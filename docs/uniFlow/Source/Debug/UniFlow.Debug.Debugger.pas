unit UniFlow.Debug.Debugger;
(*
  UniFlow Workflow Debugger
  =========================
  UX-003: 工作流执行调试器
  
  功能：
  - 断点管理（设置/移除/条件断点）
  - 单步执行（Step Over/Step Into/Step Out）
  - 变量监视与修改
  - 执行栈查看
  - 执行历史回溯
  
  Author: UniFlow Team
  Date: 2025-12-06
*)

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.JSON, System.SyncObjs,
  UniFlow.Workflow.Definition,
  UniFlow.Workflow.Context,
  UniFlow.Workflow.Executor;

type
  // ============================================================================
  // 调试器状态
  // ============================================================================
  
  TDebuggerState = (
    dsIdle,        // 空闲
    dsRunning,     // 运行中
    dsPaused,      // 已暂停（断点）
    dsStepping,    // 单步执行中
    dsFinished     // 已结束
  );
  
  TStepMode = (
    smOver,        // Step Over - 执行当前步骤，不进入子流程
    smInto,        // Step Into - 进入子流程
    smOut          // Step Out - 跳出当前作用域
  );
  
  // ============================================================================
  // 断点
  // ============================================================================
  
  TBreakpointType = (
    bpLine,        // 步骤断点
    bpConditional, // 条件断点
    bpException,   // 异常断点
    bpWatch        // 变量监视断点
  );
  
  TBreakpoint = class
  private
    FId: string;
    FStepId: string;
    FEnabled: Boolean;
    FBreakpointType: TBreakpointType;
    FCondition: string;        // 条件表达式（条件断点）
    FHitCount: Integer;        // 命中次数
    FHitCondition: Integer;    // 命中条件（0=每次，N=第N次命中）
    FWatchVariable: string;    // 监视变量（变量断点）
  public
    constructor Create(const AStepId: string);
    
    function ShouldBreak(AContext: TWorkflowContext; AHitCount: Integer): Boolean;
    function ToJSON: TJSONObject;
    procedure LoadFromJSON(AJson: TJSONObject);
    
    property Id: string read FId;
    property StepId: string read FStepId;
    property Enabled: Boolean read FEnabled write FEnabled;
    property BreakpointType: TBreakpointType read FBreakpointType write FBreakpointType;
    property Condition: string read FCondition write FCondition;
    property HitCount: Integer read FHitCount;
    property HitCondition: Integer read FHitCondition write FHitCondition;
    property WatchVariable: string read FWatchVariable write FWatchVariable;
  end;
  
  // ============================================================================
  // 执行帧（调用栈）
  // ============================================================================
  
  TStackFrame = class
  private
    FStepId: string;
    FStepName: string;
    FWorkflowId: string;
    FScopeLevel: Integer;
    FStartTime: TDateTime;
    FLocalVariables: TDictionary<string, string>;
  public
    constructor Create(const AStepId, AStepName, AWorkflowId: string; AScopeLevel: Integer);
    destructor Destroy; override;
    
    procedure AddVariable(const AName, AValue: string);
    function ToJSON: TJSONObject;
    
    property StepId: string read FStepId;
    property StepName: string read FStepName;
    property WorkflowId: string read FWorkflowId;
    property ScopeLevel: Integer read FScopeLevel;
    property StartTime: TDateTime read FStartTime;
    property LocalVariables: TDictionary<string, string> read FLocalVariables;
  end;
  
  // ============================================================================
  // 执行历史记录
  // ============================================================================
  
  TExecutionRecord = record
    Timestamp: TDateTime;
    StepId: string;
    StepName: string;
    Action: string;          // 'enter', 'exit', 'error'
    Duration: Int64;         // ms
    VariableChanges: string; // JSON
    
    function ToJSON: TJSONObject;
  end;
  
  // ============================================================================
  // 调试器事件
  // ============================================================================
  
  TDebuggerEvent = (
    deBreakpointHit,    // 命中断点
    deStepCompleted,    // 单步完成
    deVariableChanged,  // 变量变化
    deExceptionRaised,  // 异常抛出
    deExecutionFinished // 执行结束
  );
  
  TDebuggerEventHandler = reference to procedure(AEvent: TDebuggerEvent; AData: TJSONObject);
  
  // ============================================================================
  // 工作流调试器
  // ============================================================================
  
  TWorkflowDebugger = class
  private
    FExecutor: TWorkflowExecutor;
    FState: TDebuggerState;
    FBreakpoints: TObjectDictionary<string, TBreakpoint>;
    FCallStack: TObjectList<TStackFrame>;
    FHistory: TList<TExecutionRecord>;
    FWatches: TDictionary<string, string>;
    FLock: TCriticalSection;
    FPauseEvent: TEvent;
    FStepMode: TStepMode;
    FStepTargetLevel: Integer;
    FOnEvent: TDebuggerEventHandler;
    FMaxHistorySize: Integer;
    FBreakOnException: Boolean;
    FBreakOnFirstStep: Boolean;
    
    procedure ExecutorStepStart(Sender: TObject; AStep: TWorkflowStep);
    procedure ExecutorStepComplete(Sender: TObject; AStep: TWorkflowStep; AResult: TStepResult);
    procedure ExecutorError(Sender: TObject; const ACode, AMessage: string);
    
    procedure CheckBreakpoint(AStep: TWorkflowStep);
    procedure PushFrame(AStep: TWorkflowStep);
    procedure PopFrame;
    procedure RecordExecution(AStep: TWorkflowStep; const AAction: string; ADuration: Int64);
    procedure UpdateWatches;
    procedure FireEvent(AEvent: TDebuggerEvent; AData: TJSONObject);
    function ShouldPauseForStep: Boolean;
    
  public
    constructor Create(AExecutor: TWorkflowExecutor);
    destructor Destroy; override;
    
    // 断点管理
    function AddBreakpoint(const AStepId: string): TBreakpoint;
    function AddConditionalBreakpoint(const AStepId, ACondition: string): TBreakpoint;
    function AddWatchBreakpoint(const AVariableName: string): TBreakpoint;
    procedure RemoveBreakpoint(const ABreakpointId: string);
    procedure EnableBreakpoint(const ABreakpointId: string; AEnabled: Boolean);
    procedure ClearAllBreakpoints;
    function GetBreakpoints: TArray<TBreakpoint>;
    
    // 执行控制
    procedure Run;
    procedure Pause;
    procedure Continue;
    procedure StepOver;
    procedure StepInto;
    procedure StepOut;
    procedure Stop;
    
    // 变量监视
    procedure AddWatch(const AVariableName: string);
    procedure RemoveWatch(const AVariableName: string);
    function GetWatchValue(const AVariableName: string): string;
    function GetAllWatches: TJSONObject;
    
    // 变量修改
    function SetVariable(const APath, AValue: string): Boolean;
    
    // 调用栈
    function GetCallStack: TJSONArray;
    function GetCurrentFrame: TStackFrame;
    
    // 执行历史
    function GetHistory(ACount: Integer = 100): TJSONArray;
    procedure ClearHistory;
    
    // 状态查询
    function GetState: TDebuggerState;
    function GetCurrentStepId: string;
    function GetContext: TWorkflowContext;
    
    // 快照
    function CreateSnapshot: TJSONObject;
    procedure RestoreSnapshot(ASnapshot: TJSONObject);
    
    // 属性
    property State: TDebuggerState read FState;
    property MaxHistorySize: Integer read FMaxHistorySize write FMaxHistorySize;
    property BreakOnException: Boolean read FBreakOnException write FBreakOnException;
    property BreakOnFirstStep: Boolean read FBreakOnFirstStep write FBreakOnFirstStep;
    property OnEvent: TDebuggerEventHandler read FOnEvent write FOnEvent;
  end;
  
  // ============================================================================
  // 调试器控制台（文本界面）
  // ============================================================================
  
  TDebugConsole = class
  private
    FDebugger: TWorkflowDebugger;
    FOutput: TStrings;
    
    procedure PrintHelp;
    procedure PrintState;
    procedure PrintCallStack;
    procedure PrintWatches;
    procedure PrintBreakpoints;
    procedure PrintHistory(ACount: Integer);
  public
    constructor Create(ADebugger: TWorkflowDebugger);
    destructor Destroy; override;
    
    /// <summary>处理命令输入</summary>
    function ProcessCommand(const ACommand: string): string;
    
    /// <summary>获取输出</summary>
    property Output: TStrings read FOutput;
  end;

