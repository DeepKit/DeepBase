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
    FLock: TObject;
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
  FLock := TObject.Create;
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
  FreeAndNil(FLock);
  inherited;
end;

function TInMemoryCommerceStorage.IdentityKey(AProvider: TCommerceAuthProvider;
  const AProviderUserId, AAppId: string): string;
var
  NormalizedId: string;
begin
  case AProvider of
    capEmail, capPhone: NormalizedId := LowerCase(AProviderUserId);
  else
    NormalizedId := AProviderUserId;
  end;
  Result := IntToStr(Ord(AProvider)) + '|' + LowerCase(AAppId) + '|' + NormalizedId;
end;

function TInMemoryCommerceStorage.ProductKey(const AAppId,
  AProductId: string): string;
begin
  Result := LowerCase(AAppId) + '|' + LowerCase(AProductId);
end;

function TInMemoryCommerceStorage.FindUserById(const AUserId: string;
  out AUser: TCommerceUserData): Boolean;
begin
  TMonitor.Enter(FLock);
  try
    Result := FUsers.TryGetValue(AUserId, AUser);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TInMemoryCommerceStorage.FindUserByIdentity(
  AProvider: TCommerceAuthProvider; const AProviderUserId, AAppId: string;
  out AUser: TCommerceUserData): Boolean;
var
  UserId: string;
begin
  TMonitor.Enter(FLock);
  try
    Result := FIdentityToUser.TryGetValue(
      IdentityKey(AProvider, AProviderUserId, AAppId), UserId) and
      FUsers.TryGetValue(UserId, AUser);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TInMemoryCommerceStorage.UpsertUser(const AUser: TCommerceUserData);
begin
  TMonitor.Enter(FLock);
  try
    FUsers.AddOrSetValue(AUser.UserId, AUser);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TInMemoryCommerceStorage.LinkIdentity(
  const AIdentity: TCommerceIdentityData);
begin
  TMonitor.Enter(FLock);
  try
    FIdentityToUser.AddOrSetValue(
      IdentityKey(AIdentity.Provider, AIdentity.ProviderUserId, AIdentity.AppId),
      AIdentity.UserId);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TInMemoryCommerceStorage.FindProduct(const AAppId,
  AProductId: string; out AProduct: TCommerceProductData): Boolean;
begin
  TMonitor.Enter(FLock);
  try
    Result := FProducts.TryGetValue(ProductKey(AAppId, AProductId), AProduct);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TInMemoryCommerceStorage.UpsertProduct(
  const AProduct: TCommerceProductData);
begin
  TMonitor.Enter(FLock);
  try
    FProducts.AddOrSetValue(ProductKey(AProduct.AppId, AProduct.ProductId), AProduct);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TInMemoryCommerceStorage.CreateOrder(const AOrder: TCommerceOrderData);
begin
  TMonitor.Enter(FLock);
  try
    FOrders.Add(AOrder.OrderId, AOrder);
    FOutTradeNoToOrder.Add(AOrder.OutTradeNo, AOrder.OrderId);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TInMemoryCommerceStorage.FindOrderById(const AOrderId: string;
  out AOrder: TCommerceOrderData): Boolean;
begin
  TMonitor.Enter(FLock);
  try
    Result := FOrders.TryGetValue(AOrderId, AOrder);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TInMemoryCommerceStorage.FindOrderByOutTradeNo(
  const AOutTradeNo: string; out AOrder: TCommerceOrderData): Boolean;
var
  OrderId: string;
begin
  TMonitor.Enter(FLock);
  try
    Result := FOutTradeNoToOrder.TryGetValue(AOutTradeNo, OrderId) and
      FOrders.TryGetValue(OrderId, AOrder);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TInMemoryCommerceStorage.UpdateOrder(const AOrder: TCommerceOrderData);
begin
  TMonitor.Enter(FLock);
  try
    FOrders.AddOrSetValue(AOrder.OrderId, AOrder);
    FOutTradeNoToOrder.AddOrSetValue(AOrder.OutTradeNo, AOrder.OrderId);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TInMemoryCommerceStorage.CreatePayment(
  const APayment: TCommercePaymentData);
begin
  TMonitor.Enter(FLock);
  try
    FPayments.Add(APayment.PaymentId, APayment);
    FOrderToPayment.AddOrSetValue(APayment.OrderId, APayment.PaymentId);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TInMemoryCommerceStorage.FindPaymentByOrderId(
  const AOrderId: string; out APayment: TCommercePaymentData): Boolean;
var
  PaymentId: string;
begin
  TMonitor.Enter(FLock);
  try
    Result := FOrderToPayment.TryGetValue(AOrderId, PaymentId) and
      FPayments.TryGetValue(PaymentId, APayment);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TInMemoryCommerceStorage.UpdatePayment(
  const APayment: TCommercePaymentData);
begin
  TMonitor.Enter(FLock);
  try
    FPayments.AddOrSetValue(APayment.PaymentId, APayment);
    FOrderToPayment.AddOrSetValue(APayment.OrderId, APayment.PaymentId);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TInMemoryCommerceStorage.UpsertEntitlement(
  const AEntitlement: TCommerceEntitlementData);
begin
  TMonitor.Enter(FLock);
  try
    FEntitlements.AddOrSetValue(AEntitlement.EntitlementId, AEntitlement);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TInMemoryCommerceStorage.ListEntitlements(const AUserId,
  AAppId: string): TCommerceEntitlementArray;
var
  Pair: TPair<string, TCommerceEntitlementData>;
  Items: TList<TCommerceEntitlementData>;
begin
  Items := TList<TCommerceEntitlementData>.Create;
  try
    TMonitor.Enter(FLock);
    try
      for Pair in FEntitlements do
        if SameText(Pair.Value.UserId, AUserId) and SameText(Pair.Value.AppId, AAppId) then
          Items.Add(Pair.Value);
    finally
      TMonitor.Exit(FLock);
    end;
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
  TMonitor.Enter(FLock);
  try
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
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TInMemoryCommerceStorage.ConsumeEntitlement(
  const AEntitlementId: string; ACount: Integer;
  out AEntitlement: TCommerceEntitlementData): Boolean;
begin
  Result := False;
  if ACount <= 0 then
    Exit;
  TMonitor.Enter(FLock);
  try
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
    // RemainingQuota = -1 means unlimited quota: no decrement needed

    FEntitlements.AddOrSetValue(AEntitlement.EntitlementId, AEntitlement);
    Result := True;
  finally
    TMonitor.Exit(FLock);
  end;
end;

end.
