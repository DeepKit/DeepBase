{ ============================================================================
  DeepBase.Services.Protection - Protection Service Implementations

  Version: 1.0
  Description: Implements IAntiTamperService and IBasicProtectionService
               interfaces. These wrap the existing SeedTool protection
               functionality for dependency injection.
  ============================================================================ }

unit DeepBase.Services.Protection;

interface

uses
  System.SysUtils,
  System.Classes,
  DeepBase.Services.Interfaces;

type
  // ============================================================================
  // Basic Protection Service Implementation
  // ============================================================================

  /// <summary>
  /// Implementation of IBasicProtectionService
  /// Provides AES-256-CBC encryption using Windows CryptoAPI
  /// </summary>
  TBasicProtectionServiceImpl = class(TInterfacedObject, IBasicProtectionService)
  private
    FDefaultPassword: string;
    procedure EnsurePasswordConfigured;
  public
    constructor Create(const ADefaultPassword: string = '');

    function GetDynamicKey: string;
    function EncryptSensitiveData(const Data: string): string;
    function DecryptSensitiveData(const EncryptedData: string): string;
    function EncryptBinaryData(const Data: TBytes): TBytes;
    function DecryptBinaryData(const EncryptedData: TBytes): TBytes;
    function CalculateHMAC(const Data: string): string;
    function VerifyDataIntegrity(const Data, ExpectedHMAC: string): Boolean;
    function CalculateFileHash(const FileName: string): string;
    function CalculateDataHash(const Data: TBytes): string;
  end;

  // ============================================================================
  // Anti-Tamper Service Implementation
  // ============================================================================

  /// <summary>
  /// Implementation of IAntiTamperService
  /// Provides secure image storage and integrity verification
  /// </summary>
  TAntiTamperServiceImpl = class(TInterfacedObject, IAntiTamperService)
  private
    FConfig: TAntiTamperConfig;
    FInitialized: Boolean;
    FStorage: IAntiTamperStorage;
    class var FStorageFactory: TFunc<IAntiTamperStorage>;
    class function CreateStorage: IAntiTamperStorage; static;
    function GetStorage: IAntiTamperStorage;
  public
    constructor Create(const AStorage: IAntiTamperStorage = nil);
    destructor Destroy; override;
    class procedure SetStorageFactory(
      const AFactory: TFunc<IAntiTamperStorage>); static;

    procedure Initialize(const Config: TAntiTamperConfig);
    procedure SetupDatabase;
    function CalculateSHA256(const Data: TBytes): string;
    function EncryptImageData(const ImageData: TBytes): TBytes;
    function DecryptImageData(const EncryptedData: TBytes): TBytes;
    function VerifyImageIntegrity(const Data: TBytes; const ExpectedHash: string): Boolean;
    procedure SaveSecureImage(const KeyName: string; const ImageData: TBytes);
    function LoadSecureImage(const KeyName: string): TBytes;
    procedure HandleSecurityViolation(const Reason: string);
    function GetDefaultConfig: TAntiTamperConfig;
  end;

implementation

uses
  Winapi.Windows,
  System.Hash,
  System.IOUtils,
  DeepBase.Exceptions;

const
  // Windows Crypto API ����
  PROV_RSA_AES = 24;
  CRYPT_VERIFYCONTEXT = $F0000000;
  CRYPT_EXPORTABLE = $00000001;
  CALG_SHA_256 = $0000800c;
  CALG_AES_256 = $00006610;
  KP_MODE = 4;
  KP_IV = 1;
  CRYPT_MODE_CBC = 1;
  HP_HASHVAL = 2;
  MS_ENH_RSA_AES_PROV = 'Microsoft Enhanced RSA and AES Cryptographic Provider';

type
  HCRYPTPROV = THandle;
  HCRYPTKEY = THandle;
  HCRYPTHASH = THandle;

// Windows Crypto API ��������
function CryptAcquireContextA(var phProv: HCRYPTPROV; pszContainer: PAnsiChar;
  pszProvider: PAnsiChar; dwProvType: DWORD; dwFlags: DWORD): BOOL; stdcall; external 'advapi32.dll';

function CryptReleaseContext(hProv: HCRYPTPROV; dwFlags: DWORD): BOOL; stdcall; external 'advapi32.dll';

