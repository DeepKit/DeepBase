unit Test.DeepBase.Performance;

{*******************************************************************************
  DeepBase Performance Benchmark Suite
  
  Performance Targets (Reference: i7-10700 @ 3.8GHz, NVMe SSD):
  - Config Read:  > 100,000 ops/sec (cached)
  - Config Write: > 10,000 ops/sec
  - Log Write:    > 50,000 entries/sec (async queue)
  - DoQry Select: > 5,000 queries/sec (simple)
  - Cache Hit:    > 500,000 ops/sec
  
  Usage:
  - Run with DUnitX test runner
  - Results are output to console and optionally to file
  - Each test runs multiple iterations for statistical accuracy
*******************************************************************************}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.Diagnostics,
  System.Generics.Collections,
  System.IOUtils,
  System.Math,
  Data.DB,
  FireDAC.Comp.Client,
  DeepBase.Manager,
  DeepBase.Config,
  DeepBase.Logging,
  DeepBase.Cache,
  DeepBase.DB.DoQry;

type
  /// <summary>
  /// Benchmark result record
  /// </summary>
  TBenchmarkResult = record
    TestName: string;
    Iterations: Integer;
    TotalMs: Double;
    OpsPerSecond: Double;
    AvgMicroseconds: Double;
    MinMicroseconds: Double;
    MaxMicroseconds: Double;
    
    function ToString: string;
  end;

  /// <summary>
  /// Performance benchmark runner
  /// </summary>
  TBenchmarkRunner = class
  private
    FResults: TList<TBenchmarkResult>;
    FWarmupIterations: Integer;
    FOutputFile: string;
    
  public
    constructor Create;
    destructor Destroy; override;
    
    /// <summary>
    /// Run a benchmark and record results
    /// </summary>
    function RunBenchmark(const TestName: string; Iterations: Integer;
      const TestProc: TProc): TBenchmarkResult;
    
    /// <summary>
    /// Run benchmark with per-iteration timing
    /// </summary>
    function RunBenchmarkDetailed(const TestName: string; Iterations: Integer;
      const TestProc: TProc): TBenchmarkResult;
    
    /// <summary>
    /// Get all results
    /// </summary>
    property Results: TList<TBenchmarkResult> read FResults;
    
    /// <summary>
    /// Number of warmup iterations (default 100)
    /// </summary>
    property WarmupIterations: Integer read FWarmupIterations write FWarmupIterations;
    
    /// <summary>
    /// Output file for results (optional)
    /// </summary>
    property OutputFile: string read FOutputFile write FOutputFile;
    
    /// <summary>
    /// Print summary to console
    /// </summary>
    procedure PrintSummary;
    
    /// <summary>
    /// Save results to file
    /// </summary>
    procedure SaveResults;
  end;

  [TestFixture]
  [Category('Performance')]
  TTestConfigPerformance = class
  private
    FManager: TDeepBaseManager;
    FBenchmark: TBenchmarkRunner;
    FDBPath: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Benchmark_ConfigRead_Cached;
    
    [Test]
    procedure Benchmark_ConfigRead_Uncached;
    
    [Test]
    procedure Benchmark_ConfigWrite;
    
    [Test]
    procedure Benchmark_ConfigWrite_Batch;
  end;

  [TestFixture]
  [Category('Performance')]
  TTestLoggingPerformance = class
  private
    FManager: TDeepBaseManager;
    FBenchmark: TBenchmarkRunner;
    FDBPath: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Benchmark_LogWrite_Info;
    
    [Test]
    procedure Benchmark_LogWrite_WithFormat;
    
    [Test]
    procedure Benchmark_LogWrite_Concurrent;
  end;

  [TestFixture]
  [Category('Performance')]
  TTestCachePerformance = class
  private
    FCache: TCache<string, string>;
    FBenchmark: TBenchmarkRunner;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Benchmark_CacheGet_Hit;
    
    [Test]
    procedure Benchmark_CacheGet_Miss;
    
    [Test]
    procedure Benchmark_CacheSet;
    
    [Test]
    procedure Benchmark_CacheGetOrAdd;
    
    [Test]
    procedure Benchmark_CacheConcurrent;
  end;

  [TestFixture]
  [Category('Performance')]
  TTestDoQryPerformance = class
  private
    FConnection: TFDConnection;
    FBenchmark: TBenchmarkRunner;
    FDBPath: string;
    FContext: TUniQueryContext;
    
    procedure SetupTestDatabase;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Benchmark_SimpleSelect;
    
    [Test]
    procedure Benchmark_ParameterizedSelect;
    
    [Test]
    procedure Benchmark_Insert;
    
    [Test]
    procedure Benchmark_Update;
  end;

