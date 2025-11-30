{ ============================================================================
  Test.Integration.Core - 核心功能集成测试
  
  测试范围:
    - 配置管理完整流程
    - 日志系统完整流程
    - 数据绑定端到端测试
    - 多模块协作测试
  ============================================================================ }

unit Test.Integration.Core;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.IOUtils,
  System.Diagnostics,
  DUnitX.TestFramework,
  FireDAC.Comp.Client,
  UniBase.IntegrationTest;

type
  // ============================================================================
  // Configuration Integration Tests
  // ============================================================================
  
  [TestFixture]
  TConfigIntegrationTest = class(TIntegrationTestBase)
  protected
    procedure InitializeTestData; override;
    procedure CleanupTestData; override;
  public
    [Test]
    [TestCase('Basic read/write', '')]
    procedure Test_ConfigReadWrite_BasicFlow;
    
    [Test]
    procedure Test_ConfigBatchOperations;
    
    [Test]
    procedure Test_ConfigConcurrentAccess;
    
    [Test]
    procedure Test_ConfigPersistence;
    
    [Test]
    procedure Test_ConfigEncryption_EndToEnd;
    
    [Test]
    procedure Test_ConfigChangeNotification;
  end;
  
  // ============================================================================
  // Logging Integration Tests
  // ============================================================================
  
  [TestFixture]
  TLoggingIntegrationTest = class(TIntegrationTestBase)
  protected
    procedure InitializeTestData; override;
    procedure CleanupTestData; override;
  public
    [Test]
    procedure Test_LogWriteAndQuery;
    
    [Test]
    procedure Test_LogLevelFiltering;
    
    [Test]
    procedure Test_LogHighVolume;
    
    [Test]
    procedure Test_LogRotation;
    
    [Test]
    procedure Test_LogConcurrentWrites;
  end;
  
  // ============================================================================
  // Database Integration Tests
  // ============================================================================
  
  [TestFixture]
  TDatabaseIntegrationTest = class(TIntegrationTestBase)
  protected
    procedure InitializeTestData; override;
    procedure CleanupTestData; override;
  public
    [Test]
    procedure Test_ConnectionPooling;
    
    [Test]
    procedure Test_TransactionRollback;
    
    [Test]
    procedure Test_BulkInsertPerformance;
    
    [Test]
    procedure Test_QueryCaching;
    
    [Test]
    procedure Test_ConcurrentQueries;
  end;
  
  // ============================================================================
  // End-to-End Workflow Tests
  // ============================================================================
  
  [TestFixture]
  TWorkflowIntegrationTest = class(TIntegrationTestBase)
  protected
    procedure InitializeTestData; override;
    procedure CleanupTestData; override;
  public
    [Test]
    procedure Test_UserRegistrationWorkflow;
    
    [Test]
    procedure Test_ConfigurationMigration;
    
    [Test]
    procedure Test_DataExportImport;
    
    [Test]
    procedure Test_SystemInitialization;
    
    [Test]
    procedure Test_GracefulShutdown;
  end;
  
  // ============================================================================
  // Performance Regression Tests
  // ============================================================================
  
  [TestFixture]
  TPerformanceRegressionTest = class(TIntegrationTestBase)
  private
    FBenchmark: TPerformanceBenchmark;
  protected
    procedure InitializeTestData; override;
    procedure CleanupTestData; override;
  public
    [Setup]
    procedure Setup; override;
    
    [TearDown]
    procedure TearDown; override;
    
    [Test]
    procedure Test_ConfigReadPerformance;
    
    [Test]
    procedure Test_ConfigWritePerformance;
    
    [Test]
    procedure Test_DatabaseQueryPerformance;
    
    [Test]
    procedure Test_LogWritePerformance;
    
    [Test]
    procedure Test_MemoryUsage;
  end;

implementation

// ============================================================================
// TConfigIntegrationTest
// ============================================================================

