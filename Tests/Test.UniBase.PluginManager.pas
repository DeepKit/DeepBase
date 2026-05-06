{ ============================================================================
  Test.UniBase.PluginManager - Unit Tests for Plugin Manager Module
  
  Test Coverage:
    - TLoadedPlugin record
    - TPluginContext implementation
    - TUniBasePluginManager operations
  ============================================================================ }

unit Test.UniBase.PluginManager;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  UniBase.Plugin,
  UniBase.PluginManager;

type
  [TestFixture]
  TTestPluginContext = class
  private
    FContext: TPluginContext;
    FConfigValues: TDictionary<string, string>;
    FLogMessages: TStringList;
    function GetConfig(const Key, Default: string): string;
    procedure SetConfig(const Key, Value: string);
    function Translate(const Text: string): string;
    procedure LogProc(const Msg: string; Level: Integer);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_Create;
    [Test]
    procedure Test_GetConfig_Exists;
    [Test]
    procedure Test_GetConfig_Default;
    [Test]
    procedure Test_SetConfig;
    [Test]
    procedure Test_Translate;
    [Test]
    procedure Test_Log;
    [Test]
    procedure Test_GetRootPath;
    [Test]
    procedure Test_GetPluginDataPath;
  end;

  [TestFixture]
  TTestPluginManager = class
  private
    FManager: TUniBasePluginManager;
    FContext: IUniBasePluginContext;
    FPluginLoadedCount: Integer;
    FPluginUnloadedCount: Integer;
    FLastError: string;
    procedure OnPluginLoaded(Sender: TObject; const Info: TPluginInfo);
    procedure OnPluginUnloaded(Sender: TObject; const PluginID: TGUID);
    procedure OnPluginError(Sender: TObject; const Args: TPluginErrorEventArgs);
    function CreateMockContext: IUniBasePluginContext;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_Create;
    [Test]
    procedure Test_PluginsDir;
    [Test]
    procedure Test_PluginCount_Initial;
    [Test]
    procedure Test_GetLoadedPlugins_Empty;
    [Test]
    procedure Test_IsPluginLoaded_False;
    [Test]
    procedure Test_GetPlugin_Nil;
    [Test]
    procedure Test_SetPluginEnabled;
    [Test]
    procedure Test_IsPluginEnabled_Default;
    [Test]
    procedure Test_LoadPlugin_InvalidPath;
    [Test]
    procedure Test_UnloadPlugin_NotLoaded;
    [Test]
    procedure Test_Events_Assigned;
  end;

  [TestFixture]
  TTestLoadedPlugin = class
  public
    [Test]
    procedure Test_RecordFields;
    [Test]
    procedure Test_DefaultValues;
  end;

  [TestFixture]
  TTestPluginConstants = class
  public
    [Test]
    procedure Test_DEFAULT_PLUGINS_DIR;
    [Test]
    procedure Test_REGISTER_PLUGIN_FUNC;
  end;

implementation

{ Mock Plugin Context }

type
  TMockPluginContext = class(TInterfacedObject, IUniBasePluginContext)
  private
    FRootPath: string;
    FConfigs: TDictionary<string, string>;
  public
    constructor Create(const ARootPath: string);
    destructor Destroy; override;
    function GetConfig(const Key: string; const Default: string = ''): string;
    procedure SetConfig(const Key, Value: string);
    function Translate(const Text: string): string;
    procedure Log(const Message: string; Level: Integer = 1);
    function GetRootPath: string;
    function GetPluginDataPath(const PluginID: TGUID): string;
  end;

constructor TMockPluginContext.Create(const ARootPath: string);
begin
  inherited Create;
  FRootPath := ARootPath;
  FConfigs := TDictionary<string, string>.Create;
end;

destructor TMockPluginContext.Destroy;
begin
  FConfigs.Free;
  inherited;
end;

function TMockPluginContext.GetConfig(const Key: string; const Default: string): string;
begin
  if not FConfigs.TryGetValue(Key, Result) then
    Result := Default;
end;

procedure TMockPluginContext.SetConfig(const Key, Value: string);
begin
  FConfigs.AddOrSetValue(Key, Value);
end;

function TMockPluginContext.Translate(const Text: string): string;
begin
  Result := Text;
end;

procedure TMockPluginContext.Log(const Message: string; Level: Integer);
begin
  // Do nothing in mock
end;

function TMockPluginContext.GetRootPath: string;
begin
  Result := FRootPath;
