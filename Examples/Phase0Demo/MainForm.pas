unit MainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  FireDAC.VCLUI.Wait, FireDAC.Comp.UI,
  UniBase.Manager, UniBase.Config, UniBase.i18n, UniBase.FormState, UniBase.Types,
  UniBase.VCL.UIHelper;

type
  TfrmMain = class(TForm)
    FDGUIxWaitCursor1: TFDGUIxWaitCursor;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    // UI Controls
    pnlTop: TPanel;
    lblConfig: TLabel;
    edtConfig: TEdit;
    btnSaveConfig: TButton;
    
    pnlLang: TPanel;
    lblLang: TLabel;
    cboLang: TComboBox;
    btnSwitchLang: TButton;
    
    pnlTrans: TPanel;
    lblTransSource: TLabel;
    lblTransResult: TLabel;
    
    mmoLog: TMemo;
    pnlHelp: TPanel;
    mmoHelp: TMemo;
    
    // Core Modules
    FConfig: TUniBaseConfig;
    FI18n: TUniBaseI18n;
    FFormState: TUniBaseFormState;
    
    procedure InitializeUI;
    procedure Log(const Msg: string);
    procedure UpdateTranslations;
    
    // Event Handlers
    procedure OnBtnSaveConfigClick(Sender: TObject);
    procedure OnBtnSwitchLangClick(Sender: TObject);
    procedure OnLanguageChanged(Sender: TObject);
    procedure OnConfigChanged(Sender: TObject; const Key, OldValue, NewValue: string);
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

{ TfrmMain }

procedure TfrmMain.FormCreate(Sender: TObject);
var
  Langs: TLanguageInfoArray;
  Lang: TLanguageInfo;
begin
  // Try to enable Mica Effect (Windows 11)
  if TUniBaseUIHelper.ApplyMicaEffect(Self) then
  begin
    // If Mica enabled, make controls transparent where possible
    Self.Color := clBlack; // Or let OS handle it
  end;

  InitializeUI;
  
  // Initialize Modules
  if UniBase.Manager.UniBase.IsInitialized then
  begin
    Log('UniBase Initialized.');
    Log('Root Path: ' + UniBase.Manager.UniBase.RootPath);
    
    // Instantiate Modules
    FConfig := TUniBaseConfig.Create(UniBase.Manager.UniBase.ConfigDB, UniBase.Manager.UniBase.Lock);
    FConfig.OnConfigChanged := OnConfigChanged;
    
    FI18n := TUniBaseI18n.Create(UniBase.Manager.UniBase.ConfigDB, UniBase.Manager.UniBase.Lock);
    FI18n.OnLanguageChanged := OnLanguageChanged;
    
    FFormState := TUniBaseFormState.Create(UniBase.Manager.UniBase.ConfigDB, UniBase.Manager.UniBase.Lock);
    
    // Load initial data
    edtConfig.Text := FConfig.GetConfig('Demo.TestValue', 'Default Value');
    
    // Setup Languages
    FI18n.CurrentLanguage := FConfig.GetConfig('App.Language', 'en-US');
    Log('Current Language: ' + FI18n.CurrentLanguage);
    
    // Populate Language Combo
    Langs := FI18n.GetAvailableLanguages;
    for Lang in Langs do
    begin
      // Add Name=Code
      cboLang.Items.Add(Lang.LangName + '=' + Lang.LangCode);
      if Lang.LangCode = FI18n.CurrentLanguage then
        cboLang.ItemIndex := cboLang.Items.Count - 1;
    end;
    
    UpdateTranslations;
  end
  else
  begin
    Log('UniBase NOT Initialized! Error: ' + InitErrorCodeToStr(UniBase.Manager.UniBase.InitErrorCode));
  end;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  if Assigned(FFormState) then FFormState.Free;
  if Assigned(FI18n) then FI18n.Free;
  if Assigned(FConfig) then FConfig.Free;
end;

procedure TfrmMain.FormShow(Sender: TObject);
var
  State: TFormStateData;
