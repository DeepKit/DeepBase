# DeepBase.Speech 能力扩展 — Requirements Document

> 版本：2.0（基于扩展方案 v1.0 + 两轮专家评审 + 开发规范 v2.0）
> 消费方：DeepLaunch 语音版、DeepInput（完全重构）；未来可服务 DeepStory/DeepClip 等
> 本文约束：DeepBase 铁律（ConfigDB 唯一配置源 + DPAPI 密钥 + Governance 门禁 + 无 UI）

## Introduction

DeepBase 已有 5 个 Speech 单元（`Types / Service / Audio.WinMM / VAD / ASR.Baidu`），走"门面 + 插件式 Backend"架构。本次扩展在不破坏现有接口前提下，补齐 **ASR 多后端（SAPI / Whisper.cpp 本地） + TTS + WakeWord + Voiceprint + IntentParser** 五项能力，并与 DeepBase.Governance（门禁）+ DeepBase.Security.DPAPI（密钥/声纹加密）+ ConfigDB（配置/档案存储）完成集成。

扩展的首要消费方：

- **DeepLaunch 语音版**（下一轮发布）：F2 / 托盘 / 语音唤醒三入口，转录 → 意图解析 → 候选执行；可选声纹验证防误触。
- **DeepInput**（中文输入法）：持续听写（流式 ASR）→ 候选词插入；**完全重构**（Strategy A），拆掉自有语音代码，直接调用 DeepBase.Speech（DeepInput 未发布，无回归压力）。

设计目标：**下游零 JSON 配置、零外部网络依赖、零第三方 dll 默认引入**；所有云后端必须走 Governance 开关 + DPAPI 密钥。

### 架构约束（二轮评审确认）

- **Registry/Config/Policy/Runtime/Schema 五拆**：不再全塞 Schema.pas
- **AudioSession 仲裁状态机**：Idle → WakeListening → PushToTalk → DictationStreaming → TTSPlaying
- **一 process 一 SAPI worker thread**，所有 SAPI 调用串行化
- **Backend 自注册**（initialization 段），下游只做覆盖/禁用/测试替身
- **dpk 切分 5 个包**：Core / ASR / TTS / Wake / Voice
- **所有 Speech interface 强制 GUID + `SPEECH_API_LEVEL` 常量**
- **Stop 时限 best-effort + hard-limit 双轨**
- **Commerce.Permissions 与 Governance 共存但分层**（Speech.Policy 统一封装）

## Glossary

- **DeepBaseSpeech**：本 feature 的总称，位于 `DeepBase/Features/` 的 Speech 子模块集合。
- **SpeechFacade**：门面类 `TSpeechService`（类级静态门面），暴露 ASR/TTS/WakeWord/Voiceprint/IntentParser/AudioCapture/VAD 七个能力入口。
- **SpeechRegistry**：`DeepBase.Speech.Registry.pas`，Backend 注册、发现、覆盖、禁用。
- **SpeechConfig**：`DeepBase.Speech.Config.pas`，ConfigDB 键定义、默认值、读写、值校验。
- **SpeechPolicy**：`DeepBase.Speech.Policy.pas`，Governance + Commerce.Permissions 的统一策略入口。
- **SpeechRuntime**：`DeepBase.Speech.Runtime.pas`，默认 Backend 选择、降级链、Trace、AudioSession 资源仲裁。
- **ASRBackend**：实现 `ISpeechRecognizerEx`（流式版本为 `IASRStream`）的语音识别后端；现有 `Baidu`，新增 `SAPI`、`WhisperLocal`。
- **TTSBackend**：实现 `ITTSBackend` 的语音合成后端；默认 `SAPI`，可选云 Backend。
- **WakeWordDetector**：实现 `IWakeWordDetector`，基于 SAPI Grammar 的长时监听器。
- **VoiceprintService**：实现 `IVoiceprint`，负责 MFCC 特征提取、档案登记、DTW 验证。定位为**本地声纹相似度检查**，用于降低误触发，不用于身份认证或安全授权。
- **IntentParser**：实现 `IIntentParser`，把 ASR 文本解析为结构化意图；默认规则匹配，可选 LLM Backend（通过 `DeepBase.LLM.Client`）。
- **AudioCapture**：现有 `ISpeechAudioCapture`（WinMM 实现），16 kHz PCM16 单声道。
- **AudioSession**：音频资源仲裁状态机，管理 WakeWord/PTT/Dictation/TTS 之间的麦克风和音频设备独占。
- **VAD**：现有 `TDeepBaseSpeechVAD`，基于 RMS 阈值静音检测。
- **ConfigDB**：DeepBase 的 SQLite 配置库（DB1），所有键值 / 表结构的唯一存放地。
- **Governance**：`DeepBase.Governance.ConfigRegistrar` 代码注册的行为门禁系统。
- **DPAPI**：`DeepBase.Security.DPAPI.TDPAPIHelper.ProtectString / UnprotectString`，Windows 用户态数据保护。
- **VoiceProfile**：一条声纹档案记录，含 MFCC 特征向量、阈值、所属应用。
- **PTT**：Push-To-Talk，按住说话。
- **Dictation / Grammar**：SAPI 两种识别模式。Dictation 自由听写；Grammar 固定词表识别（资源占用低）。
- **BCP-47**：语言标签标准（如 `zh-CN`、`en-US`），用于 ASR/TTS 语言配置。
- **SPEECH_API_LEVEL**：接口版本常量，用于下游检查二进制兼容性。

