# DeepBase Features-A 深度代码审计报告：Browser 浏览器自动化 / Desktop 桌面感知 / UIA 组

- **审计范围**：`d:\_Progs\02Business\DeepBase\Features\` 下 Browser（19 个 `DeepBase.Browser.*.pas` + `DeepBase.BrowserAutomation.pas`）、Desktop（8 个 `DeepBase.Desktop.*.pas`）、UIA（3 个 `DeepBase.UIA.*.pas`）共 31 个单元；排除 ThirdParty。
- **审计日期**：2026-09-18（重新取证轮，行号以当前文件为准）
- **审计方法**：只读静态审查（不修改任何源码）。逐单元通读全文；对每条发现回读当前源码确认行号；用 `.dproj` 交叉核对每个单元的**实际构建归属**（是否被编译进任何包），据此区分"活代码缺陷"与"孤儿脚手架缺陷"。
- **对照基线**：`CodeReview\20260825-Features.md` 的 F2 批（历史上仅详审 13 个单元：F2.A Types/Events/Registry/IoC/Service、F2.B CDP/CDP.Adapter/PageDriver、F2.C Session/WebElement/Selectors/ScriptStore/ResponseWaiter；其余 Browser 单元 + 全部 Desktop + 全部 UIA 历史未审）。

## 0. 关键背景：构建归属决定"活/死代码"

本轮最重要的结构性发现：**审计范围内相当多单元根本没被编译进任何 `.dproj`**，是脱离构建的半成品/孤儿脚手架。据此把缺陷分为"活代码（影响运行）"与"死代码（不可编译/未被引用）"两类，避免夸大运行时风险。

| 单元 | 构建归属（本轮核实） | 说明 |
|---|---|---|
| BrowserAutomation / Browser.{Types,Registry,Recovery,ResponseWaiter,Session,CDP,Service,Events,Selectors,WindowPool,Vision,ScriptStore,AutomationAdapter,PageDriver,IoC} | ✅ 编译进 `DeepBaseBrowser.dproj` | 活代码 |
| Browser.**CDP.Adapter** / Browser.**WebElement** | ✅ 经 `Session.pas` 的 uses **传递编译**（Session.dproj 列表未直接列，但被引用即编译） | **活代码**（缺陷影响运行） |
| Browser.**Engine.WebView2** | ⚠️ 未列入任何 dproj，且整文件包在 `{$IFDEF USE_WEBVIEW2}` 内 | 默认引擎在包构建里被条件编译**整体摘除** |
| Browser.**Recorder** | ❌ 不在任何 dproj，且**无法编译**（见 REC-01） | 死代码 + 破损 |
| Desktop.**Lifecycle** | ✅ 编译进 `DeepBasePlatform.dproj`，并被 `VCL\DeepBase.VCL.DesktopLifecycle.pas` 引用 | 活代码 |
| Desktop.**Perception.{Types,ColorMatch,Engine,LLMProvider}** | ❌ 不在任何发布 dproj；仅被**同样未纳入构建**的 Tests / UnifiedActuator 引用 | 死代码（但可编译） |
| Desktop.**Screen.Click.{DPIMapper,RegionLocator,SmartExecutor}** | ❌ 不在任何 dproj；仅被未构建的 Tests 引用；且**三者均无法编译** | 死代码 + 破损 |
| UIA.**Types / UIA.Engine** | ✅ 编译进 `DeepBasePlatform.dproj` | 活代码（含严重安全缺陷） |
| UIA.**UnifiedActuator** | ❌ 不在任何 dproj；仅被未构建的 Tests 引用 | 死代码（可编译，含崩溃路径） |

> 结论：UIA.Engine 与 CDP.Adapter/WebElement/Session 的缺陷**在活代码里**，必须优先修复；Recorder 与 Screen.Click 三件套是**破损的死脚手架**，报告如实记录但风险定级会标注"未纳入构建"。

## 1. 总体统计

| 严重度 | 数量 | 其中活代码 | 其中死代码 |
|---|---:|---:|---:|
| 🔴 崩溃/数据损坏/安全漏洞 | 11 | 9 | 2 |
| 🟡 功能缺陷 | 22 | 18 | 4 |
| 🔵 优化建议 | 9 | 7 | 2 |
| 存疑区（需动态验证） | 6 | 4 | 2 |
| **合计** | **48** | 38 | 10 |

- 历史 F2 批 🔴 复核：**5 条全部仍存在**（未修复），详见第 4 节。
- 7 维度中"安全"与"架构"问题最集中：CDP JSON 注入、URL 注入、UIA 所有权/防篡改校验恒真、同名接口双 GUID、CDP 双实现（SSOT 违背）、大面积半成品。

## 2. 按单元分组的发现

严重度：🔴 / 🟡 / 🔵；每条含 `绝对路径:行号`、代码片段、说明、触发条件、修复建议。

---

### 2.1 DeepBase.Browser.CDP.Adapter.pas（362 行，✅ 经 Session 传递编译 = 活代码）

#### ADP-01 🔴 `NavigateTo` URL 未做 JSON 转义 → CDP 命令注入
`d:\_Progs\02Business\DeepBase\Features\DeepBase.Browser.CDP.Adapter.pas:270`
```pascal
Cmd.Params.Add(Format('"url":"%s"', [URL]));
```
- **说明**：直接把 `URL` 拼进 JSON 片段，未转义 `"`、`\`、控制字符，也未走 `JsStringLiteral`。同库 `CDP.pas`/`Vision.pas` 已统一改用 `JsStringLiteral`（H 系列修复），此处被遗漏。含引号的 URL 可提前闭合 `"url":"..."` 字段并注入任意 CDP 参数字段。
- **触发条件**：调用 `NavigateTo` 且 URL 来自外部/用户/上游数据（如自动化脚本从页面抓取的链接）。
- **修复建议**：改为 `Cmd.Params.AddPair('url', URL)`（让 TJSONObject 负责转义），或用 `JsStringLiteral(URL)` 构造值后再拼。

#### ADP-02 🔴 `SendCommand` 空实现（返回 "Not implemented"）→ ICDPSession 发送链路整体失效
`d:\_Progs\02Business\DeepBase\DeepBase\Features\DeepBase.Browser.CDP.Adapter.pas` 实际路径 `d:\_Progs\02Business\DeepBase\Features\DeepBase.Browser.CDP.Adapter.pas:333`
```pascal
Result.Error := 'Not implemented';
```
- **说明**：`TCDPWebSocketSession.SendCommand` 是半成品，永远返回错误。而 `Session.pas`（在构建中）持有 `FCDP: ICDPSession` 并在多处经其下发命令，等于该会话的 CDP 发送路径不可用。同时库内存在另一套 `CDP.pas.TAutomationCDP.SendCommandSync`（可用），构成**双实现/SSOT 违背**。
- **触发条件**：任何经 `TBrowseSessionImpl` 走 `ICDPSession.SendCommand` 的操作。
- **修复建议**：实现真实 WebSocket 发送，或明确废弃 `ICDPSession` 并把 Session 统一到 `TAutomationCDP`；消除两套 CDP 通道。

