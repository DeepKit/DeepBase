{*******************************************************************************
  DeepBase Payment AES-256-GCM Decryption

  Cross-platform AES-256-GCM decryption for payment notification handling.
    - Windows: Win32 BCrypt (DeepBase.Crypto declarations)
    - macOS/Linux: OpenSSL (DeepBase.Crypto.OpenSSL)
    - Other: fail-closed (returns empty)

  Used by TPaymentHelper.AES256GCMDecrypt for WeChat Pay notification decryption.

  WeChat Pay AEAD_AES_256_GCM format:
  - Ciphertext: Base64-encoded, with last 16 bytes = GCM authentication tag
  - Nonce: Base64-encoded, 12 bytes
  - Associated data: Base64-encoded
  - Key: APIv3 key (32 bytes as UTF-8 or Base64)
*******************************************************************************}

unit DeepBase.Payment.AESGCM;

interface

uses
  System.SysUtils, System.Classes;

/// <summary>
///  AES-256-GCM decrypt raw bytes.
/// </summary>
/// <param name="Key">32-byte AES-256 key</param>
/// <param name="AIV">12-byte nonce/IV</param>
/// <param name="ACiphertext">Ciphertext WITHOUT the authentication tag</param>
/// <param name="AAAD">Additional authenticated data (may be empty)</param>
/// <param name="ATag">16-byte GCM authentication tag</param>
/// <returns>Decrypted plaintext, or empty TBytes on failure</returns>
function Payment_AES256GCM_Decrypt(const AKey, AIV, ACiphertext, AAAD, ATag: TBytes): TBytes;

implementation

{$IFDEF MSWINDOWS}

uses
  DeepBase.Crypto.Platform,
  Winapi.Windows;

function Payment_AES256GCM_Decrypt(const AKey, AIV, ACiphertext, AAAD, ATag: TBytes): TBytes;
var
  hAlg: THandle;
  hKey: THandle;
  Status: NTSTATUS;
  KeyObjSize: ULONG;
  KeyObjBuf: TBytes;
  BytesCopied: ULONG;
  ResultLen: ULONG;
  AuthInfo: BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO;
begin
  Result := nil;

  if (Length(AKey) <> 32) or (Length(AIV) <> 12) then
    Exit;
  if (Length(ACiphertext) = 0) or (Length(ATag) <> 16) then
    Exit;

  // Open AES provider
  Status := BCryptOpenAlgorithmProvider(hAlg, BCRYPT_AES_ALGORITHM, nil, 0);
  if Status <> STATUS_SUCCESS then
    Exit;

  try
    // Set chaining mode to GCM
    Status := BCryptSetProperty(hAlg, BCRYPT_CHAINING_MODE,
      PByte(PWideChar(BCRYPT_CHAIN_MODE_GCM)),
      (Length(BCRYPT_CHAIN_MODE_GCM) + 1) * SizeOf(Char), 0);
    if Status <> STATUS_SUCCESS then
      Exit;

    // Get key object size
    Status := BCryptGetProperty(hAlg, BCRYPT_OBJECT_LENGTH,
      @KeyObjSize, SizeOf(KeyObjSize), BytesCopied, 0);
    if Status <> STATUS_SUCCESS then
      Exit;

    SetLength(KeyObjBuf, KeyObjSize);

    // Import key
    Status := BCryptGenerateSymmetricKey(hAlg, hKey,
      @KeyObjBuf[0], KeyObjSize,
      @AKey[0], Length(AKey), 0);
    if Status <> STATUS_SUCCESS then
      Exit;

    try
      // Setup GCM auth info
      FillChar(AuthInfo, SizeOf(AuthInfo), 0);
      AuthInfo.cbSize := SizeOf(AuthInfo);
      AuthInfo.dwInfoVersion := 1;
      AuthInfo.pbNonce := @AIV[0];
      AuthInfo.cbNonce := Length(AIV);

      if Length(AAAD) > 0 then
      begin
        AuthInfo.pbAuthData := @AAAD[0];
        AuthInfo.cbAuthData := Length(AAAD);
      end;

      AuthInfo.pbTag := @ATag[0];
      AuthInfo.cbTag := Length(ATag);

      // Decrypt: output buffer = ciphertext length
      SetLength(Result, Length(ACiphertext));
      ResultLen := 0;

      // Need mutable copy for BCryptDecrypt
      var CipherBuf: TBytes := Copy(ACiphertext);

      Status := BCryptDecrypt(hKey, @CipherBuf[0], Length(CipherBuf),
        @AuthInfo, @AIV[0], Length(AIV),
        @Result[0], Length(Result), ResultLen, 0);

      if Status = STATUS_SUCCESS then
        SetLength(Result, ResultLen)
      else
        SetLength(Result, 0);
    finally
      BCryptDestroyKey(hKey);
    end;
  finally
    BCryptCloseAlgorithmProvider(hAlg, 0);
  end;
end;

{$ELSEIF DEFINED(MACOS) OR DEFINED(LINUX)}

uses
  DeepBase.Crypto.OpenSSL;

function Payment_AES256GCM_Decrypt(const AKey, AIV, ACiphertext, AAAD, ATag: TBytes): TBytes;
begin
  if not OpenSSL_IsLoaded then
    Exit(nil);

  try
    Result := OpenSSL_AES256GCM_Decrypt(AKey, AIV, ACiphertext, AAAD, ATag);
  except
    Result := nil;
  end;
end;

{$ELSE}

function Payment_AES256GCM_Decrypt(const AKey, AIV, ACiphertext, AAAD, ATag: TBytes): TBytes;
begin
  Result := nil;
end;

{$ENDIF}

end.
