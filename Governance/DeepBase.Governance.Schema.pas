{ ============================================================================
  DeepBase.Governance.Schema
  ---------------------------------------------------------------------------
  Version     : 1.0
  Description : DDL + upsert/load helpers for governance_* tables living in
                DB1 (ConfigDB). Governance config is sourced from ConfigDB
                exclusively — no JSON files in downstream projects.

                Tables managed:
                  governance_purposes
                  governance_fields
                  governance_gates      (conditions stored as JSON text)
                  governance_actions    (bridge_keys stored as JSON text)
                  governance_routes

  Thread Safety: Intended to be called at Governance Initialize/Start,
                 not under concurrent load.
  ============================================================================ }

unit DeepBase.Governance.Schema;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Generics.Collections,
  Data.DB,
  FireDAC.Comp.Client,
  FireDAC.Stan.Param,
  DeepBase.Governance.Types,
  DeepBase.Governance.Model,
  DeepBase.Governance.Purpose,
  DeepBase.Governance.KeyResolver,
  DeepBase.Governance.DueChecker;

/// <summary>
/// Create all governance_* tables if they don't exist. Safe to call repeatedly.
/// </summary>
procedure EnsureGovernanceSchema(AConn: TFDConnection);

/// <summary>
/// Upsert a purpose into governance_purposes. Key is primary key.
/// </summary>
procedure UpsertPurpose(AConn: TFDConnection; APurpose: TPurpose);

/// <summary>
/// Upsert a context field into governance_fields. Key is primary key.
/// </summary>
procedure UpsertField(AConn: TFDConnection; AField: TContextField);

/// <summary>
/// Upsert a gate into governance_gates. Conditions serialized as JSON.
/// </summary>
procedure UpsertGate(AConn: TFDConnection; AGate: TAccessGate);

/// <summary>
/// Upsert an action into governance_actions. BridgeKeys serialized as JSON.
/// </summary>
procedure UpsertAction(AConn: TFDConnection; AAction: TAction);

/// <summary>
/// Load all purposes from governance_purposes into the PurposeSet.
/// </summary>
procedure LoadAllPurposes(AConn: TFDConnection; APurposeSet: TPurposeSet);

/// <summary>
/// Load all fields from governance_fields into the KeyResolver.
/// </summary>
procedure LoadAllFields(AConn: TFDConnection; AKeyResolver: TKeyResolver);

/// <summary>
/// Load all gates from governance_gates into the KeyResolver.
/// </summary>
procedure LoadAllGates(AConn: TFDConnection; AKeyResolver: TKeyResolver);

/// <summary>
/// Load all actions from governance_actions into the KeyResolver.
/// Also auto-registers Due rules through the DueChecker.
/// </summary>
procedure LoadAllActions(AConn: TFDConnection; AKeyResolver: TKeyResolver;
  ADueChecker: TDueChecker);

implementation

uses
  System.DateUtils;

// ============================================================================
// DDL
// ============================================================================

const
  SQL_CREATE_PURPOSES =
    'CREATE TABLE IF NOT EXISTS governance_purposes (' +
    '  key TEXT PRIMARY KEY,' +
    '  name TEXT NOT NULL,' +
    '  description TEXT,' +
    '  parent_key TEXT,' +
    '  status TEXT NOT NULL DEFAULT ''Active'',' +
    '  updated_at TEXT NOT NULL' +
    ')';

  SQL_CREATE_FIELDS =
    'CREATE TABLE IF NOT EXISTS governance_fields (' +
    '  key TEXT PRIMARY KEY,' +
    '  name TEXT NOT NULL,' +
    '  description TEXT,' +
    '  updated_at TEXT NOT NULL' +
    ')';

  SQL_CREATE_GATES =
    'CREATE TABLE IF NOT EXISTS governance_gates (' +
    '  key TEXT PRIMARY KEY,' +
    '  name TEXT NOT NULL,' +
    '  gate_type TEXT NOT NULL DEFAULT ''action'',' +
    '  parent_key TEXT,' +
    '  field_key TEXT,' +
    '  action_keys TEXT,' +
    '  conditions TEXT,' +
    '  updated_at TEXT NOT NULL' +
    ')';

  SQL_CREATE_ACTIONS =
    'CREATE TABLE IF NOT EXISTS governance_actions (' +
    '  key TEXT PRIMARY KEY,' +
    '  name TEXT NOT NULL,' +
    '  display_name TEXT,' +
    '  risk_level TEXT NOT NULL DEFAULT ''L0'',' +
    '  gate_key TEXT,' +
    '  due_ref TEXT,' +
    '  purpose_key TEXT,' +
    '  bridge_keys TEXT,' +
    '  updated_at TEXT NOT NULL' +
    ')';

  SQL_CREATE_ROUTES =
    'CREATE TABLE IF NOT EXISTS governance_routes (' +
    '  id TEXT PRIMARY KEY,' +
    '  source_gate_key TEXT NOT NULL,' +
    '  condition_expr TEXT NOT NULL DEFAULT ''true'',' +
    '  target_type TEXT NOT NULL DEFAULT ''action'',' +
    '  target_key TEXT NOT NULL,' +
    '  priority INTEGER NOT NULL DEFAULT 0,' +
    '  enabled INTEGER NOT NULL DEFAULT 1,' +
    '  risk_level TEXT NOT NULL DEFAULT ''L0'',' +
    '  fallback_target TEXT,' +
    '  description TEXT,' +
    '  updated_at TEXT NOT NULL' +
    ')';

  SQL_IDX_GATES_TYPE =
    'CREATE INDEX IF NOT EXISTS idx_governance_gates_type ON governance_gates(gate_type)';

  SQL_IDX_ACTIONS_GATE =
    'CREATE INDEX IF NOT EXISTS idx_governance_actions_gate ON governance_actions(gate_key)';

