{ ============================================================================
  Test.UniBase.LockContention - Lock Contention Performance Benchmarks

  Version: 1.0
  Description: Performance benchmarks comparing lock contention between
    TCriticalSection and TMultiReadExclusiveWriteSynchronizer (MREW).

  These benchmarks validate the OPT-004 optimization for Config and Cache
  modules by measuring throughput under various read/write ratios and
  concurrency levels.

  Test Scenarios:
  - Read-heavy (90/10) with 8 threads: CS vs MREW
  - Write-heavy (50/50) with 8 threads: CS vs MREW
  - High concurrency (16 threads, read-heavy): CS vs MREW
  - Scalability sweep at 2/4/8/16 threads with MREW
  ============================================================================ }

unit Test.UniBase.LockContention;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Diagnostics,
  System.Math,
  DUnitX.TestFramework;

const
  /// Number of iterations each thread performs in a benchmark run
  ITERATIONS_PER_THREAD = 50000;

  /// Warmup iterations per thread (discarded before measurement)
  WARMUP_ITERATIONS = 2000;

type
  /// <summary>
  /// Workload profile describing the read/write ratio and thread count
  /// </summary>
  TWorkloadProfile = record
    ReadPercent: Integer;
    ThreadCount: Integer;
    Iterations: Integer;
    Name: string;
  end;

  /// <summary>
  /// Raw benchmark sample collected from a single run
  /// </summary>
  TContentionSample = record
    ElapsedMs: Double;
    TotalOps: Int64;
    Throughput: Double;
  end;

  /// <summary>
  /// Lock contention benchmark fixture (OPT-004)
  /// </summary>
  [TestFixture]
  TLockContentionBenchmark = class
  private
    // ---- Workload runners ----
    procedure RunCriticalSectionWorkload(const Profile: TWorkloadProfile;
      out Sample: TContentionSample);

    procedure RunMREWWorkload(const Profile: TWorkloadProfile;
      out Sample: TContentionSample);

    procedure WaitForAll(const Threads: TArray<TThread>);

    /// Format a throughput value for Assert.Pass output
    function FormatThroughput(const TestName: string;
      const Sample: TContentionSample): string;
  public
    // ---- Read-heavy: 90% reads, 10% writes, 8 threads ----
    [Test]
    procedure Test_CriticalSection_ReadHeavy;

    [Test]
    procedure Test_MREW_ReadHeavy;

    // ---- Write-heavy: 50% reads, 50% writes, 8 threads ----
    [Test]
    procedure Test_CriticalSection_WriteHeavy;

    [Test]
    procedure Test_MREW_WriteHeavy;

    // ---- High concurrency: 16 threads, read-heavy ----
    [Test]
    procedure Test_CriticalSection_HighConcurrency;

    [Test]
    procedure Test_MREW_HighConcurrency;

    // ---- Scalability sweep: MREW at 2, 4, 8, 16 threads ----
    [Test]
    procedure Test_Scalability_2_4_8_16_Threads;
  end;

implementation

uses
  UniBase.Benchmark;

{ ============================================================================
  TLockContentionBenchmark - Private helpers
  ============================================================================ }

function TLockContentionBenchmark.FormatThroughput(const TestName: string;
  const Sample: TContentionSample): string;
begin
  Result := Format('%s: %.0f ops/sec (%d ops in %.2f ms)',
    [TestName, Sample.Throughput, Sample.TotalOps, Sample.ElapsedMs]);
end;

procedure TLockContentionBenchmark.WaitForAll(const Threads: TArray<TThread>);
var
  T: TThread;
begin
  for T in Threads do
    T.WaitFor;
end;

{ ----------------------------------------------------------------------------
  RunCriticalSectionWorkload

  Spawns Profile.ThreadCount threads that each perform Profile.Iterations
  operations on FSharedCounter, protected by a TCriticalSection.
  Returns timing and throughput in Sample.
  ---------------------------------------------------------------------------- }

procedure TLockContentionBenchmark.RunCriticalSectionWorkload(
  const Profile: TWorkloadProfile; out Sample: TContentionSample);
