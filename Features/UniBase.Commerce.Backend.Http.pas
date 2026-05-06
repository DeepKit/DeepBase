unit UniBase.Commerce.Backend.Http;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Net.HttpClient,
  System.Net.URLClient,
  UniBase.Commerce.Types,
  UniBase.Commerce.Storage,
  UniBase.Commerce.Service,
  UniBase.Commerce.Backend.Contract;

type
  TCommerceBackendHttpConfig = record
    BaseUrl: string;
    BearerToken: string;
    ApiKey: string;
    TimeoutMs: Integer;
    class function Create(const ABaseUrl: string;
      const ABearerToken: string = ''; const AApiKey: string = '';
      ATimeoutMs: Integer = 30000): TCommerceBackendHttpConfig; static;
  end;

  TCommerceBackendHttpResponse = record
    StatusCode: Integer;
    Body: string;
    class function Create(AStatusCode: Integer;
      const ABody: string): TCommerceBackendHttpResponse; static;
  end;

  ICommerceBackendHttpTransport = interface
    ['{F42681A2-74BD-47C8-89F9-1B910D3D5C6E}']
    function Send(const AMethod, AUrl, ABody: string;
      const AHeaders: TNetHeaders): TCommerceBackendHttpResponse;
  end;

  TCommerceBackendHttpClientTransport = class(TInterfacedObject,
    ICommerceBackendHttpTransport)
  private
    FHttpClient: THTTPClient;
  public
    constructor Create(ATimeoutMs: Integer = 30000);
    destructor Destroy; override;
    function Send(const AMethod, AUrl, ABody: string;
      const AHeaders: TNetHeaders): TCommerceBackendHttpResponse;
  end;

  TCommerceHttpStorage = class(TInterfacedObject, ICommerceStorage)
  private
    FConfig: TCommerceBackendHttpConfig;
    FTransport: ICommerceBackendHttpTransport;

    function BuildUrl(const APath: string): string;
    function BuildQuery(const APairs: array of string): string;
    function BuildHeaders: TNetHeaders;
    function SendJson(const AMethod, APath: string;
      ABody: TJSONObject = nil): TCommerceBackendHttpResponse;
    procedure EnsureSuccess(const AMethod, APath: string;
      const AResponse: TCommerceBackendHttpResponse);
    function JsonFromResponse(const AMethod, APath: string;
      const AResponse: TCommerceBackendHttpResponse): TJSONObject;
  public
    constructor Create(const AConfig: TCommerceBackendHttpConfig;
      const ATransport: ICommerceBackendHttpTransport = nil);

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

  TCommerceHttpPaymentGateway = class(TInterfacedObject, ICommercePaymentGateway)
  private
    FConfig: TCommerceBackendHttpConfig;
    FTransport: ICommerceBackendHttpTransport;

    function BuildUrl(const APath: string): string;
    function BuildHeaders(const AIdempotencyKey: string): TNetHeaders;
    function SendJson(const AMethod, APath: string; ABody: TJSONObject;
      const AIdempotencyKey: string = ''): TCommerceBackendHttpResponse;
  public
    constructor Create(const AConfig: TCommerceBackendHttpConfig;
      const ATransport: ICommerceBackendHttpTransport = nil);
    function CreatePaymentIntent(const AOrder: TCommerceOrderData;
      const APayment: TCommercePaymentData;
      const APayerOpenId: string): TCommercePaymentIntent;
  end;

implementation

uses
  System.NetEncoding;

const
  SHttpGet = 'GET';
  SHttpPost = 'POST';
  SHttpPut = 'PUT';
  SHttpDelete = 'DELETE';

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

function JsonValueAsString(AJson: TJSONObject; const AName,
  ADefault: string): string;
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
    raise EUniBaseCommerceError.Create('Commerce backend returned invalid JSON object');
  end;
  Result := TJSONObject(Value);
end;

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

function EntitlementToJson(
  const AEntitlement: TCommerceEntitlementData): TJSONObject;
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

{ TCommerceBackendHttpConfig }

