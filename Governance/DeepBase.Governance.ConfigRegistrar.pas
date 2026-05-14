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
  DeepBase.Governance.Purpose;

type
  EConfigRegistrarError = class(Exception);

  /// <summary>
  /// Code-first configuration registrar. Persists governance definitions
  /// to ConfigDB (SQLite) governance_* tables and mirrors them into the
  /// in-memory TKeyResolver / TPurposeSet.
  /// </summary>
  TConfigRegistrar = class
  private
    FConnection: TFDConnection;
    FKeyResolver: TKeyResolver;
    FPurposeSet: TPurposeSet;
    procedure EnsureTables;
    procedure EnsureDefaultMode;
    procedure UpsertGateRow(const AGateKey, ADisplayName: string;
      AGateType: TGateType; ARiskLevel: TRiskLevel;
      const AParentKey, AFieldKey: string);
    procedure ReplaceGateConditions(const AGateKey: string;
      const AConditions: array of TGateCondition);
    procedure UpsertActionRow(const AActionKey, ADisplayName: string;
      ARiskLevel: TRiskLevel; const AGateKey, APurposeKey, ADueRef: string);
    procedure UpsertPurposeRow(const AKey, AName, ADescription,
      AParentKey: string);
    procedure LoadGates;
    procedure LoadActions;
    procedure LoadPurposes;
  public
    constructor Create(AConnection: TFDConnection; AKeyResolver: TKeyResolver;
      APurposeSet: TPurposeSet);
    destructor Destroy; override;

    /// Register a gate definition. Upserts the row, replaces its conditions,
    /// creates an in-memory TAccessGate and registers it on KeyResolver.
    procedure RegisterGate(const AGateKey, ADisplayName: string;
      AGateType: TGateType; ARiskLevel: TRiskLevel;
      const AConditions: array of TGateCondition); overload;
    procedure RegisterGate(const AGateKey, ADisplayName: string;
      AGateType: TGateType; ARiskLevel: TRiskLevel); overload;

    /// Register an action definition.
    procedure RegisterAction(const AActionKey, ADisplayName: string;
      ARiskLevel: TRiskLevel; const AGateKey: string;
      const APurposeKey: string = ''; const ADueRef: string = '');

    /// Register a purpose.
    procedure RegisterPurpose(const AKey, AName, ADescription: string;
      const AParentKey: string = '');

    /// Reload all governance definitions from ConfigDB into KeyResolver
    /// and PurposeSet.
    procedure LoadFromDB;

    /// Governance mode accessors. Valid values: 'observe' | 'enforce'.
    function GetMode: string;
    procedure SetMode(const AMode: string);

    property Connection: TFDConnection read FConnection;
    property KeyResolver: TKeyResolver read FKeyResolver;
    property PurposeSet: TPurposeSet read FPurposeSet;
  end;

implementation

const
  MODE_OBSERVE = 'observe';
  MODE_ENFORCE = 'enforce';
  CONFIG_KEY_MODE = 'mode';

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

  SQL_SELECT_ALL_ACTIONS =
    'SELECT key, display_name, risk_level, gate_key, purpose_key, due_ref ' +
    'FROM governance_actions';

  SQL_SELECT_ALL_PURPOSES =
    'SELECT key, name, description, parent_key FROM governance_purposes';

{ TConfigRegistrar }

constructor TConfigRegistrar.Create(AConnection: TFDConnection;
  AKeyResolver: TKeyResolver; APurposeSet: TPurposeSet);
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
  FConnection.ExecSQL(SQL_CREATE_ACTIONS);
  FConnection.ExecSQL(SQL_CREATE_PURPOSES);
  FConnection.ExecSQL(SQL_CREATE_CONFIG);
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
      LQuery.SQL.Text := SQL_UPSERT_CONFIG;
      LQuery.ParamByName('key').AsString := CONFIG_KEY_MODE;
      LQuery.ParamByName('value').AsString := MODE_OBSERVE;
      LQuery.ExecSQL;
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

  LAction := TAction.Create(AActionKey, ADisplayName, ARiskLevel, AGateKey,
    ADueRef, APurposeKey);
  try
    FKeyResolver.RegisterAction(LAction);
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

        FKeyResolver.RegisterGate(LGate);
        LGate := nil;
      finally
        LGate.Free;
      end;
      LQuery.Next;
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
        FKeyResolver.RegisterAction(LAction);
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

procedure TConfigRegistrar.LoadFromDB;
begin
  LoadPurposes;
  LoadGates;
  LoadActions;
end;

function TConfigRegistrar.GetMode: string;
var
  LQuery: TFDQuery;
begin
  Result := MODE_OBSERVE;
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := SQL_SELECT_CONFIG;
    LQuery.ParamByName('key').AsString := CONFIG_KEY_MODE;
    LQuery.Open;
    if not LQuery.Eof then
      Result := LQuery.FieldByName('value').AsString;
  finally
    FreeAndNil(LQuery);
  end;
end;

procedure TConfigRegistrar.SetMode(const AMode: string);
var
  LQuery: TFDQuery;
begin
  if (AMode <> MODE_OBSERVE) and (AMode <> MODE_ENFORCE) then
    raise EConfigRegistrarError.CreateFmt(
      'Invalid governance mode "%s" (expected "observe" or "enforce")',
      [AMode]);

  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := SQL_UPSERT_CONFIG;
    LQuery.ParamByName('key').AsString := CONFIG_KEY_MODE;
    LQuery.ParamByName('value').AsString := AMode;
    LQuery.ExecSQL;
  finally
    FreeAndNil(LQuery);
  end;
end;

end.
