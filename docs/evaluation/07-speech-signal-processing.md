# 语音与信号处理模块评估报告

> 评估日期: 2026-06-15
> 评估范围: Features/DeepBase.Speech.* (19 个文件, ~170K)
> 评估人: 语音与信号处理专家 (15 年经验)

---

## 评估摘要

**总评分: 6.0 / 10**

模块架构设计优秀（Registry/Policy/Runtime 分层清晰），SenseVoice ASR 集成完整度高，WinMM 音频采集工程质量好。但 DSP 核心算法存在多处重要缺陷：MFCC 缺少预加重、FBank FFT 实现有性能问题、DTW 路径长度仅为近似值、VAD 仅用 RMS 能量阈值（无 ZCR/自适应）、唤醒词检测实质为占位代码（未实现关键词匹配）、声纹识别未使用已导入的 DTW 而退化为均值向量欧氏距离。

---

## DSP 核心算法评估

### MFCC (DeepBase.Speech.MFCC.pas) — 6.5/10

**正确的部分:**
- Hamming 窗函数: `0.54 - 0.46 * Cos(2*Pi*I/(N-1))` (行 103), 公式正确
- HzToMel / MelToHz: 使用标准公式 `2595 * log10(1 + Hz/700)` (行 88-95), 正确
- 梅尔三角滤波器组: 从 `FNumFilters + 2` 个 mel 等距点映射到 FFT bin, 三角升降斜坡实现正确 (行 106-159)
- Radix-2 Cooley-Tukey FFT: bit-reversal permutation + butterfly stages 实现正确 (行 201-267), twiddle factor 使用 Double 精度累乘
- 功率谱: `(Re^2 + Im^2) / N` (行 191), 归一化合理
- Type-II DCT: `Sum(logMel[J] * Cos(Pi * I * (J + 0.5) / NumFilters))` (行 296), 公式正确
- Log energy floor `1e-10` (行 281), 防止 `log(0)`, 良好的工程实践
- PCM16 转 float: `SmallInt / 32768.0` (行 313), 正确

**缺陷:**
1. **[P1] 缺少预加重 (Pre-emphasis)**: 标准 MFCC 管线在分帧前对信号施加 `y[n] = x[n] - 0.97 * x[n-1]` 预加重滤波, 用于补偿高频衰减（大约每倍频程 +6dB）。当前实现完全跳过此步骤 (行 301-338), 会导致高频 MFCC 系数能量偏弱, 降低语音识别尤其是辅音 (s, t, f 等) 的区分度。
2. **[P2] 头部注释与实现不一致**: 文件头注释声称输出 "13 MFCC coefficients per frame (+ delta + delta-delta = 39 dim)" (行 8), 但实现仅输出 13 维系数, 完全没有 delta / delta-delta 计算。下游消费者如果期望 39 维特征将出错。
3. **[P2] 缺少 cepstral liftering**: 业界标准做法是对 DCT 输出施加正弦 liftering 窗 (通常 `L = 22`), 以平滑 cepstral 系数、减少高階系数的噪声敏感度。当前实现直接返回原始 DCT 输出。
4. **[P3] FFT twiddle factor 精度累积误差**: 行 259-262 中 twiddle factor 通过反复复数乘法 `W := W * Wm` 推进, 对于大 N (如 N=512) 可能积累浮点误差。建议每 stage 重新从 `cos/sin` 计算或使用查表法。

### FBank (DeepBase.Speech.FBank.pas) — 5.5/10

**正确的部分:**
- 与 MFCC 模块使用完全一致的 HzToMel/MelToHz 公式、Hamming 窗参数、梅尔滤波器组构建逻辑
- 80 维 log-Mel 能量输出, 适配 SenseVoice 等现代 ASR 模型的标准输入
- Power spectrum `/ FFFTSize` 归一化 (行 235), 正确

