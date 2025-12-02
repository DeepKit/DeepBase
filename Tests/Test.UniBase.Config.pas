unit Test.UniBase.Config;

{*******************************************************************************
  UniBase Config 模块单元测试
  
  测试内容:
  - GetConfig / SetConfig (各类型)
  - 类型转换
  - 默认值
  - 缓存机制
  - 线程安全
*******************************************************************************}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils, System.Classes, System.SyncObjs, System.Threading,
  System.Generics.Collections,  // R-005: 添加 TDictionary 支持
  UniBase.Types, UniBase.Manager, UniBase.Config;

type
  [TestFixture]
  TTestUniBaseConfig = class
  private
    FConfig: TUniBaseConfig;
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
    procedure Test_GetSetConfig_Float;
    
    [Test]
    procedure Test_GetConfig_DefaultValue_WhenKeyNotExists;
    
    [Test]
    procedure Test_GetConfigInt_InvalidValue_ReturnsDefault;
    
    [Test]
    procedure Test_GetConfigBool_VariousFormats;
    
    [Test]
    procedure Test_DeleteConfig;
    
    [Test]
    procedure Test_ConfigExists;
    
    [Test]
    procedure Test_GetAllConfigs;
    
    [Test]
    procedure Test_Cache_ReturnsConsistentValue;
    
    [Test]
    procedure Test_ThreadSafety_ConcurrentReadWrite;
    
    [Test]
    procedure Test_OnConfigChanged_Event;
    
    [Test]
    procedure Test_SetGetConfigEncrypted;
    
    [Test]
    procedure Test_EncryptedConfig_StoredDifferently;
    
    [Test]
    procedure Test_EncryptedConfig_NotInCache;
  end;

implementation

uses
  UniBase.Security;

{ TTestUniBaseConfig }

procedure TTestUniBaseConfig.Setup;
begin
  // R-005: 使用正确的 InitializeWithDB 方法
  if not UniBase.IsInitialized then
    UniBase.InitializeWithDB(':memory:');
  
  FConfig := UniBase.Config;
end;

procedure TTestUniBaseConfig.TearDown;
begin
  // Config 由 Manager 管理，不需要手动释放
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
  
  Assert.AreEqual(Value, Retrieved, '字符串值应该正确读写');
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
  
  Assert.AreEqual(Value, Retrieved, '整数值应该正确读写');
end;

procedure TTestUniBaseConfig.Test_GetSetConfig_Boolean;
var
  Key: string;
  Value, Retrieved: Boolean;
begin
  Key := 'test.bool.key';
  
  // 测试 True
  Value := True;
  FConfig.SetConfigBool(Key, Value);
  Retrieved := FConfig.GetConfigBool(Key);
  Assert.AreEqual(Value, Retrieved, 'Boolean True 应该正确读写');
  
  // 测试 False
  Value := False;
  FConfig.SetConfigBool(Key, Value);
  Retrieved := FConfig.GetConfigBool(Key);
  Assert.AreEqual(Value, Retrieved, 'Boolean False 应该正确读写');
end;

procedure TTestUniBaseConfig.Test_GetSetConfig_Float;
var
  Key: string;
  Value, Retrieved: Double;
begin
  Key := 'test.float.key';
  Value := 3.14159265;
  
  FConfig.SetConfigFloat(Key, Value);
  Retrieved := FConfig.GetConfigFloat(Key);
  
  Assert.AreEqual(Value, Retrieved, 0.0001, '浮点值应该正确读写');
end;

procedure TTestUniBaseConfig.Test_GetConfig_DefaultValue_WhenKeyNotExists;
var
  Key, DefaultValue, Retrieved: string;
begin
  Key := 'test.nonexistent.key.' + TGUID.NewGuid.ToString;
  DefaultValue := 'DefaultValue';
  
  Retrieved := FConfig.GetConfig(Key, DefaultValue);
  
  Assert.AreEqual(DefaultValue, Retrieved, '不存在的 key 应该返回默认值');
end;

