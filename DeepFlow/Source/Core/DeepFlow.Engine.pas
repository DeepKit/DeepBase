unit DeepFlow.Engine;

{*******************************************************************************
  DeepFlow.Engine - 引擎核心
  
  描述：
    DeepFlow 引擎负责消息循环、角色管理和消息路由。
    这是整个系统的调度中心。
    
  职责：
    - 消息队列管理（优先级队列）
    - 角色注册与生命周期管理
    - 消息路由与分发
    - 系统指标收集
    
  作者：鲁班（开发者）
  日期：2025-12-04
  版本：1.0
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.SyncObjs,
  System.Generics.Collections, System.Generics.Defaults,
  DeepFlow.Message, DeepFlow.Role, DeepFlow.Config,
  DeepBase.Exceptions;

type
  /// <summary>引擎状态</summary>
  TEngineState = (
    esUninitialized,
    esInitializing,
    esReady,
    esRunning,
    esStopping,
    esStopped,
    esError
  );

  /// <summary>消息处理回调</summary>
  TMessageCallback = reference to procedure(const AMessage: TDeepFlowMessage);

  /// <summary>
  /// GOV-R3-006 (D-006): SendSync 的每调用等待器。持有一个事件与一个响应对象，
  /// 按 MsgId 注册到 FResponseWaiters 字典，分发时按 CorrelationId 查找，
  /// 使多个并发 SendSync 各自的等待器互不覆盖（原单槽 FResponseSink 会互相覆盖）。
  /// </summary>
  TResponseWaiter = class
  private
    FEvent: TEvent;
    FResponse: TDeepFlowMessage;
  public
    constructor Create;
    destructor Destroy; override;
    property Event: TEvent read FEvent;
    property Response: TDeepFlowMessage read FResponse write FResponse;
  end;

  /// <summary>DeepFlow 引擎</summary>
  TDeepFlowEngine = class(TInterfacedObject, IEngine)
  private
    FState: TEngineState;
    FConfig: TDeepFlowConfig;
    FOwnsConfig: Boolean;
    
    // 角色管理
    FRoles: TDictionary<string, IDeepFlowRole>;
    FRoleLock: TCriticalSection;
    
    // 消息队列（按优先级排序）
    FMessageQueue: TList<TDeepFlowMessage>;
    FQueueLock: TCriticalSection;
    FQueueEvent: TEvent;
    
    // 消息处理线程
    FWorkerThread: TThread;
    FStopFlag: Boolean;
    FPaused: Boolean;
    FPauseEvent: TEvent;
    
    // 指标
    FMessagesProcessed: Int64;
    FMessagesDropped: Int64;
    FStartTime: TDateTime;
    
    // 回调
    FOnMessageProcessed: TMessageCallback;
    FOnMessageDropped: TMessageCallback;
    // DATA2-009 / GOV-R3-006 (D-006): Per-call response waiters keyed by
    // request MsgId, so concurrent SendSync calls no longer clobber a single
    // shared sink (which made the first waiter's CorrelationId never match
    // and time out, silently dropping its response).
    FResponseWaiters: TObjectDictionary<string, TResponseWaiter>;
    FResponseSinkLock: TCriticalSection;

    // DATA2-036: 死信队列与重试统计
    FDeadLetterQueue: TList<TDeepFlowMessage>;
    FDeadLetterLock: TCriticalSection;
    FMessagesRetried: Int64;
    FMessagesDeadLettered: Int64;

    /// <summary>消息最大重试次数（超出后进入死信队列）</summary>
    CDefaultMaxRetries: Integer;

    procedure MessageLoop;
    procedure ProcessMessage(const AMessage: TDeepFlowMessage);
    procedure RouteMessage(const AMessage: TDeepFlowMessage);
    function CompareMessages(const Left, Right: TDeepFlowMessage): Integer;
    procedure InsertSorted(const AMessage: TDeepFlowMessage);
  protected
    // IDeepFlowRole 实现
    function GetRoleName: string;
    function GetMetaInfo: TRoleMetaInfo;
    function GetState: TRoleState;
    function HandleMessage(const AMessage: TDeepFlowMessage): TDeepFlowMessage;
    function CanHandle(const AMsgType: string): Boolean;
  public
    constructor Create; overload;
    constructor Create(const AConfig: TDeepFlowConfig); overload;
    destructor Destroy; override;
    // Lifecycle controls exposed publicly so tests and hosts can drive the
    // engine without going through the role interface.
    procedure Initialize;
    procedure Pause;
    procedure Resume;
    
    /// <summary>启动引擎</summary>
    procedure Start;
    /// <summary>停止引擎</summary>
    procedure Stop;

    /// <summary>从错误状态恢复引擎。
    /// <para>仅当引擎处于 esError 状态时可调用。调用后会重新初始化所有
    /// 未初始化的角色，并将状态转换回 esReady，允许再次 Start。</para>
    /// <para>调用前请确保导致错误的条件已修复（例如：角色配置已更正、
    /// 外部依赖已恢复等）。</para></summary>
    procedure Reset;

    // IEngine 实现
    /// <summary>注册角色</summary>
    procedure RegisterRole(const ARole: IDeepFlowRole);
    /// <summary>获取角色</summary>
    function GetRole(const ARoleName: string): IDeepFlowRole;
    /// <summary>提交消息</summary>
    procedure SubmitMessage(const AMessage: TDeepFlowMessage);
    /// <summary>获取系统指标</summary>
    function GetMetrics: TJSONObject;
    
    /// <summary>同步发送消息并等待响应</summary>
    function SendSync(const AMessage: TDeepFlowMessage; ATimeout: Integer = 30000): TDeepFlowMessage;
    
    /// <summary>获取所有已注册角色名</summary>
    function GetRegisteredRoles: TArray<string>;

    /// <summary>获取死信队列的快照（克隆）。
    /// <para>死信队列存放重试次数耗尽仍处理失败的消息，供后续人工或自动化排查。</para></summary>
    function GetDeadLetterQueue: TArray<TDeepFlowMessage>;

    property State: TEngineState read FState;
    property Config: TDeepFlowConfig read FConfig;
    property MessagesProcessed: Int64 read FMessagesProcessed;
    property MessagesDropped: Int64 read FMessagesDropped;
    /// <summary>进入死信队列的消息总数</summary>
    property MessagesDeadLettered: Int64 read FMessagesDeadLettered;
    
    property OnMessageProcessed: TMessageCallback read FOnMessageProcessed write FOnMessageProcessed;
    property OnMessageDropped: TMessageCallback read FOnMessageDropped write FOnMessageDropped;
  end;

/// <summary>全局引擎实例</summary>
function Engine: TDeepFlowEngine;

implementation

uses
  System.DateUtils
  {$IFDEF MSWINDOWS}, Winapi.Windows{$ENDIF};

var
  _Engine: TDeepFlowEngine = nil;

function Engine: TDeepFlowEngine;
begin
  if _Engine = nil then
    _Engine := TDeepFlowEngine.Create;
  Result := _Engine;
end;

{ TResponseWaiter }

constructor TResponseWaiter.Create;
begin
  inherited Create;
  FEvent := TEvent.Create(nil, True {manual reset}, False {initially non-signaled}, '');
  FResponse := nil;
end;

destructor TResponseWaiter.Destroy;
begin
  FResponse.Free;
  FEvent.Free;
  inherited Destroy;
end;

{ TDeepFlowEngine }

constructor TDeepFlowEngine.Create;
begin
  Create(GlobalConfig);
  FOwnsConfig := False;  // 使用全局配置，不拥有
end;

constructor TDeepFlowEngine.Create(const AConfig: TDeepFlowConfig);
begin
  inherited Create;
  
  FConfig := AConfig;
  FOwnsConfig := True;
  FState := esUninitialized;
  FStopFlag := False;
  FPaused := False;
  FMessagesProcessed := 0;
  FMessagesDropped := 0;
  FMessagesRetried := 0;
  FMessagesDeadLettered := 0;
  CDefaultMaxRetries := 3;  // DATA2-036: 消息最大重试次数

  // 初始化同步对象
  FRoleLock := TCriticalSection.Create;
  FQueueLock := TCriticalSection.Create;
  FQueueEvent := TEvent.Create(nil, False, False, '');
  FPauseEvent := TEvent.Create(nil, True, True, '');  // Manual reset, initially signaled
  FResponseSinkLock := TCriticalSection.Create;
  FDeadLetterLock := TCriticalSection.Create;  // DATA2-036

  // 初始化集合
  FRoles := TDictionary<string, IDeepFlowRole>.Create;
  FMessageQueue := TList<TDeepFlowMessage>.Create;
  FDeadLetterQueue := TList<TDeepFlowMessage>.Create;  // DATA2-036
  // GOV-R3-006 (D-006): 字典 own values，确保 waiter 析构时释放 Event+Response。
  FResponseWaiters := TObjectDictionary<string, TResponseWaiter>.Create([doOwnsValues]);
end;

destructor TDeepFlowEngine.Destroy;
begin
  if FState = esRunning then
    Stop;
  
  // 清理消息队列
  FQueueLock.Enter;
  try
    while FMessageQueue.Count > 0 do
    begin
      FMessageQueue[0].Free;
      FMessageQueue.Delete(0);
    end;
  finally
    FQueueLock.Leave;
  end;
  
  FMessageQueue.Free;
  // DATA2-036: 清理死信队列
  FDeadLetterLock.Enter;
  try
    while FDeadLetterQueue.Count > 0 do
    begin
      FDeadLetterQueue[0].Free;
      FDeadLetterQueue.Delete(0);
    end;
  finally
    FDeadLetterLock.Leave;
  end;
  FDeadLetterQueue.Free;
  FDeadLetterLock.Free;
  FResponseWaiters.Free;  // GOV-R3-006 (D-006): doOwnsValues 释放各 waiter 及其 Event+Response
  FRoles.Free;
  FPauseEvent.Free;
  FQueueEvent.Free;
  FQueueLock.Free;
  FRoleLock.Free;
  FResponseSinkLock.Free;

  // BUG-442: FreeOnTerminate=False 后引擎显式拥有 worker 线程。若引擎未走 Stop 就被 Destroy
  // (FState=esRunning 时上面已调 Stop), 或 Stop 中途异常未及 FreeAndNil, 此处兜底释放。
  // TThread.Free 内部 WaitFor, 但若 worker 正阻塞且 FStopFlag 未置, 可能死等——
  // 故仅当 FWorkerThread 已为 nil (Stop 已释放) 或 FStopFlag 已置 (worker 将退出) 时才 Free。
  if Assigned(FWorkerThread) then
  begin
    FStopFlag := True;
    FPauseEvent.SetEvent;
    FQueueEvent.SetEvent;
    FreeAndNil(FWorkerThread);
  end;

  if FOwnsConfig and (FConfig <> GlobalConfig) then
    FConfig.Free;
  
  inherited;
end;

procedure TDeepFlowEngine.Initialize;
var
  RolePair: TPair<string, IDeepFlowRole>;
begin
  if FState <> esUninitialized then
    Exit;
  
  FState := esInitializing;
  
  // 初始化所有已注册角色
  FRoleLock.Enter;
  try
    for RolePair in FRoles do
    begin
      if RolePair.Value.GetState = rsUninitialized then
        RolePair.Value.Initialize;
    end;
  finally
    FRoleLock.Leave;
  end;
  
  FState := esReady;
end;

procedure TDeepFlowEngine.Start;
var
  RolePair: TPair<string, IDeepFlowRole>;
begin
  if FState = esUninitialized then
    Initialize;
  
  if FState <> esReady then
    raise EOperationException.Create('Engine cannot start: not in Ready state');
  
  FStartTime := Now;
  FStopFlag := False;
  
  // 启动所有角色
  FRoleLock.Enter;
  try
    for RolePair in FRoles do
    begin
      if RolePair.Value.GetState in [rsReady, rsStopped] then
        RolePair.Value.Start;
    end;
  finally
    FRoleLock.Leave;
  end;
  
  // 启动消息处理线程
  // BUG-442: 不用 FreeOnTerminate。FreeOnTerminate=True 时 worker 结束会自释放 TThread 对象，
  // 但 FWorkerThread 引用不清零 → 悬空指针; Stop 里 Assigned(FWorkerThread) 仍 True,
  // 访问 .Handle/.ThreadID 或 FreeAndNil 均命中已释放对象 → "Invalid pointer operation"/AV。
  // 改由引擎显式拥有: Stop 里 WaitFor 后 FreeAndNil(FWorkerThread), Destroy 兜底 Free。
  // MessageLoop 用 FStopFlag 轮询 (WaitFor 100ms timeout), Stop 置 FStopFlag:=True + SetEvent
  // 可让 worker 在 ~100ms 内退出 Execute, 此时显式 Free 安全 (TThread.Free 内部 WaitFor)。
  FWorkerThread := TThread.CreateAnonymousThread(MessageLoop);
  FWorkerThread.FreeOnTerminate := False;
  FWorkerThread.Start;
  
  FState := esRunning;
end;

procedure TDeepFlowEngine.Stop;
var
  RolePair: TPair<string, IDeepFlowRole>;
  LIsWorkerThread: Boolean;
begin
  if FState <> esRunning then
    Exit;

  FState := esStopping;
  FStopFlag := True;
  FPaused := False;

  // REVIEW5-GOV-002: Wake every wait point in MessageLoop, including Pause.
  FPauseEvent.SetEvent;
  FQueueEvent.SetEvent;

  // REVIEW5-GOV-002: Check if we're being called from the worker thread itself
  // (e.g., via system.shutdown message). If so, skip WaitFor to avoid deadlock.
  // DATA2-034: FWorkerThread may already be nil when FreeOnTerminate has freed it.
  LIsWorkerThread := Assigned(FWorkerThread) and
    (GetCurrentThreadId = FWorkerThread.ThreadID);

  if Assigned(FWorkerThread) and not LIsWorkerThread then
  begin
    // REVIEW5-GOV-002: Use timeout to prevent indefinite hang if worker is stuck
    if WaitForSingleObject(FWorkerThread.Handle, 5000) = WAIT_TIMEOUT then
    begin
      // Worker didn't exit in time - terminate it
      FWorkerThread.Terminate;
      WaitForSingleObject(FWorkerThread.Handle, 2000);
    end;
    // BUG-442: FreeOnTerminate=False 后 worker 不会自释放, 此处显式 WaitFor+Free 安全。
    // FWorkerThread 在 Stop 整个执行期间保持有效 (仅本线程访问), FreeAndNil 置 nil 防重复 Stop 再访问。
    FreeAndNil(FWorkerThread);
  end;

  // 停止所有角色
  FRoleLock.Enter;
  try
    for RolePair in FRoles do
    begin
      if RolePair.Value.GetState = rsRunning then
        RolePair.Value.Stop;
    end;
  finally
    FRoleLock.Leave;
  end;

  FState := esStopped;
end;

/// DATA2-027: 从错误状态恢复。
/// 重新初始化尚未初始化的角色，将状态转换回 esReady。
/// 仅当引擎处于 esError 状态时可调用。
procedure TDeepFlowEngine.Reset;
var
  RolePair: TPair<string, IDeepFlowRole>;
begin
  if FState <> esError then
    raise EOperationException.Create(
      'Engine can only be reset from esError state');

  // 重新初始化所有尚未初始化的角色
  FRoleLock.Enter;
  try
    for RolePair in FRoles do
    begin
      if RolePair.Value.GetState = rsUninitialized then
        try
          RolePair.Value.Initialize;
        except
          // 角色初始化失败不阻止引擎恢复，跳过该角色
        end;
    end;
  finally
    FRoleLock.Leave;
  end;

  FStopFlag := False;
  FPaused := False;
  FState := esReady;
end;

procedure TDeepFlowEngine.Pause;
begin
  // Suspend execution: running tasks complete but no new tasks start
  if FState <> esRunning then
    Exit;
  FPaused := True;
  FPauseEvent.ResetEvent;
end;

procedure TDeepFlowEngine.Resume;
begin
  // Resume execution: wake scheduler to continue processing
  if not FPaused then
    Exit;
  FPaused := False;
  FPauseEvent.SetEvent;
end;

procedure TDeepFlowEngine.RegisterRole(const ARole: IDeepFlowRole);
var
  RoleName: string;
begin
  RoleName := ARole.GetRoleName;
  
  FRoleLock.Enter;
  try
    if FRoles.ContainsKey(RoleName) then
      raise EOperationException.CreateFmt('Role %s already registered', [RoleName]);
    
    FRoles.Add(RoleName, ARole);
    
    // 如果引擎已运行，立即初始化并启动角色
    if FState = esRunning then
    begin
      if ARole.GetState = rsUninitialized then
        ARole.Initialize;
      if ARole.GetState = rsReady then
        ARole.Start;
    end;
  finally
    FRoleLock.Leave;
  end;
end;

function TDeepFlowEngine.GetRole(const ARoleName: string): IDeepFlowRole;
begin
  FRoleLock.Enter;
  try
    if not FRoles.TryGetValue(ARoleName, Result) then
      Result := nil;
  finally
    FRoleLock.Leave;
  end;
end;

function TDeepFlowEngine.GetRegisteredRoles: TArray<string>;
begin
  FRoleLock.Enter;
  try
    Result := FRoles.Keys.ToArray;
  finally
    FRoleLock.Leave;
  end;
end;

/// DATA2-036: 返回死信队列中所有消息的克隆快照。
/// 调用方负责释放返回数组中的每个 TDeepFlowMessage。
function TDeepFlowEngine.GetDeadLetterQueue: TArray<TDeepFlowMessage>;
var
  I: Integer;
begin
  FDeadLetterLock.Enter;
  try
    SetLength(Result, FDeadLetterQueue.Count);
    for I := 0 to FDeadLetterQueue.Count - 1 do
      Result[I] := FDeadLetterQueue[I].Clone;
  finally
    FDeadLetterLock.Leave;
  end;
end;

procedure TDeepFlowEngine.SubmitMessage(const AMessage: TDeepFlowMessage);
begin
  FQueueLock.Enter;
  try
    // 检查队列大小
    if FMessageQueue.Count >= FConfig.MessageQueueSize then
    begin
      Inc(FMessagesDropped);
      if Assigned(FOnMessageDropped) then
        FOnMessageDropped(AMessage);
      // DATA2-033: SubmitMessage 拥有消息所有权，队列满时必须释放以避免内存泄漏
      AMessage.Free;
      Exit;
    end;
    
    AMessage.Status := msQueued;
    InsertSorted(AMessage);
  finally
    FQueueLock.Leave;
  end;
  
  // 通知工作线程
  FQueueEvent.SetEvent;
end;

function TDeepFlowEngine.SendSync(const AMessage: TDeepFlowMessage; ATimeout: Integer): TDeepFlowMessage;
var
  LWaiter: TResponseWaiter;
  LMsgId: string;
  LOwnsWaiter: Boolean;
  LExisting: TResponseWaiter;
  LPair: TPair<string, TResponseWaiter>;
begin
  Result := nil;
  LMsgId := AMessage.MsgId;
  LWaiter := TResponseWaiter.Create;
  LOwnsWaiter := True;  // SendSync 自创建 waiter，初始拥有所有权

  // GOV-R3-006 (D-006): 按 MsgId 注册等待器到字典，而非覆盖单槽 FResponseSink。
  // 多个并发 SendSync 各自的等待器互不干扰，分发时按 CorrelationId 精确路由。
  // Response 对象由 waiter 持有所有权，超时或成功后随 waiter 一并释放。
  FResponseSinkLock.Enter;
  try
    // 若同 MsgId 已有等待器（理论上不应发生，MsgId 唯一），先摘出旧值由本调用
    // 不拥有它，避免 doOwnsValues 在 Add 时释放正在被旧调用使用的 waiter。
    if FResponseWaiters.TryGetValue(LMsgId, LExisting) then
      LPair := FResponseWaiters.ExtractPair(LMsgId);  // 旧 waiter 所有权移出字典，本调用不释放它
    FResponseWaiters.Add(LMsgId, LWaiter);
    LOwnsWaiter := False;  // 所有权移交字典（doOwnsValues）
  finally
    FResponseSinkLock.Leave;
  end;

  try
    SubmitMessage(AMessage);

    // 等待响应
    if LWaiter.Event.WaitFor(ATimeout) = wrSignaled then
    begin
      // 取走响应所有权，避免后续释放 waiter 时重复释放 Response。
      Result := LWaiter.Response;
      LWaiter.Response := nil;
    end;
    // 超时则 Result 保持 nil，waiter 内残留 Response 随摘除后释放。
  finally
    // 从字典摘除本等待器并取回所有权，统一由下方释放。
    // 用 ExtractPair：若仍指向本 waiter 则摘出并取回所有权；
    // 若已被同 MsgId 后续请求替换（理论上不应发生），则字典里已是新实例，
    // 本调用不再拥有原 waiter，避免误释放新实例。
    FResponseSinkLock.Enter;
    try
      if FResponseWaiters.TryGetValue(LMsgId, LExisting) and (LExisting = LWaiter) then
      begin
        FResponseWaiters.ExtractPair(LMsgId);  // doOwnsValues 字典 ExtractPair 后不再拥有 value
        LOwnsWaiter := True;                   // 所有权回到本调用
      end;
    finally
      FResponseSinkLock.Leave;
    end;
    if LOwnsWaiter then
      LWaiter.Free;  // 释放 waiter 及其残留 Response；Result 已摘出不受影响
  end;
end;

function TDeepFlowEngine.GetMetrics: TJSONObject;
var
  Uptime: Double;
  RoleCount: Integer;
  QueueSize: Integer;
begin
  Result := TJSONObject.Create;
  
  // 基础指标
  Uptime := SecondsBetween(Now, FStartTime);
  Result.AddPair('uptime_seconds', TJSONNumber.Create(Uptime));
  Result.AddPair('state', TJSONNumber.Create(Ord(FState)));
  Result.AddPair('messages_processed', TJSONNumber.Create(FMessagesProcessed));
  Result.AddPair('messages_dropped', TJSONNumber.Create(FMessagesDropped));
  // DATA2-036: 重试与死信指标
  Result.AddPair('messages_retried', TJSONNumber.Create(FMessagesRetried));
  Result.AddPair('messages_dead_lettered', TJSONNumber.Create(FMessagesDeadLettered));
  
  // 角色数量
  FRoleLock.Enter;
  try
    RoleCount := FRoles.Count;
  finally
    FRoleLock.Leave;
  end;
  Result.AddPair('registered_roles', TJSONNumber.Create(RoleCount));
  
  // 队列大小
  FQueueLock.Enter;
  try
    QueueSize := FMessageQueue.Count;
  finally
    FQueueLock.Leave;
  end;
  Result.AddPair('queue_size', TJSONNumber.Create(QueueSize));

  // DATA2-036: 死信队列大小
  FDeadLetterLock.Enter;
  try
    Result.AddPair('dead_letter_queue_size', TJSONNumber.Create(FDeadLetterQueue.Count));
  finally
    FDeadLetterLock.Leave;
  end;
  
  // 吞吐率
  if Uptime > 0 then
    Result.AddPair('throughput_per_sec', TJSONNumber.Create(FMessagesProcessed / Uptime))
  else
    Result.AddPair('throughput_per_sec', TJSONNumber.Create(0));
end;

function TDeepFlowEngine.GetRoleName: string;
begin
  Result := 'Engine';
end;

function TDeepFlowEngine.GetMetaInfo: TRoleMetaInfo;
begin
  Result.Name := 'Engine';
  Result.DisplayName := '引擎';
  Result.Level := rlMeta;
  Result.TrustLevel := tlFullTrust;
  Result.Description := 'DeepFlow 核心引擎，负责消息调度和角色管理';
  Result.Version := '1.0';
end;

function TDeepFlowEngine.GetState: TRoleState;
begin
  // DATA2-042 fix: surface the paused state so callers can distinguish a
  // paused engine from a running one without polling a separate flag.
  if FPaused then
    Exit(rsPaused);

  case FState of
    esUninitialized: Result := rsUninitialized;
    esInitializing: Result := rsInitializing;
    esReady: Result := rsReady;
    esRunning: Result := rsRunning;
    esStopping: Result := rsStopping;
    esStopped: Result := rsStopped;
    esError: Result := rsError;
  else
    Result := rsUninitialized;
  end;
end;

function TDeepFlowEngine.HandleMessage(const AMessage: TDeepFlowMessage): TDeepFlowMessage;
begin
  // 引擎本身处理系统消息
  Result := nil;
  
  if AMessage.MsgType = 'system.shutdown' then
  begin
    Stop;
    Result := TResponseMessage.Create(AMessage);
    TResponseMessage(Result).Success := True;
  end
  else if AMessage.MsgType = 'system.status' then
  begin
    Result := TResponseMessage.Create(AMessage);
    TResponseMessage(Result).Success := True;
    TResponseMessage(Result).Payload.Free;
    TResponseMessage(Result).Payload := GetMetrics;
  end;
end;

function TDeepFlowEngine.CanHandle(const AMsgType: string): Boolean;
begin
  Result := AMsgType.StartsWith('system.');
end;

procedure TDeepFlowEngine.MessageLoop;
var
  Msg: TDeepFlowMessage;
  LWaitResult: TWaitResult;
begin
  // DATA2-034: 顶层异常保护——未捕获的异常不再直接终止工作线程，
  // 而是将引擎切换至 esError 状态，可通过 Reset 恢复。
  try
  while not FStopFlag do
  begin
    // REVIEW5-GOV-002: Wait for pause to be lifted before processing
    // Use timeout instead of INFINITE to allow checking FStopFlag periodically
    if FPaused then
    begin
      LWaitResult := FPauseEvent.WaitFor(100);
      if LWaitResult = wrTimeout then
        Continue;
    end;

    if FStopFlag then
      Break;

    // 等待消息或停止信号
    FQueueEvent.WaitFor(100);

    if FStopFlag then
      Break;

    // 处理队列中的消息
    while True do
    begin
      // Check pause state before each message
      if FPaused then
        Break;

      Msg := nil;

      FQueueLock.Enter;
      try
        if FMessageQueue.Count > 0 then
        begin
          Msg := FMessageQueue[0];
          FMessageQueue.Delete(0);
        end;
      finally
        FQueueLock.Leave;
      end;

      if Msg = nil then
        Break;

      try
        ProcessMessage(Msg);
      finally
        Msg.Free;
      end;
    end;
  end;
  except
    on E: Exception do
    begin
      FState := esError;
    end;
  end;
end;

/// DATA2-036: ProcessMessage 实现重试 + 死信队列协议。
/// <para>成功路径：消息被 Ack（状态 msCompleted，从队列移除，回调触发）。</para>
/// <para>失败路径：若 RetryCount &lt; Max，克隆消息并重新入队（带退避延迟）；
/// 否则移入死信队列，不再重试。</para>
procedure TDeepFlowEngine.ProcessMessage(const AMessage: TDeepFlowMessage);
var
  LSink: TMessageCallback;
  LMaxRetries: Integer;
  LRetryClone: TDeepFlowMessage;
  LResponseWaiter: TResponseWaiter;
  LCorrelationId: string;
  LRouted: Boolean;
begin
  AMessage.Status := msProcessing;

  try
    RouteMessage(AMessage);
    AMessage.Status := msCompleted;
    Inc(FMessagesProcessed);

    // DATA2-009 / GOV-R3-006 (D-006): 响应消息按 CorrelationId 路由到对应
    // SendSync 等待器（字典按请求 MsgId 分发），不再用单槽 sink。非响应消息
    // 或无匹配等待器时，回落到用户安装的 FOnMessageProcessed 回调。
    LSink := nil;
    LRouted := False;
    if FResponseSinkLock <> nil then
    begin
      FResponseSinkLock.Enter;
      try
        if AMessage is TResponseMessage then
        begin
          LCorrelationId := TResponseMessage(AMessage).CorrelationId;
          if (LCorrelationId <> '') and
             FResponseWaiters.TryGetValue(LCorrelationId, LResponseWaiter) then
          begin
            // 把响应克隆后交给等待器（调用方 SendSync 从 waiter.Response 取走所有权）。
            LResponseWaiter.Response := AMessage.Clone;
            LResponseWaiter.Event.SetEvent;
            LRouted := True;
          end;
        end;
        if (not LRouted) and Assigned(FOnMessageProcessed) then
          LSink := FOnMessageProcessed;
      finally
        FResponseSinkLock.Leave;
      end;
    end
    else if Assigned(FOnMessageProcessed) then
      LSink := FOnMessageProcessed;
    if Assigned(LSink) then
      LSink(AMessage);
  except
    on E: Exception do
    begin
      AMessage.Status := msFailed;

      // DATA2-036: 重试 / 死信逻辑。
      // 使用消息自身的 MaxRetries（若未显式设置则为 TDeepFlowMessage 默认值 3），
      // 同时参考引擎级 CDefaultMaxRetries 作为兜底。
      LMaxRetries := AMessage.MaxRetries;
      if LMaxRetries <= 0 then
        LMaxRetries := CDefaultMaxRetries;

      if AMessage.RetryCount < LMaxRetries then
      begin
        // 还有重试机会：克隆消息（保留 RetryCount），追加到队列尾部
        // 以实现自然 FIFO 退避（同优先级消息按入队顺序处理）。
        Inc(FMessagesRetried);
        LRetryClone := AMessage.Clone;
        LRetryClone.RetryCount := AMessage.RetryCount + 1;
        LRetryClone.Status := msQueued;

        FQueueLock.Enter;
        try
          if FMessageQueue.Count < FConfig.MessageQueueSize then
            // 追加到队尾，而非 InsertSorted 的优先级排序位置，
            // 让正在处理的消息之后的消息先被消费，实现轻量退避。
            FMessageQueue.Add(LRetryClone)
          else
          begin
            // 重试队列也满 → 直接进入死信队列
            LRetryClone.Free;
            LRetryClone := nil;
            FDeadLetterLock.Enter;
            try
              FDeadLetterQueue.Add(AMessage.Clone);
              Inc(FMessagesDeadLettered);
            finally
              FDeadLetterLock.Leave;
            end;
          end;
        finally
          FQueueLock.Leave;
        end;

        if Assigned(LRetryClone) then
          FQueueEvent.SetEvent;  // 通知工作线程有新消息
      end
      else
      begin
        // 重试耗尽 → 移入死信队列
        FDeadLetterLock.Enter;
        try
          FDeadLetterQueue.Add(AMessage.Clone);
          Inc(FMessagesDeadLettered);
        finally
          FDeadLetterLock.Leave;
        end;
      end;
    end;
  end;
end;

procedure TDeepFlowEngine.RouteMessage(const AMessage: TDeepFlowMessage);
var
  TargetRole: IDeepFlowRole;
  Response: TDeepFlowMessage;
  LClone: TDeepFlowMessage;
  LIsFirst: Boolean;
begin
  // 系统消息由引擎处理
  if CanHandle(AMessage.MsgType) then
  begin
    Response := HandleMessage(AMessage);
    if Response <> nil then
      SubmitMessage(Response);
    Exit;
  end;

  // 有明确目标的消息
  if AMessage.Target <> '' then
  begin
    TargetRole := GetRole(AMessage.Target);
    if Assigned(TargetRole) and TargetRole.CanHandle(AMessage.MsgType) then
    begin
      Response := TargetRole.HandleMessage(AMessage);
      if Response <> nil then
        SubmitMessage(Response);
    end;
    Exit;
  end;

  // DATA2-010: 广播消息 - 发送给所有能处理的角色。
  // 为避免一个订阅者对消息的修改影响其他订阅者，除第一个接收者外，
  // 其余订阅者均收到消息的克隆副本。
  FRoleLock.Enter;
  try
    LIsFirst := True;
    for var RolePair in FRoles do
    begin
      if RolePair.Value.CanHandle(AMessage.MsgType) then
      begin
        if LIsFirst then
        begin
          Response := RolePair.Value.HandleMessage(AMessage);
          LIsFirst := False;
        end
        else
        begin
          LClone := AMessage.Clone;
          try
            Response := RolePair.Value.HandleMessage(LClone);
          finally
            LClone.Free;
          end;
        end;
        if Response <> nil then
          SubmitMessage(Response);
      end;
    end;
  finally
    FRoleLock.Leave;
  end;
end;

function TDeepFlowEngine.CompareMessages(const Left, Right: TDeepFlowMessage): Integer;
begin
  // 优先级高的排前面
  Result := Ord(Right.Priority) - Ord(Left.Priority);
  if Result = 0 then
    // 同优先级按时间戳排序（先进先出）
    Result := CompareDateTime(Left.Timestamp, Right.Timestamp);
end;

procedure TDeepFlowEngine.InsertSorted(const AMessage: TDeepFlowMessage);
var
  LLow, LHigh, LMid: Integer;
begin
  // Binary search insertion (O(log N)) maintaining priority order
  LLow := 0;
  LHigh := FMessageQueue.Count - 1;
  while LLow <= LHigh do
  begin
    LMid := (LLow + LHigh) div 2;
    if CompareMessages(AMessage, FMessageQueue[LMid]) >= 0 then
      LLow := LMid + 1
    else
      LHigh := LMid - 1;
  end;
  FMessageQueue.Insert(LLow, AMessage);
end;

initialization

finalization
  FreeAndNil(_Engine);

end.
