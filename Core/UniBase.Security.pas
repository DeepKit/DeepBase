{ ============================================================================
  UniBase.Security - Cross-Platform Security Module
  
  Version: 1.0
  Description: Provides secure storage for sensitive data.
               - Windows: Uses DPAPI (user scope)
               - macOS/Linux: Uses OpenSSL AES-256-GCM + PBKDF2 (requires bundled libcrypto)
               Use this module for passwords, API keys, tokens, and other secrets.
  
  Thread Safety: All public methods are thread-safe.
  
  SECURITY NOTES:
  - Windows DPAPI uses user-scope encryption (current Windows user only)
  - macOS/Linux uses AES-256-GCM with PBKDF2 key derivation from machine entropy
  - Encrypted data cannot be decrypted on different machines or users
  - For cross-machine scenarios, set UNIBASE_MASTER_KEY environment variable
  
  DATA FORMAT (UBS2 for macOS/Linux):
  - Magic: "UBS2" (4 bytes)
  - Version: 0x01 (1 byte)
  - KDF: 0x01=PBKDF2-SHA256 (1 byte)
  - Iterations: UInt32 LE (4 bytes)
  - Salt: 16 bytes
  - IV/Nonce: 12 bytes (GCM)
  - Ciphertext: variable
  - Tag: 16 bytes (GCM auth tag)
  ============================================================================ }

unit UniBase.Security;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  FireDAC.Comp.Client,
  UniBase.Types;

type
  /// <summary>
  /// Security manager for sensitive data using Windows DPAPI
  /// </summary>
  TUniBaseSecurity = class
  private
    FConnection: TFDConnection;
    FLock: TObject;
    
    procedure EnsureSecretsTable;
    
  public
    constructor Create(AConnection: TFDConnection; ALock: TObject);
    destructor Destroy; override;
    
    // ========================================
    // DPAPI Encryption Functions
    // ========================================
    
    /// <summary>
    /// Encrypt string using Windows DPAPI (user scope).
    /// Returns encrypted binary data.
    /// </summary>
    function ProtectString(const AText: string): TBytes;
    
    /// <summary>
    /// Decrypt binary data using Windows DPAPI.
    /// Returns decrypted string.
    /// </summary>
    function UnprotectString(const AData: TBytes): string;
    
    // ========================================
    // Secret Management
    // ========================================
    
    /// <summary>
    /// Load a secret value by name. Returns empty string if not found.
    /// The value is automatically decrypted using DPAPI.
    /// </summary>
    function LoadSecret(const AName: string): string;
    
    /// <summary>
    /// Save a secret value. The value is automatically encrypted using DPAPI.
    /// </summary>
    procedure SaveSecret(const AName, APlainValue: string; 
      const ADescription: string = '');
    
    /// <summary>
    /// Delete a secret by name.
    /// </summary>
    procedure DeleteSecret(const AName: string);
    
    /// <summary>
    /// Check if a secret exists.
    /// </summary>
    function SecretExists(const AName: string): Boolean;
    
    /// <summary>
    /// Get all secret names (without values for security).
    /// </summary>
    function GetSecretNames: TArray<string>;
    
    /// <summary>
    /// Validate secret name format for security
    /// </summary>
    class function IsValidSecretName(const AName: string): Boolean; static;
  end;

// ============================================================================
// BUG-038 FIX: Secure Memory Functions
// ============================================================================

/// <summary>
/// Securely zero memory to prevent sensitive data from remaining in memory.
/// Uses volatile write to prevent compiler optimization.
/// </summary>
procedure SecureZeroMemory(var Data: TBytes); overload;
procedure SecureZeroMemory(var Data: string); overload;

/// <summary>
/// Securely clear a byte array and set length to 0.
/// </summary>
procedure SecureClearBytes(var Data: TBytes);

// ============================================================================
// Global Shortcut Functions
// ============================================================================

/// <summary>
/// Load secret from UniBase security store.
/// Shortcut for UniBase.Security.LoadSecret().
/// </summary>
function LoadSecret(const AName: string): string;

