# MoE 取证单 · 本机 packed-4bit 专家 GEMM 基线测量驱动
# 工单：WO-20261002-MC-甲-MOE-EV 判据 2（同一台机、同一模型尺寸、测量口径写死）
# 用法：pwsh -NoProfile -File docs/moe-ev-bench/run-bench.ps1 -Out <输出目录>
#
# 三道 fail-closed（缺一即红）：
#   1) 编译失败 ⇒ EXIT=3；
#   2) 形状/打包率与上游口径不一致 ⇒ EXIT=2（防「形状悄悄改了数字仍然好看」）；
#   3) 任一测量臂未产出读数 ⇒ EXIT=2。
#
# 为什么用 Add-Type 而不是建工程：判据要求脚本可复跑且不新增构建面。Add-Type 在内存里编译，
# 仓内不落 .csproj / .dproj / .dpr，不进任何门禁的构建枚举面。

param(
  [string]$Out = "$PSScriptRoot\..\..\CodeReview\20261002-AUDIT-甲-MOE-EV-证据"
)

$ErrorActionPreference = 'Stop'
$src = Join-Path $PSScriptRoot 'MoEPackedGemmBench.cs'
if (-not (Test-Path -LiteralPath $src)) { Write-Error "源文件不存在: $src"; exit 3 }

Write-Host "== 硬件基线（判据 3 的第一维：没有这一段，后面的数字都不可复算） =="
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$os  = Get-CimInstance Win32_OperatingSystem
$hw = [ordered]@{
  cpu_model       = $cpu.Name
  physical_cores  = $cpu.NumberOfCores
  logical_threads = $cpu.NumberOfLogicalProcessors
  max_clock_mhz   = $cpu.MaxClockSpeed
  ram_total_gb    = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
  os              = "$($os.Caption) $($os.Version)"
  ps_version      = $PSVersionTable.PSVersion.ToString()
}
$hw.GetEnumerator() | ForEach-Object { Write-Host ("   {0,-16}: {1}" -f $_.Key, $_.Value) }

Write-Host ""
Write-Host "== 编译测量核（内存编译，不落构建面） =="
try {
  Add-Type -TypeDefinition (Get-Content -LiteralPath $src -Raw) -Language CSharp -ErrorAction Stop
} catch {
  Write-Error "测量核编译失败: $($_.Exception.Message)"; exit 3
}
Write-Host "   compiled OK"

Write-Host ""
Write-Host "== 形状与打包率自证（fail-closed 第 2 道） =="
$shapeOk = ([PackedExpertGemm]::Out * [PackedExpertGemm]::In) -eq 33030144
$bprOk   = [math]::Abs([PackedExpertGemm]::BytesPerWeight - 0.53125) -lt 1e-12
$shapeMsg = "   Out x In            = $([PackedExpertGemm]::Out) x $([PackedExpertGemm]::In) = $([PackedExpertGemm]::Weights)  (上游每专家 33,030,144 参数)"
$bprMsg   = "   BytesPerWeight      = $([PackedExpertGemm]::BytesPerWeight)  (上游 0.53125 = MXFP4 4 bit + 每 32 元素 1 个 E8M0)"
$packMsg  = "   理论打包字节         = $([PackedExpertGemm]::Weights) * 17/32 = $([int]([PackedExpertGemm]::Weights * [PackedExpertGemm]::BytesPerWeight))  (上游 17,547,264)"
Write-Host $shapeMsg; Write-Host $bprMsg; Write-Host $packMsg
if (-not ($shapeOk -and $bprOk)) { Write-Error "形状/打包率与上游口径不一致 ⇒ 数字不可与上游对照"; exit 2 }

Write-Host ""
Write-Host "== 分配与展开 =="
$proc = Get-Process -Id $PID
$gc0  = [GC]::GetTotalMemory($false)
$p = [PackedExpertGemm+Packed]::new()
$proc.Refresh()
$rssAfterPack = $proc.WorkingSet64
$expanded = New-Object 'float[]' ([PackedExpertGemm]::Weights)
[PackedExpertGemm]::ExpandToFloat($p, $expanded)
$proc.Refresh()
$rssAfterExpand = $proc.WorkingSet64
$gc1 = [GC]::GetTotalMemory($false)

