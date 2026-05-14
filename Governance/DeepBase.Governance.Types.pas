// AI-GENERATED
// DeepBase.Governance.Types.pas
// 第一层：基础类型（无依赖）
// 枚举、记录类型定义

unit DeepBase.Governance.Types;

interface

const
  /// Evidence Schema 版本常量（P01 起始版本，后续 Phase 扩展时递增）
  EvidenceSchemaVersion_P01 = 1;

type
  /// 门禁状态 (GateState)
  TGateState = (
    gsOpen,       // 可进入
    gsClosed,     // 关闭（条件不满足）
    gsDisabled,   // 禁用（无权限）
    gsBlocked,    // 阻挡（被其他条件阻止）
    gsLocked,     // 锁定（封存后不可变）
    gsFrozen,     // 冻结（异常冻结，待处理）
    gsConflict    // 冲突（多条件矛盾）
  );

  /// 风险等级 (RiskLevel)
  TRiskLevel = (
    rlL0,   // 无风险：无需治理
    rlL1,   // 低风险：基本 Evidence
    rlL2,   // 中风险：GateCheck + Evidence + Accountability
    rlL3    // 高风险：完整 DueSet
  );

  /// 运行模式 (RunMode)
  TRunMode = (
    rmPreview,   // 预览：只检查条件，不执行
    rmDryRun,    // 试运行：执行但不提交
    rmCommit     // 提交：执行并提交
  );

  /// 合当判定结果 (DueResult)
  TDueVerdict = (
    dvPass,      // 通过
    dvFail,      // 失败
    dvFreeze,    // 冻结
    dvConflict   // 冲突
  );

  /// Action 执行结果状态
  TActionResultStatus = (
    arsSuccess,    // 成功
    arsFail,       // 失败
    arsBlocked,    // 被阻挡
    arsDryRun      // 试运行完成（未提交）
  );

  /// 门禁条件类型 (GateCondition 类型)
  TGateConditionKind = (
    gckPermission,    // 权限
    gckState,         // 状态
    gckRisk,          // 风险
    gckContract,      // 契约
    gckEvidence,      // 证据
    gckSeal,          // 封存
    gckAccountability // 责任
  );

  /// 门禁类型
  TGateType = (
    gtEntry,    // 入口门禁
    gtAction,   // 行为门禁
    gtRoute     // 路由门禁
  );

  /// 路由目标类型
  TRouteTargetType = (
    rttAction,   // 目标是 Action
    rttGate,     // 目标是 AccessGate
    rttField     // 目标是 ContextField
  );

  /// Evidence 结果
  TEvidenceResult = (
    erSuccess,   // 成功
    erFail,      // 失败
    erBlocked    // 被阻挡
  );

  /// Action 执行结果记录
  TActionResult = record
    Status: TActionResultStatus;
    ActionKey: string;
    Message: string;
    OutputData: string;  // JSON 格式的输出数据
    class function Success(const AActionKey: string; const AMessage: string = ''): TActionResult; static;
    class function Fail(const AActionKey: string; const AMessage: string): TActionResult; static;
    class function Blocked(const AActionKey: string; const AReason: string): TActionResult; static;
    class function DryRunOK(const AActionKey: string; const AMessage: string = ''): TActionResult; static;
  end;

  /// 合当判定结果
  TDueResult = record
    Verdict: TDueVerdict;
    Reason: string;
    class function Pass: TDueResult; static;
    class function Fail(const AReason: string): TDueResult; static;
    class function Freeze(const AReason: string): TDueResult; static;
    class function Conflict(const AReason: string): TDueResult; static;
  end;

  /// 门禁解析结果
  TGateResolution = record
    GateKey: string;
    State: TGateState;
    BlockedReason: string;
    AvailableActions: TArray<string>;
  end;

  /// Action 信息（用于 GetAvailableActions）
  TActionInfo = record
    ActionKey: string;
    DisplayName: string;
    Enabled: Boolean;
    DisabledReason: string;
    RiskLevel: TRiskLevel;
  end;

  /// 反馈信息
  TFeedbackInfo = record
    GateKey: string;
    State: TGateState;
    Title: string;
    Message: string;
    NextStepHint: string;
  end;

implementation

{ TActionResult }

class function TActionResult.Success(const AActionKey, AMessage: string): TActionResult;
begin
  Result.Status := arsSuccess;
  Result.ActionKey := AActionKey;
  Result.Message := AMessage;
  Result.OutputData := '';
end;

class function TActionResult.Fail(const AActionKey, AMessage: string): TActionResult;
begin
  Result.Status := arsFail;
  Result.ActionKey := AActionKey;
  Result.Message := AMessage;
  Result.OutputData := '';
end;

class function TActionResult.Blocked(const AActionKey, AReason: string): TActionResult;
begin
  Result.Status := arsBlocked;
  Result.ActionKey := AActionKey;
  Result.Message := AReason;
  Result.OutputData := '';
end;

class function TActionResult.DryRunOK(const AActionKey, AMessage: string): TActionResult;
begin
  Result.Status := arsDryRun;
  Result.ActionKey := AActionKey;
  Result.Message := AMessage;
  Result.OutputData := '';
end;

{ TDueResult }

class function TDueResult.Pass: TDueResult;
begin
  Result.Verdict := dvPass;
  Result.Reason := '';
end;

class function TDueResult.Fail(const AReason: string): TDueResult;
begin
  Result.Verdict := dvFail;
  Result.Reason := AReason;
end;

class function TDueResult.Freeze(const AReason: string): TDueResult;
begin
  Result.Verdict := dvFreeze;
  Result.Reason := AReason;
end;

class function TDueResult.Conflict(const AReason: string): TDueResult;
begin
  Result.Verdict := dvConflict;
  Result.Reason := AReason;
end;

end.
