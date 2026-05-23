unit DeepBase.Commerce.Adapter.Supabase;

{==============================================================================
  DeepBase.Commerce.Adapter.Supabase - Supabase Storage Adapter

  ICommerceStorage implementation using Supabase REST API (PostgREST).
  Maps each ICommerceStorage method to Supabase table operations.

  Usage:
    Storage := TSupabaseCommerceStorage.Create(
      'https://xxx.supabase.co', 'eyJhbG...', 'commerce_');
    Service := TDeepBaseCommerceService.Create(Storage);

  Table naming: uses configurable prefix (default 'commerce_').
  Example: commerce_users, commerce_orders, commerce_payments, etc.
==============================================================================}

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Generics.Collections,
  System.Net.HttpClient,
  System.Net.URLClient,
  System.NetEncoding,
  DeepBase.Commerce.Types,
  DeepBase.Commerce.Storage;

type
  TSupabaseConfig = record
    BaseUrl: string;
    ApiKey: string;
    ServiceRoleKey: string;
    TablePrefix: string;
    TimeoutMs: Integer;
    AllowServerOnlyPrototype: Boolean;
    class function Create(const ABaseUrl, AApiKey: string;
      const ATablePrefix: string = 'commerce_';
      ATimeoutMs: Integer = 15000;
      AAllowServerOnlyPrototype: Boolean = False): TSupabaseConfig; static;
    class function CreateServerOnly(const ABaseUrl, AApiKey: string;
      const ATablePrefix: string = 'commerce_';
      ATimeoutMs: Integer = 15000): TSupabaseConfig; static;
  end;

  TSupabaseCommerceStorage = class(TInterfacedObject, ICommerceStorage)
  private
    FConfig: TSupabaseConfig;
    FClient: THTTPClient;
    function TableName(const ABase: string): string;
    function BuildUrl(const ATable: string; const AParams: string = ''): string;
    function AddAuthHeaders: TNetHeaders;
    function SupabaseGet(const AUrl: string): TJSONObject;
    function SupabasePost(const AUrl: string; ABody: TJSONObject): TJSONObject;
    function SupabasePatch(const AUrl: string; ABody: TJSONObject): TJSONObject;
    function SingleOrNull(Arr: TJSONArray): TJSONObject;
    function ParseUser(Obj: TJSONObject): TCommerceUserData;
    function ParseOrder(Obj: TJSONObject): TCommerceOrderData;
    function ParsePayment(Obj: TJSONObject): TCommercePaymentData;
    function ParseProduct(Obj: TJSONObject): TCommerceProductData;
    function ParseEntitlement(Obj: TJSONObject): TCommerceEntitlementData;
    function UserToJson(const AUser: TCommerceUserData): TJSONObject;
    function OrderToJson(const AOrder: TCommerceOrderData): TJSONObject;
    function PaymentToJson(const APayment: TCommercePaymentData): TJSONObject;
    function ProductToJson(const AProduct: TCommerceProductData): TJSONObject;
    function EntitlementToJson(const AEntitlement: TCommerceEntitlementData): TJSONObject;
    function IdentityToJson(const AIdentity: TCommerceIdentityData): TJSONObject;
  public
    constructor Create(const AConfig: TSupabaseConfig);
    destructor Destroy; override;

    // ICommerceStorage
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

{ TSupabaseConfig }

class function TSupabaseConfig.Create(const ABaseUrl, AApiKey: string;
  const ATablePrefix: string; ATimeoutMs: Integer;
  AAllowServerOnlyPrototype: Boolean): TSupabaseConfig;
begin
  Result.BaseUrl := ABaseUrl;
  Result.ApiKey := AApiKey;
  Result.ServiceRoleKey := '';
  Result.TablePrefix := ATablePrefix;
  Result.TimeoutMs := ATimeoutMs;
  Result.AllowServerOnlyPrototype := AAllowServerOnlyPrototype;
end;

class function TSupabaseConfig.CreateServerOnly(const ABaseUrl,
  AApiKey: string; const ATablePrefix: string;
  ATimeoutMs: Integer): TSupabaseConfig;
