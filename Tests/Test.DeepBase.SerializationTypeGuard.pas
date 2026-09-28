unit Test.DeepBase.SerializationTypeGuard;

{ ============================================================================
  A5-R04：JSON 反序列化值类型校验 + 类型白名单精确匹配

  判据来源：CodeReview/20260925-AUDIT-甲-A4-证据/A403_Serialization-run.log
  的错型输入（探针改制为单测）。修复前的表现分三类，全部是缺陷：
    · AV —— 走 TJSONNumber(AJson)/as TJSONBool 硬转
    · RTL 异常消息里带原始堆字节 —— 走 TJSONObject/TJSONArray 硬转
    · 静默落默认值 —— null 与未覆盖形态直接置 Empty
  修复后一律抛 ESerializationTypeMismatchException，消息带属性路径与期望/实际形态。
  ============================================================================ }

{$M+}

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DeepBase.Serialization;

type
  { 嵌套探针：错型字段位于对象内部，用来验证异常路径是点号串起来的完整属性路径 }
  [Serializable]
  TA5R04Address = class
  private
    FCity: string;
  published
    property City: string read FCity write FCity;
  end;

  [Serializable]
  TA5R04Order = class
  private
    FAge: Integer;
    FName: string;
    FPrice: Double;
    FFlag: Boolean;
    FWhen: TDateTime;
    FAddress: TA5R04Address;
  public
    constructor Create;
    destructor Destroy; override;
  published
    property Age: Integer read FAge write FAge;
    property Name: string read FName write FName;
    property Price: Double read FPrice write FPrice;
    property Flag: Boolean read FFlag write FFlag;
    property When: TDateTime read FWhen write FWhen;
    property Address: TA5R04Address read FAddress write FAddress;
  end;

  { 类名以白名单项 'TObject' 开头，但本身既不是白名单项也未标 [Serializable]。
    修复前 StartsWith 前缀臂让它通过白名单（A4-03 WL-01）。 }
  TObjectLookalikeOrder = class
  private
    FAge: Integer;
  published
    property Age: Integer read FAge write FAge;
  end;

  { 反序列化结果快照：Delphi 在 except 块结束时销毁异常实例，异常对象带不出块外，
    所以判据要用的类名/消息/路径必须在捕获现场取成值。 }
  TA5R04Outcome = record
    Raised: Boolean;
    RaisedTypeMismatch: Boolean;
    ErrorClass: string;
    ErrorMessage: string;
    MismatchPath: string;
    MismatchExpected: string;
    MismatchActual: string;
  end;

  [TestFixture]
  TA5R04JsonTypeGuardTests = class
  private
    function CaptureFromJson(const AJson: string; ATarget: TClass): TA5R04Outcome;
    function HasNonPrintable(const S: string): Boolean;
  public
    [Test]
    [TestCase('Age=string', '{"Age":"not-a-number"}')]
    [TestCase('Age=bool', '{"Age":true}')]
    [TestCase('Age=object', '{"Age":{"x":1}}')]
    [TestCase('Age=array', '{"Age":[1]}')]
    [TestCase('Age=null', '{"Age":null}')]
    [TestCase('Name=int', '{"Name":123}')]
    [TestCase('Name=bool', '{"Name":true}')]
    [TestCase('Name=object', '{"Name":{"x":1}}')]
    [TestCase('Name=null', '{"Name":null}')]
    [TestCase('Price=string', '{"Price":"abc"}')]
    [TestCase('Price=bool', '{"Price":true}')]
    [TestCase('Price=null', '{"Price":null}')]
    [TestCase('Flag=int', '{"Flag":1}')]
    [TestCase('Flag=string', '{"Flag":"yes"}')]
    [TestCase('Flag=null', '{"Flag":null}')]
    procedure MistypedScalar_RaisesTypeMismatch(const AJson: string);

    [Test]
    procedure TypeMismatchMessage_CarriesPathAndExpectedKind;

    [Test]
    procedure MistypedScalar_NeverLeaksHeapBytesIntoMessage;

    [Test]
    procedure NestedScalarMismatch_MessageCarriesDottedPath;

    [Test]
    procedure NullForClassProperty_IsStillLegalNoValue;

    [Test]
    procedure WellFormedInput_StillDeserializes;

    [Test]
    procedure DateTimeAsString_StillAccepted;

    [Test]
    procedure Whitelist_RejectsPrefixLookalikeClassName;

    [Test]
    procedure Whitelist_StillAcceptsSerializableClass;
  end;

