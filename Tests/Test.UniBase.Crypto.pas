/// <summary>
/// Unit tests for UniBase.Crypto module
/// Tests: THashUtils, TEncodingUtils, TRandomGenerator, TPasswordUtils,
///        TAESCrypto, TSimpleCrypto, TCRCUtils, TCrypto
/// </summary>
unit Test.UniBase.Crypto;

interface

uses
  System.SysUtils,
  System.Classes,
  DUnitX.TestFramework,
  UniBase.Crypto,
  UniBase.Services.Crypto;

type
  /// <summary>
  /// Tests for THashUtils
  /// </summary>
  [TestFixture]
  THashUtilsTests = class
  public
    [Test]
    procedure Test_HashBytes_SHA256;
    [Test]
    procedure Test_HashString_SHA256;
    [Test]
    procedure Test_HashToHex_Bytes;
    [Test]
    procedure Test_HashToHex_String;
    [Test]
    procedure Test_MD5_Bytes;
    [Test]
    procedure Test_MD5_String;
    [Test]
    procedure Test_SHA1_Bytes;
    [Test]
    procedure Test_SHA1_String;
    [Test]
    procedure Test_SHA256_Bytes;
    [Test]
    procedure Test_SHA256_String;
    [Test]
    procedure Test_SHA512_Bytes;
    [Test]
    procedure Test_SHA512_String;
    [Test]
    procedure Test_HMAC_Bytes;
    [Test]
    procedure Test_HMAC_String;
    [Test]
    procedure Test_DifferentAlgorithms_DifferentLengths;
    [Test]
    procedure Test_SameInput_SameOutput;
    [Test]
    procedure Test_DifferentInput_DifferentOutput;
  end;

  /// <summary>
  /// Tests for TEncodingUtils
  /// </summary>
  [TestFixture]
  TEncodingUtilsTests = class
  public
    [Test]
    procedure Test_Base64Encode_Bytes;
    [Test]
    procedure Test_Base64Encode_String;
    [Test]
    procedure Test_Base64Decode;
    [Test]
    procedure Test_Base64DecodeString;
    [Test]
    procedure Test_Base64_RoundTrip;
    [Test]
    procedure Test_Base64UrlEncode;
    [Test]
    procedure Test_Base64UrlDecode;
    [Test]
    procedure Test_Base64Url_RoundTrip;
    [Test]
    procedure Test_HexEncode_Bytes;
    [Test]
    procedure Test_HexEncode_String;
    [Test]
    procedure Test_HexDecode;
    [Test]
    procedure Test_HexDecodeString;
    [Test]
    procedure Test_Hex_RoundTrip;
    [Test]
    procedure Test_UrlEncode;
    [Test]
    procedure Test_UrlDecode;
    [Test]
    procedure Test_Url_RoundTrip;
    [Test]
    procedure Test_HtmlEncode;
    [Test]
    procedure Test_HtmlDecode;
    [Test]
    procedure Test_Html_RoundTrip;
  end;

  /// <summary>
  /// Tests for TRandomGenerator
  /// </summary>
  [TestFixture]
  TRandomGeneratorTests = class
  public
    [Test]
    procedure Test_RandomBytes_Length;
    [Test]
    procedure Test_RandomBytes_NotAllZeros;
    [Test]
    procedure Test_RandomString_Length;
    [Test]
    procedure Test_RandomString_Alphanumeric;
    [Test]
    procedure Test_RandomHex_Length;
    [Test]
    procedure Test_RandomHex_ValidChars;
    [Test]
    procedure Test_RandomInt_InRange;
    [Test]
    procedure Test_NewGuid_Format;
    [Test]
    procedure Test_NewGuidNoDashes_Format;
    [Test]
    procedure Test_SecureToken_Length;
    [Test]
    procedure Test_GenerateOTP_Digits;
    [Test]
    procedure Test_GenerateOTP_OnlyDigits;
    [Test]
    procedure Test_Uniqueness;
  end;

  /// <summary>
  /// Tests for TPasswordUtils
  /// </summary>
  [TestFixture]
  TPasswordUtilsTests = class
  public
    [Test]
    procedure Test_HashPassword;
    [Test]
    procedure Test_VerifyPassword_Correct;
    [Test]
    procedure Test_VerifyPassword_Incorrect;
    [Test]
    procedure Test_GenerateSalt_Length;
    [Test]
    procedure Test_GenerateSalt_Unique;
    [Test]
    procedure Test_PBKDF2;
    [Test]
    procedure Test_PBKDF2_DifferentSalts;
    [Test]
    procedure Test_PBKDF2_DifferentIterations;
    [Test]
    procedure Test_CheckStrength_Weak;
    [Test]
    procedure Test_CheckStrength_Medium;
    [Test]
    procedure Test_CheckStrength_Strong;
    [Test]
    procedure Test_GeneratePassword_Length;
    [Test]
    procedure Test_GeneratePassword_WithUppercase;
    [Test]
    procedure Test_GeneratePassword_WithDigits;
    [Test]
    procedure Test_GeneratePassword_WithSpecial;
    [Test]
    procedure Test_PasswordHashOptions_Default;
  end;

  /// <summary>
  /// Tests for TAESCrypto
  /// </summary>
  [TestFixture]
  TAESCryptoTests = class
  private
    FAES: TAESCrypto;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Create;
    [Test]
    procedure Test_GenerateKey;
    [Test]
    procedure Test_GenerateIV;
    [Test]
    procedure Test_SetKey;
    [Test]
    procedure Test_SetKeyFromPassword;
    [Test]
    procedure Test_Encrypt_Decrypt_Bytes;
    [Test]
    procedure Test_EncryptString_DecryptString;
    [Test]
    procedure Test_Encrypt_Decrypt_RoundTrip;
    [Test]
    procedure Test_KeySizes;
    [Test]
    procedure Test_DifferentKeys_DifferentResults;
  end;

  /// <summary>
  /// Tests for TSimpleCrypto
  /// </summary>
  [TestFixture]
  TSimpleCryptoTests = class
  public
    [Test]
    procedure Test_Encrypt_Decrypt_String;
    [Test]
    procedure Test_Encrypt_Decrypt_Bytes;
    [Test]
    procedure Test_RoundTrip;
    [Test]
    procedure Test_DifferentPasswords_DifferentResults;
    [Test]
    procedure Test_WrongPassword_Fails;
  end;

  /// <summary>
  /// Tests for TCryptoServiceImpl IV-aware APIs
  /// </summary>
  [TestFixture]
  TCryptoServiceImplTests = class
  public
    [Test]
    procedure Test_EncryptWithIV_DecryptWithIV_RoundTrip;
    [Test]
    procedure Test_EncryptWithIV_DifferentIV_ProducesDifferentCiphertext;
    [Test]
    procedure Test_EncryptWithIV_InvalidIVLength_Raises;
  end;

  /// <summary>
  /// Tests for TCRCUtils
  /// </summary>
  [TestFixture]
  TCRCUtilsTests = class
  public
    [Test]
    procedure Test_CRC32_Bytes;
    [Test]
    procedure Test_CRC32_String;
    [Test]
    procedure Test_CRC32_Deterministic;
    [Test]
    procedure Test_CRC32_DifferentInput_DifferentOutput;
    [Test]
    procedure Test_Adler32_Bytes;
    [Test]
    procedure Test_Adler32_String;
  end;

