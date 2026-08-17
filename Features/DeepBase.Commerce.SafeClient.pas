unit DeepBase.Commerce.SafeClient;

interface

uses
  System.SysUtils,
  System.JSON,
  System.Net.URLClient,
  DeepBase.Commerce.Types,
  DeepBase.Commerce.Backend.Http,
  DeepBase.Commerce.Backend.Contract,
  DeepBase.Commerce.JsonUtil,
  DeepBase.Commerce.Idempotency;

const
  SDeepKitRouteAuthLogin = '/auth/login';
  SDeepKitRouteAuthRefresh = '/auth/refresh';
  SDeepKitRouteAuthLogout = '/auth/logout';
  SDeepKitRouteAuthMe = '/auth/me';

  SDeepKitRouteLicenseSnapshotIssue = '/license/snapshot/issue';
  SDeepKitRouteLicenseSnapshotRefresh = '/license/snapshot/refresh';
  SDeepKitRouteUpdatesManifest = '/updates/manifest';

  SDeepKitFieldLoginType = 'login_type';
  SDeepKitFieldDeviceId = 'device_id';
  SDeepKitFieldDeviceFingerprint = 'device_fingerprint';
  SDeepKitFieldAccessToken = 'access_token';
  SDeepKitFieldRefreshToken = 'refresh_token';
  SDeepKitFieldExpiresIn = 'expires_in';

  SDeepKitFieldSnapshotId = 'snapshot_id';
  SDeepKitFieldIssuedAt = 'issued_at';
  SDeepKitFieldExpiresAt = 'expires_at';
  SDeepKitFieldPayload = 'payload';
  SDeepKitFieldSignature = 'signature';
  SDeepKitFieldKeyId = 'key_id';
  SDeepKitFieldSchemaVersion = 'schema_version';
  SDeepKitFieldRevocationVersion = 'revocation_version';

  SDeepKitFieldProducts = 'products';
  SDeepKitFieldLatestVersion = 'latest_version';
  SDeepKitFieldCurrentVersion = 'current_version';
  SDeepKitFieldMinVersion = 'min_version';
  SDeepKitFieldManifestUrl = 'manifest_url';
  SDeepKitFieldPackageUrl = 'package_url';
  SDeepKitFieldPackageHash = 'package_hash';
  SDeepKitFieldForceUpdate = 'force_update';
  SDeepKitFieldReleaseNotes = 'release_notes';
  SDeepKitFieldFeatureCode = 'feature_code';
  SDeepKitFieldQuantity = 'quantity';
  SDeepKitFieldRequestId = 'request_id';
  SDeepKitFieldConsumedQuantity = 'consumed_quantity';
  SDeepKitFieldServerTime = 'server_time';

  // Invite / Referral routes
  SDeepKitRouteInviteGenerate = '/invite/generate';
  SDeepKitRouteInviteApply    = '/invite/apply';
  SDeepKitRouteInviteStatus   = '/invite/status';

  SDeepKitFieldInviteCode      = 'invite_code';
  SDeepKitFieldInviteCount     = 'invite_count';
  SDeepKitFieldTotalRewardDays = 'total_reward_days';
  SDeepKitFieldRewardDays      = 'reward_days';

