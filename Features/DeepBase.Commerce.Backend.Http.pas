unit DeepBase.Commerce.Backend.Http;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Net.HttpClient,
  System.Net.URLClient,
  DeepBase.Net.Transport,
  DeepBase.Commerce.Types,
  DeepBase.Commerce.Storage,
  DeepBase.Commerce.Service,
  DeepBase.Commerce.Backend.Contract,
  DeepBase.Commerce.JsonUtil;

type
  TCommerceBackendHttpConfig = record
    BaseUrl: string;
    RoutePrefix: string;
    BearerToken: string;
    ApiKey: string;
    TimeoutMs: Integer;
    AllowServerWrites: Boolean;
    class function Create(const ABaseUrl: string;
      const ABearerToken: string = ''; const AApiKey: string = '';
      ATimeoutMs: Integer = 30000;
      AAllowServerWrites: Boolean = False;
      const ARoutePrefix: string = ''): TCommerceBackendHttpConfig; static;
    class function CreateServerAdmin(const ABaseUrl: string;
      const ABearerToken: string = ''; const AApiKey: string = '';
      ATimeoutMs: Integer = 30000;
      const ARoutePrefix: string = ''): TCommerceBackendHttpConfig; static;
    class function CreateDeepKitClient(const ABaseUrl: string;
      const ABearerToken: string = ''; const AApiKey: string = '';
      ATimeoutMs: Integer = 30000): TCommerceBackendHttpConfig; static;
    class function CreateDeepKitServerAdmin(const ABaseUrl: string;
      const ABearerToken: string = ''; const AApiKey: string = '';
      ATimeoutMs: Integer = 30000): TCommerceBackendHttpConfig; static;
  end;

  TCommerceBackendHttpResponse = record
    StatusCode: Integer;
    Body: string;
    // BUG-428 FIX (E-005): response headers (empty when the transport does not
    // surface them). Needed by SafeClient.SendJson to honor the Retry-After
    // header on 429 responses. Defaults to nil (record zero-init), so existing
    // direct constructions `Result.StatusCode := x; Result.Body := y` are
    // unaffected — callers only read Headers when they need it.
    Headers: TNetHeaders;
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
    FLock: TObject;
  public
    constructor Create(ATimeoutMs: Integer = 30000);
    destructor Destroy; override;
    function Send(const AMethod, AUrl, ABody: string;
      const AHeaders: TNetHeaders): TCommerceBackendHttpResponse;
  end;

  TCommerceBackendUnifiedTransport = class(TInterfacedObject,
    ICommerceBackendHttpTransport)
  private
    FTransport: IDeepBaseHttpTransport;
    FTimeoutMs: Integer;
  public
    constructor Create(const ATransport: IDeepBaseHttpTransport;
      ATimeoutMs: Integer = 30000);
    function Send(const AMethod, AUrl, ABody: string;
      const AHeaders: TNetHeaders): TCommerceBackendHttpResponse;
  end;

  TCommerceHttpStorage = class(TInterfacedObject, ICommerceStorage)
  private
    FConfig: TCommerceBackendHttpConfig;
    FTransport: ICommerceBackendHttpTransport;

    function ApplyRoutePrefix(const APath: string): string;
    function BuildUrl(const APath: string): string;
    function BuildQuery(const APairs: array of string): string;
    function BuildHeaders: TNetHeaders;
    function SendJson(const AMethod, APath: string;
      ABody: TJSONObject = nil): TCommerceBackendHttpResponse;
    procedure EnsureSuccess(const AMethod, APath: string;
      const AResponse: TCommerceBackendHttpResponse);
    procedure RequireServerWrites(const AOperation: string);
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

    procedure RefundOrder(const AOrderId: string; AAmountMinor: Int64 = 0;
      const AReason: string = '');
    procedure CloseOrder(const AOrderId: string);
    procedure RevokeEntitlement(const AEntitlementId: string;
      const AReason: string = '');
    procedure RevokeLicenseSnapshot(const AAppId, ADeviceId, ASnapshotId: string;
      const AReason: string = '');
  end;

  TCommerceHttpPaymentGateway = class(TInterfacedObject, ICommercePaymentGateway)
  private
    FConfig: TCommerceBackendHttpConfig;
    FTransport: ICommerceBackendHttpTransport;

    function ApplyRoutePrefix(const APath: string): string;
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

