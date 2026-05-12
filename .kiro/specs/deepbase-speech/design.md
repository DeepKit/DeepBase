# DeepBase.Speech 能力扩展 — Design Document

> 对应 requirements.md v1.0
> 约束：DeepBase 铁律（ConfigDB + DPAPI + Governance + 无 UI）
> 测试框架：DUnitX（单元测试）+ TestInsight PBT（属性测试，Delphi 原生）

---

## 1. Architecture Overview

### 1.1 现有架构（保持不变）

```
DeepBase/Features/
  DeepBase.Speech.Types.pas          ← 数据类型、接口定义
  DeepBase.Speech.Service.pas        ← 门面 TDeepBaseSpeechService
  DeepBase.Speech.Audio.WinMM.pas    ← ISpeechAudioCapture 实现
  DeepBase.Speech.VAD.pas            ← TDeepBaseSpeechVAD
  DeepBase.Speech.ASR.Baidu.pas      ← ISpeechRecognizer 实现（百度云）
```

### 1.2 扩展后架构

```
DeepBase/Features/
  ── 现有（不改签名）──
  DeepBase.Speech.Types.pas          ← 扩展新类型（TTS/WakeWord/Voiceprint/Intent）
  DeepBase.Speech.Service.pas        ← 扩展 TSpeechService 类级门面
  DeepBase.Speech.Audio.WinMM.pas    ← 不变
  DeepBase.Speech.VAD.pas            ← 不变
  DeepBase.Speech.ASR.Baidu.pas      ← 不变

  ── Phase 1 新增 ──
  DeepBase.Speech.ASR.SAPI.pas       ← SAPI 5.4 Dictation + Grammar ASR
  DeepBase.Speech.TTS.SAPI.pas       ← SAPI 5.4 SpVoice TTS
  DeepBase.Speech.Schema.pas         ← voice_profiles 表 Schema 注册

  ── Phase 2 新增 ──
  DeepBase.Speech.WakeWord.pas       ← SAPI Grammar 长时监听

  ── Phase 4 新增 ──
  DeepBase.Speech.MFCC.pas           ← 纯 Delphi MFCC 特征提取
  DeepBase.Speech.DTW.pas            ← DTW 距离计算
  DeepBase.Speech.Voiceprint.pas     ← 声纹档案管理 + 验证门面

  ── Phase 6（可选）──
  DeepBase.Speech.ASR.WinRT.pas      ← WinRT SpeechRecognizer（Win10+）
  DeepBase.Speech.Intent.pas         ← 规则 + 可选 LLM 意图解析

DeepBase/Tests/Speech/
  Test.DeepBase.Speech.Types.pas     ← PCM round-trip PBT
  Test.DeepBase.Speech.ASR.SAPI.pas  ← SAPI ASR 单元测试
  Test.DeepBase.Speech.TTS.SAPI.pas  ← SAPI TTS 单元测试
  Test.DeepBase.Speech.WakeWord.pas  ← WakeWord 单元测试
  Test.DeepBase.Speech.MFCC.pas      ← MFCC 确定性 PBT
  Test.DeepBase.Speech.DTW.pas       ← DTW 对称性/三角不等式 PBT
  Test.DeepBase.Speech.Voiceprint.pas← Voiceprint 往返 PBT
  Test.DeepBase.Speech.Intent.pas    ← IntentParser 幂等 PBT
```

### 1.3 层次关系

```
消费方（DeepLaunch / DeepInput）
        │
        ▼
  TSpeechService（类级门面，静态方法）
        │
   ┌────┴────────────────────────────────┐
   │                                     │
ISpeechRecognizer  ITTSBackend  IWakeWordDetector  IVoiceprint  IIntentParser
   │                   │               │                │
SAPI / Baidu /    SAPI / Cloud    SAPI Grammar    MFCC+DTW+ConfigDB
WhisperLocal
        │
  ISpeechAudioCapture（WinMM）
  TDeepBaseSpeechVAD
        │
  DeepBase.Governance（门禁）
  DeepBase.Security.DPAPI（密钥/声纹加密）
  ConfigDB（settings + voice_profiles）
```

---

## 2. Interface Definitions

### 2.1 扩展 Types（`DeepBase.Speech.Types.pas`）

