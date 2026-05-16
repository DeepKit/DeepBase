unit Test.DeepBase.License;

{*******************************************************************************
  DeepBase License 模块单元测试
  
  测试内容:
  - License Key 验证
  - 设备指纹
  - 许可证类�?
  - 激�?停用
*******************************************************************************}

interface

uses
  DUnitX.TestFramework,
  Winapi.Windows,
  System.SysUtils, System.Classes, System.DateUtils,
  DeepBase.Types, DeepBase.Manager, DeepBase.License, DeepBase.Storage.Interfaces;

type
  [TestFixture]
  TTestDeepBaseLicense = class
  private
    FLicense: TDeepBaseLicense;
    FPreviousSigningKey: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_GetDeviceId_NotEmpty;
    
    [Test]
    procedure Test_GetDeviceId_Consistent;
    
    [Test]
    procedure Test_ValidateLicense_EmptyKey_Invalid;
    
    [Test]
    procedure Test_ValidateLicense_InvalidFormat;
    
    [Test]
    procedure Test_GenerateLicenseKey_ValidFormat;
    
    [Test]
    procedure Test_GenerateLicenseKey_CanBeValidated;
    
    [Test]
    procedure Test_LicenseInfo_DefaultValues;
    
    [Test]
    procedure Test_LicenseType_Trial;
    
    [Test]
    procedure Test_LicenseType_Standard;
    
    [Test]
    procedure Test_LicenseType_Pro;
    
    [Test]
    procedure Test_LicenseType_Enterprise;
    
    [Test]
    procedure Test_ExpiredLicense_Detected;
    
    [Test]
    procedure Test_ActivateLicense_ValidKey;
    
    [Test]
    procedure Test_DeactivateLicense;
    
    [Test]
    procedure Test_CurrentLicenseInfo;

    [Test]
    procedure Test_StorageInjection_BasicFlow;
  end;

implementation

const
  TEST_LICENSE_SECRET_ENV = 'DEEPBASE_LEGACY_LICENSE_SIGNING_KEY';
  TEST_LICENSE_SECRET = 'DeepBase-License-CI-Only';

type
  TInMemoryLicenseStorage = class(TInterfacedObject, ILicenseStorage)
  private
    FHasValue: Boolean;
    FValue: string;
  public
    function ReadLicenseKey: string;
    procedure WriteLicenseKey(const LicenseKey: string);
    procedure DeleteLicenseKey;
  end;

function TInMemoryLicenseStorage.ReadLicenseKey: string;
begin
  if FHasValue then
    Result := FValue
  else
    Result := '';
end;

procedure TInMemoryLicenseStorage.WriteLicenseKey(const LicenseKey: string);
begin
  FHasValue := True;
  FValue := LicenseKey;
end;

procedure TInMemoryLicenseStorage.DeleteLicenseKey;
begin
  FHasValue := False;
  FValue := '';
end;

{ TTestDeepBaseLicense }

procedure TTestDeepBaseLicense.Setup;
var
  Manager: TDeepBaseManager;
begin
  FPreviousSigningKey := GetEnvironmentVariable(TEST_LICENSE_SECRET_ENV);
  Winapi.Windows.SetEnvironmentVariable(PChar(TEST_LICENSE_SECRET_ENV),
    PChar(TEST_LICENSE_SECRET));

  Manager := DeepBase.Manager.DeepBase;
  if not Manager.IsInitialized then
    Manager.InitializeWithDB(':memory:');
  FLicense := TDeepBaseLicense.Create(Manager.ConfigDB);
end;

procedure TTestDeepBaseLicense.TearDown;
begin
  FreeAndNil(FLicense);
  if FPreviousSigningKey = '' then
    Winapi.Windows.SetEnvironmentVariable(PChar(TEST_LICENSE_SECRET_ENV), nil)
  else
    Winapi.Windows.SetEnvironmentVariable(PChar(TEST_LICENSE_SECRET_ENV),
      PChar(FPreviousSigningKey));
end;

procedure TTestDeepBaseLicense.Test_GetDeviceId_NotEmpty;
var
  DeviceId: string;
begin
  DeviceId := FLicense.GetDeviceId;
  
  Assert.IsNotEmpty(DeviceId, 'device id should not be empty');
