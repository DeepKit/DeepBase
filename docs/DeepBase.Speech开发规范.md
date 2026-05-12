# DeepBase.Speech 开发规范

> 版本：2.0（基于扩展方案 v1.0 + Spec 评审）
> 状态：✅ 规范已定稿，Phase 1 可开工
> Spec 文件：`DeepBase/.kiro/specs/deepbase-speech/`

---

## 一、模块定位

DeepBase.Speech 是 DeepBase 基础库的语音能力子模块，为下游产品提供统一的语音服务接口。

消费方：
- **DeepLaunch 语音版**：F2 转录、热词唤醒、声纹验证、TTS 反馈
- **DeepInput**：流式听写（完全重构，拆掉自有语音代码，直接调用 DeepBase.Speech）

铁律约束：
- 无 JSON/INI/YAML 配置，全部走 ConfigDB（SQLite）
- 敏感数据（API Key、声纹特征）走 DPAPI 加密
- 门禁/行为走 Governance（TConfigRegistrar 代码注册）
- DeepBase 无 UI

---

## 二、文件结构

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
  DeepBase.Speech.Schema.pas         ← voice_profiles 表 + Governance 注册 + 默认配置

  ── Phase 2 新增 ──
  DeepBase.Speech.WakeWord.pas       ← SAPI Grammar 长时监听

  ── Phase 4 新增 ──
  DeepBase.Speech.MFCC.pas           ← 纯 Delphi MFCC 特征提取（39 维）
  DeepBase.Speech.DTW.pas            ← DTW 距离计算（Sakoe-Chiba 约束）
  DeepBase.Speech.Voiceprint.pas     ← 声纹档案管理 + 验证门面

DeepBase/Tests/Speech/
  Test.DeepBase.Speech.Types.pas     ← PCM round-trip PBT
  Test.DeepBase.Speech.ASR.SAPI.pas
  Test.DeepBase.Speech.TTS.SAPI.pas
  Test.DeepBase.Speech.WakeWord.pas
  Test.DeepBase.Speech.MFCC.pas      ← MFCC 确定性 PBT
  Test.DeepBase.Speech.DTW.pas       ← DTW 对称性/非负/自距离 PBT
  Test.DeepBase.Speech.Voiceprint.pas← Voiceprint 往返 PBT
```

---

## 三、核心接口速查

### 3.1 门面（TSpeechService）

```pascal
// 能力入口
class function ASR(AKind: TASRBackendKind = abkBaidu): ISpeechRecognizerEx;
class function TTS: ITTSBackend;
class function WakeWord: IWakeWordDetector;
class function Voiceprint: IVoiceprint;
class function IntentParser: IIntentParser;
class function AudioCapture: ISpeechAudioCapture;
class function VAD: IVAD;

// 便捷方法
class function TranscribeFromMic(const ALanguage: string;
  AMaxSeconds: Integer = 30; ASilenceTimeoutMs: Integer = 3000): TSpeechRecognitionResult;
class procedure Speak(const AText: string; const ALanguage: string = '');

// Backend 注册（Bootstrap 阶段调用）
class procedure RegisterASRBackend(AKind: TASRBackendKind; AFactory: TFunc<ISpeechRecognizerEx>);
class procedure RegisterTTSBackend(AFactory: TFunc<ITTSBackend>);
class procedure RegisterWakeWordDetector(AFactory: TFunc<IWakeWordDetector>);
class procedure RegisterVoiceprint(AFactory: TFunc<IVoiceprint>);
```

### 3.2 ASR 扩展接口

```pascal
ISpeechRecognizerEx = interface(ISpeechRecognizer)
  function Kind: TASRBackendKind;
  function IsAvailable: Boolean;
  function SupportsStreaming: Boolean;
  function StartStreaming(const AOptions: TASROptions): IASRStream;
  procedure LoadGrammar(const AWords: TArray<string>);
end;

IASRStream = interface
  procedure FeedAudio(const AChunk: TSpeechAudioData);
  procedure SetOnPartial(ACallback: TProc<TASRPartialResult>);
  procedure SetOnFinal(ACallback: TProc<TSpeechRecognitionResult>);
  procedure Stop;
  function IsActive: Boolean;
