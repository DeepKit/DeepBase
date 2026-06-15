{ ============================================================================
  DeepBase.Benchmark - Performance Benchmark Framework
  
  A lightweight benchmarking framework for measuring execution time,
  memory usage, and generating performance reports.
  
  Features:
  - High-precision timing using QueryPerformanceCounter
  - Memory allocation tracking
  - Statistical analysis (min, max, avg, stddev, percentiles)
  - Warm-up iterations support
  - Multiple output formats (Text, JSON, CSV, Markdown)
  - Comparison between benchmark runs
  
  Usage:
    var Bench := TBenchmark.Create('MyOperation');
    try
      Bench.WarmupIterations := 5;
      Bench.Iterations := 100;
      Bench.Run(
        procedure
        begin
          // Code to benchmark
        end);
      Bench.Report.SaveToFile('benchmark.md', TReportFormat.Markdown);
    finally
      Bench.Free;
    end;
  ============================================================================ }

unit DeepBase.Benchmark;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Generics.Defaults,
  System.Math,
  System.JSON,
  System.Diagnostics,
  Winapi.Windows,
  Winapi.PsAPI;

type
  // ============================================================================
  // Timing Types
  // ============================================================================
  
  /// <summary>
  /// High-precision stopwatch using QueryPerformanceCounter
  /// </summary>
  THiResStopwatch = record
  private
    FStartTick: Int64;
    FStopTick: Int64;
    FFrequency: Int64;
    FIsRunning: Boolean;
    class var FFrequencyInitialized: Boolean;
    class var FGlobalFrequency: Int64;
  public
    class function Create: THiResStopwatch; static;
    procedure Start;
    procedure Stop;
    procedure Reset;
    function ElapsedTicks: Int64;
    function ElapsedMicroseconds: Double;
    function ElapsedMilliseconds: Double;
    function ElapsedSeconds: Double;
    property IsRunning: Boolean read FIsRunning;
  end;
  
  // ============================================================================
  // Memory Tracking
  // ============================================================================
  
  TMemorySnapshot = record
    WorkingSetSize: Int64;       // Physical memory
    PagefileUsage: Int64;        // Virtual memory
    PrivateUsage: Int64;         // Private bytes
    HeapAllocated: Int64;        // Delphi heap
    Timestamp: TDateTime;
    
    class function Capture: TMemorySnapshot; static;
    function Subtract(const Other: TMemorySnapshot): TMemorySnapshot;
    function ToString: string;
  end;
  
  // ============================================================================
  // Statistics
  // ============================================================================
  
  TBenchmarkStats = record
    Count: Integer;
    Min: Double;
    Max: Double;
    Sum: Double;
    Mean: Double;
    Variance: Double;
    StdDev: Double;
    Median: Double;
    P90: Double;               // 90th percentile
    P95: Double;               // 95th percentile
    P99: Double;               // 99th percentile
    
    class function Calculate(const Values: TArray<Double>): TBenchmarkStats; static;
    function ToString(const TimeUnit: string = 'ms'): string;
  end;
  
  // ============================================================================
  // Benchmark Result
  // ============================================================================
  
  TBenchmarkResult = record
    Name: string;
    Timestamp: TDateTime;
    Iterations: Integer;
    WarmupIterations: Integer;
    
    // Timing results (microseconds)
    TimingStats: TBenchmarkStats;
    RawTimings: TArray<Double>;
    
    // Memory results
    MemoryBefore: TMemorySnapshot;
    MemoryAfter: TMemorySnapshot;
    MemoryDelta: TMemorySnapshot;
    
    // Additional metadata
    Tags: TArray<TPair<string, string>>;
    
    function ThroughputPerSecond: Double;
  end;
  
  // ============================================================================
  // Report Format
  // ============================================================================
  
  TReportFormat = (rfText, rfJSON, rfCSV, rfMarkdown, rfHTML);
  
  /// <summary>
  /// Benchmark report generator
  /// </summary>
  TBenchmarkReport = class
  private
    FResults: TList<TBenchmarkResult>;
    FTitle: string;
    FDescription: string;
    FEnvironmentInfo: TDictionary<string, string>;
    
    function GenerateText: string;
    function GenerateJSON: string;
    function GenerateCSV: string;
    function GenerateMarkdown: string;
    function GenerateHTML: string;
  public
    constructor Create(const ATitle: string = 'Benchmark Report');
    destructor Destroy; override;
    
    procedure AddResult(const Result: TBenchmarkResult);
    procedure Clear;
    
    function Generate(Format: TReportFormat): string;
    procedure SaveToFile(const FileName: string; Format: TReportFormat);
    procedure SaveToStream(Stream: TStream; Format: TReportFormat);
    
    procedure CollectEnvironmentInfo;
    
    property Title: string read FTitle write FTitle;
    property Description: string read FDescription write FDescription;
    property Results: TList<TBenchmarkResult> read FResults;
    property EnvironmentInfo: TDictionary<string, string> read FEnvironmentInfo;
  end;
  
  // ============================================================================
  // Benchmark Runner
  // ============================================================================
  
  TBenchmarkProc = reference to procedure;
  TBenchmarkSetup = reference to procedure;
  TBenchmarkTeardown = reference to procedure;
  
  /// <summary>
  /// Main benchmark runner class
  /// </summary>
  TBenchmark = class
  private
    FName: string;
    FIterations: Integer;
    FWarmupIterations: Integer;
    FTrackMemory: Boolean;
    FSetup: TBenchmarkSetup;
    FTeardown: TBenchmarkTeardown;
    FLastResult: TBenchmarkResult;
    FReport: TBenchmarkReport;
    FTags: TDictionary<string, string>;
    
    function RunSingleIteration(const Proc: TBenchmarkProc): Double;
  public
    constructor Create(const AName: string);
    destructor Destroy; override;
    
    /// <summary>Run benchmark and return result</summary>
    function Run(const Proc: TBenchmarkProc): TBenchmarkResult;
    
    /// <summary>Run benchmark with setup/teardown per iteration</summary>
    function RunWithContext(const Proc: TBenchmarkProc;
      const Setup: TBenchmarkSetup;
      const Teardown: TBenchmarkTeardown): TBenchmarkResult;
    
    /// <summary>Run multiple benchmarks and compare</summary>
    class function Compare(const Benchmarks: TArray<TPair<string, TBenchmarkProc>>;
      Iterations: Integer = 100): TBenchmarkReport;
    
    /// <summary>Add tag for result metadata</summary>
    procedure AddTag(const Key, Value: string);
    
    property Name: string read FName write FName;
    property Iterations: Integer read FIterations write FIterations;
    property WarmupIterations: Integer read FWarmupIterations write FWarmupIterations;
    property TrackMemory: Boolean read FTrackMemory write FTrackMemory;
    property Setup: TBenchmarkSetup read FSetup write FSetup;
    property Teardown: TBenchmarkTeardown read FTeardown write FTeardown;
    property LastResult: TBenchmarkResult read FLastResult;
    property Report: TBenchmarkReport read FReport;
  end;
  
  // ============================================================================
  // Scoped Timer (RAII style)
  // ============================================================================
  
  /// <summary>
  /// Automatic timing scope - logs elapsed time on scope exit
  /// </summary>
  IScopedTimer = interface
    function ElapsedMs: Double;
    function ElapsedUs: Double;
  end;
  
  TScopedTimer = class(TInterfacedObject, IScopedTimer)
  private
    FName: string;
    FStopwatch: THiResStopwatch;
    FCallback: TProc<string, Double>;
  public
    constructor Create(const AName: string; ACallback: TProc<string, Double> = nil);
    destructor Destroy; override;
    function ElapsedMs: Double;
    function ElapsedUs: Double;
  end;

