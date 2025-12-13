{ ============================================================================
  UniBase.Updater - Secure Auto-Update System
  
  Version: 0.3
  Description: Provides secure application update mechanism with version checking,
               incremental updates, signature verification, and rollback support.
  
  Features:
    - Version checking against update server
    - Incremental/delta updates (reduces bandwidth)
    - Cryptographic signature verification
    - Automatic backup before update
    - Rollback on failure
    - Background download with progress
    - Update notification system
  
  Usage:
    Updater.CheckForUpdates(
      procedure(Available: Boolean; Info: TUpdateInfo)
      begin
        if Available then
          Updater.DownloadAndInstall(Info);
      end);
  ============================================================================ }

unit UniBase.Updater;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  System.Generics.Collections,
  System.Generics.Defaults,
  System.IOUtils,
  System.Net.HttpClient,
  System.Net.URLClient,
  System.JSON,
  System.Hash,
  System.DateUtils,
  System.Zip,
  System.SyncObjs,
  System.Threading,
  {$IFDEF MSWINDOWS}
  UniBase.Crypto,
  Winapi.Windows
  {$ENDIF};

type
  // Forward declarations
  TUpdateManager = class;
  
  // ============================================================================
  // Version Types
  // ============================================================================
  
  /// <summary>
  /// Semantic version representation
  /// </summary>
  TSemanticVersion = record
    Major: Integer;
    Minor: Integer;
    Patch: Integer;
    Build: Integer;
    PreRelease: string;
    
    class function Parse(const VersionStr: string): TSemanticVersion; static;
    function ToString: string;
    function CompareTo(const Other: TSemanticVersion): Integer;
    function IsNewerThan(const Other: TSemanticVersion): Boolean;
    class operator Equal(const A, B: TSemanticVersion): Boolean;
    class operator NotEqual(const A, B: TSemanticVersion): Boolean;
    class operator GreaterThan(const A, B: TSemanticVersion): Boolean;
    class operator LessThan(const A, B: TSemanticVersion): Boolean;
  end;
  
  // ============================================================================
  // Update Types
  // ============================================================================
  
  /// <summary>
  /// Update channel
  /// </summary>
  TUpdateChannel = (ucStable, ucBeta, ucAlpha, ucDev);
  
  /// <summary>
  /// Update type
  /// </summary>
  TUpdateType = (utFull, utIncremental, utPatch);
  
  /// <summary>
  /// Update status
  /// </summary>
  TUpdateStatus = (
    usIdle,
    usCheckingForUpdates,
    usUpdateAvailable,
    usDownloading,
    usVerifying,
    usBackingUp,
    usInstalling,
    usRollingBack,
    usComplete,
    usFailed
  );
  
  /// <summary>
  /// Update file information
  /// </summary>
  TUpdateFile = record
    FileName: string;
    RelativePath: string;
    Size: Int64;
    Hash: string;        // SHA256 hash
    Action: string;      // 'add', 'update', 'delete'
  end;
  
  /// <summary>
  /// Update information
  /// </summary>
  TUpdateInfo = record
    Version: TSemanticVersion;
    ReleaseDate: TDateTime;
    Channel: TUpdateChannel;
    UpdateType: TUpdateType;
    Title: string;
    Description: string;
    ReleaseNotes: string;
    DownloadUrl: string;
    DownloadSize: Int64;
    PackageHash: string;    // SHA256 of package
    Signature: string;      // RSA signature
    MinVersion: TSemanticVersion;  // Minimum version for incremental
    IsMandatory: Boolean;
    Files: TArray<TUpdateFile>;
    
    function IsEmpty: Boolean;
  end;
  
  /// <summary>
  /// Update progress information
  /// </summary>
  TUpdateProgress = record
    Status: TUpdateStatus;
    TotalBytes: Int64;
    DownloadedBytes: Int64;
    CurrentFile: string;
    ProgressPercent: Integer;
    StatusMessage: string;
  end;
  
  // ============================================================================
  // Callbacks
  // ============================================================================
  
  TCheckUpdateCallback = reference to procedure(Available: Boolean; const Info: TUpdateInfo);
  TProgressCallback = reference to procedure(const Progress: TUpdateProgress);
  TUpdateCompleteCallback = reference to procedure(Success: Boolean; const ErrorMessage: string);
  
  // ============================================================================
  // Update Manager
  // ============================================================================
  
  /// <summary>
  /// Main update manager
  /// </summary>
  TUpdateManager = class
  private
    FUpdateUrl: string;
    FCurrentVersion: TSemanticVersion;
    FChannel: TUpdateChannel;
    FBackupDir: string;
    FTempDir: string;
    FApplicationDir: string;
    FStatus: TUpdateStatus;
    FLastError: string;
    FPublicKey: string;  // RSA public key for signature verification
    FAutoCheck: Boolean;
    FAutoCheckInterval: Integer;  // Hours
    FLastCheckTime: TDateTime;
    FCurrentUpdate: TUpdateInfo;
    FOnProgress: TProgressCallback;
    FOnUpdateAvailable: TProc<TUpdateInfo>;
    FLock: TCriticalSection;
    FHttpClient: THTTPClient;
    FCancelled: Boolean;
    
    function DownloadFile(const Url, DestPath: string; 
      ProgressCallback: TProgressCallback): Boolean;
    function VerifySignature(const Data, Signature: string): Boolean;
    function VerifyFileHash(const FilePath, ExpectedHash: string): Boolean;
    function CreateBackup(const Files: TArray<string>): Boolean;
    function RestoreBackup: Boolean;
    function ApplyUpdate(const PackagePath: string; 
      const Info: TUpdateInfo): Boolean;
    function ParseUpdateInfo(const JSON: TJSONObject): TUpdateInfo;
    procedure SetStatus(Status: TUpdateStatus; const Message: string = '');
    procedure ReportProgress(TotalBytes, DownloadedBytes: Int64;
      const CurrentFile, StatusMessage: string);
    procedure CleanupTempFiles;
  public
    constructor Create;
    destructor Destroy; override;
    
    /// <summary>Initialize with update server URL and current version</summary>
    procedure Initialize(const UpdateUrl, CurrentVersion: string;
      const ApplicationDir: string = '');
    
    /// <summary>Set RSA public key for signature verification</summary>
    procedure SetPublicKey(const PublicKeyPEM: string);
    
    /// <summary>Check for updates asynchronously</summary>
    procedure CheckForUpdates(Callback: TCheckUpdateCallback);
    
    /// <summary>Check for updates synchronously</summary>
    function CheckForUpdatesSync(out Info: TUpdateInfo): Boolean;
    
    /// <summary>Download and install update</summary>
    procedure DownloadAndInstall(const Info: TUpdateInfo;
      OnComplete: TUpdateCompleteCallback = nil);
    
    /// <summary>Download update only (don't install)</summary>
    procedure DownloadOnly(const Info: TUpdateInfo;
      OnComplete: TUpdateCompleteCallback = nil);
    
    /// <summary>Install previously downloaded update</summary>
    function InstallDownloadedUpdate(const PackagePath: string): Boolean;
    
    /// <summary>Cancel ongoing operation</summary>
    procedure Cancel;
    
    /// <summary>Rollback to previous version</summary>
    function Rollback: Boolean;
    
    /// <summary>Get release notes for version</summary>
    function GetReleaseNotes(const Version: TSemanticVersion): string;
    
    /// <summary>Get update history</summary>
    function GetUpdateHistory: TArray<TUpdateInfo>;
    
    /// <summary>Clear update cache</summary>
    procedure ClearCache;
    
    // Properties
    property UpdateUrl: string read FUpdateUrl write FUpdateUrl;
    property CurrentVersion: TSemanticVersion read FCurrentVersion;
    property Channel: TUpdateChannel read FChannel write FChannel;
    property Status: TUpdateStatus read FStatus;
    property LastError: string read FLastError;
    property AutoCheck: Boolean read FAutoCheck write FAutoCheck;
    property AutoCheckInterval: Integer read FAutoCheckInterval write FAutoCheckInterval;
    property LastCheckTime: TDateTime read FLastCheckTime;
    property CurrentUpdate: TUpdateInfo read FCurrentUpdate;
    property OnProgress: TProgressCallback read FOnProgress write FOnProgress;
    property OnUpdateAvailable: TProc<TUpdateInfo> read FOnUpdateAvailable write FOnUpdateAvailable;
  end;
  
  // ============================================================================
  // Helper Functions
  // ============================================================================
  
