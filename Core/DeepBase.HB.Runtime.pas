{ ============================================================================
  DeepBase.HB.Runtime - HB Runtime Central Coordinator & State Slot Registry

  Version: 2.0 (Delphi 13.1 on Win64 / Cross-Platform RTL)
  Description: Central runtime coordinator for HB Visual Infrastructure:
               - Lifecycle phase state machine and EHbLifecycleViolation assertion.
               - Pluggable State Slot registry with work order audit logging.
               - Thread-safe registry operations with overwrite tolerance.
               Complies with docs/29.ui-runtime.md v2.0.
  ============================================================================ }

unit DeepBase.HB.Runtime;

{ IMPLICIT_STRING_CAST OFF}

interface

uses
  System.SysUtils,
  System.Classes,
  System.DateUtils,
  System.SyncObjs,
  System.Generics.Collections,
  DeepBase.HB.StateSlot.Types;

type
  /// <summary>
  /// 控件生命周期阶段状态机
  /// </summary>
  THbLifecyclePhase = (
    lpCreated,             // 步骤 1: 实例化已完成
    lpTokenBound,          // 步骤 2: 绑定设计令牌（已满足 Paint 前置断言底线）
    lpStateBound,          // 步骤 3: 绑定两轴基础状态 (Visual/Action)
    lpTouchpointAttached,  // 步骤 4: 挂载触点契约（可选）
    lpRendered,            // 步骤 5: 渲染完成并已触发 EmitTelemetry
    lpDisposed             // 步骤 7: 控件已完成销毁与资源释放
  );

  /// <summary>
  /// 违反 HB 控件生命周期顺序或未满足 Paint 断言时抛出的强类型异常
  /// </summary>
  EHbLifecycleViolation = class(Exception)
  private
    FControlClassName: string;
    FCurrentPhase: THbLifecyclePhase;
  public
    constructor Create(const AControlClassName: string; ACurrentPhase: THbLifecyclePhase); reintroduce; overload;
    constructor Create(const AMessage: string); reintroduce; overload;
    property ControlClassName: string read FControlClassName;
    property CurrentPhase: THbLifecyclePhase read FCurrentPhase;
  end;

  /// <summary>
  /// 状态槽注册审计记录
  /// </summary>
  THbStateSlotAuditRecord = record
    WorkOrder: string;
    SlotId: string;
    RegisteredAtUtc: Int64;
    ProviderClass: string;
  end;

  /// <summary>
  /// HB 运行时治理中枢
  /// </summary>
  THbRuntime = class
  private
    class var FLock: TCriticalSection;
    class var FSlots: TDictionary<string, IHbStateSlotProvider>;
    class var FAuditLog: TList<THbStateSlotAuditRecord>;
    class constructor ClassCreate;
    class destructor ClassDestroy;
  public
    /// <summary>显式注册状态槽并记录工单审计（支持后注册覆盖）</summary>
    class procedure RegisterStateSlot(const AWorkOrder: string; const ASlot: IHbStateSlotProvider);
    /// <summary>按 SlotId 获取状态槽提供者（未找到抛异常）</summary>
    class function GetStateSlot(const ASlotId: string): IHbStateSlotProvider;
    /// <summary>尝试获取状态槽提供者</summary>
    class function TryGetStateSlot(const ASlotId: string; out ASlot: IHbStateSlotProvider): Boolean;
    /// <summary>获取所有已注册的 SlotId 列表</summary>
    class function GetRegisteredSlotIds: TArray<string>;
    /// <summary>获取状态槽注册的完整审计链</summary>
    class function GetStateSlotAuditLog: TArray<THbStateSlotAuditRecord>;
    /// <summary>重置注册表与审计日志（供单元测试隔离使用）</summary>
    class procedure ResetRegistry;
  end;

implementation

{ EHbLifecycleViolation }

constructor EHbLifecycleViolation.Create(const AControlClassName: string; ACurrentPhase: THbLifecyclePhase);
begin
  FControlClassName := AControlClassName;
  FCurrentPhase := ACurrentPhase;
  inherited Create(Format(
    'HB Control [%s] entered Paint before completing lifecycle Token/State binding (Current Phase: %d)',
    [AControlClassName, Ord(ACurrentPhase)]));
end;

constructor EHbLifecycleViolation.Create(const AMessage: string);
begin
  FControlClassName := '';
  FCurrentPhase := lpCreated;
  inherited Create(AMessage);
end;

{ THbRuntime }

class constructor THbRuntime.ClassCreate;
begin
  FLock := TCriticalSection.Create;
  FSlots := TDictionary<string, IHbStateSlotProvider>.Create;
  FAuditLog := TList<THbStateSlotAuditRecord>.Create;
end;

class destructor THbRuntime.ClassDestroy;
begin
  FAuditLog.Free;
  FSlots.Free;
  FLock.Free;
end;

class procedure THbRuntime.RegisterStateSlot(const AWorkOrder: string; const ASlot: IHbStateSlotProvider);
var
  SlotId: string;
  Rec: THbStateSlotAuditRecord;
  ClassNameStr: string;
begin
  if ASlot = nil then
    raise EArgumentNilException.Create('State slot provider cannot be nil');

  SlotId := ASlot.GetSlotId.Trim;
  if SlotId = '' then
    raise EArgumentException.Create('State slot provider returned empty SlotId');

  ClassNameStr := 'Unknown';
  try
    if TObject(ASlot) is TObject then
      ClassNameStr := (ASlot as TObject).ClassName;
  except
    ClassNameStr := 'IHbStateSlotProvider';
  end;

  FLock.Enter;
  try
    FSlots.AddOrSetValue(SlotId, ASlot);

    Rec.WorkOrder := AWorkOrder;
    Rec.SlotId := SlotId;
    Rec.RegisteredAtUtc := DateTimeToUnix(TTimeZone.Local.ToUniversalTime(Now), False) * 1000;
    Rec.ProviderClass := ClassNameStr;
    FAuditLog.Add(Rec);
  finally
    FLock.Leave;
  end;
end;

class function THbRuntime.GetStateSlot(const ASlotId: string): IHbStateSlotProvider;
begin
  if not TryGetStateSlot(ASlotId, Result) then
    raise Exception.CreateFmt('State slot [%s] is not registered in THbRuntime', [ASlotId]);
end;

class function THbRuntime.TryGetStateSlot(const ASlotId: string; out ASlot: IHbStateSlotProvider): Boolean;
begin
  FLock.Enter;
  try
    Result := FSlots.TryGetValue(ASlotId.Trim, ASlot);
  finally
    FLock.Leave;
  end;
end;

class function THbRuntime.GetRegisteredSlotIds: TArray<string>;
begin
  FLock.Enter;
  try
    Result := FSlots.Keys.ToArray;
  finally
    FLock.Leave;
  end;
end;

class function THbRuntime.GetStateSlotAuditLog: TArray<THbStateSlotAuditRecord>;
begin
  FLock.Enter;
  try
    Result := FAuditLog.ToArray;
  finally
    FLock.Leave;
  end;
end;

class procedure THbRuntime.ResetRegistry;
begin
  FLock.Enter;
  try
    FSlots.Clear;
    FAuditLog.Clear;
  finally
    FLock.Leave;
  end;
end;

end.
