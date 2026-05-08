{ ============================================================================
  CLI.DB - 数据库管理命�?
  
  版本: 1.0
  说明: 实现 db init/upgrade/backup/check 命令
  ============================================================================ }

unit CLI.DB;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.DateUtils,
  FireDAC.Comp.Client,
  FireDAC.Stan.Def,
  FireDAC.Stan.Async,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  CLI.Commands;

type
  TDBCommands = class
  private
    class procedure ShowHelp;
    class function DoInit: Integer;
    class function DoUpgrade: Integer;
    class function DoBackup: Integer;
    class function DoCheck: Integer;
    class function CreateConnection(const DBPath: string): TFDConnection;
    class procedure ExecuteSchema(Conn: TFDConnection; Tier: Integer);
    class function GetCurrentTier(Conn: TFDConnection): Integer;
  public
    class function Execute: Integer;
  end;

implementation

const
  TIER0_SCHEMA =
    'CREATE TABLE IF NOT EXISTS ub_config (' +
    '  section TEXT NOT NULL,' +
    '  key TEXT NOT NULL,' +
    '  value TEXT,' +
    '  value_type INTEGER DEFAULT 0,' +
    '  updated_at TEXT,' +
    '  PRIMARY KEY (section, key)' +
    ');' +
    'CREATE TABLE IF NOT EXISTS ub_i18n (' +
    '  lang TEXT NOT NULL,' +
    '  key TEXT NOT NULL,' +
    '  value TEXT,' +
    '  updated_at TEXT,' +
    '  PRIMARY KEY (lang, key)' +
    ');' +
    'CREATE TABLE IF NOT EXISTS ub_form_state (' +
    '  form_name TEXT PRIMARY KEY,' +
    '  state_json TEXT,' +
    '  updated_at TEXT' +
    ');' +
    'CREATE TABLE IF NOT EXISTS ub_meta (' +
    '  key TEXT PRIMARY KEY,' +
    '  value TEXT' +
    ');';

  TIER1_SCHEMA =
    'CREATE TABLE IF NOT EXISTS ub_log (' +
    '  id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  timestamp TEXT NOT NULL,' +
    '  level INTEGER NOT NULL,' +
    '  source TEXT,' +
    '  message TEXT,' +
    '  detail TEXT' +
    ');' +
    'CREATE INDEX IF NOT EXISTS idx_log_timestamp ON ub_log(timestamp);' +
    'CREATE INDEX IF NOT EXISTS idx_log_level ON ub_log(level);' +
    'CREATE TABLE IF NOT EXISTS ub_mru (' +
    '  category TEXT NOT NULL,' +
    '  item TEXT NOT NULL,' +
    '  last_used TEXT,' +
    '  use_count INTEGER DEFAULT 1,' +
    '  PRIMARY KEY (category, item)' +
    ');' +
    'CREATE TABLE IF NOT EXISTS ub_hotkey (' +
    '  action_id TEXT PRIMARY KEY,' +
    '  shortcut TEXT,' +
    '  enabled INTEGER DEFAULT 1' +
    ');';

  TIER2_SCHEMA =
    'CREATE TABLE IF NOT EXISTS ub_llm_hiDeepStory (' +
    '  id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  session_id TEXT,' +
    '  timestamp TEXT NOT NULL,' +
    '  role TEXT NOT NULL,' +
    '  content TEXT,' +
    '  model TEXT,' +
    '  tokens_used INTEGER' +
    ');' +
    'CREATE INDEX IF NOT EXISTS idx_llm_session ON ub_llm_hiDeepStory(session_id);' +
    'CREATE TABLE IF NOT EXISTS ub_exception (' +
    '  id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  timestamp TEXT NOT NULL,' +
    '  exception_class TEXT,' +
    '  message TEXT,' +
    '  stack_trace TEXT,' +
    '  context TEXT,' +
    '  reported INTEGER DEFAULT 0' +
    ');';

{ TDBCommands }

class function TDBCommands.Execute: Integer;
var
  SubCmd: string;
