# DeepBase.Speech 二轮专家评审

> 日期：2026-05-12
> 基线：`DeepBase.Speech专家评审优化方案.md` + 第一轮决策后的版本
> 第一轮已采纳：P0 接口口径统一、Registry/Config/Policy/Runtime/Schema 五拆、SAPI 三级能力、AudioSession 仲裁、M0–M8 里程碑、Voiceprint 推迟到 M7、**DeepInput 完全重构保留**（未发布，无回归压力）
> 二轮目的：换 5 个新视角挖第一轮漏掉的风险

---

## 专家视角

| 专家 | 关注面 |
|---|---|
| 安全 / 红队 | 攻击面、威胁建模、密钥/音频/声纹的侧信道、权限提升 |
| 实时音频系统 | 采集延迟、jitter、线程优先级、buffer 管理、Stop 时延 |
| i18n / 多语言本地化 | SAPI 语言包缺失、zh-CN 细分、混合语言、字符归一化 |
| 发布工程 / DevOps | dpk 依赖、二进制兼容、CI 矩阵、Delphi 版本差异、包切分 |
| 可访问性 / 辅助技术 | 与 NVDA/JAWS/Narrator 的 SAPI 资源冲突、残障用户场景 |

---

## 一、总评

第一轮决策后方案已明显更稳，但仍有若干**第一轮未触达**的系统性风险：

1. **麦克风常驻监听的攻击面**未做威胁建模。WakeWord 是"默认关闭"不等于"被打开后就安全"。
2. **AudioSession 仲裁只画了状态机**，没说清楚**调度策略**：WakeWord 是否能被 PTT 强抢？被抢后何时恢复？恢复时 SAPI recognizer 句柄是否需要重建？
3. **DeepInput 完全重构**决策合理但**对 DeepBase.Speech 的接口稳定性要求更高**：因为 DeepInput 没有 fallback 链可以回滚，所以 DeepBaseFeatures.dpk 的 ABI/API 兼容性约束比原以为的更强。
4. **i18n**几乎没进设计文档。中文 zh-CN 本身在 SAPI 上有多个不同 recognizer token（zh-CN, zh-TW, zh-HK），不同 Windows 版本行为差异巨大。
5. **屏幕阅读器与 SAPI 冲突**被完全忽略。NVDA/Narrator 本身在调 SAPI TTS，DeepBase.Speech 若争抢语音通道会造成残障用户无法使用。
6. **DPAPI 的机器绑定**首轮提了一句"跨机器迁移可能无法恢复"，但没给出**明确的失败路径**：恢复失败时用户数据怎么处理？直接删？提示重建？
7. **Backend 枚举加了 Azure 但没规划密钥生命周期**。未来加国内合规云（阿里/讯飞）时，枚举要不要再扩？`TASRBackendKind` 做成开放集合还是封闭枚举？

---

## 二、5 个专家评审

### 2.1 安全 / 红队专家

**A. 核心意见**：语音链路是 Windows 桌面应用最容易被忽略的攻击面，威胁建模必须前置，不能到 M7 才补。

**A1. 威胁模型（STRIDE）缺失**

需要在 design.md 中加一节 `§ Threat Model`，至少覆盖：

| 威胁 | 场景 | 缓解 |
|---|---|---|
| **Spoofing** | 攻击者录音回放触发 WakeWord + Voiceprint | v2 使用挑战短语 + 随机性；v1 不开 Voiceprint 时通过"唤醒后不直接执行高危动作"缓解 |
| **Tampering** | 篡改 `voice_profiles.features`（虽 DPAPI 加密但可删除/替换） | features 附带 HMAC（profile_id + owner_app + 密钥绑定） |
| **Repudiation** | 用户否认语音触发的操作 | Trace 日志带 trace_id + 哈希（不记原始音频） |
| **Information Disclosure** | 日志或崩溃 dump 泄漏 PCM / 密钥 / 特征向量 | 明确禁止 `TAudioBuffer` 进 Log/Trace；SEH dump 过滤；生产关闭 `speech.trace.audio_payload_enabled` |
| **Denial of Service** | 恶意应用独占麦克风让 WakeWord 饿死 | AudioSession 记录资源抢占，超过阈值触发 Trace 告警；不做强抢 |
| **Elevation of Privilege** | 语音唤醒→模拟按键→执行管理员操作 | DeepLaunch 语音版明确声明"不执行 UAC/提权操作"（合规产品约束） |

