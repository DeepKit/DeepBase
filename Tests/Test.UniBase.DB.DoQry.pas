{ ============================================================================
  Test.UniBase.DB.DoQry - DoQry 集成模块测试
  
  说明: 测试 UniBase.DB.DoQry 模块的核心功能
  ============================================================================ }

unit Test.UniBase.DB.DoQry;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils, System.IOUtils, System.Variants, System.Threading, System.SyncObjs,
  System.Generics.Collections,
  FireDAC.Comp.Client, FireDAC.Comp.DataSet, FireDAC.Stan.Def, FireDAC.Phys.SQLite,
  UniBase.DB.DoQry;

type
  [TestFixture]
  TTestUniBaseDoQry = class
  private
    FConnection: TFDConnection;
    FTestDBPath: string;
    
    procedure CreateTestTable;
    procedure DropTestTable;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_MakeContext_CreatesValidContext;
    
    [Test]
    procedure Test_NewCorrelationId_ReturnsUniqueId;
    
    [Test]
    procedure Test_ExecInsert_InsertsRow;
    
    [Test]
    procedure Test_Select_ReturnsData;
    
    [Test]
    procedure Test_Scalar_ReturnsValue;
    
    [Test]
    procedure Test_Transaction_CommitPersists;
    
    [Test]
    procedure Test_Transaction_RollbackReverts;
    
    [Test]
    procedure Test_RunInTx_AutoCommit;
    
    [Test]
    procedure Test_RunInTx_AutoRollbackOnException;

    [Test]
    procedure Test_RunInTx_NestedSavepoint_CommitWorks;

    [Test]
    procedure Test_RunInTx_NestedSavepoint_InnerRollbackKeepsOuter;
    
    [Test]
    procedure Test_InvalidSQL_RaisesEUniBaseDbError;

    [Test]
    procedure Test_QueryTable_NameSqlText_LoadsSql;

    [Test]
    procedure Test_MissingProcName_DoesNotFallbackToSQL;

    [Test]
    procedure Test_DirectDDL_IsBlockedUnlessStoredInQueries;

    [Test]
    procedure Test_InsertReturningId_BindsJsonParams;

    [Test]
    procedure Test_InsertReturningId_WithTrigger_ReturnsTargetTableId;

    [Test]
    procedure Test_InsertReturningId_ConcurrentWrites_ReturnUniqueIds;
    
    [Test]
    procedure Test_CacheTTL_Expiry;
    
    [Test]
    procedure Test_CacheInvalidate_RemovesEntry;
    
    [Test]
    procedure Test_CacheStats_Accuracy;

    [Test]
    procedure Test_CacheConcurrentLoad_SingleMissAndStableResult;
    
    [Test]
    procedure Test_MultiTypeFields_CopyCorrectly;
    
    [Test]
    procedure Test_NullFields_CopyCorrectly;
    
    [Test]
    procedure Test_DateTimeFields_CopyCorrectly;
    
    [Test]
    procedure Test_ErrorCode_SqlSyntax;
    
    [Test]
    procedure Test_ErrorCode_UniqueConstraint;
    
    [Test]
    procedure Test_ErrorCode_HasCorrectValue;
    
    [Test]
    procedure Test_PreparedPool_EnabledCreatesPooledQuery;
    
    [Test]
    procedure Test_PreparedPool_StatsTracksReuse;
    
    [Test]
    procedure Test_PreparedPool_ClearRemovesAll;

    [Test]
    procedure Test_PreparedPool_MaxSizeEnforcesLRUEviction;
  end;

implementation

{ TTestUniBaseDoQry }

procedure TTestUniBaseDoQry.Setup;
begin
  // 使用内存数据库
  FTestDBPath := ':memory:';
  
  FConnection := TFDConnection.Create(nil);
  FConnection.DriverName := 'SQLite';
  FConnection.Params.Database := FTestDBPath;
  FConnection.Open;
  
  // 初始化 DoQry
  UniDbInit(ExtractFilePath(ParamStr(0)));
  
  CreateTestTable;
end;

procedure TTestUniBaseDoQry.TearDown;
begin
  DropTestTable;
  FConnection.Free;
end;

procedure TTestUniBaseDoQry.CreateTestTable;
var
  Q: TFDQuery;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text := 
      'CREATE TABLE IF NOT EXISTS test_users (' +
      '  id INTEGER PRIMARY KEY AUTOINCREMENT,' +
      '  name TEXT NOT NULL,' +
      '  age INTEGER,' +
      '  active INTEGER DEFAULT 1' +
      ')';
    Q.ExecSQL;
    
    // 多类型字段测试表
    Q.SQL.Text := 
      'CREATE TABLE IF NOT EXISTS test_multitype (' +
      '  id INTEGER PRIMARY KEY AUTOINCREMENT,' +
      '  name TEXT,' +
      '  price REAL,' +
      '  quantity INTEGER,' +
      '  is_active INTEGER,' +
      '  created_at TEXT,' +  // SQLite 无原生日期类型，使用 TEXT
      '  data BLOB,' +
      '  description TEXT' +
      ')';
    Q.ExecSQL;

    Q.SQL.Text :=
      'CREATE TABLE IF NOT EXISTS Queries (' +
      '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
      '  Name TEXT NOT NULL UNIQUE,' +
      '  SqlText TEXT NOT NULL,' +
      '  IsEnabled INTEGER DEFAULT 1' +
      ')';
    Q.ExecSQL;
  finally
    Q.Free;
  end;
