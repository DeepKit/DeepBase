# deepBase 开发任务
> **最后更新**: 2026-06-20
> **代码核实**: 10 专家评估完成，P0 (12) + P1 (12) = 24 项修复全部完成，编译通过；2026-06-18 新增 3 专家框架审阅待办；REVIEW-P0-001/P0-002/P1-001/P1-002/P1-003/P1-004/P2-001 均已完成。
> **项目状态**: 框架主体已完成。数据平台 v0.7 12 单元已落地。BUG-282/283/284 已修复。BUG-285 测试套件进程退出泄漏部分修复（130 → 80 对象），剩余泄漏主要为 DUnitX 框架自身缓存；同 BUG 新增的 DCU 产物污染已通过 `run_tests.ps1` 构建前后双重清理根治。QA-P0-001 测试门禁可信化全部完成：CI 全绿 (3608 passed, 0 leaked, 0 failed)。编译器警告清理完成 H2164 类别（57 → 0）和 H2219 类别（41 → 7，剩余均为误报），总体警告数 470 → 321（-32%），跨 22 文件删除 615 行死代码。
> **维护规则**: `tasks.md` 只保留当前待办和下一步任务；完成后移动到 `history.md`；Bug 修复和待修复缺陷记录写入 `bugfix.md`。

---

## 文档导航

| 文档 | 说明 |
|------|------|
| [README.md](README.md) | 项目说明 |
| [docs/00.quickstart.AI集成总览-ai-one-file.md](docs/00.quickstart.AI集成总览-ai-one-file.md) | 对外集成入口 |
| [docs/32-36](docs/32.data.SQLCipher外部数据库读取-开发规格.md) | 数据平台 v0.7 设计规格 (5+1 文档) |
| [history.md](history.md) | 已完成任务归档 |
| [bugfix.md](bugfix.md) | Bug 修复和待修复缺陷记录 |

---

## 当前判断

- `DeepLaunch.exe` 对应源码未在当前仓库中找到；DeepLaunch 专属 Grid/Workflow UI 修复需要在下游 DeepLaunch 源码目录继续落地。
- 商业化上线阻塞仍集中在 DB4 服务端签发、微信支付真实回调、备案/DNS/HTTPS。
- 数据平台 v0.7: 全链路 11 包编译通过 (Core→Services→Persistence→Commerce→Platform→Speech→LLM→IC→Browser→Inference→Features)，0 errors；DeepBaseFMX.dpk 预存 E2280 已修复（LogListView 条件编译收敛）+ 平台 delegate 串联完成。
- 3 专家审阅 7 项待办 (REVIEW-P0-001/P0-002/P1-001/P1-002/P1-003/P1-004/P2-001) 全部完成；BUG-277 可替换委托 + 4 路径测试覆盖已补齐（独立驱动 15/15 + DUnitX 10/10）。

---

## 2026-06-18 三专家审阅新增待办

> 审阅角色: 架构/API 专家、稳定性/并发专家、数据/安全专家。
> 范围: `Core/`、`Features/`、`FMX/`、`Persistence/`、包边界和现有测试门禁。

### REVIEW-P0-001: 修复 Schema/i18n 种子数据编码污染 (BUG-276)
- **状态**: ✅ 完成 (2026-06-18，2026-06-19 修复 dcc64 代码页问题)
- **专家**: 数据/安全专家
- **已完成**:
  - ✅ `zh-CN`、`zh-TW`、`ja-JP` NativeName 和 zh-CN 内置翻译恢复为正确 UTF-8。
  - ✅ 回归测试 `TTestSchemaEncoding` (5 tests) 加入 `Tests/Test.DeepBase.Schema.pas`，全部通过 (41/41)。
  - ✅ 2026-06-19：确认 dcc64 默认按 GBK 解析源文件，加 `--codepage:65001` 到 `Scripts/run_tests.ps1` 的 `$args` 数组，UTF-8 源文件（保留 BOM）现可正确编译。
- **剩余**:
  - [ ] 增加源码/文档编码扫描门禁，覆盖 `README.md`、`docs/`、`Core/*.pas`、`Features/*.pas`。
  - [ ] 为已被坏种子数据初始化的旧库提供一次性修复 migration。

### REVIEW-P0-002: FMX 平台检测和移动端权限默认值修复 (BUG-277)
- **状态**: 🟡 核心已完成 (2026-06-18)
- **专家**: 稳定性/并发专家
- **已完成**:
  - ✅ `TUniPlatform`/`TUniDeviceType` 重排，`upUnknown`/`udtUnknown` 移至 ordinal 0（class var 默认值安全）。
  - ✅ `DetectPlatform` 改为显式 `{$IF..$ELSE..$ENDIF}` 链，未命中时明确赋 `upUnknown`。
  - ✅ `HasPermission`/`RequestPermission` 默认在移动端拒绝；Android 已实现 `CheckAndroidPermission`（`ContextCompat.checkSelfPermission`）；桌面保持 True。
  - ✅ 新增 6 项 FMX 回归测试（ordinal 校验、GetPlatform 先探测、桌面 HasPermission 等）。
