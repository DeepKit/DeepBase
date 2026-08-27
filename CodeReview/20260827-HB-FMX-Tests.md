# DeepBase HB 视觉系统 FMX 双胞胎层与自动化测试套件静态审计报告

- **审计日期**： 2026-08-27
- **审计人**： AI 静态审计（Delphi 13.1 Athens / Win64）
- **受审范围**： FMX 层 18 个单元（`D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.*.pas`）+ 测试层 5 个 HB 测试单元 + `DeepBaseTests.dpr` + `Scripts\run_tests.ps1`
- **对照基准**： `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.*.pas`（同名 VCL 双胞胎）与 `D:\_Progs\02Business\DeepBase\Core\DeepBase.HB.*.Types.pas`（Core 契约）
- **编译器实测**： `D:\Program Files (x86)\Embarcadero\Studio\37.0\bin\dcc64.exe`（37.0），参数 `-B -Q -U<Core;FMX> -I<Core;FMX>`
- **方法**： 5 个对照控件（Gate/VirtualList/Grid/CommandPalette/ShareCard）全文深读 + VCL 同名单元逐函数对照；其余 FMX 单元做 uses/基类/override 全量结构扫描 + 抽样深读（Voice/Dialogs/Waterfall/Controls）；测试文件全文阅读；dcc64 实测编译 6 个单元（3 个疑似破损 + 3 个对照）
- **证据纪律**： 所有行号均为实际读取/编译输出所见，未发现项不臆造

---

## 0. 执行摘要：FMX HB 18 单元实测分层

| 层 | 单元 | 基类 | 状态 |
|---|---|---|---|
| 服务层（无控件类） | Theme / Palettes / Tray | — | 编译通过（Theme 经对照组验证），Tray 为菜单数据结构 |
| A 层：完整双胞胎 | Controls / Cards / Terminal / Dialogs(THbSummaryBar) / Voice(波形+字段卡) | `THbFmxControl` | 走 `Paint → DrawHbControl(Canvas, Rect, Tokens)` 渲染管线 + 主题变更订阅，架构正确 |
| B 层：数据骨架 | Waterfall / Grid / AI / NavTree / PageControl / Dock | 直接 `class(TControl)` | 全部 **零 override**（无 Paint/无鼠标交互），API 面与 VCL 大体同名但无渲染无事件 |
| C 层：编译破损 | CommandPalette / Gate / VirtualList | `THbCustomControl`（不存在） | **dcc64 实测 E2003，3 个单元全部无法编译** |
| 独立 | ShareCard | 纯 class（无控件基类） | 编译通过，但 `RenderToBitmap` 返回空白位图 |

---

## 一、🔴 严重发现

### F-01 【🔴】三个 FMX 单元无法编译：基类 `THbCustomControl` 在 FMX 语境不存在

**位置 1**： `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.Gate.pas:32`
```pascal
  THbGatePanel = class(THbCustomControl)
```
**位置 2**： `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.CommandPalette.pas:33`
```pascal
  THbCommandPalette = class(THbCustomControl)
```
**位置 3**： `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.VirtualList.pas:32`
```pascal
  THbVirtualList = class(THbCustomControl)
```

**dcc64 实测铁证**（2026-08-27，`-B -Q -U/Core+FMX`）：
```
FMX\DeepBase.FMX.HB.Gate.pas(32) Error: E2003 Undeclared identifier: 'THbCustomControl'
FMX\DeepBase.FMX.HB.Gate.pas(32) Error: E2021 Class type required
FMX\DeepBase.FMX.HB.Gate.pas(40) Error: E2170 Cannot override a non-virtual method
FMX\DeepBase.FMX.HB.Gate.pas(41) Error: E2037 Declaration of 'Create' differs from previous declaration
FMX\DeepBase.FMX.HB.Gate.pas(52) Error: E2147 Property 'Align' does not exist in base class
FMX\DeepBase.FMX.HB.Gate.pas(64) Error: E2003 Undeclared identifier: 'Width'
FMX\DeepBase.FMX.HB.Gate.pas(65) Error: E2003 Undeclared identifier: 'Height'
EXITCODE[Gate]=1
（CommandPalette 同型 8 处错误于 :33 起；VirtualList 同型于 :32 起；两者均 EXITCODE=1）
```

