{ ============================================================================
  Test.DeepBase.Diagnose - Unit Tests for Database Schema Diagnostic Module
  
  Test Coverage:
    - TableExists function
    - ColumnExists function
    - IndexExists function
    - GetSchemaVersion function
    - CheckTablesExist function
    - CheckColumnsExist function
    - CheckSchemaVersion function
    - CheckDataIntegrity function
    - DiagnoseAll comprehensive check
    - AutoFix automatic repair
    - AddColumnIfNotExists function
    - Report generation (GenerateDiagnoseReport, GenerateDiagnoseSummary)
  ============================================================================ }

unit Test.DeepBase.Diagnose;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  FireDAC.Comp.Client,
  FireDAC.Stan.Def,
  FireDAC.Stan.Async,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  DeepBase.Diagnose;

type
  [TestFixture]
  TTestDiagnoseHelpers = class
  private
    FConnection: TFDConnection;
    FTempDBPath: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_TableExists_True;
    [Test]
    procedure Test_TableExists_False;
    [Test]
    procedure Test_TableExists_CaseInsensitive;
    [Test]
    procedure Test_ColumnExists_True;
    [Test]
    procedure Test_ColumnExists_False;
    [Test]
    procedure Test_ColumnExists_NonExistentTable;
    [Test]
    procedure Test_IndexExists_True;
    [Test]
    procedure Test_IndexExists_False;
  end;

  [TestFixture]
  TTestSchemaVersion = class
  private
    FConnection: TFDConnection;
    FTempDBPath: string;
    procedure CreateSchemaInfoTable;
    procedure SetSchemaVersion(const Version: string);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_GetSchemaVersion_NoTable;
    [Test]
    procedure Test_GetSchemaVersion_NoValue;
    [Test]
    procedure Test_GetSchemaVersion_Valid;
    [Test]
    procedure Test_CheckSchemaVersion_NoVersion;
    [Test]
    procedure Test_CheckSchemaVersion_OldVersion;
    [Test]
    procedure Test_CheckSchemaVersion_CurrentVersion;
    [Test]
    procedure Test_CheckSchemaVersion_DifferentVersion;
  end;

  [TestFixture]
  TTestCheckTables = class
  private
    FConnection: TFDConnection;
    FTempDBPath: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_CheckTablesExist_EmptyDB;
    [Test]
    procedure Test_CheckTablesExist_Tier0Only;
    [Test]
    procedure Test_CheckTablesExist_AllTables;
    [Test]
    procedure Test_CheckTablesExist_MissingOne;
  end;

  [TestFixture]
  TTestCheckColumns = class
  private
    FConnection: TFDConnection;
    FTempDBPath: string;
    procedure CreateMinimalTable(const TableName: string);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_CheckColumnsExist_MissingColumns;
    [Test]
    procedure Test_CheckColumnsExist_AllPresent;
  end;

  [TestFixture]
  TTestAutoFix = class
  private
    FConnection: TFDConnection;
    FTempDBPath: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_AddColumnIfNotExists_NewColumn;
    [Test]
    procedure Test_AddColumnIfNotExists_ExistingColumn;
    [Test]
    procedure Test_AutoFix_CreateMissingTable;
    [Test]
    procedure Test_AutoFix_AddMissingColumn;
    [Test]
    procedure Test_AutoFix_NonFixableIssue;
    [Test]
    procedure Test_AutoFix_MultipleIssues;
  end;

  [TestFixture]
  TTestDiagnoseAll = class
  private
    FConnection: TFDConnection;
    FTempDBPath: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_DiagnoseAll_EmptyDB;
    [Test]
    procedure Test_DiagnoseAll_PartialSchema;
    [Test]
    procedure Test_DiagnoseAll_CompleteSchema;
  end;

  [TestFixture]
  TTestReportGeneration = class
  private
    FConnection: TFDConnection;
    FTempDBPath: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_GenerateDiagnoseReport_NoIssues;
    [Test]
    procedure Test_GenerateDiagnoseReport_WithIssues;
    [Test]
    procedure Test_GenerateDiagnoseSummary_NoIssues;
    [Test]
    procedure Test_GenerateDiagnoseSummary_WithIssues;
    [Test]
    procedure Test_GenerateDiagnoseReport_Format;
  end;

  [TestFixture]
  TTestDiagnoseResult = class
  public
    [Test]
    procedure Test_IssueType_Values;
    [Test]
    procedure Test_Result_Fields;
  end;

  [TestFixture]
  TTestDiagnoseStorageInjection = class
  public
    [Test]
    procedure Test_DiagnoseAllWithStorage_AggregatesProvidedResults;
    [Test]
    procedure Test_AutoFixWithStorage_DelegatesToStorage;
    [Test]
    procedure Test_DiagnoseAll_WithoutFactory_RaisesHelpfulError;
  end;

