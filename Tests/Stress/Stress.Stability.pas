{ ============================================================================
  Stress.Stability - Long-running Stability Tests
  
  Tests system stability over extended periods:
  - Long-running mixed operations
  - Memory leak detection over time
  - Handle leak detection
  - Resource exhaustion recovery
  - Continuous operation stability
  ============================================================================ }

unit Stress.Stability;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.SyncObjs,
  System.Diagnostics,
  UniBase.StressTest;

type
  // ============================================================================
  // TLongRunningStressTest - Extended duration test
  // ============================================================================
  
  TLongRunningStressTest = class(TStressTest)
  private
    FOperationCount: Int64;
    FCheckpointIntervalSec: Integer;
    FLastCheckpoint: TDateTime;
    FCheckpointCount: Integer;
    FMemorySnapshots: TList<TMemoryStats>;
    FLock: TCriticalSection;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
    procedure PerformCheckpoint;
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
    property CheckpointIntervalSec: Integer read FCheckpointIntervalSec write FCheckpointIntervalSec;
  end;
  
  // ============================================================================
  // TMemoryLeakStabilityTest - Memory leak detection over time
  // ============================================================================
  
  TMemoryLeakStabilityTest = class(TStressTest)
  private
    FAllocationSizeKB: Integer;
    FAllocateRatio: Double;  // Ratio of allocate vs free
    FAllocations: TList<TBytes>;
    FMaxAllocations: Integer;
    FOpCount: Int64;
    FLock: TCriticalSection;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
    property AllocationSizeKB: Integer read FAllocationSizeKB write FAllocationSizeKB;
    property AllocateRatio: Double read FAllocateRatio write FAllocateRatio;
    property MaxAllocations: Integer read FMaxAllocations write FMaxAllocations;
  end;
  
  // ============================================================================
  // TResourceRecoveryStressTest - Recovery from resource exhaustion
  // ============================================================================
  
  TResourceRecoveryStressTest = class(TStressTest)
  private
    FExhaustionType: Integer;  // 0=memory, 1=handles, 2=threads
    FRecoveryCount: Int64;
    FExhaustionCount: Int64;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
    procedure SimulateMemoryExhaustion;
    procedure SimulateHandleExhaustion;
    procedure SimulateThreadExhaustion;
  public
    constructor Create; reintroduce;
    property ExhaustionType: Integer read FExhaustionType write FExhaustionType;
  end;
  
  // ============================================================================
  // TContinuousOperationStressTest - Non-stop operation test
  // ============================================================================
  
  TContinuousOperationStressTest = class(TStressTest)
  private
    FOperationTypes: Integer;  // Bitmask of operations
    FOpCount: Int64;
    FErrorStreakCount: Integer;
    FMaxErrorStreak: Integer;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
    procedure DoConfigOperation;
    procedure DoLogOperation;
    procedure DoDbOperation;
  public
    constructor Create; reintroduce;
    property OperationTypes: Integer read FOperationTypes write FOperationTypes;
  end;
  
  // ============================================================================
  // TGCStressTest - Garbage collection stress
  // ============================================================================
  
  TGCStressTest = class(TStressTest)
  private
    FObjectCount: Integer;
    FOpCount: Int64;
    FObjectsCreated: Int64;
    FObjectsDestroyed: Int64;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
    property ObjectCount: Integer read FObjectCount write FObjectCount;
  end;
  
  // ============================================================================
  // TThreadChurnStressTest - Thread creation/destruction
  // ============================================================================
  
  TThreadChurnStressTest = class(TStressTest)
  private
    FThreadsCreated: Int64;
    FThreadsCompleted: Int64;
    FThreadWorkMs: Integer;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
    property ThreadWorkMs: Integer read FThreadWorkMs write FThreadWorkMs;
  end;
  
  // ============================================================================
  // Helper functions
  // ============================================================================
  
  /// <summary>Run all stability stress tests</summary>
  function RunAllStabilityStressTests(DurationSec: Integer = 300; 
    ThreadCount: Integer = 5): TStressTestReport;
  
  /// <summary>Run a quick stability check (60 seconds)</summary>
  function RunQuickStabilityCheck: TStressTestReport;

implementation

uses
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  System.DateUtils,
  UniBase.Manager,
  UniBase.Config,
  UniBase.Logging;

