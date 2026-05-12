# DeepBase.Speech 能力扩展 — Tasks

> 对应 requirements.md + design.md v1.0
> 测试框架：DUnitX + PBT（属性测试）
> 分期：Phase 1（SAPI+TTS）→ Phase 2（WakeWord）→ Phase 3（DeepInput 迁移）→ Phase 4（声纹）→ Phase 5（合规）

---

## Phase 0：摸底与准备

- [ ] 0.1 读取并记录现有 5 个 Speech 单元的完整公开接口
  - `DeepBase.Speech.Types.pas`：所有类型、接口、枚举
  - `DeepBase.Speech.Service.pas`：`TDeepBaseSpeechService` 所有方法
  - `DeepBase.Speech.Audio.WinMM.pas`：`TDeepBaseWinMMAudioCapture` 实现细节
  - `DeepBase.Speech.VAD.pas`：`TDeepBaseSpeechVAD` 构造参数与方法
  - `DeepBase.Speech.ASR.Baidu.pas`：`TDeepBaseBaiduSpeechRecognizer` 实现
  - 输出：接口摸底笔记（注释形式，不新建文件）

- [ ] 0.2 确认 SAPI COM 接口在 Delphi 37.0 的导入路径
  - 检查 `Winapi.ActiveX`、`Winapi.SpeechLib` 或手写 COM 声明
  - 确认 `ISpRecognizer / ISpVoice / ISpRecoGrammar` 可用

- [ ] 0.3 确认 `DeepBase.Manager.Schema` 的迁移注册 API
  - 读取现有 Schema 迁移示例，确认 `RegisterMigration` 调用方式

- [ ] 0.4 确认 `DeepBase.Security.DPAPI` 的 `ProtectString / UnprotectString` 签名

---

## Phase 1：SAPI ASR + TTS + 门面扩展（2 周）

### 1.1 扩展 Types

- [ ] 1.1.1 在 `DeepBase.Speech.Types.pas` 中添加新类型
  - `TASRMode`、`TASRBackendKind`、`TASROptions`、`TASRPartialResult`
  - `IASRStream`、`ISpeechRecognizerEx`
  - `TTTSVoice`、`TTTSOptions`、`ITTSBackend`
  - `TWakeEvent`、`IWakeWordDetector`
  - `TVoiceProfileId`、`TVoiceProfileInfo`、`TVoiceFeatures`、`TVerifyResult`、`IVoiceprint`
  - `TIntentSlot`、`TIntentResult`、`IIntentParser`
  - 保持现有类型签名不变

- [ ] 1.1.2 添加 `TSpeechAudioUtils.FloatToPCM16`（PCM16ToFloat 的逆操作）
  - 输入：`TArray<Single>`（值域 [-1.0, 1.0)）
  - 输出：`TBytes`（PCM16 字节序列）

### 1.2 SAPI ASR Backend

- [ ] 1.2.1 创建 `DeepBase/Features/DeepBase.Speech.ASR.SAPI.pas`
  - 实现 `TDeepBaseSAPIASRRecognizer : ISpeechRecognizerEx`
  - `IsAvailable`：`CoCreateInstance(CLSID_SpInprocRecognizer)` 检测
  - `CheckStatus`：返回缺失 SAPI 或语言包的可读原因
  - `Recognize`（同步 Dictation）：录音 → SAPI 识别 → 返回 `TSpeechRecognitionResult`
  - `StartStreaming`：返回 `TDeepBaseSAPIASRStream`
  - `LoadGrammar`：生成 SRGS XML → `LoadCmdFromMemory`

- [ ] 1.2.2 创建 `TDeepBaseSAPIASRStream : IASRStream`（在同文件）
  - `FeedAudio`：推送 PCM16 到 SAPI 输入流
  - `SetOnPartial / SetOnFinal`：注册回调
  - `Stop`：停止识别，触发 `OnFinal`
  - 后台线程轮询 SAPI 事件

### 1.3 SAPI TTS Backend

- [ ] 1.3.1 创建 `DeepBase/Features/DeepBase.Speech.TTS.SAPI.pas`
  - 实现 `TDeepBaseSAPITTSBackend : ITTSBackend`
  - `IsAvailable`：`CoCreateInstance(CLSID_SpVoice)` 检测
  - `SupportedVoices`：枚举 `SPCAT_VOICES`
  - `Speak`（同步）：`ISpVoice.Speak(SPF_DEFAULT)`
  - `SpeakAsync`：`ISpVoice.Speak(SPF_ASYNC)` + 完成事件线程
  - `Stop`：`ISpVoice.Speak(nil, SPF_PURGEBEFORESPEAK)`
  - 空文本处理：不调用 SAPI，直接触发回调