type
  TDeepKitLicenseSnapshotVerifier = reference to function(
    const APayload, ASignature, AKeyId, AAppId, ADeviceId: string): Boolean;

  TDeepKitLicenseSnapshotPublicKey = record
    KeyId: string;
    PublicKeyPEM: string;
  end;

  TDeepKitSafeClientConfig = record
    BaseUrl: string;
    RoutePrefix: string;
    BearerToken: string;
    ApiKey: string;
    TimeoutMs: Integer;
    LicenseSnapshotVerifier: TDeepKitLicenseSnapshotVerifier;
    LicenseSnapshotPublicKeys: TArray<TDeepKitLicenseSnapshotPublicKey>;
    class function Create(const ABaseUrl: string;
      const ABearerToken: string = ''; const AApiKey: string = '';
      ATimeoutMs: Integer = 30000;
      const ARoutePrefix: string = '/dk'): TDeepKitSafeClientConfig; static;
    class function CreateDeepKit(const ABaseUrl: string;
      const ABearerToken: string = ''; const AApiKey: string = '';
      ATimeoutMs: Integer = 30000): TDeepKitSafeClientConfig; static;
  end;

  TDeepKitAuthSession = record
    UserId: string;
    AccessToken: string;
    RefreshToken: string;
    ExpiresIn: Integer;
  end;

  TDeepKitUserProfile = record
    UserId: string;
    DisplayName: string;
    Email: string;
    Phone: string;
    IsActive: Boolean;
  end;

  TDeepKitOrder = record
    OrderId: string;
    OutTradeNo: string;
    AppId: string;
    ProductId: string;
    AmountMinor: Int64;
    Currency: string;
    Status: TCommerceOrderStatus;
    CreatedAtISO: string;
    PaidAtISO: string;
  end;

  TDeepKitLicenseSnapshot = record
    SnapshotId: string;
    IssuedAtISO: string;
    ExpiresAtISO: string;
    Payload: string;
    Signature: string;
    KeyId: string;
    SchemaVersion: Integer;
    RevocationVersion: Integer;
  end;

  TDeepKitUpdateManifest = record
    AppId: string;
    CurrentVersion: string;
    Channel: string;
    LatestVersion: string;
    MinVersion: string;
    ManifestUrl: string;
    PackageUrl: string;
    PackageHash: string;
    Signature: string;
    ForceUpdate: Boolean;
    ReleaseNotes: string;
  end;

  TDeepKitConsumeEntitlementResult = record
    Ok: Boolean;
    EntitlementCode: string;
    RemainingQuota: Integer;
    ConsumedQuantity: Integer;
    ServerTimeISO: string;
  end;

  TDeepKitSafeClient = class
  private
    FConfig: TDeepKitSafeClientConfig;
    FTransport: ICommerceBackendHttpTransport;
    FRefreshToken: string;
    FRefreshing: Boolean;
    FTokenLock: TObject;
    FIdempotencyTracker: TIdempotencyNonceTracker;
    FMaxRetries: Integer;

    function ApplyRoutePrefix(const APath: string): string;
    function BuildUrl(const APath: string): string;
    function BuildQuery(const APairs: array of string): string;
    function BuildHeaders(const AIdempotencyKey: string = '';
      AIncludeAuth: Boolean = True): TNetHeaders;
    function SendJson(const AMethod, APath: string; ABody: TJSONObject = nil;
      const AIdempotencyKey: string = '';
      AIncludeAuth: Boolean = True): TCommerceBackendHttpResponse;
    function SendJsonInternal(const AMethod, APath: string;
      ABody: TJSONObject; const AIdempotencyKey: string;
      AIncludeAuth: Boolean): TCommerceBackendHttpResponse;
    function IsRetriableStatus(AStatusCode: Integer): Boolean;
    function IsIdempotentCall(const AMethod, AIdempotencyKey: string): Boolean;
    function ExtractRetryAfterMs(const AHeaders: TNetHeaders;
      out ARetryMs: Integer): Boolean;
    function ComputeBackoffMs(AAttempt: Integer): Integer;
    procedure EnsureSuccess(const AMethod, APath: string;
      const AResponse: TCommerceBackendHttpResponse);
    function ParseObjectResponse(const AMethod, APath: string;
      const AResponse: TCommerceBackendHttpResponse): TJSONObject;
    procedure ValidateLicenseSnapshot(const ASnapshot: TDeepKitLicenseSnapshot;
      const AAppId, ADeviceId: string);
    function TryRefreshToken: Boolean;
  public
    constructor Create(const AConfig: TDeepKitSafeClientConfig;
      const ATransport: ICommerceBackendHttpTransport = nil);
    destructor Destroy; override;

    procedure SetAccessToken(const AAccessToken: string);
    function GetAccessToken: string;
    procedure SetRefreshToken(const AToken: string);
    function GetRefreshToken: string;

    function AuthLoginDeviceAnonymous(const AAppId, ADeviceId: string;
      const ADeviceFingerprint: string = ''): TDeepKitAuthSession;
    function AuthRefresh(const ARefreshToken: string): TDeepKitAuthSession;
    procedure AuthLogout(const ARefreshToken: string = '');
    function AuthMe: TDeepKitUserProfile;

    function EnsureUser(AProvider: TCommerceAuthProvider;
      const AProviderUserId, AAppId: string;
      const AUnionId: string = ''): TDeepKitUserProfile;
    function CreateOrder(const AUserId, AAppId, AProductId: string): TDeepKitOrder;
    function GetOrder(const AOrderId: string): TDeepKitOrder;
    function CloseOrder(const AOrderId: string): TDeepKitOrder;
    function CreatePaymentIntent(const AOrderId: string;
      AProvider: TCommercePaymentProvider; AChannel: TCommercePaymentChannel;
      const APayerOpenId: string = '';
      const AIdempotencyKey: string = ''): TCommercePaymentIntent;
    function ListProducts(const AAppId: string): TArray<TCommerceProductData>;
    function ListEntitlements(const AAppId: string): TCommerceEntitlementArray;
    function ConsumeEntitlement(const AAppId, AEntitlementCode,
      AFeatureCode: string; AQuantity: Integer;
      const ARequestId: string = ''): TDeepKitConsumeEntitlementResult;

    function IssueLicenseSnapshot(const AAppId, ADeviceId: string): TDeepKitLicenseSnapshot;
    function RefreshLicenseSnapshot(const AAppId, ADeviceId: string;
      const ASnapshotId: string = ''): TDeepKitLicenseSnapshot;
    function GetUpdatesManifest(const AAppId, ACurrentVersion,
      AChannel: string): TDeepKitUpdateManifest;

    // Invite / Referral methods
    function InviteGenerate(const AAppId: string): TJSONObject;
    function InviteApply(const AAppId, AInviteCode: string): TJSONObject;
    function InviteStatus(const AAppId: string): TJSONObject;
  end;

implementation

uses
  System.DateUtils,
  System.NetEncoding,
  System.Math,
  DeepBase.Crypto, DeepBase.Crypto.RSA
  {$IFDEF MSWINDOWS}, Winapi.Windows{$ENDIF};

const
  SHttpGet = 'GET';
  SHttpPost = 'POST';

  // BUG-428 FIX (E-005): retry policy for transient HTTP failures.
  // Applied only to idempotent requests (GET/HEAD or when an idempotency key
  // is supplied) so that non-idempotent operations (e.g. order creation) are
  // never retried. 429 honors Retry-After when the transport surfaces headers;
  // 5xx uses exponential backoff with jitter.
  DEFAULT_MAX_RETRIES = 3;
  BACKOFF_BASE_MS = 100;        // 2^attempt * BASE, capped
  BACKOFF_CAP_MS = 8000;       // never sleep longer than this between retries
  RETRY_AFTER_HEADER = 'Retry-After';

function DeepKitOrderFromJson(AJson: TJSONObject): TDeepKitOrder;
begin
  Result.OrderId := JsonValueAsString(AJson, SCommerceFieldOrderId, '');
  Result.OutTradeNo := JsonValueAsString(AJson, SCommerceFieldOutTradeNo, '');
  Result.AppId := JsonValueAsString(AJson, SCommerceFieldAppId, '');
  Result.ProductId := JsonValueAsString(AJson, SCommerceFieldProductId, '');
  Result.AmountMinor := JsonValueAsInt64(AJson, SCommerceFieldAmountMinor, 0);
  Result.Currency := JsonValueAsString(AJson, SCommerceFieldCurrency, '');
  Result.Status := OrderStatusFromString(JsonValueAsString(AJson,
    SCommerceFieldStatus, 'created'));
  Result.CreatedAtISO := JsonValueAsString(AJson, SCommerceFieldCreatedAt, '');
  Result.PaidAtISO := JsonValueAsString(AJson, SCommerceFieldPaidAt, '');
end;