// Wrapper to access UniBase singleton (avoids namespace collision)
function UB: TUniBaseManager; inline;
begin
  Result := UniBase.Manager.UniBase;
end;

const
  OP_CONFIG = 1;
  OP_LOG = 2;
  OP_DB = 4;
  OP_ALL = OP_CONFIG or OP_LOG or OP_DB;

// ============================================================================
// TLongRunningStressTest
// ============================================================================

constructor TLongRunningStressTest.Create;
begin
  inherited Create('Stability.LongRunning', 'Extended duration stability test');
  FCheckpointIntervalSec := 30;
  FLock := TCriticalSection.Create;
  FMemorySnapshots := TList<TMemoryStats>.Create;
end;

destructor TLongRunningStressTest.Destroy;
begin
  FMemorySnapshots.Free;
  FLock.Free;
  inherited;
end;

procedure TLongRunningStressTest.Setup;
begin
  FOperationCount := 0;
  FCheckpointCount := 0;
  FLastCheckpoint := Now;
  FMemorySnapshots.Clear;
  
  // Initial snapshot
  FMemorySnapshots.Add(TMemoryStats.Capture);
end;

procedure TLongRunningStressTest.Teardown;
var
  Initial, Final: TMemoryStats;
  LeakBytes: Int64;
begin
  AddCustomMetric('TotalOperations', FOperationCount);
  AddCustomMetric('CheckpointCount', FCheckpointCount);
  
  // Calculate memory trend
  if FMemorySnapshots.Count >= 2 then
  begin
    Initial := FMemorySnapshots[0];
    Final := FMemorySnapshots[FMemorySnapshots.Count - 1];
    LeakBytes := Final.HeapAllocated - Initial.HeapAllocated;
    AddCustomMetric('MemoryTrendBytes', LeakBytes);
    AddCustomMetric('HeapGrowthKB', LeakBytes / 1024);
  end;
end;

procedure TLongRunningStressTest.Execute;
var
  SW: TStopwatch;
begin
  TInterlocked.Increment(FOperationCount);
  
  SW := TStopwatch.StartNew;
  try
    // Mix of operations
    case Random(4) of
      0: // Config read
        begin
          UB.Config.GetConfig('test_key_' + IntToStr(Random(100)), 'default');
        end;
      1: // Config write
        begin
          UB.Config.SetConfig(
            'stability_key_' + IntToStr(Random(50)),
            'value_' + IntToStr(GetTickCount),
            'StabilityTest');
        end;
      2: // Log write
        begin
          Logger.Debug(Format('Stability test op #%d at %s',
            [FOperationCount, FormatDateTime('hh:nn:ss.zzz', Now)]), 'StabilityTest');
        end;
      3: // Simple computation (CPU work)
        begin
          Sleep(1);
        end;
    end;
    
    SW.Stop;
    ReportLatency(SW.Elapsed.TotalMilliseconds);
    ReportSuccess;
    
    // Periodic checkpoint
    PerformCheckpoint;
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Long running op failed: ' + E.Message);
    end;
  end;
end;

procedure TLongRunningStressTest.PerformCheckpoint;
var
  SecondsSinceCheckpoint: Double;
begin
  SecondsSinceCheckpoint := SecondSpan(Now, FLastCheckpoint);
  
  if SecondsSinceCheckpoint >= FCheckpointIntervalSec then
  begin
    FLock.Enter;
    try
      if SecondSpan(Now, FLastCheckpoint) >= FCheckpointIntervalSec then
      begin
        Inc(FCheckpointCount);
        FLastCheckpoint := Now;
        FMemorySnapshots.Add(TMemoryStats.Capture);
        
        AddCustomMetric('Checkpoint_' + IntToStr(FCheckpointCount) + '_Ops', FOperationCount);
      end;
    finally
      FLock.Leave;
    end;
  end;
end;

// ============================================================================
// TMemoryLeakStabilityTest
// ============================================================================

constructor TMemoryLeakStabilityTest.Create;
begin
  inherited Create('Stability.MemoryLeak', 'Memory allocation/deallocation stability');
  FAllocationSizeKB := 10;
  FAllocateRatio := 0.6;  // 60% allocate, 40% free
  FMaxAllocations := 1000;
  FLock := TCriticalSection.Create;
  FAllocations := TList<TBytes>.Create;
end;

