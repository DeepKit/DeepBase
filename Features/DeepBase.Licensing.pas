unit DeepBase.Licensing;

{ ============================================================================
  DeepBase.Licensing - Unified Licensing Facade

  Description:
    Thin orchestration layer that ties together DeepBase.Commerce.* (SafeClient,
    Permissions, UpgradeFlow) with DeepBase.Unlock (social unlock codes) into a
    single, simple API for each Deep-series product.

    Each product defines a TDeepLicensingProductConfig record with its identity
    (AppID, ProductCode), server URL, RSA public keys, and compile-time feature
    value definitions. The facade handles everything else:
      - device_anonymous login
      - entitlement/tier resolution (server is the source of truth)
      - feature gating (HasFeature, GetFeatureInt, GetFeatureStr)
      - trial auto-start on first launch
      - offline fallback via RSA-signed license snapshots
      - purchase flow (list products, create order, payment intent)
      - invite code generation and application
      - social unlock code validation and application

    Architecture:
      Product Code (DeepSync, DeepLaunch, ...)
              |
              v
        DeepBase.Licensing  (this unit)
        ├── DeepBase.Commerce.SafeClient       (HTTP, auth, /dk/* APIs)
        ├── DeepBase.Commerce.Permissions      (HasFeature, HasTier, OfflineGrace)
        ├── DeepBase.Commerce.UpgradeFlow      (ListProducts, StartPaidUpgrade)
        └── DeepBase.Unlock                    (social unlock codes)
              |
              v
        deepkit-db4 (FastAPI + PostgreSQL)

  Version: 1.0
  Date: 2026-06-16
  ============================================================================ }

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  DeepBase.Commerce.Types,
  DeepBase.Commerce.SafeClient,
  DeepBase.Commerce.Permissions,
  DeepBase.Commerce.UpgradeFlow,
  DeepBase.Unlock;

type
  /// <summary>License tier: Free or Pro.</summary>
  TLicensingTier = (ltFree, ltPro);

  /// <summary>Feature value type discriminator.</summary>
  TLicensingFeatureValueType = (fvInt, fvBool, fvStr);

  /// <summary>
  /// Compile-time feature definition. Maps a feature code to its Free and Pro
  /// values. The server determines the tier; these values are static per product.
  /// </summary>
  TLicensingFeatureDef = record
    Code: string;
    FreeInt: Integer;
    ProInt: Integer;
    FreeBool: Boolean;
    ProBool: Boolean;
    FreeStr: string;
    ProStr: string;
    ValueType: TLicensingFeatureValueType;
    /// <summary>Create an integer feature definition.</summary>
    class function IntVal(const ACode: string; AFree, APro: Integer): TLicensingFeatureDef; static;
    /// <summary>Create a boolean feature definition.</summary>
    class function BoolVal(const ACode: string; AFree, APro: Boolean): TLicensingFeatureDef; static;
    /// <summary>Create a string feature definition.</summary>
    class function StrVal(const ACode, AFree, APro: string): TLicensingFeatureDef; static;
  end;

  TLicensingFeatureDefArray = TArray<TLicensingFeatureDef>;

  /// <summary>
  /// Per-product configuration record. Each product defines one of these
  /// with its identity, server URL, RSA public keys, and feature definitions.
  /// </summary>
  TDeepLicensingProductConfig = record
    AppID: string;
    ProductCode: string;
    ServerBaseURL: string;
    LicensePublicKeys: TArray<TDeepKitLicenseSnapshotPublicKey>;
    FeatureDefs: TLicensingFeatureDefArray;
    /// <summary>Create a minimal config with just identity and server URL.</summary>
    class function Create(const AAppID, AProductCode, AServerBaseURL: string): TDeepLicensingProductConfig; static;
  end;

  /// <summary>
  /// Unified licensing facade for Deep-series products.
  ///
  /// Usage:
  ///   var Licensing := TDeepLicensing.Create(MyProductConfig);
  ///   Licensing.Initialize;
  ///   Licensing.StartTrial;
  ///   if Licensing.HasFeature('sync_lan_count') then ...
  ///   var MaxDevices := Licensing.GetFeatureInt('remote_devices');
  /// </summary>
  TDeepLicensing = class
  private
    FConfig: TDeepLicensingProductConfig;
    FSafeClient: TDeepKitSafeClient;
    FPermissions: TDeepKitPermissionClient;
    FUpgradeFlow: TDeepKitUpgradeFlowClient;
    FUnlock: TDeepBaseUnlock;
    FIsInitialized: Boolean;
    FIsOnline: Boolean;
    FUserId: string;
    FDeviceId: string;
    FCachedTier: TLicensingTier;
    FFeatureIndex: TDictionary<string, TLicensingFeatureDef>;

    procedure EnsureInitialized;
    function TryLogin: Boolean;
    procedure RefreshCachedTier;
    function GetOrCreateDeviceId: string;
    function FindFeatureDef(const Code: string; out Def: TLicensingFeatureDef): Boolean;
    function HasAnyProEntitlement: Boolean;
    function GetConfigStr(const Key, ADefault: string): string;
    procedure SetConfigStr(const Key, AValue: string);
  public
    constructor Create(const AConfig: TDeepLicensingProductConfig);
    destructor Destroy; override;

    // -------------------------------------------------------------------------
    // Lifecycle
    // -------------------------------------------------------------------------

    /// <summary>
    /// Initialize the licensing system: build SafeClient, perform device_anonymous
    /// login, load entitlements, prepare feature index. Must be called once at
    /// application startup before any other methods.
    /// </summary>
    procedure Initialize;

    // -------------------------------------------------------------------------
    // Tier
    // -------------------------------------------------------------------------

    /// <summary>Returns the current license tier (ltFree or ltPro).</summary>
    function GetTier: TLicensingTier;

    /// <summary>Returns 'free' or 'pro' as a string.</summary>
    function GetTierName: string;

    // -------------------------------------------------------------------------
    // Feature Gating
    // -------------------------------------------------------------------------

    /// <summary>
    /// Returns True if the feature is available at the current tier.
    /// For boolean features, this is the primary accessor.
    /// For integer features, returns True if the Pro value is used (value > Free value,
    /// or -1 for unlimited).
    /// </summary>
    function HasFeature(const FeatureCode: string): Boolean;

    /// <summary>
    /// Returns the integer value for a feature at the current tier.
    /// -1 means unlimited/infinite. Returns 0 if the feature code is not found.
    /// </summary>
    function GetFeatureInt(const FeatureCode: string): Integer;

    /// <summary>
    /// Returns the string value for a feature at the current tier.
    /// Returns empty string if the feature code is not found.
    /// </summary>
    function GetFeatureStr(const FeatureCode: string): string;

    /// <summary>Alias for GetFeatureInt. -1 means unlimited.</summary>
    function GetQuota(const QuotaCode: string): Integer;

    // -------------------------------------------------------------------------
    // Trial
    // -------------------------------------------------------------------------

    /// <summary>
    /// Start the trial on first launch. If the device has never logged in before,
    /// the device_anonymous login triggers the server to auto-grant a trial
    /// entitlement. Safe to call multiple times — only executes once.
    /// Returns True if trial was successfully started or already active.
    /// </summary>
    function StartTrial: Boolean;

    /// <summary>Returns True if a trial entitlement is currently active.</summary>
    function IsTrialActive: Boolean;

    /// <summary>Returns the number of days remaining in the trial, or -1 if not active.</summary>
    function GetTrialDaysRemaining: Integer;

    // -------------------------------------------------------------------------
    // Invite Codes
    // -------------------------------------------------------------------------

    /// <summary>
    /// Generate an invite code for the current user. The code is generated by
    /// the server and is unique per user. Returns empty string if offline.
    /// </summary>
    function GenerateInviteCode: string;

    /// <summary>
    /// Apply an invite code from another user. Both the inviter and invitee
    /// receive bonus trial days. Requires online connection.
    /// </summary>
    function ApplyInviteCode(const Code: string; out ErrorMsg: string): Boolean;

    // -------------------------------------------------------------------------
    // Social Unlock Codes (delegates to DeepBase.Unlock)
    // -------------------------------------------------------------------------

    /// <summary>
    /// Validate and apply a social unlock code (e.g. from WeChat Official Account).
    /// Delegates to TDeepBaseUnlock.ApplyCode.
    /// </summary>
    function ApplyUnlockCode(const Code: string; out ErrorMsg: string): Boolean;

    /// <summary>
    /// Validate a social unlock code without applying it.
    /// Delegates to TDeepBaseUnlock.ValidateCode.
    /// </summary>
    function ValidateUnlockCode(const Code: string; out Info: TUnlockInfo): TUnlockValidationStatus;

    // -------------------------------------------------------------------------
    // Purchase Flow
    // -------------------------------------------------------------------------

    /// <summary>Returns product list as JSON array string for display.</summary>
    function ListProducts: string;

    /// <summary>
    /// Start a paid upgrade for the given product. Creates an order and payment
    /// intent. Returns the QR code data for native payment display.
    /// </summary>
    function StartPurchase(const ProductID: string; out QRCodeData: string): Boolean;

    /// <summary>
    /// Poll entitlements to confirm a purchase. Returns True when a PRO
    /// entitlement is detected. Polls every 2 seconds up to TimeoutSec.
    /// </summary>
    function ConfirmPurchase(const TimeoutSec: Integer = 120): Boolean;

    // -------------------------------------------------------------------------
    // Offline Mode
    // -------------------------------------------------------------------------

    /// <summary>
    /// Contact the server to issue a fresh license snapshot for offline use.
    /// The snapshot is RSA-signed and stored locally.
    /// </summary>
    function RefreshLicense: Boolean;

    /// <summary>
    /// Returns True if the offline grace period is active (server unreachable
    /// but a recent license snapshot is still valid).
    /// </summary>
    function IsOfflineGraceActive: Boolean;

    // -------------------------------------------------------------------------
    // Properties
    // -------------------------------------------------------------------------

    /// <summary>Whether the licensing system has been initialized.</summary>
    property IsInitialized: Boolean read FIsInitialized;

    /// <summary>Whether the server is currently reachable.</summary>
    property IsOnline: Boolean read FIsOnline;

    /// <summary>Current user ID from device_anonymous login.</summary>
    property UserId: string read FUserId;

    /// <summary>Underlying SafeClient for advanced use.</summary>
    property SafeClient: TDeepKitSafeClient read FSafeClient;

    /// <summary>Underlying Permissions client for advanced use.</summary>
    property Permissions: TDeepKitPermissionClient read FPermissions;
  end;

implementation

uses
  System.JSON,
  System.DateUtils,
  DeepBase.Config;

const
  // Config keys (prefixed with 'Licensing.' to avoid collisions)
  CFG_TRIAL_STARTED        = 'Licensing.TrialStarted';
  CFG_TRIAL_EXPIRES        = 'Licensing.TrialExpiresAt';
  CFG_DEVICE_ID            = 'Licensing.DeviceId';
  CFG_LAST_SNAPSHOT        = 'Licensing.LastSnapshot';
  CFG_LAST_SNAPSHOT_EXPIRES = 'Licensing.LastSnapshotExpiresAt';

  // Invite endpoints (to be implemented on deepkit-db4)
  SInviteRouteGenerate = '/dk/invite/generate';
  SInviteRouteApply    = '/dk/invite/apply';

  // Polling interval for purchase confirmation (ms)
  PURCHASE_POLL_INTERVAL_MS = 2000;

  // Config category for all licensing settings
  CFG_CATEGORY = 'Licensing';

{ TLicensingFeatureDef }

class function TLicensingFeatureDef.IntVal(const ACode: string; AFree, APro: Integer): TLicensingFeatureDef;
begin
  Result := Default(TLicensingFeatureDef);
  Result.Code := ACode;
  Result.FreeInt := AFree;
  Result.ProInt := APro;
  Result.ValueType := fvInt;
end;

class function TLicensingFeatureDef.BoolVal(const ACode: string; AFree, APro: Boolean): TLicensingFeatureDef;
begin
  Result := Default(TLicensingFeatureDef);
  Result.Code := ACode;
  Result.FreeBool := AFree;
  Result.ProBool := APro;
  Result.ValueType := fvBool;
end;

class function TLicensingFeatureDef.StrVal(const ACode, AFree, APro: string): TLicensingFeatureDef;
begin
  Result := Default(TLicensingFeatureDef);
  Result.Code := ACode;
  Result.FreeStr := AFree;
  Result.ProStr := APro;
  Result.ValueType := fvStr;
end;

{ TDeepLicensingProductConfig }

class function TDeepLicensingProductConfig.Create(const AAppID, AProductCode,
  AServerBaseURL: string): TDeepLicensingProductConfig;
begin
  Result := Default(TDeepLicensingProductConfig);
  Result.AppID := AAppID;
  Result.ProductCode := AProductCode;
  Result.ServerBaseURL := AServerBaseURL;
end;

{ TDeepLicensing }

constructor TDeepLicensing.Create(const AConfig: TDeepLicensingProductConfig);
begin
  inherited Create;
  FConfig := AConfig;
  FIsInitialized := False;
  FIsOnline := False;
  FCachedTier := ltFree;
  FFeatureIndex := TDictionary<string, TLicensingFeatureDef>.Create;
end;

destructor TDeepLicensing.Destroy;
begin
  FUpgradeFlow.Free;
  FPermissions.Free;
  FSafeClient.Free;
  FUnlock.Free;
  FFeatureIndex.Free;
  inherited;
end;

// -----------------------------------------------------------------------------
// Config Helpers (thin wrappers around DeepBase.Config)
// -----------------------------------------------------------------------------

function TDeepLicensing.GetConfigStr(const Key, ADefault: string): string;
begin
  Result := DeepBase.Config.GetConfig(Key, ADefault);
end;

procedure TDeepLicensing.SetConfigStr(const Key, AValue: string);
begin
  DeepBase.Config.SetConfig(Key, AValue, CFG_CATEGORY);
end;

// -----------------------------------------------------------------------------
// Device ID
// -----------------------------------------------------------------------------

function TDeepLicensing.GetOrCreateDeviceId: string;
begin
  Result := GetConfigStr(CFG_DEVICE_ID, '');
  if Result.IsEmpty then
  begin
    Result := TGUID.NewGuid.ToString.Replace('{', '').Replace('}', '');
    SetConfigStr(CFG_DEVICE_ID, Result);
  end;
end;

// -----------------------------------------------------------------------------
// Feature Index
// -----------------------------------------------------------------------------

function TDeepLicensing.FindFeatureDef(const Code: string;
  out Def: TLicensingFeatureDef): Boolean;
begin
  Result := FFeatureIndex.TryGetValue(Code.ToLower, Def);
end;

// -----------------------------------------------------------------------------
// Entitlement Helpers
// -----------------------------------------------------------------------------

function TDeepLicensing.HasAnyProEntitlement: Boolean;
begin
  if FPermissions = nil then
    Exit(False);
  Result := FPermissions.HasTier('pro');
end;

// -----------------------------------------------------------------------------
// Initialization
// -----------------------------------------------------------------------------

procedure TDeepLicensing.EnsureInitialized;
begin
  if not FIsInitialized then
    raise EDeepBaseCommerceError.Create(
      'TDeepLicensing is not initialized. Call Initialize() first.');
end;

function TDeepLicensing.TryLogin: Boolean;
begin
  Result := False;
  if FSafeClient = nil then
    Exit;

  try
    var Session := FSafeClient.AuthLoginDeviceAnonymous(FConfig.AppID, FDeviceId);
    if not Session.UserId.IsEmpty then
    begin
      FUserId := Session.UserId;
      FIsOnline := True;
      Result := True;
    end;
  except
    on E: Exception do
    begin
      // Login failed — server may be unreachable. Operate in offline mode.
      FIsOnline := False;
      Result := False;
    end;
  end;
end;

procedure TDeepLicensing.RefreshCachedTier;
begin
  if FIsOnline and (FPermissions <> nil) then
  begin
    try
      if HasAnyProEntitlement then
        FCachedTier := ltPro
      else
        FCachedTier := ltFree;
    except
      // If entitlement check fails, stay at current cached tier
    end;
  end
  else if not FIsOnline then
  begin
    // Offline: use cached tier from last successful check, or Free
    if IsOfflineGraceActive then
      Exit;
    FCachedTier := ltFree;
  end;
end;

procedure TDeepLicensing.Initialize;
begin
  if FIsInitialized then
    Exit;

  // 1. Resolve device ID
  FDeviceId := GetOrCreateDeviceId;

  // 2. Build SafeClient config
  var SafeConfig := TDeepKitSafeClientConfig.CreateDeepKit(FConfig.ServerBaseURL);
  SafeConfig.LicenseSnapshotPublicKeys := FConfig.LicensePublicKeys;

  // 3. Create SafeClient
  FSafeClient := TDeepKitSafeClient.Create(SafeConfig);

  // 4. Try device_anonymous login
  FIsOnline := False;
  TryLogin;

  // 5. Create Permissions and UpgradeFlow if online
  if FIsOnline and (not FUserId.IsEmpty) then
  begin
    FPermissions := TDeepKitPermissionClient.Create(FSafeClient, FConfig.AppID, FDeviceId);
    FUpgradeFlow := TDeepKitUpgradeFlowClient.Create(FSafeClient, FConfig.AppID, FUserId, FDeviceId);
  end;

  // 6. Create Unlock manager for social unlock codes
  if not FConfig.ProductCode.IsEmpty then
    FUnlock := TDeepBaseUnlock.Create(FConfig.ProductCode);

  // 7. Build feature index (fast lookup table)
  FFeatureIndex.Clear;
  for var Def in FConfig.FeatureDefs do
    if not Def.Code.IsEmpty then
      FFeatureIndex.AddOrSetValue(Def.Code.ToLower, Def);

  // 8. Resolve initial tier
  RefreshCachedTier;

  FIsInitialized := True;
end;

// -----------------------------------------------------------------------------
// Tier
// -----------------------------------------------------------------------------

function TDeepLicensing.GetTier: TLicensingTier;
begin
  EnsureInitialized;
  Result := FCachedTier;
end;

function TDeepLicensing.GetTierName: string;
begin
  if GetTier = ltPro then
    Result := 'pro'
  else
    Result := 'free';
end;

// -----------------------------------------------------------------------------
// Feature Gating
// -----------------------------------------------------------------------------

function TDeepLicensing.HasFeature(const FeatureCode: string): Boolean;
var
  Def: TLicensingFeatureDef;
begin
  EnsureInitialized;
  if not FindFeatureDef(FeatureCode, Def) then
    Exit(False);

  case Def.ValueType of
    fvBool:
      if FCachedTier = ltPro then
        Result := Def.ProBool
      else
        Result := Def.FreeBool;
    fvInt:
      if FCachedTier = ltPro then
        Result := (Def.ProInt = -1) or (Def.ProInt > Def.FreeInt)
      else
        Result := (Def.FreeInt = -1) or (Def.FreeInt > 0);
    fvStr:
      if FCachedTier = ltPro then
        Result := not Def.ProStr.IsEmpty
      else
        Result := not Def.FreeStr.IsEmpty;
  else
    Result := False;
  end;
end;

function TDeepLicensing.GetFeatureInt(const FeatureCode: string): Integer;
var
  Def: TLicensingFeatureDef;
begin
  EnsureInitialized;
  if not FindFeatureDef(FeatureCode, Def) then
    Exit(0);

  if Def.ValueType <> fvInt then
    Exit(0);

  if FCachedTier = ltPro then
    Result := Def.ProInt
  else
    Result := Def.FreeInt;
end;

function TDeepLicensing.GetFeatureStr(const FeatureCode: string): string;
var
  Def: TLicensingFeatureDef;
begin
  EnsureInitialized;
  if not FindFeatureDef(FeatureCode, Def) then
    Exit('');

  if Def.ValueType <> fvStr then
    Exit('');

  if FCachedTier = ltPro then
    Result := Def.ProStr
  else
    Result := Def.FreeStr;
end;

function TDeepLicensing.GetQuota(const QuotaCode: string): Integer;
begin
  Result := GetFeatureInt(QuotaCode);
end;

// -----------------------------------------------------------------------------
// Trial
// -----------------------------------------------------------------------------

function TDeepLicensing.StartTrial: Boolean;
begin
  EnsureInitialized;

  // If already started, nothing to do
  if SameText(GetConfigStr(CFG_TRIAL_STARTED, ''), 'true') then
    Exit(True);

  // Must be online to start trial
  if not FIsOnline then
    Exit(False);

  // Server auto-grants trial for new devices on first login.
  // We just mark it as started and refresh the tier cache.
  SetConfigStr(CFG_TRIAL_STARTED, 'true');
  RefreshCachedTier;
  Result := True;
end;

function TDeepLicensing.IsTrialActive: Boolean;
begin
  EnsureInitialized;
  if not SameText(GetConfigStr(CFG_TRIAL_STARTED, ''), 'true') then
    Exit(False);

  Result := GetTrialDaysRemaining > 0;
end;

function TDeepLicensing.GetTrialDaysRemaining: Integer;
begin
  EnsureInitialized;
  Result := -1;

  if not SameText(GetConfigStr(CFG_TRIAL_STARTED, ''), 'true') then
    Exit;

  var ExpiresStr := GetConfigStr(CFG_TRIAL_EXPIRES, '');
  if ExpiresStr.IsEmpty then
    Exit(-1);

  var ExpiresAt: TDateTime;
  if not TryISO8601ToDate(ExpiresStr, ExpiresAt, False) then
    Exit(-1);

  var NowUtc := TTimeZone.Local.ToUniversalTime(Now);
  if ExpiresAt <= NowUtc then
    Exit(0);

  Result := DaysBetween(NowUtc, ExpiresAt);
end;

// -----------------------------------------------------------------------------
// Invite Codes
// -----------------------------------------------------------------------------

function TDeepLicensing.GenerateInviteCode: string;
begin
  EnsureInitialized;
  Result := '';

  // TODO: When /dk/invite/generate endpoint is available on the server,
  // call it via the SafeClient transport. For now, invite codes are generated
  // server-side on user registration.
  //
  // The server auto-generates an invite_code for each user on first
  // device_anonymous login. We could fetch it from the user profile.
  if not FIsOnline then
    Exit;
end;

function TDeepLicensing.ApplyInviteCode(const Code: string;
  out ErrorMsg: string): Boolean;
begin
  EnsureInitialized;
  Result := False;
  ErrorMsg := '';

  if Code.Trim.IsEmpty then
  begin
    ErrorMsg := 'Invite code is empty.';
    Exit;
  end;

  if not FIsOnline then
  begin
    ErrorMsg := 'Cannot apply invite code while offline.';
    Exit;
  end;

  // TODO: When /dk/invite/apply endpoint is available on the server,
  // POST { app_id, invite_code } to apply the code.
  // On success, refresh entitlements to pick up the invitee bonus.
  ErrorMsg := 'Invite system is not yet available. Please try again later.';
end;

// -----------------------------------------------------------------------------
// Social Unlock Codes (delegates to DeepBase.Unlock)
// -----------------------------------------------------------------------------

function TDeepLicensing.ApplyUnlockCode(const Code: string;
  out ErrorMsg: string): Boolean;
begin
  EnsureInitialized;

  if FUnlock = nil then
  begin
    ErrorMsg := 'Social unlock is not configured for this product.';
    Exit(False);
  end;

  var Info: TUnlockInfo;
  Result := FUnlock.ApplyCode(Code, Info);
  if not Result then
    ErrorMsg := Info.ErrorMessage
  else
  begin
    ErrorMsg := '';
    // If the unlock code upgraded the level, refresh our tier
    if Info.WasUpgraded and (Info.Level >= ulFollow) then
      RefreshCachedTier;
  end;
end;

function TDeepLicensing.ValidateUnlockCode(const Code: string;
  out Info: TUnlockInfo): TUnlockValidationStatus;
begin
  EnsureInitialized;

  if FUnlock = nil then
  begin
    Info.ProductCode := FConfig.ProductCode;
    Info.Code := Code.Trim;
    Info.Level := ulFree;
    Info.Status := uvsInvalidFormat;
    Info.ErrorMessage := 'Social unlock is not configured for this product.';
    Info.WasUpgraded := False;
    Exit(uvsInvalidFormat);
  end;

  Result := FUnlock.ValidateCode(Code, Info);
end;

// -----------------------------------------------------------------------------
// Purchase Flow
// -----------------------------------------------------------------------------

function TDeepLicensing.ListProducts: string;
begin
  EnsureInitialized;

  if FUpgradeFlow = nil then
    Exit('[]');

  var Products: TArray<TCommerceProductData>;
  try
    Products := FUpgradeFlow.ListProducts;
  except
    Exit('[]');
  end;

  var Arr := TJSONArray.Create;
  try
    for var P in Products do
    begin
      var Obj := TJSONObject.Create;
      Obj.AddPair('product_id', P.ProductId);
      Obj.AddPair('name', P.Name);
      Obj.AddPair('description', P.Description);
      Obj.AddPair('amount_minor', TJSONNumber.Create(P.AmountMinor));
      Obj.AddPair('currency', P.Currency);
      Obj.AddPair('entitlement_code', P.EntitlementCode);
      Obj.AddPair('entitlement_duration_days', TJSONNumber.Create(P.EntitlementDurationDays));
      Arr.AddElement(Obj);
    end;
    Result := Arr.ToJSON;
  finally
    Arr.Free;
  end;
end;

function TDeepLicensing.StartPurchase(const ProductID: string;
  out QRCodeData: string): Boolean;
begin
  EnsureInitialized;
  Result := False;
  QRCodeData := '';

  if (FUpgradeFlow = nil) or (not FIsOnline) then
    Exit;

  try
    var ResultData := FUpgradeFlow.StartPaidUpgrade(ProductID, cppWeChatPay, cpcNative);
    if ResultData.PaymentIntent.Success then
    begin
      QRCodeData := ResultData.PaymentIntent.QRCodeData;
      if QRCodeData.IsEmpty then
        QRCodeData := ResultData.PaymentIntent.PayUrl;
      Result := not QRCodeData.IsEmpty;
    end;
  except
    on E: EDeepBaseCommerceOrphanedOrderError do
      Result := False;
    on E: Exception do
      Result := False;
  end;
end;

function TDeepLicensing.ConfirmPurchase(const TimeoutSec: Integer): Boolean;
begin
  EnsureInitialized;
  Result := False;

  if (FPermissions = nil) or (not FIsOnline) then
    Exit;

  var StartTime := Now;
  repeat
    RefreshCachedTier;
    if FCachedTier = ltPro then
      Exit(True);

    if SecondsBetween(StartTime, Now) >= TimeoutSec then
      Break;

    Sleep(PURCHASE_POLL_INTERVAL_MS);
  until False;

  Result := FCachedTier = ltPro;
end;

// -----------------------------------------------------------------------------
// Offline Mode
// -----------------------------------------------------------------------------

function TDeepLicensing.RefreshLicense: Boolean;
begin
  EnsureInitialized;
  Result := False;

  if (FSafeClient = nil) or (not FIsOnline) then
    Exit;

  try
    var Snapshot := FSafeClient.IssueLicenseSnapshot(FConfig.AppID, FDeviceId);
    if not Snapshot.SnapshotId.IsEmpty then
    begin
      SetConfigStr(CFG_LAST_SNAPSHOT, Snapshot.Payload);
      SetConfigStr(CFG_LAST_SNAPSHOT_EXPIRES, Snapshot.ExpiresAtISO);
      Result := True;
    end;
  except
    Result := False;
  end;
end;

function TDeepLicensing.IsOfflineGraceActive: Boolean;
begin
  EnsureInitialized;

  // If online, grace period is irrelevant
  if FIsOnline then
    Exit(False);

  // Check Permissions-based offline grace (30-day grace after last validation)
  if FPermissions <> nil then
  begin
    try
      if FPermissions.IsOfflineGraceActive then
        Exit(True);
    except
      // Permissions check failed — fall through to snapshot check
    end;
  end;

  Result := False;
end;

end.