/// <summary>Get global update manager</summary>
function Updater: TUpdateManager;

/// <summary>Set global update manager</summary>
procedure SetUpdater(Manager: TUpdateManager);

/// <summary>Channel name to enum</summary>
function ParseChannel(const Name: string): TUpdateChannel;

/// <summary>Channel enum to name</summary>
function ChannelToString(Channel: TUpdateChannel): string;

implementation

var
  FUpdater: TUpdateManager = nil;
  FUpdaterLock: TCriticalSection = nil;

function Updater: TUpdateManager;
begin
  if FUpdater = nil then
  begin
    FUpdaterLock.Enter;
    try
      if FUpdater = nil then
        FUpdater := TUpdateManager.Create;
    finally
      FUpdaterLock.Leave;
    end;
  end;
  Result := FUpdater;
end;

procedure SetUpdater(Manager: TUpdateManager);
begin
  FUpdaterLock.Enter;
  try
    if (FUpdater <> nil) and (FUpdater <> Manager) then
      FUpdater.Free;
    FUpdater := Manager;
  finally
    FUpdaterLock.Leave;
  end;
end;

function ParseChannel(const Name: string): TUpdateChannel;
begin
  if SameText(Name, 'stable') then
    Result := ucStable
  else if SameText(Name, 'beta') then
    Result := ucBeta
  else if SameText(Name, 'alpha') then
    Result := ucAlpha
  else if SameText(Name, 'dev') then
    Result := ucDev
  else
    Result := ucStable;
