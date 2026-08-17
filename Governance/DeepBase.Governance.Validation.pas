// AI-GENERATED
// DeepBase.Governance.Validation.pas
// 第六层：GateValidationEngine
// P0 修复：实现 7 条核心规则（之前为空壳）
//   INV-1: 裸奔 Action（无 Gate + 无 DueRef）
//   INV-2: L2/L3 Action 缺 DuePolicy
//   INV-3: L1+ Action 缺 EvidencePolicy
//   INV-4: L2+ Action 缺 Accountability
//   INV-5: Gate 无 Action（孤立门禁）
//   INV-6: Action 有 BridgeKey 但 Bridge 未注册
//   INV-7: Key 命名非法或重复
// 其余 8 条（INV-8 至 INV-15）保留骨架，Phase 后续填充。

unit DeepBase.Governance.Validation;

interface

uses
  System.SysUtils,
  System.StrUtils,
  System.RegularExpressions,
  System.Generics.Collections,
  DeepBase.Governance.Types,
  DeepBase.Governance.Interfaces,
  DeepBase.Governance.Model,
  DeepBase.Governance.KeyResolver;

type
  /// 验证严重级别
  TValidationSeverity = (
    vsSevere,    // 严重：必须修复（阻断封版）
    vsWarning,   // 警告：建议修复
    vsInfo       // 信息：可忽略
  );

  /// 验证结果项
  TValidationIssue = record
    RuleId: string;
    Severity: TValidationSeverity;
    Message: string;
    TargetKey: string;
    Suggestion: string;
  end;

  /// 验证规则接口
  TValidationRule = reference to function(
    AKeyResolver: TKeyResolver): TArray<TValidationIssue>;

  /// 门禁验证引擎
  TGateValidationEngine = class
  private
    FKeyResolver: TKeyResolver;
    FRules: TList<TPair<string, TValidationRule>>;
    // GOV-023: cache Validate results so CountBySeverity / CanRelease /
    // ValidateSevere don't re-run the full O(rules*items) validation.
    FCachedResult: TArray<TValidationIssue>;
    FCacheValid: Boolean;
    procedure RegisterBuiltinRules;
    procedure InvalidateCache;

    // 辅助
    function MakeIssue(const ARuleId: string; ASeverity: TValidationSeverity;
      const AMessage, ATargetKey, ASuggestion: string): TValidationIssue;
    function IsValidKeyFormat(const AKey: string): Boolean;

    // P0 实现的 7 条核心规则
    function RuleINV1_NakedAction: TArray<TValidationIssue>;
    function RuleINV2_MissingDue: TArray<TValidationIssue>;
    function RuleINV3_MissingEvidence: TArray<TValidationIssue>;
    function RuleINV4_MissingAccountability: TArray<TValidationIssue>;
    function RuleINV5_OrphanGate: TArray<TValidationIssue>;
    function RuleINV6_UnregisteredBridge: TArray<TValidationIssue>;
    function RuleINV7_InvalidKey: TArray<TValidationIssue>;

    // P1 骨架（后续 Phase 填充）
    function RuleINV8_DuplicateKey: TArray<TValidationIssue>;
    function RuleINV9_CircularRoute: TArray<TValidationIssue>;
    function RuleINV10_UnreachableGate: TArray<TValidationIssue>;
    function RuleINV11_MissingFeedback: TArray<TValidationIssue>;
    function RuleINV12_L3NoSeal: TArray<TValidationIssue>;
    function RuleINV13_MissingProjection: TArray<TValidationIssue>;
    function RuleINV14_RiskMismatch: TArray<TValidationIssue>;
    function RuleINV15_EmptyField: TArray<TValidationIssue>;
  public
    constructor Create(AKeyResolver: TKeyResolver);
    destructor Destroy; override;

    procedure RegisterRule(const ARuleId: string; ARule: TValidationRule);

    function Validate: TArray<TValidationIssue>;
    function ValidateSevere: TArray<TValidationIssue>;
    function CountBySeverity(ASeverity: TValidationSeverity): Integer;

    /// PassGate 检查：SEVERE=0 即可封版
    function CanRelease: Boolean;

    /// <summary>Force the next Validate() call to re-run rules from scratch.</summary>
    procedure ResetCache;
  end;

implementation

{ TGateValidationEngine }

constructor TGateValidationEngine.Create(AKeyResolver: TKeyResolver);
begin
  inherited Create;
  FKeyResolver := AKeyResolver;
  FRules := TList<TPair<string, TValidationRule>>.Create;
  FCachedResult := nil;
  FCacheValid := False;
  RegisterBuiltinRules;