begin
  SubCmd := TCliUtils.GetSubCommand;
  
  if (SubCmd = '') or (SubCmd = 'help') or TCliUtils.HasOption('help') or TCliUtils.HasOption('h') then
  begin
    ShowHelp;
    Result := 0;
  end
  else if SubCmd = 'init' then
    Result := DoInit
  else if SubCmd = 'upgrade' then
    Result := DoUpgrade
  else if SubCmd = 'backup' then
    Result := DoBackup
  else if SubCmd = 'check' then
    Result := DoCheck
  else
  begin
    TCliUtils.Error('Unknown db subcommand: %s', [SubCmd]);
    ShowHelp;
    Result := 1;
  end;
end;

class procedure TDBCommands.ShowHelp;
begin
  Writeln('Database Management Commands');
  Writeln('');
  Writeln('Usage: DeepBase db <subcommand> [options]');
  Writeln('');
  Writeln('Subcommands:');
  Writeln('  init      Initialize a new database');
  Writeln('  upgrade   Upgrade database schema to a higher tier');
  Writeln('  backup    Create a backup of the database');
  Writeln('  check     Check database integrity');
  Writeln('');
  Writeln('Options for init:');
  Writeln('  --path, -p <path>   Database file path (required)');
  Writeln('  --tier, -t <0|1|2>  Schema tier level (default: 0)');
  Writeln('  --force, -f         Overwrite existing database');
  Writeln('');
  Writeln('Options for upgrade:');
  Writeln('  --path, -p <path>   Database file path (required)');
  Writeln('  --tier, -t <0|1|2>  Target tier level');
  Writeln('');
  Writeln('Options for backup:');
  Writeln('  --path, -p <path>   Database file path (required)');
  Writeln('  --output, -o <path> Backup file path (default: auto-generated)');
  Writeln('');
  Writeln('Options for check:');
  Writeln('  --path, -p <path>   Database file path (required)');
  Writeln('  --fix               Attempt to fix issues');
  Writeln('');
  Writeln('Examples:');
  Writeln('  DeepBase db init --path myapp.db --tier 1');
  Writeln('  DeepBase db upgrade --path myapp.db --tier 2');
  Writeln('  DeepBase db backup --path myapp.db');
  Writeln('  DeepBase db check --path myapp.db');
end;

class function TDBCommands.CreateConnection(const DBPath: string): TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  Result.DriverName := 'SQLite';
  Result.Params.Database := DBPath;
  Result.Params.Values['LockingMode'] := 'Normal';
  Result.LoginPrompt := False;
end;

class function TDBCommands.GetCurrentTier(Conn: TFDConnection): Integer;
var
  Query: TFDQuery;
begin
  Result := -1;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := Conn;
    Query.SQL.Text := 'SELECT value FROM ub_meta WHERE key = ''schema_tier''';
    try
      Query.Open;
      if not Query.Eof then
        Result := StrToIntDef(Query.Fields[0].AsString, 0);
    except
      // Table doesn't exist
    end;
  finally
    Query.Free;
  end;
end;

class procedure TDBCommands.ExecuteSchema(Conn: TFDConnection; Tier: Integer);
var
  Statements: TStringList;
  I: Integer;
  SQL: string;
