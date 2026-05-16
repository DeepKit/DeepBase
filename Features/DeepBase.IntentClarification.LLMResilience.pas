{ ============================================================================
  DeepBase.IntentClarification.LLMResilience - Resilient LLM Wrapper

  Decorator around ILLMClient that adds retry, timeout, and circuit-breaker
  protection for LLM calls used by L2/L3/L4 providers.

  Phase 2 Task 24: Resilience
    - Retry: up to 2 retries (configurable)
    - Timeout: 10s default (configurable)
    - Circuit Breaker: opens after 3 consecutive failures, stays open 30s
    - When circuit is open, immediately returns failure (triggers degradation)

  Requirements: 24.1
  ============================================================================ }

unit DeepBase.IntentClarification.LLMResilience;

interface

uses
  System.SysUtils,
  System.SyncObjs,
  System.DateUtils,
  System.Diagnostics,
  System.Threading,
  DeepBase.LLM.Client,
  DeepBase.LLM.Types,
  DeepBase.Logging,
  DeepBase.IntentClarification.Logging;

type
  /// <summary>Configuration for the resilient LLM wrapper</summary>
  TLLMResilienceConfig = record
    TimeoutMs: Integer;           // Default: 10000 (10s)
    MaxRetries: Integer;          // Default: 2
    CircuitBreakerThreshold: Integer; // Consecutive failures to open circuit. Default: 3
    CircuitBreakerCooldownMs: Integer; // Time circuit stays open. Default: 30000 (30s)

    class function Default: TLLMResilienceConfig; static;
  end;

  /// <summary>Circuit breaker states</summary>
  TCircuitState = (csClosed, csOpen, csHalfOpen);

  /// <summary>
  /// Decorator around ILLMClient that adds resilience policies.
  /// Implements ILLMClient so it can be used as a drop-in replacement.
  ///
  /// Behavior:
  ///   1. If circuit is OPEN and cooldown not elapsed -> immediate failure
  ///   2. If circuit is HALF-OPEN -> allow one request through
  ///   3. Execute with timeout
  ///   4. On failure, retry up to MaxRetries times
  ///   5. Track consecutive failures for circuit breaker
  ///   6. On success, reset failure counter (close circuit if half-open)
  /// </summary>
  TResilientLLMWrapper = class(TInterfacedObject, ILLMClient)
  private
    FInner: ILLMClient;
    FConfig: TLLMResilienceConfig;
    FLock: TCriticalSection;

    // Circuit breaker state
    FCircuitState: TCircuitState;
    FConsecutiveFailures: Integer;
    FLastFailureTime: TDateTime;

    procedure RecordSuccess;
    procedure RecordFailure;
    function IsCircuitOpen: Boolean;
    function ShouldAttemptHalfOpen: Boolean;
    function MakeCircuitOpenResult: TChatResult;
    function MakeFailureResult(const AError: string): TChatResult;
    function ExecuteWithResilience(ACall: TFunc<TChatResult>): TChatResult;

    // Image generation parallel resilience harness (Task 19.10)
    function MakeCircuitOpenImageResult: TImageGenerationResult;
    function MakeFailureImageResult(const AError: string): TImageGenerationResult;
    function ExecuteWithResilienceImage(
      ACall: TFunc<TImageGenerationResult>): TImageGenerationResult;
  public
    constructor Create(const AInner: ILLMClient); overload;
    constructor Create(const AInner: ILLMClient;
      const AConfig: TLLMResilienceConfig); overload;
    destructor Destroy; override;

    // ILLMClient implementation - wraps all Chat methods with resilience
    function Chat(const ATier: TModelTier; const AUserPrompt: string): TChatResult; overload;
    function Chat(const ATier: TModelTier; const ASystemPrompt, AUserPrompt: string): TChatResult; overload;
    function ChatWithHistory(const ATier: TModelTier;
      const AMessages: TArray<TChatMessage>;
      AMaxTokens: Integer = 0; ATemperature: Double = -1): TChatResult;
    procedure ChatStream(const ATier: TModelTier;
      const AMessages: TArray<TChatMessage>;
      AOnChunk: TProc<string>; AOnError: TProc<string>;
      AMaxTokens: Integer = 0);
    function ChatVision(const ATier: TModelTier;
      const AImageBase64: string; const AImageMimeType: string;
      const AUserPrompt: string; const ASystemPrompt: string = ''): TChatResult;
    function GenerateImage(const APrompt: string;
      const ASize: string = '1024x1024'): TImageGenerationResult;
    procedure ChatVisionStream(const ATier: TModelTier;
      const AImageBase64: string; const AImageMimeType: string;
      const AUserPrompt: string; const ASystemPrompt: string;
      AOnChunk: TProc<string>; AOnError: TProc<string>;
      AMaxTokens: Integer = 0);
    function GetModelForTier(const ATier: TModelTier): string;
    function CallCount: Integer;
    function LastDurationMs: Integer;

    /// <summary>Current circuit breaker state (for diagnostics)</summary>
    function GetCircuitState: TCircuitState;

    /// <summary>Number of consecutive failures</summary>
    function GetConsecutiveFailures: Integer;

    /// <summary>Reset circuit breaker to closed state</summary>
    procedure ResetCircuit;

    property Config: TLLMResilienceConfig read FConfig write FConfig;
  end;

