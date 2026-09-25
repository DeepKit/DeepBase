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
  DeepBase.Gate.Verdict,
  DeepBase.Update.Contracts,
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
  // Update contracts (SSOT: DeepBase.Update.Contracts)
  // 版本/通道/安装策略/TUpdateInfo 的规范类型定义在 Contracts 单元；
  // 本单元只做别名转接，禁止第二套记录定义（AU-06）。
  // ============================================================================

  TSemanticVersion = DeepBase.Update.Contracts.TSemanticVersion;
  TUpdateChannel = DeepBase.Update.Contracts.TUpdateChannel;
  TUpdateType = DeepBase.Update.Contracts.TUpdateType;
  TUpdateInstallMode = DeepBase.Update.Contracts.TUpdateInstallMode;
  TUpdateInstallPolicy = DeepBase.Update.Contracts.TUpdateInstallPolicy;
  TUpdateFile = DeepBase.Update.Contracts.TUpdateFile;
  TUpdateInfo = DeepBase.Update.Contracts.TUpdateInfo;

  /// <summary>
  /// API route strategy for update checking.
  /// Auto: infer from URL and optional app_id.
  /// LegacyCheck: GET /check?version=...
  /// Manifest: GET /updates/manifest?current_version=...
  /// </summary>
  TUpdateCheckRouteMode = (ucrmAuto, ucrmLegacyCheck, ucrmManifest);

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
    FAllowedHosts: TArray<string>;  // 更新端点主机白名单（改法项 (4)），空=拒绝
{$IFNDEF RELEASE}
    FInsecureDevMode: Boolean;  // EDGE-006: dev-only bypass; compiled out of RELEASE builds
{$ENDIF}
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
    function BuildUpdateCheckUrl: string;
    function BuildUpdateHeaders: TNetHeaders;
    function SendHttpRequest(AMethod: TDeepBaseHttpMethod; const AUrl: string;
      const AHeaders: TNetHeaders = nil): TDeepBaseHttpTransportResponse;
    function EffectiveAllowedHosts: TArray<string>;
    function ResolveInstallMode(const Info: TUpdateInfo): TUpdateInstallMode;
    function GetSystemIdleMilliseconds: UInt64;
    function StageUpdatePackage(const Info: TUpdateInfo; out PackagePath: string): Boolean;
    function InstallPackage(const Info: TUpdateInfo; const PackagePath: string): Boolean;
    /// 清单侧 fail-closed 门禁（B2-08）：策略字段齐备 + manifest hash 自洽 + manifest 验签。
    /// 唯一实现处，下载前（StageAndVerifyPackage）与就地安装（InstallDownloadedUpdate）共用，
    /// 不再出现第二条「不验签直接装」的路径。
    function VerifyUpdateManifest(const Info: TUpdateInfo): TGateVerdict;
    /// 包签名门禁（B2-08）：data = 归一化 PackageHash 的 UTF-8 字节（§16.10 关键点 1）。
    function VerifyUpdatePackageSignature(const Info: TUpdateInfo): TGateVerdict;
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

    /// <summary>Gate (A6 TGateVerdict): verify an RSA-SHA256 signature over Data
    /// (UTF-8 bytes, single-layer SHA-256 digest). 算法固定本地信任锚，
    /// 不接受远端自述；空字段/缺公钥 ⇒ gdRejected。</summary>
    function VerifySignature(const Data, Signature: string): TGateVerdict;

    /// <summary>Gate (A6 TGateVerdict): verify a downloaded file's SHA256 hash.</summary>
    function VerifyFileHash(const FilePath, ExpectedHash: string): TGateVerdict;

    /// <summary>Stage + full verification WITHOUT install (docs/66 §16.5 steps 1-5:
    /// package hash / package signature / manifest hash / manifest signature).
    /// manifest 验签前置于下载（改法项 (4)：download_url 只信任已验签 manifest）。
    /// 配置同步等“下载+验证但不安装程序二进制”场景复用。</summary>
    function StageAndVerifyPackage(const Info: TUpdateInfo;
      out PackagePath: string; out ErrorMsg: string): TGateVerdict; overload;