{$IFDEF MSWINDOWS}
  /// <summary>
  /// Tests for TRSAVerifier (Windows only)
  /// </summary>
  [TestFixture]
  TRSAVerifierTests = class
  private
    // Test RSA-2048 key pair (for testing only - DO NOT use in production!)
    const TEST_PUBLIC_KEY_PEM =
      '-----BEGIN PUBLIC KEY-----' + sLineBreak +
      'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA0Z3VS5JJcds3xfn/ygWyf8' + sLineBreak +
      'SgPT3bSOPTwlDpn8OwWAk1K0fqf2M/4xOBG8wfyQq8J3hkqD3/bFZhs3mRZmLnq6Ng' + sLineBreak +
      'dS7GKBA8UqwN0WKRH5BMH3kq+6UvKTfpSRLy/rvU0cPoK8RiVnwDd8N3mMHZPiUmBu' + sLineBreak +
      'JjHt2hA7M8O7z0YKBN5D1hLBkm7a5L7X4Q+ZMD0pwTTfWxOmRV9n7htcF1X5h3c4KT' + sLineBreak +
      'y4GWDdSp7J2D54U0dCTQwwP4DA/KAyE9zF8VKj51C5LREP5h7k6Eb5UiRMZ9S5dG4e' + sLineBreak +
      '14AO8/0DWAF05g8LlFWbOB4hwvO8h/2E6VCGvpQIDAQAB' + sLineBreak +
      '-----END PUBLIC KEY-----';
      
    // Known test data and signature for verification
    const TEST_DATA = 'Hello, RSA Signature Test!';
    // This signature was created with the corresponding private key
    const TEST_SIGNATURE_BASE64 = 
      'invalid_test_signature_placeholder'; // Will be updated with real test
  public
    [Test]
    procedure Test_Create;
    [Test]
    procedure Test_LoadPublicKeyPEM_Valid;
    [Test]
    procedure Test_LoadPublicKeyPEM_Invalid;
    [Test]
    procedure Test_LoadPublicKeyPEM_Empty;
    [Test]
    procedure Test_VerifySignature_KeyNotLoaded;
    [Test]
    procedure Test_VerifySignature_EmptySignature;
    [Test]
    procedure Test_IsKeyLoaded_Initial;
    [Test]
    procedure Test_LastError_AfterFailure;
  end;
{$ENDIF}

  /// <summary>
  /// Tests for TCrypto helper
  /// </summary>
  [TestFixture]
  TCryptoHelperTests = class
  public
    [Test]
    procedure Test_MD5;
    [Test]
    procedure Test_SHA1;
    [Test]
    procedure Test_SHA256;
    [Test]
    procedure Test_SHA512;
    [Test]
    procedure Test_Base64Encode;
    [Test]
    procedure Test_Base64Decode;
    [Test]
    procedure Test_HexEncode;
    [Test]
    procedure Test_HexDecode;
    [Test]
    procedure Test_HashPassword;
    [Test]
    procedure Test_VerifyPassword;
    [Test]
    procedure Test_Encrypt_Decrypt;
    [Test]
    procedure Test_RandomString;
    [Test]
    procedure Test_RandomBytes;
    [Test]
    procedure Test_NewGuid;
  end;

implementation

// ============================================================================
// THashUtilsTests
// ============================================================================

procedure THashUtilsTests.Test_HashBytes_SHA256;
var
  Data, Hash: TBytes;
begin
  Data := TEncoding.UTF8.GetBytes('test');
  Hash := THashUtils.HashBytes(Data, haSHA256);
  Assert.AreEqual(Integer(32), Integer(Length(Hash))); // SHA256 = 32 bytes
end;

procedure THashUtilsTests.Test_HashString_SHA256;
var
  Hash: TBytes;
begin
  Hash := THashUtils.HashString('test', haSHA256);
  Assert.AreEqual(Integer(32), Integer(Length(Hash)));
end;

procedure THashUtilsTests.Test_HashToHex_Bytes;
var
  Data: TBytes;
  Hex: string;
begin
  Data := TEncoding.UTF8.GetBytes('test');
  Hex := THashUtils.HashToHex(Data, haSHA256);
  Assert.AreEqual(Integer(64), Integer(Length(Hex))); // 32 bytes * 2 hex chars
end;

procedure THashUtilsTests.Test_HashToHex_String;
var
  Hex: string;
begin
  Hex := THashUtils.HashToHex('test', haSHA256);
  Assert.AreEqual(Integer(64), Integer(Length(Hex)));
end;

procedure THashUtilsTests.Test_MD5_Bytes;
var
  Data, Hash: TBytes;
begin
  Data := TEncoding.UTF8.GetBytes('test');
  Hash := THashUtils.MD5(Data);
  Assert.AreEqual(Integer(16), Integer(Length(Hash))); // MD5 = 16 bytes
end;

procedure THashUtilsTests.Test_MD5_String;
var
  Hash: string;
begin
  Hash := THashUtils.MD5('test');
  Assert.AreEqual(Integer(32), Integer(Length(Hash))); // 16 bytes as hex = 32 chars
end;

procedure THashUtilsTests.Test_SHA1_Bytes;
var
  Data, Hash: TBytes;
begin
  Data := TEncoding.UTF8.GetBytes('test');
  Hash := THashUtils.SHA1(Data);
  Assert.AreEqual(Integer(20), Integer(Length(Hash))); // SHA1 = 20 bytes
end;

procedure THashUtilsTests.Test_SHA1_String;
var
  Hash: string;
begin
  Hash := THashUtils.SHA1('test');
  Assert.AreEqual(Integer(40), Integer(Length(Hash))); // 20 bytes as hex
