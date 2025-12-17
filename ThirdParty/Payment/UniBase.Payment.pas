unit UniBase.Payment;

{*******************************************************************************
  UniBase Payment Integration

  Unified interface for payment providers:
    - Alipay (支付宝)
    - WeChat Pay (微信支付)
    - Stripe
    - PayPal

  Usage:
    var Client := TAlipayClient.Create(Config);
    var Result := Client.CreateOrder(Order);
    if Result.Success then
      ShellExecute(0, 'open', PChar(Result.PayUrl), nil, nil, SW_SHOW);
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.Net.HttpClient, System.Net.URLClient, System.JSON,
  System.DateUtils, System.Hash, System.NetEncoding;

type
  /// <summary>Payment provider type</summary>
  TPaymentProvider = (ppAlipay, ppWeChatPay, ppStripe, ppPayPal);

  /// <summary>Payment status</summary>
  TPaymentStatus = (
    psUnknown,      // Unknown
    psPending,      // Waiting for payment
    psSuccess,      // Payment successful
    psFailed,       // Payment failed
    psClosed,       // Order closed/cancelled
    psRefunding,    // Refund in progress
    psRefunded,     // Refund completed
    psPartialRefund // Partial refund
  );

  /// <summary>Payment method type</summary>
  TPaymentMethod = (
    pmDefault,      // Provider default
    pmQRCode,       // QR code (scan to pay)
    pmWebPage,      // Web page redirect
    pmApp,          // App SDK
    pmH5,           // Mobile H5
    pmMiniProgram,  // Mini program
    pmCard          // Credit/Debit card
  );

  EPaymentError = class(Exception)
  public
    ErrorCode: string;
    Provider: TPaymentProvider;
    constructor Create(const AMessage: string; const AErrorCode: string = '';
      AProvider: TPaymentProvider = ppAlipay); reintroduce;
  end;

  EPaymentConfigError = class(EPaymentError);
  EPaymentSignError = class(EPaymentError);
  EPaymentNetworkError = class(EPaymentError);
  EPaymentBusinessError = class(EPaymentError);

  /// <summary>Payment order request</summary>
  TPaymentOrder = record
    OrderNo: string;           // Merchant order number (required)
    Amount: Currency;          // Payment amount (required)
    Currency: string;          // Currency code: CNY, USD, EUR, etc.
    Subject: string;           // Order subject/title (required)
    Body: string;              // Order description
    NotifyUrl: string;         // Async notification URL
    ReturnUrl: string;         // Sync return URL (web)
    SuccessUrl: string;        // Success redirect URL (Stripe)
    CancelUrl: string;         // Cancel redirect URL (Stripe)
    ExpireMinutes: Integer;    // Order expiration (minutes)
    PaymentMethod: TPaymentMethod;
    Metadata: TDictionary<string, string>;  // Custom fields
    ClientIP: string;          // Payer IP address

    procedure Clear;
    procedure Validate;
  end;

  /// <summary>Payment creation result</summary>
  TPaymentResult = record
    Success: Boolean;
    ErrorCode: string;
    ErrorMessage: string;

    // Payment identifiers
    OrderNo: string;           // Merchant order number
    TradeNo: string;           // Provider transaction ID
    
    // Payment info
    PayUrl: string;            // Payment URL (redirect)
    QRCodeUrl: string;         // QR code image URL
    QRCodeData: string;        // QR code raw data
    PrepayId: string;          // WeChat prepay_id
    
    // For App SDK
    AppPayParams: string;      // JSON params for App SDK

    procedure Clear;
    class function Fail(const AErrorCode, AErrorMessage: string): TPaymentResult; static;
  end;

  /// <summary>Payment query result</summary>
  TPaymentQueryResult = record
    Success: Boolean;
    ErrorCode: string;
    ErrorMessage: string;

    OrderNo: string;
    TradeNo: string;
    Status: TPaymentStatus;
    Amount: Currency;
    PaidAmount: Currency;
    RefundedAmount: Currency;
    PaidAt: TDateTime;
    
    RawResponse: string;

    procedure Clear;
  end;

  /// <summary>Refund request</summary>
  TRefundRequest = record
    OrderNo: string;           // Original order number
    RefundNo: string;          // Refund order number (unique)
    RefundAmount: Currency;    // Refund amount
    TotalAmount: Currency;     // Original order amount (some providers need this)
    Reason: string;            // Refund reason
    NotifyUrl: string;         // Refund notification URL

    procedure Clear;
    procedure Validate;
  end;

  /// <summary>Refund result</summary>
  TRefundResult = record
    Success: Boolean;
    ErrorCode: string;
    ErrorMessage: string;

    RefundNo: string;
    RefundTradeNo: string;     // Provider refund ID
    RefundAmount: Currency;
    Status: TPaymentStatus;

    procedure Clear;
    class function Fail(const AErrorCode, AErrorMessage: string): TRefundResult; static;
  end;

  /// <summary>Payment notification (webhook/callback)</summary>
  TPaymentNotification = record
    Provider: TPaymentProvider;
    OrderNo: string;
    TradeNo: string;
    Status: TPaymentStatus;
    Amount: Currency;
    PaidAt: TDateTime;
    
    // Refund info (if applicable)
    RefundNo: string;
    RefundTradeNo: string;
    RefundAmount: Currency;
    RefundStatus: TPaymentStatus;

    RawData: string;

    procedure Clear;
  end;

  /// <summary>Key storage mode for sensitive data</summary>
  TKeyStorageMode = (
    ksmPlainText,      // Not recommended: store as plain text (legacy)
    ksmDPAPI,          // Windows DPAPI encryption (recommended)
    ksmCredential      // Windows Credential Manager
  );

  /// <summary>Base payment configuration</summary>
  TPaymentConfig = class
  private
    FProvider: TPaymentProvider;
    FIsSandbox: Boolean;
    FTimeout: Integer;
    FNotifyUrl: string;
    FReturnUrl: string;
    FKeyStorageMode: TKeyStorageMode;  // BUG-019 FIX: 密钥存储模式
    FCredentialTarget: string;          // BUG-019 FIX: Credential Manager 目标名称前缀
  protected
    // BUG-019 FIX: 安全存储/读取密钥
    function ProtectKey(const APlainKey: string): string;
    function UnprotectKey(const AEncryptedKey: string): string;
    function GetCredentialKey(const AKeyName: string): string;
    procedure SetCredentialKey(const AKeyName, AValue: string);
  public
    constructor Create(AProvider: TPaymentProvider); virtual;

    /// <summary>Load keys from secure storage (Credential Manager)</summary>
    procedure LoadKeysFromCredentialManager; virtual;
    /// <summary>Save keys to secure storage (Credential Manager)</summary>
    procedure SaveKeysToCredentialManager; virtual;

    property Provider: TPaymentProvider read FProvider;
    property IsSandbox: Boolean read FIsSandbox write FIsSandbox;
    property Timeout: Integer read FTimeout write FTimeout;
    property NotifyUrl: string read FNotifyUrl write FNotifyUrl;
    property ReturnUrl: string read FReturnUrl write FReturnUrl;
    // BUG-019 FIX: 密钥安全存储属性
    property KeyStorageMode: TKeyStorageMode read FKeyStorageMode write FKeyStorageMode;
    property CredentialTarget: string read FCredentialTarget write FCredentialTarget;
  end;

  /// <summary>Unified payment client interface</summary>
  IPaymentClient = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    function GetProvider: TPaymentProvider;

    // Order operations
    function CreateOrder(const AOrder: TPaymentOrder): TPaymentResult;
    function QueryOrder(const AOrderNo: string): TPaymentQueryResult;
    function CloseOrder(const AOrderNo: string): Boolean;

    // Refund operations
    function Refund(const ARequest: TRefundRequest): TRefundResult;
    function QueryRefund(const ARefundNo: string): TRefundResult;

    // Notification handling
    function VerifyNotification(const ARawData: string;
      out ANotification: TPaymentNotification): Boolean;
    function GetNotificationResponse(ASuccess: Boolean): string;

    property Provider: TPaymentProvider read GetProvider;
  end;

  /// <summary>Base payment client implementation</summary>
  TPaymentClient = class(TInterfacedObject, IPaymentClient)
  protected
    FConfig: TPaymentConfig;
    FHttpClient: THTTPClient;

    function DoPost(const AUrl: string; const AData: string;
      const AContentType: string = 'application/x-www-form-urlencoded'): string; virtual;
    function DoGet(const AUrl: string): string; virtual;

    // Subclass must implement
    function SignRequest(const AParams: TDictionary<string, string>): string; virtual; abstract;
    function VerifySignature(const AParams: TDictionary<string, string>;
      const ASign: string): Boolean; virtual; abstract;
  public
    constructor Create(AConfig: TPaymentConfig); virtual;
    destructor Destroy; override;

    // IPaymentClient
    function GetProvider: TPaymentProvider;
    function CreateOrder(const AOrder: TPaymentOrder): TPaymentResult; virtual; abstract;
    function QueryOrder(const AOrderNo: string): TPaymentQueryResult; virtual; abstract;
    function CloseOrder(const AOrderNo: string): Boolean; virtual; abstract;
    function Refund(const ARequest: TRefundRequest): TRefundResult; virtual; abstract;
    function QueryRefund(const ARefundNo: string): TRefundResult; virtual; abstract;
    function VerifyNotification(const ARawData: string;
      out ANotification: TPaymentNotification): Boolean; virtual; abstract;
    function GetNotificationResponse(ASuccess: Boolean): string; virtual; abstract;

    property Config: TPaymentConfig read FConfig;
  end;

  /// <summary>Helper functions</summary>
  TPaymentHelper = class
  public
    class function StatusToString(AStatus: TPaymentStatus): string;
    class function StringToStatus(const AStr: string): TPaymentStatus;
    class function ProviderToString(AProvider: TPaymentProvider): string;
    class function GenerateOrderNo(const APrefix: string = ''): string;
    class function GenerateNonceStr(ALength: Integer = 32): string;
    class function FormatAmount(AAmount: Currency; const ACurrency: string): string;
    class function ParseAmount(const AAmountStr: string; const ACurrency: string): Currency;
    class function BuildQueryString(const AParams: TDictionary<string, string>;
      AUrlEncode: Boolean = True): string;
    class function ParseQueryString(const AQueryStr: string): TDictionary<string, string>;
    class function MD5(const AData: string): string;
    class function SHA256(const AData: string): string;
    class function HMACSHA256(const AData, AKey: string): string;
    class function Base64Encode(const AData: TBytes): string;
    class function Base64Decode(const AData: string): TBytes;
  end;

implementation

uses
  UniBase.Security.DPAPI;  // BUG-019 FIX: 安全密钥存储支持

{ EPaymentError }

constructor EPaymentError.Create(const AMessage: string; const AErrorCode: string;
  AProvider: TPaymentProvider);
begin
  inherited Create(AMessage);
  ErrorCode := AErrorCode;
  Provider := AProvider;
end;

{ TPaymentOrder }

procedure TPaymentOrder.Clear;
begin
  OrderNo := '';
  Amount := 0;
  Currency := 'CNY';
  Subject := '';
  Body := '';
  NotifyUrl := '';
  ReturnUrl := '';
  SuccessUrl := '';
  CancelUrl := '';
  ExpireMinutes := 30;
  PaymentMethod := pmDefault;
  if Assigned(Metadata) then
    FreeAndNil(Metadata);
  ClientIP := '';
end;

procedure TPaymentOrder.Validate;
begin
  if OrderNo = '' then
    raise EPaymentConfigError.Create('OrderNo is required');
  if Amount <= 0 then
    raise EPaymentConfigError.Create('Amount must be positive');
  if Subject = '' then
    raise EPaymentConfigError.Create('Subject is required');
end;

{ TPaymentResult }

procedure TPaymentResult.Clear;
begin
  Success := False;
  ErrorCode := '';
  ErrorMessage := '';
  OrderNo := '';
  TradeNo := '';
  PayUrl := '';
  QRCodeUrl := '';
  QRCodeData := '';
  PrepayId := '';
  AppPayParams := '';
end;

class function TPaymentResult.Fail(const AErrorCode, AErrorMessage: string): TPaymentResult;
begin
  Result.Clear;
  Result.ErrorCode := AErrorCode;
  Result.ErrorMessage := AErrorMessage;
end;

{ TPaymentQueryResult }

procedure TPaymentQueryResult.Clear;
begin
  Success := False;
  ErrorCode := '';
  ErrorMessage := '';
  OrderNo := '';
  TradeNo := '';
  Status := psUnknown;
  Amount := 0;
  PaidAmount := 0;
  RefundedAmount := 0;
  PaidAt := 0;
  RawResponse := '';
end;

{ TRefundRequest }

procedure TRefundRequest.Clear;
begin
  OrderNo := '';
  RefundNo := '';
  RefundAmount := 0;
  TotalAmount := 0;
  Reason := '';
  NotifyUrl := '';
end;

procedure TRefundRequest.Validate;
begin
  if OrderNo = '' then
    raise EPaymentConfigError.Create('OrderNo is required for refund');
  if RefundNo = '' then
    raise EPaymentConfigError.Create('RefundNo is required');
  if RefundAmount <= 0 then
    raise EPaymentConfigError.Create('RefundAmount must be positive');
end;

{ TRefundResult }

procedure TRefundResult.Clear;
begin
  Success := False;
  ErrorCode := '';
  ErrorMessage := '';
  RefundNo := '';
  RefundTradeNo := '';
  RefundAmount := 0;
  Status := psUnknown;
end;

class function TRefundResult.Fail(const AErrorCode, AErrorMessage: string): TRefundResult;
begin
  Result.Clear;
  Result.ErrorCode := AErrorCode;
  Result.ErrorMessage := AErrorMessage;
end;

{ TPaymentNotification }

procedure TPaymentNotification.Clear;
begin
  Provider := ppAlipay;
  OrderNo := '';
  TradeNo := '';
  Status := psUnknown;
  Amount := 0;
  PaidAt := 0;
  RefundNo := '';
  RefundTradeNo := '';
  RefundAmount := 0;
  RefundStatus := psUnknown;
  RawData := '';
end;

{ TPaymentConfig }

constructor TPaymentConfig.Create(AProvider: TPaymentProvider);
begin
  inherited Create;
  FProvider := AProvider;
  FIsSandbox := False;
  FTimeout := 30000;
  // BUG-019 FIX: 初始化安全存储设置
  FKeyStorageMode := ksmDPAPI;  // 默认使用 DPAPI（推荐）
  FCredentialTarget := 'UniBase.Payment.' + TPaymentHelper.ProviderToString(AProvider);
end;

{ BUG-019 FIX: TPaymentConfig 安全存储方法实现 }

function TPaymentConfig.ProtectKey(const APlainKey: string): string;
begin
  if APlainKey = '' then
    Exit('');

  case FKeyStorageMode of
    ksmDPAPI:
      Result := TDPAPIHelper.ProtectString(APlainKey);
    ksmCredential:
      // Credential Manager 模式下不需要额外加密
      Result := APlainKey;
  else
    // ksmPlainText - 不推荐，但保持兼容性
    Result := APlainKey;
  end;
end;

function TPaymentConfig.UnprotectKey(const AEncryptedKey: string): string;
begin
  if AEncryptedKey = '' then
    Exit('');

  case FKeyStorageMode of
    ksmDPAPI:
      Result := TDPAPIHelper.UnprotectString(AEncryptedKey);
    ksmCredential:
      // Credential Manager 模式下数据已经安全存储
      Result := AEncryptedKey;
  else
    // ksmPlainText
    Result := AEncryptedKey;
  end;
end;

function TPaymentConfig.GetCredentialKey(const AKeyName: string): string;
var
  TargetName: string;
begin
  Result := '';
  if FKeyStorageMode <> ksmCredential then
    Exit;

  TargetName := FCredentialTarget + '.' + AKeyName;
  Result := TCredentialManager.GetCredential(TargetName);
end;

procedure TPaymentConfig.SetCredentialKey(const AKeyName, AValue: string);
var
  TargetName: string;
begin
  if FKeyStorageMode <> ksmCredential then
    Exit;

  TargetName := FCredentialTarget + '.' + AKeyName;
  if AValue <> '' then
    TCredentialManager.SaveCredential(TargetName, '', AValue)
  else
    TCredentialManager.DeleteCredential(TargetName);
end;

procedure TPaymentConfig.LoadKeysFromCredentialManager;
begin
  // 基类空实现，子类根据具体密钥字段重写
end;

procedure TPaymentConfig.SaveKeysToCredentialManager;
begin
  // 基类空实现，子类根据具体密钥字段重写
end;

{ TPaymentClient }

constructor TPaymentClient.Create(AConfig: TPaymentConfig);
begin
  inherited Create;
  FConfig := AConfig;
  FHttpClient := THTTPClient.Create;
  FHttpClient.ConnectionTimeout := FConfig.Timeout;
  FHttpClient.ResponseTimeout := FConfig.Timeout;
end;

destructor TPaymentClient.Destroy;
begin
  FHttpClient.Free;
  inherited;
end;

function TPaymentClient.GetProvider: TPaymentProvider;
begin
  Result := FConfig.Provider;
end;

function TPaymentClient.DoPost(const AUrl: string; const AData: string;
  const AContentType: string): string;
var
  Response: IHTTPResponse;
  Content: TStringStream;
begin
  Content := TStringStream.Create(AData, TEncoding.UTF8);
  try
    FHttpClient.CustomHeaders['Content-Type'] := AContentType;
    Response := FHttpClient.Post(AUrl, Content);
    Result := Response.ContentAsString(TEncoding.UTF8);

    if Response.StatusCode >= 400 then
      raise EPaymentNetworkError.Create(
        Format('HTTP Error %d: %s', [Response.StatusCode, Result]),
        IntToStr(Response.StatusCode), FConfig.Provider);
  finally
    Content.Free;
  end;
end;

function TPaymentClient.DoGet(const AUrl: string): string;
var
  Response: IHTTPResponse;
begin
  Response := FHttpClient.Get(AUrl);
  Result := Response.ContentAsString(TEncoding.UTF8);

  if Response.StatusCode >= 400 then
    raise EPaymentNetworkError.Create(
      Format('HTTP Error %d: %s', [Response.StatusCode, Result]),
      IntToStr(Response.StatusCode), FConfig.Provider);
end;

{ TPaymentHelper }

class function TPaymentHelper.StatusToString(AStatus: TPaymentStatus): string;
begin
  case AStatus of
    psPending: Result := 'PENDING';
    psSuccess: Result := 'SUCCESS';
    psFailed: Result := 'FAILED';
    psClosed: Result := 'CLOSED';
    psRefunding: Result := 'REFUNDING';
    psRefunded: Result := 'REFUNDED';
    psPartialRefund: Result := 'PARTIAL_REFUND';
  else
    Result := 'UNKNOWN';
  end;
end;

class function TPaymentHelper.StringToStatus(const AStr: string): TPaymentStatus;
var
  S: string;
begin
  S := UpperCase(AStr);
  if (S = 'PENDING') or (S = 'WAIT_BUYER_PAY') or (S = 'NOTPAY') then
    Result := psPending
  else if (S = 'SUCCESS') or (S = 'TRADE_SUCCESS') or (S = 'TRADE_FINISHED') then
    Result := psSuccess
  else if (S = 'FAILED') or (S = 'PAYERROR') then
    Result := psFailed
  else if (S = 'CLOSED') or (S = 'TRADE_CLOSED') or (S = 'REVOKED') then
    Result := psClosed
  else if S = 'REFUNDING' then
    Result := psRefunding
  else if (S = 'REFUNDED') or (S = 'REFUND') then
    Result := psRefunded
  else if S = 'PARTIAL_REFUND' then
    Result := psPartialRefund
  else
    Result := psUnknown;
end;

class function TPaymentHelper.ProviderToString(AProvider: TPaymentProvider): string;
begin
  case AProvider of
    ppAlipay: Result := 'Alipay';
    ppWeChatPay: Result := 'WeChatPay';
    ppStripe: Result := 'Stripe';
    ppPayPal: Result := 'PayPal';
  else
    Result := 'Unknown';
  end;
end;

class function TPaymentHelper.GenerateOrderNo(const APrefix: string): string;
begin
  // Format: PREFIX + YYYYMMDDHHNNSS + 6 random digits
  Result := APrefix + FormatDateTime('yyyymmddhhnnss', Now) +
    Format('%.6d', [Random(1000000)]);
end;

class function TPaymentHelper.GenerateNonceStr(ALength: Integer): string;
const
  Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
var
  I: Integer;
begin
  SetLength(Result, ALength);
  for I := 1 to ALength do
    Result[I] := Chars[Random(Length(Chars)) + 1];
end;

class function TPaymentHelper.FormatAmount(AAmount: Currency;
  const ACurrency: string): string;
begin
  // Most providers use cents/fen as integer
  if SameText(ACurrency, 'CNY') or SameText(ACurrency, 'JPY') then
    Result := IntToStr(Round(AAmount * 100))  // Fen
  else
    Result := FormatFloat('0.00', AAmount);
end;

class function TPaymentHelper.ParseAmount(const AAmountStr: string;
  const ACurrency: string): Currency;
begin
  if SameText(ACurrency, 'CNY') or SameText(ACurrency, 'JPY') then
    Result := StrToIntDef(AAmountStr, 0) / 100  // From fen
  else
    Result := StrToCurrDef(AAmountStr, 0);
end;

class function TPaymentHelper.BuildQueryString(
  const AParams: TDictionary<string, string>; AUrlEncode: Boolean): string;
var
  SortedKeys: TList<string>;
  Key: string;
  SB: TStringBuilder;
begin
  if (AParams = nil) or (AParams.Count = 0) then
    Exit('');

  SortedKeys := TList<string>.Create;
  SB := TStringBuilder.Create;
  try
    for Key in AParams.Keys do
      SortedKeys.Add(Key);
    SortedKeys.Sort;

    for Key in SortedKeys do
    begin
      if AParams[Key] = '' then Continue;

      if SB.Length > 0 then
        SB.Append('&');
      SB.Append(Key);
      SB.Append('=');
      if AUrlEncode then
        SB.Append(TNetEncoding.URL.Encode(AParams[Key]))
      else
        SB.Append(AParams[Key]);
    end;

    Result := SB.ToString;
  finally
    SortedKeys.Free;
    SB.Free;
  end;
end;

class function TPaymentHelper.ParseQueryString(const AQueryStr: string): TDictionary<string, string>;
var
  Pairs: TArray<string>;
  Pair: string;
  EqPos: Integer;
begin
  Result := TDictionary<string, string>.Create;
  if AQueryStr = '' then Exit;

  Pairs := AQueryStr.Split(['&']);
  for Pair in Pairs do
  begin
    EqPos := Pos('=', Pair);
    if EqPos > 0 then
      Result.AddOrSetValue(
        Copy(Pair, 1, EqPos - 1),
        TNetEncoding.URL.Decode(Copy(Pair, EqPos + 1, MaxInt))
      );
  end;
end;

class function TPaymentHelper.MD5(const AData: string): string;
begin
  Result := THashMD5.GetHashString(AData).ToLower;
end;

class function TPaymentHelper.SHA256(const AData: string): string;
begin
  Result := THashSHA2.GetHashString(AData, THashSHA2.TSHA2Version.SHA256).ToLower;
end;

class function TPaymentHelper.HMACSHA256(const AData, AKey: string): string;
var
  KeyBytes, DataBytes, HashBytes: TBytes;
begin
  KeyBytes := TEncoding.UTF8.GetBytes(AKey);
  DataBytes := TEncoding.UTF8.GetBytes(AData);
  HashBytes := THashSHA2.GetHMACAsBytes(DataBytes, KeyBytes,
    THashSHA2.TSHA2Version.SHA256);
  // Convert bytes to hex string
  Result := '';
  for var B in HashBytes do
    Result := Result + IntToHex(B, 2);
  Result := Result.ToLower;
end;

class function TPaymentHelper.Base64Encode(const AData: TBytes): string;
begin
  Result := TNetEncoding.Base64.EncodeBytesToString(AData);
end;

class function TPaymentHelper.Base64Decode(const AData: string): TBytes;
begin
  Result := TNetEncoding.Base64.DecodeStringToBytes(AData);
end;

initialization
  Randomize;

end.
