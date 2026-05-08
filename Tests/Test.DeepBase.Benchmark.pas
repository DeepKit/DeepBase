{ ============================================================================
  Test.DeepBase.Benchmark - Benchmark Framework Unit Tests
  
  Version: 1.0
  Description: Unit tests for the performance benchmarking framework
  
  Test Coverage:
  - THiResStopwatch high-precision timing
  - TMemorySnapshot memory tracking
  - TBenchmarkStats statistical calculations
  - TBenchmark execution and results
  - TBenchmarkReport generation
  ============================================================================ }

unit Test.DeepBase.Benchmark;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Math,
  System.IOUtils,
  DUnitX.TestFramework;

type
  /// <summary>
  /// Test fixture for THiResStopwatch
  /// </summary>
  [TestFixture]
  TTestHiResStopwatch = class
  public
    [Test]
    procedure Test_Create_InitialState;
    
    [Test]
    procedure Test_Start_SetsRunning;
    
    [Test]
    procedure Test_Stop_ClearsRunning;
    
    [Test]
    procedure Test_ElapsedMilliseconds_AfterSleep;
    
    [Test]
    procedure Test_ElapsedMicroseconds_Precision;
    
    [Test]
    procedure Test_Reset_ClearsElapsed;
    
    [Test]
    procedure Test_MultipleStartStop_Accumulates;
  end;
  
  /// <summary>
  /// Test fixture for TMemorySnapshot
  /// </summary>
  [TestFixture]
  TTestMemorySnapshot = class
  public
    [Test]
    procedure Test_Capture_ReturnsValidSnapshot;
    
    [Test]
    procedure Test_Capture_WorkingSetPositive;
    
    [Test]
    procedure Test_Subtract_CalculatesDelta;
    
    [Test]
    procedure Test_ToString_FormatsCorrectly;
  end;
  
  /// <summary>
  /// Test fixture for TBenchmarkStats
  /// </summary>
  [TestFixture]
  TTestBenchmarkStats = class
  public
    [Test]
    procedure Test_Calculate_EmptyArray;
    
    [Test]
    procedure Test_Calculate_SingleValue;
    
    [Test]
    procedure Test_Calculate_MinMax;
    
    [Test]
    procedure Test_Calculate_Mean;
    
    [Test]
    procedure Test_Calculate_Median_Odd;
    
    [Test]
    procedure Test_Calculate_Median_Even;
    
    [Test]
    procedure Test_Calculate_StdDev;
    
    [Test]
    procedure Test_Calculate_Percentiles;
    
    [Test]
    procedure Test_ToString_FormatsCorrectly;
  end;
  
  /// <summary>
  /// Test fixture for TBenchmark
  /// </summary>
  [TestFixture]
  TTestBenchmark = class
  public
    [Test]
    procedure Test_Create_WithName;
    
    [Test]
    procedure Test_DefaultIterations;
    
    [Test]
    procedure Test_Run_ExecutesProc;
    
    [Test]
    procedure Test_Run_CollectsTimings;
    
    [Test]
    procedure Test_Run_WithWarmup;
    
    [Test]
    procedure Test_Run_WithSetupTeardown;
    
    [Test]
    procedure Test_AddTag_StoresTag;
    
    [Test]
    procedure Test_TrackMemory_CapturesSnapshots;
    
    [Test]
    procedure Test_Result_ThroughputCalculation;
  end;
  
  /// <summary>
  /// Test fixture for TBenchmarkReport
  /// </summary>
  [TestFixture]
  TTestBenchmarkReport = class
  public
    [Test]
    procedure Test_Create_WithTitle;
    
    [Test]
    procedure Test_AddResult_IncreasesCount;
    
    [Test]
    procedure Test_Clear_RemovesResults;
    
    [Test]
    procedure Test_GenerateText_ContainsTitle;
    
    [Test]
    procedure Test_GenerateJSON_ValidJSON;
    
    [Test]
    procedure Test_GenerateCSV_HasHeaders;
    
    [Test]
    procedure Test_GenerateMarkdown_HasTable;
    
    [Test]
    procedure Test_CollectEnvironmentInfo_HasOSInfo;
    
    [Test]
    procedure Test_SaveToFile_CreatesFile;
  end;
  
  /// <summary>
  /// Test fixture for global benchmark functions
  /// </summary>
  [TestFixture]
  TTestBenchmarkFunctions = class
  public
    [Test]
    procedure Test_MeasureTime_ReturnsElapsed;
    
    [Test]
    procedure Test_MeasureTimeAvg_ReturnsAverage;
  end;

