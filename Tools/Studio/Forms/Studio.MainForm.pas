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
  Studio.SchemaFrame,
  Studio.BackupFrame,
  Studio.ImportExportFrame,
  Studio.ProfileFrame,
  Studio.HelpPanel;

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
    cardSchema: TCard;
    cardBackup: TCard;
    cardImportExport: TCard;
    cardProfile: TCard;
    
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
    FSchemaFrame: TfraSchemaViewer;
    FBackupFrame: TfraBackupWizard;
    FImportExportFrame: TfraImportExport;
    FProfileFrame: TfraProfiler;
    
    procedure InitNavigation;
    procedure OpenDatabase(const APath: string);
    procedure CloseDatabase;
    procedure ShowCard(const ACardName: string);
    
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
  UB: TUniBaseManager;
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
  // Get UniBase singleton
  UB := UniBase.Manager.UniBase;
  
  // Set default title
  Caption := 'UniBase Studio';
  lblTitle.Caption := 'UniBase Studio';
  lblCurrentDB.Caption := 'No DB Opened';
  btnOpenDB.Caption := 'Open Database...';
  
  // If UniBase is initialized, use i18n translation
  if UB.IsInitialized and (UB.I18n <> nil) then
  begin
    lblCurrentDB.Caption := UB.I18n.Translate('No DB Opened');
    btnOpenDB.Caption := UB.I18n.Translate('Open Database...');
  end;
  
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
  HelpLabelHotkey := CreateHelpLabel(cardHotkey, 
    'Hotkey Editor: Customize keyboard shortcuts for application actions.'#13#10 +
    '- Double-click or press F2 to edit a shortcut'#13#10 +
    '- Press new key combination to assign'#13#10 +
    '- Press Delete to clear a shortcut'#13#10 +
    '- Conflicts are detected automatically');
  HelpLabelHotkey.BringToFront;
  
  // Create and embed Theme Frame
  FThemeFrame := TfraTheme.Create(Self);
  FThemeFrame.Parent := cardTheme;
  FThemeFrame.Align := alClient;
  
  // Add help label for theme page
  HelpLabelTheme := CreateHelpLabel(cardTheme,
    'Theme Editor: Preview and switch application themes.'#13#10 +
    '- Select a theme to preview its appearance'#13#10 +
    '- Double-click or click Apply to switch themes'#13#10 +
    '- Dark/Light indicator shows theme type');
  HelpLabelTheme.BringToFront;
  
  // Create and embed SQL Editor Frame
  FSQLFrame := TfraSQLEditor.Create(Self);
  FSQLFrame.Parent := cardSQL;
  FSQLFrame.Align := alClient;
  
  // Add help label for SQL page
  HelpLabelSQL := CreateHelpLabel(cardSQL,
    'SQL Query Editor: Execute SQL queries on the database.'#13#10 +
    '- Press F5 or Ctrl+Enter to execute'#13#10 +
    '- Results shown in grid with export to CSV'#13#10 +
    '- Query history saved for quick recall');
  HelpLabelSQL.BringToFront;
  
  // Create and embed Schema Viewer Frame
  FSchemaFrame := TfraSchemaViewer.Create(Self);
  FSchemaFrame.Parent := cardSchema;
  FSchemaFrame.Align := alClient;
  
  // Add help label for Schema page
  HelpLabelSchema := CreateHelpLabel(cardSchema,
    'Schema Viewer: Explore database structure.'#13#10 +
    '- Click table to view columns, indexes, foreign keys'#13#10 +
    '- DDL tab shows CREATE TABLE statement'#13#10 +
    '- Tree structure for easy navigation');
  HelpLabelSchema.BringToFront;
  
  // Create and embed Backup Wizard Frame
  FBackupFrame := TfraBackupWizard.Create(Self);
  FBackupFrame.Parent := cardBackup;
  FBackupFrame.Align := alClient;
  
  // Add help label for Backup page
  HelpLabelBackup := CreateHelpLabel(cardBackup,
    'Backup/Restore Wizard: Manage database backups.'#13#10 +
    '- Create backups with optional compression'#13#10 +
    '- Restore from previous backups'#13#10 +
    '- Auto-backup before restore for safety');
  HelpLabelBackup.BringToFront;
  
  // Create and embed Import/Export Frame
  FImportExportFrame := TfraImportExport.Create(Self);
  FImportExportFrame.Parent := cardImportExport;
  FImportExportFrame.Align := alClient;
  
  // Add help label for Import/Export page
  HelpLabelImportExport := CreateHelpLabel(cardImportExport,
    'Data Import/Export: Transfer data to/from files.'#13#10 +
    '- Export to CSV, JSON, XML formats'#13#10 +
    '- Import with preview and validation'#13#10 +
    '- Batch export multiple tables');
  HelpLabelImportExport.BringToFront;
  
  // Create and embed Profiler Frame
  FProfileFrame := TfraProfiler.Create(Self);
  FProfileFrame.Parent := cardProfile;
  FProfileFrame.Align := alClient;
  
  // Add help label for Profiler page
  HelpLabelProfile := CreateHelpLabel(cardProfile,
    'Performance Profiler: Analyze database performance.'#13#10 +
    '- Table statistics and row counts'#13#10 +
    '- Query plan analysis (EXPLAIN)'#13#10 +
    '- Index overview and suggestions');
  HelpLabelProfile.BringToFront;
  
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
begin
  catNav.Categories.Clear;
  
  // Configuration category
  Cat := catNav.Categories.Add;
  Cat.Caption := 'Configuration';
  Cat.Color := clWhite;
  
  Btn := Cat.Items.Add;
  Btn.Caption := 'Settings';
  Btn.Hint := 'cardConfig';
  
  Btn := Cat.Items.Add;
  Btn.Caption := 'Hotkeys';
  Btn.Hint := 'cardHotkey';
  
  Btn := Cat.Items.Add;
  Btn.Caption := 'Themes';
  Btn.Hint := 'cardTheme';
  
  // Data category
  Cat := catNav.Categories.Add;
  Cat.Caption := 'Data';
  Cat.Color := clWhite;
  
  Btn := Cat.Items.Add;
  Btn.Caption := 'SQL Query';
  Btn.Hint := 'cardSQL';
  
  Btn := Cat.Items.Add;
  Btn.Caption := 'Schema';
  Btn.Hint := 'cardSchema';
  
  Btn := Cat.Items.Add;
  Btn.Caption := 'Logs';
  Btn.Hint := 'cardLog';
  
  Btn := Cat.Items.Add;
  Btn.Caption := 'Backup';
  Btn.Hint := 'cardBackup';
  
  Btn := Cat.Items.Add;
  Btn.Caption := 'Import/Export';
  Btn.Hint := 'cardImportExport';
  
  Btn := Cat.Items.Add;
  Btn.Caption := 'Profiler';
  Btn.Hint := 'cardProfile';
