unit Test.DeepBase.Commerce.PaymentBridge;

interface

uses
  System.SysUtils,
  System.DateUtils,
  System.Generics.Collections,
  DUnitX.TestFramework,
  DeepBase.Commerce.Types,
  DeepBase.Commerce.Storage,
  DeepBase.Commerce.Service,
  DeepBase.Commerce.PaymentBridge,
  DeepBase.Payment,
  DeepBase.Payment.WeChatPay,
  DeepBase.Payment.PayPal;

type
  /// <summary>
  /// Provider stand-in that fills PaidAt with a local bare clock reading, the way
  /// the ThirdParty SDK does, so the bridge write convention is observable without
  /// any provider network call.
  /// </summary>
  TLocalClockPaymentClient = class(TInterfacedObject, IPaymentClient)
  private
    FPaidAt: TDateTime;
    function GetProvider: TPaymentProvider;
  public
    constructor Create(const APaidAt: TDateTime);
    function CreateOrder(const AOrder: TPaymentOrder): TPaymentResult;
    function QueryOrder(const AOrderNo: string): TPaymentQueryResult;
    function CloseOrder(const AOrderNo: string): Boolean;
    function Refund(const ARequest: TRefundRequest): TRefundResult;
    function QueryRefund(const ARefundNo: string): TRefundResult;
    function VerifyNotification(const ARawData: string;
      out ANotification: TPaymentNotification): Boolean;
    function GetNotificationResponse(ASuccess: Boolean): string;
    property Provider: TPaymentProvider read GetProvider;
  end;

  /// <summary>
  /// Tests for the PaidAt wire convention of TSDKNotificationVerifier: the local
  /// bare clock reading a provider supplies must leave the bridge as the Zulu UTC
  /// instant of that same moment.
  /// </summary>
  [TestFixture]
  TPaidAtWireConventionTests = class
  public
    [Test]
    procedure Test_PaidAtISO_IsZuluInstantOfLocalBarePaidAt;

    [Test]
    procedure Test_PaidAtISO_EmptyWhenProviderSuppliesNoPaidAt;
  end;

  /// <summary>
  /// Tests for CreateWeChatPayNotificationVerifier factory and the
  /// TSDKNotificationVerifier WeChat Pay V3 callback verification path.
  /// </summary>
  [TestFixture]
  TWeChatPayBridgeTests = class
  public
    [Test]
    procedure Test_Factory_CreatesVerifier;

    [Test]
    procedure Test_Factory_VerifierIsFunctional;

    [Test]
    procedure Test_VerifyNotification_RejectsEmptyBody;

    [Test]
    procedure Test_VerifyNotification_RejectsMalformedJson;

    [Test]
    procedure Test_VerifyNotification_RejectsMissingResource;

    [Test]
    procedure Test_VerifyNotification_RejectsEmptyCiphertext;

    [Test]
    procedure Test_VerifyNotification_RejectsBadAesGcmCiphertext;

    [Test]
    procedure Test_VerifyNotification_RejectsEmptySignatureHeaders;

    [Test]
    procedure Test_RegisterVerifier_WithService;
  end;

  /// <summary>
  /// REVIEW5-FEAT-002: CreatePayPalNotificationVerifier must wire WebhookId into
  /// the PayPal config so the verifier reaches the signature-verification stage
  /// instead of failing closed with MISSING_WEBHOOK_ID.
  /// </summary>
  [TestFixture]
  TPayPalBridgeTests = class
  public
    { The factory must accept a WebhookId and propagate it to the PayPal
      config. Verifying with a missing WebhookId fails closed. }
    [Test]
    procedure Test_Factory_WiresWebhookId_MissingConfigFailsClosed;

    { With WebhookId configured, the verifier must pass the MISSING_WEBHOOK_ID
      gate and reach the next guard (missing credentials) rather than failing
      on the webhook id itself. No network is touched: missing credentials make
      GetAccessToken raise immediately. }
    [Test]
    procedure Test_VerifyWebhookSignature_WithWebhookId_PassesIdGate;

    { Direct client-level regression: empty WebhookId raises MISSING_WEBHOOK_ID. }
    [Test]
    procedure Test_VerifyWebhookSignature_MissingWebhookId_RaisesConfigError;
  end;

implementation

