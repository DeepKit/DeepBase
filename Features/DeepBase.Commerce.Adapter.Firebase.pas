unit DeepBase.Commerce.Adapter.Firebase;

{==============================================================================
  DeepBase.Commerce.Adapter.Firebase - Firebase Firestore Storage Adapter

  ICommerceStorage implementation using Firebase Firestore REST API.
  Maps Commerce records to Firestore documents in configurable collections.

  Usage:
    Storage := TFirebaseCommerceStorage.Create(
      'my-project', 'eyJhbG...', 'commerce_');
    Service := TDeepBaseCommerceService.Create(Storage);

  Collection naming: uses configurable prefix (default 'commerce_').
  Example: commerce_users, commerce_orders, commerce_payments, etc.

  Firestore document IDs use the entity's primary key (e.g. user_id, order_id).
  Composite key lookups use Firestore queries with structured queries.
==============================================================================}

interface

uses
  System.Classes,
  System.SysUtils,
  System.JSON,
  System.Generics.Collections,
  System.Net.HttpClient,
  System.Net.URLClient,
  System.NetEncoding,
  DeepBase.Commerce.Types,
  DeepBase.Commerce.Storage;

type
  TFirebaseConfig = record
    ProjectId: string;
    AccessToken: string;
    CollectionPrefix: string;
    TimeoutMs: Integer;
    AllowServerOnlyPrototype: Boolean;
    class function Create(const AProjectId, AAccessToken: string;
      const ACollectionPrefix: string = 'commerce_';
      ATimeoutMs: Integer = 15000;
      AAllowServerOnlyPrototype: Boolean = False): TFirebaseConfig; static;
    class function CreateServerOnly(const AProjectId, AAccessToken: string;
      const ACollectionPrefix: string = 'commerce_';
      ATimeoutMs: Integer = 15000): TFirebaseConfig; static;
  end;

  TFirebaseCommerceStorage = class(TInterfacedObject, ICommerceStorage)
  private
    FConfig: TFirebaseConfig;
    FClient: THTTPClient;
    function CollectionPath(const AName: string): string;
    function DocUrl(const ACollection, ADocId: string): string;
    function QueryUrl(const ACollection: string): string;
    function AuthHeaders: TNetHeaders;
    function FirestoreGet(const AUrl: string): TJSONObject;
    function FirestorePatch(const AUrl: string; ABody: TJSONObject): TJSONObject;
    function FirestoreQuery(const ACollection: string;
      AQuery: TJSONObject): TJSONArray;
    function ExtractFields(Obj: TJSONObject): TJSONObject;
    function StrField(Fields: TJSONObject; const AKey: string): string;
    function Int64Field(Fields: TJSONObject; const AKey: string): Int64;
    function IntField(Fields: TJSONObject; const AKey: string): Integer;
    function BoolField(Fields: TJSONObject; const AKey: string): Boolean;
    function WrapValue(const AValue: string): TJSONObject; overload;
    function WrapValue(AValue: Int64): TJSONObject; overload;
    function WrapValue(AValue: Integer): TJSONObject; overload;
    function WrapValue(AValue: Boolean): TJSONObject; overload;
    function ParseUser(Fields: TJSONObject): TCommerceUserData;
    function ParseOrder(Fields: TJSONObject): TCommerceOrderData;
    function ParsePayment(Fields: TJSONObject): TCommercePaymentData;
    function ParseProduct(Fields: TJSONObject): TCommerceProductData;
    function ParseEntitlement(Fields: TJSONObject): TCommerceEntitlementData;
    function UserToFields(const AUser: TCommerceUserData): TJSONObject;
    function OrderToFields(const AOrder: TCommerceOrderData): TJSONObject;
    function PaymentToFields(const APayment: TCommercePaymentData): TJSONObject;
    function ProductToFields(const AProduct: TCommerceProductData): TJSONObject;
    function EntitlementToFields(const AEntitlement: TCommerceEntitlementData): TJSONObject;
    function MakeFieldFilter(const AField, AOp, AValue: string): TJSONObject;
  public
    constructor Create(const AConfig: TFirebaseConfig);
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

{ TFirebaseConfig }

class function TFirebaseConfig.Create(const AProjectId, AAccessToken: string;
  const ACollectionPrefix: string; ATimeoutMs: Integer;
  AAllowServerOnlyPrototype: Boolean): TFirebaseConfig;
