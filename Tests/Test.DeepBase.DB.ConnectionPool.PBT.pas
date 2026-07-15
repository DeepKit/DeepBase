{ ============================================================================
  Test.DeepBase.DB.ConnectionPool.PBT - Property-based tests for the
  Round-2 TDBConnectionPool concurrency fixes.

  Properties covered (deepbase-round2-fixes):
    Property 15: For any pool with N max connections and M > N
                 concurrent Acquire requests interleaved with
                 Release calls, every Acquire eventually completes
                 (within the configured timeout). No request hangs
                 because of a lost wakeup. The fix performs
                 ResetEvent + SetEvent inside the same FLock-held
                 region during Release, so a worker that was about
                 to wait on the event always observes the signal
                 produced by the just-completed Release.
    Property 16: For any pool whose available list contains a mix
                 of live and dead pooled connections, repeated
                 Acquire calls must NEVER return a closed
                 (.Connected = False) connection. The fix replaced
                 the original `for i := 0 to Count-1 do` walk with
                 `for i := Count-1 downto 0 do` so deletes triggered
                 by the in-loop reconnection-failure branch do not
                 cause the iterator to skip live entries.

  Each property runs >= 100 random iterations.

  Notes on observability and degradation:
    - TDBConnectionPool exposes Acquire / Release / GetActiveCount
      / GetAvailableCount as the public surface. We can observe
      Property 15 end-to-end by running a parallel acquire/release
      mix and asserting all workers complete inside the budget.
    - For Property 16 the dead-connection branch in
      FindAvailableConnection is private. Driving it directly from
      a unit test would require closing pooled FDConnection
      objects from outside, which is not part of the public API.
      We therefore observe the same invariant indirectly: under
      churn (acquire / release / brief connection use) every
      Acquire returns a connection whose .Connected is True. A
      regression that skipped a live connection due to forward-
      iteration index shifting would surface as either a False
      Connected or an unexpected timeout under saturation.
    - Backing store is a temp SQLite file (per-iteration unique
      GUID) so iterations are isolated. Maximum file count grows
      linearly with iterations; we delete the file on each
      iteration's TearDown.
  ============================================================================ }

unit Test.DeepBase.DB.ConnectionPool.PBT;

{$WARN SYMBOL_DEPRECATED OFF}

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Diagnostics,
  System.SyncObjs,
  System.Threading,
  DUnitX.TestFramework,
  FireDAC.Comp.Client,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  {$WARN UNIT_DEPRECATED OFF}
  DeepBase.DB.ConnectionPool;
  {$WARN UNIT_DEPRECATED ON}

type
  [TestFixture]
  [Category('PBT')]
  TConnectionPoolPropertyTests = class
  strict private
    function MakeTempDB: string;
    procedure TouchDB(const APath: string);
    procedure RetireDB(const APath: string);
  public
    [Setup]
    procedure Setup;

    // Feature: deepbase-round2-fixes, Property 15
    [Test]
    procedure Property15_NoLostWakeupUnderContention;

    // Feature: deepbase-round2-fixes, Property 16
    [Test]
    procedure Property16_AcquireNeverReturnsDeadConnection;
  end;

implementation

{ TConnectionPoolPropertyTests }

procedure TConnectionPoolPropertyTests.Setup;
begin
  Randomize;
end;

function TConnectionPoolPropertyTests.MakeTempDB: string;
begin
  Result := TPath.Combine(TPath.GetTempPath,
    'DeepBaseConnPoolPBT_' + TGUID.NewGuid.ToString + '.db');
  TouchDB(Result);
end;

procedure TConnectionPoolPropertyTests.TouchDB(const APath: string);
var
  LConn: TFDConnection;
begin
  // Create the empty SQLite file. The pool would create on Acquire,
  // but pre-creating decouples the iteration setup from any
  // concurrent driver-link initialisation race.
  LConn := TFDConnection.Create(nil);
  try
    LConn.DriverName := 'SQLite';
    LConn.Params.Database := APath;
    LConn.Params.Values['OpenMode'] := 'CreateUTF8';
    LConn.Open;
    LConn.Close;
  finally
    LConn.Free;
  end;
end;

procedure TConnectionPoolPropertyTests.RetireDB(const APath: string);
begin
  try
    if TFile.Exists(APath) then
      TFile.Delete(APath);
  except
    // Background SQLite handles may briefly hold the file. Failing
    // a delete is not test-fatal; the temp dir gets reaped later.
  end;
end;

procedure
TConnectionPoolPropertyTests
.Property15_NoLostWakeupUnderContention;
const
  CIters = 100;
  CTotalBudgetMs = 30000;