var
  CS: TCriticalSection;
  Threads: TArray<TThread>;
  Counter: Int64;
  ThreadCount, Iterations, ReadPercent: Integer;
  SW: TStopwatch;
  I: Integer;

  procedure CreateThreads;
  var
    J: Integer;
  begin
    SetLength(Threads, ThreadCount);
    for J := 0 to ThreadCount - 1 do
    begin
      Threads[J] := TThread.CreateAnonymousThread(
        procedure
        var
          K: Integer;
          Roll: Integer;
          LocalReads, LocalWrites: Int64;
        begin
          LocalReads := 0;
          LocalWrites := 0;
          Randomize; // per-thread random seed
          for K := 1 to Iterations do
          begin
            Roll := Random(100);
            if Roll < ReadPercent then
            begin
              // Read operation
              CS.Acquire;
              try
                LocalReads := LocalReads + Counter;
              finally
                CS.Release;
              end;
            end
            else
            begin
              // Write operation
              CS.Acquire;
              try
                Counter := Counter + 1;
                LocalWrites := LocalWrites + 1;
              finally
                CS.Release;
              end;
            end;
          end;
          // Suppress unused-variable hints
          if LocalReads < 0 then;
          if LocalWrites < 0 then;
        end);
      Threads[J].FreeOnTerminate := False;
    end;
  end;

begin
  ThreadCount := Profile.ThreadCount;
  Iterations := Profile.Iterations;
  ReadPercent := Profile.ReadPercent;
  Counter := 0;

  CS := TCriticalSection.Create;
  try
    // ---- Warmup ----
    CreateThreads;
    for I := 0 to ThreadCount - 1 do
      Threads[I].Start;
    WaitForAll(Threads);
    for I := 0 to ThreadCount - 1 do
      FreeAndNil(Threads[I]);
    Counter := 0;

    // ---- Measured run ----
    SW := TStopwatch.Create;
    SW.Start;
    CreateThreads;
    for I := 0 to ThreadCount - 1 do
      Threads[I].Start;
    WaitForAll(Threads);
    SW.Stop;

    // ---- Cleanup threads ----
    for I := 0 to ThreadCount - 1 do
      FreeAndNil(Threads[I]);

    Sample.ElapsedMs := SW.ElapsedMilliseconds;
    Sample.TotalOps := Int64(ThreadCount) * Int64(Iterations);
    if Sample.ElapsedMs > 0 then
      Sample.Throughput := (Sample.TotalOps / Sample.ElapsedMs) * 1000.0
    else
      Sample.Throughput := 0;
  finally
    CS.Free;
  end;
end;

{ ----------------------------------------------------------------------------
  RunMREWWorkload

  Same as RunCriticalSectionWorkload but uses
  TMultiReadExclusiveWriteSynchronizer with BeginRead/EndRead and
  BeginWrite/EndWrite.
  ---------------------------------------------------------------------------- }

procedure TLockContentionBenchmark.RunMREWWorkload(
  const Profile: TWorkloadProfile; out Sample: TContentionSample);
var
  MREW: TMultiReadExclusiveWriteSynchronizer;
  Threads: TArray<TThread>;
  Counter: Int64;
  ThreadCount, Iterations, ReadPercent: Integer;
  SW: TStopwatch;
  I: Integer;

  procedure CreateThreads;
  var
    J: Integer;
  begin
    SetLength(Threads, ThreadCount);
    for J := 0 to ThreadCount - 1 do
    begin
      Threads[J] := TThread.CreateAnonymousThread(
        procedure
        var
          K: Integer;
          Roll: Integer;
          LocalReads, LocalWrites: Int64;
        begin
          LocalReads := 0;
          LocalWrites := 0;
          Randomize;
          for K := 1 to Iterations do
          begin
            Roll := Random(100);
            if Roll < ReadPercent then
            begin
              // Read operation - shared (concurrent) access
              MREW.BeginRead;
              try
                LocalReads := LocalReads + Counter;
              finally
                MREW.EndRead;
              end;
            end
            else
            begin
              // Write operation - exclusive access
              MREW.BeginWrite;
              try
                Counter := Counter + 1;
                LocalWrites := LocalWrites + 1;
              finally
                MREW.EndWrite;
              end;
            end;
          end;
          if LocalReads < 0 then;
          if LocalWrites < 0 then;
        end);
      Threads[J].FreeOnTerminate := False;
    end;
  end;