```pascal
type
  // ── ASR 扩展 ──
  TASRMode = (asrDictation, asrGrammar, asrCommand);
  TASRBackendKind = (abkBaidu, abkSAPI, abkWhisperLocal, abkWinRT, abkAzure);

  TASROptions = record
    Language: string;
    Mode: TASRMode;
    MaxSilenceMs: Integer;
    MaxDurationMs: Integer;
    class function Create(const ALang: string;
      AMode: TASRMode = asrDictation): TASROptions; static;
  end;

  TASRPartialResult = record
    Text: string;
    IsFinal: Boolean;
  end;

  IASRStream = interface
    ['{A1B2C3D4-0001-0001-0001-000000000001}']
    procedure FeedAudio(const AChunk: TSpeechAudioData);
    procedure SetOnPartial(ACallback: TProc<TASRPartialResult>);
    procedure SetOnFinal(ACallback: TProc<TSpeechRecognitionResult>);
    procedure Stop;
    function IsActive: Boolean;
  end;

  // 扩展现有 ISpeechRecognizer，新增流式 + Grammar
  ISpeechRecognizerEx = interface(ISpeechRecognizer)
    ['{A1B2C3D4-0001-0001-0001-000000000002}']
    function Kind: TASRBackendKind;
    function IsAvailable: Boolean;
    function SupportsStreaming: Boolean;
    function StartStreaming(const AOptions: TASROptions): IASRStream;
    procedure LoadGrammar(const AWords: TArray<string>);
  end;

  // ── TTS ──
  TTTSVoice = record
    Id: string;
    Name: string;
    Language: string;
    Gender: string;
  end;

  TTTSOptions = record
    Language: string;
    VoiceId: string;
    Rate: Integer;    // -10..10，0 为默认
    Volume: Integer;  // 0..100
    class function Default: TTTSOptions; static;
  end;

  ITTSBackend = interface
    ['{A1B2C3D4-0002-0001-0001-000000000001}']
    function Name: string;
    function IsAvailable: Boolean;
    function SupportedLanguages: TArray<string>;
    function SupportedVoices(const ALanguage: string): TArray<TTTSVoice>;
    procedure Speak(const AText: string; const AOptions: TTTSOptions);
    procedure SpeakAsync(const AText: string; const AOptions: TTTSOptions;
      ACallback: TProc);
    procedure Stop;
  end;

  // ── WakeWord ──
  TWakeEvent = record
    MatchedWord: string;
    Confidence: Double;
    Timestamp: TDateTime;
    AudioSnippet: TSpeechAudioData;
  end;

  IWakeWordDetector = interface
    ['{A1B2C3D4-0003-0001-0001-000000000001}']
    function IsAvailable: Boolean;
    procedure SetWords(const AWords: TArray<string>);
    function GetWords: TArray<string>;
    procedure SetConfidenceThreshold(AValue: Double);
    function Start: Boolean;
    procedure Stop;
    procedure SetOnWakeDetected(ACallback: TProc<TWakeEvent>);
  end;

  // ── Voiceprint ──
  TVoiceProfileId = string;

  TVoiceProfileInfo = record
    Id: TVoiceProfileId;
    UserLabel: string;
    Purpose: string;
    SampleCount: Integer;
    Threshold: Double;
    OwnerApp: string;
    CreatedAt: TDateTime;
    Enabled: Boolean;
  end;

  TVoiceFeatures = TArray<Double>;  // MFCC 向量，DPAPI 加密前的明文

  TVerifyResult = record
    Match: Boolean;
    Score: Double;    // 0..1（归一化）
    Distance: Double; // DTW 原始距离
  end;

  IVoiceprint = interface
    ['{A1B2C3D4-0004-0001-0001-000000000001}']
    function ExtractFeatures(const AAudio: TSpeechAudioData): TVoiceFeatures;
    function EnrollProfile(const AUserLabel, APurpose: string;
      const ASamples: TArray<TSpeechAudioData>): TVoiceProfileId;
    function DeleteProfile(const AId: TVoiceProfileId): Boolean;
    function ListProfiles(const AOwnerApp: string = ''): TArray<TVoiceProfileInfo>;
    function Verify(const AAudio: TSpeechAudioData;
      const AProfileId: TVoiceProfileId): TVerifyResult;
    function Identify(const AAudio: TSpeechAudioData): TVoiceProfileId;
  end;

  // ── IntentParser ──
  TIntentSlot = record
    Name: string;
    Value: string;
  end;

  TIntentResult = record
    Intent: string;
    Slots: TArray<TIntentSlot>;
    Confidence: Double;
    class function Unknown: TIntentResult; static;
  end;

  IIntentParser = interface
    ['{A1B2C3D4-0005-0001-0001-000000000001}']
    function Name: string;
    function IsAvailable: Boolean;
    function Parse(const AText, ALocale: string): TIntentResult;
    procedure RegisterRule(const APattern, AIntent: string;
      ASlotExtractor: TFunc<string, TArray<TIntentSlot>>);
  end;
```

