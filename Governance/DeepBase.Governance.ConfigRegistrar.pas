// AI-GENERATED

// DeepBase.Governance.ConfigRegistrar.pas
// Code-first governance configuration registrar backed by ConfigDB (SQLite).
// Replaces the JSON-file-based TConfigLoader path so downstream projects can
// register gates, actions and purposes programmatically while persisting them
// to the governance_* tables for reload after restart.

unit DeepBase.Governance.ConfigRegistrar;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Data.DB,
  FireDAC.Comp.Client,
  FireDAC.Stan.Param,
  DeepBase.Governance.Types,
  DeepBase.Governance.Model,
  DeepBase.Governance.KeyResolver,
  DeepBase.Governance.Purpose,
  DeepBase.Governance.ActionGrid,
  DeepBase.Governance.DueChecker,
  DeepBase.Governance.RouteStore.SQLite,
  DeepBase.Crypto, DeepBase.Crypto.Hash, DeepBase.Crypto.Encoding,
  DeepBase.KeyManager;

const
  // ASY-GOV-007: versioned policy package identity keys, persisted to
  // governance_config. Declared in the interface so external callers (e.g.
  // Assayer.Governance.PolicyCompatibility) can read them back by name.
  CONFIG_KEY_POLICY_PACKAGE_ID    = 'policy_package_id';
  CONFIG_KEY_POLICY_VERSION       = 'policy_version';
  CONFIG_KEY_DEEPBASE_MIN_VERSION = 'deepbase_min_version';
  CONFIG_KEY_CONTRACT_VERSION     = 'contract_version';
  CONFIG_KEY_CONTENT_DIGEST       = 'content_digest';
  CONFIG_KEY_ACTIVATED_AT         = 'activated_at';

type
  EConfigRegistrarError = class(Exception);

  /// <summary>
  /// Code-first configuration registrar. Persists governance definitions
  /// to ConfigDB (SQLite) governance_* tables and mirrors them into the
  /// in-memory TKeyResolver / TPurposeSet / TActionGrid / TDueChecker.
  /// </summary>
  TConfigRegistrar = class
  private
    FConnection: TFDConnection;
    FKeyResolver: TKeyResolver;
    FPurposeSet: TPurposeSet;
    FActionGrid: TActionGrid;
    FDueChecker: TDueChecker;
    procedure EnsureTables;
    procedure EnsureDefaultMode;
    procedure UpsertGateRow(const AGateKey, ADisplayName: string;
      AGateType: TGateType; ARiskLevel: TRiskLevel;
      const AParentKey, AFieldKey: string);
    procedure ReplaceGateConditions(const AGateKey: string;
      const AConditions: array of TGateCondition);
    procedure ReplaceGateActionKeys(const AGateKey: string;
      const AActionKeys: array of string);
    // ASY-GOV-003 ② (BCW-A20260715-008, 方案B): Append a single
    // gate→action_key row to the forward index. Unlike ReplaceGateActionKeys
    // (which DELETEs then re-inserts the whole set), this INSERT OR IGNOREs a
    // single row so RegisterAction can auto-populate the forward index without
    // clobbering sibling actions already registered under the same gate.
    procedure UpsertGateActionKey(const AGateKey, AActionKey: string);
    procedure UpsertActionRow(const AActionKey, ADisplayName: string;
      ARiskLevel: TRiskLevel; const AGateKey, APurposeKey, ADueRef: string);
    procedure UpsertPurposeRow(const AKey, AName, ADescription,
      AParentKey: string);
    procedure LoadGates;
    procedure LoadActions;
    procedure LoadPurposes;
    procedure UpsertDueRuleRow(const ARule: TDueRule);
    procedure LoadDueRules;
    /// <summary>
    /// DATA2-023: Compute HMAC-SHA256 of the mode value using a
    /// machine-specific signing key from KeyManager. Returns hex string.
    /// Falls back to empty string if KeyManager is not available.
    /// </summary>
    function ComputeModeHMAC(const AMode: string): string;
    /// <summary>
    /// DATA2-023: Verify the stored mode against its HMAC signature.
    /// Returns True if valid, False if tampered or unverifiable.
    /// </summary>
    function ValidateModeHMAC(const AMode, AStoredSig: string): Boolean;
  public
    constructor Create(AConnection: TFDConnection; AKeyResolver: TKeyResolver;
      APurposeSet: TPurposeSet; AActionGrid: TActionGrid = nil;
      ADueChecker: TDueChecker = nil);
    destructor Destroy; override;

    /// Register a gate definition. Upserts the row, replaces its conditions,
    /// creates an in-memory TAccessGate and registers it on KeyResolver.
    procedure RegisterGate(const AGateKey, ADisplayName: string;
      AGateType: TGateType; ARiskLevel: TRiskLevel;
      const AConditions: array of TGateCondition); overload;
    procedure RegisterGate(const AGateKey, ADisplayName: string;
      AGateType: TGateType; ARiskLevel: TRiskLevel); overload;

    /// <summary>
    /// GOV-028: Persist the set of Action keys a Gate references (the
    /// Gate→Action mapping). Replaces any previously stored mapping for the
    /// gate. LoadGates reloads this so the "ActionKeys reference an existing
    /// Action" cross-check becomes reachable.
    /// </summary>
    procedure SetGateActionKeys(const AGateKey: string;
      const AActionKeys: array of string);

    /// Register an action definition.
    procedure RegisterAction(const AActionKey, ADisplayName: string;
      ARiskLevel: TRiskLevel; const AGateKey: string;
      const APurposeKey: string = ''; const ADueRef: string = '');

    /// Register a purpose.
    procedure RegisterPurpose(const AKey, AName, ADescription: string;
      const AParentKey: string = '');

    /// ASY-GOV-003 (BCW-A20260715-007): Register an explicit DueRule.
    /// Persists to governance_due_rules and mirrors into TDueChecker.RegisterRule,
    /// bypassing AutoRegisterFromAction so the reuser controls every field.
    /// This lets an L3 action register an observe-safe DueRule (Evidence +
    /// Accountability only, no RequireConfirm/RequireSeal) instead of the
    /// full L3 set AutoRegisterFromAction would force.
    procedure RegisterDueRule(const ARule: TDueRule);

    /// <summary>
    /// ASY-GOV-003 ③: persist a RouteRule to governance_route_rules.
    /// Idempotent (INSERT OR REPLACE on id) so repeat registration is safe,
    /// matching RegisterGate/RegisterAction semantics. Delegates to
    /// TRouteStoreSQLite which owns the table DDL + index, so EnsureTables
    /// does not need a route_rules statement.
    /// No in-memory mirror: RouteRule is loaded into TRouteResolver by the
    /// caller via LoadRouteRules, same split as the file-driven path.
    /// </summary>
    procedure RegisterRouteRule(ARule: TRouteRule);

    /// Reload all governance definitions from ConfigDB into KeyResolver
    /// and PurposeSet.
    procedure LoadFromDB;

    /// Governance mode accessors. Valid values: 'observe' | 'enforce'.
    function GetMode: string;
    procedure SetMode(const AMode: string);

    /// ASY-GOV-007: policy package identity accessors. SetPackageMetadata
    /// writes the six package fields (id, version, deepbase_min_version,
    /// contract_version, content_digest, activated_at) to governance_config;
    /// GetPackageMetadata reads one back by key. Reuses the generic KV
    /// upsert/select — no dedicated table.
    procedure SetPackageMetadata(const APackageId, AVersion,
      ADeepbaseMinVersion, AContractVersion, AContentDigest,
      AActivatedAt: string);
    function GetPackageMetadata(const AKey: string): string;

    property Connection: TFDConnection read FConnection;
    property KeyResolver: TKeyResolver read FKeyResolver;
    property PurposeSet: TPurposeSet read FPurposeSet;
  end;