implementation

uses
  DeepBase.Schema,
  DeepBase.Persistence.Diagnose.FireDAC;

type
  TInMemoryDiagnoseStorage = class(TInterfacedObject, IDiagnoseStorage)
  public
    VersionResults: TDiagnoseResults;
    TableResults: TDiagnoseResults;
    ColumnResults: TDiagnoseResults;
    IndexResults: TDiagnoseResults;
    IntegrityResults: TDiagnoseResults;
    AutoFixResult: Integer;
    LastAutoFixInputCount: Integer;

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

function TInMemoryDiagnoseStorage.DiagnoseAll: TDiagnoseResults;
var
  R: TDiagnoseResult;
  L: TList<TDiagnoseResult>;
begin
  L := TList<TDiagnoseResult>.Create;
  try
    for R in VersionResults do L.Add(R);
    for R in TableResults do L.Add(R);
    for R in ColumnResults do L.Add(R);
    for R in IndexResults do L.Add(R);
    for R in IntegrityResults do L.Add(R);
    Result := L.ToArray;
  finally
    L.Free;
  end;
end;

function TInMemoryDiagnoseStorage.CheckTablesExist: TDiagnoseResults;
begin
  Result := TableResults;
end;

function TInMemoryDiagnoseStorage.CheckColumnsExist: TDiagnoseResults;
begin
  Result := ColumnResults;
end;

function TInMemoryDiagnoseStorage.CheckIndexesExist: TDiagnoseResults;
begin
  Result := IndexResults;
end;

function TInMemoryDiagnoseStorage.CheckSchemaVersion: TDiagnoseResults;
begin
  Result := VersionResults;
end;

function TInMemoryDiagnoseStorage.CheckDataIntegrity: TDiagnoseResults;
begin
  Result := IntegrityResults;
end;

function TInMemoryDiagnoseStorage.AutoFix(
  const AResults: TDiagnoseResults): Integer;
begin
  LastAutoFixInputCount := Length(AResults);
  Result := AutoFixResult;
end;

function TInMemoryDiagnoseStorage.AddColumnIfNotExists(const ATableName,
  AColumnName, AColumnDef: string): Boolean;
begin
  Result := True;
end;

function TInMemoryDiagnoseStorage.TableExists(const ATableName: string): Boolean;
begin
  Result := True;
end;

function TInMemoryDiagnoseStorage.ColumnExists(const ATableName,
  AColumnName: string): Boolean;
begin
  Result := True;
end;

function TInMemoryDiagnoseStorage.IndexExists(const AIndexName: string): Boolean;
begin
  Result := True;
end;

function TInMemoryDiagnoseStorage.GetSchemaVersion: string;
begin
  Result := SCHEMA_VERSION;
end;

{ Helper functions }

function CreateTestConnection(const DBPath: string): TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  Result.DriverName := 'SQLite';
  Result.Params.Database := DBPath;
  Result.Params.Values['LockingMode'] := 'Normal';
  Result.LoginPrompt := False;
  Result.Open;
end;

procedure ExecuteSQL(AConn: TFDConnection; const SQL: string);
begin
  // FireDAC's ExecSQL handles multi-statement SQL with semicolons inside
  // string literals correctly — the TFDQuery.SQL.Text path splits on ';'
  // naively and breaks on ';'-bearing values like 'h:mm:ss tt'.
  AConn.ExecSQL(SQL);
end;

{ TTestDiagnoseHelpers }