function AuthSessionFromJson(AJson: TJSONObject): TDeepKitAuthSession;
begin
  Result.UserId := JsonValueAsString(AJson, SCommerceFieldUserId, '');
  Result.AccessToken := JsonValueAsString(AJson, SDeepKitFieldAccessToken, '');
  Result.RefreshToken := JsonValueAsString(AJson, SDeepKitFieldRefreshToken, '');
  Result.ExpiresIn := JsonValueAsInt(AJson, SDeepKitFieldExpiresIn, 0);
end;

function UserProfileFromJson(AJson: TJSONObject): TDeepKitUserProfile;
begin
  Result.UserId := JsonValueAsString(AJson, SCommerceFieldUserId, '');
  Result.DisplayName := JsonValueAsString(AJson, SCommerceFieldDisplayName, '');
  Result.Email := JsonValueAsString(AJson, SCommerceFieldEmail, '');
  Result.Phone := JsonValueAsString(AJson, SCommerceFieldPhone, '');
  Result.IsActive := JsonValueAsBool(AJson, SCommerceFieldIsActive, True);
end;

function LicenseSnapshotFromJson(AJson: TJSONObject): TDeepKitLicenseSnapshot;
var
  PayloadValue: TJSONValue;
begin
  Result.SnapshotId := JsonValueAsString(AJson, SDeepKitFieldSnapshotId, '');
  Result.IssuedAtISO := JsonValueAsString(AJson, SDeepKitFieldIssuedAt, '');
  Result.ExpiresAtISO := JsonValueAsString(AJson, SDeepKitFieldExpiresAt, '');
  Result.Signature := JsonValueAsString(AJson, SDeepKitFieldSignature, '');
  Result.KeyId := JsonValueAsString(AJson, SDeepKitFieldKeyId, '');
  Result.SchemaVersion := JsonValueAsInt(AJson, SDeepKitFieldSchemaVersion, 0);
  Result.RevocationVersion := JsonValueAsInt(AJson, SDeepKitFieldRevocationVersion, 0);
  PayloadValue := AJson.FindValue(SDeepKitFieldPayload);
  if not Assigned(PayloadValue) or (PayloadValue is TJSONNull) then
    Result.Payload := ''
  else if PayloadValue is TJSONObject then
    Result.Payload := TJSONObject(PayloadValue).ToJSON
  else
    Result.Payload := PayloadValue.Value;
end;

function UpdateManifestFromJson(AJson: TJSONObject): TDeepKitUpdateManifest;
begin
  Result.AppId := JsonValueAsString(AJson, SCommerceFieldAppId, '');
  Result.CurrentVersion := JsonValueAsString(AJson, SDeepKitFieldCurrentVersion, '');
  Result.Channel := JsonValueAsString(AJson, SCommerceFieldChannel, '');
  Result.LatestVersion := JsonValueAsString(AJson, SDeepKitFieldLatestVersion, '');
  if Result.LatestVersion = '' then
    Result.LatestVersion := JsonValueAsString(AJson, 'version', '');
  Result.MinVersion := JsonValueAsString(AJson, SDeepKitFieldMinVersion, '');
  Result.ManifestUrl := JsonValueAsString(AJson, SDeepKitFieldManifestUrl, '');
  Result.PackageUrl := JsonValueAsString(AJson, SDeepKitFieldPackageUrl, '');
  Result.PackageHash := JsonValueAsString(AJson, SDeepKitFieldPackageHash, '');
  Result.Signature := JsonValueAsString(AJson, SDeepKitFieldSignature, '');
  Result.ForceUpdate := JsonValueAsBool(AJson, SDeepKitFieldForceUpdate,
    JsonValueAsBool(AJson, 'is_mandatory', False));
  Result.ReleaseNotes := JsonValueAsString(AJson, SDeepKitFieldReleaseNotes, '');
end;

function SnapshotJsonField(const APayload, AFieldName: string): string;
var
  JsonValue: TJSONValue;
  JsonObject: TJSONObject;
begin
  Result := '';
  if Trim(APayload) = '' then
    Exit;

  JsonValue := TJSONObject.ParseJSONValue(APayload);
  try
    if JsonValue is TJSONObject then
    begin
      JsonObject := TJSONObject(JsonValue);
      Result := JsonValueAsString(JsonObject, AFieldName, '');
    end;
  finally
    JsonValue.Free;
  end;
end;

{ TDeepKitSafeClientConfig }

class function TDeepKitSafeClientConfig.Create(const ABaseUrl, ABearerToken,
  AApiKey: string; ATimeoutMs: Integer;
  const ARoutePrefix: string): TDeepKitSafeClientConfig;
begin
  Result.BaseUrl := ABaseUrl.Trim;
  Result.RoutePrefix := NormalizeRoutePrefix(ARoutePrefix);
  Result.BearerToken := ABearerToken;
  Result.ApiKey := AApiKey;
  Result.TimeoutMs := ATimeoutMs;
  Result.LicenseSnapshotVerifier := nil;
  Result.LicenseSnapshotPublicKeys := nil;
end;

class function TDeepKitSafeClientConfig.CreateDeepKit(const ABaseUrl,
  ABearerToken, AApiKey: string; ATimeoutMs: Integer): TDeepKitSafeClientConfig;
begin
  Result := Create(ABaseUrl, ABearerToken, AApiKey, ATimeoutMs, '/dk');
end;

{ TDeepKitSafeClient }

constructor TDeepKitSafeClient.Create(const AConfig: TDeepKitSafeClientConfig;
  const ATransport: ICommerceBackendHttpTransport);
begin
  inherited Create;
  if AConfig.BaseUrl = '' then
    raise EDeepBaseCommerceValidationError.Create('DeepKit SafeClient BaseUrl is required');

  FConfig := AConfig;
  FTransport := ATransport;
  if not Assigned(FTransport) then
    FTransport := TCommerceBackendHttpClientTransport.Create(AConfig.TimeoutMs);
  FRefreshToken := '';
  FRefreshing := False;
  FTokenLock := TObject.Create;
  FIdempotencyTracker := TIdempotencyNonceTracker.Create;
  FMaxRetries := DEFAULT_MAX_RETRIES;
end;

