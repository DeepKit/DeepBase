unit DeepFlow.Workflow.Definition;

{*******************************************************************************
  DeepFlow.Workflow.Definition - 工作流定义
  
  描述：
    定义工作流的数据结构，包括工作流定义、步骤、条件、输入输出等。
    支持线性执行、条件分支、循环等控制流。
    
  工作流结构：
    Workflow
      ├── Metadata (ID, Name, Version, Description)
      ├── Variables (输入/输出变量定义)
      └── Steps[]
            ├── StepType (action/condition/loop/parallel/subworkflow)
            ├── Action (Skill调用/LLM调用/系统操作)
            ├── Condition (条件表达式)
            └── Next (下一步骤/分支)
    
  作者：鲁班（开发者）
  日期：2025-12-04
  版本：1.0
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Generics.Collections,
  DeepBase.Exceptions;

type
  /// <summary>步骤类型</summary>
  TStepType = (
    stAction,      // 动作步骤（执行 Skill）
    stCondition,   // 条件分支
    stLoop,        // 循环
    stParallel,    // 并行执行
    stSubWorkflow, // 子工作流
    stWait,        // 等待（人工审核/外部事件）
    stEnd          // 结束
  );

  /// <summary>动作类型</summary>
  TActionType = (
    atSkill,       // 调用 Skill
    atLLM,         // 调用 LLM
    atGuard,       // 调用 Guard 校验
    atLog,         // 记录日志
    atAssign,      // 变量赋值
    atHttp,        // HTTP 调用
    atScript       // 脚本执行
  );

  /// <summary>条件操作符</summary>
  TConditionOperator = (
    coEquals,      // ==
    coNotEquals,   // !=
    coGreaterThan, // >
    coLessThan,    // <
    coGreaterOrEqual, // >=
    coLessOrEqual, // <=
    coContains,    // contains
    coStartsWith,  // startsWith
    coEndsWith,    // endsWith
    coMatches,     // regex matches
    coIsEmpty,     // isEmpty
    coIsNotEmpty   // isNotEmpty
  );

  /// <summary>变量类型</summary>
  TVariableType = (
    vtString,
    vtInteger,
    vtFloat,
    vtBoolean,
    vtObject,
    vtArray
  );

  /// <summary>变量定义</summary>
  TVariableDefinition = record
    Name: string;
    VarType: TVariableType;
    DefaultValue: string;
    Required: Boolean;
    Description: string;
  end;

  /// <summary>条件表达式</summary>
  TConditionExpression = class
  private
    FLeftOperand: string;   // 左操作数（变量引用或字面量）
    FOperator: TConditionOperator;
    FRightOperand: string;  // 右操作数
    FLogicalOp: string;     // AND/OR（用于组合条件）
    FSubConditions: TObjectList<TConditionExpression>;
  public
    constructor Create;
    destructor Destroy; override;
    
    function ToJSON: TJSONObject;
    class function FromJSON(const AJSON: TJSONObject): TConditionExpression;
    
    property LeftOperand: string read FLeftOperand write FLeftOperand;
    property Operator: TConditionOperator read FOperator write FOperator;
    property RightOperand: string read FRightOperand write FRightOperand;
    property LogicalOp: string read FLogicalOp write FLogicalOp;
    property SubConditions: TObjectList<TConditionExpression> read FSubConditions;
  end;

  /// <summary>动作定义</summary>
  TActionDefinition = class
  private
    FActionType: TActionType;
    FTarget: string;        // Skill名称/LLM模型/URL等
    FInput: TJSONObject;    // 输入参数（支持变量引用 ${varName}）
    FOutputVar: string;     // 输出存储到的变量名
    FTimeout: Integer;      // 超时时间（毫秒）
    FRetryCount: Integer;   // 重试次数
    FRetryDelay: Integer;   // 重试间隔（毫秒）
  public
    constructor Create;
    destructor Destroy; override;
    
    function ToJSON: TJSONObject;
    class function FromJSON(const AJSON: TJSONObject): TActionDefinition;
    
    property ActionType: TActionType read FActionType write FActionType;
    property Target: string read FTarget write FTarget;
    property Input: TJSONObject read FInput write FInput;
    property OutputVar: string read FOutputVar write FOutputVar;
    property Timeout: Integer read FTimeout write FTimeout;
    property RetryCount: Integer read FRetryCount write FRetryCount;
    property RetryDelay: Integer read FRetryDelay write FRetryDelay;
  end;

  TWorkflowStep = class;
  
  /// <summary>分支定义</summary>
  TBranchDefinition = record
    Condition: TConditionExpression;
    NextStepId: string;
  end;

  /// <summary>工作流步骤</summary>
  TWorkflowStep = class
  private
    FStepId: string;
    FName: string;
    FDescription: string;
    FStepType: TStepType;
    FAction: TActionDefinition;
    FCondition: TConditionExpression;
    FBranches: TList<TBranchDefinition>;
    FNextStepId: string;        // 默认下一步
    FOnErrorStepId: string;     // 错误处理步骤
    FLoopCondition: TConditionExpression;  // 循环条件
    FLoopMaxIterations: Integer;
    FSubWorkflowId: string;     // 子工作流ID
    FParallelSteps: TStringList; // 并行步骤ID列表
    FEnabled: Boolean;
    FMetadata: TJSONObject;
  public
    constructor Create;
    destructor Destroy; override;
    
    function ToJSON: TJSONObject;
    class function FromJSON(const AJSON: TJSONObject): TWorkflowStep;
    
    property StepId: string read FStepId write FStepId;
    property Name: string read FName write FName;
    property Description: string read FDescription write FDescription;
    property StepType: TStepType read FStepType write FStepType;
    property Action: TActionDefinition read FAction write FAction;
    property Condition: TConditionExpression read FCondition write FCondition;
    property Branches: TList<TBranchDefinition> read FBranches;
    property NextStepId: string read FNextStepId write FNextStepId;
    property OnErrorStepId: string read FOnErrorStepId write FOnErrorStepId;
    property LoopCondition: TConditionExpression read FLoopCondition write FLoopCondition;
    property LoopMaxIterations: Integer read FLoopMaxIterations write FLoopMaxIterations;
    property SubWorkflowId: string read FSubWorkflowId write FSubWorkflowId;
    property ParallelSteps: TStringList read FParallelSteps;
    property Enabled: Boolean read FEnabled write FEnabled;
    property Metadata: TJSONObject read FMetadata write FMetadata;
  end;

  /// <summary>工作流定义</summary>
  TWorkflowDefinition = class
  private
    FWorkflowId: string;
    FName: string;
    FVersion: string;
    FDescription: string;
    FAuthor: string;
    FCreatedAt: TDateTime;
    FUpdatedAt: TDateTime;
    FEnabled: Boolean;
    
    FInputVariables: TList<TVariableDefinition>;
    FOutputVariables: TList<TVariableDefinition>;
    FLocalVariables: TList<TVariableDefinition>;
    
    FSteps: TObjectDictionary<string, TWorkflowStep>;
    FStartStepId: string;
    
    FTags: TStringList;
    FMetadata: TJSONObject;
  public
    constructor Create;
    destructor Destroy; override;
    
    /// <summary>序列化为 JSON</summary>
    function ToJSON: TJSONObject;
    /// <summary>从 JSON 反序列化</summary>
    class function FromJSON(const AJSON: TJSONObject): TWorkflowDefinition;
    /// <summary>从 JSON 字符串加载</summary>
    class function FromJSONString(const AJSONString: string): TWorkflowDefinition;
    /// <summary>从文件加载</summary>
    class function FromFile(const AFilePath: string): TWorkflowDefinition;
    
    /// <summary>添加步骤</summary>
    procedure AddStep(const AStep: TWorkflowStep);
    /// <summary>获取步骤</summary>
    function GetStep(const AStepId: string): TWorkflowStep;
    /// <summary>验证工作流定义</summary>
    function Validate: TStringList;
    
    property WorkflowId: string read FWorkflowId write FWorkflowId;
    property Name: string read FName write FName;
    property Version: string read FVersion write FVersion;
    property Description: string read FDescription write FDescription;
    property Author: string read FAuthor write FAuthor;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property UpdatedAt: TDateTime read FUpdatedAt write FUpdatedAt;
    property Enabled: Boolean read FEnabled write FEnabled;
    
    property InputVariables: TList<TVariableDefinition> read FInputVariables;
    property OutputVariables: TList<TVariableDefinition> read FOutputVariables;
    property LocalVariables: TList<TVariableDefinition> read FLocalVariables;
    
    property Steps: TObjectDictionary<string, TWorkflowStep> read FSteps;
    property StartStepId: string read FStartStepId write FStartStepId;
    
    property Tags: TStringList read FTags;
    property Metadata: TJSONObject read FMetadata write FMetadata;
  end;

/// <summary>步骤类型转字符串</summary>
function StepTypeToString(AType: TStepType): string;
/// <summary>字符串转步骤类型</summary>
function StringToStepType(const AStr: string): TStepType;
/// <summary>动作类型转字符串</summary>
function ActionTypeToString(AType: TActionType): string;
/// <summary>字符串转动作类型</summary>
function StringToActionType(const AStr: string): TActionType;
/// <summary>条件操作符转字符串</summary>
function ConditionOperatorToString(AOp: TConditionOperator): string;
/// <summary>字符串转条件操作符</summary>
function StringToConditionOperator(const AStr: string): TConditionOperator;

implementation

uses
  System.IOUtils, System.DateUtils, System.StrUtils;

function StepTypeToString(AType: TStepType): string;
begin
  case AType of
    stAction: Result := 'action';
    stCondition: Result := 'condition';
    stLoop: Result := 'loop';
    stParallel: Result := 'parallel';
    stSubWorkflow: Result := 'subworkflow';
    stWait: Result := 'wait';
    stEnd: Result := 'end';
  else
    Result := 'action';
  end;
end;

function StringToStepType(const AStr: string): TStepType;
begin
  if SameText(AStr, 'action') then Result := stAction
  else if SameText(AStr, 'condition') then Result := stCondition
  else if SameText(AStr, 'loop') then Result := stLoop
  else if SameText(AStr, 'parallel') then Result := stParallel
  else if SameText(AStr, 'subworkflow') then Result := stSubWorkflow
  else if SameText(AStr, 'wait') then Result := stWait
  else if SameText(AStr, 'end') then Result := stEnd
  else Result := stAction;
end;

function ActionTypeToString(AType: TActionType): string;
begin
  case AType of
    atSkill: Result := 'skill';
    atLLM: Result := 'llm';
    atGuard: Result := 'guard';
    atLog: Result := 'log';
    atAssign: Result := 'assign';
    atHttp: Result := 'http';
    atScript: Result := 'script';
  else
    Result := 'skill';
  end;
end;

function StringToActionType(const AStr: string): TActionType;
begin
  if SameText(AStr, 'skill') then Result := atSkill
  else if SameText(AStr, 'llm') then Result := atLLM
  else if SameText(AStr, 'guard') then Result := atGuard
  else if SameText(AStr, 'log') then Result := atLog
  else if SameText(AStr, 'assign') then Result := atAssign
  else if SameText(AStr, 'http') then Result := atHttp
  else if SameText(AStr, 'script') then Result := atScript
  else Result := atSkill;
end;

function ConditionOperatorToString(AOp: TConditionOperator): string;
begin
  case AOp of
    coEquals: Result := 'eq';
    coNotEquals: Result := 'ne';
    coGreaterThan: Result := 'gt';
    coLessThan: Result := 'lt';
    coGreaterOrEqual: Result := 'ge';
    coLessOrEqual: Result := 'le';
    coContains: Result := 'contains';
    coStartsWith: Result := 'startsWith';
    coEndsWith: Result := 'endsWith';
    coMatches: Result := 'matches';
    coIsEmpty: Result := 'isEmpty';
    coIsNotEmpty: Result := 'isNotEmpty';
  else
    Result := 'eq';
  end;
end;

function StringToConditionOperator(const AStr: string): TConditionOperator;
begin
  if SameText(AStr, 'eq') or SameText(AStr, '==') then Result := coEquals
  else if SameText(AStr, 'ne') or SameText(AStr, '!=') then Result := coNotEquals
  else if SameText(AStr, 'gt') or SameText(AStr, '>') then Result := coGreaterThan
  else if SameText(AStr, 'lt') or SameText(AStr, '<') then Result := coLessThan
  else if SameText(AStr, 'ge') or SameText(AStr, '>=') then Result := coGreaterOrEqual
  else if SameText(AStr, 'le') or SameText(AStr, '<=') then Result := coLessOrEqual
  else if SameText(AStr, 'contains') then Result := coContains
  else if SameText(AStr, 'startsWith') then Result := coStartsWith
  else if SameText(AStr, 'endsWith') then Result := coEndsWith
  else if SameText(AStr, 'matches') then Result := coMatches
  else if SameText(AStr, 'isEmpty') then Result := coIsEmpty
  else if SameText(AStr, 'isNotEmpty') then Result := coIsNotEmpty
  else Result := coEquals;
end;

{ TConditionExpression }

constructor TConditionExpression.Create;
begin
  inherited;
  FSubConditions := TObjectList<TConditionExpression>.Create(True);
  FLogicalOp := 'AND';
end;

destructor TConditionExpression.Destroy;
begin
  FSubConditions.Free;
  inherited;
end;

function TConditionExpression.ToJSON: TJSONObject;
var
  SubArray: TJSONArray;
  SubCond: TConditionExpression;
begin
  Result := TJSONObject.Create;
  Result.AddPair('left', FLeftOperand);
  Result.AddPair('op', ConditionOperatorToString(FOperator));
  Result.AddPair('right', FRightOperand);
  
  if FSubConditions.Count > 0 then
  begin
    Result.AddPair('logical', FLogicalOp);
    SubArray := TJSONArray.Create;
    for SubCond in FSubConditions do
      SubArray.Add(SubCond.ToJSON);
    Result.AddPair('sub', SubArray);
  end;
end;

class function TConditionExpression.FromJSON(const AJSON: TJSONObject): TConditionExpression;
var
  SubArray: TJSONArray;
  I: Integer;
  OpStr: string;
begin
  Result := TConditionExpression.Create;
  
  AJSON.TryGetValue<string>('left', Result.FLeftOperand);
  if AJSON.TryGetValue<string>('op', OpStr) then
    Result.FOperator := StringToConditionOperator(OpStr);
  AJSON.TryGetValue<string>('right', Result.FRightOperand);
  AJSON.TryGetValue<string>('logical', Result.FLogicalOp);
  
  if AJSON.TryGetValue<TJSONArray>('sub', SubArray) then
  begin
    for I := 0 to SubArray.Count - 1 do
      Result.FSubConditions.Add(FromJSON(SubArray.Items[I] as TJSONObject));
  end;
end;

{ TActionDefinition }

constructor TActionDefinition.Create;
begin
  inherited;
  FInput := TJSONObject.Create;
  FTimeout := 30000;
  FRetryCount := 3;
  FRetryDelay := 1000;
end;

destructor TActionDefinition.Destroy;
begin
  FInput.Free;
  inherited;
end;

function TActionDefinition.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', ActionTypeToString(FActionType));
  Result.AddPair('target', FTarget);
  Result.AddPair('input', FInput.Clone as TJSONObject);
  Result.AddPair('outputVar', FOutputVar);
  Result.AddPair('timeout', TJSONNumber.Create(FTimeout));
  Result.AddPair('retryCount', TJSONNumber.Create(FRetryCount));
  Result.AddPair('retryDelay', TJSONNumber.Create(FRetryDelay));
end;

class function TActionDefinition.FromJSON(const AJSON: TJSONObject): TActionDefinition;
var
  TypeStr: string;
  InputObj: TJSONObject;
begin
  Result := TActionDefinition.Create;
  
  if AJSON.TryGetValue<string>('type', TypeStr) then
    Result.FActionType := StringToActionType(TypeStr);
  AJSON.TryGetValue<string>('target', Result.FTarget);
  if AJSON.TryGetValue<TJSONObject>('input', InputObj) then
  begin
    Result.FInput.Free;
    Result.FInput := InputObj.Clone as TJSONObject;
  end;
  AJSON.TryGetValue<string>('outputVar', Result.FOutputVar);
  AJSON.TryGetValue<Integer>('timeout', Result.FTimeout);
  AJSON.TryGetValue<Integer>('retryCount', Result.FRetryCount);
  AJSON.TryGetValue<Integer>('retryDelay', Result.FRetryDelay);
end;

{ TWorkflowStep }

constructor TWorkflowStep.Create;
begin
  inherited;
  FBranches := TList<TBranchDefinition>.Create;
  FParallelSteps := TStringList.Create;
  FMetadata := TJSONObject.Create;
  FEnabled := True;
  FLoopMaxIterations := 100;
end;

destructor TWorkflowStep.Destroy;
begin
  FAction.Free;
  FCondition.Free;
  FLoopCondition.Free;
  FBranches.Free;
  FParallelSteps.Free;
  FMetadata.Free;
  inherited;
end;

function TWorkflowStep.ToJSON: TJSONObject;
var
  BranchArray: TJSONArray;
  Branch: TBranchDefinition;
  BranchObj: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id', FStepId);
  Result.AddPair('name', FName);
  Result.AddPair('description', FDescription);
  Result.AddPair('type', StepTypeToString(FStepType));
  Result.AddPair('enabled', TJSONBool.Create(FEnabled));
  
  if FAction <> nil then
    Result.AddPair('action', FAction.ToJSON);
  
  if FCondition <> nil then
    Result.AddPair('condition', FCondition.ToJSON);
  
  if FBranches.Count > 0 then
  begin
    BranchArray := TJSONArray.Create;
    for Branch in FBranches do
    begin
      BranchObj := TJSONObject.Create;
      if Branch.Condition <> nil then
        BranchObj.AddPair('condition', Branch.Condition.ToJSON);
      BranchObj.AddPair('next', Branch.NextStepId);
      BranchArray.Add(BranchObj);
    end;
    Result.AddPair('branches', BranchArray);
  end;
  
  Result.AddPair('next', FNextStepId);
  Result.AddPair('onError', FOnErrorStepId);
  
  if FLoopCondition <> nil then
    Result.AddPair('loopCondition', FLoopCondition.ToJSON);
  Result.AddPair('loopMaxIterations', TJSONNumber.Create(FLoopMaxIterations));
  
  Result.AddPair('subWorkflowId', FSubWorkflowId);
  
  if FParallelSteps.Count > 0 then
  begin
    var ParallelArray := TJSONArray.Create;
    for var S in FParallelSteps do
      ParallelArray.Add(S);
    Result.AddPair('parallelSteps', ParallelArray);
  end;
  
  Result.AddPair('metadata', FMetadata.Clone as TJSONObject);
end;

class function TWorkflowStep.FromJSON(const AJSON: TJSONObject): TWorkflowStep;
var
  TypeStr: string;
  ActionObj, CondObj, LoopCondObj, MetaObj: TJSONObject;
  BranchArray, ParallelArray: TJSONArray;
  I: Integer;
  Branch: TBranchDefinition;
begin
  Result := TWorkflowStep.Create;
  
  AJSON.TryGetValue<string>('id', Result.FStepId);
  AJSON.TryGetValue<string>('name', Result.FName);
  AJSON.TryGetValue<string>('description', Result.FDescription);
  if AJSON.TryGetValue<string>('type', TypeStr) then
    Result.FStepType := StringToStepType(TypeStr);
  AJSON.TryGetValue<Boolean>('enabled', Result.FEnabled);
  
  if AJSON.TryGetValue<TJSONObject>('action', ActionObj) then
    Result.FAction := TActionDefinition.FromJSON(ActionObj);
  
  if AJSON.TryGetValue<TJSONObject>('condition', CondObj) then
    Result.FCondition := TConditionExpression.FromJSON(CondObj);
  
  if AJSON.TryGetValue<TJSONArray>('branches', BranchArray) then
  begin
    for I := 0 to BranchArray.Count - 1 do
    begin
      var BranchObj := BranchArray.Items[I] as TJSONObject;
      if BranchObj.TryGetValue<TJSONObject>('condition', CondObj) then
        Branch.Condition := TConditionExpression.FromJSON(CondObj)
      else
        Branch.Condition := nil;
      BranchObj.TryGetValue<string>('next', Branch.NextStepId);
      Result.FBranches.Add(Branch);
    end;
  end;
  
  AJSON.TryGetValue<string>('next', Result.FNextStepId);
  AJSON.TryGetValue<string>('onError', Result.FOnErrorStepId);
  
  if AJSON.TryGetValue<TJSONObject>('loopCondition', LoopCondObj) then
    Result.FLoopCondition := TConditionExpression.FromJSON(LoopCondObj);
  AJSON.TryGetValue<Integer>('loopMaxIterations', Result.FLoopMaxIterations);
  
  AJSON.TryGetValue<string>('subWorkflowId', Result.FSubWorkflowId);
  
  if AJSON.TryGetValue<TJSONArray>('parallelSteps', ParallelArray) then
  begin
    for I := 0 to ParallelArray.Count - 1 do
      Result.FParallelSteps.Add(ParallelArray.Items[I].Value);
  end;
  
  if AJSON.TryGetValue<TJSONObject>('metadata', MetaObj) then
  begin
    Result.FMetadata.Free;
    Result.FMetadata := MetaObj.Clone as TJSONObject;
  end;
end;

{ TWorkflowDefinition }

constructor TWorkflowDefinition.Create;
begin
  inherited;
  FInputVariables := TList<TVariableDefinition>.Create;
  FOutputVariables := TList<TVariableDefinition>.Create;
  FLocalVariables := TList<TVariableDefinition>.Create;
  FSteps := TObjectDictionary<string, TWorkflowStep>.Create([doOwnsValues]);
  FTags := TStringList.Create;
  FMetadata := TJSONObject.Create;
  FEnabled := True;
  FCreatedAt := Now;
  FUpdatedAt := Now;
  FVersion := '1.0';
end;

destructor TWorkflowDefinition.Destroy;
begin
  FInputVariables.Free;
  FOutputVariables.Free;
  FLocalVariables.Free;
  FSteps.Free;
  FTags.Free;
  FMetadata.Free;
  inherited;
end;

procedure TWorkflowDefinition.AddStep(const AStep: TWorkflowStep);
begin
  FSteps.AddOrSetValue(AStep.StepId, AStep);
  FUpdatedAt := Now;
end;

function TWorkflowDefinition.GetStep(const AStepId: string): TWorkflowStep;
begin
  if not FSteps.TryGetValue(AStepId, Result) then
    Result := nil;
end;

function TWorkflowDefinition.Validate: TStringList;
begin
  Result := TStringList.Create;
  
  // 基础验证
  if FWorkflowId = '' then
    Result.Add('Workflow ID is required');
  if FName = '' then
    Result.Add('Workflow name is required');
  if FSteps.Count = 0 then
    Result.Add('Workflow must have at least one step');
  if FStartStepId = '' then
    Result.Add('Start step ID is required');
  if not FSteps.ContainsKey(FStartStepId) then
    Result.Add('Start step ID does not exist: ' + FStartStepId);
  
  // 验证步骤引用
  for var StepPair in FSteps do
  begin
    var Step := StepPair.Value;
    if (Step.NextStepId <> '') and (Step.NextStepId <> 'END') and 
       not FSteps.ContainsKey(Step.NextStepId) then
      Result.Add(Format('Step %s references non-existent next step: %s', 
        [Step.StepId, Step.NextStepId]));
    
    if (Step.OnErrorStepId <> '') and not FSteps.ContainsKey(Step.OnErrorStepId) then
      Result.Add(Format('Step %s references non-existent error step: %s', 
        [Step.StepId, Step.OnErrorStepId]));
  end;
end;

function TWorkflowDefinition.ToJSON: TJSONObject;
var
  VarsArray, StepsArray, TagsArray: TJSONArray;
  VarDef: TVariableDefinition;
  VarObj: TJSONObject;
begin
  Result := TJSONObject.Create;
  
  // 元数据
  Result.AddPair('id', FWorkflowId);
  Result.AddPair('name', FName);
  Result.AddPair('version', FVersion);
  Result.AddPair('description', FDescription);
  Result.AddPair('author', FAuthor);
  Result.AddPair('createdAt', DateToISO8601(FCreatedAt));
  Result.AddPair('updatedAt', DateToISO8601(FUpdatedAt));
  Result.AddPair('enabled', TJSONBool.Create(FEnabled));
  Result.AddPair('startStep', FStartStepId);
  
  // 输入变量
  VarsArray := TJSONArray.Create;
  for VarDef in FInputVariables do
  begin
    VarObj := TJSONObject.Create;
    VarObj.AddPair('name', VarDef.Name);
    VarObj.AddPair('type', IntToStr(Ord(VarDef.VarType)));
    VarObj.AddPair('default', VarDef.DefaultValue);
    VarObj.AddPair('required', TJSONBool.Create(VarDef.Required));
    VarObj.AddPair('description', VarDef.Description);
    VarsArray.Add(VarObj);
  end;
  Result.AddPair('inputVariables', VarsArray);
  
  // 输出变量
  VarsArray := TJSONArray.Create;
  for VarDef in FOutputVariables do
  begin
    VarObj := TJSONObject.Create;
    VarObj.AddPair('name', VarDef.Name);
    VarObj.AddPair('type', IntToStr(Ord(VarDef.VarType)));
    VarsArray.Add(VarObj);
  end;
  Result.AddPair('outputVariables', VarsArray);
  
  // 步骤
  StepsArray := TJSONArray.Create;
  for var StepPair in FSteps do
    StepsArray.Add(StepPair.Value.ToJSON);
  Result.AddPair('steps', StepsArray);
  
  // 标签
  TagsArray := TJSONArray.Create;
  for var Tag in FTags do
    TagsArray.Add(Tag);
  Result.AddPair('tags', TagsArray);
  
  Result.AddPair('metadata', FMetadata.Clone as TJSONObject);
end;

class function TWorkflowDefinition.FromJSON(const AJSON: TJSONObject): TWorkflowDefinition;
var
  VarsArray, StepsArray, TagsArray: TJSONArray;
  I: Integer;
  VarDef: TVariableDefinition;
  Step: TWorkflowStep;
  CreatedStr, UpdatedStr: string;
begin
  Result := TWorkflowDefinition.Create;
  
  AJSON.TryGetValue<string>('id', Result.FWorkflowId);
  AJSON.TryGetValue<string>('name', Result.FName);
  AJSON.TryGetValue<string>('version', Result.FVersion);
  AJSON.TryGetValue<string>('description', Result.FDescription);
  AJSON.TryGetValue<string>('author', Result.FAuthor);
  AJSON.TryGetValue<Boolean>('enabled', Result.FEnabled);
  AJSON.TryGetValue<string>('startStep', Result.FStartStepId);
  
  if AJSON.TryGetValue<string>('createdAt', CreatedStr) then
    Result.FCreatedAt := ISO8601ToDate(CreatedStr);
  if AJSON.TryGetValue<string>('updatedAt', UpdatedStr) then
    Result.FUpdatedAt := ISO8601ToDate(UpdatedStr);
  
  // 解析输入变量
  if AJSON.TryGetValue<TJSONArray>('inputVariables', VarsArray) then
  begin
    for I := 0 to VarsArray.Count - 1 do
    begin
      var VarObj := VarsArray.Items[I] as TJSONObject;
      VarObj.TryGetValue<string>('name', VarDef.Name);
      var TypeStr: string;
      if VarObj.TryGetValue<string>('type', TypeStr) then
        VarDef.VarType := TVariableType(StrToIntDef(TypeStr, 0));
      VarObj.TryGetValue<string>('default', VarDef.DefaultValue);
      VarObj.TryGetValue<Boolean>('required', VarDef.Required);
      VarObj.TryGetValue<string>('description', VarDef.Description);
      Result.FInputVariables.Add(VarDef);
    end;
  end;
  
  // 解析步骤
  if AJSON.TryGetValue<TJSONArray>('steps', StepsArray) then
  begin
    for I := 0 to StepsArray.Count - 1 do
    begin
      Step := TWorkflowStep.FromJSON(StepsArray.Items[I] as TJSONObject);
      Result.FSteps.AddOrSetValue(Step.StepId, Step);
    end;
  end;
  
  // 解析标签
  if AJSON.TryGetValue<TJSONArray>('tags', TagsArray) then
  begin
    for I := 0 to TagsArray.Count - 1 do
      Result.FTags.Add(TagsArray.Items[I].Value);
  end;
  
  var MetaObj: TJSONObject;
  if AJSON.TryGetValue<TJSONObject>('metadata', MetaObj) then
  begin
    Result.FMetadata.Free;
    Result.FMetadata := MetaObj.Clone as TJSONObject;
  end;
end;

class function TWorkflowDefinition.FromJSONString(const AJSONString: string): TWorkflowDefinition;
var
  JSONValue: TJSONValue;
begin
  JSONValue := TJSONObject.ParseJSONValue(AJSONString);
  try
    if JSONValue is TJSONObject then
      Result := FromJSON(JSONValue as TJSONObject)
    else
      raise EOperationException.Create('Invalid JSON: expected object');
  finally
    JSONValue.Free;
  end;
end;

class function TWorkflowDefinition.FromFile(const AFilePath: string): TWorkflowDefinition;
var
  JSONContent: string;
begin
  JSONContent := TFile.ReadAllText(AFilePath, TEncoding.UTF8);
  Result := FromJSONString(JSONContent);
end;

end.