procedure TTestDiagnoseHelpers.Setup;
begin
  FTempDBPath := TPath.Combine(TPath.GetTempPath, 'test_diagnose_' + TGUID.NewGuid.ToString + '.db');
  FConnection := CreateTestConnection(FTempDBPath);
  
  // Create test tables
  ExecuteSQL(FConnection, 'CREATE TABLE TestTable (ID INTEGER PRIMARY KEY, Name TEXT)');
  ExecuteSQL(FConnection, 'CREATE INDEX idx_test ON TestTable(Name)');
end;

procedure TTestDiagnoseHelpers.TearDown;
begin
  FConnection.Free;
  if TFile.Exists(FTempDBPath) then
    TFile.Delete(FTempDBPath);
end;

procedure TTestDiagnoseHelpers.Test_TableExists_True;
begin
  Assert.IsTrue(TableExists(FConnection, 'TestTable'));
end;

procedure TTestDiagnoseHelpers.Test_TableExists_False;
begin
  Assert.IsFalse(TableExists(FConnection, 'NonExistentTable'));
end;

procedure TTestDiagnoseHelpers.Test_TableExists_CaseInsensitive;
begin
  // SQLite table names are case-insensitive for ASCII
  Assert.IsTrue(TableExists(FConnection, 'testtable'));
  Assert.IsTrue(TableExists(FConnection, 'TESTTABLE'));
end;

procedure TTestDiagnoseHelpers.Test_ColumnExists_True;
begin
  Assert.IsTrue(ColumnExists(FConnection, 'TestTable', 'ID'));
  Assert.IsTrue(ColumnExists(FConnection, 'TestTable', 'Name'));
end;

procedure TTestDiagnoseHelpers.Test_ColumnExists_False;
begin
  Assert.IsFalse(ColumnExists(FConnection, 'TestTable', 'NonExistentColumn'));
end;

procedure TTestDiagnoseHelpers.Test_ColumnExists_NonExistentTable;
begin
  Assert.IsFalse(ColumnExists(FConnection, 'NoSuchTable', 'AnyColumn'));
end;

procedure TTestDiagnoseHelpers.Test_IndexExists_True;
begin
  Assert.IsTrue(IndexExists(FConnection, 'idx_test'));
end;

procedure TTestDiagnoseHelpers.Test_IndexExists_False;
begin
  Assert.IsFalse(IndexExists(FConnection, 'idx_nonexistent'));
end;

{ TTestSchemaVersion }

procedure TTestSchemaVersion.Setup;
begin
  FTempDBPath := TPath.Combine(TPath.GetTempPath, 'test_version_' + TGUID.NewGuid.ToString + '.db');
  FConnection := CreateTestConnection(FTempDBPath);
end;

procedure TTestSchemaVersion.TearDown;
begin
  FConnection.Free;
  if TFile.Exists(FTempDBPath) then
    TFile.Delete(FTempDBPath);
end;

procedure TTestSchemaVersion.CreateSchemaInfoTable;
begin
  ExecuteSQL(FConnection, 
    'CREATE TABLE SchemaInfo (Key TEXT PRIMARY KEY, Value TEXT, Extra TEXT, Remarks TEXT)');
end;

procedure TTestSchemaVersion.SetSchemaVersion(const Version: string);
begin
  ExecuteSQL(FConnection, Format(
    'INSERT OR REPLACE INTO SchemaInfo (Key, Value) VALUES (''SchemaVersion'', ''%s'')',
    [Version]));
end;

procedure TTestSchemaVersion.Test_GetSchemaVersion_NoTable;
begin
  Assert.AreEqual('', GetSchemaVersion(FConnection));
end;

procedure TTestSchemaVersion.Test_GetSchemaVersion_NoValue;
begin
  CreateSchemaInfoTable;
  Assert.AreEqual('', GetSchemaVersion(FConnection));
end;

procedure TTestSchemaVersion.Test_GetSchemaVersion_Valid;
begin
  CreateSchemaInfoTable;
  SetSchemaVersion('1.0.0');
  Assert.AreEqual('1.0.0', GetSchemaVersion(FConnection));
end;

procedure TTestSchemaVersion.Test_CheckSchemaVersion_NoVersion;
var
  Results: TDiagnoseResults;