end;

function TMockPluginContext.GetPluginDataPath(const PluginID: TGUID): string;
begin
  Result := FRootPath + '\PluginData\' + GUIDToString(PluginID);
end;

{ TTestPluginContext }

procedure TTestPluginContext.Setup;
begin
  FConfigValues := TDictionary<string, string>.Create;
  FConfigValues.Add('key1', 'value1');
  FConfigValues.Add('key2', 'value2');
  FLogMessages := TStringList.Create;
  
  FContext := TPluginContext.Create(
    GetConfig,
    SetConfig,
    Translate,
    LogProc,
    'C:\TestRoot');
end;

procedure TTestPluginContext.TearDown;
begin
  FContext.Free;
  FConfigValues.Free;
  FLogMessages.Free;
end;

function TTestPluginContext.GetConfig(const Key, Default: string): string;
begin
  if not FConfigValues.TryGetValue(Key, Result) then
    Result := Default;
end;

procedure TTestPluginContext.SetConfig(const Key, Value: string);
begin
  FConfigValues.AddOrSetValue(Key, Value);
end;

function TTestPluginContext.Translate(const Text: string): string;
begin
  Result := '[T]' + Text;
end;

procedure TTestPluginContext.LogProc(const Msg: string; Level: Integer);
begin
  FLogMessages.Add(Format('[%d] %s', [Level, Msg]));
end;

procedure TTestPluginContext.Test_Create;
begin
  Assert.IsNotNull(FContext);
end;

procedure TTestPluginContext.Test_GetConfig_Exists;
var
  Value: string;
begin
  Value := FContext.GetConfig('key1', 'default');
  Assert.AreEqual('value1', Value);
end;

procedure TTestPluginContext.Test_GetConfig_Default;
var
  Value: string;
begin
  Value := FContext.GetConfig('nonexistent', 'mydefault');
  Assert.AreEqual('mydefault', Value);
end;

procedure TTestPluginContext.Test_SetConfig;
begin
  FContext.SetConfig('newkey', 'newvalue');
  Assert.AreEqual('newvalue', FContext.GetConfig('newkey', ''));
end;

procedure TTestPluginContext.Test_Translate;
var
  Translated: string;
begin
  Translated := FContext.Translate('Hello');
  Assert.AreEqual('[T]Hello', Translated);
end;

procedure TTestPluginContext.Test_Log;
begin
  FContext.Log('Test message', 2);
  Assert.AreEqual(1, Integer(FLogMessages.Count));
  Assert.IsTrue(FLogMessages[0].Contains('Test message'));
end;

procedure TTestPluginContext.Test_GetRootPath;
begin
  Assert.AreEqual('C:\TestRoot', FContext.GetRootPath);
end;

procedure TTestPluginContext.Test_GetPluginDataPath;
var
  PluginID: TGUID;
  DataPath: string;
begin
  PluginID := TGUID.NewGuid;
  DataPath := FContext.GetPluginDataPath(PluginID);
  Assert.IsTrue(DataPath.Contains('C:\TestRoot'));
  Assert.IsTrue(DataPath.Contains(GUIDToString(PluginID)));
end;

{ TTestPluginManager }

procedure TTestPluginManager.Setup;
begin
  FContext := CreateMockContext;
  FManager := TUniBasePluginManager.Create('C:\TestPlugins', FContext);
  FPluginLoadedCount := 0;
  FPluginUnloadedCount := 0;
  FLastError := '';
end;

procedure TTestPluginManager.TearDown;
begin
  FManager.Free;
end;

function TTestPluginManager.CreateMockContext: IUniBasePluginContext;
begin
  Result := TMockPluginContext.Create('C:\TestRoot');
end;

procedure TTestPluginManager.OnPluginLoaded(Sender: TObject; const Info: TPluginInfo);
begin
  Inc(FPluginLoadedCount);
end;

procedure TTestPluginManager.OnPluginUnloaded(Sender: TObject; const PluginID: TGUID);
begin
  Inc(FPluginUnloadedCount);
end;

procedure TTestPluginManager.OnPluginError(Sender: TObject; const Args: TPluginErrorEventArgs);
begin
  FLastError := Args.ErrorMessage;
end;

procedure TTestPluginManager.Test_Create;
begin
  Assert.IsNotNull(FManager);
end;

procedure TTestPluginManager.Test_PluginsDir;
begin
  Assert.AreEqual('C:\TestPlugins', FManager.PluginsDir);