implementation

{ TLLMResilienceConfig }

class function TLLMResilienceConfig.Default: TLLMResilienceConfig;
begin
  Result.TimeoutMs := 10000;              // 10 seconds
  Result.MaxRetries := 2;                 // 2 retries (3 total attempts)
  Result.CircuitBreakerThreshold := 3;    // Open after 3 consecutive failures
  Result.CircuitBreakerCooldownMs := 30000; // 30 seconds cooldown
end;

{ TResilientLLMWrapper }

constructor TResilientLLMWrapper.Create(const AInner: ILLMClient);
begin
  Create(AInner, TLLMResilienceConfig.Default);
end;

constructor TResilientLLMWrapper.Create(const AInner: ILLMClient;
  const AConfig: TLLMResilienceConfig);
begin
  inherited Create;
  if AInner = nil then
    raise EArgumentNilException.Create('AInner LLM client cannot be nil');
  FInner := AInner;
  FConfig := AConfig;
  FLock := TCriticalSection.Create;
  FCircuitState := csClosed;
  FConsecutiveFailures := 0;
  FLastFailureTime := 0;
  Log(ltDebug, 'IC.Resilience: Wrapper created');
end;

destructor TResilientLLMWrapper.Destroy;
begin
  FLock.Free;
  inherited;
end;

function TResilientLLMWrapper.IsCircuitOpen: Boolean;
begin
  FLock.Enter;
  try
    Result := FCircuitState = csOpen;
  finally
    FLock.Leave;
  end;
end;

function TResilientLLMWrapper.ShouldAttemptHalfOpen: Boolean;
var
  LElapsedMs: Int64;
begin
  FLock.Enter;
  try
    if FCircuitState <> csOpen then
    begin
      Result := False;
      Exit;
    end;

    LElapsedMs := MilliSecondsBetween(Now, FLastFailureTime);
    if LElapsedMs >= FConfig.CircuitBreakerCooldownMs then
    begin
      FCircuitState := csHalfOpen;
      Result := True;
      Log(ltInfo, 'IC.Resilience: Circuit half-open, allowing probe request');
    end
    else
      Result := False;
  finally
    FLock.Leave;
  end;
end;

procedure TResilientLLMWrapper.RecordSuccess;
begin
  FLock.Enter;
  try
    FConsecutiveFailures := 0;
    if FCircuitState = csHalfOpen then
    begin
      FCircuitState := csClosed;
      Log(ltInfo, 'IC.Resilience: Circuit closed after successful probe');
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TResilientLLMWrapper.RecordFailure;
begin
  FLock.Enter;
  try
    Inc(FConsecutiveFailures);
    FLastFailureTime := Now;

    if (FCircuitState = csHalfOpen) or
       (FConsecutiveFailures >= FConfig.CircuitBreakerThreshold) then
    begin
      FCircuitState := csOpen;
      Log(ltWarning, Format('IC.Resilience: Circuit OPEN after %d failures',
        [FConsecutiveFailures]));
    end;
  finally
    FLock.Leave;
  end;
end;

function TResilientLLMWrapper.MakeCircuitOpenResult: TChatResult;
begin
  Result := Default(TChatResult);
  Result.Success := False;
  Result.Content := '';
  Result.FinishReason := 'circuit_open';
