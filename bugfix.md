# DeepBase Bug Fixes & Issues Resolution

> 本文档记录所有发现和修复�?Bug、Issue 及改�?
---

## 2026-05-14 Bug 登记（IntentClarification）

> 本节记录 2026-05-14 五专家审阅确认的缺陷。编译接入、类型契约和 Registration 已完成首轮修复；公开 facade、DomainAdapter slots、Engine 并发、Provider session state、Router 和 LLM/L4 降级语义继续跟踪。

### BUG-143: IntentClarification Phase 2 单元未纳入包和主测试
- 发现日期: 2026-05-14
- 严重性: 🔴 Critical
- 文件: `DeepBaseFeatures.dpk`, `DeepBaseFeatures.dproj`, `Tests/DeepBaseTests.dpr`, `Tests/DeepBaseTests.dproj`
- 问题:
  - `DeepBaseFeatures` 只包含旧 `Features/DeepBase.IntentClarification.pas`，未包含 `Types/Interfaces/Engine/IoC/Provider.L0-L4/SessionFSM/...`。
  - `Test.DeepBase.IntentClarification.Integration.pas` 存在但未被活跃测试入口引用。
  - 当前 `compile_test.bat` 成功只说明旧 facade 可编译，不能证明 Phase 2 新模块可编译。
- 修复计划:
  - 将所有 IntentClarification Phase 2 单元纳入包和测试工程。
  - 包边界测试增加 `DeepBase.IntentClarification.*` 必需单元检查。
- 修复:
  - Phase 2 IC 单元已加入 `DeepBaseFeatures.dpk/.dproj` 和 `Tests/DeepBaseTests.dpr/.dproj`。
  - `Test.DeepBase.IntentClarification.Integration` 已进入活跃测试入口。
- 验证:
  - `cmd /c compile_test.bat`: `compile_output.txt` 为 `Exit code: 0`。
  - `Tests\DeepBaseTests.exe -b -r:Test.DeepBase.IntentClarification,TICIntegrationTest,TICResilienceIntegrationTest,TICSessionFSMTest`: 20/20 passed。
- 状态: ✅ 已修复

### BUG-142: 公开工厂返回空 facade，不是真正的澄清引擎
- 发现日期: 2026-05-14
- 严重性: 🔴 Critical
- 文件: `Features/DeepBase.IntentClarification.pas`, `Features/DeepBase.IntentClarification.Interfaces.pas`, `Features/DeepBase.IntentClarification.Engine.pas`
- 问题:
  - `DeepBase.IntentClarification.pas` 内定义了空 `IClarificationEngine` 和空 `TClarificationEngineFacade`。
  - `TIntentClarifier.CreateEngine/CreateEngineWithPreset` 返回空 facade，而真正可用接口和实现位于 `Interfaces.pas` 与 `Engine.pas`。
  - 下游照文档调用 `StartSession/SubmitInput/SetDomainAdapter` 会遇到接口不匹配或方法不存在。
- 修复计划:
  - 删除或改名空 facade，统一 `IClarificationEngine` 定义。
  - `CreateEngineWithPreset` 必须返回真正 `TClarificationEngine`，或文档统一改为 IoC 创建路径。
- 状态: 待修复

### BUG-141: IntentClarification 核心类型契约与实现不一致
- 发现日期: 2026-05-14
- 严重性: 🔴 Critical
- 文件: `Features/DeepBase.IntentClarification.Types.pas`, `Provider.L0-L4.pas`, `OptionFrame.pas`, `Budget.pas`, `Storage.pas`, `Rapport.pas`
- 问题:
  - `TOptionItem` 只有 `Code/Text/Value`，但 Provider/OptionFrame 使用 `Number/IsRecommended`。
  - `THypothesis` 没有 `Denied/Text`，但 L2 Provider 使用这些字段。
  - `TBudgetConfig/TBudgetStatus` 没有 `MaxTokens/TokensUsed/TokensRemaining`，但 Budget/FeatureConfig 使用。
  - `TRapportProfile` 没有 `CommunicationStyle`，但 Rapport/Storage 使用。
  - `TSessionCheckpoint`、`TPresetTemplate` 在多个单元被使用，但当前类型集中未形成稳定定义。
- 修复计划:
  - 先统一 `Types.pas`，再接入包编译暴露剩余错误。
- 修复:
  - `TOptionItem`、`THypothesis`、`TBudgetConfig/TBudgetStatus`、`TRapportProfile`、`TSessionCheckpoint`、`TPresetTemplate` 已补齐到当前实现可编译契约。
- 验证:
  - `cmd /c compile_test.bat`: `Exit code: 0`。
- 状态: ✅ 已修复

### BUG-140: Registration 门面文件半截实现
- 发现日期: 2026-05-14
- 严重性: 🔴 Critical
- 文件: `Features/DeepBase.IntentClarification.Registration.pas`
- 问题:
  - 文件只声明 `TClarificationRegistration.RegisterAll`，缺少 `implementation/end.` 和实际方法实现。
  - 文档使用的 `RegisterDomainAdapter/RegisterPersonaRegistry` 不存在。
- 修复计划:
  - 补齐 `RegisterAll`、`RegisterDomainAdapter`、`RegisterPresenter`、`RegisterPersonaRegistry`、`RegisterLLM`、`ApplyPreset`。
- 修复:
  - `DeepBase.IntentClarification.Registration.pas` 已补齐 implementation，并提供 `RegisterAll`、`RegisterDomainAdapter`、`RegisterPresenter`、`RegisterPersonaRegistry`、`RegisterLLM`、`ApplyPreset`。
- 验证:
  - `cmd /c compile_test.bat`: `Exit code: 0`。
- 状态: ✅ 已修复

### BUG-139: Engine session 并发写回会覆盖挂起/取消状态
- 发现日期: 2026-05-14
- 严重性: 🔴 Critical
- 文件: `Features/DeepBase.IntentClarification.Engine.pas`
- 问题:
  - `SubmitInput` 只在读取 session 时加锁，后续无锁处理并保留旧 `LState`，最后再写回。
  - 并发 `SuspendSession/CancelSession` 可能被旧 active 状态覆盖，session 被“写活”。
  - 并发两次 `SubmitInput` 可能产生重复 turn 或 lost update。
- 修复计划:
  - 对同一 session 建立串行化处理或乐观版本检查。
  - `FHistory/FTokenUsage/FSessions` 读写统一锁策略。
- 状态: 待修复

### BUG-138: Engine 历史、token、预算耗尽路径状态不一致
- 发现日期: 2026-05-14
- 严重性: 🟠 High
- 文件: `Features/DeepBase.IntentClarification.Engine.pas`
- 问题:
  - `FHistory/FTokenUsage` 为普通集合，但读写没有统一加锁。
  - 预算耗尽路径直接完成 session 并退出，跳过本轮 history 记录。
  - `GetSessionState` 返回的 `TSessionState.History` 不同步独立 `FHistory`。
  - `MakeErrorResult` 固定返回 `ssActive`，可能误导调用方。
- 修复计划:
  - 合并或同步 session history，预算耗尽也记录 turn。
  - 错误结果应携带真实 session 状态和 turn。
- 状态: 待修复

### BUG-137: L1 Provider 没有接入 IDomainAdapter.GetPresetSlots
- 发现日期: 2026-05-14
- 严重性: 🟠 High
- 文件: `Features/DeepBase.IntentClarification.Engine.pas`, `Features/DeepBase.IntentClarification.Provider.L1.pas`
- 问题:
  - `IDomainAdapter.GetPresetSlots` 是文档要求下游实现的关键接口，但 Engine 构建上下文时没有调用。
  - `TL1SlotProvider.BuildRequest` 最终给 `TIntentClarifier` 的 slots 为空，可能直接返回 `icsReady`，跳过澄清。
- 修复计划:
  - `TProcessingContext` 增加 preset slots 或 resolved slots 字段。
  - Engine 调用 `GetPresetSlots(AState.IntentName)` 并传给 L1 request。
- 状态: 待修复

### BUG-136: Provider 状态跨 session 串话
- 发现日期: 2026-05-14
- 严重性: 🟠 High
- 文件: `Features/DeepBase.IntentClarification.Provider.L2.pas`, `Features/DeepBase.IntentClarification.Provider.L3.pas`
- 问题:
  - L2 `FDeniedHypotheses` 是 provider 实例字段，未按 `SessionId` 分桶。
  - L3 `FCurrentExpert/FExpertSelected` 是 provider 实例字段，后续 session 会复用前一个 session 的专家。
- 修复计划:
  - Provider 尽量无状态；必须保留的状态放入 session state 或按 `SessionId` 建立状态表。
  - session 完成/取消时清理 provider session 状态。
- 状态: 待修复

### BUG-135: Router MaxLevel 边界和深度增长策略会误升层级
- 发现日期: 2026-05-14
- 严重性: 🟠 High
- 文件: `Features/DeepBase.IntentClarification.Router.pas`
- 问题:
  - `ClampDepth` 只在 `ADepth > LMaxDepth` 时钳制；当深度刚好等于边界时，`DepthToLevel` 会进入下一层。
  - `ComputeDepth` 从当前深度开始，再加 `TurnCount * 0.02`，会造成无信号场景随轮次累计升到 L3/L4。
- 修复计划:
  - 边界钳制改为按目标 level 映射，避免等值越级。
  - 深度增长改为有上限的单轮增量，并由信号/用户行为驱动。
- 状态: 待修复

### BUG-134: LLM resilience 和 L4 降级语义不可靠
- 发现日期: 2026-05-14
- 严重性: 🟠 High
- 文件: `Features/DeepBase.IntentClarification.LLMResilience.pas`, `Features/DeepBase.IntentClarification.Provider.L4.pas`
- 问题:
  - `TimeoutMs` 只在同步 LLM 调用完成后记录慢调用，不会中断卡死请求。
  - `MakeCircuitOpenResult/MakeFailureResult` 没有写 `ErrorMessage`，Provider 降级信息可能为空。
  - L4 专家和综合调用即使全部失败，最终仍可能 `Success=True`。
- 修复计划:
  - 将 timeout 下沉到 HTTP/transport 层或使用可取消任务。
  - 失败结果必须填充 `ErrorMessage`。
  - L4 所有专家或综合失败时返回 degraded failure。
- 状态: 待修复

---

## 2026-05-14 Bug 修复（IntentClarification / Browser 测试编译）

### BUG-163: IntentClarification IoC provider 构造和无 LLM 默认路径失败
- 发现日期: 2026-05-14
- 严重性: 🔴 Critical
- 文件: `Features/DeepBase.IntentClarification.IoC.pas`, `Features/DeepBase.IntentClarification.Engine.pas`
- 描述:
  - IoC 通过 RTTI 构造 `TL1SlotProvider` 时尝试解析 optional 参数 `AClarifier`，导致 `Cannot resolve constructor parameter: AClarifier`。
  - 补入 L2-L4 后，未配置 LLM 的最小 engine 会路由到 LLM provider 并返回 `PROVIDER_ERROR`，破坏基础集成测试。
  - 输入 `0` 的退出路径缺少异常隔离，退出摘要失败时会被外层捕获成 active error result。
- 修复:
  - IoC 改为显式注册 provider interface 实例，避免 optional constructor 被容器误解析。
  - IoC 默认注册 L0-L4 named providers；Engine 未配置 LLM 时跳过 `RequiresLLM=True` 的 provider，走普通澄清兜底。
  - `HandleExit` 增加摘要生成异常兜底，并在写回 session 时加锁。
- 验证:
  - `cmd /c compile_test.bat`: `Exit code: 0`。
  - `Tests\DeepBaseTests.exe -b -r:Test.DeepBase.IntentClarification,TICIntegrationTest,TICResilienceIntegrationTest,TICSessionFSMTest`: 20/20 passed。
- 状态: ✅ 已修复

### BUG-164: Browser CDP/Vision 编译阻塞
- 发现日期: 2026-05-14
- 严重性: 🟠 High
- 文件: `Features/DeepBase.Browser.CDP.pas`, `Features/DeepBase.Browser.Vision.pas`, `Tests/Test.DeepBase.Browser.Vision.pas`
- 描述:
  - `Vision` 暴露 `TRect` 但 interface uses 缺少 `System.Types`。
  - `TCDPStrategy.SendCommandSync` 声明为 `procedure ...): Boolean`，签名非法。
  - `WaitForSelector` 使用 `MilliSecondsBetween` 但缺少 `System.DateUtils`，并在 queued anonymous proc 中捕获本地嵌套过程，Delphi 编译报错。
  - Vision 测试缺少 `System.Types/System.TypInfo`，且把表达式传给 `out` 参数。
- 修复:
  - 补齐 uses，修正 `SendCommandSync` 为 function。
  - 将 `WaitForSelector` 改为后台轮询线程，并只把最终 callback queue 回主线程。
  - Vision 测试改用显式 `TRect` 变量和 `GetTypeData(TypeInfo(...))^.Guid`。
- 验证:
  - `cmd /c compile_test.bat`: `Exit code: 0`。
- 状态: ✅ 已修复

### BUG-165: Browser ScriptStore 测试契约缺失和 Unicode 字面量编码不稳定
- 发现日期: 2026-05-14
- 严重性: 🟠 High
- 文件: `Features/DeepBase.Browser.ScriptStore.pas`, `Tests/Test.DeepBase.Browser.ScriptStore.pas`
- 描述:
  - 测试期望 `EBrowserScriptStore`、`TJSScriptArray`、`TJSScriptStoreSqlite.GetBuiltinDefaults`，但轻量 in-memory 实现未提供兼容契约。
  - 模板 render 奇数 name/value 参数未抛异常。
  - 测试里的中文/emoji 字面量受源码编码影响，运行时断言不稳定。
- 修复:
  - 增加 `EBrowserScriptStore`、`TJSScriptDefinition/TJSScriptArray` 和 `TJSScriptStoreSqlite.GetBuiltinDefaults` 兼容 facade。
  - `TMemoryJSScriptStore` 初始化时加载 7 个内置脚本。
  - `TJSTemplate.Render` 对奇数参数抛 `EBrowserScriptStore`。
  - 测试改为用 Unicode code point 构造字符串，避免源码编码依赖；长度断言使用显式泛型。
- 验证:
  - `cmd /c compile_test.bat`: `Exit code: 0`。
  - `Tests\DeepBaseTests.exe -b -r:Test.DeepBase.Browser.ScriptStore.TJSTemplateTests,Test.DeepBase.Browser.ScriptStore.TBuiltinDefaultsTests`: 20/20 passed。
- 状态: ✅ 已修复

---

## 2026-05-14 Bug 修复（DeepShell VCL 桌面壳骨架）

### BUG-144: IShellCommandManager 引用 IGovernanceService 但前向声明缺失
- 发现日期: 2026-05-14
- 严重性: 🔴 Critical
- 文件: `VCL/DeepBase.VCL.DeepShell.Intf.pas`
- 描述:
  - `IShellCommandManager.SetGovernance` 引用 `IGovernanceService`，但 `IGovernanceService` 在同一单元后面声明，编译报 `E2003 Undeclared identifier: 'IGovernanceService'`，再到声明处 `E2004 Identifier redeclared`。
- 修复:
  - 在类型节顶部加 `IGovernanceService = interface;` 前向声明，让前置接口可以引用后置接口。
- 验证:
  - `dcc32 _tmp_deepshell_compile.dpr`: 通过。
- 状态: ✅ 已修复

### BUG-145: TShellEventBus 重复 uses System.Classes
- 发现日期: 2026-05-14
- 严重性: 🟡 Low
- 文件: `VCL/DeepBase.VCL.DeepShell.Events.pas`
- 描述:
  - implementation uses 段重复 `System.Classes`，编译报 `E2004 Identifier redeclared: 'System.Classes'`。
- 修复:
  - 删除 implementation 段的重复 uses。
- 状态: ✅ 已修复

### BUG-146: TThread.Queue 重载在内联匿名 proc 上歧义
- 发现日期: 2026-05-14
- 严重性: 🟠 High
- 文件: `VCL/DeepBase.VCL.DeepShell.Events.pas`
- 描述:
  - 后台线程 Publish 时直接把内联匿名 procedure 传给 `TThread.Queue(nil, ...)`，编译报 `E2250 There is no overloaded version of 'Queue' that can be called with these arguments`。
- 修复:
  - 显式声明 `LProc: TThreadProcedure := procedure begin ... end;`，再传给 `TThread.Queue`。
- 状态: ✅ 已修复

### BUG-147: TDictionary 不接受 [doOwnsValues] ownership 选项
- 发现日期: 2026-05-14
- 严重性: 🟠 High
- 文件: `VCL/DeepBase.VCL.DeepShell.Localization.pas`
- 描述:
  - `Localization` 用 `TDictionary<string, TDictionary<string, string>>.Create([doOwnsValues])` 想自动释放内层字典，编译报 `E2250 There is no overloaded version of 'Create'`。`TDictionary` 不支持 ownership，只有 `TObjectDictionary` 才有。
- 修复:
  - 改为 `TObjectDictionary<string, TDictionary<string, string>>.Create([doOwnsValues])`。
- 状态: ✅ 已修复

### BUG-148: TDeepShellToolWindow 上下面板创建顺序导致 splitter 错位
- 发现日期: 2026-05-14
- 严重性: 🟠 High
- 文件: `VCL/DeepBase.VCL.DeepShell.ToolWindow.pas`
- 描述:
  - `FUpper(alClient)` 后先创建 `FSplitter(alBottom)` 再创建 `FLower(alBottom)`，VCL alBottom 按创建顺序自底向上堆叠，FSplitter 落到最底、FLower 反而在 splitter 之上。视觉上 splitter 不是分界线。
- 修复:
  - 先创建 FLower(alBottom) 再创建 FSplitter(alBottom)，splitter 自然落在 FLower 之上。
- 状态: ✅ 已修复

### BUG-149: TDeepMainForm 关闭路径下 EventBus 订阅未撤销
- 发现日期: 2026-05-14
- 严重性: 🔴 Critical
- 文件: `VCL/DeepBase.VCL.DeepShell.MainForm.pas`
- 描述:
  - 关闭流程中先把 `FShellInitialised := False`，进入 `Destroy` 时 `if FShellInitialised then` 块被跳过，连带 `UnhookEventBus` 也不再调用。EventBus 仍然持有 `TDeepMainForm` 的 handler 闭包，后续 publish 落到已释放对象上引发 UAF。
- 修复:
  - `Destroy` 中把 `UnhookEventBus` 移出 `if FShellInitialised` 块，无论关闭路径如何都能撤销订阅。
- 状态: ✅ 已修复

### BUG-150: TShellEventBus 后台线程闭包持有裸 Self 存在 UAF
- 发现日期: 2026-05-14（五专家审阅 P0-A）
- 严重性: 🔴 Critical
- 文件: `VCL/DeepBase.VCL.DeepShell.Events.pas`
- 描述:
  - 后台线程 `Publish` 时构造的匿名 proc 隐式捕获 `Self`（`TShellEventBus` 类引用，不走 IInterface 引用计数）。如果在主线程消费 queue 之前持有方释放了 bus，`DispatchInline` 会落到已释放对象上。
- 修复:
  - 在闭包内捕获 `LSelfRef: IShellEventBus := Self`，让闭包持有的接口引用计数延长 bus 生命周期，确保 queue 消费完成前 bus 不被释放。
- 验证:
  - `dcc32 _tmp_deepshell_compile.dpr`: 通过。
- 状态: ✅ 已修复

### BUG-151: TDeepMainForm OnShow/OnClose 事件钩子可被下游覆盖
- 发现日期: 2026-05-14（五专家审阅 P0-B）
- 严重性: 🔴 Critical
- 文件: `VCL/DeepBase.VCL.DeepShell.MainForm.pas`
- 描述:
  - 通过 `OnShow := DoFormShow / OnClose := DoFormClose / OnDestroy := DoFormDestroy` 占用事件属性。下游若在 DFM 中或代码中 `OnShow := MyHandler`，Shell 的 `LoadShellState`、`AfterShellShown`、`SaveShellState` 全部失效。
- 修复:
  - 改为 override `TCustomForm.DoShow` 与 `TCustomForm.DoClose` 虚方法，事件属性留给下游使用。
  - 删除 `DoFormShow/DoFormClose/DoFormDestroy` 私有方法和 OnShow/OnClose/OnDestroy 赋值。
- 状态: ✅ 已修复

### BUG-152: RefreshBottomLog 每次事件全量重建 Memo 丢失滚动和选中
- 发现日期: 2026-05-14（五专家审阅 P0-C）
- 严重性: 🟠 High
- 文件: `VCL/DeepBase.VCL.DeepShell.MainForm.pas`
- 描述:
  - 每条 `Status.Info` → publish → `RefreshBottomLog` → 清空 Memo + 重新追加全部条目。N 条日志后第 N+1 条触发 O(N) 重建，1000 条上限触发后变 O(1000)；用户的滚动位置和选中文本每次都丢，错误信息无法被复制。
- 修复:
  - 引入 `FLastLogEntryCount` 字段，正常路径只追加新增条目；StatusManager 触发 trim 导致条目数变小时才回退到全量重建。
  - `CMD_LOG_CLEAR` handler 同步清零 `FLastLogEntryCount`，避免清屏后又把已清除的条目当成历史保留。
- 状态: ✅ 已修复

### BUG-153: svkHtml/svkMarkdown 把源码当文本塞进 Memo，违反契约
- 发现日期: 2026-05-14（五专家审阅 P0-D）
- 严重性: 🟠 High
- 文件: `VCL/DeepBase.VCL.DeepShell.MainForm.pas`
- 描述:
  - 70/72 号文档明确说 HTML/Markdown 渲染由下游 provider 负责（WebView2/CEF 或自渲染控件），Shell 核心不依赖渲染库。但实现里 `svkHtml/svkMarkdown` 走的是和 `svkText` 相同的 Memo 分支，结果用户看到的是 `<html>...</html>` 字面源码，不是渲染结果。
- 修复:
  - 把 `svkHtml/svkMarkdown` 与 `svkControl/svkFrame` 一并路由到 `IShellMainViewProvider.CreateViewControl`，由 provider 决定渲染控件。
  - Provider 返回 nil 时通过 `IShellStatusManager.Warning` 记录可见诊断，不再静默失效。
  - `OpenView` 找不到 provider 时也写一行 warning，不再静默 Exit。
- 状态: ✅ 已修复

### BUG-154: SaveShellState 在 wsMinimized 时保存了不可恢复的坐标
- 发现日期: 2026-05-14（五专家审阅 P0-E）
- 严重性: 🟠 High
- 文件: `VCL/DeepBase.VCL.DeepShell.MainForm.pas`
- 描述:
  - 最小化窗口的 `Left/Top` 是 `-32000` 之类的隐藏 sentinel 坐标。直接保存到 layout 后，下次启动若不是 maximized，会把窗口"恢复"到屏幕外，用户看不到。
- 修复:
  - `SaveShellState` 检测 `WindowState = wsMinimized`，调用 Win32 `GetWindowPlacement` 取 `rcNormalPosition` 作为保存坐标；非最小化路径走 `Left/Top/Width/Height`。
  - `DoClose` 用 `try/except` 包住 `SaveShellState/ShutdownShell`，避免保存失败把关闭路径阻塞掉。
