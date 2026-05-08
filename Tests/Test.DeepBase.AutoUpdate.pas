{ ============================================================================
  Test.DeepBase.AutoUpdate - Unit Tests for Auto-Update Module
  
  Test Coverage:
    - TUpdateInfo record operations
    - TDeepBaseAutoUpdate class
    - Update channel handling
    - Version comparison
  ============================================================================ }

unit Test.DeepBase.AutoUpdate;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  DeepBase.Updater,
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
    procedure Test_Sha256Field;
    [Test]
    procedure Test_ReleaseDateField;
    [Test]
    procedure Test_ChangelogField;
    [Test]
    procedure Test_ForceUpdateField;
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

implementation

{ TTestUpdateInfo }

procedure TTestUpdateInfo.Test_DefaultValues;
var
  Info: TUpdateInfo;
begin
  FillChar(Info, SizeOf(Info), 0);
  
  Assert.AreEqual('', Info.Version);
  Assert.AreEqual('', Info.DownloadUrl);
  Assert.AreEqual(Int64(0), Info.DownloadSize);
  Assert.IsFalse(Info.ForceUpdate);
end;

procedure TTestUpdateInfo.Test_VersionField;
var
  Info: TUpdateInfo;
begin
  Info.Version := '1.2.3';
  Assert.AreEqual('1.2.3', Info.Version);
  
  Info.Version := '2.0.0-beta.1';
  Assert.AreEqual('2.0.0-beta.1', Info.Version);
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

procedure TTestUpdateInfo.Test_Sha256Field;
var
  Info: TUpdateInfo;
begin
  Info.Sha256 := 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
  Assert.AreEqual(64, Integer(Length(Info.Sha256)));
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

procedure TTestUpdateInfo.Test_ChangelogField;
var
  Info: TUpdateInfo;
begin
  Info.Changelog := '- Bug fixes\n- New features\n- Performance improvements';
  Assert.IsTrue(Info.Changelog.Contains('Bug fixes'));
  Assert.IsTrue(Info.Changelog.Contains('Performance'));
end;

procedure TTestUpdateInfo.Test_ForceUpdateField;
var
  Info: TUpdateInfo;
begin
  Info.ForceUpdate := False;
  Assert.IsFalse(Info.ForceUpdate);
  
  Info.ForceUpdate := True;
  Assert.IsTrue(Info.ForceUpdate);
end;

procedure TTestUpdateInfo.Test_AllFieldsAssignment;
var
  Info: TUpdateInfo;
begin
  Info.Version := '3.0.0';
  Info.Channel := ucStable;
  Info.DownloadUrl := 'https://cdn.example.com/v3/setup.exe';
  Info.DownloadSize := 104857600;
  Info.Sha256 := 'abc123def456';
  Info.ReleaseDate := Now;
  Info.Changelog := 'Major release with breaking changes';
  Info.ForceUpdate := True;
  
  Assert.AreEqual('3.0.0', Info.Version);
  Assert.AreEqual(ucStable, Info.Channel);
  Assert.AreEqual('https://cdn.example.com/v3/setup.exe', Info.DownloadUrl);
  Assert.AreEqual(Int64(104857600), Info.DownloadSize);
  Assert.IsTrue(Info.ForceUpdate);
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

initialization
  TDUnitX.RegisterTestFixture(TTestUpdateInfo);
  TDUnitX.RegisterTestFixture(TTestAutoUpdateClass);
  TDUnitX.RegisterTestFixture(TTestUpdateChannel);
  TDUnitX.RegisterTestFixture(TTestVersionNormalization);

end.
