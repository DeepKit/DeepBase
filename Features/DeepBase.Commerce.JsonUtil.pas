unit DeepBase.Commerce.JsonUtil;

interface

uses
  System.SysUtils,
  System.JSON,
  System.Net.URLClient,
  DeepBase.Commerce.Types,
  DeepBase.Commerce.Backend.Contract;

// JSON value extraction
function JsonValueAsString(AJson: TJSONObject; const AName, ADefault: string): string;
function JsonValueAsInt(AJson: TJSONObject; const AName: string; ADefault: Integer): Integer;
function JsonValueAsInt64(AJson: TJSONObject; const AName: string; ADefault: Int64): Int64;
function JsonValueAsBool(AJson: TJSONObject; const AName: string; ADefault: Boolean): Boolean;
function ParseJsonObject(const ABody: string): TJSONObject;

// HTTP helpers
function IsHttpSuccess(AStatusCode: Integer): Boolean;
procedure AddHeader(var AHeaders: TNetHeaders; const AName, AValue: string);
function NormalizeRoutePrefix(const APrefix: string): string;
function RouteStartsWithPrefix(const APath, APrefix: string): Boolean;

// Enum serialization — not in Types to avoid System.JSON dependency in the core unit
function ChannelToString(AChannel: TCommercePaymentChannel): string;
function ChannelFromString(const AValue: string): TCommercePaymentChannel;
function AuthProviderFromString(const AValue: string): TCommerceAuthProvider;
function PaymentProviderFromString(const AValue: string): TCommercePaymentProvider;
function OrderStatusFromString(const AValue: string): TCommerceOrderStatus;
function PaymentStatusFromString(const AValue: string): TCommercePaymentStatus;
function EntitlementStatusToString(AStatus: TCommerceEntitlementStatus): string;
function EntitlementStatusFromString(const AValue: string): TCommerceEntitlementStatus;

// Record <-> JSON (shared between Backend.Http and SafeClient)
function UserFromJson(AJson: TJSONObject): TCommerceUserData;
function UserToJson(const AUser: TCommerceUserData): TJSONObject;
function IdentityToJson(const AIdentity: TCommerceIdentityData): TJSONObject;
function ProductFromJson(AJson: TJSONObject): TCommerceProductData;
function ProductToJson(const AProduct: TCommerceProductData): TJSONObject;
function OrderFromJson(AJson: TJSONObject): TCommerceOrderData;
function OrderToJson(const AOrder: TCommerceOrderData): TJSONObject;
function PaymentFromJson(AJson: TJSONObject): TCommercePaymentData;
function PaymentToJson(const APayment: TCommercePaymentData): TJSONObject;
function EntitlementFromJson(AJson: TJSONObject): TCommerceEntitlementData;
function EntitlementToJson(const AEntitlement: TCommerceEntitlementData): TJSONObject;
function PaymentIntentFromJson(AJson: TJSONObject;
  const ARawResponse: string): TCommercePaymentIntent;

implementation

{ JSON value extraction }

function JsonValueAsString(AJson: TJSONObject; const AName, ADefault: string): string;
var
  Value: TJSONValue;
begin
  Result := ADefault;
  if not Assigned(AJson) then
    Exit;
  Value := AJson.FindValue(AName);
  if Assigned(Value) and not (Value is TJSONNull) then
    Result := Value.Value;
end;

function JsonValueAsInt(AJson: TJSONObject; const AName: string;
  ADefault: Integer): Integer;
var
  Value: TJSONValue;
begin
  Result := ADefault;
  if not Assigned(AJson) then
    Exit;
  Value := AJson.FindValue(AName);
  if Value is TJSONNumber then
    Result := TJSONNumber(Value).AsInt
  else if Assigned(Value) and not (Value is TJSONNull) then
    Result := StrToIntDef(Value.Value, ADefault);
end;

function JsonValueAsInt64(AJson: TJSONObject; const AName: string;
  ADefault: Int64): Int64;
var
  Value: TJSONValue;
begin
  Result := ADefault;
  if not Assigned(AJson) then
    Exit;
  Value := AJson.FindValue(AName);
  if Value is TJSONNumber then
    Result := TJSONNumber(Value).AsInt64
  else if Assigned(Value) and not (Value is TJSONNull) then
    Result := StrToInt64Def(Value.Value, ADefault);
end;

function JsonValueAsBool(AJson: TJSONObject; const AName: string;
  ADefault: Boolean): Boolean;
var
  Value: TJSONValue;
  Text: string;
