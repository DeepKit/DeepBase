unit DeepBase.Commerce.SDKGateway;

{==============================================================================
  DeepBase.Commerce.SDKGateway - Bridge Payment SDK to Commerce Gateway

  Bridges the ThirdParty Payment SDK (DeepBase.Payment) to the Commerce
  framework's ICommercePaymentGateway interface.  Allows apps to use
  payment providers directly (not through an HTTP backend).

  Usage:
    var Gateway := CreateWeChatPayGateway(AppId, MchId, ApiKeyV3, NotifyUrl);
    Service.RegisterPaymentGateway(cppWeChatPay, Gateway);
==============================================================================}

interface

uses
  System.SysUtils,
  DeepBase.Payment,
  DeepBase.Commerce.Types,
  DeepBase.Commerce.Service;

type
  /// <summary>
  /// Adapter that wraps an IPaymentClient from DeepBase.Payment into
  /// the ICommercePaymentGateway interface used by TDeepBaseCommerceService.
  /// </summary>
  TSDKPaymentGatewayAdapter = class(TInterfacedObject, ICommercePaymentGateway)
  private
    FClient: IPaymentClient;
    FConfig: TPaymentConfig;
    FNotifyUrl: string;
    function MapChannel(AChannel: TCommercePaymentChannel): TPaymentMethod;
  public
    constructor Create(const AClient: IPaymentClient;
      const ANotifyUrl: string = '';
      AConfig: TPaymentConfig = nil);
    destructor Destroy; override;

    function CreatePaymentIntent(const AOrder: TCommerceOrderData;
      const APayment: TCommercePaymentData;
      const APayerOpenId: string): TCommercePaymentIntent;
  end;

/// <summary>Create WeChat Pay gateway backed by TWeChatPayClient</summary>
function CreateWeChatPayGateway(const AAppId, AMchId, AApiKeyV3,
  ANotifyUrl: string): ICommercePaymentGateway;

/// <summary>Create Alipay gateway backed by TAlipayClient</summary>
function CreateAlipayGateway(const AAppId, APrivateKey,
  AAlipayPublicKey, ANotifyUrl: string): ICommercePaymentGateway;

/// <summary>Create Stripe gateway backed by TStripeClient</summary>
function CreateStripeGateway(const ASecretKey,
  ANotifyUrl: string): ICommercePaymentGateway;

/// <summary>Create PayPal gateway backed by TPayPalClient</summary>
function CreatePayPalGateway(const AClientId, AClientSecret,
  ANotifyUrl: string): ICommercePaymentGateway;

implementation

uses
  System.Generics.Collections,
  DeepBase.Payment.Alipay,
  DeepBase.Payment.WeChatPay,
  DeepBase.Payment.Stripe,
  DeepBase.Payment.PayPal;

{ Helpers }

function MinorUnitsToAmount(AMinorUnits: Int64;
  const ACurrency: string): Currency;
begin
  if SameText(ACurrency, 'JPY') or SameText(ACurrency, 'KRW') then
    Result := AMinorUnits
  else
    Result := AMinorUnits / 100;
end;

{ TSDKPaymentGatewayAdapter }

constructor TSDKPaymentGatewayAdapter.Create(const AClient: IPaymentClient;
  const ANotifyUrl: string; AConfig: TPaymentConfig);
begin
  inherited Create;
  if not Assigned(AClient) then
    raise EArgumentNilException.Create('AClient must not be nil');
  FClient := AClient;
  FConfig := AConfig;
  FNotifyUrl := ANotifyUrl;
end;

destructor TSDKPaymentGatewayAdapter.Destroy;
begin
  FConfig.Free;
  inherited;
end;

function TSDKPaymentGatewayAdapter.MapChannel(
  AChannel: TCommercePaymentChannel): TPaymentMethod;
begin
  case AChannel of
    cpcNative:       Result := pmQRCode;
    cpcJSAPI:        Result := pmMiniProgram;
    cpcMiniProgram:  Result := pmMiniProgram;
    cpcH5:           Result := pmH5;
    cpcApp:          Result := pmApp;
    cpcWeb:          Result := pmWebPage;
  else
    Result := pmDefault;
  end;
end;

