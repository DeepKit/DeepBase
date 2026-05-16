# DeepBase 开发历�?
> 本文档记录已完成的任务和功能迭代

---

## 2026-05-14 IntentClarification Phase 2 编译接入修复

### IC-P0-2026-05-14A: 编译链、IoC 和最小集成测试恢复
- **完成日期**: 2026-05-14
- **内容摘要**:
  - IntentClarification Phase 2 单元已进入 `DeepBaseFeatures.dpk/.dproj` 和 `Tests/DeepBaseTests.dpr/.dproj` 主编译链。
  - 核心类型契约和 `DeepBase.IntentClarification.Registration.pas` 首轮补齐，解决 Phase 2 单元无法进入包/测试工程的问题。
  - IoC provider 注册改为显式 interface instance，避免 `TL1SlotProvider(AClarifier)` optional constructor 被 RTTI 容器误解析。
  - L2-L4 provider 已进入 IoC named registration；Engine 未配置 LLM 时跳过 LLM provider，保证最小下游接入路径不产生 `PROVIDER_ERROR`。
  - `HandleExit` 增加异常兜底和 session 写回锁，输入 `0` 的最小退出路径通过集成测试。
  - 为主测试编译链顺带修复 Browser CDP/Vision/ScriptStore 编译阻塞，详见 `bugfix.md` 的 BUG-164、BUG-165。
- **验证**:
  - `cmd /c compile_test.bat`：`compile_output.txt` 为 `Exit code: 0`。
  - `Tests\DeepBaseTests.exe -b -r:Test.DeepBase.IntentClarification,TICIntegrationTest,TICResilienceIntegrationTest,TICSessionFSMTest`：20 tests passed，0 failed，0 errored，0 leaked。
  - `Tests\DeepBaseTests.exe -b -r:Test.DeepBase.Browser.ScriptStore.TJSTemplateTests,Test.DeepBase.Browser.ScriptStore.TBuiltinDefaultsTests`：20 tests passed，0 failed，0 errored，0 leaked。
  - 完整 `Tests\DeepBaseTests.exe` 当前为 3372 found，3351 passed，3 ignored，6 failed，12 errored；失败集中在 Browser Registry/WindowPool/Automation、FeatureFlags rollout、License legacy signing、DB.DoQry DDL gate 和 Performance benchmark，未在本轮收敛。
- **遗留**:
  - 公开 `DeepBase.IntentClarification.pas` 里的 `IClarificationEngine` facade 仍为空，`CreateEngine/CreateEngineWithPreset` 仍未对齐真实 `Interfaces/Engine`。
  - `IDomainAdapter.GetPresetSlots` 尚未接入 Engine/L1；Engine session 并发、Provider session-scoped state、Router 边界、LLMResilience timeout/ErrorMessage、L4 全失败语义继续保留在 `tasks.md`。

---

## 2026-05-14 DeepShell VCL 桌面壳骨架完成

### DESKTOP-2026-05-14: DeepShell 第一版 15 单元 + Demo 项目
- **完成日期**: 2026-05-14
- **目标**: 按 docs/70-78 号 DeepShell 设计契约落地可继承的 VCL 桌面壳骨架。下游 VCL 桌面工具从 `TDeepMainForm` 起步，不再每个软件重复搭工具栏、日志、设置、MRU、布局。
- **产出**:
  - 15 个核心单元（runtime 全部进 `DeepBaseVCL.dpk`）：
    - `VCL/DeepBase.VCL.DeepShell.Types.pas`：record / 枚举 / helpers，纯 RTL 依赖。
    - `VCL/DeepBase.VCL.DeepShell.Intf.pas`：所有接口契约 + capability/command 字符串常量。
    - `VCL/DeepBase.VCL.DeepShell.Events.pas`：UI-safe EventBus（主线程同步分发，后台线程 `TThread.Queue` 投递）。
    - `VCL/DeepBase.VCL.DeepShell.Services.pas`：`TShellServiceRegistry`。
    - `VCL/DeepBase.VCL.DeepShell.Context.pas`：`TShellContextManager`，按变更递增 Revision。
    - `VCL/DeepBase.VCL.DeepShell.Commands.pas`：`TShellCommandManager` + 流式 `ShellCommand(...)` builder + `class operator Implicit`。
    - `VCL/DeepBase.VCL.DeepShell.Recent.pas`：`TShellInMemoryRecentService`（按 ItemKey upsert，按时间排序）。
    - `VCL/DeepBase.VCL.DeepShell.Layout.pas`：内存 + Settings-store backed layout service（JSON 持久化）。
    - `VCL/DeepBase.VCL.DeepShell.Theme.pas`：默认 Theme service（仅状态跟踪，不直绑 Vcl.Themes）。
    - `VCL/DeepBase.VCL.DeepShell.Localization.pas`：默认 i18n service（locale → key → text 字典，TObjectDictionary 自释放）。
    - `VCL/DeepBase.VCL.DeepShell.Settings.pas`：`TShellInMemorySettingsStore` + `TDeepShellSettingsForm`（OK/Apply/Cancel/Restore Defaults，Provider 异常隔离）。
    - `VCL/DeepBase.VCL.DeepShell.Panels.pas`：`TShellAreaController` 三段折叠控制 + `TShellStatusManager`。
    - `VCL/DeepBase.VCL.DeepShell.ToolWindow.pas`：原生 TForm 实现的左右悬浮工具窗，不引入 Docking 框架。
    - `VCL/DeepBase.VCL.DeepShell.MainForm.pas`：`TDeepMainForm`，10 个虚生命周期方法 + 内置命令 + 主视图 dispatch。
    - `VCL/DeepBase.VCL.DeepShell.pas`：facade 单元，下游一行 uses 即可。
  - Demo 项目 `Examples/VCLDeepShellDemo/`：`VCLDeepShellDemo.dpr` + `Demo.MainForm.pas` + `Demo.Services.pas` + `Demo.Commands.pas` + `Demo.Providers.pas` + README。Demo 不依赖 DB1/doQry/LLM/WebView2/Governance，全用 fake provider/service。
  - `DeepBaseVCL.dpk` contains 列表追加全部 15 个新单元。
- **关键设计决策**:
  - Shell 核心不持有业务 `TObject`，统一用 `TShellObjectRef = record { Id, Kind, ProviderId, DisplayName }` 引用；下游 Provider 按 (ProviderId, Id) 找业务对象。
  - Command 以 record + `Handler: TProc` 存储；fluent builder 通过 `class operator Implicit` 直接转 record，下游可写 `RegisterCommand(ShellCommand('id', 'Caption').Category('File').OnExecute(...))`。
  - EventBus 线程模型：主线程 publish 同步分发；后台线程 publish 通过 `TThread.Queue` 投递到主线程，handler 异常被 catch 不影响其他订阅者。
  - 治理：Command 字段预留 `GateKey/RiskLevel/PurposeKey/RequiresEvidence`，`IShellCommandManager.SetGovernance` 在 MVP 默认接 `NullGovernanceService`，第二阶段切 OCGS adapter。
  - 渲染边界：`svkHtml/svkMarkdown` 必须由下游 provider 通过 `CreateViewControl` 自带控件渲染，Shell 核心不依赖 WebView2/CEF/Markdown 库。
  - 多实例：每个主窗体实例生成 `InstanceId(GUID)`，layout 写入带 `WriterInstanceId`，全局 layout 用 last-write-wins。
- **验证**:
  - 独立 `dcc32 _tmp_deepshell_compile.dpr` 编译：4452 行，0.39 秒，0 errors，0 warnings。
  - `DeepBaseVCL.dproj` Win64 编译：DeepShell 全部 15 单元干净通过。整包剩余 fail 来自仓库已有的 `Features\DeepBase.IntentClarification.SignalDetector.pas` (BUG-143)，与本工作无关。
  - `Examples/VCLDeepShellDemo/` 全部单元独立编译通过。
- **遗留**:
  - 整包 `DeepBaseVCL.dpk` 完整构建依赖 `IntentClarification` Phase 2 的修复，跟踪在 `IC-P0-2026-05-14`。
  - 第一版完成后五专家审阅发现的剩余 P1/P2 改进项见 `tasks.md` 的 `DESKTOP-P1-2026-05-14`。
- **归档**:
  - 第一版骨架与 6 个实现期 bug 修复（BUG-144 ~ BUG-149）和 5 个审阅 P0 修复（BUG-150 ~ BUG-154）已记录到 `bugfix.md`。

---

## 2026-05-14 IntentClarification 审阅与任务归档

### IC-AUDIT-2026-05-14: IntentClarification Phase 2 五专家审阅
- **完成日期**: 2026-05-14
- **内容摘要**:
  - 完成 `DeepBase.IntentClarification` 下游接入指南和 Phase 2 实码审阅。
  - 从 5 个视角完成只读审阅：接口契约/API、Engine/Session 并发、Provider/LLM 行为、IoC/配置/持久化/指标、测试/构建/包集成。
  - 确认当前模块主要风险不是单点逻辑缺陷，而是新单元未纳入包/主测试、公开 facade 仍为空、类型契约不一致、Registration 半截实现、Provider 状态跨会话和 Engine 并发写回等 P0 阻塞。
  - 已将后续修复整理为 `tasks.md` 的 `IC-P0-2026-05-14`。
  - 已将本轮发现缺陷登记到 `bugfix.md` 的 BUG-134 ~ BUG-143，状态均为待修复。
- **验证**:
  - `cmd /c compile_test.bat` 当前仍可通过，但只覆盖旧 facade，不覆盖 Phase 2 新单元；此结论已写入后续 QA 任务。

### ARCH-P0-001: deepBase 改名收尾与包编译门禁
- **完成日期**: 2026-05-13
- **内容摘要**:
  - 修复 `Scripts/build_packages_win64.ps1` 和 `Scripts/compile_packages_win64.ps1`，改为构建 `DeepBase*.dpk`。
  - 修复 `DeepBase*.dpk` 内部 package 名、requires 和 contains 的命名残留。
  - 发布门禁在 `VCL/` 源码目录缺失时排除 VCL 包和 VCL 必需示例，后续已恢复 VCL 源码目录并补齐 `DeepBase.VCL.*.dfm` 资源。
  - `Minimal`、`Runtime`、`All` Win64 package gate 已通过。
  - 修复 `Scripts/compile_packages_win64.ps1` 误报逻辑，改为基于退出码和真实 `Error:/Fatal:` 行判定。
  - 新增 `Scripts/check_rename_residue.ps1` 并接入包门禁，真实旧名残留命中即失败。
- **归档说明**:
  - 该项已从 `tasks.md` 的 P0 当前开发中移除；后续包门禁可信化继续由 `QA-P0-001` 和 `IC-P0-2026-05-14` 跟踪。

---

## 2026-05-07 Speech/ASR 基础模块归档 �?
### SPEECH-001: DeepInput 语音识别链路抽取�?DeepBase 基础模块 �?- **完成日期**: 2026-05-07
- **内容摘要**:
  - �?`D:\_Progs\02Business\DeepInput` 阅读并抽取语音识别核心链路：WaveIn 录音、RMS VAD、百度在�?ASR、录�?识别编排�?  - 新增 `Features/DeepBase.Speech.Types.pas`：统一音频格式、识别结果、错误状态、`ISpeechRecognizer`、`ISpeechAudioCapture`�?  - 新增 `Features/DeepBase.Speech.Audio.WinMM.pas`：Windows WaveIn 录音实现，输�?16kHz/16-bit/mono PCM�?  - 新增 `Features/DeepBase.Speech.VAD.pas`：基�?RMS 能量的静音自动停止检测�?  - 新增 `Features/DeepBase.Speech.ASR.Baidu.pas`：百度语�?REST API Provider，支�?token 缓存、错误映射和可注�?HTTP transport�?  - 新增 `Features/DeepBase.Speech.Service.pas`：封装录音、VAD、ASR Provider 的通用编排�?  - `DeepBaseFeatures.dpk` �?`Tests/DeepBaseTests.*` 已纳�?Speech 单元�?  - 下游文档已补�?`DeepBase.Speech.*` 接入说明；密钥继续要求走 `DeepBase.Security`�?- **边界**:
  - 未迁�?DeepInput 的虚拟键盘、浮动条、托盘、全局热键、文本注�?UI 状态机�?  - DeepInput 本地 Whisper 当前是旧兼容回退路径，未作为 DeepBase 基础 Provider 封装�?- **验证**:
  - `Scripts/run_tests.ps1 -Type Unit -Run Test.DeepBase.Speech`�?/5 passed�?  - `Scripts/build_packages_win64.ps1 -Profile Runtime`：通过�?
---

## 2026-05-05 架构整理与封板前优化归档 �?
### ARCH-019 / ARCH-039: Core �?Persistence 分层收敛 �?- **完成日期**: 2026-05-05
- **内容摘要**:
  - `Core/` 已移�?`FireDAC.*` / `TFD*` / `EFD*` 直接类型依赖，Core 运行包不再要�?FireDAC�?  - 引入 `DeepBase.Storage.Interfaces.pas`，统一 `IConfigStorage`、`IFormStateStorage`、`IMRUStorage`、`IHotkeyStorage`、`IThemeStorage`、`II18nStorage`、`ILogStorage`、`IManagerStorage`、`ILLMStorage`、`IORMStorage` 等抽象�?  - FireDAC 实现下沉�?`Persistence/DeepBase.Persistence.*.FireDAC.pas`，通过 initialization 自动注册工厂�?  - `Manager/Config/FormState/MRU/Hotkeys/Theme/i18n/Security/License/Authorization/Exception/Diagnose/Logging/LLM/ORM/TestHelper` 已完成主要存储注入切片�?  - `Scripts/run_tests.ps1` 增加模块化测试入口：`-Module`、`-FromUnit`、`-FromGitChanged`�?- **验证**:
  - `Scripts/run_tests.ps1 -Type Unit -Platform Win64 -CI`
  - `Scripts/run_tests.ps1 -Type All -Platform Win64 -CI`
  - `Scripts/build_packages_win64.ps1 -Profile Runtime`