**根因**： `THbCustomControl` 全库唯一声明在 VCL 侧 `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.Controls.pas:57`（`class(TCustomControl)`）。FMX 侧正确基类是 `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.Controls.pas:44` 的 `THbFmxControl = class(TControl)`（其 `:57` 声明 `DrawHbControl(...); virtual; abstract;` 渲染管线）。三个单元的 uses 已含 `DeepBase.FMX.HB.Controls` 却引用了 VCL 类名——典型“从 VCL 版复制头文件未改基类”。
**对照组**（证明非环境问题）： 同参数下 `Voice / Grid / ShareCard` 三单元 EXITCODE=0 编译通过。

**触发条件**： 任何工程（主程序/测试/Gallery）只要 uses 这三个单元之一，编译立即失败。
**建议修复**： 三处 `class(THbCustomControl)` 改为 `class(THbFmxControl)`；改后需补齐 `Width/Height`（THbFmxControl 为 Single 系）等级联适配，并以 dcc64 复测归零。

---

### F-02 【🔴】编译盲区：18 个 FMX HB 单元中 14 个不被任何工程引用，破损无法被 CI 发现

**证据**： 全库 `.dpr` / `.dproj` grep `DeepBase.FMX.HB.` 仅一处命中：
`D:\_Progs\02Business\DeepBase\Tools\FMXGallery\hbtheme_fmx_gallery.dpr:9-12`
```pascal
  DeepBase.FMX.HB.Theme in '..\..\FMX\DeepBase.FMX.HB.Theme.pas',
  DeepBase.FMX.HB.Palettes in '..\..\FMX\DeepBase.FMX.HB.Palettes.pas',
  DeepBase.FMX.HB.Controls in '..\..\FMX\DeepBase.FMX.HB.Controls.pas',
  DeepBase.FMX.HB.Cards in '..\..\FMX\DeepBase.FMX.HB.Cards.pas';
```
其余 14 个单元（Terminal/Dialogs/Voice/Tray/Waterfall/Grid/AI/NavTree/PageControl/Dock/CommandPalette/Gate/VirtualList/ShareCard）在所有 `.dpr`/`.dproj` 中**零引用**——F-01 的 3 个破损单元因此长期潜伏，`run_tests.ps1` 的编译门禁永远测不到它们。

**触发条件**： 现在。任何人在未来把这 14 个单元之一接入工程，才会“突然”编译爆炸。
**建议修复**： 短期把 18 个单元全部纳入 `hbtheme_fmx_gallery.dpr`（或新建 FMX smoke 工程挂进 `run_tests.ps1` 编译步骤）；中期为 FMX 双胞胎建专门测试单元（见 T-01），破损即刻红灯。

---

### F-03 【🔴】FMX `THbDialog` 四个静态方法全部为恒真桩——确认流被静默放行

**位置**： `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.Dialogs.pas:330-348`
```pascal
class procedure THbDialog.ShowInfo(const ATitle, AMessage: string);
begin
  // FMX ShowInfo implementation
end;

class function THbDialog.Confirm(const ATitle, AMessage: string; const ABoundaryNotice: string): Boolean;
begin
  Result := True;          // ← 恒真
end;

class function THbDialog.Prompt(const ATitle, APrompt: string; var AValue: string): Boolean;
begin
  Result := True;          // ← 恒真，且 AValue 从未被写入/询问
end;

class function THbDialog.PromptReason(const ATitle, APrompt: string; var AReason: string): Boolean;
begin
  Result := True;
end;
```