### 2.2 门面扩展（`DeepBase.Speech.Service.pas`）

```pascal
type
  // 新增类级静态门面（不替换现有 TDeepBaseSpeechService）
  TSpeechService = class
  public
    // 现有能力（保持兼容）
    class function AudioCapture: ISpeechAudioCapture;
    class function VAD: IVAD;

    // ASR：支持 Backend 选择 + 降级链
    class function ASR(AKind: TASRBackendKind = abkBaidu): ISpeechRecognizerEx;

    // 新增
    class function TTS: ITTSBackend;
    class function WakeWord: IWakeWordDetector;
    class function Voiceprint: IVoiceprint;
    class function IntentParser: IIntentParser;

    // 便捷方法
    class function TranscribeFromMic(const ALanguage: string;
      AMaxSeconds: Integer = 30;
      ASilenceTimeoutMs: Integer = 3000): TSpeechRecognitionResult;
    class procedure Speak(const AText: string; const ALanguage: string = '');

    // Backend 注册（供下游在 Bootstrap 阶段调用）
    class procedure RegisterASRBackend(AKind: TASRBackendKind;
      AFactory: TFunc<ISpeechRecognizerEx>);
    class procedure RegisterTTSBackend(AFactory: TFunc<ITTSBackend>);
    class procedure RegisterWakeWordDetector(AFactory: TFunc<IWakeWordDetector>);
    class procedure RegisterVoiceprint(AFactory: TFunc<IVoiceprint>);
    class procedure RegisterIntentParser(AFactory: TFunc<IIntentParser>);
  end;
```

---

## 3. Backend Implementations

### 3.1 SAPI ASR Backend（`DeepBase.Speech.ASR.SAPI.pas`）

- COM 接口：`ISpRecognizer / ISpRecoContext / ISpRecoGrammar`（`sapi.h` via Delphi import）
- Dictation 模式：`LoadDictationGrammar` + `SetRuleState`
- Grammar 模式：`LoadCmdFromMemory`（动态生成 SRGS XML）
- 流式：`ISpRecoContext.SetNotifyWin32Event` + 后台线程轮询 `GetEvents`
- `IsAvailable`：尝试 `CoCreateInstance(CLSID_SpInprocRecognizer)` 并检查语言包

### 3.2 SAPI TTS Backend（`DeepBase.Speech.TTS.SAPI.pas`）

- COM 接口：`ISpVoice`
- `SpeakAsync`：`ISpVoice.Speak(SPF_ASYNC)` + 完成事件线程
- `Stop`：`ISpVoice.Speak(nil, SPF_PURGEBEFORESPEAK)`
- Voice 枚举：`ISpObjectTokenCategory` 遍历 `SPCAT_VOICES`

### 3.3 WakeWord（`DeepBase.Speech.WakeWord.pas`）

- 基于 SAPI Grammar 模式的 `ISpRecoContext`，常驻后台线程
- 词表 → SRGS XML → `LoadCmdFromMemory`
- 触发时截取前后 500 ms 音频（环形缓冲区）
- Governance 门禁：`speech.wake_word.enabled`

### 3.4 MFCC（`DeepBase.Speech.MFCC.pas`）

- 参数：帧长 25 ms，帧移 10 ms，汉明窗，40 个 Mel 滤波器，13 个 MFCC 系数 + 一阶差分 + 二阶差分 = 39 维
- 纯 Delphi 实现，无外部 dll
- 输入：`TSpeechAudioData`（16 kHz PCM16）

### 3.5 DTW（`DeepBase.Speech.DTW.pas`）

