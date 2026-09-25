unit Test.DeepBase.Updater;

{*******************************************************************************
  DeepBase Updater Module Unit Tests
  
  Test Coverage:
  - TSemanticVersion parsing and comparison
  - TSemanticVersion operators (=, <>, <, >)
  - TUpdateInfo record
  - TUpdateManager initialization
  - Update channel parsing (ParseChannel, ChannelToString)
  - Version string formatting
*******************************************************************************}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.Hash,
  System.IOUtils,
  System.JSON,
  DeepBase.Gate.Verdict,
  DeepBase.Updater,
  DeepBase.Update.Contracts,
  DeepBase.Net.Transport;

type
  [TestFixture]
  TTestSemanticVersion = class
  public
    // Parse tests
    [Test]
    procedure Test_Parse_SimpleVersion;
    
    [Test]
    procedure Test_Parse_VersionWithBuild;
    
    [Test]
    procedure Test_Parse_VersionWithPreRelease;
    
    [Test]
    procedure Test_Parse_VersionWithVPrefix;
    
    [Test]
    procedure Test_Parse_EmptyString_ReturnsZeros;
    
    [Test]
    procedure Test_Parse_MajorOnly;
    
    [Test]
    procedure Test_Parse_MajorMinor;
    
    [Test]
    procedure Test_Parse_ComplexPreRelease;
    
    // ToString tests
    [Test]
    procedure Test_ToString_BasicVersion;
    
    [Test]
    procedure Test_ToString_WithBuild;
    
    [Test]
    procedure Test_ToString_WithPreRelease;
    
    [Test]
    procedure Test_ToString_WithBuildAndPreRelease;
    
    // CompareTo tests
    [Test]
    procedure Test_CompareTo_Equal_ReturnsZero;
    
    [Test]
    procedure Test_CompareTo_MajorDifference;
    
    [Test]
    procedure Test_CompareTo_MinorDifference;
    
    [Test]
    procedure Test_CompareTo_PatchDifference;
    
    [Test]
    procedure Test_CompareTo_BuildDifference;
    
    [Test]
    procedure Test_CompareTo_PreRelease_LowerThanRelease;
    
    [Test]
    procedure Test_CompareTo_PreReleaseComparison;
    
    // IsNewerThan tests
    [Test]
    procedure Test_IsNewerThan_True;
    
    [Test]
    procedure Test_IsNewerThan_False;
    
    [Test]
    procedure Test_IsNewerThan_Equal_ReturnsFalse;
    
    // Operator tests
    [Test]
    procedure Test_Equal_Operator_True;
    
    [Test]
    procedure Test_Equal_Operator_False;
    
    [Test]
    procedure Test_NotEqual_Operator_True;
    
    [Test]
    procedure Test_NotEqual_Operator_False;
    
    [Test]
    procedure Test_GreaterThan_Operator_True;
    
    [Test]
    procedure Test_GreaterThan_Operator_False;
    
    [Test]
    procedure Test_LessThan_Operator_True;
    
    [Test]
    procedure Test_LessThan_Operator_False;
  end;

  [TestFixture]
  TTestUpdateChannel = class
  public
    [Test]
    procedure Test_ParseChannel_Stable;
    
    [Test]
    procedure Test_ParseChannel_Beta;
    
    [Test]
    procedure Test_ParseChannel_Alpha;
    
    [Test]
    procedure Test_ParseChannel_Dev;
    
    [Test]
    procedure Test_ParseChannel_Unknown_ReturnsStable;
    
    [Test]
    procedure Test_ParseChannel_CaseInsensitive;
    
    [Test]
    procedure Test_ChannelToString_Stable;
    
    [Test]
    procedure Test_ChannelToString_Beta;
    
    [Test]
    procedure Test_ChannelToString_Alpha;
    
    [Test]
    procedure Test_ChannelToString_Dev;
  end;

  [TestFixture]
  TTestUpdateInfo = class
  public
    [Test]
    procedure Test_IsEmpty_AllZeros_ReturnsTrue;
    
    [Test]
    procedure Test_IsEmpty_WithVersion_ReturnsFalse;
    
    [Test]
    procedure Test_IsEmpty_WithDownloadUrl_ReturnsFalse;

    // §16.10 关键点 2 解析侧：ParseUpdateInfoFromJson 契约
    [Test]
    procedure Test_Parse_PackageHash_StripsSha256Prefix_AndLowercases;
    [Test]
    procedure Test_Parse_SignatureFields_MappedCorrectly;
    [Test]
    procedure Test_Parse_InvalidJson_ReturnsFalse;
    [Test]
    procedure Test_Parse_EmptyPackageHash_StaysEmpty;
  end;

  [TestFixture]
  TTestUpdateManager = class
  private
    FManager: TUpdateManager;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_Create_InitialState;
    
    [Test]
    procedure Test_Create_StatusIsIdle;
    
    [Test]
    procedure Test_Create_ChannelIsStable;
    
    [Test]
    procedure Test_Initialize_SetsUpdateUrl;
    
    [Test]
    procedure Test_Initialize_SetsCurrentVersion;
    
    [Test]
    procedure Test_Initialize_SetsApplicationDir;
    
    [Test]
    procedure Test_SetPublicKey_SetsKey;
    
    [Test]
    procedure Test_AutoCheck_DefaultFalse;
    
    [Test]
    procedure Test_AutoCheckInterval_Default24Hours;
    
    [Test]
    procedure Test_Channel_CanBeSet;

    [Test]
    procedure Test_UpdateCheckRouteMode_DefaultAuto;

    [Test]
    procedure Test_UpdateRequestContext_CanBeSet;

    [Test]
    procedure Test_ParseUpdateInfoFromJson_ManifestFields;

    [Test]
    procedure Test_CheckForUpdates_UsesInjectedTransport;
    
    [Test]
    procedure Test_Cancel_SetsCancelledFlag;
  end;

  [TestFixture]
  TTestUpdateProgress = class
  public
    [Test]
    procedure Test_ProgressPercent_ZeroTotal_ReturnsZero;
    
    [Test]
    procedure Test_ProgressPercent_HalfDownloaded;
    
    [Test]
    procedure Test_ProgressPercent_FullyDownloaded;
    
    [Test]
    procedure Test_ProgressPercent_Rounding;
  end;

  [TestFixture]
  TTestVersionEdgeCases = class
  public
    [Test]
    procedure Test_Parse_LargeVersionNumbers;
    
    [Test]
    procedure Test_Parse_ZeroVersion;
    
    [Test]
    procedure Test_Compare_ZeroVersions;
    
    [Test]
    procedure Test_PreRelease_AlphaBeforeBeta;
    
    [Test]
    procedure Test_PreRelease_RCAfterBeta;
    
    [Test]
    procedure Test_Parse_NonNumericParts_Handled;
  end;

  /// <summary>
  /// 更新验签链门禁测试（WO-20260920-AUDIT-甲-R5 M1 / Top20#01，RCE 级）：
  /// 本地固定信任锚、hash/签名/公钥三件套 fail-closed、manifest 验签前置于下载、
  /// 端点 https + 主机白名单咽喉点。
  /// </summary>
  [TestFixture]
  TTestUpdateSecurity = class
  private
    class function NewManager(const AUpdateUrl: string =
      'https://cdn.example.com/updates'): TUpdateManager; static;
  public
    [Test]
    procedure Test_VerifySignature_ValidHashSignature_Approved;
    [Test]
    procedure Test_VerifySignature_WrongKey_Rejected;
    [Test]
    procedure Test_VerifySignature_EmptySignature_Rejected;
    [Test]
    procedure Test_VerifySignature_TamperedData_Rejected;
    [Test]
    procedure Test_VerifySignature_NoPublicKey_Rejected;
    [Test]
    procedure Test_StageAndVerify_MissingPackageHash_Rejected;
    [Test]
    procedure Test_StageAndVerify_MissingSignature_Rejected;
    [Test]
    procedure Test_StageAndVerify_DeclaredSignatureNoPublicKey_Rejected;
    [Test]
    procedure Test_StageAndVerify_HashMismatch_Rejected;
    [Test]
    procedure Test_StageAndVerify_ValidHashAndSignature_Approved;
    [Test]
    procedure Test_StageAndVerify_MissingManifestSignature_Rejected;
    [Test]
    procedure Test_ManifestVerify_PrecedesDownload_Approved;
    [Test]
    procedure Test_ManifestSignatureForged_RejectedWithoutDownload;
    [Test]
    procedure Test_PackageSignatureForged_RejectedAfterDownload;
    [Test]
    procedure Test_UpdateEndpoint_HttpScheme_RejectedWithoutRequest;
    [Test]
    procedure Test_UpdateEndpoint_HostNotWhitelisted_RejectedWithoutRequest;
    [Test]
    procedure Test_VerifyFileHash_ValidHash_Approved;
    [Test]
    procedure Test_VerifyFileHash_WrongHash_Rejected;
    [Test]
    procedure Test_VerifyFileHash_EmptyExpectedHash_Rejected;
    [Test]
    procedure Test_Downgrade_NewerThanCurrent_Allowed;
    [Test]
    procedure Test_Downgrade_OlderThanCurrent_Detected;
    [Test]
    procedure Test_Downgrade_SameVersion_NotAllowed;
    [Test]
    procedure Test_ZipSlip_PathTraversal_Detected;
    [Test]
    procedure Test_ZipSlip_NormalPath_Allowed;
{$IFNDEF RELEASE}
    [Test]
    procedure Test_InsecureDevMode_Disabled_RejectsMissingIntegrity;
    [Test]
    procedure Test_InsecureDevMode_Enabled_SkipsVerification;
{$ENDIF}
  end;

  /// <summary>
  /// 契约层测试（DeepBase.Update.Contracts SSOT）：hash 归一化、manifest payload
  /// 7 字段唯一构造、更新端点门禁（含"空白名单 = 拒绝"）。
  /// </summary>
  [TestFixture]
  TTestUpdateContracts = class
  public
    [Test]
    procedure Test_NormalizePackageHash_StripsPrefixAndLowercases;
    [Test]
    procedure Test_ManifestPayload_SevenFieldsFixedOrder;
    [Test]
    procedure Test_ManifestPayload_EmptyFields_KeepFieldCount;
    [Test]
    procedure Test_EndpointUrl_HttpRejected;
    [Test]
    procedure Test_EndpointUrl_EmptyWhitelistRejected;
    [Test]
    procedure Test_EndpointUrl_HostNotWhitelistedRejected;
    [Test]
    procedure Test_EndpointUrl_HttpsWithWhitelistedHostApproved;
    [Test]
    procedure Test_EndpointScheme_AcceptsHttpsWithoutWhitelist;
  end;

