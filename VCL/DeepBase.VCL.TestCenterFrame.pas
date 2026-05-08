{ ============================================================================
  DeepBase.VCL.TestCenterFrame - Developer Test Center UI Frame
  
  Version: 1.0
  Description:
    VCL Frame providing a unified test center UI for developers.
    
    Layout:
    - Left: TTreeView for test categories
    - Center: TListView for tests in selected category
    - Right: TMemo for test details and results
    - Bottom: Control buttons for running tests, opening tools
  ============================================================================ }

unit DeepBase.VCL.TestCenterFrame;

interface

uses
  Winapi.Windows,
  Winapi.ShellAPI,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ComCtrls,
  Vcl.ExtCtrls,
  Vcl.ImgList,
  DeepBase.TestCenter;

type
  TTestCenterFrame = class(TFrame)
  private
    FManager: TTestCenterManager;
    FOwnsManager: Boolean;
    FUniPublisherPath: string;
    
    // Layout panels
    pnlMain: TPanel;
    pnlLeft: TPanel;
    pnlCenter: TPanel;
    pnlRight: TPanel;
    pnlBottom: TPanel;
    
    // Left - Categories
    lblCategories: TLabel;
    tvCategories: TTreeView;
    
    // Center - Tests
    lblTests: TLabel;
    lvTests: TListView;
    
    // Right - Details
    lblDetails: TLabel;
    memDetails: TMemo;
    
    // Bottom - Controls
    btnRunSelected: TButton;
    btnRunAll: TButton;
    btnReset: TButton;
    btnOpenPublisher: TButton;
    lblSummary: TLabel;
    
    // Splitters
    splLeft: TSplitter;
    splRight: TSplitter;
    
    procedure CreateUI;
    procedure WireEvents;
    
    // Event handlers
    procedure TvCategoriesChange(Sender: TObject; Node: TTreeNode);
    procedure LvTestsSelectItem(Sender: TObject; Item: TListItem; 
      Selected: Boolean);
    procedure LvTestsDblClick(Sender: TObject);
    procedure BtnRunSelectedClick(Sender: TObject);
    procedure BtnRunAllClick(Sender: TObject);
    procedure BtnResetClick(Sender: TObject);
    procedure BtnOpenPublisherClick(Sender: TObject);
    
    // Manager event handlers
    procedure OnManagerStatusChange(Sender: TObject; ATest: TTestItem);
    procedure OnManagerLog(Sender: TObject; const Msg: string);
    
    // UI helpers
    procedure RefreshCategories;
    procedure RefreshTestList(const ACategoryId: string);
    procedure RefreshTestDetails(ATest: TTestItem);
    procedure UpdateSummary;
    procedure UpdateTestListItem(ATest: TTestItem);
    function FindListItem(const ATestId: string): TListItem;
    function GetStatusImageIndex(AStatus: TTestStatus): Integer;
    
    procedure AppendLog(const Msg: string);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    procedure Initialize(AManager: TTestCenterManager = nil);
    procedure RegisterSampleTests;
    
    /// <summary>Path to UniPublisher executable.</summary>
    property UniPublisherPath: string read FUniPublisherPath write FUniPublisherPath;
    
    /// <summary>The underlying test center manager.</summary>
    property Manager: TTestCenterManager read FManager;
  end;

implementation

{ TTestCenterFrame }

constructor TTestCenterFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FManager := nil;
  FOwnsManager := False;
  FUniPublisherPath := '';
  
  CreateUI;
  WireEvents;
end;

destructor TTestCenterFrame.Destroy;
begin
  if FOwnsManager and Assigned(FManager) then
    FreeAndNil(FManager);
  inherited;
end;

procedure TTestCenterFrame.Initialize(AManager: TTestCenterManager);
begin
  if Assigned(FManager) and FOwnsManager then
    FManager.Free;
    
  if Assigned(AManager) then
  begin
    FManager := AManager;
    FOwnsManager := False;
  end
  else
  begin
    FManager := TTestCenterManager.Create;
    FOwnsManager := True;
    TStandardCategories.RegisterAll(FManager);
  end;
  
  FManager.OnStatusChange := OnManagerStatusChange;
  FManager.OnLog := OnManagerLog;
  
  RefreshCategories;
  UpdateSummary;
end;