begin
  Result := ADefault;
  if not Assigned(AJson) then
    Exit;
  Value := AJson.FindValue(AName);
  if Value is TJSONBool then
    Result := TJSONBool(Value).AsBoolean
  else if Assigned(Value) and not (Value is TJSONNull) then
  begin
    Text := LowerCase(Value.Value);
    if (Text = 'true') or (Text = '1') then
      Result := True
    else if (Text = 'false') or (Text = '0') then
      Result := False;
  end;
end;

function ParseJsonObject(const ABody: string): TJSONObject;
var
  Value: TJSONValue;
begin
  if ABody = '' then
    Exit(TJSONObject.Create);

  Value := TJSONObject.ParseJSONValue(ABody);
  if not (Value is TJSONObject) then
  begin
    Value.Free;
    raise EDeepBaseCommerceError.Create('Commerce backend returned invalid JSON object');
  end;
  Result := TJSONObject(Value);
end;

{ HTTP helpers }

function IsHttpSuccess(AStatusCode: Integer): Boolean;
begin
  Result := (AStatusCode >= 200) and (AStatusCode < 300);
end;

procedure AddHeader(var AHeaders: TNetHeaders; const AName, AValue: string);
begin
  if AValue = '' then
    Exit;
  SetLength(AHeaders, Length(AHeaders) + 1);
  AHeaders[High(AHeaders)] := TNameValuePair.Create(AName, AValue);
end;

function NormalizeRoutePrefix(const APrefix: string): string;
begin
  Result := APrefix.Trim;
  if Result = '' then
    Exit('');

  if not Result.StartsWith('/') then
    Result := '/' + Result;

  while Result.EndsWith('/') and (Length(Result) > 1) do
    Delete(Result, Length(Result), 1);
end;

function RouteStartsWithPrefix(const APath, APrefix: string): Boolean;
begin
  if APrefix = '' then
    Exit(True);
  if Length(APath) < Length(APrefix) then
    Exit(False);
  if not AnsiSameStr(Copy(APath, 1, Length(APrefix)), APrefix) then
    Exit(False);
  if Length(APath) = Length(APrefix) then
    Exit(True);
  Result := APath[Length(APrefix) + 1] = '/';
end;

{ Enum serialization }

function ChannelToString(AChannel: TCommercePaymentChannel): string;
begin
  case AChannel of
    cpcNative: Result := 'native';
    cpcJSAPI: Result := 'jsapi';
    cpcMiniProgram: Result := 'mini_program';
    cpcH5: Result := 'h5';
    cpcApp: Result := 'app';
    cpcWeb: Result := 'web';
  else
    Result := 'manual';
  end;
end;

function ChannelFromString(const AValue: string): TCommercePaymentChannel;
begin
  if SameText(AValue, 'native') then
    Result := cpcNative
  else if SameText(AValue, 'jsapi') then
    Result := cpcJSAPI
  else if SameText(AValue, 'mini_program') then
    Result := cpcMiniProgram
  else if SameText(AValue, 'h5') then
    Result := cpcH5
  else if SameText(AValue, 'app') then
    Result := cpcApp
  else if SameText(AValue, 'web') then
    Result := cpcWeb
  else
    Result := cpcManual;
end;

function AuthProviderFromString(const AValue: string): TCommerceAuthProvider;
begin
  if SameText(AValue, 'guest') then
    Result := capGuest
  else if SameText(AValue, 'phone') then
    Result := capPhone
  else if SameText(AValue, 'email') then
    Result := capEmail
  else if SameText(AValue, 'wechat_mini_program') then
    Result := capWeChatMiniProgram
  else if SameText(AValue, 'wechat_official_account') then
    Result := capWeChatOfficialAccount
  else if SameText(AValue, 'wechat_open') then
    Result := capWeChatOpen
  else if SameText(AValue, 'device') then
    Result := capDevice
  else
    Result := capExternal;
end;

function PaymentProviderFromString(const AValue: string): TCommercePaymentProvider;
begin
  if SameText(AValue, 'wechat_pay') then
    Result := cppWeChatPay
  else if SameText(AValue, 'alipay') then
    Result := cppAlipay
  else if SameText(AValue, 'stripe') then
    Result := cppStripe
  else if SameText(AValue, 'paypal') then
    Result := cppPayPal
  else if SameText(AValue, 'manual') then
    Result := cppManual
  else
    Result := cppExternal;
end;

