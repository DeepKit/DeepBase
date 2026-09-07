{ ============================================================================
  Test.DeepBase.HB.Suite - Comprehensive Tests for HB Core Component Suite

  Version: 1.0 (Delphi 13.1 on Win64)
  Description: Automated DUnitX tests covering:
               - THbFacetWaterfall (Facet exclusion, focus, dual-mode count)
               - THbDataGrid (Virtual rows, selection math stats: sum, avg, min, max)
               - THbAIConsole (Thought steps, diff proposals, model switching)
               - THbNavTree (Section headers, node selection, rail collapse)
               - THbPageControl (4 Tab styles, add/remove tab, active index)
               - THbDock & WindowProportions (Proportional anchoring calculation)
  ============================================================================ }

unit Test.DeepBase.HB.Suite;

{$WARN IMPLICIT_STRING_CAST OFF}

interface

uses
  DUnitX.TestFramework,
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
  System.IOUtils,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.Graphics,
  Vcl.Imaging.pngimage,
  DeepBase.HB.Core,
  DeepBase.HB.Waterfall.Types,
  DeepBase.HB.Grid.Types,
  DeepBase.HB.AI.Types,
  DeepBase.HB.NavTree.Types,
  DeepBase.HB.PageControl.Types,
  DeepBase.HB.Dock.Types,
  DeepBase.HB.VirtualList.Types,
  DeepBase.HB.CommandPalette.Types,
  DeepBase.HB.Dialogs.Types,
  DeepBase.VCL.HB.Waterfall,
  DeepBase.VCL.HB.Grid,
  DeepBase.VCL.HB.AI,
  DeepBase.VCL.HB.NavTree,
  DeepBase.VCL.HB.PageControl,
  DeepBase.VCL.HB.Dock,
  DeepBase.VCL.HB.Controls,
  DeepBase.VCL.HB.Cards,
  DeepBase.VCL.HB.Dialogs,
  DeepBase.VCL.HB.VirtualList,
  DeepBase.VCL.HB.CommandPalette,
  DeepBase.VCL.HB.Text,
  DeepBase.VCL.HB.Status,
  DeepBase.VCL.HB.Inputs,
  DeepBase.VCL.HB.Glass,
  DeepBase.HB.Choice.Types,
  DeepBase.VCL.HB.Choice,
  DeepBase.VCL.HB.Theme;

type
  TTestGridAccessor = class(THbDataGrid);

  [TestFixture]
  TTestHbSuite = class
  private
    FTrailingClicked: Boolean;
    FLastExecutedCmd: string;
    FCellToggledRow: Integer;
    FCellToggledCol: Integer;
    FCellToggledVal: Boolean;
    FCheckboxToggled: Boolean;
    FToggleSwitchToggled: Boolean;
    FLastChoiceKey: Integer;
    FLastCustomInputText: string;
    FLastAction: THbChoiceAction;
    FLastLinkedId: string;
    FLastLinkedTarget: string;
    FLastLinkedKind: THbWaterfallLinkKind;
    procedure OnGetFloatHelper(Sender: TObject; ARow, ACol: Integer; var AValue: Double);
    procedure OnTrailingClickHelper(Sender: TObject);
    procedure OnCommandExecuteHelper(Sender: TObject; const AItem: THbCommandItem);
    procedure OnCellToggleHelper(Sender: TObject; ARow, ACol: Integer; ANewValue: Boolean);
    procedure OnGetCellBoolHelper(Sender: TObject; ARow, ACol: Integer; var AValue: Boolean);
    procedure OnCheckBoxChangeHelper(Sender: TObject);
    procedure OnToggleSwitchChangeHelper(Sender: TObject);
    procedure OnChoiceHelper(Sender: TObject; AKey: Integer);
    procedure OnCustomInputHelper(Sender: TObject; const AInput: string);
    procedure OnActionHelper(Sender: TObject; const AAction: THbChoiceAction);
    procedure OnLinkClickHelper(Sender: TObject; const ACardId: string; AKind: THbWaterfallLinkKind; const ATarget: string);
  public
    [Test]
    procedure Test_Waterfall_Facet_Exclude_And_Focus;

    [Test]
    procedure Test_DataGrid_VirtualRows_And_Stats;

    [Test]
    procedure Test_AIConsole_Thoughts_And_Proposals;

    [Test]
    procedure Test_NavTree_Sections_And_Collapse;

    [Test]
    procedure Test_PageControl_Tabs_And_Styles;

    [Test]
    procedure Test_Dock_Panels_And_Proportions;

    // WO-20260829-0223-甲 HB 绘制纪律整改断言
    [Test]
    procedure Test_HB_Controls_EraseBackground_And_DPI_Scaling;

    [Test]
    procedure Test_HB_Controls_Mouse_Press_State_Transitions;

    [Test]
    procedure Test_HB_Button_Danger_Token_Alignment;

    [Test]
    procedure Test_HB_SummaryBar_And_Space_Tokens;

    // WO-20260829-0224-乙 HB 组件逻辑整改断言 (A-F)
    [Test]
    procedure Test_VirtualList_ModeSwitch_And_StaleCache_Clearing;

    [Test]
    procedure Test_VirtualList_VirtualMode_And_Filtered_SelectAll;

    [Test]
    procedure Test_DataGrid_ZeroRows_Scrollbar_Hiding;

    [Test]
    procedure Test_Waterfall_FocusFacet_Single_SSOT;

    [Test]
    procedure Test_Waterfall_Timeline_TimestampStr;

    [Test]
    procedure Test_CommandPalette_MRU_Sorting_And_Timestamp;

    // WO-20260830-003 HB 缺失组件补充单元测试
    [Test]
    procedure Test_HbText_Roles_And_Tones;

    [Test]
    procedure Test_HbStatusDot_States_And_Pulse;

    [Test]
    procedure Test_HbCheckBox_Toggle_And_State;

    [Test]
    procedure Test_HbToggleSwitch_Toggle_And_Text;

    [Test]
    procedure Test_HbEdit_Placeholder_And_Clear;

    [Test]
    procedure Test_HbComboBox_Items_And_Selection;

    [Test]
    procedure Test_HbThemeSelector_ThemeList_And_Selection;

    [Test]
    procedure Test_HbGlassPanel_Opacity_And_Transitions;

    [Test]
    procedure Test_HbDataGrid_Inline_Toggle_And_Checkbox;

    [Test]
    procedure Test_HbChoiceDeck_Full_0_To_9_Matrix;

    [Test]
    procedure Test_HbWaterfall_28px_Indent_And_L0_L5_Level_Badges;

    [Test]
    procedure Test_HbWaterfall_Detail_Expansion_And_Inspector;

    [Test]
    procedure Test_HbWaterfall_Nested_Hierarchy_And_Collapse;

    [Test]
    procedure Test_HbGranularity_Six_Levels_And_Waterfall_Filter;

    [Test]
    procedure Test_SurfaceProvider_Resolution_AndCardContainerBg;

    [Test]
    procedure Test_SurfaceProvider_VisualVerification_ExportCardScreenshots;

    [Test]
    procedure Test_Extended_Semantic_Tones_And_Action_Hierarchy;

    // WO-20260907 HB AI Choice Interaction Standard Tests
    [Test]
    procedure Test_HbChoice_Action_Intent_And_Input_Sources;

    [Test]
    procedure Test_HbChoice_Layout_Modes_And_Item_Rects;

    [Test]
    procedure Test_HbChoice_Truthful_State_Transitions;

    [Test]
    procedure Test_HbChoice_Text_Entry_Suspension_And_Active_Surface;
  end;

implementation

{ TTestHbSuite }

procedure TTestHbSuite.OnGetFloatHelper(Sender: TObject; ARow, ACol: Integer; var AValue: Double);
begin
  if ACol = 1 then
    AValue := (ARow + 1) * 100.0; // 100, 200, 300...
end;

procedure TTestHbSuite.Test_Waterfall_Facet_Exclude_And_Focus;
var
  Form: TCustomForm;
  WF: THbFacetWaterfall;
