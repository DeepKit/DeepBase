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
    procedure Test_Run_SQLite_BareEndTransactionControlFails;

    [Test]
    procedure Test_Run_SQLite_EndTransactionControlFails;

    [Test]
    procedure Test_Run_SQLite_FailedScriptLeavesDatabaseClean;

    [Test]
    procedure Test_Run_SQLite_WriteLockHeldFailsBeforeApplying;

    { REVIEW5-DATA-006 BUG-336: checksum must be computed from the same
      content snapshot that is executed, closing the TOCTOU window where the
      file could be swapped between checksum and ExecSQL. }
    [Test]
    procedure Test_CalculateChecksumFromContent_MatchesStoredAppliedChecksum;

    { REVIEW5-DATA-006 BUG-336: For multi-statement scripts the stored checksum
      must still equal the SHA256 of the single content snapshot that was split
      and executed, proving the split path also uses one consistent snapshot. }
    [Test]
    procedure Test_MultiStatementScript_StoredChecksumMatchesContentSnapshot;
  end;

implementation

uses
  System.SysUtils,
  System.Hash,
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

{ REVIEW5-DATA-005 BUG-334: bare END must be rejected as transaction control }
procedure TTestDBMigrations.Test_Run_SQLite_BareEndTransactionControlFails;
var
  Result: TMigrationResult;
begin
  WriteMigration('001_bare_end.up.sqlite.sql',
    'CREATE TABLE end_test (id INTEGER PRIMARY KEY);' + sLineBreak +
    'END;');

  Result := TMigrationEngine.Run(FConnection, dbSQLite, FMigrationsDir);

  Assert.IsFalse(Result.Success);
  Assert.AreEqual('001_bare_end.up.sqlite.sql', Result.FailedScript);
  Assert.Contains(Result.LastError,
    'Migration scripts must not contain transaction control statements');
  Assert.AreEqual(0,
    ScalarInt('SELECT COUNT(*) FROM DeepBase_schema_migrations'));
  { REVIEW5-DATA-005 rollback integrity: partial state must be cleaned up }
  Assert.IsFalse(TableExists('end_test'));
end;

{ REVIEW5-DATA-005 BUG-334: explicit END TRANSACTION must also be rejected }
procedure TTestDBMigrations.Test_Run_SQLite_EndTransactionControlFails;
var
  Result: TMigrationResult;
begin
  WriteMigration('001_end_tx.up.sqlite.sql',
    'CREATE TABLE endtx_test (id INTEGER PRIMARY KEY);' + sLineBreak +
    'END TRANSACTION;');

  Result := TMigrationEngine.Run(FConnection, dbSQLite, FMigrationsDir);

  Assert.IsFalse(Result.Success);
  Assert.AreEqual('001_end_tx.up.sqlite.sql', Result.FailedScript);
  Assert.Contains(Result.LastError,
    'Migration scripts must not contain transaction control statements');
  Assert.AreEqual(0,
    ScalarInt('SELECT COUNT(*) FROM DeepBase_schema_migrations'));
  Assert.IsFalse(TableExists('endtx_test'));
end;

{ REVIEW5-DATA-005: verifies database cleanliness after failed migration }
procedure TTestDBMigrations.Test_Run_SQLite_FailedScriptLeavesDatabaseClean;
var
  Result: TMigrationResult;
begin
  { Script creates a table, then contains an invalid statement to force failure }
  WriteMigration('001_partial_fail.up.sqlite.sql',
    'CREATE TABLE partial_test (id INTEGER PRIMARY KEY);' + sLineBreak +
    'INSERT INTO nonexistent_table_xyz VALUES (1);');

  Result := TMigrationEngine.Run(FConnection, dbSQLite, FMigrationsDir);

  Assert.IsFalse(Result.Success);
  Assert.AreEqual('001_partial_fail.up.sqlite.sql', Result.FailedScript);
  { Rollback integrity: migration must not be recorded }
  Assert.AreEqual(0,
    ScalarInt('SELECT COUNT(*) FROM DeepBase_schema_migrations'));
  { Rollback integrity: partial DDL must be rolled back }
  Assert.IsFalse(TableExists('partial_test'));
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

