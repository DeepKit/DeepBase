unit DeepBase.Commerce.PaymentBridge;

{==============================================================================
  DeepBase.Commerce.PaymentBridge - Bridge ThirdParty Payment SDK to Commerce

  Bridges provider-specific payment notification verification from the
  ThirdParty/Payment SDK (DeepBase.Payment) to the Commerce framework's
  ICommerceNotificationVerifier interface.

  Usage:
    var Verifier := CreateAlipayNotificationVerifier(AppId, PrivKey, PubKey);
    Service.RegisterNotificationVerifier(cppAlipay, Verifier);
    Service.VerifyAndConfirmPayment(cppAlipay, RawBody, Headers);
==============================================================================}

interface

uses
  System.SysUtils,
  System.DateUtils,
  System.Generics.Collections,
  DeepBase.Payment,
  DeepBase.Payment.Alipay,
  DeepBase.Payment.WeChatPay,
  DeepBase.Payment.Stripe,
  DeepBase.Payment.PayPal,
  DeepBase.Commerce.Types,
  DeepBase.Commerce.Service;

type
  /// <summary>
  /// Generic notification verifier that wraps a callback function.
  /// </summary>
  TCallbackNotificationVerifier = class(TInterfacedObject, ICommerceNotificationVerifier)
  private
    FCallback: TFunc<string, TArray<TPair<string, string>>, TCommercePaymentNotification>;
  public
    constructor Create(ACallback: TFunc<string, TArray<TPair<string, string>>,
      TCommercePaymentNotification>);
    function VerifyNotification(const ARawBody: string;
      const AHeaders: TArray<TPair<string, string>>): TCommercePaymentNotification;
  end;

  /// <summary>
  /// Notification verifier wrapping an IPaymentClient from ThirdParty SDK.
  /// </summary>
  TSDKNotificationVerifier = class(TInterfacedObject, ICommerceNotificationVerifier)
  private
    FClient: IPaymentClient;
    FStripeClient: TStripeClient;
    FPayPalClient: TPayPalClient;
    FWeChatClient: TWeChatPayClient;
    FConfig: TPaymentConfig;
    FProvider: TCommercePaymentProvider;
    FCurrency: string;
  public
    constructor Create(AProvider: TCommercePaymentProvider;
      AClient: TObject; const ACurrency: string = 'CNY';
      AConfig: TPaymentConfig = nil);
    destructor Destroy; override;
    function VerifyNotification(const ARawBody: string;
      const AHeaders: TArray<TPair<string, string>>): TCommercePaymentNotification;
  end;

/// <summary>Create Alipay notification verifier</summary>
function CreateAlipayNotificationVerifier(
  const AAppId, APrivateKey, AAlipayPublicKey: string;
  const ACurrency: string = 'CNY'): ICommerceNotificationVerifier;

/// <summary>Create WeChat Pay notification verifier.
/// AWeChatPublicKey is the WeChat Pay platform public key (PEM) used for
/// SHA256-RSA2048 signature verification of V3 callbacks.
/// </summary>
function CreateWeChatPayNotificationVerifier(
  const AAppId, AMchId, AApiV3Key, AWeChatPublicKey: string;
  const ACurrency: string = 'CNY'): ICommerceNotificationVerifier;

/// <summary>Create Stripe notification verifier</summary>
function CreateStripeNotificationVerifier(
  const ASecretKey, AWebhookSecret: string;
  const ACurrency: string = 'USD'): ICommerceNotificationVerifier;

/// <summary>Create PayPal notification verifier</summary>
/// <param name="AWebhookId">PayPal webhook ID (required for signature
/// verification via /v1/notifications/verify-webhook-signature). When empty,
/// the verifier will fail closed with MISSING_WEBHOOK_ID on first use.</param>
function CreatePayPalNotificationVerifier(
  const AClientId, AClientSecret, AWebhookId: string;
  const ACurrency: string = 'USD'): ICommerceNotificationVerifier;

implementation

/// <summary>
/// Hard guard preventing PaymentBridge from being used outside server-side contexts.
/// This unit contains payment verification keys and must NEVER be linked into
/// desktop/mobile client builds. Use TDeepKitSafeClient for client-side commerce.
///
/// On DESKTOP builds the factory functions are compiled out entirely.
/// On server builds they are available normally.
/// </summary>
{$IFDEF DESKTOP}
function CreateAlipayNotificationVerifier(
  const AAppId, APrivateKey, AAlipayPublicKey: string;
  const ACurrency: string = 'CNY'): ICommerceNotificationVerifier;
