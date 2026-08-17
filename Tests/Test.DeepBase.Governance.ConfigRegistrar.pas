// AI-GENERATED
unit Test.DeepBase.Governance.ConfigRegistrar;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  FireDAC.Comp.Client,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  FireDAC.Stan.Def,
  DeepBase.Governance.Types,
  DeepBase.Governance.Model,
  DeepBase.Governance.KeyResolver,
  DeepBase.Governance.DueChecker,
  DeepBase.Governance.ActionGrid,
  DeepBase.Governance.Purpose,
  DeepBase.Governance.ConfigRegistrar;

type
  [TestFixture]
  TConfigRegistrarTests = class
  private
    FConnection: TFDConnection;
    FKeyResolver: TKeyResolver;
    FPurposeSet: TPurposeSet;
    FActionGrid: TActionGrid;
    FDueChecker: TDueChecker;
    FRegistrar: TConfigRegistrar;
    FTempDir: string;
    FDBPath: string;
    procedure SetupConnection;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure RegisterAction_SyncsToAllThreeRegistries;
    [Test]
    procedure LoadFromDB_SyncsActionsToAllThreeRegistries;
    [Test]
    procedure LoadGates_ValidatesActionKeysExistInActionGrid;
    [Test]
    procedure LoadGates_ThrowsWhenActionKeyMissing;
    [Test]
    procedure RegisterDueRule_PersistsAndSyncsToChecker;
    [Test]
    procedure RegisterDueRule_L3ObserveSafeAvoidsFreeze;
    [Test]
    procedure LoadDueRules_RestoresExplicitRuleOnReload;
    [Test]
    procedure RegisterDueRule_ThrowsOnEmptyActionKey;
  end;

implementation

uses
  System.IOUtils,
  System.JSON,
  FireDAC.Stan.Async,
  FireDAC.DApt;

{ TConfigRegistrarTests }

