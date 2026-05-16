{ ============================================================================
  DeepBase.License - License Management Module
  
  Version: 1.0
  Description: Provides license validation, activation and device binding
  Features:
    - Device fingerprint generation
    - License key generation and validation
    - Multiple license types (Trial, Standard, Pro, Enterprise)
    - License activation/deactivation
    - Feature-based licensing
  ============================================================================ }

unit DeepBase.License;

interface

uses
  System.SysUtils,
  System.Classes,
  System.DateUtils,
  System.Hash,
  System.NetEncoding,
  System.JSON,
  System.Generics.Collections,
  DeepBase.Storage.Interfaces;

type
  /// <summary>
  /// License types
  /// </summary>
  TLicenseType = (
    ltNone,        // No license
    ltTrial,       // Trial version (limited time)
    ltStandard,    // Standard version
    ltPro,         // Professional version
    ltEnterprise   // Enterprise version
  );

  /// <summary>
  /// License status
  /// </summary>
  TLicenseStatus = (
    lsInvalid,     // Invalid license
    lsValid,       // Valid license
    lsExpired,     // Expired license
    lsDeviceMismatch, // Device mismatch
    lsTampered     // License tampered
  );

  /// <summary>
  /// License information record
  /// </summary>
  TLicenseInfo = record
    LicenseKey: string;
    LicenseType: TLicenseType;
    Status: TLicenseStatus;
    IssuedTo: string;
    IssuedAt: TDateTime;
    ExpiresAt: TDateTime;
    DeviceId: string;
    Features: TArray<string>;
    MaxUsers: Integer;
    
    function IsValid: Boolean;
    function IsExpired: Boolean;
    function DaysRemaining: Integer;
    function HasFeature(const FeatureName: string): Boolean;
    class function Empty: TLicenseInfo; static;
  end;

  /// <summary>
  /// DeepBase License Manager
  /// </summary>
  TDeepBaseLicense = class
  private
    FConnection: TObject;
    FStorage: ILicenseStorage;
    FCurrentLicense: TLicenseInfo;
    FCachedDeviceId: string;
    FSecretKey: string;
    FOnLicenseChanged: TNotifyEvent;
    class var FConnectionStorageFactory: TFunc<TObject, ILicenseStorage>;
    
    function GenerateDeviceFingerprint: string;
    function EncodePayload(const Payload: string): string;
    function DecodePayload(const Encoded: string): string;
    function SignData(const Data: string): string;
    function VerifySignature(const Data, Signature: string): Boolean;
    class function CreateStorageFromConnection(
      AConnection: TObject): ILicenseStorage; static;
    procedure LoadLicenseFromDB;
    procedure SaveLicenseToDB(const LicenseKey: string);
    procedure ClearLicenseFromDB;
    procedure SetConnection(const Value: TObject);
    
  public
    constructor Create(AConnection: TObject = nil); overload;
    constructor Create(const AStorage: ILicenseStorage); overload;
    destructor Destroy; override;

    class procedure SetStorageFactory(
      const AFactory: TFunc<TObject, ILicenseStorage>); static;
    
    /// <summary>Get unique device identifier</summary>
    function GetDeviceId: string;
    
    /// <summary>Validate a license key</summary>
    function ValidateLicense(const LicenseKey: string): TLicenseInfo;
    
    /// <summary>Activate license with key</summary>
    function ActivateLicense(const LicenseKey: string): Boolean;
    
    /// <summary>Deactivate current license</summary>
    procedure DeactivateLicense;
    
    /// <summary>Check if a feature is licensed</summary>
    function IsFeatureLicensed(const FeatureName: string): Boolean;
    
    /// <summary>Get current license info</summary>
    property CurrentLicenseInfo: TLicenseInfo read FCurrentLicense;
    
    /// <summary>Database connection</summary>
    property Connection: TObject read FConnection write SetConnection;
    
    /// <summary>License changed event</summary>
    property OnLicenseChanged: TNotifyEvent read FOnLicenseChanged write FOnLicenseChanged;
    
    /// <summary>Generate a license key (for license server/admin)</summary>
    class function GenerateLicenseKey(
      LicenseType: TLicenseType;
      ExpiresAt: TDateTime;
      const IssuedTo: string;
      const DeviceId: string;
      const Features: TArray<string>;
      MaxUsers: Integer = 1
    ): string;
    
    /// <summary>License type to string</summary>
    class function LicenseTypeToStr(LType: TLicenseType): string;
    
    /// <summary>String to license type</summary>
    class function StrToLicenseType(const S: string): TLicenseType;
    
    /// <summary>License status to string</summary>
    class function LicenseStatusToStr(Status: TLicenseStatus): string;
  end;

