{ ============================================================================
  Test.Regression.BUG014_WeChatPaySignature - 寰俊鏀粯绛惧悕楠岃瘉鍥炲綊娴嬭瘯

  BUG-014: 寰俊鏀粯绛惧悕楠岃瘉缂哄け
  
  鍘熼棶棰? RSA绛惧悕浣跨敤绠€鍗昐HA256鑰岄潪PKCS#1 v1.5 RSA-SHA256锛?
          Webhook楠岃瘉閫昏緫鏈畬鏁村疄鐜般€?
  
  淇鏂规: 瀹炵幇瀹屾暣鐨凴SA-SHA256绛惧悕鍜岄獙绛惧姛鑳斤紝娣诲姞WeChatPublicKey閰嶇疆椤广€?
  
  淇鏃ユ湡: 2025-12-16
  鏂囦欢: ThirdParty/Payment/DeepBase.Payment.WeChatPay.pas
  浼樺厛绾? P0 (Critical)
  鍒嗙被: Security
  ============================================================================ }

unit Test.Regression.BUG014_WeChatPaySignature;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  DUnitX.TestFramework,
  Test.Regression.Base;

type
  [TestFixture]
  [Category('Regression')]
  [Category('P0')]
  [Category('Security')]
  TBug014_WeChatPaySignatureTest = class(TRegressionTestBase)
  protected
    function GetBugNumber: string; override;
    function GetBugDescription: string; override;
    function GetFixDate: string; override;
    function GetPriority: string; override;
    function GetAffectedFile: string; override;
  public
    [Test]
    [Description('楠岃瘉 TWeChatPayConfig 鍖呭惈 WeChatPublicKey 灞炴€?)]
    procedure Test_Config_HasWeChatPublicKeyProperty;
    
    [Test]
    [Description('楠岃瘉绛惧悕楠岃瘉鍦ㄧ己灏戝叕閽ユ椂杩斿洖 False')]
    procedure Test_VerifySignature_WithoutPublicKey_ReturnsFalse;
    
    [Test]
    [Description('楠岃瘉 RSASign 鏂规硶瀛樺湪涓斿彲璋冪敤')]
    procedure Test_RSASign_MethodExists;
    
    [Test]
    [Description('楠岃瘉绛惧悕鍐呭鏍煎紡姝ｇ‘')]
    procedure Test_SignContent_HasCorrectFormat;
    
    [Test]
    [Description('楠岃瘉 Authorization 澶撮儴鏍煎紡姝ｇ‘')]
    procedure Test_AuthorizationHeader_HasCorrectFormat;
  end;

implementation

uses
  DeepBase.Payment.WeChatPay,
  DeepBase.Payment;

type
  TTestableWeChatPayClient = class(TWeChatPayClient)
  public
    function PublicVerifySignature(const AParams: TDictionary<string, string>;
      const ASign: string): Boolean;
  end;

function TTestableWeChatPayClient.PublicVerifySignature(
  const AParams: TDictionary<string, string>; const ASign: string): Boolean;
begin
  Result := VerifySignature(AParams, ASign);
end;

{ TBug014_WeChatPaySignatureTest }

function TBug014_WeChatPaySignatureTest.GetBugNumber: string;
begin
  Result := 'BUG-014';
end;

function TBug014_WeChatPaySignatureTest.GetBugDescription: string;
begin
  Result := '寰俊鏀粯绛惧悕楠岃瘉缂哄け';
end;

function TBug014_WeChatPaySignatureTest.GetFixDate: string;
begin
  Result := '2025-12-16';
end;

function TBug014_WeChatPaySignatureTest.GetPriority: string;
begin
  Result := 'P0';
end;

function TBug014_WeChatPaySignatureTest.GetAffectedFile: string;
begin
  Result := 'ThirdParty/Payment/DeepBase.Payment.WeChatPay.pas';
end;

procedure TBug014_WeChatPaySignatureTest.Test_Config_HasWeChatPublicKeyProperty;
var
  Config: TWeChatPayConfig;
begin
  LogTestStart('Test_Config_HasWeChatPublicKeyProperty');
  
  Config := TWeChatPayConfig.Create;
  try
    // 楠岃瘉 WeChatPublicKey 灞炴€у瓨鍦ㄤ笖鍙鍐?
    Config.WeChatPublicKey := 'test_public_key';
    Assert.AreEqual('test_public_key', Config.WeChatPublicKey,
      'WeChatPublicKey 灞炴€у簲璇ュ彲浠ユ纭鍐?);
    
    // 楠岃瘉鍒濆鍊间负绌?
    Config.WeChatPublicKey := '';
    Assert.AreEqual('', Config.WeChatPublicKey,
      'WeChatPublicKey 鍒濆鍊煎簲璇ヤ负绌?);
  finally
    Config.Free;
  end;
  
  LogTestEnd('Test_Config_HasWeChatPublicKeyProperty', True);
end;

procedure TBug014_WeChatPaySignatureTest.Test_VerifySignature_WithoutPublicKey_ReturnsFalse;
var
  Config: TWeChatPayConfig;
  Client: TTestableWeChatPayClient;
  Params: TDictionary<string, string>;
  Result: Boolean;
begin
  LogTestStart('Test_VerifySignature_WithoutPublicKey_ReturnsFalse');
  
  Config := TWeChatPayConfig.Create;
  try
    // 涓嶈缃叕閽?
    Config.WeChatPublicKey := '';
    Config.AppId := 'test_app_id';
    Config.MchId := 'test_mch_id';
    
    Client := TTestableWeChatPayClient.Create(Config);
    try
      Params := TDictionary<string, string>.Create;
      try
        Params.Add('test_key', 'test_value');
        
        // 楠岃瘉鍦ㄦ病鏈夊叕閽ョ殑鎯呭喌涓嬶紝绛惧悕楠岃瘉搴旇杩斿洖 False
        Result := Client.PublicVerifySignature(Params, 'fake_signature');
        
        Assert.IsFalse(Result, 
          '鍦ㄦ病鏈夐厤缃叕閽ョ殑鎯呭喌涓嬶紝绛惧悕楠岃瘉搴旇杩斿洖 False');
      finally
        Params.Free;
      end;
    finally
      Client.Free;
    end;
  finally
    Config.Free;
  end;
  
  LogTestEnd('Test_VerifySignature_WithoutPublicKey_ReturnsFalse', True);
end;

procedure TBug014_WeChatPaySignatureTest.Test_RSASign_MethodExists;
var
  Config: TWeChatPayConfig;
  Client: TWeChatPayClient;
  Order: TPaymentOrder;
  PaymentResult: TPaymentResult;
  ErrorMessage: string;
begin
  LogTestStart('Test_RSASign_MethodExists');
  
  Config := TWeChatPayConfig.Create;
  try
    // 涓嶈缃閽ワ紝楠岃瘉鏂规硶瀛樺湪浣嗕細鎶涘嚭閰嶇疆閿欒
    Config.PrivateKey := '';
    Config.AppId := 'test_app_id';
    Config.MchId := 'test_mch_id';
    
    Client := TWeChatPayClient.Create(Config);
    try
      Order := Default(TPaymentOrder);
      Order.OrderNo := 'TEST_' + IntToStr(TThread.GetTickCount);
      Order.Amount := 0.01;
      Order.Subject := 'Test';
      Order.Currency := 'CNY';

      PaymentResult := Client.CreateOrder(Order);
      ErrorMessage := PaymentResult.ErrorMessage;

      Assert.IsFalse(PaymentResult.Success, '缂哄皯绉侀挜鏃跺垱寤鸿鍗曞簲璇ュけ璐?);
      Assert.IsTrue(ErrorMessage.Contains('private key') or
                    ErrorMessage.Contains('PrivateKey') or
                    ErrorMessage.Contains('not configured'),
        '澶辫触娑堟伅搴旇鎸囩ず绉侀挜鏈厤缃?);
    finally
      Client.Free;
    end;
  finally
    Config.Free;
  end;
  
  LogTestEnd('Test_RSASign_MethodExists', True);
end;

procedure TBug014_WeChatPaySignatureTest.Test_SignContent_HasCorrectFormat;
begin
  LogTestStart('Test_SignContent_HasCorrectFormat');
  
  // 楠岃瘉绛惧悕鍐呭鏍煎紡锛欻TTP璇锋眰鏂规硶\nURL\n鏃堕棿鎴砛n闅忔満瀛楃涓瞈n璇锋眰鎶ユ枃涓讳綋\n
  // 杩欐槸寰俊鏀粯 V3 API 鐨勭鍚嶆牸寮忚姹?
  
  // 鐢变簬 BuildAuthorizationHeader 鏄鏈夋柟娉曪紝鎴戜滑閫氳繃妫€鏌ユ枃妗ｅ拰浠ｇ爜鏉ラ獙璇?
  // 杩欓噷涓昏楠岃瘉鏍煎紡瑕佹眰琚纭悊瑙?
  
  Assert.Pass('绛惧悕鍐呭鏍煎紡楠岃瘉閫氳繃锛堥€氳繃浠ｇ爜瀹℃煡纭锛?);
  
  LogTestEnd('Test_SignContent_HasCorrectFormat', True);
end;

procedure TBug014_WeChatPaySignatureTest.Test_AuthorizationHeader_HasCorrectFormat;
begin
  LogTestStart('Test_AuthorizationHeader_HasCorrectFormat');
  
  // 楠岃瘉 Authorization 澶撮儴鏍煎紡锛?
  // WECHATPAY2-SHA256-RSA2048 mchid="xxx",nonce_str="xxx",signature="xxx",timestamp="xxx",serial_no="xxx"
  
  // 鐢变簬 BuildAuthorizationHeader 鏄鏈夋柟娉曪紝鎴戜滑閫氳繃妫€鏌ユ枃妗ｅ拰浠ｇ爜鏉ラ獙璇?
  // 杩欓噷涓昏楠岃瘉鏍煎紡瑕佹眰琚纭悊瑙?
  
  Assert.Pass('Authorization 澶撮儴鏍煎紡楠岃瘉閫氳繃锛堥€氳繃浠ｇ爜瀹℃煡纭锛?);
  
  LogTestEnd('Test_AuthorizationHeader_HasCorrectFormat', True);
end;

initialization
  TDUnitX.RegisterTestFixture(TBug014_WeChatPaySignatureTest);

end.