{$IFNDEF RELEASE}
    /// <summary>Enable insecure dev mode: allows updates without hash/signature.
    /// NEVER enable in production builds. Use only for local development testing.
    /// RELEASE 编译期整体剔除（改法项 (2)）。</summary>
    property InsecureDevMode: Boolean read FInsecureDevMode write FInsecureDevMode;
{$ENDIF}

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

    /// <summary>Gate (A6): stage-verify a downloaded package against SHA256 and
    /// RSA-SHA256 signature. Declared signature without a public key is rejected.</summary>
    class function StageAndVerifyPackage(const AInfo: TUpdateInfo;
      const APackagePath: string; const APublicKeyPEM: string;
      out AErrMsg: string): TGateVerdict; overload;

    class function StageAndVerifyPackage(const AVersion, APackageHash, ASignature: string;
      const APackagePath: string; const APublicKeyPEM: string;
      out AErrMsg: string): TGateVerdict; overload;

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
    /// <summary>更新端点主机白名单（小写主机名）。未显式配置时回退为
    /// UpdateUrl 的 host；两者皆无 ⇒ 下载/检查请求一律拒绝（fail-closed）。</summary>
    property UpdateHostWhitelist: TArray<string> read FAllowedHosts write FAllowedHosts;
    property Status: TUpdateStatus read FStatus;
    property LastError: string read FLastError;
    property AutoCheck: Boolean read FAutoCheck write FAutoCheck;
    property AutoCheckInterval: Integer read FAutoCheckInterval write FAutoCheckInterval;
    property LastCheckTime: TDateTime read FLastCheckTime;
    property CurrentUpdate: TUpdateInfo read FCurrentUpdate;
    /// <summary>暂存/备份根目录。原为 %TEMP% 下写死的两个固定目录：同一台机器上
    /// 多宿主或并发更新会互相踩暂存，且「备份清单非空、条数可核对」这类判据无法离线测试
    /// （B2-08 判定要求）。可注入即把安装/回滚路径变成可隔离、可断言的真实路径。</summary>
    property TempDirectory: string read FTempDir write FTempDir;
    property BackupDirectory: string read FBackupDir write FBackupDir;
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

procedure AddHeader(var AHeaders: TNetHeaders; const AName, AValue: string);
begin
  if AValue = '' then
    Exit;
  SetLength(AHeaders, Length(AHeaders) + 1);
  AHeaders[High(AHeaders)] := TNameValuePair.Create(AName, AValue);
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
{$IFNDEF RELEASE}
  FInsecureDevMode := False;
{$ENDIF}
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
  Result.PackageHash := NormalizePackageHash(LPackageHash);
  Result.Signature := JSON.GetValue<string>('signature', '');
  // 不再读取 signatureAlgorithm：验签算法固定本地信任锚 rsa-sha256（改法项 (1)），
  // 远端自述一律不采信。
  Result.ManifestHash := JSON.GetValue<string>('manifestHash', '');
  if Result.ManifestHash = '' then
    Result.ManifestHash := JSON.GetValue<string>('manifest_hash', '');
  Result.ManifestSignature := JSON.GetValue<string>('manifestSignature', '');
  if Result.ManifestSignature = '' then
    Result.ManifestSignature := JSON.GetValue<string>('manifest_signature', '');
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
          Result.PackageHash := NormalizePackageHash(Result.Files[I].Hash);
      end;
    end;
  end;
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
  Verdict: TGateVerdict;
begin
  // 改法项 (4)：所有更新链 HTTP 出口统一过 https+主机白名单门禁（咽喉点）。
  Verdict := ValidateUpdateEndpointUrl(AUrl, EffectiveAllowedHosts);
  if not Verdict.IsApproved then
    raise Exception.Create('Update endpoint rejected: ' + Verdict.Reason);

  if FTransport = nil then
    FTransport := TDeepBaseSystemNetTransport.Create;

  Request := TDeepBaseHttpTransportRequest.Create(AMethod, AUrl);
  Request.Headers := AHeaders;
  Request.TimeoutMs := 30000;
  Request.FollowRedirects := True;
  Result := FTransport.Send(Request);
end;

procedure TUpdateManager.CheckForUpdates(Callback: TCheckUpdateCallback);
begin
  TThread.CreateAnonymousThread(
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
    end).Start;
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