end;

destructor TGateValidationEngine.Destroy;
begin
  FRules.Free;
  inherited;
end;

procedure TGateValidationEngine.RegisterBuiltinRules;
begin
  // P0 实现（7 条核心规则）
  RegisterRule('INV-1', function(AKR: TKeyResolver): TArray<TValidationIssue>
    begin Result := RuleINV1_NakedAction; end);
  RegisterRule('INV-2', function(AKR: TKeyResolver): TArray<TValidationIssue>
    begin Result := RuleINV2_MissingDue; end);
  RegisterRule('INV-3', function(AKR: TKeyResolver): TArray<TValidationIssue>
    begin Result := RuleINV3_MissingEvidence; end);
  RegisterRule('INV-4', function(AKR: TKeyResolver): TArray<TValidationIssue>
    begin Result := RuleINV4_MissingAccountability; end);
  RegisterRule('INV-5', function(AKR: TKeyResolver): TArray<TValidationIssue>
    begin Result := RuleINV5_OrphanGate; end);
  RegisterRule('INV-6', function(AKR: TKeyResolver): TArray<TValidationIssue>
    begin Result := RuleINV6_UnregisteredBridge; end);
  RegisterRule('INV-7', function(AKR: TKeyResolver): TArray<TValidationIssue>
    begin Result := RuleINV7_InvalidKey; end);

  // REVIEW5-GOV-004: P1 骨架规则暂时降级，不注册到规则引擎中。
  // 这些规则当前返回空结果（Result := nil），会假装参与 release gate 判断。
  // 待相应 Phase 实现后，取消注释以下行以重新注册：
  //
  // INV-8: 检查重复 Key（Phase P01 框架下 TObjectDictionary 自动防护）
  // RegisterRule('INV-8', function(AKR: TKeyResolver): TArray<TValidationIssue>
  //   begin Result := RuleINV8_DuplicateKey; end);
  //
  // INV-9, INV-10: RouteImpact 分析（Phase P09）
  // RegisterRule('INV-9', function(AKR: TKeyResolver): TArray<TValidationIssue>
  //   begin Result := RuleINV9_CircularRoute; end);
  // RegisterRule('INV-10', function(AKR: TKeyResolver): TArray<TValidationIssue>
  //   begin Result := RuleINV10_UnreachableGate; end);
  //
  // INV-11, INV-13: UI 层反馈和投射检查（Phase P07）
  // RegisterRule('INV-11', function(AKR: TKeyResolver): TArray<TValidationIssue>
  //   begin Result := RuleINV11_MissingFeedback; end);
  // RegisterRule('INV-13', function(AKR: TKeyResolver): TArray<TValidationIssue>
  //   begin Result := RuleINV13_MissingProjection; end);
  //
  // INV-12: L3 高风险封存检查（Phase P10）
  // RegisterRule('INV-12', function(AKR: TKeyResolver): TArray<TValidationIssue>
  //   begin Result := RuleINV12_L3NoSeal; end);
  //
  // INV-14: 风险等级匹配检查（Phase P03）
  // RegisterRule('INV-14', function(AKR: TKeyResolver): TArray<TValidationIssue>
  //   begin Result := RuleINV14_RiskMismatch; end);
  //
  // INV-15: 治理配置空字段检查（Phase P06）
  // RegisterRule('INV-15', function(AKR: TKeyResolver): TArray<TValidationIssue>
  //   begin Result := RuleINV15_EmptyField; end);
end;

procedure TGateValidationEngine.RegisterRule(const ARuleId: string;
  ARule: TValidationRule);
begin
  FRules.Add(TPair<string, TValidationRule>.Create(ARuleId, ARule));
  // New rule may produce new issues -> invalidate cache.
  InvalidateCache;
end;

procedure TGateValidationEngine.InvalidateCache;
begin
  FCachedResult := nil;
  FCacheValid := False;
end;

procedure TGateValidationEngine.ResetCache;
begin
  InvalidateCache;
end;

function TGateValidationEngine.MakeIssue(const ARuleId: string;
  ASeverity: TValidationSeverity;
  const AMessage, ATargetKey, ASuggestion: string): TValidationIssue;
begin
  Result.RuleId := ARuleId;
  Result.Severity := ASeverity;
  Result.Message := AMessage;
  Result.TargetKey := ATargetKey;
  Result.Suggestion := ASuggestion;