## Requirements

### Requirement 1: 统一的 Speech 门面与 Backend 注册机制

**User Story:** As a DeepBase 消费方（DeepLaunch/DeepInput），I want 通过单一门面拿到 ASR / TTS / WakeWord / Voiceprint / IntentParser 能力，so that 不需要感知各 Backend 的差异，也不用自己装配依赖。

#### Acceptance Criteria

1. THE SpeechFacade SHALL 暴露 `ASR`、`TTS`、`WakeWord`、`Voiceprint`、`IntentParser`、`AudioCapture`、`VAD` 七个能力入口。
2. WHEN 调用方请求某个能力但该能力没有可用 Backend，THE SpeechFacade SHALL 返回可判定的"不可用"标识（接口 `IsAvailable = False` 或抛出 `EDeepBaseSpeechProviderError`）而不返回 `nil`。
3. THE SpeechRegistry SHALL 支持 Backend 自注册（通过单元 `initialization` 段），下游仅允许覆盖、禁用或注入测试替身。
4. WHERE 调用方未指定 Backend，THE SpeechRuntime SHALL 按"用户在 ConfigDB 指定 → 可用 Backend 降级链（WinRT / SAPI / WhisperLocal / Baidu） → 全部不可用则返回不可用标识"的顺序决定默认 Backend。
5. THE SpeechFacade SHALL 保留现有 `TDeepBaseSpeechService.CreateBaidu` 等构造器签名，确保现有 Baidu 使用方无需改动源码即可升级。
6. THE SpeechRegistry SHALL 为每个注册的 Backend 维护元数据：`Kind`、`Name`、`Local/Cloud`、`RequiresMic`、`SupportsBatch`、`SupportsStreaming`、`SupportsGrammar`。
7. THE DeepBaseSpeech SHALL 为所有 Speech interface 声明 GUID，并暴露 `SPEECH_API_LEVEL` 常量供下游检查二进制兼容性。

### Requirement 2: ASR 多后端与流式识别

**User Story:** As a DeepLaunch/DeepInput 开发者，I want ASR 支持本地（SAPI / Whisper.cpp）与云（Baidu）两类 Backend，且支持流式识别，so that 语音唤醒浮窗能实时显示中间结果，且离线场景可用。

#### Acceptance Criteria

1. THE ASRBackend SHALL 通过 `TASRBackendKind` 枚举区分 `abkBaidu / abkSAPI / abkWhisperLocal / abkWinRT / abkAzure`（Azure 预留枚举，不实现）。
2. THE ASRBackend SHALL 暴露 `Kind`、`IsAvailable`、`SupportsStreaming` 三个自描述方法。
3. WHERE Backend 的 `SupportsStreaming` 返回 True，THE ASRBackend SHALL 提供 `StartStreaming(AOptions): IASRStream` 方法，返回的流对象 SHALL 支持 `FeedAudio / SetOnPartial / SetOnFinal / Stop`。
4. WHERE Backend 支持 Grammar 模式（SAPI），THE ASRBackend SHALL 提供 `LoadGrammar(AWords: TArray<string>)` 方法，加载成功后后续识别仅匹配词表。
5. WHEN Dictation 模式识别到一段语音，THE ASRBackend SHALL 返回 `TSpeechRecognitionResult` 含 `Success / Text / Status / ErrorCode / ErrorMessage`，且在输入音频为空时 `Status` SHALL 为 `srsEmptyAudio`。
6. THE SAPI ASRBackend SHALL 在 Windows 7+ 且安装了对应语言包的环境下 `IsAvailable = True`，否则返回 False 并在 `CheckStatus` 输出缺失原因（包括具体缺失的 recognizer token）。
7. IF 用户在 ConfigDB 把 `speech.default.asr_backend` 设为某一 Backend 名称，THEN THE SpeechRuntime SHALL 优先尝试该 Backend，且当该 Backend 不可用时按降级链回退，且 SHALL 通过 Trace 日志记录实际选中的 Backend 名称。
8. THE ASRBackend SHALL 在流式模式下，对于任一 `FeedAudio` 调用不阻塞超过 100 毫秒（在主流桌面硬件下）。
9. WHEN 云 ASR Backend（Baidu/Azure）被选中，THE SpeechPolicy SHALL 同时验证 `speech.asr.cloud_enabled=Enabled` 门禁和密钥可用性，两者缺一则拒绝使用该 Backend。

