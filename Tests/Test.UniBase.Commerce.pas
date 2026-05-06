unit Test.UniBase.Commerce;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.Net.URLClient,
  DUnitX.TestFramework,
  UniBase.Commerce.Types,
  UniBase.Commerce.Backend.Contract,
  UniBase.Commerce.Backend.Http,
  UniBase.Commerce.Storage,
  UniBase.Commerce.Service,
  UniBase.Commerce.PaymentBridge;

type
  [TestFixture]
  TCommerceServiceTests = class
  private
    FStorage: ICommerceStorage;
    FService: TUniBaseCommerceService;
    procedure RegisterProduct(const AProductId, ACode: string;
      AAmountMinor: Int64 = 9900; AQuota: Integer = -1);
    function EnsureUser: TCommerceUserData;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_EnsureUserForIdentity_IsIdempotent;

    [Test]
    procedure Test_CreateOrder_UsesProductPriceAndGeneratesOutTradeNo;

    [Test]
    procedure Test_BeginPayment_RequiresRegisteredGateway;

    [Test]
    procedure Test_BeginPayment_CreatesPendingPaymentIntent;

    [Test]
    procedure Test_ConfirmPayment_GrantsEntitlementIdempotently;

    [Test]
    procedure Test_ConfirmPayment_RejectsAmountMismatch;

    [Test]
    procedure Test_ConsumeEntitlement_DecrementsQuota;

    [Test]
    procedure Test_BackendContract_RoutesMatchSpec;

    [Test]
    procedure Test_BackendContract_JsonFieldsUseSnakeCase;

    [Test]
    procedure Test_HttpStorage_FindUserByIdentity_UsesContractRouteAndParsesUser;

    [Test]
    procedure Test_HttpStorage_CreateOrder_SendsSnakeCaseJsonAndAuthHeader;

    [Test]
    procedure Test_HttpPaymentGateway_CreatePaymentIntent_SendsBackendRequestAndParsesResponse;

    [Test]
    procedure Test_BeginPayment_WithHttpPaymentGateway_UsesBackendProxy;

    [Test]
    procedure Test_VerifyAndConfirmPayment_RequiresRegisteredVerifier;

    [Test]
    procedure Test_VerifyAndConfirmPayment_VerifiesAndConfirms;
  end;

implementation

type
  TFakePaymentGateway = class(TInterfacedObject, ICommercePaymentGateway)
  public
    function CreatePaymentIntent(const AOrder: TCommerceOrderData;
      const APayment: TCommercePaymentData; const APayerOpenId: string): TCommercePaymentIntent;
  end;

  TRecordedHttpRequest = record
    Method: string;
    Url: string;
    Body: string;
    Headers: TNetHeaders;
  end;

  TFakeCommerceTransport = class(TInterfacedObject, ICommerceBackendHttpTransport)
  private
    FRequests: TList<TRecordedHttpRequest>;
    FResponses: TQueue<TCommerceBackendHttpResponse>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure QueueResponse(AStatusCode: Integer; const ABody: string);
    function RequestCount: Integer;
    function RequestAt(AIndex: Integer): TRecordedHttpRequest;
    function Send(const AMethod, AUrl, ABody: string;
      const AHeaders: TNetHeaders): TCommerceBackendHttpResponse;
  end;

function TFakePaymentGateway.CreatePaymentIntent(const AOrder: TCommerceOrderData;
  const APayment: TCommercePaymentData; const APayerOpenId: string): TCommercePaymentIntent;
begin
  Result.Success := True;
  Result.PaymentId := APayment.PaymentId;
  Result.OutTradeNo := AOrder.OutTradeNo;
  Result.PrepayId := 'prepay_' + AOrder.OutTradeNo;
  Result.PayUrl := '';
  Result.QRCodeData := '';
  Result.ClientParamsJson := '{"prepay_id":"' + Result.PrepayId + '"}';
  Result.RawResponse := '{"ok":true}';
  Result.ErrorCode := '';
  Result.ErrorMessage := '';
end;

{ TFakeCommerceTransport }