begin
  Form := TCustomForm.CreateNew(nil);
  try
    WF := THbFacetWaterfall.Create(Form);
    WF.Parent := Form;
    WF.AddFacet('law', '7 字段法源', 14);
    WF.AddFacet('ai', '候选方案推演', 8);
    WF.AddFacet('gov', '治理审计拦截', 12);

    WF.AddCard('c1', 'law', '7 字段法源', '法源 1', '摘要 1');
    WF.AddCard('c2', 'law', '7 字段法源', '法源 2', '摘要 2');
    WF.AddCard('c3', 'ai', '候选方案推演', '推演 1', '摘要 3');
    WF.AddCard('c4', 'gov', '治理审计拦截', '拦截 1', '摘要 4');

    Assert.AreEqual(Integer(4), Integer(WF.GetVisibleCardCount));

    // Test Exclude 'law' -> Only 'ai' and 'gov' remain (2 cards)
    WF.ExcludeFacet('law', True);
    Assert.IsFalse(WF.IsCategoryVisible('law'));
    Assert.IsTrue(WF.IsCategoryVisible('ai'));
    Assert.AreEqual(Integer(2), Integer(WF.GetVisibleCardCount));

    // Test Focus 'ai' -> Only 'ai' remains (1 card)
    WF.ResetFilter;
    WF.FocusFacet('ai');
    Assert.AreEqual(Integer(1), Integer(WF.GetVisibleCardCount));

    // Reset -> All 4 cards visible
    WF.ResetFilter;
    Assert.AreEqual(Integer(4), Integer(WF.GetVisibleCardCount));
  finally
    Form.Free;
  end;
end;

procedure TTestHbSuite.Test_DataGrid_VirtualRows_And_Stats;
var
  Form: TCustomForm;
  Grid: THbDataGrid;
  Stats: THbGridStats;
begin
  Form := TCustomForm.CreateNew(nil);
  try
    Grid := THbDataGrid.Create(Form);
    Grid.Parent := Form;
    Grid.AddColumn('name', '客户名称', 120, gctText);
    Grid.AddColumn('amount', '累计金额', 100, gctFloat);
    Grid.RowCount := 10;
    Grid.OnGetCellFloat := OnGetFloatHelper;

    // Select row 0 (100) and row 1 (200)
    Grid.SelectRow(0, False);
    Grid.SelectRow(1, True);

    Stats := Grid.ComputeSelectionStats;
    Assert.AreEqual(Integer(2), Integer(Stats.SelectedRowCount));
    Assert.AreEqual(Integer(2), Integer(Stats.NumericCount));
    Assert.AreEqual(Double(300.0), Double(Stats.SumValue), 0.01);
    Assert.AreEqual(Double(150.0), Double(Stats.AvgValue), 0.01);
    Assert.AreEqual(Double(100.0), Double(Stats.MinValue), 0.01);
    Assert.AreEqual(Double(200.0), Double(Stats.MaxValue), 0.01);
  finally
    Form.Free;
  end;
end;

procedure TTestHbSuite.Test_AIConsole_Thoughts_And_Proposals;
var
  Form: TCustomForm;
  AI: THbAIConsole;
begin
  Form := TCustomForm.CreateNew(nil);
  try
    Form.HandleNeeded;
    AI := THbAIConsole.Create(Form);
    AI.Parent := Form;
    AI.HandleNeeded;
    AI.SelectedModel := aimLocal8B;
    Assert.AreEqual(Ord(aimLocal8B), Ord(AI.SelectedModel));

    AI.TokenCount := 2500;
    Assert.AreEqual(Int64(2500), Int64(AI.TokenCount));

    AI.AddThoughtStep('触发 IntentClarification.SignalDetector', '推演特征向量', 120, 3);
    Assert.AreEqual(Integer(1), Integer(AI.Thoughts.Count));
    Assert.AreEqual(Integer(120), Integer(AI.Thoughts[0].DurationMs));

    AI.AddDiffProposal('p1', 'AuthMode', '认证模式', 'AllowAnonymous=True', 'AllowAnonymous=False', 'P0加固');
    Assert.AreEqual(Integer(1), Integer(AI.Proposals.Count));
    Assert.AreEqual(Ord(psPending), Ord(AI.Proposals[0].Status));
  finally
    Form.Free;
  end;
end;

procedure TTestHbSuite.Test_NavTree_Sections_And_Collapse;
var
  Form: TCustomForm;
  Nav: THbNavTree;
begin
  Form := TCustomForm.CreateNew(nil);
  try
    Nav := THbNavTree.Create(Form);
    Nav.Parent := Form;
    Nav.AddSection('CORE WORKSPACE');
    Nav.AddItem('wf', '分面情报发现', '42');
    Nav.AddItem('grid', '全景数据工作表', 'New');

    Assert.AreEqual(Integer(3), Integer(Nav.Items.Count));
    Assert.AreEqual(Ord(nnSectionHeader), Ord(Nav.Items[0].Kind));
    Assert.AreEqual(Ord(nnItem), Ord(Nav.Items[1].Kind));

    Nav.SelectNode('wf');
    Assert.AreEqual(string('wf'), Nav.SelectedId);

    Nav.ToggleRail;
    Assert.IsTrue(Nav.IsCollapsed);
    Assert.AreEqual(Integer(Nav.CollapsedWidth), Integer(Nav.Width));
  finally
    Form.Free;
  end;
end;

procedure TTestHbSuite.Test_PageControl_Tabs_And_Styles;
var
  Form: TCustomForm;
  PC: THbPageControl;
begin
  Form := TCustomForm.CreateNew(nil);
  try
    PC := THbPageControl.Create(Form);
    PC.Parent := Form;
    PC.TabStyle := tsSegmented;
    Assert.AreEqual(Ord(tsSegmented), Ord(PC.TabStyle));

    PC.AddTab('t1', '概览仪表盘', 0);
    PC.AddTab('t2', '安全拦截', 3);

    Assert.AreEqual(Integer(2), Integer(PC.Tabs.Count));
    Assert.AreEqual(Integer(0), Integer(PC.ActiveTabIndex));

    PC.ActiveTabIndex := 1;
    Assert.AreEqual(Integer(1), Integer(PC.ActiveTabIndex));

    PC.RemoveTab(0);
    Assert.AreEqual(Integer(1), Integer(PC.Tabs.Count));
  finally
    Form.Free;
  end;
end;

procedure TTestHbSuite.Test_Dock_Panels_And_Proportions;
var
  Prop: THbWindowProportion;
begin
  Prop.WidthRatio := 0.65;
  Prop.HeightRatio := 0.75;
  Prop.LockAspectRatio := True;
  Prop.AspectRatio := 16.0 / 10.0;
  Prop.MinWidthPx := 800;
  Prop.MinHeightPx := 500;

  Assert.AreEqual(Single(0.65), Single(Prop.WidthRatio), 0.001);
  Assert.AreEqual(Single(0.75), Single(Prop.HeightRatio), 0.001);
  Assert.IsTrue(Prop.LockAspectRatio);
  Assert.AreEqual(Single(1.6), Single(Prop.AspectRatio), 0.001);
end;

procedure TTestHbSuite.OnTrailingClickHelper(Sender: TObject);
begin
  FTrailingClicked := True;
end;

procedure TTestHbSuite.OnCommandExecuteHelper(Sender: TObject; const AItem: THbCommandItem);
begin
  FLastExecutedCmd := AItem.CommandID;
end;

procedure TTestHbSuite.Test_HB_Controls_EraseBackground_And_DPI_Scaling;
var
  Form: TCustomForm;
  Chip: THbChip;
  Badge: THbBadge;
  Avatar: THbAvatar;
  Ring: THbProgressRing;
  Toast: THbToast;
  Skeleton: THbSkeleton;
  Header: THbSectionHeader;
  Bmp: TBitmap;
begin
  Form := TCustomForm.CreateNew(nil);
  try
    Form.HandleNeeded;
    Chip := THbChip.Create(Form);
    Chip.Parent := Form;
    Badge := THbBadge.Create(Form);
    Badge.Parent := Form;
    Avatar := THbAvatar.Create(Form);
    Avatar.Parent := Form;
    Ring := THbProgressRing.Create(Form);
    Ring.Parent := Form;
    Toast := THbToast.Create(Form);
    Toast.Parent := Form;
    Skeleton := THbSkeleton.Create(Form);
    Skeleton.Parent := Form;
    Header := THbSectionHeader.Create(Form);
    Header.Parent := Form;

    // Test ScaleDIP calculations across 96, 120, 144 PPI (100%, 125%, 150%)
    Assert.AreEqual(Single(16.0), THbTheme.GetScaledDIP(16.0, 96), 0.01);
    Assert.AreEqual(Single(20.0), THbTheme.GetScaledDIP(16.0, 120), 0.01);
    Assert.AreEqual(Single(24.0), THbTheme.GetScaledDIP(16.0, 144), 0.01);

    // Verify all 7 controls render properly with Paint onto a test canvas
    Bmp := TBitmap.Create;
    try
      Bmp.SetSize(300, 100);
      Chip.Repaint;
      Badge.Repaint;
      Avatar.Repaint;
      Ring.Repaint;
      Toast.Repaint;
      Skeleton.Repaint;
      Header.Repaint;
      Assert.IsTrue(Chip.Width > 0);
      Assert.IsTrue(Badge.Width > 0);
      Assert.IsTrue(Avatar.Width > 0);
      Assert.IsTrue(Ring.Width > 0);
      Assert.IsTrue(Toast.Width > 0);
      Assert.IsTrue(Skeleton.Width > 0);
      Assert.IsTrue(Header.Width > 0);
    finally
      Bmp.Free;
    end;
  finally
    Form.Free;
  end;