**缺陷:**
1. **[P2] FFT 内层循环效率低下**: `Radix2FFT` 的 butterfly 阶段 (行 159-185) 使用 `if (I mod M) = K` 过滤, 导致遍历所有 `AN` 个位置但仅处理 `AN/2` 个有效 butterfly pair。标准实现应使用三层嵌套循环 `for K, J, butterfly_index`, 避免无效的 mod 检查。对于 `FFFTSize=512`, 每个 stage 浪费约一半计算。
2. **[P2] 代码重复**: MFCC 和 FBank 模块各自独立实现了完整的 Hamming + Mel filter bank + FFT, 代码重复率超过 70%。应抽取公共 DSP 工具类 (如 `TMelSpectrumBase`), 减少维护成本并确保一致性。
3. **[P3] bit-reversal 起始索引差异**: MFCC 的 `RadixFFT` 从 `I := 1` 开始 (行 214), FBank 的 `Radix2FFT` 从 `I := 0` 开始 (行 143)。虽然 `I=0, J=0` 时不会发生交换所以结果一致, 但这种不一致增加了代码审查的认知负担。

### DTW (DeepBase.Speech.DTW.pas) — 5.0/10

**正确的部分:**
- 代价矩阵使用 1-based indexing (行 82-89), `LCost[0][0] := 0`, 其余初始化为 `1e30`, 标准做法
- Sakoe-Chiba band 约束: `LBand := Max(1, Max(N,M) div 10)` (行 78), 限制搜索带宽, 降低 O(N*M) 到 O(N*band)
- 三方向递推: insertion `LCost[I-1][J]`, deletion `LCost[I][J-1]`, match `LCost[I-1][J-1]` (行 96-101), 标准 DTW 递推
- 欧氏距离度量: 13 维 MFCC 帧间距离 (行 42-54), 正确

**缺陷:**
1. **[P1] 路径长度仅为近似值**: `Result.PathLength := N + M` (行 105) 是粗略近似, 实际 warping path 长度取决于具体对齐方式 (范围 `[max(N,M), N+M-1]`)。这导致归一化距离 `RawDistance / PathLength` 存在系统性偏差, 对不同长度序列对的比较不公平。
2. **[P1] 无路径回溯 (backtracking)**: 完整的 DTW 应存储回溯指针, 输出最优对齐路径。当前实现仅返回标量距离, 丢失了时间对齐信息, 无法用于需要 frame-level 对齐的场景 (如发音评估、强制对齐)。
3. **[P2] 带约束可能导致不可达**: 当两条序列长度差异较大时, 10% 带宽可能使 `LCost[N][M]` 保持为 `1e30` (不可达), 但代码没有对此做检查或返回错误标志。
4. **[P2] 全局 double 数组分配**: `SetLength(LCost, N+1)` 每次调用都重新分配 `(N+1)*(M+1)` 的二维数组。对于长语音 (如 10 秒 = 1000 帧), 矩阵大小约 1M entries (8MB), 频繁调用会造成 GC 压力。

### VAD (DeepBase.Speech.VAD.pas) — 3.5/10

**正确的部分:**
- dB 到线性阈值的转换: `Power(10, AThresholdDb / 20)` (行 34), 正确
- RMS 能量计算: `Sqrt(Sum(x^2) / N)` (行 53-54), 正确
- 静音帧计数器 + 最大静音帧数判断 (行 61-65), 基本的端点检测逻辑

**缺陷:**
1. **[P1] 仅基于 RMS 能量, 无过零率 (ZCR)**: 仅用能量阈值无法区分语音与稳态噪声 (如风扇声、空调噪声), 也无法区分清音 (fricatives, 低能量高 ZCR) 与静音。工业级 VAD 至少需要能量 + ZCR 双特征, 最好使用 G.729 Annex B 或 WebRTC VAD 的频谱特征方法。
2. **[P1] 固定阈值, 无自适应**: `-40dB` 绝对阈值对不同麦克风灵敏度、环境噪声水平缺乏鲁棒性。安静环境下可能太灵敏 (误触发), 嘈杂环境下可能太迟钝。应实现基于前 N 帧噪声估计的自适应阈值 (如 SNR-based)。
3. **[P2] 无 hangover / 平滑机制**: 语音端点检测没有前后平滑 (hangover), 容易在语音中短暂能量下降时误判为语音结束。应加入 speech onset / offset 的滞后判断。
4. **[P2] 帧大小 100ms 过粗**: 默认 100ms 帧 (行 35) 对 VAD 来说时间分辨率太低, 典型 VAD 使用 10-30ms 帧。100ms 帧会模糊语音边界, 导致截断语音首尾。
5. **[P3] ProcessAll 调用 Reset 清除状态**: `ProcessAll` 在行 75 调用 `Reset`, 这使得无法跨多次 `ProcessAll` 调用保持 VAD 状态, 限制了流式使用场景。