end;
```

### 3.3 TTS 接口

```pascal
ITTSBackend = interface
  function Name: string;
  function IsAvailable: Boolean;
  function SupportedLanguages: TArray<string>;
  function SupportedVoices(const ALanguage: string): TArray<TTTSVoice>;
  procedure Speak(const AText: string; const AOptions: TTTSOptions);
  procedure SpeakAsync(const AText: string; const AOptions: TTTSOptions; ACallback: TProc);
  procedure Stop;
end;

TTTSOptions = record
  Language: string;
  VoiceId: string;
  Rate: Integer;    // -10..10
  Volume: Integer;  // 0..100
  class function Default: TTTSOptions; static;
end;
```

### 3.4 WakeWord 接口

```pascal
IWakeWordDetector = interface
  function IsAvailable: Boolean;
  procedure SetWords(const AWords: TArray<string>);  // 每词长度 ≥ 2
  function GetWords: TArray<string>;
  procedure SetConfidenceThreshold(AValue: Double);
  function Start: Boolean;   // 检查 Governance 门禁
  procedure Stop;            // 500 ms 内释放麦克风
  procedure SetOnWakeDetected(ACallback: TProc<TWakeEvent>);
end;

TWakeEvent = record
  MatchedWord: string;
  Confidence: Double;
  Timestamp: TDateTime;
  AudioSnippet: TSpeechAudioData;  // 前后 500 ms 音频，供声纹验证
end;
```

### 3.5 Voiceprint 接口

```pascal
IVoiceprint = interface
  function ExtractFeatures(const AAudio: TSpeechAudioData): TVoiceFeatures;
  function EnrollProfile(const AUserLabel, APurpose: string;
    const ASamples: TArray<TSpeechAudioData>): TVoiceProfileId;  // 需 ≥3 样本
  function DeleteProfile(const AId: TVoiceProfileId): Boolean;
  function ListProfiles(const AOwnerApp: string = ''): TArray<TVoiceProfileInfo>;
  function Verify(const AAudio: TSpeechAudioData;
    const AProfileId: TVoiceProfileId): TVerifyResult;
  function Identify(const AAudio: TSpeechAudioData): TVoiceProfileId;
end;

TVerifyResult = record
  Match: Boolean;    // = Distance < Profile.Threshold
  Score: Double;     // 0..1 归一化
  Distance: Double;  // DTW 原始距离
end;
```

---

## 四、ASR 降级链

```
ConfigDB speech.default.asr_backend = 'auto' 时：
  1. WinRT（Win10+）
  2. SAPI 5.4（Win7+）
  3. WhisperLocal（需 whisper.dll）
  4. Baidu（需 speech.asr.cloud_enabled=Enabled + API Key）
  5. 全部不可用 → EDeepBaseSpeechProviderError

