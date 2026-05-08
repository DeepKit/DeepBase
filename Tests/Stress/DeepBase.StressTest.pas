{ ============================================================================
  DeepBase.StressTest - Stress Testing Framework
  
  A comprehensive stress testing framework for evaluating system behavior
  under high load, concurrent access, and extended operation periods.
  
  Features:
  - Load generation with configurable thread count and duration
  - Memory leak detection and tracking
  - Resource monitoring (CPU, memory, handles)
  - Stability testing for long-running operations
  - Detailed reporting (Text, JSON, HTML)
  - Throughput and latency statistics
  
  Usage:
    var Runner := TStressTestRunner.Create;
    try
      Runner.AddTest(TConfigStressTest.Create);
      Runner.Duration := 60; // seconds
      Runner.ThreadCount := 10;
      Runner.Run;
      Runner.Report.SaveToFile('stress_report.html', srfHTML);
    finally
      Runner.Free;
    end;
  ============================================================================ }

unit DeepBase.StressTest;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.SyncObjs,
  System.Diagnostics,
  System.Math,
  System.JSON,
  System.DateUtils,
  System.IOUtils,
  Winapi.Windows,
  Winapi.PsAPI;

type
  // ============================================================================
  // Forward declarations
  // ============================================================================
  
  TStressTestRunner = class;
  TStressTest = class;
  TLoadGenerator = class;
  TMemoryLeakDetector = class;
  TStabilityMonitor = class;
  TStressTestReport = class;
  
  // ============================================================================
  // Types and Enums
  // ============================================================================
  
  /// <summary>
  /// Stress test status
  /// </summary>
  TStressTestStatus = (
    stsIdle,       // Not started
    stsRunning,    // Currently running
    stsCompleted,  // Finished successfully
    stsFailed,     // Failed with errors
    stsAborted     // Aborted by user
  );
  
  /// <summary>
  /// Report format
  /// </summary>
  TStressReportFormat = (srfText, srfJSON, srfHTML, srfCSV);
  
  /// <summary>
  /// Load profile type
  /// </summary>
  TLoadProfile = (
    lpConstant,    // Constant load throughout test
    lpRampUp,      // Gradually increase load
    lpRampDown,    // Gradually decrease load
    lpSpike,       // Spike pattern
    lpWave         // Sine wave pattern
  );
  
  /// <summary>
  /// Memory snapshot
  /// </summary>
  TMemoryStats = record
    WorkingSetSize: Int64;      // Physical memory (bytes)
    PrivateBytes: Int64;        // Private memory (bytes)
    VirtualSize: Int64;         // Virtual memory (bytes)
    HeapAllocated: Int64;       // Delphi heap (bytes)
    HeapCommitted: Int64;       // Committed heap
    HandleCount: Cardinal;      // Open handles
    ThreadCount: Cardinal;      // Thread count
    GDIObjects: Cardinal;       // GDI objects
    UserObjects: Cardinal;      // User objects
    Timestamp: TDateTime;
    
    class function Capture: TMemoryStats; static;
    function Subtract(const Other: TMemoryStats): TMemoryStats;
    function ToString: string;
    class function FormatBytes(Bytes: Int64): string; static;
  end;
  
  /// <summary>
  /// Latency statistics
  /// </summary>
  TLatencyStats = record
    Count: Int64;
    MinMs: Double;
    MaxMs: Double;
    MeanMs: Double;
    StdDevMs: Double;
    MedianMs: Double;
    P50Ms: Double;
    P90Ms: Double;
    P95Ms: Double;
    P99Ms: Double;
    P999Ms: Double;
    
    procedure Reset;
    class function Calculate(const Values: TArray<Double>): TLatencyStats; static;
    function ToString: string;
  end;
  
  /// <summary>
  /// Throughput statistics
  /// </summary>
  TThroughputStats = record
    TotalOperations: Int64;
    SuccessCount: Int64;
    FailureCount: Int64;
    DurationSec: Double;
    OpsPerSecond: Double;
    SuccessRate: Double;
    
    procedure Reset;
    function ToString: string;
  end;
  
  /// <summary>
  /// Test result
  /// </summary>
  TStressTestResult = record
    TestName: string;
    Status: TStressTestStatus;
    StartTime: TDateTime;
    EndTime: TDateTime;
    DurationSec: Double;
    ThreadCount: Integer;
    
    // Performance metrics
    Throughput: TThroughputStats;
    Latency: TLatencyStats;
    
    // Resource metrics
    MemoryBefore: TMemoryStats;
    MemoryAfter: TMemoryStats;
    MemoryPeak: TMemoryStats;
    MemoryLeakBytes: Int64;
    
    // Errors
    Errors: TArray<string>;
    ErrorCount: Integer;
    
    // Custom metrics
    CustomMetrics: TArray<TPair<string, Double>>;
    
    function IsSuccess: Boolean;
    function GetStatusString: string;
  end;
  
  // ============================================================================
  // Event types
  // ============================================================================
  
  TStressProgressEvent = procedure(Sender: TObject; Progress: Integer; 
    const Status: string) of object;
  TStressErrorEvent = procedure(Sender: TObject; const Error: string) of object;
  TStressMetricEvent = procedure(Sender: TObject; const MetricName: string; 
    Value: Double) of object;
  
  // ============================================================================
  // TStressTestConfig
  // ============================================================================
  
  /// <summary>
  /// Stress test configuration
  /// </summary>
  TStressTestConfig = class
  private
    FDurationSec: Integer;
    FThreadCount: Integer;
    FRampUpSec: Integer;
    FRampDownSec: Integer;
    FLoadProfile: TLoadProfile;
    FTargetOpsPerSec: Integer;
    FMaxErrors: Integer;
    FMemoryLeakThresholdBytes: Int64;
    FCollectLatencyHistogram: Boolean;
    FReportIntervalSec: Integer;
    FWarmupSec: Integer;
  public
    constructor Create;
    
    /// <summary>Test duration in seconds (default 60)</summary>
    property DurationSec: Integer read FDurationSec write FDurationSec;
    
    /// <summary>Number of concurrent threads (default 10)</summary>
    property ThreadCount: Integer read FThreadCount write FThreadCount;
    
    /// <summary>Ramp-up period in seconds (default 5)</summary>
    property RampUpSec: Integer read FRampUpSec write FRampUpSec;
    
    /// <summary>Ramp-down period in seconds (default 5)</summary>
    property RampDownSec: Integer read FRampDownSec write FRampDownSec;
    
    /// <summary>Load profile type (default lpConstant)</summary>
    property LoadProfile: TLoadProfile read FLoadProfile write FLoadProfile;
    
    /// <summary>Target operations per second (0 = unlimited)</summary>
    property TargetOpsPerSec: Integer read FTargetOpsPerSec write FTargetOpsPerSec;
    
    /// <summary>Maximum errors before abort (default 1000)</summary>
    property MaxErrors: Integer read FMaxErrors write FMaxErrors;
    
    /// <summary>Memory leak threshold in bytes (default 10MB)</summary>
    property MemoryLeakThresholdBytes: Int64 read FMemoryLeakThresholdBytes write FMemoryLeakThresholdBytes;
    
    /// <summary>Collect latency histogram (default True)</summary>
    property CollectLatencyHistogram: Boolean read FCollectLatencyHistogram write FCollectLatencyHistogram;
    
    /// <summary>Progress report interval in seconds (default 5)</summary>
    property ReportIntervalSec: Integer read FReportIntervalSec write FReportIntervalSec;
    
    /// <summary>Warmup period in seconds (default 3)</summary>
    property WarmupSec: Integer read FWarmupSec write FWarmupSec;
  end;
  
  // ============================================================================
  // TStressTest - Base class for stress tests
  // ============================================================================
  
  /// <summary>
  /// Base class for implementing stress tests
  /// </summary>
  TStressTest = class
  private
    FName: string;
    FDescription: string;
    FConfig: TStressTestConfig;
    FOwnsConfig: Boolean;
    FStatus: TStressTestStatus;
    FResult: TStressTestResult;
    FAbortRequested: Boolean;
    FLock: TCriticalSection;
    
    // Metrics collection
    FLatencies: TList<Double>;
    FErrors: TList<string>;
    FSuccessCount: Int64;
    FFailureCount: Int64;
    FCustomMetrics: TDictionary<string, TList<Double>>;
    
    procedure CollectLatency(Ms: Double);
    procedure CollectError(const Msg: string);
    procedure IncrementSuccess;
    procedure IncrementFailure;
    
  protected
    /// <summary>Override to perform test setup</summary>
    procedure Setup; virtual;
    
    /// <summary>Override to perform test teardown</summary>
    procedure Teardown; virtual;
    
    /// <summary>Override to perform a single test iteration</summary>
    /// <remarks>Called from multiple threads concurrently</remarks>
    procedure Execute; virtual; abstract;
    
    /// <summary>Call from Execute to report operation latency</summary>
    procedure ReportLatency(Ms: Double);
    
    /// <summary>Call from Execute to report an error</summary>
    procedure ReportError(const Msg: string);
    
    /// <summary>Call from Execute to report success</summary>
    procedure ReportSuccess;
    
    /// <summary>Call from Execute to report failure</summary>
    procedure ReportFailure;
    
    /// <summary>Call to add custom metric</summary>
    procedure AddCustomMetric(const Name: string; Value: Double);
    
    /// <summary>Check if abort was requested</summary>
    function IsAborted: Boolean;
    
  public
    constructor Create(const AName: string; const ADescription: string = ''); virtual;
    destructor Destroy; override;
    
    /// <summary>Run the stress test</summary>
    function Run: TStressTestResult;
    
    /// <summary>Request abort</summary>
    procedure Abort;
    
    property Name: string read FName;
    property Description: string read FDescription;
    property Config: TStressTestConfig read FConfig;
    property Status: TStressTestStatus read FStatus;
    property Result: TStressTestResult read FResult;
  end;
  
  // ============================================================================
  // TLoadGenerator
  // ============================================================================
  
  TLoadWorkerProc = reference to procedure;
  
  /// <summary>
  /// Generates concurrent load using multiple threads
  /// </summary>
  TLoadGenerator = class
  private
    FThreadCount: Integer;
    FDurationSec: Integer;
    FTargetOpsPerSec: Integer;
    FLoadProfile: TLoadProfile;
    FRampUpSec: Integer;
    FRampDownSec: Integer;
    
    FWorkers: TList<TThread>;
    FStopEvent: TEvent;
    FStartTime: TDateTime;
    FTotalOps: Int64;
    FLock: TCriticalSection;
    
    FOnProgress: TStressProgressEvent;
    FOnError: TStressErrorEvent;
    
    function GetCurrentLoadFactor: Double;
    procedure WorkerThread(WorkerProc: TLoadWorkerProc);
    
  public
    constructor Create;
    destructor Destroy; override;
    
    /// <summary>Start load generation</summary>
    procedure Start(WorkerProc: TLoadWorkerProc);
    
    /// <summary>Stop load generation</summary>
    procedure Stop;
    
    /// <summary>Wait for completion</summary>
    procedure WaitFor;
    
    /// <summary>Check if running</summary>
    function IsRunning: Boolean;
    
    property ThreadCount: Integer read FThreadCount write FThreadCount;
    property DurationSec: Integer read FDurationSec write FDurationSec;
    property TargetOpsPerSec: Integer read FTargetOpsPerSec write FTargetOpsPerSec;
    property LoadProfile: TLoadProfile read FLoadProfile write FLoadProfile;
    property RampUpSec: Integer read FRampUpSec write FRampUpSec;
    property RampDownSec: Integer read FRampDownSec write FRampDownSec;
    property TotalOperations: Int64 read FTotalOps;
    
    property OnProgress: TStressProgressEvent read FOnProgress write FOnProgress;
    property OnError: TStressErrorEvent read FOnError write FOnError;
  end;
  
  // ============================================================================
  // TMemoryLeakDetector
  // ============================================================================
  
  /// <summary>
  /// Detects memory leaks during stress testing
  /// </summary>
  TMemoryLeakDetector = class
  private
    FSnapshots: TList<TMemoryStats>;
    FBaseline: TMemoryStats;
    FPeak: TMemoryStats;
    FSampleIntervalMs: Integer;
    FMonitorThread: TThread;
    FStopEvent: TEvent;
    FLock: TCriticalSection;
    
    procedure MonitorThread;
    
  public
    constructor Create;
    destructor Destroy; override;
    
    /// <summary>Start monitoring</summary>
    procedure Start;
    
    /// <summary>Stop monitoring</summary>
    procedure Stop;
    
    /// <summary>Get baseline snapshot</summary>
    function GetBaseline: TMemoryStats;
    
    /// <summary>Get current snapshot</summary>
    function GetCurrent: TMemoryStats;
    
    /// <summary>Get peak memory</summary>
    function GetPeak: TMemoryStats;
    
    /// <summary>Calculate leak (current - baseline)</summary>
    function GetLeakBytes: Int64;
    
    /// <summary>Get all snapshots</summary>
    function GetSnapshots: TArray<TMemoryStats>;
    
    /// <summary>Check if leak exceeds threshold</summary>
    function HasLeak(ThresholdBytes: Int64): Boolean;
    
    /// <summary>Sample interval in milliseconds (default 1000)</summary>
    property SampleIntervalMs: Integer read FSampleIntervalMs write FSampleIntervalMs;
  end;
  
  // ============================================================================
  // TStabilityMonitor
  // ============================================================================
  
  /// <summary>
  /// Monitors system stability during extended tests
  /// </summary>
  TStabilityMonitor = class
  private
    FCheckIntervalSec: Integer;
    FMonitorThread: TThread;
    FStopEvent: TEvent;
    FLock: TCriticalSection;
    
    FMemoryThresholdMB: Integer;
    FHandleThresholdCount: Integer;
    FCPUThresholdPercent: Integer;
    
    FAnomalies: TList<string>;
    FStartTime: TDateTime;
    FLastCheckTime: TDateTime;
    
    FOnAnomaly: TStressErrorEvent;
    
    procedure MonitorThread;
    procedure CheckMemory;
    procedure CheckHandles;
    procedure CheckCPU;
    procedure AddAnomaly(const Msg: string);
    
  public
    constructor Create;
    destructor Destroy; override;
    
    /// <summary>Start monitoring</summary>
    procedure Start;
    
    /// <summary>Stop monitoring</summary>
    procedure Stop;
    
    /// <summary>Get detected anomalies</summary>
    function GetAnomalies: TArray<string>;
    
    /// <summary>Check if system is stable</summary>
    function IsStable: Boolean;
    
    /// <summary>Check interval in seconds (default 5)</summary>
    property CheckIntervalSec: Integer read FCheckIntervalSec write FCheckIntervalSec;
    
    /// <summary>Memory threshold in MB (default 500)</summary>
    property MemoryThresholdMB: Integer read FMemoryThresholdMB write FMemoryThresholdMB;
    
    /// <summary>Handle count threshold (default 10000)</summary>
    property HandleThresholdCount: Integer read FHandleThresholdCount write FHandleThresholdCount;
    
    /// <summary>CPU threshold percent (default 95)</summary>
    property CPUThresholdPercent: Integer read FCPUThresholdPercent write FCPUThresholdPercent;
    
    property OnAnomaly: TStressErrorEvent read FOnAnomaly write FOnAnomaly;
  end;
  
  // ============================================================================
  // TStressTestReport
  // ============================================================================
  
  /// <summary>
  /// Generates stress test reports
  /// </summary>
  TStressTestReport = class
  private
    FResults: TList<TStressTestResult>;
    FTitle: string;
    FDescription: string;
    FTimestamp: TDateTime;
    FEnvironmentInfo: TDictionary<string, string>;
    
    function GenerateText: string;
    function GenerateJSON: string;
    function GenerateHTML: string;
    function GenerateCSV: string;
    
  public
    constructor Create(const ATitle: string = 'Stress Test Report');
    destructor Destroy; override;
    
    /// <summary>Add test result</summary>
    procedure AddResult(const AResult: TStressTestResult);
    
    /// <summary>Clear all results</summary>
    procedure Clear;
    
    /// <summary>Generate report</summary>
    function Generate(Format: TStressReportFormat): string;
    
    /// <summary>Save report to file</summary>
    procedure SaveToFile(const FileName: string; Format: TStressReportFormat);
    
    /// <summary>Collect environment info</summary>
    procedure CollectEnvironmentInfo;
    
    property Title: string read FTitle write FTitle;
    property Description: string read FDescription write FDescription;
    property Results: TList<TStressTestResult> read FResults;
    property EnvironmentInfo: TDictionary<string, string> read FEnvironmentInfo;
  end;
  
  // ============================================================================
  // TStressTestRunner
  // ============================================================================
  
  /// <summary>
  /// Main stress test runner
  /// </summary>
  TStressTestRunner = class
  private
    FTests: TObjectList<TStressTest>;
    FConfig: TStressTestConfig;
    FReport: TStressTestReport;
    FMemoryDetector: TMemoryLeakDetector;
    FStabilityMonitor: TStabilityMonitor;
    
    FOnProgress: TStressProgressEvent;
    FOnError: TStressErrorEvent;
    FOnTestComplete: TNotifyEvent;
    
    FAbortRequested: Boolean;
    FIsRunning: Boolean;
    
  public
    constructor Create;
    destructor Destroy; override;
    
    /// <summary>Add a stress test</summary>
    procedure AddTest(ATest: TStressTest);
    
    /// <summary>Clear all tests</summary>
    procedure ClearTests;
    
    /// <summary>Run all tests</summary>
    procedure Run;
    
    /// <summary>Run a single test</summary>
    function RunTest(ATest: TStressTest): TStressTestResult;
    
    /// <summary>Abort running tests</summary>
    procedure Abort;
    
    /// <summary>Check if running</summary>
    function IsRunning: Boolean;
    
    property Tests: TObjectList<TStressTest> read FTests;
    property Config: TStressTestConfig read FConfig;
    property Report: TStressTestReport read FReport;
    property MemoryDetector: TMemoryLeakDetector read FMemoryDetector;
    property StabilityMonitor: TStabilityMonitor read FStabilityMonitor;
    
    property OnProgress: TStressProgressEvent read FOnProgress write FOnProgress;
    property OnError: TStressErrorEvent read FOnError write FOnError;
    property OnTestComplete: TNotifyEvent read FOnTestComplete write FOnTestComplete;
  end;
  
  // ============================================================================
  // Helper functions
  // ============================================================================
  
  /// <summary>Quick stress test execution</summary>
  function RunStressTest(const TestName: string; WorkerProc: TLoadWorkerProc;
    DurationSec: Integer = 60; ThreadCount: Integer = 10): TStressTestResult;