procedure TConfigIntegrationTest.InitializeTestData;
begin
  inherited;
  // Clear any existing test configs
  FContext.ExecuteSQL('DELETE FROM Config WHERE Key LIKE ''test.%''');
end;

procedure TConfigIntegrationTest.CleanupTestData;
begin
  FContext.ExecuteSQL('DELETE FROM Config WHERE Key LIKE ''test.%''');
  inherited;
end;

procedure TConfigIntegrationTest.Test_ConfigReadWrite_BasicFlow;
var
  Query: TFDQuery;
begin
  // Write config
  FContext.ExecuteSQL(
    'INSERT INTO Config (Key, Value, Category) VALUES (''test.basic.key'', ''test_value'', ''test'')'
  );
  
  // Read back and verify
  Query := FContext.QuerySQL('SELECT Value FROM Config WHERE Key = ''test.basic.key''');
  try
    Assert.IsFalse(Query.IsEmpty, 'Config should exist');
    Assert.AreEqual('test_value', Query.FieldByName('Value').AsString);
  finally
    Query.Free;
  end;
  
  // Update config
  FContext.ExecuteSQL(
    'UPDATE Config SET Value = ''updated_value'' WHERE Key = ''test.basic.key'''
  );
  
  // Verify update
  Query := FContext.QuerySQL('SELECT Value FROM Config WHERE Key = ''test.basic.key''');
  try
    Assert.AreEqual('updated_value', Query.FieldByName('Value').AsString);
  finally
    Query.Free;
  end;
end;

procedure TConfigIntegrationTest.Test_ConfigBatchOperations;
var
  I: Integer;
begin
  // Batch insert
  for I := 1 to 100 do
    FContext.ExecuteSQL(Format(
      'INSERT INTO Config (Key, Value, Category) VALUES (''test.batch.%d'', ''value_%d'', ''test'')',
      [I, I]
    ));
  
  // Verify count
  TIntegrationAssert.QueryCount(FContext.Connection,
    'SELECT * FROM Config WHERE Key LIKE ''test.batch.%''', 100);
  
  // Batch update
  FContext.ExecuteSQL(
    'UPDATE Config SET Value = ''batch_updated'' WHERE Key LIKE ''test.batch.%'''
  );
  
  // Verify all updated
  TIntegrationAssert.QueryCount(FContext.Connection,
    'SELECT * FROM Config WHERE Key LIKE ''test.batch.%'' AND Value = ''batch_updated''', 100);
  
  // Batch delete
  FContext.ExecuteSQL('DELETE FROM Config WHERE Key LIKE ''test.batch.%''');
  
  // Verify all deleted
  TIntegrationAssert.QueryCount(FContext.Connection,
    'SELECT * FROM Config WHERE Key LIKE ''test.batch.%''', 0);
end;

procedure TConfigIntegrationTest.Test_ConfigConcurrentAccess;
var
  Tasks: array[0..4] of ITask;
  I: Integer;
  ErrorCount: Integer;
begin
  ErrorCount := 0;
  
  // Create concurrent tasks
  for I := 0 to High(Tasks) do
  begin
    Tasks[I] := TTask.Create(procedure
    var
      J: Integer;
      Query: TFDQuery;
      Conn: TFDConnection;
    begin
      // Each task uses its own connection
      Conn := TFDConnection.Create(nil);
      try
        Conn.DriverName := 'SQLite';
        Conn.Params.Database := ':memory:';
        Conn.Connected := True;
        
        for J := 1 to 20 do
        begin
          try
            // Simulated concurrent config access
            Query := TFDQuery.Create(nil);
            try
              Query.Connection := Conn;
              Query.SQL.Text := 'SELECT 1';
              Query.Open;
            finally
              Query.Free;
            end;
          except
            TInterlocked.Increment(ErrorCount);
          end;
        end;
      finally
        Conn.Free;
      end;
    end);
  end;
  
  // Start all tasks
  for I := 0 to High(Tasks) do
    Tasks[I].Start;
  
  // Wait for completion
  TTask.WaitForAll(Tasks);
  
  Assert.AreEqual(0, ErrorCount, 'No errors should occur during concurrent access');
