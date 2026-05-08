{ ============================================================================
  DeepBase.Resilience - compatibility facade for resilience policies

  Implementations are split by strategy type:
  - DeepBase.Resilience.CircuitBreaker
  - DeepBase.Resilience.Retry
  - DeepBase.Resilience.Timeout
  - DeepBase.Resilience.Fallback
  - DeepBase.Resilience.Bulkhead
  - DeepBase.Resilience.Policy
  ============================================================================ }

unit DeepBase.Resilience;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Threading,
  System.Generics.Collections,
  System.SyncObjs,
  DeepBase.Exceptions,
  DeepBase.Resilience.CircuitBreaker,
  DeepBase.Resilience.Retry,
  DeepBase.Resilience.Timeout,
  DeepBase.Resilience.Fallback,
  DeepBase.Resilience.Bulkhead,
  DeepBase.Resilience.Policy;

type
  TCircuitState = DeepBase.Resilience.CircuitBreaker.TCircuitState;

  TCircuitStateHelper = record helper for TCircuitState
    function ToString: string;
  end;

  TOnCircuitStateChanged = DeepBase.Resilience.CircuitBreaker.TOnCircuitStateChanged;
  TOnCircuitRejected = DeepBase.Resilience.CircuitBreaker.TOnCircuitRejected;

  TCircuitBreaker = class(DeepBase.Resilience.CircuitBreaker.TCircuitBreaker)
  public
    constructor Create(const AName: string = 'default');

    function FailureThreshold(Value: Integer): TCircuitBreaker; reintroduce;
    function SuccessThreshold(Value: Integer): TCircuitBreaker; reintroduce;
    function OpenDuration(Ms: Int64): TCircuitBreaker; reintroduce;
    function OnStateChanged(Handler: TOnCircuitStateChanged): TCircuitBreaker; reintroduce;
    function OnRejected(Handler: TOnCircuitRejected): TCircuitBreaker; reintroduce;

    procedure Execute(Proc: TProc); reintroduce; overload;
    procedure Execute(Proc: TProc; TimeoutMs: Int64); reintroduce; overload;
    function Execute<T>(Func: TFunc<T>): T; reintroduce; overload;
    function Execute<T>(Func: TFunc<T>; TimeoutMs: Int64): T; reintroduce; overload;
  end;

  TCircuitBreakerRegistry = class
  private
    FBreakers: TDictionary<string, TCircuitBreaker>;
    FLock: TCriticalSection;
  public
    constructor Create;
    destructor Destroy; override;

    function GetOrCreate(const Name: string): TCircuitBreaker;
    function TryGet(const Name: string; out Breaker: TCircuitBreaker): Boolean;
    procedure Remove(const Name: string);
    procedure Clear;

    class function Instance: TCircuitBreakerRegistry;
    class procedure ReleaseInstance;
  end;

  TRetryStrategy = DeepBase.Resilience.Retry.TRetryStrategy;
  TRetryMainThreadWaitMode = DeepBase.Resilience.Retry.TRetryMainThreadWaitMode;
  TOnRetry = DeepBase.Resilience.Retry.TOnRetry;
  TOnRetryWait = DeepBase.Resilience.Retry.TOnRetryWait;
  TOnRetryMainThreadWait = DeepBase.Resilience.Retry.TOnRetryMainThreadWait;
  ERetryMainThreadWaitException = DeepBase.Resilience.Retry.ERetryMainThreadWaitException;

  TRetryPolicy = class(DeepBase.Resilience.Retry.TRetryPolicy)
  public
    constructor Create;

    function MaxRetries(Value: Integer): TRetryPolicy; reintroduce;
    function FixedDelay(Ms: Int64): TRetryPolicy; reintroduce;
    function LinearBackoff(BaseMs: Int64; MaxMs: Int64 = 30000): TRetryPolicy; reintroduce;
    function ExponentialBackoff(BaseMs: Int64; Multiplier: Double = 2.0;
      MaxMs: Int64 = 30000): TRetryPolicy; reintroduce;
    function WithJitter(Factor: Double = 0.2): TRetryPolicy; reintroduce;
    function Handle<T: Exception>: TRetryPolicy; reintroduce;
    function HandleAll: TRetryPolicy; reintroduce;
    function OnRetryEvent(Handler: TOnRetry): TRetryPolicy; reintroduce;
    function OnWaitEvent(Handler: TOnRetryWait): TRetryPolicy; reintroduce;
    function MainThreadWaitMode(Mode: TRetryMainThreadWaitMode): TRetryPolicy; reintroduce;
    function OnMainThreadWaitEvent(Handler: TOnRetryMainThreadWait): TRetryPolicy; reintroduce;

    procedure Execute(Proc: TProc); reintroduce; overload;
    function Execute<T>(Func: TFunc<T>): T; reintroduce; overload;
    function ExecuteAsync(Proc: TProc): ITask; reintroduce; overload;
    function ExecuteAsync<T>(Func: TFunc<T>): IFuture<T>; reintroduce; overload;
    function TryExecute(Proc: TProc; out Error: Exception): Boolean; reintroduce;
  end;

  ETimeoutException = DeepBase.Resilience.Timeout.ETimeoutException;
  TOnTimeout = DeepBase.Resilience.Timeout.TOnTimeout;

  TTimeoutPolicy = class(DeepBase.Resilience.Timeout.TTimeoutPolicy)
  public
    constructor Create(ATimeoutMs: Int64 = 5000);

    function Timeout(Ms: Int64): TTimeoutPolicy; reintroduce;
    function OnTimeoutEvent(Handler: TOnTimeout): TTimeoutPolicy; reintroduce;

    procedure Execute(Proc: TProc); reintroduce; overload;
    function Execute<T>(Func: TFunc<T>): T; reintroduce; overload;
  end;

  TFallbackPolicy<T> = class(DeepBase.Resilience.Fallback.TFallbackPolicy<T>)
  public
    constructor Create;

    function Value(AValue: T): TFallbackPolicy<T>; reintroduce;
    function ValueFunc(AFunc: TFunc<Exception, T>): TFallbackPolicy<T>; reintroduce;
    function Handle<E: Exception>: TFallbackPolicy<T>; reintroduce;
    function HandleAll: TFallbackPolicy<T>; reintroduce;
    function Execute(Func: TFunc<T>): T; reintroduce;
  end;

  EBulkheadRejectedException = DeepBase.Resilience.Bulkhead.EBulkheadRejectedException;

  TBulkheadPolicy = class(DeepBase.Resilience.Bulkhead.TBulkheadPolicy)
  public
    constructor Create(AMaxConcurrency: Integer; AMaxQueue: Integer = 0);

    function MaxQueue(Value: Integer): TBulkheadPolicy; reintroduce;
    function QueueTimeout(Ms: Int64): TBulkheadPolicy; reintroduce;

    procedure Execute(Proc: TProc); reintroduce; overload;
    function Execute<T>(Func: TFunc<T>): T; reintroduce; overload;
    function TryExecute(Proc: TProc): Boolean; reintroduce;
  end;

  TResiliencePolicy = class(DeepBase.Resilience.Policy.TResiliencePolicy)
  public
    constructor Create;

    function WithRetry(Policy: TRetryPolicy; OwnsPolicy: Boolean = True): TResiliencePolicy; reintroduce;
    function WithTimeout(Policy: TTimeoutPolicy; OwnsPolicy: Boolean = True): TResiliencePolicy; reintroduce; overload;
    function WithTimeout(Ms: Int64): TResiliencePolicy; reintroduce; overload;
    function WithCircuitBreaker(Breaker: TCircuitBreaker;
      OwnsBreaker: Boolean = False): TResiliencePolicy; reintroduce;
    function WithBulkhead(Policy: TBulkheadPolicy;
      OwnsPolicy: Boolean = True): TResiliencePolicy; reintroduce; overload;
    function WithBulkhead(MaxConcurrency: Integer): TResiliencePolicy; reintroduce; overload;

    procedure Execute(Proc: TProc); reintroduce; overload;
    function Execute<T>(Func: TFunc<T>): T; reintroduce; overload;
  end;

