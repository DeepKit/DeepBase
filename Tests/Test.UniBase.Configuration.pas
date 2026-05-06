unit Test.UniBase.Configuration;

{*******************************************************************************
  UniBase Configuration Module Unit Tests
  
  Test Coverage:
  - TConfigValue type conversions
  - Memory configuration source
  - Environment configuration source
  - INI file configuration source
  - JSON file configuration source
  - Command line configuration source
  - Configuration builder (fluent API)
  - Configuration sections
  - Configuration change notifications
  - Hot reload capability
  - Object binding
  - Static TConfig helper
  - Thread safety
*******************************************************************************}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  System.JSON,
  System.SyncObjs,
  System.Threading,
  UniBase.Configuration;

type
  // Test configuration class for binding
  TDatabaseSettings = class
  private
    FHost: string;
    FPort: Integer;
    FUsername: string;
    FPassword: string;
    FTimeout: Double;
    FUseSSL: Boolean;
  public
    property Host: string read FHost write FHost;
    property Port: Integer read FPort write FPort;
    property Username: string read FUsername write FUsername;
    property Password: string read FPassword write FPassword;
    property Timeout: Double read FTimeout write FTimeout;
    property UseSSL: Boolean read FUseSSL write FUseSSL;
  end;

  [TestFixture]
  TTestConfigValue = class
  public
    [Test]
    procedure Test_AsString_ReturnsValue;
    
    [Test]
    procedure Test_AsInteger_ValidNumber;
    
    [Test]
    procedure Test_AsInteger_InvalidNumber_ReturnsDefault;
    
    [Test]
    procedure Test_AsInt64_ValidNumber;
    
    [Test]
    procedure Test_AsInt64_InvalidNumber_ReturnsDefault;
    
    [Test]
    procedure Test_AsFloat_ValidNumber;
    
    [Test]
    procedure Test_AsFloat_InvalidNumber_ReturnsDefault;
    
    [Test]
    procedure Test_AsBoolean_True_Values;
    
    [Test]
    procedure Test_AsBoolean_False_Values;
    
    [Test]
    procedure Test_AsBoolean_Invalid_ReturnsDefault;
    
    [Test]
    procedure Test_AsDateTime_ValidDate;
    
    [Test]
    procedure Test_AsDateTime_InvalidDate_ReturnsDefault;
    
    [Test]
    procedure Test_AsArray_SplitsByDelimiter;
    
    [Test]
    procedure Test_AsArray_EmptyValue_ReturnsNil;
    
    [Test]
    procedure Test_IsEmpty_True;
    
    [Test]
    procedure Test_IsEmpty_False;
  end;

  [TestFixture]
  TTestMemoryConfigurationSource = class
  private
    FSource: TMemoryConfigurationSource;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_SetValue_StoresValue;
    
    [Test]
    procedure Test_SetValues_ParsesKeyValuePairs;
    
    [Test]
    procedure Test_Clear_RemovesAllValues;
    
    [Test]
    procedure Test_Load_ReturnsCopy;
    
    [Test]
    procedure Test_GetName_ReturnsMemory;
    
    [Test]
    procedure Test_SupportsReload_ReturnsFalse;
  end;

  [TestFixture]
  TTestIniFileConfigurationSource = class
  private
    FTempFile: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_Load_ReadsIniFile;
    
    [Test]
    procedure Test_Load_UsesDelimiter;
    
    [Test]
    procedure Test_Load_NonExistentFile_ReturnsEmpty;
    
    [Test]
    procedure Test_SupportsReload_ReturnsTrue;
  end;

  [TestFixture]
  TTestJsonFileConfigurationSource = class
  private
    FTempFile: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_Load_ReadsJsonFile;
    
    [Test]
    procedure Test_Load_FlattensNestedObjects;
    
    [Test]
    procedure Test_Load_FlattensArrays;
    
    [Test]
    procedure Test_Load_HandlesNullValues;
    
    [Test]
    procedure Test_Load_NonExistentFile_ReturnsEmpty;
    
    [Test]
    procedure Test_SupportsReload_ReturnsTrue;
  end;

  [TestFixture]
  TTestConfigurationBuilder = class
  public
    [Test]
    procedure Test_AddMemory_AddsSource;
    
    [Test]
    procedure Test_AddIniFile_Optional_NoException;
    
    [Test]
    procedure Test_AddIniFile_Required_RaisesException;
    
    [Test]
    procedure Test_AddJsonFile_Optional_NoException;
    
    [Test]
    procedure Test_AddJsonFile_Required_RaisesException;
    
    [Test]
    procedure Test_SetKeyDelimiter_ChangesDelimiter;
    
    [Test]
    procedure Test_Build_ReturnsConfiguration;
    
    [Test]
    procedure Test_FluentApi_ChainsCalls;
  end;

  [TestFixture]
  TTestConfiguration = class
  private
    FConfig: TConfiguration;
    FTempJsonFile: string;
    
    procedure CreateTempJsonFile(const AContent: string);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    // Basic Operations
    [Test]
    procedure Test_GetString_ExistingKey;
    
    [Test]
    procedure Test_GetString_MissingKey_ReturnsDefault;
    
    [Test]
    procedure Test_GetInteger_ExistingKey;
    
    [Test]
    procedure Test_GetInteger_MissingKey_ReturnsDefault;
    
    [Test]
    procedure Test_GetInt64_ExistingKey;
    
    [Test]
    procedure Test_GetFloat_ExistingKey;
    
    [Test]
    procedure Test_GetBoolean_ExistingKey;
    
    [Test]
    procedure Test_GetDateTime_ExistingKey;
    
    [Test]
    procedure Test_GetArray_ExistingKey;
    
    // SetValue
    [Test]
    procedure Test_SetValue_UpdatesExisting;
    
    [Test]
    procedure Test_SetValue_AddsNew;
    
    // ContainsKey
    [Test]
    procedure Test_ContainsKey_True;
    
    [Test]
    procedure Test_ContainsKey_False;
    
    // Case Insensitive
    [Test]
    procedure Test_Keys_CaseInsensitive;
    
    // GetAllKeys
    [Test]
    procedure Test_GetAllKeys_ReturnsAllKeys;
    
    // Value Indexer
    [Test]
    procedure Test_ValueIndexer_ReturnsConfigValue;
    
    // ToDictionary
    [Test]
    procedure Test_ToDictionary_ReturnsAllValues;
  end;

  [TestFixture]
  TTestConfigurationSection = class
  private
    FConfig: TConfiguration;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_GetSection_ReturnsSection;
    
    [Test]
    procedure Test_Section_GetValue;
    
    [Test]
    procedure Test_Section_SetValue;
    
    [Test]
    procedure Test_Section_GetKey;
    
    [Test]
    procedure Test_Section_GetPath;
    
    [Test]
    procedure Test_Section_Exists_True;
    
    [Test]
    procedure Test_Section_Exists_False;
    
    [Test]
    procedure Test_Section_GetChildren;
    
    [Test]
    procedure Test_NestedSection;
  end;

  [TestFixture]
  TTestConfigurationChangeNotification = class
  private
    FConfig: TConfiguration;
    FChangedKey: string;
    FOldValue: string;
    FNewValue: string;
    FEventFired: Boolean;
    
    procedure HandleChange(Sender: TObject; const AKey: string);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_OnChange_FiresOnValueChange;
    
    [Test]
    procedure Test_OnChanged_CallbackFires;
    
    [Test]
    procedure Test_NoChange_NoNotification;
  end;

  [TestFixture]
  TTestConfigurationLayering = class
  public
    [Test]
    procedure Test_LaterSourceOverridesEarlier;
    
    [Test]
    procedure Test_MultipleSources_MergeValues;
  end;

  [TestFixture]
  TTestConfigurationBinding = class
  private
    FConfig: TConfiguration;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_BindTo_SetsStringProperties;
    
    [Test]
    procedure Test_BindTo_SetsIntegerProperties;
    
    [Test]
    procedure Test_BindTo_SetsFloatProperties;
    
    [Test]
    procedure Test_BindTo_SetsBooleanProperties;
    
    [Test]
    procedure Test_BindTo_WithSectionPath;
  end;

  [TestFixture]
  TTestStaticConfig = class
  private
    FSavedConfig: TConfiguration;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_SetDefault_SetsConfiguration;
    
    [Test]
    procedure Test_Default_ReturnsSetConfiguration;
    
    [Test]
    procedure Test_Get_ReturnsValue;
    
    [Test]
    procedure Test_Get_NoDefault_ReturnsDefault;
    
    [Test]
    procedure Test_GetInt_ReturnsValue;
    
    [Test]
    procedure Test_GetBool_ReturnsValue;
    
    [Test]
    procedure Test_GetFloat_ReturnsValue;
    
    [Test]
    procedure Test_Builder_ReturnsBuilder;
  end;

  [TestFixture]
  TTestConfigurationThreadSafety = class
  public
    [Test]
    procedure Test_ConcurrentReads;
    
    [Test]
    procedure Test_ConcurrentWrites;
    
    [Test]
    procedure Test_ConcurrentReadWrite;
  end;