constructor TFakeCommerceTransport.Create;
begin
  inherited Create;
  FRequests := TList<TRecordedHttpRequest>.Create;
  FResponses := TQueue<TCommerceBackendHttpResponse>.Create;
end;

destructor TFakeCommerceTransport.Destroy;
begin
  FResponses.Free;
  FRequests.Free;
  inherited;
end;

procedure TFakeCommerceTransport.QueueResponse(AStatusCode: Integer;
  const ABody: string);
begin
  FResponses.Enqueue(TCommerceBackendHttpResponse.Create(AStatusCode, ABody));
end;

function TFakeCommerceTransport.RequestCount: Integer;
begin
  Result := FRequests.Count;
end;

function TFakeCommerceTransport.RequestAt(AIndex: Integer): TRecordedHttpRequest;
begin
  Result := FRequests[AIndex];
end;

function TFakeCommerceTransport.Send(const AMethod, AUrl, ABody: string;
  const AHeaders: TNetHeaders): TCommerceBackendHttpResponse;
var
  Request: TRecordedHttpRequest;
begin
  Request.Method := AMethod;
  Request.Url := AUrl;
  Request.Body := ABody;
  Request.Headers := AHeaders;
  FRequests.Add(Request);

  if FResponses.Count = 0 then
    Exit(TCommerceBackendHttpResponse.Create(500, '{"error":"missing fake response"}'));
  Result := FResponses.Dequeue;
end;

function HeaderValue(const AHeaders: TNetHeaders; const AName: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AHeaders) do
    if SameText(AHeaders[I].Name, AName) then
      Exit(AHeaders[I].Value);
end;

{ TCommerceServiceTests }

procedure TCommerceServiceTests.Setup;
begin
  FStorage := TInMemoryCommerceStorage.Create;
  FService := TUniBaseCommerceService.Create(FStorage);
end;

procedure TCommerceServiceTests.TearDown;
begin
  FService.Free;
  FService := nil;
  FStorage := nil;
end;

procedure TCommerceServiceTests.RegisterProduct(const AProductId,
  ACode: string; AAmountMinor: Int64; AQuota: Integer);
var
  Product: TCommerceProductData;
begin
  Product := TCommerceProductData.Create(
    'desktop_tool', AProductId, 'Pro Plan', AAmountMinor, 'CNY', ACode, AQuota, 365);
  FService.RegisterProduct(Product);
end;

function TCommerceServiceTests.EnsureUser: TCommerceUserData;
begin
  Result := FService.EnsureUserForIdentity(
    capWeChatMiniProgram, 'openid_001', 'desktop_tool', 'union_001');
end;

procedure TCommerceServiceTests.Test_EnsureUserForIdentity_IsIdempotent;
var
  User1: TCommerceUserData;
  User2: TCommerceUserData;
begin
  User1 := EnsureUser;
  User2 := EnsureUser;

  Assert.AreEqual(User1.UserId, User2.UserId);
  Assert.IsTrue(User1.UserId.StartsWith('usr_'));
end;

procedure TCommerceServiceTests.Test_CreateOrder_UsesProductPriceAndGeneratesOutTradeNo;
var
  User: TCommerceUserData;
  Order: TCommerceOrderData;
begin
  RegisterProduct('pro_year', 'desktop.pro', 9900);
  User := EnsureUser;

  Order := FService.CreateOrder(User.UserId, 'desktop_tool', 'pro_year');

  Assert.IsTrue(Order.OrderId.StartsWith('ord_'));
  Assert.IsTrue(Order.OutTradeNo.StartsWith('UB'));
  Assert.AreEqual<Int64>(9900, Order.AmountMinor);
  Assert.AreEqual('CNY', Order.Currency);
  Assert.AreEqual(cosCreated, Order.Status);
end;

procedure TCommerceServiceTests.Test_BeginPayment_RequiresRegisteredGateway;
var
  User: TCommerceUserData;
  Order: TCommerceOrderData;
  Raised: Boolean;
