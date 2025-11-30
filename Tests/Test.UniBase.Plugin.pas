{ ============================================================================
  Test.UniBase.Plugin - Plugin System Unit Tests
  
  Tests for UniBase.Plugin and UniBase.PluginManager modules including:
  - TPluginInfo creation and helper functions
  - TUniBasePluginBase lifecycle
  - TPluginContext functionality
  - TUniBasePluginManager operations
  ============================================================================ }

unit Test.UniBase.Plugin;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  UniBase.Plugin,
  UniBase.PluginManager;

type
  // Mock plugin for testing
  TTestPlugin = class(TUniBasePluginBase)
  private
    FInitializeCalled: Boolean;
    FFinalizeCalled: Boolean;
    FShouldFailInit: Boolean;
  protected
    function DoGetPluginInfo: TPluginInfo; override;
    function DoInitialize: Boolean; override;
    function DoFinalize: Boolean; override;
  public
    constructor Create(AShouldFailInit: Boolean = False);
    
    property InitializeCalled: Boolean read FInitializeCalled;
    property FinalizeCalled: Boolean read FFinalizeCalled;
  end;

  [TestFixture]
  TTestPluginHelpers = class
  public
    [Test]
    procedure Test_MakePluginInfo_CreatesRecord;
    
    [Test]
    procedure Test_PluginStateToStr_ReturnsCorrectStrings;
    
    [Test]
    procedure Test_CompareVersions_Equal;
    
    [Test]
    procedure Test_CompareVersions_Less;
    
    [Test]
    procedure Test_CompareVersions_Greater;
    
    [Test]
    procedure Test_CompareVersions_DifferentLengths;
    
    [Test]
    procedure Test_GUIDToShortString_RemovesBraces;
  end;
  
  [TestFixture]
  TTestPluginBase = class
  private
    FPlugin: TTestPlugin;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_InitialState_IsUnloaded;
    
    [Test]
    procedure Test_Initialize_SetsActiveState;
    
    [Test]
    procedure Test_Initialize_CallsDoInitialize;
    
    [Test]
    procedure Test_Initialize_Failure_SetsErrorState;
    
    [Test]
    procedure Test_Finalize_SetsUnloadedState;
    
    [Test]
    procedure Test_Finalize_CallsDoFinalize;
    
    [Test]
    procedure Test_GetPluginInfo_ReturnsInfo;
  end;
  
  [TestFixture]
  TTestPluginContext = class
  private
    FContext: IUniBasePluginContext;
    FLastLogMsg: string;
    FLastLogLevel: Integer;
    FConfigStore: TStringList;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_GetConfig_ReturnsValue;
    
    [Test]
    procedure Test_GetConfig_ReturnsDefault;
    
    [Test]
    procedure Test_SetConfig_StoresValue;
    
    [Test]
    procedure Test_Translate_CallsCallback;
    
    [Test]
    procedure Test_Log_CallsCallback;
    
    [Test]
    procedure Test_GetRootPath_ReturnsPath;
  end;
  
  [TestFixture]
  TTestPluginManager = class
  private
    FManager: TUniBasePluginManager;
    FTempDir: string;
    FLoadedCount: Integer;
    FUnloadedCount: Integer;
    FErrorCount: Integer;
    
    procedure OnPluginLoaded(Sender: TObject; const Info: TPluginInfo);
    procedure OnPluginUnloaded(Sender: TObject; const PluginID: TGUID);
    procedure OnPluginError(Sender: TObject; const Args: TPluginErrorEventArgs);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_Create_SetsPluginsDir;
    
    [Test]
    procedure Test_PluginCount_InitiallyZero;
    
    [Test]
    procedure Test_LoadAllPlugins_CreatesDir;
    
    [Test]
    procedure Test_LoadPlugin_NonexistentFile_ReturnsFailure;
    
    [Test]
    procedure Test_GetLoadedPlugins_ReturnsEmptyInitially;
  end;