---

## 唤醒词 / 声纹识别评估

### 唤醒词检测 (DeepBase.Speech.WakeWord.pas) — 3.0/10

**正确的设计:**
- 唤醒词归一化处理: 零宽字符过滤、全角/半角转换 (行 91-111), 健壮
- 最小长度校验 >= 2 字符 (行 118), 防止单字符误触发
- 置信度阈值可配置 (行 156-161)
- 自注册到 TSpeechRegistry, 线程安全 (TCriticalSection)

**严重缺陷:**
1. **[P0] 唤醒词匹配未实现**: `Start` 方法 (行 212-213) 使用 `FGrammar.LoadDictation` + `SetDictationState(SPRS_ACTIVE)` 进入听写模式, 而非加载包含唤醒词的 SRGS grammar 进行关键词匹配。这意味着系统监听所有语音输入而非仅检测唤醒词, 会产生极高的误唤醒率。代码注释 (行 208-211) 明确承认这是 "functional placeholder"。
2. **[P0] 无事件轮询循环**: `WorkerProc` 在 ASR.SAPI 中的实现 (对应文件 ASR.SAPI.pas 行 353-362) 仅在 `while FRunning` 中等待 StopEvent, 完全不轮询 SAPI 识别事件。唤醒结果永远不会触发回调。
3. **[P1] 无 AudioSnippet 录制**: Types.pas 中的 `TWakeEvent` 定义了 `AudioSnippet: TBytes` (行 75), 用于声纹验证, 但 WakeWord.pas 从未填充此字段, 声纹二次确认链路断裂。
4. **[P2] IsAvailable 中创建全局实例**: `IsAvailableFunc` (行 255-261) 在可用性检查时创建 `GlobalWakeWord` 实例, 存在副作用 (调用一个名为 "IsAvailable" 的函数不应改变全局状态)。

### 声纹识别 (DeepBase.Speech.Voiceprint.pas) — 4.5/10

**正确的部分:**
- 注册要求 >= 3 个样本 (行 129), 防止过拟合
- 使用 GUID 作为 profile ID (行 152), 无冲突
- 线程安全 (TCriticalSection 保护 FProfiles / FProfileInfos)
- DPAPI 加密持久化的设计意图正确 (行 172 TODO 注释)

**缺陷:**
1. **[P1] DTW 已导入但未使用**: 文件 uses 子句包含 `DeepBase.Speech.DTW` (行 19), 但 `Verify` (行 244) 和 `Identify` (行 278) ���仅调用 `TDTW.FrameDistance` 做单帧欧氏距离, 完全没有调用 `TDTW.Compute` 做序列级 DTW 对齐。这大幅降低了声纹区分能力——不同语速、不同内容的同一说话人, 其均值向量差异可能很大。
2. **[P1] 注册仅存储均值向量**: `EnrollProfile` (行 146) 将所有样本的所有帧聚合成一个均值向量。这丢失了帧间分布信息 (方差、协方差), 使得不同说话人但相似平均音色的情况无法区分。至少应存储均值 + 方差 (GMM-UBM 的简化版)。
3. **[P2] Score 计算公式粗糙**: `Result.Score := Max(0, 1.0 - LDist / (LInfo.Threshold * 2))` (行 250) 是线性映射, 不是概率校准的分数。阈值 * 2 处 score 降为 0 的假设没有统计学依据。
4. **[P2] 持久化未实现**: `EnrollProfile` (行 172) 和 `DeleteProfile` (行 188) 的 ConfigDB 持久化均为 TODO, 当前重启后所有声纹数据丢失。
5. **[P3] 最低帧数要求过低**: `Length(LFeatures) < 5` (行 137) 仅要求 5 帧 (约 50ms), 对于声纹注册来说样本量严重不足, 建议最低 50 帧 (约 500ms)。

