// AI-GENERATED
// DeepBase.Governance.ReviewQueue.SQLite.pas
// ASY-GOV-006 阶段2：主权 review queue 的 SQLite 实现。
// 两张表：
//   review_challenges —— 裁决挑战，挂 HMAC-SHA256 线性哈希链（防内容篡改）。
//   human_decisions    —— 人工决策记录，裁决落定时写入并把 challenge 状态推进。
// 设计要点：
//   - challenge 行的 hash 绑定"挑战内容快照"（action_intent/summaries/digest/expires），
//     不含 Status——状态变更是被审计的关键事件，其审计落在 human_decisions 表 +
//     evidence 链（RecordDecision 同时写 decision 行 + 原子 UPDATE challenge 状态），
//     challenge 的 hash 链只防"挑战内容被静默篡改"（如改 parameters_digest 绕过授权）。
//     二者正交。
//   - 状态机用原子 UPDATE ... WHERE status='pending' 防并发双重裁决（fail-closed）。
//   - 数组列（allowed_decisions/authorization_scopes/evidence_refs）用 JSON 数组存 TEXT。
// 依赖 Persistence（TFDConnection）+ Crypto.Hash/Encoding（HMAC 原语）+ ReviewQueue 契约。
// 范本：DeepBase.Governance.EvidenceStore.SQLite.pas（hash 链 + FLock + EnsureTable）。

unit DeepBase.Governance.ReviewQueue.SQLite;

interface

uses
  System.SysUtils,
  System.Classes,
  Data.DB,
  FireDAC.Comp.Client,
  FireDAC.Stan.Param,
  DeepBase.Governance.ReviewQueue;

type
  TReviewQueueSQLite = class(TInterfacedObject, IReviewQueue)
  private
    FConnection: TFDConnection;
    FOwnsConnection: Boolean;
    FHmacKey: TBytes;
    FLock: TObject;
    FChainInitialized: Boolean;
    FLastChainHash: string;
    procedure EnsureTable;
    procedure MigrateExecutedAtColumn;
    procedure InitializeChainState;
    function GetLastHash: string;
    function ComputePayload(const AChallenge: TReviewChallenge): string;
    /// <summary>同 ComputePayload，但 expires_at 用存储列原始字符串，避免
    /// TDateTime↔ISO8601 往返精度差异导致 VerifyChain 误判未篡改行为破损。</summary>
    function ComputePayloadRaw(const AChallenge: TReviewChallenge;
      const ARawExpiresAt: string): string;
    function ComputeHash(const ATimestamp, APayload, APrevHash: string): string;
    function StatusToStr(AStatus: TReviewStatus): string;
    function StrToStatus(const AStr: string): TReviewStatus;
    function DecisionToStr(ADecision: TReviewDecision): string;
    function StrToDecision(const AStr: string): TReviewDecision;
    function ScopeToStr(AScope: TAuthorizationScope): string;
    function StrToScope(const AStr: string): TAuthorizationScope;
    function ArrayToJson(const AItems: TArray<string>): string;
    function JsonToArray(const AJson: string): TArray<string>;
    procedure ReadChallengeRow(AQuery: TFDQuery; out AChallenge: TReviewChallenge);
    procedure ReadDecisionRow(AQuery: TFDQuery; out ADecision: THumanDecision);
  public
    constructor Create(AConnection: TFDConnection;
      const AHmacKey: TBytes; AOwnsConnection: Boolean = False);
    destructor Destroy; override;
    // IReviewQueue
    function CreateChallenge(const AChallenge: TReviewChallenge): TReviewChallenge;
    function RecordDecision(const ADecision: THumanDecision): Boolean;
    function GetChallenge(const AReviewId: string; out AChallenge: TReviewChallenge): Boolean;
    function QueryByIntent(const AActionIntentId: string): TArray<TReviewChallenge>;
    function QueryPending: TArray<TReviewChallenge>;
    function GetDecision(const ADecisionId: string; out ADecision: THumanDecision): Boolean;
    function ExpireOverdue: Integer;
    function VerifyChain(out ABrokenCount, ATotalRows: Integer): Boolean;
    function Count: Integer;
    function MarkExecuted(const AReviewId: string;
      out AOutChallenge: TReviewChallenge): Boolean;
    function IsExecuted(const AReviewId: string): Boolean;
  end;

implementation

uses
  System.DateUtils,
  System.SyncObjs,
  System.JSON,
  DeepBase.Crypto, DeepBase.Crypto.Hash, DeepBase.Crypto.Encoding;

