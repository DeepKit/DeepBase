{ ============================================================================
  Test.UniBase.DB.DoQry - DoQry 集成模块测试
  
  说明: 测试 UniBase.DB.DoQry 模块的核心功能
  ============================================================================ }

unit Test.UniBase.DB.DoQry;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils, System.IOUtils, System.Variants,
  FireDAC.Comp.Client, FireDAC.Stan.Def, FireDAC.Phys.SQLite,
  DBClient,
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
    procedure Test_InvalidSQL_RaisesEUniBaseDbError;
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
  Data: TClientDataSet;
  Rows: Integer;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite);
  
  // 先插入数据
  UniDbExec(
    'INSERT INTO test_users (name, age) VALUES (:name, :age)',
    '{"name": "Bob", "age": 25}',
    Ctx
  );
  
  Data := TClientDataSet.Create(nil);
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

procedure TTestUniBaseDoQry.Test_InvalidSQL_RaisesEUniBaseDbError;
var
  Ctx: TUniQueryContext;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite);
  
  Assert.WillRaise(
    procedure
    begin
      UniDbExec('INVALID SQL SYNTAX', '', Ctx);
    end,
    EUniBaseDbError,
    'Should raise EUniBaseDbError for invalid SQL'
  );
end;

initialization
  TDUnitX.RegisterTestFixture(TTestUniBaseDoQry);

end.
