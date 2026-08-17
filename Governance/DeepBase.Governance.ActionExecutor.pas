// AI-GENERATED
// DeepBase.Governance.ActionExecutor.pas
// 第四层：行为执行器（调用 Bridge 链）
// 依赖 Interfaces + ActionGrid + DueChecker

unit DeepBase.Governance.ActionExecutor;

interface

uses
  System.SysUtils,
  System.JSON,
  DeepBase.Governance.Types,
  DeepBase.Governance.Interfaces,
  DeepBase.Governance.ReviewQueue;

type
  TActionExecutor = class(TInterfacedObject, IActionExecutor)
  private
    FActionGrid: IActionGrid;
    FDueChecker: IDueChecker;
    FEvidenceRecorder: IEvidenceRecorder;
    FVerifier: IReviewDecisionVerifier;
    /// 从 AContext 提取执行端实时入参摘要（与 challenge.ParametersDigest 同算法）。
    /// 默认返回空串（无需校验）；子类/装配可覆盖。此处取 context 的
    /// 'parameters_digest' 字段，若缺失则空。
    function ExtractArgumentsDigest(AContext: TJSONObject): string;
  public
    constructor Create(AActionGrid: IActionGrid; ADueChecker: IDueChecker;
      AEvidenceRecorder: IEvidenceRecorder;
      AVerifier: IReviewDecisionVerifier = nil);

    // IActionExecutor
    function Execute(const AActionKey: string; AContext: TJSONObject;
      AMode: TRunMode; const AConfirmation: string = ''): TActionResult;
    procedure SetVerifier(const AVerifier: IReviewDecisionVerifier);
  end;

implementation

{ TActionExecutor }

constructor TActionExecutor.Create(AActionGrid: IActionGrid;
  ADueChecker: IDueChecker; AEvidenceRecorder: IEvidenceRecorder;
  AVerifier: IReviewDecisionVerifier);
begin
  inherited Create;
  FActionGrid := AActionGrid;
  FDueChecker := ADueChecker;
  FEvidenceRecorder := AEvidenceRecorder;
  FVerifier := AVerifier;
end;

procedure TActionExecutor.SetVerifier(const AVerifier: IReviewDecisionVerifier);
begin
  FVerifier := AVerifier;
end;

function TActionExecutor.ExtractArgumentsDigest(AContext: TJSONObject): string;
var
  LVal: TJSONValue;
begin
  // 执行端入参摘要：取 context 的 'parameters_digest' 字段。
  // 与 challenge.ParametersDigest 同源（由调用方在创建 challenge 时写入同一摘要）。
  Result := '';
  if AContext = nil then
    Exit;
  LVal := AContext.FindValue('parameters_digest');
  if (LVal <> nil) and (LVal is TJSONString) then
    Result := TJSONString(LVal).Value;
end;

function TActionExecutor.Execute(const AActionKey: string;
  AContext: TJSONObject; AMode: TRunMode; const AConfirmation: string): TActionResult;
var
  LDue: TDueResult;
  LChallenge: TReviewChallenge;
  LReason: string;
  LDigest: string;
begin
  // 0. ASY-GOV-006 阶段3：裁决验证（fail-closed）
  //    confirmation 非空 = 调用方主张已获人工批准，必须经 verifier 校验。
  if AConfirmation <> '' then
  begin
    if FVerifier = nil then
      // 有凭证却无校验器 → 绝不放行（装配缺陷，不可静默降级）
      raise EReviewDecisionRejected.CreateFmt(
        'action [%s] 带裁决凭证但 executor 未装配 verifier', [AActionKey]);
    LDigest := ExtractArgumentsDigest(AContext);
    if not FVerifier.Verify(AActionKey, LDigest, AConfirmation, asOnce,
      LChallenge, LReason) then
      raise EReviewDecisionRejected.CreateFmt(
        'action [%s] 裁决被拒: %s', [AActionKey, LReason]);
  end;

  // 1. 检查是否可执行
  if not FActionGrid.CanRun(AActionKey, AContext) then
  begin
    Result := TActionResult.Blocked(AActionKey,
      FActionGrid.GetDisabledReason(AActionKey, AContext));
    // 记录阻挡证据
    if FEvidenceRecorder <> nil then
      FEvidenceRecorder.LogBlocked(AActionKey, Result.Message, AContext);
    Exit;
  end;

  // 2. 合当检查（DryRun 和 Commit 都需要）
  if (FDueChecker <> nil) and (AMode <> rmPreview) then
  begin
    LDue := FDueChecker.Check(AActionKey, AContext);
    if LDue.Verdict <> dvPass then
    begin
      Result := TActionResult.Blocked(AActionKey, LDue.Reason);
      if FEvidenceRecorder <> nil then
        FEvidenceRecorder.LogBlocked(AActionKey, LDue.Reason, AContext);
      Exit;
    end;
  end;

  // 3. 执行
  Result := FActionGrid.Run(AActionKey, AContext, AMode);

  // 3.5 asOnce 消费：仅 Commit 成功后消费，防重放（DryRun/Preview 不消费）
  if (AConfirmation <> '') and (AMode = rmCommit) and (FVerifier <> nil) then
  begin
    if Result.Status = arsSuccess then
      // Consume 返回 False = 已被消费（并发重放），记录但不回滚已执行的副作用
      // （asOnce 语义下并发第二次执行属边界，由调用方幂等保证）
      FVerifier.Consume(LChallenge.ReviewId, LChallenge)
    else
      ; // 执行失败不消费，保留 challenge 供重试
  end;

  // 4. 记录证据（仅 Commit 模式）
  if (FEvidenceRecorder <> nil) and (AMode = rmCommit) then
    FEvidenceRecorder.LogAction(AActionKey, AContext, Result);
end;

end.
