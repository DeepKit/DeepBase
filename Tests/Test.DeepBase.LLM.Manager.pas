{ ============================================================================
  Test.DeepBase.LLM.Manager - Unit Tests for LLM Prompt Manager Types
  
  Test Coverage (pure types/helpers only):
    - TPromptVariable (TypeToStr / StrToType, fields)
    - TMetaPrompt (Category/MergeMode helpers)
    - TPromptCategory (FullPath)
    - TPromptVersion (SuccessRate)
    - TPrompt (GetProductionVersion / HasVersion / GetVersion)
    - TLLMResponse.Init
    - TLLMManager storage factory error path
  ============================================================================ }

unit Test.DeepBase.LLM.Manager;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Variants,
  System.Classes,
  System.Generics.Collections,
  Data.DB,
  DeepBase.LLM,
  DeepBase.LLM.Manager;

type
  [TestFixture]
  TTestPromptVariable = class
  public
    [Test]
    procedure Test_Type_RoundTrip_AllKinds;
    [Test]
    procedure Test_Fields_Assignment;
  end;

  [TestFixture]
  TTestMetaPromptHelpers = class
  public
    [Test]
    procedure Test_Category_RoundTrip_AllKinds;
    [Test]
    procedure Test_MergeMode_RoundTrip_AllKinds;
  end;

  [TestFixture]
  TTestPromptCategory = class
  public
    [Test]
    procedure Test_FullPath_ContainsName;
  end;

  [TestFixture]
  TTestPromptVersion = class
  public
    [Test]
    procedure Test_SuccessRate_NoTests;
    [Test]
    procedure Test_SuccessRate_Partial;
  end;

  [TestFixture]
  TTestPromptHelpers = class
  public
    [Test]
    procedure Test_GetProductionVersion;
    [Test]
    procedure Test_HasVersion_TrueFalse;
    [Test]
    procedure Test_GetVersion_ReturnsCorrect;
  end;

  [TestFixture]
  TTestLLMResponse = class
  public
    [Test]
    procedure Test_Init_SetsDefaults;
  end;

  [TestFixture]
  TTestLLMManagerStorageFactory = class
  public
    [Test]
    procedure Test_CreateWithConnection_WithoutStorageFactory_ShouldFailClearly;
    [Test]
    procedure Test_CreateWithStorageObject_WithoutStorageFactory_ShouldSucceed;
    [Test]
    procedure Test_CreateWithStorageInterface_ShouldSucceed;
  end;

  /// <summary>
  /// Records every Execute/OpenDataSet/ExecuteScalar SQL call. Used by
  /// TTestLLMManagerBatchOps to assert SetProductionVersion issues a single
  /// atomic UPDATE and DeleteVersions collapses to a single DELETE + IN.
  /// </summary>
  TRecordingLLMStorage = class(TInterfacedObject, ILLMStorage)
  private
    FConnected: Boolean;
    FSQLCalls: TList<string>;
    FSeededPrompts: TList<TPair<string, TPrompt>>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure SeedPrompt(const InternalCode: string; const Prompt: TPrompt);

    property SQLCalls: TList<string> read FSQLCalls;

    // ILLMStorage
    function IsConnected: Boolean;
    function TableExists(const TableName: string): Boolean;
    function TableHasColumn(const TableName, ColumnName: string): Boolean;
    function OpenDataSet(const SQL: string;
      const Params: array of TLLMStorageParam): TDataSet;
    function Execute(const SQL: string;
      const Params: array of TLLMStorageParam): Integer;
    function ExecuteScalar(const SQL: string;
      const Params: array of TLLMStorageParam): Variant;
    function IsPostgreSQL: Boolean;
  end;

  /// <summary>
  /// BUG-308 (BIZ-013) — atomicity / batch tests for SetProductionVersion
  /// and DeleteVersions. Uses a recording mock ILLMStorage to capture SQL.
  /// </summary>
  [TestFixture]
  TTestLLMManagerBatchOps = class
  strict private
    FManager: TLLMManager;
    FMock: TRecordingLLMStorage;
  public
    [Setup]    procedure Setup;
    [TearDown] procedure TearDown;
    [Test] procedure Test_SetProductionVersion_SingleAtomicSQL;
    [Test] procedure Test_SetProductionVersion_UsesCaseExpression;
    [Test] procedure Test_DeleteVersions_EmptyArray_NoOp;
    [Test] procedure Test_DeleteVersions_MultipleVersions_InClause;
    [Test] procedure Test_DeleteVersions_SingleVersion_NoInClause;
  end;

implementation

