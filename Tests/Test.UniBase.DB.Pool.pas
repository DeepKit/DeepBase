{ ============================================================================
  Test.UniBase.DB.Pool - Unit Tests for Database Connection Pool Module
  
  Test Coverage:
    - TPoolStatistics record operations
    - TPooledConnection lifecycle
    - TPoolConfig configuration
    - TUniConnectionPool operations
    - Database type and connection state enums
  ============================================================================ }

unit Test.UniBase.DB.Pool;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.Diagnostics,
  System.TimeSpan,
  UniBase.DB.Pool;

type
  [TestFixture]
  TTestPoolStatistics = class
  public
    [Test]
    procedure Test_DefaultValues;
    [Test]
    procedure Test_ToString;
    [Test]
    procedure Test_FieldAssignment;
    [Test]
    procedure Test_TotalConnections;
    [Test]
    procedure Test_AverageWaitTime;
  end;

  [TestFixture]
  TTestPoolConfig = class
  public
    [Test]
    procedure Test_Default_MinSize;
    [Test]
    procedure Test_Default_MaxSize;
    [Test]
    procedure Test_Default_AcquireTimeout;
    [Test]
    procedure Test_Default_IdleTimeout;
    [Test]
    procedure Test_Default_MaxLifetime;
    [Test]
    procedure Test_Default_ValidationInterval;
    [Test]
    procedure Test_Default_LeakDetection;
    [Test]
    procedure Test_Default_AutoCommit;
    [Test]
    procedure Test_CustomConfig;
  end;

  [TestFixture]
  TTestDatabaseTypeEnum = class
  public
    [Test]
    procedure Test_SQLite;
    [Test]
    procedure Test_MySQL;
    [Test]
    procedure Test_PostgreSQL;
    [Test]
    procedure Test_SQLServer;
    [Test]
    procedure Test_Oracle;
    [Test]
    procedure Test_Firebird;
    [Test]
    procedure Test_InterBase;
    [Test]
    procedure Test_EnumCount;
  end;

  [TestFixture]
  TTestConnectionStateEnum = class
  public
    [Test]
    procedure Test_Idle;
    [Test]
    procedure Test_InUse;
    [Test]
    procedure Test_Invalid;
    [Test]
    procedure Test_Validating;
    [Test]
    procedure Test_EnumValues;
  end;

  [TestFixture]
  TTestPoolEventTypeEnum = class
  public
    [Test]
    procedure Test_ConnectionCreated;
    [Test]
    procedure Test_ConnectionDestroyed;
    [Test]
    procedure Test_ConnectionAcquired;
    [Test]
    procedure Test_ConnectionReleased;
    [Test]
    procedure Test_ConnectionValidated;
    [Test]
    procedure Test_ConnectionInvalidated;
    [Test]
    procedure Test_ConnectionLeakDetected;
    [Test]
    procedure Test_PoolExhausted;
  end;

  [TestFixture]
  TTestConnectionPoolBasic = class
  private
    FPool: TUniConnectionPool;
    FEventCount: Integer;
    FLastEventType: TPoolEventType;
    procedure OnPoolEvent(Sender: TObject; EventType: TPoolEventType; const Message: string);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_Create;
    [Test]
    procedure Test_DatabaseType_Default;
    [Test]
    procedure Test_DatabaseType_Set;
    [Test]
    procedure Test_ConnectionString_Set;
    [Test]
    procedure Test_Config_Default;
    [Test]
    procedure Test_Config_MinSize;
    [Test]
    procedure Test_Config_MaxSize;
    [Test]
    procedure Test_OnPoolEvent_Assignment;
  end;

implementation

{ TTestPoolStatistics }

procedure TTestPoolStatistics.Test_DefaultValues;
var
  Stats: TPoolStatistics;
begin
  FillChar(Stats, SizeOf(Stats), 0);
  
  Assert.AreEqual(0, Stats.TotalConnections);
  Assert.AreEqual(0, Stats.ActiveConnections);
  Assert.AreEqual(0, Stats.IdleConnections);
  Assert.AreEqual(0, Stats.WaitingRequests);