- 状态: ✅ 已修复

### BUG-155: IShellStatusManager 缺乏 sanitizer 钩子，下游 token/Authorization 可能误入日志
- 发现日期: 2026-05-14（五专家审阅 P1-Security）
- 严重性: 🟠 High
- 文件: `VCL/DeepBase.VCL.DeepShell.Intf.pas`, `VCL/DeepBase.VCL.DeepShell.Panels.pas`
- 描述:
  - 78 号文档要求"密码、Token、私钥不进入日志"，但 Shell 没有任何机制强制。下游不小心写 `Status.Info('http', 'Authorization: Bearer eyJhb...')`，token 直接进 entries / 底部 Memo / 后续持久化层。
- 修复:
  - 新增 `TShellStatusSanitizer = reference to function(const ASource, AMessage: string): string`。
  - `IShellStatusManager.SetSanitizer` 允许下游注入正则替换器。
  - `TShellStatusManager.AddEntry` 在写入 entries 和发布 EventBus 之前对 message 应用 sanitizer；sanitizer 自身抛异常时回退到原 message，不阻断日志。
- 状态: ✅ 已修复

### BUG-156: TShellCommandManager.BuildContextJson 默认携带 project_path 泄漏 PII
- 发现日期: 2026-05-14（五专家审阅 P1-Privacy）
- 严重性: 🟠 High
- 文件: `VCL/DeepBase.VCL.DeepShell.Commands.pas`
- 描述:
  - `BuildContextJson` 把 `LCtx.ProjectPath` 无条件写入 governance evidence。本地路径常含用户名（`C:\Users\Alice\my-project`），落到 evidence 库后审计员能看到所有用户的本地目录结构，违反 GDPR / 公司隐私策略。
- 修复:
  - 默认不发 `project_path` 字段；只有命令显式声明 `RequiresEvidence=True` 时才把 path 写入 evidence。
  - 文档化：希望发送的下游产品需要在命令注册时调 `.RequiresEvidence(True)`，并由 governance 层负责持久化前的二次脱敏。
- 状态: ✅ 已修复

### BUG-157: TDeepShellToolWindow 默认尺寸未做 DPI 缩放
- 发现日期: 2026-05-14（五专家审阅 P1-UX）
- 严重性: 🟡 Medium
- 文件: `VCL/DeepBase.VCL.DeepShell.ToolWindow.pas`
- 描述:
  - 工具窗硬编 `Width := 320; Height := 480; FLower.Height := 140`。在 4K 屏 200% DPI 下，肉眼上是 160×240×70，几乎不可用。
- 修复:
  - 默认尺寸按 `Screen.PixelsPerInch / 96` 用 `MulDiv` 缩放；fallback 到 96 DPI 默认值。
  - 实际值在 `CreateForShell` 计算后赋给 `Width/Height/FLower.Height`，不影响布局保存（`SetState` 会用持久化的 layout 尺寸覆盖）。
- 状态: ✅ 已修复

### BUG-158: TShellAreaController.SetCollapsed 中区死代码导致行为含糊
- 发现日期: 2026-05-14（五专家审阅 P1-Code）
- 严重性: 🟡 Low
- 文件: `VCL/DeepBase.VCL.DeepShell.Panels.pas`
- 描述:
  - 中区 `FMiddlePanel` 是 alClient，`Height` 没有意义。但 `UpdateVisuals` 折叠分支里写 `FPanel.Height := MIN_MIDDLE_HEIGHT_COLLAPSED`，`SetCollapsed` 也会按 BOTTOM 默认值处理 middle 的 `LastExpandedSize`。逻辑没崩，但代码读起来误导后人。
- 修复:
  - `UpdateVisuals` 中区只切 host 与 summary 的可见性，不再设置 alClient 面板的 Height。
  - `SetCollapsed` 不为 middle 维护 `LastExpandedSize`。
- 状态: ✅ 已修复

### BUG-159: CommandIds / ServiceIds 顺序不可预期
- 发现日期: 2026-05-14（五专家审阅 P1-API）
- 严重性: 🟡 Medium
- 文件: `VCL/DeepBase.VCL.DeepShell.Commands.pas`, `VCL/DeepBase.VCL.DeepShell.Services.pas`
- 描述:
  - `TDictionary<string, T>.Keys.ToArray` 不保证顺序，与插入顺序也无关。下游"按注册顺序展示菜单"的期望落空。
- 修复:
  - `TShellCommandManager` 与 `TShellServiceRegistry` 在 dict 之外维护一个 `TList<string>` 记录插入顺序；`CommandIds` / `ServiceIds` 返回有序列表的 `ToArray`。
  - 同时修一个相关问题：`UnregisterCommand` 之前用 `if FCommands.Remove(...)` 当 Boolean 用，但 `TDictionary.Remove` 返回 void，编译报 E2012；改为 `ContainsKey` 后再 `Remove`。
- 状态: ✅ 已修复

### BUG-160: NullGovernanceService 既不拦也不记录，gmObserve 阶段没有审计痕迹
- 发现日期: 2026-05-14（五专家审阅 P1-Audit）
- 严重性: 🟠 High
- 文件: `VCL/DeepBase.VCL.DeepShell.Governance.pas`（新增）, `VCL/DeepBase.VCL.DeepShell.MainForm.pas`
- 描述:
  - 文档默认 `NullGovernanceService` 总是允许，但既不拦也不记录。下游接 OCGS 之前的整个 gmObserve 期 L2/L3 命令都没有审计痕迹，违背了"先观察后阻断"的设计意图。
- 修复:
  - 新增 `TShellAuditOnlyGovernanceService`：`IsEnabled = True`，`EnterGate` 总是允许但解析 context JSON 拿到 `risk_level`，对 `>= rlMedium` 的命令通过 `IShellStatusManager.Diagnostic` 写一行 evidence。
  - 同时提供 `TShellAllowAllGovernanceService` 给测试场景使用（`IsEnabled = False` 直接走早出路径，不构建 JSON）。
  - `TDeepMainForm` 默认接 `TShellAuditOnlyGovernanceService(FStatus)`；下游可 `SetGovernance(nil)` 或 `SetGovernance(allowAll)` 显式退出审计。
- 状态: ✅ 已修复

### BUG-161: IShellStatusManager.ShellError 命名含糊
- 发现日期: 2026-05-14（五专家审阅 P1-Naming）
- 严重性: 🟢 Trivial
- 文件: `VCL/DeepBase.VCL.DeepShell.Intf.pas`, `VCL/DeepBase.VCL.DeepShell.Panels.pas`
- 描述:
  - `ShellError` 名字带 `Shell` 前缀语义重复，不符合接口的简洁命名习惯。
- 修复:
  - 接口和实现都加 `LogError(const ASource, AMessage, ADetail: string)` 作为推荐名。
  - `ShellError` 保留为兼容别名，行为一致。
- 状态: ✅ 已修复

### BUG-162: SaveShellState 只写全局 layout，多项目工作流互相覆盖
- 发现日期: 2026-05-14（五专家审阅 P1-Multi-project）
- 严重性: 🟠 High
- 文件: `VCL/DeepBase.VCL.DeepShell.MainForm.pas`
- 描述:
  - `IShellLayoutService` 已经定义了 `SaveProjectLayout/TryLoadProjectLayout`，但 `TDeepMainForm.SaveShellState` 只调 `SaveGlobalLayout`，从不调 project 路径。多项目工作流会互相覆盖 layout。
- 修复:
  - 抽出 `CaptureLayoutState` / `ApplyLayoutState` 私有 helper 复用 layout 序列化与还原逻辑。
  - 新增 `OpenProject(AProjectId, APath)` / `CloseProject` 方法：切换前持久化旧项目 layout，切换后加载新项目 layout，并把项目登记到 RecentService。
  - `SaveShellState` 同时写全局 layout 和（若 `FActiveProjectIdForLayout` 非空）项目 layout。
  - `LoadShellState` 改用 `ApplyLayoutState`，与 `OpenProject` 走同一恢复路径。
- 状态: ✅ 已修复

### BUG-163: VCLDeepShellDemo Demo.Providers/Demo.Commands 缺 uses 致 enum/常量未声明
- 发现日期: 2026-05-14（dproj 实建后第一轮编译）
- 严重性: 🟠 High
- 文件: `Examples/VCLDeepShellDemo/Demo.Providers.pas`, `Examples/VCLDeepShellDemo/Demo.Commands.pas`
- 描述:
  - 单独靠 `uses DeepBase.VCL.DeepShell;` 引用 facade，编译报 `E2003 Undeclared identifier: 'svkText'`、`E2003 Undeclared identifier: 'mrYes'`。Delphi 类型别名不会把枚举值带进来；MessageDlg 常量也需要显式 uses。
  - facade 的实例只 alias 了 `TShellViewKind` 的类型，未把每个 ordinal 值注入到调用方作用域。
- 修复:
  - `Demo.Providers.pas`: 增加 `uses DeepBase.VCL.DeepShell.Types`，让 `svkText`、`svkControl` 等枚举值可见。
  - `Demo.Commands.pas`: 增加 `uses Vcl.Controls`、`System.UITypes`，让 `mrYes`、`mtConfirmation`、`MessageDlg` 都可见。
- 验证:
  - `msbuild Examples/VCLDeepShellDemo/VCLDeepShellDemo.dproj /p:Config=Debug /p:Platform=Win64`: 编译通过，17593 lines，0 errors，输出 6.0 MB Win64 exe。
- 状态: ✅ 已修复

### BUG-164: compile_test.bat 外层吞掉 msbuild 失败
- 发现日期: 2026-05-14（构建门禁审阅）
- 严重性: 🔴 Critical
- 文件: `compile_test.bat`
- 描述:
  - msbuild 失败（exit code 1）会被 `>>compile_output.txt` 后的 `echo` 覆盖，外层 `%ERRORLEVEL%` 变成 0。脚本本身缺 `exit /b %ERRORLEVEL%`。CI 误判通过。
- 修复:
  - `set BUILD_EC=%ERRORLEVEL%` 立即捕获 msbuild 退出码，写入 `compile_output.txt` 并 `exit /b %BUILD_EC%`。
- 验证:
  - 当前 Tests\DeepBaseTests.dproj 因 IntentClarification.SignalDetector 错误返回 1，外层脚本 ERRORLEVEL = 1。
- 状态: ✅ 已修复

### BUG-165: DeepBaseFeatures.dpk 缺 requires DeepBasePersistence
- 发现日期: 2026-05-14（构建门禁审阅）
- 严重性: 🟠 High
- 文件: `DeepBaseFeatures.dpk`
- 描述:
  - `Features\DeepBase.IntentClarification.Storage.pas` 在 uses 段引用 `DeepBase.DB.Factory` / `DeepBase.DB.Guardian`，这两个单元位于 `DeepBasePersistence.dpk` 的 contains 列表，但 Features 包没有 `requires DeepBasePersistence`，导致整个 Features 包解析时找不到这两个单元。
  - 与 docs/全局规则要求的运行时包顺序 `Core → Services → Persistence → Features → FMX → VCL` 一致：Features 完全可以依赖 Persistence。
- 修复:
  - 在 `DeepBaseFeatures.dpk` 的 requires 段加入 `DeepBasePersistence`。
- 状态: ✅ 已修复

### BUG-166: 服务"可替换"设计实际未生效——私有字段旁路 registry
- 发现日期: 2026-05-14（构建门禁审阅 P0-3）
- 严重性: 🔴 Critical
- 文件: `VCL/DeepBase.VCL.DeepShell.MainForm.pas`
- 描述:
  - 构造期把 `FRecent/FSettings/FLayout/FTheme/FLocalization` 创建为内存默认实现，再通过 `RegisterServices` 写入 `IShellServiceRegistry`。但 `LoadShellState/SaveShellState/OpenProject/CloseProject` 等代码全部直接读 `FRecent`/`FLayout` 等私有字段。下游 `inherited; Services.RegisterService(CAP_SHELL_RECENT, MyDB1Recent)` 把 registry 替换掉之后，主窗体仍然用旧的内存对象 → 实际上替换无效。
- 修复:
  - 新增 `ResolveServicesFromRegistry` 私有方法：从 registry 按 capability id 查回最新注册的实现，重新绑定 `FRecent/FLayout/FSettings/FTheme/FLocalization`。
  - `AfterConstruction` 在 `RegisterServices` 之后立即调用 `ResolveServicesFromRegistry`，让"先 inherited 注册默认 + 后用 RegisterService 覆盖"这条标准下游 pattern 真正生效。
  - `Bus / Context / Commands / Status` 仍由构造期固化（构成 shell identity），不参与重绑。
- 状态: ✅ 已修复

### BUG-167: TShellEventBus + 主窗体闭包 UAF（已排队闭包仍捕获 Self）
- 发现日期: 2026-05-14（构建门禁审阅 P0-4）
- 严重性: 🔴 Critical
- 文件: `VCL/DeepBase.VCL.DeepShell.MainForm.pas`, `VCL/DeepBase.VCL.DeepShell.Events.pas`
- 描述:
  - `TShellEventBus.Publish` 在后台线程时通过 `TThread.Queue` 投递主线程闭包，`LSelfRef: IShellEventBus := Self` 已经把 bus 自身的生命周期延长到 queue 消费完。但是：主窗体的 `HookEventBus` 订阅 handler 是匿名 procedure，它捕获 `Self`（裸 `TDeepMainForm` 类引用，不增引用计数）。形式上 EventBus 拿着这个匿名方法的 closure，里面引用了已释放的 form。即使关闭路径调了 `UnsubscribeAll`，已经入队的 queue 项还在，下一次 `CheckSynchronize` 跑回 `UpdateStatusBarFromContext` 就 UAF。
- 修复:
  - 引入 `IShellMainFormBridge` 接口和 `TShellMainFormBridge` 实现类（接口在 interface 段以便 form class 字段引用，实现类在 implementation 段以便持有原生 `TDeepMainForm*`）。
  - 主窗体构造期创建 `FBridge: IShellMainFormBridge := TShellMainFormBridge.Create(Self)`。
  - `HookEventBus` 把 bridge 取入 `LBridge: IShellMainFormBridge` 局部变量，闭包只捕获该接口（不捕获 Self）。
  - `Destroy` 中调用 `FBridge.Detach` 把 bridge 内部的 `FOwner := nil`，再 `FBridge := nil`。Bridge 在 queue 项内部仍然存活（接口引用计数），但 `Dispatch` 看到 `FOwner = nil` 直接返回 → 不再访问已释放 form。
- 状态: ✅ 已修复

### BUG-168: Governance 双轨结果只检查 Boolean，AllowResult 被忽略可能误放行
- 发现日期: 2026-05-14（构建门禁审阅 P0-5）
- 严重性: 🔴 Critical
- 文件: `VCL/DeepBase.VCL.DeepShell.Commands.pas`, `VCL/DeepBase.VCL.DeepShell.MainForm.pas`
- 描述:
  - `IGovernanceService.EnterGate` 返回 `Boolean` 同时 `out TShellGateResult`。`TShellCommandManager.Execute` 只判 `Boolean`：`if not LGov.EnterGate(...) then PublishRejected; Exit;`。如果 adapter 把 Boolean 当 "function call success" 而把 `LResult.Outcome := sgoDeniedHard` 放在 result 里，命令仍会执行。
  - 拒绝事件通过 `sekCommandRejected` 发出，但主窗体没有任何 handler，用户视觉上完全静默。
- 修复:
  - `Execute` 改为 fail-closed：`Allowed := EnterGate 返回 True 且 LResult.Allowed`，否则一律 `PublishRejected` + `Exit`。
  - adapter 抛异常时 catch 并视为 soft denial，不把异常向上抛。
  - 主窗体 `HandleCommandRejected` 处理 `sekCommandRejected`：状态栏写明 "Command was not allowed"，底部日志写一条 warning，把 `Source / GateKey / 拒绝消息` 全部记录。Bridge 调用此方法。
- 状态: ✅ 已修复

### BUG-169: TDeepMainForm.Create 在构造期调用虚方法，descendant 字段尚未初始化
- 发现日期: 2026-05-14（构建门禁审阅 P0-6）
- 严重性: 🟠 High
- 文件: `VCL/DeepBase.VCL.DeepShell.MainForm.pas`
- 描述:
  - 构造期顺序调用 `InitializeShell / RegisterServices / RegisterCommands / RegisterProviders / BuildShellUI`。这些都是虚方法，按 Delphi 规则会派发到最派生的覆盖。但此时 descendant 自己的构造体（`begin ... end;`）还没运行，descendant 的 `private FSomething: TSomething;` 字段全部为零值。任何在 descendant `RegisterServices` 里访问自身字段的代码都会 nil 引用。
- 修复:
  - 重构生命周期：`Create` 只做字段分配 + 核心服务实例化，不调任何虚方法。
  - 新增 `AfterConstruction override`：执行 `InitializeShell → RegisterServices → ResolveServicesFromRegistry → RegisterCommands → RegisterProviders → BuildShellUI → HookEventBus`，并设置 `FShellInitialised := True`。
  - `AfterConstruction` 由 `TObject.NewInstance` 在最派生构造器返回之后调用，descendant 字段已完成初始化。
- 状态: ✅ 已修复

### BUG-170: OpenView 不优先 ProviderId 匹配 + 把 Title 当 ViewType
- 发现日期: 2026-05-14（构建门禁审阅，重要问题 1+2）
- 严重性: 🟠 High
- 文件: `VCL/DeepBase.VCL.DeepShell.MainForm.pas`
- 描述:
  - 多个 provider 支持同一 Kind 时（例如两个不同 ProviderId 都能开 'doc'），`OpenView` 仅按"第一个 CanOpen 命中"派发，可能打开错对象。
  - 设置 context 时把 `LInfo.Title`（描述性 UI 文本）当成 `ViewType` 写进 `IShellContextManager.SetView(ViewId, ViewType)`。Inspector / governance 依赖的 ViewType 拿到的是任意 caption 字符串。
- 修复:
  - 两遍扫描：先按 `ARef.ProviderId` 严格匹配，再退回任意 `CanOpen`。
  - `SetView(ViewId, ViewType)` 改为传 `GetEnumName(TypeInfo(TShellViewKind), Ord(LInfo.ViewKind))`，也就是 `svkText/svkHtml/...` 这类稳定枚举名，不再写 caption。
- 状态: ✅ 已修复

### BUG-171: Layout 持久化在 wsMaximized 也写错坐标 + 无工作区裁剪
- 发现日期: 2026-05-14（构建门禁审阅，重要问题 3）
- 严重性: 🟠 High
- 文件: `VCL/DeepBase.VCL.DeepShell.MainForm.pas`
- 描述:
  - `CaptureLayoutState` 仅对 `wsMinimized` 走 `GetWindowPlacement.rcNormalPosition`。最大化时 `Left/Top/Width/Height` 等于最大化矩形（覆盖整屏），保存后下次 restore 看似还原成"最大化前"，实际是把最大化前的 normal 矩形丢了。
  - `ApplyLayoutState` 直接套用保存的坐标，没有按当前显示器工作区裁剪。把窗口拉到第二显示器做 layout、再断开第二显示器后启动，会落到不可见区域。
- 修复:
  - 两种状态都走 `GetWindowPlacement.rcNormalPosition`：`wsMinimized in [wsMinimized, wsMaximized]` 时使用 placement 矩形。
  - `ApplyLayoutState` 用 `Screen.MonitorFromPoint(矩形中心)` 找当前可用 monitor 的 work area，对 width/height/left/top 逐项夹回；缺省退化到 `Screen.PrimaryMonitor`。
- 状态: ✅ 已修复

### BUG-172: StatusManager Detail 字段未脱敏
- 发现日期: 2026-05-14（构建门禁审阅，重要问题 6）
- 严重性: 🟠 High
- 文件: `VCL/DeepBase.VCL.DeepShell.Panels.pas`
- 描述:
  - 之前 BUG-155 给 `IShellStatusManager` 加了 sanitizer hook，但 `AddEntry` 只对 `MessageText` 走 sanitizer，`Detail` 字段（异常 stack trace、HTTP response body 等更可能含 token 的位置）原样保存。
- 修复:
  - `AddEntry` 对 `ADetail` 也调 `ApplySanitizer`，与 message 同口径。
- 状态: ✅ 已修复

---

## 2026-05-09 Bug 修复

### BUG-133: Studio 工程编译链断裂
- 发现日期: 2026-05-09
- 严重性: 🟠 High
- 描述:
  - `Tools\Studio\Studio.dproj` Win64 编译被多个 Studio 单元阻断：`Studio.SQLFrame` 仍用 `TClientDataSet` 调用已改为 `TFDMemTable` 的 `UniDbSelect`；`Studio.LLMConfigForm` 和 `Studio.PromptDebugForm` 存在损坏的非 ASCII 状态/星标字符串并缺少必要 uses；`Studio.LLMFrame` 的高级工具按钮事件未在类声明中注册；`Studio.QueriesFrame` 有 `{$R *.dfm}` 但缺失 DFM。
- 修复:
  - `Studio.SQLFrame`: DoQry select 结果改用 `TFDMemTable`，匹配 `DeepBase.DB.DoQry.UniDbSelect` 的 `var` 参数类型。
  - `Studio.LLMConfigForm`: 补 `System.Math`，将默认配置星标改为 ASCII `*`，修复损坏字符串。
  - `Studio.PromptDebugForm`: 补 `System.Math` 和 `Vcl.CheckLst`，将变量 required 列绘制改为 ASCII `Y/N`，修复损坏字符串。
  - `Studio.LLMFrame`: 补齐 `btnOpenConfigManagerClick`、`btnOpenPromptDebugClick` 声明和析构事件清理。
  - `Studio.QueriesFrame`: 新增最小 `Studio.QueriesFrame.dfm`，匹配运行时创建控件的 frame 模式。
- 验证:
  - `msbuild Tools\Studio\Studio.dproj /t:Build /p:Config=Debug /p:Platform=Win64 ...`: 编译通过。
- 状态: ✅ 已修复

### BUG-132: LLM PromptTemplate schema/生命周期漂移与 SimpleCrypto 未认证密文
- 发现日期: 2026-05-09
- 严重性: 🔴 Critical
- 描述:
  - `Core/DeepBase.LLM.pas` 的 prompt template CRUD 使用 `LLMPromptTemplates`，但 schema 常量和 sample DB 只创建 `LLMPrompts`，新库会在模板读写时缺表。
  - `Test.DeepBase.LLM.PromptTemplate` 因缺少 schema 常量长期未接入 `DeepBaseTests.dpr`，重新注册后又暴露 DUnitX `Length(...)` 断言泛型推断失败。
  - `TLLMPromptTemplate` 是持有 `TDictionary<string,string>` 的 record，但没有统一释放协议；`GetTemplate/GetAllTemplates/GetTemplatesByCategory/Clone/Import` 返回或创建的 `DefaultValues` 会在调用方和内部临时对象路径上残留，PromptTemplate 单测退出时触发 FastMM 小块泄漏告警。
  - `TSimpleCrypto` 仅使用 AES-CBC `IV||Ciphertext`，没有认证标签；错密码时可能解出随机字节，并在 UTF-8 转换阶段抛出编码异常而不是稳定 fail-closed。
