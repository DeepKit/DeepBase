{ ============================================================================
  Test.DeepBase.DB.ConnectionPool - Connection Pool Tests
  
  Version: 1.0
  Description: Unit tests for TDBConnectionPool
  ============================================================================ }

unit Test.DeepBase.DB.ConnectionPool;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Threading,
  DUnitX.TestFramework,
  FireDAC.Comp.Client,
  DeepBase.DB.ConnectionPool;

type
  [TestFixture]
  TTestDBConnectionPool = class
  private
    FTempDBPath: string;
    FPool: TDBConnectionPool;
    
    procedure CreateTestDB;
    
  public
    [Setup]
    procedure Setup;
    
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_Create_Pool;
    
    [Test]
    procedure Test_Acquire_Returns_Connection;
    
    [Test]
    procedure Test_Release_Makes_Connection_Available;
    
    [Test]
    procedure Test_Multiple_Acquire_Release;
    
    [Test]
    procedure Test_Pool_Stats;
    
    [Test]
    procedure Test_Max_Pool_Size_Respected;
    
    [Test]
    procedure Test_AcquireTimeout_Returns_Nil_On_Timeout;
    
    [Test]
    procedure Test_Connection_Is_Valid_After_Acquire;
  end;

implementation

{ TTestDBConnectionPool }

procedure TTestDBConnectionPool.Setup;
begin
  FTempDBPath := TPath.Combine(TPath.GetTempPath, 
    'ConnectionPoolTest_' + TGUID.NewGuid.ToString + '.db');
  CreateTestDB;
end;

procedure TTestDBConnectionPool.TearDown;
begin
  if Assigned(FPool) then
    FreeAndNil(FPool);
    
  if TFile.Exists(FTempDBPath) then
    TFile.Delete(FTempDBPath);
end;

procedure TTestDBConnectionPool.CreateTestDB;
var
  Conn: TFDConnection;
begin
  // Create an empty SQLite database
  Conn := TFDConnection.Create(nil);
  try
    Conn.DriverName := 'SQLite';
    Conn.Params.Database := FTempDBPath;
    Conn.Params.Values['OpenMode'] := 'CreateUTF8';
    Conn.Open;
    Conn.Close;
  finally
    Conn.Free;
  end;
end;

procedure TTestDBConnectionPool.Test_Create_Pool;
begin
  FPool := TDBConnectionPool.Create(FTempDBPath, 3);
  
  Assert.IsNotNull(FPool, 'Pool should be created');
  Assert.AreEqual(3, FPool.MaxPoolSize, 'Max pool size should be 3');
  Assert.AreEqual(FTempDBPath, FPool.DBPath, 'DB path should match');
end;

procedure TTestDBConnectionPool.Test_Acquire_Returns_Connection;
var
  Conn: TFDConnection;
begin
  FPool := TDBConnectionPool.Create(FTempDBPath, 3);
  
  Conn := FPool.Acquire;
  try
    Assert.IsNotNull(Conn, 'Acquire should return a connection');
    Assert.IsTrue(Conn.Connected, 'Connection should be connected');
  finally
    FPool.Release(Conn);
  end;
end;

procedure TTestDBConnectionPool.Test_Release_Makes_Connection_Available;
var
  Conn1, Conn2: TFDConnection;
begin
  FPool := TDBConnectionPool.Create(FTempDBPath, 1);
  FPool.ConnectionTimeout := 2; // 2 seconds
  
  Conn1 := FPool.Acquire;
  
  // With pool size 1, second acquire should wait
  // Release first connection
  FPool.Release(Conn1);
  
  // Now acquire should succeed
  Conn2 := FPool.AcquireTimeout(1000);
  try
    Assert.IsNotNull(Conn2, 'Second acquire should succeed after release');
  finally
    FPool.Release(Conn2);
  end;
end;

procedure TTestDBConnectionPool.Test_Multiple_Acquire_Release;
var
  Conn1, Conn2, Conn3: TFDConnection;
begin
  FPool := TDBConnectionPool.Create(FTempDBPath, 5);
  
  Conn1 := FPool.Acquire;
  Conn2 := FPool.Acquire;
  Conn3 := FPool.Acquire;
  
  try
    Assert.AreEqual(3, FPool.GetActiveCount, 'Should have 3 active connections');
    Assert.AreEqual(3, FPool.GetTotalCount, 'Should have 3 total connections');
    
    FPool.Release(Conn2);
    Assert.AreEqual(2, FPool.GetActiveCount, 'Should have 2 active after release');
  finally
    FPool.Release(Conn1);
    FPool.Release(Conn3);
  end;
  
  Assert.AreEqual(0, FPool.GetActiveCount, 'Should have 0 active after all released');
end;

procedure TTestDBConnectionPool.Test_Pool_Stats;
begin
  FPool := TDBConnectionPool.Create(FTempDBPath, 5);
  
  Assert.IsNotEmpty(FPool.GetPoolStats, 'Pool stats should not be empty');
  Assert.Contains(FPool.GetPoolStats, 'Pool:', 'Stats should contain Pool:');
end;

procedure TTestDBConnectionPool.Test_Max_Pool_Size_Respected;
var
  Conn1, Conn2, Conn3: TFDConnection;
  Conn4: TFDConnection;
begin
  FPool := TDBConnectionPool.Create(FTempDBPath, 3);
  FPool.ConnectionTimeout := 1;
  
  Conn1 := FPool.Acquire;
  Conn2 := FPool.Acquire;
  Conn3 := FPool.Acquire;
  
  try
    Assert.AreEqual(3, FPool.GetTotalCount, 'Should have exactly 3 connections');
    
    // Try to acquire 4th - should timeout since pool is full
    Conn4 := FPool.AcquireTimeout(500);
    Assert.IsNull(Conn4, 'Fourth acquire should timeout when pool is full');
  finally
    FPool.Release(Conn1);
    FPool.Release(Conn2);
    FPool.Release(Conn3);
  end;
end;

procedure TTestDBConnectionPool.Test_AcquireTimeout_Returns_Nil_On_Timeout;
var
  Conn: TFDConnection;
begin
  FPool := TDBConnectionPool.Create(FTempDBPath, 1);
  
  Conn := FPool.Acquire;
  try
    // Pool is now full, try with short timeout
    Assert.IsNull(FPool.AcquireTimeout(100), 'Should return nil on timeout');
  finally
    FPool.Release(Conn);
  end;
end;

procedure TTestDBConnectionPool.Test_Connection_Is_Valid_After_Acquire;
var
  Conn: TFDConnection;
  Query: TFDQuery;
begin
  FPool := TDBConnectionPool.Create(FTempDBPath, 2);
  
  Conn := FPool.Acquire;
  try
    // Try to execute a query
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := Conn;
      Query.SQL.Text := 'SELECT 1 AS TestValue';
      Query.Open;
      
      Assert.AreEqual(1, Query.FieldByName('TestValue').AsInteger, 
        'Query should execute successfully');
    finally
      Query.Free;
    end;
  finally
    FPool.Release(Conn);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDBConnectionPool);

end.