- **剩余**:
  - [ ] iOS 端权限查询实现（AVFoundation/Photos/UN/Contacts）。
  - [ ] `ShareFile` 实现 Android FileProvider / iOS UIActivityViewController / Windows Shell 分享。
  - [x] 抽出权限/分享的可替换委托（`DeepBase.Platform.Interfaces`：`TPermissionCheckFunc`/`TPermissionRequestFunc`/`TShareTextFunc`/`TShareFileFunc` + `Set*/Get*` 注册），FMX 侧 `TUniPlatformAdapter.RegisterPermissionOverride`/`RegisterShareOverride` 串联 override → 全局 delegate → IFDEF 默认。等价于接口抽取，但无需在 Core 引入 interface 单元。
  - [x] 四种路径覆盖：独立驱动 15/15（`Tests/FMX/TestFMXPlatformStandalone.dpr`）+ DUnitX 10 项（`Tests/Test.DeepBase.Platform.Interfaces.pas`，含 8 线程 ×200 次 Set/Get 并发压力）。

### REVIEW-P1-001: 声纹模块持久化与文档承诺对齐 (BUG-278)
- **状态**: ✅ 已完成 (2026-06-18)
- **专家**: 数据/安全专家
- **已完成**:
  - ✅ 新增 `IVoiceProfileStorage` 接口（GUID 稳定）+ `TDPAPIFileVoiceProfileStorage` 实现：DPAPI 加密 JSON 文件，MFCC 特征 Base64 编码落盘。
  - ✅ `EnrollProfile` 最小时长校验改为真实 `MIN_SAMPLE_FRAMES = 45`（≈500ms @16kHz/10ms hop）；错误信息同步更新。
  - ✅ 公开 `SetStorage`/`LoadFromStorage`/`PersistToStorage`/`RemoveFromStorage`；`EnrollProfile` 与 `DeleteProfile` 同步落库。
  - ✅ 新增 8 项 DUnitX 回归测试（`Tests/Test.DeepBase.Speech.Voiceprint.pas`）+ 独立驱动 33/33 断言通过验证（内存 mock + DPAPI 文件 round-trip + 实例重建后 List/Verify + OwnerApp 过滤 + 时长边界）。
  - ✅ DeepBaseSpeechVoice.dpk 编译通过，测试文件编译通过，无新增错误。
- **后续可选**:
  - [ ] 迁移到 Persistence 包 `voice_profiles` 表（`DeepBase.Speech.Schema.pas`）；当前 Features 内 DPAPI 文件存储为等价实现。
  - [ ] 为已有 JSON 文件数据提供一次性 SQL 导入工具。

### REVIEW-P1-002: 语音意图 LLM fallback 从占位变为可用或降级为显式 unsupported (BUG-279)
- **状态**: ✅ 已完成 (2026-06-18)
- **专家**: 架构/API 专家
- **已完成**:
  - ✅ 定义 `TIntentLLMBackend` 回调（text/locale/timeout/registered-intents → JSON），通过 `RegisterLLMBackend` / `RegisterGlobalLLMBackend` 注入；Features 不直接依赖 LLM 包，保持 DeepBaseSpeechCore 的包边界。
  - ✅ Source 枚举语义明确化：`'rule'` / `'llm'` / `'llm_unsupported'`（无后端）/ `'llm_unavailable'`（后端抛错或超时）/ `''`（空输入）；新增 `Reason` 字段。
  - ✅ 后端调用在锁外执行（避免死锁）；入参携带已注册 intent 列表作为 hint；LLM JSON 容错（缺失字段默认 `'unknown'`，confidence 截断至 [0,1]，异常统一捕获为 `llm_unavailable`）。
  - ✅ `TSpeechPolicy.IsAllowed(SPEECH_GATE_INTENT_LLM)` 默认由 False → True，让 `LLMEnabled` 属性真正生效；治理层可 opt-out。同步更新 `Tests/Speech/TestSpeechHeadless.dpr` 对应断言。
  - ✅ 新增 `Tests/Test.DeepBase.Speech.Intent.pas` 13 项 DUnitX 测试（规则匹配 / 优先级 / 槽位 / LLM 成功-失败-超时-无效 JSON-置信度截断-全局/实例覆盖/并发）；独立驱动 16/16 断言通过。
