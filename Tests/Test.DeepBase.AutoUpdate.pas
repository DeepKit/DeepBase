{ ============================================================================
  Test.DeepBase.AutoUpdate - Unit Tests for Auto-Update Module

  覆盖：
    - TUpdateInfo（DeepBase.Update.Contracts SSOT 别名）字段语义
    - TDeepBaseAutoUpdate 属性 / 通道 / 版本归一化
    - 完整性三方（SHA256 + RSA-SHA256 签名 + 公钥）fail-closed 门禁（改法项 (2)）
    - 端点 https 门禁（改法项 (4)，静态 CDN 通道无白名单可配）
    - AU-01 正向 KAT：对包文件原始字节单层签名 → 验签收敛（RSA-2048/CNG 真实往返）

  密钥材料来自 Test.DeepBase.UpdateFixtures（两通道测试共用，禁各持一份）。
  法源：WO-20260920-AUDIT-甲-R5 M1（Top20#01 更新验签链，docs/66 §16.10）。
  ============================================================================ }

unit Test.DeepBase.AutoUpdate;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Hash,
  DeepBase.Gate.Verdict,
  DeepBase.Update.Contracts,
  DeepBase.AutoUpdate;

type
  [TestFixture]
  TTestUpdateInfo = class
  public
    [Test]
    procedure Test_DefaultValues;
    [Test]
    procedure Test_VersionField;
    [Test]
    procedure Test_ChannelField;
    [Test]
    procedure Test_DownloadUrlField;
    [Test]
    procedure Test_DownloadSizeField;
    [Test]
    procedure Test_PackageHashField;
    [Test]
    procedure Test_SignatureField;
    [Test]
    procedure Test_ReleaseDateField;
    [Test]
    procedure Test_ReleaseNotesField;
    [Test]
    procedure Test_IsMandatoryField;
    [Test]
    procedure Test_IsEmpty;
    [Test]
    procedure Test_AllFieldsAssignment;
  end;

  [TestFixture]
  TTestAutoUpdateClass = class
  private
    FAutoUpdate: TDeepBaseAutoUpdate;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Create_Default;
    [Test]
    procedure Test_Create_WithParams;
    [Test]
    procedure Test_UpdateUrl_Get;
    [Test]
    procedure Test_UpdateUrl_Set;
    [Test]
    procedure Test_CurrentVersion_Default;
    [Test]
    procedure Test_CurrentVersion_Set;
    [Test]
    procedure Test_CurrentVersion_Empty;
    [Test]
    procedure Test_Channel_Default;
    [Test]
    procedure Test_Channel_SetStable;
    [Test]
    procedure Test_Channel_SetBeta;
    [Test]
    procedure Test_Channel_SetDev;
    [Test]
    procedure Test_CheckForUpdate_NoUrl;
  end;

  [TestFixture]
  TTestUpdateChannel = class
  public
    [Test]
    procedure Test_Stable;
    [Test]
    procedure Test_Beta;
    [Test]
    procedure Test_Alpha;
    [Test]
    procedure Test_Dev;
    [Test]
    procedure Test_EnumValues;
  end;

  [TestFixture]
  TTestVersionNormalization = class
  private
    FAutoUpdate: TDeepBaseAutoUpdate;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_VersionWithV;
    [Test]
    procedure Test_VersionWithoutV;
    [Test]
    procedure Test_EmptyVersion;
    [Test]
    procedure Test_TrimmedVersion;
  end;

  /// <summary>
  /// 完整性门禁测试（改法项 (2)(4) + AU-01）：
  /// - hash/签名/公钥三元组任一缺失 = 下载前 fail-closed 拒绝，不发网络请求；
  /// - 非 https 端点拒绝；
  /// - 正向 KAT：私钥对包原始字节签名 → VerifyDownloadedPackageIntegrity 通过；
  /// - 篡改包 / 伪造签名 → 拒绝且删包。
  /// </summary>
  [TestFixture]
  TTestIntegrityEnforcement = class
  private
    FAutoUpdate: TDeepBaseAutoUpdate;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_DefaultConnectionTimeout;
    [Test]
    procedure Test_DefaultResponseTimeout;
    [Test]
    procedure Test_TimeoutsAreConfigurable;
    [Test]
    procedure Test_DownloadUpdate_FailClosed_NoIntegrityInfo;
    [Test]
    procedure Test_DownloadUpdate_FailClosed_OnlyPackageHash;
    [Test]
    procedure Test_DownloadUpdate_FailClosed_OnlySignature;
    [Test]
    procedure Test_DownloadUpdate_FailClosed_NoPublicKey;
    [Test]
    procedure Test_DownloadUpdate_NonHttpsEndpoint_RejectedWithoutRequest;
    [Test]
    procedure Test_Verify_IntegrityKAT_SignedRawBytes_Approved;
    [Test]
    procedure Test_Verify_TamperedPackageAfterSigning_RejectedAndDeleted;
    [Test]
    procedure Test_Verify_ForgedSignature_HashConsistent_Rejected;
    [Test]
    procedure Test_Verify_MissingHash_RejectedAndDeleted;
    [Test]
    procedure Test_Verify_MissingSignature_Rejected;
    [Test]
    procedure Test_Verify_MissingPublicKey_Rejected;
  end;

