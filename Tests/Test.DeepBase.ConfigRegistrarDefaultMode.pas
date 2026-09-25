{ ============================================================================
  Test.DeepBase.ConfigRegistrarDefaultMode - A2-14 regression

  DATA2-023 pinned "default to enforce for safety" but the code persisted
  MODE_OBSERVE on every default/tampered path (fail-open + lying comment).
  A2-14: uninitialized default and tamper-reset must both yield ENFORCE;
  observe remains reachable only via an explicit SetMode.
  ============================================================================ }

unit Test.DeepBase.ConfigRegistrarDefaultMode;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  FireDAC.Comp.Client,
  DeepBase.Governance.Types,
  DeepBase.Governance.Model,
  DeepBase.Governance.KeyResolver,
  DeepBase.Governance.DueChecker,
  DeepBase.Governance.ActionGrid,
  DeepBase.Governance.Purpose,
  DeepBase.Governance.ConfigRegistrar,
  DeepBase.KeyManager;

type
  [TestFixture]
  TTestConfigRegistrarDefaultModeA214 = class
  private
    FConnection: TFDConnection;
    FKeyResolver: TKeyResolver;
    FPurposeSet: TPurposeSet;
    FActionGrid: TActionGrid;
    FDueChecker: TDueChecker;
    FRegistrar: TConfigRegistrar;
    FKM: TKeyManager;
    FKMPath: string;
    FTempDir: string;
    function ReadRawConfig(const AKey: string): string;
    procedure WriteRawConfig(const AKey, AValue: string);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_FreshStore_DefaultsToEnforce;

    [Test]
    procedure Test_TamperedMode_ResetsToEnforce;

    [Test]
    procedure Test_ModeRowWithoutSignature_Enforce;

    [Test]
    procedure Test_ExplicitObserve_SurvivesGetMode;
  end;

implementation

uses
  System.IOUtils,
  Data.DB,
  FireDAC.Stan.Def,
  FireDAC.Stan.Async,
  FireDAC.DApt,
  FireDAC.Phys,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef;

const
  MODE_KEY = 'mode';
  MODE_SIG_KEY = 'mode_sig';

{ TTestConfigRegistrarDefaultModeA214 }

procedure TTestConfigRegistrarDefaultModeA214.Setup;
begin
  // Standard DeepBase test SQLite pattern (cf. Test.DeepBase.Governance.
  // ConfigRegistrar): temp dir + file DB + CreateUTF8.
  FTempDir := TPath.Combine(TPath.GetTempPath, 'db_a214_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(FTempDir);
  FConnection := TFDConnection.Create(nil);
  FConnection.DriverName := 'SQLite';
  FConnection.Params.Database := TPath.Combine(FTempDir, 'governance.db');
  FConnection.Params.Values['OpenMode'] := 'CreateUTF8';
  FConnection.Params.Values['LockingMode'] := 'Normal';
  FConnection.LoginPrompt := False;
  FConnection.Open;

  // Mode HMAC is computed against the GLOBAL signing key; provide a
  // throwaway key store via the public SetInstance DI hook and restore
  // nil on teardown (SetInstance owns/frees the instance).
  FKMPath := TPath.Combine(FTempDir, 'a214_keys.json');
  FKM := TKeyManager.Create(FKMPath);
  FKM.Initialize('a214-test-master');
  TKeyManager.SetInstance(FKM);
  FKM := nil; // ownership now with the singleton

  FKeyResolver := TKeyResolver.Create;
  FDueChecker := TDueChecker.Create(FKeyResolver);
  FActionGrid := TActionGrid.Create(FDueChecker);
  FPurposeSet := TPurposeSet.Create;
  FRegistrar := TConfigRegistrar.Create(FConnection, FKeyResolver,
    FPurposeSet, FActionGrid, FDueChecker);
end;

procedure TTestConfigRegistrarDefaultModeA214.TearDown;
begin
  FRegistrar.Free;
  FPurposeSet.Free;
  FActionGrid.Free; // chain-releases DueChecker + KeyResolver (see harness notes)
  FConnection.Free;
  TKeyManager.SetInstance(nil);
  if (FTempDir <> '') and TDirectory.Exists(FTempDir) then
    TDirectory.Delete(FTempDir, True);
end;

function TTestConfigRegistrarDefaultModeA214.ReadRawConfig(
  const AKey: string): string;
var
  LQuery: TFDQuery;
begin
  Result := '';
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := 'SELECT value FROM governance_config WHERE key = :key';
    LQuery.ParamByName('key').AsString := AKey;
    LQuery.Open;
    if not LQuery.Eof then
      Result := LQuery.FieldByName('value').AsString;
  finally
    FreeAndNil(LQuery);
  end;
end;

procedure TTestConfigRegistrarDefaultModeA214.WriteRawConfig(
  const AKey, AValue: string);
var
  LQuery: TFDQuery;
begin
  // Direct DB-level write bypassing the signed API -- the tamper face A2-14
  // must fail closed on.
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text :=
      'INSERT OR REPLACE INTO governance_config (key, value) VALUES (:key, :value)';
    LQuery.ParamByName('key').AsString := AKey;
    LQuery.ParamByName('value').AsString := AValue;
    LQuery.ExecSQL;
  finally
    FreeAndNil(LQuery);
  end;
end;

procedure TTestConfigRegistrarDefaultModeA214.Test_FreshStore_DefaultsToEnforce;
begin
  Assert.AreEqual('enforce', FRegistrar.GetMode,
    'fresh config store must default to enforce (A2-14 fail-closed)');
  Assert.AreEqual('enforce', ReadRawConfig(MODE_KEY),
    'EnsureDefaultMode must persist enforce');
  Assert.AreNotEqual('', ReadRawConfig(MODE_SIG_KEY),
    'default mode must carry an HMAC signature');
end;

procedure TTestConfigRegistrarDefaultModeA214.Test_TamperedMode_ResetsToEnforce;
begin
  // Flip the persisted value under a stale signature via raw DB write.
  FRegistrar.SetMode('observe');
  Assert.AreEqual('observe', FRegistrar.GetMode);
  WriteRawConfig(MODE_KEY, 'observe_x'); // signature no longer matches

  Assert.AreEqual('enforce', FRegistrar.GetMode,
    'tampered mode must reset to enforce, never observe (A2-14)');
  Assert.AreEqual('enforce', ReadRawConfig(MODE_KEY),
    'tamper reset must re-sign and persist the safe default');
end;

procedure TTestConfigRegistrarDefaultModeA214.Test_ModeRowWithoutSignature_Enforce;
begin
  WriteRawConfig(MODE_KEY, 'observe');
  // no mode_sig row at all -> unverifiable -> fail closed
  Assert.AreEqual('enforce', FRegistrar.GetMode,
    'mode without signature is unverifiable and must yield enforce');
end;

procedure TTestConfigRegistrarDefaultModeA214.Test_ExplicitObserve_SurvivesGetMode;
begin
  FRegistrar.SetMode('observe');
  Assert.AreEqual('observe', FRegistrar.GetMode,
    'explicitly set observe with valid signature must round-trip');
  FRegistrar.SetMode('enforce');
  Assert.AreEqual('enforce', FRegistrar.GetMode);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestConfigRegistrarDefaultModeA214);

end.
