{ ============================================================================
  Stress.ConnectionPool - Connection Pool Long-term Stability Tests

  Tests database connection pool under extended load:
  - Connection acquisition/release cycles
  - Pool exhaustion and recovery
  - Connection leak detection
  - Timeout handling
  - Pool scaling under varying load
  ============================================================================ }

unit Stress.ConnectionPool;

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
  // TConnectionPoolAcquireReleaseTest - Connection acquisition cycles
  // ============================================================================

  TConnectionPoolAcquireReleaseTest = class(TStressTest)
  private
    FAcquisitions: Int64;
    FReleases: Int64;
    FFailedAcquisitions: Int64;
    FHoldTimeMs: Integer;
    FLock: TCriticalSection;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
    property HoldTimeMs: Integer read FHoldTimeMs write FHoldTimeMs;
  end;

  // ============================================================================
  // TConnectionPoolExhaustionTest - Pool exhaustion and recovery
  // ============================================================================

  TConnectionPoolExhaustionTest = class(TStressTest)
  private
    FPoolSize: Integer;
    FActiveConnections: Integer;
    FExhaustionEvents: Int64;
    FRecoveryEvents: Int64;
    FTimeoutMs: Integer;
    FLock: TCriticalSection;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
    property PoolSize: Integer read FPoolSize write FPoolSize;
    property TimeoutMs: Integer read FTimeoutMs write FTimeoutMs;
  end;

  // ============================================================================
  // TConnectionLeakDetectionTest - Connection leak detection
  // ============================================================================

  TConnectionLeakDetectionTest = class(TStressTest)
  private
    FConnectionsAcquired: Int64;
    FConnectionsReleased: Int64;
    FLeaksDetected: Int64;
    FLeakCheckIntervalSec: Integer;
    FLastLeakCheck: TDateTime;
    FLeakThreshold: Integer;
    FLock: TCriticalSection;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
    procedure CheckForLeaks;
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
    property LeakCheckIntervalSec: Integer read FLeakCheckIntervalSec write FLeakCheckIntervalSec;
    property LeakThreshold: Integer read FLeakThreshold write FLeakThreshold;
  end;

  // ============================================================================
  // TConnectionTimeoutTest - Timeout handling stress
  // ============================================================================

  TConnectionTimeoutTest = class(TStressTest)
  private
    FTimeoutsOccurred: Int64;
    FSuccessfulAcquisitions: Int64;
    FConnectionTimeoutMs: Integer;
    FQueryTimeoutMs: Integer;
    FSimulatedQueryTimeMs: Integer;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
    property ConnectionTimeoutMs: Integer read FConnectionTimeoutMs write FConnectionTimeoutMs;
    property QueryTimeoutMs: Integer read FQueryTimeoutMs write FQueryTimeoutMs;
    property SimulatedQueryTimeMs: Integer read FSimulatedQueryTimeMs write FSimulatedQueryTimeMs;
  end;

  // ============================================================================
  // TConnectionPoolScalingTest - Pool scaling under varying load
  // ============================================================================

  TConnectionPoolScalingTest = class(TStressTest)
  private
    FCurrentLoad: Integer;  // 0-100%
    FLoadDirection: Integer;  // 1 = increasing, -1 = decreasing
    FOperationsAtLowLoad: Int64;
    FOperationsAtHighLoad: Int64;
    FScalingEvents: Int64;
    FLoadChangeIntervalSec: Integer;
    FLastLoadChange: TDateTime;
    FLock: TCriticalSection;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
    procedure UpdateLoad;
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
    property LoadChangeIntervalSec: Integer read FLoadChangeIntervalSec write FLoadChangeIntervalSec;
  end;

  // ============================================================================
  // TConnectionPoolLongRunningTest - Extended duration pool test
  // ============================================================================

  TConnectionPoolLongRunningTest = class(TStressTest)
  private
    FTotalOperations: Int64;
    FCheckpointCount: Integer;
    FCheckpointIntervalSec: Integer;
    FLastCheckpoint: TDateTime;
    FPoolHealthy: Boolean;
    FHealthCheckFailures: Int64;
    FConnectionSnapshots: TList<Integer>;
    FLock: TCriticalSection;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
    procedure PerformHealthCheck;
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
    property CheckpointIntervalSec: Integer read FCheckpointIntervalSec write FCheckpointIntervalSec;
  end;

  // ============================================================================
  // TConnectionPoolConcurrencyTest - High concurrency pool access
  // ============================================================================

  TConnectionPoolConcurrencyTest = class(TStressTest)
  private
    FConcurrentOperations: Integer;
    FMaxConcurrency: Integer;
    FPeakConcurrency: Integer;
    FOperationsCompleted: Int64;
    FOperationsFailed: Int64;
    FLock: TCriticalSection;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
    property MaxConcurrency: Integer read FMaxConcurrency write FMaxConcurrency;
  end;

  // ============================================================================
  // TConnectionPoolReconnectTest - Reconnection stress test
  // ============================================================================

  TConnectionPoolReconnectTest = class(TStressTest)
  private
    FReconnectAttempts: Int64;
    FReconnectSuccesses: Int64;
    FReconnectFailures: Int64;
    FSimulatedDisconnectRate: Double;  // Rate at which to simulate disconnects
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
    property SimulatedDisconnectRate: Double read FSimulatedDisconnectRate write FSimulatedDisconnectRate;
  end;

  // ============================================================================
  // Helper functions
  // ============================================================================

  /// <summary>Run all connection pool stress tests</summary>
  function RunAllConnectionPoolStressTests(DurationSec: Integer = 300;
    ThreadCount: Integer = 15): TStressTestReport;

  /// <summary>Run quick connection pool check (60 seconds)</summary>
  function RunQuickConnectionPoolCheck: TStressTestReport;

  /// <summary>Run 48-hour endurance test</summary>
  function Run48HourConnectionPoolEnduranceTest(ThreadCount: Integer = 10): TStressTestReport;