const
  csClosed: TCircuitState = DeepBase.Resilience.CircuitBreaker.csClosed;
  csOpen: TCircuitState = DeepBase.Resilience.CircuitBreaker.csOpen;
  csHalfOpen: TCircuitState = DeepBase.Resilience.CircuitBreaker.csHalfOpen;

  rsFixed: TRetryStrategy = DeepBase.Resilience.Retry.rsFixed;
  rsLinear: TRetryStrategy = DeepBase.Resilience.Retry.rsLinear;
  rsExponential: TRetryStrategy = DeepBase.Resilience.Retry.rsExponential;
  rsJitter: TRetryStrategy = DeepBase.Resilience.Retry.rsJitter;

  rmwAllow: TRetryMainThreadWaitMode = DeepBase.Resilience.Retry.rmwAllow;
  rmwWarn: TRetryMainThreadWaitMode = DeepBase.Resilience.Retry.rmwWarn;
  rmwRaise: TRetryMainThreadWaitMode = DeepBase.Resilience.Retry.rmwRaise;

function CircuitBreakers: TCircuitBreakerRegistry;

implementation

var
  _CircuitBreakerRegistry: TCircuitBreakerRegistry;
  _RegistryLock: TCriticalSection;

function CircuitBreakers: TCircuitBreakerRegistry;
begin
  if not Assigned(_RegistryLock) then
    raise ECircuitBreakerNotInitializedException.Create(
      'CircuitBreakers registry lock not initialized');

  if not Assigned(_CircuitBreakerRegistry) then
  begin
    _RegistryLock.Enter;
    try
      if not Assigned(_CircuitBreakerRegistry) then
        _CircuitBreakerRegistry := TCircuitBreakerRegistry.Create;
    finally
      _RegistryLock.Leave;
    end;
  end;
  Result := _CircuitBreakerRegistry;
