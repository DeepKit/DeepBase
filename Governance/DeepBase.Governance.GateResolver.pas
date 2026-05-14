// AI-GENERATED
// DeepBase.Governance.GateResolver.pas
// 第四层：门禁状态解析
// 依赖 Interfaces + Model + KeyResolver

unit DeepBase.Governance.GateResolver;

interface

uses
  System.SysUtils,
  System.JSON,
  System.Generics.Collections,
  DeepBase.Governance.Types,
  DeepBase.Governance.Interfaces,
  DeepBase.Governance.Model;

type
  /// 门禁条件评估器（可扩展）
  TConditionEvaluator = reference to function(ACondition: TGateCondition;
    AContext: TJSONObject): Boolean;

  /// 门禁解析器实现
  TGateResolver = class(TInterfacedObject, IGateResolver)
  private
    FKeyResolver: IKeyResolver;
    FEvaluators: TDictionary<TGateConditionKind, TConditionEvaluator>;
    function EvaluateCondition(ACondition: TGateCondition;
      AContext: TJSONObject): Boolean;
    function DetermineState(AGate: TAccessGate;
      AContext: TJSONObject; out ABlockedReason: string): TGateState;
  public
    constructor Create(AKeyResolver: IKeyResolver);
    destructor Destroy; override;

    // 注册条件评估器
    procedure RegisterEvaluator(AKind: TGateConditionKind;
      AEvaluator: TConditionEvaluator);

    // IGateResolver
    function Resolve(const AGateKey: string;
      AContext: TJSONObject): TGateResolution;
    function GetState(const AGateKey: string;
      AContext: TJSONObject): TGateState;
  end;

implementation

{ TGateResolver }

constructor TGateResolver.Create(AKeyResolver: IKeyResolver);
begin
  inherited Create;
  FKeyResolver := AKeyResolver;
  FEvaluators := TDictionary<TGateConditionKind, TConditionEvaluator>.Create;
end;

destructor TGateResolver.Destroy;
begin
  FEvaluators.Free;
  inherited;
end;

procedure TGateResolver.RegisterEvaluator(AKind: TGateConditionKind;
  AEvaluator: TConditionEvaluator);
begin
  FEvaluators.AddOrSetValue(AKind, AEvaluator);
end;

function TGateResolver.EvaluateCondition(ACondition: TGateCondition;
  AContext: TJSONObject): Boolean;
var
  LEvaluator: TConditionEvaluator;
begin
  if FEvaluators.TryGetValue(ACondition.Kind, LEvaluator) then
    Result := LEvaluator(ACondition, AContext)
  else
    // Fail-closed：无评估器时按 Kind 决定默认策略
    // - Permission/Risk/Seal/Accountability：默认拒绝（安全优先）
    // - State/Contract/Evidence：默认拒绝（需显式配置）
    // 任何 GateCondition 只要被声明，就必须有对应的 Evaluator
    // 这是防止"看起来有治理但实际放行"的关键防线
    Result := False;
end;

function TGateResolver.DetermineState(AGate: TAccessGate;
  AContext: TJSONObject; out ABlockedReason: string): TGateState;
var
  LCondition: TGateCondition;
  LFailCount: Integer;
  LHasPermissionFail: Boolean;
begin
  ABlockedReason := '';
  LFailCount := 0;
  LHasPermissionFail := False;

  if AGate.Conditions.Count = 0 then
    Exit(gsOpen);

  for LCondition in AGate.Conditions do
  begin
    if not EvaluateCondition(LCondition, AContext) then
    begin
      Inc(LFailCount);
      if LCondition.Kind = gckPermission then
        LHasPermissionFail := True;
      if ABlockedReason = '' then
        ABlockedReason := LCondition.BlockedMessage;
    end;
  end;

  if LFailCount = 0 then
    Result := gsOpen
  else if LHasPermissionFail then
    Result := gsDisabled
  else if LFailCount > 1 then
    Result := gsConflict
  else
    Result := gsBlocked;
end;

function TGateResolver.Resolve(const AGateKey: string;
  AContext: TJSONObject): TGateResolution;
var
  LGate: TAccessGate;
  LBlockedReason: string;
begin
  Result.GateKey := AGateKey;
  Result.AvailableActions := nil;

  LGate := FKeyResolver.ResolveGateKey(AGateKey);
  if LGate = nil then
  begin
    Result.State := gsClosed;
    Result.BlockedReason := 'Gate not found: ' + AGateKey;
    Exit;
  end;

  Result.State := DetermineState(LGate, AContext, LBlockedReason);
  Result.BlockedReason := LBlockedReason;

  // Always populate AvailableActions. The caller (EnterGate) already checks
  // State before dispatch. This also lets decorators like ObserveGateResolver
  // override State to gsOpen and still have actions available for routing.
  Result.AvailableActions := LGate.ActionKeys.ToArray;
end;

function TGateResolver.GetState(const AGateKey: string;
  AContext: TJSONObject): TGateState;
var
  LResolution: TGateResolution;
begin
  LResolution := Resolve(AGateKey, AContext);
  Result := LResolution.State;
end;

end.
