{ ============================================================================
  DeepBase.Manifest.Verifier - 统一 Artifact Manifest v1 签名验证器

  法源：docs/79.protocol §13（统一 Artifact Manifest 字段与信任根原则）
        docs/77a.adr §4（校验逻辑归口）
        docs/78a.adr §2.7（签名信任根与防回滚，P0-004）
        P0-004 任务验收硬条件：篡改签名拒绝加载、版本降低拒绝、信任根缺失安全失败

  安全纪律（与 79 §13 §216 对齐）：
  - 签名算法门禁：仅接受 algorithm=rsa-sha256（RSA-SHA256, PKCS#1 v1.5）；
  - 签名数据 = 剥离 signature 字段后的 Manifest 经 RFC 8785 JCS 规范化
    后的 UTF-8 字节（与签名方一致，键序无关）；
  - 信任根 keyset 禁止自证：只能由宿主/可信安装通过 AddTrustedKey 注入，
    Manifest 内的 signing_key_id 必须命中已注入 keyset，否则拒载；
  - generation 防回滚：Manifest.generation 必须 >= AMinGeneration，否则拒载；
  - 过期校验：issued_at <= now <= expires_at（UTC），未生效/已过期均拒载；
  - 信任根缺失（无任何注入 key）时安全失败：抛 EManifestVerificationError，
    绝不放行（验收硬条件 #3）。
  ============================================================================ }

unit DeepBase.Manifest.Verifier;

interface

uses
  System.SysUtils,
  System.JSON,
  System.Generics.Collections,
  DeepBase.Crypto.JCS,
  DeepBase.Crypto.RSA;

const
  { Manifest v1 schema 版本与受支持签名算法 }
  CManifestSchemaVersion = 1;
  CManifestAlgorithmRsaSha256 = 'rsa-sha256';