begin
  Result := Create(ABaseUrl, AApiKey, ATablePrefix, ATimeoutMs, True);
end;

{ TSupabaseCommerceStorage }

constructor TSupabaseCommerceStorage.Create(const AConfig: TSupabaseConfig);
begin
  inherited Create;
  if not AConfig.AllowServerOnlyPrototype and
     (not SameText(GetEnvironmentVariable(
       'DEEPBASE_ALLOW_PROTOTYPE_COMMERCE_ADAPTERS'), '1')) then
    raise EDeepBaseCommerceValidationError.Create(
      'TSupabaseCommerceStorage is server-only/prototype. Desktop production clients must use safe backend APIs (for example TDeepKitSafeClient) instead of direct Supabase adapter.');

  FConfig := AConfig;
  FClient := THTTPClient.Create;
  FClient.ConnectionTimeout := FConfig.TimeoutMs;
  FClient.ResponseTimeout := FConfig.TimeoutMs;
end;

destructor TSupabaseCommerceStorage.Destroy;
begin
  FreeAndNil(FClient);
  inherited;
end;

function TSupabaseCommerceStorage.TableName(const ABase: string): string;
begin
  Result := FConfig.TablePrefix + ABase;
end;

function TSupabaseCommerceStorage.BuildUrl(const ATable, AParams: string): string;
var
  Base: string;
begin
  Base := FConfig.BaseUrl;
  if not Base.EndsWith('/') then
    Base := Base + '/';
  Result := Base + 'rest/v1/' + ATable;
  if AParams <> '' then
    Result := Result + '?' + AParams;
end;

function TSupabaseCommerceStorage.AddAuthHeaders: TNetHeaders;
var
  Key: string;
begin
  if FConfig.ServiceRoleKey <> '' then
    Key := FConfig.ServiceRoleKey
  else
    Key := FConfig.ApiKey;
  Result := [
    TNetHeader.Create('apikey', FConfig.ApiKey),
    TNetHeader.Create('Authorization', 'Bearer ' + Key),
    TNetHeader.Create('Content-Type', 'application/json'),
    TNetHeader.Create('Prefer', 'return=representation')
  ];
end;

function TSupabaseCommerceStorage.SupabaseGet(const AUrl: string): TJSONObject;
var
  Response: IHTTPResponse;
  Arr: TJSONArray;
begin
  Response := FClient.Get(AUrl, nil, AddAuthHeaders);
  if Response.StatusCode >= 300 then
    raise EDeepBaseCommerceError.CreateFmt('Supabase GET %s: %d %s',
      [AUrl, Response.StatusCode, Response.StatusText]);

  Arr := TJSONObject.ParseJSONValue(Response.ContentAsString(TEncoding.UTF8)) as TJSONArray;
  if Assigned(Arr) then
  try
    Result := SingleOrNull(Arr);
  finally
    Arr.Free;
  end
  else
    Result := nil;
end;

function TSupabaseCommerceStorage.SupabasePost(const AUrl: string;
  ABody: TJSONObject): TJSONObject;
var
  Response: IHTTPResponse;
  Arr: TJSONArray;
begin
  Response := FClient.Post(AUrl, ABody.ToJSON, nil, AddAuthHeaders);
  if Response.StatusCode >= 300 then
    raise EDeepBaseCommerceError.CreateFmt('Supabase POST %s: %d %s',
      [AUrl, Response.StatusCode, Response.StatusText]);

  Arr := TJSONObject.ParseJSONValue(Response.ContentAsString(TEncoding.UTF8)) as TJSONArray;
  if Assigned(Arr) then
  try
    Result := SingleOrNull(Arr);
  finally
    Arr.Free;
  end
  else
    Result := nil;
end;

function TSupabaseCommerceStorage.SupabasePatch(const AUrl: string;
  ABody: TJSONObject): TJSONObject;
var
  Response: IHTTPResponse;
  Arr: TJSONArray;
  BodyStream: TStringStream;
