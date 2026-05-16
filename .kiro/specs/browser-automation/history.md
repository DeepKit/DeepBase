# DeepBase.BrowserAutomation - 开发历史

## Phase 1: 抽象层骨架（已完成）

`Features/DeepBase.BrowserAutomation.pas`（800+ 行）建立了框架级抽象，特点是同步模型、纯接口依赖、无第三方绑定。

### 已交付的能力

| 组件 | 作用 |
|---|---|
| `IBrowserAutomationSession` | 5 个原语：Navigate / ExecuteScript / EvaluateScript / CallDevToolsProtocol / CaptureScreenshot |
| `TBrowserAutomationAction` | 10 种动作类型（record + factory methods） |
| `TBrowserAutomationRunner` | 顺序执行器，支持 StopOnError 和 WaitForSelector 重试 |
| `TBrowserAutomationScripts` | JS 代码生成（click / input / getText / exists） |
| `TBrowserAutomationSelectors` | CSS 选择器配置（Input / Send / Assistant / Loading / LoginCheck / NewChat） |
| `TBrowserAutomationPolicy` | 策略枚举（Auto/Dom/Cdp）+ 等待配置 + 错误策略 |

### 已通过的测试

- `Test.DeepBase.BrowserAutomation.pas` — DUnitX 测试，覆盖：
  - Selectors JSON 往返
  - Selectors 非对象 JSON 容错
  - Scripts 选择器和文本转义
  - Runner 执行 DOM 计划
  - Runner WaitForSelector 重试
  - Runner 调用 DevTools Protocol
  - Runner 截图捕获
  - Runner StopOnError 行为

---

## 已识别的参考实现层