{ TLocalClockPaymentClient }

constructor TLocalClockPaymentClient.Create(const APaidAt: TDateTime);
begin
  inherited Create;
  FPaidAt := APaidAt;
end;

function TLocalClockPaymentClient.GetProvider: TPaymentProvider;
begin
  Result := ppAlipay;
end;

function TLocalClockPaymentClient.CreateOrder(
  const AOrder: TPaymentOrder): TPaymentResult;
begin
  Result := TPaymentResult.Fail('NOT_IMPLEMENTED', 'Stub provider client');
end;

function TLocalClockPaymentClient.QueryOrder(
  const AOrderNo: string): TPaymentQueryResult;
begin
  Result.Clear;
  Result.Success := False;
  Result.ErrorCode := 'NOT_IMPLEMENTED';
end;

function TLocalClockPaymentClient.CloseOrder(const AOrderNo: string): Boolean;
begin
  Result := False;
end;

function TLocalClockPaymentClient.Refund(
  const ARequest: TRefundRequest): TRefundResult;
begin
  Result := TRefundResult.Fail('NOT_IMPLEMENTED', 'Stub provider client');
end;

function TLocalClockPaymentClient.QueryRefund(
  const ARefundNo: string): TRefundResult;
begin
  Result := TRefundResult.Fail('NOT_IMPLEMENTED', 'Stub provider client');
end;

function TLocalClockPaymentClient.VerifyNotification(const ARawData: string;
  out ANotification: TPaymentNotification): Boolean;
begin
  ANotification.Clear;
  ANotification.Provider := ppAlipay;
  ANotification.OrderNo := 'ORDER_PAIDAT_WIRE';
  ANotification.Status := psSuccess;
  ANotification.Amount := 12.34;
  ANotification.PaidAt := FPaidAt;
  ANotification.RawData := ARawData;
  Result := True;
end;

function TLocalClockPaymentClient.GetNotificationResponse(ASuccess: Boolean): string;
begin
  Result := 'success';
end;

{ TPaidAtWireConventionTests }

procedure TPaidAtWireConventionTests.Test_PaidAtISO_IsZuluInstantOfLocalBarePaidAt;
var
  PaidAtLocal: TDateTime;
  ExpectedUtc: TDateTime;
  Parsed: TDateTime;
  Client: TLocalClockPaymentClient;
  Verifier: ICommerceNotificationVerifier;
  Notification: TCommercePaymentNotification;
begin
  PaidAtLocal := EncodeDateTime(2031, 3, 1, 12, 0, 0, 0);
  ExpectedUtc := TTimeZone.Local.ToUniversalTime(PaidAtLocal);
  Client := TLocalClockPaymentClient.Create(PaidAtLocal);
  try
    Verifier := TSDKNotificationVerifier.Create(cppAlipay, Client, 'CNY');
    Notification := Verifier.VerifyNotification('{"stub":true}', []);
    Assert.IsTrue(Copy(Notification.PaidAtISO, Length(Notification.PaidAtISO), 1) = 'Z',
      'PaidAtISO must leave the bridge in Zulu form, got ' + Notification.PaidAtISO);
    Assert.IsTrue(TryISO8601ToDate(Notification.PaidAtISO, Parsed, True),
      'PaidAtISO must parse back as an ISO-8601 UTC instant');
    Assert.AreEqual(0.0, Abs((Parsed - ExpectedUtc) * 86400000), 0.001,
      'PaidAtISO must round-trip to the UTC instant of the clock reading the provider sent');
  finally
    Verifier := nil;
  end;
end;

procedure TPaidAtWireConventionTests.Test_PaidAtISO_EmptyWhenProviderSuppliesNoPaidAt;
var
  Client: TLocalClockPaymentClient;
  Verifier: ICommerceNotificationVerifier;
  Notification: TCommercePaymentNotification;
begin
  Client := TLocalClockPaymentClient.Create(0);
  try
    Verifier := TSDKNotificationVerifier.Create(cppAlipay, Client, 'CNY');
    Notification := Verifier.VerifyNotification('{"stub":true}', []);
    Assert.AreEqual('', Notification.PaidAtISO,
      'A provider that supplies no paid-at must leave the field empty');
  finally
    Verifier := nil;
  end;
end;

{ TWeChatPayBridgeTests }