begin
  raise EDeepBaseCommerceValidationError.Create(
    'PaymentBridge is not available in desktop builds. Use TDeepKitSafeClient.');
end;

function CreateWeChatPayNotificationVerifier(
  const AAppId, AMchId, AApiV3Key, AWeChatPublicKey: string;
  const ACurrency: string = 'CNY'): ICommerceNotificationVerifier;
begin
  raise EDeepBaseCommerceValidationError.Create(
    'PaymentBridge is not available in desktop builds. Use TDeepKitSafeClient.');
end;

function CreateStripeNotificationVerifier(
  const ASecretKey, AWebhookSecret: string;
  const ACurrency: string = 'USD'): ICommerceNotificationVerifier;
begin
  raise EDeepBaseCommerceValidationError.Create(
    'PaymentBridge is not available in desktop builds. Use TDeepKitSafeClient.');
end;

function CreatePayPalNotificationVerifier(
  const AClientId, AClientSecret, AWebhookId: string;
  const ACurrency: string = 'USD'): ICommerceNotificationVerifier;
begin
  raise EDeepBaseCommerceValidationError.Create(
    'PaymentBridge is not available in desktop builds. Use TDeepKitSafeClient.');
end;
{$ELSE}

{ TCallbackNotificationVerifier }

constructor TCallbackNotificationVerifier.Create(
  ACallback: TFunc<string, TArray<TPair<string, string>>, TCommercePaymentNotification>);
begin
  inherited Create;
  FCallback := ACallback;
end;

function TCallbackNotificationVerifier.VerifyNotification(const ARawBody: string;
  const AHeaders: TArray<TPair<string, string>>): TCommercePaymentNotification;
begin
  Result := FCallback(ARawBody, AHeaders);
end;

{ TSDKNotificationVerifier }

constructor TSDKNotificationVerifier.Create(AProvider: TCommercePaymentProvider;
  AClient: TObject; const ACurrency: string; AConfig: TPaymentConfig);
begin
  inherited Create;
  if not Supports(AClient, IPaymentClient, FClient) then
    raise EDeepBaseCommerceValidationError.Create('Payment client does not implement IPaymentClient');
  FStripeClient := nil;
  FPayPalClient := nil;
  FWeChatClient := nil;
  if AClient is TStripeClient then
    FStripeClient := TStripeClient(AClient)
  else if AClient is TPayPalClient then
    FPayPalClient := TPayPalClient(AClient)
  else if AClient is TWeChatPayClient then
    FWeChatClient := TWeChatPayClient(AClient);
  FConfig := AConfig;
  FProvider := AProvider;
  FCurrency := ACurrency;
end;

destructor TSDKNotificationVerifier.Destroy;
begin
  FConfig.Free;
  inherited;
end;

function TSDKNotificationVerifier.VerifyNotification(const ARawBody: string;
  const AHeaders: TArray<TPair<string, string>>): TCommercePaymentNotification;
var
  SDKNotif: TPaymentNotification;
  HeaderValue: string;

  function GetHeaderValue(const AName: string): string;
  var
    I: Integer;
  begin
    Result := '';
    for I := 0 to High(AHeaders) do
      if SameText(AHeaders[I].Key, AName) then
        Exit(AHeaders[I].Value);
  end;