implementation

uses
  DeepBase.Benchmark;

{ TTestHiResStopwatch }

procedure TTestHiResStopwatch.Test_Create_InitialState;
var
  SW: THiResStopwatch;
begin
  SW := THiResStopwatch.Create;
  Assert.IsFalse(SW.IsRunning);
  Assert.AreEqual(Int64(0), SW.ElapsedTicks);
end;

procedure TTestHiResStopwatch.Test_Start_SetsRunning;
var
  SW: THiResStopwatch;
begin
  SW := THiResStopwatch.Create;
  SW.Start;
  Assert.IsTrue(SW.IsRunning);
end;

procedure TTestHiResStopwatch.Test_Stop_ClearsRunning;
var
  SW: THiResStopwatch;
begin
  SW := THiResStopwatch.Create;
  SW.Start;
  SW.Stop;
  Assert.IsFalse(SW.IsRunning);
end;

procedure TTestHiResStopwatch.Test_ElapsedMilliseconds_AfterSleep;
var
  SW: THiResStopwatch;
  Elapsed: Double;
begin
  SW := THiResStopwatch.Create;
  SW.Start;
  Sleep(50);
  SW.Stop;
  Elapsed := SW.ElapsedMilliseconds;
  // Should be approximately 50ms, allow 20ms variance
  Assert.IsTrue(Elapsed >= 40, 'Elapsed should be >= 40ms');
  Assert.IsTrue(Elapsed <= 100, 'Elapsed should be <= 100ms');
end;

procedure TTestHiResStopwatch.Test_ElapsedMicroseconds_Precision;
var
  SW: THiResStopwatch;
  Elapsed: Double;
begin
  SW := THiResStopwatch.Create;
  SW.Start;
  Sleep(10);
  SW.Stop;
  Elapsed := SW.ElapsedMicroseconds;
  // Should be approximately 10000 microseconds
  Assert.IsTrue(Elapsed >= 5000, 'Elapsed should be >= 5000us');
  Assert.IsTrue(Elapsed <= 50000, 'Elapsed should be <= 50000us');
end;

procedure TTestHiResStopwatch.Test_Reset_ClearsElapsed;
var
  SW: THiResStopwatch;
begin
  SW := THiResStopwatch.Create;
  SW.Start;
  Sleep(10);
  SW.Stop;
  SW.Reset;
  Assert.AreEqual(Int64(0), SW.ElapsedTicks);
  Assert.IsFalse(SW.IsRunning);
end;

procedure TTestHiResStopwatch.Test_MultipleStartStop_Accumulates;
var
  SW: THiResStopwatch;
  Elapsed1, Elapsed2: Double;
begin
  SW := THiResStopwatch.Create;
  SW.Start;
  Sleep(20);
  SW.Stop;
  Elapsed1 := SW.ElapsedMilliseconds;
  
  SW.Start;
  Sleep(20);
  SW.Stop;
  Elapsed2 := SW.ElapsedMilliseconds;
  
  // Second elapsed should include both sleeps
  Assert.IsTrue(Elapsed2 > Elapsed1, 'Time should accumulate');
end;

{ TTestMemorySnapshot }

procedure TTestMemorySnapshot.Test_Capture_ReturnsValidSnapshot;
var
  Snap: TMemorySnapshot;
