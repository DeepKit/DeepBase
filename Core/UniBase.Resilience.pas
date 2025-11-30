{ ============================================================================
  UniBase.Resilience - Resilience Patterns Module
  
  Implementation of common resilience patterns for fault tolerance.
  
  Features:
  - Circuit Breaker: Prevent cascading failures
  - Retry Policy: Automatic retry with configurable strategies
  - Timeout: Prevent indefinite waits
  - Fallback: Provide alternative values on failure
  - Bulkhead: Isolate failures (limit concurrent executions)
  - Policy combination: Chain multiple policies together
  
  Usage:
    // Retry with exponential backoff
    var Retry := TRetryPolicy.Create
      .MaxRetries(3)
      .ExponentialBackoff(100, 2.0, 5000)
      .Handle<ENetException>;
    
    Retry.Execute(
      procedure
      begin
        CallRemoteService;
      end);
    
    // Circuit Breaker
    var Breaker := TCircuitBreaker.Create('service1')
      .FailureThreshold(5)
      .SuccessThreshold(2)
      .OpenDuration(30000);
    
    if Breaker.AllowRequest then
    begin
      try
        CallService;
        Breaker.RecordSuccess;
      except
        Breaker.RecordFailure;
        raise;
      end;
    end;
    
    // Combined policy
    var Policy := TResiliencePolicy.Create
      .WithRetry(TRetryPolicy.Create.MaxRetries(3))
      .WithTimeout(5000)
      .WithCircuitBreaker(Breaker)
      .WithFallback<string>('default value');
  ============================================================================ }

unit UniBase.Resilience;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.SyncObjs,
  System.DateUtils,
  System.Diagnostics,
  System.Threading;

