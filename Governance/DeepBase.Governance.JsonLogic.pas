// AI-GENERATED
// DeepBase.Governance.JsonLogic.pas
// 第四层：JsonLogic 表达式引擎（20 个操作符）
// 路由条件的核心引擎

unit DeepBase.Governance.JsonLogic;

interface

uses
  System.SysUtils,
  System.JSON,
  System.Generics.Collections,
  System.StrUtils,
  System.Variants;

type
  /// JsonLogic 求值异常
  EJsonLogicError = class(Exception);

  /// JsonLogic 操作符处理器
  TJsonLogicOperator = reference to function(AArgs: TJSONArray;
    AData: TJSONObject): TJSONValue;

  /// JsonLogic 表达式引擎
  /// 内存策略：
  ///   - ApplyBool / ApplyStr 是推荐的公共 API，内部管理所有临时对象
  ///   - Apply 返回的 TJSONValue 由引擎内部管理，调用方不得 Free
  ///   - 返回值在下一次 Apply 调用前有效
  TJsonLogicEngine = class
  private
    FOperators: TDictionary<string, TJsonLogicOperator>;
    FManagedResults: TObjectList<TJSONValue>;  // P1 修复：统一管理临时对象
    procedure RegisterBuiltinOperators;
    procedure ClearManaged;
    function Manage(AValue: TJSONValue): TJSONValue;  // 注册到管理列表

    // 内置操作符实现
    function OpVar(AArgs: TJSONArray; AData: TJSONObject): TJSONValue;
    function OpEqual(AArgs: TJSONArray; AData: TJSONObject): TJSONValue;
    function OpStrictEqual(AArgs: TJSONArray; AData: TJSONObject): TJSONValue;
    function OpNotEqual(AArgs: TJSONArray; AData: TJSONObject): TJSONValue;
    function OpGreaterThan(AArgs: TJSONArray; AData: TJSONObject): TJSONValue;
    function OpGreaterEqual(AArgs: TJSONArray; AData: TJSONObject): TJSONValue;
    function OpLessThan(AArgs: TJSONArray; AData: TJSONObject): TJSONValue;
    function OpLessEqual(AArgs: TJSONArray; AData: TJSONObject): TJSONValue;
    function OpAnd(AArgs: TJSONArray; AData: TJSONObject): TJSONValue;
    function OpOr(AArgs: TJSONArray; AData: TJSONObject): TJSONValue;
    function OpNot(AArgs: TJSONArray; AData: TJSONObject): TJSONValue;
    function OpIf(AArgs: TJSONArray; AData: TJSONObject): TJSONValue;
    function OpIn(AArgs: TJSONArray; AData: TJSONObject): TJSONValue;
    function OpCat(AArgs: TJSONArray; AData: TJSONObject): TJSONValue;
    function OpSubstr(AArgs: TJSONArray; AData: TJSONObject): TJSONValue;
    function OpPlus(AArgs: TJSONArray; AData: TJSONObject): TJSONValue;
    function OpMinus(AArgs: TJSONArray; AData: TJSONObject): TJSONValue;
    function OpMultiply(AArgs: TJSONArray; AData: TJSONObject): TJSONValue;
    function OpDivide(AArgs: TJSONArray; AData: TJSONObject): TJSONValue;
    function OpMissing(AArgs: TJSONArray; AData: TJSONObject): TJSONValue;

    // 辅助
    function ResolveVar(const APath: string; AData: TJSONObject): TJSONValue;
    function IsTrue(AValue: TJSONValue): Boolean;
    function ToNumber(AValue: TJSONValue): Double;
    function ToString(AValue: TJSONValue): string; reintroduce;
  public
    constructor Create;
    destructor Destroy; override;

    /// 注册自定义操作符
    procedure RegisterOperator(const AName: string; AHandler: TJsonLogicOperator);

    /// 求值：传入 JsonLogic 表达式和数据，返回结果
    function Apply(ALogic: TJSONValue; AData: TJSONObject): TJSONValue;

    /// 求值并返回布尔结果
    function ApplyBool(ALogic: TJSONValue; AData: TJSONObject): Boolean;

    /// 从 JSON 字符串求值
    function ApplyStr(const ALogicJson: string; AData: TJSONObject): Boolean;
  end;

implementation

{ TJsonLogicEngine }