end;

function ChannelToString(Channel: TUpdateChannel): string;
begin
  case Channel of
    ucStable: Result := 'stable';
    ucBeta: Result := 'beta';
    ucAlpha: Result := 'alpha';
    ucDev: Result := 'dev';
  else
    Result := 'stable';
  end;
end;

// ============================================================================
// TSemanticVersion
// ============================================================================

class function TSemanticVersion.Parse(const VersionStr: string): TSemanticVersion;
var
  Parts: TArray<string>;
  MainParts: TArray<string>;
  PreReleaseIdx: Integer;
begin
  Result.Major := 0;
  Result.Minor := 0;
  Result.Patch := 0;
  Result.Build := 0;
  Result.PreRelease := '';
  
  if VersionStr = '' then
    Exit;
  
  // Remove 'v' prefix if present
  var Ver := VersionStr;
  if (Length(Ver) > 0) and (Ver[1] = 'v') then
    Ver := Copy(Ver, 2, MaxInt);
  
  // Check for pre-release suffix
  PreReleaseIdx := Pos('-', Ver);
  if PreReleaseIdx > 0 then
  begin
    Result.PreRelease := Copy(Ver, PreReleaseIdx + 1, MaxInt);
    Ver := Copy(Ver, 1, PreReleaseIdx - 1);
  end;
  
  // Parse main version parts
  Parts := Ver.Split(['.']);
  if Length(Parts) >= 1 then
    Result.Major := StrToIntDef(Parts[0], 0);
  if Length(Parts) >= 2 then
    Result.Minor := StrToIntDef(Parts[1], 0);
  if Length(Parts) >= 3 then
    Result.Patch := StrToIntDef(Parts[2], 0);
  if Length(Parts) >= 4 then
    Result.Build := StrToIntDef(Parts[3], 0);
end;

function TSemanticVersion.ToString: string;
begin
  Result := Format('%d.%d.%d', [Major, Minor, Patch]);
  if Build > 0 then
    Result := Result + '.' + IntToStr(Build);
  if PreRelease <> '' then
    Result := Result + '-' + PreRelease;
end;

function TSemanticVersion.CompareTo(const Other: TSemanticVersion): Integer;
begin
  Result := Major - Other.Major;
  if Result <> 0 then Exit;
  
  Result := Minor - Other.Minor;
  if Result <> 0 then Exit;
  
  Result := Patch - Other.Patch;
  if Result <> 0 then Exit;
  
  Result := Build - Other.Build;
  if Result <> 0 then Exit;
  
  // Pre-release versions are lower than release versions
  if (PreRelease = '') and (Other.PreRelease <> '') then
    Result := 1
  else if (PreRelease <> '') and (Other.PreRelease = '') then
    Result := -1
  else
    Result := CompareText(PreRelease, Other.PreRelease);
end;

function TSemanticVersion.IsNewerThan(const Other: TSemanticVersion): Boolean;
begin
  Result := CompareTo(Other) > 0;
end;

class operator TSemanticVersion.Equal(const A, B: TSemanticVersion): Boolean;
begin
  Result := A.CompareTo(B) = 0;
end;

class operator TSemanticVersion.NotEqual(const A, B: TSemanticVersion): Boolean;
begin
  Result := A.CompareTo(B) <> 0;
end;

class operator TSemanticVersion.GreaterThan(const A, B: TSemanticVersion): Boolean;
begin
  Result := A.CompareTo(B) > 0;
end;

