unit DeepBase.Crypto.AES;

{*******************************************************************************
  DeepBase Crypto - AES Encryption
  AES-128/192/256 with CBC/GCM/ECB modes, and TSimpleCrypto password-based
  authenticated encryption envelope.

  Author: DeepBase Team
  Created: 2025-11-29
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Hash,
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  DeepBase.Crypto.Platform, DeepBase.Crypto.Encoding, DeepBase.Crypto.Random,
  DeepBase.Crypto.Hash;

type
  /// <summary>AES encryption mode (仅保留已实现的两种，A17/Top20#10 删除假模式)</summary>
  TAESMode = (aesCBC, aesGCM);

  /// <summary>AES key size</summary>
  TAESKeySize = (aes128, aes192, aes256);

  /// <summary>Simple AES encryption wrapper using Windows CryptoAPI</summary>
  TAESCrypto = class
  private
    FKey: TBytes;
    FIV: TBytes;
    // A4-1: guards against CBC IV reuse. FIV is consumed by one implicit
    // Encrypt; the next implicit Encrypt regenerates it. An explicit SetIV
    // resets the flag so a caller-supplied IV is always honored for that call.
    FIVConsumed: Boolean;
    FMode: TAESMode;
    FKeySize: TAESKeySize;

    function GetKeyLength: Integer;
    function GetBlockSize: Integer;
    function PadData(const AData: TBytes): TBytes;
    function UnpadData(const AData: TBytes): TBytes;
    function GetKey: TBytes;
    function GetIV: TBytes;
  public
    constructor Create(AKeySize: TAESKeySize = aes256; AMode: TAESMode = aesGCM);
    destructor Destroy; override;

    /// <summary>Set key from bytes</summary>
    procedure SetKey(const AKey: TBytes);

    /// <summary>Set key from password (using PBKDF2)</summary>
    procedure SetKeyFromPassword(const APassword: string; const ASalt: TBytes);

    /// <summary>Set initialization vector</summary>
    procedure SetIV(const AIV: TBytes);

    /// <summary>Generate random key</summary>
    procedure GenerateKey;

    /// <summary>Generate random IV</summary>
    procedure GenerateIV;

    /// <summary>Generate random 12-byte nonce for GCM mode</summary>
    function GenerateNonce: TBytes;

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

    property Key: TBytes read GetKey;
    property IV: TBytes read GetIV;
    property Mode: TAESMode read FMode write FMode;
    property KeySize: TAESKeySize read FKeySize write FKeySize;
  end;

  /// <summary>Simple encryption helper (password-based)</summary>
  TSimpleCrypto = class
  public
    class function DeriveSalt(const APassword: string): TBytes; static;

    /// <summary>Encrypt string with password</summary>
    class function Encrypt(const AData, APassword: string): string; static;

    /// <summary>Decrypt string with password</summary>
    class function Decrypt(const AData, APassword: string): string; static;

    /// <summary>Encrypt bytes with password</summary>
    class function EncryptBytes(const AData: TBytes; const APassword: string): TBytes; static;

    /// <summary>Decrypt bytes with password</summary>
    class function DecryptBytes(const AData: TBytes; const APassword: string): TBytes; static;
  end;

// AES-GCM authenticated-encryption sizes (BCrypt GCM layout).
// Output of TAESCrypto.Encrypt = nonce(12) || ciphertext || tag(16).
// Exposed at interface level so other units (e.g. DeepBase.KeyManager) can
// parse the GCM wire format.
const
  AES_GCM_NONCE_SIZE = 12;
  AES_GCM_TAG_SIZE = 16;

implementation

{$IFNDEF MSWINDOWS}
uses
  DeepBase.Crypto.OpenSSL;
{$ENDIF}

const
  SIMPLE_CRYPTO_MAGIC_0 = $44; // D
  SIMPLE_CRYPTO_MAGIC_1 = $42; // B
  SIMPLE_CRYPTO_MAGIC_2 = $53; // S
  SIMPLE_CRYPTO_MAGIC_3 = $43; // C
  // SIMPLE_CRYPTO_VERSION is the envelope version for all NEW writes.
  // v3 derives the MAC key from the per-message salt via PBKDF2 (A4-3), closing
  // the strength gap vs the encryption key. v2/v1 are retained READ-ONLY so
  // envelopes already on disk stay decryptable; they are never written again.
  SIMPLE_CRYPTO_VERSION = 3;
  SIMPLE_CRYPTO_VERSION_V2 = 2;    // read-only: GCM + single-round HMAC MAC key
  SIMPLE_CRYPTO_VERSION_V1 = 1;    // read-only: CBC + salt derived from password
  SIMPLE_CRYPTO_HEADER_SIZE = 5;
  SIMPLE_CRYPTO_AES_BLOCK_SIZE = 16;
  SIMPLE_CRYPTO_SALT_SIZE = 16;
  SIMPLE_CRYPTO_MAC_SIZE = 32; // SHA-256
  // Legacy single-round HMAC context. READ path only (v1/v2 envelopes).
  SIMPLE_CRYPTO_MAC_CONTEXT = 'DeepBase.SimpleCrypto.MAC.v1';
  // v3 MAC-key domain-separation label, mixed into the PBKDF2 salt so the MAC
  // key and the encryption key stay independent even for the same password+salt.
  SIMPLE_CRYPTO_MAC_KDF_INFO = 'DeepBase.SimpleCrypto.MACKey.v3';

function BytesEqualConstantTime(const ALeft, ARight: TBytes): Boolean;
var
  I: Integer;
  Diff: Integer;
begin
  if Length(ALeft) <> Length(ARight) then
    Exit(False);

  Diff := 0;
  for I := 0 to High(ALeft) do
    Diff := Diff or (ALeft[I] xor ARight[I]);

  Result := Diff = 0;
end;

function SimpleCryptoHasHeader(const AData: TBytes): Boolean;
begin
  Result :=
    (Length(AData) >= SIMPLE_CRYPTO_HEADER_SIZE) and
    (AData[0] = SIMPLE_CRYPTO_MAGIC_0) and
    (AData[1] = SIMPLE_CRYPTO_MAGIC_1) and
    (AData[2] = SIMPLE_CRYPTO_MAGIC_2) and
    (AData[3] = SIMPLE_CRYPTO_MAGIC_3);
end;

// Legacy MAC key (single-round HMAC, no salt). Retained ONLY so v1/v2
// envelopes already on disk can still be authenticated; never used for new
// writes. See SimpleCryptoMacKeyV3 for the v3 write path.
function SimpleCryptoMacKey(const APassword: string): TBytes;
begin
  Result := THashUtils.HMAC(
    TEncoding.UTF8.GetBytes(APassword),
    TEncoding.UTF8.GetBytes(SIMPLE_CRYPTO_MAC_CONTEXT),
    haSHA256);
end;

// A4-3: v3 MAC key. Same PBKDF2 strength as the encryption key (100k rounds,
// SHA-256), bound to the per-message salt, with a distinct domain-separation
// label so it never equals the encryption key derived from the same salt.
function SimpleCryptoMacKeyV3(const APassword: string; const ASalt: TBytes): TBytes;
var
  LInfo, LSaltInfo: TBytes;
begin
  LInfo := TEncoding.UTF8.GetBytes(SIMPLE_CRYPTO_MAC_KDF_INFO);
  SetLength(LSaltInfo, Length(ASalt) + Length(LInfo));
  if Length(ASalt) > 0 then
    Move(ASalt[0], LSaltInfo[0], Length(ASalt));
  Move(LInfo[0], LSaltInfo[Length(ASalt)], Length(LInfo));
  Result := TPasswordUtils.PBKDF2(APassword, LSaltInfo, 100000, SIMPLE_CRYPTO_MAC_SIZE, haSHA256);
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

destructor TAESCrypto.Destroy;
begin
  if Length(FKey) > 0 then
    FillChar(FKey[0], Length(FKey), 0);
  FKey := nil;
  if Length(FIV) > 0 then
    FillChar(FIV[0], Length(FIV), 0);
  FIV := nil;
  inherited;
end;

function TAESCrypto.GetKey: TBytes;
begin
  Result := Copy(FKey);
end;

function TAESCrypto.GetIV: TBytes;
begin
  Result := Copy(FIV);
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
begin
  if Length(ASalt) = 0 then
    raise ECryptoException.Create('Salt is required for key derivation. Pass a cryptographically random salt.');

  FKey := TPasswordUtils.PBKDF2(APassword, ASalt, 100000, GetKeyLength, haSHA256);
end;

class function TSimpleCrypto.DeriveSalt(const APassword: string): TBytes;
begin
  Result := System.Hash.THashSHA2.GetHashBytes(APassword + '_salt_v1', System.Hash.THashSHA2.TSHA2Version.SHA256);
end;

procedure TAESCrypto.SetIV(const AIV: TBytes);
begin
  if Length(AIV) <> GetBlockSize then
    raise ECryptoException.CreateFmt('Invalid IV length. Expected %d bytes', [GetBlockSize]);
  FIV := Copy(AIV);
  // An explicit IV is authoritative for the next Encrypt; do not auto-rotate it.
  FIVConsumed := False;
end;

procedure TAESCrypto.GenerateKey;
begin
  FKey := TRandomGenerator.RandomBytes(GetKeyLength);
end;

procedure TAESCrypto.GenerateIV;
begin
  FIV := TRandomGenerator.RandomBytes(GetBlockSize);
  FIVConsumed := False;
end;

function TAESCrypto.GenerateNonce: TBytes;
begin
  Result := TRandomGenerator.RandomBytes(AES_GCM_NONCE_SIZE);
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
  I: Integer;
begin
  if Length(AData) = 0 then
    Exit(nil);

  LPadLen := AData[High(AData)];
  if (LPadLen < 1) or (LPadLen > GetBlockSize) or (LPadLen > Length(AData)) then
    raise ECryptoException.Create('Invalid padding');

  for I := Length(AData) - LPadLen to High(AData) do
    if AData[I] <> LPadLen then
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
  LNonce, LTag, LCipher: TBytes;
  LAuthInfo: BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO;
begin
  LAlgHandle := 0;
  LKeyHandle := 0;

  try
    // Open AES algorithm provider
    LStatus := BCryptOpenAlgorithmProvider(LAlgHandle, BCRYPT_AES_ALGORITHM, nil, 0);
    if LStatus <> STATUS_SUCCESS then
      raise ECryptoException.CreateFmt('BCryptOpenAlgorithmProvider failed: %d', [LStatus]);

    if FMode = aesGCM then
    begin
      // --- GCM authenticated encryption ---
      LChainMode := BCRYPT_CHAIN_MODE_GCM;
      LStatus := BCryptSetProperty(LAlgHandle, BCRYPT_CHAINING_MODE,
        PByte(PWideChar(LChainMode)), (Length(LChainMode) + 1) * SizeOf(WideChar), 0);
      if LStatus <> STATUS_SUCCESS then
        raise ECryptoException.CreateFmt('BCryptSetProperty (ChainMode GCM) failed: %d', [LStatus]);

      LStatus := BCryptGetProperty(LAlgHandle, BCRYPT_OBJECT_LENGTH,
        @LKeyObjectSize, SizeOf(LKeyObjectSize), LBlockLen, 0);
      if LStatus <> STATUS_SUCCESS then
        raise ECryptoException.CreateFmt('BCryptGetProperty failed: %d', [LStatus]);

      SetLength(LKeyObject, LKeyObjectSize);
      LStatus := BCryptGenerateSymmetricKey(LAlgHandle, LKeyHandle,
        @LKeyObject[0], LKeyObjectSize, @FKey[0], Length(FKey), 0);
      if LStatus <> STATUS_SUCCESS then
        raise ECryptoException.CreateFmt('BCryptGenerateSymmetricKey failed: %d', [LStatus]);

      // Generate random 12-byte nonce
      LNonce := TRandomGenerator.RandomBytes(AES_GCM_NONCE_SIZE);

      // Prepare tag buffer
      SetLength(LTag, AES_GCM_TAG_SIZE);

      // Initialize authenticated cipher mode info
      FillChar(LAuthInfo, SizeOf(LAuthInfo), 0);
      LAuthInfo.cbSize := SizeOf(BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO);
      LAuthInfo.dwInfoVersion := BCRYPT_INIT_AUTH_MODE_INFO_VERSION;
      LAuthInfo.pbNonce := @LNonce[0];
      LAuthInfo.cbNonce := AES_GCM_NONCE_SIZE;
      LAuthInfo.pbTag := @LTag[0];
      LAuthInfo.cbTag := AES_GCM_TAG_SIZE;

      // GCM: no padding, output size = input size
      SetLength(LCipher, Length(AData));
      if Length(AData) > 0 then
        LStatus := BCryptEncrypt(LKeyHandle, @AData[0], Length(AData),
          @LAuthInfo, nil, 0, @LCipher[0], Length(LCipher), LResultSize, 0)
      else
        LStatus := BCryptEncrypt(LKeyHandle, nil, 0,
          @LAuthInfo, nil, 0, nil, 0, LResultSize, 0);
      if LStatus <> STATUS_SUCCESS then
        raise ECryptoException.CreateFmt('BCryptEncrypt GCM failed: %d', [LStatus]);

      SetLength(LCipher, LResultSize);

      // Output format: Nonce(12) + CipherText + Tag(16)
      SetLength(Result, AES_GCM_NONCE_SIZE + Length(LCipher) + AES_GCM_TAG_SIZE);
      Move(LNonce[0], Result[0], AES_GCM_NONCE_SIZE);
      if Length(LCipher) > 0 then
        Move(LCipher[0], Result[AES_GCM_NONCE_SIZE], Length(LCipher));
      Move(LTag[0], Result[AES_GCM_NONCE_SIZE + Length(LCipher)], AES_GCM_TAG_SIZE);
    end
    else
    begin
      // --- CBC mode ---
      LChainMode := BCRYPT_CHAIN_MODE_CBC;
      LStatus := BCryptSetProperty(LAlgHandle, BCRYPT_CHAINING_MODE,
        PByte(PWideChar(LChainMode)), (Length(LChainMode) + 1) * SizeOf(WideChar), 0);
      if LStatus <> STATUS_SUCCESS then
        raise ECryptoException.CreateFmt('BCryptSetProperty (ChainMode) failed: %d', [LStatus]);

      LStatus := BCryptGetProperty(LAlgHandle, BCRYPT_OBJECT_LENGTH,
        @LKeyObjectSize, SizeOf(LKeyObjectSize), LBlockLen, 0);
      if LStatus <> STATUS_SUCCESS then
        raise ECryptoException.CreateFmt('BCryptGetProperty failed: %d', [LStatus]);

      SetLength(LKeyObject, LKeyObjectSize);
      LStatus := BCryptGenerateSymmetricKey(LAlgHandle, LKeyHandle,
        @LKeyObject[0], LKeyObjectSize, @FKey[0], Length(FKey), 0);
      if LStatus <> STATUS_SUCCESS then
        raise ECryptoException.CreateFmt('BCryptGenerateSymmetricKey failed: %d', [LStatus]);

      // A4-1: never reuse an IV. If the current IV was already consumed by a
      // prior implicit Encrypt, advance to a fresh random one. A caller that
      // explicitly SetIV resets the consumed flag, so its IV is honored.
      if FIVConsumed then
        GenerateIV;
      LPadded := PadData(AData);
      LIVCopy := Copy(FIV);

      LStatus := BCryptEncrypt(LKeyHandle, @LPadded[0], Length(LPadded),
        nil, @LIVCopy[0], Length(LIVCopy), nil, 0, LResultSize, 0);
      if LStatus <> STATUS_SUCCESS then
        raise ECryptoException.CreateFmt('BCryptEncrypt (size query) failed: %d', [LStatus]);

      SetLength(Result, LResultSize);
      LIVCopy := Copy(FIV);

      LStatus := BCryptEncrypt(LKeyHandle, @LPadded[0], Length(LPadded),
        nil, @LIVCopy[0], Length(LIVCopy), @Result[0], LResultSize, LResultSize, 0);
      if LStatus <> STATUS_SUCCESS then
        raise ECryptoException.CreateFmt('BCryptEncrypt failed: %d', [LStatus]);

      SetLength(Result, LResultSize);
      FIVConsumed := True;
    end;
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
  LNonce, LTag, LCipher: TBytes;
begin
  if FMode = aesGCM then
  begin
    // GCM authenticated encryption via OpenSSL
    LNonce := TRandomGenerator.RandomBytes(AES_GCM_NONCE_SIZE);
    LCipher := DeepBase.Crypto.OpenSSL.OpenSSL_AES256GCM_Encrypt(FKey, LNonce, AData, nil, LTag);

    // Output format: Nonce(12) + CipherText + Tag(16)
    SetLength(Result, AES_GCM_NONCE_SIZE + Length(LCipher) + AES_GCM_TAG_SIZE);
    Move(LNonce[0], Result[0], AES_GCM_NONCE_SIZE);
    if Length(LCipher) > 0 then
      Move(LCipher[0], Result[AES_GCM_NONCE_SIZE], Length(LCipher));
    Move(LTag[0], Result[AES_GCM_NONCE_SIZE + Length(LCipher)], AES_GCM_TAG_SIZE);
  end
  else
  begin
    // A4-1: never reuse an IV (see Windows branch).
    if FIVConsumed then
      GenerateIV;
    LPadded := PadData(AData);
    Result := DeepBase.Crypto.OpenSSL.OpenSSL_AES256CBC_Encrypt(FKey, FIV, LPadded);
    FIVConsumed := True;
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
  LNonce, LTag, LCipher: TBytes;
  LAuthInfo: BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO;
  LCipherLen: Integer;
begin
  LAlgHandle := 0;
  LKeyHandle := 0;

  try
    // Open AES algorithm provider
    LStatus := BCryptOpenAlgorithmProvider(LAlgHandle, BCRYPT_AES_ALGORITHM, nil, 0);
    if LStatus <> STATUS_SUCCESS then
      raise ECryptoException.CreateFmt('BCryptOpenAlgorithmProvider failed: %d', [LStatus]);

    if FMode = aesGCM then
    begin
      // --- GCM authenticated decryption ---
      // Input format: Nonce(12) + CipherText + Tag(16)
      if Length(AData) < AES_GCM_NONCE_SIZE + AES_GCM_TAG_SIZE then
        raise ECryptoException.Create('Invalid GCM ciphertext length');

      // Extract nonce from beginning
      SetLength(LNonce, AES_GCM_NONCE_SIZE);
      Move(AData[0], LNonce[0], AES_GCM_NONCE_SIZE);

      // Extract tag from end
      SetLength(LTag, AES_GCM_TAG_SIZE);
      Move(AData[Length(AData) - AES_GCM_TAG_SIZE], LTag[0], AES_GCM_TAG_SIZE);

      // Extract ciphertext from middle
      LCipherLen := Length(AData) - AES_GCM_NONCE_SIZE - AES_GCM_TAG_SIZE;
      SetLength(LCipher, LCipherLen);
      if LCipherLen > 0 then
        Move(AData[AES_GCM_NONCE_SIZE], LCipher[0], LCipherLen);

      LChainMode := BCRYPT_CHAIN_MODE_GCM;
      LStatus := BCryptSetProperty(LAlgHandle, BCRYPT_CHAINING_MODE,
        PByte(PWideChar(LChainMode)), (Length(LChainMode) + 1) * SizeOf(WideChar), 0);
      if LStatus <> STATUS_SUCCESS then
        raise ECryptoException.CreateFmt('BCryptSetProperty (ChainMode GCM) failed: %d', [LStatus]);

      LStatus := BCryptGetProperty(LAlgHandle, BCRYPT_OBJECT_LENGTH,
        @LKeyObjectSize, SizeOf(LKeyObjectSize), LBlockLen, 0);
      if LStatus <> STATUS_SUCCESS then
        raise ECryptoException.CreateFmt('BCryptGetProperty failed: %d', [LStatus]);

      SetLength(LKeyObject, LKeyObjectSize);
      LStatus := BCryptGenerateSymmetricKey(LAlgHandle, LKeyHandle,
        @LKeyObject[0], LKeyObjectSize, @FKey[0], Length(FKey), 0);
      if LStatus <> STATUS_SUCCESS then
        raise ECryptoException.CreateFmt('BCryptGenerateSymmetricKey failed: %d', [LStatus]);

      // Initialize authenticated cipher mode info
      FillChar(LAuthInfo, SizeOf(LAuthInfo), 0);
      LAuthInfo.cbSize := SizeOf(BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO);
      LAuthInfo.dwInfoVersion := BCRYPT_INIT_AUTH_MODE_INFO_VERSION;
      LAuthInfo.pbNonce := @LNonce[0];
      LAuthInfo.cbNonce := AES_GCM_NONCE_SIZE;
      LAuthInfo.pbTag := @LTag[0];
      LAuthInfo.cbTag := AES_GCM_TAG_SIZE;

      // GCM: output size = ciphertext size (no padding)
      SetLength(LDecrypted, LCipherLen);
      if LCipherLen > 0 then
        LStatus := BCryptDecrypt(LKeyHandle, @LCipher[0], LCipherLen,
          @LAuthInfo, nil, 0, @LDecrypted[0], Length(LDecrypted), LResultSize, 0)
      else
        LStatus := BCryptDecrypt(LKeyHandle, nil, 0,
          @LAuthInfo, nil, 0, nil, 0, LResultSize, 0);
      if LStatus <> STATUS_SUCCESS then
        raise ECryptoException.CreateFmt('BCryptDecrypt GCM failed (tag mismatch?): %d', [LStatus]);

      SetLength(LDecrypted, LResultSize);
      Result := LDecrypted;
    end
    else
    begin
      // --- CBC mode ---
      if Length(AData) mod 16 <> 0 then
        raise ECryptoException.Create('Invalid ciphertext length');

      LChainMode := BCRYPT_CHAIN_MODE_CBC;
      LStatus := BCryptSetProperty(LAlgHandle, BCRYPT_CHAINING_MODE,
        PByte(PWideChar(LChainMode)), (Length(LChainMode) + 1) * SizeOf(WideChar), 0);
      if LStatus <> STATUS_SUCCESS then
        raise ECryptoException.CreateFmt('BCryptSetProperty (ChainMode) failed: %d', [LStatus]);

      LStatus := BCryptGetProperty(LAlgHandle, BCRYPT_OBJECT_LENGTH,
        @LKeyObjectSize, SizeOf(LKeyObjectSize), LBlockLen, 0);
      if LStatus <> STATUS_SUCCESS then
        raise ECryptoException.CreateFmt('BCryptGetProperty failed: %d', [LStatus]);

      SetLength(LKeyObject, LKeyObjectSize);
      LStatus := BCryptGenerateSymmetricKey(LAlgHandle, LKeyHandle,
        @LKeyObject[0], LKeyObjectSize, @FKey[0], Length(FKey), 0);
      if LStatus <> STATUS_SUCCESS then
        raise ECryptoException.CreateFmt('BCryptGenerateSymmetricKey failed: %d', [LStatus]);

      LIVCopy := Copy(FIV);

      LStatus := BCryptDecrypt(LKeyHandle, @AData[0], Length(AData),
        nil, @LIVCopy[0], Length(LIVCopy), nil, 0, LResultSize, 0);
      if LStatus <> STATUS_SUCCESS then
        raise ECryptoException.CreateFmt('BCryptDecrypt (size query) failed: %d', [LStatus]);

      SetLength(LDecrypted, LResultSize);
      LIVCopy := Copy(FIV);

      LStatus := BCryptDecrypt(LKeyHandle, @AData[0], Length(AData),
        nil, @LIVCopy[0], Length(LIVCopy), @LDecrypted[0], LResultSize, LResultSize, 0);
      if LStatus <> STATUS_SUCCESS then
        raise ECryptoException.CreateFmt('BCryptDecrypt failed: %d', [LStatus]);

      SetLength(LDecrypted, LResultSize);
      Result := UnpadData(LDecrypted);
    end;
  finally
    if LKeyHandle <> 0 then
      BCryptDestroyKey(LKeyHandle);
    if LAlgHandle <> 0 then
      BCryptCloseAlgorithmProvider(LAlgHandle, 0);
  end;
end;
{$ELSE}
var
  LDecrypted: TBytes;
  LNonce, LTag, LCipher: TBytes;
  LCipherLen: Integer;
begin
  if FMode = aesGCM then
  begin
    // GCM authenticated decryption via OpenSSL
    // Input format: Nonce(12) + CipherText + Tag(16)
    if Length(AData) < AES_GCM_NONCE_SIZE + AES_GCM_TAG_SIZE then
      raise ECryptoException.Create('Invalid GCM ciphertext length');

    SetLength(LNonce, AES_GCM_NONCE_SIZE);
    Move(AData[0], LNonce[0], AES_GCM_NONCE_SIZE);

    SetLength(LTag, AES_GCM_TAG_SIZE);
    Move(AData[Length(AData) - AES_GCM_TAG_SIZE], LTag[0], AES_GCM_TAG_SIZE);

    LCipherLen := Length(AData) - AES_GCM_NONCE_SIZE - AES_GCM_TAG_SIZE;
    SetLength(LCipher, LCipherLen);
    if LCipherLen > 0 then
      Move(AData[AES_GCM_NONCE_SIZE], LCipher[0], LCipherLen);

    Result := DeepBase.Crypto.OpenSSL.OpenSSL_AES256GCM_Decrypt(FKey, LNonce, LCipher, nil, LTag);
  end
  else
  begin
    if Length(AData) mod 16 <> 0 then
      raise ECryptoException.Create('Invalid ciphertext length');
    LDecrypted := DeepBase.Crypto.OpenSSL.OpenSSL_AES256CBC_Decrypt(FKey, FIV, AData);
    Result := UnpadData(LDecrypted);
  end;
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
  Plain: TBytes;
  Enc: TBytes;
begin
  // Encrypt UTF-8 bytes and return Base64 of (IV || Ciphertext)
  Plain := TEncoding.UTF8.GetBytes(AData);
  Enc := EncryptBytes(Plain, APassword);
  Result := TEncodingUtils.Base64Encode(Enc);
end;

class function TSimpleCrypto.Decrypt(const AData, APassword: string): string;
var
  Enc, Plain: TBytes;
begin
  // Decode Base64 then decrypt the authenticated envelope.
  Enc := TEncodingUtils.Base64Decode(AData);
  Plain := DecryptBytes(Enc, APassword);
  try
    Result := TEncoding.UTF8.GetString(Plain);
  except
    on Exception do
      raise ECryptoException.Create('Invalid encrypted data or password');
  end;
end;

class function TSimpleCrypto.EncryptBytes(const AData: TBytes; const APassword: string): TBytes;
var
  LAES: TAESCrypto;
  LSalt, Cipher, IV, MacKey, MacInput, Mac: TBytes;
  BlockSize: Integer;
  PayloadLen: Integer;
begin
  // Generate cryptographically random salt
  LSalt := TRandomGenerator.RandomBytes(SIMPLE_CRYPTO_SALT_SIZE);

  LAES := TAESCrypto.Create(aes256, aesGCM);
  try
    LAES.SetKeyFromPassword(APassword, LSalt);
    Cipher := LAES.Encrypt(AData);
    IV := LAES.IV;
    BlockSize := Length(IV);

    // v3 format: Header(5) + Salt(16) + IV(16) + Cipher + MAC(32)
    PayloadLen := SIMPLE_CRYPTO_HEADER_SIZE + SIMPLE_CRYPTO_SALT_SIZE + BlockSize + Length(Cipher);
    SetLength(MacInput, PayloadLen);
    MacInput[0] := SIMPLE_CRYPTO_MAGIC_0;
    MacInput[1] := SIMPLE_CRYPTO_MAGIC_1;
    MacInput[2] := SIMPLE_CRYPTO_MAGIC_2;
    MacInput[3] := SIMPLE_CRYPTO_MAGIC_3;
    MacInput[4] := SIMPLE_CRYPTO_VERSION;
    Move(LSalt[0], MacInput[SIMPLE_CRYPTO_HEADER_SIZE], SIMPLE_CRYPTO_SALT_SIZE);
    if BlockSize > 0 then
      Move(IV[0], MacInput[SIMPLE_CRYPTO_HEADER_SIZE + SIMPLE_CRYPTO_SALT_SIZE], BlockSize);
    if Length(Cipher) > 0 then
      Move(Cipher[0], MacInput[SIMPLE_CRYPTO_HEADER_SIZE + SIMPLE_CRYPTO_SALT_SIZE + BlockSize], Length(Cipher));

    // A4-3: v3 binds the MAC key to the per-message salt via PBKDF2.
    MacKey := SimpleCryptoMacKeyV3(APassword, LSalt);
    Mac := THashUtils.HMAC(MacKey, MacInput, haSHA256);

    SetLength(Result, PayloadLen + Length(Mac));
    Move(MacInput[0], Result[0], PayloadLen);
    Move(Mac[0], Result[PayloadLen], Length(Mac));
  finally
    LAES.Free;
  end;
end;

class function TSimpleCrypto.DecryptBytes(const AData: TBytes; const APassword: string): TBytes;
var
  LAES: TAESCrypto;
  LSalt, IV, Cipher, MacKey, MacInput, ExpectedMac, ActualMac: TBytes;
  MacInputLen, CipherLen: Integer;
  LVersion: Byte;
  LUseGCM: Boolean;
begin
  if Length(AData) = 0 then
    Exit(nil);

  // LUseGCM selects the AES mode the data was originally written with:
  // v3/v2 use AES-GCM; v1 and legacy (no header) use AES-CBC and must be
  // decrypted with CBC or the data is unrecoverable after the GCM upgrade.
  LUseGCM := False;

  if SimpleCryptoHasHeader(AData) then
  begin
    LVersion := AData[4];
    if (LVersion <> SIMPLE_CRYPTO_VERSION) and
       (LVersion <> SIMPLE_CRYPTO_VERSION_V2) and
       (LVersion <> SIMPLE_CRYPTO_VERSION_V1) then
      raise ECryptoException.Create('Unsupported encrypted data version');

    if (LVersion = SIMPLE_CRYPTO_VERSION) or (LVersion = SIMPLE_CRYPTO_VERSION_V2) then
    begin
      LUseGCM := True;
      // v3/v2 framing: Header(5) + Salt(16) + IV(16) + Cipher + MAC(32)
      if Length(AData) < SIMPLE_CRYPTO_HEADER_SIZE + SIMPLE_CRYPTO_SALT_SIZE + SIMPLE_CRYPTO_AES_BLOCK_SIZE + SIMPLE_CRYPTO_MAC_SIZE then
        raise ECryptoException.Create('Invalid encrypted data (too short)');

      MacInputLen := Length(AData) - SIMPLE_CRYPTO_MAC_SIZE;
      SetLength(MacInput, MacInputLen);
      Move(AData[0], MacInput[0], MacInputLen);

      SetLength(ExpectedMac, SIMPLE_CRYPTO_MAC_SIZE);
      Move(AData[MacInputLen], ExpectedMac[0], SIMPLE_CRYPTO_MAC_SIZE);

      SetLength(LSalt, SIMPLE_CRYPTO_SALT_SIZE);
      Move(AData[SIMPLE_CRYPTO_HEADER_SIZE], LSalt[0], SIMPLE_CRYPTO_SALT_SIZE);

      // A4-3: MAC-key derivation is version-bound — v3 uses PBKDF2(salt),
      // v2 used the legacy single-round HMAC. Verify with the method the
      // writer actually used, otherwise authenticated data would be rejected.
      if LVersion = SIMPLE_CRYPTO_VERSION then
        MacKey := SimpleCryptoMacKeyV3(APassword, LSalt)
      else
        MacKey := SimpleCryptoMacKey(APassword);
      ActualMac := THashUtils.HMAC(MacKey, MacInput, haSHA256);
      if not BytesEqualConstantTime(ExpectedMac, ActualMac) then
        raise ECryptoException.Create('Invalid encrypted data or password');

      SetLength(IV, SIMPLE_CRYPTO_AES_BLOCK_SIZE);
      Move(AData[SIMPLE_CRYPTO_HEADER_SIZE + SIMPLE_CRYPTO_SALT_SIZE], IV[0], SIMPLE_CRYPTO_AES_BLOCK_SIZE);

      CipherLen := MacInputLen - SIMPLE_CRYPTO_HEADER_SIZE - SIMPLE_CRYPTO_SALT_SIZE - SIMPLE_CRYPTO_AES_BLOCK_SIZE;
      SetLength(Cipher, CipherLen);
      if CipherLen > 0 then
        Move(AData[SIMPLE_CRYPTO_HEADER_SIZE + SIMPLE_CRYPTO_SALT_SIZE + SIMPLE_CRYPTO_AES_BLOCK_SIZE], Cipher[0], CipherLen);
    end
    else
    begin
      // v1 format (backward compat): Header(5) + IV(16) + Cipher + MAC(32)
      if Length(AData) < SIMPLE_CRYPTO_HEADER_SIZE + SIMPLE_CRYPTO_AES_BLOCK_SIZE + SIMPLE_CRYPTO_MAC_SIZE then
        raise ECryptoException.Create('Invalid encrypted data (too short)');

      MacInputLen := Length(AData) - SIMPLE_CRYPTO_MAC_SIZE;
      SetLength(MacInput, MacInputLen);
      Move(AData[0], MacInput[0], MacInputLen);

      SetLength(ExpectedMac, SIMPLE_CRYPTO_MAC_SIZE);
      Move(AData[MacInputLen], ExpectedMac[0], SIMPLE_CRYPTO_MAC_SIZE);

      MacKey := SimpleCryptoMacKey(APassword);
      ActualMac := THashUtils.HMAC(MacKey, MacInput, haSHA256);
      if not BytesEqualConstantTime(ExpectedMac, ActualMac) then
        raise ECryptoException.Create('Invalid encrypted data or password');

      LSalt := DeriveSalt(APassword);

      SetLength(IV, SIMPLE_CRYPTO_AES_BLOCK_SIZE);
      Move(AData[SIMPLE_CRYPTO_HEADER_SIZE], IV[0], SIMPLE_CRYPTO_AES_BLOCK_SIZE);

      CipherLen := MacInputLen - SIMPLE_CRYPTO_HEADER_SIZE - SIMPLE_CRYPTO_AES_BLOCK_SIZE;
      SetLength(Cipher, CipherLen);
      if CipherLen > 0 then
        Move(AData[SIMPLE_CRYPTO_HEADER_SIZE + SIMPLE_CRYPTO_AES_BLOCK_SIZE], Cipher[0], CipherLen);
    end;
  end
  else
  begin
    // Legacy format (no header): IV(16) + Cipher
    if Length(AData) < SIMPLE_CRYPTO_AES_BLOCK_SIZE then
      raise ECryptoException.Create('Invalid encrypted data (too short)');

    LSalt := DeriveSalt(APassword);

    SetLength(IV, SIMPLE_CRYPTO_AES_BLOCK_SIZE);
    Move(AData[0], IV[0], SIMPLE_CRYPTO_AES_BLOCK_SIZE);

    SetLength(Cipher, Length(AData) - SIMPLE_CRYPTO_AES_BLOCK_SIZE);
    if Length(Cipher) > 0 then
      Move(AData[SIMPLE_CRYPTO_AES_BLOCK_SIZE], Cipher[0], Length(Cipher));
  end;

  // Use the AES mode that matches how this data was originally encrypted.
  // GCM for v3/v2 data; CBC for v1 and legacy data (the CBC path consumes the
  // 16-byte IV set below — GCM instead reads a 12-byte nonce from Cipher).
  if LUseGCM then
    LAES := TAESCrypto.Create(aes256, aesGCM)
  else
    LAES := TAESCrypto.Create(aes256, aesCBC);
  try
    LAES.SetKeyFromPassword(APassword, LSalt);
    LAES.SetIV(IV);
    Result := LAES.Decrypt(Cipher);
  finally
    LAES.Free;
  end;
end;

end.
