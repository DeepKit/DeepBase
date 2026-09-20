unit DeepBase.Security.UBS2;

{*******************************************************************************
  DeepBase Security UBS2 - Authenticated secret envelope (format SSOT).

  UBS2 v2 layout (all integers little-endian):

    [0..3]   magic  'UBS2'
    [4]      format version (= 2)
    [5]      KDF id   (= 1, PBKDF2-HMAC-SHA256)
    [6..9]   PBKDF2 iteration count
    [10..25] per-record salt (16 bytes)
    [26..]   AES-256-GCM blob produced by TAESCrypto: nonce(12) || ciphertext || tag(16)

  The fixed header is fed to GCM as additional authenticated data together with
  the machine binding, so the iteration count and the KDF id cannot be downgraded
  or replayed without breaking the authentication tag (A11-03).

  Key hierarchy: PBKDF2 is applied to the *user secret* (32 random bytes held in
  ~/.deepbase/master.key or an explicit key file). Machine identity is NOT part
  of the derived-key password; it only travels through the AAD, which is what
  makes "same machine, different user" decryption impossible.

  v1 is accepted by UnprotectLegacyV1 only, which is reachable from the UBS2
  migrator and never from the production read path.

  Author: DeepBase Team
  Created: 2026-09-20
*******************************************************************************}

interface

uses
  System.SysUtils,
  DeepBase.Exceptions,
  DeepBase.Crypto.AES, DeepBase.Crypto.Hash, DeepBase.Crypto.Random,
  DeepBase.Crypto.Platform,
  DeepBase.SecureMemory;

const
  // Raised by TAESCrypto on any primitive failure; the envelope translates it into
  // its own exception type so callers have one contract on both BCrypt and OpenSSL.
  AUTH_FAILURE_HINT = 'wrong user secret, foreign machine binding, or a tampered record';

const
  UBS2_MAGIC = 'UBS2';
  UBS2_FORMAT_VERSION_V1 = 1;          // legacy: machine fingerprint as password entropy, no AAD
  UBS2_FORMAT_VERSION_V2 = 2;          // current writer
  UBS2_FORMAT_VERSION = UBS2_FORMAT_VERSION_V2;
  UBS2_KDF_PBKDF2_HMAC_SHA256 = 1;
  UBS2_SALT_SIZE = 16;
  UBS2_NONCE_SIZE = AES_GCM_NONCE_SIZE;
  UBS2_TAG_SIZE = AES_GCM_TAG_SIZE;
  UBS2_KEY_SIZE = 32;
  UBS2_HEADER_SIZE = 26;               // magic(4) ver(1) kdf(1) iter(4) salt(16)
  UBS2_MIN_ENVELOPE_SIZE = UBS2_HEADER_SIZE + UBS2_NONCE_SIZE + UBS2_TAG_SIZE;
  UBS2_MASTER_SECRET_SIZE = 32;
  UBS2_MASTER_SECRET_MIN_SIZE = 32;

  // KDF cost policy: anything outside these bounds is rejected on read, so a
  // tampered header cannot force a cheap derivation (A11-03).
  UBS2_MIN_ITERATIONS = 100_000;
  UBS2_MAX_ITERATIONS = 2_000_000;
  UBS2_DEFAULT_ITERATIONS = 600_000;

type
  /// <summary>Key material required to open or seal a UBS2 envelope.</summary>
  TUBS2KeyMaterial = record
    /// <summary>User secret; the only password entropy. Must be UBS2_MASTER_SECRET_MIN_SIZE bytes.</summary>
    MasterSecret: TBytes;
    /// <summary>Machine binding value. Authenticated (AAD) but never secret.</summary>
    Binding: TBytes;
  end;

  /// <summary>Codec for the UBS2 envelope. Stateless; all members are class-level.</summary>
  TUBS2 = class
  public
    class function Protect(const APlaintext: TBytes; const AKey: TUBS2KeyMaterial;
      AIterations: Integer = UBS2_DEFAULT_ITERATIONS): TBytes; static;

    class function Unprotect(const AEnvelope: TBytes; const AKey: TUBS2KeyMaterial): TBytes; static;

    /// <summary>Migrator-only: open a v1 envelope whose password entropy was the
    /// machine fingerprint itself. Never called by the production read path.</summary>
    class function UnprotectLegacyV1(const AEnvelope: TBytes;
      const ALegacyPassphrase: string): TBytes; static;

    class function IsUBS2(const AData: TBytes): Boolean; static;
    class function FormatVersionOf(const AEnvelope: TBytes): Byte; static;
  end;

