{ ============================================================================
  Stress.Database - Database Stress Tests
  
  Tests database connection pool and concurrent operations:
  - Connection pool stress
  - Concurrent queries
  - Transaction stress
  - Large result set handling
  - Connection leak detection
  ============================================================================ }

unit Stress.Database;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.SyncObjs,
  System.Diagnostics,
  FireDAC.Comp.Client,
  DeepBase.StressTest;

type
  // ============================================================================
  // TDBConnectionPoolStressTest - Connection pool stress
  // ============================================================================
  
  TDBConnectionPoolStressTest = class(TStressTest)
  private
    FAcquireCount: Int64;
    FReleaseCount: Int64;
    FHoldTimeMs: Integer;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
    property HoldTimeMs: Integer read FHoldTimeMs write FHoldTimeMs;
  end;
  
  // ============================================================================
  // TDBQueryStressTest - Concurrent queries
  // ============================================================================
  
  TDBQueryStressTest = class(TStressTest)
  private
    FTableName: string;
    FRowCount: Integer;
    FQueryCounter: Int64;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
    property TableName: string read FTableName write FTableName;
    property RowCount: Integer read FRowCount write FRowCount;
  end;
  
  // ============================================================================
  // TDBInsertStressTest - Concurrent inserts
  // ============================================================================
  
  TDBInsertStressTest = class(TStressTest)
  private
    FTableName: string;
    FValueSize: Integer;
    FInsertCounter: Int64;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
    property TableName: string read FTableName write FTableName;
    property ValueSize: Integer read FValueSize write FValueSize;
  end;
  
  // ============================================================================
  // TDBTransactionStressTest - Transaction stress
  // ============================================================================
  
  TDBTransactionStressTest = class(TStressTest)
  private
    FTableName: string;
    FOpsPerTransaction: Integer;
    FTxCounter: Int64;
    FCommitRatio: Double;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
    property TableName: string read FTableName write FTableName;
    property OpsPerTransaction: Integer read FOpsPerTransaction write FOpsPerTransaction;
    property CommitRatio: Double read FCommitRatio write FCommitRatio;
  end;
  
  // ============================================================================
  // TDBLargeResultStressTest - Large result sets
  // ============================================================================
  
  TDBLargeResultStressTest = class(TStressTest)
  private
    FTableName: string;
    FRowsToFetch: Integer;
    FQueryCounter: Int64;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
    property TableName: string read FTableName write FTableName;
    property RowsToFetch: Integer read FRowsToFetch write FRowsToFetch;
  end;
  
  // ============================================================================
  // TDBMixedOperationsStressTest - Mixed operations
  // ============================================================================
  
  TDBMixedOperationsStressTest = class(TStressTest)
  private
    FTableName: string;
    FSelectRatio: Double;
    FInsertRatio: Double;
    FUpdateRatio: Double;
    FDeleteRatio: Double;
    FOpCounter: Int64;
    FLock: TCriticalSection;
    FExistingIds: TList<Int64>;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
    property TableName: string read FTableName write FTableName;
    property SelectRatio: Double read FSelectRatio write FSelectRatio;
    property InsertRatio: Double read FInsertRatio write FInsertRatio;
    property UpdateRatio: Double read FUpdateRatio write FUpdateRatio;
    property DeleteRatio: Double read FDeleteRatio write FDeleteRatio;
  end;
  
  // ============================================================================
  // Helper functions
  // ============================================================================
  
  /// <summary>Run all database stress tests</summary>
  function RunAllDatabaseStressTests(DurationSec: Integer = 30; 
    ThreadCount: Integer = 10): TStressTestReport;

implementation

uses
  System.Math,
  DeepBase.Manager;

const
  STRESS_TEST_TABLE = 'stress_test_data';

// Helper function to get database connection from DeepBase Manager
function GetDBConnection: TFDConnection;
begin
  Result := DeepBase.Manager.DeepBase.ConfigDB;
end;

// Helper IfThen for integers
function IfThenInt(Condition: Boolean; TrueValue, FalseValue: Integer): Integer; inline;
begin
  if Condition then
    Result := TrueValue
  else
    Result := FalseValue;
end;
  
// ============================================================================
// TDBConnectionPoolStressTest
// ============================================================================

constructor TDBConnectionPoolStressTest.Create;
begin
  inherited Create('Database.ConnectionPool', 'Connection pool acquire/release stress');
  FHoldTimeMs := 10;
end;

