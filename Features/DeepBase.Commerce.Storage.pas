unit DeepBase.Commerce.Storage;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  DeepBase.Commerce.Types;

type
  ICommerceStorage = interface
    ['{3E3C548C-9890-4C7A-8524-685F9F9F7A7D}']
    function FindUserById(const AUserId: string; out AUser: TCommerceUserData): Boolean;
    function FindUserByIdentity(AProvider: TCommerceAuthProvider;
      const AProviderUserId, AAppId: string; out AUser: TCommerceUserData): Boolean;
    procedure UpsertUser(const AUser: TCommerceUserData);
    procedure LinkIdentity(const AIdentity: TCommerceIdentityData);

    function FindProduct(const AAppId, AProductId: string;
      out AProduct: TCommerceProductData): Boolean;
    procedure UpsertProduct(const AProduct: TCommerceProductData);

    procedure CreateOrder(const AOrder: TCommerceOrderData);
    function FindOrderById(const AOrderId: string; out AOrder: TCommerceOrderData): Boolean;
    function FindOrderByOutTradeNo(const AOutTradeNo: string;
      out AOrder: TCommerceOrderData): Boolean;
    procedure UpdateOrder(const AOrder: TCommerceOrderData);

    procedure CreatePayment(const APayment: TCommercePaymentData);
    function FindPaymentByOrderId(const AOrderId: string;
      out APayment: TCommercePaymentData): Boolean;
    procedure UpdatePayment(const APayment: TCommercePaymentData);

    procedure UpsertEntitlement(const AEntitlement: TCommerceEntitlementData);
    function ListEntitlements(const AUserId, AAppId: string): TCommerceEntitlementArray;
    function FindEntitlement(const AUserId, AAppId, ACode: string;
      out AEntitlement: TCommerceEntitlementData): Boolean;
    function ConsumeEntitlement(const AEntitlementId: string; ACount: Integer;
      out AEntitlement: TCommerceEntitlementData): Boolean;
  end;

  TInMemoryCommerceStorage = class(TInterfacedObject, ICommerceStorage)
  private
    FUsers: TDictionary<string, TCommerceUserData>;
    FIdentityToUser: TDictionary<string, string>;
    FProducts: TDictionary<string, TCommerceProductData>;
    FOrders: TDictionary<string, TCommerceOrderData>;
    FOutTradeNoToOrder: TDictionary<string, string>;
    FPayments: TDictionary<string, TCommercePaymentData>;
    FOrderToPayment: TDictionary<string, string>;
    FEntitlements: TDictionary<string, TCommerceEntitlementData>;
    function IdentityKey(AProvider: TCommerceAuthProvider;
      const AProviderUserId, AAppId: string): string;
    function ProductKey(const AAppId, AProductId: string): string;
  public
    constructor Create;
    destructor Destroy; override;

    function FindUserById(const AUserId: string; out AUser: TCommerceUserData): Boolean;
    function FindUserByIdentity(AProvider: TCommerceAuthProvider;
      const AProviderUserId, AAppId: string; out AUser: TCommerceUserData): Boolean;
    procedure UpsertUser(const AUser: TCommerceUserData);
    procedure LinkIdentity(const AIdentity: TCommerceIdentityData);

    function FindProduct(const AAppId, AProductId: string;
      out AProduct: TCommerceProductData): Boolean;
    procedure UpsertProduct(const AProduct: TCommerceProductData);

    procedure CreateOrder(const AOrder: TCommerceOrderData);
    function FindOrderById(const AOrderId: string; out AOrder: TCommerceOrderData): Boolean;
    function FindOrderByOutTradeNo(const AOutTradeNo: string;
      out AOrder: TCommerceOrderData): Boolean;
    procedure UpdateOrder(const AOrder: TCommerceOrderData);

    procedure CreatePayment(const APayment: TCommercePaymentData);
    function FindPaymentByOrderId(const AOrderId: string;
      out APayment: TCommercePaymentData): Boolean;
    procedure UpdatePayment(const APayment: TCommercePaymentData);

    procedure UpsertEntitlement(const AEntitlement: TCommerceEntitlementData);
    function ListEntitlements(const AUserId, AAppId: string): TCommerceEntitlementArray;
    function FindEntitlement(const AUserId, AAppId, ACode: string;
      out AEntitlement: TCommerceEntitlementData): Boolean;
    function ConsumeEntitlement(const AEntitlementId: string; ACount: Integer;
      out AEntitlement: TCommerceEntitlementData): Boolean;
  end;