implementation

uses
  System.DateUtils,
  System.StrUtils;

// ============================================================================
// TBreakpoint
// ============================================================================

constructor TBreakpoint.Create(const AStepId: string);
begin
  inherited Create;
  FId := TGUID.NewGuid.ToString;
  FStepId := AStepId;
  FEnabled := True;
  FBreakpointType := bpLine;
  FCondition := '';
  FHitCount := 0;
  FHitCondition := 0;
  FWatchVariable := '';
end;

function TBreakpoint.ShouldBreak(AContext: TWorkflowContext; AHitCount: Integer): Boolean;
begin
  Result := False;
  if not FEnabled then Exit;
  
  Inc(FHitCount);
  
  // 检查命中条件
  if (FHitCondition > 0) and (FHitCount < FHitCondition) then
    Exit;
  
  case FBreakpointType of
    bpLine:
      Result := True;
      
    bpConditional:
      begin
        if (FCondition <> '') and (AContext <> nil) then
        begin
          try
            var Resolved := AContext.ResolveString(FCondition);
            Result := SameText(Resolved, 'true') or (Resolved = '1');
          except
            Result := False;
          end;
        end;
      end;
      
    bpWatch:
      begin
        // 监视断点在变量变化时触发（由调试器外部处理）
        Result := True;
      end;
      
    bpException:
      Result := True;
  end;