implementation

uses
  Test.DeepBase.UpdateFixtures;

{ TTestUpdateInfo }

procedure TTestUpdateInfo.Test_DefaultValues;
var
  Info: TUpdateInfo;
begin
  Info := Default(TUpdateInfo);

  Assert.AreEqual('0.0.0', Info.Version.ToString);
  Assert.AreEqual('', Info.DownloadUrl);
  Assert.AreEqual('', Info.PackageHash);
  Assert.AreEqual('', Info.Signature);
  Assert.AreEqual(Int64(0), Info.DownloadSize);
  Assert.IsFalse(Info.IsMandatory);
end;

procedure TTestUpdateInfo.Test_VersionField;
var
  Info: TUpdateInfo;
begin
  Info.Version := TSemanticVersion.Parse('1.2.3');
  Assert.AreEqual('1.2.3', Info.Version.ToString);

  Info.Version := TSemanticVersion.Parse('2.0.0-beta.1');
  Assert.AreEqual('2.0.0-beta.1', Info.Version.ToString);
  Assert.AreEqual(2, Info.Version.Major);
  Assert.AreEqual('beta.1', Info.Version.PreRelease);
end;

procedure TTestUpdateInfo.Test_ChannelField;
var
  Info: TUpdateInfo;
begin
  Info.Channel := ucStable;
  Assert.AreEqual(ucStable, Info.Channel);

  Info.Channel := ucBeta;
  Assert.AreEqual(ucBeta, Info.Channel);

  Info.Channel := ucDev;
  Assert.AreEqual(ucDev, Info.Channel);
end;

procedure TTestUpdateInfo.Test_DownloadUrlField;
var
  Info: TUpdateInfo;
begin
  Info.DownloadUrl := 'https://example.com/update.exe';
  Assert.AreEqual('https://example.com/update.exe', Info.DownloadUrl);
end;

procedure TTestUpdateInfo.Test_DownloadSizeField;
var
  Info: TUpdateInfo;
begin
  Info.DownloadSize := 0;
  Assert.AreEqual(Int64(0), Info.DownloadSize);

  Info.DownloadSize := 52428800;  // 50MB
  Assert.AreEqual(Int64(52428800), Info.DownloadSize);
end;

procedure TTestUpdateInfo.Test_PackageHashField;
var
  Info: TUpdateInfo;
begin
  Info.PackageHash := 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
  Assert.AreEqual(64, Integer(Length(Info.PackageHash)));
end;

procedure TTestUpdateInfo.Test_SignatureField;
var
  Info: TUpdateInfo;