uses
  Datasnap.DBClient,
  FireDAC.Comp.Client,
  DeepBase.Persistence.LLM.FireDAC;

type
  TMockDisconnectedLLMStorage = class(TInterfacedObject, ILLMStorage)
  public
    function IsConnected: Boolean;
    function TableExists(const TableName: string): Boolean;
    function TableHasColumn(const TableName, ColumnName: string): Boolean;
    function OpenDataSet(const SQL: string;
      const Params: array of TLLMStorageParam): TDataSet;
    function Execute(const SQL: string;
      const Params: array of TLLMStorageParam): Integer;
    function ExecuteScalar(const SQL: string;
      const Params: array of TLLMStorageParam): Variant;
    function IsPostgreSQL: Boolean;
  end;

function TMockDisconnectedLLMStorage.IsConnected: Boolean;
begin
  Result := False;
end;

function TMockDisconnectedLLMStorage.TableExists(const TableName: string): Boolean;
begin
  Result := False;
end;

function TMockDisconnectedLLMStorage.TableHasColumn(const TableName,
  ColumnName: string): Boolean;
begin
  Result := False;
end;

function TMockDisconnectedLLMStorage.OpenDataSet(const SQL: string;
  const Params: array of TLLMStorageParam): TDataSet;
begin
  raise EInvalidOp.Create('OpenDataSet should not be called for disconnected storage');
end;

function TMockDisconnectedLLMStorage.Execute(const SQL: string;
  const Params: array of TLLMStorageParam): Integer;
begin
  Result := 0;
end;

function TMockDisconnectedLLMStorage.ExecuteScalar(const SQL: string;
  const Params: array of TLLMStorageParam): Variant;
begin
  Result := 0;
end;

function TMockDisconnectedLLMStorage.IsPostgreSQL: Boolean;
begin
  Result := False;
end;

{ TRecordingLLMStorage — records every Execute SQL for batch/atomicity tests }

constructor TRecordingLLMStorage.Create;
begin
  inherited Create;
  FConnected := True;
  FSQLCalls := TList<string>.Create;
  FSeededPrompts := TList<TPair<string, TPrompt>>.Create;
end;

destructor TRecordingLLMStorage.Destroy;
begin
  FSeededPrompts.Free;
  FSQLCalls.Free;
  inherited;
end;

procedure TRecordingLLMStorage.SeedPrompt(const InternalCode: string;
  const Prompt: TPrompt);
begin
  FSeededPrompts.Add(TPair<string, TPrompt>.Create(InternalCode, Prompt));
end;

function TRecordingLLMStorage.IsConnected: Boolean;
begin
  Result := FConnected;
end;

function TRecordingLLMStorage.TableExists(const TableName: string): Boolean;
begin
  Result := True;
end;

function TRecordingLLMStorage.TableHasColumn(const TableName,
  ColumnName: string): Boolean;
begin
  Result := True;
end;

function TRecordingLLMStorage.OpenDataSet(const SQL: string;
  const Params: array of TLLMStorageParam): TDataSet;
begin
  FSQLCalls.Add(SQL);
  // Initialize's LoadCategories / LoadMetaPrompts / LoadPrompts need a TDataSet,
  // but for our batch-ops tests we never iterate the result — we only care that
  // GetPrompt returns the seeded prompt from the cache, which we bypass by
  // seeding the cache directly via the test accessor. Return an empty dataset
  // to satisfy the caller.
  Result := TClientDataSet.Create(nil);
end;

function TRecordingLLMStorage.Execute(const SQL: string;
  const Params: array of TLLMStorageParam): Integer;
begin
  FSQLCalls.Add(SQL);
  Result := 0;
end;

function TRecordingLLMStorage.ExecuteScalar(const SQL: string;
  const Params: array of TLLMStorageParam): Variant;
begin
  FSQLCalls.Add(SQL);
  Result := 0;
end;

function TRecordingLLMStorage.IsPostgreSQL: Boolean;
begin
  Result := False;
end;

{ TTestLLMManagerBatchOps }

{ TTestPromptVariable }

procedure TTestPromptVariable.Test_Type_RoundTrip_AllKinds;
var
  V: TPromptVariable;
  AllTypes: array[0..6] of TPromptVariableType;
  T: TPromptVariableType;
  S: string;
begin
  AllTypes[0] := pvtString;
  AllTypes[1] := pvtNumber;
  AllTypes[2] := pvtBoolean;
  AllTypes[3] := pvtDate;
  AllTypes[4] := pvtDateTime;
  AllTypes[5] := pvtList;
  AllTypes[6] := pvtJson;

  for T in AllTypes do
  begin
    V.VarType := T;
    S := V.TypeToStr;
    Assert.AreEqual(T, TPromptVariable.StrToType(S));
  end;
