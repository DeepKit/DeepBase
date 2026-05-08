{ ============================================================================
  Stress.Concurrency - High Concurrency Race Condition Tests

  Tests for race conditions and thread safety:
  - Shared resource access patterns
  - Lock contention scenarios
  - Atomic operation stress
  - Deadlock detection
  - Thread pool exhaustion
  ============================================================================ }

unit Stress.Concurrency;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.SyncObjs,
  System.Diagnostics,
  DeepBase.StressTest;

type
  // ============================================================================
  // TSharedResourceStressTest - Shared resource access
  // ============================================================================

  TSharedResourceStressTest = class(TStressTest)
  private
    FSharedCounter: Int64;
    FExpectedValue: Int64;
    FReadsPerformed: Int64;
    FWritesPerformed: Int64;
    FInconsistenciesDetected: Int64;
    FLock: TCriticalSection;
    FRWLock: TMultiReadExclusiveWriteSynchronizer;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
  end;

  // ============================================================================
  // TLockContentionStressTest - Lock contention scenarios
  // ============================================================================

  TLockContentionStressTest = class(TStressTest)
  private
    FLockAcquisitions: Int64;
    FLockContentions: Int64;
    FLockTimeoutMs: Integer;
    FResourceValue: Int64;
    FLock: TCriticalSection;
    FContentionLock: TCriticalSection;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
    property LockTimeoutMs: Integer read FLockTimeoutMs write FLockTimeoutMs;
  end;

  // ============================================================================
  // TAtomicOperationStressTest - Atomic operation stress
  // ============================================================================

  TAtomicOperationStressTest = class(TStressTest)
  private
    FAtomicCounter: Int64;
    FCompareExchangeCounter: Int64;
    FIncrementCount: Int64;
    FCompareExchangeSuccess: Int64;
    FCompareExchangeFail: Int64;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
  end;

  // ============================================================================
  // TDeadlockDetectionStressTest - Deadlock detection
  // ============================================================================

  TDeadlockDetectionStressTest = class(TStressTest)
  private
    FLockA: TCriticalSection;
    FLockB: TCriticalSection;
    FLockC: TCriticalSection;
    FOperationsCompleted: Int64;
    FDeadlocksAvoided: Int64;
    FTimeoutMs: Integer;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
    function TryAcquireLock(Lock: TCriticalSection; TimeoutMs: Integer): Boolean;
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
    property TimeoutMs: Integer read FTimeoutMs write FTimeoutMs;
  end;

  // ============================================================================
  // TProducerConsumerStressTest - Producer-consumer pattern
  // ============================================================================

  TProducerConsumerStressTest = class(TStressTest)
  private
    FQueue: TThreadList<Int64>;
    FProducedCount: Int64;
    FConsumedCount: Int64;
    FMaxQueueSize: Integer;
    FQueueOverflows: Int64;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
    property MaxQueueSize: Integer read FMaxQueueSize write FMaxQueueSize;
  end;

  // ============================================================================
  // TThreadPoolExhaustionTest - Thread pool exhaustion
  // ============================================================================

  TThreadPoolExhaustionTest = class(TStressTest)
  private
    FTasksSubmitted: Int64;
    FTasksCompleted: Int64;
    FTaskRejections: Int64;
    FMaxConcurrentTasks: Integer;
    FActiveTasks: Integer;
    FLock: TCriticalSection;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
    property MaxConcurrentTasks: Integer read FMaxConcurrentTasks write FMaxConcurrentTasks;
  end;

  // ============================================================================
  // TReadWriteLockStressTest - Read-write lock patterns
  // ============================================================================

  TReadWriteLockStressTest = class(TStressTest)
  private
    FSharedData: TDictionary<string, Int64>;
    FRWLock: TMultiReadExclusiveWriteSynchronizer;
    FReadsPerformed: Int64;
    FWritesPerformed: Int64;
    FReadWriteRatio: Double;  // Ratio of reads to writes
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
    property ReadWriteRatio: Double read FReadWriteRatio write FReadWriteRatio;
  end;

  // ============================================================================
  // TCASSpinLockStressTest - Compare-and-swap spin lock
  // ============================================================================

  TCASSpinLockStressTest = class(TStressTest)
  private
    FLockState: Integer;  // 0 = unlocked, 1 = locked
    FSpinCount: Int64;
    FLockAcquisitions: Int64;
    FMaxSpinsPerAcquire: Integer;
    FTotalSpins: Int64;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
    procedure SpinLock;
    procedure SpinUnlock;
  public
    constructor Create; reintroduce;
    property MaxSpinsPerAcquire: Integer read FMaxSpinsPerAcquire write FMaxSpinsPerAcquire;
  end;

  // ============================================================================
  // Helper functions
  // ============================================================================

  /// <summary>Run all concurrency stress tests</summary>
  function RunAllConcurrencyStressTests(DurationSec: Integer = 300;
    ThreadCount: Integer = 20): TStressTestReport;

  /// <summary>Run quick concurrency check (60 seconds)</summary>
  function RunQuickConcurrencyCheck: TStressTestReport;