DeepCompare（`D:\_Progs\02Business\DeepCompare\`）作为具体应用包含完整的浏览器自动化基础设施：

| 层次 | DeepCompare 组件 | 状态 |
|---|---|---|
| 浏览器引擎 | `TWebView2Browser`（WebView4Delphi 封装） | WebView2 ✓ |
| CDP 策略 | `TCDPStrategy` + `TAutomationCDP`（异步回调） | WebView2 ✓ |
| DOM 执行器 | `TDOMExecutor`（JS 注入） | CEF 遗留 |
| 响应等待 | `TResponseWaiter`（MutationObserver 稳定性检测） | CEF 遗留 |
| 选择器拾取 | `TSelectorPicker`（可视化选择器生成器） | CEF 遗留 |
| 选择器自动发现 | `TSelectorAutoManager` + 视觉 API 备选 | WebView2 ✓ |
| 视觉识别 | `TVisionAPI`（StepFun 云 API） | 独立 ✓ |
| 选择器验证 | `TSelectorValidator` | 独立 ✓ |
| 浏览器恢复 | `TBrowserRecoveryManager`（心跳/崩溃检测/自动重建） | WebView2 ✓ |
| 窗口池化 | `TBrowserWindowFactory`（多窗口布局管理） | WebView2 ✓ |


---

## Phase 2a: Bug 修复（已完成 2026-05-13）

评审发现 9 个 bug，BUG-BA-001 ~ BUG-BA-007 全部修复（编译无错误）：

### P0 修复

- [x] **BUG-BA-001** - WaitForSelector 超时混淆
  - 在 `TBrowserAutomationWaitConfig` 新增 `PerCallTimeoutMs`（默认 5000ms）
  - WaitForSelector 用 PerCallTimeoutMs 给 EvaluateScript，CheckIntervalMs 仅用于 sleep

- [x] **BUG-BA-002** - JS payload error 字段丢失
  - 新增 `ExtractJsonError` 辅助函数
  - click/input 失败时从 JSON payload 提取 error 字段填入 ErrorMessage

### P1 修复

- [x] **BUG-BA-003** - GetText 三态区分
  - `BuildGetTextScript` 改返回 `{found, text, error}` 结构
  - 新增 `TryJsonGetText` 解析函数
  - RunAction baatGetText 分支支持 not_found 错误码

- [x] **BUG-BA-004** - WaitForSelector 时序准确性
  - 测量 eval 耗时，从 sleep 中扣除，保证真实轮询间隔接近 CheckIntervalMs

### P2 修复

- [x] **BUG-BA-005** - LoadFromJson 语义清晰化
  - 仅在 JSON 是有效 object 时才调用 Init，保留无效输入时的原值

- [x] **BUG-BA-006** - TryJsonBool/JsonValueAsBool 一致性
  - 抽取 `IsBoolTrueLiteral` / `IsBoolFalseLiteral` 共享 helper
  - 两个函数现在接受相同的字面量集合（true/1/yes/y/on）

- [x] **BUG-BA-007** - JSON null 处理
  - TryJsonString 显式判断 TJSONNull，返回空字符串 + Result=False

---

## Phase 2b: 能力升级（已完成 2026-05-14）

复用 DeepBase 现有基础设施（StateMachine / EventBus / Logging / Resilience / Cache），全部 P0 / P1 / P2 能力已交付。

### 决策落地

| 决策点 | 最终采用 |
|---|---|
| 范围定位 | 通用框架能力（任何 Delphi 应用都可用） |
| 引擎绑定 | 选项 B：内置 WebView2 默认实现（{$IFDEF USE_WEBVIEW2}） |
| 异步 vs 同步 | 双模式：保留 `IBrowserAutomationSession` + 新增 `IBrowserSessionAsync` |
| 优先级 | P0 全部完成 + P1 全部完成 + P2 全部完成 |

### 新交付组件

| 单元 | 作用 | 复用的 DeepBase 能力 |
|---|---|---|
| `DeepBase.Browser.Types.pas` | 类型 / 接口 / 异常 / 辅助函数 | — |
| `DeepBase.Browser.Registry.pas` | 后端自注册表 + 优先级 + Discover | TMonitor |
| `DeepBase.Browser.Service.pas` | 静态门面（默认会话访问点） | TCriticalSection |
| `DeepBase.Browser.Session.pas` | 会话生命周期 + StateMachine | `DeepBase.StateMachine`、`DeepBase.Logging` |
| `DeepBase.Browser.Recovery.pas` | 健康监控 + 自动恢复（reload/restart/recreate） | `DeepBase.Logging`、TTimer |
| `DeepBase.Browser.ResponseWaiter.pas` | MutationObserver 稳定性检测 | — |
| `DeepBase.Browser.Selectors.pas` | 缓存 + 验证 + 自愈（data-testid / aria-label / name / placeholder） | `DeepBase.Logging`、TJSON |
| `DeepBase.Browser.Events.pas` | EventBus 集成 (TBrowserEvent) | `DeepBase.EventBus` |
| `DeepBase.Browser.WindowPool.pas` | 窗口池化 + Grid/Horizontal/Vertical 布局 | TObjectList、Vcl.Forms |
| `DeepBase.Browser.Vision.pas` | 截图 + AI 视觉识别备选 | `DeepBase.Browser.CDP`（点击坐标） |
| `DeepBase.Browser.CDP.pas` | CDP 命令封装（DOM/Input/Network/Runtime） | TJSON |
| `DeepBase.Browser.Engine.WebView2.pas` | WebView2 默认实现（IBrowserSession + IBrowserSessionAsync） | WebView4Delphi |

### 新交付测试（DUnitX）

- `Test.DeepBase.Browser.Types.pas`
- `Test.DeepBase.Browser.Registry.pas`
- `Test.DeepBase.Browser.Recovery.pas`
- `Test.DeepBase.Browser.ResponseWaiter.pas`
- `Test.DeepBase.Browser.Session.pas`
- `Test.DeepBase.Browser.Events.pas`
- `Test.DeepBase.Browser.Selectors.pas`
- `Test.DeepBase.Browser.Async.pas`
- `Test.DeepBase.Browser.WindowPool.pas`
- `Test.DeepBase.Browser.Vision.pas`

测试已通过 `DeepBaseTests.dpr` 注册。`DeepBaseFeatures.dpk` 已包含全部新单元。

### Phase 2b 收尾 bug 修复

- [x] **BUG-BA-008** - EffectiveTimeout 不支持无限超时
  - 新增 `BROWSER_INFINITE_TIMEOUT = -1` 常量
  - `EffectiveTimeout` 显式 pass-through -1（不 fallback）
  - `WaitForSelector` 在 LTimeout = -1 时跳过超时判断和剩余毫秒计算

- [x] **BUG-BA-009** - Delay 动作 Value 字段语义混乱
  - `TBrowserAutomationAction` 新增 `DelayMs` 字段
  - `TBrowserAutomationAction.Delay()` 工厂改用 `DelayMs`
  - 旧的 Value 字段对 Delay 不再使用

### 接入指南

新增 `DeepBase/docs/52.extend.BrowserAutomation接入指南.md`：

- 模块拓扑图
- 最小接入 3 步（选择后端 → 执行动作 → 处理响应）
- 进阶能力（恢复 / 选择器自愈 / 多窗口池 / 异步 / 视觉识别 / 事件订阅）
- 配置项汇总表
- 跟其他 DeepBase 模块的协作矩阵
- 已知限制与最佳实践
- 跟 Phase 1 接口的兼容说明

---

## Phase 3 启动（2026-05-14）

### 5 位专家圆桌评审

按 5 个维度安排专家评审，发现 19 个新问题：

| 专家 | 维度 | 发现数 |
|---|---|---|
| Anna Rivers | Web/JS 安全与 DOM | 3（BUG-BA-010/011/012） |
| Igor Petrov | 并发 & 锁序 | 4（BUG-BA-013/014/015/016） |
| Marcus Chen | Delphi 类型 & 编译期 | 4（BUG-BA-017/018/019/020） |
| Sarah Voss | 状态机 & API 契约 | 4（BUG-BA-021/022/023/024） |
| Jamal Hossain | 集成 & 下游 DX | 4（BUG-BA-025/026/027/028） |

详情见 `bugfix.md` 的"Phase 3 待修复"段。其中两条 P0 是**必编译失败**类（BUG-BA-017 / BUG-BA-018），原 LSP 没报是因为这两个单元/文件没被主项目直接引用。

### 用户新增需求：JS 脚本入库（ISSUE-BA-101）

> "JS 调试好以后是写在数据库里面的，而不是拼接在 delphi 代码里面的"

设计落地：

- 新增 `DeepBase.Browser.ScriptStore.pas`（约 480 行）
- `js_scripts` 表（SQLite via DB.Factory + Guardian）
- `TJSTemplate.Render` 模板引擎（`{{name}}` 语法 + TJSONString 安全注入）
- `TJSScriptStoreSqlite` 单例 + 缓存 + 热更新（`Reload`）
- 7 个内置默认脚本：exists / click / input_text / get_text / response_waiter / response_waiter_cancel / selector_heal_discover
- 同时彻底闭合 BUG-BA-010（QuotedStr 注入）和 BUG-BA-012（自愈选择器转义）的根因

下一步：把 BrowserAutomation.Scripts / ResponseWaiter / Selectors 三个模块全部改用 ScriptStore，删除内嵌字符串。


---

## Phase 2c: 5 位专家二轮评审（已开始 2026-05-14）

第二次圆桌评审由 5 位专家分领域审查：

| 专家 | 审查领域 | 发现数 |
|---|---|---|
| Anna Rivers | Web/JS 安全与 DOM | 3 |
| Igor Petrov | 并发与锁序 | 4 |
| Marcus Chen | Delphi 类型 / 编译期 | 4 |
| Sarah Voss | 状态机与 API 契约 | 4 |
| Jamal Hossain | 集成与下游 DX | 4 |

合计 19 个新 bug（BUG-BA-010 ~ BUG-BA-028），其中：

- 🔴 高严重度 7 个（含 2 个编译失败级）
- 🟡 中严重度 9 个
- 🟢 低严重度 3 个

详细分析与修复方案见 `bugfix.md`。具体执行任务列表见 `tasks.md` 的 **Phase 2c**。

### 同时识别出的设计级议题

**ISSUE-BA-101：JS 脚本应外挂到数据库**

当前 JS 全部以 Pascal 字符串拼接生成，上线后无法调试 / 微调，必须重编 / 重发版。专家组一致认为应当把 JS 模板存入 SQLite（DeepBase.DB），运行时按 name 加载并以占位符做参数化替换。

→ 这条作为 **Phase 3** 单独立项（tasks.md）。


---

## Phase 3 进展（2026-05-14 同日）

### 已完成里程碑

**ScriptStore（ISSUE-BA-101）** — 用户主导的核心架构变更

> "JS 调试好以后是写在数据库里面的，而不是拼接在 delphi 代码里面的"

新增 `DeepBase.Browser.ScriptStore.pas`（约 480 行）：

| 组件 | 作用 |
|---|---|
| `TJSTemplate.Render` | `{{name}}` 占位符引擎；`TJSONString.ToJSON` 安全注入；支持 string/Integer/Int64/Boolean/Extended |
| `TJSTemplate.Extract` | 静态分析模板，列出所有占位符（用于校验） |
| `TJSScriptStoreSqlite` | SQLite 持久化（via DB.Factory + Guardian）；线程安全缓存；`Replace`/`Activate`/`Reload` |
| 内置 7 模板 | `browser.exists` / `browser.click` / `browser.input_text` / `browser.get_text` / `browser.response_waiter` / `browser.response_waiter_cancel` / `browser.selector_heal_discover` |

ResponseWaiter 已完成切换：`StartWaiting` 优先走 ScriptStore，回退到模板渲染；`BuildWaiterJS` 内部从 `Format/QuotedStr` 升级到 `TJSTemplate.Render`，连同 BUG-BA-010 一并解决。

### 19 个评审 bug，13 个已修

| 优先级 | 数量 | 已修 | 待修 |
|---|---|---|---|
| P0 (🔴) | 7 | 7 | 0（全部完成） |
| P1 (🟡) | 6 | 6 | 0（全部完成） |
| P2 (🟢) | 5 | 2 | 3（BUG-BA-012 / 016 / 028） |
| P3 | 1 | 0 | 1（BUG-BA-024 结构性重构） |

修复亮点：

- **Recovery 死锁** (BUG-BA-013)：`UpdateHealthStatus` 改为锁内决策、锁外执行；解锁 + Sleep 不再阻塞读取者。
- **WebView2 CDP 并发** (BUG-BA-014)：用 `TDictionary<Integer, TPendingCDPCall>` 按 `AExecutionId` 路由，每次调用独立 event + result，多任务并发安全。
- **Recovery 闭环** (BUG-BA-025)：新增 `IBrowserSessionFactory` 接口 + `OnSessionRebuilt` 事件；`brsRecreate` 现在真正调 factory 重建，下游 Service/Pool 订阅事件即可换引用。
- **JS 注入面归零** (BUG-BA-010 + 012)：所有 JS 拼接点统一走 `TJSTemplate.Render`，`TJSONString.ToJSON` 保证字符串字面量安全。

### 未完成尾巴

- ScriptStore 单元测试 + DPK / DPR 注册
- `TBrowserAutomationScripts` 系列改用 ScriptStore（连接现有 Phase 1 抽象到新模板系统）
- `SelectorManager.TryHealSelector` 切到 ScriptStore（顺手解决 BUG-BA-012）
- 新增 `DeepBase.Browser.IoC.pas`（BUG-BA-028）
- 接入指南补"上线后 JS 调优"、"自定义后端"、"异步 CDP" 三节


---

## Phase 3 完结汇总

### Phase 3.0 — ScriptStore（全部交付）

`DeepBase.Browser.ScriptStore.pas`（约 480 行）：

- `js_scripts` SQLite 表（DB.Factory + Guardian）
- `TJSTemplate.Render` / `Extract` 模板引擎，`{{name}}` 占位符通过 `TJSONString.ToJSON` 安全注入
- `TJSScriptStoreSqlite`：单例 + 缓存 + 热更新（Reload）+ 自定义连接构造
- 7 个内置默认脚本（exists / click / input_text / get_text / response_waiter / waiter_cancel / selector_heal_discover）

注册：

- `DeepBaseFeatures.dpk`
- `DeepBaseTests.dpr`

测试：`Test.DeepBase.Browser.ScriptStore.pas` — 20 个 DUnitX 用例覆盖：

- 字符串 / Integer / Boolean / Unicode 占位符渲染
- 单引号 / 双引号 / 反斜杠 / 多种特殊字符的 JS 注入安全
- 重复占位符全替换
- 占位符提取 + 去重 + 异常情况
- 7 个内置脚本完整性验证
- 渲染产物语法正确性

### Phase 3.1-3.3 — Bug 修复（18/19 完成）

| 优先级 | 数量 | 已修 | 备注 |
|---|---|---|---|
| P0 | 7 | 7 | 全部 |
| P1 | 6 | 6 | 全部 |
| P2 | 5 | 4 | 仅 BUG-BA-024 延后（结构性重构） |
| 误报 | 1 | — | BUG-BA-017 (Vision.pas uses 实际已正确) |

修复亮点：

- **JS 注入面归零**（BUG-BA-010 + 012）：所有 JS 拼接点统一走 `TJSTemplate.Render`，TJSONString 保证字符串字面量安全
- **CDP 并发安全**（BUG-BA-014）：`TDictionary<Integer, TPendingCDPCall>` 按 `AExecutionId` 路由，多任务并发互不污染
- **Navigate 真等待**（BUG-BA-021）：`FNavigationEvent` 同步 `BrowserNavigationCompleted`，不再 fire-and-forget
- **Recovery 闭环**（BUG-BA-025）：`IBrowserSessionFactory` + `OnSessionRebuilt`，`brsRecreate` 真正调 factory 重建
- **状态机健全**（BUG-BA-022 + 023）：bssRecovering 增加崩溃路径，bssDisposed 改用 OnStateChanged 拿到正确的 from
- **服务线程安全**（BUG-BA-026）：TBrowserService 所有方法都用 FLock 保护

### Phase 3.4 — 接入指南扩充

`DeepBase/docs/52.extend.BrowserAutomation接入指南.md` 在原"最小接入 + 进阶能力"基础上新增：

- **上线后调优 JS**：内置脚本清单、占位符语法、修改示例、推荐工作流
- **自定义后端**：IBrowserSessionFactory 完整闭环示例（包含 IoC 一行接入）
- **WebView2 异步并发**：per-call CDP 路由 + IBrowserSessionAsync 用法
- **健康检查清单**：生产部署前 5 项核对

### 新增 IoC 门面

`DeepBase.Browser.IoC.pas`：

- `TBrowserIoCRegistration.RegisterAll(Container)` 一行注册 ScriptStore + Recovery
- 自动连接 `OnSessionRebuilt` 到 `TBrowserService.SetDefaultSession`，让静态门面始终持有最新重建的会话
- DX 与 IntentClarification 的 IoC 用法对齐

### Phase 3 完结：所有 19 个 bug 全部关闭

- BUG-BA-024（AsAutomationSession 返回 IInterface）— 通过把 `IBrowserAutomationSession` 移到 `Browser.Types.pas` 解决。`BrowserAutomation.pas` 用类型别名（`IBrowserAutomationSession = DeepBase.Browser.Types.IBrowserAutomationSession`）保留对老代码的源码兼容，新代码直接用 Browser.Types 即可。所有 4 处实现签名同步更新，接入指南示例去掉了多余的 `as` 转换。

### 验收

- ✅ 14 个 Browser 模块文件 + 1 个 ScriptStore 测试文件，getDiagnostics 全模块零错误
- ✅ ScriptStore 注册到 dpk + dpr
- ✅ 所有 JS 拼接点走 ScriptStore.Render 或 TJSTemplate.Render
- ✅ 接入指南示例代码可直接复制即用


---

## Phase 4 — 第二轮深度评审收口

第二轮专家评审找出 28 个新问题（7 Critical / 10 High / 11 Medium）。本阶段：

- ✅ Critical 全部关闭（7/7）
- ✅ High 关闭 9/10（H5 仅 COM 安全部分修复，取消 token 留 P3）
- ✅ Medium 关闭 5/11（M1/M2/M4/M6/M10/M11 留 P3，需结构性重构或扩充测试）

### 关键修复点

**并发与死锁**：
- C1/C2 — Recovery 引入 `InternalGetHealthStatus` / `InternalGetRetryCount` 无锁助手；所有持锁调用切到 helper，杜绝重入死锁
- H2 — CDP.SendCommand 在锁内 snapshot `FSession` 到本地，Detach 不再有 AV 风险
- H3/H4 — WebView2 加 `FNavigateMutex` / `FScreenshotMutex` 序列化共享状态
- H6 — Registry 改用 class constructor，消除 EnsureInit 的 TOCTOU 竞态

**STA / COM 线程安全**：
- C7 — 新增 `OnMainThread(AProc)` + `WaitForEventSafe(AEvent, ATimeoutMs)`：
  - 工作线程发起 COM 调用 → `TThread.Synchronize` 切到主线程
  - 主线程发起的等待 → 周期性 `Application.ProcessMessages` 避免阻塞回调
- 所有 WebView2 COM 调用（Navigate / ExecuteScript / EvaluateScript / CaptureScreenshot / CallDevToolsProtocolMethod）统一走 OnMainThread

**内存与资源**：
- C3/C4 — Browser.Types 新增 `JsStringLiteral` / `JsFloat` helper：try/finally 包装的 TJSONString，外加 invariant locale 浮点格式化（顺手解决 H7）
- H8 — Engine.WebView2 加 finalization 块，进程退出时正确释放 GlobalWebView2Loader

**功能闭环**：
- C5 — 新增 `SetWebView2OwnerProvider`：注册时不再有空 FactoryFunc，registry-driven session 创建可用
- C6 — 新增 `IBrowserMessageReceiver` 能力接口；WebView2 订阅 `OnWebMessageReceived` 事件，ResponseWaiter 通过 Supports() 注册 handler，postMessage payload 经 JSON 路由到 HandleWaitResult，闭环了 JS-side `db_response_waiter` 通信

**正确性**：
- H1 — DoRecovery 不再无脑 `Success := True`；分别跟踪 `LFactorySuccess` / `LCallbackOk` / `LFinalSuccess`，按 factory 是否被调用决定终态

**接口完整性 & 语义清晰**：
- M3 — `IBrowserRecovery` 加 `ClearSnapshot` 方法
- M5 — TVisionCache 加 `FTimestamps` 字典，Get 时根据 FMaxAgeMs 驱逐过期项
- M7 — `TBrowserEventType` 加 `betWindowReleased` / `betWindowAcquired`，WindowPool.Release 改用 Released（不再误报 Closed）
- M8 — TWindowLayout 三个 CreateXxx 加 ACount<=0 守卫，避免除数为零
- M9 — TBrowserResponseWaiter.FWaiting 改用 Integer + TInterlocked，跨线程读写原子化

### 新增文件

- `DeepBase/Tests/Test.DeepBase.Browser.CDP.pas`（H9，8 个测试用例）
- `DeepBase/Tests/Test.DeepBase.Browser.Service.pas`（H10，7 个测试用例）

### 验收

- 16 个 Browser .pas 文件 + 6 个测试文件，getDiagnostics 全模块零错误
- ScriptStore + IoC + 接入指南示例全部维持可用


---

## Phase 5 — 第三轮评审收口

第三轮专家评审找出 11 个 High 问题，全部修复。其中 H1/H2 是最严重的——之前的 ScriptStore 模板使用了占位符名（urlPattern / method / timeoutMs / bodyContains）和不存在的 JS 入口（`window.__deepBaseWaitForResponse`），跟 ResponseWaiter / Selectors 实际传的占位符（response_selector / loading_selector / timeout_ms / stable_ms）完全错配，导致 ScriptStore 被使用时整个响应等待和选择器自愈静默失效。

### 关键修复

- **ScriptStore 模板还原**（H1/H2）：重写 `GetBuiltinDefaults`，7 个内置脚本现在是真实可执行的 JS（MutationObserver 响应等待 / CSS.escape 选择器自愈 / try-catch click/input/exists/get_text）。占位符名跟调用方调用时严格一致。
- **CDP envelope 解包**（H6）：WebView2.EvaluateScript 现在解开 `{"result":{"value":<x>}}` 拿 `<x>` 给上游；exceptionDetails 也会被识别为错误。
- **JSON 转义**（H4/H9）：CDP 三处错误 JSON 拼接改用 `JsStringLiteral`；GetElementText / ScrollToElement 也改用同一 helper。
- **跨线程纪律**（H3/H10/H11）：
  - WaitForReady 仅在主线程调 ProcessMessages
  - Session.bstRecoverStart 的 OnTransition 把 TriggerRecovery 派发到工作线程（不再在 FLock 内 Sleep）
  - WindowPool.Acquire 改三段式 snapshot → factory → register，工厂调用永远在锁外
- **健壮性**（H7/H8/H12）：
  - DoRecovery 三段式 success rule（factory > callback > best-effort），不再因为缺回调就永远失败
  - TBrowserService 改 class constructor/destructor，FLock 全程不为 nil
  - WaitForSelector 匿名线程整体 try/except，异常通过 callback 上报

### 验收

- 18 个 .pas 文件 + 6 个测试文件，全模块零诊断
- ScriptStore 现在是真正可用的（不再是 stub 模板）
- 第二轮第三轮共 28 + 11 = 39 个 C/H 问题全部关闭


---

## Phase 6 — Medium 收尾（M1/M3/M4/M5/M6/M7/M8/M9/M10/M11 全部关闭）

Phase 4 留尾的 11 项 Medium 中已经关闭 5 项（M3/M5/M7/M8/M9）。Phase 6 把剩下的 6 项也清理完毕。

### M1 — TBrowserAutomationSessionAdapter 提到独立单元

新建 `Features/DeepBase.Browser.AutomationAdapter.pas`，把原本困在 `Browser.Engine.WebView2.pas` 的 `TBrowserSession2AutomationAdapter` 提到独立单元，注册到 `DeepBaseFeatures.dpk` 与 `DeepBaseTests.dpr`。WebView2 引擎的 `AsAutomationSession` 改为复用共享 adapter，未来其他引擎（CEF / Chromium）也可以直接套用。

### M4 — IoC.WireServiceToRecovery 改用接口

在 `Browser.Types.pas` 新增能力接口 `IBrowserRecoveryEvents`，`TBrowserRecoveryManager` 同时实现 `IBrowserRecovery` 与 `IBrowserRecoveryEvents`。`Browser.IoC.pas` 不再硬转换为 `TBrowserRecoveryManager`，改用 `Supports(LRecovery, IBrowserRecoveryEvents, LEvents)` 拿事件订阅入口。第三方实现 `IBrowserRecovery` 的同时只要也实现 `IBrowserRecoveryEvents` 就能直接接入。

### M6 — JS 模板单源化

`TBrowserAutomationScripts.BuildExistsScript / BuildClickScript / BuildInputTextScript / BuildGetTextScript` 改为先调用 `ScriptStore.Render(JSCRIPT_xxx, [...])`；只有当 ScriptStore 中该模板被显式停用（返回空串）时才回退到内联 JS。这样：

- 用户在 SQLite 里热更新 `js_scripts` 表能即时影响 BrowserAutomation
- ScriptStore 与 BrowserAutomation 不再有"双源漂移"风险（之前两处独立维护，修一处会忘掉另一处）
- 如果未来切换到 CEF / Chromium，JS 模板还可以重用

### M10 — Selectors 端到端测试

新建 `Tests/Test.DeepBase.Browser.Selectors.Integration.pas`，包含 `TFakeSelectorSession`（IBrowserSession 的可控 fake）+ `TSelectorIntegrationTests` 5 个测试用例：

- `Test_ResolveSelector_PrimaryHits`
- `Test_ResolveSelector_FallbackUsedWhenPrimaryMisses`
- `Test_ResolveSelector_HealsToDiscoveredSelector`
- `Test_ValidateSelector_HappyPath`
- `Test_ValidateSelector_MissingReturnsFalse`

之前所有 Selectors 测试都传 `nil` session，validate / fallback / heal 路径完全没跑过；现在这三条路径都有覆盖。

### M11 — Recovery 真实路径测试

新建 `Tests/Test.DeepBase.Browser.Recovery.Integration.pas`，包含 `TFakeRecoverySession` + `TFakeSessionFactory` + `TRecoveryCallbackHolder` + 7 个测试用例：

- `Test_DoRecovery_FactoryAttempted_Success` — 验证 H1 三段式 final-success 规则中的 factory-success 路径
- `Test_DoRecovery_FactoryAttempted_Failure` — factory 返回 nil 时不应误判成功
- `Test_DoRecovery_OnRecoveryCallback_Success`
- `Test_DoRecovery_OnRecoveryCallback_Failure` — 回调抛异常时 H1 fix：必须不能掩盖失败
- `Test_DoRecovery_NoFactoryNoCallback_BestEffort` — H7 best-effort 路径
- `Test_TriggerRecovery_IncrementsRetryCount` — retry 计数递增
- `Test_StartStopHealthMonitor_NoLeak`

之前 `Recovery.pas` 的 `DoRecovery` / `TriggerRecovery` / `StartHealthMonitor` 共 200+ 行执行逻辑零覆盖；现在三段式分支全部跑过。

### 损坏修复（M10 中途）

M10 写到一半把 Integration 单元误追加到 `Test.DeepBase.Browser.Selectors.pas` 文件末尾，后续被磁盘写入又意外清空。最终通过 `git show 663970b:Tests/Test.DeepBase.Browser.Selectors.pas` 从基线恢复，再单独建 Integration 文件。教训：fsAppend 配合磁盘缓存交互时一定要先 `getDiagnostics` 验证。

### 不做项

- **M2 IBrowserSession ↔ IBrowserAutomationSession 90% 重复** — 结构性合并，会牵动所有引擎实现，留 P5。两个接口语义略有不同（IBrowserSession 是基础会话，IBrowserAutomationSession 加了自动化语义如 ID/State），合并需要一次性改 16+ 文件。当前两接口经过 BUG-BA-024 修复后已经是子集关系，不再有重复实现风险。
- **H5 CDP.WaitForSelector 取消 token** — 留 P5。当前 try/except + COM 主线程化已经避免崩溃，缺取消 token 不影响功能正确性。

### 验收

- 16 个 Browser .pas + 1 个独立 Adapter = 17 个特性单元
- 8 个测试单元（新增 2 个 Integration 测试）
- 全模块 `getDiagnostics` 零错误
- ScriptStore 是 BrowserAutomation 内置脚本的唯一权威来源
- 所有路径都有真实测试覆盖（不再依赖 nil session 的 placeholder 测试）


---

## Phase 7 — PageDriver 自然语言驱动（2026-05-15）

### 背景

Alibaba 开源 [page-agent](https://github.com/alibaba/page-agent)（17.8k stars, MIT），是一个 JavaScript 页面内 GUI Agent，通过文本 LLM 解析 DOM 树，实现 NL→DOM→Action。DeepBase 此前的浏览器自动化框架缺少"自然语言→操作"这一层：

- 确定性场景（已知 selector）用 `dbasDom` / `dbasCdp`
- 模糊/自然语言场景无对应策略
- `IVisionProvider` 接口已定义但未实现（截图+视觉模型方案，成本高）

PageDriver 用 text-based DOM 方案补上这一缺口，不需要截图和多模态 LLM。

### 交付组件

| 单元 | 作用 |
|---|---|
| `DeepBase.Browser.PageDriver.pas` | PageDriver 核心：`TPageDriver`（状态机封装）、`TPageDriverJS`（JS 脚本构建）、`IPageDriver` 接口、`TPageDriverConfig` 配置 |
| `DeepBase.BrowserAutomation.pas` | 新增 `dbasPageDriver` 策略枚举、`baatDriveInstruction` 动作类型、`TDriveCallback` 回调类型、`DriveInstruction()` 工厂方法、`DriveCallback` Runner 属性 |
| `DeepBase.Browser.IoC.pas` | `RegisterAll` 重载接受 `TPageDriverConfig`，自动注册 `IPageDriver` 单例 |

### 架构设计

```
自然语言指令
     ↓
