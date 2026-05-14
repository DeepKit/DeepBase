unit Test.DeepBase.DB.Migrations;

interface

uses
  DUnitX.TestFramework,
  FireDAC.Comp.Client;

type
  [TestFixture]
  TTestDBMigrations = class
  private
    FTempDir: string;
    FMigrationsDir: string;
    FDBPath: string;
    FConnection: TFDConnection;
    function CreateConnection: TFDConnection;
    procedure WriteMigration(const FileName, SQLText: string);
    function ScalarInt(const SQLText: string): Integer;
    function TableExists(const TableName: string): Boolean;
  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Run_SQLite_AppliesOnlySQLiteScriptsAndCreatesBackup;

    [Test]
    procedure Test_Run_SQLite_IsIdempotentOnSecondRun;

    [Test]
    procedure Test_Run_SQLite_ChecksumMismatchFails;

    [Test]
    procedure Test_Run_SQLite_FailedScriptRollsBackAndIsNotRecorded;

    [Test]
    procedure Test_Run_SQLite_TriggerBodyIsNotSplit;

    [Test]
    procedure Test_Run_SQLite_TransactionControlFails;

    [Test]
    procedure Test_Run_SQLite_WriteLockHeldFailsBeforeApplying;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  FireDAC.Stan.Param,
  DeepBase.DB.Migrations,
  DeepBase.DB.Pool;

procedure TTestDBMigrations.Setup;
var
  GuidText: string;
begin
  GuidText := TGUID.NewGuid.ToString;
  GuidText := StringReplace(GuidText, '{', '', [rfReplaceAll]);
  GuidText := StringReplace(GuidText, '}', '', [rfReplaceAll]);
  FTempDir := TPath.Combine(TPath.GetTempPath, 'DeepBase_Migrations_' + GuidText);
  FMigrationsDir := TPath.Combine(FTempDir, 'migrations');
  TDirectory.CreateDirectory(FMigrationsDir);
  FDBPath := TPath.Combine(FTempDir, 'app.db');
  FConnection := CreateConnection;
end;

procedure TTestDBMigrations.TearDown;
begin
  FConnection.Free;
  if (FTempDir <> '') and TDirectory.Exists(FTempDir) then
    TDirectory.Delete(FTempDir, True);
end;

function TTestDBMigrations.CreateConnection: TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  try
    Result.DriverName := 'SQLite';
    Result.Params.Database := FDBPath;
    Result.Params.Values['OpenMode'] := 'CreateUTF8';
    Result.Params.Values['LockingMode'] := 'Normal';
    Result.LoginPrompt := False;
    Result.Open;
  except
    Result.Free;
    raise;
  end;
end;

procedure TTestDBMigrations.WriteMigration(const FileName, SQLText: string);
begin
  TFile.WriteAllText(TPath.Combine(FMigrationsDir, FileName), SQLText,
    TEncoding.UTF8);
end;

function TTestDBMigrations.ScalarInt(const SQLText: string): Integer;
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := SQLText;
    Query.Open;
    Result := Query.Fields[0].AsInteger;
  finally
    Query.Free;
  end;
end;

function TTestDBMigrations.TableExists(const TableName: string): Boolean;
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text :=
      'SELECT COUNT(*) FROM sqlite_master WHERE type = ''table'' AND name = :name';
    Query.ParamByName('name').AsString := TableName;
    Query.Open;
    Result := Query.Fields[0].AsInteger > 0;
  finally
    Query.Free;
  end;
end;

procedure TTestDBMigrations.Test_Run_SQLite_AppliesOnlySQLiteScriptsAndCreatesBackup;
var
  Result: TMigrationResult;
begin
  WriteMigration('001_create_widgets.up.sqlite.sql',
    'CREATE TABLE widgets (id INTEGER PRIMARY KEY, name TEXT);');
  WriteMigration('002_insert_widgets.up.sqlite.sql',
    'INSERT INTO widgets (id, name) VALUES (1, ''alpha'');');
  WriteMigration('001_pg_should_be_ignored.up.pg.sql',
    'CREATE TABLE should_not_exist (id INTEGER PRIMARY KEY);');

  Result := TMigrationEngine.Run(FConnection, dbSQLite, FMigrationsDir);

  Assert.IsTrue(Result.Success, Result.LastError);
  Assert.AreEqual(2, Result.AppliedCount);
  Assert.AreEqual(0, Result.SkippedCount);
  Assert.IsTrue(TFile.Exists(Result.BackupPath), 'SQLite backup must exist');
  Assert.AreEqual(1, ScalarInt('SELECT COUNT(*) FROM widgets'));
  Assert.IsFalse(TableExists('should_not_exist'));
  Assert.AreEqual(2,
    ScalarInt('SELECT COUNT(*) FROM DeepBase_schema_migrations'));
end;

procedure TTestDBMigrations.Test_Run_SQLite_IsIdempotentOnSecondRun;
var
  Result: TMigrationResult;
begin
  WriteMigration('001_create_widgets.up.sqlite.sql',
    'CREATE TABLE widgets (id INTEGER PRIMARY KEY, name TEXT);');

  Result := TMigrationEngine.Run(FConnection, dbSQLite, FMigrationsDir);
  Assert.IsTrue(Result.Success, Result.LastError);
  Assert.AreEqual(1, Result.AppliedCount);

  Result := TMigrationEngine.Run(FConnection, dbSQLite, FMigrationsDir);
  Assert.IsTrue(Result.Success, Result.LastError);
  Assert.AreEqual(0, Result.AppliedCount);
  Assert.AreEqual(1, Result.SkippedCount);
  Assert.AreEqual('', Result.BackupPath);
