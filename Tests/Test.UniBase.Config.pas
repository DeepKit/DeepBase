unit Test.UniBase.Config;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils, System.Classes,
  UniBase.Types, UniBase.Manager, UniBase.Config;

type
  [TestFixture]
  TTestUniBaseConfig = class
  private
    FConfig: TUniBaseConfig;
    FManager: TUniBaseManager;
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
  end;

implementation

procedure TTestUniBaseConfig.Setup;
begin
  FManager := UniBase.Manager.UniBase;
  if not FManager.IsInitialized then
    FManager.InitializeWithDB(':memory:');
  FConfig := FManager.Config;
end;

procedure TTestUniBaseConfig.TearDown;
begin
  FConfig := nil;
end;

procedure TTestUniBaseConfig.Test_GetSetConfig_String;
var
  Key, Value, Retrieved: string;
begin
  Key := 'test.string.key';
  Value := 'Hello UniBase';
  
  FConfig.SetConfig(Key, Value);
  Retrieved := FConfig.GetConfig(Key);
  
  Assert.AreEqual(Value, Retrieved, 'String value should match');
end;

procedure TTestUniBaseConfig.Test_GetSetConfig_Integer;
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

procedure TTestUniBaseConfig.Test_GetSetConfig_Boolean;
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

initialization
  TDUnitX.RegisterTestFixture(TTestUniBaseConfig);

end.