{ TCommerceBackendHttpConfig }

class function TCommerceBackendHttpConfig.Create(const ABaseUrl, ABearerToken,
  AApiKey: string; ATimeoutMs: Integer; AAllowServerWrites: Boolean;
  const ARoutePrefix: string): TCommerceBackendHttpConfig;
begin
  Result.BaseUrl := ABaseUrl;
  Result.RoutePrefix := NormalizeRoutePrefix(ARoutePrefix);
  Result.BearerToken := ABearerToken;
  Result.ApiKey := AApiKey;
  Result.TimeoutMs := ATimeoutMs;
  Result.AllowServerWrites := AAllowServerWrites;
end;

class function TCommerceBackendHttpConfig.CreateServerAdmin(const ABaseUrl,
  ABearerToken, AApiKey: string; ATimeoutMs: Integer;
  const ARoutePrefix: string): TCommerceBackendHttpConfig;
begin
  Result := Create(ABaseUrl, ABearerToken, AApiKey, ATimeoutMs, True,
    ARoutePrefix);
end;

class function TCommerceBackendHttpConfig.CreateDeepKitClient(
  const ABaseUrl, ABearerToken, AApiKey: string;
  ATimeoutMs: Integer): TCommerceBackendHttpConfig;
begin
  Result := Create(ABaseUrl, ABearerToken, AApiKey, ATimeoutMs, False, '/dk');
end;

class function TCommerceBackendHttpConfig.CreateDeepKitServerAdmin(
  const ABaseUrl, ABearerToken, AApiKey: string;
  ATimeoutMs: Integer): TCommerceBackendHttpConfig;
begin
  Result := Create(ABaseUrl, ABearerToken, AApiKey, ATimeoutMs, True, '/dk');
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
  // TLS certificate validation uses platform defaults (enabled).
  // Do not disable for payment-related traffic.
  FLock := TObject.Create;
end;

destructor TCommerceBackendHttpClientTransport.Destroy;
begin
  FreeAndNil(FHttpClient);
  FreeAndNil(FLock);
  inherited;
end;

function TCommerceBackendHttpClientTransport.Send(const AMethod, AUrl,
  ABody: string; const AHeaders: TNetHeaders): TCommerceBackendHttpResponse;
var
  Response: IHTTPResponse;
  Stream: TStringStream;
begin
  // FEAT-014: THTTPClient is not thread-safe — serialize all calls on the
  // shared instance so concurrent Send invocations cannot corrupt internal
  // request/response state.
  TMonitor.Enter(FLock);
  try
    try
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
        raise EDeepBaseCommerceError.CreateFmt('Unsupported HTTP method: %s',
          [AMethod]);

      Result.StatusCode := Response.StatusCode;
      Result.Body := Response.ContentAsString(TEncoding.UTF8);
      Result.Headers := Response.Headers;
    except
      on E: EDeepBaseCommerceError do
        raise;
      on E: Exception do
        raise EDeepBaseCommerceError.CreateFmt(
          'Commerce HTTP transport error for %s %s: %s', [AMethod, AUrl, E.Message]);
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

{ TCommerceBackendUnifiedTransport }

constructor TCommerceBackendUnifiedTransport.Create(
  const ATransport: IDeepBaseHttpTransport; ATimeoutMs: Integer);
begin
  inherited Create;
  if not Assigned(ATransport) then
    raise EDeepBaseCommerceValidationError.Create(
      'Commerce unified transport requires IDeepBaseHttpTransport');
  if ATimeoutMs <= 0 then
    ATimeoutMs := 30000;
  FTransport := ATransport;
  FTimeoutMs := ATimeoutMs;
end;

function TCommerceBackendUnifiedTransport.Send(const AMethod, AUrl,
  ABody: string; const AHeaders: TNetHeaders): TCommerceBackendHttpResponse;
var
  Request: TDeepBaseHttpTransportRequest;
  Response: TDeepBaseHttpTransportResponse;