implementation

{ TInMemoryCommerceStorage }

constructor TInMemoryCommerceStorage.Create;
begin
  inherited Create;
  FUsers := TDictionary<string, TCommerceUserData>.Create;
  FIdentityToUser := TDictionary<string, string>.Create;
  FProducts := TDictionary<string, TCommerceProductData>.Create;
  FOrders := TDictionary<string, TCommerceOrderData>.Create;
  FOutTradeNoToOrder := TDictionary<string, string>.Create;
  FPayments := TDictionary<string, TCommercePaymentData>.Create;
  FOrderToPayment := TDictionary<string, string>.Create;
  FEntitlements := TDictionary<string, TCommerceEntitlementData>.Create;
end;

destructor TInMemoryCommerceStorage.Destroy;
begin
  FreeAndNil(FEntitlements);
  FreeAndNil(FOrderToPayment);
  FreeAndNil(FPayments);
  FreeAndNil(FOutTradeNoToOrder);
  FreeAndNil(FOrders);
  FreeAndNil(FProducts);
  FreeAndNil(FIdentityToUser);
  FreeAndNil(FUsers);
  inherited;
end;

function TInMemoryCommerceStorage.IdentityKey(AProvider: TCommerceAuthProvider;
  const AProviderUserId, AAppId: string): string;
begin
  Result := IntToStr(Ord(AProvider)) + '|' + LowerCase(AAppId) + '|' + AProviderUserId;
end;

function TInMemoryCommerceStorage.ProductKey(const AAppId,
  AProductId: string): string;
begin
  Result := LowerCase(AAppId) + '|' + LowerCase(AProductId);
end;

function TInMemoryCommerceStorage.FindUserById(const AUserId: string;
  out AUser: TCommerceUserData): Boolean;
begin
  Result := FUsers.TryGetValue(AUserId, AUser);
end;

function TInMemoryCommerceStorage.FindUserByIdentity(
  AProvider: TCommerceAuthProvider; const AProviderUserId, AAppId: string;
  out AUser: TCommerceUserData): Boolean;
var
  UserId: string;
begin
  Result := FIdentityToUser.TryGetValue(
    IdentityKey(AProvider, AProviderUserId, AAppId), UserId) and
    FUsers.TryGetValue(UserId, AUser);
end;

procedure TInMemoryCommerceStorage.UpsertUser(const AUser: TCommerceUserData);
begin
  FUsers.AddOrSetValue(AUser.UserId, AUser);
end;

procedure TInMemoryCommerceStorage.LinkIdentity(
  const AIdentity: TCommerceIdentityData);
begin
  FIdentityToUser.AddOrSetValue(
    IdentityKey(AIdentity.Provider, AIdentity.ProviderUserId, AIdentity.AppId),
    AIdentity.UserId);
end;

function TInMemoryCommerceStorage.FindProduct(const AAppId,
  AProductId: string; out AProduct: TCommerceProductData): Boolean;
begin
  Result := FProducts.TryGetValue(ProductKey(AAppId, AProductId), AProduct);
end;

procedure TInMemoryCommerceStorage.UpsertProduct(
  const AProduct: TCommerceProductData);
begin
  FProducts.AddOrSetValue(ProductKey(AProduct.AppId, AProduct.ProductId), AProduct);
end;

procedure TInMemoryCommerceStorage.CreateOrder(const AOrder: TCommerceOrderData);
begin
  FOrders.Add(AOrder.OrderId, AOrder);
  FOutTradeNoToOrder.Add(AOrder.OutTradeNo, AOrder.OrderId);
end;

function TInMemoryCommerceStorage.FindOrderById(const AOrderId: string;
  out AOrder: TCommerceOrderData): Boolean;