---

## ASR 多后端集成评估

### SenseVoice (DeepBase.Speech.ASR.SenseVoice.pas) — 8.0/10

**最完整的 ASR 后端:**
- 完整的特征管线: FBank 80 维 -> LFR stacking (7/6 -> 560 维) -> CMVN 归一化 (行 336-399)
- LFR (Low Frame Rate) 实现正确: `LFR_WINDOW_SIZE=7, LFR_WINDOW_SHIFT=6` (行 108-109), 每 6 帧堆叠 7 帧, 降采样比约 6:1
- CMVN 从 ONNX metadata 加载 `neg_mean` / `inv_stddev` (行 287-312), 正确应用 `(x - negMean) * invStddev` (行 398)
- CTC greedy decode + blank 折叠 + 连续重复消除 (行 480-556), 实现正确
- SentencePiece 空格标记 `$2581` 替换为真实空格 (行 551), 正确处理
- 多语言支持: auto/zh/en/yue/ja/ko, 带语言到整数的映射 (行 314-334)
- 模拟流式: 每 500ms 对累积 buffer 做完整解码, 触发 partial 回调 (行 673-706)
- 烟雾测试: 初始化后用 0.5s 静音验证管线 (行 213-221), 良好的工程实践

**缺陷:**
1. **[P2] 模拟流式效率低**: 每 500ms 对全部累积音频重新运行 ONNX 推理 (行 691 `RecognizeInternal(Copy(FBuffer))`)。对于 10 秒语音, 最后一次解码要处理全部数据。应实现 chunk-level 增量推理 (保留 KV cache)。
2. **[P2] 无语义置信度输出**: `LPartial.Confidence := 0.8` (行 693) 硬编码为 0.8, 实际应从 CTC logits 计算 (如 softmax max 值的平均)。
3. **[P3] vocab size 硬编码**: `SENSEVOICE_VOCAB_SIZE = 25055` (行 112), 如果模型版本更新导致 vocab 变化, 此值需要同步更新。应从 tokens.txt 行数动态获取。

### Baidu (DeepBase.Speech.ASR.Baidu.pas) — 6.5/10

**正确的部分:**
- OAuth2 token 管理: 带缓存和提前 1 小时过期 (行 312 `FTokenExpireTime := Now + (ExpiresIn - 3600) / 86400`)
- 双 HTTP transport: 直接 `THTTPClient` 和通过 `IDeepBaseHttpTransport` 代理 (行 37-237), 灵活
- 音频格式校验: 严格要求 PCM16 mono (行 345-348)
- 错误处理链完整: token 失败 / HTTP 错误 / JSON 解析错误 / 业务 err_no 均独立处理

**缺陷:**
1. **[P2] 仅支持 batch**: 无流式识别能力, 对于实时交互场景受限
2. **[P2] 无重试逻辑**: 网络请求失败直接返回错误 (行 379-383), 无指数退避重试。云服务短暂故障会导致识别完全失败。
3. **[P3] Base64 换行符手动去除**: 行 365 `SpeechB64.Replace(#13#10, '', [rfReplaceAll])`, 依赖 TNetEncoding.Base64 的具体编码行为, 如果底层实现变化可能引入 bug。应使用不产生换行的 Base64 编码。

### SAPI ASR (DeepBase.Speech.ASR.SAPI.pas) — 3.5/10

**正确的设计:**
- Shared recognizer fallback 到 Inproc recognizer (行 130-132)
- Grammar + Dictation 双模式设计
- Streaming 架构 (worker thread + event polling) 的框架代码存在

**严重缺陷:**
1. **[P0] WorkerProc 未实际轮询事件**: 行 353-362 的 `WorkerProc` 仅在 `while FRunning` 中等待 `FStopEvent`, 不读取 SAPI 识别结果。注释 (行 357-361) 承认 "results are collected when Stop is called. Full event-driven implementation requires ISpNotifyCallback"。这意味着流式识别完全不工作。
2. **[P1] LoadGrammar 退化为 dictation**: 行 197 `FGrammar.LoadDictation(nil, 0)`, 与 WakeWord 相同的问题, grammar 模式未实现。
3. **[P2] Stop 中 Sleep(100) 等待**: 行 319 `Sleep(100)` 是脆弱的线程同步方式, 应使用事件或 condition variable。