function OrderStatusFromString(const AValue: string): TCommerceOrderStatus;
begin
  if SameText(AValue, 'created') then
    Result := cosCreated
  else if SameText(AValue, 'paying') then
    Result := cosPaying
  else if SameText(AValue, 'paid') then
    Result := cosPaid
  else if SameText(AValue, 'closed') then
    Result := cosClosed
  else if SameText(AValue, 'failed') then
    Result := cosFailed
  else
    Result := cosRefunded;
end;

function PaymentStatusFromString(const AValue: string): TCommercePaymentStatus;
begin
  if SameText(AValue, 'created') then
    Result := cpsCreated
  else if SameText(AValue, 'pending') then
    Result := cpsPending
  else if SameText(AValue, 'paid') then
    Result := cpsPaid
  else if SameText(AValue, 'failed') then
    Result := cpsFailed
  else
    Result := cpsRefunded;
end;

function EntitlementStatusToString(AStatus: TCommerceEntitlementStatus): string;
begin
  case AStatus of
    cesActive: Result := 'active';
    cesConsumed: Result := 'consumed';
    cesExpired: Result := 'expired';
  else
    Result := 'revoked';
  end;
end;

function EntitlementStatusFromString(
  const AValue: string): TCommerceEntitlementStatus;
begin
  if SameText(AValue, 'active') then
    Result := cesActive
  else if SameText(AValue, 'consumed') then
    Result := cesConsumed
  else if SameText(AValue, 'expired') then
    Result := cesExpired
  else
    Result := cesRevoked;
end;

{ Record <-> JSON }

function UserFromJson(AJson: TJSONObject): TCommerceUserData;
begin
  Result.UserId := JsonValueAsString(AJson, SCommerceFieldUserId, '');
  Result.DisplayName := JsonValueAsString(AJson, SCommerceFieldDisplayName, '');
  Result.Email := JsonValueAsString(AJson, SCommerceFieldEmail, '');
  Result.Phone := JsonValueAsString(AJson, SCommerceFieldPhone, '');
  Result.IsActive := JsonValueAsBool(AJson, SCommerceFieldIsActive, True);
  Result.CreatedAtISO := JsonValueAsString(AJson, SCommerceFieldCreatedAt, '');
  Result.UpdatedAtISO := JsonValueAsString(AJson, SCommerceFieldUpdatedAt, '');
end;

function UserToJson(const AUser: TCommerceUserData): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair(SCommerceFieldUserId, AUser.UserId);
  Result.AddPair(SCommerceFieldDisplayName, AUser.DisplayName);
  Result.AddPair(SCommerceFieldEmail, AUser.Email);
  Result.AddPair(SCommerceFieldPhone, AUser.Phone);
  Result.AddPair(SCommerceFieldIsActive, TJSONBool.Create(AUser.IsActive));
  Result.AddPair(SCommerceFieldCreatedAt, AUser.CreatedAtISO);
  Result.AddPair(SCommerceFieldUpdatedAt, AUser.UpdatedAtISO);
end;

function IdentityToJson(const AIdentity: TCommerceIdentityData): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair(SCommerceFieldUserId, AIdentity.UserId);
  Result.AddPair(SCommerceFieldProvider,
    CommerceAuthProviderToStr(AIdentity.Provider));
  Result.AddPair(SCommerceFieldProviderUserId, AIdentity.ProviderUserId);
  Result.AddPair(SCommerceFieldAppId, AIdentity.AppId);
  Result.AddPair(SCommerceFieldUnionId, AIdentity.UnionId);
  Result.AddPair(SCommerceFieldCreatedAt, AIdentity.CreatedAtISO);
end;

function ProductFromJson(AJson: TJSONObject): TCommerceProductData;
begin
  Result.ProductId := JsonValueAsString(AJson, SCommerceFieldProductId, '');
  Result.AppId := JsonValueAsString(AJson, SCommerceFieldAppId, '');
  Result.Name := JsonValueAsString(AJson, SCommerceFieldName, '');
  Result.Description := JsonValueAsString(AJson, SCommerceFieldDescription, '');
  Result.AmountMinor := JsonValueAsInt64(AJson, SCommerceFieldAmountMinor, 0);
  Result.Currency := JsonValueAsString(AJson, SCommerceFieldCurrency, '');
  Result.EntitlementCode := JsonValueAsString(AJson,
    SCommerceFieldEntitlementCode, '');
  Result.EntitlementDurationDays := JsonValueAsInt(AJson,
    SCommerceFieldEntitlementDurationDays, 0);
  Result.InitialQuota := JsonValueAsInt(AJson, SCommerceFieldInitialQuota, -1);
  Result.IsActive := JsonValueAsBool(AJson, SCommerceFieldIsActive, True);
