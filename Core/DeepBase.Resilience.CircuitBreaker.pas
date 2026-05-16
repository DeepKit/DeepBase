{ ============================================================================
  DeepBase.Resilience.CircuitBreaker - Circuit breaker resilience policy
  Split from DeepBase.Resilience; use DeepBase.Resilience for compatibility.
  ============================================================================ }

unit DeepBase.Resilience.CircuitBreaker;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.SyncObjs,
  DeepBase.Constants,
  DeepBase.Exceptions;

type
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
    FHalfOpenActiveCount: Integer;  // BUG-119 FIX: 跟踪HalfOpen状态下的活跃请求数
    FMaxHalfOpenRequests: Integer;  // BUG-119 FIX: HalfOpen状态下允许的最大并发请求数

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
    function AllowRequest: Boolean; deprecated 'Use Execute(...) to keep state transitions atomic';
    procedure RecordSuccess;
    procedure RecordFailure;
    procedure Reset;
    
    // Execute with circuit breaker
    procedure Execute(Proc: TProc); overload;
    procedure Execute(Proc: TProc; TimeoutMs: Int64); overload;
    function Execute<T>(Func: TFunc<T>): T; overload;
    function Execute<T>(Func: TFunc<T>; TimeoutMs: Int64): T; overload;
    
    // State info
    property Name: string read FName;
    property State: TCircuitState read GetState;
    property FailureCount: Integer read FFailureCount;
    property SuccessCount: Integer read FSuccessCount;
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

uses
  System.DateUtils,
  DeepBase.Resilience.Timeout;

var
  _CircuitBreakerRegistry: TCircuitBreakerRegistry;
  _RegistryLock: TCriticalSection;

function CircuitBreakers: TCircuitBreakerRegistry;
begin
  // BUG-111 FIX: 确保锁已初始化后再使�?
  if not Assigned(_RegistryLock) then
    raise ECircuitBreakerNotInitializedException.Create('CircuitBreakers registry lock not initialized');
    
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
  FOpenDurationMs := DEFAULT_KEEP_ALIVE_TIMEOUT_MS;
  FLastStateChange := Now;
  FLock := TCriticalSection.Create;
  // BUG-119 FIX: 初始化HalfOpen状态跟踪变�?
  FHalfOpenActiveCount := 0;
  FMaxHalfOpenRequests := 1;  // 默认只允�?个探测请�?
end;

destructor TCircuitBreaker.Destroy;
begin
  FreeAndNil(FLock);
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
      begin
        // BUG-119 FIX: 限制HalfOpen状态下的并发请求数
        // 只允许有限数量的探测请求通过，防止高并发场景下状态混�?
        if FHalfOpenActiveCount < FMaxHalfOpenRequests then
        begin
          Inc(FHalfOpenActiveCount);
          Result := True;
        end
        else
        begin
          Result := False;
          if Assigned(FOnRejected) then
            FOnRejected(FName);
        end;
      end;
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
        // BUG-119 FIX: 减少活跃请求计数
        if FHalfOpenActiveCount > 0 then
          Dec(FHalfOpenActiveCount);

        Inc(FSuccessCount);
        if FSuccessCount >= FSuccessThreshold then
        begin
          SetState(csClosed);
          FFailureCount := 0;
          FHalfOpenActiveCount := 0;  // 重置计数
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
        // BUG-119 FIX: 减少活跃请求计数并立即打开断路�?
        if FHalfOpenActiveCount > 0 then
          Dec(FHalfOpenActiveCount);

        SetState(csOpen);
        FFailureCount := 0;
        FHalfOpenActiveCount := 0;  // 重置计数
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
    FHalfOpenActiveCount := 0;  // BUG-119 FIX: 重置活跃请求计数
  finally
    FLock.Leave;
  end;
end;

procedure TCircuitBreaker.Execute(Proc: TProc);
begin
  FLock.Enter;
  try
    CheckHalfOpenTransition;
    case FState of
      csOpen:
      begin
        if Assigned(FOnRejected) then
          FOnRejected(FName);
        raise ECircuitBreakerException.CreateFmt('Circuit breaker "%s" is open', [FName]);
      end;
      csHalfOpen:
      begin
        if FHalfOpenActiveCount >= FMaxHalfOpenRequests then
        begin
          if Assigned(FOnRejected) then
            FOnRejected(FName);
          raise ECircuitBreakerException.CreateFmt('Circuit breaker "%s" is open', [FName]);
        end;
        Inc(FHalfOpenActiveCount);
      end;
    end;
  finally
    FLock.Leave;
  end;

  try
    Proc;
    RecordSuccess;
  except
    RecordFailure;
    raise;
  end;
end;

procedure TCircuitBreaker.Execute(Proc: TProc; TimeoutMs: Int64);
var
  TimeoutPolicy: TTimeoutPolicy;
begin
  TimeoutPolicy := TTimeoutPolicy.Create(TimeoutMs);
  try
    Execute(
      procedure
      begin
        TimeoutPolicy.Execute(Proc);
      end);
  finally
    TimeoutPolicy.Free;
  end;
end;

function TCircuitBreaker.Execute<T>(Func: TFunc<T>): T;
begin
  FLock.Enter;
  try
    CheckHalfOpenTransition;
    case FState of
      csOpen:
      begin
        if Assigned(FOnRejected) then
          FOnRejected(FName);
        raise ECircuitBreakerException.CreateFmt('Circuit breaker "%s" is open', [FName]);
      end;
      csHalfOpen:
      begin
        if FHalfOpenActiveCount >= FMaxHalfOpenRequests then
        begin
          if Assigned(FOnRejected) then
            FOnRejected(FName);
          raise ECircuitBreakerException.CreateFmt('Circuit breaker "%s" is open', [FName]);
        end;
        Inc(FHalfOpenActiveCount);
      end;
    end;
  finally
    FLock.Leave;
  end;

  try
    Result := Func;
    RecordSuccess;
  except
    RecordFailure;
    raise;
  end;
end;

function TCircuitBreaker.Execute<T>(Func: TFunc<T>; TimeoutMs: Int64): T;
var
  TimeoutPolicy: TTimeoutPolicy;
begin
  TimeoutPolicy := TTimeoutPolicy.Create(TimeoutMs);
  try
    Result := Execute<T>(
      function: T
      begin
        Result := TimeoutPolicy.Execute<T>(Func);
      end);
  finally
    TimeoutPolicy.Free;
  end;
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
  FreeAndNil(FBreakers);
  FreeAndNil(FLock);
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

finalization
  FreeAndNil(_CircuitBreakerRegistry);
  FreeAndNil(_RegistryLock);

end.