begin
  Snap := TMemorySnapshot.Capture;
  Assert.IsTrue(Snap.Timestamp > 0, 'Timestamp should be set');
end;

procedure TTestMemorySnapshot.Test_Capture_WorkingSetPositive;
var
  Snap: TMemorySnapshot;
begin
  Snap := TMemorySnapshot.Capture;
  Assert.IsTrue(Snap.WorkingSetSize > 0, 'WorkingSet should be positive');
end;

procedure TTestMemorySnapshot.Test_Subtract_CalculatesDelta;
var
  Snap1, Snap2, Delta: TMemorySnapshot;
  Arr: TArray<Integer>;
  I: Integer;
begin
  Snap1 := TMemorySnapshot.Capture;
  
  // Allocate some memory
  SetLength(Arr, 100000);
  for I := 0 to High(Arr) do
    Arr[I] := I;
  
  Snap2 := TMemorySnapshot.Capture;
  Delta := Snap2.Subtract(Snap1);
  
  // Delta should show increased memory (may vary)
  Assert.IsTrue(Delta.HeapAllocated >= 0, 'Heap delta should be non-negative');
end;

procedure TTestMemorySnapshot.Test_ToString_FormatsCorrectly;
var
  Snap: TMemorySnapshot;
  S: string;
begin
  Snap := TMemorySnapshot.Capture;
  S := Snap.ToString;
  Assert.Contains(S, 'Working');
end;

{ TTestBenchmarkStats }

procedure TTestBenchmarkStats.Test_Calculate_EmptyArray;
var
  Stats: TBenchmarkStats;
  Values: TArray<Double>;
begin
  SetLength(Values, 0);
  Stats := TBenchmarkStats.Calculate(Values);
  Assert.AreEqual(0, Integer(Stats.Count));
end;

procedure TTestBenchmarkStats.Test_Calculate_SingleValue;
var
  Stats: TBenchmarkStats;
  Values: TArray<Double>;
begin
  Values := [42.0];
  Stats := TBenchmarkStats.Calculate(Values);
  Assert.AreEqual(1, Integer(Stats.Count));
  Assert.AreEqual(42.0, Stats.Min, 0.001);
  Assert.AreEqual(42.0, Stats.Max, 0.001);
  Assert.AreEqual(42.0, Stats.Mean, 0.001);
end;

procedure TTestBenchmarkStats.Test_Calculate_MinMax;
var
  Stats: TBenchmarkStats;
  Values: TArray<Double>;
begin
  Values := [1.0, 5.0, 3.0, 9.0, 2.0];
  Stats := TBenchmarkStats.Calculate(Values);
  Assert.AreEqual(1.0, Stats.Min, 0.001);
  Assert.AreEqual(9.0, Stats.Max, 0.001);
end;

procedure TTestBenchmarkStats.Test_Calculate_Mean;
var
  Stats: TBenchmarkStats;
  Values: TArray<Double>;
begin
  Values := [10.0, 20.0, 30.0, 40.0, 50.0];
  Stats := TBenchmarkStats.Calculate(Values);
  Assert.AreEqual(30.0, Stats.Mean, 0.001);
end;

procedure TTestBenchmarkStats.Test_Calculate_Median_Odd;
var
  Stats: TBenchmarkStats;
  Values: TArray<Double>;
begin
  Values := [1.0, 3.0, 5.0, 7.0, 9.0];
  Stats := TBenchmarkStats.Calculate(Values);
  Assert.AreEqual(5.0, Stats.Median, 0.001);
end;

procedure TTestBenchmarkStats.Test_Calculate_Median_Even;
var
  Stats: TBenchmarkStats;
  Values: TArray<Double>;
begin
  Values := [1.0, 2.0, 3.0, 4.0];
  Stats := TBenchmarkStats.Calculate(Values);
  Assert.AreEqual(2.5, Stats.Median, 0.001);
end;

procedure TTestBenchmarkStats.Test_Calculate_StdDev;
var
  Stats: TBenchmarkStats;
  Values: TArray<Double>;