end;

procedure THashUtilsTests.Test_SHA256_Bytes;
var
  Data, Hash: TBytes;
begin
  Data := TEncoding.UTF8.GetBytes('test');
  Hash := THashUtils.SHA256(Data);
  Assert.AreEqual(Integer(32), Integer(Length(Hash)));
end;

procedure THashUtilsTests.Test_SHA256_String;
var
  Hash: string;
begin
  Hash := THashUtils.SHA256('test');
  Assert.AreEqual(Integer(64), Integer(Length(Hash)));
end;

procedure THashUtilsTests.Test_SHA512_Bytes;
var
  Data, Hash: TBytes;
begin
  Data := TEncoding.UTF8.GetBytes('test');
  Hash := THashUtils.SHA512(Data);
  Assert.AreEqual(Integer(64), Integer(Length(Hash))); // SHA512 = 64 bytes
end;

procedure THashUtilsTests.Test_SHA512_String;
var
  Hash: string;
begin
  Hash := THashUtils.SHA512('test');
  Assert.AreEqual(Integer(128), Integer(Length(Hash))); // 64 bytes as hex
end;

procedure THashUtilsTests.Test_HMAC_Bytes;
var
  Key, Data, Mac: TBytes;
begin
  Key := TEncoding.UTF8.GetBytes('secret');
  Data := TEncoding.UTF8.GetBytes('message');
  Mac := THashUtils.HMAC(Key, Data, haSHA256);
  Assert.AreEqual(Integer(32), Integer(Length(Mac)));
end;

procedure THashUtilsTests.Test_HMAC_String;
var
  Mac: string;
begin
  Mac := THashUtils.HMAC('secret', 'message', haSHA256);
  Assert.AreEqual(64, Integer(Length(Mac)));
end;

procedure THashUtilsTests.Test_DifferentAlgorithms_DifferentLengths;
begin
  Assert.AreEqual(32, Integer(Length(THashUtils.MD5('test'))));   // 16 bytes
  Assert.AreEqual(40, Integer(Length(THashUtils.SHA1('test'))));  // 20 bytes
  Assert.AreEqual(64, Integer(Length(THashUtils.SHA256('test')))); // 32 bytes
  Assert.AreEqual(128, Integer(Length(THashUtils.SHA512('test')))); // 64 bytes
end;

procedure THashUtilsTests.Test_SameInput_SameOutput;
var
  Hash1, Hash2: string;
begin
  Hash1 := THashUtils.SHA256('test');
  Hash2 := THashUtils.SHA256('test');
  Assert.AreEqual(Hash1, Hash2);
end;

procedure THashUtilsTests.Test_DifferentInput_DifferentOutput;
var
  Hash1, Hash2: string;
begin
  Hash1 := THashUtils.SHA256('test1');
  Hash2 := THashUtils.SHA256('test2');
  Assert.AreNotEqual(Hash1, Hash2);
end;

// ============================================================================
// TEncodingUtilsTests
// ============================================================================

procedure TEncodingUtilsTests.Test_Base64Encode_Bytes;
var
  Data: TBytes;
  Encoded: string;
begin
  Data := TEncoding.UTF8.GetBytes('Hello World');
  Encoded := TEncodingUtils.Base64Encode(Data);
  Assert.AreEqual('SGVsbG8gV29ybGQ=', Encoded);
end;

procedure TEncodingUtilsTests.Test_Base64Encode_String;
var
  Encoded: string;
begin
  Encoded := TEncodingUtils.Base64Encode('Hello World');
  Assert.AreEqual('SGVsbG8gV29ybGQ=', Encoded);
end;

procedure TEncodingUtilsTests.Test_Base64Decode;
var
  Decoded: TBytes;
begin
  Decoded := TEncodingUtils.Base64Decode('SGVsbG8gV29ybGQ=');
  Assert.AreEqual('Hello World', TEncoding.UTF8.GetString(Decoded));
end;

procedure TEncodingUtilsTests.Test_Base64DecodeString;
var
  Decoded: string;
begin
  Decoded := TEncodingUtils.Base64DecodeString('SGVsbG8gV29ybGQ=');
  Assert.AreEqual('Hello World', Decoded);
end;

procedure TEncodingUtilsTests.Test_Base64_RoundTrip;
var
  Original, Decoded: string;
begin
  Original := 'Test data with special chars: @#$%';
  Decoded := TEncodingUtils.Base64DecodeString(TEncodingUtils.Base64Encode(Original));
  Assert.AreEqual(Original, Decoded);
end;

procedure TEncodingUtilsTests.Test_Base64UrlEncode;
var
  Encoded: string;
begin
  // Test that + and / are replaced with - and _
  Encoded := TEncodingUtils.Base64UrlEncode('test data');
  Assert.IsFalse(Encoded.Contains('+'));
  Assert.IsFalse(Encoded.Contains('/'));
end;

procedure TEncodingUtilsTests.Test_Base64UrlDecode;
var
  Encoded: string;
  Decoded: TBytes;
begin
  Encoded := TEncodingUtils.Base64UrlEncode('test data');
  Decoded := TEncodingUtils.Base64UrlDecode(Encoded);
  Assert.AreEqual('test data', TEncoding.UTF8.GetString(Decoded));
end;

procedure TEncodingUtilsTests.Test_Base64Url_RoundTrip;
var
  Original, Decoded: string;
begin
  Original := 'Test URL-safe encoding';
  Decoded := TEncodingUtils.Base64UrlDecodeString(TEncodingUtils.Base64UrlEncode(Original));
  Assert.AreEqual(Original, Decoded);
end;

procedure TEncodingUtilsTests.Test_HexEncode_Bytes;
var
  Data: TBytes;
  Encoded: string;
begin
  Data := TBytes.Create($48, $65, $6C, $6C, $6F); // 'Hello'
  Encoded := TEncodingUtils.HexEncode(Data);
  Assert.AreEqual('48656C6C6F', Encoded.ToUpper);
end;

procedure TEncodingUtilsTests.Test_HexEncode_String;
var
  Encoded: string;
begin
  Encoded := TEncodingUtils.HexEncode('AB');
  Assert.AreEqual('4142', Encoded.ToUpper);
end;

procedure TEncodingUtilsTests.Test_HexDecode;
var
  Decoded: TBytes;
begin
  Decoded := TEncodingUtils.HexDecode('48656C6C6F');
  Assert.AreEqual('Hello', TEncoding.UTF8.GetString(Decoded));
