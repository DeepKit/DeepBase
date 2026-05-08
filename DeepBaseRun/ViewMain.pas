unit ViewMain;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.Layouts, FMX.Memo, FMX.StdCtrls, FMX.TabControl, FMX.ListBox,
  FMX.TreeView, FMX.Edit,
  FireDAC.Comp.UI,
  DeepBase.Manager,
  DeepBase.Types,
  DeepBase.Config,
  DeepBase.i18n,
  DeepBase.Logging,
  DeepBase.FormState,
  CtrlMain;

type
  TfrmMain = class(TForm)
    LayoutMain: TLayout;
    PanelTop: TPanel;
    LabelTitle: TLabel;
    PanelLeft: TPanel;
    TreeViewNav: TTreeView;
    TreeItemConfig: TTreeViewItem;
    TreeItemI18n: TTreeViewItem;
    TreeItemLogs: TTreeViewItem;
    TreeItemTools: TTreeViewItem;
    PanelCenter: TPanel;
    TabControlMain: TTabControl;
    TabItemWelcome: TTabItem;
    TabItemConfig: TTabItem;
    TabItemI18n: TTabItem;
    TabItemLogs: TTabItem;
    TabItemTools: TTabItem;
    LayoutWelcome: TLayout;
    LabelWelcomeDesc: TLabel;
    MemoWelcome: TMemo;
    LayoutConfig: TLayout;
    LabelConfigDesc: TLabel;
    ListBoxConfigGroups: TListBox;
    EditConfigValue: TEdit;
    ButtonConfigSave: TButton;
    LayoutI18n: TLayout;
    LabelI18nDesc: TLabel;
    ComboBoxLanguages: TComboBox;
    ListBoxLanguages: TListBox;
    EditTestText: TEdit;
    LabelTranslated: TLabel;
    ButtonTranslate: TButton;
    LayoutLogs: TLayout;
    LabelLogsDesc: TLabel;
    MemoLogs: TMemo;
    ButtonLogsRefresh: TButton;
    ButtonLogsClear: TButton;
    ButtonLogWrite: TButton;
    LayoutTools: TLayout;
    LabelToolsDesc: TLabel;
    ButtonSelfCheck: TButton;
    MemoToolsOutput: TMemo;
    PanelRight: TPanel;
    LabelRightTitle: TLabel;
    MemoInfo: TMemo;
    PanelBottom: TPanel;
    LabelStatus: TLabel;
    LabelVersion: TLabel;
    FDGUIxWaitCursor1: TFDGUIxWaitCursor;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure TabControlMainChange(Sender: TObject);
    procedure TreeViewNavChange(Sender: TObject);
    procedure ButtonConfigSaveClick(Sender: TObject);
    procedure ButtonLogsRefreshClick(Sender: TObject);
    procedure ButtonLogsClearClick(Sender: TObject);
    procedure ButtonLogWriteClick(Sender: TObject);
    procedure ButtonTranslateClick(Sender: TObject);
    procedure ButtonSelfCheckClick(Sender: TObject);
    procedure ComboBoxLanguagesChange(Sender: TObject);
  private
    FController: ICtrlMain;
    FUB: TDeepBaseManager;
    FFormState: TDeepBaseFormState;
    procedure InitializeController;
    procedure SetupWelcomePage;
    procedure SetupConfigPage;
    procedure SetupI18nPage;
    procedure SetupLogsPage;
    procedure SetupToolsPage;
    procedure UpdateInfoPanel(const ATitle, AContent: string);
    procedure SaveFormState;
    procedure RestoreFormState;
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.fmx}

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  FUB := DeepBase.Manager.DeepBase;
  FFormState := nil;
  
  // 初始化 FormState 管理器
  if FUB.IsInitialized then
    FFormState := FUB.FormState;
  
  InitializeController;
  SetupWelcomePage;
  SetupConfigPage;
  SetupI18nPage;
  SetupLogsPage;
  SetupToolsPage;
  
  // 恢复窗体状态
  RestoreFormState;
  
  if FUB.IsInitialized then
    LabelStatus.Text := 'Ready - DeepBase initialized'
  else
    LabelStatus.Text := 'Warning: ' + FUB.LastError;
    
  LabelVersion.Text := 'v' + DeepBase_VERSION;
  TabControlMain.ActiveTab := TabItemWelcome;
  
  if FUB.IsInitialized and Assigned(FUB.Logger) then
    FUB.Logger.Info('DeepBaseRun started', 'ViewMain');
end;

procedure TfrmMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  // 保存窗体状态
  SaveFormState;
  
  FFormState := nil;
    
  Action := TCloseAction.caFree;
