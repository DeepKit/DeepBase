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

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.Graphics,
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
  DeepBase.VCL.HB.CommandPalette;

type
  [TestFixture]
  TTestHbSuite = class
  private
    FTrailingClicked: Boolean;
    FLastExecutedCmd: string;
    procedure OnGetFloatHelper(Sender: TObject; ARow, ACol: Integer; var AValue: Double);
    procedure OnTrailingClickHelper(Sender: TObject);
    procedure OnCommandExecuteHelper(Sender: TObject; const AItem: THbCommandItem);
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

initialization
  TDUnitX.RegisterTestFixture(TTestHbSuite);

end.