end;

procedure TEncodingUtilsTests.Test_HexDecodeString;
var
  Decoded: string;
begin
  Decoded := TEncodingUtils.HexDecodeString('48656C6C6F');
  Assert.AreEqual('Hello', Decoded);
end;

procedure TEncodingUtilsTests.Test_Hex_RoundTrip;
var
  Original, Decoded: string;
begin
  Original := 'Test hex encoding';
  Decoded := TEncodingUtils.HexDecodeString(TEncodingUtils.HexEncode(Original));
  Assert.AreEqual(Original, Decoded);
end;

procedure TEncodingUtilsTests.Test_UrlEncode;
var
  Encoded: string;
begin
  Encoded := TEncodingUtils.UrlEncode('Hello World!');
  Assert.IsTrue(Encoded.Contains('%20') or Encoded.Contains('+'));
end;

procedure TEncodingUtilsTests.Test_UrlDecode;
var
  Decoded: string;
begin
  Decoded := TEncodingUtils.UrlDecode('Hello%20World');
  Assert.AreEqual('Hello World', Decoded);
end;

procedure TEncodingUtilsTests.Test_Url_RoundTrip;
var
  Original, Decoded: string;
begin
  Original := 'test=value&name=John Doe';
  Decoded := TEncodingUtils.UrlDecode(TEncodingUtils.UrlEncode(Original));
  Assert.AreEqual(Original, Decoded);
end;

procedure TEncodingUtilsTests.Test_HtmlEncode;
var
  Encoded: string;
begin
  Encoded := TEncodingUtils.HtmlEncode('<script>alert("XSS")</script>');
  Assert.IsTrue(Encoded.Contains('&lt;'));
  Assert.IsTrue(Encoded.Contains('&gt;'));
end;

procedure TEncodingUtilsTests.Test_HtmlDecode;
var
  Decoded: string;
begin
  Decoded := TEncodingUtils.HtmlDecode('&lt;b&gt;Bold&lt;/b&gt;');
  Assert.AreEqual('<b>Bold</b>', Decoded);
end;

procedure TEncodingUtilsTests.Test_Html_RoundTrip;
var
  Original, Decoded: string;
begin
  Original := '<div class="test">Content & more</div>';
  Decoded := TEncodingUtils.HtmlDecode(TEncodingUtils.HtmlEncode(Original));
  Assert.AreEqual(Original, Decoded);
end;

// ============================================================================
// TRandomGeneratorTests
// ============================================================================

procedure TRandomGeneratorTests.Test_RandomBytes_Length;
var
  Data: TBytes;
begin
  Data := TRandomGenerator.RandomBytes(32);
  Assert.AreEqual(Integer(32), Integer(Length(Data)));
end;

procedure TRandomGeneratorTests.Test_RandomBytes_NotAllZeros;
var
  Data: TBytes;
  HasNonZero: Boolean;
begin
  Data := TRandomGenerator.RandomBytes(32);
  HasNonZero := False;
  for var B in Data do
    if B <> 0 then
    begin
      HasNonZero := True;
      Break;
    end;
  Assert.IsTrue(HasNonZero);
end;

procedure TRandomGeneratorTests.Test_RandomString_Length;
var
  S: string;
begin
  S := TRandomGenerator.RandomString(20);
  Assert.AreEqual(20, Integer(Length(S)));
end;

procedure TRandomGeneratorTests.Test_RandomString_Alphanumeric;
var
  S: string;
begin
  S := TRandomGenerator.RandomString(100);
  for var C in S do
    Assert.IsTrue(CharInSet(C, ['A'..'Z', 'a'..'z', '0'..'9']));
end;

procedure TRandomGeneratorTests.Test_RandomHex_Length;
var
  S: string;
begin
  S := TRandomGenerator.RandomHex(16);
  Assert.AreEqual(16, Integer(Length(S)));
end;

procedure TRandomGeneratorTests.Test_RandomHex_ValidChars;
var
  S: string;
begin
  S := TRandomGenerator.RandomHex(32);
  for var C in S do
    Assert.IsTrue(CharInSet(C, ['0'..'9', 'A'..'F', 'a'..'f']));
end;

procedure TRandomGeneratorTests.Test_RandomInt_InRange;
var
  Value: Integer;
begin
  for var I := 1 to 100 do
  begin
    Value := TRandomGenerator.RandomInt(10, 20);
    Assert.IsTrue((Value >= 10) and (Value <= 20));
  end;
end;

procedure TRandomGeneratorTests.Test_NewGuid_Format;
var
  Guid: string;
begin
  Guid := TRandomGenerator.NewGuid;
  Assert.AreEqual(36, Integer(Length(Guid))); // xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  Assert.AreEqual('-', Guid[9]);
  Assert.AreEqual('-', Guid[14]);
  Assert.AreEqual('-', Guid[19]);
  Assert.AreEqual('-', Guid[24]);
end;

procedure TRandomGeneratorTests.Test_NewGuidNoDashes_Format;
var
  Guid: string;
begin
  Guid := TRandomGenerator.NewGuidNoDashes;
  Assert.AreEqual(32, Integer(Length(Guid)));
  Assert.IsFalse(Guid.Contains('-'));
end;

procedure TRandomGeneratorTests.Test_SecureToken_Length;
var
  Token: string;
begin
  Token := TRandomGenerator.SecureToken(64);
  Assert.IsTrue(Length(Token) >= 64);
end;

procedure TRandomGeneratorTests.Test_GenerateOTP_Digits;
var
  OTP: string;
begin
  OTP := TRandomGenerator.GenerateOTP(6);
  Assert.AreEqual(6, Integer(Length(OTP)));
end;

procedure TRandomGeneratorTests.Test_GenerateOTP_OnlyDigits;
var
  OTP: string;
begin
  OTP := TRandomGenerator.GenerateOTP(8);
  for var C in OTP do
    Assert.IsTrue(CharInSet(C, ['0'..'9']));
end;

procedure TRandomGeneratorTests.Test_Uniqueness;
var
  S1, S2: string;
begin
  S1 := TRandomGenerator.RandomString(32);
  S2 := TRandomGenerator.RandomString(32);
  Assert.AreNotEqual(S1, S2);
end;

// ============================================================================
// TPasswordUtilsTests
// ============================================================================

procedure TPasswordUtilsTests.Test_HashPassword;
var
  Hash: string;
