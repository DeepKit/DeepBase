unit Test.Regression.BUG334_PoolShutdownInUse;

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
  TBUG334_PoolShutdownInUseTest = class(TRegressionTestBase)
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
    procedure Test_Shutdown_TimeoutPreservesInUseConnection;
  end;

implementation

procedure TBUG334_PoolShutdownInUseTest.SetUp;
begin
  inherited;
  FDbFile := TPath.Combine(TPath.GetTempPath, 'bug334_pool.db');
  if TFile.Exists(FDbFile) then
    TFile.Delete(FDbFile);

  FPool := TUniConnectionPool.Create;
  FPool.DatabaseType := dbSQLite;
  FPool.ConnectionString := FDbFile;
  var Cfg := TPoolConfig.Default;
  Cfg.MinSize := 1;
  Cfg.MaxSize := 2;
  Cfg.AcquireTimeoutMs := 1;
  FPool.Config := Cfg;
  FPool.Initialize;
end;

procedure TBUG334_PoolShutdownInUseTest.TearDown;
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

function TBUG334_PoolShutdownInUseTest.GetBugNumber: string;
begin
  Result := 'BUG-334';
end;

function TBUG334_PoolShutdownInUseTest.GetBugDescription: string;
begin
  Result := 'Pool Shutdown must not free csInUse connections (UAF)';
end;

function TBUG334_PoolShutdownInUseTest.GetFixDate: string;
begin
  Result := '2026-09-02';
end;

function TBUG334_PoolShutdownInUseTest.GetPriority: string;
begin
  Result := 'P0';
end;

function TBUG334_PoolShutdownInUseTest.GetAffectedFile: string;
begin
  Result := 'Persistence/DeepBase.DB.Pool.pas';
end;

procedure TBUG334_PoolShutdownInUseTest.Test_Shutdown_TimeoutPreservesInUseConnection;
var
  Conn: TPooledConnection;
  StatsBefore, StatsAfter: TPoolStatistics;
begin
  Conn := FPool.GetConnection;
  Assert.IsNotNull(Conn, 'Should acquire connection');
  Assert.AreEqual(csInUse, Conn.State);

  StatsBefore := FPool.GetStatistics;
  Assert.IsTrue(StatsBefore.TotalConnections >= 1);

  FPool.Shutdown;

  Assert.AreEqual(csInUse, Conn.State,
    'Borrowed connection object must survive Shutdown');
  StatsAfter := FPool.GetStatistics;
  Assert.AreEqual(1, StatsAfter.TotalConnections,
    'csInUse connection must remain in pool (intentional leak > UAF)');
end;

initialization
  TDUnitX.RegisterTestFixture(TBUG334_PoolShutdownInUseTest);

end.