implementation

// ============================================================================
// TMemoryStats
// ============================================================================

class function TMemoryStats.Capture: TMemoryStats;
var
  PMC: PROCESS_MEMORY_COUNTERS_EX;
  HProcess: THandle;
  HeapStatus: THeapStatus;
begin
  Result := Default(TMemoryStats);
  Result.Timestamp := Now;
  
  HProcess := GetCurrentProcess;
  
  // Process memory
  PMC.cb := SizeOf(PMC);
  if GetProcessMemoryInfo(HProcess, @PMC, SizeOf(PMC)) then
  begin
    Result.WorkingSetSize := PMC.WorkingSetSize;
    Result.PrivateBytes := PMC.PrivateUsage;
    Result.VirtualSize := PMC.PagefileUsage;
  end;
  
  // Delphi heap
  {$WARNINGS OFF}
  HeapStatus := GetHeapStatus;
  Result.HeapAllocated := HeapStatus.TotalAllocated;
  Result.HeapCommitted := HeapStatus.TotalCommitted;
  {$WARNINGS ON}
  
  // Handle counts
  GetProcessHandleCount(HProcess, Result.HandleCount);
  Result.ThreadCount := 0; // Would need TlHelp32 snapshot
  Result.GDIObjects := GetGuiResources(HProcess, GR_GDIOBJECTS);
  Result.UserObjects := GetGuiResources(HProcess, GR_USEROBJECTS);
