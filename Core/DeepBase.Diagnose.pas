{ ============================================================================
  DeepBase.Diagnose - Database Schema Diagnostic Tool
  
  Version: 1.0.0
  Description: Provides diagnostic and auto-fix capabilities for DeepBase
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

unit DeepBase.Diagnose;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections;

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

  /// <summary>
  /// Diagnose storage abstraction (ARCH-039 incremental slice).
  /// Allows callers to inject non-FireDAC implementations.
  /// </summary>
  IDiagnoseStorage = interface
    ['{B9B9E3A0-A1F5-4FE9-95EF-C79E60DE0E38}']
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
function DiagnoseAll(AConnection: TObject): TDiagnoseResults;

/// <summary>
/// Perform comprehensive diagnosis via injected storage.
/// </summary>
function DiagnoseAllWithStorage(const AStorage: IDiagnoseStorage): TDiagnoseResults;

/// <summary>
/// Check if all expected tables exist
/// </summary>
function CheckTablesExist(AConnection: TObject): TDiagnoseResults;
function CheckTablesExistWithStorage(const AStorage: IDiagnoseStorage): TDiagnoseResults;

/// <summary>
/// Check if required columns exist in each table
/// </summary>
function CheckColumnsExist(AConnection: TObject): TDiagnoseResults;
function CheckColumnsExistWithStorage(const AStorage: IDiagnoseStorage): TDiagnoseResults;

/// <summary>
/// Check if required indexes exist
/// </summary>
function CheckIndexesExist(AConnection: TObject): TDiagnoseResults;
function CheckIndexesExistWithStorage(const AStorage: IDiagnoseStorage): TDiagnoseResults;

/// <summary>
/// Check schema version compatibility
/// </summary>
function CheckSchemaVersion(AConnection: TObject): TDiagnoseResults;
function CheckSchemaVersionWithStorage(const AStorage: IDiagnoseStorage): TDiagnoseResults;

/// <summary>
/// Attempt to automatically fix detected issues
/// </summary>
/// <returns>Number of issues fixed</returns>
function AutoFix(AConnection: TObject; const AResults: TDiagnoseResults): Integer;
function AutoFixWithStorage(const AStorage: IDiagnoseStorage;
  const AResults: TDiagnoseResults): Integer;

/// <summary>
/// Add a column to a table if it doesn't exist
/// </summary>
function AddColumnIfNotExists(AConnection: TObject; 
  const ATableName, AColumnName, AColumnDef: string): Boolean;
function AddColumnIfNotExistsWithStorage(const AStorage: IDiagnoseStorage;
  const ATableName, AColumnName, AColumnDef: string): Boolean;

/// <summary>
/// Check if a table exists in the database
/// </summary>
function TableExists(AConnection: TObject; const ATableName: string): Boolean;
function TableExistsWithStorage(const AStorage: IDiagnoseStorage;
  const ATableName: string): Boolean;

/// <summary>
/// Check if a column exists in a table
/// </summary>
function ColumnExists(AConnection: TObject; 
  const ATableName, AColumnName: string): Boolean;
function ColumnExistsWithStorage(const AStorage: IDiagnoseStorage;
  const ATableName, AColumnName: string): Boolean;

/// <summary>
/// Check if an index exists
/// </summary>
function IndexExists(AConnection: TObject; const AIndexName: string): Boolean;
function IndexExistsWithStorage(const AStorage: IDiagnoseStorage;
  const AIndexName: string): Boolean;

/// <summary>
/// Generate a human-readable diagnostic report
/// </summary>
function GenerateDiagnoseReport(const AResults: TDiagnoseResults): string;
function GenerateDiagnoseSummary(const AResults: TDiagnoseResults): string;

/// <summary>
/// Get the current schema version from database
/// </summary>
function GetSchemaVersion(AConnection: TObject): string;
function GetSchemaVersionWithStorage(const AStorage: IDiagnoseStorage): string;

/// <summary>
/// Check data integrity: foreign keys, required fields, enum values
/// </summary>
function CheckDataIntegrity(AConnection: TObject): TDiagnoseResults;
function CheckDataIntegrityWithStorage(const AStorage: IDiagnoseStorage): TDiagnoseResults;

/// <summary>
/// Create connection-backed diagnose storage from registered factory.
/// </summary>
function CreateDiagnoseStorage(AConnection: TObject): IDiagnoseStorage;

/// <summary>
/// Register custom connection->storage factory (ARCH-039).
/// </summary>
procedure SetDiagnoseStorageFactory(
  const AFactory: TFunc<TObject, IDiagnoseStorage>);

implementation

uses
  DeepBase.Schema;

var
  GConnectionStorageFactory: TFunc<TObject, IDiagnoseStorage>;

function CreateDiagnoseStorage(AConnection: TObject): IDiagnoseStorage;
begin
  Result := nil;
  if Assigned(AConnection) and Assigned(GConnectionStorageFactory) then
    Result := GConnectionStorageFactory(AConnection);
end;

procedure SetDiagnoseStorageFactory(
  const AFactory: TFunc<TObject, IDiagnoseStorage>);
begin
  GConnectionStorageFactory := AFactory;
end;

function DiagnoseAllWithStorage(
  const AStorage: IDiagnoseStorage): TDiagnoseResults;
begin
  if Assigned(AStorage) then
    Result := AStorage.DiagnoseAll
  else
    SetLength(Result, 0);
end;

function CheckTablesExistWithStorage(
  const AStorage: IDiagnoseStorage): TDiagnoseResults;
begin
  if Assigned(AStorage) then
    Result := AStorage.CheckTablesExist
  else
    SetLength(Result, 0);
end;

function CheckColumnsExistWithStorage(
  const AStorage: IDiagnoseStorage): TDiagnoseResults;
begin
  if Assigned(AStorage) then
    Result := AStorage.CheckColumnsExist
  else
    SetLength(Result, 0);
end;

function CheckIndexesExistWithStorage(
  const AStorage: IDiagnoseStorage): TDiagnoseResults;
begin
  if Assigned(AStorage) then
    Result := AStorage.CheckIndexesExist
  else
    SetLength(Result, 0);
end;

function CheckSchemaVersionWithStorage(
  const AStorage: IDiagnoseStorage): TDiagnoseResults;
begin
  if Assigned(AStorage) then
    Result := AStorage.CheckSchemaVersion
  else
    SetLength(Result, 0);
end;

function AutoFixWithStorage(const AStorage: IDiagnoseStorage;
  const AResults: TDiagnoseResults): Integer;
begin
  if Assigned(AStorage) then
    Result := AStorage.AutoFix(AResults)
  else
    Result := 0;
end;

function AddColumnIfNotExistsWithStorage(const AStorage: IDiagnoseStorage;
  const ATableName, AColumnName, AColumnDef: string): Boolean;
begin
  Result := Assigned(AStorage) and
    AStorage.AddColumnIfNotExists(ATableName, AColumnName, AColumnDef);
end;

function TableExistsWithStorage(const AStorage: IDiagnoseStorage;
  const ATableName: string): Boolean;
begin
  Result := Assigned(AStorage) and AStorage.TableExists(ATableName);
end;

function ColumnExistsWithStorage(const AStorage: IDiagnoseStorage;
  const ATableName, AColumnName: string): Boolean;
begin
  Result := Assigned(AStorage) and AStorage.ColumnExists(ATableName, AColumnName);
end;

function IndexExistsWithStorage(const AStorage: IDiagnoseStorage;
  const AIndexName: string): Boolean;
begin
  Result := Assigned(AStorage) and AStorage.IndexExists(AIndexName);
end;

function GetSchemaVersionWithStorage(const AStorage: IDiagnoseStorage): string;
begin
  if Assigned(AStorage) then
    Result := AStorage.GetSchemaVersion
  else
    Result := '';
end;

function CheckDataIntegrityWithStorage(
  const AStorage: IDiagnoseStorage): TDiagnoseResults;
begin
  if Assigned(AStorage) then
    Result := AStorage.CheckDataIntegrity
  else
    SetLength(Result, 0);
end;

function RequireDiagnoseStorage(AConnection: TObject): IDiagnoseStorage;
begin
  Result := CreateDiagnoseStorage(AConnection);
  if not Assigned(Result) then
    raise EInvalidOperation.Create(
      'No diagnose storage factory registered. Include DeepBase.Persistence.Diagnose.FireDAC.');
end;

function TableExists(AConnection: TObject; const ATableName: string): Boolean;
begin
  Result := TableExistsWithStorage(
    RequireDiagnoseStorage(AConnection), ATableName);
end;

function ColumnExists(AConnection: TObject; 
  const ATableName, AColumnName: string): Boolean;
begin
  Result := ColumnExistsWithStorage(
    RequireDiagnoseStorage(AConnection), ATableName, AColumnName);
end;

function IndexExists(AConnection: TObject; const AIndexName: string): Boolean;
begin
  Result := IndexExistsWithStorage(
    RequireDiagnoseStorage(AConnection), AIndexName);
end;

function GetSchemaVersion(AConnection: TObject): string;
begin
  Result := GetSchemaVersionWithStorage(RequireDiagnoseStorage(AConnection));
end;

function CheckSchemaVersion(AConnection: TObject): TDiagnoseResults;
begin
  Result := CheckSchemaVersionWithStorage(RequireDiagnoseStorage(AConnection));
end;

function CheckTablesExist(AConnection: TObject): TDiagnoseResults;
begin
  Result := CheckTablesExistWithStorage(RequireDiagnoseStorage(AConnection));
end;

function CheckColumnsExist(AConnection: TObject): TDiagnoseResults;
begin
  Result := CheckColumnsExistWithStorage(RequireDiagnoseStorage(AConnection));
end;

function CheckIndexesExist(AConnection: TObject): TDiagnoseResults;
begin
  Result := CheckIndexesExistWithStorage(RequireDiagnoseStorage(AConnection));
end;

function CheckDataIntegrity(AConnection: TObject): TDiagnoseResults;
begin
  Result := CheckDataIntegrityWithStorage(RequireDiagnoseStorage(AConnection));
end;

function DiagnoseAll(AConnection: TObject): TDiagnoseResults;
begin
  Result := DiagnoseAllWithStorage(RequireDiagnoseStorage(AConnection));
end;

function AddColumnIfNotExists(AConnection: TObject;
  const ATableName, AColumnName, AColumnDef: string): Boolean;
begin
  Result := AddColumnIfNotExistsWithStorage(
    RequireDiagnoseStorage(AConnection), ATableName, AColumnName, AColumnDef);
end;

function AutoFix(AConnection: TObject; const AResults: TDiagnoseResults): Integer;
begin
  Result := AutoFixWithStorage(RequireDiagnoseStorage(AConnection), AResults);
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
    SB.AppendLine('--------------------------------------------------');
    SB.AppendLine('DeepBase Database Diagnostic Report');
    SB.AppendLine('--------------------------------------------------');
    SB.AppendFormat('DeepBase Version: %s', [SCHEMA_VERSION]);
    SB.AppendLine;
    SB.AppendFormat('Check Time: %s', [FormatDateTime('yyyy-mm-dd hh:nn:ss', Now)]);
    SB.AppendLine;
    SB.AppendLine;

    if Length(AResults) = 0 then
    begin
      SB.AppendLine('[OK] No issues found. Database schema is valid.');
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
        if R.TableName <> '' then
        begin
          SB.AppendFormat('   Table: %s', [R.TableName]);
          SB.AppendLine;
        end;
        if R.ObjectName <> '' then
        begin
          SB.AppendFormat('   Object: %s', [R.ObjectName]);
          SB.AppendLine;
        end;
        SB.AppendFormat('   Suggestion: %s', [R.Suggestion]);
        SB.AppendLine;
        if R.CanAutoFix then
          SB.AppendLine('   [Can be auto-fixed]');
        SB.AppendLine;
      end;

      SB.AppendLine('--------------------------------------------------');
      SB.AppendFormat('Auto-fixable: %d | Manual fix required: %d', [FixableCount, UnfixableCount]);
      SB.AppendLine;

      if FixableCount > 0 then
        SB.AppendLine('Run AutoFix(DB, Results) to fix auto-fixable issues.');
    end;

    SB.AppendLine('--------------------------------------------------');

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
    Result := 'No issues found. 0 issue(s).';
    Exit;
  end;
  
  FixableCount := 0;
  for R in AResults do
    if R.CanAutoFix then
      Inc(FixableCount);
  
  Result := Format('Found %d issue(s), %d auto-fixable.', [Length(AResults), FixableCount]);
end;

end.
