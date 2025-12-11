{ ============================================================================
  Test.UniBase.PublishConfig - Unit Tests for Publish Configuration
  
  Tests:
    - TPublishConfig serialization/deserialization
    - TVersionManifest generation (new and legacy formats)
    - TPublishConfigMRU functionality
    - AutoUpdate format detection and compatibility
  ============================================================================ }

unit Test.UniBase.PublishConfig;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.JSON,
  Publisher.Config,
  Publisher.Manifest;

type
  [TestFixture]
  TTestPublishConfig = class
  private
    FConfig: TPublishConfig;
    FTempDir: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_DefaultConfig_HasDefaultPatterns;
    
    [Test]
    procedure Test_ToJSONString_ProducesValidJSON;
    
    [Test]
    procedure Test_FromJSONString_ParsesCorrectly;
    
    [Test]
    procedure Test_SaveAndLoad_RoundTrip;
    
    [Test]
    procedure Test_Validate_RequiresAppId;
    
    [Test]
    procedure Test_Validate_RequiresAppName;
    
    [Test]
    procedure Test_GetDefaultPackageName_FormatsCorrectly;
  end;

  [TestFixture]
  TTestVersionManifest = class
  private
    FTempDir: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_NewFormat_ToJSONString_HasRequiredFields;
    
    [Test]
    procedure Test_NewFormat_FromJSON_ParsesCorrectly;
    
    [Test]
    procedure Test_LegacyFormat_HasChannelObjects;
    
    [Test]
    procedure Test_IsNewFormat_DetectsNewFormat;
    
    [Test]
    procedure Test_IsNewFormat_DetectsLegacyFormat;
    
    [Test]
    procedure Test_SaveToFile_CreatesFile;
    
    [Test]
    procedure Test_CreateFileEntry_ComputesHash;
  end;

  [TestFixture]
  TTestPublishConfigMRU = class
  private
    FMRU: TPublishConfigMRU;
    FTempFile: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_Add_InsertsAtFront;
    
    [Test]
    procedure Test_Add_MovesExistingToFront;
    
    [Test]
    procedure Test_Add_RespectsMaxItems;
    
    [Test]
    procedure Test_Remove_DeletesItem;
    
    [Test]
    procedure Test_GetMostRecent_ReturnsFirst;
    
    [Test]
    procedure Test_Clear_RemovesAllItems;
    
    [Test]
    procedure Test_Persistence_SavesAndLoads;
  end;

  [TestFixture]
  TTestAutoUpdateFormatDetection = class
  public
    [Test]
    procedure Test_NewFormatJSON_HasAppIdAndFiles;
    
    [Test]
    procedure Test_LegacyFormatJSON_HasChannelObjects;
    
    [Test]
    procedure Test_ParseNewFormat_ExtractsVersion;
    
    [Test]
    procedure Test_ParseLegacyFormat_ExtractsVersion;
  end;

implementation

{ TTestPublishConfig }

procedure TTestPublishConfig.Setup;
begin
  FConfig := TPublishConfig.Create;
  FTempDir := TPath.Combine(TPath.GetTempPath, 'UniBaseTests_' + TGUID.NewGuid.ToString);
  ForceDirectories(FTempDir);
end;

procedure TTestPublishConfig.TearDown;
begin
  FConfig.Free;
  if TDirectory.Exists(FTempDir) then
    TDirectory.Delete(FTempDir, True);
end;

procedure TTestPublishConfig.Test_DefaultConfig_HasDefaultPatterns;
begin
  Assert.IsTrue(Length(FConfig.PackageLayout.IncludePatterns) > 0, 
    'Should have default include patterns');
  Assert.IsTrue(Length(FConfig.PackageLayout.ExcludePatterns) > 0, 
    'Should have default exclude patterns');
end;

procedure TTestPublishConfig.Test_ToJSONString_ProducesValidJSON;
var
  JsonStr: string;
  Root: TJSONObject;
begin
  FConfig.AppId := 'com.test.app';
  FConfig.AppName := 'TestApp';
  
  JsonStr := FConfig.ToJSONString;
  Assert.IsNotEmpty(JsonStr, 'JSON string should not be empty');
  
  Root := TJSONObject.ParseJSONValue(JsonStr) as TJSONObject;
  try
    Assert.IsNotNull(Root, 'Should produce valid JSON');
    Assert.AreEqual('com.test.app', Root.GetValue<string>('appId'));
    Assert.AreEqual('TestApp', Root.GetValue<string>('appName'));
  finally
    Root.Free;
  end;