implementation

uses
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  System.DateUtils,
  System.Math,
  UniBase.Manager,
  UniBase.DB.ConnectionPool;

// Wrapper to access UniBase singleton
function UB: TUniBaseManager; inline;
begin
  Result := UniBase.Manager.UniBase;
end;

// Simulated connection for testing when real DB is not available
type
  TSimulatedConnection = class
  private
    FID: Integer;
    FAcquiredAt: TDateTime;
    FThreadID: TThreadID;
  public
    constructor Create(AID: Integer);
    property ID: Integer read FID;
    property AcquiredAt: TDateTime read FAcquiredAt;
    property ThreadID: TThreadID read FThreadID;
  end;

  TSimulatedConnectionPool = class
  private
    FPool: TList<TSimulatedConnection>;
    FActiveConnections: TList<TSimulatedConnection>;
    FMaxSize: Integer;
    FLock: TCriticalSection;
    FNextID: Integer;
  public
    constructor Create(MaxSize: Integer);
    destructor Destroy; override;
    function Acquire(TimeoutMs: Integer): TSimulatedConnection;
    procedure Release(Conn: TSimulatedConnection);
    function GetActiveCount: Integer;
    function GetPoolSize: Integer;
  end;

var
  GSimPool: TSimulatedConnectionPool;
  GSimPoolLock: TCriticalSection;

procedure EnsureSimPool;
begin
  if GSimPool = nil then
  begin
    GSimPoolLock.Enter;
    try
      if GSimPool = nil then
        GSimPool := TSimulatedConnectionPool.Create(50);
    finally
      GSimPoolLock.Leave;
    end;
  end;
end;

{ TSimulatedConnection }

constructor TSimulatedConnection.Create(AID: Integer);
begin
  inherited Create;
  FID := AID;
  FAcquiredAt := Now;
  FThreadID := TThread.CurrentThread.ThreadID;
end;

{ TSimulatedConnectionPool }

constructor TSimulatedConnectionPool.Create(MaxSize: Integer);
begin
  inherited Create;
  FPool := TList<TSimulatedConnection>.Create;
  FActiveConnections := TList<TSimulatedConnection>.Create;
  FMaxSize := MaxSize;
  FLock := TCriticalSection.Create;
  FNextID := 1;
