{ ============================================================================
  FullDemo.MainForm - 综合演示主窗体
  
  版本: 1.0
  说明: 演示 UniBase 框架所有核心功能
  ============================================================================ }

unit FullDemo.MainForm;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.Menus,
  UniBase.Manager,
  UniBase.Config,
  UniBase.i18n,
  UniBase.Logging,
  UniBase.FormState,
  UniBase.MRU,
  UniBase.Theme,
  UniBase.License,
  UniBase.VCL.ConfigControls,
  UniBase.VCL.I18nControls,
  UniBase.VCL.MRUControls,
  UniBase.VCL.ComboBoxes,
  UniBase.VCL.LogListView,
  UniBase.VCL.WaitForm,
  UniBase.VCL.LicenseStatusPanel,
  UniBase.VCL.LicenseAuthDialog,
  UniBase.VCL.FeedbackDialog;

type
  TMainForm = class(TForm)
  private
    // 主界面
    FPageControl: TPageControl;
    FStatusBar: TStatusBar;
    FMainMenu: TMainMenu;
    
    // Config Tab
    FTabConfig: TTabSheet;
    FConfigEdit: TConfigEdit;
    FConfigCheckBox: TConfigCheckBox;
    FConfigSpinEdit: TConfigSpinEdit;
    FBtnSaveConfig: TButton;
    FLblConfigDemo: TLabel;
    
    // i18n Tab
    FTabI18n: TTabSheet;
    FI18nLabel: TI18nLabel;
    FI18nButton: TI18nButton;
    FLanguageComboBox: TLanguageComboBox;
    FLblCurrentLang: TLabel;
    
    // Logging Tab
    FTabLogging: TTabSheet;
    FLogListView: TLogListView;
    FBtnLogDebug: TButton;
    FBtnLogInfo: TButton;
    FBtnLogWarn: TButton;
    FBtnLogError: TButton;
    FBtnClearLogs: TButton;
    
    // MRU Tab
    FTabMRU: TTabSheet;
    FMRUComboBox: TMRUComboBox;
    FEdtMRUItem: TEdit;
    FBtnAddMRU: TButton;
    FBtnClearMRU: TButton;
    FLvMRU: TListView;
    
    // Theme Tab
    FTabTheme: TTabSheet;
    FThemeComboBox: TThemeComboBox;
    FLblThemeDemo: TLabel;
    FPnlThemePreview: TPanel;
    
    // License Tab
    FTabLicense: TTabSheet;
    FLicenseStatusPanel: TLicenseStatusPanel;
    FBtnActivate: TButton;
    FBtnFeedback: TButton;
    
    // Wait/Progress Tab
    FTabWait: TTabSheet;
    FBtnShowWait: TButton;
    FBtnShowProgress: TButton;
    
    procedure CreateUI;
    procedure CreateConfigTab;
    procedure CreateI18nTab;
    procedure CreateLoggingTab;
    procedure CreateMRUTab;
    procedure CreateThemeTab;
    procedure CreateLicenseTab;
    procedure CreateWaitTab;
    procedure CreateMainMenu;
    
    // Event handlers
    procedure HandleSaveConfigClick(Sender: TObject);
    procedure HandleLanguageChange(Sender: TObject);
    procedure HandleLogButtonClick(Sender: TObject);
    procedure HandleClearLogsClick(Sender: TObject);
    procedure HandleAddMRUClick(Sender: TObject);
    procedure HandleClearMRUClick(Sender: TObject);
    procedure HandleMRUSelect(Sender: TObject);
    procedure HandleThemeChange(Sender: TObject);
    procedure HandleActivateClick(Sender: TObject);
    procedure HandleFeedbackClick(Sender: TObject);
    procedure HandleShowWaitClick(Sender: TObject);
    procedure HandleShowProgressClick(Sender: TObject);
    procedure HandleMenuExit(Sender: TObject);
    procedure HandleMenuAbout(Sender: TObject);
    
    procedure RefreshMRUList;
    procedure UpdateStatusBar;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  MainForm: TMainForm;

implementation

uses
  Vcl.Dialogs;

{ TMainForm }

constructor TMainForm.Create(AOwner: TComponent);
var
  DBPath: string;