### 1.4 门面扩展

- [ ] 1.4.1 在 `DeepBase.Speech.Service.pas` 中添加 `TSpeechService` 类
  - 静态方法：`ASR / TTS / WakeWord / Voiceprint / IntentParser / AudioCapture / VAD`
  - `RegisterASRBackend / RegisterTTSBackend / RegisterWakeWordDetector / RegisterVoiceprint / RegisterIntentParser`
  - `TranscribeFromMic`：封装录音 + VAD + 识别
  - `Speak`：封装 TTS 调用
  - ASR 降级链逻辑（见 design.md 7.1）
  - 保守模式：Governance 未初始化时仅本地 Backend

### 1.5 Schema 注册

- [ ] 1.5.1 创建 `DeepBase/Features/DeepBase.Speech.Schema.pas`
  - `RegisterSpeechSchema`：注册 `voice_profiles` 表迁移（版本 `speech_v1`）
  - `RegisterSpeechGovernance`：通过 `TConfigRegistrar` 注册 5 个门禁键
  - `RegisterSpeechDefaults`：写入 Req 7.2 中的 10 个默认 settings 键（仅首次）

### 1.6 DeepBaseFeatures.dpk 更新

- [ ] 1.6.1 在 `DeepBaseFeatures.dpk` 中加入新单元
  - `DeepBase.Speech.ASR.SAPI`
  - `DeepBase.Speech.TTS.SAPI`
  - `DeepBase.Speech.Schema`

### 1.7 Phase 1 测试

- [ ] 1.7.1 单元测试：`Test.DeepBase.Speech.Types.pas`
  - `TTTSOptions.Default` 字段完整性
  - `TIntentResult.Unknown` 字段值
  - `TSpeechAudioData.DurationMs` 边界值（空数据、SampleRate=0）

- [ ] 1.7.2 PBT：PCM16 往返（P1）
  **Validates: Requirements 14.1**
  - 生成器：随机偶数长度（2..65536）字节数组
  - 属性：`FloatToPCM16(PCM16ToFloat(B)) = B`

- [ ] 1.7.3 PBT：Float 往返量化误差（P2）
  **Validates: Requirements 14.2**
  - 生成器：随机长度（1..1024）Single 数组，值域 [-1.0, 1.0)
  - 属性：每个元素差 < 1/32768

- [ ] 1.7.4 PBT：DurationMs 公式（P3）
  **Validates: Requirements 9.4**
  - 生成器：随机 SampleRate（8000/16000/44100）+ 随机 PCMData 长度
  - 属性：`DurationMs = round(Length * 1000 / BytesPerSecond)`

- [ ] 1.7.5 PBT：PCM16ToFloat 范围（P4）
  **Validates: Requirements 9.3**
  - 属性：长度 = Length(B) div 2，每个值 ∈ [-1.0, 1.0]

- [ ] 1.7.6 单元测试：SAPI ASR `IsAvailable / CheckStatus`
  - 在有 SAPI 环境下验证 `IsAvailable=True`
  - 验证 `CheckStatus` 返回非空字符串

- [ ] 1.7.7 单元测试：SAPI TTS `IsAvailable / SupportedVoices`
  - 验证 `IsAvailable=True`（SAPI 环境）
  - 验证 `SupportedVoices` 返回非空列表

- [ ] 1.7.8 单元测试：TTS 空文本处理（Req 3.6）
  - 传入空字符串，验证 `SpeakAsync` 回调被调用一次

- [ ] 1.7.9 单元测试：Governance 门禁拒绝云 Backend（Req 8.2/8.3）
  - mock ConfigRegistrar 返回 Disabled
  - 验证 `TSpeechService.ASR` 不返回云 Backend

---

## Phase 2：WakeWord（1 周）

- [ ] 2.1 创建 `DeepBase/Features/DeepBase.Speech.WakeWord.pas`
  - 实现 `TDeepBaseSAPIWakeWordDetector : IWakeWordDetector`
  - `SetWords`：验证词长度 ≥ 2，生成 SRGS XML
  - `GetWords`：返回当前词表
  - `Start`：检查 Governance 门禁，启动后台监听线程
  - `Stop`：停止线程，500 ms 内释放麦克风
  - `SetOnWakeDetected`：注册回调
  - 环形缓冲区：保存前后 500 ms 音频供 `TWakeEvent.AudioSnippet`