**VCL 对照**（真实模态）： `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.Dialogs.pas:523` `if DlgForm.ShowModal = mrOk then`。
**触发条件**： 宿主把任何删除/覆盖/写库确认流接到 FMX 版 `THbDialog.Confirm` → 用户永远不被询问，操作直接放行；`Prompt` 返回 True 但 `AValue` 保持调用方初值，下游拿到假输入。
**建议修复**： 实现真实 FMX 模态（`FMX.Forms` + 动态构建 THbFmxControl 面板）；在实现之前，桩应 `raise ENotImplemented.Create('THbDialog FMX twin pending')` 防止静默放行——恒真比抛异常危险得多。

---

### F-04 【🔴】FMX `THbVoiceDialog.Execute` 恒真桩——语音字段写库流被自动“全部确认”

**位置**： `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.Voice.pas:372-378`
```pascal
class function THbVoiceDialog.Execute(const ATitle: string;
  var AItems: TArray<THbVoiceFieldItem>;
  out AConfirmedCount: Integer): Boolean;
begin
  AConfirmedCount := Length(AItems);   // ← 全部字段视为已确认
  Result := True;                       // ← 恒真
end;
```

**VCL 对照**（真实模态）： `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.Voice.pas:679` `if DlgForm.ShowModal = mrOk then`。
**触发条件**： 与治理测试 `Test.DeepBase.HB.Voice.CF` 的 CF-VOICE-01（未确认字段不得入库）意图正面冲突——该测试守卫的是 Core 层过滤逻辑，测不到这个 FMX 桩。若宿主通过 FMX 对话框确认语音字段，`vfsPending/vfsDiscarded` 的字段会被直接计数为“已确认”。
**建议修复**： 同 F-03——真实模态或显式 raise；绝不允许“返回成功 + 全部确认”的组合静默存在。

---

## 二、🟡 FMX 双胞胎一致性 / 正确性

### F-05 【🟡】CommandPalette（FMX）：无模糊搜索、SearchText 无副作用、缺 FilteredCount

**位置**： `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.CommandPalette.pas:79-86` 与 `:52`
```pascal
procedure THbCommandPalette.RebuildFilteredList;
var I: Integer;
begin
  FFilteredIndices.Clear;
  for I := 0 to FItems.Count - 1 do
    FFilteredIndices.Add(I);          // ← 全量直通，FSearchText 从未参与
end;
...
    property SearchText: string read FSearchText write FSearchText;  // ← 直写字段
```
**VCL 对照**： `DeepBase.VCL.HB.CommandPalette.pas:60/:154/:190`（`MatchFuzzy` 子序列匹配并驱动过滤）、`:198-206`（`SetSearchText` setter 触发 `RebuildFilteredList + Invalidate`）、`:85`（`FilteredCount` 只读属性）。
**触发条件**： FMX 宿主 `SearchText := '体检'` 后列表纹丝不动、无重绘；`Test.DeepBase.HB.DeepRW` 的 `FilteredCount` 断言（DeepRW:80/84）在 FMX 版无对应属性，测试无法移植。
**建议修复**： 移植 `MatchFuzzy`；`SearchText` 改 setter 调 `RebuildFilteredList`；补 `FilteredCount: Integer read GetFilteredCount`。

### F-06 【🟡】Gate（FMX）：纯数据骨架——无绘制、无严重度过滤、无手风琴折叠