- 标准 DTW，Sakoe-Chiba 带宽约束（带宽 = 序列长度 × 0.1）
- 距离度量：欧氏距离
- 输出：归一化距离（除以路径长度）

### 3.6 Voiceprint（`DeepBase.Speech.Voiceprint.pas`）

- `EnrollProfile`：对 ≥3 段样本提取 MFCC，取均值向量，DPAPI 加密后写 `voice_profiles`
- `Verify`：提取待验证音频 MFCC，DTW 距离 vs 档案均值向量，`Match = Distance < Threshold`
- `Identify`：遍历所有档案，返回距离最小且 `Match=True` 的 ProfileId

---

## 4. Data Storage

### 4.1 ConfigDB Settings 键

| 键 | 默认值 | 说明 |
|---|---|---|
| `speech.default.asr_backend` | `auto` | auto/sapi/winrt/baidu/whisper |
| `speech.default.tts_backend` | `sapi` | sapi/cloud |
| `speech.default.language` | `zh-CN` | BCP-47 |
| `speech.wake_word.enabled` | `0` | Governance 门禁 |
| `speech.wake_word.threshold` | `0.7` | 置信度阈值 |
| `speech.voiceprint.enabled` | `0` | Governance 门禁 |
| `speech.intent.llm_enabled` | `0` | Governance 门禁 |
| `speech.intent.llm_timeout_ms` | `3000` | LLM 超时 |
| `speech.baidu.app_key` | `` | DPAPI 加密 |
| `speech.baidu.secret_key` | `` | DPAPI 加密 |

### 4.2 voice_profiles 表（`DeepBase.Speech.Schema.pas`）

```sql
CREATE TABLE IF NOT EXISTS voice_profiles (
  profile_id   TEXT PRIMARY KEY,
  user_label   TEXT NOT NULL,
  purpose      TEXT NOT NULL,
  sample_count INTEGER NOT NULL,
  features     BLOB NOT NULL,          -- DPAPI 加密的 MFCC 向量
  threshold    REAL NOT NULL DEFAULT 15.0,
  owner_app    TEXT NOT NULL,
  created_at   TEXT NOT NULL,
  updated_at   TEXT NOT NULL,
  enabled      INTEGER NOT NULL DEFAULT 1
);
CREATE INDEX IF NOT EXISTS idx_vp_app     ON voice_profiles(owner_app);
CREATE INDEX IF NOT EXISTS idx_vp_purpose ON voice_profiles(purpose);
```

Schema 通过 `DeepBase.Manager.Schema` 的迁移机制注册（版本号 `speech_v1`）。

### 4.3 DPAPI 存储路径

- API Key：`TDPAPIHelper.ProtectString(AKey)` → `settings.speech.baidu.app_key`
- 声纹特征：`TDPAPIHelper.ProtectBytes(SerializeFeatures(AFeatures))` → `voice_profiles.features`

---

## 5. Governance Integration

通过 `TConfigRegistrar` 代码注册（在 `DeepBase.Speech.Schema.pas` 的 `RegisterSpeechGovernance` 过程中）：

| 门禁键 | 默认 | 说明 |
|---|---|---|
| `speech.wake_word.enabled` | Disabled | 长时麦克风监听 |
| `speech.voiceprint.enabled` | Disabled | 生物识别数据处理 |
| `speech.intent.llm_enabled` | Disabled | 联网 LLM 意图解析 |
| `speech.asr.cloud_enabled` | Disabled | 云 ASR（Baidu/Azure） |
| `speech.tts.cloud_enabled` | Disabled | 云 TTS |

保守模式：当 `TConfigRegistrar` 未初始化时，所有云 Backend 和生物识别能力自动禁用。

---

## 6. Correctness Properties

以下属性用于 Property-Based Testing（PBT），使用 DUnitX + 自定义生成器实现。

### P1 PCM16 往返（Req 14.1）
**Validates: Requirements 14.1**
```
∀ B: TBytes（Length(B) mod 2 = 0）
  FloatToPCM16(PCM16ToFloat(B)) = B
```
生成器：随机偶数长度（2..65536）字节数组。

