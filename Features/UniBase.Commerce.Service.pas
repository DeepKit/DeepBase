unit UniBase.Commerce.Service;

interface

uses
  System.SysUtils,
  System.DateUtils,
  System.Generics.Collections,
  UniBase.Commerce.Types,
  UniBase.Commerce.Storage;

type
  ICommercePaymentGateway = interface
    ['{C6C54E5E-4C3C-4C29-AB64-60E5637C4BF1}']
    function CreatePaymentIntent(const AOrder: TCommerceOrderData;
      const APayment: TCommercePaymentData; const APayerOpenId: string): TCommercePaymentIntent;
  end;

  TUniBaseCommerceService = class
  private
    FStorage: ICommerceStorage;
    FGateways: TDictionary<Integer, ICommercePaymentGateway>;
    function GatewayKey(AProvider: TCommercePaymentProvider): Integer;
    function RequireProduct(const AAppId, AProductId: string): TCommerceProductData;
    function IsEntitlementUsable(const AEntitlement: TCommerceEntitlementData): Boolean;
    procedure GrantEntitlementForOrder(const AOrder: TCommerceOrderData);
  public
    constructor Create(const AStorage: ICommerceStorage);
    destructor Destroy; override;

    procedure RegisterPaymentGateway(AProvider: TCommercePaymentProvider;
      const AGateway: ICommercePaymentGateway);
    procedure RegisterProduct(const AProduct: TCommerceProductData);

    function EnsureUserForIdentity(AProvider: TCommerceAuthProvider;
      const AProviderUserId, AAppId: string; const AUnionId: string = ''): TCommerceUserData;
    function CreateOrder(const AUserId, AAppId, AProductId: string): TCommerceOrderData;
    function BeginPayment(const AOrderId: string; AProvider: TCommercePaymentProvider;
      AChannel: TCommercePaymentChannel; const APayerOpenId: string = ''): TCommercePaymentIntent;
    function ConfirmPayment(const ANotification: TCommercePaymentNotification): TCommerceOrderData;

    function ListEntitlements(const AUserId, AAppId: string): TCommerceEntitlementArray;
    function HasEntitlement(const AUserId, AAppId, ACode: string): Boolean;
    function ConsumeEntitlement(const AUserId, AAppId, ACode: string;
      ACount: Integer = 1): Boolean;

    property Storage: ICommerceStorage read FStorage;
  end;

implementation

{ TUniBaseCommerceService }

constructor TUniBaseCommerceService.Create(const AStorage: ICommerceStorage);
begin
  inherited Create;
  if not Assigned(AStorage) then
    raise EUniBaseCommerceValidationError.Create('Commerce storage is required');
  FStorage := AStorage;
  FGateways := TDictionary<Integer, ICommercePaymentGateway>.Create;
end;

destructor TUniBaseCommerceService.Destroy;
begin
  FreeAndNil(FGateways);
  inherited;
end;

function TUniBaseCommerceService.GatewayKey(
  AProvider: TCommercePaymentProvider): Integer;
begin
  Result := Ord(AProvider);
end;

procedure TUniBaseCommerceService.RegisterPaymentGateway(
  AProvider: TCommercePaymentProvider; const AGateway: ICommercePaymentGateway);
begin
  if not Assigned(AGateway) then
    raise EUniBaseCommerceValidationError.Create('Payment gateway is required');
  FGateways.AddOrSetValue(GatewayKey(AProvider), AGateway);
end;

procedure TUniBaseCommerceService.RegisterProduct(
  const AProduct: TCommerceProductData);
begin
  if AProduct.AppId = '' then
    raise EUniBaseCommerceValidationError.Create('Product AppId is required');
  if AProduct.ProductId = '' then
    raise EUniBaseCommerceValidationError.Create('ProductId is required');
  if AProduct.AmountMinor < 0 then
    raise EUniBaseCommerceValidationError.Create('Product amount cannot be negative');
  if AProduct.EntitlementCode = '' then
    raise EUniBaseCommerceValidationError.Create('Product entitlement code is required');
  FStorage.UpsertProduct(AProduct);
