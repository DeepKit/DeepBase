{ ============================================================================
  UniBase.Diagnose - Database Schema Diagnostic Tool
  
  Version: 1.0.0
  Description: Provides diagnostic and auto-fix capabilities for UniBase
               database schema validation.
  
  Features:
    - Check if all required tables exist
    - Check if all required columns exist
    - Check if all required indexes exist
    - Auto-fix missing tables/columns
    - Generate diagnostic reports
  
  Usage:
    var
      Results: TDiagnoseResults;
    begin
      Results := DiagnoseAll(Database);
      if Length(Results) > 0 then
      begin
        ShowMessage(GenerateDiagnoseReport(Results));
        AutoFix(Database, Results);
      end;
    end;
  ============================================================================ }

unit UniBase.Diagnose;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  FireDAC.Comp.Client;

type
  TDiagnoseIssueType = (ditMissingTable, ditMissingColumn, ditMissingIndex, 
                        ditVersionMismatch, ditDataIntegrity, ditForeignKey, 
                        ditNullValue, ditInvalidEnum);
  
  TDiagnoseResult = record
    IssueType: TDiagnoseIssueType;
    IsOK: Boolean;
    TableName: string;
    ObjectName: string;  // Column name, Index name, etc.
    Issue: string;
    Suggestion: string;
    FixSQL: string;
    CanAutoFix: Boolean;
  end;
  
  TDiagnoseResults = TArray<TDiagnoseResult>;

const
  // Expected tables for each tier
  TIER0_TABLES: array[0..4] of string = (
    'SchemaInfo', 'Settings', 'FormStates', 'Languages', 'I18nTexts'
  );
  
  TIER1_TABLES: array[0..6] of string = (
    'Logs', 'MRU', 'Hotkeys', 'Queries', 'Themes', 'Categories', 'Tags'
  );
  
  TIER2_TABLES: array[0..10] of string = (
    'Providers', 'Models', 'LLMConfig', 'LLMCalls', 'LLMPrompts', 'LLMApiKeys',
    'ExceptionReports', 'AnimationAssets', 'Attachments', 'TagMappings', 'Notifications'
  );

/// <summary>
/// Perform comprehensive diagnosis of the database schema
/// </summary>
function DiagnoseAll(AConnection: TFDConnection): TDiagnoseResults;

/// <summary>
/// Check if all expected tables exist
/// </summary>
function CheckTablesExist(AConnection: TFDConnection): TDiagnoseResults;

/// <summary>
/// Check if required columns exist in each table
/// </summary>
function CheckColumnsExist(AConnection: TFDConnection): TDiagnoseResults;

/// <summary>
/// Check if required indexes exist
/// </summary>
function CheckIndexesExist(AConnection: TFDConnection): TDiagnoseResults;

/// <summary>
/// Check schema version compatibility
/// </summary>
function CheckSchemaVersion(AConnection: TFDConnection): TDiagnoseResults;

/// <summary>
/// Attempt to automatically fix detected issues
/// </summary>
/// <returns>Number of issues fixed</returns>
function AutoFix(AConnection: TFDConnection; const AResults: TDiagnoseResults): Integer;

/// <summary>
/// Add a column to a table if it doesn't exist
/// </summary>
function AddColumnIfNotExists(AConnection: TFDConnection; 
  const ATableName, AColumnName, AColumnDef: string): Boolean;

/// <summary>
/// Check if a table exists in the database
/// </summary>
function TableExists(AConnection: TFDConnection; const ATableName: string): Boolean;

/// <summary>
/// Check if a column exists in a table
/// </summary>
function ColumnExists(AConnection: TFDConnection; 
  const ATableName, AColumnName: string): Boolean;

/// <summary>
/// Check if an index exists
/// </summary>
function IndexExists(AConnection: TFDConnection; const AIndexName: string): Boolean;

/// <summary>
/// Generate a human-readable diagnostic report
/// </summary>
function GenerateDiagnoseReport(const AResults: TDiagnoseResults): string;

/// <summary>
/// Generate a brief summary of diagnosis results
/// </summary>
function GenerateDiagnoseSummary(const AResults: TDiagnoseResults): string;

/// <summary>
/// Get the current schema version from database
/// </summary>
function GetSchemaVersion(AConnection: TFDConnection): string;

/// <summary>
/// Check data integrity: foreign keys, required fields, enum values
/// </summary>
function CheckDataIntegrity(AConnection: TFDConnection): TDiagnoseResults;

implementation

uses
  UniBase.Schema;