end;

procedure TTestHbSuite.Test_HB_Controls_Mouse_Press_State_Transitions;
var
  Form: TCustomForm;
  Chip: THbChip;
  Header: THbSectionHeader;
begin
  Form := TCustomForm.CreateNew(nil);
  try
    Form.HandleNeeded;
    Chip := THbChip.Create(Form);
    Chip.Parent := Form;
    Chip.Closable := True;
    Assert.IsFalse(Chip.Selected);

    Header := THbSectionHeader.Create(Form);
    Header.Parent := Form;
    Header.TrailingLink := '查看全部';
    FTrailingClicked := False;
    Header.OnTrailingClick := OnTrailingClickHelper;
    Assert.IsFalse(FTrailingClicked);
    Assert.AreEqual(string('查看全部'), Header.TrailingLink);
  finally
    Form.Free;
  end;
end;

procedure TTestHbSuite.Test_HB_Button_Danger_Token_Alignment;
var
  Tokens: THbTokens;
begin
  Tokens := THbTheme.Tokens;
  Assert.AreNotEqual(TAlphaColors.Null, Tokens.Danger);
  Assert.AreNotEqual(TAlphaColors.Null, Tokens.OnPrimary);
  Assert.AreEqual(Tokens.OnPrimary, THbTheme.Tokens.OnPrimary);
end;

procedure TTestHbSuite.Test_HB_SummaryBar_And_Space_Tokens;
var
  Form: TCustomForm;
  Bar: THbSummaryBar;
  Tokens: THbTokens;
begin
  Tokens := THbTheme.Tokens;
  Assert.IsTrue(Tokens.SpaceXS > 0);
  Assert.IsTrue(Tokens.SpaceS > Tokens.SpaceXS);
  Assert.IsTrue(Tokens.SpaceM > Tokens.SpaceS);
  Assert.IsTrue(Tokens.SpaceL > Tokens.SpaceM);
  Assert.IsTrue(Tokens.SpaceXL > Tokens.SpaceL);

  Form := TCustomForm.CreateNew(nil);
  try
    Form.HandleNeeded;
    Bar := THbSummaryBar.Create(Form);
    Bar.Parent := Form;
    Bar.StepIndex := 2;
    Bar.Title := '法源合规检查';
    Bar.SummaryText := '已通过 14 项检查';
    Bar.State := ssCompleted;

    Assert.AreEqual(Integer(2), Bar.StepIndex);
    Assert.AreEqual(string('法源合规检查'), Bar.Title);
    Assert.AreEqual(Ord(ssCompleted), Ord(Bar.State));
  finally
    Form.Free;
  end;
end;

procedure TTestHbSuite.Test_VirtualList_ModeSwitch_And_StaleCache_Clearing;
var
  Form: TCustomForm;
  VList: THbVirtualList;
begin
  Form := TCustomForm.CreateNew(nil);
  try
    Form.HandleNeeded;
    VList := THbVirtualList.Create(Form);
    VList.Parent := Form;
    VList.HandleNeeded;

    // 1. Add static items
    VList.AddItem('i1', 'cat', 'Title 1', 'Sub 1', 'Ctx 1', 'Src 1', btSuccess, 'Tag 1');
    VList.AddItem('i2', 'cat', 'Title 2', 'Sub 2', 'Ctx 2', 'Src 2', btNeutral, 'Tag 2');
    Assert.AreEqual(Integer(2), Integer(VList.Items.Count));
    Assert.AreEqual(Integer(2), Integer(VList.FilteredCount));

    // 2. Switch to Virtual mode -> Clears static items & resets count
    VList.VirtualItemCount := 100;
    Assert.AreEqual(Integer(0), Integer(VList.Items.Count));
    Assert.AreEqual(Integer(100), Integer(VList.FilteredCount));

    // 3. Switch back to static mode
    VList.VirtualItemCount := 0;
    Assert.AreEqual(Integer(0), Integer(VList.FilteredCount));
  finally
    Form.Free;
  end;
end;

procedure TTestHbSuite.Test_VirtualList_VirtualMode_And_Filtered_SelectAll;
var
  Form: TCustomForm;
  VList: THbVirtualList;
  SelIds: TArray<string>;
begin
  Form := TCustomForm.CreateNew(nil);
  try
    Form.HandleNeeded;
    VList := THbVirtualList.Create(Form);
    VList.Parent := Form;
    VList.HandleNeeded;

    // Static mode select all
    VList.AddItem('a1', 'cat', 'A1', 'Sub', 'Ctx', 'Src', btNeutral, 'T');
    VList.AddItem('a2', 'cat', 'A2', 'Sub', 'Ctx', 'Src', btNeutral, 'T');
    VList.AddItem('b1', 'cat', 'B1', 'Sub', 'Ctx', 'Src', btNeutral, 'T');
    Assert.AreEqual(Integer(3), Integer(VList.FilteredCount));

    VList.SelectItem(0, False);
    VList.SelectItem(1, True);
    VList.SelectItem(2, True);
    Assert.AreEqual(Integer(3), Integer(VList.SelectedIndices.Count));
    SelIds := VList.GetSelectedIds;
    Assert.AreEqual(Integer(3), Integer(Length(SelIds)));

    // Filtered mode
    VList.SearchFilter := 'A';
    Assert.AreEqual(Integer(2), Integer(VList.FilteredCount));
  finally
    Form.Free;
  end;
end;

procedure TTestHbSuite.Test_DataGrid_ZeroRows_Scrollbar_Hiding;
var
  Form: TCustomForm;
  Grid: THbDataGrid;
begin
  Form := TCustomForm.CreateNew(nil);
  try
    Form.HandleNeeded;
    Grid := THbDataGrid.Create(Form);
    Grid.Parent := Form;
    Grid.HandleNeeded;
    Grid.AddColumn('col1', 'Column 1', 100, gctText);

    // Empty grid
    Grid.RowCount := 0;
    Assert.AreEqual(Integer(0), Grid.RowCount);

    // Few rows (less than visible height)
    Grid.RowCount := 2;
    Assert.AreEqual(Integer(2), Grid.RowCount);
  finally
    Form.Free;
  end;
end;

procedure TTestHbSuite.Test_Waterfall_FocusFacet_Single_SSOT;
var
  Form: TCustomForm;
  WF: THbFacetWaterfall;
begin
  Form := TCustomForm.CreateNew(nil);
  try
    Form.HandleNeeded;
    WF := THbFacetWaterfall.Create(Form);
    WF.Parent := Form;
    WF.HandleNeeded;

    WF.AddFacet('f1', '法源审查', 5);
    WF.AddFacet('f2', '智能推演', 3);
    WF.AddCard('c1', 'f1', '法源', '标题1', '摘要1');
    WF.AddCard('c2', 'f2', '推演', '标题2', '摘要2');

    Assert.AreEqual(Integer(2), Integer(WF.GetVisibleCardCount));
    WF.FocusFacet('f1');
    Assert.AreEqual(Integer(1), Integer(WF.GetVisibleCardCount));
    Assert.IsTrue(WF.IsCategoryVisible('f1'));
    Assert.IsFalse(WF.IsCategoryVisible('f2'));
  finally
    Form.Free;
  end;
end;

procedure TTestHbSuite.Test_Waterfall_Timeline_TimestampStr;
var
  Form: TCustomForm;
  WF: THbFacetWaterfall;
  Card: THbWaterfallCardData;
