(* ============================================================================
  DeepBase.AutoUpdate - High-Level Auto-Update Helper
  
  Version: 0.4
  Description:
    Lightweight helper for application auto-update based on a static
    version.json file hosted on a web server or CDN.

    This module is intentionally simpler than DeepBase.Updater. It is
    designed for typical desktop apps that:
      - Host a JSON file (version.json) on a static site (e.g. OSS/CDN)
      - Each channel (stable/beta/dev) contains version info and download URL
      - Optionally mark releases as mandatory with SHA256 checksum

    Supports two version.json formats:
    
    1. New Standard Format (UniPublisher-Spec.md compliant):
      {
        "appId": "com.goodmem.app",
        "version": "1.2.0",
        "channel": "stable",
        "publishedAt": "2025-12-11T08:00:00Z",
        "files": [{ "name": "...", "url": "...", "size": ..., "sha256": "..." }],
        "releaseNotes": "...",
        "mandatory": false,
        "minVersion": "1.0.0"
      }
    
    2. Legacy Format (backward compatible):
      {
        "stable": {
          "version": "1.0.0",
          "versionCode": 1,
          "downloadUrl": "https://.../setup_1.0.0.exe",
          "fileSize": 12345678,
          "sha256": "...",
          "releaseNotes": "...",
          "releaseDate": "2025-12-01T10:00:00Z",
          "isMandatory": false,
          "minOsVersion": "10.0"
        },
        "beta": { ... },
        "dev":  { ... },
        "meta": { ... }
      }

    Version comparison:
      - Uses DeepBase.Updater.TSemanticVersion to compare CurrentVersion
        with remote version ("version" field).
      - If remote <= current, CheckForUpdate returns False.
  ============================================================================ *)

unit DeepBase.AutoUpdate;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Net.HttpClient,
  System.Net.URLClient,
  System.JSON,
  System.Hash,
  System.DateUtils,
  System.Threading,
  System.Generics.Collections,
  DeepBase.Updater,
  DeepBase.Commerce.Permissions,
  DeepBase.Crypto.RSA;