procedure TTestUniBaseConfig.Test_GetConfigInt_InvalidValue_ReturnsDefault;
var
  Key: string;
  DefaultValue, Retrieved: Integer;
begin
  Key := 'test.invalid.int';
  DefaultValue := 999;
  
  // 先存一个无效的整数字符串
  FConfig.SetConfig(Key, 'not_a_number');
  
  Retrieved := FConfig.GetConfigInt(Key, DefaultValue);
  
  Assert.AreEqual(DefaultValue, Retrieved, '无效整数应该返回默认值');
end;

procedure TTestUniBaseConfig.Test_GetConfigBool_VariousFormats;
var
  Key: string;
begin
  Key := 'test.bool.formats';
  
  // 测试各种 True 格式
  FConfig.SetConfig(Key, '1');
  Assert.IsTrue(FConfig.GetConfigBool(Key), '"1" 应该解析为 True');
  
  FConfig.SetConfig(Key, 'true');
  Assert.IsTrue(FConfig.GetConfigBool(Key), '"true" 应该解析为 True');
  
  FConfig.SetConfig(Key, 'TRUE');
  Assert.IsTrue(FConfig.GetConfigBool(Key), '"TRUE" 应该解析为 True');
  
  FConfig.SetConfig(Key, 'yes');
  Assert.IsTrue(FConfig.GetConfigBool(Key), '"yes" 应该解析为 True');
  
  // 测试各种 False 格式
  FConfig.SetConfig(Key, '0');
  Assert.IsFalse(FConfig.GetConfigBool(Key), '"0" 应该解析为 False');
  
  FConfig.SetConfig(Key, 'false');
  Assert.IsFalse(FConfig.GetConfigBool(Key), '"false" 应该解析为 False');
end;

procedure TTestUniBaseConfig.Test_DeleteConfig;
var
  Key: string;
begin
  Key := 'test.delete.key';
  
  FConfig.SetConfig(Key, 'ToBeDeleted');
  Assert.IsTrue(FConfig.ConfigExists(Key), '设置后 key 应该存在');
  
  FConfig.DeleteConfig(Key);
  Assert.IsFalse(FConfig.ConfigExists(Key), '删除后 key 不应该存在');
end;

procedure TTestUniBaseConfig.Test_ConfigExists;
var
  Key: string;
begin
  Key := 'test.exists.key';
  
  Assert.IsFalse(FConfig.ConfigExists(Key), '未设置前 key 不应该存在');
  
  FConfig.SetConfig(Key, 'Value');
  Assert.IsTrue(FConfig.ConfigExists(Key), '设置后 key 应该存在');
end;

procedure TTestUniBaseConfig.Test_GetAllConfigs;
var
  Configs: TDictionary<string, string>;  // R-005: 使用正确的返回类型
  Value: string;
const
  TEST_CATEGORY = 'TestAll';
begin
  // 设置一些配置，使用相同的 Category
  FConfig.SetConfig('test.all.key1', 'Value1', TEST_CATEGORY);
  FConfig.SetConfig('test.all.key2', 'Value2', TEST_CATEGORY);
  
  // R-005: 使用正确的 GetConfigsByCategory 方法
  Configs := FConfig.GetConfigsByCategory(TEST_CATEGORY);
  try
    Assert.IsTrue(Configs.Count >= 2, '应该至少返回 2 个配置项');
    
    // 检查是否包含我们设置的 key
    Assert.IsTrue(Configs.TryGetValue('test.all.key1', Value), '应该找到 test.all.key1');
    Assert.AreEqual('Value1', Value, 'key1 的值应该正确');
    
    Assert.IsTrue(Configs.TryGetValue('test.all.key2', Value), '应该找到 test.all.key2');
    Assert.AreEqual('Value2', Value, 'key2 的值应该正确');
  finally
    Configs.Free;  // GetConfigsByCategory 返回的字典需要调用者释放
  end;
end;

procedure TTestUniBaseConfig.Test_Cache_ReturnsConsistentValue;
var
  Key: string;
  Value1, Value2: string;