const
  /// 创世哈希（用于第一行 challenge 的 prev_hash）。与 evidence 链同值。
  GENESIS_HASH =
    '0000000000000000000000000000000000000000000000000000000000000000';

  SQL_CREATE_CHALLENGES =
    'CREATE TABLE IF NOT EXISTS review_challenges (' +
    '  review_id TEXT PRIMARY KEY,' +
    '  action_intent_id TEXT NOT NULL,' +
    '  decision_id TEXT,' +
    '  action_summary TEXT NOT NULL,' +
    '  target_summary TEXT NOT NULL,' +
    '  impact TEXT NOT NULL,' +
    '  reversibility TEXT NOT NULL,' +
    '  parameters_digest TEXT NOT NULL,' +
    '  allowed_decisions TEXT,' +            // JSON 数组
    '  authorization_scopes TEXT,' +          // JSON 数组
    '  evidence_refs TEXT,' +                 // JSON 数组
    '  expires_at TEXT NOT NULL,' +
    '  status TEXT NOT NULL DEFAULT ''pending'',' +
    '  created_at TEXT NOT NULL,' +
    '  updated_at TEXT NOT NULL,' +
    '  prev_hash TEXT,' +
    '  this_hash TEXT,' +
    '  executed_at TEXT)';  // ASY-GOV-006 阶段3：asOnce 消费时刻；NULL=未执行（防重放）

  SQL_CREATE_CHALLENGES_INDEX =
    'CREATE INDEX IF NOT EXISTS idx_review_challenges_intent ' +
    'ON review_challenges(action_intent_id)';

  SQL_CREATE_CHALLENGES_STATUS_INDEX =
    'CREATE INDEX IF NOT EXISTS idx_review_challenges_status ' +
    'ON review_challenges(status)';

  SQL_CREATE_DECISIONS =
    'CREATE TABLE IF NOT EXISTS human_decisions (' +
    '  human_decision_id TEXT PRIMARY KEY,' +
    '  review_id TEXT NOT NULL,' +
    '  action_intent_id TEXT NOT NULL,' +
    '  actor_id TEXT NOT NULL,' +
    '  decision TEXT NOT NULL,' +
    '  authorization_scope TEXT NOT NULL,' +
    '  parameters_digest TEXT NOT NULL,' +
    '  decided_at TEXT NOT NULL,' +
    '  expires_at TEXT)';

  SQL_CREATE_DECISIONS_REVIEW_INDEX =
    'CREATE INDEX IF NOT EXISTS idx_human_decisions_review ' +
    'ON human_decisions(review_id)';

  // ASY-GOV-006 阶段3：executed_at 列迁移（旧库无此列）。ALTER 无 IF NOT EXISTS，
  // 靠捕获 EDatabaseError 兼容重复迁移（与 EvidenceStore.MigrateHashColumns 同模式）。
  SQL_ALTER_EXECUTED_AT =
    'ALTER TABLE review_challenges ADD COLUMN executed_at TEXT';

  // 原子消费：仅当 executed_at IS NULL 时写入，防 asOnce 重放。
  SQL_MARK_EXECUTED =
    'UPDATE review_challenges SET executed_at = :executed_at, ' +
    'updated_at = :updated_at WHERE review_id = :review_id ' +
    'AND executed_at IS NULL';

  SQL_SELECT_EXECUTED_AT =
    'SELECT executed_at FROM review_challenges WHERE review_id = :review_id';

  SQL_INSERT_CHALLENGE =
    'INSERT INTO review_challenges ' +
    '(review_id, action_intent_id, decision_id, action_summary, target_summary, ' +
    ' impact, reversibility, parameters_digest, allowed_decisions, ' +
    ' authorization_scopes, evidence_refs, expires_at, status, created_at, ' +
    ' updated_at, prev_hash, this_hash) ' +
    'VALUES (:review_id, :action_intent_id, :decision_id, :action_summary, ' +
    ' :target_summary, :impact, :reversibility, :parameters_digest, ' +
    ' :allowed_decisions, :authorization_scopes, :evidence_refs, :expires_at, ' +
    ' :status, :created_at, :updated_at, :prev_hash, :this_hash)';

  SQL_INSERT_DECISION =
    'INSERT INTO human_decisions ' +
    '(human_decision_id, review_id, action_intent_id, actor_id, decision, ' +
    ' authorization_scope, parameters_digest, decided_at, expires_at) ' +
    'VALUES (:human_decision_id, :review_id, :action_intent_id, :actor_id, ' +
    ' :decision, :authorization_scope, :parameters_digest, :decided_at, :expires_at)';

  // 原子状态推进：仅当当前 status=pending 才 UPDATE，防并发双重裁决。
  // 决策落定后 decision_id 指向真实 HumanDecision，状态推进为终态。
  SQL_ADVANCE_CHALLENGE =
    'UPDATE review_challenges SET status = :status, decision_id = :decision_id, ' +
    'updated_at = :updated_at WHERE review_id = :review_id AND status = ''pending''';

  // 过期推进：pending 且 expires_at 已过 → expired。
  SQL_EXPIRE_OVERDUE =
    'UPDATE review_challenges SET status = ''expired'', updated_at = :updated_at ' +
    'WHERE status = ''pending'' AND expires_at < :now';

  SQL_GET_CHALLENGE =
    'SELECT review_id, action_intent_id, decision_id, action_summary, target_summary, ' +
    'impact, reversibility, parameters_digest, allowed_decisions, ' +
    'authorization_scopes, evidence_refs, expires_at, status, created_at, ' +
    'updated_at, prev_hash, this_hash, executed_at ' +
    'FROM review_challenges WHERE review_id = :review_id';

  SQL_QUERY_BY_INTENT =
    'SELECT review_id, action_intent_id, decision_id, action_summary, target_summary, ' +
    'impact, reversibility, parameters_digest, allowed_decisions, ' +
    'authorization_scopes, evidence_refs, expires_at, status, created_at, ' +
    'updated_at, prev_hash, this_hash, executed_at ' +
    'FROM review_challenges WHERE action_intent_id = :action_intent_id ' +
    'ORDER BY created_at';

  SQL_QUERY_PENDING =
    'SELECT review_id, action_intent_id, decision_id, action_summary, target_summary, ' +
    'impact, reversibility, parameters_digest, allowed_decisions, ' +
    'authorization_scopes, evidence_refs, expires_at, status, created_at, ' +
    'updated_at, prev_hash, this_hash, executed_at ' +
    'FROM review_challenges WHERE status = ''pending'' ORDER BY created_at';

  SQL_GET_DECISION =
    'SELECT human_decision_id, review_id, action_intent_id, actor_id, decision, ' +
    'authorization_scope, parameters_digest, decided_at, expires_at ' +
    'FROM human_decisions WHERE human_decision_id = :human_decision_id';

  SQL_LAST_HASH =
    'SELECT this_hash FROM review_challenges ORDER BY created_at DESC LIMIT 1';

  SQL_VERIFY_CHAIN =
    'SELECT review_id, action_intent_id, action_summary, target_summary, impact, reversibility, ' +
    'parameters_digest, allowed_decisions, authorization_scopes, evidence_refs, ' +
    'expires_at, created_at, prev_hash, this_hash ' +
    'FROM review_challenges ORDER BY created_at';

  SQL_COUNT = 'SELECT COUNT(*) FROM review_challenges';

