{ ============================================================================
  Demo.MainForm

  Programmatically-built VCL form for the AIErrorHandler demo. No .dfm so
  the demo is buildable from the CLI without IDE save.

  Layout: status banner + 4 trigger buttons + scrollable log memo.
  ============================================================================ }

unit Demo.MainForm;

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Graphics;

type
  TDemoMainForm = class(TForm)
  private
    FStatus: TLabel;
    FLog: TMemo;
    FBtnIgnore: TButton;
    FBtnAutoFix: TButton;
    FBtnAIAnalyze: TButton;
    FBtnFatal: TButton;
    FBtnClearLog: TButton;
    procedure DoIgnore(Sender: TObject);
    procedure DoAutoFix(Sender: TObject);
    procedure DoAIAnalyze(Sender: TObject);
    procedure DoFatal(Sender: TObject);
    procedure DoClearLog(Sender: TObject);
    procedure AppendLog(const ALine: string);
    function ResolveStatusCaption: string;
  public
    constructor Create(AOwner: TComponent); override;
  end;

implementation

uses
  DeepBase.AIErrorHandler;

{ TDemoMainForm }

function TDemoMainForm.ResolveStatusCaption: string;
begin
  var LMode :=
    if TAIErrorHandler.Config.SilentMode then 'TEST (silent)'
    else 'PRODUCTION (interactive)';
  var LEnv := GetEnvironmentVariable('DEEP_AIEH_MODE');
  Result := Format(
    'AIErrorHandler  |  mode = %s  |  DEEP_AIEH_MODE = %s',
    [LMode, if LEnv = '' then '(unset)' else LEnv]);
end;

constructor TDemoMainForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  Caption := 'AIErrorHandler Demo';
  Width := 720;
  Height := 480;
  Position := poScreenCenter;

  FStatus := TLabel.Create(Self);
  FStatus.Parent := Self;
  FStatus.SetBounds(12, 12, Width - 24, 20);
  FStatus.Anchors := [akLeft, akTop, akRight];
  FStatus.AutoSize := False;
  FStatus.Caption := ResolveStatusCaption;
  FStatus.Font.Style := [fsBold];

  // Row of 4 trigger buttons + clear-log on the far right.
  FBtnIgnore := TButton.Create(Self);
  FBtnIgnore.Parent := Self;
  FBtnIgnore.SetBounds(12, 40, 120, 28);
  FBtnIgnore.Caption := '1) elIgnore';
  FBtnIgnore.OnClick := DoIgnore;

  FBtnAutoFix := TButton.Create(Self);
  FBtnAutoFix.Parent := Self;
  FBtnAutoFix.SetBounds(140, 40, 120, 28);
  FBtnAutoFix.Caption := '2) elAutoFix';
  FBtnAutoFix.OnClick := DoAutoFix;

  FBtnAIAnalyze := TButton.Create(Self);
  FBtnAIAnalyze.Parent := Self;
  FBtnAIAnalyze.SetBounds(268, 40, 120, 28);
  FBtnAIAnalyze.Caption := '3) elAIAnalyze';
  FBtnAIAnalyze.OnClick := DoAIAnalyze;

  FBtnFatal := TButton.Create(Self);
  FBtnFatal.Parent := Self;
  FBtnFatal.SetBounds(396, 40, 120, 28);
  FBtnFatal.Caption := '4) elFatal';
  FBtnFatal.OnClick := DoFatal;

  FBtnClearLog := TButton.Create(Self);
  FBtnClearLog.Parent := Self;
  FBtnClearLog.SetBounds(580, 40, 120, 28);
  FBtnClearLog.Anchors := [akTop, akRight];
  FBtnClearLog.Caption := 'Clear Log';
  FBtnClearLog.OnClick := DoClearLog;

  FLog := TMemo.Create(Self);
  FLog.Parent := Self;
  FLog.SetBounds(12, 80, Width - 24, Height - 130);
  FLog.Anchors := [akLeft, akTop, akRight, akBottom];
  FLog.ScrollBars := ssVertical;
  FLog.ReadOnly := True;
  FLog.Font.Name := 'Consolas';
  FLog.Font.Size := 9;

  AppendLog('Demo started. Click a button to trigger one of the four classification paths.');
  AppendLog('Tip: relaunch with DEEP_AIEH_MODE=test to switch from interactive to silent mode.');
  AppendLog('');
end;

procedure TDemoMainForm.AppendLog(const ALine: string);
begin
  FLog.Lines.Add(FormatDateTime('hh:nn:ss.zzz  ', Now) + ALine);
end;

procedure TDemoMainForm.DoClearLog(Sender: TObject);
begin
  FLog.Lines.Clear;
end;

procedure TDemoMainForm.DoIgnore(Sender: TObject);
begin
  AppendLog('-> Triggering EAbort (elIgnore path)');
  try
    SafeRun('demo.ignore', procedure begin Abort end);
    AppendLog('   handler returned. EAbort is silently dropped (no log, no dialog).');
  except
    on E: Exception do
      AppendLog('   UNEXPECTED: ' + E.ClassName + ' escaped: ' + E.Message);
  end;
end;

procedure TDemoMainForm.DoAutoFix(Sender: TObject);
begin
  AppendLog('-> Triggering EConvertError (elAutoFix path)');
  try
    SafeRun('demo.autofix',
      procedure
      begin
        StrToInt('not-a-number');
      end);
    AppendLog('   handler returned. Logged via Logger.Warn (check log/console).');
  except
    on E: Exception do
      AppendLog('   UNEXPECTED: ' + E.ClassName + ' escaped: ' + E.Message);
  end;
end;

procedure TDemoMainForm.DoAIAnalyze(Sender: TObject);
begin
  AppendLog('-> Triggering generic Exception (elAIAnalyze path)');
  AppendLog('   In PRODUCTION mode you''ll see a MessageDlg.');
  AppendLog('   In TEST mode (DEEP_AIEH_MODE=test) the dialog is suppressed.');
  try
    SafeRun('demo.aianalyze',
      procedure
      begin
        raise Exception.Create('A simulated business-logic failure for demo purposes.');
      end);
    AppendLog('   handler returned.');
  except
    on E: Exception do
      AppendLog('   UNEXPECTED: ' + E.ClassName + ' escaped: ' + E.Message);
  end;
end;

procedure TDemoMainForm.DoFatal(Sender: TObject);
begin
  AppendLog('-> Triggering EAccessViolation (elFatal path)');
  AppendLog('   PRODUCTION mode: MessageDlg + Application.Terminate.');
  AppendLog('   TEST mode: ExitCode := 1; Halt(1) (no dialog).');
  AppendLog('   The application is about to terminate.');
  // Force a flush so the user sees the warnings before termination.
  Application.ProcessMessages;
  SafeRun('demo.fatal',
    procedure
    begin
      raise EAccessViolation.Create('A simulated fatal exception for demo purposes.');
    end);
  // Should be unreachable: Handle.elFatal terminates the process.
  AppendLog('   UNEXPECTED: process is still running after elFatal.');
end;

end.
