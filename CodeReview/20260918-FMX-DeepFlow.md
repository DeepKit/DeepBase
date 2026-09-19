# DeepBase FMX + DeepFlow 层深度代码审计报告

- **报告编号**：20260918-FMX-DeepFlow
- **审计日期**：2026-09-18（系统时间基准 2026-09-19）
- **审计人**：资深 Object Pascal / Delphi FMX 架构审查（AI 辅助，只读）
- **审计对象**：DeepBase 库（`d:\_Progs\02Business\DeepBase`）

## 范围

| 层 | 目录 | .pas 文件数（已 Glob 核对，排除 `__history`） |
|---|---|---|
| FMX | `d:\_Progs\02Business\DeepBase\FMX\` | 43 |
| DeepFlow | `d:\_Progs\02Business\DeepBase\DeepFlow\Source\...`、`DeepFlow\Tests\...` | 12 |

> 说明：FMX `.pas` 实为 43 个（含 `AutoFix.FmxHook`、`LogListView`、`LLMChatFrame` 等）；DeepFlow 12 个（含 1 个 `Tests\Test.DeepFlow.Engine.pas`）。`.fmx` 窗体文件流描述不在代码审计范围。

## 方法

1. **模式扫描**（ripgrep）：线程原语（`TThread.Queue/Synchronize/ForceQueue/CreateAnonymousThread`、`TTask`、`ProcessMessages`）、异常吞噬（`except`）、Owner 错配（`Create(nil)`、`TForm.CreateNew`、`ShowModal`、`.Free`）、Timer/动画、`RepeatInvalid`/全量重绘、安全面（`ShellExecute`、`TFile.ReadAllText`、HTML/WebBrowser）。
2. **精读**：对全部含线程/生命周期/算法风险的大文件与热点逐行核对（FormControls 1150、HB.Controls 1617、HB.Choice 1220、LLMConfigPanel 745、Platform 965、ListView 689、Chronicler 667、Engine 997、Workflow.Context 783、Workflow.Definition 816 等）。
3. **交叉验证**：对"疑似 bug"逐一判定是否实害（如 TTimer owner+手动 Free 是否双 Free、可重入锁是否死锁、FillChar 用于托管记录是否触发），避免误报。

---

## 总体统计

| 严重度 | 数量 | 说明 |
|---|---|---|
| 🔴 崩溃/数据损坏 | 10 | use-after-free、跨线程改 UI、死锁、类型混淆、异常风暴 |
| 🟡 功能缺陷 | 17 | 资源泄漏、逻辑错误、性能与描述不符、防护可绕过 |
| 🔵 优化建议 | 8 | 反模式、热路径分配、脆弱写法、所有权 footgun |
| 存疑区 | 4 | 依赖跨模块实现或运行期条件，需确认（Q-02 已核实） |
| **合计** | **40** | |

按维度分布（一条发现可归多维）：①正确性 9 · ②内存/生命周期 8 · ③线程安全 9 · ④异常处理 4 · ⑤安全 3 · ⑥性能 4 · ⑦架构 3。

---

## FMX 层发现（按单元）

### 1. `DeepBase.FMX.LLMChatFrame.pas`（639 行）

#### 🔴 F-01 析构器主线程 `Wait` + 排队 `Synchronize` → 死锁 / use-after-free
- **路径:行号**：`d:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.LLMChatFrame.pas:196-203`（配合 `497`、`537`）
- **代码**：
  ```pascal
  if FIsGenerating then
  begin
    FClient.Cancel;
    if Assigned(FCurrentTask) then
      FCurrentTask.Wait(2000);   // 主线程阻塞
  end;
  ...
  FreeAndNil(FHistory); FreeAndNil(FChatItems); // 2s 后无条件释放
  ```
  worker 内部（L497/L537）：`TThread.Synchronize(nil, procedure begin ... FMemoChat... end)`。
- **问题**：析构在 UI 主线程执行 `FCurrentTask.Wait`，而 worker 完成/取消路径通过 `TThread.Synchronize` 回到主线程更新 `FMemoChat`。若 worker 已进入 Synchronize 等待主线程、主线程又在 `Wait` → **相互等待**；即便 2s 超时跳出，随后 `FreeAndNil` 释放历史/条目对象，而 Synchronize 已排队的过程稍后仍会在主线程执行并访问已释放的 `FMemoChat`/`FChatItems` → **use-after-free**。
- **触发条件**：生成回复过程中关闭/释放含该 Frame 的窗体（用户中途关窗、切页触发 Free）。
- **建议修复**：不要在主线程 `Wait` worker。改为：置 `FCancelled/FSdestroying` 标志 → `Cancel` → 让 worker 的 Synchronize 回调首行检测该标志并 `Exit`；用引用计数/事件在**非阻塞**前提下延迟 `FreeAndNil`（如在最后一个 Synchronize 回调末尾自行释放），或让 Frame 不拥有 worker（worker 捕获接口的弱引用）。

#### 🟡 F-02 传给后台任务的 `LMessages` 可能为内部列表引用（竞态，见存疑 Q-01）
- **路径:行号**：`...LLMChatFrame.pas:478-479`、`481`
- **代码**：`var LMessages := FHistory.GetMessages; ... FCurrentTask := TTask.Run(...)`
- **问题**：主线程"快照"后交给 worker；若 `GetMessages` 返回内部 `TList` 引用而非深拷贝，则 worker 遍历期间主线程 `AddUserMessage` 改动同一列表 → 竞态/越界。
- **建议**：确认 `TChatHistory.GetMessages` 语义；若非拷贝，在提交前显式拷贝一份只读快照。

#### 🔵 F-03 依赖手工空行结构计算 content 行索引
- **路径:行号**：`...LLMChatFrame.pas:502`、`521`、`540`
- `FMemoChat.Lines.Count - 2` 依赖前置 `Add` 的空行约定，结构一变即错位。建议改为记录行锚点。

---

### 2. `DeepBase.FMX.UpdateDialog.pas`（388 行）

#### 🔴 F-04 对话框把自己方法指针注册进后台 AutoUpdater，关闭时不反注册 → 悬垂 Self
- **路径:行号**：`d:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.UpdateDialog.pas:283`、`286`（配合 `106`、`163-166`）
- **代码**：
  ```pascal
  AutoUpdater.OnProgress  := HandleAutoUpdaterProgress;
  AutoUpdater.OnComplete  := HandleAutoUpdaterComplete;
  ```
- **问题**：`AutoUpdater` 生命周期长于对话框；其 `OnProgress/OnComplete` 持有本 dialog 的方法指针（含 Self）。对话框 `Close`（caFree）释放后，后台下载仍在跑并回调 → 访问已释放 dialog → **崩溃**。回调结束/释放前均未反注册。
- **触发条件**：更新下载过程中用户关闭更新对话框。
- **建议**：dialog `OnDestroy`/`BeforeDestruction` 中把 `AutoUpdater.OnProgress/OnComplete := nil`；或由一个生命周期≥下载过程的宿主对象接收回调再转发给 dialog（dialog 存活期用弱引用/wrapper）。

#### 🟡 F-05 强制更新对话框 `Create(nil)` + `caNone` → 永不释放（泄漏）
- **路径:行号**：`...UpdateDialog.pas:106`、`163-166`
- `Dialog := TFMXUpdateDialog.Create(nil)`（无 Owner），强制更新时 `FormClose` 返回 `caNone` 阻止关闭 → 无任何释放路径，实例常驻。建议由 Owner 托管或提供确定释放路径（下载结束后显式 Free）。

---

### 3. `DeepBase.FMX.AutoUpdater.pas`（435 行）

#### 🔴 F-06 全局单例回调闭包捕获 Self，析构未清除 → use-after-free
- **路径:行号**：`d:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.AutoUpdater.pas:276-280`、`182-185`
- **代码**：
  ```pascal
  Updater := TFMXAutoUpdater.Create(nil);   // 全局单例
  Updater.OnProgress := procedure(const Progress: TUpdateProgress)
    begin HandleProgress(Progress); end;    // 闭包捕获 Self
  ...
  destructor ...  // 未 Updater.OnProgress := nil
  ```
- **问题**：单例 `Updater.OnProgress` 闭包强引用外层对象 Self；外层释放后单例仍存活并回调 → 访问悬垂 Self。
- **建议**：析构中 `Updater.OnProgress := nil; Updater.OnComplete := nil;` 或让回调持有 weak/接口引用。

#### 🔴 F-07 `TThread.Queue(nil, ...)` 裸捕获 Self → 悬垂
- **路径:行号**：`...AutoUpdater.pas:327-335`、`355-360`、`376-381`
- **代码**：`TThread.Queue(nil, procedure begin FOnProgress(Self, Progress) end);`
- **问题**：队列过程执行前若本对象已释放，`Self` 悬垂（典型"线程安全裸指针捕获"）。
- **建议**：Queue 前先判存活并用弱引用/接口捕获；或改由不被释放的调度器转发。

#### 🟡 F-08 析构未 Cancel 进行中的检查/下载
- 后台线程可能仍在访问 `FHttpClient`/状态字段。建议 `Destroy` 置停止标志并等待有界退出。

---

### 4. `DeepBase.FMX.FormControls.pas`（1150 行）

#### 🔴 F-09 异步校验在后台线程修改 FMX 控件 + 线程不被跟踪
- **路径:行号**：`d:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.FormControls.pas:853-868`
- **代码**：
  ```pascal
  TThread.CreateAnonymousThread(
    procedure
    var IsValid: Boolean;
    begin
      IsValid := ValidateAll;                 // 内部 DoValidate → 改 UI
      TThread.Synchronize(nil, TThreadProcedure(...));
    end).Start;                               // 线程不被跟踪
  ```
- **问题**：`ValidateAll → Control.Validate → DoValidate` 会设置 `FHelperLabel.Text`、`UpdateState` 等**直接改 FMX 控件**（FMX 控件非线程亲和=主线程独占），且匿名线程不被 owner 跟踪、闭包捕获 `Self(validator)`，validator 可能先被释放 → 跨线程 UI 访问崩溃 + 悬垂。
- **触发条件**：调用 `ValidateAllAsync` 且校验涉及可见控件状态更新，或校验期间窗体关闭。
- **建议**：后台仅计算纯数据结果，所有控件读写回到主线程（构造期在主线程预抓取文本/值），并跟踪线程生命周期；或去掉"异步"（本地校验本就应主线程）。

#### 🟡 F-10 `TUniFormValidator` 用裸 `TList<TUniMaterialEdit>` 持控件引用
- 控件释放无通知，`FControls` 内指针悬垂，`ValidateAll` 遍历即崩。建议控件注销（订阅控件 Destroy）或弱引用容器。

---

### 5. `DeepBase.FMX.HB.Controls.pas`（1617 行，向量控件基类）

#### 🔴 F-11 Paint 吞异常即永久 Dispose，后续 Paint 抛异常向 FMX 传播
- **路径:行号**：`d:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.Controls.pas:562-591`（配合 `480`）
- **代码**：
  ```pascal
  FLife.AssertPaintAllowed;           // L567 在 try 之外
  try
    DrawHbControl(...); Render(...); EmitTelemetry(...);
  except
    HandleLifecycleError(...);        // 不 re-raise，吞异常
  end;
  // HandleLifecycleError 路径最终 DoDispose（L480）
  ```
- **问题**：任一瞬时绘制异常 → 控件被永久 `Dispose`；此后每次 Paint 走到 try 外的 `AssertPaintAllowed` 抛异常并向 FMX 传播 → **异常风暴/死控件甚至崩溃**。
- **触发条件**：某帧绘制/遥测抛瞬时异常（字体/画布状态异常、主题令牌缺失等）。
- **建议**：区分"可恢复瞬时异常"（记录并跳过本帧，不 Dispose）与"致命生命周期错误"（才 Dispose）；`AssertPaintAllowed` 移入受控保护并给出安全降级（不绘制而非抛给框架）。

#### 🟡 F-12 `EmitTelemetry` 每次 Paint 调用 + 高频定时器全量 Repaint
- **路径:行号**：`...HB.Controls.pas:575`；定时器见 `1288`(ProgressRing)、`1392`(Skeleton)、`1485`(StreamBlock)
- ProgressRing≈25ms / Skeleton≈30ms / StreamBlock≈60ms 常开 `Repaint`，每帧触发遥测（字符串拼接 + 引擎调用）。属热路径性能问题（维度⑥）。建议遥测降频/聚合，非可见时停表。

#### 🔵 F-13 TTimer `Create(Self)` 后又手动 `FTimer.Free`（owner+手动混用）
- **路径:行号**：`...HB.Controls.pas:1294-1298`、`1398-1402`、`1491-1495`
- 非双 Free（显式 Free 会从 owner 链表移除），但属冗余反模式。建议仅依赖 owner 释放。

#### 🔵 F-14 对含 string 字段的托管记录使用 `FillChar`
- **路径:行号**：`...HB.Controls.pas:669`（`FillChar(Ev, SizeOf(Ev), 0)`，`TTouchEvidence` 含 string）
- 此处 `Ev` 为新建局部变量（托管字段本为 nil）暂无实害，但属反模式，且与 L652 分支不一致。建议用 `Ev := Default(TTouchEvidence)`。

#### 🔵 F-15 `THbProgressRing.DrawHbControl` 每帧 `TPathData.Create/Free`
- **路径:行号**：`...HB.Controls.pas:1368-1376`
- 每帧分配/释放路径对象。建议缓存复用。

---

### 6. `DeepBase.FMX.HB.VirtualList.pas`（260 行）

#### 🟡 F-16 名为"Virtual"实无滚动：仅可显示顶部若干行
- **路径:行号**：`d:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.VirtualList.pas:224-257`（命中测试 `200-208`）
- `DrawHbControl` 从固定 `top+10`、行高 64px 顺序画到底即 `Break`，无滚动条/偏移 → 超过约 8 行的数据不可达（维度①功能缺陷）。MouseDown 用同一固定原点，自洽但无翻页。
- **建议**：引入 `ScrollDelta`/`ScrollBar`，绘制与命中测试均加滚动偏移。

#### 🟡 F-17 `AddItem` 每次 `RebuildFilteredIndices` 全量 O(N) → 批量 O(N²)
- **路径:行号**：`...HB.VirtualList.pas:145`
- 建议增量维护索引。

#### 🔵 F-18 绘制循环内 `FSelectedIndices.Contains` O(K) → O(N·K)
- 建议用哈希集合或位图。

---

### 7. `DeepBase.FMX.HB.Terminal.pas`（601 行）

#### 🟡 F-19 Toast 自动隐藏后滞留 `FActiveToasts`，累积至下次 ShowToast 才回收
- **路径:行号**：`d:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.Terminal.pas:566-599`（OnTimerTick 仅置 `Visible:=False`）
- `THbToast` 不自我释放；隐藏后仍留在活动列表，直到下一次 `ShowToast→RepositionToasts` 才清理 → 无后续 toast 时内存持续增长。
- **建议**：toast 隐藏定时器回调里主动从 `FActiveToasts` 移除并释放（或延迟 Free）。

#### 🟡 F-20 `THbToastHost.FHostControl` 裸引用 TFmxObject 无失效通知
- 宿主先于 host 释放 → `RepositionToasts/ShowToast` 访问悬垂。建议订阅宿主销毁或置空。

---

### 8. `DeepBase.FMX.LogListView.pas`（382 行）

#### 🟡 F-21 头注释"virtual scrolling / 10000+"与实现不符：每 2 秒全量重建控件
- **路径:行号**：`d:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.LogListView.pas:246-309`（定时器 `206-210`）
- `PopulateListBox` 每次 `Clear` 后为每条日志新建 `TListBoxItem + 4×TLabel`（FMaxItems=1000 → ~4000 控件），`FRefreshTimer` 每 2s 触发一次全量重建 → 明显卡顿，与"虚拟化"宣称相悖（维度⑥+误导性注释）。
- **建议**：改用 FMX 虚拟列表（自绘，如 HB.VirtualList）或增量 append，仅重绘可视区。

#### 🟡 F-22 release 下 `RefreshLogs` 静默吞异常
- **路径:行号**：`...LogListView.pas:236-243`（维度④）。建议至少记录一次首异常。

---

### 9. `DeepBase.FMX.WaitForm.pas`（413 行）

#### 🟡 F-23 多处 `Application.ProcessMessages` → 消息泵重入
- **路径:行号**：`d:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.WaitForm.pas:268`、`285`、`354`、`404`、`410`
- 与 NotificationBar 已修复的 FMX-001 同类隐患，本文件仍保留 `ProcessMessages`，在等待循环中泵消息可导致重入（用户在等待期点其它控件/再次触发）。
- **建议**：以 `TThread.Queue`/动画帧驱动刷新替代 ProcessMessages（参考 FMX-001）。

---

### 10. `DeepBase.FMX.HotkeyEditor.pas`（716 行）

#### 🟡 F-24 导出/导入在 try…except 之外 Free 对话框，`Exit` 跳过 → 取消时泄漏
- **路径:行号**：`d:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HotkeyEditor.pas:653-668`、`680-714`
- **代码**：
  ```pascal
  SaveDialog := TSaveDialog.Create(nil);   // 无 Owner
  try
    ...
    if not SaveDialog.Execute then Exit;   // Exit 跳过下方 Free
    ...
  except ... end;
  SaveDialog.Free;                          // ← 不在 finally 内
  ```
- **问题**：用户取消（`Execute` 返回 False → `Exit`）或冲突选择 `mrCancel` → `Exit` 直接跳出过程，`SaveDialog/OpenDialog.Free`（在 try 块之后、非 finally）被跳过 → 对话框泄漏（无 Owner 不会自动回收）。
- **建议**：把 `.Free` 放进 `finally`，或 `try..finally` 包裹整个使用段。

---

### 11. `DeepBase.FMX.Platform.pas`（965 行）

#### 🟡 F-25 `OpenURL` Windows 分支未校验 scheme 即 ShellExecute 'open'
- **路径:行号**：`d:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.Platform.pas:555-560`
- **代码**：`Result := ShellExecute(0,'open', PChar(URL), nil, nil, SW_SHOWNORMAL) > 32;`
- **问题**：若 `URL` 源自不可信内容（LLM 输出、导入的工作流/热键 JSON），`file:`、UNC 或裸可执行路径会被 `open` 直接启动 → 任意程序执行面（维度⑤）。
- **建议**：白名单校验协议（仅 `http/https/mailto/deepbase:`），拒绝其它 scheme；对 host 做二次校验。
- 备注：Android/iOS 分支的 `except → Result:=False`（L569/578）为布尔返回启动器的合理降级，不计吞异常缺陷。

---

### 12. `DeepBase.FMX.HB.Dialogs.pas` / `HB.Voice.pas`（弹窗）

#### 🔵 F-26 `TForm.CreateNew(nil)` + `ShowModal` 后立即 `DlgForm.Free`
- **路径:行号**：`d:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.Dialogs.pas:352-492`；`...HB.Voice.pas:388-477`
- **问题**：FMX 中 `ShowModal` 返回后立刻 `Free` 模态窗，在部分平台（模态栈仍可能引用该 Form，尤其移动/异步 modal 路径）是已知脆弱点；桌面 Win64 通常可用。归属"存疑/平台相关"（见 Q-04）。
- **建议**：用 `OnCloseQuery`+`caFree` 交由框架释放，或 `TThread.ForceQueue` 延迟 Free，避免在 modal 返回同帧 Free。

---

### 13. `DeepBase.FMX.NotificationBar.pas`（445 行）
- **未发现问题**。Timer/动画生命周期正确（spinner 动画 owner=子控件，析构 `Stop` 动画并关 timer；FMX-001 注释表明已移除 ProcessMessages）。

### 14. `DeepBase.FMX.I18nControls.pas`（525 行）
#### 🔵 F-27 控件在 `Loaded` 时若 I18n 未初始化则永不订阅语言变更
- **路径:行号**：`d:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.I18nControls.pas:167-207`
- `SubscribeToLanguageChange` 在 `IsInitialized=False` 时静默跳过，且无后续补订时机 → 早于 I18n 初始化的控件切换语言时不更新。订阅/退订成对（Destroy 中退订，无泄漏），仅初始化时序缺口。
- **建议**：I18n 初始化时广播"就绪"消息，控件收到后补订阅；或在 `UpdateTranslation` 前惰性重订阅。

### 15. 其余 FMX 单元（模式扫描，未发现重大问题）
`AboutFrame`、`ConfigControls`、`ConfigEdit`、`Controls`、`DesktopLifecycle`、`Dialogs`、`FormStateHelper`、`HB.AI`、`HB.Cards`、`HB.Choice`、`HB.CommandPalette`、`HB.Dock`、`HB.Gate`、`HB.Grid`、`HB.NavTree`、`HB.PageControl`、`HB.Palettes`、`HB.ShareCard`、`HB.Theme`、`HB.Tray`、`HB.Waterfall`、`Hotkeys`、`LLMConfigPanel`、`LicenseStatusPanel`、`ListView`、`MRUControls`、`Theme`、`AutoFix.FmxHook`：
- 无跨线程 UI 访问（线程原语仅出现在 F-01~F-09 涉及的文件）；无空 `except`；`Create(nil)` 对象均有配对的显式 `Free`（HotkeyEditor 除外，见 F-24）。
- 其中 `HB.Waterfall` 补充两条：

#### 🟡 F-28 `THbFmxFacetWaterfall` 是 `TControl` 但无任何绘制实现
- **路径:行号**：`d:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.Waterfall.pas:27-51`
- 类继承 `TControl` 并 `published Align`，却无 `Paint`/`DrawHbControl`/子控件装配 → 放置到窗体上不会渲染任何内容（功能未完成/占位）。建议实现绘制或明确标注为数据容器（改基类或加注释）。

#### 🔵 F-29 `GetVisibleCardCount` O(N·M)
- **路径:行号**：`...HB.Waterfall.pas:174-184`（内层 `IsCategoryVisible` O(M)）。可缓存可见类别集合。

---

## DeepFlow 层发现（按单元）

### 16. `DeepFlow.Engine.pas`（997 行）

#### 🔴 F-30 `Stop`/`Destroy` 对 worker 线程无限 `WaitFor` → 挂死
- **路径:行号**：`d:\_Progs\02Business\DeepBase\DeepFlow\Source\Core\DeepFlow.Engine.pas:365-414`（`398`；兜底 `288-294`）
- worker 正阻塞在角色 `HandleMessage`（如 `TExecutor.CallSkillService` 的 `FHttpClient.Post`，ResponseTimeout 默认 30s）时，`FreeAndNil(FWorkerThread)` 内部 `WaitFor` 无有界超时 → `Stop` 卡住。已有 5000+2000ms 逻辑超时但最终以阻塞式 `Free` 收场。
- **建议**：`FStopFlag`+`SetEvent` 后用 `WaitFor(timeout)` 有界等待，超时不强杀（记录），或将角色调用改为可中断（HTTP 主动 Cancel）。

#### 🟡 F-31 全局单例 `Engine()` 懒加载非线程安全
- **路径:行号**：`...Engine.pas:183-188`
- 双线程首次并发调用 `Engine()` → 可能双建实例/泄漏其一。`Config` 中 `GlobalConfig()` 同构问题。建议 `TInterlocked` 双检锁或初始化单元内构造。

#### 🔵 F-32 `Uptime`：未启动时 `FStartTime=0` 致巨大值
- **路径:行号**：`...Engine.pas:622`。GetMetrics 应在非 Running 时返回 0。
- 备注：SendSync per-call waiter（L554-611）与 `ProcessMessage` 按 `CorrelationId` 路由（L815-840）+ `ExtractPair` 所有权处理，经核**无泄漏/无悬垂**，GOV-R3-006/D-006 修复正确。MessageLoop 顶层 except（L782-787）置 `esError` 且有 `Reset` 恢复路径，属可接受的显式降级。

### 17. `DeepFlow.Workflow.Context.pas`（783 行）

#### 🔴 F-33 `GetVariable` 锁外返回被字典拥有的对象裸引用 → use-after-free
- **路径:行号**：`d:\_Progs\02Business\DeepBase\DeepFlow\Source\Workflow\DeepFlow.Workflow.Context.pas:416-424`
- **代码**：`Result := FVariables[...]`（`FVariables` = `TObjectDictionary(doOwnsValues)`），`FLock.Leave` 后调用方在锁外使用该对象。
- **问题**：类名注释宣称"线程安全、可用于并行步骤"；但取回的 `TVariableValue` 由字典拥有，另一线程 `DeleteVariable`/PopScope 释放它时，持引用者 → **悬垂**（维度③）。
- **建议**：返回值的读取（AsString/AsJSON）应在锁内完成并返回**值拷贝**；或引入引用计数/在并行执行期禁止删除变量。

#### 🟡 F-34 `TExpressionEvaluator.Compare` 对 Variant 直接比较，类型不符抛异常且未捕获
- **路径:行号**：`...Workflow.Context.pas:703-757`
- 字符串与数字比较触发 `EVariantOpError`；`EvaluateCondition` 未捕获 → 传播到 worker → 引擎进入 `esError`（维度①）。建议按 VarType 归一（尝试数值/字符串强转）或 try 捕获后返回 False。
- 备注：可重入 `TCriticalSection` 使嵌套加锁不死锁、`EvaluateCondition` 递归前释放锁、`MAX_CONDITION_DEPTH=100` 深度保护、`FromJSON` 用 `AddOrSetValue` 转移所有权 —— 均正确。

### 18. `DeepFlow.Workflow.Definition.pas`（816 行）

#### 🟡 F-35 `FromFile` 无差别读取任意路径反序列化，含 `atScript`/`atHttp`（导入攻击面）
- **路径:行号**：`...Workflow.Definition.pas:808-814`（动作类型枚举 L44-52）
- 工作流定义可携带脚本/HTTP 动作；导入不受信 JSON 即可能在执行期触发脚本/外联（维度⑤）。
- **现状缓解（重要）**：全库检索显示 `TWorkflowExecutor` 仅出现在 README，**尚无实际解释器执行 `atScript`/`atHttp`**，故当前为"潜在攻击面"而非"现网可利用"。见存疑 Q-03。
- **建议**：反序列化时对 `atScript`/`atHttp` 做来源可信校验/沙箱开关；实现执行器时默认禁用脚本动作并要求显式授权。

#### 🟡 F-36 `Validate` 不检测环 → 流程图连线算法缺环检测
- **路径:行号**：`...Workflow.Definition.pas:638-667`
- 仅校验 `next/onError` 目标存在，不做 DFS/入度环检测 → `stLoop`/next 指回可致无限跳转（维度①）。建议加拓扑/环检测。

#### 🟡 F-37 `TBranchDefinition` 为 record，其 `Condition` 对象永不释放 → 确定泄漏
- **路径:行号**：声明 `...Workflow.Definition.pas:140-143`、`154`（`FBranches: TList<TBranchDefinition>`，非 TObjectList）；析构 `475-484`（已确认）
- `TList<T>` 存放 record，`doOwnsValues` 语义不适用；`TWorkflowStep.Destroy` 仅 `FBranches.Free` 释放容器本身，**未遍历释放各 record 内的 `Condition: TConditionExpression`**（对比 `FCondition.Free`/`FLoopCondition.Free` 均被释放）。反序列化（L566 区）为每个 branch 新建 Condition → 步骤释放时全部悬空泄漏。
- **建议**：`Destroy` 中 `for B in FBranches do B.Condition.Free;`，或将 FBranches 改为持有小对象类（`TObjectList<TBranch>`）以自动接管。

#### 🔵 F-38 `TVariableType(StrToIntDef(TypeStr,0))` 以序号整数持久化类型
- **路径:行号**：`...Workflow.Definition.pas:760`。枚举增删导致跨版本序号漂移。建议字符串名序列化。

### 19. `DeepFlow.Skill.Client.pas`（209 行）

#### 🟡 F-39 `THTTPClient` 单实例被多线程共享（若并发调用）
- **路径:行号**：`d:\_Progs\02Business\DeepBase\DeepFlow\Source\AI\DeepFlow.Skill.Client.pas:78-138`
- `TSkillClient` 持一个 `FHttpClient`，`ExecuteWithRetry` 每次调用还改 `ConnectionTimeout/ResponseTimeout`（L124-125）。若同一 client 实例跨线程并发使用 `THTTPClient`（非线程安全）→ 竞态。
- **建议**：明确 client 为线程独占；若共享则每调用新建或用锁串行化超时刻设置。
- 备注：BUG-439 的"except 块克隆异常对象再抛出"处理正确，规避了跨 except 块持有 RTL 自动释放 `E` 的悬垂；重试退避与所有权移交逻辑无缺陷。

### 20. `DeepFlow.Executor.pas`（382 行）
#### 🔵 F-40 复用单一 `FHttpClient` 且 `Payload` 公共非拥有写访问器
- **路径:行号**：`...Executor.pas:92`（同 F-39 的 HTTP 线程亲和隐患）；`DoHandleMessage` L343-345/366-368 `Payload.Free; Payload := ExecResult` 依赖 `TDeepFlowMessage.Payload` 的 `write FPayload`（普通写、不自动释放旧值）——当前所有调用方都先 `Free` 再赋值故正确，但该 public 写访问器是所有权 footgun（外部若直接赋值不先 Free 即泄漏）。见 Message 单元 F-42。JSON 解析/克隆/Free 配对经核无泄漏。

### 21. `DeepFlow.Role.pas`（315 行）

#### 🔴 F-41 角色接口 GUID 重复 → 接口类型混淆
- **路径:行号**：`d:\_Progs\02Business\DeepBase\DeepFlow\Source\Core\DeepFlow.Role.pas:128-134`、`190-196`、`136-142`、`198-204`
- `IEngine` 与 `ILogistics` 同为 `{...0010}`；`IInspector` 与 `IChronicler` 同为 `{...0011}`。
- **问题**：Delphi 用 GUID 区分接口类型（`Supports()`、`as`、`QueryInterface` 在跨模块/COM 风格解析时）。重复 GUID 使 `Supports(X, ILogistics)` 可能命中 `IEngine` 实现 → **错误接口被识别/返回**，运行期类型混淆（维度①）。
- **建议**：为 `ILogistics`/`IChronicler` 分配唯一 GUID（`Ctrl+Shift+G` 重生成）。

### 22. `DeepFlow.Message.pas`（255 行）

#### 🔵 F-42 `Payload: TJSONObject read FPayload write FPayload` 非拥有写 + Clone 漏字段
- **路径:行号**：`d:\_Progs\02Business\DeepBase\DeepFlow\Source\Core\DeepFlow.Message.pas:76`、`211-225`
- 公开写访问器不接管旧值，误用即泄漏（多处调用方靠"先 Free 再赋值"约定，脆弱）。`Clone` 未复制 `FStatus/FRetryCount`（`FMsgId` 有意重生成）。建议提供 `SetPayload`（内部 Free 旧值）并在 Clone 中补齐字段。
- `FromJSON`/`ToJSON` 的 payload 克隆、`TResponseMessage.Create` 关联字段设置经核无泄漏。

### 23. `DeepFlow.Commander.pas`（445 行）

#### 🟡 F-43 `ProcessRequest` 在 `FSessionLock` 之外获取并长期持有 `Session` 裸指针
- **路径:行号**：`d:\_Progs\02Business\DeepBase\DeepFlow\Source\Roles\DeepFlow.Commander.pas:349-363`（`FSessions` 为 `doOwnsValues`，`DoStop` L162-167 会 `Clear`）
- `Session := GetOrCreateSession`（L349，锁内取回后立即出锁）；随后再进锁修改 `Session.State`（L355-357）。若此间隙另一线程 `Stop→FSessions.Clear` 释放该 `TSession`，则对 `Session` 的字段写入为 **use-after-free**。锁只保护字段读写，不保证对象存活期。
- **建议**：整个会话使用段持锁，或 `GetOrCreateSession` 返回引用计数/接口；`Clear` 与处理路径需共享同一"存活保证"。
- 备注：`CreateSession` 在 `GetOrCreateSession` 持锁时被再次 `TMonitor.Enter`（L173）——TMonitor 可重入，非死锁。

### 24. `DeepFlow.Guard.pas`（486 行）

#### 🟡 F-44 必填字段检查误用 `GetValue(FieldName, False)` 语义
- **路径:行号**：`d:\_Progs\02Business\DeepBase\DeepFlow\Source\Roles\DeepFlow.Guard.pas:314-317`
- `AInput.GetValue(FieldName, False)` 走的是"取布尔字段值，缺省 False"重载，返回字段的**布尔真值**而非"字段是否存在"。若必填字段是字符串/对象，判定结果错误（漏报/误报缺失）。建议改用 `ContainsField`/`TryGetValue`。

#### 🟡 F-45 Guard 非引擎自动调用，未显式编排则全部安全校验被绕过（DATA2-044）
- **路径:行号**：`...Guard.pas:49-56`（类注释自述）
- 门卫/监工/审核官三层防护只在"工作流显式包含 Guard 步骤"时生效；这是可被静默跳过的安全设计缺陷（维度⑤/⑦）。注释已标为已知演进项，但风险真实存在。
- **建议**：引擎侧提供系统级强制拦截点（路由前后自动过 Guard），与业务编排解耦。

#### 🔵 F-46 静态 `TRegEx.IsMatch/Replace` 每次重编译
- **路径:行号**：`...Guard.pas:211-219`、`356`。热路径反复编译正则。建议预编译为字段常量复用（`FBlockedPatterns`/`FSensitivePatterns` 已预编译，Sanitize 系列未复用）。
- 备注：`Warnings`（TJSONArray）在每条 `Exit`/正常路径均 `AddPair('warnings', Warnings)` 恰好一次，经核无泄漏/双释放。

### 25. `DeepFlow.Config.pas`（273 行）

#### 🟡 F-47 `GlobalConfig()` 懒加载单例非线程安全
- **路径:行号**：`d:\_Progs\02Business\DeepBase\DeepFlow\Source\Core\DeepFlow.Config.pas:104-109`
- 与 F-31 同构：双线程首访可能双建/泄漏。finalization `FreeAndNil` 正确。
- `LoadFromFile`（L166-215）对非对象 JSON 返回 nil → `Free` 安全处理；但 `TFile.ReadAllText` 无 try 包裹，IO/权限异常会从构造函数抛出（次要）。

### 26. `Test.DeepFlow.Engine.pas`（148 行）
- 测试单元，未发现影响生产正确性的问题；不作为缺陷计数。

---

## 维度覆盖小结

| 维度 | 结论 | 代表发现 |
|---|---|---|
| ① 正确性（生命周期/坐标/动画/流程图算法） | 有 | F-11、F-16、F-28、F-34、F-36、F-41、F-44 |
| ② 内存与生命周期（Owner/悬垂/Timer/双 Free） | 有 | F-01、F-04~F-07、F-10、F-19、F-24、F-33 |
| ③ 线程安全（跨线程改 UI/裸指针捕获） | 有 | F-01、F-09、F-33、F-39、F-43、F-30、F-31/F-47 |
| ④ 异常处理（吞异常） | 有 | F-11、F-22、F-34 |
| ⑤ 安全（文件导入/渲染/外联注入） | 有 | F-25、F-35、F-45 |
| ⑥ 性能（全量重绘/O(N²)/循环失效） | 有 | F-12、F-17、F-21、F-29、F-46 |
| ⑦ 架构（双栈重复/业务混入 UI/依赖方向/超大文件） | 有（有限） | F-45（安全职责缺系统级落点）；见下方"架构维度说明" |

### 架构维度说明（⑦）
- **FMX/VCL 双栈重复**：本次范围仅 `FMX\`、`DeepFlow\`，`VCL\` 层不在范围，无法在范围内逐控件比对；从命名看 FMX 侧多为独立实现（THb*、TUni*、TFMX*），未见明显跨栈 `uses`。**未发现范围内证据支持的重复实现缺陷**（跨栈比对留待 VCL 层审计）。
- **业务逻辑混入 UI**：`LLMChatFrame` 直接在 Frame 内组织 `TChatHistory`、发 HTTP/SSE、导出文件（L478-636），属 UI 层承载会话/网络业务，建议下沉到服务层。计 🔵 级观察，不单列为数。
- **DeepFlow 与 Core 依赖方向**：DeepFlow units `uses DeepBase.Exceptions`（Core）为正向依赖，未发现 Core 反向依赖 DeepFlow 或 FMX 依赖 DeepFlow 角色的倒挂。**未发现依赖倒置问题**。
- **超大文件**：`HB.Controls.pas`（1617）、`HB.Choice.pas`（1220）、`FormControls.pas`（1150）、`Platform.pas`（965）、`Engine.pas`（997）均逼近或超千行，`HB.Controls`/`Engine` 承担多职责。建议按控件/角色拆分。计 🔵 级观察。

---

## 🔴 Top 10（最严重）

| # | 编号 | 位置 | 一句话 |
|---|---|---|---|
| 1 | F-01 | `FMX\DeepBase.FMX.LLMChatFrame.pas:196-203` | 析构主线程 `Wait` + worker `Synchronize` → 死锁 / 释放后回调 use-after-free |
| 2 | F-09 | `FMX\DeepBase.FMX.FormControls.pas:853-868` | `ValidateAllAsync` 后台线程直接改 FMX 控件，线程不跟踪且悬垂 Self |
| 3 | F-04 | `FMX\DeepBase.FMX.UpdateDialog.pas:283/286` | dialog 方法注册进长生命周期 AutoUpdater，关闭不反注册 → 悬垂 Self 崩溃 |
| 4 | F-06/F-07 | `FMX\DeepBase.FMX.AutoUpdater.pas:276-280/327-381` | 单例闭包与 `TThread.Queue` 裸捕获 Self，析构未清 → use-after-free |
| 5 | F-33 | `DeepFlow\Source\Workflow\DeepFlow.Workflow.Context.pas:416-424` | "线程安全"上下文锁外返回被字典拥有的对象裸引用 → 悬垂 |
| 6 | F-41 | `DeepFlow\Source\Core\DeepFlow.Role.pas:128-204` | 角色接口 GUID 重复（Engine/Logistics、Inspector/Chronicler）→ 接口类型混淆 |
| 7 | F-11 | `FMX\DeepBase.FMX.HB.Controls.pas:562-591` | Paint 吞异常即永久 Dispose，try 外断言再抛 → 死控件/异常风暴 |
| 8 | F-30 | `DeepFlow\Source\Core\DeepFlow.Engine.pas:365-414/288-294` | `Stop`/`Destroy` 对阻塞在角色调用的 worker 无限 `WaitFor` → 挂死 |
| 9 | F-34 | `DeepFlow\Source\Workflow\DeepFlow.Workflow.Context.pas:703-757` | Variant 跨类型比较异常未捕获 → 传播致引擎 esError |
| 10 | F-43 | `DeepFlow\Source\Roles\DeepFlow.Commander.pas:349-363` | 锁外长期持有 `Session` 裸指针，与 `DoStop.Clear` 竞争 → use-after-free |

---

## 存疑区（需跨模块/运行期确认）

- **Q-01（对应 F-02）**：`TChatHistory.GetMessages`（位于 Core，超出本次范围）是否返回内部列表引用？若为引用，则 LLMChatFrame worker 遍历与主线程 `AddUserMessage` 并发构成竞态。需查 Core 实现确认。
- **Q-02（对应 F-37）**：已核实并升级为 🟡 确定泄漏——`TWorkflowStep.Destroy`（L475-484）未回收 `FBranches` 内各 record 的 `Condition`。
- **Q-03（对应 F-35）**：`atScript`/`atHttp` 当前全库无执行器落地（`TWorkflowExecutor` 仅存在于 README），故为潜在而非现网攻击面。一旦实现解释器，风险即升级为 🔴。
- **Q-04（对应 F-26）**：FMX 跨平台（尤其 Android/iOS）`ShowModal` 同帧 `Free` 模态 Form 是否触发访问违规，取决于 FMX 版本模态栈实现；Win64 桌面通常安全。需真机验证。
- **Q-05（对应 F-10/F-09）**：`TUniMaterialEdit.Validate/DoValidate` 是否总修改可见控件状态？若某些子类型仅纯计算，则 F-09 跨线程 UI 访问的实际触发面可能小于最坏估计，但仍应修正线程边界。

---

*本报告为只读审计，未修改任何被审计源码。所有行号基于审计当日文件内容。*