### P2 Float 往返量化误差（Req 14.2）
**Validates: Requirements 14.2**
```
∀ S: TArray<Single>（每个元素 ∈ [-1.0, 1.0)）
  ∀ i: |PCM16ToFloat(FloatToPCM16(S))[i] - S[i]| < 1/32768
```
生成器：随机长度（1..1024）的 Single 数组，值域 [-1.0, 1.0)。

### P3 DurationMs 公式（Req 9.4）
**Validates: Requirements 9.4**
```
∀ D: TSpeechAudioData（非空，SampleRate > 0）
  D.DurationMs = round(Length(D.PCMData) * 1000 / BytesPerSecond)
  其中 BytesPerSecond = SampleRate * Channels * (BitsPerSample div 8)
```
生成器：随机 SampleRate（8000/16000/44100）、随机 PCMData 长度。

### P4 PCM16ToFloat 范围（Req 9.3）
**Validates: Requirements 9.3**
```
∀ B: TBytes（Length(B) mod 2 = 0）
  Length(PCM16ToFloat(B)) = Length(B) div 2
  ∀ v ∈ PCM16ToFloat(B): v ∈ [-1.0, 1.0]
```

### P5 ExtractFeatures 确定性（Req 5.6）
**Validates: Requirements 5.6**
```
∀ A: TSpeechAudioData（有效 PCM16，时长 ≥ 100ms）
  ExtractFeatures(A) = ExtractFeatures(A)  // 两次调用结果相同
```
生成器：随机长度（1600..16000 样本）的 PCM16 音频。

### P6 DTW 对称性
**Validates: Requirements 5.5（间接）**
```
∀ X, Y: TVoiceFeatures（非空）
  |DTW(X, Y) - DTW(Y, X)| < 1e-9  // 浮点误差容忍
```
生成器：随机长度（10..100）的 Double 数组对。

### P7 DTW 非负性
**Validates: Requirements 5.5（间接）**
```
∀ X, Y: TVoiceFeatures（非空）
  DTW(X, Y) ≥ 0
```

### P8 DTW 自距离为零
**Validates: Requirements 5.5（间接）**
```
∀ X: TVoiceFeatures（非空）
  DTW(X, X) = 0
```

### P9 Verify Match 等价于 Distance < Threshold（Req 5.5）
**Validates: Requirements 5.5**
```
∀ 已登记档案 P，∀ 音频 A
  Verify(A, P.Id).Match = (Verify(A, P.Id).Distance < P.Threshold)
```

### P10 Verify 确定性（Req 5.7）
**Validates: Requirements 5.7**
```
∀ A: TSpeechAudioData，∀ ProfileId
  Verify(A, ProfileId) = Verify(A, ProfileId)  // 两次调用结果相同
```

### P11 IntentParser 幂等（Req 6.4）
**Validates: Requirements 6.4**
```
∀ text: string，∀ locale: string
  Parse(text, locale) = Parse(text, locale)
```
生成器：随机中文/英文字符串（长度 1..200）。

### P12 IntentParser 增量注册不影响已有规则（Req 6.7）
**Validates: Requirements 6.7**
```
∀ 已注册规则集 R，∀ 新规则 r（不与 R 中任何规则冲突）
  ∀ text 命中 R 中某规则 r0
    RegisterRule(r) 后 Parse(text) 仍返回与 r0 对应的 TIntentResult
```

### P13 配置读写幂等（Req 7.6）
**Validates: Requirements 7.6**
```
∀ key ∈ SpeechConfigKeys，∀ value: string（合法值）
  WriteConfig(key, value); ReadConfig(key) = value
  WriteConfig(key, ReadConfig(key)); ReadConfig(key) = value
```

### P14 热词词表往返（Req 15.1）
**Validates: Requirements 15.1**
```
∀ words: TArray<string>（每个词长度 ≥ 2，不含控制字符）
  SetWords(words); GetWords() 返回的集合 = Set(words)
```
生成器：随机长度（1..20）的中文词数组，每词 2..8 字。

### P15 声纹特征 DPAPI 往返（Req 14.3）
**Validates: Requirements 14.3**
```
∀ F: TVoiceFeatures（非空）
  Deserialize(DPAPIDecrypt(DPAPIEncrypt(Serialize(F)))) = F  // 元素级相等
```
生成器：随机长度（13..39）的 Double 数组（MFCC 向量维度范围）。

---

## 7. Backend Fallback Chain

### 7.1 ASR 降级链