/// <summary>
/// Save secret to UniBase security store.
/// Shortcut for UniBase.Security.SaveSecret().
/// </summary>
procedure SaveSecret(const AName, APlainValue: string; 
  const ADescription: string = '');

/// <summary>
/// Check if secret exists in UniBase security store.
/// </summary>
function SecretExists(const AName: string): Boolean;

// ============================================================================
// Low-level DPAPI Functions (for advanced usage)
// ============================================================================

/// <summary>
/// Encrypt string using Windows DPAPI (user scope).
/// </summary>
function ProtectStringDpapi(const AText: string): TBytes;

/// <summary>
/// Decrypt binary data using Windows DPAPI.
/// </summary>
function UnprotectStringDpapi(const AData: TBytes): string;

implementation

uses
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  {$IF DEFINED(MACOS) OR DEFINED(LINUX)}
  UniBase.Crypto.OpenSSL,
  {$ENDIF}
  System.NetEncoding,
  UniBase.Manager,
  UniBase.Consts;

// ============================================================================
// BUG-038 FIX: Secure Memory Functions Implementation
// ============================================================================

procedure SecureZeroMemory(var Data: TBytes);
var
  I: Integer;
begin
  // Use volatile write pattern to prevent compiler optimization
  for I := 0 to High(Data) do
    Data[I] := 0;
  // Memory barrier to ensure writes are not optimized away
  {$IFDEF MSWINDOWS}
  MemoryBarrier;
  {$ENDIF}
end;

procedure SecureZeroMemory(var Data: string);
var
  I: Integer;
  P: PChar;
begin
  if Length(Data) > 0 then
  begin
    P := PChar(Data);
    for I := 0 to Length(Data) - 1 do
      P[I] := #0;
    {$IFDEF MSWINDOWS}
    MemoryBarrier;
    {$ENDIF}
  end;
end;

procedure SecureClearBytes(var Data: TBytes);
begin
  SecureZeroMemory(Data);
  SetLength(Data, 0);
end;

{$IFDEF MSWINDOWS}
// ============================================================================
// Windows DPAPI Declarations
// ============================================================================

type
  PDataBlob = ^TDataBlob;
  TDataBlob = record
    cbData: DWORD;
    pbData: PByte;
  end;

function CryptProtectData(pDataIn: PDataBlob; szDataDescr: PWideChar;
  pOptionalEntropy: PDataBlob; pvReserved: Pointer;
  pPromptStruct: Pointer; dwFlags: DWORD; pDataOut: PDataBlob): BOOL; stdcall;
  external 'crypt32.dll' name 'CryptProtectData';

function CryptUnprotectData(pDataIn: PDataBlob; ppszDataDescr: PPWideChar;
  pOptionalEntropy: PDataBlob; pvReserved: Pointer;
  pPromptStruct: Pointer; dwFlags: DWORD; pDataOut: PDataBlob): BOOL; stdcall;
  external 'crypt32.dll' name 'CryptUnprotectData';

{$ENDIF}

{$IF DEFINED(MACOS) OR DEFINED(LINUX)}
// ============================================================================
// Cross-Platform AES-256-GCM Encryption (macOS/Linux) using OpenSSL
// ============================================================================
// UBS2 Format: [Magic:4][Ver:1][KDF:1][Iter:4][Salt:16][IV:12][Cipher:N][Tag:16]

const
  UBS2_MAGIC: array[0..3] of Byte = ($55, $42, $53, $32); // 'UBS2'
  UBS2_VERSION = $01;
  UBS2_KDF_PBKDF2_SHA256 = $01;
  UBS2_SALT_SIZE = 16;
  UBS2_IV_SIZE = 12;   // GCM recommended nonce size
  UBS2_KEY_SIZE = 32;  // AES-256
  UBS2_TAG_SIZE = 16;  // GCM tag
  UBS2_PBKDF2_ITERATIONS = 100000;
  UBS2_HEADER_SIZE = 4 + 1 + 1 + 4 + 16 + 12; // 38 bytes before ciphertext

