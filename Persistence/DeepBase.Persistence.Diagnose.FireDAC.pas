{ ============================================================================
  DeepBase.Persistence.Diagnose.FireDAC - FireDAC adapter for diagnose storage
  ============================================================================
  Implements Core\DeepBase.Diagnose IDiagnoseStorage using FireDAC.
  ============================================================================ }

unit DeepBase.Persistence.Diagnose.FireDAC;

interface

uses
  DeepBase.Diagnose,
  FireDAC.Comp.Client;

function CreateDiagnoseFireDACStorage(
  AConnection: TFDConnection): IDiagnoseStorage;
procedure RegisterDiagnoseStorageFactory;

implementation

uses
  System.SysUtils,
  System.Generics.Collections,
  Winapi.Windows,
  DeepBase.Schema,
  DeepBase.SQL.Utils;

type
  TColumnDef = record
    TableName: string;
    ColumnName: string;
    ColumnType: string;
    DefaultValue: string;
  end;

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
    ValidValues: string;
  end;

const
  REQUIRED_COLUMNS: array[0..45] of TColumnDef = (
    (TableName: 'SchemaInfo'; ColumnName: 'Extra'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'SchemaInfo'; ColumnName: 'Remarks'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'Settings'; ColumnName: 'DefaultValue'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'Settings'; ColumnName: 'IsReadOnly'; ColumnType: 'INTEGER'; DefaultValue: '0'),
    (TableName: 'Settings'; ColumnName: 'IsSystem'; ColumnType: 'INTEGER'; DefaultValue: '0'),
    (TableName: 'Settings'; ColumnName: 'SortOrder'; ColumnType: 'INTEGER'; DefaultValue: '0'),
    (TableName: 'Settings'; ColumnName: 'Extra'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'Settings'; ColumnName: 'Remarks'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'FormStates'; ColumnName: 'Splitters'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'FormStates'; ColumnName: 'Columns'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'FormStates'; ColumnName: 'TabIndex'; ColumnType: 'INTEGER'; DefaultValue: '0'),
    (TableName: 'FormStates'; ColumnName: 'Extra'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'FormStates'; ColumnName: 'Remarks'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'Languages'; ColumnName: 'DateFormat'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'Languages'; ColumnName: 'TimeFormat'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'Languages'; ColumnName: 'TextDirection'; ColumnType: 'TEXT'; DefaultValue: '''LTR'''),
    (TableName: 'Languages'; ColumnName: 'Extra'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'Languages'; ColumnName: 'Remarks'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'I18nTexts'; ColumnName: 'Module'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'I18nTexts'; ColumnName: 'Extra'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'I18nTexts'; ColumnName: 'Remarks'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'Logs'; ColumnName: 'SessionId'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'Logs'; ColumnName: 'MachineName'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'Logs'; ColumnName: 'Extra'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'Logs'; ColumnName: 'Remarks'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'MRU'; ColumnName: 'Extra'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'MRU'; ColumnName: 'Remarks'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'Hotkeys'; ColumnName: 'DefaultShortcut'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'Hotkeys'; ColumnName: 'IsEnabled'; ColumnType: 'INTEGER'; DefaultValue: '1'),
    (TableName: 'Hotkeys'; ColumnName: 'IsGlobal'; ColumnType: 'INTEGER'; DefaultValue: '0'),
    (TableName: 'Hotkeys'; ColumnName: 'Extra'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'Hotkeys'; ColumnName: 'Remarks'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'Queries'; ColumnName: 'Extra'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'Queries'; ColumnName: 'Remarks'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'Themes'; ColumnName: 'Extra'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'Themes'; ColumnName: 'Remarks'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'Categories'; ColumnName: 'Extra'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'Categories'; ColumnName: 'Remarks'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'Tags'; ColumnName: 'Extra'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'Tags'; ColumnName: 'Remarks'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'LLMConfig'; ColumnName: 'Extra'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'LLMConfig'; ColumnName: 'Remarks'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'LLMCalls'; ColumnName: 'Extra'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'LLMCalls'; ColumnName: 'Remarks'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'Notifications'; ColumnName: 'Extra'; ColumnType: 'TEXT'; DefaultValue: ''),
    (TableName: 'Notifications'; ColumnName: 'Remarks'; ColumnType: 'TEXT'; DefaultValue: '')
  );

  FK_RELATIONS: array[0..6] of TForeignKeyDef = (
    (TableName: 'Models'; ColumnName: 'ProviderId'; RefTable: 'Providers'; RefColumn: 'Id'),
    (TableName: 'LLMConfig'; ColumnName: 'ModelId'; RefTable: 'Models'; RefColumn: 'Id'),
    (TableName: 'LLMCalls'; ColumnName: 'ConfigId'; RefTable: 'LLMConfig'; RefColumn: 'Id'),
    (TableName: 'LLMPrompts'; ColumnName: 'CategoryId'; RefTable: 'Categories'; RefColumn: 'Id'),
    (TableName: 'LLMApiKeys'; ColumnName: 'ProviderId'; RefTable: 'Providers'; RefColumn: 'Id'),
    (TableName: 'Attachments'; ColumnName: 'CategoryId'; RefTable: 'Categories'; RefColumn: 'Id'),
    (TableName: 'TagMappings'; ColumnName: 'TagId'; RefTable: 'Tags'; RefColumn: 'Id')
  );

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

  ENUM_FIELDS: array[0..5] of TEnumFieldDef = (
    (TableName: 'Logs'; ColumnName: 'Level'; ValidValues: 'DEBUG,INFO,WARN,ERROR,FATAL'),
    (TableName: 'Languages'; ColumnName: 'TextDirection'; ValidValues: 'LTR,RTL'),
    (TableName: 'Notifications'; ColumnName: 'Priority'; ValidValues: 'LOW,NORMAL,HIGH,URGENT'),
    (TableName: 'Notifications'; ColumnName: 'Status'; ValidValues: 'PENDING,SHOWN,READ,DISMISSED'),
    (TableName: 'LLMApiKeys'; ColumnName: 'EncryptionMethod'; ValidValues: 'PLAIN,DPAPI,AES,CREDMAN'),
    (TableName: 'MRU'; ColumnName: 'ItemType'; ValidValues: 'FILE,FOLDER,URL,QUERY,OTHER')
  );

