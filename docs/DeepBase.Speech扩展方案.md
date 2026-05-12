# DeepBase.Speech 扩展方案

> 文档版本：1.0
> 创建日期：2026-05-12
> 状态：📋 待评审
> 目的：为 DeepLaunch 语音版 + DeepInput 提供统一的语音基础能力

---

## 一、现状摸底

DeepBase 已有的 Speech 能力（`DeepBase/Features/` 目录）：

| 单元 | 职责 | 状态 |
|---|---|---|
| `DeepBase.Speech.Types` | 数据类型 | ✅ 已有 |
| `DeepBase.Speech.Service` | 服务门面 | ✅ 已有 |
| `DeepBase.Speech.Audio.WinMM` | 麦克风采集（Win32 WinMM） | ✅ 已有 |
| `DeepBase.Speech.VAD` | 语音活动检测 | ✅ 已有 |
| `DeepBase.Speech.ASR.Baidu` | 百度云 ASR Backend | ✅ 已有 |

架构特征：**门面 + 插件式 Backend**。服务门面通过 `IASRBackend` 接口调用 Backend，Backend 可插拔（百度云 / SAPI / WinRT 等）。

包：`DeepBaseFeatures.dpk`。

---

## 二、缺失能力清单

DeepLaunch 语音版 + DeepInput 需要的能力，现在缺：

| 能力 | 新增单元 | 优先级 | 用途 |
|---|---|---|---|
| **SAPI 5.4 ASR Backend** | `DeepBase.Speech.ASR.SAPI.pas` | ⭐⭐⭐ | DeepInput 听写、DeepLaunch F2 转录 |
| **SAPI 5.4 TTS Backend** | `DeepBase.Speech.TTS.SAPI.pas` | ⭐⭐⭐ | DeepLaunch 语音反馈、DeepInput 校对朗读 |
| **TTS 门面扩展** | 扩展 `Service` + `Types` | ⭐⭐⭐ | 服务接口 |
| **WakeWord 热词识别** | `DeepBase.Speech.WakeWord.pas` | ⭐⭐⭐ | DeepLaunch 语音唤醒 |
| **WinRT ASR Backend**（Win10+ 原生更准） | `DeepBase.Speech.ASR.WinRT.pas` | ⭐⭐ | 升级识别准确率 |
| **MFCC 特征提取** | `DeepBase.Speech.MFCC.pas` | ⭐⭐ | 声纹基础 |
| **DTW 匹配** | `DeepBase.Speech.DTW.pas` | ⭐⭐ | 声纹比对 |
| **Voiceprint 声纹服务** | `DeepBase.Speech.Voiceprint.pas` | ⭐⭐ | 声纹验证门面 |
| **voice_profiles 表** | 扩展 `DeepBase.Manager.Schema` | ⭐⭐ | 声纹档案存储 |

---

## 三、接口扩展

### 3.1 ASR（在现有 IASRBackend 基础上扩展）

```pascal
type
  TASRMode = (asrDictation, asrGrammar, asrCommand);
  TASRBackendKind = (abkBaidu, abkSAPI, abkWinRT, abkAzure);

  // 现有（百度已实现），补充两个方法
  IASRBackend = interface
    function Kind: TASRBackendKind;
    function SupportsStreaming: Boolean;
    function StartStreaming(const AOptions: TASROptions): IASRStream;
    procedure LoadGrammar(const AWords: TArray<string>);  // Grammar 模式
  end;

  IASRStream = interface
    procedure FeedAudio(const AChunk: TAudioBuffer);
    procedure OnPartial(ACallback: TProc<TASRPartialResult>);
    procedure OnFinal(ACallback: TProc<TASRResult>);
    procedure Stop;
  end;
```

### 3.2 新增 TTS 接口

```pascal
type
  ITTSBackend = interface
    function Name: string;
    function IsAvailable: Boolean;
    function SupportedLanguages: TArray<string>;
    function SupportedVoices(const ALanguage: string): TArray<TTTSVoice>;
    procedure Speak(const AText: string; const AOptions: TTTSOptions);
    procedure SpeakAsync(const AText: string; const AOptions: TTTSOptions;
      ACallback: TProc);
    procedure Stop;
  end;
```