procedure EnsureGovernanceSchema(AConn: TFDConnection);
begin
  if AConn = nil then Exit;
  AConn.ExecSQL(SQL_CREATE_PURPOSES);
  AConn.ExecSQL(SQL_CREATE_FIELDS);
  AConn.ExecSQL(SQL_CREATE_GATES);
  AConn.ExecSQL(SQL_CREATE_ACTIONS);
  AConn.ExecSQL(SQL_CREATE_ROUTES);
  AConn.ExecSQL(SQL_IDX_GATES_TYPE);
  AConn.ExecSQL(SQL_IDX_ACTIONS_GATE);
end;

// ============================================================================
// Helpers
// ============================================================================

function NowIso: string;
begin
  Result := DateToISO8601(Now, False);
end;

function RiskToStr(ARisk: TRiskLevel): string;
begin
  case ARisk of
    rlL0: Result := 'L0';
    rlL1: Result := 'L1';
    rlL2: Result := 'L2';
    rlL3: Result := 'L3';
  else
    Result := 'L0';
  end;
end;

function StrToRisk(const S: string): TRiskLevel;
begin
  if SameText(S, 'L1') then Result := rlL1
  else if SameText(S, 'L2') then Result := rlL2
  else if SameText(S, 'L3') then Result := rlL3
  else Result := rlL0;
end;

function GateTypeToStr(AType: TGateType): string;
begin
  case AType of
    gtEntry: Result := 'entry';
    gtRoute: Result := 'route';
  else
    Result := 'action';
  end;
end;

function StrToGateType(const S: string): TGateType;
begin
  if SameText(S, 'entry') then Result := gtEntry
  else if SameText(S, 'route') then Result := gtRoute
  else Result := gtAction;
end;

function CondKindToStr(AKind: TGateConditionKind): string;
begin
  case AKind of
    gckPermission: Result := 'permission';
    gckRisk: Result := 'risk';
    gckContract: Result := 'contract';
    gckEvidence: Result := 'evidence';
    gckSeal: Result := 'seal';
    gckAccountability: Result := 'accountability';
  else
    Result := 'state';
  end;
end;

function StrToCondKind(const S: string): TGateConditionKind;
begin
  if SameText(S, 'permission') then Result := gckPermission
  else if SameText(S, 'risk') then Result := gckRisk
  else if SameText(S, 'contract') then Result := gckContract
  else if SameText(S, 'evidence') then Result := gckEvidence
  else if SameText(S, 'seal') then Result := gckSeal
  else if SameText(S, 'accountability') then Result := gckAccountability
  else Result := gckState;
end;

function StrArrayToJson(const AArr: array of string): string;
var
  LArr: TJSONArray;
  I: Integer;
begin
  LArr := TJSONArray.Create;
  try
    for I := 0 to High(AArr) do
      LArr.Add(AArr[I]);
    Result := LArr.ToJSON;
  finally
    LArr.Free;
  end;
end;

function ConditionsToJson(AGate: TAccessGate): string;
var
  LArr: TJSONArray;
  LObj: TJSONObject;
  LCond: TGateCondition;