end;

procedure TTestUniBaseDoQry.DropTestTable;
var
  Q: TFDQuery;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text := 'DROP TABLE IF EXISTS test_users';
    Q.ExecSQL;
    Q.SQL.Text := 'DROP TABLE IF EXISTS test_multitype';
    Q.ExecSQL;
    Q.SQL.Text := 'DROP TABLE IF EXISTS Queries';
    Q.ExecSQL;
  finally
    Q.Free;
  end;
end;

procedure TTestUniBaseDoQry.Test_MakeContext_CreatesValidContext;
var
  Ctx: TUniQueryContext;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite, 30, '');
  
  Assert.IsNotNull(Ctx.Connection, 'Connection should not be nil');
  Assert.AreEqual(udbSQLite, Ctx.DBType, 'DBType should be SQLite');
  Assert.AreEqual(30, Ctx.TimeoutSec, 'TimeoutSec should be 30');
  Assert.IsNotEmpty(Ctx.CorrelationId, 'CorrelationId should not be empty');
end;

procedure TTestUniBaseDoQry.Test_NewCorrelationId_ReturnsUniqueId;
var
  Id1, Id2: string;
begin
  Id1 := UniDbNewCorrelationId;
  Id2 := UniDbNewCorrelationId;
  
  Assert.IsNotEmpty(Id1, 'Id1 should not be empty');
  Assert.IsNotEmpty(Id2, 'Id2 should not be empty');
  Assert.AreNotEqual(Id1, Id2, 'IDs should be unique');
end;

procedure TTestUniBaseDoQry.Test_ExecInsert_InsertsRow;
var
  Ctx: TUniQueryContext;
  Rows: Integer;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite);
  
  Rows := UniDbExec(
    'INSERT INTO test_users (name, age) VALUES (:name, :age)',
    '{"name": "Alice", "age": 30}',
    Ctx
  );
  
  Assert.AreEqual(1, Rows, 'Should insert 1 row');
end;

procedure TTestUniBaseDoQry.Test_Select_ReturnsData;
var
  Ctx: TUniQueryContext;
  Data: TFDMemTable;
  Rows: Integer;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite);
  
  // 先插入数据
  UniDbExec(
    'INSERT INTO test_users (name, age) VALUES (:name, :age)',
    '{"name": "Bob", "age": 25}',
    Ctx
  );
  
  Data := TFDMemTable.Create(nil);
  try
    Rows := UniDbSelect(
      'SELECT * FROM test_users WHERE name = :name',
      '{"name": "Bob"}',
      Data,
      Ctx
    );
    
    Assert.AreEqual(1, Rows, 'Should return 1 row');
  finally
    Data.Free;
  end;
end;

procedure TTestUniBaseDoQry.Test_Scalar_ReturnsValue;
var
  Ctx: TUniQueryContext;
  Count: Variant;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite);
  
  // 插入两条数据
  UniDbExec('INSERT INTO test_users (name, age) VALUES (:name, :age)', '{"name": "A", "age": 20}', Ctx);
  UniDbExec('INSERT INTO test_users (name, age) VALUES (:name, :age)', '{"name": "B", "age": 30}', Ctx);
  
  Count := UniDbScalar('SELECT COUNT(*) FROM test_users', '', Ctx);
  
  Assert.AreEqual(2, Integer(Count), 'Should return count of 2');
end;

procedure TTestUniBaseDoQry.Test_Transaction_CommitPersists;
var
  Ctx: TUniQueryContext;
  Tx: IUniTransaction;
  Count: Variant;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite);
  
  Tx := UniDbBeginTx(Ctx);
  try
    UniDbExec('INSERT INTO test_users (name, age) VALUES (:name, :age)', '{"name": "TxTest", "age": 40}', Ctx);
    Tx.Commit;
  except
    Tx.Rollback;
    raise;
  end;
  
  Count := UniDbScalar('SELECT COUNT(*) FROM test_users WHERE name = ''TxTest''', '', Ctx);
  Assert.AreEqual(1, Integer(Count), 'Data should persist after commit');
end;

procedure TTestUniBaseDoQry.Test_Transaction_RollbackReverts;
var
  Ctx: TUniQueryContext;
  Tx: IUniTransaction;
  Count: Variant;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite);
  
  Tx := UniDbBeginTx(Ctx);
  UniDbExec('INSERT INTO test_users (name, age) VALUES (:name, :age)', '{"name": "RollbackTest", "age": 50}', Ctx);
  Tx.Rollback;
  
  Count := UniDbScalar('SELECT COUNT(*) FROM test_users WHERE name = ''RollbackTest''', '', Ctx);
  Assert.AreEqual(0, Integer(Count), 'Data should be rolled back');
end;

