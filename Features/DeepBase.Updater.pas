{ ============================================================================
  DeepBase.Updater - Secure Auto-Update System
  
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

unit DeepBase.Updater;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  System.Generics.Collections,
  System.Generics.Defaults,
  System.IOUtils,
  System.Net.URLClient,
  System.NetEncoding,
  System.JSON,
  System.Hash,
  System.DateUtils,
  System.Zip,
  System.SyncObjs,
  System.Threading,
  DeepBase.Exceptions,
  DeepBase.Net.Transport
  {$IFDEF MSWINDOWS}
  , DeepBase.Crypto, DeepBase.Crypto.RSA, Winapi.Windows
  {$ENDIF}
  {$IF DEFINED(MACOS) OR DEFINED(LINUX)}
  , DeepBase.Crypto.OpenSSL
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
  /// Update install mode.
  /// interactive/immediate: install in current flow.
  /// onExit/whenIdle: download and stage first, install later in safe window.
  /// </summary>
  TUpdateInstallMode = (uimUnspecified, uimInteractive, uimImmediate, uimOnExit, uimWhenIdle);

  /// <summary>
  /// API route strategy for update checking.
  /// Auto: infer from URL and optional app_id.
  /// LegacyCheck: GET /check?version=...
  /// Manifest: GET /updates/manifest?current_version=...
  /// </summary>
  TUpdateCheckRouteMode = (ucrmAuto, ucrmLegacyCheck, ucrmManifest);

  /// <summary>
  /// Install policy carried by update metadata.
  /// </summary>
  TUpdateInstallPolicy = record
    Mode: TUpdateInstallMode;
    AllowSilent: Boolean;
    BackgroundDownload: Boolean;
    IdleWindowMinutes: Integer;
    ForceRestart: Boolean;
  end;
  
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
    AppId: string;
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
    SignatureAlgorithm: string;  // rsa-sha256/hmac-sha256/sha256
    ManifestHash: string;
    ManifestSignature: string;
    SignatureRequired: Boolean;
    MinVersion: TSemanticVersion;  // Minimum version for incremental
    IsMandatory: Boolean;
    InstallPolicy: TUpdateInstallPolicy;
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
    FUpdateCheckRouteMode: TUpdateCheckRouteMode;
    FUpdateAppId: string;
    FUpdateDeviceId: string;
    FUpdateAccessToken: string;
    FUpdateApiKey: string;
    FBackupDir: string;
    FTempDir: string;
    FApplicationDir: string;
    FStatus: TUpdateStatus;
    FLastError: string;
    FPublicKey: string;  // RSA public key for signature verification
    FSignatureSecret: string;  // Shared secret for HMAC signature verification
    FInsecureDevMode: Boolean;  // EDGE-006: when True, allows bypass of missing hash/key checks
    FAutoCheck: Boolean;
    FAutoCheckInterval: Integer;  // Hours
    FLastCheckTime: TDateTime;
    FCurrentUpdate: TUpdateInfo;
    FDefaultInstallMode: TUpdateInstallMode;
    FLastStagedPackagePath: string;
    FHelperExePath: string;
    FHelperRunHidden: Boolean;
    FSilentInstallTask: ITask;
    FSilentInstallStopEvent: TEvent;
    FSilentInstallLoopActive: Boolean;
    FOnProgress: TProgressCallback;
    FOnUpdateAvailable: TProc<TUpdateInfo>;
    FLock: TCriticalSection;
    FTransport: IDeepBaseHttpTransport;
    FCancelled: Boolean;
    
    function DownloadFile(const Url, DestPath: string;
      ProgressCallback: TProgressCallback): Boolean;
    function CreateBackup(const Files: TArray<string>): Boolean;
    function RestoreBackup: Boolean;
    function ApplyUpdate(const PackagePath: string; 
      const Info: TUpdateInfo): Boolean;
    function ParseUpdateInfo(const JSON: TJSONObject): TUpdateInfo;
    function BuildManifestSignaturePayload(const Info: TUpdateInfo): string;
    function BuildUpdateCheckUrl: string;
    function BuildUpdateHeaders: TNetHeaders;
    function SendHttpRequest(AMethod: TDeepBaseHttpMethod; const AUrl: string;
      const AHeaders: TNetHeaders = nil): TDeepBaseHttpTransportResponse;
    function ResolveInstallMode(const Info: TUpdateInfo): TUpdateInstallMode;
    function GetSystemIdleMilliseconds: UInt64;
    function StageUpdatePackage(const Info: TUpdateInfo; out PackagePath: string): Boolean;
    function InstallPackage(const Info: TUpdateInfo; const PackagePath: string): Boolean;
    function LaunchHelperForPackage(const Info: TUpdateInfo; const PackagePath: string;
      const MainExePath: string = ''): Boolean;
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

    /// <summary>Set shared secret for hmac-sha256 signature verification</summary>
    procedure SetSignatureSecret(const Secret: string);

    /// <summary>Verify an RSA/HMAC signature over Data (for tests/integration).</summary>
    function VerifySignature(const Data, Signature, Algorithm: string): Boolean;

    /// <summary>Verify a downloaded file's SHA256 hash (for tests/integration).</summary>
    function VerifyFileHash(const FilePath, ExpectedHash: string): Boolean;

    /// <summary>Stage + full verification WITHOUT install (docs/66 §16.5 steps 1-5:
    /// package hash / package signature / manifest hash / manifest signature).
    /// 配置同步等“下载+验证但不安装程序二进制”场景复用。</summary>
    function StageAndVerifyPackage(const Info: TUpdateInfo;
      out PackagePath: string; out ErrorMsg: string): Boolean;

    /// <summary>Enable insecure dev mode: allows updates without hash/signature.
    /// NEVER enable in production builds. Use only for local development testing.</summary>
    property InsecureDevMode: Boolean read FInsecureDevMode write FInsecureDevMode;

    /// <summary>Inject HTTP transport for System.Net/ICS/test implementations.</summary>
    procedure SetHttpTransport(const Transport: IDeepBaseHttpTransport);
    
    /// <summary>Check for updates asynchronously</summary>
    procedure CheckForUpdates(Callback: TCheckUpdateCallback);
    
    /// <summary>Check for updates synchronously</summary>
    function CheckForUpdatesSync(out Info: TUpdateInfo): Boolean;

    /// <summary>Parse update metadata from a JSON string (for tests/integration).</summary>
    function ParseUpdateInfoFromJson(const JsonText: string; out Info: TUpdateInfo): Boolean;
    
    /// <summary>Download and install update</summary>
    procedure DownloadAndInstall(const Info: TUpdateInfo;
      OnComplete: TUpdateCompleteCallback = nil);
    
    /// <summary>Download update only (don't install)</summary>
    procedure DownloadOnly(const Info: TUpdateInfo;
      OnComplete: TUpdateCompleteCallback = nil);
    
    /// <summary>Install previously downloaded update</summary>
    function InstallDownloadedUpdate(const PackagePath: string): Boolean;

    /// <summary>Install staged update package downloaded by DownloadAndInstall in onExit/whenIdle mode</summary>
    function InstallStagedUpdate(const Info: TUpdateInfo;
      const MainExePath: string = ''): Boolean;

    /// <summary>Whether a valid staged package currently exists.</summary>
    function HasStagedUpdate: Boolean;

    /// <summary>
    /// Check whether current install window is ready.
    /// whenIdle requires idle window; onExit requires IsAppExiting=True.
    /// </summary>
    function IsInstallWindowReady(const Info: TUpdateInfo;
      IsAppExiting: Boolean = False): Boolean;

    /// <summary>
    /// Try to install staged update only when policy window is ready.
    /// Returns False (without installing) when still waiting for idle/exit window.
    /// </summary>
    function TryInstallStagedUpdate(const Info: TUpdateInfo;
      const MainExePath: string = ''; IsAppExiting: Boolean = False): Boolean;

    /// <summary>
    /// Start background loop for whenIdle/onExit staged install policy.
    /// Loop checks window readiness and attempts install when possible.
    /// </summary>
    procedure StartSilentInstallLoop(const Info: TUpdateInfo;
      PollIntervalMs: Cardinal = 30000; const MainExePath: string = '');

    /// <summary>Stop background silent-install loop.</summary>
    procedure StopSilentInstallLoop;

    /// <summary>Whether silent-install loop is currently active.</summary>
    function IsSilentInstallLoopRunning: Boolean;

    /// <summary>Try staged install in exit window (onExit policy).</summary>
    function TriggerExitInstall(const Info: TUpdateInfo;
      const MainExePath: string = ''): Boolean;

    /// <summary>Configure helper executable for lock-safe replacement and restart.</summary>
    procedure ConfigureHelper(const HelperExePath: string; RunHidden: Boolean = True);

    /// <summary>Launch helper to install currently staged package (Windows only).</summary>
    function LaunchStagedUpdateWithHelper(const Info: TUpdateInfo;
      const MainExePath: string = ''): Boolean;
    
    /// <summary>Cancel ongoing operation</summary>
    procedure Cancel;
    
    /// <summary>Rollback to previous version</summary>
    function Rollback: Boolean;
    
    /// <summary>Get release notes for version</summary>
    function GetReleaseNotes(const Version: TSemanticVersion): string;
    
    /// <summary>Get update hiDeepStory</summary>
    function GetUpdateHistory: TArray<TUpdateInfo>;
    
    /// <summary>Clear update cache</summary>
    procedure ClearCache;
    
    // Properties
    property UpdateUrl: string read FUpdateUrl write FUpdateUrl;
    property CurrentVersion: TSemanticVersion read FCurrentVersion;
    property Channel: TUpdateChannel read FChannel write FChannel;
    property UpdateCheckRouteMode: TUpdateCheckRouteMode read FUpdateCheckRouteMode write FUpdateCheckRouteMode;
    property UpdateAppId: string read FUpdateAppId write FUpdateAppId;
    property UpdateDeviceId: string read FUpdateDeviceId write FUpdateDeviceId;
    property UpdateAccessToken: string read FUpdateAccessToken write FUpdateAccessToken;
    property UpdateApiKey: string read FUpdateApiKey write FUpdateApiKey;
    property HttpTransport: IDeepBaseHttpTransport read FTransport write SetHttpTransport;
    property Status: TUpdateStatus read FStatus;
    property LastError: string read FLastError;
    property AutoCheck: Boolean read FAutoCheck write FAutoCheck;
    property AutoCheckInterval: Integer read FAutoCheckInterval write FAutoCheckInterval;
    property LastCheckTime: TDateTime read FLastCheckTime;
    property CurrentUpdate: TUpdateInfo read FCurrentUpdate;
    property DefaultInstallMode: TUpdateInstallMode read FDefaultInstallMode write FDefaultInstallMode;
    property LastStagedPackagePath: string read FLastStagedPackagePath;
    property HelperExePath: string read FHelperExePath write FHelperExePath;
    property HelperRunHidden: Boolean read FHelperRunHidden write FHelperRunHidden;
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

/// <summary>Install mode name to enum</summary>
function ParseInstallMode(const Name: string): TUpdateInstallMode;

/// <summary>Install mode enum to name</summary>
function InstallModeToString(Mode: TUpdateInstallMode): string;

implementation

const
  // RSA-2048 公钥，用于验签 update manifest 的 signature / manifest_signature（§16.5 / §16.10）。
  // 生产公钥由 DB4 签发方（王维）生成并回传后填入此处，必须与 docs/66 §16.12 一致。
  // 轮换时升 key_id，客户端走多密钥并存（TODO，本轮单公钥）。
  // 留空时 Initialize 不自动设置——调用方需显式 SetPublicKey，否则验签 fail-closed。
  DEEPBASE_UPDATE_RSA_PUBLIC_KEY_PEM = '';

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
      FreeAndNil(FUpdater);
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

function ParseInstallMode(const Name: string): TUpdateInstallMode;
begin
  if SameText(Name, 'interactive') then
    Result := uimInteractive
  else if SameText(Name, 'immediate') then
    Result := uimImmediate
  else if SameText(Name, 'onExit') or SameText(Name, 'on_exit') then
    Result := uimOnExit
  else if SameText(Name, 'whenIdle') or SameText(Name, 'when_idle') then
    Result := uimWhenIdle
  else
    Result := uimUnspecified;
end;

function InstallModeToString(Mode: TUpdateInstallMode): string;
begin
  case Mode of
    uimInteractive: Result := 'interactive';
    uimImmediate: Result := 'immediate';
    uimOnExit: Result := 'onExit';
    uimWhenIdle: Result := 'whenIdle';
  else
    Result := 'unspecified';
  end;
end;

procedure AddHeader(var AHeaders: TNetHeaders; const AName, AValue: string);
begin
  if AValue = '' then
    Exit;
  SetLength(AHeaders, Length(AHeaders) + 1);
  AHeaders[High(AHeaders)] := TNameValuePair.Create(AName, AValue);
end;

// ============================================================================
// TSemanticVersion
// ============================================================================

class function TSemanticVersion.Parse(const VersionStr: string): TSemanticVersion;
var
  Parts: TArray<string>;
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
  FSilentInstallStopEvent := TEvent.Create(nil, True, False, '');
  FTransport := TDeepBaseSystemNetTransport.Create;
  FChannel := ucStable;
  FUpdateCheckRouteMode := ucrmAuto;
  FUpdateAppId := '';
  FUpdateDeviceId := '';
  FUpdateAccessToken := '';
  FUpdateApiKey := '';
  FStatus := usIdle;
  FAutoCheck := False;
  FAutoCheckInterval := 24;
  FDefaultInstallMode := uimInteractive;
  FLastStagedPackagePath := '';
  FHelperExePath := '';
  FHelperRunHidden := True;
  FSilentInstallTask := nil;
  FSilentInstallLoopActive := False;
  FSignatureSecret := '';
  FInsecureDevMode := False;
  FLastCheckTime := 0;
  FCancelled := False;
  FTempDir := TPath.Combine(TPath.GetTempPath, 'DeepBase_Update');
  FBackupDir := TPath.Combine(TPath.GetTempPath, 'DeepBase_Backup');
end;

destructor TUpdateManager.Destroy;
begin
  StopSilentInstallLoop;
  if FSilentInstallTask <> nil then
  begin
    try
      FSilentInstallTask.Wait;
    except
      // ignore and continue shutdown
    end;
    FSilentInstallTask := nil;
  end;
  FreeAndNil(FSilentInstallStopEvent);
  FTransport := nil;
  FreeAndNil(FLock);
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
  // 默认加载内置 RSA 验签公钥（docs/66 §16.12）。若 const 留空或调用方已显式
  // SetPublicKey，则跳过——保持显式设置优先，避免覆盖。
  if (FPublicKey = '') and (DEEPBASE_UPDATE_RSA_PUBLIC_KEY_PEM <> '') then
    SetPublicKey(DEEPBASE_UPDATE_RSA_PUBLIC_KEY_PEM);
end;

procedure TUpdateManager.SetPublicKey(const PublicKeyPEM: string);
begin
  FPublicKey := PublicKeyPEM;
end;

procedure TUpdateManager.SetSignatureSecret(const Secret: string);
begin
  FSignatureSecret := Secret;
end;

procedure TUpdateManager.SetHttpTransport(
  const Transport: IDeepBaseHttpTransport);
begin
  if Transport = nil then
    FTransport := TDeepBaseSystemNetTransport.Create
  else
    FTransport := Transport;
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
  PolicyObj: TJSONObject;
  I: Integer;
  LMode: string;
  LReleaseNotes: string;
  LDownloadUrl: string;
  LDownloadSize: Int64;
  LPackageHash: string;
  LDateStr: string;
  LVersion: string;

  function ReadString(const AObj: TJSONObject; const PrimaryKey, FallbackKey: string;
    const DefaultValue: string = ''): string;
  begin
    Result := DefaultValue;
    if AObj = nil then
      Exit;
    Result := AObj.GetValue<string>(PrimaryKey, DefaultValue);
    if (Result = '') and (FallbackKey <> '') then
      Result := AObj.GetValue<string>(FallbackKey, DefaultValue);
  end;

  function ReadBool(const AObj: TJSONObject; const PrimaryKey, FallbackKey: string;
    const DefaultValue: Boolean): Boolean;
  begin
    Result := DefaultValue;
    if AObj = nil then
      Exit;
    if AObj.GetValue(PrimaryKey) <> nil then
      Exit(AObj.GetValue<Boolean>(PrimaryKey, DefaultValue));
    if (FallbackKey <> '') and (AObj.GetValue(FallbackKey) <> nil) then
      Exit(AObj.GetValue<Boolean>(FallbackKey, DefaultValue));
  end;

  function ReadInt(const AObj: TJSONObject; const PrimaryKey, FallbackKey: string;
    const DefaultValue: Integer): Integer;
  begin
    Result := DefaultValue;
    if AObj = nil then
      Exit;
    if AObj.GetValue(PrimaryKey) <> nil then
      Exit(AObj.GetValue<Integer>(PrimaryKey, DefaultValue));
    if (FallbackKey <> '') and (AObj.GetValue(FallbackKey) <> nil) then
      Exit(AObj.GetValue<Integer>(FallbackKey, DefaultValue));
  end;
begin
  Result := Default(TUpdateInfo);
  
  if JSON = nil then
    Exit;

  Result.AppId := JSON.GetValue<string>('appId', '');
  if Result.AppId = '' then
    Result.AppId := JSON.GetValue<string>('app_id', '');
  LVersion := JSON.GetValue<string>('version', '');
  if LVersion = '' then
    LVersion := JSON.GetValue<string>('latest_version', '');
  if LVersion = '' then
    LVersion := JSON.GetValue<string>('latestVersion', '');
  Result.Version := TSemanticVersion.Parse(LVersion);
  Result.Title := JSON.GetValue<string>('title', '');
  Result.Description := JSON.GetValue<string>('description', '');
  LReleaseNotes := JSON.GetValue<string>('release_notes', '');
  if LReleaseNotes = '' then
    LReleaseNotes := JSON.GetValue<string>('releaseNotes', '');
  Result.ReleaseNotes := LReleaseNotes;

  LDownloadUrl := JSON.GetValue<string>('package_url', '');
  if LDownloadUrl = '' then
    LDownloadUrl := JSON.GetValue<string>('packageUrl', '');
  if LDownloadUrl = '' then
    LDownloadUrl := JSON.GetValue<string>('download_url', '');
  if LDownloadUrl = '' then
    LDownloadUrl := JSON.GetValue<string>('downloadUrl', '');
  if LDownloadUrl = '' then
    LDownloadUrl := JSON.GetValue<string>('manifest_url', '');
  if LDownloadUrl = '' then
    LDownloadUrl := JSON.GetValue<string>('manifestUrl', '');
  Result.DownloadUrl := LDownloadUrl;

  LDownloadSize := JSON.GetValue<Int64>('download_size', 0);
  if LDownloadSize = 0 then
    LDownloadSize := JSON.GetValue<Int64>('downloadSize', 0);
  if LDownloadSize = 0 then
    LDownloadSize := JSON.GetValue<Int64>('package_size', 0);
  if LDownloadSize = 0 then
    LDownloadSize := JSON.GetValue<Int64>('packageSize', 0);
  if LDownloadSize = 0 then
    LDownloadSize := JSON.GetValue<Int64>('fileSize', 0);
  Result.DownloadSize := LDownloadSize;

  LPackageHash := JSON.GetValue<string>('package_hash', '');
  if LPackageHash = '' then
    LPackageHash := JSON.GetValue<string>('packageHash', '');
  if LPackageHash = '' then
    LPackageHash := JSON.GetValue<string>('sha256', '');
  if SameText(Copy(LPackageHash, 1, 7), 'sha256:') then
    Delete(LPackageHash, 1, 7);
  Result.PackageHash := LowerCase(LPackageHash);
  Result.Signature := JSON.GetValue<string>('signature', '');
  Result.SignatureAlgorithm := JSON.GetValue<string>('signatureAlgorithm', '');
  if Result.SignatureAlgorithm = '' then
    Result.SignatureAlgorithm := JSON.GetValue<string>('signature_algorithm', '');
  Result.ManifestHash := JSON.GetValue<string>('manifestHash', '');
  if Result.ManifestHash = '' then
    Result.ManifestHash := JSON.GetValue<string>('manifest_hash', '');
  Result.ManifestSignature := JSON.GetValue<string>('manifestSignature', '');
  if Result.ManifestSignature = '' then
    Result.ManifestSignature := JSON.GetValue<string>('manifest_signature', '');
  Result.SignatureRequired := ReadBool(JSON, 'signatureRequired', 'signature_required', False);
  Result.IsMandatory := ReadBool(JSON, 'mandatory', 'is_mandatory', False);
  if not Result.IsMandatory then
    Result.IsMandatory := ReadBool(JSON, 'force_update', 'forceUpdate', False);
  Result.Channel := ParseChannel(JSON.GetValue<string>('channel', 'stable'));
  Result.InstallPolicy.Mode := FDefaultInstallMode;
  Result.InstallPolicy.AllowSilent := False;
  Result.InstallPolicy.BackgroundDownload := True;
  Result.InstallPolicy.IdleWindowMinutes := 0;
  Result.InstallPolicy.ForceRestart := Result.IsMandatory;
  
  if JSON.GetValue<string>('update_type', '') = 'incremental' then
    Result.UpdateType := utIncremental
  else if JSON.GetValue<string>('update_type', '') = 'patch' then
    Result.UpdateType := utPatch
  else
    Result.UpdateType := utFull;
  
  Result.MinVersion := TSemanticVersion.Parse(
    JSON.GetValue<string>('min_version', ''));
  
  // Parse release date
  LDateStr := JSON.GetValue<string>('release_date', '');
  if LDateStr = '' then
    LDateStr := JSON.GetValue<string>('releaseDate', '');
  if LDateStr = '' then
    LDateStr := JSON.GetValue<string>('publishedAt', '');
  if LDateStr <> '' then
  begin
    try
      Result.ReleaseDate := ISO8601ToDate(LDateStr);
    except
      Result.ReleaseDate := Now;
    end;
  end
  else
    Result.ReleaseDate := Now;

  PolicyObj := JSON.GetValue<TJSONObject>('installPolicy', nil);
  if PolicyObj = nil then
    PolicyObj := JSON.GetValue<TJSONObject>('install_policy', nil);

  if PolicyObj <> nil then
  begin
    LMode := ReadString(PolicyObj, 'mode', 'installMode', '');
    if LMode = '' then
      LMode := ReadString(PolicyObj, 'install_mode', '', '');
    if LMode <> '' then
      Result.InstallPolicy.Mode := ParseInstallMode(LMode);

    Result.InstallPolicy.AllowSilent := ReadBool(PolicyObj, 'allowSilent', 'allow_silent',
      Result.InstallPolicy.AllowSilent);
    Result.InstallPolicy.BackgroundDownload := ReadBool(PolicyObj, 'backgroundDownload',
      'background_download', Result.InstallPolicy.BackgroundDownload);
    Result.InstallPolicy.IdleWindowMinutes := ReadInt(PolicyObj, 'idleWindowMinutes',
      'idle_window_minutes', Result.InstallPolicy.IdleWindowMinutes);
    Result.InstallPolicy.ForceRestart := ReadBool(PolicyObj, 'forceRestart', 'force_restart',
      Result.InstallPolicy.ForceRestart);
  end
  else
  begin
    LMode := ReadString(JSON, 'installMode', 'install_mode', '');
    if LMode <> '' then
      Result.InstallPolicy.Mode := ParseInstallMode(LMode);
    Result.InstallPolicy.AllowSilent := ReadBool(JSON, 'allowSilent', 'allow_silent',
      Result.InstallPolicy.AllowSilent);
    Result.InstallPolicy.BackgroundDownload := ReadBool(JSON, 'backgroundDownload',
      'background_download', Result.InstallPolicy.BackgroundDownload);
    Result.InstallPolicy.IdleWindowMinutes := ReadInt(JSON, 'idleWindowMinutes',
      'idle_window_minutes', Result.InstallPolicy.IdleWindowMinutes);
    Result.InstallPolicy.ForceRestart := ReadBool(JSON, 'forceRestart', 'force_restart',
      Result.InstallPolicy.ForceRestart);
  end;
  
  // Parse files list
  FilesArray := JSON.GetValue<TJSONArray>('files', nil);
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
      if Result.Files[I].Hash = '' then
        Result.Files[I].Hash := FileObj.GetValue<string>('sha256', '');
      Result.Files[I].Action := FileObj.GetValue<string>('action', 'update');

      if I = 0 then
      begin
        if Result.DownloadUrl = '' then
        begin
          Result.DownloadUrl := FileObj.GetValue<string>('url', '');
          if Result.DownloadUrl = '' then
            Result.DownloadUrl := FileObj.GetValue<string>('downloadUrl', '');
        end;
        if Result.DownloadSize = 0 then
          Result.DownloadSize := Result.Files[I].Size;
        if Result.PackageHash = '' then
          Result.PackageHash := LowerCase(Result.Files[I].Hash);
      end;
    end;
  end;

  // EDGE-006 fix: auto-require signature when trust anchors are configured
  // or when metadata already contains a signature. This prevents an attacker
  // from stripping the signature field from metadata to bypass verification.
  if not Result.SignatureRequired then
    Result.SignatureRequired := (Result.Signature <> '') or
      (Result.ManifestSignature <> '') or
      (FPublicKey <> '') or
      (FSignatureSecret <> '');
  if Result.SignatureAlgorithm = '' then
    Result.SignatureAlgorithm := 'rsa-sha256';
end;

function TUpdateManager.BuildUpdateCheckUrl: string;
var
  Base: string;
  LowerBase: string;
  UseManifest: Boolean;

  procedure AddQueryPair(const AName, AValue: string);
  begin
    if AValue = '' then
      Exit;
    if Pos('?', Base) = 0 then
      Base := Base + '?'
    else
      Base := Base + '&';
    Base := Base + TNetEncoding.URL.Encode(AName) + '=' +
      TNetEncoding.URL.Encode(AValue);
  end;
begin
  Base := Trim(FUpdateUrl);
  if Base = '' then
    Exit('');

  while Base.EndsWith('/') do
    Delete(Base, Length(Base), 1);
  LowerBase := LowerCase(Base);

  case FUpdateCheckRouteMode of
    ucrmLegacyCheck: UseManifest := False;
    ucrmManifest: UseManifest := True;
  else
    begin
      if LowerBase.EndsWith('/check') then
        UseManifest := False
      else if LowerBase.EndsWith('/updates/manifest') then
        UseManifest := True
      else
        UseManifest := FUpdateAppId <> '';
    end;
  end;

  if not LowerBase.EndsWith('/check') and
     not LowerBase.EndsWith('/updates/manifest') then
  begin
    if UseManifest then
      Base := Base + '/updates/manifest'
    else
      Base := Base + '/check';
  end;

  AddQueryPair('channel', ChannelToString(FChannel));
  AddQueryPair('platform', 'windows');
  AddQueryPair('version', FCurrentVersion.ToString);
  AddQueryPair('current_version', FCurrentVersion.ToString);
  AddQueryPair('app_id', FUpdateAppId);
  AddQueryPair('device_id', FUpdateDeviceId);

  Result := Base;
end;

function TUpdateManager.BuildUpdateHeaders: TNetHeaders;
begin
  SetLength(Result, 0);
  if FUpdateAccessToken <> '' then
    AddHeader(Result, 'Authorization', 'Bearer ' + FUpdateAccessToken);
  if FUpdateApiKey <> '' then
    AddHeader(Result, 'X-API-Key', FUpdateApiKey);
end;

function TUpdateManager.SendHttpRequest(AMethod: TDeepBaseHttpMethod;
  const AUrl: string; const AHeaders: TNetHeaders):
  TDeepBaseHttpTransportResponse;
var
  Request: TDeepBaseHttpTransportRequest;
begin
  if FTransport = nil then
    FTransport := TDeepBaseSystemNetTransport.Create;

  Request := TDeepBaseHttpTransportRequest.Create(AMethod, AUrl);
  Request.Headers := AHeaders;
  Request.TimeoutMs := 30000;
  Request.FollowRedirects := True;
  Result := FTransport.Send(Request);
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
  Response: TDeepBaseHttpTransportResponse;
  JSON: TJSONObject;
  Url: string;
  Headers: TNetHeaders;
begin
  Result := False;
  Info := Default(TUpdateInfo);
  
  SetStatus(usCheckingForUpdates, 'Checking for updates...');
  FCancelled := False;
  
  try
    // Build update check URL (legacy /check and /updates/manifest are both supported).
    Url := BuildUpdateCheckUrl;
    if Url = '' then
      raise Exception.Create('UpdateUrl is not configured');

    Headers := BuildUpdateHeaders;
    Response := SendHttpRequest(dbhmGet, Url, Headers);
    
    if Response.StatusCode = 200 then
    begin
      JSON := TJSONObject.ParseJSONValue(Response.Body) as TJSONObject;
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
      FLastError := Copy(Response.Body, 1, 300);
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

function TUpdateManager.BuildManifestSignaturePayload(
  const Info: TUpdateInfo): string;
begin
  Result := Info.AppId + '|' + Info.Version.ToString + '|' +
    ChannelToString(Info.Channel) + '|' + Info.DownloadUrl + '|' +
    IntToStr(Info.DownloadSize) + '|' + Info.PackageHash + '|' + Info.Signature;
end;

function TUpdateManager.ParseUpdateInfoFromJson(const JsonText: string;
  out Info: TUpdateInfo): Boolean;
var
  JSON: TJSONObject;
begin
  Result := False;
  Info := Default(TUpdateInfo);
  if Trim(JsonText) = '' then
    Exit;

  JSON := TJSONObject.ParseJSONValue(JsonText) as TJSONObject;
  try
    if JSON = nil then
      Exit;
    Info := ParseUpdateInfo(JSON);
    Result := not Info.IsEmpty;
  finally
    JSON.Free;
  end;
end;

function TUpdateManager.ResolveInstallMode(const Info: TUpdateInfo): TUpdateInstallMode;
begin
  Result := Info.InstallPolicy.Mode;
  if Result = uimUnspecified then
    Result := FDefaultInstallMode;
  if Result = uimUnspecified then
    Result := uimInteractive;
end;

function TUpdateManager.GetSystemIdleMilliseconds: UInt64;
{$IFDEF MSWINDOWS}
var
  LastInput: TLastInputInfo;
  TickNow: UInt64;
{$ENDIF}
begin
  Result := 0;
  {$IFDEF MSWINDOWS}
  LastInput.cbSize := SizeOf(LastInput);
  if GetLastInputInfo(LastInput) then
  begin
    TickNow := GetTickCount64;
    if TickNow >= LastInput.dwTime then
      Result := TickNow - LastInput.dwTime;
  end;
  {$ENDIF}
end;

function TUpdateManager.StageUpdatePackage(const Info: TUpdateInfo; out PackagePath: string): Boolean;
begin
  PackagePath := TPath.Combine(FTempDir, Format('update_%s.zip', [Info.Version.ToString]));
  Result := DownloadFile(Info.DownloadUrl, PackagePath, FOnProgress);
  if not Result then
    Exit;
  SetStatus(usVerifying, 'Verifying download...');
  Result := VerifyFileHash(PackagePath, Info.PackageHash);
  if not Result then
    FLastError := 'Package hash verification failed';
end;

function TUpdateManager.StageAndVerifyPackage(const Info: TUpdateInfo;
  out PackagePath: string; out ErrorMsg: string): Boolean;
var
  SignatureAlg, ManifestPayload, ComputedManifestHash, ExpectedManifestHash: string;
begin
  Result := False;
  PackagePath := '';
  ErrorMsg := '';
  try
    SetStatus(usDownloading, 'Downloading package...');
    if not StageUpdatePackage(Info, PackagePath) then
    begin
      ErrorMsg := FLastError;
      Exit;
    end;

    // Insecure dev mode bypass (strictly for local dev testing)
    if FInsecureDevMode then
    begin
      Result := True;
      Exit;
    end;

    SignatureAlg := Trim(Info.SignatureAlgorithm).ToLower;
    if SignatureAlg = '' then
      SignatureAlg := 'rsa-sha256';

    if Info.SignatureRequired then
    begin
      if (Pos('hmac', SignatureAlg) = 1) and (FSignatureSecret = '') then
      begin
        ErrorMsg := 'Package signature verification is required but HMAC secret is not configured';
        Exit;
      end;
      if (Pos('rsa', SignatureAlg) = 1) and (FPublicKey = '') then
      begin
        ErrorMsg := 'Package signature verification is required but RSA public key is not configured';
        Exit;
      end;
    end;

    if Info.Signature <> '' then
    begin
      if not VerifySignature(Info.PackageHash, Info.Signature, SignatureAlg) then
      begin
        ErrorMsg := 'Package signature verification failed';
        Exit;
      end;
    end
    else if Info.SignatureRequired then
    begin
      ErrorMsg := 'Package signature is missing';
      Exit;
    end;

    if Info.ManifestSignature <> '' then
    begin
      ManifestPayload := BuildManifestSignaturePayload(Info);
      ComputedManifestHash := LowerCase(THashSHA2.GetHashString(ManifestPayload));
      // docs/66 §16.10: manifest_hash 允许 'sha256:' 前缀，比对前剥离
      ExpectedManifestHash := Info.ManifestHash;
      if SameText(Copy(ExpectedManifestHash, 1, 7), 'sha256:') then
        Delete(ExpectedManifestHash, 1, 7);
      if (ExpectedManifestHash <> '') and (not SameText(ExpectedManifestHash, ComputedManifestHash)) then
      begin
        ErrorMsg := 'Manifest hash verification failed';
        Exit;
      end;
      // §16.10 Step 6: manifest_signature 签的是 payload 的 UTF-8 字节（非 hash）
      if not VerifySignature(ManifestPayload, Info.ManifestSignature, SignatureAlg) then
      begin
        ErrorMsg := 'Manifest signature verification failed';
        Exit;
      end;
    end
    else if Info.SignatureRequired then
    begin
      ErrorMsg := 'Manifest signature is missing';
      Exit;
    end;

    Result := True;
  except
    on E: Exception do
    begin
      ErrorMsg := E.Message;
      Result := False;
    end;
  end;
  if not Result then
    SetStatus(usFailed, ErrorMsg);
end;

function TUpdateManager.InstallPackage(const Info: TUpdateInfo; const PackagePath: string): Boolean;
var
  FilesToBackup: TArray<string>;
  I: Integer;
begin
  SetLength(FilesToBackup, Length(Info.Files));
  for I := 0 to High(Info.Files) do
    FilesToBackup[I] := Info.Files[I].RelativePath;

  Result := CreateBackup(FilesToBackup);
  if not Result then
    Exit;

  Result := ApplyUpdate(PackagePath, Info);
end;

function TUpdateManager.LaunchHelperForPackage(const Info: TUpdateInfo;
  const PackagePath: string; const MainExePath: string): Boolean;
{$IFDEF MSWINDOWS}
var
  HelperPath: string;
  TargetExe: string;
  RestartFlag: string;
  CmdLine: string;
  MutableCmdLine: string;
  StartInfo: TStartupInfo;
  ProcInfo: TProcessInformation;
{$ENDIF}
begin
  Result := False;
  if PackagePath = '' then
  begin
    FLastError := 'Package path is empty';
    Exit;
  end;

  if not FileExists(PackagePath) then
  begin
    FLastError := 'Update package not found: ' + PackagePath;
    Exit;
  end;

  {$IFDEF MSWINDOWS}
  HelperPath := Trim(FHelperExePath);
  if HelperPath = '' then
    HelperPath := TPath.Combine(FApplicationDir, 'UpdaterHelper.exe');

  if not FileExists(HelperPath) then
  begin
    FLastError := 'Updater helper not found: ' + HelperPath;
    Exit;
  end;

  if MainExePath <> '' then
    TargetExe := MainExePath
  else
    TargetExe := ParamStr(0);

  if Info.InstallPolicy.ForceRestart then
    RestartFlag := '1'
  else
    RestartFlag := '0';

  CmdLine := Format('"%s" --mode install --package "%s" --appdir "%s" --target "%s" --restart %s --sha256 "%s" --wait-ms 30000',
    [HelperPath, PackagePath, FApplicationDir, TargetExe, RestartFlag, Info.PackageHash]);
  MutableCmdLine := CmdLine;
  UniqueString(MutableCmdLine);

  ZeroMemory(@StartInfo, SizeOf(StartInfo));
  StartInfo.cb := SizeOf(StartInfo);
  StartInfo.dwFlags := STARTF_USESHOWWINDOW;
  if FHelperRunHidden then
    StartInfo.wShowWindow := SW_HIDE
  else
    StartInfo.wShowWindow := SW_SHOWNORMAL;

  ZeroMemory(@ProcInfo, SizeOf(ProcInfo));
  Result := CreateProcess(nil, PChar(MutableCmdLine), nil, nil, False, 0, nil,
    PChar(FApplicationDir), StartInfo, ProcInfo);

  if Result then
  begin
    CloseHandle(ProcInfo.hThread);
    CloseHandle(ProcInfo.hProcess);
  end
  else
    FLastError := 'Failed to launch updater helper: ' + SysErrorMessage(GetLastError);
  {$ELSE}
  FLastError := 'Updater helper is only supported on Windows';
  {$ENDIF}
end;

function TUpdateManager.DownloadFile(const Url, DestPath: string;
  ProgressCallback: TProgressCallback): Boolean;
var
  Response: TDeepBaseHttpTransportResponse;
  FileStream: TFileStream;
begin
  Result := False;
  
  try
    // Ensure directory exists
    ForceDirectories(TPath.GetDirectoryName(DestPath));
    
    Response := SendHttpRequest(dbhmGet, Url);
    
    if (Response.StatusCode = 200) and not FCancelled then
    begin
      FileStream := TFileStream.Create(DestPath, fmCreate);
      try
        if Length(Response.BodyBytes) > 0 then
          FileStream.WriteBuffer(Response.BodyBytes[0], Length(Response.BodyBytes));
        Result := True;
      finally
        FreeAndNil(FileStream);
      end;
    end;
  except
    on E: Exception do
    begin
      FLastError := 'Download failed: ' + E.Message;
    end;
  end;
end;

function TUpdateManager.VerifySignature(const Data, Signature,
  Algorithm: string): Boolean;
{$IFDEF MSWINDOWS}
var
  LVerifier: TRSAVerifier;
{$ENDIF}
{$IF DEFINED(MACOS) OR DEFINED(LINUX)}
var
  LDataBytes: TBytes;
  LError: string;
{$ENDIF}
var
  LAlgorithm: string;
  LExpected: string;
begin
  LAlgorithm := Trim(Algorithm).ToLower;
  if LAlgorithm = '' then
    LAlgorithm := 'rsa-sha256';

  if Signature = '' then
  begin
    Result := False;
    FLastError := 'Signature is empty';
    Exit;
  end;

  if (LAlgorithm = 'sha256') or (LAlgorithm = 'sha-256') then
  begin
    LExpected := LowerCase(THashSHA2.GetHashString(Data));
    Result := SameText(LExpected, Signature);
    if not Result then
      FLastError := 'SHA256 signature mismatch';
    Exit;
  end;

  if (LAlgorithm = 'hmac-sha256') or (LAlgorithm = 'hmac_sha256') then
  begin
    if FSignatureSecret = '' then
    begin
      FLastError := 'HMAC signature secret is not configured';
      Exit(False);
    end;
    LExpected := LowerCase(THashSHA2.GetHMAC(Data, FSignatureSecret));
    Result := SameText(LExpected, Signature);
    if not Result then
      FLastError := 'HMAC-SHA256 signature mismatch';
    Exit;
  end;

  // Default: RSA-SHA256
  // EDGE-006 fix: missing public key must fail-closed in production.
  // Only allow bypass in explicit dev/insecure mode.
  if FPublicKey = '' then
  begin
    if FInsecureDevMode then
    begin
      FLastError := 'WARNING: Signature verification skipped (insecure dev mode, no public key)';
      Exit(True);
    end;
    FLastError := 'RSA public key is not configured. Cannot verify update signature.';
    Exit(False);
  end;

  {$IFDEF MSWINDOWS}
  LVerifier := TRSAVerifier.Create;
  try
    if not LVerifier.LoadPublicKeyPEM(FPublicKey) then
    begin
      FLastError := 'Failed to load public key: ' + LVerifier.LastError;
      Exit(False);
    end;

    Result := LVerifier.VerifySignature(Data, Signature);
    if not Result then
      FLastError := 'Signature verification failed: ' + LVerifier.LastError;
  finally
    LVerifier.Free;
  end;
  {$ELSE}
    {$IF DEFINED(MACOS) OR DEFINED(LINUX)}
    LDataBytes := TEncoding.UTF8.GetBytes(Data);
    Result := OpenSSL_RSAVerifySHA256(FPublicKey, LDataBytes, Signature, LError);
    if not Result then
      FLastError := LError;
    {$ELSE}
    Result := False;
    FLastError := 'Signature verification not implemented on this platform';
    {$ENDIF}
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
  
  // EDGE-006 fix: empty hash must fail-closed in production.
  // Only allow bypass in explicit dev/insecure mode.
  if ExpectedHash = '' then
  begin
    if FInsecureDevMode then
      Exit(True);
    FLastError := 'Package hash is missing. Cannot verify update integrity.';
    Exit(False);
  end;
  
  FileStream := TFileStream.Create(FilePath, fmOpenRead or fmShareDenyWrite);
  try
    ActualHash := THashSHA2.GetHashString(FileStream, SHA256);
    Result := SameText(ActualHash, ExpectedHash);
  finally
    FreeAndNil(FileStream);
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
  ExtractPath, FileName, DestPath, CanonicalExtract, CanonicalDest: string;
  I: Integer;
  FileNames: TArray<string>;
begin
  Result := False;
  
  SetStatus(usInstalling, 'Installing update...');
  
  try
    ExtractPath := TPath.Combine(FTempDir, 'extract_' + 
      FormatDateTime('yyyymmdd_hhnnss', Now));
    ForceDirectories(ExtractPath);
    CanonicalExtract := IncludeTrailingPathDelimiter(
      TPath.GetFullPath(ExtractPath));
    
    // EDGE-007 fix: safe extraction — validate each entry before extracting.
    // Reject absolute paths, parent directory traversal (../), and entries
    // that would escape the extraction directory.
    Zip := TZipFile.Create;
    try
      Zip.Open(PackagePath, zmRead);
      for I := 0 to Zip.FileCount - 1 do
      begin
        FileName := Zip.FileNames[I];
        // Reject absolute paths
        if TPath.IsPathRooted(FileName) then
          raise EInvalidOperationException.CreateFmt(
            'Unsafe zip entry (absolute path): %s', [FileName]);
        // Reject parent directory traversal
        if Pos('..', FileName) > 0 then
          raise EInvalidOperationException.CreateFmt(
            'Unsafe zip entry (path traversal): %s', [FileName]);
        // Verify canonical path stays within extract directory
        CanonicalDest := TPath.GetFullPath(TPath.Combine(ExtractPath, FileName));
        if not CanonicalDest.StartsWith(CanonicalExtract, True) then
          raise EInvalidOperationException.CreateFmt(
            'Unsafe zip entry (escapes target): %s', [FileName]);
      end;
      // All entries validated — now extract
      Zip.ExtractAll(ExtractPath);
      Zip.Close;
    finally
      Zip.Free;
    end;
    
    // Get list of files to update
    FileNames := TDirectory.GetFiles(ExtractPath, '*.*', 
      TSearchOption.soAllDirectories);
    
    // Copy files to application directory with path validation
    for I := 0 to High(FileNames) do
    begin
      if FCancelled then
      begin
        RestoreBackup;
        Exit;
      end;
      
      FileName := Copy(FileNames[I], Length(ExtractPath) + 2, MaxInt);
      DestPath := TPath.Combine(FApplicationDir, FileName);
      
      // EDGE-007: verify destination stays within application directory
      CanonicalDest := TPath.GetFullPath(DestPath);
      if not CanonicalDest.StartsWith(
        IncludeTrailingPathDelimiter(TPath.GetFullPath(FApplicationDir)), True) then
      begin
        FLastError := Format('Unsafe file path rejected: %s', [FileName]);
        RestoreBackup;
        Exit;
      end;
      
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
      InstallMode: TUpdateInstallMode;
      Success: Boolean;
      ErrorMsg: string;
      SignatureAlg: string;
      ManifestPayload: string;
      ComputedManifestHash: string;
    begin
      Success := False;
      ErrorMsg := '';
      FCancelled := False;
      
      try
        SetStatus(usDownloading, 'Downloading update...');

        if not StageUpdatePackage(Info, PackagePath) then
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

        SignatureAlg := Trim(Info.SignatureAlgorithm).ToLower;
        if SignatureAlg = '' then
          SignatureAlg := 'rsa-sha256';

        if Info.SignatureRequired then
        begin
          if ((Pos('hmac', SignatureAlg) = 1) and (FSignatureSecret = '')) then
          begin
            ErrorMsg := 'Package signature verification is required but HMAC secret is not configured';
            SetStatus(usFailed, ErrorMsg);
            Exit;
          end;
          if ((Pos('rsa', SignatureAlg) = 1) and (FPublicKey = '')) then
          begin
            ErrorMsg := 'Package signature verification is required but RSA public key is not configured';
            SetStatus(usFailed, ErrorMsg);
            Exit;
          end;
        end;

        if Info.Signature <> '' then
        begin
          if not VerifySignature(Info.PackageHash, Info.Signature, SignatureAlg) then
          begin
            ErrorMsg := 'Package signature verification failed';
            SetStatus(usFailed, ErrorMsg);
            Exit;
          end;
        end
        else if Info.SignatureRequired then
        begin
          ErrorMsg := 'Package signature is missing';
          SetStatus(usFailed, ErrorMsg);
          Exit;
        end;

        if Info.ManifestSignature <> '' then
        begin
          ManifestPayload := BuildManifestSignaturePayload(Info);
          ComputedManifestHash := LowerCase(THashSHA2.GetHashString(ManifestPayload));
          if (Info.ManifestHash <> '') and (not SameText(Info.ManifestHash, ComputedManifestHash)) then
          begin
            ErrorMsg := 'Manifest hash verification failed';
            SetStatus(usFailed, ErrorMsg);
            Exit;
          end;
          if not VerifySignature(ComputedManifestHash, Info.ManifestSignature, SignatureAlg) then
          begin
            ErrorMsg := 'Manifest signature verification failed';
            SetStatus(usFailed, ErrorMsg);
            Exit;
          end;
        end
        else if Info.SignatureRequired then
        begin
          ErrorMsg := 'Manifest signature is missing';
          SetStatus(usFailed, ErrorMsg);
          Exit;
        end;

        InstallMode := ResolveInstallMode(Info);
        if InstallMode in [uimOnExit, uimWhenIdle] then
        begin
          FLastStagedPackagePath := PackagePath;
          SetStatus(usIdle, Format('Update staged (%s). Install in safe window.',
            [InstallModeToString(InstallMode)]));
          Success := True;
        end
        else
        begin
          Success := InstallPackage(Info, PackagePath);
          if not Success then
            ErrorMsg := FLastError
          else if SameFileName(FLastStagedPackagePath, PackagePath) then
            FLastStagedPackagePath := '';
        end;
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

procedure TUpdateManager.ConfigureHelper(const HelperExePath: string; RunHidden: Boolean);
begin
  FHelperExePath := Trim(HelperExePath);
  FHelperRunHidden := RunHidden;
end;

function TUpdateManager.LaunchStagedUpdateWithHelper(const Info: TUpdateInfo;
  const MainExePath: string): Boolean;
begin
  Result := False;
  if FLastStagedPackagePath = '' then
  begin
    FLastError := 'No staged update package';
    Exit;
  end;

  if not FileExists(FLastStagedPackagePath) then
  begin
    FLastError := 'Staged update package missing';
    FLastStagedPackagePath := '';
    Exit;
  end;

  Result := LaunchHelperForPackage(Info, FLastStagedPackagePath, MainExePath);
  if Result then
    SetStatus(usInstalling, 'Updater helper launched');
end;

function TUpdateManager.HasStagedUpdate: Boolean;
begin
  Result := (FLastStagedPackagePath <> '') and FileExists(FLastStagedPackagePath);
end;

function TUpdateManager.IsInstallWindowReady(const Info: TUpdateInfo;
  IsAppExiting: Boolean): Boolean;
var
  Mode: TUpdateInstallMode;
  RequiredIdleMinutes: Integer;
begin
  Mode := ResolveInstallMode(Info);
  case Mode of
    uimOnExit:
      Result := IsAppExiting;
    uimWhenIdle:
      begin
        RequiredIdleMinutes := Info.InstallPolicy.IdleWindowMinutes;
        if RequiredIdleMinutes <= 0 then
          Exit(True);
        {$IFDEF MSWINDOWS}
        Result := GetSystemIdleMilliseconds >=
          (UInt64(RequiredIdleMinutes) * 60 * 1000);
        {$ELSE}
        Result := True;
        {$ENDIF}
      end;
  else
    Result := True;
  end;
end;

function TUpdateManager.TryInstallStagedUpdate(const Info: TUpdateInfo;
  const MainExePath: string; IsAppExiting: Boolean): Boolean;
var
  Mode: TUpdateInstallMode;
  RequiredIdleMinutes: Integer;
begin
  Result := False;
  if not HasStagedUpdate then
  begin
    FLastError := 'No staged update package';
    Exit;
  end;

  if not IsInstallWindowReady(Info, IsAppExiting) then
  begin
    Mode := ResolveInstallMode(Info);
    case Mode of
      uimOnExit:
        FLastError := 'Staged update is waiting for application exit window';
      uimWhenIdle:
        begin
          RequiredIdleMinutes := Info.InstallPolicy.IdleWindowMinutes;
          FLastError := Format('Staged update is waiting for idle window (%d minute(s))',
            [RequiredIdleMinutes]);
        end;
    else
      FLastError := 'Staged update install window is not ready';
    end;
    SetStatus(usIdle, FLastError);
    Exit;
  end;

  Result := InstallStagedUpdate(Info, MainExePath);
end;

procedure TUpdateManager.StartSilentInstallLoop(const Info: TUpdateInfo;
  PollIntervalMs: Cardinal; const MainExePath: string);
var
  LInfo: TUpdateInfo;
  LMainExePath: string;
  LPollIntervalMs: Cardinal;
begin
  StopSilentInstallLoop;

  LInfo := Info;
  LMainExePath := MainExePath;
  LPollIntervalMs := PollIntervalMs;
  if LPollIntervalMs < 1000 then
    LPollIntervalMs := 1000;

  if FSilentInstallStopEvent = nil then
    Exit;
  FSilentInstallStopEvent.ResetEvent;

  FLock.Enter;
  try
    FSilentInstallLoopActive := True;
  finally
    FLock.Leave;
  end;

  FSilentInstallTask := TTask.Run(
    procedure
    begin
      try
        while True do
        begin
          if FSilentInstallStopEvent.WaitFor(0) = wrSignaled then
            Break;

          if not HasStagedUpdate then
            Break;

          if TryInstallStagedUpdate(LInfo, LMainExePath, False) then
            Break;

          if FSilentInstallStopEvent.WaitFor(LPollIntervalMs) = wrSignaled then
            Break;
        end;
      finally
        FLock.Enter;
        try
          FSilentInstallLoopActive := False;
        finally
          FLock.Leave;
        end;
      end;
    end);
end;

procedure TUpdateManager.StopSilentInstallLoop;
begin
  if FSilentInstallStopEvent <> nil then
    FSilentInstallStopEvent.SetEvent;
end;

function TUpdateManager.IsSilentInstallLoopRunning: Boolean;
begin
  FLock.Enter;
  try
    Result := FSilentInstallLoopActive;
  finally
    FLock.Leave;
  end;
end;

function TUpdateManager.TriggerExitInstall(const Info: TUpdateInfo;
  const MainExePath: string): Boolean;
begin
  Result := TryInstallStagedUpdate(Info, MainExePath, True);
end;

function TUpdateManager.InstallStagedUpdate(const Info: TUpdateInfo;
  const MainExePath: string): Boolean;
begin
  Result := False;
  if FLastStagedPackagePath = '' then
  begin
    FLastError := 'No staged update package';
    Exit;
  end;

  if not FileExists(FLastStagedPackagePath) then
  begin
    FLastError := 'Staged update package missing';
    FLastStagedPackagePath := '';
    Exit;
  end;

  if Info.InstallPolicy.AllowSilent then
  begin
    Result := LaunchHelperForPackage(Info, FLastStagedPackagePath, MainExePath);
    if Result then
    begin
      SetStatus(usInstalling, 'Updater helper launched');
      Exit;
    end;
    // Fallback to in-process install if helper unavailable or launch failed.
  end;

  Result := InstallPackage(Info, FLastStagedPackagePath);
  if Result then
    FLastStagedPackagePath := '';
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
  Response: TDeepBaseHttpTransportResponse;
  Url: string;
begin
  Result := '';
  
  try
    Url := FUpdateUrl;
    if not Url.EndsWith('/') then
      Url := Url + '/';
    Url := Url + Format('release-notes/%s', [Version.ToString]);
    
    Response := SendHttpRequest(dbhmGet, Url);
    if Response.StatusCode = 200 then
      Result := Response.Body;
  except
    on E: Exception do
      {$IFDEF DEBUG}
      OutputDebugString(PChar('DeepBase.Updater: GetReleaseNotes failed: ' + E.Message));
      {$ENDIF}
  end;
end;

function TUpdateManager.GetUpdateHistory: TArray<TUpdateInfo>;
var
  Response: TDeepBaseHttpTransportResponse;
  Url: string;
  JSON: TJSONArray;
  I: Integer;
begin
  SetLength(Result, 0);
  
  try
    Url := FUpdateUrl;
    if not Url.EndsWith('/') then
      Url := Url + '/';
    Url := Url + 'hiDeepStory';
    
    Response := SendHttpRequest(dbhmGet, Url);
    if Response.StatusCode = 200 then
    begin
      JSON := TJSONObject.ParseJSONValue(Response.Body) as TJSONArray;
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
      OutputDebugString(PChar('DeepBase.Updater: GetUpdateHistory failed: ' + E.Message));
      {$ENDIF}
  end;
end;

procedure TUpdateManager.ClearCache;
begin
  if TDirectory.Exists(FTempDir) then
    TDirectory.Delete(FTempDir, True);
  FLastStagedPackagePath := '';
end;

procedure TUpdateManager.CleanupTempFiles;
begin
  // Keep only the latest update package, delete older ones
  var Files := TDirectory.GetFiles(FTempDir, '*.zip');
  for var F in Files do
  begin
    if (FLastStagedPackagePath <> '') and SameFileName(F, FLastStagedPackagePath) then
      Continue;
    try
      TFile.Delete(F);
    except
      on E: Exception do
        {$IFDEF DEBUG}
        OutputDebugString(PChar('DeepBase.Updater: CleanupTempFiles failed to delete: ' + E.Message));
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
