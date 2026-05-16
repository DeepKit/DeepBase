// AI-GENERATED
// DeepBase.Governance.RouteResolver.pas
// 第四层：路由解析（调用 JsonLogic）
// P1 修复：ReloadRules 打通 RouteStore

unit DeepBase.Governance.RouteResolver;

interface

uses
  System.SysUtils,
  System.JSON,
  System.Generics.Collections,
  System.Generics.Defaults,
  DeepBase.Governance.Types,
  DeepBase.Governance.Interfaces,
  DeepBase.Governance.Model,
  DeepBase.Governance.JsonLogic;

type
  /// 路由决策记录（P1 修复：记录命中信息）
  TRouteDecision = record
    SourceGateKey: string;
    MatchedRuleId: string;
    TargetKey: string;
    FallbackUsed: Boolean;
    ReasonCode: string;
  end;

  /// RouteStore 接口（供 ReloadRules 使用）
  IRouteStore = interface
    ['{D1E2F3A4-B5C6-7890-DEFA-123456789ABC}']
    function LoadBySource(const ASourceGateKey: string): TObjectList<TRouteRule>;
    function LoadAll: TObjectList<TRouteRule>;
  end;

  TRouteResolver = class(TInterfacedObject, IRouteResolver)
  private
    FRules: TObjectList<TRouteRule>;
    FJsonLogic: TJsonLogicEngine;
    FFallbacks: TDictionary<string, string>;
    FRouteStore: IRouteStore;
    FLastDecision: TRouteDecision;
    function FindMatchingRule(const ASourceGateKey: string;
      APayload: TJSONObject): TRouteRule;
  public
    constructor Create; overload;
    constructor Create(ARouteStore: IRouteStore); overload;
    destructor Destroy; override;

    // 规则管理
    procedure AddRule(ARule: TRouteRule);
    procedure ClearRules;
    procedure SetFallback(const ASourceGateKey, ATargetKey: string);

    // IRouteResolver
    function Resolve(const ASourceGateKey: string;
      APayload: TJSONObject): string;
    function GetFallback(const ASourceGateKey: string): string;
    procedure ReloadRules;

    // 决策记录
    property LastDecision: TRouteDecision read FLastDecision;

    // 访问 JsonLogic 引擎（供测试）
    property JsonLogic: TJsonLogicEngine read FJsonLogic;
  end;

implementation

{ TRouteResolver }

constructor TRouteResolver.Create;
begin
  inherited Create;
  FRules := TObjectList<TRouteRule>.Create(True);
  FJsonLogic := TJsonLogicEngine.Create;
  FFallbacks := TDictionary<string, string>.Create;
  FRouteStore := nil;
end;

constructor TRouteResolver.Create(ARouteStore: IRouteStore);
begin
  Create;
  FRouteStore := ARouteStore;
  if FRouteStore <> nil then
    ReloadRules;
end;

destructor TRouteResolver.Destroy;
begin
  FFallbacks.Free;
  FJsonLogic.Free;
  FRules.Free;
  inherited;
end;

procedure TRouteResolver.AddRule(ARule: TRouteRule);
begin
  FRules.Add(ARule);
  // 按优先级降序排列
  FRules.Sort(TComparer<TRouteRule>.Construct(
    function(const Left, Right: TRouteRule): Integer
    begin
      Result := Right.Priority - Left.Priority;
    end));
end;

procedure TRouteResolver.ClearRules;
begin
  FRules.Clear;
end;

procedure TRouteResolver.SetFallback(const ASourceGateKey, ATargetKey: string);
begin
  FFallbacks.AddOrSetValue(ASourceGateKey, ATargetKey);
end;

function TRouteResolver.FindMatchingRule(const ASourceGateKey: string;
  APayload: TJSONObject): TRouteRule;
var
  LRule: TRouteRule;
begin
  for LRule in FRules do
  begin
    if not LRule.Enabled then
      Continue;
    if LRule.SourceGateKey <> ASourceGateKey then
      Continue;
    // 检查有效期
    if (LRule.ExpiredAt > 0) and (Now > LRule.ExpiredAt) then
      Continue;
    if Now < LRule.EffectiveFrom then
      Continue;
    // 评估条件表达式
    try
      if FJsonLogic.ApplyStr(LRule.ConditionExpr, APayload) then
        Exit(LRule);
    except
      // JsonLogic 表达式错误时跳过该规则，不崩溃
      Continue;
    end;
  end;
  Result := nil;
end;

function TRouteResolver.Resolve(const ASourceGateKey: string;
  APayload: TJSONObject): string;
var
  LRule: TRouteRule;
begin
  // 清空上次决策
  FLastDecision.SourceGateKey := ASourceGateKey;
  FLastDecision.MatchedRuleId := '';
  FLastDecision.TargetKey := '';
  FLastDecision.FallbackUsed := False;
  FLastDecision.ReasonCode := '';

  LRule := FindMatchingRule(ASourceGateKey, APayload);
  if LRule <> nil then
  begin
    FLastDecision.MatchedRuleId := LRule.Id;
    FLastDecision.TargetKey := LRule.TargetKey;
    FLastDecision.ReasonCode := 'route.matched';
    Result := LRule.TargetKey;
  end
  else
  begin
    Result := GetFallback(ASourceGateKey);
    FLastDecision.TargetKey := Result;
    if Result <> '' then
    begin
      FLastDecision.FallbackUsed := True;
      FLastDecision.ReasonCode := 'route.fallback_used';
    end
    else
      FLastDecision.ReasonCode := 'route.no_match';
  end;
end;

function TRouteResolver.GetFallback(const ASourceGateKey: string): string;
begin
  if not FFallbacks.TryGetValue(ASourceGateKey, Result) then
    Result := '';
end;

procedure TRouteResolver.ReloadRules;
var
  LAllRules: TObjectList<TRouteRule>;
  LRule: TRouteRule;
  LNewRule: TRouteRule;
begin
  if FRouteStore = nil then
    Exit;

  // 从 RouteStore 加载所有启用的规则
  LAllRules := FRouteStore.LoadAll;
  try
    ClearRules;
    // GOV-019: clear stale fallbacks so old entries from a previous load do
    // not survive a rule reload.
    FFallbacks.Clear;
    for LRule in LAllRules do
    begin
      // 复制规则到本地列表（RouteStore 返回的列表拥有对象所有权）
      LNewRule := TRouteRule.Create(
        LRule.Id,
        LRule.SourceGateKey,
        LRule.ConditionExpr,
        LRule.TargetType,
        LRule.TargetKey,
        LRule.Priority);
      LNewRule.Version := LRule.Version;
      LNewRule.Enabled := LRule.Enabled;
      LNewRule.EffectiveFrom := LRule.EffectiveFrom;
      LNewRule.ExpiredAt := LRule.ExpiredAt;
      LNewRule.RiskLevel := LRule.RiskLevel;
      LNewRule.FallbackTarget := LRule.FallbackTarget;
      LNewRule.Description := LRule.Description;

      // 如果规则有 FallbackTarget，注册为 Fallback
      if LNewRule.FallbackTarget <> '' then
        SetFallback(LNewRule.SourceGateKey, LNewRule.FallbackTarget);

      AddRule(LNewRule);
    end;
  finally
    LAllRules.Free;
  end;
end;

end.