procedure TWeChatPayBridgeTests.Test_Factory_CreatesVerifier;
var
  Verifier: ICommerceNotificationVerifier;
begin
  Verifier := CreateWeChatPayNotificationVerifier(
    'wx_test_appid', 'mch_test_001',
    '0123456789abcdef0123456789abcdef',
    '-----BEGIN PUBLIC KEY-----' + sLineBreak +
    'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA0Z3VS5JJcds3xfn/ygWy' + sLineBreak +
    'f8SgPT3bSOPTwlDpn8OwWAk1K0fqf2M/4xOBG8wfyQq8J3hkqD3/bFZhs3mRZmLn' + sLineBreak +
    'q6NgdS7GKBA8UqwN0WKRH5BMH3kq+6UvKTfpSRLy/rvU0cPoK8RiVnwDd8N3mMHZ' + sLineBreak +
    'PiUmBuJjHt2hA7M8O7z0YKBN5D1hLBkm7a5L7X4Q+ZMD0pwTTfWxOmRV9n7htcF1' + sLineBreak +
    'X5h3c4KTy4GWDdSp7J2D54U0dCTQwwP4DA/KAyE9zF8VKj51C5LREP5h7k6Eb5Ui' + sLineBreak +
    'RMZ9S5dG4e14AO8/0DWAF05g8LlFWbOB4hwvO8h/2E6VCGvpQIDAQAB' + sLineBreak +
    '-----END PUBLIC KEY-----');
  Assert.IsNotNull(Verifier, 'Factory should create a non-nil verifier');
end;

procedure TWeChatPayBridgeTests.Test_Factory_VerifierIsFunctional;
var
  Verifier: ICommerceNotificationVerifier;
  Ex: Exception;
begin
  // The verifier should be functional and reject invalid data rather than
  // raising a construction-time error (no longer fails closed)
  Verifier := CreateWeChatPayNotificationVerifier(
    'wx_test_appid', 'mch_test_001',
    '0123456789abcdef0123456789abcdef', '');
  Assert.IsNotNull(Verifier);
  // Empty body should be rejected gracefully (not crash)
  Ex := nil;
  try
    Verifier.VerifyNotification('', []);
  except
    on E: EDeepBaseCommercePaymentError do
      Ex := E;
  end;
  Assert.IsNotNull(Ex, 'Empty body should raise EDeepBaseCommercePaymentError');
end;

procedure TWeChatPayBridgeTests.Test_VerifyNotification_RejectsEmptyBody;
var
  Verifier: ICommerceNotificationVerifier;
begin
  Verifier := CreateWeChatPayNotificationVerifier(
    'wx_test', 'mch_test', 'key_01234567890123456789012345', '');
  Assert.WillRaiseWithMessage(
    procedure begin
      Verifier.VerifyNotification('', []);
    end,
    EDeepBaseCommercePaymentError);
end;

procedure TWeChatPayBridgeTests.Test_VerifyNotification_RejectsMalformedJson;
var
  Verifier: ICommerceNotificationVerifier;
begin
  Verifier := CreateWeChatPayNotificationVerifier(
    'wx_test', 'mch_test', 'key_01234567890123456789012345', '');
  Assert.WillRaiseWithMessage(
    procedure begin
      Verifier.VerifyNotification('this is not json', []);
    end,
    EDeepBaseCommercePaymentError);
end;

procedure TWeChatPayBridgeTests.Test_VerifyNotification_RejectsMissingResource;
var
  Verifier: ICommerceNotificationVerifier;
begin
  Verifier := CreateWeChatPayNotificationVerifier(
    'wx_test', 'mch_test', 'key_01234567890123456789012345', '');
  Assert.WillRaiseWithMessage(
    procedure begin
      Verifier.VerifyNotification('{"event_type":"TRANSACTION.SUCCESS"}', []);
    end,
    EDeepBaseCommercePaymentError);
end;

procedure TWeChatPayBridgeTests.Test_VerifyNotification_RejectsEmptyCiphertext;
var
  Verifier: ICommerceNotificationVerifier;
