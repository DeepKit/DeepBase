{ ============================================================================
  Test.DeepBase.PerformanceSuite - Comprehensive Performance Benchmark Suite

  Version: 1.0
  Description: Performance benchmarks for establishing baselines and detecting
               regressions in DeepBase framework.

  Test Categories:
  - Memory allocation and usage patterns
  - Disk I/O throughput
  - Concurrency and threading
  - Core module performance (Cache, Config, Logger)

  Usage:
    Run these tests to establish performance baselines.
    Results are output for documentation and regression detection.
  ============================================================================ }

unit Test.DeepBase.PerformanceSuite;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.SyncObjs,
  System.Threading,
  System.IOUtils,
  System.DateUtils,
  System.JSON,
  DUnitX.TestFramework,
  DeepBase.Benchmark,
  DeepBase.Cache;

type
  // ============================================================================
  // Memory Benchmark Tests
  // ============================================================================

  [TestFixture]
  [Category('Performance')]
  TMemoryBenchmarkTests = class
  private
    FBenchmark: TBenchmark;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_SmallObjectAllocation_1000;

    [Test]
    procedure Test_SmallObjectAllocation_10000;

    [Test]
    procedure Test_LargeBufferAllocation;

    [Test]
    procedure Test_StringConcatenation;

    [Test]
    procedure Test_StringBuilderPerformance;

    [Test]
    procedure Test_DictionaryAddLookup;

    [Test]
    procedure Test_ListAddSort;

    [Test]
    procedure Test_MemoryPoolPattern;
  end;

  // ============================================================================
  // Disk I/O Benchmark Tests
  // ============================================================================

  [TestFixture]
  [Category('Performance')]
  TDiskIOBenchmarkTests = class
  private
    FBenchmark: TBenchmark;
    FTestDir: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_SequentialWrite_1KB;

    [Test]
    procedure Test_SequentialWrite_100KB;

    [Test]
    procedure Test_SequentialWrite_1MB;

    [Test]
    procedure Test_SequentialRead_1KB;

    [Test]
    procedure Test_SequentialRead_100KB;

    [Test]
    procedure Test_SequentialRead_1MB;

    [Test]
    procedure Test_RandomAccess;

    [Test]
    procedure Test_FileCreateDelete;
  end;

  // ============================================================================
  // Concurrency Benchmark Tests
  // ============================================================================

  [TestFixture]
  [Category('Performance')]
  TConcurrencyBenchmarkTests = class
  private
    FBenchmark: TBenchmark;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_ThreadCreation_4;

    [Test]
    procedure Test_ThreadCreation_8;

    [Test]
    procedure Test_CriticalSectionLocking;

    [Test]
    procedure Test_ReadWriteLock;

    [Test]
    procedure Test_AtomicIncrement;

    [Test]
    procedure Test_ThreadPoolTasks;

    [Test]
    procedure Test_EventSignaling;

    [Test]
    procedure Test_MonitorLocking;
  end;

  // ============================================================================
  // Core Module Benchmark Tests
  // ============================================================================

  [TestFixture]
  [Category('Performance')]
  TCoreBenchmarkTests = class
  private
    FBenchmark: TBenchmark;
    FCache: TCache<string, string>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_CachePut;

    [Test]
    procedure Test_CacheGetHit;

    [Test]
    procedure Test_CacheGetMiss;

    [Test]
    procedure Test_CacheEviction_LRU;

    [Test]
    procedure Test_JSONParsing;

    [Test]
    procedure Test_JSONGeneration;

    [Test]
    procedure Test_DateTimeFormatting;

    [Test]
    procedure Test_GUIDGeneration;
  end;

implementation

{ TMemoryBenchmarkTests }

procedure TMemoryBenchmarkTests.Setup;
begin
  FBenchmark := TBenchmark.Create('Memory');
  FBenchmark.Iterations := 100;
  FBenchmark.WarmupIterations := 5;
  FBenchmark.TrackMemory := True;
end;

procedure TMemoryBenchmarkTests.TearDown;
begin
  FBenchmark.Free;
end;

procedure TMemoryBenchmarkTests.Test_SmallObjectAllocation_1000;
var
  Result: TBenchmarkResult;