end;

function TBreakpoint.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id', FId);
  Result.AddPair('stepId', FStepId);
  Result.AddPair('enabled', TJSONBool.Create(FEnabled));
  Result.AddPair('type', Integer(FBreakpointType));
  Result.AddPair('condition', FCondition);
  Result.AddPair('hitCount', TJSONNumber.Create(FHitCount));
  Result.AddPair('hitCondition', TJSONNumber.Create(FHitCondition));
  Result.AddPair('watchVariable', FWatchVariable);
end;

procedure TBreakpoint.LoadFromJSON(AJson: TJSONObject);
begin
  if AJson = nil then Exit;
  AJson.TryGetValue<string>('id', FId);
  AJson.TryGetValue<string>('stepId', FStepId);
  AJson.TryGetValue<Boolean>('enabled', FEnabled);
  var TypeInt: Integer := 0;
  if AJson.TryGetValue<Integer>('type', TypeInt) then
    FBreakpointType := TBreakpointType(TypeInt);
  AJson.TryGetValue<string>('condition', FCondition);
  AJson.TryGetValue<Integer>('hitCount', FHitCount);
  AJson.TryGetValue<Integer>('hitCondition', FHitCondition);
  AJson.TryGetValue<string>('watchVariable', FWatchVariable);
end;

// ============================================================================
// TStackFrame
// ============================================================================

constructor TStackFrame.Create(const AStepId, AStepName, AWorkflowId: string; AScopeLevel: Integer);
begin
  inherited Create;
  FStepId := AStepId;
  FStepName := AStepName;
  FWorkflowId := AWorkflowId;
  FScopeLevel := AScopeLevel;
  FStartTime := Now;
  FLocalVariables := TDictionary<string, string>.Create;
end;

destructor TStackFrame.Destroy;
begin
  FLocalVariables.Free;
  inherited;
end;

procedure TStackFrame.AddVariable(const AName, AValue: string);
begin
  FLocalVariables.AddOrSetValue(AName, AValue);
end;

function TStackFrame.ToJSON: TJSONObject;
var
  VarsObj: TJSONObject;
  Pair: TPair<string, string>;
begin
  Result := TJSONObject.Create;
  Result.AddPair('stepId', FStepId);
  Result.AddPair('stepName', FStepName);
  Result.AddPair('workflowId', FWorkflowId);
  Result.AddPair('scopeLevel', TJSONNumber.Create(FScopeLevel));
  Result.AddPair('startTime', DateTimeToStr(FStartTime));
  
  VarsObj := TJSONObject.Create;
  for Pair in FLocalVariables do
    VarsObj.AddPair(Pair.Key, Pair.Value);
  Result.AddPair('localVariables', VarsObj);
end;

// ============================================================================
// TExecutionRecord
// ============================================================================

function TExecutionRecord.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('timestamp', DateTimeToStr(Timestamp));
  Result.AddPair('stepId', StepId);
  Result.AddPair('stepName', StepName);
  Result.AddPair('action', Action);
  Result.AddPair('duration', TJSONNumber.Create(Duration));
  Result.AddPair('variableChanges', VariableChanges);
end;

// ============================================================================
// TWorkflowDebugger
// ============================================================================

constructor TWorkflowDebugger.Create(AExecutor: TWorkflowExecutor);
begin
  inherited Create;
  FExecutor := AExecutor;
  FState := dsIdle;
  FBreakpoints := TObjectDictionary<string, TBreakpoint>.Create([doOwnsValues]);
  FCallStack := TObjectList<TStackFrame>.Create(True);
  FHistory := TList<TExecutionRecord>.Create;
  FWatches := TDictionary<string, string>.Create;
  FLock := TCriticalSection.Create;
  FPauseEvent := TEvent.Create(nil, True, True, '');
  FMaxHistorySize := 1000;
  FBreakOnException := True;
  FBreakOnFirstStep := False;
  
  // 挂接执行器事件
  FExecutor.OnStepStart := ExecutorStepStart;
  FExecutor.OnStepComplete := ExecutorStepComplete;
  FExecutor.OnWorkflowError := ExecutorError;
end;

destructor TWorkflowDebugger.Destroy;
begin
  FBreakpoints.Free;
  FCallStack.Free;
  FHistory.Free;
  FWatches.Free;
  FLock.Free;
  FPauseEvent.Free;
  inherited;