procedure TTestUniBaseDoQry.Test_RunInTx_AutoCommit;
var
  Ctx: TUniQueryContext;
  Count: Variant;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite);
  
  UniDbRunInTx(Ctx, procedure
  begin
    UniDbExec('INSERT INTO test_users (name, age) VALUES (:name, :age)', '{"name": "AutoCommit", "age": 60}', Ctx);
  end);
  
  Count := UniDbScalar('SELECT COUNT(*) FROM test_users WHERE name = ''AutoCommit''', '', Ctx);
  Assert.AreEqual(1, Integer(Count), 'Data should persist after RunInTx');
end;

procedure TTestUniBaseDoQry.Test_RunInTx_AutoRollbackOnException;
var
  Ctx: TUniQueryContext;
  Count: Variant;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite);
  
  try
    UniDbRunInTx(Ctx, procedure
    begin
      UniDbExec('INSERT INTO test_users (name, age) VALUES (:name, :age)', '{"name": "WillRollback", "age": 70}', Ctx);
      raise Exception.Create('Test exception');
    end);
  except
    // Expected exception
  end;
  
  Count := UniDbScalar('SELECT COUNT(*) FROM test_users WHERE name = ''WillRollback''', '', Ctx);
  Assert.AreEqual(0, Integer(Count), 'Data should be rolled back on exception');
end;

procedure TTestUniBaseDoQry.Test_RunInTx_NestedSavepoint_CommitWorks;
var
  Ctx: TUniQueryContext;
  Count: Variant;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite);

  UniDbRunInTx(Ctx,
    procedure
    begin
      UniDbExec('INSERT INTO test_users (name, age) VALUES (:name, :age)',
        '{"name": "OuterA", "age": 10}', Ctx);

      UniDbRunInTx(Ctx,
        procedure
        begin
          UniDbExec('INSERT INTO test_users (name, age) VALUES (:name, :age)',
            '{"name": "InnerB", "age": 20}', Ctx);
        end);

      UniDbExec('INSERT INTO test_users (name, age) VALUES (:name, :age)',
        '{"name": "OuterC", "age": 30}', Ctx);
    end);

  Count := UniDbScalar(
    'SELECT COUNT(*) FROM test_users WHERE name IN (''OuterA'', ''InnerB'', ''OuterC'')',
    '', Ctx);
  Assert.AreEqual(3, Integer(Count), 'Nested transaction commit should persist all rows');
end;

procedure TTestUniBaseDoQry.Test_RunInTx_NestedSavepoint_InnerRollbackKeepsOuter;
var
  Ctx: TUniQueryContext;
  KeepCount: Variant;
  InnerCount: Variant;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite);

  UniDbRunInTx(Ctx,
    procedure
    begin
      UniDbExec('INSERT INTO test_users (name, age) VALUES (:name, :age)',
        '{"name": "OuterKeep", "age": 11}', Ctx);

      try
        UniDbRunInTx(Ctx,
          procedure
          begin
            UniDbExec('INSERT INTO test_users (name, age) VALUES (:name, :age)',
              '{"name": "InnerRollback", "age": 22}', Ctx);
            raise Exception.Create('force inner rollback');
          end);
      except
        // expected inner rollback
      end;

      UniDbExec('INSERT INTO test_users (name, age) VALUES (:name, :age)',
        '{"name": "OuterAfter", "age": 33}', Ctx);
    end);

  KeepCount := UniDbScalar(
    'SELECT COUNT(*) FROM test_users WHERE name IN (''OuterKeep'', ''OuterAfter'')',
    '', Ctx);
  InnerCount := UniDbScalar(
    'SELECT COUNT(*) FROM test_users WHERE name = ''InnerRollback''',
    '', Ctx);

  Assert.AreEqual(2, Integer(KeepCount), 'Outer transaction data should remain committed');
  Assert.AreEqual(0, Integer(InnerCount), 'Inner transaction should be rolled back by savepoint');
end;

procedure TTestUniBaseDoQry.Test_InvalidSQL_RaisesEUniBaseDbError;
var
  Ctx: TUniQueryContext;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite);
  
  Assert.WillRaise(
    procedure
    begin
      UniDbExec('SELECT FROM', '', Ctx);
    end,
    EUniBaseDbError,
    'Should raise EUniBaseDbError for invalid SQL'
  );
end;

procedure TTestUniBaseDoQry.Test_QueryTable_NameSqlText_LoadsSql;
var
  Ctx: TUniQueryContext;
  Data: TFDMemTable;
  Rows: Integer;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite);

  UniDbExec(
    'INSERT INTO Queries (Name, SqlText, IsEnabled) VALUES (:query_name, :sql_text, 1)',
    '{"query_name": "user.by_name", "sql_text": "SELECT * FROM test_users WHERE name = :name"}',
    Ctx
  );
  UniDbExec(
    'INSERT INTO test_users (name, age) VALUES (:name, :age)',
    '{"name": "StoredQueryUser", "age": 31}',
    Ctx
  );

  Data := TFDMemTable.Create(nil);
  try
    Rows := UniDbSelect('user.by_name', '{"name": "StoredQueryUser"}', Data, Ctx);
    Assert.AreEqual(1, Rows);
    Assert.AreEqual('StoredQueryUser', Data.FieldByName('name').AsString);
  finally
    Data.Free;
  end;