begin
  FBenchmark.Name := 'SmallObject_Alloc_1000';

  Result := FBenchmark.Run(
    procedure
    var
      Objects: TArray<TObject>;
      I: Integer;
    begin
      SetLength(Objects, 1000);
      for I := 0 to 999 do
        Objects[I] := TObject.Create;
      for I := 0 to 999 do
        Objects[I].Free;
    end);

  Assert.IsTrue(Result.TimingStats.Mean > 0);
  Assert.Pass(Format('Mean: %.2f us, P95: %.2f us, %.0f allocs/s',
    [Result.TimingStats.Mean, Result.TimingStats.P95,
     Result.ThroughputPerSecond * 1000]));
end;

procedure TMemoryBenchmarkTests.Test_SmallObjectAllocation_10000;
var
  Result: TBenchmarkResult;
begin
  FBenchmark.Name := 'SmallObject_Alloc_10000';
  FBenchmark.Iterations := 50;

  Result := FBenchmark.Run(
    procedure
    var
      Objects: TArray<TObject>;
      I: Integer;
    begin
      SetLength(Objects, 10000);
      for I := 0 to 9999 do
        Objects[I] := TObject.Create;
      for I := 0 to 9999 do
        Objects[I].Free;
    end);

  Assert.IsTrue(Result.TimingStats.Mean > 0);
  Assert.Pass(Format('Mean: %.2f us, P95: %.2f us, %.0f allocs/s',
    [Result.TimingStats.Mean, Result.TimingStats.P95,
     Result.ThroughputPerSecond * 10000]));
end;

procedure TMemoryBenchmarkTests.Test_LargeBufferAllocation;
var
  Result: TBenchmarkResult;
begin
  FBenchmark.Name := 'LargeBuffer_Alloc_1MB';
  FBenchmark.Iterations := 100;

  Result := FBenchmark.Run(
    procedure
    var
      Buffer: TBytes;
    begin
      SetLength(Buffer, 1024 * 1024);  // 1MB
      FillChar(Buffer[0], Length(Buffer), $AA);
      SetLength(Buffer, 0);
    end);

  Assert.IsTrue(Result.TimingStats.Mean > 0);
  Assert.Pass(Format('Mean: %.2f us, Heap delta: %d bytes',
    [Result.TimingStats.Mean, Result.MemoryDelta.HeapAllocated]));
end;

procedure TMemoryBenchmarkTests.Test_StringConcatenation;
var
  Result: TBenchmarkResult;
begin
  FBenchmark.Name := 'String_Concat_100';
  FBenchmark.Iterations := 500;

  Result := FBenchmark.Run(
    procedure
    var
      S: string;
      I: Integer;
    begin
      S := '';
      for I := 1 to 100 do
        S := S + 'Hello World ';
    end);

  Assert.IsTrue(Result.TimingStats.Mean > 0);
  Assert.Pass(Format('Mean: %.2f us per 100 concats', [Result.TimingStats.Mean]));
end;

procedure TMemoryBenchmarkTests.Test_StringBuilderPerformance;
var
  Result: TBenchmarkResult;
begin
  FBenchmark.Name := 'StringBuilder_100';
  FBenchmark.Iterations := 500;

  Result := FBenchmark.Run(
    procedure
    var
      SB: TStringBuilder;
      I: Integer;
    begin
      SB := TStringBuilder.Create;
      try
        for I := 1 to 100 do
          SB.Append('Hello World ');
      finally
        SB.Free;
      end;
    end);

  Assert.IsTrue(Result.TimingStats.Mean > 0);
  Assert.Pass(Format('Mean: %.2f us per 100 appends', [Result.TimingStats.Mean]));
end;

procedure TMemoryBenchmarkTests.Test_DictionaryAddLookup;
var
  Dict: TDictionary<string, Integer>;
  Result: TBenchmarkResult;