begin
  inherited CreateNew(AOwner);
  
  Caption := 'UniBase Full Demo';
  Width := 800;
  Height := 600;
  Position := poScreenCenter;
  
  // 初始化 UniBase
  DBPath := TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), 'demo.db');
  if not UniBase.InitializeWithDB(DBPath, 2) then
  begin
    ShowMessage('UniBase 初始化失败: ' + UniBase.GetInitErrorMessage);
  end;
  
  // 创建界面
  CreateUI;
  
  // 恢复窗体状态
  UniBase.FormState.RestoreFormState(Self);
  
  // 记录启动日志
  UniBase.Log.LogInfo('FullDemo 应用已启动', 'App');
  
  UpdateStatusBar;
end;

destructor TMainForm.Destroy;
begin
  // 保存窗体状态
  if UniBase.IsInitialized then
  begin
    UniBase.FormState.SaveFormState(Self);
    UniBase.Log.LogInfo('FullDemo 应用正在关闭', 'App');
    UniBase.Finalize;
  end;
  
  inherited;
end;

procedure TMainForm.CreateUI;
begin
  // 状态栏
  FStatusBar := TStatusBar.Create(Self);
  FStatusBar.Parent := Self;
  FStatusBar.Panels.Add.Width := 200;
  FStatusBar.Panels.Add.Width := 150;
  FStatusBar.Panels.Add.Width := 100;
  
  // 主菜单
  CreateMainMenu;
  
  // 页面控件
  FPageControl := TPageControl.Create(Self);
  FPageControl.Parent := Self;
  FPageControl.Align := alClient;
  
  // 创建各功能页
  CreateConfigTab;
  CreateI18nTab;
  CreateLoggingTab;
  CreateMRUTab;
  CreateThemeTab;
  CreateLicenseTab;
  CreateWaitTab;
end;

procedure TMainForm.CreateMainMenu;
var
  MFile, MHelp: TMenuItem;
  MItem: TMenuItem;
begin
  FMainMenu := TMainMenu.Create(Self);
  Self.Menu := FMainMenu;
  
  // File
  MFile := TMenuItem.Create(FMainMenu);
  MFile.Caption := '&File';
  FMainMenu.Items.Add(MFile);
  
  MItem := TMenuItem.Create(MFile);
  MItem.Caption := 'E&xit';
  MItem.OnClick := HandleMenuExit;
  MFile.Add(MItem);
  
  // Help
  MHelp := TMenuItem.Create(FMainMenu);
  MHelp.Caption := '&Help';
  FMainMenu.Items.Add(MHelp);
  
  MItem := TMenuItem.Create(MHelp);
  MItem.Caption := '&About...';
  MItem.OnClick := HandleMenuAbout;
  MHelp.Add(MItem);
end;

procedure TMainForm.CreateConfigTab;
var
  Y: Integer;
begin
  FTabConfig := TTabSheet.Create(FPageControl);
  FTabConfig.PageControl := FPageControl;
  FTabConfig.Caption := 'Config';
  
  Y := 20;
  
  FLblConfigDemo := TLabel.Create(Self);
  FLblConfigDemo.Parent := FTabConfig;
  FLblConfigDemo.Caption := '配置管理演示 - 修改下方控件，值会自动保存到数据库';
  FLblConfigDemo.Font.Style := [fsBold];
  FLblConfigDemo.SetBounds(20, Y, 500, 20);
  Inc(Y, 40);
  
  // ConfigEdit
  var LblEdit := TLabel.Create(Self);
  LblEdit.Parent := FTabConfig;
  LblEdit.Caption := 'User Name (app.username):';
  LblEdit.SetBounds(20, Y, 200, 16);
  Inc(Y, 20);
  
  FConfigEdit := TConfigEdit.Create(Self);
  FConfigEdit.Parent := FTabConfig;
  FConfigEdit.Section := 'app';
  FConfigEdit.Key := 'username';
  FConfigEdit.AutoLoad := True;
  FConfigEdit.AutoSave := True;
  FConfigEdit.SetBounds(20, Y, 250, 24);
  Inc(Y, 40);
  
  // ConfigCheckBox
  FConfigCheckBox := TConfigCheckBox.Create(Self);
  FConfigCheckBox.Parent := FTabConfig;
  FConfigCheckBox.Caption := 'Enable Notifications (app.notifications)';
  FConfigCheckBox.Section := 'app';
  FConfigCheckBox.Key := 'notifications';
  FConfigCheckBox.AutoLoad := True;
  FConfigCheckBox.AutoSave := True;
  FConfigCheckBox.SetBounds(20, Y, 300, 24);
  Inc(Y, 40);
  
  // ConfigSpinEdit
  var LblSpin := TLabel.Create(Self);
  LblSpin.Parent := FTabConfig;
  LblSpin.Caption := 'Max Items (app.max_items):';
  LblSpin.SetBounds(20, Y, 200, 16);
  Inc(Y, 20);
  
  FConfigSpinEdit := TConfigSpinEdit.Create(Self);
  FConfigSpinEdit.Parent := FTabConfig;
  FConfigSpinEdit.Section := 'app';
  FConfigSpinEdit.Key := 'max_items';
  FConfigSpinEdit.DefaultValue := 100;
  FConfigSpinEdit.AutoLoad := True;
  FConfigSpinEdit.AutoSave := True;
  FConfigSpinEdit.SetBounds(20, Y, 100, 24);
  Inc(Y, 50);
  
  FBtnSaveConfig := TButton.Create(Self);
  FBtnSaveConfig.Parent := FTabConfig;
  FBtnSaveConfig.Caption := 'Manual Save Test';
  FBtnSaveConfig.SetBounds(20, Y, 150, 28);
  FBtnSaveConfig.OnClick := HandleSaveConfigClick;
