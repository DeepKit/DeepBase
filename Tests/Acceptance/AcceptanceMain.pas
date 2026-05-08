{ ============================================================================
  AcceptanceMain - 验收测试主窗�?
  
  版本: 1.0
  说明: 可视化验收测试界�?
  ============================================================================ }

unit AcceptanceMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, Vcl.ComCtrls, Vcl.ExtCtrls, Vcl.Buttons,
  AcceptanceRunner;

type
  TfrmAcceptanceMain = class(TForm)
    pnlTop: TPanel;
    lblTitle: TLabel;
    pnlLeft: TPanel;
    tvPhases: TTreeView;
    pnlRight: TPanel;
    pnlButtons: TPanel;
    btnRunPhase: TButton;
    btnRunAll: TButton;
    btnReport: TButton;
    lvTests: TListView;
    pnlLog: TPanel;
    mmoLog: TMemo;
    splitter1: TSplitter;
    pnlProgress: TPanel;
    pbProgress: TProgressBar;
    lblProgress: TLabel;
    btnMarkPass: TButton;
    btnMarkFail: TButton;
    pnlStatus: TPanel;
    lblStatus: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure tvPhasesClick(Sender: TObject);
    procedure btnRunPhaseClick(Sender: TObject);
    procedure btnRunAllClick(Sender: TObject);
    procedure btnReportClick(Sender: TObject);
    procedure btnMarkPassClick(Sender: TObject);
    procedure btnMarkFailClick(Sender: TObject);
    procedure lvTestsSelectItem(Sender: TObject; Item: TListItem;
      Selected: Boolean);
  private
    FRunner: TAcceptanceRunner;
    FSelectedPhase: Integer;
    
    procedure InitUI;
    procedure LoadPhases;
    procedure LoadTestsForPhase(Phase: Integer);
    procedure UpdateProgress;
    procedure OnTestProgress(const Item: TTestItem; Progress: Integer);
    procedure OnPhaseComplete(const Result: TPhaseResult);
    procedure OnLog(const Msg: string; IsError: Boolean);
    procedure UpdateTestItem(const Item: TTestItem);
  public
  end;

var
  frmAcceptanceMain: TfrmAcceptanceMain;

implementation

{$R *.dfm}

uses
  System.IOUtils, Winapi.ShellAPI;

const
  PHASE_NAMES: array[1..8] of string = (
    '文档与架构审�?,
    '静态代码分�?,
    '单元测试验证',
    '集成测试',
    '安全专项测试',
    '兼容性测�?,
    '示例项目验证',
    '最终验�?
  );

procedure TfrmAcceptanceMain.FormCreate(Sender: TObject);
begin
  FRunner := TAcceptanceRunner.Create;
  FRunner.OnProgress := OnTestProgress;
  FRunner.OnPhaseComplete := OnPhaseComplete;
  FRunner.OnLog := OnLog;
  FRunner.LoadTests;
  
  FSelectedPhase := 1;
  InitUI;
  LoadPhases;
  LoadTestsForPhase(1);
end;

procedure TfrmAcceptanceMain.FormDestroy(Sender: TObject);
begin
  FRunner.Free;
end;

procedure TfrmAcceptanceMain.InitUI;
begin
  Caption := 'DeepBase 可视化验收测试工�?v1.0';
  Width := 1200;
  Height := 800;
  Position := poDesigned;
  Left := 100;
  Top := 300;
  
  // 设置 ListView �?
  lvTests.ViewStyle := vsReport;
  lvTests.RowSelect := True;
  lvTests.GridLines := True;
  
  with lvTests.Columns.Add do begin Caption := 'ID'; Width := 80; end;
  with lvTests.Columns.Add do begin Caption := '测试名称'; Width := 200; end;
  with lvTests.Columns.Add do begin Caption := '描述'; Width := 300; end;
  with lvTests.Columns.Add do begin Caption := '优先�?; Width := 60; end;
  with lvTests.Columns.Add do begin Caption := '状�?; Width := 80; end;
  with lvTests.Columns.Add do begin Caption := '耗时(ms)'; Width := 80; end;
  
  mmoLog.Clear;
  mmoLog.Lines.Add('=== DeepBase 验收测试工具 ===');
  mmoLog.Lines.Add('按验收计划分阶段执行测试');
  mmoLog.Lines.Add('');
