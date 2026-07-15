# Expert E 审阅报告: UI 层 (VCL/FMX) + 包配置 + Tools/Examples

> 审查日期: 2026-07-06
> 审查人: Expert E (UI/UX/包工程/工具链架构)
> 审查范围: FMX/ 模块(24 个 .pas), VCL/ 模块(48 个 .pas), 包工程 .dpk(24 个), .dproj/.groupproj, Tools/, Examples/
> 文件总数: 80+ .pas + 24 .dpk + 1 .groupproj + 24+.dproj

## 概要

| 项目 | 数值 |
|------|------|
| 审阅模块数 | 80+ |
| 发现总数 | 18 |
| P0(紧急) | 3 |
| P1(高) | 8 |
| P2(中) | 5 |
| P3(低) | 2 |
| 修复回归风险 | 2 |

## 发现列表

| ID | 模块 | 严重度 | 类型 | 简述 | 位置 |
|----|------|--------|------|------|------|
| UI2-001 | DeepBaseCore.dpk / DeepBaseDataPlatform.dpk | P0 | duplicate-unit | DeepBase.SchemaAdapter.WeChat4x 同时出现在两个包中,编译时产生 E2065 duplicate unit | DeepBaseCore.dpk:104, DeepBaseDataPlatform.dpk:39 |
| UI2-002 | FMX/DeepBase.FMX.LLMChatFrame.pas | P0 | use-after-free | DoSendMessage 用 TThread.CreateAnonymousThread 但没赋值给 FCurrentTask;析构时 FCurrentTask 永远 nil,后台线程继续运行使已释放帧悬垂引用 | FMX/DeepBase.FMX.LLMChatFrame.pas:468-540 (L196-201 失效) |
| UI2-003 | VCL/DeepBase.VCL.FeedbackDialog.pas | P0 | resource-leak | SubmitFeedback 中 Post 请求的 TStringStream 未释放,每次提交泄漏流对象 | VCL/DeepBase.VCL.FeedbackDialog.pas:430 |
| UI2-004 | pgDeepBase.groupproj | P1 | build-config | 缺少 DeepBaseSpeechCore、DeepBaseDataPlatform、DeepBaseGovernance、DeepAxis 及 4 个 Speech 子包;但 DeepBaseFeatures 和 DeepBasePersistence requires 了这些包 | pgDeepBase.groupproj:6-51, DeepBaseFeatures.dpk:39-41, DeepBasePersistence.dpk:17 |
| UI2-005 | DeepBaseCore.dproj | P1 | missing-DCCReference | 17 个 contains 单元在 .dproj 中缺少 DCCReference,可能导致 IDE 找不到文件或增量编译问题 | DeepBaseCore.dproj |
| UI2-006 | DeepBaseLLM.dproj | P1 | missing-DCCReference | 4 个 contains 单元在 .dproj 中缺少 DCCReference: Core\DeepBase.LLM.pas 等 | DeepBaseLLM.dproj |
| UI2-007 | DeepBasePersistence.dproj | P1 | missing-DCCReference | 2 个 contains 单元在 .dproj 中缺少 DCCReference | DeepBasePersistence.dproj |
| UI2-008 | DeepBaseCommerce.dproj | P1 | missing-DCCReference | 1 个 contains 单元在 .dproj 中缺少 DCCReference | DeepBaseCommerce.dproj |
| UI2-009 | FMX/DeepBase.FMX.LLMChatFrame.pas | P1 | thread-safety | FHistory.GetMessages 在后台匿名线程中直接调用,未做拷贝同步;若帧在此时销毁则访问已释放的 FHistory | FMX/DeepBase.FMX.LLMChatFrame.pas:478 |
| UI2-010 | FMX/DeepBase.FMX.UpdateDialog.pas | P1 | type-safety | ShowDialog 中直接 TFMXAutoUpdater(AAutoUpdater) 强转,未用 is 检查;传入错误类型时 AV | FMX/DeepBase.FMX.UpdateDialog.pas:111 |
| UI2-011 | VCL/DeepBase.VCL.UpdateDialog.pas | P1 | thread-safety | btnUpdateClick 访问 FUpdateInfo(ForceUpdate) 在 UI 线程,但 FUpdateInfo 在匿名线程的 FCancelRequested/Abort 异常路径中被同步写回,缺少保护 | VCL/DeepBase.VCL.UpdateDialog.pas:112-208 (FIsDownloading 写回路径) |
| UI2-012 | dclDeepBaseCore.dpk | P1 | design-time | 设计时包 contains 为空,没有任何 RegisterComponents 或设计时编辑器;虽然运行时单元自带 Register,但设计时包没有资源图标 | dclDeepBaseCore.dpk:36 |
| UI2-013 | VCL/DeepBase.VCL.NotificationBar.pas | P2 | registration | 该单元有 Register 但 TNotificationBar 无 ComponentIcon,IDE 中显示为默认齿轮图标 | VCL/DeepBase.VCL.NotificationBar.pas:168-171 |
| UI2-014 | VCL/DeepBase.VCL.TrayIcon.pas | P2 | resource-leak | SetVisible(False) 时只清了回调但未 Reset TTrayIcon;SetIcon(nil) 仅设 Handle 为 0,旧的 HICON 可能泄漏 | VCL/DeepBase.VCL.TrayIcon.pas:170-176, 392-400 |
| UI2-015 | VCL/DeepBase.VCL.WaitForm.pas / FMX/DeepBase.FMX.WaitForm.pas | P2 | api-design | CloseWait 调用 Close 后立即 FreeAndNil;Close 触发的事件处理中可能访问 AWaitForm 导致 AV | VCL/DeepBase.VCL.WaitForm.pas:429-435, FMX/DeepBase.FMX.WaitForm.pas:357-363 |
| UI2-016 | VCL/DeepBase.VCL.FeedbackDialog.pas | P2 | thread-safety | SubmitFeedback 访问 FFeedbackUrl、FChkIncludeLogs 等字段在后台线程;虽 TThread.Queue 写回,但 FFeedbackUrl 读取未保护 | VCL/DeepBase.VCL.FeedbackDialog.pas:395-459 |
| UI2-017 | FMX/DeepBase.FMX.FormStateHelper.pas | P2 | cross-platform | SaveState 使用 FForm.ClientWidth/ClientHeight 而不是实际窗口尺寸;在 macOS/iOS 上 ClientWidth 可能为 0 | FMX/DeepBase.FMX.FormStateHelper.pas:302-326 |
| UI2-018 | VCL/DeepBase.VCL.I18nControls.pas (扫描发现) | P3 | i18n | 部分控件按钮文本(发送/取消/清空等)硬编码中文,未通过 i18n 服务 | 多处 |

