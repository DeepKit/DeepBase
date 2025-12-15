{ ============================================================================
  UniBase.Security.DPAPI - Windows Data Protection API Wrapper
  
  Version: 1.0
  Description: Provides secure storage for sensitive data using Windows DPAPI.
               DPAPI encrypts data tied to current user or local machine.
  
  Features:
    - User-scope encryption (default) - data can only be decrypted by same user
    - Machine-scope encryption - data can be decrypted by any user on same machine
    - Optional entropy for additional security
    - Windows Credential Manager integration
    - Secure string helpers
    
  Usage:
    // Encrypt/decrypt string
    Encrypted := TDPAPIHelper.ProtectString('my secret');
    Decrypted := TDPAPIHelper.UnprotectString(Encrypted);
    
    // Encrypt/decrypt bytes
    EncryptedBytes := TDPAPIHelper.Protect(PlainBytes);
    PlainBytes := TDPAPIHelper.Unprotect(EncryptedBytes);
    
    // With entropy (additional password)
    Encrypted := TDPAPIHelper.ProtectString('secret', TEncoding.UTF8.GetBytes('entropy'));
    
    // Credential Manager
    TCredentialManager.SaveCredential('MyApp', 'username', 'password');
    Password := TCredentialManager.GetCredential('MyApp', 'username');
  ============================================================================ }

unit UniBase.Security.DPAPI;

interface

uses
  System.SysUtils, System.Classes,
  {$IFDEF MSWINDOWS}
  Winapi.Windows
  {$ENDIF};

{$IFDEF MSWINDOWS}

type
  EDPAPIError = class(Exception);
  ECredentialError = class(Exception);
  
  /// <summary>Protection scope</summary>
  TProtectionScope = (
    psCurrentUser,    // Encrypt for current user only (default)
    psLocalMachine    // Encrypt for any user on this machine
  );
  
  /// <summary>
  /// Windows DPAPI Helper Class
  /// </summary>
  TDPAPIHelper = class
  public
    /// <summary>Protect (encrypt) bytes using DPAPI</summary>
    class function Protect(const APlainData: TBytes; 
      AScope: TProtectionScope = psCurrentUser;
      const AEntropy: TBytes = nil): TBytes; static;
    
    /// <summary>Unprotect (decrypt) bytes using DPAPI</summary>
    class function Unprotect(const AEncryptedData: TBytes;
      const AEntropy: TBytes = nil): TBytes; static;
    
    /// <summary>Protect string and return Base64-encoded result</summary>
    class function ProtectString(const APlainText: string;
      AScope: TProtectionScope = psCurrentUser;
      const AEntropy: TBytes = nil): string; static;
    
    /// <summary>Unprotect Base64-encoded string</summary>
    class function UnprotectString(const AEncryptedBase64: string;
      const AEntropy: TBytes = nil): string; static;
    
    /// <summary>Protect string to file</summary>
    class procedure ProtectToFile(const APlainText, AFileName: string;
      AScope: TProtectionScope = psCurrentUser;
      const AEntropy: TBytes = nil); static;
    
    /// <summary>Unprotect string from file</summary>
    class function UnprotectFromFile(const AFileName: string;
      const AEntropy: TBytes = nil): string; static;
    
    /// <summary>Check if DPAPI is available</summary>
    class function IsAvailable: Boolean; static;
  end;
  
  /// <summary>
  /// Windows Credential Manager Helper
  /// </summary>
  TCredentialManager = class
  public
    /// <summary>Save credential to Windows Credential Manager</summary>
    class procedure SaveCredential(const ATargetName, AUserName, APassword: string); static;
    
    /// <summary>Get password from Windows Credential Manager</summary>
    class function GetCredential(const ATargetName: string; out AUserName, APassword: string): Boolean; overload; static;
    class function GetCredential(const ATargetName, AUserName: string): string; overload; static;
    
    /// <summary>Delete credential from Windows Credential Manager</summary>
    class function DeleteCredential(const ATargetName: string): Boolean; static;
    
    /// <summary>Check if credential exists</summary>
    class function CredentialExists(const ATargetName: string): Boolean; static;
    
    /// <summary>List all credentials for a target prefix</summary>
    class function ListCredentials(const ATargetPrefix: string = ''): TArray<string>; static;
  end;
  
  /// <summary>
  /// Secure string helper - auto-clears memory on destruction
  /// </summary>
  TSecureString = class
  private
    FData: TBytes;
    FDataLength: Integer;
  public
    constructor Create(const AValue: string); overload;
    constructor Create(const AData: TBytes); overload;
    destructor Destroy; override;
    
    function ToString: string; override;
    function ToBytes: TBytes;
    procedure Clear;
    
    property DataLength: Integer read FDataLength;
  end;