end;

function TMemoryStats.Subtract(const Other: TMemoryStats): TMemoryStats;
begin
  Result.WorkingSetSize := Self.WorkingSetSize - Other.WorkingSetSize;
  Result.PrivateBytes := Self.PrivateBytes - Other.PrivateBytes;
  Result.VirtualSize := Self.VirtualSize - Other.VirtualSize;
  Result.HeapAllocated := Self.HeapAllocated - Other.HeapAllocated;
  Result.HeapCommitted := Self.HeapCommitted - Other.HeapCommitted;
  Result.HandleCount := Self.HandleCount - Other.HandleCount;
  Result.ThreadCount := Self.ThreadCount - Other.ThreadCount;
  Result.GDIObjects := Self.GDIObjects - Other.GDIObjects;
  Result.UserObjects := Self.UserObjects - Other.UserObjects;
  Result.Timestamp := Self.Timestamp;
end;

function TMemoryStats.ToString: string;
begin
  Result := Format('WorkingSet: %s, Private: %s, Heap: %s, Handles: %d',
    [FormatBytes(WorkingSetSize), FormatBytes(PrivateBytes), 
     FormatBytes(HeapAllocated), HandleCount]);
end;

class function TMemoryStats.FormatBytes(Bytes: Int64): string;
const
  KB = 1024;
  MB = KB * 1024;
  GB = MB * 1024;
begin
  if Abs(Bytes) >= GB then
    Result := Format('%.2f GB', [Bytes / GB])
  else if Abs(Bytes) >= MB then
    Result := Format('%.2f MB', [Bytes / MB])
  else if Abs(Bytes) >= KB then
    Result := Format('%.2f KB', [Bytes / KB])
  else
    Result := Format('%d B', [Bytes]);
end;

// ============================================================================
// TLatencyStats
// ============================================================================

procedure TLatencyStats.Reset;
begin
  Self := Default(TLatencyStats);
end;

class function TLatencyStats.Calculate(const Values: TArray<Double>): TLatencyStats;
var
  I, N: Integer;
  Sum, SumSq, Mean: Double;
  Sorted: TArray<Double>;
begin
  Result.Reset;
  N := Length(Values);
  if N = 0 then Exit;
  
  Result.Count := N;
  
  // Min/Max/Sum
  Result.MinMs := Values[0];
  Result.MaxMs := Values[0];
  Sum := 0;
  for I := 0 to N - 1 do
  begin
    if Values[I] < Result.MinMs then Result.MinMs := Values[I];
    if Values[I] > Result.MaxMs then Result.MaxMs := Values[I];
    Sum := Sum + Values[I];
  end;
  
  // Mean
  Mean := Sum / N;
  Result.MeanMs := Mean;
  
  // StdDev
  SumSq := 0;
  for I := 0 to N - 1 do
    SumSq := SumSq + Sqr(Values[I] - Mean);
  if N > 1 then
    Result.StdDevMs := Sqrt(SumSq / (N - 1))
  else
    Result.StdDevMs := 0;
  
  // Percentiles (need sorted array)
  Sorted := Copy(Values);
  TArray.Sort<Double>(Sorted);
  
  Result.MedianMs := Sorted[N div 2];
  Result.P50Ms := Sorted[Trunc(N * 0.50)];
  Result.P90Ms := Sorted[Min(Trunc(N * 0.90), N - 1)];
  Result.P95Ms := Sorted[Min(Trunc(N * 0.95), N - 1)];
  Result.P99Ms := Sorted[Min(Trunc(N * 0.99), N - 1)];
  Result.P999Ms := Sorted[Min(Trunc(N * 0.999), N - 1)];
end;

function TLatencyStats.ToString: string;
begin
  Result := Format('Min: %.2f ms, Max: %.2f ms, Mean: %.2f ms, P99: %.2f ms',
    [MinMs, MaxMs, MeanMs, P99Ms]);
end;

// ============================================================================
// TThroughputStats
// ============================================================================

procedure TThroughputStats.Reset;
begin
  Self := Default(TThroughputStats);
end;

function TThroughputStats.ToString: string;
begin
  Result := Format('Total: %d, Success: %d (%.1f%%), %.2f ops/sec',
    [TotalOperations, SuccessCount, SuccessRate * 100, OpsPerSecond]);
end;

// ============================================================================
// TStressTestResult
// ============================================================================

function TStressTestResult.IsSuccess: Boolean;
begin
  Result := (Status = stsCompleted) and (ErrorCount = 0) and (MemoryLeakBytes < 10 * 1024 * 1024);
end;

