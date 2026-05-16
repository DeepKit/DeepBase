# DeepBase.Speech 能力扩展 — Implementation Plan

> 版本：2.0（基于两轮专家评审 + 开发规范 v2.0）
> 测试框架：DUnitX + PBT（属性测试）
> 里程碑：M0 Spike → M1 Runtime 骨架 → M2 流式 ASR → M3 DeepInput 重构 → M4 DeepLaunch F2/PTT → M5 WakeWord → M6 稳定化 → M7 Voiceprint → M8 IntentParser/扩展

## Overview

实施路径遵循"基础设施成熟度分期"：先运行时骨架（Registry/Config/Policy/Runtime/Schema）、能力检测、配置/治理、测试替身和资源仲裁，再实现具体 Backend 和下游集成。

---

## Tasks

- [ ] 1. M0 Spike：SAPI/WinMM/可访问性验证（不发布）
  - [x] 1.1 验证 Delphi 37.0 SAPI COM 声明可用性
    - 检查 `Winapi.SpeechLib` 或手写最小 COM 接口声明
    - 确认 `ISpRecognizer / ISpVoice / ISpRecoGrammar` 可用
    - _Requirements: 2.6_

  - [x] 1.2 Win7/10/11 SAPI zh recognizer/voice token 矩阵
    - 穷举 Win7 SP1 / Win10 1803 / Win10 20H2 / Win11 23H2 / Win11 24H2 下的 token 名
    - 给出 `IsAvailable` 判定逻辑：枚举 `SPCAT_RECOGNIZERS` 找 zh 开头
    - _Requirements: 2.6, 13.3_

  - [x] 1.3 16k zh PCM16 WAV batch ASR 验证
    - 用预录中文 WAV 跑 SAPI batch ASR，确认识别结果
    - _Requirements: 2.5_

  - [x] 1.4 SAPI 自采麦克风 live streaming 验证
    - 验证 SAPI events 产生 partial/final 的时序
    - _Requirements: 2.3_

  - [x] 1.5 SAPI FeedAudio（自定义 PCM chunk queue）可行性
    - 验证自定义 IStream 注入 SAPI 的可行性和成本
    - _Requirements: 2.3, 12.1_

  - [x] 1.6 WinMM buffer 20/50/100ms 延迟+CPU 基准
    - 测试不同 buffer 大小的延迟、CPU 占用、丢帧情况
    - 给出推荐值
    - _Requirements: 9.1, 10.1_

  - [x] 1.7 SAPI recognizer + WinMM capture 并发占用验证
    - 测试两者同时打开时的设备占用行为
    - _Requirements: 10.4_

  - [x] 1.8 WakeWord Grammar zh 词 confidence 分布
    - 注册"小启"等中文词，采集 confidence 分布、误触率、漏触率
    - _Requirements: 4.2_

  - [x] 1.9 监听中动态 SetWords 稳定性验证
    - 验证不崩溃、不退出、可停止
    - _Requirements: 4.3_

  - [x] 1.10 TTS SpeakAsync/Stop/连续/空文本/voice 切换验证
    - 验证 Stop 时延、连续播放行为、空文本处理
    - _Requirements: 3.3, 3.4, 3.6_

  - [ ] 1.11 GitHub Actions windows-latest SAPI 可用性验证
    - 确认 CI 环境是否能跑真 SAPI 测试
    - _Requirements: 19.1_

  - [ ] 1.12 屏幕阅读器检测验证
    - 验证 `SystemParametersInfo(SPI_GETSCREENREADER)` 在有/无 NVDA 时的返回值
    - _Requirements: 18.1_

  - [ ] 1.13 Voice Access 检测验证
    - 验证进程名 `VoiceAccess.exe` 检测方式
    - _Requirements: 18.2_

  - [ ] 1.14 SAPI voice 占用状态探测
    - 验证是否能检测某个 voice 被其他进程占用
    - _Requirements: 18.3_

  - [ ] 1.15 DPAPI 跨用户/跨机器失败路径验证
    - 验证恢复失败时的行为和错误信息
    - _Requirements: 7.4_

  - [ ] 1.16 QueryPerformanceCounter 多线程精度验证
    - 验证高精度时钟在多线程场景下的精度
    - _Requirements: 10.6_

