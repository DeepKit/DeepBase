unit Test.DeepBase.Payment;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  DUnitX.TestFramework,
  DeepBase.Payment,
  DeepBase.Payment.Alipay,
  DeepBase.Payment.WeChatPay,
  DeepBase.Payment.PayPal;

type
  /// <summary>
  /// Tests for TPaymentOrder record.
  /// </summary>
  [TestFixture]
  TPaymentOrderTests = class
  public
    [Test]
    procedure Test_Clear_Sets_Defaults;

    [Test]
    procedure Test_Validate_ThrowsOnMissingOrderNo;

    [Test]
    procedure Test_Validate_ThrowsOnInvalidAmount;

    [Test]
    procedure Test_Validate_ThrowsOnMissingSubject;

    [Test]
    procedure Test_Validate_PassesWithValidData;
  end;

  /// <summary>
  /// Tests for TPaymentResult record.
  /// </summary>
  [TestFixture]
  TPaymentResultTests = class
  public
    [Test]
    procedure Test_Clear_Sets_Defaults;

    [Test]
    procedure Test_Fail_SetsErrorFields;

    [Test]
    procedure Test_Status_Enum_Values;
  end;

  /// <summary>
  /// Tests for TRefundRequest record.
  /// </summary>
  [TestFixture]
  TRefundRequestTests = class
  public
    [Test]
    procedure Test_Clear_Sets_Defaults;

    [Test]
    procedure Test_Validate_ThrowsOnMissingFields;

    [Test]
    procedure Test_Validate_ThrowsOnInvalidAmount;
  end;

  /// <summary>
  /// Tests for TPaymentHelper.
  /// </summary>
  [TestFixture]
  TPaymentHelperTests = class
  public
    [Test]
    procedure Test_StatusToString_AllValues;

    [Test]
    procedure Test_ProviderToString_AllValues;

    [Test]
    procedure Test_GenerateOrderNo_UniqueFormat;

    [Test]
    procedure Test_GenerateNonceStr_CorrectLength;

    [Test]
    procedure Test_MD5_Hash;

    [Test]
    procedure Test_SHA256_Hash;
  end;

  [TestFixture]
  TPaymentSignatureSecurityTests = class
  public
    [Test]
    procedure Test_Alipay_VerifySignature_DoesNotBypassInSandboxWithoutPublicKey;

    [Test]
    procedure Test_WeChat_VerifySignature_WithoutPublicKey_ReturnsFalse;

    [Test]
    procedure Test_PayPal_VerifySignature_RequiresTransmissionHeaders;

    [Test]
    procedure Test_PayPal_VerifyNotification_RejectsProductionWithoutHeaderContext;
  end;

implementation

type
  TTestableAlipayClient = class(TAlipayClient)
  public
    function PublicVerifySignature(const AParams: TDictionary<string, string>;
      const ASign: string): Boolean;
  end;

  TTestableWeChatPayClient = class(TWeChatPayClient)
  public
    function PublicVerifySignature(const AParams: TDictionary<string, string>;
      const ASign: string): Boolean;
  end;

  TTestablePayPalClient = class(TPayPalClient)
  public
    function PublicVerifySignature(const AParams: TDictionary<string, string>;
      const ASign: string): Boolean;
  end;

function TTestableAlipayClient.PublicVerifySignature(
  const AParams: TDictionary<string, string>; const ASign: string): Boolean;
begin
  Result := VerifySignature(AParams, ASign);
end;

function TTestableWeChatPayClient.PublicVerifySignature(
  const AParams: TDictionary<string, string>; const ASign: string): Boolean;
begin
  Result := VerifySignature(AParams, ASign);
end;

function TTestablePayPalClient.PublicVerifySignature(
  const AParams: TDictionary<string, string>; const ASign: string): Boolean;
begin
  Result := VerifySignature(AParams, ASign);
end;

{ TPaymentOrderTests }

procedure TPaymentOrderTests.Test_Clear_Sets_Defaults;
var
  Order: TPaymentOrder;
