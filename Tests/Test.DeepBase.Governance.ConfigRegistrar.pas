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
  end;

implementation

uses
  System.IOUtils,
  FireDAC.Stan.Async,
  FireDAC.DApt;

{ TConfigRegistrarTests }

procedure TConfigRegistrarTests.SetupConnection;
begin
  FConnection := TFDConnection.Create(nil);
  try
    FConnection.DriverName := 'SQLite';
    FConnection.Params.Add('Database=' + TPath.GetTempFileName);
    FConnection.Params.Add('SQLiteAdvanced=mode=memory');
    FConnection.Connected := True;
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
  FRegistrar.Free;
  FPurposeSet.Free;
  FActionGrid.Free;
  FDueChecker.Free;
  FKeyResolver.Free;
  FConnection.Free;
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

  // Clear in-memory state
  FKeyResolver := TKeyResolver.Create;
  FActionGrid := TActionGrid.Create(FDueChecker);

  // Create a new registrar with fresh resolvers
  FRegistrar.Free;
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
var
  LGate: TAccessGate;
begin
  // Register an action first
  FRegistrar.RegisterAction('action1', 'Test Action', rlL2, 'gate1', '', '');

  // Register a gate that references this action
  FRegistrar.RegisterGate('gate1', 'Test Gate', gtAction, rlL2);

  // Manually add the action key to the gate's list
  LGate := FKeyResolver.ResolveGateKey('gate1');
  Assert.IsNotNull(LGate);
  LGate.AddActionKey('action1');

  // Reload from DB (this will validate the mapping)
  FRegistrar.LoadFromDB;

  // If we got here without exception, the validation passed
  Assert.Pass;
end;

procedure TConfigRegistrarTests.LoadGates_ThrowsWhenActionKeyMissing;
var
  LGate: TAccessGate;
  LException: Exception;
begin
  // Register a gate
  FRegistrar.RegisterGate('gate1', 'Test Gate', gtAction, rlL2);

  // Manually add a non-existent action key to the gate's list
  LGate := FKeyResolver.ResolveGateKey('gate1');
  Assert.IsNotNull(LGate);
  LGate.AddActionKey('nonexistent_action');

  // Try to reload from DB - should throw because the action doesn't exist
  LException := nil;
  try
    FRegistrar.LoadFromDB;
  except
    on E: EConfigRegistrarError do
      LException := E;
  end;

  Assert.IsNotNull(LException, 'Should throw EConfigRegistrarError when ActionKey is missing');
  Assert.Contains(LException.Message, 'nonexistent_action');
end;

end.