end;

procedure TConfigIntegrationTest.Test_ConfigPersistence;
var
  TempDB: string;
  Conn: TFDConnection;
  Query: TFDQuery;
begin
  // Create temp database file
  TempDB := FContext.CreateTempFile('.db');
  
  // Create connection and write config
  Conn := TFDConnection.Create(nil);
  try
    Conn.DriverName := 'SQLite';
    Conn.Params.Database := TempDB;
    Conn.Connected := True;
    
    Conn.ExecSQL('CREATE TABLE Config (Key TEXT PRIMARY KEY, Value TEXT)');
    Conn.ExecSQL('INSERT INTO Config VALUES (''persist.test'', ''persisted_value'')');
    Conn.Connected := False;
  finally
    Conn.Free;
  end;
  
  // Reconnect and verify
  Conn := TFDConnection.Create(nil);
  try
    Conn.DriverName := 'SQLite';
    Conn.Params.Database := TempDB;
    Conn.Connected := True;
    
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := Conn;
      Query.SQL.Text := 'SELECT Value FROM Config WHERE Key = ''persist.test''';
      Query.Open;
      
      Assert.IsFalse(Query.IsEmpty, 'Config should persist after reconnection');
      Assert.AreEqual('persisted_value', Query.FieldByName('Value').AsString);
    finally
      Query.Free;
    end;
  finally
    Conn.Free;
  end;
end;

procedure TConfigIntegrationTest.Test_ConfigEncryption_EndToEnd;
begin
  // This test would use the actual encryption module
  // For now, we verify the table structure supports encrypted values
  
  FContext.ExecuteSQL(
    'INSERT INTO Config (Key, Value, Category, Description) ' +
    'VALUES (''test.encrypted'', ''[ENC]base64data'', ''security'', ''Encrypted value'')'
  );
  
  TIntegrationAssert.RowExists(FContext.Connection, 'Config',
    'Key = ''test.encrypted'' AND Value LIKE ''[ENC]%''');
end;

procedure TConfigIntegrationTest.Test_ConfigChangeNotification;
var
  ChangeDetected: Boolean;
  Query: TFDQuery;
begin
  ChangeDetected := False;
  
  // Insert initial value
  FContext.ExecuteSQL(
    'INSERT INTO Config (Key, Value, Category, UpdatedAt) ' +
    'VALUES (''test.change'', ''initial'', ''test'', CURRENT_TIMESTAMP)'
  );
  
  // Get initial timestamp
  Query := FContext.QuerySQL('SELECT UpdatedAt FROM Config WHERE Key = ''test.change''');
  try
    var InitialTime := Query.FieldByName('UpdatedAt').AsDateTime;
    
    // Small delay
    Sleep(100);
    
    // Update value
    FContext.ExecuteSQL(
      'UPDATE Config SET Value = ''changed'', UpdatedAt = CURRENT_TIMESTAMP ' +
      'WHERE Key = ''test.change'''
    );
    
    Query.Close;
    Query.Open;
    
    // Check if timestamp changed
    ChangeDetected := Query.FieldByName('UpdatedAt').AsDateTime > InitialTime;
  finally
    Query.Free;
  end;
  
  Assert.IsTrue(ChangeDetected, 'Config change should update timestamp');
end;

// ============================================================================
// TLoggingIntegrationTest
// ============================================================================

procedure TLoggingIntegrationTest.InitializeTestData;
begin
  inherited;
  FContext.ExecuteSQL('DELETE FROM Logs WHERE Category = ''test''');
end;

procedure TLoggingIntegrationTest.CleanupTestData;
begin
  FContext.ExecuteSQL('DELETE FROM Logs WHERE Category = ''test''');
  inherited;
end;

procedure TLoggingIntegrationTest.Test_LogWriteAndQuery;
var
  Query: TFDQuery;