type
  /// <summary>
  /// Update channel used by AutoUpdate. Alias of DeepBase.Updater.TUpdateChannel.
  /// Only stable/beta/dev are used by version.json; alpha maps to dev.
  /// </summary>
  TUpdateChannel = DeepBase.Updater.TUpdateChannel;
  TUpdateInstallMode = DeepBase.Updater.TUpdateInstallMode;

  /// <summary>
  /// Simplified update information parsed from version.json.
  /// </summary>
  TUpdateInfo = record
    Version: string;            // e.g. "1.2.3"
    Channel: TUpdateChannel;    // stable/beta/dev
    DownloadUrl: string;        // direct URL to installer/package
    DownloadSize: Int64;        // bytes (may be 0 if unknown)
    Sha256: string;             // optional SHA256 hex string
    Signature: string;          // REVIEW5-FEAT-003: optional digital signature (base64/PEM)
    ReleaseDate: TDateTime;     // parsed from ISO8601, or Now if missing
    Changelog: string;          // releaseNotes
    ForceUpdate: Boolean;       // isMandatory
    InstallMode: TUpdateInstallMode;
    AllowSilentInstall: Boolean;
    BackgroundDownload: Boolean;
    IdleWindowMinutes: Integer;
    ForceRestart: Boolean;
  end;

  /// <summary>Callback used after asynchronous update check.</summary>
  TUpdateCheckCallback = reference to procedure(Success: Boolean; const Info: TUpdateInfo);

  /// <summary>Progress callback used during download.</summary>
  TUpdateProgressCallback = reference to procedure(const ReadBytes, TotalBytes: Int64);

  /// <summary>Callback invoked when a TLS certificate is rejected during update checks.</summary>
  TOnValidateCertificateEvent = reference to procedure(const AHost: string; const AReason: string);

  /// <summary>
  /// High-level auto-update helper for static version.json based flow.
  /// TLS pinning: callers can assign OnValidateCert to a THTTPClient's
  /// OnValidateServerCertificate event (requires an instance-method wrapper
  /// since class methods cannot satisfy "of object" event types).
  /// </summary>
  TDeepBaseAutoUpdate = class
  private
    FUpdateUrl: string;
    FChannel: TUpdateChannel;
    FCurrentVersion: string;
    FPermissionClient: TDeepKitPermissionClient;
    FLastError: string;
    FOnCertRejected: TOnValidateCertificateEvent;
    FConnectionTimeout: Integer;  // REVIEW5-FEAT-003: HTTP connection timeout (ms)
    FResponseTimeout: Integer;    // REVIEW5-FEAT-003: HTTP response timeout (ms)
    FPublicKeyRSA: string;        // PEM RSA public key (PKCS#1 v1.5, RSA-SHA256 production)

    function GetChannel: TUpdateChannel;
    procedure SetChannel(const Value: TUpdateChannel);
    function GetCurrentVersion: string;
    procedure SetCurrentVersion(const Value: string);

    function ChannelKey(Channel: TUpdateChannel): string;
    function NormalizeVersion(const S: string): string;
    function IsNewFormatJson(ARoot: TJSONObject): Boolean;
    procedure ResetUpdateInfo(out Info: TUpdateInfo; Channel: TUpdateChannel);
    procedure ParseInstallPolicy(Source: TJSONObject; var Info: TUpdateInfo);
    function CreateHttpClient: THTTPClient;

    function CheckForUpdateFromJson(out Info: TUpdateInfo): Boolean;
    function CheckForUpdateFromNewFormat(ARoot: TJSONObject; out Info: TUpdateInfo): Boolean;
    function CheckForUpdateFromLegacyFormat(ARoot: TJSONObject; out Info: TUpdateInfo): Boolean;
    function CheckForUpdateFromGitHub(const RepoSlug: string; out Info: TUpdateInfo): Boolean;
    function CheckForUpdateFromGitee(const RepoSlug: string; out Info: TUpdateInfo): Boolean;
  public
    constructor Create(const AUpdateUrl: string = ''; const ACurrentVersion: string = '');

    /// <summary>Base URL of version.json file (full URL including file name).</summary>
    property UpdateUrl: string read FUpdateUrl write FUpdateUrl;

    /// <summary>Update channel (stable/beta/dev). Default is ucStable.</summary>
    property Channel: TUpdateChannel read GetChannel write SetChannel;

    /// <summary>
    /// Current application version used for comparison.
    /// If empty, defaults to '0.0.0' (any remote version is considered newer).
    /// </summary>
    property CurrentVersion: string read GetCurrentVersion write SetCurrentVersion;

    /// <summary>
    /// Check for updates synchronously.
    /// Returns True and fills Info when a newer version is available on the
    /// configured channel; otherwise returns False.
    /// </summary>
    function CheckForUpdate(out Info: TUpdateInfo): Boolean;

    /// <summary>
    /// Check for updates asynchronously. The returned task is created but not
    /// started; caller should call .Start.
    /// </summary>
    function CheckForUpdateAsync(const Callback: TUpdateCheckCallback): ITask;

    /// <summary>
    /// Download update package to DestFile and optionally verify SHA256.
    /// OnProgress is called with (ReadBytes, TotalBytes). For simplicity the
    /// current implementation only reports 0 and TotalBytes upon completion,
    /// which is sufficient for a basic progress bar.
    /// </summary>
    function DownloadUpdate(const Info: TUpdateInfo; const DestFile: string;
      const OnProgress: TUpdateProgressCallback = nil): Boolean;

    /// <summary>
    /// Optional permission client for gating update downloads.
    /// When set, DownloadUpdate requires 'updates' feature entitlement.
    /// When nil, no permission check is performed (default).
    /// </summary>
    property PermissionClient: TDeepKitPermissionClient
      read FPermissionClient write FPermissionClient;

    /// <summary>Last error message (set when CheckForUpdate or DownloadUpdate fails).</summary>
    property LastError: string read FLastError;

    /// <summary>
    /// Optional callback invoked whenever a TLS certificate is rejected during
    /// an update check or download.  Useful for logging / diagnostics.
    /// TLS pinning should be applied by callers: assign an instance-method
    /// wrapper to THTTPClient.OnValidateServerCertificate that checks
    /// Certificate.Fingerprint against a set of pinned values.
    /// </summary>
    property OnCertRejected: TOnValidateCertificateEvent
      read FOnCertRejected write FOnCertRejected;

    /// <summary>
    /// REVIEW5-FEAT-003: HTTP connection timeout in milliseconds.
    /// Default: 30000 (30 seconds). Prevents indefinite hangs on slow servers.
    /// </summary>
    property ConnectionTimeout: Integer read FConnectionTimeout write FConnectionTimeout;

    /// <summary>
    /// REVIEW5-FEAT-003: HTTP response timeout in milliseconds.
    /// Default: 60000 (60 seconds). Prevents indefinite hangs during download.
    /// </summary>
    property ResponseTimeout: Integer read FResponseTimeout write FResponseTimeout;

    /// <summary>
    /// PEM-encoded RSA public key (PKCS#1 v1.5, RSA-SHA256) used for production
    /// signature verification per 78a ADR r1 §2.7 (Windows CNG).
    /// Default loaded from DEEPKIT_UPDATE_PUBLIC_KEY_RSA_PEM or UPDATE_PUBLIC_KEY_RSA_PEM env vars.
    /// When set, DownloadUpdate verifies the package signature with RSA-SHA256.
    /// </summary>
    property PublicKeyRSA: string read FPublicKeyRSA write FPublicKeyRSA;
  end;