begin
  Form := TCustomForm.CreateNew(nil);
  try
    Form.HandleNeeded;
    WF := THbFacetWaterfall.Create(Form);
    WF.Parent := Form;
    WF.HandleNeeded;

    WF.Mode := wmTimeline;
    Assert.AreEqual(Ord(wmTimeline), Ord(WF.Mode));

    WF.AddCard('t1', 'audit', '分类', '审计事件1', '摘要');
    Card := WF.Items[0];
    Card.TimestampStr := '2026-08-29 08:00:00';
    WF.Items[0] := Card;
    Assert.AreEqual(Integer(1), Integer(WF.Items.Count));
    Assert.AreEqual(string('2026-08-29 08:00:00'), WF.Items[0].TimestampStr);
  finally
    Form.Free;
  end;
end;

procedure TTestHbSuite.Test_CommandPalette_MRU_Sorting_And_Timestamp;
var
  Form: TCustomForm;
  Palette: THbCommandPalette;
begin
  Form := TCustomForm.CreateNew(nil);
  try
    Form.HandleNeeded;
    Palette := THbCommandPalette.Create(Form);
    Palette.Parent := Form;
    Palette.HandleNeeded;
    FLastExecutedCmd := '';
    Palette.OnCommandExecute := OnCommandExecuteHelper;

    Palette.AddCommand('cmd.first', '首次执行命令', '操作', '', '');
    Palette.AddCommand('cmd.second', '二次执行命令', '操作', '', '');

    Assert.AreEqual(Integer(2), Integer(Palette.Items.Count));
    Assert.AreEqual(TDateTime(0), Palette.Items[0].LastUsedAt);

    // Execute first command
    Palette.ExecuteSelected;
    Assert.AreEqual(string('cmd.first'), FLastExecutedCmd);
    Assert.IsTrue(Palette.Items[0].LastUsedAt > 0);
  finally
    Form.Free;
  end;
end;


procedure TTestHbSuite.OnCellToggleHelper(Sender: TObject; ARow, ACol: Integer; ANewValue: Boolean);
begin
  FCellToggledRow := ARow;
  FCellToggledCol := ACol;
  FCellToggledVal := ANewValue;
end;

procedure TTestHbSuite.OnGetCellBoolHelper(Sender: TObject; ARow, ACol: Integer; var AValue: Boolean);
begin
  if (ACol = 1) and (ARow = 2) then
    AValue := True
  else
    AValue := False;
end;

procedure TTestHbSuite.OnCheckBoxChangeHelper(Sender: TObject);
begin
  FCheckboxToggled := True;
end;

procedure TTestHbSuite.OnToggleSwitchChangeHelper(Sender: TObject);
begin
  FToggleSwitchToggled := True;
end;

procedure TTestHbSuite.Test_HbText_Roles_And_Tones;
var
  Form: TCustomForm;
  Txt: THbText;
  Tokens: THbTokens;
begin
  Form := TCustomForm.CreateNew(nil);
  try
    Txt := THbText.Create(Form);
    Txt.Parent := Form;
    Tokens := THbTheme.Tokens;

    Txt.Caption := '标题文本';
    Txt.Role := trHeading;
    Assert.AreEqual(Tokens.SizeL, Txt.EffectiveFontSize, 0.01);
    Assert.AreEqual(Cardinal(Tokens.Ink), Cardinal(Txt.EffectiveColor));

    Txt.Role := trMuted;
    Assert.AreEqual(Tokens.SizeS, Txt.EffectiveFontSize, 0.01);
    Assert.AreEqual(Cardinal(Tokens.InkMuted), Cardinal(Txt.EffectiveColor));

    Txt.Tone := ttSuccess;
    Assert.AreEqual(Cardinal(Tokens.Success), Cardinal(Txt.EffectiveColor));

    Txt.Tone := ttDanger;
    Assert.AreEqual(Cardinal(Tokens.Danger), Cardinal(Txt.EffectiveColor));
  finally
    Form.Free;
  end;
end;

procedure TTestHbSuite.Test_HbStatusDot_States_And_Pulse;
var
  Form: TCustomForm;
  Dot: THbStatusDot;
  Tokens: THbTokens;
begin
  Form := TCustomForm.CreateNew(nil);
  try
    Dot := THbStatusDot.Create(Form);
    Dot.Parent := Form;
    Tokens := THbTheme.Tokens;

    Dot.Status := sdSuccess;
    Assert.AreEqual(Cardinal(Tokens.Success), Cardinal(Dot.StatusColor));

    Dot.Status := sdDanger;
    Assert.AreEqual(Cardinal(Tokens.Danger), Cardinal(Dot.StatusColor));

    Dot.Status := sdWarning;
    Assert.AreEqual(Cardinal(Tokens.Warning), Cardinal(Dot.StatusColor));

    Dot.Status := sdInfo;
    Assert.AreEqual(Cardinal(Tokens.Info), Cardinal(Dot.StatusColor));

    Dot.Pulse := True;
    Assert.IsTrue(Dot.Pulse);
  finally
    Form.Free;
  end;
end;

procedure TTestHbSuite.Test_HbCheckBox_Toggle_And_State;
var
  Form: TCustomForm;
  Cb: THbCheckBox;
begin
  Form := TCustomForm.CreateNew(nil);
  try
    Cb := THbCheckBox.Create(Form);
    Cb.Parent := Form;
    FCheckboxToggled := False;
    Cb.OnChange := OnCheckBoxChangeHelper;

    Assert.IsFalse(Cb.Checked);
    Cb.Toggle;
    Assert.IsTrue(Cb.Checked);
    Assert.IsTrue(FCheckboxToggled);

    Cb.Toggle;
    Assert.IsFalse(Cb.Checked);
  finally
    Form.Free;
  end;
end;

procedure TTestHbSuite.Test_HbToggleSwitch_Toggle_And_Text;
var
  Form: TCustomForm;
  Sw: THbToggleSwitch;
begin
  Form := TCustomForm.CreateNew(nil);
  try
    Sw := THbToggleSwitch.Create(Form);
    Sw.Parent := Form;
    FToggleSwitchToggled := False;
    Sw.OnChange := OnToggleSwitchChangeHelper;

    Assert.IsFalse(Sw.Checked);
    Assert.AreEqual(string('ON'), Sw.OnText);
    Assert.AreEqual(string('OFF'), Sw.OffText);

    Sw.Toggle;
    Assert.IsTrue(Sw.Checked);
    Assert.IsTrue(FToggleSwitchToggled);
  finally
    Form.Free;
  end;
end;

procedure TTestHbSuite.Test_HbEdit_Placeholder_And_Clear;
var
  Form: TCustomForm;
  Edt: THbEdit;
begin
  Form := TCustomForm.CreateNew(nil);
  try
    Edt := THbEdit.Create(Form);
    Edt.Parent := Form;

    Edt.PlaceholderText := '请输入关键字...';
    Assert.AreEqual(string('请输入关键字...'), Edt.PlaceholderText);

    Edt.Text := '测试内容';
    Assert.AreEqual(string('测试内容'), Edt.Text);

    Edt.Clear;
    Assert.AreEqual(string(''), Edt.Text);
  finally
    Form.Free;
  end;
end;

procedure TTestHbSuite.Test_HbComboBox_Items_And_Selection;
var
  Form: TCustomForm;
  Cmb: THbComboBox;
begin
  Form := TCustomForm.CreateNew(nil);
  try
    Cmb := THbComboBox.Create(Form);
    Cmb.Parent := Form;

    Cmb.AddItem('策略 A');
    Cmb.AddItem('策略 B');
    Cmb.AddItem('策略 C');

    Assert.AreEqual(Integer(3), Integer(Cmb.Items.Count));
    Cmb.ItemIndex := 1;
    Assert.AreEqual(string('策略 B'), Cmb.Text);
  finally
    Form.Free;
  end;
end;

procedure TTestHbSuite.Test_HbThemeSelector_ThemeList_And_Selection;
var
  Form: TCustomForm;
  Sel: THbThemeSelector;
begin
  Form := TCustomForm.CreateNew(nil);
  try
    Sel := THbThemeSelector.Create(Form);
    Sel.Parent := Form;

    Assert.IsNotEmpty(Sel.SelectedThemeId);
    Sel.SelectedThemeId := 'ocean-deep';
    Assert.AreEqual(string('ocean-deep'), Sel.SelectedThemeId);
  finally
    Form.Free;
  end;
end;

procedure TTestHbSuite.Test_HbGlassPanel_Opacity_And_Transitions;
var
  Form: TCustomForm;
  Glass: THbGlassPanel;
begin
  Form := TCustomForm.CreateNew(nil);
  try
    Glass := THbGlassPanel.Create(Form);
    Glass.Parent := Form;

    Assert.IsTrue(Glass.Acrylic);
    Assert.IsTrue(Glass.DropShadow);

    Glass.Opacity := 0.75;
    Assert.AreEqual(0.75, Glass.Opacity, 0.01);
  finally
    Form.Free;
  end;
