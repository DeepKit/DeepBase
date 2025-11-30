{ ============================================================================
  Studio.BackupFrame - Database Backup/Restore Wizard Frame
  
  Version: 1.0
  Description: Manages database backups with create, restore, and delete
               functionality. Stores backups in a dedicated folder with
               timestamp naming and metadata tracking.
  ============================================================================ }

unit Studio.BackupFrame;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Types,
  System.Classes,
  System.Generics.Collections,
  System.Generics.Defaults,
  System.UITypes,
  System.IOUtils,
  System.DateUtils,
  System.Zip,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  FireDAC.Comp.Client;

type
  TBackupInfo = record
    FileName: string;
    FullPath: string;
    CreatedAt: TDateTime;
    SizeBytes: Int64;
    Description: string;
    IsCompressed: Boolean;
  end;

  TfraBackupWizard = class(TFrame)
    pnlToolbar: TPanel;
    lblTitle: TLabel;
    btnCreateBackup: TButton;
    btnRestoreBackup: TButton;
    btnDeleteBackup: TButton;
    btnRefresh: TButton;
    pnlMain: TPanel;
    lblBackups: TLabel;
    lvBackups: TListView;
    pnlDetails: TPanel;
    lblDetailsTitle: TLabel;
    lblFileName: TLabel;
    lblFileNameValue: TLabel;
    lblCreated: TLabel;
    lblCreatedValue: TLabel;
    lblSize: TLabel;
    lblSizeValue: TLabel;
    lblDescription: TLabel;
    mmoDescription: TMemo;
    chkCompress: TCheckBox;
    pnlStatus: TPanel;
    lblStatus: TLabel;
    prgProgress: TProgressBar;
    procedure btnCreateBackupClick(Sender: TObject);
    procedure btnRestoreBackupClick(Sender: TObject);
    procedure btnDeleteBackupClick(Sender: TObject);
    procedure btnRefreshClick(Sender: TObject);
    procedure lvBackupsSelectItem(Sender: TObject; Item: TListItem;
      Selected: Boolean);
  private
    FConnection: TFDConnection;
    FCurrentDBPath: string;
    FBackupFolder: string;
    FBackups: TList<TBackupInfo>;
    
    procedure LoadBackups;
    procedure RefreshBackupList;
    procedure CreateBackup;
    procedure RestoreBackup(const ABackupPath: string);
    procedure DeleteBackup(const ABackupPath: string);
    procedure UpdateDetails(const ABackup: TBackupInfo);
    procedure ClearDetails;
    procedure SetStatus(const AText: string; AIsError: Boolean = False);
    procedure SetProgress(AValue: Integer; AMax: Integer = 100);
    function GetBackupFolder: string;
    function GetSelectedBackup: TBackupInfo;
    function FormatFileSize(ABytes: Int64): string;
    procedure SaveBackupMetadata(const ABackupPath, ADescription: string);
    function LoadBackupMetadata(const ABackupPath: string): string;
    
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    procedure SetConnection(AConnection: TFDConnection);
    procedure SetDatabasePath(const APath: string);
    procedure RefreshData;
  end;

implementation

{$R *.dfm}

const
  BACKUP_EXT = '.db.bak';
  BACKUP_ZIP_EXT = '.db.zip';
  METADATA_EXT = '.meta';

{ TfraBackupWizard }

constructor TfraBackupWizard.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FBackups := TList<TBackupInfo>.Create;
  FBackupFolder := '';
  FCurrentDBPath := '';
  
  // Initialize ListView
  with lvBackups.Columns.Add do
  begin
    Caption := 'Backup Name';
    Width := 250;
  end;
  with lvBackups.Columns.Add do
  begin
    Caption := 'Created';
    Width := 150;
  end;
  with lvBackups.Columns.Add do
  begin
    Caption := 'Size';
    Width := 80;
  end;
  with lvBackups.Columns.Add do
  begin
    Caption := 'Type';
    Width := 80;
  end;
  
  lvBackups.ViewStyle := vsReport;
  lvBackups.RowSelect := True;
  lvBackups.ReadOnly := True;
  lvBackups.HideSelection := False;
  
  // Description memo
  mmoDescription.ReadOnly := False;
  mmoDescription.ScrollBars := ssVertical;
  
  // Progress bar
  prgProgress.Visible := False;
  
  chkCompress.Checked := True;
  
  SetStatus('Ready - Open a database to manage backups');
end;

destructor TfraBackupWizard.Destroy;
begin
  FBackups.Free;
  inherited;
end;

procedure TfraBackupWizard.SetConnection(AConnection: TFDConnection);
begin
  FConnection := AConnection;
  
  if Assigned(FConnection) and FConnection.Connected then
    SetStatus('Connected')
  else
    SetStatus('No database connection', True);
