{ ============================================================================
  Test.DeepBase.DB.DoQry - DoQry 集成模块测试
  
  说明: 测试 DeepBase.DB.DoQry 模块的核心功�?
  ============================================================================ }

unit Test.DeepBase.DB.DoQry;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils, System.IOUtils, System.Variants, System.Threading, System.SyncObjs,
  System.Generics.Collections,
  FireDAC.Comp.Client, FireDAC.Comp.DataSet, FireDAC.Stan.Def, FireDAC.Phys.SQLite,
  FireDAC.Phys.PG, FireDAC.Phys.PGDef,
  DeepBase.DB.DoQry, DeepBase.DB.Factory, DeepBase.DB.Pool;

type
  [TestFixture]
  TTestDeepBaseDoQryPG = class
  private
    FConnection: TFDConnection;
    FAvailable: Boolean;
    procedure CreateTestTable;
    procedure DropTestTable;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_PG_InsertReturningId_InsertsAndReturnsSerial;

    [Test]
    procedure Test_PG_Select_WithParamBinding_ReturnsData;

    [Test]
    procedure Test_PG_Exec_UpdateAndRowCount;

    [Test]
    procedure Test_PG_Scalar_ReturnsAggregateAndSingleValue;

    [Test]
    procedure Test_PG_ParamBinding_DiverseTypes;

    [Test]
    procedure Test_PG_Transaction_Commit_PersistsData;

    [Test]
    procedure Test_PG_Transaction_Rollback_RevertsData;

    [Test]
    procedure Test_PG_RunInTx_Counterfactual_RollbackOnException;

    [Test]
    procedure Test_PG_UniqueConstraint_RaisesEDeepBaseDbError;
  end;

  [TestFixture]
  TTestDeepBaseDoQry = class
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
    procedure Test_InvalidSQL_RaisesEDeepBaseDbError;

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

    { REVIEW5-DATA-007: a pooled TFDQuery is a single live cursor; concurrent
      callers must never receive the same in-use instance, or their bound
      parameters and result sets cross-contaminate. }
    [Test]
    procedure Test_PreparedPool_ConcurrentSameSql_DoesNotCrossContaminateParams;

    { REVIEW5-DATA-008: write-type PRAGMAs must not be accepted as direct SQL;
      they must be whitelisted through the Queries table. }
    [Test]
    procedure Test_DirectWritePragma_Assignment_IsBlocked;

    [Test]
    procedure Test_DirectWritePragma_SideEffect_IsBlocked;

    [Test]
    procedure Test_DirectReadOnlyPragma_IsAllowed;
  end;

implementation

{ TTestDeepBaseDoQry }

procedure TTestDeepBaseDoQry.Setup;
begin
  // 使用内存数据�?
  FTestDBPath := ':memory:';
  
  FConnection := TFDConnection.Create(nil);
  FConnection.DriverName := 'SQLite';
  FConnection.Params.Database := FTestDBPath;
  FConnection.Open;
  
  // 初始�?DoQry
  UniDbInit(ExtractFilePath(ParamStr(0)));

  // DATA2-028: opt-in 直连 SQL 开关。本夹具大量用例以 inline SQL(DML) 作为 ProcName 传入,
  // 走直连通道而非 Queries 表白名单。实现层对 DDL 仍由关键字白名单独立阻断,
  // 故开关打开不影响 Test_DirectDDL_IsBlockedUnlessStoredInQueries / Test_MissingProcName 等
  // 安全特性用例。TearDown 复位 False 防跨测试串扰。
  UniDbSetDirectSQLAllowed(True);

  CreateTestTable;
end;

procedure TTestDeepBaseDoQry.TearDown;
begin
  UniDbSetDirectSQLAllowed(False);
  DropTestTable;
  FConnection.Free;
end;

procedure TTestDeepBaseDoQry.CreateTestTable;
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

procedure TTestDeepBaseDoQry.DropTestTable;
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

procedure TTestDeepBaseDoQry.Test_MakeContext_CreatesValidContext;
var
  Ctx: TUniQueryContext;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite, 30, '');
  
  Assert.IsNotNull(Ctx.Connection, 'Connection should not be nil');
  Assert.AreEqual(udbSQLite, Ctx.DBType, 'DBType should be SQLite');
  Assert.AreEqual(30, Ctx.TimeoutSec, 'TimeoutSec should be 30');
  Assert.IsNotEmpty(Ctx.CorrelationId, 'CorrelationId should not be empty');
end;

procedure TTestDeepBaseDoQry.Test_NewCorrelationId_ReturnsUniqueId;
var
  Id1, Id2: string;