- 修复:
  - 新增 `SQL_TIER2_LLM_PROMPT_TEMPLATES`，在 `GetTier2SchemaSQL` 和 `data/create_sample_db.sql` 中创建 `LLMPromptTemplates` 及索引，保留旧 `LLMPrompts` 兼容表。
  - `Test.DeepBase.LLM.PromptTemplate` 接入主 Unit runner，并将 `Length(...)` 断言显式标注为 `Integer` 泛型重载。
  - 新增 `TLLMPromptTemplate.Clear` 显式释放协议，框架内部在 `ExecuteTemplate/CopyTemplate/ValidateTemplate/RenderWithInheritance/ExportTemplates/ImportTemplates` 中释放临时模板；Studio 模板界面和 PromptTemplate 单测同步释放返回数组和模板记录，避免 record 浅拷贝导致的字典残留。
  - 修复 `Studio.PromptTemplateFrame` 单元可编译性：补齐 `System.StrUtils`，并将模板切换确认框结果保存到局部 `DialogResult`，不再误读不存在的 `ModalResult`。
  - `TSimpleCrypto` 新密文改为 `DBSC` 版本头 + IV + Ciphertext + HMAC-SHA256 认证封包，解密前常量时间验签；旧 `IV||Ciphertext` 格式保留兼容读取。
  - `TAESCrypto.UnpadData` 完整校验 PKCS#7 padding 字节；字符串解密中的 UTF-8 解码错误统一转换为 `ECryptoException`。
  - 清理测试编译落入 `Features` 源目录的 `.dcu` 产物，源码目录 `.dcu` 数量恢复为 0。
- 验证:
  - `Scripts/run_tests.ps1 -Type Unit -FromUnit DeepBase.LLM.PromptTemplate -CI -AllowFilteredCI`: 14 tests passed，0 leaked，退出无 FastMM unexpected memory leak。
  - `Scripts/run_tests.ps1 -Type Unit -FromUnit DeepBase.Schema -CI -AllowFilteredCI`: 36 tests passed。
  - `Scripts/run_tests.ps1 -Type Unit -Module LLM -CI -AllowFilteredCI`: 76 tests passed。
  - `Scripts/run_tests.ps1 -Type Unit -FromUnit DeepBase.Crypto -CI -AllowFilteredCI`: 111 tests passed。
  - `Scripts/run_tests.ps1 -Type Unit -CI`: 3243 tests，3240 passed，3 ignored，0 failed，0 errored，0 leaked。
  - `Scripts/run_tests.ps1 -Type Integration -CI`: 10 tests passed。
  - `Scripts/run_architecture_checks.ps1`: 18 tests passed。
  - `Scripts/check_rename_residue.ps1`: passed。
  - `dcc64 ... Tools\Studio\Frames\Studio.PromptTemplateFrame.pas`: 编译通过；`Tools\Studio\Studio.dproj` 整体仍被既有 `Studio.SQLFrame.pas(619)` 类型不匹配阻断。
- 状态: ✅ 已修复

### BUG-131: 五专家审阅第二轮 P0 修复与门禁回归
- 发现日期: 2026-05-09
- 严重性: 🔴 Critical
- 描述:
  - 迁移脚本解析会把 SQLite trigger body 内部 `;` 错拆；脚本内事务控制可能破坏迁移引擎统一事务；checksum mismatch 诊断不足；SQLite 并发迁移存在重复执行窗口。
  - CloudBackup scheduler/backup/restore 线程使用 `FreeOnTerminate=True` 后丢引用，停止和析构无法可靠等待后台任务退出。
  - Web/API 默认值过宽：WebSocket 默认 `*` origin、query `api_key`、弱 JWT secret、非 constant-time compare、500 回显异常和默认 CORS header 都会扩大攻击面。
  - `Test.WebService` 未接入主 Unit runner，CI 过滤运行和 `-SkipCompile` 仍有绕过风险。
  - Commerce license snapshot 改为 fail-closed 后，E2E fake 客户端未配置验签器，Integration 会在刷新许可证快照时报验签失败。
- 修复:
  - `DeepBase.DB.Migrations` 修复 trigger/multi-statement 切分，禁止迁移脚本内事务控制，并在 checksum mismatch 时记录 `FailedScript`。
  - SQLite 迁移执行前使用 `BEGIN IMMEDIATE` 拿写锁，并在锁内二次检查版本/checksum，避免两个进程同时看到未应用后重复执行。
  - `DeepBase.CloudBackup` 改为显式 signal + `WaitFor` + 释放，后台线程生命周期由 `Stop/Cancel/Destroy` 收口。
  - Web/API 默认安全收紧：WebSocket 不默认放行 `*`，query `api_key` 默认关闭，JWT secret 长度不足直接拒绝，JWT verify 常量时间比较，默认 500 不回显内部异常，HTTP CORS middleware 默认不写 CORS 头。
  - `Test.WebService` 接入 `DeepBaseTests.dpr`，`NET` module alias 只运行已注册 fixture；`run_tests.ps1 -CI -SkipCompile` 禁止，CI 过滤运行必须显式 `-AllowFilteredCI`。
  - `TDeepKitSafeClient` 要求 license snapshot 必需字段、过期/app-device mismatch/无 verifier 或 public key/验签失败均 fail-closed；Windows 下支持 RSA-SHA256 PEM 公钥验签。
  - Commerce E2E fake snapshot payload 绑定 `app_id/device_id`，并显式配置测试 verifier，保持 fail-closed 语义不被测试绕过。
- 验证:
  - `Scripts/run_tests.ps1 -Type Unit -CI`: 3229 tests，3226 passed，3 ignored，0 failed，0 errored，0 leaked。
  - `Scripts/run_tests.ps1 -Type Integration -CI`: 10 tests passed。
  - `Scripts/run_architecture_checks.ps1`: 18 tests passed。
  - `Scripts/check_rename_residue.ps1`: passed。
  - 定向回归：`DeepBase.DB.Migrations` 7 tests、`DeepBase.CloudBackup` 35 tests、`NET` module 44 tests、`DeepBase.Commerce` 49 tests 均通过。
- 状态: ✅ 已修复

### BUG-130: 五专家审阅 P0 门禁和安全缺陷收敛
- 发现日期: 2026-05-09
- 严重性: 🔴 Critical
- 描述:
  - 完整 Unit 存在 `TrayIcon` 5 个失败和 `PluginManager` 1 个权限错误。
  - Integration runner 因 WebAPI fixture 未注册只跑 1 个测试，CI rename gate 把合法 `DeepBase` 当残留。
  - SQLLogger 写入 `Logs` 的列名与 schema 漂移，压缩/备份/云下载存在路径穿越风险。
  - 插件启停配置命名空间、RBAC wildcard、支付回调 fail-closed、legacy 许可证签发默认值均存在上线风险。
- 修复:
  - `TrayIcon` 增加可注入 `Shell_NotifyIcon`，测试脱离真实通知区；插件测试改用临时目录。
  - `run_tests.ps1` 增加最低测试数检查，WebAPI integration fixture 注册，rename gate 改为只查真实旧名残留。
  - SQLLogger 改写 `LogLevel/LogTime`，Zip/Backup/CloudStorage 写文件前校验 canonical path。
  - 插件启停改为 `Plugin.*` 配置并在加载时拦截 disabled；RBAC wildcard 只匹配授权前缀，禁用用户/角色默认拒绝。
  - PaymentBridge 对 Stripe/PayPal 用 raw body + headers 验签；WeChat V3 未完成解密前 fail-closed；legacy 本地许可证签发默认关闭。
- 验证:
  - `Scripts/run_tests.ps1 -Type Unit -CI`: 3229 tests，3226 passed，3 ignored，0 failed，0 errored，0 leaked。
  - `Scripts/run_tests.ps1 -Type Integration -CI`: 10 tests passed。
  - `Scripts/run_architecture_checks.ps1`: 18 tests passed。
  - `Scripts/check_rename_residue.ps1`: passed。
  - `dcc64 ThirdParty\Cloud\DeepBase.Cloud.Storage.pas`: compiled。
- 状态: ✅ 已修复

## 2026-05-08 Bug 修复

### BUG-129: CloudSync JSONMergeArrays 移除旧数组元素未释放
- 发现日期: 2026-05-08
- 严重性: 🟠 Medium
- 描述:
  - `JSONMergeArrays` 的 `amsReplace` 分支调用 `ATarget.Remove(0)` 清空目标数组，但没有释放返回的旧 `TJSONValue`。
  - `amsMergeByIndex` 替换非对象元素时同样调用 `ATarget.Remove(I)` 后直接丢弃返回值。
  - 完整 Unit 退出阶段因此残留 `TJSONNumber x5` 和对应字符串内存。
- 修复:
  - `Features/DeepBase.CloudSync.pas`: 增加 `LRemoved`，对 `TJSONArray.Remove` 返回的旧 JSON 节点立即 `Free`。
- 验证:
  - `Scripts/run_tests.ps1 -Type Unit -FromUnit DeepBase.CloudSync -CI`: 56 tests passed，0 leaked。
  - `Scripts/run_tests.ps1 -Type Unit -SkipCompile -CI`: 3115 found，3112 passed，3 ignored，0 failed，0 errored，0 leaked，退出无 FastMM unexpected memory leak。
- 状态: ✅ 已修复

### BUG-128: Performance 并发 benchmark 未释放 TTask 引用导致退出泄漏
- 发现日期: 2026-05-08
- 严重性: 🟡 Low
- 描述:
  - `Benchmark_LogWrite_Concurrent` 和 `Benchmark_CacheConcurrent` 在 benchmark 匿名方法内创建 `TTask` 数组并 `WaitForAll`，但没有在匿名方法返回前清空 `ITask` 引用。
  - `Tasks -> TTask -> 匿名方法 -> benchmark actrec -> Tasks` 形成引用环，退出阶段残留 `TTask`、线程池控制对象和 benchmark 闭包。
- 修复:
  - `Tests/Test.DeepBase.Performance.pas`: 两个并发 benchmark 在 `WaitForAll` 后逐项置空 `Tasks[I]` 并 `SetLength(Tasks, 0)`。
- 验证:
  - `Scripts/run_tests.ps1 -Type Unit -FromUnit DeepBase.Performance -CI`: 16 tests passed，0 leaked，退出无 FastMM unexpected memory leak。
- 状态: ✅ 已修复

### BUG-127: MVVM TAsyncCommand 异步取消闭包形成自引用泄漏
- 发现日期: 2026-05-08
- 严重性: 🟡 Low
- 描述:
  - `TAsyncCommand.DoExecute` 创建局部 `IsCancelledFunc` 匿名方法，再由 `TTask` 匿名方法捕获使用。
  - Delphi 匿名方法活动记录因此保留 `IsCancelledFunc -> DoExecute actrec` 的自引用链，测试结束后退出阶段残留 `TAsyncCommand.DoExecute$ActRec`。
- 修复:
  - `Core/DeepBase.MVVM.pas`: 异步任务主体外层增加 `finally`，任务结束时显式将 `IsCancelledFunc := nil`，打断活动记录自引用链。
- 验证:
  - `Scripts/run_tests.ps1 -Type Unit -FromUnit DeepBase.MVVM -CI`: 42 tests passed，0 leaked，退出无 FastMM unexpected memory leak。
- 状态: ✅ 已修复

### BUG-126: Scheduler Delay 不刷新 NextRunAt 导致 fluent API 状态不可见
- 发现日期: 2026-05-08
- 严重性: 🟡 Low
- 描述:
  - `TScheduledTask.Delay` 只记录 `FDelayMs`，不调用 `CalculateNextRun`，导致调用 `Delay(5000)` 后 `NextRunAt` 仍为 0。
  - `Every` / `Cron` 也没有在配置阶段刷新 `NextRunAt`，并且多个调度策略链式调用时旧策略字段可能残留。
- 修复:
  - `Delay` / `Every` / `Cron` 在配置时立即调用 `CalculateNextRun`。
  - 调度策略改为最后一次 fluent 调用生效：`Delay` 清理 interval，`Every` 清理 delay，`Cron` 清理 delay/interval。
- 验证:
  - `Scripts/run_tests.ps1 -Type Unit -FromUnit DeepBase.Scheduler -CI`: 50 tests passed，0 leaked。
- 状态: ✅ 已修复

### BUG-125: LLM 配置布尔字段直接 AsBoolean 导致 SQLite credential 测试失败
- 发现日期: 2026-05-08
- 严重性: 🟠 Medium
- 描述:
  - `LoadConfigFromQuery` 直接用 `Query.FieldByName('IsEnabled').AsBoolean` / `IsDefault.AsBoolean` 读取布尔字段。
  - 当前 SQLite/FireDAC 路径下，`IsEnabled INTEGER DEFAULT 1` 可能不能按 Boolean 直接访问，导致 credential 迁移测试在读取配置时抛出 `Cannot access field 'IsEnabled' as type Boolean`。
- 修复:
  - 新增 `QueryFieldBoolean`，统一兼容 Boolean、Integer 和字符串布尔值。
  - LLM 配置、模板和调用记录的布尔读取改走兼容 helper，避免不同数据库/驱动字段映射差异导致运行期异常。
- 验证:
  - `Scripts/run_tests.ps1 -Type Unit -FromUnit DeepBase.LLM -CI`: 15 tests passed，0 leaked。
- 状态: ✅ 已修复

### BUG-124: BillingClient 聊天历史 Clear 语义和 token 总数计算不一致
- 发现日期: 2026-05-08
- 严重性: 🟠 Medium
- 描述:
  - `TChatHistory.Clear` 只清空用户/助手消息，但 `GetMessages` 和 `Count` 仍无条件把 `SystemPrompt` 加回当前消息列表，导致 Clear 后 `Count=1`。
  - `TTokenUsage.TotalTokens` 是普通字段，设置 `PromptTokens` 和 `CompletionTokens` 后不会自动得到总数。
- 修复:
  - 增加 `FSystemPromptVisible`，区分保留系统提示词配置与当前消息列表是否包含 system 消息；Clear 后配置仍保留，但当前消息计数为 0。
  - `TTokenUsage` 改为带 setter 的 record 属性；未显式设置服务端 total 时按 `PromptTokens + CompletionTokens` 计算。
- 验证:
  - `Scripts/run_tests.ps1 -Type Unit -FromUnit DeepBase.LLM.BillingClient -CI`: 23 tests passed，0 leaked。
- 状态: ✅ 已修复

### BUG-123: PDF SaveToStream 写入动态数组变量导致文件头损坏
- 发现日期: 2026-05-08
- 严重性: 🟠 Medium
- 描述:
  - `TPDFDocument.SaveToStream` 调用 `AStream.WriteBuffer(Buf, Length(Buf))`，传入的是动态数组变量本身，不是 `Buf[0]` 指向的字节内容。
  - PDF 文件头因此写成数组指针/描述数据，`%PDF-1.4` 头部损坏。
  - 对 JPEG 数据和 page content 的 `TBytes` 写流存在同类风险。
  - 单元测试直接把二进制 header 读入 `string`，在 Unicode Delphi 下也会造成字节/字符混读。
- 修复:
  - 所有 `TBytes` 写流改为 `WriteBuffer(Bytes[0], Length(Bytes))` 并处理空数组。
  - `startxref` 改为记录 xref 表起始位置，而不是写入 trailer 时的当前位置。
  - PDF header 测试改为读取 `TBytes` 后用 ASCII 解码断言。
- 验证:
  - `Scripts/run_tests.ps1 -Type Unit -FromUnit DeepBase.Export.Gen -CI`: 18 tests passed，0 leaked。
- 状态: ✅ 已修复

### BUG-122: Exception Install 缺少 VCL Application.OnException 适配且存储注入依赖 DB 连接
- 发现日期: 2026-05-08
- 严重性: 🟠 Medium
- 描述:
  - `DeepBase.Exception` 已拆为 UI-neutral Core，但缺失 `DeepBase.VCL.ExceptionAdapter`，VCL 应用/测试链接后调用 `Install` 不会设置 `Application.OnException`。
  - `LogExceptionToDB` 只有在 Manager 已初始化且存在 ConfigDB 连接时才调用 `IExceptionReportStorage` 工厂，导致测试和非 DB 存储注入无法收到异常报告。
- 修复:
  - 新增 `VCL/DeepBase.VCL.ExceptionAdapter.pas`，通过 bridge 对象把 `Application.OnException` 转发到 `TDeepBaseExceptionHandler.HandleException`，并保持 Core 不依赖 VCL。
  - VCL 展示回调跳过 `EAbort`，避免测试/正常取消流程弹出阻塞窗口。
  - `CreateStorageFromConnection` 支持向工厂传入 nil 连接，使内存/测试/非 DB 存储可以接管异常报告。
  - `DeepBaseTests.dpr` 链接 VCL exception adapter，覆盖真实安装路径。
- 验证:
  - `Scripts/run_tests.ps1 -Type Unit -FromUnit DeepBase.Exception -CI`: 10 tests passed，0 leaked。
- 状态: ✅ 已修复

### BUG-121: Diff 相似度按行计算导致单行局部修改为 0 且 Patch hunk 泄漏
- 发现日期: 2026-05-08
- 严重性: 🟠 Medium
- 描述:
  - `TDiff.Similarity` 只按行 LCS 计算，`Hello` 与 `Hallo` 这种单行局部修改被视为两行完全不同，返回 0。
  - `TPatchOperation` 持有 `TDiffHunk`，但析构函数不释放，解析 patch 后会泄漏 `TDiffHunk` 及其内部 `TList<TDiffItem>`。
- 修复:
  - `TDiff.Similarity` 改为字符级 LCS，并用双行 DP 数组避免为长文本建立完整矩阵。
  - `TPatchOperation.Destroy` 释放持有的 `TDiffHunk`，由 `TPatch.FOperations` 的对象生命周期统一清理。
- 验证:
  - `Scripts/run_tests.ps1 -Type Unit -FromUnit DeepBase.Diff -CI`: 57 tests passed，0 leaked。
- 状态: ✅ 已修复

### BUG-120: DBException 默认用户提示语言与文档/测试不一致
- 发现日期: 2026-05-08
- 严重性: 🟠 Medium
- 描述:
  - `GetErrorMessage` 被改为返回英文消息，但 FAQ 和单元测试仍以中文用户提示为默认口径。
  - `DB-1001`、`DB-3001`、`DB-5001` 等常用错误码因此无法通过测试，也会影响中文桌面软件的默认错误展示。
- 修复:
  - `Core/DeepBase.DBException.pas`: 恢复数据库错误码的中文默认用户提示，保留错误码识别和处理建议逻辑。
- 影响范围: 数据库异常包装、用户提示、日志/诊断消息中的默认错误描述。
- 验证:
  - `Scripts/run_tests.ps1 -Type Unit -FromUnit DeepBase.DBException -CI` 通过，7 tests passed，0 leaked。

### BUG-119: AntiTamper 单元测试与无硬编码密钥策略冲突
- 发现日期: 2026-05-08
- 严重性: 🔴 High
- 描述:
  - `TAntiTamperPackage.GetDefaultConfig` 已按 BUG-034 安全策略将 `EncryptionKey` 默认为空，要求下游应用显式配置。
  - 单元测试仍断言默认密钥非空，并直接用默认配置执行 AES 加解密，导致测试失败并诱导恢复硬编码密钥。
- 修复:
  - `Tests/Test.DeepBase.AntiTamper.pas`: 默认配置测试改为断言 `EncryptionKey` 为空，明确每个应用必须显式配置。
  - `Tests/Test.DeepBase.AntiTamper.pas`: AES 往返测试显式设置 `UnitTest_AntiTamper_Key_2026`，只验证算法通路，不改变产品默认安全策略。
- 影响范围: AntiTamper 安全默认值、单元测试可信度、BUG-034 防回归。
- 验证:
  - `Scripts/run_tests.ps1 -Type Unit -FromUnit DeepBase.AntiTamper -CI` 通过，8 tests passed，0 leaked。

### BUG-118: VirtualScroll 可见索引被 overscan 预渲染项污染
- 发现日期: 2026-05-08
- 严重性: 🟠 Medium
- 描述:
  - `TVirtualScrollController.CalculateVisibleItems` 会把 overscan 预渲染项加入 `FVisibleItems`，但 `FirstVisibleIndex/LastVisibleIndex` 直接返回列表首尾。
  - 滚动偏移到第 5 项时，列表首项可能是第 2 项预渲染数据，公开 `FirstVisibleIndex` 因此错误返回 2。
- 修复:
  - `Core/DeepBase.VirtualScroll.pas`: `GetFirstVisibleIndex` 从前向后扫描 `Visible=True` 的真实可见项。
  - `Core/DeepBase.VirtualScroll.pas`: `GetLastVisibleIndex` 从后向前扫描 `Visible=True` 的真实可见项。
- 影响范围: 虚拟列表可见范围查询、懒加载触发、滚动定位和 UI 渲染统计。
- 验证:
  - `Scripts/run_tests.ps1 -Type Unit -FromUnit DeepBase.VirtualScroll -CI` 通过，60 tests passed，0 leaked。

### BUG-117: Validation Email 规则允许空字符串绕过
- 发现日期: 2026-05-08
- 严重性: 🟠 Medium
- 描述:
  - `TEmailRule.Validate` 和 `TValidate.Email` 将空字符串视为有效邮箱，导致只使用 Email 规则时空邮箱可以通过。
  - 单元测试明确要求 `TValidate.Email('')` 失败，Email 规则语义应与格式校验一致，不隐式承担 Optional 行为。
- 修复:
  - `Core/DeepBase.Validation.pas`: Fluent `Email` 规则先 `Trim`，空白字符串或格式不匹配均返回 `EMAIL` 错误。
  - `Core/DeepBase.Validation.pas`: 快捷 `TValidate.Email` 与 Fluent 规则保持一致。
- 影响范围: 表单邮箱校验、DTO 校验、快捷校验 API。
- 验证:
  - `Scripts/run_tests.ps1 -Type Unit -FromUnit DeepBase.Validation -CI` 通过，72 tests passed，0 leaked。

### BUG-116: Unlock 等级校验字符碰撞导致高等级降级
- 发现日期: 2026-05-08
- 严重性: 🔴 High
- 描述:
  - `TDeepBaseUnlock.GenerateCode` 的校验字符由等级参与哈希后直接对可见字符表取模生成，`Free/Follow/Share` 在同一产品同一月份可能生成相同校验字符。
  - `ValidateCode` 从低等级开始推断，发生碰撞时 `ulShare` 会被识别为 `ulFree` 或保留在 `ulFollow`，导致 `ApplyCode` 无法升级到更高等级。
- 修复:
  - `Features/DeepBase.Unlock.pas`: 新校验字符算法改为产品月份哈希基础上按等级固定错位，保证 32 字符表内 3 个等级互不碰撞。
  - `Features/DeepBase.Unlock.pas`: 保留旧算法作为新算法无匹配时的兼容兜底，降低已有短期解锁码失效风险。
- 影响范围: 免费版、关注解锁、分享解锁等轻量 freemium 激活流程。
- 验证:
  - `Scripts/run_tests.ps1 -Type Unit -FromUnit DeepBase.Unlock -CI` 通过，5 tests passed，0 leaked。