begin
  Hash := TPasswordUtils.HashPassword('myPassword123');
  Assert.IsNotEmpty(Hash);
  Assert.IsTrue(Length(Hash) > 32);
end;

procedure TPasswordUtilsTests.Test_VerifyPassword_Correct;
var
  Hash: string;
begin
  Hash := TPasswordUtils.HashPassword('myPassword123');
  Assert.IsTrue(TPasswordUtils.VerifyPassword('myPassword123', Hash));
end;

procedure TPasswordUtilsTests.Test_VerifyPassword_Incorrect;
var
  Hash: string;
begin
  Hash := TPasswordUtils.HashPassword('myPassword123');
  Assert.IsFalse(TPasswordUtils.VerifyPassword('wrongPassword', Hash));
end;

procedure TPasswordUtilsTests.Test_GenerateSalt_Length;
var
  Salt: TBytes;
begin
  Salt := TPasswordUtils.GenerateSalt(16);
  Assert.AreEqual(Integer(16), Integer(Length(Salt)));
end;

procedure TPasswordUtilsTests.Test_GenerateSalt_Unique;
var
  Salt1, Salt2: TBytes;
begin
  Salt1 := TPasswordUtils.GenerateSalt(16);
  Salt2 := TPasswordUtils.GenerateSalt(16);
  Assert.IsFalse(CompareMem(@Salt1[0], @Salt2[0], 16));
end;

procedure TPasswordUtilsTests.Test_PBKDF2;
var
  Salt, Key: TBytes;
begin
  Salt := TPasswordUtils.GenerateSalt(16);
  Key := TPasswordUtils.PBKDF2('password', Salt, 10000, 32);
  Assert.AreEqual(Integer(32), Integer(Length(Key)));
end;

procedure TPasswordUtilsTests.Test_PBKDF2_DifferentSalts;
var
  Salt1, Salt2, Key1, Key2: TBytes;
begin
  Salt1 := TPasswordUtils.GenerateSalt(16);
  Salt2 := TPasswordUtils.GenerateSalt(16);
  Key1 := TPasswordUtils.PBKDF2('password', Salt1, 1000, 32);
  Key2 := TPasswordUtils.PBKDF2('password', Salt2, 1000, 32);
  Assert.IsFalse(CompareMem(@Key1[0], @Key2[0], 32));
end;

procedure TPasswordUtilsTests.Test_PBKDF2_DifferentIterations;
var
  Salt, Key1, Key2: TBytes;
begin
  Salt := TBytes.Create(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16);
  Key1 := TPasswordUtils.PBKDF2('password', Salt, 1000, 32);
  Key2 := TPasswordUtils.PBKDF2('password', Salt, 2000, 32);
  Assert.IsFalse(CompareMem(@Key1[0], @Key2[0], 32));
end;

procedure TPasswordUtilsTests.Test_CheckStrength_Weak;
var
  Score: Integer;
begin
  Score := TPasswordUtils.CheckStrength('123');
  // Very short numeric-only password should be classified as weak (low score)
  Assert.IsTrue(Score <= 2, 'Weak password should have low strength score');
end;

procedure TPasswordUtilsTests.Test_CheckStrength_Medium;
var
  Score: Integer;
begin
  Score := TPasswordUtils.CheckStrength('Password1');
  // Mixed-case + digits, medium length -> medium strength (around 3-4)
  Assert.IsTrue((Score >= 3) and (Score <= 4), 'Medium strength password should have medium score');
end;

procedure TPasswordUtilsTests.Test_CheckStrength_Strong;
var
  Score: Integer;
begin
  Score := TPasswordUtils.CheckStrength('MyStr0ng!P@ssw0rd#2024');
  // Long password with upper/lower/digits/special -> strongest bucket
  Assert.IsTrue(Score >= 5, 'Strong password should have the highest score');
end;

procedure TPasswordUtilsTests.Test_GeneratePassword_Length;
var
  Pwd: string;
begin
  Pwd := TPasswordUtils.GeneratePassword(20);
  Assert.AreEqual(20, Integer(Length(Pwd)));
end;

procedure TPasswordUtilsTests.Test_GeneratePassword_WithUppercase;
var
  Pwd: string;
  HasUpper: Boolean;
begin
  Pwd := TPasswordUtils.GeneratePassword(20, True, False, False, False);
  HasUpper := False;
  for var C in Pwd do
    if CharInSet(C, ['A'..'Z']) then
    begin
      HasUpper := True;
      Break;
    end;
  Assert.IsTrue(HasUpper);
end;

procedure TPasswordUtilsTests.Test_GeneratePassword_WithDigits;
var
  Pwd: string;
  HasDigit: Boolean;
begin
  Pwd := TPasswordUtils.GeneratePassword(20, False, False, True, False);
  HasDigit := False;
  for var C in Pwd do
    if CharInSet(C, ['0'..'9']) then
    begin
      HasDigit := True;
      Break;
    end;
  Assert.IsTrue(HasDigit);
end;

procedure TPasswordUtilsTests.Test_GeneratePassword_WithSpecial;
var
  Pwd: string;
  HasSpecial: Boolean;
const
  SpecialChars = '!@#$%^&*()_+-=[]{}|;:,.<>?';
begin
  Pwd := TPasswordUtils.GeneratePassword(20, False, False, False, True);
  HasSpecial := False;
  for var C in Pwd do
    if Pos(C, SpecialChars) > 0 then
    begin
      HasSpecial := True;
      Break;
    end;
  Assert.IsTrue(HasSpecial);
end;

procedure TPasswordUtilsTests.Test_PasswordHashOptions_Default;
var
  Opts: TPasswordHashOptions;
begin
  Opts := TPasswordHashOptions.Default;
  Assert.IsTrue(Opts.Iterations >= 10000);
  Assert.IsTrue(Opts.SaltLength >= 16);
  Assert.IsTrue(Opts.HashLength >= 32);
end;

// ============================================================================
// TAESCryptoTests
// ============================================================================

procedure TAESCryptoTests.Setup;
begin
  // Use default constructor parameters (aes256, aesCBC)
  FAES := TAESCrypto.Create;
end;

procedure TAESCryptoTests.TearDown;
begin
  FAES.Free;
end;

procedure TAESCryptoTests.Test_Create;
begin
  Assert.IsNotNull(FAES);
  // Default constructor should use AES-256 CBC
  Assert.IsTrue(FAES.KeySize = aes256);
  Assert.IsTrue(FAES.Mode = aesCBC);
end;

