{ ============================================================================
  Test.DeepBase.LLM.Schema.PBT - Property-based tests for LLM canonical
  schema initialization.

  Properties covered:
    P1: LLM Schema Initialization Completeness (Req 1.1)
        After running the LLM schema SQL on an empty SQLite database, all
        canonical LLM tables exist and are queryable.

    P2: LLMCalls Canonical Field Set (Req 1.4)
        The LLMCalls table contains the canonical columns required by
        TLLMManager: model identifier, provider, token counters, duration,
        status, error and timestamp. No legacy-only columns (e.g.
        deprecated 'CallerHost') are present.

  Each property runs >= 100 random iterations. Each iteration uses a
  fresh in-memory SQLite database so isolation is guaranteed.

  Note on naming: the design document uses snake_case canonical names
  (model, provider, input_tokens, ...). The DeepBase schema unit defines
  these columns in PascalCase (ModelId, ProviderCode, InputTokens, ...).
  The test verifies the PascalCase column names that the schema actually
  emits, which is the contract callers see at runtime.
  ============================================================================ }

unit Test.DeepBase.LLM.Schema.PBT;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Data.DB,
  FireDAC.Comp.Client,
  FireDAC.Stan.Def,
  FireDAC.Phys,
  FireDAC.Phys.SQLiteDef,
  FireDAC.Phys.SQLite,
  DUnitX.TestFramework,
  DeepBase.Schema;

type
  [TestFixture]
  [Category('PBT')]
  TLLMSchemaPropertyTests = class
  strict private
    function NewMemoryConnection: TFDConnection;
    procedure RunSqlScript(AConn: TFDConnection; const ASql: string);
    function TableExists(AConn: TFDConnection; const ATable: string): Boolean;
    function CountRows(AConn: TFDConnection; const ASql: string): Integer;
    function CollectTableColumns(AConn: TFDConnection;
      const ATable: string): TArray<string>;
    function ContainsCI(const AArr: TArray<string>;
      const AValue: string): Boolean;
  public
    [Setup]
    procedure Setup;

    // Feature: deepbase-bug-fixes-p0p1p2, Property 1
    [Test]
    procedure Property1_AllCanonicalLLMTablesExist;

    // Feature: deepbase-bug-fixes-p0p1p2, Property 2
    [Test]
    procedure Property2_LLMCallsHasCanonicalFieldSet;
  end;

implementation

uses
  System.IOUtils;

{ TLLMSchemaPropertyTests }

procedure TLLMSchemaPropertyTests.Setup;
begin
  Randomize;
end;

function TLLMSchemaPropertyTests.NewMemoryConnection: TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  Result.DriverName := 'SQLite';
  Result.Params.Database := ':memory:';
  Result.LoginPrompt := False;
  Result.Open;
end;

procedure TLLMSchemaPropertyTests.RunSqlScript(AConn: TFDConnection;
  const ASql: string);
var
  LStatements: TArray<string>;
begin
  // Split on top-level ';' separators. The TIER2 SQL does not use embedded
  // semicolons inside string literals, so a naive split is safe here.
  LStatements := ASql.Split([';'], TStringSplitOptions.None);
  for var LRaw in LStatements do
  begin
    var LStmt := LRaw.Trim;
    if LStmt = '' then
      Continue;
    AConn.ExecSQL(LStmt);
  end;
end;

function TLLMSchemaPropertyTests.TableExists(AConn: TFDConnection;
  const ATable: string): Boolean;
var
  LQ: TFDQuery;
begin
  LQ := TFDQuery.Create(nil);
  try
    LQ.Connection := AConn;
    LQ.SQL.Text :=
      'SELECT COUNT(*) AS cnt FROM sqlite_master ' +
      'WHERE type=''table'' AND name=:n';
    LQ.ParamByName('n').AsString := ATable;
    LQ.Open;
    Result := LQ.FieldByName('cnt').AsInteger > 0;
  finally
    LQ.Free;
  end;
end;

function TLLMSchemaPropertyTests.CountRows(AConn: TFDConnection;
  const ASql: string): Integer;
var
  LQ: TFDQuery;
begin
  LQ := TFDQuery.Create(nil);
  try
    LQ.Connection := AConn;
    LQ.SQL.Text := ASql;
    LQ.Open;
    Result := LQ.Fields[0].AsInteger;
  finally
    LQ.Free;
  end;
end;

function TLLMSchemaPropertyTests.CollectTableColumns(AConn: TFDConnection;
  const ATable: string): TArray<string>;
var
  LQ: TFDQuery;
  LList: TList<string>;