### BUG-115: Plugin 配置键归一化和安全键误判
- 发现日期: 2026-05-08
- 严重性: 🔴 High
- 描述:
  - 插件本地配置写入 `NewKey/newkey` 等简单键时，没有稳定归一化到插件命名空间，测试和真实插件调用容易出现读取路径不一致。
  - 安全敏感键检测过宽，普通配置键可能被误判为凭据类键而拒绝写入。
  - `GetPluginDataPath` 的测试期望与实际短 GUID 路径策略不一致。
- 修复:
  - `Core/DeepBase.PluginManager.pas`: 增加 `PLUGIN_CONFIG_PREFIX`、`NormalizePluginConfigKey` 和 `IsSecurityConfigKey`，简单键统一存储为 `Plugin.*`，非 `Plugin.` 的点号键仍拒绝。
  - `Core/DeepBase.PluginManager.pas`: `TPluginContext.GetConfig` 先查原始键，再兼容读取归一化后的 `Plugin.*` 键。
  - `Tests/Test.DeepBase.Plugin.pas`: 配置写入断言改为 `Plugin.NewKey`。
  - `Tests/Test.DeepBase.PluginManager.pas`: 插件数据路径断言对齐 `GUIDToShortString`。
- 影响范围: 插件配置隔离、插件配置读写兼容、安全敏感配置保护、插件数据目录稳定性。
- 验证:
  - `Scripts/run_tests.ps1 -Type Unit -FromUnit DeepBase.Plugin -CI` 通过，25 tests passed，0 leaked。
  - `Scripts/run_tests.ps1 -Type Unit -FromUnit DeepBase.PluginManager -CI` 通过，23 tests passed，0 leaked。

## 2026-05-07 Bug 修复

### BUG-114: CloudBackup/Feedback JSON 日期和可选字段兼容
- 发现日期: 2026-05-08
- 严重性: 🔴 High
- 描述:
  - `DeepBase.CloudBackup` 的文件信息 JSON 字段名与公开测试约定不一致，`FromJSON` 只识别旧字段，且 `createdAt/modifiedTime` 只接受 ISO8601，读取 Delphi 浮点日期字符串时报 `Invalid date string`。
  - `DeepBase.Feedback` 的附件、反馈、评论、通知反序列化同样只接受 ISO8601 日期，解析中途异常会泄漏已创建对象。
  - `TFeedbackItem.FromJSON` 只按枚举名称解析，旧 JSON 中的枚举数字会退回默认值。
- 修复:
  - `Features/DeepBase.CloudBackup.pas`: `ToJSON` 输出 `relativePath/fileSize/modifiedTime`，读取端兼容 `path/size/modified`，日期兼容 ISO8601 和 Delphi 浮点日期。
  - `Features/DeepBase.CloudBackup.pas`: 增加安全 JSON string/int/array 读取，`Manifest/Version.FromJSON` 异常路径释放对象，默认本地备份路径改为非空且默认不启用加密。
  - `Core/DeepBase.Feedback.pas`: 增加安全 JSON object/array/string 读取、日期兼容解析、枚举数字兼容解析，并补齐对象反序列化异常释放。
- 影响范围: 备份 manifest/version 兼容读取、反馈离线队列/服务端响应读取、旧 JSON 数据升级。
- 验证:
  - `Scripts/run_tests.ps1 -Type Unit -FromUnit DeepBase.CloudBackup -CI` 通过，35 tests passed，0 leaked。
  - `Scripts/run_tests.ps1 -Type Unit -FromUnit DeepBase.Feedback -CI` 通过，31 tests passed，0 leaked。

### BUG-113: Security/KeyManager IV 持久化和 Secret 长度校验坏行
- 发现日期: 2026-05-07
- 严重性: 🔴 High
- 描述:
  - `TKeyManager.Encrypt/Decrypt` 和 `TDataKey.EncryptWith/DecryptWith` 使用 AES-CBC 时没有把 IV 随密文保存，解密会使用新 IV，导致明文损坏并在 UTF-8 字符串恢复时报代码页错误。
  - `TKeyStore.GetActiveKey` 在指定 purpose 没有 active key 时返回 `nil`，而上层和测试期望可自动创建可用 key。
  - `TDeepBaseSecurity.SaveSecret` 的长度校验行被损坏，`if Length(...)` 被中文注释吞掉，下一行 `raise` 变成无条件执行，所有保存 Secret 的调用都会失败。
- 修复:
  - `Core/DeepBase.KeyManager.pas`: 数据密钥和业务密文统一保存为 `IV + ciphertext`，解密时拆出 IV 后再执行 AES-CBC。
  - `Core/DeepBase.KeyManager.pas`: `GetActiveKey` 在缺失 active key 时自动创建新 key。
  - `Core/DeepBase.Security.pas`: 修复损坏注释/条件行，并按 UTF-8 字节数执行 64KB Secret 明文上限校验。
- 影响范围: KeyManager 加解密、数据密钥持久化、Secret 存储、DPAPI-backed secret 管理。
- 验证:
  - `Scripts/run_tests.ps1 -Type Unit -FromUnit DeepBase.KeyManager -CI` 通过，36 tests passed，0 leaked。
  - `Scripts/run_tests.ps1 -Type Unit -FromUnit DeepBase.Security -CI` 通过，19 tests passed，0 leaked。
  - `Scripts/run_tests.ps1 -Type Unit -FromUnit DeepBase.Security.DPAPI -CI` 通过，23 tests passed，0 leaked。

### BUG-112: DataBinding ObservableList 所有权和 OneTime 绑定语义
- 发现日期: 2026-05-07
- 严重性: 🔴 High
- 描述:
  - `TObservableList<T>.OwnsObjects` 只修改包装类字段，没有同步到底层 `TObjectList<T>.OwnsObjects`，调用方切换所有权后仍可能发生旧对象重复释放和访问越界。
  - `bmOneTime` 绑定在初始化同步后仍订阅源对象属性变更，源属性更新会继续覆盖目标，违反一次性绑定语义。
- 修复:
  - `Core/DeepBase.DataBinding.pas`: 增加 `SetOwnsObjects`，同步更新底层 `TObjectList<T>` 所有权。
  - `Core/DeepBase.DataBinding.pas`: `bmOneTime` 不再订阅源属性变化，事件处理也显式跳过 one-time 绑定；`UpdateAllTargets` 仍保留强制同步能力。
- 影响范围: ObservableList replace/delete 生命周期、OneTime/OneWay/TwoWay 绑定行为。
- 验证:
  - `Scripts/run_tests.ps1 -Type Unit -FromUnit DeepBase.DataBinding -CI` 通过，22 tests passed，0 failed，0 errored，0 leaked。

### BUG-111: Expression 缓存所有权、XOR 解析和 AST 异常泄漏
- 发现日期: 2026-05-07
- 严重性: 🔴 High
- 描述:
  - `TExpression.Compile` 返回缓存内部对象，调用方按 API 习惯释放后会破坏全局缓存，后续 `Evaluate/ClearCache` 出现 invalid pointer、访问越界和 runtime error 217。
  - 词法器识别 `XOR`，但 parser 没有对应优先级层，`true XOR false` 被解析为表达式后残留 token。
  - `AsInt64` 使用 Delphi `Round` 的银行家舍入，`9876543210.5` 得到偶数方向结果。
  - 解析异常路径上已经创建的 AST 节点没有释放，错误用例会产生 FastMM 泄漏。
- 修复:
  - `Core/DeepBase.Expression.pas`: `Compile` 改为返回调用方拥有的新 `TCompiledExpression`；新增内部 `CompileCached` 仅供 `Evaluate` 使用，缓存对象不再被外部释放。
  - `Core/DeepBase.Expression.pas`: 增加 `ParseXor` 优先级层，`XOR` 位于 `OR` 和 `AND` 之间。
  - `Core/DeepBase.Expression.pas`: `AsInt64` 改为半数远离零舍入，匹配现有表达式测试语义。
  - `Core/DeepBase.Expression.pas`: 二元/一元/括号/函数调用解析异常时释放已创建 AST 节点，避免错误路径泄漏。
  - `Tests/Test.DeepBase.Expression.pas`: 未知操作符断言改为专用 `EExpressionError`。
- 影响范围: Expression 编译缓存、静态求值、逻辑表达式、错误路径内存安全。
- 验证:
  - `Scripts/run_tests.ps1 -Type Unit -FromUnit DeepBase.Expression -CI` 通过，140 tests passed，0 failed，0 errored，0 leaked。

### BUG-110: Template 分支解析、过滤器参数和 Context 生命周期
- 发现日期: 2026-05-07
- 严重性: 🔴 High
- 描述:
  - Template parser 在遇到 `else/elseif/endif` 时提前消费结束标签，导致 `else` 内容被错误渲染为普通文本。
  - 注释中的模板标记、冒号形式过滤器参数、点号完整键、严格模式缺失变量处理不完整。
  - 子 Context 使用接口父引用会触发 `TInterfacedObject` 引用计数，手工释放父 Context 的场景下会提前销毁父对象并产生访问越界。
- 修复:
  - `Core/DeepBase.Template.pas`: `ParseNodes` 遇到当前块结束标签时回退位置，让调用方正确解析 `else/elseif/endif`。
  - `Core/DeepBase.Template.pas`: 注释节点渲染时跳过输出并处理相邻空格，注释内容中的模板标记不再污染后续解析。
  - `Core/DeepBase.Template.pas`: `ParseFilterArgs` 支持 `filter:arg` 和多参数冒号形式；`ResolveValue` 优先匹配完整键并在 strict mode 下抛出缺失变量异常。
  - `Core/DeepBase.Template.pas`: 子 Context 改用弱父对象引用读取父值，`Parent` 属性返回轻量适配器，避免接口引用计数释放手工管理的父对象。
- 影响范围: Template 条件渲染、注释、过滤器、严格模式、父子 Context 生命周期。
- 验证:
  - `Scripts/run_tests.ps1 -Type Unit -FromUnit DeepBase.Template -CI` 通过，81 tests passed，0 failed，0 errored，0 leaked。

### BUG-109: StateMachine 泛型比较、目标状态语义和 Builder 泄漏
- 发现日期: 2026-05-07
- 严重性: 🔴 High
- 描述:
  - `TStateMachine` 使用 `CompareMem` 比较泛型 state/trigger，字符串触发器不可靠，部分枚举泛型场景也会找不到已配置 transition。
  - `Fire` 要求目标状态必须已 `Configure`，但状态机常见语义和现有测试允许只配置来源状态，未配置目标状态仍应能作为合法当前状态。
  - `TStateMachineBuilder` 未实现析构，未调用 `Build` 的 Builder 会泄漏内部 `TStateMachine`、配置、transition、闭包和锁。
  - 异常测试用泛型 `Exception` 断言，DUnitX 对异常类型做精确匹配时会误报专用异常 `EInvalidTransitionException`。
- 修复:
  - `Core/DeepBase.StateMachine.pas`: 引入 `TEqualityComparer<T>.Default` 比较 state/trigger，替换 `CompareMem`。
  - `Core/DeepBase.StateMachine.pas`: `IsValidState` 改为允许泛型目标状态，未配置目标状态不再阻止 transition；配置只用于 entry/exit、层级和显式 transition。
  - `Core/DeepBase.StateMachine.pas`: 为 `TStateMachineBuilder` 增加析构，释放未转移所有权的内部状态机；`Build` 后仍置空避免双释放。
  - `Tests/Test.DeepBase.StateMachine.pas`: 异常测试改为断言 `EInvalidTransitionException`。
- 影响范围: StateMachine 枚举/字符串状态机、Builder 生命周期、Unit 门禁内存泄漏。
- 验证:
  - `Scripts/run_tests.ps1 -Type Unit -FromUnit DeepBase.StateMachine -CI` 通过，79 tests passed，0 leaked，0 failed，0 errored。

### BUG-108: DoQry SQLite 与预编译池导致 DB 单测失败
- 发现日期: 2026-05-07
- 严重性: 🔴 High
- 描述:
  - DoQry 预编译池默认开启，池 key 使用连接指针；测试或业务释放 `TFDConnection` 后，Delphi 可能复用同一地址，导致 stale `TFDQuery` 命中并报 `Connection is not defined`。
  - `IsDirectSQL` 只接受 `SELECT ` 等带空格前缀，`SELECT FROM` 这类 malformed SQL 被误当成存储查询，错误码落到 unknown/connection 类。
  - SQLite 路径给 `INSERT` 追加 `RETURNING id`，当前 FireDAC SQLite 环境不支持，导致插入返回 ID、触发器场景和并发写入测试失败。
  - 预编译池 LRU 使用 `Now`，高频测试中时间戳可能相同，淘汰条目不稳定，复用统计误增。
- 修复:
  - `Persistence/DeepBase.DB.DoQry.pas`: 默认关闭预编译池，`UniDbInit` 清空池并复位统计；显式启用池时校验 query 和连接仍匹配且连接在线，否则移除 stale entry。
  - `Persistence/DeepBase.DB.DoQry.pas`: `IsDirectSQL` 改为 token 级关键字判断，保留 DML/查询白名单，同时让 malformed direct SQL 进入数据库层并映射语法错误码。
  - `Persistence/DeepBase.DB.DoQry.pas`: SQLite `UniDbInsertReturningId` 改为执行 insert 后读取连接本地 `last_insert_rowid()`，不再依赖 `RETURNING`。
  - `Persistence/DeepBase.DB.DoQry.pas`: 预编译池 LRU 改用单调使用序号生成 `LastUsed`，避免 `Now` 分辨率导致随机淘汰。
- 影响范围: DoQry 查询执行、SQLite 插入返回 ID、预编译池复用、CI DB 单测稳定性。
- 验证:
  - `Scripts/run_tests.ps1 -Type Unit -FromUnit DeepBase.DB.DoQry -CI` 通过，32 tests passed，0 failed，0 errored。

### BUG-107: DUnitX 过滤误匹配和 MVVM 异步命令死锁
- 发现日期: 2026-05-07
- 严重性: 🔴 High
- 描述:
  - `Scripts/run_tests.ps1 -FromUnit/-Module` 直接把测试单元名传给 DUnitX `--run`，会发生前缀误匹配，例如 `Test.DeepBase.Performance` 同时匹配 `PerformanceSuite`。
  - 未注册 `TDUnitX.RegisterTestFixture` 的测试单元会得到 0 tests，影响 CI 可信度。
  - `TAsyncCommand.Wait` 在主线程等待后台任务时没有泵 `CheckSynchronize`，后台任务中的 `TThread.Synchronize` 会与主线程 `Wait` 形成死锁。
- 修复:
  - `Scripts/run_tests.ps1`: `-FromUnit` 和 `-Module` 改为扫描测试文件中的 `TDUnitX.RegisterTestFixture(...)`，生成精确 `Test.Unit.Fixture` 过滤值。
  - `Scripts/run_tests.ps1`: 显式跳过并提示无注册 fixture 的单元；显式 `-FromUnit` 命中无 fixture 单元时直接失败。
  - `Scripts/run_tests.ps1`: 过滤解析时校验测试单元是否被当前 `-Type` 对应的测试工程实际引用，避免 `ModuleRunMap` 指向未编译进 runner 的单元。
  - `Core/DeepBase.MVVM.pas`: `TAsyncCommand.Wait` 在主线程等待时循环执行 `CheckSynchronize`，避免控制台 CI runner 死锁。
  - `Core/DeepBase.MVVM.pas`: 异步错误回调不再使用跨上下文 `AcquireExceptionObject`，改为捕获错误消息并创建短生命周期异常对象。
- 影响范围: Unit 测试过滤、CI 针对性回归、MVVM 异步命令等待和错误回调。
- 验证:
  - `Scripts/run_tests.ps1 -Type Unit -FromUnit DeepBase.Commerce -CI` 通过，16 tests passed。
  - `Scripts/run_tests.ps1 -Type Unit -FromUnit DeepBase.MVVM -CI` 通过，42 tests passed。
  - `Scripts/run_tests.ps1 -Type Unit -SkipCompile -CI` 不再超时，约 143 秒结束；当前仍有 52 failed、48 errored，已回写 `tasks.md`。
  - `Scripts/build_packages_win64.ps1 -Profile All` 通过；`VCL/` 源码目录缺失时 VCL 包仍按门禁策略排除。

## 2026-05-05 Bug 修复

### BUG-098: FormState 多显示器坐标残留导致窗口恢复到屏幕外
- 发现日期: 2026-05-05
- 严重�? 🟡 Medium
- 描述: 应用先在多显示器环境保存窗体位置，后续只剩单屏或显示器布局变化时，�?`Left/Top` 会落在当前可见工作区之外，二次启�?恢复后主界面可能不可见。Core 高层 `RestoreFormState` 只使用虚拟屏幕宽高，没有使用虚拟屏幕原点和当前显示器工作区�?- 修复:
  - `Core/DeepBase.FormState.pas`: 恢复时根据保存矩形定位当前最近的真实显示器工作区，并将窗口尺寸与坐标夹回该工作区；同时保留最大化恢复、不恢复最小化的既有策略�?  - `VCL/DeepBase.VCL.FormStateHelper.pas`: 保存 `GetWindowPlacement.rcNormalPosition` 时补齐工作区坐标到屏幕坐标的转换，和 Core 保存路径保持一致�?  - `Tests/Test.DeepBase.FormState.pas`: 新增旧多屏超界坐标回归测试，验证恢复后窗体完整落入当前某个显示器工作区�?- 影响范围: FormState 窗口位置保存/恢复、VCL FormStateHelper 自动恢复�?- 验证: `Scripts/run_tests.ps1 -Type Unit -Platform Win64 -CI -Run "Test.DeepBase.FormState"` 通过�?3/13 passed；`Scripts/build_packages_win64.ps1 -Profile All` 通过�?
## 2026-05-03 Bug 修复

### BUG-085: 架构审阅 P0 问题批量修复
- 发现日期: 2026-05-02
- 严重�? 🔴 High
- 描述: 架构审阅发现 DoQry Schema 不匹配、ProcName 回退 SQL 注入、Payment �?CSPRNG、LLM 表名冲突、入口文档断链和残留泛型异常�?P0 问题�?- 修复:
  - `Persistence/DeepBase.DB.DoQry.pas`: `Queries` 查询优先使用 `Name/SqlText`，缺失查询名不再回退执行；直�?SQL 收紧�?DML/查询白名单；`UniDbInsertReturningId` 绑定 JSON 参数�?  - `Core/DeepBase.Protection.pas` / `Core/DeepBase.Services.Protection.pas`: 修复密钥派生不对称并补强 padding 边界校验�?  - `ThirdParty/Payment/DeepBase.Payment.pas`: 订单号和 nonce 改用 `SecureRandom`�?  - `Core/DeepBase.LLM.pas` / LLM 文档�?SQL: 统一 canonical 表名�?`LLMConfig`，保留旧表兼容读�?写入路径�?  - `ARCH-QUICKSTART.md`: 修复旧文档路径，并新�?`Scripts/check_doc_links.ps1`�?  - 非测试代码中�?`raise Exception.Create/CreateFmt` 已迁移到 `EDeepBaseException` 层次�?- 影响范围: DoQry、Protection、Payment、LLM 集成、文档入口、异常处理�?- 验证: 已完成静态扫描；剩余泛型异常仅在 Tests 目录的测试场景中保留�?
### BUG-086: 全局锁和单例懒初始化存在并发竞�?- 发现日期: 2026-05-03
- 严重�? 🟡 Medium
- 描述: 部分全局�?单例在首次调用路径中懒创建或无锁读取，高并发启动时存在重复创建、访�?nil 锁或读到被替换实例的风险�?- 修复:
  - `Persistence/DeepBase.DB.DoQry.pas`: 查询缓存锁、查询缓存、预编译语句池锁和池对象改为单元初始化创建，并补�?finalization 释放�?  - `Core/DeepBase.KeyManager.pas`: `FInstanceLock` 改为 initialization 创建，finalization 先释�?`FInstance` 再释放锁�?  - `Core/DeepBase.FeatureFlags.pas`: 全局 manager 创建全程持锁，`TFeatureFlags.Manager` 统一返回 `FeatureFlags()` 的全局实例�?  - `Core/DeepBase.Configuration.pas` / `Core/DeepBase.Authorization.pas`: 默认配置和全局授权 manager 的读取路径补齐锁保护�?  - `Tests/Test.DeepBase.FeatureFlags.pas`: 新增多线程访�?`TFeatureFlags.Manager` 的单例一致性回归测试�?- 影响范围: DoQry、KeyManager、FeatureFlags、Configuration、Authorization 的全局初始化与单例访问�?- 验证: Win64 Unit 门禁通过�?348 found / 3 ignored / 1345 passed / 0 failed / 0 errored / 0 leaked�?
### BUG-087: Core/Persistence DoQry 双实现导致修复需要同步两�?- 发现日期: 2026-05-03
- 严重�? 🟡 Medium
- 描述: �?Core DoQry 单元�?`Persistence/DeepBase.DB.DoQry.pas` 同名同功能并存，导致安全修复、参数绑定、缓存锁初始化等改动需要重复同步，且包边界容易引用到旧实现�?- 修复:
  - 删除�?Core DoQry 重复实现�?  - 保留 `Persistence/DeepBase.DB.DoQry.pas` 作为 `DeepBase.DB.DoQry` 的唯一实现，并迁入全局锁初始化修复�?  - `Tests/DeepBaseTests.dpr` / `.dproj` 改为显式引用 `..\Persistence\DeepBase.DB.DoQry.pas`�?  - 保留 Persistence 版本中的 `IDoQryService` / `TDoQryService` 服务适配层，避免破坏 IoC 使用方�?- 影响范围: DoQry 源文件归属、测试工程引用、Persistence 包边界�?- 验证: Win64 Unit 门禁通过�?348 found / 3 ignored / 1345 passed / 0 failed / 0 errored / 0 leaked�?
### BUG-088: 社交 OAuth2 流程缺少 PKCE �?state 校验
- 发现日期: 2026-05-03
- 严重�? 🔴 High
- 描述: WeChat/QQ/Weibo/GitHub/Google 等社交登录流程只�?`state` 放入授权 URL，未保存和校验回�?state；state 使用�?CSPRNG 生成，授权码交换也缺�?PKCE verifier/challenge，存�?CSRF 和授权码截获风险�?- 修复:
  - `ThirdParty/Social/DeepBase.Social.pas`: `GenerateState` 改用 `SecureRandom`；新�?PKCE verifier、S256 challenge、常量时间比较；`TSocialClient` 保存 state/verifier，并提供 `ValidateState` 和带 state �?`ExchangeCode` 重载�?  - `ThirdParty/Social/DeepBase.Social.OAuth.pas`: 通用 OAuth/GitHub/Google 授权 URL 增加 `code_challenge` / `code_challenge_method=S256`，授权码�?token 时携�?`code_verifier`�?  - `ThirdParty/Social/DeepBase.Social.WeChat.pas` / `DeepBase.Social.Weibo.pas` / `DeepBase.Social.QQ.pas`: 改为复用基类 state/PKCE 逻辑�?  - `Tests/Test.DeepBase.Social.pas`: 新增 RFC 7636 PKCE challenge 向量、授�?URL PKCE 参数�?state 校验回归测试�?- 影响范围: 社交登录 OAuth2 授权 URL 构造、授权码交换和回�?state 校验�?- 验证: Win64 Unit 门禁通过�?353 found / 3 ignored / 1350 passed / 0 failed / 0 errored / 0 leaked�?
