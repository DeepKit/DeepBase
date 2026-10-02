// MoE 取证单 · packed-4bit 专家 GEMM 的本机 CPU 基线测量（WO-20261002-MC-甲-MOE-EV 判据 2）
//
// 形状与打包口径均取自上游 FareedKhan-dev/kimi-k3-in-c 的自述架构，二者都可被独立算术复核：
//   单个 routed expert = 33,030,144 参数 / 17,547,264 字节 = 0.53125 字节每权重
//   （MXFP4：4 bit 半字节 + 每 32 个元素 1 个 E8M0 标度 = 4 + 8/32 = 4.25 bit = 0.53125 B）。
//   本夹具用 4608 × 7168 的矩阵，恰好 33,030,144 个权重 —— 与上游「每专家」口径逐位相同：
//     4608 × 7168 = 33,030,144
//     33,030,144 × 17/32 = 17,547,264 字节
//   两个数与上游 docs/ARCHITECTURE.md 的自述逐位吻合。
//
// 为什么必须自己测：讨论包 §4.1 的「15~35 tok/s」没有硬件基线、没有量化格式，按本单判据 3
// 属不可复算；本夹具补的正是「同一台机、同一形状、同一打包格式」这三个缺失维度。
//
// 口径边界（诚实收窄）：本夹具只测 MoE 专家 MLP 这一层的矩阵乘。不含 trunk（54.4B 参数 bf16 投影）、
// KDA 递推、Gated MLA、路由器、采样、磁盘流式。因此由此推出的 tok/s 是**下界**，不是全模型 tok/s，
// 引用时必须与这个边界一起出现。

using System;
using System.Diagnostics;
using System.Threading.Tasks;

public static class PackedExpertGemm
{
    // 形状：与上游「每专家」口径逐位相同
    public const int Out = 4608;
    public const int In = 7168;
    public const int Weights = Out * In;            // 33,030,144
    public const double BytesPerWeight = 17.0 / 32.0; // 0.53125 = MXFP4 实打包率
    public const int ScaleGroup = 32;               // 每 32 个权重一个共享标度
    public const int ScaleCount = Weights / ScaleGroup;   // 整矩阵的标度组数
    public const int ScalesPerRow = In / ScaleGroup;      // 每行的标度组数 = 224

    // E2M1 的 16 个码值（OCP MX FP4 元素格式），索引即半字节取值
    static readonly float[] E2M1 = {
        0f, 0.5f, 1f, 1.5f, 2f, 3f, 4f, 6f,
        0f, -0.5f, -1f, -1.5f, -2f, -3f, -4f, -6f
    };

    // 确定性填充：固定种子的 xorshift，任意机器上逐位可复现
    // （不用 System.Random —— 它的序列是实现相关的，不可跨运行时复现）
    static ulong Next(ulong s)
    {
        s ^= s << 13; s ^= s >> 7; s ^= s << 17; return s;
    }

    public sealed class Packed
    {
        public readonly byte[] Nibbles;    // 每字节 2 个权重，低半字节 = 偶数位元素
        public readonly float[] Scales;    // 每 32 个权重一个共享标度（按整矩阵线性排布）
        public readonly long PackedBytes;  // 实占字节（半字节流 + 标度流）

        public Packed()
        {
            Nibbles = new byte[Weights / 2];
            Scales = new float[ScaleCount];
            ulong s = 0x9E3779B97F4A7C15UL;
            for (int i = 0; i < Nibbles.Length; i++) { s = Next(s); Nibbles[i] = (byte)(s >> 24); }
            for (int i = 0; i < ScaleCount; i++) { s = Next(s); Scales[i] = 0.5f + (float)((s >> 40) & 0xFFFF) / 65535.0f * 1.5f; }
            // 实占 = 半字节流（Weights/2 字节）+ 每 32 权重 1 字节 E8M0 标度（ScaleCount 字节）
            // = 33,030,144 × 0.53125 = 17,547,264，与上游自述逐位相同
            PackedBytes = Nibbles.Length + ScaleCount;
        }
    }

    // 单线程：y[o] = Σ_k E2M1[nibble(w)] · scale(w/32) · x[k]，w = o·In + k
    // 直接吃打包半字节，任何时刻都不存在反量化后的整块缓冲 —— 这正是被测的那条设计主张的可测形态。
    public static void GemmSingleThread(Packed p, float[] x, float[] y)
    {
        for (int o = 0; o < Out; o++) GemmRow(p, x, y, o);
    }

    static void GemmRow(Packed p, float[] x, float[] y, int o)
    {
        int nbr = (o * In) >> 1;        // 本行首权重在半字节流里的下标
        int g0 = (o * In) / ScaleGroup; // 本行首权重所属的标度组下标
        float acc = 0f;
        for (int k = 0; k < In; k += ScaleGroup)
        {
            float sc = p.Scales[g0 + (k / ScaleGroup)];
            int nb = nbr + (k >> 1);
            for (int t = 0; t < ScaleGroup; t += 2)
            {
                byte b = p.Nibbles[nb + (t >> 1)];
                acc += E2M1[b & 0x0F] * sc * x[k + t];
                acc += E2M1[b >> 4] * sc * x[k + t + 1];
            }
        }
        y[o] = acc;
    }

    public static double BenchSingleThread(Packed p, float[] x, float[] y, int warmup, int iters, out double checksum)
    {
        for (int i = 0; i < warmup; i++) GemmSingleThread(p, x, y);
        var sw = Stopwatch.StartNew();
        for (int i = 0; i < iters; i++) GemmSingleThread(p, x, y);
        sw.Stop();
        checksum = Checksum(y);
        return sw.Elapsed.TotalMilliseconds / iters;
    }

    public static double BenchAllThreads(Packed p, float[] x, float[] y, int warmup, int iters, int threads, out double checksum)
    {
        var opts = new ParallelOptions { MaxDegreeOfParallelism = threads };
        for (int i = 0; i < warmup; i++) Parallel.For(0, Out, opts, o => GemmRow(p, x, y, o));
        var sw = Stopwatch.StartNew();
        for (int i = 0; i < iters; i++) Parallel.For(0, Out, opts, o => GemmRow(p, x, y, o));
        sw.Stop();
        checksum = Checksum(y);
        return sw.Elapsed.TotalMilliseconds / iters;
    }

    static double Checksum(float[] y)
    {
        double cs = 0; for (int i = 0; i < y.Length; i++) cs += y[i]; return cs;
    }

    // 判据 4 的对照臂：把同一权重展开成 float[]，量出「反量化后体积 / 打包体积」的真比，
    // 用来把「理论打包比」和「实测驻留量」分开摆，不混用一个「降 75%」。
    public static void ExpandToFloat(Packed p, float[] dst)
    {
        for (int g = 0; g < ScaleCount; g++)
        {
            float sc = p.Scales[g];
            int k0 = g * ScaleGroup;        // 权重下标
            int nb = g * (ScaleGroup / 2); // 半字节流下标 = 权重下标 / 2
            for (int j = 0; j < ScaleGroup; j += 2)
            {
                byte b = p.Nibbles[nb + (j >> 1)];
                dst[k0 + j] = E2M1[b & 0x0F] * sc;
                dst[k0 + j + 1] = E2M1[b >> 4] * sc;
            }
        }
    }
}