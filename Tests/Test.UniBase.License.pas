unit Test.UniBase.License;

{*******************************************************************************
  UniBase License 模块单元测试
  
  测试内容:
  - License Key 验证
  - 设备指纹
  - 许可证类型
  - 激活/停用
*******************************************************************************}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils, System.Classes, System.DateUtils,
  UniBase.Types, UniBase.Manager, UniBase.License, UniBase.Storage.Interfaces;

type
  [TestFixture]
  TTestUniBaseLicense = class
  private
    FLicense: TUniBaseLicense;
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

{ TTestUniBaseLicense }

procedure TTestUniBaseLicense.Setup;
var
  Manager: TUniBaseManager;
begin
  Manager := UniBase.Manager.UniBase;
  if not Manager.IsInitialized then
    Manager.InitializeWithDB(':memory:');
  FLicense := TUniBaseLicense.Create(Manager.ConfigDB);
end;

procedure TTestUniBaseLicense.TearDown;
begin
  FreeAndNil(FLicense);
end;

procedure TTestUniBaseLicense.Test_GetDeviceId_NotEmpty;
var
  DeviceId: string;
begin
  DeviceId := FLicense.GetDeviceId;
  
  Assert.IsNotEmpty(DeviceId, '设备 ID 不应该为空');
end;

procedure TTestUniBaseLicense.Test_GetDeviceId_Consistent;
var
  Id1, Id2: string;
begin
  Id1 := FLicense.GetDeviceId;
  Id2 := FLicense.GetDeviceId;
  
  Assert.AreEqual(Id1, Id2, '多次调用应该返回相同的设备 ID');
end;

procedure TTestUniBaseLicense.Test_ValidateLicense_EmptyKey_Invalid;
var
  Info: TLicenseInfo;
begin
  Info := FLicense.ValidateLicense('');
  
  Assert.AreEqual(Ord(lsInvalid), Ord(Info.Status), '空 Key 应该无效');
end;

procedure TTestUniBaseLicense.Test_ValidateLicense_InvalidFormat;
var
  Info: TLicenseInfo;
begin
  Info := FLicense.ValidateLicense('invalid-license-key-format');
  
  Assert.AreEqual(Ord(lsInvalid), Ord(Info.Status), '无效格式应该被检测');
end;

procedure TTestUniBaseLicense.Test_GenerateLicenseKey_ValidFormat;
var
  Key: string;
begin
  Key := TUniBaseLicense.GenerateLicenseKey(
    ltStandard, 
    IncYear(Now, 1),
    'Test User',
    FLicense.GetDeviceId,
    []
  );
  
  Assert.IsNotEmpty(Key, '生成的 Key 不应该为空');
  Assert.Contains(Key, '.', 'Key 应该包含分隔符');
end;

procedure TTestUniBaseLicense.Test_GenerateLicenseKey_CanBeValidated;
var
  Key: string;
  Info: TLicenseInfo;
begin
  Key := TUniBaseLicense.GenerateLicenseKey(
    ltStandard, 
    IncYear(Now, 1),
    'Test User',
    FLicense.GetDeviceId,
    []
  );
  
  Info := FLicense.ValidateLicense(Key);
  
  Assert.AreEqual(Ord(lsValid), Ord(Info.Status), '生成的 Key 应该可以验证通过');
  Assert.AreEqual(Ord(ltStandard), Ord(Info.LicenseType), '许可证类型应该正确');
  Assert.AreEqual('Test User', Info.IssuedTo, 'IssuedTo 应该正确');
end;

procedure TTestUniBaseLicense.Test_LicenseInfo_DefaultValues;
var
  Info: TLicenseInfo;
begin
  Info := Default(TLicenseInfo);
  
  Assert.AreEqual(Ord(ltNone), Ord(Info.LicenseType), '默认类型应该是 None');
  Assert.AreEqual(Ord(lsInvalid), Ord(Info.Status), '默认状态应该是 Invalid');
end;

procedure TTestUniBaseLicense.Test_LicenseType_Trial;
var
  Key: string;
  Info: TLicenseInfo;
begin
  Key := TUniBaseLicense.GenerateLicenseKey(
    ltTrial, 
    IncDay(Now, 30),
    'Trial User',
    FLicense.GetDeviceId,
    []
  );
  
  Info := FLicense.ValidateLicense(Key);
  
  Assert.AreEqual(Ord(ltTrial), Ord(Info.LicenseType), '应该是试用许可证');
end;

