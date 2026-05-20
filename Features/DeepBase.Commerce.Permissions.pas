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

    property AppId: string read FAppId write FAppId;
    property DeviceId: string read FDeviceId write FDeviceId;
    property DefaultEntitlementCode: string read FDefaultEntitlementCode
      write FDefaultEntitlementCode;
    property WildcardCodes: TList<string> read FWildcardCodes;
    property LastSnapshot: TDeepKitLicenseSnapshot read FLastSnapshot;
  end;

implementation

function IsEntitlementCurrentlyUsable(
  const AEntitlement: TCommerceEntitlementData): Boolean;
var
  ValidUntil: TDateTime;
begin
  if AEntitlement.Status <> cesActive then
    Exit(False);
  if AEntitlement.RemainingQuota = 0 then
    Exit(False);
  if AEntitlement.ValidUntilISO = '' then
    Exit(True);
  if not TryISO8601ToDate(AEntitlement.ValidUntilISO, ValidUntil, False) then
    Exit(False);
  Result := ValidUntil > TTimeZone.Local.ToUniversalTime(Now);
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
  if FDefaultEntitlementCode <> '' then
    EntitlementCode := FDefaultEntitlementCode;

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

end.