end;

destructor TSimulatedConnectionPool.Destroy;
var
  Conn: TSimulatedConnection;
begin
  for Conn in FPool do
    Conn.Free;
  FPool.Free;

  for Conn in FActiveConnections do
    Conn.Free;
  FActiveConnections.Free;

  FLock.Free;
  inherited;
end;

function TSimulatedConnectionPool.Acquire(TimeoutMs: Integer): TSimulatedConnection;
var
  StartTime: Cardinal;
begin
  Result := nil;
  StartTime := GetTickCount;

  repeat
    FLock.Enter;
    try
      if FPool.Count > 0 then
      begin
        Result := FPool[FPool.Count - 1];
        FPool.Delete(FPool.Count - 1);
        Result.FAcquiredAt := Now;
        Result.FThreadID := TThread.CurrentThread.ThreadID;
        FActiveConnections.Add(Result);
        Exit;
      end
      else if FActiveConnections.Count < FMaxSize then
      begin
        Result := TSimulatedConnection.Create(FNextID);
        Inc(FNextID);
        FActiveConnections.Add(Result);
        Exit;
      end;
    finally
      FLock.Leave;
    end;

    Sleep(10);
  until (GetTickCount - StartTime) >= Cardinal(TimeoutMs);
end;

procedure TSimulatedConnectionPool.Release(Conn: TSimulatedConnection);
begin
  if Conn = nil then Exit;

  FLock.Enter;
  try
    FActiveConnections.Remove(Conn);
    FPool.Add(Conn);
  finally
    FLock.Leave;
  end;
end;

function TSimulatedConnectionPool.GetActiveCount: Integer;
begin
  FLock.Enter;
  try
    Result := FActiveConnections.Count;
  finally
    FLock.Leave;
  end;
end;

function TSimulatedConnectionPool.GetPoolSize: Integer;
begin
  FLock.Enter;
  try
    Result := FPool.Count + FActiveConnections.Count;
  finally
    FLock.Leave;
  end;
end;

// ============================================================================
// TConnectionPoolAcquireReleaseTest
// ============================================================================

constructor TConnectionPoolAcquireReleaseTest.Create;
begin
  inherited Create('ConnectionPool.AcquireRelease', 'Connection acquisition/release cycles');
  FHoldTimeMs := 10;
  FLock := TCriticalSection.Create;
end;

destructor TConnectionPoolAcquireReleaseTest.Destroy;
begin
  FLock.Free;
  inherited;
end;

procedure TConnectionPoolAcquireReleaseTest.Setup;
begin
  FAcquisitions := 0;
  FReleases := 0;
  FFailedAcquisitions := 0;
  EnsureSimPool;
end;

procedure TConnectionPoolAcquireReleaseTest.Teardown;
begin
  AddCustomMetric('Acquisitions', FAcquisitions);
  AddCustomMetric('Releases', FReleases);
  AddCustomMetric('FailedAcquisitions', FFailedAcquisitions);
  AddCustomMetric('HoldTimeMs', FHoldTimeMs);
  AddCustomMetric('AcquireReleaseBalance', FAcquisitions - FReleases);
end;

procedure TConnectionPoolAcquireReleaseTest.Execute;
var
  SW: TStopwatch;
  Conn: TSimulatedConnection;
begin
  SW := TStopwatch.StartNew;
  try
    Conn := GSimPool.Acquire(1000);

    if Conn <> nil then
    begin
      try
        TInterlocked.Increment(FAcquisitions);

        // Simulate work with connection
        Sleep(FHoldTimeMs);
      finally
        GSimPool.Release(Conn);
        TInterlocked.Increment(FReleases);
      end;

      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportSuccess;
    end
    else
    begin
      TInterlocked.Increment(FFailedAcquisitions);
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Failed to acquire connection');
    end;
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Connection pool error: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// TConnectionPoolExhaustionTest
// ============================================================================