begin
  Verifier := CreateWeChatPayNotificationVerifier(
    'wx_test', 'mch_test', 'key_01234567890123456789012345', '');
  Assert.WillRaiseWithMessage(
    procedure begin
      Verifier.VerifyNotification(
        '{"event_type":"TRANSACTION.SUCCESS","resource":{"ciphertext":"","nonce":"abc","associated_data":""}}',
        []);
    end,
    EDeepBaseCommercePaymentError);
end;

procedure TWeChatPayBridgeTests.Test_VerifyNotification_RejectsBadAesGcmCiphertext;
var
  Verifier: ICommerceNotificationVerifier;
begin
  Verifier := CreateWeChatPayNotificationVerifier(
    'wx_test', 'mch_test', 'key_01234567890123456789012345', '');
  // Valid JSON structure but garbage ciphertext that cannot be decrypted
  Assert.WillRaiseWithMessage(
    procedure begin
      Verifier.VerifyNotification(
        '{"event_type":"TRANSACTION.SUCCESS","resource":{' +
        '"ciphertext":"bm90X3ZhbGlkX2Flc19nY21fY2lwaGVydGV4dA==",' +
        '"nonce":"test_nonce_123","associated_data":"test"}}',
        []);
    end,
    EDeepBaseCommercePaymentError);
end;

procedure TWeChatPayBridgeTests.Test_VerifyNotification_RejectsEmptySignatureHeaders;
var
  Verifier: ICommerceNotificationVerifier;
  Headers: TArray<TPair<string, string>>;
begin
  // When a public key IS configured but no signature headers are provided,
  // the verifier should still fail (signature verification is mandatory)
  Verifier := CreateWeChatPayNotificationVerifier(
    'wx_test', 'mch_test', 'key_01234567890123456789012345',
    '-----BEGIN PUBLIC KEY-----' + sLineBreak +
    'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA0Z3VS5JJcds3xfn/ygWy' + sLineBreak +
    'f8SgPT3bSOPTwlDpn8OwWAk1K0fqf2M/4xOBG8wfyQq8J3hkqD3/bFZhs3mRZmLn' + sLineBreak +
    'q6NgdS7GKBA8UqwN0WKRH5BMH3kq+6UvKTfpSRLy/rvU0cPoK8RiVnwDd8N3mMHZ' + sLineBreak +
    'PiUmBuJjHt2hA7M8O7z0YKBN5D1hLBkm7a5L7X4Q+ZMD0pwTTfWxOmRV9n7htcF1' + sLineBreak +
    'X5h3c4KTy4GWDdSp7J2D54U0dCTQwwP4DA/KAyE9zF8VKj51C5LREP5h7k6Eb5Ui' + sLineBreak +
    'RMZ9S5dG4e14AO8/0DWAF05g8LlFWbOB4hwvO8h/2E6VCGvpQIDAQAB' + sLineBreak +
    '-----END PUBLIC KEY-----');

  // Build valid-looking headers but with an invalid signature
  SetLength(Headers, 3);
  Headers[0] := TPair<string, string>.Create('Wechatpay-Timestamp', '1234567890');
  Headers[1] := TPair<string, string>.Create('Wechatpay-Nonce', 'test_nonce');
  Headers[2] := TPair<string, string>.Create('Wechatpay-Signature', 'invalid_signature_base64');

  Assert.WillRaiseWithMessage(
    procedure begin
      Verifier.VerifyNotification('{"event_type":"TRANSACTION.SUCCESS"}', Headers);
    end,
    EDeepBaseCommercePaymentError);
end;

procedure TWeChatPayBridgeTests.Test_RegisterVerifier_WithService;
const
  RawBody = '{"resource":{"ciphertext":"stub"}}';
var
  Storage: ICommerceStorage;
  Service: TDeepBaseCommerceService;
  Verifier: ICommerceNotificationVerifier;
  Callback: TFunc<string, TArray<TPair<string, string>>, TCommercePaymentNotification>;
  DispatchCount: Integer;
  ForwardedBody: string;
  UnregisteredError: string;
  DispatchedError: string;
  ReplacedError: string;