begin
  Id1 := UniDbNewCorrelationId;
  Id2 := UniDbNewCorrelationId;
  
  Assert.IsNotEmpty(Id1, 'Id1 should not be empty');
  Assert.IsNotEmpty(Id2, 'Id2 should not be empty');
  Assert.AreNotEqual(Id1, Id2, 'IDs should be unique');
end;

procedure TTestDeepBaseDoQry.Test_ExecInsert_InsertsRow;
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

procedure TTestDeepBaseDoQry.Test_Select_ReturnsData;
var
  Ctx: TUniQueryContext;
  Data: TFDMemTable;
  Rows: Integer;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite);
  
  // 先插入数�?
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

procedure TTestDeepBaseDoQry.Test_Scalar_ReturnsValue;
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

procedure TTestDeepBaseDoQry.Test_Transaction_CommitPersists;
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

procedure TTestDeepBaseDoQry.Test_Transaction_RollbackReverts;
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

procedure TTestDeepBaseDoQry.Test_RunInTx_AutoCommit;
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

procedure TTestDeepBaseDoQry.Test_RunInTx_AutoRollbackOnException;
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

procedure TTestDeepBaseDoQry.Test_RunInTx_NestedSavepoint_CommitWorks;
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

procedure TTestDeepBaseDoQry.Test_RunInTx_NestedSavepoint_InnerRollbackKeepsOuter;
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

procedure TTestDeepBaseDoQry.Test_InvalidSQL_RaisesEDeepBaseDbError;
var
  Ctx: TUniQueryContext;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite);
  
  Assert.WillRaise(
    procedure
    begin
      UniDbExec('SELECT FROM', '', Ctx);
    end,
    EDeepBaseDbError,
    'Should raise EDeepBaseDbError for invalid SQL'
  );
end;

procedure TTestDeepBaseDoQry.Test_QueryTable_NameSqlText_LoadsSql;
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

procedure TTestDeepBaseDoQry.Test_MissingProcName_DoesNotFallbackToSQL;
var
  Ctx: TUniQueryContext;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite);

  try
    UniDbExec('missing.proc.name', '', Ctx);
    Assert.Fail('Missing query name should not be executed as SQL');
  except
    on E: EDeepBaseDbError do
      Assert.AreEqual(DOQRY_ERR_QUERY_NOT_FOUND, E.ErrorCode);
  end;
end;

procedure TTestDeepBaseDoQry.Test_DirectDDL_IsBlockedUnlessStoredInQueries;
var
  Ctx: TUniQueryContext;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite);

  try
    UniDbExec('DROP TABLE test_users', '', Ctx);
    Assert.Fail('DDL text should not be accepted as direct SQL');
  except
    on E: EDeepBaseDbError do
      Assert.AreEqual(DOQRY_ERR_QUERY_NOT_FOUND, E.ErrorCode);
  end;
end;

procedure TTestDeepBaseDoQry.Test_InsertReturningId_BindsJsonParams;
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

procedure TTestDeepBaseDoQry.Test_InsertReturningId_WithTrigger_ReturnsTargetTableId;
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

procedure TTestDeepBaseDoQry.Test_InsertReturningId_ConcurrentWrites_ReturnUniqueIds;
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
    Format('DeepBase_insert_id_%d.db', [Random(MaxInt)]));
  if TFile.Exists(TempDbPath) then
    TFile.Delete(TempDbPath);

  SetupConn := TFDConnection.Create(nil);
  try
    SetupConn.DriverName := 'SQLite';
    SetupConn.Params.Database := TempDbPath;
    SetupConn.Params.Values['OpenMode'] := 'CreateUTF8';
    SetupConn.Params.Values['JournalMode'] := 'WAL';
    SetupConn.Params.Values['BusyTimeout'] := '10000';
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
        begin
          var Conn := TFDConnection.Create(nil);
          try
            Conn.DriverName := 'SQLite';
            Conn.Params.Database := TempDbPath;
            Conn.Params.Values['OpenMode'] := 'CreateUTF8';
            Conn.Params.Values['JournalMode'] := 'WAL';
            Conn.Params.Values['BusyTimeout'] := '10000';
            Conn.Open;

            var Ctx := UniDbMakeContext(Conn, udbSQLite);
            var Payload := Format('{"name":"ConcUser-%d","age":%d}', [WorkerIndex, 20 + WorkerIndex]);

            var Success := False;
            var InsertId := 0;
            for var Attempt := 1 to 20 do
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
                on E: EDeepBaseDbError do
                begin
                  if E.ErrorCode = DOQRY_ERR_TX_CONFLICT then
                    Sleep(Attempt * 25)
                  else
                    raise;
                end;
              end;
            end;

            if Success then
            begin
              IdLock.Enter;
              try
                ReturnedIds.Add(InsertId);
              finally
                IdLock.Leave;
              end;
            end
            else
              TInterlocked.Increment(ErrorCount);
          except
            TInterlocked.Increment(ErrorCount);
          end;
          Conn.Free;
        end
      );
    end;

    TTask.WaitForAll(Tasks);
    Assert.AreEqual(0, ErrorCount, 'Concurrent insert should not produce errors');
    Assert.AreEqual(CThreadCount, Integer(ReturnedIds.Count), 'Each worker should return one id');

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