## 严重度定义

| 严重度 | 含义 |
|--------|------|
| P0 | 可直接导致崩溃、数据损坏或编译失败;须立即修复 |
| P1 | 存在明显缺陷,特定场景下可触发错误;须在当前迭代修复 |
| P2 | 设计瑕疵或潜在风险;建议在后续迭代中修复 |
| P3 | 低优先级问题;可延期修复 |

---

## 详细发现说明

### UI2-001 — DeepBase.SchemaAdapter.WeChat4x 在 DeepBaseCore 和 DeepBaseDataPlatform 中重复

**模块**: DeepBaseCore.dpk / DeepBaseDataPlatform.dpk
**严重度**: P0(编译错误)
**类型**: 重复单元/包边界

DeepBase.SchemaAdapter.WeChat4x 出现在两个运行时包中:
- `DeepBaseCore.dpk` 第 104 行: `DeepBase.SchemaAdapter.WeChat4x in 'Core\DeepBase.SchemaAdapter.WeChat4x.pas'`
- `DeepBaseDataPlatform.dpk` 第 39 行: `DeepBase.SchemaAdapter.WeChat4x in 'Core\DeepBase.SchemaAdapter.WeChat4x.pas'`

由于 DeepBaseCore 是几乎所有包的依赖,而 DeepBaseDataPlatform 被 DeepBaseFeatures 依赖,两个包同时加载时编译器报 "E2065 Unit %s was compiled with a different version" 或链接器报 duplicate unit。