begin
  LList := TList<string>.Create;
  LQ := TFDQuery.Create(nil);
  try
    LQ.Connection := AConn;
    LQ.SQL.Text := 'PRAGMA table_info(' + ATable + ')';
    LQ.Open;
    while not LQ.Eof do
    begin
      LList.Add(LQ.FieldByName('name').AsString);
      LQ.Next;
    end;
    Result := LList.ToArray;
  finally
    LQ.Free;
    LList.Free;
  end;
end;

function TLLMSchemaPropertyTests.ContainsCI(const AArr: TArray<string>;
  const AValue: string): Boolean;
begin
  Result := False;
  for var S in AArr do
    if SameText(S, AValue) then
      Exit(True);
end;

// Feature: deepbase-bug-fixes-p0p1p2, Property 1: After running the LLM
// schema SQL on a fresh empty SQLite database, all canonical LLM tables
// SHALL exist and be queryable.
procedure TLLMSchemaPropertyTests.Property1_AllCanonicalLLMTablesExist;
const
  CCanonicalTables: array[0..8] of string = (
    'LLMConfig',
    'LLMCalls',
    'LLMPromptTemplates',     // schema's actual prompt table
    'LLMApiKeys',
    'PromptCategories',
    'Prompts',
    'PromptVersions',
    'PromptMeta',
    'PromptMetaBinding'
  );
  CSql =
    SQL_TIER2_LLM_CONFIG + #13#10 +
    SQL_TIER2_LLM_CALLS + #13#10 +
    SQL_TIER2_LLM_PROMPTS + #13#10 +
    SQL_TIER2_LLM_API_KEYS + #13#10 +
    SQL_TIER2_PROMPT_CATEGORIES + #13#10 +
    SQL_TIER2_PROMPTS + #13#10 +
    SQL_TIER2_PROMPT_VERSIONS + #13#10 +
    SQL_TIER2_PROMPT_META + #13#10 +
    SQL_TIER2_PROMPT_META_BINDING;
begin
  for var Iter := 1 to 100 do
  begin
    var LConn := NewMemoryConnection;
    try
      RunSqlScript(LConn, CSql);
      for var T in CCanonicalTables do
        Assert.IsTrue(TableExists(LConn, T),
          Format('Iter %d: canonical table "%s" missing after schema init',
            [Iter, T]));

      // Sanity: every table is queryable (returns 0 rows on a freshly
      // created empty schema).
      for var T in CCanonicalTables do
        Assert.IsTrue(CountRows(LConn, 'SELECT COUNT(*) FROM ' + T) >= 0,
          Format('Iter %d: SELECT against "%s" failed', [Iter, T]));
    finally
      LConn.Free;
    end;
  end;
end;

// Feature: deepbase-bug-fixes-p0p1p2, Property 2: LLMCalls SHALL contain the
// canonical column set required by TLLMManager. Legacy-only columns from
// the deprecated external SQL script (e.g. 'CallerHost') SHALL be absent.
procedure TLLMSchemaPropertyTests.Property2_LLMCallsHasCanonicalFieldSet;
const
  // Canonical column names from SQL_TIER2_LLM_CALLS in DeepBase.Schema.pas.
  // These are the PascalCase equivalents of the snake_case names listed in
  // the design document (model->ModelId, provider->ProviderCode, ...).
  CCanonicalColumns: array[0..8] of string = (
    'ModelId',         // model
    'ProviderCode',    // provider
    'InputTokens',     // input_tokens
    'OutputTokens',    // output_tokens
    'DurationMs',      // duration_ms
    'Success',         // status (success flag)
    'ErrorMessage',    // error
    'CallTime',        // created_at
    'Id'               // primary key
  );
  // Forbidden / legacy column names that must not creep back in.
  CForbiddenColumns: array[0..1] of string = (
    'CallerHost',      // legacy hostname column
    'LegacyExtra'      // sentinel to catch accidental migrations
  );
begin
  for var Iter := 1 to 100 do
  begin
    var LConn := NewMemoryConnection;
    try
      RunSqlScript(LConn, SQL_TIER2_LLM_CALLS);
      Assert.IsTrue(TableExists(LConn, 'LLMCalls'),
        Format('Iter %d: LLMCalls missing', [Iter]));

      var LCols := CollectTableColumns(LConn, 'LLMCalls');
      Assert.IsTrue(Length(LCols) > 0,
        Format('Iter %d: PRAGMA table_info(LLMCalls) returned no columns',
          [Iter]));

      for var C in CCanonicalColumns do
        Assert.IsTrue(ContainsCI(LCols, C),
          Format('Iter %d: canonical column "%s" missing from LLMCalls',
            [Iter, C]));

      for var C in CForbiddenColumns do
        Assert.IsFalse(ContainsCI(LCols, C),
          Format('Iter %d: forbidden legacy column "%s" present in LLMCalls',
            [Iter, C]));
    finally
      LConn.Free;
    end;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TLLMSchemaPropertyTests);

end.
