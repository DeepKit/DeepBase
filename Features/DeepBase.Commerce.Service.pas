unit DeepBase.Commerce.Service;

interface

uses
  System.SysUtils,
  System.DateUtils,
  System.Generics.Collections,
  DeepBase.Commerce.Types,
  DeepBase.Commerce.Storage;

type
  ICommercePaymentGateway = interface
    ['{C6C54E5E-4C3C-4C29-AB64-60E5637C4BF1}']
    function CreatePaymentIntent(const AOrder: TCommerceOrderData;
      const APayment: TCommercePaymentData; const APayerOpenId: string): TCommercePaymentIntent;
  end;

  ICommerceNotificationVerifier = interface
    ['{D7E8F9A0-B1C2-4D3E-A5B6-7C8D9E0F1A2B}']
    function VerifyNotification(const ARawBody: string;
      const AHeaders: TArray<TPair<string, string>>): TCommercePaymentNotification;
  end;

  TDeepBaseCommerceService = class
  private
    FStorage: ICommerceStorage;
    FGateways: TDictionary<Integer, ICommercePaymentGateway>;
    FVerifiers: TDictionary<Integer, ICommerceNotificationVerifier>;
    function GatewayKey(AProvider: TCommercePaymentProvider): Integer;
    function RequireProduct(const AAppId, AProductId: string): TCommerceProductData;
    function IsEntitlementUsable(const AEntitlement: TCommerceEntitlementData): Boolean;
    procedure GrantEntitlementForOrder(const AOrder: TCommerceOrderData);
  public
    constructor Create(const AStorage: ICommerceStorage);
    destructor Destroy; override;

    procedure RegisterPaymentGateway(AProvider: TCommercePaymentProvider;
      const AGateway: ICommercePaymentGateway);
    procedure RegisterNotificationVerifier(AProvider: TCommercePaymentProvider;
      const AVerifier: ICommerceNotificationVerifier);
    procedure RegisterProduct(const AProduct: TCommerceProductData);

    function EnsureUserForIdentity(AProvider: TCommerceAuthProvider;
      const AProviderUserId, AAppId: string; const AUnionId: string = ''): TCommerceUserData;
    function CreateOrder(const AUserId, AAppId, AProductId: string): TCommerceOrderData;
    function BeginPayment(const AOrderId: string; AProvider: TCommercePaymentProvider;
      AChannel: TCommercePaymentChannel; const APayerOpenId: string = ''): TCommercePaymentIntent;
    function ConfirmPayment(const ANotification: TCommercePaymentNotification): TCommerceOrderData;
    function VerifyAndConfirmPayment(AProvider: TCommercePaymentProvider;
      const ARawBody: string;
      const AHeaders: TArray<TPair<string, string>>): TCommerceOrderData;

    function ListEntitlements(const AUserId, AAppId: string): TCommerceEntitlementArray;
    function HasEntitlement(const AUserId, AAppId, ACode: string): Boolean;
    function ConsumeEntitlement(const AUserId, AAppId, ACode: string;
      ACount: Integer = 1): Boolean;

    property Storage: ICommerceStorage read FStorage;
  end;

implementation

{ TDeepBaseCommerceService }

constructor TDeepBaseCommerceService.Create(const AStorage: ICommerceStorage);
begin
  inherited Create;
  if not Assigned(AStorage) then
    raise EDeepBaseCommerceValidationError.Create('Commerce storage is required');
  FStorage := AStorage;
  FGateways := TDictionary<Integer, ICommercePaymentGateway>.Create;
  FVerifiers := TDictionary<Integer, ICommerceNotificationVerifier>.Create;
end;

destructor TDeepBaseCommerceService.Destroy;
begin
  FreeAndNil(FVerifiers);
  FreeAndNil(FGateways);
  inherited;
end;

function TDeepBaseCommerceService.GatewayKey(
  AProvider: TCommercePaymentProvider): Integer;
begin
  Result := Ord(AProvider);
end;

procedure TDeepBaseCommerceService.RegisterPaymentGateway(
  AProvider: TCommercePaymentProvider; const AGateway: ICommercePaymentGateway);
begin
  if not Assigned(AGateway) then
    raise EDeepBaseCommerceValidationError.Create('Payment gateway is required');
  FGateways.AddOrSetValue(GatewayKey(AProvider), AGateway);