begin
  BodyStream := TStringStream.Create(ABody.ToJSON, TEncoding.UTF8);
  try
    Response := FClient.Patch(AUrl, BodyStream, nil, AddAuthHeaders);
  finally
    BodyStream.Free;
  end;
  if Response.StatusCode >= 300 then
    raise EDeepBaseCommerceError.CreateFmt('Supabase PATCH %s: %d %s',
      [AUrl, Response.StatusCode, Response.StatusText]);

  Arr := TJSONObject.ParseJSONValue(Response.ContentAsString(TEncoding.UTF8)) as TJSONArray;
  if Assigned(Arr) then
  try
    Result := SingleOrNull(Arr);
  finally
    Arr.Free;
  end
  else
    Result := nil;
end;

function TSupabaseCommerceStorage.SingleOrNull(Arr: TJSONArray): TJSONObject;
begin
  if (Arr <> nil) and (Arr.Count > 0) then
    Result := Arr.Items[0].Clone as TJSONObject  // Clone to avoid UAF when Arr is freed
  else
    Result := nil;
end;

{ JSON parsing helpers }

function Str(Obj: TJSONObject; const AKey: string): string;
begin
  if Obj.TryGetValue<string>(AKey, Result) then
    Exit;
  Result := '';
end;

function Int64Val(Obj: TJSONObject; const AKey: string): Int64;
var
  V: Int64;
begin
  if Obj.TryGetValue<Int64>(AKey, V) then
    Exit(V);
  Result := 0;
end;

function BoolVal(Obj: TJSONObject; const AKey: string): Boolean;
var
  V: Boolean;
begin
  if Obj.TryGetValue<Boolean>(AKey, V) then
    Exit(V);
  Result := False;
end;

function IntVal(Obj: TJSONObject; const AKey: string): Integer;
var
  V: Integer;
begin
  if Obj.TryGetValue<Integer>(AKey, V) then
    Exit(V);
  Result := 0;
end;

{ Record parsers }

function TSupabaseCommerceStorage.ParseUser(Obj: TJSONObject): TCommerceUserData;
begin
  Result.UserId := Str(Obj, 'user_id');
  Result.DisplayName := Str(Obj, 'display_name');
  Result.Email := Str(Obj, 'email');
  Result.Phone := Str(Obj, 'phone');
  Result.IsActive := BoolVal(Obj, 'is_active');
  Result.CreatedAtISO := Str(Obj, 'created_at');
  Result.UpdatedAtISO := Str(Obj, 'updated_at');
end;

function TSupabaseCommerceStorage.ParseOrder(Obj: TJSONObject): TCommerceOrderData;
begin
  Result.OrderId := Str(Obj, 'order_id');
  Result.UserId := Str(Obj, 'user_id');
  Result.AppId := Str(Obj, 'app_id');
  Result.ProductId := Str(Obj, 'product_id');
  Result.OutTradeNo := Str(Obj, 'out_trade_no');
  Result.Title := Str(Obj, 'title');
  Result.AmountMinor := Int64Val(Obj, 'amount_minor');
  Result.Currency := Str(Obj, 'currency');
  Result.CreatedAtISO := Str(Obj, 'created_at');
  Result.PaidAtISO := Str(Obj, 'paid_at');
end;

function TSupabaseCommerceStorage.ParsePayment(Obj: TJSONObject): TCommercePaymentData;
begin
  Result.PaymentId := Str(Obj, 'payment_id');
  Result.OrderId := Str(Obj, 'order_id');
  Result.ProviderTradeNo := Str(Obj, 'provider_trade_no');
  Result.PrepayId := Str(Obj, 'prepay_id');
  Result.RawPayload := Str(Obj, 'raw_payload');
  Result.Provider := StrToCommercePaymentProvider(Str(Obj, 'provider'));
  Result.Channel := StrToCommercePaymentChannel(Str(Obj, 'channel'));
  Result.Status := StrToCommercePaymentStatus(Str(Obj, 'status'));
  Result.CreatedAtISO := Str(Obj, 'created_at');
  Result.PaidAtISO := Str(Obj, 'paid_at');
end;

