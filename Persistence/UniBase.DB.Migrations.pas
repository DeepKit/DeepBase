unit UniBase.DB.Migrations;

interface

uses
  System.SysUtils,
  FireDAC.Comp.Client,
  UniBase.DB.Pool;

type
  TMigrationResult = record
    Success: Boolean;
    AppliedCount: Integer;
    SkippedCount: Integer;
    FailedScript: string;
    BackupPath: string;
    LastError: string;
  end;

  TMigrationEngine = class
  private
    class function AcquireConnection(DatabaseType: TDatabaseType): TFDConnection; static;
    class procedure ValidateDatabaseType(DatabaseType: TDatabaseType); static;
    class function IsPostgreSQL(DatabaseType: TDatabaseType): Boolean; static;
    class function IsSQLite(DatabaseType: TDatabaseType): Boolean; static;
    class procedure EnsureMigrationTable(Connection: TFDConnection;
      DatabaseType: TDatabaseType); static;
    class function FindMigrationFiles(DatabaseType: TDatabaseType;
      const MigrationsDir: string): TArray<string>; static;
    class function ExtractVersion(DatabaseType: TDatabaseType;
      const FilePath: string): string; static;
    class function CalculateChecksum(const FilePath: string): string; static;
    class function AlreadyApplied(Connection: TFDConnection; const Version,
      Checksum: string): Boolean; static;
    class procedure RecordApplied(Connection: TFDConnection; const Version,
      ScriptName, Checksum: string); static;
    class function SplitSQLStatements(const SQLText: string): TArray<string>; static;
    class procedure ExecuteScript(Connection: TFDConnection;
      const ScriptPath: string); static;
    class function BackupSQLiteDatabase(Connection: TFDConnection): string; static;
    class procedure AcquirePostgreSQLLock(Connection: TFDConnection); static;
    class procedure ReleasePostgreSQLLock(Connection: TFDConnection); static;
  public
    class function Run(DatabaseType: TDatabaseType;
      const MigrationsDir: string): TMigrationResult; overload; static;
    class function Run(Connection: TFDConnection; DatabaseType: TDatabaseType;
      const MigrationsDir: string): TMigrationResult; overload; static;
  end;

implementation

uses
  System.Classes,
  System.Generics.Collections,
  System.Hash,
  System.IOUtils,
  System.StrUtils,
  FireDAC.Stan.Param,
  UniBase.DB.Factory,
  UniBase.Exceptions;

const
  MIGRATION_TABLE = 'unibase_schema_migrations';
  MIGRATION_LOCK_ID = 742030451;

class function TMigrationEngine.Run(DatabaseType: TDatabaseType;
  const MigrationsDir: string): TMigrationResult;
var
  Connection: TFDConnection;
begin
  ValidateDatabaseType(DatabaseType);
  Connection := AcquireConnection(DatabaseType);
  try
    Result := Run(Connection, DatabaseType, MigrationsDir);
  finally
    Connection.Free;
  end;
end;

class function TMigrationEngine.Run(Connection: TFDConnection;
  DatabaseType: TDatabaseType; const MigrationsDir: string): TMigrationResult;
var
  Files: TArray<string>;
  FilePath: string;
  Version: string;
  Checksum: string;
  OwnTransaction: Boolean;
  PgLockHeld: Boolean;