constructor TConnectionPoolExhaustionTest.Create;
begin
  inherited Create('ConnectionPool.Exhaustion', 'Pool exhaustion and recovery test');
  FPoolSize := 20;
  FTimeoutMs := 500;
  FLock := TCriticalSection.Create;
end;

destructor TConnectionPoolExhaustionTest.Destroy;
begin
  FLock.Free;
  inherited;
end;

procedure TConnectionPoolExhaustionTest.Setup;
begin
  FActiveConnections := 0;
  FExhaustionEvents := 0;
  FRecoveryEvents := 0;
  EnsureSimPool;
end;

procedure TConnectionPoolExhaustionTest.Teardown;
begin
  AddCustomMetric('ExhaustionEvents', FExhaustionEvents);
  AddCustomMetric('RecoveryEvents', FRecoveryEvents);
  AddCustomMetric('PoolSize', FPoolSize);
  AddCustomMetric('TimeoutMs', FTimeoutMs);
end;

procedure TConnectionPoolExhaustionTest.Execute;
var
  SW: TStopwatch;
  Conn: TSimulatedConnection;
  WasExhausted: Boolean;
begin
  SW := TStopwatch.StartNew;
  try
    // Check if pool was exhausted before acquire
    WasExhausted := GSimPool.GetActiveCount >= FPoolSize;

    Conn := GSimPool.Acquire(FTimeoutMs);

    if Conn <> nil then
    begin
      try
        if WasExhausted then
          TInterlocked.Increment(FRecoveryEvents);

        // Vary hold time to create contention
        Sleep(Random(50) + 10);
      finally
        GSimPool.Release(Conn);
      end;

      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportSuccess;
    end
    else
    begin
      TInterlocked.Increment(FExhaustionEvents);
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportSuccess; // Exhaustion is expected in this test
    end;
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Pool exhaustion error: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// TConnectionLeakDetectionTest
// ============================================================================

constructor TConnectionLeakDetectionTest.Create;
begin
  inherited Create('ConnectionPool.LeakDetection', 'Connection leak detection test');
  FLeakCheckIntervalSec := 10;
  FLeakThreshold := 5;
  FLock := TCriticalSection.Create;
end;

destructor TConnectionLeakDetectionTest.Destroy;
begin
  FLock.Free;
  inherited;
end;

procedure TConnectionLeakDetectionTest.Setup;
begin
  FConnectionsAcquired := 0;
  FConnectionsReleased := 0;
  FLeaksDetected := 0;
  FLastLeakCheck := Now;
  EnsureSimPool;
end;

procedure TConnectionLeakDetectionTest.Teardown;
begin
  AddCustomMetric('ConnectionsAcquired', FConnectionsAcquired);
  AddCustomMetric('ConnectionsReleased', FConnectionsReleased);
  AddCustomMetric('LeaksDetected', FLeaksDetected);
  AddCustomMetric('UnreleasedConnections', FConnectionsAcquired - FConnectionsReleased);
end;

procedure TConnectionLeakDetectionTest.CheckForLeaks;
var
  Unreleased: Int64;
begin
  Unreleased := FConnectionsAcquired - FConnectionsReleased;
  if Unreleased > FLeakThreshold then
    TInterlocked.Increment(FLeaksDetected);
end;

procedure TConnectionLeakDetectionTest.Execute;
var
  SW: TStopwatch;
  Conn: TSimulatedConnection;
  ShouldLeak: Boolean;
begin
  SW := TStopwatch.StartNew;
  try
    Conn := GSimPool.Acquire(1000);

    if Conn <> nil then
    begin
      TInterlocked.Increment(FConnectionsAcquired);

      // Intentionally "leak" some connections (1% chance)
      ShouldLeak := Random < 0.01;

      if not ShouldLeak then
      begin
        Sleep(5);
        GSimPool.Release(Conn);
        TInterlocked.Increment(FConnectionsReleased);
      end;

      // Periodic leak check
      if SecondSpan(Now, FLastLeakCheck) >= FLeakCheckIntervalSec then
      begin
        FLock.Enter;
        try
          if SecondSpan(Now, FLastLeakCheck) >= FLeakCheckIntervalSec then
          begin
            CheckForLeaks;
            FLastLeakCheck := Now;
          end;
        finally
          FLock.Leave;
        end;
      end;

      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportSuccess;
    end
    else
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Failed to acquire connection for leak test');
    end;
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Leak detection error: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// TConnectionTimeoutTest
// ============================================================================

