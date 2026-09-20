{ ============================================================================
  Test.DeepBase.Security.UBS2 - Unit tests for the UBS2 envelope (WO Top20 #05)

  Runs on every platform: the codec is built on TAESCrypto/TPasswordUtils, which
  resolve to BCrypt on Win64 and OpenSSL on macOS/Linux. The attack cases below
  (different user secret, foreign machine binding, downgraded KDF cost, truncated
  record, legacy v1 record) are therefore exercised for real, not simulated.

  Test Coverage:
    - Seal/open round trip and header fields
    - Cross-user replay: same machine binding, different user secret
    - Binding (AAD) tampering: fails closed
    - KDF cost bounds and KDF id policy
    - Envelope truncation
    - v1 records are refused by the read path and migrate with the migrator
  ============================================================================ }

unit Test.DeepBase.Security.UBS2;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.NetEncoding,
  DeepBase.SecureMemory,
  DeepBase.Security.UBS2,
  DeepBase.Security.UBS2.Migration,
  DeepBase.Crypto.AES,
  DeepBase.Crypto.Hash;

type
  [TestFixture]
  TTestUBS2Envelope = class
  private
    FSecretOwner: TBytes;
    FSecretOtherUser: TBytes;
    FBinding: TBytes;
    FBindingOtherMachine: TBytes;
    function OwnerKey: TUBS2KeyMaterial;
    function OtherUserKey: TUBS2KeyMaterial;
    function OtherMachineKey: TUBS2KeyMaterial;
    function Seal(const APlain: TBytes; const AKey: TUBS2KeyMaterial): TBytes;
  public
    [Setup]
    procedure Setup;

    [Test]
    procedure Test_ProtectUnprotect_RoundTrip;
    [Test]
    procedure Test_Protect_SealsCurrentVersionWithBoundedIterations;
    [Test]
    procedure Test_Unprotect_OtherUserSecret_Raises;
    [Test]
    procedure Test_Unprotect_ForeignMachineBinding_Raises;
    [Test]
    procedure Test_Protect_IterationsOutOfRange_Raises;
    [Test]
    procedure Test_Unprotect_IterationsBelowFloor_Raises;
    [Test]
    procedure Test_Unprotect_IterationsAboveCeiling_Raises;
    [Test]
    procedure Test_Unprotect_UnsupportedKDFId_Raises;
    [Test]
    procedure Test_Unprotect_TruncatedEnvelope_Raises;
    [Test]
    procedure Test_Unprotect_ForeignFormatVersion_RaisesMigrationHint;
    [Test]
    procedure Test_Unprotect_MissingUserSecret_Raises;
    [Test]
    procedure Test_Reencrypt_LegacyV1_BecomesReadableV2;
    [Test]
    procedure Test_Reencrypt_WrongLegacyPassphrase_LeavesRecordUntouched;
    [Test]
    procedure Test_NeedsMigration_ClassifiesRecords;
    [Test]
    procedure Test_LegacyPassphrase_Formulas;
  end;

implementation

uses
  DeepBase.Exceptions;

const
  // The floor keeps each derivation fast enough for a unit test while staying
  // inside the accepted KDF cost range.
  TEST_ITERATIONS = UBS2_MIN_ITERATIONS;
  LEGACY_ITERATIONS = 100000;
  LEGACY_PASSPHRASE = 'b1a7c9d0e1f23456:alice:Linux:DeepBase';

procedure FillPattern(out ABytes: TBytes; ALength: Integer; APattern: Byte);
begin
  SetLength(ABytes, ALength);
  if ALength > 0 then
    FillChar(ABytes[0], ALength, APattern);
end;

{ TTestUBS2Envelope }

procedure TTestUBS2Envelope.Setup;
begin
  FillPattern(FSecretOwner, UBS2_MASTER_SECRET_SIZE, $A1);
  FillPattern(FSecretOtherUser, UBS2_MASTER_SECRET_SIZE, $B2);
  FBinding := TEncoding.UTF8.GetBytes('v1|machine_guid=afff3ce9|volume_serial=8EB53A74');
  FBindingOtherMachine := TEncoding.UTF8.GetBytes('v1|machine_guid=00000000|volume_serial=8EB53A74');
end;

function TTestUBS2Envelope.OwnerKey: TUBS2KeyMaterial;
begin
  Result.MasterSecret := Copy(FSecretOwner);
  Result.Binding := Copy(FBinding);
end;

function TTestUBS2Envelope.OtherUserKey: TUBS2KeyMaterial;
begin
  Result.MasterSecret := Copy(FSecretOtherUser);
  Result.Binding := Copy(FBinding);
end;

function TTestUBS2Envelope.OtherMachineKey: TUBS2KeyMaterial;
begin
  Result.MasterSecret := Copy(FSecretOwner);
  Result.Binding := Copy(FBindingOtherMachine);
end;

function TTestUBS2Envelope.Seal(const APlain: TBytes;
  const AKey: TUBS2KeyMaterial): TBytes;
begin
  Result := TUBS2.Protect(APlain, AKey, TEST_ITERATIONS);
end;

procedure TTestUBS2Envelope.Test_ProtectUnprotect_RoundTrip;
var
  Plain, Envelope, Opened: TBytes;
begin
  Plain := TEncoding.UTF8.GetBytes('postgres://user:s3cr3t@db:5432/app');
  Envelope := Seal(Plain, OwnerKey);
  Opened := TUBS2.Unprotect(Envelope, OwnerKey);
  try
    Assert.AreEqual(TEncoding.UTF8.GetString(Plain), TEncoding.UTF8.GetString(Opened));
  finally
    SecureClearBytes(Opened);
  end;
end;

procedure TTestUBS2Envelope.Test_Protect_SealsCurrentVersionWithBoundedIterations;
var
  Plain, Envelope: TBytes;
begin
  Plain := TEncoding.UTF8.GetBytes('value');
  Envelope := Seal(Plain, OwnerKey);
  try
    Assert.IsTrue(TUBS2.IsUBS2(Envelope));
    Assert.AreEqual(Byte(UBS2_FORMAT_VERSION_V2), TUBS2.FormatVersionOf(Envelope));
    Assert.AreEqual(Byte(UBS2_KDF_PBKDF2_HMAC_SHA256), Envelope[5]);
    Assert.IsTrue(Integer(Cardinal(Envelope[6]) or (Cardinal(Envelope[7]) shl 8) or
      (Cardinal(Envelope[8]) shl 16) or (Cardinal(Envelope[9]) shl 24)) >= UBS2_MIN_ITERATIONS);
    // A fresh envelope for the same plaintext never repeats: salt and nonce are random.
    // Compared as base64 because ciphertext is not valid UTF-8 text.
    Assert.AreNotEqual(TNetEncoding.Base64.EncodeBytesToString(Envelope),
      TNetEncoding.Base64.EncodeBytesToString(Seal(Plain, OwnerKey)));
  finally
    SecureClearBytes(Envelope);
  end;
end;

procedure TTestUBS2Envelope.Test_Unprotect_OtherUserSecret_Raises;
var
  Plain, Envelope, Opened: TBytes;
begin
  Plain := TEncoding.UTF8.GetBytes('top-secret-token');
  Envelope := Seal(Plain, OwnerKey);
  try
    // Positive control: the owner can always open it.
    Opened := TUBS2.Unprotect(Envelope, OwnerKey);
    SecureClearBytes(Opened);
    // Attack: second local user, same machine, no knowledge of the owner secret.
    Assert.WillRaise(
      procedure
      begin
        TUBS2.Unprotect(Envelope, OtherUserKey);
      end, EDecryptionException);
  finally
    SecureClearBytes(Envelope);
  end;
end;

procedure TTestUBS2Envelope.Test_Unprotect_ForeignMachineBinding_Raises;
var
  Plain, Envelope: TBytes;
begin
  Plain := TEncoding.UTF8.GetBytes('top-secret-token');
  Envelope := Seal(Plain, OwnerKey);
  try
    // The envelope was copied to a machine whose identity differs; the binding is
    // authenticated data, so the record must not open even with the right secret.
    Assert.WillRaise(
      procedure
      begin
        TUBS2.Unprotect(Envelope, OtherMachineKey);
      end, EDecryptionException);
  finally
    SecureClearBytes(Envelope);
  end;
end;

procedure TTestUBS2Envelope.Test_Protect_IterationsOutOfRange_Raises;
var
  Plain: TBytes;
begin
  Plain := TEncoding.UTF8.GetBytes('value');
  Assert.WillRaise(
    procedure
    begin
      TUBS2.Protect(Plain, OwnerKey, UBS2_MIN_ITERATIONS - 1);
    end, EEncryptionException);
  Assert.WillRaise(
    procedure
    begin
      TUBS2.Protect(Plain, OwnerKey, UBS2_MAX_ITERATIONS + 1);
    end, EEncryptionException);
end;

procedure TTestUBS2Envelope.Test_Unprotect_IterationsBelowFloor_Raises;
var
  Plain, Envelope: TBytes;
begin
  Plain := TEncoding.UTF8.GetBytes('value');
  Envelope := Seal(Plain, OwnerKey);
  try
    Envelope[6] := Byte(50_000);
    Envelope[7] := Byte(50_000 shr 8);
    Envelope[8] := Byte(50_000 shr 16);
    Envelope[9] := Byte(50_000 shr 24);
    Assert.WillRaise(
      procedure
      begin
        TUBS2.Unprotect(Envelope, OwnerKey);
      end, EDecryptionException);
  finally
    SecureClearBytes(Envelope);
  end;
end;

procedure TTestUBS2Envelope.Test_Unprotect_IterationsAboveCeiling_Raises;
var
  Plain, Envelope: TBytes;
  LValue: Cardinal;
begin
  Plain := TEncoding.UTF8.GetBytes('value');
  Envelope := Seal(Plain, OwnerKey);
  try
    LValue := Cardinal(UBS2_MAX_ITERATIONS) + 1;
    Envelope[6] := Byte(LValue);
    Envelope[7] := Byte(LValue shr 8);
    Envelope[8] := Byte(LValue shr 16);
    Envelope[9] := Byte(LValue shr 24);
    Assert.WillRaise(
      procedure
      begin
        TUBS2.Unprotect(Envelope, OwnerKey);
      end, EDecryptionException);
  finally
    SecureClearBytes(Envelope);
  end;
end;

procedure TTestUBS2Envelope.Test_Unprotect_UnsupportedKDFId_Raises;
var
  Plain, Envelope: TBytes;
begin
  Plain := TEncoding.UTF8.GetBytes('value');
  Envelope := Seal(Plain, OwnerKey);
  try
    Envelope[5] := $7F;
    Assert.WillRaise(
      procedure
      begin
        TUBS2.Unprotect(Envelope, OwnerKey);
      end, EDecryptionException);
  finally
    SecureClearBytes(Envelope);
  end;
end;

procedure TTestUBS2Envelope.Test_Unprotect_TruncatedEnvelope_Raises;
var
  Plain, Envelope, Truncated: TBytes;
begin
  Plain := TEncoding.UTF8.GetBytes('value-that-is-long-enough-to-truncate');
  Envelope := Seal(Plain, OwnerKey);
  try
    SetLength(Truncated, Length(Envelope) div 2);
    Move(Envelope[0], Truncated[0], Length(Truncated));
    Assert.WillRaise(
      procedure
      begin
        TUBS2.Unprotect(Truncated, OwnerKey);
      end, EDecryptionException);
  finally
    SecureClearBytes(Envelope);
  end;
end;

procedure TTestUBS2Envelope.Test_Unprotect_ForeignFormatVersion_RaisesMigrationHint;
var
  Plain, Envelope: TBytes;
begin
  Plain := TEncoding.UTF8.GetBytes('value');
  Envelope := Seal(Plain, OwnerKey);
  try
    Envelope[4] := UBS2_FORMAT_VERSION_V1;
    try
      TUBS2.Unprotect(Envelope, OwnerKey);
      Assert.Fail('A v1 record must not be readable by the production path.');
    except
      on E: EDecryptionException do
        Assert.Contains(E.Message, 'migrator');
    end;
  finally
    SecureClearBytes(Envelope);
  end;
end;

procedure TTestUBS2Envelope.Test_Unprotect_MissingUserSecret_Raises;
var
  Plain, Envelope: TBytes;
  Key: TUBS2KeyMaterial;
begin
  Plain := TEncoding.UTF8.GetBytes('value');
  Envelope := Seal(Plain, OwnerKey);
  try
    Key.MasterSecret := Copy(FSecretOwner);
    Key.Binding := Copy(FBinding);
    SecureClearBytes(Key.MasterSecret);
    Assert.WillRaise(
      procedure
      begin
        TUBS2.Unprotect(Envelope, Key);
      end, EDecryptionException);

    Key.MasterSecret := Copy(FSecretOwner);
    SecureClearBytes(Key.Binding);
    Assert.WillRaise(
      procedure
      begin
        TUBS2.Unprotect(Envelope, Key);
      end, EDecryptionException);
  finally
    SecureClearBytes(Key.Binding);
    SecureClearBytes(Envelope);
  end;
end;

// Reproduces the pre-v2 wire format byte for byte: 26-byte header (magic, version 1,
// PBKDF2-SHA256, iterations, salt) followed by the GCM blob nonce||cipher||tag with
// no additional authenticated data, keyed from the machine-entropy passphrase.
function BuildLegacyV1Envelope(const APlain: TBytes;
  const ALegacyPassphrase: string): TBytes;
var
  Salt, Key, Blob: TBytes;
  AES: TAESCrypto;
begin
  SetLength(Salt, UBS2_SALT_SIZE);
  FillChar(Salt[0], UBS2_SALT_SIZE, $5A);
  Key := TPasswordUtils.PBKDF2(ALegacyPassphrase, Salt, LEGACY_ITERATIONS,
    UBS2_KEY_SIZE, haSHA256);
  try
    AES := TAESCrypto.Create(aes256, aesGCM);
    try
      AES.SetKey(Key);
      Blob := AES.Encrypt(APlain);
    finally
      AES.Free;
    end;
  finally
    SecureClearBytes(Key);
  end;

  SetLength(Result, UBS2_HEADER_SIZE + Length(Blob));
  Result[0] := Ord('U');
  Result[1] := Ord('B');
  Result[2] := Ord('S');
  Result[3] := Ord('2');
  Result[4] := UBS2_FORMAT_VERSION_V1;
  Result[5] := UBS2_KDF_PBKDF2_HMAC_SHA256;
  Result[6] := Byte(LEGACY_ITERATIONS);
  Result[7] := Byte(LEGACY_ITERATIONS shr 8);
  Result[8] := Byte(LEGACY_ITERATIONS shr 16);
  Result[9] := Byte(LEGACY_ITERATIONS shr 24);
  Move(Salt[0], Result[10], UBS2_SALT_SIZE);
  Move(Blob[0], Result[UBS2_HEADER_SIZE], Length(Blob));
end;

procedure TTestUBS2Envelope.Test_Reencrypt_LegacyV1_BecomesReadableV2;
var
  Plain, Legacy, Migrated, Opened: TBytes;
begin
  Plain := TEncoding.UTF8.GetBytes('historical-credential-value');

  Legacy := BuildLegacyV1Envelope(Plain, LEGACY_PASSPHRASE);
  try
    Assert.IsTrue(TUBS2Migrator.NeedsMigration(Legacy));
    Assert.AreEqual(Byte(UBS2_FORMAT_VERSION_V1), TUBS2.FormatVersionOf(Legacy));
    // The record is unreadable through the normal path first.
    Assert.WillRaise(
      procedure
      begin
        TUBS2.Unprotect(Legacy, OwnerKey);
      end, EDecryptionException);

    Migrated := TUBS2Migrator.Reencrypt(Legacy, LEGACY_PASSPHRASE, OwnerKey);
    try
      Assert.AreEqual(Byte(UBS2_FORMAT_VERSION_V2), TUBS2.FormatVersionOf(Migrated));
      Assert.IsFalse(TUBS2Migrator.NeedsMigration(Migrated));
      Opened := TUBS2.Unprotect(Migrated, OwnerKey);
      try
        Assert.AreEqual(TEncoding.UTF8.GetString(Plain), TEncoding.UTF8.GetString(Opened));
      finally
        SecureClearBytes(Opened);
      end;
    finally
      SecureClearBytes(Migrated);
    end;
  finally
    SecureClearBytes(Legacy);
  end;
end;

procedure TTestUBS2Envelope.Test_Reencrypt_WrongLegacyPassphrase_LeavesRecordUntouched;
var
  Plain, Legacy, Migrated: TBytes;
begin
  Plain := TEncoding.UTF8.GetBytes('historical-credential-value');
  Legacy := BuildLegacyV1Envelope(Plain, LEGACY_PASSPHRASE);
  try
    Assert.WillRaise(
      procedure
      begin
        Migrated := TUBS2Migrator.Reencrypt(Legacy,
          'deadbeef:bob:Linux:DeepBase', OwnerKey);
        SecureClearBytes(Migrated);
      end, EDecryptionException);
    // Nothing was rewritten: the caller still holds the original v1 bytes.
    Assert.IsTrue(TUBS2Migrator.NeedsMigration(Legacy));
  finally
    SecureClearBytes(Legacy);
  end;
end;

procedure TTestUBS2Envelope.Test_NeedsMigration_ClassifiesRecords;
var
  Plain, V1, V2, Other: TBytes;
begin
  Plain := TEncoding.UTF8.GetBytes('value');
  V1 := BuildLegacyV1Envelope(Plain, LEGACY_PASSPHRASE);
  V2 := Seal(Plain, OwnerKey);
  SetLength(Other, 64);
  FillChar(Other[0], Length(Other), 0);
  Other[0] := Ord('U');
  Other[1] := Ord('B');
  Other[2] := Ord('S');
  Other[3] := Ord('1');
  try
    Assert.IsTrue(TUBS2Migrator.NeedsMigration(V1));
    Assert.IsFalse(TUBS2Migrator.NeedsMigration(V2));
    Assert.IsFalse(TUBS2Migrator.NeedsMigration(Other));
  finally
    SecureClearBytes(V1);
    SecureClearBytes(V2);
    SetLength(Other, 0);
  end;
end;

procedure TTestUBS2Envelope.Test_LegacyPassphrase_Formulas;
begin
  Assert.AreEqual('b1a7c9d0e1f23456:alice:Linux:DeepBase',
    TUBS2Migrator.LegacyPassphraseLinux('b1a7c9d0e1f23456', 'alice'));
  Assert.AreEqual('/home/alice:alice:macOS:DeepBase',
    TUBS2Migrator.LegacyPassphraseMacOS('/home/alice', 'alice'));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestUBS2Envelope);

end.