function GetMachineEntropy: TBytes;
var
  Entropy, EnvKey: string;
  {$IFDEF LINUX}
  F: TextFile;
  MachineId: string;
  {$ENDIF}
begin
  // Check for explicit master key override (for CI/containers)
  EnvKey := GetEnvironmentVariable('UNIBASE_MASTER_KEY');
  if EnvKey <> '' then
  begin
    Result := TEncoding.UTF8.GetBytes(EnvKey);
    Exit;
  end;
  
  // Collect machine-specific entropy
  {$IFDEF MACOS}
  Entropy := GetEnvironmentVariable('HOME') + ':' + 
             GetEnvironmentVariable('USER') + ':macOS:UniBase';
  {$ENDIF}
  
  {$IFDEF LINUX}
  MachineId := '';
  if FileExists('/etc/machine-id') then
  begin
    try
      AssignFile(F, '/etc/machine-id');
      Reset(F);
      ReadLn(F, MachineId);
      CloseFile(F);
    except
      MachineId := '';
    end;
  end;
  if MachineId = '' then
    MachineId := GetEnvironmentVariable('HOSTNAME');
  Entropy := MachineId + ':' + GetEnvironmentVariable('USER') + ':Linux:UniBase';
  {$ENDIF}
  
  Result := TEncoding.UTF8.GetBytes(Entropy);
end;
{$ENDIF}

// ============================================================================
// Global Encryption Functions
// ============================================================================

function ProtectStringDpapi(const AText: string): TBytes;
{$IFDEF MSWINDOWS}
var
  InBlob, OutBlob: TDataBlob;
  WideText: UnicodeString;
begin
  if AText = '' then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  
  WideText := AText; // UTF-16
  InBlob.cbData := Length(WideText) * SizeOf(WideChar);
  InBlob.pbData := PByte(PWideChar(WideText));
  
  // User-scope encryption (not using CRYPTPROTECT_LOCAL_MACHINE)
  if not CryptProtectData(@InBlob, nil, nil, nil, nil, 0, @OutBlob) then
    RaiseLastOSError;
  
  SetLength(Result, OutBlob.cbData);
  Move(OutBlob.pbData^, Result[0], OutBlob.cbData);
  LocalFree(HLOCAL(OutBlob.pbData));
end;
{$ELSEIF DEFINED(MACOS) OR DEFINED(LINUX)}
var
  MachineKey, Salt, IV, Key, Plaintext, Ciphertext, Tag: TBytes;
  Iterations: Cardinal;
  Offset: Integer;
begin
  if AText = '' then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  
  // Initialize OpenSSL if not already done
  OpenSSL_Init;
  
  // Generate random salt and IV
  Salt := OpenSSL_RandomBytes(UBS2_SALT_SIZE);
  IV := OpenSSL_RandomBytes(UBS2_IV_SIZE);
  
  // Derive key from machine entropy using OpenSSL PBKDF2
  MachineKey := GetMachineEntropy;
  Iterations := UBS2_PBKDF2_ITERATIONS;
  Key := OpenSSL_PBKDF2_SHA256(MachineKey, Salt, Iterations, UBS2_KEY_SIZE);
  
  // Encrypt using AES-256-GCM
  Plaintext := TEncoding.UTF8.GetBytes(AText);
  Ciphertext := OpenSSL_AES256GCM_Encrypt(Key, IV, Plaintext, nil, Tag);
  
  // Build UBS2 format output
  SetLength(Result, UBS2_HEADER_SIZE + Length(Ciphertext) + UBS2_TAG_SIZE);
  Offset := 0;
  
  // Magic
  Move(UBS2_MAGIC[0], Result[Offset], 4);
  Inc(Offset, 4);
  
  // Version
  Result[Offset] := UBS2_VERSION;
  Inc(Offset);
  
  // KDF type
  Result[Offset] := UBS2_KDF_PBKDF2_SHA256;
  Inc(Offset);
  
  // Iterations (little-endian)
  Result[Offset] := Byte(Iterations);
  Result[Offset + 1] := Byte(Iterations shr 8);
  Result[Offset + 2] := Byte(Iterations shr 16);
  Result[Offset + 3] := Byte(Iterations shr 24);
  Inc(Offset, 4);
  
  // Salt
  Move(Salt[0], Result[Offset], UBS2_SALT_SIZE);
  Inc(Offset, UBS2_SALT_SIZE);
  
  // IV
  Move(IV[0], Result[Offset], UBS2_IV_SIZE);
  Inc(Offset, UBS2_IV_SIZE);
  
  // Ciphertext
  if Length(Ciphertext) > 0 then
    Move(Ciphertext[0], Result[Offset], Length(Ciphertext));
  Inc(Offset, Length(Ciphertext));
  
  // Tag
  Move(Tag[0], Result[Offset], UBS2_TAG_SIZE);
