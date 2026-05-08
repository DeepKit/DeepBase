unit Test.DeepBase.Config;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils, System.Classes, System.Generics.Collections,
  DeepBase.Types, DeepBase.Manager, DeepBase.Config, DeepBase.Storage.Interfaces;

type
  [TestFixture]
  TTestDeepBaseConfig = class
  private
    FConfig: TDeepBaseConfig;
    FManager: TDeepBaseManager;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_GetSetConfig_String;
    
    [Test]
    procedure Test_GetSetConfig_Integer;
    
    [Test]
    procedure Test_GetSetConfig_Boolean;

    [Test]
    procedure Test_StorageInjection_WorksWithoutManagerDB;
  end;

implementation

type
  TInMemoryConfigStorage = class(TInterfacedObject, IConfigStorage)
  private
    FValues: TDictionary<string, string>;
    FCategories: TDictionary<string, string>;
  public
    constructor Create;
    destructor Destroy; override;
    function ReadValue(const Key: string; const Default: string = ''): string;
    procedure WriteValue(const Key, Value, Category, ValueType,
      Description: string);
    procedure LoadAll(AValues: TDictionary<string, string>);
    procedure LoadByCategory(const Category: string;
      AValues: TDictionary<string, string>);
    procedure DeleteValue(const Key: string);
    function ValueExists(const Key: string): Boolean;
  end;

constructor TInMemoryConfigStorage.Create;
begin
  inherited Create;
  FValues := TDictionary<string, string>.Create;
  FCategories := TDictionary<string, string>.Create;
end;

destructor TInMemoryConfigStorage.Destroy;
begin
  FCategories.Free;
  FValues.Free;
  inherited;
end;

function TInMemoryConfigStorage.ReadValue(const Key: string;
  const Default: string): string;
begin
  if not FValues.TryGetValue(Key, Result) then
    Result := Default;
end;

procedure TInMemoryConfigStorage.WriteValue(const Key, Value, Category, ValueType,
  Description: string);
begin
  FValues.AddOrSetValue(Key, Value);
  FCategories.AddOrSetValue(Key, Category);
end;

procedure TInMemoryConfigStorage.LoadAll(AValues: TDictionary<string, string>);
var
  Pair: TPair<string, string>;
begin
  if not Assigned(AValues) then
    Exit;
  AValues.Clear;
  for Pair in FValues do
    AValues.AddOrSetValue(Pair.Key, Pair.Value);
end;

procedure TInMemoryConfigStorage.LoadByCategory(const Category: string;
  AValues: TDictionary<string, string>);
var
  Pair: TPair<string, string>;
  KeyCategory: string;
begin
  if not Assigned(AValues) then
    Exit;
  AValues.Clear;

  for Pair in FValues do
  begin
    if FCategories.TryGetValue(Pair.Key, KeyCategory) and
       SameText(KeyCategory, Category) then
      AValues.AddOrSetValue(Pair.Key, Pair.Value);
  end;
end;

procedure TInMemoryConfigStorage.DeleteValue(const Key: string);
begin
  FValues.Remove(Key);
  FCategories.Remove(Key);
end;

function TInMemoryConfigStorage.ValueExists(const Key: string): Boolean;
begin
  Result := FValues.ContainsKey(Key);
end;

procedure TTestDeepBaseConfig.Setup;
begin
  FManager := DeepBase.Manager.DeepBase;
  if not FManager.IsInitialized then
    FManager.InitializeWithDB(':memory:');
  FConfig := FManager.Config;
end;

procedure TTestDeepBaseConfig.TearDown;
begin
  FConfig := nil;
end;

procedure TTestDeepBaseConfig.Test_GetSetConfig_String;
var
  Key, Value, Retrieved: string;
begin
  Key := 'test.string.key';
  Value := 'Hello DeepBase';
  
  FConfig.SetConfig(Key, Value);
  Retrieved := FConfig.GetConfig(Key);
  
  Assert.AreEqual(Value, Retrieved, 'String value should match');
end;

procedure TTestDeepBaseConfig.Test_GetSetConfig_Integer;
var
  Key: string;
  Value, Retrieved: Integer;
begin
  Key := 'test.int.key';
  Value := 12345;
  
  FConfig.SetConfigInt(Key, Value);
  Retrieved := FConfig.GetConfigInt(Key);
  
  Assert.AreEqual(Value, Retrieved, 'Integer value should match');
end;

procedure TTestDeepBaseConfig.Test_GetSetConfig_Boolean;
var
  Key: string;
  Value, Retrieved: Boolean;
begin
  Key := 'test.bool.key';
  Value := True;
  FConfig.SetConfigBool(Key, Value);
  Retrieved := FConfig.GetConfigBool(Key);
  Assert.AreEqual(Value, Retrieved, 'Boolean True should match');
  
  Value := False;
  FConfig.SetConfigBool(Key, Value);
  Retrieved := FConfig.GetConfigBool(Key);
  Assert.AreEqual(Value, Retrieved, 'Boolean False should match');
end;

procedure TTestDeepBaseConfig.Test_StorageInjection_WorksWithoutManagerDB;
var
  Storage: IConfigStorage;
  LocalConfig: TDeepBaseConfig;
begin
  Storage := TInMemoryConfigStorage.Create;
  LocalConfig := TDeepBaseConfig.Create(Storage);
  try
    LocalConfig.SetConfig('Inject.Key', 'InjectValue', 'InjectCategory');
    Assert.AreEqual('InjectValue', LocalConfig.GetConfig('Inject.Key'),
      'Injected storage read/write should work');
    Assert.IsTrue(LocalConfig.ConfigExists('Inject.Key'),
      'Injected storage should support existence checks');

    LocalConfig.DeleteConfig('Inject.Key');
    Assert.IsFalse(LocalConfig.ConfigExists('Inject.Key'),
      'Injected storage delete should remove key');
  finally
    LocalConfig.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDeepBaseConfig);

end.
