{ ============================================================================
  Test.DeepBase.DB.Upsert.PBT - Property-based tests for the Round-2
  UPSERT atomicity fix.

  Properties covered (deepbase-round2-fixes):
    Property 20: For any uniquely-keyed table and N concurrent
                 INSERT-OR-REPLACE operations targeting the same
                 primary key with different value payloads, after
                 all writes complete:
                   (a) exactly ONE row with that key exists, AND
                   (b) the surviving value equals one of the
                       payloads written by some concurrent worker
                       (no row corruption / no torn write).
                 The Round-2 fix replaced the unsafe
                 INSERT-then-UPDATE patterns in
                 License/Security/Manager/Factory storages with
                 SQLite's INSERT OR REPLACE, which the engine
                 implements as an atomic upsert at the row level.

  Each property runs >= 100 random iterations.

  Notes on observability and degradation:
    - The production fix lives in the FireDAC storage adapters.
      Drive a real SQLite database directly (file-backed, WAL
      mode) so concurrent connections from multiple threads share
      the same on-disk row state, faithfully reproducing what the
      production code does at runtime.
    - Each iteration uses a fresh temp database file so iterations
      do not interact. We open per-thread TFDConnection to mirror
      the multi-connection case the fix guards against (a single
      connection serialises writes inside FireDAC, which would
      mask the underlying engine-level guarantee).
    - We assert on the SQLite engine's UPSERT semantics, not on
      any specific FireDAC adapter. The production fix's invariant
      is the SQL pattern itself.
  ============================================================================ }

unit Test.DeepBase.DB.Upsert.PBT;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.SyncObjs,
  System.Threading,
  System.Generics.Collections,
  DUnitX.TestFramework,
  FireDAC.Comp.Client,
  FireDAC.Stan.Param,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef;

type
  [TestFixture]
  TUpsertPropertyTests = class
  strict private
    function MakeTempDB: string;
    procedure RetireDB(const APath: string);
    procedure InitSchema(const ADB: string);
    function NewConnection(const ADB: string): TFDConnection;
  public
    [Setup]
    procedure Setup;

    // Feature: deepbase-round2-fixes, Property 20
    [Test]
    procedure Property20_ConcurrentUpsertProducesExactlyOneRow;
  end;

implementation

{ TUpsertPropertyTests }

procedure TUpsertPropertyTests.Setup;
begin
  Randomize;
end;

function TUpsertPropertyTests.MakeTempDB: string;
begin
  Result := TPath.Combine(TPath.GetTempPath,
    'DeepBaseUpsertPBT_' + TGUID.NewGuid.ToString + '.db');
end;

procedure TUpsertPropertyTests.RetireDB(const APath: string);
begin
  try
    if TFile.Exists(APath) then
      TFile.Delete(APath);
    // SQLite WAL/SHM siblings.
    if TFile.Exists(APath + '-wal') then
      TFile.Delete(APath + '-wal');
    if TFile.Exists(APath + '-shm') then
      TFile.Delete(APath + '-shm');
  except
    // Background SQLite handles may briefly hold these. Not test-fatal.
  end;
end;

function TUpsertPropertyTests.NewConnection(const ADB: string): TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  try
    Result.DriverName := 'SQLite';
    Result.Params.Database := ADB;
    Result.Params.Values['OpenMode'] := 'CreateUTF8';
    Result.Params.Values['LockingMode'] := 'Normal';
    Result.Params.Values['Synchronous'] := 'Normal';
    Result.Params.Values['JournalMode'] := 'WAL';
    Result.Params.Values['BusyTimeout'] := '5000';
    Result.Open;
  except
    Result.Free;
    raise;
  end;
end;

procedure TUpsertPropertyTests.InitSchema(const ADB: string);
var
  LConn: TFDConnection;
begin
  LConn := NewConnection(ADB);
  try
    LConn.ExecSQL(
      'CREATE TABLE IF NOT EXISTS upsert_t (' +
      '  k TEXT PRIMARY KEY, ' +
      '  v TEXT NOT NULL, ' +
      '  writer INTEGER NOT NULL)');
  finally
    LConn.Free;
  end;
end;