begin
  Result.ProjectId := AProjectId;
  Result.AccessToken := AAccessToken;
  Result.CollectionPrefix := ACollectionPrefix;
  Result.TimeoutMs := ATimeoutMs;
  Result.AllowServerOnlyPrototype := AAllowServerOnlyPrototype;
end;

class function TFirebaseConfig.CreateServerOnly(const AProjectId,
  AAccessToken: string; const ACollectionPrefix: string;
  ATimeoutMs: Integer): TFirebaseConfig;
begin
  Result := Create(AProjectId, AAccessToken, ACollectionPrefix, ATimeoutMs,
    True);
end;

{ TFirebaseCommerceStorage }

constructor TFirebaseCommerceStorage.Create(const AConfig: TFirebaseConfig);
begin
  inherited Create;
  if not AConfig.AllowServerOnlyPrototype and
     (not SameText(GetEnvironmentVariable(
       'DEEPBASE_ALLOW_PROTOTYPE_COMMERCE_ADAPTERS'), '1')) then
    raise EDeepBaseCommerceValidationError.Create(
      'TFirebaseCommerceStorage is server-only/prototype. Desktop production clients must use safe backend APIs (for example TDeepKitSafeClient) instead of direct Firebase adapter.');

  FConfig := AConfig;
  FClient := THTTPClient.Create;
  FClient.ConnectionTimeout := FConfig.TimeoutMs;
  FClient.ResponseTimeout := FConfig.TimeoutMs;
end;

destructor TFirebaseCommerceStorage.Destroy;
begin
  FreeAndNil(FClient);
  inherited;
end;

function TFirebaseCommerceStorage.CollectionPath(const AName: string): string;
begin
  Result := 'projects/' + FConfig.ProjectId + '/databases/(default)/documents/' +
    FConfig.CollectionPrefix + AName;
end;

function TFirebaseCommerceStorage.DocUrl(const ACollection, ADocId: string): string;
begin
  Result := 'https://firestore.googleapis.com/v1/' +
    CollectionPath(ACollection) + '/' + TNetEncoding.URL.Encode(ADocId);
end;

function TFirebaseCommerceStorage.QueryUrl(const ACollection: string): string;
begin
  Result := 'https://firestore.googleapis.com/v1/' +
    CollectionPath(ACollection) + ':runQuery';
end;

function TFirebaseCommerceStorage.AuthHeaders: TNetHeaders;
begin
  Result := [
    TNetHeader.Create('Authorization', 'Bearer ' + FConfig.AccessToken),
    TNetHeader.Create('Content-Type', 'application/json')
  ];
end;

function TFirebaseCommerceStorage.FirestoreGet(const AUrl: string): TJSONObject;
var
  Response: IHTTPResponse;
begin
  Response := FClient.Get(AUrl, nil, AuthHeaders);
  if Response.StatusCode = 404 then
    Exit(nil);
  if Response.StatusCode >= 300 then
    raise EDeepBaseCommerceError.CreateFmt('Firestore GET %s: %d',
      [AUrl, Response.StatusCode]);
  var LValue := TJSONObject.ParseJSONValue(Response.ContentAsString(TEncoding.UTF8));
  if not (LValue is TJSONObject) then
  begin
    LValue.Free;
    Exit(nil);
  end;
  Result := TJSONObject(LValue);
end;

function TFirebaseCommerceStorage.FirestorePatch(const AUrl: string;
  ABody: TJSONObject): TJSONObject;
var
  Response: IHTTPResponse;
  BodyStream: TStringStream;
begin
  BodyStream := TStringStream.Create(ABody.ToJSON, TEncoding.UTF8);
  try
    Response := FClient.Patch(
      AUrl + '?updateMask.fieldPaths=', BodyStream, nil, AuthHeaders);
  finally
    BodyStream.Free;
  end;
  if Response.StatusCode >= 300 then
    raise EDeepBaseCommerceError.CreateFmt('Firestore PATCH: %d', [Response.StatusCode]);
  var LValue := TJSONObject.ParseJSONValue(Response.ContentAsString(TEncoding.UTF8));
  if not (LValue is TJSONObject) then
  begin
    LValue.Free;
    Exit(nil);
  end;
  Result := TJSONObject(LValue);
end;


function TFirebaseCommerceStorage.FirestoreQuery(const ACollection: string;
  AQuery: TJSONObject): TJSONArray;