end;

procedure TDeepBaseCommerceService.RegisterNotificationVerifier(
  AProvider: TCommercePaymentProvider;
  const AVerifier: ICommerceNotificationVerifier);
begin
  if not Assigned(AVerifier) then
    raise EDeepBaseCommerceValidationError.Create('Notification verifier is required');
  FVerifiers.AddOrSetValue(GatewayKey(AProvider), AVerifier);
end;

procedure TDeepBaseCommerceService.RegisterProduct(
  const AProduct: TCommerceProductData);
begin
  if AProduct.AppId = '' then
    raise EDeepBaseCommerceValidationError.Create('Product AppId is required');
  if AProduct.ProductId = '' then
    raise EDeepBaseCommerceValidationError.Create('ProductId is required');
  if AProduct.AmountMinor < 0 then
    raise EDeepBaseCommerceValidationError.Create('Product amount cannot be negative');
  if AProduct.EntitlementCode = '' then
    raise EDeepBaseCommerceValidationError.Create('Product entitlement code is required');
  FStorage.UpsertProduct(AProduct);
end;

function TDeepBaseCommerceService.RequireProduct(const AAppId,
  AProductId: string): TCommerceProductData;
begin
  if not FStorage.FindProduct(AAppId, AProductId, Result) then
    raise EDeepBaseCommerceNotFoundError.CreateFmt(
      'Product not found: %s/%s', [AAppId, AProductId]);
  if not Result.IsActive then
    raise EDeepBaseCommerceValidationError.CreateFmt(
      'Product is inactive: %s/%s', [AAppId, AProductId]);
end;

function TDeepBaseCommerceService.EnsureUserForIdentity(
  AProvider: TCommerceAuthProvider; const AProviderUserId, AAppId,
  AUnionId: string): TCommerceUserData;
var
  Identity: TCommerceIdentityData;
begin
  if AProviderUserId = '' then
    raise EDeepBaseCommerceValidationError.Create('Provider user id is required');
  if AAppId = '' then
    raise EDeepBaseCommerceValidationError.Create('AppId is required');

  if FStorage.FindUserByIdentity(AProvider, AProviderUserId, AAppId, Result) then
    Exit;

  Result := TCommerceUserData.CreateNew(TCommerceIds.NewId('usr'));
  FStorage.UpsertUser(Result);

  Identity.UserId := Result.UserId;
  Identity.Provider := AProvider;
  Identity.ProviderUserId := AProviderUserId;
  Identity.AppId := AAppId;
  Identity.UnionId := AUnionId;
  Identity.CreatedAtISO := CommerceNowISO;
  FStorage.LinkIdentity(Identity);
end;

function TDeepBaseCommerceService.CreateOrder(const AUserId, AAppId,
  AProductId: string): TCommerceOrderData;
var
  User: TCommerceUserData;
  Product: TCommerceProductData;
begin
  if not FStorage.FindUserById(AUserId, User) then
    raise EDeepBaseCommerceNotFoundError.CreateFmt('User not found: %s', [AUserId]);
  if not User.IsActive then
    raise EDeepBaseCommerceValidationError.CreateFmt('User is inactive: %s', [AUserId]);

  Product := RequireProduct(AAppId, AProductId);

  Result.OrderId := TCommerceIds.NewId('ord');
  Result.UserId := AUserId;
  Result.AppId := AAppId;
  Result.ProductId := AProductId;
  Result.OutTradeNo := TCommerceIds.NewOutTradeNo;
  Result.Title := Product.Name;
  Result.AmountMinor := Product.AmountMinor;
  Result.Currency := Product.Currency;
  Result.Status := cosCreated;
  Result.CreatedAtISO := CommerceNowISO;
  Result.PaidAtISO := '';
  FStorage.CreateOrder(Result);
end;

function TDeepBaseCommerceService.BeginPayment(const AOrderId: string;
  AProvider: TCommercePaymentProvider; AChannel: TCommercePaymentChannel;
  const APayerOpenId: string): TCommercePaymentIntent;
var
  Order: TCommerceOrderData;
  Payment: TCommercePaymentData;
  Gateway: ICommercePaymentGateway;