procedure TTestCenterFrame.CreateUI;
begin
  Width := 900;
  Height := 600;
  
  // Main panel
  pnlMain := TPanel.Create(Self);
  pnlMain.Parent := Self;
  pnlMain.Align := alClient;
  pnlMain.BevelOuter := bvNone;
  
  // Bottom panel (controls)
  pnlBottom := TPanel.Create(Self);
  pnlBottom.Parent := pnlMain;
  pnlBottom.Align := alBottom;
  pnlBottom.Height := 50;
  pnlBottom.BevelOuter := bvNone;
  
  btnRunSelected := TButton.Create(Self);
  btnRunSelected.Parent := pnlBottom;
  btnRunSelected.Left := 16;
  btnRunSelected.Top := 12;
  btnRunSelected.Width := 100;
  btnRunSelected.Caption := '运行选中';
  
  btnRunAll := TButton.Create(Self);
  btnRunAll.Parent := pnlBottom;
  btnRunAll.Left := 124;
  btnRunAll.Top := 12;
  btnRunAll.Width := 100;
  btnRunAll.Caption := '运行全部';
  
  btnReset := TButton.Create(Self);
  btnReset.Parent := pnlBottom;
  btnReset.Left := 232;
  btnReset.Top := 12;
  btnReset.Width := 80;
  btnReset.Caption := '重置';
  
  btnOpenPublisher := TButton.Create(Self);
  btnOpenPublisher.Parent := pnlBottom;
  btnOpenPublisher.Left := 340;
  btnOpenPublisher.Top := 12;
  btnOpenPublisher.Width := 140;
  btnOpenPublisher.Caption := '打开 UniPublisher...';
  
  lblSummary := TLabel.Create(Self);
  lblSummary.Parent := pnlBottom;
  lblSummary.Left := 500;
  lblSummary.Top := 16;
  lblSummary.Caption := '通过: 0, 失败: 0, 未运行: 0';
  lblSummary.AutoSize := True;
  
  // Left panel (categories)
  pnlLeft := TPanel.Create(Self);
  pnlLeft.Parent := pnlMain;
  pnlLeft.Align := alLeft;
  pnlLeft.Width := 180;
  pnlLeft.BevelOuter := bvNone;
  
  lblCategories := TLabel.Create(Self);
  lblCategories.Parent := pnlLeft;
  lblCategories.Left := 8;
  lblCategories.Top := 4;
  lblCategories.Caption := '测试分类';
  lblCategories.Font.Style := [fsBold];
  
  tvCategories := TTreeView.Create(Self);
  tvCategories.Parent := pnlLeft;
  tvCategories.Align := alClient;
  tvCategories.AlignWithMargins := True;
  tvCategories.Margins.Top := 24;
  tvCategories.Margins.Left := 4;
  tvCategories.Margins.Right := 4;
  tvCategories.Margins.Bottom := 4;
  tvCategories.ReadOnly := True;
  tvCategories.HideSelection := False;
  
  splLeft := TSplitter.Create(Self);
  splLeft.Parent := pnlMain;
  splLeft.Left := pnlLeft.Width;
  splLeft.Width := 4;
  
  // Right panel (details)
  pnlRight := TPanel.Create(Self);
  pnlRight.Parent := pnlMain;
  pnlRight.Align := alRight;
  pnlRight.Width := 300;
  pnlRight.BevelOuter := bvNone;
  
  lblDetails := TLabel.Create(Self);
  lblDetails.Parent := pnlRight;
  lblDetails.Left := 8;
  lblDetails.Top := 4;
  lblDetails.Caption := '详情 / 日志';
  lblDetails.Font.Style := [fsBold];
  
  memDetails := TMemo.Create(Self);
  memDetails.Parent := pnlRight;
  memDetails.Align := alClient;
  memDetails.AlignWithMargins := True;
  memDetails.Margins.Top := 24;
  memDetails.Margins.Left := 4;
  memDetails.Margins.Right := 4;
  memDetails.Margins.Bottom := 4;
  memDetails.ReadOnly := True;
  memDetails.ScrollBars := ssBoth;
  memDetails.Font.Name := 'Consolas';
  memDetails.Font.Size := 9;
  
  splRight := TSplitter.Create(Self);
  splRight.Parent := pnlMain;
  splRight.Align := alRight;
  splRight.Left := pnlRight.Left - 4;
  splRight.Width := 4;
  
  // Center panel (tests)
  pnlCenter := TPanel.Create(Self);
  pnlCenter.Parent := pnlMain;
  pnlCenter.Align := alClient;
  pnlCenter.BevelOuter := bvNone;
  
  lblTests := TLabel.Create(Self);
  lblTests.Parent := pnlCenter;
  lblTests.Left := 8;
  lblTests.Top := 4;
  lblTests.Caption := '测试项';
  lblTests.Font.Style := [fsBold];
  
  lvTests := TListView.Create(Self);
  lvTests.Parent := pnlCenter;
  lvTests.Align := alClient;
  lvTests.AlignWithMargins := True;
  lvTests.Margins.Top := 24;
  lvTests.Margins.Left := 4;
  lvTests.Margins.Right := 4;
  lvTests.Margins.Bottom := 4;
  lvTests.ViewStyle := vsReport;
  lvTests.RowSelect := True;
  lvTests.HideSelection := False;
  lvTests.ReadOnly := True;
  
  with lvTests.Columns.Add do
  begin
    Caption := '测试名称';
    Width := 200;
  end;
  with lvTests.Columns.Add do
  begin
    Caption := '状态';
    Width := 80;
  end;
  with lvTests.Columns.Add do
  begin
    Caption := '上次运行';
    Width := 120;
  end;