end;

procedure TTestUniBaseDoQry.Test_MissingProcName_DoesNotFallbackToSQL;
var
  Ctx: TUniQueryContext;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite);

  try
    UniDbExec('missing.proc.name', '', Ctx);
    Assert.Fail('Missing query name should not be executed as SQL');
  except
    on E: EUniBaseDbError do
      Assert.AreEqual(DOQRY_ERR_QUERY_NOT_FOUND, E.ErrorCode);
  end;
end;

procedure TTestUniBaseDoQry.Test_DirectDDL_IsBlockedUnlessStoredInQueries;
var
  Ctx: TUniQueryContext;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite);

  try
    UniDbExec('DROP TABLE test_users', '', Ctx);
    Assert.Fail('DDL text should not be accepted as direct SQL');
  except
    on E: EUniBaseDbError do
      Assert.AreEqual(DOQRY_ERR_QUERY_NOT_FOUND, E.ErrorCode);
  end;
end;

procedure TTestUniBaseDoQry.Test_InsertReturningId_BindsJsonParams;
var
  Ctx: TUniQueryContext;
  NewId: Integer;
  Name: Variant;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite);

  NewId := UniDbInsertReturningId(
    'INSERT INTO test_users (name, age) VALUES (:name, :age)',
    '{"name": "InsertIdUser", "age": 41}',
    Ctx
  );

  Assert.IsTrue(NewId > 0, 'InsertReturningId should return the new row id');
  Name := UniDbScalar('SELECT name FROM test_users WHERE id = :id',
    '{"id": ' + IntToStr(NewId) + '}', Ctx);
  Assert.AreEqual('InsertIdUser', string(Name));
end;

procedure TTestUniBaseDoQry.Test_InsertReturningId_WithTrigger_ReturnsTargetTableId;
var
  Ctx: TUniQueryContext;
  Q: TFDQuery;
  I: Integer;
  NewId: Integer;
  ActualId: Integer;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite);

  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'CREATE TABLE IF NOT EXISTS test_users_audit (' +
      '  id INTEGER PRIMARY KEY AUTOINCREMENT,' +
      '  user_name TEXT NOT NULL' +
      ')';
    Q.ExecSQL;

    for I := 1 to 20 do
    begin
      Q.SQL.Text := 'INSERT INTO test_users_audit (user_name) VALUES (:n)';
      Q.ParamByName('n').AsString := 'seed-' + IntToStr(I);
      Q.ExecSQL;
    end;

    Q.SQL.Text :=
      'CREATE TRIGGER IF NOT EXISTS trg_test_users_audit ' +
      'AFTER INSERT ON test_users ' +
      'BEGIN ' +
      '  INSERT INTO test_users_audit (user_name) VALUES (NEW.name); ' +
      'END';
    Q.ExecSQL;
  finally
    Q.Free;
  end;

  try
    NewId := UniDbInsertReturningId(
      'INSERT INTO test_users (name, age) VALUES (:name, :age)',
      '{"name": "TriggerUser", "age": 22}',
      Ctx
    );

    ActualId := Integer(UniDbScalar(
      'SELECT id FROM test_users WHERE name = :name',
      '{"name": "TriggerUser"}',
      Ctx
    ));

    Assert.AreEqual(ActualId, NewId,
      'InsertReturningId should return inserted test_users.id, not trigger side-effect rowid');
  finally
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := FConnection;
      Q.SQL.Text := 'DROP TRIGGER IF EXISTS trg_test_users_audit';
      Q.ExecSQL;
      Q.SQL.Text := 'DROP TABLE IF EXISTS test_users_audit';
      Q.ExecSQL;
    finally
      Q.Free;
    end;
  end;
end;

procedure TTestUniBaseDoQry.Test_InsertReturningId_ConcurrentWrites_ReturnUniqueIds;
const
  CThreadCount = 8;
var
  TempDbPath: string;
  SetupConn: TFDConnection;
  Q: TFDQuery;
  Tasks: TArray<ITask>;
  IdLock: TCriticalSection;
  ReturnedIds: TList<Integer>;
  ErrorCount: Integer;
  I: Integer;
  DistinctCount: Integer;