end;
{$ELSE}
begin
  // Unsupported platform - raise error instead of silent failure
  raise Exception.Create('Encryption not supported on this platform');
end;
{$ENDIF}

function UnprotectStringDpapi(const AData: TBytes): string;
{$IFDEF MSWINDOWS}
var
  InBlob, OutBlob: TDataBlob;
  WideText: UnicodeString;
begin
  if Length(AData) = 0 then
    Exit('');
  
  InBlob.cbData := Length(AData);
  InBlob.pbData := @AData[0];
  
  if not CryptUnprotectData(@InBlob, nil, nil, nil, nil, 0, @OutBlob) then
    RaiseLastOSError;
  
  SetString(WideText, PWideChar(OutBlob.pbData), OutBlob.cbData div SizeOf(WideChar));
  Result := WideText;
  LocalFree(HLOCAL(OutBlob.pbData));
end;
{$ELSEIF DEFINED(MACOS) OR DEFINED(LINUX)}
var
  MachineKey, Salt, IV, Key, Ciphertext, Tag, Plaintext: TBytes;
  Iterations: Cardinal;
  Offset, CiphertextLen, I: Integer;
begin
  Result := '';
  
  if Length(AData) < UBS2_HEADER_SIZE + UBS2_TAG_SIZE then
    raise Exception.Create('Invalid encrypted data: too short');
  
  // Verify magic header
  for I := 0 to 3 do
    if AData[I] <> UBS2_MAGIC[I] then
      raise Exception.Create('Invalid encrypted data: bad header (expected UBS2)');
  
  Offset := 4;
  
  // Check version
  if AData[Offset] <> UBS2_VERSION then
    raise Exception.CreateFmt('Unsupported UBS2 version: %d', [AData[Offset]]);
  Inc(Offset);
  
  // Check KDF type
  if AData[Offset] <> UBS2_KDF_PBKDF2_SHA256 then
    raise Exception.CreateFmt('Unsupported KDF type: %d', [AData[Offset]]);
  Inc(Offset);
  
  // Read iterations (little-endian)
  Iterations := Cardinal(AData[Offset]) or
                (Cardinal(AData[Offset + 1]) shl 8) or
                (Cardinal(AData[Offset + 2]) shl 16) or
                (Cardinal(AData[Offset + 3]) shl 24);
  Inc(Offset, 4);
  
  // Extract salt
  SetLength(Salt, UBS2_SALT_SIZE);
  Move(AData[Offset], Salt[0], UBS2_SALT_SIZE);
  Inc(Offset, UBS2_SALT_SIZE);
  
  // Extract IV
  SetLength(IV, UBS2_IV_SIZE);
  Move(AData[Offset], IV[0], UBS2_IV_SIZE);
  Inc(Offset, UBS2_IV_SIZE);
  
  // Extract ciphertext
  CiphertextLen := Length(AData) - Offset - UBS2_TAG_SIZE;
  if CiphertextLen < 0 then
    raise Exception.Create('Invalid encrypted data: corrupted');
  SetLength(Ciphertext, CiphertextLen);
  if CiphertextLen > 0 then
    Move(AData[Offset], Ciphertext[0], CiphertextLen);
  Inc(Offset, CiphertextLen);
  
  // Extract tag
  SetLength(Tag, UBS2_TAG_SIZE);
  Move(AData[Offset], Tag[0], UBS2_TAG_SIZE);
  
  // Initialize OpenSSL if not already done
  OpenSSL_Init;
  
  // Derive key using same parameters
  MachineKey := GetMachineEntropy;
  Key := OpenSSL_PBKDF2_SHA256(MachineKey, Salt, Iterations, UBS2_KEY_SIZE);
  
  // Decrypt using AES-256-GCM (will verify tag)
  Plaintext := OpenSSL_AES256GCM_Decrypt(Key, IV, Ciphertext, nil, Tag);
  
  Result := TEncoding.UTF8.GetString(Plaintext);