begin
  RegisterProduct('pro_year', 'desktop.pro', 9900);
  User := EnsureUser;
  Order := FService.CreateOrder(User.UserId, 'desktop_tool', 'pro_year');

  Raised := False;
  try
    FService.BeginPayment(Order.OrderId, cppWeChatPay, cpcMiniProgram, 'openid_001');
  except
    on E: EUniBaseCommercePaymentError do
      Raised := True;
  end;
  Assert.IsTrue(Raised);
end;

procedure TCommerceServiceTests.Test_BeginPayment_CreatesPendingPaymentIntent;
var
  User: TCommerceUserData;
  Order: TCommerceOrderData;
  StoredOrder: TCommerceOrderData;
  Payment: TCommercePaymentData;
  Intent: TCommercePaymentIntent;
begin
  RegisterProduct('pro_year', 'desktop.pro', 9900);
  FService.RegisterPaymentGateway(cppWeChatPay, TFakePaymentGateway.Create);
  User := EnsureUser;
  Order := FService.CreateOrder(User.UserId, 'desktop_tool', 'pro_year');

  Intent := FService.BeginPayment(Order.OrderId, cppWeChatPay, cpcMiniProgram, 'openid_001');

  Assert.IsTrue(Intent.Success);
  Assert.AreEqual('prepay_' + Order.OutTradeNo, Intent.PrepayId);
  Assert.IsTrue(FStorage.FindOrderById(Order.OrderId, StoredOrder));
  Assert.AreEqual(cosPaying, StoredOrder.Status);
  Assert.IsTrue(FStorage.FindPaymentByOrderId(Order.OrderId, Payment));
  Assert.AreEqual(cpsPending, Payment.Status);
end;

procedure TCommerceServiceTests.Test_ConfirmPayment_GrantsEntitlementIdempotently;
var
  User: TCommerceUserData;
  Order: TCommerceOrderData;
  Notification: TCommercePaymentNotification;
  Entitlements: TCommerceEntitlementArray;
begin
  RegisterProduct('pro_year', 'desktop.pro', 9900);
  FService.RegisterPaymentGateway(cppWeChatPay, TFakePaymentGateway.Create);
  User := EnsureUser;
  Order := FService.CreateOrder(User.UserId, 'desktop_tool', 'pro_year');
  FService.BeginPayment(Order.OrderId, cppWeChatPay, cpcMiniProgram, 'openid_001');

  Notification.Provider := cppWeChatPay;
  Notification.OutTradeNo := Order.OutTradeNo;
  Notification.ProviderTradeNo := 'wx_trade_001';
  Notification.AmountMinor := Order.AmountMinor;
  Notification.Currency := Order.Currency;
  Notification.Success := True;
  Notification.PaidAtISO := CommerceNowISO;
  Notification.RawPayload := '{}';

  FService.ConfirmPayment(Notification);
  FService.ConfirmPayment(Notification);

  Assert.IsTrue(FService.HasEntitlement(User.UserId, 'desktop_tool', 'desktop.pro'));
  Entitlements := FService.ListEntitlements(User.UserId, 'desktop_tool');
  Assert.AreEqual<Integer>(1, Length(Entitlements));
end;

procedure TCommerceServiceTests.Test_ConfirmPayment_RejectsAmountMismatch;
var
  User: TCommerceUserData;
  Order: TCommerceOrderData;
  Notification: TCommercePaymentNotification;
  Raised: Boolean;
begin
  RegisterProduct('pro_year', 'desktop.pro', 9900);
  FService.RegisterPaymentGateway(cppWeChatPay, TFakePaymentGateway.Create);
  User := EnsureUser;
  Order := FService.CreateOrder(User.UserId, 'desktop_tool', 'pro_year');
  FService.BeginPayment(Order.OrderId, cppWeChatPay, cpcMiniProgram, 'openid_001');

  Notification.Provider := cppWeChatPay;
  Notification.OutTradeNo := Order.OutTradeNo;
  Notification.ProviderTradeNo := 'wx_trade_001';
  Notification.AmountMinor := Order.AmountMinor - 1;
  Notification.Currency := Order.Currency;
  Notification.Success := True;
  Notification.PaidAtISO := CommerceNowISO;
  Notification.RawPayload := '{}';

  Raised := False;
  try
    FService.ConfirmPayment(Notification);
  except
    on E: EUniBaseCommercePaymentError do
      Raised := True;
  end;
  Assert.IsTrue(Raised);
  Assert.IsFalse(FService.HasEntitlement(User.UserId, 'desktop_tool', 'desktop.pro'));