end;

procedure TTestCenterFrame.WireEvents;
begin
  tvCategories.OnChange := TvCategoriesChange;
  lvTests.OnSelectItem := LvTestsSelectItem;
  lvTests.OnDblClick := LvTestsDblClick;
  btnRunSelected.OnClick := BtnRunSelectedClick;
  btnRunAll.OnClick := BtnRunAllClick;
  btnReset.OnClick := BtnResetClick;
  btnOpenPublisher.OnClick := BtnOpenPublisherClick;
end;

procedure TTestCenterFrame.RefreshCategories;
var
  Categories: TArray<TTestCategory>;
  Cat: TTestCategory;
  Node: TTreeNode;
begin
  tvCategories.Items.Clear;
  
  if FManager = nil then
    Exit;
    
  Categories := FManager.GetCategories;
  
  for Cat in Categories do
  begin
    Node := tvCategories.Items.Add(nil, Cat.Name);
    Node.Data := Pointer(NativeUInt(Length(Cat.Id)));  // Store length for lookup
    // Store category ID in node's hint-like data
    Node.StateIndex := tvCategories.Items.Count - 1;
  end;
  
  // Select first category
  if tvCategories.Items.Count > 0 then
  begin
    tvCategories.Items[0].Selected := True;
    tvCategories.Items[0].Focused := True;
  end;
end;

procedure TTestCenterFrame.RefreshTestList(const ACategoryId: string);
var
  Tests: TArray<TTestItem>;
  Test: TTestItem;
  Item: TListItem;
begin
  lvTests.Items.Clear;
  
  if FManager = nil then
    Exit;
    
  Tests := FManager.GetTestsByCategory(ACategoryId);
  
  for Test in Tests do
  begin
    Item := lvTests.Items.Add;
    Item.Caption := Test.Name;
    Item.SubItems.Add(Test.StatusText);
    if Test.LastRunTime > 0 then
      Item.SubItems.Add(FormatDateTime('yyyy-mm-dd hh:nn:ss', Test.LastRunTime))
    else
      Item.SubItems.Add('');
    Item.Data := Test;
    Item.ImageIndex := GetStatusImageIndex(Test.Status);
  end;
  
  // Select first test
  if lvTests.Items.Count > 0 then
  begin
    lvTests.Items[0].Selected := True;
    lvTests.Items[0].Focused := True;
  end;
end;