```
ConfigDB speech.default.asr_backend = 'auto'（或未设置）时：
  1. WinRT（Win10+，speech.asr.cloud_enabled 不影响本地 WinRT）
  2. SAPI 5.4（Win7+）
  3. WhisperLocal（需 whisper.dll 存在）
  4. Baidu（需 speech.asr.cloud_enabled=Enabled + API Key）
  5. 全部不可用 → EDeepBaseSpeechProviderError

显式指定时：直接尝试指定 Backend，不可用则按上述链回退（记录 Trace 日志）。
```

### 7.2 TTS 降级链

```
  1. SAPI 5.4（默认，全兼容）
  2. 云 TTS（需 speech.tts.cloud_enabled=Enabled）
  3. 全部不可用 → EDeepBaseSpeechProviderError
```

---

## 8. Threading Model

- `ISpeechAudioCapture`（WinMM）：内部后台线程采集，`GetAudioData` 线程安全
- `IASRStream`（SAPI）：后台线程处理 SAPI 事件，回调在后台线程触发，消费方负责 `TThread.Synchronize`
- `IWakeWordDetector`：独立后台线程，回调同上
- `ITTSBackend.SpeakAsync`：SAPI 异步模式，完成回调在 SAPI 内部线程
- `IVoiceprint`：所有方法同步调用，无内部线程

---

## 9. Error Handling

| 场景 | 行为 |
|---|---|
| Backend 不可用 | `IsAvailable=False`，`CheckStatus` 返回可读原因 |
| 密钥缺失/解密失败 | `IsAvailable=False`，不透露密钥内容 |
| 麦克风不可用 | `StartRecording=False`，`LastError` 含 "no input device" |
| 云 HTTP 超时 | `Status=srsHttpError`，`ErrorMessage` 含超时秒数 |
| Governance 门禁拒绝 | 抛出 `EDeepBaseGovernanceError`（现有异常类型） |
| 空音频 | `Status=srsEmptyAudio`，不调用云 API |
| DPAPI 失败 | 抛出 `EDeepBaseSpeechError`，不落盘明文 |

---

## 10. Testing Strategy

### 10.1 单元测试（DUnitX）
- 每个 Backend 的 `IsAvailable / CheckStatus` 在有/无 SAPI 环境下的行为
- `TSpeechAudioData.DurationMs` 边界值（空数据、最大值）
- `TTTSOptions.Default` 字段完整性
- `TIntentResult.Unknown` 字段值
- Governance 门禁拒绝路径（mock ConfigRegistrar）

### 10.2 属性测试（PBT，见第 6 节）
- P1–P4：音频编解码往返（无需硬件）
- P5–P8：MFCC/DTW 数学属性（无需硬件）
- P9–P10：Voiceprint 验证一致性（需预录样本或合成音频）
- P11–P12：IntentParser 幂等/增量（纯逻辑，无需硬件）
- P13：ConfigDB 读写幂等（需 ConfigDB 初始化）
- P14：热词词表往返（纯逻辑）
- P15：DPAPI 往返（需 Windows 环境）

### 10.3 集成测试（手动 / CI 可选）
- SAPI ASR：麦克风输入 → 识别结果（需真实硬件）
- WakeWord：说"小启" → 回调触发（需真实硬件）
- TTS：`Speak('测试')` → 有声音输出（需真实硬件）

---

## 11. Migration Notes

### 11.1 现有 Baidu 使用方
- `TDeepBaseSpeechService.CreateBaidu` 签名不变
- `ISpeechRecognizer` 接口不变
- 新增 `ISpeechRecognizerEx` 扩展接口，Baidu Backend 可选实现

### 11.2 DeepInput 迁移策略（D2 已决策：完全重构 Strategy A）
- DeepInput 拆掉所有内部语音代码，直接调用 `TSpeechService`
- Phase 3 任务：列出 DeepInput 语音单元 → 逐一替换 → 删除旧代码 → 回归测试
- 无 Adapter 层，无双层维护

### 11.3 DeepBaseFeatures.dpk
Phase 1 完成后，需在 `DeepBaseFeatures.dpk` 中加入：
- `DeepBase.Speech.ASR.SAPI`
- `DeepBase.Speech.TTS.SAPI`
- `DeepBase.Speech.Schema`