begin
  Key := 'test.cache.key';
  
  FConfig.SetConfig(Key, 'CachedValue');
  
  // 多次读取应该返回相同值
  Value1 := FConfig.GetConfig(Key);
  Value2 := FConfig.GetConfig(Key);
  
  Assert.AreEqual(Value1, Value2, '多次读取应该返回一致的值');
end;

procedure TTestUniBaseConfig.Test_ThreadSafety_ConcurrentReadWrite;
var
  Tasks: array[0..9] of ITask;
  I: Integer;
  Errors: Integer;
  Key: string;
begin
  Key := 'test.thread.key';
  Errors := 0;
  
  // 创建 10 个并发任务
  for I := 0 to 9 do
  begin
    Tasks[I] := TTask.Create(
      procedure
      var
        J: Integer;
        Value: string;
      begin
        try
          for J := 1 to 100 do
          begin
            // 交替读写
            FConfig.SetConfig(Key, 'Value' + IntToStr(J));
            Value := FConfig.GetConfig(Key);
            // 简单验证值不为空
            if Value = '' then
              TInterlocked.Increment(Errors);
          end;
        except
          TInterlocked.Increment(Errors);
        end;
      end
    );
  end;
  
  // 启动所有任务
  for I := 0 to 9 do
    Tasks[I].Start;
    
  // 等待所有任务完成
  TTask.WaitForAll(Tasks);
  
  Assert.AreEqual(0, Errors, '并发读写不应该产生错误');
end;

procedure TTestUniBaseConfig.Test_OnConfigChanged_Event;
var
  Key: string;
  EventFired: Boolean;
  ChangedKey: string;
begin
  Key := 'test.event.key';
  EventFired := False;
  ChangedKey := '';
  
  FConfig.OnConfigChanged := 
    procedure(const AKey: string)
    begin
      EventFired := True;
      ChangedKey := AKey;
    end;
  
  try
    FConfig.SetConfig(Key, 'NewValue');
    
    Assert.IsTrue(EventFired, 'OnConfigChanged 事件应该被触发');
    Assert.AreEqual(Key, ChangedKey, '事件应该传递正确的 key');
  finally
    FConfig.OnConfigChanged := nil;
  end;
end;

procedure TTestUniBaseConfig.Test_SetGetConfigEncrypted;
var
  Key, Value, Retrieved: string;
begin
  Key := 'test.encrypted.apikey';
  Value := 'sk-abc123secretkey';
  
  FConfig.SetConfigEncrypted(Key, Value);
  Retrieved := FConfig.GetConfigEncrypted(Key);
  
  Assert.AreEqual(Value, Retrieved, 'Encrypted value should be correctly decrypted');
end;

procedure TTestUniBaseConfig.Test_EncryptedConfig_StoredDifferently;
var
  Key, Value, PlainStored: string;
begin
  Key := 'test.encrypted.password';
  Value := 'MySecretPassword123!';
  
  FConfig.SetConfigEncrypted(Key, Value);
  
  // Encrypted secrets should no longer be stored in Settings table
  PlainStored := FConfig.GetConfig(Key, '__default__');
  
  Assert.AreEqual('__default__', PlainStored, 'Encrypted value should not be stored in plain Settings table');
  Assert.IsTrue(SecretExists(Key), 'Encrypted value should be stored in UniBase.Security secrets store');
end;

procedure TTestUniBaseConfig.Test_EncryptedConfig_NotInCache;
var
  Key, Value: string;
begin
  Key := 'test.encrypted.nocache';
  Value := 'SensitiveData';
  
  FConfig.SetConfigEncrypted(Key, Value);
  
  // After setting encrypted, getting plain should hit DB
  // (since encrypted values are removed from cache for security)
  // This test just verifies the flow doesn't crash
  Assert.AreEqual(Value, FConfig.GetConfigEncrypted(Key), 
    'Should retrieve encrypted value correctly');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestUniBaseConfig);

end.