var
  Response: IHTTPResponse;
  Wrapper: TJSONObject;
begin
  Wrapper := TJSONObject.Create;
  Wrapper.AddPair('structuredQuery', AQuery);
  try
    Response := FClient.Post(QueryUrl(ACollection), Wrapper.ToJSON, nil, AuthHeaders);
  finally
    Wrapper.Free;
  end;
  var LValue := TJSONObject.ParseJSONValue(Response.ContentAsString(TEncoding.UTF8));
  if not (LValue is TJSONArray) then
  begin
    LValue.Free;
    Exit(nil);
  end;
  Result := TJSONArray(LValue);
end;

function TFirebaseCommerceStorage.ExtractFields(Obj: TJSONObject): TJSONObject;
begin
  if Obj.TryGetValue<TJSONObject>('fields', Result) then
    Exit;
  Result := nil;
end;

function TFirebaseCommerceStorage.StrField(Fields: TJSONObject;
  const AKey: string): string;
var
  Fld: TJSONObject;
begin
  if Fields.TryGetValue<TJSONObject>(AKey, Fld) then
  begin
    if Fld.TryGetValue<string>('stringValue', Result) then
      Exit;
  end;
  Result := '';
end;

function TFirebaseCommerceStorage.Int64Field(Fields: TJSONObject;
  const AKey: string): Int64;
var
  Fld: TJSONObject;
  S: string;
begin
  if Fields.TryGetValue<TJSONObject>(AKey, Fld) then
  begin
    if Fld.TryGetValue<string>('integerValue', S) then
      Exit(StrToInt64Def(S, 0));
  end;
  Result := 0;
end;

function TFirebaseCommerceStorage.IntField(Fields: TJSONObject;
  const AKey: string): Integer;
var
  Fld: TJSONObject;
  S: string;
begin
  if Fields.TryGetValue<TJSONObject>(AKey, Fld) then
  begin
    if Fld.TryGetValue<string>('integerValue', S) then
      Exit(StrToIntDef(S, 0));
  end;
  Result := 0;
end;

function TFirebaseCommerceStorage.BoolField(Fields: TJSONObject;
  const AKey: string): Boolean;
var
  Fld: TJSONObject;
  S: string;
begin
  if Fields.TryGetValue<TJSONObject>(AKey, Fld) then
  begin
    if Fld.TryGetValue<string>('booleanValue', S) then
      Exit(SameText(S, 'true'));
  end;
  Result := False;
end;

function TFirebaseCommerceStorage.WrapValue(const AValue: string): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('stringValue', AValue);
end;

function TFirebaseCommerceStorage.WrapValue(AValue: Int64): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('integerValue', IntToStr(AValue));
end;

function TFirebaseCommerceStorage.WrapValue(AValue: Integer): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('integerValue', IntToStr(AValue));
end;

function TFirebaseCommerceStorage.WrapValue(AValue: Boolean): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('booleanValue', TJSONBool.Create(AValue));
end;

{ Firestore field filters }

function TFirebaseCommerceStorage.MakeFieldFilter(
  const AField, AOp, AValue: string): TJSONObject;
var
  Filter: TJSONObject;
begin
  Filter := TJSONObject.Create;
  Filter.AddPair('field', TJSONObject.Create.AddPair('fieldPath', AField));
  Filter.AddPair('op', AOp);
  Filter.AddPair('value', TJSONObject.Create.AddPair('stringValue', AValue));
  Result := TJSONObject.Create;
  Result.AddPair('fieldFilter', Filter);
end;

{ Record parsers }

function TFirebaseCommerceStorage.ParseUser(Fields: TJSONObject): TCommerceUserData;
begin
  Result.UserId := StrField(Fields, 'user_id');
  Result.DisplayName := StrField(Fields, 'display_name');
  Result.Email := StrField(Fields, 'email');
  Result.Phone := StrField(Fields, 'phone');
  Result.IsActive := BoolField(Fields, 'is_active');
  Result.CreatedAtISO := StrField(Fields, 'created_at');
  Result.UpdatedAtISO := StrField(Fields, 'updated_at');
end;