implementation

uses
  System.Threading,
  System.SyncObjs,
  FireDAC.Stan.Def,
  FireDAC.Phys.SQLite;

{ TBenchmarkResult }

function TBenchmarkResult.ToString: string;
begin
  Result := Format('%s: %d iterations in %.2f ms (%.0f ops/sec, avg %.2f µs)',
    [TestName, Iterations, TotalMs, OpsPerSecond, AvgMicroseconds]);
end;

{ TBenchmarkRunner }

constructor TBenchmarkRunner.Create;
begin
  inherited;
  FResults := TList<TBenchmarkResult>.Create;
  FWarmupIterations := 100;
end;

destructor TBenchmarkRunner.Destroy;
begin
  FResults.Free;
  inherited;
end;

function TBenchmarkRunner.RunBenchmark(const TestName: string; Iterations: Integer;
  const TestProc: TProc): TBenchmarkResult;
var
  SW: TStopwatch;
  I: Integer;
begin
  // Warmup
  for I := 1 to FWarmupIterations do
    TestProc();
  
  // Actual benchmark
  SW := TStopwatch.StartNew;
  for I := 1 to Iterations do
    TestProc();
  SW.Stop;
  
  Result.TestName := TestName;
  Result.Iterations := Iterations;
  Result.TotalMs := SW.Elapsed.TotalMilliseconds;
  Result.OpsPerSecond := Iterations / (Result.TotalMs / 1000);
  Result.AvgMicroseconds := (Result.TotalMs * 1000) / Iterations;
  Result.MinMicroseconds := Result.AvgMicroseconds; // Not tracked in simple mode
  Result.MaxMicroseconds := Result.AvgMicroseconds;
  
  FResults.Add(Result);
end;

function TBenchmarkRunner.RunBenchmarkDetailed(const TestName: string; Iterations: Integer;
  const TestProc: TProc): TBenchmarkResult;
var
  SW: TStopwatch;
  I: Integer;
  Times: TArray<Double>;
  ElapsedUs: Double;
  MinUs, MaxUs, SumUs: Double;
begin
  SetLength(Times, Iterations);
  
  // Warmup
  for I := 1 to FWarmupIterations do
    TestProc();
  
  // Actual benchmark with per-iteration timing
  MinUs := MaxDouble;
  MaxUs := 0;
  SumUs := 0;
  
  for I := 0 to Iterations - 1 do
  begin
    SW := TStopwatch.StartNew;
    TestProc();
    SW.Stop;
    
    ElapsedUs := SW.Elapsed.TotalMilliseconds * 1000;
    Times[I] := ElapsedUs;
    SumUs := SumUs + ElapsedUs;
    
    if ElapsedUs < MinUs then MinUs := ElapsedUs;
    if ElapsedUs > MaxUs then MaxUs := ElapsedUs;
  end;
  
  Result.TestName := TestName;
  Result.Iterations := Iterations;
  Result.TotalMs := SumUs / 1000;
  Result.OpsPerSecond := Iterations / (Result.TotalMs / 1000);
  Result.AvgMicroseconds := SumUs / Iterations;
  Result.MinMicroseconds := MinUs;
  Result.MaxMicroseconds := MaxUs;
  
  FResults.Add(Result);
end;

procedure TBenchmarkRunner.PrintSummary;
var
  R: TBenchmarkResult;
begin
  WriteLn('');
  WriteLn('=== Performance Benchmark Results ===');
  WriteLn('');
  for R in FResults do
    WriteLn(R.ToString);
  WriteLn('');
end;

procedure TBenchmarkRunner.SaveResults;
var
  SL: TStringList;
  R: TBenchmarkResult;
