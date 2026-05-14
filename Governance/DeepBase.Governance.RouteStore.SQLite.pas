// AI-GENERATED
// DeepBase.Governance.RouteStore.SQLite.pas
// 第五层：RouteRule 表 CRUD + 版本管理（SQLite）
// 依赖 Persistence + Model

unit DeepBase.Governance.RouteStore.SQLite;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Data.DB,
  FireDAC.Comp.Client,
  FireDAC.Stan.Param,
  DeepBase.Governance.Types,
  DeepBase.Governance.Model;

type
  TRouteStoreSQLite = class
  private
    FConnection: TFDConnection;
    FOwnsConnection: Boolean;
    procedure EnsureTable;
    function TargetTypeToStr(AType: TRouteTargetType): string;
    function StrToTargetType(const AStr: string): TRouteTargetType;
    function RiskLevelToStr(ALevel: TRiskLevel): string;
    function StrToRiskLevel(const AStr: string): TRiskLevel;
  public
    constructor Create(AConnection: TFDConnection; AOwnsConnection: Boolean = False);
    destructor Destroy; override;

    // CRUD
    procedure Save(ARule: TRouteRule);
    procedure Delete(const AId: string);
    function LoadById(const AId: string): TRouteRule;
    function LoadBySource(const ASourceGateKey: string): TObjectList<TRouteRule>;
    function LoadAll: TObjectList<TRouteRule>;

    // 版本管理
    function GetLatestVersion(const ASourceGateKey: string): Integer;
    procedure ExpireRule(const AId: string);

    // 统计
    function Count: Integer;
  end;

implementation

uses
  System.DateUtils;

const
  SQL_CREATE_TABLE =
    'CREATE TABLE IF NOT EXISTS governance_route_rules (' +
    '  id TEXT PRIMARY KEY,' +
    '  source_gate_key TEXT NOT NULL,' +
    '  condition_expr TEXT NOT NULL,' +
    '  target_type TEXT NOT NULL,' +
    '  target_key TEXT NOT NULL,' +
    '  priority INTEGER DEFAULT 0,' +
    '  fallback_target TEXT,' +
    '  version INTEGER NOT NULL DEFAULT 1,' +
    '  effective_from TEXT NOT NULL,' +
    '  expired_at TEXT,' +
    '  risk_level TEXT DEFAULT ''L0'',' +
    '  enabled INTEGER DEFAULT 1,' +
    '  created_by TEXT,' +
    '  approved_by TEXT,' +
    '  tags TEXT,' +
    '  description TEXT,' +
    '  created_at TEXT NOT NULL' +
    ')';

  SQL_CREATE_INDEX =
    'CREATE INDEX IF NOT EXISTS idx_route_source ON ' +
    'governance_route_rules(source_gate_key, enabled, priority DESC)';

  SQL_INSERT =
    'INSERT OR REPLACE INTO governance_route_rules ' +
    '(id, source_gate_key, condition_expr, target_type, target_key, ' +
    'priority, fallback_target, version, effective_from, expired_at, ' +
    'risk_level, enabled, created_by, approved_by, tags, description, created_at) ' +
    'VALUES (:id, :source_gate_key, :condition_expr, :target_type, :target_key, ' +
    ':priority, :fallback_target, :version, :effective_from, :expired_at, ' +
    ':risk_level, :enabled, :created_by, :approved_by, :tags, :description, :created_at)';

  SQL_DELETE = 'DELETE FROM governance_route_rules WHERE id = :id';

  SQL_LOAD_BY_ID = 'SELECT * FROM governance_route_rules WHERE id = :id';

  SQL_LOAD_BY_SOURCE =
    'SELECT * FROM governance_route_rules WHERE source_gate_key = :source ' +
    'AND enabled = 1 ORDER BY priority DESC';

  SQL_LOAD_ALL = 'SELECT * FROM governance_route_rules ORDER BY source_gate_key, priority DESC';

  SQL_MAX_VERSION =
    'SELECT MAX(version) FROM governance_route_rules WHERE source_gate_key = :source';

  SQL_EXPIRE =
    'UPDATE governance_route_rules SET expired_at = :expired_at WHERE id = :id';

  SQL_COUNT = 'SELECT COUNT(*) FROM governance_route_rules';