begin
  // Values with known stddev
  Values := [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0];
  Stats := TBenchmarkStats.Calculate(Values);
  // Mean = 5, StdDev should be around 2
  Assert.IsTrue(Stats.StdDev > 1.5, 'StdDev should be > 1.5');
  Assert.IsTrue(Stats.StdDev < 2.5, 'StdDev should be < 2.5');
end;

procedure TTestBenchmarkStats.Test_Calculate_Percentiles;
var
  Stats: TBenchmarkStats;
  Values: TArray<Double>;
  I: Integer;
begin
  // Create 100 values from 1 to 100
  SetLength(Values, 100);
  for I := 0 to 99 do
    Values[I] := I + 1;
  
  Stats := TBenchmarkStats.Calculate(Values);
  
  // P90 should be around 90, P95 around 95, P99 around 99
  Assert.IsTrue(Stats.P90 >= 89, 'P90 should be >= 89');
  Assert.IsTrue(Stats.P90 <= 92, 'P90 should be <= 92');
  Assert.IsTrue(Stats.P95 >= 94, 'P95 should be >= 94');
  Assert.IsTrue(Stats.P99 >= 98, 'P99 should be >= 98');
end;

procedure TTestBenchmarkStats.Test_ToString_FormatsCorrectly;
var
  Stats: TBenchmarkStats;
  Values: TArray<Double>;
  S: string;
begin
  Values := [1.0, 2.0, 3.0];
  Stats := TBenchmarkStats.Calculate(Values);
  S := Stats.ToString('ms');
  Assert.Contains(S, 'ms');
end;

{ TTestBenchmark }

procedure TTestBenchmark.Test_Create_WithName;
var
  Bench: TBenchmark;
begin
  Bench := TBenchmark.Create('TestBenchmark');
  try
    Assert.AreEqual('TestBenchmark', Bench.Name);
  finally
    Bench.Free;
  end;
end;

procedure TTestBenchmark.Test_DefaultIterations;
var
  Bench: TBenchmark;
begin
  Bench := TBenchmark.Create('Test');
  try
    Assert.IsTrue(Bench.Iterations > 0, 'Default iterations should be > 0');
  finally
    Bench.Free;
  end;
end;

procedure TTestBenchmark.Test_Run_ExecutesProc;
var
  Bench: TBenchmark;
  Counter: Integer;
begin
  Bench := TBenchmark.Create('CounterTest');
  try
    Counter := 0;
    Bench.Iterations := 10;
    Bench.WarmupIterations := 0;
    Bench.Run(
      procedure
      begin
        Inc(Counter);
      end);
    Assert.AreEqual(10, Counter);
  finally
    Bench.Free;
  end;
end;

procedure TTestBenchmark.Test_Run_CollectsTimings;
var
  Bench: TBenchmark;
begin
  Bench := TBenchmark.Create('TimingTest');
  try
    Bench.Iterations := 5;
    Bench.WarmupIterations := 0;
    Bench.Run(
      procedure
      begin
        Sleep(1);
      end);
    Assert.AreEqual(5, Bench.LastResult.Iterations);
    Assert.AreEqual(5, Integer(Length(Bench.LastResult.RawTimings)));
  finally
    Bench.Free;
  end;
end;

procedure TTestBenchmark.Test_Run_WithWarmup;
var
  Bench: TBenchmark;
  TotalCalls: Integer;
begin
  Bench := TBenchmark.Create('WarmupTest');
  try
    TotalCalls := 0;
    Bench.Iterations := 5;
    Bench.WarmupIterations := 3;
    Bench.Run(
      procedure
      begin
        Inc(TotalCalls);
      end);
    // Should call warmup + iterations = 3 + 5 = 8
    Assert.AreEqual(8, TotalCalls);
    Assert.AreEqual(3, Bench.LastResult.WarmupIterations);
  finally
    Bench.Free;
  end;
end;

