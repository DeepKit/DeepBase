# DeepBase.Speech 专家评审优化方案

> 日期：2026-05-12
> 来源：`DeepBase.Speech开发规范.md` + `DeepBase.Speech扩展方案.md` + 5 个专家视角评审
> 状态：评审优化稿。建议先据此修订 requirements/design/tasks，再进入 Phase 1 实现。

---

## 一、总评结论

原方案的方向正确：DeepBase.Speech 应该成为 DeepLaunch、DeepInput 共用的语音基础能力，继续坚持 ConfigDB、DPAPI、Governance、无 UI 的铁律，并保留现有 `ISpeechRecognizer` / `TDeepBaseSpeechService.CreateBaidu` 兼容层。

但当前方案不适合按“Phase 1 直接开工全量接口”的节奏推进。主要原因：

1. 现有代码是批处理 ASR 模型，新方案直接引入真流式 ASR、WakeWord 常驻监听、声纹、意图解析，跨度过大。
2. SAPI 流式、`FeedAudio`、COM 线程模型、WinMM 低延迟采集、麦克风资源仲裁都需要先做 Spike。
3. 架构口径未统一：Backend 枚举、降级链、注册责任、`OnPartial`/`SetOnPartial`、`TAudioBuffer`/`TSpeechAudioData` 等存在漂移。
4. DeepInput “完全重构”应改为先 Adapter 灰度，再移除旧链路，否则回归风险过高。
5. 声纹必须降级定位为“本地 speaker check，用于降低误触发”，不得写成身份认证或安全授权。

建议将当前“功能分期”改成“基础设施成熟度分期”：先运行时骨架、能力检测、配置/治理、测试替身和资源仲裁，再实现 WakeWord、DeepInput 重构和 Voiceprint。

---

## 二、5 个专家评审摘要

| 视角 | 核心意见 |
|---|---|
| 架构专家 | 先补 `Speech.Registry`、`Speech.Config`、`Speech.Policy`、`Speech.Runtime`，把 Backend 默认注册责任收回 DeepBase，统一枚举/降级链/配置真源。 |
| Delphi/Windows Speech 专家 | SAPI 不等于中文 ASR 可用；SAPI 对 COM 线程模型敏感；`FeedAudio` 真流式复杂，必须先验证；WakeWord 与普通 ASR 需要麦克风仲裁。 |
| 语音算法/生物识别专家 | MFCC+DTW 只能做弱相似度检查。500ms 唤醒片段不足以可靠验证说话人；`Identify()` 默认不应开放；阈值必须用数据校准。 |
| 测试质量专家 | 现有测试只覆盖 PCM/VAD/Baidu fake HTTP/服务权限。SAPI/TTS/WakeWord/MFCC/DTW/Voiceprint/Schema/Governance 需要 headless、nightly、manual 三层测试矩阵。 |
| 产品交付专家 | DeepLaunch 与 DeepInput 不应同时承压。WakeWord 和 Voiceprint 要默认关闭、显式授权、可回滚；DeepInput 先 Adapter 接入，稳定后再完全重构。 |

---

## 三、必须先修正的 P0 问题

### 3.1 统一接口口径

必须冻结以下名称和语义：

| 项 | 决策 |
|---|---|
| 音频类型 | 统一使用 `TSpeechAudioData`，不再出现 `TAudioBuffer`。 |
| 流式回调注册 | 统一使用 `SetOnPartial` / `SetOnFinal`，不使用 `OnPartial` / `OnFinal` 作为方法名。 |
| WakeWord 启动 | `Start: Boolean`，门禁拒绝或不可用时返回 False，并记录原因。 |
| Backend 枚举 | `abkBaidu / abkSAPI / abkWinRT / abkWhisperLocal / abkAzure`。Azure 保留但不进入默认链。 |
| 配置键前缀 | 全部使用 `speech.*`，修正 `voice.wake_word.enabled` 为 `speech.wake_word.enabled`。 |
| 声纹接口 | 所有 Profile 操作必须显式带 `OwnerApp` 或由上下文注入，不允许默认扫全库。 |

### 3.2 统一 ASR 降级链

建议默认链如下：

```text
auto:
  1. WinRT          本地，Win10+，可用性检测通过才启用
  2. SAPI          本地，Win7+ 可尝试，取决于 recognizer/language pack
  3. WhisperLocal  本地，whisper.dll 存在且显式安装
  4. Baidu/Azure   云端，仅 speech.asr.cloud_enabled=Enabled 且用户显式授权
  5. 全部不可用 -> EDeepBaseSpeechProviderError
```

云 ASR 不应在用户无感情况下进入 auto 降级。即使用户设置了 `speech.default.asr_backend=baidu`，也必须同时满足云门禁和密钥可用。

### 3.3 把注册责任收回 DeepBase