**A2. 麦克风常驻的攻击面**

WakeWord 默认关闭是对的，但文档没说**启用后何时自动关闭**：

- 建议加 `speech.wake_word.auto_disable_after_days = 30`（长时间未使用自动关闭）
- 建议加"前台失焦 N 分钟后降级到低频采样"（但这会引入 UX 争议，可选）
- 日志里记录"WakeWord 今日触发次数"，异常频次（>100 次/天）弹提示

**A3. Baidu/Azure 云 Backend 密钥生命周期**

当前只说 "DPAPI 加密 + 不输出原文"，但漏了：

- **密钥轮换**：用户更换 API Key 后，老密钥的 DPAPI blob 必须覆盖擦除（不能只改指向）
- **密钥泄漏响应**：当 ConfigRegistrar 检测到配置键值异常（比如解密失败多次），应触发"吊销并要求重新输入"
- **密钥作用域**：`speech.baidu.*` 目前全局共享，但不同下游应用（DeepLaunch / DeepInput）的 Baidu 账号可能不同。建议加 `speech.baidu.<app_name>.app_key`

**A4. 声纹特征 HMAC / 篡改检测**

`voice_profiles.features` 只 DPAPI 加密不够。攻击者可以：

1. 拷贝他人的 `voice_profiles` 行（跨 owner_app）
2. 替换他人的 features（让 B 的声音匹配 A 的档案）

建议：

```sql
-- 新增列
features_hmac  BLOB NOT NULL,  -- HMAC(features || profile_id || owner_app || feature_version, K_local)
```

K_local 是每机器一次性生成的本地盐（用 DPAPI 保护），用于绑定行级完整性。

**A5. 动作清单**

- [ ] design.md 新增 `§ Threat Model`（STRIDE 表）
- [ ] voice_profiles 加 `features_hmac` 列（M1 Schema 就位，M7 校验启用）
- [ ] 新增键 `speech.wake_word.auto_disable_after_days`
- [ ] 新增键 `speech.baidu.<app_name>.*` 作用域
- [ ] Trace 规范：禁止 PCM payload，建议值 `speech.trace.audio_payload_enabled=0`（与一轮一致，再次确认）
- [ ] 文档明确：DeepLaunch 语音版不承诺"执行需 UAC 的管理员操作"

---

### 2.2 实时音频系统专家

**B. 核心意见**：一轮给了 AudioSession 状态机但没给**调度策略**和**时序契约**。语音链路最容易踩坑的是 Stop 时延和资源恢复。

**B1. AudioSession 调度策略未定义**

当前只有状态枚举，缺的是：

| 抢占规则 | 决策 |
|---|---|
| WakeWord 常驻监听中，用户按 F2 | PTT 优先级更高，**硬切**（WakeWord 暂停，PTT 独占） |
| PTT 结束后 | 自动恢复 WakeWord（**重建 recognizer** 还是**复用**？） |
| 流式听写中，WakeWord 触发 | WakeWord 此时本就被 PTT/流式暂停（不会触发） |
| TTS 播报中，用户按 F2 | TTS 立即 `Stop`（200 ms 内），进入 PTT |
| 两个下游应用（DeepLaunch + DeepInput）同时想抢麦克风 | **必须失败其一**，不能并发占有。策略：先到先得 + 显式 `TryAcquireMic(OwnerApp, Purpose, Timeout)` |

**B2. Stop 时延契约的实现代价**

首轮提了 WakeWord Stop 500ms / TTS Stop 200ms / ASR final 2s。这些数字**看似合理**但落地难：

- SAPI `ISpVoice.Speak(nil, SPF_PURGEBEFORESPEAK)` 实测可能要 300–800ms（取决于当前音素）
- SAPI `ISpRecognizer` 停止 recognizer 句柄释放有延迟
- WinMM `waveInReset + waveInClose` 在 buffer 满时可能阻塞

**建议**：把时限从"承诺"改成"**best effort + 上限**"：

```
WakeWord.Stop:  best-effort 300ms, hard-limit 1500ms, 超时强制 TerminateThread
TTS.Stop:       best-effort 150ms, hard-limit 800ms, 超时用 CoDisconnectObject
ASR.Stop→Final: best-effort 800ms, hard-limit 3000ms, 超时直接 OnFinal(Error=Timeout)
```