{ TRouteStoreSQLite }

constructor TRouteStoreSQLite.Create(AConnection: TFDConnection;
  AOwnsConnection: Boolean);
begin
  inherited Create;
  FConnection := AConnection;
  FOwnsConnection := AOwnsConnection;
  EnsureTable;
end;

destructor TRouteStoreSQLite.Destroy;
begin
  if FOwnsConnection then
    FConnection.Free;
  inherited;
end;

procedure TRouteStoreSQLite.EnsureTable;
begin
  FConnection.ExecSQL(SQL_CREATE_TABLE);
  FConnection.ExecSQL(SQL_CREATE_INDEX);
end;

function TRouteStoreSQLite.TargetTypeToStr(AType: TRouteTargetType): string;
begin
  case AType of
    rttAction: Result := 'action';
    rttGate:   Result := 'gate';
    rttField:  Result := 'field';
  else
    Result := 'action';
  end;
end;

function TRouteStoreSQLite.StrToTargetType(const AStr: string): TRouteTargetType;
begin
  if AStr = 'gate' then Result := rttGate
  else if AStr = 'field' then Result := rttField
  else Result := rttAction;
end;

function TRouteStoreSQLite.RiskLevelToStr(ALevel: TRiskLevel): string;
begin
  case ALevel of
    rlL0: Result := 'L0';
    rlL1: Result := 'L1';
    rlL2: Result := 'L2';
    rlL3: Result := 'L3';
  else
    Result := 'L0';
  end;
end;

function TRouteStoreSQLite.StrToRiskLevel(const AStr: string): TRiskLevel;
begin
  if AStr = 'L1' then Result := rlL1
  else if AStr = 'L2' then Result := rlL2
  else if AStr = 'L3' then Result := rlL3
  else Result := rlL0;
end;

procedure TRouteStoreSQLite.Save(ARule: TRouteRule);
var
  LQuery: TFDQuery;
begin
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := SQL_INSERT;
    LQuery.ParamByName('id').AsString := ARule.Id;
    LQuery.ParamByName('source_gate_key').AsString := ARule.SourceGateKey;
    LQuery.ParamByName('condition_expr').AsString := ARule.ConditionExpr;
    LQuery.ParamByName('target_type').AsString := TargetTypeToStr(ARule.TargetType);
    LQuery.ParamByName('target_key').AsString := ARule.TargetKey;
    LQuery.ParamByName('priority').AsInteger := ARule.Priority;
    LQuery.ParamByName('fallback_target').AsString := ARule.FallbackTarget;
    LQuery.ParamByName('version').AsInteger := ARule.Version;
    LQuery.ParamByName('effective_from').AsString := DateToISO8601(ARule.EffectiveFrom);
    if ARule.ExpiredAt > 0 then
      LQuery.ParamByName('expired_at').AsString := DateToISO8601(ARule.ExpiredAt)
    else
      LQuery.ParamByName('expired_at').Clear;
    LQuery.ParamByName('risk_level').AsString := RiskLevelToStr(ARule.RiskLevel);
    LQuery.ParamByName('enabled').AsInteger := Ord(ARule.Enabled);
    LQuery.ParamByName('created_by').AsString := ARule.CreatedBy;
    LQuery.ParamByName('approved_by').AsString := ARule.ApprovedBy;
    LQuery.ParamByName('tags').AsString := ARule.Tags;
    LQuery.ParamByName('description').AsString := ARule.Description;
    LQuery.ParamByName('created_at').AsString := DateToISO8601(Now);
    LQuery.ExecSQL;
  finally
    LQuery.Free;
  end;
end;

procedure TRouteStoreSQLite.Delete(const AId: string);
var
  LQuery: TFDQuery;
begin
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := SQL_DELETE;
    LQuery.ParamByName('id').AsString := AId;
    LQuery.ExecSQL;
  finally
    LQuery.Free;
  end;
end;

function TRouteStoreSQLite.LoadById(const AId: string): TRouteRule;
var
  LQuery: TFDQuery;
