{ ============================================================================
  DeepBase.Services.Crypto - Cryptographic Service Implementations

  Version: 1.0
  Description: Implements IHashService, IEncodingService, IPasswordService,
               IRandomService, ICryptoService, ICRCService interfaces.
               These implementations wrap the existing static methods from
               DeepBase.Crypto module.

  Note: This module provides dependency-injectable wrappers around existing
        crypto functionality. The underlying implementations remain unchanged.
  ============================================================================ }

unit DeepBase.Services.Crypto;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Hash,
  System.NetEncoding,
  DeepBase.Services.Interfaces,
  DeepBase.Crypto;

type
  // ============================================================================
  // Hash Service Implementation
  // ============================================================================

  /// <summary>
  /// Implementation of IHashService using DeepBase.Crypto
  /// </summary>
  THashServiceImpl = class(TInterfacedObject, IHashService)
  public
    // IHashService
    function HashBytes(const Data: TBytes; Algorithm: THashAlgorithm): TBytes;
    function HashString(const Data: string; Algorithm: THashAlgorithm): TBytes;
    function HashStream(Stream: TStream; Algorithm: THashAlgorithm): TBytes;
    function HashFile(const FileName: string; Algorithm: THashAlgorithm): TBytes;
    function HashToHex(const Hash: TBytes): string;

    function MD5(const Data: string): string; overload;
    function MD5(const Data: TBytes): string; overload;
    function MD5File(const FileName: string): string;

    function SHA1(const Data: string): string; overload;
    function SHA1(const Data: TBytes): string; overload;

    function SHA256(const Data: string): string; overload;
    function SHA256(const Data: TBytes): string; overload;
    function SHA256File(const FileName: string): string;

    function SHA512(const Data: string): string; overload;
    function SHA512(const Data: TBytes): string; overload;

    function HMAC(const Data, Key: TBytes; Algorithm: THashAlgorithm): TBytes; overload;
    function HMAC(const Data, Key: string; Algorithm: THashAlgorithm): string; overload;
  end;

  // ============================================================================
  // Encoding Service Implementation
  // ============================================================================

  /// <summary>
  /// Implementation of IEncodingService using DeepBase.Crypto
  /// </summary>
  TEncodingServiceImpl = class(TInterfacedObject, IEncodingService)
  public
    // IEncodingService
    function Base64Encode(const Data: TBytes): string; overload;
    function Base64Encode(const Data: string): string; overload;
    function Base64Decode(const Data: string): TBytes; overload;
    function Base64DecodeString(const Data: string): string;

    function Base64UrlEncode(const Data: TBytes): string; overload;
    function Base64UrlEncode(const Data: string): string; overload;
    function Base64UrlDecode(const Data: string): TBytes;
    function Base64UrlDecodeString(const Data: string): string;

    function HexEncode(const Data: TBytes): string; overload;
    function HexEncode(const Data: string): string; overload;
    function HexDecode(const Data: string): TBytes;
    function HexDecodeString(const Data: string): string;

    function UrlEncode(const Data: string): string;
    function UrlDecode(const Data: string): string;

    function HtmlEncode(const Data: string): string;
    function HtmlDecode(const Data: string): string;
  end;

  // ============================================================================
  // Password Service Implementation
  // ============================================================================

  /// <summary>
  /// Implementation of IPasswordService using DeepBase.Crypto
  /// </summary>
  TPasswordServiceImpl = class(TInterfacedObject, IPasswordService)
  public
    // IPasswordService
    function HashPassword(const Password: string): string; overload;
    function HashPassword(const Password, Salt: string): string; overload;
    function VerifyPassword(const Password, Hash: string): Boolean;
    function GenerateSalt(Length: Integer = 16): string;
    function PBKDF2(const Password, Salt: string; Iterations, KeyLength: Integer): TBytes;
    function CheckStrength(const Password: string): TPasswordStrength;
    function GeneratePassword(Length: Integer = 16; IncludeSpecial: Boolean = True): string;
  end;

  // ============================================================================
  // Random Service Implementation
  // ============================================================================

  /// <summary>
  /// Implementation of IRandomService using DeepBase.Crypto
  /// </summary>
  TRandomServiceImpl = class(TInterfacedObject, IRandomService)
  public
    // IRandomService
    function RandomBytes(Length: Integer): TBytes;
    function RandomString(Length: Integer): string;
    function RandomHex(Length: Integer): string;
    function RandomInt(Min, Max: Integer): Integer;
    function NewGuid: string;
    function NewGuidNoDashes: string;
    function SecureToken(Length: Integer = 32): string;
    function GenerateOTP(Digits: Integer = 6): string;
  end;

  // ============================================================================
  // Crypto Service Implementation
  // ============================================================================

  /// <summary>
  /// Implementation of ICryptoService using DeepBase.Crypto
  /// </summary>
  TCryptoServiceImpl = class(TInterfacedObject, ICryptoService)
  public
    // ICryptoService
    function Encrypt(const Data, Key: string): string;
    function Decrypt(const Data, Key: string): string;
    function EncryptBytes(const Data: TBytes; const Key: string): TBytes;
    function DecryptBytes(const Data: TBytes; const Key: string): TBytes;
    function EncryptWithIV(const Data: TBytes; const Key, IV: TBytes): TBytes;
    function DecryptWithIV(const Data: TBytes; const Key, IV: TBytes): TBytes;
  end;

  // ============================================================================
  // CRC Service Implementation
  // ============================================================================

  /// <summary>
  /// Implementation of ICRCService using DeepBase.Crypto
  /// </summary>
  TCRCServiceImpl = class(TInterfacedObject, ICRCService)
  public
    // ICRCService
    function CRC32(const Data: TBytes): Cardinal; overload;
    function CRC32(const Data: string): Cardinal; overload;
    function CRC32File(const FileName: string): Cardinal;
    function Adler32(const Data: TBytes): Cardinal; overload;
    function Adler32(const Data: string): Cardinal; overload;
  end;