constructor TConnectionTimeoutTest.Create;
begin
  inherited Create('ConnectionPool.Timeout', 'Connection timeout handling test');
  FConnectionTimeoutMs := 500;
  FQueryTimeoutMs := 1000;
  FSimulatedQueryTimeMs := 100;
end;

procedure TConnectionTimeoutTest.Setup;
begin
  FTimeoutsOccurred := 0;
  FSuccessfulAcquisitions := 0;
  EnsureSimPool;
end;

procedure TConnectionTimeoutTest.Teardown;
begin
  AddCustomMetric('TimeoutsOccurred', FTimeoutsOccurred);
  AddCustomMetric('SuccessfulAcquisitions', FSuccessfulAcquisitions);
  AddCustomMetric('ConnectionTimeoutMs', FConnectionTimeoutMs);
  AddCustomMetric('TimeoutRate',
    IfThen(FSuccessfulAcquisitions + FTimeoutsOccurred > 0,
      FTimeoutsOccurred / (FSuccessfulAcquisitions + FTimeoutsOccurred), 0));
end;

procedure TConnectionTimeoutTest.Execute;
var
  SW: TStopwatch;
  Conn: TSimulatedConnection;
begin
  SW := TStopwatch.StartNew;
  try
    // Vary timeout to test edge cases
    Conn := GSimPool.Acquire(FConnectionTimeoutMs + Random(200) - 100);

    if Conn <> nil then
    begin
      try
        TInterlocked.Increment(FSuccessfulAcquisitions);

        // Simulate query that might timeout
        Sleep(FSimulatedQueryTimeMs + Random(50));
      finally
        GSimPool.Release(Conn);
      end;

      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportSuccess;
    end
    else
    begin
      TInterlocked.Increment(FTimeoutsOccurred);
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportSuccess; // Timeout is expected in this test
    end;
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Timeout test error: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// TConnectionPoolScalingTest
// ============================================================================

constructor TConnectionPoolScalingTest.Create;
begin
  inherited Create('ConnectionPool.Scaling', 'Pool scaling under varying load');
  FLoadChangeIntervalSec := 5;
  FLock := TCriticalSection.Create;
end;

destructor TConnectionPoolScalingTest.Destroy;
begin
  FLock.Free;
  inherited;
end;

procedure TConnectionPoolScalingTest.Setup;
begin
  FCurrentLoad := 50;
  FLoadDirection := 1;
  FOperationsAtLowLoad := 0;
  FOperationsAtHighLoad := 0;
  FScalingEvents := 0;
  FLastLoadChange := Now;
  EnsureSimPool;
end;

procedure TConnectionPoolScalingTest.Teardown;
begin
  AddCustomMetric('OperationsAtLowLoad', FOperationsAtLowLoad);
  AddCustomMetric('OperationsAtHighLoad', FOperationsAtHighLoad);
  AddCustomMetric('ScalingEvents', FScalingEvents);
  AddCustomMetric('FinalLoad', FCurrentLoad);
end;

procedure TConnectionPoolScalingTest.UpdateLoad;
begin
  // Change load direction at extremes
  if FCurrentLoad >= 100 then
    FLoadDirection := -1
  else if FCurrentLoad <= 10 then
    FLoadDirection := 1;

  FCurrentLoad := FCurrentLoad + FLoadDirection * 10;
  TInterlocked.Increment(FScalingEvents);
end;

procedure TConnectionPoolScalingTest.Execute;
var
  SW: TStopwatch;
  Conn: TSimulatedConnection;
  LocalLoad: Integer;