**影响**: 从 groupproj 完整构建时报错。即使单个包构建通过,运行时当两个 BPL 同时加载时可能出现不可预测的行为。

**修复建议**: 从 DeepBaseDataPlatform.dpk 中移除 WeChat4x 行(它在 DeepBaseCore 中已有),或将 WeChat4x 只保留在 DeepBaseDataPlatform 中并从 DeepBaseCore 中移除(注意: DeepBaseSchemaAdapter.WeChat39x 仍在 DeepBaseCore 中,若两者耦合可一起迁移)。

---

### UI2-002 — FMX LLMChatFrame 后台线程无引用,析构后悬垂

**模块**: FMX/DeepBase.FMX.LLMChatFrame.pas
**严重度**: P0(use-after-free)
**类型**: 线程安全/生命周期

**位置**: DoSendMessage(L468-540), Destroy(L192-210)

FMX 版本的 `DoSendMessage` 启动后台任务:
```pascal
TThread.CreateAnonymousThread(
  procedure
  ...
  begin
    Messages := FHistory.GetMessages;  // L478 - 后台线程访问 FHistory
    ...
  end).Start;  // L540
```

但 `FCurrentTask: ITask` 从未被赋值(只在 VCL 版本中用 `FCurrentTask := TTask.Run(...)`)。析构函数检查:
```pascal
if Assigned(FCurrentTask) then     // L201 - 永远 nil
  FCurrentTask.WaitFor(2000);
```

**后果**: 
1. 当用户在 LLM 响应中关闭 Frame/Form,后台匿名线程继续执行
2. 线程中访问 `Self.FHistory`(L478)、`Self.FClient`(L482) 等字段,此时 Frame 已被释放
3. 在 `TThread.Synchronize` 回调(L487-522)中同样访问已释放的 `Self.FMemoChat`、`Self.FChatItems`

**修复建议**:
1. 将 `FCurrentTask` 改为 `TThread` 类型或 `ITask`,并正确赋值
2. 或在析构时调用 `FCurrentTask.WaitFor`(改为 TThread 则用 `FThread.WaitFor`)
3. 建议将 FMX 版本改为与 VCL 版本一致的 `TTask.Run + 局部变量捕获` 模式

---

### UI2-003 — FeedbackDialog HTTP Post TStringStream 泄漏

**模块**: VCL/DeepBase.VCL.FeedbackDialog.pas
**严重度**: P0(资源泄漏)
**类型**: 内存泄漏

**位置**: SubmitFeedback L430

```pascal
Response := Client.Post(FFeedbackUrl,
  TStringStream.Create(JsonObj.ToString, TEncoding.UTF8));  // L430 - 创建了 TStringStream
```

`TStringStream.Create` 作为参数传入 Post,但 THTTPClient.Post 的文档表明调用方拥有所有权。Stream 在 Post 返回后未被释放,每次反馈提交泄漏一个 TStringStream(~几十字节)。

**修复建议**: 
```pascal
var SS: TStringStream;
SS := TStringStream.Create(JsonObj.ToString, TEncoding.UTF8);
try
  Response := Client.Post(FFeedbackUrl, SS);
finally
  SS.Free;
end;
```

---

### UI2-004 — groupproj 缺少多个必要包

**模块**: pgDeepBase.groupproj
**严重度**: P1(构建配置)
**类型**: 缺失依赖

当前 groupproj 包含 15 个包,但缺少以下已在 requires 中声明的依赖:
- **DeepBaseFeatures.dpk** requires: `DeepBaseSpeechCore`, `DeepBaseDataPlatform`
- **DeepBasePersistence.dpk** requires: `DeepBaseSpeechCore`
- 完整的 Speech 子包(DeepBaseSpeechWake/ASR/TTS/Voice)和 DeepBaseGovernance、DeepAxis 也未在 groupproj 中

