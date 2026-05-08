unit MainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  FireDAC.VCLUI.Wait, FireDAC.Comp.UI, Vcl.ComCtrls,
  DeepBase.Manager, DeepBase.Logging, DeepBase.VCL.Controls, DeepBase.VCL.ConfigControls,
  DeepBase.VCL.I18nControls, DeepBase.VCL.ComboBoxes, DeepBase.VCL.FormStateHelper,
  DeepBase.VCL.LogListView, DeepBase.VCL.UIHelper, DeepBase.VCL.LLMConfigPanel,
  DeepBase.VCL.WaitForm, DeepBase.VCL.NotificationBar, DeepBase.Exception,
  DeepBase.Exceptions;

type
  TfrmMain = class(TForm)
    FDGUIxWaitCursor1: TFDGUIxWaitCursor;
    pnlLeft: TPanel;
    pnlRight: TPanel;
    splSplitter: TSplitter;
    pnlConfig: TPanel;
    pnlSettings: TPanel;
    lblLanguage: TI18nLabel;
    cboLanguage: TLanguageComboBox;
    lblTheme: TI18nLabel;
    cboTheme: TThemeComboBox;
    lblTestConfig: TI18nLabel;
    edtTestConfig: TConfigEdit;
    chkAutoSave: TConfigCheckBox;
    btnTestLog: TI18nButton;
    FormStateHelper1: TFormStateHelper;
    pgcMain: TPageControl;
    tsLogs: TTabSheet;
    tsLLM: TTabSheet;
    tsUI: TTabSheet;
    pnlLog: TPanel;
    LogListView1: TLogListView;
    LLMPanel: TLLMConfigPanel;
    NotificationBar1: TNotificationBar;
    btnShowWait: TButton;
    btnShowNotify: TButton;
    btnTriggerError: TButton;
    procedure FormCreate(Sender: TObject);
    procedure btnTestLogClick(Sender: TObject);
    procedure btnShowWaitClick(Sender: TObject);
    procedure btnShowNotifyClick(Sender: TObject);
    procedure btnTriggerErrorClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  TDeepBaseUIHelper.ApplyMicaEffect(Self);
  
  // Install Global Exception Handler
  TDeepBaseExceptionHandler.Install;
  
  // Create Controls Dynamically for Demo purpose
  
  // 1. Form State Helper
  FormStateHelper1 := TFormStateHelper.Create(Self);
  
  // 2. Left Panel Layout
  pnlLeft.Width := 300;
  
  // 3. Settings
  lblLanguage.TextKey := 'Language';
  lblTheme.TextKey := 'Theme';
  lblTestConfig.TextKey := 'Test Config';
  chkAutoSave.ConfigKey := 'App.AutoSaveDemo';
  chkAutoSave.Caption := 'Auto Save (Config Bound)';
  
  edtTestConfig.ConfigKey := 'Demo.TestString';
  edtTestConfig.DefaultValue := 'Hello DeepBase';
  
  btnTestLog.TextKey := 'Add Log';
  
  // 4. PageControl and Tabs
  pgcMain := TPageControl.Create(Self);
  pgcMain.Parent := pnlRight;
  pgcMain.Align := alClient;
  
  // Tab 1: Logs
  tsLogs := TTabSheet.Create(Self);
  tsLogs.PageControl := pgcMain;
  tsLogs.Caption := 'Logs';
  
  // Move pnlLog to Tab 1
  // Ideally pnlLog is already created by DFM but we are creating dynamic layout in this plan
  // Wait, LogListView1 is in DFM? Yes.
  // We need to reparent pnlLog
  pnlLog.Parent := tsLogs; 
  
  // Tab 2: LLM
  tsLLM := TTabSheet.Create(Self);
  tsLLM.PageControl := pgcMain;
  tsLLM.Caption := 'LLM';
  
  LLMPanel := TLLMConfigPanel.Create(Self);
  LLMPanel.Parent := tsLLM;
  LLMPanel.Align := alClient;
  
  // Tab 3: UI & Error
  tsUI := TTabSheet.Create(Self);
  tsUI.PageControl := pgcMain;
  tsUI.Caption := 'UI & Error';
  
  btnShowWait := TButton.Create(Self);
  btnShowWait.Parent := tsUI;
  btnShowWait.Left := 20;
  btnShowWait.Top := 20;
  btnShowWait.Width := 150;
  btnShowWait.Caption := 'Show Wait Form (3s)';
  btnShowWait.OnClick := btnShowWaitClick;
  
  btnShowNotify := TButton.Create(Self);
  btnShowNotify.Parent := tsUI;
  btnShowNotify.Left := 20;
  btnShowNotify.Top := 60;
  btnShowNotify.Width := 150;
  btnShowNotify.Caption := 'Show Notification';
  btnShowNotify.OnClick := btnShowNotifyClick;
  
  btnTriggerError := TButton.Create(Self);
  btnTriggerError.Parent := tsUI;
  btnTriggerError.Left := 20;
  btnTriggerError.Top := 100;
  btnTriggerError.Width := 150;
  btnTriggerError.Caption := 'Trigger Exception';
  btnTriggerError.OnClick := btnTriggerErrorClick;
  
  // Notification Bar (Bottom of Main Form, or pnlRight?)
  // Let's put it in pnlRight to avoid covering pnlLeft
  NotificationBar1 := TNotificationBar.Create(Self);
  NotificationBar1.Parent := pnlRight;
end;

procedure TfrmMain.btnShowWaitClick(Sender: TObject);
var
  WaitForm: TWaitForm;
begin
  WaitForm := TWaitForm.ShowWait('Processing data...');
  
  // Simulate work
  TThread.CreateAnonymousThread(procedure
  begin
    Sleep(3000);
    TThread.Synchronize(nil, TThreadProcedure(
      procedure
      begin
        TWaitForm.CloseWait(WaitForm);
        NotificationBar1.ShowSuccess('Operation Completed!');
      end));
  end).Start;
end;

procedure TfrmMain.btnShowNotifyClick(Sender: TObject);
begin
  NotificationBar1.ShowInfo('This is a non-intrusive notification.');
end;

procedure TfrmMain.btnTriggerErrorClick(Sender: TObject);
begin
  raise EOperationException.Create('This is a test exception handled by DeepBase!');
end;

procedure TfrmMain.btnTestLogClick(Sender: TObject);
begin
  Logger.Info('User clicked test log button.');
end;

end.