end;

procedure TfrmMain.SaveFormState;
var
  Data: TFormStateData;
begin
  if not Assigned(FFormState) then
    Exit;
    
  Data.Init;
  Data.Left := Round(Self.Left);
  Data.Top := Round(Self.Top);
  Data.Width := Round(Self.Width);
  Data.Height := Round(Self.Height);
  if Self.WindowState = TWindowState.wsMaximized then
    Data.WindowState := 2
  else if Self.WindowState = TWindowState.wsMinimized then
    Data.WindowState := 1
  else
    Data.WindowState := 0;
  Data.MonitorIndex := 0;
  Data.Extra := '';
  
  FFormState.SaveState('frmMain', Data);
end;

procedure TfrmMain.RestoreFormState;
var
  Data: TFormStateData;
begin
  if not Assigned(FFormState) then
    Exit;
    
  if FFormState.RestoreState('frmMain', Data) then
  begin
    if Data.IsValid then
    begin
      Self.Left := Data.Left;
      Self.Top := Data.Top;
      Self.Width := Data.Width;
      Self.Height := Data.Height;
      case Data.WindowState of
        1: Self.WindowState := TWindowState.wsMinimized;
        2: Self.WindowState := TWindowState.wsMaximized;
      else
        Self.WindowState := TWindowState.wsNormal;
      end;
    end;
  end;
end;

procedure TfrmMain.InitializeController;
begin
  FController := TCtrlMain.Create;
  FController.Initialize;
end;

procedure TfrmMain.SetupWelcomePage;
begin
  LabelWelcomeDesc.Text := '[Welcome] DeepBase.Manager - Core manager singleton' + #13#10 +
    'Controls: TLayout, TLabel, TMemo, TTreeView, TTabControl' + #13#10 +
    'Functions: DeepBase(), DeepBase_VERSION, IsInitialized, RootPath';
  MemoWelcome.Lines.Clear;
  MemoWelcome.Lines.Add('=== DeepBaseRun Demo Application ===');
  MemoWelcome.Lines.Add('');
  MemoWelcome.Lines.Add('DeepBase Version: ' + DeepBase_VERSION);
  MemoWelcome.Lines.Add('Initialized: ' + BoolToStr(FUB.IsInitialized, True));
  
  if not FUB.IsInitialized then
  begin
    MemoWelcome.Lines.Add('');
    MemoWelcome.Lines.Add('*** INIT ERROR ***');
    MemoWelcome.Lines.Add('ErrorCode: ' + IntToStr(Ord(FUB.InitErrorCode)));
    MemoWelcome.Lines.Add('LastError: ' + FUB.LastError);
    MemoWelcome.Lines.Add('');
  end;
  
  MemoWelcome.Lines.Add('RootPath: ' + FUB.RootPath);
  MemoWelcome.Lines.Add('ConfigDB: ' + FUB.ConfigDBPath);
  MemoWelcome.Lines.Add('');
  MemoWelcome.Lines.Add('DeepBase Modules Demonstrated:');
  MemoWelcome.Lines.Add('  1. DeepBase.Manager   - Core manager, singleton pattern');
  MemoWelcome.Lines.Add('  2. DeepBase.Config    - Config management, GetConfig/SetConfig');
  MemoWelcome.Lines.Add('  3. DeepBase.i18n      - Internationalization, T()/TFmt()');
  MemoWelcome.Lines.Add('  4. DeepBase.Logging   - Logging, Debug/Info/Warn/Error');
  MemoWelcome.Lines.Add('  5. DeepBase.Types     - Common types and records');
  MemoWelcome.Lines.Add('  6. DeepBase.FormState - Save/restore window position');
  MemoWelcome.Lines.Add('');
  MemoWelcome.Lines.Add('Layout: 5-Panel + Multi-Tab');
  MemoWelcome.Lines.Add('  - PanelTop: Title bar');
  MemoWelcome.Lines.Add('  - PanelLeft: Navigation tree');
  MemoWelcome.Lines.Add('  - PanelCenter: Tab pages');
  MemoWelcome.Lines.Add('  - PanelRight: Info panel');
  MemoWelcome.Lines.Add('  - PanelBottom: Status bar');
end;

procedure TfrmMain.SetupConfigPage;
var
  Groups: TArray<string>;
  i: Integer;