type
  TFireDACDiagnoseStorage = class(TInterfacedObject, IDiagnoseStorage)
  private
    FConnection: TFDConnection;
    function GetTableCreateSQL(const ATableName: string): string;
    function CheckForeignKeys: TDiagnoseResults;
    function CheckRequiredFields: TDiagnoseResults;
    function CheckEnumValues: TDiagnoseResults;
  public
    constructor Create(AConnection: TFDConnection);
    function DiagnoseAll: TDiagnoseResults;
    function CheckTablesExist: TDiagnoseResults;
    function CheckColumnsExist: TDiagnoseResults;
    function CheckIndexesExist: TDiagnoseResults;
    function CheckSchemaVersion: TDiagnoseResults;
    function CheckDataIntegrity: TDiagnoseResults;
    function AutoFix(const AResults: TDiagnoseResults): Integer;
    function AddColumnIfNotExists(const ATableName, AColumnName,
      AColumnDef: string): Boolean;
    function TableExists(const ATableName: string): Boolean;
    function ColumnExists(const ATableName, AColumnName: string): Boolean;
    function IndexExists(const AIndexName: string): Boolean;
    function GetSchemaVersion: string;
  end;

constructor TFireDACDiagnoseStorage.Create(AConnection: TFDConnection);
begin
  inherited Create;
  FConnection := AConnection;
end;

function TFireDACDiagnoseStorage.TableExists(const ATableName: string): Boolean;
var
  Query: TFDQuery;
begin
  Result := False;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT name FROM sqlite_master WHERE type=''table'' AND LOWER(name)=LOWER(:tablename)';
    Query.ParamByName('tablename').AsString := ATableName;
    Query.Open;
    Result := not Query.IsEmpty;
  finally
    Query.Free;
  end;
end;

function TFireDACDiagnoseStorage.ColumnExists(
  const ATableName, AColumnName: string): Boolean;
var
  Query: TFDQuery;
begin
  Result := False;
  TSQLUtils.ValidateIdentifier(ATableName, 'Diagnose.ColumnExists.TableName');
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := Format('PRAGMA table_info(%s)', [ATableName]);
    Query.Open;
    while not Query.Eof do
    begin
      if SameText(Query.FieldByName('name').AsString, AColumnName) then
        Exit(True);
      Query.Next;
    end;
  finally
    Query.Free;
  end;
end;

function TFireDACDiagnoseStorage.IndexExists(const AIndexName: string): Boolean;
var
  Query: TFDQuery;
