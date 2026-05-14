// AI-GENERATED
// DeepBase.Governance.ActionGrid.pas
// 第四层：行为网格 — 行为注册、分发、启停
// 依赖 Interfaces + Model

unit DeepBase.Governance.ActionGrid;

interface

uses
  System.SysUtils,
  System.JSON,
  System.Generics.Collections,
  DeepBase.Governance.Types,
  DeepBase.Governance.Interfaces,
  DeepBase.Governance.Model;

type
  /// Bridge 注册项
  TBridgeEntry = record
    Key: string;
    Bridge: IBridge;
  end;

  /// 行为网格实现
  TActionGrid = class(TInterfacedObject, IActionGrid)
  private
    FActions: TObjectDictionary<string, TAction>;
    FBridges: TDictionary<string, IBridge>;
    FDueChecker: IDueChecker;
    procedure CheckDueIfRequired(const AActionKey: string; AContext: TJSONObject;
      AAction: TAction; AMode: TRunMode);
  public
    constructor Create(ADueChecker: IDueChecker);
    destructor Destroy; override;

    // Bridge 管理
    procedure RegisterBridge(const AKey: string; ABridge: IBridge);

    // IActionGrid
    procedure RegisterAction(const AActionKey: string; const ADisplayName: string;
      ARiskLevel: TRiskLevel);
    function Run(const AActionKey: string; AContext: TJSONObject;
      AMode: TRunMode): TActionResult;
    function CanRun(const AActionKey: string; AContext: TJSONObject): Boolean;
    function GetDisabledReason(const AActionKey: string;
      AContext: TJSONObject): string;
    procedure SetEnabled(const AActionKey: string; AEnabled: Boolean);
    function GetActionInfo(const AActionKey: string): TActionInfo;
    function GetAllActions: TArray<TActionInfo>;

    // 扩展
    procedure RegisterActionObj(AAction: TAction);
    function FindAction(const AActionKey: string): TAction;
  end;

implementation

{ TActionGrid }

constructor TActionGrid.Create(ADueChecker: IDueChecker);
begin
  inherited Create;
  FActions := TObjectDictionary<string, TAction>.Create([doOwnsValues]);
  FBridges := TDictionary<string, IBridge>.Create;
  FDueChecker := ADueChecker;
end;

destructor TActionGrid.Destroy;
begin
  FBridges.Free;
  FActions.Free;
  inherited;
end;

procedure TActionGrid.RegisterBridge(const AKey: string; ABridge: IBridge);
begin
  FBridges.AddOrSetValue(AKey, ABridge);
end;

procedure TActionGrid.RegisterAction(const AActionKey, ADisplayName: string;
  ARiskLevel: TRiskLevel);
var
  LAction: TAction;
begin
  LAction := TAction.Create(AActionKey, ADisplayName, ARiskLevel);
  FActions.AddOrSetValue(AActionKey, LAction);
end;

procedure TActionGrid.RegisterActionObj(AAction: TAction);
begin
  if AAction = nil then
    raise EArgumentNilException.Create('AAction cannot be nil');
  FActions.AddOrSetValue(AAction.Key, AAction);
end;

function TActionGrid.FindAction(const AActionKey: string): TAction;
begin
  if not FActions.TryGetValue(AActionKey, Result) then
    Result := nil;
end;

function TActionGrid.CanRun(const AActionKey: string;
  AContext: TJSONObject): Boolean;
var
  LAction: TAction;
begin
  if not FActions.TryGetValue(AActionKey, LAction) then
    Exit(False);

  if not LAction.Enabled then
    Exit(False);

  // 检查合当性（如果有 DueChecker）
  if (FDueChecker <> nil) and (LAction.DueRef <> '') then
  begin
    var LDue := FDueChecker.Check(AActionKey, AContext);
    if LDue.Verdict <> dvPass then
      Exit(False);
  end;

  Result := True;
end;