begin
  Result.Success := False;
  Result.AppliedCount := 0;
  Result.SkippedCount := 0;
  Result.FailedScript := '';
  Result.BackupPath := '';
  Result.LastError := '';
  PgLockHeld := False;

  try
    ValidateDatabaseType(DatabaseType);
    if not Assigned(Connection) then
      raise EDatabaseException.Create('Migration connection cannot be nil');
    if not TDirectory.Exists(MigrationsDir) then
      raise EInvalidOperationException.CreateFmt(
        'Migrations directory does not exist: %s', [MigrationsDir]);
    if not Connection.Connected then
      Connection.Open;

    EnsureMigrationTable(Connection, DatabaseType);

    if IsPostgreSQL(DatabaseType) then
    begin
      AcquirePostgreSQLLock(Connection);
      PgLockHeld := True;
    end;

    Files := FindMigrationFiles(DatabaseType, MigrationsDir);
    for FilePath in Files do
    begin
      Version := ExtractVersion(DatabaseType, FilePath);
      Checksum := CalculateChecksum(FilePath);

      if AlreadyApplied(Connection, Version, Checksum) then
      begin
        Inc(Result.SkippedCount);
        Continue;
      end;

      if IsSQLite(DatabaseType) and (Result.BackupPath = '') then
        Result.BackupPath := BackupSQLiteDatabase(Connection);

      Result.FailedScript := ExtractFileName(FilePath);
      OwnTransaction := not Connection.InTransaction;
      if OwnTransaction then
        Connection.StartTransaction;
      try
        ExecuteScript(Connection, FilePath);
        RecordApplied(Connection, Version, ExtractFileName(FilePath), Checksum);
        if OwnTransaction then
          Connection.Commit;
        Inc(Result.AppliedCount);
      except
        if OwnTransaction and Connection.InTransaction then
          Connection.Rollback;
        raise;
      end;
    end;

    Result.FailedScript := '';
    Result.Success := True;
  except
    on E: Exception do
    begin
      Result.Success := False;
      Result.LastError := E.Message;
    end;
  end;

  if PgLockHeld then
  begin
    try
      ReleasePostgreSQLLock(Connection);
    except
      on E: Exception do
      begin
        if Result.LastError = '' then
          Result.LastError := E.Message;
        Result.Success := False;
      end;
    end;
  end;
end;

class function TMigrationEngine.AcquireConnection(
  DatabaseType: TDatabaseType): TFDConnection;
begin
  if IsSQLite(DatabaseType) then
    Result := TDBConnectionFactory.GetLocal
  else if IsPostgreSQL(DatabaseType) then
    Result := TDBConnectionFactory.GetShared
  else
    raise EDatabaseException.Create('Migration engine supports SQLite and PostgreSQL only');
end;

class procedure TMigrationEngine.ValidateDatabaseType(
  DatabaseType: TDatabaseType);
begin
  if not (IsSQLite(DatabaseType) or IsPostgreSQL(DatabaseType)) then
    raise EDatabaseException.Create('Migration engine supports SQLite and PostgreSQL only');
end;

class function TMigrationEngine.IsPostgreSQL(
  DatabaseType: TDatabaseType): Boolean;
begin
  Result := DatabaseType = dbPostgreSQL;
end;

class function TMigrationEngine.IsSQLite(DatabaseType: TDatabaseType): Boolean;
begin
  Result := DatabaseType = dbSQLite;
end;

class procedure TMigrationEngine.EnsureMigrationTable(Connection: TFDConnection;
  DatabaseType: TDatabaseType);
begin
  if IsPostgreSQL(DatabaseType) then
    Connection.ExecSQL(
      'CREATE TABLE IF NOT EXISTS ' + MIGRATION_TABLE + ' (' +
      'version TEXT PRIMARY KEY, ' +
      'script_name TEXT NOT NULL, ' +
      'checksum TEXT NOT NULL, ' +
      'applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP)')
  else
    Connection.ExecSQL(
      'CREATE TABLE IF NOT EXISTS ' + MIGRATION_TABLE + ' (' +
      'version TEXT PRIMARY KEY, ' +
      'script_name TEXT NOT NULL, ' +
      'checksum TEXT NOT NULL, ' +
      'applied_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)');
end;

class function TMigrationEngine.FindMigrationFiles(DatabaseType: TDatabaseType;
  const MigrationsDir: string): TArray<string>;
var
  Files: TStringList;
  FilePath: string;
  Suffix: string;
  I: Integer;
begin
  if IsSQLite(DatabaseType) then
    Suffix := '.up.sqlite.sql'
  else
    Suffix := '.up.pg.sql';

  Files := TStringList.Create;
  try
    for FilePath in TDirectory.GetFiles(MigrationsDir, '*.sql') do
    begin
      if EndsText(Suffix, ExtractFileName(FilePath)) then
        Files.Add(FilePath);
    end;
    Files.Sort;

    SetLength(Result, Files.Count);
    for I := 0 to Files.Count - 1 do
      Result[I] := Files[I];
  finally
    Files.Free;
  end;