// DPAPI function declarations
type
  DATA_BLOB = record
    cbData: DWORD;
    pbData: PByte;
  end;
  PDATA_BLOB = ^DATA_BLOB;
  
  CRYPTPROTECT_PROMPTSTRUCT = record
    cbSize: DWORD;
    dwPromptFlags: DWORD;
    hwndApp: HWND;
    szPrompt: PWideChar;
  end;
  PCRYPTPROTECT_PROMPTSTRUCT = ^CRYPTPROTECT_PROMPTSTRUCT;

const
  CRYPTPROTECT_UI_FORBIDDEN = $1;
  CRYPTPROTECT_LOCAL_MACHINE = $4;
  
  // Credential Manager constants
  CRED_TYPE_GENERIC = 1;
  CRED_PERSIST_LOCAL_MACHINE = 2;
  CRED_PERSIST_ENTERPRISE = 3;

type
  PCREDENTIALW = ^CREDENTIALW;
  CREDENTIALW = record
    Flags: DWORD;
    _Type: DWORD;
    TargetName: PWideChar;
    Comment: PWideChar;
    LastWritten: TFileTime;
    CredentialBlobSize: DWORD;
    CredentialBlob: PByte;
    Persist: DWORD;
    AttributeCount: DWORD;
    Attributes: Pointer;
    TargetAlias: PWideChar;
    UserName: PWideChar;
  end;
  PPCREDENTIALW = ^PCREDENTIALW;

function CryptProtectData(pDataIn: PDATA_BLOB; szDataDescr: LPCWSTR;
  pOptionalEntropy: PDATA_BLOB; pvReserved: Pointer; 
  pPromptStruct: PCRYPTPROTECT_PROMPTSTRUCT;
  dwFlags: DWORD; pDataOut: PDATA_BLOB): BOOL; stdcall; external 'Crypt32.dll';

function CryptUnprotectData(pDataIn: PDATA_BLOB; ppszDataDescr: PLPWSTR;
  pOptionalEntropy: PDATA_BLOB; pvReserved: Pointer;
  pPromptStruct: PCRYPTPROTECT_PROMPTSTRUCT;
  dwFlags: DWORD; pDataOut: PDATA_BLOB): BOOL; stdcall; external 'Crypt32.dll';

function CredWriteW(Credential: PCREDENTIALW; Flags: DWORD): BOOL; stdcall; 
  external 'Advapi32.dll';

function CredReadW(TargetName: LPCWSTR; _Type: DWORD; Flags: DWORD;
  out Credential: PCREDENTIALW): BOOL; stdcall; external 'Advapi32.dll';

function CredDeleteW(TargetName: LPCWSTR; _Type: DWORD; Flags: DWORD): BOOL; stdcall;
  external 'Advapi32.dll';

function CredFree(Buffer: Pointer): BOOL; stdcall; external 'Advapi32.dll';

function CredEnumerateW(Filter: LPCWSTR; Flags: DWORD; out Count: DWORD;
  out Credentials: PPCREDENTIALW): BOOL; stdcall; external 'Advapi32.dll';

{$ENDIF}

implementation

uses
  System.NetEncoding;

{$IFDEF MSWINDOWS}

{ TDPAPIHelper }

class function TDPAPIHelper.Protect(const APlainData: TBytes;
  AScope: TProtectionScope; const AEntropy: TBytes): TBytes;
var
  DataIn, DataOut, EntropyBlob: DATA_BLOB;
  pEntropy: PDATA_BLOB;
  Flags: DWORD;
begin
  SetLength(Result, 0);
  
  if Length(APlainData) = 0 then
    Exit;
  
  DataIn.cbData := Length(APlainData);
  DataIn.pbData := @APlainData[0];
  
  DataOut.cbData := 0;
  DataOut.pbData := nil;
  
  // Setup entropy if provided
  if Length(AEntropy) > 0 then
  begin
    EntropyBlob.cbData := Length(AEntropy);
    EntropyBlob.pbData := @AEntropy[0];
    pEntropy := @EntropyBlob;
  end
  else
    pEntropy := nil;
  
  // Setup flags
  Flags := CRYPTPROTECT_UI_FORBIDDEN;
  if AScope = psLocalMachine then
    Flags := Flags or CRYPTPROTECT_LOCAL_MACHINE;
  
  if CryptProtectData(@DataIn, nil, pEntropy, nil, nil, Flags, @DataOut) then
  begin
    try
      SetLength(Result, DataOut.cbData);
      Move(DataOut.pbData^, Result[0], DataOut.cbData);
    finally
      LocalFree(HLOCAL(DataOut.pbData));
    end;
  end
  else
    raise EDPAPIError.Create('DPAPI 加密失败: ' + SysErrorMessage(GetLastError));
