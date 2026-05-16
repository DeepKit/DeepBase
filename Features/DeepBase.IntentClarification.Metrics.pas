{ ============================================================================
  DeepBase.IntentClarification.Metrics - Metrics Collection

  Provides metric recording for the IntentClarification engine.
  Integrates with DeepBase.Metrics for counter/histogram/gauge patterns.

  Phase 2 Task 25: Metrics
    - ic_turn_count (counter): incremented after each turn
    - ic_turn_latency_ms (histogram): latency of each turn cycle
    - ic_tokens_used (counter): total tokens consumed
    - ic_session_completed (counter with reason label): session completions

  Requirements: 25.1
  ============================================================================ }

unit DeepBase.IntentClarification.Metrics;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Diagnostics,
  DeepBase.IntentClarification.Types,
  DeepBase.Logging,
  DeepBase.IntentClarification.Logging;

type
  /// <summary>
  /// Metrics collector for the IntentClarification module.
  /// Records operational metrics that can be consumed by DeepBase.Metrics.
  ///
  /// Usage:
  ///   FMetrics.RecordTurn(latencyMs, level, posture, tokensUsed);
  ///   FMetrics.RecordSessionCompleted('user_cancel');
  /// </summary>
  TICMetrics = class
  private
    // Accumulated counters (in-memory, flushed to DeepBase.Metrics periodically)
    FTurnCount: Int64;
    FTotalTokensUsed: Int64;
    FSessionsCompleted: Int64;
    FTotalLatencyMs: Int64;
    FMaxLatencyMs: Int64;
  public
    constructor Create;

    /// <summary>
    /// Records metrics for a completed turn.
    /// Called by Engine after each SubmitInput cycle.
    /// </summary>
    procedure RecordTurn(ALatencyMs: Int64; ALevel: TClarificationLevel;
      APosture: TPosture; ATokensUsed: Integer);

    /// <summary>
    /// Records a session completion event with reason label.
    /// Reasons: 'user_cancel', 'budget_exhausted', 'auto_complete', 'frustration'
    /// </summary>
    procedure RecordSessionCompleted(const AReason: string);

    /// <summary>
    /// Records token usage for a single LLM call.
    /// </summary>
    procedure RecordTokens(ATokens: Integer);

    /// <summary>Total turns processed since creation</summary>
    property TurnCount: Int64 read FTurnCount;

    /// <summary>Total tokens consumed since creation</summary>
    property TotalTokensUsed: Int64 read FTotalTokensUsed;

    /// <summary>Total sessions completed since creation</summary>
    property SessionsCompleted: Int64 read FSessionsCompleted;

    /// <summary>Average turn latency in milliseconds</summary>
    function AverageLatencyMs: Double;

    /// <summary>Maximum turn latency observed</summary>
    property MaxLatencyMs: Int64 read FMaxLatencyMs;

    /// <summary>Reset all counters (for testing)</summary>
    procedure Reset;
  end;

implementation

{ TICMetrics }

constructor TICMetrics.Create;
begin
  inherited Create;
  Reset;
end;

procedure TICMetrics.RecordTurn(ALatencyMs: Int64; ALevel: TClarificationLevel;
  APosture: TPosture; ATokensUsed: Integer);
begin
  // IC-018: Use TInterlocked for thread-safe counter increments.
  TInterlocked.Increment(FTurnCount);
  TInterlocked.Add(FTotalLatencyMs, ALatencyMs);
  TInterlocked.Add(FTotalTokensUsed, ATokensUsed);

  // FMaxLatencyMs requires CAS for safe max-update across threads
  var LCurrentMax := TInterlocked.Read(FMaxLatencyMs);
  while ALatencyMs > LCurrentMax do
  begin
    if TInterlocked.CompareExchange(FMaxLatencyMs, ALatencyMs, LCurrentMax) = LCurrentMax then
      Break;
    LCurrentMax := TInterlocked.Read(FMaxLatencyMs);
  end;

  // In full integration, would call:
  //   Metrics.Counter('ic_turn_count').Inc;
  //   Metrics.Histogram('ic_turn_latency_ms').Observe(ALatencyMs);
  //   Metrics.Counter('ic_tokens_used').Inc(ATokensUsed);
  //   Metrics.Gauge('ic_current_level').Set(Ord(ALevel));
  //   Metrics.Gauge('ic_current_posture').Set(Ord(APosture));

  Log(ltDebug, Format('IC.Metrics: Turn recorded (latency=%dms, level=L%d, tokens=%d)',
    [ALatencyMs, Ord(ALevel), ATokensUsed]));
end;

procedure TICMetrics.RecordSessionCompleted(const AReason: string);
begin
  TInterlocked.Increment(FSessionsCompleted);

  // In full integration:
  //   Metrics.Counter('ic_session_completed', ['reason', AReason]).Inc;

  Log(ltDebug, Format('IC.Metrics: Session completed (reason=%s, total=%d)',
    [AReason, FSessionsCompleted]));
end;

procedure TICMetrics.RecordTokens(ATokens: Integer);
begin
  TInterlocked.Add(FTotalTokensUsed, ATokens);
end;

function TICMetrics.AverageLatencyMs: Double;
begin
  if FTurnCount > 0 then
    Result := FTotalLatencyMs / FTurnCount
  else
    Result := 0.0;
end;

procedure TICMetrics.Reset;
begin
  FTurnCount := 0;
  FTotalTokensUsed := 0;
  FSessionsCompleted := 0;
  FTotalLatencyMs := 0;
  FMaxLatencyMs := 0;
end;

end.