{ TReviewQueueSQLite }

constructor TReviewQueueSQLite.Create(AConnection: TFDConnection;
  const AHmacKey: TBytes; AOwnsConnection: Boolean);
begin
  inherited Create;
  FConnection := AConnection;
  FOwnsConnection := AOwnsConnection;
  FHmacKey := Copy(AHmacKey);
  FLock := TObject.Create;
  FChainInitialized := False;
  FLastChainHash := '';
  EnsureTable;
  InitializeChainState;
end;

destructor TReviewQueueSQLite.Destroy;
begin
  if FOwnsConnection then
    FConnection.Free;
  FLock.Free;
  inherited;
end;

procedure TReviewQueueSQLite.EnsureTable;
begin
  FConnection.ExecSQL(SQL_CREATE_CHALLENGES);
  FConnection.ExecSQL(SQL_CREATE_CHALLENGES_INDEX);
  FConnection.ExecSQL(SQL_CREATE_CHALLENGES_STATUS_INDEX);
  FConnection.ExecSQL(SQL_CREATE_DECISIONS);
  FConnection.ExecSQL(SQL_CREATE_DECISIONS_REVIEW_INDEX);
  MigrateExecutedAtColumn;
end;

{ ASY-GOV-006 阶段3：旧库（阶段2 建表，无 executed_at）补列。 }
procedure TReviewQueueSQLite.MigrateExecutedAtColumn;
begin
  // ALTER TABLE ADD COLUMN 无 IF NOT EXISTS（SQLite 不支持），
  // 靠捕获 EDatabaseError 兼容重复迁移（与 EvidenceStore.MigrateHashColumns 同模式）。
  try
    FConnection.ExecSQL(SQL_ALTER_EXECUTED_AT);
  except
    on E: EDatabaseError do
      ; // 列已存在，忽略
  end;
end;