begin
  if not FStorage.FindOrderById(AOrderId, Order) then
    raise EDeepBaseCommerceNotFoundError.CreateFmt('Order not found: %s', [AOrderId]);
  if Order.Status = cosPaid then
    raise EDeepBaseCommerceValidationError.CreateFmt('Order already paid: %s', [AOrderId]);
  if not FGateways.TryGetValue(GatewayKey(AProvider), Gateway) then
    raise EDeepBaseCommercePaymentError.CreateFmt(
      'Payment gateway is not registered: %s', [CommercePaymentProviderToStr(AProvider)]);

  if not FStorage.FindPaymentByOrderId(AOrderId, Payment) then
  begin
    Payment.PaymentId := TCommerceIds.NewId('pay');
    Payment.OrderId := AOrderId;
    Payment.Provider := AProvider;
    Payment.Channel := AChannel;
    Payment.ProviderTradeNo := '';
    Payment.PrepayId := '';
    Payment.Status := cpsCreated;
    Payment.RawPayload := '';
    Payment.CreatedAtISO := CommerceNowISO;
    Payment.PaidAtISO := '';
    FStorage.CreatePayment(Payment);
  end;

  Result := Gateway.CreatePaymentIntent(Order, Payment, APayerOpenId);
  if not Result.Success then
    raise EDeepBaseCommercePaymentError.CreateFmt('%s: %s',
      [Result.ErrorCode, Result.ErrorMessage]);

  Payment.PrepayId := Result.PrepayId;
  Payment.RawPayload := Result.RawResponse;
  Payment.Status := cpsPending;
  FStorage.UpdatePayment(Payment);

  Order.Status := cosPaying;
  FStorage.UpdateOrder(Order);

  Result.PaymentId := Payment.PaymentId;
  Result.OutTradeNo := Order.OutTradeNo;
end;

function TDeepBaseCommerceService.ConfirmPayment(
  const ANotification: TCommercePaymentNotification): TCommerceOrderData;
var
  Payment: TCommercePaymentData;
begin
  if ANotification.OutTradeNo = '' then
    raise EDeepBaseCommerceValidationError.Create('Payment notification missing out_trade_no');
  if not FStorage.FindOrderByOutTradeNo(ANotification.OutTradeNo, Result) then
    raise EDeepBaseCommerceNotFoundError.CreateFmt(
      'Order not found by out_trade_no: %s', [ANotification.OutTradeNo]);

  if (Result.AmountMinor <> ANotification.AmountMinor) or
     not SameText(Result.Currency, ANotification.Currency) then
    raise EDeepBaseCommercePaymentError.CreateFmt(
      'Payment amount mismatch for order %s', [Result.OrderId]);

  if not FStorage.FindPaymentByOrderId(Result.OrderId, Payment) then
  begin
    Payment.PaymentId := TCommerceIds.NewId('pay');
    Payment.OrderId := Result.OrderId;
    Payment.Provider := ANotification.Provider;
    Payment.Channel := cpcManual;
    Payment.ProviderTradeNo := '';
    Payment.PrepayId := '';
    Payment.Status := cpsCreated;
    Payment.RawPayload := '';
    Payment.CreatedAtISO := CommerceNowISO;
    Payment.PaidAtISO := '';
    FStorage.CreatePayment(Payment);
  end;

  if Result.Status = cosPaid then
    Exit;

  Payment.Provider := ANotification.Provider;
  Payment.ProviderTradeNo := ANotification.ProviderTradeNo;
  Payment.RawPayload := ANotification.RawPayload;

  if ANotification.Success then
  begin
    Payment.Status := cpsPaid;
    Payment.PaidAtISO := ANotification.PaidAtISO;
    if Payment.PaidAtISO = '' then
      Payment.PaidAtISO := CommerceNowISO;
    FStorage.UpdatePayment(Payment);

    Result.Status := cosPaid;
    Result.PaidAtISO := Payment.PaidAtISO;
    FStorage.UpdateOrder(Result);

    GrantEntitlementForOrder(Result);
  end
  else
  begin
    Payment.Status := cpsFailed;
    FStorage.UpdatePayment(Payment);
    Result.Status := cosFailed;
    FStorage.UpdateOrder(Result);
  end;
end;