function TFirebaseCommerceStorage.ParseOrder(Fields: TJSONObject): TCommerceOrderData;
begin
  Result.OrderId := StrField(Fields, 'order_id');
  Result.UserId := StrField(Fields, 'user_id');
  Result.AppId := StrField(Fields, 'app_id');
  Result.ProductId := StrField(Fields, 'product_id');
  Result.OutTradeNo := StrField(Fields, 'out_trade_no');
  Result.Title := StrField(Fields, 'title');
  Result.AmountMinor := Int64Field(Fields, 'amount_minor');
  Result.Currency := StrField(Fields, 'currency');
  Result.CreatedAtISO := StrField(Fields, 'created_at');
  Result.PaidAtISO := StrField(Fields, 'paid_at');
end;

function TFirebaseCommerceStorage.ParsePayment(Fields: TJSONObject): TCommercePaymentData;
begin
  Result.PaymentId := StrField(Fields, 'payment_id');
  Result.OrderId := StrField(Fields, 'order_id');
  Result.ProviderTradeNo := StrField(Fields, 'provider_trade_no');
  Result.PrepayId := StrField(Fields, 'prepay_id');
  Result.RawPayload := StrField(Fields, 'raw_payload');
  Result.Provider := StrToCommercePaymentProvider(StrField(Fields, 'provider'));
  Result.Channel := StrToCommercePaymentChannel(StrField(Fields, 'channel'));
  Result.Status := StrToCommercePaymentStatus(StrField(Fields, 'status'));
  Result.CreatedAtISO := StrField(Fields, 'created_at');
  Result.PaidAtISO := StrField(Fields, 'paid_at');
end;

function TFirebaseCommerceStorage.ParseProduct(Fields: TJSONObject): TCommerceProductData;
begin
  Result.ProductId := StrField(Fields, 'product_id');
  Result.AppId := StrField(Fields, 'app_id');
  Result.Name := StrField(Fields, 'name');
  Result.Description := StrField(Fields, 'description');
  Result.AmountMinor := Int64Field(Fields, 'amount_minor');
  Result.Currency := StrField(Fields, 'currency');
  Result.EntitlementCode := StrField(Fields, 'entitlement_code');
  Result.EntitlementDurationDays := IntField(Fields, 'entitlement_duration_days');
  Result.InitialQuota := IntField(Fields, 'initial_quota');
  Result.Tier := StrField(Fields, 'tier');
  Result.MaxDevices := IntField(Fields, 'max_devices');
  Result.OfflineGraceDays := IntField(Fields, 'offline_grace_days');
  Result.IsActive := BoolField(Fields, 'is_active');
end;

function TFirebaseCommerceStorage.ParseEntitlement(Fields: TJSONObject): TCommerceEntitlementData;
begin
  Result.EntitlementId := StrField(Fields, 'entitlement_id');
  Result.UserId := StrField(Fields, 'user_id');
  Result.AppId := StrField(Fields, 'app_id');
  Result.ProductId := StrField(Fields, 'product_id');
  Result.Code := StrField(Fields, 'code');
  Result.Status := StrToCommerceEntitlementStatus(StrField(Fields, 'status'));
  Result.ValidFromISO := StrField(Fields, 'valid_from');
  Result.ValidUntilISO := StrField(Fields, 'valid_until');
  Result.RemainingQuota := IntField(Fields, 'remaining_quota');
  Result.SourceOrderId := StrField(Fields, 'source_order_id');
end;

{ Record serializers }

function TFirebaseCommerceStorage.UserToFields(const AUser: TCommerceUserData): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('user_id', WrapValue(AUser.UserId));
  Result.AddPair('display_name', WrapValue(AUser.DisplayName));
  Result.AddPair('email', WrapValue(AUser.Email));
  Result.AddPair('phone', WrapValue(AUser.Phone));
  Result.AddPair('is_active', WrapValue(AUser.IsActive));
  Result.AddPair('created_at', WrapValue(AUser.CreatedAtISO));
  Result.AddPair('updated_at', WrapValue(AUser.UpdatedAtISO));
end;

function TFirebaseCommerceStorage.OrderToFields(const AOrder: TCommerceOrderData): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('order_id', WrapValue(AOrder.OrderId));
  Result.AddPair('user_id', WrapValue(AOrder.UserId));
  Result.AddPair('app_id', WrapValue(AOrder.AppId));
  Result.AddPair('product_id', WrapValue(AOrder.ProductId));
  Result.AddPair('out_trade_no', WrapValue(AOrder.OutTradeNo));
  Result.AddPair('title', WrapValue(AOrder.Title));
  Result.AddPair('amount_minor', WrapValue(AOrder.AmountMinor));
  Result.AddPair('currency', WrapValue(AOrder.Currency));
  Result.AddPair('status', WrapValue(CommerceOrderStatusToStr(AOrder.Status)));
  Result.AddPair('created_at', WrapValue(AOrder.CreatedAtISO));
  Result.AddPair('paid_at', WrapValue(AOrder.PaidAtISO));