begin
  LArr := TJSONArray.Create;
  try
    for LCond in AGate.Conditions do
    begin
      LObj := TJSONObject.Create;
      LObj.AddPair('kind', CondKindToStr(LCond.Kind));
      LObj.AddPair('expression', LCond.Expression);
      LObj.AddPair('description', LCond.Description);
      LObj.AddPair('blocked_message', LCond.BlockedMessage);
      LArr.AddElement(LObj);
    end;
    Result := LArr.ToJSON;
  finally
    LArr.Free;
  end;
end;

procedure StrListFromJsonText(const AJson: string; AList: TStrings);
var
  LVal: TJSONValue;
  LArr: TJSONArray;
  I: Integer;
begin
  AList.Clear;
  if Trim(AJson) = '' then Exit;
  LVal := TJSONObject.ParseJSONValue(AJson);
  if LVal = nil then Exit;
  try
    if LVal is TJSONArray then
    begin
      LArr := TJSONArray(LVal);
      for I := 0 to LArr.Count - 1 do
        AList.Add(LArr.Items[I].Value);
    end;
  finally
    LVal.Free;
  end;
end;

// ============================================================================
// Upserts
// ============================================================================

procedure UpsertPurpose(AConn: TFDConnection; APurpose: TPurpose);
const
  SQL =
    'INSERT INTO governance_purposes (key, name, description, parent_key, status, updated_at) ' +
    'VALUES (:key, :name, :description, :parent_key, :status, :updated_at) ' +
    'ON CONFLICT(key) DO UPDATE SET ' +
    '  name=excluded.name, description=excluded.description, ' +
    '  parent_key=excluded.parent_key, status=excluded.status, ' +
    '  updated_at=excluded.updated_at';
var
  LQ: TFDQuery;
begin
  if (AConn = nil) or (APurpose = nil) then Exit;
  LQ := TFDQuery.Create(nil);
  try
    LQ.Connection := AConn;
    LQ.SQL.Text := SQL;
    LQ.ParamByName('key').AsString := APurpose.Key;
    LQ.ParamByName('name').AsString := APurpose.Name;
    LQ.ParamByName('description').AsString := APurpose.Description;
    LQ.ParamByName('parent_key').AsString := APurpose.ParentKey;
    LQ.ParamByName('status').AsString := APurpose.Status;
    LQ.ParamByName('updated_at').AsString := NowIso;
    LQ.ExecSQL;
  finally
    LQ.Free;
  end;
end;

procedure UpsertField(AConn: TFDConnection; AField: TContextField);
const
  SQL =
    'INSERT INTO governance_fields (key, name, description, updated_at) ' +
    'VALUES (:key, :name, :description, :updated_at) ' +
    'ON CONFLICT(key) DO UPDATE SET ' +
    '  name=excluded.name, description=excluded.description, ' +
    '  updated_at=excluded.updated_at';
var
  LQ: TFDQuery;
begin
  if (AConn = nil) or (AField = nil) then Exit;
  LQ := TFDQuery.Create(nil);
  try
    LQ.Connection := AConn;
    LQ.SQL.Text := SQL;
    LQ.ParamByName('key').AsString := AField.Key;
    LQ.ParamByName('name').AsString := AField.DisplayName;
    LQ.ParamByName('description').AsString := AField.Description;
    LQ.ParamByName('updated_at').AsString := NowIso;
    LQ.ExecSQL;
  finally
    LQ.Free;
  end;
end;

procedure UpsertGate(AConn: TFDConnection; AGate: TAccessGate);
const
  SQL =
    'INSERT INTO governance_gates (key, name, gate_type, parent_key, field_key, ' +
    '  action_keys, conditions, updated_at) ' +
    'VALUES (:key, :name, :gate_type, :parent_key, :field_key, ' +
    '  :action_keys, :conditions, :updated_at) ' +
    'ON CONFLICT(key) DO UPDATE SET ' +
    '  name=excluded.name, gate_type=excluded.gate_type, ' +
    '  parent_key=excluded.parent_key, field_key=excluded.field_key, ' +
    '  action_keys=excluded.action_keys, conditions=excluded.conditions, ' +
    '  updated_at=excluded.updated_at';
var
  LQ: TFDQuery;
  LArr: TJSONArray;
  LKey: string;