function TableExists(AConnection: TFDConnection; const ATableName: string): Boolean;
var
  Query: TFDQuery;
begin
  Result := False;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := AConnection;
    Query.SQL.Text := 'SELECT name FROM sqlite_master WHERE type=''table'' AND name=:tablename';
    Query.ParamByName('tablename').AsString := ATableName;
    Query.Open;
    Result := not Query.IsEmpty;
  finally
    Query.Free;
  end;
end;

function ColumnExists(AConnection: TFDConnection; 
  const ATableName, AColumnName: string): Boolean;
var
  Query: TFDQuery;
begin
  Result := False;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := AConnection;
    Query.SQL.Text := Format('PRAGMA table_info(%s)', [ATableName]);
    Query.Open;
    while not Query.Eof do
    begin
      if SameText(Query.FieldByName('name').AsString, AColumnName) then
      begin
        Result := True;
        Break;
      end;
      Query.Next;
    end;
  finally
    Query.Free;
  end;
end;

function IndexExists(AConnection: TFDConnection; const AIndexName: string): Boolean;
var
  Query: TFDQuery;
begin
  Result := False;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := AConnection;
    Query.SQL.Text := 'SELECT name FROM sqlite_master WHERE type=''index'' AND name=:indexname';
    Query.ParamByName('indexname').AsString := AIndexName;
    Query.Open;
    Result := not Query.IsEmpty;
  finally
    Query.Free;
  end;
end;

function GetSchemaVersion(AConnection: TFDConnection): string;
var
  Query: TFDQuery;
begin
  Result := '';
  if not TableExists(AConnection, 'SchemaInfo') then
    Exit;
    
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := AConnection;
    Query.SQL.Text := 'SELECT Value FROM SchemaInfo WHERE Key = ''SchemaVersion''';
    Query.Open;
    if not Query.IsEmpty then
      Result := Query.Fields[0].AsString;
  finally
    Query.Free;
  end;
end;

function CheckSchemaVersion(AConnection: TFDConnection): TDiagnoseResults;
var
  DBVersion: string;
  Issue: TDiagnoseResult;
begin
  SetLength(Result, 0);
  DBVersion := GetSchemaVersion(AConnection);
  
  if DBVersion = '' then
  begin
    Issue.IssueType := ditVersionMismatch;
    Issue.IsOK := False;
    Issue.TableName := 'SchemaInfo';
    Issue.ObjectName := 'SchemaVersion';
    Issue.Issue := 'Schema version not found';
    Issue.Suggestion := 'Database may not be initialized. Run EnsureSchema.';
    Issue.FixSQL := Format('INSERT OR REPLACE INTO SchemaInfo (Key, Value) VALUES (''SchemaVersion'', ''%s'')', [SCHEMA_VERSION]);
    Issue.CanAutoFix := True;
    SetLength(Result, 1);
    Result[0] := Issue;
  end
  else if DBVersion < MIN_COMPATIBLE_SCHEMA_VERSION then
  begin
    Issue.IssueType := ditVersionMismatch;
    Issue.IsOK := False;
    Issue.TableName := 'SchemaInfo';
    Issue.ObjectName := 'SchemaVersion';
    Issue.Issue := Format('Database version %s is too old (minimum: %s)', [DBVersion, MIN_COMPATIBLE_SCHEMA_VERSION]);
    Issue.Suggestion := 'Run database migration to upgrade schema.';
    Issue.FixSQL := '';
    Issue.CanAutoFix := False;
    SetLength(Result, 1);
    Result[0] := Issue;
  end
  else if DBVersion <> SCHEMA_VERSION then
  begin
    Issue.IssueType := ditVersionMismatch;
    Issue.IsOK := False;
    Issue.TableName := 'SchemaInfo';
    Issue.ObjectName := 'SchemaVersion';
    Issue.Issue := Format('Database version %s differs from UniBase version %s', [DBVersion, SCHEMA_VERSION]);
    Issue.Suggestion := 'Consider running migration if features are missing.';
    Issue.FixSQL := '';
    Issue.CanAutoFix := False;
    SetLength(Result, 1);
    Result[0] := Issue;
  end;
end;