end;

procedure TTestPluginManager.Test_PluginCount_Initial;
begin
  Assert.AreEqual(0, FManager.PluginCount);
end;

procedure TTestPluginManager.Test_GetLoadedPlugins_Empty;
var
  Plugins: TArray<TPluginInfo>;
begin
  Plugins := FManager.GetLoadedPlugins;
  Assert.AreEqual(0, Integer(Length(Plugins)));
end;

procedure TTestPluginManager.Test_IsPluginLoaded_False;
var
  RandomID: TGUID;
begin
  RandomID := TGUID.NewGuid;
  Assert.IsFalse(FManager.IsPluginLoaded(RandomID));
end;

procedure TTestPluginManager.Test_GetPlugin_Nil;
var
  RandomID: TGUID;
  Plugin: IUniBasePlugin;
begin
  RandomID := TGUID.NewGuid;
  Plugin := FManager.GetPlugin(RandomID);
  Assert.IsNull(Plugin);
end;

procedure TTestPluginManager.Test_SetPluginEnabled;
var
  PluginID: TGUID;
begin
  PluginID := TGUID.NewGuid;
  FManager.SetPluginEnabled(PluginID, False);
  Assert.IsFalse(FManager.IsPluginEnabled(PluginID));
  
  FManager.SetPluginEnabled(PluginID, True);
  Assert.IsTrue(FManager.IsPluginEnabled(PluginID));
end;

procedure TTestPluginManager.Test_IsPluginEnabled_Default;
var
  PluginID: TGUID;
begin
  PluginID := TGUID.NewGuid;
  // Default should be True (plugins are enabled by default)
  Assert.IsTrue(FManager.IsPluginEnabled(PluginID));
end;

procedure TTestPluginManager.Test_LoadPlugin_InvalidPath;
var
  Result: Boolean;
begin
  Result := FManager.LoadPlugin('C:\NonExistent\plugin.bpl');
  Assert.IsFalse(Result);
end;

procedure TTestPluginManager.Test_UnloadPlugin_NotLoaded;
var
  RandomID: TGUID;
  Result: Boolean;
begin
  RandomID := TGUID.NewGuid;
  Result := FManager.UnloadPlugin(RandomID);
  Assert.IsFalse(Result);
end;

procedure TTestPluginManager.Test_Events_Assigned;
begin
  FManager.OnPluginLoaded := OnPluginLoaded;
  FManager.OnPluginUnloaded := OnPluginUnloaded;
  FManager.OnPluginError := OnPluginError;
  
  Assert.IsNotNull(TMethod(FManager.OnPluginLoaded).Code);
  Assert.IsNotNull(TMethod(FManager.OnPluginUnloaded).Code);
  Assert.IsNotNull(TMethod(FManager.OnPluginError).Code);
end;

{ TTestLoadedPlugin }

procedure TTestLoadedPlugin.Test_RecordFields;
var
  Loaded: TLoadedPlugin;
begin
  Loaded.BPLPath := 'C:\Plugins\test.bpl';
  Loaded.PackageHandle := 12345;
  Loaded.LoadOrder := 1;
  
  Assert.AreEqual('C:\Plugins\test.bpl', Loaded.BPLPath);
  Assert.AreEqual(HMODULE(12345), Loaded.PackageHandle);
  Assert.AreEqual(1, Loaded.LoadOrder);
end;

procedure TTestLoadedPlugin.Test_DefaultValues;
var
  Loaded: TLoadedPlugin;
begin
  FillChar(Loaded, SizeOf(Loaded), 0);
  
  Assert.AreEqual('', Loaded.BPLPath);
  Assert.AreEqual(HMODULE(0), Loaded.PackageHandle);
  Assert.AreEqual(0, Loaded.LoadOrder);
end;

{ TTestPluginConstants }

procedure TTestPluginConstants.Test_DEFAULT_PLUGINS_DIR;
begin
  Assert.AreEqual('Plugins', DEFAULT_PLUGINS_DIR);
end;

procedure TTestPluginConstants.Test_REGISTER_PLUGIN_FUNC;
begin
  Assert.AreEqual('RegisterPlugin', REGISTER_PLUGIN_FUNC);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestPluginContext);
  TDUnitX.RegisterTestFixture(TTestPluginManager);
  TDUnitX.RegisterTestFixture(TTestLoadedPlugin);
  TDUnitX.RegisterTestFixture(TTestPluginConstants);

end.