destructor TDeepKitSafeClient.Destroy;
begin
  FreeAndNil(FIdempotencyTracker);
  FreeAndNil(FTokenLock);
  inherited;
end;

procedure TDeepKitSafeClient.SetAccessToken(const AAccessToken: string);
begin
  TMonitor.Enter(FTokenLock);
  try
    FConfig.BearerToken := AAccessToken;
  finally
    TMonitor.Exit(FTokenLock);
  end;
end;

function TDeepKitSafeClient.GetAccessToken: string;
begin
  TMonitor.Enter(FTokenLock);
  try
    Result := FConfig.BearerToken;
  finally
    TMonitor.Exit(FTokenLock);
  end;
end;

procedure TDeepKitSafeClient.SetRefreshToken(const AToken: string);
begin
  TMonitor.Enter(FTokenLock);
  try
    FRefreshToken := AToken;
  finally
    TMonitor.Exit(FTokenLock);
  end;
end;

function TDeepKitSafeClient.GetRefreshToken: string;
begin
  TMonitor.Enter(FTokenLock);
  try
    Result := FRefreshToken;
  finally
    TMonitor.Exit(FTokenLock);
  end;
end;

function TDeepKitSafeClient.ApplyRoutePrefix(const APath: string): string;
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

function TDeepKitSafeClient.BuildUrl(const APath: string): string;
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

function TDeepKitSafeClient.BuildQuery(const APairs: array of string): string;
var
  I: Integer;
begin
  if Odd(Length(APairs)) then
    raise EArgumentNilException.Create('BuildQuery requires an even-length array of key-value pairs');
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

function TDeepKitSafeClient.BuildHeaders(const AIdempotencyKey: string;
  AIncludeAuth: Boolean): TNetHeaders;
var
  LToken, LApiKey: string;
begin
  TMonitor.Enter(FTokenLock);
  try
    LToken := FConfig.BearerToken;
    LApiKey := FConfig.ApiKey;
  finally
    TMonitor.Exit(FTokenLock);
  end;

  SetLength(Result, 0);
  AddHeader(Result, 'Accept', 'application/json');
  AddHeader(Result, 'Content-Type', 'application/json');
  if AIncludeAuth and (LToken <> '') then
    AddHeader(Result, 'Authorization', 'Bearer ' + LToken);
  if LApiKey <> '' then
    AddHeader(Result, 'X-API-Key', LApiKey);
  if AIdempotencyKey <> '' then
    AddHeader(Result, 'Idempotency-Key', AIdempotencyKey);
end;

function TDeepKitSafeClient.SendJsonInternal(const AMethod, APath: string;
  ABody: TJSONObject; const AIdempotencyKey: string;
  AIncludeAuth: Boolean): TCommerceBackendHttpResponse;
var
  BodyText: string;
begin
  if Assigned(ABody) then
    BodyText := ABody.ToJSON
  else
    BodyText := '';
  Result := FTransport.Send(AMethod, BuildUrl(APath), BodyText,
    BuildHeaders(AIdempotencyKey, AIncludeAuth));
end;

function TDeepKitSafeClient.SendJson(const AMethod, APath: string;
  ABody: TJSONObject; const AIdempotencyKey: string;
  AIncludeAuth: Boolean): TCommerceBackendHttpResponse;
var
  Attempt: Integer;
  RetryMs: Integer;
begin
  Result := SendJsonInternal(AMethod, APath, ABody, AIdempotencyKey, AIncludeAuth);

  // 401 — attempt a single token refresh + retry (auth path, unchanged).
  if AIncludeAuth and (Result.StatusCode = 401) then
  begin
    // Only retry on idempotent methods (GET/HEAD) or when an idempotency key
    // is provided. Retrying POST without an idempotency key could duplicate
    // non-idempotent operations like order creation.
    if IsIdempotentCall(AMethod, AIdempotencyKey) then
    begin
      TMonitor.Enter(FTokenLock);
      try
        if FRefreshToken = '' then
          Exit;

        if FRefreshing then
        begin
          // Another thread is refreshing — wait for it to finish, then retry.
          while FRefreshing do
            TMonitor.Wait(FTokenLock, 5000);
          Result := SendJsonInternal(AMethod, APath, ABody, AIdempotencyKey, AIncludeAuth);
        end
        else
        begin
          FRefreshing := True;
          try
            if TryRefreshToken then
              Result := SendJsonInternal(AMethod, APath, ABody, AIdempotencyKey, AIncludeAuth);
          finally
            FRefreshing := False;
            TMonitor.PulseAll(FTokenLock);
          end;
        end;
      finally
        TMonitor.Exit(FTokenLock);
      end;
    end;
  end;

  // BUG-428 FIX (E-005): 429/5xx transient-failure backoff. Only retry
  // idempotent requests so that non-idempotent operations (order creation,
  // payment intents) are never duplicated. 429 honors Retry-After when the
  // transport surfaces headers; 5xx uses exponential backoff with jitter.
  if IsIdempotentCall(AMethod, AIdempotencyKey) and
     IsRetriableStatus(Result.StatusCode) then
  begin
    for Attempt := 0 to FMaxRetries - 1 do
    begin
      if (Result.StatusCode = 429) and
         ExtractRetryAfterMs(Result.Headers, RetryMs) then
        // Honor server-directed Retry-After (clamped to the cap).
        RetryMs := System.Math.Min(RetryMs, BACKOFF_CAP_MS)
      else
        RetryMs := ComputeBackoffMs(Attempt);

      {$IFDEF MSWINDOWS}
      if RetryMs > 0 then
        Sleep(RetryMs);
      {$ENDIF}

      Result := SendJsonInternal(AMethod, APath, ABody, AIdempotencyKey,
        AIncludeAuth);
      if not IsRetriableStatus(Result.StatusCode) then
        Break;
    end;
  end;
end;

function TDeepKitSafeClient.IsRetriableStatus(AStatusCode: Integer): Boolean;
begin
  // 429 (rate-limited) and 5xx (server errors) are transient. 408/409 are
  // left to higher layers (timeout/idempotency conflict handling).
  Result := (AStatusCode = 429) or
            ((AStatusCode >= 500) and (AStatusCode <= 599));