在 PBT 里加 **"Stop 必须在 hard-limit 内返回"** 属性，而不是"某某 ms 内"精确值。

**B3. WinMM 低延迟采集的 buffer 设计未定**

当前 `DeepBase.Speech.Audio.WinMM` 是现有代码，buffer 参数没写文档。M0 Spike 要量化：

| 参数 | 建议范围 | 权衡 |
|---|---|---|
| `nSamplesPerSec` | 16000（固定 zh-CN ASR 输入格式） | — |
| buffer 大小 | 20ms / 50ms / 100ms | 20ms 延迟最低但 CPU 高；100ms 延迟高但稳 |
| buffer 数量 | 3–8 | 少易丢帧，多延迟累加 |

建议在 `speech.audio.win_mm.frame_ms` 配置键暴露，M0 Spike 给出推荐值。

**B4. SAPI Worker Thread 的重入**

SAPI COM 对象必须在 worker thread 内使用（一轮共识）。但一轮没说：

- **多个 recognizer 共享一个 worker thread 还是一人一个？**
- 建议：**一个 process 只有一个 SAPI worker thread**，所有 SAPI 调用串行化。如果 DeepLaunch 同时想 PTT + WakeWord，第二个请求排队等待。
- 这也是为什么 AudioSession 必须做"资源仲裁"而不是简单状态机。

**B5. 时钟源**

Trace 需要 `trace_id + timestamp`，但如果用 `Now`，多线程精度只有 ms 级。建议用 `TStopwatch.GetTimeStamp / QueryPerformanceCounter`，给纳秒精度，便于复盘。

**B6. 动作清单**

- [ ] design.md 新增 `§ AudioSession 调度策略表`
- [ ] design.md 把 Stop 时限改为 `best-effort + hard-limit` 两档
- [ ] PBT 规范：属性使用 hard-limit，不用 best-effort
- [ ] M0 Spike 增加"WinMM buffer 参数矩阵"任务
- [ ] 明确 "一 process 一 SAPI worker thread" 并发模型
- [ ] Trace timestamp 使用高精度时钟

---

### 2.3 i18n / 多语言本地化专家

**C. 核心意见**：Speech 模块几乎没写 i18n，而它恰恰是 i18n 最敏感的领域之一。

**C1. zh-CN 在 SAPI 上不是"一个" recognizer**

Windows 不同版本 zh 家族 token：

| Windows 版本 | 可能出现的 zh token |
|---|---|
| Win7 SP1 | 仅 `Microsoft Lili` (zh-CN TTS)，**无 zh ASR** |
| Win10 1803+ | `Microsoft Kangkang / Huihui / Yaoyao`，ASR 需下载语言包 |
| Win11 | `Microsoft Xiaoxiao / Yunyang`（神经网络），ASR 需从设置下载 |
| 企业版/教育版 | 可能被管理员禁用 Speech 组件 |

当前 design.md 说 "SAPI 5.4 Win7+ 全兼容"**不准确**。M0 Spike §4.3 的 "zh-CN recognizer token" 任务要扩成：

- 穷举测试 Win7 / Win10 1803 / Win10 20H2 / Win11 23H2 / Win11 24H2 下的实际 token 名
- 给出 `IsAvailable` 判定逻辑：不只看 `CoCreateInstance`，还要 `ISpObjectTokenCategory` 枚举 `SPCAT_RECOGNIZERS` 找 zh 开头

**C2. 语言标签必须 BCP-47 全路径**

当前 `speech.default.language = zh-CN` 是对的。但：

- SAPI 内部用 LCID（`0x0804` for zh-CN），不用字符串。门面层要做转换。
- 用户可能输入 `zh`（不带区域）、`zh-Hans-CN`（含 script）、`zh_CN`（下划线变体）。需要归一化。
- Fallback 链：`zh-Hans-CN → zh-CN → zh-Hans → zh`。未命中再回 `en-US` 还是报错？**建议报错**，让用户显式选择。

**C3. TTS voice 语言不等于 ASR 语言**

当前 `speech.default.language` 一个键管全。应拆：

- `speech.asr.language`
- `speech.tts.language`（默认等于 asr.language，但可独立）

场景：用户输入中文，想听英文回读学习发音。一轮没想过。

**C4. 混合语言（code-switching）**

中文对话里常混英文词（品牌名、命令名）：

- Dictation 模式下 SAPI zh recognizer 对英文词识别很差
- Grammar 模式不受影响（词表里可以混中英文）
- WakeWord 混合词"打开 Chrome"**可能失败**

