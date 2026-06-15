{ ============================================================================
  Test.DeepBase.Crypto.PBT - Property-based tests for DeepBase.Crypto

  Properties covered (deepbase-round2-fixes):
    Property  7: Crypto encryption is non-deterministic (random salt).
    Property  8: Crypto Encrypt/Decrypt round-trip with random keys + payloads.
    Property  9: TRandomGenerator.RandomInt has no modulo bias.
    Property 10: TRSAVerifier DER parser is length-safe (no buffer overrun).
    Property 11: TPasswordUtils.VerifyPassword validates hash format before
                 comparison (returns False on malformed hash, never AVs).

  Each property runs >= 100 random iterations.

  Note on API signatures:
    - TSimpleCrypto.EncryptBytes/DecryptBytes(AData: TBytes; APassword: string)
      use AES-256-CBC + HMAC-SHA256 + random per-message salt + PBKDF2-100k.
    - TRandomGenerator.RandomInt(AMin, AMax) is the public crypto-grade RNG
      that Property 9 targets.
    - TRSAVerifier.ParseDERPublicKey is private; we exercise it through the
      public LoadPublicKeyDER which returns False on parse errors and sets
      LastError. Property 10 asserts LoadPublicKeyDER(malformed) returns
      False and never raises an unhandled exception.
    - TPasswordUtils.VerifyPassword is the public API for Property 11.
  ============================================================================ }

unit Test.DeepBase.Crypto.PBT;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Math,
  DUnitX.TestFramework,
  DeepBase.Crypto;

type
  [TestFixture]
  TCryptoPropertyTests = class
  strict private
    function RandomBytes(AMinLen, AMaxLen: Integer): TBytes;
    function RandomAsciiPassword(AMinLen, AMaxLen: Integer): string;
    function RandomMixedPayload(AIter: Integer): TBytes;
    function RandomAsciiString(ALen: Integer): string;
  public
    [Setup]
    procedure Setup;

    // Feature: deepbase-round2-fixes, Property 7
    [Test]
    procedure Property7_EncryptIsNonDeterministic;

    // Feature: deepbase-round2-fixes, Property 8
    [Test]
    procedure Property8_EncryptDecryptRoundTrip;

    // Feature: deepbase-round2-fixes, Property 9
    [Test]
    procedure Property9_RandomIntNoModuloBias;

    // Feature: deepbase-round2-fixes, Property 10
    [Test]
    procedure Property10_DERParserLengthSafe;

    // Feature: deepbase-round2-fixes, Property 11
    [Test]
    procedure Property11_VerifyPasswordFormatValidation;
  end;

implementation

{ TCryptoPropertyTests }

procedure TCryptoPropertyTests.Setup;
begin
  Randomize;
end;

function TCryptoPropertyTests.RandomBytes(AMinLen, AMaxLen: Integer): TBytes;
var
  LLen: Integer;
begin
  LLen := AMinLen + Random(Max(1, AMaxLen - AMinLen + 1));
  SetLength(Result, LLen);
  for var I := 0 to LLen - 1 do
    Result[I] := Random(256);
end;

function TCryptoPropertyTests.RandomAsciiString(ALen: Integer): string;
begin
  SetLength(Result, ALen);
  for var I := 1 to ALen do
    Result[I] := Char(Ord('!') + Random(94));  // printable ASCII 33..126
end;

function TCryptoPropertyTests.RandomAsciiPassword(AMinLen, AMaxLen: Integer): string;
var
  LLen: Integer;
begin
  LLen := AMinLen + Random(Max(1, AMaxLen - AMinLen + 1));
  Result := RandomAsciiString(LLen);
end;

function TCryptoPropertyTests.RandomMixedPayload(AIter: Integer): TBytes;
var
  LMode: Integer;
begin
  LMode := AIter mod 5;
  case LMode of
    0:
      // Random binary bytes, varied lengths (1..1024)
      Result := RandomBytes(1, 1024);
    1:
      begin
        // UTF-8 of random Chinese-ish string (multi-byte)
        var LStr := '';
        var LLen := 1 + Random(64);
        for var I := 1 to LLen do
          LStr := LStr + Char($4E00 + Random($1000));  // CJK range
        Result := TEncoding.UTF8.GetBytes(LStr);
      end;
    2:
      begin
        // Bytes containing many embedded zeros
        var LLen := 1 + Random(256);
        SetLength(Result, LLen);
        for var I := 0 to LLen - 1 do
          if Random(3) = 0 then
            Result[I] := 0
          else
            Result[I] := Random(256);
      end;
    3:
      begin
        // Empty-ish (1 byte) edge case
        SetLength(Result, 1);
        Result[0] := Random(256);
      end;
  else
    // Long random buffer (1..4 KiB) to exercise multi-block AES
    Result := RandomBytes(512, 4096);
  end;