end;

procedure TCommerceServiceTests.Test_ConsumeEntitlement_DecrementsQuota;
var
  User: TCommerceUserData;
  Order: TCommerceOrderData;
  Notification: TCommercePaymentNotification;
begin
  RegisterProduct('assessment_once', 'assessment.report', 4900, 1);
  FService.RegisterPaymentGateway(cppWeChatPay, TFakePaymentGateway.Create);
  User := EnsureUser;
  Order := FService.CreateOrder(User.UserId, 'desktop_tool', 'assessment_once');
  FService.BeginPayment(Order.OrderId, cppWeChatPay, cpcMiniProgram, 'openid_001');

  Notification.Provider := cppWeChatPay;
  Notification.OutTradeNo := Order.OutTradeNo;
  Notification.ProviderTradeNo := 'wx_trade_002';
  Notification.AmountMinor := Order.AmountMinor;
  Notification.Currency := Order.Currency;
  Notification.Success := True;
  Notification.PaidAtISO := CommerceNowISO;
  Notification.RawPayload := '{}';
  FService.ConfirmPayment(Notification);

  Assert.IsTrue(FService.HasEntitlement(User.UserId, 'desktop_tool', 'assessment.report'));
  Assert.IsTrue(FService.ConsumeEntitlement(User.UserId, 'desktop_tool', 'assessment.report'));
  Assert.IsFalse(FService.HasEntitlement(User.UserId, 'desktop_tool', 'assessment.report'));
end;

procedure TCommerceServiceTests.Test_BackendContract_RoutesMatchSpec;
begin
  Assert.AreEqual('/commerce/users/usr_001',
    TCommerceBackendRoutes.UserById('usr_001'));
  Assert.AreEqual('/commerce/products/app_001/pro_year',
    TCommerceBackendRoutes.ProductById('app_001', 'pro_year'));
  Assert.AreEqual('/commerce/users/ensure', SCommerceRouteUsersEnsure);
  Assert.AreEqual('/commerce/orders', SCommerceRouteOrders);
  Assert.AreEqual('/commerce/orders/ord_001',
    TCommerceBackendRoutes.OrderById('ord_001'));
  Assert.AreEqual('/commerce/payments/intents', SCommerceRoutePaymentIntents);
  Assert.AreEqual('/commerce/payments/wechat_pay/notify',
    TCommerceBackendRoutes.PaymentNotify(cppWeChatPay));
  Assert.AreEqual('/commerce/entitlements', SCommerceRouteEntitlements);
  Assert.AreEqual('/commerce/entitlements/consume',
    SCommerceRouteEntitlementsConsume);
end;

procedure TCommerceServiceTests.Test_BackendContract_JsonFieldsUseSnakeCase;
begin
  Assert.AreEqual('provider_user_id', SCommerceFieldProviderUserId);
  Assert.AreEqual('out_trade_no', SCommerceFieldOutTradeNo);
  Assert.AreEqual('amount_minor', SCommerceFieldAmountMinor);
  Assert.AreEqual('provider_trade_no', SCommerceFieldProviderTradeNo);
  Assert.AreEqual('client_params_json', SCommerceFieldClientParamsJson);
  Assert.AreEqual('remaining_quota', SCommerceFieldRemainingQuota);
  Assert.AreEqual('error_code', SCommerceFieldErrorCode);
  Assert.AreEqual('error_message', SCommerceFieldErrorMessage);
end;

procedure TCommerceServiceTests.Test_HttpStorage_FindUserByIdentity_UsesContractRouteAndParsesUser;
var
  Transport: TFakeCommerceTransport;
  Storage: ICommerceStorage;
  User: TCommerceUserData;
  Request: TRecordedHttpRequest;