从 groupproj 一键构建时,由于缺少这些包,无法直接将所有依赖解析完毕。虽然可以通过已编译的 DCU 绕过,但增量构建和首次构建会失败。

**修复建议**: 将缺失包加入 groupproj `<ItemGroup>` 并确保构建顺序正确:
- DeepBaseSpeechCore (优先于 DeepBaseFeatures)
- DeepBaseDataPlatform (优先于 DeepBaseFeatures)
- DeepBaseGovernance (如需要)
- DeepAxis (已由 DeepBaseDataPlatform requires)
- 4 个 Speech 子包

---

### UI2-005 — DeepBaseCore.dproj 缺少 17 个 DCCReference

**模块**: DeepBaseCore.dproj
**严重度**: P1(IDE/构建兼容性)
**类型**: 缺失引用

.dpk contains 声明了这些单元,但 .dproj 中没有对应的 DCCReference:

| 缺失单元 | .dpk 路径 |
|----------|-----------|
| DeepBase.SQL.Splitter | Core\DeepBase.SQL.Splitter.pas |
| DeepBase.SQL.Utils | Core\DeepBase.SQL.Utils.pas |
| DeepBase.i18n.Gender | Core\DeepBase.i18n.Gender.pas |
| DeepBase.AutoFix.StackWalker | Core\DeepBase.AutoFix.StackWalker.pas |
| DeepBase.AutoFix.ErrorRecorder | Core\DeepBase.AutoFix.ErrorRecorder.pas |
| DeepBase.AutoFix.ScenarioRunner | Core\DeepBase.AutoFix.ScenarioRunner.pas |
| DeepBase.AutoFix.SelfTerminator | Core\DeepBase.AutoFix.SelfTerminator.pas |
| DeepBase.AutoFix.HealthSignal | Core\DeepBase.AutoFix.HealthSignal.pas |
| DeepBase.AutoFix | Core\DeepBase.AutoFix.pas |
| DeepBase.External.Types | Core\DeepBase.External.Types.pas |
| DeepBase.External.Auditor | Core\DeepBase.External.Auditor.pas |
| DeepBase.Platform.Interfaces | Core\DeepBase.Platform.Interfaces.pas |
| DeepBase.SchemaAdapter.Types | Core\DeepBase.SchemaAdapter.Types.pas |
| DeepBase.SchemaAdapter | Core\DeepBase.SchemaAdapter.pas |
| DeepBase.SchemaAdapter.Registry | Core\DeepBase.SchemaAdapter.Registry.pas |
| DeepBase.SchemaAdapter.WeChat39x | Core\DeepBase.SchemaAdapter.WeChat39x.pas |
| DeepBase.SchemaAdapter.WeChat4x | Core\DeepBase.SchemaAdapter.WeChat4x.pas |

**影响**: IDE 在加载 .dproj 时无法将这些文件映射到包中,影响项目管理、编译和调试路径解析。

**修复建议**: 在 DeepBaseCore.dproj 的 `<ItemGroup>` 下为每个缺失单元添加 `<DCCReference Include="...">`。

---

### UI2-006 — DeepBaseLLM.dproj 缺少 4 个 DCCReference

**模块**: DeepBaseLLM.dproj
**严重度**: P1(IDE/构建兼容性)
**类型**: 缺失引用

同理,以下单元在 .dpk contains 中存在但 .dproj 中无 DCCReference:
- `Core\DeepBase.LLM.pas`
- `Core\DeepBase.LLM.BillingClient.pas`
- `Core\DeepBase.LLM.Manager.pas`
- `Core\DeepBase.LLM.ImportExport.pas`

---

### UI2-007 — DeepBasePersistence.dproj 缺少 2 个 DCCReference

**模块**: DeepBasePersistence.dproj
**严重度**: P1(IDE/构建兼容性)
**类型**: 缺失引用

- `Persistence\DeepBase.ORM.pas`
- `Persistence\DeepBase.Persistence.Speech.Voiceprint.FireDAC.pas`

---