end;

procedure TTestDBMigrations.Test_Run_SQLite_ChecksumMismatchFails;
var
  Result: TMigrationResult;
begin
  WriteMigration('001_create_widgets.up.sqlite.sql',
    'CREATE TABLE widgets (id INTEGER PRIMARY KEY, name TEXT);');
  Result := TMigrationEngine.Run(FConnection, dbSQLite, FMigrationsDir);
  Assert.IsTrue(Result.Success, Result.LastError);

  WriteMigration('001_create_widgets.up.sqlite.sql',
    'CREATE TABLE widgets (id INTEGER PRIMARY KEY, name TEXT, extra TEXT);');
  Result := TMigrationEngine.Run(FConnection, dbSQLite, FMigrationsDir);

  Assert.IsFalse(Result.Success);
  Assert.Contains(Result.LastError, 'checksum mismatch');
  Assert.AreEqual('001_create_widgets.up.sqlite.sql', Result.FailedScript);
  Assert.AreEqual(0, Result.AppliedCount);
end;

procedure TTestDBMigrations.Test_Run_SQLite_FailedScriptRollsBackAndIsNotRecorded;
var
  Result: TMigrationResult;
begin
  WriteMigration('001_bad.up.sqlite.sql',
    'CREATE TABLE failed_table (id INTEGER PRIMARY KEY);' + sLineBreak +
    'INSERT INTO missing_table (id) VALUES (1);');

  Result := TMigrationEngine.Run(FConnection, dbSQLite, FMigrationsDir);

  Assert.IsFalse(Result.Success);
  Assert.AreEqual('001_bad.up.sqlite.sql', Result.FailedScript);
  Assert.AreEqual(0,
    ScalarInt('SELECT COUNT(*) FROM DeepBase_schema_migrations'));
  Assert.IsFalse(TableExists('failed_table'));
end;

procedure TTestDBMigrations.Test_Run_SQLite_TriggerBodyIsNotSplit;
var
  Result: TMigrationResult;
begin
  WriteMigration('001_trigger.up.sqlite.sql',
    'CREATE TABLE widgets (id INTEGER PRIMARY KEY, name TEXT);' + sLineBreak +
    'CREATE TABLE widget_audit (id INTEGER);' + sLineBreak +
    'CREATE TRIGGER trg_widgets_ai AFTER INSERT ON widgets' + sLineBreak +
    'BEGIN' + sLineBreak +
    '  INSERT INTO widget_audit (id) VALUES (new.id);' + sLineBreak +
    'END;' + sLineBreak +
    'INSERT INTO widgets (id, name) VALUES (1, ''alpha'');');

  Result := TMigrationEngine.Run(FConnection, dbSQLite, FMigrationsDir);

  Assert.IsTrue(Result.Success, Result.LastError);
  Assert.AreEqual(1, ScalarInt('SELECT COUNT(*) FROM widget_audit'));
end;

procedure TTestDBMigrations.Test_Run_SQLite_TransactionControlFails;
var
  Result: TMigrationResult;
begin
  WriteMigration('001_tx_control.up.sqlite.sql',
    'BEGIN;' + sLineBreak +
    'CREATE TABLE tx_test (id INTEGER PRIMARY KEY);' + sLineBreak +
    'COMMIT;');

  Result := TMigrationEngine.Run(FConnection, dbSQLite, FMigrationsDir);

  Assert.IsFalse(Result.Success);
  Assert.AreEqual('001_tx_control.up.sqlite.sql', Result.FailedScript);
  Assert.Contains(Result.LastError,
    'Migration scripts must not contain transaction control statements');
  Assert.AreEqual(0,
    ScalarInt('SELECT COUNT(*) FROM DeepBase_schema_migrations'));
  Assert.IsFalse(TableExists('tx_test'));
end;

procedure TTestDBMigrations.Test_Run_SQLite_WriteLockHeldFailsBeforeApplying;
var
  SeedResult: TMigrationResult;
  Result: TMigrationResult;
  LockConnection: TFDConnection;
  RunConnection: TFDConnection;
begin
  SeedResult := TMigrationEngine.Run(FConnection, dbSQLite, FMigrationsDir);
  Assert.IsTrue(SeedResult.Success, SeedResult.LastError);

  WriteMigration('001_locked.up.sqlite.sql',
    'CREATE TABLE locked_test (id INTEGER PRIMARY KEY);');

  LockConnection := CreateConnection;
  RunConnection := CreateConnection;
  try
    RunConnection.ExecSQL('PRAGMA busy_timeout=100');
    LockConnection.ExecSQL('BEGIN IMMEDIATE');
    try
      Result := TMigrationEngine.Run(RunConnection, dbSQLite, FMigrationsDir);

      Assert.IsFalse(Result.Success);
      Assert.AreEqual('001_locked.up.sqlite.sql', Result.FailedScript);
      Assert.IsTrue(Result.LastError <> '', 'Lock failure must be reported');
    finally
      LockConnection.ExecSQL('ROLLBACK');
    end;
  finally
    RunConnection.Free;
    LockConnection.Free;
  end;

  Assert.IsFalse(TableExists('locked_test'));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDBMigrations);

end.