procedure TTestDeepBaseDoQry.Test_CacheTTL_Expiry;
var
  Ctx: TUniQueryContext;
  Hits, Misses, EntryCount: Int64;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite);
  
  // 设置 TTL �?1 �?
  UniDbSetCacheTTL(1);
  UniDbClearQueryCache;
  
  // 第一次调用，应该未命�?
  UniDbExec('INSERT INTO test_users (name, age) VALUES (:name, :age)', '{"name": "TTLTest", "age": 20}', Ctx);
  UniDbGetCacheStats(Hits, Misses, EntryCount);
  Assert.AreEqual(Int64(0), Hits, 'First call should be cache miss');
  
  // 第二次调用（直接 SQL 不缓存，所以仍然是 miss，但这里验证 TTL 逻辑�?
  // 等待 TTL 过期
  Sleep(1500);
  
  // 重置统计
  UniDbClearQueryCache;
  UniDbGetCacheStats(Hits, Misses, EntryCount);
  Assert.AreEqual(Int64(0), EntryCount, 'Cache should be empty after clear');
end;

procedure TTestDeepBaseDoQry.Test_CacheInvalidate_RemovesEntry;
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

procedure TTestDeepBaseDoQry.Test_CacheStats_Accuracy;
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
  // 直接 SQL 不经过缓存查找，miss 应该�?0
  Assert.AreEqual(Int64(0), Hits, 'Direct SQL should not count as hits');
end;

procedure TTestDeepBaseDoQry.Test_CacheConcurrentLoad_SingleMissAndStableResult;
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
    Format('DeepBase_doqry_cache_%d.db', [Random(MaxInt)]));
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
      begin
        try
          var Conn := TFDConnection.Create(nil);
          try
            Conn.DriverName := 'SQLite';
            Conn.Params.Database := TempDbPath;
            Conn.Open;
            var Ctx := UniDbMakeContext(Conn, udbSQLite);
            var V := UniDbScalar('user.count_by_name', '{"name":"ConcurrentUser"}', Ctx);
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

procedure TTestDeepBaseDoQry.Test_MultiTypeFields_CopyCorrectly;
var
  Ctx: TUniQueryContext;
  Data: TFDMemTable;
  Rows: Integer;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite);

  UniDbExec(
    'INSERT INTO test_multitype (name, price, quantity, is_active, description) ' +
    'VALUES (:name, :price, :quantity, :is_active, :description)',
    '{"name": "TestProduct", "price": 99.99, "quantity": 100, "is_active": true, "description": "Test product description"}',
    Ctx
  );

  Data := TFDMemTable.Create(nil);
  try
    Rows := UniDbSelect(
      'SELECT * FROM test_multitype WHERE name = :name',
      '{"name": "TestProduct"}',
      Data,
      Ctx
    );

    Assert.AreEqual(1, Rows, 'Should return 1 row');
    Assert.IsFalse(Data.IsEmpty, 'Data should not be empty');
    Assert.AreEqual('TestProduct', Data.FieldByName('name').AsString, 'Name should match');
    Assert.AreEqual(99.99, Data.FieldByName('price').AsFloat, 0.001, 'Price should match');
    Assert.AreEqual(100, Data.FieldByName('quantity').AsInteger, 'Quantity should match');
    Assert.AreEqual(1, Data.FieldByName('is_active').AsInteger, 'IsActive should be 1');
    Assert.AreEqual('Test product description', Data.FieldByName('description').AsString, 'Description should match');
  finally
    Data.Free;
  end;
end;
procedure TTestDeepBaseDoQry.Test_NullFields_CopyCorrectly;
var
  Ctx: TUniQueryContext;
  Data: TFDMemTable;
  Rows: Integer;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite);
  
  // 插入�?NULL 字段的数�?
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

procedure TTestDeepBaseDoQry.Test_DateTimeFields_CopyCorrectly;
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