type
  // ============================================================================
  // Forward Declarations
  // ============================================================================
  
  TCircuitBreaker = class;
  TRetryPolicy = class;
  TTimeoutPolicy = class;
  TBulkheadPolicy = class;
  
  // ============================================================================
  // Circuit Breaker State
  // ============================================================================
  
  TCircuitState = (csClosed, csOpen, csHalfOpen);
  
  TCircuitStateHelper = record helper for TCircuitState
    function ToString: string;
  end;
  
  // ============================================================================
  // Circuit Breaker Events
  // ============================================================================
  
  TOnCircuitStateChanged = reference to procedure(const Name: string;
    OldState, NewState: TCircuitState);
  TOnCircuitRejected = reference to procedure(const Name: string);
  
  // ============================================================================
  // Circuit Breaker
  // ============================================================================
  
  /// <summary>
  /// Circuit Breaker pattern implementation
  /// Prevents repeated calls to a failing service
  /// </summary>
  TCircuitBreaker = class
  private
    FName: string;
    FState: TCircuitState;
    FFailureCount: Integer;
    FSuccessCount: Integer;
    FFailureThreshold: Integer;
    FSuccessThreshold: Integer;
    FOpenDurationMs: Int64;
    FLastStateChange: TDateTime;
    FLastFailure: TDateTime;
    FLock: TCriticalSection;
    FOnStateChanged: TOnCircuitStateChanged;
    FOnRejected: TOnCircuitRejected;
    
    procedure SetState(NewState: TCircuitState);
    function GetState: TCircuitState;
    procedure CheckHalfOpenTransition;
  public
    constructor Create(const AName: string = 'default');
    destructor Destroy; override;
    
    // Configuration (fluent)
    function FailureThreshold(Value: Integer): TCircuitBreaker;
    function SuccessThreshold(Value: Integer): TCircuitBreaker;
    function OpenDuration(Ms: Int64): TCircuitBreaker;
    function OnStateChanged(Handler: TOnCircuitStateChanged): TCircuitBreaker;
    function OnRejected(Handler: TOnCircuitRejected): TCircuitBreaker;
    
    // Operations
    function AllowRequest: Boolean;
    procedure RecordSuccess;
    procedure RecordFailure;
    procedure Reset;
    
    // Execute with circuit breaker
    procedure Execute(Proc: TProc);
    function Execute<T>(Func: TFunc<T>): T;
    
    // State info
    property Name: string read FName;
    property State: TCircuitState read GetState;
    property FailureCount: Integer read FFailureCount;
    property SuccessCount: Integer read FSuccessCount;
  end;
  
  // ============================================================================
  // Retry Strategy
  // ============================================================================
  
  TRetryStrategy = (rsFixed, rsLinear, rsExponential, rsJitter);
  
  TOnRetry = reference to procedure(RetryCount: Integer; E: Exception;
    var ShouldRetry: Boolean);
  TOnRetryWait = reference to procedure(RetryCount: Integer; WaitMs: Int64);
  
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
    
    function CalculateDelay(RetryCount: Integer): Int64;
    function ShouldHandle(E: Exception): Boolean;
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
    
    // Execute
    procedure Execute(Proc: TProc);
    function Execute<T>(Func: TFunc<T>): T;
    function TryExecute(Proc: TProc; out Error: Exception): Boolean;
  end;
  
  // ============================================================================
  // Timeout Policy
  // ============================================================================
  
  ETimeoutException = class(Exception)
  private
    FTimeoutMs: Int64;
  public
    constructor Create(ATimeoutMs: Int64);
    property TimeoutMs: Int64 read FTimeoutMs;
  end;
  
  TOnTimeout = reference to procedure(TimeoutMs: Int64);
  
  /// <summary>
  /// Timeout policy - limits execution time
  /// </summary>
  TTimeoutPolicy = class
  private
    FTimeoutMs: Int64;
    FOnTimeout: TOnTimeout;
  public
    constructor Create(ATimeoutMs: Int64 = 5000);
    
    // Configuration
    function Timeout(Ms: Int64): TTimeoutPolicy;
    function OnTimeoutEvent(Handler: TOnTimeout): TTimeoutPolicy;
    
    // Execute
    procedure Execute(Proc: TProc);
    function Execute<T>(Func: TFunc<T>): T;
  end;
  
  // ============================================================================
  // Fallback Policy
  // ============================================================================
  
  TFallbackPolicy<T> = class
  private
    FFallbackValue: T;
    FFallbackFunc: TFunc<Exception, T>;
    FHandledExceptions: TList<TClass>;
  public
    constructor Create;
    destructor Destroy; override;
    
    // Configuration
    function Value(AValue: T): TFallbackPolicy<T>;
    function ValueFunc(AFunc: TFunc<Exception, T>): TFallbackPolicy<T>;
    function Handle<E: Exception>: TFallbackPolicy<T>;
    function HandleAll: TFallbackPolicy<T>;
    
    // Execute
    function Execute(Func: TFunc<T>): T;
  end;
  
  // ============================================================================
  // Bulkhead Policy
  // ============================================================================
  
  EBulkheadRejectedException = class(Exception)
  private
    FMaxConcurrency: Integer;
  public
    constructor Create(AMaxConcurrency: Integer);
    property MaxConcurrency: Integer read FMaxConcurrency;
  end;
  
  /// <summary>
  /// Bulkhead policy - limits concurrent executions
  /// </summary>
  TBulkheadPolicy = class
  private
    FMaxConcurrency: Integer;
    FMaxQueue: Integer;
    FCurrentCount: Integer;
    FQueueCount: Integer;
    FSemaphore: TSemaphore;
    FLock: TCriticalSection;
    FQueueTimeoutMs: Int64;
  public
    constructor Create(AMaxConcurrency: Integer; AMaxQueue: Integer = 0);
    destructor Destroy; override;
    
    // Configuration
    function MaxQueue(Value: Integer): TBulkheadPolicy;
    function QueueTimeout(Ms: Int64): TBulkheadPolicy;
    
    // Execute
    procedure Execute(Proc: TProc);
    function Execute<T>(Func: TFunc<T>): T;
    function TryExecute(Proc: TProc): Boolean;
    
    // Stats
    property CurrentCount: Integer read FCurrentCount;
    property QueueCount: Integer read FQueueCount;
    property MaxConcurrency: Integer read FMaxConcurrency;
  end;
  
  // ============================================================================
  // Combined Resilience Policy
  // ============================================================================
  
  TResiliencePolicy = class
  private
    FRetry: TRetryPolicy;
    FTimeout: TTimeoutPolicy;
    FCircuitBreaker: TCircuitBreaker;
    FBulkhead: TBulkheadPolicy;
    FOwnsRetry: Boolean;
    FOwnsTimeout: Boolean;
    FOwnsCircuitBreaker: Boolean;
    FOwnsBulkhead: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    
    // Configuration (fluent)
    function WithRetry(Policy: TRetryPolicy; OwnsPolicy: Boolean = True): TResiliencePolicy;
    function WithTimeout(Policy: TTimeoutPolicy; OwnsPolicy: Boolean = True): TResiliencePolicy; overload;
    function WithTimeout(Ms: Int64): TResiliencePolicy; overload;
    function WithCircuitBreaker(Breaker: TCircuitBreaker;
      OwnsBreaker: Boolean = False): TResiliencePolicy;
    function WithBulkhead(Policy: TBulkheadPolicy;
      OwnsPolicy: Boolean = True): TResiliencePolicy; overload;
    function WithBulkhead(MaxConcurrency: Integer): TResiliencePolicy; overload;
    
    // Execute with all policies
    procedure Execute(Proc: TProc);
    function Execute<T>(Func: TFunc<T>): T;
  end;
  
  // ============================================================================
  // Circuit Breaker Registry
  // ============================================================================
  
  TCircuitBreakerRegistry = class
  private
    FBreakers: TDictionary<string, TCircuitBreaker>;
    FLock: TCriticalSection;
    class var FInstance: TCircuitBreakerRegistry;
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