procedure TAESCryptoTests.Test_GenerateKey;
begin
  FAES.GenerateKey;
  Assert.AreEqual(Integer(32), Integer(Length(FAES.Key))); // AES-256 = 32 bytes
end;

procedure TAESCryptoTests.Test_GenerateIV;
begin
  FAES.GenerateIV;
  Assert.AreEqual(Integer(16), Integer(Length(FAES.IV))); // AES block size = 16 bytes
end;

procedure TAESCryptoTests.Test_SetKey;
var
  Key: TBytes;
begin
  Key := TRandomGenerator.RandomBytes(32);
  FAES.SetKey(Key);
  Assert.AreEqual(32, Integer(Length(FAES.Key)));
end;

procedure TAESCryptoTests.Test_SetKeyFromPassword;
begin
  FAES.SetKeyFromPassword('testPassword', TSimpleCrypto.DeriveSalt('testPassword'));
  Assert.AreEqual(32, Integer(Length(FAES.Key)));
end;

procedure TAESCryptoTests.Test_Encrypt_Decrypt_Bytes;
var
  Original, Encrypted, Decrypted: TBytes;
begin
  FAES.GenerateKey;
  FAES.GenerateIV;
  
  Original := TEncoding.UTF8.GetBytes('Test message for encryption');
  Encrypted := FAES.Encrypt(Original);
  Decrypted := FAES.Decrypt(Encrypted);
  
  Assert.AreEqual(TEncoding.UTF8.GetString(Original), TEncoding.UTF8.GetString(Decrypted));
end;

procedure TAESCryptoTests.Test_EncryptString_DecryptString;
var
  Original, Encrypted, Decrypted: string;
begin
  FAES.GenerateKey;
  FAES.GenerateIV;
  
  Original := 'Test string encryption';
  Encrypted := FAES.EncryptString(Original);
  Decrypted := FAES.DecryptString(Encrypted);
  
  Assert.AreEqual(Original, Decrypted);
end;

procedure TAESCryptoTests.Test_Encrypt_Decrypt_RoundTrip;
var
  Original, Result: string;
begin
  FAES.GenerateKey;
  FAES.GenerateIV;
  
  Original := 'Multiple round trip test with various characters: @#$%^&*()';
  Result := FAES.DecryptString(FAES.EncryptString(Original));
  Assert.AreEqual(Original, Result);
end;

procedure TAESCryptoTests.Test_KeySizes;
begin
  // Basic sanity: AES-256 default key size should produce 32-byte keys
  FAES.GenerateKey;
  Assert.AreEqual(Integer(32), Integer(Length(FAES.Key)));
end;

procedure TAESCryptoTests.Test_DifferentKeys_DifferentResults;
var
  AES1, AES2: TAESCrypto;
  Encrypted1, Encrypted2: string;
begin
  AES1 := TAESCrypto.Create;
  AES2 := TAESCrypto.Create;
  try
    AES1.GenerateKey;
    AES1.GenerateIV;
    AES2.GenerateKey;
    AES2.GenerateIV;
    
    Encrypted1 := AES1.EncryptString('Test');
    Encrypted2 := AES2.EncryptString('Test');
    
    Assert.AreNotEqual(Encrypted1, Encrypted2);
  finally
    AES1.Free;
    AES2.Free;
  end;
end;

// ============================================================================
// TSimpleCryptoTests
// ============================================================================

procedure TSimpleCryptoTests.Test_Encrypt_Decrypt_String;
var
  Original, Encrypted, Decrypted: string;
begin
  Original := 'Test message';
  Encrypted := TSimpleCrypto.Encrypt(Original, 'password');
  Decrypted := TSimpleCrypto.Decrypt(Encrypted, 'password');
  Assert.AreEqual(Original, Decrypted);
end;

procedure TSimpleCryptoTests.Test_Encrypt_Decrypt_Bytes;
var
  Original, Encrypted, Decrypted: TBytes;
begin
  Original := TEncoding.UTF8.GetBytes('Test bytes');
  Encrypted := TSimpleCrypto.EncryptBytes(Original, 'password');
  Decrypted := TSimpleCrypto.DecryptBytes(Encrypted, 'password');
  Assert.AreEqual(TEncoding.UTF8.GetString(Original), TEncoding.UTF8.GetString(Decrypted));
end;

procedure TSimpleCryptoTests.Test_RoundTrip;
var
  Original: string;
begin
  Original := 'Complex data with special chars: åäö @#$%';
  Assert.AreEqual(Original, TSimpleCrypto.Decrypt(TSimpleCrypto.Encrypt(Original, 'pwd'), 'pwd'));
end;

procedure TSimpleCryptoTests.Test_DifferentPasswords_DifferentResults;
var
  Encrypted1, Encrypted2: string;
begin
  Encrypted1 := TSimpleCrypto.Encrypt('Test', 'password1');
  Encrypted2 := TSimpleCrypto.Encrypt('Test', 'password2');
  Assert.AreNotEqual(Encrypted1, Encrypted2);
end;

procedure TSimpleCryptoTests.Test_WrongPassword_Fails;
var
  Encrypted: string;
  Raised: Boolean;
begin
  Encrypted := TSimpleCrypto.Encrypt('Test', 'correctPassword');
  // Decrypting with a wrong password should fail with a crypto error
  Raised := False;
  try
    TSimpleCrypto.Decrypt(Encrypted, 'wrongPassword');
  except
    on ECryptoException do
      Raised := True;
  end;
  Assert.IsTrue(Raised, 'Expected ECryptoException');
end;

// ============================================================================
// TCryptoServiceImplTests
// ============================================================================

procedure TCryptoServiceImplTests.Test_EncryptWithIV_DecryptWithIV_RoundTrip;
var
  Svc: TCryptoServiceImpl;
  Data, Key, IV, Encrypted, Decrypted: TBytes;
begin
  Svc := TCryptoServiceImpl.Create;
  try
    Data := TEncoding.UTF8.GetBytes('service-iv-roundtrip');
    Key := TEncoding.UTF8.GetBytes('service-key');
    IV := TEncoding.UTF8.GetBytes('0123456789ABCDEF');

    Encrypted := Svc.EncryptWithIV(Data, Key, IV);
    Decrypted := Svc.DecryptWithIV(Encrypted, Key, IV);

    Assert.AreEqual(TEncoding.UTF8.GetString(Data), TEncoding.UTF8.GetString(Decrypted));
  finally
    Svc.Free;
  end;
end;