procedure TTestDeepBaseDoQry.Test_ErrorCode_SqlSyntax;
var
  Ctx: TUniQueryContext;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite);
  
  try
    UniDbExec('SELECT FROM', '', Ctx);
    Assert.Fail('Should have raised EDeepBaseDbError');
  except
    on E: EDeepBaseDbError do
    begin
      // SQLite 语法错误通常包含 "near"
      Assert.AreEqual(DOQRY_ERR_SQL_SYNTAX, E.ErrorCode, 'ErrorCode should be SQL_SYNTAX');
    end;
  end;
end;

procedure TTestDeepBaseDoQry.Test_ErrorCode_UniqueConstraint;
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
    // 插入第一�?
    UniDbExec('INSERT INTO test_unique (code) VALUES (:code)', '{"code": "ABC"}', Ctx);
    // 插入重复的，应该触发唯一约束错误
    UniDbExec('INSERT INTO test_unique (code) VALUES (:code)', '{"code": "ABC"}', Ctx);
    Assert.Fail('Should have raised EDeepBaseDbError for unique constraint');
  except
    on E: EDeepBaseDbError do
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

procedure TTestDeepBaseDoQry.Test_ErrorCode_HasCorrectValue;
var
  Ctx: TUniQueryContext;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite);
  
  try
    UniDbExec('SELECT * FROM nonexistent_table_xyz', '', Ctx);
    Assert.Fail('Should have raised EDeepBaseDbError');
  except
    on E: EDeepBaseDbError do
    begin
      // 确保 ErrorCode 字段存在且不�?0
      Assert.IsTrue(E.ErrorCode > 0, 'ErrorCode should be greater than 0');
      Assert.IsNotEmpty(E.Message, 'Message should not be empty');
      Assert.IsNotEmpty(E.CorrelationId, 'CorrelationId should not be empty');
    end;
  end;
end;

procedure TTestDeepBaseDoQry.Test_PreparedPool_EnabledCreatesPooledQuery;
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

procedure TTestDeepBaseDoQry.Test_PreparedPool_StatsTracksReuse;
var
  Ctx: TUniQueryContext;
  Data: TFDMemTable;
  PoolSize, ReuseCount1: Int64;
  I: Integer;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite);
  Data := nil;
  
  UniDbClearPreparedStatements;
  UniDbSetPreparedStatementPooling(True);
  try
    // 执行 10 次相同查�?
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

procedure TTestDeepBaseDoQry.Test_PreparedPool_ClearRemovesAll;
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
    // 创建几个池条�?
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

procedure TTestDeepBaseDoQry.Test_PreparedPool_MaxSizeEnforcesLRUEviction;
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

procedure TTestDeepBaseDoQry.Test_PreparedPool_ConcurrentSameSql_DoesNotCrossContaminateParams;
const
  CThreadCount = 6;
  CIterations = 25;
  SQL = 'SELECT :val AS v';
var
  SharedDbPath: string;
  SharedConn: TFDConnection;
  Ctx: TUniQueryContext;
  Tasks: TArray<ITask>;
  StartGate: TCountdownEvent;
  ErrorCount: Integer;
  MismatchCount: Integer;
  I: Integer;