### 3.3 WakeWord 接口

```pascal
type
  IWakeWordDetector = interface
    function IsAvailable: Boolean;
    procedure SetWords(const AWords: TArray<string>);
    procedure SetConfidenceThreshold(AValue: Double);
    procedure Start;
    procedure Stop;
    procedure OnWakeDetected(ACallback: TProc<TWakeEvent>);
  end;

  TWakeEvent = record
    MatchedWord: string;
    Confidence: Double;
    Timestamp: TDateTime;
    AudioSnippet: TAudioBuffer;  // 供声纹验证用
  end;
```

### 3.4 Voiceprint 接口

```pascal
type
  IVoiceprint = interface
    // 特征提取
    function ExtractFeatures(const AAudio: TAudioBuffer): TVoiceFeatures;
    // 档案管理（走 ConfigDB + DPAPI 加密）
    function EnrollProfile(const AUserLabel, APurpose: string;
      const ASamples: TArray<TAudioBuffer>): TVoiceProfileId;
    function DeleteProfile(const AId: TVoiceProfileId): Boolean;
    function ListProfiles(const AOwnerApp: string = ''): TArray<TVoiceProfileInfo>;
    // 运行时验证
    function Verify(const AAudio: TAudioBuffer;
      const AProfileId: TVoiceProfileId): TVerifyResult;
    function Identify(const AAudio: TAudioBuffer): TVoiceProfileId;
  end;

  TVerifyResult = record
    Match: Boolean;
    Score: Double;       // 0..1
    Distance: Double;    // DTW 距离
  end;
```

### 3.5 门面扩展

```pascal
type
  TSpeechService = class
  public
    // 已有
    class function ASR(AKind: TASRBackendKind = abkDefault): IASRBackend;
    class function AudioCapture: IAudioCapture;
    class function VAD: IVAD;

    // 新增
    class function TTS: ITTSBackend;
    class function WakeWord: IWakeWordDetector;
    class function Voiceprint: IVoiceprint;

    // 便捷方法（跨组件通用）
    class function TranscribeFromMic(const ALanguage: string;
      AMaxSeconds: Integer = 30;
      ASilenceTimeoutMs: Integer = 3000): TASRResult;
    class procedure Speak(const AText: string; const ALanguage: string = '');
  end;
```

---

## 四、Backend 选型与降级链

### 4.1 ASR 优先级

```
用户在设置里显式指定 → 用那个
  ↓（未指定时）
WinRT（Win10+）    — 准确率最高，支持流式
  ↓
SAPI 5.4（Win7+）  — 全兼容，支持 Dictation + Grammar
  ↓
Baidu 云           — 需 API Key + 联网，最准但有成本
  ↓
全部不可用         — 禁用语音功能，提示用户
```

### 4.2 TTS 优先级

```
SAPI 5.4 SpVoice（默认，全兼容）
  ↓
云端 TTS（未来扩展：Azure / 百度）
```

### 4.3 WakeWord 只有一个 Backend

**SAPI Grammar 模式** — 这是唯一能长时间本地监听、资源占用低的方案。

---

## 五、数据存储规范（铁律符合）

### 5.1 新增 Schema（`DeepBase.Speech.Schema.pas`）

```sql
-- 声纹档案（跨产品共享）
CREATE TABLE voice_profiles (
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

CREATE INDEX idx_voice_profiles_app ON voice_profiles(owner_app);
CREATE INDEX idx_voice_profiles_purpose ON voice_profiles(purpose);
```

### 5.2 配置键（settings 表）

| 键 | 默认 | 说明 |
|---|---|---|
| `speech.default.asr_backend` | `auto` | auto / sapi / winrt / baidu |
| `speech.default.tts_backend` | `sapi` | |
| `speech.default.language` | `zh-CN` | |
| `speech.wake_word.enabled` | `0` | |
| `speech.wake_word.threshold` | `0.7` | |
| `speech.voiceprint.enabled` | `0` | |