begin
  if (AConn = nil) or (AGate = nil) then Exit;
  LQ := TFDQuery.Create(nil);
  try
    LQ.Connection := AConn;
    LQ.SQL.Text := SQL;
    LQ.ParamByName('key').AsString := AGate.Key;
    LQ.ParamByName('name').AsString := AGate.DisplayName;
    LQ.ParamByName('gate_type').AsString := GateTypeToStr(AGate.GateType);
    LQ.ParamByName('parent_key').AsString := AGate.ParentKey;
    LQ.ParamByName('field_key').AsString := AGate.FieldKey;

    LArr := TJSONArray.Create;
    try
      for LKey in AGate.ActionKeys do
        LArr.Add(LKey);
      LQ.ParamByName('action_keys').AsString := LArr.ToJSON;
    finally
      LArr.Free;
    end;

    LQ.ParamByName('conditions').AsString := ConditionsToJson(AGate);
    LQ.ParamByName('updated_at').AsString := NowIso;
    LQ.ExecSQL;
  finally
    LQ.Free;
  end;
end;

procedure UpsertAction(AConn: TFDConnection; AAction: TAction);
const
  SQL =
    'INSERT INTO governance_actions (key, name, display_name, risk_level, gate_key, ' +
    '  due_ref, purpose_key, bridge_keys, updated_at) ' +
    'VALUES (:key, :name, :display_name, :risk_level, :gate_key, ' +
    '  :due_ref, :purpose_key, :bridge_keys, :updated_at) ' +
    'ON CONFLICT(key) DO UPDATE SET ' +
    '  name=excluded.name, display_name=excluded.display_name, ' +
    '  risk_level=excluded.risk_level, gate_key=excluded.gate_key, ' +
    '  due_ref=excluded.due_ref, purpose_key=excluded.purpose_key, ' +
    '  bridge_keys=excluded.bridge_keys, updated_at=excluded.updated_at';
var
  LQ: TFDQuery;
  LArr: TJSONArray;
  LKey: string;
begin
  if (AConn = nil) or (AAction = nil) then Exit;
  LQ := TFDQuery.Create(nil);
  try
    LQ.Connection := AConn;
    LQ.SQL.Text := SQL;
    LQ.ParamByName('key').AsString := AAction.Key;
    LQ.ParamByName('name').AsString := AAction.DisplayName;
    LQ.ParamByName('display_name').AsString := AAction.DisplayName;
    LQ.ParamByName('risk_level').AsString := RiskToStr(AAction.RiskLevel);
    LQ.ParamByName('gate_key').AsString := AAction.GateKey;
    LQ.ParamByName('due_ref').AsString := AAction.DueRef;
    LQ.ParamByName('purpose_key').AsString := AAction.PurposeKey;

    LArr := TJSONArray.Create;
    try
      for LKey in AAction.BridgeKeys do
        LArr.Add(LKey);
      LQ.ParamByName('bridge_keys').AsString := LArr.ToJSON;
    finally
      LArr.Free;
    end;

    LQ.ParamByName('updated_at').AsString := NowIso;
    LQ.ExecSQL;
  finally
    LQ.Free;
  end;
end;

// ============================================================================
// Loaders
// ============================================================================

procedure LoadAllPurposes(AConn: TFDConnection; APurposeSet: TPurposeSet);
var
  LQ: TFDQuery;
  LPurpose: TPurpose;
begin
  if (AConn = nil) or (APurposeSet = nil) then Exit;
  LQ := TFDQuery.Create(nil);
  try
    LQ.Connection := AConn;
    LQ.SQL.Text := 'SELECT key, name, description, parent_key, status FROM governance_purposes';
    LQ.Open;
    while not LQ.Eof do
    begin
      LPurpose := TPurpose.Create(
        LQ.FieldByName('key').AsString,
        LQ.FieldByName('name').AsString,
        LQ.FieldByName('description').AsString,
        LQ.FieldByName('parent_key').AsString);
      LPurpose.Status := LQ.FieldByName('status').AsString;
      APurposeSet.Register(LPurpose);
      LQ.Next;
    end;
  finally
    LQ.Free;
  end;
end;

procedure LoadAllFields(AConn: TFDConnection; AKeyResolver: TKeyResolver);
var
  LQ: TFDQuery;
begin
  if (AConn = nil) or (AKeyResolver = nil) then Exit;
  LQ := TFDQuery.Create(nil);
  try
    LQ.Connection := AConn;
    LQ.SQL.Text := 'SELECT key, name, description FROM governance_fields';
    LQ.Open;
    while not LQ.Eof do
    begin
      AKeyResolver.RegisterField(TContextField.Create(
        LQ.FieldByName('key').AsString,
        LQ.FieldByName('name').AsString,
        LQ.FieldByName('description').AsString));
      LQ.Next;
    end;
  finally
    LQ.Free;
  end;
