unit DeepBase.Crypto;

{*******************************************************************************
  DeepBase Cryptography Utilities — Facade
  Re-exports all public symbols from the DeepBase.Crypto.* sub-modules so that
  existing callers (uses DeepBase.Crypto) continue to compile unchanged.

  Sub-modules:
    DeepBase.Crypto.Platform  — BCrypt/CryptoAPI bindings, ECryptoException
    DeepBase.Crypto.Hash      — THashUtils, TCRCUtils, TPasswordUtils
    DeepBase.Crypto.Encoding  — TEncodingUtils
    DeepBase.Crypto.AES       — TAESCrypto, TSimpleCrypto
    DeepBase.Crypto.RSA       — TRSAVerifier, TRSASigner
    DeepBase.Crypto.Random    — TRandomGenerator, CryptoRandomBytes

  Author: DeepBase Team
  Created: 2025-11-29
*******************************************************************************}

interface

uses
  System.SysUtils,
  DeepBase.Crypto.Platform,
  DeepBase.Crypto.Hash,
  DeepBase.Crypto.Encoding,
  DeepBase.Crypto.AES,
  DeepBase.Crypto.RSA,
  DeepBase.Crypto.Random;

// Re-export: all public symbols from the sub-modules above are accessible to
// any unit that has 'uses DeepBase.Crypto' in its interface or implementation.
// The uses clause exposes ECryptoException, THashAlgorithm, THashUtils,
// TEncodingUtils, TRandomGenerator, TPasswordHashOptions, TPasswordUtils,
// TAESMode, TAESKeySize, TAESCrypto, TSimpleCrypto, TCRCUtils,
// TRSAVerifier, TRSASigner, CryptoRandomBytes, etc.

type
  /// <summary>Static crypto helper — convenience shortcuts delegating to sub-modules.</summary>
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