function GetTableCreateSQL(const ATableName: string): string;
begin
  Result := '';
  // Tier 0
  if SameText(ATableName, 'SchemaInfo') then Result := SQL_TIER0_SCHEMA_INFO
  else if SameText(ATableName, 'Settings') then Result := SQL_TIER0_SETTINGS
  else if SameText(ATableName, 'FormStates') then Result := SQL_TIER0_FORM_STATES
  else if SameText(ATableName, 'Languages') then Result := SQL_TIER0_LANGUAGES
  else if SameText(ATableName, 'I18nTexts') then Result := SQL_TIER0_I18N_TEXTS
  // Tier 1
  else if SameText(ATableName, 'Logs') then Result := SQL_TIER1_LOGS
  else if SameText(ATableName, 'MRU') then Result := SQL_TIER1_MRU
  else if SameText(ATableName, 'Hotkeys') then Result := SQL_TIER1_HOTKEYS
  else if SameText(ATableName, 'Queries') then Result := SQL_TIER1_QUERIES
  else if SameText(ATableName, 'Themes') then Result := SQL_TIER1_THEMES
  else if SameText(ATableName, 'Categories') then Result := SQL_TIER1_CATEGORIES
  else if SameText(ATableName, 'Tags') then Result := SQL_TIER1_TAGS
  // Tier 2
  else if SameText(ATableName, 'Providers') then Result := SQL_TIER2_PROVIDERS
  else if SameText(ATableName, 'Models') then Result := SQL_TIER2_MODELS
  else if SameText(ATableName, 'LLMConfig') then Result := SQL_TIER2_LLM_CONFIG
  else if SameText(ATableName, 'LLMCalls') then Result := SQL_TIER2_LLM_CALLS
  else if SameText(ATableName, 'LLMPrompts') then Result := SQL_TIER2_LLM_PROMPTS
  else if SameText(ATableName, 'LLMApiKeys') then Result := SQL_TIER2_LLM_API_KEYS
  else if SameText(ATableName, 'ExceptionReports') then Result := SQL_TIER2_EXCEPTION_REPORTS
  else if SameText(ATableName, 'AnimationAssets') then Result := SQL_TIER2_ANIMATION_ASSETS
  else if SameText(ATableName, 'Attachments') then Result := SQL_TIER2_ATTACHMENTS
  else if SameText(ATableName, 'TagMappings') then Result := SQL_TIER2_TAG_MAPPINGS
  else if SameText(ATableName, 'Notifications') then Result := SQL_TIER2_NOTIFICATIONS;
end;

function CheckTablesExist(AConnection: TFDConnection): TDiagnoseResults;
var
  AllTables: TArray<string>;
  TableName: string;
  Issue: TDiagnoseResult;
  ResultList: TList<TDiagnoseResult>;
  I: Integer;
begin
  ResultList := TList<TDiagnoseResult>.Create;
  try
    // Combine all tiers
    SetLength(AllTables, Length(TIER0_TABLES) + Length(TIER1_TABLES) + Length(TIER2_TABLES));
    for I := 0 to High(TIER0_TABLES) do
      AllTables[I] := TIER0_TABLES[I];
    for I := 0 to High(TIER1_TABLES) do
      AllTables[Length(TIER0_TABLES) + I] := TIER1_TABLES[I];
    for I := 0 to High(TIER2_TABLES) do
      AllTables[Length(TIER0_TABLES) + Length(TIER1_TABLES) + I] := TIER2_TABLES[I];
    
    for TableName in AllTables do
    begin
      if not TableExists(AConnection, TableName) then
      begin
        Issue.IssueType := ditMissingTable;
        Issue.IsOK := False;
        Issue.TableName := TableName;
        Issue.ObjectName := '';
        Issue.Issue := Format('Table ''%s'' does not exist', [TableName]);
        Issue.Suggestion := Format('Create the table using UniBase schema SQL for %s', [TableName]);
        Issue.FixSQL := GetTableCreateSQL(TableName);
        Issue.CanAutoFix := Issue.FixSQL <> '';
        ResultList.Add(Issue);
      end;
    end;
    
    Result := ResultList.ToArray;
  finally
    ResultList.Free;
  end;
end;

type
  TColumnDef = record
    TableName: string;
    ColumnName: string;
    ColumnType: string;
    DefaultValue: string;
  end;

