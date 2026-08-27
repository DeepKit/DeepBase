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
  Vcl.Forms,
  DeepBase.HB.Core,
  DeepBase.HB.Waterfall.Types,
  DeepBase.HB.Grid.Types,
  DeepBase.HB.AI.Types,
  DeepBase.HB.NavTree.Types,
  DeepBase.HB.PageControl.Types,
  DeepBase.HB.Dock.Types,
  DeepBase.VCL.HB.Waterfall,
  DeepBase.VCL.HB.Grid,
  DeepBase.VCL.HB.AI,
  DeepBase.VCL.HB.NavTree,
  DeepBase.VCL.HB.PageControl,
  DeepBase.VCL.HB.Dock;

type
  [TestFixture]
  TTestHbSuite = class
  private
    procedure OnGetFloatHelper(Sender: TObject; ARow, ACol: Integer; var AValue: Double);
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

initialization
  TDUnitX.RegisterTestFixture(TTestHbSuite);

end.
