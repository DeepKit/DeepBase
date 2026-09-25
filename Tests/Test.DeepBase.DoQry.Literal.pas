unit Test.DeepBase.DoQry.Literal;

(********************************************************************************
  Test.DeepBase.DoQry.Literal - B2-13 回归

  被测面：uDoQryLegacy.QuoteValue —— legacy SQL 文本构建器里唯一「不带类型信息」的值出口
  （UPDATE 的 SET、INSERT 的 VALUES、CALL 的实参三处拼接都走它）。
  旧实现先按字符集 {'0'..'9','.','+','-'} 猜「这串是数值」，猜中就原样拼进 SQL 并跳过转义，
  于是 '1--' 这类样本把 `--` 送进代码面，把同一行后面的约束注释掉。

  为什么断言建在「代码面」而不是比对期望字面量：判据要的是「值不再改变 SQL 语义」，
  所以这里自带一把按单引号状态机的解剖器 ProbeSql，把整条语句切成三样东西——
    Balanced  引号是否闭合（值有没有把语句的字面量边界撑破）
    Scaffold  代码面：剥掉所有字面量后数据库真正当语法解析的部分
    Literal   字面量面：按双写口径（'' 表示一个引号）解出来的值本身
  然后断言 Scaffold 恰好等于值前后缀的拼接、Literal 原样等于值、Balanced 为真。
  把「期望的引号形态」抄进用例等于建第二套真源，故不作这类断言。
  方言口径：解剖器取标准 SQL 双写转义；MySQL 的裸反斜杠转义差异不在本单元覆盖内，
  作为同文件族登记项报主控（见 CodeReview/20260925-AUDIT-乙-B2-证据/）。
*******************************************************************************)

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  uDoQryLegacy;

type
  /// <summary>一条 SQL 片段按单引号状态机解剖后的三态。</summary>
  TSqlProbe = record
    Scaffold: string;
    Literal: string;
    Balanced: Boolean;
  end;

  [TestFixture]
  TTestDoQryLiteral = class
  strict private
    const PREFIX = 'col = ';
    /// <summary>SQL 字符串字面量的定界符。</summary>
    const QUOTE = #39;
    const SUFFIX = ' AND deleted = 0';
    class function ProbeSql(const ASql: string): TSqlProbe; static;
    function BuildFragment(const AValue: string): string;
    /// <summary>三态一起断言；返回失败原因（空串=通过），供穷举用例累计反例。</summary>
    function Violation(const AValue: string): string;
  public
    [Test]
    procedure Test_Comment_Prefix_Values_Do_Not_Change_SQL;
    [Test]
    procedure Test_Pure_Numeric_Set_Values_Stay_Inside_Literal;
    [Test]
    procedure Test_Quote_Breaking_Values_Stay_Inside_Literal;
    [Test]
    procedure Test_Null_Sentinels_Keep_Legacy_Contract;
  end;

implementation

class function TTestDoQryLiteral.ProbeSql(const ASql: string): TSqlProbe;
var
  i: Integer;
  inLiteral: Boolean;
begin
  Result.Scaffold := '';
  Result.Literal := '';
  inLiteral := False;
  i := 1;
  while i <= Length(ASql) do
  begin
    if not inLiteral then
    begin
      if ASql[i] = QUOTE then
        inLiteral := True
      else
        Result.Scaffold := Result.Scaffold + ASql[i];
    end
    else if ASql[i] = QUOTE then
    begin
      if (i < Length(ASql)) and (ASql[i + 1] = QUOTE) then
      begin
        Result.Literal := Result.Literal + QUOTE;
        Inc(i);
      end
      else
        inLiteral := False;
    end
    else
      Result.Literal := Result.Literal + ASql[i];
    Inc(i);
  end;
  Result.Balanced := not inLiteral;
end;

function TTestDoQryLiteral.BuildFragment(const AValue: string): string;
begin
  Result := PREFIX + QuoteValue(AValue) + SUFFIX;
end;

