unit Test.DeepBase.Commerce;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.Net.URLClient,
  DUnitX.TestFramework,
  DeepBase.Net.Transport,
  DeepBase.Net.Transport.ICS,
  DeepBase.Commerce.Types,
  DeepBase.Commerce.Backend.Contract,
  DeepBase.Commerce.Backend.Http,
  DeepBase.Commerce.SafeClient,
  DeepBase.Commerce.Permissions,
  DeepBase.Commerce.UpgradeFlow,
  DeepBase.Desktop.Lifecycle,
  DeepBase.Commerce.Adapter.Supabase,
  DeepBase.Commerce.Adapter.Firebase,
  DeepBase.Commerce.Storage,
  DeepBase.Commerce.Service,
  DeepBase.Updater;

type
  [TestFixture]
  TCommerceServiceTests = class
  private
    FStorage: ICommerceStorage;
    FService: TDeepBaseCommerceService;
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
    procedure Test_HttpStorage_CreateDeepKitClient_PrefixesRoute;

    [Test]
    procedure Test_HttpStorage_CreateOrder_SendsSnakeCaseJsonAndAuthHeader;

    [Test]
    procedure Test_HttpStorage_DefaultMode_BlocksServerWrites;

    [Test]
    procedure Test_HttpPaymentGateway_CreatePaymentIntent_SendsBackendRequestAndParsesResponse;

    [Test]
    procedure Test_HttpPaymentGateway_CreateDeepKitClient_PrefixesRoute;

    [Test]
    procedure Test_NetTransport_MethodMapping_AndResponseSuccess;

    [Test]
    procedure Test_CommerceUnifiedTransport_BridgesRequestAndResponse;

    [Test]
    procedure Test_IcsTransport_NotCompiled_FailsFast;

    [Test]
    procedure Test_BeginPayment_WithHttpPaymentGateway_UsesBackendProxy;

    [Test]
    procedure Test_VerifyAndConfirmPayment_RequiresRegisteredVerifier;

    [Test]
    procedure Test_VerifyAndConfirmPayment_VerifiesAndConfirms;

    [Test]
    procedure Test_DeepKitSafeClient_AuthLogin_UsesDeepKitRoute_AndStoresToken;

    [Test]
    procedure Test_DeepKitSafeClient_CreateOrder_UsesAuthorizationHeader_AndDeepKitRoute;

    [Test]
    procedure Test_DeepKitSafeClient_CreatePaymentIntent_UsesIdempotencyKey;

    [Test]
    procedure Test_DeepKitSafeClient_ListProducts_UsesAppIdQuery_AndParsesItems;

    [Test]
    procedure Test_DeepKitSafeClient_ListEntitlements_UsesAppIdQuery_AndParsesItems;

    [Test]
    procedure Test_DeepKitSafeClient_ConsumeEntitlement_UsesRequestId_AndParsesResult;

    [Test]
    procedure Test_DeepKitSafeClient_ConsumeEntitlement_MissingOk_FailsClosed;

    [Test]
    procedure Test_PermissionClient_HasFeature_UsesActiveEntitlement;

    [Test]
    procedure Test_PermissionClient_HasFeature_MissingStatus_Denies;

    [Test]
    procedure Test_PermissionClient_HasFeature_ExpiredEntitlement_Denies;

    [Test]
    procedure Test_PermissionClient_ConsumeQuota_UsesFeatureAndRequestId;

    [Test]
    procedure Test_UpgradeFlow_StartPaidUpgrade_ListsProductCreatesOrderAndPayment;

    [Test]
    procedure Test_UpgradeFlow_CheckEntitlement_AndRefreshSnapshot;

    [Test]
    procedure Test_UpgradeFlow_CheckEntitlement_ExpiredEntitlement_ReturnsFalse;

    [Test]
    procedure Test_DesktopLifecycle_LoginConfiguresUpdaterAndPermissions;

    [Test]
    procedure Test_DesktopLifecycle_StartPaidUpgrade_UsesUserContext;

    [Test]
    procedure Test_DeepKitSafeClient_IssueLicenseSnapshot_UsesRoute_AndParsesFields;

    [Test]
    procedure Test_DeepKitSafeClient_IssueLicenseSnapshot_RequiresVerifier;

    [Test]
    procedure Test_DeepKitSafeClient_IssueLicenseSnapshot_MissingSignature_Raises;

    [Test]
    procedure Test_DeepKitSafeClient_RefreshLicenseSnapshot_DeviceMismatch_Raises;

    [Test]
    procedure Test_DeepKitSafeClient_GetUpdatesManifest_UsesRoute_AndParsesFields;

    [Test]
    procedure Test_HttpStorage_RefundOrder_ServerAdmin_UsesRouteAndPayload;

    [Test]
    procedure Test_HttpStorage_RevokeEntitlement_ServerAdmin_UsesRouteAndPayload;

    [Test]
    procedure Test_HttpStorage_RevokeLicenseSnapshot_ServerAdmin_UsesDeepKitRoute;

    [Test]
    procedure Test_SupabaseAdapter_DefaultConfig_BlockedAsServerOnlyPrototype;

    [Test]
    procedure Test_SupabaseAdapter_CreateServerOnly_AllowsConstruction;

    [Test]
    procedure Test_FirebaseAdapter_DefaultConfig_BlockedAsServerOnlyPrototype;

    [Test]
    procedure Test_FirebaseAdapter_CreateServerOnly_AllowsConstruction;
  end;

implementation

type
  TFakePaymentGateway = class(TInterfacedObject, ICommercePaymentGateway)
  public
    function CreatePaymentIntent(const AOrder: TCommerceOrderData;
      const APayment: TCommercePaymentData; const APayerOpenId: string): TCommercePaymentIntent;
  end;

  TFakeNotificationVerifier = class(TInterfacedObject, ICommerceNotificationVerifier)
  private
    FNotification: TCommercePaymentNotification;
  public
    constructor Create(const ANotification: TCommercePaymentNotification);
    function VerifyNotification(const ARawBody: string;
      const AHeaders: TArray<TPair<string, string>>): TCommercePaymentNotification;
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

  TFakeDeepBaseHttpTransport = class(TInterfacedObject, IDeepBaseHttpTransport)
  private
    FRequests: TList<TDeepBaseHttpTransportRequest>;
    FResponses: TQueue<TDeepBaseHttpTransportResponse>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure QueueResponse(AStatusCode: Integer; const ABody: string);
    function RequestCount: Integer;
    function RequestAt(AIndex: Integer): TDeepBaseHttpTransportRequest;
    function Send(const ARequest: TDeepBaseHttpTransportRequest):
      TDeepBaseHttpTransportResponse;
  end;

function CreateSnapshotVerifiedConfig(const ABearerToken: string = 'atk_001'):
  TDeepKitSafeClientConfig;
begin
  Result := TDeepKitSafeClientConfig.CreateDeepKit('https://api.example.test',
    ABearerToken);
  Result.LicenseSnapshotVerifier :=
    function(const APayload, ASignature, AKeyId, AAppId, ADeviceId: string): Boolean
    begin
      Result := (APayload <> '') and (ASignature = 'sig_001') and
        (AKeyId = 'v1');
    end;
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

constructor TFakeNotificationVerifier.Create(
  const ANotification: TCommercePaymentNotification);
begin
  inherited Create;
  FNotification := ANotification;
end;

function TFakeNotificationVerifier.VerifyNotification(const ARawBody: string;
  const AHeaders: TArray<TPair<string, string>>): TCommercePaymentNotification;
begin
  Result := FNotification;
  Result.RawPayload := ARawBody;
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

{ TFakeDeepBaseHttpTransport }

