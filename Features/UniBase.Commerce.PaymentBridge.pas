unit UniBase.Commerce.PaymentBridge;

{==============================================================================
  UniBase.Commerce.PaymentBridge - Bridge ThirdParty Payment SDK to Commerce

  Bridges provider-specific payment notification verification from the
  ThirdParty/Payment SDK (UniBase.Payment) to the Commerce framework's
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
  UniBase.Commerce.Types,
  UniBase.Commerce.Service;

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
    FClient: IInterface;
    FProvider: TCommercePaymentProvider;
    FCurrency: string;
  public
    constructor Create(AProvider: TCommercePaymentProvider;
      const AClient: IInterface; const ACurrency: string = 'CNY');
    function VerifyNotification(const ARawBody: string;
      const AHeaders: TArray<TPair<string, string>>): TCommercePaymentNotification;
  end;

/// <summary>Create Alipay notification verifier</summary>
function CreateAlipayNotificationVerifier(
  const AAppId, APrivateKey, AAlipayPublicKey: string;
  const ACurrency: string = 'CNY'): ICommerceNotificationVerifier;

/// <summary>Create WeChat Pay notification verifier</summary>
function CreateWeChatPayNotificationVerifier(
  const AAppId, AMchId, AApiV3Key: string;
  const ACurrency: string = 'CNY'): ICommerceNotificationVerifier;

/// <summary>Create Stripe notification verifier</summary>
function CreateStripeNotificationVerifier(
  const ASecretKey, AWebhookSecret: string;
  const ACurrency: string = 'USD'): ICommerceNotificationVerifier;

/// <summary>Create PayPal notification verifier</summary>
function CreatePayPalNotificationVerifier(
  const AClientId, AClientSecret: string;
  const ACurrency: string = 'USD'): ICommerceNotificationVerifier;

implementation

uses
  UniBase.Payment,
  UniBase.Payment.Alipay,
  UniBase.Payment.WeChatPay,
  UniBase.Payment.Stripe,
  UniBase.Payment.PayPal;

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
  const AClient: IInterface; const ACurrency: string);
begin
  inherited Create;
  FClient := AClient;
  FProvider := AProvider;
  FCurrency := ACurrency;
end;

function TSDKNotificationVerifier.VerifyNotification(const ARawBody: string;
  const AHeaders: TArray<TPair<string, string>>): TCommercePaymentNotification;
var
  Client: IPaymentClient;
  SDKNotif: TPaymentNotification;
begin
  Client := FClient as IPaymentClient;
  if not Client.VerifyNotification(ARawBody, SDKNotif) then
    raise EUniBaseCommercePaymentError.CreateFmt(
      '%s notification verification failed',
      [CommercePaymentProviderToStr(FProvider)]);

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

{ Factory functions - client owns the config }

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
    TAlipayClient.Create(Config), ACurrency);
end;

function CreateWeChatPayNotificationVerifier(
  const AAppId, AMchId, AApiV3Key: string;
  const ACurrency: string): ICommerceNotificationVerifier;
var
  Config: TWeChatPayConfig;
begin
  Config := TWeChatPayConfig.Create;
  Config.AppId := AAppId;
  Config.MchId := AMchId;
  Config.ApiKeyV3 := AApiV3Key;
  Result := TSDKNotificationVerifier.Create(cppWeChatPay,
    TWeChatPayClient.Create(Config), ACurrency);
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
    TStripeClient.Create(Config), ACurrency);
end;

function CreatePayPalNotificationVerifier(
  const AClientId, AClientSecret: string;
  const ACurrency: string): ICommerceNotificationVerifier;
var
  Config: TPayPalConfig;
begin
  Config := TPayPalConfig.Create;
  Config.ClientID := AClientId;
  Config.ClientSecret := AClientSecret;
  Result := TSDKNotificationVerifier.Create(cppPayPal,
    TPayPalClient.Create(Config), ACurrency);
end;

end.