implementation

uses
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  System.Win.Registry,
  {$ENDIF}
  System.IOUtils;

const
  LICENSE_LEGACY_SECRET_ENV = 'DEEPBASE_LEGACY_LICENSE_SIGNING_KEY';
  LICENSE_CI_SECRET = 'DeepBase-License-CI-Only';
  LICENSE_TABLE = 'LicenseInfo';
  LICENSE_VERSION = '1.0';

function ResolveLegacyLicenseSecret: string;
begin
  Result := GetEnvironmentVariable(LICENSE_LEGACY_SECRET_ENV);
  {$IFDEF CI}
  if Result = '' then
    Result := LICENSE_CI_SECRET;
  {$ENDIF}
end;

{ TLicenseInfo }

class function TLicenseInfo.Empty: TLicenseInfo;
begin
  Result.LicenseKey := '';
  Result.LicenseType := ltNone;
  Result.Status := lsInvalid;
  Result.IssuedTo := '';
  Result.IssuedAt := 0;
  Result.ExpiresAt := 0;
  Result.DeviceId := '';
  SetLength(Result.Features, 0);
  Result.MaxUsers := 0;
end;

function TLicenseInfo.IsValid: Boolean;
begin
  Result := Status = lsValid;
end;

function TLicenseInfo.IsExpired: Boolean;
begin
  Result := (ExpiresAt > 0) and (Now > ExpiresAt);
end;

function TLicenseInfo.DaysRemaining: Integer;
begin
  if ExpiresAt <= 0 then
    Result := MaxInt  // Perpetual
  else if Now > ExpiresAt then
    Result := 0
  else
    Result := DaysBetween(Now, ExpiresAt);
end;

function TLicenseInfo.HasFeature(const FeatureName: string): Boolean;
var
  F: string;
begin
  Result := False;
  
  // Enterprise has all features
  if LicenseType = ltEnterprise then
    Exit(True);
  
  for F in Features do
  begin
    if SameText(F, FeatureName) or SameText(F, 'all') then
      Exit(True);
  end;
end;

{ TDeepBaseLicense }

constructor TDeepBaseLicense.Create(AConnection: TObject);
begin
  Create(CreateStorageFromConnection(AConnection));
  FConnection := AConnection;
end;

constructor TDeepBaseLicense.Create(const AStorage: ILicenseStorage);
begin
  inherited Create;
  FStorage := AStorage;
  FSecretKey := ResolveLegacyLicenseSecret;
  FCachedDeviceId := '';
  FCurrentLicense := TLicenseInfo.Empty;

  if Assigned(FStorage) then
    LoadLicenseFromDB;
end;

destructor TDeepBaseLicense.Destroy;
begin
  inherited;
end;

class procedure TDeepBaseLicense.SetStorageFactory(
  const AFactory: TFunc<TObject, ILicenseStorage>);
begin
  FConnectionStorageFactory := AFactory;
end;

class function TDeepBaseLicense.CreateStorageFromConnection(
  AConnection: TObject): ILicenseStorage;
begin
  Result := nil;
  if Assigned(AConnection) and Assigned(FConnectionStorageFactory) then
    Result := FConnectionStorageFactory(AConnection);
  if (Result = nil) and Assigned(AConnection) then
    raise EInvalidOp.Create(
      'No license storage factory registered for connection-backed constructor. ' +
      'Include a persistence registration unit (e.g. DeepBase.Persistence.RuntimeRegistration).');
