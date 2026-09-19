unit Test.DeepBase.Crypto.OpenSSL;

interface

{$IF DEFINED(MACOS) OR DEFINED(LINUX)}

uses
  System.SysUtils,
  System.Classes,
  DUnitX.TestFramework,
  DeepBase.Crypto.OpenSSL;

type
  /// <summary>
  /// Basic tests for DeepBase.Crypto.OpenSSL helper functions.
  ///
  /// 璇存槑锛?
  /// - 杩欎簺娴嬭瘯鍦ㄦ病鏈?libcrypto 鏃朵笉浼氬け璐ワ紝鍙獙璇佷笉浼氭姏鍑烘剰澶栧紓甯革紱
  /// - 褰撹繍琛岀幆澧冩纭儴缃?libcrypto 鏃讹紝浼氳繘涓€姝ラ獙璇侀殢鏈烘暟闀垮害鍜?AES-256-GCM 鐨勫姞瑙ｅ瘑寰€杩斻€?
  /// </summary>
  [TestFixture]
  TOpenSSLBasicTests = class
  private
    function EnsureLoadedOrSkip: Boolean;
  public
    [Test]
    procedure Test_OpenSSL_Init_DoesNotRaise_Unexpected_Exception;

    [Test]
    procedure Test_RandomBytes_Length_WhenLoaded;

    [Test]
    procedure Test_PBKDF2_Returns_Key_With_Requested_Length_WhenLoaded;

    [Test]
    procedure Test_AES256GCM_Encrypt_Decrypt_RoundTrip_WhenLoaded;
  end;

{$ENDIF} // MACOS/LINUX

implementation

{$IF DEFINED(MACOS) OR DEFINED(LINUX)}

{ TOpenSSLBasicTests }

function TOpenSSLBasicTests.EnsureLoadedOrSkip: Boolean;
begin
  Result := OpenSSL_IsLoaded;
  if not Result then
  begin
    try
      OpenSSL_Init;
      Result := OpenSSL_IsLoaded;
    except
      on E: EOpenSSLNotLoaded do
      begin
        // 鍦ㄥ綋鍓嶇幆澧冩棤娉曞姞杞?OpenSSL 鏃讹紝鍚庣画娴嬭瘯鐩存帴杩斿洖锛岄伩鍏嶅け璐?
        Result := False;
      end;
      on E: Exception do
      begin
        Assert.Fail('OpenSSL_Init raised unexpected exception: ' + E.ClassName + ': ' + E.Message);
        Result := False;
      end;
    end;
  end;
end;

procedure TOpenSSLBasicTests.Test_OpenSSL_Init_DoesNotRaise_Unexpected_Exception;
begin
  try
    OpenSSL_Init;
  except
    on E: EOpenSSLNotLoaded do
      ; // 鍦ㄧ己灏?libcrypto 鐨勭幆澧冧笅鍏佽鍑虹幇璇ュ紓甯?
    on E: Exception do
      Assert.Fail('Unexpected exception from OpenSSL_Init: ' + E.ClassName + ': ' + E.Message);
  end;
end;

procedure TOpenSSLBasicTests.Test_RandomBytes_Length_WhenLoaded;
var
  Bytes: TBytes;
begin
  if not EnsureLoadedOrSkip then
    Exit; // 鐜鏈姞杞?OpenSSL锛岃烦杩囧叿浣撹涓洪獙璇?

  Bytes := OpenSSL_RandomBytes(32);
  Assert.AreEqual(32, Integer(Length(Bytes)));
end;

procedure TOpenSSLBasicTests.Test_PBKDF2_Returns_Key_With_Requested_Length_WhenLoaded;
var
  Password, Salt, Key: TBytes;
begin
  if not EnsureLoadedOrSkip then
    Exit;

  Password := TEncoding.UTF8.GetBytes('test-password');
  Salt := TEncoding.UTF8.GetBytes('test-salt');

  Key := OpenSSL_PBKDF2_SHA256(Password, Salt, 1000, 48);
  Assert.AreEqual(48, Integer(Length(Key)));
end;

procedure TOpenSSLBasicTests.Test_AES256GCM_Encrypt_Decrypt_RoundTrip_WhenLoaded;
var
  Key, IV, Plain, Cipher, Plain2, Tag, AAD: TBytes;
  Text1, Text2: string;
begin
  if not EnsureLoadedOrSkip then
    Exit;

  Key := OpenSSL_RandomBytes(32);  // AES-256 key
  IV := OpenSSL_RandomBytes(12);   // 96-bit GCM IV
  SetLength(AAD, 0);

  Text1 := 'Hello OpenSSL AES-256-GCM!';
  Plain := TEncoding.UTF8.GetBytes(Text1);

  Cipher := OpenSSL_AES256GCM_Encrypt(Key, IV, Plain, AAD, Tag);
  Assert.IsTrue(Length(Cipher) > 0, 'Ciphertext should not be empty');
  Assert.AreEqual(16, Length(Tag), 'Auth tag must be 16 bytes');

  Plain2 := OpenSSL_AES256GCM_Decrypt(Key, IV, Cipher, AAD, Tag);
  Text2 := TEncoding.UTF8.GetString(Plain2);

  Assert.AreEqual(Text1, Text2, 'Decrypted plaintext should equal original');
end;

initialization
  TDUnitX.RegisterTestFixture(TOpenSSLBasicTests);

{$ENDIF} // MACOS/LINUX

end.