end;

function TFirebaseCommerceStorage.PaymentToFields(
  const APayment: TCommercePaymentData): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('payment_id', WrapValue(APayment.PaymentId));
  Result.AddPair('order_id', WrapValue(APayment.OrderId));
  Result.AddPair('provider', WrapValue(CommercePaymentProviderToStr(APayment.Provider)));
  Result.AddPair('channel', WrapValue(CommercePaymentChannelToStr(APayment.Channel)));
  Result.AddPair('provider_trade_no', WrapValue(APayment.ProviderTradeNo));
  Result.AddPair('prepay_id', WrapValue(APayment.PrepayId));
  Result.AddPair('status', WrapValue(CommercePaymentStatusToStr(APayment.Status)));
  Result.AddPair('raw_payload', WrapValue(APayment.RawPayload));
  Result.AddPair('created_at', WrapValue(APayment.CreatedAtISO));
  Result.AddPair('paid_at', WrapValue(APayment.PaidAtISO));
end;

function TFirebaseCommerceStorage.ProductToFields(
  const AProduct: TCommerceProductData): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('product_id', WrapValue(AProduct.ProductId));
  Result.AddPair('app_id', WrapValue(AProduct.AppId));
  Result.AddPair('name', WrapValue(AProduct.Name));
  Result.AddPair('description', WrapValue(AProduct.Description));
  Result.AddPair('amount_minor', WrapValue(AProduct.AmountMinor));
  Result.AddPair('currency', WrapValue(AProduct.Currency));
  Result.AddPair('entitlement_code', WrapValue(AProduct.EntitlementCode));
  Result.AddPair('entitlement_duration_days', WrapValue(AProduct.EntitlementDurationDays));
  Result.AddPair('initial_quota', WrapValue(AProduct.InitialQuota));
  Result.AddPair('tier', WrapValue(AProduct.Tier));
  Result.AddPair('max_devices', WrapValue(AProduct.MaxDevices));
  Result.AddPair('offline_grace_days', WrapValue(AProduct.OfflineGraceDays));
  Result.AddPair('is_active', WrapValue(AProduct.IsActive));
end;

function TFirebaseCommerceStorage.EntitlementToFields(
  const AEntitlement: TCommerceEntitlementData): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('entitlement_id', WrapValue(AEntitlement.EntitlementId));
  Result.AddPair('user_id', WrapValue(AEntitlement.UserId));
  Result.AddPair('app_id', WrapValue(AEntitlement.AppId));
  Result.AddPair('product_id', WrapValue(AEntitlement.ProductId));
  Result.AddPair('code', WrapValue(AEntitlement.Code));
  Result.AddPair('status', WrapValue(CommerceEntitlementStatusToStr(AEntitlement.Status)));
  Result.AddPair('valid_from', WrapValue(AEntitlement.ValidFromISO));
  Result.AddPair('valid_until', WrapValue(AEntitlement.ValidUntilISO));
  Result.AddPair('remaining_quota', WrapValue(AEntitlement.RemainingQuota));
  Result.AddPair('source_order_id', WrapValue(AEntitlement.SourceOrderId));
end;

{ ICommerceStorage implementation }

function TFirebaseCommerceStorage.FindUserById(const AUserId: string;
  out AUser: TCommerceUserData): Boolean;
var
  Doc: TJSONObject;
  Fields: TJSONObject;
begin
  Doc := FirestoreGet(DocUrl('users', AUserId));
  Result := Assigned(Doc);
  if Result then
  try
    Fields := ExtractFields(Doc);
    if Assigned(Fields) then
      AUser := ParseUser(Fields);
  finally
    Doc.Free;
  end;
end;

function TFirebaseCommerceStorage.FindUserByIdentity(AProvider: TCommerceAuthProvider;
  const AProviderUserId, AAppId: string; out AUser: TCommerceUserData): Boolean;
var
  Query, From, Where: TJSONObject;
  Results: TJSONArray;
  Doc: TJSONObject;
  Fields: TJSONObject;
  I: Integer;
