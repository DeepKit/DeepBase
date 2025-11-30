{ ============================================================================
  CLI.Config - 配置管理命令
  
  版本: 1.0
  说明: 实现 config get/set/export/import 命令
  ============================================================================ }

unit CLI.Config;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.JSON,
  System.IniFiles,
  FireDAC.Comp.Client,
  FireDAC.Stan.Def,
  FireDAC.Stan.Async,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  CLI.Commands;

type
  TConfigCommands = class
  private
    class procedure ShowHelp;
    class function DoGet: Integer;
    class function DoSet: Integer;
    class function DoExport: Integer;
    class function DoImport: Integer;
    class function CreateConnection(const DBPath: string): TFDConnection;
    class function GetConfigValue(Conn: TFDConnection; const Section, Key: string): string;
    class procedure SetConfigValue(Conn: TFDConnection; const Section, Key, Value: string);
    class procedure EnsureConfigTable(Conn: TFDConnection);
  public
    class function Execute: Integer;
  end;

implementation

{ TConfigCommands }

class function TConfigCommands.Execute: Integer;
var
  SubCmd: string;
begin
  SubCmd := TCliUtils.GetSubCommand;
  
  if (SubCmd = '') or (SubCmd = 'help') or TCliUtils.HasOption('help') or TCliUtils.HasOption('h') then
  begin
    ShowHelp;
    Result := 0;
  end
  else if SubCmd = 'get' then
    Result := DoGet
  else if SubCmd = 'set' then
    Result := DoSet
  else if SubCmd = 'export' then
    Result := DoExport
  else if SubCmd = 'import' then
    Result := DoImport
  else
  begin
    TCliUtils.Error('Unknown config subcommand: %s', [SubCmd]);
    ShowHelp;
    Result := 1;
  end;
end;

class procedure TConfigCommands.ShowHelp;
begin
  Writeln('Configuration Management Commands');
  Writeln('');
  Writeln('Usage: unibase config <subcommand> [options]');
  Writeln('');
  Writeln('Subcommands:');
  Writeln('  get       Get a configuration value');
  Writeln('  set       Set a configuration value');
  Writeln('  export    Export all configuration to a file');
  Writeln('  import    Import configuration from a file');
  Writeln('');
  Writeln('Options for get:');
  Writeln('  --db, -d <path>     Database file path (required)');
  Writeln('  <section.key>       Configuration key to get (positional arg)');
  Writeln('');
  Writeln('Options for set:');
  Writeln('  --db, -d <path>     Database file path (required)');
  Writeln('  <section.key>       Configuration key to set (positional arg)');
  Writeln('  <value>             Value to set (positional arg)');
  Writeln('');
  Writeln('Options for export:');
  Writeln('  --db, -d <path>     Database file path (required)');
  Writeln('  --output, -o <file> Output file path (required)');
  Writeln('  --format, -f <fmt>  Output format: json, ini (default: json)');
  Writeln('  --section, -s <sec> Export only specific section');
  Writeln('');
  Writeln('Options for import:');
  Writeln('  --db, -d <path>     Database file path (required)');
  Writeln('  --input, -i <file>  Input file path (required)');
  Writeln('  --format, -f <fmt>  Input format: json, ini (default: auto-detect)');
  Writeln('  --merge             Merge with existing config (default: replace)');
  Writeln('');
  Writeln('Examples:');
  Writeln('  unibase config get --db myapp.db app.theme');
  Writeln('  unibase config set --db myapp.db app.theme dark');
  Writeln('  unibase config export --db myapp.db -o config.json');
  Writeln('  unibase config import --db myapp.db -i config.json --merge');
end;

class function TConfigCommands.CreateConnection(const DBPath: string): TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  Result.DriverName := 'SQLite';
  Result.Params.Database := DBPath;
  Result.Params.Values['LockingMode'] := 'Normal';
  Result.LoginPrompt := False;
end;

class procedure TConfigCommands.EnsureConfigTable(Conn: TFDConnection);
begin
  Conn.ExecSQL(
    'CREATE TABLE IF NOT EXISTS ub_config (' +
    '  section TEXT NOT NULL,' +
    '  key TEXT NOT NULL,' +
    '  value TEXT,' +
    '  value_type INTEGER DEFAULT 0,' +
    '  updated_at TEXT,' +
    '  PRIMARY KEY (section, key)' +
    ')'
  );