function TStressTestResult.GetStatusString: string;
begin
  case Status of
    stsIdle: Result := 'Idle';
    stsRunning: Result := 'Running';
    stsCompleted: Result := 'Completed';
    stsFailed: Result := 'Failed';
    stsAborted: Result := 'Aborted';
  else
    Result := 'Unknown';
  end;
end;

// ============================================================================
// TStressTestConfig
// ============================================================================

constructor TStressTestConfig.Create;
begin
  inherited;
  FDurationSec := 60;
  FThreadCount := 10;
  FRampUpSec := 5;
  FRampDownSec := 5;
  FLoadProfile := lpConstant;
  FTargetOpsPerSec := 0;
  FMaxErrors := 1000;
  FMemoryLeakThresholdBytes := 10 * 1024 * 1024; // 10 MB
  FCollectLatencyHistogram := True;
  FReportIntervalSec := 5;
  FWarmupSec := 3;
end;

// ============================================================================
// TStressTest
// ============================================================================

constructor TStressTest.Create(const AName: string; const ADescription: string);
begin
  inherited Create;
  FName := AName;
  FDescription := ADescription;
  FConfig := TStressTestConfig.Create;
  FOwnsConfig := True;
  FStatus := stsIdle;
  FLock := TCriticalSection.Create;
  FLatencies := TList<Double>.Create;
  FErrors := TList<string>.Create;
  FCustomMetrics := TDictionary<string, TList<Double>>.Create;
end;

destructor TStressTest.Destroy;
var
  MetricList: TList<Double>;
begin
  for MetricList in FCustomMetrics.Values do
    MetricList.Free;
  FCustomMetrics.Free;
  FErrors.Free;
  FLatencies.Free;
  FLock.Free;
  if FOwnsConfig then
    FConfig.Free;
  inherited;
end;

procedure TStressTest.Setup;
begin
  // Override in subclass
end;

procedure TStressTest.Teardown;
begin
  // Override in subclass
end;

procedure TStressTest.CollectLatency(Ms: Double);
begin
  FLock.Enter;
  try
    FLatencies.Add(Ms);
  finally
    FLock.Leave;
  end;
end;

procedure TStressTest.CollectError(const Msg: string);
begin
  FLock.Enter;
  try
    if FErrors.Count < 1000 then // Limit error collection
      FErrors.Add(Msg);
  finally
    FLock.Leave;
  end;
end;

procedure TStressTest.IncrementSuccess;
begin
  TInterlocked.Increment(FSuccessCount);
end;

procedure TStressTest.IncrementFailure;
begin
  TInterlocked.Increment(FFailureCount);
end;

procedure TStressTest.ReportLatency(Ms: Double);
begin
  if FConfig.CollectLatencyHistogram then
    CollectLatency(Ms);
end;

procedure TStressTest.ReportError(const Msg: string);
begin
  CollectError(Msg);
  IncrementFailure;
end;

procedure TStressTest.ReportSuccess;
begin
  IncrementSuccess;
end;

procedure TStressTest.ReportFailure;
begin
  IncrementFailure;
end;

procedure TStressTest.AddCustomMetric(const Name: string; Value: Double);
var
  MetricList: TList<Double>;
begin
  FLock.Enter;
  try
    if not FCustomMetrics.TryGetValue(Name, MetricList) then
    begin
      MetricList := TList<Double>.Create;
      FCustomMetrics.Add(Name, MetricList);
    end;
    MetricList.Add(Value);
  finally
    FLock.Leave;
  end;
end;

function TStressTest.IsAborted: Boolean;
begin
  Result := FAbortRequested;
end;

procedure TStressTest.Abort;
begin
  FAbortRequested := True;
end;

function TStressTest.Run: TStressTestResult;
var
  LoadGen: TLoadGenerator;
  MemDetect: TMemoryLeakDetector;
  SW: TStopwatch;
  Pair: TPair<string, TList<Double>>;
  I: Integer;
begin
  FStatus := stsRunning;
  FResult := Default(TStressTestResult);
  FResult.TestName := FName;
  FResult.StartTime := Now;
  FResult.ThreadCount := FConfig.ThreadCount;
  FAbortRequested := False;
  
  FLatencies.Clear;
  FErrors.Clear;
  FSuccessCount := 0;
  FFailureCount := 0;
  for Pair in FCustomMetrics do
    Pair.Value.Clear;
  
  LoadGen := TLoadGenerator.Create;
  MemDetect := TMemoryLeakDetector.Create;
  SW := TStopwatch.StartNew;
  
  try
    // Setup
    try
      Setup;
    except
      on E: Exception do
      begin
        FResult.Status := stsFailed;
        SetLength(FResult.Errors, 1);
        FResult.Errors[0] := 'Setup failed: ' + E.Message;
        FResult.ErrorCount := 1;
        Exit(FResult);
      end;
    end;
    
    // Configure load generator
    LoadGen.ThreadCount := FConfig.ThreadCount;
    LoadGen.DurationSec := FConfig.DurationSec;
    LoadGen.TargetOpsPerSec := FConfig.TargetOpsPerSec;
    LoadGen.LoadProfile := FConfig.LoadProfile;
    LoadGen.RampUpSec := FConfig.RampUpSec;
    LoadGen.RampDownSec := FConfig.RampDownSec;
    
    // Start monitoring
    MemDetect.Start;
    FResult.MemoryBefore := MemDetect.GetBaseline;
    
    // Run warmup
    if FConfig.WarmupSec > 0 then
    begin
      LoadGen.DurationSec := FConfig.WarmupSec;
      LoadGen.Start(
        procedure
        begin
          if not IsAborted then
            Execute;
        end);
      LoadGen.WaitFor;
      
      // Reset metrics after warmup
      FLatencies.Clear;
      FSuccessCount := 0;
      FFailureCount := 0;
    end;
    
    // Run main test
    LoadGen.DurationSec := FConfig.DurationSec;
    LoadGen.Start(
      procedure
      begin
        if not IsAborted then
          Execute;
      end);
    
    LoadGen.WaitFor;
    
    SW.Stop;
    
    // Stop monitoring
    MemDetect.Stop;
    
    // Collect results
    FResult.EndTime := Now;
    FResult.DurationSec := SW.Elapsed.TotalSeconds;
    FResult.MemoryAfter := MemDetect.GetCurrent;
    FResult.MemoryPeak := MemDetect.GetPeak;
    FResult.MemoryLeakBytes := MemDetect.GetLeakBytes;
    
    // Throughput
    FResult.Throughput.TotalOperations := FSuccessCount + FFailureCount;
    FResult.Throughput.SuccessCount := FSuccessCount;
    FResult.Throughput.FailureCount := FFailureCount;
    FResult.Throughput.DurationSec := FResult.DurationSec;
    if FResult.DurationSec > 0 then
      FResult.Throughput.OpsPerSecond := FResult.Throughput.TotalOperations / FResult.DurationSec
    else
      FResult.Throughput.OpsPerSecond := 0;
    if FResult.Throughput.TotalOperations > 0 then
      FResult.Throughput.SuccessRate := FResult.Throughput.SuccessCount / FResult.Throughput.TotalOperations
    else
      FResult.Throughput.SuccessRate := 0;
    
    // Latency
    FLock.Enter;
    try
      if FLatencies.Count > 0 then
        FResult.Latency := TLatencyStats.Calculate(FLatencies.ToArray);
        
      // Errors
      FResult.Errors := FErrors.ToArray;
      FResult.ErrorCount := FErrors.Count;
      
      // Custom metrics
      SetLength(FResult.CustomMetrics, FCustomMetrics.Count);
      I := 0;
      for Pair in FCustomMetrics do
      begin
        if Pair.Value.Count > 0 then
        begin
          FResult.CustomMetrics[I].Key := Pair.Key;
          FResult.CustomMetrics[I].Value := Pair.Value[Pair.Value.Count - 1]; // Last value
        end;
        Inc(I);
      end;
    finally
      FLock.Leave;
    end;
    
    // Determine status
    if FAbortRequested then
      FResult.Status := stsAborted
    else if FResult.ErrorCount > 0 then
      FResult.Status := stsFailed
    else
      FResult.Status := stsCompleted;
    
  finally
    // Teardown
    try
      Teardown;
    except
      // Ignore teardown errors
    end;
    
    MemDetect.Free;
    LoadGen.Free;
  end;
  
  FStatus := FResult.Status;
  Result := FResult;
end;

// ============================================================================
// TLoadGenerator
// ============================================================================