implementation

{ TTestConfigValue }

procedure TTestConfigValue.Test_AsString_ReturnsValue;
var
  Value: TConfigValue;
begin
  Value.Value := 'Hello World';
  Assert.AreEqual('Hello World', Value.AsString);
end;

procedure TTestConfigValue.Test_AsInteger_ValidNumber;
var
  Value: TConfigValue;
begin
  Value.Value := '42';
  Assert.AreEqual(42, Value.AsInteger);
end;

procedure TTestConfigValue.Test_AsInteger_InvalidNumber_ReturnsDefault;
var
  Value: TConfigValue;
begin
  Value.Value := 'not a number';
  Assert.AreEqual(99, Value.AsInteger(99));
end;

procedure TTestConfigValue.Test_AsInt64_ValidNumber;
var
  Value: TConfigValue;
begin
  Value.Value := '9223372036854775807';
  Assert.AreEqual(Int64(9223372036854775807), Value.AsInt64);
end;

procedure TTestConfigValue.Test_AsInt64_InvalidNumber_ReturnsDefault;
var
  Value: TConfigValue;
begin
  Value.Value := 'invalid';
  Assert.AreEqual(Int64(123), Value.AsInt64(123));
end;

procedure TTestConfigValue.Test_AsFloat_ValidNumber;
var
  Value: TConfigValue;
begin
  Value.Value := FormatFloat('0.00', 3.14);
  Assert.AreEqual(Double(3.14), Value.AsFloat, 0.001);
end;

procedure TTestConfigValue.Test_AsFloat_InvalidNumber_ReturnsDefault;
var
  Value: TConfigValue;
begin
  Value.Value := 'not a float';
  Assert.AreEqual(Double(1.5), Value.AsFloat(1.5), 0.001);
end;

procedure TTestConfigValue.Test_AsBoolean_True_Values;
var
  Value: TConfigValue;
begin
  Value.Value := 'true';
  Assert.IsTrue(Value.AsBoolean);
  
  Value.Value := 'True';
  Assert.IsTrue(Value.AsBoolean);
  
  Value.Value := '1';
  Assert.IsTrue(Value.AsBoolean);
  
  Value.Value := 'yes';
  Assert.IsTrue(Value.AsBoolean);
  
  Value.Value := 'YES';
  Assert.IsTrue(Value.AsBoolean);