end;

procedure TWorkflowDebugger.ExecutorStepStart(Sender: TObject; AStep: TWorkflowStep);
begin
  FLock.Enter;
  try
    // 入栈
    PushFrame(AStep);
    
    // 记录执行
    RecordExecution(AStep, 'enter', 0);
    
    // 更新监视
    UpdateWatches;
    
    // 检查是否需要暂停
    if FBreakOnFirstStep and (FHistory.Count = 1) then
    begin
      FState := dsPaused;
      FPauseEvent.ResetEvent;
      FireEvent(deBreakpointHit, TJSONObject.Create.AddPair('stepId', AStep.Id));
    end
    else
    begin
      CheckBreakpoint(AStep);
    end;
  finally
    FLock.Leave;
  end;
  
  // 等待继续（如果暂停）
  if FState = dsPaused then
    FPauseEvent.WaitFor(INFINITE);
end;

procedure TWorkflowDebugger.ExecutorStepComplete(Sender: TObject; AStep: TWorkflowStep; AResult: TStepResult);
var
  Duration: Int64;
begin
  FLock.Enter;
  try
    // 计算执行时间
    if FCallStack.Count > 0 then
      Duration := MilliSecondsBetween(Now, FCallStack.Last.StartTime)
    else
      Duration := 0;
    
    // 记录执行
    RecordExecution(AStep, 'exit', Duration);
    
    // 出栈
    PopFrame;
    
    // 更新监视
    UpdateWatches;
    
    // 检查单步模式
    if ShouldPauseForStep then
    begin
      FState := dsPaused;
      FPauseEvent.ResetEvent;
      FireEvent(deStepCompleted, TJSONObject.Create.AddPair('stepId', AStep.Id));
    end;
  finally
    FLock.Leave;
  end;
  
  // 等待继续
  if FState = dsPaused then
    FPauseEvent.WaitFor(INFINITE);
end;

procedure TWorkflowDebugger.ExecutorError(Sender: TObject; const ACode, AMessage: string);
var
  Data: TJSONObject;
begin
  FLock.Enter;
  try
    // 记录错误
    var Rec: TExecutionRecord;
    Rec.Timestamp := Now;
    Rec.StepId := GetCurrentStepId;
    Rec.StepName := '';
    Rec.Action := 'error';
    Rec.Duration := 0;
    Rec.VariableChanges := Format('{"code":"%s","message":"%s"}', [ACode, AMessage]);
    FHistory.Add(Rec);
    
    // 异常断点
    if FBreakOnException then
    begin
      FState := dsPaused;
      FPauseEvent.ResetEvent;
      
      Data := TJSONObject.Create;
      Data.AddPair('code', ACode);
      Data.AddPair('message', AMessage);
      FireEvent(deExceptionRaised, Data);
    end;
  finally
    FLock.Leave;
  end;
  
  if FState = dsPaused then
    FPauseEvent.WaitFor(INFINITE);
end;

procedure TWorkflowDebugger.CheckBreakpoint(AStep: TWorkflowStep);
var
  BP: TBreakpoint;
  Data: TJSONObject;
begin
  // 检查该步骤是否有断点
  if FBreakpoints.TryGetValue(AStep.Id, BP) then
  begin
    if BP.ShouldBreak(FExecutor.Context, BP.HitCount) then
    begin
      FState := dsPaused;
      FPauseEvent.ResetEvent;
      
      Data := TJSONObject.Create;
      Data.AddPair('breakpointId', BP.Id);
      Data.AddPair('stepId', AStep.Id);
      Data.AddPair('hitCount', TJSONNumber.Create(BP.HitCount));
      FireEvent(deBreakpointHit, Data);
    end;
  end;
end;

procedure TWorkflowDebugger.PushFrame(AStep: TWorkflowStep);
var
  Frame: TStackFrame;
begin
  Frame := TStackFrame.Create(
    AStep.Id,
    AStep.Name,
    FExecutor.Workflow.Id,
    FCallStack.Count
  );
  FCallStack.Add(Frame);
end;

procedure TWorkflowDebugger.PopFrame;
begin
  if FCallStack.Count > 0 then
    FCallStack.Delete(FCallStack.Count - 1);
end;

procedure TWorkflowDebugger.RecordExecution(AStep: TWorkflowStep; const AAction: string; ADuration: Int64);
var
  Rec: TExecutionRecord;
begin
  Rec.Timestamp := Now;
  Rec.StepId := AStep.Id;
  Rec.StepName := AStep.Name;
  Rec.Action := AAction;
  Rec.Duration := ADuration;
  Rec.VariableChanges := '{}';
  
  FHistory.Add(Rec);
  
  // 限制历史大小
  while FHistory.Count > FMaxHistorySize do
    FHistory.Delete(0);