end;

procedure TTestPublishConfig.Test_FromJSONString_ParsesCorrectly;
const
  TestJSON = '{"appId":"com.test.myapp","appName":"MyApp","displayName":"My Application",' +
             '"dproj":"C:\\Projects\\MyApp.dproj","outputDir":"C:\\Projects\\Release",' +
             '"packageLayout":{"includePatterns":["*.exe"],"excludePatterns":["*.dcu"]},' +
             '"publishTargets":{"http":{"enabled":true,"uploadUrl":"https://example.com"},' +
             '"github":{"enabled":false},"gitee":{"enabled":false}},"metadata":{}}';
begin
  Assert.IsTrue(FConfig.FromJSONString(TestJSON), 'Should parse valid JSON');
  Assert.AreEqual('com.test.myapp', FConfig.AppId);
  Assert.AreEqual('MyApp', FConfig.AppName);
  Assert.AreEqual('My Application', FConfig.DisplayName);
  Assert.AreEqual('C:\Projects\MyApp.dproj', FConfig.Dproj);
  Assert.IsTrue(FConfig.PublishTargets.Http.Enabled, 'HTTP should be enabled');
end;

procedure TTestPublishConfig.Test_SaveAndLoad_RoundTrip;
var
  FilePath: string;
  LoadedConfig: TPublishConfig;
begin
  FilePath := TPath.Combine(FTempDir, 'test.publish.json');
  
  FConfig.AppId := 'com.roundtrip.test';
  FConfig.AppName := 'RoundTripTest';
  FConfig.DisplayName := 'Round Trip Test';
  FConfig.Dproj := 'D:\Test\Test.dproj';
  FConfig.OutputDir := 'D:\Test\Release';
  FConfig.PublishTargets.GitHub.Enabled := True;
  FConfig.PublishTargets.GitHub.Owner := 'testowner';
  FConfig.PublishTargets.GitHub.Repo := 'testrepo';
  
  Assert.IsTrue(FConfig.SaveToFile(FilePath), 'Should save successfully');
  Assert.IsTrue(TFile.Exists(FilePath), 'File should exist');
  
  LoadedConfig := TPublishConfig.Create;
  try
    Assert.IsTrue(LoadedConfig.LoadFromFile(FilePath), 'Should load successfully');
    Assert.AreEqual(FConfig.AppId, LoadedConfig.AppId);
    Assert.AreEqual(FConfig.AppName, LoadedConfig.AppName);
    Assert.AreEqual(FConfig.DisplayName, LoadedConfig.DisplayName);
    Assert.AreEqual(FConfig.PublishTargets.GitHub.Owner, LoadedConfig.PublishTargets.GitHub.Owner);
  finally
    LoadedConfig.Free;
  end;
end;

procedure TTestPublishConfig.Test_Validate_RequiresAppId;
var
  ErrorMsg: string;
begin
  FConfig.AppName := 'Test';
  FConfig.Dproj := 'C:\Test\Test.dproj';
  FConfig.OutputDir := 'C:\Test\Release';
  FConfig.PublishTargets.Http.Enabled := True;
  
  Assert.IsFalse(FConfig.Validate(ErrorMsg), 'Should fail without appId');
  Assert.Contains(ErrorMsg, 'appId', 'Error should mention appId');
end;

procedure TTestPublishConfig.Test_Validate_RequiresAppName;
var
  ErrorMsg: string;
begin
  FConfig.AppId := 'com.test.app';
  FConfig.Dproj := 'C:\Test\Test.dproj';
  FConfig.OutputDir := 'C:\Test\Release';
  FConfig.PublishTargets.Http.Enabled := True;
  
  Assert.IsFalse(FConfig.Validate(ErrorMsg), 'Should fail without appName');
  Assert.Contains(ErrorMsg, 'appName', 'Error should mention appName');
end;

procedure TTestPublishConfig.Test_GetDefaultPackageName_FormatsCorrectly;
var
  PackageName: string;