**位置**： `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.Gate.pas:32-55`（类声明无任何 `Paint/Resize/MouseDown` override、无子控件、无 `IsRowVisible`）；`:49`
```pascal
    property FilterSeverity: Integer read FFilterSeverity write FFilterSeverity;
```
**VCL 对照**： `DeepBase.VCL.HB.Gate.pas:41-93` 有完整 `Paint/Resize/MouseDown` override、`FPnlSummaryBar` 等 8 个子控件、`:68 IsRowVisible` 严重度过滤、`:83 ToggleRowExpand` 手风琴。
**接口缺口**： FMX 版无 `ToggleRowExpand`——DeepRW 测试 `Gate.ToggleRowExpand(0)`（DeepRW:123）无法移植。
**触发条件**： FMX 宿主放入 THbGatePanel 显示一块空白 750×500 区域；设置 `FilterSeverity` 后无任何效果；点击规则行无展开。
**备注**： `ComputeStats` 本身无恙——`IsAllPassed/HasBlockingErrors` 是 Core 契约 record 方法（`Core\DeepBase.HB.Gate.Types.pas:50-51/68-76`），按计数即时计算，无需 FMX 侧填。
**建议修复**： 基于 `THbFmxControl`（修 F-01 后）重写渲染/过滤/折叠三件套，或明确降级该单元为“数据模型”并从控件层除名。

### F-07 【🟡】VirtualList（FMX）：无搜索过滤、IsSelected 与选中列表脱节、事件声明即死代码、缺 FilteredCount

**位置 1**（过滤直通）： `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.VirtualList.pas:84-91`——`RebuildFilteredIndices` 全量直通，`:54` `SearchFilter` 直写字段。VCL 对照 `DeepBase.VCL.HB.VirtualList.pas:188-196` setter 触发过滤+重绘。
**位置 2**（数据脱节）： `:122-133`
```pascal
procedure THbVirtualList.SelectItem(AIndex: Integer; AAccumulate: Boolean);
begin
  if (AIndex >= 0) and (AIndex < FItems.Count) then
  begin
    if not AAccumulate then FSelectedIndices.Clear;
    if FSelectedIndices.Contains(AIndex) then
      FSelectedIndices.Remove(AIndex)      // ← toggle 语义，且从不回写 Item.IsSelected
    else FSelectedIndices.Add(AIndex);
  end;
end;
```
`:108` 加项时 `Item.IsSelected := False` 之后再无人更新——模型字段与选中列表永远矛盾。
**位置 3**（死事件）： `:38-39` 声明 `FOnItemAction/FOnSelectionChange` 并在 `:58-59` published，但全单元无一处 `if Assigned(...) then` 调用——宿主挂了事件也永远不触发。
**接口缺口**： VCL `:86 FilteredCount`（DeepRW:148/162 断言依赖）FMX 无。
**建议修复**： 过滤 setter 化；`SelectItem/DeselectAll` 同步 `Item.IsSelected`；选择变化处触发 `OnSelectionChange`；补 `FilteredCount`。

### F-08 【🟡】Grid（FMX）：无渲染、无数据回调、统计字段几乎全空

**位置 1**： `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.Grid.pas:27`——`class(TControl)` 且全单元零 override（无 Paint）。
**位置 2**： `:111-115`
```pascal
function THbFmxDataGrid.ComputeSelectionStats: THbGridStats;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.SelectedRowCount := FSelectedRows.Count;   // ← 只填 1 项
end;
```
**VCL 对照**： `DeepBase.VCL.HB.Grid.pas:208-243` 经 `OnGetCellFloat/OnGetCellText` 回调计算 `SelectedCellCount/NumericCount/SumValue/AvgValue/MinValue/MaxValue`（`:90` 声明回调属性）。
**触发条件**： FMX 宿主选中两行求和 → `Stats.SumValue` 恒 0；Suite 测试 `Test_DataGrid_VirtualRows_And_Stats`（Suite:131-137 的 Sum/Avg/Min/Max 断言）在 FMX 版必然全挂或无法编译（无 `OnGetCellFloat`）。
**建议修复**： 补 `OnGetCellFloat/OnGetCellText` 事件与统计计算（注意别复制 VCL 的 `ValFloat <> 0.0` 语义，见可疑区 S-02）。

### F-09 【🟡】ShareCard（FMX）：`RenderToBitmap` 返回空白位图，`SaveToFile` 导出空图