begin
  FBenchmark.Name := 'Dictionary_1000_AddGet';
  Dict := TDictionary<string, Integer>.Create;
  try
    Result := FBenchmark.Run(
      procedure
      var
        I, V: Integer;
      begin
        Dict.Clear;
        for I := 1 to 1000 do
          Dict.Add('Key' + IntToStr(I), I);
        for I := 1 to 1000 do
          Dict.TryGetValue('Key' + IntToStr(I), V);
      end);

    Assert.IsTrue(Result.TimingStats.Mean > 0);
    Assert.Pass(Format('Mean: %.2f us for 1000 add + 1000 get',
      [Result.TimingStats.Mean]));
  finally
    Dict.Free;
  end;
end;

procedure TMemoryBenchmarkTests.Test_ListAddSort;
var
  List: TList<Integer>;
  Result: TBenchmarkResult;
begin
  FBenchmark.Name := 'List_10000_AddSort';
  FBenchmark.Iterations := 50;
  List := TList<Integer>.Create;
  try
    Result := FBenchmark.Run(
      procedure
      var
        I: Integer;
      begin
        List.Clear;
        for I := 1 to 10000 do
          List.Add(Random(100000));
        List.Sort;
      end);

    Assert.IsTrue(Result.TimingStats.Mean > 0);
    Assert.Pass(Format('Mean: %.2f us for 10000 add + sort',
      [Result.TimingStats.Mean]));
  finally
    List.Free;
  end;
end;

procedure TMemoryBenchmarkTests.Test_MemoryPoolPattern;
var
  Pool: TList<TObject>;
  Result: TBenchmarkResult;
begin
  FBenchmark.Name := 'MemoryPool_100_AcquireRelease';
  Pool := TList<TObject>.Create;
  Pool.Capacity := 100;
  try
    Result := FBenchmark.Run(
      procedure
      var
        Obj: TObject;
        I: Integer;
      begin
        for I := 1 to 100 do
        begin
          // Acquire
          if Pool.Count > 0 then
          begin
            Obj := Pool.Last;
            Pool.Delete(Pool.Count - 1);
          end
          else
            Obj := TObject.Create;

          // Release
          Pool.Add(Obj);
        end;
      end);

    Assert.IsTrue(Result.TimingStats.Mean > 0);
    Assert.Pass(Format('Mean: %.2f us for 100 acquire/release',
      [Result.TimingStats.Mean]));
  finally
    while Pool.Count > 0 do
    begin
      Pool.Last.Free;
      Pool.Delete(Pool.Count - 1);
    end;
    Pool.Free;
  end;
end;

{ TDiskIOBenchmarkTests }

procedure TDiskIOBenchmarkTests.Setup;
begin
  FBenchmark := TBenchmark.Create('DiskIO');
  FBenchmark.Iterations := 30;
  FBenchmark.WarmupIterations := 3;
  FTestDir := TPath.Combine(TPath.Combine(TDirectory.GetCurrentDirectory,
    'TestResults'), 'BenchmarkTemp_' + FormatDateTime('hhnnsszzz', Now));
  ForceDirectories(FTestDir);
end;

procedure TDiskIOBenchmarkTests.TearDown;
begin
  FBenchmark.Free;
  if TDirectory.Exists(FTestDir) then
    TDirectory.Delete(FTestDir, True);
end;

procedure TDiskIOBenchmarkTests.Test_SequentialWrite_1KB;
var
  Data: TBytes;
  FileName: string;
  Result: TBenchmarkResult;
begin
  SetLength(Data, 1024);
  FillChar(Data[0], Length(Data), $AA);
  FileName := TPath.Combine(FTestDir, 'write_1kb.bin');
  FBenchmark.Name := 'SequentialWrite_1KB';

  Result := FBenchmark.Run(
    procedure
    begin
      TFile.WriteAllBytes(FileName, Data);
    end);

  if TFile.Exists(FileName) then
    TFile.Delete(FileName);

  Assert.IsTrue(Result.TimingStats.Mean > 0);
  Assert.Pass(Format('Mean: %.2f us, %.2f MB/s',
    [Result.TimingStats.Mean,
     (1024 / 1048576) / (Result.TimingStats.Mean / 1000000)]));
end;

procedure TDiskIOBenchmarkTests.Test_SequentialWrite_100KB;
var
  Data: TBytes;
  FileName: string;
  Result: TBenchmarkResult;