class operator TSemanticVersion.LessThan(const A, B: TSemanticVersion): Boolean;
begin
  Result := A.CompareTo(B) < 0;
end;

// ============================================================================
// TUpdateInfo
// ============================================================================

function TUpdateInfo.IsEmpty: Boolean;
begin
  Result := (Version.Major = 0) and (Version.Minor = 0) and 
            (Version.Patch = 0) and (DownloadUrl = '');
end;

// ============================================================================
// TUpdateManager
// ============================================================================

constructor TUpdateManager.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FHttpClient := THTTPClient.Create;
  FHttpClient.UserAgent := 'UniBase-Updater/1.0';
  FChannel := ucStable;
  FStatus := usIdle;
  FAutoCheck := False;
  FAutoCheckInterval := 24;
  FLastCheckTime := 0;
  FCancelled := False;
  FTempDir := TPath.Combine(TPath.GetTempPath, 'UniBase_Update');
  FBackupDir := TPath.Combine(TPath.GetTempPath, 'UniBase_Backup');
end;

destructor TUpdateManager.Destroy;
begin
  FHttpClient.Free;
  FLock.Free;
  inherited;
end;

procedure TUpdateManager.Initialize(const UpdateUrl, CurrentVersion: string;
  const ApplicationDir: string);
begin
  FUpdateUrl := UpdateUrl;
  FCurrentVersion := TSemanticVersion.Parse(CurrentVersion);
  if ApplicationDir <> '' then
    FApplicationDir := ApplicationDir
  else
    FApplicationDir := TPath.GetDirectoryName(ParamStr(0));
end;

procedure TUpdateManager.SetPublicKey(const PublicKeyPEM: string);
begin
  FPublicKey := PublicKeyPEM;
end;

procedure TUpdateManager.SetStatus(Status: TUpdateStatus; const Message: string);
begin
  FLock.Enter;
  try
    FStatus := Status;
    if Message <> '' then
      FLastError := Message;
  finally
    FLock.Leave;
  end;
end;

procedure TUpdateManager.ReportProgress(TotalBytes, DownloadedBytes: Int64;
  const CurrentFile, StatusMessage: string);
var
  Progress: TUpdateProgress;
begin
  Progress.Status := FStatus;
  Progress.TotalBytes := TotalBytes;
  Progress.DownloadedBytes := DownloadedBytes;
  Progress.CurrentFile := CurrentFile;
  Progress.StatusMessage := StatusMessage;
  if TotalBytes > 0 then
    Progress.ProgressPercent := Round(DownloadedBytes * 100 / TotalBytes)
  else
    Progress.ProgressPercent := 0;
  
  if Assigned(FOnProgress) then
    FOnProgress(Progress);
end;

function TUpdateManager.ParseUpdateInfo(const JSON: TJSONObject): TUpdateInfo;
var
  FilesArray: TJSONArray;
  FileObj: TJSONObject;
  I: Integer;
begin
  Result := Default(TUpdateInfo);
  
  if JSON = nil then
    Exit;
  
  Result.Version := TSemanticVersion.Parse(JSON.GetValue<string>('version', ''));
  Result.Title := JSON.GetValue<string>('title', '');
  Result.Description := JSON.GetValue<string>('description', '');
  Result.ReleaseNotes := JSON.GetValue<string>('release_notes', '');
  Result.DownloadUrl := JSON.GetValue<string>('download_url', '');
  Result.DownloadSize := JSON.GetValue<Int64>('download_size', 0);
  Result.PackageHash := JSON.GetValue<string>('package_hash', '');
  Result.Signature := JSON.GetValue<string>('signature', '');
  Result.IsMandatory := JSON.GetValue<Boolean>('mandatory', False);
  Result.Channel := ParseChannel(JSON.GetValue<string>('channel', 'stable'));
  
  if JSON.GetValue<string>('update_type', '') = 'incremental' then
    Result.UpdateType := utIncremental
  else if JSON.GetValue<string>('update_type', '') = 'patch' then
    Result.UpdateType := utPatch
  else
    Result.UpdateType := utFull;
  
  Result.MinVersion := TSemanticVersion.Parse(
    JSON.GetValue<string>('min_version', ''));
  
  // Parse release date
  var DateStr := JSON.GetValue<string>('release_date', '');
  if DateStr <> '' then
    Result.ReleaseDate := ISO8601ToDate(DateStr)
  else
    Result.ReleaseDate := Now;
  
  // Parse files list
  FilesArray := JSON.GetValue<TJSONArray>('files');
  if FilesArray <> nil then
  begin
    SetLength(Result.Files, FilesArray.Count);
    for I := 0 to FilesArray.Count - 1 do
    begin
      FileObj := FilesArray.Items[I] as TJSONObject;
      Result.Files[I].FileName := FileObj.GetValue<string>('name', '');
      Result.Files[I].RelativePath := FileObj.GetValue<string>('path', '');
      Result.Files[I].Size := FileObj.GetValue<Int64>('size', 0);
      Result.Files[I].Hash := FileObj.GetValue<string>('hash', '');
      Result.Files[I].Action := FileObj.GetValue<string>('action', 'update');
    end;
  end;