// Global circuit breaker registry
function CircuitBreakers: TCircuitBreakerRegistry;

implementation

var
  _CircuitBreakerRegistry: TCircuitBreakerRegistry;
  _RegistryLock: TCriticalSection;

function CircuitBreakers: TCircuitBreakerRegistry;
begin
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

// ============================================================================
// TCircuitStateHelper
// ============================================================================

function TCircuitStateHelper.ToString: string;
const
  Names: array[TCircuitState] of string = ('Closed', 'Open', 'HalfOpen');
begin
  Result := Names[Self];
end;

// ============================================================================
// TCircuitBreaker
// ============================================================================

constructor TCircuitBreaker.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
  FState := csClosed;
  FFailureCount := 0;
  FSuccessCount := 0;
  FFailureThreshold := 5;
  FSuccessThreshold := 2;
  FOpenDurationMs := 30000;
  FLastStateChange := Now;
  FLock := TCriticalSection.Create;
end;

destructor TCircuitBreaker.Destroy;
begin
  FLock.Free;
  inherited;
end;

function TCircuitBreaker.FailureThreshold(Value: Integer): TCircuitBreaker;
begin
  FFailureThreshold := Value;
  Result := Self;
end;

function TCircuitBreaker.SuccessThreshold(Value: Integer): TCircuitBreaker;
begin
  FSuccessThreshold := Value;
  Result := Self;
end;

function TCircuitBreaker.OpenDuration(Ms: Int64): TCircuitBreaker;
begin
  FOpenDurationMs := Ms;
  Result := Self;
end;

function TCircuitBreaker.OnStateChanged(Handler: TOnCircuitStateChanged): TCircuitBreaker;
begin
  FOnStateChanged := Handler;
  Result := Self;
end;