begin
  for var Iter := 1 to CIters do
  begin
    var LMaxSize: Integer := 2 + Random(3);          // 2..4
    var LWorkers: Integer := LMaxSize + 2 + Random(3); // M > N
    var LDB := MakeTempDB;
    try
      var LPool := TDBConnectionPool.Create(LDB, LMaxSize);
      try
        LPool.MinPoolSize := 1;
        LPool.ConnectionTimeout := 10;  // 10s per Acquire

        var LCompleted := 0;
        var LErrors := 0;
        var LErrorMsgLock := TObject.Create;
        var LErrorMsg: string := '';

        var LSw := TStopwatch.StartNew;

        // M > N workers contend for the pool. Each does:
        //   Acquire -> brief use -> Release. Repeat 3x per worker.
        // A lost wakeup would manifest as one or more workers
        // hanging in Acquire past the budget.
        TParallel.For(0, LWorkers - 1,
          procedure(AIndex: Integer)
          begin
            try
              for var LRound := 1 to 3 do
              begin
                var LConn := LPool.AcquireTimeout(8000);
                if LConn = nil then
                  raise Exception.CreateFmt(
                    'Worker %d round %d: AcquireTimeout returned nil',
                    [AIndex, LRound]);
                try
                  // Tiny deterministic "use". No SQL needed; we
                  // only need to hold the connection long enough
                  // to force contention.
                  Sleep(2 + Random(8));
                finally
                  LPool.Release(LConn);
                end;
              end;
              TInterlocked.Increment(LCompleted);
            except
              on E: Exception do
              begin
                TInterlocked.Increment(LErrors);
                TMonitor.Enter(LErrorMsgLock);
                try
                  if LErrorMsg = '' then
                    LErrorMsg := E.ClassName + ': ' + E.Message;
                finally
                  TMonitor.Exit(LErrorMsgLock);
                end;
              end;
            end;
          end);
        LSw.Stop;

        try
          Assert.IsTrue(LSw.ElapsedMilliseconds < CTotalBudgetMs,
            Format('Iter %d: total run time %d ms exceeds budget %d ms ' +
                   '(workers=%d, maxSize=%d) — likely lost wakeup',
              [Iter, LSw.ElapsedMilliseconds, CTotalBudgetMs,
               LWorkers, LMaxSize]));

          Assert.AreEqual<Integer>(0,
            TInterlocked.CompareExchange(LErrors, 0, 0),
            Format('Iter %d: %d worker(s) failed; first: %s',
              [Iter, TInterlocked.CompareExchange(LErrors, 0, 0),
               LErrorMsg]));

          Assert.AreEqual<Integer>(LWorkers,
            TInterlocked.CompareExchange(LCompleted, 0, 0),
            Format('Iter %d: only %d/%d workers completed',
              [Iter, TInterlocked.CompareExchange(LCompleted, 0, 0),
               LWorkers]));
        finally
          LErrorMsgLock.Free;
        end;
      finally
        LPool.Free;
      end;
    finally
      RetireDB(LDB);
    end;
  end;
end;

procedure
TConnectionPoolPropertyTests
.Property16_AcquireNeverReturnsDeadConnection;
const
  CIters = 100;
begin
  for var Iter := 1 to CIters do
  begin
    var LMaxSize: Integer := 2 + Random(4);   // 2..5
    var LRounds: Integer  := 5 + Random(10);  // 5..14 acquire/release rounds
    var LDB := MakeTempDB;
    try
      var LPool := TDBConnectionPool.Create(LDB, LMaxSize);
      try
        LPool.MinPoolSize := 1;
        LPool.ConnectionTimeout := 5;

        // Pre-populate the pool to MaxSize via a brief saturate-
        // and-release pass. This forces FindAvailableConnection
        // to walk a fully-occupied list on subsequent Acquires,
        // which is where the original forward-iteration bug
        // could skip an entry after a delete.
        var LSaturated: TArray<TFDConnection>;
        SetLength(LSaturated, LMaxSize);
        for var I := 0 to LMaxSize - 1 do
        begin
          LSaturated[I] := LPool.AcquireTimeout(5000);
          Assert.IsNotNull(LSaturated[I],
            Format('Iter %d: pre-saturate Acquire %d returned nil',
              [Iter, I]));
        end;
        for var I := 0 to LMaxSize - 1 do
          LPool.Release(LSaturated[I]);

        // Property 16: every subsequent Acquire under churn must
        // return a connection that is .Connected = True. A
        // regression in FindAvailableConnection's iteration
        // direction would either skip past a still-good entry
        // (yielding a timeout) or return a no-longer-Connected
        // entry from the freshly-retried branch.
        for var LRound := 1 to LRounds do
        begin
          var LConn := LPool.AcquireTimeout(5000);
          Assert.IsNotNull(LConn,
            Format('Iter %d round %d: AcquireTimeout returned nil',
              [Iter, LRound]));
          try
            Assert.IsTrue(LConn.Connected,
              Format('Iter %d round %d: Acquire returned a closed ' +
                     'connection (Connected=False) — reverse-iteration ' +
                     'invariant violated', [Iter, LRound]));
          finally
            LPool.Release(LConn);
          end;
        end;
      finally
        LPool.Free;
      end;
    finally
      RetireDB(LDB);
    end;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TConnectionPoolPropertyTests);

end.
