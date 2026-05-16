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
    procedure Initialize;
    procedure Pause;
    procedure Resume;
    function HandleMessage(const AMessage: TDeepFlowMessage): TDeepFlowMessage;
    function CanHandle(const AMsgType: string): Boolean;
  public
    constructor Create; overload;
    constructor Create(const AConfig: TDeepFlowConfig); overload;
    destructor Destroy; override;
    
    /// <summary>启动引擎</summary>
    procedure Start;
    /// <summary>停止引擎</summary>
    procedure Stop;
    
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
    
    property State: TEngineState read FState;
    property Config: TDeepFlowConfig read FConfig;
    property MessagesProcessed: Int64 read FMessagesProcessed;
    property MessagesDropped: Int64 read FMessagesDropped;
    
    property OnMessageProcessed: TMessageCallback read FOnMessageProcessed write FOnMessageProcessed;
    property OnMessageDropped: TMessageCallback read FOnMessageDropped write FOnMessageDropped;
  end;

/// <summary>全局引擎实例</summary>
function Engine: TDeepFlowEngine;

implementation

uses
  System.DateUtils;

var
  _Engine: TDeepFlowEngine = nil;

function Engine: TDeepFlowEngine;
begin
  if _Engine = nil then
    _Engine := TDeepFlowEngine.Create;
  Result := _Engine;
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
  
  // 初始化同步对象
  FRoleLock := TCriticalSection.Create;
  FQueueLock := TCriticalSection.Create;
  FQueueEvent := TEvent.Create(nil, False, False, '');
  FPauseEvent := TEvent.Create(nil, True, True, '');  // Manual reset, initially signaled
  
  // 初始化集合
  FRoles := TDictionary<string, IDeepFlowRole>.Create;
  FMessageQueue := TList<TDeepFlowMessage>.Create;
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
  FRoles.Free;
  FPauseEvent.Free;
  FQueueEvent.Free;
  FQueueLock.Free;
  FRoleLock.Free;
  
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
  FWorkerThread := TThread.CreateAnonymousThread(MessageLoop);
  FWorkerThread.FreeOnTerminate := False;
  FWorkerThread.Start;
  
  FState := esRunning;
end;

procedure TDeepFlowEngine.Stop;
var
  RolePair: TPair<string, IDeepFlowRole>;
begin
  if FState <> esRunning then
    Exit;
  
  FState := esStopping;
  FStopFlag := True;
  
  // 唤醒工作线程
  FQueueEvent.SetEvent;
  
  // 等待工作线程结束
  if Assigned(FWorkerThread) then
  begin
    FWorkerThread.WaitFor;
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
  ResponseEvent: TEvent;
  Response: TDeepFlowMessage;
  OriginalCallback: TMessageCallback;
begin
  Result := nil;
  ResponseEvent := TEvent.Create(nil, True, False, '');
  Response := nil;
  
  try
    // 保存并设置回调
    OriginalCallback := FOnMessageProcessed;
    FOnMessageProcessed := procedure(const AMsg: TDeepFlowMessage)
    begin
      if (AMsg is TResponseMessage) and 
         (TResponseMessage(AMsg).CorrelationId = AMessage.MsgId) then
      begin
        Response := AMsg.Clone;
        ResponseEvent.SetEvent;
      end;
      
      if Assigned(OriginalCallback) then
        OriginalCallback(AMsg);
    end;
    
    // 提交消息
    SubmitMessage(AMessage);
    
    // 等待响应
    if ResponseEvent.WaitFor(ATimeout) = wrSignaled then
      Result := Response
    else
      Response.Free;  // 超时，释放响应
  finally
    FOnMessageProcessed := OriginalCallback;
    ResponseEvent.Free;
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
begin
  while not FStopFlag do
  begin
    // Wait for pause to be lifted before processing
    if FPaused then
      FPauseEvent.WaitFor(INFINITE);

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
end;

procedure TDeepFlowEngine.ProcessMessage(const AMessage: TDeepFlowMessage);
begin
  AMessage.Status := msProcessing;
  
  try
    RouteMessage(AMessage);
    AMessage.Status := msCompleted;
    Inc(FMessagesProcessed);
    
    if Assigned(FOnMessageProcessed) then
      FOnMessageProcessed(AMessage);
  except
    on E: Exception do
    begin
      AMessage.Status := msFailed;
      // 可以在这里添加错误处理逻辑
    end;
  end;
end;

procedure TDeepFlowEngine.RouteMessage(const AMessage: TDeepFlowMessage);
var
  TargetRole: IDeepFlowRole;
  Response: TDeepFlowMessage;
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
  
  // 广播消息 - 发送给所有能处理的角色
  FRoleLock.Enter;
  try
    for var RolePair in FRoles do
    begin
      if RolePair.Value.CanHandle(AMessage.MsgType) then
      begin
        Response := RolePair.Value.HandleMessage(AMessage);
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