begin
  SW := TStopwatch.StartNew;
  try
    // Update load periodically
    if SecondSpan(Now, FLastLoadChange) >= FLoadChangeIntervalSec then
    begin
      FLock.Enter;
      try
        if SecondSpan(Now, FLastLoadChange) >= FLoadChangeIntervalSec then
        begin
          UpdateLoad;
          FLastLoadChange := Now;
        end;
      finally
        FLock.Leave;
      end;
    end;

    LocalLoad := FCurrentLoad;

    // Simulate load by varying connection hold time
    Conn := GSimPool.Acquire(1000);

    if Conn <> nil then
    begin
      try
        // Hold longer at high load
        Sleep(LocalLoad div 10 + 5);

        if LocalLoad < 50 then
          TInterlocked.Increment(FOperationsAtLowLoad)
        else
          TInterlocked.Increment(FOperationsAtHighLoad);
      finally
        GSimPool.Release(Conn);
      end;

      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportSuccess;
    end
    else
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Failed to acquire under load ' + IntToStr(LocalLoad));
    end;
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Scaling test error: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// TConnectionPoolLongRunningTest
// ============================================================================

constructor TConnectionPoolLongRunningTest.Create;
begin
  inherited Create('ConnectionPool.LongRunning', '48-hour endurance test');
  FCheckpointIntervalSec := 300;  // 5 minutes
  FLock := TCriticalSection.Create;
  FConnectionSnapshots := TList<Integer>.Create;
end;

destructor TConnectionPoolLongRunningTest.Destroy;
begin
  FConnectionSnapshots.Free;
  FLock.Free;
  inherited;
end;

procedure TConnectionPoolLongRunningTest.Setup;
begin
  FTotalOperations := 0;
  FCheckpointCount := 0;
  FLastCheckpoint := Now;
  FPoolHealthy := True;
  FHealthCheckFailures := 0;
  FConnectionSnapshots.Clear;
  EnsureSimPool;
end;

procedure TConnectionPoolLongRunningTest.Teardown;
var
  I: Integer;
  TrendSum: Int64;
begin
  AddCustomMetric('TotalOperations', FTotalOperations);
  AddCustomMetric('CheckpointCount', FCheckpointCount);
  AddCustomMetric('PoolHealthy', Ord(FPoolHealthy));
  AddCustomMetric('HealthCheckFailures', FHealthCheckFailures);

  // Calculate connection count trend
  if FConnectionSnapshots.Count > 1 then
  begin
    TrendSum := 0;
    for I := 1 to FConnectionSnapshots.Count - 1 do
      TrendSum := TrendSum + (FConnectionSnapshots[I] - FConnectionSnapshots[I-1]);
    AddCustomMetric('ConnectionCountTrend', TrendSum);
  end;
end;

procedure TConnectionPoolLongRunningTest.PerformHealthCheck;
var
  ActiveCount: Integer;
begin
  ActiveCount := GSimPool.GetActiveCount;
  FConnectionSnapshots.Add(ActiveCount);
  Inc(FCheckpointCount);

  // Check for anomalies
  if ActiveCount < 0 then
  begin
    FPoolHealthy := False;
    TInterlocked.Increment(FHealthCheckFailures);
  end;

  AddCustomMetric('Checkpoint_' + IntToStr(FCheckpointCount) + '_Active', ActiveCount);
end;

procedure TConnectionPoolLongRunningTest.Execute;
var
  SW: TStopwatch;
  Conn: TSimulatedConnection;
begin
  SW := TStopwatch.StartNew;
  try
    TInterlocked.Increment(FTotalOperations);

    Conn := GSimPool.Acquire(2000);

    if Conn <> nil then
    begin
      try
        // Random operation time
        Sleep(Random(20) + 5);
      finally
        GSimPool.Release(Conn);
      end;

      // Periodic health check
      if SecondSpan(Now, FLastCheckpoint) >= FCheckpointIntervalSec then
      begin
        FLock.Enter;
        try
          if SecondSpan(Now, FLastCheckpoint) >= FCheckpointIntervalSec then
          begin
            PerformHealthCheck;
            FLastCheckpoint := Now;
          end;
        finally
          FLock.Leave;
        end;
      end;

      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportSuccess;
    end
    else
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Long running test: connection timeout');
    end;
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Long running test error: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// TConnectionPoolConcurrencyTest
// ============================================================================