begin
  SetLength(Data, 102400);
  FillChar(Data[0], Length(Data), $AA);
  FileName := TPath.Combine(FTestDir, 'write_100kb.bin');
  FBenchmark.Name := 'SequentialWrite_100KB';

  Result := FBenchmark.Run(
    procedure
    begin
      TFile.WriteAllBytes(FileName, Data);
    end);

  if TFile.Exists(FileName) then
    TFile.Delete(FileName);

  Assert.IsTrue(Result.TimingStats.Mean > 0);
  Assert.Pass(Format('Mean: %.2f us, %.2f MB/s',
    [Result.TimingStats.Mean,
     (102400 / 1048576) / (Result.TimingStats.Mean / 1000000)]));
end;

procedure TDiskIOBenchmarkTests.Test_SequentialWrite_1MB;
var
  Data: TBytes;
  FileName: string;
  Result: TBenchmarkResult;
begin
  SetLength(Data, 1048576);
  FillChar(Data[0], Length(Data), $AA);
  FileName := TPath.Combine(FTestDir, 'write_1mb.bin');
  FBenchmark.Name := 'SequentialWrite_1MB';
  FBenchmark.Iterations := 20;

  Result := FBenchmark.Run(
    procedure
    begin
      TFile.WriteAllBytes(FileName, Data);
    end);

  if TFile.Exists(FileName) then
    TFile.Delete(FileName);

  Assert.IsTrue(Result.TimingStats.Mean > 0);
  Assert.Pass(Format('Mean: %.2f us, %.2f MB/s',
    [Result.TimingStats.Mean,
     1.0 / (Result.TimingStats.Mean / 1000000)]));
end;

procedure TDiskIOBenchmarkTests.Test_SequentialRead_1KB;
var
  Data, ReadData: TBytes;
  FileName: string;
  Result: TBenchmarkResult;
begin
  SetLength(Data, 1024);
  FillChar(Data[0], Length(Data), $AA);
  FileName := TPath.Combine(FTestDir, 'read_1kb.bin');
  TFile.WriteAllBytes(FileName, Data);
  FBenchmark.Name := 'SequentialRead_1KB';

  Result := FBenchmark.Run(
    procedure
    begin
      ReadData := TFile.ReadAllBytes(FileName);
    end);

  TFile.Delete(FileName);

  Assert.IsTrue(Result.TimingStats.Mean > 0);
  Assert.Pass(Format('Mean: %.2f us, %.2f MB/s',
    [Result.TimingStats.Mean,
     (1024 / 1048576) / (Result.TimingStats.Mean / 1000000)]));
end;

procedure TDiskIOBenchmarkTests.Test_SequentialRead_100KB;
var
  Data, ReadData: TBytes;
  FileName: string;
  Result: TBenchmarkResult;
begin
  SetLength(Data, 102400);
  FillChar(Data[0], Length(Data), $AA);
  FileName := TPath.Combine(FTestDir, 'read_100kb.bin');
  TFile.WriteAllBytes(FileName, Data);
  FBenchmark.Name := 'SequentialRead_100KB';

  Result := FBenchmark.Run(
    procedure
    begin
      ReadData := TFile.ReadAllBytes(FileName);
    end);

  TFile.Delete(FileName);

  Assert.IsTrue(Result.TimingStats.Mean > 0);
  Assert.Pass(Format('Mean: %.2f us, %.2f MB/s',
    [Result.TimingStats.Mean,
     (102400 / 1048576) / (Result.TimingStats.Mean / 1000000)]));
end;

procedure TDiskIOBenchmarkTests.Test_SequentialRead_1MB;
var
  Data, ReadData: TBytes;
  FileName: string;
  Result: TBenchmarkResult;
begin
  SetLength(Data, 1048576);
  FillChar(Data[0], Length(Data), $AA);
  FileName := TPath.Combine(FTestDir, 'read_1mb.bin');
  TFile.WriteAllBytes(FileName, Data);
  FBenchmark.Name := 'SequentialRead_1MB';
  FBenchmark.Iterations := 20;

  Result := FBenchmark.Run(
    procedure
    begin
      ReadData := TFile.ReadAllBytes(FileName);
    end);

  TFile.Delete(FileName);

  Assert.IsTrue(Result.TimingStats.Mean > 0);
  Assert.Pass(Format('Mean: %.2f us, %.2f MB/s',
    [Result.TimingStats.Mean,
     1.0 / (Result.TimingStats.Mean / 1000000)]));