$x = New-Object 'float[]' ([PackedExpertGemm]::In)
$y = New-Object 'float[]' ([PackedExpertGemm]::Out)
for ($i = 0; $i -lt $x.Length; $i++) { $x[$i] = [math]::Sin($i * 0.0001) }   # 确定性输入

$warmup = 3; $iters = 10
$threads = [Environment]::ProcessorCount

Write-Host ""
Write-Host "== 测量臂 1 · 单线程专家 GEMM =="
$cs1 = 0.0
$t1 = [PackedExpertGemm]::BenchSingleThread($p, $x, $y, $warmup, $iters, [ref]$cs1)
Write-Host ("   单次延迟 = {0:N3} ms   吞吐 = {1:N2} GFLOP/s（按 2*MAC 折算，精度参考值）" -f $t1, (2.0 * [PackedExpertGemm]::Weights / $t1 / 1e6))

Write-Host ""
Write-Host "== 测量臂 2 · 全线程专家 GEMM（$threads 逻辑核）=="
$cs2 = 0.0
$t2 = [PackedExpertGemm]::BenchAllThreads($p, $x, $y, 2, $iters, $threads, [ref]$cs2)
Write-Host ("   单次延迟 = {0:N3} ms   加速比 = {1:N2}x" -f $t2, ($t1 / $t2))

# 单次结果不可信（同配置 run-to-run 噪声是本仓与上游共有的问题），故重复 3 组报全部
Write-Host ""
Write-Host "== 重复 3 组（对应上游 BENCHMARKING.md 的「报全部而非报最好」） =="
$rep1 = @(); $rep2 = @()
for ($r = 1; $r -le 3; $r++) {
  $c = 0.0
  $a = [PackedExpertGemm]::BenchSingleThread($p, $x, $y, 1, $iters, [ref]$c); $rep1 += $a
  $b = [PackedExpertGemm]::BenchAllThreads($p, $x, $y, 1, $iters, $threads, [ref]$c); $rep2 += $b
  Write-Host ("   组 {0}: 单线程 {1:N3} ms   全线程 {2:N3} ms" -f $r, $a, $b)
}
function Get-Spread($v) { $m = ($v | Measure-Object -Average).Average; $sd = [math]::Sqrt((($v | ForEach-Object { ($_ - $m) * ($_ - $m) } | Measure-Object -Sum).Sum) / ($v.Count - 1)); 100.0 * $sd / $m }
$spread1 = Get-Spread $rep1; $spread2 = Get-Spread $rep2
Write-Host ("   单线程 3 组离散度 = {0:N1}%   全线程 3 组离散度 = {1:N1}%" -f $spread1, $spread2)

$proc.Refresh()
$peak = $proc.PeakWorkingSet64

Write-Host ""
Write-Host "== 判据 4 的两栏对照：理论打包比 vs 实测驻留量 =="
$packedBytes = $p.PackedBytes
$floatBytes  = $expanded.Length * 4
$bf16Bytes   = $expanded.Length * 2
$theoBf16 = 100.0 * (1 - $packedBytes / $bf16Bytes)
$theoFp32 = 100.0 * (1 - $packedBytes / $floatBytes)
Write-Host ("   理论打包比（bf16 16 bit -> MXFP4 4.25 bit） = {0:N2}%" -f $theoBf16)
Write-Host ("   理论打包比（fp32 32 bit -> MXFP4 4.25 bit） = {0:N2}%" -f $theoFp32)
Write-Host ("   实测驻留量：打包流 {0:N0} B   展开 float[] {1:N0} B   比值 {2:N2}x" -f $packedBytes, $floatBytes, ($floatBytes / $packedBytes))
Write-Host ("   进程 RSS：分配打包流后 {0:N0} B   展开后 {1:N0} B   本进程峰值工作集 {2:N0} B" -f $rssAfterPack, $rssAfterExpand, $peak)
Write-Host ("   GC 托管堆：分配前 {0:N0} B   展开后 {1:N0} B" -f $gc0, $gc1)