### Requirement 3: TTS 合成与中断

**User Story:** As a DeepLaunch 语音版开发者，I want 在收到命令后用语音反馈结果（"已为你打开计算器"），以及 DeepInput 校对朗读场景，so that 产品能提供双向语音交互。

#### Acceptance Criteria

1. THE TTSBackend SHALL 暴露 `Name`、`IsAvailable`、`SupportedLanguages`、`SupportedVoices(ALanguage)`、`Speak(AText, AOptions)`、`SpeakAsync(AText, AOptions, ACallback)`、`Stop` 接口。
2. THE SAPI TTSBackend SHALL 在 Windows 7+ 安装了 SAPI 5.4 的环境下 `IsAvailable = True`。
3. WHEN 调用 `SpeakAsync` 后又在完成前调用 `Stop`，THE TTSBackend SHALL 以 best-effort 150ms / hard-limit 800ms 终止当前合成并释放音频设备，且不调用完成回调。
4. WHEN 同一 TTSBackend 实例上连续两次 `SpeakAsync` 调用，THE TTSBackend SHALL 要么串行执行（第二次等第一次完成），要么中断第一次（行为由实现声明），不得并发导致音频混叠。
5. WHERE 用户在 ConfigDB 设置 `speech.default.tts_voice` 为某个已支持的 Voice Id，THE TTSBackend SHALL 使用该 Voice 作为 `Speak` 的默认音色。
6. IF `AText` 为空字符串或纯空白，THEN THE TTSBackend SHALL 不播放任何声音，且 `SpeakAsync` 回调 SHALL 仍然被调用一次。
7. THE TTTSOptions SHALL 至少包含 `Language / VoiceId / Rate / Volume` 字段。
8. WHERE 检测到屏幕阅读器运行（`SystemParametersInfo(SPI_GETSCREENREADER)`）且 `speech.tts.defer_to_screen_reader=1`，THE TTSBackend SHALL 默认静默（不播放），让屏幕阅读器全权处理语音反馈。

### Requirement 4: 语音唤醒（WakeWord）长时监听

**User Story:** As a DeepLaunch 用户，I want 说出"小启"等热词即可唤醒浮窗，so that 不需要键盘操作也能启动语义遥控。

#### Acceptance Criteria

1. THE WakeWordDetector SHALL 暴露 `IsAvailable / SetWords / GetWords / SetConfidenceThreshold / Start / Stop / SetOnWakeDetected`。
2. WHEN `Start` 之后检测到词表中任一热词且置信度 ≥ 阈值，THE WakeWordDetector SHALL 调用 `OnWakeDetected(TWakeEvent)` 回调，且 `TWakeEvent.MatchedWord` SHALL 等于命中的热词之一，`TWakeEvent.AudioSnippet` SHALL 包含触发时段前后至少 500 毫秒的音频。
3. WHILE 处于 `Start` 与 `Stop` 之间，THE WakeWordDetector SHALL 保持监听状态，即使在期间调用 `SetWords` 或 `SetConfidenceThreshold` 也不退出监听。
4. WHEN 调用 `Stop`，THE WakeWordDetector SHALL 以 best-effort 300ms / hard-limit 1500ms 释放麦克风独占并停止回调。
5. IF `SetWords` 的入参包含长度 < 2 的中文词或空字符串，THEN THE WakeWordDetector SHALL 抛出 `EDeepBaseSpeechError` 且词表不变。
6. THE WakeWordDetector SHALL 通过 Governance 门禁 `speech.wake_word.enabled` 控制启停；当门禁为 Disabled 时，`Start` SHALL 返回失败且不占用麦克风。
7. WHERE 运行平台缺失 SAPI，THE WakeWordDetector SHALL `IsAvailable = False` 且 `Start` SHALL 返回失败。
8. WHERE 检测到 Voice Access 运行（进程名 `VoiceAccess.exe`）且 `speech.wake_word.defer_to_voice_access=1`，THE WakeWordDetector SHALL 默认不启动，`Start` 返回 False。

### Requirement 5: 声纹登记与验证（Voiceprint）— M7

**User Story:** As a DeepLaunch 语音版用户，I want 让系统认识我的声音，so that 别人说热词不会误触我的账号操作。

> 注：声纹定位为**本地声纹相似度检查**，用于降低误触发，不用于身份认证、安全授权、支付、解锁或账号确认。推迟到 M7 实现。

