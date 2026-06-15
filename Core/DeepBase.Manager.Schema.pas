{ ============================================================================
  DeepBase.Manager.Schema - Schema and migration helpers for TDeepBaseManager

  Version: 0.3
  Description: Keeps schema validation, compatibility patching and migration
               work outside the core manager orchestration unit.
  ============================================================================ }

unit DeepBase.Manager.Schema;

interface

uses
  System.SysUtils,
  DeepBase.Types,
  DeepBase.Logging,
  DeepBase.Storage.Interfaces;

type
  TDeepBaseManagerSchema = class
  private
    class function SplitSQLStatements(const SQL: string): TArray<string>; static;
  public
    class function GetSchemaVersion(const AStorage: IManagerStorage;
      AConnectionReady: Boolean): string; static;
    class function ValidateSchema(const AStorage: IManagerStorage;
      AConnectionReady: Boolean; const RequiredTables: array of string;
      out AErrorCode: TInitErrorCode; out ALastError: string): Boolean; static;
    class function ValidateSchemaVersion(const AStorage: IManagerStorage;
      AConnectionReady: Boolean; out AErrorCode: TInitErrorCode;
      out ALastError: string): Boolean; static;
    class function CreateSchema(const AStorage: IManagerStorage;
      AConnectionReady: Boolean; const ALogger: TDeepBaseLogger;
      out AErrorCode: TInitErrorCode; out ALastError: string): Boolean; static;
    class procedure EnsureSchemaColumns(const AStorage: IManagerStorage;
      AConnectionReady: Boolean); static;
    class function RunMigrationScript(const AStorage: IManagerStorage;
      const ScriptPath: string; out ALastError: string): Boolean; static;
    class function MigrateSchema(const AStorage: IManagerStorage;
      const RootPath, FromVersion, ToVersion: string;
      out ALastError: string): Boolean; static;
    class function CheckAndMigrateSchema(const AStorage: IManagerStorage;
      const RootPath, CurrentVersion, TargetVersion, DefaultTargetVersion: string;
      out ALastError: string): Boolean; static;
  end;

implementation

uses
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  DeepBase.Schema,
  DeepBase.SQL.Splitter;

const
  ecSchemaVersionMismatch = TInitErrorCode(10);

{ TDeepBaseManagerSchema }

class function TDeepBaseManagerSchema.SplitSQLStatements(
  const SQL: string): TArray<string>;
begin
  // BASIC-019: delegate to the shared canonical SQL splitter so that
  // Manager.Schema and DB.Migrations parse the same way (handles dollar
  // quotes, line/block comments, and CREATE TRIGGER..END bodies).
  Result := TDeepBaseSQLSplitter.Split(SQL);
end;

class function TDeepBaseManagerSchema.GetSchemaVersion(
  const AStorage: IManagerStorage; AConnectionReady: Boolean): string;
begin
  Result := '';

  if not AConnectionReady then
    Exit;
  if not Assigned(AStorage) then
    Exit;

  Result := AStorage.ReadSchemaVersion;
end;

class function TDeepBaseManagerSchema.ValidateSchema(
  const AStorage: IManagerStorage; AConnectionReady: Boolean;
  const RequiredTables: array of string; out AErrorCode: TInitErrorCode;
  out ALastError: string): Boolean;
var
  TableCount: Integer;
begin
  Result := False;
  AErrorCode := ecSuccess;
  ALastError := '';

  if not AConnectionReady then
    Exit;

  if not Assigned(AStorage) then
  begin
    AErrorCode := ecConfigDBCorrupted;
    ALastError := 'Schema validation requires manager storage registration.';
    Exit;
  end;

  TableCount := AStorage.CountCoreTables(RequiredTables);
  Result := (TableCount = Length(RequiredTables));

  if not Result then
  begin
    AErrorCode := ecConfigDBCorrupted;
    ALastError := Format('Schema validation failed: expected %d tables, found %d',
      [Length(RequiredTables), TableCount]);
    Exit;
  end;

  Result := ValidateSchemaVersion(AStorage, AConnectionReady, AErrorCode,
    ALastError);
end;