end;

function TResilientLLMWrapper.MakeFailureResult(const AError: string): TChatResult;
begin
  Result := Default(TChatResult);
  Result.Success := False;
  Result.Content := '';
  Result.ErrorMessage := AError;
  Result.ErrorCode := 'resilience_failure';
  Result.FinishReason := 'resilience_failure';
end;

function TResilientLLMWrapper.ExecuteWithResilience(
  ACall: TFunc<TChatResult>): TChatResult;
var
  LAttempt: Integer;
  LLastError: string;
  LSW: TStopwatch;
  LTask: ITask;
  LTaskResult: TChatResult;
  LTaskError: string;
  LTimedOut: Boolean;
begin
  // Circuit breaker check
  if IsCircuitOpen then
  begin
    if not ShouldAttemptHalfOpen then
    begin
      Log(ltWarning, 'IC.Resilience: Request rejected (circuit open)');
      Result := MakeCircuitOpenResult;
      Exit;
    end;
  end;

  // Retry loop
  LLastError := '';
  for LAttempt := 0 to FConfig.MaxRetries do
  begin
    try
      LSW := TStopwatch.StartNew;

      // IC-010: Run inner call inside a TTask and wait with timeout so a
      // hung LLM call cannot block the whole engine. Note that Wait()
      // returning False does not synchronously kill the inner call --
      // ONNX/HTTP libraries do not support cancellation tokens here, so the
      // background task may still complete eventually, but we no longer
      // block the caller and we treat it as a failure.
      LTaskResult := Default(TChatResult);
      LTaskError := '';
      LTask := TTask.Run(
        procedure
        begin
          try
            LTaskResult := ACall();
          except
            on E: Exception do
              LTaskError := E.ClassName + ': ' + E.Message;
          end;
        end);

      LTimedOut := not LTask.Wait(FConfig.TimeoutMs);
      LSW.Stop;

      if LTimedOut then
      begin
        Result := Default(TChatResult);
        Result.Success := False;
        LLastError := Format('LLM call timed out after %dms', [FConfig.TimeoutMs]);
        Result.FinishReason := 'timeout';
        Result.ErrorMessage := LLastError;
        Result.ErrorCode := 'timeout';
        Log(ltWarning, Format('IC.Resilience: LLM timeout (attempt %d/%d): %s',
          [LAttempt + 1, FConfig.MaxRetries + 1, LLastError]));
      end
      else if LTaskError <> '' then
      begin
        LLastError := LTaskError;
        Log(ltWarning, Format('IC.Resilience: LLM exception (attempt %d/%d): %s',
          [LAttempt + 1, FConfig.MaxRetries + 1, LTaskError]));
        Result := Default(TChatResult);
        Result.Success := False;
        Result.FinishReason := 'exception';
      end
      else
      begin
        Result := LTaskResult;
        if Result.Success then
        begin
          RecordSuccess;
          Exit;
        end
        else
        begin
          LLastError := Result.FinishReason;
          Log(ltWarning, Format('IC.Resilience: LLM returned error (attempt %d/%d): %s',
            [LAttempt + 1, FConfig.MaxRetries + 1, LLastError]));
        end;
      end;
    except
      on E: Exception do
      begin
        LLastError := E.Message;
        Log(ltWarning, Format('IC.Resilience: Resilience harness exception (attempt %d/%d): %s',
          [LAttempt + 1, FConfig.MaxRetries + 1, E.Message]));
      end;
    end;

    // Brief pause before retry (simple linear backoff)
    if LAttempt < FConfig.MaxRetries then
      Sleep(100 * (LAttempt + 1));
  end;

  // All attempts failed
  RecordFailure;
  Result := MakeFailureResult(LLastError);
  Log(ltError, Format('IC.Resilience: All attempts exhausted: %s', [LLastError]));
end;

// === Image Generation Resilience Harness (Task 19.10) ===
// Mirrors ExecuteWithResilience but operates on TImageGenerationResult.
// Kept as a duplicate harness rather than a generic helper to keep the
// success/error field handling explicit per result type.