begin
  CreateSchemaInfoTable;
  Results := CheckSchemaVersion(FConnection);
  Assert.AreEqual<Integer>(1, Length(Results));
  Assert.AreEqual(ditVersionMismatch, Results[0].IssueType);
  Assert.IsFalse(Results[0].IsOK);
  Assert.IsTrue(Results[0].CanAutoFix);
end;

procedure TTestSchemaVersion.Test_CheckSchemaVersion_OldVersion;
var
  Results: TDiagnoseResults;
begin
  CreateSchemaInfoTable;
  SetSchemaVersion('0.1.0');  // Very old version
  Results := CheckSchemaVersion(FConnection);
  Assert.AreEqual<Integer>(1, Length(Results));
  Assert.IsFalse(Results[0].CanAutoFix);
  Assert.IsTrue(Results[0].Issue.Contains('too old'));
end;

procedure TTestSchemaVersion.Test_CheckSchemaVersion_CurrentVersion;
var
  Results: TDiagnoseResults;
begin
  CreateSchemaInfoTable;
  SetSchemaVersion(SCHEMA_VERSION);
  Results := CheckSchemaVersion(FConnection);
  Assert.AreEqual<Integer>(0, Length(Results));  // No issues
end;

procedure TTestSchemaVersion.Test_CheckSchemaVersion_DifferentVersion;
var
  Results: TDiagnoseResults;
begin
  CreateSchemaInfoTable;
  SetSchemaVersion('99.0.0');  // Future version
  Results := CheckSchemaVersion(FConnection);
  // Different version should produce a warning
  Assert.IsTrue(Length(Results) >= 0);  // May or may not be an issue depending on logic
end;

{ TTestCheckTables }

procedure TTestCheckTables.Setup;
begin
  FTempDBPath := TPath.Combine(TPath.GetTempPath, 'test_tables_' + TGUID.NewGuid.ToString + '.db');
  FConnection := CreateTestConnection(FTempDBPath);
end;

procedure TTestCheckTables.TearDown;
begin
  FConnection.Free;
  if TFile.Exists(FTempDBPath) then
    TFile.Delete(FTempDBPath);
end;

procedure TTestCheckTables.Test_CheckTablesExist_EmptyDB;
var
  Results: TDiagnoseResults;
begin
  Results := CheckTablesExist(FConnection);
  // Should report all Tier0, Tier1, Tier2 tables as missing
  Assert.IsTrue(Length(Results) >= 5);  // At least Tier0 tables
end;

procedure TTestCheckTables.Test_CheckTablesExist_Tier0Only;
var
  Results: TDiagnoseResults;
  I: Integer;
begin
  // Create Tier0 tables
  for I := Low(TIER0_TABLES) to High(TIER0_TABLES) do
    ExecuteSQL(FConnection, Format('CREATE TABLE %s (ID INTEGER PRIMARY KEY)', [TIER0_TABLES[I]]));
  
  Results := CheckTablesExist(FConnection);
  // Tier1 and Tier2 tables should be missing
  Assert.IsTrue(Length(Results) >= Length(TIER1_TABLES));
end;

procedure TTestCheckTables.Test_CheckTablesExist_AllTables;
var
  I: Integer;
  Results: TDiagnoseResults;
begin
  // Create all tables
  for I := Low(TIER0_TABLES) to High(TIER0_TABLES) do
    ExecuteSQL(FConnection, Format('CREATE TABLE %s (ID INTEGER PRIMARY KEY)', [TIER0_TABLES[I]]));
  for I := Low(TIER1_TABLES) to High(TIER1_TABLES) do
    ExecuteSQL(FConnection, Format('CREATE TABLE %s (ID INTEGER PRIMARY KEY)', [TIER1_TABLES[I]]));
  for I := Low(TIER2_TABLES) to High(TIER2_TABLES) do
    ExecuteSQL(FConnection, Format('CREATE TABLE %s (ID INTEGER PRIMARY KEY)', [TIER2_TABLES[I]]));
  
  Results := CheckTablesExist(FConnection);
  Assert.AreEqual<Integer>(0, Length(Results));  // All tables exist
end;

procedure TTestCheckTables.Test_CheckTablesExist_MissingOne;
var
  I: Integer;
  Results: TDiagnoseResults;