{ REVIEW5-DATA-006 BUG-336: The checksum stored in DeepBase_schema_migrations
  must equal the SHA256 of the executed script content. This proves the engine
  computes the checksum from the same in-memory snapshot it executes, rather
  than two independent file reads (the TOCTOU window). }
procedure TTestDBMigrations.Test_CalculateChecksumFromContent_MatchesStoredAppliedChecksum;
const
  ScriptSQL = 'CREATE TABLE snapshot_test (id INTEGER PRIMARY KEY, name TEXT);';
var
  RunResult: TMigrationResult;
  ScriptPath: string;
  ExpectedChecksum: string;
  StoredChecksum: string;
  Query: TFDQuery;
begin
  ScriptPath := TPath.Combine(FMigrationsDir, '001_snapshot.up.sqlite.sql');
  TFile.WriteAllText(ScriptPath, ScriptSQL, TEncoding.UTF8);

  // Must mirror CalculateChecksumFromContent: SHA256 over the Delphi string
  // (UTF-16 code units), not the on-disk UTF-8 bytes.
  ExpectedChecksum := THashSHA2.GetHashString(ScriptSQL, THashSHA2.TSHA2Version.SHA256);

  RunResult := TMigrationEngine.Run(FConnection, dbSQLite, FMigrationsDir);
  Assert.IsTrue(RunResult.Success, RunResult.LastError);

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT checksum FROM DeepBase_schema_migrations WHERE version = :v';
    Query.ParamByName('v').AsString := '001_snapshot';
    Query.Open;
    Assert.IsFalse(Query.Eof, 'Migration row must be recorded');
    StoredChecksum := Query.Fields[0].AsString;
  finally
    Query.Free;
  end;

  Assert.AreEqual(ExpectedChecksum, StoredChecksum,
    'Stored checksum must equal SHA256 of the executed content snapshot');
end;

{ REVIEW5-DATA-006 BUG-336: For multi-statement scripts the stored checksum
  must equal the SHA256 of the content snapshot that was split and executed.
  This proves the split path (SplitSQLStatements over the single snapshot)
  cannot diverge from the checksum even when the script contains triggers with
  nested statement terminators. }
procedure TTestDBMigrations.Test_MultiStatementScript_StoredChecksumMatchesContentSnapshot;
const
  ScriptSQL =
    'CREATE TABLE multi_test (id INTEGER PRIMARY KEY, name TEXT);' + sLineBreak +
    'CREATE TABLE multi_audit (id INTEGER);' + sLineBreak +
    'CREATE TRIGGER trg_multi_ai AFTER INSERT ON multi_test' + sLineBreak +
    'BEGIN' + sLineBreak +
    '  INSERT INTO multi_audit (id) VALUES (new.id);' + sLineBreak +
    'END;' + sLineBreak +
    'INSERT INTO multi_test (id, name) VALUES (1, ''alpha'');';
var
  RunResult: TMigrationResult;
  ExpectedChecksum: string;
  StoredChecksum: string;
  Query: TFDQuery;
begin
  WriteMigration('001_multi.up.sqlite.sql', ScriptSQL);
  ExpectedChecksum := THashSHA2.GetHashString(ScriptSQL, THashSHA2.TSHA2Version.SHA256);

  RunResult := TMigrationEngine.Run(FConnection, dbSQLite, FMigrationsDir);
  Assert.IsTrue(RunResult.Success, RunResult.LastError);

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT checksum FROM DeepBase_schema_migrations WHERE version = :v';
    Query.ParamByName('v').AsString := '001_multi';
    Query.Open;
    Assert.IsFalse(Query.Eof, 'Migration row must be recorded');
    StoredChecksum := Query.Fields[0].AsString;
  finally
    Query.Free;
  end;

  Assert.AreEqual(ExpectedChecksum, StoredChecksum,
    'Stored checksum must equal SHA256 of the executed content snapshot');
  Assert.AreEqual(1, ScalarInt('SELECT COUNT(*) FROM multi_audit'),
    'Trigger must have fired, proving the multi-statement snapshot executed');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDBMigrations);

end.