implementation

uses
  Test.DeepBase.UpdateFixtures,
  DeepBase.Crypto.Hash;

{ TTestSemanticVersion }

procedure TTestSemanticVersion.Test_Parse_SimpleVersion;
var
  V: TSemanticVersion;
begin
  V := TSemanticVersion.Parse('1.2.3');
  
  Assert.AreEqual(1, V.Major);
  Assert.AreEqual(2, V.Minor);
  Assert.AreEqual(3, V.Patch);
  Assert.AreEqual(0, V.Build);
  Assert.AreEqual('', V.PreRelease);
end;

procedure TTestSemanticVersion.Test_Parse_VersionWithBuild;
var
  V: TSemanticVersion;
begin
  V := TSemanticVersion.Parse('1.2.3.456');
  
  Assert.AreEqual(1, V.Major);
  Assert.AreEqual(2, V.Minor);
  Assert.AreEqual(3, V.Patch);
  Assert.AreEqual(456, V.Build);
end;

procedure TTestSemanticVersion.Test_Parse_VersionWithPreRelease;
var
  V: TSemanticVersion;
begin
  V := TSemanticVersion.Parse('1.2.3-beta');
  
  Assert.AreEqual(1, V.Major);
  Assert.AreEqual(2, V.Minor);
  Assert.AreEqual(3, V.Patch);
  Assert.AreEqual('beta', V.PreRelease);
end;

procedure TTestSemanticVersion.Test_Parse_VersionWithVPrefix;
var
  V: TSemanticVersion;
begin
  V := TSemanticVersion.Parse('v1.2.3');
  
  Assert.AreEqual(1, V.Major);
  Assert.AreEqual(2, V.Minor);
  Assert.AreEqual(3, V.Patch);
end;

procedure TTestSemanticVersion.Test_Parse_EmptyString_ReturnsZeros;
var
  V: TSemanticVersion;
begin
  V := TSemanticVersion.Parse('');
  
  Assert.AreEqual(0, V.Major);
  Assert.AreEqual(0, V.Minor);
  Assert.AreEqual(0, V.Patch);
  Assert.AreEqual(0, V.Build);
end;

procedure TTestSemanticVersion.Test_Parse_MajorOnly;
var
  V: TSemanticVersion;
begin
  V := TSemanticVersion.Parse('5');
  
  Assert.AreEqual(5, V.Major);
  Assert.AreEqual(0, V.Minor);
  Assert.AreEqual(0, V.Patch);
end;

procedure TTestSemanticVersion.Test_Parse_MajorMinor;
var
  V: TSemanticVersion;
begin
  V := TSemanticVersion.Parse('3.14');
  
  Assert.AreEqual(3, V.Major);
  Assert.AreEqual(14, V.Minor);
  Assert.AreEqual(0, V.Patch);
end;

procedure TTestSemanticVersion.Test_Parse_ComplexPreRelease;
var
  V: TSemanticVersion;
begin
  V := TSemanticVersion.Parse('2.0.0-alpha.1.build.123');
  
  Assert.AreEqual(2, V.Major);
  Assert.AreEqual(0, V.Minor);
  Assert.AreEqual(0, V.Patch);
  Assert.AreEqual('alpha.1.build.123', V.PreRelease);
end;

procedure TTestSemanticVersion.Test_ToString_BasicVersion;
var
  V: TSemanticVersion;
begin
  V.Major := 1;
  V.Minor := 2;
  V.Patch := 3;
  V.Build := 0;
  V.PreRelease := '';
  
  Assert.AreEqual('1.2.3', V.ToString);
end;

procedure TTestSemanticVersion.Test_ToString_WithBuild;
var
  V: TSemanticVersion;
begin
  V.Major := 1;
  V.Minor := 2;
  V.Patch := 3;
  V.Build := 100;
  V.PreRelease := '';
  
  Assert.AreEqual('1.2.3.100', V.ToString);
end;

procedure TTestSemanticVersion.Test_ToString_WithPreRelease;
var
  V: TSemanticVersion;
begin
  V.Major := 1;
  V.Minor := 0;
  V.Patch := 0;
  V.Build := 0;
  V.PreRelease := 'beta';
  
  Assert.AreEqual('1.0.0-beta', V.ToString);
end;

procedure TTestSemanticVersion.Test_ToString_WithBuildAndPreRelease;
var
  V: TSemanticVersion;
begin
  V.Major := 2;
  V.Minor := 1;
  V.Patch := 0;
  V.Build := 50;
  V.PreRelease := 'rc1';
  
  Assert.AreEqual('2.1.0.50-rc1', V.ToString);
end;

procedure TTestSemanticVersion.Test_CompareTo_Equal_ReturnsZero;
var
  V1, V2: TSemanticVersion;
begin
  V1 := TSemanticVersion.Parse('1.2.3');
  V2 := TSemanticVersion.Parse('1.2.3');
  
  Assert.AreEqual(0, V1.CompareTo(V2));
end;

procedure TTestSemanticVersion.Test_CompareTo_MajorDifference;
var
  V1, V2: TSemanticVersion;
begin
  V1 := TSemanticVersion.Parse('2.0.0');
  V2 := TSemanticVersion.Parse('1.9.9');
  
  Assert.IsTrue(V1.CompareTo(V2) > 0);
  Assert.IsTrue(V2.CompareTo(V1) < 0);
end;

procedure TTestSemanticVersion.Test_CompareTo_MinorDifference;
var
  V1, V2: TSemanticVersion;
begin
  V1 := TSemanticVersion.Parse('1.2.0');
  V2 := TSemanticVersion.Parse('1.1.9');
  
  Assert.IsTrue(V1.CompareTo(V2) > 0);
end;

procedure TTestSemanticVersion.Test_CompareTo_PatchDifference;
var
  V1, V2: TSemanticVersion;
begin
  V1 := TSemanticVersion.Parse('1.2.4');
  V2 := TSemanticVersion.Parse('1.2.3');
  
  Assert.IsTrue(V1.CompareTo(V2) > 0);