### UI2-008 — DeepBaseCommerce.dproj 缺少 1 个 DCCReference

**模块**: DeepBaseCommerce.dproj
**严重度**: P1(IDE/构建兼容性)
**类型**: 缺失引用

- `Features\DeepBase.Net.Transport.pas`

---

### UI2-009 — FMX LLMChatFrame 后台线程访问 FHistory 未保护

**模块**: FMX/DeepBase.FMX.LLMChatFrame.pas
**严重度**: P1(线程安全)
**类型**: 数据竞争

```pascal
// L477-482 - 在匿名线程内部访问字段
Messages := FHistory.GetMessages;   // 后台线程访问 FHistory

try
  Response := FClient.ChatWithHistory(Messages);  // 后台线程访问 FClient
```

与此对比,VCL 版本(DeepBase.VCL.LLMChatFrame.pas:486-489)将字段拷贝到局部变量再启动任务:
```pascal
var LClient := FClient;
var LMessages := FHistory.GetMessages;
...
FCurrentTask := TTask.Run(
```

**影响**: 若 Frame 在后台任务运行期间被销毁,FHistory 和 FClient 已被释放,后台线程访问已释放内存。

**修复建议**: 将 FMX 版本改为与 VCL 一致的局部变量捕获模式,在 UI 线程拷贝字段到局部变量再启动后台任务。

---

### UI2-010 — FMX UpdateDialog 强转类型未保护

**模块**: FMX/DeepBase.FMX.UpdateDialog.pas
**严重度**: P1(运行时崩溃)
**类型**: 类型安全

```pascal
// L111
Dialog.LblVersion.Text := Format('Version %s -> %s',
  [TFMXAutoUpdater(AAutoUpdater).CurrentVersion, Info.Version.ToString]);
```

`AAutoUpdater` 参数是 `TComponent`,被直接硬转换为 `TFMXAutoUpdater`。若调用方传入非 `TFMXAutoUpdater` 类型,产生无效指针访问(AV)。

**影响**: 任何传入错误类型的调用都导致崩溃。

**修复建议**: 
```pascal
if not (AAutoUpdater is TFMXAutoUpdater) then
  Exit;
var AutoUpdater := TFMXAutoUpdater(AAutoUpdater);
```

---

### UI2-011 — VCL UpdateDialog 线程安全边界问题

**模块**: VCL/DeepBase.VCL.UpdateDialog.pas
**严重度**: P1(线程安全)
**类型**: 竞态条件

StartDownload(L130-207) 在匿名线程内用 FCancelRequested 做取消标志。但以下路径涉及 UI 状态写回:
1. 取消时的 `FIsDownloading := False` (L141, L182, L192)
2. 成功/失败路径设置 `btnUpdate.Enabled`、`pbDownload.Visible`

虽然 TThread.Synchronize/Queue 包裹了 UI 操作,但 `FIsDownloading` 布尔标志在 UI 线程的 `btnCancelClick`(L218) 中被读取,而该变量可能同时从后台线程的 Synchronize 回调中写入。布尔值本身是原子的但缺乏内存屏障(memory barrier),不同线程可能看到不同值。

**影响**: 极低概率下,取消后按钮状态不正确。

**修复建议**: 添加 `TInterlocked` 或 `TVolatile` 保护 FIsDownloading;或在主线程加 TEvent 同步取消状态。

---

### UI2-012 — dclDeepBaseCore 设计时包为空

**模块**: dclDeepBaseCore.dpk
**严重度**: P1(设计时包完整性)
**类型**: 缺失注册

```pascal
package dclDeepBaseCore;
{$DESIGNONLY}
requires
  rtl,
  designide,
  DeepBaseCore;
// contains 缺失!
end.
```

该包没有 contains 任何单元,且其他 Runtime 包的 Register 方法仅在运行时有效(Install Packages 不会扫描运行时包)。这导致:
- 设计时包安装后 IDE 组件面板没有新组件可用
- 与 dclDeepBaseVCL(contains DeepBase.VCL.Controls)和 dclDeepBaseFMX(contains DeepBase.FMX.Controls)不一致