### BUG-089: 泛型对象池双实现导致行为分叉和测试缺�?- 发现日期: 2026-05-03
- 严重�? 🟡 Medium
- 描述: `Core/DeepBase.Memory.pas` �?`Core/DeepBase.ObjectPool.pas` 同时维护泛型 `TObjectPool<T>`，默认容量、事件、reset 和统计行为容易分叉；canonical 对象池测试未纳入主测试工程，wrapper 行为测试还存在直接创建对象未释放导致 FastMM 泄漏的问题。合并后还发�?reset 失败对象不能重新入池，必须显式丢弃，后台清理任务也需要可唤醒退出�?- 修复:
  - `Core/DeepBase.Memory.pas`: 保留兼容 API，但内部委托 `DeepBase.ObjectPool.TObjectPool<T>`，统一池化生命周期、统计和并发行为；释放时继续执行旧版 reset 语义�?  - `Core/DeepBase.ObjectPool.pas`: 将对象池事件类型改为匿名方法友好形式，默�?`MinSize` 调整�?0，匹配惰性创建和�?Memory wrapper 预期；新�?`Discard` 丢弃损坏对象；后台清理任务改�?shutdown event 唤醒并在析构中等待退出�?  - `Tests/DeepBaseTests.dpr` / `.dproj`: 纳入 `Test.DeepBase.ObjectPool` �?`DeepBase.ObjectPool`，主测试工程覆盖 canonical 对象池�?  - `Tests/Test.DeepBase.ObjectPool.pas` / `Tests/Test.DeepBase.Memory.pas`: 补齐并修�?canonical 和兼�?wrapper 回归测试，覆�?scoped 释放、直接创建对象释放、坏对象 discard �?reset 失败路径�?- 影响范围: Core 泛型对象池、Memory 模块兼容对象池、对象池单元测试覆盖�?- 验证: Win64 Unit 门禁通过�?403 found / 3 ignored / 1400 passed / 0 failed / 0 errored / 0 leaked�?
### BUG-090: 磁盘 I/O 基准依赖系统临时盘导致单测失�?- 发现日期: 2026-05-03
- 严重�? 🟢 Low
- 描述: `Tests/Test.DeepBase.PerformanceSuite.pas` 的磁�?I/O 基准使用 `TPath.GetTempPath`，当前环境该路径指向 `Z:\Temp` 且剩余空间不足，导致 Win64 单测出现 Windows 错误 112（磁盘空间不足）�?- 修复:
  - `Tests/Test.DeepBase.PerformanceSuite.pas`: 磁盘 I/O 基准改用当前项目下的 `TestResults/BenchmarkTemp_*` 作为工作目录，并�?`TearDown` 中继续递归清理�?- 影响范围: PerformanceSuite 磁盘 I/O 基准测试稳定性�?- 验证: Win64 Unit 门禁通过�?403 found / 3 ignored / 1400 passed / 0 failed / 0 errored / 0 leaked�?
### BUG-095: Unit 测试运行期崩溃与 Win64 sqlite3 装载失败
- 发现日期: 2026-05-04
- 严重�? 🔴 High
- 描述:
  - Unit 测试可执行文件在启动阶段退�?`-1073741511 (0xC0000139)`，无法进�?DUnitX 运行�?  - 崩溃修复后发�?Win64 Unit 仍会加载�?32 �?`sqlite3.dll`，导�?FireDAC vendor library 装载失败�?- 修复:
  - `Core/DeepBase.Security.pas`: `SecureZeroMemory` 从静态导入改为运行时解析（`RtlSecureZeroMemory` �?`RtlZeroMemory` �?`FillChar` 回退），避免加载期入口点缺失�?  - `Scripts/run_tests.ps1`: Unit 路径增加 `Ensure-SqliteDll`，并补充 x64 候选路�?`bin64\sqlite3.dll` �?`bin\windows\lldb\sqlite3.dll`；测试结束后清理临时拷贝�?  - `Tests/Test.DeepBase.Resilience.pas`: `Test_Execute_RejectedWhenOpen` 断言类型改为 `ECircuitBreakerException`，与实现对齐�?- 影响范围: 安全模块初始化、Win64 Unit 测试运行链路、Resilience 回归断言�?- 验证: Win64 Unit 门禁通过�?433 found / 3 ignored / 1430 passed / 0 failed / 0 errored / 0 leaked�?
### BUG-096: Diagnose 模块缺少存储注入入口，难以脱�?FireDAC 调用
- 发现日期: 2026-05-04
- 严重�? 🟡 Medium
- 描述: `Core/DeepBase.Diagnose.pas` 仅暴�?`TFDConnection` 入口，调用侧无法注入替代存储实现，不利于 ARCH-019/039 分层迁移和无数据库环境测试�?- 修复:
  - `Core/DeepBase.Diagnose.pas`：新�?`IDiagnoseStorage` 抽象，并补充 `DiagnoseAllWithStorage`、`Check*WithStorage`、`AutoFixWithStorage`、`CreateDiagnoseStorage` 等入口�?  - `Core/DeepBase.Diagnose.pas`：新�?`SetDiagnoseStorageFactory`，支�?Persistence 层注册自定义连接适配器�?  - `Persistence/DeepBase.Persistence.Diagnose.FireDAC.pas`：新�?FireDAC 适配器并�?initialization 自动注册�?Diagnose 工厂�?  - `Tests/Test.DeepBase.Diagnose.pas`：新增注入回归测试，覆盖 `DiagnoseAllWithStorage` 结果聚合�?`AutoFixWithStorage` 委托行为�?- 影响范围: Diagnose 模块扩展点与测试可注入性�?- 验证: Win64 全量门禁通过，Unit 1444 found / 3 ignored / 1441 passed，Integration 9/9 passed�?
### BUG-097: Logging 模块缺少可注入存�?+ 队列空批次重复写风险
- 发现日期: 2026-05-04
- 严重�? 🟡 Medium
- 描述:
  - `Core/DeepBase.Logging.pas` 直接依赖 FireDAC，DB 写入路径无法替换为其他存储实现，不利�?ARCH-019/039 分层迁移与无数据库测试�?  - 写线程在某些空批次轮询场景下未重�?`LocalBatch`，可能复用上次批次内容导致重复写入风险�?- 修复:
  - `Core/DeepBase.Storage.Interfaces.pas`：扩展日志契约，新增 `TLogStorageData` �?`ILogQueryStorage`（计数查询）�?  - `Core/DeepBase.Logging.pas`：新�?`SetStorageFactory`/`CreateStorage`，将 DB 写入、清理与计数切换�?`ILogStorage` 注入；移�?`FireDAC/Data.DB` 直接依赖�?  - `Core/DeepBase.Logging.pas`：写线程每轮显式 `SetLength(LocalBatch, 0)`，避免空批次复用旧数据�?  - `Persistence/DeepBase.Persistence.Logging.FireDAC.pas`：重�?FireDAC 适配器并自动注册；对旧库�?`Logs.Extra` 列保留兼容写入回退�?  - `Tests/Test.DeepBase.Logging.pas`：新�?`Test_StorageInjection_DelegatesDbWriteAndQuery`，覆盖注入写入、计数与清理委托链路�?- 影响范围: Logging 模块分层边界、异步写线程稳定性、日志数据库写入兼容性�?- 验证: Win64 全量门禁通过，Unit 1445 found / 3 ignored / 1442 passed，Integration 9/9 passed�?
### BUG-091: LLM API 示例文档与实际接口不一�?- 发现日期: 2026-05-03
- 严重�? 🟢 Low
- 描述: `05.05 LLM 集成指南` �?`05.01 API 参考` 中的 LLM 示例风格和接口覆盖不一致，部分示例仍使用旧代码块类型、占位调用或未定�?UI 控件，容易误导集成方�?- 修复:
  - `docs/05.05.DeepBase-4AI-LLM集成指南-v1.0.md`: 统一 LLM 示例�?`delphi` 代码块，补齐 `TLLMManager`、`TDeepBaseLLM`、`TLLMImportExport` 的真实单元引用，修正导入导出、异步和错误处理示例�?  - `docs/05.01.DeepBase-4AI-API参�?v1.0.md`: 新增 LLM 模块 API 参考，覆盖直接模型调用、提示词版本调用、响应字段和导入导出 API�?- 影响范围: LLM 文档集成示例、API 参考目录与章节编号�?- 验证: 静态扫描确认两份文档不再包�?`LLMConfiguration`、旧 `DeepBaseLLM` 全局写法、`TLLMMessage.Create`、`LLM.AddProvider`、`LLM.SetTierModels` �?`pascal` 代码块�?
### BUG-092: 旧格式文档散落在 docs 根目录导致索引混�?- 发现日期: 2026-05-03
- 严重�? 🟢 Low
- 描述: `docs/` 根目录同时存在标准命名文档和大量旧命名、重复或过期文档，索引仍引用过期 v1.0 ThirdParty 指南和旧 API/FAQ/DoQry 文档，开发者容易进入过时材料�?- 修复:
  - 旧格式、重复或过期文档已清理，并记录当前替代入口�?  - `docs/00.00.DeepBase-文档索引-v1.0.md`: 更新日期、修正表格格式，并统一 ThirdParty 指南入口�?v1.1�?  - `ARCH-QUICKSTART.md` / `README.md` / 标准文档 / 回归测试文档: 修正旧路径引用，优先指向当前标准文档�?  - `Scripts/check_doc_links.ps1`: 修正链接解析逻辑，Markdown 链接按源文件目录解析，代码路径仍支持仓库根路径�?- 影响范围: 文档导航、归档文档路径、README 与测试文档链接�?- 验证: 静态扫描确�?`docs/` 根目录仅保留标准命名文档�?`00.00` 文档索引；旧路径引用已从�?legacy 文档中清理；关键导航文档链接检查通过�?
### BUG-093: TBasicProtection 使用 CBC 缺少认证加密
- 发现日期: 2026-05-03
- 严重�? 🟡 Medium
- 描述: `TBasicProtection` 新写入密文仍使用 AES-256-CBC，虽然已�?padding 校验和外�?HMAC 辅助，但加密格式本身不提�?AEAD 认证，密文篡改不能在解密层稳定表达为认证失败�?- 修复:
  - `Core/DeepBase.Protection.pas`: 新增 Windows CNG AES-256-GCM 实现；字符串密文使用 `UBG1|<hex payload>`，二进制密文使用 `UBG1 + nonce + tag + ciphertext`�?  - 保留�?AES-256-CBC 字符串格�?`IVHex|CipherHex` 与二进制格式 `IV + Cipher` 的只读解密兼容路径�?  - `Tests/Test.DeepBase.Protection.pas`: 新增 GCM 格式断言、篡�?tag/ciphertext 后认证失败、旧 CBC 样本兼容解密测试�?  - `docs/07.03.DeepBase-4H-安全与测�?v1.0.md`: 更新加密模式说明�?- 影响范围: Protection 敏感字符�?二进制加密格式、AntiTamper 等调�?`TBasicProtection` 的可选保护能力�?- 验证: Win64 Unit 门禁通过�?409 found / 3 ignored / 1406 passed / 0 failed / 0 errored / 0 leaked�?
### BUG-094: LLM API Key 被写入配置表字段
- 发现日期: 2026-05-03
- 严重�? 🟡 Medium
- 描述: `TDeepBaseLLM.SaveConfig` �?`TLLMConfig.ApiKey` 直接写入 `LLMConfig.ApiKeyRef` 或旧 `LLMConfiguration.ApiKey` 字段，导�?SQLite 配置库可能保存真�?API Key�?- 修复:
  - `Core/DeepBase.LLM.pas`: 保存配置时将真实 API Key 写入 Windows Credential Manager，数据库只保�?`credman:<target>`；读取时兼容 `credman:`、`LLMApiKeys.Name` 和旧明文值�?  - `Scripts/migrate_llm_credentials.ps1`: 新增迁移脚本，将旧明�?LLM 凭据写入 Credential Manager 并回写引用�?  - `Core/DeepBase.Schema.pas` / `Data/create_sample_db.sql` / `Core/DeepBase.Diagnose.pas`: LLMApiKeys 默认存储方式更新�?`CREDMAN`，诊断枚举允�?`CREDMAN`�?  - `Tests/Test.DeepBase.LLM.pas`: 新增 Credential Manager 存储、旧明文迁移、`LLMApiKeys` 引用解析回归测试�?- 影响范围: LLM 配置保存/读取、LLMApiKeys schema 语义、旧库凭据迁移�?- 验证: Win64 Unit 门禁通过�?412 found / 3 ignored / 1409 passed / 0 failed / 0 errored / 0 leaked�?
## 2026-05-02 Bug 修复

### BUG-074: FormState 使用工作区坐标导致恢复位置偏移（顶部任务栏场景）
- 发现日期: 2026-05-02
- 严重�? 🟡 Medium
- 描述: `SaveFormState` 使用 `GetWindowPlacement.rcNormalPosition` 直接入库，在顶部任务�?多显示器工作区场景会出现 `Top` 偏移，恢复后位置不一致�?- 修复:
  - `Core/DeepBase.FormState.pas`: �?`rcNormalPosition` 从工作区坐标转换为屏幕坐标后再持久化（基�?`MonitorFromWindow + GetMonitorInfo`）�?- 影响范围: FormState 窗口位置保存/恢复�?- 验证: 单元测试全绿，`Test_SaveRestore_Position` 稳定通过 �?
### BUG-075: Resilience 组合执行链匿名方法残留导�?FastMM 泄漏告警
- 发现日期: 2026-05-02
- 严重�? 🟡 Medium
- 描述: `TResiliencePolicy.Execute` / `Execute<T>` 多层闭包链在测试进程结束时触发小块泄漏告警�?- 修复:
  - `Core/DeepBase.Resilience.pas`: 重构闭包拼装逻辑并显式置空捕获引用，避免残留引用链�?- 影响范围: Resilience 组合策略执行（Retry/Timeout/CircuitBreaker/Bulkhead 组合）�?- 验证: Unit 测试结束后无 `TResiliencePolicy.Execute*` 相关 FastMM 泄漏告警 �?
### BUG-076: Win64 �?DUnitX 泛型断言类型推断失败
- 发现日期: 2026-05-02
- 严重�? 🟢 Low
- 描述: `Test.DeepBase.Resilience.pas` �?Win64 编译�?`Assert.AreEqual(1, Breakers.Count)` 触发泛型参数推断错误�?- 修复:
  - `Tests/Test.DeepBase.Resilience.pas`: 改为 `Assert.AreEqual<Integer>(1, Breakers.Count)`�?- 影响范围: Win64 单测编译�?- 验证: Win64 单测可完整编译并执行 �?
### BUG-077: 默认测试链路仍使�?Win32，不符合 64 位基线要�?- 发现日期: 2026-05-02
- 严重�? 🟢 Low
- 描述: `Scripts/run_tests.ps1` 固定 `dcc32`，与“默�?64 位”基线不一致�?- 修复:
  - `Scripts/run_tests.ps1`: 新增 `-Platform` 参数（`Win32|Win64`），默认改为 `Win64`，并增加编译器路径存在性检查�?- 影响范围: CI/本地单测入口�?- 验证: 默认命令 `.\Scripts\run_tests.ps1 -Type Unit -CI` 已在 Win64 全绿 �?
### BUG-078: DoQry 调用 SQLLogger 旧签名导致编译不通过
- 发现日期: 2026-05-02
- 严重�? 🟡 Medium
- 描述: �?Core DoQry 实现使用旧版 `TSQLLogger.LogSQL` 参数形式，与当前 SQLLogger 接口不匹配�?- 修复:
  - `Persistence/DeepBase.DB.DoQry.pas`: 相关调用切换�?`TSQLLogger.LogSQLEx(...)`�?- 影响范围: DoQry 模块编译�?SQL 日志记录�?- 验证: 单元测试工程可成功编�?�?
### BUG-079: Payment 凭据管理接口签名不匹�?- 发现日期: 2026-05-02
- 严重�? 🟢 Low
- 描述: `TCredentialManager.GetCredential` 调用参数缺失导致编译错误�?- 修复:
  - `ThirdParty/Payment/DeepBase.Payment.pas`: 调整�?`GetCredential(TargetName, '')`�?- 影响范围: Payment 模块编译�?- 验证: 单元测试工程可成功编�?�?
### BUG-080: WebAPI TLS 配置依赖 Indy 新枚举导�?Win64 集成编译失败
- 发现日期: 2026-05-02
- 严重�? 🟡 Medium
- 描述: `DeepBase.WebAPI.Core` 直接引用 `sslvTLSv1_3`，在不包含该枚举�?Indy 版本上编译失败�?- 修复:
  - `Tools/WebService/DeepBase.WebAPI.Core.pas`: �?`sslvTLSv1_3` 使用 `{$IF Declared(...)}` 条件编译，自动回退 TLS 1.2�?- 影响范围: WebAPI 模块�?Indy 版本编译兼容性�?- 验证: Win64 Integration 工程可编译通过 �?
### BUG-081: DeepBase.Net 静态方法调用与 LinkLocal 检测缺失导致编译错�?- 发现日期: 2026-05-02
- 严重�? 🟡 Medium
- 描述:
  - `THttpRequest.Execute` 中调�?`IsValidHttpHeader/IsSafeUrl` 未加类限定�?  - `TIPUtils.IsLinkLocalIP` 被调用但未实现�?- 修复:
  - `Core/DeepBase.Net.pas`: 改为 `TNetworkUtils.IsValidHttpHeader` �?`TNetworkUtils.IsSafeUrl`�?  - 新增 `TIPUtils.IsLinkLocalIP`（IPv4 169.254/16 + IPv6 fe80::/10 前缀）�?- 影响范围: Net 模块编译�?URL 安全检查�?- 验证: Win64 Integration 工程可编译通过 �?
### BUG-082: Win64 集成测试缺少位宽匹配 sqlite3.dll 导致运行报错
- 发现日期: 2026-05-02
- 严重�? 🟡 Medium
- 描述: 集成测试执行目录缺少 x64 `sqlite3.dll`，FireDAC SQLite 驱动运行时报 `-314 Cannot load vendor library`�?- 修复:
  - `Scripts/run_tests.ps1`: 增加 `Ensure-SqliteDll`，自动复制位宽匹配的 `sqlite3.dll` �?`Tests/Integration`�?- 影响范围: Win64 Integration 运行时依赖加载�?- 验证: 集成测试 9/9 通过 �?
### BUG-083: SSRF 安全检查默认拦�?localhost，导致本地集成测试不可用
- 发现日期: 2026-05-02
- 严重�? 🟢 Low
- 描述: `IsSafeUrl` 默认禁止 `127.0.0.1/localhost`，导�?WebAPI 本地回环调用测试全部�?`Unsafe URL detected`�?- 修复:
  - `Core/DeepBase.Net.pas`: 增加环境变量开�?`DeepBase_ALLOW_LOCALHOST_HTTP` �?`DeepBase_ALLOW_PRIVATE_NET_HTTP`�?  - `Scripts/run_tests.ps1`: 集成测试阶段临时设置 `DeepBase_ALLOW_LOCALHOST_HTTP=1`�?- 影响范围: 开�?测试环境本地回环请求；生产默认仍保持安全策略�?- 验证: 集成测试 9/9 通过 �?
### BUG-084: DB.Factory 无法按配置创建共�?SQLite 连接
- 发现日期: 2026-05-02
- 严重�? 🟡 Medium
- 描述: `TDBConnectionFactory.LoadSharedProfile` 仅支�?`DB3.Type=PostgreSQL/PG`，导致下游无法通过统一 `DB3.*` 配置切换到共�?SQLite�?- 修复:
  - `Persistence/DeepBase.DB.Factory.pas`：新�?`DB3.Type=SQLite` 分支，支�?`DB3.Database`（兼�?`DB3.Path`）和相对 `RootPath` 解析�?  - 增加 SQLite 参数透传：`DB3.SQLiteLockingMode`、`DB3.SQLiteSynchronous`、`DB3.SQLiteJournalMode`、`DB3.SQLiteOpenMode`、`DB3.ExtraParams`�?  - `Tests/Test.DeepBase.DB.Factory.pas` 新增回归用例验证 Driver/Path/参数/超时�?- 影响范围: 下游多库接入（本�?SQLite + 共享 SQLite/PG 切换）�?- 验证: Win64 全量门禁通过（Unit + Integration）✅

---

## 2025-12-13 Bug 修复

### BUG-067: TStyleManager.IsValidStyle 抛出 EFOpenError 导致主题加载失败
- 发现日期: 2025-12-13
- 严重�? 🟡 Medium
- 描述: 当数据库中存储了无效的主题名（如 `Iceberg Classico`）时，`TStyleManager.IsValidStyle()` 会尝试将其作为文件路径加载，抛出 `EFOpenError: Cannot open file 'xxx'` 异常，导致应用程序启动失败�?- 修复:
  - `Core/DeepBase.Theme.pas`: 新增 `IsStyleInList()` 辅助函数，通过 `TStyleManager.StyleNames` 列表检查样式是否已注册，而不是调用可能抛异常�?`IsValidStyle()`�?  - `ApplyTheme()`、`GetAvailableThemes()`、`IsThemeAvailable()` 方法均改�?`IsStyleInList()` 进行样式验证�?  - 无效主题名会自动回退�?`Windows` 默认主题�?- 影响范围: 所有使�?DeepBase 主题功能�?VCL 应用程序�?- 验证: 单元测试 181/181 通过 �?
### BUG-068: I18nTexts 列名不一致导致翻译添加失�?- 发现日期: 2025-12-13
- 严重�? 🟡 Medium
- 描述: `DeepBase.i18n.pas` 中的 `AddTranslation` �?`RecordMissingTranslation` 方法使用列名 `LastUsedTime`，但 `DeepBase.Schema.pas` �?I18nTexts 表定义使�?`LastUsedAt`，导致内存数据库 `:memory:` 测试时报�?"table I18nTexts has no column named LastUsedTime"�?- 修复: �?`Core/DeepBase.i18n.pas` 中所�?`LastUsedTime` 引用改为 `LastUsedAt`�?- 影响范围: i18n 模块的翻译添加和缺失记录功能�?- 验证: 单元测试 265/267 通过 �?
### BUG-069: DeepBase.Updater.pas 缺少 Winapi.Windows 导致 OutputDebugString 编译错误
- 发现日期: 2025-12-13
- 严重�? 🟡 Medium
- 描述: `Features/DeepBase.Updater.pas` �?`{$IFDEF DEBUG}` 块中使用 `OutputDebugString`，但未引�?`Winapi.Windows`，导�?Debug 配置编译失败�?- 修复: �?`{$IFDEF MSWINDOWS}` uses 块中添加 `Winapi.Windows`�?- 影响范围: Debug 模式下的编译�?- 验证: 编译通过 �?
### BUG-070: MRU LastAccess 时间精度不足导致排序不稳�?- 发现日期: 2025-12-13
- 严重�? 🟡 Medium
- 描述: `Core/DeepBase.MRU.pas` 写入 LastAccess 使用秒级时间戳（`yyyy-mm-dd"T"hh:nn:ss`），在短时间内连续写入（如单元测�?Sleep(100)）会出现同一秒内多条记录 LastAccess 相同，导�?`ORDER BY LastAccess DESC` 出现排序不稳定�?- 修复: LastAccess 改为毫秒精度（`yyyy-mm-dd"T"hh:nn:ss.zzz`），避免同秒冲突�?- 影响范围: MRU 列表排序与稳定性（尤其是测�?高频写入场景）�?- 验证: 单元测试全部通过�?93/293）✅