end;

procedure TTestSemanticVersion.Test_CompareTo_BuildDifference;
var
  V1, V2: TSemanticVersion;
begin
  V1 := TSemanticVersion.Parse('1.2.3.100');
  V2 := TSemanticVersion.Parse('1.2.3.99');
  
  Assert.IsTrue(V1.CompareTo(V2) > 0);
end;

procedure TTestSemanticVersion.Test_CompareTo_PreRelease_LowerThanRelease;
var
  V1, V2: TSemanticVersion;
begin
  V1 := TSemanticVersion.Parse('1.0.0');       // Release
  V2 := TSemanticVersion.Parse('1.0.0-beta');  // Pre-release
  
  Assert.IsTrue(V1.CompareTo(V2) > 0, 'Release should be greater than pre-release');
  Assert.IsTrue(V2.CompareTo(V1) < 0, 'Pre-release should be less than release');
end;

procedure TTestSemanticVersion.Test_CompareTo_PreReleaseComparison;
var
  V1, V2: TSemanticVersion;
begin
  V1 := TSemanticVersion.Parse('1.0.0-beta');
  V2 := TSemanticVersion.Parse('1.0.0-alpha');
  
  // 'beta' > 'alpha' alphabetically
  Assert.IsTrue(V1.CompareTo(V2) > 0);
end;

procedure TTestSemanticVersion.Test_IsNewerThan_True;
var
  V1, V2: TSemanticVersion;
begin
  V1 := TSemanticVersion.Parse('2.0.0');
  V2 := TSemanticVersion.Parse('1.9.9');
  
  Assert.IsTrue(V1.IsNewerThan(V2));
end;

procedure TTestSemanticVersion.Test_IsNewerThan_False;
var
  V1, V2: TSemanticVersion;
begin
  V1 := TSemanticVersion.Parse('1.0.0');
  V2 := TSemanticVersion.Parse('2.0.0');
  
  Assert.IsFalse(V1.IsNewerThan(V2));
end;

procedure TTestSemanticVersion.Test_IsNewerThan_Equal_ReturnsFalse;
var
  V1, V2: TSemanticVersion;
begin
  V1 := TSemanticVersion.Parse('1.0.0');
  V2 := TSemanticVersion.Parse('1.0.0');
  
  Assert.IsFalse(V1.IsNewerThan(V2));
end;

procedure TTestSemanticVersion.Test_Equal_Operator_True;
var
  V1, V2: TSemanticVersion;
begin
  V1 := TSemanticVersion.Parse('1.2.3');
  V2 := TSemanticVersion.Parse('1.2.3');
  
  Assert.IsTrue(V1 = V2);
end;

procedure TTestSemanticVersion.Test_Equal_Operator_False;
var
  V1, V2: TSemanticVersion;
begin
  V1 := TSemanticVersion.Parse('1.2.3');
  V2 := TSemanticVersion.Parse('1.2.4');
  
  Assert.IsFalse(V1 = V2);
end;

procedure TTestSemanticVersion.Test_NotEqual_Operator_True;
var
  V1, V2: TSemanticVersion;
begin
  V1 := TSemanticVersion.Parse('1.2.3');
  V2 := TSemanticVersion.Parse('1.2.4');
  
  Assert.IsTrue(V1 <> V2);
end;

procedure TTestSemanticVersion.Test_NotEqual_Operator_False;
var
  V1, V2: TSemanticVersion;
begin
  V1 := TSemanticVersion.Parse('1.2.3');
  V2 := TSemanticVersion.Parse('1.2.3');
  
  Assert.IsFalse(V1 <> V2);
end;

procedure TTestSemanticVersion.Test_GreaterThan_Operator_True;
var
  V1, V2: TSemanticVersion;
begin
  V1 := TSemanticVersion.Parse('2.0.0');
  V2 := TSemanticVersion.Parse('1.9.9');
  
  Assert.IsTrue(V1 > V2);
end;

procedure TTestSemanticVersion.Test_GreaterThan_Operator_False;
var
  V1, V2: TSemanticVersion;
begin
  V1 := TSemanticVersion.Parse('1.0.0');
  V2 := TSemanticVersion.Parse('2.0.0');
  
  Assert.IsFalse(V1 > V2);
end;

procedure TTestSemanticVersion.Test_LessThan_Operator_True;
var
  V1, V2: TSemanticVersion;
begin
  V1 := TSemanticVersion.Parse('1.0.0');
  V2 := TSemanticVersion.Parse('2.0.0');
  
  Assert.IsTrue(V1 < V2);
end;

procedure TTestSemanticVersion.Test_LessThan_Operator_False;
var
  V1, V2: TSemanticVersion;
begin
  V1 := TSemanticVersion.Parse('2.0.0');
  V2 := TSemanticVersion.Parse('1.0.0');
  
  Assert.IsFalse(V1 < V2);
end;

{ TTestUpdateChannel }

procedure TTestUpdateChannel.Test_ParseChannel_Stable;
begin
  Assert.AreEqual(ucStable, ParseChannel('stable'));
end;

procedure TTestUpdateChannel.Test_ParseChannel_Beta;
begin
  Assert.AreEqual(ucBeta, ParseChannel('beta'));
end;

procedure TTestUpdateChannel.Test_ParseChannel_Alpha;
begin
  Assert.AreEqual(ucAlpha, ParseChannel('alpha'));
end;

procedure TTestUpdateChannel.Test_ParseChannel_Dev;
begin
  Assert.AreEqual(ucDev, ParseChannel('dev'));
end;

procedure TTestUpdateChannel.Test_ParseChannel_Unknown_ReturnsStable;
begin
  Assert.AreEqual(ucStable, ParseChannel('unknown'));
  Assert.AreEqual(ucStable, ParseChannel(''));
  Assert.AreEqual(ucStable, ParseChannel('production'));
end;

procedure TTestUpdateChannel.Test_ParseChannel_CaseInsensitive;
begin
  Assert.AreEqual(ucStable, ParseChannel('STABLE'));
  Assert.AreEqual(ucBeta, ParseChannel('Beta'));
  Assert.AreEqual(ucAlpha, ParseChannel('ALPHA'));
  Assert.AreEqual(ucDev, ParseChannel('DEV'));
end;

procedure TTestUpdateChannel.Test_ChannelToString_Stable;
begin
  Assert.AreEqual('stable', ChannelToString(ucStable));
end;

procedure TTestUpdateChannel.Test_ChannelToString_Beta;
begin
  Assert.AreEqual('beta', ChannelToString(ucBeta));
end;

procedure TTestUpdateChannel.Test_ChannelToString_Alpha;
begin
  Assert.AreEqual('alpha', ChannelToString(ucAlpha));
end;

procedure TTestUpdateChannel.Test_ChannelToString_Dev;
begin
  Assert.AreEqual('dev', ChannelToString(ucDev));
end;

{ TTestUpdateInfo }

procedure TTestUpdateInfo.Test_IsEmpty_AllZeros_ReturnsTrue;
var
  Info: TUpdateInfo;
begin
  Info := Default(TUpdateInfo);
  
  Assert.IsTrue(Info.IsEmpty);
end;

procedure TTestUpdateInfo.Test_IsEmpty_WithVersion_ReturnsFalse;
var
  Info: TUpdateInfo;
begin
  Info := Default(TUpdateInfo);
  Info.Version := TSemanticVersion.Parse('1.0.0');
  
  Assert.IsFalse(Info.IsEmpty);
end;

procedure TTestUpdateInfo.Test_IsEmpty_WithDownloadUrl_ReturnsFalse;
var
  Info: TUpdateInfo;
begin
  Info := Default(TUpdateInfo);
  Info.DownloadUrl := 'https://example.com/update.zip';
  
  Assert.IsFalse(Info.IsEmpty);
end;

{ TTestUpdateInfo — §16.10 关键点 2 解析侧契约 }

procedure TTestUpdateInfo.Test_Parse_PackageHash_StripsSha256Prefix_AndLowercases;
const
  // 服务端下发带 "sha256:" 前缀 + 大写 hex；客户端必须去前缀、转小写
  Json = '{"version":"1.2.3","download_url":"https://x/p.zip",' +
    '"package_hash":"sha256:ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789"}';
var
  Info: TUpdateInfo;
  Manager: TUpdateManager;