function TSupabaseCommerceStorage.ParseProduct(Obj: TJSONObject): TCommerceProductData;
begin
  Result.ProductId := Str(Obj, 'product_id');
  Result.AppId := Str(Obj, 'app_id');
  Result.Name := Str(Obj, 'name');
  Result.Description := Str(Obj, 'description');
  Result.AmountMinor := Int64Val(Obj, 'amount_minor');
  Result.Currency := Str(Obj, 'currency');
  Result.EntitlementCode := Str(Obj, 'entitlement_code');
  Result.EntitlementDurationDays := IntVal(Obj, 'entitlement_duration_days');
  Result.InitialQuota := IntVal(Obj, 'initial_quota');
  Result.IsActive := BoolVal(Obj, 'is_active');
end;

function TSupabaseCommerceStorage.ParseEntitlement(Obj: TJSONObject): TCommerceEntitlementData;
begin
  Result.EntitlementId := Str(Obj, 'entitlement_id');
  Result.UserId := Str(Obj, 'user_id');
  Result.AppId := Str(Obj, 'app_id');
  Result.ProductId := Str(Obj, 'product_id');
  Result.Code := Str(Obj, 'code');
  Result.Status := StrToCommerceEntitlementStatus(Str(Obj, 'status'));
  Result.ValidFromISO := Str(Obj, 'valid_from');
  Result.ValidUntilISO := Str(Obj, 'valid_until');
  Result.RemainingQuota := IntVal(Obj, 'remaining_quota');
  Result.SourceOrderId := Str(Obj, 'source_order_id');
end;

{ Record serializers }

function TSupabaseCommerceStorage.UserToJson(const AUser: TCommerceUserData): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('user_id', AUser.UserId);
  Result.AddPair('display_name', AUser.DisplayName);
  Result.AddPair('email', AUser.Email);
  Result.AddPair('phone', AUser.Phone);
  Result.AddPair('is_active', TJSONBool.Create(AUser.IsActive));
  Result.AddPair('created_at', AUser.CreatedAtISO);
  Result.AddPair('updated_at', AUser.UpdatedAtISO);
end;

function TSupabaseCommerceStorage.OrderToJson(const AOrder: TCommerceOrderData): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('order_id', AOrder.OrderId);
  Result.AddPair('user_id', AOrder.UserId);
  Result.AddPair('app_id', AOrder.AppId);
  Result.AddPair('product_id', AOrder.ProductId);
  Result.AddPair('out_trade_no', AOrder.OutTradeNo);
  Result.AddPair('title', AOrder.Title);
  Result.AddPair('amount_minor', TJSONNumber.Create(AOrder.AmountMinor));
  Result.AddPair('currency', AOrder.Currency);
  Result.AddPair('status', CommerceOrderStatusToStr(AOrder.Status));
  Result.AddPair('created_at', AOrder.CreatedAtISO);
  if AOrder.PaidAtISO <> '' then
    Result.AddPair('paid_at', AOrder.PaidAtISO);
end;

function TSupabaseCommerceStorage.PaymentToJson(const APayment: TCommercePaymentData): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('payment_id', APayment.PaymentId);
  Result.AddPair('order_id', APayment.OrderId);
  Result.AddPair('provider', CommercePaymentProviderToStr(APayment.Provider));
  Result.AddPair('channel', CommercePaymentChannelToStr(APayment.Channel));
  Result.AddPair('provider_trade_no', APayment.ProviderTradeNo);
  Result.AddPair('prepay_id', APayment.PrepayId);
  Result.AddPair('status', CommercePaymentStatusToStr(APayment.Status));
  Result.AddPair('raw_payload', APayment.RawPayload);
  Result.AddPair('created_at', APayment.CreatedAtISO);
  if APayment.PaidAtISO <> '' then
    Result.AddPair('paid_at', APayment.PaidAtISO);
end;

function TSupabaseCommerceStorage.ProductToJson(const AProduct: TCommerceProductData): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('product_id', AProduct.ProductId);
  Result.AddPair('app_id', AProduct.AppId);
  Result.AddPair('name', AProduct.Name);
  Result.AddPair('description', AProduct.Description);
  Result.AddPair('amount_minor', TJSONNumber.Create(AProduct.AmountMinor));
  Result.AddPair('currency', AProduct.Currency);
  Result.AddPair('entitlement_code', AProduct.EntitlementCode);
  Result.AddPair('entitlement_duration_days', TJSONNumber.Create(AProduct.EntitlementDurationDays));
  Result.AddPair('initial_quota', TJSONNumber.Create(AProduct.InitialQuota));
  Result.AddPair('is_active', TJSONBool.Create(AProduct.IsActive));