begin
  LabelConfigDesc.Text := '[Config] DeepBase.Config - Configuration management' + #13#10 +
    'Controls: TLayout, TLabel, TListBox, TEdit, TButton' + #13#10 +
    'Functions: GetConfig, SetConfig, GetConfigInt, GetConfigBool';
  ListBoxConfigGroups.Clear;
  Groups := FController.GetConfigGroups;
  for i := 0 to Length(Groups) - 1 do
    ListBoxConfigGroups.Items.Add(Groups[i]);
  if FUB.IsInitialized and Assigned(FUB.Config) then
  begin
    ListBoxConfigGroups.Items.Add('--- DeepBase.Config Demo ---');
    ListBoxConfigGroups.Items.Add('App.Name = ' + FUB.Config.GetConfig('App.Name', 'N/A'));
    ListBoxConfigGroups.Items.Add('Log.Level = ' + FUB.Config.GetConfig('Log.Level', 'Info'));
  end;
end;

procedure TfrmMain.SetupI18nPage;
var
  Langs: TLanguageInfoArray;
  i: Integer;
begin
  LabelI18nDesc.Text := '[I18n] DeepBase.i18n - Internationalization' + #13#10 +
    'Controls: TLayout, TLabel, TComboBox, TListBox, TEdit, TButton' + #13#10 +
    'Functions: Translate, T(), TFmt(), GetAvailableLanguages';
    
  ComboBoxLanguages.Clear;
  ListBoxLanguages.Clear;
  EditTestText.Text := 'Hello World';
  LabelTranslated.Text := 'Result: (click Translate)';
  
  if FUB.IsInitialized and Assigned(FUB.I18n) then
  begin
    // 填充语言选择下拉框
    Langs := FUB.I18n.GetAvailableLanguages;
    
    if Length(Langs) = 0 then
    begin
      // 如果没有语言数据，添加默认语言
      ComboBoxLanguages.Items.Add('en-US - English');
      ComboBoxLanguages.Items.Add('zh-CN - Chinese (Simplified)');
      ComboBoxLanguages.Items.Add('ja-JP - Japanese');
      ListBoxLanguages.Items.Add('(No languages in database, showing defaults)');
    end
    else
    begin
      for i := 0 to Length(Langs) - 1 do
      begin
        ComboBoxLanguages.Items.Add(Format('%s - %s', [Langs[i].LangCode, Langs[i].LangName]));
        if Langs[i].IsDefault then
          ListBoxLanguages.Items.Add('[Default] ' + Langs[i].LangCode + ' - ' + Langs[i].NativeName)
        else
          ListBoxLanguages.Items.Add(Langs[i].LangCode + ' - ' + Langs[i].NativeName);
      end;
    end;
    
    // 设置当前语言
    ComboBoxLanguages.ItemIndex := 0;
    for i := 0 to ComboBoxLanguages.Items.Count - 1 do
    begin
      if Pos(FUB.I18n.CurrentLanguage, ComboBoxLanguages.Items[i]) = 1 then
      begin
        ComboBoxLanguages.ItemIndex := i;
        Break;
      end;
    end;
    
    ListBoxLanguages.Items.Add('');
    ListBoxLanguages.Items.Add('Current Language: ' + FUB.I18n.CurrentLanguage);
    ListBoxLanguages.Items.Add('');
    ListBoxLanguages.Items.Add('=== I18n Functions ===');
    ListBoxLanguages.Items.Add('T(text) - Translate text');
    ListBoxLanguages.Items.Add('TFmt(text, args) - Format + translate');
    ListBoxLanguages.Items.Add('TN(singular, plural, count) - Plural form');
  end
  else
  begin
    ComboBoxLanguages.Items.Add('(I18n not initialized)');
    ListBoxLanguages.Items.Add('DeepBase.I18n module not initialized.');
    ListBoxLanguages.Items.Add('');
    if not FUB.IsInitialized then
      ListBoxLanguages.Items.Add('Reason: DeepBase init failed - ' + FUB.LastError)
    else
      ListBoxLanguages.Items.Add('Reason: I18n module is nil');
  end;
end;

procedure TfrmMain.ComboBoxLanguagesChange(Sender: TObject);
var
  SelText, LangCode: string;
  P: Integer;
begin
  if ComboBoxLanguages.ItemIndex < 0 then
    Exit;
    
  SelText := ComboBoxLanguages.Items[ComboBoxLanguages.ItemIndex];
  P := Pos(' - ', SelText);
  if P > 0 then
    LangCode := Copy(SelText, 1, P - 1)
  else
    LangCode := SelText;
    
  if FUB.IsInitialized and Assigned(FUB.I18n) then
  begin
    FUB.I18n.CurrentLanguage := LangCode;
    ListBoxLanguages.Items.Add('');
    ListBoxLanguages.Items.Add('[' + FormatDateTime('hh:nn:ss', Now) + '] Language changed to: ' + LangCode);
    LabelStatus.Text := 'Language: ' + LangCode;
  end;