begin
  if Assigned(FFormState) then
  begin
    if FFormState.RestoreState(Self.Name, State) then
    begin
      Self.Left := State.Left;
      Self.Top := State.Top;
      Self.Width := State.Width;
      Self.Height := State.Height;
      
      if State.WindowState = 2 then
        Self.WindowState := wsMaximized;
        
      Log('Form state restored.');
    end;
  end;
end;

procedure TfrmMain.FormClose(Sender: TObject; var Action: TCloseAction);
var
  State: TFormStateData;
begin
  if Assigned(FFormState) then
  begin
    State.Left := Self.Left;
    State.Top := Self.Top;
    State.Width := Self.Width;
    State.Height := Self.Height;
    
    case Self.WindowState of
      wsMaximized: State.WindowState := 2;
      wsMinimized: State.WindowState := 1;
      else State.WindowState := 0;
    end;
    
    State.MonitorIndex := Self.Monitor.MonitorNum;
    State.Extra := '';
    
    FFormState.SaveState(Self.Name, State);
  end;
end;

procedure TfrmMain.InitializeUI;
begin
  // Top Panel (Config)
  pnlTop := TPanel.Create(Self);
  pnlTop.Parent := Self;
  pnlTop.Align := alTop;
  pnlTop.Height := 50;
  pnlTop.Caption := '';
  pnlTop.BevelOuter := bvNone;
  
  lblConfig := TLabel.Create(Self);
  lblConfig.Parent := pnlTop;
  lblConfig.Left := 10;
  lblConfig.Top := 18;
  lblConfig.Caption := 'Config (Demo.TestValue):';
  
  edtConfig := TEdit.Create(Self);
  edtConfig.Parent := pnlTop;
  edtConfig.Left := 160;
  edtConfig.Top := 15;
  edtConfig.Width := 200;
  
  btnSaveConfig := TButton.Create(Self);
  btnSaveConfig.Parent := pnlTop;
  btnSaveConfig.Left := 370;
  btnSaveConfig.Top := 13;
  btnSaveConfig.Caption := 'Save Config';
  btnSaveConfig.OnClick := OnBtnSaveConfigClick;
  
  // Lang Panel
  pnlLang := TPanel.Create(Self);
  pnlLang.Parent := Self;
  pnlLang.Align := alTop;
  pnlLang.Height := 50;
  pnlLang.Caption := '';
  pnlLang.BevelOuter := bvNone;
  
  lblLang := TLabel.Create(Self);
  lblLang.Parent := pnlLang;
  lblLang.Left := 10;
  lblLang.Top := 18;
  lblLang.Caption := 'Language:';
  
  cboLang := TComboBox.Create(Self);
  cboLang.Parent := pnlLang;
  cboLang.Left := 80;
  cboLang.Top := 15;
  cboLang.Width := 200;
  cboLang.Style := csDropDownList;
  
  btnSwitchLang := TButton.Create(Self);
  btnSwitchLang.Parent := pnlLang;
  btnSwitchLang.Left := 300;
  btnSwitchLang.Top := 13;
  btnSwitchLang.Caption := 'Switch Language';
  btnSwitchLang.OnClick := OnBtnSwitchLangClick;
  
  // Translation Demo Panel
  pnlTrans := TPanel.Create(Self);
  pnlTrans.Parent := Self;
  pnlTrans.Align := alTop;
  pnlTrans.Height := 80;
  pnlTrans.Caption := '';
  pnlTrans.BevelOuter := bvNone;
  
  lblTransSource := TLabel.Create(Self);
  lblTransSource.Parent := pnlTrans;
  lblTransSource.Left := 10;
  lblTransSource.Top := 10;
  lblTransSource.Caption := 'Source: "Welcome"';
  
  lblTransResult := TLabel.Create(Self);
  lblTransResult.Parent := pnlTrans;
  lblTransResult.Left := 10;
  lblTransResult.Top := 40;
  lblTransResult.Caption := 'Translated: ...';
  lblTransResult.Font.Size := 14;
  
  // Log Memo
  mmoLog := TMemo.Create(Self);
  mmoLog.Parent := Self;
  mmoLog.Align := alClient;
  mmoLog.ScrollBars := ssVertical;
  
  // Help Panel
  pnlHelp := TPanel.Create(Self);
  pnlHelp.Parent := Self;
  pnlHelp.Align := alRight;
  pnlHelp.Width := 220;
  pnlHelp.BevelOuter := bvNone;
  pnlHelp.Color := clWhite;
  pnlHelp.ParentBackground := False;
  
  mmoHelp := TMemo.Create(Self);
  mmoHelp.Parent := pnlHelp;
  mmoHelp.Align := alClient;
  mmoHelp.ReadOnly := True;
  mmoHelp.Color := $00F0F0F0; // Light Gray
  mmoHelp.Font.Size := 9;
  mmoHelp.Lines.Add('UniBase Phase 0 Demo Features:');
  mmoHelp.Lines.Add('');
  mmoHelp.Lines.Add('1. Initialization');
  mmoHelp.Lines.Add('   - Auto connects to SQLite DB.');
  mmoHelp.Lines.Add('   - Creates tables if missing.');
  mmoHelp.Lines.Add('');
  mmoHelp.Lines.Add('2. Configuration');
  mmoHelp.Lines.Add('   - Edit "Config" value.');
  mmoHelp.Lines.Add('   - Click "Save" to persist.');
  mmoHelp.Lines.Add('');
  mmoHelp.Lines.Add('3. i18n (Internationalization)');
  mmoHelp.Lines.Add('   - Switch Language (en-US/zh-CN).');
  mmoHelp.Lines.Add('   - "Welcome" text translates automatically.');
  mmoHelp.Lines.Add('');
  mmoHelp.Lines.Add('4. Form State');
  mmoHelp.Lines.Add('   - Resize/Move window.');
  mmoHelp.Lines.Add('   - Restart app to see it restore.');
  mmoHelp.Lines.Add('');
  mmoHelp.Lines.Add('5. UI Effect');
  mmoHelp.Lines.Add('   - Windows 11 Mica Effect enabled if supported.');
  mmoHelp.Lines.Add('');
  mmoHelp.Lines.Add('Note: Check mmoLog for internal events.');
  mmoHelp.Lines.Add('');
  mmoHelp.Lines.Add('Troubleshooting:');
  mmoHelp.Lines.Add('- If only English is shown, delete config.db and restart.');