begin
  ThreadCount := Profile.ThreadCount;
  Iterations := Profile.Iterations;
  ReadPercent := Profile.ReadPercent;
  Counter := 0;

  MREW := TMultiReadExclusiveWriteSynchronizer.Create;
  try
    // ---- Warmup ----
    CreateThreads;
    for I := 0 to ThreadCount - 1 do
      Threads[I].Start;
    WaitForAll(Threads);
    for I := 0 to ThreadCount - 1 do
      FreeAndNil(Threads[I]);
    Counter := 0;

    // ---- Measured run ----
    SW := TStopwatch.Create;
    SW.Start;
    CreateThreads;
    for I := 0 to ThreadCount - 1 do
      Threads[I].Start;
    WaitForAll(Threads);
    SW.Stop;

    // ---- Cleanup threads ----
    for I := 0 to ThreadCount - 1 do
      FreeAndNil(Threads[I]);

    Sample.ElapsedMs := SW.ElapsedMilliseconds;
    Sample.TotalOps := Int64(ThreadCount) * Int64(Iterations);
    if Sample.ElapsedMs > 0 then
      Sample.Throughput := (Sample.TotalOps / Sample.ElapsedMs) * 1000.0
    else
      Sample.Throughput := 0;
  finally
    MREW.Free;
  end;
end;

{ ============================================================================
  TLockContentionBenchmark - Test methods
  ============================================================================ }

{ ---- Read-heavy: 90% reads, 10% writes, 8 threads ---- }

procedure TLockContentionBenchmark.Test_CriticalSection_ReadHeavy;
var
  Profile: TWorkloadProfile;
  Sample: TContentionSample;
  Bench: TBenchmark;
begin
  Profile.Name := 'CriticalSection_ReadHeavy_8T';
  Profile.ReadPercent := 90;
  Profile.ThreadCount := 8;
  Profile.Iterations := ITERATIONS_PER_THREAD;

  Bench := TBenchmark.Create(Profile.Name);
  try
    Bench.WarmupIterations := 0;
    Bench.Iterations := 3;
    Bench.TrackMemory := False;
    Bench.Run(
      procedure
      begin
        RunCriticalSectionWorkload(Profile, Sample);
      end);

    Assert.Pass(FormatThroughput(Profile.Name, Sample));
  finally
    Bench.Free;
  end;
end;

procedure TLockContentionBenchmark.Test_MREW_ReadHeavy;
var
  Profile: TWorkloadProfile;
  Sample: TContentionSample;
  Bench: TBenchmark;
begin
  Profile.Name := 'MREW_ReadHeavy_8T';
  Profile.ReadPercent := 90;
  Profile.ThreadCount := 8;
  Profile.Iterations := ITERATIONS_PER_THREAD;

  Bench := TBenchmark.Create(Profile.Name);
  try
    Bench.WarmupIterations := 0;
    Bench.Iterations := 3;
    Bench.TrackMemory := False;
    Bench.Run(
      procedure
      begin
        RunMREWWorkload(Profile, Sample);
      end);

    Assert.Pass(FormatThroughput(Profile.Name, Sample));
  finally
    Bench.Free;
  end;
end;

{ ---- Write-heavy: 50% reads, 50% writes, 8 threads ---- }

procedure TLockContentionBenchmark.Test_CriticalSection_WriteHeavy;
var
  Profile: TWorkloadProfile;
  Sample: TContentionSample;
  Bench: TBenchmark;
begin
  Profile.Name := 'CriticalSection_WriteHeavy_8T';
  Profile.ReadPercent := 50;
  Profile.ThreadCount := 8;
  Profile.Iterations := ITERATIONS_PER_THREAD;

  Bench := TBenchmark.Create(Profile.Name);
  try
    Bench.WarmupIterations := 0;
    Bench.Iterations := 3;
    Bench.TrackMemory := False;
    Bench.Run(
      procedure
      begin
        RunCriticalSectionWorkload(Profile, Sample);
      end);

    Assert.Pass(FormatThroughput(Profile.Name, Sample));
  finally
    Bench.Free;
  end;
end;