end;

procedure TTestPromptVariable.Test_Fields_Assignment;
var
  V: TPromptVariable;
begin
  V.Name := 'user_name';
  V.VarType := pvtString;
  V.DefaultValue := 'guest';
  V.Description := 'User name';
  V.Required := True;

  Assert.AreEqual('user_name', V.Name);
  Assert.AreEqual(pvtString, V.VarType);
  Assert.AreEqual('guest', VarToStr(V.DefaultValue));
  Assert.AreEqual('User name', V.Description);
  Assert.IsTrue(V.Required);
end;

{ TTestMetaPromptHelpers }

procedure TTestMetaPromptHelpers.Test_Category_RoundTrip_AllKinds;
var
  M: TMetaPrompt;
  C: TMetaCategory;
  AllCats: array[0..4] of TMetaCategory;
  S: string;
begin
  AllCats[0] := mcSecurity;
  AllCats[1] := mcFormat;
  AllCats[2] := mcRole;
  AllCats[3] := mcDomain;
  AllCats[4] := mcQuality;

  for C in AllCats do
  begin
    M.Category := C;
    S := M.CategoryToStr;
    Assert.AreEqual(C, TMetaPrompt.StrToCategory(S));
  end;
end;

procedure TTestMetaPromptHelpers.Test_MergeMode_RoundTrip_AllKinds;
var
  M: TMetaPrompt;
  Mode: TMetaMergeMode;
  AllModes: array[0..2] of TMetaMergeMode;
  S: string;
begin
  AllModes[0] := mmPrefix;
  AllModes[1] := mmSuffix;
  AllModes[2] := mmWrap;

  for Mode in AllModes do
  begin
    M.MergeMode := Mode;
    S := M.MergeModeToStr;
    Assert.AreEqual(Mode, TMetaPrompt.StrToMergeMode(S));
  end;
end;

{ TTestPromptCategory }

procedure TTestPromptCategory.Test_FullPath_ContainsName;
var
  Cat: TPromptCategory;
  Path: string;
begin
  Cat.Id := 1;
  Cat.ParentId := 0;
  Cat.Level := 1;
  Cat.Code := '01';
  Cat.Name := 'System Prompt';
  Cat.Description := 'Root category';
  Cat.SortOrder := 10;
  Cat.IsActive := True;

  Path := Cat.FullPath;
  Assert.IsTrue(Path.Contains(Cat.Name));
end;

{ TTestPromptVersion }

procedure TTestPromptVersion.Test_SuccessRate_NoTests;
var
  Ver: TPromptVersion;
begin
  Ver.TestCount := 0;
  Ver.SuccessCount := 0;
  Assert.AreEqual(0.0, Ver.SuccessRate, 0.0001);
end;

procedure TTestPromptVersion.Test_SuccessRate_Partial;
var
  Ver: TPromptVersion;
begin
  Ver.TestCount := 4;
  Ver.SuccessCount := 3;
  Assert.AreEqual(75.0, Ver.SuccessRate, 0.0001);
end;

{ TTestPromptHelpers }

procedure TTestPromptHelpers.Test_GetProductionVersion;
var
  P: TPrompt;
  V1, V2, V3: TPromptVersion;
  VerNum: Integer;
begin
  SetLength(P.Versions, 3);

  V1.VersionNumber := 1;
  V1.IsProduction := False;
  P.Versions[0] := V1;

  V2.VersionNumber := 2;
  V2.IsProduction := True;
  P.Versions[1] := V2;

  V3.VersionNumber := 3;
  V3.IsProduction := False;
  P.Versions[2] := V3;

  VerNum := P.GetProductionVersion;
  Assert.AreEqual(2, VerNum);
end;

procedure TTestPromptHelpers.Test_HasVersion_TrueFalse;
var
  P: TPrompt;
  V1: TPromptVersion;
begin
  SetLength(P.Versions, 1);
  V1.VersionNumber := 5;
  P.Versions[0] := V1;

  Assert.IsTrue(P.HasVersion(5));
  Assert.IsFalse(P.HasVersion(2));
end;

procedure TTestPromptHelpers.Test_GetVersion_ReturnsCorrect;
var
  P: TPrompt;
  V1, V2: TPromptVersion;
  R: TPromptVersion;
begin
  SetLength(P.Versions, 2);
  V1.VersionNumber := 1;
  V1.Content := 'v1';
  P.Versions[0] := V1;

  V2.VersionNumber := 2;
  V2.Content := 'v2';
  P.Versions[1] := V2;

  R := P.GetVersion(2);
  Assert.AreEqual(2, R.VersionNumber);
  Assert.AreEqual('v2', R.Content);