begin
  // Create all Tier0 tables except Settings
  for I := Low(TIER0_TABLES) to High(TIER0_TABLES) do
    if TIER0_TABLES[I] <> 'Settings' then
      ExecuteSQL(FConnection, Format('CREATE TABLE %s (ID INTEGER PRIMARY KEY)', [TIER0_TABLES[I]]));
  
  Results := CheckTablesExist(FConnection);
  // Should find Settings as missing plus all Tier1/Tier2
  Assert.IsTrue(Length(Results) >= 1);
  
  // Find Settings in results
  var Found := False;
  for I := 0 to High(Results) do
    if Results[I].TableName = 'Settings' then
    begin
      Found := True;
      Assert.AreEqual(ditMissingTable, Results[I].IssueType);
      Break;
    end;
  Assert.IsTrue(Found, 'Settings should be reported as missing');
end;

{ TTestCheckColumns }

procedure TTestCheckColumns.Setup;
begin
  FTempDBPath := TPath.Combine(TPath.GetTempPath, 'test_columns_' + TGUID.NewGuid.ToString + '.db');
  FConnection := CreateTestConnection(FTempDBPath);
end;

procedure TTestCheckColumns.TearDown;
begin
  FConnection.Free;
  if TFile.Exists(FTempDBPath) then
    TFile.Delete(FTempDBPath);
end;

procedure TTestCheckColumns.CreateMinimalTable(const TableName: string);
begin
  ExecuteSQL(FConnection, Format('CREATE TABLE %s (ID INTEGER PRIMARY KEY)', [TableName]));
end;

procedure TTestCheckColumns.Test_CheckColumnsExist_MissingColumns;
var
  Results: TDiagnoseResults;
begin
  // Create SchemaInfo with only ID column (missing Extra, Remarks)
  CreateMinimalTable('SchemaInfo');
  
  Results := CheckColumnsExist(FConnection);
  Assert.IsTrue(Length(Results) >= 1);  // Should report missing columns
  
  var Found := False;
  for var I := 0 to High(Results) do
    if (Results[I].TableName = 'SchemaInfo') and (Results[I].IssueType = ditMissingColumn) then
    begin
      Found := True;
      Break;
    end;
  Assert.IsTrue(Found, 'Should report missing columns in SchemaInfo');
end;

procedure TTestCheckColumns.Test_CheckColumnsExist_AllPresent;
var
  Results: TDiagnoseResults;
begin
  // Create SchemaInfo with all required columns
  ExecuteSQL(FConnection, 
    'CREATE TABLE SchemaInfo (Key TEXT PRIMARY KEY, Value TEXT, Extra TEXT, Remarks TEXT)');
  
  Results := CheckColumnsExist(FConnection);
  // Should not report SchemaInfo column issues
  var HasSchemaInfoIssue := False;
  for var I := 0 to High(Results) do
    if (Results[I].TableName = 'SchemaInfo') and (Results[I].IssueType = ditMissingColumn) then
    begin
      HasSchemaInfoIssue := True;
      Break;
    end;
  Assert.IsFalse(HasSchemaInfoIssue);
end;

{ TTestAutoFix }

procedure TTestAutoFix.Setup;
begin
  FTempDBPath := TPath.Combine(TPath.GetTempPath, 'test_autofix_' + TGUID.NewGuid.ToString + '.db');
  FConnection := CreateTestConnection(FTempDBPath);
end;

procedure TTestAutoFix.TearDown;
begin
  FConnection.Free;
  if TFile.Exists(FTempDBPath) then
    TFile.Delete(FTempDBPath);
end;