end;

procedure TDeepBaseLicense.SetConnection(const Value: TObject);
begin
  FConnection := Value;
  FStorage := CreateStorageFromConnection(Value);
  if Assigned(FStorage) then
    LoadLicenseFromDB;
end;

function TDeepBaseLicense.GenerateDeviceFingerprint: string;
var
  Parts: TStringList;
  {$IFDEF MSWINDOWS}
  Reg: TRegistry;
  {$ENDIF}
  ComputerName, UserName: string;
  RawFingerprint: string;
begin
  Parts := TStringList.Create;
  try
    // Get computer name
    {$IFDEF MSWINDOWS}
    SetLength(ComputerName, MAX_COMPUTERNAME_LENGTH + 1);
    var Size: DWORD := MAX_COMPUTERNAME_LENGTH + 1;
    if GetComputerName(PChar(ComputerName), Size) then
      SetLength(ComputerName, Size)
    else
      ComputerName := 'Unknown';
    
    // Get Windows Product ID
    Reg := TRegistry.Create(KEY_READ);
    try
      Reg.RootKey := HKEY_LOCAL_MACHINE;
      if Reg.OpenKeyReadOnly('\SOFTWARE\Microsoft\Windows NT\CurrentVersion') then
      begin
        Parts.Add(Reg.ReadString('ProductId'));
        Reg.CloseKey;
      end;
    finally
      Reg.Free;
    end;
    
    // Get processor info
    Reg := TRegistry.Create(KEY_READ);
    try
      Reg.RootKey := HKEY_LOCAL_MACHINE;
      if Reg.OpenKeyReadOnly('\HARDWARE\DESCRIPTION\System\CentralProcessor\0') then
      begin
        Parts.Add(Reg.ReadString('ProcessorNameString'));
        Reg.CloseKey;
      end;
    finally
      Reg.Free;
    end;
    {$ELSE}
    ComputerName := 'Unknown';
    {$ENDIF}
    
    Parts.Add(ComputerName);
    
    // Generate hash
    RawFingerprint := Parts.Text;
    Result := THashSHA2.GetHashString(RawFingerprint, THashSHA2.TSHA2Version.SHA256);
    Result := Copy(Result, 1, 32); // Use first 32 chars
  finally
    Parts.Free;
  end;
end;

function TDeepBaseLicense.GetDeviceId: string;
begin
  if FCachedDeviceId = '' then
    FCachedDeviceId := GenerateDeviceFingerprint;
  Result := FCachedDeviceId;
end;

function TDeepBaseLicense.EncodePayload(const Payload: string): string;
var
  Bytes: TBytes;
begin
  Bytes := TEncoding.UTF8.GetBytes(Payload);
  Result := TNetEncoding.Base64URL.EncodeBytesToString(Bytes);
end;

function TDeepBaseLicense.DecodePayload(const Encoded: string): string;
var
  Bytes: TBytes;
begin
  try
    Bytes := TNetEncoding.Base64URL.DecodeStringToBytes(Encoded);
    Result := TEncoding.UTF8.GetString(Bytes);
  except
    Result := '';
  end;
end;

function TDeepBaseLicense.SignData(const Data: string): string;
var
  Combined: string;
begin
  if FSecretKey = '' then
    raise EInvalidOp.Create(
      'Legacy local license signing is disabled. Sign licenses on the server and set ' +
      LICENSE_LEGACY_SECRET_ENV + ' only for migration tooling.');

  Combined := Data + FSecretKey;
  Result := THashSHA2.GetHashString(Combined, THashSHA2.TSHA2Version.SHA256);
  Result := Copy(Result, 1, 16); // Short signature
end;

function TDeepBaseLicense.VerifySignature(const Data, Signature: string): Boolean;
var
  Expected: string;
  I, Diff: Integer;