end;

{ TTestLLMResponse }

procedure TTestLLMResponse.Test_Init_SetsDefaults;
var
  R: TLLMResponse;
begin
  // Set non-defaults first
  R.Success := True;
  R.Content := 'x';
  R.InputTokens := 10;
  R.OutputTokens := 5;
  R.TotalTokens := 15;
  R.DurationMs := 123;
  R.ErrorCode := 'ERR';
  R.ErrorMessage := 'msg';
  R.PromptId := 1;
  R.VersionNumber := 1;
  R.ConfigName := 'cfg';
  R.Cost := 1.23;

  R.Init;

  Assert.IsFalse(R.Success);
  Assert.AreEqual('', R.Content);
  Assert.AreEqual(0, R.InputTokens);
  Assert.AreEqual(0, R.OutputTokens);
  Assert.AreEqual(0, R.TotalTokens);
  Assert.AreEqual<Int64>(0, R.DurationMs);
  Assert.AreEqual('', R.ErrorCode);
  Assert.AreEqual('', R.ErrorMessage);
  Assert.AreEqual(0, R.PromptId);
  Assert.AreEqual(0, R.VersionNumber);
  Assert.AreEqual('', R.ConfigName);
  Assert.AreEqual(0.0, R.Cost, 0.0001);
end;

{ TTestLLMManagerStorageFactory }

procedure TTestLLMManagerStorageFactory.Test_CreateWithConnection_WithoutStorageFactory_ShouldFailClearly;
var
  Conn: TFDConnection;
  Manager: TLLMManager;
  RaisedMsg: string;
begin
  TLLMManager.SetStorageFactory(nil);
  try
    Conn := TFDConnection.Create(nil);
    try
      Conn.DriverName := 'SQLite';
      Conn.Params.Database := ':memory:';
      Conn.Connected := True;

      Manager := nil;
      RaisedMsg := '';
      try
        Manager := TLLMManager.Create(Conn);
        Assert.Fail('Expected EInvalidOp when LLM manager storage factory is missing');
      except
        on E: EInvalidOp do
          RaisedMsg := E.Message;
      end;
      Manager.Free;

      Assert.IsTrue(RaisedMsg.Contains('DeepBase.Persistence.LLM.FireDAC'),
        'Error should point to LLM FireDAC adapter registration');
    finally
      Conn.Free;
    end;
  finally
    RegisterLLMStorageFactory;
  end;
end;

procedure TTestLLMManagerStorageFactory.Test_CreateWithStorageObject_WithoutStorageFactory_ShouldSucceed;
var
  StorageObj: TObject;
  Manager: TLLMManager;
begin
  TLLMManager.SetStorageFactory(nil);
  TDeepBaseLLM.SetStorageFactory(nil);
  try
    StorageObj := TMockDisconnectedLLMStorage.Create;
    Manager := nil;
    try
      Manager := TLLMManager.Create(StorageObj);
      Assert.IsNotNull(Manager, 'Manager should be created when connection object implements ILLMStorage');
    finally
      Manager.Free;
    end;
  finally
    RegisterLLMStorageFactory;
  end;
end;

procedure TTestLLMManagerStorageFactory.Test_CreateWithStorageInterface_ShouldSucceed;
var
  Storage: ILLMStorage;
  Manager: TLLMManager;
begin
  TLLMManager.SetStorageFactory(nil);
  TDeepBaseLLM.SetStorageFactory(nil);
  try
    Storage := TMockDisconnectedLLMStorage.Create;
    Manager := nil;
    try
      Manager := TLLMManager.Create(Storage);
      Assert.IsNotNull(Manager, 'Manager should be created when storage interface is injected directly');
    finally
      Manager.Free;
    end;
  finally
    RegisterLLMStorageFactory;
  end;
end;

{ TTestLLMManagerBatchOps }

procedure TTestLLMManagerBatchOps.Setup;
var
  P: TPrompt;
  V1, V2, V3: TPromptVersion;
begin
  FMock := TRecordingLLMStorage.Create;
  FManager := TLLMManager.Create(FMock);

  // Seed the prompt cache with one prompt carrying 3 versions. This bypasses
  // the OpenDataSet-driven cache loading — we're only testing the SQL produced
  // by SetProductionVersion / DeleteVersions, not the cache-load path.
  P.Id := 42;
  P.InternalCode := 'TEST-BATCH';
  P.Name := 'Test Batch Prompt';
  SetLength(P.Versions, 3);

  V1.VersionNumber := 1; V1.IsProduction := True;  P.Versions[0] := V1;
  V2.VersionNumber := 2; V2.IsProduction := False; P.Versions[1] := V2;
  V3.VersionNumber := 3; V3.IsProduction := False; P.Versions[2] := V3;

  FManager.TestSeedPrompt('TEST-BATCH', P);