end;

function TSupabaseCommerceStorage.EntitlementToJson(
  const AEntitlement: TCommerceEntitlementData): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('entitlement_id', AEntitlement.EntitlementId);
  Result.AddPair('user_id', AEntitlement.UserId);
  Result.AddPair('app_id', AEntitlement.AppId);
  Result.AddPair('product_id', AEntitlement.ProductId);
  Result.AddPair('code', AEntitlement.Code);
  // FEAT-003: Serialize entitlement status as string instead of empty value
  var LStatusStr: string;
  case AEntitlement.Status of
    cesActive:   LStatusStr := 'active';
    cesConsumed: LStatusStr := 'consumed';
    cesExpired:  LStatusStr := 'expired';
  else
    LStatusStr := 'revoked';
  end;
  Result.AddPair('status', LStatusStr);
  Result.AddPair('valid_from', AEntitlement.ValidFromISO);
  if AEntitlement.ValidUntilISO <> '' then
    Result.AddPair('valid_until', AEntitlement.ValidUntilISO);
  Result.AddPair('remaining_quota', TJSONNumber.Create(AEntitlement.RemainingQuota));
  Result.AddPair('source_order_id', AEntitlement.SourceOrderId);
end;

function TSupabaseCommerceStorage.IdentityToJson(
  const AIdentity: TCommerceIdentityData): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('user_id', AIdentity.UserId);
  Result.AddPair('provider', CommerceAuthProviderToStr(AIdentity.Provider));
  Result.AddPair('provider_user_id', AIdentity.ProviderUserId);
  Result.AddPair('app_id', AIdentity.AppId);
  Result.AddPair('union_id', AIdentity.UnionId);
  Result.AddPair('created_at', AIdentity.CreatedAtISO);
end;

{ ICommerceStorage implementation }

function TSupabaseCommerceStorage.FindUserById(const AUserId: string;
  out AUser: TCommerceUserData): Boolean;
var
  Obj: TJSONObject;
begin
  Obj := SupabaseGet(BuildUrl(TableName('users'),
    'user_id=eq.' + TNetEncoding.URL.Encode(AUserid)));
  Result := Assigned(Obj);
  if Result then
  try
    AUser := ParseUser(Obj);
  finally
    Obj.Free;
  end;
end;

function TSupabaseCommerceStorage.FindUserByIdentity(AProvider: TCommerceAuthProvider;
  const AProviderUserId, AAppId: string; out AUser: TCommerceUserData): Boolean;
var
  Obj: TJSONObject;
  Params: string;
begin
  Params := 'provider=eq.' + CommerceAuthProviderToStr(AProvider) +
    '&provider_user_id=eq.' + TNetEncoding.URL.Encode(AProviderUserId) +
    '&app_id=eq.' + TNetEncoding.URL.Encode(AAppId) +
    '&select=user_id,display_name,email,phone,is_active,created_at,updated_at' +
    ',users!inner(user_id,display_name,email,phone,is_active,created_at,updated_at)';
  Obj := SupabaseGet(BuildUrl(TableName('identities'), Params));
  Result := Assigned(Obj);
  if Result then
  try
    AUser := ParseUser(Obj);
  finally
    Obj.Free;
  end;
end;

procedure TSupabaseCommerceStorage.UpsertUser(const AUser: TCommerceUserData);
var
  Body: TJSONObject;
begin
  Body := UserToJson(AUser);
  try
    SupabasePost(BuildUrl(TableName('users')), Body);
  finally
    Body.Free;
  end;
end;

procedure TSupabaseCommerceStorage.LinkIdentity(const AIdentity: TCommerceIdentityData);
var
  Body: TJSONObject;
begin
  Body := IdentityToJson(AIdentity);
  try
    SupabasePost(BuildUrl(TableName('identities')), Body);
  finally
    Body.Free;
  end;
end;

