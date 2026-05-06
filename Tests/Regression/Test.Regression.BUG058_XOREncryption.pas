{ ============================================================================
  Test.Regression.BUG058_XOREncryption - XOR加密安全缺陷回归测试

  BUG-058: 配置XOR加密安全缺陷
  
  原问题: GetConfigEncrypted和SetConfigEncrypted使用XOR混淆而非真正加密，
          XOR加密是可逆的简单操作，不提供真正的安全保护。
  
  修复方案: 完全移除XOR实现，强制抛出异常引导用户使用
            UniBase.Security.SaveSecret() 进行安全的DPAPI加密。
  
  修复日期: 2025-01-27
  文件: Core/UniBase.Config.pas
  优先级: P0 (Critical)
  分类: Security
  ============================================================================ }

unit Test.Regression.BUG058_XOREncryption;

interface

uses
  System.SysUtils,
  System.Classes,
  DUnitX.TestFramework,
  Test.Regression.Base;

type
  [TestFixture]
  [Category('Regression')]
  [Category('P0')]
  [Category('Security')]
  TBug058_XOREncryptionTest = class(TRegressionTestBase)
  protected
    function GetBugNumber: string; override;
    function GetBugDescription: string; override;
    function GetFixDate: string; override;
    function GetPriority: string; override;
    function GetAffectedFile: string; override;
  public
    [Test]
    [Description('验证 GetConfigEncrypted 已被禁用并抛出 ENotSupportedException')]
    procedure Test_GetConfigEncrypted_ShouldRaiseException;
    
    [Test]
    [Description('验证 SetConfigEncrypted 已被禁用并抛出 ENotSupportedException')]
    procedure Test_SetConfigEncrypted_ShouldRaiseException;
    
    [Test]
    [Description('验证异常消息包含正确的迁移指引')]
    procedure Test_ExceptionMessage_ContainsMigrationGuidance;
    
    [Test]
    [Description('验证 Security.SaveSecret/LoadSecret 作为替代方案正常工作')]
    procedure Test_SecurityModule_ShouldWorkAsReplacement;
  end;

implementation

uses
  UniBase.Config,
  UniBase.Security,
  UniBase.Manager;

{ TBug058_XOREncryptionTest }

function TBug058_XOREncryptionTest.GetBugNumber: string;
begin
  Result := 'BUG-058';
end;

function TBug058_XOREncryptionTest.GetBugDescription: string;
begin
  Result := '配置XOR加密安全缺陷';
end;

function TBug058_XOREncryptionTest.GetFixDate: string;
begin
  Result := '2025-01-27';
end;

function TBug058_XOREncryptionTest.GetPriority: string;
begin
  Result := 'P0';
end;

function TBug058_XOREncryptionTest.GetAffectedFile: string;
begin
  Result := 'Core/UniBase.Config.pas';
end;

procedure TBug058_XOREncryptionTest.Test_GetConfigEncrypted_ShouldRaiseException;
var
  Config: TUniBaseConfig;
  ExceptionRaised: Boolean;
begin
  LogTestStart('Test_GetConfigEncrypted_ShouldRaiseException');
  ExceptionRaised := False;
  
  // 获取配置实例
  Config := UBConfig;
  if not Assigned(Config) then
  begin
    // 如果 UniBase 未初始化，跳过测试
    Assert.Pass('UniBase not initialized, skipping test');
    Exit;
  end;
  
  try
    {$WARNINGS OFF}  // 忽略 deprecated 警告
    Config.GetConfigEncrypted('test_key');
    {$WARNINGS ON}
  except
    on E: ENotSupportedException do
      ExceptionRaised := True;
  end;
  
  Assert.IsTrue(ExceptionRaised, 
    'GetConfigEncrypted 应该抛出 ENotSupportedException，因为 XOR 加密已被移除');
  
  LogTestEnd('Test_GetConfigEncrypted_ShouldRaiseException', True);
end;

procedure TBug058_XOREncryptionTest.Test_SetConfigEncrypted_ShouldRaiseException;
var
  Config: TUniBaseConfig;
  ExceptionRaised: Boolean;
begin
  LogTestStart('Test_SetConfigEncrypted_ShouldRaiseException');
  ExceptionRaised := False;
  
  Config := UBConfig;
  if not Assigned(Config) then
  begin
    Assert.Pass('UniBase not initialized, skipping test');
    Exit;
  end;
  
  try
    {$WARNINGS OFF}
    Config.SetConfigEncrypted('test_key', 'test_value');
    {$WARNINGS ON}
  except
    on E: ENotSupportedException do
      ExceptionRaised := True;
  end;
  
  Assert.IsTrue(ExceptionRaised,
    'SetConfigEncrypted 应该抛出 ENotSupportedException，因为 XOR 加密已被移除');
  
  LogTestEnd('Test_SetConfigEncrypted_ShouldRaiseException', True);
end;

procedure TBug058_XOREncryptionTest.Test_ExceptionMessage_ContainsMigrationGuidance;
var
  Config: TUniBaseConfig;
  ErrorMessage: string;
begin
  LogTestStart('Test_ExceptionMessage_ContainsMigrationGuidance');
  ErrorMessage := '';
  
  Config := UBConfig;
  if not Assigned(Config) then
  begin
    Assert.Pass('UniBase not initialized, skipping test');
    Exit;
  end;
  
  try
    {$WARNINGS OFF}
    Config.GetConfigEncrypted('test_key');
    {$WARNINGS ON}
  except
    on E: ENotSupportedException do
      ErrorMessage := E.Message;
  end;
  
  // 验证错误消息包含迁移指引
  Assert.IsTrue(ErrorMessage.Contains('UniBase.Security'),
    '异常消息应该包含 "UniBase.Security" 迁移指引');
  Assert.IsTrue(ErrorMessage.Contains('DPAPI') or ErrorMessage.Contains('LoadSecret'),
    '异常消息应该提及 DPAPI 或 LoadSecret 作为替代方案');
  
  LogTestEnd('Test_ExceptionMessage_ContainsMigrationGuidance', True);
end;

procedure TBug058_XOREncryptionTest.Test_SecurityModule_ShouldWorkAsReplacement;
var
  SecretName: string;
  SecretValue: string;
  RetrievedValue: string;
begin
  LogTestStart('Test_SecurityModule_ShouldWorkAsReplacement');
  
  if (not UniBase.Manager.UniBase.IsInitialized) or
     (not Assigned(UniBase.Manager.UniBase.Security)) then
  begin
    Assert.Pass('UniBase not initialized, skipping test');
    Exit;
  end;

  // 使用唯一的密钥名避免冲突
  SecretName := 'regression_test_bug058_' + IntToStr(TThread.GetTickCount);
  SecretValue := 'my_secure_password_12345';

  try
    // 使用安全的 DPAPI 存储
    UniBase.Manager.UniBase.Security.SaveSecret(SecretName, SecretValue);

    // 读取并验证
    RetrievedValue := UniBase.Manager.UniBase.Security.LoadSecret(SecretName);

    Assert.AreEqual(SecretValue, RetrievedValue,
      'Security.SaveSecret/LoadSecret 应该正确保存和读取密钥');
  finally
    // 清理测试数据
    try
      UniBase.Manager.UniBase.Security.DeleteSecret(SecretName);
    except
      // 忽略清理错误
    end;
  end;
  
  LogTestEnd('Test_SecurityModule_ShouldWorkAsReplacement', True);
end;

initialization
  TDUnitX.RegisterTestFixture(TBug058_XOREncryptionTest);

end.
