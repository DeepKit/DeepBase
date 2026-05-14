// AI-GENERATED
// DeepBase.Governance.EvidenceStore.SQLite.pas
// 第五层：Evidence 表 CRUD（SQLite）
// 依赖 Persistence + EvidenceRecorder

unit DeepBase.Governance.EvidenceStore.SQLite;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.Classes,
  Data.DB,
  FireDAC.Comp.Client,
  FireDAC.Stan.Param,
  DeepBase.Governance.Types,
  DeepBase.Governance.EvidenceRecorder;

type
  TEvidenceStoreSQLite = class(TInterfacedObject, IEvidenceStore)
  private
    FConnection: TFDConnection;
    FOwnsConnection: Boolean;
    procedure EnsureTable;
    function RiskLevelToStr(ALevel: TRiskLevel): string;
    function StrToRiskLevel(const AStr: string): TRiskLevel;
    function EvidenceResultToStr(AResult: TEvidenceResult): string;
    function StrToEvidenceResult(const AStr: string): TEvidenceResult;
  public
    constructor Create(AConnection: TFDConnection; AOwnsConnection: Boolean = False);
    destructor Destroy; override;

    // IEvidenceStore
    procedure Save(const AEntry: TEvidenceEntry);
    function Query(const AActionKey: string; ALimit: Integer): TArray<TEvidenceEntry>;

    // 扩展查询
    function QueryByUser(const AUserId: string; ALimit: Integer): TArray<TEvidenceEntry>;
    function Count: Integer;
  end;

implementation

uses
  System.DateUtils;

const
  SQL_CREATE_TABLE =
    'CREATE TABLE IF NOT EXISTS governance_evidence (' +
    '  id TEXT PRIMARY KEY,' +
    '  schema_version INTEGER NOT NULL DEFAULT 1,' +
    '  correlation_id TEXT,' +
    '  timestamp TEXT NOT NULL,' +
    '  user_id TEXT,' +
    '  action_key TEXT NOT NULL,' +
    '  risk_level TEXT NOT NULL,' +
    '  gate_path TEXT,' +
    '  input_summary TEXT,' +
    '  output_summary TEXT,' +
    '  result TEXT NOT NULL,' +
    '  blocked_reason TEXT,' +
    '  snapshot_data TEXT,' +
    '  created_at TEXT NOT NULL' +
    ')';

  SQL_CREATE_INDEX_ACTION =
    'CREATE INDEX IF NOT EXISTS idx_evidence_action ON governance_evidence(action_key, timestamp)';

  SQL_CREATE_INDEX_USER =
    'CREATE INDEX IF NOT EXISTS idx_evidence_user ON governance_evidence(user_id, timestamp)';

  SQL_CREATE_INDEX_CORRELATION =
    'CREATE INDEX IF NOT EXISTS idx_evidence_correlation ON governance_evidence(correlation_id)';

  SQL_INSERT =
    'INSERT INTO governance_evidence (id, schema_version, correlation_id, timestamp, user_id, action_key, ' +
    'risk_level, gate_path, input_summary, output_summary, result, ' +
    'blocked_reason, snapshot_data, created_at) VALUES ' +
    '(:id, :schema_version, :correlation_id, :timestamp, :user_id, :action_key, :risk_level, :gate_path, ' +
    ':input_summary, :output_summary, :result, :blocked_reason, ' +
    ':snapshot_data, :created_at)';

  SQL_QUERY_BY_ACTION =
    'SELECT * FROM governance_evidence WHERE action_key = :action_key ' +
    'ORDER BY timestamp DESC LIMIT :limit';

  SQL_QUERY_BY_USER =
    'SELECT * FROM governance_evidence WHERE user_id = :user_id ' +
    'ORDER BY timestamp DESC LIMIT :limit';

  SQL_COUNT =
    'SELECT COUNT(*) FROM governance_evidence';

{ TEvidenceStoreSQLite }

constructor TEvidenceStoreSQLite.Create(AConnection: TFDConnection;
  AOwnsConnection: Boolean);
begin
  inherited Create;
  FConnection := AConnection;
  FOwnsConnection := AOwnsConnection;
  EnsureTable;
end;

destructor TEvidenceStoreSQLite.Destroy;
begin
  if FOwnsConnection then
    FConnection.Free;
  inherited;
end;

procedure TEvidenceStoreSQLite.EnsureTable;
begin
  FConnection.ExecSQL(SQL_CREATE_TABLE);
  FConnection.ExecSQL(SQL_CREATE_INDEX_ACTION);
  FConnection.ExecSQL(SQL_CREATE_INDEX_USER);
  FConnection.ExecSQL(SQL_CREATE_INDEX_CORRELATION);
end;

function TEvidenceStoreSQLite.RiskLevelToStr(ALevel: TRiskLevel): string;
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

function TEvidenceStoreSQLite.StrToRiskLevel(const AStr: string): TRiskLevel;
begin
  if AStr = 'L1' then Result := rlL1
  else if AStr = 'L2' then Result := rlL2
  else if AStr = 'L3' then Result := rlL3
  else Result := rlL0;
end;