function TResilientLLMWrapper.MakeCircuitOpenImageResult: TImageGenerationResult;
begin
  Result := Default(TImageGenerationResult);
  Result.Success := False;
  Result.ErrorCode := 'circuit_open';
  Result.ErrorMessage := 'Circuit breaker is OPEN';
end;

function TResilientLLMWrapper.MakeFailureImageResult(
  const AError: string): TImageGenerationResult;
begin
  Result := Default(TImageGenerationResult);
  Result.Success := False;
  Result.ErrorCode := 'resilience_failure';
  Result.ErrorMessage := AError;
end;

function TResilientLLMWrapper.ExecuteWithResilienceImage(
  ACall: TFunc<TImageGenerationResult>): TImageGenerationResult;
var
  LAttempt: Integer;
  LLastError: string;
  LSW: TStopwatch;
  LTask: ITask;
  LTaskResult: TImageGenerationResult;
  LTaskError: string;
  LTimedOut: Boolean;
begin
  // Circuit breaker check
  if IsCircuitOpen then
  begin
    if not ShouldAttemptHalfOpen then
    begin
      Log(ltWarning, 'IC.Resilience: Image request rejected (circuit open)');
      Result := MakeCircuitOpenImageResult;
      Exit;
    end;
  end;

  LLastError := '';
  for LAttempt := 0 to FConfig.MaxRetries do
  begin
    try
      LSW := TStopwatch.StartNew;

      LTaskResult := Default(TImageGenerationResult);
      LTaskError := '';
      LTask := TTask.Run(
        procedure
        begin
          try
            LTaskResult := ACall();
          except
            on E: Exception do
              LTaskError := E.ClassName + ': ' + E.Message;
          end;
        end);

      LTimedOut := not LTask.Wait(FConfig.TimeoutMs);
      LSW.Stop;

      if LTimedOut then
      begin
        Result := Default(TImageGenerationResult);
        Result.Success := False;
        LLastError := Format('Image call timed out after %dms', [FConfig.TimeoutMs]);
        Result.ErrorCode := 'timeout';
        Result.ErrorMessage := LLastError;
        Log(ltWarning, Format('IC.Resilience: Image timeout (attempt %d/%d): %s',
          [LAttempt + 1, FConfig.MaxRetries + 1, LLastError]));
      end
      else if LTaskError <> '' then
      begin
        LLastError := LTaskError;
        Log(ltWarning, Format('IC.Resilience: Image exception (attempt %d/%d): %s',
          [LAttempt + 1, FConfig.MaxRetries + 1, LTaskError]));
        Result := Default(TImageGenerationResult);
        Result.Success := False;
        Result.ErrorCode := 'exception';
        Result.ErrorMessage := LTaskError;
      end
      else
      begin
        Result := LTaskResult;
        if Result.Success then
        begin
          RecordSuccess;
          Exit;
        end
        else
        begin
          var LErr := if Result.ErrorMessage <> '' then Result.ErrorMessage
                      else Result.ErrorCode;
          LLastError := LErr;
          Log(ltWarning, Format('IC.Resilience: Image returned error (attempt %d/%d): %s',
            [LAttempt + 1, FConfig.MaxRetries + 1, LLastError]));
        end;
      end;
    except
      on E: Exception do
      begin
        LLastError := E.Message;
        Log(ltWarning, Format('IC.Resilience: Image harness exception (attempt %d/%d): %s',
          [LAttempt + 1, FConfig.MaxRetries + 1, E.Message]));
      end;
    end;

    if LAttempt < FConfig.MaxRetries then
      Sleep(100 * (LAttempt + 1));
  end;

  RecordFailure;
  Result := MakeFailureImageResult(LLastError);
  Log(ltError, Format('IC.Resilience: Image attempts exhausted: %s', [LLastError]));
end;

// === ILLMClient Implementation ===

function TResilientLLMWrapper.Chat(const ATier: TModelTier;
  const AUserPrompt: string): TChatResult;
begin
  Result := ExecuteWithResilience(
    function: TChatResult
    begin
      Result := FInner.Chat(ATier, AUserPrompt);
    end);
end;

function TResilientLLMWrapper.Chat(const ATier: TModelTier;
  const ASystemPrompt, AUserPrompt: string): TChatResult;
begin
  Result := ExecuteWithResilience(
    function: TChatResult
    begin
      Result := FInner.Chat(ATier, ASystemPrompt, AUserPrompt);
    end);