end;

function TGateValidationEngine.IsValidKeyFormat(const AKey: string): Boolean;
begin
  // Key 命名规范：小写字母 + 数字 + 下划线 + 点
  // 格式：[a-z_][a-z0-9_]*(\.[a-z_][a-z0-9_]*)*
  if AKey = '' then Exit(False);
  Result := TRegEx.IsMatch(AKey, '^[a-z_][a-z0-9_]*(\.[a-z_][a-z0-9_]*)*$');
end;

// ========== P0 规则实现 ==========

function TGateValidationEngine.RuleINV1_NakedAction: TArray<TValidationIssue>;
var
  LIssues: TList<TValidationIssue>;
  LAction: TAction;
  LSeverity: TValidationSeverity;
begin
  // INV-1: 裸奔 Action — Action 无 GateKey 且无 DueRef
  // L0：Info（可不治理）；L1+：Severe
  LIssues := TList<TValidationIssue>.Create;
  try
    for LAction in FKeyResolver.GetAllActions do
    begin
      if (LAction.GateKey = '') and (LAction.DueRef = '') then
      begin
        if LAction.RiskLevel >= rlL1 then
          LSeverity := vsSevere
        else
          LSeverity := vsInfo;

        LIssues.Add(MakeIssue('INV-1', LSeverity,
          Format('Naked Action: "%s" (L%d) has no GateKey and no DueRef',
            [LAction.Key, Ord(LAction.RiskLevel)]),
          LAction.Key,
          'Assign a GateKey or DueRef to bring this action under governance'));
      end;
    end;
    Result := LIssues.ToArray;
  finally
    LIssues.Free;
  end;
end;

function TGateValidationEngine.RuleINV2_MissingDue: TArray<TValidationIssue>;
var
  LIssues: TList<TValidationIssue>;
  LAction: TAction;
begin
  // INV-2: L2/L3 Action 必须有 DueRef
  LIssues := TList<TValidationIssue>.Create;
  try
    for LAction in FKeyResolver.GetAllActions do
    begin
      if (LAction.RiskLevel >= rlL2) and (LAction.DueRef = '') then
      begin
        LIssues.Add(MakeIssue('INV-2', vsSevere,
          Format('L%d Action "%s" has no DueRef',
            [Ord(LAction.RiskLevel), LAction.Key]),
          LAction.Key,
          'L2+ Actions must declare DueRef for compliance judgment'));
      end;
    end;
    Result := LIssues.ToArray;
  finally
    LIssues.Free;
  end;
end;

function TGateValidationEngine.RuleINV3_MissingEvidence: TArray<TValidationIssue>;
var
  LIssues: TList<TValidationIssue>;
  LAction: TAction;
  LSeverity: TValidationSeverity;
begin
  // INV-3: L1+ Action 应有 EvidencePolicy（当前 Model 未建 EvidencePolicyRef 字段，
  // 用 DueRef 作为存在代理；真正的 EvidencePolicy 在 P10 封存补救层引入）
  // L1：Warning；L2+：Severe
  LIssues := TList<TValidationIssue>.Create;
  try
    for LAction in FKeyResolver.GetAllActions do
    begin
      if (LAction.RiskLevel >= rlL1) and (LAction.DueRef = '') then
      begin
        if LAction.RiskLevel >= rlL2 then
          LSeverity := vsSevere
        else
          LSeverity := vsWarning;

        LIssues.Add(MakeIssue('INV-3', LSeverity,
          Format('L%d Action "%s" lacks EvidencePolicy (proxied via DueRef in P01)',
            [Ord(LAction.RiskLevel), LAction.Key]),
          LAction.Key,
          'Declare DueRef or EvidencePolicyRef to enable evidence recording'));
      end;
    end;
    Result := LIssues.ToArray;
  finally
    LIssues.Free;
  end;
end;

function TGateValidationEngine.RuleINV4_MissingAccountability: TArray<TValidationIssue>;
var
  LIssues: TList<TValidationIssue>;
  LAction: TAction;
begin
  // INV-4: L2+ Action 应有 Accountability
  // P01 阶段：用 DueRef 包含 'accountability' 关键字作为代理
  // 真正的 Accountability 对象在 P03 主体责任层引入
  LIssues := TList<TValidationIssue>.Create;
  try
    for LAction in FKeyResolver.GetAllActions do
    begin
      if LAction.RiskLevel >= rlL2 then
      begin
        if (LAction.DueRef = '') or
           (not ContainsText(LAction.DueRef, 'accountability')) then
        begin
          LIssues.Add(MakeIssue('INV-4', vsWarning,
            Format('L%d Action "%s" may lack Accountability binding',
              [Ord(LAction.RiskLevel), LAction.Key]),
            LAction.Key,
            'Ensure DueRef includes accountability (P03 will add proper Actor objects)'));
        end;
      end;
    end;
    Result := LIssues.ToArray;
  finally
    LIssues.Free;
  end;