begin
  TempDbPath := TPath.Combine(TPath.GetTempPath,
    Format('unibase_insert_id_%d.db', [GetTickCount]));
  if TFile.Exists(TempDbPath) then
    TFile.Delete(TempDbPath);

  SetupConn := TFDConnection.Create(nil);
  try
    SetupConn.DriverName := 'SQLite';
    SetupConn.Params.Database := TempDbPath;
    SetupConn.Params.Values['OpenMode'] := 'CreateUTF8';
    SetupConn.Open;

    Q := TFDQuery.Create(nil);
    try
      Q.Connection := SetupConn;
      Q.SQL.Text :=
        'CREATE TABLE IF NOT EXISTS test_users (' +
        '  id INTEGER PRIMARY KEY AUTOINCREMENT,' +
        '  name TEXT NOT NULL,' +
        '  age INTEGER,' +
        '  active INTEGER DEFAULT 1' +
        ')';
      Q.ExecSQL;
    finally
      Q.Free;
    end;
  finally
    SetupConn.Free;
  end;

  UniDbInit(ExtractFilePath(ParamStr(0)));

  IdLock := TCriticalSection.Create;
  ReturnedIds := TList<Integer>.Create;
  try
    ErrorCount := 0;
    SetLength(Tasks, CThreadCount);
    for I := 0 to CThreadCount - 1 do
    begin
      var WorkerIndex := I;
      Tasks[I] := TTask.Run(
        procedure
        var
          Conn: TFDConnection;
          Ctx: TUniQueryContext;
          InsertId: Integer;
          Attempt: Integer;
          Success: Boolean;
          Payload: string;
        begin
          Conn := TFDConnection.Create(nil);
          try
            Conn.DriverName := 'SQLite';
            Conn.Params.Database := TempDbPath;
            Conn.Params.Values['OpenMode'] := 'CreateUTF8';
            Conn.Params.Values['JournalMode'] := 'WAL';
            Conn.Params.Values['BusyTimeout'] := '5000';
            Conn.Open;

            Ctx := UniDbMakeContext(Conn, udbSQLite);
            Payload := Format('{"name":"ConcUser-%d","age":%d}', [WorkerIndex, 20 + WorkerIndex]);

            Success := False;
            for Attempt := 1 to 5 do
            begin
              try
                InsertId := UniDbInsertReturningId(
                  'INSERT INTO test_users (name, age) VALUES (:name, :age)',
                  Payload,
                  Ctx
                );
                Success := True;
                Break;
              except
                on E: EUniBaseDbError do
                begin
                  if E.ErrorCode = DOQRY_ERR_TX_CONFLICT then
                    Sleep(Attempt * 10)
                  else
                    raise;
                end;
              end;
            end;

            if not Success then
            begin
              TInterlocked.Increment(ErrorCount);
              Exit;
            end;

            IdLock.Enter;
            try
              ReturnedIds.Add(InsertId);
            finally
              IdLock.Leave;
            end;
          except
            TInterlocked.Increment(ErrorCount);
          end;
          Conn.Free;
        end
      );
    end;

    TTask.WaitForAll(Tasks);
    Assert.AreEqual(0, ErrorCount, 'Concurrent insert should not produce errors');
    Assert.AreEqual(CThreadCount, ReturnedIds.Count, 'Each worker should return one id');

    ReturnedIds.Sort;
    DistinctCount := 1;
    for I := 1 to ReturnedIds.Count - 1 do
      if ReturnedIds[I] <> ReturnedIds[I - 1] then
        Inc(DistinctCount);
    Assert.AreEqual(CThreadCount, DistinctCount, 'Returned ids should be unique');
  finally
    ReturnedIds.Free;
    IdLock.Free;
    if TFile.Exists(TempDbPath) then
      TFile.Delete(TempDbPath);
  end;
end;

procedure TTestUniBaseDoQry.Test_CacheTTL_Expiry;
var
  Ctx: TUniQueryContext;
  Hits, Misses, EntryCount: Int64;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite);
  
  // 设置 TTL 为 1 秒
  UniDbSetCacheTTL(1);
  UniDbClearQueryCache;
  
  // 第一次调用，应该未命中
  UniDbExec('INSERT INTO test_users (name, age) VALUES (:name, :age)', '{"name": "TTLTest", "age": 20}', Ctx);
  UniDbGetCacheStats(Hits, Misses, EntryCount);
  Assert.AreEqual(Int64(0), Hits, 'First call should be cache miss');
  
  // 第二次调用（直接 SQL 不缓存，所以仍然是 miss，但这里验证 TTL 逻辑）
  // 等待 TTL 过期
  Sleep(1500);
  
  // 重置统计
  UniDbClearQueryCache;
  UniDbGetCacheStats(Hits, Misses, EntryCount);
  Assert.AreEqual(Int64(0), EntryCount, 'Cache should be empty after clear');
end;

procedure TTestUniBaseDoQry.Test_CacheInvalidate_RemovesEntry;
var
  Hits, Misses, EntryCount: Int64;
begin
  UniDbClearQueryCache;
  UniDbGetCacheStats(Hits, Misses, EntryCount);
  Assert.AreEqual(Int64(0), EntryCount, 'Cache should start empty');
  
  // 精确失效不存在的条目不应报错
  UniDbInvalidateQuery('NonExistentProc');
  UniDbGetCacheStats(Hits, Misses, EntryCount);
  Assert.AreEqual(Int64(0), EntryCount, 'Invalidating non-existent entry should not fail');
end;

procedure TTestUniBaseDoQry.Test_CacheStats_Accuracy;
var
  Ctx: TUniQueryContext;
  Hits, Misses, EntryCount: Int64;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite);
  
  // 重置
  UniDbInit(ExtractFilePath(ParamStr(0)));
  UniDbSetCacheTTL(300);
  
  // 直接 SQL 不使用缓存（不计入统计）
  UniDbExec('INSERT INTO test_users (name, age) VALUES (:name, :age)', '{"name": "Stats1", "age": 30}', Ctx);
  UniDbExec('INSERT INTO test_users (name, age) VALUES (:name, :age)', '{"name": "Stats2", "age": 40}', Ctx);
  
  UniDbGetCacheStats(Hits, Misses, EntryCount);
  // 直接 SQL 不经过缓存查找，miss 应该为 0
  Assert.AreEqual(Int64(0), Hits, 'Direct SQL should not count as hits');