### ARCH-027 / ARCH-044: Core 目录和包边界整理 �?- **完成日期**: 2026-05-05
- **内容摘要**:
  - `Core` 中与 UI、Features、Persistence 强相关的实现完成迁移或边界收敛�?  - `DeepBaseCore.dpk`、`DeepBaseServices.dpk`、`DeepBasePersistence.dpk`、`DeepBaseFeatures.dpk`、`DeepBaseVCL.dpk`、`DeepBaseFMX.dpk` 已按当前分层重新对齐�?  - `Theme/Exception/Hotkeys/Plugin` 等模块去�?Core �?VCL/FMX 的直接绑定，由平台包提供适配器�?  - `Profile All` 包门禁已覆盖 VCL/FMX 包，并检查源目录 `.dcu` 泄漏�?
### FEATURE-001: 统一用户/订单/支付/权益 Commerce MVP �?- **完成日期**: 2026-05-05
- **内容摘要**:
  - 新增 `Features/DeepBase.Commerce.Types.pas`：统一用户、身份、商品、订单、支付、权益数据结构�?  - 新增 `Features/DeepBase.Commerce.Storage.pas`：定�?`ICommerceStorage`，提�?`TInMemoryCommerceStorage` 用于开发和测试�?  - 新增 `Features/DeepBase.Commerce.Service.pas`：实�?`EnsureUserForIdentity`、`CreateOrder`、`BeginPayment`、`ConfirmPayment`、`HasEntitlement`、`ConsumeEntitlement` 主流程�?  - 新增 `ICommercePaymentGateway`，为微信支付、CloudBase、自建后端等真实网关预留适配点�?  - 新增 `Tests/Test.DeepBase.Commerce.pas`，覆盖用户绑定、订单、支付意图、回调确认、权益幂等发放、金额不匹配拒绝和消费型权益扣减�?- **验证**:
  - `Scripts/run_tests.ps1 -Type Unit -Platform Win64 -CI -Run "Test.DeepBase.Commerce"`�?/7 passed�?  - `Scripts/build_packages_win64.ps1 -Profile All`：通过�?
### COMMERCE-002A-D: Commerce 后端契约�?HTTP 后端适配�?�?- **完成日期**: 2026-05-05
- **内容摘要**:
  - 新增 `docs/Commerce-Backend-Adapter-Spec.md`，固化后端数据表、HTTP API、幂等、安全边界和实施顺序�?  - 新增 `Features/DeepBase.Commerce.Backend.Contract.pas`，统一后端路由�?snake_case JSON 字段常量�?  - 新增 `Features/DeepBase.Commerce.Backend.Http.pas`，提�?`TCommerceHttpStorage` 作为生产 `ICommerceStorage` HTTP 后端适配器�?  - `TCommerceHttpStorage` 支持 `BaseUrl`、Bearer token、API key、超时配置，并通过 `ICommerceBackendHttpTransport` 支持单元测试注入�?  - 新增 `TCommerceHttpPaymentGateway`，作为生�?`ICommercePaymentGateway` 后端代理适配器，统一调用 `POST /commerce/payments/intents` 并使�?`Idempotency-Key` 防重试冲突�?  - 更新下游集成文档，生产路线从“自行实�?ICommerceStorage”收敛为“优先接入统一后端 HTTP API”�?- **验证**:
  - `Scripts/run_tests.ps1 -Type Unit -Platform Win64 -CI -Run "Test.DeepBase.Commerce"`�?3/13 passed�?
### ARCH-029 / ARCH-030 / CLEANUP-005 / CLEANUP-006: 旧商业化路线与文档清�?�?- **完成日期**: 2026-05-05
- **内容摘要**:
  - 删除未使用的 AiPEX/AipexBase、旧后端认证/计费客户端、旧认证/计费 UI 组件和演示工程�?  - 删除过期 API/集成文档，不再保留误�?AI 的历史入口�?  - `ThirdParty/Payment` 明确定位为渠�?SDK 能力；统一用户、订单、支付、权益流程由 `Features/DeepBase.Commerce.*` 承接�?  - `docs/integrations` 已扁平化�?`docs/`，空目录删除，相关链接修正�?  - 新增 `docs/DeepBase-Downstream-Integration.md` 作为下游最干净的集成入口�?
### LLM-001 ~ LLM-004: Delphi LLM 客户端、安全存储与聊天组件 �?- **完成日期**: 2025-12-14
- **内容摘要**:
  - `Core/DeepBase.LLM.BillingClient.pas` 提供轻量 AI 质价管家客户端，支持流式/非流式、重试、取消、异步调用和对话历史�?  - `Core/DeepBase.Security.DPAPI.pas` 提供 DPAPI、Credential Manager �?`TSecureString`�?  - `VCL/DeepBase.VCL.LLMChatFrame.pas`、`FMX/DeepBase.FMX.LLMChatFrame.pas` 提供可复用聊�?Frame�?  - `Tests/Test.DeepBase.LLM.BillingClient.pas` �?`Tests/Test.DeepBase.Security.DPAPI.pas` 覆盖核心行为�?
### BUG-098: FormState 多显示器坐标恢复修复 �?- **完成日期**: 2026-05-05
- **内容摘要**:
  - `Core/DeepBase.FormState.pas` 恢复窗口时按当前显示器工作区夹回坐标，避免旧多屏坐标导致窗口不可见�?  - `VCL/DeepBase.VCL.FormStateHelper.pas` 保存路径补齐 `GetWindowPlacement` 工作区坐标到屏幕坐标转换�?  - 详细修复记录�?`bugfix.md`�?- **验证**:
  - `Scripts/run_tests.ps1 -Type Unit -Platform Win64 -CI -Run "Test.DeepBase.FormState"`�?3/13 passed�?  - `Scripts/build_packages_win64.ps1 -Profile All`：通过�?
---

## 2026-05-02 持续优化迭代 �?
### MAINT-002-A: 单元测试稳定性清零（Win64 基线）✅
- **完成日期**: 2026-05-02
- **输出�?*:
  - �?`Scripts/run_tests.ps1` 新增 `-Platform` 参数（`Win32|Win64`），默认改为 `Win64`
  - �?Win64 单元测试全绿：`Tests Found 824 / Ignored 4 / Passed 820 / Failed 0 / Errored 0 / Leaked 0`
  - �?修复 Win64 �?`Test.DeepBase.Resilience` 泛型断言类型推断问题（显�?`Assert.AreEqual<Integer>`�?
### MAINT-002-B: FormState 坐标持久化修正（顶部任务栏场景）�?- **完成日期**: 2026-05-02
- **输出�?*:
  - �?`Core/DeepBase.FormState.pas`：`GetWindowPlacement.rcNormalPosition` 工作区坐标转换为屏幕坐标后再持久�?  - �?`Tests/Test.DeepBase.FormState.pas`：测试窗体默认放置到左下工作区，降低测试过程误击风险

### MAINT-002-C: Resilience 执行链闭包泄漏修�?�?- **完成日期**: 2026-05-02
- **输出�?*:
  - �?`Core/DeepBase.Resilience.pas`：重�?`TResiliencePolicy.Execute` / `Execute<T>` 闭包链，显式释放捕获引用
  - �?清除 FastMM 末尾 `TResiliencePolicy.Execute` 相关小块泄漏告警

### MAINT-002-D: 异常语义与测试断言对齐 �?- **完成日期**: 2026-05-02
- **输出�?*:
  - �?`Tests/Test.DeepBase.Protection.pas`：文件不存在断言改为 `EFileNotFoundExceptionEx`
  - �?`Tests/Test.DeepBase.Resilience.pas`：断路器打开断言改为 `ECircuitBreakerException`

### MAINT-002-E: 构建产物清理 �?- **完成日期**: 2026-05-02
- **输出�?*:
  - �?已清理仓库内 `.dcu` 文件 65 个（满足“源库不保留 dcu”要求）

### MAINT-002-F: Win64 集成测试链路打�?�?- **完成日期**: 2026-05-02
- **输出�?*:
  - �?`Tools/WebService/DeepBase.WebAPI.Core.pas`：TLS 版本枚举兼容 Indy 版本差异（`sslvTLSv1_3` 可选）
  - �?`Core/DeepBase.Net.pas`：修复静态方法调用限定，补齐 `TIPUtils.IsLinkLocalIP`
  - �?`Core/DeepBase.Net.pas`：新增本�?内网 URL 安全开关（环境变量�?  - �?`Scripts/run_tests.ps1`：集成测试自动准备位宽匹�?`sqlite3.dll` 并启�?localhost 白名�?  - �?Win64 Integration 全绿�?/9 通过

### MAINT-002-G: 全量 Win64 门禁通过 �?- **完成日期**: 2026-05-02
- **输出�?*:
  - �?`.\Scripts\run_tests.ps1 -Type All -CI` 执行通过（Unit + Integration�?  - �?最终清�?`.dcu` 与临时集成依赖文件，仓库保持可提交状�?
### MAINT-002-H: DB.Factory 双共享模式补齐（SQLite / PostgreSQL）✅
- **完成日期**: 2026-05-02
- **输出�?*:
  - �?`Persistence/DeepBase.DB.Factory.pas`：`LoadSharedProfile` 支持 `DB3.Type=SQLite`（保�?`PostgreSQL/PG` 兼容�?  - �?SQLite 共享库路径支持相�?`RootPath` 解析（`DB3.Database`，兼�?`DB3.Path`�?  - �?支持 `DB3.SQLiteLockingMode/SQLiteSynchronous/SQLiteJournalMode/SQLiteOpenMode/ExtraParams` 配置透传
  - �?新增单测 `Test_CreateSharedUnopenedConnection_FromLocalSettings_SQLite`
  - �?更新当时的快速集成文档（补充 `DB3.Type=SQLite` 配置键；当前入口�?`docs/DeepBase-Downstream-Integration.md`�?  - �?更新文档索引 `docs/00.00.DeepBase-文档索引-v1.0.md`（快速入口优先指向新集成指南�?
---

## Phase 0: 最小核�?�?(完成)

### P0-001: 创建项目结构和包配置 �?- **完成日期**: 2025-11-26
- **负责�?*: 鲁班
- **输出�?*:
  - �?项目目录结构（Core/VCL/FMX/Tests/Tools/ThirdParty�?  - �?`.gitignore` �?`.gitmodules` 配置
  - �?`DeepBaseCore.dpk` 运行时包
  - �?`dclDeepBaseCore.dpk` 设计时包
  - �?`README.md` 项目说明
- **备注**: 包可�?Delphi IDE 中成功编�?
---

### P0-002: 创建 Tier 0 数据�?Schema 脚本 �?- **完成日期**: 2025-11-26
- **负责�?*: 鲁班
- **输出�?*:
  - �?`sql/tier0_init.sql`: 包含 SchemaInfo, ProjectInfo, Settings, FormStates, Languages, I18nTexts �?  - �?预置数据（默认语言、默�?Schema 版本�?  - �?`sql/README.md`: Schema 设计说明
- **备注**: 脚本可在�?SQLite 数据库上成功执行

---

### P0-003: 实现 TDeepBaseManager 核心框架 �?- **完成日期**: 2025-11-26
- **负责�?*: 李冰
- **输出�?*:
  - �?`Core/DeepBase.Manager.pas`
  - �?`Core/DeepBase.Types.pas`
  - �?`Tests/Test.DeepBase.Manager.pas`
- **功能**:
  - �?Initialize / InitializeEx / InitializeWithDB 方法
  - �?Finalize 方法
  - �?RootPath 检测逻辑（EXE 目录 -> APPDATA 回退�?  - �?FInitErrorCode 错误码机�?  - �?全局单例 DeepBase()
  - �?HealthCheck 方法
  - �?单元测试（代码覆盖率 > 85%�?- **备注**: Manager 使用 TMonitor 确保线程安全

---

### P0-004: 实现 Config 模块 �?- **完成日期**: 2025-11-26
- **负责�?*: 李冰
- **输出�?*:
  - �?`Core/DeepBase.Config.pas`
  - �?`Tests/Test.DeepBase.Config.pas`
- **功能**:
  - �?GetConfig / SetConfig (String)
  - �?GetConfigInt / SetConfigInt
  - �?GetConfigBool / SetConfigBool
  - �?GetConfigFloat / SetConfigFloat
  - �?OnConfigChanged 事件通知
  - �?内存缓存机制�? 1ms 读取�?  - �?线程安全（TMonitor�?- **性能**: 缓存命中 < 1ms，未命中 < 10ms

---

### P0-005: 实现 i18n 模块（基础�?�?- **完成日期**: 2025-11-26
- **负责�?*: 李冰
- **输出�?*:
  - �?`Core/DeepBase.i18n.pas`
  - �?`Tests/Test.DeepBase.i18n.pas`
- **功能**:
  - �?T() 函数
  - �?TFmt() 格式化翻�?  - �?CurrentLanguage 属�?  - �?OnLanguageChanged 事件
  - �?GetAvailableLanguages 方法
  - �?LRU 翻译缓存（容�?10000�?  - �?线程安全（TMonitor�?- **性能**: 缓存命中 < 0.5ms

---