begin
  // Initialize to zero first to avoid garbage pointers
  FillChar(Order, SizeOf(Order), 0);

  // Set some values
  Order.OrderNo := 'TEST';
  Order.Amount := 100;

  Order.Clear;

  Assert.AreEqual('', Order.OrderNo);
  Assert.AreEqual('', Order.Subject);
  Assert.AreEqual('', Order.Body);
  Assert.AreEqual<Currency>(0, Order.Amount);
  Assert.AreEqual('CNY', Order.Currency);
  Assert.AreEqual(pmDefault, Order.PaymentMethod);
  Assert.AreEqual('', Order.NotifyUrl);
  Assert.AreEqual('', Order.ReturnUrl);
  Assert.AreEqual('', Order.SuccessUrl);
  Assert.AreEqual('', Order.CancelUrl);
  Assert.AreEqual(30, Order.ExpireMinutes);
  Assert.AreEqual('', Order.ClientIP);
end;

procedure TPaymentOrderTests.Test_Validate_ThrowsOnMissingOrderNo;
var
  Order: TPaymentOrder;
begin
  FillChar(Order, SizeOf(Order), 0);
  Order.Clear;
  Order.Amount := 100;
  Order.Subject := 'Test';

  Assert.WillRaise(
    procedure begin Order.Validate; end,
    EPaymentConfigError
  );
end;

procedure TPaymentOrderTests.Test_Validate_ThrowsOnInvalidAmount;
var
  Order: TPaymentOrder;
begin
  FillChar(Order, SizeOf(Order), 0);
  Order.Clear;
  Order.OrderNo := 'TEST001';
  Order.Subject := 'Test';
  Order.Amount := 0;

  Assert.WillRaise(
    procedure begin Order.Validate; end,
    EPaymentConfigError
  );
end;

procedure TPaymentOrderTests.Test_Validate_ThrowsOnMissingSubject;
var
  Order: TPaymentOrder;
begin
  FillChar(Order, SizeOf(Order), 0);
  Order.Clear;
  Order.OrderNo := 'TEST001';
  Order.Amount := 100;
  Order.Subject := '';

  Assert.WillRaise(
    procedure begin Order.Validate; end,
    EPaymentConfigError
  );
end;

procedure TPaymentOrderTests.Test_Validate_PassesWithValidData;
var
  Order: TPaymentOrder;
begin
  FillChar(Order, SizeOf(Order), 0);
  Order.Clear;
  Order.OrderNo := 'TEST001';
  Order.Amount := 100;
  Order.Subject := 'Test Product';

  // Should not raise
  Order.Validate;
  Assert.Pass;
end;

{ TPaymentResultTests }

procedure TPaymentResultTests.Test_Clear_Sets_Defaults;
var
  Res: TPaymentResult;
begin
  Res.Success := True;
  Res.ErrorCode := 'ERR';

  Res.Clear;

  Assert.IsFalse(Res.Success);
  Assert.AreEqual('', Res.OrderNo);
  Assert.AreEqual('', Res.TradeNo);
  Assert.AreEqual('', Res.ErrorCode);
  Assert.AreEqual('', Res.ErrorMessage);
  Assert.AreEqual('', Res.PayUrl);
  Assert.AreEqual('', Res.QRCodeUrl);
  Assert.AreEqual('', Res.QRCodeData);
  Assert.AreEqual('', Res.PrepayId);
  Assert.AreEqual('', Res.AppPayParams);
end;

procedure TPaymentResultTests.Test_Fail_SetsErrorFields;
var
  Res: TPaymentResult;
begin
  Res := TPaymentResult.Fail('E001', 'Test error');

  Assert.IsFalse(Res.Success);
  Assert.AreEqual('E001', Res.ErrorCode);
  Assert.AreEqual('Test error', Res.ErrorMessage);
end;

procedure TPaymentResultTests.Test_Status_Enum_Values;
begin
  // Verify enum values for proper serialization
  Assert.AreEqual(0, Ord(psUnknown));
  Assert.AreEqual(1, Ord(psPending));
  Assert.AreEqual(2, Ord(psSuccess));
  Assert.AreEqual(3, Ord(psFailed));
  Assert.AreEqual(4, Ord(psClosed));
  Assert.AreEqual(5, Ord(psRefunding));
  Assert.AreEqual(6, Ord(psRefunded));
  Assert.AreEqual(7, Ord(psPartialRefund));
end;

{ TRefundRequestTests }