begin
  FConfig.AppName := 'MyApp';
  PackageName := FConfig.GetDefaultPackageName('1.2.3');
  Assert.AreEqual('MyApp-1.2.3-Win32.zip', PackageName);
end;

{ TTestVersionManifest }

procedure TTestVersionManifest.Setup;
begin
  FTempDir := TPath.Combine(TPath.GetTempPath, 'UniBaseTests_' + TGUID.NewGuid.ToString);
  ForceDirectories(FTempDir);
end;

procedure TTestVersionManifest.TearDown;
begin
  if TDirectory.Exists(FTempDir) then
    TDirectory.Delete(FTempDir, True);
end;

procedure TTestVersionManifest.Test_NewFormat_ToJSONString_HasRequiredFields;
var
  Manifest: TVersionManifest;
  Files: TArray<TManifestFile>;
  JsonStr: string;
  Root: TJSONObject;
begin
  SetLength(Files, 1);
  Files[0].Name := 'test.zip';
  Files[0].Url := 'https://example.com/test.zip';
  Files[0].Size := 1024;
  Files[0].Sha256 := 'abc123';
  
  Manifest := TManifestGenerator.GenerateManifest(
    'com.test.app', '1.0.0', 'stable', Files, 'Release notes', False);
  
  JsonStr := Manifest.ToJSONString;
  Root := TJSONObject.ParseJSONValue(JsonStr) as TJSONObject;
  try
    Assert.IsNotNull(Root.GetValue('appId'), 'Should have appId');
    Assert.IsNotNull(Root.GetValue('version'), 'Should have version');
    Assert.IsNotNull(Root.GetValue('channel'), 'Should have channel');
    Assert.IsNotNull(Root.GetValue('publishedAt'), 'Should have publishedAt');
    Assert.IsNotNull(Root.GetValue('files'), 'Should have files');
  finally
    Root.Free;
  end;
end;

procedure TTestVersionManifest.Test_NewFormat_FromJSON_ParsesCorrectly;
const
  TestJSON = '{"appId":"com.test.app","version":"2.0.0","channel":"beta",' +
             '"publishedAt":"2025-12-11T10:00:00Z",' +
             '"files":[{"name":"app.zip","url":"https://example.com/app.zip","size":2048,"sha256":"def456"}],' +
             '"releaseNotes":"New features","mandatory":true}';
var
  Manifest: TVersionManifest;
  Root: TJSONObject;
begin
  Root := TJSONObject.ParseJSONValue(TestJSON) as TJSONObject;
  try
    Manifest.FromJSON(Root);
    Assert.AreEqual('com.test.app', Manifest.AppId);
    Assert.AreEqual('2.0.0', Manifest.Version);
    Assert.AreEqual('beta', Manifest.Channel);
    Assert.AreEqual(1, Length(Manifest.Files));
    Assert.AreEqual('app.zip', Manifest.Files[0].Name);
    Assert.IsTrue(Manifest.Mandatory);
  finally
    Root.Free;
  end;
end;

procedure TTestVersionManifest.Test_LegacyFormat_HasChannelObjects;
var
  Root: TJSONObject;
begin
  Root := TManifestGenerator.GenerateLegacyJSON(
    'stable', '1.0.0', 'https://example.com/app.zip', 1024, 'abc123', 'Notes');
  try
    Assert.IsNotNull(Root.GetValue('stable'), 'Should have stable channel');
    Assert.IsNotNull(Root.GetValue('beta'), 'Should have beta channel');
    Assert.IsNotNull(Root.GetValue('dev'), 'Should have dev channel');
    Assert.IsNotNull(Root.GetValue('meta'), 'Should have meta section');
    
    Assert.AreEqual('1.0.0', 
      Root.GetValue<TJSONObject>('stable').GetValue<string>('version'));
  finally
    Root.Free;
  end;
end;

procedure TTestVersionManifest.Test_IsNewFormat_DetectsNewFormat;
const
  NewFormatJSON = '{"appId":"com.test","version":"1.0.0","files":[]}';
begin
  Assert.IsTrue(TManifestGenerator.IsNewFormat(NewFormatJSON), 
    'Should detect new format');
end;

procedure TTestVersionManifest.Test_IsNewFormat_DetectsLegacyFormat;
const
  LegacyFormatJSON = '{"stable":{"version":"1.0.0"},"beta":{},"dev":{},"meta":{}}';