implementation

{ TDeepBaseAutoUpdate }

constructor TDeepBaseAutoUpdate.Create(const AUpdateUrl, ACurrentVersion: string);
begin
  inherited Create;
  FUpdateUrl := AUpdateUrl;
  FCurrentVersion := ACurrentVersion;
  FChannel := TUpdateChannel.ucStable;
  // REVIEW5-FEAT-003: Default HTTP timeouts to prevent indefinite hangs
  FConnectionTimeout := 30000; // 30 seconds
  FResponseTimeout := 60000;   // 60 seconds
  // Production signature protocol per 78a ADR r1 §2.7: RSA-SHA256 (PKCS#1 v1.5, CNG).
  FPublicKeyRSA := GetEnvironmentVariable('DEEPKIT_UPDATE_PUBLIC_KEY_RSA_PEM');
  if FPublicKeyRSA = '' then
    FPublicKeyRSA := GetEnvironmentVariable('UPDATE_PUBLIC_KEY_RSA_PEM');
end;

function TDeepBaseAutoUpdate.GetChannel: TUpdateChannel;
begin
  Result := FChannel;
end;

procedure TDeepBaseAutoUpdate.SetChannel(const Value: TUpdateChannel);
begin
  FChannel := Value;
end;

function TDeepBaseAutoUpdate.GetCurrentVersion: string;
begin
  if FCurrentVersion = '' then
    Result := '0.0.0'
  else
    Result := FCurrentVersion;
end;

procedure TDeepBaseAutoUpdate.SetCurrentVersion(const Value: string);
begin
  FCurrentVersion := Trim(Value);
end;

function TDeepBaseAutoUpdate.ChannelKey(Channel: TUpdateChannel): string;
begin
  // Map to keys used in version.json
  case Channel of
    ucStable: Result := 'stable';
    ucBeta:   Result := 'beta';
    ucAlpha,
    ucDev:    Result := 'dev';
  else
    Result := 'stable';
  end;
end;

function TDeepBaseAutoUpdate.NormalizeVersion(const S: string): string;
begin
  Result := Trim(S);
  if (Result <> '') and ((Result[Low(Result)] = 'v') or (Result[Low(Result)] = 'V')) then
    Delete(Result, Low(Result), 1);
end;

function TDeepBaseAutoUpdate.IsNewFormatJson(ARoot: TJSONObject): Boolean;
begin
  if ARoot = nil then
    Exit(False);

  // UniPublisher standard format has appId/version/channel/files at root.
  Result := (ARoot.GetValue('files') <> nil) or
    ((ARoot.GetValue('appId') <> nil) and (ARoot.GetValue('version') <> nil));
end;

procedure TDeepBaseAutoUpdate.ResetUpdateInfo(out Info: TUpdateInfo;
  Channel: TUpdateChannel);
begin
  Info.Version := '';
  Info.Channel := Channel;
  Info.DownloadUrl := '';
  Info.DownloadSize := 0;
  Info.Sha256 := '';
  Info.Signature := '';
  Info.ReleaseDate := 0;
  Info.Changelog := '';
  Info.ForceUpdate := False;
  Info.InstallMode := uimUnspecified;
  Info.AllowSilentInstall := False;
  Info.BackgroundDownload := True;
  Info.IdleWindowMinutes := 0;
  Info.ForceRestart := False;