- [ ] 2. Checkpoint — M0 Spike 完成
  - 汇总 Spike 结论，确认 SAPI 三级能力边界
  - 确认 FeedAudio 可行性结论
  - 确认 WinMM buffer 推荐值
  - Ensure all findings documented, ask the user if questions arise.

- [ ] 3. M1 Runtime 骨架 + SAPI Batch ASR + TTS
  - [x] 3.1 扩展 `DeepBase.Speech.Types.pas` 新类型
    - 添加 `SPEECH_API_LEVEL` 常量
    - 添加 `TASRMode / TASRBackendKind / TASROptions / TASRPartialResult`
    - 添加 `IASRStream / ISpeechRecognizerEx`（含 GUID）
    - 添加 `TTTSVoice / TTTSOptions / ITTSBackend`（含 GUID）
    - 添加 `TWakeEvent / IWakeWordDetector`（含 GUID）
    - 添加 `TVoiceProfileId / TVoiceProfileInfo / TVoiceFeatures / TVerifyResult / IVoiceprint`（含 GUID）
    - 添加 `TIntentSlot / TIntentResult / IIntentParser`（含 GUID）
    - 添加 `TSpeechAudioUtils.FloatToPCM16`
    - 保持现有类型签名不变
    - _Requirements: 1.7, 19.3, 19.4_

  - [ ]* 3.2 PBT: PCM16 往返（P1）
    - **Property 1: PCM16 round-trip**
    - 生成器：随机偶数长度（2..65536）字节数组
    - 属性：`FloatToPCM16(PCM16ToFloat(B)) = B`
    - **Validates: Requirements 15.1**

  - [ ]* 3.3 PBT: Float 往返量化误差（P2）
    - **Property 2: Float round-trip quantization error**
    - 生成器：随机长度（1..1024）Single 数组，值域 [-1.0, 1.0)
    - 属性：每个元素差 < 1/32768
    - **Validates: Requirements 15.2**

  - [ ]* 3.4 PBT: DurationMs 公式（P3）
    - **Property 3: DurationMs formula**
    - 生成器：随机 SampleRate（8000/16000/44100）+ 随机 PCMData 长度
    - 属性：`DurationMs = round(Length * 1000 / BytesPerSecond)`
    - **Validates: Requirements 9.4**

  - [ ]* 3.5 PBT: PCM16ToFloat 范围（P4）
    - **Property 4: PCM16ToFloat range**
    - 属性：长度 = Length(B) div 2，每个值 ∈ [-1.0, 1.0]
    - **Validates: Requirements 9.3**

  - [x] 3.6 创建 `DeepBase.Speech.Registry.pas`
    - Backend 注册表：`Kind / Name / IsCloud / RequiresMic / SupportsBatch / SupportsStreaming / SupportsGrammar`
    - `Register / Disable / Override / Discover` 方法
    - Backend 自注册机制（initialization 段）
    - _Requirements: 1.3, 1.6_

  - [x] 3.7 创建 `DeepBase.Speech.Config.pas`
    - ConfigDB 键定义与默认值
    - BCP-47 归一化逻辑（`zh-Hans-CN → zh-CN`、`zh_CN → zh-CN`、`zh → 报错`）
    - 语言键拆分：`speech.asr.language` + `speech.tts.language`
    - 首次启动写入默认键
    - _Requirements: 7.1, 7.2, 7.7_

  - [ ]* 3.8 PBT: 配置读写幂等（P12）
    - **Property 12: Config read-write idempotence**
    - 对所有 Speech 配置键，读取→写回→再读取，验证值不变
    - **Validates: Requirements 7.6**

  - [x] 3.9 创建 `DeepBase.Speech.Policy.pas`
    - 统一封装 Governance + Commerce.Permissions
    - `IsAllowed(key): Boolean` 查询接口
    - 通过 `TConfigRegistrar` 注册 5 个门禁键
    - 保守模式：ConfigRegistrar 未初始化时全禁用
    - _Requirements: 8.1, 8.4, 8.6_

  - [x] 3.10 创建 `DeepBase.Speech.Runtime.pas`
    - AudioSession 仲裁状态机（Idle/WakeListening/PushToTalk/DictationStreaming/TTSPlaying）
    - ASR/TTS 降级链执行逻辑
    - Trace 日志（高精度时钟 QueryPerformanceCounter）
    - Stop 时限管理（best-effort + hard-limit 双轨）
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6_

  - [x] 3.11 创建 `DeepBase.Speech.Schema.pas`
    - 注册 `voice_profiles` 表迁移（版本 `speech_v1`，含 `features_hmac` 预留列）
    - _Requirements: 7.5, 17.4_

  - [x] 3.12 扩展 `DeepBase.Speech.Service.pas` 门面
    - 添加 `TSpeechService` 类级静态门面
    - 静态方法：`ASR / TTS / WakeWord / Voiceprint / IntentParser / AudioCapture / VAD`
    - `RegisterASRBackend / RegisterTTSBackend / RegisterWakeWordDetector / RegisterVoiceprint / RegisterIntentParser`
    - `TranscribeFromMic` / `Speak` 便捷方法
    - 保持现有 `TDeepBaseSpeechService` 签名不变
    - _Requirements: 1.1, 1.2, 1.5_

  - [x] 3.13 创建 `DeepBase.Speech.ASR.SAPI.pas`（Batch 模式）
    - 实现 `TDeepBaseSAPIASRRecognizer : ISpeechRecognizerEx`
    - 所有 SAPI 调用在唯一 worker thread 内串行
    - `IsAvailable`：`CoCreateInstance` + 枚举 `SPCAT_RECOGNIZERS` 找 zh token
    - `CheckStatus`：返回缺失 SAPI 或语言包的可读原因
    - `Recognize`（同步 Batch）：PCM → SAPI → `TSpeechRecognitionResult`
    - `LoadGrammar`：生成 SRGS XML → `LoadCmdFromMemory`
    - initialization 段自注册到 Registry
    - _Requirements: 2.1, 2.2, 2.4, 2.5, 2.6_

  - [x] 3.14 创建 `DeepBase.Speech.TTS.SAPI.pas`
    - 实现 `TDeepBaseSAPITTSBackend : ITTSBackend`
    - `IsAvailable`：`CoCreateInstance(CLSID_SpVoice)` 检测
    - `SupportedVoices`：枚举 `SPCAT_VOICES`，跳过被占用的 voice
    - `Speak`（同步）/ `SpeakAsync`（异步）/ `Stop`（best-effort 150ms / hard-limit 800ms）
    - 空文本处理：不调用 SAPI，直接触发回调
    - 屏幕阅读器检测：`SPI_GETSCREENREADER` → 静默
    - initialization 段自注册到 Registry
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.8, 18.1_

  - [ ]* 3.15 单元测试：SAPI ASR/TTS
    - `IsAvailable / CheckStatus` 在有/无 SAPI 环境下的行为
    - `SupportedVoices` 返回非空列表
    - TTS 空文本处理（Req 3.6）
    - Governance 门禁拒绝云 Backend（Req 8.2/8.3）
    - AudioSession 状态切换
    - BCP-47 归一化
    - _Requirements: 2.6, 3.6, 8.2, 8.3, 7.7_

  - [x] 3.16 dpk 切分：创建 5 个 dpk 文件
    - `DeepBaseFeatures.dpk`（Core）
    - `DeepBaseFeaturesASR.dpk`
    - `DeepBaseFeaturesTTS.dpk`
    - `DeepBaseFeaturesWake.dpk`（暂空）
    - `DeepBaseFeaturesVoice.dpk`（暂空）
    - _Requirements: 19.1, 19.2_

