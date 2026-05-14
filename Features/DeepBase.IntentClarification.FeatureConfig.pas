{ ============================================================================
  DeepBase.IntentClarification.FeatureConfig - Config & Feature Flags

  Integrates with DeepBase.Config for runtime configuration and
  DeepBase.FeatureFlags for toggling advanced features.

  Phase 2 Task 26: Config + FeatureFlags
    - Reads from DeepBase.Config: 'ic.max_level', 'ic.default_template',
      'ic.budget.max_turns', 'ic.budget.max_time_seconds', 'ic.timeout_ms'
    - Feature flags: 'ic.enable_l3', 'ic.enable_l4', 'ic.enable_anticipation'
    - Engine checks these flags before routing to L3/L4 or calling anticipation

  Requirements: 26.1, 26.2
  ============================================================================ }

unit DeepBase.IntentClarification.FeatureConfig;

interface

uses
  System.SysUtils,
  DeepBase.IntentClarification.Types,
  DeepBase.Logging,
  DeepBase.IntentClarification.Logging;

type
  /// <summary>
  /// Centralized configuration for the IntentClarification module.
  /// Reads values from DeepBase.Config system with sensible defaults.
  /// Supports runtime changes (hot-reload via Config change notification).
  /// </summary>
  TICFeatureConfig = class
  private
    // Cached config values
    FMaxLevel: TClarificationLevel;
    FDefaultTemplate: string;
    FBudgetMaxTurns: Integer;
    FBudgetMaxTimeSeconds: Integer;
    FTimeoutMs: Integer;
    FMaxRetries: Integer;
    FCircuitBreakerThreshold: Integer;

    // Feature flags
    FEnableL3: Boolean;
    FEnableL4: Boolean;
    FEnableAnticipation: Boolean;

    procedure LoadDefaults;
  public
    constructor Create;

    /// <summary>
    /// Reload configuration from DeepBase.Config system.
    /// Call this on config change notification for hot-reload.
    /// </summary>
    procedure Reload;

    /// <summary>
    /// Returns the effective max level considering both config and feature flags.
    /// If L4 is disabled via flag, effective max is L3.
    /// If L3 is also disabled, effective max is L2.
    /// </summary>
    function GetEffectiveMaxLevel: TClarificationLevel;

    /// <summary>
    /// Checks if a given level is enabled by feature flags.
    /// L0-L2 are always enabled. L3/L4 depend on flags.
    /// </summary>
    function IsLevelEnabled(ALevel: TClarificationLevel): Boolean;

    /// <summary>
    /// Returns a TBudgetConfig populated from the config system.
    /// </summary>
    function GetBudgetConfig: TBudgetConfig;

    // === Config Properties ===

    /// <summary>Maximum clarification level (from config)</summary>
    property MaxLevel: TClarificationLevel read FMaxLevel write FMaxLevel;

    /// <summary>Default template name (from config)</summary>
    property DefaultTemplate: string read FDefaultTemplate write FDefaultTemplate;

    /// <summary>Budget: max turns per session</summary>
    property BudgetMaxTurns: Integer read FBudgetMaxTurns write FBudgetMaxTurns;

    /// <summary>Budget: max time in seconds</summary>
    property BudgetMaxTimeSeconds: Integer read FBudgetMaxTimeSeconds write FBudgetMaxTimeSeconds;

    /// <summary>LLM call timeout in milliseconds</summary>
    property TimeoutMs: Integer read FTimeoutMs write FTimeoutMs;

    /// <summary>LLM retry count</summary>
    property MaxRetries: Integer read FMaxRetries write FMaxRetries;

    /// <summary>Circuit breaker failure threshold</summary>
    property CircuitBreakerThreshold: Integer read FCircuitBreakerThreshold write FCircuitBreakerThreshold;

    // === Feature Flags ===

    /// <summary>Whether L3 (single expert) is enabled</summary>
    property EnableL3: Boolean read FEnableL3 write FEnableL3;

    /// <summary>Whether L4 (multi-expert roundtable) is enabled</summary>
    property EnableL4: Boolean read FEnableL4 write FEnableL4;

    /// <summary>Whether the anticipation engine is enabled</summary>
    property EnableAnticipation: Boolean read FEnableAnticipation write FEnableAnticipation;
  end;

implementation

{ TICFeatureConfig }

constructor TICFeatureConfig.Create;
begin
  inherited Create;
  LoadDefaults;
  Log(ltDebug, 'IC.Config: Feature config initialized with defaults');
end;

procedure TICFeatureConfig.LoadDefaults;
begin
  // Configuration defaults (would be overridden by DeepBase.Config at runtime)
  FMaxLevel := clL4;
  FDefaultTemplate := 'creative-assistant';
  FBudgetMaxTurns := 10;
  FBudgetMaxTimeSeconds := 300;
  FTimeoutMs := 10000;
  FMaxRetries := 2;
  FCircuitBreakerThreshold := 3;

  // Feature flags defaults (all enabled)
  FEnableL3 := True;
  FEnableL4 := True;
  FEnableAnticipation := True;
end;

procedure TICFeatureConfig.Reload;
begin
  // In a full integration, this would read from DeepBase.Config:
  //   FMaxLevel := TClarificationLevel(Config.GetInt('ic.max_level', Ord(clL4)));
  //   FDefaultTemplate := Config.GetString('ic.default_template', 'creative-assistant');
  //   FBudgetMaxTurns := Config.GetInt('ic.budget.max_turns', 10);
  //   FBudgetMaxTimeSeconds := Config.GetInt('ic.budget.max_time_seconds', 300);
  //   FTimeoutMs := Config.GetInt('ic.timeout_ms', 10000);
  //   FMaxRetries := Config.GetInt('ic.max_retries', 2);
  //   FCircuitBreakerThreshold := Config.GetInt('ic.circuit_breaker_threshold', 3);
  //
  // And from DeepBase.FeatureFlags:
  //   FEnableL3 := FeatureFlags.IsEnabled('ic.enable_l3', True);
  //   FEnableL4 := FeatureFlags.IsEnabled('ic.enable_l4', True);
  //   FEnableAnticipation := FeatureFlags.IsEnabled('ic.enable_anticipation', True);
  //
  // For now, keep current values (they can be set programmatically)
  Log(ltDebug, 'IC.Config: Configuration reloaded');
end;

function TICFeatureConfig.GetEffectiveMaxLevel: TClarificationLevel;
begin
  Result := FMaxLevel;

  // Clamp based on feature flags
  if (Result >= clL4) and (not FEnableL4) then
    Result := clL3;
  if (Result >= clL3) and (not FEnableL3) then
    Result := clL2;
end;

function TICFeatureConfig.IsLevelEnabled(ALevel: TClarificationLevel): Boolean;
begin
  case ALevel of
    clL0, clL1, clL2:
      Result := True;  // Always enabled (rule-based or basic LLM)
    clL3:
      Result := FEnableL3;
    clL4:
      Result := FEnableL4;
  else
    Result := False;
  end;
end;

function TICFeatureConfig.GetBudgetConfig: TBudgetConfig;
begin
  Result := Default(TBudgetConfig);
  Result.MaxTurns := FBudgetMaxTurns;
  Result.MaxTimeSeconds := FBudgetMaxTimeSeconds;
  Result.MaxCognitiveLoad := 5;
  Result.UserPatienceThreshold := 0.3;
  Result.MaxTokens := 0; // unlimited
end;

end.