constructor TLoadGenerator.Create;
begin
  inherited;
  FThreadCount := 10;
  FDurationSec := 60;
  FTargetOpsPerSec := 0;
  FLoadProfile := lpConstant;
  FRampUpSec := 5;
  FRampDownSec := 5;
  FWorkers := TList<TThread>.Create;
  FStopEvent := TEvent.Create(nil, True, False, '');
  FLock := TCriticalSection.Create;
end;

destructor TLoadGenerator.Destroy;
begin
  Stop;
  FLock.Free;
  FStopEvent.Free;
  FWorkers.Free;
  inherited;
end;

function TLoadGenerator.GetCurrentLoadFactor: Double;
var
  ElapsedSec: Double;
  TotalDuration: Double;
begin
  ElapsedSec := SecondSpan(Now, FStartTime);
  TotalDuration := FDurationSec;
  Result := 1.0;
  
  case FLoadProfile of
    lpConstant:
      Result := 1.0;
      
    lpRampUp:
      if ElapsedSec < FRampUpSec then
        Result := ElapsedSec / FRampUpSec
      else
        Result := 1.0;
        
    lpRampDown:
      if ElapsedSec > (TotalDuration - FRampDownSec) then
        Result := (TotalDuration - ElapsedSec) / FRampDownSec
      else
        Result := 1.0;
        
    lpSpike:
      begin
        // Spike at 50%
        if (ElapsedSec > TotalDuration * 0.45) and (ElapsedSec < TotalDuration * 0.55) then
          Result := 2.0
        else
          Result := 1.0;
      end;
      
    lpWave:
      Result := 0.5 + 0.5 * Sin(ElapsedSec * Pi / 30); // 30 sec period
  end;
  
  Result := Max(0.1, Result);
end;

procedure TLoadGenerator.WorkerThread(WorkerProc: TLoadWorkerProc);
var
  OpCount: Integer;
  DelayMs: Integer;
  LoadFactor: Double;
begin
  while FStopEvent.WaitFor(0) = wrTimeout do
  begin
    try
      WorkerProc;
      TInterlocked.Increment(FTotalOps);
      
      // Rate limiting
      if FTargetOpsPerSec > 0 then
      begin
        LoadFactor := GetCurrentLoadFactor;
        DelayMs := Round(1000 / (FTargetOpsPerSec * LoadFactor / FThreadCount));
        if DelayMs > 0 then
          Sleep(DelayMs);
      end;
    except
      on E: Exception do
      begin
        if Assigned(FOnError) then
        begin
          FLock.Enter;
          try
            FOnError(Self, E.Message);
          finally
            FLock.Leave;
          end;
        end;
      end;
    end;
  end;
end;

procedure TLoadGenerator.Start(WorkerProc: TLoadWorkerProc);
var
  I: Integer;
  Worker: TThread;
begin
  if IsRunning then Exit;
  
  FStopEvent.ResetEvent;
  FStartTime := Now;
  FTotalOps := 0;
  
  for I := 0 to FThreadCount - 1 do
  begin
    Worker := TThread.CreateAnonymousThread(
      procedure
      begin
        WorkerThread(WorkerProc);
      end);
    Worker.FreeOnTerminate := False;
    FWorkers.Add(Worker);
    Worker.Start;
  end;
  
  // Schedule stop
  TThread.CreateAnonymousThread(
    procedure
    begin
      Sleep(FDurationSec * 1000);
      Stop;
    end).Start;
end;

procedure TLoadGenerator.Stop;
var
  Worker: TThread;
begin
  FStopEvent.SetEvent;
  
  for Worker in FWorkers do
  begin
    Worker.WaitFor;
    Worker.Free;
  end;
  FWorkers.Clear;
end;

procedure TLoadGenerator.WaitFor;
var
  Worker: TThread;
begin
  for Worker in FWorkers do
    Worker.WaitFor;
end;

function TLoadGenerator.IsRunning: Boolean;
begin
  Result := FWorkers.Count > 0;
end;

// ============================================================================
// TMemoryLeakDetector
// ============================================================================

constructor TMemoryLeakDetector.Create;
begin
  inherited;
  FSnapshots := TList<TMemoryStats>.Create;
  FSampleIntervalMs := 1000;
  FStopEvent := TEvent.Create(nil, True, False, '');
  FLock := TCriticalSection.Create;
end;

destructor TMemoryLeakDetector.Destroy;
begin
  Stop;
  FLock.Free;
  FStopEvent.Free;
  FSnapshots.Free;
  inherited;
end;

procedure TMemoryLeakDetector.MonitorThread;
var
  Stats: TMemoryStats;
begin
  while FStopEvent.WaitFor(FSampleIntervalMs) = wrTimeout do
  begin
    Stats := TMemoryStats.Capture;
    
    FLock.Enter;
    try
      FSnapshots.Add(Stats);
      
      // Track peak
      if Stats.WorkingSetSize > FPeak.WorkingSetSize then
        FPeak := Stats;
    finally
      FLock.Leave;
    end;
  end;
end;

procedure TMemoryLeakDetector.Start;
begin
  FStopEvent.ResetEvent;
  FSnapshots.Clear;
  
  FBaseline := TMemoryStats.Capture;
  FPeak := FBaseline;
  
  FMonitorThread := TThread.CreateAnonymousThread(MonitorThread);
  FMonitorThread.FreeOnTerminate := False;
  FMonitorThread.Start;
end;

procedure TMemoryLeakDetector.Stop;
begin
  if Assigned(FMonitorThread) then
  begin
    FStopEvent.SetEvent;
    FMonitorThread.WaitFor;
    FreeAndNil(FMonitorThread);
  end;
end;

function TMemoryLeakDetector.GetBaseline: TMemoryStats;
begin
  FLock.Enter;
  try
    Result := FBaseline;
  finally
    FLock.Leave;
  end;
end;

function TMemoryLeakDetector.GetCurrent: TMemoryStats;
begin
  Result := TMemoryStats.Capture;
end;

function TMemoryLeakDetector.GetPeak: TMemoryStats;
begin
  FLock.Enter;
  try
    Result := FPeak;
  finally
    FLock.Leave;
  end;
end;

function TMemoryLeakDetector.GetLeakBytes: Int64;
var
  Current: TMemoryStats;
begin
  Current := TMemoryStats.Capture;
  Result := Current.HeapAllocated - FBaseline.HeapAllocated;
end;

function TMemoryLeakDetector.GetSnapshots: TArray<TMemoryStats>;
begin
  FLock.Enter;
  try
    Result := FSnapshots.ToArray;
  finally
    FLock.Leave;
  end;
end;

function TMemoryLeakDetector.HasLeak(ThresholdBytes: Int64): Boolean;
begin
  Result := GetLeakBytes > ThresholdBytes;
end;

// ============================================================================
// TStabilityMonitor
// ============================================================================

constructor TStabilityMonitor.Create;
begin
  inherited;
  FCheckIntervalSec := 5;
  FMemoryThresholdMB := 500;
  FHandleThresholdCount := 10000;
  FCPUThresholdPercent := 95;
  FAnomalies := TList<string>.Create;
  FStopEvent := TEvent.Create(nil, True, False, '');
  FLock := TCriticalSection.Create;
end;

destructor TStabilityMonitor.Destroy;
begin
  Stop;
  FLock.Free;
  FStopEvent.Free;
  FAnomalies.Free;
  inherited;
end;

procedure TStabilityMonitor.MonitorThread;
begin
  while FStopEvent.WaitFor(FCheckIntervalSec * 1000) = wrTimeout do
  begin
    FLastCheckTime := Now;
    CheckMemory;
    CheckHandles;
    // CheckCPU requires kernel32 calls not implemented yet
  end;
end;

procedure TStabilityMonitor.CheckMemory;
var
  Stats: TMemoryStats;
  UsedMB: Integer;
begin
  Stats := TMemoryStats.Capture;
  UsedMB := Stats.WorkingSetSize div (1024 * 1024);
  
  if UsedMB > FMemoryThresholdMB then
    AddAnomaly(Format('Memory threshold exceeded: %d MB (threshold: %d MB)',
      [UsedMB, FMemoryThresholdMB]));
end;

procedure TStabilityMonitor.CheckHandles;
var
  HandleCount: Cardinal;