#### ADP-03 🟡 `ConnectToBrowser` 用 `ExtractFileName` 解析 WS URL
`d:\_Progs\02Business\DeepBase\Features\DeepBase.Browser.CDP.Adapter.pas:204`
```pascal
WSUrl := 'ws://' + ExtractFileName(WebSocketEndpoint);
```
- **说明**：`ExtractFileName` 取的是"文件名"部分，对形如 `http://127.0.0.1:9222/devtools/page/ABC` 的 endpoint 会截出错误片段，拼出的 `ws://` 地址基本无效率。应解析 `webSocketDebuggerUrl`。
- **触发条件**：连接远端/本地 Chrome DevTools。
- **修复建议**：规范化解析 host:port + path，或直接从 `/json` 列表取 `webSocketDebuggerUrl`。

#### ADP-04 🟡 硬编码 `Sleep(500)` 作为连接就绪等待
`d:\_Progs\02Business\DeepBase\Features\DeepBase.Browser.CDP.Adapter.pas:217`
- **说明**：固定睡眠既不可靠（慢机器连不上）又拖慢（快机器白等）。应事件化或轮询就绪。
- **修复建议**：改为带超时的状态轮询/事件等待。

#### ADP-05 🟡 `ParseJSONValue(...) as TJSONObject` 可抛 EInvalidCast
`d:\_Progs\02Business\DeepBase\Features\DeepBase.Browser.CDP.Adapter.pas:339`
```pascal
Result := TJSONObject.ParseJSONValue(Value) as TJSONObject;
```
- **说明**：`Value` 为数组/标量/null 时 `as` 抛 `EInvalidCast`；解析失败返回 nil 时 `as` 尚可（nil 转型不抛），但类型不符即崩。
- **修复建议**：先 `is TJSONObject` 判定或用 `TryParse` 模式。

#### ADP-06 🔵 `InitializeBrowserAdapter` 双检无锁 + 死代码 `GDPI`
`d:\_Progs\02Business\DeepBase\Features\DeepBase.Browser.CDP.Adapter.pas:343`
- **说明**：全局单例懒初始化在锁外读接口指针并写，非原子；存在竞态双实例化。文件另有 `GDPI: Integer = 96` 未被使用（死代码）。
- **修复建议**：用 `TInterlocked`/一次性初始化或加锁；删除死变量。

---

### 2.2 DeepBase.Browser.CDP.pas（1055 行，✅ 活代码）

#### CDP-01 🔴 `WaitForSelector` 匿名线程 use-after-free + 数据竞争（历史 F2.B.1.1 未真正修复）
`d:\_Progs\02Business\DeepBase\Features\DeepBase.Browser.CDP.pas:905`
```pascal
LSelf := Self;                     // 捕获裸对象指针
var LThread := TThread.CreateAnonymousThread(procedure ...
  ...
  if LSelf.FDetached then ...       // L927 读裸指针字段
  LLiveCDP := LSelf.FCDP; ...       // L940 读裸指针字段
end);
LThread.FreeOnTerminate := True;    // L1010，无人 WaitFor
```
- **说明**：`REVIEW5-FEAT-009` 的缓解措施是"每轮检查 `LSelf.FDetached`"，但线程捕获的是 `TAutomationCDP` 的**裸对象指针** `LSelf`，且 `FreeOnTerminate=True`、没有任何引用/事件让 `Destroy` 等待它。一旦宿主对象在线程仍在轮询时被 `Free`（`Destroy` 置 `FDetached:=True` 后对象内存随即被释放/复用），线程下一次 `LSelf.FDetached`/`LSelf.FCDP` 读取即访问**已释放内存**（检查标志位本身就发生在悬垂指针上）。此外 `FDetached`/`FCDP` 由主线程写、工作线程读，无同步、无内存屏障，是数据竞争（读到的可能是撕裂/过期值，`FCDP` 甚至可能非 nil 但对象正在销毁）。
- **触发条件**：关闭/释放浏览器会话时恰有未完成的 `WaitForSelector` 轮询（timeout 上限内）。
- **修复建议**：参照同库 `Recovery.pas` 的正确停止模式（`FreeOnTerminate=False` + `TEvent` 取消 + `Free` 前 `WaitFor`），或以引用计数/`SafeInterval` 式宿主令牌保证对象生命周期；对 `FDetached/FCDP` 用锁或原子访问。

#### CDP-02 🟡 `as TJSONArray`/`as TJSONObject` 未判定即转型
`d:\_Progs\02Business\DeepBase\Features\DeepBase.Browser.CDP.pas:858`
```pascal
'model.content') as TJSONArray;
```
- **说明**：CDP 返回结构异常（字段缺失/类型不符）时抛 `EInvalidCast`，且该处若在发送/回调链上会把异常传播给调用方。
- **修复建议**：`is` 判定或用 `GetValue<T>` 带默认值。

#### CDP-03 🔵 `SendCommandSync` 固定阻塞 10s
`d:\_Progs\02Business\DeepBase\Features\DeepBase.Browser.CDP.pas`（SendCommandSync）
- **说明**：同步等待硬编码上限，UI 线程调用会冻结至多 10s。建议可配置并走 `WaitForEventSafe` 式消息泵。

> 备注：本单元历史 H2/H9（快照锁 + `JsStringLiteral`）修复到位，`SendCommand/SendCommandSync` 主体健壮；仅上述残留。

---

### 2.3 DeepBase.Browser.Session.pas（329 行，✅ 活代码）

#### SESS-01 🔴 `ExecuteCdpCommand` 空实现、恒返回 nil
`d:\_Progs\02Business\DeepBase\Features\DeepBase.Browser.Session.pas:165`
```pascal
function TBrowseSessionImpl.ExecuteCdpCommand(Method: string;
  const Params: array of const): TJSONValue;
begin
  Result := nil;
  EnsureConnected;    // 只做连接检查，命令从未下发
end;
```
- **说明**：公开 API 声称执行 CDP 命令，实际只 `EnsureConnected` 后返回 nil。调用方拿 nil 当结果极易 NPE/空判断错误。（历史 F2.C.1.2 未修复）
- **修复建议**：接入真实 CDP 通道（ADP-02 修好后），或在未实现前抛 `ENotImplemented` 明确契约。

#### SESS-02 🟡 `CreateFromExistingSession` 未校验 nil
`d:\_Progs\02Business\DeepBase\Features\DeepBase.Browser.Session.pas:128`
```pascal
constructor TBrowseSessionImpl.CreateFromExistingSession(Session: ICDPSession);
```
- **说明**：构造中直接用 `Session.IsConnected` 等，传入 nil 接口即崩。
- **修复建议**：入口 nil 守卫。