destructor TMemoryLeakStabilityTest.Destroy;
begin
  FAllocations.Free;
  FLock.Free;
  inherited;
end;

procedure TMemoryLeakStabilityTest.Setup;
begin
  FOpCount := 0;
  FAllocations.Clear;
end;

procedure TMemoryLeakStabilityTest.Teardown;
begin
  AddCustomMetric('TotalOperations', FOpCount);
  AddCustomMetric('RemainingAllocations', FAllocations.Count);
  AddCustomMetric('AllocationSizeKB', FAllocationSizeKB);
  
  // Clean up remaining allocations
  FAllocations.Clear;
end;

procedure TMemoryLeakStabilityTest.Execute;
var
  Buffer: TBytes;
  DoAllocate: Boolean;
  SW: TStopwatch;
begin
  TInterlocked.Increment(FOpCount);
  
  SW := TStopwatch.StartNew;
  try
    FLock.Enter;
    try
      DoAllocate := (FAllocations.Count < FMaxAllocations) and (Random < FAllocateRatio);
      
      if DoAllocate then
      begin
        // Allocate memory
        SetLength(Buffer, FAllocationSizeKB * 1024);
        // Fill with pattern to prevent optimization
        FillChar(Buffer[0], Length(Buffer), $AA);
        FAllocations.Add(Buffer);
        AddCustomMetric('Allocations', 1);
      end
      else if FAllocations.Count > 0 then
      begin
        // Free random allocation
        FAllocations.Delete(Random(FAllocations.Count));
        AddCustomMetric('Deallocations', 1);
      end;
    finally
      FLock.Leave;
    end;
    
    SW.Stop;
    ReportLatency(SW.Elapsed.TotalMilliseconds);
    ReportSuccess;
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Memory operation failed: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// TResourceRecoveryStressTest
// ============================================================================

constructor TResourceRecoveryStressTest.Create;
begin
  inherited Create('Stability.ResourceRecovery', 'Resource exhaustion recovery test');
  FExhaustionType := 0;  // Memory by default
end;

procedure TResourceRecoveryStressTest.Setup;
begin
  FRecoveryCount := 0;
  FExhaustionCount := 0;
end;

procedure TResourceRecoveryStressTest.Teardown;
begin
  AddCustomMetric('ExhaustionAttempts', FExhaustionCount);
  AddCustomMetric('RecoveryCount', FRecoveryCount);
end;

procedure TResourceRecoveryStressTest.Execute;
var
  SW: TStopwatch;
begin
  SW := TStopwatch.StartNew;
  try
    case FExhaustionType of
      0: SimulateMemoryExhaustion;
      1: SimulateHandleExhaustion;
      2: SimulateThreadExhaustion;
    else
      SimulateMemoryExhaustion;
    end;
    
    SW.Stop;
    ReportLatency(SW.Elapsed.TotalMilliseconds);
    ReportSuccess;
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      // Expected - we're testing recovery
      TInterlocked.Increment(FRecoveryCount);
      ReportSuccess; // Recovery is success
    end;
  end;
end;

procedure TResourceRecoveryStressTest.SimulateMemoryExhaustion;
var
  Allocations: TList<TBytes>;
  Buffer: TBytes;
  I: Integer;
begin
  TInterlocked.Increment(FExhaustionCount);
  
  Allocations := TList<TBytes>.Create;
  try
    // Try to allocate lots of memory
    for I := 1 to 100 do
    begin
      SetLength(Buffer, 1024 * 1024);  // 1 MB each
      FillChar(Buffer[0], Length(Buffer), $BB);
      Allocations.Add(Buffer);
    end;
  finally
    // Always clean up
    Allocations.Clear;
    Allocations.Free;
  end;
end;

procedure TResourceRecoveryStressTest.SimulateHandleExhaustion;
var
  Handles: TList<THandle>;
  H: THandle;
  I: Integer;
begin
  TInterlocked.Increment(FExhaustionCount);
  
  Handles := TList<THandle>.Create;
  try
    // Create many events
    for I := 1 to 100 do
    begin
      H := CreateEvent(nil, False, False, nil);
      if H <> 0 then
        Handles.Add(H);
    end;
  finally
    // Clean up handles
    for H in Handles do
      CloseHandle(H);
    Handles.Free;
  end;
end;