begin
  Transport := TFakeCommerceTransport.Create;
  Transport.QueueResponse(200,
    '{"user_id":"usr_001","display_name":"Tester","email":"","phone":"","is_active":true,"created_at":"2026-05-05T10:00:00","updated_at":"2026-05-05T10:00:00"}');
  Storage := TCommerceHttpStorage.Create(
    TCommerceBackendHttpConfig.Create('https://api.example.test/', 'token_123'),
    Transport);

  Assert.IsTrue(Storage.FindUserByIdentity(
    capWeChatMiniProgram, 'openid_001', 'desktop_tool', User));

  Assert.AreEqual('usr_001', User.UserId);
  Assert.AreEqual('Tester', User.DisplayName);
  Assert.AreEqual<Integer>(1, Transport.RequestCount);

  Request := Transport.RequestAt(0);
  Assert.AreEqual('GET', Request.Method);
  Assert.IsTrue(Request.Url.StartsWith(
    'https://api.example.test/commerce/users/by-identity?'));
  Assert.IsTrue(Pos('provider=wechat_mini_program', Request.Url) > 0);
  Assert.IsTrue(Pos('provider_user_id=openid_001', Request.Url) > 0);
  Assert.IsTrue(Pos('app_id=desktop_tool', Request.Url) > 0);
  Assert.AreEqual('', Request.Body);
  Assert.AreEqual('Bearer token_123', HeaderValue(Request.Headers, 'Authorization'));
end;

procedure TCommerceServiceTests.Test_HttpStorage_CreateOrder_SendsSnakeCaseJsonAndAuthHeader;
var
  Transport: TFakeCommerceTransport;
  Storage: ICommerceStorage;
  Order: TCommerceOrderData;
  Request: TRecordedHttpRequest;
begin
  Transport := TFakeCommerceTransport.Create;
  Transport.QueueResponse(201, '{}');
  Storage := TCommerceHttpStorage.Create(
    TCommerceBackendHttpConfig.Create('https://api.example.test', '', 'api_key_123'),
    Transport);

  Order.OrderId := 'ord_001';
  Order.UserId := 'usr_001';
  Order.AppId := 'desktop_tool';
  Order.ProductId := 'pro_year';
  Order.OutTradeNo := 'UB202605050001';
  Order.Title := 'Pro Plan';
  Order.AmountMinor := 9900;
  Order.Currency := 'CNY';
  Order.Status := cosCreated;
  Order.CreatedAtISO := '2026-05-05T10:00:00';
  Order.PaidAtISO := '';

  Storage.CreateOrder(Order);

  Assert.AreEqual<Integer>(1, Transport.RequestCount);
  Request := Transport.RequestAt(0);
  Assert.AreEqual('POST', Request.Method);
  Assert.AreEqual('https://api.example.test/commerce/orders', Request.Url);
  Assert.IsTrue(Pos('"order_id":"ord_001"', Request.Body) > 0);
  Assert.IsTrue(Pos('"out_trade_no":"UB202605050001"', Request.Body) > 0);
  Assert.IsTrue(Pos('"amount_minor":9900', Request.Body) > 0);
  Assert.IsTrue(Pos('"status":"created"', Request.Body) > 0);
  Assert.AreEqual('api_key_123', HeaderValue(Request.Headers, 'X-API-Key'));
end;

procedure TCommerceServiceTests.Test_HttpPaymentGateway_CreatePaymentIntent_SendsBackendRequestAndParsesResponse;
var
  Transport: TFakeCommerceTransport;
  Gateway: ICommercePaymentGateway;
  Order: TCommerceOrderData;
  Payment: TCommercePaymentData;
  Intent: TCommercePaymentIntent;
  Request: TRecordedHttpRequest;