implementation

const
  // Distinct from the password entropy so an envelope sealed for one purpose can
  // never authenticate as another.
  UBS2_AAD_LABEL = 'DeepBase.UBS2.v2';

function BytesToHexLower(const AData: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AData) do
    Result := Result + LowerCase(IntToHex(AData[I], 2));
end;

// The user secret is binary; PBKDF2 here is driven by a string password, so the
// secret is carried as lowercase hex. Deterministic and lossless, and pinned by
// the format version.
function MasterSecretPassphrase(const AMasterSecret: TBytes): string;
begin
  Result := BytesToHexLower(AMasterSecret);
end;

procedure AppendBytes(var ADest: TBytes; const ASrc: TBytes);
var
  LSize: Integer;
begin
  if Length(ASrc) = 0 then
    Exit;
  LSize := Length(ADest);
  SetLength(ADest, LSize + Length(ASrc));
  Move(ASrc[0], ADest[LSize], Length(ASrc));
end;

procedure AppendCardinalLE(var ADest: TBytes; AValue: Cardinal);
var
  LSize: Integer;
begin
  LSize := Length(ADest);
  SetLength(ADest, LSize + 4);
  ADest[LSize] := Byte(AValue);
  ADest[LSize + 1] := Byte(AValue shr 8);
  ADest[LSize + 2] := Byte(AValue shr 16);
  ADest[LSize + 3] := Byte(AValue shr 24);
end;

function ReadCardinalLE(const AData: TBytes; AOffset: Integer): Cardinal;
begin
  Result := Cardinal(AData[AOffset]) or
            (Cardinal(AData[AOffset + 1]) shl 8) or
            (Cardinal(AData[AOffset + 2]) shl 16) or
            (Cardinal(AData[AOffset + 3]) shl 24);
end;

function MagicMatches(const AData: TBytes): Boolean;
var
  I: Integer;
begin
  Result := Length(AData) >= UBS2_MIN_ENVELOPE_SIZE;
  if not Result then
    Exit;
  for I := 1 to Length(UBS2_MAGIC) do
    if AData[I - 1] <> Ord(UBS2_MAGIC[I]) then
      Exit(False);
end;

// AAD = header || len(binding) || binding || len(label) || label
function BuildAAD(const AHeader, ABinding: TBytes): TBytes;
begin
  Result := Copy(AHeader, 0, UBS2_HEADER_SIZE);
  AppendCardinalLE(Result, Cardinal(Length(ABinding)));
  AppendBytes(Result, ABinding);
  AppendCardinalLE(Result, Cardinal(TEncoding.UTF8.GetByteCount(UBS2_AAD_LABEL)));
  AppendBytes(Result, TEncoding.UTF8.GetBytes(UBS2_AAD_LABEL));
end;

function BuildHeader(AFormatVersion: Byte; AIterations: Integer; const ASalt: TBytes): TBytes;
var
  I: Integer;
  LValue: Cardinal;
begin
  SetLength(Result, UBS2_HEADER_SIZE);
  for I := 1 to Length(UBS2_MAGIC) do
    Result[I - 1] := Ord(UBS2_MAGIC[I]);
  Result[4] := AFormatVersion;
  Result[5] := UBS2_KDF_PBKDF2_HMAC_SHA256;
  LValue := Cardinal(AIterations);
  Result[6] := Byte(LValue);
  Result[7] := Byte(LValue shr 8);
  Result[8] := Byte(LValue shr 16);
  Result[9] := Byte(LValue shr 24);
  Move(ASalt[0], Result[10], UBS2_SALT_SIZE);
end;

procedure ValidateEnvelope(const AEnvelope: TBytes);
begin
  if Length(AEnvelope) < UBS2_MIN_ENVELOPE_SIZE then
    raise EDecryptionException.CreateFmt(
      'Invalid UBS2 envelope: too short (got %d bytes, minimum %d)',
      [Length(AEnvelope), UBS2_MIN_ENVELOPE_SIZE]);
  if not MagicMatches(AEnvelope) then
    raise EDecryptionException.Create(
      'Invalid UBS2 envelope: magic mismatch');