显式指定时：直接尝试，不可用则按上述链回退，记录 Trace 日志。
```

---

## 五、ConfigDB 配置键

| 键 | 默认值 | 说明 |
|---|---|---|
| `speech.default.asr_backend` | `auto` | auto/sapi/winrt/baidu/whisper |
| `speech.default.tts_backend` | `sapi` | |
| `speech.default.language` | `zh-CN` | |
| `speech.wake_word.enabled` | `0` | Governance 门禁 |
| `speech.wake_word.threshold` | `0.7` | |
| `speech.voiceprint.enabled` | `0` | Governance 门禁 |
| `speech.intent.llm_enabled` | `0` | Governance 门禁 |
| `speech.intent.llm_timeout_ms` | `3000` | |
| `speech.baidu.app_key` | `` | **DPAPI 加密** |
| `speech.baidu.secret_key` | `` | **DPAPI 加密** |

---

## 六、voice_profiles 表

```sql
CREATE TABLE IF NOT EXISTS voice_profiles (
  profile_id   TEXT PRIMARY KEY,
  user_label   TEXT NOT NULL,
  purpose      TEXT NOT NULL,         -- 'wake_word' / 'dictation' / 'identify'
  sample_count INTEGER NOT NULL,
  features     BLOB NOT NULL,         -- MFCC 向量（DPAPI 加密）
  threshold    REAL NOT NULL DEFAULT 15.0,
  owner_app    TEXT NOT NULL,         -- 'DeepLaunch' / 'DeepInput'
  created_at   TEXT NOT NULL,
  updated_at   TEXT NOT NULL,
  enabled      INTEGER NOT NULL DEFAULT 1
);
```

Schema 通过 `DeepBase.Manager.Schema` 迁移机制注册（版本 `speech_v1`）。

---

## 七、Governance 门禁注册

在 `DeepBase.Speech.Schema.pas` 的 `RegisterSpeechGovernance` 中通过 `TConfigRegistrar` 注册：

| 门禁键 | 默认 | 说明 |
|---|---|---|
| `speech.wake_word.enabled` | Disabled | 长时麦克风监听 |
| `speech.voiceprint.enabled` | Disabled | 生物识别数据处理 |
| `speech.intent.llm_enabled` | Disabled | 联网 LLM 意图解析 |
| `speech.asr.cloud_enabled` | Disabled | 云 ASR（Baidu/Azure） |
| `speech.tts.cloud_enabled` | Disabled | 云 TTS |

保守模式：ConfigRegistrar 未初始化时，所有云 Backend 和生物识别能力自动禁用。

---

## 八、MFCC 参数（Phase 4）

| 参数 | 值 |
|---|---|
| 帧长 | 25 ms |
| 帧移 | 10 ms |
| 窗函数 | 汉明窗 |
| Mel 滤波器数 | 40 |
| MFCC 系数 | 13 |
| 差分 | 一阶 + 二阶 |
| 总维度 | 39 |
| 输入格式 | 16 kHz PCM16 单声道 |

DTW：Sakoe-Chiba 带宽约束（带宽 = 序列长度 × 0.1），归一化距离（除以路径长度）。

---

## 九、下游集成示例

### DeepLaunch 语音版

```pascal
// F2 按下 → 录音 + 转录
var R := TSpeechService.TranscribeFromMic('zh-CN', 30, 3000);
if R.Success then
  EnterCandidateSystem(R.Text);

// 热词唤醒（Bootstrap 阶段启动）
TSpeechService.WakeWord.SetWords(['小启']);
TSpeechService.WakeWord.SetConfidenceThreshold(0.7);
TSpeechService.WakeWord.SetOnWakeDetected(
  procedure(E: TWakeEvent)
  begin
    if VoiceprintEnabled then
      if not TSpeechService.Voiceprint.Verify(E.AudioSnippet, FOwnerId).Match then
        Exit;
    SimulateF2KeyPress;
  end);
TSpeechService.WakeWord.Start;

// 语音反馈
TSpeechService.Speak('已为你打开计算器');
```

### DeepInput 完全重构后

```pascal
// 流式听写（替换原有内部语音代码）
var LStream := TSpeechService.ASR.StartStreaming(
  TASROptions.Create('zh-CN', asrDictation));
LStream.SetOnPartial(
  procedure(P: TASRPartialResult)
  begin
    TThread.Synchronize(nil, procedure begin
      FloatingLabel.Caption := P.Text;
    end);
  end);
LStream.SetOnFinal(
  procedure(R: TSpeechRecognitionResult)
  begin
    TThread.Synchronize(nil, procedure begin
      InsertTextToFocusedWindow(R.Text);
    end);
  end);