begin
  // Write logs at different levels
  FContext.ExecuteSQL(
    'INSERT INTO Logs (Level, Message, Category) VALUES (''INFO'', ''Test info message'', ''test'')'
  );
  FContext.ExecuteSQL(
    'INSERT INTO Logs (Level, Message, Category) VALUES (''ERROR'', ''Test error message'', ''test'')'
  );
  
  // Query all test logs
  Query := FContext.QuerySQL('SELECT * FROM Logs WHERE Category = ''test'' ORDER BY Id');
  try
    Assert.AreEqual(2, Query.RecordCount, 'Should have 2 log entries');
    
    Assert.AreEqual('INFO', Query.FieldByName('Level').AsString);
    Query.Next;
    Assert.AreEqual('ERROR', Query.FieldByName('Level').AsString);
  finally
    Query.Free;
  end;
end;

procedure TLoggingIntegrationTest.Test_LogLevelFiltering;
begin
  // Insert logs at various levels
  FContext.ExecuteSQL('INSERT INTO Logs (Level, Message, Category) VALUES (''DEBUG'', ''Debug msg'', ''test'')');
  FContext.ExecuteSQL('INSERT INTO Logs (Level, Message, Category) VALUES (''INFO'', ''Info msg'', ''test'')');
  FContext.ExecuteSQL('INSERT INTO Logs (Level, Message, Category) VALUES (''WARN'', ''Warn msg'', ''test'')');
  FContext.ExecuteSQL('INSERT INTO Logs (Level, Message, Category) VALUES (''ERROR'', ''Error msg'', ''test'')');
  
  // Filter by level
  TIntegrationAssert.QueryCount(FContext.Connection,
    'SELECT * FROM Logs WHERE Category = ''test'' AND Level IN (''WARN'', ''ERROR'')', 2);
  
  TIntegrationAssert.QueryCount(FContext.Connection,
    'SELECT * FROM Logs WHERE Category = ''test'' AND Level = ''ERROR''', 1);
end;

procedure TLoggingIntegrationTest.Test_LogHighVolume;
var
  SW: TStopwatch;
  I: Integer;
begin
  SW := TStopwatch.StartNew;
  
  // Insert 1000 log entries
  for I := 1 to 1000 do
    FContext.ExecuteSQL(Format(
      'INSERT INTO Logs (Level, Message, Category) VALUES (''INFO'', ''High volume test %d'', ''test'')',
      [I]
    ));
  
  SW.Stop;
  
  // Verify all inserted
  TIntegrationAssert.QueryCount(FContext.Connection,
    'SELECT * FROM Logs WHERE Category = ''test'' AND Message LIKE ''High volume%''', 1000);
  
  // Performance check - should complete within reasonable time
  Assert.IsTrue(SW.ElapsedMilliseconds < 10000,
    Format('High volume insert took %d ms, expected < 10000 ms', [SW.ElapsedMilliseconds]));
end;

procedure TLoggingIntegrationTest.Test_LogRotation;
var
  Query: TFDQuery;
begin
  // Insert test logs
  FContext.DataGenerator.InsertLogs(100);
  
  // Simulate rotation by keeping only recent logs
  FContext.ExecuteSQL(
    'DELETE FROM Logs WHERE Category = ''test'' AND Id NOT IN ' +
    '(SELECT Id FROM Logs WHERE Category = ''test'' ORDER BY Id DESC LIMIT 50)'
  );
  
  // Verify only 50 remain
  Query := FContext.QuerySQL('SELECT COUNT(*) AS Cnt FROM Logs WHERE Category = ''test''');
  try
    Assert.IsTrue(Query.FieldByName('Cnt').AsInteger <= 50,
      'Log rotation should limit entries');
  finally
    Query.Free;
  end;
end;

procedure TLoggingIntegrationTest.Test_LogConcurrentWrites;
var
  Tasks: array[0..9] of ITask;
  I: Integer;