end;

function TDeepKitSafeClient.IsIdempotentCall(const AMethod,
  AIdempotencyKey: string): Boolean;
begin
  Result := (AIdempotencyKey <> '') or SameText(AMethod, SHttpGet) or
            SameText(AMethod, 'HEAD');
end;

function TDeepKitSafeClient.ExtractRetryAfterMs(const AHeaders: TNetHeaders;
  out ARetryMs: Integer): Boolean;
var
  I: Integer;
  Raw: string;
  Code: Integer;
begin
  ARetryMs := 0;
  Result := False;
  for I := Low(AHeaders) to High(AHeaders) do
  begin
    if SameText(AHeaders[I].Name, RETRY_AFTER_HEADER) then
    begin
      Raw := Trim(AHeaders[I].Value);
      // Retry-After may be a delay-seconds integer or an HTTP-date. We only
      // honor the integer form here; HTTP-date falls back to exponential
      // backoff in SendJson.
      if TryStrToInt(Raw, Code) and (Code >= 0) then
      begin
        ARetryMs := Code * 1000;
        Result := True;
      end;
      Exit;
    end;
  end;
end;

function TDeepKitSafeClient.ComputeBackoffMs(AAttempt: Integer): Integer;
var
  Base: Integer;
  Jitter: Integer;
begin
  // Exponential base 2^attempt * BACKOFF_BASE_MS, capped at BACKOFF_CAP_MS,
  // plus a small deterministic jitter derived from the attempt index so that
  // concurrent callers do not retry in lockstep. Math.random/Now are avoided
  // (the latter would defeat prompt-cache warmth in callers).
  Base := BACKOFF_BASE_MS;
  if AAttempt > 0 then
    Base := Base * (1 shl System.Math.Min(AAttempt, 7)); // 2^attempt, cap shift
  if Base > BACKOFF_CAP_MS then
    Base := BACKOFF_CAP_MS;
  // Jitter: -/+ 25% of base, derived deterministically from attempt.
  Jitter := (Base div 4) * ((AAttempt mod 3) - 1);
  Result := Base + Jitter;
  if Result < 0 then
    Result := Base;
end;

function TDeepKitSafeClient.TryRefreshToken: Boolean;
var
  Body: TJSONObject;
  Response: TCommerceBackendHttpResponse;
  Json: TJSONObject;
  Session: TDeepKitAuthSession;
begin
  Result := False;
  if FRefreshToken = '' then
    Exit;

  Body := TJSONObject.Create;
  try
    Body.AddPair(SDeepKitFieldRefreshToken, FRefreshToken);
    Response := SendJsonInternal(SHttpPost, SDeepKitRouteAuthRefresh, Body, '', False);
  finally
    Body.Free;
  end;

  if Response.StatusCode <> 200 then
    Exit;

  Json := ParseJsonObject(Response.Body);
  if not Assigned(Json) then
    Exit;
  try
    Session := AuthSessionFromJson(Json);
    if Session.AccessToken <> '' then
    begin
      SetAccessToken(Session.AccessToken);
      if Session.RefreshToken <> '' then
          SetRefreshToken(Session.RefreshToken);
      Result := True;
    end;
  finally
    Json.Free;
  end;
end;

procedure TDeepKitSafeClient.EnsureSuccess(const AMethod, APath: string;
  const AResponse: TCommerceBackendHttpResponse);
var
  SafeBody: string;
begin
  if not IsHttpSuccess(AResponse.StatusCode) then
  begin
    if Length(AResponse.Body) > 100 then
      SafeBody := Copy(AResponse.Body, 1, 100) + '[...]'
    else
      SafeBody := AResponse.Body;
    raise EDeepBaseCommerceError.CreateFmt(
      'DeepKit HTTP %d for %s %s: %s',
      [AResponse.StatusCode, AMethod, APath, SafeBody]);
  end;
end;

function TDeepKitSafeClient.ParseObjectResponse(const AMethod,
  APath: string; const AResponse: TCommerceBackendHttpResponse): TJSONObject;
begin
  EnsureSuccess(AMethod, APath, AResponse);
  Result := ParseJsonObject(AResponse.Body);
end;

procedure TDeepKitSafeClient.ValidateLicenseSnapshot(
  const ASnapshot: TDeepKitLicenseSnapshot; const AAppId, ADeviceId: string);
var
  ExpiresAt: TDateTime;
  PayloadAppId: string;
  PayloadDeviceId: string;
  Verified: Boolean;
  I: Integer;
{$IFDEF MSWINDOWS}
  RsaVerifier: TRSAVerifier;
{$ENDIF}
begin
  if ASnapshot.SnapshotId = '' then
    raise EDeepBaseCommerceValidationError.Create('License snapshot is missing snapshot_id');
  if ASnapshot.IssuedAtISO = '' then
    raise EDeepBaseCommerceValidationError.Create('License snapshot is missing issued_at');
  if ASnapshot.ExpiresAtISO = '' then
    raise EDeepBaseCommerceValidationError.Create('License snapshot is missing expires_at');
  if ASnapshot.Payload = '' then
    raise EDeepBaseCommerceValidationError.Create('License snapshot is missing payload');
  if ASnapshot.Signature = '' then
    raise EDeepBaseCommerceValidationError.Create('License snapshot is missing signature');
  if ASnapshot.KeyId = '' then
    raise EDeepBaseCommerceValidationError.Create('License snapshot is missing key_id');
  if ASnapshot.SchemaVersion <= 0 then
    raise EDeepBaseCommerceValidationError.Create('License snapshot has invalid schema_version');

  if not TryISO8601ToDate(ASnapshot.ExpiresAtISO, ExpiresAt, False) then
    raise EDeepBaseCommerceValidationError.Create('License snapshot expires_at is invalid');
  if ExpiresAt <= TTimeZone.Local.ToUniversalTime(Now) then
    raise EDeepBaseCommerceValidationError.Create('License snapshot has expired');

  PayloadAppId := SnapshotJsonField(ASnapshot.Payload, SCommerceFieldAppId);
  if (PayloadAppId <> '') and (PayloadAppId <> AAppId) then
    raise EDeepBaseCommerceValidationError.Create('License snapshot app_id mismatch');

  PayloadDeviceId := SnapshotJsonField(ASnapshot.Payload, SDeepKitFieldDeviceId);
  if (PayloadDeviceId <> '') and (PayloadDeviceId <> ADeviceId) then
    raise EDeepBaseCommerceValidationError.Create('License snapshot device_id mismatch');

  if Assigned(FConfig.LicenseSnapshotVerifier) then
  begin
    if not FConfig.LicenseSnapshotVerifier(ASnapshot.Payload,
      ASnapshot.Signature, ASnapshot.KeyId, AAppId, ADeviceId) then
      raise EDeepBaseCommerceValidationError.Create('License snapshot signature verification failed');
    Exit;
  end;

  Verified := False;
  for I := 0 to Length(FConfig.LicenseSnapshotPublicKeys) - 1 do
  begin
    if not SameText(FConfig.LicenseSnapshotPublicKeys[I].KeyId, ASnapshot.KeyId) then
      Continue;

