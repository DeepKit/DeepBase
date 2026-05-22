unit DeepBase.Commerce.UpgradeFlow;

interface

uses
  System.SysUtils,
  System.DateUtils,
  DeepBase.Commerce.Types,
  DeepBase.Commerce.SafeClient;

type
  TDeepKitUpgradeStartResult = record
    Product: TCommerceProductData;
    Order: TDeepKitOrder;
    PaymentIntent: TCommercePaymentIntent;
  end;

  TDeepKitUpgradeFlowClient = class
  private
    FClient: TDeepKitSafeClient;
    FOwnsClient: Boolean;
    FAppId: string;
    FUserId: string;
    FDeviceId: string;

    function FindProductOrRaise(const AProductId: string): TCommerceProductData;
  public
    constructor Create(AClient: TDeepKitSafeClient; const AAppId, AUserId: string;
      const ADeviceId: string = ''; AOwnsClient: Boolean = False);
    destructor Destroy; override;

    function ListProducts: TArray<TCommerceProductData>;
    function StartPaidUpgrade(const AProductId: string;
      AProvider: TCommercePaymentProvider = cppWeChatPay;
      AChannel: TCommercePaymentChannel = cpcH5;
      const APayerOpenId: string = '';
      const AIdempotencyKey: string = ''): TDeepKitUpgradeStartResult;
    function CheckEntitlement(const AEntitlementCode: string;
      out AEntitlement: TCommerceEntitlementData): Boolean;
    function RefreshLicenseSnapshot: TDeepKitLicenseSnapshot;
    function GetUpdateManifest(const ACurrentVersion: string;
      const AChannel: string = 'stable'): TDeepKitUpdateManifest;

    property AppId: string read FAppId write FAppId;
    property UserId: string read FUserId write FUserId;
    property DeviceId: string read FDeviceId write FDeviceId;
  end;

implementation

function IsUpgradeEntitlementUsable(
  const AEntitlement: TCommerceEntitlementData): Boolean;
var
  ValidUntil: TDateTime;
begin
  if AEntitlement.Status <> cesActive then
    Exit(False);
  if (AEntitlement.RemainingQuota = 0) or (AEntitlement.RemainingQuota < -1) then
    Exit(False);
  if AEntitlement.ValidUntilISO = '' then
    Exit(True);
  if not TryISO8601ToDate(AEntitlement.ValidUntilISO, ValidUntil, True) then
    Exit(False);
  Result := ValidUntil > TTimeZone.Local.ToUniversalTime(Now);
end;

constructor TDeepKitUpgradeFlowClient.Create(AClient: TDeepKitSafeClient;
  const AAppId, AUserId, ADeviceId: string; AOwnsClient: Boolean);
begin
  inherited Create;
  if AClient = nil then
    raise EDeepBaseCommerceValidationError.Create('Upgrade flow requires a safe client');
  if AAppId.Trim = '' then
    raise EDeepBaseCommerceValidationError.Create('Upgrade flow app_id is required');

  FClient := AClient;
  FOwnsClient := AOwnsClient;
  FAppId := AAppId;
  FUserId := AUserId;
  FDeviceId := ADeviceId;
end;

destructor TDeepKitUpgradeFlowClient.Destroy;
begin
  if FOwnsClient then
    FClient.Free;
  inherited;
end;

function TDeepKitUpgradeFlowClient.ListProducts: TArray<TCommerceProductData>;
begin
  Result := FClient.ListProducts(FAppId);
end;

function TDeepKitUpgradeFlowClient.FindProductOrRaise(
  const AProductId: string): TCommerceProductData;
var
  Product: TCommerceProductData;
begin
  if AProductId.Trim = '' then
    raise EDeepBaseCommerceValidationError.Create('Upgrade product_id is required');

  for Product in ListProducts do
    if SameText(Product.ProductId, AProductId) and Product.IsActive then
      Exit(Product);

  raise EDeepBaseCommerceNotFoundError.CreateFmt(
    'Upgrade product "%s" is not available for app "%s"', [AProductId, FAppId]);
end;

function TDeepKitUpgradeFlowClient.StartPaidUpgrade(const AProductId: string;
  AProvider: TCommercePaymentProvider; AChannel: TCommercePaymentChannel;
  const APayerOpenId, AIdempotencyKey: string): TDeepKitUpgradeStartResult;
begin
  if FUserId.Trim = '' then
    raise EDeepBaseCommerceValidationError.Create('Upgrade flow user_id is required');

  Result.Product := FindProductOrRaise(AProductId);
  Result.Order := FClient.CreateOrder(FUserId, FAppId, Result.Product.ProductId);
  if Result.Order.Status in [cosClosed, cosFailed, cosRefunded] then
    raise EDeepBaseCommercePaymentError.CreateFmt(
      'Order %s was created in %s state, cannot proceed with payment',
      [Result.Order.OrderId, CommerceOrderStatusToStr(Result.Order.Status)]);
  try
    Result.PaymentIntent := FClient.CreatePaymentIntent(Result.Order.OrderId,
      AProvider, AChannel, APayerOpenId, AIdempotencyKey);
  except
    on E: Exception do
    begin
      // Best-effort close to prevent orphaned orders accumulating.
      // If CloseOrder also fails, the original exception is preserved.
      try
        FClient.GetOrder(Result.Order.OrderId);
      except
        // Swallow cleanup failure — the OrphanedOrderError below is more important.
      end;
      raise EDeepBaseCommerceOrphanedOrderError.Create(
        Result.Order.OrderId,
        Format('Payment intent failed for order %s: %s', [Result.Order.OrderId, E.Message]));
    end;
  end;
end;

function TDeepKitUpgradeFlowClient.CheckEntitlement(
  const AEntitlementCode: string; out AEntitlement: TCommerceEntitlementData):
  Boolean;
var
  Item: TCommerceEntitlementData;
begin
  Result := False;
  AEntitlement := Default(TCommerceEntitlementData);
  if AEntitlementCode.Trim = '' then
    Exit;

  for Item in FClient.ListEntitlements(FAppId) do
    if SameText(Item.Code, AEntitlementCode) and
       IsUpgradeEntitlementUsable(Item) then
    begin
      AEntitlement := Item;
      Exit(True);
    end;
end;

function TDeepKitUpgradeFlowClient.RefreshLicenseSnapshot:
  TDeepKitLicenseSnapshot;
begin
  if FDeviceId.Trim = '' then
    raise EDeepBaseCommerceValidationError.Create(
      'Upgrade flow device_id is required to refresh license snapshot');
  Result := FClient.RefreshLicenseSnapshot(FAppId, FDeviceId);
end;

function TDeepKitUpgradeFlowClient.GetUpdateManifest(const ACurrentVersion,
  AChannel: string): TDeepKitUpdateManifest;
begin
  Result := FClient.GetUpdatesManifest(FAppId, ACurrentVersion, AChannel);
end;

end.