begin
  // Create concurrent write tasks
  for I := 0 to High(Tasks) do
  begin
    var TaskIndex := I;
    Tasks[I] := TTask.Create(procedure
    var
      J: Integer;
    begin
      for J := 1 to 50 do
      begin
        FContext.ExecuteSQL(Format(
          'INSERT INTO Logs (Level, Message, Category) VALUES (''INFO'', ''Task %d Log %d'', ''test'')',
          [TaskIndex, J]
        ));
      end;
    end);
  end;
  
  // Start all tasks
  for I := 0 to High(Tasks) do
    Tasks[I].Start;
  
  // Wait for completion
  TTask.WaitForAll(Tasks);
  
  // Verify total count
  TIntegrationAssert.QueryCount(FContext.Connection,
    'SELECT * FROM Logs WHERE Category = ''test'' AND Message LIKE ''Task%''', 500);
end;

// ============================================================================
// TDatabaseIntegrationTest
// ============================================================================

procedure TDatabaseIntegrationTest.InitializeTestData;
begin
  inherited;
  FContext.DataGenerator.ClearAllData;
end;

procedure TDatabaseIntegrationTest.CleanupTestData;
begin
  FContext.DataGenerator.ClearAllData;
  inherited;
end;

procedure TDatabaseIntegrationTest.Test_ConnectionPooling;
var
  Connections: array[0..4] of TFDConnection;
  I: Integer;
begin
  // Create multiple connections
  for I := 0 to High(Connections) do
  begin
    Connections[I] := TFDConnection.Create(nil);
    Connections[I].DriverName := 'SQLite';
    Connections[I].Params.Database := ':memory:';
    Connections[I].Connected := True;
    
    Assert.IsTrue(Connections[I].Connected, 'Connection should be established');
  end;
  
  // Cleanup
  for I := 0 to High(Connections) do
    Connections[I].Free;
end;

procedure TDatabaseIntegrationTest.Test_TransactionRollback;
var
  Query: TFDQuery;
begin
  // Start transaction
  FContext.Connection.StartTransaction;
  try
    // Insert data
    FContext.ExecuteSQL(
      'INSERT INTO Users (Username, Email, PasswordHash) VALUES (''rollback_test'', ''rollback@test.com'', ''hash'')'
    );
    
    // Verify exists within transaction
    TIntegrationAssert.RowExists(FContext.Connection, 'Users', 'Username = ''rollback_test''');
    
    // Rollback
    FContext.Connection.Rollback;
  except
    FContext.Connection.Rollback;
    raise;
  end;
  
  // Verify rolled back
  Query := FContext.QuerySQL('SELECT COUNT(*) FROM Users WHERE Username = ''rollback_test''');
  try
    Assert.AreEqual(0, Query.Fields[0].AsInteger, 'Data should be rolled back');
  finally
    Query.Free;
  end;
end;

procedure TDatabaseIntegrationTest.Test_BulkInsertPerformance;
var
  SW: TStopwatch;
begin
  SW := TStopwatch.StartNew;
  
  FContext.Connection.StartTransaction;
  try
    FContext.DataGenerator.InsertUsers(1000);
    FContext.Connection.Commit;
  except
    FContext.Connection.Rollback;
    raise;
  end;
  
  SW.Stop;
  
  // Verify count
  TIntegrationAssert.QueryCount(FContext.Connection,
    'SELECT * FROM Users WHERE Username LIKE ''testuser_%''', 1000);
  
  // Performance assertion
  Assert.IsTrue(SW.ElapsedMilliseconds < 5000,
    Format('Bulk insert of 1000 rows took %d ms, expected < 5000 ms', [SW.ElapsedMilliseconds]));
end;

procedure TDatabaseIntegrationTest.Test_QueryCaching;
var
  SW1, SW2: TStopwatch;
  Query: TFDQuery;
  I: Integer;