begin
  Result := nil;
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := SQL_LOAD_BY_ID;
    LQuery.ParamByName('id').AsString := AId;
    LQuery.Open;
    if not LQuery.Eof then
    begin
      Result := TRouteRule.Create(
        LQuery.FieldByName('id').AsString,
        LQuery.FieldByName('source_gate_key').AsString,
        LQuery.FieldByName('condition_expr').AsString,
        StrToTargetType(LQuery.FieldByName('target_type').AsString),
        LQuery.FieldByName('target_key').AsString,
        LQuery.FieldByName('priority').AsInteger);
      Result.Version := LQuery.FieldByName('version').AsInteger;
      Result.RiskLevel := StrToRiskLevel(LQuery.FieldByName('risk_level').AsString);
      Result.Enabled := LQuery.FieldByName('enabled').AsInteger = 1;
      Result.CreatedBy := LQuery.FieldByName('created_by').AsString;
      Result.ApprovedBy := LQuery.FieldByName('approved_by').AsString;
      Result.Tags := LQuery.FieldByName('tags').AsString;
      Result.Description := LQuery.FieldByName('description').AsString;
    end;
  finally
    LQuery.Free;
  end;
end;

function TRouteStoreSQLite.LoadBySource(
  const ASourceGateKey: string): TObjectList<TRouteRule>;
var
  LQuery: TFDQuery;
  LRule: TRouteRule;
begin
  Result := TObjectList<TRouteRule>.Create(True);
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := SQL_LOAD_BY_SOURCE;
    LQuery.ParamByName('source').AsString := ASourceGateKey;
    LQuery.Open;
    while not LQuery.Eof do
    begin
      LRule := TRouteRule.Create(
        LQuery.FieldByName('id').AsString,
        LQuery.FieldByName('source_gate_key').AsString,
        LQuery.FieldByName('condition_expr').AsString,
        StrToTargetType(LQuery.FieldByName('target_type').AsString),
        LQuery.FieldByName('target_key').AsString,
        LQuery.FieldByName('priority').AsInteger);
      LRule.Version := LQuery.FieldByName('version').AsInteger;
      LRule.Enabled := LQuery.FieldByName('enabled').AsInteger = 1;
      Result.Add(LRule);
      LQuery.Next;
    end;
  finally
    LQuery.Free;
  end;
end;

function TRouteStoreSQLite.LoadAll: TObjectList<TRouteRule>;
var
  LQuery: TFDQuery;
  LRule: TRouteRule;
begin
  Result := TObjectList<TRouteRule>.Create(True);
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := SQL_LOAD_ALL;
    LQuery.Open;
    while not LQuery.Eof do
    begin
      LRule := TRouteRule.Create(
        LQuery.FieldByName('id').AsString,
        LQuery.FieldByName('source_gate_key').AsString,
        LQuery.FieldByName('condition_expr').AsString,
        StrToTargetType(LQuery.FieldByName('target_type').AsString),
        LQuery.FieldByName('target_key').AsString,
        LQuery.FieldByName('priority').AsInteger);
      Result.Add(LRule);
      LQuery.Next;
    end;
  finally
    LQuery.Free;
  end;
end;

function TRouteStoreSQLite.GetLatestVersion(const ASourceGateKey: string): Integer;
var
  LQuery: TFDQuery;
begin
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := SQL_MAX_VERSION;
    LQuery.ParamByName('source').AsString := ASourceGateKey;
    LQuery.Open;
    if LQuery.Fields[0].IsNull then
      Result := 0
    else
      Result := LQuery.Fields[0].AsInteger;
  finally
    LQuery.Free;
  end;
end;

procedure TRouteStoreSQLite.ExpireRule(const AId: string);
var
  LQuery: TFDQuery;
begin
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := SQL_EXPIRE;
    LQuery.ParamByName('expired_at').AsString := DateToISO8601(Now);
    LQuery.ParamByName('id').AsString := AId;
    LQuery.ExecSQL;
  finally
    LQuery.Free;
  end;
end;

function TRouteStoreSQLite.Count: Integer;
var
  LQuery: TFDQuery;
begin
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := SQL_COUNT;
    LQuery.Open;
    Result := LQuery.Fields[0].AsInteger;
  finally
    LQuery.Free;
  end;
end;

end.