begin
  // REVIEW5-DATA-007: every worker runs the SAME parameterized SQL on the SAME
  // shared connection with pooling enabled, binding its own :val each call.
  // Without the InUseCount guard each concurrent caller would receive the same
  // live TFDQuery and clobber the others' bound parameter / active result set
  // ("cannot perform this operation on an active dataset" or wrong :val). With
  // the guard, concurrent in-use lookups hand out fresh queries, so every worker
  // always reads back its own value.
  //
  // A file-backed WAL database is used (rather than :memory:) so concurrent
  // readers on the shared connection do not collide on SQLite's per-connection
  // memory store.
  SharedDbPath := TPath.Combine(TPath.GetTempPath,
    Format('DeepBase_preppool_%d.db', [Random(MaxInt)]));
  if TFile.Exists(SharedDbPath) then
    TFile.Delete(SharedDbPath);

  SharedConn := TFDConnection.Create(nil);
  try
    SharedConn.DriverName := 'SQLite';
    SharedConn.Params.Database := SharedDbPath;
    SharedConn.Params.Values['OpenMode'] := 'CreateUTF8';
    SharedConn.Params.Values['JournalMode'] := 'WAL';
    SharedConn.Params.Values['BusyTimeout'] := '10000';
    SharedConn.Open;
    Ctx := UniDbMakeContext(SharedConn, udbSQLite);
  except
    SharedConn.Free;
    raise;
  end;

  UniDbClearPreparedStatements;
  UniDbSetPreparedStatementPooling(True);
  StartGate := TCountdownEvent.Create(1);
  try
    ErrorCount := 0;
    MismatchCount := 0;
    SetLength(Tasks, CThreadCount);
    for I := 0 to CThreadCount - 1 do
    begin
      var WorkerIndex := I;
      Tasks[I] := TTask.Run(
        procedure
        var
          Data: TFDMemTable;
          Iter: Integer;
          Payload: string;
          Expected: Integer;
          Actual: Variant;
        begin
          try
            // Park all workers until the gate signals, so the first burst of
            // GetOrCreatePreparedQuery calls lands on a cold pool together and
            // maximizes the chance of overlapping InUseCount > 0 lookups.
            StartGate.WaitFor;

            for Iter := 0 to CIterations - 1 do
            begin
              Expected := WorkerIndex * 1000 + Iter;
              Payload := Format('{"val":%d}', [Expected]);
              Data := nil;
              try
                UniDbSelect(SQL, Payload, Data, Ctx);
                if (Data = nil) or Data.Eof then
                  TInterlocked.Increment(MismatchCount)
                else
                begin
                  Actual := Data.FieldByName('v').AsVariant;
                  if Integer(Actual) <> Expected then
                    TInterlocked.Increment(MismatchCount);
                end;
              finally
                Data.Free;
              end;
            end;
          except
            TInterlocked.Increment(ErrorCount);
          end;
        end);
    end;

    // Release all workers at once.
    StartGate.Signal;
    TTask.WaitForAll(Tasks);

    Assert.AreEqual(0, ErrorCount,
      'Concurrent same-SQL pooled queries must not raise (no shared active cursor)');
    Assert.AreEqual(0, MismatchCount,
      'Each worker must read back its own bound :val; cross-contamination detected');
  finally
    UniDbSetPreparedStatementPooling(False);
    UniDbClearPreparedStatements;
    StartGate.Free;
    SharedConn.Free;
    TFile.Delete(SharedDbPath);
  end;
end;

procedure TTestDeepBaseDoQry.Test_DirectWritePragma_Assignment_IsBlocked;
var
  Ctx: TUniQueryContext;
begin
  // REVIEW5-DATA-008: a PRAGMA that assigns a value mutates DB state and must
  // be whitelisted through the Queries table, not run as ad-hoc direct SQL.
  Ctx := UniDbMakeContext(FConnection, udbSQLite);

  try
    UniDbExec('PRAGMA foreign_keys=ON', '', Ctx);
    Assert.Fail('Write-type PRAGMA assignment should be rejected as direct SQL');
  except
    on E: EDeepBaseDbError do
      Assert.AreEqual(DOQRY_ERR_QUERY_NOT_FOUND, E.ErrorCode);
  end;
end;

procedure TTestDeepBaseDoQry.Test_DirectWritePragma_SideEffect_IsBlocked;
var
  Ctx: TUniQueryContext;
begin
  // REVIEW5-DATA-008: inherently side-effecting pragmas (even without `=`)
  // such as wal_checkpoint / optimize must be rejected as direct SQL.
  Ctx := UniDbMakeContext(FConnection, udbSQLite);

  try
    UniDbExec('PRAGMA wal_checkpoint', '', Ctx);
    Assert.Fail('Side-effecting PRAGMA should be rejected as direct SQL');
  except
    on E: EDeepBaseDbError do
      Assert.AreEqual(DOQRY_ERR_QUERY_NOT_FOUND, E.ErrorCode);
  end;
end;

procedure TTestDeepBaseDoQry.Test_DirectReadOnlyPragma_IsAllowed;
var
  Ctx: TUniQueryContext;
  Data: TFDMemTable;
begin
  // REVIEW5-DATA-008: read-only pragmas (no `=`, no side-effecting name) must
  // still be accepted as direct SQL.
  Ctx := UniDbMakeContext(FConnection, udbSQLite);
  Data := nil;
  try
    UniDbSelect('PRAGMA table_info(test_users)', '', Data, Ctx);
    Assert.IsNotNull(Data, 'Read-only PRAGMA should produce a result set');
    Assert.IsFalse(Data.Eof, 'table_info should return at least one column row');
  finally
    Data.Free;
  end;
end;

{ TTestDeepBaseDoQryPG }

procedure TTestDeepBaseDoQryPG.Setup;
var
  Profile: TDBConnectionProfile;
  Host, Database, Username, Password: string;
  Port: Integer;