原文要求下游 Bootstrap 调用 `RegisterASRBackend`，这与“下游不需要装配依赖”冲突。优化后：

- DeepBase 自带 Backend 由各单元 `initialization` 自注册。
- 下游只允许覆盖、禁用或注入测试 Backend。
- 注册表内部维护 Backend 元数据：`Kind`、`Name`、`Local/Cloud`、`RequiresMic`、`SupportsBatch`、`SupportsStreaming`、`SupportsGrammar`。

### 3.4 拆开 Schema、Config、Policy

不要把 `voice_profiles` 迁移、默认配置写入、Governance 注册全部塞进 `DeepBase.Speech.Schema.pas`。建议拆分：

| 单元 | 职责 |
|---|---|
| `DeepBase.Speech.Registry.pas` | Backend 注册、发现、覆盖、禁用。 |
| `DeepBase.Speech.Config.pas` | ConfigDB 键定义、默认值、读写、值校验。 |
| `DeepBase.Speech.Policy.pas` | Governance + 现有 `TDeepKitPermissionClient` 的统一策略入口。 |
| `DeepBase.Speech.Runtime.pas` | 默认 Backend 选择、降级链、Trace、资源仲裁。 |
| `DeepBase.Speech.Schema.pas` | 仅负责表结构迁移，如 `voice_profiles`。 |

### 3.5 新增音频资源仲裁

WakeWord、F2 转录、DeepInput 流式听写不能各自抢麦克风。需要新增内部仲裁：

```text
Idle
  -> WakeListening
  -> PushToTalk
  -> DictationStreaming
  -> TTSPlaying
```

基本规则：

- PTT/F2/DeepInput 启动时暂停 WakeWord。
- ASR 完成后恢复 WakeWord。
- `Stop` 必须有时限：WakeWord 500ms 内释放，TTS 200ms 内停止，ASR stream 2s 内 final 或明确取消。
- 所有状态切换写 Trace：`trace_id/backend/session_kind/duration/status/fallback_reason`。

---

## 四、SAPI 实现策略调整

### 4.1 Phase 1 不承诺真流式 FeedAudio

SAPI ASR 先拆成三种能力，不一次性承诺：

| 能力 | Phase | 说明 |
|---|---|---|
| Batch Recognize | M1 | `Recognize(TSpeechAudioData)`，先跑通 PCM/WAV final result。 |
| Live Streaming | M2 | SAPI 自采麦克风，使用 SAPI events 产生 partial/final。 |
| FeedAudio Streaming | Spike 后决定 | 自定义 PCM chunk queue/IStream 成本高，不能默认写进首发契约。 |

`IASRStream.FeedAudio` 可以先作为通用接口保留，但 SAPI Backend 若未验证通过，必须 `SupportsStreaming=False` 或声明为 backend 自采麦克风模式。

### 4.2 SAPI COM 线程拥有模型

所有 SAPI 对象必须在固定 worker thread 内创建、使用和释放：

- 线程内 `CoInitializeEx`。
- 外部接口只投递命令，不跨线程直接调用 COM 对象。
- 回调默认在后台线程触发，消费方负责 `TThread.Synchronize`。
- Grammar 热更新必须在线程内串行执行：停用 grammar -> 更新 -> commit -> 启用。

### 4.3 Phase 0 必做 Spike

1. Delphi 37.0 下确认 SAPI COM 声明来源：`Winapi.SpeechLib`、导入 TLB 或手写最小接口。
2. 检查 Win7/Win10/Win11、Win32/Win64 下 SAPI COM、zh-CN recognizer token、voice token。
3. 用 16k PCM16 中文 WAV 跑 SAPI batch ASR。
4. 用 SAPI 自采麦克风跑 live streaming partial/final。
5. 验证 SAPI 是否能从自定义 PCM chunk queue 识别。
6. WinMM buffer 调到 20/50/100ms，验证 CPU、丢帧、停止释放时间。
7. 测试 SAPI recognizer 与 WinMM capture 同时打开时的设备占用行为。
8. WakeWord Grammar 注册“小启”等中文词，采集 confidence 分布、误触率、漏触率。
9. 监听中动态 `SetWords`，验证不崩溃、不退出、可停止。
10. TTS `SpeakAsync/Stop/连续播放/空文本/voice 切换` 状态机验证。

---

## 五、Voiceprint 重新定位

### 5.1 产品定位

统一措辞：

> 本地声纹相似度检查，用于降低误触发，不用于身份认证、安全授权、支付、解锁或账号确认。

不得使用“声纹认证”“确认本人”“身份认证级”等表述。

### 5.2 v1/v2 调整

v1 不做 Voiceprint，只做：

- F2/PTT 转录。
- 本地 TTS。
- 可选 WakeWord Beta，但默认关闭。
- 唤醒后进入待命或开始录音，不直接执行高风险动作。

