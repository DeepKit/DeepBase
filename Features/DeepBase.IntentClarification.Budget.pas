unit DeepBase.IntentClarification.Budget;

interface

uses
  System.SysUtils,
  System.DateUtils,
  DeepBase.IntentClarification.Types,
  DeepBase.IntentClarification.Interfaces;

type
  /// <summary>
  /// 预算控制器 - 跟踪轮次使用、时间消耗和 Token 用量，判断预算是否耗尽。
  /// Property 17: 当 MaxTurns 达到时，ShouldExit = True。
  /// Requirements: 5.5, 10.2-10.3
  /// </summary>
  TBudgetController = class
  public
    /// <summary>
    /// Checks budget status given configuration, turns used, tokens used,
    /// and session start time.
    /// Returns a TBudgetStatus indicating remaining budget and whether exit is needed.
    /// </summary>
    function Check(const AConfig: TBudgetConfig; ATurnsUsed: Integer;
      ATokensUsed: Integer; AStartTime: TDateTime): TBudgetStatus; overload;

    /// <summary>
    /// Legacy overload without token tracking (tokens default to 0).
    /// </summary>
    function Check(const AConfig: TBudgetConfig; ATurnsUsed: Integer;
      AStartTime: TDateTime): TBudgetStatus; overload;

    /// <summary>
    /// Returns True if the budget status indicates exhaustion (should exit).
    /// </summary>
    function IsExhausted(const AStatus: TBudgetStatus): Boolean;
  end;

implementation

{ TBudgetController }

function TBudgetController.Check(const AConfig: TBudgetConfig;
  ATurnsUsed: Integer; ATokensUsed: Integer;
  AStartTime: TDateTime): TBudgetStatus;
var
  LElapsedMs: Int64;
  LTimeExhausted: Boolean;
  LTurnsExhausted: Boolean;
  LTokensExhausted: Boolean;
begin
  Result := Default(TBudgetStatus);
  Result.TurnsUsed := ATurnsUsed;
  Result.TokensUsed := ATokensUsed;

  // Calculate time elapsed in milliseconds
  LElapsedMs := MilliSecondsBetween(Now, AStartTime);
  Result.TimeElapsedMs := LElapsedMs;

  // Calculate turns remaining
  if AConfig.MaxTurns > 0 then
    Result.TurnsRemaining := AConfig.MaxTurns - ATurnsUsed
  else
    Result.TurnsRemaining := MaxInt;

  // Calculate tokens remaining
  if AConfig.MaxTokens > 0 then
    Result.TokensRemaining := AConfig.MaxTokens - ATokensUsed
  else
    Result.TokensRemaining := MaxInt;

  // Check exhaustion conditions
  LTurnsExhausted := (AConfig.MaxTurns > 0) and (ATurnsUsed >= AConfig.MaxTurns);
  LTimeExhausted := (AConfig.MaxTimeSeconds > 0) and
    (LElapsedMs >= Int64(AConfig.MaxTimeSeconds) * 1000);
  LTokensExhausted := (AConfig.MaxTokens > 0) and (ATokensUsed >= AConfig.MaxTokens);

  Result.IsExhausted := LTurnsExhausted or LTimeExhausted or LTokensExhausted;
  Result.ShouldExit := Result.IsExhausted;
end;

function TBudgetController.Check(const AConfig: TBudgetConfig;
  ATurnsUsed: Integer; AStartTime: TDateTime): TBudgetStatus;
begin
  Result := Check(AConfig, ATurnsUsed, 0, AStartTime);
end;

function TBudgetController.IsExhausted(const AStatus: TBudgetStatus): Boolean;
begin
  Result := AStatus.IsExhausted;
end;

end.