end;

procedure TMainForm.CreateI18nTab;
var
  Y: Integer;
begin
  FTabI18n := TTabSheet.Create(FPageControl);
  FTabI18n.PageControl := FPageControl;
  FTabI18n.Caption := 'i18n';
  
  Y := 20;
  
  var LblDemo := TLabel.Create(Self);
  LblDemo.Parent := FTabI18n;
  LblDemo.Caption := '国际化演示 - 切换语言后控件文本自动更新';
  LblDemo.Font.Style := [fsBold];
  LblDemo.SetBounds(20, Y, 400, 20);
  Inc(Y, 40);
  
  // Language selector
  var LblLang := TLabel.Create(Self);
  LblLang.Parent := FTabI18n;
  LblLang.Caption := 'Select Language:';
  LblLang.SetBounds(20, Y, 100, 16);
  Inc(Y, 20);
  
  FLanguageComboBox := TLanguageComboBox.Create(Self);
  FLanguageComboBox.Parent := FTabI18n;
  FLanguageComboBox.SetBounds(20, Y, 200, 24);
  FLanguageComboBox.OnChange := HandleLanguageChange;
  Inc(Y, 40);
  
  // Current language display
  FLblCurrentLang := TLabel.Create(Self);
  FLblCurrentLang.Parent := FTabI18n;
  FLblCurrentLang.Caption := 'Current: ' + UniBase.i18n.CurrentLanguage;
  FLblCurrentLang.SetBounds(20, Y, 200, 20);
  Inc(Y, 40);
  
  // i18n Label
  FI18nLabel := TI18nLabel.Create(Self);
  FI18nLabel.Parent := FTabI18n;
  FI18nLabel.TextKey := 'welcome_message';
  FI18nLabel.Caption := 'Welcome to UniBase!';
  FI18nLabel.Font.Size := 14;
  FI18nLabel.SetBounds(20, Y, 400, 30);
  Inc(Y, 40);
  
  // i18n Button
  FI18nButton := TI18nButton.Create(Self);
  FI18nButton.Parent := FTabI18n;
  FI18nButton.TextKey := 'btn_save';
  FI18nButton.Caption := 'Save';
  FI18nButton.SetBounds(20, Y, 100, 28);
end;

procedure TMainForm.CreateLoggingTab;
var
  PnlButtons: TPanel;
