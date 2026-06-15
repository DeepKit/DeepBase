{ ============================================================================
  DeepBase.Resilience.Policy - Combined resilience policy
  Split from DeepBase.Resilience; use DeepBase.Resilience for compatibility.
  ============================================================================ }

unit DeepBase.Resilience.Policy;

interface

uses
  System.SysUtils,
  DeepBase.Resilience.CircuitBreaker,
  DeepBase.Resilience.Retry,
  DeepBase.Resilience.Timeout,
  DeepBase.Resilience.Bulkhead;

type
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
    procedure Execute(Proc: TProc); overload;
    function Execute<T>(Func: TFunc<T>): T; overload;
  end;

implementation

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
    FreeAndNil(FRetry);
  if FOwnsTimeout and Assigned(FTimeout) then
    FreeAndNil(FTimeout);
  if FOwnsCircuitBreaker and Assigned(FCircuitBreaker) then
    FreeAndNil(FCircuitBreaker);
  if FOwnsBulkhead and Assigned(FBulkhead) then
    FreeAndNil(FBulkhead);
  inherited;
end;

function TResiliencePolicy.WithRetry(Policy: TRetryPolicy;
  OwnsPolicy: Boolean): TResiliencePolicy;
begin
  if FOwnsRetry and Assigned(FRetry) then
    FreeAndNil(FRetry);
  FRetry := Policy;
  FOwnsRetry := OwnsPolicy;
  Result := Self;
end;

function TResiliencePolicy.WithTimeout(Policy: TTimeoutPolicy;
  OwnsPolicy: Boolean): TResiliencePolicy;
begin
  if FOwnsTimeout and Assigned(FTimeout) then
    FreeAndNil(FTimeout);
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
    FreeAndNil(FCircuitBreaker);
  FCircuitBreaker := Breaker;
  FOwnsCircuitBreaker := OwnsBreaker;
  Result := Self;
end;

function TResiliencePolicy.WithBulkhead(Policy: TBulkheadPolicy;
  OwnsPolicy: Boolean): TResiliencePolicy;
begin
  if FOwnsBulkhead and Assigned(FBulkhead) then
    FreeAndNil(FBulkhead);
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
  TimeoutProc: TProc;
  BreakerProc: TProc;
  RetryProc: TProc;
  BulkheadProc: TProc;
begin
  InnerProc := Proc;
  TimeoutProc := nil;
  BreakerProc := nil;
  RetryProc := nil;
  BulkheadProc := nil;
  
  // Wrap with timeout
  if Assigned(FTimeout) then
  begin
    TimeoutProc := InnerProc;
    InnerProc := procedure
      begin
        FTimeout.Execute(TimeoutProc);
      end;
  end;
  
  // Wrap with circuit breaker
  if Assigned(FCircuitBreaker) then
  begin
    BreakerProc := InnerProc;
    InnerProc := procedure
      begin
        FCircuitBreaker.Execute(BreakerProc);
      end;
  end;
  
  // Wrap with retry
  if Assigned(FRetry) then
  begin
    RetryProc := InnerProc;
    InnerProc := procedure
      begin
        FRetry.Execute(RetryProc);
      end;
  end;
  
  // Wrap with bulkhead
  if Assigned(FBulkhead) then
  begin
    BulkheadProc := InnerProc;
    InnerProc := procedure
      begin
        FBulkhead.Execute(BulkheadProc);
      end;
  end;
  
  try
    InnerProc();
  finally
    InnerProc := nil;
    TimeoutProc := nil;
    BreakerProc := nil;
    RetryProc := nil;
    BulkheadProc := nil;
  end;
end;

function TResiliencePolicy.Execute<T>(Func: TFunc<T>): T;
var
  InnerFunc: TFunc<T>;
  TimeoutFunc: TFunc<T>;
  BreakerFunc: TFunc<T>;
  RetryFunc: TFunc<T>;
  BulkheadFunc: TFunc<T>;
begin
  InnerFunc := Func;
  TimeoutFunc := nil;
  BreakerFunc := nil;
  RetryFunc := nil;
  BulkheadFunc := nil;

  if Assigned(FTimeout) then
  begin
    TimeoutFunc := InnerFunc;
    InnerFunc := function: T
      begin
        Result := FTimeout.Execute<T>(TimeoutFunc);
      end;
  end;

  if Assigned(FCircuitBreaker) then
  begin
    BreakerFunc := InnerFunc;
    InnerFunc := function: T
      begin
        Result := FCircuitBreaker.Execute<T>(BreakerFunc);
      end;
  end;

  if Assigned(FRetry) then
  begin
    RetryFunc := InnerFunc;
    InnerFunc := function: T
      begin
        Result := FRetry.Execute<T>(RetryFunc);
      end;
  end;

  if Assigned(FBulkhead) then
  begin
    BulkheadFunc := InnerFunc;
    InnerFunc := function: T
      begin
        Result := FBulkhead.Execute<T>(BulkheadFunc);
      end;
  end;

  try
    Result := InnerFunc();
  finally
    InnerFunc := nil;
    TimeoutFunc := nil;
    BreakerFunc := nil;
    RetryFunc := nil;
    BulkheadFunc := nil;
  end;
end;

end.