class function TCommerceBackendHttpConfig.Create(const ABaseUrl, ABearerToken,
  AApiKey: string; ATimeoutMs: Integer): TCommerceBackendHttpConfig;
begin
  Result.BaseUrl := ABaseUrl;
  Result.BearerToken := ABearerToken;
  Result.ApiKey := AApiKey;
  Result.TimeoutMs := ATimeoutMs;
end;

{ TCommerceBackendHttpResponse }

class function TCommerceBackendHttpResponse.Create(AStatusCode: Integer;
  const ABody: string): TCommerceBackendHttpResponse;
begin
  Result.StatusCode := AStatusCode;
  Result.Body := ABody;
end;

{ TCommerceBackendHttpClientTransport }

constructor TCommerceBackendHttpClientTransport.Create(ATimeoutMs: Integer);
begin
  inherited Create;
  if ATimeoutMs <= 0 then
    ATimeoutMs := 30000;
  FHttpClient := THTTPClient.Create;
  FHttpClient.ConnectionTimeout := ATimeoutMs;
  FHttpClient.ResponseTimeout := ATimeoutMs;
  FHttpClient.ContentType := 'application/json';
end;

destructor TCommerceBackendHttpClientTransport.Destroy;
begin
  FreeAndNil(FHttpClient);
  inherited;
end;

function TCommerceBackendHttpClientTransport.Send(const AMethod, AUrl,
  ABody: string; const AHeaders: TNetHeaders): TCommerceBackendHttpResponse;
var
  Response: IHTTPResponse;
  Stream: TStringStream;
begin
  if SameText(AMethod, SHttpGet) then
    Response := FHttpClient.Get(AUrl, nil, AHeaders)
  else if SameText(AMethod, SHttpPost) then
  begin
    Stream := TStringStream.Create(ABody, TEncoding.UTF8);
    try
      Response := FHttpClient.Post(AUrl, Stream, nil, AHeaders);
    finally
      Stream.Free;
    end;
  end
  else if SameText(AMethod, SHttpPut) then
  begin
    Stream := TStringStream.Create(ABody, TEncoding.UTF8);
    try
      Response := FHttpClient.Put(AUrl, Stream, nil, AHeaders);
    finally
      Stream.Free;
    end;
  end
  else if SameText(AMethod, SHttpDelete) then
    Response := FHttpClient.Delete(AUrl, nil, AHeaders)
  else
    raise EUniBaseCommerceError.CreateFmt('Unsupported HTTP method: %s',
      [AMethod]);

  Result.StatusCode := Response.StatusCode;
  Result.Body := Response.ContentAsString(TEncoding.UTF8);
end;

{ TCommerceHttpStorage }

constructor TCommerceHttpStorage.Create(
  const AConfig: TCommerceBackendHttpConfig;
  const ATransport: ICommerceBackendHttpTransport);
begin
  inherited Create;
  if AConfig.BaseUrl.Trim = '' then
    raise EUniBaseCommerceValidationError.Create(
      'Commerce backend BaseUrl is required');

  FConfig := AConfig;
  FTransport := ATransport;
  if not Assigned(FTransport) then
    FTransport := TCommerceBackendHttpClientTransport.Create(AConfig.TimeoutMs);
end;

function TCommerceHttpStorage.BuildUrl(const APath: string): string;
var
  Base: string;
begin
  Base := FConfig.BaseUrl.Trim;
  while Base.EndsWith('/') do
    Delete(Base, Length(Base), 1);
  if APath.StartsWith('/') then
    Result := Base + APath
  else
    Result := Base + '/' + APath;
end;

function TCommerceHttpStorage.BuildQuery(
  const APairs: array of string): string;
var
  I: Integer;
begin
  Result := '';
  I := 0;
  while I < Length(APairs) - 1 do
  begin
    if APairs[I] <> '' then
    begin
      if Result = '' then
        Result := '?'
      else
        Result := Result + '&';
      Result := Result + TNetEncoding.URL.Encode(APairs[I]) + '=' +
        TNetEncoding.URL.Encode(APairs[I + 1]);
    end;
    Inc(I, 2);
  end;