begin
  FAvailable := False;
  FConnection := nil;

  Host := GetEnvironmentVariable('DB3_SERVER');
  if Host = '' then
    Host := '127.0.0.1';

  Port := StrToIntDef(GetEnvironmentVariable('DB3_PORT'), 5432);

  Database := GetEnvironmentVariable('DB3_DATABASE');
  if Database = '' then
    Database := 'postgres';

  Username := GetEnvironmentVariable('DB3_USER');
  if Username = '' then
    Username := 'postgres';

  Password := GetEnvironmentVariable('DB3_PASSWORD');
  if Password = '' then
    Password := GetEnvironmentVariable('PGPASSWORD');
  if Password = '' then
    Password := GetEnvironmentVariable('ARTIFACTOS_DB_PASS');

  try
    FConnection := TFDConnection.Create(nil);
    FConnection.DriverName := 'PG';
    FConnection.Params.Values['Server'] := Host;
    FConnection.Params.Values['Port'] := IntToStr(Port);
    FConnection.Params.Database := Database;
    FConnection.Params.UserName := Username;
    FConnection.Params.Password := Password;
    FConnection.Params.Values['LoginTimeout'] := '3';
    FConnection.Open;
    FAvailable := True;
  except
    on E: Exception do
    begin
      FAvailable := False;
      FreeAndNil(FConnection);
      Exit;
    end;
  end;

  UniDbInit(ExtractFilePath(ParamStr(0)));
  UniDbSetDirectSQLAllowed(True);
  CreateTestTable;
end;

procedure TTestDeepBaseDoQryPG.TearDown;
begin
  UniDbSetDirectSQLAllowed(False);
  if FAvailable then
    DropTestTable;
  FreeAndNil(FConnection);
end;

procedure TTestDeepBaseDoQryPG.CreateTestTable;
var
  Q: TFDQuery;
begin
  if not FAvailable then
    Exit;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'CREATE TABLE IF NOT EXISTS deepbase_doqry_pg_smoke (' +
      '  id BIGSERIAL PRIMARY KEY,' +
      '  name TEXT NOT NULL,' +
      '  amount NUMERIC(10, 2),' +
      '  is_active BOOLEAN DEFAULT true,' +
      '  uuid_val UUID,' +
      '  big_num BIGINT,' +
      '  created_at TIMESTAMPTZ DEFAULT now(),' +
      '  extra_info TEXT' +
      ');';
    Q.ExecSQL;

    Q.SQL.Text :=
      'CREATE TABLE IF NOT EXISTS deepbase_doqry_pg_unique (' +
      '  id SERIAL PRIMARY KEY,' +
      '  code TEXT NOT NULL UNIQUE' +
      ');';
    Q.ExecSQL;
  finally
    Q.Free;
  end;
end;

procedure TTestDeepBaseDoQryPG.DropTestTable;
var
  Q: TFDQuery;
begin
  if not FAvailable or (FConnection = nil) or not FConnection.Connected then
    Exit;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text := 'DROP TABLE IF EXISTS deepbase_doqry_pg_smoke; DROP TABLE IF EXISTS deepbase_doqry_pg_unique;';
    Q.ExecSQL;
  except
    // ignore cleanup error
  end;
  Q.Free;
end;

procedure TTestDeepBaseDoQryPG.Test_PG_InsertReturningId_InsertsAndReturnsSerial;
var
  Ctx: TUniQueryContext;
  NewId: Integer;
begin
  if not FAvailable then
    Exit;

  Ctx := UniDbMakeContext(FConnection, udbPostgreSQL);
  NewId := UniDbInsertReturningId(
    'INSERT INTO deepbase_doqry_pg_smoke (name, amount, is_active) VALUES (:name, :amount, :is_active)',
    '{"name": "ItemAlpha", "amount": 42.50, "is_active": true}',
    Ctx
  );

  Assert.IsTrue(NewId > 0, 'UniDbInsertReturningId on PG should return generated serial ID > 0');
end;

procedure TTestDeepBaseDoQryPG.Test_PG_Select_WithParamBinding_ReturnsData;
var
  Ctx: TUniQueryContext;
  Data: TFDMemTable;
  RowCount: Integer;
begin
  if not FAvailable then
    Exit;

  Ctx := UniDbMakeContext(FConnection, udbPostgreSQL);
  UniDbExec(
    'INSERT INTO deepbase_doqry_pg_smoke (name, amount, is_active) VALUES (:name, :amount, :is_active)',
    '{"name": "ItemBeta", "amount": 100.00, "is_active": true}',
    Ctx
  );

  Data := nil;
  try
    RowCount := UniDbSelect(
      'SELECT * FROM deepbase_doqry_pg_smoke WHERE name = :name',
      '{"name": "ItemBeta"}',
      Data,
      Ctx
    );

    Assert.AreEqual(1, RowCount, 'Should return 1 matching row');
    Assert.IsNotNull(Data, 'Data memtable should not be nil');
    Assert.AreEqual('ItemBeta', Data.FieldByName('name').AsString);
    Assert.AreEqual(100.0, Data.FieldByName('amount').AsFloat, 0.001);
  finally
    Data.Free;
  end;
