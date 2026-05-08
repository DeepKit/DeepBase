{ ============================================================================
  DeepBase.Resilience.Retry - Retry resilience policy
  Split from DeepBase.Resilience; use DeepBase.Resilience for compatibility.
  ============================================================================ }

unit DeepBase.Resilience.Retry;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Threading,
  DeepBase.Constants,
  DeepBase.Exceptions;

type
  // ============================================================================
  // Retry Strategy
  // ============================================================================
  
  TRetryStrategy = (rsFixed, rsLinear, rsExponential, rsJitter);
  TRetryMainThreadWaitMode = (rmwAllow, rmwWarn, rmwRaise);
  
  TOnRetry = reference to procedure(RetryCount: Integer; E: Exception;
    var ShouldRetry: Boolean);
  TOnRetryWait = reference to procedure(RetryCount: Integer; WaitMs: Int64);
  TOnRetryMainThreadWait = reference to procedure(RetryCount: Integer;
    WaitMs: Int64; var Mode: TRetryMainThreadWaitMode);

  ERetryMainThreadWaitException = class(EDeepBaseException)
  private
    FRetryCount: Integer;
    FWaitMs: Int64;
  public
    constructor Create(ARetryCount: Integer; AWaitMs: Int64);
    property RetryCount: Integer read FRetryCount;
    property WaitMs: Int64 read FWaitMs;
  end;
  
  // ============================================================================
  // Retry Policy
  // ============================================================================
  
  /// <summary>
  /// Retry policy with configurable strategies
  /// </summary>
  TRetryPolicy = class
  private
    FMaxRetries: Integer;
    FStrategy: TRetryStrategy;
    FBaseDelayMs: Int64;
    FMaxDelayMs: Int64;
    FMultiplier: Double;
    FJitterFactor: Double;
    FHandledExceptions: TList<TClass>;
    FOnRetry: TOnRetry;
    FOnWait: TOnRetryWait;
    FOnMainThreadWait: TOnRetryMainThreadWait;
    FMainThreadWaitMode: TRetryMainThreadWaitMode;
    
    function CalculateDelay(RetryCount: Integer): Int64;
    function ShouldHandle(E: Exception): Boolean;
    function IsMainThreadWait(DelayMs: Int64): Boolean;
    procedure WaitBeforeRetry(RetryCount: Integer; DelayMs: Int64);
  public
    constructor Create;
    destructor Destroy; override;
    
    // Configuration (fluent)
    function MaxRetries(Value: Integer): TRetryPolicy;
    function FixedDelay(Ms: Int64): TRetryPolicy;
    function LinearBackoff(BaseMs: Int64; MaxMs: Int64 = 30000): TRetryPolicy;
    function ExponentialBackoff(BaseMs: Int64; Multiplier: Double = 2.0;
      MaxMs: Int64 = 30000): TRetryPolicy;
    function WithJitter(Factor: Double = 0.2): TRetryPolicy;
    function Handle<T: Exception>: TRetryPolicy;
    function HandleAll: TRetryPolicy;
    function OnRetryEvent(Handler: TOnRetry): TRetryPolicy;
    function OnWaitEvent(Handler: TOnRetryWait): TRetryPolicy;
    function MainThreadWaitMode(Mode: TRetryMainThreadWaitMode): TRetryPolicy;
    function OnMainThreadWaitEvent(Handler: TOnRetryMainThreadWait): TRetryPolicy;
    
    // Execute
    procedure Execute(Proc: TProc); overload;
    function Execute<T>(Func: TFunc<T>): T; overload;
    function ExecuteAsync(Proc: TProc): ITask; overload;
    function ExecuteAsync<T>(Func: TFunc<T>): IFuture<T>; overload;
    function TryExecute(Proc: TProc; out Error: Exception): Boolean;
  end;

implementation

uses
  System.Math;

constructor ERetryMainThreadWaitException.Create(ARetryCount: Integer;
  AWaitMs: Int64);
