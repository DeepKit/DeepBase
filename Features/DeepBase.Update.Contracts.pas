{ ============================================================================
  DeepBase.Update.Contracts - 更新链契约单一真相源（SSOT）

  法源：WO-20260920-AUDIT-甲-R5 M1（Top20#01 更新验签链，RCE 级）改法项 (3)(4)(7)。

  职责边界：
  - 只放"契约"：版本/通道/安装策略/更新信息记录、manifest 签名 payload 的
    唯一构造函数（docs/66 §16.10 7 字段协议）、包 hash 归一化、端点 URL 门禁。
  - 不放 HTTP/下载/安装等运行时行为——那些留在 DeepBase.Updater /
    DeepBase.AutoUpdate 两条更新通道各自的编排层。
  - TUpdateInfo 是全仓唯一更新信息记录（AU-06 SSOT 分裂消解点）：
    DeepBase.Updater 与 DeepBase.AutoUpdate 均以类型别名转接本单元。
    算法自述字段（signatureAlgorithm / signature_required）不属于契约：
    验签算法固定 RSA-SHA256，远端自述一律不采信（改法项 (1)），
    强制策略（hash/签名缺失即拒）固定在门禁侧（改法项 (2)）。
  ============================================================================ }

unit DeepBase.Update.Contracts;

interface

uses
  System.SysUtils,
  System.Net.URLClient,
  DeepBase.Gate.Verdict;

type
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

  /// <summary>Update channel</summary>
  TUpdateChannel = (ucStable, ucBeta, ucAlpha, ucDev);

  /// <summary>Update type</summary>
  TUpdateType = (utFull, utIncremental, utPatch);

  /// <summary>
  /// Update install mode.
  /// interactive/immediate: install in current flow.
  /// onExit/whenIdle: download and stage first, install later in safe window.
  /// </summary>
  TUpdateInstallMode = (uimUnspecified, uimInteractive, uimImmediate, uimOnExit, uimWhenIdle);

  /// <summary>Install policy carried by update metadata.</summary>
  TUpdateInstallPolicy = record
    Mode: TUpdateInstallMode;
    AllowSilent: Boolean;
    BackgroundDownload: Boolean;
    IdleWindowMinutes: Integer;
    ForceRestart: Boolean;
  end;

  /// <summary>Update file information</summary>
  TUpdateFile = record
    FileName: string;
    RelativePath: string;
    Size: Int64;
    Hash: string;        // SHA256 hash（归一化后为纯 hex 小写）
    Action: string;      // 'add', 'update', 'delete'
  end;

  /// <summary>
  /// 全仓唯一更新信息记录。PackageHash/ManifestHash 存储语义：
  /// 去 "sha256:" 前缀、小写的纯 hex（NormalizePackageHash 归一，§16.10 关键点 2）。
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
    PackageHash: string;       // SHA256 of package（纯 hex 小写）
    Signature: string;         // RSA-SHA256 签名（base64），data=utf8(PackageHash)
    ManifestHash: string;
    ManifestSignature: string; // RSA-SHA256 签名（base64），data=utf8(payload)
    MinVersion: TSemanticVersion;  // Minimum version for incremental
    IsMandatory: Boolean;
    InstallPolicy: TUpdateInstallPolicy;
    Files: TArray<TUpdateFile>;

    function IsEmpty: Boolean;
  end;

// ============================================================================
// 契约助手函数
// ============================================================================

function ParseChannel(const Name: string): TUpdateChannel;
function ChannelToString(Channel: TUpdateChannel): string;
function ParseInstallMode(const Name: string): TUpdateInstallMode;
function InstallModeToString(Mode: TUpdateInstallMode): string;

/// <summary>
/// hash 归一化：剥 "sha256:" 前缀 + 转小写，得到 §16.10 签名侧的纯 hex 串。
/// 解析远端 metadata 与验签前比对都必须经过本函数，防止大小写/前缀分叉。
/// </summary>
function NormalizePackageHash(const ARawHash: string): string;

