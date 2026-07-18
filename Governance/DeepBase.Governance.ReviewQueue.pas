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
    PrevHash: string;              // 哈希链：上一行 this_hash
    ThisHash: string;              // 哈希链：本行哈希
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
  end;

implementation

end.