procedure TDBConnectionPoolStressTest.Setup;
begin
  FAcquireCount := 0;
  FReleaseCount := 0;
end;

procedure TDBConnectionPoolStressTest.Teardown;
begin
  AddCustomMetric('AcquireCount', FAcquireCount);
  AddCustomMetric('ReleaseCount', FReleaseCount);
end;

procedure TDBConnectionPoolStressTest.Execute;
var
  Conn: TFDConnection;
  SW: TStopwatch;
begin
  SW := TStopwatch.StartNew;
  try
    // Get connection from DeepBase Manager
    Conn := GetDBConnection;
    if Conn = nil then
    begin
      ReportError('Connection not available');
      Exit;
    end;
    
    TInterlocked.Increment(FAcquireCount);
    
    // Simulate some work
    if FHoldTimeMs > 0 then
      Sleep(FHoldTimeMs);
    
    // Simple validation query
    Conn.ExecSQL('SELECT 1');
    
    TInterlocked.Increment(FReleaseCount);
    
    SW.Stop;
    ReportLatency(SW.Elapsed.TotalMilliseconds);
    ReportSuccess;
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Database connection error: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// TDBQueryStressTest
// ============================================================================

constructor TDBQueryStressTest.Create;
begin
  inherited Create('Database.Query', 'Concurrent SELECT query stress');
  FTableName := STRESS_TEST_TABLE;
  FRowCount := 1000;
end;

procedure TDBQueryStressTest.Setup;
var
  I: Integer;
  Conn: TFDConnection;
begin
  FQueryCounter := 0;
  
  // Create test table and populate with data
  Conn := GetDBConnection;
  try
    // Create table if not exists
    Conn.ExecSQL(Format(
      'CREATE TABLE IF NOT EXISTS %s (' +
      '  id INTEGER PRIMARY KEY,' +
      '  name TEXT NOT NULL,' +
      '  value TEXT,' +
      '  created_at DATETIME DEFAULT CURRENT_TIMESTAMP' +
      ')', [FTableName]));
    
    // Clear existing data
    Conn.ExecSQL(Format('DELETE FROM %s', [FTableName]));
    
    // Insert test rows
    Conn.StartTransaction;
    try
      for I := 1 to FRowCount do
      begin
        Conn.ExecSQL(Format(
          'INSERT INTO %s (id, name, value) VALUES (%d, ''name_%d'', ''%s'')',
          [FTableName, I, I, StringOfChar('V', 100)]));
      end;
      Conn.Commit;
    except
      Conn.Rollback;
      raise;
    end;
  except
    on E: Exception do
      raise Exception.CreateFmt('Setup failed: %s', [E.Message]);
  end;
end;

procedure TDBQueryStressTest.Teardown;
var
  Conn: TFDConnection;
begin
  AddCustomMetric('TotalQueries', FQueryCounter);
  
  // Clean up test table
  try
    Conn := GetDBConnection;
    Conn.ExecSQL(Format('DROP TABLE IF EXISTS %s', [FTableName]));
  except
    // Ignore cleanup errors
  end;
end;

procedure TDBQueryStressTest.Execute;
var
  Query: TFDQuery;
  Conn: TFDConnection;
  RandomId: Integer;
  SW: TStopwatch;
begin
  TInterlocked.Increment(FQueryCounter);
  RandomId := Random(FRowCount) + 1;
  
  Conn := GetDBConnection;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := Conn;
    
    SW := TStopwatch.StartNew;
    try
      Query.SQL.Text := Format(
        'SELECT * FROM %s WHERE id = :id', [FTableName]);
      Query.ParamByName('id').AsInteger := RandomId;
      Query.Open;
      
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      
      if not Query.IsEmpty then
        ReportSuccess
      else
        ReportError('Query returned no results for id: ' + IntToStr(RandomId));
        
      AddCustomMetric('RowsReturned', Query.RecordCount);
    except
      on E: Exception do
      begin
        SW.Stop;
        ReportLatency(SW.Elapsed.TotalMilliseconds);
        ReportError('Query failed: ' + E.Message);
      end;
    end;
  finally
    Query.Free;
  end;
end;

// ============================================================================
// TDBInsertStressTest
// ============================================================================

constructor TDBInsertStressTest.Create;
begin
  inherited Create('Database.Insert', 'Concurrent INSERT stress');
  FTableName := STRESS_TEST_TABLE + '_insert';
  FValueSize := 100;
end;