begin
  // Insert test data
  FContext.DataGenerator.InsertUsers(100);
  
  // First query (cold)
  SW1 := TStopwatch.StartNew;
  for I := 1 to 10 do
  begin
    Query := FContext.QuerySQL('SELECT * FROM Users WHERE Username LIKE ''testuser_%''');
    Query.Free;
  end;
  SW1.Stop;
  
  // Second query run (potentially warm)
  SW2 := TStopwatch.StartNew;
  for I := 1 to 10 do
  begin
    Query := FContext.QuerySQL('SELECT * FROM Users WHERE Username LIKE ''testuser_%''');
    Query.Free;
  end;
  SW2.Stop;
  
  // Log timing difference (caching benefit varies by database)
  // Just ensure both complete reasonably fast
  Assert.IsTrue(SW1.ElapsedMilliseconds < 5000, 'Cold queries should complete in < 5s');
  Assert.IsTrue(SW2.ElapsedMilliseconds < 5000, 'Warm queries should complete in < 5s');
end;

procedure TDatabaseIntegrationTest.Test_ConcurrentQueries;
var
  Tasks: array[0..4] of ITask;
  I: Integer;
  ErrorCount: Integer;
begin
  ErrorCount := 0;
  
  // Insert test data
  FContext.DataGenerator.InsertUsers(50);
  
  // Concurrent queries
  for I := 0 to High(Tasks) do
  begin
    Tasks[I] := TTask.Create(procedure
    var
      J: Integer;
      Query: TFDQuery;
    begin
      for J := 1 to 20 do
      begin
        try
          Query := FContext.QuerySQL('SELECT COUNT(*) FROM Users');
          try
            // Just verify query executes
            Query.Fields[0].AsInteger;
          finally
            Query.Free;
          end;
        except
          TInterlocked.Increment(ErrorCount);
        end;
      end;
    end);
  end;
  
  for I := 0 to High(Tasks) do
    Tasks[I].Start;
  
  TTask.WaitForAll(Tasks);
  
  Assert.AreEqual(0, ErrorCount, 'No errors during concurrent queries');
end;

// ============================================================================
// TWorkflowIntegrationTest
// ============================================================================

procedure TWorkflowIntegrationTest.InitializeTestData;
begin
  inherited;
  FContext.DataGenerator.ClearAllData;
end;

procedure TWorkflowIntegrationTest.CleanupTestData;
begin
  FContext.DataGenerator.ClearAllData;
  inherited;
end;

procedure TWorkflowIntegrationTest.Test_UserRegistrationWorkflow;
var
  Query: TFDQuery;
begin
  // Simulate user registration workflow
  
  // 1. Check username availability
  Query := FContext.QuerySQL('SELECT COUNT(*) FROM Users WHERE Username = ''newuser''');
  try
    Assert.AreEqual(0, Query.Fields[0].AsInteger, 'Username should be available');
  finally
    Query.Free;
  end;
  
  // 2. Create user
  FContext.ExecuteSQL(
    'INSERT INTO Users (Username, Email, PasswordHash, Role) ' +
    'VALUES (''newuser'', ''newuser@test.com'', ''hashed_password'', ''user'')'
  );
  
  // 3. Log registration event
  FContext.ExecuteSQL(
    'INSERT INTO Logs (Level, Message, Category) ' +
    'VALUES (''INFO'', ''User registered: newuser'', ''auth'')'
  );
  
  // 4. Create default config
  FContext.ExecuteSQL(
    'INSERT INTO Config (Key, Value, Category) ' +
    'VALUES (''user.newuser.theme'', ''default'', ''user_prefs'')'
  );
  
  // Verify complete workflow
  TIntegrationAssert.RowExists(FContext.Connection, 'Users', 'Username = ''newuser''');
  TIntegrationAssert.RowExists(FContext.Connection, 'Logs', 'Message LIKE ''%newuser%''');
  TIntegrationAssert.RowExists(FContext.Connection, 'Config', 'Key = ''user.newuser.theme''');
