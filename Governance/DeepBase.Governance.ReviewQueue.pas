// AI-GENERATED
// DeepBase.Governance.ReviewQueue.pas
// 主权 review queue 契约层：裁决挑战 + 人工决策记录 + IReviewQueue 接口。
// ASY-GOV-006 阶段2：D006 人主权——review case 的权威状态不由 UI 保存，
// 落 DeepBase 持久层。challenge 行挂 HMAC-SHA256 哈希链（与 evidence 链同构），
// 防止有 DB 写权限的攻击者静默篡改/删除裁决状态。
// 依赖 Persistence + Crypto.Hash/Encoding（哈希原语，由 SQLite 实现层复用）。
//
// 字段对齐 docs/40-specifications/api/openapi/common.yaml 的
// ReviewChallenge / HumanDecision schema。

unit DeepBase.Governance.ReviewQueue;

interface

uses
  System.SysUtils,
  System.Generics.Collections;

type
  /// ASY-GOV-006 阶段3：执行端 fail-closed 异常。ActionExecutor 在
  /// verifier=nil 却收到非空 confirmation，或 Verify 返回 False 时抛出，
  /// 阻止未获主权批准的高风险 action 执行。
  EReviewDecisionRejected = class(Exception);

  /// ReviewChallenge 生命周期状态。
  /// pending → approved | rejected | cancelled | expired（单向，不可逆）
  TReviewStatus = (
    rsPending,
    rsApproved,
    rsRejected,
    rsCancelled,
    rsExpired
  );

  /// 人工决策动作（对应 HumanDecision.decision enum）。
  TReviewDecision = (
    rdApprove,
    rdReject,
    rdCancel
  );

  /// 授权作用域（对应 HumanDecision.authorization_scope enum）。
  TAuthorizationScope = (
    asOnce,
    asSession,
    asPersistent
  );

  /// <summary>
  /// 裁决挑战记录。对应 review_challenges 表一行。
  /// 由 Governance 或 action owner 创建并拥有；UI/CLI 仅作展示与决策客户端。
  /// </summary>
  TReviewChallenge = record
    ReviewId: string;             // PK, UUID
    ActionIntentId: string;       // 关联 ActionIntent（与 evidence.action_intent_id 同源）
    DecisionId: string;           // 预期决策占位 UUID（裁决落定后指向 HumanDecision）
    ActionSummary: string;        // 动作摘要（≤2000）
    TargetSummary: string;        // 目标摘要（≤2000）
    Impact: string;               // 影响说明（≤4000）
    Reversibility: string;        // 可逆性
    ParametersDigest: string;     // Sha256Digest，绑定入参
    AllowedDecisions: TArray<string>;      // 允许的决策项（JSON 列）
    AuthorizationScopes: TArray<string>;   // 允许的作用域（JSON 列）
    EvidenceRefs: TArray<string>;         // 关联证据行 id（JSON 列）
    ExpiresAt: TDateTime;         // 过期时刻；过期 → rsExpired
    Status: TReviewStatus;
    CreatedAt: TDateTime;
    UpdatedAt: TDateTime;
    ExecutedAt: TDateTime;         // asOnce 消费时刻；>0 表示已执行（防重放），0=未执行
    PrevHash: string;              // 哈希链：上一行 this_hash
    ThisHash: string;              // 哈希链：本行哈希
  end;

  /// <summary>
  /// 执行端裁决验证器。ASY-GOV-006 阶段3：ActionExecutor 在执行高风险
  /// action 前，凭人工裁决凭证（confirmation=review_id）调本接口校验
  /// 该 action 已获主权批准且入参未被篡改。校验通过后由执行端调
  /// MarkExecuted 标记消费，防 asOnce 重放。
  /// </summary>
  IReviewDecisionVerifier = interface
    ['{C8B4A3F2-0D5E-5B9F-C2A7-4E3F1B8D6000}']
    /// 校验 confirmation 对应的裁决是否允许执行 action。
    /// - AActionKey：被校验的动作键（用于日志/证据，不参与哈希比对）
    /// - AArgumentsDigest：执行端实时计算的入参摘要，须与 challenge.ParametersDigest 一致
    /// - AConfirmation：人工裁决凭证 = review_id
    /// - ARequiredScope：执行端要求的作用域（通常 asOnce）
    /// fail-fast：①challenge 存在 ②ParametersDigest 匹配 ③未过期(先 ExpireOverdue)
    /// ④status=approved ⑤AuthorizationScopes 含 ARequiredScope。
    /// 全通过返回 True + AOutChallenge；任一失败返回 False + ARejectionReason。
    function Verify(const AActionKey, AArgumentsDigest, AConfirmation: string;
      ARequiredScope: TAuthorizationScope;
      out AOutChallenge: TReviewChallenge;
      out ARejectionReason: string): Boolean;
    /// 消费 challenge（asOnce 防重放）。Verify 通过后、action 执行成功后由
    /// 执行端调用。已执行返回 False（重放被拒）。封装 IReviewQueue.MarkExecuted。
    function Consume(const AReviewId: string;
      out AOutChallenge: TReviewChallenge): Boolean;
  end;

  /// <summary>
  /// 人工决策记录。对应 human_decisions 表一行。
  /// 裁决落定时由 RecordDecision 写入，并把 challenge 状态推进为
  /// approved/rejected/cancelled。
  /// </summary>
  THumanDecision = record
    HumanDecisionId: string;      // PK, UUID
    ReviewId: string;              // FK → review_challenges
    ActionIntentId: string;       // 冗余便于直查（与 challenge 同值）
    ActorId: string;               // 决策者标识（≤255）
    Decision: TReviewDecision;
    AuthorizationScope: TAuthorizationScope;
    ParametersDigest: string;      // 绑定入参，防重放
    DecidedAt: TDateTime;
    ExpiresAt: TDateTime;         // session/persistent 作用域的失效时刻
  end;

  /// <summary>
  /// SQLite 持久化的主权 review queue。
  /// ASY-GOV-006 阶段2：challenge 行挂 HMAC-SHA256 线性链，所有写入在
  /// FLock 下；状态机用原子 UPDATE WHERE status=rsPending 防并发双重裁决。
  /// </summary>
  IReviewQueue = interface
    ['{B7A3F2E1-9C4D-4A8E-B1F6-3D2E0A7C5F90}']
    /// 创建裁决挑战。返回写入的 challenge（含已计算的哈希链）。
    function CreateChallenge(const AChallenge: TReviewChallenge): TReviewChallenge;
    /// 记录人工决策并推进 challenge 状态。
    /// 若 challenge 已非 pending（已被裁决/取消/过期），返回 False（fail-closed）。
    function RecordDecision(const ADecision: THumanDecision): Boolean;
    /// 按 review_id 取挑战（含哈希）。不存在返回 False。
    function GetChallenge(const AReviewId: string; out AChallenge: TReviewChallenge): Boolean;
    /// 取某 action_intent 的全部挑战（裁决历史）。
    function QueryByIntent(const AActionIntentId: string): TArray<TReviewChallenge>;
    /// 取全部 pending 挑战（裁决队列视图）。
    function QueryPending: TArray<TReviewChallenge>;
    /// 按 decision_id 取人工决策。
    function GetDecision(const ADecisionId: string; out ADecision: THumanDecision): Boolean;
    /// 把过期 pending 推进为 expired。返回推进的行数（供定时任务）。
    function ExpireOverdue: Integer;
    /// 哈希链完整性校验。返回是否完整 + 破损行数 + 总行数。
    function VerifyChain(out ABrokenCount, ATotalRows: Integer): Boolean;
    /// challenge 行数（不含 decision 行）。
    function Count: Integer;
    /// 标记 challenge 已被消费（asOnce 防重放）。原子 UPDATE WHERE executed_at IS NULL。
    /// 已执行返回 False（重放被拒）。同时刷新 AOutChallenge.ExecutedAt。
    function MarkExecuted(const AReviewId: string;
      out AOutChallenge: TReviewChallenge): Boolean;
    /// 是否已消费（executed_at > 0）。不存在返回 False。
    function IsExecuted(const AReviewId: string): Boolean;
  end;

  /// <summary>
  /// 默认裁决验证器实现。持 IReviewQueue 做只读校验 + Consume 写，
  /// 不直接碰 SQL。fail-fast 五步见 IReviewDecisionVerifier.Verify 注释。
  /// 声明须在 IReviewQueue 之后（FQueue/构造参引用它）。
  /// </summary>
  TReviewDecisionVerifier = class(TInterfacedObject, IReviewDecisionVerifier)
  private
    FQueue: IReviewQueue;
  public
    constructor Create(const AQueue: IReviewQueue);
    function Verify(const AActionKey, AArgumentsDigest, AConfirmation: string;
      ARequiredScope: TAuthorizationScope;
      out AOutChallenge: TReviewChallenge;
      out ARejectionReason: string): Boolean;
    function Consume(const AReviewId: string;
      out AOutChallenge: TReviewChallenge): Boolean;
  end;