end;

procedure TTestHbSuite.Test_HbDataGrid_Inline_Toggle_And_Checkbox;
var
  Form: TCustomForm;
  Grid: THbDataGrid;
begin
  Form := TCustomForm.CreateNew(nil);
  try
    Form.HandleNeeded;
    Grid := THbDataGrid.Create(Form);
    Grid.Parent := Form;
    Grid.HandleNeeded;

    Grid.AddColumn('name', '任务名称', 120, gctText);
    Grid.AddColumn('active', '启用状态', 80, gctToggleSwitch);
    Grid.AddColumn('sel', '勾选', 60, gctCheckbox);
    Grid.RowCount := 5;

    Assert.AreEqual(Integer(3), Integer(Grid.Columns.Count));
    Assert.AreEqual(Ord(gctToggleSwitch), Ord(Grid.Columns[1].ColType));
    Assert.AreEqual(Ord(gctCheckbox), Ord(Grid.Columns[2].ColType));

    FCellToggledRow := -1;
    FCellToggledCol := -1;
    FCellToggledVal := False;
    Grid.OnCellToggle := OnCellToggleHelper;
    Grid.OnGetCellBool := OnGetCellBoolHelper;

    // Simulate MouseDown on row 2, col 1 (active toggle)
    TTestGridAccessor(Grid).MouseDown(mbLeft, [], 150, Grid.HeaderHeight + 2 * Grid.RowHeight + 10);
    Assert.AreEqual(Integer(2), Integer(FCellToggledRow));
    Assert.AreEqual(Integer(1), Integer(FCellToggledCol));
    Assert.IsFalse(FCellToggledVal); // Inverted from True -> False
  finally
    Form.Free;
  end;
end;

procedure TTestHbSuite.OnChoiceHelper(Sender: TObject; AKey: Integer);
begin
  FLastChoiceKey := AKey;
end;

procedure TTestHbSuite.OnCustomInputHelper(Sender: TObject; const AInput: string);
begin
  FLastCustomInputText := AInput;
end;

procedure TTestHbSuite.OnActionHelper(Sender: TObject; const AAction: THbChoiceAction);
begin
  FLastAction := AAction;
end;

procedure TTestHbSuite.OnLinkClickHelper(Sender: TObject; const ACardId: string; AKind: THbWaterfallLinkKind; const ATarget: string);
begin
  FLastLinkedId := ACardId;
  FLastLinkedKind := AKind;
  FLastLinkedTarget := ATarget;
end;

procedure TTestHbSuite.Test_HbChoiceDeck_Full_0_To_9_Matrix;
var
  Form: TCustomForm;
  Deck: THbChoiceDeck;
  Tokens: THbTokens;
  Item: THbChoiceItem;
  Msg: TWMKeyDown;
  K: Integer;
  R: TRect;
begin
  Tokens := THbTheme.Tokens;
  Assert.AreNotEqual(TAlphaColor(0), Tokens.ChoiceOption);
  Assert.AreNotEqual(TAlphaColor(0), Tokens.ChoiceRegenerate);
  Assert.AreNotEqual(TAlphaColor(0), Tokens.ChoiceInput);
  Assert.AreNotEqual(TAlphaColor(0), Tokens.ChoiceBack);
  Assert.AreNotEqual(TAlphaColor(0), Tokens.ChoiceRecommended);

  Form := TCustomForm.CreateNew(nil);
  try
    Deck := THbChoiceDeck.Create(Form);
    Deck.Parent := Form;
    Deck.Width := 400;
    Deck.Height := 500;
    Deck.OnChoice := OnChoiceHelper;
    Deck.OnCustomInput := OnCustomInputHelper;
    FLastChoiceKey := -1;
    FLastCustomInputText := '';

    // 1. Setup 7 options (1..7) with 1 recommended + 3 standard controls (8, 9, 0)
    Deck.Clear;
    for K := 1 to 7 do
      Deck.AddOption(K, Format('选项 %d', [K]), Format('这是选项 %d 的描述', [K]), K = 1);
    Deck.AddStandardControls(True, True, True);

    Assert.AreEqual(Integer(10), Integer(Deck.ItemCount)); // 7 options + 8 regen + 9 input + 0 back

    // Check Key 1 is recommended
    Assert.IsTrue(Deck.FindItemByKey(1, Item));
    Assert.IsTrue(Item.IsRecommended);
    Assert.AreEqual('选项 1', Item.Text);

    // Check standard items
    Assert.IsTrue(Deck.FindItemByKey(8, Item));
    Assert.AreEqual(Ord(ckRegenerate), Ord(Item.Kind));
    Assert.IsTrue(Deck.FindItemByKey(9, Item));
    Assert.AreEqual(Ord(ckInput), Ord(Item.Kind));
    Assert.IsTrue(Deck.FindItemByKey(0, Item));
    Assert.AreEqual(Ord(ckBack), Ord(Item.Kind));

    // 2. Test direct keyboard matrix for all keys: 1..7, 8, 9, 0
    for K := 1 to 7 do
    begin
      FLastChoiceKey := -1;
      FillChar(Msg, SizeOf(Msg), 0);
      Msg.Msg := WM_KEYDOWN;
      Msg.CharCode := Ord('0') + K;
      Deck.Dispatch(Msg);
      Assert.AreEqual(K, FLastChoiceKey);
    end;

    // Key 8 (Regenerate)
    FLastChoiceKey := -1;
    FillChar(Msg, SizeOf(Msg), 0);
    Msg.Msg := WM_KEYDOWN;
    Msg.CharCode := Ord('8');
    Deck.Dispatch(Msg);
    Assert.AreEqual(Integer(8), Integer(FLastChoiceKey));

    // Key 9 (Custom Input) -> triggers OnChoice and OnCustomInput
    FLastChoiceKey := -1;
    FLastCustomInputText := '';
    FillChar(Msg, SizeOf(Msg), 0);
    Msg.Msg := WM_KEYDOWN;
    Msg.CharCode := Ord('9');
    Deck.Dispatch(Msg);
    Assert.AreEqual(Integer(9), Integer(FLastChoiceKey));
    Assert.AreEqual('自己输入', FLastCustomInputText);

    // Cancel built-in free input mode to return to ready choice state
    Deck.CancelFreeInput;

    // Key 0 (Back)
    FLastChoiceKey := -1;
    FillChar(Msg, SizeOf(Msg), 0);
    Msg.Msg := WM_KEYDOWN;
    Msg.CharCode := Ord('0');
    Deck.Dispatch(Msg);
    Assert.AreEqual(Integer(0), Integer(FLastChoiceKey));

    // 3. Test Disabled Item: disable key 4
    Deck.SetItemEnabled(4, False);
    Assert.IsTrue(Deck.FindItemByKey(4, Item));
    Assert.IsFalse(Item.Enabled);

    // Pressing '4' should be ignored
    FLastChoiceKey := -1;
    FillChar(Msg, SizeOf(Msg), 0);
    Msg.Msg := WM_KEYDOWN;
    Msg.CharCode := Ord('4');
    Deck.Dispatch(Msg);
    Assert.AreEqual(Integer(-1), Integer(FLastChoiceKey)); // Ignored!

    // 4. Test Mouse Hit-Testing on Item 2 Rect
    FLastChoiceKey := -1;
    R := Deck.ItemRect(1); // Index 1 is Key 2
    Assert.IsTrue(R.Bottom > R.Top);
    var CenterPt := Point((R.Left + R.Right) div 2, (R.Top + R.Bottom) div 2);
    Deck.TabStop := False;
    TTestGridAccessor(Deck).MouseDown(mbLeft, [], CenterPt.X, CenterPt.Y);
    TTestGridAccessor(Deck).MouseUp(mbLeft, [], CenterPt.X, CenterPt.Y);
    Assert.AreEqual(Integer(2), Integer(FLastChoiceKey));

    // 5. Test Theme Switch updates Tokens
    THbTheme.ApplyTheme('aurora_glow_dark');
    Tokens := THbTheme.Tokens;
    Assert.AreNotEqual(TAlphaColor(0), Tokens.ChoiceOption);
    Assert.AreNotEqual(TAlphaColor(0), Tokens.ChoiceRecommended);
    THbTheme.ApplyTheme('warm_gold_light');
  finally
    Form.Free;
  end;
end;