begin
  // WeChat Pay V3: verify HTTP-level signature (SHA256-RSA2048) then
  // decrypt AES-256-GCM resource envelope
  if FProvider = cppWeChatPay then
  begin
    if FWeChatClient = nil then
      raise EDeepBaseCommercePaymentError.Create(
        'WeChat Pay client not available for notification verification');
    HeaderValue := GetHeaderValue('Wechatpay-Timestamp');
    // The SDK's VerifyNotificationWithSignature loads and uses the WeChat Pay
    // platform public key internally; a key-load or RSA failure surfaces as a
    // ThirdParty EPaymentSignError/EPaymentError. The Commerce bridge contract
    // (and the regression tests) expect the Commerce-domain
    // EDeepBaseCommercePaymentError — wrap any ThirdParty payment exception so
    // it never leaks through this API boundary.
    try
      if not FWeChatClient.VerifyNotificationWithSignature(
        ARawBody,
        HeaderValue,
        GetHeaderValue('Wechatpay-Nonce'),
        GetHeaderValue('Wechatpay-Signature'),
        SDKNotif) then
        raise EDeepBaseCommercePaymentError.Create(
          'WeChat Pay V3 notification verification failed');
    except
      on E: EDeepBaseCommercePaymentError do
        raise;
      on E: Exception do
        raise EDeepBaseCommercePaymentError.Create(
          'WeChat Pay V3 notification verification failed: ' + E.Message);
    end;
  end
  else
  begin
    // Alipay: FClient.VerifyNotification handles RSA2 signature verification internally
    if FProvider = cppStripe then
    begin
      HeaderValue := GetHeaderValue('Stripe-Signature');
      if not FStripeClient.VerifyWebhookSignature(ARawBody, HeaderValue) then
        raise EDeepBaseCommercePaymentError.Create('Stripe notification signature verification failed');
    end
    else if FProvider = cppPayPal then
    begin
      if not FPayPalClient.VerifyWebhookSignature(
        ARawBody,
        GetHeaderValue('Paypal-Transmission-Id'),
        GetHeaderValue('Paypal-Transmission-Time'),
        GetHeaderValue('Paypal-Transmission-Sig'),
        '') then
        raise EDeepBaseCommercePaymentError.Create('PayPal notification signature verification failed');
    end;

    if not FClient.VerifyNotification(ARawBody, SDKNotif) then
      raise EDeepBaseCommercePaymentError.CreateFmt(
        '%s notification verification failed',
        [CommercePaymentProviderToStr(FProvider)]);
  end;

  Result.Provider := FProvider;
  Result.OutTradeNo := SDKNotif.OrderNo;
  Result.ProviderTradeNo := SDKNotif.TradeNo;
  Result.Currency := FCurrency;
  if SameText(FCurrency, 'JPY') or SameText(FCurrency, 'KRW') then
    Result.AmountMinor := Round(SDKNotif.Amount)
  else
    Result.AmountMinor := Round(SDKNotif.Amount * 100);
  Result.Success := SDKNotif.Status = psSuccess;
  if SDKNotif.PaidAt > 0 then
    Result.PaidAtISO := DateToISO8601(SDKNotif.PaidAt, False)
  else
    Result.PaidAtISO := '';
  Result.RawPayload := SDKNotif.RawData;
end;

{ Factory functions - TSDKNotificationVerifier owns and frees the Config }

function CreateAlipayNotificationVerifier(
  const AAppId, APrivateKey, AAlipayPublicKey: string;
  const ACurrency: string): ICommerceNotificationVerifier;
var
  Config: TAlipayConfig;
begin
  Config := TAlipayConfig.Create;
  Config.AppId := AAppId;
  Config.PrivateKey := APrivateKey;
  Config.AlipayPublicKey := AAlipayPublicKey;
  Config.SignType := 'RSA2';
  Result := TSDKNotificationVerifier.Create(cppAlipay,
    TAlipayClient.Create(Config), ACurrency, Config);
end;

function CreateWeChatPayNotificationVerifier(
  const AAppId, AMchId, AApiV3Key, AWeChatPublicKey: string;
  const ACurrency: string): ICommerceNotificationVerifier;
var
  Config: TWeChatPayConfig;
  Client: TWeChatPayClient;
begin
  Config := TWeChatPayConfig.Create;
  Config.AppId := AAppId;
  Config.MchId := AMchId;
  Config.ApiKeyV3 := AApiV3Key;
  Config.WeChatPublicKey := AWeChatPublicKey;
  Client := TWeChatPayClient.Create(Config);
  Result := TSDKNotificationVerifier.Create(cppWeChatPay, Client, ACurrency, Config);
end;

function CreateStripeNotificationVerifier(
  const ASecretKey, AWebhookSecret: string;
  const ACurrency: string): ICommerceNotificationVerifier;
var
  Config: TStripeConfig;
begin
  Config := TStripeConfig.Create;
  Config.SecretKey := ASecretKey;
  Config.WebhookSecret := AWebhookSecret;
  Result := TSDKNotificationVerifier.Create(cppStripe,
    TStripeClient.Create(Config), ACurrency, Config);
end;

function CreatePayPalNotificationVerifier(
  const AClientId, AClientSecret, AWebhookId: string;
  const ACurrency: string): ICommerceNotificationVerifier;
var
  Config: TPayPalConfig;
begin
  Config := TPayPalConfig.Create;
  Config.ClientID := AClientId;
  Config.ClientSecret := AClientSecret;
  Config.WebhookId := AWebhookId;
  Result := TSDKNotificationVerifier.Create(cppPayPal,
    TPayPalClient.Create(Config), ACurrency, Config);
end;
{$ENDIF}

end.