function CryptGenRandom(hProv: HCRYPTPROV; dwLen: DWORD; pbBuffer: PByte): BOOL; stdcall; external 'advapi32.dll';

function CryptCreateHash(hProv: HCRYPTPROV; Algid: DWORD; hKey: HCRYPTKEY;
  dwFlags: DWORD; var phHash: HCRYPTHASH): BOOL; stdcall; external 'advapi32.dll';

function CryptHashData(hHash: HCRYPTHASH; pbData: PByte; dwDataLen: DWORD;
  dwFlags: DWORD): BOOL; stdcall; external 'advapi32.dll';

function CryptDeriveKey(hProv: HCRYPTPROV; Algid: DWORD; hBaseData: HCRYPTHASH;
  dwFlags: DWORD; var phKey: HCRYPTKEY): BOOL; stdcall; external 'advapi32.dll';

function CryptSetKeyParam(hKey: HCRYPTKEY; dwParam: DWORD; pbData: PByte;
  dwFlags: DWORD): BOOL; stdcall; external 'advapi32.dll';

function CryptEncrypt(hKey: HCRYPTKEY; hHash: HCRYPTHASH; Final: BOOL;
  dwFlags: DWORD; pbData: PByte; var pdwDataLen: DWORD; dwBufLen: DWORD): BOOL; stdcall; external 'advapi32.dll';

function CryptDecrypt(hKey: HCRYPTKEY; hHash: HCRYPTHASH; Final: BOOL;
  dwFlags: DWORD; pbData: PByte; var pdwDataLen: DWORD): BOOL; stdcall; external 'advapi32.dll';

function CryptDestroyKey(hKey: HCRYPTKEY): BOOL; stdcall; external 'advapi32.dll';

function CryptDestroyHash(hHash: HCRYPTHASH): BOOL; stdcall; external 'advapi32.dll';

function CryptGetHashParam(hHash: HCRYPTHASH; dwParam: DWORD; pbData: PByte;
  var pdwDataLen: DWORD; dwFlags: DWORD): BOOL; stdcall; external 'advapi32.dll';

// Helper functions
function GenerateRandomIV: TBytes;
var
  hProv: HCRYPTPROV;
begin
  SetLength(Result, 16);
  if CryptAcquireContextA(hProv, nil, nil, 1, CRYPT_VERIFYCONTEXT) then
  try
    if not CryptGenRandom(hProv, 16, @Result[0]) then
      raise ERandomException.Create('Failed to generate random IV');
  finally
    CryptReleaseContext(hProv, 0);
  end
  else
    raise EEncryptionException.Create('Failed to acquire crypto context');
end;