begin
  Result := False;
  From := TJSONObject.Create;
  From.AddPair('collectionId', 'identities');

  Where := TJSONObject.Create;
  Where.AddPair('compositeFilter', TJSONObject.Create
    .AddPair('op', 'AND')
    .AddPair('filters', TJSONArray.Create
      .Add(MakeFieldFilter('provider', 'EQUAL', CommerceAuthProviderToStr(AProvider)))
      .Add(MakeFieldFilter('provider_user_id', 'EQUAL', AProviderUserId))
      .Add(MakeFieldFilter('app_id', 'EQUAL', AAppId))));

  Query := TJSONObject.Create;
  Query.AddPair('from', TJSONArray.Create.Add(From));
  Query.AddPair('where', Where);

  Results := FirestoreQuery('identities', Query);
  if Assigned(Results) then
  try
    for I := 0 to Results.Count - 1 do
    begin
      Doc := Results.Items[I] as TJSONObject;
      Fields := ExtractFields(Doc);
      if Assigned(Fields) then
      begin
        AUser.UserId := StrField(Fields, 'user_id');
        Exit(FindUserById(AUser.UserId, AUser));
      end;
    end;
  finally
    Results.Free;
  end;
end;

procedure TFirebaseCommerceStorage.UpsertUser(const AUser: TCommerceUserData);
var
  Body: TJSONObject;
begin
  Body := TJSONObject.Create;
  Body.AddPair('fields', UserToFields(AUser));
  try
    FirestorePatch(DocUrl('users', AUser.UserId), Body);
  finally
    Body.Free;
  end;
end;

procedure TFirebaseCommerceStorage.LinkIdentity(const AIdentity: TCommerceIdentityData);
var
  Body, Fields: TJSONObject;
  DocId: string;
begin
  Fields := TJSONObject.Create;
  Fields.AddPair('user_id', WrapValue(AIdentity.UserId));
  Fields.AddPair('provider', WrapValue(CommerceAuthProviderToStr(AIdentity.Provider)));
  Fields.AddPair('provider_user_id', WrapValue(AIdentity.ProviderUserId));
  Fields.AddPair('app_id', WrapValue(AIdentity.AppId));
  Fields.AddPair('union_id', WrapValue(AIdentity.UnionId));
  Fields.AddPair('created_at', WrapValue(AIdentity.CreatedAtISO));

  DocId := AIdentity.UserId + '_' + CommerceAuthProviderToStr(AIdentity.Provider);
  Body := TJSONObject.Create;
  Body.AddPair('fields', Fields);
  try
    FirestorePatch(DocUrl('identities', DocId), Body);
  finally
    Body.Free;
  end;
end;

function TFirebaseCommerceStorage.FindProduct(const AAppId, AProductId: string;
  out AProduct: TCommerceProductData): Boolean;
var
  Doc: TJSONObject;
  Fields: TJSONObject;
begin
  Doc := FirestoreGet(DocUrl('products', AAppId + '_' + AProductId));
  Result := Assigned(Doc);
  if Result then
  try
    Fields := ExtractFields(Doc);
    if Assigned(Fields) then
      AProduct := ParseProduct(Fields);
  finally
    Doc.Free;
  end;
end;

procedure TFirebaseCommerceStorage.UpsertProduct(const AProduct: TCommerceProductData);
var
  Body: TJSONObject;
begin
  Body := TJSONObject.Create;
  Body.AddPair('fields', ProductToFields(AProduct));
  try
    FirestorePatch(DocUrl('products', AProduct.AppId + '_' + AProduct.ProductId), Body);
  finally
    Body.Free;
  end;
end;

procedure TFirebaseCommerceStorage.CreateOrder(const AOrder: TCommerceOrderData);
var
  Body: TJSONObject;
begin
  Body := TJSONObject.Create;
  Body.AddPair('fields', OrderToFields(AOrder));
  try
    FirestorePatch(DocUrl('orders', AOrder.OrderId), Body);
  finally
    Body.Free;
  end;
end;

function TFirebaseCommerceStorage.FindOrderById(const AOrderId: string;
  out AOrder: TCommerceOrderData): Boolean;
var
  Doc: TJSONObject;
  Fields: TJSONObject;