### P0-006: 实现 FormState 模块 �?- **完成日期**: 2025-11-26
- **负责�?*: 李冰
- **输出�?*:
  - �?`Core/DeepBase.FormState.pas`
  - �?`Tests/Test.DeepBase.FormState.pas`
- **功能**:
  - �?SaveFormState(AForm: TForm)
  - �?RestoreFormState(AForm: TForm)
  - �?多显示器边界检�?  - �?WindowState 支持 (Normal/Minimized/Maximized)
  - �?Extra 字段（JSON 格式�?- **备注**: 框架无关的实现，VCL �?FMX 都可�?
---

### P0-007: 创建 Phase 0 示例工程 �?- **完成日期**: 2025-11-26
- **负责�?*: 鲁班
- **输出�?*:
  - �?`Examples/Phase0Demo/Phase0Demo.dproj`
  - �?`Examples/Phase0Demo/MainForm.pas`
  - �?`Examples/Phase0Demo/README.md`
  - �?`Examples/Phase0Demo/config.db`
- **演示内容**:
  - �?DeepBase 初始化和 Finalize
  - �?读写配置（带界面展示�?  - �?T() 函数进行文本翻译
  - �?语言切换功能
  - �?窗体状态自动保�?恢复
  - �?错误处理演示

---

### P0-008: Phase 0 集成测试和文�?�?- **完成日期**: 2025-11-27
- **负责�?*: 李冰
- **输出�?*:
  - �?�?Phase0 集成测试入口
  - �?Phase0 API 参考文档（后续并入 `docs/05.01.DeepBase-4AI-API参�?v1.0.md`�?  - �?快速入门文档（当前入口�?`ARCH-QUICKSTART.md`�?- **测试覆盖**:
  - �?所有单元测试通过
  - �?集成测试通过
  - �?代码覆盖�?> 85%

---

## Phase 1: 推荐功能 �?(完成)

### P1-001: 创建 Tier 1 数据�?Schema 脚本 �?- **完成日期**: 2025-11-26
- **输出�?*: `sql/tier1_init.sql` (Logs, MRU, Hotkeys, Themes)

---

### P1-002: 实现 Logging 模块 �?- **完成日期**: 2025-11-26
- **负责�?*: 李冰
- **功能**:
  - �?Log(Msg, Level, Source) 方法
  - �?LogDebug/LogInfo/LogWarn/LogError/LogFmt 快捷方法
  - �?StorageMode 配置 (Database/File/Both)
  - �?ClearOldLogs(DaysToKeep) 方法
  - �?后台写入线程，不丢失日志
- **性能**: 10000 条日志写�?< 5 �?
---

### P1-003: 实现 MRU 模块 �?- **完成日期**: 2025-11-26
- **负责�?*: 李冰
- **功能**:
  - �?AddMRU(Category, ItemKey, DisplayName)
  - �?GetMRUList(Category, MaxItems)
  - �?GetMRUItems(Category, MaxItems)
  - �?ClearMRU(Category)
  - �?RemoveInvalidMRU 自动清理

---

### P1-004: 实现 Hotkeys 模块 �?- **完成日期**: 2025-11-26
- **负责�?*: 李冰
- **功能**:
  - �?GetHotkey(ActionName): TShortCut
  - �?SetHotkey(ActionName, Shortcut)
  - �?RegisterDefaultHotkeys(Defaults)
  - �?ResetHotkey / ResetAllHotkeys
  - �?CheckHotkeyConflict(Shortcut)

---

### P1-005: 实现 Theme 模块 �?- **完成日期**: 2025-11-26
- **负责�?*: 李冰
- **功能**:
  - �?ApplyTheme(ThemeName)
  - �?GetAvailableThemes
  - �?IsDarkTheme: Boolean
  - �?OnThemeChanged 事件

---