{$IFDEF MSWINDOWS}
    RsaVerifier := TRSAVerifier.Create;
    try
      if not RsaVerifier.LoadPublicKeyPEM(
        FConfig.LicenseSnapshotPublicKeys[I].PublicKeyPEM) then
        raise EDeepBaseCommerceValidationError.Create(
          'License snapshot public key is invalid');
      Verified := RsaVerifier.VerifySignature(ASnapshot.Payload,
        ASnapshot.Signature);
    finally
      RsaVerifier.Free;
    end;
{$ELSE}
    // License snapshot RSA-SHA256 verification currently requires Windows CryptoAPI.
    // On non-Windows platforms, provide a custom LicenseSnapshotVerifier callback
    // in TDeepKitSafeClientConfig to handle verification (e.g. via OpenSSL).
    raise EDeepBaseCommerceValidationError.Create(
      'License snapshot public-key verification is unavailable on this platform');
{$ENDIF}
    Break;
  end;

  if not Verified then
    raise EDeepBaseCommerceValidationError.Create(
      'License snapshot signature verification failed');
end;

function TDeepKitSafeClient.AuthLoginDeviceAnonymous(const AAppId,
  ADeviceId, ADeviceFingerprint: string): TDeepKitAuthSession;
var
  Body: TJSONObject;
  Response: TCommerceBackendHttpResponse;
  Json: TJSONObject;
begin
  Body := TJSONObject.Create;
  try
    Body.AddPair(SDeepKitFieldLoginType, 'device_anonymous');
    Body.AddPair(SCommerceFieldAppId, AAppId);
    Body.AddPair(SDeepKitFieldDeviceId, ADeviceId);
    if ADeviceFingerprint <> '' then
      Body.AddPair(SDeepKitFieldDeviceFingerprint, ADeviceFingerprint);
    Response := SendJson(SHttpPost, SDeepKitRouteAuthLogin, Body, '', False);
  finally
    Body.Free;
  end;

  Json := ParseObjectResponse(SHttpPost, SDeepKitRouteAuthLogin, Response);
  try
    Result := AuthSessionFromJson(Json);
    if Result.AccessToken <> '' then
      SetAccessToken(Result.AccessToken);
    if Result.RefreshToken <> '' then
      SetRefreshToken(Result.RefreshToken);
  finally
    Json.Free;
  end;
end;

function TDeepKitSafeClient.AuthRefresh(
  const ARefreshToken: string): TDeepKitAuthSession;
var
  Body: TJSONObject;
  Response: TCommerceBackendHttpResponse;
  Json: TJSONObject;
begin
  Body := TJSONObject.Create;
  try
    Body.AddPair(SDeepKitFieldRefreshToken, ARefreshToken);
    Response := SendJson(SHttpPost, SDeepKitRouteAuthRefresh, Body, '', False);
  finally
    Body.Free;
  end;

  Json := ParseObjectResponse(SHttpPost, SDeepKitRouteAuthRefresh, Response);
  try
    Result := AuthSessionFromJson(Json);
    if Result.AccessToken <> '' then
      SetAccessToken(Result.AccessToken);
    if Result.RefreshToken <> '' then
      SetRefreshToken(Result.RefreshToken);
  finally
    Json.Free;
  end;
end;

procedure TDeepKitSafeClient.AuthLogout(const ARefreshToken: string);
var
  Token: string;
  Body: TJSONObject;
  Json: TJSONObject;
begin
  Token := ARefreshToken;
  if Token = '' then
    Token := GetRefreshToken;

  if Token = '' then
    Exit;

  Body := TJSONObject.Create;
  try
    if Token <> '' then
      Body.AddPair(SDeepKitFieldRefreshToken, Token);
    Json := ParseObjectResponse(SHttpPost, SDeepKitRouteAuthLogout,
      SendJson(SHttpPost, SDeepKitRouteAuthLogout, Body));
    try
      SetAccessToken('');
      SetRefreshToken('');
    finally
      Json.Free;
    end;
  finally
    Body.Free;
  end;
end;

function TDeepKitSafeClient.AuthMe: TDeepKitUserProfile;
var
  Json: TJSONObject;
begin
  Json := ParseObjectResponse(SHttpGet, SDeepKitRouteAuthMe,
    SendJson(SHttpGet, SDeepKitRouteAuthMe));
  try
    Result := UserProfileFromJson(Json);
  finally
    Json.Free;
  end;
end;

function TDeepKitSafeClient.EnsureUser(AProvider: TCommerceAuthProvider;
  const AProviderUserId, AAppId, AUnionId: string): TDeepKitUserProfile;
var
  Body: TJSONObject;
  Json: TJSONObject;