procedure TCryptoServiceImplTests.Test_EncryptWithIV_DifferentIV_ProducesDifferentCiphertext;
var
  Svc: TCryptoServiceImpl;
  Data, Key, IV1, IV2, Enc1, Enc2: TBytes;
begin
  Svc := TCryptoServiceImpl.Create;
  try
    Data := TEncoding.UTF8.GetBytes('same-plain-text');
    Key := TEncoding.UTF8.GetBytes('service-key');
    IV1 := TEncoding.UTF8.GetBytes('0123456789ABCDEF');
    IV2 := TEncoding.UTF8.GetBytes('FEDCBA9876543210');

    Enc1 := Svc.EncryptWithIV(Data, Key, IV1);
    Enc2 := Svc.EncryptWithIV(Data, Key, IV2);

    Assert.AreNotEqual(TEncodingUtils.HexEncode(Enc1), TEncodingUtils.HexEncode(Enc2));
  finally
    Svc.Free;
  end;
end;

procedure TCryptoServiceImplTests.Test_EncryptWithIV_InvalidIVLength_Raises;
var
  Svc: TCryptoServiceImpl;
  Data, Key, InvalidIV: TBytes;
  Raised: Boolean;
begin
  Svc := TCryptoServiceImpl.Create;
  try
    Data := TEncoding.UTF8.GetBytes('payload');
    Key := TEncoding.UTF8.GetBytes('service-key');
    InvalidIV := TEncoding.UTF8.GetBytes('too-short');

    Raised := False;
    try
      Svc.EncryptWithIV(Data, Key, InvalidIV);
    except
      on ECryptoException do
        Raised := True;
    end;
    Assert.IsTrue(Raised, 'Expected ECryptoException');
  finally
    Svc.Free;
  end;
end;

// ============================================================================
// TCRCUtilsTests
// ============================================================================

procedure TCRCUtilsTests.Test_CRC32_Bytes;
var
  Data: TBytes;
  CRC: Cardinal;
begin
  Data := TEncoding.UTF8.GetBytes('test');
  CRC := TCRCUtils.CRC32(Data);
  Assert.AreNotEqual(Cardinal(0), CRC);
end;

procedure TCRCUtilsTests.Test_CRC32_String;
var
  CRC: Cardinal;
begin
  CRC := TCRCUtils.CRC32('test');
  Assert.AreNotEqual(Cardinal(0), CRC);
end;

procedure TCRCUtilsTests.Test_CRC32_Deterministic;
var
  CRC1, CRC2: Cardinal;
begin
  CRC1 := TCRCUtils.CRC32('test data');
  CRC2 := TCRCUtils.CRC32('test data');
  Assert.AreEqual(CRC1, CRC2);
end;

procedure TCRCUtilsTests.Test_CRC32_DifferentInput_DifferentOutput;
var
  CRC1, CRC2: Cardinal;
begin
  CRC1 := TCRCUtils.CRC32('data1');
  CRC2 := TCRCUtils.CRC32('data2');
  Assert.AreNotEqual(CRC1, CRC2);
end;

procedure TCRCUtilsTests.Test_Adler32_Bytes;
var
  Data: TBytes;
  Checksum: Cardinal;
begin
  Data := TEncoding.UTF8.GetBytes('test');
  Checksum := TCRCUtils.Adler32(Data);
  Assert.AreNotEqual(Cardinal(0), Checksum);
end;

procedure TCRCUtilsTests.Test_Adler32_String;
var
  Checksum: Cardinal;
begin
  Checksum := TCRCUtils.Adler32('test');
  Assert.AreNotEqual(Cardinal(0), Checksum);
end;

// ============================================================================
// TCryptoHelperTests
// ============================================================================

procedure TCryptoHelperTests.Test_MD5;
begin
  Assert.AreEqual(32, Integer(Length(TCrypto.MD5('test'))));
end;

procedure TCryptoHelperTests.Test_SHA1;
begin
  Assert.AreEqual(40, Integer(Length(TCrypto.SHA1('test'))));
end;

procedure TCryptoHelperTests.Test_SHA256;
begin
  Assert.AreEqual(64, Integer(Length(TCrypto.SHA256('test'))));
end;

procedure TCryptoHelperTests.Test_SHA512;
begin
  Assert.AreEqual(128, Integer(Length(TCrypto.SHA512('test'))));
end;

procedure TCryptoHelperTests.Test_Base64Encode;
begin
  Assert.AreEqual('SGVsbG8=', TCrypto.Base64Encode('Hello'));
end;

procedure TCryptoHelperTests.Test_Base64Decode;
begin
  Assert.AreEqual('Hello', TCrypto.Base64Decode('SGVsbG8='));
end;

procedure TCryptoHelperTests.Test_HexEncode;
begin
  Assert.IsNotEmpty(TCrypto.HexEncode('test'));
end;

procedure TCryptoHelperTests.Test_HexDecode;
var
  Encoded: string;
begin
  Encoded := TCrypto.HexEncode('test');
  Assert.AreEqual('test', TCrypto.HexDecode(Encoded));
end;

procedure TCryptoHelperTests.Test_HashPassword;
begin
  Assert.IsNotEmpty(TCrypto.HashPassword('password'));
end;

procedure TCryptoHelperTests.Test_VerifyPassword;
var
  Hash: string;
begin
  Hash := TCrypto.HashPassword('password');
  Assert.IsTrue(TCrypto.VerifyPassword('password', Hash));
  Assert.IsFalse(TCrypto.VerifyPassword('wrong', Hash));
end;

procedure TCryptoHelperTests.Test_Encrypt_Decrypt;
var
  Encrypted: string;
begin
  Encrypted := TCrypto.Encrypt('secret data', 'password');
  Assert.AreEqual('secret data', TCrypto.Decrypt(Encrypted, 'password'));
end;

procedure TCryptoHelperTests.Test_RandomString;
begin
  Assert.AreEqual(16, Integer(Length(TCrypto.RandomString(16))));
end;

procedure TCryptoHelperTests.Test_RandomBytes;
begin
  Assert.AreEqual(Integer(32), Integer(Length(TCrypto.RandomBytes(32))));
end;

procedure TCryptoHelperTests.Test_NewGuid;
begin
  Assert.AreEqual(36, Integer(Length(TCrypto.NewGuid)));
end;

{$IFDEF MSWINDOWS}
// ============================================================================
// TRSAVerifierTests
// ============================================================================

procedure TRSAVerifierTests.Test_Create;
var
  LVerifier: TRSAVerifier;