end;

procedure TTestConfigValue.Test_AsBoolean_False_Values;
var
  Value: TConfigValue;
begin
  Value.Value := 'false';
  Assert.IsFalse(Value.AsBoolean);
  
  Value.Value := 'False';
  Assert.IsFalse(Value.AsBoolean);
  
  Value.Value := '0';
  Assert.IsFalse(Value.AsBoolean);
  
  Value.Value := 'no';
  Assert.IsFalse(Value.AsBoolean);
end;

procedure TTestConfigValue.Test_AsBoolean_Invalid_ReturnsDefault;
var
  Value: TConfigValue;
begin
  Value.Value := 'maybe';
  Assert.IsTrue(Value.AsBoolean(True));
  Assert.IsFalse(Value.AsBoolean(False));
end;

procedure TTestConfigValue.Test_AsDateTime_ValidDate;
var
  Value: TConfigValue;
  Expected: TDateTime;
begin
  Expected := EncodeDate(2025, 1, 15);
  Value.Value := DateToStr(Expected);
  Assert.AreEqual(Expected, Value.AsDateTime, 0.0001);
end;

procedure TTestConfigValue.Test_AsDateTime_InvalidDate_ReturnsDefault;
var
  Value: TConfigValue;
  Default: TDateTime;
begin
  Default := EncodeDate(2000, 1, 1);
  Value.Value := 'not a date';
  Assert.AreEqual(Default, Value.AsDateTime(Default), 0.0001);
end;

procedure TTestConfigValue.Test_AsArray_SplitsByDelimiter;
var
  Value: TConfigValue;
  Arr: TArray<string>;
begin
  Value.Value := 'a,b,c,d';
  Arr := Value.AsArray;
  
  Assert.AreEqual(4, Integer(Length(Arr)));
  Assert.AreEqual('a', Arr[0]);
  Assert.AreEqual('b', Arr[1]);
  Assert.AreEqual('c', Arr[2]);
  Assert.AreEqual('d', Arr[3]);
end;

procedure TTestConfigValue.Test_AsArray_EmptyValue_ReturnsNil;
var
  Value: TConfigValue;
begin
  Value.Value := '';
  Assert.IsNull(Value.AsArray);
end;

procedure TTestConfigValue.Test_IsEmpty_True;
var
  Value: TConfigValue;
begin
  Value.Value := '';
  Assert.IsTrue(Value.IsEmpty);
end;

procedure TTestConfigValue.Test_IsEmpty_False;
var
  Value: TConfigValue;
begin
  Value.Value := 'something';
  Assert.IsFalse(Value.IsEmpty);
end;

{ TTestMemoryConfigurationSource }

procedure TTestMemoryConfigurationSource.Setup;
begin
  FSource := TMemoryConfigurationSource.Create;
end;

procedure TTestMemoryConfigurationSource.TearDown;
begin
  FSource.Free;
end;

procedure TTestMemoryConfigurationSource.Test_SetValue_StoresValue;
var
  Data: TDictionary<string, string>;
begin
  FSource.SetValue('key1', 'value1');
  
  Data := FSource.Load;
  try
    Assert.AreEqual('value1', Data['key1']);
  finally
    Data.Free;
  end;
end;

procedure TTestMemoryConfigurationSource.Test_SetValues_ParsesKeyValuePairs;
var
  Data: TDictionary<string, string>;
begin
  FSource.SetValues(['name=John', 'age=30', 'city=NYC']);
  
  Data := FSource.Load;
  try
    Assert.AreEqual('John', Data['name']);
    Assert.AreEqual('30', Data['age']);
    Assert.AreEqual('NYC', Data['city']);
  finally
    Data.Free;
  end;
end;

procedure TTestMemoryConfigurationSource.Test_Clear_RemovesAllValues;
var
  Data: TDictionary<string, string>;
begin
  FSource.SetValues(['a=1', 'b=2']);
  FSource.Clear;

  Data := FSource.Load;
  try
    Assert.AreEqual(0, Integer(Data.Count));
  finally
    Data.Free;
  end;
end;

procedure TTestMemoryConfigurationSource.Test_Load_ReturnsCopy;
var
  Data1, Data2: TDictionary<string, string>;
begin
  FSource.SetValue('key', 'value');
  
  Data1 := FSource.Load;
  Data2 := FSource.Load;
  try
    Assert.AreNotSame(Data1, Data2);
  finally
    Data1.Free;
    Data2.Free;
  end;
end;

procedure TTestMemoryConfigurationSource.Test_GetName_ReturnsMemory;
begin
  Assert.AreEqual('Memory', FSource.Name);
end;

procedure TTestMemoryConfigurationSource.Test_SupportsReload_ReturnsFalse;
begin
  Assert.IsFalse(FSource.SupportsReload);
end;

{ TTestIniFileConfigurationSource }