end;

procedure TfraBackupWizard.SetDatabasePath(const APath: string);
begin
  FCurrentDBPath := APath;
  FBackupFolder := GetBackupFolder;
  
  if FCurrentDBPath <> '' then
    LoadBackups;
end;

procedure TfraBackupWizard.RefreshData;
begin
  LoadBackups;
end;

function TfraBackupWizard.GetBackupFolder: string;
var
  DBFolder: string;
begin
  if FCurrentDBPath = '' then
    Result := ''
  else
  begin
    DBFolder := ExtractFilePath(FCurrentDBPath);
    Result := TPath.Combine(DBFolder, 'backups');
    
    // Create backup folder if it doesn't exist
    if not TDirectory.Exists(Result) then
      TDirectory.CreateDirectory(Result);
  end;
end;

procedure TfraBackupWizard.LoadBackups;
var
  Files: TStringDynArray;
  FileName, FullPath: string;
  Backup: TBackupInfo;
  FileInfo: TSearchRec;
begin
  FBackups.Clear;
  
  if (FBackupFolder = '') or not TDirectory.Exists(FBackupFolder) then
  begin
    RefreshBackupList;
    Exit;
  end;
  
  // Find all backup files
  Files := TDirectory.GetFiles(FBackupFolder, '*' + BACKUP_EXT);
  for FileName in Files do
  begin
    FullPath := FileName;
    if FindFirst(FullPath, faAnyFile, FileInfo) = 0 then
    begin
      Backup.FileName := ExtractFileName(FileName);
      Backup.FullPath := FullPath;
      Backup.CreatedAt := FileInfo.TimeStamp;
      Backup.SizeBytes := FileInfo.Size;
      Backup.Description := LoadBackupMetadata(FullPath);
      Backup.IsCompressed := False;
      FBackups.Add(Backup);
      FindClose(FileInfo);
    end;
  end;
  
  // Find compressed backups
  Files := TDirectory.GetFiles(FBackupFolder, '*' + BACKUP_ZIP_EXT);
  for FileName in Files do
  begin
    FullPath := FileName;
    if FindFirst(FullPath, faAnyFile, FileInfo) = 0 then
    begin
      Backup.FileName := ExtractFileName(FileName);
      Backup.FullPath := FullPath;
      Backup.CreatedAt := FileInfo.TimeStamp;
      Backup.SizeBytes := FileInfo.Size;
      Backup.Description := LoadBackupMetadata(FullPath);
      Backup.IsCompressed := True;
      FBackups.Add(Backup);
      FindClose(FileInfo);
    end;
  end;
  
  // Sort by date descending (newest first)
  FBackups.Sort(TComparer<TBackupInfo>.Construct(
    function(const L, R: TBackupInfo): Integer
    begin
      Result := CompareDateTime(R.CreatedAt, L.CreatedAt);
    end));
  
  RefreshBackupList;
  SetStatus(Format('Found %d backup(s)', [FBackups.Count]));
end;

procedure TfraBackupWizard.RefreshBackupList;
var
  I: Integer;
  Backup: TBackupInfo;
  Item: TListItem;
begin
  lvBackups.Items.BeginUpdate;
  try
    lvBackups.Items.Clear;
    
    for I := 0 to FBackups.Count - 1 do
    begin
      Backup := FBackups[I];
      Item := lvBackups.Items.Add;
      Item.Caption := Backup.FileName;
      Item.SubItems.Add(FormatDateTime('yyyy-mm-dd hh:nn:ss', Backup.CreatedAt));
      Item.SubItems.Add(FormatFileSize(Backup.SizeBytes));
      
      if Backup.IsCompressed then
        Item.SubItems.Add('Compressed')
      else
        Item.SubItems.Add('Normal');
        
      Item.Data := Pointer(I);
    end;
  finally
    lvBackups.Items.EndUpdate;
  end;
  
  ClearDetails;
end;

procedure TfraBackupWizard.CreateBackup;
var
  BackupName: string;
  BackupPath: string;
  ZipFile: TZipFile;
  TempPath: string;
  Description: string;
