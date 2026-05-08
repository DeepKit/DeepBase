unit Test.DeepBase.Services.Protection;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DeepBase.Services.Interfaces;

type
  TMockAntiTamperStorage = class(TInterfacedObject, IAntiTamperStorage)
  public
    SetupDatabasePath: string;
    LastSaveDatabasePath: string;
    LastSaveKey: string;
    LastSaveData: TBytes;
    LastSaveHash: string;
    LastSaveCreatedAt: string;
    LastLoadDatabasePath: string;
    LastLoadKey: string;
    NextLoadData: TBytes;
    NextLoadHash: string;
    NextLoadFound: Boolean;

    procedure SetupDatabase(const DatabasePath: string);
    procedure SaveSecureImage(const DatabasePath, KeyName: string;
      const EncryptedImageData: TBytes; const Hash, CreatedAt: string);
    function TryLoadSecureImage(const DatabasePath, KeyName: string;
      out EncryptedImageData: TBytes; out Hash: string): Boolean;
  end;

  [TestFixture]
  TTestServicesProtection = class
  private
    FMockStorageObj: TMockAntiTamperStorage;
    FMockStorage: IAntiTamperStorage;
    function CreateConfiguredService: IAntiTamperService;
    function BytesEqual(const Left, Right: TBytes): Boolean;
  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure SetupDatabase_DelegatesToStorage;

    [Test]
    procedure SaveSecureImage_DelegatesEncryptedPayloadAndHash;

    [Test]
    procedure LoadSecureImage_DecryptsAndVerifiesIntegrity;

    [Test]
    procedure SetupDatabase_WithoutStorageFactory_RaisesHelpfulError;
  end;

implementation

uses
  DeepBase.Services.Protection;

{ TMockAntiTamperStorage }

procedure TMockAntiTamperStorage.SetupDatabase(const DatabasePath: string);
begin
  SetupDatabasePath := DatabasePath;
end;

procedure TMockAntiTamperStorage.SaveSecureImage(const DatabasePath,
  KeyName: string; const EncryptedImageData: TBytes; const Hash,
  CreatedAt: string);
begin
  LastSaveDatabasePath := DatabasePath;
  LastSaveKey := KeyName;
  LastSaveData := Copy(EncryptedImageData);
  LastSaveHash := Hash;
  LastSaveCreatedAt := CreatedAt;
end;

function TMockAntiTamperStorage.TryLoadSecureImage(const DatabasePath,
  KeyName: string; out EncryptedImageData: TBytes; out Hash: string): Boolean;
begin
  LastLoadDatabasePath := DatabasePath;
  LastLoadKey := KeyName;
  EncryptedImageData := Copy(NextLoadData);
  Hash := NextLoadHash;
  Result := NextLoadFound;
end;

{ TTestServicesProtection }

function TTestServicesProtection.BytesEqual(const Left, Right: TBytes): Boolean;
var
  I: Integer;
begin
  if Length(Left) <> Length(Right) then
    Exit(False);

  for I := 0 to High(Left) do
    if Left[I] <> Right[I] then
      Exit(False);

  Result := True;
end;

function TTestServicesProtection.CreateConfiguredService: IAntiTamperService;
var
  Service: TAntiTamperServiceImpl;
  Config: TAntiTamperConfig;
begin
  Service := TAntiTamperServiceImpl.Create;
  Config := Service.GetDefaultConfig;
  Config.KeyString := 'ServicesProtectionTest-Key';
  Config.DatabasePath := 'anti_tamper_services_test.db';
  Service.Initialize(Config);
  Result := Service;
end;

procedure TTestServicesProtection.Setup;
begin
  FMockStorageObj := TMockAntiTamperStorage.Create;
  FMockStorage := FMockStorageObj;
  TAntiTamperServiceImpl.SetStorageFactory(
    function: IAntiTamperStorage
    begin
      Result := FMockStorage;
    end);
end;

procedure TTestServicesProtection.TearDown;
begin
  TAntiTamperServiceImpl.SetStorageFactory(nil);
  FMockStorage := nil;
  FMockStorageObj := nil;
end;

procedure TTestServicesProtection.SetupDatabase_DelegatesToStorage;
var
  Service: IAntiTamperService;
begin
  Service := CreateConfiguredService;
  Service.SetupDatabase;
  Assert.AreEqual('anti_tamper_services_test.db',
    FMockStorageObj.SetupDatabasePath);
end;

procedure TTestServicesProtection.SaveSecureImage_DelegatesEncryptedPayloadAndHash;
var
  Service: IAntiTamperService;
  ImageData: TBytes;
begin
  Service := CreateConfiguredService;
  ImageData := TEncoding.UTF8.GetBytes('secure-image-bytes');
  Service.SaveSecureImage('aboutme', ImageData);

  Assert.AreEqual('anti_tamper_services_test.db',
    FMockStorageObj.LastSaveDatabasePath);
  Assert.AreEqual('aboutme', FMockStorageObj.LastSaveKey);
  Assert.IsTrue(Length(FMockStorageObj.LastSaveData) > 0);
  Assert.AreEqual(64, Integer(Length(FMockStorageObj.LastSaveHash)));
  Assert.IsFalse(FMockStorageObj.LastSaveCreatedAt.Trim.IsEmpty);
end;

procedure TTestServicesProtection.LoadSecureImage_DecryptsAndVerifiesIntegrity;
var
  Service: IAntiTamperService;
  ExpectedData: TBytes;
  ActualData: TBytes;
begin
  Service := CreateConfiguredService;
  ExpectedData := TEncoding.UTF8.GetBytes('image-payload-42');
  FMockStorageObj.NextLoadData := Service.EncryptImageData(ExpectedData);
  FMockStorageObj.NextLoadHash := Service.CalculateSHA256(ExpectedData);
  FMockStorageObj.NextLoadFound := True;

  ActualData := Service.LoadSecureImage('aboutme');
  Assert.IsTrue(BytesEqual(ExpectedData, ActualData));
  Assert.AreEqual('anti_tamper_services_test.db',
    FMockStorageObj.LastLoadDatabasePath);
  Assert.AreEqual('aboutme', FMockStorageObj.LastLoadKey);
end;

procedure TTestServicesProtection.SetupDatabase_WithoutStorageFactory_RaisesHelpfulError;
var
  Service: IAntiTamperService;
  Raised: Boolean;
begin
  TAntiTamperServiceImpl.SetStorageFactory(nil);
  Service := CreateConfiguredService;
  Raised := False;
  try
    Service.SetupDatabase;
  except
    on E: Exception do
    begin
      Raised := True;
      Assert.IsTrue(
        E.Message.Contains('Anti-tamper storage factory is not registered'),
        'Unexpected exception message: ' + E.Message);
    end;
  end;
  Assert.IsTrue(Raised, 'Expected storage factory exception was not raised');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestServicesProtection);

end.