/// <summary>Create a scoped timer that logs on destruction</summary>
function TimeScope(const Name: string; Callback: TProc<string, Double> = nil): IScopedTimer;

/// <summary>Measure single execution time in milliseconds</summary>
function MeasureTime(const Proc: TBenchmarkProc): Double;

/// <summary>Measure average execution time over N iterations</summary>
function MeasureTimeAvg(const Proc: TBenchmarkProc; Iterations: Integer = 100): Double;

/// <summary>Get current memory usage</summary>
function GetCurrentMemoryUsage: Int64;

implementation

// ============================================================================
// THiResStopwatch
// ============================================================================

class function THiResStopwatch.Create: THiResStopwatch;
begin
  Result.FStartTick := 0;
  Result.FStopTick := 0;
  Result.FIsRunning := False;
  
  if not FFrequencyInitialized then
  begin
    QueryPerformanceFrequency(FGlobalFrequency);
    FFrequencyInitialized := True;
  end;
  Result.FFrequency := FGlobalFrequency;
end;

procedure THiResStopwatch.Start;
begin
  if FIsRunning then
    Exit;

  QueryPerformanceCounter(FStartTick);
  FIsRunning := True;
end;

procedure THiResStopwatch.Stop;
var
  CurrentTick: Int64;
begin
  if not FIsRunning then
    Exit;

  QueryPerformanceCounter(CurrentTick);
  FStopTick := FStopTick + (CurrentTick - FStartTick);
  FStartTick := 0;
  FIsRunning := False;
