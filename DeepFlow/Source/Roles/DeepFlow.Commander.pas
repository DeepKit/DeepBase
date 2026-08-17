unit DeepFlow.Commander;

{*******************************************************************************
  DeepFlow.Commander - 指挥官角色 (L4 决策层)
  
  描述：
    负责意图分析、任务分解和结果整合。
    是用户请求的入口点，将用户输入转化为可执行的任务序列。
    
  职责：
    - 分析用户意图 (AnalyzeIntent)
    - 将复杂任务分解为子任务 (Decompose)
    - 整合子任务结果 (Integrate)
    - 会话管理
    
  信任级别：有限信任 (输出需要 Guard 校验)
    
  作者：鲁班（开发者）
  日期：2025-12-04
  版本：1.0
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Generics.Collections,
  DeepFlow.Message, DeepFlow.Role;

type
  /// <summary>会话状态</summary>
  TSessionState = (
    ssNew,        // 新会话
    ssActive,     // 活跃中
    ssPending,    // 等待用户输入
    ssCompleted,  // 已完成
    ssError       // 错误
  );

  /// <summary>会话信息</summary>
  TSession = class
  private
    FSessionId: string;
    FState: TSessionState;
    FContext: TJSONObject;
    FCreatedAt: TDateTime;
    FLastActivity: TDateTime;
    FTurnCount: Integer;
  public
    constructor Create(const ASessionId: string);
    destructor Destroy; override;
    
    property SessionId: string read FSessionId;
    property State: TSessionState read FState write FState;
    property Context: TJSONObject read FContext;
    property CreatedAt: TDateTime read FCreatedAt;
    property LastActivity: TDateTime read FLastActivity write FLastActivity;
    property TurnCount: Integer read FTurnCount write FTurnCount;
  end;

  /// <summary>Commander 角色</summary>
  TCommander = class(TDeepFlowRoleBase, ICommander)
  private
    FSessions: TObjectDictionary<string, TSession>;
    FSessionLock: TObject;
    
    function CreateSession: TSession;
    function GetOrCreateSession(const ASessionId: string): TSession;
  protected
    procedure DoInitialize; override;
    procedure DoStart; override;
    procedure DoStop; override;
    function DoHandleMessage(const AMessage: TDeepFlowMessage): TDeepFlowMessage; override;
  public
    constructor Create;
    destructor Destroy; override;
    
    // ICommander 实现
    /// <summary>分析用户意图</summary>
    function AnalyzeIntent(const AInput: string; const AContext: TJSONObject): TJSONObject;
    /// <summary>分解任务</summary>
    function Decompose(const AIntent: TJSONObject): TJSONArray;
    /// <summary>整合结果</summary>
    function Integrate(const AResults: TJSONArray): TJSONObject;
    
    /// <summary>处理用户请求</summary>
    function ProcessRequest(const AInput: string; const ASessionId: string = ''): TJSONObject;
    
    function CanHandle(const AMsgType: string): Boolean; override;
  end;

implementation

uses
  System.DateUtils, System.RegularExpressions, System.StrUtils;

{ TSession }

constructor TSession.Create(const ASessionId: string);
var
  GUID: TGUID;
begin
  inherited Create;
  if ASessionId <> '' then
    FSessionId := ASessionId
  else
  begin
    CreateGUID(GUID);
    FSessionId := 'session_' + Copy(GUIDToString(GUID), 2, 8);
  end;
  FState := ssNew;
  FContext := TJSONObject.Create;
  FCreatedAt := Now;
  FLastActivity := Now;
  FTurnCount := 0;
end;

destructor TSession.Destroy;
begin
  FContext.Free;
  inherited;
end;

{ TCommander }

constructor TCommander.Create;
var
  Meta: TRoleMetaInfo;
begin
  Meta.Name := 'Commander';
  Meta.DisplayName := '指挥官';
  Meta.Level := rlDecision;
  Meta.TrustLevel := tlLimitedTrust;
  Meta.Description := '负责意图分析、任务分解和结果整合';
  Meta.Version := '1.0';
  
  inherited Create(Meta);
  
  FSessions := TObjectDictionary<string, TSession>.Create([doOwnsValues]);
  FSessionLock := TObject.Create;
end;

destructor TCommander.Destroy;
begin
  FSessions.Free;
  FSessionLock.Free;
  inherited;
end;

procedure TCommander.DoInitialize;
begin
  // 初始化 Commander
end;

procedure TCommander.DoStart;
begin
  // 启动 Commander
end;

procedure TCommander.DoStop;
begin
  // 停止 Commander
  TMonitor.Enter(FSessionLock);
  try
    FSessions.Clear;
  finally
    TMonitor.Exit(FSessionLock);
  end;
end;

function TCommander.CreateSession: TSession;
begin
  Result := TSession.Create('');
  TMonitor.Enter(FSessionLock);
  try
    FSessions.Add(Result.SessionId, Result);
  finally
    TMonitor.Exit(FSessionLock);
  end;
end;

function TCommander.GetOrCreateSession(const ASessionId: string): TSession;
begin
  TMonitor.Enter(FSessionLock);
  try
    if (ASessionId = '') or not FSessions.TryGetValue(ASessionId, Result) then
      Result := CreateSession
    else
      Result.LastActivity := Now;
  finally
    TMonitor.Exit(FSessionLock);
  end;
end;

function TCommander.AnalyzeIntent(const AInput: string; const AContext: TJSONObject): TJSONObject;
var
  Intent: string;
  Confidence: Double;
  Entities: TJSONArray;
begin
  Result := TJSONObject.Create;
  Entities := TJSONArray.Create;
  
  // 简单的意图识别逻辑（MVP阶段）
  // 后续会调用 Advisor (LLM) 进行更复杂的意图分析
  
  if TRegEx.IsMatch(AInput, '(?i)(查询|查找|搜索|获取)', []) then
  begin
    Intent := 'query';
    Confidence := 0.8;
  end
  else if TRegEx.IsMatch(AInput, '(?i)(创建|新建|添加|生成)', []) then
  begin
    Intent := 'create';
    Confidence := 0.8;
  end
  else if TRegEx.IsMatch(AInput, '(?i)(修改|更新|编辑|变更)', []) then
  begin
    Intent := 'update';
    Confidence := 0.8;
  end
  else if TRegEx.IsMatch(AInput, '(?i)(删除|移除|清除)', []) then
  begin
    Intent := 'delete';
    Confidence := 0.8;
  end
  else if TRegEx.IsMatch(AInput, '(?i)(分析|评估|检查)', []) then
  begin
    Intent := 'analyze';
    Confidence := 0.75;
  end
  else if TRegEx.IsMatch(AInput, '(?i)(帮助|说明|怎么)', []) then
  begin
    Intent := 'help';
    Confidence := 0.85;
  end
  else
  begin
    Intent := 'unknown';
    Confidence := 0.3;
  end;
  
  Result.AddPair('intent', Intent);
  Result.AddPair('confidence', TJSONNumber.Create(Confidence));
  Result.AddPair('original_input', AInput);
  Result.AddPair('entities', Entities);
  Result.AddPair('requires_llm', TJSONBool.Create(Confidence < 0.6));
end;

function TCommander.Decompose(const AIntent: TJSONObject): TJSONArray;
var
  Intent: string;
  Task: TJSONObject;
begin
  Result := TJSONArray.Create;
  
  if not AIntent.TryGetValue<string>('intent', Intent) then
    Exit;
  
  // 简单的任务分解逻辑
  case IndexText(Intent, ['query', 'create', 'update', 'delete', 'analyze', 'help']) of
    0: // query
    begin
      Task := TJSONObject.Create;
      Task.AddPair('task_type', 'execute_skill');
      Task.AddPair('skill_name', 'query');
      Task.AddPair('role', 'Executor');
      Result.Add(Task);
    end;
    
    1: // create
    begin
      // 创建前先校验
      Task := TJSONObject.Create;
      Task.AddPair('task_type', 'validate');
      Task.AddPair('role', 'Guard');
      Result.Add(Task);
      
      // 然后执行创建
      Task := TJSONObject.Create;
      Task.AddPair('task_type', 'execute_skill');
      Task.AddPair('skill_name', 'create');
      Task.AddPair('role', 'Executor');
      Result.Add(Task);
    end;
    
    4: // analyze
    begin
      // 分析任务需要调用 LLM
      Task := TJSONObject.Create;
      Task.AddPair('task_type', 'consult_llm');
      Task.AddPair('role', 'Advisor');
      Result.Add(Task);
    end;
    
    5: // help
    begin
      Task := TJSONObject.Create;
      Task.AddPair('task_type', 'get_help');
      Task.AddPair('role', 'Commander');
      Result.Add(Task);
    end;
  else
    // unknown - 交给 LLM 处理
    Task := TJSONObject.Create;
    Task.AddPair('task_type', 'consult_llm');
    Task.AddPair('role', 'Advisor');
    Result.Add(Task);
  end;
end;

function TCommander.Integrate(const AResults: TJSONArray): TJSONObject;
var
  I: Integer;
  ResultItem: TJSONObject;
  Success: Boolean;
  AllSuccess: Boolean;
  Outputs: TJSONArray;
begin
  Result := TJSONObject.Create;
  Outputs := TJSONArray.Create;
  AllSuccess := True;
  
  for I := 0 to AResults.Count - 1 do
  begin
    if AResults.Items[I] is TJSONObject then
    begin
      ResultItem := AResults.Items[I] as TJSONObject;
      Outputs.AddElement(ResultItem.Clone as TJSONValue);
      
      if ResultItem.TryGetValue<Boolean>('success', Success) and not Success then
        AllSuccess := False;
    end;
  end;
  
  Result.AddPair('success', TJSONBool.Create(AllSuccess));
  Result.AddPair('results', Outputs);
  Result.AddPair('timestamp', DateToISO8601(Now));
end;

function TCommander.ProcessRequest(const AInput: string; const ASessionId: string): TJSONObject;
var
  Session: TSession;
  Intent: TJSONObject;
  Tasks: TJSONArray;
begin
  Result := TJSONObject.Create;

  // 获取或创建会话
  Session := GetOrCreateSession(ASessionId);
  // BUG-429 FIX (D-007): 会话字段 (State/FTurnCount) 必须在 FSessionLock 内修改,
  // 否则并发 ProcessRequest(同 SessionId) 锁外裸改标量字段形成数据竞争.
  // Context 引用快照也在锁内取, 避免与 Commander 停止时 FSessions.Clear 释放竞争.
  var SessionCtx: TJSONObject;
  var SessionSid: string;
  TMonitor.Enter(FSessionLock);
  try
    Session.State := ssActive;
    Inc(Session.FTurnCount);
    SessionCtx := Session.Context;
    SessionSid := Session.SessionId;
  finally
    TMonitor.Exit(FSessionLock);
  end;

  try
    // 1. 分析意图
    Intent := AnalyzeIntent(AInput, SessionCtx);
    try
      Result.AddPair('session_id', SessionSid);
      Result.AddPair('intent', Intent.Clone as TJSONObject);

      // 2. 分解任务
      Tasks := Decompose(Intent);
      Result.AddPair('tasks', Tasks);

      // 3. 标记需要进一步处理
      Result.AddPair('status', 'tasks_ready');

    finally
      Intent.Free;
    end;

    TMonitor.Enter(FSessionLock);
    try
      Session.State := ssPending;
    finally
      TMonitor.Exit(FSessionLock);
    end;
  except
    on E: Exception do
    begin
      TMonitor.Enter(FSessionLock);
      try
        Session.State := ssError;
      finally
        TMonitor.Exit(FSessionLock);
      end;
      Result.AddPair('status', 'error');
      Result.AddPair('error', E.Message);
    end;
  end;
end;

function TCommander.DoHandleMessage(const AMessage: TDeepFlowMessage): TDeepFlowMessage;
var
  Input: string;
  SessionId: string;
  ProcessResult: TJSONObject;
begin
  Result := nil;
  
  if AMessage.MsgType = 'commander.process' then
  begin
    // 处理用户请求
    if AMessage.Payload.TryGetValue<string>('input', Input) then
    begin
      AMessage.Payload.TryGetValue<string>('session_id', SessionId);
      ProcessResult := ProcessRequest(Input, SessionId);
      
      Result := TResponseMessage.Create(AMessage);
      TResponseMessage(Result).Success := True;
      TResponseMessage(Result).Payload.Free;
      TResponseMessage(Result).Payload := ProcessResult;
    end;
  end
  else if AMessage.MsgType = 'commander.integrate' then
  begin
    // 整合结果
    var Results: TJSONArray;
    if AMessage.Payload.TryGetValue<TJSONArray>('results', Results) then
    begin
      Result := TResponseMessage.Create(AMessage);
      TResponseMessage(Result).Success := True;
      TResponseMessage(Result).Payload.Free;
      TResponseMessage(Result).Payload := Integrate(Results);
    end;
  end;
end;

function TCommander.CanHandle(const AMsgType: string): Boolean;
begin
  Result := AMsgType.StartsWith('commander.');
end;

end.