constructor TJsonLogicEngine.Create;
begin
  inherited Create;
  FOperators := TDictionary<string, TJsonLogicOperator>.Create;
  FManagedResults := TObjectList<TJSONValue>.Create(True);
  RegisterBuiltinOperators;
end;

destructor TJsonLogicEngine.Destroy;
begin
  FManagedResults.Free;
  FOperators.Free;
  inherited;
end;

procedure TJsonLogicEngine.ClearManaged;
begin
  FManagedResults.Clear;
end;

function TJsonLogicEngine.Manage(AValue: TJSONValue): TJSONValue;
begin
  // 只管理新创建的值，不管理输入数据中的引用
  if AValue <> nil then
    FManagedResults.Add(AValue);
  Result := AValue;
end;

procedure TJsonLogicEngine.RegisterBuiltinOperators;
begin
  FOperators.Add('var', OpVar);
  FOperators.Add('==', OpEqual);
  FOperators.Add('===', OpStrictEqual);
  FOperators.Add('!=', OpNotEqual);
  FOperators.Add('>', OpGreaterThan);
  FOperators.Add('>=', OpGreaterEqual);
  FOperators.Add('<', OpLessThan);
  FOperators.Add('<=', OpLessEqual);
  FOperators.Add('and', OpAnd);
  FOperators.Add('or', OpOr);
  FOperators.Add('!', OpNot);
  FOperators.Add('if', OpIf);
  FOperators.Add('in', OpIn);
  FOperators.Add('cat', OpCat);
  FOperators.Add('substr', OpSubstr);
  FOperators.Add('+', OpPlus);
  FOperators.Add('-', OpMinus);
  FOperators.Add('*', OpMultiply);
  FOperators.Add('/', OpDivide);
  FOperators.Add('missing', OpMissing);
end;

procedure TJsonLogicEngine.RegisterOperator(const AName: string;
  AHandler: TJsonLogicOperator);
begin
  FOperators.AddOrSetValue(AName, AHandler);
end;

function TJsonLogicEngine.ResolveVar(const APath: string;
  AData: TJSONObject): TJSONValue;
var
  LParts: TArray<string>;
  LCurrent: TJSONValue;
  I: Integer;
begin
  if (APath = '') or (AData = nil) then
    Exit(AData);

  LParts := APath.Split(['.']);
  LCurrent := AData;

  for I := 0 to High(LParts) do
  begin
    if LCurrent is TJSONObject then
      LCurrent := TJSONObject(LCurrent).GetValue(LParts[I])
    else
      Exit(Manage(TJSONNull.Create));

    if LCurrent = nil then
      Exit(Manage(TJSONNull.Create));
  end;

  Result := LCurrent;
end;

function TJsonLogicEngine.IsTrue(AValue: TJSONValue): Boolean;
begin
  if AValue = nil then Exit(False);
  if AValue is TJSONNull then Exit(False);
  if AValue is TJSONBool then Exit(TJSONBool(AValue).AsBoolean);
  if AValue is TJSONNumber then Exit(TJSONNumber(AValue).AsDouble <> 0);
  if AValue is TJSONString then Exit(TJSONString(AValue).Value <> '');
  if AValue is TJSONArray then Exit(TJSONArray(AValue).Count > 0);
  Result := True;
end;

function TJsonLogicEngine.ToNumber(AValue: TJSONValue): Double;
begin
  if AValue = nil then Exit(0);
  if AValue is TJSONNumber then Exit(TJSONNumber(AValue).AsDouble);
  if AValue is TJSONBool then
  begin
    if TJSONBool(AValue).AsBoolean then Exit(1) else Exit(0);
  end;
  if AValue is TJSONString then
  begin
    if not TryStrToFloat(TJSONString(AValue).Value, Result) then
      Result := 0;
    Exit;
  end;
  Result := 0;
end;

function TJsonLogicEngine.ToString(AValue: TJSONValue): string;
begin
  if AValue = nil then Exit('');
  if AValue is TJSONNull then Exit('null');
  if AValue is TJSONString then Exit(TJSONString(AValue).Value);
  if AValue is TJSONNumber then Exit(TJSONNumber(AValue).ToString);
  if AValue is TJSONBool then
  begin
    if TJSONBool(AValue).AsBoolean then Exit('true') else Exit('false');
  end;
  Result := AValue.ToJSON;