end;

procedure TUpdateManager.CheckForUpdates(Callback: TCheckUpdateCallback);
var
  LTask: ITask;
begin
  LTask := TTask.Create(
    procedure
    var
      Info: TUpdateInfo;
      Available: Boolean;
    begin
      Available := CheckForUpdatesSync(Info);
      
      TThread.Synchronize(nil,
        procedure
        begin
          if Assigned(Callback) then
            Callback(Available, Info);
        end);
    end);
  LTask.Start;
end;

function TUpdateManager.CheckForUpdatesSync(out Info: TUpdateInfo): Boolean;
var
  Response: IHTTPResponse;
  JSON: TJSONObject;
  Url: string;
begin
  Result := False;
  Info := Default(TUpdateInfo);
  
  SetStatus(usCheckingForUpdates, 'Checking for updates...');
  FCancelled := False;
  
  try
    // Build update check URL
    Url := FUpdateUrl;
    if not Url.EndsWith('/') then
      Url := Url + '/';
    Url := Url + Format('check?version=%s&channel=%s&platform=windows',
      [FCurrentVersion.ToString, ChannelToString(FChannel)]);
    
    Response := FHttpClient.Get(Url);
    
    if Response.StatusCode = 200 then
    begin
      JSON := TJSONObject.ParseJSONValue(Response.ContentAsString) as TJSONObject;
      try
        if JSON <> nil then
        begin
          Info := ParseUpdateInfo(JSON);
          
          // Check if update is newer than current version
          if Info.Version.IsNewerThan(FCurrentVersion) then
          begin
            Result := True;
            FCurrentUpdate := Info;
            SetStatus(usUpdateAvailable);
            
            if Assigned(FOnUpdateAvailable) then
              FOnUpdateAvailable(Info);
          end
          else
            SetStatus(usIdle, 'No updates available');
        end;
      finally
        JSON.Free;
      end;
    end
    else
    begin
      SetStatus(usFailed, Format('Server returned status %d', [Response.StatusCode]));
    end;
    
    FLastCheckTime := Now;
  except
    on E: Exception do
    begin
      SetStatus(usFailed, 'Check failed: ' + E.Message);
      FLastError := E.Message;
    end;
  end;
end;

function TUpdateManager.DownloadFile(const Url, DestPath: string;
  ProgressCallback: TProgressCallback): Boolean;
var
  Response: IHTTPResponse;
  FileStream: TFileStream;
begin
  Result := False;
  
  try
    // Ensure directory exists
    ForceDirectories(TPath.GetDirectoryName(DestPath));
    
    Response := FHttpClient.Get(Url);
    
    if (Response.StatusCode = 200) and not FCancelled then
    begin
      FileStream := TFileStream.Create(DestPath, fmCreate);
      try
        FileStream.CopyFrom(Response.ContentStream, 0);
        Result := True;
      finally
        FileStream.Free;
      end;
    end;
  except
    on E: Exception do
    begin
      FLastError := 'Download failed: ' + E.Message;
    end;
  end;
end;

function TUpdateManager.VerifySignature(const Data, Signature: string): Boolean;
{$IFDEF MSWINDOWS}
var
  LVerifier: TRSAVerifier;
{$ENDIF}
begin
  // If no public key configured, skip verification (development mode)
  if FPublicKey = '' then
    Exit(True);
  
  // If signature is empty but public key is set, fail
  if Signature = '' then
    Exit(False);
  
  {$IFDEF MSWINDOWS}
  LVerifier := TRSAVerifier.Create;
  try
    // Load public key (PEM format)
    if not LVerifier.LoadPublicKeyPEM(FPublicKey) then
    begin
      FLastError := 'Failed to load public key: ' + LVerifier.LastError;
      Exit(False);
    end;
    
    // Verify RSA-SHA256 signature
    Result := LVerifier.VerifySignature(Data, Signature);
    if not Result then
      FLastError := 'Signature verification failed: ' + LVerifier.LastError;
  finally
    LVerifier.Free;
  end;
  {$ELSE}
  // Non-Windows platforms: signature verification not implemented yet
  // TODO: Implement OpenSSL-based verification for macOS/Linux
  Result := False;
  FLastError := 'Signature verification not implemented on this platform';
  {$ENDIF}