end;

class function TDPAPIHelper.Unprotect(const AEncryptedData: TBytes;
  const AEntropy: TBytes): TBytes;
var
  DataIn, DataOut, EntropyBlob: DATA_BLOB;
  pEntropy: PDATA_BLOB;
begin
  SetLength(Result, 0);
  
  if Length(AEncryptedData) = 0 then
    Exit;
  
  DataIn.cbData := Length(AEncryptedData);
  DataIn.pbData := @AEncryptedData[0];
  
  DataOut.cbData := 0;
  DataOut.pbData := nil;
  
  // Setup entropy if provided
  if Length(AEntropy) > 0 then
  begin
    EntropyBlob.cbData := Length(AEntropy);
    EntropyBlob.pbData := @AEntropy[0];
    pEntropy := @EntropyBlob;
  end
  else
    pEntropy := nil;
  
  if CryptUnprotectData(@DataIn, nil, pEntropy, nil, nil, CRYPTPROTECT_UI_FORBIDDEN, @DataOut) then
  begin
    try
      SetLength(Result, DataOut.cbData);
      Move(DataOut.pbData^, Result[0], DataOut.cbData);
    finally
      // Zero and free memory
      if DataOut.pbData <> nil then
      begin
        FillChar(DataOut.pbData^, DataOut.cbData, 0);
        LocalFree(HLOCAL(DataOut.pbData));
      end;
    end;
  end
  else
    raise EDPAPIError.Create('DPAPI 解密失败: ' + SysErrorMessage(GetLastError));
end;

class function TDPAPIHelper.ProtectString(const APlainText: string;
  AScope: TProtectionScope; const AEntropy: TBytes): string;
var
  PlainBytes, EncryptedBytes: TBytes;
begin
  PlainBytes := TEncoding.UTF8.GetBytes(APlainText);
  try
    EncryptedBytes := Protect(PlainBytes, AScope, AEntropy);
    Result := TNetEncoding.Base64.EncodeBytesToString(EncryptedBytes);
  finally
    // Clear sensitive data
    if Length(PlainBytes) > 0 then
      FillChar(PlainBytes[0], Length(PlainBytes), 0);
  end;
end;

class function TDPAPIHelper.UnprotectString(const AEncryptedBase64: string;
  const AEntropy: TBytes): string;
var
  EncryptedBytes, PlainBytes: TBytes;
begin
  EncryptedBytes := TNetEncoding.Base64.DecodeStringToBytes(AEncryptedBase64);
  PlainBytes := Unprotect(EncryptedBytes, AEntropy);
  try
    Result := TEncoding.UTF8.GetString(PlainBytes);
  finally
    // Clear sensitive data
    if Length(PlainBytes) > 0 then
      FillChar(PlainBytes[0], Length(PlainBytes), 0);
  end;
end;

class procedure TDPAPIHelper.ProtectToFile(const APlainText, AFileName: string;
  AScope: TProtectionScope; const AEntropy: TBytes);
var
  PlainBytes, EncryptedBytes: TBytes;
  FileStream: TFileStream;
begin
  PlainBytes := TEncoding.UTF8.GetBytes(APlainText);
  try
    EncryptedBytes := Protect(PlainBytes, AScope, AEntropy);
    
    FileStream := TFileStream.Create(AFileName, fmCreate);
    try
      FileStream.WriteBuffer(EncryptedBytes[0], Length(EncryptedBytes));
    finally
      FileStream.Free;
    end;
  finally
    // Clear sensitive data
    if Length(PlainBytes) > 0 then
      FillChar(PlainBytes[0], Length(PlainBytes), 0);
  end;
end;

class function TDPAPIHelper.UnprotectFromFile(const AFileName: string;
  const AEntropy: TBytes): string;
var
  FileStream: TFileStream;
  EncryptedBytes, PlainBytes: TBytes;
begin
  FileStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(EncryptedBytes, FileStream.Size);
    FileStream.ReadBuffer(EncryptedBytes[0], FileStream.Size);
  finally
    FileStream.Free;
  end;
  
  PlainBytes := Unprotect(EncryptedBytes, AEntropy);
  try
    Result := TEncoding.UTF8.GetString(PlainBytes);
  finally
    // Clear sensitive data
    if Length(PlainBytes) > 0 then
      FillChar(PlainBytes[0], Length(PlainBytes), 0);
  end;
end;

class function TDPAPIHelper.IsAvailable: Boolean;
var
  TestData: TBytes;
begin
  Result := False;
  try
    TestData := TEncoding.UTF8.GetBytes('test');
    Unprotect(Protect(TestData));
    Result := True;
  except
    Result := False;
  end;