**修复建议**: 如果 DeepBaseCore 中有需要设计时注册的组件,创建对应的注册单元加入 contains;否则考虑删除此空包。

---

### UI2-013 — TNotificationBar 注册组件无图标

**模块**: VCL/DeepBase.VCL.NotificationBar.pas
**严重度**: P2(用户体验)
**类型**: 设计时资源

```pascal
procedure Register;
begin
  RegisterComponents('DeepBase', [TNotificationBar]);
end;
```

组件已注册但未指定 ComponentIcon。VCL IDE 使用默认齿轮图标,与其他 DeepBase 组件不一致。

**修复建议**: 在单元中添加 `{$R *.dcr}` 资源文件引用,为 TNotificationBar 提供 24x24 位图资源。

---

### UI2-014 — TrayIcon 资源清理不完整

**模块**: VCL/DeepBase.VCL.TrayIcon.pas
**严重度**: P2(资源泄漏)
**类型**: GDI 资源泄漏

1. `SetIcon(nil)` (L175): `FIcon.Handle := 0` 直接将图标句柄置零,但旧句柄未被 `DeleteObject` 释放。TIcon.Assign 内部会处理,但直接置 Handle 不会释放之前的 GDI 对象。

2. `SetVisible(False)` (L392-400): 调用 `TTrayIcon.Hide` 隐藏托盘图标,但没有调用 `TTrayIcon.Reset` 清理图标句柄或通知消息回调。

**修复建议**: 
```pascal
procedure TDeepBaseTrayIcon.SetIcon(const Value: TIcon);
begin
  if Assigned(Value) then
    FIcon.Assign(Value)
  else
    FIcon.Handle := 0;  // 应改为 FIcon.Clear 或释放旧资源
end;
```

建议用 `FIcon.Clear` 替代直接置 0。

---

### UI2-015 — WaitForm Close 后立即 FreeAndNil

**模块**: VCL/DeepBase.VCL.WaitForm.pas / FMX/DeepBase.FMX.WaitForm.pas
**严重度**: P2(潜在崩溃)
**类型**: 生命周期

```pascal
class procedure TWaitForm.CloseWait(var AWaitForm: TWaitForm);
begin
  if Assigned(AWaitForm) then
  begin
    AWaitForm.Close;        // Close 可能触发异步事件
    FreeAndNil(AWaitForm);  // 此时 AWaitForm 可能还在被访问
  end;
end;
```

`Close` 在某些情况下(如模态窗口、VCL 消息队列)可能触发延缓关闭。`FreeAndNil` 在 Close 返回后立即释放,可能发生在 close 事件处理中。

**修复建议**: 在 Close 后调用 `Application.ProcessMessages` 确保关闭完成再 Free,或使用 Release 替代 Close。

---

### UI2-016 — FeedbackDialog 后台线程读 UI 字段

**模块**: VCL/DeepBase.VCL.FeedbackDialog.pas
**严重度**: P2(线程安全)
**类型**: 数据竞争

```pascal
// L395-459
TThread.CreateAnonymousThread(
  procedure
  begin
    ...
    if FFeedbackUrl = '' then    // 后台线程读 FFeedbackUrl
    ...
    if FChkIncludeLogs.Checked then  // 后台线程读 CheckBox
    ...
```

`FFeedbackUrl` 和 `FChkIncludeLogs.Checked` 在后台线程中读取,但 UI 线程可能在读取同时修改这些值。虽然实际情况中 FeedbackUrl 很少变化,但结构上存在数据竞争。

**修复建议**: 在进入线程前将字段拷贝到局部变量:
```pascal
var LUrl := FFeedbackUrl;
var LIncludeLogs := FChkIncludeLogs.Checked;
...
TThread.CreateAnonymousThread(
  procedure
  begin
    ...
    if LUrl = '' then
```

---

### UI2-017 — FMX FormStateHelper 保存 ClientWidth/ClientHeight