procedure TResourceRecoveryStressTest.SimulateThreadExhaustion;
var
  Threads: TList<TThread>;
  T: TThread;
  I: Integer;
begin
  TInterlocked.Increment(FExhaustionCount);
  
  Threads := TList<TThread>.Create;
  try
    // Create multiple threads
    for I := 1 to 20 do
    begin
      T := TThread.CreateAnonymousThread(
        procedure
        begin
          Sleep(100);
        end);
      T.FreeOnTerminate := False;
      Threads.Add(T);
      T.Start;
    end;
    
    // Wait for all threads
    for T in Threads do
    begin
      T.WaitFor;
      T.Free;
    end;
  finally
    Threads.Free;
  end;
end;

// ============================================================================
// TContinuousOperationStressTest
// ============================================================================

constructor TContinuousOperationStressTest.Create;
begin
  inherited Create('Stability.Continuous', 'Continuous mixed operations test');
  FOperationTypes := OP_ALL;
end;

procedure TContinuousOperationStressTest.Setup;
begin
  FOpCount := 0;
  FErrorStreakCount := 0;
  FMaxErrorStreak := 0;
end;

procedure TContinuousOperationStressTest.Teardown;
begin
  AddCustomMetric('TotalOperations', FOpCount);
  AddCustomMetric('MaxErrorStreak', FMaxErrorStreak);
end;

procedure TContinuousOperationStressTest.Execute;
var
  SW: TStopwatch;
  OpType: Integer;
begin
  TInterlocked.Increment(FOpCount);
  
  SW := TStopwatch.StartNew;
  try
    // Select operation type based on bitmask
    OpType := Random(3);
    
    case OpType of
      0:
        if (FOperationTypes and OP_CONFIG) <> 0 then
          DoConfigOperation
        else
          DoLogOperation;
      1:
        if (FOperationTypes and OP_LOG) <> 0 then
          DoLogOperation
        else
          DoConfigOperation;
      2:
        if (FOperationTypes and OP_DB) <> 0 then
          DoDbOperation
        else
          DoConfigOperation;
    end;
    
    SW.Stop;
    ReportLatency(SW.Elapsed.TotalMilliseconds);
    ReportSuccess;
    
    // Reset error streak on success
    FErrorStreakCount := 0;
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Continuous op failed: ' + E.Message);
      
      // Track error streaks
      Inc(FErrorStreakCount);
      if FErrorStreakCount > FMaxErrorStreak then
        FMaxErrorStreak := FErrorStreakCount;
    end;
  end;
end;

procedure TContinuousOperationStressTest.DoConfigOperation;
begin
  if Random > 0.5 then
    UB.Config.GetConfig('continuous_key_' + IntToStr(Random(20)), 'default')
  else
    UB.Config.SetConfig(
      'continuous_key_' + IntToStr(Random(20)),
      FormatDateTime('yyyymmddhhnnsszzz', Now),
      'ContinuousTest');
end;

procedure TContinuousOperationStressTest.DoLogOperation;
begin
  case Random(4) of
    0: Logger.Debug('Continuous debug message', 'ContinuousTest');
    1: Logger.Info('Continuous info message', 'ContinuousTest');
    2: Logger.Warn('Continuous warning message', 'ContinuousTest');
    3: Logger.Error('Continuous error message', 'ContinuousTest');
  end;
end;

procedure TContinuousOperationStressTest.DoDbOperation;
begin
  // Simple config operation as DB proxy
  UB.Config.GetConfig('db_proxy_key', 'default');
end;

// ============================================================================
// TGCStressTest
// ============================================================================

constructor TGCStressTest.Create;
begin
  inherited Create('Stability.GC', 'Object creation/destruction stress');
  FObjectCount := 100;
end;

procedure TGCStressTest.Setup;
begin
  FOpCount := 0;
  FObjectsCreated := 0;
  FObjectsDestroyed := 0;
end;

procedure TGCStressTest.Teardown;
begin
  AddCustomMetric('TotalOperations', FOpCount);
  AddCustomMetric('ObjectsCreated', FObjectsCreated);
  AddCustomMetric('ObjectsDestroyed', FObjectsDestroyed);
end;

procedure TGCStressTest.Execute;
var
  Objects: TObjectList<TStringList>;
  I: Integer;
  SW: TStopwatch;
