// AI-GENERATED
// DeepBase.Governance.ProjectionResolver.pas
// 第四层：GateState → UI 属性映射
// 依赖 Interfaces + GateResolver

unit DeepBase.Governance.ProjectionResolver;

interface

uses
  System.SysUtils,
  System.JSON,
  System.Generics.Collections,
  DeepBase.Governance.Types,
  DeepBase.Governance.Interfaces;

type
  /// 投射绑定项
  TProjectionBinding = record
    Key: string;           // Action 或 Gate 的 Key
    EnabledExpr: string;   // 启用条件（简单表达式或 GateKey）
    HintTemplate: string;  // Hint 模板（支持 {state} 占位符）
  end;

  /// 投射引擎实现
  TProjectionResolver = class(TInterfacedObject, IProjectionResolver)
  private
    FGateResolver: IGateResolver;
    FBindings: TDictionary<string, TProjectionBinding>;
    FCache: TDictionary<string, Boolean>;
    FCacheContext: TJSONObject;
  public
    constructor Create(AGateResolver: IGateResolver);
    destructor Destroy; override;

    // 绑定管理
    procedure Bind(const AKey, AGateKey: string; const AHintTemplate: string = '');
    procedure Unbind(const AKey: string);

    // IProjectionResolver
    function GetEnabled(const AKey: string; AContext: TJSONObject): Boolean;
    function GetHint(const AKey: string; AContext: TJSONObject): string;
    procedure RefreshAll;
  end;

implementation

{ TProjectionResolver }

constructor TProjectionResolver.Create(AGateResolver: IGateResolver);
begin
  inherited Create;
  FGateResolver := AGateResolver;
  FBindings := TDictionary<string, TProjectionBinding>.Create;
  FCache := TDictionary<string, Boolean>.Create;
  FCacheContext := nil;
end;

destructor TProjectionResolver.Destroy;
begin
  FCache.Free;
  FBindings.Free;
  inherited;
end;

procedure TProjectionResolver.Bind(const AKey, AGateKey, AHintTemplate: string);
var
  LBinding: TProjectionBinding;
begin
  LBinding.Key := AKey;
  LBinding.EnabledExpr := AGateKey;
  LBinding.HintTemplate := AHintTemplate;
  FBindings.AddOrSetValue(AKey, LBinding);
end;

procedure TProjectionResolver.Unbind(const AKey: string);
begin
  FBindings.Remove(AKey);
  FCache.Remove(AKey);
end;

function TProjectionResolver.GetEnabled(const AKey: string;
  AContext: TJSONObject): Boolean;
var
  LBinding: TProjectionBinding;
  LResolution: TGateResolution;
begin
  // 检查缓存
  if (AContext = FCacheContext) and FCache.TryGetValue(AKey, Result) then
    Exit;

  if not FBindings.TryGetValue(AKey, LBinding) then
    Exit(True); // 无绑定时默认启用

  // 通过 GateResolver 判断
  LResolution := FGateResolver.Resolve(LBinding.EnabledExpr, AContext);
  Result := LResolution.State = gsOpen;

  // 更新缓存
  FCacheContext := AContext;
  FCache.AddOrSetValue(AKey, Result);
end;

function TProjectionResolver.GetHint(const AKey: string;
  AContext: TJSONObject): string;
var
  LBinding: TProjectionBinding;
  LResolution: TGateResolution;
  LStateStr: string;
begin
  if not FBindings.TryGetValue(AKey, LBinding) then
    Exit('');

  if LBinding.HintTemplate = '' then
  begin
    // 默认：如果被阻挡，返回阻挡原因
    LResolution := FGateResolver.Resolve(LBinding.EnabledExpr, AContext);
    if LResolution.State <> gsOpen then
      Exit(LResolution.BlockedReason);
    Exit('');
  end;

  // 模板替换
  LResolution := FGateResolver.Resolve(LBinding.EnabledExpr, AContext);
  case LResolution.State of
    gsOpen:     LStateStr := 'Open';
    gsClosed:   LStateStr := 'Closed';
    gsDisabled: LStateStr := 'Disabled';
    gsBlocked:  LStateStr := 'Blocked';
    gsLocked:   LStateStr := 'Locked';
    gsFrozen:   LStateStr := 'Frozen';
    gsConflict: LStateStr := 'Conflict';
  end;

  Result := StringReplace(LBinding.HintTemplate, '{state}', LStateStr, [rfReplaceAll]);
  Result := StringReplace(Result, '{reason}', LResolution.BlockedReason, [rfReplaceAll]);
end;

procedure TProjectionResolver.RefreshAll;
begin
  FCache.Clear;
  FCacheContext := nil;
end;

end.