begin
  if FCurrentDBPath = '' then
  begin
    SetStatus('No database loaded', True);
    Exit;
  end;
  
  if not FileExists(FCurrentDBPath) then
  begin
    SetStatus('Database file not found', True);
    Exit;
  end;
  
  // Generate backup name with timestamp
  BackupName := ChangeFileExt(ExtractFileName(FCurrentDBPath), '') + '_' +
    FormatDateTime('yyyymmdd_hhnnss', Now);
  
  Description := Trim(mmoDescription.Text);
  
  SetStatus('Creating backup...');
  prgProgress.Visible := True;
  SetProgress(10);
  Application.ProcessMessages;
  
  try
    if chkCompress.Checked then
    begin
      // Create compressed backup
      BackupPath := TPath.Combine(FBackupFolder, BackupName + BACKUP_ZIP_EXT);
      TempPath := TPath.Combine(FBackupFolder, BackupName + '.tmp');
      
      // First copy the database
      SetProgress(30);
      TFile.Copy(FCurrentDBPath, TempPath, True);
      
      // Then compress it
      SetProgress(50);
      ZipFile := TZipFile.Create;
      try
        ZipFile.Open(BackupPath, zmWrite);
        ZipFile.Add(TempPath, ExtractFileName(FCurrentDBPath));
        ZipFile.Close;
      finally
        ZipFile.Free;
      end;
      
      // Clean up temp file
      TFile.Delete(TempPath);
    end
    else
    begin
      // Create uncompressed backup
      BackupPath := TPath.Combine(FBackupFolder, BackupName + BACKUP_EXT);
      SetProgress(30);
      TFile.Copy(FCurrentDBPath, BackupPath, True);
    end;
    
    SetProgress(80);
    
    // Save metadata
    if Description <> '' then
      SaveBackupMetadata(BackupPath, Description);
    
    SetProgress(100);
    SetStatus(Format('Backup created: %s', [ExtractFileName(BackupPath)]));
    
    // Refresh list
    LoadBackups;
  except
    on E: Exception do
      SetStatus('Backup failed: ' + E.Message, True);
  end;
  
  prgProgress.Visible := False;
end;

procedure TfraBackupWizard.RestoreBackup(const ABackupPath: string);
var
  ZipFile: TZipFile;
  TempFolder: string;
  ExtractedFile: string;
  Files: TArray<string>;