procedure TReviewQueueSQLite.InitializeChainState;
begin
  System.TMonitor.Enter(FLock);
  try
    FLastChainHash := GetLastHash;
    FChainInitialized := True;
  finally
    System.TMonitor.Exit(FLock);
  end;
end;

function TReviewQueueSQLite.GetLastHash: string;
var
  LQuery: TFDQuery;
begin
  Result := GENESIS_HASH;
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := SQL_LAST_HASH;
    LQuery.Open;
    if (not LQuery.Eof) and (not LQuery.Fields[0].IsNull) and
       (LQuery.Fields[0].AsString <> '') then
      Result := LQuery.Fields[0].AsString;
  finally
    LQuery.Free;
  end;
end;

function TReviewQueueSQLite.StatusToStr(AStatus: TReviewStatus): string;
begin
  case AStatus of
    rsPending:   Result := 'pending';
    rsApproved:  Result := 'approved';
    rsRejected:  Result := 'rejected';
    rsCancelled: Result := 'cancelled';
    rsExpired:   Result := 'expired';
  else
    Result := 'pending';
  end;
end;

function TReviewQueueSQLite.StrToStatus(const AStr: string): TReviewStatus;
begin
  if AStr = 'approved' then Result := rsApproved
  else if AStr = 'rejected' then Result := rsRejected
  else if AStr = 'cancelled' then Result := rsCancelled
  else if AStr = 'expired' then Result := rsExpired
  else Result := rsPending;
end;

function TReviewQueueSQLite.DecisionToStr(ADecision: TReviewDecision): string;
begin
  case ADecision of
    rdApprove: Result := 'approve';
    rdReject:  Result := 'reject';
    rdCancel:  Result := 'cancel';
  else
    Result := 'approve';
  end;
end;

function TReviewQueueSQLite.StrToDecision(const AStr: string): TReviewDecision;
begin
  if AStr = 'reject' then Result := rdReject
  else if AStr = 'cancel' then Result := rdCancel
  else Result := rdApprove;
end;

function TReviewQueueSQLite.ScopeToStr(AScope: TAuthorizationScope): string;
begin
  case AScope of
    asOnce:      Result := 'once';
    asSession:   Result := 'session';
    asPersistent: Result := 'persistent';
  else
    Result := 'once';
  end;
end;

function TReviewQueueSQLite.StrToScope(const AStr: string): TAuthorizationScope;
begin
  if AStr = 'session' then Result := asSession
  else if AStr = 'persistent' then Result := asPersistent
  else Result := asOnce;
end;

function TReviewQueueSQLite.ArrayToJson(const AItems: TArray<string>): string;
var
  LArr: TJSONArray;
  LItem: string;
begin
  LArr := TJSONArray.Create;
  try
    for LItem in AItems do
      LArr.Add(LItem);
    Result := LArr.ToJSON;
  finally
    LArr.Free;
  end;
end;

function TReviewQueueSQLite.JsonToArray(const AJson: string): TArray<string>;
var
  LArr: TJSONArray;
  LVal: TJSONValue;
  LList: TArray<string>;
begin
  Result := nil;
  if AJson = '' then
    Exit;
  LVal := TJSONObject.ParseJSONValue(AJson);
  if not (LVal is TJSONArray) then
  begin
    LVal.Free;
    Exit;
  end;
  LArr := TJSONArray(LVal);
  try
    SetLength(LList, LArr.Count);
    var I := 0;
    for var LItem in LArr do
    begin
      LList[I] := LItem.Value;
      Inc(I);
    end;
    Result := LList;
  finally
    LArr.Free;
  end;
end;

function TReviewQueueSQLite.ComputePayload(const AChallenge: TReviewChallenge): string;
begin
  // hash 绑定"挑战内容快照"：id, intent, summaries, impact, reversibility,
  // digest, expires。不含 Status（状态变更有独立审计路径）、不含哈希列/时间戳元数据。
  // 数组列纳入 payload（JSON 形式），改 allowed_decisions 等也改变哈希。
  Result := AChallenge.ReviewId + '|' +
    AChallenge.ActionIntentId + '|' +
    AChallenge.ActionSummary + '|' +
    AChallenge.TargetSummary + '|' +
    AChallenge.Impact + '|' +
    AChallenge.Reversibility + '|' +
    AChallenge.ParametersDigest + '|' +
    DateToISO8601(AChallenge.ExpiresAt) + '|' +
    ArrayToJson(AChallenge.AllowedDecisions) + '|' +
    ArrayToJson(AChallenge.AuthorizationScopes) + '|' +
    ArrayToJson(AChallenge.EvidenceRefs);
end;