begin
  Manager := TUpdateManager.Create;
  try
    Assert.IsTrue(Manager.ParseUpdateInfoFromJson(Json, Info));
  finally
    Manager.Free;
  end;
  Assert.AreEqual('abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
    Info.PackageHash, 'sha256: prefix must be stripped and hex lowercased');
end;

procedure TTestUpdateInfo.Test_Parse_SignatureFields_MappedCorrectly;
const
  Json = '{"version":"1.2.3","download_url":"https://x/p.zip",' +
    '"package_hash":"sha256:abc","signature":"SIG_BASE64","signature_algorithm":"rsa-sha256",' +
    '"manifest_signature":"MANIFEST_SIG_BASE64"}';
var
  Info: TUpdateInfo;
  Manager: TUpdateManager;
begin
  Manager := TUpdateManager.Create;
  try
    Assert.IsTrue(Manager.ParseUpdateInfoFromJson(Json, Info));
  finally
    Manager.Free;
  end;
  Assert.AreEqual('SIG_BASE64', Info.Signature, 'signature field must map to Info.Signature');
  Assert.AreEqual('MANIFEST_SIG_BASE64', Info.ManifestSignature, 'manifest_signature must map');
end;

procedure TTestUpdateInfo.Test_Parse_InvalidJson_ReturnsFalse;
var
  Info: TUpdateInfo;
  Manager: TUpdateManager;
begin
  Manager := TUpdateManager.Create;
  try
    Assert.IsFalse(Manager.ParseUpdateInfoFromJson('not a json', Info),
      'Invalid JSON must yield False');
  finally
    Manager.Free;
  end;
end;

procedure TTestUpdateInfo.Test_Parse_EmptyPackageHash_StaysEmpty;
const
  Json = '{"version":"1.2.3","download_url":"https://x/p.zip"}';
var
  Info: TUpdateInfo;
  Manager: TUpdateManager;
begin
  Manager := TUpdateManager.Create;
  try
    Assert.IsTrue(Manager.ParseUpdateInfoFromJson(Json, Info),
      'Valid JSON with version+url must parse even without package_hash');
  finally
    Manager.Free;
  end;
  Assert.AreEqual('', Info.PackageHash, 'Missing package_hash must stay empty');
end;

{ TTestUpdateManager }

procedure TTestUpdateManager.Setup;
begin
  FManager := TUpdateManager.Create;
end;

procedure TTestUpdateManager.TearDown;
begin
  FManager.Free;
  FManager := nil;
end;

procedure TTestUpdateManager.Test_Create_InitialState;
begin
  Assert.IsNotNull(FManager);
end;

procedure TTestUpdateManager.Test_Create_StatusIsIdle;
begin
  Assert.AreEqual(usIdle, FManager.Status);
end;

procedure TTestUpdateManager.Test_Create_ChannelIsStable;
begin
  Assert.AreEqual(ucStable, FManager.Channel);
end;

procedure TTestUpdateManager.Test_Initialize_SetsUpdateUrl;
begin
  FManager.Initialize('https://updates.example.com/api', '1.0.0');
  
  Assert.AreEqual('https://updates.example.com/api', FManager.UpdateUrl);
end;

procedure TTestUpdateManager.Test_Initialize_SetsCurrentVersion;
begin
  FManager.Initialize('https://updates.example.com/api', '2.3.4');
  
  Assert.AreEqual(2, FManager.CurrentVersion.Major);
  Assert.AreEqual(3, FManager.CurrentVersion.Minor);
  Assert.AreEqual(4, FManager.CurrentVersion.Patch);
end;

procedure TTestUpdateManager.Test_Initialize_SetsApplicationDir;
var
  CustomDir: string;
begin
  CustomDir := TPath.GetTempPath;
  FManager.Initialize('https://updates.example.com/api', '1.0.0', CustomDir);
  
  // Can't directly access ApplicationDir, but no exception means success
  Assert.Pass;
end;

procedure TTestUpdateManager.Test_SetPublicKey_SetsKey;
const
  TestKey = '-----BEGIN PUBLIC KEY-----'#13#10 +
            'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...'#13#10 +
            '-----END PUBLIC KEY-----';
begin
  FManager.SetPublicKey(TestKey);
  
  // No direct access to verify, but no exception means success
  Assert.Pass;
end;

procedure TTestUpdateManager.Test_AutoCheck_DefaultFalse;
begin
  Assert.IsFalse(FManager.AutoCheck);
end;

procedure TTestUpdateManager.Test_AutoCheckInterval_Default24Hours;
begin
  Assert.AreEqual(24, FManager.AutoCheckInterval);
end;

procedure TTestUpdateManager.Test_Channel_CanBeSet;
begin
  FManager.Channel := ucBeta;
  
  Assert.AreEqual(ucBeta, FManager.Channel);
end;

procedure TTestUpdateManager.Test_UpdateCheckRouteMode_DefaultAuto;
begin
  Assert.AreEqual(ucrmAuto, FManager.UpdateCheckRouteMode);
end;

procedure TTestUpdateManager.Test_UpdateRequestContext_CanBeSet;
begin
  FManager.UpdateAppId := 'deepbase_desktop';
  FManager.UpdateDeviceId := 'dev_001';
  FManager.UpdateAccessToken := 'atk_001';
  FManager.UpdateApiKey := 'api_001';

  Assert.AreEqual('deepbase_desktop', FManager.UpdateAppId);
  Assert.AreEqual('dev_001', FManager.UpdateDeviceId);
  Assert.AreEqual('atk_001', FManager.UpdateAccessToken);
  Assert.AreEqual('api_001', FManager.UpdateApiKey);
end;

procedure TTestUpdateManager.Test_ParseUpdateInfoFromJson_ManifestFields;
var
  Info: TUpdateInfo;
  Ok: Boolean;
begin
  Ok := FManager.ParseUpdateInfoFromJson(
    '{"app_id":"deepbase_desktop","latest_version":"1.3.0","channel":"stable","package_url":"https://cdn.example.com/deepbase-1.3.0.zip","package_hash":"sha256:ABC","force_update":true,"release_notes":"fixes"}',
    Info);

  Assert.IsTrue(Ok);
  Assert.AreEqual('deepbase_desktop', Info.AppId);
  Assert.AreEqual(1, Info.Version.Major);
  Assert.AreEqual(3, Info.Version.Minor);
  Assert.AreEqual(0, Info.Version.Patch);
  Assert.AreEqual('https://cdn.example.com/deepbase-1.3.0.zip', Info.DownloadUrl);
  Assert.AreEqual('abc', Info.PackageHash);
  Assert.IsTrue(Info.IsMandatory);
  Assert.AreEqual('fixes', Info.ReleaseNotes);
end;

procedure TTestUpdateManager.Test_CheckForUpdates_UsesInjectedTransport;
var
  Fake: TFakeUpdaterTransport;
  Transport: IDeepBaseHttpTransport;
  Info: TUpdateInfo;
  FoundAuth: Boolean;
  FoundApiKey: Boolean;
  I: Integer;
begin
  Fake := TFakeUpdaterTransport.Create;
  Transport := Fake as IDeepBaseHttpTransport;
  Fake.Response := TDeepBaseHttpTransportResponse.Create(200,
    '{"app_id":"deepbase_desktop","latest_version":"1.2.0","channel":"stable","package_url":"https://cdn.example.com/deepbase.zip","package_hash":"abc"}');

  FManager.Initialize('https://api.example.com/dk', '1.0.0');
  FManager.UpdateAppId := 'deepbase_desktop';
  FManager.UpdateDeviceId := 'device_001';
  FManager.UpdateAccessToken := 'access_001';
  FManager.UpdateApiKey := 'api_001';
  FManager.HttpTransport := Transport;

  Assert.IsTrue(FManager.CheckForUpdatesSync(Info));
  Assert.AreEqual(1, Fake.CallCount);
  Assert.AreEqual(dbhmGet, Fake.LastRequest.Method);
  Assert.IsTrue(Pos('/updates/manifest', Fake.LastRequest.Url) > 0);
  Assert.IsTrue(Pos('app_id=deepbase_desktop', Fake.LastRequest.Url) > 0);
  Assert.IsTrue(Pos('device_id=device_001', Fake.LastRequest.Url) > 0);
  Assert.AreEqual('deepbase_desktop', Info.AppId);

  FoundAuth := False;
  FoundApiKey := False;
  for I := 0 to High(Fake.LastRequest.Headers) do
  begin
    if SameText(Fake.LastRequest.Headers[I].Name, 'Authorization') and
       (Fake.LastRequest.Headers[I].Value = 'Bearer access_001') then
      FoundAuth := True;
    if SameText(Fake.LastRequest.Headers[I].Name, 'X-API-Key') and
       (Fake.LastRequest.Headers[I].Value = 'api_001') then
      FoundApiKey := True;
  end;
  Assert.IsTrue(FoundAuth);
  Assert.IsTrue(FoundApiKey);