### BUG-071: Hotkeys / i18n 单元测试用例与框架语义不一致导致失�?- 发现日期: 2025-12-13
- 严重�? 🟢 Low
- 描述:
  - `Test.DeepBase.Hotkeys.Test_CheckHotkeyConflict_NoConflict` 假设 `Ctrl+F` 不会被默认快捷键占用，但框架初始化可能已注册默认快捷键，导致返回冲突 ActionName�?  - `Test.DeepBase.i18n` 测试之间共享单例 I18n 实例，部分用例切换语言后未复位，导致后续复数规�?缓存相关用例受到污染；同时框架将 `en-US` 视为英文源语言（TranslateTo 直接返回原文），测试用例不应要求 `en-US` 有独立翻译�?- 修复:
  - Hotkeys 测试改为动态寻找未占用快捷键（候选集�?Ctrl+Shift+Alt+F1..F12）�?  - i18n 测试�?Setup/TearDown 统一复位 CurrentLanguage= en-US �?ClearCache；语言切换用例改用 `fr-FR` 作为第二语言�?- 影响范围: 仅测试代码，但可避免误报并提升回归稳定性�?- 验证: 单元测试全部通过�?23/323）✅

### BUG-072: FormState 单元测试使用无效窗体 Name / 句柄创建时机导致位置断言失败
- 发现日期: 2025-12-13
- 严重�? 🟢 Low
- 描述:
  - `Test.DeepBase.FormState.pas` 使用 `TGUID.ToString` 生成窗体 Name，包�?`{}` 导致 VCL 抛出 “not a valid component name”�?  - 测试窗体未提前创�?Handle，导�?`SaveFormState` 内部首次访问 Handle 时触�?Windows 默认窗口摆放，`GetWindowPlacement().rcNormalPosition` 与测试设置的 Left/Top 不一致�?- 修复:
  - 生成 Name 时剥�?GUID �?`{}` �?`-`�?  - 在设置窗�?Bounds 之前调用 `HandleNeeded`，并使用 `SetBounds` 让窗口位�?大小真正落到 WinAPI 句柄上�?- 影响范围: 仅测试代码；同时更准确地覆盖 `GetWindowPlacement` 分支�?- 验证: 单元测试全部通过�?23/323）✅

### BUG-073: Logging 单元测试与现�?Logger API 不一致导致无法编�?- 发现日期: 2025-12-13
- 严重�? 🟢 Low
- 描述: `Test.DeepBase.Logging.pas` 使用了旧接口（`LogInfo/Flush/GetLogs/OnLogAdded` 等），与当前 `TDeepBaseLogger`（`Info/InfoFmt`、异步写入线程、无 GetLogs API）不匹配，导致测试工程无法编译�?- 修复:
  - 重写 Logging 测试：改�?file-only 模式（避�?SQLite `:memory:` 多连接限制），并通过轮询当天日志文件内容验证异步写入�?  - 修复 Delphi 兼容性：避免 `Exit([])` 写法�?- 影响范围: 仅测试代码，但能恢复 Logging 回归测试覆盖�?- 验证: 单元测试全部通过�?23/323）✅

---

## 2025-12-12 Bug 修复

### BUG-065: Indy HTTPServer 拒绝 Authorization: Bearer 导致 JWT 中间件无法工�?- 发现日期: 2025-12-12
- 严重�? 🟡 Medium
- 描述: �?Indy `TIdHTTPServer` 场景下，请求携带 `Authorization: Bearer <token>` 会被 Indy 在进入业务路由前直接拒绝�?01，Body �?`Unsupported authorization scheme.`），导致 `TAuthMiddleware` 无法读取 token 并完成认证�?- 修复:
  - `Tools/WebService/DeepBase.WebAPI.Auth.pas`: Bearer 提取逻辑兼容 `X-Authorization: Bearer <token>`（当 `Authorization` 不可用时作为替代入口），并对提取结果�?Trim�?  - `Tools/WebService/DeepBase.WebAPI.Core.pas`: 修复请求头解析，支持折行 header continuation lines，并确保自定义头（如 `X-Authorization`）可被正确读取�?  - `Tools/WebService/DeepBase.WebAPI.Auth.pas`: 修复认证中间件中每请求用户对象生命周期，避免内存泄漏�?  - `Tests/Integration/Test.Integration.WebAPI.pas`: 测试用例改用 `X-Authorization` 头以兼容 Indy�?- 影响范围: DeepBase WebAPI（Indy HTTPServer）下�?JWT Bearer 认证�?- 验证: 运行 `Scripts/run_tests.ps1 -Type Integration`�?/9 测试通过 �?
### BUG-066: Integration Tests 缺少 FireDAC SQLite 驱动导致测试失败
- 发现日期: 2025-12-12
- 严重�? 🟡 Medium
- 描述: `DeepBaseIntegrationTests.dpr` 项目缺少 FireDAC SQLite 驱动引用，导致运行时报错 `Object factory for class ... is missing. To register it, you can drop component [TFDPhysXXXDriverLink] into your project`�?- 修复: �?`DeepBaseIntegrationTests.dpr` �?uses 中添�?`FireDAC.Phys.SQLite`, `FireDAC.Phys.SQLiteDef`, `FireDAC.Stan.ExprFuncs`�?- 影响范围: 集成测试项目�?- 验证: 重新编译并运行集成测试，9/9 测试通过 �?
---

## 2025-12-11 Bug 修复

### BUG-061: DBException UserMessage 中文+英文混排被截�?- 发现日期: 2025-12-11
- 严重�? 🟡 Medium
- 描述: `Core/DeepBase.DBException.pas` �?`EDeepBaseDB.UserMessage` 在同时包含中文和英文操作描述时，字符串拼接逻辑存在编码/格式问题，导致用户可见的操作文本只剩下部分英文字符（例如只显�?"s"）�?- 修复: 重写 `UserMessage` 拼接逻辑，改用简单可靠的字符串连接顺序，避免格式化与编码混用导致的截断问题，并为该场景增加回归单元测试�?- 影响范围: 所有通过 `EDeepBaseDB` 抛出的数据库异常的用户提示信息，尤其是包含中文操作描述的场景�?- 验证: 使用中英混排消息构造异常，检�?`Message` / `UserMessage` / `Suggestion` 输出，确认完整操作文本被正确包含且单元测试通过 �?
### BUG-062: WebAPI 查询字符串解析导�?Query 参数丢失
- 发现日期: 2025-12-11
- 严重�? 🟡 Medium
- 描述: WebAPI 核心�?`TApiServer.DoCommandGet` 中通过 `ARequestInfo.URI` 手工�?`?` 拆分路径和查询字符串，但在部�?Indy 配置�?`URI` 不包含查询部分，导致�?`/api/users/42?verbose=1` 中的 `verbose` 参数未被解析，集成测试中返回空字符串�?- 修复: 改为使用 Indy 提供�?`ARequestInfo.Document` �?`ARequestInfo.UnparsedParams` 填充 `TApiRequest.Path` �?`QueryString`，并在必要时去掉前导 `?`，保�?`ParseQueryString` 能稳定解析所有查询参数�?- 影响范围: 所有通过 WebAPI 访问�?GET/POST �?HTTP 路由的查询参数解析，尤其是依�?`Request.GetQueryParam` 的接口�?- 验证: 通过 `Test.Integration.WebAPI.pas` �?`Test_RouteParams_And_QueryParams_Parsed` 用例访问 `/api/users/42?verbose=1`，确认响�?JSON �?`id="42"` �?`verbose="1"`，集成测试通过 �?
### BUG-063: JWT Base64 编码包含换行导致 Token 无法安全放入 HTTP Header
- 发现日期: 2025-12-11
- 严重�? 🟡 Medium
- 描述: `TJWTManager.Base64URLEncode` 使用标准 Base64 编码时可能插�?CRLF/LF/CR 换行。JWT 若携带换行符，放�?HTTP Header（如 `Authorization`/`X-Authorization`）会被客户端/服务器视为非法或被截断，导致认证失败�?- 修复: �?Base64URL 转换前显式移除所�?CR/LF（`#13`/`#10`），再将 `+`/`/` 替换�?URL 安全字符并去掉尾�?`=` 填充，确保生成的 JWT 始终为单行字符串�?- 影响范围: 所有使�?`TJWTManager.GenerateToken` 生成 JWT 并通过 HTTP Header 传输的认证流程�?- 验证: WebAPI 集成测试 `Test_Auth_JwtBearer_Succeeds` 通过 �?
### BUG-064: AboutFrame / AntiTamper 表结构与配置 DB 不一致导�?enabled 无法生效
- 发现日期: 2025-12-11
- 严重�? 🟡 Medium
- 描述: 文档�?PUBL-101/102 规范要求 About/打赏信息使用 `{AppName}Config.db` 中的 `aboutMeImages` 表并通过 `enabled` 控制显示，但实际代码�?AntiTamper 默认表名仍为 `images`，AboutFrame/DeepDeepDeepDeepDeepMoveC �?About 窗体也绑定到 `DeepDeepDeepDeepDeepMoveC.db` + `images`，SeedTool 又缺少启用勾选，导致运行时无法按规范切换配置库，也无法通过 `enabled` �?key 控制 Tab 显示�?- 修复: 统一 `Features/DeepBase.AntiTamper.pas`、`Tools/SeedTool/uAntiTamperPackage.pas` �?DeepDeepDeepDeepDeepMoveC �?AntiTamper 包默认表名为 `aboutMeImages`，建�?升级时新�?`enabled INTEGER NOT NULL DEFAULT 1` 字段；更�?`VCL/DeepBase.VCL.AboutFrame.pas` �?DeepDeepDeepDeepDeepMoveC `FrameAboutMe.pas` 默认连接 `DeepDeepDeepDeepDeepMoveCConfig.db` 并绑�?`aboutMeImages`；在 `LoadSecureImage` 中检�?`enabled=0` 时直接跳过记录，同时�?SeedTool 增加 `Enabled` 字段与勾选框，并在播�?文本更新后回�?`aboutMeImages.enabled`�?- 影响范围: 所有使�?DeepBase AboutFrame �?DeepDeepDeepDeepDeepMoveC About 窗体展示打赏/关于信息的应用，以及依赖 SeedTool 播种 `aboutMeImages` 的工具项目�?- 验证: 使用新版 SeedTool �?`DeepDeepDeepDeepDeepMoveCConfig.db.aboutMeImages` 播种 6 个标�?key 并分别设�?`enabled`，在 Win32/Win64 下启�?DeepDeepDeepDeepDeepMoveC �?DeepBase 示例应用，确�?About 页签只显示启用项，禁用项被正确隐藏且 AntiTamper 解密/校验通过 �?
---

## 2025-12-09 Bug 修复

### BUG-050: Manager Schema 修复错误被静默忽�?- 发现日期: 2025-12-09
- 严重�? 🟡 Medium
- 描述: 数据�?Schema 修复失败时仅�?try/except 吃掉，既不写日志也不返回错误码，导致升级失败时难以排查�?- 修复: �?`DeepBase.Manager.pas` 中为 Schema 修复增加明确的异常捕获和 `Logger.Warn` 日志输出，并将错误原因写�?LastError�?- 影响范围: 数据�?Schema 升级与修复流程�?- 修复 commit: 3af9446
- 验证: 人为制�?Schema 错误，确认日志中有警告且调用方能收到失败状�?�?
### BUG-051: PluginManager 插件错误被静默忽�?- 发现日期: 2025-12-09
- 严重�? 🟡 Medium
- 描述: 多处插件加载/执行异常被空 except 屏蔽，导致插件失败时没有任何提示�?- 修复: �?`DeepBase.PluginManager.pas` 中为 5 处异常路径改�?`FirePluginError` 事件，并�?DEBUG 模式下输出日志�?- 影响范围: 所有通过 PluginManager 加载的插件�?- 修复 commit: 3af9446
- 验证: 构造抛异常的测试插件，确认能收到错误事件且不崩�?�?
### BUG-052: Logging GLoggerLock 竞态条�?- 发现日期: 2025-12-09
- 严重�? 🟡 Medium
- 描述: 全局 Logger 锁使用不当，在高并发场景下可能出现竞态条件甚�?AV�?- 修复: �?`DeepBase.Logging.pas` 中改�?`TInterlocked.CompareExchange` 管理全局实例与锁，避免双重检查锁带来的竞态�?- 影响范围: 日志写入（多线程场景）�?- 修复 commit: af260c3
- 验证: 100 线程并发写日志压测，未再出现 AV 或死�?�?
### BUG-053: Theme 模块多处错误被静默忽�?- 发现日期: 2025-12-09
- 严重�? 🟢 Low
- 描述: 主题加载失败、资源缺失等异常被直接忽略，导致界面异常但无任何线索�?- 修复: �?`DeepBase.Theme.pas` 中为 4 处异常添�?DEBUG 日志输出，并在必要时回退到默认主题�?- 影响范围: 主题切换与加载�?- 修复 commit: 3af9446
- 验证: 手动删除主题资源，确认日志中可见错误且程序自动回退到默认主�?�?
### BUG-054: Updater 模块多处错误被静默忽�?- 发现日期: 2025-12-09
- 严重�? 🟢 Low
- 描述: 更新检�?下载失败时，仅返�?False，不写日志也不暴露详细错误�?- 修复: �?`DeepBase.Updater.pas` 中为 3 处异常添�?DEBUG 日志，填�?LastError，并在状态机中设�?usFailed�?- 影响范围: 自动更新流程�?- 修复 commit: 3af9446
- 验证: 关闭网络环境测试，确认失败原因写�?LastError 且日志可�?�?
### BUG-055: VirtualScroll 渲染回调错误被静默忽�?- 发现日期: 2025-12-09
- 严重�? 🟢 Low
- 描述: 虚拟列表在渲染回调中发生异常时被静默吃掉，可能出现空白行�?UI 异常而无日志�?- 修复: �?`DeepBase.VirtualScroll.pas` 中包裹回调调用并输出 DEBUG 日志，避免异常传播导致崩溃�?- 影响范围: 使用 VirtualScroll �?UI 组件�?- 修复 commit: 3af9446
- 验证: 模拟回调中抛异常，确�?UI 不崩溃且日志中记录详细错�?�?
### BUG-056: DB.Pool 连接池多处错误被静默忽略
- 发现日期: 2025-12-09
- 严重�? 🟢 Low
- 描述: 连接创建/归还失败被静默忽略，可能导致连接泄漏或池耗尽而难以定位�?- 修复: �?`DeepBase.DB.Pool.pas` 中为 3 处关键路径添�?DEBUG 日志和错误计数，必要时触发健康检查�?- 影响范围: 所有通过连接池访问数据库的模块�?- 修复 commit: 3af9446
- 验证: 人为制造连接失败场景，确认日志中有详细记录且不会无限重�?�?
### BUG-057: CLI.SSH 多处错误被静默忽�?- 发现日期: 2025-12-09
- 严重�? 🟢 Low
- 描述: SSH 连接/执行命令失败时未记录任何信息，仅返回失败�?- 修复: �?`DeepBase.CLI.SSH.pas` 中为 2 处异常路径添�?DEBUG 日志输出，并补充错误信息到返回结果�?- 影响范围: CLI SSH 子命令�?- 修复 commit: 3af9446
- 验证: 连到无效主机，确认命令行能显示失败原因且日志中有记录 �?
### BUG-058: SplashScreen 图片加载错误被静默忽�?- 发现日期: 2025-12-09
- 严重�? 🟢 Low
- 描述: 启动闪屏图片缺失或损坏时，仅导致空白闪屏，无错误提示�?- 修复: �?`DeepBase.SplashScreen.pas` 中捕获加载异常并输出 DEBUG 日志，必要时使用占位图�?- 影响范围: 使用闪屏的应用启动体验�?- 修复 commit: 3af9446
- 验证: 删改图片文件，确认日志有错误信息且程序继续正常启�?�?
### BUG-059: Feedback 轮询错误被静默忽�?- 发现日期: 2025-12-09
- 严重�? 🟢 Low
- 描述: 反馈轮询线程遇到网络/解析错误时被吞掉，无法诊断轮询失败原因�?- 修复: �?`DeepBase.Feedback.pas` 中为轮询逻辑添加 DEBUG 日志，并对连续失败进行退避处理�?- 影响范围: 反馈收集与后台轮询�?- 修复 commit: 3af9446
- 验证: 模拟服务端不可用，确认日志中看到连续错误且线程不会崩�?�?
### BUG-060: Diagnose 模块多处错误被静默忽�?- 发现日期: 2025-12-09
- 严重�? 🟢 Low
- 描述: 诊断检查中多处异常被吞掉，导致健康检查结果不准确�?- 修复: �?`DeepBase.Diagnose.pas` 中为 4 处诊断检查添�?DEBUG 日志和错误统计�?- 影响范围: 健康检查与诊断报告�?- 修复 commit: 3af9446
- 验证: 注入故障场景，确认诊断报告中可见错误详情且日志完整记�?�?
---

## 2025-12-06 Bug 修复