function TReviewQueueSQLite.ComputePayloadRaw(const AChallenge: TReviewChallenge;
  const ARawExpiresAt: string): string;
begin
  // 与 ComputePayload 字段顺序/分隔符严格一致，仅 expires_at 用存储列原始字符串，
  // 杜绝 ISO8601ToDate(DateToISO8601(x)) 再 DateToISO8601 的浮点往返。
  Result := AChallenge.ReviewId + '|' +
    AChallenge.ActionIntentId + '|' +
    AChallenge.ActionSummary + '|' +
    AChallenge.TargetSummary + '|' +
    AChallenge.Impact + '|' +
    AChallenge.Reversibility + '|' +
    AChallenge.ParametersDigest + '|' +
    ARawExpiresAt + '|' +
    ArrayToJson(AChallenge.AllowedDecisions) + '|' +
    ArrayToJson(AChallenge.AuthorizationScopes) + '|' +
    ArrayToJson(AChallenge.EvidenceRefs);
end;

function TReviewQueueSQLite.ComputeHash(const ATimestamp, APayload,
  APrevHash: string): string;
var
  LInput: string;
begin
  LInput := ATimestamp + APayload + APrevHash;
  if Length(FHmacKey) > 0 then
    Result := TEncodingUtils.HexEncode(
      THashUtils.HMAC(FHmacKey, TEncoding.UTF8.GetBytes(LInput), haSHA256))
  else
    Result := THashUtils.HashToHex(LInput, haSHA256);
end;

procedure TReviewQueueSQLite.ReadChallengeRow(AQuery: TFDQuery;
  out AChallenge: TReviewChallenge);
begin
  AChallenge.ReviewId := AQuery.FieldByName('review_id').AsString;
  AChallenge.ActionIntentId := AQuery.FieldByName('action_intent_id').AsString;
  AChallenge.DecisionId := AQuery.FieldByName('decision_id').AsString;
  AChallenge.ActionSummary := AQuery.FieldByName('action_summary').AsString;
  AChallenge.TargetSummary := AQuery.FieldByName('target_summary').AsString;
  AChallenge.Impact := AQuery.FieldByName('impact').AsString;
  AChallenge.Reversibility := AQuery.FieldByName('reversibility').AsString;
  AChallenge.ParametersDigest := AQuery.FieldByName('parameters_digest').AsString;
  AChallenge.AllowedDecisions := JsonToArray(AQuery.FieldByName('allowed_decisions').AsString);
  AChallenge.AuthorizationScopes := JsonToArray(AQuery.FieldByName('authorization_scopes').AsString);
  AChallenge.EvidenceRefs := JsonToArray(AQuery.FieldByName('evidence_refs').AsString);
  AChallenge.ExpiresAt := ISO8601ToDate(AQuery.FieldByName('expires_at').AsString, False);
  AChallenge.Status := StrToStatus(AQuery.FieldByName('status').AsString);
  AChallenge.CreatedAt := ISO8601ToDate(AQuery.FieldByName('created_at').AsString, False);
  AChallenge.UpdatedAt := ISO8601ToDate(AQuery.FieldByName('updated_at').AsString, False);
  AChallenge.PrevHash := AQuery.FieldByName('prev_hash').AsString;
  AChallenge.ThisHash := AQuery.FieldByName('this_hash').AsString;
  if AQuery.FieldByName('executed_at').IsNull then
    AChallenge.ExecutedAt := 0
  else
    AChallenge.ExecutedAt := ISO8601ToDate(AQuery.FieldByName('executed_at').AsString, False);
end;

procedure TReviewQueueSQLite.ReadDecisionRow(AQuery: TFDQuery;
  out ADecision: THumanDecision);
begin
  ADecision.HumanDecisionId := AQuery.FieldByName('human_decision_id').AsString;
  ADecision.ReviewId := AQuery.FieldByName('review_id').AsString;
  ADecision.ActionIntentId := AQuery.FieldByName('action_intent_id').AsString;
  ADecision.ActorId := AQuery.FieldByName('actor_id').AsString;
  ADecision.Decision := StrToDecision(AQuery.FieldByName('decision').AsString);
  ADecision.AuthorizationScope := StrToScope(AQuery.FieldByName('authorization_scope').AsString);
  ADecision.ParametersDigest := AQuery.FieldByName('parameters_digest').AsString;
  ADecision.DecidedAt := ISO8601ToDate(AQuery.FieldByName('decided_at').AsString, False);
  ADecision.ExpiresAt := ISO8601ToDate(AQuery.FieldByName('expires_at').AsString, False);
end;

function TReviewQueueSQLite.CreateChallenge(
  const AChallenge: TReviewChallenge): TReviewChallenge;