end;

procedure TWorkflowDebugger.UpdateWatches;
var
  WatchName: string;
  Value: TVariableValue;
begin
  for WatchName in FWatches.Keys do
  begin
    try
      Value := FExecutor.Context.GetVariable(WatchName);
      if Value <> nil then
        FWatches[WatchName] := Value.AsString
      else
        FWatches[WatchName] := '<undefined>';
    except
      FWatches[WatchName] := '<error>';
    end;
  end;
end;

procedure TWorkflowDebugger.FireEvent(AEvent: TDebuggerEvent; AData: TJSONObject);
begin
  if Assigned(FOnEvent) then
  begin
    try
      FOnEvent(AEvent, AData);
    finally
      AData.Free;
    end;
  end
  else
    AData.Free;
end;

function TWorkflowDebugger.ShouldPauseForStep: Boolean;
begin
  Result := False;
  
  case FStepMode of
    smOver:
      Result := FCallStack.Count <= FStepTargetLevel;
    smInto:
      Result := True;
    smOut:
      Result := FCallStack.Count < FStepTargetLevel;
  end;
  
  if Result then
    FState := dsStepping;
end;

// 断点管理

function TWorkflowDebugger.AddBreakpoint(const AStepId: string): TBreakpoint;
begin
  FLock.Enter;
  try
    Result := TBreakpoint.Create(AStepId);
    Result.BreakpointType := bpLine;
    FBreakpoints.Add(AStepId, Result);
  finally
    FLock.Leave;
  end;
end;

function TWorkflowDebugger.AddConditionalBreakpoint(const AStepId, ACondition: string): TBreakpoint;
begin
  FLock.Enter;
  try
    Result := TBreakpoint.Create(AStepId);
    Result.BreakpointType := bpConditional;
    Result.Condition := ACondition;
    FBreakpoints.Add(AStepId, Result);
  finally
    FLock.Leave;
  end;
end;

function TWorkflowDebugger.AddWatchBreakpoint(const AVariableName: string): TBreakpoint;
begin
  FLock.Enter;
  try
    Result := TBreakpoint.Create('watch:' + AVariableName);
    Result.BreakpointType := bpWatch;
    Result.WatchVariable := AVariableName;
    FBreakpoints.Add(Result.StepId, Result);
  finally
    FLock.Leave;
  end;
end;

procedure TWorkflowDebugger.RemoveBreakpoint(const ABreakpointId: string);
var
  Pair: TPair<string, TBreakpoint>;
begin
  FLock.Enter;
  try
    for Pair in FBreakpoints do
    begin
      if Pair.Value.Id = ABreakpointId then
      begin
        FBreakpoints.Remove(Pair.Key);
        Break;
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TWorkflowDebugger.EnableBreakpoint(const ABreakpointId: string; AEnabled: Boolean);
var
  Pair: TPair<string, TBreakpoint>;
begin
  FLock.Enter;
  try
    for Pair in FBreakpoints do
    begin
      if Pair.Value.Id = ABreakpointId then
      begin
        Pair.Value.Enabled := AEnabled;
        Break;
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TWorkflowDebugger.ClearAllBreakpoints;
begin
  FLock.Enter;
  try
    FBreakpoints.Clear;
  finally
    FLock.Leave;
  end;
end;

function TWorkflowDebugger.GetBreakpoints: TArray<TBreakpoint>;
var
  List: TList<TBreakpoint>;
  Pair: TPair<string, TBreakpoint>;
begin
  FLock.Enter;
  try
    List := TList<TBreakpoint>.Create;
    try
      for Pair in FBreakpoints do
        List.Add(Pair.Value);
      Result := List.ToArray;
    finally
      List.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

// 执行控制

procedure TWorkflowDebugger.Run;
begin
  FLock.Enter;
  try
    FState := dsRunning;
    FStepMode := smOver;
    FStepTargetLevel := -1;
    FPauseEvent.SetEvent;
  finally
    FLock.Leave;
  end;
end;

procedure TWorkflowDebugger.Pause;
begin
  FLock.Enter;
  try
    if FState = dsRunning then
    begin
      FState := dsPaused;
      FPauseEvent.ResetEvent;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TWorkflowDebugger.Continue;
begin
  FLock.Enter;
  try
    if FState = dsPaused then
    begin
      FState := dsRunning;
      FStepMode := smOver;
      FStepTargetLevel := -1;
      FPauseEvent.SetEvent;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TWorkflowDebugger.StepOver;
begin
  FLock.Enter;
  try
    if FState = dsPaused then
    begin
      FState := dsStepping;
      FStepMode := smOver;
      FStepTargetLevel := FCallStack.Count;
      FPauseEvent.SetEvent;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TWorkflowDebugger.StepInto;