- [ ] 2.2 在 `DeepBaseFeatures.dpk` 中加入 `DeepBase.Speech.WakeWord`

- [ ] 2.3 单元测试：`Test.DeepBase.Speech.WakeWord.pas`
  - `SetWords` 短词/空词抛出异常（Req 4.5）
  - Governance 门禁 Disabled 时 `Start` 返回 False（Req 4.6）
  - `IsAvailable` 在无 SAPI 时返回 False（Req 4.7）

- [ ] 2.4 PBT：热词词表往返（P14）
  **Validates: Requirements 15.1**
  - 生成器：随机长度（1..20）中文词数组，每词 2..8 字
  - 属性：`SetWords(words); GetWords()` 集合相等

---

## Phase 3：DeepInput 迁移 + DeepLaunch 接入（2 周）

- [ ] 3.1 评审 DeepInput 现有语音代码
  - 列出 DeepInput 中所有语音相关单元和接口
  - 确认迁移策略（A+B 渐进，见 design.md 11.2）

- [ ] 3.2 DeepInput 完全重构（Strategy A）
  - 列出 DeepInput 所有语音相关单元，逐一替换为 `TSpeechService` 调用
  - 删除 DeepInput 内部 ASR/TTS 代码，直接依赖 `DeepBaseFeatures.dpk`
  - 回归测试：验证旧用户场景（听写、候选词插入）行为不变

- [ ] 3.3 DeepLaunch 语音版接入
  - 在 DeepLaunch 中调用 `TSpeechService.TranscribeFromMic`（F2 入口）
  - 在 DeepLaunch 中调用 `TSpeechService.Speak`（语音反馈）
  - 在 DeepLaunch Bootstrap 中调用 `RegisterSpeechSchema / RegisterSpeechGovernance`

- [ ] 3.4 集成测试（手动）
  - DeepLaunch F2 → 录音 → 识别 → 候选系统
  - DeepInput 按键 → 流式 ASR → 浮标实时显示

---

## Phase 4：声纹 MFCC + DTW + Voiceprint（3 周）

### 4.1 MFCC

- [ ] 4.1.1 创建 `DeepBase/Features/DeepBase.Speech.MFCC.pas`
  - `TDeepBaseMFCC.Extract(AAudio: TSpeechAudioData): TVoiceFeatures`
  - 参数：帧长 25 ms，帧移 10 ms，汉明窗，40 Mel 滤波器，13 MFCC + Δ + ΔΔ = 39 维
  - 纯 Delphi 实现

- [ ] 4.1.2 PBT：MFCC 确定性（P5）
  **Validates: Requirements 5.6**
  - 生成器：随机长度（1600..16000 样本）PCM16 音频
  - 属性：两次调用结果相同

### 4.2 DTW

- [ ] 4.2.1 创建 `DeepBase/Features/DeepBase.Speech.DTW.pas`
  - `TDeepBaseDTW.Distance(X, Y: TVoiceFeatures): Double`
  - Sakoe-Chiba 带宽约束（带宽 = 序列长度 × 0.1）
  - 归一化（除以路径长度）

- [ ] 4.2.2 PBT：DTW 对称性（P6）
  **Validates: Requirements 5.5（间接）**
  - 属性：`|DTW(X,Y) - DTW(Y,X)| < 1e-9`

- [ ] 4.2.3 PBT：DTW 非负性（P7）
  **Validates: Requirements 5.5（间接）**
  - 属性：`DTW(X,Y) ≥ 0`

- [ ] 4.2.4 PBT：DTW 自距离为零（P8）
  **Validates: Requirements 5.5（间接）**
  - 属性：`DTW(X,X) = 0`

### 4.3 Voiceprint

- [ ] 4.3.1 创建 `DeepBase/Features/DeepBase.Speech.Voiceprint.pas`
  - 实现 `TDeepBaseVoiceprintService : IVoiceprint`
  - `ExtractFeatures`：调用 `TDeepBaseMFCC.Extract`
  - `EnrollProfile`：≥3 样本 → 均值向量 → DPAPI 加密 → 写 `voice_profiles`
  - `DeleteProfile`：删除 ConfigDB 记录
  - `ListProfiles`：查询 ConfigDB，按 `owner_app` 过滤
  - `Verify`：提取 MFCC → DTW 距离 → `Match = Distance < Threshold`
  - `Identify`：遍历档案，返回最近匹配
  - Governance 门禁：`speech.voiceprint.enabled`