end;

class function TMigrationEngine.ExtractVersion(DatabaseType: TDatabaseType;
  const FilePath: string): string;
var
  FileName: string;
  Suffix: string;
begin
  FileName := ExtractFileName(FilePath);
  if IsSQLite(DatabaseType) then
    Suffix := '.up.sqlite.sql'
  else
    Suffix := '.up.pg.sql';

  if not EndsText(Suffix, FileName) then
    raise EInvalidOperationException.CreateFmt(
      'Invalid migration file name: %s', [FileName]);

  Result := Copy(FileName, 1, Length(FileName) - Length(Suffix));
  if Trim(Result) = '' then
    raise EInvalidOperationException.CreateFmt(
      'Migration version cannot be empty: %s', [FileName]);
end;

class function TMigrationEngine.CalculateChecksum(const FilePath: string): string;
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(FilePath, fmOpenRead or fmShareDenyNone);
  try
    Result := THashSHA2.GetHashString(Stream, THashSHA2.TSHA2Version.SHA256);
  finally
    Stream.Free;
  end;
end;

class function TMigrationEngine.AlreadyApplied(Connection: TFDConnection;
  const Version, Checksum: string): Boolean;
var
  Query: TFDQuery;
  ExistingChecksum: string;
begin
  Result := False;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := Connection;
    Query.SQL.Text :=
      'SELECT checksum FROM ' + MIGRATION_TABLE + ' WHERE version = :version';
    Query.ParamByName('version').AsString := Version;
    Query.Open;
    if Query.Eof then
      Exit(False);

    ExistingChecksum := Query.FieldByName('checksum').AsString;
    if not SameText(ExistingChecksum, Checksum) then
      raise EDatabaseException.CreateFmt(
        'Migration checksum mismatch for version %s', [Version]);

    Result := True;
  finally
    Query.Free;
  end;
end;

class procedure TMigrationEngine.RecordApplied(Connection: TFDConnection;
  const Version, ScriptName, Checksum: string);
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := Connection;
    Query.SQL.Text :=
      'INSERT INTO ' + MIGRATION_TABLE + ' ' +
      '(version, script_name, checksum, applied_at) ' +
      'VALUES (:version, :script_name, :checksum, CURRENT_TIMESTAMP)';
    Query.ParamByName('version').AsString := Version;
    Query.ParamByName('script_name').AsString := ScriptName;
    Query.ParamByName('checksum').AsString := Checksum;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

class function TMigrationEngine.SplitSQLStatements(
  const SQLText: string): TArray<string>;
var
  Statements: TList<string>;
  Builder: TStringBuilder;
  I: Integer;
  J: Integer;
  Ch: Char;
  NextCh: Char;
  Statement: string;
  InSingleQuote: Boolean;
  InDoubleQuote: Boolean;
  DollarTag: string;

  function IsTagChar(C: Char): Boolean;
  begin
    Result := CharInSet(C, ['A'..'Z', 'a'..'z', '0'..'9', '_']);
  end;