implementation

constructor TA5R04Order.Create;
begin
  inherited Create;
  FAddress := TA5R04Address.Create;
end;

destructor TA5R04Order.Destroy;
begin
  FAddress.Free;
  inherited;
end;

{ TA5R04JsonTypeGuardTests }

function TA5R04JsonTypeGuardTests.CaptureFromJson(const AJson: string;
  ATarget: TClass): TA5R04Outcome;
var
  LObj: TObject;
begin
  Result.Raised := False;
  Result.RaisedTypeMismatch := False;
  Result.ErrorClass := '';
  Result.ErrorMessage := '';
  Result.MismatchPath := '';
  Result.MismatchExpected := '';
  Result.MismatchActual := '';
  LObj := nil;
  try
    try
      LObj := TSerializer.FromJson(AJson, ATarget);
    except
      on E: ESerializationTypeMismatchException do
      begin
        Result.Raised := True;
        Result.RaisedTypeMismatch := True;
        Result.ErrorClass := E.ClassName;
        Result.ErrorMessage := E.Message;
        Result.MismatchPath := E.Path;
        Result.MismatchExpected := E.ExpectedKind;
        Result.MismatchActual := E.ActualKind;
      end;
      on E: Exception do
      begin
        Result.Raised := True;
        Result.ErrorClass := E.ClassName;
        Result.ErrorMessage := E.Message;
      end;
    end;
  finally
    LObj.Free;
  end;
end;

function TA5R04JsonTypeGuardTests.HasNonPrintable(const S: string): Boolean;
var
  I: Integer;