#### Acceptance Criteria

1. THE VoiceprintService SHALL 暴露 `ExtractFeatures / EnrollProfile / DeleteProfile / ListProfiles / Verify / Identify`。
2. WHEN 调用 `EnrollProfile(AUserLabel, APurpose, ASamples)` 且 `Length(ASamples) ≥ 3`，THE VoiceprintService SHALL 返回非空 `TVoiceProfileId` 并在 ConfigDB `voice_profiles` 表写入一条记录。
3. THE `voice_profiles.features` 字段 SHALL 通过 DPAPI 加密存储，且明文 MFCC 向量 SHALL 不出现在任何落盘文件中。
4. WHEN 调用 `DeleteProfile(AId)` 且该档案存在，THE VoiceprintService SHALL 返回 True 且后续 `ListProfiles` 不再返回该档案。
5. WHEN 调用 `Verify(AAudio, AProfileId)`，THE VoiceprintService SHALL 返回 `TVerifyResult` 含 `Match / Score / Distance`，且 `Match` SHALL 等价于 `Distance < Profile.Threshold`。
6. THE VoiceprintService SHALL 对同一段音频多次调用 `ExtractFeatures` 返回相同的特征向量（确定性）。
7. THE VoiceprintService SHALL 在同一段音频上 `Verify` 返回的 `Match` 结果稳定可复现（相同输入 → 相同输出）。
8. WHERE Governance 门禁 `speech.voiceprint.enabled` 为 Disabled，THE VoiceprintService SHALL 拒绝 `EnrollProfile / Verify / Identify` 调用（抛出门禁异常），但 `ListProfiles / DeleteProfile` SHALL 仍允许执行（便于用户撤回数据）。
9. WHEN 调用 `EnrollProfile` 时 `ASamples` 某段时长 < 500 毫秒或全静音，THE VoiceprintService SHALL 返回失败（不写入档案）且抛出 `EDeepBaseSpeechError` 指明问题样本序号。

### Requirement 6: 意图解析（IntentParser）— M8

**User Story:** As a DeepLaunch 语音版开发者，I want 把 ASR 文本解析为结构化意图（动作 + 参数），so that 候选系统能把"打开计算器"映射到具体执行路径。

#### Acceptance Criteria

1. THE IntentParser SHALL 暴露 `Name / IsAvailable / Parse(AText, ALocale): TIntentResult`。
2. WHEN 文本命中已注册的规则（如 "打开 <X>" → `intent=open, target=X`），THE IntentParser SHALL 返回 `TIntentResult` 含 `Intent / Slots / Confidence ≥ 0.9`。
3. WHEN 文本未命中任何规则，THE IntentParser SHALL 返回 `Intent = 'unknown'`，`Confidence = 0`，且 `Slots` SHALL 为空集合。
4. THE IntentParser SHALL 对同一文本同一 Locale 的多次调用返回完全相同的 `TIntentResult`（确定性 / 幂等）。
5. WHERE 调用方注册了 LLM Backend 且 Governance 门禁 `speech.intent.llm_enabled` 开启，THE IntentParser SHALL 在规则未命中时调用 LLM Backend（通过 `DeepBase.LLM.Client`）作为二级解析，且 LLM Backend 的超时 SHALL 不超过 `speech.intent.llm_timeout_ms`（默认 3000 ms）。
6. IF LLM Backend 超时或返回错误，THEN THE IntentParser SHALL 降级返回 `Intent = 'unknown'` 而非抛出异常。
7. THE IntentParser SHALL 以非破坏方式支持规则增量注册（`RegisterRule(APattern, AIntent, ASlotExtractor)`），新规则不影响已注册规则的解析结果。

### Requirement 7: 配置与密钥存储（ConfigDB + DPAPI）

**User Story:** As a DeepBase 守门人，I want 所有 Speech 配置与敏感数据都走 ConfigDB + DPAPI，so that 下游产品不需要额外的 JSON/INI 文件，且密钥不明文落盘。

#### Acceptance Criteria