end;

procedure LoadAllGates(AConn: TFDConnection; AKeyResolver: TKeyResolver);
var
  LQ: TFDQuery;
  LGate: TAccessGate;
  LActions, LCondArr: TJSONValue;
  LObj: TJSONObject;
  LList: TJSONArray;
  I: Integer;
begin
  if (AConn = nil) or (AKeyResolver = nil) then Exit;
  LQ := TFDQuery.Create(nil);
  try
    LQ.Connection := AConn;
    LQ.SQL.Text :=
      'SELECT key, name, gate_type, parent_key, field_key, action_keys, conditions ' +
      'FROM governance_gates';
    LQ.Open;
    while not LQ.Eof do
    begin
      LGate := TAccessGate.Create(
        LQ.FieldByName('key').AsString,
        LQ.FieldByName('name').AsString,
        StrToGateType(LQ.FieldByName('gate_type').AsString),
        LQ.FieldByName('parent_key').AsString,
        LQ.FieldByName('field_key').AsString);

      // Parse action_keys JSON
      LActions := TJSONObject.ParseJSONValue(LQ.FieldByName('action_keys').AsString);
      if (LActions <> nil) and (LActions is TJSONArray) then
      try
        LList := TJSONArray(LActions);
        for I := 0 to LList.Count - 1 do
          LGate.AddActionKey(LList.Items[I].Value);
      finally
        LActions.Free;
      end
      else if LActions <> nil then
        LActions.Free;

      // Parse conditions JSON
      LCondArr := TJSONObject.ParseJSONValue(LQ.FieldByName('conditions').AsString);
      if (LCondArr <> nil) and (LCondArr is TJSONArray) then
      try
        LList := TJSONArray(LCondArr);
        for I := 0 to LList.Count - 1 do
        begin
          LObj := LList.Items[I] as TJSONObject;
          LGate.AddCondition(TGateCondition.Create(
            StrToCondKind(LObj.GetValue<string>('kind', 'state')),
            LObj.GetValue<string>('expression', 'true'),
            LObj.GetValue<string>('description', ''),
            LObj.GetValue<string>('blocked_message', '')));
        end;
      finally
        LCondArr.Free;
      end
      else if LCondArr <> nil then
        LCondArr.Free;

      AKeyResolver.RegisterGate(LGate);
      LQ.Next;
    end;
  finally
    LQ.Free;
  end;
end;

procedure LoadAllActions(AConn: TFDConnection; AKeyResolver: TKeyResolver;
  ADueChecker: TDueChecker);
var
  LQ: TFDQuery;
  LAction: TAction;
  LBridges: TJSONValue;
  LList: TJSONArray;
  LKey: string;
  I: Integer;
begin
  if (AConn = nil) or (AKeyResolver = nil) then Exit;
  LQ := TFDQuery.Create(nil);
  try
    LQ.Connection := AConn;
    LQ.SQL.Text :=
      'SELECT key, name, display_name, risk_level, gate_key, due_ref, purpose_key, bridge_keys ' +
      'FROM governance_actions';
    LQ.Open;
    while not LQ.Eof do
    begin
      LAction := TAction.Create(
        LQ.FieldByName('key').AsString,
        LQ.FieldByName('display_name').AsString,
        StrToRisk(LQ.FieldByName('risk_level').AsString),
        LQ.FieldByName('gate_key').AsString,
        LQ.FieldByName('due_ref').AsString,
        LQ.FieldByName('purpose_key').AsString);

      LBridges := TJSONObject.ParseJSONValue(LQ.FieldByName('bridge_keys').AsString);
      if (LBridges <> nil) and (LBridges is TJSONArray) then
      try
        LList := TJSONArray(LBridges);
        for I := 0 to LList.Count - 1 do
        begin
          LKey := LList.Items[I].Value;
          LAction.AddBridgeKey(LKey);
          AKeyResolver.RegisterBridgeKey(LKey);
        end;
      finally
        LBridges.Free;
      end
      else if LBridges <> nil then
        LBridges.Free;

      AKeyResolver.RegisterAction(LAction);

      if (ADueChecker <> nil) and (LAction.DueRef <> '') then
        ADueChecker.AutoRegisterFromAction(LAction);

      LQ.Next;
    end;
  finally
    LQ.Free;
  end;
end;

end.
