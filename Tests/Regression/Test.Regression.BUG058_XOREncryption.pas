{ ============================================================================
  Test.Regression.BUG058_XOREncryption - XOR加密安全缺陷回归测试

  BUG-058: 配置XOR加密安全缺陷
  
  原问题: GetConfigEncrypted和SetConfigEncrypted使用XOR混淆而非真正加密。
          XOR加密是可逆的简单操作，不提供真正的安全保护。
  
  修复方案: 完全移除方法声明，强制编译时错误引导用户使用
            DeepBase.Security.SaveSecret() 进行安全的DPAPI加密。
  
  修复日期: 2025-01-27
  文件: Core/DeepBase.Config.pas, Core/DeepBase.Interfaces.pas
  优先级: P0 (Critical)
  分类: Security
  ============================================================================ }

unit Test.Regression.BUG058_XOREncryption;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
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
    [Description('验证 IDeepBaseConfig 接口不再包含 GetConfigEncrypted 方法')]
    procedure Test_Interface_NoGetConfigEncrypted;

    [Test]
    [Description('验证 IDeepBaseConfig 接口不再包含 SetConfigEncrypted 方法')]
    procedure Test_Interface_NoSetConfigEncrypted;

    [Test]
    [Description('验证 IDeepBaseConfig GUID 已更新为新版本')]
    procedure Test_Interface_GUIDChanged;

    [Test]
    [Description('验证 Security.SaveSecret/LoadSecret 作为替代方案正常工作')]
    procedure Test_SecurityModule_ShouldWorkAsReplacement;
  end;

implementation

uses
  DeepBase.Interfaces,
  DeepBase.Security,
  DeepBase.Manager;

{ TBug058_XOREncryptionTest }

function TBug058_XOREncryptionTest.GetBugNumber: string;
begin
  Result := 'BUG-058';
end;

function TBug058_XOREncryptionTest.GetBugDescription: string;
begin
  Result := '配置XOR加密安全缺陷 - 方法已完全移除';
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
  Result := 'Core/DeepBase.Config.pas';
end;

procedure TBug058_XOREncryptionTest.Test_Interface_NoGetConfigEncrypted;
var
  RttiCtx: TRttiContext;
  RttiType: TRttiType;
  Method: TRttiMethod;
begin
  LogTestStart('Test_Interface_NoGetConfigEncrypted');

  RttiCtx := TRttiContext.Create;
  try
    RttiType := RttiCtx.GetType(TypeInfo(IDeepBaseConfig));
    if RttiType = nil then
    begin
      Assert.Fail('Cannot get RTTI for IDeepBaseConfig');
      Exit;
    end;

    Method := RttiType.GetMethod('GetConfigEncrypted');
    Assert.IsNull(Method,
      'IDeepBaseConfig should no longer declare GetConfigEncrypted');
  finally
    RttiCtx.Free;
  end;

  LogTestEnd('Test_Interface_NoGetConfigEncrypted', True);
end;

procedure TBug058_XOREncryptionTest.Test_Interface_NoSetConfigEncrypted;
var
  RttiCtx: TRttiContext;
  RttiType: TRttiType;
  Method: TRttiMethod;
begin
  LogTestStart('Test_Interface_NoSetConfigEncrypted');

  RttiCtx := TRttiContext.Create;
  try
    RttiType := RttiCtx.GetType(TypeInfo(IDeepBaseConfig));
    if RttiType = nil then
    begin
      Assert.Fail('Cannot get RTTI for IDeepBaseConfig');
      Exit;
    end;

    Method := RttiType.GetMethod('SetConfigEncrypted');
    Assert.IsNull(Method,
      'IDeepBaseConfig should no longer declare SetConfigEncrypted');
  finally
    RttiCtx.Free;
  end;

  LogTestEnd('Test_Interface_NoSetConfigEncrypted', True);
end;

procedure TBug058_XOREncryptionTest.Test_Interface_GUIDChanged;
var
  ExpectedGUID: TGUID;
  ActualGUID: TGUID;
begin
  LogTestStart('Test_Interface_GUIDChanged');

  // The new GUID after the breaking interface change (last char D→E)
  ExpectedGUID := StringToGUID('{A1B2C3D4-E5F6-4A5B-8C9D-0E1F2A3B4C5E}');
  ActualGUID := IDeepBaseConfig;

  Assert.IsTrue(IsEqualGUID(ExpectedGUID, ActualGUID),
    'IDeepBaseConfig GUID should be {A1B2C3D4-E5F6-4A5B-8C9D-0E1F2A3B4C5E}');

  LogTestEnd('Test_Interface_GUIDChanged', True);
end;

procedure TBug058_XOREncryptionTest.Test_SecurityModule_ShouldWorkAsReplacement;
var
  SecretName: string;
  SecretValue: string;
  RetrievedValue: string;
begin
  LogTestStart('Test_SecurityModule_ShouldWorkAsReplacement');

  if (not DeepBase.Manager.DeepBase.IsInitialized) or
     (not Assigned(DeepBase.Manager.DeepBase.Security)) then
  begin
    Assert.Pass('DeepBase not initialized, skipping test');
    Exit;
  end;

  // 使用唯一的密钥名避免冲突
  SecretName := 'regression_test_bug058_' + IntToStr(TThread.GetTickCount);
  SecretValue := 'my_secure_password_12345';

  try
    // 使用安全的 DPAPI 存储
    DeepBase.Manager.DeepBase.Security.SaveSecret(SecretName, SecretValue);

    // 读取并验证
    RetrievedValue := DeepBase.Manager.DeepBase.Security.LoadSecret(SecretName);

    Assert.AreEqual(SecretValue, RetrievedValue,
      'Security.SaveSecret/LoadSecret should correctly save and retrieve secrets');
  finally
    // 清理测试数据
    try
      DeepBase.Manager.DeepBase.Security.DeleteSecret(SecretName);
    except
      // 忽略清理错误
    end;
  end;

  LogTestEnd('Test_SecurityModule_ShouldWorkAsReplacement', True);
end;

initialization
  TDUnitX.RegisterTestFixture(TBug058_XOREncryptionTest);

end.