end;

function TCommerceHttpStorage.BuildHeaders: TNetHeaders;
begin
  SetLength(Result, 0);
  AddHeader(Result, 'Accept', 'application/json');
  AddHeader(Result, 'Content-Type', 'application/json');
  if FConfig.BearerToken <> '' then
    AddHeader(Result, 'Authorization', 'Bearer ' + FConfig.BearerToken);
  if FConfig.ApiKey <> '' then
    AddHeader(Result, 'X-API-Key', FConfig.ApiKey);
end;

function TCommerceHttpStorage.SendJson(const AMethod, APath: string;
  ABody: TJSONObject): TCommerceBackendHttpResponse;
var
  BodyText: string;
begin
  if Assigned(ABody) then
    BodyText := ABody.ToJSON
  else
    BodyText := '';
  Result := FTransport.Send(AMethod, BuildUrl(APath), BodyText, BuildHeaders);
end;

procedure TCommerceHttpStorage.EnsureSuccess(const AMethod, APath: string;
  const AResponse: TCommerceBackendHttpResponse);
begin
  if not IsHttpSuccess(AResponse.StatusCode) then
    raise EUniBaseCommerceError.CreateFmt('Commerce backend HTTP %d for %s %s: %s',
      [AResponse.StatusCode, AMethod, APath, Copy(AResponse.Body, 1, 300)]);
end;

function TCommerceHttpStorage.JsonFromResponse(const AMethod, APath: string;
  const AResponse: TCommerceBackendHttpResponse): TJSONObject;
begin
  EnsureSuccess(AMethod, APath, AResponse);
  Result := ParseJsonObject(AResponse.Body);
end;

function TCommerceHttpStorage.FindUserById(const AUserId: string;
  out AUser: TCommerceUserData): Boolean;
var
  Path: string;
  Response: TCommerceBackendHttpResponse;
  Json: TJSONObject;
begin
  Path := TCommerceBackendRoutes.UserById(AUserId);
  Response := SendJson(SHttpGet, Path);
  if Response.StatusCode = 404 then
    Exit(False);
  Json := JsonFromResponse(SHttpGet, Path, Response);
  try
    AUser := UserFromJson(Json);
    Result := AUser.UserId <> '';
  finally
    Json.Free;
  end;
end;

function TCommerceHttpStorage.FindUserByIdentity(
  AProvider: TCommerceAuthProvider; const AProviderUserId, AAppId: string;
  out AUser: TCommerceUserData): Boolean;
var
  Path: string;
  Response: TCommerceBackendHttpResponse;
  Json: TJSONObject;
begin
  Path := SCommerceRouteUsersByIdentity + BuildQuery([
    SCommerceFieldProvider, CommerceAuthProviderToStr(AProvider),
    SCommerceFieldProviderUserId, AProviderUserId,
    SCommerceFieldAppId, AAppId]);
  Response := SendJson(SHttpGet, Path);
  if Response.StatusCode = 404 then
    Exit(False);
  Json := JsonFromResponse(SHttpGet, Path, Response);
  try
    AUser := UserFromJson(Json);
    Result := AUser.UserId <> '';
  finally
    Json.Free;
  end;
end;

procedure TCommerceHttpStorage.UpsertUser(const AUser: TCommerceUserData);
var
  Json: TJSONObject;
  Path: string;
begin
  Path := TCommerceBackendRoutes.UserById(AUser.UserId);
  Json := UserToJson(AUser);
  try
    EnsureSuccess(SHttpPut, Path, SendJson(SHttpPut, Path, Json));
  finally
    Json.Free;
  end;
end;

procedure TCommerceHttpStorage.LinkIdentity(
  const AIdentity: TCommerceIdentityData);
var
  Json: TJSONObject;
begin
  Json := IdentityToJson(AIdentity);
  try
    EnsureSuccess(SHttpPost, SCommerceRouteUserIdentities,
      SendJson(SHttpPost, SCommerceRouteUserIdentities, Json));
  finally
    Json.Free;
  end;
end;