end;

procedure THiResStopwatch.Reset;
begin
  FStartTick := 0;
  FStopTick := 0;
  FIsRunning := False;
end;

function THiResStopwatch.ElapsedTicks: Int64;
var
  CurrentTick: Int64;
begin
  if FIsRunning then
  begin
    QueryPerformanceCounter(CurrentTick);
    Result := FStopTick + (CurrentTick - FStartTick);
  end
  else
    Result := FStopTick;
end;

function THiResStopwatch.ElapsedMicroseconds: Double;
begin
  Result := (ElapsedTicks * 1000000.0) / FFrequency;
end;

function THiResStopwatch.ElapsedMilliseconds: Double;
begin
  Result := (ElapsedTicks * 1000.0) / FFrequency;
end;

function THiResStopwatch.ElapsedSeconds: Double;
begin
  Result := ElapsedTicks / FFrequency;
end;

// ============================================================================
// TMemorySnapshot
// ============================================================================

class function TMemorySnapshot.Capture: TMemorySnapshot;
var
  ProcessHandle: THandle;
  MemCounters: TProcessMemoryCounters;
  HeapStatus: THeapStatus;
begin
  Result.Timestamp := Now;
  Result.WorkingSetSize := 0;
  Result.PagefileUsage := 0;
  Result.PrivateUsage := 0;
  Result.HeapAllocated := 0;
  
  ProcessHandle := GetCurrentProcess;
  MemCounters.cb := SizeOf(MemCounters);
  
  if GetProcessMemoryInfo(ProcessHandle, @MemCounters, SizeOf(MemCounters)) then
  begin
    Result.WorkingSetSize := MemCounters.WorkingSetSize;
    Result.PagefileUsage := MemCounters.PagefileUsage;
    Result.PrivateUsage := MemCounters.PagefileUsage;
  end;
  
  {$WARN SYMBOL_DEPRECATED OFF}
  HeapStatus := GetHeapStatus;
  Result.HeapAllocated := HeapStatus.TotalAllocated;
  {$WARN SYMBOL_DEPRECATED ON}
end;

function TMemorySnapshot.Subtract(const Other: TMemorySnapshot): TMemorySnapshot;
begin
  Result.Timestamp := Now;
  Result.WorkingSetSize := Self.WorkingSetSize - Other.WorkingSetSize;
  Result.PagefileUsage := Self.PagefileUsage - Other.PagefileUsage;
  Result.PrivateUsage := Self.PrivateUsage - Other.PrivateUsage;
  Result.HeapAllocated := Self.HeapAllocated - Other.HeapAllocated;
end;

function TMemorySnapshot.ToString: string;
begin
  Result := Format('Working: %.2f MB, Pagefile: %.2f MB, Heap: %.2f MB',
    [WorkingSetSize / (1024 * 1024),
     PagefileUsage / (1024 * 1024),
     HeapAllocated / (1024 * 1024)]);
end;

// ============================================================================
// TBenchmarkStats
// ============================================================================

class function TBenchmarkStats.Calculate(const Values: TArray<Double>): TBenchmarkStats;
var
  I, N: Integer;
  Sorted: TArray<Double>;
  SumSq: Double;