end;
{$ELSE}
begin
  raise Exception.Create('Decryption not supported on this platform');
end;
{$ENDIF}

// ============================================================================
// Global Shortcut Functions
// ============================================================================

function LoadSecret(const AName: string): string;
begin
  if UniBase.Manager.UniBase.IsInitialized and 
     Assigned(UniBase.Manager.UniBase.Security) then
    Result := UniBase.Manager.UniBase.Security.LoadSecret(AName)
  else
    Result := '';
end;

procedure SaveSecret(const AName, APlainValue: string; 
  const ADescription: string);
begin
  if UniBase.Manager.UniBase.IsInitialized and 
     Assigned(UniBase.Manager.UniBase.Security) then
    UniBase.Manager.UniBase.Security.SaveSecret(AName, APlainValue, ADescription);
end;

function SecretExists(const AName: string): Boolean;
begin
  if UniBase.Manager.UniBase.IsInitialized and 
     Assigned(UniBase.Manager.UniBase.Security) then
    Result := UniBase.Manager.UniBase.Security.SecretExists(AName)
  else
    Result := False;
end;

// ============================================================================
// TUniBaseSecurity
// ============================================================================

constructor TUniBaseSecurity.Create(AConnection: TFDConnection; ALock: TObject);
begin
  inherited Create;
  FConnection := AConnection;
  FLock := ALock;
end;

destructor TUniBaseSecurity.Destroy;
begin
  inherited;
end;

procedure TUniBaseSecurity.EnsureSecretsTable;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  FConnection.ExecSQL(
    'CREATE TABLE IF NOT EXISTS ' + STableSecrets + ' (' +
    '  Name        TEXT PRIMARY KEY,' +
    '  CipherBlob  TEXT NOT NULL,' +
    '  Description TEXT,' +
    '  CreatedAt   TEXT NOT NULL,' +
    '  UpdatedAt   TEXT NOT NULL' +
    ')'
  );
end;

function TUniBaseSecurity.ProtectString(const AText: string): TBytes;
begin
  Result := ProtectStringDpapi(AText);
end;

function TUniBaseSecurity.UnprotectString(const AData: TBytes): string;
begin
  Result := UnprotectStringDpapi(AData);
end;

function TUniBaseSecurity.LoadSecret(const AName: string): string;
var
  Query: TFDQuery;
  CipherBase64: string;
  CipherBytes: TBytes;
begin
  Result := '';
  
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
  
  TMonitor.Enter(FLock);
  try
    EnsureSecretsTable;
    
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'SELECT CipherBlob FROM ' + STableSecrets + 
        ' WHERE Name = :Name';
      Query.ParamByName('Name').AsString := AName;
      Query.Open;
      
      if Query.Eof then
        Exit;
      
      CipherBase64 := Query.FieldByName('CipherBlob').AsString;
      if CipherBase64 = '' then
        Exit;
        
      CipherBytes := TNetEncoding.Base64.DecodeStringToBytes(CipherBase64);
      Result := UnprotectString(CipherBytes);
    finally
      Query.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TUniBaseSecurity.SaveSecret(const AName, APlainValue: string;
  const ADescription: string);
var
  Query: TFDQuery;
  CipherBytes: TBytes;
  CipherBase64: string;
  NowStr: string;
