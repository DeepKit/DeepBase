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
  EDeepBaseCommerceOrphanedOrderError = class(EDeepBaseCommercePaymentError)
  public
    OrderId: string;
    constructor Create(const AOrderId, AMessage: string);
  end;

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
    Tier: string;                     // 'free', 'standard', 'pro', 'enterprise'
    MaxDevices: Integer;              // -1 = unlimited, 0 = not set, >0 = limit
    OfflineGraceDays: Integer;        // 0 = no offline grace
    IsActive: Boolean;
    class function Create(const AAppId, AProductId, AName: string;
      AAmountMinor: Int64; const ACurrency, AEntitlementCode: string;
      AInitialQuota: Integer = -1; ADurationDays: Integer = 0;
      const ATier: string = ''; AMaxDevices: Integer = 0;
      AOfflineGraceDays: Integer = 0): TCommerceProductData; static;
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
    Tier: string;              // 'free', 'standard', 'pro', 'enterprise'
    MaxDevices: Integer;       // -1 = unlimited, 0 = no limit set
    OfflineGraceDays: Integer; // 0 = no offline grace
    LastValidatedISO: string;  // last server validation timestamp (UTC)
  end;

  TCommerceEntitlementArray = TArray<TCommerceEntitlementData>;

  // ---------------------------------------------------------------------------
  // Invite / Referral Types
  // ---------------------------------------------------------------------------

  /// <summary>
  /// Invite status for the current user.
  /// Returned by /dk/invite/status.
  /// </summary>
  TCommerceInviteStatus = record
    InviteCode: string;       // the user's personal invite code
    InviteCount: Integer;     // number of successful invitations
    TotalRewardDays: Integer; // cumulative reward days earned

    class function Empty: TCommerceInviteStatus; static;
  end;

  /// <summary>
  /// Result of applying an invite code.
  /// Returned by /dk/invite/apply.
  /// </summary>
  TCommerceInviteApplyResult = record
    Success: Boolean;
    RewardDays: Integer;      // days granted to both parties
    Message: string;          // human-readable result message

    class function CreateSuccess(ARewardDays: Integer; const AMsg: string): TCommerceInviteApplyResult; static;
    class function CreateFailed(const AMsg: string): TCommerceInviteApplyResult; static;
  end;

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
function CommercePaymentChannelToStr(AChannel: TCommercePaymentChannel): string;
function CommerceEntitlementStatusToStr(AStatus: TCommerceEntitlementStatus): string;
function IsCommerceEntitlementUsable(const AEntitlement: TCommerceEntitlementData): Boolean;
function StrToCommercePaymentProvider(const S: string): TCommercePaymentProvider;
function StrToCommercePaymentChannel(const S: string): TCommercePaymentChannel;
function StrToCommercePaymentStatus(const S: string): TCommercePaymentStatus;
function StrToCommerceEntitlementStatus(const S: string): TCommerceEntitlementStatus;

implementation

{ EDeepBaseCommerceOrphanedOrderError }

constructor EDeepBaseCommerceOrphanedOrderError.Create(const AOrderId, AMessage: string);
begin
  inherited Create(AMessage);
  OrderId := AOrderId;
end;

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

function CommerceEntitlementStatusToStr(AStatus: TCommerceEntitlementStatus): string;
begin
  case AStatus of
    cesActive: Result := 'active';
    cesConsumed: Result := 'consumed';
    cesExpired: Result := 'expired';
    cesRevoked: Result := 'revoked';
  else
    Result := 'active';
  end;
end;

function CommercePaymentChannelToStr(AChannel: TCommercePaymentChannel): string;
begin
  case AChannel of
    cpcNative: Result := 'native';
    cpcJSAPI: Result := 'jsapi';
    cpcMiniProgram: Result := 'mini_program';
    cpcH5: Result := 'h5';
    cpcApp: Result := 'app';
    cpcWeb: Result := 'web';
    cpcManual: Result := 'manual';
  else
    Result := 'native';
  end;
end;

function StrToCommercePaymentProvider(const S: string): TCommercePaymentProvider;
begin
  if SameText(S, 'wechat_pay') then Exit(cppWeChatPay);
  if SameText(S, 'alipay') then Exit(cppAlipay);
  if SameText(S, 'stripe') then Exit(cppStripe);
  if SameText(S, 'paypal') then Exit(cppPayPal);
  if SameText(S, 'manual') then Exit(cppManual);
  Result := cppExternal;