begin
  Transport := TFakeCommerceTransport.Create;
  Transport.QueueResponse(200,
    '{"success":true,"payment_id":"pay_backend","out_trade_no":"UB202605050002","prepay_id":"wx_pre_001","pay_url":"https://pay.example/001","qr_code_data":"qr_001","client_params_json":"{\"package\":\"prepay_id=wx_pre_001\"}"}');
  Gateway := TCommerceHttpPaymentGateway.Create(
    TCommerceBackendHttpConfig.Create('https://api.example.test', 'token_123'),
    Transport);

  Order.OrderId := 'ord_001';
  Order.UserId := 'usr_001';
  Order.AppId := 'desktop_tool';
  Order.ProductId := 'pro_year';
  Order.OutTradeNo := 'UB202605050002';
  Order.Title := 'Pro Plan';
  Order.AmountMinor := 9900;
  Order.Currency := 'CNY';
  Order.Status := cosCreated;
  Order.CreatedAtISO := '2026-05-05T10:00:00';
  Order.PaidAtISO := '';

  Payment.PaymentId := 'pay_001';
  Payment.OrderId := Order.OrderId;
  Payment.Provider := cppWeChatPay;
  Payment.Channel := cpcMiniProgram;
  Payment.ProviderTradeNo := '';
  Payment.PrepayId := '';
  Payment.Status := cpsCreated;
  Payment.RawPayload := '';
  Payment.CreatedAtISO := '2026-05-05T10:00:00';
  Payment.PaidAtISO := '';

  Intent := Gateway.CreatePaymentIntent(Order, Payment, 'openid_001');

  Assert.IsTrue(Intent.Success);
  Assert.AreEqual('pay_backend', Intent.PaymentId);
  Assert.AreEqual('UB202605050002', Intent.OutTradeNo);
  Assert.AreEqual('wx_pre_001', Intent.PrepayId);
  Assert.AreEqual('https://pay.example/001', Intent.PayUrl);
  Assert.AreEqual('qr_001', Intent.QRCodeData);
  Assert.IsTrue(Pos('prepay_id=wx_pre_001', Intent.ClientParamsJson) > 0);

  Assert.AreEqual<Integer>(1, Transport.RequestCount);
  Request := Transport.RequestAt(0);
  Assert.AreEqual('POST', Request.Method);
  Assert.AreEqual('https://api.example.test/commerce/payments/intents',
    Request.Url);
  Assert.IsTrue(Pos('"order_id":"ord_001"', Request.Body) > 0);
  Assert.IsTrue(Pos('"payment_id":"pay_001"', Request.Body) > 0);
  Assert.IsTrue(Pos('"provider":"wechat_pay"', Request.Body) > 0);
  Assert.IsTrue(Pos('"channel":"mini_program"', Request.Body) > 0);
  Assert.IsTrue(Pos('"payer_open_id":"openid_001"', Request.Body) > 0);
  Assert.IsTrue(Pos('"amount_minor":9900', Request.Body) > 0);
  Assert.AreEqual('Bearer token_123', HeaderValue(Request.Headers, 'Authorization'));
  Assert.AreEqual('pay_001', HeaderValue(Request.Headers, 'Idempotency-Key'));
end;

procedure TCommerceServiceTests.Test_BeginPayment_WithHttpPaymentGateway_UsesBackendProxy;
var
  Transport: TFakeCommerceTransport;
  User: TCommerceUserData;
  Order: TCommerceOrderData;
  Intent: TCommercePaymentIntent;
  StoredOrder: TCommerceOrderData;
  StoredPayment: TCommercePaymentData;
  Request: TRecordedHttpRequest;