begin
  if FOutputFile = '' then Exit;
  
  SL := TStringList.Create;
  try
    SL.Add('TestName,Iterations,TotalMs,OpsPerSecond,AvgMicroseconds,MinMicroseconds,MaxMicroseconds');
    for R in FResults do
      SL.Add(Format('%s,%d,%.3f,%.0f,%.3f,%.3f,%.3f',
        [R.TestName, R.Iterations, R.TotalMs, R.OpsPerSecond,
         R.AvgMicroseconds, R.MinMicroseconds, R.MaxMicroseconds]));
    SL.SaveToFile(FOutputFile);
  finally
    SL.Free;
  end;
end;

{ TTestConfigPerformance }

procedure TTestConfigPerformance.Setup;
begin
  FDBPath := TPath.Combine(TPath.GetTempPath, 'DeepBase_perf_config_' + TGUID.NewGuid.ToString + '.db');
  FManager := TDeepBaseManager.Create(nil);
  FManager.InitializeWithDB(FDBPath);
  FBenchmark := TBenchmarkRunner.Create;
  
  // Pre-populate some config values
  for var I := 1 to 100 do
    FManager.Config.SetConfig('perf_key_' + IntToStr(I), 'value_' + IntToStr(I));
end;

procedure TTestConfigPerformance.TearDown;
begin
  FBenchmark.PrintSummary;
  FBenchmark.Free;
  FManager.Finalize;
  FManager.Free;
  if TFile.Exists(FDBPath) then
    TFile.Delete(FDBPath);
end;

procedure TTestConfigPerformance.Benchmark_ConfigRead_Cached;
var
  R: TBenchmarkResult;
  Value: string;
begin
  // Ensure cache is warm
  FManager.Config.PreloadCache;
  
  R := FBenchmark.RunBenchmark('Config.Read.Cached', 100000,
    procedure
    begin
      Value := FManager.Config.GetConfig('perf_key_50');
    end);
  
  Assert.IsTrue(R.OpsPerSecond > 50000, 
    Format('Cached read should exceed 50K ops/sec, got %.0f', [R.OpsPerSecond]));
end;

procedure TTestConfigPerformance.Benchmark_ConfigRead_Uncached;
var
  R: TBenchmarkResult;
  Value: string;
begin
  R := FBenchmark.RunBenchmark('Config.Read.Uncached', 10000,
    procedure
    begin
      FManager.Config.ClearCache;
      Value := FManager.Config.GetConfig('perf_key_50');
    end);
  
  Assert.IsTrue(R.OpsPerSecond > 1000,
    Format('Uncached read should exceed 1K ops/sec, got %.0f', [R.OpsPerSecond]));
end;

procedure TTestConfigPerformance.Benchmark_ConfigWrite;
var
  R: TBenchmarkResult;
  Counter: Integer;
begin
  Counter := 0;
  R := FBenchmark.RunBenchmark('Config.Write.Single', 10000,
    procedure
    begin
      Inc(Counter);
      FManager.Config.SetConfig('write_key', 'value_' + IntToStr(Counter));
    end);
  
  Assert.IsTrue(R.OpsPerSecond > 5000,
    Format('Config write should exceed 5K ops/sec, got %.0f', [R.OpsPerSecond]));
end;

procedure TTestConfigPerformance.Benchmark_ConfigWrite_Batch;
var
  R: TBenchmarkResult;
  Counter: Integer;
begin
  Counter := 0;
  R := FBenchmark.RunBenchmark('Config.Write.Batch', 1000,
    procedure
    var
      I: Integer;
    begin
      Inc(Counter);
      for I := 1 to 10 do
        FManager.Config.SetConfig('batch_key_' + IntToStr(I), 'value_' + IntToStr(Counter));
    end);
  
  // 1000 batches * 10 writes = 10000 total writes
  Assert.IsTrue((R.OpsPerSecond * 10) > 5000,
    Format('Batch write should exceed 5K effective ops/sec', []));
end;

{ TTestLoggingPerformance }

procedure TTestLoggingPerformance.Setup;
begin
  FDBPath := TPath.Combine(TPath.GetTempPath, 'DeepBase_perf_log_' + TGUID.NewGuid.ToString + '.db');
  FManager := TDeepBaseManager.Create(nil);
  FManager.InitializeWithDB(FDBPath);
  FBenchmark := TBenchmarkRunner.Create;
end;