function BytesToHex(const ABytes: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to Length(ABytes) - 1 do
    Result := Result + IntToHex(ABytes[I], 2);
end;

function HexToBytes(const AHex: string): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to Length(Result) - 1 do
    Result[I] := StrToInt('$' + Copy(AHex, I * 2 + 1, 2));
end;

function PadData(const AData: TBytes; ABlockSize: Integer): TBytes;
var
  PadLength: Integer;
  I: Integer;
begin
  PadLength := ABlockSize - (Length(AData) mod ABlockSize);
  if PadLength = 0 then
    PadLength := ABlockSize;

  SetLength(Result, Length(AData) + PadLength);
  if Length(AData) > 0 then
    Move(AData[0], Result[0], Length(AData));

  for I := Length(AData) to High(Result) do
    Result[I] := PadLength;
end;

function UnpadData(const AData: TBytes): TBytes;
var
  PadLength: Integer;
  I: Integer;
begin
  if Length(AData) = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  PadLength := AData[High(AData)];

  if (PadLength <= 0) or (PadLength > Length(AData)) then
    raise EDecryptionException.Create('Invalid padding');

  for I := Length(AData) - PadLength to High(AData) do
  begin
    if AData[I] <> PadLength then
      raise EDecryptionException.Create('Invalid padding');
  end;

  SetLength(Result, Length(AData) - PadLength);
  if Length(Result) > 0 then
    Move(AData[0], Result[0], Length(Result));
end;

// ============================================================================
// TBasicProtectionServiceImpl
// ============================================================================

constructor TBasicProtectionServiceImpl.Create(const ADefaultPassword: string);
begin
  inherited Create;
  FDefaultPassword := ADefaultPassword;
end;

procedure TBasicProtectionServiceImpl.EnsurePasswordConfigured;
begin
  if Trim(FDefaultPassword) = '' then
    raise EMissingConfigurationException.Create(
      'Protection password is required. Configure a non-empty password before using protection services.');
end;

function TBasicProtectionServiceImpl.GetDynamicKey: string;
begin
  Result := '';
end;

function TBasicProtectionServiceImpl.EncryptSensitiveData(const Data: string): string;
var
  hProv: HCRYPTPROV;
  hKey: HCRYPTKEY;
  hHash: HCRYPTHASH;
  DataBytes, EncryptedData, IV, PaddedData, KeyBytes: TBytes;
  DataLen: DWORD;
  Mode: DWORD;
begin
  if Data = '' then
    Exit('');

  EnsurePasswordConfigured;
  KeyBytes := TEncoding.UTF8.GetBytes(FDefaultPassword);
  if Length(KeyBytes) = 0 then
    raise EEncryptionException.Create('Password derived key is empty');
  DataBytes := TEncoding.UTF8.GetBytes(Data);
  IV := GenerateRandomIV;

  if not CryptAcquireContextA(hProv, nil, PAnsiChar(AnsiString(MS_ENH_RSA_AES_PROV)),
       PROV_RSA_AES, CRYPT_VERIFYCONTEXT) then
    raise EEncryptionException.Create('Failed to acquire AES context');

  try
    if not CryptCreateHash(hProv, CALG_SHA_256, 0, 0, hHash) then
      raise EEncryptionException.Create('Failed to create hash');

    try
      if not CryptHashData(hHash, @KeyBytes[0], Length(KeyBytes), 0) then
        raise EEncryptionException.Create('Failed to hash key');

      if not CryptDeriveKey(hProv, CALG_AES_256, hHash, CRYPT_EXPORTABLE, hKey) then
        raise EEncryptionException.Create('Failed to derive key');

      try
        Mode := CRYPT_MODE_CBC;
        if not CryptSetKeyParam(hKey, KP_MODE, @Mode, 0) then
          raise EEncryptionException.Create('Failed to set mode');

        if not CryptSetKeyParam(hKey, KP_IV, @IV[0], 0) then
          raise EEncryptionException.Create('Failed to set IV');

        PaddedData := PadData(DataBytes, 16);
        DataLen := Length(PaddedData);

        SetLength(EncryptedData, DataLen + 16);
        Move(PaddedData[0], EncryptedData[0], DataLen);

        if not CryptEncrypt(hKey, 0, True, 0, @EncryptedData[0], DataLen, Length(EncryptedData)) then
          raise EEncryptionException.Create('Encryption failed');

        SetLength(EncryptedData, DataLen);
        Result := BytesToHex(IV) + '|' + BytesToHex(EncryptedData);

      finally
        CryptDestroyKey(hKey);
      end;
    finally
      CryptDestroyHash(hHash);
    end;
  finally
    CryptReleaseContext(hProv, 0);
  end;
end;

function TBasicProtectionServiceImpl.DecryptSensitiveData(const EncryptedData: string): string;
var
  hProv: HCRYPTPROV;
  hKey: HCRYPTKEY;
  hHash: HCRYPTHASH;
  Parts: TArray<string>;
  IV, EncryptedBytes, DecryptedData, KeyBytes: TBytes;
  DataLen: DWORD;
  Mode: DWORD;
begin
  Result := '';
  if EncryptedData = '' then
    Exit;

  EnsurePasswordConfigured;
  Parts := EncryptedData.Split(['|']);
  if Length(Parts) <> 2 then
    raise EDecryptionException.Create('Invalid format');

  IV := HexToBytes(Parts[0]);
  EncryptedBytes := HexToBytes(Parts[1]);
  KeyBytes := TEncoding.UTF8.GetBytes(FDefaultPassword);
  if Length(KeyBytes) = 0 then
    raise EDecryptionException.Create('Password derived key is empty');

  if not CryptAcquireContextA(hProv, nil, PAnsiChar(AnsiString(MS_ENH_RSA_AES_PROV)),
       PROV_RSA_AES, CRYPT_VERIFYCONTEXT) then
    raise EDecryptionException.Create('Failed to acquire context');

  try
    if not CryptCreateHash(hProv, CALG_SHA_256, 0, 0, hHash) then
      raise EDecryptionException.Create('Failed to create hash');

    try
      if not CryptHashData(hHash, @KeyBytes[0], Length(KeyBytes), 0) then
        raise EDecryptionException.Create('Failed to hash key');

      if not CryptDeriveKey(hProv, CALG_AES_256, hHash, CRYPT_EXPORTABLE, hKey) then
        raise EDecryptionException.Create('Failed to derive key');

      try
        Mode := CRYPT_MODE_CBC;
        if not CryptSetKeyParam(hKey, KP_MODE, @Mode, 0) then
          raise EDecryptionException.Create('Failed to set mode');

        if not CryptSetKeyParam(hKey, KP_IV, @IV[0], 0) then
          raise EDecryptionException.Create('Failed to set IV');

        DecryptedData := Copy(EncryptedBytes);
        DataLen := Length(DecryptedData);

        if not CryptDecrypt(hKey, 0, True, 0, @DecryptedData[0], DataLen) then
          raise EDecryptionException.Create('Decryption failed');

        SetLength(DecryptedData, DataLen);
        DecryptedData := UnpadData(DecryptedData);
        Result := TEncoding.UTF8.GetString(DecryptedData);

      finally
        CryptDestroyKey(hKey);
      end;
    finally
      CryptDestroyHash(hHash);
    end;
  finally
    CryptReleaseContext(hProv, 0);
  end;
end;

function TBasicProtectionServiceImpl.EncryptBinaryData(const Data: TBytes): TBytes;
var
  hProv: HCRYPTPROV;
  hKey: HCRYPTKEY;
  hHash: HCRYPTHASH;
  EncryptedData, IV, PaddedData, KeyBytes: TBytes;
  DataLen: DWORD;
  Mode: DWORD;
begin
  if Length(Data) = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  EnsurePasswordConfigured;
  KeyBytes := TEncoding.UTF8.GetBytes(FDefaultPassword);
  if Length(KeyBytes) = 0 then
    raise EEncryptionException.Create('Password derived key is empty');
  IV := GenerateRandomIV;

  if not CryptAcquireContextA(hProv, nil, PAnsiChar(AnsiString(MS_ENH_RSA_AES_PROV)),
       PROV_RSA_AES, CRYPT_VERIFYCONTEXT) then
    raise EEncryptionException.Create('Failed to acquire context');

  try
    if not CryptCreateHash(hProv, CALG_SHA_256, 0, 0, hHash) then
      raise EEncryptionException.Create('Failed to create hash');

    try
      if not CryptHashData(hHash, @KeyBytes[0], Length(KeyBytes), 0) then
        raise EEncryptionException.Create('Failed to hash key');

      if not CryptDeriveKey(hProv, CALG_AES_256, hHash, CRYPT_EXPORTABLE, hKey) then
        raise EEncryptionException.Create('Failed to derive key');

      try
        Mode := CRYPT_MODE_CBC;
        if not CryptSetKeyParam(hKey, KP_MODE, @Mode, 0) then
          raise EEncryptionException.Create('Failed to set mode');
        if not CryptSetKeyParam(hKey, KP_IV, @IV[0], 0) then
          raise EEncryptionException.Create('Failed to set IV');

        PaddedData := PadData(Data, 16);
        DataLen := Length(PaddedData);

        SetLength(EncryptedData, DataLen + 16);
        Move(PaddedData[0], EncryptedData[0], DataLen);

        if not CryptEncrypt(hKey, 0, True, 0, @EncryptedData[0], DataLen, Length(EncryptedData)) then
          raise EEncryptionException.Create('Encryption failed');

        SetLength(EncryptedData, DataLen);

        SetLength(Result, Length(IV) + Length(EncryptedData));
        Move(IV[0], Result[0], Length(IV));
        Move(EncryptedData[0], Result[Length(IV)], Length(EncryptedData));

      finally
        CryptDestroyKey(hKey);
      end;
    finally
      CryptDestroyHash(hHash);
    end;
  finally
    CryptReleaseContext(hProv, 0);
  end;
end;

function TBasicProtectionServiceImpl.DecryptBinaryData(const EncryptedData: TBytes): TBytes;
var
  hProv: HCRYPTPROV;
  hKey: HCRYPTKEY;
  hHash: HCRYPTHASH;
  IV, EncryptedBytes, DecryptedData, KeyBytes: TBytes;
  DataLen: DWORD;
  Mode: DWORD;
begin
  SetLength(Result, 0);
  if Length(EncryptedData) < 16 then Exit;

  EnsurePasswordConfigured;
  SetLength(IV, 16);
  Move(EncryptedData[0], IV[0], 16);
  SetLength(EncryptedBytes, Length(EncryptedData) - 16);
  Move(EncryptedData[16], EncryptedBytes[0], Length(EncryptedBytes));

  KeyBytes := TEncoding.UTF8.GetBytes(FDefaultPassword);
  if Length(KeyBytes) = 0 then
    raise EDecryptionException.Create('Password derived key is empty');

  if not CryptAcquireContextA(hProv, nil, PAnsiChar(AnsiString(MS_ENH_RSA_AES_PROV)),
       PROV_RSA_AES, CRYPT_VERIFYCONTEXT) then
    raise EDecryptionException.Create('Failed to acquire context');

  try
    if not CryptCreateHash(hProv, CALG_SHA_256, 0, 0, hHash) then
      raise EDecryptionException.Create('Failed to create hash');

    try
      if not CryptHashData(hHash, @KeyBytes[0], Length(KeyBytes), 0) then
        raise EDecryptionException.Create('Failed to hash key');

      if not CryptDeriveKey(hProv, CALG_AES_256, hHash, CRYPT_EXPORTABLE, hKey) then
        raise EDecryptionException.Create('Failed to derive key');

      try
        Mode := CRYPT_MODE_CBC;
        if not CryptSetKeyParam(hKey, KP_MODE, @Mode, 0) then
          raise EDecryptionException.Create('Failed to set mode');
        if not CryptSetKeyParam(hKey, KP_IV, @IV[0], 0) then
          raise EDecryptionException.Create('Failed to set IV');

        DecryptedData := Copy(EncryptedBytes);
        DataLen := Length(DecryptedData);

        if not CryptDecrypt(hKey, 0, True, 0, @DecryptedData[0], DataLen) then
          raise EDecryptionException.Create('Decryption failed');

        SetLength(DecryptedData, DataLen);
        Result := UnpadData(DecryptedData);

      finally
        CryptDestroyKey(hKey);
      end;
    finally
      CryptDestroyHash(hHash);
    end;
  finally
    CryptReleaseContext(hProv, 0);
  end;
end;

function TBasicProtectionServiceImpl.CalculateHMAC(const Data: string): string;
begin
  EnsurePasswordConfigured;
  Result := THashSHA2.GetHMAC(Data, FDefaultPassword, THashSHA2.TSHA2Version.SHA256);
end;

function TBasicProtectionServiceImpl.VerifyDataIntegrity(const Data, ExpectedHMAC: string): Boolean;
var
  Actual: string;
  I, Diff: Integer;
begin
  Actual := CalculateHMAC(Data);
  if Length(Actual) <> Length(ExpectedHMAC) then
    Exit(False);
  Diff := 0;
  for I := 1 to Length(Actual) do
    Diff := Diff or (Ord(Actual[I]) xor Ord(ExpectedHMAC[I]));
  Result := Diff = 0;
end;

function TBasicProtectionServiceImpl.CalculateFileHash(const FileName: string): string;
var
  FileStream: TFileStream;
begin
  if not TFile.Exists(FileName) then
    raise EFileNotFoundExceptionEx.Create('File not found: ' + FileName);

  FileStream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    Result := THashSHA2.GetHashString(FileStream);
  finally
    FreeAndNil(FileStream);
  end;
end;

function TBasicProtectionServiceImpl.CalculateDataHash(const Data: TBytes): string;
begin
  Result := THashSHA2.GetHashString(TEncoding.UTF8.GetString(Data));
end;

// ============================================================================
// TAntiTamperServiceImpl
// ============================================================================

class function TAntiTamperServiceImpl.CreateStorage: IAntiTamperStorage;
begin
  if Assigned(FStorageFactory) then
    Result := FStorageFactory()
  else
    Result := nil;
end;

function TAntiTamperServiceImpl.GetStorage: IAntiTamperStorage;
begin
  if FStorage = nil then
    FStorage := CreateStorage;

  if FStorage = nil then
    raise EInvalidOperation.Create(
      'Anti-tamper storage factory is not registered. ' +
      'Include a persistence registration unit (e.g. DeepBase.Persistence.RuntimeRegistration).');

  Result := FStorage;
end;

class procedure TAntiTamperServiceImpl.SetStorageFactory(
  const AFactory: TFunc<IAntiTamperStorage>);
begin
  FStorageFactory := AFactory;
end;

constructor TAntiTamperServiceImpl.Create(const AStorage: IAntiTamperStorage);
begin
  inherited Create;
  FInitialized := False;
  FConfig := GetDefaultConfig;
  FStorage := AStorage;
end;

destructor TAntiTamperServiceImpl.Destroy;
begin
  inherited;
end;

procedure TAntiTamperServiceImpl.Initialize(const Config: TAntiTamperConfig);
begin
  FConfig := Config;
  FInitialized := True;
end;

procedure TAntiTamperServiceImpl.SetupDatabase;
begin
  if not FInitialized then
    raise ENotInitializedException.Create('Service not initialized');

  GetStorage.SetupDatabase(FConfig.DatabasePath);
end;

function TAntiTamperServiceImpl.CalculateSHA256(const Data: TBytes): string;
begin
  Result := THashSHA2.Create.Update(Data).HashAsString;
end;

function TAntiTamperServiceImpl.EncryptImageData(const ImageData: TBytes): TBytes;
var
  ProtectionSvc: TBasicProtectionServiceImpl;
begin
  ProtectionSvc := TBasicProtectionServiceImpl.Create(FConfig.KeyString);
  try
    Result := ProtectionSvc.EncryptBinaryData(ImageData);
  finally
    ProtectionSvc.Free;
  end;
end;

function TAntiTamperServiceImpl.DecryptImageData(const EncryptedData: TBytes): TBytes;
var
  ProtectionSvc: TBasicProtectionServiceImpl;
begin
  ProtectionSvc := TBasicProtectionServiceImpl.Create(FConfig.KeyString);
  try
    Result := ProtectionSvc.DecryptBinaryData(EncryptedData);
  finally
    ProtectionSvc.Free;
  end;
end;

function TAntiTamperServiceImpl.VerifyImageIntegrity(const Data: TBytes;
  const ExpectedHash: string): Boolean;
begin
  Result := SameText(CalculateSHA256(Data), ExpectedHash);
end;

procedure TAntiTamperServiceImpl.SaveSecureImage(const KeyName: string;
  const ImageData: TBytes);
var
  EncryptedData: TBytes;
  Hash: string;
begin
  if not FInitialized then
    raise ENotInitializedException.Create('Service not initialized');

  EncryptedData := EncryptImageData(ImageData);
  Hash := CalculateSHA256(ImageData);
  GetStorage.SaveSecureImage(FConfig.DatabasePath, KeyName, EncryptedData,
    Hash, FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
end;

function TAntiTamperServiceImpl.LoadSecureImage(const KeyName: string): TBytes;
var
  EncryptedData: TBytes;
  StoredHash: string;
begin
  SetLength(Result, 0);

  if not FInitialized then
    raise ENotInitializedException.Create('Service not initialized');

  if GetStorage.TryLoadSecureImage(FConfig.DatabasePath, KeyName,
    EncryptedData, StoredHash) then
  begin
    Result := DecryptImageData(EncryptedData);

    if FConfig.EnableIntegrityCheck then
    begin
      if not VerifyImageIntegrity(Result, StoredHash) then
      begin
        HandleSecurityViolation('Image integrity check failed for: ' + KeyName);
        SetLength(Result, 0);
      end;
    end;
  end;
end;

procedure TAntiTamperServiceImpl.HandleSecurityViolation(const Reason: string);
begin
  raise EAntiTamperException.Create('Security violation: ' + Reason);
end;

function TAntiTamperServiceImpl.GetDefaultConfig: TAntiTamperConfig;
begin
  Result.KeyString := '';
  Result.IntegrityKey := 'DeepBase_Integrity_Key';
  Result.DatabasePath := '';
  Result.EnableCompression := False;
  Result.EnableIntegrityCheck := True;
end;

end.