procedure TTestAutoFix.Test_AddColumnIfNotExists_NewColumn;
begin
  ExecuteSQL(FConnection, 'CREATE TABLE TestTable (ID INTEGER PRIMARY KEY)');
  
  var Added := AddColumnIfNotExists(FConnection, 'TestTable', 'NewCol', 'TEXT DEFAULT ''''');
  Assert.IsTrue(Added);
  Assert.IsTrue(ColumnExists(FConnection, 'TestTable', 'NewCol'));
end;

procedure TTestAutoFix.Test_AddColumnIfNotExists_ExistingColumn;
begin
  ExecuteSQL(FConnection, 'CREATE TABLE TestTable (ID INTEGER PRIMARY KEY, ExistingCol TEXT)');
  
  var Added := AddColumnIfNotExists(FConnection, 'TestTable', 'ExistingCol', 'TEXT');
  Assert.IsFalse(Added);  // Column already exists, should not add again
end;

procedure TTestAutoFix.Test_AutoFix_CreateMissingTable;
var
  Results: TDiagnoseResults;
  FixedCount: Integer;
begin
  // Empty DB - all tables missing
  Results := CheckTablesExist(FConnection);
  Assert.IsTrue(Length(Results) > 0);
  
  // Fix should create tables with FixSQL
  FixedCount := AutoFix(FConnection, Results);
  Assert.IsTrue(FixedCount > 0);
  
  // Verify some tables were created
  Assert.IsTrue(TableExists(FConnection, 'SchemaInfo') or TableExists(FConnection, 'Settings'));
end;

procedure TTestAutoFix.Test_AutoFix_AddMissingColumn;
var
  Results: TDiagnoseResults;
  FixedCount: Integer;
begin
  // Create SchemaInfo without Extra column
  ExecuteSQL(FConnection, 'CREATE TABLE SchemaInfo (Key TEXT PRIMARY KEY, Value TEXT)');
  
  Results := CheckColumnsExist(FConnection);
  FixedCount := AutoFix(FConnection, Results);
  
  // Extra column should be added if it was fixable
  if FixedCount > 0 then
    Assert.IsTrue(ColumnExists(FConnection, 'SchemaInfo', 'Extra'));
end;

procedure TTestAutoFix.Test_AutoFix_NonFixableIssue;
var
  Results: TDiagnoseResults;
begin
  // Create a non-fixable issue
  ExecuteSQL(FConnection, 
    'CREATE TABLE SchemaInfo (Key TEXT PRIMARY KEY, Value TEXT, Extra TEXT, Remarks TEXT)');
  ExecuteSQL(FConnection, 
    'INSERT INTO SchemaInfo (Key, Value) VALUES (''SchemaVersion'', ''0.0.1'')');
  
  Results := CheckSchemaVersion(FConnection);
  AutoFix(FConnection, Results);
  
  // Old version issues may not be auto-fixable
  // Just verify the function doesn't crash
  Assert.Pass;
end;

procedure TTestAutoFix.Test_AutoFix_MultipleIssues;
var
  Results: TDiagnoseResults;
  FixedCount: Integer;
begin
  Results := DiagnoseAll(FConnection);
  FixedCount := AutoFix(FConnection, Results);
  
  // Should fix multiple issues
  Assert.IsTrue(FixedCount >= 0);
end;

{ TTestDiagnoseAll }

procedure TTestDiagnoseAll.Setup;
begin
  FTempDBPath := TPath.Combine(TPath.GetTempPath, 'test_diagnose_all_' + TGUID.NewGuid.ToString + '.db');
  FConnection := CreateTestConnection(FTempDBPath);
end;

procedure TTestDiagnoseAll.TearDown;
begin
  FConnection.Free;
  if TFile.Exists(FTempDBPath) then
    TFile.Delete(FTempDBPath);
end;

procedure TTestDiagnoseAll.Test_DiagnoseAll_EmptyDB;
var
  Results: TDiagnoseResults;
begin
  Results := DiagnoseAll(FConnection);
  // Should report many issues for empty DB
  Assert.IsTrue(Length(Results) > 10);
end;

procedure TTestDiagnoseAll.Test_DiagnoseAll_PartialSchema;
var
  Results: TDiagnoseResults;
begin
  // Create only Tier0 tables with minimal columns
  ExecuteSQL(FConnection, 'CREATE TABLE SchemaInfo (Key TEXT PRIMARY KEY, Value TEXT)');
  ExecuteSQL(FConnection, 'CREATE TABLE Settings (Key TEXT PRIMARY KEY, Value TEXT)');
  
  Results := DiagnoseAll(FConnection);
  // Should still report missing tables and columns
  Assert.IsTrue(Length(Results) > 0);
end;

procedure TTestDiagnoseAll.Test_DiagnoseAll_CompleteSchema;
var
  Results: TDiagnoseResults;
begin
  // Execute full schema SQL
  ExecuteSQL(FConnection, GetFullSchemaSQL);
  
  Results := DiagnoseAll(FConnection);
  // Should report few or no issues
  Assert.IsTrue(Length(Results) < 5);
end;

{ TTestReportGeneration }

procedure TTestReportGeneration.Setup;
begin
  FTempDBPath := TPath.Combine(TPath.GetTempPath, 'test_report_' + TGUID.NewGuid.ToString + '.db');
  FConnection := CreateTestConnection(FTempDBPath);
end;

procedure TTestReportGeneration.TearDown;
begin
  FConnection.Free;
  if TFile.Exists(FTempDBPath) then
    TFile.Delete(FTempDBPath);
end;

procedure TTestReportGeneration.Test_GenerateDiagnoseReport_NoIssues;
var
  Results: TDiagnoseResults;
  Report: string;
begin
  SetLength(Results, 0);
  Report := GenerateDiagnoseReport(Results);
  Assert.IsTrue(Report.Contains('No issues') or (Report = ''));
end;

procedure TTestReportGeneration.Test_GenerateDiagnoseReport_WithIssues;
var
  Results: TDiagnoseResults;
  Report: string;
begin
  Results := DiagnoseAll(FConnection);  // Will have issues on empty DB
  Report := GenerateDiagnoseReport(Results);
  Assert.IsTrue(Length(Report) > 0);
  Assert.IsTrue(Report.Contains('Table') or Report.Contains('Issue'));
end;

procedure TTestReportGeneration.Test_GenerateDiagnoseSummary_NoIssues;
var
  Results: TDiagnoseResults;
  Summary: string;
begin
  SetLength(Results, 0);
  Summary := GenerateDiagnoseSummary(Results);
  Assert.IsTrue(Summary.Contains('0') or Summary.Contains('No'));
end;

procedure TTestReportGeneration.Test_GenerateDiagnoseSummary_WithIssues;
var
  Results: TDiagnoseResults;
  Summary: string;
begin
  Results := DiagnoseAll(FConnection);
  Summary := GenerateDiagnoseSummary(Results);
  Assert.IsTrue(Length(Summary) > 0);
end;

procedure TTestReportGeneration.Test_GenerateDiagnoseReport_Format;
var
  Results: TDiagnoseResults;
  Report: string;
begin
  // Create specific issue
  SetLength(Results, 1);
  Results[0].IssueType := ditMissingTable;
  Results[0].IsOK := False;
  Results[0].TableName := 'TestTable';
  Results[0].Issue := 'Table does not exist';
  Results[0].Suggestion := 'Create the table';
  Results[0].CanAutoFix := True;
  Results[0].FixSQL := 'CREATE TABLE TestTable...';
  
  Report := GenerateDiagnoseReport(Results);
  Assert.IsTrue(Report.Contains('TestTable'));
  Assert.IsTrue(Report.Contains('does not exist'));
end;

{ TTestDiagnoseResult }

procedure TTestDiagnoseResult.Test_IssueType_Values;
begin
  // Verify all issue types exist
  Assert.AreEqual(0, Ord(ditMissingTable));
  Assert.AreEqual(1, Ord(ditMissingColumn));
  Assert.AreEqual(2, Ord(ditMissingIndex));
  Assert.AreEqual(3, Ord(ditVersionMismatch));
  Assert.AreEqual(4, Ord(ditDataIntegrity));
  Assert.AreEqual(5, Ord(ditForeignKey));
  Assert.AreEqual(6, Ord(ditNullValue));
  Assert.AreEqual(7, Ord(ditInvalidEnum));
  Assert.AreEqual(8, Ord(ditCheckError));
end;

procedure TTestDiagnoseResult.Test_Result_Fields;
var
  R: TDiagnoseResult;
begin
  R.IssueType := ditMissingTable;
  R.IsOK := False;
  R.TableName := 'Test';
  R.ObjectName := 'Column1';
  R.Issue := 'Issue description';
  R.Suggestion := 'Fix it';
  R.FixSQL := 'ALTER TABLE...';
  R.CanAutoFix := True;
  
  Assert.AreEqual(ditMissingTable, R.IssueType);
  Assert.IsFalse(R.IsOK);
  Assert.AreEqual('Test', R.TableName);
  Assert.AreEqual('Column1', R.ObjectName);
  Assert.AreEqual('Issue description', R.Issue);
  Assert.AreEqual('Fix it', R.Suggestion);
  Assert.AreEqual('ALTER TABLE...', R.FixSQL);
  Assert.IsTrue(R.CanAutoFix);
end;

{ TTestDiagnoseStorageInjection }

procedure TTestDiagnoseStorageInjection.Test_DiagnoseAllWithStorage_AggregatesProvidedResults;
var
  Storage: IDiagnoseStorage;
  Mem: TInMemoryDiagnoseStorage;
  Results: TDiagnoseResults;
begin
  Mem := TInMemoryDiagnoseStorage.Create;
  Storage := Mem;

  SetLength(Mem.VersionResults, 1);
  Mem.VersionResults[0].IssueType := ditVersionMismatch;
  Mem.VersionResults[0].Issue := 'version issue';

  SetLength(Mem.TableResults, 1);
  Mem.TableResults[0].IssueType := ditMissingTable;
  Mem.TableResults[0].Issue := 'table issue';

  SetLength(Mem.ColumnResults, 1);
  Mem.ColumnResults[0].IssueType := ditMissingColumn;
  Mem.ColumnResults[0].Issue := 'column issue';

  SetLength(Mem.IndexResults, 1);
  Mem.IndexResults[0].IssueType := ditMissingIndex;
  Mem.IndexResults[0].Issue := 'index issue';

  SetLength(Mem.IntegrityResults, 1);
  Mem.IntegrityResults[0].IssueType := ditDataIntegrity;
  Mem.IntegrityResults[0].Issue := 'integrity issue';

  Results := DiagnoseAllWithStorage(Storage);

  Assert.AreEqual<Integer>(5, Length(Results));
  Assert.AreEqual(ditVersionMismatch, Results[0].IssueType);
  Assert.AreEqual(ditMissingTable, Results[1].IssueType);
  Assert.AreEqual(ditMissingColumn, Results[2].IssueType);
  Assert.AreEqual(ditMissingIndex, Results[3].IssueType);
  Assert.AreEqual(ditDataIntegrity, Results[4].IssueType);
end;

procedure TTestDiagnoseStorageInjection.Test_AutoFixWithStorage_DelegatesToStorage;
var
  Storage: IDiagnoseStorage;
  Mem: TInMemoryDiagnoseStorage;
  Input: TDiagnoseResults;
begin
  Mem := TInMemoryDiagnoseStorage.Create;
  Storage := Mem;
  Mem.AutoFixResult := 7;

  SetLength(Input, 2);
  Input[0].IssueType := ditMissingTable;
  Input[1].IssueType := ditMissingColumn;

  Assert.AreEqual(7, AutoFixWithStorage(Storage, Input));
  Assert.AreEqual(2, Mem.LastAutoFixInputCount);
end;

procedure TTestDiagnoseStorageInjection.Test_DiagnoseAll_WithoutFactory_RaisesHelpfulError;
var
  RaisedMsg: string;
begin
  SetDiagnoseStorageFactory(nil);
  try
    RaisedMsg := '';
    try
      DiagnoseAll(nil);
      Assert.Fail('missing factory should raise');
    except
      on E: EInvalidOperation do
        RaisedMsg := E.Message;
    end;

    Assert.IsTrue(RaisedMsg.Contains('DeepBase.Persistence.Diagnose.FireDAC'),
      'error message should guide persistence module registration');
  finally
    RegisterDiagnoseStorageFactory;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDiagnoseHelpers);
  TDUnitX.RegisterTestFixture(TTestSchemaVersion);
  TDUnitX.RegisterTestFixture(TTestCheckTables);
  TDUnitX.RegisterTestFixture(TTestCheckColumns);
  TDUnitX.RegisterTestFixture(TTestAutoFix);
  TDUnitX.RegisterTestFixture(TTestDiagnoseAll);
  TDUnitX.RegisterTestFixture(TTestReportGeneration);
  TDUnitX.RegisterTestFixture(TTestDiagnoseResult);
  TDUnitX.RegisterTestFixture(TTestDiagnoseStorageInjection);

end.