- [ ] 4. Checkpoint — M1 Runtime 骨架完成
  - 现有 `Test.DeepBase.Speech.pas` 全部通过
  - Backend contract fake 测试通过
  - SAPI 不存在时不可用路径验证
  - 云 ASR 默认禁用且无 API Key 不外连
  - ConfigDB 默认键写入和读写幂等通过
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 5. M2 流式 ASR + AudioSession 仲裁
  - [x] 5.1 实现 SAPI Live Streaming
    - 在 `DeepBase.Speech.ASR.SAPI.pas` 中添加 `TDeepBaseSAPIASRStream : IASRStream`
    - SAPI 自采麦克风模式，SAPI events 产生 partial/final
    - `FeedAudio`：推送 PCM16 到 SAPI 输入流（如 Spike 验证可行）
    - `SetOnPartial / SetOnFinal`：注册回调
    - `Stop`：best-effort 800ms / hard-limit 3000ms，触发 OnFinal
    - 后台线程轮询 SAPI 事件
    - _Requirements: 2.3, 2.8, 12.3_

  - [x] 5.2 实现低延迟 WinMM capture 优化
    - 根据 M0 Spike 结论调整 buffer 参数
    - 确保不影响现有 batch capture
    - _Requirements: 9.1_

  - [x] 5.3 完善 AudioSession 仲裁实现
    - PTT 抢占 WakeWord 的硬切逻辑
    - PTT 结束后自动恢复 WakeWord
    - TTS 播报中 F2 按下的 Stop + 切换
    - 先到先得策略
    - Trace 覆盖 backend/duration/status/fallback_reason
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_

  - [ ]* 5.4 单元测试：流式 ASR + AudioSession
    - `IASRStream.Stop` 在 hard-limit 内返回
    - AudioSession 状态切换正确性
    - 并发请求麦克风时后到者失败
    - _Requirements: 12.3, 10.4_