procedure TTestCenterFrame.RefreshTestDetails(ATest: TTestItem);
begin
  memDetails.Clear;
  
  if ATest = nil then
    Exit;
    
  memDetails.Lines.Add('=== 测试详情 ===');
  memDetails.Lines.Add('');
  memDetails.Lines.Add('ID: ' + ATest.Id);
  memDetails.Lines.Add('名称: ' + ATest.Name);
  memDetails.Lines.Add('分类: ' + ATest.CategoryId);
  memDetails.Lines.Add('状态: ' + ATest.StatusText);
  memDetails.Lines.Add('');
  
  if ATest.Description <> '' then
  begin
    memDetails.Lines.Add('描述:');
    memDetails.Lines.Add(ATest.Description);
    memDetails.Lines.Add('');
  end;
  
  if ATest.LastRunTime > 0 then
  begin
    memDetails.Lines.Add('上次运行: ' + 
      FormatDateTime('yyyy-mm-dd hh:nn:ss', ATest.LastRunTime));
  end;
  
  if ATest.LastResult <> '' then
  begin
    memDetails.Lines.Add('');
    memDetails.Lines.Add('=== 运行结果 ===');
    memDetails.Lines.Add(ATest.LastResult);
  end;
end;

procedure TTestCenterFrame.UpdateSummary;
begin
  if FManager = nil then
  begin
    lblSummary.Caption := '未初始化';
    Exit;
  end;
  
  lblSummary.Caption := Format('通过: %d, 失败: %d, 未运行: %d, 总计: %d',
    [FManager.GetPassedCount, FManager.GetFailedCount, 
     FManager.GetNotRunCount, FManager.GetTotalCount]);
end;

procedure TTestCenterFrame.UpdateTestListItem(ATest: TTestItem);
var
  Item: TListItem;
begin
  Item := FindListItem(ATest.Id);
  if Item = nil then
    Exit;
    
  Item.SubItems[0] := ATest.StatusText;
  if ATest.LastRunTime > 0 then
    Item.SubItems[1] := FormatDateTime('yyyy-mm-dd hh:nn:ss', ATest.LastRunTime)
  else
    Item.SubItems[1] := '';
  Item.ImageIndex := GetStatusImageIndex(ATest.Status);
end;

function TTestCenterFrame.FindListItem(const ATestId: string): TListItem;
var
  I: Integer;
  Test: TTestItem;
begin
  Result := nil;
  for I := 0 to lvTests.Items.Count - 1 do
  begin
    Test := TTestItem(lvTests.Items[I].Data);
    if (Test <> nil) and SameText(Test.Id, ATestId) then
      Exit(lvTests.Items[I]);
  end;
end;

function TTestCenterFrame.GetStatusImageIndex(AStatus: TTestStatus): Integer;
begin
  case AStatus of
    tsNotRun:  Result := -1;
    tsRunning: Result := 0;
    tsPassed:  Result := 1;
    tsFailed:  Result := 2;
    tsSkipped: Result := 3;
  else
    Result := -1;
  end;
end;

procedure TTestCenterFrame.AppendLog(const Msg: string);
begin
  memDetails.Lines.Add(FormatDateTime('hh:nn:ss', Now) + ' ' + Msg);
end;

procedure TTestCenterFrame.TvCategoriesChange(Sender: TObject; Node: TTreeNode);
var
  Categories: TArray<TTestCategory>;
  Index: Integer;
begin
  if (Node = nil) or (FManager = nil) then
    Exit;
    
  Categories := FManager.GetCategories;
  Index := Node.StateIndex;
  
  if (Index >= 0) and (Index < Length(Categories)) then
    RefreshTestList(Categories[Index].Id);
end;

procedure TTestCenterFrame.LvTestsSelectItem(Sender: TObject; Item: TListItem;
  Selected: Boolean);
var
  Test: TTestItem;
begin
  if not Selected or (Item = nil) then
    Exit;
    
  Test := TTestItem(Item.Data);
  RefreshTestDetails(Test);
end;

procedure TTestCenterFrame.LvTestsDblClick(Sender: TObject);
begin
  BtnRunSelectedClick(Sender);
end;

procedure TTestCenterFrame.BtnRunSelectedClick(Sender: TObject);
var
  Item: TListItem;
  Test: TTestItem;
begin
  Item := lvTests.Selected;
  if (Item = nil) or (FManager = nil) then
    Exit;
    
  Test := TTestItem(Item.Data);
  if Test = nil then
    Exit;
    
  AppendLog('');
  AppendLog('=== 运行测试 ===');
  FManager.RunTest(Test.Id);
  RefreshTestDetails(Test);
end;