**位置**： `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.ShareCard.pas:83-91`
```pascal
class function THbShareCardRenderer.RenderToBitmap(const AData: THbShareCardData;
  AFormat: THbShareCardFormat): FMX.Graphics.TBitmap;
var W, H: Integer; Bmp: FMX.Graphics.TBitmap;
begin
  GetDimensions(AFormat, W, H);
  Bmp := FMX.Graphics.TBitmap.Create(W, H);
  Result := Bmp;     // ← AData 完全未使用：无标题/指标行/徽章/水印/二维码槽
end;
```
`:93-105` 的 `SaveToFile` 于是把空白（透明）位图写成文件。`MaskSensitiveText`（`:64-81`）与 `GetDimensions`（`:39-62`）与 VCL 版逐行同构（VCL:49-91），**唯渲染体缺失**。
**触发条件**： FMX 宿主导出 4:5 分享卡 → 得到尺寸正确但内容全空的 PNG，且尺寸断言型测试照样绿灯（见 T-02）。
**建议修复**： 用 FMX Canvas（`TBitmap.Canvas` + `THbTheme.Tokens`）移植 VCL 渲染逻辑；未移植前 `SaveToFile` 应 raise 而非静默产出废文件。

### F-10 【🟡】Voice 波形计时器不计时、MaxDuration 到点不停录（FMX 与 VCL 同病，共享缺口）

**位置**： `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.Voice.pas:161-170`
```pascal
procedure THbVoiceWaveform.OnTimerTick(Sender: TObject);
begin
  if FIsRecording and not FIsPaused then
  begin
    FAnimPhase := FAnimPhase + 0.15;      // ← 只推进动画相位
    ...
```
`FDurationSec` 自 `StartRecording`（`:174` 置 0）后永无增长 → `:239` 的 `'%.2d:%.2d / %.2d:%.2d'` 显示恒 `00:00 / 02:00`；`MaxDurationSec`（`:113` 默认 120）到点无 `StopRecording` 调用。
**VCL 对照**： `DeepBase.VCL.HB.Voice.pas:177-186` 同样只推进 `FAnimPhase`——**双胞胎共享缺口，非 FMX 独有回归**（Voice.CF 测试 CF-VOICE-06 的 120s 截断测的是 Core 层逻辑，测不到波形控件）。
**建议修复**： OnTimerTick 累计毫秒，逢 1000ms `Inc(FDurationSec)`；`FDurationSec >= FMaxDurationSec` 时自动 `StopRecording`。两侧同修。

### F-11 【🟡】B 层 6 单元绕过 `THbFmxControl` 渲染管线：无主题订阅、无状态管理、无绘制

**位置**（6 处，均为 `class(TControl)` 直继承）：
- `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.Waterfall.pas:27`（实测深读确认：只有 AddFacet/ExcludeFacet 等**数据方法**，全单元零 override，无渲染）
- `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.Grid.pas:27`
- `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.AI.pas:27`
- `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.NavTree.pas:27`
- `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.PageControl.pas:27`
- `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.Dock.pas:26`

**对照**： A 层正确架构在 `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.Controls.pas:44-63`——`THbFmxControl` 统一提供主题变更订阅（`:48 OnThemeChangedMessage`）、六态鼠标/焦点 override（`:50-55`）、`Paint → DrawHbControl(Canvas, ARect, Tokens)` 管线（`:56-57`）。B 层 6 单元一个都没接：主题切换不刷新、hover/press 状态无、任何场景都是白板控件。
**结构扫描证据**： FMX HB 全目录 override 扫描（44 处命中）全部落在 Controls/Cards/Terminal/Dialogs/Voice 五个 A 层单元，B 层 6 单元零命中。
**建议修复**： B 层统一改继承 `THbFmxControl` 并实现 `DrawHbControl`；Waterfall 的数据 API（与 VCL 测试断言面同名）可保留，只补渲染层。

---

## 三、🟡 测试质量

### T-01 【🟡】FMX 双胞胎零测试覆盖：5 个 HB 测试单元 100% 只测 VCL