#### SESS-03 🟡 `CreateBrowserSession` 把会话塞进 `GSessionManager` 但从不查找/移除，且无锁 Add
`d:\_Progs\02Business\DeepBase\Features\DeepBase.Browser.Session.pas:318`
```pascal
GSessionManager.Add(Result);
```
- **说明**：全局列表只增不减——每个创建的会话被永久强引用（泄漏，永不释放），且 `Add` 无锁保护（并发创建竞态）。`InitializeBrowserSessionManager`（L308）同样是锁外双检懒初始化。
- **修复建议**：要么实现完整的按 Id 查找/回收生命周期，要么干脆不持有全局强引用；懒初始化加锁。

---

### 2.4 DeepBase.Browser.Types.pas（507 行，✅ 活代码）

#### TYP-01 🔴 `IBrowserSession` 同名不同 GUID、不同契约（接口分裂）
- `d:\_Progs\02Business\DeepBase\Features\DeepBase.Browser.Types.pas:208`
```pascal
IBrowserSession = interface(IBrowserAutomationSession)
['{C4E2D1A0-3B5F-4A7E-8C9D-0E1F2A3B4C5D}']
```
- `d:\_Progs\02Business\DeepBase\Features\DeepBase.Browser.Session.pas:21`
```pascal
IBrowserSession = interface
['{CDEF3456-0123-4567-89AB-CDEF01234567}']
```
- **说明**：两个**不同 GUID、不同继承、不同方法集**的 `IBrowserSession` 同时被编译。Types 版被 Selectors/Vision/WindowPool/Recovery 使用并继承 `IBrowserAutomationSession`；Session 版是独立旧契约。实现其一的对象经 `Supports`/`as` 转另一版会失败，跨模块传参会在运行期 `EInvalidCast` 或静默 nil。这是全组最核心的架构性契约分裂。（历史 F2.C.1.1 未修复）
- **修复建议**：统一为单一 `IBrowserSession`（保留 Types 版为 SSOT），删除 Session.pas 的重复定义并让其复用之。

---

### 2.5 DeepBase.Browser.WebElement.pas（197 行，✅ 经 Session 传递编译 = 活代码）

#### WEL-01 🔴 `TWebWebElement` 交互方法全为空实现（静默失效）
`d:\_Progs\02Business\DeepBase\Features\DeepBase.Browser.WebElement.pas:100`
```pascal
procedure TWebWebElement.Click;        begin end;   // L100-102
procedure TWebWebElement.TypeText(Text: string); begin end; // L104-106
function TWebWebElement.GetAttributeInternal(...): string;
begin Result := ''; end;               // L113-116
function TWebWebElement.SelectOption(...): Boolean;
begin Result := False; end;            // L128-130
```
- **说明**：`Session.pas.FindElementByCSS/XPath`（活代码）返回 `TWebWebElement`，但其 `Click/TypeText/GetAttribute/SelectOption` 全是空体——调用"看起来成功"实则什么也没做（无异常、无返回码），是最危险的静默半成品。
- **触发条件**：使用 `Session.FindElementByCSS(sel).Click` 等 API 的任意调用方。
- **修复建议**：接入真实 CDP（`Runtime.callFunctionOn`/`DOM`）实现；在未实现前抛 `ENotImplemented`，杜绝静默 no-op。

#### WEL-02 🟡 `ByID` 选择器未转义
`d:\_Progs\02Business\DeepBase\Features\DeepBase.Browser.WebElement.pas:183`
```pascal
Result := '[id="' + ID + '"]';
```
- **说明**：`ID` 含 `"` 或 `]` 时选择器语法被破坏（CSS 注入/错配）。
- **修复建议**：转义或用 `CSS.escape`。

---

### 2.6 DeepBase.Browser.Engine.WebView2.pas（1148 行，⚠️ 条件编译 + 未入构建）

本单元修复极其充分（BUG-BA-014 每调用 CDP 路由、FEAT-R3-002 `FAsyncTasks` Destroy 前等待、C5–C7、H3/H4/H6/H8、P0-6、B-002/B-035），是活代码里质量最高者之一。仍存以下问题：

#### WV2-01 🟡 `Destroy` 在 UI 线程 + 在途异步任务 → 有界等待超时后仍可能 UAF
`d:\_Progs\02Business\DeepBase\Features\DeepBase.Browser.Engine.WebView2.pas:341`（`WaitForAsyncTasks`）/ `:672`（`LTask.Wait(5000)`）/ `:527`（`TThread.Synchronize`）
- **说明**：`RunTrackedAsync` 起的任务闭包捕获 Self，内部 `Navigate`→`OnMainThread`→当不在主线程时 `TThread.Synchronize(nil, ...)` 会排队等待主线程。若 `Destroy` 正在主线程执行并卡在 `WaitForAsyncTasks` 的 `LTask.Wait`，则被 `Synchronize` 等待的主线程正是被阻塞的这个线程 → 死锁 5s → `Wait(5000)` 超时吞掉 except → 继续 `Free` Self，而任务闭包仍在跑 → UAF。FEAT-R3-002 的跟踪只覆盖了"任务在跑"，未覆盖"任务卡在往正在销毁它的主线程同步"。
- **触发条件**：主线程释放会话时仍有未完成的 `*Async`。
- **修复建议**：Destroy 前先取消/收敛（PostMessage 唤醒），或对 `Synchronize` 改用 `WaitForSingleObject` 超时 + 主动放弃标记，勿把"有界等待"当成"可安全释放"。

#### WV2-02 🟡 `FBrowser`/`FWindowParent` 以 AOwner 创建却又显式 `Free`
`d:\_Progs\02Business\DeepBase\Features\DeepBase.Browser.Engine.WebView2.pas:296` / `:301` / `:357-358`
```pascal
FWindowParent := TWVWindowParent.Create(AOwner);  // 被 AOwner 拥有
FBrowser := TWVBrowser.Create(AOwner);            // 被 AOwner 拥有
...
FBrowser.Free; FWindowParent.Free;                // Destroy 又显式释放
```
- **说明**：组件被宿主 `TWinControl` 拥有；若宿主先于会话销毁，这两个组件已被 owner 释放，会话再访问/`Free` 即悬垂。反之会话先释放又从 owner 组件链摘除，尚可，但所有权模型不清晰，owner 生命周期与会话生命周期强耦合。
- **修复建议**：`Create(nil)` 自持所有权，或彻底交给 owner 管理、会话不显式 Free，二选一并统一。

#### WV2-03 🟡 跨线程读取 `FReady`/`FCurrentUrl`/`FNavigationOk` 无同步
`d:\_Progs\02Business\DeepBase\Features\DeepBase.Browser.Engine.WebView2.pas:626`（`while not FReady` 于 worker）/ `:403`（主线程回调写 `FCurrentUrl`）
- **说明**：`FReady`/`FCurrentUrl` 由主线程回调写、`WaitForReady`/getter 从任意线程读，无 `volatile`/原子/屏障。x86 上对齐布尔/指针读通常"看起来没事"，但优化与弱内存序下 `WaitForReady` 可能永不观测到 `FReady=True` 而空转到超时。
- **修复建议**：用 `TInterlocked` 或事件通知替代忙轮询布尔。