---

## TTS 集成评估

### TTS.SAPI (DeepBase.Speech.TTS.SAPI.pas) — 6.0/10

**正确的部分:**
- 同步 `Speak` (SPF_DEFAULT) 和异步 `SpeakAsync` (SPF_ASYNC) 双模式
- 速率和音量可调 (SetRate / SetVolume)
- Stop 使用 `SPF_PURGEBEFORESPEAK` 清空队列 (行 160)

**缺陷:**
1. **[P2] 异步完成回调不可靠**: `SpeakAsync` 的完成回调 (行 137-151) 创建匿名线程, 调用 `FVoice.WaitUntilDone(30000)`, 超时 30 秒后静默触发回调。如果语音超过 30 秒 (长文本), 回调会提前触发。此外, 回调在匿名线程中执行, 不保证在 UI 线程上, 可能导致跨线程 UI 操作异常。
2. **[P2] 无音色选择**: 未实现 `SupportedVoices` 和按 ID/语言选择音色, 仅使用 SAPI 默认语音。
3. **[P2] 无 SSML 支持**: `SPF_IS_XML` 标志已定义 (SAPI.Decl 行 230) 但 Speak 方法始终使用 `SPF_DEFAULT`, 无法利用 SSML 进行精细控制 (停顿、语速变化、发音纠正)。
4. **[P3] Speak 参数始终 SPF_DEFAULT**: 行 107 `FVoice.Speak(... SPF_DEFAULT ...)`, 这意味着每次 Speak 调用是阻塞的。在 UI 线程中调用会卡死界面。

---

## 音频采集层评估

### Audio.WinMM (DeepBase.Speech.Audio.WinMM.pas) — 7.5/10

**正确的部分:**
- `waveInProc` 回调正确处理 `WIM_DATA` 消息, 追加数据到 TMemoryStream 并重新提交 buffer (行 60-77)
- `TInterlocked` 原子操作保护 `FIsRecording` 标志 (行 166-173), 避免回调与主线程的竞态
- 可配置 buffer 大小和数量, 提供 `CreateLowLatency` 工厂方法 (50ms * 8 buffers, 行 93-98)
- 错误处理: `waveInGetErrorText` 转换错误码为可读文本 (行 204-206)
- `StopRecording` 先设置 `IsRecording=False` 再获取锁 (行 244-248), 确保回调不再进入临界区后才清理资源
- 正确的 wave header unprepare 检查 `WHDR_PREPARED` flag (行 146)

**缺陷:**
1. **[P2] WaveInProc 回调中的 AddBufferToStream 加锁风险**: 行 73 `Capture.AddBufferToStream(Header)` 在 `waveInProc` 回调中执行, 该回调运行在 Windows 音频线程 (非 UI 线程)。`AddBufferToStream` 获取 `FLock` (行 157)。如果 `StopRecording` 正持有 `FLock` (行 247), 音频线程会被阻塞, 可能导致音频 glitch 甚至系统音频服务挂起。建议改用 lock-free 队列。
2. **[P2] 无设备选择**: `waveInOpen` 使用 `WAVE_MAPPER` (行 200), 始终使用系统默认麦克风。无法选择特定音频输入设备。
3. **[P3] GetPCMData 读取后未重置 Stream Position**: `GetPCMData` (行 264-276) 读取后 `FStream.Position` 停留在末尾。虽然每次读取前都设置 `Position := 0` (行 271), 但如果其他代码路径访问 Stream 可能出问题。
4. **[P3] 无限录制时内存增长**: `FStream` 持续增长直到 `StopRecording` 或 `StartRecording` 重新调用。对于长时间录制 (> 1 小时), 内存占用可达数百 MB。

---

## 架构评估