建议：

- Grammar 模式下允许混合
- Dictation 模式下在 design.md 里明确声明"英文词识别依赖 Backend 能力，不保证"
- Whisper.cpp（M8 后）天然支持混合

**C5. 数字/日期/货币归一化**

ASR 输出 `"三月八号下午三点"` vs `"3月8日15:00"`。

- 当前 `TSpeechRecognitionResult.Text` 是原始识别文本
- 归一化（NLU 前处理）**不属于 DeepBase.Speech 职责**，应放在 IntentParser
- 但 design.md 没明确这个分工

**C6. 字符归一化（WakeWord 词表）**

一轮提了"全/半角归一化"和"非 BMP 字符拒绝"。补充：

- **繁简转换**：用户输入"深啟"（繁），是否应匹配"深启"？**建议不做自动转换**，让用户显式写他要的词形
- **零宽字符**：U+200B/200C/200D 必须剥离
- **全角空格**：必须规范化为半角空格或剥离
- **emoji 和符号**：拒绝（非 BMP 以外的规则字符也要考虑）

**C7. 动作清单**

- [ ] requirements.md 拆分 `speech.asr.language` 和 `speech.tts.language`
- [ ] design.md 新增 `§ i18n / Locale Handling`，明确 BCP-47 归一化 + Fallback 策略
- [ ] M0 Spike 增加"Win7/10/11 下 zh recognizer token 矩阵"任务
- [ ] WakeWord 归一化规则加"零宽字符剥离、繁简不自动转、emoji 拒绝"
- [ ] 明确 Dictation 模式下混合语言识别不保证，Grammar 模式支持

---

### 2.4 发布工程 / DevOps 专家

**D. 核心意见**：DeepBase.Speech 新增 7 个单元加现有 5 个，dpk 变大变复杂，CI 矩阵必须跟上，否则 DeepInput 重构会变成盲飞。

**D1. DeepBaseFeatures.dpk 切分策略**

当前所有 Speech 单元都进 `DeepBaseFeatures.dpk`。问题：

- DeepInput 只需要 ASR，但会被迫链接 TTS/WakeWord/Voiceprint 的代码
- `DeepBase.Speech.MFCC/DTW` 是纯数学代码，link 进 DeepInput 增加体积但不被使用

建议切分：

| dpk | 内容 | 谁用 |
|---|---|---|
| `DeepBaseFeatures.dpk` | 核心 Types / Service / AudioCapture / VAD / Registry / Config / Policy / Runtime | 所有下游 |
| `DeepBaseFeaturesASR.dpk` | ASR Backend（SAPI/Baidu/WinRT） | DeepInput/DeepLaunch |
| `DeepBaseFeaturesTTS.dpk` | TTS Backend | DeepLaunch |
| `DeepBaseFeaturesWake.dpk` | WakeWord + AudioSession 仲裁扩展 | DeepLaunch（语音版） |
| `DeepBaseFeaturesVoice.dpk` | MFCC + DTW + Voiceprint | DeepLaunch v2.0 |

权衡：dpk 数量多，但每个下游只引自己需要的。

**另一种方案**：全进 `DeepBaseFeatures.dpk`，但用条件编译 `{$IFDEF DEEPBASE_SPEECH_FULL}` 控制。这个方案简单，但要求所有下游统一开关，不够灵活。

**建议**：**采用 dpk 切分**，理由是 Delphi 生态习惯。

**D2. 二进制兼容（ABI）**

一轮强调 DeepInput 完全重构（你的最新决策），但重构后 DeepInput 的发布节奏会**强依赖 DeepBaseFeatures.dpk** 的版本。任何接口变化都会让 DeepInput 重编。

缓解：

- **接口使用 GUID 而非名称绑定**：所有 `ISpeechRecognizerEx / IASRStream / ITTSBackend` 的 `['{GUID}']` 保证新增方法走新接口（`IASRStream2 = interface(IASRStream) [...]`）
- **记录 API level**：`const SPEECH_API_LEVEL = 1`，下游检查
- **不在 record 上加新字段**：扩展用新的 record 类型

**D3. 单元测试 / PBT 的 CI 矩阵**

一轮的 CI 三层（headless / nightly / manual）是对的。具体化：