class function TDeepBaseManagerSchema.ValidateSchemaVersion(
  const AStorage: IManagerStorage; AConnectionReady: Boolean;
  out AErrorCode: TInitErrorCode; out ALastError: string): Boolean;
var
  DBVersion: string;
begin
  Result := True;
  AErrorCode := ecSuccess;
  ALastError := '';

  DBVersion := GetSchemaVersion(AStorage, AConnectionReady);
  if DBVersion = '' then
    Exit;

  if CompareVersions(DBVersion, MIN_COMPATIBLE_SCHEMA_VERSION) < 0 then
  begin
    AErrorCode := ecSchemaVersionMismatch;
    ALastError := Format(
      'Database schema version %s is too old. Minimum required: %s. ' +
      'Please upgrade your database or use CheckAndMigrateSchema.',
      [DBVersion, MIN_COMPATIBLE_SCHEMA_VERSION]);
    Result := False;
    Exit;
  end;

  if CompareVersions(DBVersion, MAX_COMPATIBLE_SCHEMA_VERSION) > 0 then
  begin
    AErrorCode := ecSchemaVersionMismatch;
    ALastError := Format(
      'Database schema version %s is newer than framework supports (max: %s). ' +
      'Please upgrade DeepBase framework.',
      [DBVersion, MAX_COMPATIBLE_SCHEMA_VERSION]);
    Result := False;
    Exit;
  end;
end;

class function TDeepBaseManagerSchema.CreateSchema(
  const AStorage: IManagerStorage; AConnectionReady: Boolean;
  const ALogger: TDeepBaseLogger; out AErrorCode: TInitErrorCode;
  out ALastError: string): Boolean;
var
  FullSQL: string;
  Statements: TArray<string>;
  Stmt: string;
  I, MaxRetry: Integer;
  ErrorMsg: string;
  LastStmt: string;
begin
  Result := False;
  AErrorCode := ecSuccess;
  ALastError := '';
  LastStmt := '';

  if not AConnectionReady then
    Exit;
  if not Assigned(AStorage) then
  begin
    AErrorCode := ecConfigDBCorrupted;
    ALastError := 'Schema creation requires manager storage registration.';
    Exit;
  end;

  MaxRetry := 2;

  for I := 1 to MaxRetry do
  begin
    FullSQL := GetFullSchemaSQL;
    Statements := SplitSQLStatements(FullSQL);

    try
      for Stmt in Statements do
      begin
        if Trim(Stmt) <> '' then
        begin
          LastStmt := Stmt;
          AStorage.ExecuteStatement(Stmt);
        end;
      end;
      try
        EnsureSchemaColumns(AStorage, AConnectionReady);
      except
        on E: Exception do
          if Assigned(ALogger) then
            ALogger.Warn('Post-schema compatibility patch failed: ' + E.Message,
              'DeepBase.Manager');
      end;
      Result := True;
      AErrorCode := ecSuccess;
      Exit;
    except
      on E: Exception do
      begin
        ErrorMsg := E.Message;
        if I < MaxRetry then
        begin
          try
            EnsureSchemaColumns(AStorage, AConnectionReady);
          except
            on E2: Exception do
              if Assigned(ALogger) then
                ALogger.Warn('Schema column fix attempt failed: ' + E2.Message,
                  'DeepBase.Manager');
          end;
        end
        else
        begin
          AErrorCode := ecConfigDBCorrupted;
          if Length(LastStmt) > 400 then
            LastStmt := Copy(LastStmt, 1, 400) + '...';
          ALastError := 'Failed to create schema: ' + ErrorMsg + sLineBreak +
                        'Statement: ' + LastStmt;
        end;
      end;
    end;
  end;
end;

class procedure TDeepBaseManagerSchema.EnsureSchemaColumns(
  const AStorage: IManagerStorage; AConnectionReady: Boolean);

  function ColumnExists(const TableName, ColumnName: string): Boolean;
  begin
    Result := Assigned(AStorage) and AStorage.ColumnExists(TableName, ColumnName);
  end;

  procedure AddColumnIfMissing(const TableName, ColumnName, ColumnDef: string);
  begin
    if not ColumnExists(TableName, ColumnName) then
    begin
      try
        AStorage.AddColumn(TableName, ColumnName, ColumnDef);
      except
        on E: Exception do
          {$IFDEF DEBUG}
          OutputDebugString(PChar('DeepBase.Manager: ALTER TABLE failed: ' + E.Message));
          {$ENDIF}
      end;
    end;
  end;

