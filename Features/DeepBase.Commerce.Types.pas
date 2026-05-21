unit DeepBase.Commerce.Types;

interface

uses
  System.SysUtils,
  System.DateUtils;

type
  TCommerceAuthProvider = (
    capGuest,
    capPhone,
    capEmail,
    capWeChatMiniProgram,
    capWeChatOfficialAccount,
    capWeChatOpen,
    capDevice,
    capExternal
  );

  TCommerceOrderStatus = (
    cosCreated,
    cosPaying,
    cosPaid,
    cosClosed,
    cosFailed,
    cosRefunded
  );

  TCommercePaymentProvider = (
    cppWeChatPay,
    cppAlipay,
    cppStripe,
    cppPayPal,
    cppManual,
    cppExternal
  );

  TCommercePaymentChannel = (
    cpcNative,
    cpcJSAPI,
    cpcMiniProgram,
    cpcH5,
    cpcApp,
    cpcWeb,
    cpcManual
  );

  TCommercePaymentStatus = (
    cpsCreated,
    cpsPending,
    cpsPaid,
    cpsFailed,
    cpsRefunded
  );

  TCommerceEntitlementStatus = (
    cesActive,
    cesConsumed,
    cesExpired,
    cesRevoked
  );

  EDeepBaseCommerceError = class(Exception);
  EDeepBaseCommerceValidationError = class(EDeepBaseCommerceError);
  EDeepBaseCommerceNotFoundError = class(EDeepBaseCommerceError);
  EDeepBaseCommercePaymentError = class(EDeepBaseCommerceError);

  TCommerceUserData = record
    UserId: string;
    DisplayName: string;
    Email: string;
    Phone: string;
    IsActive: Boolean;
    CreatedAtISO: string;
    UpdatedAtISO: string;
    class function CreateNew(const AUserId: string): TCommerceUserData; static;
  end;

  TCommerceIdentityData = record
    UserId: string;
    Provider: TCommerceAuthProvider;
    ProviderUserId: string;
    AppId: string;
    UnionId: string;
    CreatedAtISO: string;
  end;

  TCommerceProductData = record
    ProductId: string;
    AppId: string;
    Name: string;
    Description: string;
    AmountMinor: Int64;
    Currency: string;
    EntitlementCode: string;
    EntitlementDurationDays: Integer; // 0 means permanent
    InitialQuota: Integer;            // -1 means unlimited
    IsActive: Boolean;
    class function Create(const AAppId, AProductId, AName: string;
      AAmountMinor: Int64; const ACurrency, AEntitlementCode: string;
      AInitialQuota: Integer = -1; ADurationDays: Integer = 0): TCommerceProductData; static;
  end;

  TCommerceOrderData = record
    OrderId: string;
    UserId: string;
    AppId: string;
    ProductId: string;
    OutTradeNo: string;
    Title: string;
    AmountMinor: Int64;
    Currency: string;
    Status: TCommerceOrderStatus;
    CreatedAtISO: string;
    PaidAtISO: string;
  end;

  TCommercePaymentData = record
    PaymentId: string;
    OrderId: string;
    Provider: TCommercePaymentProvider;
    Channel: TCommercePaymentChannel;
    ProviderTradeNo: string;
    PrepayId: string;
    Status: TCommercePaymentStatus;
    RawPayload: string;
    CreatedAtISO: string;
    PaidAtISO: string;
  end;

  TCommercePaymentIntent = record
    Success: Boolean;
    PaymentId: string;
    OutTradeNo: string;
    PrepayId: string;
    PayUrl: string;
    QRCodeData: string;
    ClientParamsJson: string;
    RawResponse: string;
    ErrorCode: string;
    ErrorMessage: string;
    class function Failed(const ACode, AMessage: string): TCommercePaymentIntent; static;
  end;

  TCommercePaymentNotification = record
    Provider: TCommercePaymentProvider;
    OutTradeNo: string;
    ProviderTradeNo: string;
    AmountMinor: Int64;
    Currency: string;
    Success: Boolean;
    PaidAtISO: string;
    RawPayload: string;
  end;

  TCommerceEntitlementData = record
    EntitlementId: string;
    UserId: string;
    AppId: string;
    ProductId: string;
    Code: string;
    Status: TCommerceEntitlementStatus;
    ValidFromISO: string;
    ValidUntilISO: string; // empty means permanent
    RemainingQuota: Integer; // -1 means unlimited
    SourceOrderId: string;
  end;

  TCommerceEntitlementArray = TArray<TCommerceEntitlementData>;

  TCommerceIds = record
    class function NewId(const APrefix: string): string; static;
    class function NewOutTradeNo(const APrefix: string = 'UB'): string; static;
  end;

  // All ISO timestamps (CreatedAtISO, PaidAtISO, etc.) are UTC. Use CommerceNowISO to generate.