begin
  Assert.IsFalse(TManifestGenerator.IsNewFormat(LegacyFormatJSON), 
    'Should detect legacy format');
end;

procedure TTestVersionManifest.Test_SaveToFile_CreatesFile;
var
  Manifest: TVersionManifest;
  FilePath: string;
begin
  FilePath := TPath.Combine(FTempDir, 'version.json');
  
  Manifest.Clear;
  Manifest.AppId := 'com.test.app';
  Manifest.Version := '1.0.0';
  Manifest.Channel := 'stable';
  
  Assert.IsTrue(Manifest.SaveToFile(FilePath), 'Should save successfully');
  Assert.IsTrue(TFile.Exists(FilePath), 'File should exist');
end;

procedure TTestVersionManifest.Test_CreateFileEntry_ComputesHash;
var
  FilePath: string;
  Entry: TManifestFile;
begin
  // Create a test file
  FilePath := TPath.Combine(FTempDir, 'testfile.txt');
  TFile.WriteAllText(FilePath, 'Hello World', TEncoding.UTF8);
  
  Entry := TManifestGenerator.CreateFileEntry(FilePath, 'https://example.com/testfile.txt');
  
  Assert.AreEqual('testfile.txt', Entry.Name);
  Assert.AreEqual('https://example.com/testfile.txt', Entry.Url);
  Assert.IsTrue(Entry.Size > 0, 'Size should be > 0');
  Assert.IsNotEmpty(Entry.Sha256, 'SHA256 should not be empty');
  Assert.AreEqual(64, Length(Entry.Sha256), 'SHA256 should be 64 hex chars');
end;

{ TTestPublishConfigMRU }

procedure TTestPublishConfigMRU.Setup;
begin
  FTempFile := TPath.Combine(TPath.GetTempPath, 
    'UniBaseMRUTest_' + TGUID.NewGuid.ToString + '.json');
  FMRU := TPublishConfigMRU.Create(FTempFile, 5);
end;

procedure TTestPublishConfigMRU.TearDown;
begin
  FMRU.Free;
  if TFile.Exists(FTempFile) then
    TFile.Delete(FTempFile);
end;

procedure TTestPublishConfigMRU.Test_Add_InsertsAtFront;
begin
  FMRU.Add('path1');
  FMRU.Add('path2');
  
  Assert.AreEqual('path2', FMRU.GetMostRecent, 'Most recent should be last added');
end;

procedure TTestPublishConfigMRU.Test_Add_MovesExistingToFront;
begin
  FMRU.Add('path1');
  FMRU.Add('path2');
  FMRU.Add('path1');  // Add path1 again
  
  Assert.AreEqual('path1', FMRU.GetMostRecent, 'path1 should be moved to front');
  Assert.AreEqual(2, Length(FMRU.GetItems), 'Should not duplicate');
end;

procedure TTestPublishConfigMRU.Test_Add_RespectsMaxItems;
var
  I: Integer;
  Items: TArray<string>;
begin
  for I := 1 to 10 do
    FMRU.Add('path' + IntToStr(I));
  
  Items := FMRU.GetItems;
  Assert.AreEqual(5, Length(Items), 'Should respect max items (5)');
  Assert.AreEqual('path10', Items[0], 'Most recent should be path10');
end;

procedure TTestPublishConfigMRU.Test_Remove_DeletesItem;
begin
  FMRU.Add('path1');
  FMRU.Add('path2');
  FMRU.Remove('path1');
  
  Assert.AreEqual(1, Length(FMRU.GetItems), 'Should have 1 item');
  Assert.AreEqual('path2', FMRU.GetMostRecent);
end;

procedure TTestPublishConfigMRU.Test_GetMostRecent_ReturnsFirst;
begin
  Assert.IsEmpty(FMRU.GetMostRecent, 'Empty MRU should return empty string');
  
  FMRU.Add('path1');
  Assert.AreEqual('path1', FMRU.GetMostRecent);
end;

procedure TTestPublishConfigMRU.Test_Clear_RemovesAllItems;
begin
  FMRU.Add('path1');
  FMRU.Add('path2');
  FMRU.Clear;
  
  Assert.AreEqual(0, Length(FMRU.GetItems), 'Should be empty');