implementation

uses
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  System.Math,
  System.Threading;

// ============================================================================
// TSharedResourceStressTest
// ============================================================================

constructor TSharedResourceStressTest.Create;
begin
  inherited Create('Concurrency.SharedResource', 'Shared resource access test');
  FLock := TCriticalSection.Create;
  FRWLock := TMultiReadExclusiveWriteSynchronizer.Create;
end;

destructor TSharedResourceStressTest.Destroy;
begin
  FRWLock.Free;
  FLock.Free;
  inherited;
end;

procedure TSharedResourceStressTest.Setup;
begin
  FSharedCounter := 0;
  FExpectedValue := 0;
  FReadsPerformed := 0;
  FWritesPerformed := 0;
  FInconsistenciesDetected := 0;
end;

procedure TSharedResourceStressTest.Teardown;
begin
  AddCustomMetric('FinalCounter', FSharedCounter);
  AddCustomMetric('ExpectedValue', FExpectedValue);
  AddCustomMetric('ReadsPerformed', FReadsPerformed);
  AddCustomMetric('WritesPerformed', FWritesPerformed);
  AddCustomMetric('InconsistenciesDetected', FInconsistenciesDetected);
  AddCustomMetric('DataIntegrity',
    Ord(FSharedCounter = FExpectedValue));
end;

procedure TSharedResourceStressTest.Execute;
var
  SW: TStopwatch;
  DoWrite: Boolean;
  ReadValue: Int64;
begin
  SW := TStopwatch.StartNew;
  try
    DoWrite := Random > 0.7;  // 30% writes, 70% reads

    if DoWrite then
    begin
      // Write operation with exclusive lock
      FRWLock.BeginWrite;
      try
        Inc(FSharedCounter);
        TInterlocked.Increment(FExpectedValue);
        TInterlocked.Increment(FWritesPerformed);
      finally
        FRWLock.EndWrite;
      end;
    end
    else
    begin
      // Read operation with shared lock
      FRWLock.BeginRead;
      try
        ReadValue := FSharedCounter;
        TInterlocked.Increment(FReadsPerformed);

        // Check for obvious inconsistencies
        if ReadValue < 0 then
          TInterlocked.Increment(FInconsistenciesDetected);
      finally
        FRWLock.EndRead;
      end;
    end;

    SW.Stop;
    ReportLatency(SW.Elapsed.TotalMilliseconds);
    ReportSuccess;
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Shared resource access failed: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// TLockContentionStressTest
// ============================================================================

constructor TLockContentionStressTest.Create;
begin
  inherited Create('Concurrency.LockContention', 'Lock contention stress test');
  FLockTimeoutMs := 100;
  FLock := TCriticalSection.Create;
  FContentionLock := TCriticalSection.Create;
end;