function TCircuitBreaker.OnRejected(Handler: TOnCircuitRejected): TCircuitBreaker;
begin
  FOnRejected := Handler;
  Result := Self;
end;

procedure TCircuitBreaker.SetState(NewState: TCircuitState);
var
  OldState: TCircuitState;
begin
  if FState <> NewState then
  begin
    OldState := FState;
    FState := NewState;
    FLastStateChange := Now;
    
    if Assigned(FOnStateChanged) then
      FOnStateChanged(FName, OldState, NewState);
  end;
end;

function TCircuitBreaker.GetState: TCircuitState;
begin
  FLock.Enter;
  try
    CheckHalfOpenTransition;
    Result := FState;
  finally
    FLock.Leave;
  end;
end;

procedure TCircuitBreaker.CheckHalfOpenTransition;
var
  ElapsedMs: Int64;
begin
  if FState = csOpen then
  begin
    ElapsedMs := MilliSecondsBetween(Now, FLastStateChange);
    if ElapsedMs >= FOpenDurationMs then
    begin
      SetState(csHalfOpen);
      FSuccessCount := 0;
    end;
  end;
end;

function TCircuitBreaker.AllowRequest: Boolean;
begin
  FLock.Enter;
  try
    CheckHalfOpenTransition;
    
    case FState of
      csClosed:
        Result := True;
      csOpen:
      begin
        Result := False;
        if Assigned(FOnRejected) then
          FOnRejected(FName);
      end;
      csHalfOpen:
        Result := True;
    else
      Result := False;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TCircuitBreaker.RecordSuccess;
begin
  FLock.Enter;
  try
    case FState of
      csClosed:
        FFailureCount := 0;
      csHalfOpen:
      begin
        Inc(FSuccessCount);
        if FSuccessCount >= FSuccessThreshold then
        begin
          SetState(csClosed);
          FFailureCount := 0;
        end;
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TCircuitBreaker.RecordFailure;
begin
  FLock.Enter;
  try
    FLastFailure := Now;
    
    case FState of
      csClosed:
      begin
        Inc(FFailureCount);
        if FFailureCount >= FFailureThreshold then
          SetState(csOpen);
      end;
      csHalfOpen:
      begin
        SetState(csOpen);
        FFailureCount := 0;
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TCircuitBreaker.Reset;
begin
  FLock.Enter;
  try
    FState := csClosed;
    FFailureCount := 0;
    FSuccessCount := 0;
    FLastStateChange := Now;
  finally
    FLock.Leave;
  end;
end;

procedure TCircuitBreaker.Execute(Proc: TProc);
begin
  if not AllowRequest then
    raise Exception.CreateFmt('Circuit breaker "%s" is open', [FName]);
  
  try
    Proc;
    RecordSuccess;
  except
    RecordFailure;
    raise;
  end;
end;

function TCircuitBreaker.Execute<T>(Func: TFunc<T>): T;
begin
  if not AllowRequest then
    raise Exception.CreateFmt('Circuit breaker "%s" is open', [FName]);
  
  try
    Result := Func;
    RecordSuccess;
  except
    RecordFailure;
    raise;
  end;
end;

// ============================================================================
// ETimeoutException
// ============================================================================

constructor ETimeoutException.Create(ATimeoutMs: Int64);
begin
  inherited CreateFmt('Operation timed out after %d ms', [ATimeoutMs]);
  FTimeoutMs := ATimeoutMs;
end;

// ============================================================================
// TRetryPolicy
// ============================================================================

constructor TRetryPolicy.Create;
begin
  inherited Create;
  FMaxRetries := 3;
  FStrategy := rsFixed;
  FBaseDelayMs := 1000;
  FMaxDelayMs := 30000;
  FMultiplier := 2.0;
  FJitterFactor := 0;
  FHandledExceptions := TList<TClass>.Create;
end;