1. THE DeepBaseSpeech SHALL 不读取任何 `.json / .ini / .yaml` 配置文件，所有运行期配置仅从 ConfigDB 的 `settings` 表读取。
2. THE SpeechConfig SHALL 在首次启动时把以下默认键写入 ConfigDB：`speech.default.asr_backend=auto`、`speech.default.tts_backend=sapi`、`speech.asr.language=zh-CN`、`speech.tts.language=zh-CN`、`speech.wake_word.enabled=0`、`speech.wake_word.threshold=0.7`、`speech.voiceprint.enabled=0`、`speech.intent.llm_enabled=0`、`speech.intent.llm_timeout_ms=3000`、`speech.tts.defer_to_screen_reader=1`、`speech.wake_word.defer_to_voice_access=1`。
3. THE DeepBaseSpeech SHALL 把所有云 Backend 的 API Key / Secret（如 `speech.baidu.app_key`、`speech.baidu.secret_key`）通过 DPAPI 加密后存入 ConfigDB，且读取路径 SHALL 经过 `TDPAPIHelper.UnprotectString`。
4. IF Backend 需要的密钥缺失或解密失败，THEN THE ASRBackend / TTSBackend SHALL `IsAvailable = False` 并在 `CheckStatus` 返回明确错误文本（不得透露密钥内容）。
5. THE DeepBaseSpeech SHALL 通过 `voice_profiles` 表存储声纹档案，schema 变更 SHALL 通过 `DeepBase.Manager.Schema` 注册，遵循现有迁移机制。
6. FOR ALL 用户可配置的 Speech 键，读取配置并回写完全相同的值后再读取，SHALL 得到原始值（配置读写的幂等/往返）。
7. THE SpeechConfig SHALL 对 `speech.asr.language` 和 `speech.tts.language` 进行 BCP-47 归一化（`zh-Hans-CN → zh-CN`、`zh_CN → zh-CN`），未命中已知 locale 时 SHALL 返回错误而非静默 fallback。

### Requirement 8: Governance 门禁集成

**User Story:** As a 合规负责人，I want 所有联网 Backend、长时监听、声纹能力都走 Governance 门禁，so that 企业部署和个人用户都能按需关闭敏感功能。

#### Acceptance Criteria

1. THE SpeechPolicy SHALL 通过 `TConfigRegistrar` 代码注册以下门禁键：`speech.wake_word.enabled`、`speech.voiceprint.enabled`、`speech.intent.llm_enabled`、`speech.asr.cloud_enabled`、`speech.tts.cloud_enabled`。
2. WHEN 门禁 `speech.asr.cloud_enabled = Disabled`，THE SpeechRuntime SHALL 拒绝在降级链中使用云 ASR Backend（Baidu/Azure），即使 `speech.default.asr_backend` 显式指定。
3. WHEN 门禁 `speech.tts.cloud_enabled = Disabled`，THE SpeechRuntime SHALL 拒绝云 TTS Backend，仅允许本地 SAPI。
4. IF 门禁读取失败（ConfigRegistrar 未初始化），THEN THE DeepBaseSpeech SHALL 以"保守模式"运行：仅本地 Backend 可用，云 Backend 和生物识别能力全禁用。
5. THE DeepBaseSpeech SHALL 在门禁状态变更后 1 秒内生效（无需重启进程）。
6. THE SpeechPolicy SHALL 统一封装 Governance 和 Commerce.Permissions 两套策略体系，对上层暴露单一策略查询接口。

### Requirement 9: 音频采集与 VAD（保持现状 + 契约锁定）

**User Story:** As a 现有 Baidu ASR 的维护者，I want 扩展不破坏现有采集与 VAD 行为，so that 已发布的产品零回归。

#### Acceptance Criteria

1. THE AudioCapture SHALL 保持 `ISpeechAudioCapture` 现有签名（`StartRecording / StopRecording / GetAudioData / GetPCMData / GetFloatSamples / IsRecording / LastError / SampleRate`）。
2. THE VAD SHALL 保持 `TDeepBaseSpeechVAD` 的构造参数与 `ProcessFrame / ProcessAll / Reset` 契约。
3. FOR ALL PCM16 字节序列 `ABytes`，`TSpeechAudioUtils.PCM16ToFloat(ABytes)` 返回的 `Single` 数组长度 SHALL 等于 `Length(ABytes) div 2`，且每个值 SHALL 在 `[-1.0, 1.0]` 闭区间内。
4. FOR ALL 有效 `TSpeechAudioData`，`DurationMs` 返回值 SHALL 等于 `round(Length(PCMData) * 1000 / BytesPerSecond)`（与 SampleRate/Channels/BitsPerSample 一致）。
5. WHERE 现有 Baidu Backend 单元测试存在，扩展实施后所有既有测试 SHALL 继续通过。

### Requirement 10: AudioSession 资源仲裁

**User Story:** As a DeepBase.Speech 运行时，I want 管理 WakeWord/PTT/Dictation/TTS 之间的麦克风和音频设备独占，so that 多个语音功能不会互相干扰。

#### Acceptance Criteria