procedure TTestBenchmark.Test_Run_WithSetupTeardown;
var
  Bench: TBenchmark;
  SetupCalled, TeardownCalled: Boolean;
begin
  Bench := TBenchmark.Create('SetupTest');
  try
    SetupCalled := False;
    TeardownCalled := False;
    Bench.Iterations := 1;
    Bench.WarmupIterations := 0;
    Bench.Setup := procedure begin SetupCalled := True; end;
    Bench.Teardown := procedure begin TeardownCalled := True; end;
    Bench.Run(procedure begin end);
    Assert.IsTrue(SetupCalled, 'Setup should be called');
    Assert.IsTrue(TeardownCalled, 'Teardown should be called');
  finally
    Bench.Free;
  end;
end;

procedure TTestBenchmark.Test_AddTag_StoresTag;
var
  Bench: TBenchmark;
begin
  Bench := TBenchmark.Create('TagTest');
  try
    Bench.AddTag('version', '1.0');
    Bench.AddTag('env', 'test');
    Bench.Iterations := 1;
    Bench.WarmupIterations := 0;
    Bench.Run(procedure begin end);
    Assert.AreEqual(2, Integer(Length(Bench.LastResult.Tags)));
  finally
    Bench.Free;
  end;
end;

procedure TTestBenchmark.Test_TrackMemory_CapturesSnapshots;
var
  Bench: TBenchmark;
begin
  Bench := TBenchmark.Create('MemoryTest');
  try
    Bench.TrackMemory := True;
    Bench.Iterations := 1;
    Bench.WarmupIterations := 0;
    Bench.Run(procedure begin end);
    Assert.IsTrue(Bench.LastResult.MemoryBefore.WorkingSetSize > 0, 
      'Memory before should be captured');
  finally
    Bench.Free;
  end;
end;

procedure TTestBenchmark.Test_Result_ThroughputCalculation;
var
  Bench: TBenchmark;
  Throughput: Double;
begin
  Bench := TBenchmark.Create('ThroughputTest');
  try
    Bench.Iterations := 10;
    Bench.WarmupIterations := 0;
    Bench.Run(
      procedure
      begin
        Sleep(10);  // ~10ms per iteration
      end);
    Throughput := Bench.LastResult.ThroughputPerSecond;
    // Should be around 100 ops/sec (1000ms / 10ms)
    Assert.IsTrue(Throughput > 10, 'Throughput should be > 10 ops/sec');
    Assert.IsTrue(Throughput < 500, 'Throughput should be < 500 ops/sec');
  finally
    Bench.Free;
  end;
end;

{ TTestBenchmarkReport }

procedure TTestBenchmarkReport.Test_Create_WithTitle;
var
  Report: TBenchmarkReport;
begin
  Report := TBenchmarkReport.Create('My Report');
  try
    Assert.AreEqual('My Report', Report.Title);
  finally
    Report.Free;
  end;
end;

procedure TTestBenchmarkReport.Test_AddResult_IncreasesCount;
var
  Report: TBenchmarkReport;
  Bench: TBenchmark;
begin
  Report := TBenchmarkReport.Create;
  Bench := TBenchmark.Create('Test');
  try
    Bench.Iterations := 1;
    Bench.WarmupIterations := 0;
    Bench.Run(procedure begin end);
    Report.AddResult(Bench.LastResult);
    Assert.AreEqual<Integer>(1, Report.Results.Count);
  finally
    Bench.Free;
    Report.Free;
  end;
end;

procedure TTestBenchmarkReport.Test_Clear_RemovesResults;
var
  Report: TBenchmarkReport;
  Bench: TBenchmark;
begin
  Report := TBenchmarkReport.Create;
  Bench := TBenchmark.Create('Test');
  try
    Bench.Iterations := 1;
    Bench.WarmupIterations := 0;
    Bench.Run(procedure begin end);
    Report.AddResult(Bench.LastResult);
    Report.Clear;
    Assert.AreEqual<Integer>(0, Report.Results.Count);
  finally
    Bench.Free;
    Report.Free;
  end;
