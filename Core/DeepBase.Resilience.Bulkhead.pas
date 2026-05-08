{ ============================================================================
  DeepBase.Resilience.Bulkhead - Bulkhead resilience policy
  Split from DeepBase.Resilience; use DeepBase.Resilience for compatibility.
  ============================================================================ }

unit DeepBase.Resilience.Bulkhead;

interface

uses
  System.SysUtils,
  System.SyncObjs;

type
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
    procedure Execute(Proc: TProc); overload;
    function Execute<T>(Func: TFunc<T>): T; overload;
    function TryExecute(Proc: TProc): Boolean;
    
    // Stats
    property CurrentCount: Integer read FCurrentCount;
    property QueueCount: Integer read FQueueCount;
    property MaxConcurrency: Integer read FMaxConcurrency;
  end;

implementation

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
  FreeAndNil(FSemaphore);
  FreeAndNil(FLock);
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
  NeedReleaseSemaphore: Boolean;
begin
  NeedReleaseSemaphore := False;
  
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
      // BUG-054 FIX: When not queuing, we need to acquire semaphore first
      // to maintain proper semaphore count
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
        begin
          Inc(FCurrentCount);
          NeedReleaseSemaphore := True;
        end;
      finally
        FLock.Leave;
      end;
      
      if not Acquired then
        raise EBulkheadRejectedException.Create(FMaxConcurrency);
    except
      on E: EBulkheadRejectedException do
      begin
        // Already handled QueueCount in the try block above
        raise;
      end;
      on E: Exception do
      begin
        FLock.Enter;
        try
          Dec(FQueueCount);
        finally
          FLock.Leave;
        end;
        raise;
      end;
    end;
  end
  else
  begin
    // BUG-054 FIX: When not queuing, acquire semaphore to maintain count
    Acquired := FSemaphore.WaitFor(FQueueTimeoutMs) = wrSignaled;
    if Acquired then
      NeedReleaseSemaphore := True
    else
    begin
      // Rollback the FCurrentCount increment
      FLock.Enter;
      try
        Dec(FCurrentCount);
      finally
        FLock.Leave;
      end;
      raise EBulkheadRejectedException.Create(FMaxConcurrency);
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
    // BUG-054 FIX: Only release semaphore if we acquired it
    if NeedReleaseSemaphore then
      FSemaphore.Release;
  end;
end;

function TBulkheadPolicy.Execute<T>(Func: TFunc<T>): T;
var
  R: T;
begin
  Execute(
    procedure
    begin
      R := Func();
    end);
  Result := R;
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

end.