### 5.3 敏感信息走 DeepBase.Security（DPAPI）

- 百度云 `app_key` / `secret_key` → `SaveSecret('speech.baidu.app_key', ...)`
- 其他云 API Key 同样处理
- 声纹 features BLOB → 写入 `voice_profiles.features` 前先 `TDeepBaseSecurity.ProtectString` 加密

### 5.4 铁律

- ✅ 无 JSON 配置文件，全部走 ConfigDB
- ✅ 敏感数据 DPAPI
- ✅ 无云端依赖（默认，用户可选启用）
- ✅ 可插拔 Backend，不改核心接口

---

## 六、下游集成样例

### 6.1 DeepLaunch 语音版

```pascal
// F2 按下 → 录音 + 转录
var R: TASRResult;
begin
  R := TSpeechService.TranscribeFromMic('zh-CN', 30, 3000);
  if R.Success then
    EnterCandidateSystem(R.Text);
end;

// 热词唤醒
TSpeechService.WakeWord.SetWords(['小启']);
TSpeechService.WakeWord.SetConfidenceThreshold(0.7);
TSpeechService.WakeWord.OnWakeDetected(
  procedure(E: TWakeEvent)
  begin
    // v1: 直接触发
    // v2: 先声纹验证
    if VoiceprintEnabled then
      if not TSpeechService.Voiceprint.Verify(E.AudioSnippet, FOwnerId).Match then
        Exit;
    SimulateF2KeyPress;
  end);
TSpeechService.WakeWord.Start;

// 语音反馈
TSpeechService.Speak('已为你打开计算器');
```

### 6.2 DeepInput 语音输入

```pascal
// 持续听写（流式）
var LStream := TSpeechService.ASR.StartStreaming(
  TASROptions.Create('zh-CN', asrDictation));
LStream.OnPartial(
  procedure(P: TASRPartialResult)
  begin
    FloatingLabel.Caption := P.Text;   // 实时显示
  end);
LStream.OnFinal(
  procedure(R: TASRResult)
  begin
    InsertTextToFocusedWindow(R.Text);  // 插入到光标
  end);
```

---

## 七、实施路径

### Phase 1（2 周）：SAPI Backend 补全

- [ ] `DeepBase.Speech.ASR.SAPI.pas` — SAPI Dictation + Grammar
- [ ] `DeepBase.Speech.TTS.SAPI.pas` — SAPI SpVoice
- [ ] 扩展 `Service.pas` + `Types.pas`（TTS 门面 + 类型）
- [ ] `DeepBaseFeatures.dpk` 加入新单元
- [ ] `Test.DeepBase.Speech.pas` 加 SAPI/TTS 用例

### Phase 2（1 周）：WakeWord

- [ ] `DeepBase.Speech.WakeWord.pas` — SAPI Grammar 封装
- [ ] 测试：设置热词 → 说话 → 触发回调
- [ ] 资源占用基准（内存 / CPU）

### Phase 3（2 周）：DeepInput 迁移 + DeepLaunch 语音版开工

- [ ] 评审 DeepInput 现状：是重构还是薄 adapter 层？
- [ ] DeepLaunch 语音版调用 DeepBase.Speech（先跑通 F2 入口）

### Phase 4（3 周）：声纹 v2

- [ ] `DeepBase.Speech.MFCC.pas` — 纯 Delphi MFCC 实现
- [ ] `DeepBase.Speech.DTW.pas` — DTW 匹配算法
- [ ] `DeepBase.Speech.Voiceprint.pas` — 档案管理 + 验证
- [ ] `DeepBase.Manager.Schema` 加 `voice_profiles` 列
- [ ] DPAPI 加密特征向量
- [ ] 录制 UI 组件（供下游共用）

### Phase 5（1 周）：合规与文档

- [ ] 隐私告知文案（麦克风权限 / 声纹说明）
- [ ] 设置页：导出 / 删除 / 禁用声纹
- [ ] `DeepBase/docs/` 补完 Speech 模块文档
- [ ] DeepInput / DeepLaunch 分别加隐私声明

---

## 八、合规要点