function TSupabaseCommerceStorage.FindProduct(const AAppId, AProductId: string;
  out AProduct: TCommerceProductData): Boolean;
var
  Obj: TJSONObject;
  Params: string;
begin
  Params := 'app_id=eq.' + TNetEncoding.URL.Encode(AAppId) +
    '&product_id=eq.' + TNetEncoding.URL.Encode(AProductId);
  Obj := SupabaseGet(BuildUrl(TableName('products'), Params));
  Result := Assigned(Obj);
  if Result then
  try
    AProduct := ParseProduct(Obj);
  finally
    Obj.Free;
  end;
end;

procedure TSupabaseCommerceStorage.UpsertProduct(const AProduct: TCommerceProductData);
var
  Body: TJSONObject;
begin
  Body := ProductToJson(AProduct);
  try
    SupabasePost(BuildUrl(TableName('products')), Body);
  finally
    Body.Free;
  end;
end;

procedure TSupabaseCommerceStorage.CreateOrder(const AOrder: TCommerceOrderData);
var
  Body: TJSONObject;
begin
  Body := OrderToJson(AOrder);
  try
    SupabasePost(BuildUrl(TableName('orders')), Body);
  finally
    Body.Free;
  end;
end;

function TSupabaseCommerceStorage.FindOrderById(const AOrderId: string;
  out AOrder: TCommerceOrderData): Boolean;
var
  Obj: TJSONObject;
begin
  Obj := SupabaseGet(BuildUrl(TableName('orders'),
    'order_id=eq.' + TNetEncoding.URL.Encode(AOrderId)));
  Result := Assigned(Obj);
  if Result then
  try
    AOrder := ParseOrder(Obj);
  finally
    Obj.Free;
  end;
end;

function TSupabaseCommerceStorage.FindOrderByOutTradeNo(const AOutTradeNo: string;
  out AOrder: TCommerceOrderData): Boolean;
var
  Obj: TJSONObject;
begin
  Obj := SupabaseGet(BuildUrl(TableName('orders'),
    'out_trade_no=eq.' + TNetEncoding.URL.Encode(AOutTradeNo)));
  Result := Assigned(Obj);
  if Result then
  try
    AOrder := ParseOrder(Obj);
  finally
    Obj.Free;
  end;
end;

procedure TSupabaseCommerceStorage.UpdateOrder(const AOrder: TCommerceOrderData);
var
  Body: TJSONObject;
begin
  Body := OrderToJson(AOrder);
  try
    SupabasePatch(BuildUrl(TableName('orders'),
      'order_id=eq.' + TNetEncoding.URL.Encode(AOrder.OrderId)), Body);
  finally
    Body.Free;
  end;
end;

procedure TSupabaseCommerceStorage.CreatePayment(const APayment: TCommercePaymentData);
var
  Body: TJSONObject;
begin
  Body := PaymentToJson(APayment);
  try
    SupabasePost(BuildUrl(TableName('payments')), Body);
  finally
    Body.Free;
  end;
end;

function TSupabaseCommerceStorage.FindPaymentByOrderId(const AOrderId: string;
  out APayment: TCommercePaymentData): Boolean;
var
  Obj: TJSONObject;
begin
  Obj := SupabaseGet(BuildUrl(TableName('payments'),
    'order_id=eq.' + TNetEncoding.URL.Encode(AOrderId)));
  Result := Assigned(Obj);
  if Result then
  try
    APayment := ParsePayment(Obj);
  finally
    Obj.Free;
  end;
end;

procedure TSupabaseCommerceStorage.UpdatePayment(const APayment: TCommercePaymentData);
var
  Body: TJSONObject;
begin
  Body := PaymentToJson(APayment);
  try
    SupabasePatch(BuildUrl(TableName('payments'),
      'payment_id=eq.' + TNetEncoding.URL.Encode(APayment.PaymentId)), Body);
  finally
    Body.Free;
  end;
end;

procedure TSupabaseCommerceStorage.UpsertEntitlement(
  const AEntitlement: TCommerceEntitlementData);
var
  Body: TJSONObject;
begin
  Body := EntitlementToJson(AEntitlement);
  try
    SupabasePost(BuildUrl(TableName('entitlements')), Body);
  finally
    Body.Free;
  end;