destructor TLockContentionStressTest.Destroy;
begin
  FContentionLock.Free;
  FLock.Free;
  inherited;
end;

procedure TLockContentionStressTest.Setup;
begin
  FLockAcquisitions := 0;
  FLockContentions := 0;
  FResourceValue := 0;
end;

procedure TLockContentionStressTest.Teardown;
begin
  AddCustomMetric('LockAcquisitions', FLockAcquisitions);
  AddCustomMetric('LockContentions', FLockContentions);
  AddCustomMetric('ResourceValue', FResourceValue);
  AddCustomMetric('ContentionRate',
    IfThen(FLockAcquisitions > 0,
      FLockContentions / FLockAcquisitions, 0));
end;

procedure TLockContentionStressTest.Execute;
var
  SW: TStopwatch;
  Acquired: Boolean;
begin
  SW := TStopwatch.StartNew;
  try
    // Try to acquire with timeout
    Acquired := FContentionLock.TryEnter;

    if Acquired then
    begin
      try
        TInterlocked.Increment(FLockAcquisitions);

        // Do some work while holding lock
        Inc(FResourceValue);
        Sleep(1);  // Simulate work
      finally
        FContentionLock.Leave;
      end;
    end
    else
    begin
      // Lock contention occurred
      TInterlocked.Increment(FLockContentions);

      // Wait and retry
      FContentionLock.Enter;
      try
        TInterlocked.Increment(FLockAcquisitions);
        Inc(FResourceValue);
      finally
        FContentionLock.Leave;
      end;
    end;

    SW.Stop;
    ReportLatency(SW.Elapsed.TotalMilliseconds);
    ReportSuccess;
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Lock contention failed: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// TAtomicOperationStressTest
// ============================================================================

constructor TAtomicOperationStressTest.Create;
begin
  inherited Create('Concurrency.AtomicOps', 'Atomic operation stress test');
end;

procedure TAtomicOperationStressTest.Setup;
begin
  FAtomicCounter := 0;
  FCompareExchangeCounter := 0;
  FIncrementCount := 0;
  FCompareExchangeSuccess := 0;
  FCompareExchangeFail := 0;
end;

procedure TAtomicOperationStressTest.Teardown;
begin
  AddCustomMetric('AtomicCounter', FAtomicCounter);
  AddCustomMetric('CompareExchangeCounter', FCompareExchangeCounter);
  AddCustomMetric('IncrementCount', FIncrementCount);
  AddCustomMetric('CompareExchangeSuccess', FCompareExchangeSuccess);
  AddCustomMetric('CompareExchangeFail', FCompareExchangeFail);
  AddCustomMetric('AtomicIntegrity',
    Ord(FAtomicCounter = FIncrementCount));
end;

procedure TAtomicOperationStressTest.Execute;
var
  SW: TStopwatch;
  OldValue, NewValue: Int64;
  DoIncrement: Boolean;
begin
  SW := TStopwatch.StartNew;
  try
    DoIncrement := Random > 0.5;

    if DoIncrement then
    begin
      // Simple atomic increment
      TInterlocked.Increment(FAtomicCounter);
      TInterlocked.Increment(FIncrementCount);
    end
    else
    begin
      // Compare-and-exchange operation
      repeat
        OldValue := FCompareExchangeCounter;
        NewValue := OldValue + 1;
      until TInterlocked.CompareExchange(FCompareExchangeCounter, NewValue, OldValue) = OldValue;

      TInterlocked.Increment(FCompareExchangeSuccess);
    end;

    SW.Stop;
    ReportLatency(SW.Elapsed.TotalMilliseconds);
    ReportSuccess;
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Atomic operation failed: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// TDeadlockDetectionStressTest
// ============================================================================

constructor TDeadlockDetectionStressTest.Create;
begin
  inherited Create('Concurrency.DeadlockDetection', 'Deadlock detection and avoidance test');
  FLockA := TCriticalSection.Create;
  FLockB := TCriticalSection.Create;
  FLockC := TCriticalSection.Create;
  FTimeoutMs := 50;