procedure TTestLoggingPerformance.TearDown;
begin
  FBenchmark.PrintSummary;
  FBenchmark.Free;
  FManager.Finalize;
  FManager.Free;
  if TFile.Exists(FDBPath) then
    TFile.Delete(FDBPath);
end;

procedure TTestLoggingPerformance.Benchmark_LogWrite_Info;
var
  R: TBenchmarkResult;
begin
  R := FBenchmark.RunBenchmark('Log.Write.Info', 50000,
    procedure
    begin
      FManager.Logger.Info('Performance test message');
    end);
  
  // Async logging should be very fast (just queue)
  Assert.IsTrue(R.OpsPerSecond > 100000,
    Format('Async log write should exceed 100K ops/sec, got %.0f', [R.OpsPerSecond]));
end;

procedure TTestLoggingPerformance.Benchmark_LogWrite_WithFormat;
var
  R: TBenchmarkResult;
  Counter: Integer;
begin
  Counter := 0;
  R := FBenchmark.RunBenchmark('Log.Write.Formatted', 50000,
    procedure
    begin
      Inc(Counter);
      FManager.Logger.InfoFmt('Performance test message %d with value %s', [Counter, 'test']);
    end);
  
  Assert.IsTrue(R.OpsPerSecond > 50000,
    Format('Formatted log write should exceed 50K ops/sec, got %.0f', [R.OpsPerSecond]));
end;

procedure TTestLoggingPerformance.Benchmark_LogWrite_Concurrent;
var
  R: TBenchmarkResult;
  Tasks: TArray<ITask>;
  Counter: Integer;
  Lock: TCriticalSection;
const
  THREAD_COUNT = 4;
  LOGS_PER_THREAD = 10000;
begin
  Counter := 0;
  Lock := TCriticalSection.Create;
  try
    R := FBenchmark.RunBenchmark('Log.Write.Concurrent', 1,
      procedure
      var
        I: Integer;
      begin
        SetLength(Tasks, THREAD_COUNT);
        try
          for I := 0 to THREAD_COUNT - 1 do
          begin
            var ThreadId := I;
            Tasks[I] := TTask.Create(
              procedure
              var
                J: Integer;
              begin
                for J := 1 to LOGS_PER_THREAD do
                  FManager.Logger.InfoFmt('Thread %d message %d', [ThreadId, J]);
              end);
            Tasks[I].Start;
          end;
          TTask.WaitForAll(Tasks);
        finally
          for I := 0 to High(Tasks) do
            Tasks[I] := nil;
          SetLength(Tasks, 0);
        end;
      end);
    
    // Calculate effective ops/sec
    var EffectiveOps := (THREAD_COUNT * LOGS_PER_THREAD) / (R.TotalMs / 1000);
    Assert.IsTrue(EffectiveOps > 50000,
      Format('Concurrent log write should exceed 50K effective ops/sec, got %.0f', [EffectiveOps]));
  finally
    Lock.Free;
  end;
end;

{ TTestCachePerformance }

procedure TTestCachePerformance.Setup;
begin
  FCache := TCache<string, string>.Create;
  FCache.MaxItems := 10000;
  FBenchmark := TBenchmarkRunner.Create;
  
  // Pre-populate cache
  for var I := 1 to 1000 do
    FCache.Put('key_' + IntToStr(I), 'value_' + IntToStr(I));
end;

procedure TTestCachePerformance.TearDown;
begin
  FBenchmark.PrintSummary;
  FBenchmark.Free;
  FCache.Free;
end;

procedure TTestCachePerformance.Benchmark_CacheGet_Hit;
var
  R: TBenchmarkResult;
  Value: string;
begin
  R := FBenchmark.RunBenchmark('Cache.Get.Hit', 200000,
    procedure
    begin
      FCache.TryGet('key_500', Value);
    end);
  
  Assert.IsTrue(R.OpsPerSecond > 100000,
    Format('Cache hit should exceed 100K ops/sec, got %.0f', [R.OpsPerSecond]));
end;

procedure TTestCachePerformance.Benchmark_CacheGet_Miss;
var
  R: TBenchmarkResult;
  Value: string;