end;

function TUniBaseCommerceService.RequireProduct(const AAppId,
  AProductId: string): TCommerceProductData;
begin
  if not FStorage.FindProduct(AAppId, AProductId, Result) then
    raise EUniBaseCommerceNotFoundError.CreateFmt(
      'Product not found: %s/%s', [AAppId, AProductId]);
  if not Result.IsActive then
    raise EUniBaseCommerceValidationError.CreateFmt(
      'Product is inactive: %s/%s', [AAppId, AProductId]);
end;

function TUniBaseCommerceService.EnsureUserForIdentity(
  AProvider: TCommerceAuthProvider; const AProviderUserId, AAppId,
  AUnionId: string): TCommerceUserData;
var
  Identity: TCommerceIdentityData;
begin
  if AProviderUserId = '' then
    raise EUniBaseCommerceValidationError.Create('Provider user id is required');
  if AAppId = '' then
    raise EUniBaseCommerceValidationError.Create('AppId is required');

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

function TUniBaseCommerceService.CreateOrder(const AUserId, AAppId,
  AProductId: string): TCommerceOrderData;
var
  User: TCommerceUserData;
  Product: TCommerceProductData;
begin
  if not FStorage.FindUserById(AUserId, User) then
    raise EUniBaseCommerceNotFoundError.CreateFmt('User not found: %s', [AUserId]);
  if not User.IsActive then
    raise EUniBaseCommerceValidationError.CreateFmt('User is inactive: %s', [AUserId]);

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

function TUniBaseCommerceService.BeginPayment(const AOrderId: string;
  AProvider: TCommercePaymentProvider; AChannel: TCommercePaymentChannel;
  const APayerOpenId: string): TCommercePaymentIntent;
var
  Order: TCommerceOrderData;
  Payment: TCommercePaymentData;
  Gateway: ICommercePaymentGateway;
begin
  if not FStorage.FindOrderById(AOrderId, Order) then
    raise EUniBaseCommerceNotFoundError.CreateFmt('Order not found: %s', [AOrderId]);
  if Order.Status = cosPaid then
    raise EUniBaseCommerceValidationError.CreateFmt('Order already paid: %s', [AOrderId]);
  if not FGateways.TryGetValue(GatewayKey(AProvider), Gateway) then
    raise EUniBaseCommercePaymentError.CreateFmt(
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
    raise EUniBaseCommercePaymentError.CreateFmt('%s: %s',
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

function TUniBaseCommerceService.ConfirmPayment(
  const ANotification: TCommercePaymentNotification): TCommerceOrderData;
var
  Payment: TCommercePaymentData;
begin
  if ANotification.OutTradeNo = '' then
    raise EUniBaseCommerceValidationError.Create('Payment notification missing out_trade_no');
  if not FStorage.FindOrderByOutTradeNo(ANotification.OutTradeNo, Result) then
    raise EUniBaseCommerceNotFoundError.CreateFmt(
      'Order not found by out_trade_no: %s', [ANotification.OutTradeNo]);

  if (Result.AmountMinor <> ANotification.AmountMinor) or
     not SameText(Result.Currency, ANotification.Currency) then
    raise EUniBaseCommercePaymentError.CreateFmt(
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

procedure TUniBaseCommerceService.GrantEntitlementForOrder(
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

function TUniBaseCommerceService.ListEntitlements(const AUserId,
  AAppId: string): TCommerceEntitlementArray;
begin
  Result := FStorage.ListEntitlements(AUserId, AAppId);
end;

function TUniBaseCommerceService.IsEntitlementUsable(
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

function TUniBaseCommerceService.HasEntitlement(const AUserId, AAppId,
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

function TUniBaseCommerceService.ConsumeEntitlement(const AUserId, AAppId,
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