begin
  Request := TDeepBaseHttpTransportRequest.Create(
    DeepBaseHttpMethodFromString(AMethod), AUrl);
  Request.Body := ABody;
  Request.Headers := AHeaders;
  Request.ContentType := 'application/json';
  Request.TimeoutMs := FTimeoutMs;

  Response := FTransport.Send(Request);
  Result.StatusCode := Response.StatusCode;
  Result.Body := Response.Body;
  Result.Headers := Response.Headers;
end;

{ TCommerceHttpStorage }

constructor TCommerceHttpStorage.Create(
  const AConfig: TCommerceBackendHttpConfig;
  const ATransport: ICommerceBackendHttpTransport);
begin
  inherited Create;
  if AConfig.BaseUrl.Trim = '' then
    raise EDeepBaseCommerceValidationError.Create(
      'Commerce backend BaseUrl is required');

  FConfig := AConfig;
  FTransport := ATransport;
  if not Assigned(FTransport) then
    FTransport := TCommerceBackendHttpClientTransport.Create(AConfig.TimeoutMs);
end;

function TCommerceHttpStorage.ApplyRoutePrefix(const APath: string): string;
var
  Path: string;
  Prefix: string;
begin
  Path := APath;
  if not Path.StartsWith('/') then
    Path := '/' + Path;

  Prefix := NormalizeRoutePrefix(FConfig.RoutePrefix);
  if (Prefix <> '') and (not RouteStartsWithPrefix(Path, Prefix)) then
    Path := Prefix + Path;

  Result := Path;
end;

function TCommerceHttpStorage.BuildUrl(const APath: string): string;
var
  Base: string;
  Path: string;
begin
  Base := FConfig.BaseUrl.Trim;
  while Base.EndsWith('/') do
    Delete(Base, Length(Base), 1);
  Path := ApplyRoutePrefix(APath);
  if Path.StartsWith('/') then
    Result := Base + Path
  else
    Result := Base + '/' + Path;
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
    raise EDeepBaseCommerceError.CreateFmt('Commerce backend HTTP %d for %s %s: %s',
      [AResponse.StatusCode, AMethod, APath, Copy(AResponse.Body, 1, 300)]);
end;

procedure TCommerceHttpStorage.RequireServerWrites(
  const AOperation: string);
begin
  if not FConfig.AllowServerWrites then
    raise EDeepBaseCommerceValidationError.CreateFmt(
      '%s requires server-admin Commerce HTTP config. Desktop clients must call safe backend APIs and must not write orders, payments, products, users, or entitlements directly.',
      [AOperation]);
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
  RequireServerWrites('UpsertUser');
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
  RequireServerWrites('LinkIdentity');
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
  RequireServerWrites('UpsertProduct');
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
  RequireServerWrites('CreateOrder');
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
  RequireServerWrites('UpdateOrder');
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
  RequireServerWrites('CreatePayment');
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
  RequireServerWrites('UpdatePayment');
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
  RequireServerWrites('UpsertEntitlement');
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
    if not JsonValueAsBool(Json, SCommerceFieldSuccess, False) then
      Exit(False);
    AEntitlement := EntitlementFromJson(Json);
    Result := AEntitlement.EntitlementId <> '';
  finally
    Json.Free;
  end;
end;

procedure TCommerceHttpStorage.RefundOrder(const AOrderId: string;
  AAmountMinor: Int64; const AReason: string);
var
  Body: TJSONObject;
  Path: string;
begin
  if AOrderId.Trim = '' then
    raise EDeepBaseCommerceValidationError.Create(
      'RefundOrder requires order_id');
  RequireServerWrites('RefundOrder');
  Path := TCommerceBackendRoutes.OrderRefund(AOrderId);
  Body := TJSONObject.Create;
  try
    Body.AddPair(SCommerceFieldOrderId, AOrderId);
    if AAmountMinor > 0 then
      Body.AddPair(SCommerceFieldAmountMinor, TJSONNumber.Create(AAmountMinor));
    if AReason <> '' then
      Body.AddPair(SCommerceFieldReason, AReason);
    EnsureSuccess(SHttpPost, Path, SendJson(SHttpPost, Path, Body));
  finally
    Body.Free;
  end;
end;