end;

procedure TDeepBaseAutoUpdate.ParseInstallPolicy(Source: TJSONObject;
  var Info: TUpdateInfo);
var
  PolicyObj: TJSONObject;
  ModeStr: string;
begin
  if Source = nil then
    Exit;

  PolicyObj := Source.GetValue<TJSONObject>('installPolicy', nil);
  if PolicyObj = nil then
    PolicyObj := Source.GetValue<TJSONObject>('install_policy', nil);

  if PolicyObj <> nil then
  begin
    ModeStr := PolicyObj.GetValue<string>('mode', '');
    if ModeStr = '' then
      ModeStr := PolicyObj.GetValue<string>('installMode', '');
    if ModeStr = '' then
      ModeStr := PolicyObj.GetValue<string>('install_mode', '');
    if ModeStr <> '' then
      Info.InstallMode := ParseInstallMode(ModeStr);

    Info.AllowSilentInstall := PolicyObj.GetValue<Boolean>('allowSilent',
      PolicyObj.GetValue<Boolean>('allow_silent', Info.AllowSilentInstall));
    Info.BackgroundDownload := PolicyObj.GetValue<Boolean>('backgroundDownload',
      PolicyObj.GetValue<Boolean>('background_download', Info.BackgroundDownload));
    Info.IdleWindowMinutes := PolicyObj.GetValue<Integer>('idleWindowMinutes',
      PolicyObj.GetValue<Integer>('idle_window_minutes', Info.IdleWindowMinutes));
    Info.ForceRestart := PolicyObj.GetValue<Boolean>('forceRestart',
      PolicyObj.GetValue<Boolean>('force_restart', Info.ForceRestart));
  end;

  if Info.InstallMode = uimUnspecified then
  begin
    ModeStr := Source.GetValue<string>('installMode', '');
    if ModeStr = '' then
      ModeStr := Source.GetValue<string>('install_mode', '');
    if ModeStr <> '' then
      Info.InstallMode := ParseInstallMode(ModeStr);
  end;

  Info.AllowSilentInstall := Source.GetValue<Boolean>('allowSilent',
    Source.GetValue<Boolean>('allow_silent', Info.AllowSilentInstall));
  Info.BackgroundDownload := Source.GetValue<Boolean>('backgroundDownload',
    Source.GetValue<Boolean>('background_download', Info.BackgroundDownload));
  Info.IdleWindowMinutes := Source.GetValue<Integer>('idleWindowMinutes',
    Source.GetValue<Integer>('idle_window_minutes', Info.IdleWindowMinutes));
  Info.ForceRestart := Source.GetValue<Boolean>('forceRestart',
    Source.GetValue<Boolean>('force_restart', Info.ForceRestart));
end;

function TDeepBaseAutoUpdate.CheckForUpdateFromNewFormat(
  ARoot: TJSONObject; out Info: TUpdateInfo): Boolean;
var
  VerStr, DateStr, ChannelStr: string;
  CurVer, RemoteVer: TSemanticVersion;
  FilesArr: TJSONArray;
  FileObj: TJSONObject;
begin
  Result := False;

  if ARoot = nil then
    Exit;

  VerStr := ARoot.GetValue<string>('version', '');
  if VerStr = '' then
    Exit;

  CurVer := TSemanticVersion.Parse(NormalizeVersion(GetCurrentVersion));
  RemoteVer := TSemanticVersion.Parse(NormalizeVersion(VerStr));
  if not RemoteVer.IsNewerThan(CurVer) then
    Exit;

  ChannelStr := ARoot.GetValue<string>('channel', '');
  if ChannelStr <> '' then
  begin
    Info.Channel := ParseChannel(ChannelStr);
    if not SameText(ChannelKey(Info.Channel), ChannelKey(FChannel)) then
      Exit;
  end
  else
    Info.Channel := FChannel;

  Info.Version := VerStr;
  Info.DownloadUrl := '';
  Info.DownloadSize := 0;
  Info.Sha256 := '';
  Info.Signature := '';
  Info.Changelog := ARoot.GetValue<string>('releaseNotes', '');
  Info.ForceUpdate := ARoot.GetValue<Boolean>('mandatory', False);
  Info.ForceRestart := Info.ForceUpdate;

  DateStr := ARoot.GetValue<string>('publishedAt', '');
  if DateStr = '' then
    DateStr := ARoot.GetValue<string>('releaseDate', '');
  if DateStr = '' then
    DateStr := ARoot.GetValue<string>('release_date', '');

  if DateStr <> '' then
  try
    Info.ReleaseDate := ISO8601ToDate(DateStr, False);
  except
    Info.ReleaseDate := Now;
  end
  else
    Info.ReleaseDate := Now;

  FilesArr := ARoot.GetValue<TJSONArray>('files', nil);
  if (FilesArr <> nil) and (FilesArr.Count > 0) and
    (FilesArr.Items[0] is TJSONObject) then
  begin
    FileObj := FilesArr.Items[0] as TJSONObject;
    Info.DownloadUrl := FileObj.GetValue<string>('url', '');
    if Info.DownloadUrl = '' then
      Info.DownloadUrl := FileObj.GetValue<string>('downloadUrl', '');
    Info.DownloadSize := FileObj.GetValue<Int64>('size', 0);
    Info.Sha256 := FileObj.GetValue<string>('sha256', '');
    Info.Signature := FileObj.GetValue<string>('signature', '');
  end;

  ParseInstallPolicy(ARoot, Info);

  Result := Info.DownloadUrl <> '';