constructor TFakeDeepBaseHttpTransport.Create;
begin
  inherited Create;
  FRequests := TList<TDeepBaseHttpTransportRequest>.Create;
  FResponses := TQueue<TDeepBaseHttpTransportResponse>.Create;
end;

destructor TFakeDeepBaseHttpTransport.Destroy;
begin
  FResponses.Free;
  FRequests.Free;
  inherited;
end;

procedure TFakeDeepBaseHttpTransport.QueueResponse(AStatusCode: Integer;
  const ABody: string);
begin
  FResponses.Enqueue(TDeepBaseHttpTransportResponse.Create(AStatusCode, ABody));
end;

function TFakeDeepBaseHttpTransport.RequestCount: Integer;
begin
  Result := FRequests.Count;
end;

function TFakeDeepBaseHttpTransport.RequestAt(
  AIndex: Integer): TDeepBaseHttpTransportRequest;
begin
  Result := FRequests[AIndex];
end;

function TFakeDeepBaseHttpTransport.Send(
  const ARequest: TDeepBaseHttpTransportRequest): TDeepBaseHttpTransportResponse;
begin
  FRequests.Add(ARequest);
  if FResponses.Count = 0 then
    Exit(TDeepBaseHttpTransportResponse.Create(500,
      '{"error":"missing fake response"}'));
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
  FService := TDeepBaseCommerceService.Create(FStorage);
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
    on E: EDeepBaseCommercePaymentError do
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
    on E: EDeepBaseCommercePaymentError do
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
  Assert.AreEqual('/commerce/orders/ord_001/refund',
    TCommerceBackendRoutes.OrderRefund('ord_001'));
  Assert.AreEqual('/commerce/payments/intents', SCommerceRoutePaymentIntents);
  Assert.AreEqual('/commerce/payments/wechat_pay/notify',
    TCommerceBackendRoutes.PaymentNotify(cppWeChatPay));
  Assert.AreEqual('/commerce/entitlements', SCommerceRouteEntitlements);
  Assert.AreEqual('/commerce/entitlements/consume',
    SCommerceRouteEntitlementsConsume);
  Assert.AreEqual('/commerce/entitlements/ent_001/revoke',
    TCommerceBackendRoutes.EntitlementRevoke('ent_001'));
  Assert.AreEqual('/license/snapshot/revoke', SCommerceRouteLicenseSnapshotRevoke);
end;

procedure TCommerceServiceTests.Test_BackendContract_JsonFieldsUseSnakeCase;
begin
  Assert.AreEqual('provider_user_id', SCommerceFieldProviderUserId);
  Assert.AreEqual('out_trade_no', SCommerceFieldOutTradeNo);
  Assert.AreEqual('amount_minor', SCommerceFieldAmountMinor);
  Assert.AreEqual('provider_trade_no', SCommerceFieldProviderTradeNo);
  Assert.AreEqual('client_params_json', SCommerceFieldClientParamsJson);
  Assert.AreEqual('remaining_quota', SCommerceFieldRemainingQuota);
  Assert.AreEqual('reason', SCommerceFieldReason);
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

procedure TCommerceServiceTests.Test_HttpStorage_CreateDeepKitClient_PrefixesRoute;
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
    TCommerceBackendHttpConfig.CreateDeepKitClient(
      'https://api.example.test', 'token_123'),
    Transport);

  Assert.IsTrue(Storage.FindUserByIdentity(
    capWeChatMiniProgram, 'openid_001', 'desktop_tool', User));

  Assert.AreEqual<Integer>(1, Transport.RequestCount);
  Request := Transport.RequestAt(0);
  Assert.IsTrue(Request.Url.StartsWith(
    'https://api.example.test/dk/commerce/users/by-identity?'));
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
    TCommerceBackendHttpConfig.CreateServerAdmin(
      'https://api.example.test', '', 'api_key_123'),
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

procedure TCommerceServiceTests.Test_HttpStorage_DefaultMode_BlocksServerWrites;
var
  Transport: TFakeCommerceTransport;
  Storage: ICommerceStorage;
  Order: TCommerceOrderData;
  Raised: Boolean;