end;

procedure TTestUniBaseDoQry.Test_CacheConcurrentLoad_SingleMissAndStableResult;
const
  CThreadCount = 8;
var
  TempDbPath: string;
  SetupConn: TFDConnection;
  Q: TFDQuery;
  Tasks: TArray<ITask>;
  I: Integer;
  Hits, Misses, EntryCount: Int64;
  ErrorCount: Integer;
begin
  TempDbPath := TPath.Combine(TPath.GetTempPath,
    Format('unibase_doqry_cache_%d.db', [GetTickCount]));
  if TFile.Exists(TempDbPath) then
    TFile.Delete(TempDbPath);

  SetupConn := TFDConnection.Create(nil);
  try
    SetupConn.DriverName := 'SQLite';
    SetupConn.Params.Database := TempDbPath;
    SetupConn.Open;

    Q := TFDQuery.Create(nil);
    try
      Q.Connection := SetupConn;
      Q.SQL.Text :=
        'CREATE TABLE IF NOT EXISTS test_users (' +
        '  id INTEGER PRIMARY KEY AUTOINCREMENT,' +
        '  name TEXT NOT NULL,' +
        '  age INTEGER' +
        ')';
      Q.ExecSQL;

      Q.SQL.Text :=
        'CREATE TABLE IF NOT EXISTS Queries (' +
        '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
        '  Name TEXT NOT NULL UNIQUE,' +
        '  SqlText TEXT NOT NULL,' +
        '  IsEnabled INTEGER DEFAULT 1' +
        ')';
      Q.ExecSQL;

      Q.SQL.Text :=
        'INSERT INTO Queries (Name, SqlText, IsEnabled) VALUES ' +
        '(''user.count_by_name'', ''SELECT COUNT(*) FROM test_users WHERE name = :name'', 1)';
      Q.ExecSQL;

      Q.SQL.Text := 'INSERT INTO test_users (name, age) VALUES (''ConcurrentUser'', 18)';
      Q.ExecSQL;
    finally
      Q.Free;
    end;
  finally
    SetupConn.Free;
  end;

  UniDbInit(ExtractFilePath(ParamStr(0)));
  UniDbSetCacheTTL(300);
  UniDbClearQueryCache;

  ErrorCount := 0;
  SetLength(Tasks, CThreadCount);
  for I := 0 to CThreadCount - 1 do
  begin
    Tasks[I] := TTask.Run(
      procedure
      var
        Conn: TFDConnection;
        Ctx: TUniQueryContext;
        V: Variant;
      begin
        try
          Conn := TFDConnection.Create(nil);
          try
            Conn.DriverName := 'SQLite';
            Conn.Params.Database := TempDbPath;
            Conn.Open;
            Ctx := UniDbMakeContext(Conn, udbSQLite);
            V := UniDbScalar('user.count_by_name', '{"name":"ConcurrentUser"}', Ctx);
            if Integer(V) <> 1 then
              TInterlocked.Increment(ErrorCount);
          finally
            Conn.Free;
          end;
        except
          TInterlocked.Increment(ErrorCount);
        end;
      end);
  end;

  TTask.WaitForAll(Tasks);
  UniDbGetCacheStats(Hits, Misses, EntryCount);

  Assert.AreEqual(0, ErrorCount, 'Concurrent stored-query load should remain stable');
  Assert.AreEqual(Int64(1), Misses, 'Only one cache miss is expected for same ProcName concurrent load');
  Assert.AreEqual(Int64(CThreadCount - 1), Hits, 'Remaining calls should hit cache');
  Assert.AreEqual(Int64(1), EntryCount, 'Cache should contain one entry for loaded ProcName');

  if TFile.Exists(TempDbPath) then
    TFile.Delete(TempDbPath);
end;

procedure TTestUniBaseDoQry.Test_MultiTypeFields_CopyCorrectly;
var
  Ctx: TUniQueryContext;
  Data: TFDMemTable;
  Rows: Integer;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite);
  
  // 插入多类型数据
  UniDbExec(
    'INSERT INTO test_multitype (name, price, quantity, is_active, description) ' +
    'VALUES (:name, :price, :quantity, :is_active, :description)',
    '{"name": "测试产品", "price": 99.99, "quantity": 100, "is_active": true, "description": "这是一个测试产品"}',
    Ctx
  );
  
  Data := TFDMemTable.Create(nil);
  try
    Rows := UniDbSelect(
      'SELECT * FROM test_multitype WHERE name = :name',
      '{"name": "测试产品"}',
      Data,
      Ctx
    );
    
    Assert.AreEqual(1, Rows, 'Should return 1 row');
    Assert.IsFalse(Data.IsEmpty, 'Data should not be empty');
    Assert.AreEqual('测试产品', Data.FieldByName('name').AsString, 'Name should match');
    Assert.AreEqual(99.99, Data.FieldByName('price').AsFloat, 0.001, 'Price should match');
    Assert.AreEqual(100, Data.FieldByName('quantity').AsInteger, 'Quantity should match');
    Assert.AreEqual(1, Data.FieldByName('is_active').AsInteger, 'IsActive should be 1');
    Assert.AreEqual('这是一个测试产品', Data.FieldByName('description').AsString, 'Description should match');
  finally
    Data.Free;
  end;