begin
  N := Length(Values);
  if N = 0 then
  begin
    Result := Default(TBenchmarkStats);
    Exit;
  end;
  
  Result.Count := N;
  
  // Basic stats
  Result.Min := Values[0];
  Result.Max := Values[0];
  Result.Sum := 0;
  
  for I := 0 to N - 1 do
  begin
    if Values[I] < Result.Min then
      Result.Min := Values[I];
    if Values[I] > Result.Max then
      Result.Max := Values[I];
    Result.Sum := Result.Sum + Values[I];
  end;
  
  Result.Mean := Result.Sum / N;
  
  // Variance and StdDev
  SumSq := 0;
  for I := 0 to N - 1 do
    SumSq := SumSq + Sqr(Values[I] - Result.Mean);
  
  if N > 1 then
    Result.Variance := SumSq / (N - 1)
  else
    Result.Variance := 0;
  
  Result.StdDev := Sqrt(Result.Variance);
  
  // Percentiles (need sorted array)
  Sorted := Copy(Values);
  TArray.Sort<Double>(Sorted);
  
  if Odd(N) then
    Result.Median := Sorted[N div 2]
  else
    Result.Median := (Sorted[(N div 2) - 1] + Sorted[N div 2]) / 2;
  Result.P90 := Sorted[Trunc(N * 0.90)];
  Result.P95 := Sorted[Trunc(N * 0.95)];
  Result.P99 := Sorted[System.Math.Min(Trunc(N * 0.99), N - 1)];
end;

function TBenchmarkStats.ToString(const TimeUnit: string): string;
begin
  Result := Format(
    'Count: %d, Min: %.3f %s, Max: %.3f %s, Mean: %.3f %s, StdDev: %.3f %s, ' +
    'Median: %.3f %s, P95: %.3f %s, P99: %.3f %s',
    [Count,
     Min, TimeUnit, Max, TimeUnit, Mean, TimeUnit, StdDev, TimeUnit,
     Median, TimeUnit, P95, TimeUnit, P99, TimeUnit]);
end;

// ============================================================================
// TBenchmarkResult
// ============================================================================

function TBenchmarkResult.ThroughputPerSecond: Double;
begin
  if TimingStats.Mean > 0 then
    Result := 1000000.0 / TimingStats.Mean  // Mean is in microseconds
  else
    Result := 0;
end;

// ============================================================================
// TBenchmarkReport
// ============================================================================

constructor TBenchmarkReport.Create(const ATitle: string);
begin
  inherited Create;
  FResults := TList<TBenchmarkResult>.Create;
  FEnvironmentInfo := TDictionary<string, string>.Create;
  FTitle := ATitle;
  FDescription := '';
end;

destructor TBenchmarkReport.Destroy;
begin
  FreeAndNil(FEnvironmentInfo);
  FreeAndNil(FResults);
  inherited;
end;

procedure TBenchmarkReport.AddResult(const Result: TBenchmarkResult);
begin
  FResults.Add(Result);
end;

procedure TBenchmarkReport.Clear;
begin
  FResults.Clear;
end;