v2 若保留 Voiceprint：

- 仅开放 `Verify(ProfileId, OwnerApp, Purpose)`，默认禁用 `Identify()`。
- 不使用 500ms 唤醒片段单独判定，应使用更长命令音频，或固定短语/随机挑战短语。
- 登记样本从 `>=3` 提高到建议 `5-10` 条，并加入质量检查：SNR、削波、有效语音时长、样本间距离。
- 阈值不写死 `15.0`，改为 `threshold_policy` + 校准数据。
- 发布前必须给出 FAR/FRR/误唤醒率/拒识率基准，而不是只做 PBT。

### 5.3 Schema 建议

`voice_profiles` 建议扩展：

```sql
CREATE TABLE IF NOT EXISTS voice_profiles (
  profile_id             TEXT PRIMARY KEY,
  owner_app              TEXT NOT NULL,
  user_label             TEXT NOT NULL,
  purpose                TEXT NOT NULL,
  sample_count           INTEGER NOT NULL,
  features               BLOB NOT NULL,
  threshold              REAL,
  threshold_policy       TEXT NOT NULL DEFAULT 'calibrated_v1',
  model_version          TEXT NOT NULL,
  feature_version        TEXT NOT NULL,
  enrollment_quality     TEXT NOT NULL DEFAULT '{}',
  consent_id             TEXT NOT NULL,
  device_hint            TEXT NOT NULL DEFAULT '',
  retention_expires_at   TEXT,
  last_used_at           TEXT,
  failed_attempts        INTEGER NOT NULL DEFAULT 0,
  created_at             TEXT NOT NULL,
  updated_at             TEXT NOT NULL,
  enabled                INTEGER NOT NULL DEFAULT 1
);
```

`features` 是二进制特征，应使用 DPAPI bytes 接口或 `TDeepBaseSecurity.ProtectString` 前先做稳定二进制/文本序列化；不要把未加密 MFCC 明文落盘、写日志或写临时文件。

---

## 六、配置键补全

保留原有键，并新增：

| 键 | 默认 | 说明 |
|---|---|---|
| `speech.default.asr_backend` | `auto` | auto/sapi/winrt/whisper/baidu/azure |
| `speech.default.tts_backend` | `sapi` | |
| `speech.default.language` | `zh-CN` | BCP-47 |
| `speech.default.input_device_id` | `` | 空为系统默认麦克风 |
| `speech.default.tts_voice` | `` | 空为系统默认 voice |
| `speech.tts.rate` | `0` | -10..10 |
| `speech.tts.volume` | `100` | 0..100 |
| `speech.wake_word.enabled` | `0` | Governance 门禁 |
| `speech.wake_word.words` | `` | ConfigDB 存储，禁止 JSON 文件 |
| `speech.wake_word.threshold` | `0.7` | 仅作默认，须按 backend 校准 |
| `speech.voiceprint.enabled` | `0` | Governance 门禁 |
| `speech.voiceprint.cross_app_enabled` | `0` | 跨应用复用必须单独授权 |
| `speech.asr.cloud_enabled` | `0` | 云 ASR 门禁 |
| `speech.tts.cloud_enabled` | `0` | 云 TTS 门禁 |
| `speech.intent.llm_enabled` | `0` | LLM 门禁 |
| `speech.intent.llm_timeout_ms` | `3000` | |
| `speech.trace.enabled` | `1` | Trace 默认开，但必须脱敏 |
| `speech.trace.audio_payload_enabled` | `0` | 默认禁止记录音频 payload |

API Key 继续通过 `DeepBase.Security.SaveSecret/LoadSecret` 或 DPAPI 等价接口处理，不建议直接使用已废弃的 `SetConfigEncrypted/GetConfigEncrypted`。

---

## 七、优化后的里程碑

| 里程碑 | 内容 | 发布目标 |
|---|---|---|
| M0 | Spike：SAPI COM、语言包、WinMM 低延迟、麦克风并发、WakeWord confidence、TTS async/stop | 不发布 |
| M1 | Runtime 骨架：Registry/Config/Policy/Runtime、Backend contract fake、SAPI batch ASR、SAPI TTS、默认配置、Governance | DeepBase.Speech v2.0-alpha |
| M2 | 流式 ASR：低延迟 capture、音频资源仲裁、可观测性、SAPI live streaming 或明确降级策略 | DeepBase.Speech v2.0-beta |
| M3 | DeepInput Adapter：保留旧接口，底层可切到 DeepBase.Speech，支持灰度和回滚 | DeepInput 兼容测试版 |
| M4 | DeepLaunch F2/PTT MVP：本地 ASR + TTS + 设置页 + 麦克风授权 | DeepLaunch 语音版 v1.0 |
| M5 | WakeWord Beta：默认关闭、独立授权、常驻状态提示、资源占用基准、与 PTT/DeepInput 仲裁 | DeepLaunch 语音唤醒 Beta |
| M6 | DeepInput 完全重构：Adapter 稳定至少一个版本周期后移除旧语音代码 | DeepInput 重构版 |
| M7 | Voiceprint speaker check：本地防误触、删除/撤回/跨应用授权、校准报告 | DeepLaunch 语音版 v2.0 |
| M8 | IntentParser / WinRT / Whisper / 云扩展 | 可选增强 |

