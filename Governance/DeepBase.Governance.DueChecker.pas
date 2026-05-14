// AI-GENERATED
// DeepBase.Governance.DueChecker.pas
// 第四层：合当判定（PASS/FAIL/FREEZE/CONFLICT）
// 依赖 Interfaces + Model

unit DeepBase.Governance.DueChecker;

interface

uses
  System.SysUtils,
  System.JSON,
  System.Generics.Collections,
  DeepBase.Governance.Types,
  DeepBase.Governance.Interfaces,
  DeepBase.Governance.Model;

type
  /// 合当规则检查器
  TDueRule = record
    ActionKey: string;
    RiskLevel: TRiskLevel;
    RequireEvidence: Boolean;
    RequireAccountability: Boolean;
    RequireConfirm: Boolean;
    RequireSeal: Boolean;
    Description: string;
  end;

  /// 合当引擎实现
  TDueChecker = class(TInterfacedObject, IDueChecker)
  private
    FRules: TDictionary<string, TDueRule>;
    FLastReasons: TDictionary<string, string>;
    FKeyResolver: IKeyResolver;
    function CheckRiskLevel(const AActionKey: string;
      AContext: TJSONObject): TDueResult;
    function HasAccountability(AContext: TJSONObject): Boolean;
    function HasConfirmation(AContext: TJSONObject): Boolean;
  public
    constructor Create(AKeyResolver: IKeyResolver);
    destructor Destroy; override;

    // 规则管理
    procedure RegisterRule(const ARule: TDueRule);
    procedure AutoRegisterFromAction(AAction: TAction);

    // IDueChecker
    function Check(const AActionKey: string;
      AContext: TJSONObject): TDueResult;
    function GetReason(const AActionKey: string): string;
  end;

implementation

{ TDueChecker }

constructor TDueChecker.Create(AKeyResolver: IKeyResolver);
begin
  inherited Create;
  FRules := TDictionary<string, TDueRule>.Create;
  FLastReasons := TDictionary<string, string>.Create;
  FKeyResolver := AKeyResolver;
end;

destructor TDueChecker.Destroy;
begin
  FLastReasons.Free;
  FRules.Free;
  inherited;
end;

procedure TDueChecker.RegisterRule(const ARule: TDueRule);
begin
  FRules.AddOrSetValue(ARule.ActionKey, ARule);
end;

procedure TDueChecker.AutoRegisterFromAction(AAction: TAction);
var
  LRule: TDueRule;
begin
  if AAction = nil then Exit;
  if AAction.DueRef = '' then Exit;

  LRule.ActionKey := AAction.Key;
  LRule.RiskLevel := AAction.RiskLevel;
  LRule.Description := AAction.DueRef;

  // 根据风险等级自动设置要求
  case AAction.RiskLevel of
    rlL0: begin
      LRule.RequireEvidence := False;
      LRule.RequireAccountability := False;
      LRule.RequireConfirm := False;
      LRule.RequireSeal := False;
    end;
    rlL1: begin
      LRule.RequireEvidence := True;
      LRule.RequireAccountability := False;
      LRule.RequireConfirm := False;
      LRule.RequireSeal := False;
    end;
    rlL2: begin
      LRule.RequireEvidence := True;
      LRule.RequireAccountability := True;
      LRule.RequireConfirm := False;
      LRule.RequireSeal := False;
    end;
    rlL3: begin
      LRule.RequireEvidence := True;
      LRule.RequireAccountability := True;
      LRule.RequireConfirm := True;
      LRule.RequireSeal := True;
    end;
  end;

  FRules.AddOrSetValue(AAction.Key, LRule);
end;

function TDueChecker.HasAccountability(AContext: TJSONObject): Boolean;
begin
  // 检查上下文中是否有 user_id（责任绑定）
  Result := (AContext <> nil) and (AContext.GetValue('user_id') <> nil);
end;

function TDueChecker.HasConfirmation(AContext: TJSONObject): Boolean;
begin
  // 检查上下文中是否有确认标记
  Result := (AContext <> nil) and (AContext.GetValue('confirmed') <> nil) and
    (AContext.GetValue<Boolean>('confirmed', False));
end;

function TDueChecker.CheckRiskLevel(const AActionKey: string;
  AContext: TJSONObject): TDueResult;
var
  LRule: TDueRule;
begin
  if not FRules.TryGetValue(AActionKey, LRule) then
    Exit(TDueResult.Pass); // 应由上层 Check 已处理，此处兜底

  // L2+: 需要责任绑定
  if LRule.RequireAccountability and not HasAccountability(AContext) then
  begin
    FLastReasons.AddOrSetValue(AActionKey,
      'due.missing_accountability: user_id required in context');
    Exit(TDueResult.Fail(
      'due.missing_accountability: L' + IntToStr(Ord(LRule.RiskLevel)) +
      ' action requires user_id in context'));
  end;

  // L3: 需要确认
  if LRule.RequireConfirm and not HasConfirmation(AContext) then
  begin
    FLastReasons.AddOrSetValue(AActionKey,
      'due.missing_confirmation: confirmed flag required in context');
    Exit(TDueResult.Freeze(
      'due.missing_confirmation: L3 action requires explicit confirmation'));
  end;

  Result := TDueResult.Pass;
end;

function TDueChecker.Check(const AActionKey: string;
  AContext: TJSONObject): TDueResult;
var
  LAction: TAction;
  LActionRisk: TRiskLevel;
begin
  LActionRisk := rlL0;

  // 先查 Action 的风险等级
  if FKeyResolver <> nil then
  begin
    LAction := FKeyResolver.ResolveActionKey(AActionKey);
    if LAction <> nil then
      LActionRisk := LAction.RiskLevel;
  end;

  // L0：无需治理，直接通过
  if LActionRisk = rlL0 then
    Exit(TDueResult.Pass);

  // L1+ 没有规则时的 fail-closed 策略（按风险分层）
  if not FRules.ContainsKey(AActionKey) then
  begin
    case LActionRisk of
      rlL1:
        begin
          // L1：允许警告通过，但记录原因
          FLastReasons.AddOrSetValue(AActionKey,
            'WARN: L1 action has no DuePolicy registered');
          Exit(TDueResult.Pass);  // L1 放行但带警告
        end;
      rlL2:
        begin
          // L2：fail-closed，缺规则必须阻断
          FLastReasons.AddOrSetValue(AActionKey,
            'due.missing_policy: L2 action requires DuePolicy');
          Exit(TDueResult.Fail(
            'due.missing_policy: L2 Action "' + AActionKey +
            '" requires DuePolicy but none is registered'));
        end;
      rlL3:
        begin
          // L3：fail-closed 且 Frozen，必须人工处理
          FLastReasons.AddOrSetValue(AActionKey,
            'due.missing_policy: L3 action requires full DuePolicy');
          Exit(TDueResult.Freeze(
            'due.missing_policy: L3 Action "' + AActionKey +
            '" requires complete DuePolicy (Permission+Confirm+Evidence+Accountability) but none is registered'));
        end;
    end;
  end;

  Result := CheckRiskLevel(AActionKey, AContext);
end;

function TDueChecker.GetReason(const AActionKey: string): string;
begin
  if not FLastReasons.TryGetValue(AActionKey, Result) then
    Result := '';
end;

end.
