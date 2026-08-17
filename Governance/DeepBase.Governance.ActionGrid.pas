// AI-GENERATED
// DeepBase.Governance.ActionGrid.pas
// 第四层：行为网格 — 行为注册、分发、启停
// 依赖 Interfaces + Model

unit DeepBase.Governance.ActionGrid;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
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
    FLock: TCriticalSection;
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
  // GOV-027 (BCW-A20260715-011): FActions MUST NOT own its TAction values.
  // Ownership of every TAction is held uniquely by TKeyResolver (its FActions
  // dictionary is [doOwnsValues], the authoritative key→object registry).
  // ActionGrid is only a runtime execution index. With doOwnsValues here too,
  // the same TAction was owned by two dictionaries — when both got freed
  // (KeyResolver then ActionGrid, in any teardown path), the second Free hit
  // an already-freed object → "Invalid pointer operation" / access violation.
  // This bug was latent in TGovernanceLifecycle (single Init/Shutdown rarely
  // reentered) and surfaced under the per-test Setup/TearDown of this fixture.
  FActions := TObjectDictionary<string, TAction>.Create([]);
  FBridges := TDictionary<string, IBridge>.Create;
  FDueChecker := ADueChecker;
  FLock := TCriticalSection.Create;
end;

destructor TActionGrid.Destroy;
begin
  FLock.Free;
  FBridges.Free;
  FActions.Free;
  inherited;
end;

procedure TActionGrid.RegisterBridge(const AKey: string; ABridge: IBridge);
begin
  // GOV-026: serialize all bridge dictionary mutations.
  FLock.Enter;
  try
    FBridges.AddOrSetValue(AKey, ABridge);
  finally
    FLock.Leave;
  end;
end;

procedure TActionGrid.RegisterAction(const AActionKey, ADisplayName: string;
  ARiskLevel: TRiskLevel);
var
  LAction: TAction;
begin
  LAction := TAction.Create(AActionKey, ADisplayName, ARiskLevel);
  FLock.Enter;
  try
    FActions.AddOrSetValue(AActionKey, LAction);
  finally
    FLock.Leave;
  end;
end;

procedure TActionGrid.RegisterActionObj(AAction: TAction);
begin
  if AAction = nil then
    raise EArgumentNilException.Create('AAction cannot be nil');
  FLock.Enter;
  try
    FActions.AddOrSetValue(AAction.Key, AAction);
  finally
    FLock.Leave;
  end;
end;

function TActionGrid.FindAction(const AActionKey: string): TAction;
begin
  FLock.Enter;
  try
    if not FActions.TryGetValue(AActionKey, Result) then
      Result := nil;
  finally
    FLock.Leave;
  end;
end;

function TActionGrid.CanRun(const AActionKey: string;
  AContext: TJSONObject): Boolean;
var
  LAction: TAction;
  LEnabled: Boolean;
  LDueRef: string;
begin
  // D-003: 读路径须持锁——热注册路径会改 FActions 容器（rehash）并按 key
  // 释放/替换 TAction 实例，裸读 TryGetValue 后持 LAction 引用在锁外访问会
  // 与并发 rehash 竞争（半更新/AV），同 key 重新注册甚至会释放该对象致 UAF。
  // 故锁内只把决策需要的值类型字段克隆到局部，锁外再跑慢速 DueChecker。
  LEnabled := False;
  LDueRef := '';
  FLock.Enter;
  try
    if not FActions.TryGetValue(AActionKey, LAction) then
      Exit(False);
    LEnabled := LAction.Enabled;
    LDueRef := LAction.DueRef;
  finally
    FLock.Leave;
  end;

  if not LEnabled then
    Exit(False);

  // 检查合当性（如果有 DueChecker）——放锁外，避免慢回调阻塞并发读
  if (FDueChecker <> nil) and (LDueRef <> '') then
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
  LEnabled: Boolean;
  LDisabledReason: string;
  LDueRef: string;
begin
  // D-003: 同 CanRun，锁内克隆值类型快照，锁外跑 DueChecker。
  LEnabled := False;
  LDisabledReason := '';
  LDueRef := '';
  FLock.Enter;
  try
    if not FActions.TryGetValue(AActionKey, LAction) then
      Exit('Action not found: ' + AActionKey);
    LEnabled := LAction.Enabled;
    LDisabledReason := LAction.DisabledReason;
    LDueRef := LAction.DueRef;
  finally
    FLock.Leave;
  end;

  if not LEnabled then
    Exit(LDisabledReason);

  if (FDueChecker <> nil) and (LDueRef <> '') then
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
  // D-003: 写 Enabled 字段须持锁——与热注册路径并发，否则可能写到一个正被
  // 释放/替换的 TAction 实例上（UAF）。
  FLock.Enter;
  try
    if FActions.TryGetValue(AActionKey, LAction) then
      LAction.Enabled := AEnabled;
  finally
    FLock.Leave;
  end;