end;

class function TConfigCommands.GetConfigValue(Conn: TFDConnection; const Section, Key: string): string;
var
  Query: TFDQuery;
begin
  Result := '';
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := Conn;
    Query.SQL.Text := 'SELECT value FROM ub_config WHERE section = :section AND key = :key';
    Query.ParamByName('section').AsString := Section;
    Query.ParamByName('key').AsString := Key;
    Query.Open;
    
    if not Query.Eof then
      Result := Query.Fields[0].AsString;
  finally
    Query.Free;
  end;
end;

class procedure TConfigCommands.SetConfigValue(Conn: TFDConnection; const Section, Key, Value: string);
begin
  Conn.ExecSQL(
    'INSERT OR REPLACE INTO ub_config (section, key, value, updated_at) ' +
    'VALUES (:section, :key, :value, :updated_at)',
    [Section, Key, Value, FormatDateTime('yyyy-mm-dd hh:nn:ss', Now)]
  );
end;

class function TConfigCommands.DoGet: Integer;
var
  DBPath, KeyPath, Section, Key, Value: string;
  Conn: TFDConnection;
  DotPos: Integer;
begin
  Result := 0;
  
  DBPath := TCliUtils.GetOption('db', TCliUtils.GetOption('d'));
  if DBPath = '' then
  begin
    TCliUtils.Error('Database path is required. Use --db or -d option.');
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
  
  KeyPath := TCliUtils.GetArg(0);
  if KeyPath = '' then
  begin
    TCliUtils.Error('Configuration key is required (e.g., app.theme).');
    Result := 1;
    Exit;
  end;
  
  // Parse section.key
  DotPos := Pos('.', KeyPath);
  if DotPos > 0 then
  begin
    Section := Copy(KeyPath, 1, DotPos - 1);
    Key := Copy(KeyPath, DotPos + 1, MaxInt);
  end
  else
  begin
    Section := 'app';
    Key := KeyPath;
  end;
  
  Conn := CreateConnection(DBPath);
  try
    try
      Conn.Connected := True;
      Value := GetConfigValue(Conn, Section, Key);
      
      if Value <> '' then
        Writeln(Value)
      else
      begin
        TCliUtils.Warning('Key not found: %s.%s', [Section, Key]);
        Result := 1;
      end;
    except
      on E: Exception do
      begin
        TCliUtils.Error('Failed to get config: %s', [E.Message]);
        Result := 1;
      end;
    end;
  finally
    Conn.Free;
  end;
end;

class function TConfigCommands.DoSet: Integer;
var
  DBPath, KeyPath, Value, Section, Key: string;
  Conn: TFDConnection;
  DotPos: Integer;
begin
  Result := 0;
  
  DBPath := TCliUtils.GetOption('db', TCliUtils.GetOption('d'));
  if DBPath = '' then
  begin
    TCliUtils.Error('Database path is required. Use --db or -d option.');
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
  
  KeyPath := TCliUtils.GetArg(0);
  if KeyPath = '' then
  begin
    TCliUtils.Error('Configuration key is required (e.g., app.theme).');
    Result := 1;
    Exit;
  end;
  
  Value := TCliUtils.GetArg(1);
  if Value = '' then
  begin
    TCliUtils.Error('Value is required.');
    Result := 1;
    Exit;
  end;
  
  // Parse section.key
  DotPos := Pos('.', KeyPath);
  if DotPos > 0 then
  begin
    Section := Copy(KeyPath, 1, DotPos - 1);
    Key := Copy(KeyPath, DotPos + 1, MaxInt);
  end
  else
  begin
    Section := 'app';
    Key := KeyPath;
  end;
  
  Conn := CreateConnection(DBPath);
  try
    try
      Conn.Connected := True;
      EnsureConfigTable(Conn);
      SetConfigValue(Conn, Section, Key, Value);
      TCliUtils.Success('%s.%s = %s', [Section, Key, Value]);
    except
      on E: Exception do
      begin
        TCliUtils.Error('Failed to set config: %s', [E.Message]);
        Result := 1;
      end;
    end;
  finally
    Conn.Free;
  end;