end;

function TDeepBaseAutoUpdate.CheckForUpdateFromLegacyFormat(
  ARoot: TJSONObject; out Info: TUpdateInfo): Boolean;
var
  Source: TJSONObject;
  VerStr, DateStr, HashStr: string;
  CurVer, RemoteVer: TSemanticVersion;
begin
  Result := False;

  if ARoot = nil then
    Exit;

  Source := ARoot.GetValue<TJSONObject>(ChannelKey(FChannel), nil);
  if Source = nil then
  begin
    if ARoot.GetValue('version') = nil then
      Exit;
    Source := ARoot;
  end;

  VerStr := Source.GetValue<string>('version', '');
  if VerStr = '' then
    Exit;

  CurVer := TSemanticVersion.Parse(NormalizeVersion(GetCurrentVersion));
  RemoteVer := TSemanticVersion.Parse(NormalizeVersion(VerStr));
  if not RemoteVer.IsNewerThan(CurVer) then
    Exit;

  Info.Version := VerStr;
  Info.Channel := FChannel;
  Info.DownloadUrl := Source.GetValue<string>('downloadUrl', '');
  if Info.DownloadUrl = '' then
    Info.DownloadUrl := Source.GetValue<string>('download_url', '');
  if Info.DownloadUrl = '' then
    Info.DownloadUrl := Source.GetValue<string>('url', '');

  Info.DownloadSize := Source.GetValue<Int64>('fileSize', 0);
  if Info.DownloadSize = 0 then
    Info.DownloadSize := Source.GetValue<Int64>('downloadSize', 0);
  if Info.DownloadSize = 0 then
    Info.DownloadSize := Source.GetValue<Int64>('download_size', 0);
  if Info.DownloadSize = 0 then
    Info.DownloadSize := Source.GetValue<Int64>('size', 0);

  HashStr := Source.GetValue<string>('sha256', '');
  if HashStr = '' then
    HashStr := Source.GetValue<string>('packageHash', '');
  if HashStr = '' then
    HashStr := Source.GetValue<string>('package_hash', '');
  if SameText(Copy(HashStr, 1, 7), 'sha256:') then
    Delete(HashStr, 1, 7);
  Info.Sha256 := HashStr;

  Info.Signature := Source.GetValue<string>('signature', '');

  Info.Changelog := Source.GetValue<string>('releaseNotes', '');
  if Info.Changelog = '' then
    Info.Changelog := Source.GetValue<string>('release_notes', '');
  if Info.Changelog = '' then
    Info.Changelog := Source.GetValue<string>('changelog', '');

  Info.ForceUpdate := Source.GetValue<Boolean>('isMandatory', False);
  if not Info.ForceUpdate then
    Info.ForceUpdate := Source.GetValue<Boolean>('mandatory', False);
  Info.ForceRestart := Info.ForceUpdate;

  DateStr := Source.GetValue<string>('releaseDate', '');
  if DateStr = '' then
    DateStr := Source.GetValue<string>('release_date', '');
  if DateStr = '' then
    DateStr := Source.GetValue<string>('publishedAt', '');

  if DateStr <> '' then
  try
    Info.ReleaseDate := ISO8601ToDate(DateStr, False);
  except
    Info.ReleaseDate := Now;
  end
  else
    Info.ReleaseDate := Now;

  ParseInstallPolicy(Source, Info);
  if Info.InstallMode = uimUnspecified then
    ParseInstallPolicy(ARoot, Info);

  Result := Info.DownloadUrl <> '';