1. THE SpeechRuntime SHALL 维护 AudioSession 状态机，状态包括：`Idle / WakeListening / PushToTalk / DictationStreaming / TTSPlaying`。
2. WHEN 用户按 F2（PTT）且当前状态为 WakeListening，THE SpeechRuntime SHALL 硬切到 PushToTalk（WakeWord 暂停），PTT 结束后自动恢复 WakeListening。
3. WHEN TTS 播报中用户按 F2，THE SpeechRuntime SHALL 立即 Stop TTS（best-effort 150ms / hard-limit 800ms），进入 PushToTalk。
4. WHEN 两个下游应用（DeepLaunch + DeepInput）同时请求麦克风，THE SpeechRuntime SHALL 以先到先得策略处理，后到者获得失败结果。
5. THE SpeechRuntime SHALL 对所有状态切换写 Trace 日志：`trace_id / backend / session_kind / duration / status / fallback_reason`。
6. THE SpeechRuntime SHALL 使用高精度时钟（`QueryPerformanceCounter`）作为 Trace 时间戳源。

### Requirement 11: DeepLaunch 语音版消费场景

**User Story:** As a DeepLaunch 语音版开发者，I want 通过 DeepBase.Speech 一套调用完成 F2 转录、热词唤醒、可选声纹验证、TTS 反馈四件事，so that DeepLaunch 端只写薄胶水代码。

#### Acceptance Criteria

1. WHEN DeepLaunch 调用 `TSpeechService.TranscribeFromMic('zh-CN', 30, 3000)`，THE SpeechFacade SHALL 启动麦克风、在 3 秒静音或 30 秒超时后停止，并返回 `TSpeechRecognitionResult`。
2. WHEN 热词触发后 DeepLaunch 取到 `TWakeEvent.AudioSnippet` 调用 `Voiceprint.Verify(...)`，THE VoiceprintService SHALL 返回可判定结果在 200 毫秒内（在主流桌面硬件下）。
3. WHEN DeepLaunch 调用 `TSpeechService.Speak('已为你打开计算器')`，THE TTSBackend SHALL 使用当前默认 Backend 进行朗读；若默认 Backend 不可用，THE SpeechRuntime SHALL 按 TTS 降级链选择下一个可用 Backend。
4. WHERE DeepLaunch 设置 `speech.wake_word.enabled=1` 且声纹门禁关闭，THE WakeWordDetector SHALL 在命中热词后直接模拟触发（不做声纹校验）。
5. WHERE DeepLaunch 同时开启声纹门禁，THE WakeWordDetector 命中后的声纹校验失败 SHALL 使 DeepLaunch 侧获得 `Match=False` 的结果，且 DeepBase.Speech 本身 SHALL 不直接决定"是否打开浮窗"（决策权留给 DeepLaunch）。
6. THE DeepLaunch 语音版 SHALL 不执行需 UAC/提权的管理员操作（合规产品约束）。

### Requirement 12: DeepInput 消费场景（流式听写 — 完全重构）

**User Story:** As a DeepInput 开发者，I want 在用户按住快捷键时启动流式 ASR 并获得实时中间结果，so that 浮标能随说随显，松手即落字。

#### Acceptance Criteria

1. WHEN DeepInput 调用 `TSpeechService.ASR.StartStreaming(TASROptions.Create('zh-CN', asrDictation))`，THE ASRBackend SHALL 返回 `IASRStream` 且在 500 毫秒内进入可 `FeedAudio` 状态。
2. WHILE 流式识别进行中，THE ASRBackend SHALL 对每次 `FeedAudio` 最终最多产生一次 `OnPartial` 回调（可聚合），且累计 `OnPartial` 的 `Text` 字段 SHALL 以追加为主（允许后向修订替换前向部分）。
3. WHEN DeepInput 调用 `IASRStream.Stop`，THE ASRBackend SHALL 以 best-effort 800ms / hard-limit 3000ms 触发一次 `OnFinal`，之后 SHALL 不再回调 `OnPartial`。
4. THE DeepInput 完全重构 SHALL 拆掉所有内部语音代码，直接依赖 DeepBase.Speech（无 Adapter 层，DeepInput 未发布无回归压力）。

### Requirement 13: 可观测性与错误处理

**User Story:** As a 排障工程师，I want Speech 各 Backend 出错时能拿到可定位的错误码和状态，so that 能在生产环境快速定位"是麦克风没权限、还是云 Key 无效、还是语音包缺失"。

#### Acceptance Criteria

1. THE DeepBaseSpeech SHALL 通过 `TSpeechRecognitionStatus` 枚举区分 `srsSuccess / srsEmptyAudio / srsProviderNotReady / srsHttpError / srsParseError / srsServiceError / srsInternalError`。
2. IF 麦克风设备不可用，THEN THE AudioCapture SHALL 在 `StartRecording` 返回 False 且 `LastError` 包含"no input device"类可读文本。
3. IF SAPI 5.4 未安装或中文语言包缺失，THEN THE SAPI ASRBackend `CheckStatus` SHALL 返回 False 且 `AError` 明确列出缺失项（包括具体 recognizer token 名称）。
4. IF 云 Backend HTTP 请求超时，THEN THE ASRBackend SHALL 返回 `Status=srsHttpError` 且 `ErrorMessage` 包含超时秒数。
5. THE DeepBaseSpeech SHALL 不在错误消息中直接输出完整 API Key / Secret 原文（防泄漏）。
6. THE DeepBaseSpeech SHALL 禁止在 Trace 日志中记录 PCM payload（`speech.trace.audio_payload_enabled=0` 为默认值）。

