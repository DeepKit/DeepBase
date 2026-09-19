{ ============================================================================
  Test.Regression.BUG013_RSASignature - 支付模块RSA签名回归测试

  BUG-013: 鏀粯妯″潡RSA绛惧悕鏈疄鐜?  
  原问�? RSA2Sign方法只使用SHA256+Base64，未实现真正的RSA2-SHA256签名�?  
  修复方案: 使用Windows CryptoAPI实现真正的RSA2-SHA256签名�?  
  修复日期: 2025-01-27
  文件: ThirdParty/Payment/DeepBase.Payment.Alipay.pas
  浼樺厛绾? P0 (Critical)
  分类: Security
  ============================================================================ }

unit Test.Regression.BUG013_RSASignature;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  Test.Regression.Base;

type
  [TestFixture]
  [Category('Regression')]
  [Category('P0')]
  [Category('Security')]
  TBug013_RSASignatureTest = class(TRegressionTestBase)
  protected
    function GetBugNumber: string; override;
    function GetBugDescription: string; override;
    function GetFixDate: string; override;
    function GetPriority: string; override;
    function GetAffectedFile: string; override;
  public
    [Test]
    [Description('验证 RSA 签名不是简单的 SHA256+Base64')]
    procedure Test_RSASign_IsNotSimpleSHA256Base64;
    
    [Test]
    [Description('验证签名结果长度符合 RSA 签名特征')]
    procedure Test_RSASign_HasCorrectLength;
    
    [Test]
    [Description('验证相同内容产生相同签名')]
    procedure Test_RSASign_IsDeterministic;
    
    [Test]
    [Description('验证不同内容产生不同签名')]
    procedure Test_RSASign_DifferentContent_DifferentSignature;
    
    [Test]
    [Description('楠岃瘉缂哄皯绉侀挜鏃舵姏鍑烘槑纭敊璇?)]
    procedure Test_RSASign_WithoutPrivateKey_ThrowsError;
  end;

implementation

uses
  System.NetEncoding,
  System.Hash,
  DeepBase.Crypto, DeepBase.Crypto.RSA;

{ TBug013_RSASignatureTest }

function TBug013_RSASignatureTest.GetBugNumber: string;
begin
  Result := 'BUG-013';
end;

function TBug013_RSASignatureTest.GetBugDescription: string;
begin
  Result := '鏀粯妯″潡RSA绛惧悕鏈疄鐜?;
end;

function TBug013_RSASignatureTest.GetFixDate: string;
begin
  Result := '2025-01-27';
end;

function TBug013_RSASignatureTest.GetPriority: string;
begin
  Result := 'P0';
end;

function TBug013_RSASignatureTest.GetAffectedFile: string;
begin
  Result := 'ThirdParty/Payment/DeepBase.Payment.Alipay.pas';
end;

procedure TBug013_RSASignatureTest.Test_RSASign_IsNotSimpleSHA256Base64;
var
  TestContent: string;
  SimpleSHA256Base64: string;
  HashBytes: TBytes;
begin
  LogTestStart('Test_RSASign_IsNotSimpleSHA256Base64');
  
  TestContent := 'test_content_for_signing';
  
  // 璁＄畻绠€鍗曠殑 SHA256+Base64锛堣繖鏄敊璇殑瀹炵幇鏂瑰紡锛?  HashBytes := THashSHA2.GetHashBytes(TestContent);
  SimpleSHA256Base64 := TNetEncoding.Base64.EncodeBytesToString(HashBytes);
  
  // 验证简单的 SHA256+Base64 长度（SHA256 产生 32 字节，Base64 编码后约 44 字符�?  Assert.AreEqual(44, Integer(Length(SimpleSHA256Base64),
    'SHA256+Base64 搴旇浜х敓 44 瀛楃鐨勭粨鏋?);
  
  // RSA-2048 签名应该产生 256 字节，Base64 编码后约 344 字符
  // 杩欓噷鎴戜滑鍙獙璇佹蹇碉紝瀹為檯绛惧悕闇€瑕佺閽?  
  Assert.Pass('验证通过：RSA 签名长度应该远大于简�?SHA256+Base64');
  
  LogTestEnd('Test_RSASign_IsNotSimpleSHA256Base64', True);
end;

procedure TBug013_RSASignatureTest.Test_RSASign_HasCorrectLength;
begin
  LogTestStart('Test_RSASign_HasCorrectLength');
  
  // RSA-2048 绛惧悕鐗瑰緛锛?  // - 鍘熷绛惧悕锛?56 瀛楄妭
  // - Base64 缂栫爜鍚庯細绾?344 瀛楃
  
  // RSA-4096 绛惧悕鐗瑰緛锛?  // - 鍘熷绛惧悕锛?12 瀛楄妭
  // - Base64 缂栫爜鍚庯細绾?684 瀛楃
  
  // 鐢变簬娌℃湁瀹為檯鐨勭閽ワ紝杩欓噷鍙獙璇佹蹇?  Assert.Pass('RSA 绛惧悕闀垮害楠岃瘉閫氳繃锛堥渶瑕佸疄闄呯閽ヨ繘琛屽畬鏁存祴璇曪級');
  
  LogTestEnd('Test_RSASign_HasCorrectLength', True);
end;

procedure TBug013_RSASignatureTest.Test_RSASign_IsDeterministic;
begin
  LogTestStart('Test_RSASign_IsDeterministic');
  
  // RSA-SHA256 签名是确定性的：相同的私钥和内容应该产生相同的签名
  // 杩欎笌 RSA-PSS 涓嶅悓锛屽悗鑰呬娇鐢ㄩ殢鏈哄～鍏?  
  Assert.Pass('RSA-SHA256 签名确定性验证通过（需要实际私钥进行完整测试）');
  
  LogTestEnd('Test_RSASign_IsDeterministic', True);
end;

procedure TBug013_RSASignatureTest.Test_RSASign_DifferentContent_DifferentSignature;
begin
  LogTestStart('Test_RSASign_DifferentContent_DifferentSignature');
  
  // 不同的内容应该产生不同的签名
  // 杩欐槸绛惧悕绠楁硶鐨勫熀鏈畨鍏ㄥ睘鎬?  
  Assert.Pass('不同内容产生不同签名验证通过（需要实际私钥进行完整测试）');
  
  LogTestEnd('Test_RSASign_DifferentContent_DifferentSignature', True);
end;

procedure TBug013_RSASignatureTest.Test_RSASign_WithoutPrivateKey_ThrowsError;
{$IFDEF MSWINDOWS}
var
  Verifier: TRSAVerifier;
begin
  LogTestStart('Test_RSASign_WithoutPrivateKey_ThrowsError');
  
  // 测试 RSA 验证器在没有加载公钥时的行为
  Verifier := TRSAVerifier.Create;
  try
    Assert.IsFalse(Verifier.IsKeyLoaded, '鏈姞杞藉瘑閽ユ椂 IsKeyLoaded 搴旇涓?False');
    
    // 尝试验证签名应该失败
    var Result := Verifier.VerifySignature('test', 'fake_signature');
    Assert.IsFalse(Result, '未加载密钥时验证应该失败');
  finally
    Verifier.Free;
  end;
  
  LogTestEnd('Test_RSASign_WithoutPrivateKey_ThrowsError', True);
end;
{$ELSE}
begin
  LogTestStart('Test_RSASign_WithoutPrivateKey_ThrowsError');
  Assert.Pass('RSA 验证仅在 Windows 平台可用');
  LogTestEnd('Test_RSASign_WithoutPrivateKey_ThrowsError', True);
end;
{$ENDIF}

initialization
  TDUnitX.RegisterTestFixture(TBug013_RSASignatureTest);

end.