end;

destructor TDeadlockDetectionStressTest.Destroy;
begin
  FLockC.Free;
  FLockB.Free;
  FLockA.Free;
  inherited;
end;

procedure TDeadlockDetectionStressTest.Setup;
begin
  FOperationsCompleted := 0;
  FDeadlocksAvoided := 0;
end;

procedure TDeadlockDetectionStressTest.Teardown;
begin
  AddCustomMetric('OperationsCompleted', FOperationsCompleted);
  AddCustomMetric('DeadlocksAvoided', FDeadlocksAvoided);
  AddCustomMetric('TimeoutMs', FTimeoutMs);
end;

function TDeadlockDetectionStressTest.TryAcquireLock(Lock: TCriticalSection;
  TimeoutMs: Integer): Boolean;
var
  StartTime: Cardinal;
begin
  StartTime := GetTickCount;
  repeat
    if Lock.TryEnter then
    begin
      Result := True;
      Exit;
    end;
    Sleep(1);
  until (GetTickCount - StartTime) >= Cardinal(TimeoutMs);
  Result := False;
end;

procedure TDeadlockDetectionStressTest.Execute;
var
  SW: TStopwatch;
  LockOrder: Integer;
  AcquiredA, AcquiredB, AcquiredC: Boolean;
begin
  SW := TStopwatch.StartNew;
  AcquiredA := False;
  AcquiredB := False;
  AcquiredC := False;

  try
    // Random lock order (can cause deadlocks without proper handling)
    LockOrder := Random(6);

    case LockOrder of
      0: // A -> B -> C
        begin
          AcquiredA := TryAcquireLock(FLockA, FTimeoutMs);
          if AcquiredA then AcquiredB := TryAcquireLock(FLockB, FTimeoutMs);
          if AcquiredB then AcquiredC := TryAcquireLock(FLockC, FTimeoutMs);
        end;
      1: // A -> C -> B
        begin
          AcquiredA := TryAcquireLock(FLockA, FTimeoutMs);
          if AcquiredA then AcquiredC := TryAcquireLock(FLockC, FTimeoutMs);
          if AcquiredC then AcquiredB := TryAcquireLock(FLockB, FTimeoutMs);
        end;
      2: // B -> A -> C
        begin
          AcquiredB := TryAcquireLock(FLockB, FTimeoutMs);
          if AcquiredB then AcquiredA := TryAcquireLock(FLockA, FTimeoutMs);
          if AcquiredA then AcquiredC := TryAcquireLock(FLockC, FTimeoutMs);
        end;
      3: // B -> C -> A
        begin
          AcquiredB := TryAcquireLock(FLockB, FTimeoutMs);
          if AcquiredB then AcquiredC := TryAcquireLock(FLockC, FTimeoutMs);
          if AcquiredC then AcquiredA := TryAcquireLock(FLockA, FTimeoutMs);
        end;
      4: // C -> A -> B
        begin
          AcquiredC := TryAcquireLock(FLockC, FTimeoutMs);
          if AcquiredC then AcquiredA := TryAcquireLock(FLockA, FTimeoutMs);
          if AcquiredA then AcquiredB := TryAcquireLock(FLockB, FTimeoutMs);
        end;
      5: // C -> B -> A
        begin
          AcquiredC := TryAcquireLock(FLockC, FTimeoutMs);
          if AcquiredC then AcquiredB := TryAcquireLock(FLockB, FTimeoutMs);
          if AcquiredB then AcquiredA := TryAcquireLock(FLockA, FTimeoutMs);
        end;
    end;

    // Check if we got all locks
    if AcquiredA and AcquiredB and AcquiredC then
    begin
      // Do work
      Sleep(1);
      TInterlocked.Increment(FOperationsCompleted);
    end
    else
    begin
      // Deadlock avoided by timeout
      TInterlocked.Increment(FDeadlocksAvoided);
    end;

    SW.Stop;
    ReportLatency(SW.Elapsed.TotalMilliseconds);
    ReportSuccess;
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Deadlock test failed: ' + E.Message);
    end;
  end;

  // Release locks in reverse order
  if AcquiredC then FLockC.Leave;
  if AcquiredB then FLockB.Leave;
  if AcquiredA then FLockA.Leave;