function TDeepBaseCommerceService.VerifyAndConfirmPayment(
  AProvider: TCommercePaymentProvider; const ARawBody: string;
  const AHeaders: TArray<TPair<string, string>>): TCommerceOrderData;
var
  Verifier: ICommerceNotificationVerifier;
  Notification: TCommercePaymentNotification;
begin
  if not FVerifiers.TryGetValue(GatewayKey(AProvider), Verifier) then
    raise EDeepBaseCommercePaymentError.CreateFmt(
      'Notification verifier not registered for provider: %s',
      [CommercePaymentProviderToStr(AProvider)]);
  Notification := Verifier.VerifyNotification(ARawBody, AHeaders);
  Result := ConfirmPayment(Notification);
end;

procedure TDeepBaseCommerceService.GrantEntitlementForOrder(
  const AOrder: TCommerceOrderData);
var
  Product: TCommerceProductData;
  Entitlements: TCommerceEntitlementArray;
  Entitlement: TCommerceEntitlementData;
  I: Integer;
  ValidFrom: TDateTime;
begin
  Product := RequireProduct(AOrder.AppId, AOrder.ProductId);
  Entitlements := FStorage.ListEntitlements(AOrder.UserId, AOrder.AppId);
  for I := 0 to High(Entitlements) do
    if SameText(Entitlements[I].SourceOrderId, AOrder.OrderId) then
      Exit;

  ValidFrom := Now;
  Entitlement.EntitlementId := TCommerceIds.NewId('ent');
  Entitlement.UserId := AOrder.UserId;
  Entitlement.AppId := AOrder.AppId;
  Entitlement.ProductId := AOrder.ProductId;
  Entitlement.Code := Product.EntitlementCode;
  Entitlement.Status := cesActive;
  Entitlement.ValidFromISO := DateToISO8601(ValidFrom, False);
  if Product.EntitlementDurationDays > 0 then
    Entitlement.ValidUntilISO := DateToISO8601(
      IncDay(ValidFrom, Product.EntitlementDurationDays), False)
  else
    Entitlement.ValidUntilISO := '';
  Entitlement.RemainingQuota := Product.InitialQuota;
  Entitlement.SourceOrderId := AOrder.OrderId;
  FStorage.UpsertEntitlement(Entitlement);
end;

function TDeepBaseCommerceService.ListEntitlements(const AUserId,
  AAppId: string): TCommerceEntitlementArray;
begin
  Result := FStorage.ListEntitlements(AUserId, AAppId);
end;

function TDeepBaseCommerceService.IsEntitlementUsable(
  const AEntitlement: TCommerceEntitlementData): Boolean;
var
  ExpiresAt: TDateTime;
begin
  Result := AEntitlement.Status = cesActive;
  if not Result then
    Exit;
  if (AEntitlement.RemainingQuota = 0) then
    Exit(False);
  if AEntitlement.ValidUntilISO <> '' then
  begin
    try
      ExpiresAt := ISO8601ToDate(AEntitlement.ValidUntilISO, False);
      Result := ExpiresAt > Now;
    except
      Result := False;
    end;
  end;
end;

function TDeepBaseCommerceService.HasEntitlement(const AUserId, AAppId,
  ACode: string): Boolean;
var
  Entitlements: TCommerceEntitlementArray;
  I: Integer;
begin
  Result := False;
  Entitlements := FStorage.ListEntitlements(AUserId, AAppId);
  for I := 0 to High(Entitlements) do
    if SameText(Entitlements[I].Code, ACode) and
       IsEntitlementUsable(Entitlements[I]) then
      Exit(True);
end;

function TDeepBaseCommerceService.ConsumeEntitlement(const AUserId, AAppId,
  ACode: string; ACount: Integer): Boolean;
var
  Entitlements: TCommerceEntitlementArray;
  Entitlement: TCommerceEntitlementData;
  I: Integer;
begin
  Result := False;
  Entitlements := FStorage.ListEntitlements(AUserId, AAppId);
  for I := 0 to High(Entitlements) do
  begin
    if SameText(Entitlements[I].Code, ACode) and
       IsEntitlementUsable(Entitlements[I]) then
    begin
      Result := FStorage.ConsumeEntitlement(
        Entitlements[I].EntitlementId, ACount, Entitlement);
      Exit;
    end;
  end;
end;

end.