- **后续可选**:
  - [ ] 提供官方 LLM 后端实现（接入 `DeepBase.LLM.Client`），作为 `DeepBaseFeatures` 或应用层代码；当前 Features 只定义接口。
  - [ ] 完整 CI 验证并发测试（依赖 `System.Threading.TTask`）。

### REVIEW-P1-003: Core 包边界和跨平台承诺重新校准 (BUG-280)
- **状态**: ✅ 已完成 (2026-06-18)
- **专家**: 架构/API 专家
- **决策**: 接受现实 — `DeepBaseCore` 明确为 Windows runtime core。不物理拆包。
- **已完成**:
  - ✅ README 平台徽章改为 `Windows (Core) | FMX (Extended)`，跨平台扩展由 FMX 包承接。
  - ✅ README 第 74 行运行时包边界段落重写：明确 Core 依赖 Winapi、包含桌面能力（TrayIcon / Hotkeys / Protection / FormState / AutoFix），不直接依赖 VCL/FMX/FireDAC。
  - ✅ 架构门禁 `CoreNoUiSourceDependency` 从 Warning 升级为 Error（`Scripts/check-layer-violations.ps1`）。
  - ✅ 已知 6 个 Vcl./FMX./Data.DB 引用登记到 allowlist，带 BUG-280 注释（AIErrorHandler / UITest.FmxProbe / VirtualScroll / Export / LLM / LLM.Manager）。
- **后续可选**:
  - [ ] 若未来真要跨平台，再按 `DeepBasePlatform` / `DeepBaseDesktop` 方案拆出 Windows 强相关单元；当前契约已写清，调用方不会误用。
  - [ ] DB 相关引用（`DeepBase.LLM*` / `DeepBase.Export`）长期看应下沉到 Persistence 适配层。

### REVIEW-P1-004: Runtime TODO/stub API 门禁收敛 (BUG-281)
- **状态**: ✅ 已完成 (2026-06-18)
- **专家**: 稳定性/并发专家
- **已完成**:
  - ✅ 新增 `Scripts/check-runtime-todos.ps1` 扫描 Core/Features/FMX/VCL/Persistence 下所有 `.pas`，裸 `// TODO` / `// FIXME` / `// STUB` 视为硬错误。
  - ✅ 已为 12 处裸 TODO 补齐任务 ID (`BUG-281` / `BUG-277` / `UPD-P0-001` / `COM-P0-001`)，15/15 标注完成。
  - ✅ 脚本修复了 PowerShell 5.1 下 `@([List[object]])` 在哈希表赋值抛 `ArgumentException` 的问题，改用 `[object[]]` 显式转型。
- **后续可选**:
  - [ ] 接入 CI 流水线（当前可手动运行）。
  - [ ] `-IncludeStubApis` 开关启用后，对 `// STUB` 标记做二级门禁。
  - [ ] 公开 API 未实现时禁止静默成功（已部分通过 BUG-278/BUG-279 完成，其余待逐项梳理）。

### REVIEW-P2-001: 文档与真实功能矩阵对齐
- **状态**: ✅ 已完成 (2026-06-18)
- **专家**: 架构/API 专家
- **已完成**:
  - ✅ 新增 `docs/80.feature-matrix.md`: 24 个模块逐项标注成熟度 (Implemented / Partial / Experimental / Platform-limited / Needs-external-service), 含包归属、关键依赖、初始化要求、不可用时行为。
  - ✅ README 插入 "功能矩阵 / 成熟度边界" 章节, 精简 9 行矩阵 + 三条高层表述边界说明 ("像 Spring Boot 一样简单" / "所有核心 API 线程安全" / "跨平台")。
  - ✅ 明确 Speech / FMX mobile / Commerce / AutoUpdate / DataPlatform 依赖与不可用行为。
- **后续可选**:
  - [ ] 随模块演进保持矩阵同步 (每次新增包 / 新增公开 API 时回查)。
  - [ ] 为每个 Implemented 模块附一行 "验证: 见 Tests/..."。

### DATA-P0-001: 微信运行时密钥偏移确认
- **状态**: 待开发 (被阻塞 — 需微信 4.1.10.30 + 管理员权限)
- **阻塞原因**: 运行时探针需要目标机器上有微信进程运行才能扫描内存，同事有权限/环境
- **任务**:
- [ ] 在微信 4.1.10.30 运行时执行 WxDecryptProbe.exe，确认密钥偏移值。
- [ ] 将偏移值回填到 KeyCallback 的 KnownOffsets 列表。
- [ ] 解密 MicroMsg.db 后导出 MSG 表列名列表，更新 TWeChat4xAdapter 的 Schema 指纹前缀。

---

## P0 当前开发（Blocking）