**证据**：
- `D:\_Progs\02Business\DeepBase\Tests\` 全目录 grep `DeepBase\.FMX\.HB`——**零命中**；
- `Test.DeepBase.HB.DeepRW.pas:28-31` uses `DeepBase.VCL.HB.CommandPalette/Gate/VirtualList/ShareCard`；
- `Test.DeepBase.HB.Suite.pas:31-36` uses `DeepBase.VCL.HB.Waterfall/Grid/AI/NavTree/PageControl/Dock`；
- `Test.DeepBase.HB.Tray.pas:19` uses `DeepBase.VCL.HB.Tray`；
- `Test.DeepBase.HB.Voice.CF.pas:18-19` 只用 Core 契约（`DeepBase.HB.Core/Voice.Types`）——纯逻辑测试，与 UI 层无关。

**后果**： F-01 的 3 个编译破损、F-09 的空白位图、F-03/F-04 的恒真桩，全部处于测试雷达之外；"双胞胎一致性"没有任何自动化防线。
**建议修复**： 新建 `Test.DeepBase.FMX.HB.Twins.pas`，至少覆盖：ShareCard 掩码/尺寸、Gate/VList/CP 的数据方法（含 F-05/06/07 修复后的过滤逻辑）、Dialog 桩在修复前应显式断言“raise ENotImplemented”（把桩钉死在雷达上）。

### T-02 【🟡】`Test_ShareCardRenderer_Portrait4x5_And_Watermark` 是"尺寸断言"，空白渲染也能通过（假测试风险）

**位置**： `D:\_Progs\02Business\DeepBase\Tests\Test.DeepBase.HB.DeepRW.pas:198-205`
```pascal
  Bmp := THbShareCardRenderer.RenderToBitmap(CardData, scfPortrait4x5);
  try
    Assert.IsNotNull(Bmp);
    Assert.AreEqual(Integer(1080), Integer(Bmp.Width));
    Assert.AreEqual(Integer(1350), Integer(Bmp.Height));
  finally
    Bmp.Free;
  end;