begin
  // The verifier registry exposes no getter, so registration is only observable
  // through the service: an unregistered provider has to fail closed, and once a
  // verifier is registered that same instance has to be the one dispatched with the
  // payload forwarded. This is what pins the gateway key used on both sides.
  Storage := TInMemoryCommerceStorage.Create;
  Service := TDeepBaseCommerceService.Create(Storage);
  DispatchCount := 0;
  ForwardedBody := '';
  try
    try
      Service.VerifyAndConfirmPayment(cppWeChatPay, RawBody, []);
    except
      on E: EDeepBaseCommercePaymentError do
        UnregisteredError := E.Message;
    end;
    Assert.IsTrue(UnregisteredError.Contains('not registered'),
      'An unregistered provider must fail closed, got: ' + UnregisteredError);

    Callback :=
      function(ARawBody: string;
        AHeaders: TArray<TPair<string, string>>): TCommercePaymentNotification
      begin
        Inc(DispatchCount);
        ForwardedBody := ARawBody;
        raise EDeepBaseCommercePaymentError.Create('registered verifier dispatched');
      end;
    Verifier := TCallbackNotificationVerifier.Create(Callback);
    Service.RegisterNotificationVerifier(cppWeChatPay, Verifier);

    try
      Service.VerifyAndConfirmPayment(cppWeChatPay, RawBody, []);
    except
      on E: EDeepBaseCommercePaymentError do
        DispatchedError := E.Message;
    end;
    Assert.IsTrue(DispatchedError.Contains('registered verifier dispatched'),
      'The service must dispatch the verifier that was registered, got: ' + DispatchedError);
    Assert.AreEqual(1, DispatchCount,
      'One notification must reach the registered verifier exactly once');
    Assert.AreEqual(RawBody, ForwardedBody,
      'The raw notification body must reach the verifier unchanged');

    // Re-registering replaces the entry for that provider; the previous instance
    // must not stay in play. The factory verifier is used here because it is the
    // object this fixture is about.
    Verifier := CreateWeChatPayNotificationVerifier(
      'wx_test', 'mch_test', 'key_01234567890123456789012345', '');
    Service.RegisterNotificationVerifier(cppWeChatPay, Verifier);

    try
      Service.VerifyAndConfirmPayment(cppWeChatPay, '', []);
    except
      on E: EDeepBaseCommercePaymentError do
        ReplacedError := E.Message;
    end;
    Assert.IsFalse(ReplacedError.Contains('not registered'),
      'The factory verifier must have taken over the registration, got: ' + ReplacedError);
    Assert.AreEqual(1, DispatchCount,
      'A replaced verifier must no longer be dispatched');

    Assert.WillRaiseWithMessage(
      procedure begin
        Service.RegisterNotificationVerifier(cppWeChatPay, nil);
      end,
      EDeepBaseCommerceValidationError, 'Notification verifier is required',
      'Registering a nil verifier must be refused');
  finally
    Service.Free;
  end;
end;

{ TPayPalBridgeTests }

procedure TPayPalBridgeTests.Test_Factory_WiresWebhookId_MissingConfigFailsClosed;
var
  Verifier: ICommerceNotificationVerifier;
  Headers: TArray<TPair<string, string>>;
  RaisedClass: string;
  RaisedMsg: string;
  RaisedCode: string;
  Raised: Boolean;
begin
  // REVIEW5-FEAT-002: when WebhookId is NOT supplied via the factory, the
  // verifier must fail closed with MISSING_WEBHOOK_ID rather than silently
  // accepting or making a network call. No real HTTP is performed: the
  // MISSING_WEBHOOK_ID guard raises before any token request.
  Verifier := CreatePayPalNotificationVerifier('client_id_test', 'client_secret_test', '', 'USD');
  Assert.IsNotNull(Verifier, 'Factory should create a non-nil PayPal verifier');

  SetLength(Headers, 3);
  Headers[0] := TPair<string, string>.Create('Paypal-Transmission-Id', 'tx_id_test');
  Headers[1] := TPair<string, string>.Create('Paypal-Transmission-Time', '2026-06-30T00:00:00Z');
  Headers[2] := TPair<string, string>.Create('Paypal-Transmission-Sig', 'sig_test');

  Raised := False;
  RaisedClass := '';
  RaisedMsg := '';
  RaisedCode := '';
  try
    Verifier.VerifyNotification('{"event_type":"PAYMENT.CAPTURE.COMPLETED"}', Headers);
  except
    on E: EPaymentConfigError do
    begin
      Raised := True;
      RaisedClass := E.ClassName;
      RaisedMsg := E.Message;
      RaisedCode := E.ErrorCode;
    end;
    on E: EDeepBaseCommercePaymentError do
    begin
      // The SDKNotificationVerifier may wrap the underlying failure; either
      // error type is an acceptable fail-closed outcome but the underlying
      // code should still be MISSING_WEBHOOK_ID.
      Raised := True;
      RaisedClass := E.ClassName;
      RaisedMsg := E.Message;
    end;
  end;

  Assert.IsTrue(Raised, 'Missing WebhookId must fail closed (no exception raised)');
  Assert.IsTrue(
    (RaisedCode = 'MISSING_WEBHOOK_ID') or (Pos('MISSING_WEBHOOK_ID', RaisedMsg) > 0),
    'Missing WebhookId must fail closed with MISSING_WEBHOOK_ID (got class='
      + RaisedClass + ' msg=' + RaisedMsg + ' code=' + RaisedCode + ')');