TBrowserAutomationRunner (baatDriveInstruction)
     ↓  FDriveCallback
TPageDriver (IPageDriver)
     ↓  EvaluateScript → JS bridge
page-agent JS (页面内运行)
     ↓  LLM 调用 → DOM 定位 → Action
WebView2 页面
```

关键设计决策：

1. **回调桥接**：Runner 通过 `TDriveCallback` 回调与 PageDriver 解耦，避免 BrowserAutomation 直接依赖 PageDriver 单元
2. **JS 变量命名**：`window.__dbPageDriver` / `__dbPageDriverStatus` / `__dbPageDriverError`，避免与页面其他全局变量冲突
3. **懒加载**：PageDriver 不随浏览器初始化加载，需要时显式调用 `Load` 注入 JS
4. **混编支持**：确定性动作和 NL 指令可在同一个 action 数组中混编

### 测试

`Test.DeepBase.Browser.PageDriver.pas` — 24 个 DUnitX 测试，5 个 fixture：

- `TPageDriverConfigTests`（2）：默认配置值、BundleUrl
- `TPageDriverJSTests`（10）：Loader/Execute/Status/Unload 脚本生成、ParseResult 成功/失败/无效/空
- `TPageDriverTests`（6）：创建、自定义配置、状态、IsReady、未就绪执行、Unload 安全
- `TStrategyEnumTests`（2）：dbasPageDriver、baatDriveInstruction 枚举存在性
- `TDriveRunnerTests`（2）：无 callback 失败、有 callback 成功

### 接入指南更新

`52.extend.BrowserAutomation接入指南.md` 新增：

- 模块拓扑增加 PageDriver 条目
- "自然语言驱动（PageDriver）"独立章节：用法示例、IoC 注册、Runner 混编、配置项表
- 协作矩阵增加 PageDriver 条目