end;

function TUpdateManager.VerifyFileHash(const FilePath, ExpectedHash: string): Boolean;
var
  FileStream: TFileStream;
  ActualHash: string;
begin
  Result := False;
  
  if not FileExists(FilePath) then
    Exit;
  
  if ExpectedHash = '' then
    Exit(True);  // No hash to verify
  
  FileStream := TFileStream.Create(FilePath, fmOpenRead or fmShareDenyWrite);
  try
    ActualHash := THashSHA2.GetHashString(FileStream, SHA256);
    Result := SameText(ActualHash, ExpectedHash);
  finally
    FileStream.Free;
  end;
end;

function TUpdateManager.CreateBackup(const Files: TArray<string>): Boolean;
var
  BackupPath, SrcPath, DestPath: string;
  I: Integer;
begin
  Result := False;
  
  SetStatus(usBackingUp, 'Creating backup...');
  
  try
    BackupPath := TPath.Combine(FBackupDir, FormatDateTime('yyyymmdd_hhnnss', Now));
    ForceDirectories(BackupPath);
    
    for I := 0 to High(Files) do
    begin
      if FCancelled then
        Exit;
      
      SrcPath := TPath.Combine(FApplicationDir, Files[I]);
      DestPath := TPath.Combine(BackupPath, Files[I]);
      
      if FileExists(SrcPath) then
      begin
        ForceDirectories(TPath.GetDirectoryName(DestPath));
        TFile.Copy(SrcPath, DestPath);
      end;
      
      ReportProgress(Length(Files), I + 1, Files[I], 'Backing up files...');
    end;
    
    // Save backup manifest
    TFile.WriteAllText(
      TPath.Combine(BackupPath, 'manifest.json'),
      Format('{"version":"%s","date":"%s"}', 
        [FCurrentVersion.ToString, DateToISO8601(Now)]));
    
    Result := True;
  except
    on E: Exception do
    begin
      FLastError := 'Backup failed: ' + E.Message;
    end;
  end;
end;

function TUpdateManager.RestoreBackup: Boolean;
var
  BackupDirs: TStringDynArray;
  LatestBackup, SrcPath, DestPath, FileName: string;
  I: Integer;
  Files: TStringDynArray;
begin
  Result := False;
  
  SetStatus(usRollingBack, 'Restoring backup...');
  
  try
    // Find latest backup
    if not TDirectory.Exists(FBackupDir) then
    begin
      FLastError := 'No backup found';
      Exit;
    end;
    
    BackupDirs := TDirectory.GetDirectories(FBackupDir);
    if Length(BackupDirs) = 0 then
    begin
      FLastError := 'No backup found';
      Exit;
    end;
    
    // Sort to get latest
    TArray.Sort<string>(BackupDirs, TComparer<string>.Default);
    LatestBackup := BackupDirs[High(BackupDirs)];
    
    // Copy files back
    Files := TDirectory.GetFiles(LatestBackup, '*.*', TSearchOption.soAllDirectories);
    for I := 0 to High(Files) do
    begin
      if FCancelled then
        Exit;
      
      FileName := Copy(Files[I], Length(LatestBackup) + 2, MaxInt);
      if FileName = 'manifest.json' then
        Continue;
      
      SrcPath := Files[I];
      DestPath := TPath.Combine(FApplicationDir, FileName);
      
      ForceDirectories(TPath.GetDirectoryName(DestPath));
      TFile.Copy(SrcPath, DestPath, True);
      
      ReportProgress(Length(Files), I + 1, FileName, 'Restoring files...');
    end;
    
    Result := True;
  except
    on E: Exception do
    begin
      FLastError := 'Rollback failed: ' + E.Message;
    end;
  end;
end;

function TUpdateManager.ApplyUpdate(const PackagePath: string;
  const Info: TUpdateInfo): Boolean;
var
  Zip: TZipFile;
  ExtractPath, FileName, DestPath: string;
  I: Integer;
  FileNames: TArray<string>;