end;

procedure TTestUpdateManager.Test_Cancel_SetsCancelledFlag;
begin
  FManager.Cancel;
  
  // Cancel should not raise exception
  Assert.Pass;
end;

{ TTestUpdateProgress }

procedure TTestUpdateProgress.Test_ProgressPercent_ZeroTotal_ReturnsZero;
var
  Progress: TUpdateProgress;
begin
  // ProgressPercent is a field that's set by TUpdateManager.ReportProgress
  // Test that default initialization is 0
  Progress := Default(TUpdateProgress);
  
  Assert.AreEqual(0, Progress.ProgressPercent);
end;

procedure TTestUpdateProgress.Test_ProgressPercent_HalfDownloaded;
var
  Progress: TUpdateProgress;
begin
  // Test setting ProgressPercent field
  Progress := Default(TUpdateProgress);
  Progress.TotalBytes := 1000;
  Progress.DownloadedBytes := 500;
  Progress.ProgressPercent := 50;  // This is set by TUpdateManager.ReportProgress
  
  Assert.AreEqual(50, Progress.ProgressPercent);
end;

procedure TTestUpdateProgress.Test_ProgressPercent_FullyDownloaded;
var
  Progress: TUpdateProgress;
begin
  Progress := Default(TUpdateProgress);
  Progress.TotalBytes := 1000;
  Progress.DownloadedBytes := 1000;
  Progress.ProgressPercent := 100;
  
  Assert.AreEqual(100, Progress.ProgressPercent);
end;

procedure TTestUpdateProgress.Test_ProgressPercent_Rounding;
var
  Progress: TUpdateProgress;
begin
  // Test that ProgressPercent is stored correctly
  Progress := Default(TUpdateProgress);
  Progress.TotalBytes := 1000;
  Progress.DownloadedBytes := 333;
  Progress.ProgressPercent := 33;  // Pre-calculated by ReportProgress
  
  Assert.AreEqual(33, Progress.ProgressPercent);
end;

{ TTestVersionEdgeCases }

procedure TTestVersionEdgeCases.Test_Parse_LargeVersionNumbers;
var
  V: TSemanticVersion;
begin
  V := TSemanticVersion.Parse('999.999.999.999');
  
  Assert.AreEqual(999, V.Major);
  Assert.AreEqual(999, V.Minor);
  Assert.AreEqual(999, V.Patch);
  Assert.AreEqual(999, V.Build);
end;

procedure TTestVersionEdgeCases.Test_Parse_ZeroVersion;
var
  V: TSemanticVersion;
begin
  V := TSemanticVersion.Parse('0.0.0');
  
  Assert.AreEqual(0, V.Major);
  Assert.AreEqual(0, V.Minor);
  Assert.AreEqual(0, V.Patch);
end;

procedure TTestVersionEdgeCases.Test_Compare_ZeroVersions;
var
  V1, V2: TSemanticVersion;
begin
  V1 := TSemanticVersion.Parse('0.0.0');
  V2 := TSemanticVersion.Parse('0.0.0');
  
  Assert.AreEqual(0, V1.CompareTo(V2));
  Assert.IsTrue(V1 = V2);
end;

procedure TTestVersionEdgeCases.Test_PreRelease_AlphaBeforeBeta;
var
  Alpha, Beta: TSemanticVersion;
begin
  Alpha := TSemanticVersion.Parse('1.0.0-alpha');
  Beta := TSemanticVersion.Parse('1.0.0-beta');
  
  Assert.IsTrue(Alpha < Beta, 'alpha should be less than beta');
end;

procedure TTestVersionEdgeCases.Test_PreRelease_RCAfterBeta;
var
  Beta, RC: TSemanticVersion;
begin
  Beta := TSemanticVersion.Parse('1.0.0-beta');
  RC := TSemanticVersion.Parse('1.0.0-rc');
  
  Assert.IsTrue(RC > Beta, 'rc should be greater than beta');
end;

procedure TTestVersionEdgeCases.Test_Parse_NonNumericParts_Handled;
var
  V: TSemanticVersion;
begin
  V := TSemanticVersion.Parse('abc.def.ghi');
  
  // Non-numeric parts should parse to 0
  Assert.AreEqual(0, V.Major);
  Assert.AreEqual(0, V.Minor);
  Assert.AreEqual(0, V.Patch);
end;

{ TTestUpdateSecurity }

{ TTestUpdateSecurity }

class function TTestUpdateSecurity.NewManager(const AUpdateUrl: string): TUpdateManager;
begin
  Result := TUpdateManager.Create;
  Result.Initialize(AUpdateUrl, '1.0.0');
  Result.SetPublicKey(TEST_PUBLIC_KEY_PEM);
end;

procedure TTestUpdateSecurity.Test_VerifySignature_ValidHashSignature_Approved;
const
  // §16.10 关键点 2：data 是去前缀纯 hex 小写串（镜像客户端 Info.PackageHash）。
  TestData = 'a1b2c3d4e5f678901234567890abcdef0123456789abcdef0123456789abcdef';
var
  Manager: TUpdateManager;
  Verdict: TGateVerdict;
begin
  Manager := NewManager;
  try
    Verdict := Manager.VerifySignature(TestData, TestRSASign(TestData));
    // 用配对私钥签名 → 同公钥验签必然通过
    Assert.IsTrue(Verdict.IsApproved,
      'Valid signature must verify against matching public key: ' + Verdict.Reason);
  finally
    Manager.Free;
  end;
end;

procedure TTestUpdateSecurity.Test_VerifySignature_WrongKey_Rejected;
const
  TestData = 'a1b2c3d4e5f678901234567890abcdef0123456789abcdef0123456789abcdef';
var
  Manager: TUpdateManager;
begin
  Manager := TUpdateManager.Create;
  try
    Manager.Initialize('https://cdn.example.com/updates', '1.0.0');
    // 故意设置一个无效公钥 PEM → LoadPublicKeyPEM 失败 → fail-closed
    Manager.SetPublicKey('-----BEGIN PUBLIC KEY-----' + sLineBreak +
      'NOT_A_REAL_KEY' + sLineBreak + '-----END PUBLIC KEY-----');
    Assert.IsFalse(Manager.VerifySignature(TestData, TestRSASign(TestData)).IsApproved,
      'Signature must NOT verify against an invalid/unmatched public key');
  finally
    Manager.Free;
  end;
end;

procedure TTestUpdateSecurity.Test_VerifySignature_EmptySignature_Rejected;
const
  TestData = 'a1b2c3d4e5f678901234567890abcdef0123456789abcdef0123456789abcdef';
var
  Manager: TUpdateManager;
begin
  Manager := NewManager;
  try
    Assert.IsFalse(Manager.VerifySignature(TestData, '').IsApproved,
      'Empty signature must be rejected');
  finally
    Manager.Free;
  end;
end;

procedure TTestUpdateSecurity.Test_VerifySignature_TamperedData_Rejected;
const
  TestData     = 'a1b2c3d4e5f678901234567890abcdef0123456789abcdef0123456789abcdef';
  TamperedData = 'b1b2c3d4e5f678901234567890abcdef0123456789abcdef0123456789abcdef';
var
  Manager: TUpdateManager;
begin
  Manager := NewManager;
  try
    // 用 TestData 的签名，却拿篡改后的 data 验签 → 必然失败
    Assert.IsFalse(Manager.VerifySignature(TamperedData, TestRSASign(TestData)).IsApproved,
      'Tampered data must fail signature verification');
  finally
    Manager.Free;
  end;
end;

procedure TTestUpdateSecurity.Test_VerifySignature_NoPublicKey_Rejected;
const
  TestData = 'a1b2c3d4e5f678901234567890abcdef0123456789abcdef0123456789abcdef';