var
  LQuery: TFDQuery;
  LCreated, LExpires, LPayload, LPrevHash, LThisHash: string;
begin
  System.TMonitor.Enter(FLock);
  try
    if not FChainInitialized then
    begin
      FLastChainHash := GetLastHash;
      FChainInitialized := True;
    end;

    Result := AChallenge;
    if Result.Status = rsPending then
      ; // 默认即 pending
    Result.CreatedAt := Now;
    Result.UpdatedAt := Result.CreatedAt;

    LCreated := DateToISO8601(Result.CreatedAt);
    LExpires := DateToISO8601(Result.ExpiresAt);
    LPayload := ComputePayload(Result);
    LPrevHash := FLastChainHash;
    LThisHash := ComputeHash(LCreated, LPayload, LPrevHash);
    Result.PrevHash := LPrevHash;
    Result.ThisHash := LThisHash;

    LQuery := TFDQuery.Create(nil);
    try
      LQuery.Connection := FConnection;
      LQuery.SQL.Text := SQL_INSERT_CHALLENGE;
      LQuery.ParamByName('review_id').AsString := Result.ReviewId;
      LQuery.ParamByName('action_intent_id').AsString := Result.ActionIntentId;
      LQuery.ParamByName('decision_id').AsString := Result.DecisionId;
      LQuery.ParamByName('action_summary').AsString := Result.ActionSummary;
      LQuery.ParamByName('target_summary').AsString := Result.TargetSummary;
      LQuery.ParamByName('impact').AsString := Result.Impact;
      LQuery.ParamByName('reversibility').AsString := Result.Reversibility;
      LQuery.ParamByName('parameters_digest').AsString := Result.ParametersDigest;
      LQuery.ParamByName('allowed_decisions').AsString := ArrayToJson(Result.AllowedDecisions);
      LQuery.ParamByName('authorization_scopes').AsString := ArrayToJson(Result.AuthorizationScopes);
      LQuery.ParamByName('evidence_refs').AsString := ArrayToJson(Result.EvidenceRefs);
      LQuery.ParamByName('expires_at').AsString := LExpires;
      LQuery.ParamByName('status').AsString := StatusToStr(rsPending);
      LQuery.ParamByName('created_at').AsString := LCreated;
      LQuery.ParamByName('updated_at').AsString := LCreated;
      LQuery.ParamByName('prev_hash').AsString := LPrevHash;
      LQuery.ParamByName('this_hash').AsString := LThisHash;
      LQuery.ExecSQL;
    finally
      LQuery.Free;
    end;

    FLastChainHash := LThisHash;
  finally
    System.TMonitor.Exit(FLock);
  end;
end;

function TReviewQueueSQLite.RecordDecision(
  const ADecision: THumanDecision): Boolean;
var
  LQuery: TFDQuery;
  LTargetStatus: TReviewStatus;
  LUpdated: string;
  LAffected: Integer;
begin
  // fail-closed：仅当 challenge 仍 pending 才接受决策。
  // approve → approved；reject → rejected；cancel → cancelled。
  case ADecision.Decision of
    rdApprove: LTargetStatus := rsApproved;
    rdReject:  LTargetStatus := rsRejected;
    rdCancel:  LTargetStatus := rsCancelled;
  else
    LTargetStatus := rsApproved;
  end;

  System.TMonitor.Enter(FLock);
  try
    LUpdated := DateToISO8601(Now);

    // 先写 decision 行（独立 INSERT，decision 行无哈希链——它是 challenge
    // 状态变更的审计旁证，本身经 evidence 链的 human_decision_id 关联）。
    LQuery := TFDQuery.Create(nil);
    try
      LQuery.Connection := FConnection;
      LQuery.SQL.Text := SQL_INSERT_DECISION;
      LQuery.ParamByName('human_decision_id').AsString := ADecision.HumanDecisionId;
      LQuery.ParamByName('review_id').AsString := ADecision.ReviewId;
      LQuery.ParamByName('action_intent_id').AsString := ADecision.ActionIntentId;
      LQuery.ParamByName('actor_id').AsString := ADecision.ActorId;
      LQuery.ParamByName('decision').AsString := DecisionToStr(ADecision.Decision);
      LQuery.ParamByName('authorization_scope').AsString := ScopeToStr(ADecision.AuthorizationScope);
      LQuery.ParamByName('parameters_digest').AsString := ADecision.ParametersDigest;
      LQuery.ParamByName('decided_at').AsString := DateToISO8601(ADecision.DecidedAt);
      LQuery.ParamByName('expires_at').AsString := DateToISO8601(ADecision.ExpiresAt);
      LQuery.ExecSQL;
    finally
      LQuery.Free;
    end;

    // 原子推进 challenge 状态。WHERE status='pending' 保证并发场景下只有
    // 第一个决策生效；第二个决策因状态已非 pending 而不影响任何行 → 返回 False。
    LQuery := TFDQuery.Create(nil);
    try
      LQuery.Connection := FConnection;
      LQuery.SQL.Text := SQL_ADVANCE_CHALLENGE;
      LQuery.ParamByName('status').AsString := StatusToStr(LTargetStatus);
      LQuery.ParamByName('decision_id').AsString := ADecision.HumanDecisionId;
      LQuery.ParamByName('updated_at').AsString := LUpdated;
      LQuery.ParamByName('review_id').AsString := ADecision.ReviewId;
      LQuery.ExecSQL;
      LAffected := LQuery.RowsAffected;
    finally
      LQuery.Free;
    end;

    Result := (LAffected > 0);
    // 注意：即使 challenge 已非 pending（LAffected=0），decision 行已写入。
    // 这是有意的——决策记录本身是审计事实（人类确实做过此决策），
    // 只是它未改变 challenge 终态。调用方据 Result=False 判定决策未生效。
  finally
    System.TMonitor.Exit(FLock);
  end;