begin
  if not AConnectionReady then
    Exit;
  if not Assigned(AStorage) then
    Exit;

  AddColumnIfMissing('Settings', 'ValueType', 'TEXT DEFAULT ''String''');
  AddColumnIfMissing('Settings', 'Category', 'TEXT DEFAULT ''General''');
  AddColumnIfMissing('Settings', 'Description', 'TEXT');
  AddColumnIfMissing('Settings', 'DefaultValue', 'TEXT');
  AddColumnIfMissing('Settings', 'MinValue', 'TEXT');
  AddColumnIfMissing('Settings', 'MaxValue', 'TEXT');
  AddColumnIfMissing('Settings', 'Options', 'TEXT');
  AddColumnIfMissing('Settings', 'IsEncrypted', 'INTEGER DEFAULT 0');
  AddColumnIfMissing('Settings', 'IsReadOnly', 'INTEGER DEFAULT 0');
  AddColumnIfMissing('Settings', 'IsHidden', 'INTEGER DEFAULT 0');
  AddColumnIfMissing('Settings', 'SortOrder', 'INTEGER DEFAULT 0');
  AddColumnIfMissing('Settings', 'CreatedAt', 'TEXT');
  AddColumnIfMissing('Settings', 'UpdatedAt', 'TEXT');

  AddColumnIfMissing('Languages', 'NativeName', 'TEXT');
  AddColumnIfMissing('Languages', 'FlagIcon', 'TEXT');
  AddColumnIfMissing('Languages', 'DateFormat', 'TEXT');
  AddColumnIfMissing('Languages', 'TimeFormat', 'TEXT');
  AddColumnIfMissing('Languages', 'NumberFormat', 'TEXT');
  AddColumnIfMissing('Languages', 'CurrencySymbol', 'TEXT');
  AddColumnIfMissing('Languages', 'TextDirection', 'TEXT DEFAULT ''LTR''');
  AddColumnIfMissing('Languages', 'FontFamily', 'TEXT');
  AddColumnIfMissing('Languages', 'IsEnabled', 'INTEGER DEFAULT 1');
  AddColumnIfMissing('Languages', 'IsDefault', 'INTEGER DEFAULT 0');
  AddColumnIfMissing('Languages', 'IsComplete', 'INTEGER DEFAULT 0');
  AddColumnIfMissing('Languages', 'SortOrder', 'INTEGER DEFAULT 0');

  AddColumnIfMissing('Logs', 'LogTime', 'TEXT');
  AddColumnIfMissing('Logs', 'LogLevel', 'TEXT');
  AddColumnIfMissing('Logs', 'Source', 'TEXT');
  AddColumnIfMissing('Logs', 'ExceptionClass', 'TEXT');
  AddColumnIfMissing('Logs', 'ExceptionMessage', 'TEXT');
  AddColumnIfMissing('Logs', 'ThreadId', 'INTEGER');
  AddColumnIfMissing('Logs', 'UserId', 'TEXT');

  AddColumnIfMissing('MRU', 'ItemKey', 'TEXT');
  AddColumnIfMissing('MRU', 'DisplayName', 'TEXT');
  AddColumnIfMissing('MRU', 'IconIndex', 'INTEGER DEFAULT 0');
  AddColumnIfMissing('MRU', 'IsPinned', 'INTEGER DEFAULT 0');
  AddColumnIfMissing('MRU', 'Extra', 'TEXT');
  if ColumnExists('MRU', 'ItemPath') and ColumnExists('MRU', 'ItemKey') then
  begin
    try
      AStorage.ExecuteStatement(
        'UPDATE MRU SET ItemKey = ItemPath ' +
        'WHERE (ItemKey IS NULL OR ItemKey = '''') ' +
        'AND ItemPath IS NOT NULL AND ItemPath <> ''''');
    except
      on E: Exception do
        {$IFDEF DEBUG}
        OutputDebugString(PChar('DeepBase.Manager: MRU ItemPath->ItemKey migration failed: ' + E.Message));
        {$ENDIF}
    end;
  end;
  if ColumnExists('MRU', 'ItemKey') then
  begin
    try
      AStorage.ExecuteStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_mru_category_itemkey ' +
        'ON MRU(Category, ItemKey)');
    except
      on E: Exception do
        {$IFDEF DEBUG}
        OutputDebugString(PChar('DeepBase.Manager: MRU unique index patch failed: ' + E.Message));
        {$ENDIF}
    end;
  end;

  AddColumnIfMissing('FormStates', 'MonitorIndex', 'INTEGER DEFAULT 0');
  AddColumnIfMissing('FormStates', 'Splitters', 'TEXT');
  AddColumnIfMissing('FormStates', 'Columns', 'TEXT');
  AddColumnIfMissing('FormStates', 'TabIndex', 'INTEGER DEFAULT 0');
  AddColumnIfMissing('FormStates', 'ScrollPos', 'TEXT');
  AddColumnIfMissing('FormStates', 'LastAccess', 'TEXT');
  AddColumnIfMissing('FormStates', 'Extra', 'TEXT');

  AddColumnIfMissing('Hotkeys', 'Description', 'TEXT');
  AddColumnIfMissing('Hotkeys', 'Category', 'TEXT');
  AddColumnIfMissing('Hotkeys', 'IsCustomized', 'INTEGER DEFAULT 0');

  AddColumnIfMissing('Themes', 'DisplayName', 'TEXT');
  AddColumnIfMissing('Themes', 'StyleFile', 'TEXT');
  AddColumnIfMissing('Themes', 'AccentColor', 'INTEGER');
  AddColumnIfMissing('Themes', 'CustomCSS', 'TEXT');

  AddColumnIfMissing('LLMConfig', 'ContextWindow', 'INTEGER DEFAULT 4096');
  AddColumnIfMissing('LLMConfig', 'PricePer1kPrompt', 'REAL DEFAULT 0');
  AddColumnIfMissing('LLMConfig', 'PricePer1kCompletion', 'REAL DEFAULT 0');

  AddColumnIfMissing('LLMCalls', 'CallTime', 'TEXT');
  AddColumnIfMissing('LLMCalls', 'Prompt', 'TEXT');
  AddColumnIfMissing('LLMCalls', 'Response', 'TEXT');
  AddColumnIfMissing('LLMCalls', 'EstimatedCost', 'REAL DEFAULT 0');
  AddColumnIfMissing('LLMCalls', 'DurationMs', 'INTEGER DEFAULT 0');
  AddColumnIfMissing('LLMCalls', 'Success', 'INTEGER DEFAULT 1');
  AddColumnIfMissing('LLMCalls', 'ErrorCode', 'TEXT');
  AddColumnIfMissing('LLMCalls', 'CallerModule', 'TEXT');
  AddColumnIfMissing('LLMCalls', 'CallerFunction', 'TEXT');

  AddColumnIfMissing('LLMPromptTemplates', 'DefaultValues', 'TEXT');
  AddColumnIfMissing('LLMPromptTemplates', 'ParentTemplate', 'TEXT');
  AddColumnIfMissing('LLMPromptTemplates', 'IncludeTemplates', 'TEXT');
  AddColumnIfMissing('LLMPromptTemplates', 'OutputFormat', 'TEXT DEFAULT ''text''');
  AddColumnIfMissing('LLMPromptTemplates', 'ValidationRegex', 'TEXT');
  AddColumnIfMissing('LLMPromptTemplates', 'Examples', 'TEXT');
  AddColumnIfMissing('LLMPromptTemplates', 'RecommendedConfig', 'TEXT');
  AddColumnIfMissing('LLMPromptTemplates', 'RecommendedModel', 'TEXT');
  AddColumnIfMissing('LLMPromptTemplates', 'MaxTokens', 'INTEGER DEFAULT 0');