function TCommerceHttpStorage.FindProduct(const AAppId, AProductId: string;
  out AProduct: TCommerceProductData): Boolean;
var
  Path: string;
  Response: TCommerceBackendHttpResponse;
  Json: TJSONObject;
begin
  Path := TCommerceBackendRoutes.ProductById(AAppId, AProductId);
  Response := SendJson(SHttpGet, Path);
  if Response.StatusCode = 404 then
    Exit(False);
  Json := JsonFromResponse(SHttpGet, Path, Response);
  try
    AProduct := ProductFromJson(Json);
    Result := AProduct.ProductId <> '';
  finally
    Json.Free;
  end;
end;

procedure TCommerceHttpStorage.UpsertProduct(
  const AProduct: TCommerceProductData);
var
  Json: TJSONObject;
  Path: string;
begin
  Path := TCommerceBackendRoutes.ProductById(AProduct.AppId, AProduct.ProductId);
  Json := ProductToJson(AProduct);
  try
    EnsureSuccess(SHttpPut, Path, SendJson(SHttpPut, Path, Json));
  finally
    Json.Free;
  end;
end;

procedure TCommerceHttpStorage.CreateOrder(const AOrder: TCommerceOrderData);
var
  Json: TJSONObject;
begin
  Json := OrderToJson(AOrder);
  try
    EnsureSuccess(SHttpPost, SCommerceRouteOrders,
      SendJson(SHttpPost, SCommerceRouteOrders, Json));
  finally
    Json.Free;
  end;
end;

function TCommerceHttpStorage.FindOrderById(const AOrderId: string;
  out AOrder: TCommerceOrderData): Boolean;
var
  Path: string;
  Response: TCommerceBackendHttpResponse;
  Json: TJSONObject;
begin
  Path := TCommerceBackendRoutes.OrderById(AOrderId);
  Response := SendJson(SHttpGet, Path);
  if Response.StatusCode = 404 then
    Exit(False);
  Json := JsonFromResponse(SHttpGet, Path, Response);
  try
    AOrder := OrderFromJson(Json);
    Result := AOrder.OrderId <> '';
  finally
    Json.Free;
  end;
end;

function TCommerceHttpStorage.FindOrderByOutTradeNo(
  const AOutTradeNo: string; out AOrder: TCommerceOrderData): Boolean;
var
  Path: string;
  Response: TCommerceBackendHttpResponse;
  Json: TJSONObject;
begin
  Path := TCommerceBackendRoutes.OrderByOutTradeNo(AOutTradeNo);
  Response := SendJson(SHttpGet, Path);
  if Response.StatusCode = 404 then
    Exit(False);
  Json := JsonFromResponse(SHttpGet, Path, Response);
  try
    AOrder := OrderFromJson(Json);
    Result := AOrder.OrderId <> '';
  finally
    Json.Free;
  end;
end;

procedure TCommerceHttpStorage.UpdateOrder(const AOrder: TCommerceOrderData);
var
  Json: TJSONObject;
  Path: string;
begin
  Path := TCommerceBackendRoutes.OrderById(AOrder.OrderId);
  Json := OrderToJson(AOrder);
  try
    EnsureSuccess(SHttpPut, Path, SendJson(SHttpPut, Path, Json));
  finally
    Json.Free;
  end;
end;

procedure TCommerceHttpStorage.CreatePayment(
  const APayment: TCommercePaymentData);
var
  Json: TJSONObject;
begin
  Json := PaymentToJson(APayment);
  try
    EnsureSuccess(SHttpPost, SCommerceRoutePayments,
      SendJson(SHttpPost, SCommerceRoutePayments, Json));
  finally
    Json.Free;
  end;
end;

function TCommerceHttpStorage.FindPaymentByOrderId(const AOrderId: string;
  out APayment: TCommercePaymentData): Boolean;
var
  Path: string;
  Response: TCommerceBackendHttpResponse;
  Json: TJSONObject;