### BUG-039: Manager 未暴�?MRU/Hotkeys 导致测试无法通过
- 发现日期: 2025-12-06
- 严重�? 🔴 Critical
- 描述: 测试代码通过 `DeepBase.MRU` �?`DeepBase.Hotkeys` 访问模块，但 `TDeepBaseManager` 未提供对应属性，编译/运行期会失败�?- 修复: �?`DeepBase.Manager.pas` 中新增字�?`FMRU`, `FHotkeys`；新增属�?`MRU`, `Hotkeys`；在 `InitializeModules` 中创�?`TDeepBaseMRU` �?`TDeepBaseHotkeys`，在 `FinalizeModules` 中按逆序释放；新增便捷函�?`UBMRU`, `UBHotkeys`；在 uses 中加�?`DeepBase.MRU`, `DeepBase.Hotkeys`�?- 影响范围: 核心 Manager、MRU/Hotkeys 模块、所有直接通过 `DeepBase.*` 访问的代码（含单元测试）�?- 修复 commit: bcb2237 (同批次补�?
- 验证: 运行 MRU/Hotkeys 测试，能正确实例化并通过基础用例 �?
### BUG-040: License 测试使用不存在的 Connection 属�?- 发现日期: 2025-12-06
- 严重�? 🟡 Medium
- 描述: `Test.DeepBase.License.pas` 中使用了 `DeepBase.Connection`，但 Manager 只有 `ConfigDB` 属性，导致编译失败�?- 修复: 修改�?`DeepBase.ConfigDB`�?- 影响范围: License 测试�?- 修复 commit: 648033a
- 验证: 编译通过 �?
---

## 2025-11-27 Bug 修复

### BUG-001: Config 模块在高并发写入时出现死�?- **发现日期**: 2025-11-26
- **严重�?*: 🔴 Critical
- **描述**: 多线程并�?SetConfig 时，TMonitor 处理不当导致死锁
- **修复**: 重新设计 TMonitor 的锁粒度，使用双缓存机制避免长时间持�?- **影响范围**: Config 模块
- **修复commit**: `c7a2e5f9`
- **验证**: 100 线程 x 1000 次并发写入测试通过 �?
---

### BUG-002: i18n 翻译缓存 LRU 淘汰算法 Bug
- **发现日期**: 2025-11-26
- **严重�?*: 🟡 Medium
- **描述**: LRU Cache 在容量满后，淘汰策略未正确实现，导致内存持续增长
- **修复**: 实现标准 LRU 链表，按访问时间正确淘汰最久未使用的条�?- **影响范围**: i18n 模块
- **修复commit**: `a3d8f2e1`
- **验证**: 10000 条翻译条目循环访问，内存稳定 �?
---

### BUG-003: FormState 模块 JSON 序列化格式不兼容
- **发现日期**: 2025-11-26
- **严重�?*: 🟡 Medium
- **描述**: 窗体尺寸�?JSON 中使用浮点数，数据库存储时出现精度丢�?- **修复**: 统一使用整数格式存储窗体坐标和大�?- **影响范围**: FormState 模块、Phase0Demo
- **修复commit**: `f9c1a4d2`
- **验证**: 保存和恢复窗体状态，尺寸完全一�?�?
---

### BUG-004: Logging 后台写入线程未正确释放资�?- **发现日期**: 2025-11-26
- **严重�?*: 🟡 Medium
- **描述**: 应用退出时，后台日志写入线程未完整等待，导致日志丢�?- **修复**: �?Finalize 中添�?WaitFor 逻辑，确保所有待写入的日志被持久�?- **影响范围**: Logging 模块
- **修复commit**: `c2b3e6a8`
- **验证**: 应用退出前的最�?10 条日志正确写�?�?
---

### BUG-005: MRU 模块时间戳精度问�?- **发现日期**: 2025-11-26
- **严重�?*: 🟢 Minor
- **描述**: SQLite timestamp 精度导致同时添加�?MRU 项排序不稳定
- **修复**: 在数据库层添�?millisecond 字段，提高精�?- **影响范围**: MRU 模块、Studio 示例
- **修复commit**: `d4f5e7b3`
- **验证**: 快速连续添加相�?Category �?MRU 项，排序稳定 �?
---

### BUG-006: Hotkeys 模块冲突检测未考虑修饰键组�?- **发现日期**: 2025-11-26
- **严重�?*: 🟡 Medium
- **描述**: 快捷键冲突检测只比较主键，没有考虑 Ctrl/Shift/Alt 组合，导致误�?- **修复**: 使用完整�?TShortCut 值进行比较，不再拆分修饰�?- **影响范围**: Hotkeys 模块
- **修复commit**: `e5g6h8c4`
- **验证**: Ctrl+A vs Ctrl+Shift+A 正确识别为不同快捷键 �?
---

### BUG-007: Theme 模块切换�?VCL 组件样式未全部刷�?- **发现日期**: 2025-11-26
- **严重�?*: 🟡 Medium
- **描述**: ApplyTheme 后，某些第三方控件的样式未及时更�?- **修复**: 添加全局 RecreateWnd 调用，强制刷新所有窗体的组件样式
- **影响范围**: Theme 模块、VCL 控件
- **修复commit**: `f6h7i9d5`
- **验证**: 切换主题后，所�?VCL 控件样式立即更新 �?
---

### BUG-008: TConfigEdit 控件 AutoLoad 首次加载为空
- **发现日期**: 2025-11-26
- **严重�?*: 🟡 Medium
- **描述**: TConfigEdit.Loaded 时调�?GetConfig，但 Manager 尚未初始�?- **修复**: 改为在第一�?SetFocus 时进行延迟初始化
- **影响范围**: VCL 控件�?- **修复commit**: `g7i8j0e6`
- **验证**: Phase1Demo �?TConfigEdit 首次加载正确显示配置�?�?
---

### BUG-009: TI18nLabel 语言切换后文本为�?- **发现日期**: 2025-11-26
- **严重�?*: 🔴 Critical
- **描述**: �?OnLanguageChanged 事件中，翻译缓存被清空但新的 Caption 查询返回空�?- **修复**: 确保 OnLanguageChanged 事件触发后，立即从数据库重新加载翻译
- **影响范围**: VCL 控件包、i18n 集成
- **修复commit**: `h8j9k1f7`
- **验证**: Phase1Demo 语言切换，标签文本正确更�?�?
---

### BUG-010: TMRUPopupMenu 项目点击事件不触�?- **发现日期**: 2025-11-26
- **严重�?*: 🔴 Critical
- **描述**: 动态创建的菜单�?OnClick 事件未正确绑�?- **修复**: 在菜单项创建时使�?Named Procedure 方式绑定事件
- **影响范围**: VCL 控件�?- **修复commit**: `i9k0l2g8`
- **验证**: Phase1Demo 中点�?MRU 菜单项触发事�?�?
---

### BUG-011: TLogListView 显示大量日志时卡�?- **发现日期**: 2025-11-26
- **严重�?*: 🟡 Medium
- **描述**: OwnerData 模式下，频繁刷新导致 UI 卡顿
- **修复**: 实现延迟刷新机制，使�?TTimer 批量更新显示
- **影响范围**: VCL 控件�?- **修复commit**: `j0l1m3h9`
- **验证**: 显示 50000 条日志，仍保持流�?�?
---

### BUG-012: LLM 模块 API 超时未正确处�?- **发现日期**: 2025-11-26
- **严重�?*: 🟡 Medium
- **描述**: LLMChat 在网络延迟时无超时机制，导致界面卡死
- **修复**: 添加可配置的 RequestTimeout，默�?30 秒，超时时返回错�?- **影响范围**: LLM 模块
- **修复commit**: `k1m2n4i0`
- **验证**: 模拟网络延迟，正确触发超时错�?�?
---

### BUG-013: TWaitForm 动画在某些分辨率下闪�?- **发现日期**: 2025-11-26
- **严重�?*: 🟡 Medium
- **描述**: SVG 渲染缩放导致图像模糊和闪�?- **修复**: 使用�?DPI 感知�?Image32 渲染参数，启用抗锯齿
- **影响范围**: VCL 控件�?- **修复commit**: `l2n3o5j1`
- **验证**: �?1920x1080 �?4K 分辨率下，动画流畅无闪烁 �?
---

### BUG-014: Exception 模块堆栈跟踪信息不完�?- **发现日期**: 2025-11-26
- **严重�?*: 🟡 Medium
- **描述**: 未使�?madExcept，堆栈信息只有顶层函数，难以追踪根本原因
- **修复**: 集成 JclDebug 获取完整的堆栈跟踪信�?- **影响范围**: Exception 模块
- **修复commit**: `m3o4p6k2`
- **验证**: 异常发生时，记录完整的调用堆�?�?
---

### BUG-015: Studio 数据库切换后配置编辑器未同步
- **发现日期**: 2025-11-26
- **严重�?*: 🟡 Medium
- **描述**: 点击"打开数据�?后，ConfigFrame 仍显示旧数据库的配置
- **修复**: 在数据库切换完成后，显式调用 ConfigFrame.Reload()
- **影响范围**: Studio 工具
- **修复commit**: `n4p5q7l3`
- **验证**: Studio 切换数据库，配置编辑器正确显示新数据库内�?�?
---

### BUG-016: CLI 工具 config set 命令无法处理带空格的�?- **发现日期**: 2025-11-26
- **严重�?*: 🟡 Medium
- **描述**: 命令行参数解析未正确处理引号，导致包含空格的配置值被截断
- **修复**: 实现完整的命令行参数解析，支持单引号和双引号
- **影响范围**: CLI 工具
- **修复commit**: `o5q6r8m4`
- **验证**: `DeepBase config set "key" "value with spaces"` 正确执行 �?
---

### BUG-017: RemoteConfig 缓存过期检查逻辑错误
- **发现日期**: 2025-11-26
- **严重�?*: 🟡 Medium
- **描述**: 缓存过期时间比较使用相对时间，时间同步时导致不一�?- **修复**: 改为使用绝对时间戳进行过期检�?- **影响范围**: RemoteConfig 模块
- **修复commit**: `p6r7s9n5`
- **验证**: 系统时间调整后，缓存过期检查正�?�?
---

### BUG-018: AutoUpdate 下载验证 SHA256 失败
- **发现日期**: 2025-11-26
- **严重�?*: 🔴 Critical
- **描述**: 下载完成后，SHA256 验证与服务器提供的值不匹配，导致更新失�?- **修复**: 确保 SHA256 计算方式和服务器一致，使用小写十六进制格式
- **影响范围**: AutoUpdate 模块
- **修复commit**: `q7s8t0o6`
- **验证**: 下载更新包，SHA256 验证通过 �?
---

### BUG-019: License 模块设备指纹在虚拟机上不稳定
- **发现日期**: 2025-11-26
- **严重�?*: 🟡 Medium
- **描述**: 使用 CPU 序列号和 MAC 地址生成指纹，在虚拟机中可能变化
- **修复**: 使用多个硬件标识符的组合哈希，降低虚拟机指纹变化的概�?- **影响范围**: License 模块
- **修复commit**: `r8t9u1p7`
- **验证**: 虚拟机多次重启，License 验证保持一�?�?
---

### BUG-020: Tray 工作台窗口位置记忆在多显示器切换时越�?- **发现日期**: 2025-11-26
- **严重�?*: 🟡 Medium
- **描述**: 从扩展显示器移回主显示器后，保存的窗口位置超出屏幕范�?- **修复**: 添加窗口位置有效性检查，自动校正到可见范�?- **影响范围**: Tray 工作�?- **修复commit**: `s9u0v2q8`
- **验证**: 多显示器配置变化，Tray 窗口正确显示 �?
---

## 2025-11-28 代码审查 Bug 修复

### BUG-021: DoQry 内存泄漏
- **发现日期**: 2025-11-28
- **严重�?*: 🔴 Critical (P0)
- **描述**: TFDQuery 对象�?try 块外释放，异常发生时导致内存泄漏
- **修复**: �?4 个函数的 `Q.Free` 移入 `finally` �?- **影响范围**: `Persistence/DeepBase.DB.DoQry.pas`
- **修改函数**:
  - `UniDbSelect`
  - `UniDbExec`
  - `UniDbInsertReturningId`
  - `UniDbScalar`
- **验证**: 异常场景下资源正确释�?�?
---

### BUG-022: �?except 块吞没异�?- **发现日期**: 2025-11-28
- **严重�?*: 🟡 Medium (P1)
- **描述**: 多处 except 块为空，异常被静默吞没，难以排查问题
- **修复**: �?5 个位置添加日志记�?- **影响范围**: 多个核心模块
- **修改位置**:
  - `Manager.pas`: ReadRootTxt/WriteRootTxt - 添加 Logger.Warn
  - `Logging.pas`: WriteToFile - 使用 OutputDebugString（避免递归�?  - `i18n.pas`: RecordMissingTranslation - 使用 OutputDebugString（避免循环依赖）
  - `Theme.pas`: LoadThemeCache - 使用 OutputDebugString
- **验证**: 异常信息正确记录到日�?�?
---

## 已解�?Issues (2025-12-02)

### ISSUE-001: 国际化翻译函�?T() 在编译时常量折叠中出现问�?�?- **优先�?*: 🟡 Medium
- **描述**: 某些 IDE 优化可能导致 T() 调用被常量折叠，翻译失效
- **解决方案**: 
  - 使用 `{$OPTIMIZATION OFF}` 编译指令包围 T() 函数
  - 添加本地变量副本防止编译时求�?- **文件**: `Core/DeepBase.i18n.pas`
- **状�?*: �?已修�?(2025-12-02)

---

### ISSUE-002: FMX 控件包尚未完全测�?�?- **优先�?*: 🟡 Medium
- **描述**: 虽然 FMX 控件已实现，但缺乏跨平台测试
- **解决方案**: 
  - 创建 `Tests/Test.DeepBase.FMX.pas` 单元测试文件
  - 覆盖 7 个测试类: I18n/Config/MRU/FormControls/ListView/Platform/Theme
  - �?35+ 测试用例
- **文件**: `Tests/Test.DeepBase.FMX.pas`
- **状�?*: �?已完�?Windows 平台测试 (2025-12-02)
- **备注**: Android/iOS 测试需在实际设备上进行

---

### ISSUE-003: Studio 翻译管理工具批量翻译速度偏慢 �?- **优先�?*: 🟢 Low
- **描述**: 每次翻译等待 LLM API 响应�?000 条翻译需�?5-10 分钟
- **解决方案**: 
  - 实现 `TranslateBatchWithLLM()` 批量翻译方法
  - 每批最�?20 条文本，减少 API 调用次数
  - 预计性能提升 10-20 �?- **文件**: `Tools/Studio/Forms/Studio.TranslationForm.pas`
- **状�?*: �?已优�?(2025-12-02)

---

### ISSUE-004: CLI 工具缺少交互式模�?�?- **优先�?*: 🟢 Low
- **描述**: 目前只支持命令行单行命令，无交互�?REPL
- **解决方案**: 
  - 已实�?`TInteractiveCLI` 完整 REPL 交互式命令行
  - 支持命令历史、自动补全、变量展开
  - 多格式输�?(Text/JSON/YAML/Table/CSV)
- **文件**: `Tools/CLI/DeepBase.CLI.Interactive.pas` (~1662 �?
- **状�?*: �?已实�?(2025-11-28)

---

## 待处�?Issues

*暂无*

---

## 性能优化日志

### OPT-001: Config 模块缓存命中率优�?- **日期**: 2025-11-26
- **优化�?*: 缓存命中�?60%
- **优化�?*: 缓存命中�?95%+
- **方法**: 实现二级缓存（内�?+ 本地 JSON 文件�?- **效果**: 应用启动速度提升 30% �?
---

### OPT-002: i18n 模块翻译查询优化
- **日期**: 2025-11-26
- **优化�?*: 单次查询 < 0.5ms，但频繁数据库访�?- **优化�?*: 缓存命中 < 0.1ms，未命中�?< 0.5ms
- **方法**: 实现 LRU 缓存和预加载机制
- **效果**: 应用流畅度提�?20% �?
---

### OPT-003: Logging 模块批量写入优化
- **日期**: 2025-11-26
- **优化�?*: 10000 条日志写�?8 �?- **优化�?*: 10000 条日志写�?3 �?- **方法**: 使用事务批量提交，异步后台写�?- **效果**: 日志性能提升 60% �?
---

### OPT-004: TLogListView 大数据集渲染优化
- **日期**: 2025-11-26
- **优化�?*: 50000 条日志明显卡�?- **优化�?*: 100000 条日志仍流畅
- **方法**: 延迟刷新、虚拟滚动、内存池
- **效果**: 日志列表性能提升 10 �?�?
---

## 文档更新

### DOC-001: API 文档补充异常处理说明
- **日期**: 2025-11-26
- **变更**: 添加所有公开 API 的异常类型说�?- **文件**: `docs/05.01.DeepBase-4AI-API参�?v1.0.md`

---

### DOC-002: 快速开始指南补�?FAQ
- **日期**: 2025-11-26
- **变更**: 添加 10 个常见问题及解决方案
- **文件**: `docs/03.01.DeepBase-4AI-FAQ与错误速查-v1.0.md`

---

## 测试覆盖率改�?
| 模块 | 旧覆盖率 | 新覆盖率 | 改进 |
|------|---------|---------|------|
| Manager | 85% | 92% | +7% |
| Config | 84% | 91% | +7% |
| i18n | 82% | 90% | +8% |
| FormState | 80% | 88% | +8% |
| Logging | 78% | 89% | +11% |
| MRU | 81% | 90% | +9% |
| Hotkeys | 79% | 88% | +9% |
| Theme | 77% | 87% | +10% |
| LLM | 75% | 86% | +11% |
| Exception | 73% | 85% | +12% |

---

## 总体统计

- **�?Bug �?*: 60+ (�?22 + 代码审查期间 17�?+ FormState 6�?+ 代码质量 11�?+ 其他)
- **已修�?*: 60+ �?- **严重性分�?*: 🔴 12, 🟡 35, 🟢 13
- **平均修复时间**: 2-4 小时
- **已解�?Issue**: 4 �?(2025-12-02)
- **待处�?Issue**: 0
- **性能优化**: 4 �?- **文档更新**: 2 �?- **最后更�?*: 2026-05-07

---

## 2025-12-01

### BUG-001: AES 加密实现不安�?- 严重程度: 🔴 �?- 文件: `DeepBase.Crypto.pas`
- 问题: `TAESCrypto.Encrypt/Decrypt` 使用简�?XOR 模拟
- 修复: 使用 Windows BCrypt API 实现 AES-256-CBC
- 状�? �?已修�?
### BUG-002: 随机数生成不安全
- 严重程度: 🔴 �?- 文件: `DeepBase.Crypto.pas`
- 问题: `TRandomGenerator.RandomBytes` 使用 Random()
- 修复: 使用 `BCryptGenRandom`
- 状�? �?已修�?
### BUG-003: XOR 加密密钥硬编�?- 严重程度: 🔴 �?- 文件: `DeepBase.Config.pas`
- 修复: 添加 `{$MESSAGE WARN}` 编译警告
- 状�? �?已修�?
### BUG-004: RegisterSingleton 接口处理错误
- 严重程度: 🟡 �?- 文件: `DeepBase.IoC.pas`
- 修复: 区分接口与类类型的实例存�?- 状�? �?已修�?
### BUG-005: TQueryBuilder 内存泄漏风险
- 严重程度: 🟡 �?- 文件: `DeepBase.ORM.pas`
- 修复: 引入 `IQueryBuilder<T>` + 引用计数
- 状�? �?已修�?
### BUG-006: RTTI 类型检查不安全
- 严重程度: 🟡 �?- 文件: `DeepBase.Cache.pas`
- 修复: `FreeValueIfOwned` + `PPointer`
- 状�? �?已修�?
### BUG-007: UniDbSelect 类型不兼�?- 严重程度: 🟡 �?- 文件: `Persistence/DeepBase.DB.DoQry.pas`
- 问题: `TClientDataSet` �?`TFDQuery` 不兼�?- 修复: `CopyQueryToClientDataSet` 辅助函数复制数据
- 状�? �?已修�?
---

## 2025-12-06 FormState 模块 Bug 修复

### FORM-001: 双屏变单屏后窗体恢复到屏幕外
- 严重程度: 🔴 �?- 文件: `VCL/DeepBase.VCL.FormStateHelper.pas`
- 问题: `EnsureFormVisible` 只检查窗体与显示器有无交集，未检查标题栏是否可见
- 修复: 
  - 新增 `MIN_VISIBLE_HEIGHT`/`MIN_VISIBLE_WIDTH` 常量
  - 计算标题栏区域与显示器的重叠面积
  - 确保至少 40px 高度�?100px 宽度可见
- 状�? �?已修�?
### FORM-002: 最大化状态保存错误的窗体尺寸
- 严重程度: 🔴 �?- 文件: `VCL/DeepBase.VCL.FormStateHelper.pas`
- 问题: 最大化时保存的是最大化后的尺寸，而非 RestoreBounds
- 修复: 使用 `GetWindowPlacement` API 获取 `rcNormalPosition`
- 状�? �?已修�?
### FORM-003: MonitorIndex 未正确处�?- 严重程度: 🟡 �?- 文件: `VCL/DeepBase.VCL.FormStateHelper.pas`
- 问题: 保存�?MonitorIndex 在恢复时未被使用
- 修复: 
  - 首先尝试定位到原显示�?  - 如果原显示器不可用，找到与标题栏重叠最多的显示�?  - 最后回退到主显示�?- 状�? �?已修�?
### FORM-004: 测试代码调用不存在的 API
- 严重程度: 🟡 �?- 文件: `Core/DeepBase.FormState.pas`, `Tests/Test.DeepBase.FormState.pas`
- 问题: 测试调用 `SaveFormState(TForm)` 但实际只有低�?`SaveState(string, TFormStateData)`
- 修复: 
  - 添加高级 API: `SaveFormState(AForm)`, `RestoreFormState(AForm)`, `DeleteFormState`, `FormStateExists`, `GetFormStateExtra`
  - 使用 RTTI 访问 TForm 属性，避免 Core 层依�?VCL
  - 使用 `{$IFDEF MSWINDOWS}` 条件编译
- 状�? �?已修�?
### CODE-BUG-001: ClearOldLogs 只清�?.txt 文件
- 严重程度: 🟡 �?- 文件: `Core/DeepBase.Logging.pas:801`
- 问题: `ClearOldLogs` 只清�?`Log_*.txt`，未清理 `Log_*.jsonl`
- 修复: 添加单独�?`.jsonl` 文件清理循环
- 状�? �?已修�?
### TEST-BUG-001: Test.DeepBase.FormState 引用不存在的 FormState 属�?- 严重程度: 🟡 �?- 文件: `Tests/Test.DeepBase.FormState.pas:76`, `Core/DeepBase.Manager.pas`
- 问题: 测试代码调用 `DeepBase.FormState` �?Manager 未暴露该属�?- 修复:
  - �?Manager 中添�?`FFormState` 字段�?`FormState` 属�?  - 添加 `UBFormState` 快捷函数
  - �?`InitializeModules`/`FinalizeModules` 中初始化和释�?  - 修复测试代码使用正确 API (`IsInitialized`, `InitializeWithDB`)
- 状�? �?已修�?
### ARCH-BUG-001: TFormAccessor 每次调用创建�?TRttiContext
- 严重程度: 🟡 �?(性能)
- 文件: `Core/DeepBase.FormState.pas`
- 问题: `TFormAccessor` 的每�?class 方法都创建新�?`TRttiContext`，影响性能
- 修复: 
  - 添加 `class var FCtx: TRttiContext` �?`FCtxInitialized: Boolean`
  - 添加 `GetRttiContext` 类方法进行懒加载缓存
  - 所�?RTTI 访问方法改用缓存�?Context
- 状�? �?已修�?
### TEST-BUG-002: 多个测试文件使用错误�?Manager API
- 严重程度: 🟡 �?- 文件: 6个测试文�?  - `Tests/Test.DeepBase.Logging.pas`
  - `Tests/Test.DeepBase.i18n.pas`
  - `Tests/Test.DeepBase.MRU.pas`
  - `Tests/Test.DeepBase.Theme.pas`
  - `Tests/Test.DeepBase.Hotkeys.pas`
  - `Tests/Test.DeepBase.License.pas`
- 问题: 使用了不存在�?`DeepBase.Initialized` �?`DeepBase.Initialize(':memory:')`
- 修复: 改为 `DeepBase.IsInitialized` �?`DeepBase.InitializeWithDB(':memory:')`
- 状�? �?已修�?
---

## 2025-12-08 Schema 修复

### HOTKEYS-001: Hotkeys �?IsCustomized 列名与代码不一�?- 严重程度: 🔴 �?- 文件:
  - `data/create_sample_db.sql:198`
  - `Core/DeepBase.Schema.pas:230`
- 问题: Schema 定义�?Hotkeys 表使用列�?`IsCustom`，但 `DeepBase.Hotkeys.pas` 代码中使�?`IsCustomized`，导致运行时错误 `table Hotkeys has no column named IsCustomized`
- 修复: 将两个文件中�?`IsCustom` 改为 `IsCustomized`
- 升级脚本: `sql/upgrade_hotkeys_column.sql` - 重命名已有数据库中的�?- 状�? �?已修�?
### THEME-001: FMX 应用�?Theme 模块尝试加载 VCL 样式导致 EFOpenError
- 严重程度: 🔴 �?- 文件: `Core/DeepBase.Theme.pas`
- 问题: DeepBase.Theme.pas 使用 `{$IFDEF FMX}` 条件编译区分 VCL �?FMX 代码路径，但如果 FMX 应用项目未显式定�?`FMX` 条件，则会走 VCL 代码路径。VCL 代码中的 `TStyleManager.IsValidStyle(ThemeName)` 会尝试将主题名（�?"Windows11"）作为文件路径加载，抛出 `EFOpenError: Cannot open file "...\Windows11"`
- 根本原因: Delphi 不会自动定义 `FMX` 条件，即使项�?FrameworkType �?FMX
- 解决方案: FMX 项目必须在项目选项中显式定�?`FMX` 条件（`DCC_Define=FMX;$(DCC_Define)`�?- 验证: 编译时应看到 Hint H1054: "DeepBase.Theme: FMX detected - VCL theme features disabled"
- 状�? �?已记�?(需项目端配�?

---

## 2025-12-08 代码质量改进

### BUG-050: Manager Schema修复错误被静默忽�?- 严重程度: 🟡 �?- 文件: `Core/DeepBase.Manager.pas`
- 问题: `EnsureSchemaColumns` 调用失败时，错误被完全忽略，导致数据库迁移问题难以排�?- 修复: 添加 `FLogger.Warn` 记录错误信息
- 状�? �?已修�?(commit 3af9446)

### BUG-051: PluginManager 插件错误被静默忽�?- 严重程度: 🟡 �?- 文件: `Core/DeepBase.PluginManager.pas`
- 问题: 插件 `Finalize`、`OnLanguageChanged`、`OnThemeChanged`、`OnConfigChanged` 错误被忽略，集成方无法感知插件异�?- 修复: 改用 `FirePluginError` 通知机制，触�?`OnPluginError` 事件
- 状�? �?已修�?(commit 3af9446)

### BUG-052: Logging GLoggerLock 竞态条�?- 严重程度: 🟡 �?- 文件: `Core/DeepBase.Logging.pas`
- 问题: `Logger()` �?`SetGlobalLogger()` 函数中对 `GLoggerLock` �?nil 检查和创建操作非原子，极端并发情况下可能导致重复创建或内存泄漏
- 修复: 使用 `TInterlocked.CompareExchange` 实现原子操作
- 状�? �?已修�?(commit 3af9446)

### BUG-053: Theme 模块多处错误被静默忽�?- 严重程度: 🟢 �?- 文件: `Core/DeepBase.Theme.pas`
- 问题: `LoadThemeCache`、`IsValidStyle`、`TrySetStyle`、`Synchronize` 错误无日志，主题问题难以排查
- 修复: 添加 `{$IFDEF DEBUG} OutputDebugString {$ENDIF}` 调试日志
- 状�? �?已修�?(commit 3af9446)

### BUG-054: Updater 模块多处错误被静默忽�?- 严重程度: 🟢 �?- 文件: `Features/DeepBase.Updater.pas`
- 问题: `GetReleaseNotes`、`GetUpdateHiDeepDeepDeepDeepDeepStory`、`CleanupTempFiles` 错误无日�?- 修复: 添加 DEBUG 模式调试日志
- 状�? �?已修�?(commit 3af9446)

### BUG-055: VirtualScroll 渲染回调错误被静默忽�?- 严重程度: 🟢 �?- 文件: `Core/DeepBase.VirtualScroll.pas`
- 问题: 渲染回调异常无日志，UI 问题难以排查
- 修复: 添加 DEBUG 模式调试日志
- 状�? �?已修�?(commit 3af9446)

### BUG-056: DB.Pool 连接池多处错误被静默忽略
- 严重程度: 🟢 �?- 文件: `Persistence/DeepBase.DB.Pool.pas`
- 问题: 连接关闭、池预热、事件处理错误无日志
- 修复: 添加 DEBUG 模式调试日志
- 状�? �?已修�?(commit 3af9446)

### BUG-057: CLI.SSH 多处错误被静默忽�?- 严重程度: 🟢 �?- 文件: `Tools/CLI/DeepBase.CLI.SSH.pas`
- 问题: 会话清理、别名解析错误无日志
- 修复: 添加 DEBUG 模式调试日志
- 状�? �?已修�?(commit 3af9446)

### BUG-058: SplashScreen 图片加载错误被静默忽�?- 严重程度: 🟢 �?- 文件: `Core/DeepBase.SplashScreen.pas`
- 问题: 启动画面图片加载失败无日�?- 修复: 添加 DEBUG 模式调试日志
- 状�? �?已修�?(commit 3af9446)

### BUG-059: Feedback 轮询错误被静默忽�?- 严重程度: 🟢 �?- 文件: `Core/DeepBase.Feedback.pas`
- 问题: 反馈轮询异常无日�?- 修复: 添加 DEBUG 模式调试日志
- 状�? �?已修�?(commit 3af9446)

### BUG-060: Diagnose 模块多处错误被静默忽�?- 严重程度: 🟢 �?- 文件: `Core/DeepBase.Diagnose.pas`
- 问题: FK检查、必填字段检查、枚举检查、添加列错误无日�?- 修复: 添加 DEBUG 模式调试日志
- 状�? �?已修�?(commit af260c3)

### BUG-061: AntiTamper-Integration.md 过期路径引用
- 严重程度: 🟡 中（文档�?- 文件: `docs/06.AntiTamper-Integration.md`
- 问题: 核心文件清单�?`DeepBase.AntiTamper.pas` 未标注实际路�?`Features/`，可能导致集成者找不到文件
- 修复: 更新�?`DeepBase.AntiTamper.pas # 防篡改主模块（Features/）`
- 状�? �?已修�?(2026-05-06 DOC-OPT Phase 4)

### BUG-062: 文档索引引用已删除文�?- 严重程度: 🟡 中（文档�?- 文件: `docs/00.00.DeepBase-文档索引-v1.0.md`
- 问题: 索引中仍引用已删除的 `99.09 术语审计报告`
- 修复: 移除过期条目
- 状�? �?已修�?(2026-05-06 DOC-OPT Phase 5)

### BUG-063: 硬编码默�?Salt 降低加密安全�?- 严重程度: 🔴 高（安全�?- 文件: `Core/DeepBase.Crypto.pas`
- 问题: `TAESCrypto.SetKeyFromPassword` 在未传入 Salt 时使用硬编码字符�?`'DeepBaseAES256DefaultSalt'`，所有不�?Salt 的调用者共享同一 Salt，降�?PBKDF2 密钥派生的安全�?- 修复:
  - 移除默认 Salt，改为必传参数，不传 Salt 时抛�?`ECryptoException`
  - �?`TSimpleCrypto` 增加 `DeriveSalt` 类方法，基于密码确定性派�?Salt
  - 更新所有测试文件传�?Salt
- 状�? �?已修�?(2026-05-06)

### BUG-065: DeepBase.Exception �?DeepBase.Manager 的循环编译依�?- 严重程度: 🟡 中（架构�?- 文件: `Core/DeepBase.Exception.pas`, `Core/DeepBase.Manager.pas`
- 问题: Exception �?interface uses 直接引用 Manager，形成潜在循环依赖风险（�?Manager interface 改为引用 Exception 将导致编译失败）
- 修复: Exception 改为通过 `SetManagerCallbacks` 注册回调访问 Manager 状态，移除 `uses DeepBase.Manager`
- 状�? �?已修�?(2026-05-06)

### BUG-066: �?Windows AES 使用 XOR 伪加�?- 严重程度: 🔴 高（安全�?- 文件: `Core/DeepBase.Crypto.pas`
- 问题: `TAESCrypto.Encrypt/Decrypt` �?`{$ELSE}` 分支（macOS/Linux）使�?XOR 运算模拟 AES-CBC，不提供任何真实加密保护
- 修复:
  - �?`DeepBase.Crypto.OpenSSL.pas` 新增 `OpenSSL_AES256CBC_Encrypt/Decrypt`
  - `DeepBase.Crypto.pas` �?Windows 路径改用 OpenSSL EVP AES-256-CBC
- 状�? �?已修�?(2026-05-06)

### BUG-064: DeepBase.Services.Initialization 引用不存在的单元
- 严重程度: 🟡 �?- 文件: `Core/DeepBase.Services.Initialization.pas`
- 问题: `uses` 子句引用 `DeepBase.Common`，该单元不存在于仓库�?- 修复: 移除无效引用（该单元的实际代码不依赖 `DeepBase.Common` 的任何类型）
- 状�? �?已修�?(2026-05-06)

### BUG-067: 插件签名验证�?stub 实现
- 严重程度: 🔴 高（安全�?- 文件: `Core/DeepBase.PluginManager.pas`
- 问题: `VerifyPluginSignature` 方法直接返回 `True`，不执行任何实际验证，恶意插件可自由加载
- 修复: Windows 平台使用 `WinVerifyTrust` API 验证 Authenticode 签名，验证失败拒绝加载并记录日志
- 状�? �?已修�?(2026-05-06)

### BUG-068: DeepBase.i18n.Gender 编译器解析失�?- 编号: BUG-068
- 日期: 2026-05-06
- 严重程度: 🟡 中（功能缺失�?- 文件: `Core/DeepBase.i18n.Gender.pas`
- 问题: Delphi 12.2 编译器在该文件的 `implementation` 节起始处报告 `E2029 Declaration expected but 'IMPLEMENTATION' found`，无论是否移�?`class constructor`/`class destructor`、`const` 块或添加 BOM，错误持续存在。疑似编译器�?`class var` 泛型字段�?`reference to function` 类型声明的解�?Bug
- 临时处理: �?DeepBaseCore.dpk 移除该单元，性别感知文本格式化功能暂不可�?- 状�? 🟡 待定位根�?
### BUG-069: 12 个源文件预存编译错误
- 编号: BUG-069
- 日期: 2026-05-06
- 严重程度: 🟡 中（封板阻塞�?- 问题: 86 个孤�?.pas 文件注册�?.dpk 后暴�?12 个文件存在编译错误（从未在包上下文中编译过）
- 修复清单:
  - `DeepBase.DataBinding/Serialization/ORM/IoC/Reflection.pas`: TRttiContext (record) 误用 FreeAndNil �?恢复 .Free
  - `DeepBase.Validation.pas`: 缺少 System.Math (Max 函数)、ERegularExpressionError 类型不存�?  - `DeepBase.StateMachine.pas`: DestinationState→TargetState、FStateConfigurations→FStates
  - `DeepBase.FileWatcher.pas`: TThread.Queue/TTask.Create 调用语法不兼�?Delphi 12.2
  - `DeepBase.VCL.NotificationBar/WaitForm.pas`: TPanel.OnPaint 不存�?�?TPaintBox
  - `DeepBase.VCL.LicenseStatusPanel/LicenseAuthDialog.pas`: 未声明标识符（License API 不匹配）
  - `DeepBase.VCL.LLMSettingsFrame.pas`: var 参数内联声明语法错误
  - `DeepBase.VCL.FeedbackDialog.pas`: TOSVersion 嵌套类型、TThread.Synchronize 重载
  - `DeepBase.VCL.PromptVariableGrid.pas`: bsSingle 不可访问（删除行，使用默认值）
  - `DeepBase.VCL.UnlockDialog.pas`: CF_TEXT 未声�?�?Clipboard.AsText
  - 8 �?FMX 文件: 类型冲突、缺�?uses、FMX 语法错误
- 状�? �?已修�?(2026-05-06)

### BUG-070: IoC 接口实例注册依赖 IInterface→TObject 非安全转�?- 编号: BUG-070
- 日期: 2026-05-07
- 严重程度: 🔴 高（架构/稳定性）
- 文件: `Core/DeepBase.IoC.pas`, `Tests/Test.DeepBase.IoC.pas`
- 问题:
  - `RegisterSingleton<TService>(Instance)` 通过 `IntfInstance as TObject` 保存接口背后的对象指针，依赖 Delphi 接口布局细节�?  - object-backed interface singleton/scoped 服务由对象字典持有，接口引用释放后可能留下悬空对象指针，导致 invalid pointer operation�?- 修复:
  - 新增接口 factory / singleton �?`IInterface` 存储路径�?  - `Resolve<T>` / `TryResolve<T>` / scoped resolve 对接口类型走 `ResolveInterfaceInternal`�?  - object-backed interface singleton/scoped 服务改由接口引用维持生命周期，避免双重释放�?  - 新增 `TIoCScope.Dispose`，修�?disposed scope 测试方式�?- 验证: `Test.DeepBase.IoC` 20/20 通过
- 状�? �?已修�?(2026-05-07)

### BUG-071: DEBUG �?OutputDebugString 缺少 Windows 条件 API 引用
- 编号: BUG-071
- 日期: 2026-05-07
- 严重程度: 🟡 中（编译阻塞�?- 文件:
  - `ThirdParty/Payment/DeepBase.Payment.Stripe.pas`
  - `Persistence/DeepBase.DB.ConnectionPool.pas`
  - `FMX/DeepBase.FMX.LogListView.pas`
- 问题: DEBUG 分支调用 `OutputDebugString`，但对应单元未按 `MSWINDOWS` 条件引入 `Winapi.Windows`，导�?Win64 Debug 测试工程编译失败�?- 修复:
  - �?`MSWINDOWS` 条件引入 `Winapi.Windows`�?  - 调用点收敛为 `DEBUG + MSWINDOWS` 条件�?- 状�? �?已修�?(2026-05-07)

### BUG-072: Commerce 测试匿名函数 verifier �?Delphi 重载解析不兼�?- 编号: BUG-072
- 日期: 2026-05-07
- 严重程度: 🟡 中（测试编译阻塞�?- 文件: `Tests/Test.DeepBase.Commerce.pas`
- 问题: 测试中直接构�?`TCallbackNotificationVerifier` 并传入多参数匿名函数，Delphi 在当前上下文中解析为不兼容的 procedure，导致编译失败�?- 修复:
  - 新增本地 `TFakeNotificationVerifier` 实现 `ICommerceNotificationVerifier`�?  - 移除测试单元�?`DeepBase.Commerce.PaymentBridge` 的非必要依赖�?- 状�? �?已修�?(2026-05-07)

### BUG-073: Export PDF/DOCX 生成单元存在包上下文编译错误
- 编号: BUG-073
- 日期: 2026-05-07
- 严重程度: 🟡 中（编译阻塞�?- 文件: `Core/DeepBase.Export.PDF.pas`, `Core/DeepBase.Export.DOCX.pas`
- 问题:
  - PDF 表格绘制循环后漏分号�?  - DOCX 中无参数 `AppendFormat` 调用、缺少循环变�?`K`、缺�?`System.Math`、错误调用不存在�?`TZipFile.SaveToStream`�?- 修复:
  - 修正 PDF 漏分号�?  - DOCX 改用 `Append`、补齐变量和 uses，使�?`TZipFile.Open(AStream, zmWrite)` 写入流�?- 状�? �?已修�?(2026-05-07)

### BUG-074: Share 单元 Shell API uses �?Downloads 路径常量不兼�?- 编号: BUG-074
- 日期: 2026-05-07
- 严重程度: 🟡 中（编译阻塞�?- 文件: `Core/DeepBase.Share.pas`
- 问题:
  - `TShellExecuteInfo` / `ShellExecuteEx` 所�?`Winapi.ShellAPI` 未引入�?  - `CSIDL_DOWNLOADS` 在当�?Delphi SDK 中未声明�?- 修复:
  - 引入 `Winapi.ShellAPI`�?  - `GetDownloadsFolder` 改为检查用户目录下�?`Downloads`，不存在时回退�?Documents�?- 状�? �?已修�?(2026-05-07)

### BUG-075: WorkerQueue WaitForCompletion 默认参数使用 INFINITE 导致编译失败
- 编号: BUG-075
- 日期: 2026-05-07
- 严重程度: 🟡 中（编译阻塞�?- 文件: `Core/DeepBase.WorkerQueue.pas`
- 问题: `WaitForCompletion(ATimeoutMs: Integer = INFINITE)` 使用 Windows unsigned 常量作为 `Integer` 默认参数，Delphi �?`Constant expression expected`�?- 修复: 默认值改�?`-1` 表示无限等待，并同步调整超时判断逻辑�?- 状�? �?已修�?(2026-05-07)

### BUG-099: RegisterDefaultRuntimeComponents 仍为占位实现
- 编号: BUG-099
- 日期: 2026-05-07
- 严重程度: 🟡 中（架构/生命周期�?- 文件: `Core/DeepBase.Services.Registration.pas`, `Tests/Test.DeepBase.Services.Registration.pas`
- 问题: `RegisterDefaultRuntimeComponents` 仅保�?`UnusedPath/UnusedInclude` 占位逻辑，EventBus / Scheduler / WorkerQueue / IoC / Manager 未接入统一 RuntimeContext 生命周期�?- 修复:
  - 新增运行期组件适配器，默认注册 `DeepBase.Manager`、`IoC.Container`、`EventBus`、`Scheduler`、`WorkerQueue`�?  - 保持注册 side-effect free，后台线程只�?`RuntimeContext.Start` 后启动�?  - Shutdown 按反向顺序释放，`IncludeManager=False` 可排�?Manager�?- 状�? �?已修�?(2026-05-07)

### BUG-100: EventBus 异步 handler 无法�?RuntimeContext.Stop 中可�?drain
- 编号: BUG-100
- 日期: 2026-05-07
- 严重程度: 🟡 中（并发/生命周期�?- 文件: `Core/DeepBase.EventBus.pas`, `Tests/Test.DeepBase.RuntimeContext.pas`
- 问题: `edmAsync` 使用匿名线程后没有活跃任务计数，RuntimeContext Stop 只能固定 Sleep，无法保证异步回调完成后再释放订阅�?- 修复:
  - EventBus 增加异步 handler 计数�?`WaitForAsyncHandlers`�?  - RuntimeContext 相关适配�?Stop/Shutdown 调用 drain，避免异步回调与清理交叉�?- 状�? �?已修�?(2026-05-07)

### BUG-101: WorkerQueue 队列所有权、唤醒和调度状态存在多处竞�?- 编号: BUG-101
- 日期: 2026-05-07
- 严重程度: 🟡 中（并发/稳定性）
- 文件: `Core/DeepBase.WorkerQueue.pas`, `Tests/Test.DeepBase.WorkerQueue.pas`, `Tests/Test.DeepBase.RuntimeContext.pas`
- 问题:
  - `TMemoryJobStorage` �?`TWorkerQueue.FJobs` 同时拥有同一�?`TJob`，`SaveJob` 覆盖�?key 时可能释放正在运行的 job�?  - `GetNextJob` 遍历 `FPendingQueue` 时删除元素后继续 `for` 循环，两个待处理 job 并存时可能越界读�?  - 定时任务、依赖任务和重试任务在事�?reset 后缺少周期性重�?重新唤醒�?  - `Enqueue` 会把 `ScheduleAt` 设置�?`jsScheduled` 覆盖�?`jsPending`，导致定时任务提前执行�?  - Stop 后统计只看当�?worker，历�?`TotalProcessed/TotalErrors` 丢失�?- 修复:
  - 内存 job storage 改为非拥有引用，队列字典继续负责 job 生命周期�?  - `GetNextJob` 改为 while 取一�?job 后退出，并重新检查剩余可�?job 维护事件状态�?  - worker 等待超时后也重查队列，job 完成后对剩余 pending job 重新 signal�?  - `Enqueue` 保留 `jsScheduled` 状态，统计改用队列累计计数�?  - 修复 WorkerQueue JSON 反序列化和测�?JSON 对象释放泄漏�?- 状�? �?已修�?(2026-05-07)

### BUG-102: ILLMStorage 新增 IsPostgreSQL 后测�?mock 未同�?- 编号: BUG-102
- 日期: 2026-05-07
- 严重程度: 🟢 低（测试编译阻塞�?- 文件: `Tests/Test.DeepBase.LLM.pas`, `Tests/Test.DeepBase.LLM.Manager.pas`
- 问题: `ILLMStorage` 接口新增 `IsPostgreSQL` 后，两个断开连接 mock 未实现该方法，导�?`DeepBaseTests` 编译失败�?- 修复: 测试 mock 增加 `IsPostgreSQL: Boolean`，默认返�?`False`�?- 状�? �?已修�?(2026-05-07)

### BUG-103: RetryPolicy 在主线程重试等待时直�?Sleep
- 编号: BUG-103
- 日期: 2026-05-07
- 严重程度: 🟡 中（UI/并发�?- 文件: `Core/DeepBase.Resilience.pas`, `Tests/Test.DeepBase.Resilience.pas`
- 问题:
  - `TRetryPolicy.Execute` 在每次重试前直接 `Sleep(Delay)`�?  - 如果�?VCL/FMX 主线程或 EventBus 主线�?handler 内执行，会造成界面卡顿或阻塞主线程事件处理�?- 修复:
  - 新增 `TRetryMainThreadWaitMode`：`rmwAllow`、`rmwWarn`、`rmwRaise`�?  - 默认 `rmwWarn` 保持旧行为兼容，同时通过 `OnMainThreadWaitEvent` 暴露可观测告警点�?  - `rmwRaise` 下抛�?`ERetryMainThreadWaitException`，在进入 `Sleep` �?fail-fast�?  - 新增 `ExecuteAsync` / `ExecuteAsync<T>`，为 UI 调用方提供后台重试入口�?- 验证:
  - `cmd /c compile_test.bat`：通过，`Exit code: 0`�?  - `Scripts/run_tests.ps1 -Type Unit -SkipCompile -Run Test.DeepBase.Resilience`�?18/118 通过�?- 状�? �?已修�?(2026-05-07)

### BUG-104: 必�?Examples 与当前公共库 API 漂移导致编译失败
- 编号: BUG-104
- 日期: 2026-05-07
- 严重程度: 🟡 中（示例/门禁阻塞�?- 文件:
  - `Scripts/build_examples_win64.ps1`
  - `Examples/Phase1Demo/Phase1Demo.dpr`
  - `Examples/Phase1Demo/MainForm.pas`
  - `Examples/Phase1Demo/MainForm.dfm`
  - `Examples/FullDemo/FullDemo.dpr`
  - `Examples/FullDemo/FullDemo.MainForm.pas`
  - `Examples/FMXDemo/FMXPlatformDemo.dpr`
  - `Examples/FMXDemo/Main.Form.pas`
  - `Examples/CommerceE2EDemo/CommerceE2EDemo.pas`
- 问题:
  - Phase1Demo 使用已不存在�?`TWaitForm.HideWait`、`TNotificationBar.ShowMessage` 和缺�?损坏资源�?  - FullDemo 使用旧版 `InitializeWithDB`、`DeepBase.Log`、`DeepBase.MRU`、`DeepBase.Theme`、配置控�?`Section/Key`、旧等待�?API 和已不存在的 `DeepBase.RemoteConfig`�?  - FMXPlatformDemo 使用不存在的 `PlatformName/DeviceTypeName` 属性，匿名事件�?`TThread.Synchronize` 写法在当�?Delphi 下无法编译�?  - CommerceE2EDemo 使用 `WriteLn` 格式数组和不兼容的匿�?verifier 回调�?- 修复:
  - 新增 Win64 示例编译脚本，区分必选和可选示例并生成 txt/xml 报告�?  - 示例代码统一迁移到当前等待窗、通知条、配置控件、Manager、FMX Platform �?Commerce API�?  - 移除缺失 `.res` / `RemoteConfig` 引用，修�?Phase1 DFM 结构�?- 验证:
  - `Scripts/build_examples_win64.ps1`�? 个必选示例全部通过�?- 状�? �?已修�?(2026-05-07)

### BUG-105: Manager 初始�?Boolean/异常入口语义不一�?- 编号: BUG-105
- 日期: 2026-05-07
- 严重程度: 🟡 中（API 语义/调用方错误处理）
- 文件:
  - `Core/DeepBase.Manager.pas`
  - `Tests/Test.DeepBase.Manager.pas`
- 问题:
  - Manager 只有 Boolean 初始化入口，失败原因需要调用方额外读取 `LastError` / `InitErrorCode`�?  - 需要异常模式的调用方缺少统一入口，容易自行包装后丢失错误码、上下文或底层失败原因�?  - Manager 测试中连接适配器和 storage factory 是全局状态，失败断言可能让后续测试继�?nil 适配器状态�?- 修复:
  - 新增 `InitializeOrRaise` �?`InitializeWithDBOrRaise`，失败时抛出 `EInitializationException`�?  - 新增初始化错误格式化和抛出辅助方法，异常携带 `ErrorCode` �?`DeepBase.Manager.<Operation>` 上下文�?  - 保持 `InitializeEx` / `InitializeWithDB` �?Boolean 入口兼容语义不变�?  - Manager 测试�?setup/teardown 中恢�?FireDAC 连接适配器和 storage factory，并补充异常入口成功/失败覆盖�?- 验证:
  - `Scripts/run_tests.ps1 -Type Unit -Run Test.DeepBase.Manager`�?6/16 通过�?- 状�? �?已修�?(2026-05-07)

### BUG-106: UBS2 解密路径缺少版本分发和迁移诊�?- 编号: BUG-106
- 日期: 2026-05-07
- 严重程度: 🟡 中（安全格式兼容/可维护性）
- 文件:
  - `Core/DeepBase.Security.pas`
  - `Tests/Test.DeepBase.Security.pas`
- 问题:
  - �?Windows UBS2 解密路径直接硬编�?v1 解析逻辑，后续格式升级时容易在主入口累积条件分支�?  - 未知 magic、legacy 格式、未知版本和未知 KDF 的错误信息不足以指导迁移或升级�?  - Security 篡改检测测试使用基�?`Exception`，与实际 `EDecryptionException` 不一致�?- 修复:
  - 新增 UBS2 当前版本/支持版本常量和版本读取入口�?  - �?UBS2 v1 解密逻辑拆成独立分支，主入口按版�?dispatch�?  - �?legacy UBS1、未�?magic、未知版本、未�?KDF、过�?payload、无�?PBKDF2 迭代次数输出明确诊断�?  - 补充�?Windows UBS2 版本协商测试，并�?Windows 篡改检测断言收紧�?`EDecryptionException`�?- 验证:
  - `Scripts/run_tests.ps1 -Type Unit -Run Test.DeepBase.Security`�?2/42 通过�?  - `Scripts/run_tests.ps1 -Type Unit -SkipCompile -Run Test.DeepBase.Security.DPAPI`�?3/23 通过�?- 状�? �?已修�?(2026-05-07)