end;

class function TDeepBaseManagerSchema.RunMigrationScript(
  const AStorage: IManagerStorage; const ScriptPath: string;
  out ALastError: string): Boolean;
var
  ScriptSQL, Stmt: string;
  Statements: TArray<string>;
begin
  Result := False;
  ALastError := '';

  if not TFile.Exists(ScriptPath) then
  begin
    ALastError := 'Migration script not found: ' + ScriptPath;
    Exit;
  end;

  try
    ScriptSQL := TFile.ReadAllText(ScriptPath, TEncoding.UTF8);

    // BASIC-019: shared canonical splitter handles dollar quotes,
    // line/block comments, escaped quotes, and trigger bodies.
    Statements := TDeepBaseSQLSplitter.Split(ScriptSQL);

    if not Assigned(AStorage) then
    begin
      ALastError := 'Migration requires manager storage registration.';
      Exit(False);
    end;

    for Stmt in Statements do
    begin
      if Trim(Stmt) <> '' then
        AStorage.ExecuteStatement(Stmt);
    end;
    Result := True;
  except
    on E: Exception do
      ALastError := 'Migration script error: ' + E.Message;
  end;
end;

class function TDeepBaseManagerSchema.MigrateSchema(
  const AStorage: IManagerStorage; const RootPath, FromVersion,
  ToVersion: string; out ALastError: string): Boolean;