destructor TRetryPolicy.Destroy;
begin
  FHandledExceptions.Free;
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
  
  // Apply jitter
  if FJitterFactor > 0 then
  begin
    JitterRange := Delay * FJitterFactor;
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
        
        if Assigned(FOnWait) then
          FOnWait(RetryCount, Delay);
        
        Sleep(Delay);
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
        
        if Assigned(FOnWait) then
          FOnWait(RetryCount, Delay);
        
        Sleep(Delay);
      end;
    end;
  end;
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

// ============================================================================
// TTimeoutPolicy
// ============================================================================

constructor TTimeoutPolicy.Create(ATimeoutMs: Int64);
begin
  inherited Create;
  FTimeoutMs := ATimeoutMs;
end;

function TTimeoutPolicy.Timeout(Ms: Int64): TTimeoutPolicy;
begin
  FTimeoutMs := Ms;
  Result := Self;
end;

function TTimeoutPolicy.OnTimeoutEvent(Handler: TOnTimeout): TTimeoutPolicy;
begin
  FOnTimeout := Handler;
  Result := Self;
end;

procedure TTimeoutPolicy.Execute(Proc: TProc);
var
  Task: ITask;
  Completed: Boolean;
begin
  Task := TTask.Create(
    procedure
    begin
      Proc;
    end);
  
  Task.Start;
  Completed := Task.Wait(FTimeoutMs);
  
  if not Completed then
  begin
    if Assigned(FOnTimeout) then
      FOnTimeout(FTimeoutMs);
    raise ETimeoutException.Create(FTimeoutMs);
  end;
  
  // Check for exception in task
  if Task.Status = TTaskStatus.Exception then
    raise Task.GetExceptionObject;
end;

function TTimeoutPolicy.Execute<T>(Func: TFunc<T>): T;
var
  Task: ITask;
  TaskResult: T;
  Completed: Boolean;
begin
  Task := TTask.Create(
    procedure
    begin
      TaskResult := Func;
    end);
  
  Task.Start;
  Completed := Task.Wait(FTimeoutMs);
  
  if not Completed then
  begin
    if Assigned(FOnTimeout) then
      FOnTimeout(FTimeoutMs);
    raise ETimeoutException.Create(FTimeoutMs);
  end;
  
  if Task.Status = TTaskStatus.Exception then
    raise Task.GetExceptionObject;
  
  Result := TaskResult;
end;

// ============================================================================
// TFallbackPolicy<T>
// ============================================================================

constructor TFallbackPolicy<T>.Create;
begin
  inherited Create;
  FHandledExceptions := TList<TClass>.Create;
end;

destructor TFallbackPolicy<T>.Destroy;
begin
  FHandledExceptions.Free;
  inherited;
end;

function TFallbackPolicy<T>.Value(AValue: T): TFallbackPolicy<T>;
begin
  FFallbackValue := AValue;
  FFallbackFunc := nil;
  Result := Self;
end;

function TFallbackPolicy<T>.ValueFunc(AFunc: TFunc<Exception, T>): TFallbackPolicy<T>;
begin
  FFallbackFunc := AFunc;
  Result := Self;
end;

function TFallbackPolicy<T>.Handle<E>: TFallbackPolicy<T>;
begin
  FHandledExceptions.Add(E);
  Result := Self;
end;

function TFallbackPolicy<T>.HandleAll: TFallbackPolicy<T>;
begin
  FHandledExceptions.Clear;
  FHandledExceptions.Add(Exception);
  Result := Self;
end;

function TFallbackPolicy<T>.Execute(Func: TFunc<T>): T;
var
  ExClass: TClass;
  ShouldFallback: Boolean;
begin
  try
    Result := Func;
  except
    on E: Exception do
    begin
      ShouldFallback := FHandledExceptions.Count = 0;
      
      if not ShouldFallback then
      begin
        for ExClass in FHandledExceptions do
        begin
          if E is ExClass then
          begin
            ShouldFallback := True;
            Break;
          end;
        end;
      end;
      
      if ShouldFallback then
      begin
        if Assigned(FFallbackFunc) then
          Result := FFallbackFunc(E)
        else
          Result := FFallbackValue;
      end
      else
        raise;
    end;
  end;
