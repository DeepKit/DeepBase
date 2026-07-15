{ ============================================================================
  Test.Regression.BUG333_RecycleAllConnectionsUAF - REVIEW5-DATA-004

  Verifies that RecycleAllConnections does NOT free csValidating connections.
  Before the fix, csValidating was included in the delete set, which caused
  a use-after-free when the maintenance thread was still running Validate
  on those connections outside the pool lock.
  ============================================================================ }

unit Test.Regression.BUG333_RecycleAllConnectionsUAF;

interface

uses
  System.SysUtils,
  System.IOUtils,
  DUnitX.TestFramework,
  Test.Regression.Base,
  DeepBase.DB.Pool;

type
  [TestFixture]
  [Category('regression')]
  TBUG333_RecycleAllConnectionsUAFTest = class(TRegressionTestBase)
  private
    FPool: TUniConnectionPool;
    FDbFile: string;
  protected
    function GetBugNumber: string; override;
    function GetBugDescription: string; override;
    function GetFixDate: string; override;
    function GetPriority: string; override;
    function GetAffectedFile: string; override;
  public
    [Setup]
    procedure SetUp; override;
    [TearDown]
    procedure TearDown; override;

    /// <summary>csIdle connections are deleted by RecycleAllConnections</summary>
    [Test]
    procedure Test_RecycleAll_IdleConnectionsDeleted;

    /// <summary>csValidating connections are NOT deleted (prevents UAF)</summary>
    [Test]
    procedure Test_RecycleAll_ValidatingConnectionsPreserved;

    /// <summary>csInUse connections are NOT deleted</summary>
    [Test]
    procedure Test_RecycleAll_InUseConnectionsPreserved;
  end;

implementation

{ TBUG333_RecycleAllConnectionsUAFTest }

procedure TBUG333_RecycleAllConnectionsUAFTest.SetUp;
begin
  inherited;
  FDbFile := TPath.Combine(TPath.GetTempPath, 'bug333_test.db');
  if TFile.Exists(FDbFile) then
    TFile.Delete(FDbFile);

  FPool := TUniConnectionPool.Create;
  FPool.DatabaseType := dbSQLite;
  FPool.ConnectionString := FDbFile;  // For SQLite, ConnectionString is just the file path
  var Cfg := TPoolConfig.Default;
  Cfg.MinSize := 0;  // REVIEW5-DATA-004: MinSize=0 prevents Warmup replenishment
                      // so we can test RecycleAllConnections without auto-recreate
  Cfg.MaxSize := 4;
  Cfg.ValidationIntervalSec := 0;
  FPool.Config := Cfg;
  FPool.Initialize;

  // Manually create connections by acquiring them simultaneously.
  // GetConnection creates on demand when no idle connection is available.
  var C1 := FPool.GetConnection;
  var C2 := FPool.GetConnection;
  // Release both → pool now has 2 idle connections
  C1.Release;
  C2.Release;
end;

procedure TBUG333_RecycleAllConnectionsUAFTest.TearDown;
begin
  FPool.Shutdown;
  FPool.Free;
  if TFile.Exists(FDbFile) then
  try
    TFile.Delete(FDbFile);
  except
    // ignore cleanup errors
  end;
  inherited;
end;

function TBUG333_RecycleAllConnectionsUAFTest.GetBugNumber: string;
begin
  Result := 'BUG-333';
end;

function TBUG333_RecycleAllConnectionsUAFTest.GetBugDescription: string;
begin
  Result := 'RecycleAllConnections deleted csValidating connections causing use-after-free';
end;

function TBUG333_RecycleAllConnectionsUAFTest.GetFixDate: string;
begin
  Result := '2026-06-29';
end;

function TBUG333_RecycleAllConnectionsUAFTest.GetPriority: string;
begin
  Result := 'P1';
end;

function TBUG333_RecycleAllConnectionsUAFTest.GetAffectedFile: string;
begin
  Result := 'Persistence/DeepBase.DB.Pool.pas';
end;

procedure TBUG333_RecycleAllConnectionsUAFTest.Test_RecycleAll_IdleConnectionsDeleted;
var
  Stats: TPoolStatistics;
begin
  Stats := FPool.GetStatistics;
  Assert.AreEqual(2, Stats.TotalConnections, 'Pool should have 2 connections after setup');

  FPool.RecycleAllConnections;

  Assert.AreEqual(0, FPool.GetStatistics.TotalConnections,
    'All csIdle connections should be deleted by RecycleAllConnections (MinSize=0 → no warmup)');
end;

procedure TBUG333_RecycleAllConnectionsUAFTest.Test_RecycleAll_ValidatingConnectionsPreserved;
var
  Stats: TPoolStatistics;
  Conn1, Conn2: TPooledConnection;
begin
  Stats := FPool.GetStatistics;
  Assert.AreEqual(2, Stats.TotalConnections, 'Pool should have 2 connections after setup');

  // Acquire first connection and mark as csValidating (simulates maintenance thread).
  // NOTE: Do NOT call Release after SetStateForTest — Release resets state to csIdle.
  Conn1 := FPool.GetConnection;
  Assert.IsNotNull(Conn1, 'Should acquire connection');
  Conn1.SetStateForTest(csValidating);
  // Conn1 stays in csValidating (not released, simulating mid-validation)

  // Acquire second connection, leave as csIdle
  Conn2 := FPool.GetConnection;
  Assert.IsNotNull(Conn2, 'Should acquire second connection');
  Conn2.Release;  // This sets state back to csIdle

  // RecycleAllConnections should delete csIdle but preserve csValidating
  FPool.RecycleAllConnections;

  Stats := FPool.GetStatistics;
  Assert.AreEqual(1, Stats.TotalConnections,
    'csValidating connection should survive RecycleAllConnections (UAF fix)');
end;

procedure TBUG333_RecycleAllConnectionsUAFTest.Test_RecycleAll_InUseConnectionsPreserved;
var
  Stats: TPoolStatistics;
  Conn: TPooledConnection;
begin
  Stats := FPool.GetStatistics;
  Assert.AreEqual(2, Stats.TotalConnections, 'Pool should have 2 connections after setup');

  // Acquire a connection (sets it to csInUse) and do NOT release it
  Conn := FPool.GetConnection;
  Assert.IsNotNull(Conn, 'Should acquire connection');
  // Conn stays acquired (csInUse), not released

  // RecycleAllConnections should not delete csInUse connections
  FPool.RecycleAllConnections;

  Stats := FPool.GetStatistics;
  Assert.AreEqual(1, Stats.TotalConnections,
    'csInUse connection should survive RecycleAllConnections');

  // Release to clean up
  Conn.Release;
end;

end.