end;

function StrToCommercePaymentChannel(const S: string): TCommercePaymentChannel;
begin
  if SameText(S, 'native') then Exit(cpcNative);
  if SameText(S, 'jsapi') then Exit(cpcJSAPI);
  if SameText(S, 'mini_program') then Exit(cpcMiniProgram);
  if SameText(S, 'h5') then Exit(cpcH5);
  if SameText(S, 'app') then Exit(cpcApp);
  if SameText(S, 'web') then Exit(cpcWeb);
  if SameText(S, 'manual') then Exit(cpcManual);
  Result := cpcNative;
end;

function StrToCommercePaymentStatus(const S: string): TCommercePaymentStatus;
begin
  if SameText(S, 'created') then Exit(cpsCreated);
  if SameText(S, 'pending') then Exit(cpsPending);
  if SameText(S, 'paid') then Exit(cpsPaid);
  if SameText(S, 'failed') then Exit(cpsFailed);
  if SameText(S, 'refunded') then Exit(cpsRefunded);
  Result := cpsCreated;
end;

function StrToCommerceEntitlementStatus(const S: string): TCommerceEntitlementStatus;
begin
  if SameText(S, 'active') then Exit(cesActive);
  if SameText(S, 'consumed') then Exit(cesConsumed);
  if SameText(S, 'expired') then Exit(cesExpired);
  if SameText(S, 'revoked') then Exit(cesRevoked);
  Result := cesRevoked;
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
  AInitialQuota, ADurationDays: Integer; const ATier: string;
  AMaxDevices, AOfflineGraceDays: Integer): TCommerceProductData;
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
  Result.Tier := ATier;
  Result.MaxDevices := AMaxDevices;
  Result.OfflineGraceDays := AOfflineGraceDays;
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

{ TCommerceInviteStatus }

class function TCommerceInviteStatus.Empty: TCommerceInviteStatus;
begin
  Result.InviteCode := '';
  Result.InviteCount := 0;
  Result.TotalRewardDays := 0;
end;

{ TCommerceInviteApplyResult }

class function TCommerceInviteApplyResult.CreateSuccess(ARewardDays: Integer;
  const AMsg: string): TCommerceInviteApplyResult;
begin
  Result.Success := True;
  Result.RewardDays := ARewardDays;
  Result.Message := AMsg;
end;

class function TCommerceInviteApplyResult.CreateFailed(const AMsg: string): TCommerceInviteApplyResult;
begin
  Result.Success := False;
  Result.RewardDays := 0;
  Result.Message := AMsg;
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
  N := TTimeZone.Local.ToUniversalTime(Now);
  DecodeDateTime(N, Y, M, D, H, Mi, S, MS);
  Result := APrefix + Format('%.4d%.2d%.2d%.2d%.2d%.2d%.3d', [Y, M, D, H, Mi, S, MS]) + Tail;
end;

function IsCommerceEntitlementUsable(const AEntitlement: TCommerceEntitlementData): Boolean;
var
  ValidUntil, LastValidated, GraceExpiry: TDateTime;
begin
  if AEntitlement.Status <> cesActive then
    Exit(False);
  if (AEntitlement.RemainingQuota = 0) or (AEntitlement.RemainingQuota < -1) then
    Exit(False);
  if AEntitlement.ValidUntilISO = '' then
    Exit(True);
  if not TryISO8601ToDate(AEntitlement.ValidUntilISO, ValidUntil, False) then
    Exit(False);
  if ValidUntil > TTimeZone.Local.ToUniversalTime(Now) then
    Exit(True);
  if (AEntitlement.OfflineGraceDays > 0) and
     (AEntitlement.LastValidatedISO <> '') and
     TryISO8601ToDate(AEntitlement.LastValidatedISO, LastValidated, False) then
  begin
    GraceExpiry := LastValidated + AEntitlement.OfflineGraceDays;
    Result := GraceExpiry > TTimeZone.Local.ToUniversalTime(Now);
  end
  else
    Result := False;
end;

end.