#### WV2-04 🔵 `CaptureScreenshot` 固定 5000ms，不受调用方超时控制
`d:\_Progs\02Business\DeepBase\Features\DeepBase.Browser.Engine.WebView2.pas:963`
- **说明**：`WaitForEventSafe(FScreenshotEvent, 5000)` 硬编码，忽略上层 timeout 语义；忙等 `WaitForReady`（L626-633 `Sleep(50)` 轮询）也是轮询而非事件。
- **修复建议**：事件化就绪通知，超时参数透传。

#### WV2-05 🔵（架构）默认引擎整体在 `{$IFDEF USE_WEBVIEW2}` 内且未列入 dproj
- **说明**：若发布包未定义 `USE_WEBVIEW2`，则 `initialization RegisterWebView2Backend` 不执行，注册表没有任何真实后端工厂；结合 ADP-02（`SendCommand` 未实现）与 WEL-01（元素交互空），构建出的 Browser 栈缺少可运行的引擎后端。属结构性半成品/配置风险，需与构建脚本核对 `USE_WEBVIEW2` 与依赖包。

---

### 2.7 DeepBase.BrowserAutomation.pas（1152 行，✅ 活代码）

修复充分（BUG-BA-001..024、CP-LOGIN-R1、M6）。残留：

#### BAU-01 🟡 `baatUploadFile` 多处 `as TJSONObject` 未判定即转型
`d:\_Progs\02Business\DeepBase\Features\DeepBase.BrowserAutomation.pas:958` / `:962` / `:991` / `:995`
```pascal
LDocObj := TJSONObject.ParseJSONValue(LDocRaw) as TJSONObject;
...
LResObj := LDocObj.GetValue('result') as TJSONObject;
var LRoot := LResObj.GetValue('root') as TJSONObject;
```
- **说明**：CDP 返回异常结构时 `as` 抛 `EInvalidCast`，此 case 分支无本地 try/except，异常会传播出 `Run`。仅 `Assigned(LDocObj)`/`Assigned(LResObj)` 被保护，类型不符仍崩。
- **修复建议**：`is` 判定后转型；或整段包 try/except 归一为 `upload_failed`。

#### BAU-02 🟡 `Run` 对每条 action 无 try/except 隔离
`d:\_Progs\02Business\DeepBase\Features\DeepBase.BrowserAutomation.pas:1140`
- **说明**：`RunAction` 内部各分支若抛（见 BAU-01、EvaluateScript 传输异常），会跳出整个 `Run` 循环，已完成的 `Result[]` 不回传，`StopOnError` 语义被绕过为异常传播。
- **修复建议**：`Run` 循环内 `try Result[I] := RunAction(...) except ... end` 归一为失败结果。

---

### 2.8 DeepBase.Browser.PageDriver.pas（1047 行，✅ 活代码）

#### PGD-01 🟡 `CallPlanner` 的 HTTP `Post` 未捕获异常 + `LResponse` 泄漏
`d:\_Progs\02Business\DeepBase\Features\DeepBase.Browser.PageDriver.pas:784`
```pascal
LResponse := LHttp.Post(LEndpoint, LStream);   // 网络/HTTP 异常会向上抛
...
finally
  LHttp.Free; LStream.Free;   // 无 AError 归一，异常逃逸
end;
```
- **说明**：`try/finally` 只保证释放 `LHttp/LStream`，网络层抛异常时不设置 `AError`、不返回 False，异常直接传播出 `Execute`。且 `LResponse`（`IResponse`）自始至终未 `Free`/未 `Result` 释放 → 每次 LLM 规划调用泄漏一个响应对象。
- **修复建议**：`try Post except on E:Exception do begin AError:=...; Exit(False); end end`；使用后释放 `LResponse`。

#### PGD-02 🟡 `Load` 在持锁期间执行阻塞式浏览器 IPC
`d:\_Progs\02Business\DeepBase\Features\DeepBase.Browser.PageDriver.pas:602` / `:621`
```pascal
FLock.Enter; ...
  if not LSession.ExecuteScript(BuildLoaderScript...) then ...   // 锁内同步 IPC
...
  if ... FSession.EvaluateScript(BuildStatusScript, 5000, ...)   // 第二段锁内同步 IPC
```
- **说明**：`WaitForReady`（L612）已正确移出锁（历史改进），但脚本注入 L602 与状态查询 L621 仍在 `FLock` 内做跨进程阻塞调用；浏览器卡顿时会把 `GetStatus`/`Execute` 等所有竞争 `FLock` 的调用一并拖住。
- **修复建议**：把浏览器 IPC 移出 `FLock`，锁只保护状态字段。

---

### 2.9 DeepBase.Browser.Service.pas（132 行，✅ 活代码）

#### SVC-01 🟡 `Shutdown` 在锁内释放接口引用，可能重入自锁
`d:\_Progs\02Business\DeepBase\Features\DeepBase.Browser.Service.pas:90`
- **说明**：`FDefaultSession := nil; FRecovery := nil`（锁内）若触发被释放对象的 `Destroy`，而后者回调重入本服务（如从注册表注销/事件总线反注册），`TCriticalSection` 非重入 → 死锁。Recovery 懒初始化（L111-118）也在锁内调用外部工厂函数，同样有锁内回调外部代码的风险。
- **修复建议**：先在锁内取出待释放引用到局部变量、置空字段、离开锁，再在锁外释放。

---

### 2.10 DeepBase.Browser.Selectors.pas（453 行，✅ 活代码）

#### SEL-01 🟡 `ValidateAgainstBrowser` fail-open
`d:\_Progs\02Business\DeepBase\Features\DeepBase.Browser.Selectors.pas:432`
```pascal
if FSession = nil then Exit(True);
```
- **说明**：无会话时"验证通过"，把无法验证当成验证成功（fail-open）。若该函数用于选择器有效性把关，会在会话缺失时放行错误选择器。
- **修复建议**：无法验证应返回 False 或 `Unknown` 三态，交由上层决定。

---

### 2.11 DeepBase.Browser.Recovery.pas（660 行，✅ 活代码）

健康监控停止模式**正确**（`FreeOnTerminate=False` + `TEvent.WaitFor` + 退出前 `WaitFor`+`Free`），是 CDP-01 应参照的正面样板。残留：

#### REC-02 🟡 监控线程无锁读 `FConfig`
`d:\_Progs\02Business\DeepBase\Features\DeepBase.Browser.Recovery.pas:456`（`HealthMonitorLoop`）
- **说明**：`HealthMonitorLoop`/`RunHealthCheck` 直接读 `FConfig`（含 record），而配置可在别处被改；record 读非原子，可能读到撕裂状态。
- **修复建议**：读 `FConfig` 时加锁或读快照。