end;

class function TConfigCommands.DoExport: Integer;
var
  DBPath, OutputFile, Format, FilterSection: string;
  Conn: TFDConnection;
  Query: TFDQuery;
  JsonRoot, JsonSection: TJSONObject;
  IniFile: TMemIniFile;
  CurrentSection: string;
begin
  Result := 0;
  
  DBPath := TCliUtils.GetOption('db', TCliUtils.GetOption('d'));
  if DBPath = '' then
  begin
    TCliUtils.Error('Database path is required. Use --db or -d option.');
    Result := 1;
    Exit;
  end;
  
  OutputFile := TCliUtils.GetOption('output', TCliUtils.GetOption('o'));
  if OutputFile = '' then
  begin
    TCliUtils.Error('Output file is required. Use --output or -o option.');
    Result := 1;
    Exit;
  end;
  
  DBPath := TCliUtils.ResolvePath(DBPath);
  OutputFile := TCliUtils.ResolvePath(OutputFile);
  Format := LowerCase(TCliUtils.GetOption('format', TCliUtils.GetOption('f', 'json')));
  FilterSection := TCliUtils.GetOption('section', TCliUtils.GetOption('s'));
  
  if not FileExists(DBPath) then
  begin
    TCliUtils.Error('Database not found: %s', [DBPath]);
    Result := 1;
    Exit;
  end;
  
  TCliUtils.Info('Exporting configuration...');
  TCliUtils.Info('Database: %s', [DBPath]);
  TCliUtils.Info('Output: %s', [OutputFile]);
  TCliUtils.Info('Format: %s', [Format]);
  
  Conn := CreateConnection(DBPath);
  Query := TFDQuery.Create(nil);
  try
    try
      Conn.Connected := True;
      Query.Connection := Conn;
      
      if FilterSection <> '' then
        Query.SQL.Text := 'SELECT section, key, value FROM ub_config WHERE section = :section ORDER BY section, key'
      else
        Query.SQL.Text := 'SELECT section, key, value FROM ub_config ORDER BY section, key';
        
      if FilterSection <> '' then
        Query.ParamByName('section').AsString := FilterSection;
        
      Query.Open;
      
      if Format = 'json' then
      begin
        JsonRoot := TJSONObject.Create;
        try
          CurrentSection := '';
          JsonSection := nil;
          
          while not Query.Eof do
          begin
            if Query.FieldByName('section').AsString <> CurrentSection then
            begin
              CurrentSection := Query.FieldByName('section').AsString;
              JsonSection := TJSONObject.Create;
              JsonRoot.AddPair(CurrentSection, JsonSection);
            end;
            
            if Assigned(JsonSection) then
              JsonSection.AddPair(Query.FieldByName('key').AsString, 
                                  Query.FieldByName('value').AsString);
            
            Query.Next;
          end;
          
          TCliUtils.EnsureDirectory(TPath.GetDirectoryName(OutputFile));
          TFile.WriteAllText(OutputFile, JsonRoot.Format(2), TEncoding.UTF8);
        finally
          JsonRoot.Free;
        end;
      end
      else if Format = 'ini' then
      begin
        IniFile := TMemIniFile.Create('');
        try
          while not Query.Eof do
          begin
            IniFile.WriteString(
              Query.FieldByName('section').AsString,
              Query.FieldByName('key').AsString,
              Query.FieldByName('value').AsString
            );
            Query.Next;
          end;
          
          TCliUtils.EnsureDirectory(TPath.GetDirectoryName(OutputFile));
          IniFile.UpdateFile;
          IniFile.Rename(OutputFile, True);
        finally
          IniFile.Free;
        end;
      end
      else
      begin
        TCliUtils.Error('Unknown format: %s. Supported formats: json, ini', [Format]);
        Result := 1;
        Exit;
      end;
      
      TCliUtils.Success('Configuration exported: %d entries.', [Query.RecordCount]);
    except
      on E: Exception do
      begin
        TCliUtils.Error('Failed to export config: %s', [E.Message]);
        Result := 1;
      end;
    end;
  finally
    Query.Free;
    Conn.Free;
  end;
end;