begin
  Result := False;
  if FSecretKey = '' then
    Exit;

  Expected := SignData(Data);
  if Length(Expected) <> Length(Signature) then
    Exit;

  Diff := 0;
  for I := 1 to Length(Expected) do
    Diff := Diff or (Ord(UpCase(Expected[I])) xor Ord(UpCase(Signature[I])));

  Result := Diff = 0;
end;

class function TDeepBaseLicense.GenerateLicenseKey(
  LicenseType: TLicenseType;
  ExpiresAt: TDateTime;
  const IssuedTo: string;
  const DeviceId: string;
  const Features: TArray<string>;
  MaxUsers: Integer): string;
var
  JsonObj: TJSONObject;
  FeaturesArray: TJSONArray;
  F: string;
  Payload, PayloadEncoded, Signature: string;
  TempLicense: TDeepBaseLicense;
begin
  JsonObj := TJSONObject.Create;
  try
    JsonObj.AddPair('v', LICENSE_VERSION);
    JsonObj.AddPair('t', TJSONNumber.Create(Ord(LicenseType)));
    JsonObj.AddPair('e', TJSONNumber.Create(DateTimeToUnix(ExpiresAt)));
    JsonObj.AddPair('i', TJSONNumber.Create(DateTimeToUnix(Now)));
    JsonObj.AddPair('to', IssuedTo);
    JsonObj.AddPair('d', DeviceId);
    JsonObj.AddPair('u', TJSONNumber.Create(MaxUsers));
    
    FeaturesArray := TJSONArray.Create;
    for F in Features do
      FeaturesArray.Add(F);
    JsonObj.AddPair('f', FeaturesArray);
    
    Payload := JsonObj.ToJSON;
  finally
    JsonObj.Free;
  end;
  
  // Encode and sign
  TempLicense := TDeepBaseLicense.Create(nil);
  try
    PayloadEncoded := TempLicense.EncodePayload(Payload);
    Signature := TempLicense.SignData(PayloadEncoded);
  finally
    TempLicense.Free;
  end;
  
  Result := PayloadEncoded + '.' + Signature;
end;

function TDeepBaseLicense.ValidateLicense(const LicenseKey: string): TLicenseInfo;
var
  Parts: TArray<string>;
  PayloadEncoded, Signature, PayloadJson: string;
  JsonObj: TJSONObject;
  FeaturesArray: TJSONArray;
  I: Integer;
  LicenseDeviceId: string;
begin
  Result := TLicenseInfo.Empty;
  Result.LicenseKey := LicenseKey;
  
  if LicenseKey = '' then
    Exit;
  
  // Split key into payload and signature
  Parts := LicenseKey.Split(['.']);
  if Length(Parts) <> 2 then
  begin
    Result.Status := lsInvalid;
    Exit;
  end;
  
  PayloadEncoded := Parts[0];
  Signature := Parts[1];
  
  // Verify signature
  if not VerifySignature(PayloadEncoded, Signature) then
  begin
    Result.Status := lsTampered;
    Exit;
  end;
  
  // Decode payload
  PayloadJson := DecodePayload(PayloadEncoded);
  if PayloadJson = '' then
  begin
    Result.Status := lsInvalid;
    Exit;
  end;
  
  // Parse JSON
  try
    JsonObj := TJSONObject.ParseJSONValue(PayloadJson) as TJSONObject;
    if JsonObj = nil then
    begin
      Result.Status := lsInvalid;
      Exit;
    end;
    
    try
      Result.LicenseType := TLicenseType(JsonObj.GetValue<Integer>('t', 0));
      Result.ExpiresAt := UnixToDateTime(JsonObj.GetValue<Int64>('e', 0));
      Result.IssuedAt := UnixToDateTime(JsonObj.GetValue<Int64>('i', 0));
      Result.IssuedTo := JsonObj.GetValue<string>('to', '');
      Result.DeviceId := JsonObj.GetValue<string>('d', '');
      Result.MaxUsers := JsonObj.GetValue<Integer>('u', 1);
      
      // Parse features
      if JsonObj.TryGetValue<TJSONArray>('f', FeaturesArray) then
      begin
        SetLength(Result.Features, FeaturesArray.Count);
        for I := 0 to FeaturesArray.Count - 1 do
          Result.Features[I] := FeaturesArray.Items[I].Value;
      end;
    finally
      JsonObj.Free;
    end;
  except
    Result.Status := lsInvalid;
    Exit;
  end;
  
  // Check expiration
  if Result.IsExpired then
  begin
    Result.Status := lsExpired;
    Exit;
  end;
  
  // Check device binding (skip for Enterprise or empty device ID)
  LicenseDeviceId := Result.DeviceId;
  if (LicenseDeviceId <> '') and (Result.LicenseType <> ltEnterprise) then
  begin
    if not SameText(LicenseDeviceId, GetDeviceId) then
    begin
      Result.Status := lsDeviceMismatch;
      Exit;
    end;
  end;
  
  Result.Status := lsValid;