begin
  Result := False;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT name FROM sqlite_master WHERE type=''index'' AND name=:indexname';
    Query.ParamByName('indexname').AsString := AIndexName;
    Query.Open;
    Result := not Query.IsEmpty;
  finally
    Query.Free;
  end;
end;

function TFireDACDiagnoseStorage.GetSchemaVersion: string;
var
  Query: TFDQuery;
begin
  Result := '';
  if not TableExists('SchemaInfo') then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT Value FROM SchemaInfo WHERE Key = ''SchemaVersion''';
    Query.Open;
    if not Query.IsEmpty then
      Result := Query.Fields[0].AsString;
  finally
    Query.Free;
  end;
end;

function TFireDACDiagnoseStorage.CheckSchemaVersion: TDiagnoseResults;
var
  DBVersion: string;
  Issue: TDiagnoseResult;
begin
  SetLength(Result, 0);
  DBVersion := GetSchemaVersion;

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
    Issue.Issue := Format('Database version %s differs from DeepBase version %s', [DBVersion, SCHEMA_VERSION]);
    Issue.Suggestion := 'Consider running migration if features are missing.';
    Issue.FixSQL := '';
    Issue.CanAutoFix := False;
    SetLength(Result, 1);
    Result[0] := Issue;
  end;
end;

function TFireDACDiagnoseStorage.GetTableCreateSQL(const ATableName: string): string;
begin
  Result := '';
  if SameText(ATableName, 'SchemaInfo') then Result := SQL_TIER0_SCHEMA_INFO
  else if SameText(ATableName, 'Settings') then Result := SQL_TIER0_SETTINGS
  else if SameText(ATableName, 'FormStates') then Result := SQL_TIER0_FORM_STATES
  else if SameText(ATableName, 'Languages') then Result := SQL_TIER0_LANGUAGES
  else if SameText(ATableName, 'I18nTexts') then Result := SQL_TIER0_I18N_TEXTS
  else if SameText(ATableName, 'Logs') then Result := SQL_TIER1_LOGS
  else if SameText(ATableName, 'MRU') then Result := SQL_TIER1_MRU
  else if SameText(ATableName, 'Hotkeys') then Result := SQL_TIER1_HOTKEYS
  else if SameText(ATableName, 'Queries') then Result := SQL_TIER1_QUERIES
  else if SameText(ATableName, 'Themes') then Result := SQL_TIER1_THEMES
  else if SameText(ATableName, 'Categories') then Result := SQL_TIER1_CATEGORIES
  else if SameText(ATableName, 'Tags') then Result := SQL_TIER1_TAGS
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

function TFireDACDiagnoseStorage.CheckTablesExist: TDiagnoseResults;
var
  AllTables: TArray<string>;
  TableName: string;
  Issue: TDiagnoseResult;
  ResultList: TList<TDiagnoseResult>;
  I: Integer;
begin
  ResultList := TList<TDiagnoseResult>.Create;
  try
    SetLength(AllTables, Length(TIER0_TABLES) + Length(TIER1_TABLES) + Length(TIER2_TABLES));
    for I := 0 to High(TIER0_TABLES) do
      AllTables[I] := TIER0_TABLES[I];
    for I := 0 to High(TIER1_TABLES) do
      AllTables[Length(TIER0_TABLES) + I] := TIER1_TABLES[I];
    for I := 0 to High(TIER2_TABLES) do
      AllTables[Length(TIER0_TABLES) + Length(TIER1_TABLES) + I] := TIER2_TABLES[I];

    for TableName in AllTables do
    begin
      if not TableExists(TableName) then
      begin
        Issue.IssueType := ditMissingTable;
        Issue.IsOK := False;
        Issue.TableName := TableName;
        Issue.ObjectName := '';
        Issue.Issue := Format('Table ''%s'' does not exist', [TableName]);
        Issue.Suggestion := Format('Create the table using DeepBase schema SQL for %s', [TableName]);
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

function TFireDACDiagnoseStorage.CheckColumnsExist: TDiagnoseResults;
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
      if not TableExists(ColDef.TableName) then
        Continue;

      if not ColumnExists(ColDef.TableName, ColDef.ColumnName) then
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

function TFireDACDiagnoseStorage.CheckIndexesExist: TDiagnoseResults;
begin
  SetLength(Result, 0);
end;

function TFireDACDiagnoseStorage.CheckForeignKeys: TDiagnoseResults;
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
    Query.Connection := FConnection;
    for I := Low(FK_RELATIONS) to High(FK_RELATIONS) do
    begin
      FK := FK_RELATIONS[I];
      if not TableExists(FK.TableName) then
        Continue;
      if not TableExists(FK.RefTable) then
        Continue;
      if not ColumnExists(FK.TableName, FK.ColumnName) then
        Continue;

      TSQLUtils.ValidateIdentifier(FK.TableName, 'Diagnose.CheckFK.TableName');
      TSQLUtils.ValidateIdentifier(FK.ColumnName, 'Diagnose.CheckFK.ColumnName');
      TSQLUtils.ValidateIdentifier(FK.RefTable, 'Diagnose.CheckFK.RefTable');
      TSQLUtils.ValidateIdentifier(FK.RefColumn, 'Diagnose.CheckFK.RefColumn');

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
          Issue.FixSQL := '';
          Issue.CanAutoFix := False;
          ResultList.Add(Issue);
        end;
      except
        on E: Exception do
        begin
          // Surface check-execution failures instead of swallowing them via OutputDebugString.
          // Without this, a query error returns an empty Result -> DiagnoseAll reports green-on-error (DATA-R3-004).
          Issue.IssueType := ditCheckError;
          Issue.IsOK := False;
          Issue.TableName := FK.TableName;
          Issue.ObjectName := FK.ColumnName;
          Issue.Issue := '检查失败: ' + E.Message;
          Issue.Suggestion := '确认数据库连接正常且表结构可被内省后重试外键检查';
          Issue.FixSQL := '';
          Issue.CanAutoFix := False;
          ResultList.Add(Issue);
        end;
      end;
    end;
    Result := ResultList.ToArray;
  finally
    Query.Free;
    ResultList.Free;
  end;
end;

function TFireDACDiagnoseStorage.CheckRequiredFields: TDiagnoseResults;
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
    Query.Connection := FConnection;
    for I := Low(REQUIRED_FIELDS) to High(REQUIRED_FIELDS) do
    begin
      RF := REQUIRED_FIELDS[I];
      if not TableExists(RF.TableName) then
        Continue;
      if not ColumnExists(RF.TableName, RF.ColumnName) then
        Continue;

      TSQLUtils.ValidateIdentifier(RF.TableName, 'Diagnose.CheckRequired.TableName');
      TSQLUtils.ValidateIdentifier(RF.ColumnName, 'Diagnose.CheckRequired.ColumnName');

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
          Issue.FixSQL := '';
          Issue.CanAutoFix := False;
          ResultList.Add(Issue);
        end;
      except
        on E: Exception do
        begin
          // Surface check-execution failures (DATA-R3-004): swallowing via OutputDebugString made a failed query look like "no nulls".
          Issue.IssueType := ditCheckError;
          Issue.IsOK := False;
          Issue.TableName := RF.TableName;
          Issue.ObjectName := RF.ColumnName;
          Issue.Issue := '检查失败: ' + E.Message;
          Issue.Suggestion := '确认数据库连接正常且表结构可被内省后重试必填字段检查';
          Issue.FixSQL := '';
          Issue.CanAutoFix := False;
          ResultList.Add(Issue);
        end;
      end;
    end;
    Result := ResultList.ToArray;
  finally
    Query.Free;
    ResultList.Free;
  end;
end;

function TFireDACDiagnoseStorage.CheckEnumValues: TDiagnoseResults;
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
    Query.Connection := FConnection;
    for I := Low(ENUM_FIELDS) to High(ENUM_FIELDS) do
    begin
      EF := ENUM_FIELDS[I];
      if not TableExists(EF.TableName) then
        Continue;
      if not ColumnExists(EF.TableName, EF.ColumnName) then
        Continue;

      TSQLUtils.ValidateIdentifier(EF.TableName, 'Diagnose.CheckEnum.TableName');
      TSQLUtils.ValidateIdentifier(EF.ColumnName, 'Diagnose.CheckEnum.ColumnName');

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
          Issue.Suggestion := Format('Update invalid %s values to one of: %s',
            [EF.ColumnName, EF.ValidValues]);
          Issue.FixSQL := '';
          Issue.CanAutoFix := False;
          ResultList.Add(Issue);
        end;
      except
        on E: Exception do
        begin
          // Surface check-execution failures (DATA-R3-004): swallowing via OutputDebugString made a failed query look like "all enum values valid".
          Issue.IssueType := ditCheckError;
          Issue.IsOK := False;
          Issue.TableName := EF.TableName;
          Issue.ObjectName := EF.ColumnName;
          Issue.Issue := '检查失败: ' + E.Message;
          Issue.Suggestion := '确认数据库连接正常且表结构可被内省后重试枚举值检查';
          Issue.FixSQL := '';
          Issue.CanAutoFix := False;
          ResultList.Add(Issue);
        end;
      end;
    end;
    Result := ResultList.ToArray;
  finally
    Query.Free;
    ResultList.Free;
  end;
end;

function TFireDACDiagnoseStorage.CheckDataIntegrity: TDiagnoseResults;
var
  FKResults, NullResults, EnumResults: TDiagnoseResults;
  ResultList: TList<TDiagnoseResult>;
  R: TDiagnoseResult;
begin
  ResultList := TList<TDiagnoseResult>.Create;
  try
    FKResults := CheckForeignKeys;
    for R in FKResults do
      ResultList.Add(R);
    NullResults := CheckRequiredFields;
    for R in NullResults do
      ResultList.Add(R);
    EnumResults := CheckEnumValues;
    for R in EnumResults do
      ResultList.Add(R);
    Result := ResultList.ToArray;
  finally
    ResultList.Free;
  end;
end;

function TFireDACDiagnoseStorage.DiagnoseAll: TDiagnoseResults;
var
  VersionResults, TableResults, ColumnResults, IndexResults, IntegrityResults: TDiagnoseResults;
  ResultList: TList<TDiagnoseResult>;
  R: TDiagnoseResult;
begin
  ResultList := TList<TDiagnoseResult>.Create;
  try
    VersionResults := CheckSchemaVersion;
    for R in VersionResults do
      ResultList.Add(R);
    TableResults := CheckTablesExist;
    for R in TableResults do
      ResultList.Add(R);
    ColumnResults := CheckColumnsExist;
    for R in ColumnResults do
      ResultList.Add(R);
    IndexResults := CheckIndexesExist;
    for R in IndexResults do
      ResultList.Add(R);
    IntegrityResults := CheckDataIntegrity;
    for R in IntegrityResults do
      ResultList.Add(R);
    Result := ResultList.ToArray;
  finally
    ResultList.Free;
  end;
end;

function TFireDACDiagnoseStorage.AddColumnIfNotExists(const ATableName,
  AColumnName, AColumnDef: string): Boolean;
begin
  Result := False;
  TSQLUtils.ValidateIdentifier(ATableName, 'Diagnose.AddColumn.TableName');
  TSQLUtils.ValidateIdentifier(AColumnName, 'Diagnose.AddColumn.ColumnName');
  if ColumnExists(ATableName, AColumnName) then
    Exit;
  try
    FConnection.ExecSQL(Format('ALTER TABLE %s ADD COLUMN %s %s',
      [ATableName, AColumnName, AColumnDef]));
    Result := True;
  except
    on E: Exception do
      OutputDebugString(PChar('Diagnose.AddColumnIfNotExists: ' + E.Message));
  end;
end;

function TFireDACDiagnoseStorage.AutoFix(
  const AResults: TDiagnoseResults): Integer;
var
  R: TDiagnoseResult;
begin
  Result := 0;
  for R in AResults do
  begin
    if (not R.CanAutoFix) or (R.FixSQL = '') then
      Continue;
    try
      FConnection.ExecSQL(R.FixSQL);
      Inc(Result);
    except
      on E: Exception do
        OutputDebugString(PChar('Diagnose.AutoFix: ' + E.Message));
    end;
  end;
end;

function CreateDiagnoseFireDACStorage(
  AConnection: TFDConnection): IDiagnoseStorage;
begin
  Result := TFireDACDiagnoseStorage.Create(AConnection);
end;

procedure RegisterDiagnoseStorageFactory;
begin
  SetDiagnoseStorageFactory(
    function(AConnection: TObject): IDiagnoseStorage
    var
      FDConnection: TFDConnection;
    begin
      if not (AConnection is TFDConnection) then
        raise EInvalidCast.Create(
          'Expected TFDConnection for Diagnose FireDAC storage.');
      FDConnection := TFDConnection(AConnection);
      Result := CreateDiagnoseFireDACStorage(FDConnection);
    end);
end;

initialization
  RegisterDiagnoseStorageFactory;

end.