| 测试线 | 跑哪些 | 机器 | 频次 |
|---|---|---|---|
| headless | Types PBT / Registry / Config / Policy / Schema 迁移 / DPAPI 往返（mock） / fake Backend | GitHub Actions ubuntu-latest + wine？或 windows-latest | PR |
| nightly-sapi | 真 SAPI ASR batch / SAPI TTS / 语言包探测 / 空数据路径 | 自建 Win10 + Win11 runner | 每日 |
| manual-mic | WakeWord 误触率 / 设备并发 / PTT 时延 / AudioSession 状态切换 | 人工桌面 | 每个 PR label `hardware` |

**问题**：Delphi 37.0 + SAPI 没有官方 headless 方案。Github Actions 的 windows-latest 是否有 SAPI zh 语言包？**需要 M0 Spike 验证**。

**D4. Delphi 版本矩阵**

当前固定 Delphi 37.0。但：

- DeepInput 未发布，用什么 Delphi 版本不确定
- 其他下游（DeepLaunch/DeepStory 等）可能有遗留版本

一次只支持 37.0 没问题，但要**在 README/dpk/dproj 明确声明**：

- 最低 Delphi 版本 `CompilerVersion >= 37.0`
- 如果加老版本支持，要走独立 branch 不走主线

**D5. 构建产物**

- [ ] `.dpk` 编译产物路径统一到 `DeepBase/bin/`
- [ ] `.dcu` 产物不进 git（`.gitignore` 验证）
- [ ] PBT dpr 产物独立到 `DeepBase/Tests/bin/`

**D6. 依赖图**

画一下 DeepBase.Speech 对 DeepBase 其他模块的依赖：

```
DeepBase.Speech.*
  ├─ DeepBase.Core.*                    （ConfigDB、Schema、Logger）
  ├─ DeepBase.Security.DPAPI            （密钥/声纹加密）
  ├─ DeepBase.Governance.ConfigRegistrar（门禁注册）
  ├─ DeepBase.Commerce.Permissions      （旧，现有 Service 已依赖）
  └─ DeepBase.LLM.Client                 （M8 IntentParser 可选）
```

问题：`DeepBase.Commerce.Permissions` 是否该继续存在？ 如果已有 `Governance` 作为统一策略，Permissions 应该被收敛掉。否则 DeepBase.Speech.Policy 同时依赖两套策略体系。

**M0 或 M1 阶段要回答**：Permissions vs Governance 二选一。

**D7. 动作清单**

- [ ] design.md `§ Packaging` 节给 dpk 切分方案
- [ ] 所有新接口声明 GUID（interface 有 GUID 的规矩要写进规范）
- [ ] `SPEECH_API_LEVEL` 常量
- [ ] 明确 Delphi 37.0 最低版本
- [ ] M0 Spike 加"GitHub Actions windows-latest 是否能跑真 SAPI"任务
- [ ] M1 前决定 `Commerce.Permissions` 与 `Governance.Policy` 合并或共存

---

### 2.5 可访问性 / 辅助技术专家

**E. 核心意见**：Windows 桌面系统级 TTS 的第一用户是**残障用户**，DeepBase.Speech 抢占 SAPI 资源会造成无障碍功能失效。

**E1. 屏幕阅读器冲突（最严重）**

NVDA、JAWS、Narrator 都在使用 SAPI：

- Narrator 默认用 WinRT Speech（新架构），但 fallback 到 SAPI
- NVDA 可配置为 SAPI TTS 输出
- DeepBase TTS 播报时，**屏幕阅读器会被打断**

场景：盲人用户在 DeepLaunch 里听到"已为你打开计算器"（DeepBase TTS），同时 NVDA 在读"计算器窗口已激活"。**两个声音叠加，用户完全听不清**。

缓解：

- **检测屏幕阅读器存在**：调 `SystemParametersInfo(SPI_GETSCREENREADER)` 判断
- 如果检测到屏幕阅读器：
  - **DeepBase TTS 默认静默**（让屏幕阅读器全权处理语音反馈）
  - 或提供配置 `speech.tts.defer_to_screen_reader = 1`（默认 1）
- **WakeWord** 不受影响（只是监听），但**语音反馈要让位**

**E2. SAPI voice 独占**

部分屏幕阅读器在启动时独占某个 SAPI voice（如 Microsoft Huihui）。DeepBase TTS 如果同样默认选 Huihui，会和屏幕阅读器争抢。

建议：