begin
  FTabLogging := TTabSheet.Create(FPageControl);
  FTabLogging.PageControl := FPageControl;
  FTabLogging.Caption := 'Logging';
  
  // Button panel
  PnlButtons := TPanel.Create(Self);
  PnlButtons.Parent := FTabLogging;
  PnlButtons.Align := alTop;
  PnlButtons.Height := 50;
  PnlButtons.BevelOuter := bvNone;
  
  FBtnLogDebug := TButton.Create(Self);
  FBtnLogDebug.Parent := PnlButtons;
  FBtnLogDebug.Caption := 'Debug';
  FBtnLogDebug.Tag := 0;
  FBtnLogDebug.SetBounds(10, 10, 80, 28);
  FBtnLogDebug.OnClick := HandleLogButtonClick;
  
  FBtnLogInfo := TButton.Create(Self);
  FBtnLogInfo.Parent := PnlButtons;
  FBtnLogInfo.Caption := 'Info';
  FBtnLogInfo.Tag := 1;
  FBtnLogInfo.SetBounds(100, 10, 80, 28);
  FBtnLogInfo.OnClick := HandleLogButtonClick;
  
  FBtnLogWarn := TButton.Create(Self);
  FBtnLogWarn.Parent := PnlButtons;
  FBtnLogWarn.Caption := 'Warning';
  FBtnLogWarn.Tag := 2;
  FBtnLogWarn.SetBounds(190, 10, 80, 28);
  FBtnLogWarn.OnClick := HandleLogButtonClick;
  
  FBtnLogError := TButton.Create(Self);
  FBtnLogError.Parent := PnlButtons;
  FBtnLogError.Caption := 'Error';
  FBtnLogError.Tag := 3;
  FBtnLogError.SetBounds(280, 10, 80, 28);
  FBtnLogError.OnClick := HandleLogButtonClick;
  
  FBtnClearLogs := TButton.Create(Self);
  FBtnClearLogs.Parent := PnlButtons;
  FBtnClearLogs.Caption := 'Clear';
  FBtnClearLogs.SetBounds(380, 10, 80, 28);
  FBtnClearLogs.OnClick := HandleClearLogsClick;
  
  // Log ListView
  FLogListView := TLogListView.Create(Self);
  FLogListView.Parent := FTabLogging;
  FLogListView.Align := alClient;
end;

procedure TMainForm.CreateMRUTab;
var
  Y: Integer;
begin
  FTabMRU := TTabSheet.Create(FPageControl);
  FTabMRU.PageControl := FPageControl;
  FTabMRU.Caption := 'MRU';
  
  Y := 20;
  
  var LblDemo := TLabel.Create(Self);
  LblDemo.Parent := FTabMRU;
  LblDemo.Caption := '最近使用项演示';
  LblDemo.Font.Style := [fsBold];
  LblDemo.SetBounds(20, Y, 200, 20);
  Inc(Y, 40);
  
  // Add MRU
  FEdtMRUItem := TEdit.Create(Self);
  FEdtMRUItem.Parent := FTabMRU;
  FEdtMRUItem.SetBounds(20, Y, 250, 24);
  FEdtMRUItem.TextHint := 'Enter item to add...';
  
  FBtnAddMRU := TButton.Create(Self);
  FBtnAddMRU.Parent := FTabMRU;
  FBtnAddMRU.Caption := 'Add';
  FBtnAddMRU.SetBounds(280, Y, 60, 24);
  FBtnAddMRU.OnClick := HandleAddMRUClick;
  
  FBtnClearMRU := TButton.Create(Self);
  FBtnClearMRU.Parent := FTabMRU;
  FBtnClearMRU.Caption := 'Clear';
  FBtnClearMRU.SetBounds(350, Y, 60, 24);
  FBtnClearMRU.OnClick := HandleClearMRUClick;
  Inc(Y, 40);
  
  // MRU ComboBox
  var LblCombo := TLabel.Create(Self);
  LblCombo.Parent := FTabMRU;
  LblCombo.Caption := 'MRU ComboBox:';
  LblCombo.SetBounds(20, Y, 100, 16);
  Inc(Y, 20);
  
  FMRUComboBox := TMRUComboBox.Create(Self);
  FMRUComboBox.Parent := FTabMRU;
  FMRUComboBox.Category := 'demo_items';
  FMRUComboBox.SetBounds(20, Y, 250, 24);
  FMRUComboBox.OnSelect := HandleMRUSelect;
  Inc(Y, 40);
  
  // MRU List
  var LblList := TLabel.Create(Self);
  LblList.Parent := FTabMRU;
  LblList.Caption := 'All MRU Items:';
  LblList.SetBounds(20, Y, 100, 16);
  Inc(Y, 20);
  
  FLvMRU := TListView.Create(Self);
  FLvMRU.Parent := FTabMRU;
  FLvMRU.ViewStyle := vsReport;
  FLvMRU.SetBounds(20, Y, 400, 200);
  FLvMRU.Columns.Add.Caption := 'Item';
  FLvMRU.Columns[0].Width := 200;
  FLvMRU.Columns.Add.Caption := 'Last Used';
  FLvMRU.Columns[1].Width := 150;
  
  RefreshMRUList;