end;

procedure TTestPublishConfigMRU.Test_Persistence_SavesAndLoads;
var
  MRU2: TPublishConfigMRU;
begin
  FMRU.Add('path1');
  FMRU.Add('path2');
  FMRU.Free;
  
  // Create new instance with same file
  MRU2 := TPublishConfigMRU.Create(FTempFile, 5);
  try
    Assert.AreEqual(2, Length(MRU2.GetItems), 'Should load persisted items');
    Assert.AreEqual('path2', MRU2.GetMostRecent, 'Order should be preserved');
  finally
    MRU2.Free;
  end;
  
  // Recreate FMRU for TearDown
  FMRU := TPublishConfigMRU.Create(FTempFile, 5);
end;

{ TTestAutoUpdateFormatDetection }

procedure TTestAutoUpdateFormatDetection.Test_NewFormatJSON_HasAppIdAndFiles;
const
  NewFormatJSON = '{"appId":"com.test.app","version":"1.0.0","channel":"stable",' +
                  '"publishedAt":"2025-12-11T10:00:00Z",' +
                  '"files":[{"name":"app.zip","url":"https://example.com/app.zip","size":1024,"sha256":"abc"}],' +
                  '"releaseNotes":"Notes"}';
var
  Root: TJSONObject;
begin
  Root := TJSONObject.ParseJSONValue(NewFormatJSON) as TJSONObject;
  try
    Assert.IsNotNull(Root.GetValue('appId'), 'New format should have appId');
    Assert.IsNotNull(Root.GetValue('files'), 'New format should have files');
    Assert.IsTrue(TManifestGenerator.IsNewFormat(Root), 'Should be detected as new format');
  finally
    Root.Free;
  end;
end;

procedure TTestAutoUpdateFormatDetection.Test_LegacyFormatJSON_HasChannelObjects;
const
  LegacyFormatJSON = '{"stable":{"version":"1.0.0","downloadUrl":"https://example.com/app.zip"},' +
                     '"beta":{},"dev":{},"meta":{"lastUpdated":"2025-12-11"}}';
var
  Root: TJSONObject;
begin
  Root := TJSONObject.ParseJSONValue(LegacyFormatJSON) as TJSONObject;
  try
    Assert.IsNotNull(Root.GetValue('stable'), 'Legacy format should have stable');
    Assert.IsNull(Root.GetValue('appId'), 'Legacy format should not have appId');
    Assert.IsFalse(TManifestGenerator.IsNewFormat(Root), 'Should be detected as legacy format');
  finally
    Root.Free;
  end;
end;

procedure TTestAutoUpdateFormatDetection.Test_ParseNewFormat_ExtractsVersion;
const
  NewFormatJSON = '{"appId":"com.test","version":"2.5.0","channel":"stable",' +
                  '"files":[{"url":"https://example.com/app.zip"}]}';
var
  Root: TJSONObject;
  Version: string;
begin
  Root := TJSONObject.ParseJSONValue(NewFormatJSON) as TJSONObject;
  try
    Version := Root.GetValue<string>('version', '');
    Assert.AreEqual('2.5.0', Version, 'Should extract version from new format');
  finally
    Root.Free;
  end;
end;

procedure TTestAutoUpdateFormatDetection.Test_ParseLegacyFormat_ExtractsVersion;
const
  LegacyFormatJSON = '{"stable":{"version":"3.0.0","downloadUrl":"https://example.com"},' +
                     '"beta":{},"dev":{}}';
var
  Root, ChanObj: TJSONObject;
  Version: string;
begin
  Root := TJSONObject.ParseJSONValue(LegacyFormatJSON) as TJSONObject;
  try
    ChanObj := Root.GetValue<TJSONObject>('stable');
    Assert.IsNotNull(ChanObj, 'Should have stable channel object');
    Version := ChanObj.GetValue<string>('version', '');
    Assert.AreEqual('3.0.0', Version, 'Should extract version from legacy format');
  finally
    Root.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestPublishConfig);
  TDUnitX.RegisterTestFixture(TTestVersionManifest);
  TDUnitX.RegisterTestFixture(TTestPublishConfigMRU);
  TDUnitX.RegisterTestFixture(TTestAutoUpdateFormatDetection);

end.