end;

function TCircuitStateHelper.ToString: string;
const
  Names: array[TCircuitState] of string = ('Closed', 'Open', 'HalfOpen');
begin
  Result := Names[Self];
end;

constructor TCircuitBreaker.Create(const AName: string);
begin
  inherited Create(AName);
end;

function TCircuitBreaker.FailureThreshold(Value: Integer): TCircuitBreaker;
begin
  inherited FailureThreshold(Value);
  Result := Self;
end;

function TCircuitBreaker.SuccessThreshold(Value: Integer): TCircuitBreaker;
begin
  inherited SuccessThreshold(Value);
  Result := Self;
end;

function TCircuitBreaker.OpenDuration(Ms: Int64): TCircuitBreaker;
begin
  inherited OpenDuration(Ms);
  Result := Self;
end;

function TCircuitBreaker.OnStateChanged(
  Handler: TOnCircuitStateChanged): TCircuitBreaker;
begin
  inherited OnStateChanged(Handler);
  Result := Self;
end;

function TCircuitBreaker.OnRejected(
  Handler: TOnCircuitRejected): TCircuitBreaker;
begin
  inherited OnRejected(Handler);
  Result := Self;
end;

procedure TCircuitBreaker.Execute(Proc: TProc);
begin
  inherited Execute(Proc);
end;

procedure TCircuitBreaker.Execute(Proc: TProc; TimeoutMs: Int64);
begin
  inherited Execute(Proc, TimeoutMs);
end;

function TCircuitBreaker.Execute<T>(Func: TFunc<T>): T;
begin
  Result := inherited Execute<T>(Func);
end;

function TCircuitBreaker.Execute<T>(Func: TFunc<T>; TimeoutMs: Int64): T;
begin
  Result := inherited Execute<T>(Func, TimeoutMs);
end;

constructor TCircuitBreakerRegistry.Create;
begin
  inherited Create;
  FBreakers := TDictionary<string, TCircuitBreaker>.Create;
  FLock := TCriticalSection.Create;
end;

destructor TCircuitBreakerRegistry.Destroy;
var
  Pair: TPair<string, TCircuitBreaker>;
begin
  for Pair in FBreakers do
    Pair.Value.Free;
  FreeAndNil(FBreakers);
  FreeAndNil(FLock);
  inherited;
end;

function TCircuitBreakerRegistry.GetOrCreate(
  const Name: string): TCircuitBreaker;
begin
  FLock.Enter;
  try
    if not FBreakers.TryGetValue(Name, Result) then
    begin
      Result := TCircuitBreaker.Create(Name);
      FBreakers.Add(Name, Result);
    end;
  finally
    FLock.Leave;
  end;
end;

function TCircuitBreakerRegistry.TryGet(const Name: string;
  out Breaker: TCircuitBreaker): Boolean;