end;

procedure TTestLLMManagerBatchOps.TearDown;
begin
  FManager.Free;
  FMock := nil; // release the interface-typed reference
end;

procedure TTestLLMManagerBatchOps.Test_SetProductionVersion_SingleAtomicSQL;
var
  ExecuteSQLs: TStringList;
  I, N, C: Integer;
begin
  FMock.SQLCalls.Clear;
  FManager.SetProductionVersion('TEST-BATCH', 3);

  // Only the single atomic UPDATE (and any cache-load SELECTs) should appear —
  // there must NOT be two UPDATE statements (the old non-atomic behavior).
  ExecuteSQLs := TStringList.Create;
  try
    N := FMock.SQLCalls.Count;
    for I := 0 to N - 1 do
      if FMock.SQLCalls[I].StartsWith('UPDATE', True) then
        ExecuteSQLs.Add(FMock.SQLCalls[I]);
    C := ExecuteSQLs.Count;
    Assert.AreEqual(Integer(1), C,
      'SetProductionVersion must issue exactly one UPDATE statement (atomic)');
  finally
    ExecuteSQLs.Free;
  end;
end;

procedure TTestLLMManagerBatchOps.Test_SetProductionVersion_UsesCaseExpression;
var
  Found: Boolean;
  SQL: string;
begin
  FMock.SQLCalls.Clear;
  FManager.SetProductionVersion('TEST-BATCH', 3);

  Found := False;
  for SQL in FMock.SQLCalls do
    if SQL.Contains('CASE', True) and SQL.Contains('WHEN VersionNumber = :VersionNumber') then
    begin
      Found := True;
      Break;
    end;
  Assert.IsTrue(Found,
    'Atomic UPDATE should use a CASE expression keyed on :VersionNumber');
end;

procedure TTestLLMManagerBatchOps.Test_DeleteVersions_EmptyArray_NoOp;
var
  InitialCount, ActualCount: Integer;
begin
  FMock.SQLCalls.Clear;
  InitialCount := FMock.SQLCalls.Count;
  FManager.DeleteVersions('TEST-BATCH', []);
  ActualCount := FMock.SQLCalls.Count;
  Assert.AreEqual(InitialCount, ActualCount,
    'DeleteVersions with an empty array must be a no-op (no SQL, no refresh)');
end;

procedure TTestLLMManagerBatchOps.Test_DeleteVersions_MultipleVersions_InClause;
var
  FoundIn: Boolean;
  SQL: string;
begin
  FMock.SQLCalls.Clear;
  FManager.DeleteVersions('TEST-BATCH', [1, 2]);

  FoundIn := False;
  for SQL in FMock.SQLCalls do
    if SQL.StartsWith('DELETE', True) and SQL.Contains('IN (') then
    begin
      FoundIn := True;
      // Each version number must appear as a named parameter (:V0, :V1, …).
      Assert.IsTrue(SQL.Contains(':V0'), 'IN clause should bind :V0');
      Assert.IsTrue(SQL.Contains(':V1'), 'IN clause should bind :V1');
      Break;
    end;
  Assert.IsTrue(FoundIn,
    'DeleteVersions must issue a single DELETE with an IN clause');
end;

procedure TTestLLMManagerBatchOps.Test_DeleteVersions_SingleVersion_NoInClause;
var
  DeleteCount: Integer;
  SQL: string;
begin
  FMock.SQLCalls.Clear;
  FManager.DeleteVersions('TEST-BATCH', [1]);

  DeleteCount := 0;
  for SQL in FMock.SQLCalls do
    if SQL.StartsWith('DELETE', True) then
      Inc(DeleteCount);
  Assert.AreEqual(1, DeleteCount,
    'DeleteVersions with one element must issue exactly one DELETE');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestPromptVariable);
  TDUnitX.RegisterTestFixture(TTestMetaPromptHelpers);
  TDUnitX.RegisterTestFixture(TTestPromptCategory);
  TDUnitX.RegisterTestFixture(TTestPromptVersion);
  TDUnitX.RegisterTestFixture(TTestPromptHelpers);
  TDUnitX.RegisterTestFixture(TTestLLMResponse);
  TDUnitX.RegisterTestFixture(TTestLLMManagerStorageFactory);
  TDUnitX.RegisterTestFixture(TTestLLMManagerBatchOps);

end.