const
  TEST_PLUGIN_GUID: TGUID = '{12345678-1234-1234-1234-123456789ABC}';

implementation

{ TTestPlugin }

constructor TTestPlugin.Create(AShouldFailInit: Boolean);
begin
  inherited Create;
  FInitializeCalled := False;
  FFinalizeCalled := False;
  FShouldFailInit := AShouldFailInit;
end;

function TTestPlugin.DoGetPluginInfo: TPluginInfo;
begin
  Result := MakePluginInfo(
    TEST_PLUGIN_GUID,
    'Test Plugin',
    '1.0.0',
    'Test Author',
    'A test plugin for unit testing',
    [pcMenuItems],
    '0.3'
  );
end;

function TTestPlugin.DoInitialize: Boolean;
begin
  FInitializeCalled := True;
  if FShouldFailInit then
  begin
    SetError('Forced init failure');
    Result := False;
  end
  else
    Result := True;
end;

function TTestPlugin.DoFinalize: Boolean;
begin
  FFinalizeCalled := True;
  Result := True;
end;

{ TTestPluginHelpers }

procedure TTestPluginHelpers.Test_MakePluginInfo_CreatesRecord;
var
  Info: TPluginInfo;
  TestGUID: TGUID;
begin
  TestGUID := TEST_PLUGIN_GUID;
  
  Info := MakePluginInfo(
    TestGUID,
    'MyPlugin',
    '2.0.0',
    'John Doe',
    'Description',
    [pcMenuItems, pcSettingsPage],
    '0.3'
  );
  
  Assert.IsTrue(IsEqualGUID(Info.ID, TestGUID));
  Assert.AreEqual('MyPlugin', Info.Name);
  Assert.AreEqual('2.0.0', Info.Version);
  Assert.AreEqual('John Doe', Info.Author);
  Assert.AreEqual('Description', Info.Description);
  Assert.IsTrue(pcMenuItems in Info.Capabilities);
  Assert.IsTrue(pcSettingsPage in Info.Capabilities);
  Assert.AreEqual('0.3', Info.MinUniBaseVersion);
end;

procedure TTestPluginHelpers.Test_PluginStateToStr_ReturnsCorrectStrings;
begin
  Assert.AreEqual('Unloaded', PluginStateToStr(psUnloaded));
  Assert.AreEqual('Loading', PluginStateToStr(psLoading));
  Assert.AreEqual('Loaded', PluginStateToStr(psLoaded));
  Assert.AreEqual('Active', PluginStateToStr(psActive));
  Assert.AreEqual('Error', PluginStateToStr(psError));
  Assert.AreEqual('Unloading', PluginStateToStr(psUnloading));
end;

procedure TTestPluginHelpers.Test_CompareVersions_Equal;
begin
  Assert.AreEqual(0, CompareVersions('1.0.0', '1.0.0'));
  Assert.AreEqual(0, CompareVersions('2.5.3', '2.5.3'));
end;

procedure TTestPluginHelpers.Test_CompareVersions_Less;
begin
  Assert.AreEqual(-1, CompareVersions('1.0.0', '2.0.0'));
  Assert.AreEqual(-1, CompareVersions('1.0.0', '1.1.0'));
  Assert.AreEqual(-1, CompareVersions('1.0.0', '1.0.1'));
end;

procedure TTestPluginHelpers.Test_CompareVersions_Greater;
begin
  Assert.AreEqual(1, CompareVersions('2.0.0', '1.0.0'));
  Assert.AreEqual(1, CompareVersions('1.1.0', '1.0.0'));
  Assert.AreEqual(1, CompareVersions('1.0.1', '1.0.0'));
end;

procedure TTestPluginHelpers.Test_CompareVersions_DifferentLengths;
begin
  Assert.AreEqual(0, CompareVersions('1.0', '1.0.0'));
  Assert.AreEqual(-1, CompareVersions('1.0', '1.0.1'));
  Assert.AreEqual(1, CompareVersions('1.0.1', '1.0'));
