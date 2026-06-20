{ ============================================================================
  Test.DeepBase.DB.Pool.PBT - Property-based tests for TUniConnectionPool
  initialization-time deadlock freedom.

  Properties covered (deepbase-round2-fixes):
    Property 14: For any valid SQLite pool configuration, racing
                 Initialize and Warmup from multiple threads completes
                 within a bounded budget (5 s). The fix split the
                 lock-holding inner work (DoWarmup) from the public
                 Initialize/Warmup entry points so the external
                 caller does not re-acquire FLock on a path that
                 already holds it.

  Each property runs >= 100 random iterations.

  Notes on observability:
    - We pick the SQLite :memory: connection string. Each FireDAC
      :memory: connection is per-connection isolated and cheap to
      open, which keeps total wall-clock low and avoids touching the
      filesystem.
    - We pick a small Min/MaxSize (1..3) so warmup work is small.
      The PBT is checking lock topology, not pool throughput.
    - A deadlock manifests as a thread parking on FLock forever; the
      Stopwatch budget catches that. A regression that simply slows
      down (without deadlocking) also surfaces because we also assert
      that the pool reports Initialized=True.
    - We avoid GetConnection here. Issuing live FireDAC traffic would
      pull in maintenance threads and external state that are
      unrelated to the property under test.
  ============================================================================ }

unit Test.DeepBase.DB.Pool.PBT;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Diagnostics,
  System.Threading,
  DUnitX.TestFramework,
  DeepBase.DB.Pool;

type
  [TestFixture]
  [Category('PBT')]
  TUniPoolPropertyTests = class
  public
    [Setup]
    procedure Setup;

    // Feature: deepbase-round2-fixes, Property 14
    [Test]
    procedure Property14_InitializeAndWarmupDoNotDeadlock;
  end;

implementation

{ TUniPoolPropertyTests }

procedure TUniPoolPropertyTests.Setup;
begin
  Randomize;
end;

procedure
TUniPoolPropertyTests
.Property14_InitializeAndWarmupDoNotDeadlock;
const
  CIters = 100;
  CTotalBudgetMs = 5000;
begin
  for var Iter := 1 to CIters do
  begin
    var LThreadCount: Integer := 3 + Random(8);  // 3..10 threads
    var LMinSize: Integer := 1 + Random(3);      // 1..3
    var LMaxSize: Integer := LMinSize + 1 + Random(3);  // >= MinSize+1

    var LPool := TUniConnectionPool.Create;
    try
      LPool.DatabaseType := dbSQLite;
      LPool.ConnectionString := ':memory:';
      LPool.MinSize := LMinSize;
      LPool.MaxSize := LMaxSize;
      LPool.AcquireTimeoutMs := 2000;

      var LSw := TStopwatch.StartNew;
      var LErrors: Integer := 0;
      var LErrorMsg := '';
      var LErrorMsgLock := TObject.Create;
      try
        // TParallel.For races LThreadCount workers. Each worker calls
        // Initialize (idempotent) and then Warmup with a small count.
        // The fix path requires the public methods to acquire FLock
        // without re-entering it via a callee, and to make Initialize
        // safe under contention.
        TParallel.For(0, LThreadCount - 1,
          procedure(AIndex: Integer)
          begin
            try
              LPool.Initialize;
              // Add a small Warmup as well so we exercise the public
              // Warmup path (the original bug: Warmup re-acquiring a
              // non-recursive lock through DoWarmup).
              LPool.Warmup(LMinSize);
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

        Assert.IsTrue(LSw.ElapsedMilliseconds < CTotalBudgetMs,
          Format('Iter %d: Initialize+Warmup race took %d ms with %d ' +
                 'threads (budget %d ms) — likely deadlock',
            [Iter, LSw.ElapsedMilliseconds, LThreadCount,
             CTotalBudgetMs]));

        Assert.AreEqual<Integer>(0,
          TInterlocked.CompareExchange(LErrors, 0, 0),
          Format('Iter %d: workers reported %d errors; first: %s',
            [Iter,
             TInterlocked.CompareExchange(LErrors, 0, 0),
             LErrorMsg]));

        Assert.IsTrue(LPool.Initialized,
          Format('Iter %d: pool not flagged Initialized after race',
            [Iter]));
      finally
        LErrorMsgLock.Free;
      end;
    finally
      LPool.Free;
    end;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TUniPoolPropertyTests);

end.