---

## 八、测试与验收门槛

### 8.1 CI 分层

| 测试线 | 内容 | PR 是否必跑 |
|---|---|---|
| `speech-headless` | Types、PCM/VAD、Registry、Config、Policy、fake Backend、Schema、DPAPI 往返、错误映射 | 必跑 |
| `speech-windows-sapi-nightly` | 真实 SAPI ASR/TTS、语言包探测、TTS Stop、SAPI event | Nightly |
| `speech-hardware-manual` | 真实麦克风、WakeWord 误触/漏触、设备并发、资源占用 | Manual/验收 |

### 8.2 Phase Gate

M1 发布门槛：

- 现有 `Test.DeepBase.Speech.pas` 全部通过。
- 新增 Backend contract fake 测试。
- SAPI 不存在时测试验证不可用路径，不失败。
- 云 ASR 默认禁用且无 API Key 不外连。
- ConfigDB 默认键写入和读写幂等通过。

M2 发布门槛：

- `FeedAudio` 可行性结论写入设计文档。
- 低延迟采集不影响现有 batch capture。
- ASR/WakeWord/TTS 资源仲裁有单元测试。
- Trace 覆盖 backend、duration、status、fallback_reason。

M5 发布门槛：

- WakeWord fake 测试覆盖词长校验、阈值边界、门禁关闭、重复触发抑制、Stop 释放时限。
- 真实麦克风验收记录 CPU、内存、误触率、漏触率、Stop 时延。

M7 发布门槛：

- MFCC/DTW PBT 通过：确定性、非负、自距离、对称性、带宽边界。
- Golden speech set 通过：同人/不同人/噪声/近远场/录音回放/合成音。
- features 加密验证、owner_app 隔离、删除可撤回、跨应用授权测试通过。
- 文档不得宣称身份认证级能力。

---

## 九、合规边界

工程文档建议写成“按敏感个人信息控制项设计”，不要写成“已合规”。控制项：

- 长时麦克风监听默认关闭，首次启用单独授权。
- 云 ASR/TTS/LLM 默认关闭，启用前明确说明联网和上传范围。
- 声纹特征属于由声音派生的生物识别相关数据，即使不存原始音频，也不能称为匿名化或无风险。
- 提供删除、禁用、撤回同意、跨应用复用授权。
- 原始音频和 `AudioSnippet` 默认只在内存短期保存，不写日志、不落盘、不上传。
- DPAPI 用户态加密意味着跨 Windows 用户、跨机器迁移可能无法恢复，应在下游 UI 说明。

依据：

- 《中华人民共和国个人信息保护法》第二十八至三十条将生物识别列为敏感个人信息，要求特定目的、充分必要、严格保护、单独同意和必要性告知。官方文本：https://www.npc.gov.cn/npc/c2/c30834/202108/t20210820_313088.html
- NIST SP 800-63B 对生物特征认证采取限制态度，生物特征不能单独作为 authenticator；新版 SP 800-63B 还明确 voice biometric comparison 不应用于其认证要求。参考：https://pages.nist.gov/800-63-4/sp800-63b.html

---

## 十、需要同步修改的文档/Spec

建议按以下顺序修订：

1. `DeepBase/.kiro/specs/deepbase-speech/requirements.md`
   - 统一 Backend 枚举和降级链。
   - 修正 `voice.wake_word.enabled`。
   - 把 DeepInput 迁移从“完全重构”改成“Adapter -> 稳定 -> 移除旧链路”。
   - 把 Voiceprint 改为 speaker check，删除身份认证暗示。

2. `DeepBase/.kiro/specs/deepbase-speech/design.md`
   - 增加 Registry/Config/Policy/Runtime/AudioSession。
   - 增加 SAPI COM worker thread 模型。
   - 明确 SAPI batch/live/feed-audio 三种能力边界。
   - 增加测试替身和 CI 分层。

3. `DeepBase/.kiro/specs/deepbase-speech/tasks.md`
   - 前置 M0 Spike。
   - Phase 1 改成 Runtime 骨架 + SAPI batch/TTS。
   - WakeWord、DeepInput 完全重构、Voiceprint 后移。

4. `DeepBase/docs/DeepBase.Speech开发规范.md`
   - 状态从“规范已定稿，Phase 1 可开工”改成“评审后需修订”。
   - 合并本优化稿中的 P0 决策后再标记可开工。