end;

function TJsonLogicEngine.Apply(ALogic: TJSONValue;
  AData: TJSONObject): TJSONValue;
var
  LObj: TJSONObject;
  LPair: TJSONPair;
  LOpName: string;
  LArgs: TJSONArray;
  LArgsOwned: Boolean;
  LHandler: TJsonLogicOperator;
  LEvaluatedArgs: TJSONArray;
  I: Integer;
begin
  if not (ALogic is TJSONObject) then
  begin
    if ALogic = nil then
      Exit(Manage(TJSONNull.Create));
    Exit(Manage(ALogic.Clone as TJSONValue));
  end;

  LObj := TJSONObject(ALogic);
  if LObj.Count <> 1 then
    Exit(Manage(ALogic.Clone as TJSONValue));

  LPair := LObj.Pairs[0];
  LOpName := LPair.JsonString.Value;

  LArgsOwned := False;
  if LPair.JsonValue is TJSONArray then
    LArgs := TJSONArray(LPair.JsonValue)
  else
  begin
    LArgs := TJSONArray.Create;
    LArgsOwned := True;
    LArgs.AddElement(LPair.JsonValue.Clone as TJSONValue);
  end;

  try
    if not FOperators.TryGetValue(LOpName, LHandler) then
      raise EJsonLogicError.CreateFmt('Unknown operator: %s', [LOpName]);

    if (LOpName = 'var') or (LOpName = 'if') or (LOpName = 'and') or
       (LOpName = 'or') or (LOpName = 'missing') then
      Result := LHandler(LArgs, AData)
    else
    begin
      LEvaluatedArgs := TJSONArray.Create;
      try
        for I := 0 to LArgs.Count - 1 do
          LEvaluatedArgs.AddElement(Apply(LArgs.Items[I], AData).Clone as TJSONValue);
        Result := LHandler(LEvaluatedArgs, AData);
      finally
        LEvaluatedArgs.Free;
      end;
    end;
  finally
    if LArgsOwned then
      LArgs.Free;
  end;
end;

function TJsonLogicEngine.ApplyBool(ALogic: TJSONValue;
  AData: TJSONObject): Boolean;
begin
  ClearManaged;  // P1：每次顶层调用前清理上一次的临时对象
  Result := IsTrue(Apply(ALogic, AData));
end;

function TJsonLogicEngine.ApplyStr(const ALogicJson: string;
  AData: TJSONObject): Boolean;
var
  LLogic: TJSONValue;
begin
  ClearManaged;  // P1：清理
  LLogic := TJSONObject.ParseJSONValue(ALogicJson);
  if LLogic = nil then
    raise EJsonLogicError.Create('Invalid JSON logic expression');
  Manage(LLogic);  // P1：解析出的 JSON 也纳入管理
  Result := IsTrue(Apply(LLogic, AData));
end;

// --- 操作符实现 ---

function TJsonLogicEngine.OpVar(AArgs: TJSONArray;
  AData: TJSONObject): TJSONValue;
var
  LPath: string;
  LDefault: TJSONValue;
  LResult: TJSONValue;
begin
  if AArgs.Count = 0 then
  begin
    if AData = nil then
      Exit(Manage(TJSONNull.Create));
    Exit(Manage(AData.Clone as TJSONValue));
  end;

  LPath := ToString(AArgs.Items[0]);
  LResult := ResolveVar(LPath, AData);

  if (LResult is TJSONNull) and (AArgs.Count > 1) then
  begin
    LDefault := AArgs.Items[1];
    Exit(Manage(LDefault.Clone as TJSONValue));
  end;

  if LResult = nil then
    Result := Manage(TJSONNull.Create)
  else
    Result := Manage(LResult.Clone as TJSONValue);
end;

function TJsonLogicEngine.OpEqual(AArgs: TJSONArray;
  AData: TJSONObject): TJSONValue;
begin
  if AArgs.Count < 2 then Exit(Manage(TJSONBool.Create(False)));
  Result := Manage(TJSONBool.Create(
    ToString(AArgs.Items[0]) = ToString(AArgs.Items[1])));
end;

function TJsonLogicEngine.OpStrictEqual(AArgs: TJSONArray;
  AData: TJSONObject): TJSONValue;
