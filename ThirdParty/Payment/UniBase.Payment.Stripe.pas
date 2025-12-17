unit UniBase.Payment.Stripe;

{*******************************************************************************
  UniBase Stripe Payment Integration

  Supports:
    - Checkout Sessions (hosted payment page)
    - Payment Intents (custom integration)
    - Refunds
    - Webhooks

  Official Docs: https://stripe.com/docs/api
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.JSON, System.DateUtils, System.NetEncoding,
  UniBase.Payment;

type
  /// <summary>Stripe configuration</summary>
  TStripeConfig = class(TPaymentConfig)
  private
    FSecretKey: string;        // sk_test_xxx or sk_live_xxx
    FPublishableKey: string;   // pk_test_xxx or pk_live_xxx
    FWebhookSecret: string;    // whsec_xxx
    FApiVersion: string;
  public
    constructor Create; reintroduce;

    // BUG-019 FIX: 安全密钥存储方法重写
    procedure LoadKeysFromCredentialManager; override;
    procedure SaveKeysToCredentialManager; override;
    /// <summary>设置密钥（自动使用安全存储）</summary>
    procedure SetSecretKeySecure(const AKey: string);
    /// <summary>获取密钥（自动解密）</summary>
    function GetSecretKeySecure: string;
    /// <summary>设置Webhook密钥（自动使用安全存储）</summary>
    procedure SetWebhookSecretSecure(const AKey: string);
    /// <summary>获取Webhook密钥（自动解密）</summary>
    function GetWebhookSecretSecure: string;

    property SecretKey: string read FSecretKey write FSecretKey;
    property PublishableKey: string read FPublishableKey write FPublishableKey;
    property WebhookSecret: string read FWebhookSecret write FWebhookSecret;
    property ApiVersion: string read FApiVersion write FApiVersion;
  end;

  /// <summary>Stripe client implementation</summary>
  TStripeClient = class(TPaymentClient)
  private
    function GetApiUrl: string;
    function DoStripePost(const AEndpoint: string;
      const AParams: TDictionary<string, string>): TJSONObject;
    function DoStripeGet(const AEndpoint: string): TJSONObject;
    function ParseStripeStatus(const AStatus: string): TPaymentStatus;
  protected
    function SignRequest(const AParams: TDictionary<string, string>): string; override;
    function VerifySignature(const AParams: TDictionary<string, string>;
      const ASign: string): Boolean; override;
  public
    constructor Create(AConfig: TStripeConfig); reintroduce;

    // IPaymentClient
    function CreateOrder(const AOrder: TPaymentOrder): TPaymentResult; override;
    function QueryOrder(const AOrderNo: string): TPaymentQueryResult; override;
    function CloseOrder(const AOrderNo: string): Boolean; override;
    function Refund(const ARequest: TRefundRequest): TRefundResult; override;
    function QueryRefund(const ARefundNo: string): TRefundResult; override;
    function VerifyNotification(const ARawData: string;
      out ANotification: TPaymentNotification): Boolean; override;
    function GetNotificationResponse(ASuccess: Boolean): string; override;

    // Stripe specific
    function CreateCheckoutSession(const AOrder: TPaymentOrder): TPaymentResult;
    function CreatePaymentIntent(const AOrder: TPaymentOrder): TPaymentResult;
    function RetrievePaymentIntent(const APaymentIntentId: string): TPaymentQueryResult;
    function CancelPaymentIntent(const APaymentIntentId: string): Boolean;
    function ListPaymentMethods(const ACustomerId: string): TJSONArray;
    
    // BUG-015 FIX: Webhook signature verification
    /// <summary>
    /// Verify Stripe webhook signature before processing the payload.
    /// Call this method first with the Stripe-Signature header value.
    /// </summary>
    function VerifyWebhookSignature(const APayload, ASignatureHeader: string): Boolean;
  end;

implementation

uses
  System.Hash, System.StrUtils;

const
  STRIPE_API_URL = 'https://api.stripe.com/v1';
  STRIPE_API_VERSION = '2023-10-16';

{ TStripeConfig }

constructor TStripeConfig.Create;
begin
  inherited Create(ppStripe);
  FApiVersion := STRIPE_API_VERSION;
end;

// BUG-019 FIX: 安全密钥存储方法实现
procedure TStripeConfig.LoadKeysFromCredentialManager;
begin
  if KeyStorageMode = ksmCredential then
  begin
    FSecretKey := GetCredentialKey('SecretKey');
    FWebhookSecret := GetCredentialKey('WebhookSecret');
  end;
end;

procedure TStripeConfig.SaveKeysToCredentialManager;
begin
  if KeyStorageMode = ksmCredential then
  begin
    SetCredentialKey('SecretKey', FSecretKey);
    SetCredentialKey('WebhookSecret', FWebhookSecret);
  end;
end;

procedure TStripeConfig.SetSecretKeySecure(const AKey: string);
begin
  FSecretKey := ProtectKey(AKey);
end;

function TStripeConfig.GetSecretKeySecure: string;
begin
  Result := UnprotectKey(FSecretKey);
end;

procedure TStripeConfig.SetWebhookSecretSecure(const AKey: string);
begin
  FWebhookSecret := ProtectKey(AKey);
end;

function TStripeConfig.GetWebhookSecretSecure: string;
begin
  Result := UnprotectKey(FWebhookSecret);
end;

{ TStripeClient }

constructor TStripeClient.Create(AConfig: TStripeConfig);
begin
  inherited Create(AConfig);
end;

function TStripeClient.GetApiUrl: string;
begin
  Result := STRIPE_API_URL;
end;

function TStripeClient.SignRequest(const AParams: TDictionary<string, string>): string;
begin
  // Stripe uses Basic Auth, not request signing
  Result := '';
end;

function TStripeClient.VerifySignature(const AParams: TDictionary<string, string>;
  const ASign: string): Boolean;
begin
  // Webhook signature verification is handled differently
  Result := True;
end;

function TStripeClient.DoStripePost(const AEndpoint: string;
  const AParams: TDictionary<string, string>): TJSONObject;
var
  Cfg: TStripeConfig;
  PostData, Response: string;
  AuthStr: string;
begin
  Result := nil;
  Cfg := TStripeConfig(FConfig);

  // Set up Basic Auth
  AuthStr := TNetEncoding.Base64.Encode(Cfg.SecretKey + ':');
  FHttpClient.CustomHeaders['Authorization'] := 'Basic ' + AuthStr;
  FHttpClient.CustomHeaders['Stripe-Version'] := Cfg.ApiVersion;

  PostData := TPaymentHelper.BuildQueryString(AParams, True);
  Response := DoPost(GetApiUrl + AEndpoint, PostData);

  Result := TJSONObject.ParseJSONValue(Response) as TJSONObject;
  if not Assigned(Result) then
    raise EPaymentNetworkError.Create('Invalid JSON response', 'INVALID_JSON', ppStripe);

  // Check for error
  if Result.GetValue('error') <> nil then
  begin
    var ErrObj := Result.GetValue<TJSONObject>('error');
    var ErrType := ErrObj.GetValue<string>('type', '');
    var ErrMsg := ErrObj.GetValue<string>('message', '');
    var ErrCode := ErrObj.GetValue<string>('code', '');
    Result.Free;
    raise EPaymentBusinessError.Create(ErrMsg, ErrCode, ppStripe);
  end;
end;

function TStripeClient.DoStripeGet(const AEndpoint: string): TJSONObject;
var
  Cfg: TStripeConfig;
  AuthStr, Response: string;
begin
  Result := nil;
  Cfg := TStripeConfig(FConfig);

  AuthStr := TNetEncoding.Base64.Encode(Cfg.SecretKey + ':');
  FHttpClient.CustomHeaders['Authorization'] := 'Basic ' + AuthStr;
  FHttpClient.CustomHeaders['Stripe-Version'] := Cfg.ApiVersion;

  Response := DoGet(GetApiUrl + AEndpoint);

  Result := TJSONObject.ParseJSONValue(Response) as TJSONObject;
  if not Assigned(Result) then
    raise EPaymentNetworkError.Create('Invalid JSON response', 'INVALID_JSON', ppStripe);

  if Result.GetValue('error') <> nil then
  begin
    var ErrObj := Result.GetValue<TJSONObject>('error');
    var ErrMsg := ErrObj.GetValue<string>('message', '');
    var ErrCode := ErrObj.GetValue<string>('code', '');
    Result.Free;
    raise EPaymentBusinessError.Create(ErrMsg, ErrCode, ppStripe);
  end;
end;

function TStripeClient.ParseStripeStatus(const AStatus: string): TPaymentStatus;
begin
  if AStatus = 'requires_payment_method' then
    Result := psPending
  else if AStatus = 'requires_confirmation' then
    Result := psPending
  else if AStatus = 'requires_action' then
    Result := psPending
  else if AStatus = 'processing' then
    Result := psPending
  else if AStatus = 'succeeded' then
    Result := psSuccess
  else if AStatus = 'canceled' then
    Result := psClosed
  else if AStatus = 'requires_capture' then
    Result := psPending
  else
    Result := psUnknown;
end;

function TStripeClient.CreateOrder(const AOrder: TPaymentOrder): TPaymentResult;
begin
  // Default to Checkout Session
  Result := CreateCheckoutSession(AOrder);
end;

function TStripeClient.CreateCheckoutSession(const AOrder: TPaymentOrder): TPaymentResult;
var
  Params: TDictionary<string, string>;
  RespObj: TJSONObject;
  AmountCents: Int64;
begin
  Result.Clear;
  AOrder.Validate;

  // Stripe uses cents
  AmountCents := Round(AOrder.Amount * 100);

  Params := TDictionary<string, string>.Create;
  try
    Params.Add('mode', 'payment');
    Params.Add('line_items[0][price_data][currency]',
      IfThen(AOrder.Currency <> '', AOrder.Currency, 'usd').ToLower);
    Params.Add('line_items[0][price_data][product_data][name]', AOrder.Subject);
    Params.Add('line_items[0][price_data][unit_amount]', IntToStr(AmountCents));
    Params.Add('line_items[0][quantity]', '1');

    if AOrder.SuccessUrl <> '' then
      Params.Add('success_url', AOrder.SuccessUrl)
    else
      Params.Add('success_url', 'https://example.com/success');

    if AOrder.CancelUrl <> '' then
      Params.Add('cancel_url', AOrder.CancelUrl)
    else
      Params.Add('cancel_url', 'https://example.com/cancel');

    // Store merchant order number in metadata
    Params.Add('metadata[order_no]', AOrder.OrderNo);
    Params.Add('client_reference_id', AOrder.OrderNo);

    if AOrder.ExpireMinutes > 0 then
      Params.Add('expires_at', IntToStr(DateTimeToUnix(Now + AOrder.ExpireMinutes / 1440)));

    try
      RespObj := DoStripePost('/checkout/sessions', Params);
      try
        Result.Success := True;
        Result.OrderNo := AOrder.OrderNo;
        Result.TradeNo := RespObj.GetValue<string>('id', '');
        Result.PayUrl := RespObj.GetValue<string>('url', '');
      finally
        RespObj.Free;
      end;
    except
      on E: EPaymentError do
        Result := TPaymentResult.Fail(E.ErrorCode, E.Message);
    end;
  finally
    Params.Free;
  end;
end;

function TStripeClient.CreatePaymentIntent(const AOrder: TPaymentOrder): TPaymentResult;
var
  Params: TDictionary<string, string>;
  RespObj: TJSONObject;
  AmountCents: Int64;
begin
  Result.Clear;
  AOrder.Validate;

  AmountCents := Round(AOrder.Amount * 100);

  Params := TDictionary<string, string>.Create;
  try
    Params.Add('amount', IntToStr(AmountCents));
    Params.Add('currency', IfThen(AOrder.Currency <> '', AOrder.Currency, 'usd').ToLower);
    Params.Add('description', AOrder.Subject);
    Params.Add('metadata[order_no]', AOrder.OrderNo);

    // Automatic payment methods
    Params.Add('automatic_payment_methods[enabled]', 'true');

    try
      RespObj := DoStripePost('/payment_intents', Params);
      try
        Result.Success := True;
        Result.OrderNo := AOrder.OrderNo;
        Result.TradeNo := RespObj.GetValue<string>('id', '');
        Result.PrepayId := RespObj.GetValue<string>('client_secret', '');

        // Build params for frontend SDK
        var ParamsJson := TJSONObject.Create;
        try
          ParamsJson.AddPair('clientSecret', Result.PrepayId);
          ParamsJson.AddPair('publishableKey', TStripeConfig(FConfig).PublishableKey);
          Result.AppPayParams := ParamsJson.ToString;
        finally
          ParamsJson.Free;
        end;
      finally
        RespObj.Free;
      end;
    except
      on E: EPaymentError do
        Result := TPaymentResult.Fail(E.ErrorCode, E.Message);
    end;
  finally
    Params.Free;
  end;
end;

function TStripeClient.QueryOrder(const AOrderNo: string): TPaymentQueryResult;
begin
  // Stripe doesn't query by merchant order number directly
  // Need to retrieve by Payment Intent ID or search
  Result := RetrievePaymentIntent(AOrderNo);
end;

function TStripeClient.RetrievePaymentIntent(const APaymentIntentId: string): TPaymentQueryResult;
var
  RespObj: TJSONObject;
begin
  Result.Clear;

  try
    RespObj := DoStripeGet('/payment_intents/' + APaymentIntentId);
    try
      Result.Success := True;
      Result.TradeNo := RespObj.GetValue<string>('id', '');
      Result.OrderNo := RespObj.GetValue<string>('metadata.order_no', '');
      Result.Amount := RespObj.GetValue<Int64>('amount', 0) / 100;
      Result.PaidAmount := RespObj.GetValue<Int64>('amount_received', 0) / 100;
      Result.Status := ParseStripeStatus(RespObj.GetValue<string>('status', ''));
      Result.RawResponse := RespObj.ToString;
    finally
      RespObj.Free;
    end;
  except
    on E: EPaymentError do
    begin
      Result.ErrorCode := E.ErrorCode;
      Result.ErrorMessage := E.Message;
    end;
  end;
end;

function TStripeClient.CloseOrder(const AOrderNo: string): Boolean;
begin
  Result := CancelPaymentIntent(AOrderNo);
end;

function TStripeClient.CancelPaymentIntent(const APaymentIntentId: string): Boolean;
var
  Params: TDictionary<string, string>;
  RespObj: TJSONObject;
begin
  Result := False;

  Params := TDictionary<string, string>.Create;
  try
    try
      RespObj := DoStripePost('/payment_intents/' + APaymentIntentId + '/cancel', Params);
      try
        Result := RespObj.GetValue<string>('status', '') = 'canceled';
      finally
        RespObj.Free;
      end;
    except
      on E: EPaymentError do
        Result := False;
    end;
  finally
    Params.Free;
  end;
end;

function TStripeClient.Refund(const ARequest: TRefundRequest): TRefundResult;
var
  Params: TDictionary<string, string>;
  RespObj: TJSONObject;
  AmountCents: Int64;
begin
  Result.Clear;
  ARequest.Validate;

  AmountCents := Round(ARequest.RefundAmount * 100);

  Params := TDictionary<string, string>.Create;
  try
    Params.Add('payment_intent', ARequest.OrderNo);  // Actually the Payment Intent ID
    if ARequest.RefundAmount > 0 then
      Params.Add('amount', IntToStr(AmountCents));
    if ARequest.Reason <> '' then
      Params.Add('reason', 'requested_by_customer');
    Params.Add('metadata[refund_no]', ARequest.RefundNo);

    try
      RespObj := DoStripePost('/refunds', Params);
      try
        Result.Success := True;
        Result.RefundNo := ARequest.RefundNo;
        Result.RefundTradeNo := RespObj.GetValue<string>('id', '');
        Result.RefundAmount := RespObj.GetValue<Int64>('amount', 0) / 100;

        if RespObj.GetValue<string>('status', '') = 'succeeded' then
          Result.Status := psRefunded
        else
          Result.Status := psRefunding;
      finally
        RespObj.Free;
      end;
    except
      on E: EPaymentError do
        Result := TRefundResult.Fail(E.ErrorCode, E.Message);
    end;
  finally
    Params.Free;
  end;
end;

function TStripeClient.QueryRefund(const ARefundNo: string): TRefundResult;
var
  RespObj: TJSONObject;
begin
  Result.Clear;

  try
    RespObj := DoStripeGet('/refunds/' + ARefundNo);
    try
      Result.Success := True;
      Result.RefundTradeNo := RespObj.GetValue<string>('id', '');
      Result.RefundNo := RespObj.GetValue<string>('metadata.refund_no', '');
      Result.RefundAmount := RespObj.GetValue<Int64>('amount', 0) / 100;

      if RespObj.GetValue<string>('status', '') = 'succeeded' then
        Result.Status := psRefunded
      else if RespObj.GetValue<string>('status', '') = 'pending' then
        Result.Status := psRefunding
      else
        Result.Status := psFailed;
    finally
      RespObj.Free;
    end;
  except
    on E: EPaymentError do
      Result := TRefundResult.Fail(E.ErrorCode, E.Message);
  end;
end;

function TStripeClient.VerifyNotification(const ARawData: string;
  out ANotification: TPaymentNotification): Boolean;
var
  Cfg: TStripeConfig;
  JsonObj, DataObj, ObjData: TJSONObject;
  EventType, ObjType: string;
begin
  Result := False;
  ANotification.Clear;
  ANotification.Provider := ppStripe;
  ANotification.RawData := ARawData;

  Cfg := TStripeConfig(FConfig);

  // BUG-015 FIX: Webhook signature verification is now required
  // Note: The signature header must be passed separately via VerifyWebhookSignature
  // This method only parses the payload after signature is verified
  if Cfg.WebhookSecret = '' then
  begin
    {$IFDEF DEBUG}
    OutputDebugString('WARNING: Stripe webhook secret not configured');
    {$ENDIF}
    // In production, we should fail if webhook secret is not configured
    if not Cfg.IsSandbox then
      Exit;
  end;

  try
    JsonObj := TJSONObject.ParseJSONValue(ARawData) as TJSONObject;
    if not Assigned(JsonObj) then
      Exit;

    try
      EventType := JsonObj.GetValue<string>('type', '');
      DataObj := JsonObj.GetValue<TJSONObject>('data');
      if not Assigned(DataObj) then
        Exit;

      ObjData := DataObj.GetValue<TJSONObject>('object');
      if not Assigned(ObjData) then
        Exit;

      ObjType := ObjData.GetValue<string>('object', '');

      // Handle different event types
      if EventType = 'payment_intent.succeeded' then
      begin
        ANotification.TradeNo := ObjData.GetValue<string>('id', '');
        ANotification.OrderNo := ObjData.GetValue<string>('metadata.order_no', '');
        ANotification.Amount := ObjData.GetValue<Int64>('amount', 0) / 100;
        ANotification.Status := psSuccess;
        Result := True;
      end
      else if EventType = 'payment_intent.payment_failed' then
      begin
        ANotification.TradeNo := ObjData.GetValue<string>('id', '');
        ANotification.OrderNo := ObjData.GetValue<string>('metadata.order_no', '');
        ANotification.Status := psFailed;
        Result := True;
      end
      else if EventType = 'checkout.session.completed' then
      begin
        ANotification.TradeNo := ObjData.GetValue<string>('id', '');
        ANotification.OrderNo := ObjData.GetValue<string>('client_reference_id', '');
        ANotification.Amount := ObjData.GetValue<Int64>('amount_total', 0) / 100;
        ANotification.Status := psSuccess;
        Result := True;
      end
      else if EventType = 'charge.refunded' then
      begin
        ANotification.TradeNo := ObjData.GetValue<string>('payment_intent', '');
        ANotification.RefundAmount := ObjData.GetValue<Int64>('amount_refunded', 0) / 100;
        ANotification.RefundStatus := psRefunded;
        Result := True;
      end;
    finally
      JsonObj.Free;
    end;
  except
    Result := False;
  end;
end;

function TStripeClient.GetNotificationResponse(ASuccess: Boolean): string;
begin
  // Stripe expects HTTP 200 for success
  if ASuccess then
    Result := '{"received": true}'
  else
    Result := '{"error": "Processing failed"}';
end;

// BUG-015 FIX: Implement Stripe webhook signature verification
function TStripeClient.VerifyWebhookSignature(const APayload, ASignatureHeader: string): Boolean;
var
  Cfg: TStripeConfig;
  Parts, SigParts: TArray<string>;
  Part, Timestamp, Signature, ExpectedSig: string;
  SignedPayload: string;
  TimestampInt, CurrentTime: Int64;
  I, Diff: Integer;
const
  // BUG-109 FIX: 将时间戳容差从300秒降低到120秒以减少重放攻击风险
  // 原来是5分钟，现在改为2分钟，在保证正常请求通过的同时减少攻击窗口
  TOLERANCE_SECONDS = 120; // 2 minutes tolerance (reduced from 5 minutes)
begin
  Result := False;
  Cfg := TStripeConfig(FConfig);
  
  if Cfg.WebhookSecret = '' then
  begin
    raise EPaymentException.Create('Stripe webhook secret not configured');
  end;
  
  // Parse signature header: t=timestamp,v1=signature
  Timestamp := '';
  Signature := '';
  Parts := ASignatureHeader.Split([',']);
  for Part in Parts do
  begin
    SigParts := Part.Split(['=']);
    if Length(SigParts) = 2 then
    begin
      if SigParts[0] = 't' then
        Timestamp := SigParts[1]
      else if SigParts[0] = 'v1' then
        Signature := SigParts[1];
    end;
  end;
  
  if (Timestamp = '') or (Signature = '') then
    Exit;
  
  // Verify timestamp is within tolerance
  TimestampInt := StrToInt64Def(Timestamp, 0);
  CurrentTime := DateTimeToUnix(Now, False);
  if Abs(CurrentTime - TimestampInt) > TOLERANCE_SECONDS then
    Exit; // Timestamp too old or in future
  
  // Compute expected signature: HMAC-SHA256(timestamp + '.' + payload, secret)
  SignedPayload := Timestamp + '.' + APayload;
  ExpectedSig := THashSHA2.GetHMAC(SignedPayload, Cfg.WebhookSecret, SHA256);
  ExpectedSig := LowerCase(ExpectedSig);
  
  // Constant-time comparison to prevent timing attacks
  if Length(ExpectedSig) <> Length(Signature) then
    Exit;
  
  Diff := 0;
  for I := 1 to Length(ExpectedSig) do
    Diff := Diff or (Ord(ExpectedSig[I]) xor Ord(LowerCase(Signature)[I]));
  
  Result := Diff = 0;
end;

function TStripeClient.ListPaymentMethods(const ACustomerId: string): TJSONArray;
var
  RespObj: TJSONObject;
begin
  Result := nil;

  try
    RespObj := DoStripeGet('/payment_methods?customer=' + ACustomerId + '&type=card');
    try
      if RespObj.GetValue('data') is TJSONArray then
        Result := TJSONArray(RespObj.GetValue('data').Clone);
    finally
      RespObj.Free;
    end;
  except
    Result := nil;
  end;
end;

end.