implementation

uses
  System.TypInfo;

function NormalizeAes256Key(const AKey: TBytes): TBytes;
begin
  if Length(AKey) = 0 then
    raise ECryptoException.Create('Encryption key cannot be empty');

  if Length(AKey) = 32 then
    Exit(Copy(AKey));

  Result := THashUtils.HashBytes(AKey, haSHA256);
end;

procedure ValidateAesCbcIV(const AIV: TBytes);
begin
  if Length(AIV) <> 16 then
    raise ECryptoException.CreateFmt('Invalid IV length. Expected %d bytes', [16]);
end;

// ============================================================================
// THashServiceImpl
// ============================================================================

function THashServiceImpl.HashBytes(const Data: TBytes; Algorithm: THashAlgorithm): TBytes;
begin
  case Algorithm of
    haMD5:    Result := THashUtils.HashBytes(Data, haMD5);
    haSHA1:   Result := THashUtils.HashBytes(Data, haSHA1);
    haSHA256: Result := THashUtils.HashBytes(Data, haSHA256);
    haSHA384: Result := THashUtils.HashBytes(Data, haSHA384);
    haSHA512: Result := THashUtils.HashBytes(Data, haSHA512);
  else
    Result := THashUtils.HashBytes(Data, haSHA256);
  end;
end;

function THashServiceImpl.HashString(const Data: string; Algorithm: THashAlgorithm): TBytes;
begin
  case Algorithm of
    haMD5:    Result := THashUtils.HashString(Data, haMD5);
    haSHA1:   Result := THashUtils.HashString(Data, haSHA1);
    haSHA256: Result := THashUtils.HashString(Data, haSHA256);
    haSHA384: Result := THashUtils.HashString(Data, haSHA384);
    haSHA512: Result := THashUtils.HashString(Data, haSHA512);
  else
    Result := THashUtils.HashString(Data, haSHA256);
  end;
end;