end;

// ============================================================================
// TProducerConsumerStressTest
// ============================================================================

constructor TProducerConsumerStressTest.Create;
begin
  inherited Create('Concurrency.ProducerConsumer', 'Producer-consumer pattern test');
  FQueue := TThreadList<Int64>.Create;
  FMaxQueueSize := 1000;
end;

destructor TProducerConsumerStressTest.Destroy;
begin
  FQueue.Free;
  inherited;
end;

procedure TProducerConsumerStressTest.Setup;
begin
  FProducedCount := 0;
  FConsumedCount := 0;
  FQueueOverflows := 0;
end;

procedure TProducerConsumerStressTest.Teardown;
var
  List: TList<Int64>;
begin
  List := FQueue.LockList;
  try
    AddCustomMetric('QueueRemaining', List.Count);
  finally
    FQueue.UnlockList;
  end;

  AddCustomMetric('ProducedCount', FProducedCount);
  AddCustomMetric('ConsumedCount', FConsumedCount);
  AddCustomMetric('QueueOverflows', FQueueOverflows);
  AddCustomMetric('MaxQueueSize', FMaxQueueSize);
end;

procedure TProducerConsumerStressTest.Execute;
var
  SW: TStopwatch;
  IsProduce: Boolean;
  List: TList<Int64>;
  Item: Int64;
begin
  SW := TStopwatch.StartNew;
  try
    IsProduce := Random > 0.4;  // 60% produce, 40% consume

    if IsProduce then
    begin
      // Produce
      List := FQueue.LockList;
      try
        if List.Count < FMaxQueueSize then
        begin
          List.Add(GetTickCount64);
          TInterlocked.Increment(FProducedCount);
        end
        else
        begin
          TInterlocked.Increment(FQueueOverflows);
        end;
      finally
        FQueue.UnlockList;
      end;
    end
    else
    begin
      // Consume
      List := FQueue.LockList;
      try
        if List.Count > 0 then
        begin
          Item := List[0];
          List.Delete(0);
          TInterlocked.Increment(FConsumedCount);
        end;
      finally
        FQueue.UnlockList;
      end;
    end;

    SW.Stop;
    ReportLatency(SW.Elapsed.TotalMilliseconds);
    ReportSuccess;
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Producer-consumer failed: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// TThreadPoolExhaustionTest
// ============================================================================

constructor TThreadPoolExhaustionTest.Create;
begin
  inherited Create('Concurrency.ThreadPoolExhaustion', 'Thread pool exhaustion test');
  FMaxConcurrentTasks := 50;
  FLock := TCriticalSection.Create;
end;

destructor TThreadPoolExhaustionTest.Destroy;
begin
  FLock.Free;
  inherited;
end;

procedure TThreadPoolExhaustionTest.Setup;
begin
  FTasksSubmitted := 0;
  FTasksCompleted := 0;
  FTaskRejections := 0;
  FActiveTasks := 0;
end;

procedure TThreadPoolExhaustionTest.Teardown;
begin
  AddCustomMetric('TasksSubmitted', FTasksSubmitted);
  AddCustomMetric('TasksCompleted', FTasksCompleted);
  AddCustomMetric('TaskRejections', FTaskRejections);
  AddCustomMetric('MaxConcurrentTasks', FMaxConcurrentTasks);
end;

procedure TThreadPoolExhaustionTest.Execute;
var
  SW: TStopwatch;
  CanSubmit: Boolean;
  Work: TProc;
  Task: ITask;
