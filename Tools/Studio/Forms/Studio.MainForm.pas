{ ============================================================================
  Studio.MainForm - UniBase Studio Main Form
  
  Version: 2.0
  Description: Main interface for UniBase configuration management tool
  ============================================================================ }

unit Studio.MainForm;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  System.IOUtils,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.ExtCtrls,
  Vcl.StdCtrls,
  Vcl.CategoryButtons,
  Vcl.WinXPanels,
  Data.DB,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Error,
  FireDAC.UI.Intf,
  FireDAC.Phys.Intf,
  FireDAC.Stan.Def,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.Phys,
  FireDAC.VCLUI.Wait,
  FireDAC.Comp.Client,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  UniBase.Manager,
  UniBase.i18n,
  Studio.ConfigFrame,
  Studio.LogFrame,
  Studio.HotkeyFrame,
  Studio.ThemeFrame,
  Studio.SQLFrame,
  Studio.QueriesFrame,
  Studio.SchemaFrame,
  Studio.BackupFrame,
  Studio.ImportExportFrame,
  Studio.ProfileFrame,
  Studio.LLMFrame,
  Studio.PromptTemplateFrame,
  Studio.HelpPanel,
  Studio.Resources,
  Studio.i18nInit;

type
  TfrmStudioMain = class(TForm)
    { === Design-time controls (defined in dfm) === }
    pnlTop: TPanel;
    lblTitle: TLabel;
    btnOpenDB: TButton;
    lblCurrentDB: TLabel;
    
    pnlNav: TPanel;
    catNav: TCategoryButtons;
    
    splSplitter: TSplitter;
    
    pnlClient: TPanel;
    cardPanel: TCardPanel;
    cardConfig: TCard;
    cardLog: TCard;
    cardHotkey: TCard;
    cardTheme: TCard;
    cardSQL: TCard;
    cardQueries: TCard;
    cardSchema: TCard;
    cardBackup: TCard;
    cardImportExport: TCard;
    cardProfile: TCard;
    cardLLM: TCard;
    cardPromptTemplate: TCard;
    
    dlgOpenDB: TOpenDialog;

    procedure FormDestroy(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure btnOpenDBClick(Sender: TObject);
    procedure catNavButtonClicked(Sender: TObject; const Button: TButtonItem);
    
  private
    FConnection: TFDConnection;
    FCurrentDBPath: string;
    
    // Embedded Frames
    FConfigFrame: TfraConfig;
    FLogFrame: TfraLog;
    FHotkeyFrame: TfraHotkey;
    FThemeFrame: TfraTheme;
    FSQLFrame: TfraSQLEditor;
    FQueriesFrame: TfraQueries;
    FSchemaFrame: TfraSchemaViewer;
    FBackupFrame: TfraBackupWizard;
    FImportExportFrame: TfraImportExport;
    FProfileFrame: TfraProfiler;
    FLLMFrame: TfraLLM;
    FPromptTemplateFrame: TfraPromptTemplate;
    
    procedure InitNavigation;
    procedure OpenDatabase(const APath: string);
    procedure CloseDatabase;
    procedure ShowCard(ACard: TCard);
    
  public
    property Connection: TFDConnection read FConnection;
    property CurrentDBPath: string read FCurrentDBPath;
  end;

var
  frmStudioMain: TfrmStudioMain;

implementation

{$R *.dfm}

{ TfrmStudioMain }

procedure TfrmStudioMain.FormCreate(Sender: TObject);
var
  HelpLabelConfig: TLabel;
  HelpLabelLogs: TLabel;
  HelpLabelHotkey: TLabel;
  HelpLabelTheme: TLabel;
  HelpLabelSQL: TLabel;
  HelpLabelSchema: TLabel;
  HelpLabelBackup: TLabel;
  HelpLabelImportExport: TLabel;
  HelpLabelProfile: TLabel;
begin
  // Initialize i18n (detect system language)
  InitializeI18n;
  
  // Set title using resource strings
  Caption := TStudioResources.GetString('RSFormCaption');
  lblTitle.Caption := TStudioResources.GetString('RSLblTitle');
  lblCurrentDB.Caption := TStudioResources.GetString('RSNoDBOpened');
  btnOpenDB.Caption := TStudioResources.GetString('RSBtnOpen');
  
  // Create and embed Frames
  FConfigFrame := TfraConfig.Create(Self);
  FConfigFrame.Parent := cardConfig;
  FConfigFrame.Align := alClient;
  
  // Add help label for config page
  HelpLabelConfig := CreateHelpLabel(cardConfig, GetConfigurationHelp);
  HelpLabelConfig.BringToFront;
  
  FLogFrame := TfraLog.Create(Self);
  FLogFrame.Parent := cardLog;
  FLogFrame.Align := alClient;
  
  // Add help label for logs page
  HelpLabelLogs := CreateHelpLabel(cardLog, GetLogsHelp);
  HelpLabelLogs.BringToFront;
  
  // Create and embed Hotkey Frame
  FHotkeyFrame := TfraHotkey.Create(Self);
  FHotkeyFrame.Parent := cardHotkey;
  FHotkeyFrame.Align := alClient;
  
  // Add help label for hotkey page
  HelpLabelHotkey := CreateHelpLabel(cardHotkey, TStudioResources.GetString('RSHelpHotkey'));
  HelpLabelHotkey.BringToFront;
  
  // Create and embed Theme Frame
  FThemeFrame := TfraTheme.Create(Self);
  FThemeFrame.Parent := cardTheme;
  FThemeFrame.Align := alClient;
  
  // Add help label for theme page
  HelpLabelTheme := CreateHelpLabel(cardTheme, TStudioResources.GetString('RSHelpTheme'));
  HelpLabelTheme.BringToFront;
  
  // Create and embed SQL Editor Frame
  FSQLFrame := TfraSQLEditor.Create(Self);
  FSQLFrame.Parent := cardSQL;
  FSQLFrame.Align := alClient;
  
  // Create and embed Queries Frame (DoQry metadata editor)
  FQueriesFrame := TfraQueries.Create(Self);
  FQueriesFrame.Parent := cardQueries;
  FQueriesFrame.Align := alClient;
  
  // Add help label for SQL page
  HelpLabelSQL := CreateHelpLabel(cardSQL, TStudioResources.GetString('RSHelpSQL'));
  HelpLabelSQL.BringToFront;
  
  // Create and embed Schema Viewer Frame
  FSchemaFrame := TfraSchemaViewer.Create(Self);
  FSchemaFrame.Parent := cardSchema;
  FSchemaFrame.Align := alClient;
  
  // Add help label for Schema page
  HelpLabelSchema := CreateHelpLabel(cardSchema, TStudioResources.GetString('RSHelpSchema'));
  HelpLabelSchema.BringToFront;
  
  // Create and embed Backup Wizard Frame
  FBackupFrame := TfraBackupWizard.Create(Self);
  FBackupFrame.Parent := cardBackup;
  FBackupFrame.Align := alClient;
  
  // Add help label for Backup page
  HelpLabelBackup := CreateHelpLabel(cardBackup, TStudioResources.GetString('RSHelpBackup'));
  HelpLabelBackup.BringToFront;
  
  // Create and embed Import/Export Frame
  FImportExportFrame := TfraImportExport.Create(Self);
  FImportExportFrame.Parent := cardImportExport;
  FImportExportFrame.Align := alClient;
  
  // Add help label for Import/Export page
  HelpLabelImportExport := CreateHelpLabel(cardImportExport, TStudioResources.GetString('RSHelpImportExport'));
  HelpLabelImportExport.BringToFront;
  
  // Create and embed Profiler Frame
  FProfileFrame := TfraProfiler.Create(Self);
  FProfileFrame.Parent := cardProfile;
  FProfileFrame.Align := alClient;
  
  // Add help label for Profiler page
  HelpLabelProfile := CreateHelpLabel(cardProfile, TStudioResources.GetString('RSHelpProfiler'));
  HelpLabelProfile.BringToFront;
  
  // Create and embed LLM Frame
  FLLMFrame := TfraLLM.Create(Self);
  FLLMFrame.Parent := cardLLM;
  FLLMFrame.Align := alClient;
  
  // Create and embed Prompt Template Frame
  FPromptTemplateFrame := TfraPromptTemplate.Create(Self);
  FPromptTemplateFrame.Parent := cardPromptTemplate;
  FPromptTemplateFrame.Align := alClient;
  
  // Initialize navigation
  InitNavigation;
  
  // Show config page by default
  cardPanel.ActiveCard := cardConfig;
end;

procedure TfrmStudioMain.FormDestroy(Sender: TObject);
begin
  CloseDatabase;
end;

procedure TfrmStudioMain.InitNavigation;
var
  Cat: TButtonCategory;
  Btn: TButtonItem;
  
  function RS(const Key: string): string;
  begin
    Result := TStudioResources.GetString(Key);
  end;
  
begin
  catNav.Categories.Clear;
  
  // Configuration category
  Cat := catNav.Categories.Add;
  Cat.Caption := RS('RSMenuConfiguration');
  Cat.Color := clWhite;
  
  Btn := Cat.Items.Add;
  Btn.Caption := RS('RSMenuSettings');
  Btn.Data := Pointer(cardConfig);
  
  Btn := Cat.Items.Add;
  Btn.Caption := RS('RSMenuHotkeys');
  Btn.Data := Pointer(cardHotkey);
  
  Btn := Cat.Items.Add;
  Btn.Caption := RS('RSMenuThemes');
  Btn.Data := Pointer(cardTheme);
  
  // Data category
  Cat := catNav.Categories.Add;
  Cat.Caption := RS('RSMenuData');
  Cat.Color := clWhite;
  
  Btn := Cat.Items.Add;
  Btn.Caption := RS('RSMenuSQLQuery');
  Btn.Data := Pointer(cardSQL);
  
  Btn := Cat.Items.Add;
  Btn.Caption := RS('RSMenuQueries');
  Btn.Data := Pointer(cardQueries);
  
  Btn := Cat.Items.Add;
  Btn.Caption := RS('RSMenuSchema');
  Btn.Data := Pointer(cardSchema);
  
  Btn := Cat.Items.Add;
  Btn.Caption := RS('RSMenuLogs');
  Btn.Data := Pointer(cardLog);
  
  Btn := Cat.Items.Add;
  Btn.Caption := RS('RSMenuBackup');
  Btn.Data := Pointer(cardBackup);
  
  Btn := Cat.Items.Add;
  Btn.Caption := RS('RSMenuImportExport');
  Btn.Data := Pointer(cardImportExport);
  
  Btn := Cat.Items.Add;
  Btn.Caption := RS('RSMenuProfiler');
  Btn.Data := Pointer(cardProfile);
  
  // AI/LLM category
  Cat := catNav.Categories.Add;
  Cat.Caption := RS('RSMenuAI');
  Cat.Color := clWhite;
  
  Btn := Cat.Items.Add;
  Btn.Caption := RS('RSMenuLLM');
  Btn.Data := Pointer(cardLLM);
  
  Btn := Cat.Items.Add;
  Btn.Caption := RS('RSMenuPromptTemplates');
  Btn.Data := Pointer(cardPromptTemplate);
end;

procedure TfrmStudioMain.btnOpenDBClick(Sender: TObject);
begin
  if dlgOpenDB.Execute then
    OpenDatabase(dlgOpenDB.FileName);
end;

procedure TfrmStudioMain.catNavButtonClicked(Sender: TObject; const Button: TButtonItem);
var
  TargetCard: TCard;
begin
  // Use Data pointer to get the card directly
  if Button.Data <> nil then
  begin
    TargetCard := TCard(Button.Data);
    ShowCard(TargetCard);
  end;
end;

procedure TfrmStudioMain.ShowCard(ACard: TCard);
begin
  if ACard = nil then Exit;
  
  cardPanel.ActiveCard := ACard;
  
  // Refresh data for the active card's frame
  if ACard = cardConfig then
    FConfigFrame.RefreshData
  else if ACard = cardLog then
    FLogFrame.RefreshData
  else if ACard = cardHotkey then
    FHotkeyFrame.RefreshData
  else if ACard = cardTheme then
    FThemeFrame.RefreshData
  else if ACard = cardSQL then
    FSQLFrame.RefreshData
  else if ACard = cardQueries then
    FQueriesFrame.RefreshData
  else if ACard = cardSchema then
    FSchemaFrame.RefreshData
  else if ACard = cardBackup then
    FBackupFrame.RefreshData
  else if ACard = cardImportExport then
    FImportExportFrame.RefreshData
  else if ACard = cardProfile then
    FProfileFrame.RefreshData
  else if ACard = cardLLM then
    FLLMFrame.RefreshData
  else if ACard = cardPromptTemplate then
    FPromptTemplateFrame.RefreshData;
end;

procedure TfrmStudioMain.OpenDatabase(const APath: string);
begin
  CloseDatabase;
  
  if not FileExists(APath) then
  begin
    ShowMessage('Database file not found: ' + APath);
    Exit;
  end;
  
  FConnection := TFDConnection.Create(Self);
  FConnection.DriverName := 'SQLite';
  FConnection.Params.Database := APath;
  FConnection.Params.Values['LockingMode'] := 'Normal';
  FConnection.Params.Values['JournalMode'] := 'WAL';
  FConnection.LoginPrompt := False;
  
  try
    FConnection.Open;
    FCurrentDBPath := APath;
    
    lblCurrentDB.Caption := ExtractFileName(APath);
    lblCurrentDB.Font.Color := clWindowText;
    Caption := 'UniBase Studio - ' + ExtractFileName(APath);
    
    // Pass connection to Frames
    FConfigFrame.SetConnection(FConnection);
    FLogFrame.SetConnection(FConnection);
    FHotkeyFrame.SetConnection(FConnection);
    FThemeFrame.SetConnection(FConnection);
    FSQLFrame.SetConnection(FConnection);
    FQueriesFrame.SetConnection(FConnection);
    FSchemaFrame.SetConnection(FConnection);
    FBackupFrame.SetConnection(FConnection);
    FBackupFrame.SetDatabasePath(APath);
    FImportExportFrame.SetConnection(FConnection);
    FProfileFrame.SetConnection(FConnection);
    FLLMFrame.SetConnection(FConnection);
    FPromptTemplateFrame.SetConnection(FConnection);
    
    // Refresh data
    FConfigFrame.RefreshData;
    FLogFrame.RefreshData;
    FHotkeyFrame.RefreshData;
    FThemeFrame.RefreshData;
    FSQLFrame.RefreshData;
    FSchemaFrame.RefreshData;
    FBackupFrame.RefreshData;
    FImportExportFrame.RefreshData;
    FProfileFrame.RefreshData;
    FLLMFrame.RefreshData;
    FPromptTemplateFrame.RefreshData;
  except
    on E: Exception do
    begin
      ShowMessage('Failed to open database: ' + E.Message);
      FreeAndNil(FConnection);
    end;
  end;
end;

procedure TfrmStudioMain.CloseDatabase;
begin
  // Disconnect all frames BEFORE freeing connection
  if Assigned(FConfigFrame) then FConfigFrame.SetConnection(nil);
  if Assigned(FLogFrame) then FLogFrame.SetConnection(nil);
  if Assigned(FHotkeyFrame) then FHotkeyFrame.SetConnection(nil);
  if Assigned(FThemeFrame) then FThemeFrame.SetConnection(nil);
  if Assigned(FSQLFrame) then FSQLFrame.SetConnection(nil);
  if Assigned(FQueriesFrame) then FQueriesFrame.SetConnection(nil);
  if Assigned(FSchemaFrame) then FSchemaFrame.SetConnection(nil);
  if Assigned(FBackupFrame) then FBackupFrame.SetConnection(nil);
  if Assigned(FImportExportFrame) then FImportExportFrame.SetConnection(nil);
  if Assigned(FProfileFrame) then FProfileFrame.SetConnection(nil);
  if Assigned(FLLMFrame) then FLLMFrame.SetConnection(nil);
  if Assigned(FPromptTemplateFrame) then FPromptTemplateFrame.SetConnection(nil);
  
  // Now safely close and free connection
  if FConnection <> nil then
  begin
    FConnection.Close;
    FreeAndNil(FConnection);
  end;
  
  FCurrentDBPath := '';
  lblCurrentDB.Caption := TStudioResources.GetString('RSNoDBOpened');
  lblCurrentDB.Font.Color := clGrayText;
  Caption := TStudioResources.GetString('RSFormCaption');
end;

end.