end;

function TReviewQueueSQLite.GetChallenge(const AReviewId: string;
  out AChallenge: TReviewChallenge): Boolean;
var
  LQuery: TFDQuery;
begin
  Result := False;
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := SQL_GET_CHALLENGE;
    LQuery.ParamByName('review_id').AsString := AReviewId;
    LQuery.Open;
    if not LQuery.Eof then
    begin
      ReadChallengeRow(LQuery, AChallenge);
      Result := True;
    end;
  finally
    LQuery.Free;
  end;
end;

function TReviewQueueSQLite.QueryByIntent(
  const AActionIntentId: string): TArray<TReviewChallenge>;
var
  LQuery: TFDQuery;
  LList: TArray<TReviewChallenge>;
  LCh: TReviewChallenge;
begin
  Result := nil;
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := SQL_QUERY_BY_INTENT;
    LQuery.ParamByName('action_intent_id').AsString := AActionIntentId;
    LQuery.Open;
    while not LQuery.Eof do
    begin
      ReadChallengeRow(LQuery, LCh);
      SetLength(LList, Length(LList) + 1);
      LList[High(LList)] := LCh;
      LQuery.Next;
    end;
    Result := LList;
  finally
    LQuery.Free;
  end;
end;

function TReviewQueueSQLite.QueryPending: TArray<TReviewChallenge>;
var
  LQuery: TFDQuery;
  LList: TArray<TReviewChallenge>;
  LCh: TReviewChallenge;
begin
  Result := nil;
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := SQL_QUERY_PENDING;
    LQuery.Open;
    while not LQuery.Eof do
    begin
      ReadChallengeRow(LQuery, LCh);
      SetLength(LList, Length(LList) + 1);
      LList[High(LList)] := LCh;
      LQuery.Next;
    end;
    Result := LList;
  finally
    LQuery.Free;
  end;
end;

function TReviewQueueSQLite.GetDecision(const ADecisionId: string;
  out ADecision: THumanDecision): Boolean;
var
  LQuery: TFDQuery;
begin
  Result := False;
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := SQL_GET_DECISION;
    LQuery.ParamByName('human_decision_id').AsString := ADecisionId;
    LQuery.Open;
    if not LQuery.Eof then
    begin
      ReadDecisionRow(LQuery, ADecision);
      Result := True;
    end;
  finally
    LQuery.Free;
  end;
end;

function TReviewQueueSQLite.ExpireOverdue: Integer;
var
  LQuery: TFDQuery;
begin
  System.TMonitor.Enter(FLock);
  try
    LQuery := TFDQuery.Create(nil);
    try
      LQuery.Connection := FConnection;
      LQuery.SQL.Text := SQL_EXPIRE_OVERDUE;
      LQuery.ParamByName('updated_at').AsString := DateToISO8601(Now);
      LQuery.ParamByName('now').AsString := DateToISO8601(Now);
      LQuery.ExecSQL;
      Result := LQuery.RowsAffected;
    finally
      LQuery.Free;
    end;
  finally
    System.TMonitor.Exit(FLock);
  end;
end;

function TReviewQueueSQLite.VerifyChain(out ABrokenCount,
  ATotalRows: Integer): Boolean;
var
  LQuery: TFDQuery;
  LPrevHash, LExpectedHash, LStoredHash, LTimestamp, LPayload: string;
  LCh: TReviewChallenge;