begin
  FLock.Enter;
  try
    if FState = dsPaused then
    begin
      FState := dsStepping;
      FStepMode := smInto;
      FStepTargetLevel := FCallStack.Count + 1;
      FPauseEvent.SetEvent;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TWorkflowDebugger.StepOut;
begin
  FLock.Enter;
  try
    if FState = dsPaused then
    begin
      FState := dsStepping;
      FStepMode := smOut;
      FStepTargetLevel := FCallStack.Count;
      FPauseEvent.SetEvent;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TWorkflowDebugger.Stop;
begin
  FLock.Enter;
  try
    FState := dsFinished;
    FExecutor.Cancel;
    FPauseEvent.SetEvent;
  finally
    FLock.Leave;
  end;
end;

// 变量监视

procedure TWorkflowDebugger.AddWatch(const AVariableName: string);
begin
  FLock.Enter;
  try
    if not FWatches.ContainsKey(AVariableName) then
      FWatches.Add(AVariableName, '<not evaluated>');
  finally
    FLock.Leave;
  end;
end;

procedure TWorkflowDebugger.RemoveWatch(const AVariableName: string);
begin
  FLock.Enter;
  try
    FWatches.Remove(AVariableName);
  finally
    FLock.Leave;
  end;
end;

function TWorkflowDebugger.GetWatchValue(const AVariableName: string): string;
begin
  FLock.Enter;
  try
    if not FWatches.TryGetValue(AVariableName, Result) then
      Result := '<not watched>';
  finally
    FLock.Leave;
  end;
end;

function TWorkflowDebugger.GetAllWatches: TJSONObject;
var
  Pair: TPair<string, string>;
begin
  FLock.Enter;
  try
    Result := TJSONObject.Create;
    for Pair in FWatches do
      Result.AddPair(Pair.Key, Pair.Value);
  finally
    FLock.Leave;
  end;
end;

function TWorkflowDebugger.SetVariable(const APath, AValue: string): Boolean;
begin
  Result := False;
  FLock.Enter;
  try
    if FExecutor.Context <> nil then
    begin
      try
        FExecutor.Context.SetVariable(APath, AValue);
        UpdateWatches;
        Result := True;
      except
        // 忽略设置失败
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

// 调用栈

function TWorkflowDebugger.GetCallStack: TJSONArray;
var
  I: Integer;
begin
  FLock.Enter;
  try
    Result := TJSONArray.Create;
    for I := FCallStack.Count - 1 downto 0 do
      Result.AddElement(FCallStack[I].ToJSON);
  finally
    FLock.Leave;
  end;
end;

function TWorkflowDebugger.GetCurrentFrame: TStackFrame;
begin
  FLock.Enter;
  try
    if FCallStack.Count > 0 then
      Result := FCallStack.Last
    else
      Result := nil;
  finally
    FLock.Leave;
  end;
end;

// 执行历史

function TWorkflowDebugger.GetHistory(ACount: Integer): TJSONArray;
var
  I, StartIdx: Integer;
begin
  FLock.Enter;
  try
    Result := TJSONArray.Create;
    StartIdx := FHistory.Count - ACount;
    if StartIdx < 0 then StartIdx := 0;
    
    for I := StartIdx to FHistory.Count - 1 do
      Result.AddElement(FHistory[I].ToJSON);
  finally
    FLock.Leave;
  end;
end;

procedure TWorkflowDebugger.ClearHistory;
begin
  FLock.Enter;
  try
    FHistory.Clear;
  finally
    FLock.Leave;
  end;
end;

// 状态查询

function TWorkflowDebugger.GetState: TDebuggerState;
begin
  FLock.Enter;
  try
    Result := FState;
  finally
    FLock.Leave;
  end;
end;

function TWorkflowDebugger.GetCurrentStepId: string;
begin
  FLock.Enter;
  try
    if FCallStack.Count > 0 then
      Result := FCallStack.Last.StepId
    else
      Result := '';
  finally
    FLock.Leave;
  end;
end;

function TWorkflowDebugger.GetContext: TWorkflowContext;
begin
  Result := FExecutor.Context;
end;

// 快照

function TWorkflowDebugger.CreateSnapshot: TJSONObject;
var
  BPArray: TJSONArray;
  WatchObj: TJSONObject;
  BP: TBreakpoint;
  Pair: TPair<string, string>;