end;

function TGateValidationEngine.RuleINV5_OrphanGate: TArray<TValidationIssue>;
var
  LIssues: TList<TValidationIssue>;
  LGate: TAccessGate;
begin
  // INV-5: Gate 无任何 Action 关联（孤立门禁）
  LIssues := TList<TValidationIssue>.Create;
  try
    for LGate in FKeyResolver.GetAllGates do
    begin
      // Entry 类型的 Gate 可以不直接关联 Action（用于纯导航）
      // 但 Action 类型的 Gate 必须有 Action
      if (LGate.GateType = gtAction) and (LGate.ActionKeys.Count = 0) then
      begin
        LIssues.Add(MakeIssue('INV-5', vsSevere,
          Format('Orphan Gate: "%s" (type=Action) has no ActionKey linked', [LGate.Key]),
          LGate.Key,
          'Add at least one ActionKey or change GateType to Entry'));
      end;
    end;
    Result := LIssues.ToArray;
  finally
    LIssues.Free;
  end;
end;

function TGateValidationEngine.RuleINV6_UnregisteredBridge: TArray<TValidationIssue>;
var
  LIssues: TList<TValidationIssue>;
  LAction: TAction;
  LBridgeKey: string;
begin
  // INV-6: Action 的 BridgeKey 必须已注册
  LIssues := TList<TValidationIssue>.Create;
  try
    for LAction in FKeyResolver.GetAllActions do
    begin
      for LBridgeKey in LAction.BridgeKeys do
      begin
        if not FKeyResolver.IsBridgeRegistered(LBridgeKey) then
        begin
          LIssues.Add(MakeIssue('INV-6', vsSevere,
            Format('Action "%s" references unregistered Bridge "%s"',
              [LAction.Key, LBridgeKey]),
            LAction.Key,
            'Register the Bridge before binding it to an Action'));
        end;
      end;
    end;
    Result := LIssues.ToArray;
  finally
    LIssues.Free;
  end;
end;

function TGateValidationEngine.RuleINV7_InvalidKey: TArray<TValidationIssue>;
var
  LIssues: TList<TValidationIssue>;
  LAction: TAction;
  LGate: TAccessGate;
  LAbility: TAbility;
  LField: TContextField;
begin
  // INV-7: Key 命名必须符合规范（小写 + 点 + 下划线 + 数字）
  LIssues := TList<TValidationIssue>.Create;
  try
    for LAction in FKeyResolver.GetAllActions do
      if not IsValidKeyFormat(LAction.Key) then
        LIssues.Add(MakeIssue('INV-7', vsSevere,
          Format('Invalid Action Key format: "%s"', [LAction.Key]),
          LAction.Key,
          'Use lowercase letters, digits, underscores, and dots (e.g. customer.save)'));

    for LGate in FKeyResolver.GetAllGates do
      if not IsValidKeyFormat(LGate.Key) then
        LIssues.Add(MakeIssue('INV-7', vsSevere,
          Format('Invalid Gate Key format: "%s"', [LGate.Key]),
          LGate.Key,
          'Use lowercase letters, digits, underscores, and dots'));

    for LAbility in FKeyResolver.GetAllAbilities do
      if not IsValidKeyFormat(LAbility.Key) then
        LIssues.Add(MakeIssue('INV-7', vsSevere,
          Format('Invalid Ability Key format: "%s"', [LAbility.Key]),
          LAbility.Key,
          'Use lowercase letters, digits, underscores, and dots'));

    for LField in FKeyResolver.GetAllFields do
      if not IsValidKeyFormat(LField.Key) then
        LIssues.Add(MakeIssue('INV-7', vsSevere,
          Format('Invalid Field Key format: "%s"', [LField.Key]),
          LField.Key,
          'Use lowercase letters, digits, underscores, and dots'));

    Result := LIssues.ToArray;
  finally
    LIssues.Free;
  end;
end;