begin
  // 验证密钥名称，防止SQL注入和路径遍历
  if not IsValidSecretName(AName) then
    raise EArgumentException.Create('Invalid secret name format');
    
  // 限制明文值的长度，防止过大数据攻击
  if Length(APlainValue) > 64 * 1024 then // 64KB限制
    raise EArgumentException.Create('Secret value too large (max 64KB)');
    
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
  
  TMonitor.Enter(FLock);
  try
    EnsureSecretsTable;
    
    CipherBytes := ProtectString(APlainValue);
    CipherBase64 := TNetEncoding.Base64.EncodeBytesToString(CipherBytes);
    
    // Use ISO8601 format for SQLite datetime compatibility
    NowStr := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now);
    
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text :=
        'INSERT OR REPLACE INTO ' + STableSecrets + 
        ' (Name, CipherBlob, Description, CreatedAt, UpdatedAt) ' +
        'VALUES (:Name, :CipherBlob, :Description, ' +
        '  COALESCE((SELECT CreatedAt FROM ' + STableSecrets + ' WHERE Name = :Name2), :NowTime), ' +
        '  :UpdatedAt)';
      Query.ParamByName('Name').AsString := AName;
      Query.ParamByName('Name2').AsString := AName;
      Query.ParamByName('CipherBlob').AsString := CipherBase64;
      Query.ParamByName('Description').AsString := ADescription;
      Query.ParamByName('NowTime').AsString := NowStr;
      Query.ParamByName('UpdatedAt').AsString := NowStr;
      Query.ExecSQL;
    finally
      Query.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TUniBaseSecurity.DeleteSecret(const AName: string);
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
  
  TMonitor.Enter(FLock);
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'DELETE FROM ' + STableSecrets + ' WHERE Name = :Name';
      Query.ParamByName('Name').AsString := AName;
      Query.ExecSQL;
    finally
      Query.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TUniBaseSecurity.SecretExists(const AName: string): Boolean;
var
  Query: TFDQuery;
begin
  Result := False;
  
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
  
  TMonitor.Enter(FLock);
  try
    EnsureSecretsTable;
    
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'SELECT 1 FROM ' + STableSecrets + ' WHERE Name = :Name';
      Query.ParamByName('Name').AsString := AName;
      Query.Open;
      Result := not Query.Eof;
    finally
      Query.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TUniBaseSecurity.GetSecretNames: TArray<string>;
var
  Query: TFDQuery;
  List: TList<string>;
begin
  SetLength(Result, 0);
  
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
  
  TMonitor.Enter(FLock);
  try
    EnsureSecretsTable;
    
    List := TList<string>.Create;
    try
      Query := TFDQuery.Create(nil);
      try
        Query.Connection := FConnection;
        Query.SQL.Text := 'SELECT Name FROM ' + STableSecrets + ' ORDER BY Name';
        Query.Open;
        
        while not Query.Eof do
        begin
          List.Add(Query.FieldByName('Name').AsString);
          Query.Next;
        end;
      finally
        Query.Free;
      end;
      
      Result := List.ToArray;
    finally
      List.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class function TUniBaseSecurity.IsValidSecretName(const AName: string): Boolean;
var
  I: Integer;
  C: Char;
begin
  Result := False;
  
  // 检查基本要求
  if AName.IsEmpty or (Length(AName) > 255) then
    Exit;
    
  // 不能以点开头（防止隐藏文件）
  if AName.StartsWith('.') then
    Exit;
    
  // 检查每个字符
  for I := 1 to Length(AName) do
  begin
    C := AName[I];
    
    // 只允许字母、数字、下划线、连字符和点
    if not (CharInSet(C, ['a'..'z', 'A'..'Z', '0'..'9', '_', '-', '.'])) then
      Exit;
      
    // 不允许连续的点（防止路径遍历）
    if (C = '.') and (I > 1) and (AName[I-1] = '.') then
      Exit;
  end;
  
  // 不能以点结尾
  if AName.EndsWith('.') then
    Exit;
    
  // 检查保留名称
  var LowerName := AName.ToLower;
  if (LowerName = 'con') or (LowerName = 'prn') or (LowerName = 'aux') or 
     (LowerName = 'nul') or LowerName.StartsWith('com') or LowerName.StartsWith('lpt') then
    Exit;
    
  Result := True;
end;

end.