end;

function TDeepBaseLicense.ActivateLicense(const LicenseKey: string): Boolean;
var
  Info: TLicenseInfo;
begin
  Info := ValidateLicense(LicenseKey);
  Result := Info.Status = lsValid;
  
  if Result then
  begin
    FCurrentLicense := Info;
    if Assigned(FStorage) then
      SaveLicenseToDB(LicenseKey);
    
    if Assigned(FOnLicenseChanged) then
      FOnLicenseChanged(Self);
  end;
end;

procedure TDeepBaseLicense.DeactivateLicense;
begin
  FCurrentLicense := TLicenseInfo.Empty;
  
  if Assigned(FStorage) then
    ClearLicenseFromDB;
  
  if Assigned(FOnLicenseChanged) then
    FOnLicenseChanged(Self);
end;

function TDeepBaseLicense.IsFeatureLicensed(const FeatureName: string): Boolean;
begin
  if FCurrentLicense.Status <> lsValid then
    Exit(False);
  
  Result := FCurrentLicense.HasFeature(FeatureName);
end;

procedure TDeepBaseLicense.LoadLicenseFromDB;
var
  StoredKey: string;
begin
  if not Assigned(FStorage) then
    Exit;

  try
    StoredKey := FStorage.ReadLicenseKey;
    if StoredKey <> '' then
      FCurrentLicense := ValidateLicense(StoredKey);
  except
    // Table might not exist yet
  end;
end;

procedure TDeepBaseLicense.SaveLicenseToDB(const LicenseKey: string);
begin
  if not Assigned(FStorage) then
    Exit;

  FStorage.WriteLicenseKey(LicenseKey);
end;

procedure TDeepBaseLicense.ClearLicenseFromDB;
begin
  if not Assigned(FStorage) then
    Exit;

  FStorage.DeleteLicenseKey;
end;

class function TDeepBaseLicense.LicenseTypeToStr(LType: TLicenseType): string;
begin
  case LType of
    ltNone:       Result := 'None';
    ltTrial:      Result := 'Trial';
    ltStandard:   Result := 'Standard';
    ltPro:        Result := 'Professional';
    ltEnterprise: Result := 'Enterprise';
  else
    Result := 'Unknown';
  end;
end;

class function TDeepBaseLicense.StrToLicenseType(const S: string): TLicenseType;
var
  Upper: string;
begin
  Upper := UpperCase(Trim(S));
  if Upper = 'TRIAL' then Result := ltTrial
  else if Upper = 'STANDARD' then Result := ltStandard
  else if (Upper = 'PRO') or (Upper = 'PROFESSIONAL') then Result := ltPro
  else if Upper = 'ENTERPRISE' then Result := ltEnterprise
  else Result := ltNone;
end;

class function TDeepBaseLicense.LicenseStatusToStr(Status: TLicenseStatus): string;
begin
  case Status of
    lsInvalid:        Result := 'Invalid';
    lsValid:          Result := 'Valid';
    lsExpired:        Result := 'Expired';
    lsDeviceMismatch: Result := 'Device Mismatch';
    lsTampered:       Result := 'Tampered';
  else
    Result := 'Unknown';
  end;
end;

end.