function TTestDoQryLiteral.Violation(const AValue: string): string;
var
  Fragment: string;
  P: TSqlProbe;
begin
  Result := '';
  Fragment := BuildFragment(AValue);
  P := ProbeSql(Fragment);
  if not P.Balanced then
    Result := ' quote-unbalanced'
  else if P.Scaffold <> PREFIX + SUFFIX then
    Result := ' leaked-into-code-face[' + P.Scaffold + ']'
  else if P.Literal <> AValue then
    Result := ' literal-face-not-equal-to-value[' + P.Literal + ']';
end;

{ 工单点名样本与同族：只由 0-9 . + - 组成、旧启发式判为「数值」因而原样拼接的串。 }
procedure TTestDoQryLiteral.Test_Comment_Prefix_Values_Do_Not_Change_SQL;
var
  Samples: TArray<string>;
  Value: string;
  Reason: string;
begin
  Samples := TArray<string>.Create(
    '1--', '-1--', '--', '+.', '.', '1.2--', '0-', '+7', '-1', '123');
  for Value in Samples do
  begin
    Reason := Violation(Value);
    Assert.AreEqual('', Reason, 'value [' + Value + '] changed SQL semantics:' + Reason);
  end;
end;

(* 穷举 - + . 0 1 五个字符的 1..4 长度全空间（共 780 个值）：旧启发式的判据正是
  「全属该字符集」，所以这一条一次钉死整个缺陷等价类，不靠挑选样本。 *)
procedure TTestDoQryLiteral.Test_Pure_Numeric_Set_Values_Stay_Inside_Literal;
const
  Alphabet: array[0..4] of Char = ('-', '+', '.', '0', '1');
  SampleCap = 20;
var
  CounterExamples: string;
  BadCount, len: Integer;

  procedure Walk(const APrefix: string; ARemaining: Integer);
  var
    i: Integer;
    Reason: string;
  begin
    if ARemaining > 0 then
    begin
      for i := 0 to High(Alphabet) do
        Walk(APrefix + string(Alphabet[i]), ARemaining - 1);
    end
    else if APrefix <> '' then
    begin
      Reason := Violation(APrefix);
      if Reason <> '' then
      begin
        Inc(BadCount);
        if BadCount <= SampleCap then
          CounterExamples := CounterExamples + ' [' + APrefix + ']' + Reason;
      end;
    end;
  end;

begin
  CounterExamples := '';
  BadCount := 0;
  for len := 1 to 4 do
    Walk('', len);
  Assert.AreEqual(0, BadCount,
    'values that changed SQL semantics (' + IntToStr(BadCount) + ' total, first ' +
    IntToStr(SampleCap) + ' listed):' + CounterExamples);
end;

{ 引号族样本：旧代码本已走转义分支，留在这里是为了在「两套引号器合一」的重构中
  钉住转义口径不被回退（同一文件曾各写一遍引号处理，见 B2-13 证据）。 }
procedure TTestDoQryLiteral.Test_Quote_Breaking_Values_Stay_Inside_Literal;
var
  Samples: TArray<string>;
  Value: string;
  Reason: string;
begin
  Samples := TArray<string>.Create(
    'abc'' OR 1=1 --', '''', '''''', 'a''b''c', 'x''; DROP TABLE t; --',
    'O''Brien', '1'' --');
  for Value in Samples do
  begin
    Reason := Violation(Value);
    Assert.AreEqual('', Reason, 'value [' + Value + '] changed SQL semantics:' + Reason);
  end;
end;

{ 空串与字面量 'NULL' 是 legacy 的置空约定（写入口唯一，该语义本身不在本单改动范围）。 }
procedure TTestDoQryLiteral.Test_Null_Sentinels_Keep_Legacy_Contract;
begin
  Assert.AreEqual('NULL', QuoteValue(''));
  Assert.AreEqual('NULL', QuoteValue('NULL'));
  Assert.AreEqual('''null''', QuoteValue('null'));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDoQryLiteral);

end.