function TUpdateManager.EffectiveAllowedHosts: TArray<string>;
begin
  if Length(FAllowedHosts) > 0 then
    Exit(FAllowedHosts);
  // 未显式配置白名单时回退到 UpdateUrl 的 host（信任锚 = 初始化时人工配置的服务器）；
  // 两者皆无 → 空数组 → ValidateUpdateEndpointUrl fail-closed 拒绝。
  if UrlHost(FUpdateUrl) <> '' then
    Result := [UrlHost(FUpdateUrl)]
  else
    Result := [];
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
var
  LHashVerdict: TGateVerdict;
begin
  PackagePath := TPath.Combine(FTempDir, Format('update_%s.zip', [Info.Version.ToString]));
  Result := DownloadFile(Info.DownloadUrl, PackagePath, FOnProgress);
  if not Result then
    Exit;
  SetStatus(usVerifying, 'Verifying download...');
  LHashVerdict := VerifyFileHash(PackagePath, Info.PackageHash);
  if not LHashVerdict.IsApproved then
  begin
    FLastError := 'Package hash verification failed: ' + LHashVerdict.Reason;
    Exit;
  end;
  Result := True;
end;

function TUpdateManager.StageAndVerifyPackage(const Info: TUpdateInfo;
  out PackagePath: string; out ErrorMsg: string): TGateVerdict;
var
  LVerdict: TGateVerdict;

  function Reject(const AReason: string): TGateVerdict;
  begin
    ErrorMsg := AReason;
    Result := TGateVerdict.Rejected(AReason);
  end;

begin
  PackagePath := '';
  ErrorMsg := '';
  Result := TGateVerdict.Rejected('');
  try
{$IFNDEF RELEASE}
    if FInsecureDevMode then
    begin
      // 开发豁免仅存在于非 RELEASE 编译；RELEASE 构建中此分支连代码都不存在。
      SetStatus(usDownloading, 'Downloading package...');
      if not StageUpdatePackage(Info, PackagePath) then
        Exit(Reject(FLastError));
      Exit(TGateVerdict.Approved('WARNING: verification skipped (insecure dev mode)'));
    end;
{$ENDIF}

    // 改法项 (4)：manifest 验签前置于下载——download_url 只有在 payload
    // （含 URL 字段）通过 RSA 验签后才可信。门禁唯一实现见 VerifyUpdateManifest。
    LVerdict := VerifyUpdateManifest(Info);
    if not LVerdict.IsApproved then
      Exit(Reject(LVerdict.Reason));

    SetStatus(usDownloading, 'Downloading package...');
    if not StageUpdatePackage(Info, PackagePath) then
      Exit(Reject(FLastError));

    LVerdict := VerifyUpdatePackageSignature(Info);
    if not LVerdict.IsApproved then
      Exit(Reject(LVerdict.Reason));

    Result := TGateVerdict.Approved;
  except
    on E: Exception do
      Result := Reject(E.Message);
  end;
  if not Result.IsApproved then
    SetStatus(usFailed, ErrorMsg);
end;

function TUpdateManager.VerifyUpdateManifest(const Info: TUpdateInfo): TGateVerdict;
var
  ManifestPayload, ComputedManifestHash, ExpectedManifestHash: string;
  LVerdict: TGateVerdict;
