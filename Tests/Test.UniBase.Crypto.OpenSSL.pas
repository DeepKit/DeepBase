unit Test.UniBase.Crypto.OpenSSL;

interface

{$IF DEFINED(MACOS) OR DEFINED(LINUX)}

uses
  System.SysUtils,
  System.Classes,
  DUnitX.TestFramework,
  UniBase.Crypto.OpenSSL;

type
  /// <summary>
  /// Basic tests for UniBase.Crypto.OpenSSL helper functions.
  ///
  /// 说明：
  /// - 这些测试在没有 libcrypto 时不会失败，只验证不会抛出意外异常；
  /// - 当运行环境正确部署 libcrypto 时，会进一步验证随机数长度和 AES-256-GCM 的加解密往返。
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
        // 在当前环境无法加载 OpenSSL 时，后续测试直接返回，避免失败
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
      ; // 在缺少 libcrypto 的环境下允许出现该异常
    on E: Exception do
      Assert.Fail('Unexpected exception from OpenSSL_Init: ' + E.ClassName + ': ' + E.Message);
  end;
end;

procedure TOpenSSLBasicTests.Test_RandomBytes_Length_WhenLoaded;
var
  Bytes: TBytes;
begin
  if not EnsureLoadedOrSkip then
    Exit; // 环境未加载 OpenSSL，跳过具体行为验证

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