function THashServiceImpl.HashStream(Stream: TStream; Algorithm: THashAlgorithm): TBytes;
begin
  case Algorithm of
    haMD5:    Result := THashUtils.HashStream(Stream, haMD5);
    haSHA1:   Result := THashUtils.HashStream(Stream, haSHA1);
    haSHA256: Result := THashUtils.HashStream(Stream, haSHA256);
    haSHA384: Result := THashUtils.HashStream(Stream, haSHA384);
    haSHA512: Result := THashUtils.HashStream(Stream, haSHA512);
  else
    Result := THashUtils.HashStream(Stream, haSHA256);
  end;
end;

function THashServiceImpl.HashFile(const FileName: string; Algorithm: THashAlgorithm): TBytes;
begin
  case Algorithm of
    haMD5:    Result := THashUtils.HashFile(FileName, haMD5);
    haSHA1:   Result := THashUtils.HashFile(FileName, haSHA1);
    haSHA256: Result := THashUtils.HashFile(FileName, haSHA256);
    haSHA384: Result := THashUtils.HashFile(FileName, haSHA384);
    haSHA512: Result := THashUtils.HashFile(FileName, haSHA512);
  else
    Result := THashUtils.HashFile(FileName, haSHA256);
  end;
end;

function THashServiceImpl.HashToHex(const Hash: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(Hash) do
    Result := Result + IntToHex(Hash[I], 2);
  Result := LowerCase(Result);
end;

function THashServiceImpl.MD5(const Data: string): string;
begin
  Result := THashUtils.MD5(Data);
end;

function THashServiceImpl.MD5(const Data: TBytes): string;
begin
  Result := HashToHex(THashUtils.MD5(Data));
end;

function THashServiceImpl.MD5File(const FileName: string): string;
begin
  Result := THashUtils.MD5File(FileName);
end;

function THashServiceImpl.SHA1(const Data: string): string;
begin
  Result := THashUtils.SHA1(Data);
end;

function THashServiceImpl.SHA1(const Data: TBytes): string;
begin
  Result := HashToHex(THashUtils.SHA1(Data));
end;

function THashServiceImpl.SHA256(const Data: string): string;
begin
  Result := THashUtils.SHA256(Data);
end;

function THashServiceImpl.SHA256(const Data: TBytes): string;
begin
  Result := HashToHex(THashUtils.SHA256(Data));
end;

function THashServiceImpl.SHA256File(const FileName: string): string;
begin
  Result := THashUtils.SHA256File(FileName);
end;

function THashServiceImpl.SHA512(const Data: string): string;
begin
  Result := THashUtils.SHA512(Data);
end;

function THashServiceImpl.SHA512(const Data: TBytes): string;
begin
  Result := HashToHex(THashUtils.SHA512(Data));
end;

function THashServiceImpl.HMAC(const Data, Key: TBytes; Algorithm: THashAlgorithm): TBytes;
begin
  case Algorithm of
    haMD5:    Result := THashUtils.HMAC(Key, Data, haMD5);
    haSHA1:   Result := THashUtils.HMAC(Key, Data, haSHA1);
    haSHA256: Result := THashUtils.HMAC(Key, Data, haSHA256);
    haSHA384: Result := THashUtils.HMAC(Key, Data, haSHA384);
    haSHA512: Result := THashUtils.HMAC(Key, Data, haSHA512);
  else
    Result := THashUtils.HMAC(Key, Data, haSHA256);
  end;
end;

function THashServiceImpl.HMAC(const Data, Key: string; Algorithm: THashAlgorithm): string;
begin
  Result := HashToHex(HMAC(TEncoding.UTF8.GetBytes(Data), TEncoding.UTF8.GetBytes(Key), Algorithm));
end;

// ============================================================================
// TEncodingServiceImpl
// ============================================================================

function TEncodingServiceImpl.Base64Encode(const Data: TBytes): string;
begin
  Result := TEncodingUtils.Base64Encode(Data);
end;

function TEncodingServiceImpl.Base64Encode(const Data: string): string;
begin
  Result := TEncodingUtils.Base64Encode(Data);
end;

function TEncodingServiceImpl.Base64Decode(const Data: string): TBytes;
begin
  Result := TEncodingUtils.Base64Decode(Data);
end;

function TEncodingServiceImpl.Base64DecodeString(const Data: string): string;
begin
  Result := TEncodingUtils.Base64DecodeString(Data);
end;

function TEncodingServiceImpl.Base64UrlEncode(const Data: TBytes): string;
begin
  Result := TEncodingUtils.Base64UrlEncode(Data);
end;

function TEncodingServiceImpl.Base64UrlEncode(const Data: string): string;
begin
  Result := TEncodingUtils.Base64UrlEncode(Data);
end;

function TEncodingServiceImpl.Base64UrlDecode(const Data: string): TBytes;
begin
  Result := TEncodingUtils.Base64UrlDecode(Data);
end;

function TEncodingServiceImpl.Base64UrlDecodeString(const Data: string): string;
begin
  Result := TEncodingUtils.Base64UrlDecodeString(Data);
end;

function TEncodingServiceImpl.HexEncode(const Data: TBytes): string;
begin
  Result := TEncodingUtils.HexEncode(Data);
end;

function TEncodingServiceImpl.HexEncode(const Data: string): string;
begin
  Result := TEncodingUtils.HexEncode(Data);
end;

function TEncodingServiceImpl.HexDecode(const Data: string): TBytes;
begin
  Result := TEncodingUtils.HexDecode(Data);
end;

function TEncodingServiceImpl.HexDecodeString(const Data: string): string;
begin
  Result := TEncodingUtils.HexDecodeString(Data);
end;

function TEncodingServiceImpl.UrlEncode(const Data: string): string;
begin
  Result := TEncodingUtils.UrlEncode(Data);
end;

function TEncodingServiceImpl.UrlDecode(const Data: string): string;
begin
  Result := TEncodingUtils.UrlDecode(Data);
end;

function TEncodingServiceImpl.HtmlEncode(const Data: string): string;
begin
  Result := TEncodingUtils.HtmlEncode(Data);
end;

function TEncodingServiceImpl.HtmlDecode(const Data: string): string;
begin
  Result := TEncodingUtils.HtmlDecode(Data);
end;

// ============================================================================
// TPasswordServiceImpl
// ============================================================================

function TPasswordServiceImpl.HashPassword(const Password: string): string;
begin
  Result := TPasswordUtils.HashPassword(Password);
end;

function TPasswordServiceImpl.HashPassword(const Password, Salt: string): string;
begin
  Result := TEncodingUtils.Base64Encode(
    TPasswordUtils.PBKDF2(Password, TEncoding.UTF8.GetBytes(Salt), 100000,
      32, haSHA256));
end;

function TPasswordServiceImpl.VerifyPassword(const Password, Hash: string): Boolean;
begin
  Result := TPasswordUtils.VerifyPassword(Password, Hash);
end;

function TPasswordServiceImpl.GenerateSalt(Length: Integer): string;
begin
  Result := TEncodingUtils.Base64Encode(TPasswordUtils.GenerateSalt(Length));
end;

function TPasswordServiceImpl.PBKDF2(const Password, Salt: string;
  Iterations, KeyLength: Integer): TBytes;
begin
  Result := TPasswordUtils.PBKDF2(Password, TEncoding.UTF8.GetBytes(Salt),
    Iterations, KeyLength, haSHA256);
end;

function TPasswordServiceImpl.CheckStrength(const Password: string): TPasswordStrength;
var
  Score: Integer;
begin
  Score := TPasswordUtils.CheckStrength(Password);
  if Score < 20 then
    Result := psVeryWeak
  else if Score < 40 then
    Result := psWeak
  else if Score < 60 then
    Result := psFair
  else if Score < 80 then
    Result := psStrong
  else
    Result := psVeryStrong;
end;

function TPasswordServiceImpl.GeneratePassword(Length: Integer;
  IncludeSpecial: Boolean): string;
begin
  Result := TPasswordUtils.GeneratePassword(Length, True, True, True,
    IncludeSpecial);
end;

// ============================================================================
// TRandomServiceImpl
// ============================================================================

function TRandomServiceImpl.RandomBytes(Length: Integer): TBytes;
begin
  Result := TRandomGenerator.RandomBytes(Length);
end;

function TRandomServiceImpl.RandomString(Length: Integer): string;
begin
  Result := TRandomGenerator.RandomString(Length);
end;

function TRandomServiceImpl.RandomHex(Length: Integer): string;
begin
  Result := TRandomGenerator.RandomHex(Length);
end;

function TRandomServiceImpl.RandomInt(Min, Max: Integer): Integer;
begin
  Result := TRandomGenerator.RandomInt(Min, Max);
end;

function TRandomServiceImpl.NewGuid: string;
begin
  Result := TRandomGenerator.NewGuid;
end;

function TRandomServiceImpl.NewGuidNoDashes: string;
begin
  Result := TRandomGenerator.NewGuidNoDashes;
end;

function TRandomServiceImpl.SecureToken(Length: Integer): string;
begin
  Result := TRandomGenerator.SecureToken(Length);
end;

function TRandomServiceImpl.GenerateOTP(Digits: Integer): string;
begin
  Result := TRandomGenerator.GenerateOTP(Digits);
end;

// ============================================================================
// TCryptoServiceImpl
// ============================================================================

function TCryptoServiceImpl.Encrypt(const Data, Key: string): string;
begin
  Result := TSimpleCrypto.Encrypt(Data, Key);
end;

function TCryptoServiceImpl.Decrypt(const Data, Key: string): string;
begin
  Result := TSimpleCrypto.Decrypt(Data, Key);
end;

function TCryptoServiceImpl.EncryptBytes(const Data: TBytes; const Key: string): TBytes;
begin
  Result := TSimpleCrypto.EncryptBytes(Data, Key);
end;

function TCryptoServiceImpl.DecryptBytes(const Data: TBytes; const Key: string): TBytes;
begin
  Result := TSimpleCrypto.DecryptBytes(Data, Key);
end;

function TCryptoServiceImpl.EncryptWithIV(const Data: TBytes; const Key, IV: TBytes): TBytes;
var
  AES: TAESCrypto;
  EffectiveKey: TBytes;
begin
  ValidateAesCbcIV(IV);
  EffectiveKey := NormalizeAes256Key(Key);

  AES := TAESCrypto.Create(aes256, aesCBC);
  try
    AES.SetKey(EffectiveKey);
    AES.SetIV(IV);
    Result := AES.Encrypt(Data);
  finally
    AES.Free;
  end;
end;

function TCryptoServiceImpl.DecryptWithIV(const Data: TBytes; const Key, IV: TBytes): TBytes;
var
  AES: TAESCrypto;
  EffectiveKey: TBytes;
begin
  ValidateAesCbcIV(IV);
  EffectiveKey := NormalizeAes256Key(Key);

  AES := TAESCrypto.Create(aes256, aesCBC);
  try
    AES.SetKey(EffectiveKey);
    AES.SetIV(IV);
    Result := AES.Decrypt(Data);
  finally
    AES.Free;
  end;
end;

// ============================================================================
// TCRCServiceImpl
// ============================================================================

function TCRCServiceImpl.CRC32(const Data: TBytes): Cardinal;
begin
  Result := TCRCUtils.CRC32(Data);
end;

function TCRCServiceImpl.CRC32(const Data: string): Cardinal;
begin
  Result := TCRCUtils.CRC32(Data);
end;

function TCRCServiceImpl.CRC32File(const FileName: string): Cardinal;
begin
  Result := TCRCUtils.CRC32File(FileName);
end;

function TCRCServiceImpl.Adler32(const Data: TBytes): Cardinal;
begin
  Result := TCRCUtils.Adler32(Data);
end;

function TCRCServiceImpl.Adler32(const Data: string): Cardinal;
begin
  Result := TCRCUtils.Adler32(Data);
end;

end.