begin
  Path := TCommerceBackendRoutes.PaymentByOrderId(AOrderId);
  Response := SendJson(SHttpGet, Path);
  if Response.StatusCode = 404 then
    Exit(False);
  Json := JsonFromResponse(SHttpGet, Path, Response);
  try
    APayment := PaymentFromJson(Json);
    Result := APayment.PaymentId <> '';
  finally
    Json.Free;
  end;
end;

procedure TCommerceHttpStorage.UpdatePayment(
  const APayment: TCommercePaymentData);
var
  Json: TJSONObject;
  Path: string;
begin
  Path := TCommerceBackendRoutes.PaymentById(APayment.PaymentId);
  Json := PaymentToJson(APayment);
  try
    EnsureSuccess(SHttpPut, Path, SendJson(SHttpPut, Path, Json));
  finally
    Json.Free;
  end;
end;

procedure TCommerceHttpStorage.UpsertEntitlement(
  const AEntitlement: TCommerceEntitlementData);
var
  Json: TJSONObject;
  Path: string;
begin
  Path := TCommerceBackendRoutes.EntitlementById(AEntitlement.EntitlementId);
  Json := EntitlementToJson(AEntitlement);
  try
    EnsureSuccess(SHttpPut, Path, SendJson(SHttpPut, Path, Json));
  finally
    Json.Free;
  end;
end;

function TCommerceHttpStorage.ListEntitlements(const AUserId,
  AAppId: string): TCommerceEntitlementArray;
var
  Path: string;
  Response: TCommerceBackendHttpResponse;
  Json: TJSONObject;
  Items: TJSONArray;
  I: Integer;
begin
  SetLength(Result, 0);
  Path := SCommerceRouteEntitlements + BuildQuery([
    SCommerceFieldUserId, AUserId,
    SCommerceFieldAppId, AAppId]);
  Response := SendJson(SHttpGet, Path);
  if Response.StatusCode = 404 then
    Exit;
  Json := JsonFromResponse(SHttpGet, Path, Response);
  try
    Items := Json.GetValue<TJSONArray>(SCommerceFieldItems, nil);
    if not Assigned(Items) then
      Exit;
    SetLength(Result, Items.Count);
    for I := 0 to Items.Count - 1 do
      if Items.Items[I] is TJSONObject then
        Result[I] := EntitlementFromJson(TJSONObject(Items.Items[I]));
  finally
    Json.Free;
  end;
end;

function TCommerceHttpStorage.FindEntitlement(const AUserId, AAppId,
  ACode: string; out AEntitlement: TCommerceEntitlementData): Boolean;
var
  Path: string;
  Response: TCommerceBackendHttpResponse;
  Json: TJSONObject;
begin
  Path := SCommerceRouteEntitlementsByCode + BuildQuery([
    SCommerceFieldUserId, AUserId,
    SCommerceFieldAppId, AAppId,
    SCommerceFieldCode, ACode]);
  Response := SendJson(SHttpGet, Path);
  if Response.StatusCode = 404 then
    Exit(False);
  Json := JsonFromResponse(SHttpGet, Path, Response);
  try
    AEntitlement := EntitlementFromJson(Json);
    Result := AEntitlement.EntitlementId <> '';
  finally
    Json.Free;
  end;
end;

function TCommerceHttpStorage.ConsumeEntitlement(const AEntitlementId: string;
  ACount: Integer; out AEntitlement: TCommerceEntitlementData): Boolean;
var
  Body: TJSONObject;
  Response: TCommerceBackendHttpResponse;
  Json: TJSONObject;
begin
  Result := False;
  if ACount <= 0 then
    Exit;

  Body := TJSONObject.Create;
  try
    Body.AddPair(SCommerceFieldEntitlementId, AEntitlementId);
    Body.AddPair(SCommerceFieldCount, TJSONNumber.Create(ACount));
    Response := SendJson(SHttpPost, SCommerceRouteEntitlementsConsume, Body);
  finally
    Body.Free;
  end;

  if (Response.StatusCode = 404) or (Response.StatusCode = 409) then
    Exit(False);

  Json := JsonFromResponse(SHttpPost, SCommerceRouteEntitlementsConsume,
    Response);
  try
    if not JsonValueAsBool(Json, SCommerceFieldSuccess, True) then
      Exit(False);
    AEntitlement := EntitlementFromJson(Json);
    Result := AEntitlement.EntitlementId <> '';
  finally
    Json.Free;
  end;