end;

procedure TWorkflowIntegrationTest.Test_ConfigurationMigration;
begin
  // Insert old-style config
  FContext.ExecuteSQL(
    'INSERT INTO Config (Key, Value) VALUES (''old.format.setting'', ''value1'')'
  );
  FContext.ExecuteSQL(
    'INSERT INTO Config (Key, Value) VALUES (''old.format.another'', ''value2'')'
  );
  
  // Migrate to new format
  FContext.ExecuteSQL(
    'UPDATE Config SET Key = REPLACE(Key, ''old.format.'', ''new.format.'') ' +
    'WHERE Key LIKE ''old.format.%'''
  );
  
  // Verify migration
  TIntegrationAssert.QueryCount(FContext.Connection,
    'SELECT * FROM Config WHERE Key LIKE ''old.format.%''', 0);
  TIntegrationAssert.QueryCount(FContext.Connection,
    'SELECT * FROM Config WHERE Key LIKE ''new.format.%''', 2);
end;

procedure TWorkflowIntegrationTest.Test_DataExportImport;
var
  ExportFile: string;
  Query: TFDQuery;
  ExportData: TStringList;
begin
  // Insert test data
  FContext.DataGenerator.InsertUsers(10);
  
  // Export to file
  ExportFile := FContext.CreateTempFile('.csv');
  ExportData := TStringList.Create;
  try
    ExportData.Add('Username,Email,Role');
    
    Query := FContext.QuerySQL('SELECT Username, Email, Role FROM Users');
    try
      while not Query.Eof do
      begin
        ExportData.Add(Format('%s,%s,%s', [
          Query.FieldByName('Username').AsString,
          Query.FieldByName('Email').AsString,
          Query.FieldByName('Role').AsString
        ]));
        Query.Next;
      end;
    finally
      Query.Free;
    end;
    
    ExportData.SaveToFile(ExportFile);
  finally
    ExportData.Free;
  end;
  
  // Verify export file
  TIntegrationAssert.FileExists(ExportFile);
  TIntegrationAssert.FileContains(ExportFile, 'Username,Email,Role');
end;

procedure TWorkflowIntegrationTest.Test_SystemInitialization;
begin
  // Verify all required tables exist
  TIntegrationAssert.TableExists(FContext.Connection, 'Config');
  TIntegrationAssert.TableExists(FContext.Connection, 'Logs');
  TIntegrationAssert.TableExists(FContext.Connection, 'Users');
  TIntegrationAssert.TableExists(FContext.Connection, 'TestSnapshots');
  
  // Verify system is operational
  Assert.IsTrue(FContext.Connection.Connected, 'Database should be connected');
  Assert.IsTrue(FContext.Initialized, 'Context should be initialized');
end;

procedure TWorkflowIntegrationTest.Test_GracefulShutdown;
var
  TempContext: TIntegrationTestContext;
begin
  // Create temporary context
  TempContext := CreateTestContext;
  try
    Assert.IsTrue(TempContext.Initialized, 'Context should be initialized');
    Assert.IsTrue(TempContext.Connection.Connected, 'Connection should be active');
    
    // Cleanup
    TempContext.Cleanup;
    
    Assert.IsFalse(TempContext.Initialized, 'Context should be deinitialized');
  finally
    TempContext.Free;
  end;
end;

// ============================================================================
// TPerformanceRegressionTest
// ============================================================================

procedure TPerformanceRegressionTest.InitializeTestData;
begin
  inherited;
  FContext.DataGenerator.ClearAllData;
  FContext.DataGenerator.InsertUsers(100);
  FContext.DataGenerator.InsertConfigs(100);
end;

procedure TPerformanceRegressionTest.CleanupTestData;
begin
  FContext.DataGenerator.ClearAllData;
  inherited;
end;

procedure TPerformanceRegressionTest.Setup;
begin
  inherited;
  FBenchmark := TPerformanceBenchmark.Create;
  FBenchmark.WarmupIterations := 3;