- `SupportedVoices` 枚举时**标记哪些 voice 当前被其他进程占用**（`ISpObjectToken.GetStorageFileName` 能查到引用计数？需 Spike 验证）
- 默认 voice 选择规则：**跳过被占用的**，选第一个 idle 的

**E3. ASR 与语音控制（Voice Access）冲突**

Win11 有"Voice Access"功能（语音控制全系统）。用户开着 Voice Access 的同时开 DeepLaunch WakeWord：

- 两个常驻监听竞争同一麦克风
- 可能导致 Voice Access 识别率下降

缓解：

- 检测 Voice Access 是否运行（进程名 `VoiceAccess.exe`）
- 如果检测到：**WakeWord 默认不启动**，提示用户"Windows 语音控制已运行，不需要重复启用"

**E4. 热键冲突（非语音但相关）**

F2 作为 DeepLaunch PTT 热键。但：

- F2 在很多应用里是"重命名"（文件管理器、Excel）
- 全局热键 F2 会吃掉应用的 F2

建议：

- 全局热键默认使用组合键（如 Ctrl+F2 或 Win+/）
- "纯 F2"作为可选配置，用户显式启用
- **这是产品层决策**，不全是 DeepBase 职责，但 DeepBase 文档应提示下游

**E5. 延迟与反馈**

无障碍用户对"没有反馈"特别敏感：

- PTT 按下 → 应有**立即的音频反馈**（滴声或震动），而非等 ASR 结果
- TTS 开始前 → 应先有**短蜂鸣**作为"我要说话了"提示

这是产品层要求，DeepBase.Speech 不主动实现，但**接口要能支持**：

- `TTTSOptions` 加 `PreBeep: Boolean`（默认 False）
- `ITTSBackend.Speak` 支持 "SSML-lite 标记"（至少能表示 `<audio src="beep"/>`）—— 但 D5 已定"暂不支持 SSML"，此处矛盾。折中：加 `ITTSBackend.PlayEarcon(name)` 单独接口

**E6. 动作清单**

- [ ] design.md 新增 `§ Accessibility Coexistence`
- [ ] 新增键 `speech.tts.defer_to_screen_reader`（默认 1）
- [ ] 新增键 `speech.wake_word.defer_to_voice_access`（默认 1）
- [ ] `ITTSBackend` 增加 `PlayEarcon` 接口（或推迟到 M4）
- [ ] M0 Spike 增加"屏幕阅读器检测 + voice 占用探测"任务
- [ ] 产品层（DeepLaunch）热键默认不用纯 F2 —— 这条提议需要你反馈（与 DeepLaunch 产品文档矛盾）

---

## 三、二轮评审汇总表

| # | 问题 | 严重性 | 影响里程碑 | 新增/修改 |
|---|---|---|---|---|
| A1 | Threat Model 缺失 | P0 | design.md | 新增 STRIDE 表 |
| A4 | 声纹 features HMAC | P0 | Schema, M1 | 新增 `features_hmac` 列 |
| A2 | WakeWord 自动关闭策略 | P1 | Config | 新增 `auto_disable_after_days` |
| A3 | Baidu 密钥分 app 作用域 | P1 | Config | 新增 `speech.baidu.<app>.*` |
| B1 | AudioSession 调度策略 | P0 | design.md | 新增调度表 |
| B2 | Stop 时限 best-effort + hard-limit | P0 | requirements + design | 改时限契约 |
| B3 | WinMM buffer 参数 | P1 | M0 Spike | 新增 Spike 任务 |
| B4 | 一 process 一 SAPI worker thread | P0 | design.md | 明确并发模型 |
| B5 | Trace 高精度时钟 | P2 | design.md | 明确时钟源 |
| C1 | zh-CN recognizer token 矩阵 | P0 | M0 Spike | 扩展 Spike 任务 |
| C2 | BCP-47 归一化 + Fallback | P1 | design.md | 新增 i18n 节 |
| C3 | 拆 `speech.asr.language` / `speech.tts.language` | P1 | Config | 拆键 |
| C4 | 混合语言识别声明 | P2 | design.md | 写进限制条款 |
| C6 | 零宽字符/emoji/繁简规则 | P1 | requirements | 补 Req 15 边界 |
| D1 | dpk 切分 | P1 | design.md | 新增 Packaging 节 |
| D2 | 接口 GUID + API level | P0 | 所有 interface | 规范要求 |
| D3 | CI 矩阵具体化 | P1 | tasks.md | 细化 CI 任务 |
| D6 | Commerce.Permissions vs Governance 合并 | P0 | M0 或 M1 前置 | 架构决策 |
| E1 | 屏幕阅读器冲突 | P0 | design.md + Config | 新增键 + 文档 |
| E2 | SAPI voice 占用检测 | P1 | M0 Spike | 新增 Spike 任务 |
| E3 | Voice Access 冲突 | P1 | Config | 新增键 |
| E4 | 默认热键不用纯 F2 | P2 | DeepLaunch 产品决策 | 需用户反馈 |