begin
  SW := TStopwatch.StartNew;
  try
    // Check if we can submit more tasks
    FLock.Enter;
    try
      CanSubmit := FActiveTasks < FMaxConcurrentTasks;
      if CanSubmit then
        Inc(FActiveTasks);
    finally
      FLock.Leave;
    end;

    if CanSubmit then
    begin
      TInterlocked.Increment(FTasksSubmitted);

      // Submit task to thread pool
      Work :=
        procedure
        begin
          Sleep(10);  // Simulate work
          TInterlocked.Increment(FTasksCompleted);

          FLock.Enter;
          try
            Dec(FActiveTasks);
          finally
            FLock.Leave;
          end;
        end;
      Task := TTask.Run(Work);
    end
    else
    begin
      TInterlocked.Increment(FTaskRejections);
    end;

    SW.Stop;
    ReportLatency(SW.Elapsed.TotalMilliseconds);
    ReportSuccess;
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Thread pool test failed: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// TReadWriteLockStressTest
// ============================================================================

constructor TReadWriteLockStressTest.Create;
begin
  inherited Create('Concurrency.ReadWriteLock', 'Read-write lock stress test');
  FSharedData := TDictionary<string, Int64>.Create;
  FRWLock := TMultiReadExclusiveWriteSynchronizer.Create;
  FReadWriteRatio := 0.8;  // 80% reads, 20% writes
end;

destructor TReadWriteLockStressTest.Destroy;
begin
  FRWLock.Free;
  FSharedData.Free;
  inherited;
end;

procedure TReadWriteLockStressTest.Setup;
var
  I: Integer;
begin
  FReadsPerformed := 0;
  FWritesPerformed := 0;

  // Initialize shared data
  FRWLock.BeginWrite;
  try
    FSharedData.Clear;
    for I := 1 to 100 do
      FSharedData.Add('Key' + IntToStr(I), I);
  finally
    FRWLock.EndWrite;
  end;
end;

procedure TReadWriteLockStressTest.Teardown;
begin
  AddCustomMetric('ReadsPerformed', FReadsPerformed);
  AddCustomMetric('WritesPerformed', FWritesPerformed);
  AddCustomMetric('ReadWriteRatio', FReadWriteRatio);
  AddCustomMetric('TotalOperations', FReadsPerformed + FWritesPerformed);
end;

procedure TReadWriteLockStressTest.Execute;
var
  SW: TStopwatch;
  KeyNum: Integer;
  Key: string;
  Value: Int64;
begin
  SW := TStopwatch.StartNew;
  try
    KeyNum := Random(100) + 1;
    Key := 'Key' + IntToStr(KeyNum);

    if Random < FReadWriteRatio then
    begin
      // Read operation
      FRWLock.BeginRead;
      try
        if FSharedData.TryGetValue(Key, Value) then
          TInterlocked.Increment(FReadsPerformed);
      finally
        FRWLock.EndRead;
      end;
    end
    else
    begin
      // Write operation
      FRWLock.BeginWrite;
      try
        FSharedData.AddOrSetValue(Key, GetTickCount64);
        TInterlocked.Increment(FWritesPerformed);
      finally
        FRWLock.EndWrite;
      end;
    end;

    SW.Stop;
    ReportLatency(SW.Elapsed.TotalMilliseconds);
    ReportSuccess;
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Read-write lock failed: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// TCASSpinLockStressTest
// ============================================================================

constructor TCASSpinLockStressTest.Create;
begin
  inherited Create('Concurrency.CASSpinLock', 'Compare-and-swap spin lock test');
  FMaxSpinsPerAcquire := 10000;
end;

procedure TCASSpinLockStressTest.Setup;
begin
  FLockState := 0;
  FSpinCount := 0;
  FLockAcquisitions := 0;
  FTotalSpins := 0;
end;