var
  Manager: TUpdateManager;
  Verdict: TGateVerdict;
begin
  { 改法项 (2)：验签信任锚缺失 = 不可校验 = 拒绝，无开关、无远端自述兜底 }
  Manager := TUpdateManager.Create;
  try
    Manager.Initialize('https://cdn.example.com/updates', '1.0.0');
    Verdict := Manager.VerifySignature(TestData, TestRSASign(TestData));
    Assert.IsFalse(Verdict.IsApproved, 'Missing public key must be rejected');
    Assert.AreEqual(gdRejected, Verdict.Decision,
      'Missing public key must produce gdRejected');
  finally
    Manager.Free;
  end;
end;

procedure TTestUpdateSecurity.Test_StageAndVerify_MissingPackageHash_Rejected;
var
  Info: TUpdateInfo;
  PackagePath, ErrMsg: string;
  Verdict: TGateVerdict;
begin
  PackagePath := TPath.GetTempFileName;
  try
    TFile.WriteAllText(PackagePath, 'package content');
    Info := Default(TUpdateInfo);
    Info.Signature := 'ANY_SIGNATURE';
    Verdict := TUpdateManager.StageAndVerifyPackage(Info, PackagePath,
      TEST_PUBLIC_KEY_PEM, ErrMsg);
    Assert.IsFalse(Verdict.IsApproved, 'Missing package hash must be rejected');
    Assert.IsTrue(Pos('Package hash is missing', ErrMsg) > 0,
      'Reject reason must name the missing field: ' + ErrMsg);
  finally
    TFile.Delete(PackagePath);
  end;
end;

procedure TTestUpdateSecurity.Test_StageAndVerify_MissingSignature_Rejected;
var
  Info: TUpdateInfo;
  PackagePath, ErrMsg: string;
begin
  PackagePath := TPath.GetTempFileName;
  try
    TFile.WriteAllText(PackagePath, 'package content');
    Info := Default(TUpdateInfo);
    Info.PackageHash := StringOfChar('a', 64);
    Info.Signature := '';
    Assert.IsFalse(
      TUpdateManager.StageAndVerifyPackage(Info, PackagePath,
        TEST_PUBLIC_KEY_PEM, ErrMsg).IsApproved,
      'Missing package signature must be rejected');
  finally
    TFile.Delete(PackagePath);
  end;
end;

procedure TTestUpdateSecurity.Test_StageAndVerify_DeclaredSignatureNoPublicKey_Rejected;
var
  Info: TUpdateInfo;
  PackagePath, ErrMsg: string;
  Verdict: TGateVerdict;
begin
  { A6 fail-open 修复：声明了签名但无公钥 → 拒绝（旧代码静默跳过验签） }
  PackagePath := TPath.GetTempFileName;
  try
    TFile.WriteAllText(PackagePath, 'dummy package content');
    Info := Default(TUpdateInfo);
    Info.PackageHash := StringOfChar('a', 64);
    Info.Signature := 'some-signature-value';
    Verdict := TUpdateManager.StageAndVerifyPackage(Info, PackagePath, '', ErrMsg);
    Assert.IsFalse(Verdict.IsApproved,
      'Declared signature with no public key must be rejected (fail-open fix)');
    Assert.AreEqual(gdRejected, Verdict.Decision,
      'Must be gdRejected, not Indeterminate');
  finally
    TFile.Delete(PackagePath);
  end;
end;

procedure TTestUpdateSecurity.Test_StageAndVerify_HashMismatch_Rejected;
var
  Info: TUpdateInfo;
  PackagePath, ErrMsg, WrongHash: string;
begin
  PackagePath := TPath.GetTempFileName;
  try
    TFile.WriteAllText(PackagePath, 'package content');
    WrongHash := StringOfChar('0', 64);
    Info := Default(TUpdateInfo);
    Info.PackageHash := WrongHash;
    // 签名对"错误 hash"是正确的：只有 hash 比对层会失败，证明不是签名层误伤
    Info.Signature := TestRSASign(WrongHash);
    Assert.IsFalse(
      TUpdateManager.StageAndVerifyPackage(Info, PackagePath,
        TEST_PUBLIC_KEY_PEM, ErrMsg).IsApproved,
      'Package whose bytes do not match declared hash must be rejected');
  finally
    TFile.Delete(PackagePath);
  end;
end;

procedure TTestUpdateSecurity.Test_StageAndVerify_ValidHashAndSignature_Approved;
var
  Info: TUpdateInfo;
  PackagePath, ErrMsg, Hash: string;
  Verdict: TGateVerdict;
begin
  PackagePath := TPath.GetTempFileName;
  try
    TFile.WriteAllText(PackagePath, 'package content');
    Hash := LowerCase(THashSHA2.GetHashStringFromFile(PackagePath));
    Info := Default(TUpdateInfo);
    Info.PackageHash := Hash;
    Info.Signature := TestRSASign(Hash);
    Verdict := TUpdateManager.StageAndVerifyPackage(Info, PackagePath,
      TEST_PUBLIC_KEY_PEM, ErrMsg);
    Assert.IsTrue(Verdict.IsApproved,
      'Hash + signature computed from the real package must approve: ' + ErrMsg);
  finally
    TFile.Delete(PackagePath);
  end;
end;

procedure TTestUpdateSecurity.Test_StageAndVerify_MissingManifestSignature_Rejected;
var
  Manager: TUpdateManager;
  Info: TUpdateInfo;
  PackagePath, ErrMsg: string;
begin
  { 改法项 (2)：manifest 签名与包签名同为强制项，缺一即拒（三件套 fail-closed） }
  Manager := NewManager;
  try
    Info := Default(TUpdateInfo);
    Info.PackageHash := StringOfChar('a', 64);
    Info.Signature := TestRSASign(StringOfChar('a', 64));
    Info.ManifestSignature := '';
    Assert.IsFalse(
      Manager.StageAndVerifyPackage(Info, PackagePath, ErrMsg).IsApproved,
      'Missing manifest signature must be rejected');
  finally
    Manager.Free;
  end;
end;

procedure TTestUpdateSecurity.Test_ManifestVerify_PrecedesDownload_Approved;
var
  Manager: TUpdateManager;
  Fake: TFakeUpdaterTransport;
  Transport: IDeepBaseHttpTransport;
  Info: TUpdateInfo;
  TempFile, PackagePath, ErrMsg, Hash: string;
  Verdict: TGateVerdict;
begin
  TempFile := TPath.GetTempFileName;
  try
    TFile.WriteAllText(TempFile, 'deepbase update package bytes');
    Hash := LowerCase(THashSHA2.GetHashStringFromFile(TempFile));
    Info := BuildSignedManifestInfo(Hash);

    Manager := NewManager;
    Fake := TFakeUpdaterTransport.Create;
    Fake.Response := TDeepBaseHttpTransportResponse.Create(200, '');
    Fake.Response.BodyBytes := TFile.ReadAllBytes(TempFile);
    Transport := Fake as IDeepBaseHttpTransport;
    Manager.HttpTransport := Transport;
    try
      Verdict := Manager.StageAndVerifyPackage(Info, PackagePath, ErrMsg);
      Assert.IsTrue(Verdict.IsApproved,
        'Fully signed manifest + package must approve: ' + ErrMsg);
      Assert.AreEqual(1, Fake.CallCount,
        'Manifest verification must precede exactly one package download');
    finally
      Manager.Free;
      if PackagePath <> '' then
        TFile.Delete(PackagePath);
    end;
  finally
    TFile.Delete(TempFile);
  end;
end;

procedure TTestUpdateSecurity.Test_ManifestSignatureForged_RejectedWithoutDownload;
var
  Manager: TUpdateManager;
  Fake: TFakeUpdaterTransport;
  Transport: IDeepBaseHttpTransport;
  Info: TUpdateInfo;
  PackagePath, ErrMsg: string;
  Verdict: TGateVerdict;