end;

// Feature: deepbase-round2-fixes, Property 7: For any plaintext + password,
// EncryptBytes called twice on the same input MUST produce different
// ciphertexts (random salt + IV per call) AND both ciphertexts MUST decrypt
// back to the original plaintext.
procedure TCryptoPropertyTests.Property7_EncryptIsNonDeterministic;
begin
  for var Iter := 1 to 100 do
  begin
    var LPlain := RandomMixedPayload(Iter);
    var LPwd := RandomAsciiPassword(8, 32);

    var LEnc1 := TSimpleCrypto.EncryptBytes(LPlain, LPwd);
    var LEnc2 := TSimpleCrypto.EncryptBytes(LPlain, LPwd);

    // Two encryptions of the same plaintext + password MUST differ.
    Assert.IsTrue(Length(LEnc1) > 0,
      Format('Iter %d: ciphertext 1 should not be empty', [Iter]));
    Assert.IsTrue(Length(LEnc2) > 0,
      Format('Iter %d: ciphertext 2 should not be empty', [Iter]));

    var LSame: Boolean := (Length(LEnc1) = Length(LEnc2));
    if LSame then
    begin
      LSame := True;
      for var I := 0 to High(LEnc1) do
        if LEnc1[I] <> LEnc2[I] then
        begin
          LSame := False;
          Break;
        end;
    end;
    Assert.IsFalse(LSame,
      Format('Iter %d: encrypting same plaintext+password produced ' +
             'identical ciphertext (random salt missing?)', [Iter]));

    // Both ciphertexts must decrypt back to the original plaintext.
    var LDec1 := TSimpleCrypto.DecryptBytes(LEnc1, LPwd);
    var LDec2 := TSimpleCrypto.DecryptBytes(LEnc2, LPwd);
    Assert.AreEqual(Length(LPlain), Length(LDec1),
      Format('Iter %d: decrypted-1 length mismatch', [Iter]));
    Assert.AreEqual(Length(LPlain), Length(LDec2),
      Format('Iter %d: decrypted-2 length mismatch', [Iter]));
    for var I := 0 to High(LPlain) do
    begin
      Assert.AreEqual(Integer(LPlain[I]), Integer(LDec1[I]),
        Format('Iter %d: byte %d mismatch in dec1', [Iter, I]));
      Assert.AreEqual(Integer(LPlain[I]), Integer(LDec2[I]),
        Format('Iter %d: byte %d mismatch in dec2', [Iter, I]));
    end;
  end;
end;

// Feature: deepbase-round2-fixes, Property 8: For any random key + plaintext
// (ASCII / UTF-8 / binary / embedded zeros / multi-block), DecryptBytes is
// the left inverse of EncryptBytes.
procedure TCryptoPropertyTests.Property8_EncryptDecryptRoundTrip;
begin
  for var Iter := 1 to 100 do
  begin
    var LPlain := RandomMixedPayload(Iter);
    // Vary password length per iter: short, medium, long (edge cases)
    var LPwdLen: Integer;
    case Iter mod 3 of
      0: LPwdLen := 1;
      1: LPwdLen := 16;
    else
      LPwdLen := 64;
    end;
    var LPwd := RandomAsciiPassword(LPwdLen, LPwdLen);

    var LCipher := TSimpleCrypto.EncryptBytes(LPlain, LPwd);
    var LDecoded := TSimpleCrypto.DecryptBytes(LCipher, LPwd);

    Assert.AreEqual(Length(LPlain), Length(LDecoded),
      Format('Iter %d: round-trip length mismatch (plain=%d, decoded=%d)',
        [Iter, Length(LPlain), Length(LDecoded)]));
    for var I := 0 to High(LPlain) do
      Assert.AreEqual(Integer(LPlain[I]), Integer(LDecoded[I]),
        Format('Iter %d: round-trip byte %d mismatch', [Iter, I]));
  end;
end;

