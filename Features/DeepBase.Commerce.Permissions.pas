unit DeepBase.Commerce.Permissions;

interface

uses
  System.SysUtils,
  System.DateUtils,
  System.Generics.Collections,
  DeepBase.Commerce.Types,
  DeepBase.Commerce.SafeClient;

type
  EDeepKitPermissionDenied = class(EDeepBaseCommerceError);

  TRevocationReason = (rrUnknown, rrRefund, rrBan, rrUnbind, rrAdminOverride);

  TDeepKitPermissionResult = record
    Allowed: Boolean;
    FeatureCode: string;
    EntitlementCode: string;
    RemainingQuota: Integer;
    Reason: string;
    class function Denied(const AFeatureCode, AReason: string):
      TDeepKitPermissionResult; static;
  end;

  TDeepKitPermissionClient = class
  private
    FClient: TDeepKitSafeClient;
    FOwnsClient: Boolean;
    FAppId: string;
    FDeviceId: string;
    FDefaultEntitlementCode: string;
    FWildcardCodes: TList<string>;
    FLastSnapshot: TDeepKitLicenseSnapshot;

    function EntitlementMatchesFeature(const AEntitlement: TCommerceEntitlementData;
      const AFeatureCode: string): Boolean;
  public
    constructor Create(AClient: TDeepKitSafeClient; const AAppId: string;
      const ADeviceId: string = ''; AOwnsClient: Boolean = False);
    destructor Destroy; override;

    function HasFeature(const AFeatureCode: string): TDeepKitPermissionResult;
    procedure RequireFeature(const AFeatureCode: string);
    function ConsumeQuota(const AFeatureCode: string; AQuantity: Integer = 1;
      const ARequestId: string = ''): TDeepKitConsumeEntitlementResult;
    function RefreshLicenseSnapshot: TDeepKitLicenseSnapshot;
    function HasTier(const ATier: string): Boolean;
    procedure RequireTier(const ATier: string);
    function IsOfflineGraceActive: Boolean;

    class function TierRank(const ATier: string): Integer; static;

    property AppId: string read FAppId write FAppId;
    property DeviceId: string read FDeviceId write FDeviceId;
    property DefaultEntitlementCode: string read FDefaultEntitlementCode
      write FDefaultEntitlementCode;
    property WildcardCodes: TList<string> read FWildcardCodes;
    property LastSnapshot: TDeepKitLicenseSnapshot read FLastSnapshot;
  end;

  TOnLicenseRevoked = procedure(AReason: TRevocationReason;
    const ASnapshotId: string) of object;

  /// <summary>
  /// Tracks the highest revocation version seen from the server and
  /// detects when a previously-issued snapshot has been revoked.
  /// Call CheckSnapshot after each license refresh; call UpdateRevocationVersion
  /// when the server reports a new global revocation version.
  /// </summary>
  TLicenseRevocationPolicy = class
  private
    FKnownRevocationVersion: Integer;
    FOnRevoked: TOnLicenseRevoked;

  public
    constructor Create;

    /// <summary>
    /// Updates the known revocation version if AVersion is higher.
    /// Returns True if the version was updated (new revocations detected).
    /// </summary>
    function UpdateRevocationVersion(AVersion: Integer): Boolean;

    /// <summary>
    /// Checks if ASnapshot has been revoked (its RevocationVersion is less
    /// than the known global version). If revoked, fires OnRevoked callback.
    /// Returns True if the snapshot is still valid (not revoked).
    /// </summary>
    function CheckSnapshot(const ASnapshot: TDeepKitLicenseSnapshot): Boolean;

    /// <summary>Current known revocation version (read-only)</summary>
    property KnownRevocationVersion: Integer read FKnownRevocationVersion;

    /// <summary>
    /// Optional callback fired when a snapshot is detected as revoked.
    /// </summary>
    property OnRevoked: TOnLicenseRevoked read FOnRevoked write FOnRevoked;
  end;

implementation

function IsEntitlementCurrentlyUsable(
  const AEntitlement: TCommerceEntitlementData): Boolean;
begin
  Result := IsCommerceEntitlementUsable(AEntitlement);
end;

class function TDeepKitPermissionResult.Denied(const AFeatureCode,
  AReason: string): TDeepKitPermissionResult;