begin
  // 强制策略（改法项 (2)）：hash/签名/验签信任锚任一缺失即拒，无开关、无自述。
  if Info.PackageHash = '' then
    Exit(TGateVerdict.Rejected('Package hash is missing; update refused (fail-closed)'));
  if Info.Signature = '' then
    Exit(TGateVerdict.Rejected('Package signature is missing; update refused (fail-closed)'));
  if Info.ManifestSignature = '' then
    Exit(TGateVerdict.Rejected('Manifest signature is missing; update refused (fail-closed)'));
  if FPublicKey = '' then
    Exit(TGateVerdict.Rejected('RSA public key is not configured; update refused (fail-closed)'));

  // payload 唯一构造见 Contracts；ManifestHash 与 PackageHash 同形（可带 sha256: 前缀），
  // 归一化也统一走 NormalizePackageHash，不再手写前缀裁剪。
  SetStatus(usVerifying, 'Verifying manifest signature...');
  ManifestPayload := BuildManifestSignaturePayload(Info);
  ComputedManifestHash := LowerCase(THashSHA2.GetHashString(ManifestPayload));
  ExpectedManifestHash := NormalizePackageHash(Info.ManifestHash);
  if Trim(ExpectedManifestHash) = '' then
    Exit(TGateVerdict.Rejected('Manifest hash is missing; update refused (fail-closed)'));
  if not SameText(ExpectedManifestHash, ComputedManifestHash) then
    Exit(TGateVerdict.Rejected('Manifest hash verification failed'));
  // §16.10 Step 6: manifest_signature 签的是 payload 的 UTF-8 字节（非 hash）
  LVerdict := VerifySignature(ManifestPayload, Info.ManifestSignature);
  if not LVerdict.IsApproved then
    Exit(TGateVerdict.Rejected('Manifest signature verification failed: ' + LVerdict.Reason));

  Result := TGateVerdict.Approved;
end;

function TUpdateManager.VerifyUpdatePackageSignature(const Info: TUpdateInfo): TGateVerdict;
var
  LVerdict: TGateVerdict;
begin
  // 包签名：data = 归一化 PackageHash 的 UTF-8 字节（§16.10 关键点 1）
  LVerdict := VerifySignature(Info.PackageHash, Info.Signature);
  if not LVerdict.IsApproved then
    Exit(TGateVerdict.Rejected('Package signature verification failed: ' + LVerdict.Reason));
  Result := TGateVerdict.Approved;
end;

function TUpdateManager.InstallPackage(const Info: TUpdateInfo; const PackagePath: string): Boolean;
var
  FilesToBackup: TArray<string>;
  I: Integer;
begin
  // 清单未声明受影响文件 ⇒ 备份清单必然为空 ⇒ ApplyUpdate 覆盖后无现场可回滚。
  // 按 B2-08 fail-closed 口径拒装，而不是「备份 0 条然后照样覆盖」。
  if Length(Info.Files) = 0 then
  begin
    FLastError := 'Update manifest declares no files; install refused (fail-closed)';
    SetStatus(usFailed, FLastError);
    Exit(False);
  end;

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

function TUpdateManager.VerifySignature(const Data, Signature: string): TGateVerdict;
{$IFDEF MSWINDOWS}
var
  LVerifier: TRSAVerifier;
{$ENDIF}
{$IF DEFINED(MACOS) OR DEFINED(LINUX)}
var
  LDataBytes: TBytes;
  LError: string;
{$ENDIF}

  function Reject(const AReason: string): TGateVerdict;
  begin
    FLastError := AReason;
    Result := TGateVerdict.Rejected(AReason);
  end;

begin
  { 改法项 (1)：验签算法不接受远端自述——本函数只实现 rsa-sha256（本地固定
    信任锚）。旧 sha256"伪签名"与 hmac 共享密钥分支不是签名，全部删除。 }
  if Signature = '' then
    Exit(Reject('Signature is empty'));

  // 缺公钥必须 fail-closed；dev 旁路仅存在于非 RELEASE 编译（改法项 (2)）。
  if FPublicKey = '' then
  begin
{$IFNDEF RELEASE}
    if FInsecureDevMode then
    begin
      FLastError := 'WARNING: Signature verification skipped (insecure dev mode, no public key)';
      Exit(TGateVerdict.Approved(FLastError));
    end;
{$ENDIF}
    Exit(Reject('RSA public key is not configured. Cannot verify update signature.'));
  end;

  {$IFDEF MSWINDOWS}
  LVerifier := TRSAVerifier.Create;
  try
    if not LVerifier.LoadPublicKeyPEM(FPublicKey) then
      Exit(Reject('Failed to load public key: ' + LVerifier.LastError));

    if not LVerifier.VerifySignature(Data, Signature) then
      Exit(Reject('Signature verification failed: ' + LVerifier.LastError));
  finally
    LVerifier.Free;
  end;
  {$ELSE}
    {$IF DEFINED(MACOS) OR DEFINED(LINUX)}
    LDataBytes := TEncoding.UTF8.GetBytes(Data);
    if not OpenSSL_RSAVerifySHA256(FPublicKey, LDataBytes, Signature, LError) then
      Exit(Reject(LError));
    {$ELSE}
    Exit(Reject('Signature verification not implemented on this platform'));
    {$ENDIF}
  {$ENDIF}
  FLastError := '';
  Result := TGateVerdict.Approved;