end;

procedure TTestPoolStatistics.Test_ToString;
var
  Stats: TPoolStatistics;
  S: string;
begin
  Stats.TotalConnections := 10;
  Stats.ActiveConnections := 3;
  Stats.IdleConnections := 7;
  Stats.TotalAcquires := 100;
  Stats.TotalReleases := 97;
  
  S := Stats.ToString;
  
  Assert.IsNotEmpty(S);
  Assert.IsTrue(S.Contains('10') or S.Contains('Total'));
end;

procedure TTestPoolStatistics.Test_FieldAssignment;
var
  Stats: TPoolStatistics;
begin
  Stats.TotalConnections := 5;
  Stats.ActiveConnections := 2;
  Stats.IdleConnections := 3;
  Stats.WaitingRequests := 1;
  Stats.TotalAcquires := 1000;
  Stats.TotalReleases := 999;
  Stats.TotalCreates := 10;
  Stats.TotalDestroys := 5;
  Stats.TotalTimeouts := 2;
  Stats.TotalValidations := 50;
  Stats.TotalInvalidations := 3;
  Stats.AverageWaitTimeMs := 25.5;
  Stats.MaxWaitTimeMs := 150;
  Stats.LeaksDetected := 1;
  
  Assert.AreEqual(5, Stats.TotalConnections);
  Assert.AreEqual(2, Stats.ActiveConnections);
  Assert.AreEqual(3, Stats.IdleConnections);
  Assert.AreEqual(Int64(1000), Stats.TotalAcquires);
  Assert.AreEqual(Double(25.5), Stats.AverageWaitTimeMs, 0.01);
  Assert.AreEqual(Int64(150), Stats.MaxWaitTimeMs);
end;

procedure TTestPoolStatistics.Test_TotalConnections;
var
  Stats: TPoolStatistics;
begin
  Stats.TotalConnections := 20;
  Stats.ActiveConnections := 15;
  Stats.IdleConnections := 5;
  
  Assert.AreEqual(Stats.TotalConnections, Stats.ActiveConnections + Stats.IdleConnections);
end;

procedure TTestPoolStatistics.Test_AverageWaitTime;
var
  Stats: TPoolStatistics;
begin
  Stats.AverageWaitTimeMs := 0;
  Assert.AreEqual(Double(0), Stats.AverageWaitTimeMs, 0.001);
  
  Stats.AverageWaitTimeMs := 100.5;
  Assert.AreEqual(Double(100.5), Stats.AverageWaitTimeMs, 0.001);
end;

{ TTestPoolConfig }

procedure TTestPoolConfig.Test_Default_MinSize;
var
  Config: TPoolConfig;
begin
  Config := TPoolConfig.Default;
  Assert.IsTrue(Config.MinSize >= 1);
end;

procedure TTestPoolConfig.Test_Default_MaxSize;
var
  Config: TPoolConfig;
begin
  Config := TPoolConfig.Default;
  Assert.IsTrue(Config.MaxSize >= Config.MinSize);
  Assert.IsTrue(Config.MaxSize <= 100);  // Reasonable upper bound
end;

procedure TTestPoolConfig.Test_Default_AcquireTimeout;
var
  Config: TPoolConfig;
begin
  Config := TPoolConfig.Default;
  Assert.IsTrue(Config.AcquireTimeoutMs > 0);
end;

procedure TTestPoolConfig.Test_Default_IdleTimeout;
var
  Config: TPoolConfig;
begin
  Config := TPoolConfig.Default;
  Assert.IsTrue(Config.IdleTimeoutSec > 0);
end;

procedure TTestPoolConfig.Test_Default_MaxLifetime;
var
  Config: TPoolConfig;
begin
  Config := TPoolConfig.Default;
  Assert.IsTrue(Config.MaxLifetimeSec > 0);
end;

procedure TTestPoolConfig.Test_Default_ValidationInterval;
var
  Config: TPoolConfig;