- [ ] 6. Checkpoint — M2 流式 ASR 完成
  - FeedAudio 可行性结论写入设计文档
  - 低延迟采集不影响现有 batch capture
  - AudioSession 仲裁有单元测试
  - Trace 覆盖 backend/duration/status/fallback_reason
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 6.5 M2.5 SenseVoice Backend（默认本地 ASR）
  - [ ] 6.5.1 扩展 `DeepBase.Inference.Types.pas` 新增 `TInferenceElementType` + `TInferenceInput`
    - 支持混合 float32/int32 张量输入
    - _Requirements: 2.1_
  - [ ] 6.5.2 扩展 `DeepBase.Inference.Session.pas` 新增 `RunTyped` 方法
    - 根据 ElementType 选择 CreateTensor<Single> 或 CreateTensor<Int32>
    - 现有 Run 方法不改动
  - [ ] 6.5.3 创建 `DeepBase.Speech.FBank.pas`
    - 80 维 FBank 特征提取：Radix-2 FFT（补零到 512）+ 80 Mel 滤波器 + Hamming 窗
    - 输入: 16kHz PCM16 mono，输出: [frames][80] log-Mel energies
    - _Requirements: 9.1_
  - [ ] 6.5.4 创建 `DeepBase.Speech.ASR.SenseVoice.pas`
    - 实现 `TDeepBaseSenseVoiceASR : ISpeechRecognizerEx`
    - LFR 堆叠（7窗口/6步长 → 560 维）+ CMVN 归一化（模型 metadata）
    - CTC greedy decode + tokens.txt 查表
    - 模拟流式：每 500ms decode 产生 OnPartial，Stop 触发 OnFinal
    - initialization 段自注册到 Registry（Priority=5）
    - 依赖 DeepBase.Inference 模块加载 ONNX 模型
    - _Requirements: 2.1, 2.3, 12.1, 12.2_
  - [ ] 6.5.5 扩展 `DeepBase.Speech.Types.pas` 枚举
    - `TASRBackendKind` 增加 `abkSenseVoice`
    - _Requirements: 2.1_
  - [ ] 6.5.6 扩展 `DeepBase.Speech.Config.pas` 配置键
    - 新增 SenseVoice 配置键常量
    - 默认 ASR backend 改为 sensevoice
    - _Requirements: 7.1, 7.2_
  - [ ] 6.5.7 更新 `DeepBaseSpeechASR.dpk`
    - 加入 FBank + SenseVoice 单元
    - _Requirements: 19.1_

- [ ] 7. M3 DeepInput 完全重构
  - [x] 7.1 评审 DeepInput 现有语音代码
    - 列出 DeepInput 中所有语音相关单元和接口
    - 确认替换映射关系
    - _Requirements: 12.4_

  - [x] 7.2 逐一替换 DeepInput 语音单元
    - 拆掉 DeepInput 内部 ASR/TTS 代码
    - 直接依赖 `DeepBaseFeaturesASR.dpk`
    - 调用 `TSpeechService.ASR.StartStreaming` 实现流式听写
    - _Requirements: 12.1, 12.2, 12.4_

  - [ ] 7.3 DeepInput 回归测试
    - 验证旧用户场景（听写、候选词插入）行为不变
    - _Requirements: 12.4_