begin
  FLock.Enter;
  try
    Result := FBreakers.TryGetValue(Name, Breaker);
  finally
    FLock.Leave;
  end;
end;

procedure TCircuitBreakerRegistry.Remove(const Name: string);
var
  Breaker: TCircuitBreaker;
begin
  FLock.Enter;
  try
    if FBreakers.TryGetValue(Name, Breaker) then
    begin
      FBreakers.Remove(Name);
      Breaker.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TCircuitBreakerRegistry.Clear;
var
  Pair: TPair<string, TCircuitBreaker>;
begin
  FLock.Enter;
  try
    for Pair in FBreakers do
      Pair.Value.Free;
    FBreakers.Clear;
  finally
    FLock.Leave;
  end;
end;

class function TCircuitBreakerRegistry.Instance: TCircuitBreakerRegistry;
begin
  Result := CircuitBreakers;
end;

class procedure TCircuitBreakerRegistry.ReleaseInstance;
begin
  _RegistryLock.Enter;
  try
    FreeAndNil(_CircuitBreakerRegistry);
  finally
    _RegistryLock.Leave;
  end;
end;

constructor TRetryPolicy.Create;
begin
  inherited Create;
end;

function TRetryPolicy.MaxRetries(Value: Integer): TRetryPolicy;
begin
  inherited MaxRetries(Value);
  Result := Self;
end;

function TRetryPolicy.FixedDelay(Ms: Int64): TRetryPolicy;
begin
  inherited FixedDelay(Ms);
  Result := Self;
end;

function TRetryPolicy.LinearBackoff(BaseMs, MaxMs: Int64): TRetryPolicy;
begin
  inherited LinearBackoff(BaseMs, MaxMs);
  Result := Self;
end;

function TRetryPolicy.ExponentialBackoff(BaseMs: Int64; Multiplier: Double;
  MaxMs: Int64): TRetryPolicy;
begin
  inherited ExponentialBackoff(BaseMs, Multiplier, MaxMs);
  Result := Self;
end;

function TRetryPolicy.WithJitter(Factor: Double): TRetryPolicy;
begin
  inherited WithJitter(Factor);
  Result := Self;
end;

function TRetryPolicy.Handle<T>: TRetryPolicy;
begin
  inherited Handle<T>;
  Result := Self;
end;

function TRetryPolicy.HandleAll: TRetryPolicy;
begin
  inherited HandleAll;
  Result := Self;
end;

function TRetryPolicy.OnRetryEvent(Handler: TOnRetry): TRetryPolicy;
begin
  inherited OnRetryEvent(Handler);
  Result := Self;
end;

function TRetryPolicy.OnWaitEvent(Handler: TOnRetryWait): TRetryPolicy;
begin
  inherited OnWaitEvent(Handler);
  Result := Self;
end;

function TRetryPolicy.MainThreadWaitMode(
  Mode: TRetryMainThreadWaitMode): TRetryPolicy;
begin
  inherited MainThreadWaitMode(Mode);
  Result := Self;
end;

function TRetryPolicy.OnMainThreadWaitEvent(
  Handler: TOnRetryMainThreadWait): TRetryPolicy;
begin
  inherited OnMainThreadWaitEvent(Handler);
  Result := Self;
end;

procedure TRetryPolicy.Execute(Proc: TProc);
begin
  inherited Execute(Proc);
end;

function TRetryPolicy.Execute<T>(Func: TFunc<T>): T;
begin
  Result := inherited Execute<T>(Func);
end;

function TRetryPolicy.ExecuteAsync(Proc: TProc): ITask;
begin
  Result := inherited ExecuteAsync(Proc);
end;

function TRetryPolicy.ExecuteAsync<T>(Func: TFunc<T>): IFuture<T>;
begin
  Result := inherited ExecuteAsync<T>(Func);
end;

function TRetryPolicy.TryExecute(Proc: TProc; out Error: Exception): Boolean;
begin
  Result := inherited TryExecute(Proc, Error);
end;

constructor TTimeoutPolicy.Create(ATimeoutMs: Int64);
begin
  inherited Create(ATimeoutMs);
end;

function TTimeoutPolicy.Timeout(Ms: Int64): TTimeoutPolicy;
begin
  inherited Timeout(Ms);
  Result := Self;