// ========== P1 骨架（后续 Phase 填充） ==========
// DATA2-032: 以下 8 条规则为骨架实现，当前返回 nil（不报告任何问题），
// 且未在 RegisterBuiltinRules 中注册，不会影响 CanRelease 判断。
// 每个骨架都标注了对应 Phase，便于追踪；实现后取消 RegisterRule 注释即可。
// 注意：若需要 fail-closed 行为（规则未实现时阻止封版），可在注册后改为
// 返回包含 vsSevere 的 Issue 数组。

function TGateValidationEngine.RuleINV8_DuplicateKey: TArray<TValidationIssue>;
begin
  // TODO(DATA2-032): implement INV-8 — check duplicate keys across namespaces.
  // 注：当前 TKeyResolver 使用 TObjectDictionary，不允许重复 Key（自动覆盖），
  // 所以此规则在 P01 框架下实际不会触发，保留供未来多命名空间检查。
  Result := nil;
end;

function TGateValidationEngine.RuleINV9_CircularRoute: TArray<TValidationIssue>;
begin
  // TODO(DATA2-032): implement INV-9 — cycle detection in route graph (Phase P09).
  // Fail-closed when implemented: return vsSevere for any cycle found.
  Result := nil;
end;

function TGateValidationEngine.RuleINV10_UnreachableGate: TArray<TValidationIssue>;
begin
  // TODO(DATA2-032): implement INV-10 — detect gates with no incoming route (Phase P09).
  Result := nil;
end;

function TGateValidationEngine.RuleINV11_MissingFeedback: TArray<TValidationIssue>;
begin
  // TODO(DATA2-032): implement INV-11 — UI feedback for every action (Phase P07).
  Result := nil;
end;

function TGateValidationEngine.RuleINV12_L3NoSeal: TArray<TValidationIssue>;
begin
  // TODO(DATA2-032): implement INV-12 — L3 high-risk actions must be sealed (Phase P10).
  Result := nil;
end;

function TGateValidationEngine.RuleINV13_MissingProjection: TArray<TValidationIssue>;
begin
  // TODO(DATA2-032): implement INV-13 — UI projection for every gate (Phase P07).
  Result := nil;
end;

function TGateValidationEngine.RuleINV14_RiskMismatch: TArray<TValidationIssue>;
begin
  // TODO(DATA2-032): implement INV-14 — risk level consistency check (Phase P03).
  Result := nil;
end;

function TGateValidationEngine.RuleINV15_EmptyField: TArray<TValidationIssue>;
begin
  // TODO(DATA2-032): implement INV-15 — governance config empty field check (Phase P06).
  Result := nil;
end;

// ========== 执行与统计 ==========

function TGateValidationEngine.Validate: TArray<TValidationIssue>;
var
  LAllIssues: TList<TValidationIssue>;
  LPair: TPair<string, TValidationRule>;
  LIssues: TArray<TValidationIssue>;
  LIssue: TValidationIssue;
begin
  // GOV-023: return cached result on subsequent calls. Callers that mutate
  // the underlying KeyResolver should call ResetCache.
  if FCacheValid then
    Exit(FCachedResult);

  LAllIssues := TList<TValidationIssue>.Create;
  try
    for LPair in FRules do
    begin
      LIssues := LPair.Value(FKeyResolver);
      for LIssue in LIssues do
        LAllIssues.Add(LIssue);
    end;
    Result := LAllIssues.ToArray;
  finally
    LAllIssues.Free;
  end;

  FCachedResult := Result;
  FCacheValid := True;
end;

function TGateValidationEngine.ValidateSevere: TArray<TValidationIssue>;
var
  LAll: TArray<TValidationIssue>;
  LFiltered: TList<TValidationIssue>;
  LIssue: TValidationIssue;
begin
  LAll := Validate; // cached after first call
  LFiltered := TList<TValidationIssue>.Create;
  try
    for LIssue in LAll do
      if LIssue.Severity = vsSevere then
        LFiltered.Add(LIssue);
    Result := LFiltered.ToArray;
  finally
    LFiltered.Free;
  end;
end;

function TGateValidationEngine.CountBySeverity(
  ASeverity: TValidationSeverity): Integer;
var
  LAll: TArray<TValidationIssue>;
  LIssue: TValidationIssue;
begin
  Result := 0;
  LAll := Validate; // cached after first call
  for LIssue in LAll do
    if LIssue.Severity = ASeverity then
      Inc(Result);
end;

function TGateValidationEngine.CanRelease: Boolean;
begin
  // PassGate：SEVERE=0 即可封版
  Result := CountBySeverity(vsSevere) = 0;
end;

end.