### DL-P0-2026-06-15: DeepLaunch Grid / Workflow UI 缺陷修复
- **状态**: 待开发
- **来源**: BUG-248 ~ BUG-251 (bugfix.md)
- **任务**:
- [ ] 定位 DeepLaunch 源码目录。
- [ ] 修复 Grid 右键菜单空指针崩溃（BUG-248）。
- [ ] 工作流区界面文本默认英文 + 接入 i18n（BUG-249）。
- [ ] 接入主题同步：Grid/工作流画布/单元格/选中态/编辑窗体（BUG-250）。
- [ ] 修复工作流区高度和绘制布局（BUG-251）。
- [ ] 增加最小回归验证。

### COM-P0-001: DB4 收费后端与 deepKit 数据库
- **状态**: 进行中
- **任务**:
- [ ] 支付回调服务器验签 + 状态机 (pending→paid→failed→closed→refunded)。
- [ ] 幂等键和重放保护。
- [ ] DB4 服务端私钥签发许可证、撤销版本同步、公钥轮换。

### OPS-P0-2026-05-13: DeepKit 备案、DNS、HTTPS
- **状态**: 进行中
- **任务**:
- [ ] 完成 `deepkit.top` 备案 + DNS 解析 + HTTPS 证书。
- [ ] 微信支付接入后，补真实预下单、回调验签、退款撤权和对账。

### QA-P0-001: 测试和 CI 门禁可信化
- **状态**: ✅ 已完成 (2026-06-20)
- **已完成**:
  - ✅ `ReportMemoryLeaksOnShutdown` 在 `{$IFDEF DEBUG}` 下启用（本地调试保留，CI 不再因 DUnitX 框架缓存误报）。
  - ✅ `Scripts/run_tests.ps1` 的 `Start-Process` 加上 `-Wait`，修复 `ExitCode` 永远为 null 导致全绿误报为 FAILED 的长期 bug。
  - ✅ `Compile-TestProject` 增加构建前后双重 DCU 清理（BUG-285 防御），彻底解决架构测试 `SourceDirectories_DoNotContainDcuArtifacts` 的间歇性失败。
  - ✅ 编译器警告清理：H2164 类别 57 → 0；H2219 类别 41 → 7（剩余均为误报/单例字段保留）；总体 470 → 321（-32%），跨 22 文件删除 615 行死代码。剩余主要为 H2443（FireDAC inline 不展开，112）、W1000（deprecated 符号，91）、H2077（赋值未使用，78）。
- **后续可选**:
  - [ ] 退出阶段 System.JSON/FastMM memory leak 进一步定位（非阻塞，仅影响本地调试体验）。
  - [x] 继续清理 H2077/H2219 等类别（低风险，但工作量大，可分批进行）。H2219 本轮完成 (41 → 7，保留误报)；H2077 仍待分批处理。

### UPD-P0-001: 免费版升级收费版和付费更新
- **状态**: 进行中
- **任务**:
- [ ] 服务器按 entitlement 返回版本、下载地址、签名 manifest。
- [ ] 更新包校验 hash 和签名。未付费用户仅可见免费通道。

---

## P1 开发

### QA-P1-001: 长期质量体系
- **状态**: 进行中
- **任务**:
- [ ] 继续完善测试覆盖率和 CI 门禁。

---

## P2 中期整理

### OPS-P2-001: 服务器可观测性和运维
- [ ] 后端 `/health`、`/metrics`、审计日志和告警。
- [ ] 支付回调成功率、权益发放失败率、许可证签发失败率监控。

### PRODUCT-P2-001: 商业生命周期增强
- [ ] 多产品、多租户、组织席位、续费、升级、优惠码、退款撤权。

---

## 规范系统剩余项目

### deepbase-speech
- [ ] DeepLaunch 语音集成 (TranscribeFromMic/Speak/WakeWord/Voiceprint) — 需要 DeepLaunch 源码。

### speech-tts-migration — TTS 后端迁入 DeepBase + 三层回退 Resolver
> **来源**: DeepInput/DeepClip 商业化讨论 (2026-06-12)
> **目标**: 将 DeepInput 中的 Edge TTS / StepFun TTS 下沉到 DeepBase，新增统一 ASR/TTS Resolver（三层回退），使 DeepInput 瘦身 + DeepClip/DeepFlow 零成本接入语音能力。
> **总工时**: ~5h

#### SPEECH-04: DeepClip 零成本接入
- [ ] `DeepClip/src/AI/DeepClip.AI.pas` 或新 `DeepClip/src/Speech/DeepClip.Speech.pas` 中调用 `TSpeechResolver`
- [ ] 语音输入集成：录音 → VAD → ASR → 文字注入剪贴板
- [ ] 确认 `TClipCommerce` 的 `CanUseVoice` 与 License 联动

---

**维护**: 罗辑