procedure TBenchmarkReport.CollectEnvironmentInfo;
begin
  FEnvironmentInfo.Clear;
  
  FEnvironmentInfo.Add('OS', Format('%s %d.%d.%d',
    [TOSVersion.Name, TOSVersion.Major, TOSVersion.Minor, TOSVersion.Build]));
  FEnvironmentInfo.Add('CPU Cores', IntToStr(System.CPUCount));
  FEnvironmentInfo.Add('Delphi Version', {$IFDEF VER360}'12.2 Athens'{$ELSE}'Unknown'{$ENDIF});
  FEnvironmentInfo.Add('Timestamp', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
  
  {$IFDEF WIN64}
  FEnvironmentInfo.Add('Platform', 'Win64');
  {$ELSE}
  FEnvironmentInfo.Add('Platform', 'Win32');
  {$ENDIF}
  
  {$IFDEF DEBUG}
  FEnvironmentInfo.Add('Build', 'Debug');
  {$ELSE}
  FEnvironmentInfo.Add('Build', 'Release');
  {$ENDIF}
end;

function TBenchmarkReport.Generate(Format: TReportFormat): string;
begin
  case Format of
    rfText: Result := GenerateText;
    rfJSON: Result := GenerateJSON;
    rfCSV: Result := GenerateCSV;
    rfMarkdown: Result := GenerateMarkdown;
    rfHTML: Result := GenerateHTML;
  else
    Result := GenerateText;
  end;
end;

procedure TBenchmarkReport.SaveToFile(const FileName: string; Format: TReportFormat);
var
  Content: string;
  Stream: TFileStream;
  Bytes: TBytes;
begin
  Content := Generate(Format);
  Stream := TFileStream.Create(FileName, fmCreate);
  try
    Bytes := TEncoding.UTF8.GetBytes(Content);
    Stream.WriteBuffer(Bytes[0], Length(Bytes));
  finally
    Stream.Free;
  end;
end;

procedure TBenchmarkReport.SaveToStream(Stream: TStream; Format: TReportFormat);
var
  Content: string;
  Bytes: TBytes;
begin
  Content := Generate(Format);
  Bytes := TEncoding.UTF8.GetBytes(Content);
  Stream.WriteBuffer(Bytes[0], Length(Bytes));
end;

function TBenchmarkReport.GenerateText: string;
var
  SB: TStringBuilder;
  R: TBenchmarkResult;
  Pair: TPair<string, string>;
begin
  SB := TStringBuilder.Create;
  try
    SB.AppendLine('=' + StringOfChar('=', 70));
    SB.AppendLine(FTitle);
    SB.AppendLine('=' + StringOfChar('=', 70));
    
    if FDescription <> '' then
    begin
      SB.AppendLine(FDescription);
      SB.AppendLine;
    end;
    
    // Environment
    if FEnvironmentInfo.Count > 0 then
    begin
      SB.AppendLine('Environment:');
      for Pair in FEnvironmentInfo do
        SB.AppendFormat('  %s: %s', [Pair.Key, Pair.Value]).AppendLine;
      SB.AppendLine;
    end;
    
    // Results
    for R in FResults do
    begin
      SB.AppendLine('-' + StringOfChar('-', 70));
      SB.AppendFormat('Benchmark: %s', [R.Name]).AppendLine;
      SB.AppendFormat('  Iterations: %d (Warmup: %d)', [R.Iterations, R.WarmupIterations]).AppendLine;
      SB.AppendLine('  Timing (microseconds):');
      SB.AppendFormat('    Min: %.3f, Max: %.3f, Mean: %.3f', 
        [R.TimingStats.Min, R.TimingStats.Max, R.TimingStats.Mean]).AppendLine;
      SB.AppendFormat('    StdDev: %.3f, Median: %.3f',
        [R.TimingStats.StdDev, R.TimingStats.Median]).AppendLine;
      SB.AppendFormat('    P90: %.3f, P95: %.3f, P99: %.3f',
        [R.TimingStats.P90, R.TimingStats.P95, R.TimingStats.P99]).AppendLine;
      SB.AppendFormat('  Throughput: %.2f ops/sec', [R.ThroughputPerSecond]).AppendLine;
      
      if R.MemoryDelta.HeapAllocated <> 0 then
      begin
        SB.AppendLine('  Memory Delta:');
        SB.AppendFormat('    Heap: %d bytes', [R.MemoryDelta.HeapAllocated]).AppendLine;
      end;
    end;
    
    SB.AppendLine('=' + StringOfChar('=', 70));
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TBenchmarkReport.GenerateJSON: string;
var
  Root, EnvObj, ResultsArr, ResultObj, TimingObj, MemObj: TJSONObject;
  R: TBenchmarkResult;
  Pair: TPair<string, string>;
begin
  Root := TJSONObject.Create;
  try
    Root.AddPair('title', FTitle);
    Root.AddPair('description', FDescription);
    Root.AddPair('timestamp', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now));
    
    // Environment
    EnvObj := TJSONObject.Create;
    for Pair in FEnvironmentInfo do
      EnvObj.AddPair(Pair.Key, Pair.Value);
    Root.AddPair('environment', EnvObj);
    
    // Results
    ResultsArr := TJSONObject.Create;
    for R in FResults do
    begin
      ResultObj := TJSONObject.Create;
      ResultObj.AddPair('name', R.Name);
      ResultObj.AddPair('iterations', TJSONNumber.Create(R.Iterations));
      ResultObj.AddPair('warmup', TJSONNumber.Create(R.WarmupIterations));
      
      TimingObj := TJSONObject.Create;
      TimingObj.AddPair('min_us', TJSONNumber.Create(R.TimingStats.Min));
      TimingObj.AddPair('max_us', TJSONNumber.Create(R.TimingStats.Max));
      TimingObj.AddPair('mean_us', TJSONNumber.Create(R.TimingStats.Mean));
      TimingObj.AddPair('stddev_us', TJSONNumber.Create(R.TimingStats.StdDev));
      TimingObj.AddPair('median_us', TJSONNumber.Create(R.TimingStats.Median));
      TimingObj.AddPair('p90_us', TJSONNumber.Create(R.TimingStats.P90));
      TimingObj.AddPair('p95_us', TJSONNumber.Create(R.TimingStats.P95));
      TimingObj.AddPair('p99_us', TJSONNumber.Create(R.TimingStats.P99));
      ResultObj.AddPair('timing', TimingObj);
      
      MemObj := TJSONObject.Create;
      MemObj.AddPair('heap_delta', TJSONNumber.Create(R.MemoryDelta.HeapAllocated));
      ResultObj.AddPair('memory', MemObj);
      
      ResultObj.AddPair('throughput_ops', TJSONNumber.Create(R.ThroughputPerSecond));
      
      TJSONArray(ResultsArr).Add(ResultObj);
    end;
    Root.AddPair('results', ResultsArr);
    
    Result := Root.Format(2);
  finally
    Root.Free;
  end;