end;

procedure TDiskIOBenchmarkTests.Test_RandomAccess;
var
  FileName: string;
  Data: TBytes;
  Result: TBenchmarkResult;
begin
  FileName := TPath.Combine(FTestDir, 'random_1mb.bin');
  SetLength(Data, 1048576);
  FillChar(Data[0], Length(Data), $AA);
  TFile.WriteAllBytes(FileName, Data);

  FBenchmark.Name := 'RandomAccess_100x4KB';
  SetLength(Data, 4096);

  Result := FBenchmark.Run(
    procedure
    var
      FS: TFileStream;
      I: Integer;
      Pos: Int64;
    begin
      FS := TFileStream.Create(FileName, fmOpenRead);
      try
        for I := 1 to 100 do
        begin
          Pos := Random(1048576 - 4096);
          FS.Position := Pos;
          FS.ReadBuffer(Data[0], 4096);
        end;
      finally
        FS.Free;
      end;
    end);

  TFile.Delete(FileName);

  Assert.IsTrue(Result.TimingStats.Mean > 0);
  Assert.Pass(Format('Mean: %.2f us for 100 random 4KB reads',
    [Result.TimingStats.Mean]));
end;

procedure TDiskIOBenchmarkTests.Test_FileCreateDelete;
var
  Result: TBenchmarkResult;
begin
  FBenchmark.Name := 'FileCreateDelete_50';

  Result := FBenchmark.Run(
    procedure
    var
      I: Integer;
      FileName: string;
      FS: TFileStream;
    begin
      for I := 1 to 50 do
      begin
        FileName := TPath.Combine(FTestDir, Format('temp_%d.tmp', [I]));
        FS := TFileStream.Create(FileName, fmCreate);
        FS.Free;
        TFile.Delete(FileName);
      end;
    end);

  Assert.IsTrue(Result.TimingStats.Mean > 0);
  Assert.Pass(Format('Mean: %.2f us for 50 create+delete',
    [Result.TimingStats.Mean]));
end;

{ TConcurrencyBenchmarkTests }

procedure TConcurrencyBenchmarkTests.Setup;
begin
  FBenchmark := TBenchmark.Create('Concurrency');
  FBenchmark.Iterations := 50;
  FBenchmark.WarmupIterations := 3;
end;

procedure TConcurrencyBenchmarkTests.TearDown;
begin
  FBenchmark.Free;
end;

procedure TConcurrencyBenchmarkTests.Test_ThreadCreation_4;
var
  Result: TBenchmarkResult;
begin
  FBenchmark.Name := 'ThreadCreate_4';

  Result := FBenchmark.Run(
    procedure
    var
      Threads: array[0..3] of TThread;
      I: Integer;
    begin
      for I := 0 to 3 do
      begin
        Threads[I] := TThread.CreateAnonymousThread(procedure begin end);
        Threads[I].FreeOnTerminate := False;
        Threads[I].Start;
      end;
      for I := 0 to 3 do
      begin
        Threads[I].WaitFor;
        Threads[I].Free;
      end;
    end);

  Assert.IsTrue(Result.TimingStats.Mean > 0);
  Assert.Pass(Format('Mean: %.2f us for 4 threads', [Result.TimingStats.Mean]));
end;

procedure TConcurrencyBenchmarkTests.Test_ThreadCreation_8;
var
  Result: TBenchmarkResult;
begin
  FBenchmark.Name := 'ThreadCreate_8';

  Result := FBenchmark.Run(
    procedure
    var
      Threads: array[0..7] of TThread;
      I: Integer;
    begin
      for I := 0 to 7 do
      begin
        Threads[I] := TThread.CreateAnonymousThread(procedure begin end);
        Threads[I].FreeOnTerminate := False;
        Threads[I].Start;
      end;
      for I := 0 to 7 do
      begin
        Threads[I].WaitFor;
        Threads[I].Free;
      end;
    end);

  Assert.IsTrue(Result.TimingStats.Mean > 0);
  Assert.Pass(Format('Mean: %.2f us for 8 threads', [Result.TimingStats.Mean]));