end;

procedure TfrmMain.Log(const Msg: string);
begin
  mmoLog.Lines.Add(Format('[%s] %s', [FormatDateTime('HH:mm:ss', Now), Msg]));
end;

procedure TfrmMain.UpdateTranslations;
begin
  if not Assigned(FI18n) then Exit;
  
  lblTransResult.Caption := 'Translated: ' + FI18n.Translate('Welcome');
end;

procedure TfrmMain.OnBtnSaveConfigClick(Sender: TObject);
begin
  if Assigned(FConfig) then
  begin
    FConfig.SetConfig('Demo.TestValue', edtConfig.Text);
    Log('Config saved.');
  end;
end;

procedure TfrmMain.OnBtnSwitchLangClick(Sender: TObject);
var
  NewLang: string;
begin
  if (cboLang.ItemIndex >= 0) and Assigned(FI18n) then
  begin
    NewLang := cboLang.Items.ValueFromIndex[cboLang.ItemIndex];
    if NewLang = '' then 
       NewLang := cboLang.Items[cboLang.ItemIndex];
       
    FI18n.CurrentLanguage := NewLang;
    FConfig.SetConfig('App.Language', NewLang);
  end;
end;

procedure TfrmMain.OnLanguageChanged(Sender: TObject);
begin
  Log('Language changed to: ' + FI18n.CurrentLanguage);
  UpdateTranslations;
end;

procedure TfrmMain.OnConfigChanged(Sender: TObject; const Key, OldValue, NewValue: string);
begin
  Log(Format('Config Changed: %s = "%s" -> "%s"', [Key, OldValue, NewValue]));
end;

end.