1. **铁律：零下游 JSON 配置**，全部走 ConfigDB
2. **最小必要**：声纹只存 MFCC 特征，不存原始音频
3. **DPAPI 加密**：API Key + features BLOB
4. **用户知情**：首次启用麦克风弹窗明告"本地处理"
5. **可撤回**：设置页一键删除声纹 + 关闭语音功能
6. **跨产品边界**：`voice_profiles.owner_app` 隔离，默认不跨应用复用（用户可显式允许）
7. **个保法合规**：声纹属生物识别，单独同意 + 本地存储 + 不跨境

---

## 九、设计取舍与建议

### 为什么选 SAPI 5.4 而不是 WinRT 首发？

- SAPI 5.4 Win7+ 全兼容，覆盖率最大
- COM 接口对 Delphi 友好
- WinRT 可作为 Phase 1 之后的精度升级选项

### 为什么 MFCC + DTW 而不是深度学习？

- 纯 Delphi 实现，无外部 dll
- 计算量小（10ms 级），不占资源
- 准确率对"防误触"场景够用（不是身份认证级）
- 许可证干净

### 为什么 WakeWord 独立单元而不是合入 ASR？

- 长时间监听麦克风是**隐私敏感操作**，独立模块方便用户/审计区分
- 资源占用模型不同（ASR 是按需，WakeWord 是常驻）
- 可独立禁用

### DeepInput 迁移策略建议

两个选择：

**A. 重构方案**：DeepInput 完全用 DeepBase.Speech，拆掉自己的语音代码
- 好处：彻底解耦，维护成本低
- 成本：需要回归测试旧用户场景

**B. Adapter 方案**：DeepInput 保留内部接口，加 adapter 层代理到 DeepBase.Speech
- 好处：改动小，风险低
- 成本：双层维护，长期技术债

**建议 A**，但分两步走：
1. Phase 3 前半段：DeepInput 加 adapter，先让 DeepBase.Speech 的 SAPI 在 DeepInput 里跑起来
2. Phase 3 后半段：逐步移除 DeepInput 的内部语音代码，直到只剩 adapter 调用

---

## 十、需要决策的事项

| 问题 | 选项 | 我的建议 |
|---|---|---|
| 1. 接受本扩展方案整体分层吗？ | 是 / 否 / 微调 | — |
| 2. Phase 1 SAPI Backend 立刻开工？ | 立刻 / 先评估 DeepInput | 立刻，地基优先 |
| 3. WinRT Backend 何时做？ | Phase 2 / Phase 4 后 / 不做 | Phase 4 后（如果 SAPI 准确率不够再加） |
| 4. 声纹 v2 时机？ | Phase 4 / 语音版 v1 发布后 | Phase 4（基础设施一次性建好） |
| 5. DeepInput 迁移方式？ | A 重构 / B Adapter / A+B 渐进 | A+B 渐进 |
| 6. TTS 是否作为 Phase 1 必需？ | 必需 / 推迟 | 必需（50 行代码，对 DeepLaunch 反馈有用） |
| 7. WakeWord 作为独立安装包？ | 是 / 否 | 否（配置开关就够了，安装包会增加部署复杂度） |

---

## 十一、时间估算

| 阶段 | 内容 | 工时 |
|---|---|---|
| Phase 1 | SAPI ASR + TTS + 门面扩展 | 2 周 |
| Phase 2 | WakeWord | 1 周 |
| Phase 3 | DeepInput 迁移 + DeepLaunch 接入 | 2 周 |
| Phase 4 | 声纹 MFCC + DTW + Voiceprint | 3 周 |
| Phase 5 | 合规文档 + 测试 | 1 周 |
| **合计** | | **9 周** |

发布节奏：
- Phase 1-2 完成 → 发布 **DeepBase.Speech v2.0**（增强 SAPI + TTS + WakeWord）
- Phase 3 完成 → 发布 **DeepInput 重构版**
- Phase 3-4 完成 → 发布 **DeepLaunch 语音版 v1.0**
- Phase 5 完成 → 发布 **DeepLaunch 语音版 v2.0**（含声纹）
