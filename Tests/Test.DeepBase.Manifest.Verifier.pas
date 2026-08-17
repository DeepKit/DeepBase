{ ============================================================================
  Test.DeepBase.Manifest.Verifier - Manifest v1 签名验证器测试

  覆盖（对齐 P0-004 验收硬条件 + 79 §13）：
  1. 合法 Manifest（JCS+RSA-SHA256 签名）通过验证
  2. 篡改签名/篡改字段 -> 拒绝加载
  3. generation 降级（< AMinGeneration）-> 拒绝
  4. 已过期 / 未生效 -> 拒绝
  5. 信任根缺失 -> 安全失败（抛 EManifestVerificationError）
  6. 未知 signing_key_id -> 拒绝
  7. 非 rsa-sha256 算法 -> 拒绝
  8. 信任根禁自证：keyset 由 AddTrustedKey 注入，Manifest 不能自证

  fixture 说明：RSA-2048 密钥对由 .NET (pwsh 7, RSABCrypt) 生成，签名用
  PKCS#1 v1.5 + SHA256（与 TRSAVerifier.VerifySignature 跨实现兼容，已 probe
  验证）。签名数据 = 剥离 signature 字段后 Manifest 的 JCS canonical 字符串
  的 UTF-8 字节。
  ============================================================================ }

unit Test.DeepBase.Manifest.Verifier;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  DeepBase.Manifest.Verifier;