begin
  GetProcessHandleCount(GetCurrentProcess, HandleCount);
  
  if HandleCount > Cardinal(FHandleThresholdCount) then
    AddAnomaly(Format('Handle count threshold exceeded: %d (threshold: %d)',
      [HandleCount, FHandleThresholdCount]));
end;

procedure TStabilityMonitor.CheckCPU;
begin
  // CPU monitoring would require PDH or WMI queries
  // Not implemented in this version
end;

procedure TStabilityMonitor.AddAnomaly(const Msg: string);
var
  TimestampedMsg: string;
begin
  TimestampedMsg := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + ' - ' + Msg;
  
  FLock.Enter;
  try
    FAnomalies.Add(TimestampedMsg);
  finally
    FLock.Leave;
  end;
  
  if Assigned(FOnAnomaly) then
    FOnAnomaly(Self, TimestampedMsg);
end;

procedure TStabilityMonitor.Start;
begin
  FStopEvent.ResetEvent;
  FAnomalies.Clear;
  FStartTime := Now;
  
  FMonitorThread := TThread.CreateAnonymousThread(MonitorThread);
  FMonitorThread.FreeOnTerminate := False;
  FMonitorThread.Start;
end;

procedure TStabilityMonitor.Stop;
begin
  if Assigned(FMonitorThread) then
  begin
    FStopEvent.SetEvent;
    FMonitorThread.WaitFor;
    FreeAndNil(FMonitorThread);
  end;
end;

function TStabilityMonitor.GetAnomalies: TArray<string>;
begin
  FLock.Enter;
  try
    Result := FAnomalies.ToArray;
  finally
    FLock.Leave;
  end;
end;

function TStabilityMonitor.IsStable: Boolean;
begin
  FLock.Enter;
  try
    Result := FAnomalies.Count = 0;
  finally
    FLock.Leave;
  end;
end;

// ============================================================================
// TStressTestReport
// ============================================================================

constructor TStressTestReport.Create(const ATitle: string);
begin
  inherited Create;
  FTitle := ATitle;
  FTimestamp := Now;
  FResults := TList<TStressTestResult>.Create;
  FEnvironmentInfo := TDictionary<string, string>.Create;
end;

destructor TStressTestReport.Destroy;
begin
  FEnvironmentInfo.Free;
  FResults.Free;
  inherited;
end;

procedure TStressTestReport.AddResult(const AResult: TStressTestResult);
begin
  FResults.Add(AResult);
end;

procedure TStressTestReport.Clear;
begin
  FResults.Clear;
end;

procedure TStressTestReport.CollectEnvironmentInfo;
var
  OSVersionInfo: TOSVersionInfo;
  MemStatus: TMemoryStatusEx;