end;

procedure RaiseKeyMaterial(const AKey: TUBS2KeyMaterial; AForReading: Boolean);
var
  LMessage: string;
begin
  if Length(AKey.MasterSecret) < UBS2_MASTER_SECRET_MIN_SIZE then
    LMessage := Format(
      'UBS2 requires a user secret of at least %d bytes; got %d',
      [UBS2_MASTER_SECRET_MIN_SIZE, Length(AKey.MasterSecret)])
  else if Length(AKey.Binding) = 0 then
    LMessage := 'UBS2 requires a machine binding value; machine identity sources ' +
                'are unavailable and must not be bypassed'
  else
    Exit;

  if AForReading then
    raise EDecryptionException.Create(LMessage)
  else
    raise EEncryptionException.Create(LMessage);
end;

procedure ValidateFormatAndKDF(AFormatVersion, AKdfId: Byte; AIterations: Cardinal);
begin
  if AFormatVersion <> UBS2_FORMAT_VERSION_V2 then
    raise EDecryptionException.CreateFmt(
      'UBS2 format version %d is not readable by this build; run the UBS2 migrator first',
      [AFormatVersion]);
  if AKdfId <> UBS2_KDF_PBKDF2_HMAC_SHA256 then
    raise EDecryptionException.CreateFmt('Unsupported UBS2 KDF id %d', [AKdfId]);
  if (AIterations < UBS2_MIN_ITERATIONS) or (AIterations > UBS2_MAX_ITERATIONS) then
    raise EDecryptionException.CreateFmt(
      'UBS2 PBKDF2 iterations %d outside the accepted range [%d, %d]',
      [AIterations, UBS2_MIN_ITERATIONS, UBS2_MAX_ITERATIONS]);
end;

function DeriveKey(const AMasterSecret, ASalt: TBytes; AIterations: Integer): TBytes;
begin
  Result := TPasswordUtils.PBKDF2(MasterSecretPassphrase(AMasterSecret), ASalt,
    AIterations, UBS2_KEY_SIZE, haSHA256);
end;

{ TUBS2 }

class function TUBS2.IsUBS2(const AData: TBytes): Boolean;
var
  I: Integer;
begin
  Result := Length(AData) >= UBS2_HEADER_SIZE;
  if not Result then
    Exit;
  for I := 1 to Length(UBS2_MAGIC) do
    if AData[I - 1] <> Ord(UBS2_MAGIC[I]) then
      Exit(False);
end;

class function TUBS2.FormatVersionOf(const AEnvelope: TBytes): Byte;
begin
  if not IsUBS2(AEnvelope) then
    raise EDecryptionException.Create('Not a UBS2 envelope: magic mismatch or truncated');
  Result := AEnvelope[4];
end;

class function TUBS2.Protect(const APlaintext: TBytes; const AKey: TUBS2KeyMaterial;
  AIterations: Integer): TBytes;
var
  LSalt, LHeader, LAAD, LKey, LBlob: TBytes;
  LAES: TAESCrypto;
begin
  RaiseKeyMaterial(AKey, False);
  if (AIterations < UBS2_MIN_ITERATIONS) or (AIterations > UBS2_MAX_ITERATIONS) then
    raise EEncryptionException.CreateFmt(
      'UBS2 PBKDF2 iterations %d outside the accepted range [%d, %d]',
      [AIterations, UBS2_MIN_ITERATIONS, UBS2_MAX_ITERATIONS]);

  LSalt := TRandomGenerator.RandomBytes(UBS2_SALT_SIZE);
  LHeader := BuildHeader(UBS2_FORMAT_VERSION_V2, AIterations, LSalt);
  LAAD := BuildAAD(LHeader, AKey.Binding);

  LKey := DeriveKey(AKey.MasterSecret, LSalt, AIterations);
  try
    LAES := TAESCrypto.Create(aes256, aesGCM);
    try
      LAES.SetKey(LKey);
      LBlob := LAES.Encrypt(APlaintext, LAAD);
    finally
      LAES.Free;
    end;
  finally
    SecureClearBytes(LKey);
    SecureClearBytes(LAAD);
  end;

  SetLength(Result, UBS2_HEADER_SIZE + Length(LBlob));
  Move(LHeader[0], Result[0], UBS2_HEADER_SIZE);
  Move(LBlob[0], Result[UBS2_HEADER_SIZE], Length(LBlob));