begin
  Transport := TFakeCommerceTransport.Create;
  Storage := TCommerceHttpStorage.Create(
    TCommerceBackendHttpConfig.Create('https://api.example.test', 'desktop_token'),
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

  Raised := False;
  try
    Storage.CreateOrder(Order);
  except
    on E: EDeepBaseCommerceValidationError do
      Raised := True;
  end;

  Assert.IsTrue(Raised);
  Assert.AreEqual<Integer>(0, Transport.RequestCount);
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

procedure TCommerceServiceTests.Test_HttpPaymentGateway_CreateDeepKitClient_PrefixesRoute;
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
    TCommerceBackendHttpConfig.CreateDeepKitClient(
      'https://api.example.test', 'token_123'),
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

  Assert.AreEqual<Integer>(1, Transport.RequestCount);
  Request := Transport.RequestAt(0);
  Assert.AreEqual('https://api.example.test/dk/commerce/payments/intents',
    Request.Url);
  Assert.AreEqual('Bearer token_123', HeaderValue(Request.Headers, 'Authorization'));
end;

procedure TCommerceServiceTests.Test_NetTransport_MethodMapping_AndResponseSuccess;
var
  Response: TDeepBaseHttpTransportResponse;
begin
  Assert.AreEqual('GET', DeepBaseHttpMethodToString(dbhmGet));
  Assert.AreEqual('POST', DeepBaseHttpMethodToString(dbhmPost));
  Assert.AreEqual('PATCH', DeepBaseHttpMethodToString(dbhmPatch));
  Assert.AreEqual(dbhmDelete, DeepBaseHttpMethodFromString('DELETE'));
  Assert.AreEqual(dbhmOptions, DeepBaseHttpMethodFromString('options'));

  Response := TDeepBaseHttpTransportResponse.Create(204, '');
  Assert.IsTrue(Response.IsSuccess);
  Response := TDeepBaseHttpTransportResponse.Create(500, 'error');
  Assert.IsFalse(Response.IsSuccess);
end;

procedure TCommerceServiceTests.Test_CommerceUnifiedTransport_BridgesRequestAndResponse;
var
  BaseTransport: TFakeDeepBaseHttpTransport;
  CommerceTransport: ICommerceBackendHttpTransport;
  Headers: TNetHeaders;
  Request: TDeepBaseHttpTransportRequest;
  Response: TCommerceBackendHttpResponse;
begin
  BaseTransport := TFakeDeepBaseHttpTransport.Create;
  BaseTransport.QueueResponse(200, '{"ok":true}');
  CommerceTransport := TCommerceBackendUnifiedTransport.Create(
    BaseTransport as IDeepBaseHttpTransport, 12345);

  SetLength(Headers, 2);
  Headers[0] := TNetHeader.Create('Authorization', 'Bearer token_001');
  Headers[1] := TNetHeader.Create('Idempotency-Key', 'idem_001');

  Response := CommerceTransport.Send('POST',
    'https://api.example.test/dk/commerce/orders',
    '{"product_id":"pro_monthly"}', Headers);

  Assert.AreEqual<Integer>(200, Response.StatusCode);
  Assert.AreEqual('{"ok":true}', Response.Body);
  Assert.AreEqual<Integer>(1, BaseTransport.RequestCount);

  Request := BaseTransport.RequestAt(0);
  Assert.AreEqual(dbhmPost, Request.Method);
  Assert.AreEqual('https://api.example.test/dk/commerce/orders', Request.Url);
  Assert.AreEqual('{"product_id":"pro_monthly"}', Request.Body);
  Assert.AreEqual<Integer>(12345, Request.TimeoutMs);
  Assert.AreEqual('application/json', Request.ContentType);
  Assert.AreEqual('Bearer token_001',
    HeaderValue(Request.Headers, 'Authorization'));
  Assert.AreEqual('idem_001', HeaderValue(Request.Headers, 'Idempotency-Key'));
end;

procedure TCommerceServiceTests.Test_IcsTransport_NotCompiled_FailsFast;
var
  Raised: Boolean;
  Transport: IDeepBaseHttpTransport;
  Config: TDeepBaseIcsTransportConfig;
  Request: TDeepBaseHttpTransportRequest;
  Effective: TDeepBaseHttpTransportRequest;
begin
  Config := TDeepBaseIcsTransportConfig.CreateSecure(45000,
    'http://proxy.example.test:8080', itls12);
  Request := TDeepBaseHttpTransportRequest.Create(dbhmGet,
    'https://api.example.test/dk/health');
  Request.TimeoutMs := 0;
  Request.ProxyUrl := '';
  Effective := TDeepBaseIcsHttpTransport.EffectiveRequest(Config, Request);
  Assert.AreEqual<Integer>(45000, Effective.TimeoutMs);
  Assert.AreEqual('http://proxy.example.test:8080', Effective.ProxyUrl);
  Assert.IsTrue(Effective.FollowRedirects);
  Assert.AreEqual<Integer>(5, Effective.MaxRedirects);

  if TDeepBaseIcsHttpTransport.IsAvailable then
    Exit;

  Raised := False;
  try
    Transport := TDeepBaseIcsHttpTransport.Create(
      TDeepBaseIcsTransportConfig.Create);
  except
    on E: EDeepBaseNetTransportError do
      Raised := True;
  end;

  Assert.IsTrue(Raised);
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
    on E: EDeepBaseCommercePaymentError do
      Raised := True;
  end;
  Assert.IsTrue(Raised);
end;

procedure TCommerceServiceTests.Test_VerifyAndConfirmPayment_VerifiesAndConfirms;
var
  User: TCommerceUserData;
  Order: TCommerceOrderData;
  ConfirmedOrder: TCommerceOrderData;
  Notification: TCommercePaymentNotification;
  Verifier: ICommerceNotificationVerifier;
begin
  RegisterProduct('pro_year', 'desktop.pro', 9900);
  FService.RegisterPaymentGateway(cppWeChatPay, TFakePaymentGateway.Create);
  User := EnsureUser;
  Order := FService.CreateOrder(User.UserId, 'desktop_tool', 'pro_year');
  FService.BeginPayment(Order.OrderId, cppWeChatPay, cpcMiniProgram, 'openid_001');

  Notification.Provider := cppWeChatPay;
  Notification.OutTradeNo := Order.OutTradeNo;
  Notification.ProviderTradeNo := 'wx_trade_003';
  Notification.AmountMinor := Order.AmountMinor;
  Notification.Currency := Order.Currency;
  Notification.Success := True;
  Notification.PaidAtISO := CommerceNowISO;
  Verifier := TFakeNotificationVerifier.Create(Notification);
  FService.RegisterNotificationVerifier(cppWeChatPay, Verifier);

  ConfirmedOrder := FService.VerifyAndConfirmPayment(
    cppWeChatPay, '{"event_type":"TRANSACTION.SUCCESS"}', nil);

  Assert.AreEqual(cosPaid, ConfirmedOrder.Status);
  Assert.IsTrue(FService.HasEntitlement(User.UserId, 'desktop_tool', 'desktop.pro'));
end;

procedure TCommerceServiceTests.Test_DeepKitSafeClient_AuthLogin_UsesDeepKitRoute_AndStoresToken;
var
  Transport: TFakeCommerceTransport;
  Client: TDeepKitSafeClient;
  Session: TDeepKitAuthSession;
  Request: TRecordedHttpRequest;
begin
  Transport := TFakeCommerceTransport.Create;
  Transport.QueueResponse(200,
    '{"user_id":"usr_001","access_token":"atk_001","refresh_token":"rtk_001","expires_in":7200}');
  Client := TDeepKitSafeClient.Create(
    TDeepKitSafeClientConfig.CreateDeepKit('https://api.example.test'),
    Transport);
  try
    Session := Client.AuthLoginDeviceAnonymous('deepbase_desktop', 'dev_001',
      'fp_001');

    Assert.AreEqual('usr_001', Session.UserId);
    Assert.AreEqual('atk_001', Session.AccessToken);
    Assert.AreEqual('rtk_001', Session.RefreshToken);
    Assert.AreEqual<Integer>(7200, Session.ExpiresIn);
    Assert.AreEqual('atk_001', Client.GetAccessToken);

    Assert.AreEqual<Integer>(1, Transport.RequestCount);
    Request := Transport.RequestAt(0);
    Assert.AreEqual('POST', Request.Method);
    Assert.AreEqual('https://api.example.test/dk/auth/login', Request.Url);
    Assert.IsTrue(Pos('"login_type":"device_anonymous"', Request.Body) > 0);
    Assert.IsTrue(Pos('"app_id":"deepbase_desktop"', Request.Body) > 0);
    Assert.IsTrue(Pos('"device_id":"dev_001"', Request.Body) > 0);
    Assert.IsTrue(Pos('"device_fingerprint":"fp_001"', Request.Body) > 0);
    Assert.AreEqual('', HeaderValue(Request.Headers, 'Authorization'));
  finally
    Client.Free;
  end;
end;

procedure TCommerceServiceTests.Test_DeepKitSafeClient_CreateOrder_UsesAuthorizationHeader_AndDeepKitRoute;
var
  Transport: TFakeCommerceTransport;
  Client: TDeepKitSafeClient;
  Order: TDeepKitOrder;
  Request: TRecordedHttpRequest;
begin
  Transport := TFakeCommerceTransport.Create;
  Transport.QueueResponse(200,
    '{"order_id":"ord_001","out_trade_no":"UB202605080001","app_id":"deepbase_desktop","product_id":"pro_monthly","amount_minor":3900,"currency":"CNY","status":"created"}');
  Client := TDeepKitSafeClient.Create(
    TDeepKitSafeClientConfig.CreateDeepKit('https://api.example.test',
      'atk_001'),
    Transport);
  try
    Order := Client.CreateOrder('usr_001', 'deepbase_desktop', 'pro_monthly');

    Assert.AreEqual('ord_001', Order.OrderId);
    Assert.AreEqual('UB202605080001', Order.OutTradeNo);
    Assert.AreEqual<Int64>(3900, Order.AmountMinor);
    Assert.AreEqual(cosCreated, Order.Status);

    Assert.AreEqual<Integer>(1, Transport.RequestCount);
    Request := Transport.RequestAt(0);
    Assert.AreEqual('POST', Request.Method);
    Assert.AreEqual('https://api.example.test/dk/commerce/orders', Request.Url);
    Assert.AreEqual('Bearer atk_001', HeaderValue(Request.Headers, 'Authorization'));
    Assert.IsTrue(Pos('"user_id":"usr_001"', Request.Body) > 0);
    Assert.IsTrue(Pos('"app_id":"deepbase_desktop"', Request.Body) > 0);
    Assert.IsTrue(Pos('"product_id":"pro_monthly"', Request.Body) > 0);
  finally
    Client.Free;
  end;
end;

procedure TCommerceServiceTests.Test_DeepKitSafeClient_CreatePaymentIntent_UsesIdempotencyKey;
var
  Transport: TFakeCommerceTransport;
  Client: TDeepKitSafeClient;
  Intent: TCommercePaymentIntent;
  Request: TRecordedHttpRequest;
begin
  Transport := TFakeCommerceTransport.Create;
  Transport.QueueResponse(200,
    '{"success":true,"payment_id":"pay_001","out_trade_no":"UB202605080002","prepay_id":"wx_pre_001","pay_url":"https://pay.example/1"}');
  Client := TDeepKitSafeClient.Create(
    TDeepKitSafeClientConfig.CreateDeepKit('https://api.example.test',
      'atk_001'),
    Transport);
  try
    Intent := Client.CreatePaymentIntent('ord_001', cppWeChatPay,
      cpcMiniProgram, 'openid_001', 'idem_001');

    Assert.IsTrue(Intent.Success);
    Assert.AreEqual('pay_001', Intent.PaymentId);
    Assert.AreEqual('wx_pre_001', Intent.PrepayId);
    Assert.AreEqual('https://pay.example/1', Intent.PayUrl);

    Assert.AreEqual<Integer>(1, Transport.RequestCount);
    Request := Transport.RequestAt(0);
    Assert.AreEqual('POST', Request.Method);
    Assert.AreEqual('https://api.example.test/dk/commerce/payments/intents',
      Request.Url);
    Assert.AreEqual('Bearer atk_001', HeaderValue(Request.Headers, 'Authorization'));
    Assert.AreEqual('idem_001', HeaderValue(Request.Headers, 'Idempotency-Key'));
    Assert.IsTrue(Pos('"order_id":"ord_001"', Request.Body) > 0);
    Assert.IsTrue(Pos('"provider":"wechat_pay"', Request.Body) > 0);
    Assert.IsTrue(Pos('"channel":"mini_program"', Request.Body) > 0);
  finally
    Client.Free;
  end;
end;

procedure TCommerceServiceTests.Test_DeepKitSafeClient_ListProducts_UsesAppIdQuery_AndParsesItems;
var
  Transport: TFakeCommerceTransport;
  Client: TDeepKitSafeClient;
  Items: TArray<TCommerceProductData>;
  Request: TRecordedHttpRequest;
begin
  Transport := TFakeCommerceTransport.Create;
  Transport.QueueResponse(200,
    '{"products":[{"app_id":"deepbase_desktop","product_id":"pro_monthly","name":"Pro Monthly","description":"monthly plan","amount_minor":3900,"currency":"CNY","entitlement_code":"pro_full","entitlement_duration_days":30,"initial_quota":-1,"is_active":true}]}');
  Client := TDeepKitSafeClient.Create(
    TDeepKitSafeClientConfig.CreateDeepKit('https://api.example.test',
      'atk_001'),
    Transport);
  try
    Items := Client.ListProducts('deepbase_desktop');

    Assert.AreEqual<Integer>(1, Length(Items));
    Assert.AreEqual('deepbase_desktop', Items[0].AppId);
    Assert.AreEqual('pro_monthly', Items[0].ProductId);
    Assert.AreEqual<Int64>(3900, Items[0].AmountMinor);
    Assert.AreEqual('pro_full', Items[0].EntitlementCode);

    Assert.AreEqual<Integer>(1, Transport.RequestCount);
    Request := Transport.RequestAt(0);
    Assert.AreEqual('GET', Request.Method);
    Assert.IsTrue(Request.Url.StartsWith(
      'https://api.example.test/dk/commerce/products?'));
    Assert.IsTrue(Pos('app_id=deepbase_desktop', Request.Url) > 0);
    Assert.AreEqual('Bearer atk_001', HeaderValue(Request.Headers, 'Authorization'));
  finally
    Client.Free;
  end;
end;

procedure TCommerceServiceTests.Test_DeepKitSafeClient_ListEntitlements_UsesAppIdQuery_AndParsesItems;
var
  Transport: TFakeCommerceTransport;
  Client: TDeepKitSafeClient;
  Items: TCommerceEntitlementArray;
  Request: TRecordedHttpRequest;
begin
  Transport := TFakeCommerceTransport.Create;
  Transport.QueueResponse(200,
    '{"items":[{"entitlement_id":"ent_001","user_id":"usr_001","app_id":"deepbase_desktop","product_id":"pro_monthly","code":"pro_full","status":"active","valid_from":"2026-05-08T10:00:00Z","valid_until":"2026-06-08T10:00:00Z","remaining_quota":-1,"source_order_id":"ord_001"}]}');
  Client := TDeepKitSafeClient.Create(
    TDeepKitSafeClientConfig.CreateDeepKit('https://api.example.test',
      'atk_001'),
    Transport);
  try
    Items := Client.ListEntitlements('deepbase_desktop');
    Assert.AreEqual<Integer>(1, Length(Items));
    Assert.AreEqual('ent_001', Items[0].EntitlementId);
    Assert.AreEqual('pro_full', Items[0].Code);
    Assert.AreEqual(cesActive, Items[0].Status);
    Assert.AreEqual<Integer>(-1, Items[0].RemainingQuota);

    Assert.AreEqual<Integer>(1, Transport.RequestCount);
    Request := Transport.RequestAt(0);
    Assert.AreEqual('GET', Request.Method);
    Assert.IsTrue(Request.Url.StartsWith(
      'https://api.example.test/dk/commerce/entitlements?'));
    Assert.IsTrue(Pos('app_id=deepbase_desktop', Request.Url) > 0);
    Assert.AreEqual('Bearer atk_001', HeaderValue(Request.Headers, 'Authorization'));
  finally
    Client.Free;
  end;
end;

procedure TCommerceServiceTests.Test_DeepKitSafeClient_ConsumeEntitlement_UsesRequestId_AndParsesResult;
var
  Transport: TFakeCommerceTransport;
  Client: TDeepKitSafeClient;
  ResultData: TDeepKitConsumeEntitlementResult;
  Request: TRecordedHttpRequest;
begin
  Transport := TFakeCommerceTransport.Create;
  Transport.QueueResponse(200,
    '{"ok":true,"entitlement_code":"ai_quota","remaining_quota":41,"consumed_quantity":1,"server_time":"2026-05-08T11:00:00Z"}');
  Client := TDeepKitSafeClient.Create(
    TDeepKitSafeClientConfig.CreateDeepKit('https://api.example.test',
      'atk_001'),
    Transport);
  try
    ResultData := Client.ConsumeEntitlement('deepbase_desktop', 'ai_quota',
      'llm.chat', 1, 'req_001');

    Assert.IsTrue(ResultData.Ok);
    Assert.AreEqual('ai_quota', ResultData.EntitlementCode);
    Assert.AreEqual<Integer>(41, ResultData.RemainingQuota);
    Assert.AreEqual<Integer>(1, ResultData.ConsumedQuantity);
    Assert.AreEqual('2026-05-08T11:00:00Z', ResultData.ServerTimeISO);

    Assert.AreEqual<Integer>(1, Transport.RequestCount);
    Request := Transport.RequestAt(0);
    Assert.AreEqual('POST', Request.Method);
    Assert.AreEqual('https://api.example.test/dk/commerce/entitlements/consume',
      Request.Url);
    Assert.AreEqual('Bearer atk_001', HeaderValue(Request.Headers, 'Authorization'));
    Assert.AreEqual('req_001', HeaderValue(Request.Headers, 'Idempotency-Key'));
    Assert.IsTrue(Pos('"app_id":"deepbase_desktop"', Request.Body) > 0);
    Assert.IsTrue(Pos('"entitlement_code":"ai_quota"', Request.Body) > 0);
    Assert.IsTrue(Pos('"feature_code":"llm.chat"', Request.Body) > 0);
    Assert.IsTrue(Pos('"quantity":1', Request.Body) > 0);
    Assert.IsTrue(Pos('"request_id":"req_001"', Request.Body) > 0);
  finally
    Client.Free;
  end;
end;

procedure TCommerceServiceTests.Test_DeepKitSafeClient_ConsumeEntitlement_MissingOk_FailsClosed;
var
  Transport: TFakeCommerceTransport;
  Client: TDeepKitSafeClient;
  ResultData: TDeepKitConsumeEntitlementResult;
begin
  Transport := TFakeCommerceTransport.Create;
  Transport.QueueResponse(200,
    '{"entitlement_code":"ai_quota","remaining_quota":41,"consumed_quantity":1}');
  Client := TDeepKitSafeClient.Create(
    TDeepKitSafeClientConfig.CreateDeepKit('https://api.example.test',
      'atk_001'),
    Transport);
  try
    ResultData := Client.ConsumeEntitlement('deepbase_desktop', 'ai_quota',
      'llm.chat', 1, 'req_001');

    Assert.IsFalse(ResultData.Ok,
      'ConsumeEntitlement must require explicit ok/success=true');
  finally
    Client.Free;
  end;
end;

procedure TCommerceServiceTests.Test_PermissionClient_HasFeature_UsesActiveEntitlement;
var
  Transport: TFakeCommerceTransport;
  Client: TDeepKitSafeClient;
  Permissions: TDeepKitPermissionClient;
  Check: TDeepKitPermissionResult;
begin
  Transport := TFakeCommerceTransport.Create;
  Transport.QueueResponse(200,
    '{"items":[{"entitlement_id":"ent_001","user_id":"usr_001","app_id":"deepbase_desktop","product_id":"pro_monthly","code":"pro_full","status":"active","valid_from":"2026-05-08T10:00:00Z","valid_until":"2026-06-08T10:00:00Z","remaining_quota":-1,"source_order_id":"ord_001"}]}');
  Client := TDeepKitSafeClient.Create(
    TDeepKitSafeClientConfig.CreateDeepKit('https://api.example.test',
      'atk_001'),
    Transport);
  Permissions := TDeepKitPermissionClient.Create(Client, 'deepbase_desktop',
    'dev_001', True);
  try
    Check := Permissions.HasFeature('llm.chat');

    Assert.IsTrue(Check.Allowed);
    Assert.AreEqual('llm.chat', Check.FeatureCode);
    Assert.AreEqual('pro_full', Check.EntitlementCode);
    Assert.AreEqual<Integer>(-1, Check.RemainingQuota);
  finally
    Permissions.Free;
  end;
end;

procedure TCommerceServiceTests.Test_PermissionClient_HasFeature_MissingStatus_Denies;
var
  Transport: TFakeCommerceTransport;
  Client: TDeepKitSafeClient;
  Permissions: TDeepKitPermissionClient;
  Check: TDeepKitPermissionResult;
begin
  Transport := TFakeCommerceTransport.Create;
  Transport.QueueResponse(200,
    '{"items":[{"entitlement_id":"ent_001","user_id":"usr_001","app_id":"deepbase_desktop","product_id":"pro_monthly","code":"pro_full","remaining_quota":-1}]}');
  Client := TDeepKitSafeClient.Create(
    TDeepKitSafeClientConfig.CreateDeepKit('https://api.example.test',
      'atk_001'),
    Transport);
  Permissions := TDeepKitPermissionClient.Create(Client, 'deepbase_desktop',
    'dev_001', True);
  try
    Check := Permissions.HasFeature('llm.chat');

    Assert.IsFalse(Check.Allowed,
      'Entitlement without explicit active status should be denied');
  finally
    Permissions.Free;
  end;
end;

procedure TCommerceServiceTests.Test_PermissionClient_HasFeature_ExpiredEntitlement_Denies;
var
  Transport: TFakeCommerceTransport;
  Client: TDeepKitSafeClient;
  Permissions: TDeepKitPermissionClient;
  Check: TDeepKitPermissionResult;
begin
  Transport := TFakeCommerceTransport.Create;
  Transport.QueueResponse(200,
    '{"items":[{"entitlement_id":"ent_001","user_id":"usr_001","app_id":"deepbase_desktop","product_id":"pro_monthly","code":"pro_full","status":"active","valid_until":"2000-01-01T00:00:00Z","remaining_quota":-1}]}');
  Client := TDeepKitSafeClient.Create(
    TDeepKitSafeClientConfig.CreateDeepKit('https://api.example.test',
      'atk_001'),
    Transport);
  Permissions := TDeepKitPermissionClient.Create(Client, 'deepbase_desktop',
    'dev_001', True);
  try
    Check := Permissions.HasFeature('llm.chat');

    Assert.IsFalse(Check.Allowed,
      'Expired entitlement should be denied even when status is active');
  finally
    Permissions.Free;
  end;
end;

procedure TCommerceServiceTests.Test_PermissionClient_ConsumeQuota_UsesFeatureAndRequestId;
var
  Transport: TFakeCommerceTransport;
  Client: TDeepKitSafeClient;
  Permissions: TDeepKitPermissionClient;
  ResultData: TDeepKitConsumeEntitlementResult;
  Request: TRecordedHttpRequest;
begin
  Transport := TFakeCommerceTransport.Create;
  Transport.QueueResponse(200,
    '{"items":[{"entitlement_id":"ent_001","user_id":"usr_001","app_id":"deepbase_desktop","product_id":"pro_monthly","code":"ai_quota","status":"active","remaining_quota":42}]}');
  Transport.QueueResponse(200,
    '{"ok":true,"entitlement_code":"ai_quota","remaining_quota":41,"consumed_quantity":1,"server_time":"2026-05-08T11:00:00Z"}');
  Client := TDeepKitSafeClient.Create(
    TDeepKitSafeClientConfig.CreateDeepKit('https://api.example.test',
      'atk_001'),
    Transport);
  Permissions := TDeepKitPermissionClient.Create(Client, 'deepbase_desktop',
    'dev_001', True);
  try
    ResultData := Permissions.ConsumeQuota('ai_quota', 1, 'req_quota_001');

    Assert.IsTrue(ResultData.Ok);
    Assert.AreEqual('ai_quota', ResultData.EntitlementCode);
    Assert.AreEqual<Integer>(41, ResultData.RemainingQuota);
    Assert.AreEqual<Integer>(2, Transport.RequestCount);

    Request := Transport.RequestAt(1);
    Assert.AreEqual('POST', Request.Method);
    Assert.AreEqual('https://api.example.test/dk/commerce/entitlements/consume',
      Request.Url);
    Assert.AreEqual('req_quota_001', HeaderValue(Request.Headers, 'Idempotency-Key'));
    Assert.IsTrue(Pos('"feature_code":"ai_quota"', Request.Body) > 0);
    Assert.IsTrue(Pos('"request_id":"req_quota_001"', Request.Body) > 0);
  finally
    Permissions.Free;
  end;
end;

procedure TCommerceServiceTests.Test_UpgradeFlow_StartPaidUpgrade_ListsProductCreatesOrderAndPayment;
var
  Transport: TFakeCommerceTransport;
  Client: TDeepKitSafeClient;
  Flow: TDeepKitUpgradeFlowClient;
  ResultData: TDeepKitUpgradeStartResult;
  Request: TRecordedHttpRequest;
begin
  Transport := TFakeCommerceTransport.Create;
  Transport.QueueResponse(200,
    '{"products":[{"product_id":"pro_monthly","app_id":"deepbase_desktop","name":"Pro Monthly","amount_minor":3900,"currency":"CNY","entitlement_code":"pro_full","entitlement_duration_days":31,"initial_quota":-1,"is_active":true}]}');
  Transport.QueueResponse(200,
    '{"order_id":"ord_001","out_trade_no":"DB20260508001","app_id":"deepbase_desktop","product_id":"pro_monthly","amount_minor":3900,"currency":"CNY","status":"created"}');
  Transport.QueueResponse(200,
    '{"success":true,"payment_id":"pay_001","out_trade_no":"DB20260508001","prepay_id":"prepay_001","pay_url":"https://pay.example.test/h5"}');

  Client := TDeepKitSafeClient.Create(
    TDeepKitSafeClientConfig.CreateDeepKit('https://api.example.test',
      'atk_001'),
    Transport);
  Flow := TDeepKitUpgradeFlowClient.Create(Client, 'deepbase_desktop',
    'usr_001', 'dev_001', True);
  try
    ResultData := Flow.StartPaidUpgrade('pro_monthly', cppWeChatPay, cpcH5,
      '', 'upgrade_req_001');

    Assert.AreEqual('pro_monthly', ResultData.Product.ProductId);
    Assert.AreEqual('ord_001', ResultData.Order.OrderId);
    Assert.IsTrue(ResultData.PaymentIntent.Success);
    Assert.AreEqual('https://pay.example.test/h5', ResultData.PaymentIntent.PayUrl);
    Assert.AreEqual<Integer>(3, Transport.RequestCount);

    Request := Transport.RequestAt(0);
    Assert.AreEqual('GET', Request.Method);
    Assert.AreEqual('https://api.example.test/dk/commerce/products?app_id=deepbase_desktop',
      Request.Url);

    Request := Transport.RequestAt(1);
    Assert.AreEqual('POST', Request.Method);
    Assert.AreEqual('https://api.example.test/dk/commerce/orders', Request.Url);
    Assert.IsTrue(Pos('"user_id":"usr_001"', Request.Body) > 0);
    Assert.IsTrue(Pos('"product_id":"pro_monthly"', Request.Body) > 0);

    Request := Transport.RequestAt(2);
    Assert.AreEqual('POST', Request.Method);
    Assert.AreEqual('https://api.example.test/dk/commerce/payments/intents',
      Request.Url);
    Assert.AreEqual('upgrade_req_001', HeaderValue(Request.Headers, 'Idempotency-Key'));
    Assert.IsTrue(Pos('"channel":"h5"', Request.Body) > 0);
  finally
    Flow.Free;
  end;
end;

procedure TCommerceServiceTests.Test_UpgradeFlow_CheckEntitlement_AndRefreshSnapshot;
var
  Transport: TFakeCommerceTransport;
  Client: TDeepKitSafeClient;
  Flow: TDeepKitUpgradeFlowClient;
  Entitlement: TCommerceEntitlementData;
  Snapshot: TDeepKitLicenseSnapshot;
begin
  Transport := TFakeCommerceTransport.Create;
  Transport.QueueResponse(200,
    '{"items":[{"entitlement_id":"ent_001","user_id":"usr_001","app_id":"deepbase_desktop","product_id":"pro_monthly","code":"pro_full","status":"active","remaining_quota":-1}]}');
  Transport.QueueResponse(200,
    '{"snapshot_id":"lic_001","issued_at":"2026-05-08T10:00:00Z","expires_at":"2099-05-15T10:00:00Z","payload":{"app_id":"deepbase_desktop","device_id":"dev_001","tier":"pro"},"signature":"sig_001","key_id":"v1","schema_version":1,"revocation_version":0}');

  Client := TDeepKitSafeClient.Create(CreateSnapshotVerifiedConfig, Transport);
  Flow := TDeepKitUpgradeFlowClient.Create(Client, 'deepbase_desktop',
    'usr_001', 'dev_001', True);
  try
    Assert.IsTrue(Flow.CheckEntitlement('pro_full', Entitlement));
    Assert.AreEqual('ent_001', Entitlement.EntitlementId);

    Snapshot := Flow.RefreshLicenseSnapshot;
    Assert.AreEqual('lic_001', Snapshot.SnapshotId);
    Assert.AreEqual<Integer>(2, Transport.RequestCount);
    Assert.AreEqual('https://api.example.test/dk/license/snapshot/refresh',
      Transport.RequestAt(1).Url);
  finally
    Flow.Free;
  end;
end;

procedure TCommerceServiceTests.Test_UpgradeFlow_CheckEntitlement_ExpiredEntitlement_ReturnsFalse;
var
  Transport: TFakeCommerceTransport;
  Client: TDeepKitSafeClient;
  Flow: TDeepKitUpgradeFlowClient;
  Entitlement: TCommerceEntitlementData;
begin
  Transport := TFakeCommerceTransport.Create;
  Transport.QueueResponse(200,
    '{"items":[{"entitlement_id":"ent_001","user_id":"usr_001","app_id":"deepbase_desktop","product_id":"pro_monthly","code":"pro_full","status":"active","valid_until":"2000-01-01T00:00:00Z","remaining_quota":-1}]}');

  Client := TDeepKitSafeClient.Create(
    TDeepKitSafeClientConfig.CreateDeepKit('https://api.example.test',
      'atk_001'),
    Transport);
  Flow := TDeepKitUpgradeFlowClient.Create(Client, 'deepbase_desktop',
    'usr_001', 'dev_001', True);
  try
    Assert.IsFalse(Flow.CheckEntitlement('pro_full', Entitlement),
      'Upgrade flow should deny expired entitlements');
  finally
    Flow.Free;
  end;
end;

procedure TCommerceServiceTests.Test_DesktopLifecycle_LoginConfiguresUpdaterAndPermissions;
var
  Transport: TFakeCommerceTransport;
  Client: TDeepKitSafeClient;
  Lifecycle: TDeepBaseDesktopLifecycle;
  Updater: TUpdateManager;
  Session: TDeepKitAuthSession;
  Check: TDeepKitPermissionResult;
begin
  Transport := TFakeCommerceTransport.Create;
  Transport.QueueResponse(200,
    '{"user_id":"usr_001","access_token":"atk_001","refresh_token":"rtk_001","expires_in":7200}');
  Transport.QueueResponse(200,
    '{"items":[{"entitlement_id":"ent_001","user_id":"usr_001","app_id":"deepbase_desktop","product_id":"pro_monthly","code":"pro_full","status":"active","remaining_quota":-1}]}');

  Client := TDeepKitSafeClient.Create(
    TDeepKitSafeClientConfig.CreateDeepKit('https://api.example.test'),
    Transport);
  Updater := TUpdateManager.Create;
  Lifecycle := TDeepBaseDesktopLifecycle.Create(
    TDeepBaseDesktopLifecycleConfig.Create('deepbase_desktop', 'dev_001',
      '1.2.0', 'https://api.example.test/dk', 'stable'),
    Client, True);
  try
    Lifecycle.AttachUpdater(Updater, True);
    Session := Lifecycle.LoginDeviceAnonymous('fp_001');

    Assert.AreEqual('usr_001', Session.UserId);
    Assert.AreEqual('atk_001', Client.GetAccessToken);
    Assert.AreEqual('deepbase_desktop', Updater.UpdateAppId);
    Assert.AreEqual('dev_001', Updater.UpdateDeviceId);
    Assert.AreEqual('atk_001', Updater.UpdateAccessToken);

    Check := Lifecycle.HasFeature('llm.chat');
    Assert.IsTrue(Check.Allowed);
    Assert.AreEqual('pro_full', Check.EntitlementCode);
    Assert.IsTrue(Lifecycle.GetPermissionClient = Lifecycle.Permissions);
  finally
    Lifecycle.Free;
  end;
end;

procedure TCommerceServiceTests.Test_DesktopLifecycle_StartPaidUpgrade_UsesUserContext;
var
  Transport: TFakeCommerceTransport;
  Client: TDeepKitSafeClient;
  Lifecycle: TDeepBaseDesktopLifecycle;
  Config: TDeepBaseDesktopLifecycleConfig;
  Upgrade: TDeepKitUpgradeStartResult;
  Request: TRecordedHttpRequest;
begin
  Transport := TFakeCommerceTransport.Create;
  Transport.QueueResponse(200,
    '{"products":[{"product_id":"pro_monthly","app_id":"deepbase_desktop","name":"Pro Monthly","amount_minor":3900,"currency":"CNY","entitlement_code":"pro_full","entitlement_duration_days":31,"initial_quota":-1,"is_active":true}]}');
  Transport.QueueResponse(200,
    '{"order_id":"ord_001","out_trade_no":"DB20260508001","app_id":"deepbase_desktop","product_id":"pro_monthly","amount_minor":3900,"currency":"CNY","status":"created"}');
  Transport.QueueResponse(200,
    '{"success":true,"payment_id":"pay_001","out_trade_no":"DB20260508001","prepay_id":"prepay_001","pay_url":"https://pay.example.test/h5"}');

  Client := TDeepKitSafeClient.Create(
    TDeepKitSafeClientConfig.CreateDeepKit('https://api.example.test',
      'atk_001'),
    Transport);
  Config := TDeepBaseDesktopLifecycleConfig.Create('deepbase_desktop', 'dev_001');
  Config.UserId := 'usr_001';
  Lifecycle := TDeepBaseDesktopLifecycle.Create(
    Config, Client, True);
  try
    Upgrade := Lifecycle.StartPaidUpgrade('pro_monthly', cppWeChatPay, cpcH5,
      '', 'desktop_upgrade_001');

    Assert.AreEqual('ord_001', Upgrade.Order.OrderId);
    Assert.IsTrue(Upgrade.PaymentIntent.Success);
    Assert.AreEqual<Integer>(3, Transport.RequestCount);

    Request := Transport.RequestAt(1);
    Assert.AreEqual('POST', Request.Method);
    Assert.AreEqual('https://api.example.test/dk/commerce/orders', Request.Url);
    Assert.IsTrue(Pos('"user_id":"usr_001"', Request.Body) > 0);

    Request := Transport.RequestAt(2);
    Assert.AreEqual('desktop_upgrade_001',
      HeaderValue(Request.Headers, 'Idempotency-Key'));
  finally
    Lifecycle.Free;
  end;
end;

procedure TCommerceServiceTests.Test_DeepKitSafeClient_IssueLicenseSnapshot_UsesRoute_AndParsesFields;
var
  Transport: TFakeCommerceTransport;
  Client: TDeepKitSafeClient;
  Snapshot: TDeepKitLicenseSnapshot;
  Request: TRecordedHttpRequest;
begin
  Transport := TFakeCommerceTransport.Create;
  Transport.QueueResponse(200,
    '{"snapshot_id":"lic_001","issued_at":"2026-05-08T10:00:00Z","expires_at":"2099-05-15T10:00:00Z","payload":{"app_id":"deepbase_desktop","device_id":"dev_001","tier":"pro"},"signature":"sig_001","key_id":"v1","schema_version":1,"revocation_version":2}');
  Client := TDeepKitSafeClient.Create(CreateSnapshotVerifiedConfig, Transport);
  try
    Snapshot := Client.IssueLicenseSnapshot('deepbase_desktop', 'dev_001');

    Assert.AreEqual('lic_001', Snapshot.SnapshotId);
    Assert.AreEqual('sig_001', Snapshot.Signature);
    Assert.AreEqual('v1', Snapshot.KeyId);
    Assert.AreEqual<Integer>(1, Snapshot.SchemaVersion);
    Assert.AreEqual<Integer>(2, Snapshot.RevocationVersion);
    Assert.IsTrue(Pos('"tier":"pro"', Snapshot.Payload) > 0);

    Assert.AreEqual<Integer>(1, Transport.RequestCount);
    Request := Transport.RequestAt(0);
    Assert.AreEqual('POST', Request.Method);
    Assert.AreEqual('https://api.example.test/dk/license/snapshot/issue',
      Request.Url);
    Assert.IsTrue(Pos('"app_id":"deepbase_desktop"', Request.Body) > 0);
    Assert.IsTrue(Pos('"device_id":"dev_001"', Request.Body) > 0);
  finally
    Client.Free;
  end;
end;

procedure TCommerceServiceTests.Test_DeepKitSafeClient_IssueLicenseSnapshot_RequiresVerifier;
var
  Transport: TFakeCommerceTransport;
  Client: TDeepKitSafeClient;
  Raised: Boolean;
begin
  Transport := TFakeCommerceTransport.Create;
  Transport.QueueResponse(200,
    '{"snapshot_id":"lic_001","issued_at":"2026-05-08T10:00:00Z","expires_at":"2099-05-15T10:00:00Z","payload":{"app_id":"deepbase_desktop","device_id":"dev_001","tier":"pro"},"signature":"sig_001","key_id":"v1","schema_version":1,"revocation_version":2}');
  Client := TDeepKitSafeClient.Create(
    TDeepKitSafeClientConfig.CreateDeepKit('https://api.example.test',
      'atk_001'),
    Transport);
  try
    Raised := False;
    try
      Client.IssueLicenseSnapshot('deepbase_desktop', 'dev_001');
    except
      on E: EDeepBaseCommerceValidationError do
        Raised := True;
    end;

    Assert.IsTrue(Raised,
      'License snapshot must fail closed when no verifier/public key is configured');
  finally
    Client.Free;
  end;
end;

procedure TCommerceServiceTests.Test_DeepKitSafeClient_IssueLicenseSnapshot_MissingSignature_Raises;
var
  Transport: TFakeCommerceTransport;
  Client: TDeepKitSafeClient;
  Raised: Boolean;
begin
  Transport := TFakeCommerceTransport.Create;
  Transport.QueueResponse(200,
    '{"snapshot_id":"lic_001","issued_at":"2026-05-08T10:00:00Z","expires_at":"2099-05-15T10:00:00Z","payload":{"app_id":"deepbase_desktop","device_id":"dev_001","tier":"pro"},"key_id":"v1","schema_version":1,"revocation_version":2}');
  Client := TDeepKitSafeClient.Create(CreateSnapshotVerifiedConfig, Transport);
  try
    Raised := False;
    try
      Client.IssueLicenseSnapshot('deepbase_desktop', 'dev_001');
    except
      on E: EDeepBaseCommerceValidationError do
        Raised := True;
    end;

    Assert.IsTrue(Raised, 'License snapshot without signature must be rejected');
  finally
    Client.Free;
  end;
end;

procedure TCommerceServiceTests.Test_DeepKitSafeClient_RefreshLicenseSnapshot_DeviceMismatch_Raises;
var
  Transport: TFakeCommerceTransport;
  Client: TDeepKitSafeClient;
  Raised: Boolean;
begin
  Transport := TFakeCommerceTransport.Create;
  Transport.QueueResponse(200,
    '{"snapshot_id":"lic_001","issued_at":"2026-05-08T10:00:00Z","expires_at":"2099-05-15T10:00:00Z","payload":{"app_id":"deepbase_desktop","device_id":"other_device","tier":"pro"},"signature":"sig_001","key_id":"v1","schema_version":1,"revocation_version":2}');
  Client := TDeepKitSafeClient.Create(CreateSnapshotVerifiedConfig, Transport);
  try
    Raised := False;
    try
      Client.RefreshLicenseSnapshot('deepbase_desktop', 'dev_001');
    except
      on E: EDeepBaseCommerceValidationError do
        Raised := True;
    end;

    Assert.IsTrue(Raised,
      'License snapshot device_id must be bound to the requested device');
  finally
    Client.Free;
  end;
end;

procedure TCommerceServiceTests.Test_DeepKitSafeClient_GetUpdatesManifest_UsesRoute_AndParsesFields;
var
  Transport: TFakeCommerceTransport;
  Client: TDeepKitSafeClient;
  Manifest: TDeepKitUpdateManifest;
  Request: TRecordedHttpRequest;
begin
  Transport := TFakeCommerceTransport.Create;
  Transport.QueueResponse(200,
    '{"app_id":"deepbase_desktop","current_version":"1.2.0","channel":"stable-pro","latest_version":"1.3.0","min_version":"1.0.0","manifest_url":"https://cdn.example.com/manifest.json","package_url":"https://cdn.example.com/deepbase-1.3.0.zip","package_hash":"sha256:abc","signature":"sig_abc","force_update":false,"release_notes":"fixes"}');
  Client := TDeepKitSafeClient.Create(
    TDeepKitSafeClientConfig.CreateDeepKit('https://api.example.test',
      'atk_001'),
    Transport);
  try
    Manifest := Client.GetUpdatesManifest('deepbase_desktop', '1.2.0',
      'stable');

    Assert.AreEqual('deepbase_desktop', Manifest.AppId);
    Assert.AreEqual('1.3.0', Manifest.LatestVersion);
    Assert.AreEqual('stable-pro', Manifest.Channel);
    Assert.AreEqual('https://cdn.example.com/manifest.json',
      Manifest.ManifestUrl);
    Assert.AreEqual('sha256:abc', Manifest.PackageHash);
    Assert.IsFalse(Manifest.ForceUpdate);

    Assert.AreEqual<Integer>(1, Transport.RequestCount);
    Request := Transport.RequestAt(0);
    Assert.AreEqual('GET', Request.Method);
    Assert.IsTrue(Request.Url.StartsWith(
      'https://api.example.test/dk/updates/manifest?'));
    Assert.IsTrue(Pos('app_id=deepbase_desktop', Request.Url) > 0);
    Assert.IsTrue(Pos('current_version=1.2.0', Request.Url) > 0);
    Assert.IsTrue(Pos('channel=stable', Request.Url) > 0);
    Assert.AreEqual('Bearer atk_001', HeaderValue(Request.Headers, 'Authorization'));
  finally
    Client.Free;
  end;
end;

procedure TCommerceServiceTests.Test_HttpStorage_RefundOrder_ServerAdmin_UsesRouteAndPayload;
var
  Transport: TFakeCommerceTransport;
  Storage: TCommerceHttpStorage;
  Request: TRecordedHttpRequest;
begin
  Transport := TFakeCommerceTransport.Create;
  Transport.QueueResponse(200, '{"ok":true}');
  Storage := TCommerceHttpStorage.Create(
    TCommerceBackendHttpConfig.CreateServerAdmin('https://api.example.test',
      'atk_admin'),
    Transport);
  try
    Storage.RefundOrder('ord_001', 3900, 'customer_request');

    Assert.AreEqual<Integer>(1, Transport.RequestCount);
    Request := Transport.RequestAt(0);
    Assert.AreEqual('POST', Request.Method);
    Assert.AreEqual('https://api.example.test/commerce/orders/ord_001/refund',
      Request.Url);
    Assert.AreEqual('Bearer atk_admin',
      HeaderValue(Request.Headers, 'Authorization'));
    Assert.IsTrue(Pos('"order_id":"ord_001"', Request.Body) > 0);
    Assert.IsTrue(Pos('"amount_minor":3900', Request.Body) > 0);
    Assert.IsTrue(Pos('"reason":"customer_request"', Request.Body) > 0);
  finally
    Storage.Free;
  end;
end;

procedure TCommerceServiceTests.Test_HttpStorage_RevokeEntitlement_ServerAdmin_UsesRouteAndPayload;
var
  Transport: TFakeCommerceTransport;
  Storage: TCommerceHttpStorage;
  Request: TRecordedHttpRequest;
begin
  Transport := TFakeCommerceTransport.Create;
  Transport.QueueResponse(200, '{"ok":true}');
  Storage := TCommerceHttpStorage.Create(
    TCommerceBackendHttpConfig.CreateServerAdmin('https://api.example.test',
      'atk_admin'),
    Transport);
  try
    Storage.RevokeEntitlement('ent_001', 'risk_control');

    Assert.AreEqual<Integer>(1, Transport.RequestCount);
    Request := Transport.RequestAt(0);
    Assert.AreEqual('POST', Request.Method);
    Assert.AreEqual(
      'https://api.example.test/commerce/entitlements/ent_001/revoke',
      Request.Url);
    Assert.AreEqual('Bearer atk_admin',
      HeaderValue(Request.Headers, 'Authorization'));
    Assert.IsTrue(Pos('"entitlement_id":"ent_001"', Request.Body) > 0);
    Assert.IsTrue(Pos('"reason":"risk_control"', Request.Body) > 0);
  finally
    Storage.Free;
  end;
end;

procedure TCommerceServiceTests.Test_HttpStorage_RevokeLicenseSnapshot_ServerAdmin_UsesDeepKitRoute;
var
  Transport: TFakeCommerceTransport;
  Storage: TCommerceHttpStorage;
  Request: TRecordedHttpRequest;
begin
  Transport := TFakeCommerceTransport.Create;
  Transport.QueueResponse(200, '{"ok":true,"revocation_version":3}');
  Storage := TCommerceHttpStorage.Create(
    TCommerceBackendHttpConfig.CreateDeepKitServerAdmin(
      'https://api.example.test', 'atk_admin'),
    Transport);
  try
    Storage.RevokeLicenseSnapshot('deepbase_desktop', 'dev_001', 'snap_001',
      'refund');

    Assert.AreEqual<Integer>(1, Transport.RequestCount);
    Request := Transport.RequestAt(0);
    Assert.AreEqual('POST', Request.Method);
    Assert.AreEqual('https://api.example.test/dk/license/snapshot/revoke',
      Request.Url);
    Assert.AreEqual('Bearer atk_admin',
      HeaderValue(Request.Headers, 'Authorization'));
    Assert.IsTrue(Pos('"app_id":"deepbase_desktop"', Request.Body) > 0);
    Assert.IsTrue(Pos('"device_id":"dev_001"', Request.Body) > 0);
    Assert.IsTrue(Pos('"snapshot_id":"snap_001"', Request.Body) > 0);
    Assert.IsTrue(Pos('"reason":"refund"', Request.Body) > 0);
  finally
    Storage.Free;
  end;
end;

procedure TCommerceServiceTests.Test_SupabaseAdapter_DefaultConfig_BlockedAsServerOnlyPrototype;
var
  Raised: Boolean;
  Storage: ICommerceStorage;
begin
  Raised := False;
  try
    Storage := TSupabaseCommerceStorage.Create(
      TSupabaseConfig.Create('https://sb.example.test', 'anon_key'));
  except
    on E: EDeepBaseCommerceValidationError do
      Raised := True;
  end;
  Assert.IsTrue(Raised);
end;

procedure TCommerceServiceTests.Test_SupabaseAdapter_CreateServerOnly_AllowsConstruction;
var
  Storage: ICommerceStorage;
begin
  Storage := TSupabaseCommerceStorage.Create(
    TSupabaseConfig.CreateServerOnly('https://sb.example.test', 'service_key'));
  Assert.IsNotNull(Storage);
end;

procedure TCommerceServiceTests.Test_FirebaseAdapter_DefaultConfig_BlockedAsServerOnlyPrototype;
var
  Raised: Boolean;
  Storage: ICommerceStorage;
begin
  Raised := False;
  try
    Storage := TFirebaseCommerceStorage.Create(
      TFirebaseConfig.Create('project_001', 'access_token'));
  except
    on E: EDeepBaseCommerceValidationError do
      Raised := True;
  end;
  Assert.IsTrue(Raised);
end;

procedure TCommerceServiceTests.Test_FirebaseAdapter_CreateServerOnly_AllowsConstruction;
var
  Storage: ICommerceStorage;
begin
  Storage := TFirebaseCommerceStorage.Create(
    TFirebaseConfig.CreateServerOnly('project_001', 'access_token'));
  Assert.IsNotNull(Storage);
end;

initialization
  TDUnitX.RegisterTestFixture(TCommerceServiceTests);

end.