end;

function TSupabaseCommerceStorage.ListEntitlements(
  const AUserId, AAppId: string): TCommerceEntitlementArray;
var
  Response: IHTTPResponse;
  Arr: TJSONArray;
  I: Integer;
begin
  Response := FClient.Get(
    BuildUrl(TableName('entitlements'),
      'user_id=eq.' + TNetEncoding.URL.Encode(AUserId) +
      '&app_id=eq.' + TNetEncoding.URL.Encode(AAppId)),
    nil, AddAuthHeaders);

  Arr := TJSONObject.ParseJSONValue(Response.ContentAsString(TEncoding.UTF8)) as TJSONArray;
  if Assigned(Arr) then
  try
    SetLength(Result, Arr.Count);
    for I := 0 to Arr.Count - 1 do
      Result[I] := ParseEntitlement(Arr.Items[I] as TJSONObject);
  finally
    Arr.Free;
  end
  else
    SetLength(Result, 0);
end;

function TSupabaseCommerceStorage.FindEntitlement(const AUserId, AAppId,
  ACode: string; out AEntitlement: TCommerceEntitlementData): Boolean;
var
  Obj: TJSONObject;
  Params: string;
begin
  Params := 'user_id=eq.' + TNetEncoding.URL.Encode(AUserId) +
    '&app_id=eq.' + TNetEncoding.URL.Encode(AAppId) +
    '&code=eq.' + TNetEncoding.URL.Encode(ACode);
  Obj := SupabaseGet(BuildUrl(TableName('entitlements'), Params));
  Result := Assigned(Obj);
  if Result then
  try
    AEntitlement := ParseEntitlement(Obj);
  finally
    Obj.Free;
  end;
end;

function TSupabaseCommerceStorage.ConsumeEntitlement(const AEntitlementId: string;
  ACount: Integer; out AEntitlement: TCommerceEntitlementData): Boolean;
var
  Body: TJSONObject;
  Obj: TJSONObject;
  LFilter: string;
  NewQuota: Integer;
begin
  // Read current entitlement
  Obj := SupabaseGet(BuildUrl(TableName('entitlements'),
    'entitlement_id=eq.' + TNetEncoding.URL.Encode(AEntitlementId)));
  if not Assigned(Obj) then
    Exit(False);
  try
    AEntitlement := ParseEntitlement(Obj);
    if AEntitlement.Status <> cesActive then
      Exit(False);

    // Unlimited quota (-1): skip deduction, always succeed
    if AEntitlement.RemainingQuota < 0 then
      Exit(True);

    if AEntitlement.RemainingQuota < ACount then
      Exit(False);
  finally
    Obj.Free;
  end;

  // Compute new quota and PATCH with atomic filter to prevent over-consumption
  NewQuota := AEntitlement.RemainingQuota - ACount;
  LFilter := 'entitlement_id=eq.' + TNetEncoding.URL.Encode(AEntitlementId) +
    '&remaining_quota=eq.' + IntToStr(AEntitlement.RemainingQuota);

  Body := TJSONObject.Create;
  try
    Body.AddPair('remaining_quota', TJSONNumber.Create(NewQuota));
    SupabasePatch(BuildUrl(TableName('entitlements'), LFilter), Body);
  finally
    Body.Free;
  end;

  // Re-read to confirm the update took effect
  Obj := SupabaseGet(BuildUrl(TableName('entitlements'),
    'entitlement_id=eq.' + TNetEncoding.URL.Encode(AEntitlementId)));
  if Assigned(Obj) then
  try
    AEntitlement := ParseEntitlement(Obj);
  finally
    Obj.Free;
  end;
  Result := True;

  if AEntitlement.RemainingQuota = 0 then
  begin
    Body := TJSONObject.Create;
    try
      Body.AddPair('status', 'consumed');
      SupabasePatch(BuildUrl(TableName('entitlements'),
        'entitlement_id=eq.' + TNetEncoding.URL.Encode(AEntitlementId)), Body);
    finally
      Body.Free;
    end;
    AEntitlement.Status := cesConsumed;
  end;
end;

end.