procedure TRefundRequestTests.Test_Clear_Sets_Defaults;
var
  Req: TRefundRequest;
begin
  Req.Clear;
  Assert.AreEqual('', Req.OrderNo);
  Assert.AreEqual('', Req.RefundNo);
  Assert.AreEqual<Currency>(0, Req.RefundAmount);
  Assert.AreEqual<Currency>(0, Req.TotalAmount);
  Assert.AreEqual('', Req.Reason);
  Assert.AreEqual('', Req.NotifyUrl);
end;

procedure TRefundRequestTests.Test_Validate_ThrowsOnMissingFields;
var
  Req: TRefundRequest;
begin
  Req.Clear;
  Req.RefundAmount := 50;

  // Missing OrderNo
  Assert.WillRaise(
    procedure begin Req.Validate; end,
    EPaymentConfigError
  );

  Req.OrderNo := 'TEST001';
  // Missing RefundNo
  Assert.WillRaise(
    procedure begin Req.Validate; end,
    EPaymentConfigError
  );
end;

procedure TRefundRequestTests.Test_Validate_ThrowsOnInvalidAmount;
var
  Req: TRefundRequest;
begin
  Req.Clear;
  Req.OrderNo := 'TEST001';
  Req.RefundNo := 'REFUND001';
  Req.RefundAmount := 0;

  Assert.WillRaise(
    procedure begin Req.Validate; end,
    EPaymentConfigError
  );
end;

{ TPaymentHelperTests }

procedure TPaymentHelperTests.Test_StatusToString_AllValues;
begin
  Assert.AreEqual('UNKNOWN', TPaymentHelper.StatusToString(psUnknown));
  Assert.AreEqual('PENDING', TPaymentHelper.StatusToString(psPending));
  Assert.AreEqual('SUCCESS', TPaymentHelper.StatusToString(psSuccess));
  Assert.AreEqual('FAILED', TPaymentHelper.StatusToString(psFailed));
  Assert.AreEqual('CLOSED', TPaymentHelper.StatusToString(psClosed));
  Assert.AreEqual('REFUNDING', TPaymentHelper.StatusToString(psRefunding));
  Assert.AreEqual('REFUNDED', TPaymentHelper.StatusToString(psRefunded));
  Assert.AreEqual('PARTIAL_REFUND', TPaymentHelper.StatusToString(psPartialRefund));
end;

procedure TPaymentHelperTests.Test_ProviderToString_AllValues;
begin
  Assert.AreEqual('Alipay', TPaymentHelper.ProviderToString(ppAlipay));
  Assert.AreEqual('WeChatPay', TPaymentHelper.ProviderToString(ppWeChatPay));
  Assert.AreEqual('Stripe', TPaymentHelper.ProviderToString(ppStripe));
  Assert.AreEqual('PayPal', TPaymentHelper.ProviderToString(ppPayPal));
end;

procedure TPaymentHelperTests.Test_GenerateOrderNo_UniqueFormat;
var
  No1, No2: string;
begin
  No1 := TPaymentHelper.GenerateOrderNo('TEST');
  Assert.IsTrue(No1.StartsWith('TEST'), 'Should start with prefix');
  Assert.IsTrue(Length(No1) > 10, 'Should include timestamp/random');

  No2 := TPaymentHelper.GenerateOrderNo('TEST');
  Assert.AreNotEqual(No1, No2, 'Should generate unique numbers');
end;

procedure TPaymentHelperTests.Test_GenerateNonceStr_CorrectLength;
var
  S: string;
  C: Char;
begin
  S := TPaymentHelper.GenerateNonceStr(16);
  Assert.AreEqual(16, Integer(Length(S)));
  for C in S do
    Assert.IsTrue(CharInSet(C, ['A'..'Z', 'a'..'z', '0'..'9']));

  S := TPaymentHelper.GenerateNonceStr(32);
  Assert.AreEqual(32, Integer(Length(S)));
  for C in S do
    Assert.IsTrue(CharInSet(C, ['A'..'Z', 'a'..'z', '0'..'9']));

  S := TPaymentHelper.GenerateNonceStr; // Default 32
  Assert.AreEqual(32, Integer(Length(S)));
  for C in S do
    Assert.IsTrue(CharInSet(C, ['A'..'Z', 'a'..'z', '0'..'9']));

  Assert.AreEqual('', TPaymentHelper.GenerateNonceStr(0));