begin
  inherited CreateFmt(
    'Retry delay of %d ms on main thread before retry #%d is not allowed',
    [AWaitMs, ARetryCount]);
  FRetryCount := ARetryCount;
  FWaitMs := AWaitMs;
end;

// ============================================================================
// TRetryPolicy
// ============================================================================

constructor TRetryPolicy.Create;
begin
  inherited Create;
  FMaxRetries := DEFAULT_MAX_RETRIES;
  FStrategy := rsFixed;
  FBaseDelayMs := DEFAULT_RETRY_DELAY_MS;
  FMaxDelayMs := DEFAULT_KEEP_ALIVE_TIMEOUT_MS;
  FMultiplier := 2.0;
  FJitterFactor := 0;
  FHandledExceptions := TList<TClass>.Create;
  FMainThreadWaitMode := rmwWarn;
end;

destructor TRetryPolicy.Destroy;
begin
  FreeAndNil(FHandledExceptions);
  inherited;
end;

function TRetryPolicy.MaxRetries(Value: Integer): TRetryPolicy;
begin
  FMaxRetries := Value;
  Result := Self;
end;

function TRetryPolicy.FixedDelay(Ms: Int64): TRetryPolicy;
begin
  FStrategy := rsFixed;
  FBaseDelayMs := Ms;
  Result := Self;
end;

function TRetryPolicy.LinearBackoff(BaseMs: Int64; MaxMs: Int64): TRetryPolicy;
begin
  FStrategy := rsLinear;
  FBaseDelayMs := BaseMs;
  FMaxDelayMs := MaxMs;
  Result := Self;
end;

function TRetryPolicy.ExponentialBackoff(BaseMs: Int64; Multiplier: Double;
  MaxMs: Int64): TRetryPolicy;
begin
  FStrategy := rsExponential;
  FBaseDelayMs := BaseMs;
  FMultiplier := Multiplier;
  FMaxDelayMs := MaxMs;
  Result := Self;
end;

function TRetryPolicy.WithJitter(Factor: Double): TRetryPolicy;
begin
  FJitterFactor := Factor;
  Result := Self;
end;

function TRetryPolicy.Handle<T>: TRetryPolicy;
begin
  FHandledExceptions.Add(T);
  Result := Self;
end;

function TRetryPolicy.HandleAll: TRetryPolicy;
begin
  FHandledExceptions.Clear;
  FHandledExceptions.Add(Exception);
  Result := Self;
end;

function TRetryPolicy.OnRetryEvent(Handler: TOnRetry): TRetryPolicy;
begin
  FOnRetry := Handler;
  Result := Self;
end;

function TRetryPolicy.OnWaitEvent(Handler: TOnRetryWait): TRetryPolicy;
begin
  FOnWait := Handler;
  Result := Self;
end;

function TRetryPolicy.MainThreadWaitMode(
  Mode: TRetryMainThreadWaitMode): TRetryPolicy;
begin
  FMainThreadWaitMode := Mode;
  Result := Self;
end;

function TRetryPolicy.OnMainThreadWaitEvent(
  Handler: TOnRetryMainThreadWait): TRetryPolicy;
begin
  FOnMainThreadWait := Handler;
  Result := Self;
end;

function TRetryPolicy.CalculateDelay(RetryCount: Integer): Int64;
var
  Delay: Double;
  JitterRange: Double;
begin
  case FStrategy of
    rsFixed:
      Delay := FBaseDelayMs;
    rsLinear:
      Delay := FBaseDelayMs * RetryCount;
    rsExponential:
      Delay := FBaseDelayMs * Power(FMultiplier, RetryCount - 1);
  else
    Delay := FBaseDelayMs;
  end;
  
  // Apply jitter - BUG-106 FIX: 使用更安全的随机数生�?
  // 注意：对于安全敏感场景，应使用TRandomGenerator.RandomBytes
  if FJitterFactor > 0 then
  begin
    JitterRange := Delay * FJitterFactor;
    // Random() 对于重试延迟的抖动是可接受的，因为这不是安全敏感场景
    Delay := Delay + (Random * 2 - 1) * JitterRange;
  end;
  
  // Cap at max
  if Delay > FMaxDelayMs then
    Delay := FMaxDelayMs;
  if Delay < 0 then
    Delay := 0;
  
  Result := Round(Delay);