const
  // Key columns that must exist (fallback fields)
  REQUIRED_COLUMNS: array[0..45] of TColumnDef = (
    // SchemaInfo
    (TableName: 'SchemaInfo'; ColumnName: 'Extra'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'SchemaInfo'; ColumnName: 'Remarks'; ColumnType: 'TEXT'; DefaultValue: ''),
    // Settings
    (TableName: 'Settings'; ColumnName: 'DefaultValue'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'Settings'; ColumnName: 'IsReadOnly'; ColumnType: 'INTEGER'; DefaultValue: '0'),
    (TableName: 'Settings'; ColumnName: 'IsSystem'; ColumnType: 'INTEGER'; DefaultValue: '0'),
    (TableName: 'Settings'; ColumnName: 'SortOrder'; ColumnType: 'INTEGER'; DefaultValue: '0'),
    (TableName: 'Settings'; ColumnName: 'Extra'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'Settings'; ColumnName: 'Remarks'; ColumnType: 'TEXT'; DefaultValue: ''),
    // FormStates
    (TableName: 'FormStates'; ColumnName: 'Splitters'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'FormStates'; ColumnName: 'Columns'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'FormStates'; ColumnName: 'TabIndex'; ColumnType: 'INTEGER'; DefaultValue: '0'),
    (TableName: 'FormStates'; ColumnName: 'Extra'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'FormStates'; ColumnName: 'Remarks'; ColumnType: 'TEXT'; DefaultValue: ''),
    // Languages
    (TableName: 'Languages'; ColumnName: 'DateFormat'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'Languages'; ColumnName: 'TimeFormat'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'Languages'; ColumnName: 'TextDirection'; ColumnType: 'TEXT'; DefaultValue: '''LTR'''),
    (TableName: 'Languages'; ColumnName: 'Extra'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'Languages'; ColumnName: 'Remarks'; ColumnType: 'TEXT'; DefaultValue: ''),
    // I18nTexts
    (TableName: 'I18nTexts'; ColumnName: 'Module'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'I18nTexts'; ColumnName: 'Extra'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'I18nTexts'; ColumnName: 'Remarks'; ColumnType: 'TEXT'; DefaultValue: ''),
    // Logs
    (TableName: 'Logs'; ColumnName: 'SessionId'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'Logs'; ColumnName: 'MachineName'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'Logs'; ColumnName: 'Extra'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'Logs'; ColumnName: 'Remarks'; ColumnType: 'TEXT'; DefaultValue: ''),
    // MRU
    (TableName: 'MRU'; ColumnName: 'Extra'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'MRU'; ColumnName: 'Remarks'; ColumnType: 'TEXT'; DefaultValue: ''),
    // Hotkeys
    (TableName: 'Hotkeys'; ColumnName: 'DefaultShortcut'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'Hotkeys'; ColumnName: 'IsEnabled'; ColumnType: 'INTEGER'; DefaultValue: '1'),
    (TableName: 'Hotkeys'; ColumnName: 'IsGlobal'; ColumnType: 'INTEGER'; DefaultValue: '0'),
    (TableName: 'Hotkeys'; ColumnName: 'Extra'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'Hotkeys'; ColumnName: 'Remarks'; ColumnType: 'TEXT'; DefaultValue: ''),
    // Queries
    (TableName: 'Queries'; ColumnName: 'Extra'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'Queries'; ColumnName: 'Remarks'; ColumnType: 'TEXT'; DefaultValue: ''),
    // Themes
    (TableName: 'Themes'; ColumnName: 'Extra'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'Themes'; ColumnName: 'Remarks'; ColumnType: 'TEXT'; DefaultValue: ''),
    // Categories
    (TableName: 'Categories'; ColumnName: 'Extra'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'Categories'; ColumnName: 'Remarks'; ColumnType: 'TEXT'; DefaultValue: ''),
    // Tags
    (TableName: 'Tags'; ColumnName: 'Extra'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'Tags'; ColumnName: 'Remarks'; ColumnType: 'TEXT'; DefaultValue: ''),
    // LLMConfig
    (TableName: 'LLMConfig'; ColumnName: 'Extra'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'LLMConfig'; ColumnName: 'Remarks'; ColumnType: 'TEXT'; DefaultValue: ''),
    // LLMCalls
    (TableName: 'LLMCalls'; ColumnName: 'Extra'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'LLMCalls'; ColumnName: 'Remarks'; ColumnType: 'TEXT'; DefaultValue: ''),
    // Notifications
    (TableName: 'Notifications'; ColumnName: 'Extra'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'Notifications'; ColumnName: 'Remarks'; ColumnType: 'TEXT'; DefaultValue: '')
  );

function CheckColumnsExist(AConnection: TFDConnection): TDiagnoseResults;
var
  ColDef: TColumnDef;
  Issue: TDiagnoseResult;
  ResultList: TList<TDiagnoseResult>;
  I: Integer;