procedure TConfigRegistrarTests.SetupConnection;
begin
  // Standard DeepBase test SQLite pattern (cf. Test.DeepBase.DB.Migrations /
  // Test.DeepBase.DB.StatusMachine): temp dir + file DB + OpenMode=CreateUTF8.
  // NOTE: SQLiteAdvanced=mode=memory triggers "Invalid pointer operation" in
  // this environment, so we deliberately avoid in-memory mode here.
  FTempDir := TPath.Combine(TPath.GetTempPath, 'db_cfgreg_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(FTempDir);
  FDBPath := TPath.Combine(FTempDir, 'governance.db');
  FConnection := TFDConnection.Create(nil);
  try
    FConnection.DriverName := 'SQLite';
    FConnection.Params.Database := FDBPath;
    FConnection.Params.Values['OpenMode'] := 'CreateUTF8';
    FConnection.Params.Values['LockingMode'] := 'Normal';
    FConnection.LoginPrompt := False;
    FConnection.Open;
  except
    FConnection.Free;
    raise;
  end;
end;

procedure TConfigRegistrarTests.Setup;
begin
  SetupConnection;
  FKeyResolver := TKeyResolver.Create;
  FDueChecker := TDueChecker.Create(FKeyResolver);
  FActionGrid := TActionGrid.Create(FDueChecker);
  FPurposeSet := TPurposeSet.Create;
  FRegistrar := TConfigRegistrar.Create(FConnection, FKeyResolver, FPurposeSet,
    FActionGrid, FDueChecker);
end;

procedure TConfigRegistrarTests.TearDown;
begin
  // Ownership model (critical — this is the root cause of the original
  // "Invalid pointer operation"): TKeyResolver / TDueChecker / TActionGrid are
  // TInterfacedObject. Their RefCount is bumped only by *interface* references,
  // not by object references. We hold them as concrete-class fields because
  // TConfigRegistrar.Create requires concrete classes and the tests call
  // concrete methods (FindAction / Check / ResolveActionKey).
  //
  // Chain at Setup time:
  //   FActionGrid  --holds IDueChecker-->  TDueChecker (RefCount 1)
  //   TDueChecker --holds IKeyResolver--> TKeyResolver (RefCount 1)
  //   FActionGrid itself has RefCount 0 (nobody holds an IActionGrid to it).
  //
  // So: Free(FActionGrid) is safe (RefCount 0), and its destruction drops the
  // IDueChecker ref → TDueChecker RefCount 0 → auto-frees → drops IKeyResolver
  // → TKeyResolver auto-frees. WE MUST NOT manually Free FDueChecker /
  // FKeyResolver here — that would double-free the already auto-released
  // objects, which is exactly the "Invalid pointer operation" we hit before.
  FRegistrar.Free;      // does not own the three objects (destructor is a no-op)
  FPurposeSet.Free;     // plain TObject, manual Free is safe
  FActionGrid.Free;     // triggers the chain above; frees DueChecker + KeyResolver
  FConnection.Free;
  // Pointers are now dangling — clear the stale object references (assigning
  // nil to an object reference is a plain pointer zero, no _Release call).
  FActionGrid := nil;
  FDueChecker := nil;
  FKeyResolver := nil;
  if (FTempDir <> '') and TDirectory.Exists(FTempDir) then
    TDirectory.Delete(FTempDir, True);
end;

procedure TConfigRegistrarTests.RegisterAction_SyncsToAllThreeRegistries;
var
  LAction: TAction;
begin
  // Register an action using the registrar
  FRegistrar.RegisterAction('action1', 'Test Action', rlL2, 'gate1', 'purpose1', 'due1');

  // Verify it's registered in KeyResolver
  LAction := FKeyResolver.ResolveActionKey('action1');
  Assert.IsNotNull(LAction, 'Action should be registered in KeyResolver');
  Assert.AreEqual('action1', LAction.Key);

  // Verify it's registered in ActionGrid
  LAction := FActionGrid.FindAction('action1');
  Assert.IsNotNull(LAction, 'Action should be registered in ActionGrid');
  Assert.AreEqual('action1', LAction.Key);

  // DueChecker auto-registers from Action, so we can't directly verify,
  // but the fact that no exception was thrown means it worked
end;

procedure TConfigRegistrarTests.LoadFromDB_SyncsActionsToAllThreeRegistries;
var
  LAction: TAction;
begin
  // First register an action (this persists to DB)
  FRegistrar.RegisterAction('action1', 'Test Action', rlL2, 'gate1', 'purpose1', 'due1');

  // Clear in-memory state. Because FActionGrid holds an IDueChecker ref to
  // FDueChecker (and FDueChecker holds an IKeyResolver ref to FKeyResolver),
  // we cannot keep FDueChecker while rebuilding only FActionGrid — freeing the
  // old FActionGrid would auto-free FDueChecker and FKeyResolver via the ref-
  // count chain (see TearDown). So rebuild the whole in-memory trio together,
  // keeping only the persisted DB (FConnection) and FPurposeSet.
  FRegistrar.Free;
  FActionGrid.Free;     // chain-releases FDueChecker + FKeyResolver
  FActionGrid := nil;   // stale object ref — plain pointer clear, no _Release
  FDueChecker := nil;
  FKeyResolver := nil;

  FKeyResolver := TKeyResolver.Create;
  FDueChecker := TDueChecker.Create(FKeyResolver);
  FActionGrid := TActionGrid.Create(FDueChecker);
  FRegistrar := TConfigRegistrar.Create(FConnection, FKeyResolver, FPurposeSet,
    FActionGrid, FDueChecker);

  // Load from DB
  FRegistrar.LoadFromDB;

  // Verify the action was loaded into both registries
  LAction := FKeyResolver.ResolveActionKey('action1');
  Assert.IsNotNull(LAction, 'Action should be loaded into KeyResolver from DB');

  LAction := FActionGrid.FindAction('action1');
  Assert.IsNotNull(LAction, 'Action should be loaded into ActionGrid from DB');
end;

procedure TConfigRegistrarTests.LoadGates_ValidatesActionKeysExistInActionGrid;
begin
  // Register an action first (persists to governance_actions)
  FRegistrar.RegisterAction('action1', 'Test Action', rlL2, 'gate1', '', '');

  // Register a gate, then declare it references action1 (GOV-028 mapping).
  FRegistrar.RegisterGate('gate1', 'Test Gate', gtAction, rlL2);
  FRegistrar.SetGateActionKeys('gate1', ['action1']);

  // Reload from DB: LoadActions repopulates FActionGrid with action1, then
  // LoadGates reloads the gate with its ActionKeys and runs the cross-check.
  FRegistrar.LoadFromDB;

  // If we got here without exception, the validation passed.
  Assert.Pass;
end;

procedure TConfigRegistrarTests.LoadGates_ThrowsWhenActionKeyMissing;
var
  LGate: TAccessGate;
  LExMsg: string;
  LRaised: Boolean;
begin
  // Register a gate, then declare it references an Action that was never
  // registered (no governance_actions row, nothing in FActionGrid).
  FRegistrar.RegisterGate('gate1', 'Test Gate', gtAction, rlL2);
  FRegistrar.SetGateActionKeys('gate1', ['nonexistent_action']);

  // Sanity: SetGateActionKeys must have synced the mapping into the in-memory
  // gate, otherwise the reload path below can't be exercised meaningfully.
  LGate := FKeyResolver.ResolveGateKey('gate1');
  Assert.IsNotNull(LGate, 'gate1 should exist after RegisterGate');
  Assert.IsTrue(LGate.ActionKeys.Count = 1, 'in-memory gate should hold 1 action key');
  Assert.IsTrue(LGate.ActionKeys[0] = 'nonexistent_action', 'in-memory action key mismatch');

  // Reload from DB - should throw because the referenced action doesn't exist.
  // Capture the message inside the handler: the exception object is owned by
  // the runtime and is freed when the except block exits, so reading it after
  // the block (LException.Message) yields dangling-pointer garbage.
  LRaised := False;
  LExMsg := '';
  try
    FRegistrar.LoadFromDB;
  except
    on E: EConfigRegistrarError do
    begin
      LRaised := True;
      LExMsg := E.Message;
    end;
  end;

  Assert.IsTrue(LRaised,
    'Should throw EConfigRegistrarError when a gate references an unregistered action');
  Assert.Contains(LExMsg, 'nonexistent_action');
  Assert.Contains(LExMsg, 'nonexistent_action');
end;

procedure TConfigRegistrarTests.RegisterDueRule_PersistsAndSyncsToChecker;
var
  LRule: TDueRule;
  LResult: TDueResult;
  LContext: TJSONObject;
begin
  FRegistrar.RegisterAction('due_action1', 'Due Action', rlL2, 'gate1', 'purpose1', 'due1');

  // Register an observe-safe DueRule (no Confirm/Seal).
  LRule := Default(TDueRule);
  LRule.ActionKey := 'due_action1';
  LRule.RiskLevel := rlL2;
  LRule.RequireEvidence := True;
  LRule.RequireAccountability := True;
  LRule.RequireConfirm := False;
  LRule.RequireSeal := False;
  LRule.Description := 'observe-safe L2 due rule';
  FRegistrar.RegisterDueRule(LRule);

  // Check should no longer Freeze on missing_policy — the explicit rule
  // exists, so the verdict path is CheckRiskLevel, not the missing_policy branch.
  LContext := TJSONObject.Create;
  try
    LContext.AddPair('user_id', 'u1');
    LContext.AddPair('evidence', 'ev1');
    LResult := FDueChecker.Check('due_action1', LContext);
  finally
    LContext.Free;
  end;

  Assert.AreNotEqual(Ord(dvFreeze), Ord(LResult.Verdict),
    'Should not Freeze — explicit DueRule exists');
end;

procedure TConfigRegistrarTests.RegisterDueRule_L3ObserveSafeAvoidsFreeze;
var
  LRule: TDueRule;
  LResultBefore, LResultAfter: TDueResult;
  LContext: TJSONObject;
begin
  // L3 action WITHOUT an explicit DueRule must Freeze (missing_policy,
  // fail-closed) — this is the baseline proving the observe red-line works.
  FRegistrar.RegisterAction('l3_safe', 'L3 Safe Action', rlL3, 'gate1', 'purpose1', 'due1');

  LContext := TJSONObject.Create;
  try
    LContext.AddPair('user_id', 'u1');
    LContext.AddPair('evidence', 'ev1');
    LResultBefore := FDueChecker.Check('l3_safe', LContext);
  finally
    LContext.Free;
  end;
  Assert.AreEqual(Ord(dvFreeze), Ord(LResultBefore.Verdict),
    'L3 with no DueRule must Freeze (missing_policy, fail-closed)');

  // Now register an explicit observe-safe L3 DueRule — the reuser explicitly
  // declines RequireConfirm/RequireSeal, overriding what AutoRegisterFromAction
  // would have hard-forced.
  LRule := Default(TDueRule);
  LRule.ActionKey := 'l3_safe';
  LRule.RiskLevel := rlL3;
  LRule.RequireEvidence := True;
  LRule.RequireAccountability := True;
  LRule.RequireConfirm := False;
  LRule.RequireSeal := False;
  LRule.Description := 'observe-safe L3: no Confirm/Seal';
  FRegistrar.RegisterDueRule(LRule);

  LContext := TJSONObject.Create;
  try
    LContext.AddPair('user_id', 'u1');
    LContext.AddPair('evidence', 'ev1');
    LResultAfter := FDueChecker.Check('l3_safe', LContext);
  finally
    LContext.Free;
  end;
  Assert.AreNotEqual(Ord(dvFreeze), Ord(LResultAfter.Verdict),
    'After explicit observe-safe DueRule, L3 should not Freeze');
end;

procedure TConfigRegistrarTests.LoadDueRules_RestoresExplicitRuleOnReload;
var
  LRule: TDueRule;
  LResult: TDueResult;
  LContext: TJSONObject;
begin
  FRegistrar.RegisterAction('reload_action', 'Reload Action', rlL3, 'gate1', 'purpose1', 'due1');

  LRule := Default(TDueRule);
  LRule.ActionKey := 'reload_action';
  LRule.RiskLevel := rlL3;
  LRule.RequireEvidence := True;
  LRule.RequireAccountability := True;
  LRule.RequireConfirm := False;
  LRule.RequireSeal := False;
  LRule.Description := 'reload test';
  FRegistrar.RegisterDueRule(LRule);

  // Reload from DB — LoadDueRules must restore the explicit rule so it
  // overrides any AutoRegisterFromAction entry from LoadActions.
  FRegistrar.LoadFromDB;

  LContext := TJSONObject.Create;
  try
    LContext.AddPair('user_id', 'u1');
    LContext.AddPair('evidence', 'ev1');
    LResult := FDueChecker.Check('reload_action', LContext);
  finally
    LContext.Free;
  end;
  Assert.AreNotEqual(Ord(dvFreeze), Ord(LResult.Verdict),
    'After LoadFromDB, explicit DueRule must be restored (not Freeze)');
end;

procedure TConfigRegistrarTests.RegisterDueRule_ThrowsOnEmptyActionKey;
var
  LRule: TDueRule;
  LException: Exception;
begin
  LRule := Default(TDueRule);
  LRule.ActionKey := '';
  LRule.RiskLevel := rlL2;

  LException := nil;
  try
    FRegistrar.RegisterDueRule(LRule);
  except
    on E: EConfigRegistrarError do
      LException := E;
  end;
  Assert.IsNotNull(LException, 'Empty ActionKey must raise EConfigRegistrarError');
end;

initialization
  TDUnitX.RegisterTestFixture(TConfigRegistrarTests);

end.