type
  { 验证失败异常。配置级失败（信任根缺失/不支持的算法）抛异常；业务级
    验证失败（签名不符/降级/过期/未知 key）通过 Verify 返回 False + LastError。 }
  EManifestVerificationError = class(Exception)
  end;

  { 解析并校验通过后的 Manifest 元数据快照 }
  TManifestAbi = record
    Major: Integer;
    Minor: Integer;
  end;

  TManifestMetadata = record
    ArtifactId: string;
    ArtifactType: string;
    Version: string;
    SchemaVersion: Integer;
    Abi: TManifestAbi;
    Capabilities: TArray<string>;
    RolloutRing: string;
    RollbackTarget: string;
    Lkg: string;
    Algorithm: string;
    SigningKeyId: string;
    Generation: Int64;
    IssuedAt: TDateTime;      // UTC
    ExpiresAt: TDateTime;     // UTC
    HasIssuedAt: Boolean;
    HasExpiresAt: Boolean;
    SignatureBase64: string;
  end;

  { Manifest v1 签名验证器。线程无关：AddTrustedKey 在配置期调用，
    VerifyManifest 为只读并发安全（FTrustedKeys 无并发写）。 }
  TManifestVerifier = class
  private
    FTrustedKeys: TDictionary<string, string>;
    FHasTrustedKeys: Boolean;
    FLastError: string;
    function CanonicalSigningData(ARoot: TJSONObject): string;
    function ParseMetadata(ARoot: TJSONObject): TManifestMetadata;
    function CheckGeneration(const AMeta: TManifestMetadata; AMinGeneration: Int64): Boolean;
    function CheckTimestamps(const AMeta: TManifestMetadata; ANow: TDateTime;
      AAllowExpired: Boolean): Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    { 注入信任根公钥（PEM, PKCS#1）。重复 key_id 覆盖。 }
    procedure AddTrustedKey(const AKeyId, APem: string);
    procedure ClearTrustedKeys;

    { 验证 Manifest JSON。AMinGeneration 为宿主已知最低可接受 generation
      （防回滚）；ANow 为当前 UTC 时间。成功返回 True 并填充 AMetadata。 }
    function VerifyManifest(const AJson: string; AMinGeneration: Int64;
      ANow: TDateTime; out AMetadata: TManifestMetadata): Boolean; overload;
    { 便捷重载：仅做完整性+防回滚+过期（用当前 UTC 时间），不返回元数据 }
    function VerifyManifest(const AJson: string; AMinGeneration: Int64): Boolean; overload;

    property HasTrustedKeys: Boolean read FHasTrustedKeys;
    property LastError: string read FLastError;
  end;

implementation

uses
  System.Math,
  System.DateUtils;

{ TManifestVerifier }

constructor TManifestVerifier.Create;
begin
  inherited Create;
  FTrustedKeys := TDictionary<string, string>.Create;
  FHasTrustedKeys := False;
  FLastError := '';
end;

destructor TManifestVerifier.Destroy;
begin
  FTrustedKeys.Free;
  inherited Destroy;
end;

procedure TManifestVerifier.AddTrustedKey(const AKeyId, APem: string);
begin
  if AKeyId = '' then
    raise EManifestVerificationError.Create('Trusted key id must not be empty');
  if APem = '' then
    raise EManifestVerificationError.CreateFmt('Trusted key %s has empty PEM', [AKeyId]);
  FTrustedKeys.AddOrSetValue(AKeyId, APem);
  FHasTrustedKeys := True;
end;

procedure TManifestVerifier.ClearTrustedKeys;
begin
  FTrustedKeys.Clear;
  FHasTrustedKeys := False;
end;

{ 签名数据 = 剥离 signature 字段后经 JCS 规范化的 UTF-8 字符串。
  剥离而不是排除键：签名方与验证方对同一 JSON 做相同剥离+JCS，结果一致。 }
function TManifestVerifier.CanonicalSigningData(ARoot: TJSONObject): string;
var
  LSigning: TJSONObject;
  LPair: TJSONPair;
begin
  LSigning := TJSONObject.Create;
  try
    for LPair in ARoot do
      if not SameText(LPair.JsonString.Value, 'signature') then
        LSigning.AddPair(LPair.Clone as TJSONPair);
    Result := TJsonCanonicalizer.Canonicalize(LSigning);
  finally
    LSigning.Free;
  end;
end;

function TManifestVerifier.ParseMetadata(ARoot: TJSONObject): TManifestMetadata;
var
  LAbiObj: TJSONObject;
  LCapArr: TJSONArray;
  LVal: TJSONValue;
  I: Integer;
  LTmp: string;
begin
  { out 语义：托管字段（string/TArray）已由编译器清空；
    仅需显式初始化非托管字段。 }
  Result.SchemaVersion := -1;
  Result.Abi.Major := 0;
  Result.Abi.Minor := 0;
  Result.Generation := 0;
  Result.HasIssuedAt := False;
  Result.HasExpiresAt := False;

  if ARoot.TryGetValue<string>('artifact_id', Result.ArtifactId) then ;
  ARoot.TryGetValue<string>('artifact_type', Result.ArtifactType);
  ARoot.TryGetValue<string>('version', Result.Version);
  ARoot.TryGetValue<string>('algorithm', Result.Algorithm);
  ARoot.TryGetValue<string>('signing_key_id', Result.SigningKeyId);
  ARoot.TryGetValue<string>('rollout_ring', Result.RolloutRing);
  ARoot.TryGetValue<string>('rollback_target', Result.RollbackTarget);
  ARoot.TryGetValue<string>('lkg', Result.Lkg);

  if ARoot.TryGetValue<Int64>('generation', Result.Generation) then ;
  ARoot.TryGetValue<Integer>('schema_version', Result.SchemaVersion);
  ARoot.TryGetValue<string>('signature', Result.SignatureBase64);

  if ARoot.TryGetValue<string>('issued_at', LTmp) then
  begin
    Result.IssuedAt := ISO8601ToDate(LTmp, False);
    Result.HasIssuedAt := True;
  end;
  if ARoot.TryGetValue<string>('expires_at', LTmp) then
  begin
    Result.ExpiresAt := ISO8601ToDate(LTmp, False);
    Result.HasExpiresAt := True;
  end;

  if ARoot.TryGetValue<TJSONObject>('abi', LAbiObj) then
  begin
    LAbiObj.TryGetValue<Integer>('major', Result.Abi.Major);
    LAbiObj.TryGetValue<Integer>('minor', Result.Abi.Minor);
  end;

  if ARoot.TryGetValue<TJSONArray>('capabilities', LCapArr) then
  begin
    SetLength(Result.Capabilities, LCapArr.Count);
    for I := 0 to LCapArr.Count - 1 do
    begin
      LVal := LCapArr.Items[I];
      if LVal is TJSONString then
        Result.Capabilities[I] := TJSONString(LVal).Value;
    end;
  end;
end;

function TManifestVerifier.CheckGeneration(const AMeta: TManifestMetadata;
  AMinGeneration: Int64): Boolean;
begin
  if AMeta.Generation < AMinGeneration then
  begin
    FLastError := Format('Rollback rejected: generation %d < min %d',
      [AMeta.Generation, AMinGeneration]);
    Exit(False);
  end;
  Result := True;
end;

function TManifestVerifier.CheckTimestamps(const AMeta: TManifestMetadata;
  ANow: TDateTime; AAllowExpired: Boolean): Boolean;
begin
  if AMeta.HasIssuedAt and (AMeta.IssuedAt > ANow) then
  begin
    FLastError := Format('Manifest not yet valid: issued_at %s > now %s',
      [DateToISO8601(AMeta.IssuedAt, False), DateToISO8601(ANow, False)]);
    Exit(False);
  end;
  if AMeta.HasExpiresAt and (AMeta.ExpiresAt < ANow) and not AAllowExpired then
  begin
    FLastError := Format('Manifest expired: expires_at %s < now %s',
      [DateToISO8601(AMeta.ExpiresAt, False), DateToISO8601(ANow, False)]);
    Exit(False);
  end;
  Result := True;
end;

function TManifestVerifier.VerifyManifest(const AJson: string;
  AMinGeneration: Int64; ANow: TDateTime;
  out AMetadata: TManifestMetadata): Boolean;
var
  LRoot: TJSONObject;
  LSigningData: string;
  LKeyId: string;
  LPem: string;
  LVerifier: TRSAVerifier;
begin
  Result := False;
  FLastError := '';
  { out 语义自动清空托管字段；无需 ZeroMemory }

  { 信任根缺失 = 安全失败（验收硬条件 #3） }
  if not FHasTrustedKeys then
    raise EManifestVerificationError.Create(
      'No trusted keys injected; refusing to verify manifest (safe-fail)');

  LRoot := nil;
  try
    LRoot := TJSONObject.ParseJSONValue(AJson) as TJSONObject;
    if LRoot = nil then
    begin
      FLastError := 'Malformed manifest: not a JSON object';
      Exit;
    end;

    AMetadata := ParseMetadata(LRoot);

    { 算法门禁 }
    if not SameText(AMetadata.Algorithm, CManifestAlgorithmRsaSha256) then
    begin
      FLastError := Format('Unsupported signature algorithm "%s"; expected %s',
        [AMetadata.Algorithm, CManifestAlgorithmRsaSha256]);
      Exit;
    end;

    { signing_key_id 必须声明且命中信任根 }
    LKeyId := AMetadata.SigningKeyId;
    if LKeyId = '' then
    begin
      FLastError := 'Manifest missing signing_key_id';
      Exit;
    end;
    if not FTrustedKeys.TryGetValue(LKeyId, LPem) then
    begin
      FLastError := Format('signing_key_id "%s" not in trusted keyset', [LKeyId]);
      Exit;
    end;

    { 防回滚 }
    if not CheckGeneration(AMetadata, AMinGeneration) then
      Exit;

    { 过期校验 }
    if not CheckTimestamps(AMetadata, ANow, False) then
      Exit;

    { 签名验证：签名数据 = 剥离 signature 的 JCS 规范化 }
    LSigningData := CanonicalSigningData(LRoot);

    LVerifier := TRSAVerifier.Create;
    try
      if not LVerifier.LoadPublicKeyPEM(LPem) then
      begin
        FLastError := 'Failed to load trusted public key: ' + LVerifier.LastError;
        Exit;
      end;
      if not LVerifier.VerifySignature(LSigningData, AMetadata.SignatureBase64) then
      begin
        FLastError := 'Signature verification failed: ' + LVerifier.LastError;
        Exit;
      end;
    finally
      LVerifier.Free;
    end;

    Result := True;
  finally
    LRoot.Free;
  end;
end;

function TManifestVerifier.VerifyManifest(const AJson: string;
  AMinGeneration: Int64): Boolean;
var
  LMeta: TManifestMetadata;
begin
  Result := VerifyManifest(AJson, AMinGeneration, Now, LMeta);
end;

end.