end;

function TResilientLLMWrapper.ChatWithHistory(const ATier: TModelTier;
  const AMessages: TArray<TChatMessage>;
  AMaxTokens: Integer; ATemperature: Double): TChatResult;
begin
  Result := ExecuteWithResilience(
    function: TChatResult
    begin
      Result := FInner.ChatWithHistory(ATier, AMessages, AMaxTokens, ATemperature);
    end);
end;

procedure TResilientLLMWrapper.ChatStream(const ATier: TModelTier;
  const AMessages: TArray<TChatMessage>;
  AOnChunk: TProc<string>; AOnError: TProc<string>;
  AMaxTokens: Integer);
begin
  // Streaming calls are passed through directly (resilience is harder for streams)
  // The circuit breaker still applies as a gate
  if IsCircuitOpen and not ShouldAttemptHalfOpen then
  begin
    if Assigned(AOnError) then
      AOnError('Circuit breaker is OPEN');
    Exit;
  end;

  try
    FInner.ChatStream(ATier, AMessages, AOnChunk, AOnError, AMaxTokens);
    RecordSuccess;
  except
    on E: Exception do
    begin
      RecordFailure;
      if Assigned(AOnError) then
        AOnError(E.Message);
    end;
  end;
end;

function TResilientLLMWrapper.ChatVision(const ATier: TModelTier;
  const AImageBase64, AImageMimeType, AUserPrompt: string;
  const ASystemPrompt: string): TChatResult;
begin
  Result := ExecuteWithResilience(
    function: TChatResult
    begin
      Result := FInner.ChatVision(ATier, AImageBase64, AImageMimeType,
        AUserPrompt, ASystemPrompt);
    end);
end;

function TResilientLLMWrapper.GenerateImage(const APrompt: string;
  const ASize: string): TImageGenerationResult;
begin
  // IC-010 / Task 19.10: image generation now goes through the resilience
  // harness (circuit-breaker + retry + timeout). The harness mirrors the
  // TChatResult version but operates on TImageGenerationResult fields.
  Result := ExecuteWithResilienceImage(
    function: TImageGenerationResult
    begin
      Result := FInner.GenerateImage(APrompt, ASize);
    end);
end;

procedure TResilientLLMWrapper.ChatVisionStream(const ATier: TModelTier;
  const AImageBase64, AImageMimeType, AUserPrompt, ASystemPrompt: string;
  AOnChunk: TProc<string>; AOnError: TProc<string>;
  AMaxTokens: Integer);
begin
  if IsCircuitOpen and not ShouldAttemptHalfOpen then
  begin
    if Assigned(AOnError) then
      AOnError('Circuit breaker is OPEN');
    Exit;
  end;

  try
    FInner.ChatVisionStream(ATier, AImageBase64, AImageMimeType,
      AUserPrompt, ASystemPrompt, AOnChunk, AOnError, AMaxTokens);
    RecordSuccess;
  except
    on E: Exception do
    begin
      RecordFailure;
      if Assigned(AOnError) then
        AOnError(E.Message);
    end;
  end;
end;

function TResilientLLMWrapper.GetModelForTier(const ATier: TModelTier): string;
begin
  Result := FInner.GetModelForTier(ATier);
end;

function TResilientLLMWrapper.CallCount: Integer;
begin
  Result := FInner.CallCount;
end;

function TResilientLLMWrapper.LastDurationMs: Integer;
begin
  Result := FInner.LastDurationMs;
end;

// === Diagnostics ===

function TResilientLLMWrapper.GetCircuitState: TCircuitState;
begin
  FLock.Enter;
  try
    Result := FCircuitState;
  finally
    FLock.Leave;
  end;
end;

function TResilientLLMWrapper.GetConsecutiveFailures: Integer;
begin
  FLock.Enter;
  try
    Result := FConsecutiveFailures;
  finally
    FLock.Leave;
  end;
end;

procedure TResilientLLMWrapper.ResetCircuit;
begin
  FLock.Enter;
  try
    FCircuitState := csClosed;
    FConsecutiveFailures := 0;
    FLastFailureTime := 0;
    Log(ltInfo, 'IC.Resilience: Circuit manually reset');
  finally
    FLock.Leave;
  end;
end;

end.