end;

procedure TTestDeepBaseLicense.Test_GetDeviceId_Consistent;
var
  Id1, Id2: string;
begin
  Id1 := FLicense.GetDeviceId;
  Id2 := FLicense.GetDeviceId;
  
  Assert.AreEqual(Id1, Id2, '多次调用应该返回相同的设�?ID');
end;

procedure TTestDeepBaseLicense.Test_ValidateLicense_EmptyKey_Invalid;
var
  Info: TLicenseInfo;
begin
  Info := FLicense.ValidateLicense('');
  
  Assert.AreEqual(Ord(lsInvalid), Ord(Info.Status), '�?Key 应该无效');
end;

procedure TTestDeepBaseLicense.Test_ValidateLicense_InvalidFormat;
var
  Info: TLicenseInfo;
begin
  Info := FLicense.ValidateLicense('invalid-license-key-format');
  
  Assert.AreEqual(Ord(lsInvalid), Ord(Info.Status), 'invalid format should be detected');
end;

procedure TTestDeepBaseLicense.Test_GenerateLicenseKey_ValidFormat;
var
  Key: string;
begin
  Key := TDeepBaseLicense.GenerateLicenseKey(
    ltStandard, 
    IncYear(Now, 1),
    'Test User',
    FLicense.GetDeviceId,
    []
  );
  
  Assert.IsNotEmpty(Key, 'generated key should not be empty');
  Assert.Contains(Key, '.', 'key should contain separator');
end;

procedure TTestDeepBaseLicense.Test_GenerateLicenseKey_CanBeValidated;
var
  Key: string;
  Info: TLicenseInfo;
begin
  Key := TDeepBaseLicense.GenerateLicenseKey(
    ltStandard, 
    IncYear(Now, 1),
    'Test User',
    FLicense.GetDeviceId,
    []
  );
  
  Info := FLicense.ValidateLicense(Key);
  
  Assert.AreEqual(Ord(lsValid), Ord(Info.Status), '生成�?Key 应该可以验证通过');
  Assert.AreEqual(Ord(ltStandard), Ord(Info.LicenseType), 'license type should be correct');
  Assert.AreEqual('Test User', Info.IssuedTo, 'IssuedTo 应该正确');
end;

procedure TTestDeepBaseLicense.Test_LicenseInfo_DefaultValues;
var
  Info: TLicenseInfo;
begin
  Info := Default(TLicenseInfo);
  
  Assert.AreEqual(Ord(ltNone), Ord(Info.LicenseType), '默认类型应该�?None');
  Assert.AreEqual(Ord(lsInvalid), Ord(Info.Status), '默认状态应该是 Invalid');
end;

procedure TTestDeepBaseLicense.Test_LicenseType_Trial;
var
  Key: string;
  Info: TLicenseInfo;
begin
  Key := TDeepBaseLicense.GenerateLicenseKey(
    ltTrial, 
    IncDay(Now, 30),
    'Trial User',
    FLicense.GetDeviceId,
    []
  );
  
  Info := FLicense.ValidateLicense(Key);
  
  Assert.AreEqual(Ord(ltTrial), Ord(Info.LicenseType), '应该是试用许可证');
end;

procedure TTestDeepBaseLicense.Test_LicenseType_Standard;
var
  Key: string;
  Info: TLicenseInfo;
begin
  Key := TDeepBaseLicense.GenerateLicenseKey(
    ltStandard, 
    IncYear(Now, 1),
    'Standard User',
    FLicense.GetDeviceId,
    []
  );
  
  Info := FLicense.ValidateLicense(Key);
  
  Assert.AreEqual(Ord(ltStandard), Ord(Info.LicenseType), '应该是标准许可证');
end;

procedure TTestDeepBaseLicense.Test_LicenseType_Pro;
var
  Key: string;
  Info: TLicenseInfo;
begin
  Key := TDeepBaseLicense.GenerateLicenseKey(
    ltPro, 
    IncYear(Now, 1),
    'Pro User',
    FLicense.GetDeviceId,
    ['feature1', 'feature2']
  );
  
  Info := FLicense.ValidateLicense(Key);
  
  Assert.AreEqual(Ord(ltPro), Ord(Info.LicenseType), '应该是专业许可证');