end;

// ============================================================================
// EBulkheadRejectedException
// ============================================================================

constructor EBulkheadRejectedException.Create(AMaxConcurrency: Integer);
begin
  inherited CreateFmt('Bulkhead rejected: max concurrency %d exceeded', [AMaxConcurrency]);
  FMaxConcurrency := AMaxConcurrency;
end;

// ============================================================================
// TBulkheadPolicy
// ============================================================================

constructor TBulkheadPolicy.Create(AMaxConcurrency: Integer; AMaxQueue: Integer);
begin
  inherited Create;
  FMaxConcurrency := AMaxConcurrency;
  FMaxQueue := AMaxQueue;
  FCurrentCount := 0;
  FQueueCount := 0;
  FSemaphore := TSemaphore.Create(nil, AMaxConcurrency, AMaxConcurrency, '');
  FLock := TCriticalSection.Create;
  FQueueTimeoutMs := 30000;
end;

destructor TBulkheadPolicy.Destroy;
begin
  FSemaphore.Free;
  FLock.Free;
  inherited;
end;

function TBulkheadPolicy.MaxQueue(Value: Integer): TBulkheadPolicy;
begin
  FMaxQueue := Value;
  Result := Self;
end;

function TBulkheadPolicy.QueueTimeout(Ms: Int64): TBulkheadPolicy;
begin
  FQueueTimeoutMs := Ms;
  Result := Self;
end;

procedure TBulkheadPolicy.Execute(Proc: TProc);
var
  CanQueue: Boolean;
  Acquired: Boolean;
begin
  // Check if we can queue
  FLock.Enter;
  try
    if FCurrentCount >= FMaxConcurrency then
    begin
      if (FMaxQueue > 0) and (FQueueCount < FMaxQueue) then
      begin
        Inc(FQueueCount);
        CanQueue := True;
      end
      else
        raise EBulkheadRejectedException.Create(FMaxConcurrency);
    end
    else
    begin
      Inc(FCurrentCount);
      CanQueue := False;
    end;
  finally
    FLock.Leave;
  end;
  
  if CanQueue then
  begin
    try
      // Wait for semaphore
      Acquired := FSemaphore.WaitFor(FQueueTimeoutMs) = wrSignaled;
      
      FLock.Enter;
      try
        Dec(FQueueCount);
        if Acquired then
          Inc(FCurrentCount);
      finally
        FLock.Leave;
      end;
      
      if not Acquired then
        raise EBulkheadRejectedException.Create(FMaxConcurrency);
    except
      FLock.Enter;
      try
        Dec(FQueueCount);
      finally
        FLock.Leave;
      end;
      raise;
    end;
  end;
  
  try
    Proc;
  finally
    FLock.Enter;
    try
      Dec(FCurrentCount);
    finally
      FLock.Leave;
    end;
    FSemaphore.Release;
  end;
end;

function TBulkheadPolicy.Execute<T>(Func: TFunc<T>): T;
begin
  Execute(
    procedure
    begin
      Result := Func;
    end);
end;

function TBulkheadPolicy.TryExecute(Proc: TProc): Boolean;
begin
  try
    Execute(Proc);
    Result := True;
  except
    on E: EBulkheadRejectedException do
      Result := False;
  end;
end;

// ============================================================================
// TResiliencePolicy
// ============================================================================

constructor TResiliencePolicy.Create;
begin
  inherited Create;
end;

destructor TResiliencePolicy.Destroy;
begin
  if FOwnsRetry and Assigned(FRetry) then
    FRetry.Free;
  if FOwnsTimeout and Assigned(FTimeout) then
    FTimeout.Free;
  if FOwnsCircuitBreaker and Assigned(FCircuitBreaker) then
    FCircuitBreaker.Free;
  if FOwnsBulkhead and Assigned(FBulkhead) then
    FBulkhead.Free;
  inherited;