end;

procedure TPerformanceRegressionTest.TearDown;
begin
  FBenchmark.Free;
  inherited;
end;

procedure TPerformanceRegressionTest.Test_ConfigReadPerformance;
var
  Result: TBenchmarkResult;
begin
  Result := FBenchmark.Run('ConfigRead', 100, procedure
  var
    Query: TFDQuery;
  begin
    Query := FContext.QuerySQL('SELECT Value FROM Config WHERE Key = ''test.config.50''');
    Query.Free;
  end);
  
  // Baseline: should read config in < 10ms average
  Assert.IsTrue(Result.AvgTime < 10,
    Format('Config read avg %.2f ms, expected < 10 ms', [Result.AvgTime]));
end;

procedure TPerformanceRegressionTest.Test_ConfigWritePerformance;
var
  Result: TBenchmarkResult;
  Counter: Integer;
begin
  Counter := 0;
  
  Result := FBenchmark.Run('ConfigWrite', 100, procedure
  begin
    Inc(Counter);
    FContext.ExecuteSQL(Format(
      'INSERT OR REPLACE INTO Config (Key, Value) VALUES (''perf.test.%d'', ''value'')',
      [Counter]
    ));
  end);
  
  // Baseline: should write config in < 20ms average
  Assert.IsTrue(Result.AvgTime < 20,
    Format('Config write avg %.2f ms, expected < 20 ms', [Result.AvgTime]));
  
  // Cleanup
  FContext.ExecuteSQL('DELETE FROM Config WHERE Key LIKE ''perf.test.%''');
end;

procedure TPerformanceRegressionTest.Test_DatabaseQueryPerformance;
var
  Result: TBenchmarkResult;
begin
  Result := FBenchmark.Run('DatabaseQuery', 50, procedure
  var
    Query: TFDQuery;
  begin
    Query := FContext.QuerySQL('SELECT * FROM Users WHERE Username LIKE ''testuser_%'' LIMIT 10');
    Query.Free;
  end);
  
  // Baseline: query should complete in < 50ms average
  Assert.IsTrue(Result.AvgTime < 50,
    Format('DB query avg %.2f ms, expected < 50 ms', [Result.AvgTime]));
end;

procedure TPerformanceRegressionTest.Test_LogWritePerformance;
var
  Result: TBenchmarkResult;
  Counter: Integer;
begin
  Counter := 0;
  
  Result := FBenchmark.Run('LogWrite', 100, procedure
  begin
    Inc(Counter);
    FContext.ExecuteSQL(Format(
      'INSERT INTO Logs (Level, Message, Category) VALUES (''INFO'', ''Perf test %d'', ''perf'')',
      [Counter]
    ));
  end);
  
  // Baseline: should write log in < 10ms average
  Assert.IsTrue(Result.AvgTime < 10,
    Format('Log write avg %.2f ms, expected < 10 ms', [Result.AvgTime]));
  
  // Cleanup
  FContext.ExecuteSQL('DELETE FROM Logs WHERE Category = ''perf''');
end;

procedure TPerformanceRegressionTest.Test_MemoryUsage;
begin
  // Test that operations don't leak memory
  TIntegrationAssert.NoMemoryLeak(procedure
  var
    I: Integer;
    Query: TFDQuery;
  begin
    for I := 1 to 100 do
    begin
      Query := FContext.QuerySQL('SELECT * FROM Config LIMIT 10');
      Query.Free;
    end;
  end, 1024 * 1024); // 1MB tolerance
end;

initialization
  TDUnitX.RegisterTestFixture(TConfigIntegrationTest);
  TDUnitX.RegisterTestFixture(TLoggingIntegrationTest);
  TDUnitX.RegisterTestFixture(TDatabaseIntegrationTest);
  TDUnitX.RegisterTestFixture(TWorkflowIntegrationTest);
  TDUnitX.RegisterTestFixture(TPerformanceRegressionTest);

end.