begin
  if AArgs.Count < 2 then Exit(Manage(TJSONBool.Create(False)));
  Result := Manage(TJSONBool.Create(
    (AArgs.Items[0].ClassName = AArgs.Items[1].ClassName) and
    (AArgs.Items[0].ToJSON = AArgs.Items[1].ToJSON)));
end;

function TJsonLogicEngine.OpNotEqual(AArgs: TJSONArray;
  AData: TJSONObject): TJSONValue;
begin
  if AArgs.Count < 2 then Exit(Manage(TJSONBool.Create(True)));
  Result := Manage(TJSONBool.Create(
    ToString(AArgs.Items[0]) <> ToString(AArgs.Items[1])));
end;

function TJsonLogicEngine.OpGreaterThan(AArgs: TJSONArray;
  AData: TJSONObject): TJSONValue;
begin
  if AArgs.Count < 2 then Exit(Manage(TJSONBool.Create(False)));
  Result := Manage(TJSONBool.Create(
    ToNumber(AArgs.Items[0]) > ToNumber(AArgs.Items[1])));
end;

function TJsonLogicEngine.OpGreaterEqual(AArgs: TJSONArray;
  AData: TJSONObject): TJSONValue;
begin
  if AArgs.Count < 2 then Exit(Manage(TJSONBool.Create(False)));
  Result := Manage(TJSONBool.Create(
    ToNumber(AArgs.Items[0]) >= ToNumber(AArgs.Items[1])));
end;

function TJsonLogicEngine.OpLessThan(AArgs: TJSONArray;
  AData: TJSONObject): TJSONValue;
begin
  if AArgs.Count < 2 then Exit(Manage(TJSONBool.Create(False)));
  Result := Manage(TJSONBool.Create(
    ToNumber(AArgs.Items[0]) < ToNumber(AArgs.Items[1])));
end;

function TJsonLogicEngine.OpLessEqual(AArgs: TJSONArray;
  AData: TJSONObject): TJSONValue;
begin
  if AArgs.Count < 2 then Exit(Manage(TJSONBool.Create(False)));
  Result := Manage(TJSONBool.Create(
    ToNumber(AArgs.Items[0]) <= ToNumber(AArgs.Items[1])));
end;

function TJsonLogicEngine.OpAnd(AArgs: TJSONArray;
  AData: TJSONObject): TJSONValue;
var
  I: Integer;
  LVal: TJSONValue;
begin
  Result := Manage(TJSONBool.Create(True));
  for I := 0 to AArgs.Count - 1 do
  begin
    LVal := Apply(AArgs.Items[I], AData);
    if not IsTrue(LVal) then
      Exit(LVal);
  end;
end;

function TJsonLogicEngine.OpOr(AArgs: TJSONArray;
  AData: TJSONObject): TJSONValue;
var
  I: Integer;
  LVal: TJSONValue;
begin
  Result := Manage(TJSONBool.Create(False));
  for I := 0 to AArgs.Count - 1 do
  begin
    LVal := Apply(AArgs.Items[I], AData);
    if IsTrue(LVal) then
      Exit(LVal);
  end;
end;

function TJsonLogicEngine.OpNot(AArgs: TJSONArray;
  AData: TJSONObject): TJSONValue;
begin
  if AArgs.Count = 0 then Exit(Manage(TJSONBool.Create(True)));
  Result := Manage(TJSONBool.Create(not IsTrue(AArgs.Items[0])));
end;

function TJsonLogicEngine.OpIf(AArgs: TJSONArray;
  AData: TJSONObject): TJSONValue;
var
  I: Integer;
begin
  I := 0;
  while I < AArgs.Count do
  begin
    if I = AArgs.Count - 1 then
      Exit(Apply(AArgs.Items[I], AData));
    if IsTrue(Apply(AArgs.Items[I], AData)) then
      Exit(Apply(AArgs.Items[I + 1], AData));
    Inc(I, 2);
  end;
  Result := Manage(TJSONNull.Create);
end;

function TJsonLogicEngine.OpIn(AArgs: TJSONArray;
  AData: TJSONObject): TJSONValue;
var
  LNeedle: string;
  LHaystack: TJSONValue;
  I: Integer;