- [ ] 8. M4 DeepLaunch F2/PTT MVP
  - [ ] 8.1 DeepLaunch 语音版接入
    - 调用 `TSpeechService.TranscribeFromMic`（F2 入口）
    - 调用 `TSpeechService.Speak`（语音反馈）
    - Bootstrap 中调用 Schema/Governance 注册
    - _Requirements: 11.1, 11.3_

  - [ ] 8.2 DeepLaunch 设置页 + 麦克风授权
    - 语言选择（`speech.asr.language` / `speech.tts.language`）
    - Backend 选择
    - 麦克风权限提示（消费方职责）
    - _Requirements: 7.7, 14.4_

  - [ ]* 8.3 集成测试：DeepLaunch F2 → 录音 → 识别 → 候选系统
    - _Requirements: 11.1_

- [ ] 9. Checkpoint — M4 DeepLaunch MVP 完成
  - F2 转录 + TTS 反馈端到端可用
  - 屏幕阅读器检测生效
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 10. M5 WakeWord Beta
  - [ ] 10.1 创建 `DeepBase.Speech.WakeWord.pas`
    - 实现 `TDeepBaseSAPIWakeWordDetector : IWakeWordDetector`
    - `SetWords`：验证词长 ≥ 2，归一化（全/半角统一、零宽字符剥离），生成 SRGS XML
    - `GetWords`：返回归一化后的词表
    - `Start`：检查 Governance 门禁 + Voice Access 检测，启动后台监听线程
    - `Stop`：best-effort 300ms / hard-limit 1500ms 释放麦克风
    - `SetOnWakeDetected`：注册回调
    - 环形缓冲区：保存前后 500 ms 音频供 `TWakeEvent.AudioSnippet`
    - initialization 段自注册到 Registry
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8_

  - [ ]* 10.2 PBT: 热词词表往返（P13）
    - **Property 13: WakeWord word list round-trip**
    - 生成器：随机长度（1..20）中文词数组，每词 2..8 字
    - 属性：`SetWords(words); GetWords()` 集合相等
    - **Validates: Requirements 16.1**

  - [ ]* 10.3 单元测试：WakeWord
    - `SetWords` 短词/空词/零宽字符/emoji 抛出异常（Req 4.5, 16.3）
    - Governance 门禁 Disabled 时 `Start` 返回 False（Req 4.6）
    - Voice Access 运行时 `Start` 返回 False（Req 4.8）
    - `IsAvailable` 在无 SAPI 时返回 False（Req 4.7）
    - _Requirements: 4.5, 4.6, 4.7, 4.8, 16.3_

  - [x] 10.4 在 `DeepBaseFeaturesWake.dpk` 中加入 WakeWord 单元
    - _Requirements: 19.1_

  - [ ] 10.5 DeepLaunch WakeWord 集成
    - 默认关闭，独立授权
    - 常驻状态提示
    - 与 PTT 仲裁（AudioSession 硬切）
    - _Requirements: 11.4, 10.2_

- [ ] 11. Checkpoint — M5 WakeWord Beta 完成
  - WakeWord fake 测试覆盖词长校验/阈值边界/门禁关闭/Stop 释放时限
  - 真实麦克风验收记录 CPU/内存/误触率/漏触率/Stop 时延
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 12. M6 稳定化 + 合规文档
  - [ ] 12.1 全模块回归测试
    - 运行所有 speech-headless 测试
    - 运行 speech-windows-sapi-nightly 测试
    - 确认 P1–P4, P12, P13 PBT 全部通过（≥100 次迭代）
    - _Requirements: 9.1, 9.2, 15.1, 15.2_

  - [ ] 12.2 合规文档编写
    - 隐私告知文案（麦克风权限 / 声纹说明 / 云 ASR 联网范围）
    - 声纹定位声明："本地声纹相似度检查，用于降低误触发，不用于身份认证"
    - 数据删除/禁用/撤回同意流程文档
    - DPAPI 跨机器迁移限制说明
    - _Requirements: 14.1, 14.2, 14.3_

  - [ ] 12.3 Trace 与可观测性验收
    - 验证所有 Backend 切换/降级/错误路径有 Trace 覆盖
    - 验证 `speech.trace.audio_payload_enabled=0` 时无 PCM 泄漏
    - 验证 Trace 时间戳使用 QueryPerformanceCounter
    - _Requirements: 13.1, 13.5, 13.6, 10.5, 10.6, 17.2_

  - [ ] 12.4 Stop 时限验收
    - 验证 WakeWord Stop: best-effort 300ms / hard-limit 1500ms
    - 验证 TTS Stop: best-effort 150ms / hard-limit 800ms
    - 验证 ASR Stop→Final: best-effort 800ms / hard-limit 3000ms
    - _Requirements: 3.3, 4.4, 12.3_