function TEvidenceStoreSQLite.EvidenceResultToStr(AResult: TEvidenceResult): string;
begin
  case AResult of
    erSuccess: Result := 'success';
    erFail:    Result := 'fail';
    erBlocked: Result := 'blocked';
  else
    Result := 'success';
  end;
end;

function TEvidenceStoreSQLite.StrToEvidenceResult(const AStr: string): TEvidenceResult;
begin
  if AStr = 'fail' then Result := erFail
  else if AStr = 'blocked' then Result := erBlocked
  else Result := erSuccess;
end;

procedure TEvidenceStoreSQLite.Save(const AEntry: TEvidenceEntry);
var
  LQuery: TFDQuery;
begin
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := SQL_INSERT;
    LQuery.ParamByName('id').AsString := AEntry.Id;
    LQuery.ParamByName('schema_version').AsInteger := AEntry.SchemaVersion;
    LQuery.ParamByName('correlation_id').AsString := AEntry.CorrelationId;
    LQuery.ParamByName('timestamp').AsString := DateToISO8601(AEntry.Timestamp);
    LQuery.ParamByName('user_id').AsString := AEntry.UserId;
    LQuery.ParamByName('action_key').AsString := AEntry.ActionKey;
    LQuery.ParamByName('risk_level').AsString := RiskLevelToStr(AEntry.RiskLevel);
    LQuery.ParamByName('gate_path').AsString := AEntry.GatePath;
    LQuery.ParamByName('input_summary').AsString := AEntry.InputSummary;
    LQuery.ParamByName('output_summary').AsString := AEntry.OutputSummary;
    LQuery.ParamByName('result').AsString := EvidenceResultToStr(AEntry.Result);
    LQuery.ParamByName('blocked_reason').AsString := AEntry.BlockedReason;
    LQuery.ParamByName('snapshot_data').AsString := AEntry.SnapshotData;
    LQuery.ParamByName('created_at').AsString := DateToISO8601(Now);
    LQuery.ExecSQL;
  finally
    LQuery.Free;
  end;
end;

function TEvidenceStoreSQLite.Query(const AActionKey: string;
  ALimit: Integer): TArray<TEvidenceEntry>;
var
  LQuery: TFDQuery;
  LList: TList<TEvidenceEntry>;
  LEntry: TEvidenceEntry;
begin
  LList := TList<TEvidenceEntry>.Create;
  try
    LQuery := TFDQuery.Create(nil);
    try
      LQuery.Connection := FConnection;
      LQuery.SQL.Text := SQL_QUERY_BY_ACTION;
      LQuery.ParamByName('action_key').AsString := AActionKey;
      LQuery.ParamByName('limit').AsInteger := ALimit;
      LQuery.Open;

      while not LQuery.Eof do
      begin
        LEntry.Id := LQuery.FieldByName('id').AsString;
        LEntry.SchemaVersion := LQuery.FieldByName('schema_version').AsInteger;
        LEntry.CorrelationId := LQuery.FieldByName('correlation_id').AsString;
        LEntry.Timestamp := ISO8601ToDate(LQuery.FieldByName('timestamp').AsString);
        LEntry.UserId := LQuery.FieldByName('user_id').AsString;
        LEntry.ActionKey := LQuery.FieldByName('action_key').AsString;
        LEntry.RiskLevel := StrToRiskLevel(LQuery.FieldByName('risk_level').AsString);
        LEntry.GatePath := LQuery.FieldByName('gate_path').AsString;
        LEntry.InputSummary := LQuery.FieldByName('input_summary').AsString;
        LEntry.OutputSummary := LQuery.FieldByName('output_summary').AsString;
        LEntry.Result := StrToEvidenceResult(LQuery.FieldByName('result').AsString);
        LEntry.BlockedReason := LQuery.FieldByName('blocked_reason').AsString;
        LEntry.SnapshotData := LQuery.FieldByName('snapshot_data').AsString;
        LList.Add(LEntry);
        LQuery.Next;
      end;
    finally
      LQuery.Free;
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TEvidenceStoreSQLite.QueryByUser(const AUserId: string;
  ALimit: Integer): TArray<TEvidenceEntry>;
var
  LQuery: TFDQuery;
  LList: TList<TEvidenceEntry>;
  LEntry: TEvidenceEntry;
begin
  LList := TList<TEvidenceEntry>.Create;
  try
    LQuery := TFDQuery.Create(nil);
    try
      LQuery.Connection := FConnection;
      LQuery.SQL.Text := SQL_QUERY_BY_USER;
      LQuery.ParamByName('user_id').AsString := AUserId;
      LQuery.ParamByName('limit').AsInteger := ALimit;
      LQuery.Open;

      while not LQuery.Eof do
      begin
        LEntry.Id := LQuery.FieldByName('id').AsString;
        LEntry.UserId := LQuery.FieldByName('user_id').AsString;
        LEntry.ActionKey := LQuery.FieldByName('action_key').AsString;
        LEntry.Result := StrToEvidenceResult(LQuery.FieldByName('result').AsString);
        LList.Add(LEntry);
        LQuery.Next;
      end;
    finally
      LQuery.Free;
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TEvidenceStoreSQLite.Count: Integer;
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