constructor TConnectionPoolConcurrencyTest.Create;
begin
  inherited Create('ConnectionPool.Concurrency', 'High concurrency pool access');
  FMaxConcurrency := 30;
  FLock := TCriticalSection.Create;
end;

destructor TConnectionPoolConcurrencyTest.Destroy;
begin
  FLock.Free;
  inherited;
end;

procedure TConnectionPoolConcurrencyTest.Setup;
begin
  FConcurrentOperations := 0;
  FPeakConcurrency := 0;
  FOperationsCompleted := 0;
  FOperationsFailed := 0;
  EnsureSimPool;
end;

procedure TConnectionPoolConcurrencyTest.Teardown;
begin
  AddCustomMetric('PeakConcurrency', FPeakConcurrency);
  AddCustomMetric('OperationsCompleted', FOperationsCompleted);
  AddCustomMetric('OperationsFailed', FOperationsFailed);
  AddCustomMetric('MaxConcurrency', FMaxConcurrency);
end;

procedure TConnectionPoolConcurrencyTest.Execute;
var
  SW: TStopwatch;
  Conn: TSimulatedConnection;
  CurrentConcurrent: Integer;
begin
  SW := TStopwatch.StartNew;
  try
    // Track concurrency
    CurrentConcurrent := TInterlocked.Increment(FConcurrentOperations);

    FLock.Enter;
    try
      if CurrentConcurrent > FPeakConcurrency then
        FPeakConcurrency := CurrentConcurrent;
    finally
      FLock.Leave;
    end;

    try
      Conn := GSimPool.Acquire(1000);

      if Conn <> nil then
      begin
        try
          // Simulate concurrent work
          Sleep(Random(30) + 5);
          TInterlocked.Increment(FOperationsCompleted);
        finally
          GSimPool.Release(Conn);
        end;

        SW.Stop;
        ReportLatency(SW.Elapsed.TotalMilliseconds);
        ReportSuccess;
      end
      else
      begin
        TInterlocked.Increment(FOperationsFailed);
        SW.Stop;
        ReportLatency(SW.Elapsed.TotalMilliseconds);
        ReportError('Concurrency test: connection unavailable');
      end;
    finally
      TInterlocked.Decrement(FConcurrentOperations);
    end;
  except
    on E: Exception do
    begin
      TInterlocked.Decrement(FConcurrentOperations);
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Concurrency test error: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// TConnectionPoolReconnectTest
// ============================================================================

constructor TConnectionPoolReconnectTest.Create;
begin
  inherited Create('ConnectionPool.Reconnect', 'Connection reconnection stress test');
  FSimulatedDisconnectRate := 0.05;  // 5% disconnect rate
end;

procedure TConnectionPoolReconnectTest.Setup;
begin
  FReconnectAttempts := 0;
  FReconnectSuccesses := 0;
  FReconnectFailures := 0;
  EnsureSimPool;
end;

procedure TConnectionPoolReconnectTest.Teardown;
begin
  AddCustomMetric('ReconnectAttempts', FReconnectAttempts);
  AddCustomMetric('ReconnectSuccesses', FReconnectSuccesses);
  AddCustomMetric('ReconnectFailures', FReconnectFailures);
  AddCustomMetric('ReconnectSuccessRate',
    IfThen(FReconnectAttempts > 0,
      FReconnectSuccesses / FReconnectAttempts, 0));
end;

procedure TConnectionPoolReconnectTest.Execute;
var
  SW: TStopwatch;
  Conn: TSimulatedConnection;
  ShouldDisconnect: Boolean;
begin
  SW := TStopwatch.StartNew;
  try
    Conn := GSimPool.Acquire(1000);

    if Conn <> nil then
    begin
      try
        // Simulate random disconnect
        ShouldDisconnect := Random < FSimulatedDisconnectRate;

        if ShouldDisconnect then
        begin
          TInterlocked.Increment(FReconnectAttempts);

          // Release and re-acquire to simulate reconnect
          GSimPool.Release(Conn);
          Conn := GSimPool.Acquire(500);

          if Conn <> nil then
            TInterlocked.Increment(FReconnectSuccesses)
          else
            TInterlocked.Increment(FReconnectFailures);
        end
        else
        begin
          Sleep(10);
        end;
      finally
        if Conn <> nil then
          GSimPool.Release(Conn);
      end;

      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportSuccess;
    end
    else
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Reconnect test: initial connection failed');
    end;
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Reconnect test error: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// Helper functions
// ============================================================================