end;

procedure TPaymentHelperTests.Test_MD5_Hash;
var
  Hash: string;
begin
  Hash := TPaymentHelper.MD5('test');
  Assert.AreEqual('098f6bcd4621d373cade4e832627b4f6', Hash.ToLower);
end;

procedure TPaymentHelperTests.Test_SHA256_Hash;
var
  Hash: string;
begin
  Hash := TPaymentHelper.SHA256('test');
  Assert.AreEqual('9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08', Hash.ToLower);
end;

{ TPaymentSignatureSecurityTests }

procedure TPaymentSignatureSecurityTests.Test_Alipay_VerifySignature_DoesNotBypassInSandboxWithoutPublicKey;
var
  Config: TAlipayConfig;
  Client: TTestableAlipayClient;
  Params: TDictionary<string, string>;
begin
  Config := TAlipayConfig.Create;
  try
    Config.IsSandbox := True;
    Config.AlipayPublicKey := '';
    Client := TTestableAlipayClient.Create(Config);
    try
      Params := TDictionary<string, string>.Create;
      try
        Params.Add('out_trade_no', 'T20260503');
        Params.Add('total_amount', '1.00');
        Assert.IsFalse(Client.PublicVerifySignature(Params, 'fake-signature'));
      finally
        Params.Free;
      end;
    finally
      Client.Free;
    end;
  finally
    Config.Free;
  end;
end;

procedure TPaymentSignatureSecurityTests.Test_WeChat_VerifySignature_WithoutPublicKey_ReturnsFalse;
var
  Config: TWeChatPayConfig;
  Client: TTestableWeChatPayClient;
  Params: TDictionary<string, string>;
begin
  Config := TWeChatPayConfig.Create;
  try
    Config.WeChatPublicKey := '';
    Client := TTestableWeChatPayClient.Create(Config);
    try
      Params := TDictionary<string, string>.Create;
      try
        Params.Add('appid', 'wx_test');
        Params.Add('mchid', 'mch_test');
        Assert.IsFalse(Client.PublicVerifySignature(Params, 'fake-signature'));
      finally
        Params.Free;
      end;
    finally
      Client.Free;
    end;
  finally
    Config.Free;
  end;
end;

procedure TPaymentSignatureSecurityTests.Test_PayPal_VerifySignature_RequiresTransmissionHeaders;
var
  Config: TPayPalConfig;
  Client: TTestablePayPalClient;
  Params: TDictionary<string, string>;
begin
  Config := TPayPalConfig.Create;
  try
    Config.WebhookId := 'wh_test_001';
    Client := TTestablePayPalClient.Create(Config);
    try
      Params := TDictionary<string, string>.Create;
      try
        Params.Add('payload', '{"id":"evt_test"}');
        // 缺少 transmission_id / transmission_time，应拒绝
        Assert.IsFalse(Client.PublicVerifySignature(Params, 'fake-signature'));
      finally
        Params.Free;
      end;
    finally
      Client.Free;
    end;
  finally
    Config.Free;
  end;
end;

procedure TPaymentSignatureSecurityTests.Test_PayPal_VerifyNotification_RejectsProductionWithoutHeaderContext;
var
  Config: TPayPalConfig;
  Client: TPayPalClient;
  Notification: TPaymentNotification;
begin
  Config := TPayPalConfig.Create;
  try
    Config.IsSandbox := False;
    Config.WebhookId := 'wh_test_002';
    Client := TPayPalClient.Create(Config);
    try
      Assert.IsFalse(Client.VerifyNotification('{"event_type":"CHECKOUT.ORDER.COMPLETED"}',
        Notification));
    finally
      Client.Free;
    end;
  finally
    Config.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TPaymentOrderTests);
  TDUnitX.RegisterTestFixture(TPaymentResultTests);
  TDUnitX.RegisterTestFixture(TRefundRequestTests);
  TDUnitX.RegisterTestFixture(TPaymentHelperTests);
  TDUnitX.RegisterTestFixture(TPaymentSignatureSecurityTests);

end.