begin
  FLock.Enter;
  try
    Result := TJSONObject.Create;
    
    // 断点
    BPArray := TJSONArray.Create;
    for BP in GetBreakpoints do
      BPArray.AddElement(BP.ToJSON);
    Result.AddPair('breakpoints', BPArray);
    
    // 监视
    WatchObj := TJSONObject.Create;
    for Pair in FWatches do
      WatchObj.AddPair(Pair.Key, Pair.Value);
    Result.AddPair('watches', WatchObj);
    
    // 调用栈
    Result.AddPair('callStack', GetCallStack);
    
    // 历史
    Result.AddPair('history', GetHistory(100));
    
    // 状态
    Result.AddPair('state', Integer(FState));
  finally
    FLock.Leave;
  end;
end;

procedure TWorkflowDebugger.RestoreSnapshot(ASnapshot: TJSONObject);
var
  BPArray: TJSONArray;
  WatchObj: TJSONObject;
  I: Integer;
  BP: TBreakpoint;
  Pair: TJSONPair;
begin
  if ASnapshot = nil then Exit;
  
  FLock.Enter;
  try
    // 断点
    if ASnapshot.TryGetValue<TJSONArray>('breakpoints', BPArray) then
    begin
      FBreakpoints.Clear;
      for I := 0 to BPArray.Count - 1 do
      begin
        BP := TBreakpoint.Create('');
        BP.LoadFromJSON(BPArray.Items[I] as TJSONObject);
        FBreakpoints.Add(BP.StepId, BP);
      end;
    end;
    
    // 监视
    if ASnapshot.TryGetValue<TJSONObject>('watches', WatchObj) then
    begin
      FWatches.Clear;
      for Pair in WatchObj do
        FWatches.Add(Pair.JsonString.Value, Pair.JsonValue.Value);
    end;
  finally
    FLock.Leave;
  end;
end;

// ============================================================================
// TDebugConsole
// ============================================================================

constructor TDebugConsole.Create(ADebugger: TWorkflowDebugger);
begin
  inherited Create;
  FDebugger := ADebugger;
  FOutput := TStringList.Create;
end;

destructor TDebugConsole.Destroy;
begin
  FOutput.Free;
  inherited;
end;

function TDebugConsole.ProcessCommand(const ACommand: string): string;
var
  Parts: TArray<string>;
  Cmd: string;
begin
  FOutput.Clear;
  Parts := ACommand.Trim.Split([' '], 2);
  if Length(Parts) = 0 then Exit('');
  
  Cmd := LowerCase(Parts[0]);
  
  if (Cmd = 'help') or (Cmd = '?') or (Cmd = 'h') then
    PrintHelp
  else if (Cmd = 'run') or (Cmd = 'r') then
  begin
    FDebugger.Run;
    FOutput.Add('Running...');
  end
  else if (Cmd = 'continue') or (Cmd = 'c') then
  begin
    FDebugger.Continue;
    FOutput.Add('Continuing...');
  end
  else if (Cmd = 'pause') or (Cmd = 'p') then
  begin
    FDebugger.Pause;
    FOutput.Add('Paused');
  end
  else if (Cmd = 'stop') or (Cmd = 'q') then
  begin
    FDebugger.Stop;
    FOutput.Add('Stopped');
  end
  else if (Cmd = 'step') or (Cmd = 'n') then
  begin
    FDebugger.StepOver;
    FOutput.Add('Step over...');
  end
  else if (Cmd = 'stepin') or (Cmd = 's') then
  begin
    FDebugger.StepInto;
    FOutput.Add('Step into...');
  end
  else if (Cmd = 'stepout') or (Cmd = 'o') then
  begin
    FDebugger.StepOut;
    FOutput.Add('Step out...');
  end
  else if (Cmd = 'break') or (Cmd = 'b') then
  begin
    if Length(Parts) > 1 then
    begin
      FDebugger.AddBreakpoint(Parts[1]);
      FOutput.Add('Breakpoint added: ' + Parts[1]);
    end
    else
      PrintBreakpoints;
  end
  else if (Cmd = 'delete') or (Cmd = 'd') then
  begin
    if Length(Parts) > 1 then
    begin
      FDebugger.RemoveBreakpoint(Parts[1]);
      FOutput.Add('Breakpoint removed');
    end;
  end
  else if Cmd = 'clear' then
  begin
    FDebugger.ClearAllBreakpoints;
    FOutput.Add('All breakpoints cleared');
  end
  else if (Cmd = 'watch') or (Cmd = 'w') then
  begin
    if Length(Parts) > 1 then
    begin
      FDebugger.AddWatch(Parts[1]);
      FOutput.Add('Watch added: ' + Parts[1]);
    end
    else
      PrintWatches;
  end
  else if (Cmd = 'set') then
  begin
    if Length(Parts) > 1 then
    begin
      var SetParts := Parts[1].Split(['='], 2);
      if Length(SetParts) = 2 then
      begin
        if FDebugger.SetVariable(SetParts[0].Trim, SetParts[1].Trim) then
          FOutput.Add('Variable set')
        else
          FOutput.Add('Failed to set variable');
      end;
    end;
  end
  else if (Cmd = 'stack') or (Cmd = 'bt') then
    PrintCallStack
  else if (Cmd = 'history') or (Cmd = 'hist') then
  begin
    var Count := 20;
    if Length(Parts) > 1 then
      TryStrToInt(Parts[1], Count);
    PrintHistory(Count);
  end
  else if (Cmd = 'state') or (Cmd = 'info') then
    PrintState
  else
    FOutput.Add('Unknown command: ' + Cmd + '. Type "help" for available commands.');
  
  Result := FOutput.Text;
