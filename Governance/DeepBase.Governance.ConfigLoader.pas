// AI-GENERATED
// DeepBase.Governance.ConfigLoader.pas
// P06：治理配置层 — 从 JSON 文件加载所有治理对象到 KeyResolver

unit DeepBase.Governance.ConfigLoader;

interface

uses
  System.SysUtils,
  System.IOUtils,
  System.JSON,
  System.Generics.Collections,
  DeepBase.Governance.Types,
  DeepBase.Governance.Model,
  DeepBase.Governance.KeyResolver,
  DeepBase.Governance.DueChecker,
  DeepBase.Governance.RouteResolver,
  DeepBase.Governance.FeedbackResolver,
  DeepBase.Governance.ProjectionResolver,
  DeepBase.Governance.Purpose,
  DeepBase.Governance.Output;

type
  TConfigLoader = class
  private
    FConfigDir: string;
    FKeyResolver: TKeyResolver;
    FDueChecker: TDueChecker;
    FRouteResolver: TRouteResolver;
    FFeedbackResolver: TFeedbackResolver;
    FProjectionResolver: TProjectionResolver;
    FPurposeSet: TPurposeSet;
    FOutputRegistry: TOutputRegistry;
    procedure LoadActions(const AFilePath: string);
    procedure LoadGates(const AFilePath: string);
    procedure LoadFields(const AFilePath: string);
    procedure LoadRoutes(const AFilePath: string);
    procedure LoadPurposes(const AFilePath: string);
    procedure LoadGovernanceConfig(const AFilePath: string);
    function FileContent(const AFileName: string): string;
    function RiskFromStr(const S: string): TRiskLevel;
    function GateTypeFromStr(const S: string): TGateType;
    function ConditionKindFromStr(const S: string): TGateConditionKind;
    function TargetTypeFromStr(const S: string): TRouteTargetType;
  public
    constructor Create(const AConfigDir: string;
      AKeyResolver: TKeyResolver;
      ADueChecker: TDueChecker;
      ARouteResolver: TRouteResolver;
      AFeedbackResolver: TFeedbackResolver;
      AProjectionResolver: TProjectionResolver;
      APurposeSet: TPurposeSet;
      AOutputRegistry: TOutputRegistry);

    /// 加载所有配置文件
    procedure LoadAll;

    /// 热更新：重新加载路由
    procedure ReloadRoutes;
  end;

implementation

{ TConfigLoader }

constructor TConfigLoader.Create(const AConfigDir: string;
  AKeyResolver: TKeyResolver; ADueChecker: TDueChecker;
  ARouteResolver: TRouteResolver; AFeedbackResolver: TFeedbackResolver;
  AProjectionResolver: TProjectionResolver; APurposeSet: TPurposeSet;
  AOutputRegistry: TOutputRegistry);
begin
  inherited Create;
  // DATA2-020: Normalize to resolve '..' / '.' segments and prevent
  // path-traversal escapes from the intended configuration directory.
  FConfigDir := TPath.GetFullPath(AConfigDir);
  FKeyResolver := AKeyResolver;
  FDueChecker := ADueChecker;
  FRouteResolver := ARouteResolver;
  FFeedbackResolver := AFeedbackResolver;
  FProjectionResolver := AProjectionResolver;
  FPurposeSet := APurposeSet;
  FOutputRegistry := AOutputRegistry;
end;

function TConfigLoader.FileContent(const AFileName: string): string;
var
  LPath, LResolved: string;
begin
  LPath := TPath.Combine(FConfigDir, AFileName);
  // DATA2-020: Resolve and verify the final path stays within FConfigDir.
  LResolved := TPath.GetFullPath(LPath);
  if not LResolved.StartsWith(FConfigDir, True) then
    raise EArgumentException.CreateFmt(
      'Config path "%s" escapes config directory "%s"', [AFileName, FConfigDir]);
  if TFile.Exists(LResolved) then
    Result := TFile.ReadAllText(LResolved, TEncoding.UTF8)
  else
    Result := '';
end;

function TConfigLoader.RiskFromStr(const S: string): TRiskLevel;
begin
  if S = 'L1' then Result := rlL1
  else if S = 'L2' then Result := rlL2
  else if S = 'L3' then Result := rlL3
  else Result := rlL0;