class function TConfigCommands.DoImport: Integer;
var
  DBPath, InputFile, Format: string;
  Merge: Boolean;
  Conn: TFDConnection;
  JsonStr: string;
  JsonRoot, JsonSection: TJSONObject;
  SectionPair, KeyPair: TJSONPair;
  IniFile: TMemIniFile;
  Sections, Keys: TStringList;
  I, J, ImportCount: Integer;
begin
  Result := 0;
  
  DBPath := TCliUtils.GetOption('db', TCliUtils.GetOption('d'));
  if DBPath = '' then
  begin
    TCliUtils.Error('Database path is required. Use --db or -d option.');
    Result := 1;
    Exit;
  end;
  
  InputFile := TCliUtils.GetOption('input', TCliUtils.GetOption('i'));
  if InputFile = '' then
  begin
    TCliUtils.Error('Input file is required. Use --input or -i option.');
    Result := 1;
    Exit;
  end;
  
  DBPath := TCliUtils.ResolvePath(DBPath);
  InputFile := TCliUtils.ResolvePath(InputFile);
  Merge := TCliUtils.HasOption('merge');
  
  // Auto-detect format
  Format := LowerCase(TCliUtils.GetOption('format', TCliUtils.GetOption('f')));
  if Format = '' then
  begin
    if LowerCase(TPath.GetExtension(InputFile)) = '.ini' then
      Format := 'ini'
    else
      Format := 'json';
  end;
  
  if not FileExists(DBPath) then
  begin
    TCliUtils.Error('Database not found: %s', [DBPath]);
    Result := 1;
    Exit;
  end;
  
  if not FileExists(InputFile) then
  begin
    TCliUtils.Error('Input file not found: %s', [InputFile]);
    Result := 1;
    Exit;
  end;
  
  TCliUtils.Info('Importing configuration...');
  TCliUtils.Info('Input: %s', [InputFile]);
  TCliUtils.Info('Database: %s', [DBPath]);
  TCliUtils.Info('Format: %s', [Format]);
  TCliUtils.Info('Mode: %s', [IfThen(Merge, 'merge', 'replace')]);
  
  Conn := CreateConnection(DBPath);
  try
    try
      Conn.Connected := True;
      EnsureConfigTable(Conn);
      
      // Clear existing config if not merging
      if not Merge then
        Conn.ExecSQL('DELETE FROM ub_config');
      
      ImportCount := 0;
      
      if Format = 'json' then
      begin
        JsonStr := TFile.ReadAllText(InputFile, TEncoding.UTF8);
        JsonRoot := TJSONObject.ParseJSONValue(JsonStr) as TJSONObject;
        
        if Assigned(JsonRoot) then
        try
          for SectionPair in JsonRoot do
          begin
            if SectionPair.JsonValue is TJSONObject then
            begin
              JsonSection := SectionPair.JsonValue as TJSONObject;
              for KeyPair in JsonSection do
              begin
                SetConfigValue(Conn, SectionPair.JsonString.Value, 
                              KeyPair.JsonString.Value, KeyPair.JsonValue.Value);
                Inc(ImportCount);
              end;
            end;
          end;
        finally
          JsonRoot.Free;
        end;
      end
      else if Format = 'ini' then
      begin
        IniFile := TMemIniFile.Create(InputFile);
        Sections := TStringList.Create;
        Keys := TStringList.Create;
        try
          IniFile.ReadSections(Sections);
          for I := 0 to Sections.Count - 1 do
          begin
            Keys.Clear;
            IniFile.ReadSection(Sections[I], Keys);
            for J := 0 to Keys.Count - 1 do
            begin
              SetConfigValue(Conn, Sections[I], Keys[J], 
                            IniFile.ReadString(Sections[I], Keys[J], ''));
              Inc(ImportCount);
            end;
          end;
        finally
          Keys.Free;
          Sections.Free;
          IniFile.Free;
        end;
      end
      else
      begin
        TCliUtils.Error('Unknown format: %s. Supported formats: json, ini', [Format]);
        Result := 1;
        Exit;
      end;
      
      TCliUtils.Success('Configuration imported: %d entries.', [ImportCount]);
    except
      on E: Exception do
      begin
        TCliUtils.Error('Failed to import config: %s', [E.Message]);
        Result := 1;
      end;
    end;
  finally
    Conn.Free;
  end;
end;

end.