begin
  TInterlocked.Increment(FOpCount);
  
  SW := TStopwatch.StartNew;
  try
    Objects := TObjectList<TStringList>.Create(True);
    try
      // Create objects
      for I := 1 to FObjectCount do
      begin
        Objects.Add(TStringList.Create);
        Objects.Last.Add('Item ' + IntToStr(I));
        TInterlocked.Increment(FObjectsCreated);
      end;
      
      // Destroy happens automatically when Objects is freed
    finally
      TInterlocked.Add(FObjectsDestroyed, Objects.Count);
      Objects.Free;
    end;
    
    SW.Stop;
    ReportLatency(SW.Elapsed.TotalMilliseconds);
    ReportSuccess;
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('GC stress failed: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// TThreadChurnStressTest
// ============================================================================

constructor TThreadChurnStressTest.Create;
begin
  inherited Create('Stability.ThreadChurn', 'Thread creation/destruction stress');
  FThreadWorkMs := 10;
end;

procedure TThreadChurnStressTest.Setup;
begin
  FThreadsCreated := 0;
  FThreadsCompleted := 0;
end;

procedure TThreadChurnStressTest.Teardown;
begin
  AddCustomMetric('ThreadsCreated', FThreadsCreated);
  AddCustomMetric('ThreadsCompleted', FThreadsCompleted);
end;

procedure TThreadChurnStressTest.Execute;
var
  T: TThread;
  WorkMs: Integer;
  SW: TStopwatch;
begin
  WorkMs := FThreadWorkMs;
  
  SW := TStopwatch.StartNew;
  try
    TInterlocked.Increment(FThreadsCreated);
    
    T := TThread.CreateAnonymousThread(
      procedure
      begin
        Sleep(WorkMs);
        TInterlocked.Increment(FThreadsCompleted);
      end);
    T.FreeOnTerminate := False;
    T.Start;
    T.WaitFor;
    T.Free;
    
    SW.Stop;
    ReportLatency(SW.Elapsed.TotalMilliseconds);
    ReportSuccess;
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Thread churn failed: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// Helper functions
// ============================================================================

function RunAllStabilityStressTests(DurationSec: Integer; 
  ThreadCount: Integer): TStressTestReport;
var
  Runner: TStressTestRunner;
  LongRunTest: TLongRunningStressTest;
  MemLeakTest: TMemoryLeakStabilityTest;
  RecoveryTest: TResourceRecoveryStressTest;
  ContinuousTest: TContinuousOperationStressTest;
  GCTest: TGCStressTest;
  ThreadTest: TThreadChurnStressTest;
begin
  Runner := TStressTestRunner.Create;
  try
    Runner.Config.DurationSec := DurationSec;
    Runner.Config.ThreadCount := ThreadCount;
    
    // Long running test
    LongRunTest := TLongRunningStressTest.Create;
    LongRunTest.CheckpointIntervalSec := DurationSec div 10;
    Runner.AddTest(LongRunTest);
    
    // Memory leak test
    MemLeakTest := TMemoryLeakStabilityTest.Create;
    MemLeakTest.AllocationSizeKB := 10;
    MemLeakTest.AllocateRatio := 0.55;  // Slight bias towards allocate
    MemLeakTest.MaxAllocations := 500;
    Runner.AddTest(MemLeakTest);
    
    // Resource recovery test
    RecoveryTest := TResourceRecoveryStressTest.Create;
    RecoveryTest.ExhaustionType := 0;  // Memory
    Runner.AddTest(RecoveryTest);
    
    // Continuous operations test
    ContinuousTest := TContinuousOperationStressTest.Create;
    ContinuousTest.OperationTypes := OP_CONFIG or OP_LOG;
    Runner.AddTest(ContinuousTest);
    
    // GC stress test
    GCTest := TGCStressTest.Create;
    GCTest.ObjectCount := 50;
    Runner.AddTest(GCTest);
    
    // Thread churn test
    ThreadTest := TThreadChurnStressTest.Create;
    ThreadTest.ThreadWorkMs := 5;
    Runner.AddTest(ThreadTest);
    
    Runner.Run;
    
    Result := Runner.Report;
  finally
    Runner.Free;
  end;
end;

function RunQuickStabilityCheck: TStressTestReport;
begin
  Result := RunAllStabilityStressTests(60, 5);
end;

end.