begin
  Body := TJSONObject.Create;
  try
    Body.AddPair(SCommerceFieldProvider, CommerceAuthProviderToStr(AProvider));
    Body.AddPair(SCommerceFieldProviderUserId, AProviderUserId);
    Body.AddPair(SCommerceFieldAppId, AAppId);
    if AUnionId <> '' then
      Body.AddPair(SCommerceFieldUnionId, AUnionId);

    Json := ParseObjectResponse(SHttpPost, SCommerceRouteUsersEnsure,
      SendJson(SHttpPost, SCommerceRouteUsersEnsure, Body));
    try
      Result := UserProfileFromJson(Json);
    finally
      Json.Free;
    end;
  finally
    Body.Free;
  end;
end;

function TDeepKitSafeClient.CreateOrder(const AUserId, AAppId,
  AProductId: string): TDeepKitOrder;
var
  Body: TJSONObject;
  Json: TJSONObject;
begin
  Body := TJSONObject.Create;
  try
    Body.AddPair(SCommerceFieldUserId, AUserId);
    Body.AddPair(SCommerceFieldAppId, AAppId);
    Body.AddPair(SCommerceFieldProductId, AProductId);

    Json := ParseObjectResponse(SHttpPost, SCommerceRouteOrders,
      SendJson(SHttpPost, SCommerceRouteOrders, Body));
    try
      Result := DeepKitOrderFromJson(Json);
    finally
      Json.Free;
    end;
  finally
    Body.Free;
  end;
end;

function TDeepKitSafeClient.GetOrder(const AOrderId: string): TDeepKitOrder;
var
  Path: string;
  Json: TJSONObject;
begin
  Path := TCommerceBackendRoutes.OrderById(AOrderId);
  Json := ParseObjectResponse(SHttpGet, Path, SendJson(SHttpGet, Path));
  try
    Result := DeepKitOrderFromJson(Json);
  finally
    Json.Free;
  end;
end;

function TDeepKitSafeClient.CloseOrder(const AOrderId: string): TDeepKitOrder;
var
  Path: string;
  Json: TJSONObject;
begin
  if AOrderId = '' then
    raise EDeepBaseCommerceValidationError.Create('Order ID is required');
  Path := TCommerceBackendRoutes.OrderClose(AOrderId);
  Json := ParseObjectResponse(SHttpPost, Path, SendJson(SHttpPost, Path));
  try
    Result := DeepKitOrderFromJson(Json);
  finally
    Json.Free;
  end;
end;

function TDeepKitSafeClient.CreatePaymentIntent(const AOrderId: string;
  AProvider: TCommercePaymentProvider; AChannel: TCommercePaymentChannel;
  const APayerOpenId, AIdempotencyKey: string): TCommercePaymentIntent;
var
  Body: TJSONObject;
  Response: TCommerceBackendHttpResponse;
  Json: TJSONObject;
begin
  Body := TJSONObject.Create;
  try
    Body.AddPair(SCommerceFieldOrderId, AOrderId);
    Body.AddPair(SCommerceFieldProvider, CommercePaymentProviderToStr(AProvider));
    Body.AddPair(SCommerceFieldChannel, ChannelToString(AChannel));
    if APayerOpenId <> '' then
      Body.AddPair(SCommerceFieldPayerOpenId, APayerOpenId);

    Response := SendJson(SHttpPost, SCommerceRoutePaymentIntents, Body,
      AIdempotencyKey);
  finally
    Body.Free;
  end;

  Json := ParseObjectResponse(SHttpPost, SCommerceRoutePaymentIntents, Response);
  try
    Result := PaymentIntentFromJson(Json, Response.Body);
  finally
    Json.Free;
  end;
end;

function TDeepKitSafeClient.ListProducts(
  const AAppId: string): TArray<TCommerceProductData>;
var
  Path: string;
  Json: TJSONObject;
  Items: TJSONArray;
  I: Integer;
begin
  SetLength(Result, 0);
  Path := SCommerceRouteProducts + BuildQuery([SCommerceFieldAppId, AAppId]);
  Json := ParseObjectResponse(SHttpGet, Path, SendJson(SHttpGet, Path));
  try
    Items := Json.GetValue<TJSONArray>(SDeepKitFieldProducts, nil);
    if not Assigned(Items) then
      Items := Json.GetValue<TJSONArray>(SCommerceFieldItems, nil);
    if not Assigned(Items) then
      Exit;

    SetLength(Result, Items.Count);
    for I := 0 to Items.Count - 1 do
      if Items.Items[I] is TJSONObject then
        Result[I] := ProductFromJson(TJSONObject(Items.Items[I]));
  finally
    Json.Free;
  end;
end;

function TDeepKitSafeClient.ListEntitlements(
  const AAppId: string): TCommerceEntitlementArray;
var
  Path: string;
  Json: TJSONObject;
  Items: TJSONArray;
  I: Integer;
begin
  SetLength(Result, 0);
  Path := SCommerceRouteEntitlements + BuildQuery([SCommerceFieldAppId, AAppId]);
  Json := ParseObjectResponse(SHttpGet, Path, SendJson(SHttpGet, Path));
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

function TDeepKitSafeClient.ConsumeEntitlement(const AAppId, AEntitlementCode,
  AFeatureCode: string; AQuantity: Integer;
  const ARequestId: string): TDeepKitConsumeEntitlementResult;
var
  Body: TJSONObject;
  Json: TJSONObject;
  IdempotencyKey: string;
  CachedJson: string;