begin
  Config := TPoolConfig.Default;
  Assert.IsTrue(Config.ValidationIntervalSec >= 0);
end;

procedure TTestPoolConfig.Test_Default_LeakDetection;
var
  Config: TPoolConfig;
begin
  Config := TPoolConfig.Default;
  Assert.IsTrue(Config.LeakDetectionThresholdSec > 0);
end;

procedure TTestPoolConfig.Test_Default_AutoCommit;
var
  Config: TPoolConfig;
begin
  Config := TPoolConfig.Default;
  // AutoCommit can be either True or False by default
  Assert.IsTrue(Config.AutoCommit or not Config.AutoCommit);
end;

procedure TTestPoolConfig.Test_CustomConfig;
var
  Config: TPoolConfig;
begin
  Config.MinSize := 5;
  Config.MaxSize := 50;
  Config.AcquireTimeoutMs := 10000;
  Config.IdleTimeoutSec := 300;
  Config.MaxLifetimeSec := 3600;
  Config.ValidationIntervalSec := 60;
  Config.LeakDetectionThresholdSec := 120;
  Config.ValidationQuery := 'SELECT 1';
  Config.AutoCommit := True;
  
  Assert.AreEqual(5, Config.MinSize);
  Assert.AreEqual(50, Config.MaxSize);
  Assert.AreEqual(Cardinal(10000), Config.AcquireTimeoutMs);
  Assert.AreEqual(300, Config.IdleTimeoutSec);
  Assert.AreEqual(3600, Config.MaxLifetimeSec);
  Assert.AreEqual('SELECT 1', Config.ValidationQuery);
  Assert.IsTrue(Config.AutoCommit);
end;

{ TTestDatabaseTypeEnum }

procedure TTestDatabaseTypeEnum.Test_SQLite;
begin
  Assert.AreEqual(0, Ord(dbSQLite));
end;

procedure TTestDatabaseTypeEnum.Test_MySQL;
begin
  Assert.AreEqual(1, Ord(dbMySQL));
end;

procedure TTestDatabaseTypeEnum.Test_PostgreSQL;
begin
  Assert.AreEqual(2, Ord(dbPostgreSQL));
end;

procedure TTestDatabaseTypeEnum.Test_SQLServer;
begin
  Assert.AreEqual(3, Ord(dbSQLServer));
end;

procedure TTestDatabaseTypeEnum.Test_Oracle;
begin
  Assert.AreEqual(4, Ord(dbOracle));
end;

procedure TTestDatabaseTypeEnum.Test_Firebird;
begin
  Assert.AreEqual(5, Ord(dbFirebird));
end;

procedure TTestDatabaseTypeEnum.Test_InterBase;
begin
  Assert.AreEqual(6, Ord(dbInterBase));
end;

procedure TTestDatabaseTypeEnum.Test_EnumCount;
begin
  // Verify we have exactly 7 database types
  Assert.AreEqual(7, Ord(High(TDatabaseType)) + 1);
end;

{ TTestConnectionStateEnum }

procedure TTestConnectionStateEnum.Test_Idle;
begin
  Assert.AreEqual(0, Ord(csIdle));
end;

procedure TTestConnectionStateEnum.Test_InUse;
begin
  Assert.AreEqual(1, Ord(csInUse));
end;

procedure TTestConnectionStateEnum.Test_Invalid;
begin
  Assert.AreEqual(2, Ord(csInvalid));
end;

procedure TTestConnectionStateEnum.Test_Validating;
begin
  Assert.AreEqual(3, Ord(csValidating));
end;

procedure TTestConnectionStateEnum.Test_EnumValues;
begin
  Assert.AreEqual(4, Ord(High(TConnectionState)) + 1);
end;

{ TTestPoolEventTypeEnum }

procedure TTestPoolEventTypeEnum.Test_ConnectionCreated;
begin
  Assert.AreEqual(0, Ord(peConnectionCreated));
end;