end;

procedure TTestPluginHelpers.Test_GUIDToShortString_RemovesBraces;
var
  S: string;
begin
  S := GUIDToShortString(TEST_PLUGIN_GUID);
  
  Assert.IsFalse(S.StartsWith('{'));
  Assert.IsFalse(S.EndsWith('}'));
  Assert.IsTrue(S.Contains('-')); // Still has dashes
end;

{ TTestPluginBase }

procedure TTestPluginBase.Setup;
begin
  FPlugin := TTestPlugin.Create;
end;

procedure TTestPluginBase.TearDown;
begin
  FPlugin.Free;
end;

procedure TTestPluginBase.Test_InitialState_IsUnloaded;
begin
  Assert.AreEqual(Ord(psUnloaded), Ord(FPlugin.State));
end;

procedure TTestPluginBase.Test_Initialize_SetsActiveState;
begin
  FPlugin.Initialize;
  Assert.AreEqual(Ord(psActive), Ord(FPlugin.State));
end;

procedure TTestPluginBase.Test_Initialize_CallsDoInitialize;
begin
  FPlugin.Initialize;
  Assert.IsTrue(FPlugin.InitializeCalled);
end;

procedure TTestPluginBase.Test_Initialize_Failure_SetsErrorState;
var
  FailingPlugin: TTestPlugin;
begin
  FailingPlugin := TTestPlugin.Create(True); // Should fail
  try
    FailingPlugin.Initialize;
    Assert.AreEqual(Ord(psError), Ord(FailingPlugin.State));
    Assert.AreEqual('Forced init failure', FailingPlugin.LastError);
  finally
    FailingPlugin.Free;
  end;
end;

procedure TTestPluginBase.Test_Finalize_SetsUnloadedState;
begin
  FPlugin.Initialize;
  FPlugin.Finalize;
  Assert.AreEqual(Ord(psUnloaded), Ord(FPlugin.State));
end;

procedure TTestPluginBase.Test_Finalize_CallsDoFinalize;
begin
  FPlugin.Initialize;
  FPlugin.Finalize;
  Assert.IsTrue(FPlugin.FinalizeCalled);
end;

procedure TTestPluginBase.Test_GetPluginInfo_ReturnsInfo;
var
  Info: TPluginInfo;
begin
  Info := FPlugin.GetPluginInfo;
  Assert.AreEqual('Test Plugin', Info.Name);
  Assert.AreEqual('1.0.0', Info.Version);
end;

{ TTestPluginContext }

procedure TTestPluginContext.Setup;
begin
  FConfigStore := TStringList.Create;
  FLastLogMsg := '';
  FLastLogLevel := -1;
  
  FContext := TPluginContext.Create(
    // GetConfig
    function(const Key, Default: string): string
    var
      Idx: Integer;
    begin
      Idx := FConfigStore.IndexOfName(Key);
      if Idx >= 0 then
        Result := FConfigStore.ValueFromIndex[Idx]
      else
        Result := Default;
    end,
    // SetConfig
    procedure(const Key, Value: string)
    begin
      FConfigStore.Values[Key] := Value;
    end,
    // Translate
    function(const Text: string): string
    begin
      Result := '[T]' + Text;
    end,
    // Log
    procedure(const Msg: string; Level: Integer)
    begin
      FLastLogMsg := Msg;
      FLastLogLevel := Level;
    end,
    'C:\TestRoot'
  );
end;

procedure TTestPluginContext.TearDown;
begin
  FContext := nil;
  FConfigStore.Free;
end;

procedure TTestPluginContext.Test_GetConfig_ReturnsValue;
begin
  FConfigStore.Values['TestKey'] := 'TestValue';
  Assert.AreEqual('TestValue', FContext.GetConfig('TestKey', 'Default'));
end;

procedure TTestPluginContext.Test_GetConfig_ReturnsDefault;
begin
  Assert.AreEqual('DefaultValue', FContext.GetConfig('NonExistent', 'DefaultValue'));