begin
  RegisterProduct('pro_year', 'desktop.pro', 9900);
  User := EnsureUser;
  Order := FService.CreateOrder(User.UserId, 'desktop_tool', 'pro_year');

  Transport := TFakeCommerceTransport.Create;
  Transport.QueueResponse(200,
    '{"success":true,"payment_id":"pay_backend","out_trade_no":"' +
    Order.OutTradeNo +
    '","prepay_id":"wx_pre_002","client_params_json":"{\"package\":\"prepay_id=wx_pre_002\"}"}');
  FService.RegisterPaymentGateway(cppWeChatPay,
    TCommerceHttpPaymentGateway.Create(
      TCommerceBackendHttpConfig.Create('https://api.example.test', '', 'api_key_123'),
      Transport));

  Intent := FService.BeginPayment(Order.OrderId, cppWeChatPay, cpcMiniProgram,
    'openid_001');

  Assert.IsTrue(Intent.Success);
  Assert.AreEqual('wx_pre_002', Intent.PrepayId);
  Assert.IsTrue(Intent.PaymentId.StartsWith('pay_'));
  Assert.AreEqual(Order.OutTradeNo, Intent.OutTradeNo);
  Assert.IsTrue(FStorage.FindOrderById(Order.OrderId, StoredOrder));
  Assert.AreEqual(cosPaying, StoredOrder.Status);
  Assert.IsTrue(FStorage.FindPaymentByOrderId(Order.OrderId, StoredPayment));
  Assert.AreEqual(cpsPending, StoredPayment.Status);
  Assert.AreEqual('wx_pre_002', StoredPayment.PrepayId);

  Assert.AreEqual<Integer>(1, Transport.RequestCount);
  Request := Transport.RequestAt(0);
  Assert.AreEqual('https://api.example.test/commerce/payments/intents',
    Request.Url);
  Assert.IsTrue(Pos('"out_trade_no":"' + Order.OutTradeNo + '"', Request.Body) > 0);
  Assert.AreEqual('api_key_123', HeaderValue(Request.Headers, 'X-API-Key'));
  Assert.IsTrue(HeaderValue(Request.Headers, 'Idempotency-Key').StartsWith('pay_'));
end;

procedure TCommerceServiceTests.Test_VerifyAndConfirmPayment_RequiresRegisteredVerifier;
var
  User: TCommerceUserData;
  Order: TCommerceOrderData;
  Raised: Boolean;
begin
  RegisterProduct('pro_year', 'desktop.pro', 9900);
  User := EnsureUser;
  Order := FService.CreateOrder(User.UserId, 'desktop_tool', 'pro_year');

  Raised := False;
  try
    FService.VerifyAndConfirmPayment(cppWeChatPay, '{}', nil);
  except
    on E: EUniBaseCommercePaymentError do
      Raised := True;
  end;
  Assert.IsTrue(Raised);
end;

procedure TCommerceServiceTests.Test_VerifyAndConfirmPayment_VerifiesAndConfirms;
var
  User: TCommerceUserData;
  Order: TCommerceOrderData;
  ConfirmedOrder: TCommerceOrderData;
  Verifier: ICommerceNotificationVerifier;
begin
  RegisterProduct('pro_year', 'desktop.pro', 9900);
  FService.RegisterPaymentGateway(cppWeChatPay, TFakePaymentGateway.Create);
  User := EnsureUser;
  Order := FService.CreateOrder(User.UserId, 'desktop_tool', 'pro_year');
  FService.BeginPayment(Order.OrderId, cppWeChatPay, cpcMiniProgram, 'openid_001');

  Verifier := TCallbackNotificationVerifier.Create(
    function(const ARawBody: string;
      const AHeaders: TArray<TPair<string, string>>): TCommercePaymentNotification
    begin
      Result.Provider := cppWeChatPay;
      Result.OutTradeNo := Order.OutTradeNo;
      Result.ProviderTradeNo := 'wx_trade_003';
      Result.AmountMinor := Order.AmountMinor;
      Result.Currency := Order.Currency;
      Result.Success := True;
      Result.PaidAtISO := CommerceNowISO;
      Result.RawPayload := ARawBody;
    end);
  FService.RegisterNotificationVerifier(cppWeChatPay, Verifier);

  ConfirmedOrder := FService.VerifyAndConfirmPayment(
    cppWeChatPay, '{"event_type":"TRANSACTION.SUCCESS"}', nil);

  Assert.AreEqual(cosPaid, ConfirmedOrder.Status);
  Assert.IsTrue(FService.HasEntitlement(User.UserId, 'desktop_tool', 'desktop.pro'));
end;

initialization
  TDUnitX.RegisterTestFixture(TCommerceServiceTests);

end.