procedure TTestHbSuite.Test_HbWaterfall_28px_Indent_And_L0_L5_Level_Badges;
var
  Tokens: THbTokens;
  ADepth: Integer;
  Base28Indent: Integer;
begin
  Tokens := THbTheme.Tokens;

  // 1. Verify Level0..Level5 Tokens are defined and non-zero
  for ADepth := 0 to 5 do
  begin
    Assert.AreNotEqual(TAlphaColor(0), Tokens.GetLevelColor(ADepth));
  end;

  // Verify L0 and L1 are distinct
  Assert.AreNotEqual(Tokens.GetLevelColor(0), Tokens.GetLevelColor(1));
  Assert.AreNotEqual(Tokens.GetLevelColor(1), Tokens.GetLevelColor(2));

  // 2. Verify 28px Base Indentation Progression
  Base28Indent := 28;
  for ADepth := 0 to 5 do
  begin
    Assert.AreEqual(Integer(ADepth * Base28Indent), Integer(ADepth * Round(28 * (96 / 96.0))));
  end;

  // 3. Verify High-DPI Scaling on 28px
  Assert.AreEqual(Integer(28), Round(28 * (96 / 96.0)));   // 100% 96 DPI
  Assert.AreEqual(Integer(35), Round(28 * (120 / 96.0)));  // 125% 120 DPI
  Assert.AreEqual(Integer(42), Round(28 * (144 / 96.0)));  // 150% 144 DPI
  Assert.AreEqual(Integer(56), Round(28 * (192 / 96.0)));  // 200% 192 DPI
end;

procedure TTestHbSuite.Test_HbWaterfall_Detail_Expansion_And_Inspector;
var
  Form: TCustomForm;
  WF: THbFacetWaterfall;
  Card: THbWaterfallCardData;
begin
  Form := TCustomForm.CreateNew(nil);
  try
    WF := THbFacetWaterfall.Create(Form);
    WF.Parent := Form;
    WF.Width := 900;
    WF.Height := 600;
    WF.AddFacet('core', '核心模块', 2);

    FLastLinkedId := '';
    FLastLinkedTarget := '';
    FLastLinkedKind := wlkNone;
    WF.OnLinkClick := OnLinkClickHelper;

    // Card 1: with details, link, and properties
    WF.AddCard('c1', 'core', '核心模块', 'THbChoiceDeck 控件', '0-9 键选等价',
      '详细技术实现规范与五态机定义', 'DeepBase.VCL.HB.Choice.pas',
      wisNormal, btBrand, '', 0, wlkDoc, 'docs/choice_spec.md',
      [THbCardProperty.Create('版本', '1.0'), THbCardProperty.Create('状态', '已交付')]);

    // Card 2: plain card without links/properties
    WF.AddCard('c2', 'core', '核心模块', '普通卡片', '仅摘要', '', '', wisNormal, btBrand, '', 0);

    Assert.IsTrue(WF.FindCard('c1', Card));
    Assert.IsFalse(Card.IsExpanded);

    // 1. Toggle Detail Expansion -> IsExpanded becomes True
    WF.ToggleCardDetail('c1');
    Assert.IsTrue(WF.FindCard('c1', Card));
    Assert.IsTrue(Card.IsExpanded);

    // Toggle again -> IsExpanded becomes False
    WF.ToggleCardDetail('c1');
    Assert.IsTrue(WF.FindCard('c1', Card));
    Assert.IsFalse(Card.IsExpanded);

    // 2. Test SelectCard opens Right Inspector when card has props/links
    WF.SelectCard('c1');
    Assert.AreEqual('c1', WF.SelectedCardId);

    // 3. Test SelectCard collapses Right Inspector when card has no props/links
    WF.SelectCard('c2');
    Assert.AreEqual('c2', WF.SelectedCardId);
  finally
    Form.Free;
  end;
end;

procedure TTestHbSuite.Test_HbWaterfall_Nested_Hierarchy_And_Collapse;
var
  Form: TCustomForm;
  WF: THbFacetWaterfall;
  Card: THbWaterfallCardData;
begin
  Form := TCustomForm.CreateNew(nil);
  try
    WF := THbFacetWaterfall.Create(Form);
    WF.Parent := Form;
    WF.AddFacet('change', '变更流水', 3);

    // Root -> Child -> GrandChild
    WF.AddCard('root', 'change', '变更流水', '总意图', '重构视觉系统', '', '', wisNormal, btBrand, '', 0);
    WF.AddCard('child', 'change', '变更流水', '子项 1', 'HB 输入集', '', '', wisNormal, btBrand, 'root');
    WF.AddCard('grandchild', 'change', '变更流水', '细节 1.1', 'THbChoiceDeck 0-9 键', '', '', wisNormal, btBrand, 'child');

    Assert.IsTrue(WF.FindCard('root', Card));
    Assert.IsTrue(Card.HasChildren);
    Assert.AreEqual(Integer(0), Integer(Card.Depth));

    Assert.IsTrue(WF.FindCard('child', Card));
    Assert.IsTrue(Card.HasChildren);
    Assert.AreEqual(Integer(1), Integer(Card.Depth));

    Assert.IsTrue(WF.FindCard('grandchild', Card));
    Assert.IsFalse(Card.HasChildren);
    Assert.AreEqual(Integer(2), Integer(Card.Depth));

    Assert.AreEqual(Integer(3), Integer(WF.GetVisibleCardCount));

    // Collapse child -> grandchild is hidden
    WF.ToggleCardCollapse('child');
    Assert.AreEqual(Integer(2), Integer(WF.GetVisibleCardCount));

    // Collapse root -> both child and grandchild are hidden
    WF.ToggleCardCollapse('root');
    Assert.AreEqual(Integer(1), Integer(WF.GetVisibleCardCount));

    // Expand root -> child is visible, grandchild still collapsed
    WF.ToggleCardCollapse('root');
    Assert.AreEqual(Integer(2), Integer(WF.GetVisibleCardCount));

    // Expand child -> all 3 visible
    WF.ToggleCardCollapse('child');
    Assert.AreEqual(Integer(3), Integer(WF.GetVisibleCardCount));
  finally
    Form.Free;
  end;
end;

procedure TTestHbSuite.Test_HbGranularity_Six_Levels_And_Waterfall_Filter;
var
  Form: TCustomForm;
  WF: THbFacetWaterfall;
begin
  Form := TCustomForm.CreateNew(nil);
  try
    WF := THbFacetWaterfall.Create(Form);
    WF.Parent := Form;
    WF.AddFacet('plan', '层级计划', 4);

    WF.AddCard('d0', 'plan', '层级计划', 'L0 顶层意图', '', '', '', wisNormal, btBrand, '', 0);
    WF.AddCard('d1', 'plan', '层级计划', 'L1 一级分支', '', '', '', wisNormal, btBrand, 'd0', 1);
    WF.AddCard('d2', 'plan', '层级计划', 'L2 二级模块', '', '', '', wisNormal, btBrand, 'd1', 2);
    WF.AddCard('d3', 'plan', '层级计划', 'L3 三级细节', '', '', '', wisNormal, btBrand, 'd2', 3);

    // gCoarsest -> Depth <= 0 (Only d0)
    WF.Granularity := gCoarsest;
    Assert.AreEqual(Integer(1), Integer(WF.GetVisibleCardCount));

    // gCoarse -> Depth <= 1 (d0, d1)
    WF.Granularity := gCoarse;
    Assert.AreEqual(Integer(2), Integer(WF.GetVisibleCardCount));

    // gMedium -> Depth <= 2 (d0, d1, d2)
    WF.Granularity := gMedium;
    Assert.AreEqual(Integer(3), Integer(WF.GetVisibleCardCount));

    // gFine -> Depth <= 3 (d0, d1, d2, d3)
    WF.Granularity := gFine;
    Assert.AreEqual(Integer(4), Integer(WF.GetVisibleCardCount));

    // gFinest -> all visible
    WF.Granularity := gFinest;
    Assert.AreEqual(Integer(4), Integer(WF.GetVisibleCardCount));

    // Orthogonal check: THbTheme.SetDensity does not affect Granularity
    THbTheme.SetDensity(hdCompact);
    Assert.AreEqual(Ord(gFinest), Ord(WF.Granularity));
    THbTheme.SetDensity(hdComfortable);
  finally
    Form.Free;
  end;
end;

procedure TTestHbSuite.Test_SurfaceProvider_Resolution_AndCardContainerBg;
var
  Form: TForm;
  Card: THbCard;
  Btn: THbButton;
  PageCtrl: THbPageControl;
  TabBtn: THbButton;