end;

procedure TfrmAcceptanceMain.LoadPhases;
var
  I: Integer;
  Node: TTreeNode;
begin
  tvPhases.Items.Clear;
  
  for I := 1 to 8 do
  begin
    Node := tvPhases.Items.Add(nil, Format('�?%d 阶段: %s', [I, PHASE_NAMES[I]]));
    Node.Data := Pointer(I);
  end;
  
  if tvPhases.Items.Count > 0 then
    tvPhases.Items[0].Selected := True;
end;

procedure TfrmAcceptanceMain.LoadTestsForPhase(Phase: Integer);
var
  Tests: TArray<TTestItem>;
  Item: TTestItem;
  LI: TListItem;
  StatusText: string;
begin
  lvTests.Items.Clear;
  Tests := FRunner.GetTestsByPhase(Phase);
  
  for Item in Tests do
  begin
    LI := lvTests.Items.Add;
    LI.Caption := Item.ID;
    LI.SubItems.Add(Item.Name);
    LI.SubItems.Add(Item.Description);
    
    case Item.Priority of
      tpP0: LI.SubItems.Add('P0');
      tpP1: LI.SubItems.Add('P1');
      tpP2: LI.SubItems.Add('P2');
      tpP3: LI.SubItems.Add('P3');
    end;
    
    case Item.Status of
      tsNotRun: StatusText := '未执�?;
      tsRunning: StatusText := '执行�?..';
      tsPassed: StatusText := '�?通过';
      tsFailed: StatusText := '�?失败';
      tsSkipped: StatusText := '�?跳过';
      tsManual: StatusText := '�?待人�?;
    end;
    LI.SubItems.Add(StatusText);
    LI.SubItems.Add(IntToStr(Item.DurationMs));
    LI.Data := Pointer(Phase);
  end;
  
  lblStatus.Caption := Format('�?%d 阶段: %s - �?%d 个测试项', 
    [Phase, PHASE_NAMES[Phase], Length(Tests)]);
end;

procedure TfrmAcceptanceMain.tvPhasesClick(Sender: TObject);
begin
  if tvPhases.Selected <> nil then
  begin
    FSelectedPhase := Integer(tvPhases.Selected.Data);
    LoadTestsForPhase(FSelectedPhase);
  end;
end;

procedure TfrmAcceptanceMain.btnRunPhaseClick(Sender: TObject);
begin
  if FRunner.Running then
  begin
    ShowMessage('测试正在运行�?..');
    Exit;
  end;
  
  btnRunPhase.Enabled := False;
  btnRunAll.Enabled := False;
  try
    FRunner.RunPhase(FSelectedPhase);
    LoadTestsForPhase(FSelectedPhase);
  finally
    btnRunPhase.Enabled := True;
    btnRunAll.Enabled := True;
  end;
end;