end;

function ProductToJson(const AProduct: TCommerceProductData): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair(SCommerceFieldProductId, AProduct.ProductId);
  Result.AddPair(SCommerceFieldAppId, AProduct.AppId);
  Result.AddPair(SCommerceFieldName, AProduct.Name);
  Result.AddPair(SCommerceFieldDescription, AProduct.Description);
  Result.AddPair(SCommerceFieldAmountMinor,
    TJSONNumber.Create(AProduct.AmountMinor));
  Result.AddPair(SCommerceFieldCurrency, AProduct.Currency);
  Result.AddPair(SCommerceFieldEntitlementCode, AProduct.EntitlementCode);
  Result.AddPair(SCommerceFieldEntitlementDurationDays,
    TJSONNumber.Create(AProduct.EntitlementDurationDays));
  Result.AddPair(SCommerceFieldInitialQuota,
    TJSONNumber.Create(AProduct.InitialQuota));
  Result.AddPair(SCommerceFieldIsActive, TJSONBool.Create(AProduct.IsActive));
end;

function OrderFromJson(AJson: TJSONObject): TCommerceOrderData;
begin
  Result.OrderId := JsonValueAsString(AJson, SCommerceFieldOrderId, '');
  Result.UserId := JsonValueAsString(AJson, SCommerceFieldUserId, '');
  Result.AppId := JsonValueAsString(AJson, SCommerceFieldAppId, '');
  Result.ProductId := JsonValueAsString(AJson, SCommerceFieldProductId, '');
  Result.OutTradeNo := JsonValueAsString(AJson, SCommerceFieldOutTradeNo, '');
  Result.Title := JsonValueAsString(AJson, SCommerceFieldTitle, '');
  Result.AmountMinor := JsonValueAsInt64(AJson, SCommerceFieldAmountMinor, 0);
  Result.Currency := JsonValueAsString(AJson, SCommerceFieldCurrency, '');
  Result.Status := OrderStatusFromString(JsonValueAsString(AJson,
    SCommerceFieldStatus, 'created'));
  Result.CreatedAtISO := JsonValueAsString(AJson, SCommerceFieldCreatedAt, '');
  Result.PaidAtISO := JsonValueAsString(AJson, SCommerceFieldPaidAt, '');
end;

function OrderToJson(const AOrder: TCommerceOrderData): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair(SCommerceFieldOrderId, AOrder.OrderId);
  Result.AddPair(SCommerceFieldUserId, AOrder.UserId);
  Result.AddPair(SCommerceFieldAppId, AOrder.AppId);
  Result.AddPair(SCommerceFieldProductId, AOrder.ProductId);
  Result.AddPair(SCommerceFieldOutTradeNo, AOrder.OutTradeNo);
  Result.AddPair(SCommerceFieldTitle, AOrder.Title);
  Result.AddPair(SCommerceFieldAmountMinor,
    TJSONNumber.Create(AOrder.AmountMinor));
  Result.AddPair(SCommerceFieldCurrency, AOrder.Currency);
  Result.AddPair(SCommerceFieldStatus, CommerceOrderStatusToStr(AOrder.Status));
  Result.AddPair(SCommerceFieldCreatedAt, AOrder.CreatedAtISO);
  Result.AddPair(SCommerceFieldPaidAt, AOrder.PaidAtISO);
end;

function PaymentFromJson(AJson: TJSONObject): TCommercePaymentData;
begin
  Result.PaymentId := JsonValueAsString(AJson, SCommerceFieldPaymentId, '');
  Result.OrderId := JsonValueAsString(AJson, SCommerceFieldOrderId, '');
  Result.Provider := PaymentProviderFromString(JsonValueAsString(AJson,
    SCommerceFieldProvider, 'external'));
  Result.Channel := ChannelFromString(JsonValueAsString(AJson,
    SCommerceFieldChannel, 'manual'));
  Result.ProviderTradeNo := JsonValueAsString(AJson,
    SCommerceFieldProviderTradeNo, '');
  Result.PrepayId := JsonValueAsString(AJson, SCommerceFieldPrepayId, '');
  Result.Status := PaymentStatusFromString(JsonValueAsString(AJson,
    SCommerceFieldStatus, 'created'));
  Result.RawPayload := JsonValueAsString(AJson, SCommerceFieldRawPayload, '');
  Result.CreatedAtISO := JsonValueAsString(AJson, SCommerceFieldCreatedAt, '');
  Result.PaidAtISO := JsonValueAsString(AJson, SCommerceFieldPaidAt, '');