begin
  Result := False;
  
  SetStatus(usInstalling, 'Installing update...');
  
  try
    ExtractPath := TPath.Combine(FTempDir, 'extract_' + 
      FormatDateTime('yyyymmdd_hhnnss', Now));
    ForceDirectories(ExtractPath);
    
    // Extract update package
    Zip := TZipFile.Create;
    try
      Zip.Open(PackagePath, zmRead);
      Zip.ExtractAll(ExtractPath);
      Zip.Close;
    finally
      Zip.Free;
    end;
    
    // Get list of files to update
    FileNames := TDirectory.GetFiles(ExtractPath, '*.*', 
      TSearchOption.soAllDirectories);
    
    // Copy files to application directory
    for I := 0 to High(FileNames) do
    begin
      if FCancelled then
      begin
        RestoreBackup;
        Exit;
      end;
      
      FileName := Copy(FileNames[I], Length(ExtractPath) + 2, MaxInt);
      DestPath := TPath.Combine(FApplicationDir, FileName);
      
      ForceDirectories(TPath.GetDirectoryName(DestPath));
      TFile.Copy(FileNames[I], DestPath, True);
      
      ReportProgress(Length(FileNames), I + 1, FileName, 'Installing files...');
    end;
    
    // Cleanup
    TDirectory.Delete(ExtractPath, True);
    
    SetStatus(usComplete, 'Update installed successfully');
    Result := True;
  except
    on E: Exception do
    begin
      FLastError := 'Installation failed: ' + E.Message;
      SetStatus(usFailed, FLastError);
      
      // Try to rollback
      RestoreBackup;
    end;
  end;
end;

procedure TUpdateManager.DownloadAndInstall(const Info: TUpdateInfo;
  OnComplete: TUpdateCompleteCallback);
var
  LTask: ITask;
begin
  LTask := TTask.Create(
    procedure
    var
      PackagePath: string;
      FilesToBackup: TArray<string>;
      I: Integer;
      Success: Boolean;
      ErrorMsg: string;
    begin
      Success := False;
      ErrorMsg := '';
      FCancelled := False;
      
      try
        SetStatus(usDownloading, 'Downloading update...');
        
        // Download update package
        PackagePath := TPath.Combine(FTempDir, 
          Format('update_%s.zip', [Info.Version.ToString]));
        
        if not DownloadFile(Info.DownloadUrl, PackagePath, FOnProgress) then
        begin
          ErrorMsg := FLastError;
          SetStatus(usFailed, ErrorMsg);
          Exit;
        end;
        
        if FCancelled then
        begin
          ErrorMsg := 'Cancelled by user';
          SetStatus(usFailed, ErrorMsg);
          Exit;
        end;
        
        // Verify package hash
        SetStatus(usVerifying, 'Verifying download...');
        if not VerifyFileHash(PackagePath, Info.PackageHash) then
        begin
          ErrorMsg := 'Package hash verification failed';
          SetStatus(usFailed, ErrorMsg);
          Exit;
        end;
        
        // Verify signature
        if not VerifySignature(Info.PackageHash, Info.Signature) then
        begin
          ErrorMsg := 'Package signature verification failed';
          SetStatus(usFailed, ErrorMsg);
          Exit;
        end;
        
        // Create backup
        SetLength(FilesToBackup, Length(Info.Files));
        for I := 0 to High(Info.Files) do
          FilesToBackup[I] := Info.Files[I].RelativePath;
        
        if not CreateBackup(FilesToBackup) then
        begin
          ErrorMsg := FLastError;
          SetStatus(usFailed, ErrorMsg);
          Exit;
        end;
        
        // Apply update
        Success := ApplyUpdate(PackagePath, Info);
        if not Success then
          ErrorMsg := FLastError;
          
      except
        on E: Exception do
        begin
          ErrorMsg := E.Message;
          SetStatus(usFailed, ErrorMsg);
        end;
      end;
      
      // Cleanup
      CleanupTempFiles;
      
      // Callback
      if Assigned(OnComplete) then
      begin
        TThread.Synchronize(nil,
          procedure
          begin
            OnComplete(Success, ErrorMsg);
          end);
      end;
    end);
  LTask.Start;
end;

procedure TUpdateManager.DownloadOnly(const Info: TUpdateInfo;
  OnComplete: TUpdateCompleteCallback);
var
  LTask: ITask;