begin
  Doc := FirestoreGet(DocUrl('orders', AOrderId));
  Result := Assigned(Doc);
  if Result then
  try
    Fields := ExtractFields(Doc);
    if Assigned(Fields) then
      AOrder := ParseOrder(Fields);
  finally
    Doc.Free;
  end;
end;

function TFirebaseCommerceStorage.FindOrderByOutTradeNo(const AOutTradeNo: string;
  out AOrder: TCommerceOrderData): Boolean;
var
  Query, From: TJSONObject;
  Results: TJSONArray;
  Doc: TJSONObject;
  Fields: TJSONObject;
  I: Integer;
begin
  Result := False;
  From := TJSONObject.Create;
  From.AddPair('collectionId', 'orders');

  Query := TJSONObject.Create;
  Query.AddPair('from', TJSONArray.Create.Add(From));
  Query.AddPair('where', MakeFieldFilter('out_trade_no', 'EQUAL', AOutTradeNo));

  Results := FirestoreQuery('orders', Query);
  if Assigned(Results) then
  try
    for I := 0 to Results.Count - 1 do
    begin
      Doc := Results.Items[I] as TJSONObject;
      Fields := ExtractFields(Doc);
      if Assigned(Fields) then
      begin
        AOrder := ParseOrder(Fields);
        Exit(True);
      end;
    end;
  finally
    Results.Free;
  end;
end;

procedure TFirebaseCommerceStorage.UpdateOrder(const AOrder: TCommerceOrderData);
var
  Body: TJSONObject;
begin
  Body := TJSONObject.Create;
  Body.AddPair('fields', OrderToFields(AOrder));
  try
    FirestorePatch(DocUrl('orders', AOrder.OrderId), Body);
  finally
    Body.Free;
  end;
end;

procedure TFirebaseCommerceStorage.CreatePayment(const APayment: TCommercePaymentData);
var
  Body: TJSONObject;
begin
  Body := TJSONObject.Create;
  Body.AddPair('fields', PaymentToFields(APayment));
  try
    FirestorePatch(DocUrl('payments', APayment.PaymentId), Body);
  finally
    Body.Free;
  end;
end;

function TFirebaseCommerceStorage.FindPaymentByOrderId(const AOrderId: string;
  out APayment: TCommercePaymentData): Boolean;
var
  Query, From: TJSONObject;
  Results: TJSONArray;
  Doc: TJSONObject;
  Fields: TJSONObject;
  I: Integer;
begin
  Result := False;
  From := TJSONObject.Create;
  From.AddPair('collectionId', 'payments');

  Query := TJSONObject.Create;
  Query.AddPair('from', TJSONArray.Create.Add(From));
  Query.AddPair('where', MakeFieldFilter('order_id', 'EQUAL', AOrderId));

  Results := FirestoreQuery('payments', Query);
  if Assigned(Results) then
  try
    for I := 0 to Results.Count - 1 do
    begin
      Doc := Results.Items[I] as TJSONObject;
      Fields := ExtractFields(Doc);
      if Assigned(Fields) then
      begin
        APayment := ParsePayment(Fields);
        Exit(True);
      end;
    end;
  finally
    Results.Free;
  end;
end;

procedure TFirebaseCommerceStorage.UpdatePayment(const APayment: TCommercePaymentData);
var
  Body: TJSONObject;
begin
  Body := TJSONObject.Create;
  Body.AddPair('fields', PaymentToFields(APayment));
  try
    FirestorePatch(DocUrl('payments', APayment.PaymentId), Body);
  finally
    Body.Free;
  end;
end;

procedure TFirebaseCommerceStorage.UpsertEntitlement(
  const AEntitlement: TCommerceEntitlementData);
var
  Body: TJSONObject;
begin
  Body := TJSONObject.Create;
  Body.AddPair('fields', EntitlementToFields(AEntitlement));
  try
    FirestorePatch(DocUrl('entitlements', AEntitlement.EntitlementId), Body);
  finally
    Body.Free;
  end;
end;

function TFirebaseCommerceStorage.ListEntitlements(
  const AUserId, AAppId: string): TCommerceEntitlementArray;
var
  Query, From, Where: TJSONObject;
  Results: TJSONArray;
  Doc: TJSONObject;
  Fields: TJSONObject;
  I: Integer;
  List: TList<TCommerceEntitlementData>;