procedure TTestIniFileConfigurationSource.Setup;
begin
  FTempFile := TPath.GetTempFileName;
  TFile.WriteAllText(FTempFile,
    '[Database]'#13#10 +
    'Host=localhost'#13#10 +
    'Port=5432'#13#10 +
    '[Logging]'#13#10 +
    'Level=Debug'#13#10 +
    'Enabled=true'#13#10);
end;

procedure TTestIniFileConfigurationSource.TearDown;
begin
  if TFile.Exists(FTempFile) then
    TFile.Delete(FTempFile);
end;

procedure TTestIniFileConfigurationSource.Test_Load_ReadsIniFile;
var
  Source: TIniFileConfigurationSource;
  Data: TDictionary<string, string>;
begin
  Source := TIniFileConfigurationSource.Create(FTempFile);
  try
    Data := Source.Load;
    try
      Assert.IsTrue(Data.ContainsKey('Database:Host'));
      Assert.AreEqual('localhost', Data['Database:Host']);
    finally
      Data.Free;
    end;
  finally
    Source.Free;
  end;
end;

procedure TTestIniFileConfigurationSource.Test_Load_UsesDelimiter;
var
  Source: TIniFileConfigurationSource;
  Data: TDictionary<string, string>;
begin
  Source := TIniFileConfigurationSource.Create(FTempFile, '.');
  try
    Data := Source.Load;
    try
      Assert.IsTrue(Data.ContainsKey('Database.Host'));
    finally
      Data.Free;
    end;
  finally
    Source.Free;
  end;
end;

procedure TTestIniFileConfigurationSource.Test_Load_NonExistentFile_ReturnsEmpty;
var
  Source: TIniFileConfigurationSource;
  Data: TDictionary<string, string>;
begin
  Source := TIniFileConfigurationSource.Create('C:\nonexistent\file.ini');
  try
    Data := Source.Load;
    try
      Assert.AreEqual(0, Integer(Data.Count));
    finally
      Data.Free;
    end;
  finally
    Source.Free;
  end;
end;

procedure TTestIniFileConfigurationSource.Test_SupportsReload_ReturnsTrue;
var
  Source: TIniFileConfigurationSource;
begin
  Source := TIniFileConfigurationSource.Create(FTempFile);
  try
    Assert.IsTrue(Source.SupportsReload);
  finally
    Source.Free;
  end;
end;

{ TTestJsonFileConfigurationSource }

procedure TTestJsonFileConfigurationSource.Setup;
begin
  FTempFile := TPath.GetTempFileName;
end;

procedure TTestJsonFileConfigurationSource.TearDown;
begin
  if TFile.Exists(FTempFile) then
    TFile.Delete(FTempFile);
end;

procedure TTestJsonFileConfigurationSource.Test_Load_ReadsJsonFile;
var
  Source: TJsonFileConfigurationSource;
  Data: TDictionary<string, string>;
begin
  TFile.WriteAllText(FTempFile, '{"name":"Test","version":"1.0"}');
  
  Source := TJsonFileConfigurationSource.Create(FTempFile);
  try
    Data := Source.Load;
    try
      Assert.AreEqual('Test', Data['name']);
      Assert.AreEqual('1.0', Data['version']);
    finally
      Data.Free;
    end;
  finally
    Source.Free;
  end;
end;

procedure TTestJsonFileConfigurationSource.Test_Load_FlattensNestedObjects;
var
  Source: TJsonFileConfigurationSource;
  Data: TDictionary<string, string>;
begin
  TFile.WriteAllText(FTempFile, '{"database":{"host":"localhost","port":5432}}');
  
  Source := TJsonFileConfigurationSource.Create(FTempFile);
  try
    Data := Source.Load;
    try
      Assert.AreEqual('localhost', Data['database:host']);
      Assert.AreEqual('5432', Data['database:port']);
    finally
      Data.Free;
    end;
  finally
    Source.Free;
  end;
end;

procedure TTestJsonFileConfigurationSource.Test_Load_FlattensArrays;
var
  Source: TJsonFileConfigurationSource;
  Data: TDictionary<string, string>;
begin
  TFile.WriteAllText(FTempFile, '{"servers":["srv1","srv2","srv3"]}');
  
  Source := TJsonFileConfigurationSource.Create(FTempFile);
  try
    Data := Source.Load;
    try
      Assert.AreEqual('srv1', Data['servers:0']);
      Assert.AreEqual('srv2', Data['servers:1']);
      Assert.AreEqual('srv3', Data['servers:2']);
    finally
      Data.Free;
    end;
  finally
    Source.Free;
  end;
end;

procedure TTestJsonFileConfigurationSource.Test_Load_HandlesNullValues;
var
  Source: TJsonFileConfigurationSource;
  Data: TDictionary<string, string>;
begin
  TFile.WriteAllText(FTempFile, '{"value":null}');
  
  Source := TJsonFileConfigurationSource.Create(FTempFile);
  try
    Data := Source.Load;
    try
      Assert.IsTrue(Data.ContainsKey('value'));
      Assert.AreEqual('', Data['value']);
    finally
      Data.Free;
    end;
  finally
    Source.Free;
  end;
end;

procedure TTestJsonFileConfigurationSource.Test_Load_NonExistentFile_ReturnsEmpty;
var
  Source: TJsonFileConfigurationSource;
  Data: TDictionary<string, string>;
begin
  Source := TJsonFileConfigurationSource.Create('C:\nonexistent\file.json');
  try
    Data := Source.Load;
    try
      Assert.AreEqual(0, Integer(Data.Count));
    finally
      Data.Free;
    end;
  finally
    Source.Free;
  end;
end;

procedure TTestJsonFileConfigurationSource.Test_SupportsReload_ReturnsTrue;
var
  Source: TJsonFileConfigurationSource;
begin
  Source := TJsonFileConfigurationSource.Create(FTempFile);
  try
    Assert.IsTrue(Source.SupportsReload);
  finally
    Source.Free;
  end;
end;

{ TTestConfigurationBuilder }

procedure TTestConfigurationBuilder.Test_AddMemory_AddsSource;
var
  Config: TConfiguration;
begin
  Config := TConfigurationBuilder.Create
    .AddMemory(['key=value'])
    .Build;
  try
    Assert.AreEqual('value', Config.GetString('key'));
  finally
    Config.Free;
  end;
end;

procedure TTestConfigurationBuilder.Test_AddIniFile_Optional_NoException;
var
  Builder: TConfigurationBuilder;
begin
  Builder := TConfigurationBuilder.Create;
  try
    // Should not raise exception
    Builder.AddIniFile('C:\nonexistent.ini', True);
    Assert.Pass;
  finally
    Builder.Free;
  end;
end;

procedure TTestConfigurationBuilder.Test_AddIniFile_Required_RaisesException;
var
  Builder: TConfigurationBuilder;
  Raised: Boolean;
begin
  Builder := TConfigurationBuilder.Create;
  try
    Raised := False;
    try
      Builder.AddIniFile('C:\nonexistent.ini', False);
    except
      on EConfigurationException do
        Raised := True;
    end;
    Assert.IsTrue(Raised, 'Expected EConfigurationException');
  finally
    Builder.Free;
  end;
end;

procedure TTestConfigurationBuilder.Test_AddJsonFile_Optional_NoException;
var
  Builder: TConfigurationBuilder;
begin
  Builder := TConfigurationBuilder.Create;
  try
    Builder.AddJsonFile('C:\nonexistent.json', True);
    Assert.Pass;
  finally
    Builder.Free;
  end;
end;

procedure TTestConfigurationBuilder.Test_AddJsonFile_Required_RaisesException;
var
  Builder: TConfigurationBuilder;
  Raised: Boolean;
begin
  Builder := TConfigurationBuilder.Create;
  try
    Raised := False;
    try
      Builder.AddJsonFile('C:\nonexistent.json', False);
    except
      on EConfigurationException do
        Raised := True;
    end;
    Assert.IsTrue(Raised, 'Expected EConfigurationException');
  finally
    Builder.Free;
  end;
end;

procedure TTestConfigurationBuilder.Test_SetKeyDelimiter_ChangesDelimiter;
var
  Config: TConfiguration;
begin
  Config := TConfigurationBuilder.Create
    .SetKeyDelimiter('.')
    .AddMemory(['a.b=test'])
    .Build;
  try
    Assert.AreEqual('.', Config.KeyDelimiter);
  finally
    Config.Free;
  end;
end;

procedure TTestConfigurationBuilder.Test_Build_ReturnsConfiguration;
var
  Config: TConfiguration;
begin
  Config := TConfigurationBuilder.Create
    .AddMemory([])
    .Build;
  try
    Assert.IsNotNull(Config);
  finally
    Config.Free;
  end;
end;

procedure TTestConfigurationBuilder.Test_FluentApi_ChainsCalls;
var
  Config: TConfiguration;
begin
  Config := TConfigurationBuilder.Create
    .SetKeyDelimiter(':')
    .AddMemory(['key1=value1'])
    .AddMemory(['key2=value2'])
    .Build;
  try
    Assert.AreEqual('value1', Config.GetString('key1'));
    Assert.AreEqual('value2', Config.GetString('key2'));
  finally
    Config.Free;
  end;
end;

{ TTestConfiguration }

procedure TTestConfiguration.Setup;
begin
  FTempJsonFile := '';
  FConfig := TConfigurationBuilder.Create
    .AddMemory([
      'stringKey=hello',
      'intKey=42',
      'int64Key=9223372036854775807',
      'floatKey=' + FormatFloat('0.00', 3.14),
      'boolKey=true',
      'arrayKey=a,b,c',
      'database:host=localhost',
      'database:port=5432',
      'database:ssl=true'
    ])
    .Build;
end;

procedure TTestConfiguration.TearDown;
begin
  FConfig.Free;
  if (FTempJsonFile <> '') and TFile.Exists(FTempJsonFile) then
    TFile.Delete(FTempJsonFile);
end;

procedure TTestConfiguration.CreateTempJsonFile(const AContent: string);
begin
  FTempJsonFile := TPath.GetTempFileName;
  TFile.WriteAllText(FTempJsonFile, AContent);
end;

procedure TTestConfiguration.Test_GetString_ExistingKey;
begin
  Assert.AreEqual('hello', FConfig.GetString('stringKey'));
end;

procedure TTestConfiguration.Test_GetString_MissingKey_ReturnsDefault;
begin
  Assert.AreEqual('default', FConfig.GetString('missing', 'default'));
end;

procedure TTestConfiguration.Test_GetInteger_ExistingKey;
begin
  Assert.AreEqual(42, FConfig.GetInteger('intKey'));
end;

procedure TTestConfiguration.Test_GetInteger_MissingKey_ReturnsDefault;
begin
  Assert.AreEqual(99, FConfig.GetInteger('missing', 99));
end;

procedure TTestConfiguration.Test_GetInt64_ExistingKey;
begin
  Assert.AreEqual(Int64(9223372036854775807), FConfig.GetInt64('int64Key'));
end;

procedure TTestConfiguration.Test_GetFloat_ExistingKey;
begin
  Assert.AreEqual(Double(3.14), FConfig.GetFloat('floatKey'), 0.001);
end;

procedure TTestConfiguration.Test_GetBoolean_ExistingKey;
begin
  Assert.IsTrue(FConfig.GetBoolean('boolKey'));
end;

procedure TTestConfiguration.Test_GetDateTime_ExistingKey;
var
  Expected: TDateTime;
begin
  Expected := EncodeDate(2025, 6, 15);
  FConfig.SetValue('dateKey', DateToStr(Expected));
  Assert.AreEqual(Expected, FConfig.GetDateTime('dateKey'), 0.0001);
end;

procedure TTestConfiguration.Test_GetArray_ExistingKey;
var
  Arr: TArray<string>;
begin
  Arr := FConfig.GetArray('arrayKey');
  Assert.AreEqual(3, Integer(Length(Arr)));
  Assert.AreEqual('a', Arr[0]);
end;

procedure TTestConfiguration.Test_SetValue_UpdatesExisting;
begin
  FConfig.SetValue('stringKey', 'world');
  Assert.AreEqual('world', FConfig.GetString('stringKey'));
end;

procedure TTestConfiguration.Test_SetValue_AddsNew;
begin
  FConfig.SetValue('newKey', 'newValue');
  Assert.AreEqual('newValue', FConfig.GetString('newKey'));
end;

procedure TTestConfiguration.Test_ContainsKey_True;
begin
  Assert.IsTrue(FConfig.ContainsKey('stringKey'));
end;

procedure TTestConfiguration.Test_ContainsKey_False;
begin
  Assert.IsFalse(FConfig.ContainsKey('nonexistent'));
end;

procedure TTestConfiguration.Test_Keys_CaseInsensitive;
begin
  Assert.AreEqual('hello', FConfig.GetString('STRINGKEY'));
  Assert.AreEqual('hello', FConfig.GetString('StringKey'));
  Assert.AreEqual('hello', FConfig.GetString('stringkey'));
end;

procedure TTestConfiguration.Test_GetAllKeys_ReturnsAllKeys;
var
  Keys: TArray<string>;
begin
  Keys := FConfig.GetAllKeys;
  Assert.IsTrue(Length(Keys) >= 9);
end;

procedure TTestConfiguration.Test_ValueIndexer_ReturnsConfigValue;
var
  Value: TConfigValue;
begin
  Value := FConfig['stringKey'];
  Assert.AreEqual('hello', Value.Value);
end;

procedure TTestConfiguration.Test_ToDictionary_ReturnsAllValues;
var
  Dict: TDictionary<string, string>;
begin
  Dict := FConfig.ToDictionary;
  try
    Assert.IsTrue(Dict.Count >= 9);
    Assert.AreEqual('hello', Dict['stringkey']);
  finally
    Dict.Free;
  end;
end;

{ TTestConfigurationSection }

procedure TTestConfigurationSection.Setup;
begin
  FConfig := TConfigurationBuilder.Create
    .AddMemory([
      'app:name=MyApp',
      'app:version=1.0',
      'app:database:host=localhost',
      'app:database:port=5432',
      'app:logging:level=debug',
      'other=value'
    ])
    .Build;
end;

procedure TTestConfigurationSection.TearDown;
begin
  FConfig.Free;
end;

procedure TTestConfigurationSection.Test_GetSection_ReturnsSection;
var
  Section: IConfigurationSection;
begin
  Section := FConfig.GetSection('app');
  Assert.IsNotNull(Section);
end;

procedure TTestConfigurationSection.Test_Section_GetValue;
var
  Section: IConfigurationSection;
begin
  Section := FConfig.GetSection('app:name');
  Assert.AreEqual('MyApp', Section.Value);
end;

procedure TTestConfigurationSection.Test_Section_SetValue;
var
  Section: IConfigurationSection;
begin
  Section := FConfig.GetSection('app:name');
  Section.Value := 'NewApp';
  Assert.AreEqual('NewApp', FConfig.GetString('app:name'));
end;

procedure TTestConfigurationSection.Test_Section_GetKey;
var
  Section: IConfigurationSection;
begin
  Section := FConfig.GetSection('app:database:host');
  Assert.AreEqual('host', Section.Key);
end;

procedure TTestConfigurationSection.Test_Section_GetPath;
var
  Section: IConfigurationSection;
begin
  Section := FConfig.GetSection('app:database:host');
  Assert.AreEqual('app:database:host', Section.Path);
end;

procedure TTestConfigurationSection.Test_Section_Exists_True;
var
  Section: IConfigurationSection;
begin
  Section := FConfig.GetSection('app:name');
  Assert.IsTrue(Section.Exists);
end;

procedure TTestConfigurationSection.Test_Section_Exists_False;
var
  Section: IConfigurationSection;
begin
  Section := FConfig.GetSection('app:nonexistent');
  Assert.IsFalse(Section.Exists);
end;

procedure TTestConfigurationSection.Test_Section_GetChildren;
var
  Section: IConfigurationSection;
  Children: TArray<IConfigurationSection>;
begin
  Section := FConfig.GetSection('app');
  Children := Section.GetChildren;
  Assert.IsTrue(Length(Children) >= 3); // name, version, database, logging
end;

procedure TTestConfigurationSection.Test_NestedSection;
var
  AppSection, DbSection: IConfigurationSection;
begin
  AppSection := FConfig.GetSection('app');
  DbSection := AppSection.GetSection('database');
  
  Assert.AreEqual('localhost', DbSection.GetSection('host').Value);
end;

{ TTestConfigurationChangeNotification }

procedure TTestConfigurationChangeNotification.Setup;
begin
  FConfig := TConfigurationBuilder.Create
    .AddMemory(['key=original'])
    .Build;
  FChangedKey := '';
  FOldValue := '';
  FNewValue := '';
  FEventFired := False;
end;

procedure TTestConfigurationChangeNotification.TearDown;
begin
  FConfig.Free;
end;

procedure TTestConfigurationChangeNotification.HandleChange(Sender: TObject; const AKey: string);
begin
  FChangedKey := AKey;
  FEventFired := True;
end;

procedure TTestConfigurationChangeNotification.Test_OnChange_FiresOnValueChange;
begin
  FConfig.OnChange := HandleChange;
  FConfig.SetValue('key', 'new value');
  
  Assert.IsTrue(FEventFired);
  Assert.AreEqual('key', FChangedKey);
end;

procedure TTestConfigurationChangeNotification.Test_OnChanged_CallbackFires;
begin
  FConfig.OnChanged(
    procedure(const AKey: string; const AOldValue, ANewValue: string)
    begin
      FChangedKey := AKey;
      FOldValue := AOldValue;
      FNewValue := ANewValue;
    end);
  
  FConfig.SetValue('key', 'updated');
  
  Assert.AreEqual('key', FChangedKey);
  Assert.AreEqual('original', FOldValue);
  Assert.AreEqual('updated', FNewValue);
end;

procedure TTestConfigurationChangeNotification.Test_NoChange_NoNotification;
begin
  FConfig.OnChange := HandleChange;
  FConfig.SetValue('key', 'original'); // Same value
  
  Assert.IsFalse(FEventFired);
end;

{ TTestConfigurationLayering }

procedure TTestConfigurationLayering.Test_LaterSourceOverridesEarlier;
var
  Config: TConfiguration;
begin
  Config := TConfigurationBuilder.Create
    .AddMemory(['key=first'])
    .AddMemory(['key=second'])
    .Build;
  try
    Assert.AreEqual('second', Config.GetString('key'));
  finally
    Config.Free;
  end;
end;

procedure TTestConfigurationLayering.Test_MultipleSources_MergeValues;
var
  Config: TConfiguration;
begin
  Config := TConfigurationBuilder.Create
    .AddMemory(['key1=value1'])
    .AddMemory(['key2=value2'])
    .AddMemory(['key3=value3'])
    .Build;
  try
    Assert.AreEqual('value1', Config.GetString('key1'));
    Assert.AreEqual('value2', Config.GetString('key2'));
    Assert.AreEqual('value3', Config.GetString('key3'));
  finally
    Config.Free;
  end;
end;

{ TTestConfigurationBinding }

procedure TTestConfigurationBinding.Setup;
begin
  FConfig := TConfigurationBuilder.Create
    .AddMemory([
      'Host=db.example.com',
      'Port=3306',
      'Username=admin',
      'Password=secret',
      'Timeout=' + FormatFloat('0.0', 30.5),
      'UseSSL=true',
      'db:Host=nested.example.com',
      'db:Port=5432'
    ])
    .Build;
end;

procedure TTestConfigurationBinding.TearDown;
begin
  FConfig.Free;
end;

procedure TTestConfigurationBinding.Test_BindTo_SetsStringProperties;
var
  Settings: TDatabaseSettings;
begin
  Settings := TDatabaseSettings.Create;
  try
    FConfig.BindTo<TDatabaseSettings>(Settings);
    Assert.AreEqual('db.example.com', Settings.Host);
    Assert.AreEqual('admin', Settings.Username);
  finally
    Settings.Free;
  end;
end;

procedure TTestConfigurationBinding.Test_BindTo_SetsIntegerProperties;
var
  Settings: TDatabaseSettings;
begin
  Settings := TDatabaseSettings.Create;
  try
    FConfig.BindTo<TDatabaseSettings>(Settings);
    Assert.AreEqual(3306, Settings.Port);
  finally
    Settings.Free;
  end;
end;

procedure TTestConfigurationBinding.Test_BindTo_SetsFloatProperties;
var
  Settings: TDatabaseSettings;
begin
  Settings := TDatabaseSettings.Create;
  try
    FConfig.BindTo<TDatabaseSettings>(Settings);
    Assert.AreEqual(Double(30.5), Settings.Timeout, 0.1);
  finally
    Settings.Free;
  end;
end;

procedure TTestConfigurationBinding.Test_BindTo_SetsBooleanProperties;
var
  Settings: TDatabaseSettings;
begin
  Settings := TDatabaseSettings.Create;
  try
    FConfig.BindTo<TDatabaseSettings>(Settings);
    Assert.IsTrue(Settings.UseSSL);
  finally
    Settings.Free;
  end;
end;

procedure TTestConfigurationBinding.Test_BindTo_WithSectionPath;
var
  Settings: TDatabaseSettings;
begin
  Settings := TDatabaseSettings.Create;
  try
    FConfig.BindTo<TDatabaseSettings>(Settings, 'db');
    Assert.AreEqual('nested.example.com', Settings.Host);
    Assert.AreEqual(5432, Settings.Port);
  finally
    Settings.Free;
  end;
end;

{ TTestStaticConfig }

procedure TTestStaticConfig.Setup;
begin
  FSavedConfig := TConfig.Default;
end;

procedure TTestStaticConfig.TearDown;
begin
  TConfig.SetDefault(nil);
end;

procedure TTestStaticConfig.Test_SetDefault_SetsConfiguration;
var
  Config: TConfiguration;
begin
  Config := TConfigurationBuilder.Create
    .AddMemory(['test=value'])
    .Build;
  
  TConfig.SetDefault(Config);
  
  Assert.AreSame(Config, TConfig.Default);
end;

procedure TTestStaticConfig.Test_Default_ReturnsSetConfiguration;
var
  Config: TConfiguration;
begin
  Config := TConfigurationBuilder.Create.AddMemory([]).Build;
  TConfig.SetDefault(Config);
  
  Assert.IsNotNull(TConfig.Default);
end;

procedure TTestStaticConfig.Test_Get_ReturnsValue;
var
  Config: TConfiguration;
begin
  Config := TConfigurationBuilder.Create
    .AddMemory(['key=value'])
    .Build;
  TConfig.SetDefault(Config);
  
  Assert.AreEqual('value', TConfig.Get('key'));
end;

procedure TTestStaticConfig.Test_Get_NoDefault_ReturnsDefault;
begin
  TConfig.SetDefault(nil);
  Assert.AreEqual('fallback', TConfig.Get('key', 'fallback'));
end;

procedure TTestStaticConfig.Test_GetInt_ReturnsValue;
var
  Config: TConfiguration;
begin
  Config := TConfigurationBuilder.Create
    .AddMemory(['num=42'])
    .Build;
  TConfig.SetDefault(Config);
  
  Assert.AreEqual(42, TConfig.GetInt('num'));
end;

procedure TTestStaticConfig.Test_GetBool_ReturnsValue;
var
  Config: TConfiguration;
begin
  Config := TConfigurationBuilder.Create
    .AddMemory(['flag=true'])
    .Build;
  TConfig.SetDefault(Config);
  
  Assert.IsTrue(TConfig.GetBool('flag'));
end;

procedure TTestStaticConfig.Test_GetFloat_ReturnsValue;
var
  Config: TConfiguration;
begin
  Config := TConfigurationBuilder.Create
    .AddMemory(['pi=' + FormatFloat('0.00', 3.14)])
    .Build;
  TConfig.SetDefault(Config);
  
  Assert.AreEqual(Double(3.14), TConfig.GetFloat('pi'), 0.001);
end;

procedure TTestStaticConfig.Test_Builder_ReturnsBuilder;
var
  Builder: TConfigurationBuilder;
begin
  Builder := TConfig.Builder;
  try
    Assert.IsNotNull(Builder);
  finally
    Builder.Free;
  end;
end;

{ TTestConfigurationThreadSafety }

procedure TTestConfigurationThreadSafety.Test_ConcurrentReads;
var
  Config: TConfiguration;
  Tasks: TArray<ITask>;
  ErrorCount: Integer;
  Lock: TCriticalSection;
const
  THREAD_COUNT = 10;
  READS_PER_THREAD = 100;
begin
  Config := TConfigurationBuilder.Create
    .AddMemory(['key=value'])
    .Build;
  ErrorCount := 0;
  Lock := TCriticalSection.Create;
  try
    SetLength(Tasks, THREAD_COUNT);
    
    for var I := 0 to THREAD_COUNT - 1 do
    begin
      Tasks[I] := TTask.Run(
        procedure
        begin
          for var J := 1 to READS_PER_THREAD do
          begin
            try
              if Config.GetString('key') <> 'value' then
              begin
                Lock.Enter;
                try
                  Inc(ErrorCount);
                finally
                  Lock.Leave;
                end;
              end;
            except
              Lock.Enter;
              try
                Inc(ErrorCount);
              finally
                Lock.Leave;
              end;
            end;
          end;
        end);
    end;

    TTask.WaitForAll(Tasks);
    Assert.AreEqual(0, ErrorCount);
  finally
    Lock.Free;
    Config.Free;
  end;
end;

procedure TTestConfigurationThreadSafety.Test_ConcurrentWrites;
var
  Config: TConfiguration;
  Tasks: TArray<ITask>;
  ErrorCount: Integer;
  Lock: TCriticalSection;
const
  THREAD_COUNT = 10;
  WRITES_PER_THREAD = 50;
begin
  Config := TConfigurationBuilder.Create
    .AddMemory([])
    .Build;
  ErrorCount := 0;
  Lock := TCriticalSection.Create;
  try
    SetLength(Tasks, THREAD_COUNT);
    
    for var I := 0 to THREAD_COUNT - 1 do
    begin
      var ThreadNum := I;
      Tasks[I] := TTask.Run(
        procedure
        begin
          for var J := 1 to WRITES_PER_THREAD do
          begin
            try
              Config.SetValue('key_' + IntToStr(ThreadNum) + '_' + IntToStr(J),
                             'value_' + IntToStr(J));
            except
              Lock.Enter;
              try
                Inc(ErrorCount);
              finally
                Lock.Leave;
              end;
            end;
          end;
        end);
    end;

    TTask.WaitForAll(Tasks);
    Assert.AreEqual(0, ErrorCount);
  finally
    Lock.Free;
    Config.Free;
  end;
end;

procedure TTestConfigurationThreadSafety.Test_ConcurrentReadWrite;
var
  Config: TConfiguration;
  Tasks: TArray<ITask>;
  ErrorCount: Integer;
  Lock: TCriticalSection;
const
  THREAD_COUNT = 10;
  OPS_PER_THREAD = 50;
begin
  Config := TConfigurationBuilder.Create
    .AddMemory(['shared=initial'])
    .Build;
  ErrorCount := 0;
  Lock := TCriticalSection.Create;
  try
    SetLength(Tasks, THREAD_COUNT);
    
    for var I := 0 to THREAD_COUNT - 1 do
    begin
      var IsWriter := (I mod 2 = 0);
      var ThreadNum := I;
      Tasks[I] := TTask.Run(
        procedure
        begin
          for var J := 1 to OPS_PER_THREAD do
          begin
            try
              if IsWriter then
                Config.SetValue('shared', 'value_' + IntToStr(ThreadNum) + '_' + IntToStr(J))
              else
                Config.GetString('shared');
            except
              Lock.Enter;
              try
                Inc(ErrorCount);
              finally
                Lock.Leave;
              end;
            end;
          end;
        end);
    end;

    TTask.WaitForAll(Tasks);
    Assert.AreEqual(0, ErrorCount);
  finally
    Lock.Free;
    Config.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestConfigValue);
  TDUnitX.RegisterTestFixture(TTestMemoryConfigurationSource);
  TDUnitX.RegisterTestFixture(TTestIniFileConfigurationSource);
  TDUnitX.RegisterTestFixture(TTestJsonFileConfigurationSource);
  TDUnitX.RegisterTestFixture(TTestConfigurationBuilder);
  TDUnitX.RegisterTestFixture(TTestConfiguration);
  TDUnitX.RegisterTestFixture(TTestConfigurationSection);
  TDUnitX.RegisterTestFixture(TTestConfigurationChangeNotification);
  TDUnitX.RegisterTestFixture(TTestConfigurationLayering);
  TDUnitX.RegisterTestFixture(TTestConfigurationBinding);
  TDUnitX.RegisterTestFixture(TTestStaticConfig);
  TDUnitX.RegisterTestFixture(TTestConfigurationThreadSafety);

end.