### Requirement 14: 隐私与合规（可撤回同意）

**User Story:** As a 终端用户，I want 能够一键删除声纹、关闭麦克风长时监听，so that 我的生物识别数据可控可撤回。

#### Acceptance Criteria

1. THE VoiceprintService SHALL 提供 `DeleteProfile(AId)` 和 `ListProfiles(AOwnerApp)`，用于下游构建"导出 / 删除"入口。
2. WHEN 用户通过上层 UI 将门禁 `speech.wake_word.enabled` 关闭，THE WakeWordDetector 的下一次 `Start` SHALL 返回失败，已在监听的实例 SHALL 在 1 秒内自停。
3. THE DeepBaseSpeech SHALL 不落盘任何原始音频片段到磁盘；必要的临时内存数据 SHALL 在 `IASRStream.Stop` 后释放。
4. THE DeepBaseSpeech SHALL 在首次调用 `AudioCapture.StartRecording` 时不自动触发系统麦克风对话框 —— 该职责属于消费方（下游产品知情告知）。

### Requirement 15: 音频格式往返（Parser/Serializer 类）

**User Story:** As a 测试工程师，I want 保证 PCM / 浮点 / 字节序列之间的编解码无损，so that VAD / 声纹 / ASR 共享同一份音频数据时不会引入精度漂移。

#### Acceptance Criteria

1. FOR ALL 字节长度为偶数的 PCM16 字节数组 `B`，`FloatToPCM16(PCM16ToFloat(B))` 返回的字节数组 SHALL 与 `B` 按字节相等（round-trip）。
2. FOR ALL `Single` 数组 `S`（取值 `[-1.0, 1.0)`），`PCM16ToFloat(FloatToPCM16(S))` 返回的 `Single` 数组每个元素 SHALL 与 `S` 对应元素的差异 < 1/32768（量化误差上界）。
3. FOR ALL 已登记声纹档案 `P`，把 `P.Features` 经过"DPAPI 加密 → 存库 → 读库 → DPAPI 解密 → 反序列化"五步往返后，SHALL 恢复为与 `P.Features` 元素级相等的向量。

### Requirement 16: 命令行 / grammar 词表解析（Parser 类）

**User Story:** As a WakeWord 使用者，I want 提供一个纯字符串词表就能注册热词，so that 不需要写 SAPI XML。

#### Acceptance Criteria

1. FOR ALL 合法中文热词数组（每个词长度 ≥ 2，不含控制字符），`SetWords(AWords)` + 序列化为 SAPI Grammar + 再解析 SHALL 能还原为相同词集合（集合相等，顺序可变）。
2. IF `AWords` 含未归一化的全/半角混排，THEN THE WakeWordDetector SHALL 统一归一化后再注册，且归一化后的词表对外可读（`GetWords`）。
3. IF `AWords` 含非 BMP 字符、控制字符、零宽字符（U+200B/200C/200D）或 emoji，THEN THE WakeWordDetector SHALL 抛出 `EDeepBaseSpeechError` 并拒绝注册。
4. THE WakeWordDetector SHALL 不做繁简自动转换，用户须显式提供目标词形。

### Requirement 17: 安全与威胁模型

**User Story:** As a 安全工程师，I want 语音链路的攻击面被识别和缓解，so that WakeWord/Voiceprint 启用后不会引入新的安全漏洞。

#### Acceptance Criteria

1. THE DeepBaseSpeech design.md SHALL 包含 STRIDE 威胁模型表，覆盖 Spoofing / Tampering / Repudiation / Information Disclosure / Denial of Service / Elevation of Privilege。
2. THE DeepBaseSpeech SHALL 禁止 `TSpeechAudioData` 进入 Log/Trace/崩溃 dump。
3. WHERE ConfigDB SQLite 加密已启用（独立基础设施任务），THE DeepBaseSpeech SHALL 依赖 ConfigDB 加密作为主防线保护 `voice_profiles.features`。
4. THE `voice_profiles` 表 Schema SHALL 预留 `features_hmac` 列（M1 就位），HMAC 校验逻辑推迟到 M7 启用（降为 P2 优先级）。

### Requirement 18: 可访问性共存

