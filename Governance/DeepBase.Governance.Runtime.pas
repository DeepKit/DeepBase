// AI-GENERATED
// DeepBase.Governance.Runtime.pas
// 第四层：总协调器（EnterGate 入口）
// 依赖所有 Engine

unit DeepBase.Governance.Runtime;

interface

uses
  System.SysUtils,
  System.JSON,
  System.Generics.Collections,
  DeepBase.Governance.Types,
  DeepBase.Governance.Interfaces;

type
  /// OCGS Runtime — 总协调器
  TOCGSRuntime = class(TInterfacedObject, IOCGSRuntime)
  private
    FActionGrid: IActionGrid;
    FGateResolver: IGateResolver;
    FRouteResolver: IRouteResolver;
    FActionExecutor: IActionExecutor;
    FDueChecker: IDueChecker;
    FProjectionResolver: IProjectionResolver;
    FFeedbackResolver: IFeedbackResolver;
    FEvidenceRecorder: IEvidenceRecorder;
    FKeyResolver: IKeyResolver;
  public
    constructor Create(
      AActionGrid: IActionGrid;
      AGateResolver: IGateResolver;
      ARouteResolver: IRouteResolver;
      AActionExecutor: IActionExecutor;
      ADueChecker: IDueChecker;
      AProjectionResolver: IProjectionResolver;
      AFeedbackResolver: IFeedbackResolver;
      AEvidenceRecorder: IEvidenceRecorder;
      AKeyResolver: IKeyResolver);

    // IOCGSRuntime
    function EnterGate(const AGateKey: string; AContext: TJSONObject;
      AMode: TRunMode): TActionResult;
    function PreviewGate(const AGateKey: string;
      AContext: TJSONObject): TGateResolution;
    function GetAvailableActions(AContext: TJSONObject): TArray<TActionInfo>;

    // 属性访问
    property ActionGrid: IActionGrid read FActionGrid;
    property GateResolver: IGateResolver read FGateResolver;
    property RouteResolver: IRouteResolver read FRouteResolver;
    property ActionExecutor: IActionExecutor read FActionExecutor;
    property DueChecker: IDueChecker read FDueChecker;
    property ProjectionResolver: IProjectionResolver read FProjectionResolver;
    property FeedbackResolver: IFeedbackResolver read FFeedbackResolver;
    property EvidenceRecorder: IEvidenceRecorder read FEvidenceRecorder;
    property KeyResolver: IKeyResolver read FKeyResolver;
  end;

implementation

{ TOCGSRuntime }

constructor TOCGSRuntime.Create(
  AActionGrid: IActionGrid;
  AGateResolver: IGateResolver;
  ARouteResolver: IRouteResolver;
  AActionExecutor: IActionExecutor;
  ADueChecker: IDueChecker;
  AProjectionResolver: IProjectionResolver;
  AFeedbackResolver: IFeedbackResolver;
  AEvidenceRecorder: IEvidenceRecorder;
  AKeyResolver: IKeyResolver);
begin
  inherited Create;
  FActionGrid := AActionGrid;
  FGateResolver := AGateResolver;
  FRouteResolver := ARouteResolver;
  FActionExecutor := AActionExecutor;
  FDueChecker := ADueChecker;
  FProjectionResolver := AProjectionResolver;
  FFeedbackResolver := AFeedbackResolver;
  FEvidenceRecorder := AEvidenceRecorder;
  FKeyResolver := AKeyResolver;
end;

function TOCGSRuntime.EnterGate(const AGateKey: string;
  AContext: TJSONObject; AMode: TRunMode): TActionResult;
var
  LResolution: TGateResolution;
  LTargetAction: string;
  LFeedback: TFeedbackInfo;
begin
  // 1. 解析门禁状态
  LResolution := FGateResolver.Resolve(AGateKey, AContext);

  // 2. 如果门禁不是 Open，返回阻挡结果
  if LResolution.State <> gsOpen then
  begin
    // 记录阻挡证据
    if FEvidenceRecorder <> nil then
      FEvidenceRecorder.LogBlocked(AGateKey, LResolution.BlockedReason, AContext);

    // 获取反馈信息
    if FFeedbackResolver <> nil then
      LFeedback := FFeedbackResolver.GetFeedback(AGateKey, LResolution.State);

    Result := TActionResult.Blocked(AGateKey, LResolution.BlockedReason);
    Exit;
  end;

  // 3. 路由解析：确定目标 Action
  LTargetAction := '';
  if FRouteResolver <> nil then
    LTargetAction := FRouteResolver.Resolve(AGateKey, AContext);

  // 如果路由未匹配，尝试使用 Gate 的第一个 Action
  if (LTargetAction = '') and (Length(LResolution.AvailableActions) > 0) then
    LTargetAction := LResolution.AvailableActions[0];

  if LTargetAction = '' then
  begin
    Result := TActionResult.Fail(AGateKey, 'No action resolved for gate: ' + AGateKey);
    Exit;
  end;

  // 4. 执行 Action
  if FActionExecutor <> nil then
    Result := FActionExecutor.Execute(LTargetAction, AContext, AMode)
  else
    Result := FActionGrid.Run(LTargetAction, AContext, AMode);

  // 5. 刷新投射（Commit 模式后）
  if (AMode = rmCommit) and (FProjectionResolver <> nil) then
    FProjectionResolver.RefreshAll;
end;

function TOCGSRuntime.PreviewGate(const AGateKey: string;
  AContext: TJSONObject): TGateResolution;
begin
  Result := FGateResolver.Resolve(AGateKey, AContext);
end;

function TOCGSRuntime.GetAvailableActions(
  AContext: TJSONObject): TArray<TActionInfo>;
begin
  Result := FActionGrid.GetAllActions;
end;

end.