end;

function TUpdateManager.VerifyFileHash(const FilePath, ExpectedHash: string): TGateVerdict;
var
  FileStream: TFileStream;
  ActualHash: string;

  function Reject(const AReason: string): TGateVerdict;
  begin
    FLastError := AReason;
    Result := TGateVerdict.Rejected(AReason);
  end;

begin
  if not FileExists(FilePath) then
    Exit(Reject('File not found for hash verification: ' + FilePath));

  // 缺 hash 必须 fail-closed；dev 旁路仅存在于非 RELEASE 编译（改法项 (2)）。
  if ExpectedHash = '' then
  begin
{$IFNDEF RELEASE}
    if FInsecureDevMode then
      Exit(TGateVerdict.Approved('WARNING: hash check skipped (insecure dev mode)'));
{$ENDIF}
    Exit(Reject('Package hash is missing. Cannot verify update integrity.'));
  end;

  FileStream := TFileStream.Create(FilePath, fmOpenRead or fmShareDenyWrite);
  try
    ActualHash := THashSHA2.GetHashString(FileStream, SHA256);
  finally
    FreeAndNil(FileStream);
  end;

  if not SameText(ActualHash, NormalizePackageHash(ExpectedHash)) then
    Exit(Reject('File hash mismatch: expected ' + ExpectedHash + ', got ' + ActualHash));
  FLastError := '';
  Result := TGateVerdict.Approved;
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
begin
  TThread.CreateAnonymousThread(
    procedure
    var
      PackagePath: string;
      InstallMode: TUpdateInstallMode;
      Success: Boolean;
      ErrorMsg: string;
      LV: TGateVerdict;
    begin
      Success := False;
      ErrorMsg := '';
      FCancelled := False;

      try
        // 路径 A 收敛到与路径 B 同一实现（改法项 (3)：U-02 双实现消缺点）：
        // StageAndVerifyPackage 内部完成 manifest 验签（前置于下载）、
        // 强制字段检查、下载+hash 校验与包签名校验，全部 fail-closed。
        LV := StageAndVerifyPackage(Info, PackagePath, ErrorMsg);
        if not LV.IsApproved then
        begin
          SetStatus(usFailed, ErrorMsg);
          Exit;
        end;

        if FCancelled then
        begin
          ErrorMsg := 'Cancelled by user';
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
    end).Start;
end;

procedure TUpdateManager.DownloadOnly(const Info: TUpdateInfo;
  OnComplete: TUpdateCompleteCallback);
begin
  TThread.CreateAnonymousThread(
    procedure
    var
      PackagePath: string;
      Success: Boolean;
      ErrorMsg: string;
      LV: TGateVerdict;
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
          LV := VerifyFileHash(PackagePath, Info.PackageHash);
          if LV.IsApproved then
          begin
            Success := True;
            SetStatus(usIdle, 'Download complete');
          end
          else
          begin
            ErrorMsg := 'Package hash verification failed: ' + LV.Reason;
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
    end).Start;
end;

function TUpdateManager.InstallDownloadedUpdate(const PackagePath: string): Boolean;
var
  LVerdict: TGateVerdict;

  function Fail(const AReason: string): Boolean;
  begin
    FLastError := AReason;
    SetStatus(usFailed, AReason);
    Result := False;
  end;