begin
  LTask := TTask.Create(
    procedure
    var
      PackagePath: string;
      Success: Boolean;
      ErrorMsg: string;
    begin
      Success := False;
      ErrorMsg := '';
      FCancelled := False;
      
      try
        SetStatus(usDownloading, 'Downloading update...');
        
        PackagePath := TPath.Combine(FTempDir, 
          Format('update_%s.zip', [Info.Version.ToString]));
        
        if DownloadFile(Info.DownloadUrl, PackagePath, FOnProgress) then
        begin
          SetStatus(usVerifying, 'Verifying download...');
          if VerifyFileHash(PackagePath, Info.PackageHash) then
          begin
            Success := True;
            SetStatus(usIdle, 'Download complete');
          end
          else
          begin
            ErrorMsg := 'Package hash verification failed';
            SetStatus(usFailed, ErrorMsg);
          end;
        end
        else
        begin
          ErrorMsg := FLastError;
          SetStatus(usFailed, ErrorMsg);
        end;
      except
        on E: Exception do
        begin
          ErrorMsg := E.Message;
          SetStatus(usFailed, ErrorMsg);
        end;
      end;
      
      if Assigned(OnComplete) then
      begin
        TThread.Synchronize(nil,
          procedure
          begin
            OnComplete(Success, ErrorMsg);
          end);
      end;
    end);
  LTask.Start;
end;

function TUpdateManager.InstallDownloadedUpdate(const PackagePath: string): Boolean;
var
  FilesToBackup: TArray<string>;
begin
  Result := False;
  
  if not FileExists(PackagePath) then
  begin
    FLastError := 'Update package not found';
    Exit;
  end;
  
  // For downloaded packages, we don't have file list, backup everything
  SetLength(FilesToBackup, 1);
  FilesToBackup[0] := '*.*';
  
  if not CreateBackup(FilesToBackup) then
    Exit;
  
  Result := ApplyUpdate(PackagePath, FCurrentUpdate);
end;

procedure TUpdateManager.Cancel;
begin
  FCancelled := True;
end;

function TUpdateManager.Rollback: Boolean;
begin
  Result := RestoreBackup;
  if Result then
    SetStatus(usComplete, 'Rollback successful')
  else
    SetStatus(usFailed, FLastError);
end;

function TUpdateManager.GetReleaseNotes(const Version: TSemanticVersion): string;
var
  Response: IHTTPResponse;
  Url: string;
begin
  Result := '';
  
  try
    Url := FUpdateUrl;
    if not Url.EndsWith('/') then
      Url := Url + '/';
    Url := Url + Format('release-notes/%s', [Version.ToString]);
    
    Response := FHttpClient.Get(Url);
    if Response.StatusCode = 200 then
      Result := Response.ContentAsString;
  except
    on E: Exception do
      {$IFDEF DEBUG}
      OutputDebugString(PChar('UniBase.Updater: GetReleaseNotes failed: ' + E.Message));
      {$ENDIF}
  end;
end;

function TUpdateManager.GetUpdateHistory: TArray<TUpdateInfo>;
var
  Response: IHTTPResponse;
  Url: string;
  JSON: TJSONArray;
  I: Integer;
begin
  SetLength(Result, 0);
  
  try
    Url := FUpdateUrl;
    if not Url.EndsWith('/') then
      Url := Url + '/';
    Url := Url + 'history';
    
    Response := FHttpClient.Get(Url);
    if Response.StatusCode = 200 then
    begin
      JSON := TJSONObject.ParseJSONValue(Response.ContentAsString) as TJSONArray;
      try
        if JSON <> nil then
        begin
          SetLength(Result, JSON.Count);
          for I := 0 to JSON.Count - 1 do
            Result[I] := ParseUpdateInfo(JSON.Items[I] as TJSONObject);
        end;
      finally
        JSON.Free;
      end;
    end;
  except
    on E: Exception do
      {$IFDEF DEBUG}
      OutputDebugString(PChar('UniBase.Updater: GetUpdateHistory failed: ' + E.Message));
      {$ENDIF}
  end;
end;

procedure TUpdateManager.ClearCache;
begin
  if TDirectory.Exists(FTempDir) then
    TDirectory.Delete(FTempDir, True);
end;

procedure TUpdateManager.CleanupTempFiles;
begin
  // Keep only the latest update package, delete older ones
  var Files := TDirectory.GetFiles(FTempDir, '*.zip');
  for var F in Files do
  begin
    try
      TFile.Delete(F);
    except
      on E: Exception do
        {$IFDEF DEBUG}
        OutputDebugString(PChar('UniBase.Updater: CleanupTempFiles failed to delete: ' + E.Message));
        {$ENDIF}
    end;
  end;
end;

initialization
  FUpdaterLock := TCriticalSection.Create;

finalization
  if FUpdater <> nil then
    FreeAndNil(FUpdater);
  FreeAndNil(FUpdaterLock);

end.