end;

procedure TConcurrencyBenchmarkTests.Test_CriticalSectionLocking;
var
  CS: TCriticalSection;
  Result: TBenchmarkResult;
begin
  FBenchmark.Name := 'CriticalSection_10000';
  FBenchmark.Iterations := 100;
  CS := TCriticalSection.Create;
  try
    Result := FBenchmark.Run(
      procedure
      var
        I, Counter: Integer;
      begin
        Counter := 0;
        for I := 1 to 10000 do
        begin
          CS.Enter;
          try
            Inc(Counter);
          finally
            CS.Leave;
          end;
        end;
      end);

    Assert.IsTrue(Result.TimingStats.Mean > 0);
    Assert.Pass(Format('Mean: %.2f us for 10000 lock/unlock',
      [Result.TimingStats.Mean]));
  finally
    CS.Free;
  end;
end;

procedure TConcurrencyBenchmarkTests.Test_ReadWriteLock;
var
  RWLock: TMultiReadExclusiveWriteSynchronizer;
  Result: TBenchmarkResult;
begin
  FBenchmark.Name := 'ReadWriteLock_1000';
  FBenchmark.Iterations := 100;
  RWLock := TMultiReadExclusiveWriteSynchronizer.Create;
  try
    Result := FBenchmark.Run(
      procedure
      var
        I, Value, V: Integer;
      begin
        Value := 0;
        // 90% reads, 10% writes
        for I := 1 to 1000 do
        begin
          if I mod 10 = 0 then
          begin
            RWLock.BeginWrite;
            try
              Inc(Value);
            finally
              RWLock.EndWrite;
            end;
          end
          else
          begin
            RWLock.BeginRead;
            try
              V := Value;
            finally
              RWLock.EndRead;
            end;
          end;
        end;
      end);

    Assert.IsTrue(Result.TimingStats.Mean > 0);
    Assert.Pass(Format('Mean: %.2f us for 900 reads + 100 writes',
      [Result.TimingStats.Mean]));
  finally
    RWLock.Free;
  end;
end;

procedure TConcurrencyBenchmarkTests.Test_AtomicIncrement;
var
  Result: TBenchmarkResult;
begin
  FBenchmark.Name := 'AtomicIncrement_100000';
  FBenchmark.Iterations := 100;

  Result := FBenchmark.Run(
    procedure
    var
      Counter, I: Integer;
    begin
      Counter := 0;
      for I := 1 to 100000 do
        TInterlocked.Increment(Counter);
    end);

  Assert.IsTrue(Result.TimingStats.Mean > 0);
  Assert.Pass(Format('Mean: %.2f us for 100000 atomic increments',
    [Result.TimingStats.Mean]));
end;

procedure TConcurrencyBenchmarkTests.Test_ThreadPoolTasks;
var
  Result: TBenchmarkResult;
begin
  FBenchmark.Name := 'ThreadPool_100Tasks';
  FBenchmark.Iterations := 30;

  Result := FBenchmark.Run(
    procedure
    var
      Tasks: array of ITask;
      I: Integer;
    begin
      SetLength(Tasks, 100);
      for I := 0 to 99 do
        Tasks[I] := TTask.Run(procedure begin Sleep(0); end);
      TTask.WaitForAll(Tasks);
    end);

  Assert.IsTrue(Result.TimingStats.Mean > 0);
  Assert.Pass(Format('Mean: %.2f us for 100 tasks', [Result.TimingStats.Mean]));
end;

procedure TConcurrencyBenchmarkTests.Test_EventSignaling;
var
  Event: TEvent;
  Result: TBenchmarkResult;
begin
  FBenchmark.Name := 'EventSignal_10000';
  FBenchmark.Iterations := 100;
  Event := TEvent.Create(nil, False, False, '');
  try
    Result := FBenchmark.Run(
      procedure
      var
        I: Integer;
      begin
        for I := 1 to 10000 do
        begin
          Event.SetEvent;
          Event.ResetEvent;
        end;
      end);

    Assert.IsTrue(Result.TimingStats.Mean > 0);
    Assert.Pass(Format('Mean: %.2f us for 10000 set/reset',
      [Result.TimingStats.Mean]));
  finally
    Event.Free;
  end;