```
测试名含 `And_Watermark`，但 `CardData.WatermarkLocked := True`（`:191`）赋值后**无任何水印断言**；无一处像素级校验。
**触发条件**： 现状即可复现——VCL 当前实现若渲染体被意外清空（或换成 FMX 空白版 F-09），该测试依然全绿。
**建议修复**： 增加内容断言：统计非透明像素数 > 阈值、抽样角点/标题区颜色 ≠ 背景色、水印区域存在绘制痕迹；`SaveToFile` 用例校验文件非零字节且可回读。

### T-03 【🟡】边界覆盖缺口：空队列 / 特殊字符模糊搜索 / 掩码边界均无用例

**证据**（`Test.DeepBase.HB.DeepRW.pas`）：
- 搜索仅一个纯中文正常值：`:83 Palette.SearchText := '体检'`——无空串清零、无英文大小写、无 emoji/标点/正则元字符（`.*[]()`）、无超长串；
- 掩码仅一个 11 位连号手机号：`:181-182` `'13812345678' → '138********'`——无 ≤3 位（不应掩码）、无分隔符打断（`'138 1234 5678'`，见可疑区 S-01）、无 18 位身份证、无空串；
- 空队列：三个控件测试全部先填 3-4 条再断言，无“空列表下 ExecuteSelected/GetSelectedIds/ComputeStats”的零值路径用例；
- 4:5 尺寸（`:176-178` 1080×1350）已覆盖 ✓，但非法枚举回退分支无用例（见 S-03）。

**建议修复**： 按“空值 / 边界值 / 特殊字符 / 回退分支”四象限补 6-8 个用例；模糊搜索补“命中 0 条”断言。

---

## 四、🔵 低危发现

### T-04 【🔵】`run_tests.ps1` 模块别名表缺 HB——HB 回归无法定向触发

**位置**： `D:\_Progs\02Business\DeepBase\Scripts\run_tests.ps1:75-91`（`$ModuleRunMap` 有 LLM/ORM/DB/…/PERF 共 15 个别名，无 "HB"；"THEME" 仅映射 `Test.DeepBase.Theme`，不含 `Test.DeepBase.VCL.HB.Theme`）。
**触发条件**： `.\run_tests.ps1 -Module HB` 报未知模块；HB 子系统改动只能跑全量或手敲 `-Run` 全名。
**建议修复**： 增加一行：
```powershell
"HB" = "Test.DeepBase.HB.DeepRW,Test.DeepBase.HB.Suite,Test.DeepBase.HB.Tray,Test.DeepBase.HB.Voice.CF,Test.DeepBase.VCL.HB.Theme"
```
**其余逻辑复核结论**（正面）： `-CI` 与 `-SkipCompile` 互斥防陈旧可执行文件（`:58-60`）、模块过滤/覆盖率阈值/CI 集成参数齐全，未发现逻辑错误。

### F-12 【🔵】Voice 单元 4 处 W1057 隐式 AnsiString 转换警告（emoji 字面量编码隐患）

**dcc64 实测输出**： `DeepBase.FMX.HB.Voice.pas(211) / (342) / (361) / (367) Warning: W1055/W1057 Implicit string cast`——四处恰为 emoji/特殊字符字面量所在行（`:211` `'🔒 本地安全沙箱处理…'`、`:342` Format 的 `'原值: %s → …'`、`:361` `'✓'`、`:367` `'🗑️'`）。源文件 UTF-8 无 BOM，编译器按 AnsiString 解析再隐式转换。
**触发条件**： 跨平台目标（Linux/macOS）或非中文 Windows 代码页下，emoji 可能渲染成乱码/问号——FMX 层恰是跨平台层。
**建议修复**： 源文件补 UTF-8 BOM，或字面量改 `#$` 码点拼接；Cards/Terminal/Dialogs 若含同类字面量一并处理。

---

## 五、可疑区（证据不足或影响面待裁定，不计入统计）

- **S-01 掩码分隔符泄漏（Core/VCL/FMX 共享算法）**： `FMX ShareCard:64-81` 与 `VCL ShareCard:74-91` 逐行同构——非数字字符即重置计数，`'138 1234 5678'` 每段仅第 4 位起掩码，输出 `138 123* 567*`，大部分数字保留。手机号带空格/连字符书写即可绕过脱敏。属 Core 契约层缺陷，提请独立工单复核（"数字总数≥7 的混合串整体掩码"是常见策略）。
- **S-02 VCL Grid 的 0 值排除语义**： `VCL\DeepBase.VCL.HB.Grid.pas:229` `if ValFloat <> 0.0` 才计入 `NumericCount/Sum/Min/Max`——合法 0 值（金额 0、计数 0）被排除出统计。FMX 移植（F-08 修复）时勿复制；建议双胞胎统一改为显式 `Numeric(const AValue: Boolean)` 回调签名。
- **S-03 GetDimensions 未知枚举返回 True**： `FMX ShareCard:58-61`（VCL 同构 else 分支）——非法 `THbShareCardFormat` 值返回 True + 默认 1080×1080，调用方无法感知非法格式。低危，建议 else 分支返回 False。
- **S-04 ClearCommands 哨兵值**： `FMX CommandPalette:110` 清空后 `FSelectedIndex := 0`（空列表下 0 为越界哨兵；`ExecuteSelected:117` 有边界防护故不崩溃）。VCL 版同场景语义未核，建议统一为 -1。
- **S-05 SelectItem 的 toggle 语义**： `FMX VirtualList:128-131` 再次调用 SelectItem 会取消选择（Remove）。是否为有意设计未见于注释；VCL 版同名方法语义未逐行核验，列为可疑。
- **S-06 范围外提示——旧 FMX 层 Winapi 依赖**： FMX 目录中非 HB 单元 `DeepBase.FMX.Theme.pas:141`、`DeepBase.FMX.AutoUpdater.pas:154-155`、`DeepBase.FMX.Platform.pas:216-217`、`DeepBase.FMX.LogListView.pas:20` 使用 `Winapi.*`。本次受审的 18 个 HB 单元 **uses 扫描零命中 Vcl./Winapi.**（反向依赖合规 ✓）；但若 HB 单元未来复用这些旧单元会引入平台耦合，提示隔离。