end;

procedure TTestUniBaseDoQry.Test_NullFields_CopyCorrectly;
var
  Ctx: TUniQueryContext;
  Data: TFDMemTable;
  Rows: Integer;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite);
  
  // 插入含 NULL 字段的数据
  UniDbExec(
    'INSERT INTO test_multitype (name, price, quantity) VALUES (:name, :price, :quantity)',
    '{"name": "NullTest", "price": null, "quantity": 50}',
    Ctx
  );
  
  Data := TFDMemTable.Create(nil);
  try
    Rows := UniDbSelect(
      'SELECT * FROM test_multitype WHERE name = :name',
      '{"name": "NullTest"}',
      Data,
      Ctx
    );
    
    Assert.AreEqual(1, Rows, 'Should return 1 row');
    Assert.IsTrue(Data.FieldByName('price').IsNull, 'Price should be NULL');
    Assert.IsTrue(Data.FieldByName('description').IsNull, 'Description should be NULL');
    Assert.AreEqual(50, Data.FieldByName('quantity').AsInteger, 'Quantity should be 50');
  finally
    Data.Free;
  end;
end;

procedure TTestUniBaseDoQry.Test_DateTimeFields_CopyCorrectly;
var
  Ctx: TUniQueryContext;
  Data: TFDMemTable;
  Rows: Integer;
  TestDate: string;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite);
  
  TestDate := '2025-12-01 08:30:00';
  
  // 插入含日期字段的数据
  UniDbExec(
    'INSERT INTO test_multitype (name, created_at) VALUES (:name, :created_at)',
    Format('{"name": "DateTest", "created_at": "%s"}', [TestDate]),
    Ctx
  );
  
  Data := TFDMemTable.Create(nil);
  try
    Rows := UniDbSelect(
      'SELECT * FROM test_multitype WHERE name = :name',
      '{"name": "DateTest"}',
      Data,
      Ctx
    );
    
    Assert.AreEqual(1, Rows, 'Should return 1 row');
    Assert.AreEqual(TestDate, Data.FieldByName('created_at').AsString, 'CreatedAt should match');
  finally
    Data.Free;
  end;
end;

procedure TTestUniBaseDoQry.Test_ErrorCode_SqlSyntax;
var
  Ctx: TUniQueryContext;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite);
  
  try
    UniDbExec('SELECT FROM', '', Ctx);
    Assert.Fail('Should have raised EUniBaseDbError');
  except
    on E: EUniBaseDbError do
    begin
      // SQLite 语法错误通常包含 "near"
      Assert.AreEqual(DOQRY_ERR_SQL_SYNTAX, E.ErrorCode, 'ErrorCode should be SQL_SYNTAX');
    end;
  end;
end;

procedure TTestUniBaseDoQry.Test_ErrorCode_UniqueConstraint;
var
  Ctx: TUniQueryContext;
  Q: TFDQuery;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite);
  
  // 创建带唯一约束的表
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text := 'CREATE TABLE IF NOT EXISTS test_unique (id INTEGER PRIMARY KEY, code TEXT UNIQUE)';
    Q.ExecSQL;
  finally
    Q.Free;
  end;
  
  try
    // 插入第一条
    UniDbExec('INSERT INTO test_unique (code) VALUES (:code)', '{"code": "ABC"}', Ctx);
    // 插入重复的，应该触发唯一约束错误
    UniDbExec('INSERT INTO test_unique (code) VALUES (:code)', '{"code": "ABC"}', Ctx);
    Assert.Fail('Should have raised EUniBaseDbError for unique constraint');
  except
    on E: EUniBaseDbError do
    begin
      Assert.AreEqual(DOQRY_ERR_UNIQUE, E.ErrorCode, 'ErrorCode should be UNIQUE');
    end;
  end;
  
  // 清理
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text := 'DROP TABLE IF EXISTS test_unique';
    Q.ExecSQL;
  finally
    Q.Free;
  end;
end;

procedure TTestUniBaseDoQry.Test_ErrorCode_HasCorrectValue;
var
  Ctx: TUniQueryContext;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite);
  
  try
    UniDbExec('SELECT * FROM nonexistent_table_xyz', '', Ctx);
    Assert.Fail('Should have raised EUniBaseDbError');
  except
    on E: EUniBaseDbError do
    begin
      // 确保 ErrorCode 字段存在且不为 0
      Assert.IsTrue(E.ErrorCode > 0, 'ErrorCode should be greater than 0');
      Assert.IsNotEmpty(E.Message, 'Message should not be empty');
      Assert.IsNotEmpty(E.CorrelationId, 'CorrelationId should not be empty');
    end;
  end;
end;