### P1-006: 实现 VCL 基础控件 �?- **完成日期**: 2025-11-26
- **负责�?*: 鲁班
- **控件列表**:
  - �?TConfigEdit, TConfigCheckBox, TConfigSpinEdit (自动保存配置)
  - �?TI18nLabel, TI18nButton (自动翻译)
  - �?TMRUPopupMenu, TMRUComboBox (最近使用列�?
  - �?TLanguageComboBox, TThemeComboBox (快速切�?
- **备注**: 所有控件已注册�?Delphi 组件面板

---

### P1-007: 实现 TFormStateHelper 组件 �?- **完成日期**: 2025-11-26
- **负责�?*: 鲁班
- **功能**:
  - �?AutoSave / AutoRestore 属�?  - �?OnSaveExtra / OnRestoreExtra 事件
  - �?自动挂钩 TForm.OnCreate �?OnDestroy

---

### P1-008: 实现 TLogListView 组件 �?- **完成日期**: 2025-11-26
- **负责�?*: 鲁班
- **功能**:
  - �?OwnerData 模式
  - �?�?LogLevel 整行变色
  - �?右键菜单（清空、复制、自动滚动）
  - �?MaxItems 环形缓冲�?- **性能**: 10000 条日志渲染流�?
---

### P1-009: 创建 DeepBase Studio - 基础框架 �?- **完成日期**: 2025-11-27
- **负责�?*: 鲁班
- **输出�?*: `Tools/Studio/Studio.dproj`
- **功能**:
  - �?主界面框架（左侧导航�?+ 右侧工作区）
  - �?项目管理功能（打开/切换 config.db�?  - �?配置编辑器（Settings 表的 Key-Value 编辑�?  - �?日志查看器界�?
---

## Phase T: DeepBaseTray 工作�?�?(完成)

### PT-001: 创建 DeepBaseTray 项目结构 �?- **完成日期**: 2025-11-27
- **输出�?*: `Tools/Tray/DeepBaseTray.dpr`
- **功能**:
  - �?悬浮窗口基础框架
  - �?系统托盘图标
  - �?窗口拖动和位置记�?  - �?半透明效果
  - �?缩小到托�?恢复显示

---

### PT-002: 创建 studio.db 全局数据�?�?- **完成日期**: 2025-11-27
- **输出�?*: `sql/studio_init.sql`
- **功能**:
  - �?DevLogs 表（开发日志）
  - �?QuickCommands 表（常用命令�?  - �?AutomationScripts 表（自动化脚本）
  - �?TraySettings 表（配置项）

---

### PT-003: 实现开发日志功�?�?- **完成日期**: 2025-11-27
- **输出�?*: `Tools/Tray/Frames/Tray.DevLogFrame.pas`
- **功能**:
  - �?日志快速录入界�?  - �?项目名下拉框
  - �?标签选择（Bug修复/新功�?重构/文档/测试�?  - �?日志保存到数据库
  - �?今日日志列表显示

---

### PT-004: 实现命令面板功能 �?- **完成日期**: 2025-11-27
- **输出�?*: `Tools/Tray/Frames/Tray.CommandFrame.pas`
- **功能**:
  - �?命令列表显示（按频次排序�?  - �?单击复制命令
  - �?双击执行命令
  - �?命令 CRUD 操作
  - �?全局命令和项目命令分�?  - �?危险命令确认和黑名单

---

### PT-005: 实现快速启动功�?�?- **完成日期**: 2025-11-27
- **输出�?*: `Tools/Tray/Tray.Launcher.pas`
- **功能**:
  - �?启动 Studio 功能
  - �?在当前目录打开 CMD
  - �?在当前目录打开 PowerShell
  - �?管理员模式启�?  - �?在当前目录打开资源管理�?
---

### PT-006: 实现多步操作自动化（基础�?�?- **完成日期**: 2025-11-27
- **输出�?*: `Tools/Tray/Automation/Tray.Automation.pas`
- **功能**:
  - �?脚本 JSON 解析�?  - �?基础 Action: wait, runCommand
  - �?窗口 Action: findWindow, activateWindow
  - �?进程 Action: killProcess

---

### PT-007: 实现多步操作自动化（高级�?�?- **完成日期**: 2025-11-27
- **输出�?*: `Tools/Tray/Automation/Tray.KeyboardMouse.pas`
- **功能**:
  - �?键盘 Action: sendKeys, sendText
  - �?剪贴�?Action: paste
  - �?鼠标 Action: mouseClick
  - �?等待 Action: waitWindow
  - �?条件判断: if

---

### PT-008: 实现配置和日志搜�?�?- **完成日期**: 2025-11-27
- **输出�?*: 
  - �?`Tools/Tray/Forms/Tray.SettingsForm.pas`
  - �?`Tools/Tray/Forms/Tray.LogSearchForm.pas`
- **功能**:
  - �?配置界面（Studio路径、透明度、置顶等�?  - �?日志搜索筛选界�?  - �?日志导出（Markdown/JSON�?
---

## Phase 2: 扩展功能 �?(完成)

### P2-001: 创建 Tier 2 数据�?Schema 脚本 �?- **完成日期**: 2025-11-27
- **输出�?*: `sql/tier2_init.sql`

---

### P2-002: 实现 LLM 模块 �?- **完成日期**: 2025-11-27
- **负责�?*: 李冰
- **功能**:
  - �?LLMChat(Prompt, out Response)
  - �?LLMChatAsync(Prompt, OnComplete)
  - �?TestLLMConnection()
  - �?支持多个 Provider (OpenAI, Anthropic)
  - �?调用记录写入数据�?  - �?成本估算

---

### P2-003: 实现 TLLMConfigPanel 组件 �?- **完成日期**: 2025-11-27
- **负责�?*: 鲁班
- **功能**:
  - �?Provider/API Key/Model 配置面板
  - �?LLMCalls 历史记录 Grid
  - �?测试连接按钮
  - �?保存/重置按钮

---

### P2-004: 实现 TWaitForm 组件 �?- **完成日期**: 2025-11-27
- **负责�?*: 鲁班
- **功能**:
  - �?Show(Message, RandomAnimation)
  - �?�?AnimationAssets 随机选择 SVG 动画
  - �?UpdateMessage / UpdateProgress
  - �?SwitchToBackground（切换到通知栏模式）

---

### P2-005: 实现 TNotificationBar 组件 �?- **完成日期**: 2025-11-27
- **负责�?*: 鲁班
- **功能**:
  - �?底部通知栏布局
  - �?进度条和旋转动画图标
  - �?取消和关闭按�?  - �?任务完成/失败自动更新状�?
---

### P2-006: 实现 Exception 模块 �?- **完成日期**: 2025-11-27
- **负责�?*: 李冰
- **功能**:
  - �?HandleException(Sender, E)
  - �?ReportException(E, UserAction)
  - �?异常信息写入 ExceptionReports �?  - �?捕获堆栈跟踪信息

---

### P2-007: 实现 Studio i18n 翻译管理 �?- **完成日期**: 2025-11-27
- **负责�?*: 鲁班
- **功能**:
  - �?源码扫描器（采集 T() �?TextKey�?  - �?翻译网格编辑界面
  - �?LLM 批量翻译功能
  - �?翻译进度统计
  - �?导入/导出（JSON/PO/Excel�?
---

### P2-008: 实现 GUI 测试辅助模块 �?- **完成日期**: 2025-11-27
- **负责�?*: 李冰
- **功能**:
  - �?CaptureFormState(AForm)
  - �?SaveSnapshot(TestName, AForm)
  - �?VerifySnapshot(TestName, AForm)
  - �?SimulateClick/SimulateInput/SimulateSelect

---

### P2-009: 实现 FMX 控件�?�?- **完成日期**: 2025-11-27
- **负责�?*: 鲁班
- **输出�?*: `FMX/DeepBase.FMX.Controls.pas`
- **功能**: FMX 控件接口�?VCL 保持一�?
---

## Phase 3: 高级功能 �?(完成)

### P3-001: 实现 AutoUpdate 模块 �?- **完成日期**: 2025-11-27
- **负责�?*: 李冰
- **功能**:
  - �?CheckForUpdate(out UpdateInfo)
  - �?DownloadUpdate(UpdateInfo, OnProgress)
  - �?SHA256 签名验证
  - �?更新渠道支持 (Stable/Beta/Dev)

---

### P3-002: 实现 TAutoUpdater 组件 �?- **完成日期**: 2025-11-27
- **负责�?*: 鲁班

---

### P3-003: 实现 TUpdateDialog 组件 �?- **完成日期**: 2025-11-27
- **负责�?*: 鲁班
- **功能**: 下载进度正确显示

---

### P3-004: 实现 TDBInitWizard 组件 �?- **完成日期**: 2025-11-27
- **负责�?*: 鲁班
- **功能**:
  - �?向导步骤界面
  - �?数据库路径选择
  - �?初始化确认和执行

---

### P3-005: 实现 RemoteConfig 模块 �?- **完成日期**: 2025-11-27
- **负责�?*: 李冰
- **功能**:
  - �?GetRemoteFlag(Key, Default)
  - �?GetRemoteConfig(Key, Default)
  - �?RefreshRemoteConfig()
  - �?本地缓存机制

---

### P3-006: 实现 DeepBase CLI 工具 �?- **完成日期**: 2025-11-27
- **负责�?*: 鲁班
- **输出�?*: `Tools/CLI/DeepBase.exe`
- **命令**:
  - �?`DeepBase db init/upgrade/backup/check`
  - �?`DeepBase i18n scan/sync/translate/export/import`
  - �?`DeepBase config get/set/export/import`

---

### P3-007: 创建云端服务示例 �?- **完成日期**: 2025-11-27
- **输出�?*: 
  - �?`CloudServices/README.md`
  - �?`CloudServices/version.json`
  - �?`CloudServices/remote-config.json`

---

## Phase 4: 完善与文�?�?(完成)

### P4-001: 实现 License 模块 �?- **完成日期**: 2025-11-27
- **负责�?*: 李冰
- **功能**:
  - �?License Key 验证（本�?+ 在线�?  - �?设备指纹生成
  - �?许可证类型检�?(Trial/Standard/Pro)

---

### P4-002: 实现 TLicenseStatusPanel 组件 �?- **完成日期**: 2025-11-27
- **负责�?*: 鲁班
- **功能**: 正确显示 License 状态和额度

---

### P4-003: 实现 TLicenseAuthDialog 组件 �?- **完成日期**: 2025-11-27
- **负责�?*: 鲁班
- **功能**: 激活流程正常工�?
---

### P4-004: 实现 TFeedbackDialog 组件 �?- **完成日期**: 2025-11-27
- **负责�?*: 鲁班
- **功能**:
  - �?反馈表单（类型、内容、联系方式）
  - �?附带日志选项
  - �?异步提交到服务器

---

### P4-005: 实现 Studio License 管理模块 �?- **完成日期**: 2025-11-27
- **负责�?*: 鲁班
- **功能**:
  - �?License Key 生成�?  - �?已发放密钥管�?
---

### P4-006: 撰写完整 API 文档 �?- **完成日期**: 2025-11-27
- **输出�?*:
  - �?`docs/05.01.DeepBase-4AI-API参�?v1.0.md`
  - �?`ARCH-QUICKSTART.md`
  - �?`docs/03.01.DeepBase-4AI-FAQ与错误速查-v1.0.md`

---

### P4-007: 创建综合示例工程 �?- **完成日期**: 2025-11-27
- **输出�?*: `Examples/FullDemo/FullDemo.dproj`
- **功能**: 演示所有框架功�?
---

## Phase 5: 代码审查优化 �?(完成)

> 基于 2025-11-28 代码审查的改进任�?
### P5-001: Schema SQL 外部�?�?- **完成日期**: 2025-11-28
- **输出�?*: `Core/DeepBase.Schema.pas` (新建�?30+ �?
- **功能**:
  - �?SQL 定义分为 Tier0/Tier1/Tier2 常量
  - �?`GetTier0SchemaSQL/GetTier1SchemaSQL/GetTier2SchemaSQL/GetFullSchemaSQL` 函数
  - �?Manager.CreateSchema 改用 GetFullSchemaSQL()
  - �?添加 `Queries` 表支�?
---

### P5-002: DoQry 查询表加载与缓存 �?- **完成日期**: 2025-11-28
- **负责�?*: Claude
- **输出�?*: `Persistence/DeepBase.DB.DoQry.pas` 更新
- **功能**:
  - �?实现 `LoadQuerySQL(ProcName, Ctx)` 带缓�?  - �?实现 `IsDirectSQL()` 判断 SQL 关键�?  - �?实现 `UniDbClearQueryCache()` 清除缓存
  - �?所�?UniDb* 函数更新使用 LoadQuerySQL
  - �?向后兼容：直�?SQL 仍然支持

---

### P5-003: Logger 初始化改�?�?- **完成日期**: 2025-11-28
- **负责�?*: Claude
- **输出�?*: `Core/DeepBase.Logging.pas` 更新
- **功能**:
  - �?添加 `SetGlobalLogger(ALogger)` 过程
  - �?添加 `IsLoggerInitialized()` 检查函�?  - �?Logger() 未初始化时返回文件日志模�?  - �?Manager.InitializeModules 调用 SetGlobalLogger

---

### P5-004: 核心模块接口抽象 �?- **完成日期**: 2025-11-28
- **负责�?*: Claude
- **输出�?*: `Core/DeepBase.Interfaces.pas` (新建�?92 �?
- **功能**:
  - �?`IDeepBaseConfig` - 配置管理接口
  - �?`IDeepBaseLogger` - 日志接口
  - �?`IDeepBaseI18n` - 国际化接�?  - �?`IDeepBaseMRU` - MRU 接口
  - �?`IDeepBaseManager` - 管理器接�?- **备注**: 各模块可逐步实现这些接口，提高可测试�?
---

### P5-005: 运行时日志级别配�?�?- **完成日期**: 2025-11-28
- **负责�?*: Claude
- **输出�?*: `Core/DeepBase.Consts.pas`, `Core/DeepBase.Manager.pas` 更新
- **功能**:
  - �?添加 `SConfigKeyLogLevel` �?`SConfigKeyLogStorageMode` 常量
  - �?InitializeModules �?Settings 读取并设置日志级�?  - �?HandleConfigChanged 响应日志级别变更（热更新�?
---

### P5-006: 版本兼容性检�?�?- **完成日期**: 2025-11-28
- **负责�?*: Claude
- **输出�?*: `Core/DeepBase.Schema.pas`, `Core/DeepBase.Manager.pas` 更新
- **功能**:
  - �?Schema 添加 MIN/MAX_COMPATIBLE_SCHEMA_VERSION
  - �?添加 ecSchemaVersionMismatch 错误�?  - �?实现 ValidateSchemaVersion 方法
  - �?ValidateSchema 中调用版本检�?  - �?版本过旧/过新时给出明确错误提�?
---

### P5-007: i18n �?Manager 解�?�?- **完成日期**: 2025-11-28
- **负责�?*: Claude
- **输出�?*: `Core/DeepBase.i18n.pas`, `Core/DeepBase.Manager.pas` 更新
- **功能**:
  - �?移除 i18n �?Manager 的直接引�?  - �?添加 `SetGlobalTranslateCallback` 回调模式
  - �?添加 `IsTranslateCallbackSet` 检查函�?  - �?Manager.InitializeModules 设置翻译回调
  - �?T() 函数未初始化时返回原�?
---

### P5-008: 配置加密安全文档 �?- **完成日期**: 2025-11-28
- **负责�?*: Claude
- **输出�?*: `Core/DeepBase.Config.pas` 更新
- **功能**:
  - �?添加详细的安全警告注释（25行）
  - �?明确说明 XOR 仅提供混淆而非加密
  - �?列出适用/不适用场景
  - �?提供更安全方案的建议（DPAPI/AES/Keychain�?
---

### P5-009: 常量命名规范文档 �?- **完成日期**: 2025-11-28
- **负责�?*: Claude
- **输出�?*: `Core/DeepBase.Consts.pas` 更新
- **功能**:
  - �?统一使用 `S` 前缀风格
  - �?添加详细的命名规范文档注�?  - �?记录各类前缀: SConfigKey*, SDefault*, STable*, etc.

---

## 统计摘要

| 阶段 | 总任务数 | 核心模块 | UI 控件 | 工具 | 状�?|
|------|---------|---------|---------|------|------|
| Phase 0 | 8 | 5 | 0 | 3 | �?完成 |
| Phase 1 | 9 | 4 | 4 | 1 | �?完成 |
| Phase 2 | 9 | 3 | 4 | 2 | �?完成 |
| Phase 3 | 7 | 2 | 3 | 2 | �?完成 |
| Phase T | 8 | 0 | 0 | 8 | �?完成 |
| Phase 4 | 7 | 1 | 3 | 3 | �?完成 |
| Phase 5 | 9 | 9 | 0 | 0 | �?完成 |
| **总计** | **57** | **24** | **14** | **19** | �?100% |

---

## 主要里程�?
- �?**2025-11-26**: Phase 0 完成，框架基础稳定
- �?**2025-11-26**: Phase 1 完成，VCL 控件库就�?- �?**2025-11-27**: Phase T 完成，开发工具套件完�?- �?**2025-11-27**: Phase 2 完成，LLM 和高�?UI 功能
- �?**2025-11-27**: Phase 3 完成，AutoUpdate �?CLI 工具
- �?**2025-11-27**: Phase 4 完成，License 和文�?- �?**2025-11-28**: Phase 5 完成，代码审查优化（9 项改进）

## 2025-12-01 代码审查与优�?
### 安全性修�?- CRYPTO-001: 实现真正�?AES-256-CBC 加密（使�?Windows BCrypt API�?  - 文件: `DeepBase.Crypto.pas`
- CRYPTO-002: 使用 BCryptGenRandom 替换不安全的 Random() 调用
  - 文件: `DeepBase.Crypto.pas`
- CONFIG-001: 添加编译器警告到 XOR 加密方法
  - 文件: `DeepBase.Config.pas`

### 内存管理优化
- ORM-001: TQueryBuilder 实现 IQueryBuilder 接口（自动引用计数）
  - 文件: `DeepBase.ORM.pas`
- CACHE-001: 添加 FreeValueIfOwned 安全释放泛型对象
  - 文件: `DeepBase.Cache.pas`

### IoC 容器修复
- IOC-001: RegisterSingleton 接口实例处理逻辑
  - 文件: `DeepBase.IoC.pas`

### 代码重构
- UTIL-001: CompareVersions 提取�?`DeepBase.Types.pas`
- INTERFACE-001: `TDeepBaseConfig`/`TDeepBaseI18n` 实现接口

### 国际化增�?- I18N-001: 集成 CLDR 复数规则（`DeepBase.i18n.Plural.pas`�?
### 日志系统优化
- LOG-001: 日志写入线程重构为批量处理模式（`DeepBase.Logging.pas`�?
### 新增功能
- E-001: IoC 循环依赖检测（异常 `ECircularDependencyException`�?- E-002: ORM `DEFAULT` 生成（`CreateTableSQL` 支持�?- E-003: Configuration 加密配置源（`TEncryptedConfigurationSource`�?- E-004: Logging 结构�?JSON 日志（`.jsonl`�?
### doQry 模块增强 (2025-12-01)
- DOQRY-001: CopyQueryToClientDataSet 扩展（Field.Assign + 性能优化�?- DOQRY-002: 查询缓存 TTL 策略（UniDbInvalidateQuery/UniDbSetCacheTTL/UniDbGetCacheStats�?- DOQRY-003: doQry 使用指南文档（`docs/05.03.DeepBase-4AI-DoQry指南-v1.0.md`�?- DOQRY-004: 日志输出结构�?JSON 格式
- DOQRY-005: 预编译语句池（UniDbSetPreparedStatementPooling/UniDbClearPreparedStatements/UniDbGetPreparedStats�?- DOQRY-006: 错误码规范化�?7 �?DOQRY_ERR_* 常量 + InferErrorCode�?
---

## OPT-MAINT-006: 日志聚合和分析系�?�?(2025-12-02)

> 功能优化任务: 集中式日志聚合和分析系统

### 新增模块

#### DeepBase.LogAggregator.pas (~1600 �?
- **日志聚合�?*: `TLogAggregator` 主类，支持批量推送、重试机�?- **后端接口**: `ILogBackend` 抽象，可扩展多种后端
- **ElasticSearch 后端**: `TElasticSearchBackend` - ES 7.x+ Bulk API 支持
- **Loki 后端**: `TLokiBackend` - Grafana Loki Push API
- **HTTP Webhook 后端**: `THttpWebhookBackend` - 通用 HTTP 推�?- **日志批次**: `TLogBatch` 批量操作�?- **过滤�?*: `TLogFilter` 流式 API
- **配置**: `TBackendConfig` 后端配置工厂方法

#### DeepBase.LogQuery.pas (~1800 �?
- **查询构建�?*: `TLogQueryBuilder` 流式查询 API
  - Where* 系列过滤方法
  - OrderBy*, Skip, Take 分页
  - GroupBy, Distinct 聚合
- **查询结果**: `TLogQueryResult` 支持 ToJSON/ToCSV 导出
- **时序数据**: `TLogTimeSeries` 时间序列分析
- **统计**: `TLogStats` 日志统计信息
- **分析�?*: `TLogAnalyzer` 高级分析功能
  - CountByLevel/Source/Host/App
  - CountByTime, ErrorRateByTime
  - TopErrors, TopExceptions
  - FindPatterns (正则匹配)
  - FindAnomalies (统计异常检�?
  - IsErrorRateIncreasing, GetTrend (线性回�?

#### DeepBase.LogAlert.pas (~1260 �?
- **告警条件**: `TAlertCondition`
  - ErrorCount: 错误数阈�?  - ErrorRate: 错误率阈�?  - PatternMatch: 模式匹配
  - NoLogs: 无日志检�?- **告警动作**: `TAlertAction`
  - Webhook: HTTP 回调
  - Email: 邮件通知 (接口)
  - Callback: 本地回调
  - Log: 日志输出
- **告警规则**: `TAlertRule` 流式 API 定义规则
- **告警管理�?*: `TAlertManager`
  - 后台评估线程
  - Cooldown 冷却机制
  - 历史记录
  - 活动告警查询

#### DeepBase.LogDashboard.pas (~1160 �?
- **Widget 类型**: Counter, Gauge, LineChart, BarChart, PieChart, Table, Heatmap
- **仪表�?*: `TDashboard` 面板�?Widget 组织
- **导出�?*: `TDashboardExporter`
  - ToJSON: 内部格式
  - ToGrafanaJSON: Grafana 兼容格式
  - ToHTML: 独立 HTML 页面
  - ToCSV: 数据导出
- **构建�?*: `TDashboardBuilder`
  - BuildOverviewDashboard: 概览仪表�?  - BuildErrorDashboard: 错误分析仪表�?  - BuildPerformanceDashboard: 性能仪表�?
### DeepBase.Logging.pas 扩展 (v1.1)
- `SetAggregatorEnabled(AEnabled)`: 启用/禁用聚合�?- `ConfigureAggregator(AppName, AppVersion, Environment)`: 配置元数�?- `AggregatorEnabled`, `AppName`, `AppVersion`, `Environment` 属�?- 写入线程自动推送到聚合�?
### 单元测试
- `Tests/Test.DeepBase.LogAggregator.pas` (~813 �?
  - TTestLogAggregator: 聚合器和批次测试
  - TTestLogQuery: 查询和分析器测试
  - TTestLogAlert: 告警规则和管理器测试
  - TTestLogDashboard: 仪表板和导出测试

### 使用示例

```pascal
// 配置 ElasticSearch 后端
LogAggregator().AddBackend(
  CreateElasticSearchBackend('http://localhost:9200', 'app-logs'));
LogAggregator().Start;

// 启用日志聚合
Logger.SetAggregatorEnabled(True);
Logger.ConfigureAggregator('MyApp', '1.0.0', 'production');

// 配置告警规则
AlertManager().AddRule(
  CreateAlertRule('high-error-rate', 'High Error Rate')
    .WithCondition(TAlertCondition.ErrorRate(10.0, 5))
    .WithSeverity(asCritical)
    .AddAction(TAlertAction.Webhook('https://hooks.slack.com/...'));
AlertManager().Start;

// 查询和分�?var Results := LogQuery()
  .WhereLevelIn([llError, llFatal])
  .WhereTimeBetween(IncHour(Now, -1), Now)
  .OrderByTimestampDesc
  .Take(100)
  .Execute;

var Stats := LogAnalyzer.GetStats;
var TopErrors := LogAnalyzer.TopErrors(10);

// 生成仪表�?var Builder := TDashboardBuilder.Create(LogAnalyzer);
var Dashboard := Builder.BuildOverviewDashboard;
var Exporter := TDashboardExporter.Create(Dashboard);
var HTML := Exporter.ToHTML;
```

### 统计
- 新增代码: ~6600 �?- 新增模块: 4 个核心模�?- 新增测试: ~813 �?(35 个测试用�?

---

## Phase MAINT-2: 项目清理与代码质�?�?(完成)

> 完成日期: 2025-12-08
> 负责�? Claude

### MAINT-2-001: 项目结构清理 �?- **完成日期**: 2025-12-08
- **输出�?*:
  - 创建 `backup/` 目录存放不确定是否需要的文件
  - 移动 7 个过时状态文件到 backup (Phase*_Status.md, Studio_Status.md, better.md, DOCS_UPDATE.md)
  - 移动旧版规划文档目录�?backup
  - 移动 `docs/uniFlow/` 错位源码目录�?backup
  - 移动 `DeepBase` 空单元文件到 backup
  - 移动 `DeepBase.db` 开发数据库�?backup
  - 删除 90+ 编译产物文件 (.dcu, .exe, .dproj.local)
  - 更新 `.gitignore` 添加 backup/ �?DeepBase.db
- **commit**: e5f0cd5
- **影响**: 312 文件变更，删�?176,557 �?
### MAINT-2-002: 代码质量深度检�?�?- **完成日期**: 2025-12-08
- **检查维�?*:
  - �?异常处理 - 发现 30+ 处空 except �?  - �?内存管理 - 确认 FreeAndNil 使用规范
  - �?线程安全 - 发现 1 处竞态条�?  - �?初始化顺�?- 确认模块依赖正确
  - �?API 一致�?- 确认命名规范统一
  - �?Schema 兼容�?- 已有版本检查机�?
### MAINT-2-003: 异常处理改进 �?- **完成日期**: 2025-12-08
- **修复内容**:
  - `DeepBase.Manager.pas`: Schema 修复错误记录�?Logger.Warn
  - `DeepBase.PluginManager.pas`: 5 处插件错误改�?FirePluginError 通知
  - `DeepBase.Logging.pas`: 使用 TInterlocked.CompareExchange 修复竞态条�?  - `DeepBase.Theme.pas`: 4 处主题错误添�?DEBUG 日志
  - `DeepBase.Updater.pas`: 3 处更新错误添�?DEBUG 日志
  - `DeepBase.VirtualScroll.pas`: 渲染回调错误添加 DEBUG 日志
  - `DeepBase.DB.Pool.pas`: 3 处连接池错误添加 DEBUG 日志
  - `DeepBase.CLI.SSH.pas`: 2 �?SSH 错误添加 DEBUG 日志
  - `DeepBase.SplashScreen.pas`: 图片加载错误添加 DEBUG 日志
  - `DeepBase.Feedback.pas`: 轮询错误添加 DEBUG 日志
  - `DeepBase.Diagnose.pas`: 4 处诊断检查错误添�?DEBUG 日志
- **commit**: 3af9446, af260c3
- **影响**: 11 文件�?32 行新�?
### 统计
- 清理文件: 312 �?- 修复模块: 11 �?- 新增 Bug 修复记录: 11 �?(BUG-050 ~ BUG-060)

---

## 商业化基础阶段 (P0) �?
### PUB-001: 模块整理归并 �?- **完成日期**: 2025-12-09
- **内容摘要**:
  - SeedTool 移动�?`DeepBase/Tools/SeedTool`
  - 反调�?保护单元归并�?`Features/DeepBase.AntiTamper.pas` �?`Core/DeepBase.Protection.pas`
  - About 界面重构�?`VCL/DeepBase.VCL.AboutFrame.pas`
  - 更新相关 uses 和命名空间，确保编译通过

### PUB-002: DeepBase.Unlock 轻量解锁模块 �?- **完成日期**: 2025-12-09
- **内容摘要**:
  - 新增核心单元 `Core/DeepBase.Unlock.pas`
  - 定义解锁等级: ulFree / ulFollow / ulShare
  - 约定解锁码规�? [产品代码][年月][类型]（如 TK2412A），包含有效期和校验�?  - 解锁状态持久化到本地配�?  - 新增 `VCL/DeepBase.VCL.UnlockDialog.pas` 解锁弹窗，支持公众号二维码展�?
### PUB-003: DeepBase.Updater 增强 �?- **完成日期**: 2025-12-09
- **内容摘要**:
  - 扩展 `Features/DeepBase.AutoUpdate.pas` 支持 GitHub/Gitee Release API
  - 通过 `github:owner/repo` / `gitee:owner/repo` 约定自动选择更新�?  - 保持对静�?`version.json` 的向后兼�?  - VCL 端新�?完善 `VCL/DeepBase.VCL.UpdateDialog.pas` 更新对话�?
### PUB-004: UniPublisher 发布工具 �?- **完成日期**: 2025-12-09
- **内容摘要**:
  - 创建 `Tools/UniPublisher` VCL 工具项目
  - 支持读取/写入 .dproj 版本�?  - 打包输出目录�?ZIP 安装�?  - �?DeepBase 规范生成 `version.json` 清单
  - 通过 gh CLI 发布 GitHub Release，并通过 HTTP API 创建 Gitee Release
  - 集成基于 `DeepBase.Unlock` 的解锁码生成器和发布说明编辑

### PUB-005: TwoKeyRun 集成验证 �?- **完成日期**: 2025-12-09
- **内容摘要**:
  - �?`TwoKeyRun` 中初始化 `TDeepBaseManager` 以启用通用配置/解锁/自动更新
  - 使用 `TDeepBaseUnlock` 重构 TwoKeyRun 解锁逻辑，统一 24/58/60 格策�?  - �?`DeepBase.VCL.UnlockDialog` 取代自定义解锁对话框
  - 集成 `DeepBase.VCL.AutoUpdater`，支持通过 DeepBase.Config 配置 UpdateUrl 自动检查更�?
---

## 商业化扩展阶�?(P1) �?|
### FMX-003: FMX 缺失控件补全 �?- **完成日期**: 2025-12-10
- **内容摘要**:
  - 完成 `FMX/DeepBase.FMX.LogListView.pas` 实现，基于日志数据库表的 FMX 日志查看�?  - 完成 `FMX/DeepBase.FMX.NotificationBar.pas` 实现，跨平台底部通知栏（进度/成功/错误/信息，支持自动隐藏与取消�?  - 完成 `FMX/DeepBase.FMX.LicenseStatusPanel.pas` 实现，展�?License 状态、类型、到期时间与授权对象
  - �?`FMX/DeepBase.FMX.Controls.pas` 中注册上述三个控件，加入 "DeepBase FMX" 组件面板，API �?VCL 版本保持一致风�?|
### SEC-002: 高级加密支持 �?- **完成日期**: 2025-12-10
- **内容摘要**:
  - 基于 `Core/DeepBase.Crypto.pas` 实现 Windows 上使�?BCrypt �?AES-256-CBC 对称加密（TAESCrypto），并提供安全随机数生成（BCryptGenRandom�?  - 新增 `Core/DeepBase.Security.pas`，使�?Windows DPAPI / OpenSSL AES-256-GCM 提供跨平台安全存储（Secrets �?+ ProtectStringDpapi/UnprotectStringDpapi�?  - 新增 `Core/DeepBase.KeyManager.pas`，实现分层密钥管理（Master/KEK/DEK），支持 `TKeyManager` 全局单例�?`TKeyStore` JSON 持久�?  - 提供 `THardwareFingerprint` 收集机器指纹（ComputerName/ProcessorId/BiosSerial/DiskSerial 等）并生�?SHA-256 指纹，用于硬件绑�?  - 通过 `TMasterKey.DeriveWithHardwareBinding` + `TKeyManager.ValidateHardwareBinding` 支持主密钥与硬件绑定的加密模�?  - 为配置场景提�?`TKeyManager.EncryptConfig/DecryptConfig` 封装，用于基�?AES-256 的配置值加解密
|
### PERF-001: 性能优化 �?- **完成日期**: 2025-12-10
- **内容摘要**:
  - 日志写入批量优化（TDeepBaseLogger 异步写线�?+ MAX_BATCH_SIZE 批处�?+ 预编�?INSERT�?  - 配置缓存预热（TDeepBaseConfig.PreloadCache �?TDeepBaseManager.InitializeModules 中启动时预热 Settings 表）
  - ORM 延迟加载优化（OneToManyAttribute.LazyLoad 标记 + TLazyLoadManager 分页惰性加载支持）
|
### PUBL-101: AboutFrame + AntiTamper 规范与文档更�?�?- **完成日期**: 2025-12-11
- **内容摘要**:
  - �?`docs/04.01.DeepBase-4AI-数据库Schema说明-v1.0.md` 中补�?`aboutMeImages` 表定�?增加 `Enabled INTEGER NOT NULL DEFAULT 1` 字段,并约�?6 个标�?ImageKey (official_gzh / wechat / alipay / btc / usdt / aboutme)�?  - AboutFrame 接入规范已归并到 `docs/IMPLEMENTATION_GUIDE.md`: 统一使用 `{AppName}Config.db` 作为 DB1，说�?aboutMeImages 表字段语义，给出 AntiTamper + SeedTool 播种流程示例�?  - 关于页面推荐结构已归并到 `docs/README.md` 与具体项目集成文档，定义 6 �?Tab(公司公众�?微信/支付�?BTC/USDT/关于�? 的布局�?ImageKey 关系�?|
### PUBL-102: AntiTamper / AboutFrame 模块实现与集�?�?- **完成日期**: 2025-12-09
- **内容摘要**:
  - 将原�?`uAntiTamperPackage` / `uBasicProtection` 等分散单元整理归并为 `Features/DeepBase.AntiTamper.pas` �?`Core/DeepBase.Protection.pas`, 提供统一的防篡改初始化与图像解密 API(�?AES/HMAC 支持)�?  - 实现 `VCL/DeepBase.VCL.AboutFrame.pas` 与配�?DFM, 作为统一�?About/打赏/公司公众�?Frame, �?DB1 �?`aboutMeImages` 表按 ImageKey 读取图像和文�?并根�?`Enabled` 字段控制 Tab 显示�?  - �?`DeepBase.i18n` 集成, �?About 页签标题/按钮文案预留多语言支持,以便在工具侧进行本地化�?
### PUBL-103: SeedTool aboutMeImages + enabled 改�?�?- **完成日期**: 2025-12-11
- **内容摘要**:
  - �?AntiTamper 默认表名�?`images` 统一调整�?`aboutMeImages` (包括 `Features/DeepBase.AntiTamper.pas` �?`Tools/SeedTool/uAntiTamperPackage.pas`), 并在建表/升级逻辑中新�?`enabled INTEGER NOT NULL DEFAULT 1` 字段�?  - 扩展 SeedTool 数据模型 (`TImageFileInfo`) 增加 `Enabled: Boolean`, 在“文字配置”页签新�?`chkEnabled` 勾选框, 用于控制每个 ImageKey 是否�?AboutFrame 中显示�?  - �?`aboutMeImages` 加载数据时一并读�?`enabled` �? 只读文本模式/完整播种模式下均会在播种后通过 `UPDATE aboutMeImages SET enabled = ...` 同步启用状态�?
### PUBL-104: DeepDeepDeepDeepDeepMoveC 参考实现对齐新规范 �?- **完成日期**: 2025-12-11
- **内容摘要**:
  - �?DeepDeepDeepDeepDeepMoveC �?DeepBase 示例中的 About/打赏页面统一迁移�?`{AppName}Config.db` + `aboutMeImages` 规范: `FrameAboutMe.pas` �?`VCL/DeepBase.VCL.AboutFrame.pas` 默认连接 `DeepDeepDeepDeepDeepMoveCConfig.db`, 表名绑定�?`aboutMeImages`�?  - �?DeepDeepDeepDeepDeepMoveC �?DeepBase AntiTamper 中启�?`enabled` 字段支持, 并在 `LoadSecureImage` 中检�?`enabled=0` 时直接跳过记�? 实现逻辑禁用而不删除数据�?  - 通过新版 SeedTool �?DeepDeepDeepDeepDeepMoveC �?`aboutMeImages` 表播�?6 个标�?key(official_gzh / wechat / alipay / btc / usdt / aboutme) 的图像与文本, 验证 Win32/Win64 �?About 页签显示与禁用行�? 为后�?TwoKeyRun/DeepSync 等项目接入提供参考实现�?
### PUBL-106: UniPublisher 配置模型�?version.json 统一规范落地 �?- **完成日期**: 2025-12-11
- **内容摘要**:
  - 新增 `Tools/UniPublisher/Core/Publisher.Config.pas` (~700 �?:
    - `TPublishConfig` 配置模型,映射 `.publish.json` 字段 (appId/appName/displayName/dproj/outputDir/packageLayout/publishTargets/metadata)
    - `TPackageLayout`/`THttpTarget`/`TGitHubTarget`/`TGiteeTarget`/`TPublishMetadata` 记录类型
    - `TPublishConfigMRU` MRU 管理�?支持最近项目列表持久化
  - 新增 `Tools/UniPublisher/Core/Publisher.Manifest.pas` (~530 �?:
    - `TVersionManifest` 新版 version.json 结构 (appId/version/channel/publishedAt/files[]/releaseNotes/mandatory/minVersion)
    - `TManifestFile`/`TManifestMetadata` 记录类型
    - `TManifestGenerator` 工具�?支持新版 `GenerateManifest` 和旧�?`GenerateLegacyJSON` 格式生成
    - `IsNewFormat` 自动检�?JSON 格式
  - 扩展 `Features/DeepBase.AutoUpdate.pas` (v0.3 �?v0.4):
    - 新增 `IsNewFormatJson` 格式检测方�?    - 新增 `CheckForUpdateFromNewFormat`/`CheckForUpdateFromLegacyFormat` 分离解析逻辑
    - `CheckForUpdateFromJson` 自动识别新旧格式并调用对应解析器
  - 重构 `Tools/UniPublisher/Forms/UniPublisher.MainForm.pas`:
    - 顶部新增项目配置选择区域 (MRU 下拉�?+ 浏览/保存按钮)
    - 启动时自动加载最近项�?(`LoadLastProject`)
    - `ConfigToUI`/`UIToConfig` 配置�?UI 双向同步
  - 新增单元测试 `Tests/Test.DeepBase.PublishConfig.pas` (~580 �?:
    - `TTestPublishConfig`: 7 个测试用�?(序列�?反序列化/验证/持久�?
    - `TTestVersionManifest`: 7 个测试用�?(新旧格式生成/解析/保存)
    - `TTestPublishConfigMRU`: 8 个测试用�?(MRU 增删改查/持久�?
    - `TTestAutoUpdateFormatDetection`: 4 个测试用�?(格式检�?版本提取)
- **统计**:
  - 新增代码: ~1800 �?  - 新增测试: 26 个测试用�?
### PUBL-107: UniPublisher 发布目标与开发体验优�?�?- **完成日期**: 2025-12-11
- **内容摘要**:
  - 新增 `Tools/UniPublisher/Core/Publisher.Targets.pas` (~895 �?:
    - `TPublishStatus`/`TPublishResult`/`TPublishResults` 发布结果模型
    - `TValidationResult` 配置验证结果，支持错误和警告收集
    - `TTargetValidator` 静态验证类，验�?HTTP/GitHub/Gitee 配置完整性，检�?gh CLI 可用�?    - `THttpPublisher` HTTP 上传发布器，支持 multipart form-data
    - `TGitHubPublisher` GitHub 发布器，通过 gh CLI 创建 Release 并上传资�?    - `TGiteePublisher` Gitee 发布器，通过 HTTP API + Access Token 创建 Release
    - `TUnifiedPublisher` 统一发布入口，支持一键发布到所有启用目�?  - 增强 `UniPublisher.MainForm.pas`:
    - 右侧新增发布状态面�?(`pnlPublishStatus`)，包含目标状态指示灯 (圆形 Shape + 标签)
    - 快捷操作按钮: 重新加载配置 / 打开输出目录 / 打开 version URL / 一键发�?    - 发布日志 Memo，实时显示发布进度和结果
    - `UpdateTargetStatusUI` 根据配置自动更新状态指示灯颜色
- **统计**:
  - 新增代码: ~895 �?(Publisher.Targets.pas) + ~200 �?(MainForm 增强)

### PUBL-108: Developer Test Center + UniPublisher 集成参考实�?�?- **完成日期**: 2025-12-11
- **内容摘要**:
  - 新增 `Core/DeepBase.TestCenter.pas` (~636 �?:
    - `TTestStatus` 测试状态枚�?(NotRun/Running/Passed/Failed/Skipped)
    - `TTestCategory` 测试分类记录
    - `TTestItem` 测试项类，支持执行回调、状态跟踪、JSON 序列�?    - `ITestRunner` 测试运行器接口，`TDefaultTestRunner` 默认实现
    - `TTestCenterManager` 测试中心管理器，支持分类/测试注册、批量执行、结果统计、持久化
    - `TStandardCategories` 标准分类常量 (core/vcl/fmx/network/database/autoupdate/publisher/tools)
  - 新增 `VCL/DeepBase.VCL.TestCenterFrame.pas` (~655 �?:
    - 三栏布局: 左侧分类�?(TTreeView) / 中间测试列表 (TListView) / 右侧详情日志 (TMemo)
    - 底部控制�? 运行选中 / 运行全部 / 重置 / 打开 UniPublisher...
    - "打开 UniPublisher..." 通过 ShellExecute 启动，自动搜索常见路�?    - `RegisterSampleTests` 注册示例测试用例
  - 集成�?`Examples/FullDemo/FullDemo.MainForm.pas`:
    - 新增 "测试中心" 页签，嵌�?TTestCenterFrame
    - 自动初始化并注册示例测试
- **统计**:
  - 新增代码: ~1291 �?(TestCenter + Frame)

### PUBL-105: 工具项目 AboutFrame 集成 �?- **完成日期**: 2025-12-12 (DeepBase 侧开发完成，待人工集�?
- **内容摘要**:
  - 新增集成规划索引文档（当前位�?`docs/README.md`�?  - 新增 5 个工具项目集成规划文�?
    - `docs/01.TwoKeyRun-Integration.md` - VCL项目, 已有 FrameAboutMe, 结构分析和迁移方�?    - `docs/02.DeepSync-Integration.md` - FMX项目, 需新建 AboutFrame, �?FMX 组件开发计�?    - `docs/03.SVGThing-Integration.md` - VCL项目, 已有 FrameAboutMe, 数据库迁移方�?    - `docs/04.Stocks-Integration.md` - FMX项目 (InfoCenter), 已集�?DeepBase, 需 FMX 组件
    - `docs/05.DeepCharset-Integration.md` - VCL项目, 轻量级工�? 弹窗式集成方�?  - VCL AboutFrame (`VCL/DeepBase.VCL.AboutFrame.pas`) 扩展�?6 �?Tab�?    - 新增 `tsOfficialGzh` 公众号页面，�?FMX 版本保持一�?    - 图像映射数组扩展�?6 �? official_gzh/wechat/alipay/btc/usdt/aboutme
  - FMX AboutFrame (`FMX/DeepBase.FMX.AboutFrame.pas`) 已对�?
    - 使用 `TAntiTamperPackage.LoadSecureImageBytes()` 统一解密和校�?    - 字段名与 SeedTool/AntiTamper 一�? `sha256_hash`/`hmac_sha256`
  - 更新 `docs/IMPLEMENTATION_GUIDE.md`:
    - 标记 FMX AboutFrame 已完成对�?    - 更新 Q4 常见问题解答
    - 更新任务检查清单和下一步建�?- **统计**:
  - VCL 项目: 3 �?(TwoKeyRun/SVGThing/DeepCharset)
  - FMX 项目: 2 �?(DeepSync/Stocks)
- **待人工完�?*:
  - 准备 6 张标准图片资�?  - 运行 SeedTool 为各项目创建 `*Config.db` 并播�?  - �?IDE 中按指南修改各项目代码并编译测试

---

## 工具�?CLI 增强阶段 (P2) �?
### CLI-002: CLI 交互增强 �?- **完成日期**: 2025-11-29
- **内容摘要**:
  - 新增核心交互�?CLI 模块 `Tools/CLI/DeepBase.CLI.Interactive.pas`，提�?`TInteractiveCLI` REPL（命令历史、变量、脚本执行、输出格式切换）
  - 新增 `Tools/CLI/DeepBase.CLI.Pipeline.pas` 管道模块，支�?`|`/`>`/`>>`/`tee` 以及 grep/sort/head/tail/uniq/wc/rev/cut/tr/jq 等过滤器
  - 在交互模块中引入 `TAnsiColor` 终端颜色工具类，用于统一的错�?警告/成功彩色输出
  - CLI 工具层通过 `CLI.Commands.TCliUtils` 复用颜色输出能力，为常规 `DeepBase` 命令提供彩色状态提�?
### TOOL-002: Studio 增强 �?- **完成日期**: 2025-11-29
- **内容摘要**:
  - SQL 查询编辑器（Studio.SQLFrame：语法高亮、执�?历史、结果网格、CSV 导出、DoQry 集成�?  - Schema 可视化浏览器（Studio.SchemaFrame：表/�?索引/外键树状浏览 + DDL 查看�?  - 数据导入导出向导（Studio.ImportExportFrame：CSV/JSON/XML 导出 + CSV/JSON 导入预览与事务导入）

---

## 维护阶段 (MAINT) - 进行�?
### MAINT-002: 单元测试覆盖率提�?🟡
|- **状�?*: 进行�?|- **目标**:
|  - 单元测试整体覆盖率提升到 95%+，并覆盖关键安全/网络/工具模块的边界条件与错误路径�?|- **已完�?(2025-12-08)**:
|  - �?`Test.DeepBase.Math.pas` - 数学工具测试 (40+ 测试用例，向�?矩阵/统计/插�?缓动/随机)
|  - �?`Test.DeepBase.Metrics.pas` - 指标收集测试 (35+ 测试用例，Counter/Gauge/Histogram/Timer/Registry)
|  - �?`Test.DeepBase.Net.pas` - 网络工具测试 (40+ 测试用例，HTTP/WebSocket/DNS/IP/Subnet)
|  - �?`Test.DeepBase.HttpServer.pas` - HTTP服务器测�?(35+ 测试用例，路�?中间�?请求响应)
|  - �?`Test.DeepBase.FileWatcher.pas` - 文件监控测试 (30+ 测试用例，过滤器/配置/集成测试)
|- **已完�?(2025-12-10)**:
|  - �?CLI 与反射相关测试：`Test.DeepBase.CLI.Pipeline.pas`, `Test.DeepBase.CLI.Interactive.pas`, `Test.DeepBase.Reflection.pas`, `Test.DeepBase.Export.pas`
|  - �?数据库与诊断相关测试：`Test.DeepBase.Diagnose.pas`, `Test.DeepBase.DB.Pool.pas`, `Test.DeepBase.DBException.pas`, `Test.DeepBase.SQLLogger.pas`
|  - �?核心基础设施测试：`Test.DeepBase.SingleInstance.pas`, `Test.DeepBase.Schema.pas`, `Test.DeepBase.Exception.pas`, `Test.DeepBase.Consts.pas`
|  - �?云与后台服务测试：`Test.DeepBase.CloudBackup.pas`, `Test.DeepBase.Feedback.pas`, `Test.DeepBase.PluginManager.pas`, `Test.DeepBase.AutoUpdate.pas`
|  - �?UI 与体验相关测试：`Test.DeepBase.VirtualScroll.pas`, `Test.DeepBase.SplashScreen.pas`, `Test.DeepBase.AntiTamper.pas`, `Test.DeepBase.Protection.pas`
|  - �?安全与密钥管理测试：`Test.DeepBase.KeyManager.pas`, `Test.DeepBase.Interfaces.pas`, `Test.DeepBase.LLM.Manager.pas`, `Test.DeepBase.LLM.ImportExport.pas`, `Test.DeepBase.ORM.Mapping.pas`, `Test.DeepBase.Updater.pas`
|- **已完�?(2025-12-11)**:
|  - �?�?OpenSSL �?LLM 核心类型补充单元测试：`Test.DeepBase.Crypto.OpenSSL.pas`, `Test.DeepBase.LLM.pas`，覆盖加解密、错误路径与配置/消息模型序列化�?|  - �?�?GUI 测试基础设施增加回归测试：`Test.DeepBase.TestHelper.pas`，覆盖快照捕�?校验、控件查找与用户交互模拟�?|  - �?修复并补�?DB 异常测试：`Core/DeepBase.DBException.pas` 改进 `EDeepBaseDB.UserMessage` 中文+英文混排场景，`Test.DeepBase.DBException.pas` 增加回归用例�?|  - �?新增 WebAPI 集成测试：`Tests/Integration/Test.Integration.WebAPI.pas`，覆�?HTTP 路由、查询参数解析、CORS、JWT 认证、OpenAPI 生成�?WebSocket 消息路由，相�?Core/Auth 单元问题已修复并通过测试�?|  - �?将测试覆盖率统计集成�?`Scripts/run_tests.ps1`，支持在本地/CI 中输�?DUnitX XML 结果及简�?HTML 汇总页面，便于持续监控覆盖率�?|||  - �?将数据库相关 Integration Tests 标记为「环境依赖」：�?`Test.Integration.Core.pas` 中为所有依�?SQLite/FireDAC 的集成测�?Fixture 添加 `Category(\"DBEnv\")`，并�?`Scripts/run_tests.ps1` 中默认通过 `--exclude:DBEnv` 排除这些测试；当需要完整运行数据库集成测试时，可通过设置环境变量 `DeepBase_RUN_DB_INTEGRATION=1` 显式启用�?|||- **已完�?(2025-12-13)**:
|||  - �?`Test.DeepBase.i18n.pas` - i18n 模块回归测试补全
|||  - �?`Test.DeepBase.Theme.pas` - 主题模块回归测试补全
|||  - �?`Test.DeepBase.FormState.pas` - 修复测试稳定性并恢复�?`DeepBaseTests.dpr`
|||  - �?`Test.DeepBase.Logging.pas` - 重写�?file-only 异步写入可验证的测试，并恢复�?`DeepBaseTests.dpr`
|||  - �?`Test.DeepBase.License.pas` - 恢复�?`DeepBaseTests.dpr`
|- **已完�?(2025-12-18)**:
|  - �?`Test.DeepBase.DateTime.pas` - DateTime 模块测试修复 (FormatOffset 格式问题、NextDayOfWeek/PreviousDayOfWeek 枚举映射问题、测试期望值修�?
|  - �?测试通过率提升：824 测试�?751 通过 (91.1%)�?1 失败�?8 错误（Access Violation�?|  - �?错误分类：Access Violation 主要来自 Config/FormState/Hotkeys/MRU/Theme/i18n 模块（需 DeepBaseManager 初始化）
||- **下一�?*:
|  - （可选）在持续集成环境中补充针对数据�?Integration Tests 的文档与示例配置（包�?FireDAC/SQLite 驱动部署方式、专用测试数据库路径等），方便在有完整数据库环境的机器上重新启用 DB 集成测试�?---

## 文档优化（DOC-OPT�?
### DOC-OPT-001: 文档编号统一 + OneFile 入口创建 + 过期文档清理 �?- **完成日期**: 2026-05-06
- **内容摘要**:
  - �?**Phase 1 编号统一**�?8 �?.md 文件的中文序数标题统一为阿拉伯数字标准（`## N.` / `### N.N` / `#### N.N.N`�?    - docs/: `06.AntiTamper-Integration.md`, `07.Project-Classification.md`, `07.01.DeepBase-4AI-集成检查清�?v1.0.md`, `99.07.DeepBase-4H-迁移修复记录-v0.3.md`
    - Tools/SeedTool/: `加密防篡改集成说�?md`, `播种与主程序对应说明.md`
    - README.md
    - doQry/tasks.md
    - docs/uniFlow/: `01.02.Quick-UniFlow-开发者快速上手指�?v1.0.md`
    - docs/uniFlow/SayDone/ (8 files): `03.01`, `03.03`, `03.07`, `03.09`, `01.09`, `01.11`, `06.03`, `06.05`
  - �?**Phase 2 M1 对外唯一入口**：创�?`docs/DeepBase-Integration-OneFile.md`，整�?DB1~DB4 边界、全模块能力清单、推荐接入组合、平台网站跳转流程、最小端到端步骤、关键约�?  - �?**Phase 3 M2 入口收敛**：更�?`docs/README.md` �?`docs/00.00.DeepBase-文档索引-v1.0.md`，标�?OneFile 为对外唯一入口
  - �?**Phase 4 M3 内容纠错**：修�?`docs/06.AntiTamper-Integration.md` 中的过期路径引用；统一 DB 口径
  - �?**Phase 5 M4 过期文档清理**：删�?10 个过�?重复文件
    - backup/: `Phase0-3_Status.md`, `Studio_Status.md`, `DOCS_UPDATE.md`, `better.md`
    - docs/: `99.07.DeepBase-4H-迁移修复记录-v0.3.md`, `99.09.DeepBase-4H-术语审计报告-v1.0.md`
    - `QUICK_START.md`
  - �?**验证**：`grep` 确认零中文序数残留；`check_doc_links.ps1` 确认链接有效
- **说明**: 文档优化计划源自 `better.md` �?M1-M5 里程碑定义，已全部执行完成�?
### DOC-OPT-002: 五位专家框架评估 �?- **完成日期**: 2026-05-06
- **内容摘要**:
  - �?邀�?5 位专家（打包/安全/测试/架构/文档）独立评估框架完善度
  - �?综合评分 6.7/10，打�?(5.5) 最低，架构 (7.5) 最�?  - �?识别 5 个封板阻塞问�?(B1-B5)�?0 个重要改�?(I1-I10)
  - �?结果已转化为可执行任务写�?`tasks.md`

### PKG-001: 86 个孤�?.pas 文件注册�?.dpk �?�?- **完成日期**: 2026-05-06
- **内容摘要**:
  - �?32 文件 �?DeepBaseCore.dpk�?6 单元�?  - �?22 文件 �?DeepBaseServices.dpk�?4 单元�?  - �?3 文件 �?DeepBaseFeatures.dpk（LLM.Manager/BillingClient/ImportExport�?  - �?20 文件 �?DeepBaseVCL.dpk�?6 VCL + 4 VCL-only Core�?  - �?13 文件 �?DeepBaseFMX.dpk�? DeepBaseFeatures requires�?  - �?1 文件 �?DeepBasePersistence.dpk

### PKG-002/003: Math/Unlock 重复修复 �?- **完成日期**: 2026-05-06

### TEST-001: 53 个测试文件注�?�?- **完成日期**: 2026-05-06

### SEC-002: 硬编码默�?Salt 移除 �?- **完成日期**: 2026-05-06

### ARCH-046: Exception↔Manager 循环依赖解除 �?- **完成日期**: 2026-05-06

### QUAL-001: 438 �?FreeAndNil 规范�?�?- **完成日期**: 2026-05-06
- **内容摘要**: 82 文件 438 处析构函数内 + 13 文件 19 处字段重新赋�?
### VERSION-001: 版本号统一 �?- **完成日期**: 2026-05-06

---

## 社区与生态（ECO�?
### ECO-002: 社区扩展包（第一阶段�?�?- **完成日期**: 2025-12-08
- **内容摘要**:
  - �?`ThirdParty/DB/DeepBase.DB.PostgreSQL.pas` - PostgreSQL 驱动适配�?  - �?`ThirdParty/DB/DeepBase.DB.MySQL.pas` - MySQL 驱动适配�?  - �?`ThirdParty/UI/DeepBase.UI.Themes.pas` - UI 主题系统
  - �?`ThirdParty/Cloud/DeepBase.Cloud.Storage.pas` - 云存储集成（对象存储封装�?- **说明**:
  - 以上�?ECO-002 的第一批官方扩展包，实现数据库驱动、主题与云存储三类集成�?  - 第二阶段（支�?社交集成）作为后续任务，已记录在 `tasks.md` 中的 ECO-002 小节�?
---

## 2026-05-06 封板质量门禁与功能补齐归�?
### SEC-001: �?Windows AES XOR fallback 替换�?OpenSSL �?- **完成日期**: 2026-05-06
- **内容摘要**:
  - `DeepBase.Crypto.OpenSSL.pas` 新增 AES-256-CBC EVP 加解密入口�?  - `DeepBase.Crypto.pas` �?Windows 分支�?XOR 伪加密改�?OpenSSL AES-256-CBC�?  - Windows 平台保持 CNG/BCrypt 路径�?
### SEC-003: 插件签名验证实现 �?- **完成日期**: 2026-05-06
- **内容摘要**:
  - Windows 平台使用 `WinVerifyTrust` 验证 Authenticode 签名�?  - 签名验证失败时拒绝加载插件并记录日志�?  - �?Windows 平台保留告警路径，后续可�?OpenSSL 代码签名验证�?
### COMMERCE-002: 生产存储与支付网关适配�?�?- **完成日期**: 2026-05-06
- **内容摘要**:
  - 完成后端契约文档、HTTP 存储适配器、微信支付代理、支付通知确认流程�?  - 新增 `PaymentBridge.pas` 桥接 ThirdParty SDK�?  - 新增 `Examples/CommerceE2EDemo/` 九步端到端样例�?
### GEN-001: 文档导出与分享框�?�?- **完成日期**: 2026-05-06
- **内容摘要**:
  - 新增 PDF、DOCX、VCL Image Export �?Share Service�?  - 新增 `Tests/Test.DeepBase.Export.Gen.pas` 覆盖生成路径�?
### DOC-005: README 示例修复 �?- **完成日期**: 2026-05-06
- **内容摘要**: 修复 CRUDApp 模板 `_('text')` �?`T('text')` �?i18n 示例错误�?
### ARCH-045: 包隐式导入告警清�?�?- **完成日期**: 2026-05-06
- **内容摘要**:
  - 清理运行时包 requires �?`{$IMPORTEDDATA ON}` 设置�?  - 修复 12 个包上下文编译错误�?  - `Profile All` 6 个包�?Error 编译通过�?
### MAINT-002: 单元测试编译修复与覆盖提�?�?- **完成日期**: 2026-05-06
- **内容摘要**:
  - 修复 51 个测试文件编译错误�?  - 注册 53 个测试文件到 `DeepBaseTests.dpr`�?  - Win64 DCU 编译 176 个单元零错误�?
### ECO-002: Commerce 社区扩展第二阶段 �?- **完成日期**: 2026-05-06
- **内容摘要**:
  - 新增 Supabase / Firebase Commerce 存储适配器�?  - 新增 ThirdParty SDK Gateway �?PaymentBridge�?
### FWK-001: 系统托盘模块 �?- **完成日期**: 2026-05-06
- **内容摘要**:
  - 新增 `Core/DeepBase.TrayIcon.pas` �?`VCL/DeepBase.VCL.TrayIcon.pas`�?  - 新增 `Tests/Test.DeepBase.TrayIcon.pas`�?
### FWK-002: Serialization XML 反序列化 �?- **完成日期**: 2026-05-06
- **内容摘要**: 实现 XML 标签解析、属性赋值、嵌套对象和常见标量类型反序列化�?
### FWK-003: Scheduler 任务持久�?�?- **完成日期**: 2026-05-06
- **内容摘要**:
  - 新增 `IJobStore` �?`TTaskMeta`�?  - 新增持久化任务元数据保存/读取 API�?  - 修复 `Stop()` 与运行中任务的关停竞态�?
### FWK-004: VCL/FMX I18n 控件补齐 �?- **完成日期**: 2026-05-06
- **内容摘要**:
  - VCL 新增 6 �?i18n 控件�?  - FMX 新增 2 �?i18n 控件�?
### FWK-005: FMX Theme 桥接 Core Theme �?- **完成日期**: 2026-05-06
- **内容摘要**: `DeepBase.FMX.Theme` 注册 Core Theme 平台适配器，支持 light/dark/system 模式�?
### FWK-006: Export 新增 JSON 格式 �?- **完成日期**: 2026-05-06
- **内容摘要**: 新增 DataSet/Grid/Array JSON 导出路径�?
### FWK-007: Updater �?Windows RSA 签名验证 �?- **完成日期**: 2026-05-06
- **内容摘要**:
  - `DeepBase.Crypto.OpenSSL.pas` 新增 `OpenSSL_RSAVerifySHA256`�?  - `DeepBase.Updater.pas` �?Windows 分支�?stub 改为 OpenSSL RSA-SHA256 验证�?
### PUBL-105: 工具项目 AboutFrame 集成规划 �?- **完成日期**: 2026-05-06
- **内容摘要**:
  - DeepBase �?VCL/FMX AboutFrame 已对�?`aboutMeImages` 规范�?  - 下游工具项目接入规划文档已更新�?  - 剩余为各下游项目人工集成和资源播种�?
---

## 2026-05-07 架构审阅后治�?
### ARCH-047: IoC 接口实例注册安全修复 �?- **完成日期**: 2026-05-07
- **内容摘要**:
  - `TIoCContainer.RegisterSingleton<TService>(Instance)` 不再使用 `IInterface as TObject` 提取对象指针�?  - 新增接口 singleton / factory 的独�?`IInterface` 存储与解析路径�?  - �?object-backed interface singleton/scoped 服务使用接口生命周期持有实例，避免引用计数对象释放后留下悬空对象指针�?  - `TIoCScope` 新增 `Dispose`，用于显式进�?disposed 状态并支持可测�?disposed 行为�?  - `Tests/Test.DeepBase.IoC.pas` 增加/调整回归用例，覆盖调用方释放接口引用后仍可解析、接�?factory 作为构造依赖、disposed scope 行为�?- **验证**:
  - `cmd /c compile_test.bat`：通过，`Exit code: 0`�?  - `Scripts/run_tests.ps1 -Type Unit -SkipCompile -Run Test.DeepBase.IoC`�?0/20 通过�?
### ARCH-048: RuntimeContext 默认组件注册落地 �?- **完成日期**: 2026-05-07
- **内容摘要**:
  - `RegisterDefaultRuntimeComponents` 从占位实现改为注册真实运行期组件�?  - 默认注册顺序固定�?`DeepBase.Manager` �?`IoC.Container` �?`EventBus` �?`Scheduler` �?`WorkerQueue`，Shutdown 反向释放�?  - 运行期注册保�?side-effect free：仅注册组件，不启动后台线程；启动由 `RuntimeContext.Start` 触发�?  - EventBus 增加异步 handler drain 能力，RuntimeContext Stop 时可等待异步回调完成�?  - WorkerQueue 修复 Stop/drain、定时任务、依赖任务、重试唤醒和统计累计路径，支撑运行期生命周期测试�?- **验证**:
  - `cmd /c compile_test.bat`：通过，`Exit code: 0`�?  - `Scripts/run_tests.ps1 -Type Unit -SkipCompile -Run Test.DeepBase.IoC,Test.DeepBase.Services.Registration,Test.DeepBase.Persistence.RuntimeRegistration,Test.DeepBase.RuntimeContext,Test.DeepBase.EventBus,Test.DeepBase.WorkerQueue`�?35/135 通过�?
### ARCH-049: 拆分 TDeepBaseManager 职责 �?- **完成日期**: 2026-05-07
- **内容摘要**:
  - 新增 `Core/DeepBase.Manager.Schema.pas`，承�?schema 创建、版本检查、迁移脚本执行和兼容列修补逻辑�?  - 新增 `Core/DeepBase.Manager.Operational.pas`，承�?retention 归档清理、表/列探测和 health check 逻辑�?  - `Core/DeepBase.Manager.pas` 保留原有 public API 和私有方法入口，内部改为委托 helper，避免破坏下游调用�?  - `DeepBaseCore.dpk` 已纳入两个新 Core 单元�?- **验证**:
  - `cmd /c compile_test.bat`：通过，`Exit code: 0`�?  - `Scripts/run_tests.ps1 -Type Unit -SkipCompile -Run Test.DeepBase.Manager`�?4/14 通过�?
### CONC-001: RetryPolicy 主线程阻塞保�?�?- **完成日期**: 2026-05-07
- **内容摘要**:
  - `TRetryPolicy` 新增 `TRetryMainThreadWaitMode`，支�?`rmwAllow`、`rmwWarn`、`rmwRaise` 三种主线程重试等待策略，默认 `rmwWarn` 保持兼容�?  - 新增 `OnMainThreadWaitEvent`，UI/FMX/VCL �?EventBus 主线�?handler 可记录告警或升级�?fail-fast�?  - 新增 `ExecuteAsync` / `ExecuteAsync<T>`，为 UI 场景提供后台执行入口，避免同�?retry delay 卡住主线程�?  - 新增 `ERetryMainThreadWaitException`，用�?`rmwRaise` 下阻止主线程 `Sleep`�?  - `Tests/Test.DeepBase.Resilience.pas` 补充主线程告警、raise 模式、异步重试和泛型异步返回值覆盖�?- **验证**:
  - `cmd /c compile_test.bat`：通过，`Exit code: 0`�?  - `Scripts/run_tests.ps1 -Type Unit -SkipCompile -Run Test.DeepBase.Resilience`�?18/118 通过�?
### QA-001: Examples 编译门禁 �?- **完成日期**: 2026-05-07
- **内容摘要**:
  - 新增 `Scripts/build_examples_win64.ps1`，建�?Win64 示例编译门禁�?  - 默认必选示例覆�?`Phase0Demo`、`Phase1Demo`、`FullDemo`、`FMXPlatformDemo`、`CommerceE2EDemo`�?  - 可选示例默认跳过并记录，支�?`-IncludeOptional` 扩展检查范围�?  - 输出 `TestResults/ExampleBuildResults.txt` �?`TestResults/ExampleBuildResults.xml`，便于本地和 CI 消费�?  - 修复必选示例中与当�?DeepBase API 不一致的等待窗、通知条、配置控件、FMX 平台、FMX 表单校验、Commerce 回调 verifier 和缺失资源引用问题�?- **验证**:
  - `Scripts/build_examples_win64.ps1`：Phase0Demo、Phase1Demo、FullDemo、FMXPlatformDemo、CommerceE2EDemo 全部通过�?
### ARCH-050: Resilience 按策略类型拆�?�?- **完成日期**: 2026-05-07
- **内容摘要**:
  - �?`Core/DeepBase.Resilience.pas` 改为兼容 facade，继续导出原有类型、枚举常量和 `CircuitBreakers` 入口�?  - 新增 `Core/DeepBase.Resilience.CircuitBreaker.pas`，承接断路器、状�?helper �?registry�?  - 新增 `Core/DeepBase.Resilience.Retry.pas`，承�?`TRetryPolicy`、重试策略和主线程等待保护�?  - 新增 `Core/DeepBase.Resilience.Timeout.pas`，承接超时策略和 `ETimeoutException`�?  - 新增 `Core/DeepBase.Resilience.Fallback.pas`，承接泛�?fallback 策略�?  - 新增 `Core/DeepBase.Resilience.Bulkhead.pas`，承�?bulkhead 策略和拒绝异常�?  - 新增 `Core/DeepBase.Resilience.Policy.pas`，承接组合策略编排�?  - `DeepBaseServices.dpk` 已纳入全�?Resilience 子单元�?- **验证**:
  - `cmd /c compile_test.bat`：通过，`Exit code: 0`�?  - `Scripts/run_tests.ps1 -Type Unit -SkipCompile -Run Test.DeepBase.Resilience`�?18/118 通过�?  - `Scripts/build_examples_win64.ps1`�? 个必选示例全部通过�?
### BUILD-001: DeepBaseTests 包上下文编译错误清理 �?- **完成日期**: 2026-05-07
- **内容摘要**:
  - 修复 DEBUG �?`OutputDebugString` 缺少 Windows 条件 uses 的编译问题�?  - 修复 Commerce 测试对回�?verifier 的匿名函数兼容问题�?  - 修复 PDF/DOCX/Share/WorkerQueue 的包上下文编译错误�?  - `Tests/DeepBaseTests.exe` 已重新生成�?
### API-001: 初始化错误处理一致�?�?- **完成日期**: 2026-05-07
- **内容摘要**:
  - `TDeepBaseManager.InitializeEx(out ErrorMsg): Boolean` �?`InitializeWithDB` 保持 Boolean 入口语义：失败返�?`False`，并通过 `LastError` / `InitErrorCode` 暴露原因�?  - 新增 `InitializeOrRaise` �?`InitializeWithDBOrRaise` 异常型入口，失败时抛�?`EInitializationException`�?  - 异常入口统一携带 `ErrorCode` �?`Context`，错误消息保留底层失败原因，避免调用方在 Boolean/异常两种模式间语义不一致�?  - Manager 测试固定恢复 FireDAC 测试连接适配器和 storage factory，避免全局适配器状态泄漏影响后续用例�?- **验证**:
  - `Scripts/run_tests.ps1 -Type Unit -Run Test.DeepBase.Manager`�?6/16 通过�?  - `Scripts/run_tests.ps1 -Type Unit -Run Test.DeepBase.Resilience`�?18/118 通过�?  - `cmd /c compile_test.bat`：通过，`Exit code: 0`�?  - `Scripts/build_examples_win64.ps1`�? 个必选示例全部通过�?
### SEC-004: UBS2 加密格式版本协商 �?- **完成日期**: 2026-05-07
- **内容摘要**:
  - �?Windows `ProtectStringDpapi` 继续写出 UBS2 v1，明�?`UBS2_VERSION_CURRENT` 和支持版本列表�?  - �?Windows `UnprotectStringDpapi` 改为先读�?UBS2 magic/version，再按版本分发到 v1 解密器�?  - UBS2 v1 解密器独立处�?KDF、迭代次数、salt、IV、ciphertext、tag，后续可添加 v2/v3 分支而不改主入口�?  - �?UBS1 legacy magic、未�?magic、未知版本、未�?KDF、过�?payload 和无效迭代次数给出可迁移的错误信息�?  - `Tests/Test.DeepBase.Security.pas` 补充�?Windows UBS2 版本头、未知版本、未�?KDF、legacy magic 覆盖，并收紧 Windows 篡改检测为 `EDecryptionException`�?- **验证**:
  - `Scripts/run_tests.ps1 -Type Unit -Run Test.DeepBase.Security`�?2/42 通过�?  - `Scripts/run_tests.ps1 -Type Unit -SkipCompile -Run Test.DeepBase.Security.DPAPI`�?3/23 通过�?  - `cmd /c compile_test.bat`：通过，`Exit code: 0`�?  - `Scripts/build_examples_win64.ps1`�? 个必选示例全部通过�?


---

## 2026-05-14 全仓库编译修复 (18/18 构建目标)

### BUILD-FIX-2026-05-14: 从 DeepBaseVCL 整包到全部 dproj 编译通过
- **完成日期**: 2026-05-14
- **目标**: 用户要求"整包必须编过",从 DeepBaseVCL.dpk 开始,逐步扩展到全仓库 18 个构建目标 (6 RT + 3 DT + 5 Examples/Tools + DeepBaseRun + prjDoQry + DeepBaseTests + DeepPublisher) 全部 Win64/Debug 0 errors。
- **产出**:
  - BUG-177: `Features/DeepBase.Browser.ResponseWaiter.pas` Delphi 13.1 RTL 不兼容修复 (TInterlocked.Read Integer 移除 + TProc<string> const 不匹配)
  - BUG-178: `Features/DeepBase.Browser.Types.pas` Win32 前向引用顺序修复 (IBrowserSessionFactory/TSessionRebuiltEvent 必须在 IBrowserRecoveryEvents 之前)
  - BUG-179: 全仓库中文字符串 UTF-8 截断修复 (60+ 处,跨 6 个文件)
  - BUG-180: DeepPublisher 工具项目 rename 不完整修复 (dproj/dpr/unit name/vrc/search path)
  - 搜索路径补齐: Phase0Demo / FullDemo / Studio / SeedTool / prjDoQry / DeepPublisher 的 dproj
  - DeepBaseTests: IntentClarification + LLM.PromptTemplate 恢复编译 (根因是 BUG-178 级联)
- **验证**:
  - 18/18 构建目标 Win64/Debug 全部 exit=0
  - DeepShell 测试 24/24 通过, 0 leaked
  - Win32 偶发 BPL 文件锁 race 重试即过 (非代码问题)
- **遗留**:
  - ~100 处注释含截断中文 (不影响编译,影响可读性)
  - DeepShell Demo 4 个 pending feature (tasks.md 队列)
  - Layout 跨进程需要 DB1 store (架构设计决策)


---

## 2026-05-14 基础模块 P0/P1/P2 第二轮修复 (BUG-181~196)

### BASIC-FIX-2026-05-14: 16 个基础层安全/并发/一致性问题修复
- **完成日期**: 2026-05-14
- **目标**: 按 better.md §8 评审清单,修复所有不需要架构重构即可解决的 P0/P1/P2 问题。
- **产出** (16 项):
  - P0: Authorization 事务 (BASIC-009); CloudBackup XOR→AES / CloudSync Base64→AES / LLM.Config 硬编码key→DPAPI (FR-002)
  - P1: Logging.FireDAC 加锁 (BASIC-010); Manager Initialize 加锁 (BASIC-018); Manager FinalizeModules 清回调 (BASIC-020); EventBus PublishAsync drain (BASIC-021); EventBus 统计原子 (BASIC-022); IoC FResolving 线程隔离 (BASIC-024); RuntimeContext 双检锁 (BASIC-005); Crypto Random fail-closed (BASIC-015); DB Factory 凭据 fail-closed (BASIC-011)
  - P2: Config 回调出锁 (BASIC-027); 版本号统一 (FR-001); CompareVersions 去重 (FR-013); Logger sanitizer 收敛 (FR-014); .editorconfig 品牌 (FR-017)
- **验证**:
  - 6 RT 包 Win64 编译通过
  - DeepShell 测试 24/24 通过, 0 leaked
- **遗留** (需架构重构,下一 sprint):
  - BASIC-001/004: Services 包 DAG 拆分
  - BASIC-006/007: Scheduler/WorkerQueue 生命周期 API 重设计
  - BASIC-008: DB Pool 连接 lease/refcount 重构
  - BASIC-019: 迁移引擎统一
  - LLM-001~009: LLM schema/provider/streaming 统一

---

## 2026-05-15 基础层 P0/P1 第三轮修复 + 架构重构 (BUG-193~203)

### BASIC-FIX-2026-05-15: 11 个基础层修复 + 3 个架构重构
- **完成日期**: 2026-05-15
- **目标**: 完成 better.md §8.6 遗留的所有 P0/P1 基础层问题,包括需要架构重构的三大项。
- **产出** (11 项修复 + 3 项重构):
  - P0: DB Pool 线程安全 (BASIC-008) — Release 加锁、ValidateIdleConnections csValidating、RecycleAll 只回收 idle、Shutdown drain 等待
  - P1: 架构测试加强 (BASIC-004); Scheduler 生命周期 (BASIC-006); WorkerQueue DrainAndStop (BASIC-007); Migration 命名兼容 (BASIC-012); DoQry 连接 sweep (BASIC-014); SQL Splitter 共享 (BASIC-019 部分); EventBus subscription lifetime (BASIC-023); IoC Freeze (BASIC-025)
  - P2: KeyManager 文档诚实化 (BASIC-017)
  - 架构重构: Services 包拆分 (BASIC-001) — requires 精简为 rtl+DeepBaseCore; Crypto 统一 (BASIC-016) — 唯一 BCrypt/CryptoAPI 声明源; Config 接口清理 (BASIC-026) — 移除 deprecated 方法
- **新增文件**: `Core/DeepBase.SQL.Splitter.pas`
- **新增测试**: IoC Freeze 3 个 + EventBus subscription lifetime 2 个
- **修改文件**: ~25 个 (含 5 个 .dpk, 4 个测试文件)
- **验证**: 所有修改文件 0 诊断错误; 编译输出仅有预先存在的 onnxruntime 第三方依赖问题
- **遗留** (下一阶段):
  - 周边模块 P0/P1: LLM-001/002 (schema/secrets), EDGE-002/003/006/007 (Cloud/Updater 安全)
  - P2 可维护性: FR-011 编码损坏, FR-016 DeepFlow, Speech/Governance 板块
  - 功能评审: DeepShell pending features, BrowserAutomation, IntentClarification BUG-134~142