begin
  if not FileExists(PackagePath) then
    Exit(Fail('Update package not found'));

  // 就地安装的包不经下载通道，但信任锚一条都不能少：manifest 自洽+验签 → 包哈希 →
  // 包签名 → 带真实备份清单的安装，全部复用下载路径的同一组门禁。旧实现在这里是
  // CreateBackup('*.*') + ApplyUpdate，零校验直装，且 '*.*' 使备份恒空、回滚必然扑空。
  // InsecureDevMode 在此刻意不生效：本判据要关的正是这条旁路。
  LVerdict := VerifyUpdateManifest(FCurrentUpdate);
  if not LVerdict.IsApproved then
    Exit(Fail(LVerdict.Reason));

  LVerdict := VerifyFileHash(PackagePath, FCurrentUpdate.PackageHash);
  if not LVerdict.IsApproved then
    Exit(Fail('Package hash verification failed: ' + LVerdict.Reason));

  LVerdict := VerifyUpdatePackageSignature(FCurrentUpdate);
  if not LVerdict.IsApproved then
    Exit(Fail(LVerdict.Reason));

  Result := InstallPackage(FCurrentUpdate, PackagePath);
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

  TThread.CreateAnonymousThread(
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
    end).Start;
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

class function TUpdateManager.StageAndVerifyPackage(const AInfo: TUpdateInfo;
  const APackagePath: string; const APublicKeyPEM: string;
  out AErrMsg: string): TGateVerdict;
var
  LComputedHash: string;
  LVerifier: TRSAVerifier;

  function Reject(const AReason: string): TGateVerdict;
  begin
    AErrMsg := AReason;
    Result := TGateVerdict.Rejected(AReason);
  end;

begin
  AErrMsg := '';
  Result := TGateVerdict.Rejected('');

  // fail-closed：hash / 签名 / 公钥任一缺失 = 不可校验 = 拒绝（改法项 (2)）。
  // 旧实现是 "if provided" 可选检查，缺字段静默放行，正是 T1 家族立法对象。
  if not TFile.Exists(APackagePath) then
    Exit(Reject('Package file does not exist: ' + APackagePath));
  if Trim(AInfo.PackageHash) = '' then
    Exit(Reject('Package hash is missing; update refused (fail-closed)'));
  if Trim(AInfo.Signature) = '' then
    Exit(Reject('Package signature is missing; update refused (fail-closed)'));
  if Trim(APublicKeyPEM) = '' then
    Exit(Reject('No RSA public key configured; cannot verify package signature (fail-closed)'));

  // 1. SHA-256 of package file（比对前双侧归一化，防 "sha256:" 前缀/大小写分叉）
  LComputedHash := LowerCase(THashSHA2.GetHashStringFromFile(APackagePath));
  if not SameText(LComputedHash, NormalizePackageHash(AInfo.PackageHash)) then
    Exit(Reject(Format('Package hash mismatch: expected %s, got %s',
      [NormalizePackageHash(AInfo.PackageHash), LComputedHash])));

  // 2. RSA-SHA256 over utf8(package_hash_hex)（docs/66 §16.10 关键点 1）。
  //    旧实现对"文件原始字节"签名，与 §16.10 协议不符且与 AutoUpdate 通道
  //    构成第二套验签语义（U-02）；统一为对归一化 hash 串单层摘要验签。
  try
    LVerifier := TRSAVerifier.Create;
    try
      if not LVerifier.LoadPublicKeyPEM(APublicKeyPEM) then
        Exit(Reject('Failed to load RSA public key: ' + LVerifier.LastError));

      if not LVerifier.VerifySignature(NormalizePackageHash(AInfo.PackageHash), AInfo.Signature) then
        Exit(Reject('Package RSA-SHA256 signature verification failed: ' + LVerifier.LastError));
    finally
      LVerifier.Free;
    end;
  except
    on E: Exception do
      Exit(Reject('RSA verification exception: ' + E.Message));
  end;

  Result := TGateVerdict.Approved;
end;

class function TUpdateManager.StageAndVerifyPackage(const AVersion, APackageHash, ASignature: string;
  const APackagePath: string; const APublicKeyPEM: string;
  out AErrMsg: string): TGateVerdict;
var
  LInfo: TUpdateInfo;
begin
  LInfo := Default(TUpdateInfo);
  LInfo.Version := TSemanticVersion.Parse(AVersion);
  LInfo.PackageHash := NormalizePackageHash(APackageHash);
  LInfo.Signature := ASignature;
  Result := StageAndVerifyPackage(LInfo, APackagePath, APublicKeyPEM, AErrMsg);
end;

initialization
  FUpdaterLock := TCriticalSection.Create;

finalization
  if FUpdater <> nil then
    FreeAndNil(FUpdater);
  FreeAndNil(FUpdaterLock);

end.