end;

procedure TConcurrencyBenchmarkTests.Test_MonitorLocking;
var
  LockObj: TObject;
  Result: TBenchmarkResult;
begin
  FBenchmark.Name := 'Monitor_10000';
  FBenchmark.Iterations := 100;
  LockObj := TObject.Create;
  try
    Result := FBenchmark.Run(
      procedure
      var
        I, Counter: Integer;
      begin
        Counter := 0;
        for I := 1 to 10000 do
        begin
          TMonitor.Enter(LockObj);
          try
            Inc(Counter);
          finally
            TMonitor.Exit(LockObj);
          end;
        end;
      end);

    Assert.IsTrue(Result.TimingStats.Mean > 0);
    Assert.Pass(Format('Mean: %.2f us for 10000 monitor lock/unlock',
      [Result.TimingStats.Mean]));
  finally
    LockObj.Free;
  end;
end;

{ TCoreBenchmarkTests }

procedure TCoreBenchmarkTests.Setup;
begin
  FBenchmark := TBenchmark.Create('Core');
  FBenchmark.Iterations := 500;
  FBenchmark.WarmupIterations := 10;
  FCache := TCache<string, string>.Create;
  FCache.MaxItems := 10000;
  FCache.EvictionPolicy := cepLRU;
end;

procedure TCoreBenchmarkTests.TearDown;
begin
  FCache.Free;
  FBenchmark.Free;
end;

procedure TCoreBenchmarkTests.Test_CachePut;
var
  Result: TBenchmarkResult;
  I: Integer;
begin
  FBenchmark.Name := 'Cache_Put';
  I := 0;

  Result := FBenchmark.Run(
    procedure
    begin
      Inc(I);
      FCache.Put('key_' + IntToStr(I), 'value_' + IntToStr(I));
    end);

  Assert.IsTrue(Result.TimingStats.Mean > 0);
  Assert.Pass(Format('Mean: %.2f us, Throughput: %.0f ops/s',
    [Result.TimingStats.Mean, Result.ThroughputPerSecond]));
end;

procedure TCoreBenchmarkTests.Test_CacheGetHit;
var
  Result: TBenchmarkResult;
  Value: string;
  I: Integer;
begin
  // Pre-populate
  for I := 1 to 1000 do
    FCache.Put('key_' + IntToStr(I), 'value_' + IntToStr(I));

  FBenchmark.Name := 'Cache_Get_Hit';
  I := 0;

  Result := FBenchmark.Run(
    procedure
    begin
      Inc(I);
      if I > 1000 then I := 1;
      FCache.TryGet('key_' + IntToStr(I), Value);
    end);

  Assert.IsTrue(Result.TimingStats.Mean > 0);
  Assert.Pass(Format('Mean: %.2f us (hit), Throughput: %.0f ops/s',
    [Result.TimingStats.Mean, Result.ThroughputPerSecond]));
end;

procedure TCoreBenchmarkTests.Test_CacheGetMiss;
var
  Result: TBenchmarkResult;
  Value: string;
  I: Integer;
begin
  FBenchmark.Name := 'Cache_Get_Miss';
  I := 0;

  Result := FBenchmark.Run(
    procedure
    begin
      Inc(I);
      FCache.TryGet('nonexistent_' + IntToStr(I), Value);
    end);

  Assert.IsTrue(Result.TimingStats.Mean > 0);
  Assert.Pass(Format('Mean: %.2f us (miss), Throughput: %.0f ops/s',
    [Result.TimingStats.Mean, Result.ThroughputPerSecond]));
end;

procedure TCoreBenchmarkTests.Test_CacheEviction_LRU;
var
  SmallCache: TCache<string, string>;
  Result: TBenchmarkResult;
  I: Integer;
