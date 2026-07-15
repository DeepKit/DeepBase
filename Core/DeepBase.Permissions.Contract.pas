{ ============================================================================
  DeepBase.Permissions.Contract
  ---------------------------------------------------------------------------
  Version     : 1.0
  Description : Abstract permission/entitlement contract that decouples
                feature modules (Speech, Platform, etc.) from Commerce
                implementation details. Modules depend on this interface
                rather than concrete Commerce classes.
  Thread Safety: Implementations must be thread-safe.
  ============================================================================ }

unit DeepBase.Permissions.Contract;

interface

uses
  System.SysUtils;

type
  /// <summary>
  /// Result of a permission check. Mirrors TDeepKitPermissionResult but
  /// without Commerce dependencies.
  /// </summary>
  TPermissionResult = record
    Allowed: Boolean;
    FeatureCode: string;
    EntitlementCode: string;
    RemainingQuota: Integer;
    Reason: string;

    class function Denied(const AFeatureCode, AReason: string): TPermissionResult; static;
    class function AllowedResult(const AFeatureCode, AEntitlementCode: string;
      ARemainingQuota: Integer = -1): TPermissionResult; static;
  end;

  /// <summary>
  /// Abstract permission client interface. Feature modules (Speech, Platform,
  /// Desktop Lifecycle, etc.) depend on this interface rather than concrete
  /// Commerce implementations like TDeepKitPermissionClient.
  ///
  /// Implementations:
  /// - TDeepKitPermissionClient (Commerce implementation)
  /// - TFakePermissionClient (for testing)
  /// - TNoOpPermissionClient (for development/free tier)
  /// </summary>
  IPermissionClient = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']

    /// <summary>
    /// Check if a feature is available without raising an exception.
    /// Returns a result record with Allowed=True/False and reason if denied.
    /// </summary>
    function HasFeature(const AFeatureCode: string): TPermissionResult;

    /// <summary>
    /// Check if a feature is available and raise an exception if not.
    /// Implementations should raise EPermissionDenied or similar.
    /// </summary>
    procedure RequireFeature(const AFeatureCode: string);

    /// <summary>
    /// Consume quota for a feature (e.g., API calls, credits).
    /// Returns the result with remaining quota.
    /// </summary>
    function ConsumeQuota(const AFeatureCode: string; AQuantity: Integer = 1;
      const ARequestId: string = ''): Integer;

    /// <summary>
    /// Check if a specific tier is available (e.g., 'free', 'pro', 'enterprise').
    /// Returns True if the user has at least the specified tier.
    /// </summary>
    function HasTier(const ATier: string): Boolean;

    /// <summary>
    /// Check if a tier is available and raise an exception if not.
    /// </summary>
    procedure RequireTier(const ATier: string);

    /// <summary>
    /// Check if offline grace period is active (allows continued use when
    /// server is unreachable). Returns True if offline use is allowed.
    /// </summary>
    function IsOfflineGraceActive: Boolean;
  end;

  /// <summary>
  /// Exception raised when a feature is not permitted.
  /// </summary>
  EPermissionDenied = class(Exception)
  private
    FFeatureCode: string;
    FReason: string;
  public
    constructor Create(const AFeatureCode, AReason: string);
    property FeatureCode: string read FFeatureCode;
    property Reason: string read FReason;
  end;

  /// <summary>
  /// Exception raised when a tier requirement is not met.
  /// </summary>
  ETierRequired = class(Exception)
  private
    FRequiredTier: string;
    FCurrentTier: string;
  public
    constructor Create(const ARequiredTier, ACurrentTier: string);
    property RequiredTier: string read FRequiredTier;
    property CurrentTier: string read FCurrentTier;
  end;

  /// <summary>
  /// No-op permission client that allows all features. Useful for
  /// development, testing, or free-tier applications.
  /// </summary>
  TNoOpPermissionClient = class(TInterfacedObject, IPermissionClient)
  public
    function HasFeature(const AFeatureCode: string): TPermissionResult;
    procedure RequireFeature(const AFeatureCode: string);
    function ConsumeQuota(const AFeatureCode: string; AQuantity: Integer = 1;
      const ARequestId: string = ''): Integer;
    function HasTier(const ATier: string): Boolean;
    procedure RequireTier(const ATier: string);
    function IsOfflineGraceActive: Boolean;
  end;

implementation

{ TPermissionResult }

class function TPermissionResult.Denied(const AFeatureCode, AReason: string): TPermissionResult;
begin
  Result.Allowed := False;
  Result.FeatureCode := AFeatureCode;
  Result.EntitlementCode := '';
  Result.RemainingQuota := 0;
  Result.Reason := AReason;
end;

class function TPermissionResult.AllowedResult(const AFeatureCode, AEntitlementCode: string;
  ARemainingQuota: Integer): TPermissionResult;
begin
  Result.Allowed := True;
  Result.FeatureCode := AFeatureCode;
  Result.EntitlementCode := AEntitlementCode;
  Result.RemainingQuota := ARemainingQuota;
  Result.Reason := '';
end;

{ EPermissionDenied }

constructor EPermissionDenied.Create(const AFeatureCode, AReason: string);
begin
  inherited CreateFmt('Permission denied for feature "%s": %s', [AFeatureCode, AReason]);
  FFeatureCode := AFeatureCode;
  FReason := AReason;
end;

{ ETierRequired }

constructor ETierRequired.Create(const ARequiredTier, ACurrentTier: string);
begin
  inherited CreateFmt('Tier "%s" required, but current tier is "%s"', [ARequiredTier, ACurrentTier]);
  FRequiredTier := ARequiredTier;
  FCurrentTier := ACurrentTier;
end;

{ TNoOpPermissionClient }

function TNoOpPermissionClient.HasFeature(const AFeatureCode: string): TPermissionResult;
begin
  Result := TPermissionResult.AllowedResult(AFeatureCode, 'noop', -1);
end;

procedure TNoOpPermissionClient.RequireFeature(const AFeatureCode: string);
begin
  // No-op: always allowed
end;

function TNoOpPermissionClient.ConsumeQuota(const AFeatureCode: string;
  AQuantity: Integer; const ARequestId: string): Integer;
begin
  // No-op: return -1 to indicate unlimited quota
  Result := -1;
end;

function TNoOpPermissionClient.HasTier(const ATier: string): Boolean;
begin
  // No-op: all tiers available
  Result := True;
end;

procedure TNoOpPermissionClient.RequireTier(const ATier: string);
begin
  // No-op: always allowed
end;

function TNoOpPermissionClient.IsOfflineGraceActive: Boolean;
begin
  // No-op: offline grace always active
  Result := True;
end;

end.