begin
  for I := 1 to Length(S) do
    if (S[I] < ' ') and (S[I] <> #13) and (S[I] <> #10) then
      Exit(True);
  Result := False;
end;

procedure TA5R04JsonTypeGuardTests.MistypedScalar_RaisesTypeMismatch(const AJson: string);
var
  LOutcome: TA5R04Outcome;
begin
  LOutcome := CaptureFromJson(AJson, TA5R04Order);
  Assert.IsTrue(LOutcome.Raised, '错类型输入必须报错，不得静默通过: ' + AJson);
  Assert.IsTrue(LOutcome.RaisedTypeMismatch,
    '必须抛类型化异常而非 AV/RTL 转换异常，实际 ' + LOutcome.ErrorClass + ': ' + LOutcome.ErrorMessage);
end;

procedure TA5R04JsonTypeGuardTests.TypeMismatchMessage_CarriesPathAndExpectedKind;
var
  LOutcome: TA5R04Outcome;
begin
  LOutcome := CaptureFromJson('{"Age":"not-a-number"}', TA5R04Order);
  Assert.IsTrue(LOutcome.RaisedTypeMismatch,
    '应抛出 ESerializationTypeMismatchException，实际 ' + LOutcome.ErrorClass);
  Assert.AreEqual('Age', LOutcome.MismatchPath, '异常必须带属性路径');
  Assert.AreEqual('number', LOutcome.MismatchExpected, 'Integer 目标只接受 number');
  Assert.AreEqual('string', LOutcome.MismatchActual, '异常必须带实际形态');
  Assert.IsTrue(LOutcome.ErrorMessage.Contains('Age'), '消息须含属性路径');
  Assert.IsTrue(LOutcome.ErrorMessage.Contains('number'), '消息须含期望形态');
  Assert.IsTrue(LOutcome.ErrorMessage.Contains('string'), '消息须含实际形态');
end;

procedure TA5R04JsonTypeGuardTests.MistypedScalar_NeverLeaksHeapBytesIntoMessage;
const
  { 修复前这两例走 TJSONObject/TJSONArray 硬转，RTL 异常消息里是原始堆内容 }
  LEVIL: array[0..1] of string = ('{"Age":{"x":1}}', '{"Age":[1]}');
var
  I: Integer;
  LOutcome: TA5R04Outcome;
begin
  for I := Low(LEVIL) to High(LEVIL) do
  begin
    LOutcome := CaptureFromJson(LEVIL[I], TA5R04Order);
    Assert.IsTrue(LOutcome.Raised, '错型输入必须报错: ' + LEVIL[I]);
    Assert.IsFalse(HasNonPrintable(LOutcome.ErrorMessage),
      '异常消息不得含堆字节: ' + LEVIL[I] + ' -> ' + LOutcome.ErrorMessage);
    Assert.IsTrue(LOutcome.ErrorMessage.Length < 256,
      '异常消息必须有界（堆内容外泄的直接特征）: ' + LEVIL[I]);
  end;
end;

procedure TA5R04JsonTypeGuardTests.NestedScalarMismatch_MessageCarriesDottedPath;
var
  LOutcome: TA5R04Outcome;
begin
  LOutcome := CaptureFromJson('{"Address":{"City":7}}', TA5R04Order);
  Assert.IsTrue(LOutcome.RaisedTypeMismatch,
    '嵌套标量错型须抛类型化异常，实际 ' + LOutcome.ErrorClass);
  Assert.AreEqual('Address.City', LOutcome.MismatchPath, '嵌套属性路径要以点号串起来');
end;

procedure TA5R04JsonTypeGuardTests.NullForClassProperty_IsStillLegalNoValue;
var
  LOutcome: TA5R04Outcome;
begin
  LOutcome := CaptureFromJson('{"Age":30,"Address":null}', TA5R04Order);
  Assert.IsFalse(LOutcome.Raised,
    '对象属性的 null 是合法「无值」，不得判为类型不匹配: ' +
    LOutcome.ErrorClass + ': ' + LOutcome.ErrorMessage);
end;

procedure TA5R04JsonTypeGuardTests.WellFormedInput_StillDeserializes;
var
  LObj: TObject;
  LOrder: TA5R04Order;
begin
  LObj := nil;
  try
    LObj := TSerializer.FromJson('{"Age":30,"Name":"bob","Price":1.5,"Flag":true}', TA5R04Order);
    LOrder := TA5R04Order(LObj);
    Assert.AreEqual(30, LOrder.Age);
    Assert.AreEqual('bob', LOrder.Name);
    Assert.AreEqual(1.5, LOrder.Price, 0.0001);
    Assert.IsTrue(LOrder.Flag);
  finally
    LObj.Free;
  end;
end;

procedure TA5R04JsonTypeGuardTests.DateTimeAsString_StillAccepted;
var
  LObj: TObject;
begin
  LObj := nil;
  try
    { TDateTime 序列化端输出固定模板字符串，闸门必须放行 string/number 双形态 }
    LObj := TSerializer.FromJson('{"When":"2026-09-28T10:20:30"}', TA5R04Order);
    Assert.IsTrue(TA5R04Order(LObj).When > 0, '字符串形态的日期仍应被接受');
  finally
    LObj.Free;
  end;
end;

procedure TA5R04JsonTypeGuardTests.Whitelist_RejectsPrefixLookalikeClassName;
var
  LOutcome: TA5R04Outcome;
begin
  LOutcome := CaptureFromJson('{"Age":30}', TObjectLookalikeOrder);
  Assert.IsTrue(LOutcome.Raised, '白名单前缀同名类必须被拒（A4-03 WL-01）');
  Assert.IsTrue(LOutcome.ErrorMessage.Contains('Unauthorized'),
    '拒绝原因要是白名单判定，实际 ' + LOutcome.ErrorClass + ': ' + LOutcome.ErrorMessage);
end;

procedure TA5R04JsonTypeGuardTests.Whitelist_StillAcceptsSerializableClass;
var
  LObj: TObject;
begin
  LObj := nil;
  try
    LObj := TSerializer.FromJson('{"Age":30}', TA5R04Order);
    Assert.IsNotNull(LObj);
  finally
    LObj.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TA5R04JsonTypeGuardTests);

end.