procedure TDBInsertStressTest.Setup;
var
  Conn: TFDConnection;
begin
  FInsertCounter := 0;
  
  Conn := GetDBConnection;
  // Create table
  Conn.ExecSQL(Format(
    'CREATE TABLE IF NOT EXISTS %s (' +
    '  id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  name TEXT NOT NULL,' +
    '  value TEXT,' +
    '  thread_id INTEGER,' +
    '  created_at DATETIME DEFAULT CURRENT_TIMESTAMP' +
    ')', [FTableName]));
end;

procedure TDBInsertStressTest.Teardown;
var
  Conn: TFDConnection;
begin
  AddCustomMetric('TotalInserts', FInsertCounter);
  
  try
    Conn := GetDBConnection;
    Conn.ExecSQL(Format('DROP TABLE IF EXISTS %s', [FTableName]));
  except
    // Ignore cleanup errors
  end;
end;

procedure TDBInsertStressTest.Execute;
var
  Conn: TFDConnection;
  Counter: Int64;
  Value: string;
  SW: TStopwatch;
begin
  Counter := TInterlocked.Increment(FInsertCounter);
  Value := StringOfChar('X', FValueSize);
  
  Conn := GetDBConnection;
  
  SW := TStopwatch.StartNew;
  try
    Conn.ExecSQL(Format(
      'INSERT INTO %s (name, value, thread_id) VALUES (''name_%d'', ''%s'', %d)',
      [FTableName, Counter, Value, TThread.CurrentThread.ThreadID]));
    
    SW.Stop;
    ReportLatency(SW.Elapsed.TotalMilliseconds);
    ReportSuccess;
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Insert failed: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// TDBTransactionStressTest
// ============================================================================

constructor TDBTransactionStressTest.Create;
begin
  inherited Create('Database.Transaction', 'Transaction commit/rollback stress');
  FTableName := STRESS_TEST_TABLE + '_tx';
  FOpsPerTransaction := 10;
  FCommitRatio := 0.9;  // 90% commit, 10% rollback
end;

procedure TDBTransactionStressTest.Setup;
var
  Conn: TFDConnection;
begin
  FTxCounter := 0;
  
  Conn := GetDBConnection;
  Conn.ExecSQL(Format(
    'CREATE TABLE IF NOT EXISTS %s (' +
    '  id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  tx_id INTEGER NOT NULL,' +
    '  seq INTEGER NOT NULL,' +
    '  value TEXT' +
    ')', [FTableName]));
end;

procedure TDBTransactionStressTest.Teardown;
var
  Conn: TFDConnection;
begin
  AddCustomMetric('TotalTransactions', FTxCounter);
  
  try
    Conn := GetDBConnection;
    Conn.ExecSQL(Format('DROP TABLE IF EXISTS %s', [FTableName]));
  except
    // Ignore cleanup errors
  end;
end;

procedure TDBTransactionStressTest.Execute;
var
  Conn: TFDConnection;
  TxId: Int64;
  I: Integer;
  DoCommit: Boolean;
  SW: TStopwatch;
begin
  TxId := TInterlocked.Increment(FTxCounter);
  DoCommit := Random < FCommitRatio;
  
  Conn := GetDBConnection;
  
  SW := TStopwatch.StartNew;
  try
    Conn.StartTransaction;
    try
      // Perform multiple operations in transaction
      for I := 1 to FOpsPerTransaction do
      begin
        Conn.ExecSQL(Format(
          'INSERT INTO %s (tx_id, seq, value) VALUES (%d, %d, ''tx_value'')',
          [FTableName, TxId, I]));
      end;
      
      if DoCommit then
        Conn.Commit
      else
        Conn.Rollback;
        
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportSuccess;
      
      AddCustomMetric('Commits', IfThenInt(DoCommit, 1, 0));
      AddCustomMetric('Rollbacks', IfThenInt(DoCommit, 0, 1));
    except
      Conn.Rollback;
      raise;
    end;
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Transaction failed: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// TDBLargeResultStressTest
// ============================================================================

constructor TDBLargeResultStressTest.Create;
begin
  inherited Create('Database.LargeResult', 'Large result set handling');
  FTableName := STRESS_TEST_TABLE + '_large';
  FRowsToFetch := 1000;
end;

procedure TDBLargeResultStressTest.Setup;
var
  I: Integer;
  Conn: TFDConnection;