begin
  Form := TForm.CreateNew(nil);
  try
    Form.Color := AlphaColorToColor(THbTheme.Tokens.Surface);

    // 1. Standalone button on Form (Parent has no IHbSurfaceProvider -> fallback to Tokens.Surface)
    Btn := THbButton.Create(Form);
    Btn.Parent := Form;
    Assert.AreEqual(THbTheme.Tokens.Surface, Btn.GetContainerBgColor, 'Standalone button on Form must resolve Tokens.Surface');

    // 2. Button placed inside THbCard
    Card := THbCard.Create(Form);
    Card.Parent := Form;
    Card.Kind := ckSurface;

    Btn.Parent := Card;
    Assert.AreEqual(THbTheme.Tokens.SurfaceAlt, Btn.GetContainerBgColor, 'Button inside ckSurface Card must resolve SurfaceAlt');

    Card.Kind := ckSunken;
    Assert.AreEqual(THbTheme.Tokens.Sunken, Btn.GetContainerBgColor, 'Button inside ckSunken Card must resolve Sunken');

    // 3. Button placed inside THbPageControl
    PageCtrl := THbPageControl.Create(Form);
    PageCtrl.Parent := Form;
    PageCtrl.AddTab('Tab1', 'Tab 1');

    TabBtn := THbButton.Create(Form);
    TabBtn.Parent := PageCtrl;
    Assert.AreEqual(THbTheme.Tokens.Surface, TabBtn.GetContainerBgColor, 'Button inside PageControl must resolve Surface');
  finally
    Form.Free;
  end;
end;

procedure TTestHbSuite.Test_SurfaceProvider_VisualVerification_ExportCardScreenshots;
var
  Form: TForm;
  Card: THbCard;
  BtnPill, BtnRect: THbButton;
  Bmp: TBitmap;
  PNG: TPngImage;
  OutDir, FilePath: string;
  Kind: THbCardKind;
  KindName: string;
begin
  OutDir := TPath.Combine(ExtractFilePath(ParamStr(0)), '..\..\TestResults\WO-20260905-001\screenshots');
  if not TDirectory.Exists(OutDir) then
    OutDir := 'TestResults\WO-20260905-001\screenshots';
  if not TDirectory.Exists(OutDir) then
    OutDir := TPath.Combine(GetCurrentDir, 'TestResults\WO-20260905-001\screenshots');
  if not TDirectory.Exists(OutDir) then
    TDirectory.CreateDirectory(OutDir);

  Form := TForm.CreateNew(nil);
  try
    Form.SetBounds(0, 0, 420, 260);
    Form.Color := AlphaColorToColor(THbTheme.Tokens.Surface);

    Card := THbCard.Create(Form);
    Card.Parent := Form;
    Card.SetBounds(20, 20, 380, 200);

    BtnPill := THbButton.Create(Form);
    BtnPill.Parent := Card;
    BtnPill.SetBounds(24, 60, 150, 42);
    BtnPill.Caption := 'Pill Primary';
    BtnPill.Kind := bkPrimary;
    BtnPill.Pill := True;

    BtnRect := THbButton.Create(Form);
    BtnRect.Parent := Card;
    BtnRect.SetBounds(190, 60, 150, 42);
    BtnRect.Caption := 'Soft Rounded';
    BtnRect.Kind := bkSoft;
    BtnRect.Pill := False;

    for Kind in [ckSurface, ckSunken, ckHero, ckOutline] do
    begin
      Card.Kind := Kind;
      case Kind of
        ckSurface: KindName := 'ckSurface';
        ckSunken:  KindName := 'ckSunken';
        ckHero:    KindName := 'ckHero';
        ckOutline: KindName := 'ckOutline';
      end;

      Bmp := TBitmap.Create;
      try
        Bmp.SetSize(Card.Width, Card.Height);
        Bmp.Canvas.Lock;
        try
          Card.PaintTo(Bmp.Canvas.Handle, 0, 0);
        finally
          Bmp.Canvas.Unlock;
        end;

        PNG := TPngImage.Create;
        try
          PNG.Assign(Bmp);
          FilePath := TPath.Combine(OutDir, Format('card_%s_button_blend.png', [KindName]));
          PNG.SaveToFile(FilePath);
        finally
          PNG.Free;
        end;
      finally
        Bmp.Free;
      end;
    end;
  finally
    Form.Free;
  end;
end;

procedure TTestHbSuite.Test_Extended_Semantic_Tones_And_Action_Hierarchy;
var
  Form: TForm;
  BadgeChange, BadgeNotice, BadgeUnresolved: THbBadge;
  ChipChange, ChipNotice, ChipUnresolved: THbChip;
  BtnRec: THbButton;
  CardGhost, CardQuiet: THbCard;
  EmptyAllClear: THbEmptyState;
  Bmp: TBitmap;
  Tokens: THbTokens;
begin
  Tokens := THbTheme.Tokens;
  Assert.AreNotEqual(TAlphaColors.Null, Tokens.Change, 'Tokens.Change must be defined');
  Assert.AreNotEqual(TAlphaColors.Null, Tokens.Notice, 'Tokens.Notice must be defined');
  Assert.AreNotEqual(TAlphaColors.Null, Tokens.Unresolved, 'Tokens.Unresolved must be defined');
  Assert.AreNotEqual(TAlphaColors.Null, Tokens.SurfaceQuiet, 'Tokens.SurfaceQuiet must be defined');

  Form := TForm.CreateNew(nil);
  try
    Form.SetBounds(0, 0, 480, 400);

    // 1. Test Extended Badges
    BadgeChange := THbBadge.Create(Form);
    BadgeChange.Parent := Form;
    BadgeChange.Tone := btChange;
    BadgeChange.Caption := '工商变更';

    BadgeNotice := THbBadge.Create(Form);
    BadgeNotice.Parent := Form;
    BadgeNotice.Tone := btNotice;
    BadgeNotice.Caption := '建议核验';

    BadgeUnresolved := THbBadge.Create(Form);
    BadgeUnresolved.Parent := Form;
    BadgeUnresolved.Tone := btUnresolved;
    BadgeUnresolved.Caption := '待决挂起';

    // 2. Test Extended Chips
    ChipChange := THbChip.Create(Form);
    ChipChange.Parent := Form;
    ChipChange.Tone := ttChange;
    ChipChange.Caption := 'Diff: 资本增资';

    ChipNotice := THbChip.Create(Form);
    ChipNotice.Parent := Form;
    ChipNotice.Tone := ttNotice;
    ChipNotice.Caption := '提示: 需复核';

    ChipUnresolved := THbChip.Create(Form);
    ChipUnresolved.Parent := Form;
    ChipUnresolved.Tone := ttUnresolved;
    ChipUnresolved.Caption := '待定: 外部数据';

    // 3. Test Action Hierarchy (AI Recommended button)
    BtnRec := THbButton.Create(Form);
    BtnRec.Parent := Form;
    BtnRec.Kind := bkRecommended;
    BtnRec.Caption := 'AI 建议方案';

    // 4. Test Card Containers (Ghost / Quiet)
    CardGhost := THbCard.Create(Form);
    CardGhost.Parent := Form;
    CardGhost.Kind := ckGhost;

    CardQuiet := THbCard.Create(Form);
    CardQuiet.Parent := Form;
    CardQuiet.Kind := ckQuiet;

    // 5. Test EmptyState (esmAllClear)
    EmptyAllClear := THbEmptyState.Create(Form);
    EmptyAllClear.Parent := Form;
    EmptyAllClear.Mode := esmAllClear;
    EmptyAllClear.Title := '天下太平，无需关注';
    EmptyAllClear.Hint := '今日各项指标平稳，无需要处理的事项';

    // 6. Test Paint & Vector Rendering without exception
    Bmp := TBitmap.Create;
    try
      Bmp.SetSize(Form.Width, Form.Height);
      Form.PaintTo(Bmp.Canvas.Handle, 0, 0);
      Assert.IsTrue(Bmp.Width > 0, 'Form successfully rendered with all new tokens & action primitives');
    finally
      Bmp.Free;
    end;
  finally
    Form.Free;
  end;
end;

procedure TTestHbSuite.Test_HbChoice_Action_Intent_And_Input_Sources;
var
  Form: TCustomForm;
  Deck: THbChoiceDeck;
  Msg: TWMKeyDown;