procedure TfrmAcceptanceMain.btnRunAllClick(Sender: TObject);
begin
  if FRunner.Running then
  begin
    ShowMessage('测试正在运行�?..');
    Exit;
  end;
  
  if MessageDlg('确定要运行所有阶段的测试吗？', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    btnRunPhase.Enabled := False;
    btnRunAll.Enabled := False;
    try
      FRunner.RunAllPhases;
      LoadTestsForPhase(FSelectedPhase);
    finally
      btnRunPhase.Enabled := True;
      btnRunAll.Enabled := True;
    end;
  end;
end;

procedure TfrmAcceptanceMain.btnReportClick(Sender: TObject);
var
  ReportPath: string;
begin
  ReportPath := TPath.Combine(ExtractFilePath(ParamStr(0)), 
    'AcceptanceReport_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.html');
  FRunner.GenerateReport(ReportPath);
  
  if MessageDlg('验收报告已生成，是否打开�?, mtConfirmation, [mbYes, mbNo], 0) = mrYes then
    ShellExecute(0, 'open', PChar(ReportPath), nil, nil, SW_SHOWNORMAL);
end;

procedure TfrmAcceptanceMain.btnMarkPassClick(Sender: TObject);
var
  TestID: string;
begin
  if lvTests.Selected = nil then
  begin
    ShowMessage('请先选择一个测试项');
    Exit;
  end;
  
  TestID := lvTests.Selected.Caption;
  FRunner.MarkManualTest(TestID, True, '');
  LoadTestsForPhase(FSelectedPhase);
  UpdateProgress;
end;

procedure TfrmAcceptanceMain.btnMarkFailClick(Sender: TObject);
var
  TestID, Notes: string;
begin
  if lvTests.Selected = nil then
  begin
    ShowMessage('请先选择一个测试项');
    Exit;
  end;
  
  TestID := lvTests.Selected.Caption;
  Notes := InputBox('标记失败', '请输入失败原�?', '');
  FRunner.MarkManualTest(TestID, False, Notes);
  LoadTestsForPhase(FSelectedPhase);
  UpdateProgress;
end;

procedure TfrmAcceptanceMain.lvTestsSelectItem(Sender: TObject; Item: TListItem;
  Selected: Boolean);
begin
  btnMarkPass.Enabled := Selected;
  btnMarkFail.Enabled := Selected;
end;

procedure TfrmAcceptanceMain.UpdateProgress;
var
  Progress: Integer;
begin
  Progress := FRunner.GetOverallProgress;
  pbProgress.Position := Progress;
  lblProgress.Caption := Format('总体进度: %d%%', [Progress]);
end;

procedure TfrmAcceptanceMain.OnTestProgress(const Item: TTestItem; Progress: Integer);
begin
  TThread.Synchronize(nil, procedure
  begin
    UpdateTestItem(Item);
    Application.ProcessMessages;
  end);
end;

procedure TfrmAcceptanceMain.OnPhaseComplete(const Result: TPhaseResult);
begin
  TThread.Synchronize(nil, procedure
  begin
    mmoLog.Lines.Add('');
    mmoLog.Lines.Add(Format('=== �?%d 阶段完成 ===', [Result.PhaseNumber]));
    mmoLog.Lines.Add(Format('  通过: %d', [Result.PassedTests]));
    mmoLog.Lines.Add(Format('  失败: %d', [Result.FailedTests]));
    mmoLog.Lines.Add(Format('  待人�? %d', [Result.ManualTests]));
    mmoLog.Lines.Add('');
    UpdateProgress;
  end);
end;

procedure TfrmAcceptanceMain.OnLog(const Msg: string; IsError: Boolean);
begin
  TThread.Synchronize(nil, procedure
  begin
    if IsError then
      mmoLog.Lines.Add('[错误] ' + Msg)
    else
      mmoLog.Lines.Add(Msg);
    SendMessage(mmoLog.Handle, EM_SCROLLCARET, 0, 0);
  end);
end;

procedure TfrmAcceptanceMain.UpdateTestItem(const Item: TTestItem);
var
  I: Integer;
  LI: TListItem;
  StatusText: string;
begin
  for I := 0 to lvTests.Items.Count - 1 do
  begin
    LI := lvTests.Items[I];
    if LI.Caption = Item.ID then
    begin
      case Item.Status of
        tsNotRun: StatusText := '未执�?;
        tsRunning: StatusText := '执行�?..';
        tsPassed: StatusText := '�?通过';
        tsFailed: StatusText := '�?失败';
        tsSkipped: StatusText := '�?跳过';
        tsManual: StatusText := '�?待人�?;
      end;
      LI.SubItems[4] := StatusText;
      LI.SubItems[5] := IntToStr(Item.DurationMs);
      Break;
    end;
  end;
end;

end.