/// <summary>
/// manifest 验签 payload 的唯一构造（docs/66 §16.10 Step 4，7 字段 '|' 分隔，
/// 顺序固定 app_id|latest_version|channel|package_url|download_size|package_hash|signature）。
/// 空字段以空串占位保证字段数恒为 7；第 6 位使用归一化后的 PackageHash。
/// 所有验签路径必须经本函数，禁止第二实现（U-02 双实现消缺点）。
/// </summary>
function BuildManifestSignaturePayload(const Info: TUpdateInfo): string;

/// <summary>URL 的小写 host；无 host/解析失败返回空串。</summary>
function UrlHost(const AUrl: string): string;

/// <summary>
/// 更新端点最低门禁：仅要求 https scheme（静态 CDN 通道 AutoUpdate 用）。
/// 需要主机白名单的通道必须用 ValidateUpdateEndpointUrl。
/// </summary>
function ValidateUpdateEndpointScheme(const AUrl: string): TGateVerdict;

/// <summary>
/// 更新端点集中门禁（改法项 (4)）：https + 主机白名单。
/// AAllowedHosts 为空 = 无信任锚，直接拒绝（fail-closed，不提供"空名单=放行"语义）。
/// </summary>
function ValidateUpdateEndpointUrl(const AUrl: string;
  const AAllowedHosts: array of string): TGateVerdict;

implementation

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

  var Ver := VersionStr;
  if (Length(Ver) > 0) and ((Ver[1] = 'v') or (Ver[1] = 'V')) then
    Ver := Copy(Ver, 2, MaxInt);

  PreReleaseIdx := Pos('-', Ver);
  if PreReleaseIdx > 0 then
  begin
    Result.PreRelease := Copy(Ver, PreReleaseIdx + 1, MaxInt);
    Ver := Copy(Ver, 1, PreReleaseIdx - 1);
  end;

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
// 契约助手函数
// ============================================================================

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

function NormalizePackageHash(const ARawHash: string): string;
begin
  Result := Trim(ARawHash);
  if SameText(Copy(Result, 1, 7), 'sha256:') then
    Delete(Result, 1, 7);
  Result := LowerCase(Result);
end;

function BuildManifestSignaturePayload(const Info: TUpdateInfo): string;
begin
  Result := Info.AppId + '|' + Info.Version.ToString + '|' +
    ChannelToString(Info.Channel) + '|' + Info.DownloadUrl + '|' +
    IntToStr(Info.DownloadSize) + '|' + Info.PackageHash + '|' + Info.Signature;
end;

function UrlHost(const AUrl: string): string;
var
  LUri: TURI;
begin
  Result := '';
  if Trim(AUrl) = '' then
    Exit;
  try
    LUri := TURI.Create(AUrl);
    Result := LowerCase(LUri.Host);
  except
    Result := '';
  end;
end;

function ValidateUpdateEndpointScheme(const AUrl: string): TGateVerdict;
var
  LUri: TURI;
begin
  if Trim(AUrl) = '' then
    Exit(TGateVerdict.Rejected('Update endpoint URL is empty'));
  try
    LUri := TURI.Create(AUrl);
  except
    on E: Exception do
      Exit(TGateVerdict.Rejected('Unparseable update endpoint URL: ' + E.Message));
  end;
  if not SameText(LUri.Scheme, 'https') then
    Exit(TGateVerdict.Rejected('Update endpoint must use https: ' + AUrl));
  if LowerCase(LUri.Host) = '' then
    Exit(TGateVerdict.Rejected('Update endpoint has no host: ' + AUrl));
  Result := TGateVerdict.Approved;
end;

function ValidateUpdateEndpointUrl(const AUrl: string;
  const AAllowedHosts: array of string): TGateVerdict;
var
  LHost: string;
  I: Integer;
begin
  Result := ValidateUpdateEndpointScheme(AUrl);
  if not Result.IsApproved then
    Exit;

  if Length(AAllowedHosts) = 0 then
    Exit(TGateVerdict.Rejected(
      'No allowed update hosts configured; endpoint host is not trusted (fail-closed)'));

  LHost := UrlHost(AUrl);
  for I := 0 to High(AAllowedHosts) do
    if SameText(Trim(AAllowedHosts[I]), LHost) then
      Exit(TGateVerdict.Approved);
  Result := TGateVerdict.Rejected(
    'Update endpoint host "' + LHost + '" is not in the allowed host list');
end;

end.