- [ ] 4.3.2 单元测试：`Test.DeepBase.Speech.Voiceprint.pas`
  - `EnrollProfile` 样本不足时失败（Req 5.9）
  - `DeleteProfile` 后 `ListProfiles` 不返回（Req 5.4）
  - 门禁 Disabled 时 `EnrollProfile` 抛出门禁异常（Req 5.8）

- [ ] 4.3.3 PBT：Verify Match 等价于 Distance < Threshold（P9）
  **Validates: Requirements 5.5**

- [ ] 4.3.4 PBT：Verify 确定性（P10）
  **Validates: Requirements 5.7**

- [ ] 4.3.5 PBT：声纹特征 DPAPI 往返（P15）
  **Validates: Requirements 14.3**
  - 生成器：随机长度（13..39）Double 数组
  - 属性：加密→存库→读库→解密→反序列化后元素级相等

### 4.4 Schema 更新

- [ ] 4.4.1 在 `DeepBase.Speech.Schema.pas` 中注册 `voice_profiles` 表迁移
  - 版本号 `speech_v1`，通过 `DeepBase.Manager.Schema` 注册

- [ ] 4.4.2 在 `DeepBaseFeatures.dpk` 中加入
  - `DeepBase.Speech.MFCC`
  - `DeepBase.Speech.DTW`
  - `DeepBase.Speech.Voiceprint`

---

## Phase 5：IntentParser（可选，1 周）

- [ ] 5.1 创建 `DeepBase/Features/DeepBase.Speech.Intent.pas`
  - 实现 `TDeepBaseRuleIntentParser : IIntentParser`
  - `RegisterRule`：注册模式 + 意图 + Slot 提取器
  - `Parse`：规则匹配 → 命中返回 `Confidence ≥ 0.9`，未命中返回 `TIntentResult.Unknown`
  - 可选 LLM Backend（Governance 门禁 `speech.intent.llm_enabled`）

- [ ] 5.2 PBT：IntentParser 幂等（P11）
  **Validates: Requirements 6.4**

- [ ] 5.3 PBT：增量注册不影响已有规则（P12）
  **Validates: Requirements 6.7**

- [ ] 5.4 单元测试：LLM 超时降级（Req 6.5/6.6）
  - mock LLM Backend 超时，验证返回 `Intent='unknown'` 不抛异常

---

## Phase 6：合规与文档（1 周）

- [ ] 6.1 PBT：配置读写幂等（P13）
  **Validates: Requirements 7.6**
  - 对所有 Speech 配置键，读取→写回→再读取，验证值不变

- [ ] 6.2 单元测试：首次启动写入默认键（Req 7.2）
  - 清空 ConfigDB，调用 `RegisterSpeechDefaults`，验证 10 个默认键存在

- [ ] 6.3 单元测试：DPAPI 密钥存储（Req 7.3）
  - 写入 API Key，验证 ConfigDB 中存储的值不是明文

- [ ] 6.4 单元测试：密钥缺失时 `IsAvailable=False`（Req 7.4）

- [ ] 6.5 补完 `DeepBase/docs/` Speech 模块文档
  - 更新 `DeepBase.Speech扩展方案.md` 状态为 ✅ 已实施

- [ ] 6.6 DeepLaunch / DeepInput 隐私声明文案
  - 麦克风权限说明（本地处理）
  - 声纹数据说明（生物识别，单独同意）

---

## 决策点跟踪

| ID | 问题 | 状态 | 决策 |
|---|---|---|---|
| D1 | Phase 1 开工时机 | ⏳ 待决策 | — |
| D2 | DeepInput 迁移策略 | ✅ 已决策 | **完全重构（Strategy A）**：DeepInput 拆掉自有语音代码，直接调用 DeepBase.Speech |
| D3 | 声纹 v2 时机 | ⏳ 待决策 | 建议 Phase 4 |
| D4 | Whisper.cpp 优先级 | ⏳ 待决策 | 建议 Phase 4 后 |
| D5 | TTS SSML 支持 | ⏳ 待决策 | 建议暂不支持 |
| D6 | 用户自定义唤醒词 | ⏳ 待决策 | 建议支持（Req 15） |
| D7 | 意图解析复用 DeepLLM | ⏳ 待决策 | 建议复用 |
| D8 | Azure ASR 预留 | ⏳ 待决策 | 建议保留枚举，不实现 |
