unit UniFlow.Engine;

{*******************************************************************************
  UniFlow.Engine - 引擎核心
  
  描述：
    UniFlow 引擎负责消息循环、角色管理和消息路由。
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
  UniFlow.Message, UniFlow.Role, UniFlow.Config,
  UniBase.Exceptions;

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
  TMessageCallback = reference to procedure(const AMessage: TUniFlowMessage);

  /// <summary>UniFlow 引擎</summary>
  TUniFlowEngine = class(TInterfacedObject, IEngine)
  private
    FState: TEngineState;
    FConfig: TUniFlowConfig;
    FOwnsConfig: Boolean;
    
    // 角色管理
    FRoles: TDictionary<string, IUniFlowRole>;
    FRoleLock: TCriticalSection;
    
    // 消息队列（按优先级排序）
    FMessageQueue: TList<TUniFlowMessage>;
    FQueueLock: TCriticalSection;
    FQueueEvent: TEvent;
    
    // 消息处理线程
    FWorkerThread: TThread;
    FStopFlag: Boolean;
    
    // 指标
    FMessagesProcessed: Int64;
    FMessagesDropped: Int64;
    FStartTime: TDateTime;
    
    // 回调
    FOnMessageProcessed: TMessageCallback;
    FOnMessageDropped: TMessageCallback;
    
    procedure MessageLoop;
    procedure ProcessMessage(const AMessage: TUniFlowMessage);
    procedure RouteMessage(const AMessage: TUniFlowMessage);
    function CompareMessages(const Left, Right: TUniFlowMessage): Integer;
    procedure InsertSorted(const AMessage: TUniFlowMessage);
  protected
    // IUniFlowRole 实现
    function GetRoleName: string;
    function GetMetaInfo: TRoleMetaInfo;
    function GetState: TRoleState;
    procedure Initialize;
    procedure Pause;
    procedure Resume;
    function HandleMessage(const AMessage: TUniFlowMessage): TUniFlowMessage;
    function CanHandle(const AMsgType: string): Boolean;
  public
    constructor Create; overload;
    constructor Create(const AConfig: TUniFlowConfig); overload;
    destructor Destroy; override;
    
    /// <summary>启动引擎</summary>
    procedure Start;
    /// <summary>停止引擎</summary>
    procedure Stop;
    
    // IEngine 实现
    /// <summary>注册角色</summary>
    procedure RegisterRole(const ARole: IUniFlowRole);
    /// <summary>获取角色</summary>
    function GetRole(const ARoleName: string): IUniFlowRole;
    /// <summary>提交消息</summary>
    procedure SubmitMessage(const AMessage: TUniFlowMessage);
    /// <summary>获取系统指标</summary>
    function GetMetrics: TJSONObject;
    
    /// <summary>同步发送消息并等待响应</summary>
    function SendSync(const AMessage: TUniFlowMessage; ATimeout: Integer = 30000): TUniFlowMessage;
    
    /// <summary>获取所有已注册角色名</summary>
    function GetRegisteredRoles: TArray<string>;
    
    property State: TEngineState read FState;
    property Config: TUniFlowConfig read FConfig;
    property MessagesProcessed: Int64 read FMessagesProcessed;
    property MessagesDropped: Int64 read FMessagesDropped;
    
    property OnMessageProcessed: TMessageCallback read FOnMessageProcessed write FOnMessageProcessed;
    property OnMessageDropped: TMessageCallback read FOnMessageDropped write FOnMessageDropped;
  end;

/// <summary>全局引擎实例</summary>
function Engine: TUniFlowEngine;

implementation

uses
  System.DateUtils;

var
  _Engine: TUniFlowEngine = nil;

function Engine: TUniFlowEngine;
begin
  if _Engine = nil then
    _Engine := TUniFlowEngine.Create;
  Result := _Engine;
end;

{ TUniFlowEngine }

constructor TUniFlowEngine.Create;
begin
  Create(GlobalConfig);
  FOwnsConfig := False;  // 使用全局配置，不拥有
end;

constructor TUniFlowEngine.Create(const AConfig: TUniFlowConfig);
begin
  inherited Create;
  
  FConfig := AConfig;
  FOwnsConfig := True;
  FState := esUninitialized;
  FStopFlag := False;
  FMessagesProcessed := 0;
  FMessagesDropped := 0;
  
  // 初始化同步对象
  FRoleLock := TCriticalSection.Create;
  FQueueLock := TCriticalSection.Create;
  FQueueEvent := TEvent.Create(nil, False, False, '');
  
  // 初始化集合
  FRoles := TDictionary<string, IUniFlowRole>.Create;
  FMessageQueue := TList<TUniFlowMessage>.Create;
end;

destructor TUniFlowEngine.Destroy;
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
  FQueueEvent.Free;
  FQueueLock.Free;
  FRoleLock.Free;
  
  if FOwnsConfig and (FConfig <> GlobalConfig) then
    FConfig.Free;
  
  inherited;
end;

procedure TUniFlowEngine.Initialize;
var
  RolePair: TPair<string, IUniFlowRole>;
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

procedure TUniFlowEngine.Start;
var
  RolePair: TPair<string, IUniFlowRole>;
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

procedure TUniFlowEngine.Stop;
var
  RolePair: TPair<string, IUniFlowRole>;
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

procedure TUniFlowEngine.Pause;
begin
  // Engine 暂停逻辑
end;

procedure TUniFlowEngine.Resume;
begin
  // Engine 恢复逻辑
end;

procedure TUniFlowEngine.RegisterRole(const ARole: IUniFlowRole);
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

function TUniFlowEngine.GetRole(const ARoleName: string): IUniFlowRole;
begin
  FRoleLock.Enter;
  try
    if not FRoles.TryGetValue(ARoleName, Result) then
      Result := nil;
  finally
    FRoleLock.Leave;
  end;
end;

function TUniFlowEngine.GetRegisteredRoles: TArray<string>;
begin
  FRoleLock.Enter;
  try
    Result := FRoles.Keys.ToArray;
  finally
    FRoleLock.Leave;
  end;
end;

procedure TUniFlowEngine.SubmitMessage(const AMessage: TUniFlowMessage);
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

function TUniFlowEngine.SendSync(const AMessage: TUniFlowMessage; ATimeout: Integer): TUniFlowMessage;
var
  ResponseEvent: TEvent;
  Response: TUniFlowMessage;
  OriginalCallback: TMessageCallback;
begin
  Result := nil;
  ResponseEvent := TEvent.Create(nil, True, False, '');
  Response := nil;
  
  try
    // 保存并设置回调
    OriginalCallback := FOnMessageProcessed;
    FOnMessageProcessed := procedure(const AMsg: TUniFlowMessage)
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

function TUniFlowEngine.GetMetrics: TJSONObject;
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

function TUniFlowEngine.GetRoleName: string;
begin
  Result := 'Engine';
end;

function TUniFlowEngine.GetMetaInfo: TRoleMetaInfo;
begin
  Result.Name := 'Engine';
  Result.DisplayName := '引擎';
  Result.Level := rlMeta;
  Result.TrustLevel := tlFullTrust;
  Result.Description := 'UniFlow 核心引擎，负责消息调度和角色管理';
  Result.Version := '1.0';
end;

function TUniFlowEngine.GetState: TRoleState;
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

function TUniFlowEngine.HandleMessage(const AMessage: TUniFlowMessage): TUniFlowMessage;
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

function TUniFlowEngine.CanHandle(const AMsgType: string): Boolean;
begin
  Result := AMsgType.StartsWith('system.');
end;

procedure TUniFlowEngine.MessageLoop;
var
  Msg: TUniFlowMessage;
begin
  while not FStopFlag do
  begin
    // 等待消息或停止信号
    FQueueEvent.WaitFor(100);
    
    if FStopFlag then
      Break;
    
    // 处理队列中的消息
    while True do
    begin
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

procedure TUniFlowEngine.ProcessMessage(const AMessage: TUniFlowMessage);
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

procedure TUniFlowEngine.RouteMessage(const AMessage: TUniFlowMessage);
var
  TargetRole: IUniFlowRole;
  Response: TUniFlowMessage;
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

function TUniFlowEngine.CompareMessages(const Left, Right: TUniFlowMessage): Integer;
begin
  // 优先级高的排前面
  Result := Ord(Right.Priority) - Ord(Left.Priority);
  if Result = 0 then
    // 同优先级按时间戳排序（先进先出）
    Result := CompareDateTime(Left.Timestamp, Right.Timestamp);
end;

procedure TUniFlowEngine.InsertSorted(const AMessage: TUniFlowMessage);
var
  I: Integer;
begin
  // 简单插入排序（对于小队列效率足够）
  for I := 0 to FMessageQueue.Count - 1 do
  begin
    if CompareMessages(AMessage, FMessageQueue[I]) < 0 then
    begin
      FMessageQueue.Insert(I, AMessage);
      Exit;
    end;
  end;
  FMessageQueue.Add(AMessage);
end;

initialization

finalization
  FreeAndNil(_Engine);

end.