type
  [TestFixture]
  TManifestVerifierTests = class
  private
    const
      { 测试用 RSA-2048 公钥（.NET 生成，DO NOT use in production） }
      TEST_PUBLIC_KEY_PEM =
        '-----BEGIN PUBLIC KEY-----' + sLineBreak +
        'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAsuIGGfRtaQWT2RLNZVXw' + sLineBreak +
        'yJyChWx5cpEGLQEwdjWLyN69sr0FBLwHw+guqpDuc5K7G+8l2PSWbzFtIhQXazUS' + sLineBreak +
        'Y1dSUViR9LXlfN/4gicx8j+Wzrfe+D5ds3p0Vzi2giu6MBTMOQd+DQz1GYmYzYQD' + sLineBreak +
        'G1OqQ+ur0PHzu45L3ttWPjGQz1PDR/88uJKBUu59JH2gSFrY2Hm8FtjvWFUiUP/u' + sLineBreak +
        'Q4Ngf9Z+Jlxz/MhT70ZnrrVZWxFX/9AvkM0AkUBAjdj/yK2MVsPP2WMLDFWbrNm2' + sLineBreak +
        '2BjrU/6oYJm/wkwPxU1NZr3hX1otVbL2yut51BGXZjuGgXNaVAuknaelD4WnHx2w' + sLineBreak +
        'hQIDAQAB' + sLineBreak +
        '-----END PUBLIC KEY-----';

      TEST_SIGNING_KEY_ID = 'release-2026-01';

      { 对 canonical Manifest（剥离 signature）的 PKCS#1 v1.5 RSA-SHA256 签名 }
      TEST_SIGNATURE_BASE64 =
        'eJVy7LQHjhEnupUy7EiyPeM2KRWMenBLNHLAAhkD+bIprXEQ6abpmMeOdxpvJ5ya' +
        'UDsXCIXCQH+286Pwd4kk4wOgSdRjIZq1i90GbXNqEI1VJMj+2OP5G9R+jAwgACn533' +
        'Gor8E/5/6LhRbfcCu9TNiJzLXk643saznwLyFds0hrzaXLBWeFcczPWEQyl+G6L177' +
        '7EDvJRZbMOjkc7/sX5F9AqRQBRvpPipzSReL/zCAssopq74h/brLjximdK2wVnNljCey' +
        '3nwWeP4juCjig7Dp2uR2AWOoTzko+ubxZwB0sNXzSUXiaXN94VLcxrqjv4j/Ve4FXIas' +
        '5d115oq18Q==';

      { 合法 Manifest v1（signature 已由 .NET 对 canonical 形式签名） }
      TEST_MANIFEST_JSON =
        '{' +
        '"artifact_id":"cfg-rules","artifact_type":"rules",' +
        '"version":"1.2.0","schema_version":1,' +
        '"abi":{"major":2,"minor":0},' +
        '"capabilities":["http","grpc"],' +
        '"algorithm":"rsa-sha256","signing_key_id":"release-2026-01",' +
        '"generation":42,' +
        '"issued_at":"2026-08-01T00:00:00Z","expires_at":"2026-12-31T23:59:59Z",' +
        '"signature":"' + TEST_SIGNATURE_BASE64 + '"' +
        '}';

    function MakeVerifier: TManifestVerifier;
    function WithSignature(const AJson, ASig: string): string;
    function WithAlgorithm(const AJson, AAlg: string): string;
    function WithGeneration(const AJson: string; AGen: Int64): string;
    function WithKeyId(const AJson, AKeyId: string): string;
    function WithIssuedAt(const AJson, ADate: string): string;
    function WithExpiresAt(const AJson, ADate: string): string;
  public
    [Setup]
    procedure Setup;

    [Test]
    procedure Test_ValidManifest_Passes;
    [Test]
    procedure Test_NoTrustedKeys_SafeFail;
    [Test]
    procedure Test_TamperedSignature_Rejected;
    [Test]
    procedure Test_TamperedField_Rejected;
    [Test]
    procedure Test_GenerationRollback_Rejected;
    [Test]
    procedure Test_GenerationEqual_Passes;
    [Test]
    procedure Test_Expired_Rejected;
    [Test]
    procedure Test_NotYetValid_Rejected;
    [Test]
    procedure Test_UnknownKeyId_Rejected;
    [Test]
    procedure Test_UnsupportedAlgorithm_Rejected;
    [Test]
    procedure Test_MetadataPopulated;
  end;

implementation

uses
  System.JSON,
  System.DateUtils;

function TManifestVerifierTests.MakeVerifier: TManifestVerifier;
begin
  Result := TManifestVerifier.Create;
  Result.AddTrustedKey(TEST_SIGNING_KEY_ID, TEST_PUBLIC_KEY_PEM);
end;

{ 替换 JSON 中的 signature 字段值（保持其他字段不变——字段顺序对 JCS 无关） }
function TManifestVerifierTests.WithSignature(const AJson, ASig: string): string;
begin
  Result := StringReplace(AJson,
    '"signature":"' + TEST_SIGNATURE_BASE64 + '"',
    '"signature":"' + ASig + '"', [rfReplaceAll]);
end;

function TManifestVerifierTests.WithAlgorithm(const AJson, AAlg: string): string;
begin
  Result := StringReplace(AJson,
    '"algorithm":"rsa-sha256"',
    '"algorithm":"' + AAlg + '"', [rfReplaceAll]);
end;

function TManifestVerifierTests.WithGeneration(const AJson: string; AGen: Int64): string;
begin
  Result := StringReplace(AJson,
    '"generation":42', '"generation":' + IntToStr(AGen), [rfReplaceAll]);
end;

function TManifestVerifierTests.WithKeyId(const AJson, AKeyId: string): string;
begin
  Result := StringReplace(AJson,
    '"signing_key_id":"release-2026-01"',
    '"signing_key_id":"' + AKeyId + '"', [rfReplaceAll]);
end;

function TManifestVerifierTests.WithIssuedAt(const AJson, ADate: string): string;
begin
  Result := StringReplace(AJson,
    '"issued_at":"2026-08-01T00:00:00Z"',
    '"issued_at":"' + ADate + '"', [rfReplaceAll]);
end;

function TManifestVerifierTests.WithExpiresAt(const AJson, ADate: string): string;
begin
  Result := StringReplace(AJson,
    '"expires_at":"2026-12-31T23:59:59Z"',
    '"expires_at":"' + ADate + '"', [rfReplaceAll]);
end;

procedure TManifestVerifierTests.Setup;
begin
end;

procedure TManifestVerifierTests.Test_ValidManifest_Passes;
var
  V: TManifestVerifier;
  M: TManifestMetadata;
  B: Boolean;
begin
  V := MakeVerifier;
  try
    B := V.VerifyManifest(TEST_MANIFEST_JSON, 0,
      ISO8601ToDate('2026-09-15T00:00:00Z', False), M);
    Assert.IsTrue(B, 'Valid manifest should pass. LastError=' + V.LastError);
    Assert.AreEqual(Int64(42), M.Generation);
    Assert.AreEqual('cfg-rules', M.ArtifactId);
  finally
    V.Free;
  end;
end;

procedure TManifestVerifierTests.Test_NoTrustedKeys_SafeFail;
var
  V: TManifestVerifier;
  M: TManifestMetadata;
  LRaised: Boolean;
begin
  V := TManifestVerifier.Create;  { no keys injected }
  try
    LRaised := False;
    try
      V.VerifyManifest(TEST_MANIFEST_JSON, 0,
        ISO8601ToDate('2026-09-15T00:00:00Z', False), M);
    except
      on E: EManifestVerificationError do
        LRaised := True;
    end;
    Assert.IsTrue(LRaised, 'No trusted keys must raise EManifestVerificationError (safe-fail)');
  finally
    V.Free;
  end;
end;

procedure TManifestVerifierTests.Test_TamperedSignature_Rejected;
var
  V: TManifestVerifier;
  M: TManifestMetadata;
  B: Boolean;
begin
  V := MakeVerifier;
  try
    B := V.VerifyManifest(
      WithSignature(TEST_MANIFEST_JSON, StringOfChar('A', Length(TEST_SIGNATURE_BASE64))),
      0, ISO8601ToDate('2026-09-15T00:00:00Z', False), M);
    Assert.IsFalse(B, 'Tampered signature must be rejected');
  finally
    V.Free;
  end;
end;

procedure TManifestVerifierTests.Test_TamperedField_Rejected;
var
  V: TManifestVerifier;
  M: TManifestMetadata;
  B: Boolean;
begin
  V := MakeVerifier;
  try
    { 篡改 version 字段（未重签）-> 签名校验失败 }
    B := V.VerifyManifest(
      StringReplace(TEST_MANIFEST_JSON, '"version":"1.2.0"', '"version":"1.2.1"', []),
      0, ISO8601ToDate('2026-09-15T00:00:00Z', False), M);
    Assert.IsFalse(B, 'Tampered field must be rejected');
  finally
    V.Free;
  end;
end;

procedure TManifestVerifierTests.Test_GenerationRollback_Rejected;
var
  V: TManifestVerifier;
  M: TManifestMetadata;
  B: Boolean;
begin
  V := MakeVerifier;
  try
    { Manifest generation=42，宿主要求 >= 100 -> 降级拒绝 }
    B := V.VerifyManifest(TEST_MANIFEST_JSON, 100,
      ISO8601ToDate('2026-09-15T00:00:00Z', False), M);
    Assert.IsFalse(B, 'Generation rollback must be rejected. LastError=' + V.LastError);
  finally
    V.Free;
  end;
end;

procedure TManifestVerifierTests.Test_GenerationEqual_Passes;
var
  V: TManifestVerifier;
  M: TManifestMetadata;
  B: Boolean;
begin
  V := MakeVerifier;
  try
    B := V.VerifyManifest(TEST_MANIFEST_JSON, 42,
      ISO8601ToDate('2026-09-15T00:00:00Z', False), M);
    Assert.IsTrue(B, 'Generation == min must pass');
  finally
    V.Free;
  end;
end;

procedure TManifestVerifierTests.Test_Expired_Rejected;
var
  V: TManifestVerifier;
  M: TManifestMetadata;
  B: Boolean;
begin
  V := MakeVerifier;
  try
    { 当前时间 > expires_at (2026-12-31) -> 已过期 }
    B := V.VerifyManifest(TEST_MANIFEST_JSON, 0,
      ISO8601ToDate('2027-01-15T00:00:00Z', False), M);
    Assert.IsFalse(B, 'Expired manifest must be rejected. LastError=' + V.LastError);
  finally
    V.Free;
  end;
end;

procedure TManifestVerifierTests.Test_NotYetValid_Rejected;
var
  V: TManifestVerifier;
  M: TManifestMetadata;
  B: Boolean;
begin
  V := MakeVerifier;
  try
    { 当前时间 < issued_at (2026-08-01) -> 未生效 }
    B := V.VerifyManifest(TEST_MANIFEST_JSON, 0,
      ISO8601ToDate('2026-07-01T00:00:00Z', False), M);
    Assert.IsFalse(B, 'Not-yet-valid manifest must be rejected. LastError=' + V.LastError);
  finally
    V.Free;
  end;
end;

procedure TManifestVerifierTests.Test_UnknownKeyId_Rejected;
var
  V: TManifestVerifier;
  M: TManifestMetadata;
  B: Boolean;
begin
  V := MakeVerifier;
  try
    { signing_key_id 不在信任根内 -> 拒绝 }
    B := V.VerifyManifest(WithKeyId(TEST_MANIFEST_JSON, 'unknown-key-999'),
      0, ISO8601ToDate('2026-09-15T00:00:00Z', False), M);
    Assert.IsFalse(B, 'Unknown signing_key_id must be rejected');
  finally
    V.Free;
  end;
end;

procedure TManifestVerifierTests.Test_UnsupportedAlgorithm_Rejected;
var
  V: TManifestVerifier;
  M: TManifestMetadata;
  B: Boolean;
begin
  V := MakeVerifier;
  try
    B := V.VerifyManifest(WithAlgorithm(TEST_MANIFEST_JSON, 'ed25519'),
      0, ISO8601ToDate('2026-09-15T00:00:00Z', False), M);
    Assert.IsFalse(B, 'Unsupported algorithm must be rejected');
  finally
    V.Free;
  end;
end;

procedure TManifestVerifierTests.Test_MetadataPopulated;
var
  V: TManifestVerifier;
  M: TManifestMetadata;
  B: Boolean;
begin
  V := MakeVerifier;
  try
    B := V.VerifyManifest(TEST_MANIFEST_JSON, 0,
      ISO8601ToDate('2026-09-15T00:00:00Z', False), M);
    Assert.IsTrue(B, 'Valid manifest should pass');
    Assert.AreEqual('cfg-rules', M.ArtifactId);
    Assert.AreEqual('rules', M.ArtifactType);
    Assert.AreEqual('1.2.0', M.Version);
    Assert.AreEqual(1, M.SchemaVersion);
    Assert.AreEqual(2, M.Abi.Major);
    Assert.AreEqual(0, M.Abi.Minor);
    Assert.AreEqual('rsa-sha256', M.Algorithm);
    Assert.AreEqual('release-2026-01', M.SigningKeyId);
    Assert.AreEqual(Int64(42), M.Generation);
    Assert.AreEqual(NativeInt(2), Length(M.Capabilities));
    Assert.AreEqual('http', M.Capabilities[0]);
    Assert.AreEqual('grpc', M.Capabilities[1]);
    Assert.AreEqual(TEST_SIGNATURE_BASE64, M.SignatureBase64);
    Assert.IsTrue(M.HasIssuedAt);
    Assert.IsTrue(M.HasExpiresAt);
  finally
    V.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TManifestVerifierTests);

end.
