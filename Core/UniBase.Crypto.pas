unit UniBase.Crypto;

{*******************************************************************************
  UniBase Cryptography Utilities
  A comprehensive cryptography module with:
  - Hash algorithms (MD5, SHA1, SHA256, SHA384, SHA512)
  - Encoding (Base64, Hex, URL encoding)
  - Symmetric encryption (AES)
  - Password hashing (PBKDF2, BCrypt-style)
  - Random data generation
  - HMAC support
  
  Author: UniBase Team
  Created: 2025-11-29
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Hash, System.NetEncoding,
  System.Generics.Collections,
  {$IFDEF MSWINDOWS}
  Winapi.Windows
  {$ENDIF};

{$IFDEF MSWINDOWS}
const
  BCRYPT_DLL = 'bcrypt.dll';
  BCRYPT_AES_ALGORITHM = 'AES';
  BCRYPT_CHAIN_MODE_CBC = 'ChainingModeCBC';
  BCRYPT_CHAINING_MODE = 'ChainingMode';
  BCRYPT_OBJECT_LENGTH = 'ObjectLength';
  BCRYPT_BLOCK_LENGTH = 'BlockLength';
  
type
  BCRYPT_ALG_HANDLE = THandle;
  BCRYPT_KEY_HANDLE = THandle;
  NTSTATUS = LongInt;

function BCryptOpenAlgorithmProvider(out phAlgorithm: BCRYPT_ALG_HANDLE;
  pszAlgId: PWideChar; pszImplementation: PWideChar; dwFlags: ULONG): NTSTATUS; stdcall;
  external BCRYPT_DLL;
  
function BCryptCloseAlgorithmProvider(hAlgorithm: BCRYPT_ALG_HANDLE;
  dwFlags: ULONG): NTSTATUS; stdcall; external BCRYPT_DLL;
  
function BCryptGetProperty(hObject: THandle; pszProperty: PWideChar;
  pbOutput: PByte; cbOutput: ULONG; out pcbResult: ULONG;
  dwFlags: ULONG): NTSTATUS; stdcall; external BCRYPT_DLL;
  
function BCryptSetProperty(hObject: THandle; pszProperty: PWideChar;
  pbInput: PByte; cbInput: ULONG; dwFlags: ULONG): NTSTATUS; stdcall;
  external BCRYPT_DLL;
  
function BCryptGenerateSymmetricKey(hAlgorithm: BCRYPT_ALG_HANDLE;
  out phKey: BCRYPT_KEY_HANDLE; pbKeyObject: PByte; cbKeyObject: ULONG;
  pbSecret: PByte; cbSecret: ULONG; dwFlags: ULONG): NTSTATUS; stdcall;
  external BCRYPT_DLL;
  
function BCryptDestroyKey(hKey: BCRYPT_KEY_HANDLE): NTSTATUS; stdcall;
  external BCRYPT_DLL;
  
function BCryptEncrypt(hKey: BCRYPT_KEY_HANDLE; pbInput: PByte; cbInput: ULONG;
  pPaddingInfo: Pointer; pbIV: PByte; cbIV: ULONG; pbOutput: PByte;
  cbOutput: ULONG; out pcbResult: ULONG; dwFlags: ULONG): NTSTATUS; stdcall;
  external BCRYPT_DLL;
  
function BCryptDecrypt(hKey: BCRYPT_KEY_HANDLE; pbInput: PByte; cbInput: ULONG;
  pPaddingInfo: Pointer; pbIV: PByte; cbIV: ULONG; pbOutput: PByte;
  cbOutput: ULONG; out pcbResult: ULONG; dwFlags: ULONG): NTSTATUS; stdcall;
  external BCRYPT_DLL;
  
function BCryptGenRandom(hAlgorithm: BCRYPT_ALG_HANDLE; pbBuffer: PByte;
  cbBuffer: ULONG; dwFlags: ULONG): NTSTATUS; stdcall; external BCRYPT_DLL;

const
  BCRYPT_USE_SYSTEM_PREFERRED_RNG = $00000002;
  BCRYPT_BLOCK_PADDING = $00000001;
  STATUS_SUCCESS = 0;
  
  // RSA algorithm identifiers
  BCRYPT_RSA_ALGORITHM = 'RSA';
  BCRYPT_SHA256_ALGORITHM = 'SHA256';
  
  // Padding schemes
  BCRYPT_PAD_PKCS1 = $00000002;
  
  // Key blob types
  BCRYPT_RSAPUBLIC_BLOB = 'RSAPUBLICBLOB';
  
  // RSAPUBKEY structure magic
  BCRYPT_RSAPUBLIC_MAGIC = $31415352; // 'RSA1'

type
  // BCrypt RSA public key blob header
  BCRYPT_RSAKEY_BLOB = record
    Magic: ULONG;
    BitLength: ULONG;
    cbPublicExp: ULONG;
    cbModulus: ULONG;
    cbPrime1: ULONG;
    cbPrime2: ULONG;
  end;
  PBCRYPT_RSAKEY_BLOB = ^BCRYPT_RSAKEY_BLOB;
  
  // PKCS1 padding info
  BCRYPT_PKCS1_PADDING_INFO = record
    pszAlgId: PWideChar;
  end;
  PBCRYPT_PKCS1_PADDING_INFO = ^BCRYPT_PKCS1_PADDING_INFO;

function BCryptImportKeyPair(hAlgorithm: BCRYPT_ALG_HANDLE; hImportKey: BCRYPT_KEY_HANDLE;
  pszBlobType: PWideChar; out phKey: BCRYPT_KEY_HANDLE; pbInput: PByte; cbInput: ULONG;
  dwFlags: ULONG): NTSTATUS; stdcall; external BCRYPT_DLL;
  
function BCryptVerifySignature(hKey: BCRYPT_KEY_HANDLE; pPaddingInfo: Pointer;
  pbHash: PByte; cbHash: ULONG; pbSignature: PByte; cbSignature: ULONG;
  dwFlags: ULONG): NTSTATUS; stdcall; external BCRYPT_DLL;

function BCryptHash(hAlgorithm: BCRYPT_ALG_HANDLE; pbSecret: PByte; cbSecret: ULONG;
  pbInput: PByte; cbInput: ULONG; pbOutput: PByte; cbOutput: ULONG): NTSTATUS; stdcall;
  external BCRYPT_DLL;
{$ENDIF}

type
  ECryptoException = class(Exception);

  /// <summary>Hash algorithm type</summary>
  THashAlgorithm = (haMD5, haSHA1, haSHA256, haSHA384, haSHA512);

  /// <summary>Hash utilities</summary>
  THashUtils = class
  public
    /// <summary>Compute hash of bytes</summary>
    class function HashBytes(const AData: TBytes; AAlgorithm: THashAlgorithm = haSHA256): TBytes; static;
    
    /// <summary>Compute hash of string</summary>
    class function HashString(const AData: string; AAlgorithm: THashAlgorithm = haSHA256;
      AEncoding: TEncoding = nil): TBytes; static;
    
    /// <summary>Compute hash of stream</summary>
    class function HashStream(AStream: TStream; AAlgorithm: THashAlgorithm = haSHA256): TBytes; static;
    
    /// <summary>Compute hash of file</summary>
    class function HashFile(const AFileName: string; AAlgorithm: THashAlgorithm = haSHA256): TBytes; static;
    
    /// <summary>Get hash as hex string</summary>
    class function HashToHex(const AData: TBytes; AAlgorithm: THashAlgorithm = haSHA256): string; overload; static;
    class function HashToHex(const AData: string; AAlgorithm: THashAlgorithm = haSHA256): string; overload; static;
    
    /// <summary>MD5 shortcuts</summary>
    class function MD5(const AData: TBytes): TBytes; overload; static;
    class function MD5(const AData: string): string; overload; static;
    class function MD5File(const AFileName: string): string; static;
    
    /// <summary>SHA1 shortcuts</summary>
    class function SHA1(const AData: TBytes): TBytes; overload; static;
    class function SHA1(const AData: string): string; overload; static;
    class function SHA1File(const AFileName: string): string; static;
    
    /// <summary>SHA256 shortcuts</summary>
    class function SHA256(const AData: TBytes): TBytes; overload; static;
    class function SHA256(const AData: string): string; overload; static;
    class function SHA256File(const AFileName: string): string; static;
    
    /// <summary>SHA512 shortcuts</summary>
    class function SHA512(const AData: TBytes): TBytes; overload; static;
    class function SHA512(const AData: string): string; overload; static;
    class function SHA512File(const AFileName: string): string; static;
    
    /// <summary>HMAC</summary>
    class function HMAC(const AKey, AData: TBytes; AAlgorithm: THashAlgorithm = haSHA256): TBytes; overload; static;
    class function HMAC(const AKey, AData: string; AAlgorithm: THashAlgorithm = haSHA256): string; overload; static;
  end;

  /// <summary>Encoding utilities</summary>
  TEncodingUtils = class
  public
    /// <summary>Base64 encode</summary>
    class function Base64Encode(const AData: TBytes): string; overload; static;
    class function Base64Encode(const AData: string): string; overload; static;
    
    /// <summary>Base64 decode</summary>
    class function Base64Decode(const AData: string): TBytes; overload; static;
    class function Base64DecodeString(const AData: string): string; static;
    
    /// <summary>Base64 URL-safe encode (RFC 4648)</summary>
    class function Base64UrlEncode(const AData: TBytes): string; overload; static;
    class function Base64UrlEncode(const AData: string): string; overload; static;
    
    /// <summary>Base64 URL-safe decode</summary>
    class function Base64UrlDecode(const AData: string): TBytes; static;
    class function Base64UrlDecodeString(const AData: string): string; static;
    
    /// <summary>Hex encode</summary>
    class function HexEncode(const AData: TBytes): string; overload; static;
    class function HexEncode(const AData: string): string; overload; static;
    
    /// <summary>Hex decode</summary>
    class function HexDecode(const AData: string): TBytes; static;
    class function HexDecodeString(const AData: string): string; static;
    
    /// <summary>URL encode</summary>
    class function UrlEncode(const AData: string): string; static;
    
    /// <summary>URL decode</summary>
    class function UrlDecode(const AData: string): string; static;
    
    /// <summary>HTML encode</summary>
    class function HtmlEncode(const AData: string): string; static;
    
    /// <summary>HTML decode</summary>
    class function HtmlDecode(const AData: string): string; static;
  end;

  /// <summary>Random data generator</summary>
  TRandomGenerator = class
  public
    /// <summary>Generate random bytes</summary>
    class function RandomBytes(ALength: Integer): TBytes; static;
    
    /// <summary>Generate random string (alphanumeric)</summary>
    class function RandomString(ALength: Integer): string; static;
    
    /// <summary>Generate random hex string</summary>
    class function RandomHex(ALength: Integer): string; static;
    
    /// <summary>Generate random number in range</summary>
    class function RandomInt(AMin, AMax: Integer): Integer; static;
    
    /// <summary>Generate UUID/GUID</summary>
    class function NewGuid: string; static;
    class function NewGuidNoDashes: string; static;
    
    /// <summary>Generate secure token</summary>
    class function SecureToken(ALength: Integer = 32): string; static;
    
    /// <summary>Generate OTP (One-Time Password)</summary>
    class function GenerateOTP(ADigits: Integer = 6): string; static;
  end;

  /// <summary>Password hashing options</summary>
  TPasswordHashOptions = record
    Iterations: Integer;     // PBKDF2 iterations (default: 100000)
    SaltLength: Integer;     // Salt length in bytes (default: 16)
    HashLength: Integer;     // Hash output length in bytes (default: 32)
    Algorithm: THashAlgorithm; // Hash algorithm (default: haSHA256)
    
    class function Default: TPasswordHashOptions; static;
  end;

  /// <summary>Password hashing utilities</summary>
  TPasswordUtils = class
  public
    /// <summary>Hash password with PBKDF2</summary>
    class function HashPassword(const APassword: string;
      const AOptions: TPasswordHashOptions): string; overload; static;
    class function HashPassword(const APassword: string): string; overload; static;
    
    /// <summary>Verify password against hash</summary>
    class function VerifyPassword(const APassword, AHash: string): Boolean; static;
    
    /// <summary>Generate salt</summary>
    class function GenerateSalt(ALength: Integer = 16): TBytes; static;
    
    /// <summary>PBKDF2 key derivation</summary>
    class function PBKDF2(const APassword: string; const ASalt: TBytes;
      AIterations, AKeyLength: Integer; AAlgorithm: THashAlgorithm = haSHA256): TBytes; static;
    
    /// <summary>Check password strength</summary>
    class function CheckStrength(const APassword: string): Integer; static;
    
    /// <summary>Generate random password</summary>
    class function GeneratePassword(ALength: Integer = 16;
      AIncludeUppercase: Boolean = True;
      AIncludeLowercase: Boolean = True;
      AIncludeDigits: Boolean = True;
      AIncludeSpecial: Boolean = True): string; static;
  end;

  /// <summary>AES encryption mode</summary>
  TAESMode = (aesECB, aesCBC, aesCFB, aesOFB, aesCTR);

  /// <summary>AES key size</summary>
  TAESKeySize = (aes128, aes192, aes256);

  /// <summary>Simple AES encryption wrapper using Windows CryptoAPI</summary>
  TAESCrypto = class
  private
    FKey: TBytes;
    FIV: TBytes;
    FMode: TAESMode;
    FKeySize: TAESKeySize;
    
    function GetKeyLength: Integer;
    function GetBlockSize: Integer;
    function PadData(const AData: TBytes): TBytes;
    function UnpadData(const AData: TBytes): TBytes;
  public
    constructor Create(AKeySize: TAESKeySize = aes256; AMode: TAESMode = aesCBC);
    
    /// <summary>Set key from bytes</summary>
    procedure SetKey(const AKey: TBytes);
    
    /// <summary>Set key from password (using PBKDF2)</summary>
    procedure SetKeyFromPassword(const APassword: string; const ASalt: TBytes = nil);
    
    /// <summary>Set initialization vector</summary>
    procedure SetIV(const AIV: TBytes);
    
    /// <summary>Generate random key</summary>
    procedure GenerateKey;
    
    /// <summary>Generate random IV</summary>
    procedure GenerateIV;
    
    /// <summary>Encrypt bytes</summary>
    function Encrypt(const AData: TBytes): TBytes;
    
    /// <summary>Decrypt bytes</summary>
    function Decrypt(const AData: TBytes): TBytes;
    
    /// <summary>Encrypt string (returns Base64)</summary>
    function EncryptString(const AData: string): string;
    
    /// <summary>Decrypt string (from Base64)</summary>
    function DecryptString(const AData: string): string;
    
    /// <summary>Encrypt stream</summary>
    procedure EncryptStream(ASource, ADest: TStream);
    
    /// <summary>Decrypt stream</summary>
    procedure DecryptStream(ASource, ADest: TStream);
    
    /// <summary>Encrypt file</summary>
    procedure EncryptFile(const ASourceFile, ADestFile: string);
    
    /// <summary>Decrypt file</summary>
    procedure DecryptFile(const ASourceFile, ADestFile: string);
    
    property Key: TBytes read FKey;
    property IV: TBytes read FIV;
    property Mode: TAESMode read FMode write FMode;
    property KeySize: TAESKeySize read FKeySize write FKeySize;
  end;

  /// <summary>Simple encryption helper (password-based)</summary>
  TSimpleCrypto = class
  public
    /// <summary>Encrypt string with password</summary>
    class function Encrypt(const AData, APassword: string): string; static;
    
    /// <summary>Decrypt string with password</summary>
    class function Decrypt(const AData, APassword: string): string; static;
    
    /// <summary>Encrypt bytes with password</summary>
    class function EncryptBytes(const AData: TBytes; const APassword: string): TBytes; static;
    
    /// <summary>Decrypt bytes with password</summary>
    class function DecryptBytes(const AData: TBytes; const APassword: string): TBytes; static;
  end;

  /// <summary>CRC utilities</summary>
  TCRCUtils = class
  public
    /// <summary>CRC32 checksum</summary>
    class function CRC32(const AData: TBytes): Cardinal; overload; static;
    class function CRC32(const AData: string): Cardinal; overload; static;
    class function CRC32File(const AFileName: string): Cardinal; static;
    
    /// <summary>Adler32 checksum</summary>
    class function Adler32(const AData: TBytes): Cardinal; overload; static;
    class function Adler32(const AData: string): Cardinal; overload; static;
  end;

{$IFDEF MSWINDOWS}
  /// <summary>
  /// RSA signature verification using Windows CNG (BCrypt).
  /// Supports RSA-SHA256 with PKCS#1 v1.5 padding.
  /// </summary>
  TRSAVerifier = class
  private
    FPublicKey: TBytes;       // Raw public key blob for BCrypt
    FPublicKeyLoaded: Boolean;
    FLastError: string;
    
    function ParsePEMPublicKey(const APEM: string): TBytes;
    function ParseDERPublicKey(const ADER: TBytes): TBytes;
    function BuildBCryptKeyBlob(const AModulus, AExponent: TBytes): TBytes;
  public
    constructor Create;
    
    /// <summary>Load public key from PEM string</summary>
    function LoadPublicKeyPEM(const APEM: string): Boolean;
    
    /// <summary>Load public key from DER bytes</summary>
    function LoadPublicKeyDER(const ADER: TBytes): Boolean;
    
    /// <summary>Load public key from file (PEM or DER)</summary>
    function LoadPublicKeyFile(const AFileName: string): Boolean;
    
    /// <summary>Verify RSA-SHA256 signature</summary>
    function VerifySignature(const AData, ASignature: TBytes): Boolean; overload;
    
    /// <summary>Verify RSA-SHA256 signature (Base64 encoded signature)</summary>
    function VerifySignature(const AData: TBytes; const ASignatureBase64: string): Boolean; overload;
    
    /// <summary>Verify RSA-SHA256 signature (string data, Base64 signature)</summary>
    function VerifySignature(const AData, ASignatureBase64: string): Boolean; overload;
    
    property IsKeyLoaded: Boolean read FPublicKeyLoaded;
    property LastError: string read FLastError;
  end;
{$ENDIF}

  /// <summary>Static crypto helper</summary>
  TCrypto = class
  public
    // Hash shortcuts
    class function MD5(const AData: string): string; static;
    class function SHA1(const AData: string): string; static;
    class function SHA256(const AData: string): string; static;
    class function SHA512(const AData: string): string; static;
    
    // Encoding shortcuts
    class function Base64Encode(const AData: string): string; static;
    class function Base64Decode(const AData: string): string; static;
    class function HexEncode(const AData: string): string; static;
    class function HexDecode(const AData: string): string; static;
    
    // Password shortcuts
    class function HashPassword(const APassword: string): string; static;
    class function VerifyPassword(const APassword, AHash: string): Boolean; static;
    
    // Encryption shortcuts
    class function Encrypt(const AData, APassword: string): string; static;
    class function Decrypt(const AData, APassword: string): string; static;
    
    // Random shortcuts
    class function RandomString(ALength: Integer): string; static;
    class function RandomBytes(ALength: Integer): TBytes; static;
    class function NewGuid: string; static;
  end;

implementation

uses
  System.Math, System.RTLConsts;

{ THashUtils }

class function THashUtils.HashBytes(const AData: TBytes; AAlgorithm: THashAlgorithm): TBytes;
begin
  case AAlgorithm of
    haMD5:
      Result := THashMD5.GetHashBytes(AData);
    haSHA1:
      Result := THashSHA1.GetHashBytes(AData);
    haSHA256:
      Result := THashSHA2.GetHashBytes(AData, THashSHA2.TSHA2Version.SHA256);
    haSHA384:
      Result := THashSHA2.GetHashBytes(AData, THashSHA2.TSHA2Version.SHA384);
    haSHA512:
      Result := THashSHA2.GetHashBytes(AData, THashSHA2.TSHA2Version.SHA512);
  else
    Result := THashSHA2.GetHashBytes(AData, THashSHA2.TSHA2Version.SHA256);
  end;
end;

class function THashUtils.HashString(const AData: string; AAlgorithm: THashAlgorithm;
  AEncoding: TEncoding): TBytes;
begin
  if AEncoding = nil then
    AEncoding := TEncoding.UTF8;
  Result := HashBytes(AEncoding.GetBytes(AData), AAlgorithm);
end;

class function THashUtils.HashStream(AStream: TStream; AAlgorithm: THashAlgorithm): TBytes;
var
  LBytes: TBytes;
  LPos: Int64;
begin
  LPos := AStream.Position;
  try
    AStream.Position := 0;
    SetLength(LBytes, AStream.Size);
    if AStream.Size > 0 then
      AStream.ReadBuffer(LBytes[0], AStream.Size);
    Result := HashBytes(LBytes, AAlgorithm);
  finally
    AStream.Position := LPos;
  end;
end;

class function THashUtils.HashFile(const AFileName: string; AAlgorithm: THashAlgorithm): TBytes;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    Result := HashStream(LStream, AAlgorithm);
  finally
    LStream.Free;
  end;
end;

class function THashUtils.HashToHex(const AData: TBytes; AAlgorithm: THashAlgorithm): string;
var
  LHash: TBytes;
  I: Integer;
begin
  LHash := HashBytes(AData, AAlgorithm);
  Result := '';
  for I := 0 to High(LHash) do
    Result := Result + IntToHex(LHash[I], 2);
  Result := LowerCase(Result);
end;

class function THashUtils.HashToHex(const AData: string; AAlgorithm: THashAlgorithm): string;
begin
  Result := HashToHex(TEncoding.UTF8.GetBytes(AData), AAlgorithm);
end;

class function THashUtils.MD5(const AData: TBytes): TBytes;
begin
  Result := HashBytes(AData, haMD5);
end;

class function THashUtils.MD5(const AData: string): string;
begin
  Result := HashToHex(AData, haMD5);
end;

class function THashUtils.MD5File(const AFileName: string): string;
var
  LHash: TBytes;
  I: Integer;
begin
  LHash := HashFile(AFileName, haMD5);
  Result := '';
  for I := 0 to High(LHash) do
    Result := Result + IntToHex(LHash[I], 2);
  Result := LowerCase(Result);
end;

class function THashUtils.SHA1(const AData: TBytes): TBytes;
begin
  Result := HashBytes(AData, haSHA1);
end;

class function THashUtils.SHA1(const AData: string): string;
begin
  Result := HashToHex(AData, haSHA1);
end;

class function THashUtils.SHA1File(const AFileName: string): string;
var
  LHash: TBytes;
  I: Integer;
begin
  LHash := HashFile(AFileName, haSHA1);
  Result := '';
  for I := 0 to High(LHash) do
    Result := Result + IntToHex(LHash[I], 2);
  Result := LowerCase(Result);
end;

class function THashUtils.SHA256(const AData: TBytes): TBytes;
begin
  Result := HashBytes(AData, haSHA256);
end;

class function THashUtils.SHA256(const AData: string): string;
begin
  Result := HashToHex(AData, haSHA256);
end;

class function THashUtils.SHA256File(const AFileName: string): string;
var
  LHash: TBytes;
  I: Integer;
begin
  LHash := HashFile(AFileName, haSHA256);
  Result := '';
  for I := 0 to High(LHash) do
    Result := Result + IntToHex(LHash[I], 2);
  Result := LowerCase(Result);
end;

class function THashUtils.SHA512(const AData: TBytes): TBytes;
begin
  Result := HashBytes(AData, haSHA512);
end;

class function THashUtils.SHA512(const AData: string): string;
begin
  Result := HashToHex(AData, haSHA512);
end;

class function THashUtils.SHA512File(const AFileName: string): string;
var
  LHash: TBytes;
  I: Integer;
begin
  LHash := HashFile(AFileName, haSHA512);
  Result := '';
  for I := 0 to High(LHash) do
    Result := Result + IntToHex(LHash[I], 2);
  Result := LowerCase(Result);
end;

class function THashUtils.HMAC(const AKey, AData: TBytes; AAlgorithm: THashAlgorithm): TBytes;
var
  LBlockSize: Integer;
  LKeyBlock, LInnerPad, LOuterPad: TBytes;
  LInnerHash: TBytes;
  I: Integer;
begin
  // Block sizes for different algorithms
  case AAlgorithm of
    haMD5: LBlockSize := 64;
    haSHA1: LBlockSize := 64;
    haSHA256: LBlockSize := 64;
    haSHA384: LBlockSize := 128;
    haSHA512: LBlockSize := 128;
  else
    LBlockSize := 64;
  end;
  
  // Prepare key block
  if Length(AKey) > LBlockSize then
    LKeyBlock := HashBytes(AKey, AAlgorithm)
  else
    LKeyBlock := Copy(AKey);
    
  SetLength(LKeyBlock, LBlockSize);
  
  // Create inner and outer pads
  SetLength(LInnerPad, LBlockSize + Length(AData));
  SetLength(LOuterPad, LBlockSize);
  
  for I := 0 to LBlockSize - 1 do
  begin
    LInnerPad[I] := LKeyBlock[I] xor $36;
    LOuterPad[I] := LKeyBlock[I] xor $5C;
  end;
  
  // Copy data to inner pad
  if Length(AData) > 0 then
    Move(AData[0], LInnerPad[LBlockSize], Length(AData));
    
  // Inner hash
  LInnerHash := HashBytes(LInnerPad, AAlgorithm);
  
  // Outer hash
  SetLength(LOuterPad, LBlockSize + Length(LInnerHash));
  Move(LInnerHash[0], LOuterPad[LBlockSize], Length(LInnerHash));
  
  Result := HashBytes(LOuterPad, AAlgorithm);
end;

class function THashUtils.HMAC(const AKey, AData: string; AAlgorithm: THashAlgorithm): string;
var
  LHash: TBytes;
  I: Integer;
begin
  LHash := HMAC(TEncoding.UTF8.GetBytes(AKey), TEncoding.UTF8.GetBytes(AData), AAlgorithm);
  Result := '';
  for I := 0 to High(LHash) do
    Result := Result + IntToHex(LHash[I], 2);
  Result := LowerCase(Result);
end;

{ TEncodingUtils }

class function TEncodingUtils.Base64Encode(const AData: TBytes): string;
begin
  Result := TNetEncoding.Base64.EncodeBytesToString(AData);
end;

class function TEncodingUtils.Base64Encode(const AData: string): string;
begin
  Result := TNetEncoding.Base64.Encode(AData);
end;

class function TEncodingUtils.Base64Decode(const AData: string): TBytes;
begin
  Result := TNetEncoding.Base64.DecodeStringToBytes(AData);
end;

class function TEncodingUtils.Base64DecodeString(const AData: string): string;
begin
  Result := TNetEncoding.Base64.Decode(AData);
end;

class function TEncodingUtils.Base64UrlEncode(const AData: TBytes): string;
begin
  Result := TNetEncoding.Base64.EncodeBytesToString(AData);
  // Convert to URL-safe base64
  Result := Result.Replace('+', '-').Replace('/', '_').TrimRight(['=']);
end;

class function TEncodingUtils.Base64UrlEncode(const AData: string): string;
begin
  Result := Base64UrlEncode(TEncoding.UTF8.GetBytes(AData));
end;

class function TEncodingUtils.Base64UrlDecode(const AData: string): TBytes;
var
  LData: string;
  LPadding: Integer;
begin
  // Convert from URL-safe base64
  LData := AData.Replace('-', '+').Replace('_', '/');
  
  // Add padding
  LPadding := (4 - Length(LData) mod 4) mod 4;
  LData := LData + StringOfChar('=', LPadding);
  
  Result := TNetEncoding.Base64.DecodeStringToBytes(LData);
end;

class function TEncodingUtils.Base64UrlDecodeString(const AData: string): string;
begin
  Result := TEncoding.UTF8.GetString(Base64UrlDecode(AData));
end;

class function TEncodingUtils.HexEncode(const AData: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AData) do
    Result := Result + IntToHex(AData[I], 2);
  Result := LowerCase(Result);
end;

class function TEncodingUtils.HexEncode(const AData: string): string;
begin
  Result := HexEncode(TEncoding.UTF8.GetBytes(AData));
end;

class function TEncodingUtils.HexDecode(const AData: string): TBytes;
var
  I: Integer;
  LClean: string;
begin
  LClean := AData.Replace(' ', '').Replace('-', '');
  if Length(LClean) mod 2 <> 0 then
    raise ECryptoException.Create('Invalid hex string length');
    
  SetLength(Result, Length(LClean) div 2);
  for I := 0 to High(Result) do
    Result[I] := StrToInt('$' + Copy(LClean, I * 2 + 1, 2));
end;

class function TEncodingUtils.HexDecodeString(const AData: string): string;
begin
  Result := TEncoding.UTF8.GetString(HexDecode(AData));
end;

class function TEncodingUtils.UrlEncode(const AData: string): string;
begin
  Result := TNetEncoding.URL.Encode(AData);
end;

class function TEncodingUtils.UrlDecode(const AData: string): string;
begin
  Result := TNetEncoding.URL.Decode(AData);
end;

class function TEncodingUtils.HtmlEncode(const AData: string): string;
begin
  Result := TNetEncoding.HTML.Encode(AData);
end;

class function TEncodingUtils.HtmlDecode(const AData: string): string;
begin
  Result := TNetEncoding.HTML.Decode(AData);
end;

{ TRandomGenerator }

class function TRandomGenerator.RandomBytes(ALength: Integer): TBytes;
{$IFDEF MSWINDOWS}
var
  LStatus: NTSTATUS;
{$ELSE}
var
  I: Integer;
{$ENDIF}
begin
  SetLength(Result, ALength);
  if ALength = 0 then
    Exit;
    
  {$IFDEF MSWINDOWS}
  // Use cryptographically secure random number generator
  LStatus := BCryptGenRandom(0, @Result[0], ALength, BCRYPT_USE_SYSTEM_PREFERRED_RNG);
  if LStatus <> STATUS_SUCCESS then
    raise ECryptoException.CreateFmt('BCryptGenRandom failed with status: %d', [LStatus]);
  {$ELSE}
  // Fallback for non-Windows platforms (NOT cryptographically secure)
  // Consider using /dev/urandom on Linux/macOS
  for I := 0 to ALength - 1 do
    Result[I] := Random(256);
  {$ENDIF}
end;

class function TRandomGenerator.RandomString(ALength: Integer): string;
const
  Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
var
  I: Integer;
begin
  SetLength(Result, ALength);
  for I := 1 to ALength do
    Result[I] := Chars[Random(Length(Chars)) + 1];
end;

class function TRandomGenerator.RandomHex(ALength: Integer): string;
const
  HexChars = '0123456789abcdef';
var
  I: Integer;
begin
  SetLength(Result, ALength);
  for I := 1 to ALength do
    Result[I] := HexChars[Random(16) + 1];
end;

class function TRandomGenerator.RandomInt(AMin, AMax: Integer): Integer;
begin
  Result := AMin + Random(AMax - AMin + 1);
end;

class function TRandomGenerator.NewGuid: string;
var
  LGuid: TGUID;
begin
  CreateGUID(LGuid);
  Result := GUIDToString(LGuid);
end;

class function TRandomGenerator.NewGuidNoDashes: string;
var
  LGuid: TGUID;
begin
  CreateGUID(LGuid);
  Result := GUIDToString(LGuid).Replace('{', '').Replace('}', '').Replace('-', '');
end;

class function TRandomGenerator.SecureToken(ALength: Integer): string;
begin
  Result := TEncodingUtils.Base64UrlEncode(RandomBytes(ALength));
end;

class function TRandomGenerator.GenerateOTP(ADigits: Integer): string;
var
  I: Integer;
begin
  SetLength(Result, ADigits);
  for I := 1 to ADigits do
    Result[I] := Chr(Ord('0') + Random(10));
end;

{ TPasswordHashOptions }

class function TPasswordHashOptions.Default: TPasswordHashOptions;
begin
  Result.Iterations := 100000;
  Result.SaltLength := 16;
  Result.HashLength := 32;
  Result.Algorithm := haSHA256;
end;

{ TPasswordUtils }

class function TPasswordUtils.HashPassword(const APassword: string;
  const AOptions: TPasswordHashOptions): string;
var
  LSalt, LHash: TBytes;
  LSaltB64, LHashB64: string;
begin
  LSalt := GenerateSalt(AOptions.SaltLength);
  LHash := PBKDF2(APassword, LSalt, AOptions.Iterations, AOptions.HashLength, AOptions.Algorithm);
  
  LSaltB64 := TEncodingUtils.Base64Encode(LSalt);
  LHashB64 := TEncodingUtils.Base64Encode(LHash);
  
  // Format: $pbkdf2$iterations$algorithm$salt$hash
  Result := Format('$pbkdf2$%d$%d$%s$%s', [AOptions.Iterations, Ord(AOptions.Algorithm), LSaltB64, LHashB64]);
end;

class function TPasswordUtils.HashPassword(const APassword: string): string;
begin
  Result := HashPassword(APassword, TPasswordHashOptions.Default);
end;

class function TPasswordUtils.VerifyPassword(const APassword, AHash: string): Boolean;
var
  LParts: TArray<string>;
  LIterations: Integer;
  LAlgorithm: THashAlgorithm;
  LSalt, LStoredHash, LComputedHash: TBytes;
begin
  Result := False;
  
  if not AHash.StartsWith('$pbkdf2$') then
    Exit;
    
  LParts := AHash.Split(['$']);
  if Length(LParts) < 6 then
    Exit;
    
  try
    LIterations := StrToInt(LParts[2]);
    LAlgorithm := THashAlgorithm(StrToInt(LParts[3]));
    LSalt := TEncodingUtils.Base64Decode(LParts[4]);
    LStoredHash := TEncodingUtils.Base64Decode(LParts[5]);
    
    LComputedHash := PBKDF2(APassword, LSalt, LIterations, Length(LStoredHash), LAlgorithm);
    
    // Constant-time comparison
    if Length(LComputedHash) <> Length(LStoredHash) then
      Exit;
      
    var LDiff: Integer := 0;
    for var I := 0 to High(LComputedHash) do
      LDiff := LDiff or (LComputedHash[I] xor LStoredHash[I]);
      
    Result := LDiff = 0;
  except
    Result := False;
  end;
end;

class function TPasswordUtils.GenerateSalt(ALength: Integer): TBytes;
begin
  Result := TRandomGenerator.RandomBytes(ALength);
end;

class function TPasswordUtils.PBKDF2(const APassword: string; const ASalt: TBytes;
  AIterations, AKeyLength: Integer; AAlgorithm: THashAlgorithm): TBytes;
var
  LHashLen, LBlocks, I, J, K: Integer;
  LPasswordBytes, LBlock, LPrev, LTemp: TBytes;
  LCounter: array[0..3] of Byte;
begin
  LPasswordBytes := TEncoding.UTF8.GetBytes(APassword);
  
  // Determine hash length
  case AAlgorithm of
    haMD5: LHashLen := 16;
    haSHA1: LHashLen := 20;
    haSHA256: LHashLen := 32;
    haSHA384: LHashLen := 48;
    haSHA512: LHashLen := 64;
  else
    LHashLen := 32;
  end;
  
  LBlocks := (AKeyLength + LHashLen - 1) div LHashLen;
  SetLength(Result, AKeyLength);
  
  for I := 1 to LBlocks do
  begin
    // Counter in big-endian
    LCounter[0] := Byte(I shr 24);
    LCounter[1] := Byte(I shr 16);
    LCounter[2] := Byte(I shr 8);
    LCounter[3] := Byte(I);
    
    // U1 = HMAC(password, salt || counter)
    SetLength(LTemp, Length(ASalt) + 4);
    if Length(ASalt) > 0 then
      Move(ASalt[0], LTemp[0], Length(ASalt));
    Move(LCounter[0], LTemp[Length(ASalt)], 4);
    
    LPrev := THashUtils.HMAC(LPasswordBytes, LTemp, AAlgorithm);
    LBlock := Copy(LPrev);
    
    // U2..Uc
    for J := 2 to AIterations do
    begin
      LPrev := THashUtils.HMAC(LPasswordBytes, LPrev, AAlgorithm);
      for K := 0 to High(LBlock) do
        LBlock[K] := LBlock[K] xor LPrev[K];
    end;
    
    // Copy to result
    for J := 0 to Min(LHashLen, AKeyLength - (I - 1) * LHashLen) - 1 do
      Result[(I - 1) * LHashLen + J] := LBlock[J];
  end;
end;

class function TPasswordUtils.CheckStrength(const APassword: string): Integer;
var
  LHasLower, LHasUpper, LHasDigit, LHasSpecial: Boolean;
  I: Integer;
  C: Char;
begin
  Result := 0;
  if Length(APassword) < 8 then
    Exit(1);
    
  LHasLower := False;
  LHasUpper := False;
  LHasDigit := False;
  LHasSpecial := False;
  
  for I := 1 to Length(APassword) do
  begin
    C := APassword[I];
    if CharInSet(C, ['a'..'z']) then LHasLower := True
    else if CharInSet(C, ['A'..'Z']) then LHasUpper := True
    else if CharInSet(C, ['0'..'9']) then LHasDigit := True
    else LHasSpecial := True;
  end;
  
  // Score based on length
  if Length(APassword) >= 16 then Result := 2
  else if Length(APassword) >= 12 then Result := 1
  else Result := 0;
  
  // Score based on character types
  if LHasLower then Inc(Result);
  if LHasUpper then Inc(Result);
  if LHasDigit then Inc(Result);
  if LHasSpecial then Inc(Result);
  
  // Cap at 5 (very strong)
  if Result > 5 then Result := 5;
end;

class function TPasswordUtils.GeneratePassword(ALength: Integer;
  AIncludeUppercase, AIncludeLowercase, AIncludeDigits, AIncludeSpecial: Boolean): string;
var
  LCharset: string;
  I: Integer;
begin
  LCharset := '';
  if AIncludeUppercase then LCharset := LCharset + 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  if AIncludeLowercase then LCharset := LCharset + 'abcdefghijklmnopqrstuvwxyz';
  if AIncludeDigits then LCharset := LCharset + '0123456789';
  if AIncludeSpecial then LCharset := LCharset + '!@#$%^&*()_+-=[]{}|;:,.<>?';
  
  if LCharset = '' then
    LCharset := 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    
  SetLength(Result, ALength);
  for I := 1 to ALength do
    Result[I] := LCharset[Random(Length(LCharset)) + 1];
end;

{ TAESCrypto }

constructor TAESCrypto.Create(AKeySize: TAESKeySize; AMode: TAESMode);
begin
  inherited Create;
  FKeySize := AKeySize;
  FMode := AMode;
  GenerateKey;
  GenerateIV;
end;

function TAESCrypto.GetKeyLength: Integer;
begin
  case FKeySize of
    aes128: Result := 16;
    aes192: Result := 24;
    aes256: Result := 32;
  else
    Result := 32;
  end;
end;

function TAESCrypto.GetBlockSize: Integer;
begin
  Result := 16; // AES block size is always 16 bytes
end;

procedure TAESCrypto.SetKey(const AKey: TBytes);
begin
  if Length(AKey) <> GetKeyLength then
    raise ECryptoException.CreateFmt('Invalid key length. Expected %d bytes', [GetKeyLength]);
  FKey := Copy(AKey);
end;

procedure TAESCrypto.SetKeyFromPassword(const APassword: string; const ASalt: TBytes);
var
  LSalt: TBytes;
begin
  if Length(ASalt) > 0 then
    LSalt := ASalt
  else
    LSalt := TEncoding.UTF8.GetBytes('UniBaseAES256DefaultSalt');
    
  FKey := TPasswordUtils.PBKDF2(APassword, LSalt, 10000, GetKeyLength, haSHA256);
end;

procedure TAESCrypto.SetIV(const AIV: TBytes);
begin
  if Length(AIV) <> GetBlockSize then
    raise ECryptoException.CreateFmt('Invalid IV length. Expected %d bytes', [GetBlockSize]);
  FIV := Copy(AIV);
end;

procedure TAESCrypto.GenerateKey;
begin
  FKey := TRandomGenerator.RandomBytes(GetKeyLength);
end;

procedure TAESCrypto.GenerateIV;
begin
  FIV := TRandomGenerator.RandomBytes(GetBlockSize);
end;

function TAESCrypto.PadData(const AData: TBytes): TBytes;
var
  LPadLen: Integer;
begin
  // PKCS7 padding
  LPadLen := GetBlockSize - (Length(AData) mod GetBlockSize);
  SetLength(Result, Length(AData) + LPadLen);
  if Length(AData) > 0 then
    Move(AData[0], Result[0], Length(AData));
  FillChar(Result[Length(AData)], LPadLen, LPadLen);
end;

function TAESCrypto.UnpadData(const AData: TBytes): TBytes;
var
  LPadLen: Integer;
begin
  if Length(AData) = 0 then
    Exit(nil);
    
  LPadLen := AData[High(AData)];
  if (LPadLen < 1) or (LPadLen > GetBlockSize) then
    raise ECryptoException.Create('Invalid padding');
    
  SetLength(Result, Length(AData) - LPadLen);
  if Length(Result) > 0 then
    Move(AData[0], Result[0], Length(Result));
end;

function TAESCrypto.Encrypt(const AData: TBytes): TBytes;
{$IFDEF MSWINDOWS}
var
  LAlgHandle: BCRYPT_ALG_HANDLE;
  LKeyHandle: BCRYPT_KEY_HANDLE;
  LKeyObjectSize, LBlockLen, LResultSize: ULONG;
  LKeyObject: TBytes;
  LIVCopy: TBytes;
  LPadded: TBytes;
  LStatus: NTSTATUS;
  LChainMode: WideString;
begin
  LAlgHandle := 0;
  LKeyHandle := 0;
  
  try
    // Open AES algorithm provider
    LStatus := BCryptOpenAlgorithmProvider(LAlgHandle, BCRYPT_AES_ALGORITHM, nil, 0);
    if LStatus <> STATUS_SUCCESS then
      raise ECryptoException.CreateFmt('BCryptOpenAlgorithmProvider failed: %d', [LStatus]);
      
    // Set CBC chaining mode
    LChainMode := BCRYPT_CHAIN_MODE_CBC;
    LStatus := BCryptSetProperty(LAlgHandle, BCRYPT_CHAINING_MODE,
      PByte(PWideChar(LChainMode)), (Length(LChainMode) + 1) * SizeOf(WideChar), 0);
    if LStatus <> STATUS_SUCCESS then
      raise ECryptoException.CreateFmt('BCryptSetProperty (ChainMode) failed: %d', [LStatus]);
      
    // Get key object size
    LStatus := BCryptGetProperty(LAlgHandle, BCRYPT_OBJECT_LENGTH,
      @LKeyObjectSize, SizeOf(LKeyObjectSize), LBlockLen, 0);
    if LStatus <> STATUS_SUCCESS then
      raise ECryptoException.CreateFmt('BCryptGetProperty failed: %d', [LStatus]);
      
    // Allocate key object
    SetLength(LKeyObject, LKeyObjectSize);
    
    // Generate symmetric key
    LStatus := BCryptGenerateSymmetricKey(LAlgHandle, LKeyHandle,
      @LKeyObject[0], LKeyObjectSize, @FKey[0], Length(FKey), 0);
    if LStatus <> STATUS_SUCCESS then
      raise ECryptoException.CreateFmt('BCryptGenerateSymmetricKey failed: %d', [LStatus]);
      
    // Pad data manually (PKCS7)
    LPadded := PadData(AData);
    
    // Copy IV (BCrypt modifies it)
    LIVCopy := Copy(FIV);
    
    // Get output size
    LStatus := BCryptEncrypt(LKeyHandle, @LPadded[0], Length(LPadded),
      nil, @LIVCopy[0], Length(LIVCopy), nil, 0, LResultSize, 0);
    if LStatus <> STATUS_SUCCESS then
      raise ECryptoException.CreateFmt('BCryptEncrypt (size query) failed: %d', [LStatus]);
      
    // Allocate output buffer
    SetLength(Result, LResultSize);
    
    // Reset IV copy
    LIVCopy := Copy(FIV);
    
    // Perform encryption
    LStatus := BCryptEncrypt(LKeyHandle, @LPadded[0], Length(LPadded),
      nil, @LIVCopy[0], Length(LIVCopy), @Result[0], LResultSize, LResultSize, 0);
    if LStatus <> STATUS_SUCCESS then
      raise ECryptoException.CreateFmt('BCryptEncrypt failed: %d', [LStatus]);
      
    SetLength(Result, LResultSize);
  finally
    if LKeyHandle <> 0 then
      BCryptDestroyKey(LKeyHandle);
    if LAlgHandle <> 0 then
      BCryptCloseAlgorithmProvider(LAlgHandle, 0);
  end;
end;
{$ELSE}
var
  LPadded: TBytes;
  I, J: Integer;
  LBlock, LPrevBlock: array[0..15] of Byte;
begin
  // Fallback XOR-based encryption for non-Windows platforms
  // WARNING: This is NOT secure - for demonstration only
  LPadded := PadData(AData);
  SetLength(Result, Length(LPadded));
  Move(FIV[0], LPrevBlock[0], 16);
  I := 0;
  while I < Length(LPadded) do
  begin
    for J := 0 to 15 do
      LBlock[J] := LPadded[I + J] xor LPrevBlock[J] xor FKey[J mod Length(FKey)];
    Move(LBlock[0], Result[I], 16);
    Move(LBlock[0], LPrevBlock[0], 16);
    Inc(I, 16);
  end;
end;
{$ENDIF}

function TAESCrypto.Decrypt(const AData: TBytes): TBytes;
{$IFDEF MSWINDOWS}
var
  LAlgHandle: BCRYPT_ALG_HANDLE;
  LKeyHandle: BCRYPT_KEY_HANDLE;
  LKeyObjectSize, LBlockLen, LResultSize: ULONG;
  LKeyObject: TBytes;
  LIVCopy: TBytes;
  LStatus: NTSTATUS;
  LChainMode: WideString;
  LDecrypted: TBytes;
begin
  if Length(AData) mod 16 <> 0 then
    raise ECryptoException.Create('Invalid ciphertext length');
    
  LAlgHandle := 0;
  LKeyHandle := 0;
  
  try
    // Open AES algorithm provider
    LStatus := BCryptOpenAlgorithmProvider(LAlgHandle, BCRYPT_AES_ALGORITHM, nil, 0);
    if LStatus <> STATUS_SUCCESS then
      raise ECryptoException.CreateFmt('BCryptOpenAlgorithmProvider failed: %d', [LStatus]);
      
    // Set CBC chaining mode
    LChainMode := BCRYPT_CHAIN_MODE_CBC;
    LStatus := BCryptSetProperty(LAlgHandle, BCRYPT_CHAINING_MODE,
      PByte(PWideChar(LChainMode)), (Length(LChainMode) + 1) * SizeOf(WideChar), 0);
    if LStatus <> STATUS_SUCCESS then
      raise ECryptoException.CreateFmt('BCryptSetProperty (ChainMode) failed: %d', [LStatus]);
      
    // Get key object size
    LStatus := BCryptGetProperty(LAlgHandle, BCRYPT_OBJECT_LENGTH,
      @LKeyObjectSize, SizeOf(LKeyObjectSize), LBlockLen, 0);
    if LStatus <> STATUS_SUCCESS then
      raise ECryptoException.CreateFmt('BCryptGetProperty failed: %d', [LStatus]);
      
    // Allocate key object
    SetLength(LKeyObject, LKeyObjectSize);
    
    // Generate symmetric key
    LStatus := BCryptGenerateSymmetricKey(LAlgHandle, LKeyHandle,
      @LKeyObject[0], LKeyObjectSize, @FKey[0], Length(FKey), 0);
    if LStatus <> STATUS_SUCCESS then
      raise ECryptoException.CreateFmt('BCryptGenerateSymmetricKey failed: %d', [LStatus]);
      
    // Copy IV (BCrypt modifies it)
    LIVCopy := Copy(FIV);
    
    // Get output size
    LStatus := BCryptDecrypt(LKeyHandle, @AData[0], Length(AData),
      nil, @LIVCopy[0], Length(LIVCopy), nil, 0, LResultSize, 0);
    if LStatus <> STATUS_SUCCESS then
      raise ECryptoException.CreateFmt('BCryptDecrypt (size query) failed: %d', [LStatus]);
      
    // Allocate output buffer
    SetLength(LDecrypted, LResultSize);
    
    // Reset IV copy
    LIVCopy := Copy(FIV);
    
    // Perform decryption
    LStatus := BCryptDecrypt(LKeyHandle, @AData[0], Length(AData),
      nil, @LIVCopy[0], Length(LIVCopy), @LDecrypted[0], LResultSize, LResultSize, 0);
    if LStatus <> STATUS_SUCCESS then
      raise ECryptoException.CreateFmt('BCryptDecrypt failed: %d', [LStatus]);
      
    SetLength(LDecrypted, LResultSize);
    Result := UnpadData(LDecrypted);
  finally
    if LKeyHandle <> 0 then
      BCryptDestroyKey(LKeyHandle);
    if LAlgHandle <> 0 then
      BCryptCloseAlgorithmProvider(LAlgHandle, 0);
  end;
end;
{$ELSE}
var
  I, J: Integer;
  LBlock, LPrevBlock, LCipherBlock: array[0..15] of Byte;
  LDecrypted: TBytes;
begin
  if Length(AData) mod 16 <> 0 then
    raise ECryptoException.Create('Invalid ciphertext length');
  // Fallback XOR-based decryption for non-Windows platforms  
  // WARNING: This is NOT secure - for demonstration only
  SetLength(LDecrypted, Length(AData));
  Move(FIV[0], LPrevBlock[0], 16);
  I := 0;
  while I < Length(AData) do
  begin
    Move(AData[I], LCipherBlock[0], 16);
    for J := 0 to 15 do
      LBlock[J] := LCipherBlock[J] xor LPrevBlock[J] xor FKey[J mod Length(FKey)];
    Move(LBlock[0], LDecrypted[I], 16);
    Move(LCipherBlock[0], LPrevBlock[0], 16);
    Inc(I, 16);
  end;
  Result := UnpadData(LDecrypted);
end;
{$ENDIF}

function TAESCrypto.EncryptString(const AData: string): string;
var
  LEncrypted: TBytes;
begin
  LEncrypted := Encrypt(TEncoding.UTF8.GetBytes(AData));
  Result := TEncodingUtils.Base64Encode(LEncrypted);
end;

function TAESCrypto.DecryptString(const AData: string): string;
var
  LDecrypted: TBytes;
begin
  LDecrypted := Decrypt(TEncodingUtils.Base64Decode(AData));
  Result := TEncoding.UTF8.GetString(LDecrypted);
end;

procedure TAESCrypto.EncryptStream(ASource, ADest: TStream);
var
  LData, LEncrypted: TBytes;
begin
  SetLength(LData, ASource.Size);
  ASource.Position := 0;
  if ASource.Size > 0 then
    ASource.ReadBuffer(LData[0], ASource.Size);
    
  LEncrypted := Encrypt(LData);
  if Length(LEncrypted) > 0 then
    ADest.WriteBuffer(LEncrypted[0], Length(LEncrypted));
end;

procedure TAESCrypto.DecryptStream(ASource, ADest: TStream);
var
  LData, LDecrypted: TBytes;
begin
  SetLength(LData, ASource.Size);
  ASource.Position := 0;
  if ASource.Size > 0 then
    ASource.ReadBuffer(LData[0], ASource.Size);
    
  LDecrypted := Decrypt(LData);
  if Length(LDecrypted) > 0 then
    ADest.WriteBuffer(LDecrypted[0], Length(LDecrypted));
end;

procedure TAESCrypto.EncryptFile(const ASourceFile, ADestFile: string);
var
  LSource, LDest: TFileStream;
begin
  LSource := TFileStream.Create(ASourceFile, fmOpenRead or fmShareDenyWrite);
  try
    LDest := TFileStream.Create(ADestFile, fmCreate);
    try
      EncryptStream(LSource, LDest);
    finally
      LDest.Free;
    end;
  finally
    LSource.Free;
  end;
end;

procedure TAESCrypto.DecryptFile(const ASourceFile, ADestFile: string);
var
  LSource, LDest: TFileStream;
begin
  LSource := TFileStream.Create(ASourceFile, fmOpenRead or fmShareDenyWrite);
  try
    LDest := TFileStream.Create(ADestFile, fmCreate);
    try
      DecryptStream(LSource, LDest);
    finally
      LDest.Free;
    end;
  finally
    LSource.Free;
  end;
end;

{ TSimpleCrypto }

class function TSimpleCrypto.Encrypt(const AData, APassword: string): string;
var
  LAES: TAESCrypto;
begin
  LAES := TAESCrypto.Create(aes256, aesCBC);
  try
    LAES.SetKeyFromPassword(APassword);
    Result := LAES.EncryptString(AData);
  finally
    LAES.Free;
  end;
end;

class function TSimpleCrypto.Decrypt(const AData, APassword: string): string;
var
  LAES: TAESCrypto;
begin
  LAES := TAESCrypto.Create(aes256, aesCBC);
  try
    LAES.SetKeyFromPassword(APassword);
    Result := LAES.DecryptString(AData);
  finally
    LAES.Free;
  end;
end;

class function TSimpleCrypto.EncryptBytes(const AData: TBytes; const APassword: string): TBytes;
var
  LAES: TAESCrypto;
begin
  LAES := TAESCrypto.Create(aes256, aesCBC);
  try
    LAES.SetKeyFromPassword(APassword);
    Result := LAES.Encrypt(AData);
  finally
    LAES.Free;
  end;
end;

class function TSimpleCrypto.DecryptBytes(const AData: TBytes; const APassword: string): TBytes;
var
  LAES: TAESCrypto;
begin
  LAES := TAESCrypto.Create(aes256, aesCBC);
  try
    LAES.SetKeyFromPassword(APassword);
    Result := LAES.Decrypt(AData);
  finally
    LAES.Free;
  end;
end;

{ TCRCUtils }

class function TCRCUtils.CRC32(const AData: TBytes): Cardinal;
const
  CRCTable: array[0..255] of Cardinal = (
    $00000000, $77073096, $EE0E612C, $990951BA, $076DC419, $706AF48F, $E963A535, $9E6495A3,
    $0EDB8832, $79DCB8A4, $E0D5E91E, $97D2D988, $09B64C2B, $7EB17CBD, $E7B82D07, $90BF1D91,
    $1DB71064, $6AB020F2, $F3B97148, $84BE41DE, $1ADAD47D, $6DDDE4EB, $F4D4B551, $83D385C7,
    $136C9856, $646BA8C0, $FD62F97A, $8A65C9EC, $14015C4F, $63066CD9, $FA0F3D63, $8D080DF5,
    $3B6E20C8, $4C69105E, $D56041E4, $A2677172, $3C03E4D1, $4B04D447, $D20D85FD, $A50AB56B,
    $35B5A8FA, $42B2986C, $DBBBC9D6, $ACBCF940, $32D86CE3, $45DF5C75, $DCD60DCF, $ABD13D59,
    $26D930AC, $51DE003A, $C8D75180, $BFD06116, $21B4F4B5, $56B3C423, $CFBA9599, $B8BDA50F,
    $2802B89E, $5F058808, $C60CD9B2, $B10BE924, $2F6F7C87, $58684C11, $C1611DAB, $B6662D3D,
    $76DC4190, $01DB7106, $98D220BC, $EFD5102A, $71B18589, $06B6B51F, $9FBFE4A5, $E8B8D433,
    $7807C9A2, $0F00F934, $9609A88E, $E10E9818, $7F6A0DBB, $086D3D2D, $91646C97, $E6635C01,
    $6B6B51F4, $1C6C6162, $856530D8, $F262004E, $6C0695ED, $1B01A57B, $8208F4C1, $F50FC457,
    $65B0D9C6, $12B7E950, $8BBEB8EA, $FCB9887C, $62DD1DDF, $15DA2D49, $8CD37CF3, $FBD44C65,
    $4DB26158, $3AB551CE, $A3BC0074, $D4BB30E2, $4ADFA541, $3DD895D7, $A4D1C46D, $D3D6F4FB,
    $4369E96A, $346ED9FC, $AD678846, $DA60B8D0, $44042D73, $33031DE5, $AA0A4C5F, $DD0D7CC9,
    $5005713C, $270241AA, $BE0B1010, $C90C2086, $5768B525, $206F85B3, $B966D409, $CE61E49F,
    $5EDEF90E, $29D9C998, $B0D09822, $C7D7A8B4, $59B33D17, $2EB40D81, $B7BD5C3B, $C0BA6CAD,
    $EDB88320, $9ABFB3B6, $03B6E20C, $74B1D29A, $EAD54739, $9DD277AF, $04DB2615, $73DC1683,
    $E3630B12, $94643B84, $0D6D6A3E, $7A6A5AA8, $E40ECF0B, $9309FF9D, $0A00AE27, $7D079EB1,
    $F00F9344, $8708A3D2, $1E01F268, $6906C2FE, $F762575D, $806567CB, $196C3671, $6E6B06E7,
    $FED41B76, $89D32BE0, $10DA7A5A, $67DD4ACC, $F9B9DF6F, $8EBEEFF9, $17B7BE43, $60B08ED5,
    $D6D6A3E8, $A1D1937E, $38D8C2C4, $4FDFF252, $D1BB67F1, $A6BC5767, $3FB506DD, $48B2364B,
    $D80D2BDA, $AF0A1B4C, $36034AF6, $41047A60, $DF60EFC3, $A867DF55, $316E8EEF, $4669BE79,
    $CB61B38C, $BC66831A, $256FD2A0, $5268E236, $CC0C7795, $BB0B4703, $220216B9, $5505262F,
    $C5BA3BBE, $B2BD0B28, $2BB45A92, $5CB36A04, $C2D7FFA7, $B5D0CF31, $2CD99E8B, $5BDEAE1D,
    $9B64C2B0, $EC63F226, $756AA39C, $026D930A, $9C0906A9, $EB0E363F, $72076785, $05005713,
    $95BF4A82, $E2B87A14, $7BB12BAE, $0CB61B38, $92D28E9B, $E5D5BE0D, $7CDCEFB7, $0BDBDF21,
    $86D3D2D4, $F1D4E242, $68DDB3F8, $1FDA836E, $81BE16CD, $F6B9265B, $6FB077E1, $18B74777,
    $88085AE6, $FF0F6A70, $66063BCA, $11010B5C, $8F659EFF, $F862AE69, $616BFFD3, $166CCF45,
    $A00AE278, $D70DD2EE, $4E048354, $3903B3C2, $A7672661, $D06016F7, $4969474D, $3E6E77DB,
    $AED16A4A, $D9D65ADC, $40DF0B66, $37D83BF0, $A9BCAE53, $DEBB9EC5, $47B2CF7F, $30B5FFE9,
    $BDBDF21C, $CABAC28A, $53B39330, $24B4A3A6, $BAD03605, $CDD706B3, $54DE5729, $23D967BF,
    $B3667A2E, $C4614AB8, $5D681B02, $2A6F2B94, $B40BBE37, $C30C8EA1, $5A05DF1B, $2D02EF8D
  );
var
  I: Integer;
begin
  Result := $FFFFFFFF;
  for I := 0 to High(AData) do
    Result := CRCTable[(Result xor AData[I]) and $FF] xor (Result shr 8);
  Result := Result xor $FFFFFFFF;
end;

class function TCRCUtils.CRC32(const AData: string): Cardinal;
begin
  Result := CRC32(TEncoding.UTF8.GetBytes(AData));
end;

class function TCRCUtils.CRC32File(const AFileName: string): Cardinal;
var
  LStream: TFileStream;
  LData: TBytes;
begin
  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(LData, LStream.Size);
    if LStream.Size > 0 then
      LStream.ReadBuffer(LData[0], LStream.Size);
    Result := CRC32(LData);
  finally
    LStream.Free;
  end;
end;

class function TCRCUtils.Adler32(const AData: TBytes): Cardinal;
var
  A, B: Cardinal;
  I: Integer;
begin
  A := 1;
  B := 0;
  for I := 0 to High(AData) do
  begin
    A := (A + AData[I]) mod 65521;
    B := (B + A) mod 65521;
  end;
  Result := (B shl 16) or A;
end;

class function TCRCUtils.Adler32(const AData: string): Cardinal;
begin
  Result := Adler32(TEncoding.UTF8.GetBytes(AData));
end;

{$IFDEF MSWINDOWS}
{ TRSAVerifier }

constructor TRSAVerifier.Create;
begin
  inherited Create;
  FPublicKeyLoaded := False;
  FLastError := '';
end;

function TRSAVerifier.ParsePEMPublicKey(const APEM: string): TBytes;
var
  LLines: TArray<string>;
  LBase64: string;
  LLine: string;
  LInKey: Boolean;
begin
  Result := nil;
  LBase64 := '';
  LInKey := False;
  
  LLines := APEM.Split([#10, #13], TStringSplitOptions.ExcludeEmpty);
  for LLine in LLines do
  begin
    if LLine.Contains('-----BEGIN') and LLine.Contains('PUBLIC KEY') then
    begin
      LInKey := True;
      Continue;
    end;
    if LLine.Contains('-----END') and LLine.Contains('PUBLIC KEY') then
      Break;
    if LInKey then
      LBase64 := LBase64 + LLine.Trim;
  end;
  
  if LBase64 = '' then
  begin
    FLastError := 'Invalid PEM format: no public key found';
    Exit;
  end;
  
  try
    Result := TEncodingUtils.Base64Decode(LBase64);
  except
    on E: Exception do
    begin
      FLastError := 'Base64 decode failed: ' + E.Message;
      Result := nil;
    end;
  end;
end;

function TRSAVerifier.ParseDERPublicKey(const ADER: TBytes): TBytes;
var
  LPos: Integer;
  LLen, LModulusLen, LExponentLen: Integer;
  LModulus, LExponent: TBytes;
  
  function ReadLength(var APos: Integer): Integer;
  var
    LFirst: Byte;
    LNumBytes, I: Integer;
  begin
    if APos >= Length(ADER) then
      raise ECryptoException.Create('Invalid DER: unexpected end');
    LFirst := ADER[APos];
    Inc(APos);
    if LFirst < $80 then
      Result := LFirst
    else
    begin
      LNumBytes := LFirst and $7F;
      Result := 0;
      for I := 1 to LNumBytes do
      begin
        if APos >= Length(ADER) then
          raise ECryptoException.Create('Invalid DER: unexpected end in length');
        Result := (Result shl 8) or ADER[APos];
        Inc(APos);
      end;
    end;
  end;
  
  procedure SkipTag(AExpectedTag: Byte; var APos: Integer);
  begin
    if APos >= Length(ADER) then
      raise ECryptoException.Create('Invalid DER: unexpected end before tag');
    if ADER[APos] <> AExpectedTag then
      raise ECryptoException.CreateFmt('Invalid DER: expected tag $%x, got $%x', [AExpectedTag, ADER[APos]]);
    Inc(APos);
  end;
  
begin
  Result := nil;
  if Length(ADER) < 20 then
  begin
    FLastError := 'DER data too short';
    Exit;
  end;
  
  try
    LPos := 0;
    
    // SubjectPublicKeyInfo ::= SEQUENCE
    SkipTag($30, LPos); // SEQUENCE
    LLen := ReadLength(LPos);
    
    // algorithm AlgorithmIdentifier ::= SEQUENCE
    SkipTag($30, LPos); // SEQUENCE
    LLen := ReadLength(LPos);
    LPos := LPos + LLen; // Skip algorithm identifier
    
    // subjectPublicKey BIT STRING
    SkipTag($03, LPos); // BIT STRING
    LLen := ReadLength(LPos);
    if LPos >= Length(ADER) then
      raise ECryptoException.Create('Invalid DER: no bit string content');
    Inc(LPos); // Skip unused bits byte (should be 0)
    
    // The BIT STRING contains RSAPublicKey ::= SEQUENCE
    SkipTag($30, LPos); // SEQUENCE
    LLen := ReadLength(LPos);
    
    // modulus INTEGER
    SkipTag($02, LPos); // INTEGER
    LModulusLen := ReadLength(LPos);
    // Skip leading zero if present (sign byte)
    if (LModulusLen > 0) and (ADER[LPos] = 0) then
    begin
      Inc(LPos);
      Dec(LModulusLen);
    end;
    SetLength(LModulus, LModulusLen);
    if LModulusLen > 0 then
      Move(ADER[LPos], LModulus[0], LModulusLen);
    Inc(LPos, LModulusLen);
    
    // publicExponent INTEGER
    SkipTag($02, LPos); // INTEGER
    LExponentLen := ReadLength(LPos);
    // Skip leading zero if present
    if (LExponentLen > 0) and (ADER[LPos] = 0) then
    begin
      Inc(LPos);
      Dec(LExponentLen);
    end;
    SetLength(LExponent, LExponentLen);
    if LExponentLen > 0 then
      Move(ADER[LPos], LExponent[0], LExponentLen);
    
    // Build BCrypt key blob
    Result := BuildBCryptKeyBlob(LModulus, LExponent);
  except
    on E: Exception do
    begin
      FLastError := 'DER parse error: ' + E.Message;
      Result := nil;
    end;
  end;
end;

function TRSAVerifier.BuildBCryptKeyBlob(const AModulus, AExponent: TBytes): TBytes;
var
  LHeader: BCRYPT_RSAKEY_BLOB;
  LBlobSize: Integer;
  LPos: Integer;
begin
  // Build BCRYPT_RSAPUBLIC_BLOB format:
  // BCRYPT_RSAKEY_BLOB header + PublicExponent + Modulus
  
  LHeader.Magic := BCRYPT_RSAPUBLIC_MAGIC;
  LHeader.BitLength := Length(AModulus) * 8;
  LHeader.cbPublicExp := Length(AExponent);
  LHeader.cbModulus := Length(AModulus);
  LHeader.cbPrime1 := 0;
  LHeader.cbPrime2 := 0;
  
  LBlobSize := SizeOf(BCRYPT_RSAKEY_BLOB) + Length(AExponent) + Length(AModulus);
  SetLength(Result, LBlobSize);
  
  LPos := 0;
  Move(LHeader, Result[LPos], SizeOf(BCRYPT_RSAKEY_BLOB));
  Inc(LPos, SizeOf(BCRYPT_RSAKEY_BLOB));
  
  // Exponent
  if Length(AExponent) > 0 then
    Move(AExponent[0], Result[LPos], Length(AExponent));
  Inc(LPos, Length(AExponent));
  
  // Modulus  
  if Length(AModulus) > 0 then
    Move(AModulus[0], Result[LPos], Length(AModulus));
end;

function TRSAVerifier.LoadPublicKeyPEM(const APEM: string): Boolean;
var
  LDER: TBytes;
begin
  FLastError := '';
  FPublicKeyLoaded := False;
  
  LDER := ParsePEMPublicKey(APEM);
  if LDER = nil then
    Exit(False);
    
  FPublicKey := ParseDERPublicKey(LDER);
  FPublicKeyLoaded := FPublicKey <> nil;
  Result := FPublicKeyLoaded;
end;

function TRSAVerifier.LoadPublicKeyDER(const ADER: TBytes): Boolean;
begin
  FLastError := '';
  FPublicKeyLoaded := False;
  
  FPublicKey := ParseDERPublicKey(ADER);
  FPublicKeyLoaded := FPublicKey <> nil;
  Result := FPublicKeyLoaded;
end;

function TRSAVerifier.LoadPublicKeyFile(const AFileName: string): Boolean;
var
  LStream: TFileStream;
  LBytes: TBytes;
  LPEM: string;
begin
  FLastError := '';
  FPublicKeyLoaded := False;
  
  if not FileExists(AFileName) then
  begin
    FLastError := 'File not found: ' + AFileName;
    Exit(False);
  end;
  
  try
    LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
    try
      SetLength(LBytes, LStream.Size);
      if LStream.Size > 0 then
        LStream.ReadBuffer(LBytes[0], LStream.Size);
    finally
      LStream.Free;
    end;
    
    // Try to detect format - PEM starts with '-----'
    if (Length(LBytes) > 5) and (LBytes[0] = Ord('-')) then
    begin
      LPEM := TEncoding.UTF8.GetString(LBytes);
      Result := LoadPublicKeyPEM(LPEM);
    end
    else
      Result := LoadPublicKeyDER(LBytes);
  except
    on E: Exception do
    begin
      FLastError := 'Failed to read file: ' + E.Message;
      Result := False;
    end;
  end;
end;

function TRSAVerifier.VerifySignature(const AData, ASignature: TBytes): Boolean;
var
  LAlgHandle: BCRYPT_ALG_HANDLE;
  LKeyHandle: BCRYPT_KEY_HANDLE;
  LHashAlgHandle: BCRYPT_ALG_HANDLE;
  LHash: TBytes;
  LPaddingInfo: BCRYPT_PKCS1_PADDING_INFO;
  LStatus: NTSTATUS;
  LAlgId: WideString;
begin
  Result := False;
  FLastError := '';
  
  if not FPublicKeyLoaded then
  begin
    FLastError := 'Public key not loaded';
    Exit;
  end;
  
  if Length(ASignature) = 0 then
  begin
    FLastError := 'Empty signature';
    Exit;
  end;
  
  LAlgHandle := 0;
  LKeyHandle := 0;
  LHashAlgHandle := 0;
  
  try
    // Open RSA algorithm provider
    LStatus := BCryptOpenAlgorithmProvider(LAlgHandle, BCRYPT_RSA_ALGORITHM, nil, 0);
    if LStatus <> STATUS_SUCCESS then
    begin
      FLastError := Format('BCryptOpenAlgorithmProvider (RSA) failed: $%x', [LStatus]);
      Exit;
    end;
    
    // Import the public key
    LStatus := BCryptImportKeyPair(LAlgHandle, 0, BCRYPT_RSAPUBLIC_BLOB, LKeyHandle,
      @FPublicKey[0], Length(FPublicKey), 0);
    if LStatus <> STATUS_SUCCESS then
    begin
      FLastError := Format('BCryptImportKeyPair failed: $%x', [LStatus]);
      Exit;
    end;
    
    // Hash the data with SHA256
    LStatus := BCryptOpenAlgorithmProvider(LHashAlgHandle, BCRYPT_SHA256_ALGORITHM, nil, 0);
    if LStatus <> STATUS_SUCCESS then
    begin
      FLastError := Format('BCryptOpenAlgorithmProvider (SHA256) failed: $%x', [LStatus]);
      Exit;
    end;
    
    SetLength(LHash, 32); // SHA256 = 32 bytes
    if Length(AData) > 0 then
      LStatus := BCryptHash(LHashAlgHandle, nil, 0, @AData[0], Length(AData), @LHash[0], 32)
    else
      LStatus := BCryptHash(LHashAlgHandle, nil, 0, nil, 0, @LHash[0], 32);
      
    if LStatus <> STATUS_SUCCESS then
    begin
      FLastError := Format('BCryptHash failed: $%x', [LStatus]);
      Exit;
    end;
    
    // Setup padding info for PKCS#1 v1.5
    LAlgId := BCRYPT_SHA256_ALGORITHM;
    LPaddingInfo.pszAlgId := PWideChar(LAlgId);
    
    // Verify signature
    LStatus := BCryptVerifySignature(LKeyHandle, @LPaddingInfo,
      @LHash[0], Length(LHash), @ASignature[0], Length(ASignature), BCRYPT_PAD_PKCS1);
      
    Result := (LStatus = STATUS_SUCCESS);
    if not Result then
      FLastError := Format('Signature verification failed: $%x', [LStatus]);
  finally
    if LHashAlgHandle <> 0 then
      BCryptCloseAlgorithmProvider(LHashAlgHandle, 0);
    if LKeyHandle <> 0 then
      BCryptDestroyKey(LKeyHandle);
    if LAlgHandle <> 0 then
      BCryptCloseAlgorithmProvider(LAlgHandle, 0);
  end;
end;

function TRSAVerifier.VerifySignature(const AData: TBytes; const ASignatureBase64: string): Boolean;
var
  LSignature: TBytes;
begin
  try
    LSignature := TEncodingUtils.Base64Decode(ASignatureBase64);
    Result := VerifySignature(AData, LSignature);
  except
    on E: Exception do
    begin
      FLastError := 'Invalid Base64 signature: ' + E.Message;
      Result := False;
    end;
  end;
end;

function TRSAVerifier.VerifySignature(const AData, ASignatureBase64: string): Boolean;
begin
  Result := VerifySignature(TEncoding.UTF8.GetBytes(AData), ASignatureBase64);
end;
{$ENDIF}

{ TCrypto }

class function TCrypto.MD5(const AData: string): string;
begin
  Result := THashUtils.MD5(AData);
end;

class function TCrypto.SHA1(const AData: string): string;
begin
  Result := THashUtils.SHA1(AData);
end;

class function TCrypto.SHA256(const AData: string): string;
begin
  Result := THashUtils.SHA256(AData);
end;

class function TCrypto.SHA512(const AData: string): string;
begin
  Result := THashUtils.SHA512(AData);
end;

class function TCrypto.Base64Encode(const AData: string): string;
begin
  Result := TEncodingUtils.Base64Encode(AData);
end;

class function TCrypto.Base64Decode(const AData: string): string;
begin
  Result := TEncodingUtils.Base64DecodeString(AData);
end;

class function TCrypto.HexEncode(const AData: string): string;
begin
  Result := TEncodingUtils.HexEncode(AData);
end;

class function TCrypto.HexDecode(const AData: string): string;
begin
  Result := TEncodingUtils.HexDecodeString(AData);
end;

class function TCrypto.HashPassword(const APassword: string): string;
begin
  Result := TPasswordUtils.HashPassword(APassword);
end;

class function TCrypto.VerifyPassword(const APassword, AHash: string): Boolean;
begin
  Result := TPasswordUtils.VerifyPassword(APassword, AHash);
end;

class function TCrypto.Encrypt(const AData, APassword: string): string;
begin
  Result := TSimpleCrypto.Encrypt(AData, APassword);
end;

class function TCrypto.Decrypt(const AData, APassword: string): string;
begin
  Result := TSimpleCrypto.Decrypt(AData, APassword);
end;

class function TCrypto.RandomString(ALength: Integer): string;
begin
  Result := TRandomGenerator.RandomString(ALength);
end;

class function TCrypto.RandomBytes(ALength: Integer): TBytes;
begin
  Result := TRandomGenerator.RandomBytes(ALength);
end;

class function TCrypto.NewGuid: string;
begin
  Result := TRandomGenerator.NewGuid;
end;

initialization
  Randomize;

end.