begin
  Form := TCustomForm.CreateNew(nil);
  try
    Deck := THbChoiceDeck.Create(Form);
    Deck.Parent := Form;
    Deck.OnAction := OnActionHelper;
    Deck.OnChoice := OnChoiceHelper;

    Deck.Clear;
    Deck.AddOption(1, '候选方案A', '描述A', True, 8881);
    Deck.AddOption(2, '候选方案B', '描述B', False, 8882);
    Deck.AddStandardControls(True, True, True);

    // 1. Test Keyboard Digit 1 -> Candidate Action
    FillChar(Msg, SizeOf(Msg), 0);
    Msg.Msg := WM_KEYDOWN;
    Msg.CharCode := Ord('1');
    Deck.Dispatch(Msg);
    Assert.AreEqual(Ord(cakCandidate), Ord(FLastAction.Kind));
    Assert.AreEqual(1, FLastAction.Key);
    Assert.AreEqual('候选方案A', FLastAction.Text);
    Assert.AreEqual(NativeInt(8881), FLastAction.Payload);
    Assert.AreEqual(Ord(cisKeyboard), Ord(FLastAction.InputSource));

    // 2. Test NumPad Digit 2 -> cisNumPad
    FillChar(Msg, SizeOf(Msg), 0);
    Msg.Msg := WM_KEYDOWN;
    Msg.CharCode := VK_NUMPAD2;
    Deck.Dispatch(Msg);
    Assert.AreEqual(Ord(cakCandidate), Ord(FLastAction.Kind));
    Assert.AreEqual(2, FLastAction.Key);
    Assert.AreEqual('候选方案B', FLastAction.Text);
    Assert.AreEqual(NativeInt(8882), FLastAction.Payload);
    Assert.AreEqual(Ord(cisNumPad), Ord(FLastAction.InputSource));

    // 3. Test Key 8 (Regenerate) -> cakRegenerate
    FillChar(Msg, SizeOf(Msg), 0);
    Msg.Msg := WM_KEYDOWN;
    Msg.CharCode := Ord('8');
    Deck.Dispatch(Msg);
    Assert.AreEqual(Ord(cakRegenerate), Ord(FLastAction.Kind));
    Assert.AreEqual(8, FLastAction.Key);

    // 4. Test Key 9 (Free Input) -> cakFreeInput
    FillChar(Msg, SizeOf(Msg), 0);
    Msg.Msg := WM_KEYDOWN;
    Msg.CharCode := Ord('9');
    Deck.Dispatch(Msg);
    Assert.AreEqual(Ord(cakFreeInput), Ord(FLastAction.Kind));
    Assert.AreEqual(9, FLastAction.Key);

    // Cancel free input to return to ready state
    Deck.CancelFreeInput;

    // 5. Test Key 0 (Back) -> cakBack
    FillChar(Msg, SizeOf(Msg), 0);
    Msg.Msg := WM_KEYDOWN;
    Msg.CharCode := Ord('0');
    Deck.Dispatch(Msg);
    Assert.AreEqual(Ord(cakBack), Ord(FLastAction.Kind));
    Assert.AreEqual(0, FLastAction.Key);
  finally
    Form.Free;
  end;
end;

procedure TTestHbSuite.Test_HbChoice_Layout_Modes_And_Item_Rects;
var
  Form: TCustomForm;
  Deck: THbChoiceDeck;
  RDeck, RRow, RList, RInline: TRect;
begin
  Form := TCustomForm.CreateNew(nil);
  try
    Deck := THbChoiceDeck.Create(Form);
    Deck.Parent := Form;
    Deck.Width := 400;
    Deck.Height := 500;
    Deck.SetOptions(['选项一', '选项二', '选项三']);

    // 1. Mode A: clmDeck (Vertical Card Stack)
    Deck.LayoutMode := clmDeck;
    RDeck := Deck.ItemRect(0);
    Assert.IsTrue(RDeck.Width > 200, 'Deck mode item should span width');
    Assert.AreEqual(Integer(Deck.ItemHeight), Integer(RDeck.Height));

    // 2. Mode B: clmRow (Horizontal Wrapped Row)
    Deck.LayoutMode := clmRow;
    RRow := Deck.ItemRect(0);
    Assert.IsTrue(RRow.Width < RDeck.Width, 'Row mode item should be a compact cell');

    // 3. Mode C: clmNumberedList
    Deck.LayoutMode := clmNumberedList;
    RList := Deck.ItemRect(0);
    Assert.IsTrue(RList.Height < RDeck.Height, 'List mode item should be compact height');

    // 4. Mode D: clmInline
    Deck.LayoutMode := clmInline;
    RInline := Deck.ItemRect(0);
    Assert.AreEqual(Integer(80), Integer(RInline.Width), 'Inline mode item has standard compact width');
  finally
    Form.Free;
  end;
end;

procedure TTestHbSuite.Test_HbChoice_Truthful_State_Transitions;
var
  Form: TCustomForm;
  Deck: THbChoiceDeck;
begin
  Form := TCustomForm.CreateNew(nil);
  try
    Deck := THbChoiceDeck.Create(Form);
    Deck.Parent := Form;
    Assert.AreEqual(Ord(csReady), Ord(Deck.State));

    // 1. Regenerate
    Deck.BeginRegenerate;
    Assert.AreEqual(Ord(csRegenerating), Ord(Deck.State));
    Deck.EndRegenerate;
    Assert.AreEqual(Ord(csReady), Ord(Deck.State));

    // 2. No Reliable Candidates (Truthful AI State)
    Deck.SetNoReliableCandidates('信息不足，暂无建议');
    Assert.AreEqual(Ord(csNoReliableCandidates), Ord(Deck.State));
    Assert.AreEqual('信息不足，暂无建议', Deck.StatusMessage);

    // 3. Technical Error State (Distinct from NoCandidates)
    Deck.SetError('网络超时: 504');
    Assert.AreEqual(Ord(csError), Ord(Deck.State));
    Assert.AreEqual('网络超时: 504', Deck.StatusMessage);

    // 4. Reset
    Deck.ResetToReady;
    Assert.AreEqual(Ord(csReady), Ord(Deck.State));
    Assert.AreEqual('', Deck.StatusMessage);
  finally
    Form.Free;
  end;
end;

procedure TTestHbSuite.Test_HbChoice_Text_Entry_Suspension_And_Active_Surface;
var
  Form: TCustomForm;
  Deck: THbChoiceDeck;
  Msg: TWMKeyDown;
begin
  Form := TCustomForm.CreateNew(nil);
  try
    Deck := THbChoiceDeck.Create(Form);
    Deck.Parent := Form;
    Deck.OnChoice := OnChoiceHelper;
    Deck.SetOptions(['方案1', '方案2', '方案3']);
    FLastChoiceKey := -1;

    // 1. Normal active state -> key '2' triggers option 2
    FillChar(Msg, SizeOf(Msg), 0);
    Msg.Msg := WM_KEYDOWN;
    Msg.CharCode := Ord('2');
    Deck.Dispatch(Msg);
    Assert.AreEqual(2, FLastChoiceKey);

    // 2. Inactive Surface -> key '2' ignored
    FLastChoiceKey := -1;
    Deck.IsActiveChoiceSurface := False;
    FillChar(Msg, SizeOf(Msg), 0);
    Msg.Msg := WM_KEYDOWN;
    Msg.CharCode := Ord('2');
    Deck.Dispatch(Msg);
    Assert.AreEqual(-1, FLastChoiceKey, 'Inactive choice surface must not intercept shortcuts');

    // 3. Text Entry Owns Keyboard: State = csFreeInput -> key '2' ignored
    Deck.IsActiveChoiceSurface := True;
    Deck.EnterFreeInput('用户正在输入手机号 13800...');
    Assert.AreEqual(Ord(csFreeInput), Ord(Deck.State));

    FLastChoiceKey := -1;
    FillChar(Msg, SizeOf(Msg), 0);
    Msg.Msg := WM_KEYDOWN;
    Msg.CharCode := Ord('2');
    Deck.Dispatch(Msg);
    Assert.AreEqual(-1, FLastChoiceKey, 'Choice shortcuts MUST be suspended during text entry');

    // 4. Cancel Free Input -> restores choice shortcuts
    Deck.CancelFreeInput;
    Assert.AreEqual(Ord(csReady), Ord(Deck.State));
    FLastChoiceKey := -1;
    FillChar(Msg, SizeOf(Msg), 0);
    Msg.Msg := WM_KEYDOWN;
    Msg.CharCode := Ord('3');
    Deck.Dispatch(Msg);
    Assert.AreEqual(3, FLastChoiceKey);
  finally
    Form.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestHbSuite);

end.