end;

procedure TTestBenchmarkReport.Test_GenerateText_ContainsTitle;
var
  Report: TBenchmarkReport;
  Text: string;
begin
  Report := TBenchmarkReport.Create('Performance Test');
  try
    Text := Report.Generate(rfText);
    Assert.Contains(Text, 'Performance Test');
  finally
    Report.Free;
  end;
end;

procedure TTestBenchmarkReport.Test_GenerateJSON_ValidJSON;
var
  Report: TBenchmarkReport;
  JSON: string;
begin
  Report := TBenchmarkReport.Create;
  try
    JSON := Report.Generate(rfJSON);
    Assert.IsTrue(JSON.StartsWith('{'), 'Should start with {');
    Assert.IsTrue(JSON.EndsWith('}'), 'Should end with }');
  finally
    Report.Free;
  end;
end;

procedure TTestBenchmarkReport.Test_GenerateCSV_HasHeaders;
var
  Report: TBenchmarkReport;
  CSV: string;
begin
  Report := TBenchmarkReport.Create;
  try
    CSV := Report.Generate(rfCSV);
    Assert.Contains(CSV, 'Name');
  finally
    Report.Free;
  end;
end;

procedure TTestBenchmarkReport.Test_GenerateMarkdown_HasTable;
var
  Report: TBenchmarkReport;
  MD: string;
begin
  Report := TBenchmarkReport.Create;
  try
    MD := Report.Generate(rfMarkdown);
    Assert.Contains(MD, '|');
  finally
    Report.Free;
  end;
end;

procedure TTestBenchmarkReport.Test_CollectEnvironmentInfo_HasOSInfo;
var
  Report: TBenchmarkReport;
begin
  Report := TBenchmarkReport.Create;
  try
    Report.CollectEnvironmentInfo;
    Assert.IsTrue(Report.EnvironmentInfo.Count > 0, 'Should have environment info');
  finally
    Report.Free;
  end;
end;

procedure TTestBenchmarkReport.Test_SaveToFile_CreatesFile;
var
  Report: TBenchmarkReport;
  TempFile: string;
begin
  Report := TBenchmarkReport.Create('FileTest');
  try
    TempFile := TPath.Combine(TPath.GetTempPath, 'benchmark_test.txt');
    try
      Report.SaveToFile(TempFile, rfText);
      Assert.IsTrue(TFile.Exists(TempFile), 'File should be created');
    finally
      if TFile.Exists(TempFile) then
        TFile.Delete(TempFile);
    end;
  finally
    Report.Free;
  end;
end;

{ TTestBenchmarkFunctions }

procedure TTestBenchmarkFunctions.Test_MeasureTime_ReturnsElapsed;
var
  Elapsed: Double;
begin
  Elapsed := MeasureTime(
    procedure
    begin
      Sleep(10);
    end);
  Assert.IsTrue(Elapsed >= 5, 'Elapsed should be >= 5ms');
  Assert.IsTrue(Elapsed <= 100, 'Elapsed should be <= 100ms');
end;

procedure TTestBenchmarkFunctions.Test_MeasureTimeAvg_ReturnsAverage;
var
  Avg: Double;
begin
  Avg := MeasureTimeAvg(
    procedure
    begin
      Sleep(5);
    end, 3);
  Assert.IsTrue(Avg >= 3, 'Average should be >= 3ms');
  Assert.IsTrue(Avg <= 50, 'Average should be <= 50ms');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestHiResStopwatch);
  TDUnitX.RegisterTestFixture(TTestMemorySnapshot);
  TDUnitX.RegisterTestFixture(TTestBenchmarkStats);
  TDUnitX.RegisterTestFixture(TTestBenchmark);
  TDUnitX.RegisterTestFixture(TTestBenchmarkReport);
  TDUnitX.RegisterTestFixture(TTestBenchmarkFunctions);

end.
