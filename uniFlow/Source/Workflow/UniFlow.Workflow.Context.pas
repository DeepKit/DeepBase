unit UniFlow.Workflow.Context;

{*******************************************************************************
  UniFlow.Workflow.Context - 工作流上下文管理
  
  描述：
    管理工作流执行时的变量上下文，包括：
    - 变量存储与作用域
    - 变量引用解析 (${varName})
    - 表达式求值
    - 条件判断
    
  作者：鲁班（开发者）
  日期：2025-12-04
  版本：1.0
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Generics.Collections,
  System.RegularExpressions, System.Variants,
  UniFlow.Workflow.Definition;

type
  /// <summary>变量作用域</summary>
  TVariableScope = (
    vsGlobal,    // 全局变量（跨工作流）
    vsWorkflow,  // 工作流级别变量
    vsStep,      // 步骤级别变量（临时）
    vsInput,     // 输入变量
    vsOutput     // 输出变量
  );

  /// <summary>变量值</summary>
  TVariableValue = class
  private
    FName: string;
    FScope: TVariableScope;
    FVarType: TVariableType;
    FValue: Variant;
    FJSONValue: TJSONValue;
    FReadOnly: Boolean;
  public
    constructor Create(const AName: string; AScope: TVariableScope);
    destructor Destroy; override;
    
    procedure SetString(const AValue: string);
    procedure SetInteger(const AValue: Int64);
    procedure SetFloat(const AValue: Double);
    procedure SetBoolean(const AValue: Boolean);
    procedure SetJSON(const AValue: TJSONValue);
    
    function AsString: string;
    function AsInteger: Int64;
    function AsFloat: Double;
    function AsBoolean: Boolean;
    function AsJSON: TJSONValue;
    
    function ToJSON: TJSONValue;
    class function FromJSON(const AName: string; AScope: TVariableScope; 
      const AValue: TJSONValue): TVariableValue;
    
    property Name: string read FName;
    property Scope: TVariableScope read FScope;
    property VarType: TVariableType read FVarType;
    property Value: Variant read FValue;
    property ReadOnly: Boolean read FReadOnly write FReadOnly;
  end;

  /// <summary>工作流上下文</summary>
  TWorkflowContext = class
  private
    FWorkflowId: string;
    FInstanceId: string;
    FVariables: TObjectDictionary<string, TVariableValue>;
    FScopeStack: TStack<TDictionary<string, TVariableValue>>;
    FVarRefPattern: TRegEx;
    
    function GetScopedKey(const AName: string; AScope: TVariableScope): string;
    function FindVariable(const AName: string): TVariableValue;
  public
    constructor Create(const AWorkflowId, AInstanceId: string);
    destructor Destroy; override;
    
    // 变量操作
    procedure SetVariable(const AName: string; const AValue: Variant; 
      AScope: TVariableScope = vsWorkflow);
    procedure SetVariableJSON(const AName: string; const AValue: TJSONValue;
      AScope: TVariableScope = vsWorkflow);
    function GetVariable(const AName: string): TVariableValue;
    function GetVariableValue(const AName: string): Variant;
    function GetVariableJSON(const AName: string): TJSONValue;
    function HasVariable(const AName: string): Boolean;
    procedure DeleteVariable(const AName: string);
    
    // 作用域管理
    procedure PushScope;
    procedure PopScope;
    
    // 变量引用解析
    function ResolveString(const ATemplate: string): string;
    function ResolveJSON(const ATemplate: TJSONObject): TJSONObject;
    
    // 条件求值
    function EvaluateCondition(const ACondition: TConditionExpression): Boolean;
    
    // 序列化
    function ToJSON: TJSONObject;
    procedure FromJSON(const AJSON: TJSONObject);
    
    // 获取所有变量
    function GetAllVariables: TJSONObject;
    
    property WorkflowId: string read FWorkflowId;
    property InstanceId: string read FInstanceId;
  end;

  /// <summary>表达式求值器</summary>
  TExpressionEvaluator = class
  public
    class function Compare(const ALeft, ARight: Variant; AOp: TConditionOperator): Boolean;
    class function EvaluateSimpleExpression(const AExpr: string; AContext: TWorkflowContext): Variant;
  end;

implementation

uses
  System.StrUtils, System.Math;

{ TVariableValue }

constructor TVariableValue.Create(const AName: string; AScope: TVariableScope);
begin
  inherited Create;
  FName := AName;
  FScope := AScope;
  FVarType := vtString;
  FValue := Null;
  FJSONValue := nil;
  FReadOnly := False;
end;

destructor TVariableValue.Destroy;
begin
  FJSONValue.Free;
  inherited;
end;

procedure TVariableValue.SetString(const AValue: string);
begin
  FVarType := vtString;
  FValue := AValue;
  FreeAndNil(FJSONValue);
end;

procedure TVariableValue.SetInteger(const AValue: Int64);
begin
  FVarType := vtInteger;
  FValue := AValue;
  FreeAndNil(FJSONValue);
end;

procedure TVariableValue.SetFloat(const AValue: Double);
begin
  FVarType := vtFloat;
  FValue := AValue;
  FreeAndNil(FJSONValue);
end;

procedure TVariableValue.SetBoolean(const AValue: Boolean);
begin
  FVarType := vtBoolean;
  FValue := AValue;
  FreeAndNil(FJSONValue);
end;

procedure TVariableValue.SetJSON(const AValue: TJSONValue);
begin
  if AValue is TJSONArray then
    FVarType := vtArray
  else
    FVarType := vtObject;
  FValue := Null;
  FreeAndNil(FJSONValue);
  if AValue <> nil then
    FJSONValue := AValue.Clone as TJSONValue;
end;

function TVariableValue.AsString: string;
begin
  if FJSONValue <> nil then
    Result := FJSONValue.ToJSON
  else if VarIsNull(FValue) then
    Result := ''
  else
    Result := VarToStr(FValue);
end;

function TVariableValue.AsInteger: Int64;
begin
  if VarIsNull(FValue) then
    Result := 0
  else
    Result := FValue;
end;

function TVariableValue.AsFloat: Double;
begin
  if VarIsNull(FValue) then
    Result := 0
  else
    Result := FValue;
end;

function TVariableValue.AsBoolean: Boolean;
begin
  if VarIsNull(FValue) then
    Result := False
  else
    Result := FValue;
end;

function TVariableValue.AsJSON: TJSONValue;
begin
  if FJSONValue <> nil then
    Result := FJSONValue.Clone as TJSONValue
  else if FVarType = vtString then
    Result := TJSONString.Create(AsString)
  else if FVarType = vtInteger then
    Result := TJSONNumber.Create(AsInteger)
  else if FVarType = vtFloat then
    Result := TJSONNumber.Create(AsFloat)
  else if FVarType = vtBoolean then
    Result := TJSONBool.Create(AsBoolean)
  else
    Result := TJSONNull.Create;
end;

function TVariableValue.ToJSON: TJSONValue;
begin
  Result := AsJSON;
end;

class function TVariableValue.FromJSON(const AName: string; AScope: TVariableScope;
  const AValue: TJSONValue): TVariableValue;
begin
  Result := TVariableValue.Create(AName, AScope);
  
  if AValue is TJSONString then
    Result.SetString(TJSONString(AValue).Value)
  else if AValue is TJSONNumber then
  begin
    var NumStr := TJSONNumber(AValue).ToJSON;
    if Pos('.', NumStr) > 0 then
      Result.SetFloat(TJSONNumber(AValue).AsDouble)
    else
      Result.SetInteger(TJSONNumber(AValue).AsInt64);
  end
  else if AValue is TJSONBool then
    Result.SetBoolean(TJSONBool(AValue).AsBoolean)
  else if AValue is TJSONObject then
    Result.SetJSON(AValue)
  else if AValue is TJSONArray then
    Result.SetJSON(AValue)
  else
    Result.SetString('');
end;

{ TWorkflowContext }

constructor TWorkflowContext.Create(const AWorkflowId, AInstanceId: string);
begin
  inherited Create;
  FWorkflowId := AWorkflowId;
  FInstanceId := AInstanceId;
  FVariables := TObjectDictionary<string, TVariableValue>.Create([doOwnsValues]);
  FScopeStack := TStack<TDictionary<string, TVariableValue>>.Create;
  FVarRefPattern := TRegEx.Create('\$\{([^}]+)\}');
end;

destructor TWorkflowContext.Destroy;
begin
  while FScopeStack.Count > 0 do
  begin
    var Scope := FScopeStack.Pop;
    Scope.Free;
  end;
  FScopeStack.Free;
  FVariables.Free;
  inherited;
end;

function TWorkflowContext.GetScopedKey(const AName: string; AScope: TVariableScope): string;
begin
  case AScope of
    vsGlobal: Result := 'global.' + AName;
    vsWorkflow: Result := 'workflow.' + AName;
    vsStep: Result := 'step.' + AName;
    vsInput: Result := 'input.' + AName;
    vsOutput: Result := 'output.' + AName;
  else
    Result := AName;
  end;
end;

function TWorkflowContext.FindVariable(const AName: string): TVariableValue;
var
  SearchKeys: array of string;
  Key: string;
begin
  Result := nil;
  
  // 如果已经带有作用域前缀，直接查找
  if FVariables.TryGetValue(AName, Result) then
    Exit;
  
  // 按优先级顺序查找
  SearchKeys := [
    'step.' + AName,
    'workflow.' + AName,
    'input.' + AName,
    'output.' + AName,
    'global.' + AName
  ];
  
  for Key in SearchKeys do
  begin
    if FVariables.TryGetValue(Key, Result) then
      Exit;
  end;
end;

procedure TWorkflowContext.SetVariable(const AName: string; const AValue: Variant;
  AScope: TVariableScope);
var
  Key: string;
  VarValue: TVariableValue;
begin
  Key := GetScopedKey(AName, AScope);
  
  if not FVariables.TryGetValue(Key, VarValue) then
  begin
    VarValue := TVariableValue.Create(AName, AScope);
    FVariables.Add(Key, VarValue);
  end
  else if VarValue.ReadOnly then
    raise Exception.CreateFmt('Variable %s is read-only', [AName]);
  
  if VarIsType(AValue, varString) or VarIsType(AValue, varUString) then
    VarValue.SetString(AValue)
  else if VarIsType(AValue, varInteger) or VarIsType(AValue, varInt64) then
    VarValue.SetInteger(AValue)
  else if VarIsType(AValue, varDouble) or VarIsType(AValue, varSingle) then
    VarValue.SetFloat(AValue)
  else if VarIsType(AValue, varBoolean) then
    VarValue.SetBoolean(AValue)
  else
    VarValue.SetString(VarToStr(AValue));
end;

procedure TWorkflowContext.SetVariableJSON(const AName: string; const AValue: TJSONValue;
  AScope: TVariableScope);
var
  Key: string;
  VarValue: TVariableValue;
begin
  Key := GetScopedKey(AName, AScope);
  
  if not FVariables.TryGetValue(Key, VarValue) then
  begin
    VarValue := TVariableValue.Create(AName, AScope);
    FVariables.Add(Key, VarValue);
  end
  else if VarValue.ReadOnly then
    raise Exception.CreateFmt('Variable %s is read-only', [AName]);
  
  VarValue.SetJSON(AValue);
end;

function TWorkflowContext.GetVariable(const AName: string): TVariableValue;
begin
  Result := FindVariable(AName);
end;

function TWorkflowContext.GetVariableValue(const AName: string): Variant;
var
  VarValue: TVariableValue;
begin
  VarValue := FindVariable(AName);
  if VarValue <> nil then
    Result := VarValue.Value
  else
    Result := Null;
end;

function TWorkflowContext.GetVariableJSON(const AName: string): TJSONValue;
var
  VarValue: TVariableValue;
begin
  VarValue := FindVariable(AName);
  if VarValue <> nil then
    Result := VarValue.AsJSON
  else
    Result := TJSONNull.Create;
end;

function TWorkflowContext.HasVariable(const AName: string): Boolean;
begin
  Result := FindVariable(AName) <> nil;
end;

procedure TWorkflowContext.DeleteVariable(const AName: string);
var
  Key: string;
begin
  // 尝试各种作用域
  for var Scope := Low(TVariableScope) to High(TVariableScope) do
  begin
    Key := GetScopedKey(AName, Scope);
    if FVariables.ContainsKey(Key) then
    begin
      FVariables.Remove(Key);
      Exit;
    end;
  end;
end;

procedure TWorkflowContext.PushScope;
begin
  FScopeStack.Push(TDictionary<string, TVariableValue>.Create);
end;

procedure TWorkflowContext.PopScope;
begin
  if FScopeStack.Count > 0 then
  begin
    var Scope := FScopeStack.Pop;
    // 清理步骤级变量
    for var Key in Scope.Keys do
      FVariables.Remove(Key);
    Scope.Free;
  end;
end;

function TWorkflowContext.ResolveString(const ATemplate: string): string;
var
  Matches: TMatchCollection;
  Match: TMatch;
  VarName, VarValue: string;
begin
  Result := ATemplate;
  
  Matches := FVarRefPattern.Matches(ATemplate);
  for Match in Matches do
  begin
    VarName := Match.Groups[1].Value;
    
    var Variable := FindVariable(VarName);
    if Variable <> nil then
      VarValue := Variable.AsString
    else
      VarValue := '';
    
    Result := StringReplace(Result, Match.Value, VarValue, [rfReplaceAll]);
  end;
end;

function TWorkflowContext.ResolveJSON(const ATemplate: TJSONObject): TJSONObject;
var
  Pair: TJSONPair;
  ResolvedValue: string;
begin
  Result := TJSONObject.Create;
  
  for Pair in ATemplate do
  begin
    if Pair.JsonValue is TJSONString then
    begin
      ResolvedValue := ResolveString(TJSONString(Pair.JsonValue).Value);
      Result.AddPair(Pair.JsonString.Value, ResolvedValue);
    end
    else if Pair.JsonValue is TJSONObject then
    begin
      Result.AddPair(Pair.JsonString.Value, ResolveJSON(TJSONObject(Pair.JsonValue)));
    end
    else
    begin
      Result.AddPair(Pair.JsonString.Value, Pair.JsonValue.Clone as TJSONValue);
    end;
  end;
end;

function TWorkflowContext.EvaluateCondition(const ACondition: TConditionExpression): Boolean;
var
  LeftValue, RightValue: Variant;
  SubResult: Boolean;
  SubCond: TConditionExpression;
begin
  if ACondition = nil then
  begin
    Result := True;
    Exit;
  end;
  
  // 解析左操作数
  if ACondition.LeftOperand.StartsWith('$') then
    LeftValue := GetVariableValue(Copy(ACondition.LeftOperand, 2, MaxInt))
  else
    LeftValue := ACondition.LeftOperand;
  
  // 解析右操作数
  if ACondition.RightOperand.StartsWith('$') then
    RightValue := GetVariableValue(Copy(ACondition.RightOperand, 2, MaxInt))
  else
    RightValue := ACondition.RightOperand;
  
  // 基本比较
  Result := TExpressionEvaluator.Compare(LeftValue, RightValue, ACondition.Operator);
  
  // 处理子条件
  if ACondition.SubConditions.Count > 0 then
  begin
    for SubCond in ACondition.SubConditions do
    begin
      SubResult := EvaluateCondition(SubCond);
      
      if SameText(ACondition.LogicalOp, 'AND') then
        Result := Result and SubResult
      else if SameText(ACondition.LogicalOp, 'OR') then
        Result := Result or SubResult;
    end;
  end;
end;

function TWorkflowContext.ToJSON: TJSONObject;
var
  VarsObj: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('workflowId', FWorkflowId);
  Result.AddPair('instanceId', FInstanceId);
  
  VarsObj := TJSONObject.Create;
  for var VarPair in FVariables do
    VarsObj.AddPair(VarPair.Key, VarPair.Value.ToJSON);
  Result.AddPair('variables', VarsObj);
end;

procedure TWorkflowContext.FromJSON(const AJSON: TJSONObject);
var
  VarsObj: TJSONObject;
  VarPair: TJSONPair;
  ScopeName, VarName: string;
  Scope: TVariableScope;
  DotPos: Integer;
begin
  AJSON.TryGetValue<string>('workflowId', FWorkflowId);
  AJSON.TryGetValue<string>('instanceId', FInstanceId);
  
  if AJSON.TryGetValue<TJSONObject>('variables', VarsObj) then
  begin
    for VarPair in VarsObj do
    begin
      // 解析作用域
      DotPos := Pos('.', VarPair.JsonString.Value);
      if DotPos > 0 then
      begin
        ScopeName := Copy(VarPair.JsonString.Value, 1, DotPos - 1);
        VarName := Copy(VarPair.JsonString.Value, DotPos + 1, MaxInt);
        
        if SameText(ScopeName, 'global') then Scope := vsGlobal
        else if SameText(ScopeName, 'workflow') then Scope := vsWorkflow
        else if SameText(ScopeName, 'step') then Scope := vsStep
        else if SameText(ScopeName, 'input') then Scope := vsInput
        else if SameText(ScopeName, 'output') then Scope := vsOutput
        else
        begin
          Scope := vsWorkflow;
          VarName := VarPair.JsonString.Value;
        end;
      end
      else
      begin
        Scope := vsWorkflow;
        VarName := VarPair.JsonString.Value;
      end;
      
      var Variable := TVariableValue.FromJSON(VarName, Scope, VarPair.JsonValue);
      FVariables.AddOrSetValue(VarPair.JsonString.Value, Variable);
    end;
  end;
end;

function TWorkflowContext.GetAllVariables: TJSONObject;
begin
  Result := TJSONObject.Create;
  for var VarPair in FVariables do
    Result.AddPair(VarPair.Key, VarPair.Value.ToJSON);
end;

{ TExpressionEvaluator }

class function TExpressionEvaluator.Compare(const ALeft, ARight: Variant;
  AOp: TConditionOperator): Boolean;
var
  LeftStr, RightStr: string;
begin
  case AOp of
    coEquals:
      Result := ALeft = ARight;
    coNotEquals:
      Result := ALeft <> ARight;
    coGreaterThan:
      Result := ALeft > ARight;
    coLessThan:
      Result := ALeft < ARight;
    coGreaterOrEqual:
      Result := ALeft >= ARight;
    coLessOrEqual:
      Result := ALeft <= ARight;
    coContains:
    begin
      LeftStr := VarToStr(ALeft);
      RightStr := VarToStr(ARight);
      Result := Pos(RightStr, LeftStr) > 0;
    end;
    coStartsWith:
    begin
      LeftStr := VarToStr(ALeft);
      RightStr := VarToStr(ARight);
      Result := LeftStr.StartsWith(RightStr);
    end;
    coEndsWith:
    begin
      LeftStr := VarToStr(ALeft);
      RightStr := VarToStr(ARight);
      Result := LeftStr.EndsWith(RightStr);
    end;
    coMatches:
    begin
      LeftStr := VarToStr(ALeft);
      RightStr := VarToStr(ARight);
      Result := TRegEx.IsMatch(LeftStr, RightStr);
    end;
    coIsEmpty:
    begin
      LeftStr := VarToStr(ALeft);
      Result := LeftStr.IsEmpty or VarIsNull(ALeft);
    end;
    coIsNotEmpty:
    begin
      LeftStr := VarToStr(ALeft);
      Result := not LeftStr.IsEmpty and not VarIsNull(ALeft);
    end;
  else
    Result := False;
  end;
end;

class function TExpressionEvaluator.EvaluateSimpleExpression(const AExpr: string;
  AContext: TWorkflowContext): Variant;
begin
  // 简单表达式求值：支持变量引用
  if AExpr.StartsWith('$') then
    Result := AContext.GetVariableValue(Copy(AExpr, 2, MaxInt))
  else if AExpr.StartsWith('"') and AExpr.EndsWith('"') then
    Result := Copy(AExpr, 2, Length(AExpr) - 2)
  else if TryStrToInt64(AExpr, Int64(Result)) then
    // 已赋值
  else if TryStrToFloat(AExpr, Double(Result)) then
    // 已赋值
  else if SameText(AExpr, 'true') then
    Result := True
  else if SameText(AExpr, 'false') then
    Result := False
  else
    Result := AExpr;
end;

end.
