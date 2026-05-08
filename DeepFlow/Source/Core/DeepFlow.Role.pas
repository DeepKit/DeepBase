unit DeepFlow.Role;

{*******************************************************************************
  DeepFlow.Role - 角色接口定义
  
  描述：
    定义 DeepFlow 11 角色的基础接口和抽象类。
    所有角色必须实现 IDeepFlowRole 接口。
    
  角色层级：
    L0 元层：Engine, Inspector
    L4 决策层：Commander, Dispatcher
    L3 智能层：Advisor
    L2 能力层：Executor, Guard, Quartermaster
    L1 基础层：Logistics, Chronicler, SignalOfficer
    
  作者：鲁班（开发者）
  日期：2025-12-04
  版本：1.0
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.JSON, DeepFlow.Message,
  DeepBase.Exceptions;

type
  /// <summary>角色层级</summary>
  TRoleLevel = (
    rlMeta,       // L0 元层
    rlDecision,   // L4 决策层
    rlIntelligence, // L3 智能层
    rlCapability, // L2 能力层
    rlFoundation  // L1 基础层
  );

  /// <summary>角色状态</summary>
  TRoleState = (
    rsUninitialized, // 未初始化
    rsInitializing,  // 初始化中
    rsReady,         // 就绪
    rsRunning,       // 运行中
    rsPaused,        // 暂停
    rsStopping,      // 停止中
    rsStopped,       // 已停止
    rsError          // 错误
  );

  /// <summary>信任级别</summary>
  TTrustLevel = (
    tlFullTrust,    // 完全信任（Engine/Inspector/Logistics/Chronicler）
    tlLimitedTrust, // 有限信任（Commander/Dispatcher/Guard/Quartermaster/SignalOfficer）
    tlUntrusted     // 不信任（Advisor/Executor）- 输出必须经过校验
  );

  /// <summary>角色元信息</summary>
  TRoleMetaInfo = record
    Name: string;
    DisplayName: string;
    Level: TRoleLevel;
    TrustLevel: TTrustLevel;
    Description: string;
    Version: string;
  end;

  /// <summary>DeepFlow 角色基础接口</summary>
  IDeepFlowRole = interface
    ['{A1B2C3D4-0001-0000-0000-000000000001}']
    /// <summary>获取角色名称</summary>
    function GetRoleName: string;
    /// <summary>获取角色元信息</summary>
    function GetMetaInfo: TRoleMetaInfo;
    /// <summary>获取角色状态</summary>
    function GetState: TRoleState;
    
    /// <summary>初始化角色</summary>
    procedure Initialize;
    /// <summary>启动角色</summary>
    procedure Start;
    /// <summary>停止角色</summary>
    procedure Stop;
    /// <summary>暂停角色</summary>
    procedure Pause;
    /// <summary>恢复角色</summary>
    procedure Resume;
    
    /// <summary>处理消息</summary>
    function HandleMessage(const AMessage: TDeepFlowMessage): TDeepFlowMessage;
    /// <summary>是否能处理指定类型的消息</summary>
    function CanHandle(const AMsgType: string): Boolean;
  end;

  /// <summary>角色基类（抽象）</summary>
  TDeepFlowRoleBase = class abstract(TInterfacedObject, IDeepFlowRole)
  private
    FState: TRoleState;
    FMetaInfo: TRoleMetaInfo;
  protected
    procedure SetState(const AState: TRoleState);
    procedure DoInitialize; virtual; abstract;
    procedure DoStart; virtual; abstract;
    procedure DoStop; virtual; abstract;
    function DoHandleMessage(const AMessage: TDeepFlowMessage): TDeepFlowMessage; virtual; abstract;
  public
    constructor Create(const AMetaInfo: TRoleMetaInfo);
    destructor Destroy; override;
    
    // IDeepFlowRole
    function GetRoleName: string;
    function GetMetaInfo: TRoleMetaInfo;
    function GetState: TRoleState;
    procedure Initialize;
    procedure Start;
    procedure Stop;
    procedure Pause; virtual;
    procedure Resume; virtual;
    function HandleMessage(const AMessage: TDeepFlowMessage): TDeepFlowMessage;
    function CanHandle(const AMsgType: string): Boolean; virtual;
    
    property State: TRoleState read FState;
    property MetaInfo: TRoleMetaInfo read FMetaInfo;
  end;

  // ============== 角色专用接口 ==============

  /// <summary>引擎接口 (L0)</summary>
  IEngine = interface(IDeepFlowRole)
    ['{A1B2C3D4-0001-0000-0000-000000000010}']
    procedure RegisterRole(const ARole: IDeepFlowRole);
    function GetRole(const ARoleName: string): IDeepFlowRole;
    procedure SubmitMessage(const AMessage: TDeepFlowMessage);
    function GetMetrics: TJSONObject;
  end;

  /// <summary>督察接口 (L0)</summary>
  IInspector = interface(IDeepFlowRole)
    ['{A1B2C3D4-0001-0000-0000-000000000011}']
    procedure Watch(const AComponent: string; const AMetrics: TJSONObject);
    function GetHealth(const AComponent: string): TJSONObject;
    procedure Audit(const AEvent: TJSONObject);
  end;

  /// <summary>指挥官接口 (L4)</summary>
  ICommander = interface(IDeepFlowRole)
    ['{A1B2C3D4-0001-0000-0000-000000000040}']
    function AnalyzeIntent(const AInput: string; const AContext: TJSONObject): TJSONObject;
    function Decompose(const AIntent: TJSONObject): TJSONArray;
    function Integrate(const AResults: TJSONArray): TJSONObject;
  end;

  /// <summary>调度员接口 (L4)</summary>
  IDispatcher = interface(IDeepFlowRole)
    ['{A1B2C3D4-0001-0000-0000-000000000041}']
    procedure Dispatch(const ATask: TJSONObject);
    function GetQueueLength: Integer;
    procedure PrioritizeTask(const ATaskId: string; const APriority: Integer);
  end;

  /// <summary>顾问接口 (L3)</summary>
  IAdvisor = interface(IDeepFlowRole)
    ['{A1B2C3D4-0001-0000-0000-000000000030}']
    function Consult(const APrompt: string; const AContext: TJSONObject): string;
    function ConsultStructured(const APrompt: string; const ASchema: TJSONObject): TJSONObject;
  end;

  /// <summary>执行者接口 (L2)</summary>
  IExecutor = interface(IDeepFlowRole)
    ['{A1B2C3D4-0001-0000-0000-000000000020}']
    function Execute(const ASkillName: string; const AInput: TJSONObject): TJSONObject;
  end;

  /// <summary>守卫接口 (L2)</summary>
  IGuard = interface(IDeepFlowRole)
    ['{A1B2C3D4-0001-0000-0000-000000000021}']
    function ValidateInput(const AInput: TJSONObject; const ASchema: TJSONObject): TJSONObject;
    function ValidateOutput(const AOutput: TJSONObject; const ASchema: TJSONObject): TJSONObject;
    function CheckSecurity(const AContent: string): TJSONObject;
    function DetectInjection(const AInput: string): Boolean;
  end;

  /// <summary>军需官接口 (L2)</summary>
  IQuartermaster = interface(IDeepFlowRole)
    ['{A1B2C3D4-0001-0000-0000-000000000022}']
    function Allocate(const AResourceType: string; const AAmount: Integer): TJSONObject;
    procedure Release(const AAllocationId: string);
    function CheckQuota(const AResourceType: string): TJSONObject;
  end;

  /// <summary>后勤接口 (L1)</summary>
  ILogistics = interface(IDeepFlowRole)
    ['{A1B2C3D4-0001-0000-0000-000000000010}']
    procedure Put(const ANamespace, AKey: string; const AValue: TJSONValue);
    function Get(const ANamespace, AKey: string): TJSONValue;
    procedure Delete(const ANamespace, AKey: string);
  end;

  /// <summary>记录员接口 (L1)</summary>
  IChronicler = interface(IDeepFlowRole)
    ['{A1B2C3D4-0001-0000-0000-000000000011}']
    procedure Log(const ALevel: string; const AComponent, AMessage: string; const ADetails: TJSONObject = nil);
    procedure AuditLog(const AEvent: TJSONObject);
    function QueryLogs(const AFilter: TJSONObject): TJSONArray;
  end;

  /// <summary>通信官接口 (L1)</summary>
  ISignalOfficer = interface(IDeepFlowRole)
    ['{A1B2C3D4-0001-0000-0000-000000000012}']
    function HttpGet(const AUrl: string): TJSONObject;
    function HttpPost(const AUrl: string; const ABody: TJSONObject): TJSONObject;
  end;

implementation

{ TDeepFlowRoleBase }

constructor TDeepFlowRoleBase.Create(const AMetaInfo: TRoleMetaInfo);
begin
  inherited Create;
  FMetaInfo := AMetaInfo;
  FState := rsUninitialized;
end;

destructor TDeepFlowRoleBase.Destroy;
begin
  if FState in [rsRunning, rsPaused] then
    Stop;
  inherited;
end;

function TDeepFlowRoleBase.GetRoleName: string;
begin
  Result := FMetaInfo.Name;
end;

function TDeepFlowRoleBase.GetMetaInfo: TRoleMetaInfo;
begin
  Result := FMetaInfo;
end;

function TDeepFlowRoleBase.GetState: TRoleState;
begin
  Result := FState;
end;

procedure TDeepFlowRoleBase.SetState(const AState: TRoleState);
begin
  FState := AState;
end;

procedure TDeepFlowRoleBase.Initialize;
begin
  if FState <> rsUninitialized then
    raise EOperationException.CreateFmt('Role %s already initialized', [FMetaInfo.Name]);
  
  SetState(rsInitializing);
  try
    DoInitialize;
    SetState(rsReady);
  except
    SetState(rsError);
    raise;
  end;
end;

procedure TDeepFlowRoleBase.Start;
begin
  if not (FState in [rsReady, rsStopped]) then
    raise EOperationException.CreateFmt('Role %s cannot start from state %d', [FMetaInfo.Name, Ord(FState)]);
  
  DoStart;
  SetState(rsRunning);
end;

procedure TDeepFlowRoleBase.Stop;
begin
  if not (FState in [rsRunning, rsPaused]) then
    Exit;
  
  SetState(rsStopping);
  try
    DoStop;
    SetState(rsStopped);
  except
    SetState(rsError);
    raise;
  end;
end;

procedure TDeepFlowRoleBase.Pause;
begin
  if FState = rsRunning then
    SetState(rsPaused);
end;

procedure TDeepFlowRoleBase.Resume;
begin
  if FState = rsPaused then
    SetState(rsRunning);
end;

function TDeepFlowRoleBase.HandleMessage(const AMessage: TDeepFlowMessage): TDeepFlowMessage;
begin
  if FState <> rsRunning then
    raise EOperationException.CreateFmt('Role %s is not running', [FMetaInfo.Name]);
  
  Result := DoHandleMessage(AMessage);
end;

function TDeepFlowRoleBase.CanHandle(const AMsgType: string): Boolean;
begin
  Result := True; // 子类可重写以限制处理的消息类型
end;

end.