end;

function TDeepBaseAutoUpdate.CreateHttpClient: THTTPClient;
var
  UA: string;
begin
  Result := THTTPClient.Create;
  try
    if FCurrentVersion <> '' then
      UA := Format('DeepBase/%s', [FCurrentVersion])
    else
      UA := 'DeepBase';
    Result.UserAgent := UA;

    // REVIEW5-FEAT-003: Apply configured HTTP timeouts
    Result.ConnectionTimeout := FConnectionTimeout;
    Result.ResponseTimeout := FResponseTimeout;
  except
    Result.Free;
    raise;
  end;
end;

function TDeepBaseAutoUpdate.CheckForUpdateFromJson(out Info: TUpdateInfo): Boolean;
var
  Client: THTTPClient;
  Response: IHTTPResponse;
  Root: TJSONObject;
begin
  Result := False;
  ResetUpdateInfo(Info, FChannel);

  Client := CreateHttpClient;
  try
    Response := Client.Get(FUpdateUrl);
    if Response.StatusCode <> 200 then
      Exit;

    Root := TJSONObject.ParseJSONValue(Response.ContentAsString) as TJSONObject;
    try
      if Root = nil then
        Exit;

      // Auto-detect format and parse accordingly
      if IsNewFormatJson(Root) then
        Result := CheckForUpdateFromNewFormat(Root, Info)
      else
        Result := CheckForUpdateFromLegacyFormat(Root, Info);
    finally
      Root.Free;
    end;
  finally
    Client.Free;
  end;
end;

function TDeepBaseAutoUpdate.CheckForUpdateFromGitHub(
  const RepoSlug: string; out Info: TUpdateInfo): Boolean;
var
  Client: THTTPClient;
  Response: IHTTPResponse;
  Url: string;
  Root, Asset: TJSONObject;
  AssetsArr: TJSONArray;
  VerStr: string;
  CurVer, RemoteVer: TSemanticVersion;
begin
  Result := False;
  ResetUpdateInfo(Info, FChannel);

  if RepoSlug = '' then
    Exit;

  Client := CreateHttpClient;
  try
    // GitHub API: GET /repos/{owner}/{repo}/releases/latest
    Url := Format('https://api.github.com/repos/%s/releases/latest', [RepoSlug]);
    Response := Client.Get(Url);
    if Response.StatusCode <> 200 then
      Exit;

    Root := TJSONObject.ParseJSONValue(Response.ContentAsString) as TJSONObject;
    try
      if Root = nil then
        Exit;

      VerStr := Root.GetValue<string>('tag_name', '');
      if VerStr = '' then
        VerStr := Root.GetValue<string>('name', '');
      if VerStr = '' then
        Exit;

      CurVer := TSemanticVersion.Parse(NormalizeVersion(GetCurrentVersion));
      RemoteVer := TSemanticVersion.Parse(NormalizeVersion(VerStr));
      if not RemoteVer.IsNewerThan(CurVer) then
        Exit;

      Info.Version := VerStr;
      Info.Channel := FChannel;
      Info.Changelog := Root.GetValue<string>('body', '');
      Info.ForceUpdate := False;
      Info.ForceRestart := False;

      AssetsArr := Root.GetValue<TJSONArray>('assets');
      if (AssetsArr <> nil) and (AssetsArr.Count > 0) then
      begin
        Asset := AssetsArr.Items[0] as TJSONObject;
        Info.DownloadUrl := Asset.GetValue<string>('browser_download_url', '');
        if Info.DownloadUrl = '' then
          Info.DownloadUrl := Asset.GetValue<string>('url', '');
        Info.DownloadSize := Asset.GetValue<Int64>('size', 0);
      end;

      Info.ReleaseDate := Now;
      Result := (Info.DownloadUrl <> '');
    finally
      Root.Free;
    end;
  finally
    Client.Free;
  end;
end;

function TDeepBaseAutoUpdate.CheckForUpdateFromGitee(
  const RepoSlug: string; out Info: TUpdateInfo): Boolean;