end;

procedure TMainForm.CreateThemeTab;
var
  Y: Integer;
begin
  FTabTheme := TTabSheet.Create(FPageControl);
  FTabTheme.PageControl := FPageControl;
  FTabTheme.Caption := 'Theme';
  
  Y := 20;
  
  FLblThemeDemo := TLabel.Create(Self);
  FLblThemeDemo.Parent := FTabTheme;
  FLblThemeDemo.Caption := '主题切换演示';
  FLblThemeDemo.Font.Style := [fsBold];
  FLblThemeDemo.SetBounds(20, Y, 200, 20);
  Inc(Y, 40);
  
  var LblTheme := TLabel.Create(Self);
  LblTheme.Parent := FTabTheme;
  LblTheme.Caption := 'Select Theme:';
  LblTheme.SetBounds(20, Y, 100, 16);
  Inc(Y, 20);
  
  FThemeComboBox := TThemeComboBox.Create(Self);
  FThemeComboBox.Parent := FTabTheme;
  FThemeComboBox.SetBounds(20, Y, 200, 24);
  FThemeComboBox.OnChange := HandleThemeChange;
  Inc(Y, 50);
  
  FPnlThemePreview := TPanel.Create(Self);
  FPnlThemePreview.Parent := FTabTheme;
  FPnlThemePreview.Caption := 'Theme Preview Panel';
  FPnlThemePreview.SetBounds(20, Y, 300, 150);
end;

procedure TMainForm.CreateLicenseTab;
var
  Y: Integer;
begin
  FTabLicense := TTabSheet.Create(FPageControl);
  FTabLicense.PageControl := FPageControl;
  FTabLicense.Caption := 'License';
  
  Y := 20;
  
  var LblDemo := TLabel.Create(Self);
  LblDemo.Parent := FTabLicense;
  LblDemo.Caption := '许可证管理演示';
  LblDemo.Font.Style := [fsBold];
  LblDemo.SetBounds(20, Y, 200, 20);
  Inc(Y, 40);
  
  FLicenseStatusPanel := TLicenseStatusPanel.Create(Self);
  FLicenseStatusPanel.Parent := FTabLicense;
  FLicenseStatusPanel.SetBounds(20, Y, 350, 130);
  FLicenseStatusPanel.OnActivateClick := HandleActivateClick;
  Inc(Y, 150);
  
  FBtnActivate := TButton.Create(Self);
  FBtnActivate.Parent := FTabLicense;
  FBtnActivate.Caption := 'Activate License...';
  FBtnActivate.SetBounds(20, Y, 130, 28);
  FBtnActivate.OnClick := HandleActivateClick;
  
  FBtnFeedback := TButton.Create(Self);
  FBtnFeedback.Parent := FTabLicense;
  FBtnFeedback.Caption := 'Send Feedback...';
  FBtnFeedback.SetBounds(160, Y, 130, 28);
  FBtnFeedback.OnClick := HandleFeedbackClick;
end;

procedure TMainForm.CreateWaitTab;
var
  Y: Integer;
begin
  FTabWait := TTabSheet.Create(FPageControl);
  FTabWait.PageControl := FPageControl;
  FTabWait.Caption := 'Wait/Progress';
  
  Y := 20;
  
  var LblDemo := TLabel.Create(Self);
  LblDemo.Parent := FTabWait;
  LblDemo.Caption := '等待窗口和进度演示';
  LblDemo.Font.Style := [fsBold];
  LblDemo.SetBounds(20, Y, 200, 20);
  Inc(Y, 40);
  
  FBtnShowWait := TButton.Create(Self);
  FBtnShowWait.Parent := FTabWait;
  FBtnShowWait.Caption := 'Show Wait Dialog (3s)';
  FBtnShowWait.SetBounds(20, Y, 180, 28);
  FBtnShowWait.OnClick := HandleShowWaitClick;
  Inc(Y, 40);
  
  FBtnShowProgress := TButton.Create(Self);
  FBtnShowProgress.Parent := FTabWait;
  FBtnShowProgress.Caption := 'Show Progress Dialog';
  FBtnShowProgress.SetBounds(20, Y, 180, 28);
  FBtnShowProgress.OnClick := HandleShowProgressClick;
end;

// Event Handlers