end;

procedure TfrmMain.SetupLogsPage;
begin
  LabelLogsDesc.Text := '[Logs] DeepBase.Logging - Log management' + #13#10 +
    'Controls: TLayout, TLabel, TMemo, TButton' + #13#10 +
    'Functions: Debug, Info, Warn, Error, Fatal, LogException';
  MemoLogs.Lines.Clear;
  MemoLogs.Lines.Add('DeepBase.Logging Demo:');
  MemoLogs.Lines.Add('');
  MemoLogs.Lines.Add('Log Levels (TLogLevel):');
  MemoLogs.Lines.Add('  - llDebug: Debug info');
  MemoLogs.Lines.Add('  - llInfo:  Normal info');
  MemoLogs.Lines.Add('  - llWarn:  Warnings');
  MemoLogs.Lines.Add('  - llError: Errors');
  MemoLogs.Lines.Add('  - llFatal: Fatal errors');
  MemoLogs.Lines.Add('');
  MemoLogs.Lines.Add('Click [Write Log] to write test logs');
  MemoLogs.Lines.Add('Click [Refresh] to view log files');
end;

procedure TfrmMain.SetupToolsPage;
begin
  LabelToolsDesc.Text := '[Tools] DeepBase.Manager - Health check' + #13#10 +
    'Controls: TLayout, TLabel, TButton, TMemo' + #13#10 +
    'Functions: HealthCheck, THealthCheckResult';
  MemoToolsOutput.Lines.Clear;
  MemoToolsOutput.Lines.Add('DeepBase System Tools:');
  MemoToolsOutput.Lines.Add('');
  MemoToolsOutput.Lines.Add('1. Self Check - DeepBase.Manager.HealthCheck()');
  MemoToolsOutput.Lines.Add('   Checks ConfigDB/Assets status');
  MemoToolsOutput.Lines.Add('');
  MemoToolsOutput.Lines.Add('2. THealthCheckResult fields:');
  MemoToolsOutput.Lines.Add('   - IsHealthy: Boolean');
  MemoToolsOutput.Lines.Add('   - ConfigDBOk: Boolean');
  MemoToolsOutput.Lines.Add('   - AssetsDirOk: Boolean');
  MemoToolsOutput.Lines.Add('   - Messages: TArray<string>');
end;