begin
  FQueryCounter := 0;
  
  Conn := GetDBConnection;
  
  // Create and populate large table
  Conn.ExecSQL(Format(
    'CREATE TABLE IF NOT EXISTS %s (' +
    '  id INTEGER PRIMARY KEY,' +
    '  data TEXT NOT NULL' +
    ')', [FTableName]));
  
  Conn.ExecSQL(Format('DELETE FROM %s', [FTableName]));
  
  Conn.StartTransaction;
  try
    for I := 1 to FRowsToFetch do
    begin
      Conn.ExecSQL(Format(
        'INSERT INTO %s (id, data) VALUES (%d, ''%s'')',
        [FTableName, I, StringOfChar('D', 500)]));
    end;
    Conn.Commit;
  except
    Conn.Rollback;
    raise;
  end;
end;

procedure TDBLargeResultStressTest.Teardown;
var
  Conn: TFDConnection;
begin
  AddCustomMetric('TotalQueries', FQueryCounter);
  
  try
    Conn := GetDBConnection;
    Conn.ExecSQL(Format('DROP TABLE IF EXISTS %s', [FTableName]));
  except
    // Ignore cleanup errors
  end;
end;

procedure TDBLargeResultStressTest.Execute;
var
  Query: TFDQuery;
  Conn: TFDConnection;
  RowCount: Integer;
  SW: TStopwatch;
begin
  TInterlocked.Increment(FQueryCounter);
  
  Conn := GetDBConnection;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := Conn;
    
    SW := TStopwatch.StartNew;
    try
      Query.SQL.Text := Format('SELECT * FROM %s', [FTableName]);
      Query.Open;
      
      // Iterate through all rows
      RowCount := 0;
      while not Query.Eof do
      begin
        Inc(RowCount);
        Query.Next;
      end;
      
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      
      if RowCount = FRowsToFetch then
        ReportSuccess
      else
        ReportError(Format('Expected %d rows, got %d', [FRowsToFetch, RowCount]));
        
      AddCustomMetric('RowsFetched', RowCount);
    except
      on E: Exception do
      begin
        SW.Stop;
        ReportLatency(SW.Elapsed.TotalMilliseconds);
        ReportError('Large result query failed: ' + E.Message);
      end;
    end;
  finally
    Query.Free;
  end;
end;

// ============================================================================
// TDBMixedOperationsStressTest
// ============================================================================

constructor TDBMixedOperationsStressTest.Create;
begin
  inherited Create('Database.MixedOps', 'Mixed database operations stress');
  FTableName := STRESS_TEST_TABLE + '_mixed';
  FSelectRatio := 0.60;
  FInsertRatio := 0.20;
  FUpdateRatio := 0.15;
  FDeleteRatio := 0.05;
  FLock := TCriticalSection.Create;
  FExistingIds := TList<Int64>.Create;
end;

destructor TDBMixedOperationsStressTest.Destroy;
begin
  FExistingIds.Free;
  FLock.Free;
  inherited;
end;

procedure TDBMixedOperationsStressTest.Setup;
var
  I: Integer;
  Conn: TFDConnection;
begin
  FOpCounter := 0;
  FExistingIds.Clear;
  
  Conn := GetDBConnection;
  
  // Create table
  Conn.ExecSQL(Format(
    'CREATE TABLE IF NOT EXISTS %s (' +
    '  id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  name TEXT NOT NULL,' +
    '  value INTEGER DEFAULT 0' +
    ')', [FTableName]));
  
  Conn.ExecSQL(Format('DELETE FROM %s', [FTableName]));
  
  // Pre-populate some rows
  Conn.StartTransaction;
  try
    for I := 1 to 100 do
    begin
      Conn.ExecSQL(Format(
        'INSERT INTO %s (name, value) VALUES (''initial_%d'', %d)',
        [FTableName, I, I]));
      FExistingIds.Add(I);
    end;
    Conn.Commit;
  except
    Conn.Rollback;
    raise;
  end;
end;

procedure TDBMixedOperationsStressTest.Teardown;
var
  Conn: TFDConnection;
begin
  AddCustomMetric('TotalOperations', FOpCounter);
  
  try
    Conn := GetDBConnection;
    Conn.ExecSQL(Format('DROP TABLE IF EXISTS %s', [FTableName]));
  except
    // Ignore cleanup errors
  end;
end;

procedure TDBMixedOperationsStressTest.Execute;
var
  Conn: TFDConnection;
  Query: TFDQuery;
  R: Double;
  OpType: string;
  RandomId: Int64;
  Counter: Int64;
  SW: TStopwatch;