procedure TCommerceHttpStorage.CloseOrder(const AOrderId: string);
var
  Body: TJSONObject;
  Path: string;
begin
  if AOrderId.Trim = '' then
    raise EDeepBaseCommerceValidationError.Create(
      'CloseOrder requires order_id');
  RequireServerWrites('CloseOrder');
  Path := TCommerceBackendRoutes.OrderClose(AOrderId);
  Body := TJSONObject.Create;
  try
    Body.AddPair(SCommerceFieldOrderId, AOrderId);
    EnsureSuccess(SHttpPost, Path, SendJson(SHttpPost, Path, Body));
  finally
    Body.Free;
  end;
end;

procedure TCommerceHttpStorage.RevokeEntitlement(const AEntitlementId,
  AReason: string);
var
  Body: TJSONObject;
  Path: string;
begin
  if AEntitlementId.Trim = '' then
    raise EDeepBaseCommerceValidationError.Create(
      'RevokeEntitlement requires entitlement_id');
  RequireServerWrites('RevokeEntitlement');
  Path := TCommerceBackendRoutes.EntitlementRevoke(AEntitlementId);
  Body := TJSONObject.Create;
  try
    Body.AddPair(SCommerceFieldEntitlementId, AEntitlementId);
    if AReason <> '' then
      Body.AddPair(SCommerceFieldReason, AReason);
    EnsureSuccess(SHttpPost, Path, SendJson(SHttpPost, Path, Body));
  finally
    Body.Free;
  end;
end;

procedure TCommerceHttpStorage.RevokeLicenseSnapshot(const AAppId, ADeviceId,
  ASnapshotId, AReason: string);
var
  Body: TJSONObject;
begin
  if AAppId.Trim = '' then
    raise EDeepBaseCommerceValidationError.Create(
      'RevokeLicenseSnapshot requires app_id');
  if ADeviceId.Trim = '' then
    raise EDeepBaseCommerceValidationError.Create(
      'RevokeLicenseSnapshot requires device_id');

  RequireServerWrites('RevokeLicenseSnapshot');
  Body := TJSONObject.Create;
  try
    Body.AddPair(SCommerceFieldAppId, AAppId);
    Body.AddPair(SCommerceFieldDeviceId, ADeviceId);
    if ASnapshotId <> '' then
      Body.AddPair(SCommerceFieldSnapshotId, ASnapshotId);
    if AReason <> '' then
      Body.AddPair(SCommerceFieldReason, AReason);
    EnsureSuccess(SHttpPost, SCommerceRouteLicenseSnapshotRevoke,
      SendJson(SHttpPost, SCommerceRouteLicenseSnapshotRevoke, Body));
  finally
    Body.Free;
  end;
end;

{ TCommerceHttpPaymentGateway }

constructor TCommerceHttpPaymentGateway.Create(
  const AConfig: TCommerceBackendHttpConfig;
  const ATransport: ICommerceBackendHttpTransport);
begin
  inherited Create;
  if AConfig.BaseUrl.Trim = '' then
    raise EDeepBaseCommerceValidationError.Create(
      'Commerce backend BaseUrl is required');

  FConfig := AConfig;
  FTransport := ATransport;
  if not Assigned(FTransport) then
    FTransport := TCommerceBackendHttpClientTransport.Create(AConfig.TimeoutMs);
end;

function TCommerceHttpPaymentGateway.ApplyRoutePrefix(const APath: string): string;
var
  Path: string;
  Prefix: string;
begin
  Path := APath;
  if not Path.StartsWith('/') then
    Path := '/' + Path;

  Prefix := NormalizeRoutePrefix(FConfig.RoutePrefix);
  if (Prefix <> '') and (not RouteStartsWithPrefix(Path, Prefix)) then
    Path := Prefix + Path;

  Result := Path;
end;

function TCommerceHttpPaymentGateway.BuildUrl(const APath: string): string;
var
  Base: string;
  Path: string;
begin
  Base := FConfig.BaseUrl.Trim;
  while Base.EndsWith('/') do
    Delete(Base, Length(Base), 1);
  Path := ApplyRoutePrefix(APath);
  if Path.StartsWith('/') then
    Result := Base + Path
  else
    Result := Base + '/' + Path;
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