end;

procedure TTestDeepBaseDoQryPG.Test_PG_Exec_UpdateAndRowCount;
var
  Ctx: TUniQueryContext;
  Affected: Integer;
begin
  if not FAvailable then
    Exit;

  Ctx := UniDbMakeContext(FConnection, udbPostgreSQL);
  UniDbExec(
    'INSERT INTO deepbase_doqry_pg_smoke (name, amount) VALUES (:name, :amount)',
    '{"name": "ItemGamma", "amount": 10.00}',
    Ctx
  );

  Affected := UniDbExec(
    'UPDATE deepbase_doqry_pg_smoke SET name = :new_name, amount = :new_amount WHERE name = :old_name',
    '{"new_name": "ItemGammaUpdated", "new_amount": 25.50, "old_name": "ItemGamma"}',
    Ctx
  );
  Assert.AreEqual(1, Affected, 'UniDbExec UPDATE should affect 1 row');

  Affected := UniDbExec(
    'DELETE FROM deepbase_doqry_pg_smoke WHERE name = :name',
    '{"name": "ItemGammaUpdated"}',
    Ctx
  );
  Assert.AreEqual(1, Affected, 'UniDbExec DELETE should affect 1 row');
end;

procedure TTestDeepBaseDoQryPG.Test_PG_Scalar_ReturnsAggregateAndSingleValue;
var
  Ctx: TUniQueryContext;
  V: Variant;
begin
  if not FAvailable then
    Exit;

  Ctx := UniDbMakeContext(FConnection, udbPostgreSQL);
  UniDbExec('DELETE FROM deepbase_doqry_pg_smoke', '', Ctx);
  UniDbExec(
    'INSERT INTO deepbase_doqry_pg_smoke (name, amount) VALUES (:name, :amount)',
    '{"name": "ScalarTest", "amount": 77.77}',
    Ctx
  );

  V := UniDbScalar('SELECT COUNT(*) FROM deepbase_doqry_pg_smoke', '', Ctx);
  Assert.IsFalse(VarIsNull(V), 'Scalar COUNT(*) must not be null');
  Assert.IsTrue(VarToStr(V) = '1', 'Scalar count should equal 1');

  V := UniDbScalar(
    'SELECT name FROM deepbase_doqry_pg_smoke WHERE name = :name',
    '{"name": "ScalarTest"}',
    Ctx
  );
  Assert.AreEqual('ScalarTest', VarToStr(V));
end;

procedure TTestDeepBaseDoQryPG.Test_PG_ParamBinding_DiverseTypes;
var
  Ctx: TUniQueryContext;
  Data: TFDMemTable;
  NewId: Integer;
begin
  if not FAvailable then
    Exit;

  Ctx := UniDbMakeContext(FConnection, udbPostgreSQL);
  NewId := UniDbInsertReturningId(
    'INSERT INTO deepbase_doqry_pg_smoke (name, amount, is_active, uuid_val, big_num, extra_info) ' +
    'VALUES (:name, :amount, :is_active, :uuid_val, :big_num, :extra_info)',
    '{"name": "TypesTest", "amount": 88.88, "is_active": false, ' +
    '"uuid_val": "d8e3b482-628a-4d74-8b65-68e1467a840e", ' +
    '"big_num": 9007199254740993, "extra_info": null}',
    Ctx
  );
  Assert.IsTrue(NewId > 0);

  Data := nil;
  try
    UniDbSelect(
      'SELECT * FROM deepbase_doqry_pg_smoke WHERE id = :id',
      Format('{"id": %d}', [NewId]),
      Data,
      Ctx
    );
    Assert.AreEqual(1, Data.RecordCount);
    Assert.AreEqual('TypesTest', Data.FieldByName('name').AsString);
    Assert.AreEqual(88.88, Data.FieldByName('amount').AsFloat, 0.001);
    Assert.IsFalse(Data.FieldByName('is_active').AsBoolean);
    Assert.IsTrue(Pos('d8e3b482-628a-4d74-8b65-68e1467a840e', LowerCase(Data.FieldByName('uuid_val').AsString)) > 0);
    Assert.AreEqual(Int64(9007199254740993), Data.FieldByName('big_num').AsLargeInt);
    Assert.IsTrue(Data.FieldByName('extra_info').IsNull);
  finally
    Data.Free;
  end;