- [ ] 13. Checkpoint — M6 稳定化完成
  - 所有 headless + nightly 测试通过
  - 合规文档完成
  - Trace 覆盖率验收通过
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 14. M7 Voiceprint speaker check
  - [x] 14.1 创建 `DeepBase.Speech.MFCC.pas`
    - 纯 Delphi MFCC 特征提取（39 维）
    - 参数：帧长 25ms / 帧移 10ms / 汉明窗 / 40 Mel 滤波器 / 13 系数 / 一阶+二阶差分
    - 输入格式：16 kHz PCM16 单声道
    - _Requirements: 5.6_

  - [ ]* 14.2 PBT: MFCC 确定性（P5）
    - **Property 5: ExtractFeatures determinism**
    - 生成器：随机 PCM16 音频（≥100ms 时长）
    - 属性：两次调用 `ExtractFeatures` 返回相同向量
    - **Validates: Requirements 5.6**

  - [x] 14.3 创建 `DeepBase.Speech.DTW.pas`
    - DTW 距离计算（Sakoe-Chiba 带宽约束 = 序列长度 × 0.1）
    - 欧氏距离度量
    - 归一化距离（除以路径长度）
    - _Requirements: 5.5_

  - [ ]* 14.4 PBT: DTW 对称性（P6）
    - **Property 6: DTW symmetry**
    - 生成器：两个随机非空特征向量
    - 属性：`|DTW(X, Y) - DTW(Y, X)| < 1e-9`
    - **Validates: Requirements 5.5**

  - [ ]* 14.5 PBT: DTW 非负性与自距离（P7）
    - **Property 7: DTW non-negativity and self-distance**
    - 生成器：随机非空特征向量
    - 属性：`DTW(X, Y) ≥ 0` 且 `DTW(X, X) = 0`
    - **Validates: Requirements 5.5**

  - [x] 14.6 创建 `DeepBase.Speech.Voiceprint.pas`
    - 实现 `TDeepBaseVoiceprintService : IVoiceprint`
    - `EnrollProfile`：≥3 段样本 → MFCC 提取 → 均值向量 → DPAPI 加密 → 写 `voice_profiles`
    - `DeleteProfile`：删除档案记录
    - `ListProfiles`：按 OwnerApp 过滤
    - `Verify`：提取 MFCC → DTW 距离 vs 档案均值向量 → `Match = Distance < Threshold`
    - `Identify`：遍历所有档案，返回距离最小且 Match=True 的 ProfileId
    - Governance 门禁：`speech.voiceprint.enabled`
    - initialization 段自注册到 Registry
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.8, 5.9_

  - [ ]* 14.7 PBT: Verify Match 等价于 Distance < Threshold（P8）
    - **Property 8: Verify Match equivalence**
    - 生成器：随机音频 + 随机已注册 Profile
    - 属性：`Verify(A, P.Id).Match = (Verify(A, P.Id).Distance < P.Threshold)`
    - **Validates: Requirements 5.5**

  - [ ]* 14.8 PBT: Verify 确定性（P9）
    - **Property 9: Verify determinism**
    - 生成器：随机音频 + 随机 ProfileId
    - 属性：两次调用 `Verify(A, ProfileId)` 返回相同结果
    - **Validates: Requirements 5.7**

  - [ ]* 14.9 PBT: 声纹特征 DPAPI 往返（P14）
    - **Property 14: Voiceprint features DPAPI round-trip**
    - 生成器：随机非空 `TVoiceFeatures`
    - 属性：序列化 → DPAPI 加密 → 存储 → 读取 → DPAPI 解密 → 反序列化 = 原始向量
    - **Validates: Requirements 15.3**

  - [ ] 14.10 启用 `features_hmac` 校验逻辑
    - 根据 ConfigDB 加密状态决定是否启用 HMAC
    - HMAC 计算：`HMAC(features || profile_id || owner_app || feature_version, K_local)`
    - K_local 用 DPAPI 保护
    - _Requirements: 17.4_

  - [x] 14.11 在 `DeepBaseFeaturesVoice.dpk` 中加入 MFCC/DTW/Voiceprint 单元
    - _Requirements: 19.1_

  - [ ] 14.12 DeepLaunch Voiceprint 集成
    - WakeWord 命中后可选声纹验证
    - 声纹登记 UI（下游职责，DeepBase 只提供接口）
    - 删除/撤回/跨应用授权
    - _Requirements: 11.5, 14.1_

  - [ ]* 14.13 单元测试：Voiceprint
    - `EnrollProfile` 样本不足（<3）时失败
    - `EnrollProfile` 样本时长 < 500ms 或全静音时失败（Req 5.9）
    - Governance 门禁 Disabled 时 `Enroll/Verify/Identify` 拒绝（Req 5.8）
    - `DeleteProfile` 后 `ListProfiles` 不再返回该档案（Req 5.4）
    - owner_app 隔离验证
    - _Requirements: 5.2, 5.4, 5.8, 5.9_