var
  ScriptPath: string;
  UpgradeTimeISO: string;
begin
  Result := False;
  ALastError := '';

  ScriptPath := TPath.Combine(RootPath, 'sql');
  ScriptPath := TPath.Combine(ScriptPath,
    Format('upgrade_v%s_to_v%s.sql', [
      StringReplace(FromVersion, '.', '_', [rfReplaceAll]),
      StringReplace(ToVersion, '.', '_', [rfReplaceAll])
    ]));

  if not RunMigrationScript(AStorage, ScriptPath, ALastError) then
    Exit;

  UpgradeTimeISO := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now);
  if not Assigned(AStorage) then
  begin
    ALastError := 'Schema migration requires manager storage registration.';
    Exit(False);
  end;

  AStorage.UpdateSchemaInfo(ToVersion, UpgradeTimeISO);
  Result := True;
end;

class function TDeepBaseManagerSchema.CheckAndMigrateSchema(
  const AStorage: IManagerStorage; const RootPath, CurrentVersion,
  TargetVersion, DefaultTargetVersion: string; out ALastError: string): Boolean;
var
  CurrentVer, Target: string;
  VersionParts: TArray<string>;
  CurrentMajor, CurrentMinor: Integer;
  TargetMajor, TargetMinor: Integer;
  MigrationError: string;
begin
  Result := True;
  ALastError := '';
  CurrentVer := CurrentVersion;

  if CurrentVer = '' then
  begin
    ALastError := 'Cannot determine current schema version';
    Result := False;
    Exit;
  end;

  if TargetVersion = '' then
    Target := DefaultTargetVersion
  else
    Target := TargetVersion;

  if CurrentVer = Target then
    Exit;

  VersionParts := CurrentVer.Split(['.']);
  if Length(VersionParts) >= 2 then
  begin
    TryStrToInt(VersionParts[0], CurrentMajor);
    TryStrToInt(VersionParts[1], CurrentMinor);
  end
  else
  begin
    CurrentMajor := 0;
    CurrentMinor := 0;
  end;

  VersionParts := Target.Split(['.']);
  if Length(VersionParts) >= 2 then
  begin
    TryStrToInt(VersionParts[0], TargetMajor);
    TryStrToInt(VersionParts[1], TargetMinor);
  end
  else
  begin
    TargetMajor := 0;
    TargetMinor := 0;
  end;

  if (TargetMajor < CurrentMajor) or
     ((TargetMajor = CurrentMajor) and (TargetMinor < CurrentMinor)) then
  begin
    ALastError := Format('Downgrade not supported: %s -> %s',
      [CurrentVer, Target]);
    Result := False;
    Exit;
  end;

  MigrationError := '';
  Result := MigrateSchema(AStorage, RootPath, CurrentVer, Target,
    MigrationError);

  if not Result then
    ALastError := Format('Migration failed: %s -> %s. %s',
      [CurrentVer, Target, MigrationError]);
end;

end.