end;

function TBenchmarkReport.GenerateCSV: string;
var
  SB: TStringBuilder;
  R: TBenchmarkResult;
begin
  SB := TStringBuilder.Create;
  try
    // Header
    SB.AppendLine('Name,Iterations,Warmup,Min_us,Max_us,Mean_us,StdDev_us,Median_us,P90_us,P95_us,P99_us,Throughput_ops,HeapDelta_bytes');
    
    // Data rows
    for R in FResults do
    begin
      SB.AppendFormat('%s,%d,%d,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.2f,%d',
        [R.Name, R.Iterations, R.WarmupIterations,
         R.TimingStats.Min, R.TimingStats.Max, R.TimingStats.Mean,
         R.TimingStats.StdDev, R.TimingStats.Median,
         R.TimingStats.P90, R.TimingStats.P95, R.TimingStats.P99,
         R.ThroughputPerSecond, R.MemoryDelta.HeapAllocated]);
      SB.AppendLine;
    end;
    
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TBenchmarkReport.GenerateMarkdown: string;
var
  SB: TStringBuilder;
  R: TBenchmarkResult;
  Pair: TPair<string, string>;
begin
  SB := TStringBuilder.Create;
  try
    SB.AppendFormat('# %s', [FTitle]).AppendLine;
    SB.AppendLine;
    
    if FDescription <> '' then
    begin
      SB.AppendLine(FDescription);
      SB.AppendLine;
    end;
    
    // Environment
    if FEnvironmentInfo.Count > 0 then
    begin
      SB.AppendLine('## Environment');
      SB.AppendLine;
      for Pair in FEnvironmentInfo do
        SB.AppendFormat('- **%s**: %s', [Pair.Key, Pair.Value]).AppendLine;
      SB.AppendLine;
    end;
    
    // Results table
    SB.AppendLine('## Results');
    SB.AppendLine;
    SB.AppendLine('| Benchmark | Iterations | Mean (μs) | StdDev (μs) | P95 (μs) | Throughput |');
    SB.AppendLine('|-----------|------------|-----------|-------------|----------|------------|');
    
    for R in FResults do
    begin
      SB.AppendFormat('| %s | %d | %.3f | %.3f | %.3f | %.0f ops/s |',
        [R.Name, R.Iterations, R.TimingStats.Mean, R.TimingStats.StdDev,
         R.TimingStats.P95, R.ThroughputPerSecond]);
      SB.AppendLine;
    end;
    
    SB.AppendLine;
    
    // Detailed results
    SB.AppendLine('## Detailed Results');
    SB.AppendLine;
    
    for R in FResults do
    begin
      SB.AppendFormat('### %s', [R.Name]).AppendLine;
      SB.AppendLine;
      SB.AppendLine('| Metric | Value |');
      SB.AppendLine('|--------|-------|');
      SB.AppendFormat('| Iterations | %d |', [R.Iterations]).AppendLine;
      SB.AppendFormat('| Warmup | %d |', [R.WarmupIterations]).AppendLine;
      SB.AppendFormat('| Min | %.3f μs |', [R.TimingStats.Min]).AppendLine;
      SB.AppendFormat('| Max | %.3f μs |', [R.TimingStats.Max]).AppendLine;
      SB.AppendFormat('| Mean | %.3f μs |', [R.TimingStats.Mean]).AppendLine;
      SB.AppendFormat('| StdDev | %.3f μs |', [R.TimingStats.StdDev]).AppendLine;
      SB.AppendFormat('| Median | %.3f μs |', [R.TimingStats.Median]).AppendLine;
      SB.AppendFormat('| P90 | %.3f μs |', [R.TimingStats.P90]).AppendLine;
      SB.AppendFormat('| P95 | %.3f μs |', [R.TimingStats.P95]).AppendLine;
      SB.AppendFormat('| P99 | %.3f μs |', [R.TimingStats.P99]).AppendLine;
      SB.AppendFormat('| Throughput | %.2f ops/s |', [R.ThroughputPerSecond]).AppendLine;
      SB.AppendLine;
    end;
    
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TBenchmarkReport.GenerateHTML: string;
var
  SB: TStringBuilder;
  R: TBenchmarkResult;
  Pair: TPair<string, string>;