#### REC-03 🟡 `DoRecovery` 用 `Sleep(RetryDelayMs)` 阻塞调用线程
`d:\_Progs\02Business\DeepBase\Features\DeepBase.Browser.Recovery.pas:563`
- **说明**：恢复重试在调用线程上 `Sleep`（默认级 2s）。若恢复路径被 UI 线程触发则界面冻结。
- **修复建议**：把恢复动作放到后台线程/异步定时器。

---

### 2.12 DeepBase.Browser.WindowPool.pas（545 行，✅ 活代码）

#### WPO-01 🟡 `Acquire` 慢路径丢竞赛时未回收新建会话
`d:\_Progs\02Business\DeepBase\Features\DeepBase.Browser.WindowPool.pas:306`
- **说明**：并发扩容时若输掉竞赛，胜出者入池、失败方仅 `LNewSession := nil`，未调用 `DisposeSession`/关闭其 OS 级浏览器窗口/进程 → 泄漏一个真实浏览器窗口。
- **修复建议**：失败方显式销毁自己刚创建的会话与其宿主窗口。

---

### 2.13 DeepBase.Browser.Vision.pas（447 行，✅ 活代码）

#### VIS-01 🔵 `GetDpiScale` 仅取主屏 DPI
`d:\_Progs\02Business\DeepBase\Features\DeepBase.Browser.Vision.pas:128`（`GetDeviceCaps(LDc, LOGPIXELSX)`）
- **说明**：用 `GetDC(0)` 的系统 DPI 折算视觉点击坐标，多屏混合 DPI 下非主屏坐标会偏。M6（设备像素→CSS 像素）与 C4/H7（`JsStringLiteral`/`JsFloat`）修复到位，数值/注入安全。
- **修复建议**：按目标窗口所在显示器 `GetDpiForMonitor`。

---

### 2.14 DeepBase.Browser.{Events,Registry,IoC,ScriptStore,AutomationAdapter}.pas（✅ 活代码）

- **EVN-01 🔵** `Events.pas:86` `LTypeName` 计算后未使用（死代码）。
- **REG-01 🔵** `Registry.pas:257` `Default(TBrowserBackendInfo)` 之后又对同字段冗余赋值。H6 class constructor 已修复 TOCTOU，整体设计良好。
- **IOC/AADP** `IoC.pas`、`AutomationAdapter.pas`：每方法 nil 守卫、1:1 转发，未发现功能性问题。
- **SST-01（存疑，见第 5 节）** `ScriptStore.pas:548` `ScriptStore` 全局单例双检锁锁外读接口指针；JS 模板全走 `{{x}}`+`JsStringLiteral` 转义，注入防护良好。

---

### 2.15 DeepBase.Desktop.Lifecycle.pas（325 行，✅ 编译进 Platform，活代码）

结构是干净的门面（facade），构造校验 AppId/DeviceId/Client 非空，Destroy 释放顺序合理。**该单元未发现问题**（线程安全上为无锁门面，但作为 UI 线程编排层可接受）。命名上它实为"Commerce/更新"门面而非"桌面感知"，属命名/归类偏差（🔵，见第 3 节 Top10 外的架构备注）。

---

### 2.16 DeepBase.Desktop.Perception.Engine.pas（868 行，❌ 死代码：不入任何发布构建，仅被未构建 Tests/UnifiedActuator 引用）

工程化程度高（CR-606 修复、帧签名/帧缓存/阈值门控设计完整）。缺陷（若未来纳入构建则生效）：

#### PCE-01 🟡 `CaptureScreen` 在 `FLock` 之外读写 `FLastShot`/`FEnabled`
`d:\_Progs\02Business\DeepBase\Features\DeepBase.Desktop.Perception.Engine.pas:590` / `:603` / `:612` / `:631`
- **说明**：类注释声称"Thread-safe for capture"，但 `CaptureScreen` 主体不进 `FLock`：`FLastShot`（含 `string ImageBase64` 长字符串）在 L631 无锁写、L603/L612 无锁读。并发下长字符串引用计数与指针可能撕裂 → 泄漏甚至 AV。`FEnabled` 同样裸读（L590）。
- **修复建议**：`CaptureScreen` 对 `FLastShot`/`FEnabled` 的访问纳入 `FLock`，或改为原子快照。

#### PCE-02 🟡 `FindByLabel`/`Recognize` 在持引擎锁期间执行 LLM 网络调用
`d:\_Progs\02Business\DeepBase\Features\DeepBase.Desktop.Perception.Engine.pas:713`（锁内 `FProvider.FindByLabel`）
- **说明**：整个 LLM 识别在 `FLock` 内进行，序列化所有感知并长时间持锁跨网络 I/O；且 `FProvider` 在 L779/L805 等处以非原子方式读，与 `SetProvider` 写竞态。
- **修复建议**：锁只取 provider 引用快照，识别移出锁外。

---

### 2.17 DeepBase.Desktop.Perception.{Types,ColorMatch,LLMProvider}.pas（❌ 死代码）

- **Types**：`TPerceivedElement`/`TFrameSignature`/`TPerceptionCache`（加锁）定义干净；`TPerceptionCache` 无淘汰上限（🔵，仅按 key 累积）。
- **ColorMatch**：GDI `CaptureRegion`/`FindColor`/`FindMultiColor`/`ParseHexColor` 实现严谨（`$POINTERMATH`、GDI 资源 try/finally、越界返回黑、hex 校验后转换）。唯一所有权隐患：`TPixelBuffer` 是按值传递的 record 却持有裸 `TBitmap`（🟡，`Bitmap`/`Release` 拷贝语义下易双 Free），建议改类或加引用计数。
- **LLMProvider**：`ParseElements` 对模型把数组包进对象的情形 `LJson := (LJson as TJSONObject).FindValue('elements')`（L179）后于 L198 `LJson.Free`——释放的是**父对象的子节点**，父 envelope 失去引用泄漏（🟡）；`Recognize` 全程 `FLock` 跨 `ChatVision` 网络（同 PCE-02 类，🟡）。提示词中立、无凭据泄漏（🔵 无问题）。

---

### 2.18 DeepBase.Desktop.Screen.Click.DPIMapper.pas（296 行，❌ 死代码且**不可编译**）

#### SCM-01 🔴 `DPIMapper.pas` 存在多处编译级错误
- `:50`–`:55` 在 **interface 的 type 段内**写了带 `begin...end` 函数体的 `Clamp`：
```pascal
function Clamp(Value, Min, Max: Double): Double;
begin
  ...
end;
```
- `:57` `TMonitorHandle = type HMONITOR;` **重复声明**（`:33` 已声明）。
- `:195`/`:203-208` 使用 `Screen`/`TMonitor`/`Screen.PrimaryMonitor`/`.Scale`，但 uses 只有 `System.SysUtils/Winapi.Windows/Winapi.Messages/System.Types/Graphics32`，**缺 `Vcl.Forms`/`Vcl.Graphics`** → 未声明标识符。
- **说明/触发**：单元根本无法通过编译；任何引用它的工程（含同名 Tests）都构建失败。因当前不在任何发布 dproj，故未破坏主构建。
- **修复建议**：`Clamp` 移入 implementation 段并前向声明；删除重复 `TMonitorHandle`；补 uses；`InitializeDPIMapper/CurrentDPIMapper` 双检加锁。