end;

function TConfigLoader.GateTypeFromStr(const S: string): TGateType;
begin
  if S = 'entry' then Result := gtEntry
  else if S = 'route' then Result := gtRoute
  else Result := gtAction;
end;

function TConfigLoader.ConditionKindFromStr(const S: string): TGateConditionKind;
begin
  if S = 'permission' then Result := gckPermission
  else if S = 'risk' then Result := gckRisk
  else if S = 'contract' then Result := gckContract
  else if S = 'evidence' then Result := gckEvidence
  else if S = 'seal' then Result := gckSeal
  else if S = 'accountability' then Result := gckAccountability
  else Result := gckState;
end;

function TConfigLoader.TargetTypeFromStr(const S: string): TRouteTargetType;
begin
  if S = 'gate' then Result := rttGate
  else if S = 'field' then Result := rttField
  else Result := rttAction;
end;

procedure TConfigLoader.LoadAll;
begin
  LoadPurposes('purposes.json');
  LoadFields('fields.json');
  LoadGates('gates.json');
  LoadActions('actions.json');
  LoadRoutes('routes.json');
  LoadGovernanceConfig('governance.json');
end;

procedure TConfigLoader.ReloadRoutes;
begin
  LoadRoutes('routes.json');
end;

procedure TConfigLoader.LoadActions(const AFilePath: string);
var
  LJson: string;
  LArr: TJSONArray;
  I: Integer;
  LObj: TJSONObject;
  LAction: TAction;
  LBridgeArr: TJSONArray;
  J: Integer;
begin
  LJson := FileContent(AFilePath);
  if LJson = '' then Exit;

  LArr := TJSONObject.ParseJSONValue(LJson) as TJSONArray;
  if LArr = nil then Exit;
  try
    for I := 0 to LArr.Count - 1 do
    begin
      LObj := LArr.Items[I] as TJSONObject;
      LAction := TAction.Create(
        LObj.GetValue<string>('key', ''),
        LObj.GetValue<string>('name', ''),
        RiskFromStr(LObj.GetValue<string>('risk_level', 'L0')),
        LObj.GetValue<string>('gate_key', ''),
        LObj.GetValue<string>('due_ref', ''),
        LObj.GetValue<string>('purpose_key', ''));

      // Bridge keys
      LBridgeArr := LObj.GetValue<TJSONArray>('bridge_keys');
      if LBridgeArr <> nil then
        for J := 0 to LBridgeArr.Count - 1 do
        begin
          LAction.AddBridgeKey(LBridgeArr.Items[J].Value);
          FKeyResolver.RegisterBridgeKey(LBridgeArr.Items[J].Value);
        end;

      FKeyResolver.RegisterAction(LAction);

      // Auto-register DueRule if due_ref present
      if LAction.DueRef <> '' then
        FDueChecker.AutoRegisterFromAction(LAction);
    end;
  finally
    LArr.Free;
  end;
end;

procedure TConfigLoader.LoadGates(const AFilePath: string);
var
  LJson: string;
  LArr: TJSONArray;
  I, J: Integer;
  LObj, LCondObj: TJSONObject;
  LGate: TAccessGate;
  LCondArr, LActionArr: TJSONArray;
begin
  LJson := FileContent(AFilePath);
  if LJson = '' then Exit;

  LArr := TJSONObject.ParseJSONValue(LJson) as TJSONArray;
  if LArr = nil then Exit;
  try
    for I := 0 to LArr.Count - 1 do
    begin
      LObj := LArr.Items[I] as TJSONObject;
      LGate := TAccessGate.Create(
        LObj.GetValue<string>('key', ''),
        LObj.GetValue<string>('name', ''),
        GateTypeFromStr(LObj.GetValue<string>('gate_type', 'action')),
        LObj.GetValue<string>('parent_key', ''),
        LObj.GetValue<string>('field_key', ''));

      // Action keys
      LActionArr := LObj.GetValue<TJSONArray>('action_keys');
      if LActionArr <> nil then
        for J := 0 to LActionArr.Count - 1 do
          LGate.AddActionKey(LActionArr.Items[J].Value);

      // Conditions
      LCondArr := LObj.GetValue<TJSONArray>('conditions');
      if LCondArr <> nil then
        for J := 0 to LCondArr.Count - 1 do
        begin
          LCondObj := LCondArr.Items[J] as TJSONObject;
          LGate.AddCondition(TGateCondition.Create(
            ConditionKindFromStr(LCondObj.GetValue<string>('kind', 'state')),
            LCondObj.GetValue<string>('expression', 'true'),
            LCondObj.GetValue<string>('description', ''),
            LCondObj.GetValue<string>('blocked_message', '')));
        end;

      FKeyResolver.RegisterGate(LGate);
    end;
  finally
    LArr.Free;
  end;