---

## 六、正面确认（实测通过项）

1. **DPR 注册完整**： `D:\_Progs\02Business\DeepBase\Tests\DeepBaseTests.dpr:289-293` 五个 HB 测试单元全部注册，无漏注册。
2. **HB 18 单元反向依赖零违规**： uses 扫描无 `Vcl.*` / `Winapi.*` 命中。
3. **A 层渲染管线架构正确**： `THbFmxControl`（Controls.pas:44-63）统一主题订阅 + 状态机 + `DrawHbControl` 抽象渲染，与 VCL 版 `THbCustomControl` 的设计意图对齐。
4. **内存/生命周期无泄漏模式**： 抽查构造/析构对称——CommandPalette(:67-68/:74-75)、Gate(:66/:73)、VirtualList(:71-73/:78-80)、Grid(:61-62/:67-68)、Waterfall(:63-64/:69-70)；Voice `FTimer`(:120/:128) owned+手动 Free 各一次无双释放；ShareCard `SaveToFile` try-finally(:99-104) 正确释放位图。未发现 TBitmap/TBrush 泄漏或 FreeAndNil 误用（析构用 `.Free` 未置 nil 属风格项，销毁路径无后续引用，实际风险为零）。
5. **Voice.CF 治理测试质量高**： 纯 Core 层反事实设计（CF-VOICE-01..06），逆向断言“未确认不得入库/原子写失败零残留/草稿不复活已丢弃项”，与 UI 解耦，值得作为 FMX 移植测试的范式。
6. **dcc64 对照组编译通过**： 同参数下 Voice/Grid/ShareCard EXITCODE=0——证明 F-01 三单元失败是代码缺陷而非审计环境问题。

---

## 七、汇总统计与总体结论

| 严重级 | 数量 | 编号 |
|---|---|---|
| 🔴 | **4** | F-01, F-02, F-03, F-04 |
| 🟡 | **10** | F-05, F-06, F-07, F-08, F-09, F-10, F-11, T-01, T-02, T-03 |
| 🔵 | **2** | T-04, F-12 |
| 可疑区 | 6 项 | S-01 ~ S-06 |

**总体结论**： DeepBase HB 的 FMX “双胞胎层”目前是 4 个完整实现（Controls/Cards/Terminal/Voice+Dialogs 的 A 层渲染管线）+ 9 个数据骨架/半成品 + 3 个**连编译都无法通过**的复制粘贴残骸（Gate/CommandPalette/VirtualList 引用了 VCL 专属基类 THbCustomControl），而 14/18 单元处于无任何工程引用的编译盲区使破损长期潜伏；更危险的是 FMX 版 THbDialog/THbVoiceDialog 是恒真桩，一旦被宿主接通将静默放行全部确认流。测试侧 5 个 HB 单元全部注册且 VCL 断言质量尚可，但 FMX 侧零覆盖、渲染断言过弱、边界用例缺失——当前没有任何自动化防线能发现上述任何 🔴 问题。建议按 F-01（改基类）→ F-02（纳入编译门禁）→ F-03/F-04（桩改 raise）→ T-01（FMX 孪生测试）的顺序修复，四步完成后 FMX 层才具备“双胞胎”之名。

---

*审计证据留存：dcc64 编译输出（Gate/CommandPalette/VirtualList 失败 ×9 错误行、Voice/Grid/ShareCard 通过、Voice W1057 ×4）为 2026-08-27 实机运行结果；所有引用行号均来自当日实际读取的文件内容。*