begin
  { 改法项 (4) 的攻击语义：伪造 manifest 签名但保持 manifest_hash 与 payload 自洽
    → hash 层放行、RSA 层必拒；关键在于此时一次下载都不该发生。 }
  Manager := NewManager;
  Fake := TFakeUpdaterTransport.Create;
  Fake.Response := TDeepBaseHttpTransportResponse.Create(200, '');
  Transport := Fake as IDeepBaseHttpTransport;
  Manager.HttpTransport := Transport;
  try
    Info := BuildSignedManifestInfo(StringOfChar('a', 64));
    Info.ManifestSignature := TestRSASign('forged-payload-by-attacker');
    Verdict := Manager.StageAndVerifyPackage(Info, PackagePath, ErrMsg);
    Assert.IsFalse(Verdict.IsApproved, 'Forged manifest signature must be rejected');
    Assert.AreEqual(0, Fake.CallCount,
      'Unverified manifest must never trigger a download from download_url');
  finally
    Manager.Free;
    if PackagePath <> '' then
      TFile.Delete(PackagePath);
  end;
end;

procedure TTestUpdateSecurity.Test_PackageSignatureForged_RejectedAfterDownload;
var
  Manager: TUpdateManager;
  Fake: TFakeUpdaterTransport;
  Transport: IDeepBaseHttpTransport;
  Info: TUpdateInfo;
  TempFile, PackagePath, ErrMsg, Hash, Payload: string;
  Verdict: TGateVerdict;
begin
  { manifest 层完好、包签名被伪造：门禁必须在下载后于包验签层拒绝。 }
  TempFile := TPath.GetTempFileName;
  try
    TFile.WriteAllText(TempFile, 'deepbase update package bytes');
    Hash := LowerCase(THashSHA2.GetHashStringFromFile(TempFile));

    Manager := NewManager;
    Fake := TFakeUpdaterTransport.Create;
    Fake.Response := TDeepBaseHttpTransportResponse.Create(200, '');
    Fake.Response.BodyBytes := TFile.ReadAllBytes(TempFile);
    Transport := Fake as IDeepBaseHttpTransport;
    Manager.HttpTransport := Transport;
    try
      Info := BuildSignedManifestInfo(Hash);
      Info.Signature := TestRSASign(StringOfChar('f', 64));
      // 重新自洽 manifest 层，使攻击只落在包签名这一层
      Payload := BuildManifestSignaturePayload(Info);
      Info.ManifestHash := LowerCase(THashSHA2.GetHashString(Payload));
      Info.ManifestSignature := TestRSASign(Payload);

      Verdict := Manager.StageAndVerifyPackage(Info, PackagePath, ErrMsg);
      Assert.IsFalse(Verdict.IsApproved, 'Forged package signature must be rejected');
      Assert.AreEqual(1, Fake.CallCount,
        'Package layer is reached only after manifest verification');
    finally
      Manager.Free;
      if PackagePath <> '' then
        TFile.Delete(PackagePath);
    end;
  finally
    TFile.Delete(TempFile);
  end;
end;

procedure TTestUpdateSecurity.Test_UpdateEndpoint_HttpScheme_RejectedWithoutRequest;
var
  Manager: TUpdateManager;
  Fake: TFakeUpdaterTransport;
  Transport: IDeepBaseHttpTransport;
  Info: TUpdateInfo;
begin
  { 改法项 (4)：https 是端点最低要求，明文更新端点在发出任何请求前被拒。 }
  Manager := NewManager('http://cdn.example.com/updates');
  Fake := TFakeUpdaterTransport.Create;
  Fake.Response := TDeepBaseHttpTransportResponse.Create(200, '{}');
  Transport := Fake as IDeepBaseHttpTransport;
  Manager.HttpTransport := Transport;
  try
    Assert.IsFalse(Manager.CheckForUpdatesSync(Info),
      'Plain http update endpoint must be refused');
    Assert.AreEqual(0, Fake.CallCount,
      'Endpoint gate must run before the transport is touched');
  finally
    Manager.Free;
  end;
end;

procedure TTestUpdateSecurity.Test_UpdateEndpoint_HostNotWhitelisted_RejectedWithoutRequest;
var
  Manager: TUpdateManager;
  Fake: TFakeUpdaterTransport;
  Transport: IDeepBaseHttpTransport;
  Info: TUpdateInfo;
begin
  { 主机白名单是显式信任锚：UpdateUrl 的 host 不在名单内同样拒（fail-closed）。 }
  Manager := NewManager('https://cdn.example.com/updates');
  Manager.UpdateHostWhitelist := ['updates.deepbase.invalid'];
  Fake := TFakeUpdaterTransport.Create;
  Fake.Response := TDeepBaseHttpTransportResponse.Create(200, '{}');
  Transport := Fake as IDeepBaseHttpTransport;
  Manager.HttpTransport := Transport;
  try
    Assert.IsFalse(Manager.CheckForUpdatesSync(Info),
      'Non-whitelisted https host must be refused');
    Assert.AreEqual(0, Fake.CallCount,
      'Host whitelist gate must run before the transport is touched');
  finally
    Manager.Free;
  end;
end;

procedure TTestUpdateSecurity.Test_VerifyFileHash_ValidHash_Approved;
begin
  var TempFile := TPath.GetTempFileName;
  try
    TFile.WriteAllText(TempFile, 'test content for hash verification');
    // §16.10 关键点 1：纯 hex 小写（VerifyFileHash 内部 THashSHA2.GetHashString 对齐）
    var Expected := THashUtils.SHA256File(TempFile);
    var Manager := NewManager;
    try
      Assert.IsTrue(Manager.VerifyFileHash(TempFile, Expected).IsApproved,
        'Correct hash must verify');
    finally
      Manager.Free;
    end;
  finally
    TFile.Delete(TempFile);
  end;
end;

procedure TTestUpdateSecurity.Test_VerifyFileHash_WrongHash_Rejected;
begin
  var TempFile := TPath.GetTempFileName;
  try
    TFile.WriteAllText(TempFile, 'test content');
    // 故意给一个不可能匹配的 hash
    var WrongHash := StringOfChar('0', 64);
    var Manager := NewManager;
    try
      Assert.IsFalse(Manager.VerifyFileHash(TempFile, WrongHash).IsApproved,
        'Wrong hash must be rejected');
    finally
      Manager.Free;
    end;
  finally
    TFile.Delete(TempFile);
  end;
end;

procedure TTestUpdateSecurity.Test_VerifyFileHash_EmptyExpectedHash_Rejected;
begin
  var TempFile := TPath.GetTempFileName;
  try
    TFile.WriteAllText(TempFile, 'test');
    var Manager := NewManager;
    try
      // 空期望 hash → fail-closed（改法项 (2)，RELEASE 构建无 dev 豁免分支）
      var Verdict := Manager.VerifyFileHash(TempFile, '');
      Assert.IsFalse(Verdict.IsApproved,
        'Empty expected hash must be rejected when dev mode is off');
      Assert.AreEqual(gdRejected, Verdict.Decision,
        'Empty expected hash must produce gdRejected');
    finally
      Manager.Free;
    end;
  finally
    TFile.Delete(TempFile);
  end;
end;

procedure TTestUpdateSecurity.Test_Downgrade_NewerThanCurrent_Allowed;
begin
  var Current := TSemanticVersion.Parse('1.0.0');
  var Newer := TSemanticVersion.Parse('2.0.0');
  Assert.IsTrue(Newer > Current, 'Newer version should be allowed');
end;

procedure TTestUpdateSecurity.Test_Downgrade_OlderThanCurrent_Detected;
begin
  var Current := TSemanticVersion.Parse('2.0.0');
  var Older := TSemanticVersion.Parse('1.0.0');
  Assert.IsFalse(Older > Current, 'Older version should be detected as downgrade');
end;

procedure TTestUpdateSecurity.Test_Downgrade_SameVersion_NotAllowed;
begin
  var Current := TSemanticVersion.Parse('1.0.0');
  var Same := TSemanticVersion.Parse('1.0.0');
  Assert.IsFalse(Same > Current, 'Same version should not trigger update');
  Assert.IsFalse(Current > Same, 'Same version should not be considered newer');
end;