begin
  FEnvironmentInfo.Clear;
  
  // OS info
  OSVersionInfo.dwOSVersionInfoSize := SizeOf(OSVersionInfo);
  GetVersionEx(OSVersionInfo);
  FEnvironmentInfo.AddOrSetValue('OS', Format('Windows %d.%d', 
    [OSVersionInfo.dwMajorVersion, OSVersionInfo.dwMinorVersion]));
  
  // Memory
  MemStatus.dwLength := SizeOf(MemStatus);
  GlobalMemoryStatusEx(MemStatus);
  FEnvironmentInfo.AddOrSetValue('Total Memory', TMemoryStats.FormatBytes(MemStatus.ullTotalPhys));
  FEnvironmentInfo.AddOrSetValue('Available Memory', TMemoryStats.FormatBytes(MemStatus.ullAvailPhys));
  
  // CPU count
  FEnvironmentInfo.AddOrSetValue('CPU Count', IntToStr(System.CPUCount));
  
  // Timestamp
  FEnvironmentInfo.AddOrSetValue('Report Time', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
end;

function TStressTestReport.GenerateText: string;
var
  SB: TStringBuilder;
  R: TStressTestResult;
  Pair: TPair<string, string>;
  ErrMsg: string;
begin
  SB := TStringBuilder.Create;
  try
    SB.AppendLine('=' + StringOfChar('=', 78));
    SB.AppendLine(FTitle);
    SB.AppendLine('=' + StringOfChar('=', 78));
    SB.AppendLine;
    
    // Environment
    SB.AppendLine('Environment:');
    SB.AppendLine('-' + StringOfChar('-', 38));
    for Pair in FEnvironmentInfo do
      SB.AppendFormat('  %s: %s', [Pair.Key, Pair.Value]).AppendLine;
    SB.AppendLine;
    
    // Results
    for R in FResults do
    begin
      SB.AppendLine('-' + StringOfChar('-', 78));
      SB.AppendFormat('Test: %s', [R.TestName]).AppendLine;
      SB.AppendFormat('Status: %s', [R.GetStatusString]).AppendLine;
      SB.AppendFormat('Duration: %.2f sec', [R.DurationSec]).AppendLine;
      SB.AppendFormat('Threads: %d', [R.ThreadCount]).AppendLine;
      SB.AppendLine;
      
      SB.AppendLine('Throughput:');
      SB.AppendFormat('  Total Operations: %d', [R.Throughput.TotalOperations]).AppendLine;
      SB.AppendFormat('  Success Count: %d', [R.Throughput.SuccessCount]).AppendLine;
      SB.AppendFormat('  Failure Count: %d', [R.Throughput.FailureCount]).AppendLine;
      SB.AppendFormat('  Ops/Second: %.2f', [R.Throughput.OpsPerSecond]).AppendLine;
      SB.AppendFormat('  Success Rate: %.2f%%', [R.Throughput.SuccessRate * 100]).AppendLine;
      SB.AppendLine;
      
      SB.AppendLine('Latency:');
      SB.AppendFormat('  Min: %.2f ms', [R.Latency.MinMs]).AppendLine;
      SB.AppendFormat('  Max: %.2f ms', [R.Latency.MaxMs]).AppendLine;
      SB.AppendFormat('  Mean: %.2f ms', [R.Latency.MeanMs]).AppendLine;
      SB.AppendFormat('  P95: %.2f ms', [R.Latency.P95Ms]).AppendLine;
      SB.AppendFormat('  P99: %.2f ms', [R.Latency.P99Ms]).AppendLine;
      SB.AppendLine;
      
      SB.AppendLine('Memory:');
      SB.AppendFormat('  Before: %s', [R.MemoryBefore.ToString]).AppendLine;
      SB.AppendFormat('  After: %s', [R.MemoryAfter.ToString]).AppendLine;
      SB.AppendFormat('  Peak: %s', [R.MemoryPeak.ToString]).AppendLine;
      SB.AppendFormat('  Leak: %s', [TMemoryStats.FormatBytes(R.MemoryLeakBytes)]).AppendLine;
      SB.AppendLine;
      
      if R.ErrorCount > 0 then
      begin
        SB.AppendFormat('Errors (%d):', [R.ErrorCount]).AppendLine;
        for ErrMsg in R.Errors do
          SB.AppendFormat('  - %s', [ErrMsg]).AppendLine;
        SB.AppendLine;
      end;
    end;
    
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TStressTestReport.GenerateJSON: string;
var
  Root, EnvObj, ResultObj, ThroughputObj, LatencyObj, MemoryObj: TJSONObject;
  ResultsArr, ErrorsArr: TJSONArray;
  R: TStressTestResult;
  Pair: TPair<string, string>;
  ErrMsg: string;
begin
  Root := TJSONObject.Create;
  try
    Root.AddPair('title', FTitle);
    Root.AddPair('timestamp', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', FTimestamp));
    
    // Environment
    EnvObj := TJSONObject.Create;
    for Pair in FEnvironmentInfo do
      EnvObj.AddPair(Pair.Key, Pair.Value);
    Root.AddPair('environment', EnvObj);
    
    // Results
    ResultsArr := TJSONArray.Create;
    for R in FResults do
    begin
      ResultObj := TJSONObject.Create;
      ResultObj.AddPair('name', R.TestName);
      ResultObj.AddPair('status', R.GetStatusString);
      ResultObj.AddPair('duration_sec', TJSONNumber.Create(R.DurationSec));
      ResultObj.AddPair('threads', TJSONNumber.Create(R.ThreadCount));
      
      ThroughputObj := TJSONObject.Create;
      ThroughputObj.AddPair('total_ops', TJSONNumber.Create(R.Throughput.TotalOperations));
      ThroughputObj.AddPair('success', TJSONNumber.Create(R.Throughput.SuccessCount));
      ThroughputObj.AddPair('failure', TJSONNumber.Create(R.Throughput.FailureCount));
      ThroughputObj.AddPair('ops_per_sec', TJSONNumber.Create(R.Throughput.OpsPerSecond));
      ThroughputObj.AddPair('success_rate', TJSONNumber.Create(R.Throughput.SuccessRate));
      ResultObj.AddPair('throughput', ThroughputObj);
      
      LatencyObj := TJSONObject.Create;
      LatencyObj.AddPair('min_ms', TJSONNumber.Create(R.Latency.MinMs));
      LatencyObj.AddPair('max_ms', TJSONNumber.Create(R.Latency.MaxMs));
      LatencyObj.AddPair('mean_ms', TJSONNumber.Create(R.Latency.MeanMs));
      LatencyObj.AddPair('p95_ms', TJSONNumber.Create(R.Latency.P95Ms));
      LatencyObj.AddPair('p99_ms', TJSONNumber.Create(R.Latency.P99Ms));
      ResultObj.AddPair('latency', LatencyObj);
      
      MemoryObj := TJSONObject.Create;
      MemoryObj.AddPair('leak_bytes', TJSONNumber.Create(R.MemoryLeakBytes));
      MemoryObj.AddPair('peak_working_set', TJSONNumber.Create(R.MemoryPeak.WorkingSetSize));
      ResultObj.AddPair('memory', MemoryObj);
      
      ErrorsArr := TJSONArray.Create;
      for ErrMsg in R.Errors do
        ErrorsArr.Add(ErrMsg);
      ResultObj.AddPair('errors', ErrorsArr);
      
      ResultsArr.Add(ResultObj);
    end;
    Root.AddPair('results', ResultsArr);
    
    Result := Root.Format(2);
  finally
    Root.Free;
  end;
end;

function TStressTestReport.GenerateHTML: string;
var
  SB: TStringBuilder;
  R: TStressTestResult;
  Pair: TPair<string, string>;
  StatusClass: string;
  ErrMsg: string;
begin
  SB := TStringBuilder.Create;
  try
    SB.AppendLine('<!DOCTYPE html>');
    SB.AppendLine('<html>');
    SB.AppendLine('<head>');
    SB.AppendLine('  <meta charset="UTF-8">');
    SB.AppendFormat('  <title>%s</title>', [FTitle]).AppendLine;
    SB.AppendLine('  <style>');
    SB.AppendLine('    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 20px; background: #f5f5f5; }');
    SB.AppendLine('    .container { max-width: 1200px; margin: 0 auto; }');
    SB.AppendLine('    h1 { color: #333; border-bottom: 2px solid #007bff; padding-bottom: 10px; }');
    SB.AppendLine('    h2 { color: #555; margin-top: 30px; }');
    SB.AppendLine('    .card { background: white; border-radius: 8px; padding: 20px; margin: 15px 0; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }');
    SB.AppendLine('    .status-completed { color: #28a745; font-weight: bold; }');
    SB.AppendLine('    .status-failed { color: #dc3545; font-weight: bold; }');
    SB.AppendLine('    .status-aborted { color: #ffc107; font-weight: bold; }');
    SB.AppendLine('    table { width: 100%; border-collapse: collapse; margin: 10px 0; }');
    SB.AppendLine('    th, td { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }');
    SB.AppendLine('    th { background: #f8f9fa; font-weight: 600; }');
    SB.AppendLine('    .metric { display: inline-block; padding: 15px 20px; margin: 5px; background: #e9ecef; border-radius: 8px; text-align: center; }');
    SB.AppendLine('    .metric-value { font-size: 24px; font-weight: bold; color: #007bff; }');
    SB.AppendLine('    .metric-label { font-size: 12px; color: #666; }');
    SB.AppendLine('    .errors { background: #fff5f5; border-left: 4px solid #dc3545; padding: 10px; margin: 10px 0; }');
    SB.AppendLine('    .success-bar { height: 20px; background: #28a745; border-radius: 10px; }');
    SB.AppendLine('    .bar-container { background: #dc3545; border-radius: 10px; overflow: hidden; }');
    SB.AppendLine('  </style>');
    SB.AppendLine('</head>');
    SB.AppendLine('<body>');
    SB.AppendLine('<div class="container">');
    SB.AppendFormat('<h1>%s</h1>', [FTitle]).AppendLine;
    
    // Environment
    SB.AppendLine('<div class="card">');
    SB.AppendLine('<h2>Environment</h2>');
    SB.AppendLine('<table>');
    for Pair in FEnvironmentInfo do
      SB.AppendFormat('<tr><th>%s</th><td>%s</td></tr>', [Pair.Key, Pair.Value]).AppendLine;
    SB.AppendLine('</table>');
    SB.AppendLine('</div>');
    
    // Results
    for R in FResults do
    begin
      case R.Status of
        stsCompleted: StatusClass := 'status-completed';
        stsFailed: StatusClass := 'status-failed';
        stsAborted: StatusClass := 'status-aborted';
      else
        StatusClass := '';
      end;
      
      SB.AppendLine('<div class="card">');
      SB.AppendFormat('<h2>%s <span class="%s">(%s)</span></h2>', 
        [R.TestName, StatusClass, R.GetStatusString]).AppendLine;
      
      // Metrics
      SB.AppendLine('<div>');
      SB.AppendFormat('<div class="metric"><div class="metric-value">%.2f</div><div class="metric-label">Duration (sec)</div></div>', [R.DurationSec]).AppendLine;
      SB.AppendFormat('<div class="metric"><div class="metric-value">%d</div><div class="metric-label">Threads</div></div>', [R.ThreadCount]).AppendLine;
      SB.AppendFormat('<div class="metric"><div class="metric-value">%.0f</div><div class="metric-label">Ops/sec</div></div>', [R.Throughput.OpsPerSecond]).AppendLine;
      SB.AppendFormat('<div class="metric"><div class="metric-value">%.1f%%</div><div class="metric-label">Success Rate</div></div>', [R.Throughput.SuccessRate * 100]).AppendLine;
      SB.AppendFormat('<div class="metric"><div class="metric-value">%.2f</div><div class="metric-label">P99 Latency (ms)</div></div>', [R.Latency.P99Ms]).AppendLine;
      SB.AppendFormat('<div class="metric"><div class="metric-value">%s</div><div class="metric-label">Memory Leak</div></div>', [TMemoryStats.FormatBytes(R.MemoryLeakBytes)]).AppendLine;
      SB.AppendLine('</div>');
      
      // Success rate bar
      SB.AppendLine('<h3>Success Rate</h3>');
      SB.AppendLine('<div class="bar-container">');
      SB.AppendFormat('<div class="success-bar" style="width: %.1f%%"></div>', [R.Throughput.SuccessRate * 100]).AppendLine;
      SB.AppendLine('</div>');
      
      // Latency table
      SB.AppendLine('<h3>Latency Distribution</h3>');
      SB.AppendLine('<table>');
      SB.AppendLine('<tr><th>Metric</th><th>Value</th></tr>');
      SB.AppendFormat('<tr><td>Min</td><td>%.2f ms</td></tr>', [R.Latency.MinMs]).AppendLine;
      SB.AppendFormat('<tr><td>Mean</td><td>%.2f ms</td></tr>', [R.Latency.MeanMs]).AppendLine;
      SB.AppendFormat('<tr><td>P50</td><td>%.2f ms</td></tr>', [R.Latency.P50Ms]).AppendLine;
      SB.AppendFormat('<tr><td>P90</td><td>%.2f ms</td></tr>', [R.Latency.P90Ms]).AppendLine;
      SB.AppendFormat('<tr><td>P95</td><td>%.2f ms</td></tr>', [R.Latency.P95Ms]).AppendLine;
      SB.AppendFormat('<tr><td>P99</td><td>%.2f ms</td></tr>', [R.Latency.P99Ms]).AppendLine;
      SB.AppendFormat('<tr><td>Max</td><td>%.2f ms</td></tr>', [R.Latency.MaxMs]).AppendLine;
      SB.AppendLine('</table>');
      
      // Memory
      SB.AppendLine('<h3>Memory Usage</h3>');
      SB.AppendLine('<table>');
      SB.AppendLine('<tr><th>Metric</th><th>Before</th><th>After</th><th>Peak</th></tr>');
      SB.AppendFormat('<tr><td>Working Set</td><td>%s</td><td>%s</td><td>%s</td></tr>', 
        [TMemoryStats.FormatBytes(R.MemoryBefore.WorkingSetSize),
         TMemoryStats.FormatBytes(R.MemoryAfter.WorkingSetSize),
         TMemoryStats.FormatBytes(R.MemoryPeak.WorkingSetSize)]).AppendLine;
      SB.AppendFormat('<tr><td>Heap</td><td>%s</td><td>%s</td><td>-</td></tr>',
        [TMemoryStats.FormatBytes(R.MemoryBefore.HeapAllocated),
         TMemoryStats.FormatBytes(R.MemoryAfter.HeapAllocated)]).AppendLine;
      SB.AppendFormat('<tr><td>Handles</td><td>%d</td><td>%d</td><td>-</td></tr>',
        [R.MemoryBefore.HandleCount, R.MemoryAfter.HandleCount]).AppendLine;
      SB.AppendLine('</table>');
      
      // Errors
      if R.ErrorCount > 0 then
      begin
        SB.AppendFormat('<h3>Errors (%d)</h3>', [R.ErrorCount]).AppendLine;
        SB.AppendLine('<div class="errors">');
        for ErrMsg in R.Errors do
          SB.AppendFormat('<div>%s</div>', [ErrMsg]).AppendLine;
        SB.AppendLine('</div>');
      end;
      
      SB.AppendLine('</div>');
    end;
    
    SB.AppendLine('</div>');
    SB.AppendLine('</body>');
    SB.AppendLine('</html>');
    
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TStressTestReport.GenerateCSV: string;
var
  SB: TStringBuilder;
  R: TStressTestResult;
begin
  SB := TStringBuilder.Create;
  try
    // Header
    SB.AppendLine('Test,Status,Duration,Threads,TotalOps,SuccessCount,FailureCount,OpsPerSec,SuccessRate,MinLatency,MeanLatency,P95Latency,P99Latency,MaxLatency,MemoryLeak,Errors');
    
    // Data
    for R in FResults do
    begin
      SB.AppendFormat('%s,%s,%.2f,%d,%d,%d,%d,%.2f,%.4f,%.2f,%.2f,%.2f,%.2f,%.2f,%d,%d',
        [R.TestName, R.GetStatusString, R.DurationSec, R.ThreadCount,
         R.Throughput.TotalOperations, R.Throughput.SuccessCount, R.Throughput.FailureCount,
         R.Throughput.OpsPerSecond, R.Throughput.SuccessRate,
         R.Latency.MinMs, R.Latency.MeanMs, R.Latency.P95Ms, R.Latency.P99Ms, R.Latency.MaxMs,
         R.MemoryLeakBytes, R.ErrorCount]).AppendLine;
    end;
    
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TStressTestReport.Generate(Format: TStressReportFormat): string;
begin
  CollectEnvironmentInfo;
  
  case Format of
    srfText: Result := GenerateText;
    srfJSON: Result := GenerateJSON;
    srfHTML: Result := GenerateHTML;
    srfCSV: Result := GenerateCSV;
  else
    Result := GenerateText;
  end;
end;

procedure TStressTestReport.SaveToFile(const FileName: string; Format: TStressReportFormat);
begin
  TFile.WriteAllText(FileName, Generate(Format), TEncoding.UTF8);
end;

// ============================================================================
// TStressTestRunner
// ============================================================================

constructor TStressTestRunner.Create;
begin
  inherited;
  FTests := TObjectList<TStressTest>.Create(True);
  FConfig := TStressTestConfig.Create;
  FReport := TStressTestReport.Create;
  FMemoryDetector := TMemoryLeakDetector.Create;
  FStabilityMonitor := TStabilityMonitor.Create;
end;

destructor TStressTestRunner.Destroy;
begin
  Abort;
  FStabilityMonitor.Free;
  FMemoryDetector.Free;
  FReport.Free;
  FConfig.Free;
  FTests.Free;
  inherited;
end;

procedure TStressTestRunner.AddTest(ATest: TStressTest);
begin
  FTests.Add(ATest);
end;

procedure TStressTestRunner.ClearTests;
begin
  FTests.Clear;
end;

procedure TStressTestRunner.Run;
var
  Test: TStressTest;
  TestResult: TStressTestResult;
begin
  if FIsRunning then Exit;
  
  FIsRunning := True;
  FAbortRequested := False;
  FReport.Clear;
  
  try
    for Test in FTests do
    begin
      if FAbortRequested then Break;
      
      // Apply global config to test
      Test.Config.DurationSec := FConfig.DurationSec;
      Test.Config.ThreadCount := FConfig.ThreadCount;
      Test.Config.RampUpSec := FConfig.RampUpSec;
      Test.Config.RampDownSec := FConfig.RampDownSec;
      Test.Config.LoadProfile := FConfig.LoadProfile;
      Test.Config.TargetOpsPerSec := FConfig.TargetOpsPerSec;
      Test.Config.MaxErrors := FConfig.MaxErrors;
      Test.Config.MemoryLeakThresholdBytes := FConfig.MemoryLeakThresholdBytes;
      
      TestResult := RunTest(Test);
      FReport.AddResult(TestResult);
      
      if Assigned(FOnTestComplete) then
        FOnTestComplete(Self);
    end;
  finally
    FIsRunning := False;
  end;
end;

function TStressTestRunner.RunTest(ATest: TStressTest): TStressTestResult;
begin
  if Assigned(FOnProgress) then
    FOnProgress(Self, 0, Format('Starting test: %s', [ATest.Name]));
  
  try
    Result := ATest.Run;
  except
    on E: Exception do
    begin
      Result := Default(TStressTestResult);
      Result.TestName := ATest.Name;
      Result.Status := stsFailed;
      SetLength(Result.Errors, 1);
      Result.Errors[0] := E.Message;
      Result.ErrorCount := 1;
      
      if Assigned(FOnError) then
        FOnError(Self, E.Message);
    end;
  end;
  
  if Assigned(FOnProgress) then
    FOnProgress(Self, 100, Format('Completed test: %s (%s)', [ATest.Name, Result.GetStatusString]));
end;

procedure TStressTestRunner.Abort;
var
  Test: TStressTest;
begin
  FAbortRequested := True;
  
  for Test in FTests do
    Test.Abort;
end;

function TStressTestRunner.IsRunning: Boolean;
begin
  Result := FIsRunning;
end;

// ============================================================================
// Helper function
// ============================================================================

function RunStressTest(const TestName: string; WorkerProc: TLoadWorkerProc;
  DurationSec: Integer; ThreadCount: Integer): TStressTestResult;
var
  LoadGen: TLoadGenerator;
  MemDetect: TMemoryLeakDetector;
  SW: TStopwatch;
begin
  Result := Default(TStressTestResult);
  Result.TestName := TestName;
  Result.StartTime := Now;
  Result.ThreadCount := ThreadCount;
  
  LoadGen := TLoadGenerator.Create;
  MemDetect := TMemoryLeakDetector.Create;
  SW := TStopwatch.StartNew;
  
  try
    LoadGen.ThreadCount := ThreadCount;
    LoadGen.DurationSec := DurationSec;
    
    MemDetect.Start;
    Result.MemoryBefore := MemDetect.GetBaseline;
    
    LoadGen.Start(WorkerProc);
    LoadGen.WaitFor;
    
    SW.Stop;
    MemDetect.Stop;
    
    Result.EndTime := Now;
    Result.DurationSec := SW.Elapsed.TotalSeconds;
    Result.MemoryAfter := MemDetect.GetCurrent;
    Result.MemoryPeak := MemDetect.GetPeak;
    Result.MemoryLeakBytes := MemDetect.GetLeakBytes;
    
    Result.Throughput.TotalOperations := LoadGen.TotalOperations;
    Result.Throughput.SuccessCount := LoadGen.TotalOperations;
    Result.Throughput.DurationSec := Result.DurationSec;
    if Result.DurationSec > 0 then
      Result.Throughput.OpsPerSecond := Result.Throughput.TotalOperations / Result.DurationSec;
    Result.Throughput.SuccessRate := 1.0;
    
    Result.Status := stsCompleted;
    
  finally
    MemDetect.Free;
    LoadGen.Free;
  end;
end;

end.