**模块**: FMX/DeepBase.FMX.FormStateHelper.pas
**严重度**: P2(跨平台兼容)
**类型**: 尺寸保存错误

```pascal
// L305-308
Data.Width := Round(FForm.ClientWidth);
Data.Height := Round(FForm.ClientHeight);
```

在 FMX 中,`ClientWidth/ClientHeight` 在某些平台(如 iOS 初期启动、macOS 无边框窗口)可能为 0。恢复时 SetBounds(Data.Left, Data.Top, 0, 0) 使窗口不可见。相比之下,VCL 版本使用 `GetWindowPlacement.rcNormalPosition` 获取窗口实际外框尺寸。

**修复建议**: 使用 `FForm.Width/Height` 或 `WindowRect` 的属性替代 Client* 属性,更准确地反映窗口实际占用空间。

---

### UI2-018 — 控件文本硬编码中文

**模块**: 多个 FMX/VCL 模块
**严重度**: P3(i18n)
**类型**: 国际化缺失

多处按钮/标签文本直接硬编码为中文(发送/取消/清空/就绪/系统等),未通过 i18n 服务获取翻译字符串。例如:
- FMX LLMChatFrame: BtnSend.Text `:= '发送'`
- VCL LLMChatFrame: BtnSend.Caption `:= '发送'`
- VCL NotificationBar: FCancelButton.Caption `:= 'Cancel'`(英文混杂)

虽然项目以中文用户为主要对象,但硬编码字符串无法通过 DeepBase.i18n 切换语言。

**修复建议**: 通过注入的 i18n 服务或全局函数获取界面文本。

---

## 修复回归验证

### REVIEW5-UI-002 修复 (FMX LLMChatFrame 任务取消)
FMX 版本在 Destroy 中加了取消逻辑和 `FCurrentTask.WaitFor(2000)`,但由于 `FCurrentTask` 从未赋值,整个保护逻辑无效(UI2-002)。这不是回归,而是原始修复不完整。

### REVIEW5-UI-003 修复 (VCL UpdateDialog 线程生命周期)
VCL UpdateDialog 的 REVIEW5-UI-003 修复增加了 FDownloadThread 生命周期管理,代码正确(L130-207)。没有问题。

### REVIEW5-GOV-003 修复 (包依赖同步)
合并了 8 个核心包但 groupproj 未同步(UI2-004),同时引入了 WeChat4x 重复问题(UI2-001)。

---

## 附录: dproj vs dpk 同步状态汇总

| 包名 | contains 单元数 | dproj 缺失引用数 |
|------|----------------|------------------|
| DeepBaseCore | 70 | 17 (24%) |
| DeepBaseLLM | 11 | 4 (36%) |
| DeepBasePersistence | 31 | 2 (6%) |
| DeepBaseCommerce | 13 | 1 (8%) |
| DeepBaseDataPlatform | 2 | 0 |
| DeepBaseFeatures | 0 (meta) | 0 |
| DeepBaseFMX | 23 | 0 |
| DeepBaseVCL | 35 | 0 |
| DeepBaseServices | 23 | 0 |
| DeepBasePlatform | 15 | 0 |
| DeepBaseBrowser | 16 | 0 |
| DeepBaseGovernance | 39 | 0 |
| DeepBaseIntentClarification | 29 | 0 |
| DeepBaseInference | 5 | 0 |
| DeepBaseSpeechCore | 15 | 0 |
| DeepBaseSpeechASR | 5 | 0 |
| DeepBaseSpeechTTS | 3 | 0 |
| DeepBaseSpeechWake | 1 | 0 |
| DeepBaseSpeechVoice | 1 | 0 |
| DeepAxis | 2 | 0 |
| dclDeepBaseCore | 0 (empty) | 0 |
| dclDeepBaseFMX | 1 | 0 |
| dclDeepBaseVCL | 1 | 0 |

注: DeepBaseLLM.dpk contains 11 个单元但 dproj 缺失 4 个 Core 路径单元(应该是迁移到 Features 路径时漏了 Core 路径的 DCCReference)。