end;

procedure TDebugConsole.PrintHelp;
begin
  FOutput.Add('=== UniFlow Debugger Commands ===');
  FOutput.Add('');
  FOutput.Add('Execution:');
  FOutput.Add('  run, r       - Start/resume execution');
  FOutput.Add('  continue, c  - Continue execution');
  FOutput.Add('  pause, p     - Pause execution');
  FOutput.Add('  stop, q      - Stop execution');
  FOutput.Add('  step, n      - Step over');
  FOutput.Add('  stepin, s    - Step into');
  FOutput.Add('  stepout, o   - Step out');
  FOutput.Add('');
  FOutput.Add('Breakpoints:');
  FOutput.Add('  break, b [stepId] - Add/list breakpoints');
  FOutput.Add('  delete, d <id>    - Remove breakpoint');
  FOutput.Add('  clear             - Clear all breakpoints');
  FOutput.Add('');
  FOutput.Add('Variables:');
  FOutput.Add('  watch, w [name]   - Add/list watches');
  FOutput.Add('  set <name>=<val>  - Set variable value');
  FOutput.Add('');
  FOutput.Add('Info:');
  FOutput.Add('  stack, bt         - Show call stack');
  FOutput.Add('  history [n]       - Show execution history');
  FOutput.Add('  state, info       - Show current state');
  FOutput.Add('  help, ?, h        - Show this help');
end;

procedure TDebugConsole.PrintState;
const
  StateNames: array[TDebuggerState] of string = ('Idle', 'Running', 'Paused', 'Stepping', 'Finished');
begin
  FOutput.Add('State: ' + StateNames[FDebugger.State]);
  FOutput.Add('Current Step: ' + FDebugger.GetCurrentStepId);
  FOutput.Add('Call Stack Depth: ' + IntToStr(FDebugger.GetCallStack.Count));
end;

procedure TDebugConsole.PrintCallStack;
var
  Stack: TJSONArray;
  I: Integer;
  Frame: TJSONObject;
begin
  Stack := FDebugger.GetCallStack;
  try
    FOutput.Add('=== Call Stack ===');
    for I := 0 to Stack.Count - 1 do
    begin
      Frame := Stack.Items[I] as TJSONObject;
      FOutput.Add(Format('#%d %s (%s)', [
        I,
        Frame.GetValue<string>('stepName', ''),
        Frame.GetValue<string>('stepId', '')
      ]));
    end;
  finally
    Stack.Free;
  end;
end;

procedure TDebugConsole.PrintWatches;
var
  Watches: TJSONObject;
  Pair: TJSONPair;
begin
  Watches := FDebugger.GetAllWatches;
  try
    FOutput.Add('=== Watches ===');
    for Pair in Watches do
      FOutput.Add(Format('%s = %s', [Pair.JsonString.Value, Pair.JsonValue.Value]));
  finally
    Watches.Free;
  end;
end;

procedure TDebugConsole.PrintBreakpoints;
var
  BPs: TArray<TBreakpoint>;
  BP: TBreakpoint;
begin
  BPs := FDebugger.GetBreakpoints;
  FOutput.Add('=== Breakpoints ===');
  for BP in BPs do
  begin
    FOutput.Add(Format('[%s] %s (hits: %d, enabled: %s)', [
      BP.Id.Substring(0, 8),
      BP.StepId,
      BP.HitCount,
      BoolToStr(BP.Enabled, True)
    ]));
  end;
end;

procedure TDebugConsole.PrintHistory(ACount: Integer);
var
  History: TJSONArray;
  I: Integer;
  Rec: TJSONObject;
begin
  History := FDebugger.GetHistory(ACount);
  try
    FOutput.Add('=== Execution History ===');
    for I := 0 to History.Count - 1 do
    begin
      Rec := History.Items[I] as TJSONObject;
      FOutput.Add(Format('%s | %s | %s | %dms', [
        Rec.GetValue<string>('timestamp', ''),
        Rec.GetValue<string>('action', ''),
        Rec.GetValue<string>('stepName', ''),
        Rec.GetValue<Integer>('duration', 0)
      ]));
    end;
  finally
    History.Free;
  end;
end;

end.