begin
  if AQuantity <= 0 then
    raise EDeepBaseCommerceValidationError.Create('ConsumeEntitlement quantity must be > 0');

  // Idempotency: use caller-provided key or auto-generate one
  if ARequestId <> '' then
    IdempotencyKey := ARequestId
  else
    IdempotencyKey := FIdempotencyTracker.NewKey('consume_entitlement');

  // Replay protection: if this key was already completed, return cached result
  if FIdempotencyTracker.IsAlreadyCompleted(IdempotencyKey) then
  begin
    CachedJson := FIdempotencyTracker.GetCachedResponse(IdempotencyKey);
    if CachedJson <> '' then
    begin
      Json := TJSONObject.ParseJSONValue(CachedJson) as TJSONObject;
      if Json <> nil then
      try
        Result.Ok := JsonValueAsBool(Json, 'ok',
          JsonValueAsBool(Json, SCommerceFieldSuccess, False));
        Result.EntitlementCode := JsonValueAsString(Json, SCommerceFieldEntitlementCode, '');
        Result.RemainingQuota := JsonValueAsInt(Json, SCommerceFieldRemainingQuota, -1);
        Result.ConsumedQuantity := JsonValueAsInt(Json, SDeepKitFieldConsumedQuantity, AQuantity);
        Result.ServerTimeISO := JsonValueAsString(Json, SDeepKitFieldServerTime, '');
        Exit;
      finally
        Json.Free;
      end;
    end;
  end;

  Body := TJSONObject.Create;
  try
    Body.AddPair(SCommerceFieldAppId, AAppId);
    Body.AddPair(SCommerceFieldEntitlementCode, AEntitlementCode);
    Body.AddPair(SDeepKitFieldFeatureCode, AFeatureCode);
    Body.AddPair(SDeepKitFieldQuantity, TJSONNumber.Create(AQuantity));
    if ARequestId <> '' then
      Body.AddPair(SDeepKitFieldRequestId, ARequestId);

    Json := ParseObjectResponse(SHttpPost, SCommerceRouteEntitlementsConsume,
      SendJson(SHttpPost, SCommerceRouteEntitlementsConsume, Body,
        IdempotencyKey));
    try
      Result.Ok := JsonValueAsBool(Json, 'ok',
        JsonValueAsBool(Json, SCommerceFieldSuccess, False));
      Result.EntitlementCode := JsonValueAsString(Json, SCommerceFieldEntitlementCode, '');
      Result.RemainingQuota := JsonValueAsInt(Json, SCommerceFieldRemainingQuota, -1);
      Result.ConsumedQuantity := JsonValueAsInt(Json, SDeepKitFieldConsumedQuantity, AQuantity);
      Result.ServerTimeISO := JsonValueAsString(Json, SDeepKitFieldServerTime, '');

      // Cache the successful response for replay protection
      if Result.Ok then
        FIdempotencyTracker.RecordSuccess(IdempotencyKey, Json.ToJSON)
      else
        FIdempotencyTracker.RecordFailure(IdempotencyKey);
    finally
      Json.Free;
    end;
  finally
    Body.Free;
  end;
end;

function TDeepKitSafeClient.IssueLicenseSnapshot(const AAppId,
  ADeviceId: string): TDeepKitLicenseSnapshot;
var
  Body: TJSONObject;
  Json: TJSONObject;
begin
  Body := TJSONObject.Create;
  try
    Body.AddPair(SCommerceFieldAppId, AAppId);
    Body.AddPair(SDeepKitFieldDeviceId, ADeviceId);

    Json := ParseObjectResponse(SHttpPost, SDeepKitRouteLicenseSnapshotIssue,
      SendJson(SHttpPost, SDeepKitRouteLicenseSnapshotIssue, Body));
    try
      Result := LicenseSnapshotFromJson(Json);
      ValidateLicenseSnapshot(Result, AAppId, ADeviceId);
    finally
      Json.Free;
    end;
  finally
    Body.Free;
  end;
end;

function TDeepKitSafeClient.RefreshLicenseSnapshot(const AAppId, ADeviceId,
  ASnapshotId: string): TDeepKitLicenseSnapshot;
var
  Body: TJSONObject;
  Json: TJSONObject;
begin
  Body := TJSONObject.Create;
  try
    Body.AddPair(SCommerceFieldAppId, AAppId);
    Body.AddPair(SDeepKitFieldDeviceId, ADeviceId);
    if ASnapshotId <> '' then
      Body.AddPair(SDeepKitFieldSnapshotId, ASnapshotId);

    Json := ParseObjectResponse(SHttpPost, SDeepKitRouteLicenseSnapshotRefresh,
      SendJson(SHttpPost, SDeepKitRouteLicenseSnapshotRefresh, Body));
    try
      Result := LicenseSnapshotFromJson(Json);
      ValidateLicenseSnapshot(Result, AAppId, ADeviceId);
    finally
      Json.Free;
    end;
  finally
    Body.Free;
  end;
end;

function TDeepKitSafeClient.GetUpdatesManifest(const AAppId,
  ACurrentVersion, AChannel: string): TDeepKitUpdateManifest;
var
  Path: string;
  Json: TJSONObject;
begin
  Path := SDeepKitRouteUpdatesManifest + BuildQuery([
    SCommerceFieldAppId, AAppId,
    SDeepKitFieldCurrentVersion, ACurrentVersion,
    SCommerceFieldChannel, AChannel
  ]);
  Json := ParseObjectResponse(SHttpGet, Path, SendJson(SHttpGet, Path));
  try
    Result := UpdateManifestFromJson(Json);
  finally
    Json.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Invite / Referral
// ---------------------------------------------------------------------------

function TDeepKitSafeClient.InviteGenerate(const AAppId: string): TJSONObject;
var
  Body: TJSONObject;
begin
  Body := TJSONObject.Create;
  try
    Body.AddPair(SCommerceFieldAppId, AAppId);
    Result := ParseObjectResponse(SHttpPost, SDeepKitRouteInviteGenerate,
      SendJson(SHttpPost, SDeepKitRouteInviteGenerate, Body));
  finally
    Body.Free;
  end;
end;

function TDeepKitSafeClient.InviteApply(const AAppId, AInviteCode: string): TJSONObject;
var
  Body: TJSONObject;
begin
  Body := TJSONObject.Create;
  try
    Body.AddPair(SCommerceFieldAppId, AAppId);
    Body.AddPair(SDeepKitFieldInviteCode, AInviteCode);
    Result := ParseObjectResponse(SHttpPost, SDeepKitRouteInviteApply,
      SendJson(SHttpPost, SDeepKitRouteInviteApply, Body));
  finally
    Body.Free;
  end;
end;

function TDeepKitSafeClient.InviteStatus(const AAppId: string): TJSONObject;
var
  Path: string;
begin
  Path := SDeepKitRouteInviteStatus + BuildQuery([SCommerceFieldAppId, AAppId]);
  Result := ParseObjectResponse(SHttpGet, Path, SendJson(SHttpGet, Path));
end;

end.