procedure TTestUniBaseLicense.Test_LicenseType_Standard;
var
  Key: string;
  Info: TLicenseInfo;
begin
  Key := TUniBaseLicense.GenerateLicenseKey(
    ltStandard, 
    IncYear(Now, 1),
    'Standard User',
    FLicense.GetDeviceId,
    []
  );
  
  Info := FLicense.ValidateLicense(Key);
  
  Assert.AreEqual(Ord(ltStandard), Ord(Info.LicenseType), '应该是标准许可证');
end;

procedure TTestUniBaseLicense.Test_LicenseType_Pro;
var
  Key: string;
  Info: TLicenseInfo;
begin
  Key := TUniBaseLicense.GenerateLicenseKey(
    ltPro, 
    IncYear(Now, 1),
    'Pro User',
    FLicense.GetDeviceId,
    ['feature1', 'feature2']
  );
  
  Info := FLicense.ValidateLicense(Key);
  
  Assert.AreEqual(Ord(ltPro), Ord(Info.LicenseType), '应该是专业许可证');
end;

procedure TTestUniBaseLicense.Test_LicenseType_Enterprise;
var
  Key: string;
  Info: TLicenseInfo;
begin
  Key := TUniBaseLicense.GenerateLicenseKey(
    ltEnterprise, 
    IncYear(Now, 1),
    'Enterprise Corp',
    '',  // 企业版不绑定设备
    ['all']
  );
  
  Info := FLicense.ValidateLicense(Key);
  
  Assert.AreEqual(Ord(ltEnterprise), Ord(Info.LicenseType), '应该是企业许可证');
end;

procedure TTestUniBaseLicense.Test_ExpiredLicense_Detected;
var
  Key: string;
  Info: TLicenseInfo;
begin
  Key := TUniBaseLicense.GenerateLicenseKey(
    ltStandard, 
    IncDay(Now, -1),  // 昨天过期
    'Expired User',
    FLicense.GetDeviceId,
    []
  );
  
  Info := FLicense.ValidateLicense(Key);
  
  Assert.AreEqual(Ord(lsExpired), Ord(Info.Status), '过期许可证应该被检测');
end;

procedure TTestUniBaseLicense.Test_ActivateLicense_ValidKey;
var
  Key: string;
  Result: Boolean;
begin
  Key := TUniBaseLicense.GenerateLicenseKey(
    ltStandard, 
    IncYear(Now, 1),
    'Activate Test',
    FLicense.GetDeviceId,
    []
  );
  
  Result := FLicense.ActivateLicense(Key);
  
  Assert.IsTrue(Result, '有效 Key 应该激活成功');
end;

procedure TTestUniBaseLicense.Test_DeactivateLicense;
var
  Key: string;
begin
  Key := TUniBaseLicense.GenerateLicenseKey(
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
    '停用后许可证类型应该是 None');
end;

procedure TTestUniBaseLicense.Test_CurrentLicenseInfo;
var
  Key: string;
  Info: TLicenseInfo;
begin
  Key := TUniBaseLicense.GenerateLicenseKey(
    ltPro, 
    IncYear(Now, 1),
    'Current Test',
    FLicense.GetDeviceId,
    ['featureA']
  );
  
  FLicense.ActivateLicense(Key);
  
  Info := FLicense.CurrentLicenseInfo;
  
  Assert.AreEqual(Ord(ltPro), Ord(Info.LicenseType), '当前许可证类型应该正确');
  Assert.AreEqual('Current Test', Info.IssuedTo, 'IssuedTo 应该正确');
end;

procedure TTestUniBaseLicense.Test_StorageInjection_BasicFlow;
var
  Storage: ILicenseStorage;
  LicenseA: TUniBaseLicense;
  LicenseB: TUniBaseLicense;
  Key: string;
begin
  Storage := TInMemoryLicenseStorage.Create;

  LicenseA := TUniBaseLicense.Create(Storage);
  try
    Key := TUniBaseLicense.GenerateLicenseKey(
      ltStandard,
      IncYear(Now, 1),
      'Storage Test',
      LicenseA.GetDeviceId,
      []
    );

    Assert.IsTrue(LicenseA.ActivateLicense(Key), '注入存储模式下应可激活许可证');
    Assert.IsNotEmpty(Storage.ReadLicenseKey, '激活后应持久化许可证');
  finally
    LicenseA.Free;
  end;

  LicenseB := TUniBaseLicense.Create(Storage);
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
  TDUnitX.RegisterTestFixture(TTestUniBaseLicense);

end.