begin
  SB := TStringBuilder.Create;
  try
    SB.AppendLine('<!DOCTYPE html>');
    SB.AppendLine('<html><head>');
    SB.AppendFormat('<title>%s</title>', [FTitle]).AppendLine;
    SB.AppendLine('<style>');
    SB.AppendLine('body { font-family: Arial, sans-serif; margin: 20px; }');
    SB.AppendLine('table { border-collapse: collapse; width: 100%; margin: 20px 0; }');
    SB.AppendLine('th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }');
    SB.AppendLine('th { background-color: #4CAF50; color: white; }');
    SB.AppendLine('tr:nth-child(even) { background-color: #f2f2f2; }');
    SB.AppendLine('.metric { font-weight: bold; }');
    SB.AppendLine('</style>');
    SB.AppendLine('</head><body>');
    
    SB.AppendFormat('<h1>%s</h1>', [FTitle]).AppendLine;
    
    if FDescription <> '' then
      SB.AppendFormat('<p>%s</p>', [FDescription]).AppendLine;
    
    // Environment
    if FEnvironmentInfo.Count > 0 then
    begin
      SB.AppendLine('<h2>Environment</h2>');
      SB.AppendLine('<ul>');
      for Pair in FEnvironmentInfo do
        SB.AppendFormat('<li><strong>%s</strong>: %s</li>', [Pair.Key, Pair.Value]).AppendLine;
      SB.AppendLine('</ul>');
    end;
    
    // Results table
    SB.AppendLine('<h2>Results Summary</h2>');
    SB.AppendLine('<table>');
    SB.AppendLine('<tr><th>Benchmark</th><th>Iterations</th><th>Mean (μs)</th><th>StdDev (μs)</th><th>P95 (μs)</th><th>Throughput</th></tr>');
    
    for R in FResults do
    begin
      SB.AppendFormat('<tr><td>%s</td><td>%d</td><td>%.3f</td><td>%.3f</td><td>%.3f</td><td>%.0f ops/s</td></tr>',
        [R.Name, R.Iterations, R.TimingStats.Mean, R.TimingStats.StdDev,
         R.TimingStats.P95, R.ThroughputPerSecond]);
      SB.AppendLine;
    end;
    
    SB.AppendLine('</table>');
    SB.AppendLine('</body></html>');
    
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

// ============================================================================
// TBenchmark
// ============================================================================

constructor TBenchmark.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
  FIterations := 100;
  FWarmupIterations := 5;
  FTrackMemory := True;
  FReport := TBenchmarkReport.Create;
  FTags := TDictionary<string, string>.Create;
end;

destructor TBenchmark.Destroy;
begin
  FreeAndNil(FTags);
  FreeAndNil(FReport);
  inherited;
end;

procedure TBenchmark.AddTag(const Key, Value: string);
begin
  FTags.AddOrSetValue(Key, Value);
end;

function TBenchmark.RunSingleIteration(const Proc: TBenchmarkProc): Double;
var
  SW: THiResStopwatch;
begin
  SW := THiResStopwatch.Create;
  SW.Start;
  Proc;
  SW.Stop;
  Result := SW.ElapsedMicroseconds;
end;

function TBenchmark.Run(const Proc: TBenchmarkProc): TBenchmarkResult;
var
  I: Integer;
  Timings: TArray<Double>;
  Pair: TPair<string, string>;