begin
  R := FBenchmark.RunBenchmark('Cache.Get.Miss', 1000000,
    procedure
    begin
      FCache.TryGet('nonexistent_key', Value);
    end);
  
  Assert.IsTrue(R.OpsPerSecond > 500000,
    Format('Cache miss should exceed 500K ops/sec, got %.0f', [R.OpsPerSecond]));
end;

procedure TTestCachePerformance.Benchmark_CacheSet;
var
  R: TBenchmarkResult;
  Counter: Integer;
begin
  Counter := 0;
  R := FBenchmark.RunBenchmark('Cache.Set', 500000,
    procedure
    begin
      Inc(Counter);
      FCache.Put('set_key_' + IntToStr(Counter mod 1000), 'value');
    end);
  
  Assert.IsTrue(R.OpsPerSecond > 200000,
    Format('Cache set should exceed 200K ops/sec, got %.0f', [R.OpsPerSecond]));
end;

procedure TTestCachePerformance.Benchmark_CacheGetOrAdd;
var
  R: TBenchmarkResult;
  Counter: Integer;
begin
  Counter := 0;
  FCache.OnLoad := function(const Key: string): string
    begin
      Result := 'computed_value';
    end;

  R := FBenchmark.RunBenchmark('Cache.GetOrLoad', 500000,
    procedure
    begin
      Inc(Counter);
      FCache.GetOrLoad('getadd_key_' + IntToStr(Counter mod 100));
    end);

  Assert.IsTrue(R.OpsPerSecond > 200000,
    Format('Cache GetOrLoad should exceed 200K ops/sec, got %.0f', [R.OpsPerSecond]));
end;

procedure TTestCachePerformance.Benchmark_CacheConcurrent;
var
  R: TBenchmarkResult;
  Tasks: TArray<ITask>;
const
  THREAD_COUNT = 4;
  OPS_PER_THREAD = 10000;
begin
  R := FBenchmark.RunBenchmark('Cache.Concurrent', 1,
    procedure
    var
      I: Integer;
    begin
      SetLength(Tasks, THREAD_COUNT);
      try
        for I := 0 to THREAD_COUNT - 1 do
        begin
          var ThreadId := I;
          Tasks[I] := TTask.Create(
            procedure
            var
              J: Integer;
              Value: string;
            begin
              for J := 1 to OPS_PER_THREAD do
              begin
                if J mod 2 = 0 then
                  FCache.TryGet('key_' + IntToStr(J mod 1000), Value)
                else
                  FCache.Put('thread_' + IntToStr(ThreadId) + '_key_' + IntToStr(J mod 100), 'value');
              end;
            end);
          Tasks[I].Start;
        end;
        TTask.WaitForAll(Tasks);
      finally
        for I := 0 to High(Tasks) do
          Tasks[I] := nil;
        SetLength(Tasks, 0);
      end;
    end);
  
  var EffectiveOps := (THREAD_COUNT * OPS_PER_THREAD) / (R.TotalMs / 1000);
  Assert.IsTrue(EffectiveOps > 10000,
    Format('Concurrent cache ops should exceed 10K effective ops/sec, got %.0f', [EffectiveOps]));
end;

{ TTestDoQryPerformance }

procedure TTestDoQryPerformance.Setup;
begin
  FDBPath := TPath.Combine(TPath.GetTempPath, 'DeepBase_perf_doqry_' + TGUID.NewGuid.ToString + '.db');
  
  FConnection := TFDConnection.Create(nil);
  FConnection.DriverName := 'SQLite';
  FConnection.Params.Values['Database'] := FDBPath;
  FConnection.Connected := True;
  
  FContext := UniDbMakeContext(FConnection, udbSQLite, 30);
  FBenchmark := TBenchmarkRunner.Create;
  
  SetupTestDatabase;
end;

procedure TTestDoQryPerformance.TearDown;
begin
  FBenchmark.PrintSummary;
  FBenchmark.Free;
  FConnection.Connected := False;
  FConnection.Free;
  if TFile.Exists(FDBPath) then
    TFile.Delete(FDBPath);
end;