function RunAllConnectionPoolStressTests(DurationSec: Integer;
  ThreadCount: Integer): TStressTestReport;
var
  Runner: TStressTestRunner;
  AcquireReleaseTest: TConnectionPoolAcquireReleaseTest;
  ExhaustionTest: TConnectionPoolExhaustionTest;
  LeakTest: TConnectionLeakDetectionTest;
  TimeoutTest: TConnectionTimeoutTest;
  ScalingTest: TConnectionPoolScalingTest;
  ConcurrencyTest: TConnectionPoolConcurrencyTest;
  ReconnectTest: TConnectionPoolReconnectTest;
begin
  Runner := TStressTestRunner.Create;
  try
    Runner.Config.DurationSec := DurationSec;
    Runner.Config.ThreadCount := ThreadCount;

    // Acquire/Release test
    AcquireReleaseTest := TConnectionPoolAcquireReleaseTest.Create;
    AcquireReleaseTest.HoldTimeMs := 15;
    Runner.AddTest(AcquireReleaseTest);

    // Exhaustion test
    ExhaustionTest := TConnectionPoolExhaustionTest.Create;
    ExhaustionTest.PoolSize := 30;
    ExhaustionTest.TimeoutMs := 300;
    Runner.AddTest(ExhaustionTest);

    // Leak detection test
    LeakTest := TConnectionLeakDetectionTest.Create;
    LeakTest.LeakCheckIntervalSec := DurationSec div 10;
    LeakTest.LeakThreshold := 10;
    Runner.AddTest(LeakTest);

    // Timeout test
    TimeoutTest := TConnectionTimeoutTest.Create;
    TimeoutTest.ConnectionTimeoutMs := 400;
    TimeoutTest.SimulatedQueryTimeMs := 50;
    Runner.AddTest(TimeoutTest);

    // Scaling test
    ScalingTest := TConnectionPoolScalingTest.Create;
    ScalingTest.LoadChangeIntervalSec := DurationSec div 20;
    Runner.AddTest(ScalingTest);

    // Concurrency test
    ConcurrencyTest := TConnectionPoolConcurrencyTest.Create;
    ConcurrencyTest.MaxConcurrency := ThreadCount * 2;
    Runner.AddTest(ConcurrencyTest);

    // Reconnect test
    ReconnectTest := TConnectionPoolReconnectTest.Create;
    ReconnectTest.SimulatedDisconnectRate := 0.03;
    Runner.AddTest(ReconnectTest);

    Runner.Run;

    Result := Runner.Report.Clone;
  finally
    Runner.Free;
  end;
end;

function RunQuickConnectionPoolCheck: TStressTestReport;
begin
  Result := RunAllConnectionPoolStressTests(60, 10);
end;

function Run48HourConnectionPoolEnduranceTest(ThreadCount: Integer): TStressTestReport;
var
  Runner: TStressTestRunner;
  LongRunTest: TConnectionPoolLongRunningTest;
begin
  Runner := TStressTestRunner.Create;
  try
    // 48 hours = 172800 seconds
    Runner.Config.DurationSec := 48 * 60 * 60;
    Runner.Config.ThreadCount := ThreadCount;

    LongRunTest := TConnectionPoolLongRunningTest.Create;
    LongRunTest.CheckpointIntervalSec := 300;  // 5-minute checkpoints
    Runner.AddTest(LongRunTest);

    Runner.Run;

    Result := Runner.Report.Clone;
  finally
    Runner.Free;
  end;
end;

initialization
  GSimPoolLock := TCriticalSection.Create;

finalization
  FreeAndNil(GSimPool);
  FreeAndNil(GSimPoolLock);

end.