// Feature: deepbase-round2-fixes, Property 9: TRandomGenerator.RandomInt
// uses rejection sampling to remove modulo bias. Small sample random tests
// cannot prove the tiny 32-bit modulo-bias bound, but they can detect gross
// mistakes such as using a single random byte or a biased modulo source.
//
// The old per-bucket +/-25% assertion was statistically flaky for 100/1000
// buckets. This uses a chi-square smoke threshold plus coverage checks, which
// stays stable under real RNG variance while still failing visibly biased
// implementations.
procedure TCryptoPropertyTests.Property9_RandomIntNoModuloBias;
const
  CSamples = 10000;

  procedure TestRange(AMax: Integer);
  var
    LBuckets: TArray<Integer>;
    LExpected: Double;
    LChiSquare: Double;
    LChiSquareLimit: Double;
    LSeen: Integer;
  begin
    // RandomInt(AMin=0, AMax=AMax-1) draws from {0..AMax-1}
    SetLength(LBuckets, AMax);
    for var I := 0 to CSamples - 1 do
    begin
      var LVal := TRandomGenerator.RandomInt(0, AMax - 1);
      Assert.IsTrue((LVal >= 0) and (LVal < AMax),
        Format('RandomInt(0,%d-1) returned out-of-range value %d',
          [AMax, LVal]));
      Inc(LBuckets[LVal]);
    end;

    LExpected := CSamples / AMax;
    LChiSquare := 0;
    LSeen := 0;
    for var B := 0 to AMax - 1 do
    begin
      if LBuckets[B] > 0 then
        Inc(LSeen);
      LChiSquare := LChiSquare + Sqr(LBuckets[B] - LExpected) / LExpected;
    end;

    LChiSquareLimit := (AMax - 1) + 6 * Sqrt(2 * (AMax - 1));
    Assert.IsTrue(LChiSquare <= LChiSquareLimit,
      Format('Range %d chi-square %.1f exceeds smoke threshold %.1f',
        [AMax, LChiSquare, LChiSquareLimit]));

    if AMax >= 100 then
      Assert.IsTrue(LSeen >= Round(AMax * 0.90),
        Format('Range %d covered only %d/%d buckets', [AMax, LSeen, AMax]));
  end;

begin
  // 17 is prime and not a divisor of 2^32, the classic worst case for
  // modulo bias when implemented naively as Random32 mod Range.
  TestRange(17);
  TestRange(100);
  TestRange(1000);
end;

// Feature: deepbase-round2-fixes, Property 10: For any byte buffer with
// an invalid DER structure (truncated, oversized length field, negative
// length, all-zero, all-0xFF), TRSAVerifier.LoadPublicKeyDER MUST return
// False without raising an unhandled exception (which would indicate a
// buffer overrun or out-of-bounds read).
procedure TCryptoPropertyTests.Property10_DERParserLengthSafe;

  function MakeMalformedDER(AIter: Integer): TBytes;
  var
    LLen: Integer;
  begin
    case AIter mod 8 of
      0:
        begin
          // Truncated: SEQUENCE tag with length saying 200 but only 5 bytes
          SetLength(Result, 5);
          Result[0] := $30; // SEQUENCE
          Result[1] := $81; // long-form length, 1 byte follows
          Result[2] := $C8; // length = 200
          Result[3] := $30;
          Result[4] := $00;
        end;
      1:
        begin
          // Oversized length field (5 bytes >= max we accept)
          SetLength(Result, 50);
          Result[0] := $30;
          Result[1] := $85; // long-form: 5 length bytes (we cap at 4)
          for var I := 2 to 49 do
            Result[I] := Random(256);
        end;
      2:
        begin
          // All-zero buffer (>= 20 bytes to pass min-size guard)
          LLen := 20 + Random(80);
          SetLength(Result, LLen);
          for var I := 0 to LLen - 1 do
            Result[I] := 0;
        end;
      3:
        begin
          // All-0xFF buffer
          LLen := 20 + Random(80);
          SetLength(Result, LLen);
          for var I := 0 to LLen - 1 do
            Result[I] := $FF;
        end;
      4:
        begin
          // Random garbage of varying length (>= 20 to bypass min check)
          LLen := 20 + Random(200);
          SetLength(Result, LLen);
          for var I := 0 to LLen - 1 do
            Result[I] := Random(256);
        end;
      5:
        begin
          // SEQUENCE with length larger than buffer (declared 1024,
          // actual 30 bytes -> ParseDER must reject, not segfault)
          SetLength(Result, 30);
          Result[0] := $30;
          Result[1] := $82; // long-form: 2 length bytes
          Result[2] := $04; // 0x0400 = 1024
          Result[3] := $00;
          for var I := 4 to 29 do
            Result[I] := Random(256);
        end;
      6:
        begin
          // Truncated mid-tag (just under min size)
          LLen := 1 + Random(19);
          SetLength(Result, LLen);
          for var I := 0 to LLen - 1 do
            Result[I] := Random(256);
        end;
    else
      begin
        // Empty buffer
        SetLength(Result, 0);
      end;
    end;
  end;