var
  Client: THTTPClient;
  Response: IHTTPResponse;
  Url: string;
  Root, Asset: TJSONObject;
  AssetsArr: TJSONArray;
  VerStr: string;
  CurVer, RemoteVer: TSemanticVersion;
begin
  Result := False;
  ResetUpdateInfo(Info, FChannel);

  if RepoSlug = '' then
    Exit;

  Client := CreateHttpClient;
  try
    // Gitee API: GET /v5/repos/{owner}/{repo}/releases/latest
    Url := Format('https://gitee.com/api/v5/repos/%s/releases/latest', [RepoSlug]);
    Response := Client.Get(Url);
    if Response.StatusCode <> 200 then
      Exit;

    Root := TJSONObject.ParseJSONValue(Response.ContentAsString) as TJSONObject;
    try
      if Root = nil then
        Exit;

      VerStr := Root.GetValue<string>('tag_name', '');
      if VerStr = '' then
        VerStr := Root.GetValue<string>('name', '');
      if VerStr = '' then
        Exit;

      CurVer := TSemanticVersion.Parse(NormalizeVersion(GetCurrentVersion));
      RemoteVer := TSemanticVersion.Parse(NormalizeVersion(VerStr));
      if not RemoteVer.IsNewerThan(CurVer) then
        Exit;

      Info.Version := VerStr;
      Info.Channel := FChannel;
      Info.Changelog := Root.GetValue<string>('body', '');
      Info.ForceUpdate := False;
      Info.ForceRestart := False;

      // Gitee JSON structure is similar to GitHub/GitCode; try common asset fields.
      AssetsArr := Root.GetValue<TJSONArray>('assets');
      if (AssetsArr <> nil) and (AssetsArr.Count > 0) then
      begin
        Asset := AssetsArr.Items[0] as TJSONObject;
        Info.DownloadUrl := Asset.GetValue<string>('browser_download_url', '');
        if Info.DownloadUrl = '' then
          Info.DownloadUrl := Asset.GetValue<string>('download_url', '');
        if Info.DownloadUrl = '' then
          Info.DownloadUrl := Asset.GetValue<string>('url', '');
        Info.DownloadSize := Asset.GetValue<Int64>('size', 0);
      end;

      Info.ReleaseDate := Now;
      Result := (Info.DownloadUrl <> '');
    finally
      Root.Free;
    end;
  finally
    Client.Free;
  end;
end;

function TDeepBaseAutoUpdate.CheckForUpdate(out Info: TUpdateInfo): Boolean;
var
  Prefix, Slug: string;
begin
  Result := False;

  if FUpdateUrl = '' then
    Exit;

  // github:owner/repo
  Prefix := 'github:';
  if SameText(Copy(FUpdateUrl, 1, Length(Prefix)), Prefix) then
  begin
    Slug := Copy(FUpdateUrl, Length(Prefix) + 1, MaxInt);
    Exit(CheckForUpdateFromGitHub(Slug, Info));
  end;

  // gitee:owner/repo
  Prefix := 'gitee:';
  if SameText(Copy(FUpdateUrl, 1, Length(Prefix)), Prefix) then
  begin
    Slug := Copy(FUpdateUrl, Length(Prefix) + 1, MaxInt);
    Exit(CheckForUpdateFromGitee(Slug, Info));
  end;

  // Default: treat as direct URL to version.json
  Result := CheckForUpdateFromJson(Info);
end;

function TDeepBaseAutoUpdate.CheckForUpdateAsync(
  const Callback: TUpdateCheckCallback): ITask;
var
  LTaskProc: TProc;
begin
  LTaskProc :=
    procedure
    var
      LInfo: TUpdateInfo;
      LSuccess: Boolean;
      LQ: TThreadProcedure;
    begin
      LSuccess := CheckForUpdate(LInfo);
      LQ := procedure
            begin
              if Assigned(Callback) then
                Callback(LSuccess, LInfo);
            end;
      TThread.ForceQueue(nil, LQ);
    end;
  Result := TTask.Create(LTaskProc);
end;

function TDeepBaseAutoUpdate.DownloadUpdate(const Info: TUpdateInfo; const DestFile: string;
  const OnProgress: TUpdateProgressCallback): Boolean;