end;

function PaymentToJson(const APayment: TCommercePaymentData): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair(SCommerceFieldPaymentId, APayment.PaymentId);
  Result.AddPair(SCommerceFieldOrderId, APayment.OrderId);
  Result.AddPair(SCommerceFieldProvider,
    CommercePaymentProviderToStr(APayment.Provider));
  Result.AddPair(SCommerceFieldChannel, ChannelToString(APayment.Channel));
  Result.AddPair(SCommerceFieldProviderTradeNo, APayment.ProviderTradeNo);
  Result.AddPair(SCommerceFieldPrepayId, APayment.PrepayId);
  Result.AddPair(SCommerceFieldStatus,
    CommercePaymentStatusToStr(APayment.Status));
  Result.AddPair(SCommerceFieldRawPayload, APayment.RawPayload);
  Result.AddPair(SCommerceFieldCreatedAt, APayment.CreatedAtISO);
  Result.AddPair(SCommerceFieldPaidAt, APayment.PaidAtISO);
end;

function EntitlementFromJson(AJson: TJSONObject): TCommerceEntitlementData;
begin
  Result.EntitlementId := JsonValueAsString(AJson,
    SCommerceFieldEntitlementId, '');
  Result.UserId := JsonValueAsString(AJson, SCommerceFieldUserId, '');
  Result.AppId := JsonValueAsString(AJson, SCommerceFieldAppId, '');
  Result.ProductId := JsonValueAsString(AJson, SCommerceFieldProductId, '');
  Result.Code := JsonValueAsString(AJson, SCommerceFieldCode, '');
  Result.Status := EntitlementStatusFromString(JsonValueAsString(AJson,
    SCommerceFieldStatus, 'active'));
  Result.ValidFromISO := JsonValueAsString(AJson, SCommerceFieldValidFrom, '');
  Result.ValidUntilISO := JsonValueAsString(AJson, SCommerceFieldValidUntil, '');
  Result.RemainingQuota := JsonValueAsInt(AJson,
    SCommerceFieldRemainingQuota, -1);
  Result.SourceOrderId := JsonValueAsString(AJson,
    SCommerceFieldSourceOrderId, '');
end;

function EntitlementToJson(const AEntitlement: TCommerceEntitlementData): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair(SCommerceFieldEntitlementId, AEntitlement.EntitlementId);
  Result.AddPair(SCommerceFieldUserId, AEntitlement.UserId);
  Result.AddPair(SCommerceFieldAppId, AEntitlement.AppId);
  Result.AddPair(SCommerceFieldProductId, AEntitlement.ProductId);
  Result.AddPair(SCommerceFieldCode, AEntitlement.Code);
  Result.AddPair(SCommerceFieldStatus,
    EntitlementStatusToString(AEntitlement.Status));
  Result.AddPair(SCommerceFieldValidFrom, AEntitlement.ValidFromISO);
  Result.AddPair(SCommerceFieldValidUntil, AEntitlement.ValidUntilISO);
  Result.AddPair(SCommerceFieldRemainingQuota,
    TJSONNumber.Create(AEntitlement.RemainingQuota));
  Result.AddPair(SCommerceFieldSourceOrderId, AEntitlement.SourceOrderId);
end;

function PaymentIntentFromJson(AJson: TJSONObject;
  const ARawResponse: string): TCommercePaymentIntent;
begin
  Result.Success := JsonValueAsBool(AJson, SCommerceFieldSuccess, True);
  Result.PaymentId := JsonValueAsString(AJson, SCommerceFieldPaymentId, '');
  Result.OutTradeNo := JsonValueAsString(AJson, SCommerceFieldOutTradeNo, '');
  Result.PrepayId := JsonValueAsString(AJson, SCommerceFieldPrepayId, '');
  Result.PayUrl := JsonValueAsString(AJson, SCommerceFieldPayUrl, '');
  Result.QRCodeData := JsonValueAsString(AJson, SCommerceFieldQrCodeData, '');
  Result.ClientParamsJson := JsonValueAsString(AJson,
    SCommerceFieldClientParamsJson, '');
  Result.RawResponse := ARawResponse;
  Result.ErrorCode := JsonValueAsString(AJson, SCommerceFieldErrorCode, '');
  Result.ErrorMessage := JsonValueAsString(AJson,
    SCommerceFieldErrorMessage, '');
end;

end.