end;

procedure TTestPluginContext.Test_SetConfig_StoresValue;
begin
  FContext.SetConfig('NewKey', 'NewValue');
  Assert.AreEqual('NewValue', FConfigStore.Values['NewKey']);
end;

procedure TTestPluginContext.Test_Translate_CallsCallback;
begin
  Assert.AreEqual('[T]Hello', FContext.Translate('Hello'));
end;

procedure TTestPluginContext.Test_Log_CallsCallback;
begin
  FContext.Log('Test message', 2);
  Assert.AreEqual('Test message', FLastLogMsg);
  Assert.AreEqual(2, FLastLogLevel);
end;

procedure TTestPluginContext.Test_GetRootPath_ReturnsPath;
begin
  Assert.AreEqual('C:\TestRoot', FContext.GetRootPath);
end;

{ TTestPluginManager }

procedure TTestPluginManager.Setup;
begin
  FTempDir := TPath.Combine(TPath.GetTempPath, 'UniBasePluginTest_' + 
    FormatDateTime('yyyymmddhhnnss', Now));
  TDirectory.CreateDirectory(FTempDir);
  
  FManager := TUniBasePluginManager.Create(FTempDir, nil);
  FManager.OnPluginLoaded := OnPluginLoaded;
  FManager.OnPluginUnloaded := OnPluginUnloaded;
  FManager.OnPluginError := OnPluginError;
  
  FLoadedCount := 0;
  FUnloadedCount := 0;
  FErrorCount := 0;
end;

procedure TTestPluginManager.TearDown;
begin
  FManager.Free;
  
  if TDirectory.Exists(FTempDir) then
    TDirectory.Delete(FTempDir, True);
end;

procedure TTestPluginManager.OnPluginLoaded(Sender: TObject; const Info: TPluginInfo);
begin
  Inc(FLoadedCount);
end;

procedure TTestPluginManager.OnPluginUnloaded(Sender: TObject; const PluginID: TGUID);
begin
  Inc(FUnloadedCount);
end;

procedure TTestPluginManager.OnPluginError(Sender: TObject; const Args: TPluginErrorEventArgs);
begin
  Inc(FErrorCount);
end;

procedure TTestPluginManager.Test_Create_SetsPluginsDir;
begin
  Assert.AreEqual(FTempDir, FManager.PluginsDir);
end;

procedure TTestPluginManager.Test_PluginCount_InitiallyZero;
begin
  Assert.AreEqual(0, FManager.PluginCount);
end;

procedure TTestPluginManager.Test_LoadAllPlugins_CreatesDir;
var
  NewDir: string;
  Manager2: TUniBasePluginManager;
begin
  NewDir := TPath.Combine(FTempDir, 'NewPlugins');
  Assert.IsFalse(TDirectory.Exists(NewDir));
  
  Manager2 := TUniBasePluginManager.Create(NewDir, nil);
  try
    Manager2.LoadAllPlugins;
    Assert.IsTrue(TDirectory.Exists(NewDir));
  finally
    Manager2.Free;
  end;
end;

procedure TTestPluginManager.Test_LoadPlugin_NonexistentFile_ReturnsFailure;
begin
  Assert.IsFalse(FManager.LoadPlugin('C:\NonExistent\Plugin.bpl'));
  Assert.AreEqual(1, FErrorCount); // Should fire error event
end;

procedure TTestPluginManager.Test_GetLoadedPlugins_ReturnsEmptyInitially;
var
  Plugins: TArray<TPluginInfo>;
begin
  Plugins := FManager.GetLoadedPlugins;
  Assert.AreEqual(0, Length(Plugins));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestPluginHelpers);
  TDUnitX.RegisterTestFixture(TTestPluginBase);
  TDUnitX.RegisterTestFixture(TTestPluginContext);
  TDUnitX.RegisterTestFixture(TTestPluginManager);
  
end.