function TSDKPaymentGatewayAdapter.CreatePaymentIntent(
  const AOrder: TCommerceOrderData;
  const APayment: TCommercePaymentData;
  const APayerOpenId: string): TCommercePaymentIntent;
var
  Order: TPaymentOrder;
  PayResult: TPaymentResult;
  ClientParams: string;
begin
  // Build the SDK payment order from commerce data
  Order := Default(TPaymentOrder);
  Order.OrderNo := AOrder.OutTradeNo;
  Order.Amount := MinorUnitsToAmount(AOrder.AmountMinor, AOrder.Currency);
  Order.Currency := AOrder.Currency;
  Order.Subject := AOrder.Title;
  Order.Body := AOrder.ProductId;
  Order.NotifyUrl := FNotifyUrl;
  Order.PaymentMethod := MapChannel(APayment.Channel);
  if APayerOpenId <> '' then
  begin
    if not Assigned(Order.Metadata) then
      Order.Metadata := TDictionary<string, string>.Create;
    Order.Metadata.AddOrSetValue('payer_openid', APayerOpenId);
  end;

  // Execute payment via the SDK client
  try
    PayResult := FClient.CreateOrder(Order);
  finally
    // FEAT-004: Use FreeAndNil with nil check to prevent freeing
    // an uninitialized or already-freed pointer.
    if Assigned(Order.Metadata) then
      FreeAndNil(Order.Metadata);
  end;

  // Map SDK result to commerce payment intent
  Result.Success := PayResult.Success;
  Result.PaymentId := '';
  Result.OutTradeNo := AOrder.OutTradeNo;
  Result.PrepayId := PayResult.PrepayId;
  Result.PayUrl := PayResult.PayUrl;
  Result.QRCodeData := PayResult.QRCodeData;

  // Determine client params from SDK result
  ClientParams := PayResult.AppPayParams;
  if ClientParams = '' then
    ClientParams := PayResult.QRCodeUrl;
  Result.ClientParamsJson := ClientParams;

  Result.RawResponse := PayResult.TradeNo;
  Result.ErrorCode := PayResult.ErrorCode;
  Result.ErrorMessage := PayResult.ErrorMessage;
end;

{ Factory functions }

function CreateWeChatPayGateway(const AAppId, AMchId, AApiKeyV3,
  ANotifyUrl: string): ICommercePaymentGateway;
var
  Config: TWeChatPayConfig;
  Client: IPaymentClient;
begin
  Config := TWeChatPayConfig.Create;
  Config.AppId := AAppId;
  Config.MchId := AMchId;
  Config.ApiKeyV3 := AApiKeyV3;
  Client := TWeChatPayClient.Create(Config);
  Result := TSDKPaymentGatewayAdapter.Create(Client, ANotifyUrl, Config);
end;

function CreateAlipayGateway(const AAppId, APrivateKey,
  AAlipayPublicKey, ANotifyUrl: string): ICommercePaymentGateway;
var
  Config: TAlipayConfig;
  Client: IPaymentClient;
begin
  Config := TAlipayConfig.Create;
  Config.AppId := AAppId;
  Config.PrivateKey := APrivateKey;
  Config.AlipayPublicKey := AAlipayPublicKey;
  Config.SignType := 'RSA2';
  Client := TAlipayClient.Create(Config);
  Result := TSDKPaymentGatewayAdapter.Create(Client, ANotifyUrl, Config);
end;

function CreateStripeGateway(const ASecretKey,
  ANotifyUrl: string): ICommercePaymentGateway;
var
  Config: TStripeConfig;
  Client: IPaymentClient;
begin
  Config := TStripeConfig.Create;
  Config.SecretKey := ASecretKey;
  Client := TStripeClient.Create(Config);
  Result := TSDKPaymentGatewayAdapter.Create(Client, ANotifyUrl, Config);
end;

function CreatePayPalGateway(const AClientId, AClientSecret,
  ANotifyUrl: string): ICommercePaymentGateway;
var
  Config: TPayPalConfig;
  Client: IPaymentClient;
begin
  Config := TPayPalConfig.Create;
  Config.ClientID := AClientId;
  Config.ClientSecret := AClientSecret;
  Client := TPayPalClient.Create(Config);
  Result := TSDKPaymentGatewayAdapter.Create(Client, ANotifyUrl, Config);
end;

end.