function CommerceNowISO: string;
function CommerceAuthProviderToStr(AProvider: TCommerceAuthProvider): string;
function CommercePaymentProviderToStr(AProvider: TCommercePaymentProvider): string;
function CommerceOrderStatusToStr(AStatus: TCommerceOrderStatus): string;
function CommercePaymentStatusToStr(AStatus: TCommercePaymentStatus): string;

implementation

function CommerceNowISO: string;
var
  UTCNow: TDateTime;
begin
  UTCNow := TTimeZone.Local.ToUniversalTime(Now);
  Result := DateToISO8601(UTCNow, False);
end;

function NormalizeGuidText(const AText: string): string;
begin
  Result := LowerCase(AText);
  Result := StringReplace(Result, '{', '', [rfReplaceAll]);
  Result := StringReplace(Result, '}', '', [rfReplaceAll]);
  Result := StringReplace(Result, '-', '', [rfReplaceAll]);
end;

function CommerceAuthProviderToStr(AProvider: TCommerceAuthProvider): string;
begin
  case AProvider of
    capGuest: Result := 'guest';
    capPhone: Result := 'phone';
    capEmail: Result := 'email';
    capWeChatMiniProgram: Result := 'wechat_mini_program';
    capWeChatOfficialAccount: Result := 'wechat_official_account';
    capWeChatOpen: Result := 'wechat_open';
    capDevice: Result := 'device';
  else
    Result := 'external';
  end;
end;

function CommercePaymentProviderToStr(AProvider: TCommercePaymentProvider): string;
begin
  case AProvider of
    cppWeChatPay: Result := 'wechat_pay';
    cppAlipay: Result := 'alipay';
    cppStripe: Result := 'stripe';
    cppPayPal: Result := 'paypal';
    cppManual: Result := 'manual';
  else
    Result := 'external';
  end;
end;

function CommerceOrderStatusToStr(AStatus: TCommerceOrderStatus): string;
begin
  case AStatus of
    cosCreated: Result := 'created';
    cosPaying: Result := 'paying';
    cosPaid: Result := 'paid';
    cosClosed: Result := 'closed';
    cosFailed: Result := 'failed';
  else
    Result := 'refunded';
  end;
end;

function CommercePaymentStatusToStr(AStatus: TCommercePaymentStatus): string;
begin
  case AStatus of
    cpsCreated: Result := 'created';
    cpsPending: Result := 'pending';
    cpsPaid: Result := 'paid';
    cpsFailed: Result := 'failed';
  else
    Result := 'refunded';
  end;
end;

{ TCommerceUserData }

class function TCommerceUserData.CreateNew(
  const AUserId: string): TCommerceUserData;
begin
  Result.UserId := AUserId;
  Result.DisplayName := '';
  Result.Email := '';
  Result.Phone := '';
  Result.IsActive := True;
  Result.CreatedAtISO := CommerceNowISO;
  Result.UpdatedAtISO := Result.CreatedAtISO;
end;

{ TCommerceProductData }

class function TCommerceProductData.Create(const AAppId, AProductId,
  AName: string; AAmountMinor: Int64; const ACurrency, AEntitlementCode: string;
  AInitialQuota, ADurationDays: Integer): TCommerceProductData;
begin
  Result.AppId := AAppId;
  Result.ProductId := AProductId;
  Result.Name := AName;
  Result.Description := '';
  Result.AmountMinor := AAmountMinor;
  Result.Currency := ACurrency;
  Result.EntitlementCode := AEntitlementCode;
  Result.EntitlementDurationDays := ADurationDays;
  Result.InitialQuota := AInitialQuota;
  Result.IsActive := True;
end;

{ TCommercePaymentIntent }

class function TCommercePaymentIntent.Failed(const ACode,
  AMessage: string): TCommercePaymentIntent;
begin
  Result.Success := False;
  Result.PaymentId := '';
  Result.OutTradeNo := '';
  Result.PrepayId := '';
  Result.PayUrl := '';
  Result.QRCodeData := '';
  Result.ClientParamsJson := '';
  Result.RawResponse := '';
  Result.ErrorCode := ACode;
  Result.ErrorMessage := AMessage;
end;

{ TCommerceIds }

class function TCommerceIds.NewId(const APrefix: string): string;
var
  Guid: TGUID;
  Text: string;
begin
  CreateGUID(Guid);
  Text := NormalizeGuidText(GUIDToString(Guid));
  if APrefix = '' then
    Result := Text
  else
    Result := APrefix + '_' + Text;
end;

class function TCommerceIds.NewOutTradeNo(const APrefix: string): string;
var
  Guid: TGUID;
  Tail: string;
  N: TDateTime;
  Y, M, D, H, Mi, S, MS: Word;
begin
  CreateGUID(Guid);
  Tail := Copy(NormalizeGuidText(GUIDToString(Guid)), 1, 12);
  N := Now;
  DecodeDateTime(N, Y, M, D, H, Mi, S, MS);
  Result := APrefix + Format('%.4d%.2d%.2d%.2d%.2d%.2d%.3d', [Y, M, D, H, Mi, S, MS]) + Tail;
end;

end.