procedure TLockContentionBenchmark.Test_MREW_WriteHeavy;
var
  Profile: TWorkloadProfile;
  Sample: TContentionSample;
  Bench: TBenchmark;
begin
  Profile.Name := 'MREW_WriteHeavy_8T';
  Profile.ReadPercent := 50;
  Profile.ThreadCount := 8;
  Profile.Iterations := ITERATIONS_PER_THREAD;

  Bench := TBenchmark.Create(Profile.Name);
  try
    Bench.WarmupIterations := 0;
    Bench.Iterations := 3;
    Bench.TrackMemory := False;
    Bench.Run(
      procedure
      begin
        RunMREWWorkload(Profile, Sample);
      end);

    Assert.Pass(FormatThroughput(Profile.Name, Sample));
  finally
    Bench.Free;
  end;
end;

{ ---- High concurrency: 16 threads, read-heavy ---- }

procedure TLockContentionBenchmark.Test_CriticalSection_HighConcurrency;
var
  Profile: TWorkloadProfile;
  Sample: TContentionSample;
  Bench: TBenchmark;
begin
  Profile.Name := 'CriticalSection_HighConcurrency_16T';
  Profile.ReadPercent := 90;
  Profile.ThreadCount := 16;
  Profile.Iterations := ITERATIONS_PER_THREAD;

  Bench := TBenchmark.Create(Profile.Name);
  try
    Bench.WarmupIterations := 0;
    Bench.Iterations := 3;
    Bench.TrackMemory := False;
    Bench.Run(
      procedure
      begin
        RunCriticalSectionWorkload(Profile, Sample);
      end);

    Assert.Pass(FormatThroughput(Profile.Name, Sample));
  finally
    Bench.Free;
  end;
end;

procedure TLockContentionBenchmark.Test_MREW_HighConcurrency;
var
  Profile: TWorkloadProfile;
  Sample: TContentionSample;
  Bench: TBenchmark;
begin
  Profile.Name := 'MREW_HighConcurrency_16T';
  Profile.ReadPercent := 90;
  Profile.ThreadCount := 16;
  Profile.Iterations := ITERATIONS_PER_THREAD;

  Bench := TBenchmark.Create(Profile.Name);
  try
    Bench.WarmupIterations := 0;
    Bench.Iterations := 3;
    Bench.TrackMemory := False;
    Bench.Run(
      procedure
      begin
        RunMREWWorkload(Profile, Sample);
      end);

    Assert.Pass(FormatThroughput(Profile.Name, Sample));
  finally
    Bench.Free;
  end;
end;

{ ---- Scalability sweep: MREW at 2, 4, 8, 16 threads ---- }

procedure TLockContentionBenchmark.Test_Scalability_2_4_8_16_Threads;
const
  ThreadCounts: array[0..3] of Integer = (2, 4, 8, 16);
var
  Profile: TWorkloadProfile;
  Sample: TContentionSample;
  Bench: TBenchmark;
  Idx: Integer;
  Summary: string;
begin
  Bench := TBenchmark.Create('MREW_Scalability_Sweep');
  try
    Bench.WarmupIterations := 0;
    Bench.Iterations := 3;
    Bench.TrackMemory := False;
    Bench.Report.Title := 'MREW Scalability (90% reads)';

    Summary := '';
    for Idx := Low(ThreadCounts) to High(ThreadCounts) do
    begin
      Profile.Name := Format('MREW_%dT_ReadHeavy', [ThreadCounts[Idx]]);
      Profile.ReadPercent := 90;
      Profile.ThreadCount := ThreadCounts[Idx];
      Profile.Iterations := ITERATIONS_PER_THREAD;

      Bench.Name := Profile.Name;
      Bench.Run(
        procedure
        begin
          RunMREWWorkload(Profile, Sample);
        end);

      Summary := Summary + Format('%s: %.0f ops/sec | ',
        [Profile.Name, Sample.Throughput]);
    end;

    // Trim trailing ' | '
    if Summary.EndsWith(' | ') then
      Summary := Summary.Substring(0, Summary.Length - 3);

    Assert.Pass(Summary);
  finally
    Bench.Free;
  end;
end;

{ ============================================================================
  Registration
  ============================================================================ }

initialization
  TDUnitX.RegisterTestFixture(TLockContentionBenchmark);

end.