begin
  if AArgs.Count < 2 then Exit(Manage(TJSONBool.Create(False)));

  LNeedle := ToString(AArgs.Items[0]);
  LHaystack := AArgs.Items[1];

  if LHaystack is TJSONArray then
  begin
    for I := 0 to TJSONArray(LHaystack).Count - 1 do
    begin
      if ToString(TJSONArray(LHaystack).Items[I]) = LNeedle then
        Exit(Manage(TJSONBool.Create(True)));
    end;
    Exit(Manage(TJSONBool.Create(False)));
  end;

  if LHaystack is TJSONString then
    Exit(Manage(TJSONBool.Create(ContainsStr(TJSONString(LHaystack).Value, LNeedle))));

  Result := Manage(TJSONBool.Create(False));
end;

function TJsonLogicEngine.OpCat(AArgs: TJSONArray;
  AData: TJSONObject): TJSONValue;
var
  I: Integer;
  LResult: string;
begin
  LResult := '';
  for I := 0 to AArgs.Count - 1 do
    LResult := LResult + ToString(AArgs.Items[I]);
  Result := Manage(TJSONString.Create(LResult));
end;

function TJsonLogicEngine.OpSubstr(AArgs: TJSONArray;
  AData: TJSONObject): TJSONValue;
var
  LStr: string;
  LStart, LLen: Integer;
begin
  if AArgs.Count < 2 then Exit(Manage(TJSONString.Create('')));
  LStr := ToString(AArgs.Items[0]);
  LStart := Trunc(ToNumber(AArgs.Items[1]));

  if LStart < 0 then
    LStart := Length(LStr) + LStart;

  if AArgs.Count > 2 then
  begin
    LLen := Trunc(ToNumber(AArgs.Items[2]));
    Result := Manage(TJSONString.Create(Copy(LStr, LStart + 1, LLen)));
  end
  else
    Result := Manage(TJSONString.Create(Copy(LStr, LStart + 1, MaxInt)));
end;

function TJsonLogicEngine.OpPlus(AArgs: TJSONArray;
  AData: TJSONObject): TJSONValue;
var
  I: Integer;
  LSum: Double;
begin
  LSum := 0;
  for I := 0 to AArgs.Count - 1 do
    LSum := LSum + ToNumber(AArgs.Items[I]);
  Result := Manage(TJSONNumber.Create(LSum));
end;

function TJsonLogicEngine.OpMinus(AArgs: TJSONArray;
  AData: TJSONObject): TJSONValue;
begin
  if AArgs.Count = 1 then
    Exit(Manage(TJSONNumber.Create(-ToNumber(AArgs.Items[0]))));
  if AArgs.Count < 2 then
    Exit(Manage(TJSONNumber.Create(0)));
  Result := Manage(TJSONNumber.Create(
    ToNumber(AArgs.Items[0]) - ToNumber(AArgs.Items[1])));
end;

function TJsonLogicEngine.OpMultiply(AArgs: TJSONArray;
  AData: TJSONObject): TJSONValue;
var
  I: Integer;
  LProduct: Double;
begin
  LProduct := 1;
  for I := 0 to AArgs.Count - 1 do
    LProduct := LProduct * ToNumber(AArgs.Items[I]);
  Result := Manage(TJSONNumber.Create(LProduct));
end;

function TJsonLogicEngine.OpDivide(AArgs: TJSONArray;
  AData: TJSONObject): TJSONValue;
var
  LDivisor: Double;
begin
  if AArgs.Count < 2 then Exit(Manage(TJSONNumber.Create(0)));
  LDivisor := ToNumber(AArgs.Items[1]);
  if LDivisor = 0 then
    Exit(Manage(TJSONNull.Create));
  Result := Manage(TJSONNumber.Create(ToNumber(AArgs.Items[0]) / LDivisor));
end;

function TJsonLogicEngine.OpMissing(AArgs: TJSONArray;
  AData: TJSONObject): TJSONValue;
var
  I: Integer;
  LPath: string;
  LMissing: TJSONArray;
begin
  LMissing := TJSONArray.Create;
  Manage(LMissing);
  for I := 0 to AArgs.Count - 1 do
  begin
    LPath := ToString(AArgs.Items[I]);
    if ResolveVar(LPath, AData) is TJSONNull then
      LMissing.Add(LPath);
  end;
  Result := LMissing;
end;

end.