end;

function TResiliencePolicy.WithRetry(Policy: TRetryPolicy;
  OwnsPolicy: Boolean): TResiliencePolicy;
begin
  if FOwnsRetry and Assigned(FRetry) then
    FRetry.Free;
  FRetry := Policy;
  FOwnsRetry := OwnsPolicy;
  Result := Self;
end;

function TResiliencePolicy.WithTimeout(Policy: TTimeoutPolicy;
  OwnsPolicy: Boolean): TResiliencePolicy;
begin
  if FOwnsTimeout and Assigned(FTimeout) then
    FTimeout.Free;
  FTimeout := Policy;
  FOwnsTimeout := OwnsPolicy;
  Result := Self;
end;

function TResiliencePolicy.WithTimeout(Ms: Int64): TResiliencePolicy;
begin
  Result := WithTimeout(TTimeoutPolicy.Create(Ms), True);
end;

function TResiliencePolicy.WithCircuitBreaker(Breaker: TCircuitBreaker;
  OwnsBreaker: Boolean): TResiliencePolicy;
begin
  if FOwnsCircuitBreaker and Assigned(FCircuitBreaker) then
    FCircuitBreaker.Free;
  FCircuitBreaker := Breaker;
  FOwnsCircuitBreaker := OwnsBreaker;
  Result := Self;
end;

function TResiliencePolicy.WithBulkhead(Policy: TBulkheadPolicy;
  OwnsPolicy: Boolean): TResiliencePolicy;
begin
  if FOwnsBulkhead and Assigned(FBulkhead) then
    FBulkhead.Free;
  FBulkhead := Policy;
  FOwnsBulkhead := OwnsPolicy;
  Result := Self;
end;

function TResiliencePolicy.WithBulkhead(MaxConcurrency: Integer): TResiliencePolicy;
begin
  Result := WithBulkhead(TBulkheadPolicy.Create(MaxConcurrency), True);
end;

procedure TResiliencePolicy.Execute(Proc: TProc);
var
  InnerProc: TProc;
begin
  InnerProc := Proc;
  
  // Wrap with timeout
  if Assigned(FTimeout) then
  begin
    var TimeoutProc := InnerProc;
    InnerProc := procedure
      begin
        FTimeout.Execute(TimeoutProc);
      end;
  end;
  
  // Wrap with circuit breaker
  if Assigned(FCircuitBreaker) then
  begin
    var BreakerProc := InnerProc;
    InnerProc := procedure
      begin
        FCircuitBreaker.Execute(BreakerProc);
      end;
  end;
  
  // Wrap with retry
  if Assigned(FRetry) then
  begin
    var RetryProc := InnerProc;
    InnerProc := procedure
      begin
        FRetry.Execute(RetryProc);
      end;
  end;
  
  // Wrap with bulkhead
  if Assigned(FBulkhead) then
  begin
    var BulkheadProc := InnerProc;
    InnerProc := procedure
      begin
        FBulkhead.Execute(BulkheadProc);
      end;
  end;
  
  InnerProc;
end;

function TResiliencePolicy.Execute<T>(Func: TFunc<T>): T;
var
  R: T;
begin
  Execute(
    procedure
    begin
      R := Func;
    end);
  Result := R;
end;

// ============================================================================
// TCircuitBreakerRegistry
// ============================================================================

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
  FBreakers.Free;
  FLock.Free;
  inherited;
end;

function TCircuitBreakerRegistry.GetOrCreate(const Name: string): TCircuitBreaker;
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

initialization
  _RegistryLock := TCriticalSection.Create;
  Randomize;

finalization
  FreeAndNil(_CircuitBreakerRegistry);
  FreeAndNil(_RegistryLock);

end.