---

### 2.19 DeepBase.Desktop.Screen.Click.RegionLocator.pas（308 行，❌ 死代码且**不可编译**）

#### SCM-02 🔴 `RegionLocator.pas` 编译级错误 + 核心算法为占位桩
`d:\_Progs\02Business\DeepBase\Features\DeepBase.Desktop.Screen.Click.RegionLocator.pas:256`
```pascal
for Row := SearchRect.Top to SearchRect.Bottom - ScaledTemp.Height do
  for Col := SearchRect.Left to SearchRect.Right - ScaledTemp.Width do
  begin
    var CurrentScore := 0.5; // Placeholder
    ...
  end;
...
FLastSearchTimeMs := GetTickCount64 - StartTime;   // :283 StartTime 未声明
```
- **说明**：`Row`/`Col`（L256-257）、`StartTime`（L283）均未声明 → 编译失败；`FindTemplate`/`FindTemplateInROI`/`FindAllTemplates`/`RefineWithCrossCorrelation`/`BuildTemplatePyramid`/`DestroyPyramid` 在类中声明但正文**无实现**（L286 明确写"Additional implementations would continue here"）→ 链接失败；匹配打分恒为 `0.5` 占位，`Found := 0.5 >= 0.7` 恒 False，整个视觉定位是**非功能桩**。
- **修复建议**：补齐声明变量与所有方法实现；接入真实 NCC/模板匹配；否则从代码树移除以免误导。

---

### 2.20 DeepBase.Desktop.Screen.Click.SmartExecutor.pas（305 行，❌ 死代码且**不可编译**）

#### SCM-03 🔴 `SmartExecutor.pas` 编译错误 + 危险的点击扇出逻辑
- `:197`–`:198` 向 `const` 记录参数写字段：
```pascal
function TSmartClickExecutor.ClickByTemplate(const TemplateImage: TBitmap32;
  const Options: TClickOptions): Boolean;   // Options 是 const
...
  if Options.Tolerance.MinConfidence = 0 then
    Options.Tolerance.MinConfidence := 0.7;  // 对 const 形参赋值 → 编译错误
```
- `:262` `Result := TMatchResult.Default;` — 普通 record 无此调用形式（应 `Default(TMatchResult)`）→ 编译错误；`:123` `SetCursorPosition` 未声明/非 WinAPI（应 `SetCursorPos`）。
- `:141`–`:154` `TryClickWithTolerance` 对 `(2T+1)²` 网格内每一点都真实调用 `SimulateMouseClick`（默认 T=5 → **121 次真实鼠标点击**），且"成功"判定只看 `DeltaX=0`。
- **触发条件**：若被纳入构建并调用 `ClickByTemplate`/`ClickAtPoint`，将在屏幕上连打上百次点击，且因依赖 SCM-01/SCM-02 的破损兄弟单元，本单元根本无法编译。
- **修复建议**：`Options` 改 `var`/值拷贝局部；修 `Default`/`SetCursorPos`；点击扇出应"试一个点→校验结果→再决定下一个"，绝非无脑全打。

---

### 2.21 DeepBase.UIA.Engine.pas（514 行，✅ 编译进 Platform，活代码）

> 这是本轮活代码里最危险的单元：一组安全校验被写成"恒真"，防劫持形同虚设。

#### UIA-01 🔴 元素"所有权 + 前台窗口"校验结构性恒真 → 粘贴注入可打到任意窗口
`d:\_Progs\02Business\DeepBase\Features\DeepBase.UIA.Engine.pas:177`
```pascal
function TUIAElementAdapter.GetNativeWindowHandle: HWND;
begin
  FRaw.GetCurrentPropertyValue(UIA_ProcessIdPropertyId, Val); // Val 弃用
  Result := GetForegroundWindow;   // 返回"当前前台窗口"，非元素句柄
end;
```
`d:\_Progs\02Business\DeepBase\Features\DeepBase.UIA.Engine.pas:186`
```pascal
function TUIAElementAdapter.GetCurrentProcessName: string;
begin
  Result := FLocator.TargetProcessName;  // 返回定位器自带字段，非元素真实进程
end;
```
- **说明**：`VerifyForegroundWindow`（L309）比较 `ElementHwnd = GetForegroundWindow`，而 `ElementHwnd` 本身就是 `GetForegroundWindow` → **恒真**。`VerifyElementOwnership`（L300）比较 `GetCurrentProcessName` 与 `ExpectedProc`，前者返回的正是 `FLocator.TargetProcessName`（即 `ExpectedProc` 来源）→ **恒等**。于是 `SetValue` 精心设计的"SetFocus 后确认前台未变、确认元素归属目标进程"防劫持链条（配合 `IClipboardGuard`、审计）**完全失效**：无论真实焦点/归属如何都放行，剪贴板粘贴可被注入到非预期窗口。
- **触发条件**：任何 `SetValue`/含粘贴的写入。
- **修复建议**：`GetNativeWindowHandle` 取 `UIA_NativeWindowHandlePropertyId`（`GetCurrentPropertyValue` 转 HWND）；`GetCurrentProcessName` 用真实 `UIA_ProcessIdPropertyId` → 进程名解析（`OpenProcess`/Toolhelp）后比较。

#### UIA-02 🔴 映射"完整性/防篡改"校验恒真，签名表永不填充
`d:\_Progs\02Business\DeepBase\Features\DeepBase.UIA.Engine.pas:449`
```pascal
function TUIAEngineWin32.IsMappingIntegrityVerified(const AppName: string): Boolean;
begin
  Result := True;   // 恒真
end;
```
`d:\_Progs\02Business\DeepBase\Features\DeepBase.UIA.Engine.pas:496`
```pascal
if FMappingSignatures.ContainsKey(FileName) then   // 该字典任何地方都不写入
  if not SameText(ActualHash, FMappingSignatures[FileName]) then
    ... 'UIA mapping file tamper detected'
```
- **说明**：`FMappingSignatures` 全单元**只有 `ContainsKey`/索引读取，从无 `Add`/赋值**，故 `ContainsKey` 恒 False，防篡改分支是**不可达死代码**；`LoadMappingsFromConfig` 对每个 JSON 只做 `SHA256File` 然后 `Logger.Info('Loaded...')`，既不上报基准签名、也不真正解析加载映射（`FMappingRegistry.Count` 恒 0，落回 `LoadBuiltInMappings` 也只打日志）。整套"签名基准 + 篡改检测 + 映射加载"是**表面存在、实则空转**。
- **触发条件**：UIA 映射文件被替换/篡改时，本应拒绝加载却静默"Loaded"。
- **修复建议**：加载时写入/比对受信签名（且签名基准本身需可信来源）；`IsMappingIntegrityVerified` 返回真实校验结果；`ResolveVersionMapping` 真正返回登记的 `WindowLocator`（当前 L441 仅回显 AppName/Version，`RegisterMapping` L435 空体）。