**优秀的架构设计:**
- `TSpeechRegistry` (Registry.pas) 提供后端自动发现和优先级排序, 各后端自注册 (initialization section), 松耦合
- `TSpeechRuntime` (Runtime.pas) 实现音频会话状态机 (Idle/WakeListening/PushToTalk/DictationStreaming/TTSPlaying), 合理处理优先级和抢占
- `TSpeechPolicy` (Policy.pas) 提供治理门控, 区分本地/云端/生物特征的权限级别
- `TSpeechService` (Service.pas) 静态门面提供便捷 API, 支持注册各种后端
- `TSpeechConfig` (Config.pas) 集中管理配置键和默认值, BCP-47 语言标签规范化

**架构缺陷:**
1. **[P2] 类型定义重复**: `TVoiceProfileInfo`, `TVerifyResult`, `TWakeEvent`, `TIntentSlot`, `TIntentResult` 在 Types.pas 和各自模块 (Voiceprint.pas, WakeWord.pas, Intent.pas) 中重复定义, 字段略有不同 (例如 Voiceprint.pas 的 `TVoiceProfileInfo` 有 `Threshold` 字段而 Types.pas 的没有)。这会导致接口不兼容和编译问题。
2. **[P2] 全局变量隐式初始化**: 多个模块在 `initialization` section 创建全局实例 (`GlobalWakeWord`, `GlobalSAPIASR`, `GlobalVoiceprint`, `GlobalIntentParser`, `SpeechRuntime`), 生命周期管理分散, 初始化顺序依赖难以追踪。
3. **[P3] ISpeechRecognizerEx 与 ISpeechRecognizer 继承关系**: `ISpeechRecognizerEx` 继承自 `ISpeechRecognizer` (Types.pas 行 160), 但 SAPI ASR (`TDeepBaseSAPIASR`) 未实现 `ISpeechRecognizerEx`, 导致无法通过统一接口查询 `IsAvailable` / `Kind` / `SupportsBatch` 等属性。

---

## 已知问题/风险汇总 (按严重程度)

### P0 — 功能缺失 (不可用)
| 问题 | 文件 | 行号 | 说明 |
|------|------|------|------|
| 唤醒词匹配未实现 | WakeWord.pas | 212-213 | 使用 dictation 模式而非 grammar 匹配 |
| SAPI ASR 流式不工作 | ASR.SAPI.pas | 353-362 | WorkerProc 未轮询识别事件 |
| VAD 无 ZCR / 自适应 | VAD.pas | 40-66 | 仅 RMS 能量, 噪声环境不可靠 |

### P1 — 算法质量缺陷
| 问题 | 文件 | 行号 | 说明 |
|------|------|------|------|
| 缺少预加重 | MFCC.pas | 301-338 | 标准 MFCC 管线的关键步骤缺失 |
| DTW 路径长度近似 | DTW.pas | 105 | `N + M` 近似, 无回溯 |
| 声纹未使用 DTW | Voiceprint.pas | 244, 278 | 仅用 FrameDistance, 未用 Compute |
| 声纹仅存储均值 | Voiceprint.pas | 146 | 丢失帧分布信息 |
| SAPI Grammar 退化 | ASR.SAPI.pas | 197 | LoadGrammar 实际加载 dictation |

### P2 — 工程质量问题
| 问题 | 文件 | 行号 | 说明 |
|------|------|------|------|
| MFCC/FBank 代码重复 | MFCC.pas + FBank.pas | 全文件 | 70%+ 重复率 |
| FBank FFT 效率低 | FBank.pas | 169-173 | mod 过滤, 浪费一半迭代 |
| VAD 帧长 100ms | VAD.pas | 35 | 时间分辨率过粗 |
| SenseVoice 流式效率 | ASR.SenseVoice.pas | 691 | 每次全量重跑推理 |
| TTS 异步回调超时 | TTS.SAPI.pas | 144 | 30s 硬编码超时 |
| 类型重复定义 | Types.pas + 各模块 | 多处 | 接口不兼容风险 |
| WinMM 回调加锁 | Audio.WinMM.pas | 73, 157 | 音频线程可能阻塞 |

---

## 优先级排序的改进建议 (Top 5)