var
  Client: THTTPClient;
  Response: IHTTPResponse;
  FS: TFileStream;
  Hash: string;
  PermCheck: TDeepKitPermissionResult;
begin
  Result := False;
  FLastError := '';

  if FPermissionClient <> nil then
  begin
    PermCheck := FPermissionClient.HasFeature('updates');
    if not PermCheck.Allowed then
    begin
      FLastError := 'Update download denied: ' + PermCheck.Reason;
      Exit;
    end;
  end;

  if Info.DownloadUrl = '' then
    Exit;

  // REVIEW5-FEAT-003: Fail-closed integrity requirement.
  // Production downloads must provide at least one integrity mechanism
  // (SHA256 hash or digital signature). Without any, tampered packages
  // cannot be detected.
  if (Info.Sha256 = '') and (Info.Signature = '') then
  begin
    FLastError := 'Download rejected: update package must provide SHA256 hash or digital signature for integrity verification';
    Exit;
  end;

  if Assigned(OnProgress) then
    OnProgress(0, Info.DownloadSize);

  Client := CreateHttpClient;
  try
    try
      Response := Client.Get(Info.DownloadUrl);
    except
      // REVIEW5-FEAT-003: network/transient failures (DNS, connection refused,
      // timeout 12002, etc.) must NOT propagate as unhandled exceptions. The
      // integrity gate contract is "download may fail for network reasons, but
      // never due to integrity rejection" — surface the failure via LastError
      // and return False so callers can distinguish the two paths.
      on E: Exception do
      begin
        FLastError := 'Download failed: ' + E.Message;
        Exit;
      end;
    end;
    if Response.StatusCode <> 200 then
      Exit;

    ForceDirectories(ExtractFilePath(DestFile));
    FS := TFileStream.Create(DestFile, fmCreate);
    try
      FS.CopyFrom(Response.ContentStream, 0);
    finally
      FreeAndNil(FS);
    end;
  finally
    Client.Free;
  end;

  // Verify SHA256 if provided
  if Info.Sha256 <> '' then
  begin
    FS := TFileStream.Create(DestFile, fmOpenRead or fmShareDenyWrite);
    try
      Hash := THashSHA2.GetHashString(FS, SHA256);
    finally
      FreeAndNil(FS);
    end;

    if not SameText(Hash, Info.Sha256) then
      Exit;
  end;

  // Verify package signature.
  // Production protocol per 78a ADR r1 §2.7: RSA-SHA256 (PKCS#1 v1.5, Windows CNG).
  // RSA path is authoritative; fail-closed when a signature is present but no
  // production RSA public key is configured.
  if Info.Signature <> '' then
  begin
    if Trim(FPublicKeyRSA) = '' then
    begin
      FLastError := 'Signature verification rejected: no RSA public key configured (RSA-SHA256 production)';
      if FileExists(DestFile) then
        DeleteFile(DestFile);
      Exit;
    end;

    var DigestBytes: TBytes;
    FS := TFileStream.Create(DestFile, fmOpenRead or fmShareDenyWrite);
    try
      var H := THashSHA2.Create(THashSHA2.TSHA2Version.SHA256);
      var Buf: array[0..65535] of Byte;
      var ReadCount: Integer;
      while True do
      begin
        ReadCount := FS.Read(Buf[0], Length(Buf));
        if ReadCount <= 0 then Break;
        H.Update(Buf[0], ReadCount);
      end;
      DigestBytes := H.HashAsBytes;
    finally
      FreeAndNil(FS);
    end;

    var Verifier: TRSAVerifier;
    Verifier := TRSAVerifier.Create;
    try
      if not Verifier.LoadPublicKeyPEM(FPublicKeyRSA) then
      begin
        FLastError := 'Failed to load RSA public key: ' + Verifier.LastError;
        if FileExists(DestFile) then
          DeleteFile(DestFile);
        Exit;
      end;

      if not Verifier.VerifySignature(DigestBytes, Info.Signature) then
      begin
        FLastError := 'Signature verification failed (RSA-SHA256): package has been tampered with or signature is invalid';
        if FileExists(DestFile) then
          DeleteFile(DestFile);
        Exit;
      end;
    finally
      FreeAndNil(Verifier);
    end;
  end;

  if Assigned(OnProgress) then
    OnProgress(Info.DownloadSize, Info.DownloadSize);

  Result := True;
end;

end.