begin
  SmallCache := TCache<string, string>.Create;
  SmallCache.MaxItems := 100;
  SmallCache.EvictionPolicy := cepLRU;
  try
    FBenchmark.Name := 'Cache_Eviction_LRU';
    FBenchmark.Iterations := 100;
    I := 0;

    Result := FBenchmark.Run(
      procedure
      var
        J: Integer;
      begin
        for J := 1 to 200 do
        begin
          Inc(I);
          SmallCache.Put('key_' + IntToStr(I), 'value');
        end;
      end);

    Assert.IsTrue(Result.TimingStats.Mean > 0);
    Assert.Pass(Format('Mean: %.2f us for 200 puts with eviction, Evictions: %d',
      [Result.TimingStats.Mean, SmallCache.Stats.Evictions]));
  finally
    SmallCache.Free;
  end;
end;

procedure TCoreBenchmarkTests.Test_JSONParsing;
var
  JSON: string;
  Result: TBenchmarkResult;
begin
  JSON := '{"id":12345,"name":"Test User","email":"test@example.com",' +
          '"active":true,"scores":[95,87,92,88,91],"metadata":{"level":5}}';
  FBenchmark.Name := 'JSON_Parse';

  Result := FBenchmark.Run(
    procedure
    var
      JObj: TJSONObject;
    begin
      JObj := TJSONObject.ParseJSONValue(JSON) as TJSONObject;
      JObj.Free;
    end);

  Assert.IsTrue(Result.TimingStats.Mean > 0);
  Assert.Pass(Format('Mean: %.2f us per parse, Throughput: %.0f ops/s',
    [Result.TimingStats.Mean, Result.ThroughputPerSecond]));
end;

procedure TCoreBenchmarkTests.Test_JSONGeneration;
var
  Result: TBenchmarkResult;
begin
  FBenchmark.Name := 'JSON_Generate';

  Result := FBenchmark.Run(
    procedure
    var
      JObj: TJSONObject;
      JArr: TJSONArray;
      S: string;
    begin
      JObj := TJSONObject.Create;
      try
        JObj.AddPair('id', TJSONNumber.Create(12345));
        JObj.AddPair('name', 'Test User');
        JObj.AddPair('email', 'test@example.com');
        JObj.AddPair('active', TJSONBool.Create(True));
        JArr := TJSONArray.Create;
        JArr.Add(95);
        JArr.Add(87);
        JArr.Add(92);
        JObj.AddPair('scores', JArr);
        S := JObj.ToJSON;
      finally
        JObj.Free;
      end;
    end);

  Assert.IsTrue(Result.TimingStats.Mean > 0);
  Assert.Pass(Format('Mean: %.2f us per generate, Throughput: %.0f ops/s',
    [Result.TimingStats.Mean, Result.ThroughputPerSecond]));
end;

procedure TCoreBenchmarkTests.Test_DateTimeFormatting;
var
  Result: TBenchmarkResult;
begin
  FBenchmark.Name := 'DateTime_Format';
  FBenchmark.Iterations := 1000;

  Result := FBenchmark.Run(
    procedure
    var
      S: string;
    begin
      S := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now);
    end);

  Assert.IsTrue(Result.TimingStats.Mean > 0);
  Assert.Pass(Format('Mean: %.2f us per format, Throughput: %.0f ops/s',
    [Result.TimingStats.Mean, Result.ThroughputPerSecond]));
end;

procedure TCoreBenchmarkTests.Test_GUIDGeneration;
var
  Result: TBenchmarkResult;
begin
  FBenchmark.Name := 'GUID_Generate';
  FBenchmark.Iterations := 1000;

  Result := FBenchmark.Run(
    procedure
    var
      G: TGUID;
      S: string;
    begin
      CreateGUID(G);
      S := GUIDToString(G);
    end);

  Assert.IsTrue(Result.TimingStats.Mean > 0);
  Assert.Pass(Format('Mean: %.2f us per GUID, Throughput: %.0f ops/s',
    [Result.TimingStats.Mean, Result.ThroughputPerSecond]));
end;

initialization
  TDUnitX.RegisterTestFixture(TMemoryBenchmarkTests);
  TDUnitX.RegisterTestFixture(TDiskIOBenchmarkTests);
  TDUnitX.RegisterTestFixture(TConcurrencyBenchmarkTests);
  TDUnitX.RegisterTestFixture(TCoreBenchmarkTests);

end.