begin
  if FCurrentDBPath = '' then
  begin
    SetStatus('No database loaded', True);
    Exit;
  end;
  
  if not FileExists(ABackupPath) then
  begin
    SetStatus('Backup file not found', True);
    Exit;
  end;
  
  if MessageDlg(
    'This will replace the current database with the selected backup.'#13#10 +
    'A backup of the current state will be created first.'#13#10#13#10 +
    'Are you sure you want to continue?',
    mtWarning, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  
  SetStatus('Restoring backup...');
  prgProgress.Visible := True;
  SetProgress(10);
  Application.ProcessMessages;
  
  try
    // First create a backup of current state
    SetProgress(20);
    mmoDescription.Text := 'Auto-backup before restore';
    CreateBackup;
    mmoDescription.Clear;
    
    // Close database connection
    SetProgress(40);
    if Assigned(FConnection) and FConnection.Connected then
      FConnection.Close;
    
    SetProgress(50);
    
    // Check if compressed
    if SameText(ExtractFileExt(ABackupPath), BACKUP_ZIP_EXT) then
    begin
      // Extract from zip
      TempFolder := TPath.Combine(TPath.GetTempPath, 'unibase_restore_' + 
        FormatDateTime('hhnnss', Now));
      TDirectory.CreateDirectory(TempFolder);
      
      ZipFile := TZipFile.Create;
      try
        ZipFile.Open(ABackupPath, zmRead);
        ZipFile.ExtractAll(TempFolder);
        ZipFile.Close;
      finally
        ZipFile.Free;
      end;
      
      // Find extracted file
      Files := TDirectory.GetFiles(TempFolder);
      if Length(Files) > 0 then
      begin
        ExtractedFile := Files[0];
        SetProgress(70);
        TFile.Copy(ExtractedFile, FCurrentDBPath, True);
      end;
      
      // Clean up
      TDirectory.Delete(TempFolder, True);
    end
    else
    begin
      // Direct copy
      SetProgress(70);
      TFile.Copy(ABackupPath, FCurrentDBPath, True);
    end;
    
    // Reopen connection
    SetProgress(90);
    if Assigned(FConnection) then
      FConnection.Open;
    
    SetProgress(100);
    SetStatus('Restore completed successfully');
  except
    on E: Exception do
    begin
      SetStatus('Restore failed: ' + E.Message, True);
      // Try to reopen connection
      if Assigned(FConnection) and not FConnection.Connected then
      try
        FConnection.Open;
      except
        // Ignore
      end;
    end;
  end;
  
  prgProgress.Visible := False;
end;

procedure TfraBackupWizard.DeleteBackup(const ABackupPath: string);
var
  MetaPath: string;
begin
  if not FileExists(ABackupPath) then
  begin
    SetStatus('Backup file not found', True);
    Exit;
  end;
  
  if MessageDlg(
    Format('Delete backup "%s"?'#13#10#13#10 +
           'This action cannot be undone.', [ExtractFileName(ABackupPath)]),
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  
  try
    TFile.Delete(ABackupPath);
    
    // Also delete metadata file if exists
    MetaPath := ABackupPath + METADATA_EXT;
    if FileExists(MetaPath) then
      TFile.Delete(MetaPath);
    
    SetStatus('Backup deleted');
    LoadBackups;
  except
    on E: Exception do
      SetStatus('Delete failed: ' + E.Message, True);
  end;
end;

procedure TfraBackupWizard.SaveBackupMetadata(const ABackupPath, ADescription: string);
var
  MetaPath: string;
begin
  MetaPath := ABackupPath + METADATA_EXT;
  TFile.WriteAllText(MetaPath, ADescription, TEncoding.UTF8);
end;

function TfraBackupWizard.LoadBackupMetadata(const ABackupPath: string): string;
var
  MetaPath: string;
begin
  Result := '';
  MetaPath := ABackupPath + METADATA_EXT;
  if FileExists(MetaPath) then
  try
    Result := TFile.ReadAllText(MetaPath, TEncoding.UTF8);
  except
    Result := '';
  end;
end;

procedure TfraBackupWizard.UpdateDetails(const ABackup: TBackupInfo);
begin
  lblFileNameValue.Caption := ABackup.FileName;
  lblCreatedValue.Caption := FormatDateTime('yyyy-mm-dd hh:nn:ss', ABackup.CreatedAt);
  lblSizeValue.Caption := FormatFileSize(ABackup.SizeBytes);
  
  if ABackup.Description <> '' then
    mmoDescription.Text := ABackup.Description
  else
    mmoDescription.Clear;
    
  btnRestoreBackup.Enabled := True;
  btnDeleteBackup.Enabled := True;
end;

procedure TfraBackupWizard.ClearDetails;
begin
  lblFileNameValue.Caption := '-';
  lblCreatedValue.Caption := '-';
  lblSizeValue.Caption := '-';
  mmoDescription.Clear;
  
  btnRestoreBackup.Enabled := False;
  btnDeleteBackup.Enabled := False;
end;

procedure TfraBackupWizard.SetStatus(const AText: string; AIsError: Boolean);
begin
  lblStatus.Caption := AText;
  if AIsError then
    lblStatus.Font.Color := clRed
  else
    lblStatus.Font.Color := clWindowText;
end;

procedure TfraBackupWizard.SetProgress(AValue: Integer; AMax: Integer);
begin
  prgProgress.Max := AMax;
  prgProgress.Position := AValue;
  Application.ProcessMessages;
end;

function TfraBackupWizard.GetSelectedBackup: TBackupInfo;
var
  Idx: Integer;
begin
  Result := Default(TBackupInfo);
  if lvBackups.Selected <> nil then
  begin
    Idx := Integer(lvBackups.Selected.Data);
    if (Idx >= 0) and (Idx < FBackups.Count) then
      Result := FBackups[Idx];
  end;
end;

function TfraBackupWizard.FormatFileSize(ABytes: Int64): string;
begin
  if ABytes < 1024 then
    Result := Format('%d B', [ABytes])
  else if ABytes < 1024 * 1024 then
    Result := Format('%.1f KB', [ABytes / 1024])
  else if ABytes < 1024 * 1024 * 1024 then
    Result := Format('%.1f MB', [ABytes / (1024 * 1024)])
  else
    Result := Format('%.2f GB', [ABytes / (1024 * 1024 * 1024)]);
end;

procedure TfraBackupWizard.btnCreateBackupClick(Sender: TObject);
begin
  CreateBackup;
end;

procedure TfraBackupWizard.btnRestoreBackupClick(Sender: TObject);
var
  Backup: TBackupInfo;
begin
  Backup := GetSelectedBackup;
  if Backup.FullPath <> '' then
    RestoreBackup(Backup.FullPath)
  else
    SetStatus('Please select a backup first', True);
end;

procedure TfraBackupWizard.btnDeleteBackupClick(Sender: TObject);
var
  Backup: TBackupInfo;
begin
  Backup := GetSelectedBackup;
  if Backup.FullPath <> '' then
    DeleteBackup(Backup.FullPath)
  else
    SetStatus('Please select a backup first', True);
end;

procedure TfraBackupWizard.btnRefreshClick(Sender: TObject);
begin
  LoadBackups;
end;

procedure TfraBackupWizard.lvBackupsSelectItem(Sender: TObject; Item: TListItem;
  Selected: Boolean);
var
  Backup: TBackupInfo;
begin
  if Selected then
  begin
    Backup := GetSelectedBackup;
    if Backup.FullPath <> '' then
      UpdateDetails(Backup);
  end
  else
    ClearDetails;
end;

end.