procedure TTestDoQryPerformance.SetupTestDatabase;
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    
    // Create test table
    Query.SQL.Text := 
      'CREATE TABLE IF NOT EXISTS PerfTest (' +
      '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
      '  Name TEXT NOT NULL,' +
      '  Value REAL,' +
      '  Created TEXT' +
      ')';
    Query.ExecSQL;
    
    // Insert test data
    Query.SQL.Text := 'INSERT INTO PerfTest (Name, Value, Created) VALUES (:Name, :Value, :Created)';
    for var I := 1 to 1000 do
    begin
      Query.ParamByName('Name').AsString := 'Item_' + IntToStr(I);
      Query.ParamByName('Value').AsFloat := I * 1.5;
      Query.ParamByName('Created').AsString := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now);
      Query.ExecSQL;
    end;
  finally
    Query.Free;
  end;
end;

procedure TTestDoQryPerformance.Benchmark_SimpleSelect;
var
  R: TBenchmarkResult;
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT * FROM PerfTest WHERE Id = 500';
    
    R := FBenchmark.RunBenchmark('DoQry.Select.Simple', 10000,
      procedure
      begin
        Query.Open;
        Query.Close;
      end);
    
    Assert.IsTrue(R.OpsPerSecond > 5000,
      Format('Simple select should exceed 5K ops/sec, got %.0f', [R.OpsPerSecond]));
  finally
    Query.Free;
  end;
end;

procedure TTestDoQryPerformance.Benchmark_ParameterizedSelect;
var
  R: TBenchmarkResult;
  Query: TFDQuery;
  Counter: Integer;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT * FROM PerfTest WHERE Id = :Id';
    Query.ParamByName('Id').DataType := ftInteger;
    Query.Prepare;
    Counter := 0;
    
    R := FBenchmark.RunBenchmark('DoQry.Select.Parameterized', 10000,
      procedure
      begin
        Inc(Counter);
        Query.ParamByName('Id').AsInteger := (Counter mod 1000) + 1;
        Query.Open;
        Query.Close;
      end);
    
    Assert.IsTrue(R.OpsPerSecond > 5000,
      Format('Parameterized select should exceed 5K ops/sec, got %.0f', [R.OpsPerSecond]));
  finally
    Query.Free;
  end;
end;

procedure TTestDoQryPerformance.Benchmark_Insert;
var
  R: TBenchmarkResult;
  Query: TFDQuery;
  Counter: Integer;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'INSERT INTO PerfTest (Name, Value, Created) VALUES (:Name, :Value, :Created)';
    Query.ParamByName('Name').DataType := ftString;
    Query.ParamByName('Value').DataType := ftFloat;
    Query.ParamByName('Created').DataType := ftString;
    Query.Prepare;
    Counter := 0;
    
    R := FBenchmark.RunBenchmark('DoQry.Insert', 5000,
      procedure
      begin
        Inc(Counter);
        Query.ParamByName('Name').AsString := 'Perf_' + IntToStr(Counter);
        Query.ParamByName('Value').AsFloat := Counter * 0.1;
        Query.ParamByName('Created').AsString := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now);
        Query.ExecSQL;
      end);
    
    Assert.IsTrue(R.OpsPerSecond > 2000,
      Format('Insert should exceed 2K ops/sec, got %.0f', [R.OpsPerSecond]));
  finally
    Query.Free;
  end;
end;

procedure TTestDoQryPerformance.Benchmark_Update;
var
  R: TBenchmarkResult;
  Query: TFDQuery;
  Counter: Integer;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'UPDATE PerfTest SET Value = :Value WHERE Id = :Id';
    Query.ParamByName('Value').DataType := ftFloat;
    Query.ParamByName('Id').DataType := ftInteger;
    Query.Prepare;
    Counter := 0;
    
    R := FBenchmark.RunBenchmark('DoQry.Update', 5000,
      procedure
      begin
        Inc(Counter);
        Query.ParamByName('Id').AsInteger := (Counter mod 1000) + 1;
        Query.ParamByName('Value').AsFloat := Counter * 0.5;
        Query.ExecSQL;
      end);
    
    Assert.IsTrue(R.OpsPerSecond > 2000,
      Format('Update should exceed 2K ops/sec, got %.0f', [R.OpsPerSecond]));
  finally
    Query.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestConfigPerformance);
  TDUnitX.RegisterTestFixture(TTestLoggingPerformance);
  TDUnitX.RegisterTestFixture(TTestCachePerformance);
  TDUnitX.RegisterTestFixture(TTestDoQryPerformance);

end.