begin
  ABrokenCount := 0;
  ATotalRows := 0;
  LPrevHash := GENESIS_HASH;

  System.TMonitor.Enter(FLock);
  try
    LQuery := TFDQuery.Create(nil);
    try
      LQuery.Connection := FConnection;
      LQuery.SQL.Text := SQL_VERIFY_CHAIN;
      LQuery.Open;
      while not LQuery.Eof do
      begin
        Inc(ATotalRows);

        LCh.ReviewId := LQuery.FieldByName('review_id').AsString;
        LCh.ActionIntentId := LQuery.FieldByName('action_intent_id').AsString;
        LCh.ActionSummary := LQuery.FieldByName('action_summary').AsString;
        LCh.TargetSummary := LQuery.FieldByName('target_summary').AsString;
        LCh.Impact := LQuery.FieldByName('impact').AsString;
        LCh.Reversibility := LQuery.FieldByName('reversibility').AsString;
        LCh.ParametersDigest := LQuery.FieldByName('parameters_digest').AsString;
        LCh.AllowedDecisions := JsonToArray(LQuery.FieldByName('allowed_decisions').AsString);
        LCh.AuthorizationScopes := JsonToArray(LQuery.FieldByName('authorization_scopes').AsString);
        LCh.EvidenceRefs := JsonToArray(LQuery.FieldByName('evidence_refs').AsString);

        LTimestamp := LQuery.FieldByName('created_at').AsString;
        LStoredHash := LQuery.FieldByName('this_hash').AsString;

        // 逐行重算 payload + hash，比对 this_hash（防内容被静默篡改）。
        // expires_at 用存储列原始字符串，避免 TDateTime 往返精度差异。
        LPayload := ComputePayloadRaw(LCh, LQuery.FieldByName('expires_at').AsString);
        LExpectedHash := ComputeHash(LTimestamp, LPayload, LPrevHash);
        if not SameText(LStoredHash, LExpectedHash) then
          Inc(ABrokenCount);

        // 链连续性推进：用存储的 this_hash 作为下一行 prev_hash（即使本行被
        // 破坏，也继续用存储值以保证后续链段连续性，可定位首个篡改点）。
        if LStoredHash <> '' then
          LPrevHash := LStoredHash
        else
        begin
          Inc(ABrokenCount);
          LPrevHash := GENESIS_HASH;
        end;

        LQuery.Next;
      end;
    finally
      LQuery.Free;
    end;

    Result := (ABrokenCount = 0);
  finally
    System.TMonitor.Exit(FLock);
  end;
end;

function TReviewQueueSQLite.Count: Integer;
var
  LQuery: TFDQuery;
begin
  Result := 0;
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := SQL_COUNT;
    LQuery.Open;
    if not LQuery.Eof then
      Result := LQuery.Fields[0].AsInteger;
  finally
    LQuery.Free;
  end;
end;

// ASY-GOV-006 stage3: atomically consume a challenge. Only writes the
// current timestamp (ISO8601) when executed_at IS NULL, preventing asOnce
// replay. On success refills AOutChallenge (with the new ExecutedAt).
// Returns False if not found or already executed.
function TReviewQueueSQLite.MarkExecuted(const AReviewId: string;
  out AOutChallenge: TReviewChallenge): Boolean;
var
  LQuery: TFDQuery;
  LExecutedAt: string;
begin
  Result := False;
  LExecutedAt := DateToISO8601(Now);
  System.TMonitor.Enter(FLock);
  try
    LQuery := TFDQuery.Create(nil);
    try
      LQuery.Connection := FConnection;
      LQuery.SQL.Text := SQL_MARK_EXECUTED;
      LQuery.ParamByName('executed_at').AsString := LExecutedAt;
      LQuery.ParamByName('updated_at').AsString := LExecutedAt;
      LQuery.ParamByName('review_id').AsString := AReviewId;
      LQuery.ExecSQL;
      Result := LQuery.RowsAffected = 1;
    finally
      LQuery.Free;
    end;
    if Result then
      GetChallenge(AReviewId, AOutChallenge);
  finally
    System.TMonitor.Exit(FLock);
  end;
end;

function TReviewQueueSQLite.IsExecuted(const AReviewId: string): Boolean;
var
  LQuery: TFDQuery;
begin
  Result := False;
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := SQL_SELECT_EXECUTED_AT;
    LQuery.ParamByName('review_id').AsString := AReviewId;
    LQuery.Open;
    if (not LQuery.Eof) and (not LQuery.Fields[0].IsNull) then
      Result := True;
  finally
    LQuery.Free;
  end;
end;

end.