end;

function TActionGrid.Run(const AActionKey: string; AContext: TJSONObject;
  AMode: TRunMode): TActionResult;
var
  LAction: TAction;
  LBridge: IBridge;
  LBridgeKey: string;
  LEnabled: Boolean;
  LDisabledReason: string;
  LDueRef: string;
  LBridges: TArray<string>;
  LBridgeRefs: TArray<IBridge>;
  LRefCount, I: Integer;
  LDue: TDueResult;
begin
  // D-003: 锁内克隆执行所需状态到值类型/接口局部，锁外再跑 DueChecker 与
  // Bridge.Execute——既避免锁内执行慢回调/外部调用死锁，也杜绝锁外持
  // TAction 引用期间同 key 重新注册被 doOwnsValues 释放所致的 UAF。
  // Bridge 接口引用计数会在锁内取引用时保活，锁外安全使用。
  LEnabled := False;
  LDisabledReason := '';
  LDueRef := '';
  LBridges := nil;
  LBridgeRefs := nil;
  LRefCount := 0;
  FLock.Enter;
  try
    if not FActions.TryGetValue(AActionKey, LAction) then
      Exit(TActionResult.Fail(AActionKey, 'Action not registered: ' + AActionKey));

    LEnabled := LAction.Enabled;
    LDisabledReason := LAction.DisabledReason;
    LDueRef := LAction.DueRef;
    if LAction.BridgeKeys.Count > 0 then
    begin
      LBridges := LAction.BridgeKeys.ToArray;
      SetLength(LBridgeRefs, Length(LBridges));
      LRefCount := 0;
      for LBridgeKey in LBridges do
      begin
        if FBridges.TryGetValue(LBridgeKey, LBridge) then
        begin
          LBridgeRefs[LRefCount] := LBridge;   // 引用计数 +1，锁外保活
          Inc(LRefCount);
        end;
      end;
      SetLength(LBridgeRefs, LRefCount);
    end;
  finally
    FLock.Leave;
  end;

  if not LEnabled then
    Exit(TActionResult.Blocked(AActionKey, LDisabledReason));

  // 合当检查——锁外跑，慢 DueChecker 不阻塞并发读
  if (AMode <> rmPreview) and (FDueChecker <> nil) and (LDueRef <> '') then
  begin
    LDue := FDueChecker.Check(AActionKey, AContext);
    if LDue.Verdict <> dvPass then
      raise Exception.CreateFmt('Due check failed for %s: %s',
        [AActionKey, LDue.Reason]);
  end;

  // Preview 模式只检查不执行
  if AMode = rmPreview then
    Exit(TActionResult.DryRunOK(AActionKey, 'Preview passed'));

  // 执行 Bridge 链——用锁内快���的引用数组，不再触碰 FBridges/LAction
  for I := 0 to High(LBridgeRefs) do
  begin
    LBridge := LBridgeRefs[I];
    if not LBridge.CanExecute(AContext) then
      Exit(TActionResult.Blocked(AActionKey,
        'Bridge not available: ' + LBridges[I]));

    Result := LBridge.Execute(AContext, AMode);
    if Result.Status <> arsSuccess then
      Exit;
  end;

  // 无 Bridge 时返回 dry-run（noop）状态而非 Success，以反映没有实际执行
  // any side effect (GOV-021).
  if Length(LBridgeRefs) = 0 then
    Result := TActionResult.DryRunOK(AActionKey, 'No bridge configured (noop)')
  else
    Result := TActionResult.Success(AActionKey);
end;

function TActionGrid.GetActionInfo(const AActionKey: string): TActionInfo;
var
  LAction: TAction;
begin
  // D-003: 读路径须持锁——与热注册路径并发会撞 rehash/UAF。锁内拷贝值类型字段到
  // 结果 record 即可，TActionInfo 全是值类型，锁外无悬空引用。
  FLock.Enter;
  try
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
  finally
    FLock.Leave;
  end;
end;

function TActionGrid.GetAllActions: TArray<TActionInfo>;
var
  LList: TList<TActionInfo>;
  LAction: TAction;
  LInfo: TActionInfo;
begin
  LList := TList<TActionInfo>.Create;
  try
    // D-003: 整个遍历持锁，避免遍历期间 FActions 被并发改动（rehash/释放
    // 正在迭代的 TAction）致 AV。直接在锁内构建 record，不再回调已加锁的
    // GetActionInfo（TCriticalSection 不可重入，二次 Enter 会死锁）。
    FLock.Enter;
    try
      for LAction in FActions.Values do
      begin
        LInfo.ActionKey := LAction.Key;
        LInfo.DisplayName := LAction.DisplayName;
        LInfo.Enabled := LAction.Enabled;
        LInfo.DisabledReason := LAction.DisabledReason;
        LInfo.RiskLevel := LAction.RiskLevel;
        LList.Add(LInfo);
      end;
    finally
      FLock.Leave;
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

end.