begin
  Statements := TStringList.Create;
  try
    Statements.Delimiter := ';';
    Statements.StrictDelimiter := True;
    
    // Tier 0 - always required
    Statements.DelimitedText := TIER0_SCHEMA;
    for I := 0 to Statements.Count - 1 do
    begin
      SQL := Trim(Statements[I]);
      if SQL <> '' then
        Conn.ExecSQL(SQL);
    end;
    
    // Set tier in meta
    Conn.ExecSQL('INSERT OR REPLACE INTO ub_meta (key, value) VALUES (''schema_tier'', ''' + IntToStr(Tier) + ''')');
    Conn.ExecSQL('INSERT OR REPLACE INTO ub_meta (key, value) VALUES (''schema_version'', ''1.0'')');
    Conn.ExecSQL('INSERT OR REPLACE INTO ub_meta (key, value) VALUES (''created_at'', ''' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + ''')');
    
    if Tier >= 1 then
    begin
      Statements.DelimitedText := TIER1_SCHEMA;
      for I := 0 to Statements.Count - 1 do
      begin
        SQL := Trim(Statements[I]);
        if SQL <> '' then
          Conn.ExecSQL(SQL);
      end;
    end;
    
    if Tier >= 2 then
    begin
      Statements.DelimitedText := TIER2_SCHEMA;
      for I := 0 to Statements.Count - 1 do
      begin
        SQL := Trim(Statements[I]);
        if SQL <> '' then
          Conn.ExecSQL(SQL);
      end;
    end;
  finally
    Statements.Free;
  end;
end;

class function TDBCommands.DoInit: Integer;
var
  DBPath: string;
  Tier: Integer;
  Force: Boolean;
  Conn: TFDConnection;
begin
  Result := 0;
  
  DBPath := TCliUtils.GetOption('path', TCliUtils.GetOption('p'));
  if DBPath = '' then
  begin
    TCliUtils.Error('Database path is required. Use --path or -p option.');
    Result := 1;
    Exit;
  end;
  
  DBPath := TCliUtils.ResolvePath(DBPath);
  Tier := StrToIntDef(TCliUtils.GetOption('tier', TCliUtils.GetOption('t', '0')), 0);
  Force := TCliUtils.HasOption('force') or TCliUtils.HasOption('f');
  
  if (Tier < 0) or (Tier > 2) then
  begin
    TCliUtils.Error('Tier must be 0, 1, or 2');
    Result := 1;
    Exit;
  end;
  
  if FileExists(DBPath) then
  begin
    if Force then
    begin
      TCliUtils.Warning('Overwriting existing database: %s', [DBPath]);
      DeleteFile(DBPath);
    end
    else
    begin
      TCliUtils.Error('Database already exists: %s', [DBPath]);
      TCliUtils.Info('Use --force to overwrite.');
      Result := 1;
      Exit;
    end;
  end;
  
  TCliUtils.EnsureDirectory(TPath.GetDirectoryName(DBPath));
  
  TCliUtils.Info('Initializing database: %s', [DBPath]);
  TCliUtils.Info('Schema tier: %d', [Tier]);
  
  Conn := CreateConnection(DBPath);
  try
    try
      Conn.Connected := True;
      ExecuteSchema(Conn, Tier);
      Conn.Connected := False;
      TCliUtils.Success('Database initialized successfully.');
    except
      on E: Exception do
      begin
        TCliUtils.Error('Failed to initialize database: %s', [E.Message]);
        Result := 1;
      end;
    end;
  finally
    Conn.Free;
  end;
end;

class function TDBCommands.DoUpgrade: Integer;
var
  DBPath: string;
  TargetTier, CurrentTier: Integer;
  Conn: TFDConnection;
begin
  Result := 0;
  
  DBPath := TCliUtils.GetOption('path', TCliUtils.GetOption('p'));
  if DBPath = '' then
  begin
    TCliUtils.Error('Database path is required. Use --path or -p option.');
    Result := 1;
    Exit;
  end;
  
  DBPath := TCliUtils.ResolvePath(DBPath);
  
  if not FileExists(DBPath) then
  begin
    TCliUtils.Error('Database not found: %s', [DBPath]);
    Result := 1;
    Exit;
  end;
  
  TargetTier := StrToIntDef(TCliUtils.GetOption('tier', TCliUtils.GetOption('t', '-1')), -1);
  
  Conn := CreateConnection(DBPath);
  try
    try
      Conn.Connected := True;
      CurrentTier := GetCurrentTier(Conn);
      
      if CurrentTier < 0 then
      begin
        TCliUtils.Error('Cannot determine current schema tier. Database may be corrupted.');
        Result := 1;
        Exit;
      end;
      
      TCliUtils.Info('Current schema tier: %d', [CurrentTier]);
      
      if TargetTier < 0 then
        TargetTier := CurrentTier + 1;
        
      if TargetTier > 2 then
        TargetTier := 2;
        
      if TargetTier <= CurrentTier then
      begin
        TCliUtils.Info('Database is already at tier %d. No upgrade needed.', [CurrentTier]);
        Exit;
      end;
      
      TCliUtils.Info('Upgrading to tier: %d', [TargetTier]);
      
      ExecuteSchema(Conn, TargetTier);
      
      Conn.Connected := False;
      TCliUtils.Success('Database upgraded to tier %d successfully.', [TargetTier]);
    except
      on E: Exception do
      begin
        TCliUtils.Error('Failed to upgrade database: %s', [E.Message]);
        Result := 1;
      end;
    end;
  finally
    Conn.Free;
  end;
end;

class function TDBCommands.DoBackup: Integer;
var
  DBPath, BackupPath: string;
  Timestamp: string;
begin
  Result := 0;
  
  DBPath := TCliUtils.GetOption('path', TCliUtils.GetOption('p'));
  if DBPath = '' then
  begin
    TCliUtils.Error('Database path is required. Use --path or -p option.');
    Result := 1;
    Exit;
  end;
  
  DBPath := TCliUtils.ResolvePath(DBPath);
  
  if not FileExists(DBPath) then
  begin
    TCliUtils.Error('Database not found: %s', [DBPath]);
    Result := 1;
    Exit;
  end;
  
  BackupPath := TCliUtils.GetOption('output', TCliUtils.GetOption('o'));
  if BackupPath = '' then
  begin
    Timestamp := FormatDateTime('yyyymmdd_hhnnss', Now);
    BackupPath := TPath.ChangeExtension(DBPath, '') + '_backup_' + Timestamp + '.db';
  end
  else
    BackupPath := TCliUtils.ResolvePath(BackupPath);
  
  TCliUtils.Info('Creating backup...');
  TCliUtils.Info('Source: %s', [DBPath]);
  TCliUtils.Info('Target: %s', [BackupPath]);
  
  try
    TCliUtils.EnsureDirectory(TPath.GetDirectoryName(BackupPath));
    TFile.Copy(DBPath, BackupPath);
    TCliUtils.Success('Backup created: %s', [BackupPath]);
  except
    on E: Exception do
    begin
      TCliUtils.Error('Failed to create backup: %s', [E.Message]);
      Result := 1;
    end;
  end;
end;

class function TDBCommands.DoCheck: Integer;
var
  DBPath: string;
  Conn: TFDConnection;
  Query: TFDQuery;
  Issues: Integer;
  Tier: Integer;
begin
  Result := 0;
  Issues := 0;
  
  DBPath := TCliUtils.GetOption('path', TCliUtils.GetOption('p'));
  if DBPath = '' then
  begin
    TCliUtils.Error('Database path is required. Use --path or -p option.');
    Result := 1;
    Exit;
  end;
  
  DBPath := TCliUtils.ResolvePath(DBPath);
  
  if not FileExists(DBPath) then
  begin
    TCliUtils.Error('Database not found: %s', [DBPath]);
    Result := 1;
    Exit;
  end;
  
  TCliUtils.Info('Checking database: %s', [DBPath]);
  
  Conn := CreateConnection(DBPath);
  Query := TFDQuery.Create(nil);
  try
    try
      Conn.Connected := True;
      Query.Connection := Conn;
      
      // Check integrity
      TCliUtils.Info('Running integrity check...');
      Query.SQL.Text := 'PRAGMA integrity_check';
      Query.Open;
      if Query.Fields[0].AsString <> 'ok' then
      begin
        TCliUtils.Error('Integrity check failed: %s', [Query.Fields[0].AsString]);
        Inc(Issues);
      end
      else
        TCliUtils.Success('Integrity check passed.');
      Query.Close;
      
      // Check schema tier
      Tier := GetCurrentTier(Conn);
      if Tier >= 0 then
        TCliUtils.Info('Schema tier: %d', [Tier])
      else
      begin
        TCliUtils.Warning('Could not determine schema tier.');
        Inc(Issues);
      end;
      
      // Check required tables
      TCliUtils.Info('Checking required tables...');
      Query.SQL.Text := 'SELECT name FROM sqlite_master WHERE type=''table'' AND name LIKE ''ub_%''';
      Query.Open;
      TCliUtils.Info('Found %d DeepBase tables.', [Query.RecordCount]);
      Query.Close;
      
      // Summary
      Writeln('');
      if Issues = 0 then
        TCliUtils.Success('Database check completed. No issues found.')
      else
      begin
        TCliUtils.Warning('Database check completed. %d issue(s) found.', [Issues]);
        Result := 1;
      end;
      
    except
      on E: Exception do
      begin
        TCliUtils.Error('Failed to check database: %s', [E.Message]);
        Result := 1;
      end;
    end;
  finally
    Query.Free;
    Conn.Free;
  end;
end;

end.