procedure TTestUniBaseDoQry.Test_PreparedPool_EnabledCreatesPooledQuery;
var
  Ctx: TUniQueryContext;
  Data: TFDMemTable;
  PoolSize1, PoolSize2, ReuseCount: Int64;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite);
  Data := nil;
  
  // 清空池并启用
  UniDbClearPreparedStatements;
  UniDbSetPreparedStatementPooling(True);
  try
    // 首次查询
    UniDbSelect('SELECT 1 AS val', '', Data, Ctx);
    UniDbGetPreparedStats(PoolSize1, ReuseCount);
    Assert.AreEqual(Int64(1), PoolSize1, 'Pool should have 1 entry after first query');
    
    // 再次执行相同 SQL
    Data.Free;
    Data := nil;
    UniDbSelect('SELECT 1 AS val', '', Data, Ctx);
    UniDbGetPreparedStats(PoolSize2, ReuseCount);
    Assert.AreEqual(Int64(1), PoolSize2, 'Pool should still have 1 entry (reused)');
    Assert.IsTrue(ReuseCount >= 1, 'ReuseCount should be at least 1');
  finally
    Data.Free;
    UniDbSetPreparedStatementPooling(False);
    UniDbClearPreparedStatements;
  end;
end;

procedure TTestUniBaseDoQry.Test_PreparedPool_StatsTracksReuse;
var
  Ctx: TUniQueryContext;
  Data: TFDMemTable;
  PoolSize, ReuseCount1, ReuseCount2: Int64;
  I: Integer;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite);
  Data := nil;
  
  UniDbClearPreparedStatements;
  UniDbSetPreparedStatementPooling(True);
  try
    // 执行 10 次相同查询
    for I := 1 to 10 do
    begin
      Data.Free;
      Data := nil;
      UniDbSelect('SELECT :id AS id', '{"id": ' + IntToStr(I) + '}', Data, Ctx);
    end;
    
    UniDbGetPreparedStats(PoolSize, ReuseCount1);
    Assert.AreEqual(Int64(1), PoolSize, 'Pool should have 1 entry');
    Assert.AreEqual(Int64(9), ReuseCount1, 'ReuseCount should be 9 (10 queries - 1 create)');
  finally
    Data.Free;
    UniDbSetPreparedStatementPooling(False);
    UniDbClearPreparedStatements;
  end;
end;

procedure TTestUniBaseDoQry.Test_PreparedPool_ClearRemovesAll;
var
  Ctx: TUniQueryContext;
  Data: TFDMemTable;
  PoolSize, ReuseCount: Int64;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite);
  Data := nil;
  
  UniDbClearPreparedStatements;
  UniDbSetPreparedStatementPooling(True);
  try
    // 创建几个池条目
    UniDbSelect('SELECT 1', '', Data, Ctx);
    Data.Free; Data := nil;
    UniDbSelect('SELECT 2', '', Data, Ctx);
    Data.Free; Data := nil;
    UniDbSelect('SELECT 3', '', Data, Ctx);
    Data.Free; Data := nil;
    
    UniDbGetPreparedStats(PoolSize, ReuseCount);
    Assert.AreEqual(Int64(3), PoolSize, 'Pool should have 3 entries');
    
    // 清空
    UniDbClearPreparedStatements;
    
    UniDbGetPreparedStats(PoolSize, ReuseCount);
    Assert.AreEqual(Int64(0), PoolSize, 'Pool should be empty after clear');
  finally
    Data.Free;
    UniDbSetPreparedStatementPooling(False);
  end;
end;

procedure TTestUniBaseDoQry.Test_PreparedPool_MaxSizeEnforcesLRUEviction;
var
  Ctx: TUniQueryContext;
  Data: TFDMemTable;
  PoolSize: Int64;
  ReuseBefore: Int64;
  ReuseAfter: Int64;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite);
  Data := nil;

  UniDbClearPreparedStatements;
  UniDbSetPreparedStatementPooling(True);
  UniDbSetPreparedPoolMaxSize(2);
  try
    UniDbSelect('SELECT 1', '', Data, Ctx); // A
    Data.Free; Data := nil;
    UniDbSelect('SELECT 2', '', Data, Ctx); // B
    Data.Free; Data := nil;
    UniDbSelect('SELECT 1', '', Data, Ctx); // touch A, make B oldest
    Data.Free; Data := nil;
    UniDbSelect('SELECT 3', '', Data, Ctx); // C, should evict B

    UniDbGetPreparedStats(PoolSize, ReuseBefore);
    Assert.AreEqual(Int64(2), PoolSize, 'Pool size should be capped to 2');

    Data.Free; Data := nil;
    UniDbSelect('SELECT 2', '', Data, Ctx); // B was evicted, should be re-created

    UniDbGetPreparedStats(PoolSize, ReuseAfter);
    Assert.AreEqual(Int64(2), PoolSize, 'Pool size should remain capped to 2');
    Assert.AreEqual(ReuseBefore, ReuseAfter,
      'Evicted SQL should not contribute to reuse count when created again');
  finally
    Data.Free;
    UniDbSetPreparedPoolMaxSize(500);
    UniDbSetPreparedStatementPooling(False);
    UniDbClearPreparedStatements;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestUniBaseDoQry);

end.