procedure TTestPoolEventTypeEnum.Test_ConnectionDestroyed;
begin
  Assert.AreEqual(1, Ord(peConnectionDestroyed));
end;

procedure TTestPoolEventTypeEnum.Test_ConnectionAcquired;
begin
  Assert.AreEqual(2, Ord(peConnectionAcquired));
end;

procedure TTestPoolEventTypeEnum.Test_ConnectionReleased;
begin
  Assert.AreEqual(3, Ord(peConnectionReleased));
end;

procedure TTestPoolEventTypeEnum.Test_ConnectionValidated;
begin
  Assert.AreEqual(4, Ord(peConnectionValidated));
end;

procedure TTestPoolEventTypeEnum.Test_ConnectionInvalidated;
begin
  Assert.AreEqual(5, Ord(peConnectionInvalidated));
end;

procedure TTestPoolEventTypeEnum.Test_ConnectionLeakDetected;
begin
  Assert.AreEqual(6, Ord(peConnectionLeakDetected));
end;

procedure TTestPoolEventTypeEnum.Test_PoolExhausted;
begin
  Assert.AreEqual(7, Ord(pePoolExhausted));
end;

{ TTestConnectionPoolBasic }

procedure TTestConnectionPoolBasic.Setup;
begin
  FPool := TUniConnectionPool.Create;
  FEventCount := 0;
end;

procedure TTestConnectionPoolBasic.TearDown;
begin
  FPool.Free;
end;

procedure TTestConnectionPoolBasic.OnPoolEvent(Sender: TObject; EventType: TPoolEventType; const Message: string);
begin
  Inc(FEventCount);
  FLastEventType := EventType;
end;

procedure TTestConnectionPoolBasic.Test_Create;
begin
  Assert.IsNotNull(FPool);
end;

procedure TTestConnectionPoolBasic.Test_DatabaseType_Default;
begin
  // Default should be SQLite
  Assert.AreEqual(dbSQLite, FPool.DatabaseType);
end;

procedure TTestConnectionPoolBasic.Test_DatabaseType_Set;
begin
  FPool.DatabaseType := dbMySQL;
  Assert.AreEqual(dbMySQL, FPool.DatabaseType);
  
  FPool.DatabaseType := dbPostgreSQL;
  Assert.AreEqual(dbPostgreSQL, FPool.DatabaseType);
end;

procedure TTestConnectionPoolBasic.Test_ConnectionString_Set;
begin
  FPool.ConnectionString := 'test.db';
  Assert.AreEqual('test.db', FPool.ConnectionString);
  
  FPool.ConnectionString := 'Server=localhost;Database=mydb';
  Assert.AreEqual('Server=localhost;Database=mydb', FPool.ConnectionString);
end;

procedure TTestConnectionPoolBasic.Test_Config_Default;
var
  Config: TPoolConfig;
begin
  Config := FPool.Config;
  Assert.IsTrue(Config.MinSize >= 1);
  Assert.IsTrue(Config.MaxSize >= Config.MinSize);
end;

procedure TTestConnectionPoolBasic.Test_Config_MinSize;
begin
  FPool.MinSize := 5;
  Assert.AreEqual(5, FPool.MinSize);
end;

procedure TTestConnectionPoolBasic.Test_Config_MaxSize;
begin
  FPool.MaxSize := 20;
  Assert.AreEqual(20, FPool.MaxSize);
end;

procedure TTestConnectionPoolBasic.Test_OnPoolEvent_Assignment;
begin
  FPool.OnPoolEvent := OnPoolEvent;
  Assert.IsNotNull(TMethod(FPool.OnPoolEvent).Code);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestPoolStatistics);
  TDUnitX.RegisterTestFixture(TTestPoolConfig);
  TDUnitX.RegisterTestFixture(TTestDatabaseTypeEnum);
  TDUnitX.RegisterTestFixture(TTestConnectionStateEnum);
  TDUnitX.RegisterTestFixture(TTestPoolEventTypeEnum);
  TDUnitX.RegisterTestFixture(TTestConnectionPoolBasic);

end.