begin
  From := TJSONObject.Create;
  From.AddPair('collectionId', 'entitlements');

  Where := TJSONObject.Create;
  Where.AddPair('compositeFilter', TJSONObject.Create
    .AddPair('op', 'AND')
    .AddPair('filters', TJSONArray.Create
      .Add(MakeFieldFilter('user_id', 'EQUAL', AUserId))
      .Add(MakeFieldFilter('app_id', 'EQUAL', AAppId))));

  Query := TJSONObject.Create;
  Query.AddPair('from', TJSONArray.Create.Add(From));
  Query.AddPair('where', Where);

  List := TList<TCommerceEntitlementData>.Create;
  Results := FirestoreQuery('entitlements', Query);
  try
    if Assigned(Results) then
      for I := 0 to Results.Count - 1 do
      begin
        Doc := Results.Items[I] as TJSONObject;
        Fields := ExtractFields(Doc);
        if Assigned(Fields) then
          List.Add(ParseEntitlement(Fields));
      end;
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

function TFirebaseCommerceStorage.FindEntitlement(const AUserId, AAppId,
  ACode: string; out AEntitlement: TCommerceEntitlementData): Boolean;
var
  Query, From, Where: TJSONObject;
  Results: TJSONArray;
  Doc: TJSONObject;
  Fields: TJSONObject;
  I: Integer;
begin
  Result := False;
  From := TJSONObject.Create;
  From.AddPair('collectionId', 'entitlements');

  Where := TJSONObject.Create;
  Where.AddPair('compositeFilter', TJSONObject.Create
    .AddPair('op', 'AND')
    .AddPair('filters', TJSONArray.Create
      .Add(MakeFieldFilter('user_id', 'EQUAL', AUserId))
      .Add(MakeFieldFilter('app_id', 'EQUAL', AAppId))
      .Add(MakeFieldFilter('code', 'EQUAL', ACode))));

  Query := TJSONObject.Create;
  Query.AddPair('from', TJSONArray.Create.Add(From));
  Query.AddPair('where', Where);

  Results := FirestoreQuery('entitlements', Query);
  if Assigned(Results) then
  try
    for I := 0 to Results.Count - 1 do
    begin
      Doc := Results.Items[I] as TJSONObject;
      Fields := ExtractFields(Doc);
      if Assigned(Fields) then
      begin
        AEntitlement := ParseEntitlement(Fields);
        Exit(True);
      end;
    end;
  finally
    Results.Free;
  end;
end;

function TFirebaseCommerceStorage.ConsumeEntitlement(const AEntitlementId: string;
  ACount: Integer; out AEntitlement: TCommerceEntitlementData): Boolean;
var
  Doc: TJSONObject;
  Fields: TJSONObject;
  NewQuota: Integer;
  Body: TJSONObject;
begin
  // NOTE: Firestore REST API does not support atomic read-modify-write transactions.
  // For production, use the backend HTTP adapter (TDeepKitSafeClient) which can run
  // Firestore transactions server-side. This implementation is safe for single-instance
  // deployments but may race under concurrent consumers.
  Doc := FirestoreGet(DocUrl('entitlements', AEntitlementId));
  if not Assigned(Doc) then
    Exit(False);
  try
    Fields := ExtractFields(Doc);
    if not Assigned(Fields) then
      Exit(False);

    AEntitlement := ParseEntitlement(Fields);
    if AEntitlement.Status <> cesActive then
      Exit(False);

    // Unlimited quota (-1): skip deduction, always succeed
    if AEntitlement.RemainingQuota < 0 then
      Exit(True);

    if AEntitlement.RemainingQuota < ACount then
      Exit(False);
  finally
    Doc.Free;
  end;

  NewQuota := AEntitlement.RemainingQuota - ACount;

  Body := TJSONObject.Create;
  Body.AddPair('fields', TJSONObject.Create
    .AddPair('remaining_quota', WrapValue(NewQuota)));
  try
    FirestorePatch(DocUrl('entitlements', AEntitlementId), Body);
  finally
    Body.Free;
  end;
  AEntitlement.RemainingQuota := NewQuota;
  if NewQuota = 0 then
  begin
    AEntitlement.Status := cesConsumed;
    Body := TJSONObject.Create;
    Body.AddPair('fields', TJSONObject.Create
      .AddPair('status', WrapValue('consumed')));
    try
      FirestorePatch(DocUrl('entitlements', AEntitlementId), Body);
    finally
      Body.Free;
    end;
  end;
  Result := True;
end;

end.