end;

procedure TfrmStudioMain.btnOpenDBClick(Sender: TObject);
begin
  if dlgOpenDB.Execute then
    OpenDatabase(dlgOpenDB.FileName);
end;

procedure TfrmStudioMain.catNavButtonClicked(Sender: TObject; const Button: TButtonItem);
begin
  ShowCard(Button.Hint);
end;

procedure TfrmStudioMain.ShowCard(const ACardName: string);
begin
  if ACardName = 'cardConfig' then
  begin
    cardPanel.ActiveCard := cardConfig;
    FConfigFrame.RefreshData;
  end
  else if ACardName = 'cardLog' then
  begin
    cardPanel.ActiveCard := cardLog;
    FLogFrame.RefreshData;
  end
  else if ACardName = 'cardHotkey' then
  begin
    cardPanel.ActiveCard := cardHotkey;
    FHotkeyFrame.RefreshData;
  end
  else if ACardName = 'cardTheme' then
  begin
    cardPanel.ActiveCard := cardTheme;
    FThemeFrame.RefreshData;
  end
  else if ACardName = 'cardSQL' then
  begin
    cardPanel.ActiveCard := cardSQL;
    FSQLFrame.RefreshData;
  end
  else if ACardName = 'cardSchema' then
  begin
    cardPanel.ActiveCard := cardSchema;
    FSchemaFrame.RefreshData;
  end
  else if ACardName = 'cardBackup' then
  begin
    cardPanel.ActiveCard := cardBackup;
    FBackupFrame.RefreshData;
  end
  else if ACardName = 'cardImportExport' then
  begin
    cardPanel.ActiveCard := cardImportExport;
    FImportExportFrame.RefreshData;
  end
  else if ACardName = 'cardProfile' then
  begin
    cardPanel.ActiveCard := cardProfile;
    FProfileFrame.RefreshData;
  end;
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
    FSchemaFrame.SetConnection(FConnection);
    FBackupFrame.SetConnection(FConnection);
    FBackupFrame.SetDatabasePath(APath);
    FImportExportFrame.SetConnection(FConnection);
    FProfileFrame.SetConnection(FConnection);
    
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
  if FConnection <> nil then
  begin
    FConnection.Close;
    FreeAndNil(FConnection);
  end;
  
  FCurrentDBPath := '';
  lblCurrentDB.Caption := 'No DB Opened';
  lblCurrentDB.Font.Color := clGrayText;
  Caption := 'UniBase Studio';
end;

end.