**User Story:** As a 使用屏幕阅读器的用户，I want DeepBase.Speech 不干扰我的辅助技术，so that 我能正常使用 NVDA/JAWS/Narrator。

#### Acceptance Criteria

1. WHERE `speech.tts.defer_to_screen_reader=1`（默认），THE TTSBackend SHALL 在检测到屏幕阅读器运行时静默不播放。
2. WHERE `speech.wake_word.defer_to_voice_access=1`（默认），THE WakeWordDetector SHALL 在检测到 Voice Access 运行时不启动监听。
3. THE SpeechRuntime SHALL 在选择默认 TTS voice 时跳过被其他进程占用的 voice（如屏幕阅读器正在使用的 voice）。

### Requirement 19: 发布工程与包切分

**User Story:** As a 发布工程师，I want Speech 模块按功能切分 dpk 包，so that 下游只引入需要的能力，不增加不必要的二进制体积。

#### Acceptance Criteria

1. THE DeepBaseSpeech SHALL 切分为 5 个 dpk 包：`DeepBaseFeatures.dpk`（Core: Types/Service/Registry/Config/Policy/Runtime/AudioCapture/VAD）、`DeepBaseFeaturesASR.dpk`（ASR Backends）、`DeepBaseFeaturesTTS.dpk`（TTS Backend）、`DeepBaseFeaturesWake.dpk`（WakeWord + AudioSession 扩展）、`DeepBaseFeaturesVoice.dpk`（MFCC/DTW/Voiceprint）。
2. THE DeepBaseSpeech SHALL 要求最低 Delphi 版本 `CompilerVersion >= 37.0`。
3. THE DeepBaseSpeech SHALL 为所有 Speech interface 声明 GUID，新增方法走新接口（如 `IASRStream2 = interface(IASRStream)`），不在已发布 interface 上追加方法。
4. THE DeepBaseSpeech SHALL 暴露 `const SPEECH_API_LEVEL = 1` 供下游检查兼容性。

## Decision Log（已决策，不再开放）

| ID | 问题 | 决策 |
|---|---|---|
| D1 | Phase 1 开工时机 | ✅ 立刻开工（M0 Spike 前置） |
| D2 | DeepInput 迁移策略 | ✅ **完全重构（Strategy A）**（未发布，无回归压力） |
| D3 | 声纹 v2 时机 | ✅ 推迟到 M7（v1 不做 Voiceprint） |
| D4 | Whisper.cpp 优先级 | ✅ M8 后 |
| D5 | TTS SSML 支持 | ✅ 暂不支持 |
| D6-orig | 用户自定义唤醒词 | ✅ 支持（词长 ≥ 2） |
| D7 | 意图解析复用 DeepLLM | ✅ 复用 DeepBase.LLM.Client |
| D8 | Azure ASR 预留 | ✅ 保留枚举，不实现 |
| D6-new | Commerce.Permissions vs Governance | ✅ **共存但分层**（Speech.Policy 统一封装） |
| A4 | 声纹 HMAC 防篡改 | ✅ **降为 P2**（ConfigDB SQLite 加密为主防线） |
| E1 | TTS 让位屏幕阅读器 | ✅ `speech.tts.defer_to_screen_reader=1` |
| E3 | Voice Access 冲突 | ✅ `speech.wake_word.defer_to_voice_access=1` |
| E4 | DeepLaunch 热键 | ✅ F2 保留单键，备用组合键可选 |
| B2 | Stop 时限 | ✅ best-effort + hard-limit 双轨 |
| C3 | 语言键拆分 | ✅ `speech.asr.language` + `speech.tts.language` |
| D1-dpk | dpk 切分 | ✅ 切分为 5 个包 |
| D2-abi | 接口 GUID + API level | ✅ 所有 Speech interface 强制 GUID + SPEECH_API_LEVEL |
| DB加密 | ConfigDB SQLite 加密 | ✅ 只加密 ConfigDB，独立基础设施任务 |

## Notes

- 本需求文档的 EARS 形式重点刻画契约级行为，不预设实现方式；具体 COM 接口、MFCC 参数、DTW 距离定义放到 design.md。
- Requirement 15 / 16 的 round-trip / parser 类条款专门为 property-based testing 铺路。
- 所有 "best-effort / hard-limit" 的性能上限均视作可观测指标，具体基线由 design.md 的 Testing Strategy 制定。
- Voiceprint（Req 5）推迟到 M7，IntentParser（Req 6）推迟到 M8，v1 不包含。
- 里程碑路径：M0 Spike → M1 Runtime 骨架 → M2 流式 ASR → M3 DeepInput 重构 → M4 DeepLaunch F2/PTT MVP → M5 WakeWord Beta → M6 稳定化 → M7 Voiceprint → M8 IntentParser/WinRT/Whisper/云扩展。
