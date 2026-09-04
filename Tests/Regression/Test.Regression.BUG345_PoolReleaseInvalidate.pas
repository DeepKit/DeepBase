unit Test.Regression.BUG345_PoolReleaseInvalidate;

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
  TBUG345_PoolReleaseInvalidateTest = class(TRegressionTestBase)
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

    [Test]
    procedure Test_InvalidateThenRelease_DoesNotReturnToIdle;
  end;

implementation

procedure TBUG345_PoolReleaseInvalidateTest.SetUp;
var
  Cfg: TPoolConfig;
begin
  inherited;
  FDbFile := TPath.Combine(TPath.GetTempPath, 'bug345_pool.db');
  if TFile.Exists(FDbFile) then
    TFile.Delete(FDbFile);

  FPool := TUniConnectionPool.Create;
  FPool.DatabaseType := dbSQLite;
  FPool.ConnectionString := FDbFile;
  Cfg := TPoolConfig.Default;
  Cfg.MinSize := 1;
  Cfg.MaxSize := 2;
  FPool.Config := Cfg;
  FPool.Initialize;
end;

procedure TBUG345_PoolReleaseInvalidateTest.TearDown;
begin
  try
    FPool.Shutdown;
  except
  end;
  FPool.Free;
  if TFile.Exists(FDbFile) then
    TFile.Delete(FDbFile);
  inherited;
end;

function TBUG345_PoolReleaseInvalidateTest.GetBugNumber: string;
begin
  Result := 'BUG-345';
end;

function TBUG345_PoolReleaseInvalidateTest.GetBugDescription: string;
begin
  Result := 'Pool Release after Invalidate must not return connection to idle';
end;

function TBUG345_PoolReleaseInvalidateTest.GetFixDate: string;
begin
  Result := '2026-09-03';
end;

function TBUG345_PoolReleaseInvalidateTest.GetPriority: string;
begin
  Result := 'P1';
end;

function TBUG345_PoolReleaseInvalidateTest.GetAffectedFile: string;
begin
  Result := 'Persistence/DeepBase.DB.Pool.pas';
end;

procedure TBUG345_PoolReleaseInvalidateTest.Test_InvalidateThenRelease_DoesNotReturnToIdle;
var
  Conn: TPooledConnection;
  StatsBefore, StatsAfter: TPoolStatistics;
  ReleasesBefore: Int64;
begin
  Conn := FPool.GetConnection;
  Assert.IsNotNull(Conn);
  Assert.AreEqual(csInUse, Conn.State);

  StatsBefore := FPool.GetStatistics;
  ReleasesBefore := StatsBefore.TotalReleases;

  Conn.Invalidate;
  Assert.AreEqual(csInvalid, Conn.State);

  Conn.Release;
  Assert.AreEqual(csInvalid, Conn.State,
    'Invalidate state must stick after Release');
  StatsAfter := FPool.GetStatistics;
  Assert.AreEqual(StatsBefore.IdleConnections, StatsAfter.IdleConnections,
    'Invalidated connection must not enter idle pool');

  Conn.Release;
  Assert.AreEqual(csInvalid, Conn.State,
    'Double Release must be a no-op without changing sticky invalid state');
  Assert.AreEqual(ReleasesBefore, FPool.GetStatistics.TotalReleases,
    'Duplicate Release must not bump TotalReleases');
end;

initialization
  TDUnitX.RegisterTestFixture(TBUG345_PoolReleaseInvalidateTest);

end.