end;

function TTimeoutPolicy.OnTimeoutEvent(
  Handler: TOnTimeout): TTimeoutPolicy;
begin
  inherited OnTimeoutEvent(Handler);
  Result := Self;
end;

procedure TTimeoutPolicy.Execute(Proc: TProc);
begin
  inherited Execute(Proc);
end;

function TTimeoutPolicy.Execute<T>(Func: TFunc<T>): T;
begin
  Result := inherited Execute<T>(Func);
end;

constructor TFallbackPolicy<T>.Create;
begin
  inherited Create;
end;

function TFallbackPolicy<T>.Value(AValue: T): TFallbackPolicy<T>;
begin
  inherited Value(AValue);
  Result := Self;
end;

function TFallbackPolicy<T>.ValueFunc(
  AFunc: TFunc<Exception, T>): TFallbackPolicy<T>;
begin
  inherited ValueFunc(AFunc);
  Result := Self;
end;

function TFallbackPolicy<T>.Handle<E>: TFallbackPolicy<T>;
begin
  inherited Handle<E>;
  Result := Self;
end;

function TFallbackPolicy<T>.HandleAll: TFallbackPolicy<T>;
begin
  inherited HandleAll;
  Result := Self;
end;

function TFallbackPolicy<T>.Execute(Func: TFunc<T>): T;
begin
  Result := inherited Execute(Func);
end;

constructor TBulkheadPolicy.Create(AMaxConcurrency, AMaxQueue: Integer);
begin
  inherited Create(AMaxConcurrency, AMaxQueue);
end;

function TBulkheadPolicy.MaxQueue(Value: Integer): TBulkheadPolicy;
begin
  inherited MaxQueue(Value);
  Result := Self;
end;

function TBulkheadPolicy.QueueTimeout(Ms: Int64): TBulkheadPolicy;
begin
  inherited QueueTimeout(Ms);
  Result := Self;
end;

procedure TBulkheadPolicy.Execute(Proc: TProc);
begin
  inherited Execute(Proc);
end;

function TBulkheadPolicy.Execute<T>(Func: TFunc<T>): T;
begin
  Result := inherited Execute<T>(Func);
end;

function TBulkheadPolicy.TryExecute(Proc: TProc): Boolean;
begin
  Result := inherited TryExecute(Proc);
end;

constructor TResiliencePolicy.Create;
begin
  inherited Create;
end;

function TResiliencePolicy.WithRetry(Policy: TRetryPolicy;
  OwnsPolicy: Boolean): TResiliencePolicy;
begin
  inherited WithRetry(Policy, OwnsPolicy);
  Result := Self;
end;

function TResiliencePolicy.WithTimeout(Policy: TTimeoutPolicy;
  OwnsPolicy: Boolean): TResiliencePolicy;
begin
  inherited WithTimeout(Policy, OwnsPolicy);
  Result := Self;
end;

function TResiliencePolicy.WithTimeout(Ms: Int64): TResiliencePolicy;
begin
  inherited WithTimeout(Ms);
  Result := Self;
end;

function TResiliencePolicy.WithCircuitBreaker(Breaker: TCircuitBreaker;
  OwnsBreaker: Boolean): TResiliencePolicy;
begin
  inherited WithCircuitBreaker(Breaker, OwnsBreaker);
  Result := Self;
end;

function TResiliencePolicy.WithBulkhead(Policy: TBulkheadPolicy;
  OwnsPolicy: Boolean): TResiliencePolicy;
begin
  inherited WithBulkhead(Policy, OwnsPolicy);
  Result := Self;
end;

function TResiliencePolicy.WithBulkhead(
  MaxConcurrency: Integer): TResiliencePolicy;
begin
  inherited WithBulkhead(MaxConcurrency);
  Result := Self;
end;

procedure TResiliencePolicy.Execute(Proc: TProc);
begin
  inherited Execute(Proc);
end;

function TResiliencePolicy.Execute<T>(Func: TFunc<T>): T;
begin
  Result := inherited Execute<T>(Func);
end;

initialization
  _RegistryLock := TCriticalSection.Create;

finalization
  FreeAndNil(_CircuitBreakerRegistry);
  FreeAndNil(_RegistryLock);

end.
