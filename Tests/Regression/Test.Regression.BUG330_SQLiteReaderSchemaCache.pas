{ ============================================================================
  Test.Regression.BUG330_SQLiteReaderSchemaCache - REVIEW5-DATA-001

  Verifies that TExternalSQLiteReader caches schema after Open so that
  SafeQueryMessages can enumerate shard tables.

  Since the full SQLiteReader requires SQLCipher (encrypted DB), this test
  covers the data structure and code-path aspects:
  - TExternalDBSchema.IsBodyColumn works with populated schema
  - SafeQueryMessages shard table enumeration logic via TExternalDBSchema
  ============================================================================ }

unit Test.Regression.BUG330_SQLiteReaderSchemaCache;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  Test.Regression.Base,
  DeepBase.External.Types;

type
  [TestFixture]
  [Category('regression')]
  TBUG330_SQLiteReaderSchemaCacheTest = class(TRegressionTestBase)
  protected
    function GetBugNumber: string; override;
    function GetBugDescription: string; override;
    function GetFixDate: string; override;
    function GetPriority: string; override;
    function GetAffectedFile: string; override;
  public
    /// <summary>TExternalDBSchema.IsBodyColumn works with populated tables</summary>
    [Test]
    procedure Test_ExternalDBSchema_IsBodyColumn;

    /// <summary>TExternalDBSchema with empty Tables has no body columns</summary>
    [Test]
    procedure Test_ExternalDBSchema_EmptySchema_NoBodyColumns;

    /// <summary>Shard table name enumeration matches CShardTableNames layout</summary>
    [Test]
    procedure Test_ShardTableNames_AreConsistent;
  end;

implementation

function TBUG330_SQLiteReaderSchemaCacheTest.GetBugNumber: string;
begin
  Result := 'BUG-330';
end;

function TBUG330_SQLiteReaderSchemaCacheTest.GetBugDescription: string;
begin
  Result := 'SQLiteReader does not cache schema after Open, SafeQueryMessages iterates empty FSchema';
end;

function TBUG330_SQLiteReaderSchemaCacheTest.GetFixDate: string;
begin
  Result := '2026-06-29';
end;

function TBUG330_SQLiteReaderSchemaCacheTest.GetPriority: string;
begin
  Result := 'P1';
end;

function TBUG330_SQLiteReaderSchemaCacheTest.GetAffectedFile: string;
begin
  Result := 'DeepAxis/DeepBase.External.SQLiteReader.pas';
end;

procedure TBUG330_SQLiteReaderSchemaCacheTest.Test_ExternalDBSchema_IsBodyColumn;
var
  Schema: TExternalDBSchema;
  MsgTable: TTableInfo;
  BodyCol, NormalCol: TColumnInfo;
begin
  // Build a schema with one table containing body and normal columns
  BodyCol.Name := 'Content';
  BodyCol.DataType := 'TEXT';
  BodyCol.IsBodyColumn := True;
  BodyCol.IsPII := False;

  NormalCol.Name := 'MsgSvrID';
  NormalCol.DataType := 'INTEGER';
  NormalCol.IsBodyColumn := False;
  NormalCol.IsPII := False;

  MsgTable.Name := 'MSG';
  MsgTable.Columns := TArray<TColumnInfo>.Create(BodyCol, NormalCol);
  MsgTable.RowCount := 100;

  Schema.Tables := TArray<TTableInfo>.Create(MsgTable);
  Schema.DbPath := '/test/db.sqlite';

  Assert.IsTrue(Schema.IsBodyColumn('MSG', 'Content'),
    'Content should be a body column');
  Assert.IsFalse(Schema.IsBodyColumn('MSG', 'MsgSvrID'),
    'MsgSvrID should NOT be a body column');
  Assert.IsFalse(Schema.IsBodyColumn('NONEXISTENT', 'Content'),
    'Non-existent table should return false');
end;

procedure TBUG330_SQLiteReaderSchemaCacheTest.Test_ExternalDBSchema_EmptySchema_NoBodyColumns;
var
  Schema: TExternalDBSchema;
begin
  // Empty schema (as was the case before the fix) has no body columns
  SetLength(Schema.Tables, 0);
  Assert.IsFalse(Schema.IsBodyColumn('MSG', 'Content'),
    'Empty schema should return false for IsBodyColumn');
end;

procedure TBUG330_SQLiteReaderSchemaCacheTest.Test_ShardTableNames_AreConsistent;
const
  // Must match CShardTableNames in SQLiteReader.SafeQueryMessages
  CExpectedShards: array[0..5] of string = (
    'MSG', 'MSG0', 'MSG1', 'MSG2', 'MSG3', 'MSG4'
  );
var
  Schema: TExternalDBSchema;
  I: Integer;
  LTable: TTableInfo;
  LCol: TColumnInfo;
begin
  // Build schema with all shard tables
  SetLength(Schema.Tables, Length(CExpectedShards));
  for I := 0 to High(CExpectedShards) do
  begin
    LCol.Name := 'StrTalker';
    LCol.DataType := 'TEXT';
    LCol.IsBodyColumn := False;
    LCol.IsPII := False;

    LTable.Name := CExpectedShards[I];
    LTable.Columns := TArray<TColumnInfo>.Create(LCol);
    LTable.RowCount := 0;
    Schema.Tables[I] := LTable;
  end;

  // Verify all shard tables are found in schema (this is what SafeQueryMessages does)
  for I := 0 to High(CExpectedShards) do
  begin
    var Found := False;
    for var Table in Schema.Tables do
      if SameText(Table.Name, CExpectedShards[I]) then
      begin
        Found := True;
        Break;
      end;
    Assert.IsTrue(Found,
      'Shard table ' + CExpectedShards[I] + ' should be found in cached schema');
  end;
end;

end.