end;

procedure TPayPalBridgeTests.Test_VerifyWebhookSignature_WithWebhookId_PassesIdGate;
var
  Config: TPayPalConfig;
  Client: TPayPalClient;
begin
  // REVIEW5-FEAT-002: with WebhookId configured, the verifier must get past
  // the MISSING_WEBHOOK_ID gate. We supply a WebhookId but leave
  // ClientID/ClientSecret empty so GetAccessToken raises MISSING_CREDENTIALS
  // immediately (no network). VerifyWebhookSignature catches EPaymentError and
  // returns False, proving the id gate was passed.
  Config := TPayPalConfig.Create;
  try
    Config.WebhookId := 'WH-2WR32450HC0233532-6RJ52350LH1234567';
    Client := TPayPalClient.Create(Config);
    try
      // Missing credentials => MISSING_CREDENTIALS raised by GetAccessToken,
      // caught inside VerifyWebhookSignature => Result False. No network call.
      Assert.IsFalse(
        Client.VerifyWebhookSignature(
          '{"event_type":"PAYMENT.CAPTURE.COMPLETED"}',
          'tx_id_test', '2026-06-30T00:00:00Z', 'sig_test', ''),
        'With WebhookId configured, the id gate is passed and the call returns '
        + 'False due to missing credentials (not MISSING_WEBHOOK_ID)');
    finally
      Client.Free;
    end;
  finally
    Config.Free;
  end;
end;

procedure TPayPalBridgeTests.Test_VerifyWebhookSignature_MissingWebhookId_RaisesConfigError;
var
  Config: TPayPalConfig;
  Client: TPayPalClient;
  RaisedClass: string;
  RaisedMsg: string;
  RaisedCode: string;
  Raised: Boolean;
begin
  // REVIEW5-FEAT-002: empty WebhookId is a hard configuration error.
  // NOTE: exception objects are auto-freed at the end of the except block, so
  // we capture the values we need inside the handler rather than holding the
  // object reference past it.
  Config := TPayPalConfig.Create;
  try
    Client := TPayPalClient.Create(Config);
    try
      Raised := False;
      RaisedClass := '';
      RaisedMsg := '';
      RaisedCode := '';
      try
        Client.VerifyWebhookSignature('{}', 'tx', 'ts', 'sig', '');
      except
        on E: EPaymentConfigError do
        begin
          Raised := True;
          RaisedClass := E.ClassName;
          RaisedMsg := E.Message;
          RaisedCode := E.ErrorCode;
        end;
        on E: Exception do
        begin
          Raised := True;
          RaisedClass := E.ClassName;
          RaisedMsg := E.Message;
        end;
      end;
      Assert.IsTrue(Raised, 'Empty WebhookId must raise an exception');
      Assert.AreEqual('EPaymentConfigError', RaisedClass,
        'Expected EPaymentConfigError but got ' + RaisedClass + ' / ' + RaisedMsg);
      Assert.AreEqual('MISSING_WEBHOOK_ID', RaisedCode,
        'Error code must be MISSING_WEBHOOK_ID (msg=' + RaisedMsg + ')');
    finally
      Client.Free;
    end;
  finally
    Config.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TPaidAtWireConventionTests);
  TDUnitX.RegisterTestFixture(TWeChatPayBridgeTests);
  TDUnitX.RegisterTestFixture(TPayPalBridgeTests);

end.