procedure
TUpsertPropertyTests
.Property20_ConcurrentUpsertProducesExactlyOneRow;
const
  CIters = 100;
begin
  for var Iter := 1 to CIters do
  begin
    var LWorkers: Integer := 4 + Random(8);  // 4..11 workers
    var LDB := MakeTempDB;
    try
      InitSchema(LDB);

      var LKey := 'shared-key-' + IntToStr(Iter);
      var LExpectedValues: TArray<string>;
      SetLength(LExpectedValues, LWorkers);
      for var I := 0 to LWorkers - 1 do
        LExpectedValues[I] := Format('v-%d-%d-%d',
          [Iter, I, Random(MaxInt)]);

      var LErrors: Integer := 0;
      var LErrorMsgLock := TObject.Create;
      var LErrorMsg: string := '';
      try
        // Race LWorkers writers, each owning its own TFDConnection
        // to the same on-disk database. The fix's invariant: after
        // all of these "INSERT OR REPLACE" calls complete, the
        // table holds exactly one row with key = LKey.
        TParallel.For(0, LWorkers - 1,
          procedure(AIndex: Integer)
          var
            LConn: TFDConnection;
          begin
            try
              LConn := NewConnection(LDB);
              try
                // INSERT OR REPLACE is the production fix pattern:
                // a single statement that either inserts or
                // replaces the existing row atomically. Without
                // this the previous SELECT-then-INSERT/UPDATE
                // pattern lost rows under contention.
                LConn.ExecSQL(
                  'INSERT OR REPLACE INTO upsert_t(k, v, writer) ' +
                  'VALUES(:k, :v, :w)',
                  [LKey, LExpectedValues[AIndex], AIndex]);
              finally
                LConn.Free;
              end;
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

        Assert.AreEqual<Integer>(0,
          TInterlocked.CompareExchange(LErrors, 0, 0),
          Format('Iter %d: %d worker(s) failed; first: %s',
            [Iter, TInterlocked.CompareExchange(LErrors, 0, 0),
             LErrorMsg]));

        // Verify the property end-to-end on a fresh connection.
        var LVerify := NewConnection(LDB);
        try
          var LQuery := TFDQuery.Create(nil);
          try
            LQuery.Connection := LVerify;

            // Property 20 (a): exactly ONE row.
            LQuery.SQL.Text :=
              'SELECT COUNT(*) AS n FROM upsert_t WHERE k = :k';
            LQuery.ParamByName('k').AsString := LKey;
            LQuery.Open;
            try
              Assert.AreEqual<Integer>(1,
                LQuery.FieldByName('n').AsInteger,
                Format('Iter %d: expected exactly 1 row for key %s, got %d',
                  [Iter, LKey, LQuery.FieldByName('n').AsInteger]));
            finally
              LQuery.Close;
            end;

            // Property 20 (b): surviving value matches some
            // worker's intended payload (no torn write).
            LQuery.SQL.Text :=
              'SELECT v, writer FROM upsert_t WHERE k = :k';
            LQuery.ParamByName('k').AsString := LKey;
            LQuery.Open;
            try
              Assert.IsFalse(LQuery.Eof,
                Format('Iter %d: row missing after upsert race', [Iter]));
              var LSurvivingV := LQuery.FieldByName('v').AsString;
              var LSurvivingW := LQuery.FieldByName('writer').AsInteger;

              Assert.IsTrue((LSurvivingW >= 0) and
                            (LSurvivingW < LWorkers),
                Format('Iter %d: writer index %d out of range [0..%d)',
                  [Iter, LSurvivingW, LWorkers]));
              Assert.AreEqual(LExpectedValues[LSurvivingW], LSurvivingV,
                Format('Iter %d: surviving (writer=%d) value %s does ' +
                       'not match worker''s payload %s — torn write',
                  [Iter, LSurvivingW, LSurvivingV,
                   LExpectedValues[LSurvivingW]]));
            finally
              LQuery.Close;
            end;
          finally
            LQuery.Free;
          end;
        finally
          LVerify.Free;
        end;
      finally
        LErrorMsgLock.Free;
      end;
    finally
      RetireDB(LDB);
    end;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TUpsertPropertyTests);

end.