begin
  Result.Name := FName;
  Result.Timestamp := Now;
  Result.Iterations := FIterations;
  Result.WarmupIterations := FWarmupIterations;
  
  // Warmup
  for I := 1 to FWarmupIterations do
  begin
    if Assigned(FSetup) then
      FSetup;
    Proc;
    if Assigned(FTeardown) then
      FTeardown;
  end;
  
  // Memory before
  if FTrackMemory then
    Result.MemoryBefore := TMemorySnapshot.Capture;
  
  // Actual benchmark
  SetLength(Timings, FIterations);
  for I := 0 to FIterations - 1 do
  begin
    if Assigned(FSetup) then
      FSetup;
    Timings[I] := RunSingleIteration(Proc);
    if Assigned(FTeardown) then
      FTeardown;
  end;
  
  // Memory after
  if FTrackMemory then
  begin
    Result.MemoryAfter := TMemorySnapshot.Capture;
    Result.MemoryDelta := Result.MemoryAfter.Subtract(Result.MemoryBefore);
  end;
  
  Result.RawTimings := Timings;
  Result.TimingStats := TBenchmarkStats.Calculate(Timings);
  
  // Copy tags
  SetLength(Result.Tags, FTags.Count);
  I := 0;
  for Pair in FTags do
  begin
    Result.Tags[I] := Pair;
    Inc(I);
  end;
  
  FLastResult := Result;
  FReport.AddResult(Result);
end;

function TBenchmark.RunWithContext(const Proc: TBenchmarkProc;
  const Setup: TBenchmarkSetup;
  const Teardown: TBenchmarkTeardown): TBenchmarkResult;
begin
  FSetup := Setup;
  FTeardown := Teardown;
  try
    Result := Run(Proc);
  finally
    FSetup := nil;
    FTeardown := nil;
  end;
end;

class function TBenchmark.Compare(const Benchmarks: TArray<TPair<string, TBenchmarkProc>>;
  Iterations: Integer): TBenchmarkReport;
var
  I: Integer;
  Bench: TBenchmark;
begin
  Result := TBenchmarkReport.Create('Benchmark Comparison');
  Result.CollectEnvironmentInfo;
  
  for I := 0 to High(Benchmarks) do
  begin
    Bench := TBenchmark.Create(Benchmarks[I].Key);
    try
      Bench.Iterations := Iterations;
      Bench.WarmupIterations := 5;
      Result.AddResult(Bench.Run(Benchmarks[I].Value));
    finally
      Bench.Free;
    end;
  end;
end;

// ============================================================================
// TScopedTimer
// ============================================================================

constructor TScopedTimer.Create(const AName: string; ACallback: TProc<string, Double>);
begin
  inherited Create;
  FName := AName;
  FCallback := ACallback;
  FStopwatch := THiResStopwatch.Create;
  FStopwatch.Start;
end;

destructor TScopedTimer.Destroy;
begin
  FStopwatch.Stop;
  if Assigned(FCallback) then
    FCallback(FName, FStopwatch.ElapsedMilliseconds);
  inherited;
end;

function TScopedTimer.ElapsedMs: Double;
begin
  Result := FStopwatch.ElapsedMilliseconds;
end;

function TScopedTimer.ElapsedUs: Double;
begin
  Result := FStopwatch.ElapsedMicroseconds;
end;

// ============================================================================
// Helper Functions
// ============================================================================

function TimeScope(const Name: string; Callback: TProc<string, Double>): IScopedTimer;
begin
  Result := TScopedTimer.Create(Name, Callback);
end;

function MeasureTime(const Proc: TBenchmarkProc): Double;
var
  SW: THiResStopwatch;
begin
  SW := THiResStopwatch.Create;
  SW.Start;
  Proc;
  SW.Stop;
  Result := SW.ElapsedMilliseconds;
end;

function MeasureTimeAvg(const Proc: TBenchmarkProc; Iterations: Integer): Double;
var
  I: Integer;
  Total: Double;
  SW: THiResStopwatch;
begin
  Total := 0;
  for I := 1 to Iterations do
  begin
    SW := THiResStopwatch.Create;
    SW.Start;
    Proc;
    SW.Stop;
    Total := Total + SW.ElapsedMilliseconds;
  end;
  Result := Total / Iterations;
end;

function GetCurrentMemoryUsage: Int64;
var
  Snapshot: TMemorySnapshot;
begin
  Snapshot := TMemorySnapshot.Capture;
  Result := Snapshot.HeapAllocated;
end;

end.