### 1. [P0] 实现真正的唤醒词 grammar 匹配
**当前状态**: 使用 SAPI dictation 监听所有语音, 无法区分唤醒词和普通语音。
**建议**: 构建 SRGS XML grammar 文件包含唤醒词列表, 使用 `ISpRecoGrammar.LoadCmdFromMemory` 加载, 通过 `ISpRecoContext.SetInterest` 注册识别事件, 在 WorkerProc 中轮询 `SPFEI_RECOGNITION` 事件并检查置信度阈值。同时录制唤醒前后 500ms 的 AudioSnippet 供声纹验证。
**预计工作量**: 3-5 天

### 2. [P1] MFCC 管线补齐预加重 + Delta + Liftering
**当前状态**: 缺少预加重导致高频系数偏弱; 头注释声称 39 维但实际仅 13 维。
**建议**: (a) 在 `Extract` 方法中分帧后、加窗前加入预emphasis: `frame[i] := frame[i] - 0.97 * frame[i-1]`; (b) 实现 delta (`(c[t+2] - c[t-2]) / norm`) 和 delta-delta, 输出 39 维; (c) 添加 sin-curve liftering (L=22)。同时抽取公共 DSP 基类消除 MFCC/FBank 代码重复。
**预计工作量**: 2-3 天

### 3. [P1] 声纹识别升级: 使用 DTW + 存储完整特征
**当前状态**: 仅存储均值向量, 用欧氏距离比较, 区分能力极弱。
**建议**: (a) 注册时保存所有帧的完整 MFCC 序列 (或关键帧子集); (b) 验证时使用 `TDTW.Compute` 做序列级对齐比较; (c) Score 改用基于 DTW 距离的 softmax 或 likelihood ratio; (d) 考虑加入 GMM-UBM 或 i-vector 的简化实现。同时修复 Types.pas / Voiceprint.pas 的类型重复问题。
**预计工作量**: 3-4 天

### 4. [P1] VAD 升级为能量 + ZCR 双特征自适应 VAD
**当前状态**: 仅 RMS 能量阈值, 噪声环境完全不可靠。
**建议**: (a) 将帧长从 100ms 降至 20-30ms; (b) 添加过零率 (ZCR) 计算; (c) 实现基于前 500ms 背景噪声的自适应阈值 (能量阈值 = noiseFloor + 10dB, ZCR 阈值 = noiseZCR * 1.5); (d) 添加 speech onset/offset hangover (onset: 3 帧确认, offset: 10 帧确认); (e) 可选: 直接使用 WebRTC VAD 的 Delphi 移植。
**预计工作量**: 2-3 天

### 5. [P1] SAPI ASR 流式事件轮询实现
**当前状态**: WorkerProc 仅等待 stop event, 不读取识别结果。
**建议**: (a) 使用 `ISpNotifySource.SetNotifyWin32Event` 将 SAPI 事件绑定到 Windows event handle; (b) WorkerProc 中使用 `WaitForMultipleObjects` 同时监听 stop event 和 SAPI event; (c) 收到 `SPFEI_RECOGNITION` 时通过 `ISpRecoContext` 获取 `ISpRecoResult`, 提取文本和置信度; (d) 收到 `SPFEI_HYPOTHESIS` 时触发 partial 回调。
**预计工作量**: 2-3 天

---

## 评分汇总表

| 模块 | 评分 | 关键问题 |
|------|------|----------|
| MFCC | 6.5 | 缺预加重, 无 delta, 无 liftering |
| FBank | 5.5 | FFT 效率低, 代码重复 |
| DTW | 5.0 | 无回溯, 路径长度近似 |
| VAD | 3.5 | 仅 RMS, 无自适应, 帧太粗 |
| 唤醒词 | 3.0 | 匹配未实现, 无事件轮询 |
| 声纹识别 | 4.5 | 未用 DTW, 仅均值向量 |
| SenseVoice ASR | 8.0 | 模拟流式效率低, 无置信度 |
| Baidu ASR | 6.5 | 仅 batch, 无重试 |
| SAPI ASR | 3.5 | 流式完全不工作 |
| TTS.SAPI | 6.0 | 无音色选择, 异步回调不可靠 |
| Audio.WinMM | 7.5 | 回调加锁风险, 无设备选择 |
| 架构 | 7.0 | 分层清晰, 但有类型重复和全局实例问题 |
| **总评** | **6.0** | |
