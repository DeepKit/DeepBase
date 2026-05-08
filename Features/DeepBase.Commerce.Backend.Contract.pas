unit DeepBase.Commerce.Backend.Contract;

interface

uses
  System.SysUtils,
  DeepBase.Commerce.Types;

const
  SCommerceRouteUsers = '/commerce/users';
  SCommerceRouteUsersEnsure = '/commerce/users/ensure';
  SCommerceRouteUsersByIdentity = '/commerce/users/by-identity';
  SCommerceRouteUserIdentities = '/commerce/users/identities';
  SCommerceRouteProducts = '/commerce/products';
  SCommerceRouteOrders = '/commerce/orders';
  SCommerceRouteOrdersByOutTradeNo = '/commerce/orders/by-out-trade-no';
  SCommerceRouteOrdersRefund = '/commerce/orders/refund';
  SCommerceRoutePayments = '/commerce/payments';
  SCommerceRoutePaymentsByOrder = '/commerce/payments/by-order';
  SCommerceRoutePaymentIntents = '/commerce/payments/intents';
  SCommerceRouteEntitlements = '/commerce/entitlements';
  SCommerceRouteEntitlementsByCode = '/commerce/entitlements/by-code';
  SCommerceRouteEntitlementsConsume = '/commerce/entitlements/consume';
  SCommerceRouteEntitlementsRevoke = '/commerce/entitlements/revoke';
  SCommerceRouteLicenseSnapshotRevoke = '/license/snapshot/revoke';

  SCommerceFieldProvider = 'provider';
  SCommerceFieldProviderUserId = 'provider_user_id';
  SCommerceFieldUnionId = 'union_id';
  SCommerceFieldUserId = 'user_id';
  SCommerceFieldDisplayName = 'display_name';
  SCommerceFieldEmail = 'email';
  SCommerceFieldPhone = 'phone';
  SCommerceFieldIsActive = 'is_active';
  SCommerceFieldAppId = 'app_id';
  SCommerceFieldProductId = 'product_id';
  SCommerceFieldName = 'name';
  SCommerceFieldDescription = 'description';
  SCommerceFieldEntitlementCode = 'entitlement_code';
  SCommerceFieldEntitlementDurationDays = 'entitlement_duration_days';
  SCommerceFieldInitialQuota = 'initial_quota';
  SCommerceFieldOrderId = 'order_id';
  SCommerceFieldOutTradeNo = 'out_trade_no';
  SCommerceFieldTitle = 'title';
  SCommerceFieldPaymentId = 'payment_id';
  SCommerceFieldProviderTradeNo = 'provider_trade_no';
  SCommerceFieldAmountMinor = 'amount_minor';
  SCommerceFieldCurrency = 'currency';
  SCommerceFieldStatus = 'status';
  SCommerceFieldChannel = 'channel';
  SCommerceFieldPayerOpenId = 'payer_open_id';
  SCommerceFieldPrepayId = 'prepay_id';
  SCommerceFieldClientParamsJson = 'client_params_json';
  SCommerceFieldPayUrl = 'pay_url';
  SCommerceFieldQrCodeData = 'qr_code_data';
  SCommerceFieldItems = 'items';
  SCommerceFieldCode = 'code';
  SCommerceFieldCount = 'count';
  SCommerceFieldReason = 'reason';
  SCommerceFieldEntitlementId = 'entitlement_id';
  SCommerceFieldRemainingQuota = 'remaining_quota';
  SCommerceFieldValidFrom = 'valid_from';
  SCommerceFieldValidUntil = 'valid_until';
  SCommerceFieldSourceOrderId = 'source_order_id';
  SCommerceFieldRawPayload = 'raw_payload';
  SCommerceFieldDeviceId = 'device_id';
  SCommerceFieldSnapshotId = 'snapshot_id';
  SCommerceFieldCreatedAt = 'created_at';
  SCommerceFieldUpdatedAt = 'updated_at';
  SCommerceFieldPaidAt = 'paid_at';
  SCommerceFieldSuccess = 'success';
  SCommerceFieldErrorCode = 'error_code';
  SCommerceFieldErrorMessage = 'error_message';

type
  TCommerceBackendRoutes = record
  public
    class function UserById(const AUserId: string): string; static;
    class function ProductById(const AAppId, AProductId: string): string; static;
    class function OrderById(const AOrderId: string): string; static;
    class function OrderByOutTradeNo(const AOutTradeNo: string): string; static;
    class function OrderRefund(const AOrderId: string): string; static;
    class function PaymentById(const APaymentId: string): string; static;
    class function PaymentByOrderId(const AOrderId: string): string; static;
    class function PaymentNotify(AProvider: TCommercePaymentProvider): string; static;
    class function EntitlementById(const AEntitlementId: string): string; static;
    class function EntitlementRevoke(const AEntitlementId: string): string; static;
  end;

implementation

uses
  System.NetEncoding;

function CommerceUrlPart(const AValue: string): string;
begin
  Result := TNetEncoding.URL.Encode(AValue);
end;

class function TCommerceBackendRoutes.UserById(const AUserId: string): string;
begin
  Result := SCommerceRouteUsers + '/' + CommerceUrlPart(AUserId);
end;

class function TCommerceBackendRoutes.ProductById(const AAppId,
  AProductId: string): string;
begin
  Result := SCommerceRouteProducts + '/' + CommerceUrlPart(AAppId) + '/' +
    CommerceUrlPart(AProductId);
end;

class function TCommerceBackendRoutes.OrderById(
  const AOrderId: string): string;
begin
  Result := SCommerceRouteOrders + '/' + CommerceUrlPart(AOrderId);
end;

class function TCommerceBackendRoutes.OrderByOutTradeNo(
  const AOutTradeNo: string): string;
begin
  Result := SCommerceRouteOrdersByOutTradeNo + '/' +
    CommerceUrlPart(AOutTradeNo);
end;

class function TCommerceBackendRoutes.OrderRefund(
  const AOrderId: string): string;
begin
  Result := SCommerceRouteOrders + '/' + CommerceUrlPart(AOrderId) +
    '/refund';
end;

class function TCommerceBackendRoutes.PaymentById(
  const APaymentId: string): string;
begin
  Result := SCommerceRoutePayments + '/' + CommerceUrlPart(APaymentId);
end;

class function TCommerceBackendRoutes.PaymentByOrderId(
  const AOrderId: string): string;
begin
  Result := SCommerceRoutePaymentsByOrder + '/' + CommerceUrlPart(AOrderId);
end;

class function TCommerceBackendRoutes.PaymentNotify(
  AProvider: TCommercePaymentProvider): string;
begin
  Result := Format('/commerce/payments/%s/notify',
    [CommercePaymentProviderToStr(AProvider)]);
end;

class function TCommerceBackendRoutes.EntitlementById(
  const AEntitlementId: string): string;
begin
  Result := SCommerceRouteEntitlements + '/' + CommerceUrlPart(AEntitlementId);
end;

class function TCommerceBackendRoutes.EntitlementRevoke(
  const AEntitlementId: string): string;
begin
  Result := SCommerceRouteEntitlements + '/' + CommerceUrlPart(AEntitlementId) +
    '/revoke';
end;

end.