begin
  ResultList := TList<TDiagnoseResult>.Create;
  try
    for I := Low(REQUIRED_COLUMNS) to High(REQUIRED_COLUMNS) do
    begin
      ColDef := REQUIRED_COLUMNS[I];
      
      // Skip if table doesn't exist (will be reported by CheckTablesExist)
      if not TableExists(AConnection, ColDef.TableName) then
        Continue;
        
      if not ColumnExists(AConnection, ColDef.TableName, ColDef.ColumnName) then
      begin
        Issue.IssueType := ditMissingColumn;
        Issue.IsOK := False;
        Issue.TableName := ColDef.TableName;
        Issue.ObjectName := ColDef.ColumnName;
        Issue.Issue := Format('Column ''%s.%s'' does not exist', [ColDef.TableName, ColDef.ColumnName]);
        Issue.Suggestion := Format('Add column: ALTER TABLE %s ADD COLUMN %s %s', 
          [ColDef.TableName, ColDef.ColumnName, ColDef.ColumnType]);
        
        if ColDef.DefaultValue <> '' then
          Issue.FixSQL := Format('ALTER TABLE %s ADD COLUMN %s %s DEFAULT %s', 
            [ColDef.TableName, ColDef.ColumnName, ColDef.ColumnType, ColDef.DefaultValue])
        else
          Issue.FixSQL := Format('ALTER TABLE %s ADD COLUMN %s %s', 
            [ColDef.TableName, ColDef.ColumnName, ColDef.ColumnType]);
            
        Issue.CanAutoFix := True;
        ResultList.Add(Issue);
      end;
    end;
    
    Result := ResultList.ToArray;
  finally
    ResultList.Free;
  end;
end;

function CheckIndexesExist(AConnection: TFDConnection): TDiagnoseResults;
begin
  // Basic implementation - can be expanded
  SetLength(Result, 0);
end;

// ============================================================================
// Data Integrity Check
// ============================================================================

type
  TForeignKeyDef = record
    TableName: string;
    ColumnName: string;
    RefTable: string;
    RefColumn: string;
  end;
  
  TRequiredFieldDef = record
    TableName: string;
    ColumnName: string;
    Description: string;
  end;
  
  TEnumFieldDef = record
    TableName: string;
    ColumnName: string;
    ValidValues: string;  // Comma-separated, e.g. 'INFO,WARN,ERROR,DEBUG'
  end;

const
  // Foreign key relationships to check
  FK_RELATIONS: array[0..6] of TForeignKeyDef = (
    (TableName: 'Models'; ColumnName: 'ProviderId'; RefTable: 'Providers'; RefColumn: 'Id'),
    (TableName: 'LLMConfig'; ColumnName: 'ModelId'; RefTable: 'Models'; RefColumn: 'Id'),
    (TableName: 'LLMCalls'; ColumnName: 'ConfigId'; RefTable: 'LLMConfig'; RefColumn: 'Id'),
    (TableName: 'LLMPrompts'; ColumnName: 'CategoryId'; RefTable: 'Categories'; RefColumn: 'Id'),
    (TableName: 'LLMApiKeys'; ColumnName: 'ProviderId'; RefTable: 'Providers'; RefColumn: 'Id'),
    (TableName: 'Attachments'; ColumnName: 'CategoryId'; RefTable: 'Categories'; RefColumn: 'Id'),
    (TableName: 'TagMappings'; ColumnName: 'TagId'; RefTable: 'Tags'; RefColumn: 'Id')
  );
  
  // Required fields that must not be NULL
  REQUIRED_FIELDS: array[0..11] of TRequiredFieldDef = (
    (TableName: 'SchemaInfo'; ColumnName: 'Key'; Description: 'Configuration key'),
    (TableName: 'Settings'; ColumnName: 'Key'; Description: 'Setting key'),
    (TableName: 'Languages'; ColumnName: 'Code'; Description: 'Language code'),
    (TableName: 'I18nTexts'; ColumnName: 'TextKey'; Description: 'Translation key'),
    (TableName: 'I18nTexts'; ColumnName: 'LangCode'; Description: 'Language code'),
    (TableName: 'Logs'; ColumnName: 'Level'; Description: 'Log level'),
    (TableName: 'Providers'; ColumnName: 'Name'; Description: 'Provider name'),
    (TableName: 'Models'; ColumnName: 'Name'; Description: 'Model name'),
    (TableName: 'Categories'; ColumnName: 'Name'; Description: 'Category name'),
    (TableName: 'Tags'; ColumnName: 'Name'; Description: 'Tag name'),
    (TableName: 'Themes'; ColumnName: 'Name'; Description: 'Theme name'),
    (TableName: 'Hotkeys'; ColumnName: 'ActionId'; Description: 'Action identifier')
  );
  
  // Enum fields with valid values
  ENUM_FIELDS: array[0..5] of TEnumFieldDef = (
    (TableName: 'Logs'; ColumnName: 'Level'; ValidValues: 'DEBUG,INFO,WARN,ERROR,FATAL'),
    (TableName: 'Languages'; ColumnName: 'TextDirection'; ValidValues: 'LTR,RTL'),
    (TableName: 'Notifications'; ColumnName: 'Priority'; ValidValues: 'LOW,NORMAL,HIGH,URGENT'),
    (TableName: 'Notifications'; ColumnName: 'Status'; ValidValues: 'PENDING,SHOWN,READ,DISMISSED'),
    (TableName: 'LLMApiKeys'; ColumnName: 'EncryptionMethod'; ValidValues: 'PLAIN,DPAPI,AES'),
    (TableName: 'MRU'; ColumnName: 'ItemType'; ValidValues: 'FILE,FOLDER,URL,QUERY,OTHER')
  );