- [ ] 15. Checkpoint — M7 Voiceprint 完成
  - MFCC/DTW PBT 通过（P5–P9, P14）
  - features 加密验证通过
  - owner_app 隔离测试通过
  - 删除可撤回测试通过
  - 文档不宣称身份认证级能力
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 16. M8 IntentParser / WinRT / Whisper / 云扩展
  - [ ] 16.1 创建 `DeepBase.Speech.Intent.pas`
    - 实现 `TDeepBaseIntentParser : IIntentParser`
    - 规则匹配引擎：`RegisterRule(APattern, AIntent, ASlotExtractor)`
    - `Parse`：先规则匹配，未命中且 LLM 门禁开启时调用 `DeepBase.LLM.Client`
    - LLM 超时处理：超过 `speech.intent.llm_timeout_ms` 降级返回 `Intent='unknown'`
    - initialization 段自注册到 Registry
    - _Requirements: 6.1, 6.2, 6.3, 6.5, 6.6, 6.7_

  - [ ]* 16.2 PBT: IntentParser 幂等（P10）
    - **Property 10: IntentParser idempotence**
    - 生成器：随机文本 + 随机 locale
    - 属性：两次调用 `Parse(text, locale)` 返回相同 `TIntentResult`
    - **Validates: Requirements 6.4**

  - [ ]* 16.3 PBT: IntentParser 增量注册不影响已有规则（P11）
    - **Property 11: IntentParser incremental registration**
    - 生成器：随机规则集 R + 新规则 r（非冲突）
    - 属性：注册 r 后，匹配 R 中规则的文本仍返回相同结果
    - **Validates: Requirements 6.7**

  - [ ]* 16.4 单元测试：IntentParser
    - 规则命中时 Confidence ≥ 0.9（Req 6.2）
    - 未命中时 Intent='unknown', Confidence=0（Req 6.3）
    - LLM 超时降级返回 unknown（Req 6.6）
    - Governance 门禁 `speech.intent.llm_enabled` 关闭时不调用 LLM
    - _Requirements: 6.2, 6.3, 6.5, 6.6_

  - [ ] 16.5 创建 `DeepBase.Speech.ASR.WinRT.pas`（可选）
    - 实现 WinRT SpeechRecognizer Backend（Win10+）
    - `IsAvailable`：检测 WinRT API 可用性
    - 支持 Dictation + Grammar 模式
    - initialization 段自注册到 Registry
    - _Requirements: 2.1_

  - [ ] 16.6 Whisper.cpp 集成（可选，SenseVoice 已作为默认本地 ASR）
    - 实现 `TDeepBaseWhisperASRRecognizer : ISpeechRecognizerEx`
    - 依赖 `whisper.dll` 存在
    - 支持 Batch + Streaming
    - _Requirements: 2.1_

  - [ ] 16.7 云 TTS Backend（可选）
    - 实现云 TTS Backend（Azure/百度）
    - 门禁：`speech.tts.cloud_enabled`
    - _Requirements: 3.1_

- [ ] 17. Final Checkpoint — M8 完成
  - IntentParser PBT 通过（P10–P11）
  - WinRT/Whisper Backend 可用性验证（如实现）
  - 所有 14 个 PBT 属性通过
  - 全模块回归测试通过
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties (P1–P14)
- Unit tests validate specific examples and edge cases
- M0 Spike 不发布，仅产出结论文档
- M7 Voiceprint 和 M8 IntentParser 为后期里程碑，v1 不包含
- 所有 Stop 时限使用 best-effort + hard-limit 双轨，PBT 验证 hard-limit
- 声纹定位为"本地 speaker check"，文档不得宣称身份认证级能力