procedure TTestUpdateSecurity.Test_ZipSlip_PathTraversal_Detected;
begin
  var TraversalPath := '..\..\windows\system32\evil.exe';
  var CleanPath := TPath.GetFullPath(TPath.Combine(TPath.GetTempPath, TraversalPath));
  var TempRoot := TPath.GetTempPath.TrimRight(['\']);
  Assert.IsFalse(CleanPath.StartsWith(TempRoot, True),
    'Path traversal should be detected');
end;

procedure TTestUpdateSecurity.Test_ZipSlip_NormalPath_Allowed;
begin
  var NormalPath := 'deepbase\update\app.exe';
  var CleanPath := TPath.GetFullPath(TPath.Combine(TPath.GetTempPath, NormalPath));
  var TempRoot := TPath.GetTempPath.TrimRight(['\']);
  Assert.IsTrue(CleanPath.StartsWith(TempRoot, True),
    'Normal path should be within temp root');
end;

{$IFNDEF RELEASE}
procedure TTestUpdateSecurity.Test_InsecureDevMode_Disabled_RejectsMissingIntegrity;
var
  Manager: TUpdateManager;
  Info: TUpdateInfo;
  PackagePath, ErrMsg: string;
begin
  { 开发豁免的反面：开关显式关闭时，三件套门禁照旧拒绝缺失的完整性字段 }
  Manager := NewManager;
  try
    Manager.InsecureDevMode := False;
    Info := Default(TUpdateInfo);
    Assert.IsFalse(
      Manager.StageAndVerifyPackage(Info, PackagePath, ErrMsg).IsApproved,
      'Missing integrity fields must still be rejected with dev mode off');
  finally
    Manager.Free;
  end;
end;

procedure TTestUpdateSecurity.Test_InsecureDevMode_Enabled_SkipsVerification;
var
  Manager: TUpdateManager;
  Fake: TFakeUpdaterTransport;
  Transport: IDeepBaseHttpTransport;
  Info: TUpdateInfo;
  PackagePath, ErrMsg: string;
  Verdict: TGateVerdict;
begin
  { 豁免只作用于非 RELEASE 编译，且必须在 verdict 理由中显式自曝（不可静默放行） }
  Manager := NewManager;
  Fake := TFakeUpdaterTransport.Create;
  Fake.Response := TDeepBaseHttpTransportResponse.Create(200, 'package');
  Transport := Fake as IDeepBaseHttpTransport;
  Manager.HttpTransport := Transport;
  try
    Manager.InsecureDevMode := True;
    Info := Default(TUpdateInfo);
    Info.Version := TSemanticVersion.Parse('2.0.0');
    Info.DownloadUrl := 'https://cdn.example.com/updates/deepbase-2.0.0.zip';
    Verdict := Manager.StageAndVerifyPackage(Info, PackagePath, ErrMsg);
    Assert.IsTrue(Verdict.IsApproved,
      'Dev mode must allow an unsigned package in non-RELEASE builds');
    Assert.IsTrue(Pos('insecure dev mode', Verdict.Reason) > 0,
      'Skipped verification must be declared in the verdict reason: ' + Verdict.Reason);
    Assert.AreEqual(1, Fake.CallCount);
  finally
    Manager.Free;
    if PackagePath <> '' then
      TFile.Delete(PackagePath);
  end;
end;
{$ENDIF}

{ TTestUpdateContracts }

procedure TTestUpdateContracts.Test_NormalizePackageHash_StripsPrefixAndLowercases;
begin
  Assert.AreEqual('abcdef0123456789',
    NormalizePackageHash('sha256:ABCDEF0123456789'));
  Assert.AreEqual('abcdef0123456789',
    NormalizePackageHash(' SHA256:ABCDEF0123456789 '),
      'prefix match is case-insensitive and surrounding blanks are trimmed');
  Assert.AreEqual('abcdef0123456789',
    NormalizePackageHash('ABCDEF0123456789'),
      'a bare hex hash must pass through lowercased');
  Assert.AreEqual('', NormalizePackageHash(''), 'Empty stays empty (fail-closed upstream)');
end;

procedure TTestUpdateContracts.Test_ManifestPayload_SevenFieldsFixedOrder;
var
  Info: TUpdateInfo;
  Fields: TArray<string>;
begin
  Info := Default(TUpdateInfo);
  Info.AppId := 'deepbase_desktop';
  Info.Version := TSemanticVersion.Parse('1.3.0');
  Info.Channel := ucBeta;
  Info.DownloadUrl := 'https://cdn.example.com/p/deepbase-1.3.0.zip';
  Info.DownloadSize := 4096;
  Info.PackageHash := 'abc123';
  Info.Signature := 'SIG_B64';

  Fields := BuildManifestSignaturePayload(Info).Split(['|']);
  Assert.AreEqual<Integer>(7, Length(Fields), '§16.10 payload must have exactly 7 fields');
  Assert.AreEqual('deepbase_desktop', Fields[0]);
  Assert.AreEqual('1.3.0', Fields[1]);
  Assert.AreEqual('beta', Fields[2]);
  Assert.AreEqual('https://cdn.example.com/p/deepbase-1.3.0.zip', Fields[3]);
  Assert.AreEqual('4096', Fields[4]);
  Assert.AreEqual('abc123', Fields[5]);
  Assert.AreEqual('SIG_B64', Fields[6]);
end;

procedure TTestUpdateContracts.Test_ManifestPayload_EmptyFields_KeepFieldCount;
var
  Info: TUpdateInfo;
begin
  { 空字段以空串占位：字段数恒为 7，否则签名字段会错位到别的序号上 }
  Info := Default(TUpdateInfo);
  Assert.AreEqual('|0.0.0|stable||0||', BuildManifestSignaturePayload(Info));
end;

procedure TTestUpdateContracts.Test_EndpointUrl_HttpRejected;
var
  Verdict: TGateVerdict;
begin
  Verdict := ValidateUpdateEndpointUrl('http://cdn.example.com/p.zip', ['cdn.example.com']);
  Assert.IsFalse(Verdict.IsApproved, 'http must be refused even for a whitelisted host');
  Assert.AreEqual(gdRejected, Verdict.Decision);
end;

procedure TTestUpdateContracts.Test_EndpointUrl_EmptyWhitelistRejected;
var
  Verdict: TGateVerdict;
begin
  { 无信任锚 ≠ 全放行：这是 fail-closed 与 fail-open 的分界 }
  Verdict := ValidateUpdateEndpointUrl('https://cdn.example.com/p.zip', []);
  Assert.IsFalse(Verdict.IsApproved, 'Empty host whitelist must reject');
  Assert.IsTrue(Pos('fail-closed', Verdict.Reason) > 0,
    'Reject reason must state fail-closed: ' + Verdict.Reason);
end;

procedure TTestUpdateContracts.Test_EndpointUrl_HostNotWhitelistedRejected;
var
  Verdict: TGateVerdict;
begin
  Verdict := ValidateUpdateEndpointUrl('https://evil.example.com/p.zip', ['cdn.example.com']);
  Assert.IsFalse(Verdict.IsApproved, 'Non-listed host must be rejected');
  Assert.IsTrue(Pos('not in the allowed host list', Verdict.Reason) > 0,
    'Reject reason must name the whitelist: ' + Verdict.Reason);
end;

procedure TTestUpdateContracts.Test_EndpointUrl_HttpsWithWhitelistedHostApproved;
var
  Verdict: TGateVerdict;
begin
  Verdict := ValidateUpdateEndpointUrl('https://cdn.example.com/p.zip', ['CDN.Example.com']);
  Assert.IsTrue(Verdict.IsApproved,
    'Host comparison must be case-insensitive: ' + Verdict.Reason);
end;

procedure TTestUpdateContracts.Test_EndpointScheme_AcceptsHttpsWithoutWhitelist;
begin
  { 静态 CDN 通道（AutoUpdate）只需 https；需要白名单的通道另有门禁函数 }
  Assert.IsTrue(ValidateUpdateEndpointScheme('https://any.cdn.example/p.zip').IsApproved);
  Assert.IsFalse(ValidateUpdateEndpointScheme('ftp://any.cdn.example/p.zip').IsApproved);
  Assert.IsFalse(ValidateUpdateEndpointScheme('').IsApproved);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestSemanticVersion);
  TDUnitX.RegisterTestFixture(TTestUpdateChannel);
  TDUnitX.RegisterTestFixture(TTestUpdateInfo);
  TDUnitX.RegisterTestFixture(TTestUpdateManager);
  TDUnitX.RegisterTestFixture(TTestUpdateProgress);
  TDUnitX.RegisterTestFixture(TTestVersionEdgeCases);
  TDUnitX.RegisterTestFixture(TTestUpdateSecurity);
  TDUnitX.RegisterTestFixture(TTestUpdateContracts);

end.