begin
  Statements := TList<string>.Create;
  Builder := TStringBuilder.Create;
  try
    I := 1;
    InSingleQuote := False;
    InDoubleQuote := False;
    DollarTag := '';

    while I <= Length(SQLText) do
    begin
      Ch := SQLText[I];
      if I < Length(SQLText) then
        NextCh := SQLText[I + 1]
      else
        NextCh := #0;

      if DollarTag <> '' then
      begin
        if Copy(SQLText, I, Length(DollarTag)) = DollarTag then
        begin
          Builder.Append(DollarTag);
          Inc(I, Length(DollarTag));
          DollarTag := '';
          Continue;
        end;

        Builder.Append(Ch);
        Inc(I);
        Continue;
      end;

      if InSingleQuote then
      begin
        Builder.Append(Ch);
        if (Ch = '''') and (NextCh = '''') then
        begin
          Builder.Append(NextCh);
          Inc(I, 2);
          Continue;
        end;
        if Ch = '''' then
          InSingleQuote := False;
        Inc(I);
        Continue;
      end;

      if InDoubleQuote then
      begin
        Builder.Append(Ch);
        if Ch = '"' then
          InDoubleQuote := False;
        Inc(I);
        Continue;
      end;

      if (Ch = '-') and (NextCh = '-') then
      begin
        while (I <= Length(SQLText)) and not CharInSet(SQLText[I], [#10, #13]) do
          Inc(I);
        Builder.AppendLine;
        Continue;
      end;

      if (Ch = '/') and (NextCh = '*') then
      begin
        Inc(I, 2);
        while I <= Length(SQLText) do
        begin
          if (SQLText[I] = '*') and (I < Length(SQLText)) and
             (SQLText[I + 1] = '/') then
          begin
            Inc(I, 2);
            Break;
          end;
          Inc(I);
        end;
        Builder.Append(' ');
        Continue;
      end;

      if Ch = '''' then
      begin
        InSingleQuote := True;
        Builder.Append(Ch);
        Inc(I);
        Continue;
      end;

      if Ch = '"' then
      begin
        InDoubleQuote := True;
        Builder.Append(Ch);
        Inc(I);
        Continue;
      end;

      if Ch = '$' then
      begin
        J := I + 1;
        while (J <= Length(SQLText)) and IsTagChar(SQLText[J]) do
          Inc(J);
        if (J <= Length(SQLText)) and (SQLText[J] = '$') then
        begin
          DollarTag := Copy(SQLText, I, J - I + 1);
          Builder.Append(DollarTag);
          I := J + 1;
          Continue;
        end;
      end;

      if Ch = ';' then
      begin
        Statement := Trim(Builder.ToString);
        if Statement <> '' then
          Statements.Add(Statement);
        Builder.Clear;
        Inc(I);
        Continue;
      end;

      Builder.Append(Ch);
      Inc(I);
    end;

    Statement := Trim(Builder.ToString);
    if Statement <> '' then
      Statements.Add(Statement);

    Result := Statements.ToArray;
  finally
    Builder.Free;
    Statements.Free;
  end;
end;

class procedure TMigrationEngine.ExecuteScript(Connection: TFDConnection;
  const ScriptPath: string);
var
  SQLText: string;
  Statements: TArray<string>;
  Statement: string;
begin
  SQLText := TFile.ReadAllText(ScriptPath, TEncoding.UTF8);
  Statements := SplitSQLStatements(SQLText);
  for Statement in Statements do
    Connection.ExecSQL(Statement);
end;

class function TMigrationEngine.BackupSQLiteDatabase(
  Connection: TFDConnection): string;
var
  DBPath: string;
  BackupDir: string;
  BackupName: string;
begin
  Result := '';
  DBPath := Connection.Params.Database;
  if Trim(DBPath) = '' then
    Exit;

  DBPath := TPath.GetFullPath(DBPath);
  if not TFile.Exists(DBPath) then
    Exit;

  BackupDir := TPath.Combine(TPath.GetDirectoryName(DBPath), 'migration_backups');
  TDirectory.CreateDirectory(BackupDir);
  BackupName := ChangeFileExt(ExtractFileName(DBPath), '') + '.' +
    FormatDateTime('yyyymmdd_hhnnss_zzz', Now) + '.bak';
  Result := TPath.Combine(BackupDir, BackupName);

  try
    Connection.ExecSQL('VACUUM INTO ' + QuotedStr(Result));
  except
    TFile.Copy(DBPath, Result, True);
  end;
end;

class procedure TMigrationEngine.AcquirePostgreSQLLock(Connection: TFDConnection);
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := Connection;
    Query.SQL.Text := Format('SELECT pg_advisory_lock(%d)', [MIGRATION_LOCK_ID]);
    Query.Open;
  finally
    Query.Free;
  end;
end;

class procedure TMigrationEngine.ReleasePostgreSQLLock(Connection: TFDConnection);
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := Connection;
    Query.SQL.Text := Format('SELECT pg_advisory_unlock(%d)', [MIGRATION_LOCK_ID]);
    Query.Open;
  finally
    Query.Free;
  end;
end;

end.
