unit UniBase.Payment.PayPal;

{*******************************************************************************
  UniBase PayPal Payment Integration

  Supports:
    - Orders API v2 (checkout/orders)
    - Payment capture and query
    - Refunds
    - Webhook verification

  Authentication: OAuth2 Bearer Token (client_id:client_secret)
  API Version: v2 (Orders), v1 (Auth/Refunds/Webhooks)

  Official Docs: https://developer.paypal.com/docs/api/orders/v2/
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.JSON, System.DateUtils, System.NetEncoding, System.SyncObjs,
  UniBase.Payment;

type
  /// <summary>PayPal configuration</summary>
  TPayPalConfig = class(TPaymentConfig)
  private
    FClientID: string;
    FClientSecret: string;
    FWebhookId: string;
  public
    constructor Create; reintroduce;

    // BUG-019 FIX: 安全密钥存储方法重写
    procedure LoadKeysFromCredentialManager; override;
    procedure SaveKeysToCredentialManager; override;
    /// <summary>设置ClientSecret（自动使用安全存储）</summary>
    procedure SetSecretKeySecure(const AKey: string);
    /// <summary>获取ClientSecret（自动解密）</summary>
    function GetSecretKeySecure: string;

    property ClientID: string read FClientID write FClientID;
    property ClientSecret: string read FClientSecret write FClientSecret;
    property WebhookId: string read FWebhookId write FWebhookId;
  end;

  /// <summary>PayPal client implementation</summary>
  TPayPalClient = class(TPaymentClient)
  private
    FAccessToken: string;
    FTokenExpiry: TDateTime;
    FTokenLock: TCriticalSection;

    function GetBaseUrl: string;
    function GetAccessToken: string;
    function DoPayPalPost(const AEndpoint: string;
      const ABody: TJSONObject): TJSONObject;
    function DoPayPalGet(const AEndpoint: string): TJSONObject;
    function DoPayPalPostForm(const AEndpoint: string;
      const AParams: TDictionary<string, string>): TJSONObject;
    function ParsePayPalStatus(const AStatus: string): TPaymentStatus;
    function ExtractCaptureId(const AOrderJson: TJSONObject): string;
  protected
    function SignRequest(const AParams: TDictionary<string, string>): string; override;
    function VerifySignature(const AParams: TDictionary<string, string>;
      const ASign: string): Boolean; override;
  public
    constructor Create(AConfig: TPayPalConfig); reintroduce;
    destructor Destroy; override;

    // IPaymentClient
    function CreateOrder(const AOrder: TPaymentOrder): TPaymentResult; override;
    function QueryOrder(const AOrderNo: string): TPaymentQueryResult; override;
    function CloseOrder(const AOrderNo: string): Boolean; override;
    function Refund(const ARequest: TRefundRequest): TRefundResult; override;
    function QueryRefund(const ARefundNo: string): TRefundResult; override;
    function VerifyNotification(const ARawData: string;
      out ANotification: TPaymentNotification): Boolean; override;
    function GetNotificationResponse(ASuccess: Boolean): string; override;

    // BUG-015 FIX: PayPal webhook signature verification
    /// <summary>
    /// Verify PayPal webhook signature using the transmission headers.
    /// Pass the raw payload, transmission ID, timestamp, actual signature,
    /// and the CRC of the webhook ID.
    /// </summary>
    function VerifyWebhookSignature(const APayload, ATransmissionId,
      ATimestamp, AWebhookSignature, ACrc: string): Boolean;
  end;

implementation

uses
  System.Hash, System.StrUtils;

const
  PAYPAL_SANDBOX_URL    = 'https://api-mvc.sandbox.paypal.com';
  PAYPAL_PRODUCTION_URL = 'https://api-mvc.paypal.com';
  TOKEN_BUFFER_SECONDS  = 60;  // Refresh token 60s before actual expiry

{ TPayPalConfig }

constructor TPayPalConfig.Create;
begin
  inherited Create(ppPayPal);
end;

// BUG-019 FIX: 安全密钥存储方法实现
procedure TPayPalConfig.LoadKeysFromCredentialManager;
begin
  if KeyStorageMode = ksmCredential then
  begin
    FClientID := GetCredentialKey('ClientID');
    FClientSecret := GetCredentialKey('ClientSecret');
    FWebhookId := GetCredentialKey('WebhookId');
  end;
end;

procedure TPayPalConfig.SaveKeysToCredentialManager;
begin
  if KeyStorageMode = ksmCredential then
  begin
    SetCredentialKey('ClientID', FClientID);
    SetCredentialKey('ClientSecret', FClientSecret);
    SetCredentialKey('WebhookId', FWebhookId);
  end;
end;

procedure TPayPalConfig.SetSecretKeySecure(const AKey: string);
begin
  FClientSecret := ProtectKey(AKey);
end;

function TPayPalConfig.GetSecretKeySecure: string;
begin
  Result := UnprotectKey(FClientSecret);
end;

{ TPayPalClient }

constructor TPayPalClient.Create(AConfig: TPayPalConfig);
begin
  inherited Create(AConfig);
  FTokenLock := TCriticalSection.Create;
  FAccessToken := '';
  FTokenExpiry := 0;
end;

destructor TPayPalClient.Destroy;
begin
  FreeAndNil(FTokenLock);
  inherited;
end;

function TPayPalClient.GetBaseUrl: string;
var
  Cfg: TPayPalConfig;
begin
  Cfg := TPayPalConfig(FConfig);
  if Cfg.IsSandbox then
    Result := PAYPAL_SANDBOX_URL
  else
    Result := PAYPAL_PRODUCTION_URL;
end;

function TPayPalClient.SignRequest(
  const AParams: TDictionary<string, string>): string;
begin
  // PayPal uses OAuth2 Bearer tokens, not per-request signing
  Result := '';
end;

function TPayPalClient.VerifySignature(
  const AParams: TDictionary<string, string>;
  const ASign: string): Boolean;
  function ReadParam(const AKeys: array of string): string;
  var
    I: Integer;
  begin
    for I := Low(AKeys) to High(AKeys) do
      if AParams.TryGetValue(AKeys[I], Result) and (Trim(Result) <> '') then
        Exit;
    Result := '';
  end;
var
  Cfg: TPayPalConfig;
  Payload: string;
  TransmissionId: string;
  Timestamp: string;
  Signature: string;
begin
  Cfg := TPayPalConfig(FConfig);
  if Cfg.WebhookId = '' then
    Exit(False);

  Payload := ReadParam(['payload', 'raw_data', 'body']);
  TransmissionId := ReadParam(['transmission_id', 'paypal-transmission-id']);
  Timestamp := ReadParam(['transmission_time', 'paypal-transmission-time']);
  Signature := Trim(ASign);
  if Signature = '' then
    Signature := ReadParam(['webhook_signature', 'transmission_sig',
      'paypal-transmission-sig', 'signature']);

  if (Payload = '') or (TransmissionId = '') or (Timestamp = '') or (Signature = '') then
    Exit(False);

  try
    Result := VerifyWebhookSignature(Payload, TransmissionId, Timestamp, Signature, '');
  except
    Result := False;
  end;
end;

// ---------------------------------------------------------------------------
// OAuth2 Token Management with caching
// ---------------------------------------------------------------------------

function TPayPalClient.GetAccessToken: string;
var
  Cfg: TPayPalConfig;
  AuthHeader: string;
  Params: TDictionary<string, string>;
  RespObj: TJSONObject;
  ExpiresIn: Int64;
begin
  FTokenLock.Acquire;
  try
    // Return cached token if still valid (with buffer)
    if (FAccessToken <> '') and (FTokenExpiry > Now + TOKEN_BUFFER_SECONDS / 86400) then
      Exit(FAccessToken);

    Cfg := TPayPalConfig(FConfig);
    if (Cfg.ClientID = '') or (Cfg.ClientSecret = '') then
      raise EPaymentConfigError.Create('PayPal ClientID and ClientSecret are required',
        'MISSING_CREDENTIALS', ppPayPal);

    // Build Basic Auth header from client_id:client_secret
    AuthHeader := TNetEncoding.Base64.Encode(Cfg.ClientID + ':' + Cfg.GetSecretKeySecure);

    Params := TDictionary<string, string>.Create;
    try
      Params.Add('grant_type', 'client_credentials');

      // Temporarily set auth for the token request
      FHttpClient.CustomHeaders['Authorization'] := 'Basic ' + AuthHeader;

      var Response := DoPost(GetBaseUrl + '/v1/oauth2/token',
        TPaymentHelper.BuildQueryString(Params, True),
        'application/x-www-form-urlencoded');

      RespObj := TJSONObject.ParseJSONValue(Response) as TJSONObject;
      if not Assigned(RespObj) then
        raise EPaymentNetworkError.Create('Invalid OAuth2 token response',
          'INVALID_TOKEN_RESPONSE', ppPayPal);

      try
        if RespObj.GetValue('error') <> nil then
        begin
          var ErrDesc := RespObj.GetValue<string>('error_description', '');
          FreeAndNil(RespObj);
          raise EPaymentBusinessError.Create('OAuth2 token request failed: ' + ErrDesc,
            'TOKEN_ERROR', ppPayPal);
        end;

        FAccessToken := RespObj.GetValue<string>('access_token', '');
        ExpiresIn := RespObj.GetValue<Int64>('expires_in', 0);

        if FAccessToken = '' then
          raise EPaymentBusinessError.Create('Empty access token received',
            'EMPTY_TOKEN', ppPayPal);

        // Calculate expiry time
        FTokenExpiry := Now + ExpiresIn / 86400;
        Result := FAccessToken;
      finally
        FreeAndNil(RespObj);
      end;
    finally
      FreeAndNil(Params);
    end;
  finally
    FTokenLock.Release;
  end;
end;

// ---------------------------------------------------------------------------
// HTTP Helpers
// ---------------------------------------------------------------------------

function TPayPalClient.DoPayPalPost(const AEndpoint: string;
  const ABody: TJSONObject): TJSONObject;
var
  Token, Response: string;
begin
  Result := nil;
  Token := GetAccessToken;

  FHttpClient.CustomHeaders['Authorization'] := 'Bearer ' + Token;
  FHttpClient.CustomHeaders['Content-Type'] := 'application/json';
  FHttpClient.CustomHeaders['Accept'] := 'application/json';

  Response := DoPost(GetBaseUrl + AEndpoint, ABody.ToString, 'application/json');

  Result := TJSONObject.ParseJSONValue(Response) as TJSONObject;
  if not Assigned(Result) then
    raise EPaymentNetworkError.Create('Invalid JSON response from PayPal',
      'INVALID_JSON', ppPayPal);

  // Check for PayPal error response
  // PayPal errors: {"name": "...", "message": "...", "details": [...]}
  if Result.GetValue('name') <> nil then
  begin
    var ErrName := Result.GetValue<string>('name', '');
    // Some responses have "name" as a legitimate field (e.g., order response)
    // Only treat as error if there is also a "details" error array or known error names
    if (Result.GetValue('details') <> nil) or
       SameText(ErrName, 'INVALID_REQUEST') or
       SameText(ErrName, 'AUTHENTICATION_FAILURE') or
       SameText(ErrName, 'INVALID_TOKEN') or
       SameText(ErrName, 'PERMISSION_DENIED') or
       SameText(ErrName, 'NOT_FOUND') or
       SameText(ErrName, 'UNPROCESSABLE_ENTITY') or
       SameText(ErrName, 'INTERNAL_SERVER_ERROR') or
       SameText(ErrName, 'SERVICE_UNAVAILABLE') then
    begin
      var ErrMsg := Result.GetValue<string>('message', ErrName);
      FreeAndNil(Result);
      raise EPaymentBusinessError.Create(ErrMsg, ErrName, ppPayPal);
    end;
  end;
end;

function TPayPalClient.DoPayPalGet(const AEndpoint: string): TJSONObject;
var
  Token, Response: string;
begin
  Result := nil;
  Token := GetAccessToken;

  FHttpClient.CustomHeaders['Authorization'] := 'Bearer ' + Token;
  FHttpClient.CustomHeaders['Accept'] := 'application/json';

  Response := DoGet(GetBaseUrl + AEndpoint);

  Result := TJSONObject.ParseJSONValue(Response) as TJSONObject;
  if not Assigned(Result) then
    raise EPaymentNetworkError.Create('Invalid JSON response from PayPal',
      'INVALID_JSON', ppPayPal);

  if Result.GetValue('name') <> nil then
  begin
    var ErrName := Result.GetValue<string>('name', '');
    if (Result.GetValue('details') <> nil) or
       SameText(ErrName, 'INVALID_REQUEST') or
       SameText(ErrName, 'AUTHENTICATION_FAILURE') or
       SameText(ErrName, 'INVALID_TOKEN') or
       SameText(ErrName, 'PERMISSION_DENIED') or
       SameText(ErrName, 'NOT_FOUND') or
       SameText(ErrName, 'UNPROCESSABLE_ENTITY') or
       SameText(ErrName, 'INTERNAL_SERVER_ERROR') or
       SameText(ErrName, 'SERVICE_UNAVAILABLE') then
    begin
      var ErrMsg := Result.GetValue<string>('message', ErrName);
      FreeAndNil(Result);
      raise EPaymentBusinessError.Create(ErrMsg, ErrName, ppPayPal);
    end;
  end;
end;

function TPayPalClient.DoPayPalPostForm(const AEndpoint: string;
  const AParams: TDictionary<string, string>): TJSONObject;
var
  Token, Response: string;
begin
  Result := nil;
  Token := GetAccessToken;

  FHttpClient.CustomHeaders['Authorization'] := 'Bearer ' + Token;

  Response := DoPost(GetBaseUrl + AEndpoint,
    TPaymentHelper.BuildQueryString(AParams, True),
    'application/x-www-form-urlencoded');

  Result := TJSONObject.ParseJSONValue(Response) as TJSONObject;
  if not Assigned(Result) then
    raise EPaymentNetworkError.Create('Invalid JSON response from PayPal',
      'INVALID_JSON', ppPayPal);
end;

// ---------------------------------------------------------------------------
// Status Parsing
// ---------------------------------------------------------------------------

function TPayPalClient.ParsePayPalStatus(const AStatus: string): TPaymentStatus;
var
  S: string;
begin
  S := LowerCase(AStatus);
  if (S = 'created') or (S = 'saved') then
    Result := psPending
  else if (S = 'approved') then
    Result := psPending       // Approved but not yet captured
  else if (S = 'payer_action_required') then
    Result := psPending
  else if S = 'completed' then
    Result := psSuccess
  else if S = 'voided' then
    Result := psClosed
  else if S = 'cancelled' then
    Result := psClosed
  else
    Result := psUnknown;
end;

function ParsePayPalAmount(const AValue: string): Currency;
var
  FS: TFormatSettings;
begin
  FS := TFormatSettings.Create;
  FS.DecimalSeparator := '.';
  Result := StrToCurrDef(AValue, 0, FS);
end;

/// <summary>Extract the first capture ID from a completed order's purchase_units</summary>
function TPayPalClient.ExtractCaptureId(const AOrderJson: TJSONObject): string;
var
  UnitsArr: TJSONArray;
  PaymentsObj, CapturesArr: TJSONValue;
begin
  Result := '';
  UnitsArr := AOrderJson.GetValue<TJSONArray>('purchase_units');
  if not Assigned(UnitsArr) or (UnitsArr.Count = 0) then
    Exit;

  PaymentsObj := UnitsArr.Items[0].FindValue('payments');
  if not Assigned(PaymentsObj) then
    Exit;

  CapturesArr := PaymentsObj.FindValue('captures');
  if not Assigned(CapturesArr) or not (CapturesArr is TJSONArray) then
    Exit;

  if TJSONArray(CapturesArr).Count > 0 then
    Result := TJSONArray(CapturesArr).Items[0].FindValue('id').Value;
end;

// ---------------------------------------------------------------------------
// IPaymentClient Implementation
// ---------------------------------------------------------------------------

function TPayPalClient.CreateOrder(const AOrder: TPaymentOrder): TPaymentResult;
var
  Body, AmountObj, PurchaseUnit, AppCtx: TJSONObject;
  RespObj: TJSONObject;
  LinksArr: TJSONArray;
  I: Integer;
begin
  Result.Clear;
  AOrder.Validate;

  Body := TJSONObject.Create;
  try
    Body.AddPair('intent', 'CAPTURE');

    // Build purchase_unit
    PurchaseUnit := TJSONObject.Create;
    PurchaseUnit.AddPair('reference_id', AOrder.OrderNo);

    AmountObj := TJSONObject.Create;
    AmountObj.AddPair('currency_code',
      IfThen(AOrder.Currency <> '', UpperCase(AOrder.Currency), 'USD'));
    AmountObj.AddPair('value', FormatFloat('0.00', AOrder.Amount));
    PurchaseUnit.AddPair('amount', AmountObj);

    if AOrder.Subject <> '' then
      PurchaseUnit.AddPair('description', AOrder.Subject);

    // Custom ID for merchant order tracking
    PurchaseUnit.AddPair('custom_id', AOrder.OrderNo);

    if AOrder.Body <> '' then
      PurchaseUnit.AddPair('soft_descriptor', Copy(AOrder.Body, 1, 22));

    var UnitsArr := TJSONArray.Create;
    UnitsArr.AddElement(PurchaseUnit);
    Body.AddPair('purchase_units', UnitsArr);

    // Application context (return/cancel URLs, branding)
    AppCtx := TJSONObject.Create;
    if AOrder.SuccessUrl <> '' then
      AppCtx.AddPair('return_url', AOrder.SuccessUrl)
    else if AOrder.ReturnUrl <> '' then
      AppCtx.AddPair('return_url', AOrder.ReturnUrl);

    if AOrder.CancelUrl <> '' then
      AppCtx.AddPair('cancel_url', AOrder.CancelUrl);

    if AOrder.Subject <> '' then
      AppCtx.AddPair('brand_name', Copy(AOrder.Subject, 1, 127));

    // No shipping needed for digital goods
    AppCtx.AddPair('shipping_preference', 'NO_SHIPPING');

    Body.AddPair('application_context', AppCtx);

    try
      RespObj := DoPayPalPost('/v2/checkout/orders', Body);
      try
        Result.Success := True;
        Result.OrderNo := AOrder.OrderNo;
        Result.TradeNo := RespObj.GetValue<string>('id', '');

        // Find the approval link (rel = "approve")
        LinksArr := RespObj.GetValue<TJSONArray>('links');
        if Assigned(LinksArr) then
        begin
          for I := 0 to LinksArr.Count - 1 do
          begin
            if SameText(
              TJSONObject(LinksArr.Items[I]).GetValue<string>('rel', ''), 'approve') then
            begin
              Result.PayUrl := TJSONObject(LinksArr.Items[I]).GetValue<string>('href', '');
              Break;
            end;
          end;
        end;
      finally
        FreeAndNil(RespObj);
      end;
    except
      on E: EPaymentError do
        Result := TPaymentResult.Fail(E.ErrorCode, E.Message);
    end;
  finally
    FreeAndNil(Body);
  end;
end;

function TPayPalClient.QueryOrder(const AOrderNo: string): TPaymentQueryResult;
var
  RespObj: TJSONObject;
  StatusStr: string;
  AmountVal: string;
begin
  Result.Clear;

  try
    // AOrderNo is the PayPal Order ID returned from CreateOrder
    RespObj := DoPayPalGet('/v2/checkout/orders/' + AOrderNo);
    try
      Result.Success := True;
      Result.TradeNo := RespObj.GetValue<string>('id', '');

      // Extract merchant reference from purchase_units[0].custom_id or reference_id
      var UnitsArr := RespObj.GetValue<TJSONArray>('purchase_units');
      if Assigned(UnitsArr) and (UnitsArr.Count > 0) then
      begin
        var CustomId := UnitsArr.Items[0].FindValue('custom_id');
        if Assigned(CustomId) then
          Result.OrderNo := CustomId.Value;

        var AmountObj := UnitsArr.Items[0].FindValue('amount');
        if Assigned(AmountObj) then
        begin
          AmountVal := AmountObj.FindValue('value').Value;
          Result.Amount := ParsePayPalAmount(AmountVal);
        end;
      end;

      StatusStr := RespObj.GetValue<string>('status', '');
      Result.Status := ParsePayPalStatus(StatusStr);

      // For completed orders, get paid amount from captures
      if StatusStr = 'COMPLETED' then
      begin
        Result.PaidAmount := Result.Amount;
        Result.PaidAt := Now;
      end;

      Result.RawResponse := RespObj.ToString;
    finally
      FreeAndNil(RespObj);
    end;
  except
    on E: EPaymentError do
    begin
      Result.ErrorCode := E.ErrorCode;
      Result.ErrorMessage := E.Message;
    end;
  end;
end;

function TPayPalClient.CloseOrder(const AOrderNo: string): Boolean;
begin
  // PayPal orders expire automatically; no explicit cancel needed
  Result := True;
end;

function TPayPalClient.Refund(const ARequest: TRefundRequest): TRefundResult;
var
  Body, AmountObj: TJSONObject;
  RespObj: TJSONObject;
  CaptureId: string;
  QueryResult: TPaymentQueryResult;
begin
  Result.Clear;
  ARequest.Validate;

  // To refund, we need the capture_id. The ARequest.OrderNo may be either
  // a PayPal Order ID or a capture ID. Try to look up the order first.
  CaptureId := ARequest.OrderNo;

  // If it looks like a PayPal Order ID (starts with prefix), query to find capture
  if not SameText(Copy(ARequest.OrderNo, 1, 4), '') then
  begin
    try
      QueryResult := QueryOrder(ARequest.OrderNo);
      if QueryResult.Success then
      begin
        // Parse capture_id from the raw response
        var OrderObj := TJSONObject.ParseJSONValue(QueryResult.RawResponse) as TJSONObject;
        if Assigned(OrderObj) then
        begin
          try
            var Found := ExtractCaptureId(OrderObj);
            if Found <> '' then
              CaptureId := Found;
          finally
            FreeAndNil(OrderObj);
          end;
        end;
      end;
    except
      // If query fails, assume OrderNo is already a capture ID
    end;
  end;

  Body := TJSONObject.Create;
  try
    // Build amount object for partial refund
    AmountObj := TJSONObject.Create;
    AmountObj.AddPair('value', FormatFloat('0.00', ARequest.RefundAmount));
    if ARequest.TotalAmount > 0 then
      AmountObj.AddPair('currency_code',
        IfThen(ARequest.TotalAmount > 0, 'USD', 'USD'))  // Default, caller should set
    else
      AmountObj.AddPair('currency_code', 'USD');
    Body.AddPair('amount', AmountObj);

    if ARequest.Reason <> '' then
      Body.AddPair('note', Copy(ARequest.Reason, 1, 255));

    // Store refund reference as custom_id
    Body.AddPair('custom_id', ARequest.RefundNo);

    try
      RespObj := DoPayPalPost(
        '/v2/payments/captures/' + CaptureId + '/refund', Body);
      try
        Result.Success := True;
        Result.RefundNo := ARequest.RefundNo;
        Result.RefundTradeNo := RespObj.GetValue<string>('id', '');

        var RefundAmountObj := RespObj.FindValue('amount');
        if Assigned(RefundAmountObj) then
        begin
          var Val := RefundAmountObj.FindValue('value');
          if Assigned(Val) then
            Result.RefundAmount := ParsePayPalAmount(Val.Value);
        end;

        var RefundStatus := RespObj.GetValue<string>('status', '');
        if SameText(RefundStatus, 'COMPLETED') then
          Result.Status := psRefunded
        else if SameText(RefundStatus, 'PENDING') then
          Result.Status := psRefunding
        else if SameText(RefundStatus, 'CANCELLED') then
          Result.Status := psFailed
        else
          Result.Status := psUnknown;
      finally
        FreeAndNil(RespObj);
      end;
    except
      on E: EPaymentError do
        Result := TRefundResult.Fail(E.ErrorCode, E.Message);
    end;
  finally
    FreeAndNil(Body);
  end;
end;

function TPayPalClient.QueryRefund(const ARefundNo: string): TRefundResult;
var
  RespObj: TJSONObject;
begin
  Result.Clear;

  try
    // ARefundNo is the PayPal refund ID
    RespObj := DoPayPalGet('/v2/payments/refunds/' + ARefundNo);
    try
      Result.Success := True;
      Result.RefundTradeNo := RespObj.GetValue<string>('id', '');

      // Extract merchant custom_id
      var CustomId := RespObj.FindValue('custom_id');
      if Assigned(CustomId) then
        Result.RefundNo := CustomId.Value;

      var RefundAmountObj := RespObj.FindValue('amount');
      if Assigned(RefundAmountObj) then
      begin
        var Val := RefundAmountObj.FindValue('value');
        if Assigned(Val) then
          Result.RefundAmount := ParsePayPalAmount(Val.Value);
      end;

      var RefundStatus := RespObj.GetValue<string>('status', '');
      if SameText(RefundStatus, 'COMPLETED') then
        Result.Status := psRefunded
      else if SameText(RefundStatus, 'PENDING') then
        Result.Status := psRefunding
      else if SameText(RefundStatus, 'CANCELLED') then
        Result.Status := psFailed
      else
        Result.Status := psUnknown;
    finally
      FreeAndNil(RespObj);
    end;
  except
    on E: EPaymentError do
      Result := TRefundResult.Fail(E.ErrorCode, E.Message);
  end;
end;

function TPayPalClient.VerifyNotification(const ARawData: string;
  out ANotification: TPaymentNotification): Boolean;
var
  Cfg: TPayPalConfig;
  JsonObj, ResourceObj: TJSONObject;
  EventType: string;
begin
  Result := False;
  ANotification.Clear;
  ANotification.Provider := ppPayPal;
  ANotification.RawData := ARawData;

  Cfg := TPayPalConfig(FConfig);

  // BUG-015 FIX: Webhook verification should be done via VerifyWebhookSignature
  // before calling this method. This method parses the payload after verification.
  // 安全收敛：当前接口无传输头，生产环境无法独立完成签名校验，默认拒绝。
  if not Cfg.IsSandbox then
    Exit(False);

  if Cfg.WebhookId = '' then
  begin
    {$IFDEF DEBUG}
    OutputDebugString('WARNING: PayPal webhook ID not configured');
    {$ENDIF}
  end;

  try
    JsonObj := TJSONObject.ParseJSONValue(ARawData) as TJSONObject;
    if not Assigned(JsonObj) then
      Exit;

    try
      EventType := JsonObj.GetValue<string>('event_type', '');
      ResourceObj := JsonObj.GetValue<TJSONObject>('resource');
      if not Assigned(ResourceObj) then
        Exit;

      // Handle checkout order events (v2)
      if EventType = 'CHECKOUT.ORDER.APPROVED' then
      begin
        ANotification.TradeNo := ResourceObj.GetValue<string>('id', '');
        var UnitsArr := ResourceObj.GetValue<TJSONArray>('purchase_units');
        if Assigned(UnitsArr) and (UnitsArr.Count > 0) then
        begin
          var CustomId := UnitsArr.Items[0].FindValue('custom_id');
          if Assigned(CustomId) then
            ANotification.OrderNo := CustomId.Value;

          var AmountObj := UnitsArr.Items[0].FindValue('amount');
          if Assigned(AmountObj) then
          begin
            var Val := AmountObj.FindValue('value');
          if Assigned(Val) then
              ANotification.Amount := ParsePayPalAmount(Val.Value);
          end;
        end;
        ANotification.Status := psPending;  // Approved, needs capture
        Result := True;
      end
      else if EventType = 'CHECKOUT.ORDER.COMPLETED' then
      begin
        ANotification.TradeNo := ResourceObj.GetValue<string>('id', '');
        var UnitsArr2 := ResourceObj.GetValue<TJSONArray>('purchase_units');
        if Assigned(UnitsArr2) and (UnitsArr2.Count > 0) then
        begin
          var CustomId2 := UnitsArr2.Items[0].FindValue('custom_id');
          if Assigned(CustomId2) then
            ANotification.OrderNo := CustomId2.Value;
        end;
        ANotification.Status := psSuccess;
        ANotification.PaidAt := Now;
        Result := True;
      end
      // Payment capture events
      else if (EventType = 'PAYMENT.CAPTURE.COMPLETED') or
              (EventType = 'PAYMENT.CAPTURE.PENDING') then
      begin
        ANotification.TradeNo := ResourceObj.GetValue<string>('id', '');
        ANotification.OrderNo := ResourceObj.GetValue<string>('custom_id', '');
        var CapAmount := ResourceObj.FindValue('amount');
        if Assigned(CapAmount) then
        begin
          var Val := CapAmount.FindValue('value');
          if Assigned(Val) then
            ANotification.Amount := ParsePayPalAmount(Val.Value);
        end;

        if EventType = 'PAYMENT.CAPTURE.COMPLETED' then
          ANotification.Status := psSuccess
        else
          ANotification.Status := psPending;
        Result := True;
      end
      else if EventType = 'PAYMENT.CAPTURE.DENIED' then
      begin
        ANotification.TradeNo := ResourceObj.GetValue<string>('id', '');
        ANotification.OrderNo := ResourceObj.GetValue<string>('custom_id', '');
        ANotification.Status := psFailed;
        Result := True;
      end
      // Refund events
      else if (EventType = 'PAYMENT.CAPTURE.REFUNDED') or
              (EventType = 'PAYMENT.REFUND.COMPLETED') then
      begin
        ANotification.RefundTradeNo := ResourceObj.GetValue<string>('id', '');
        ANotification.RefundNo := ResourceObj.GetValue<string>('custom_id', '');
        var RefAmount := ResourceObj.FindValue('amount');
        if Assigned(RefAmount) then
        begin
          var Val := RefAmount.FindValue('value');
          if Assigned(Val) then
            ANotification.RefundAmount := ParsePayPalAmount(Val.Value);
        end;
        ANotification.RefundStatus := psRefunded;
        Result := True;
      end
      else if EventType = 'PAYMENT.REFUND.REVERSED' then
      begin
        ANotification.RefundTradeNo := ResourceObj.GetValue<string>('id', '');
        ANotification.RefundStatus := psFailed;
        Result := True;
      end;
    finally
      FreeAndNil(JsonObj);
    end;
  except
    Result := False;
  end;
end;

function TPayPalClient.GetNotificationResponse(ASuccess: Boolean): string;
begin
  // PayPal expects HTTP 200 for success
  if ASuccess then
    Result := '{"status": "ok"}'
  else
    Result := '{"status": "error", "message": "Processing failed"}';
end;

// BUG-015 FIX: PayPal webhook signature verification
function TPayPalClient.VerifyWebhookSignature(const APayload, ATransmissionId,
  ATimestamp, AWebhookSignature, ACrc: string): Boolean;
var
  Cfg: TPayPalConfig;
  Body, RespObj: TJSONObject;
  Status: string;
begin
  Result := False;
  Cfg := TPayPalConfig(FConfig);

  if Cfg.WebhookId = '' then
    raise EPaymentConfigError.Create('PayPal WebhookId not configured',
      'MISSING_WEBHOOK_ID', ppPayPal);

  // Use the PayPal Webhook Verification API
  // POST /v1/notifications/verify-webhook-signature
  Body := TJSONObject.Create;
  try
    Body.AddPair('transmission_id', ATransmissionId);
    Body.AddPair('transmission_time', ATimestamp);
    Body.AddPair('webhook_id', Cfg.WebhookId);
    Body.AddPair('webhook_signature', AWebhookSignature);
    Body.AddPair('transmission_sig', AWebhookSignature);

    // The actual_body is the CRC32 of the payload concatenated with the payload
    Body.AddPair('actual_body', APayload);

    try
      RespObj := DoPayPalPost('/v1/notifications/verify-webhook-signature', Body);
      try
        Status := RespObj.GetValue<string>('verification_status', '');
        Result := SameText(Status, 'SUCCESS');
      finally
        FreeAndNil(RespObj);
      end;
    except
      on E: EPaymentError do
        Result := False;
    end;
  finally
    FreeAndNil(Body);
  end;
end;

end.