end;

class function TUBS2.Unprotect(const AEnvelope: TBytes; const AKey: TUBS2KeyMaterial): TBytes;
var
  LIterations: Cardinal;
  LSalt, LHeader, LAAD, LKey, LBlob: TBytes;
  LAES: TAESCrypto;
begin
  ValidateEnvelope(AEnvelope);
  LIterations := ReadCardinalLE(AEnvelope, 6);
  ValidateFormatAndKDF(AEnvelope[4], AEnvelope[5], LIterations);
  RaiseKeyMaterial(AKey, True);

  SetLength(LHeader, UBS2_HEADER_SIZE);
  Move(AEnvelope[0], LHeader[0], UBS2_HEADER_SIZE);
  SetLength(LSalt, UBS2_SALT_SIZE);
  Move(AEnvelope[10], LSalt[0], UBS2_SALT_SIZE);
  LAAD := BuildAAD(LHeader, AKey.Binding);

  SetLength(LBlob, Length(AEnvelope) - UBS2_HEADER_SIZE);
  Move(AEnvelope[UBS2_HEADER_SIZE], LBlob[0], Length(LBlob));

  LKey := DeriveKey(AKey.MasterSecret, LSalt, Integer(LIterations));
  try
    LAES := TAESCrypto.Create(aes256, aesGCM);
    try
      LAES.SetKey(LKey);
      try
        Result := LAES.Decrypt(LBlob, LAAD);
      except
        on E: ECryptoException do
          raise EDecryptionException.Create(
            'UBS2 envelope failed authentication (' + AUTH_FAILURE_HINT + '). ' + E.Message);
      end;
    finally
      LAES.Free;
    end;
  finally
    SecureClearBytes(LKey);
    SecureClearBytes(LAAD);
  end;
end;

class function TUBS2.UnprotectLegacyV1(const AEnvelope: TBytes;
  const ALegacyPassphrase: string): TBytes;
var
  LIterations: Cardinal;
  LSalt, LKey, LBlob: TBytes;
  LAES: TAESCrypto;
begin
  ValidateEnvelope(AEnvelope);
  if AEnvelope[4] <> UBS2_FORMAT_VERSION_V1 then
    raise EDecryptionException.CreateFmt('Not a legacy v1 UBS2 envelope (version %d)',
      [AEnvelope[4]]);
  if AEnvelope[5] <> UBS2_KDF_PBKDF2_HMAC_SHA256 then
    raise EDecryptionException.CreateFmt('Unsupported legacy UBS2 KDF id %d', [AEnvelope[5]]);

  LIterations := ReadCardinalLE(AEnvelope, 6);
  if LIterations < UBS2_MIN_ITERATIONS then
    raise EDecryptionException.CreateFmt(
      'Legacy UBS2 PBKDF2 iterations %d below the %d floor',
      [LIterations, UBS2_MIN_ITERATIONS]);

  SetLength(LSalt, UBS2_SALT_SIZE);
  Move(AEnvelope[10], LSalt[0], UBS2_SALT_SIZE);
  SetLength(LBlob, Length(AEnvelope) - UBS2_HEADER_SIZE);
  Move(AEnvelope[UBS2_HEADER_SIZE], LBlob[0], Length(LBlob));

  // v1 derived its key from the machine fingerprint and authenticated no AAD at all.
  LKey := TPasswordUtils.PBKDF2(ALegacyPassphrase, LSalt, Integer(LIterations),
    UBS2_KEY_SIZE, haSHA256);
  try
    LAES := TAESCrypto.Create(aes256, aesGCM);
    try
      LAES.SetKey(LKey);
      try
        Result := LAES.Decrypt(LBlob);
      except
        on E: ECryptoException do
          raise EDecryptionException.Create(
            'Legacy UBS2 v1 envelope failed authentication: the machine-entropy ' +
            'passphrase is wrong or the record was tampered with. ' + E.Message);
      end;
    finally
      LAES.Free;
    end;
  finally
    SecureClearBytes(LKey);
  end;
end;

end.