procedure TCASSpinLockStressTest.Teardown;
begin
  AddCustomMetric('LockAcquisitions', FLockAcquisitions);
  AddCustomMetric('TotalSpins', FTotalSpins);
  AddCustomMetric('AvgSpinsPerAcquire',
    IfThen(FLockAcquisitions > 0,
      FTotalSpins / FLockAcquisitions, 0));
end;

procedure TCASSpinLockStressTest.SpinLock;
var
  SpinCounter: Integer;
begin
  SpinCounter := 0;
  while TInterlocked.CompareExchange(FLockState, 1, 0) <> 0 do
  begin
    Inc(SpinCounter);
    TInterlocked.Increment(FTotalSpins);

    if SpinCounter > FMaxSpinsPerAcquire then
    begin
      Sleep(0);  // Yield
      SpinCounter := 0;
    end;
  end;
  TInterlocked.Increment(FLockAcquisitions);
end;

procedure TCASSpinLockStressTest.SpinUnlock;
begin
  TInterlocked.Exchange(FLockState, 0);
end;

procedure TCASSpinLockStressTest.Execute;
var
  SW: TStopwatch;
  Counter: Integer;
begin
  SW := TStopwatch.StartNew;
  try
    SpinLock;
    try
      // Do minimal work in critical section
      Counter := 0;
      Inc(Counter);
    finally
      SpinUnlock;
    end;

    SW.Stop;
    ReportLatency(SW.Elapsed.TotalMilliseconds);
    ReportSuccess;
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Spin lock failed: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// Helper functions
// ============================================================================

function RunAllConcurrencyStressTests(DurationSec: Integer;
  ThreadCount: Integer): TStressTestReport;
var
  Runner: TStressTestRunner;
  SharedResTest: TSharedResourceStressTest;
  ContentionTest: TLockContentionStressTest;
  AtomicTest: TAtomicOperationStressTest;
  DeadlockTest: TDeadlockDetectionStressTest;
  ProdConsTest: TProducerConsumerStressTest;
  PoolTest: TThreadPoolExhaustionTest;
  RWLockTest: TReadWriteLockStressTest;
  SpinLockTest: TCASSpinLockStressTest;
begin
  Runner := TStressTestRunner.Create;
  try
    Runner.Config.DurationSec := DurationSec;
    Runner.Config.ThreadCount := ThreadCount;

    // Shared resource test
    SharedResTest := TSharedResourceStressTest.Create;
    Runner.AddTest(SharedResTest);

    // Lock contention test
    ContentionTest := TLockContentionStressTest.Create;
    ContentionTest.LockTimeoutMs := 100;
    Runner.AddTest(ContentionTest);

    // Atomic operations test
    AtomicTest := TAtomicOperationStressTest.Create;
    Runner.AddTest(AtomicTest);

    // Deadlock detection test
    DeadlockTest := TDeadlockDetectionStressTest.Create;
    DeadlockTest.TimeoutMs := 50;
    Runner.AddTest(DeadlockTest);

    // Producer-consumer test
    ProdConsTest := TProducerConsumerStressTest.Create;
    ProdConsTest.MaxQueueSize := 500;
    Runner.AddTest(ProdConsTest);

    // Thread pool test
    PoolTest := TThreadPoolExhaustionTest.Create;
    PoolTest.MaxConcurrentTasks := 30;
    Runner.AddTest(PoolTest);

    // Read-write lock test
    RWLockTest := TReadWriteLockStressTest.Create;
    RWLockTest.ReadWriteRatio := 0.85;
    Runner.AddTest(RWLockTest);

    // Spin lock test
    SpinLockTest := TCASSpinLockStressTest.Create;
    SpinLockTest.MaxSpinsPerAcquire := 5000;
    Runner.AddTest(SpinLockTest);

    Runner.Run;

    Result := Runner.Report.Clone;
  finally
    Runner.Free;
  end;
end;

function RunQuickConcurrencyCheck: TStressTestReport;
begin
  Result := RunAllConcurrencyStressTests(60, 15);
end;

end.