Write-Host ""
Write-Host "== 折算：每 token 1,472 个专家的『纯专家 MLP 层』下界 =="
$expertsPerToken = 92 * 16
Write-Host ("   上游每 token 触及的 routed expert 实例数 = 92 路由层 x top-16 = {0}" -f $expertsPerToken)
$lb1 = 1000.0 / ($t1 * $expertsPerToken)
$lb2 = 1000.0 / ($t2 * $expertsPerToken)
Write-Host ("   单线程下界 = {0:N3} tok/s   全线程下界 = {1:N3} tok/s" -f $lb1, $lb2)
Write-Host "   ⚠ 这是**下界**：不含 trunk 投影（54.4B 参数 bf16）、KDA 递推、Gated MLA、路由器、采样、磁盘流式。"
Write-Host "     不可当作全模型 tok/s，也不可与讨论包 §4.1 的 15~35 tok/s 直接对比（那边是 2B~16B 另一尺寸）。"

New-Item -ItemType Directory -Force -Path $Out | Out-Null
$rows = @(
  '#key' + "`t" + 'value'
  'cpu_model' + "`t" + $hw.cpu_model
  'physical_cores' + "`t" + $hw.physical_cores
  'logical_threads' + "`t" + $hw.logical_threads
  'max_clock_mhz' + "`t" + $hw.max_clock_mhz
  'ram_total_gb' + "`t" + $hw.ram_total_gb
  'os' + "`t" + $hw.os
  'ps_version' + "`t" + $hw.ps_version
  'gemm_shape_out' + "`t" + [PackedExpertGemm]::Out
  'gemm_shape_in' + "`t" + [PackedExpertGemm]::In
  'gemm_weights' + "`t" + [PackedExpertGemm]::Weights
  'bytes_per_weight' + "`t" + [PackedExpertGemm]::BytesPerWeight
  'packed_bytes' + "`t" + $packedBytes
  'upstream_packed_bytes' + "`t" + 17547264
  'warmup_iters' + "`t" + $warmup
  'measured_iters' + "`t" + $iters
  'single_thread_ms' + "`t" + ([math]::Round($rep1[1], 4))
  'all_threads_ms' + "`t" + ([math]::Round($rep2[1], 4))
  'all_thread_speedup' + "`t" + ([math]::Round($rep1[1] / $rep2[1], 4))
  'single_thread_spread_pct' + "`t" + ([math]::Round($spread1, 2))
  'all_threads_spread_pct' + "`t" + ([math]::Round($spread2, 2))
  'experts_per_token' + "`t" + $expertsPerToken
  'expert_layer_lower_bound_tok_s_1t' + "`t" + ([math]::Round($lb1, 4))
  'expert_layer_lower_bound_tok_s_nt' + "`t" + ([math]::Round($lb2, 4))
  'theoretical_pack_ratio_vs_bf16_pct' + "`t" + ([math]::Round($theoBf16, 2))
  'theoretical_pack_ratio_vs_fp32_pct' + "`t" + ([math]::Round($theoFp32, 2))
  'measured_float_expand_bytes' + "`t" + $floatBytes
  'measured_expand_over_packed_ratio' + "`t" + ([math]::Round($floatBytes / $packedBytes, 4))
  'rss_after_pack_bytes' + "`t" + $rssAfterPack
  'rss_after_expand_bytes' + "`t" + $rssAfterExpand
  'process_peak_working_set_bytes' + "`t" + $peak
  'gc_heap_before_bytes' + "`t" + $gc0
  'gc_heap_after_expand_bytes' + "`t" + $gc1
  'checksum_single' + "`t" + ([math]::Round($cs1, 3))
  'checksum_allthreads' + "`t" + ([math]::Round($cs2, 3))
)
$tsv = Join-Path $Out '本机-packed4bit-GEMM-基线.tsv'
$rows -join "`r`n" | Set-Content -LiteralPath $tsv -Encoding UTF8
Write-Host ""
Write-Host "TSV 已写出: $tsv"

if (-not ($t1 -gt 0 -and $t2 -gt 0 -and $peak -gt 0 -and $packedBytes -gt 0)) {
  Write-Error "有测量臂未产出读数"; exit 2
}
Write-Host "BENCH_VERDICT: PASSED"
exit 0