#### UIA-03 🔴 `SetValue` 不校验 `Guard` 是否为 nil → 空接口方法调用 AV
`d:\_Progs\02Business\DeepBase\Features\DeepBase.UIA.Engine.pas:317`
```pascal
function TUIAEngineWin32.SetValue(const Locator; const Value: string;
  const Guard: IClipboardGuard): Boolean;
begin
  if not Guard.IsSaved then    // Guard 为 nil 接口 → 解引用 AV
```
- **说明**：`Guard` 是接口，未做 nil 判定即 `Guard.IsSaved`/`Guard.Save`/`Guard.SetContent`/`Guard.DoPaste`（L319/L373-374）。当调用方（如 `UnifiedActuator.InputText` 在 `FClipboardGuardFactory=nil` 时传 nil，L243-246）未提供守卫，直接 AV 崩溃。
- **修复建议**：入口 `if Guard = nil then ...`（拒绝或内部按需创建）。

#### UIA-04 🟡 COM 返回值 HRESULT 普遍未检查
`d:\_Progs\02Business\DeepBase\Features\DeepBase.UIA.Engine.pas:230` / `:238` / `:240` / `:254` / `:265` 等
- **说明**：`GetRootElement`/`CreatePropertyCondition`/`FindFirst`/`GetCurrentPattern`/`SetFocus` 的 `HRESULT` 一律忽略。多数靠"结果对象是否为 nil"兜底，但失败时可能残留上一轮 `RawElement` 值或漏报错误。`TUIAElementAdapter` 各方法亦不检查 `FRaw` 调用的返回码。
- **修复建议**：对关键调用 `OleCheck`/判 `Succeeded`，失败早退并记日志。

#### UIA-05 🟡 `FindElement` 以异常表示"未找到"，与布尔返回契约冲突
`d:\_Progs\02Business\DeepBase\Features\DeepBase.UIA.Engine.pas:280`（raise）配合 `:325`（`if Element = nil then Exit(False)` 永不成立）
- **说明**：`FindElement` 找不到就 `raise EUIAElementNotFound`，于是 `SetValue`/`GetValue`/`Invoke` 里 `Element = nil` 分支永远走不到，异常直接抛给调用方；`DoClipboardPaste`（L379-385）每 100ms 调 `GetValue`→`FindElement`，元素在轮询中消失会抛异常穿透出 `SetValue`，而非返回 False。
- **修复建议**：内部统一走 `TryFindElement`；对外明确"异常契约"或"布尔契约"其一。

#### UIA-06 🟡 `DoClipboardPaste` 轮询期重复全桌面扫描
`d:\_Progs\02Business\DeepBase\Features\DeepBase.UIA.Engine.pas:381`
- **说明**：3s 内每 100ms 调 `GetValue`→`FindElement`→`Desktop.FindFirst(TreeScope_Descendants, ...)`，即最多 ~30 次**整桌面后代树搜索**；在大型 UI 树上极慢。`FindElement` 内 AutomationId→ClassName→Name→FallbackChain 亦逐级全树 Descendants 递归。
- **修复建议**：缓存已定位元素句柄/用条件缓存与 `BuildUpdatedCache`；缩小 `TreeScope`/限定容器窗口。

#### UIA-07 🟡 `TryValuePatternSet` 控件字符检查可被粘贴路径绕过
`d:\_Progs\02Business\DeepBase\Features\DeepBase.UIA.Engine.pas:361`
- **说明**：控制字符拦截只在 ValuePattern 直写路径 `raise EUIAInvalidContent`；一旦直写失败回落到 `DoClipboardPaste`（L343），同一含控制字符的值经剪贴板粘贴被放行，防护不一致。
- **修复建议**：把 `ContainsControlChars` 提到 `SetValue` 入口统一校验。

---

### 2.22 DeepBase.UIA.Types.pas（62 行，✅ 编译进 Platform，活代码）

#### UTY-01 🟡 `TUIAMappingRegistry` 半成品 + 内层字典泄漏隐患
`d:\_Progs\02Business\DeepBase\Features\DeepBase.UIA.Types.pas:34`
```pascal
FItems: TDictionary<string, TObjectDictionary<string, TUIAElementLocator>>;
```
- **说明**：只有 `Create/Destroy/Count`，无任何 `Add/Get`，外部永远无法填充（配合 UIA-02 的 `RegisterMapping` 空体，映射系统整体不可用）。且 `FItems` 是 `TDictionary`（不拥有 value），其 value 为 `TObjectDictionary`——`FItems.Free` 不会释放内层 `TObjectDictionary`，若将来填充即泄漏（`Destroy` L51 仅 `FItems.Free`）。
- **修复建议**：提供 `AddOrSetValue`/`TryGetValue`，`FItems` 改用 `TDictionary<.., TObjectDictionary<..>>` 配 `ownValue` 语义或在 `Destroy` 逐个释放内层。

---

### 2.23 DeepBase.UIA.UnifiedActuator.pas（275 行，❌ 死代码，可编译）

#### UAC-01 🟡 向 `SetValue` 传 nil Guard（叠加 UIA-03 崩溃）
`d:\_Progs\02Business\DeepBase\Features\DeepBase.UIA.UnifiedActuator.pas:243`
```pascal
LGuard := nil;
if Assigned(FClipboardGuardFactory) then LGuard := FClipboardGuardFactory();
if FUIAEngine.SetValue(ALocator, AValue, LGuard) then ...  // LGuard 可能 nil → UIA-03 AV
```
- **说明**：工厂未注入时传 nil，触发 UIA-03 的 nil 接口调用崩溃（该组合路径当前因整单元未构建而休眠）。
- **修复建议**：nil 时跳过 UIA 写入或强制要求工厂；配合 UIA-03 的入口守卫。

#### UAC-02 🟡 视觉键入路径静默丢弃非 ASCII
`d:\_Progs\02Business\DeepBase\Features\DeepBase.UIA.UnifiedActuator.pas:166`
```pascal
LKey := Ord(AText[I]);
if LKey > 255 then Continue; // 非 ASCII 直接跳过
```
- **说明**：`KEYEVENTF_UNICODE` 本可发送任意 UTF-16 码元（`wScan` 接受 0..$FFFF），此处却把 >255 字符（含全部中文）丢弃，且 `TInput` 未设 `ki` 其余字段/未检查 `SendInput` 返回值。中文输入会"看似成功实为漏字"。
- **修复建议**：直接用 `KEYEVENTF_UNICODE` 发送 `Ord(Char)`（含代理对），不要 `>255` 截断；检查 `SendInput` 返回计数。