begin
  // §16.10：Signature = base64(RSA-SHA256(utf8(PackageHash)))，契约侧纯字符串字段。
  Info := Default(TUpdateInfo);
  Assert.AreEqual('', Info.Signature);

  Info.Signature := TestRSASign('e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
  Assert.IsTrue(Info.Signature <> '');
end;

procedure TTestUpdateInfo.Test_ReleaseDateField;
var
  Info: TUpdateInfo;
  TestDate: TDateTime;
begin
  TestDate := Now;
  Info.ReleaseDate := TestDate;
  Assert.AreEqual(TestDate, Info.ReleaseDate);
end;

procedure TTestUpdateInfo.Test_ReleaseNotesField;
var
  Info: TUpdateInfo;
begin
  Info.ReleaseNotes := '- Bug fixes' + sLineBreak + '- New features' + sLineBreak + '- Performance improvements';
  Assert.IsTrue(Info.ReleaseNotes.Contains('Bug fixes'));
  Assert.IsTrue(Info.ReleaseNotes.Contains('Performance'));
end;

procedure TTestUpdateInfo.Test_IsMandatoryField;
var
  Info: TUpdateInfo;
begin
  Info.IsMandatory := False;
  Assert.IsFalse(Info.IsMandatory);

  Info.IsMandatory := True;
  Assert.IsTrue(Info.IsMandatory);
end;

procedure TTestUpdateInfo.Test_IsEmpty;
var
  Info: TUpdateInfo;
begin
  Info := Default(TUpdateInfo);
  Assert.IsTrue(Info.IsEmpty, 'Default record must be empty');

  Info.DownloadUrl := 'https://example.com/pkg.zip';
  Assert.IsFalse(Info.IsEmpty);
end;

procedure TTestUpdateInfo.Test_AllFieldsAssignment;
var
  Info: TUpdateInfo;
begin
  Info := Default(TUpdateInfo);
  Info.AppId := 'deepbase_desktop';
  Info.Version := TSemanticVersion.Parse('3.0.0');
  Info.Channel := ucStable;
  Info.DownloadUrl := 'https://cdn.example.com/v3/setup.exe';
  Info.DownloadSize := 104857600;
  Info.PackageHash := 'abc123def456';
  Info.Signature := 'SIG_B64';
  Info.ReleaseDate := Now;
  Info.ReleaseNotes := 'Major release with breaking changes';
  Info.IsMandatory := True;

  Assert.AreEqual('deepbase_desktop', Info.AppId);
  Assert.AreEqual('3.0.0', Info.Version.ToString);
  Assert.AreEqual(ucStable, Info.Channel);
  Assert.AreEqual('https://cdn.example.com/v3/setup.exe', Info.DownloadUrl);
  Assert.AreEqual(Int64(104857600), Info.DownloadSize);
  Assert.IsTrue(Info.IsMandatory);
end;

{ TTestAutoUpdateClass }

procedure TTestAutoUpdateClass.Setup;
begin
  FAutoUpdate := TDeepBaseAutoUpdate.Create;
end;

procedure TTestAutoUpdateClass.TearDown;
begin
  FAutoUpdate.Free;
end;

procedure TTestAutoUpdateClass.Test_Create_Default;
begin
  Assert.IsNotNull(FAutoUpdate);
end;

procedure TTestAutoUpdateClass.Test_Create_WithParams;
var
  AutoUpdate: TDeepBaseAutoUpdate;
begin
  AutoUpdate := TDeepBaseAutoUpdate.Create('https://example.com/version.json', '1.0.0');
  try
    Assert.AreEqual('https://example.com/version.json', AutoUpdate.UpdateUrl);
    Assert.AreEqual('1.0.0', AutoUpdate.CurrentVersion);
  finally
    AutoUpdate.Free;
  end;
end;

procedure TTestAutoUpdateClass.Test_UpdateUrl_Get;
begin
  FAutoUpdate.UpdateUrl := 'https://test.com/updates.json';
  Assert.AreEqual('https://test.com/updates.json', FAutoUpdate.UpdateUrl);
end;

procedure TTestAutoUpdateClass.Test_UpdateUrl_Set;
begin
  FAutoUpdate.UpdateUrl := 'https://api.example.com/v1/version.json';
  Assert.AreEqual('https://api.example.com/v1/version.json', FAutoUpdate.UpdateUrl);
end;

procedure TTestAutoUpdateClass.Test_CurrentVersion_Default;
var
  AutoUpdate: TDeepBaseAutoUpdate;
begin
  AutoUpdate := TDeepBaseAutoUpdate.Create;
  try
    // Empty version should return '0.0.0'
    Assert.AreEqual('0.0.0', AutoUpdate.CurrentVersion);
  finally
    AutoUpdate.Free;
  end;
end;

procedure TTestAutoUpdateClass.Test_CurrentVersion_Set;
begin
  FAutoUpdate.CurrentVersion := '2.5.3';
  Assert.AreEqual('2.5.3', FAutoUpdate.CurrentVersion);
end;

procedure TTestAutoUpdateClass.Test_CurrentVersion_Empty;
begin
  FAutoUpdate.CurrentVersion := '';
  Assert.AreEqual('0.0.0', FAutoUpdate.CurrentVersion);
end;

procedure TTestAutoUpdateClass.Test_Channel_Default;
begin
  Assert.AreEqual(ucStable, FAutoUpdate.Channel);
end;

procedure TTestAutoUpdateClass.Test_Channel_SetStable;
begin
  FAutoUpdate.Channel := ucStable;
  Assert.AreEqual(ucStable, FAutoUpdate.Channel);
end;

procedure TTestAutoUpdateClass.Test_Channel_SetBeta;
begin
  FAutoUpdate.Channel := ucBeta;
  Assert.AreEqual(ucBeta, FAutoUpdate.Channel);
end;

procedure TTestAutoUpdateClass.Test_Channel_SetDev;
begin
  FAutoUpdate.Channel := ucDev;
  Assert.AreEqual(ucDev, FAutoUpdate.Channel);
end;

procedure TTestAutoUpdateClass.Test_CheckForUpdate_NoUrl;
var
  Info: TUpdateInfo;
  HasUpdate: Boolean;
begin
  FAutoUpdate.UpdateUrl := '';
  HasUpdate := FAutoUpdate.CheckForUpdate(Info);
  Assert.IsFalse(HasUpdate);
end;

{ TTestUpdateChannel }

procedure TTestUpdateChannel.Test_Stable;
begin
  Assert.AreEqual(0, Ord(ucStable));
end;

procedure TTestUpdateChannel.Test_Beta;
begin
  Assert.AreEqual(1, Ord(ucBeta));
end;

procedure TTestUpdateChannel.Test_Alpha;
begin
  Assert.AreEqual(2, Ord(ucAlpha));
end;

procedure TTestUpdateChannel.Test_Dev;
begin
  Assert.AreEqual(3, Ord(ucDev));
end;

procedure TTestUpdateChannel.Test_EnumValues;
begin
  Assert.AreEqual(4, Ord(High(TUpdateChannel)) + 1);
end;

{ TTestVersionNormalization }

procedure TTestVersionNormalization.Setup;
begin
  FAutoUpdate := TDeepBaseAutoUpdate.Create;
end;

procedure TTestVersionNormalization.TearDown;
begin
  FAutoUpdate.Free;
end;

procedure TTestVersionNormalization.Test_VersionWithV;
begin
  FAutoUpdate.CurrentVersion := 'v1.2.3';
  // Should normalize by removing 'v' prefix internally when comparing
  Assert.IsTrue(FAutoUpdate.CurrentVersion.StartsWith('v') or
                (FAutoUpdate.CurrentVersion = '1.2.3'));
end;

procedure TTestVersionNormalization.Test_VersionWithoutV;
begin
  FAutoUpdate.CurrentVersion := '1.2.3';
  Assert.AreEqual('1.2.3', FAutoUpdate.CurrentVersion);
end;

procedure TTestVersionNormalization.Test_EmptyVersion;
begin
  FAutoUpdate.CurrentVersion := '';
  Assert.AreEqual('0.0.0', FAutoUpdate.CurrentVersion);
end;

procedure TTestVersionNormalization.Test_TrimmedVersion;
begin
  FAutoUpdate.CurrentVersion := '  1.0.0  ';
  // Should be trimmed
  Assert.IsFalse(FAutoUpdate.CurrentVersion.StartsWith(' '));
  Assert.IsFalse(FAutoUpdate.CurrentVersion.EndsWith(' '));
end;

{ TTestIntegrityEnforcement }

procedure TTestIntegrityEnforcement.Setup;
begin
  FAutoUpdate := TDeepBaseAutoUpdate.Create;
  // 显式覆盖公钥：构造函数会读 DEEPKIT_UPDATE_PUBLIC_KEY_RSA_PEM 环境变量，
  // 测试必须自己决定有/无公钥，不受本机环境左右。
  FAutoUpdate.PublicKeyRSA := '';
end;

procedure TTestIntegrityEnforcement.TearDown;
begin
  FAutoUpdate.Free;
end;

procedure TTestIntegrityEnforcement.Test_DefaultConnectionTimeout;
begin
  Assert.AreEqual(30000, FAutoUpdate.ConnectionTimeout,
    'Default ConnectionTimeout should be 30000ms (30 seconds)');
end;

procedure TTestIntegrityEnforcement.Test_DefaultResponseTimeout;
begin
  Assert.AreEqual(60000, FAutoUpdate.ResponseTimeout,
    'Default ResponseTimeout should be 60000ms (60 seconds)');
end;

procedure TTestIntegrityEnforcement.Test_TimeoutsAreConfigurable;
begin
  FAutoUpdate.ConnectionTimeout := 15000;
  FAutoUpdate.ResponseTimeout := 45000;
  Assert.AreEqual(15000, FAutoUpdate.ConnectionTimeout);
  Assert.AreEqual(45000, FAutoUpdate.ResponseTimeout);
end;

procedure TTestIntegrityEnforcement.Test_DownloadUpdate_FailClosed_NoIntegrityInfo;
var
  Info: TUpdateInfo;
  TempFile: string;
  Ok: Boolean;
begin
  // 三元组（SHA256/签名/公钥）任一缺失 = 下载前 fail-closed 拒绝，不发 HTTP 请求。
  Info := Default(TUpdateInfo);
  Info.DownloadUrl := 'https://example.com/update.exe';
  Info.PackageHash := '';
  Info.Signature := '';

  TempFile := TPath.GetTempFileName;
  try
    Ok := False;
    try
      Ok := FAutoUpdate.DownloadUpdate(Info, TempFile);
    except
      on E: Exception do
        Assert.Fail('Download must be rejected before any request, but raised: ' + E.Message);
    end;
    Assert.IsFalse(Ok,
      'DownloadUpdate must fail closed when integrity triad is incomplete');
    Assert.IsTrue(FAutoUpdate.LastError.Contains('all required (fail-closed)'),
      'LastError should state the triad requirement. Got: ' + FAutoUpdate.LastError);
  finally
    if FileExists(TempFile) then
      DeleteFile(TempFile);
  end;
end;

procedure TTestIntegrityEnforcement.Test_DownloadUpdate_FailClosed_OnlyPackageHash;
var
  Info: TUpdateInfo;
  TempFile: string;
begin
  // 旧弱基线"只有 hash 没有签名"必须翻转拒绝（改法项 (2)，不得变通）。
  Info := Default(TUpdateInfo);
  Info.DownloadUrl := 'https://example.com/update.exe';
  Info.PackageHash := 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
  Info.Signature := '';

  TempFile := TPath.GetTempFileName;
  try
    Assert.IsFalse(FAutoUpdate.DownloadUpdate(Info, TempFile),
      'SHA256 alone must not pass the integrity gate');
    Assert.IsTrue(FAutoUpdate.LastError.Contains('all required (fail-closed)'),
      'Got: ' + FAutoUpdate.LastError);
  finally
    if FileExists(TempFile) then
      DeleteFile(TempFile);
  end;
end;

procedure TTestIntegrityEnforcement.Test_DownloadUpdate_FailClosed_OnlySignature;
var
  Info: TUpdateInfo;
  TempFile: string;
begin
  // 只有签名没有 hash：同样拒绝。
  Info := Default(TUpdateInfo);
  Info.DownloadUrl := 'https://example.com/update.exe';
  Info.PackageHash := '';
  Info.Signature := TestRSASign('anything');

  TempFile := TPath.GetTempFileName;
  try
    Assert.IsFalse(FAutoUpdate.DownloadUpdate(Info, TempFile),
      'Signature alone must not pass the integrity gate');
    Assert.IsTrue(FAutoUpdate.LastError.Contains('all required (fail-closed)'),
      'Got: ' + FAutoUpdate.LastError);
  finally
    if FileExists(TempFile) then
      DeleteFile(TempFile);
  end;
end;

procedure TTestIntegrityEnforcement.Test_DownloadUpdate_FailClosed_NoPublicKey;
var
  Info: TUpdateInfo;
  TempFile: string;
begin
  // hash+签名齐备但未配置公钥：三方缺一仍是 fail-closed。
  Info := Default(TUpdateInfo);
  Info.DownloadUrl := 'https://example.com/update.exe';
  Info.PackageHash := 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
  Info.Signature := TestRSASign(Info.PackageHash);
  FAutoUpdate.PublicKeyRSA := '';

  TempFile := TPath.GetTempFileName;
  try
    Assert.IsFalse(FAutoUpdate.DownloadUpdate(Info, TempFile),
      'Missing configured public key must fail the gate');
    Assert.IsTrue(FAutoUpdate.LastError.Contains('all required (fail-closed)'),
      'Got: ' + FAutoUpdate.LastError);
  finally
    if FileExists(TempFile) then
      DeleteFile(TempFile);
  end;
end;

procedure TTestIntegrityEnforcement.Test_DownloadUpdate_NonHttpsEndpoint_RejectedWithoutRequest;
var
  Info: TUpdateInfo;
  TempFile: string;
begin
  // 改法项 (4)：静态 CDN 通道最低门禁 = https，三元组齐备也不放行 http。
  Info := Default(TUpdateInfo);
  Info.DownloadUrl := 'http://example.com/update.exe';
  Info.PackageHash := 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
  Info.Signature := TestRSASign(Info.PackageHash);
  FAutoUpdate.PublicKeyRSA := TEST_PUBLIC_KEY_PEM;

  TempFile := TPath.GetTempFileName;
  try
    Assert.IsFalse(FAutoUpdate.DownloadUpdate(Info, TempFile),
      'http endpoint must be rejected by scheme gate');
    Assert.IsTrue(FAutoUpdate.LastError.Contains('Download rejected'),
      'Got: ' + FAutoUpdate.LastError);
  finally
    if FileExists(TempFile) then
      DeleteFile(TempFile);
  end;
end;

procedure TTestIntegrityEnforcement.Test_Verify_IntegrityKAT_SignedRawBytes_Approved;
var
  TempFile: string;
  ExpectedHash: string;
  Sig: string;
begin
  // AU-01 正向 KAT：私钥对包"原始字节"单层 SHA256 签名 → 门禁通过。
  // 这是旧双层实现（摘要的摘要）与新单层语义的分叉点，必须有真实往返证据。
  TempFile := TPath.GetTempFileName;
  try
    TFile.WriteAllText(TempFile, 'deepbase-package-payload-v1');
    ExpectedHash := LowerCase(THashSHA2.GetHashStringFromFile(TempFile));
    Sig := TestRSASignFile(TempFile);
    FAutoUpdate.PublicKeyRSA := TEST_PUBLIC_KEY_PEM;

    Assert.IsTrue(FAutoUpdate.VerifyDownloadedPackageIntegrity(TempFile, ExpectedHash, Sig).IsApproved,
      'Valid raw-bytes signature must be approved. Got: ' + FAutoUpdate.LastError);
    Assert.IsTrue(FileExists(TempFile), 'Approved package must be kept on disk');
  finally
    if FileExists(TempFile) then
      DeleteFile(TempFile);
  end;
end;

procedure TTestIntegrityEnforcement.Test_Verify_TamperedPackageAfterSigning_RejectedAndDeleted;
var
  TempFile: string;
  ExpectedHash: string;
  Sig: string;
  Verdict: TGateVerdict;
begin
  TempFile := TPath.GetTempFileName;
  try
    TFile.WriteAllText(TempFile, 'signed-content');
    // 声明侧期望值 = 签名时原始内容的 hash（远端 metadata 给出的原始事实）；
    // 篡改后文件实际 hash 与声明分叉 → SHA256 层先行拒绝并删包。
    ExpectedHash := LowerCase(THashSHA2.GetHashStringFromFile(TempFile));
    Sig := TestRSASignFile(TempFile);
    TFile.WriteAllText(TempFile, 'tampered!!');
    FAutoUpdate.PublicKeyRSA := TEST_PUBLIC_KEY_PEM;

    Verdict := FAutoUpdate.VerifyDownloadedPackageIntegrity(TempFile, ExpectedHash, Sig);
    Assert.AreEqual(gdRejected, Verdict.Decision, 'Tampered hash must be rejected');
    Assert.IsTrue(Verdict.Reason.Contains('SHA256 mismatch'),
      'Got: ' + Verdict.Reason);
    Assert.IsFalse(FileExists(TempFile), 'Rejected package must be deleted (fail-closed)');
  finally
    if FileExists(TempFile) then
      DeleteFile(TempFile);
  end;
end;

procedure TTestIntegrityEnforcement.Test_Verify_ForgedSignature_HashConsistent_Rejected;
var
  TempFile: string;
  Sig: string;
  Verdict: TGateVerdict;
begin
  // hash 与文件一致但签名是攻击者私钥对别的内容签的 → 必须走到 RSA 验签层拒绝。
  TempFile := TPath.GetTempFileName;
  try
    TFile.WriteAllText(TempFile, 'victim-package');
    Sig := TestRSASign('attacker-controlled-hash');
    FAutoUpdate.PublicKeyRSA := TEST_PUBLIC_KEY_PEM;

    Verdict := FAutoUpdate.VerifyDownloadedPackageIntegrity(
      TempFile, LowerCase(THashSHA2.GetHashStringFromFile(TempFile)), Sig);
    Assert.AreEqual(gdRejected, Verdict.Decision, 'Invalid signature must be rejected');
    Assert.IsTrue(Verdict.Reason.Contains('Signature verification failed'),
      'Got: ' + Verdict.Reason);
    Assert.IsFalse(FileExists(TempFile), 'Rejected package must be deleted');
  finally
    if FileExists(TempFile) then
      DeleteFile(TempFile);
  end;
end;

procedure TTestIntegrityEnforcement.Test_Verify_MissingHash_RejectedAndDeleted;
var
  TempFile: string;
  Verdict: TGateVerdict;
begin
  TempFile := TPath.GetTempFileName;
  try
    TFile.WriteAllText(TempFile, 'content');
    FAutoUpdate.PublicKeyRSA := TEST_PUBLIC_KEY_PEM;

    Verdict := FAutoUpdate.VerifyDownloadedPackageIntegrity(TempFile, '', 'some-sig');
    Assert.AreEqual(gdRejected, Verdict.Decision);
    Assert.IsTrue(Verdict.Reason.Contains('package hash is missing'), 'Got: ' + Verdict.Reason);
    Assert.IsFalse(FileExists(TempFile), 'Rejected package must be deleted');
  finally
    if FileExists(TempFile) then
      DeleteFile(TempFile);
  end;
end;

procedure TTestIntegrityEnforcement.Test_Verify_MissingSignature_Rejected;
var
  TempFile: string;
  Verdict: TGateVerdict;
begin
  TempFile := TPath.GetTempFileName;
  try
    TFile.WriteAllText(TempFile, 'content');
    FAutoUpdate.PublicKeyRSA := TEST_PUBLIC_KEY_PEM;

    Verdict := FAutoUpdate.VerifyDownloadedPackageIntegrity(
      TempFile, LowerCase(THashSHA2.GetHashStringFromFile(TempFile)), '');
    Assert.AreEqual(gdRejected, Verdict.Decision);
    Assert.IsTrue(Verdict.Reason.Contains('package signature is missing'), 'Got: ' + Verdict.Reason);
  finally
    if FileExists(TempFile) then
      DeleteFile(TempFile);
  end;
end;

procedure TTestIntegrityEnforcement.Test_Verify_MissingPublicKey_Rejected;
var
  TempFile: string;
  Verdict: TGateVerdict;
begin
  TempFile := TPath.GetTempFileName;
  try
    TFile.WriteAllText(TempFile, 'content');
    FAutoUpdate.PublicKeyRSA := '';

    Verdict := FAutoUpdate.VerifyDownloadedPackageIntegrity(
      TempFile, LowerCase(THashSHA2.GetHashStringFromFile(TempFile)), 'some-sig');
    Assert.AreEqual(gdRejected, Verdict.Decision);
    Assert.IsTrue(Verdict.Reason.Contains('no RSA public key configured'), 'Got: ' + Verdict.Reason);
  finally
    if FileExists(TempFile) then
      DeleteFile(TempFile);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestUpdateInfo);
  TDUnitX.RegisterTestFixture(TTestAutoUpdateClass);
  TDUnitX.RegisterTestFixture(TTestUpdateChannel);
  TDUnitX.RegisterTestFixture(TTestVersionNormalization);
  TDUnitX.RegisterTestFixture(TTestIntegrityEnforcement);

end.