function TActionGrid.GetDisabledReason(const AActionKey: string;
  AContext: TJSONObject): string;
var
  LAction: TAction;
begin
  if not FActions.TryGetValue(AActionKey, LAction) then
    Exit('Action not found: ' + AActionKey);

  if not LAction.Enabled then
    Exit(LAction.DisabledReason);

  if (FDueChecker <> nil) and (LAction.DueRef <> '') then
  begin
    var LDue := FDueChecker.Check(AActionKey, AContext);
    if LDue.Verdict <> dvPass then
      Exit(LDue.Reason);
  end;

  Result := '';
end;

procedure TActionGrid.SetEnabled(const AActionKey: string; AEnabled: Boolean);
var
  LAction: TAction;
begin
  if FActions.TryGetValue(AActionKey, LAction) then
    LAction.Enabled := AEnabled;
end;

procedure TActionGrid.CheckDueIfRequired(const AActionKey: string;
  AContext: TJSONObject; AAction: TAction; AMode: TRunMode);
var
  LDue: TDueResult;
begin
  if (FDueChecker = nil) or (AAction.DueRef = '') then
    Exit;
  if AMode = rmPreview then
    Exit;

  LDue := FDueChecker.Check(AActionKey, AContext);
  if LDue.Verdict <> dvPass then
    raise Exception.CreateFmt('Due check failed for %s: %s',
      [AActionKey, LDue.Reason]);
end;

function TActionGrid.Run(const AActionKey: string; AContext: TJSONObject;
  AMode: TRunMode): TActionResult;
var
  LAction: TAction;
  LBridge: IBridge;
  LBridgeKey: string;
begin
  if not FActions.TryGetValue(AActionKey, LAction) then
    Exit(TActionResult.Fail(AActionKey, 'Action not registered: ' + AActionKey));

  if not LAction.Enabled then
    Exit(TActionResult.Blocked(AActionKey, LAction.DisabledReason));

  // 合当检查
  CheckDueIfRequired(AActionKey, AContext, LAction, AMode);

  // Preview 模式只检查不执行
  if AMode = rmPreview then
    Exit(TActionResult.DryRunOK(AActionKey, 'Preview passed'));

  // 执行 Bridge 链
  for LBridgeKey in LAction.BridgeKeys do
  begin
    if FBridges.TryGetValue(LBridgeKey, LBridge) then
    begin
      if not LBridge.CanExecute(AContext) then
        Exit(TActionResult.Blocked(AActionKey,
          'Bridge not available: ' + LBridgeKey));

      Result := LBridge.Execute(AContext, AMode);
      if Result.Status <> arsSuccess then
        Exit;
    end;
  end;

  // 无 Bridge 时返回成功（空 Action）
  if LAction.BridgeKeys.Count = 0 then
    Result := TActionResult.Success(AActionKey, 'No bridge configured')
  else
    Result := TActionResult.Success(AActionKey);
end;

function TActionGrid.GetActionInfo(const AActionKey: string): TActionInfo;
var
  LAction: TAction;
begin
  if FActions.TryGetValue(AActionKey, LAction) then
  begin
    Result.ActionKey := LAction.Key;
    Result.DisplayName := LAction.DisplayName;
    Result.Enabled := LAction.Enabled;
    Result.DisabledReason := LAction.DisabledReason;
    Result.RiskLevel := LAction.RiskLevel;
  end
  else
  begin
    Result.ActionKey := AActionKey;
    Result.DisplayName := '';
    Result.Enabled := False;
    Result.DisabledReason := 'Not found';
    Result.RiskLevel := rlL0;
  end;
end;

function TActionGrid.GetAllActions: TArray<TActionInfo>;
var
  LList: TList<TActionInfo>;
  LAction: TAction;
begin
  LList := TList<TActionInfo>.Create;
  try
    for LAction in FActions.Values do
      LList.Add(GetActionInfo(LAction.Key));
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

end.