end;

{ TCommerceHttpPaymentGateway }

constructor TCommerceHttpPaymentGateway.Create(
  const AConfig: TCommerceBackendHttpConfig;
  const ATransport: ICommerceBackendHttpTransport);
begin
  inherited Create;
  if AConfig.BaseUrl.Trim = '' then
    raise EUniBaseCommerceValidationError.Create(
      'Commerce backend BaseUrl is required');

  FConfig := AConfig;
  FTransport := ATransport;
  if not Assigned(FTransport) then
    FTransport := TCommerceBackendHttpClientTransport.Create(AConfig.TimeoutMs);
end;

function TCommerceHttpPaymentGateway.BuildUrl(const APath: string): string;
var
  Base: string;
begin
  Base := FConfig.BaseUrl.Trim;
  while Base.EndsWith('/') do
    Delete(Base, Length(Base), 1);
  if APath.StartsWith('/') then
    Result := Base + APath
  else
    Result := Base + '/' + APath;
end;

function TCommerceHttpPaymentGateway.BuildHeaders(
  const AIdempotencyKey: string): TNetHeaders;
begin
  SetLength(Result, 0);
  AddHeader(Result, 'Accept', 'application/json');
  AddHeader(Result, 'Content-Type', 'application/json');
  if FConfig.BearerToken <> '' then
    AddHeader(Result, 'Authorization', 'Bearer ' + FConfig.BearerToken);
  if FConfig.ApiKey <> '' then
    AddHeader(Result, 'X-API-Key', FConfig.ApiKey);
  if AIdempotencyKey <> '' then
    AddHeader(Result, 'Idempotency-Key', AIdempotencyKey);
end;

function TCommerceHttpPaymentGateway.SendJson(const AMethod, APath: string;
  ABody: TJSONObject; const AIdempotencyKey: string): TCommerceBackendHttpResponse;
var
  BodyText: string;
begin
  if Assigned(ABody) then
    BodyText := ABody.ToJSON
  else
    BodyText := '';
  Result := FTransport.Send(AMethod, BuildUrl(APath), BodyText,
    BuildHeaders(AIdempotencyKey));
end;

function TCommerceHttpPaymentGateway.CreatePaymentIntent(
  const AOrder: TCommerceOrderData; const APayment: TCommercePaymentData;
  const APayerOpenId: string): TCommercePaymentIntent;
var
  Body: TJSONObject;
  Response: TCommerceBackendHttpResponse;
  Json: TJSONObject;
begin
  Body := TJSONObject.Create;
  try
    Body.AddPair(SCommerceFieldOrderId, AOrder.OrderId);
    Body.AddPair(SCommerceFieldPaymentId, APayment.PaymentId);
    Body.AddPair(SCommerceFieldOutTradeNo, AOrder.OutTradeNo);
    Body.AddPair(SCommerceFieldProvider,
      CommercePaymentProviderToStr(APayment.Provider));
    Body.AddPair(SCommerceFieldChannel, ChannelToString(APayment.Channel));
    Body.AddPair(SCommerceFieldPayerOpenId, APayerOpenId);
    Body.AddPair(SCommerceFieldAmountMinor,
      TJSONNumber.Create(AOrder.AmountMinor));
    Body.AddPair(SCommerceFieldCurrency, AOrder.Currency);

    Response := SendJson(SHttpPost, SCommerceRoutePaymentIntents, Body,
      APayment.PaymentId);
  finally
    Body.Free;
  end;

  if not IsHttpSuccess(Response.StatusCode) then
    Exit(TCommercePaymentIntent.Failed('http_' + IntToStr(Response.StatusCode),
      Copy(Response.Body, 1, 300)));

  Json := ParseJsonObject(Response.Body);
  try
    Result := PaymentIntentFromJson(Json, Response.Body);
  finally
    Json.Free;
  end;
end;

end.