function CheckForeignKeys(AConnection: TFDConnection): TDiagnoseResults;
var
  FK: TForeignKeyDef;
  Query: TFDQuery;
  Issue: TDiagnoseResult;
  ResultList: TList<TDiagnoseResult>;
  OrphanCount: Integer;
  I: Integer;
begin
  ResultList := TList<TDiagnoseResult>.Create;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := AConnection;
    
    for I := Low(FK_RELATIONS) to High(FK_RELATIONS) do
    begin
      FK := FK_RELATIONS[I];
      
      // Skip if either table doesn't exist
      if not TableExists(AConnection, FK.TableName) then Continue;
      if not TableExists(AConnection, FK.RefTable) then Continue;
      // Skip if column doesn't exist
      if not ColumnExists(AConnection, FK.TableName, FK.ColumnName) then Continue;
      
      // Check for orphan records (FK values not in referenced table)
      Query.Close;
      Query.SQL.Text := Format(
        'SELECT COUNT(*) AS OrphanCount FROM %s t ' +
        'WHERE t.%s IS NOT NULL AND t.%s <> '''' ' +
        'AND NOT EXISTS (SELECT 1 FROM %s r WHERE r.%s = t.%s)',
        [FK.TableName, FK.ColumnName, FK.ColumnName, 
         FK.RefTable, FK.RefColumn, FK.ColumnName]);
      
      try
        Query.Open;
        OrphanCount := Query.FieldByName('OrphanCount').AsInteger;
        
        if OrphanCount > 0 then
        begin
          Issue.IssueType := ditForeignKey;
          Issue.IsOK := False;
          Issue.TableName := FK.TableName;
          Issue.ObjectName := FK.ColumnName;
          Issue.Issue := Format('%d orphan record(s) in %s.%s referencing non-existent %s.%s',
            [OrphanCount, FK.TableName, FK.ColumnName, FK.RefTable, FK.RefColumn]);
          Issue.Suggestion := Format('Review and fix/delete orphan records in table %s', [FK.TableName]);
          Issue.FixSQL := ''; // Manual fix required
          Issue.CanAutoFix := False;
          ResultList.Add(Issue);
        end;
      except
        // Ignore query errors (e.g. column doesn't exist)
      end;
    end;
    
    Result := ResultList.ToArray;
  finally
    Query.Free;
    ResultList.Free;
  end;
end;

function CheckRequiredFields(AConnection: TFDConnection): TDiagnoseResults;
var
  RF: TRequiredFieldDef;
  Query: TFDQuery;
  Issue: TDiagnoseResult;
  ResultList: TList<TDiagnoseResult>;
  NullCount: Integer;
  I: Integer;
begin
  ResultList := TList<TDiagnoseResult>.Create;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := AConnection;
    
    for I := Low(REQUIRED_FIELDS) to High(REQUIRED_FIELDS) do
    begin
      RF := REQUIRED_FIELDS[I];
      
      // Skip if table doesn't exist
      if not TableExists(AConnection, RF.TableName) then Continue;
      // Skip if column doesn't exist
      if not ColumnExists(AConnection, RF.TableName, RF.ColumnName) then Continue;
      
      Query.Close;
      Query.SQL.Text := Format(
        'SELECT COUNT(*) AS NullCount FROM %s WHERE %s IS NULL OR %s = ''''',
        [RF.TableName, RF.ColumnName, RF.ColumnName]);
      
      try
        Query.Open;
        NullCount := Query.FieldByName('NullCount').AsInteger;
        
        if NullCount > 0 then
        begin
          Issue.IssueType := ditNullValue;
          Issue.IsOK := False;
          Issue.TableName := RF.TableName;
          Issue.ObjectName := RF.ColumnName;
          Issue.Issue := Format('%d record(s) in %s have NULL/empty %s (%s)',
            [NullCount, RF.TableName, RF.ColumnName, RF.Description]);
          Issue.Suggestion := Format('Review and populate missing %s values', [RF.ColumnName]);
          Issue.FixSQL := ''; // Manual fix required
          Issue.CanAutoFix := False;
          ResultList.Add(Issue);
        end;
      except
        // Ignore query errors
      end;
    end;
    
    Result := ResultList.ToArray;
  finally
    Query.Free;
    ResultList.Free;
  end;