end;

procedure TConfigLoader.LoadFields(const AFilePath: string);
var
  LJson: string;
  LArr: TJSONArray;
  I: Integer;
  LObj: TJSONObject;
  LField: TContextField;
begin
  LJson := FileContent(AFilePath);
  if LJson = '' then Exit;

  LArr := TJSONObject.ParseJSONValue(LJson) as TJSONArray;
  if LArr = nil then Exit;
  try
    for I := 0 to LArr.Count - 1 do
    begin
      LObj := LArr.Items[I] as TJSONObject;
      LField := TContextField.Create(
        LObj.GetValue<string>('key', ''),
        LObj.GetValue<string>('name', ''),
        LObj.GetValue<string>('description', ''));
      FKeyResolver.RegisterField(LField);
    end;
  finally
    LArr.Free;
  end;
end;

procedure TConfigLoader.LoadRoutes(const AFilePath: string);
var
  LJson: string;
  LArr: TJSONArray;
  I: Integer;
  LObj: TJSONObject;
  LRule: TRouteRule;
begin
  LJson := FileContent(AFilePath);
  if LJson = '' then Exit;

  LArr := TJSONObject.ParseJSONValue(LJson) as TJSONArray;
  if LArr = nil then Exit;
  try
    FRouteResolver.ClearRules;
    for I := 0 to LArr.Count - 1 do
    begin
      LObj := LArr.Items[I] as TJSONObject;
      LRule := TRouteRule.Create(
        LObj.GetValue<string>('id', ''),
        LObj.GetValue<string>('source_gate_key', ''),
        LObj.GetValue<string>('condition_expr', 'true'),
        TargetTypeFromStr(LObj.GetValue<string>('target_type', 'action')),
        LObj.GetValue<string>('target_key', ''),
        LObj.GetValue<Integer>('priority', 0));
      LRule.Enabled := LObj.GetValue<Boolean>('enabled', True);
      LRule.RiskLevel := RiskFromStr(LObj.GetValue<string>('risk_level', 'L0'));
      LRule.FallbackTarget := LObj.GetValue<string>('fallback_target', '');
      LRule.Description := LObj.GetValue<string>('description', '');

      if LRule.FallbackTarget <> '' then
        FRouteResolver.SetFallback(LRule.SourceGateKey, LRule.FallbackTarget);

      FRouteResolver.AddRule(LRule);
    end;
  finally
    LArr.Free;
  end;
end;

procedure TConfigLoader.LoadPurposes(const AFilePath: string);
var
  LJson: string;
  LArr: TJSONArray;
  I: Integer;
  LObj: TJSONObject;
begin
  LJson := FileContent(AFilePath);
  if LJson = '' then Exit;

  LArr := TJSONObject.ParseJSONValue(LJson) as TJSONArray;
  if LArr = nil then Exit;
  try
    for I := 0 to LArr.Count - 1 do
    begin
      LObj := LArr.Items[I] as TJSONObject;
      FPurposeSet.Register(TPurpose.Create(
        LObj.GetValue<string>('key', ''),
        LObj.GetValue<string>('name', ''),
        LObj.GetValue<string>('description', ''),
        LObj.GetValue<string>('parent_key', '')));
    end;
  finally
    LArr.Free;
  end;
end;

procedure TConfigLoader.LoadGovernanceConfig(const AFilePath: string);
begin
  // 全局治理配置（Evidence 策略、热更新间隔等）
  // P06 最小实现：仅确认文件可读，具体策略在 P10 封存层实现
end;

end.