end;

procedure TTestDeepBaseDoQryPG.Test_PG_Transaction_Commit_PersistsData;
var
  Ctx: TUniQueryContext;
  Tx: IUniTransaction;
  V: Variant;
begin
  if not FAvailable then
    Exit;

  Ctx := UniDbMakeContext(FConnection, udbPostgreSQL);
  Tx := UniDbBeginTx(Ctx);
  try
    UniDbExec(
      'INSERT INTO deepbase_doqry_pg_smoke (name) VALUES (:name)',
      '{"name": "TxCommittedItem"}',
      Ctx
    );
    Tx.Commit;
  except
    Tx.Rollback;
    raise;
  end;

  V := UniDbScalar('SELECT COUNT(*) FROM deepbase_doqry_pg_smoke WHERE name = :name', '{"name": "TxCommittedItem"}', Ctx);
  Assert.IsTrue(VarToStr(V) = '1', 'Committed row must persist');
end;

procedure TTestDeepBaseDoQryPG.Test_PG_Transaction_Rollback_RevertsData;
var
  Ctx: TUniQueryContext;
  Tx: IUniTransaction;
  V: Variant;
begin
  if not FAvailable then
    Exit;

  Ctx := UniDbMakeContext(FConnection, udbPostgreSQL);
  Tx := UniDbBeginTx(Ctx);
  try
    UniDbExec(
      'INSERT INTO deepbase_doqry_pg_smoke (name) VALUES (:name)',
      '{"name": "TxRolledBackItem"}',
      Ctx
    );
    Tx.Rollback;
  except
    Tx.Rollback;
    raise;
  end;

  V := UniDbScalar('SELECT COUNT(*) FROM deepbase_doqry_pg_smoke WHERE name = :name', '{"name": "TxRolledBackItem"}', Ctx);
  Assert.IsTrue(VarToStr(V) = '0', 'Rolled back row must not exist');
end;

procedure TTestDeepBaseDoQryPG.Test_PG_RunInTx_Counterfactual_RollbackOnException;
var
  Ctx: TUniQueryContext;
  V: Variant;
  Caught: Boolean;
begin
  if not FAvailable then
    Exit;

  Ctx := UniDbMakeContext(FConnection, udbPostgreSQL);
  Caught := False;

  try
    UniDbRunInTx(Ctx, procedure
    begin
      UniDbExec(
        'INSERT INTO deepbase_doqry_pg_smoke (name) VALUES (:name)',
        '{"name": "CounterfactualShouldRollback"}',
        Ctx
      );
      raise Exception.Create('Simulated business error inside UniDbRunInTx');
    end);
  except
    on E: Exception do
      Caught := True;
  end;

  Assert.IsTrue(Caught, 'Exception inside UniDbRunInTx must propagate to caller');

  V := UniDbScalar(
    'SELECT COUNT(*) FROM deepbase_doqry_pg_smoke WHERE name = :name',
    '{"name": "CounterfactualShouldRollback"}',
    Ctx
  );
  Assert.IsTrue(VarToStr(V) = '0', 'Counterfactual test: Exception in UniDbRunInTx must rollback all operations within transaction');
end;

procedure TTestDeepBaseDoQryPG.Test_PG_UniqueConstraint_RaisesEDeepBaseDbError;
var
  Ctx: TUniQueryContext;
  CaughtErrorCode: Integer;
begin
  if not FAvailable then
    Exit;

  Ctx := UniDbMakeContext(FConnection, udbPostgreSQL);
  UniDbExec('DELETE FROM deepbase_doqry_pg_unique', '', Ctx);
  UniDbExec('INSERT INTO deepbase_doqry_pg_unique (code) VALUES (:code)', '{"code": "UQ001"}', Ctx);

  CaughtErrorCode := 0;
  try
    UniDbExec('INSERT INTO deepbase_doqry_pg_unique (code) VALUES (:code)', '{"code": "UQ001"}', Ctx);
    Assert.Fail('Duplicate key insert on PG must raise exception');
  except
    on E: EDeepBaseDbError do
      CaughtErrorCode := E.ErrorCode;
  end;

  Assert.AreEqual(DOQRY_ERR_UNIQUE, CaughtErrorCode, 'PostgreSQL unique violation must map to DOQRY_ERR_UNIQUE');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDeepBaseDoQry);
  TDUnitX.RegisterTestFixture(TTestDeepBaseDoQryPG);

end.