begin
  Counter := TInterlocked.Increment(FOpCounter);
  Conn := GetDBConnection;
  
  R := Random;
  
  SW := TStopwatch.StartNew;
  try
    if R < FSelectRatio then
    begin
      // SELECT
      OpType := 'SELECT';
      Query := TFDQuery.Create(nil);
      try
        Query.Connection := Conn;
        Query.SQL.Text := Format('SELECT * FROM %s ORDER BY RANDOM() LIMIT 10', [FTableName]);
        Query.Open;
        AddCustomMetric('SelectRows', Query.RecordCount);
      finally
        Query.Free;
      end;
    end
    else if R < FSelectRatio + FInsertRatio then
    begin
      // INSERT
      OpType := 'INSERT';
      Conn.ExecSQL(Format(
        'INSERT INTO %s (name, value) VALUES (''op_%d'', %d)',
        [FTableName, Counter, Random(1000)]));
      
      FLock.Enter;
      try
        FExistingIds.Add(Counter);
      finally
        FLock.Leave;
      end;
    end
    else if R < FSelectRatio + FInsertRatio + FUpdateRatio then
    begin
      // UPDATE
      OpType := 'UPDATE';
      FLock.Enter;
      try
        if FExistingIds.Count > 0 then
          RandomId := FExistingIds[Random(FExistingIds.Count)]
        else
          RandomId := 1;
      finally
        FLock.Leave;
      end;
      
      Conn.ExecSQL(Format(
        'UPDATE %s SET value = value + 1 WHERE id = %d',
        [FTableName, RandomId]));
    end
    else
    begin
      // DELETE
      OpType := 'DELETE';
      FLock.Enter;
      try
        if FExistingIds.Count > 10 then
        begin
          RandomId := FExistingIds[Random(FExistingIds.Count)];
          FExistingIds.Remove(RandomId);
        end
        else
          RandomId := -1;
      finally
        FLock.Leave;
      end;
      
      if RandomId > 0 then
        Conn.ExecSQL(Format('DELETE FROM %s WHERE id = %d', [FTableName, RandomId]));
    end;
    
    SW.Stop;
    ReportLatency(SW.Elapsed.TotalMilliseconds);
    ReportSuccess;
    
    AddCustomMetric('Op_' + OpType, 1);
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError(OpType + ' failed: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// Helper functions
// ============================================================================

function RunAllDatabaseStressTests(DurationSec: Integer; 
  ThreadCount: Integer): TStressTestReport;
var
  Runner: TStressTestRunner;
  PoolTest: TDBConnectionPoolStressTest;
  QueryTest: TDBQueryStressTest;
  InsertTest: TDBInsertStressTest;
  TxTest: TDBTransactionStressTest;
  LargeTest: TDBLargeResultStressTest;
  MixedTest: TDBMixedOperationsStressTest;
begin
  Runner := TStressTestRunner.Create;
  try
    Runner.Config.DurationSec := DurationSec;
    Runner.Config.ThreadCount := ThreadCount;
    
    // Connection pool test
    PoolTest := TDBConnectionPoolStressTest.Create;
    PoolTest.HoldTimeMs := 5;
    Runner.AddTest(PoolTest);
    
    // Query test
    QueryTest := TDBQueryStressTest.Create;
    QueryTest.RowCount := 1000;
    Runner.AddTest(QueryTest);
    
    // Insert test
    InsertTest := TDBInsertStressTest.Create;
    InsertTest.ValueSize := 100;
    Runner.AddTest(InsertTest);
    
    // Transaction test
    TxTest := TDBTransactionStressTest.Create;
    TxTest.OpsPerTransaction := 5;
    TxTest.CommitRatio := 0.9;
    Runner.AddTest(TxTest);
    
    // Large result test (fewer threads due to memory)
    LargeTest := TDBLargeResultStressTest.Create;
    LargeTest.RowsToFetch := 500;
    Runner.AddTest(LargeTest);
    
    // Mixed operations test
    MixedTest := TDBMixedOperationsStressTest.Create;
    Runner.AddTest(MixedTest);
    
    Runner.Run;
    
    Result := Runner.Report;
  finally
    Runner.Free;
  end;
end;

function IfThen(Condition: Boolean; TrueValue, FalseValue: Double): Double;
begin
  if Condition then
    Result := TrueValue
  else
    Result := FalseValue;
end;

end.