begin
  for var Iter := 1 to 100 do
  begin
    var LDER := MakeMalformedDER(Iter);
    var LVerifier := TRSAVerifier.Create;
    try
      var LResult: Boolean := True;
      try
        // Must not raise an unhandled exception or segfault on malformed DER.
        // Implementation should set LastError and return False.
        LResult := LVerifier.LoadPublicKeyDER(LDER);
      except
        on E: Exception do
          Assert.Fail(
            Format('Iter %d: LoadPublicKeyDER raised %s: %s on malformed ' +
                   'input of length %d (parser must catch internally)',
              [Iter, E.ClassName, E.Message, Length(LDER)]));
      end;
      Assert.IsFalse(LResult,
        Format('Iter %d: LoadPublicKeyDER unexpectedly accepted ' +
               'malformed DER of length %d', [Iter, Length(LDER)]));
      Assert.IsFalse(LVerifier.IsKeyLoaded,
        Format('Iter %d: IsKeyLoaded should be False after rejected DER',
          [Iter]));
    finally
      LVerifier.Free;
    end;
  end;
end;

// Feature: deepbase-round2-fixes, Property 11: TPasswordUtils.VerifyPassword
// MUST validate the hash string format before any comparison. For any
// malformed hash string (empty, missing prefix, wrong segment count,
// non-base64, non-numeric iteration field, out-of-range algorithm enum,
// truncated), VerifyPassword MUST return False without raising an
// unhandled exception. Control case: a freshly produced legitimate hash
// MUST verify True for the original password.
procedure TCryptoPropertyTests.Property11_VerifyPasswordFormatValidation;

  function MakeMalformedHash(AIter: Integer): string;
  begin
    case AIter mod 10 of
      0: Result := '';
      1: Result := 'plaintext-no-prefix';
      2: Result := '$pbkdf2$'; // truncated
      3: Result := '$pbkdf2$10000'; // missing algo+salt+hash
      4: Result := '$pbkdf2$abc$0$AAAA$BBBB'; // non-numeric iterations
      5: Result := '$pbkdf2$10000$999$AAAA$BBBB'; // algo enum out of range
      6: Result := '$pbkdf2$-1$0$AAAA$BBBB'; // negative iterations
      7: Result := '$pbkdf2$10000$0$$BBBB'; // empty salt
      8: Result := '$pbkdf2$10000$0$AAAA$'; // empty hash
    else
      // Random non-base64 chars in salt/hash slots
      Result := '$pbkdf2$10000$0$' + StringOfChar('!', 4 + Random(8)) +
                '$' + StringOfChar('@', 4 + Random(8));
    end;
  end;

begin
  // Control: a real hash with the right password should verify True.
  var LRealPwd := 'TestPassword123!';
  var LRealHash := TPasswordUtils.HashPassword(LRealPwd);
  Assert.IsTrue(TPasswordUtils.VerifyPassword(LRealPwd, LRealHash),
    'Control: legitimate hash failed to verify for original password');
  Assert.IsFalse(TPasswordUtils.VerifyPassword('WrongPassword', LRealHash),
    'Control: legitimate hash unexpectedly verified wrong password');

  // Property: malformed hashes never raise and never return True.
  for var Iter := 1 to 100 do
  begin
    var LBad := MakeMalformedHash(Iter);
    var LResult: Boolean := True;
    try
      LResult := TPasswordUtils.VerifyPassword('AnyPassword', LBad);
    except
      on E: Exception do
        Assert.Fail(
          Format('Iter %d: VerifyPassword raised %s: %s on malformed hash ' +
                 '"%s" (must return False instead)',
            [Iter, E.ClassName, E.Message, LBad]));
    end;
    Assert.IsFalse(LResult,
      Format('Iter %d: VerifyPassword returned True for malformed hash "%s"',
        [Iter, LBad]));
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TCryptoPropertyTests);

end.