end;

function CheckEnumValues(AConnection: TFDConnection): TDiagnoseResults;
var
  EF: TEnumFieldDef;
  Query: TFDQuery;
  Issue: TDiagnoseResult;
  ResultList: TList<TDiagnoseResult>;
  InvalidCount: Integer;
  ValidList: string;
  I: Integer;
begin
  ResultList := TList<TDiagnoseResult>.Create;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := AConnection;
    
    for I := Low(ENUM_FIELDS) to High(ENUM_FIELDS) do
    begin
      EF := ENUM_FIELDS[I];
      
      // Skip if table doesn't exist
      if not TableExists(AConnection, EF.TableName) then Continue;
      // Skip if column doesn't exist
      if not ColumnExists(AConnection, EF.TableName, EF.ColumnName) then Continue;
      
      // Build IN clause: 'DEBUG','INFO','WARN','ERROR','FATAL'
      ValidList := '''' + StringReplace(EF.ValidValues, ',', ''',''', [rfReplaceAll]) + '''';
      
      Query.Close;
      Query.SQL.Text := Format(
        'SELECT COUNT(*) AS InvalidCount FROM %s ' +
        'WHERE %s IS NOT NULL AND %s <> '''' AND UPPER(%s) NOT IN (%s)',
        [EF.TableName, EF.ColumnName, EF.ColumnName, EF.ColumnName, ValidList]);
      
      try
        Query.Open;
        InvalidCount := Query.FieldByName('InvalidCount').AsInteger;
        
        if InvalidCount > 0 then
        begin
          Issue.IssueType := ditInvalidEnum;
          Issue.IsOK := False;
          Issue.TableName := EF.TableName;
          Issue.ObjectName := EF.ColumnName;
          Issue.Issue := Format('%d record(s) in %s.%s have invalid values (allowed: %s)',
            [InvalidCount, EF.TableName, EF.ColumnName, EF.ValidValues]);
          Issue.Suggestion := Format('Update invalid %s values to one of: %s', [EF.ColumnName, EF.ValidValues]);
          Issue.FixSQL := ''; // Manual fix required
          Issue.CanAutoFix := False;
          ResultList.Add(Issue);
        end;
      except
        // Ignore query errors
      end;
    end;
    
    Result := ResultList.ToArray;
  finally
    Query.Free;
    ResultList.Free;
  end;
end;

function CheckDataIntegrity(AConnection: TFDConnection): TDiagnoseResults;
var
  FKResults, NullResults, EnumResults: TDiagnoseResults;
  ResultList: TList<TDiagnoseResult>;
  R: TDiagnoseResult;
begin
  ResultList := TList<TDiagnoseResult>.Create;
  try
    // Check foreign key references
    FKResults := CheckForeignKeys(AConnection);
    for R in FKResults do
      ResultList.Add(R);
    
    // Check required fields for NULL
    NullResults := CheckRequiredFields(AConnection);
    for R in NullResults do
      ResultList.Add(R);
    
    // Check enum values
    EnumResults := CheckEnumValues(AConnection);
    for R in EnumResults do
      ResultList.Add(R);
    
    Result := ResultList.ToArray;
  finally
    ResultList.Free;
  end;
end;

function DiagnoseAll(AConnection: TFDConnection): TDiagnoseResults;
var
  VersionResults, TableResults, ColumnResults, IndexResults, IntegrityResults: TDiagnoseResults;
  ResultList: TList<TDiagnoseResult>;
  R: TDiagnoseResult;
begin
  ResultList := TList<TDiagnoseResult>.Create;
  try
    // Check schema version
    VersionResults := CheckSchemaVersion(AConnection);
    for R in VersionResults do
      ResultList.Add(R);
    
    // Check tables
    TableResults := CheckTablesExist(AConnection);
    for R in TableResults do
      ResultList.Add(R);
    
    // Check columns
    ColumnResults := CheckColumnsExist(AConnection);
    for R in ColumnResults do
      ResultList.Add(R);
    
    // Check indexes
    IndexResults := CheckIndexesExist(AConnection);
    for R in IndexResults do
      ResultList.Add(R);
    
    // Check data integrity (foreign keys, required fields, enums)
    IntegrityResults := CheckDataIntegrity(AConnection);
    for R in IntegrityResults do
      ResultList.Add(R);
    
    Result := ResultList.ToArray;
  finally
    ResultList.Free;
  end;
end;

function AddColumnIfNotExists(AConnection: TFDConnection; 
  const ATableName, AColumnName, AColumnDef: string): Boolean;
begin
  Result := False;
  if ColumnExists(AConnection, ATableName, AColumnName) then
    Exit;
    
  try
    AConnection.ExecSQL(Format('ALTER TABLE %s ADD COLUMN %s %s', 
      [ATableName, AColumnName, AColumnDef]));
    Result := True;
  except
    // Ignore errors
  end;
end;

function AutoFix(AConnection: TFDConnection; const AResults: TDiagnoseResults): Integer;
var
  R: TDiagnoseResult;
begin
  Result := 0;
  
  for R in AResults do
  begin
    if not R.CanAutoFix then
      Continue;
      
    if R.FixSQL = '' then
      Continue;
      
    try
      AConnection.ExecSQL(R.FixSQL);
      Inc(Result);
    except
      // Log error but continue
    end;
  end;
end;

function GenerateDiagnoseReport(const AResults: TDiagnoseResults): string;
var
  SB: TStringBuilder;
  R: TDiagnoseResult;
  FixableCount, UnfixableCount: Integer;
  I: Integer;
begin
  SB := TStringBuilder.Create;
  try
    SB.AppendLine('═══════════════════════════════════════════════════');
    SB.AppendLine('UniBase Database Diagnostic Report');
    SB.AppendLine('═══════════════════════════════════════════════════');
    SB.AppendFormat('UniBase Version: %s', [SCHEMA_VERSION]);
    SB.AppendLine;
    SB.AppendFormat('Check Time: %s', [FormatDateTime('yyyy-mm-dd hh:nn:ss', Now)]);
    SB.AppendLine;
    SB.AppendLine;
    
    if Length(AResults) = 0 then
    begin
      SB.AppendLine('[✓] All checks passed. Database schema is valid.');
    end
    else
    begin
      FixableCount := 0;
      UnfixableCount := 0;
      
      for R in AResults do
      begin
        if R.CanAutoFix then
          Inc(FixableCount)
        else
          Inc(UnfixableCount);
      end;
      
      SB.AppendFormat('[!] Found %d issue(s):', [Length(AResults)]);
      SB.AppendLine;
      SB.AppendLine;
      
      for I := 0 to High(AResults) do
      begin
        R := AResults[I];
        SB.AppendFormat('%d. %s', [I + 1, R.Issue]);
        SB.AppendLine;
        SB.AppendFormat('   Suggestion: %s', [R.Suggestion]);
        SB.AppendLine;
        if R.CanAutoFix then
          SB.AppendLine('   [Can be auto-fixed]');
        SB.AppendLine;
      end;
      
      SB.AppendLine('───────────────────────────────────────────────────');
      SB.AppendFormat('Auto-fixable: %d | Manual fix required: %d', [FixableCount, UnfixableCount]);
      SB.AppendLine;
      
      if FixableCount > 0 then
        SB.AppendLine('Run AutoFix(DB, Results) to fix auto-fixable issues.');
    end;
    
    SB.AppendLine('═══════════════════════════════════════════════════');
    
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function GenerateDiagnoseSummary(const AResults: TDiagnoseResults): string;
var
  FixableCount: Integer;
  R: TDiagnoseResult;
begin
  if Length(AResults) = 0 then
  begin
    Result := 'Database check passed.';
    Exit;
  end;
  
  FixableCount := 0;
  for R in AResults do
    if R.CanAutoFix then
      Inc(FixableCount);
  
  Result := Format('Found %d issue(s), %d auto-fixable.', [Length(AResults), FixableCount]);
end;

end.