end;

{ TCredentialManager }

class procedure TCredentialManager.SaveCredential(const ATargetName, AUserName, APassword: string);
var
  Cred: CREDENTIALW;
  PasswordBytes: TBytes;
begin
  PasswordBytes := TEncoding.Unicode.GetBytes(APassword);
  
  FillChar(Cred, SizeOf(Cred), 0);
  Cred._Type := CRED_TYPE_GENERIC;
  Cred.TargetName := PWideChar(ATargetName);
  Cred.UserName := PWideChar(AUserName);
  Cred.CredentialBlobSize := Length(PasswordBytes);
  Cred.CredentialBlob := @PasswordBytes[0];
  Cred.Persist := CRED_PERSIST_LOCAL_MACHINE;
  
  if not CredWriteW(@Cred, 0) then
    raise ECredentialError.Create('保存凭据失败: ' + SysErrorMessage(GetLastError));
end;

class function TCredentialManager.GetCredential(const ATargetName: string;
  out AUserName, APassword: string): Boolean;
var
  Cred: PCREDENTIALW;
  PassBytes: TBytes;
begin
  Result := False;
  AUserName := '';
  APassword := '';
  
  if CredReadW(PWideChar(ATargetName), CRED_TYPE_GENERIC, 0, Cred) then
  begin
    try
      if Cred.UserName <> nil then
        AUserName := Cred.UserName;
      
      if (Cred.CredentialBlob <> nil) and (Cred.CredentialBlobSize > 0) then
      begin
        SetLength(PassBytes, Cred.CredentialBlobSize);
        Move(Cred.CredentialBlob^, PassBytes[0], Cred.CredentialBlobSize);
        APassword := TEncoding.Unicode.GetString(PassBytes);
      end;
      
      Result := True;
    finally
      CredFree(Cred);
    end;
  end;
end;

class function TCredentialManager.GetCredential(const ATargetName, AUserName: string): string;
var
  User, Pass: string;
begin
  Result := '';
  if GetCredential(ATargetName, User, Pass) then
  begin
    if (AUserName = '') or (User = AUserName) then
      Result := Pass;
  end;
end;

class function TCredentialManager.DeleteCredential(const ATargetName: string): Boolean;
begin
  Result := CredDeleteW(PWideChar(ATargetName), CRED_TYPE_GENERIC, 0);
end;

class function TCredentialManager.CredentialExists(const ATargetName: string): Boolean;
var
  Cred: PCREDENTIALW;
begin
  Result := CredReadW(PWideChar(ATargetName), CRED_TYPE_GENERIC, 0, Cred);
  if Result then
    CredFree(Cred);
end;

class function TCredentialManager.ListCredentials(const ATargetPrefix: string): TArray<string>;
var
  Count: DWORD;
  Credentials: PPCREDENTIALW;
  CredArray: array of PCREDENTIALW absolute Credentials;
  I: Integer;
  Filter: PWideChar;
begin
  SetLength(Result, 0);
  
  if ATargetPrefix = '' then
    Filter := nil
  else
    Filter := PWideChar(ATargetPrefix + '*');
  
  if CredEnumerateW(Filter, 0, Count, Credentials) then
  begin
    try
      SetLength(Result, Count);
      for I := 0 to Count - 1 do
      begin
        // Access via pointer arithmetic
        Result[I] := PPCREDENTIALW(PByte(Credentials) + I * SizeOf(PCREDENTIALW))^.TargetName;
      end;
    finally
      CredFree(Credentials);
    end;
  end;
end;

{ TSecureString }

constructor TSecureString.Create(const AValue: string);
begin
  inherited Create;
  FData := TEncoding.UTF8.GetBytes(AValue);
  FDataLength := System.Length(FData);
end;

constructor TSecureString.Create(const AData: TBytes);
begin
  inherited Create;
  SetLength(FData, System.Length(AData));
  if System.Length(AData) > 0 then
    Move(AData[0], FData[0], System.Length(AData));
  FDataLength := System.Length(FData);
end;

destructor TSecureString.Destroy;
begin
  Clear;
  inherited;
end;

function TSecureString.ToString: string;
begin
  Result := TEncoding.UTF8.GetString(FData);
end;

function TSecureString.ToBytes: TBytes;
begin
  SetLength(Result, FDataLength);
  if FDataLength > 0 then
    Move(FData[0], Result[0], FDataLength);
end;

procedure TSecureString.Clear;
begin
  if System.Length(FData) > 0 then
  begin
    FillChar(FData[0], System.Length(FData), 0);
    SetLength(FData, 0);
  end;
  FDataLength := 0;
end;

{$ENDIF}

end.
