unit DeepBase.Payment.Types;

{*******************************************************************************
  DeepBase Payment Types

  Canonical type definitions shared by DeepBase.Payment and DeepBase.Payment.Core.
  Supports: Alipay, WeChat Pay, Stripe, PayPal
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections;

type
  /// <summary>Supported payment providers</summary>
  TPaymentProvider = (
    ppAlipay,      // Alipay (China)
    ppWeChatPay,   // WeChat Pay (China)
    ppStripe,      // Stripe (International)
    ppPayPal       // PayPal (International)
  );

  /// <summary>Payment environment</summary>
  TPaymentEnvironment = (
    peSandbox,     // Test/Development
    peProduction   // Live/Production
  );

  /// <summary>Payment status</summary>
  TPaymentStatus = (
    psUnknown,       // Unknown
    psPending,       // Payment initiated, awaiting completion
    psSuccess,       // Payment completed successfully
    psFailed,        // Payment failed
    psClosed,        // Order closed/cancelled
    psRefunding,     // Refund in progress
    psRefunded,      // Fully refunded
    psPartialRefund  // Partially refunded
  );

  /// <summary>Payment method type</summary>
  TPaymentMethodType = (
    pmtCard,           // Credit/Debit card
    pmtBankTransfer,   // Bank transfer
    pmtWallet,         // Digital wallet (Alipay, WeChat, etc.)
    pmtBuyNowPayLater, // BNPL services
    pmtCrypto          // Cryptocurrency
  );

  /// <summary>Currency code (ISO 4217)</summary>
  TCurrencyCode = string;  // e.g., 'USD', 'CNY', 'EUR'

  /// <summary>Payment provider credentials</summary>
  TPaymentCredentials = record
    Provider: TPaymentProvider;
    Environment: TPaymentEnvironment;

    // Common
    ApiKey: string;          // Public/Publishable key
    SecretKey: string;       // Secret/Private key
    WebhookSecret: string;   // Webhook signing secret

    // Alipay specific
    AppId: string;           // Alipay App ID
    PrivateKey: string;      // RSA Private Key
    AlipayPublicKey: string; // Alipay Public Key

    // WeChat Pay specific
    MchId: string;           // Merchant ID
    ApiV3Key: string;        // API v3 Key
    CertSerialNo: string;    // Certificate serial number

    // Custom endpoint (for testing)
    CustomEndpoint: string;

    class function ForStripe(const ASecretKey: string;
      AEnv: TPaymentEnvironment = peSandbox): TPaymentCredentials; static;
    class function ForPayPal(const AClientId, AClientSecret: string;
      AEnv: TPaymentEnvironment = peSandbox): TPaymentCredentials; static;
    class function ForAlipay(const AAppId, APrivateKey, AAlipayPublicKey: string;
      AEnv: TPaymentEnvironment = peSandbox): TPaymentCredentials; static;
    class function ForWeChatPay(const AAppId, AMchId, AApiKey: string;
      AEnv: TPaymentEnvironment = peSandbox): TPaymentCredentials; static;
  end;

  /// <summary>Money amount with currency</summary>
  TMoney = record
    Amount: Currency;      // Decimal amount (e.g., 99.99)
    CurrencyCode: TCurrencyCode;

    constructor Create(AAmount: Currency; const ACurrency: TCurrencyCode);
    function ToMinorUnits: Int64;  // Convert to cents/fen
    function ToString: string;
    class function FromMinorUnits(AMinorUnits: Int64; const ACurrency: TCurrencyCode): TMoney; static;
  end;

  /// <summary>Customer information</summary>
  TPaymentCustomer = record
    Id: string;            // Customer ID in your system
    Email: string;
    Phone: string;
    Name: string;

    // Address
    AddressLine1: string;
    AddressLine2: string;
    City: string;
    State: string;
    PostalCode: string;
    Country: string;       // ISO 3166-1 alpha-2

    // Provider customer IDs
    StripeCustomerId: string;
    PayPalPayerId: string;
    AlipayUserId: string;
    WeChatOpenId: string;
  end;

  /// <summary>Line item for order</summary>
  TPaymentLineItem = record
    Name: string;
    Description: string;
    Quantity: Integer;
    UnitPrice: TMoney;

    function TotalPrice: TMoney;
  end;

  /// <summary>Payment request</summary>
  TPaymentRequest = record
    // Identification
    OrderId: string;           // Your order ID
    IdempotencyKey: string;    // Prevent duplicate charges

    // Amount
    Amount: TMoney;

    // Customer
    Customer: TPaymentCustomer;

    // Items (optional)
    LineItems: TArray<TPaymentLineItem>;

    // Description
    Description: string;
    StatementDescriptor: string;  // Appears on bank statement

    // Metadata
    Metadata: TDictionary<string, string>;

    // Callbacks
    ReturnUrl: string;         // Success redirect URL
    CancelUrl: string;         // Cancel redirect
    NotifyUrl: string;         // Webhook notification URL

    // Options
    CaptureMethod: (cmAutomatic, cmManual);  // Authorize now, capture later
    ExpiresAt: TDateTime;      // Payment link expiration

    constructor Create(const AOrderId: string; AAmount: TMoney);
    procedure AddLineItem(const AItem: TPaymentLineItem);
    procedure SetMetadata(const AKey, AValue: string);
    procedure Cleanup;
  end;

  /// <summary>Payment result</summary>
  TPaymentResult = record
    Success: Boolean;

    // Transaction info
    TransactionId: string;     // Provider's transaction ID
    Status: TPaymentStatus;

    // Amounts
    AmountReceived: TMoney;
    AmountRefunded: TMoney;
    Fee: TMoney;               // Provider fee
    Net: TMoney;               // Net amount after fees

    // Redirect (for hosted checkout)
    RedirectUrl: string;       // URL to redirect customer
    QRCodeUrl: string;         // QR code image URL (Alipay/WeChat)
    QRCodeData: string;        // Raw QR code data

    // Error info
    ErrorCode: string;
    ErrorMessage: string;
    DeclineCode: string;       // Card decline reason

    // Raw response
    RawResponse: string;       // JSON response from provider

    // Timestamps
    CreatedAt: TDateTime;
    UpdatedAt: TDateTime;

    class function Succeeded(const ATransactionId: string;
      AAmount: TMoney): TPaymentResult; static;
    class function Failed(const AErrorCode, AErrorMessage: string): TPaymentResult; static;
    class function Pending(const ATransactionId, ARedirectUrl: string): TPaymentResult; static;
  end;

  /// <summary>Refund request</summary>
  TRefundRequest = record
    TransactionId: string;     // Original transaction ID
    Amount: TMoney;            // Amount to refund (empty = full refund)
    Reason: string;
    IdempotencyKey: string;
  end;

  /// <summary>Refund result</summary>
  TRefundResult = record
    Success: Boolean;
    RefundId: string;
    Status: TPaymentStatus;
    Amount: TMoney;
    ErrorCode: string;
    ErrorMessage: string;
    RawResponse: string;
  end;

  /// <summary>Webhook event</summary>
  TWebhookEvent = record
    Id: string;
    EventType: string;         // e.g., 'payment.succeeded', 'refund.created'
    Provider: TPaymentProvider;
    TransactionId: string;
    Status: TPaymentStatus;
    Amount: TMoney;
    RawPayload: string;
    Timestamp: TDateTime;
    Verified: Boolean;         // Signature verified
  end;

  /// <summary>Payment error exception</summary>
  EPaymentError = class(Exception)
  public
    ErrorCode: string;
    Provider: TPaymentProvider;
    constructor Create(const AMessage: string; const AErrorCode: string = '';
      AProvider: TPaymentProvider = ppAlipay); reintroduce;
  end;

// Helper functions
function PaymentProviderToStr(AProvider: TPaymentProvider): string;
function StrToPaymentProvider(const AStr: string): TPaymentProvider;
function PaymentStatusToStr(AStatus: TPaymentStatus): string;
function StrToPaymentStatus(const AStr: string): TPaymentStatus;

implementation

{ TPaymentCredentials }

class function TPaymentCredentials.ForStripe(const ASecretKey: string;
  AEnv: TPaymentEnvironment): TPaymentCredentials;
begin
  Result := Default(TPaymentCredentials);
  Result.Provider := ppStripe;
  Result.Environment := AEnv;
  Result.SecretKey := ASecretKey;
end;

class function TPaymentCredentials.ForPayPal(const AClientId, AClientSecret: string;
  AEnv: TPaymentEnvironment): TPaymentCredentials;
begin
  Result := Default(TPaymentCredentials);
  Result.Provider := ppPayPal;
  Result.Environment := AEnv;
  Result.ApiKey := AClientId;
  Result.SecretKey := AClientSecret;
end;

class function TPaymentCredentials.ForAlipay(const AAppId, APrivateKey, AAlipayPublicKey: string;
  AEnv: TPaymentEnvironment): TPaymentCredentials;
begin
  Result := Default(TPaymentCredentials);
  Result.Provider := ppAlipay;
  Result.Environment := AEnv;
  Result.AppId := AAppId;
  Result.PrivateKey := APrivateKey;
  Result.AlipayPublicKey := AAlipayPublicKey;
end;

class function TPaymentCredentials.ForWeChatPay(const AAppId, AMchId, AApiKey: string;
  AEnv: TPaymentEnvironment): TPaymentCredentials;
begin
  Result := Default(TPaymentCredentials);
  Result.Provider := ppWeChatPay;
  Result.Environment := AEnv;
  Result.AppId := AAppId;
  Result.MchId := AMchId;
  Result.ApiKey := AApiKey;
end;

{ TMoney }

constructor TMoney.Create(AAmount: Currency; const ACurrency: TCurrencyCode);
begin
  Amount := AAmount;
  CurrencyCode := ACurrency;
end;

function TMoney.ToMinorUnits: Int64;
begin
  // Most currencies use 2 decimal places (cents)
  // Some currencies like JPY use 0 decimal places
  if SameText(CurrencyCode, 'JPY') or SameText(CurrencyCode, 'KRW') then
    Result := Round(Amount)
  else
    Result := Round(Amount * 100);
end;

class function TMoney.FromMinorUnits(AMinorUnits: Int64; const ACurrency: TCurrencyCode): TMoney;
begin
  Result.CurrencyCode := ACurrency;
  if SameText(ACurrency, 'JPY') or SameText(ACurrency, 'KRW') then
    Result.Amount := AMinorUnits
  else
    Result.Amount := AMinorUnits / 100;
end;

function TMoney.ToString: string;
begin
  Result := Format('%s %.2f', [CurrencyCode, Amount]);
end;

{ TPaymentLineItem }

function TPaymentLineItem.TotalPrice: TMoney;
begin
  Result.CurrencyCode := UnitPrice.CurrencyCode;
  Result.Amount := UnitPrice.Amount * Quantity;
end;

{ TPaymentRequest }

constructor TPaymentRequest.Create(const AOrderId: string; AAmount: TMoney);
begin
  Self := Default(TPaymentRequest);
  OrderId := AOrderId;
  Amount := AAmount;
  CaptureMethod := cmAutomatic;
  IdempotencyKey := TGUID.NewGuid.ToString;
end;

procedure TPaymentRequest.AddLineItem(const AItem: TPaymentLineItem);
begin
  SetLength(LineItems, Length(LineItems) + 1);
  LineItems[High(LineItems)] := AItem;
end;

procedure TPaymentRequest.SetMetadata(const AKey, AValue: string);
begin
  if not Assigned(Metadata) then
    Metadata := TDictionary<string, string>.Create;
  Metadata.AddOrSetValue(AKey, AValue);
end;

procedure TPaymentRequest.Cleanup;
begin
  FreeAndNil(Metadata);
end;

{ TPaymentResult }

class function TPaymentResult.Succeeded(const ATransactionId: string;
  AAmount: TMoney): TPaymentResult;
begin
  Result := Default(TPaymentResult);
  Result.Success := True;
  Result.TransactionId := ATransactionId;
  Result.Status := psSuccess;
  Result.AmountReceived := AAmount;
  Result.CreatedAt := Now;
  Result.UpdatedAt := Now;
end;

class function TPaymentResult.Failed(const AErrorCode, AErrorMessage: string): TPaymentResult;
begin
  Result := Default(TPaymentResult);
  Result.Success := False;
  Result.Status := psFailed;
  Result.ErrorCode := AErrorCode;
  Result.ErrorMessage := AErrorMessage;
  Result.CreatedAt := Now;
  Result.UpdatedAt := Now;
end;

class function TPaymentResult.Pending(const ATransactionId, ARedirectUrl: string): TPaymentResult;
begin
  Result := Default(TPaymentResult);
  Result.Success := True;
  Result.TransactionId := ATransactionId;
  Result.Status := psPending;
  Result.RedirectUrl := ARedirectUrl;
  Result.CreatedAt := Now;
  Result.UpdatedAt := Now;
end;

{ EPaymentError }

constructor EPaymentError.Create(const AMessage: string; const AErrorCode: string;
  AProvider: TPaymentProvider);
begin
  inherited Create(AMessage);
  ErrorCode := AErrorCode;
  Provider := AProvider;
end;

{ Helper functions }

function PaymentProviderToStr(AProvider: TPaymentProvider): string;
const
  Names: array[TPaymentProvider] of string = ('Alipay', 'WeChatPay', 'Stripe', 'PayPal');
begin
  Result := Names[AProvider];
end;

function StrToPaymentProvider(const AStr: string): TPaymentProvider;
begin
  if SameText(AStr, 'Alipay') then Result := ppAlipay
  else if SameText(AStr, 'WeChatPay') or SameText(AStr, 'WeChat') then Result := ppWeChatPay
  else if SameText(AStr, 'Stripe') then Result := ppStripe
  else if SameText(AStr, 'PayPal') then Result := ppPayPal
  else raise EPaymentError.Create('Unknown provider: ' + AStr, 'INVALID_PROVIDER', ppAlipay);
end;

function PaymentStatusToStr(AStatus: TPaymentStatus): string;
const
  Names: array[TPaymentStatus] of string = (
    'unknown', 'pending', 'success', 'failed',
    'closed', 'refunding', 'refunded', 'partial_refund'
  );
begin
  Result := Names[AStatus];
end;

function StrToPaymentStatus(const AStr: string): TPaymentStatus;
begin
  if SameText(AStr, 'pending') then Result := psPending
  else if SameText(AStr, 'success') or SameText(AStr, 'succeeded') or SameText(AStr, 'paid') then
    Result := psSuccess
  else if SameText(AStr, 'failed') or SameText(AStr, 'failure') then Result := psFailed
  else if SameText(AStr, 'closed') or SameText(AStr, 'canceled') or SameText(AStr, 'cancelled') then Result := psClosed
  else if SameText(AStr, 'refunding') then Result := psRefunding
  else if SameText(AStr, 'refunded') then Result := psRefunded
  else if SameText(AStr, 'partial_refund') then Result := psPartialRefund
  else Result := psUnknown;
end;

end.