procedure TTestCenterFrame.BtnRunAllClick(Sender: TObject);
begin
  if FManager = nil then
    Exit;
    
  memDetails.Clear;
  AppendLog('=== 运行所有测试 ===');
  FManager.RunAllTests;
  
  // Refresh current list
  if tvCategories.Selected <> nil then
    TvCategoriesChange(tvCategories, tvCategories.Selected);
end;

procedure TTestCenterFrame.BtnResetClick(Sender: TObject);
begin
  if FManager = nil then
    Exit;
    
  FManager.ResetAllTests;
  
  // Refresh current list
  if tvCategories.Selected <> nil then
    TvCategoriesChange(tvCategories, tvCategories.Selected);
    
  memDetails.Clear;
  AppendLog('已重置所有测试状态');
end;

procedure TTestCenterFrame.BtnOpenPublisherClick(Sender: TObject);
var
  ExePath: string;
begin
  ExePath := FUniPublisherPath;
  
  if ExePath = '' then
  begin
    // Try to find UniPublisher in common locations
    ExePath := TPath.Combine(ExtractFilePath(Application.ExeName), 'UniPublisher.exe');
    if not TFile.Exists(ExePath) then
      ExePath := TPath.Combine(ExtractFilePath(Application.ExeName), '..\Tools\UniPublisher\UniPublisher.exe');
    if not TFile.Exists(ExePath) then
      ExePath := TPath.Combine(ExtractFilePath(Application.ExeName), '..\..\Tools\UniPublisher\Win32\Release\UniPublisher.exe');
  end;
  
  if TFile.Exists(ExePath) then
  begin
    ShellExecute(0, 'open', PChar(ExePath), nil, nil, SW_SHOWNORMAL);
    AppendLog('已打开 UniPublisher: ' + ExePath);
  end
  else
  begin
    AppendLog('未找到 UniPublisher.exe');
    AppendLog('请设置 UniPublisherPath 属性或将 UniPublisher.exe 放在应用程序目录');
    ShowMessage('未找到 UniPublisher.exe'#13#10 + 
      '请确保 UniPublisher 已编译并放在正确的位置。');
  end;
end;

procedure TTestCenterFrame.OnManagerStatusChange(Sender: TObject; 
  ATest: TTestItem);
begin
  UpdateTestListItem(ATest);
  UpdateSummary;
end;

procedure TTestCenterFrame.OnManagerLog(Sender: TObject; const Msg: string);
begin
  AppendLog(Msg);
end;

procedure TTestCenterFrame.RegisterSampleTests;
var
  Test: TTestItem;
begin
  if FManager = nil then
    Exit;
    
  // Core tests
  Test := FManager.RegisterTest('core.version', '版本信息检查', TStandardCategories.CAT_CORE);
  Test.Description := '验证应用程序版本信息是否正确设置';
  Test.ExecuteProc := procedure
    begin
      // 模拟版本检查
    end;
    
  Test := FManager.RegisterTest('core.config', '配置文件读写', TStandardCategories.CAT_CORE);
  Test.Description := '测试配置文件的读取和写入功能';
  
  // AutoUpdate tests
  Test := FManager.RegisterTest('autoupdate.check', '检查更新', TStandardCategories.CAT_AUTOUPDATE);
  Test.Description := '测试自动更新检查功能';
  
  Test := FManager.RegisterTest('autoupdate.download', '下载更新包', TStandardCategories.CAT_AUTOUPDATE);
  Test.Description := '测试更新包下载功能';
  
  // Publisher tests
  Test := FManager.RegisterTest('publisher.config', '配置加载', TStandardCategories.CAT_PUBLISHER);
  Test.Description := '测试 .publish.json 配置文件加载';
  
  Test := FManager.RegisterTest('publisher.package', 'ZIP 打包', TStandardCategories.CAT_PUBLISHER);
  Test.Description := '测试 ZIP 打包功能';
  
  Test := FManager.RegisterTest('publisher.manifest', 'Manifest 生成', TStandardCategories.CAT_PUBLISHER);
  Test.Description := '测试 version.json 生成功能';
  
  // Tools tests
  Test := FManager.RegisterTest('tools.unlock', '解锁码生成', TStandardCategories.CAT_TOOLS);
  Test.Description := '测试解锁码生成和验证';
  
  // Refresh UI
  RefreshCategories;
  UpdateSummary;
end;

end.