begin
  Result.Allowed := False;
  Result.FeatureCode := AFeatureCode;
  Result.EntitlementCode := '';
  Result.RemainingQuota := 0;
  Result.Reason := AReason;
end;

constructor TDeepKitPermissionClient.Create(AClient: TDeepKitSafeClient;
  const AAppId, ADeviceId: string; AOwnsClient: Boolean);
begin
  inherited Create;
  if AClient = nil then
    raise EDeepBaseCommerceValidationError.Create('Permission client requires a safe client');
  if AAppId.Trim = '' then
    raise EDeepBaseCommerceValidationError.Create('Permission client app_id is required');

  FClient := AClient;
  FOwnsClient := AOwnsClient;
  FAppId := AAppId;
  FDeviceId := ADeviceId;
  FDefaultEntitlementCode := '';
  FWildcardCodes := TList<string>.Create;
  FWildcardCodes.AddRange(['all', 'pro_full', 'enterprise_full']);
end;

destructor TDeepKitPermissionClient.Destroy;
begin
  FWildcardCodes.Free;
  if FOwnsClient then
    FClient.Free;
  inherited;
end;

function TDeepKitPermissionClient.EntitlementMatchesFeature(
  const AEntitlement: TCommerceEntitlementData;
  const AFeatureCode: string): Boolean;
var
  Wildcard: string;
begin
  if SameText(AEntitlement.Code, AFeatureCode) then
    Exit(True);
  for Wildcard in FWildcardCodes do
    if SameText(AEntitlement.Code, Wildcard) then
      Exit(True);
  if (FDefaultEntitlementCode <> '') and
     SameText(AEntitlement.Code, FDefaultEntitlementCode) then
    Exit(True);
  Result := False;
end;

function TDeepKitPermissionClient.HasFeature(
  const AFeatureCode: string): TDeepKitPermissionResult;
var
  Items: TCommerceEntitlementArray;
  Entitlement: TCommerceEntitlementData;
begin
  if AFeatureCode.Trim = '' then
    Exit(TDeepKitPermissionResult.Denied(AFeatureCode, 'feature_code_required'));

  Items := FClient.ListEntitlements(FAppId);
  for Entitlement in Items do
  begin
    if not IsEntitlementCurrentlyUsable(Entitlement) then
      Continue;
    if not EntitlementMatchesFeature(Entitlement, AFeatureCode) then
      Continue;

    Result.Allowed := True;
    Result.FeatureCode := AFeatureCode;
    Result.EntitlementCode := Entitlement.Code;
    Result.RemainingQuota := Entitlement.RemainingQuota;
    Result.Reason := '';
    Exit;
  end;

  Result := TDeepKitPermissionResult.Denied(AFeatureCode, 'not_entitled');
end;

procedure TDeepKitPermissionClient.RequireFeature(const AFeatureCode: string);
var
  Check: TDeepKitPermissionResult;
begin
  Check := HasFeature(AFeatureCode);
  if not Check.Allowed then
    raise EDeepKitPermissionDenied.CreateFmt(
      'Feature "%s" is not allowed: %s', [AFeatureCode, Check.Reason]);
end;

function TDeepKitPermissionClient.ConsumeQuota(const AFeatureCode: string;
  AQuantity: Integer; const ARequestId: string): TDeepKitConsumeEntitlementResult;
var
  Check: TDeepKitPermissionResult;
  EntitlementCode: string;
begin
  Check := HasFeature(AFeatureCode);
  if not Check.Allowed then
    raise EDeepKitPermissionDenied.CreateFmt(
      'Feature "%s" is not allowed: %s', [AFeatureCode, Check.Reason]);

  EntitlementCode := Check.EntitlementCode;
  if EntitlementCode = '' then
  begin
    if FDefaultEntitlementCode <> '' then
      EntitlementCode := FDefaultEntitlementCode
    else
      raise EDeepBaseCommerceError.CreateFmt(
        'HasFeature returned allowed=True for "%s" but no entitlement code was matched', [AFeatureCode]);
  end;

  Result := FClient.ConsumeEntitlement(FAppId, EntitlementCode,
    AFeatureCode, AQuantity, ARequestId);
end;