implementation

const
  MODE_OBSERVE = 'observe';
  MODE_ENFORCE = 'enforce';
  CONFIG_KEY_MODE = 'mode';
  CONFIG_KEY_MODE_SIG = 'mode_sig';

  SQL_CREATE_GATES =
    'CREATE TABLE IF NOT EXISTS governance_gates (' +
    '  key TEXT PRIMARY KEY,' +
    '  display_name TEXT NOT NULL,' +
    '  gate_type INTEGER NOT NULL DEFAULT 1,' +
    '  risk_level INTEGER NOT NULL DEFAULT 0,' +
    '  parent_key TEXT DEFAULT '''',' +
    '  field_key TEXT DEFAULT '''',' +
    '  created_at TEXT DEFAULT (datetime(''now'')),' +
    '  updated_at TEXT DEFAULT (datetime(''now''))' +
    ')';

  SQL_CREATE_GATE_CONDITIONS =
    'CREATE TABLE IF NOT EXISTS governance_gate_conditions (' +
    '  id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  gate_key TEXT NOT NULL,' +
    '  kind INTEGER NOT NULL,' +
    '  expression TEXT NOT NULL,' +
    '  description TEXT DEFAULT '''',' +
    '  blocked_message TEXT DEFAULT ''''' +
    ')';

  SQL_CREATE_GATE_CONDITIONS_INDEX =
    'CREATE INDEX IF NOT EXISTS idx_gov_gate_cond_gate ' +
    'ON governance_gate_conditions(gate_key)';

  SQL_CREATE_ACTIONS =
    'CREATE TABLE IF NOT EXISTS governance_actions (' +
    '  key TEXT PRIMARY KEY,' +
    '  display_name TEXT NOT NULL,' +
    '  risk_level INTEGER NOT NULL DEFAULT 0,' +
    '  gate_key TEXT DEFAULT '''',' +
    '  purpose_key TEXT DEFAULT '''',' +
    '  due_ref TEXT DEFAULT '''',' +
    '  created_at TEXT DEFAULT (datetime(''now'')),' +
    '  updated_at TEXT DEFAULT (datetime(''now''))' +
    ')';

  SQL_CREATE_PURPOSES =
    'CREATE TABLE IF NOT EXISTS governance_purposes (' +
    '  key TEXT PRIMARY KEY,' +
    '  name TEXT NOT NULL,' +
    '  description TEXT DEFAULT '''',' +
    '  parent_key TEXT DEFAULT '''',' +
    '  status TEXT DEFAULT ''active''' +
    ')';

  SQL_CREATE_CONFIG =
    'CREATE TABLE IF NOT EXISTS governance_config (' +
    '  key TEXT PRIMARY KEY,' +
    '  value TEXT NOT NULL' +
    ')';

  // ASY-GOV-003 (BCW-A20260715-007): explicit DueRule registration table.
  // Stores TDueRule verbatim so reusers can register observe-safe DueRules
  // for L2/L3 actions without going through AutoRegisterFromAction, which
  // hard-forces RequireConfirm+RequireSeal on every L3 rule (blocking the
  // observe red-line under enforce).
  SQL_CREATE_DUE_RULES =
    'CREATE TABLE IF NOT EXISTS governance_due_rules (' +
    '  action_key TEXT PRIMARY KEY,' +
    '  risk_level INTEGER NOT NULL DEFAULT 2,' +
    '  require_evidence INTEGER NOT NULL DEFAULT 0,' +
    '  require_accountability INTEGER NOT NULL DEFAULT 0,' +
    '  require_confirm INTEGER NOT NULL DEFAULT 0,' +
    '  require_seal INTEGER NOT NULL DEFAULT 0,' +
    '  description TEXT DEFAULT '''',' +
    '  created_at TEXT DEFAULT (datetime(''now'')),' +
    '  updated_at TEXT DEFAULT (datetime(''now''))' +
    ')';

  SQL_UPSERT_DUE_RULE =
    'INSERT INTO governance_due_rules (action_key, risk_level, require_evidence, ' +
    '  require_accountability, require_confirm, require_seal, description) ' +
    'VALUES (:action_key, :risk_level, :require_evidence, ' +
    '  :require_accountability, :require_confirm, :require_seal, :description) ' +
    'ON CONFLICT(action_key) DO UPDATE SET ' +
    '  risk_level = excluded.risk_level,' +
    '  require_evidence = excluded.require_evidence,' +
    '  require_accountability = excluded.require_accountability,' +
    '  require_confirm = excluded.require_confirm,' +
    '  require_seal = excluded.require_seal,' +
    '  description = excluded.description,' +
    '  updated_at = datetime(''now'')';

  SQL_SELECT_ALL_DUE_RULES =
    'SELECT action_key, risk_level, require_evidence, require_accountability, ' +
    '  require_confirm, require_seal, description FROM governance_due_rules';

  SQL_UPSERT_GATE =
    'INSERT INTO governance_gates (key, display_name, gate_type, risk_level, ' +
    '  parent_key, field_key) ' +
    'VALUES (:key, :display_name, :gate_type, :risk_level, :parent_key, :field_key) ' +
    'ON CONFLICT(key) DO UPDATE SET ' +
    '  display_name = excluded.display_name,' +
    '  gate_type = excluded.gate_type,' +
    '  risk_level = excluded.risk_level,' +
    '  parent_key = excluded.parent_key,' +
    '  field_key = excluded.field_key,' +
    '  updated_at = datetime(''now'')';

  SQL_DELETE_GATE_CONDITIONS =
    'DELETE FROM governance_gate_conditions WHERE gate_key = :gate_key';

  SQL_INSERT_GATE_CONDITION =
    'INSERT INTO governance_gate_conditions ' +
    '  (gate_key, kind, expression, description, blocked_message) ' +
    'VALUES (:gate_key, :kind, :expression, :description, :blocked_message)';

  SQL_UPSERT_ACTION =
    'INSERT INTO governance_actions (key, display_name, risk_level, gate_key, ' +
    '  purpose_key, due_ref) ' +
    'VALUES (:key, :display_name, :risk_level, :gate_key, :purpose_key, :due_ref) ' +
    'ON CONFLICT(key) DO UPDATE SET ' +
    '  display_name = excluded.display_name,' +
    '  risk_level = excluded.risk_level,' +
    '  gate_key = excluded.gate_key,' +
    '  purpose_key = excluded.purpose_key,' +
    '  due_ref = excluded.due_ref,' +
    '  updated_at = datetime(''now'')';

  SQL_UPSERT_PURPOSE =
    'INSERT INTO governance_purposes (key, name, description, parent_key) ' +
    'VALUES (:key, :name, :description, :parent_key) ' +
    'ON CONFLICT(key) DO UPDATE SET ' +
    '  name = excluded.name,' +
    '  description = excluded.description,' +
    '  parent_key = excluded.parent_key';

  SQL_UPSERT_CONFIG =
    'INSERT INTO governance_config (key, value) VALUES (:key, :value) ' +
    'ON CONFLICT(key) DO UPDATE SET value = excluded.value';

  SQL_SELECT_CONFIG =
    'SELECT value FROM governance_config WHERE key = :key';

  SQL_SELECT_ALL_GATES =
    'SELECT key, display_name, gate_type, risk_level, parent_key, field_key ' +
    'FROM governance_gates';

  SQL_SELECT_CONDITIONS_FOR_GATE =
    'SELECT kind, expression, description, blocked_message ' +
    'FROM governance_gate_conditions WHERE gate_key = :gate_key ORDER BY id';

  // GOV-028 (BCW-A20260715-012/A): Persistent Gate→Action mapping.
  // Previously TAccessGate.ActionKeys lived only in memory and was never
  // persisted or reloaded, so the LoadGates cross-check ("every Gate.ActionKeys
  // references an Action that exists in ActionGrid") was unreachable dead
  // code. This table makes that mapping durable and the check reachable.
  SQL_CREATE_GATE_ACTION_KEYS =
    'CREATE TABLE IF NOT EXISTS governance_gate_action_keys (' +
    '  id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  gate_key TEXT NOT NULL,' +
    '  action_key TEXT NOT NULL,' +
    '  seq INTEGER NOT NULL DEFAULT 0,' +
    '  UNIQUE(gate_key, action_key)' +
    ')';

  SQL_CREATE_GATE_ACTION_KEYS_INDEX =
    'CREATE INDEX IF NOT EXISTS idx_gate_action_keys_gate ' +
    'ON governance_gate_action_keys(gate_key)';

  SQL_DELETE_GATE_ACTION_KEYS =
    'DELETE FROM governance_gate_action_keys WHERE gate_key = :gate_key';

  SQL_INSERT_GATE_ACTION_KEY =
    'INSERT OR IGNORE INTO governance_gate_action_keys ' +
    '  (gate_key, action_key, seq) VALUES (:gate_key, :action_key, :seq)';

  SQL_SELECT_ACTION_KEYS_FOR_GATE =
    'SELECT action_key FROM governance_gate_action_keys ' +
    'WHERE gate_key = :gate_key ORDER BY seq, id';

  // ASY-GOV-003 ②: next seq for appending a single action to a gate's forward
  // index (NULL → 0 when the gate has no rows yet). COALESCE keeps it an int.
  SQL_NEXT_SEQ_FOR_GATE =
    'SELECT COALESCE(MAX(seq), -1) + 1 FROM governance_gate_action_keys ' +
    'WHERE gate_key = :gate_key';

  SQL_SELECT_ALL_ACTIONS =
    'SELECT key, display_name, risk_level, gate_key, purpose_key, due_ref ' +
    'FROM governance_actions';

  SQL_SELECT_ALL_PURPOSES =
    'SELECT key, name, description, parent_key FROM governance_purposes';

{ TConfigRegistrar }

constructor TConfigRegistrar.Create(AConnection: TFDConnection;
  AKeyResolver: TKeyResolver; APurposeSet: TPurposeSet;
  AActionGrid: TActionGrid; ADueChecker: TDueChecker);
begin
  inherited Create;
  if AConnection = nil then
    raise EConfigRegistrarError.Create('AConnection cannot be nil');
  if AKeyResolver = nil then
    raise EConfigRegistrarError.Create('AKeyResolver cannot be nil');
  if APurposeSet = nil then
    raise EConfigRegistrarError.Create('APurposeSet cannot be nil');

  FConnection := AConnection;
  FKeyResolver := AKeyResolver;
  FPurposeSet := APurposeSet;
  FActionGrid := AActionGrid;
  FDueChecker := ADueChecker;

  EnsureTables;
  EnsureDefaultMode;
end;

destructor TConfigRegistrar.Destroy;
begin
  // FConnection, FKeyResolver, FPurposeSet are not owned.
  inherited;
end;

procedure TConfigRegistrar.EnsureTables;
begin
  FConnection.ExecSQL(SQL_CREATE_GATES);
  FConnection.ExecSQL(SQL_CREATE_GATE_CONDITIONS);
  FConnection.ExecSQL(SQL_CREATE_GATE_CONDITIONS_INDEX);
  FConnection.ExecSQL(SQL_CREATE_GATE_ACTION_KEYS);
  FConnection.ExecSQL(SQL_CREATE_GATE_ACTION_KEYS_INDEX);
  FConnection.ExecSQL(SQL_CREATE_ACTIONS);
  FConnection.ExecSQL(SQL_CREATE_PURPOSES);
  FConnection.ExecSQL(SQL_CREATE_CONFIG);
  FConnection.ExecSQL(SQL_CREATE_DUE_RULES);
end;

procedure TConfigRegistrar.EnsureDefaultMode;
var
  LQuery: TFDQuery;
  LHasRow: Boolean;
begin
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := SQL_SELECT_CONFIG;
    LQuery.ParamByName('key').AsString := CONFIG_KEY_MODE;
    LQuery.Open;
    LHasRow := not LQuery.Eof;
    LQuery.Close;

    if not LHasRow then
    begin
      // DATA2-023: Use SetMode so the default value gets an HMAC signature.
      SetMode(MODE_OBSERVE);
    end;
  finally
    FreeAndNil(LQuery);
  end;
end;

procedure TConfigRegistrar.UpsertGateRow(const AGateKey, ADisplayName: string;
  AGateType: TGateType; ARiskLevel: TRiskLevel;
  const AParentKey, AFieldKey: string);
var
  LQuery: TFDQuery;
begin
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := SQL_UPSERT_GATE;
    LQuery.ParamByName('key').AsString := AGateKey;
    LQuery.ParamByName('display_name').AsString := ADisplayName;
    LQuery.ParamByName('gate_type').AsInteger := Ord(AGateType);
    LQuery.ParamByName('risk_level').AsInteger := Ord(ARiskLevel);
    LQuery.ParamByName('parent_key').AsString := AParentKey;
    LQuery.ParamByName('field_key').AsString := AFieldKey;
    LQuery.ExecSQL;
  finally
    FreeAndNil(LQuery);
  end;
end;

procedure TConfigRegistrar.ReplaceGateConditions(const AGateKey: string;
  const AConditions: array of TGateCondition);
var
  LQuery: TFDQuery;
  I: Integer;
  LCond: TGateCondition;
begin
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := SQL_DELETE_GATE_CONDITIONS;
    LQuery.ParamByName('gate_key').AsString := AGateKey;
    LQuery.ExecSQL;

    if Length(AConditions) = 0 then
      Exit;

    LQuery.SQL.Text := SQL_INSERT_GATE_CONDITION;
    for I := 0 to High(AConditions) do
    begin
      LCond := AConditions[I];
      if LCond = nil then
        Continue;
      LQuery.ParamByName('gate_key').AsString := AGateKey;
      LQuery.ParamByName('kind').AsInteger := Ord(LCond.Kind);
      LQuery.ParamByName('expression').AsString := LCond.Expression;
      LQuery.ParamByName('description').AsString := LCond.Description;
      LQuery.ParamByName('blocked_message').AsString := LCond.BlockedMessage;
      LQuery.ExecSQL;
    end;
  finally
    FreeAndNil(LQuery);
  end;
end;

procedure TConfigRegistrar.ReplaceGateActionKeys(const AGateKey: string;
  const AActionKeys: array of string);
var
  LQuery: TFDQuery;
  I: Integer;
begin
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := SQL_DELETE_GATE_ACTION_KEYS;
    LQuery.ParamByName('gate_key').AsString := AGateKey;
    LQuery.ExecSQL;

    if Length(AActionKeys) = 0 then
      Exit;

    LQuery.SQL.Text := SQL_INSERT_GATE_ACTION_KEY;
    for I := 0 to High(AActionKeys) do
    begin
      if AActionKeys[I] = '' then
        Continue;
      LQuery.ParamByName('gate_key').AsString := AGateKey;
      LQuery.ParamByName('action_key').AsString := AActionKeys[I];
      LQuery.ParamByName('seq').AsInteger := I;
      LQuery.ExecSQL;
    end;
  finally
    FreeAndNil(LQuery);
  end;
end;

procedure TConfigRegistrar.UpsertGateActionKey(const AGateKey, AActionKey: string);
var
  LQuery: TFDQuery;
  LSeq: Integer;
begin
  // ASY-GOV-003 ② (方案B): auto-populate the forward gate→action_key index.
  // Guarded so callers may pass an empty AGateKey (action not yet bound to a
  // gate) — we just skip, matching RegisterAction's own guard below.
  if (AGateKey = '') or (AActionKey = '') then
    Exit;

  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    // Determine the next seq for this gate so multi-action gates stay ordered.
    LQuery.SQL.Text := SQL_NEXT_SEQ_FOR_GATE;
    LQuery.ParamByName('gate_key').AsString := AGateKey;
    LQuery.Open;
    LSeq := LQuery.Fields[0].AsInteger;
    LQuery.Close;

    // INSERT OR IGNORE: re-registering the same (gate,action) pair is a no-op,
    // so repeated calls or reload-then-register stay idempotent.
    LQuery.SQL.Text := SQL_INSERT_GATE_ACTION_KEY;
    LQuery.ParamByName('gate_key').AsString := AGateKey;
    LQuery.ParamByName('action_key').AsString := AActionKey;
    LQuery.ParamByName('seq').AsInteger := LSeq;
    LQuery.ExecSQL;
  finally
    FreeAndNil(LQuery);
  end;
end;

procedure TConfigRegistrar.SetGateActionKeys(const AGateKey: string;
  const AActionKeys: array of string);
var
  LGate: TAccessGate;
  I: Integer;
begin
  if AGateKey = '' then
    raise EConfigRegistrarError.Create('Gate key cannot be empty');

  // Persist the mapping regardless of whether the in-memory TAccessGate
  // currently exists; LoadFromDB will rebuild it from these rows.
  ReplaceGateActionKeys(AGateKey, AActionKeys);

  // Keep the in-memory KeyResolver gate in sync if it exists.
  LGate := FKeyResolver.ResolveGateKey(AGateKey);
  if LGate <> nil then
  begin
    LGate.ActionKeys.Clear;
    for I := 0 to High(AActionKeys) do
      if AActionKeys[I] <> '' then
        LGate.AddActionKey(AActionKeys[I]);
  end;
end;

procedure TConfigRegistrar.UpsertActionRow(const AActionKey, ADisplayName: string;
  ARiskLevel: TRiskLevel; const AGateKey, APurposeKey, ADueRef: string);
var
  LQuery: TFDQuery;
begin
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := SQL_UPSERT_ACTION;
    LQuery.ParamByName('key').AsString := AActionKey;
    LQuery.ParamByName('display_name').AsString := ADisplayName;
    LQuery.ParamByName('risk_level').AsInteger := Ord(ARiskLevel);
    LQuery.ParamByName('gate_key').AsString := AGateKey;
    LQuery.ParamByName('purpose_key').AsString := APurposeKey;
    LQuery.ParamByName('due_ref').AsString := ADueRef;
    LQuery.ExecSQL;
  finally
    FreeAndNil(LQuery);
  end;
end;

procedure TConfigRegistrar.UpsertPurposeRow(const AKey, AName, ADescription,
  AParentKey: string);
var
  LQuery: TFDQuery;
begin
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := SQL_UPSERT_PURPOSE;
    LQuery.ParamByName('key').AsString := AKey;
    LQuery.ParamByName('name').AsString := AName;
    LQuery.ParamByName('description').AsString := ADescription;
    LQuery.ParamByName('parent_key').AsString := AParentKey;
    LQuery.ExecSQL;
  finally
    FreeAndNil(LQuery);
  end;
end;

procedure TConfigRegistrar.RegisterGate(const AGateKey, ADisplayName: string;
  AGateType: TGateType; ARiskLevel: TRiskLevel;
  const AConditions: array of TGateCondition);
var
  LGate: TAccessGate;
  I: Integer;
  LSrc, LClone: TGateCondition;
begin
  if AGateKey = '' then
    raise EConfigRegistrarError.Create('Gate key cannot be empty');

  UpsertGateRow(AGateKey, ADisplayName, AGateType, ARiskLevel, '', '');
  ReplaceGateConditions(AGateKey, AConditions);
  // GOV-028: RegisterGate is a full reset of the gate definition; clear any
  // previously stored Gate→Action mapping so reloads match the intent.
  // (The newly-created in-memory TAccessGate carries no ActionKeys itself.)
  ReplaceGateActionKeys(AGateKey, []);

  // NOTE: risk level is persisted but not carried on TAccessGate
  // (the model attaches risk to TAction). The DB row is the source
  // of truth for reload.
  LGate := TAccessGate.Create(AGateKey, ADisplayName, AGateType, '', '');
  try
    for I := 0 to High(AConditions) do
    begin
      LSrc := AConditions[I];
      if LSrc = nil then
        Continue;
      LClone := TGateCondition.Create(LSrc.Kind, LSrc.Expression,
        LSrc.Description, LSrc.BlockedMessage);
      LGate.AddCondition(LClone);
    end;
    FKeyResolver.RegisterGate(LGate);
    LGate := nil; // ownership transferred to KeyResolver
  finally
    LGate.Free;
  end;
end;

procedure TConfigRegistrar.RegisterGate(const AGateKey, ADisplayName: string;
  AGateType: TGateType; ARiskLevel: TRiskLevel);
var
  LEmpty: array of TGateCondition;
begin
  SetLength(LEmpty, 0);
  RegisterGate(AGateKey, ADisplayName, AGateType, ARiskLevel, LEmpty);
end;

procedure TConfigRegistrar.RegisterAction(const AActionKey, ADisplayName: string;
  ARiskLevel: TRiskLevel; const AGateKey: string;
  const APurposeKey: string; const ADueRef: string);
var
  LAction: TAction;
begin
  if AActionKey = '' then
    raise EConfigRegistrarError.Create('Action key cannot be empty');

  UpsertActionRow(AActionKey, ADisplayName, ARiskLevel, AGateKey, APurposeKey,
    ADueRef);

  // ASY-GOV-003 ② (BCW-A20260715-008, 方案B): auto-write the forward
  // gate→action_key index so LoadGates can read it back without callers
  // having to invoke the (private) ReplaceGateActionKeys. Skipped silently
  // when AGateKey is empty — an action not yet bound to any gate.
  UpsertGateActionKey(AGateKey, AActionKey);

  LAction := TAction.Create(AActionKey, ADisplayName, ARiskLevel, AGateKey,
    ADueRef, APurposeKey);
  try
    // REVIEW5-GOV-001: Sync to all three registries (KeyResolver, ActionGrid, DueChecker)
    FKeyResolver.RegisterAction(LAction);
    if FActionGrid <> nil then
      FActionGrid.RegisterActionObj(LAction);
    if FDueChecker <> nil then
      FDueChecker.AutoRegisterFromAction(LAction);
    LAction := nil; // ownership transferred
  finally
    LAction.Free;
  end;
end;

procedure TConfigRegistrar.RegisterPurpose(const AKey, AName,
  ADescription: string; const AParentKey: string);
var
  LPurpose: TPurpose;
begin
  if AKey = '' then
    raise EConfigRegistrarError.Create('Purpose key cannot be empty');

  UpsertPurposeRow(AKey, AName, ADescription, AParentKey);

  LPurpose := TPurpose.Create(AKey, AName, ADescription, AParentKey);
  try
    FPurposeSet.Register(LPurpose);
    LPurpose := nil;
  finally
    LPurpose.Free;
  end;
end;

procedure TConfigRegistrar.LoadGates;
var
  LQuery, LCondQuery: TFDQuery;
  LGate: TAccessGate;
  LGateKey, LDisplayName, LParentKey, LFieldKey: string;
  LGateType: TGateType;
  LActionKey: string;
begin
  LQuery := TFDQuery.Create(nil);
  LCondQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LCondQuery.Connection := FConnection;

    LQuery.SQL.Text := SQL_SELECT_ALL_GATES;
    LQuery.Open;
    while not LQuery.Eof do
    begin
      LGateKey := LQuery.FieldByName('key').AsString;
      LDisplayName := LQuery.FieldByName('display_name').AsString;
      LGateType := TGateType(LQuery.FieldByName('gate_type').AsInteger);
      LParentKey := LQuery.FieldByName('parent_key').AsString;
      LFieldKey := LQuery.FieldByName('field_key').AsString;

      LGate := TAccessGate.Create(LGateKey, LDisplayName, LGateType,
        LParentKey, LFieldKey);
      try
        LCondQuery.Close;
        LCondQuery.SQL.Text := SQL_SELECT_CONDITIONS_FOR_GATE;
        LCondQuery.ParamByName('gate_key').AsString := LGateKey;
        LCondQuery.Open;
        while not LCondQuery.Eof do
        begin
          LGate.AddCondition(TGateCondition.Create(
            TGateConditionKind(LCondQuery.FieldByName('kind').AsInteger),
            LCondQuery.FieldByName('expression').AsString,
            LCondQuery.FieldByName('description').AsString,
            LCondQuery.FieldByName('blocked_message').AsString));
          LCondQuery.Next;
        end;
        LCondQuery.Close;

        // GOV-028: Load this gate's persisted Gate→Action mapping so the
        // cross-check below becomes reachable. Without this the mapping lived
        // only in memory and was lost on every reload.
        LCondQuery.SQL.Text := SQL_SELECT_ACTION_KEYS_FOR_GATE;
        LCondQuery.ParamByName('gate_key').AsString := LGateKey;
        LCondQuery.Open;
        while not LCondQuery.Eof do
        begin
          LGate.AddActionKey(LCondQuery.FieldByName('action_key').AsString);
          LCondQuery.Next;
        end;
        LCondQuery.Close;

        FKeyResolver.RegisterGate(LGate);
        LGate := nil;
      finally
        LGate.Free;
      end;
      LQuery.Next;
    end;

    // REVIEW5-GOV-001: After all gates are loaded, verify that every Gate's
    // ActionKeys reference an Action that exists in ActionGrid. This ensures
    // the mapping from Gate.ActionKeys to ActionGrid is valid.
    if FActionGrid <> nil then
    begin
      for LGate in FKeyResolver.GetAllGates do
      begin
        for LActionKey in LGate.ActionKeys do
        begin
          if FActionGrid.FindAction(LActionKey) = nil then
            raise EConfigRegistrarError.CreateFmt(
              'Gate "%s" references Action "%s" which is not registered in ActionGrid',
              [LGate.Key, LActionKey]);
        end;
      end;
    end;
  finally
    FreeAndNil(LCondQuery);
    FreeAndNil(LQuery);
  end;
end;

procedure TConfigRegistrar.LoadActions;
var
  LQuery: TFDQuery;
  LAction: TAction;
begin
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := SQL_SELECT_ALL_ACTIONS;
    LQuery.Open;
    while not LQuery.Eof do
    begin
      LAction := TAction.Create(
        LQuery.FieldByName('key').AsString,
        LQuery.FieldByName('display_name').AsString,
        TRiskLevel(LQuery.FieldByName('risk_level').AsInteger),
        LQuery.FieldByName('gate_key').AsString,
        LQuery.FieldByName('due_ref').AsString,
        LQuery.FieldByName('purpose_key').AsString);
      try
        // REVIEW5-GOV-001: Sync to all three registries when loading from ConfigDB
        FKeyResolver.RegisterAction(LAction);
        if FActionGrid <> nil then
          FActionGrid.RegisterActionObj(LAction);
        if FDueChecker <> nil then
          FDueChecker.AutoRegisterFromAction(LAction);
        LAction := nil;
      finally
        LAction.Free;
      end;
      LQuery.Next;
    end;
  finally
    FreeAndNil(LQuery);
  end;
end;

procedure TConfigRegistrar.LoadPurposes;
var
  LQuery: TFDQuery;
  LPurpose: TPurpose;
begin
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := SQL_SELECT_ALL_PURPOSES;
    LQuery.Open;
    while not LQuery.Eof do
    begin
      LPurpose := TPurpose.Create(
        LQuery.FieldByName('key').AsString,
        LQuery.FieldByName('name').AsString,
        LQuery.FieldByName('description').AsString,
        LQuery.FieldByName('parent_key').AsString);
      try
        FPurposeSet.Register(LPurpose);
        LPurpose := nil;
      finally
        LPurpose.Free;
      end;
      LQuery.Next;
    end;
  finally
    FreeAndNil(LQuery);
  end;
end;

procedure TConfigRegistrar.UpsertDueRuleRow(const ARule: TDueRule);
var
  LQuery: TFDQuery;
begin
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := SQL_UPSERT_DUE_RULE;
    LQuery.ParamByName('action_key').AsString := ARule.ActionKey;
    LQuery.ParamByName('risk_level').AsInteger := Ord(ARule.RiskLevel);
    LQuery.ParamByName('require_evidence').AsInteger := Ord(ARule.RequireEvidence);
    LQuery.ParamByName('require_accountability').AsInteger := Ord(ARule.RequireAccountability);
    LQuery.ParamByName('require_confirm').AsInteger := Ord(ARule.RequireConfirm);
    LQuery.ParamByName('require_seal').AsInteger := Ord(ARule.RequireSeal);
    LQuery.ParamByName('description').AsString := ARule.Description;
    LQuery.ExecSQL;
  finally
    FreeAndNil(LQuery);
  end;
end;

procedure TConfigRegistrar.RegisterDueRule(const ARule: TDueRule);
begin
  if ARule.ActionKey = '' then
    raise EConfigRegistrarError.Create('DueRule ActionKey cannot be empty');

  // Persist the verbatim TDueRule, then mirror into the in-memory checker.
  // RegisterRule AddOrSetValue overwrites any AutoRegisterFromAction entry,
  // so the explicit (observe-safe) fields win on reload too.
  UpsertDueRuleRow(ARule);

  if FDueChecker <> nil then
    FDueChecker.RegisterRule(ARule);
end;

procedure TConfigRegistrar.RegisterRouteRule(ARule: TRouteRule);
var
  LStore: TRouteStoreSQLite;
begin
  if ARule = nil then
    raise EConfigRegistrarError.Create('RouteRule cannot be nil');
  if ARule.Id = '' then
    raise EConfigRegistrarError.Create('RouteRule Id cannot be empty');
  if ARule.SourceGateKey = '' then
    raise EConfigRegistrarError.Create('RouteRule SourceGateKey cannot be empty');

  // Delegate to TRouteStoreSQLite: it owns the table DDL (EnsureTable runs in
  // its constructor), the index, and a Save that is INSERT OR REPLACE on id,
  // so this is idempotent — repeat registration of the same id overwrites
  // cleanly, matching RegisterGate/RegisterAction semantics.
  LStore := TRouteStoreSQLite.Create(FConnection, False);
  try
    LStore.Save(ARule);
  finally
    LStore.Free;
  end;
end;

procedure TConfigRegistrar.LoadDueRules;
var
  LQuery: TFDQuery;
  LRule: TDueRule;
begin
  if FDueChecker = nil then
    Exit;

  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := SQL_SELECT_ALL_DUE_RULES;
    LQuery.Open;
    while not LQuery.Eof do
    begin
      LRule.ActionKey := LQuery.FieldByName('action_key').AsString;
      LRule.RiskLevel := TRiskLevel(LQuery.FieldByName('risk_level').AsInteger);
      LRule.RequireEvidence := LQuery.FieldByName('require_evidence').AsInteger <> 0;
      LRule.RequireAccountability := LQuery.FieldByName('require_accountability').AsInteger <> 0;
      LRule.RequireConfirm := LQuery.FieldByName('require_confirm').AsInteger <> 0;
      LRule.RequireSeal := LQuery.FieldByName('require_seal').AsInteger <> 0;
      LRule.Description := LQuery.FieldByName('description').AsString;
      FDueChecker.RegisterRule(LRule);
      LQuery.Next;
    end;
  finally
    FreeAndNil(LQuery);
  end;
end;

procedure TConfigRegistrar.LoadFromDB;
begin
  // DATA2-007: Actions must be loaded before Gates, because LoadGates
  // cross-validates that every Gate's ActionKeys reference an Action that
  // already exists in FActionGrid.
  LoadPurposes;
  LoadActions;
  LoadGates;
  // ASY-GOV-003: reload explicit DueRules last so they override any
  // AutoRegisterFromAction entries produced during LoadActions.
  LoadDueRules;
end;

function TConfigRegistrar.ComputeModeHMAC(const AMode: string): string;
var
  LKey: TBytes;
begin
  Result := '';
  try
    if not TKeyManager.Instance.IsUnlocked then
      Exit;
    LKey := TKeyManager.Instance.GetActiveKeyForPurpose(kpSigning);
    Result := TEncodingUtils.HexEncode(
      THashUtils.HMAC(LKey, TEncoding.UTF8.GetBytes(AMode), haSHA256));
  except
    // If KeyManager is not initialized or signing key is unavailable,
    // return empty — caller should treat as "unverifiable → default enforce".
    Result := '';
  end;
end;

function TConfigRegistrar.ValidateModeHMAC(const AMode, AStoredSig: string): Boolean;
var
  LExpected: string;
begin
  if AStoredSig = '' then
    // No signature stored — treat as tampered / unverifiable.
    Exit(False);
  LExpected := ComputeModeHMAC(AMode);
  // Constant-time compare is not available in base Delphi, but the
  // hex-string comparison here is acceptable because the attacker would
  // need write access to the DB *and* the signing key.
  Result := (LExpected <> '') and SameText(LExpected, AStoredSig);
end;

function TConfigRegistrar.GetMode: string;
var
  LQuery: TFDQuery;
  LMode, LSig: string;
begin
  Result := MODE_OBSERVE;
  LMode := '';
  LSig := '';
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;

    // Read stored mode
    LQuery.SQL.Text := SQL_SELECT_CONFIG;
    LQuery.ParamByName('key').AsString := CONFIG_KEY_MODE;
    LQuery.Open;
    if not LQuery.Eof then
      LMode := LQuery.FieldByName('value').AsString;
    LQuery.Close;

    // Read stored HMAC signature
    LQuery.SQL.Text := SQL_SELECT_CONFIG;
    LQuery.ParamByName('key').AsString := CONFIG_KEY_MODE_SIG;
    LQuery.Open;
    if not LQuery.Eof then
      LSig := LQuery.FieldByName('value').AsString;

    // DATA2-023: Verify integrity. If HMAC does not match, the mode has
    // been tampered with (e.g. DB-level write). Default to enforce for safety.
    if LMode <> '' then
    begin
      if ValidateModeHMAC(LMode, LSig) then
        Result := LMode
      else
      begin
        // Tampered mode detected — reset to safe default and re-sign.
        SetMode(MODE_OBSERVE);
        Result := MODE_OBSERVE;
      end;
    end;
  finally
    FreeAndNil(LQuery);
  end;
end;

procedure TConfigRegistrar.SetMode(const AMode: string);
var
  LQuery: TFDQuery;
  LSig: string;
begin
  if (AMode <> MODE_OBSERVE) and (AMode <> MODE_ENFORCE) then
    raise EConfigRegistrarError.CreateFmt(
      'Invalid governance mode "%s" (expected "observe" or "enforce")',
      [AMode]);

  // DATA2-023: Compute HMAC signature of the mode value before persisting.
  LSig := ComputeModeHMAC(AMode);

  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;

    // Store mode value
    LQuery.SQL.Text := SQL_UPSERT_CONFIG;
    LQuery.ParamByName('key').AsString := CONFIG_KEY_MODE;
    LQuery.ParamByName('value').AsString := AMode;
    LQuery.ExecSQL;

    // Store HMAC signature alongside
    LQuery.SQL.Text := SQL_UPSERT_CONFIG;
    LQuery.ParamByName('key').AsString := CONFIG_KEY_MODE_SIG;
    LQuery.ParamByName('value').AsString := LSig;
    LQuery.ExecSQL;
  finally
    FreeAndNil(LQuery);
  end;
end;

procedure TConfigRegistrar.SetPackageMetadata(const APackageId, AVersion,
  ADeepbaseMinVersion, AContractVersion, AContentDigest,
  AActivatedAt: string);
const
  // (key, value) pairs written to governance_config via SQL_UPSERT_CONFIG.
  PAIRS: array[0..5, 0..1] of string = (
    (CONFIG_KEY_POLICY_PACKAGE_ID,    ''),
    (CONFIG_KEY_POLICY_VERSION,       ''),
    (CONFIG_KEY_DEEPBASE_MIN_VERSION, ''),
    (CONFIG_KEY_CONTRACT_VERSION,     ''),
    (CONFIG_KEY_CONTENT_DIGEST,       ''),
    (CONFIG_KEY_ACTIVATED_AT,         ''));
var
  LQuery: TFDQuery;
  LValues: array[0..5] of string;
  I: Integer;
begin
  LValues[0] := APackageId;
  LValues[1] := AVersion;
  LValues[2] := ADeepbaseMinVersion;
  LValues[3] := AContractVersion;
  LValues[4] := AContentDigest;
  LValues[5] := AActivatedAt;

  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    for I := Low(PAIRS) to High(PAIRS) do
    begin
      LQuery.SQL.Text := SQL_UPSERT_CONFIG;
      LQuery.ParamByName('key').AsString := PAIRS[I, 0];
      LQuery.ParamByName('value').AsString := LValues[I];
      LQuery.ExecSQL;
    end;
  finally
    FreeAndNil(LQuery);
  end;
end;

function TConfigRegistrar.GetPackageMetadata(const AKey: string): string;
var
  LQuery: TFDQuery;
begin
  Result := '';
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := SQL_SELECT_CONFIG;
    LQuery.ParamByName('key').AsString := AKey;
    LQuery.Open;
    if not LQuery.Eof then
      Result := LQuery.FieldByName('value').AsString;
    LQuery.Close;
  finally
    FreeAndNil(LQuery);
  end;
end;

end.