procedure TfrmMain.TabControlMainChange(Sender: TObject);
begin
  if TabControlMain.ActiveTab = TabItemWelcome then
    UpdateInfoPanel('Welcome', 'DeepBase.Manager' + #13#10 + 'Core singleton')
  else if TabControlMain.ActiveTab = TabItemConfig then
    UpdateInfoPanel('Config', 'DeepBase.Config' + #13#10 + 'Thread-safe cache')
  else if TabControlMain.ActiveTab = TabItemI18n then
    UpdateInfoPanel('I18n', 'DeepBase.i18n' + #13#10 + 'T()/TFmt()/TN()')
  else if TabControlMain.ActiveTab = TabItemLogs then
    UpdateInfoPanel('Logs', 'DeepBase.Logging' + #13#10 + 'Async queue')
  else if TabControlMain.ActiveTab = TabItemTools then
    UpdateInfoPanel('Tools', 'HealthCheck()' + #13#10 + 'System status');
end;

procedure TfrmMain.TreeViewNavChange(Sender: TObject);
begin
  if TreeViewNav.Selected = TreeItemConfig then
    TabControlMain.ActiveTab := TabItemConfig
  else if TreeViewNav.Selected = TreeItemI18n then
    TabControlMain.ActiveTab := TabItemI18n
  else if TreeViewNav.Selected = TreeItemLogs then
    TabControlMain.ActiveTab := TabItemLogs
  else if TreeViewNav.Selected = TreeItemTools then
    TabControlMain.ActiveTab := TabItemTools;
end;

procedure TfrmMain.ButtonConfigSaveClick(Sender: TObject);
begin
  ShowMessage('Config Save - demo');
  LabelStatus.Text := 'Config saved';
end;

procedure TfrmMain.ButtonLogsRefreshClick(Sender: TObject);
var
  LogFiles: TArray<TLogFileInfo>;
  i: Integer;
begin
  MemoLogs.Lines.Clear;
  MemoLogs.Lines.Add('=== Log Files ===');
  LogFiles := FController.GetLogFileList;
  if Length(LogFiles) = 0 then
    MemoLogs.Lines.Add('No log files found.')
  else
    for i := 0 to Length(LogFiles) - 1 do
      MemoLogs.Lines.Add(Format('%s (%d bytes)', [LogFiles[i].FileName, LogFiles[i].FileSize]));
  LabelStatus.Text := Format('Found %d files', [Length(LogFiles)]);
end;

procedure TfrmMain.ButtonLogsClearClick(Sender: TObject);
begin
  MemoLogs.Lines.Clear;
  LabelStatus.Text := 'Logs cleared';
end;

procedure TfrmMain.ButtonLogWriteClick(Sender: TObject);
begin
  if FUB.IsInitialized and Assigned(FUB.Logger) then
  begin
    FUB.Logger.Debug('Test DEBUG message', 'ViewMain');
    FUB.Logger.Info('Test INFO message', 'ViewMain');
    FUB.Logger.Warn('Test WARN message', 'ViewMain');
    FUB.Logger.Error('Test ERROR message', 'ViewMain');
    MemoLogs.Lines.Add('');
    MemoLogs.Lines.Add('[' + FormatDateTime('hh:nn:ss', Now) + '] Wrote 4 test logs');
    LabelStatus.Text := 'Logs written';
  end
  else
  begin
    MemoLogs.Lines.Add('[ERROR] Logger not initialized');
    LabelStatus.Text := 'Logger N/A';
  end;
end;

procedure TfrmMain.ButtonTranslateClick(Sender: TObject);
var
  Src, Result: string;
begin
  Src := EditTestText.Text;
  if FUB.IsInitialized and Assigned(FUB.I18n) then
  begin
    Result := FUB.I18n.Translate(Src);
    LabelTranslated.Text := 'Result: ' + Result;
    ListBoxLanguages.Items.Add('');
    ListBoxLanguages.Items.Add('Source: ' + Src);
    ListBoxLanguages.Items.Add('Translated: ' + T(Src));
    LabelStatus.Text := 'Translated';
  end
  else
  begin
    LabelTranslated.Text := 'Result: (I18n N/A)';
    LabelStatus.Text := 'I18n N/A';
  end;
end;

procedure TfrmMain.ButtonSelfCheckClick(Sender: TObject);
var
  CheckResult: THealthCheckResult;
  i: Integer;
begin
  MemoToolsOutput.Lines.Clear;
  MemoToolsOutput.Lines.Add('=== DeepBase Health Check ===');
  MemoToolsOutput.Lines.Add('');
  
  MemoToolsOutput.Lines.Add('DeepBase.IsInitialized: ' + BoolToStr(FUB.IsInitialized, True));
  MemoToolsOutput.Lines.Add('DeepBase.LastError: ' + FUB.LastError);
  MemoToolsOutput.Lines.Add('DeepBase.InitErrorCode: ' + IntToStr(Ord(FUB.InitErrorCode)));
  MemoToolsOutput.Lines.Add('');
  
  if FUB.IsInitialized then
  begin
    CheckResult := FUB.HealthCheck;
    MemoToolsOutput.Lines.Add('IsHealthy: ' + BoolToStr(CheckResult.IsHealthy, True));
    MemoToolsOutput.Lines.Add('ConfigDBOk: ' + BoolToStr(CheckResult.ConfigDBOk, True));
    MemoToolsOutput.Lines.Add('AssetsDirOk: ' + BoolToStr(CheckResult.AssetsDirOk, True));
    MemoToolsOutput.Lines.Add('');
    MemoToolsOutput.Lines.Add('Messages:');
    for i := 0 to Length(CheckResult.Messages) - 1 do
      MemoToolsOutput.Lines.Add('  - ' + CheckResult.Messages[i]);
  end
  else
    MemoToolsOutput.Lines.Add('[ERROR] DeepBase not initialized');
    
  MemoToolsOutput.Lines.Add('');
  MemoToolsOutput.Lines.Add('=== FormState Check ===');
  if Assigned(FFormState) then
  begin
    MemoToolsOutput.Lines.Add('FormState: Created');
    MemoToolsOutput.Lines.Add('HasState(frmMain): ' + BoolToStr(FFormState.HasState('frmMain'), True));
  end
  else
    MemoToolsOutput.Lines.Add('FormState: Not available');
    
  MemoToolsOutput.Lines.Add('');
  MemoToolsOutput.Lines.Add('=== Controller Check ===');
  MemoToolsOutput.Lines.Add(FController.PerformSelfCheck);
  LabelStatus.Text := 'Check done';
end;

procedure TfrmMain.UpdateInfoPanel(const ATitle, AContent: string);
begin
  LabelRightTitle.Text := ATitle;
  MemoInfo.Lines.Text := AContent;
end;

end.