```

---

## 十、决策记录

| ID | 问题 | 决策 |
|---|---|---|
| D1 | Phase 1 开工时机 | ✅ 立刻开工（M0 Spike 前置） |
| D2 | DeepInput 迁移策略 | ✅ **完全重构（Strategy A）**（未发布，无回归压力） |
| D3 | 声纹 v2 时机 | ✅ 推迟到 M7（v1 不做 Voiceprint） |
| D4 | Whisper.cpp 优先级 | M8 后（SAPI 准确率不够再加） |
| D5 | TTS SSML 支持 | 暂不支持 |
| D6-orig | 用户自定义唤醒词 | 支持（词长 ≥ 2） |
| D7 | 意图解析复用 DeepLLM | 复用 DeepBase.LLM.Client |
| D8 | Azure ASR 预留 | 保留枚举，不实现 |
| D6-new | Commerce.Permissions vs Governance | ✅ **共存但分层**（Speech.Policy 统一封装） |
| A4 | 声纹 HMAC 防篡改 | ✅ **降为 P2**（ConfigDB SQLite 加密为主防线） |
| E4 | DeepLaunch 热键 | ✅ F2 保留单键，备用组合键可选 |
| E1 | TTS 让位屏幕阅读器 | ✅ `speech.tts.defer_to_screen_reader=1` |
| E3 | Voice Access 冲突 | ✅ `speech.wake_word.defer_to_voice_access=1` |
| B2 | Stop 时限 | ✅ best-effort + hard-limit 双轨 |
| C3 | 语言键拆分 | ✅ `speech.asr.language` + `speech.tts.language` |
| D1-dpk | dpk 切分 | ✅ 切分为 5 个包 |
| D2-abi | 接口 GUID + API level | ✅ 所有 Speech interface 强制 GUID |
| DB加密 | ConfigDB SQLite 加密 | ✅ 只加密 ConfigDB，独立基础设施任务 |

---

## 十一、实施路径（M0–M8 里程碑）

| 里程碑 | 内容 | 发布目标 |
|---|---|---|
| M0 | Spike：SAPI COM、语言包矩阵、WinMM 低延迟、麦克风并发、WakeWord confidence、TTS async/stop、屏幕阅读器检测、Voice Access 检测 | 不发布 |
| M1 | Runtime 骨架：Registry/Config/Policy/Runtime + SAPI batch ASR + SAPI TTS + Schema + Governance + 默认配置 | DeepBase.Speech v2.0-alpha |
| M2 | 流式 ASR：低延迟 capture、AudioSession 仲裁、可观测性、SAPI live streaming | DeepBase.Speech v2.0-beta |
| M3 | DeepInput 完全重构：拆掉自有语音代码，直接调用 DeepBase.Speech | DeepInput 重构版 |
| M4 | DeepLaunch F2/PTT MVP：本地 ASR + TTS + 设置页 + 麦克风授权 | DeepLaunch 语音版 v1.0 |
| M5 | WakeWord Beta：默认关闭、独立授权、常驻状态提示、资源占用基准 | DeepLaunch 语音唤醒 Beta |
| M6 | 稳定化 + 合规文档 | — |
| M7 | Voiceprint speaker check：本地防误触、MFCC+DTW、删除/撤回/跨应用授权 | DeepLaunch 语音版 v2.0 |
| M8 | IntentParser / WinRT / Whisper / 云扩展 | 可选增强 |

---

## 十二、二轮评审新增要点

### 架构补充
- **Registry/Config/Policy/Runtime/Schema 五拆**（不再全塞 Schema.pas）
- **AudioSession 仲裁状态机**：Idle → WakeListening → PushToTalk → DictationStreaming → TTSPlaying
- **一 process 一 SAPI worker thread**，所有 SAPI 调用串行化
- **Backend 自注册**（initialization 段），下游只做覆盖/禁用/测试替身

### 安全
- **Threat Model（STRIDE）** 写入 design.md
- **ConfigDB SQLite 加密**为主防线（独立基础设施任务）
- **HMAC 降为 P2 可选**（M7 时根据加密状态再定）
- **Trace 禁止 PCM payload**，`speech.trace.audio_payload_enabled=0`

### 可访问性
- **TTS 让位屏幕阅读器**：`speech.tts.defer_to_screen_reader=1`
- **WakeWord 让位 Voice Access**：`speech.wake_word.defer_to_voice_access=1`

### i18n
- **拆语言键**：`speech.asr.language` + `speech.tts.language`
- **BCP-47 归一化 + Fallback 策略**
- **zh-CN recognizer token 矩阵**（M0 Spike 验证）

### 发布工程
- **dpk 切分 5 个包**
- **所有 interface 强制 GUID + `SPEECH_API_LEVEL` 常量**
- **Stop 时限 best-effort + hard-limit 双轨**

---