---

## 四、需要你再拍板的事（二轮新增）

| ID | 问题 | 建议 |
|---|---|---|
| E1 | DeepBase TTS 是否默认让位屏幕阅读器？ | **是**（`speech.tts.defer_to_screen_reader = 1`） |
| E3 | 检测到 Voice Access 时 WakeWord 默认关闭？ | **是**（不抢占系统级语音控制） |
| E4 | DeepLaunch 默认热键是否改为组合键（Ctrl+F2）？ | 与 DeepLaunch 产品文档冲突，**请你定** |
| D1 | dpk 切分成 5 个，还是一个 `DeepBaseFeatures.dpk` 全包？ | **切分** |
| D2 | 所有 Speech interface 强制 GUID + `SPEECH_API_LEVEL`？ | **是** |
| D6 | `Commerce.Permissions` 要不要收敛到 `Governance.Policy`？ | **是**（但要列出兼容性迁移步骤，不本次做） |
| A4 | 声纹 HMAC 列 Schema 先就位，校验推迟到 M7？ | **是**（避免 M7 再改 Schema） |
| B2 | Stop 时限改"best-effort + hard-limit"双轨？ | **是** |
| C3 | 拆 `speech.asr.language` 和 `speech.tts.language`？ | **是**（向后兼容：保留 `speech.default.language` 作为默认值源） |

---

## 五、对第一轮方案的整体评价

第一轮评审**非常到位**，把"直接开工"阻止住了。二轮找到的问题分为：

1. **第一轮覆盖但不深**：声纹威胁（STRIDE）、AudioSession 调度
2. **第一轮未覆盖**：i18n、可访问性、发布工程（dpk/CI 细节）、屏幕阅读器冲突
3. **第一轮提及但值可再斟酌**：Stop 时限（best-effort vs 硬承诺）

综合看，**两轮评审后方案已经可以立项**。下一步：

1. 你针对第四节 9 个决策点给答复
2. 我根据答复一次性修订 requirements.md / design.md / tasks.md / 开发规范.md
3. 启动 M0 Spike

---

## 六、M0 Spike 二轮补强任务清单

基于两轮评审，M0 Spike 任务从一轮的 10 条扩到 16 条：

| # | 任务 | 来源 |
|---|---|---|
| S01 | Delphi 37.0 SAPI COM 声明可用性 | 一轮 |
| S02 | Win7/10/11 SAPI zh recognizer/voice token 矩阵 | 一轮+C1 |
| S03 | 16k zh PCM16 WAV batch ASR | 一轮 |
| S04 | SAPI 自采麦克风 live streaming | 一轮 |
| S05 | SAPI FeedAudio（自定义 PCM chunk queue）可行性 | 一轮 |
| S06 | WinMM buffer 20/50/100ms 延迟+CPU 基准 | 一轮+B3 |
| S07 | SAPI recognizer + WinMM capture 并发占用 | 一轮 |
| S08 | WakeWord Grammar zh 词"小启"等 confidence 分布 | 一轮 |
| S09 | 监听中动态 SetWords 稳定性 | 一轮 |
| S10 | TTS SpeakAsync/Stop/连续/空文本/voice 切换 | 一轮 |
| S11 | GitHub Actions windows-latest 是否可跑真 SAPI | D3 |
| S12 | 屏幕阅读器检测 `SPI_GETSCREENREADER` 验证 | E1 |
| S13 | Voice Access 检测（进程名 VoiceAccess.exe）验证 | E3 |
| S14 | SAPI voice 占用状态探测 | E2 |
| S15 | DPAPI 跨用户/跨机器失败路径验证 | 二轮序言 6 |
| S16 | QueryPerformanceCounter 在多线程精度验证 | B5 |

---

> **建议**：你先对第四节 9 个决策点拍板，我一把梭修订所有文档。