procedure TMainForm.HandleSaveConfigClick(Sender: TObject);
begin
  UniBase.Config.SetConfig('test', 'manual_save', DateTimeToStr(Now));
  ShowMessage('Config saved manually at ' + DateTimeToStr(Now));
end;

procedure TMainForm.HandleLanguageChange(Sender: TObject);
begin
  FLblCurrentLang.Caption := 'Current: ' + UniBase.i18n.CurrentLanguage;
end;

procedure TMainForm.HandleLogButtonClick(Sender: TObject);
var
  Level: TLogLevel;
  Msg: string;
begin
  Level := TLogLevel(TButton(Sender).Tag);
  Msg := Format('Test %s message at %s', [TButton(Sender).Caption, TimeToStr(Now)]);
  UniBase.Log.Log(Msg, Level, 'Demo');
end;

procedure TMainForm.HandleClearLogsClick(Sender: TObject);
begin
  FLogListView.Clear;
end;

procedure TMainForm.HandleAddMRUClick(Sender: TObject);
var
  Item: string;
begin
  Item := Trim(FEdtMRUItem.Text);
  if Item = '' then
  begin
    ShowMessage('Please enter an item');
    Exit;
  end;
  
  UniBase.MRU.AddMRU('demo_items', Item, Item);
  FMRUComboBox.Refresh;
  RefreshMRUList;
  FEdtMRUItem.Clear;
end;

procedure TMainForm.HandleClearMRUClick(Sender: TObject);
begin
  UniBase.MRU.ClearMRU('demo_items');
  FMRUComboBox.Refresh;
  RefreshMRUList;
end;

procedure TMainForm.HandleMRUSelect(Sender: TObject);
begin
  if FMRUComboBox.ItemIndex >= 0 then
    ShowMessage('Selected: ' + FMRUComboBox.Text);
end;

procedure TMainForm.HandleThemeChange(Sender: TObject);
begin
  if FThemeComboBox.ItemIndex >= 0 then
    UniBase.Theme.ApplyTheme(FThemeComboBox.Text);
end;

procedure TMainForm.HandleActivateClick(Sender: TObject);
begin
  if TLicenseAuthDialog.Execute(FLicenseStatusPanel.License) then
  begin
    FLicenseStatusPanel.RefreshStatus;
    ShowMessage('License activated!');
  end;
end;

procedure TMainForm.HandleFeedbackClick(Sender: TObject);
begin
  TFeedbackDialog.Execute('', 'UniBase FullDemo', '1.0.0');
end;

procedure TMainForm.HandleShowWaitClick(Sender: TObject);
begin
  TWaitForm.Show('Please wait...');
  Sleep(3000);
  TWaitForm.Hide;
end;

procedure TMainForm.HandleShowProgressClick(Sender: TObject);
var
  I: Integer;
begin
  TWaitForm.Show('Processing...');
  for I := 0 to 100 do
  begin
    TWaitForm.UpdateProgress(I, Format('Processing... %d%%', [I]));
    Sleep(30);
    Application.ProcessMessages;
  end;
  TWaitForm.Hide;
end;

procedure TMainForm.HandleMenuExit(Sender: TObject);
begin
  Close;
end;

procedure TMainForm.HandleMenuAbout(Sender: TObject);
begin
  ShowMessage('UniBase Full Demo v1.0' + sLineBreak +
              'A comprehensive demo of all UniBase features.' + sLineBreak +
              sLineBreak +
              'Copyright (c) 2024 UniBase');
end;

procedure TMainForm.RefreshMRUList;
var
  Items: TArray<TMRUItem>;
  Item: TMRUItem;
  LI: TListItem;
begin
  FLvMRU.Items.Clear;
  Items := UniBase.MRU.GetMRUItems('demo_items', 20);
  for Item in Items do
  begin
    LI := FLvMRU.Items.Add;
    LI.Caption := Item.DisplayName;
    LI.SubItems.Add(DateTimeToStr(Item.LastAccess));
  end;
end;

procedure TMainForm.UpdateStatusBar;
begin
  FStatusBar.Panels[0].Text := 'DB: ' + UniBase.DBPath;
  FStatusBar.Panels[1].Text := 'Lang: ' + UniBase.i18n.CurrentLanguage;
  if UniBase.IsInitialized then
    FStatusBar.Panels[2].Text := 'Ready'
  else
    FStatusBar.Panels[2].Text := 'Not Init';
end;

end.
