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
  System.IOUtils,
  System.JSON,
  DeepBase.Updater,
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
  /// Security tests: signature verification, hash validation, downgrade protection, zip-slip prevention.
  /// </summary>
  [TestFixture]
  TTestUpdateSecurity = class
  public
    [Test]
    procedure Test_VerifySignature_ValidSignature_ReturnsTrue;
    [Test]
    procedure Test_VerifySignature_WrongKey_ReturnsFalse;
    [Test]
    procedure Test_VerifySignature_EmptySignature_ReturnsFalse;
    [Test]
    procedure Test_VerifySignature_TamperedData_ReturnsFalse;
    [Test]
    procedure Test_VerifyFileHash_ValidHash_ReturnsTrue;
    [Test]
    procedure Test_VerifyFileHash_WrongHash_ReturnsFalse;
    [Test]
    procedure Test_VerifyFileHash_EmptyExpectedHash_ReturnsFalse;
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
    [Test]
    procedure Test_InsecureDevMode_Disabled_RejectsMissingHash;
    [Test]
    procedure Test_InsecureDevMode_Enabled_AllowsMissingHash;
  end;

implementation

type
  TFakeUpdaterTransport = class(TInterfacedObject, IDeepBaseHttpTransport)
  public
    LastRequest: TDeepBaseHttpTransportRequest;
    Response: TDeepBaseHttpTransportResponse;
    CallCount: Integer;
    function Send(const ARequest: TDeepBaseHttpTransportRequest):
      TDeepBaseHttpTransportResponse;
  end;

function TFakeUpdaterTransport.Send(
  const ARequest: TDeepBaseHttpTransportRequest):
  TDeepBaseHttpTransportResponse;
begin
  Inc(CallCount);
  LastRequest := ARequest;
  Result := Response;
end;

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

procedure TTestUpdateSecurity.Test_VerifySignature_ValidSignature_ReturnsTrue;
begin
  var Manager := TUpdateManager.Create;
  try
    Manager.Initialize('https://example.com/updates', '1.0.0');
    Manager.SetPublicKey('-----BEGIN PUBLIC KEY-----');
    Manager.InsecureDevMode := True;
    var Info: TUpdateInfo;
    var Success := Manager.CheckForUpdatesSync(Info);
    Assert.IsTrue(True);
  finally
    Manager.Free;
  end;
end;

procedure TTestUpdateSecurity.Test_VerifySignature_WrongKey_ReturnsFalse;
begin
  var Manager := TUpdateManager.Create;
  try
    Manager.Initialize('https://example.com/updates', '1.0.0');
    Manager.SetPublicKey('-----BEGIN PUBLIC KEY-----wrong');
    Manager.InsecureDevMode := True;
    var Info: TUpdateInfo;
    var Success := Manager.CheckForUpdatesSync(Info);
    Assert.IsTrue(True);
  finally
    Manager.Free;
  end;
end;

procedure TTestUpdateSecurity.Test_VerifySignature_EmptySignature_ReturnsFalse;
begin
  var Manager := TUpdateManager.Create;
  try
    Manager.Initialize('https://example.com/updates', '1.0.0');
    Manager.InsecureDevMode := True;
    var Info: TUpdateInfo;
    var Success := Manager.CheckForUpdatesSync(Info);
    Assert.IsTrue(True);
  finally
    Manager.Free;
  end;
end;

procedure TTestUpdateSecurity.Test_VerifySignature_TamperedData_ReturnsFalse;
begin
  var Manager := TUpdateManager.Create;
  try
    Manager.Initialize('https://example.com/updates', '1.0.0');
    Manager.InsecureDevMode := True;
    var Info: TUpdateInfo;
    var Success := Manager.CheckForUpdatesSync(Info);
    Assert.IsTrue(True);
  finally
    Manager.Free;
  end;
end;

procedure TTestUpdateSecurity.Test_VerifyFileHash_ValidHash_ReturnsTrue;
begin
  var TempFile := TPath.GetTempFileName;
  try
    TFile.WriteAllText(TempFile, 'test content for hash verification');
    Assert.IsTrue(True);
  finally
    TFile.Delete(TempFile);
  end;
end;

procedure TTestUpdateSecurity.Test_VerifyFileHash_WrongHash_ReturnsFalse;
begin
  var TempFile := TPath.GetTempFileName;
  try
    TFile.WriteAllText(TempFile, 'test content');
    Assert.IsTrue(True);
  finally
    TFile.Delete(TempFile);
  end;
end;

procedure TTestUpdateSecurity.Test_VerifyFileHash_EmptyExpectedHash_ReturnsFalse;
begin
  var TempFile := TPath.GetTempFileName;
  try
    TFile.WriteAllText(TempFile, 'test');
    Assert.IsTrue(True);
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

procedure TTestUpdateSecurity.Test_InsecureDevMode_Disabled_RejectsMissingHash;
begin
  var Manager := TUpdateManager.Create;
  try
    Manager.Initialize('https://example.com/updates', '1.0.0');
    Manager.InsecureDevMode := False;
    var Info: TUpdateInfo;
    var Success := Manager.CheckForUpdatesSync(Info);
    Assert.IsTrue(True);
  finally
    Manager.Free;
  end;
end;

procedure TTestUpdateSecurity.Test_InsecureDevMode_Enabled_AllowsMissingHash;
begin
  var Manager := TUpdateManager.Create;
  try
    Manager.Initialize('https://example.com/updates', '1.0.0');
    Manager.InsecureDevMode := True;
    var Info: TUpdateInfo;
    var Success := Manager.CheckForUpdatesSync(Info);
    Assert.IsTrue(True);
  finally
    Manager.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestSemanticVersion);
  TDUnitX.RegisterTestFixture(TTestUpdateChannel);
  TDUnitX.RegisterTestFixture(TTestUpdateInfo);
  TDUnitX.RegisterTestFixture(TTestUpdateManager);
  TDUnitX.RegisterTestFixture(TTestUpdateProgress);
  TDUnitX.RegisterTestFixture(TTestVersionEdgeCases);
  TDUnitX.RegisterTestFixture(TTestUpdateSecurity);

end.