function TDeepKitPermissionClient.RefreshLicenseSnapshot:
  TDeepKitLicenseSnapshot;
begin
  if FDeviceId.Trim = '' then
    raise EDeepBaseCommerceValidationError.Create(
      'Permission client device_id is required to refresh license snapshot');
  FLastSnapshot := FClient.RefreshLicenseSnapshot(FAppId, FDeviceId);
  Result := FLastSnapshot;
end;

class function TDeepKitPermissionClient.TierRank(const ATier: string): Integer;
begin
  if SameText(ATier, 'enterprise') then Exit(4);
  if SameText(ATier, 'pro') then Exit(3);
  if SameText(ATier, 'standard') then Exit(2);
  if SameText(ATier, 'free') then Exit(1);
  Result := 0;
end;

function TDeepKitPermissionClient.HasTier(const ATier: string): Boolean;
var
  Items: TCommerceEntitlementArray;
  Entitlement: TCommerceEntitlementData;
  RequiredRank, EntitlementRank: Integer;
begin
  RequiredRank := TierRank(ATier);
  if RequiredRank = 0 then
    Exit(False);

  Items := FClient.ListEntitlements(FAppId);
  for Entitlement in Items do
  begin
    if not IsEntitlementCurrentlyUsable(Entitlement) then
      Continue;
    EntitlementRank := TierRank(Entitlement.Tier);
    if EntitlementRank >= RequiredRank then
      Exit(True);
  end;
  Result := False;
end;

procedure TDeepKitPermissionClient.RequireTier(const ATier: string);
begin
  if not HasTier(ATier) then
    raise EDeepKitPermissionDenied.CreateFmt(
      'License tier "%s" or higher is required', [ATier]);
end;

function TDeepKitPermissionClient.IsOfflineGraceActive: Boolean;
var
  Items: TCommerceEntitlementArray;
  Entitlement: TCommerceEntitlementData;
  ValidUntil, LastValidated, GraceExpiry, NowUtc: TDateTime;
begin
  NowUtc := TTimeZone.Local.ToUniversalTime(Now);
  Items := FClient.ListEntitlements(FAppId);
  for Entitlement in Items do
  begin
    if Entitlement.Status <> cesActive then
      Continue;
    if Entitlement.OfflineGraceDays <= 0 then
      Continue;
    if Entitlement.ValidUntilISO = '' then
      Continue;
    if not TryISO8601ToDate(Entitlement.ValidUntilISO, ValidUntil, False) then
      Continue;
    if ValidUntil > NowUtc then
      Exit(True);
    if (Entitlement.LastValidatedISO <> '') and
       TryISO8601ToDate(Entitlement.LastValidatedISO, LastValidated, False) then
    begin
      GraceExpiry := LastValidated + Entitlement.OfflineGraceDays;
      if GraceExpiry > NowUtc then
        Exit(True);
    end;
  end;
  Result := False;
end;

{ TLicenseRevocationPolicy }

constructor TLicenseRevocationPolicy.Create;
begin
  inherited Create;
  FKnownRevocationVersion := 0;
  FOnRevoked := nil;
end;


function TLicenseRevocationPolicy.UpdateRevocationVersion(AVersion: Integer): Boolean;
begin
  if AVersion > FKnownRevocationVersion then
  begin
    FKnownRevocationVersion := AVersion;
    Result := True;
  end
  else
    Result := False;
end;

function TLicenseRevocationPolicy.CheckSnapshot(
  const ASnapshot: TDeepKitLicenseSnapshot): Boolean;
begin
  // A snapshot is valid (not revoked) if its RevocationVersion is >= the known
  // global version. If the known version has advanced past the snapshot's,
  // the snapshot has been superseded by a newer revocation.
  if ASnapshot.RevocationVersion < FKnownRevocationVersion then
  begin
    // Snapshot is revoked — fire callback if registered
    if Assigned(FOnRevoked) then
      FOnRevoked(rrUnknown, ASnapshot.SnapshotId);
    Result := False;
  end
  else
  begin
    // Snapshot is still valid; opportunistically update our known version
    if ASnapshot.RevocationVersion > FKnownRevocationVersion then
      FKnownRevocationVersion := ASnapshot.RevocationVersion;
    Result := True;
  end;
end;

end.