end;

function TRetryPolicy.ShouldHandle(E: Exception): Boolean;
var
  ExClass: TClass;
begin
  if FHandledExceptions.Count = 0 then
    Exit(True);
  
  for ExClass in FHandledExceptions do
  begin
    if E is ExClass then
      Exit(True);
  end;
  
  Result := False;
end;

function TRetryPolicy.IsMainThreadWait(DelayMs: Int64): Boolean;
begin
  Result := (DelayMs > 0) and
    (TThread.CurrentThread.ThreadID = MainThreadID);
end;

procedure TRetryPolicy.WaitBeforeRetry(RetryCount: Integer; DelayMs: Int64);
var
  Mode: TRetryMainThreadWaitMode;
begin
  if DelayMs <= 0 then
    Exit;

  if IsMainThreadWait(DelayMs) then
  begin
    Mode := FMainThreadWaitMode;
    if Mode <> rmwAllow then
    begin
      if Assigned(FOnMainThreadWait) then
        FOnMainThreadWait(RetryCount, DelayMs, Mode);
      if Mode = rmwRaise then
        raise ERetryMainThreadWaitException.Create(RetryCount, DelayMs);
    end;
  end;

  if Assigned(FOnWait) then
    FOnWait(RetryCount, DelayMs);

  Sleep(DelayMs);
end;

procedure TRetryPolicy.Execute(Proc: TProc);
var
  RetryCount: Integer;
  LastException: Exception;
  Delay: Int64;
  ShouldRetry: Boolean;
begin
  RetryCount := 0;
  LastException := nil;
  
  while True do
  begin
    try
      Proc;
      Exit;
    except
      on E: Exception do
      begin
        if not ShouldHandle(E) then
          raise;
        
        Inc(RetryCount);
        
        if RetryCount > FMaxRetries then
          raise;
        
        ShouldRetry := True;
        if Assigned(FOnRetry) then
          FOnRetry(RetryCount, E, ShouldRetry);
        
        if not ShouldRetry then
          raise;
        
        Delay := CalculateDelay(RetryCount);
        WaitBeforeRetry(RetryCount, Delay);
      end;
    end;
  end;
end;

function TRetryPolicy.Execute<T>(Func: TFunc<T>): T;
var
  RetryCount: Integer;
  Delay: Int64;
  ShouldRetry: Boolean;
begin
  RetryCount := 0;
  
  while True do
  begin
    try
      Exit(Func);
    except
      on E: Exception do
      begin
        if not ShouldHandle(E) then
          raise;
        
        Inc(RetryCount);
        
        if RetryCount > FMaxRetries then
          raise;
        
        ShouldRetry := True;
        if Assigned(FOnRetry) then
          FOnRetry(RetryCount, E, ShouldRetry);
        
        if not ShouldRetry then
          raise;
        
        Delay := CalculateDelay(RetryCount);
        WaitBeforeRetry(RetryCount, Delay);
      end;
    end;
  end;
end;

function TRetryPolicy.ExecuteAsync(Proc: TProc): ITask;
var
  LProc: TProc;
begin
  LProc := Proc;
  Result := TTask.Run(
    procedure
    begin
      Execute(LProc);
    end);
end;

function TRetryPolicy.ExecuteAsync<T>(Func: TFunc<T>): IFuture<T>;
var
  LFunc: TFunc<T>;
begin
  LFunc := Func;
  Result := TTask.Future<T>(
    function: T
    begin
      Result := Execute<T>(LFunc);
    end);
end;

function TRetryPolicy.TryExecute(Proc: TProc; out Error: Exception): Boolean;
begin
  Error := nil;
  try
    Execute(Proc);
    Result := True;
  except
    on E: Exception do
    begin
      Error := E;
      Result := False;
    end;
  end;
end;

initialization
  Randomize;

end.