implementation

{ TReviewDecisionVerifier }

constructor TReviewDecisionVerifier.Create(const AQueue: IReviewQueue);
begin
  inherited Create;
  FQueue := AQueue;
end;

function TReviewDecisionVerifier.Verify(const AActionKey, AArgumentsDigest,
  AConfirmation: string; ARequiredScope: TAuthorizationScope;
  out AOutChallenge: TReviewChallenge; out ARejectionReason: string): Boolean;
const
  // 与 TReviewQueueSQLite.ScopeToStr 同表（verifier 不依赖 SQLite 单元，故内联）。
  SCOPE_NAMES: array [TAuthorizationScope] of string = ('once', 'session', 'persistent');
var
  LScope: string;
  LFound: Boolean;
  LScopeStr: string;
  I: Integer;
begin
  Result := False;
  ARejectionReason := '';
  // 缺省初始化 out 参数（managed record 编译器已置 nil，显式 Finalize 更稳）。
  Finalize(AOutChallenge);
  FillChar(AOutChallenge, SizeOf(AOutChallenge), 0);

  if FQueue = nil then
  begin
    ARejectionReason := 'verifier 未绑定 review queue';
    Exit;
  end;

  // ① challenge 存在
  if not FQueue.GetChallenge(AConfirmation, AOutChallenge) then
  begin
    ARejectionReason := '裁决凭证对应的 challenge 不存在: ' + AConfirmation;
    Exit;
  end;

  // ③ 推进过期（先 ExpireOverdue 再判 status，确保过期 challenge 被标记）
  FQueue.ExpireOverdue;
  // 过期后重新读一次（ExpireOverdue 可能改了 status）
  if not FQueue.GetChallenge(AConfirmation, AOutChallenge) then
  begin
    ARejectionReason := 'challenge 重新读取失败';
    Exit;
  end;

  // ② 入参摘要匹配（防篡改/重放到不同参数）
  if not SameText(AOutChallenge.ParametersDigest, AArgumentsDigest) then
  begin
    ARejectionReason := '入参摘要不匹配（疑似篡改或重放到不同参数）';
    Exit;
  end;

  // ④ status = approved
  if AOutChallenge.Status <> rsApproved then
  begin
    ARejectionReason := '裁决未批准（当前状态: ' + IntToStr(Ord(AOutChallenge.Status)) + '）';
    Exit;
  end;

  // ⑤ 作用域包含 ARequiredScope
  LScope := SCOPE_NAMES[ARequiredScope];
  LFound := False;
  for I := 0 to High(AOutChallenge.AuthorizationScopes) do
  begin
    LScopeStr := AOutChallenge.AuthorizationScopes[I];
    if SameText(LScopeStr, LScope) then
    begin
      LFound := True;
      Break;
    end;
  end;
  if not LFound then
  begin
    ARejectionReason := '裁决作用域不含 ' + LScope;
    Exit;
  end;

  // asOnce 已消费检查：ExecutedAt > 0 表示已被消费（防重放）
  if (ARequiredScope = asOnce) and (AOutChallenge.ExecutedAt > 0) then
  begin
    ARejectionReason := 'asOnce 裁决已被消费（防重放）';
    Exit;
  end;

  Result := True;
end;

function TReviewDecisionVerifier.Consume(const AReviewId: string;
  out AOutChallenge: TReviewChallenge): Boolean;
begin
  if FQueue = nil then
  begin
    Finalize(AOutChallenge);
    FillChar(AOutChallenge, SizeOf(AOutChallenge), 0);
    Result := False;
    Exit;
  end;
  Result := FQueue.MarkExecuted(AReviewId, AOutChallenge);
end;

end.