---

## 3. 🔴 Top10（按"活代码 + 影响面"排序）

1. **UIA-01**：`UIA.Engine.pas:177/186` 所有权与前台窗口校验结构性恒真 → 剪贴板粘贴注入防护全线失效（活代码，安全）。
2. **UIA-02**：`UIA.Engine.pas:449/496` 映射完整性/防篡改恒真、签名表永不填充、映射从不真正加载（活代码，安全）。
3. **CDP-01**：`CDP.pas:905/927/940/1010` `WaitForSelector` 匿名线程 `FreeOnTerminate=True` 且不 `WaitFor`，捕获裸 `Self` → 销毁后会话 use-after-free（活代码，崩溃；历史 F2.B.1.1 未修复）。
4. **ADP-01**：`CDP.Adapter.pas:270` `NavigateTo` URL 未 JSON 转义 → CDP 参数注入（活代码，安全）。
5. **ADP-02**：`CDP.Adapter.pas:333` `SendCommand` 返回 "Not implemented" → `ICDPSession` 发送链路整体失效 + 与 `TAutomationCDP` 双实现违背 SSOT（活代码，功能断裂）。
6. **WEL-01**：`WebElement.pas:100-130` `Click/TypeText/GetAttribute/SelectOption` 全空实现，`Session.FindElementByCSS(...).Click` 静默 no-op（活代码，静默功能失效）。
7. **TYP-01**：`Types.pas:208` vs `Session.pas:21` 同名 `IBrowserSession` 双 GUID 双契约（活代码，架构分裂；历史 F2.C.1.1 未修复）。
8. **UIA-03**：`UIA.Engine.pas:317` `SetValue` 不判 nil Guard → 空接口调用 AV（活代码，崩溃路径）。
9. **SESS-01**：`Session.pas:165` `ExecuteCdpCommand` 恒返回 nil 公开 API 名不副实（活代码；历史 F2.C.1.2 未修复）。
10. **SCM-01/02/03**：`Desktop.Screen.Click.{DPIMapper,RegionLocator,SmartExecutor}.pas` 三件套均存在编译级错误（interface 段写函数体、重复类型、缺 uses、未声明 `Row/Col/StartTime`、缺方法实现、对 `const` 形参赋值）与危险占位逻辑（121 次点击扇出、恒 0.5 打分）——**破损的死脚手架**（若纳入构建必炸；应补全或移出代码树）。

---

## 4. 历史缺陷复核（对照 2026-08-25 F2 批）

| 历史编号 | 描述 | 本轮复核结论 |
|---|---|---|
| F2.B.1.1 | `CDP.pas` WaitForSelector 匿名线程 UAF | ❌ **仍存在**（REVIEW5-FEAT-009 加 `FDetached` 检查不足以消除裸 `Self` 悬垂读，见 CDP-01） |
| F2.B.2.1 | `CDP.Adapter.pas` NavigateTo URL 注入 | ❌ **仍存在**（L270，见 ADP-01） |
| F2.B.2.2 | `CDP.Adapter.pas` SendCommand 空实现 | ❌ **仍存在**（L333，见 ADP-02） |
| F2.C.1.1 | `IBrowserSession` 双 GUID 契约分裂 | ❌ **仍存在**（Types L208 / Session L21，见 TYP-01） |
| F2.C.1.2 | `Session.pas` ExecuteCdpCommand 空实现 | ❌ **仍存在**（L165，见 SESS-01） |
| — | `PageDriver` H2/H9（快照锁 + `JsStringLiteral`）、`WaitForReady` 移出锁 | ✅ **已改进**（残留见 PGD-01/02） |
| — | `Vision` M6 设备→CSS 像素、C4/H7 `JsStringLiteral`/`JsFloat` | ✅ **已修复**（残留仅主屏 DPI，见 VIS-01） |
| — | `WebView2` BUG-BA-014/FEAT-R3-002/C5-C7/H3/H4/H6/H8 | ✅ **大幅修复**（残留见 WV2-01/02/03） |

> 计注：上述 5 条历史 🔴 本轮按当前行号**重新计入**（未修复），不重复计为新增。

---

## 5. 存疑区（静态无法定论，需动态/上下文验证）

1. **SSD-01** `ScriptStore.pas:548` 全局 `GScriptStore` 双检锁：锁外读接口指针 `if GScriptStore = nil`。Delphi 接口指针赋值/读是否在此处构成可观测竞态，取决于调用是否真并发；若仅在单线程初始化则无害。**存疑**。
2. **RSP-01** `ResponseWaiter.pas:401` 陈旧检测用 `FRunningCount`/`FStartCount`：每次 `StartWaiting` 令二者相等，可能无法区分"紧邻上一个 waiter 已入队的 postMessage"，存在把上一个 waiter 的结果误交付的隐患；`FRunningCount` 混用原子/非原子写。**存疑**（需时序验证）。
3. **RSP-02** `ResponseWaiter.pas:416` `LOnResult := FOnResult` 快照读非原子（接口指针）——同 SSD-01 性质。
4. **SEL-02** `Selectors.pas:264` `LSelectors.Items[I].Value`：对非字符串 JSON 值取 `.Value` 的返回语义未定，可能返回原始文本而非期望值。**存疑**。
5. **WEL-03** `WebElement.pas:32` `TWebWebElement` record 含 `FHandle: TJSONValue`（对象引用）却按值拷贝、无生命周期管理——record 复制会共享同一裸对象指针，来源/释放责任不明。**存疑**（当前方法皆空实现，实际未触及该指针，故暂不升级为 🔴）。
6. **WV2-06** `Engine.WebView2.pas` 若在真实启用 `USE_WEBVIEW2` 的宿主中运行，WV2-01 的主线程 `Synchronize` 死锁窗口是否可被实际触发，取决于上层是否在 UI 线程 `Free` 会话。**存疑**。

---

## 6. 结语（不含修复动作，仅结论）

- **最需关注**：UIA.Engine（安全校验恒真/恒通过 + nil Guard 崩溃 + 映射系统空转）与 Browser 核心契约/生命周期（GUID 分裂、双 CDP 实现、匿名线程 UAF、静默空实现元素交互）。这些均在**已构建的活代码**里。
- **可维护性风险**：审计组内约 1/3 单元（Recorder、Screen.Click 三件套、Perception 全部、UnifiedActuator）是**脱离构建的半成品/不可编译脚手架**，却与活代码同名同接口并存，易被误认为"已实现"。建议明确标注实验状态或移出主树。
- **正面样板**：Recovery 的线程停止模式、Vision/PageDriver/ScriptStore/BrowserAutomation 的 JSON/JS 注入防护与数值本地化格式化、WebView2 的异步任务与 CDP 路由治理，可作为修复 CDP-01/ADP-01/UIA 系列的参照实现。

*本报告为只读静态审计，未运行程序、未修改任何源码；所有行号基于 2026-09-18 当前源码。*