begin
  Result := FOrders.TryGetValue(AOrderId, AOrder);
end;

function TInMemoryCommerceStorage.FindOrderByOutTradeNo(
  const AOutTradeNo: string; out AOrder: TCommerceOrderData): Boolean;
var
  OrderId: string;
begin
  Result := FOutTradeNoToOrder.TryGetValue(AOutTradeNo, OrderId) and
    FOrders.TryGetValue(OrderId, AOrder);
end;

procedure TInMemoryCommerceStorage.UpdateOrder(const AOrder: TCommerceOrderData);
begin
  FOrders.AddOrSetValue(AOrder.OrderId, AOrder);
  FOutTradeNoToOrder.AddOrSetValue(AOrder.OutTradeNo, AOrder.OrderId);
end;

procedure TInMemoryCommerceStorage.CreatePayment(
  const APayment: TCommercePaymentData);
begin
  FPayments.Add(APayment.PaymentId, APayment);
  FOrderToPayment.AddOrSetValue(APayment.OrderId, APayment.PaymentId);
end;

function TInMemoryCommerceStorage.FindPaymentByOrderId(
  const AOrderId: string; out APayment: TCommercePaymentData): Boolean;
var
  PaymentId: string;
begin
  Result := FOrderToPayment.TryGetValue(AOrderId, PaymentId) and
    FPayments.TryGetValue(PaymentId, APayment);
end;

procedure TInMemoryCommerceStorage.UpdatePayment(
  const APayment: TCommercePaymentData);
begin
  FPayments.AddOrSetValue(APayment.PaymentId, APayment);
  FOrderToPayment.AddOrSetValue(APayment.OrderId, APayment.PaymentId);
end;

procedure TInMemoryCommerceStorage.UpsertEntitlement(
  const AEntitlement: TCommerceEntitlementData);
begin
  FEntitlements.AddOrSetValue(AEntitlement.EntitlementId, AEntitlement);
end;

function TInMemoryCommerceStorage.ListEntitlements(const AUserId,
  AAppId: string): TCommerceEntitlementArray;
var
  Pair: TPair<string, TCommerceEntitlementData>;
  Items: TList<TCommerceEntitlementData>;
begin
  Items := TList<TCommerceEntitlementData>.Create;
  try
    for Pair in FEntitlements do
      if SameText(Pair.Value.UserId, AUserId) and SameText(Pair.Value.AppId, AAppId) then
        Items.Add(Pair.Value);
    Result := Items.ToArray;
  finally
    Items.Free;
  end;
end;

function TInMemoryCommerceStorage.FindEntitlement(const AUserId, AAppId,
  ACode: string; out AEntitlement: TCommerceEntitlementData): Boolean;
var
  Pair: TPair<string, TCommerceEntitlementData>;
begin
  Result := False;
  for Pair in FEntitlements do
  begin
    if SameText(Pair.Value.UserId, AUserId) and
       SameText(Pair.Value.AppId, AAppId) and
       SameText(Pair.Value.Code, ACode) then
    begin
      AEntitlement := Pair.Value;
      Exit(True);
    end;
  end;
end;

function TInMemoryCommerceStorage.ConsumeEntitlement(
  const AEntitlementId: string; ACount: Integer;
  out AEntitlement: TCommerceEntitlementData): Boolean;
begin
  Result := False;
  if ACount <= 0 then
    Exit;
  if not FEntitlements.TryGetValue(AEntitlementId, AEntitlement) then
    Exit;
  if AEntitlement.Status <> cesActive then
    Exit;
  if (AEntitlement.RemainingQuota >= 0) and
     (AEntitlement.RemainingQuota < ACount) then
    Exit;

  if AEntitlement.RemainingQuota >= 0 then
  begin
    Dec(AEntitlement.RemainingQuota, ACount);
    if AEntitlement.RemainingQuota = 0 then
      AEntitlement.Status := cesConsumed;
  end;

  FEntitlements.AddOrSetValue(AEntitlement.EntitlementId, AEntitlement);
  Result := True;
end;

end.