begin
  LVerifier := TRSAVerifier.Create;
  try
    Assert.IsNotNull(LVerifier);
    Assert.IsFalse(LVerifier.IsKeyLoaded);
    Assert.IsEmpty(LVerifier.LastError);
  finally
    LVerifier.Free;
  end;
end;

procedure TRSAVerifierTests.Test_LoadPublicKeyPEM_Valid;
var
  LVerifier: TRSAVerifier;
  // A valid RSA-2048 public key in PEM format
  LPEM: string;
begin
  LPEM := 
    '-----BEGIN PUBLIC KEY-----' + sLineBreak +
    'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAu1SU1LfVLPHCozMxH2Mo' + sLineBreak +
    '4lgOEePzNm0tRgeLezV6ffAt0gunVTLw7onLRnrq0/IzW7yWR7QkrmBL7jTKEn5u' + sLineBreak +
    '+qKhbwKfBstIs+bMY2Zkp18gnTxKLxoS2tFczGkPLPgizskuemMghRniWaoLcyeh' + sLineBreak +
    'kd3qqGElvW/VDL5AaWTg0nLVkjRo9z+40RQzuVaE8AkAFmxZzow3x+VJYKdjykkJ' + sLineBreak +
    '0iT9wCS0DRTXu269V264Vf/3jvredZiKRkgwlL9xNAwxXFg0x/XFw005UWVRIkdg' + sLineBreak +
    'cKWTjpBP2dPwVZ4WWC+9aGVd+Gyn1o0CLelf4rEjGoXbAAEgAqeGUxrcIlbjXfbc' + sLineBreak +
    'mwIDAQAB' + sLineBreak +
    '-----END PUBLIC KEY-----';
  
  LVerifier := TRSAVerifier.Create;
  try
    Assert.IsTrue(LVerifier.LoadPublicKeyPEM(LPEM), 
      'Failed to load valid PEM: ' + LVerifier.LastError);
    Assert.IsTrue(LVerifier.IsKeyLoaded);
  finally
    LVerifier.Free;
  end;
end;

procedure TRSAVerifierTests.Test_LoadPublicKeyPEM_Invalid;
var
  LVerifier: TRSAVerifier;
begin
  LVerifier := TRSAVerifier.Create;
  try
    Assert.IsFalse(LVerifier.LoadPublicKeyPEM('not a valid key'));
    Assert.IsFalse(LVerifier.IsKeyLoaded);
    Assert.IsNotEmpty(LVerifier.LastError);
  finally
    LVerifier.Free;
  end;
end;

procedure TRSAVerifierTests.Test_LoadPublicKeyPEM_Empty;
var
  LVerifier: TRSAVerifier;
begin
  LVerifier := TRSAVerifier.Create;
  try
    Assert.IsFalse(LVerifier.LoadPublicKeyPEM(''));
    Assert.IsFalse(LVerifier.IsKeyLoaded);
  finally
    LVerifier.Free;
  end;
end;

procedure TRSAVerifierTests.Test_VerifySignature_KeyNotLoaded;
var
  LVerifier: TRSAVerifier;
begin
  LVerifier := TRSAVerifier.Create;
  try
    Assert.IsFalse(LVerifier.VerifySignature('data', 'signature'));
    Assert.AreEqual('Public key not loaded', LVerifier.LastError);
  finally
    LVerifier.Free;
  end;
end;

procedure TRSAVerifierTests.Test_VerifySignature_EmptySignature;
var
  LVerifier: TRSAVerifier;
  LPEM: string;
begin
  LPEM := 
    '-----BEGIN PUBLIC KEY-----' + sLineBreak +
    'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAu1SU1LfVLPHCozMxH2Mo' + sLineBreak +
    '4lgOEePzNm0tRgeLezV6ffAt0gunVTLw7onLRnrq0/IzW7yWR7QkrmBL7jTKEn5u' + sLineBreak +
    '+qKhbwKfBstIs+bMY2Zkp18gnTxKLxoS2tFczGkPLPgizskuemMghRniWaoLcyeh' + sLineBreak +
    'kd3qqGElvW/VDL5AaWTg0nLVkjRo9z+40RQzuVaE8AkAFmxZzow3x+VJYKdjykkJ' + sLineBreak +
    '0iT9wCS0DRTXu269V264Vf/3jvredZiKRkgwlL9xNAwxXFg0x/XFw005UWVRIkdg' + sLineBreak +
    'cKWTjpBP2dPwVZ4WWC+9aGVd+Gyn1o0CLelf4rEjGoXbAAEgAqeGUxrcIlbjXfbc' + sLineBreak +
    'mwIDAQAB' + sLineBreak +
    '-----END PUBLIC KEY-----';
    
  LVerifier := TRSAVerifier.Create;
  try
    LVerifier.LoadPublicKeyPEM(LPEM);
    Assert.IsFalse(LVerifier.VerifySignature('data', ''));
    Assert.AreEqual('Empty signature', LVerifier.LastError);
  finally
    LVerifier.Free;
  end;
end;

procedure TRSAVerifierTests.Test_IsKeyLoaded_Initial;
var
  LVerifier: TRSAVerifier;
begin
  LVerifier := TRSAVerifier.Create;
  try
    Assert.IsFalse(LVerifier.IsKeyLoaded);
  finally
    LVerifier.Free;
  end;
end;

procedure TRSAVerifierTests.Test_LastError_AfterFailure;
var
  LVerifier: TRSAVerifier;
begin
  LVerifier := TRSAVerifier.Create;
  try
    LVerifier.LoadPublicKeyPEM('invalid');
    Assert.IsNotEmpty(LVerifier.LastError);
  finally
    LVerifier.Free;
  end;
end;
{$ENDIF}

initialization
  TDUnitX.RegisterTestFixture(THashUtilsTests);
  TDUnitX.RegisterTestFixture(TEncodingUtilsTests);
  TDUnitX.RegisterTestFixture(TRandomGeneratorTests);
  TDUnitX.RegisterTestFixture(TPasswordUtilsTests);
  TDUnitX.RegisterTestFixture(TAESCryptoTests);
  TDUnitX.RegisterTestFixture(TSimpleCryptoTests);
  TDUnitX.RegisterTestFixture(TCryptoServiceImplTests);
  TDUnitX.RegisterTestFixture(TCRCUtilsTests);
  TDUnitX.RegisterTestFixture(TCryptoHelperTests);
  {$IFDEF MSWINDOWS}
  TDUnitX.RegisterTestFixture(TRSAVerifierTests);
  {$ENDIF}

end.