end;

procedure TTestDeepBaseLicense.Test_LicenseType_Enterprise;
var
  Key: string;
  Info: TLicenseInfo;
begin
  Key := TDeepBaseLicense.GenerateLicenseKey(
    ltEnterprise, 
    IncYear(Now, 1),
    'Enterprise Corp',
    '',  // 企业版不绑定设备
    ['all']
  );
  
  Info := FLicense.ValidateLicense(Key);
  
  Assert.AreEqual(Ord(ltEnterprise), Ord(Info.LicenseType), '应该是企业许可证');
end;

procedure TTestDeepBaseLicense.Test_ExpiredLicense_Detected;
var
  Key: string;
  Info: TLicenseInfo;
begin
  Key := TDeepBaseLicense.GenerateLicenseKey(
    ltStandard, 
    IncDay(Now, -1),  // 昨天过期
    'Expired User',
    FLicense.GetDeviceId,
    []
  );
  
  Info := FLicense.ValidateLicense(Key);
  
  Assert.AreEqual(Ord(lsExpired), Ord(Info.Status), 'expired license should be detected');
end;

procedure TTestDeepBaseLicense.Test_ActivateLicense_ValidKey;
var
  Key: string;
  Result: Boolean;
begin
  Key := TDeepBaseLicense.GenerateLicenseKey(
    ltStandard, 
    IncYear(Now, 1),
    'Activate Test',
    FLicense.GetDeviceId,
    []
  );
  
  Result := FLicense.ActivateLicense(Key);
  
  Assert.IsTrue(Result, 'valid key should activate successfully');
end;

procedure TTestDeepBaseLicense.Test_DeactivateLicense;
var
  Key: string;
begin
  Key := TDeepBaseLicense.GenerateLicenseKey(
    ltStandard, 
    IncYear(Now, 1),
    'Deactivate Test',
    FLicense.GetDeviceId,
    []
  );
  
  FLicense.ActivateLicense(Key);
  FLicense.DeactivateLicense;
  
  // 停用后应该没有有效许可证
  Assert.AreEqual(Ord(ltNone), Ord(FLicense.CurrentLicenseInfo.LicenseType), 
    '停用后许可证类型应该�?None');
end;

procedure TTestDeepBaseLicense.Test_CurrentLicenseInfo;
var
  Key: string;
  Info: TLicenseInfo;
begin
  Key := TDeepBaseLicense.GenerateLicenseKey(
    ltPro, 
    IncYear(Now, 1),
    'Current Test',
    FLicense.GetDeviceId,
    ['featureA']
  );
  
  FLicense.ActivateLicense(Key);
  
  Info := FLicense.CurrentLicenseInfo;
  
  Assert.AreEqual(Ord(ltPro), Ord(Info.LicenseType), 'current license type should be correct');
  Assert.AreEqual('Current Test', Info.IssuedTo, 'IssuedTo 应该正确');
end;

procedure TTestDeepBaseLicense.Test_StorageInjection_BasicFlow;
var
  Storage: ILicenseStorage;
  LicenseA: TDeepBaseLicense;
  LicenseB: TDeepBaseLicense;
  Key: string;
begin
  Storage := TInMemoryLicenseStorage.Create;

  LicenseA := TDeepBaseLicense.Create(Storage);
  try
    Key := TDeepBaseLicense.GenerateLicenseKey(
      ltStandard,
      IncYear(Now, 1),
      'Storage Test',
      LicenseA.GetDeviceId,
      []
    );

    Assert.IsTrue(LicenseA.ActivateLicense(Key), '注入存储模式下应可激活许可证');
    Assert.IsNotEmpty(Storage.ReadLicenseKey, 'license key should be persisted after activation');
  finally
    LicenseA.Free;
  end;

  LicenseB := TDeepBaseLicense.Create(Storage);
  try
    Assert.AreEqual(Ord(lsValid), Ord(LicenseB.CurrentLicenseInfo.Status),
      '新实例应从注入存储恢复许可证');
    LicenseB.DeactivateLicense;
    Assert.AreEqual('', Storage.ReadLicenseKey, '停用后应清除持久化许可证');
  finally
    LicenseB.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDeepBaseLicense);

end.
