{ ============================================================================
  Test.DeepBase.Speech.ASR.SenseVoice - Unit Tests
  
  Test Coverage:
    - ParseCommaList (T4 regression: managed TArray<string> copy safety,
      WO-20260919-AUDIT-乙-R2 E7)
  ============================================================================ }

unit Test.DeepBase.Speech.ASR.SenseVoice;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  DeepBase.Speech.ASR.SenseVoice;

type
  [TestFixture]
  TTestParseCommaList = class
  public
    [Test]
    procedure Test_EmptyText_ReturnsEmpty;
    [Test]
    procedure Test_SingleToken_NoComma;
    [Test]
    procedure Test_ThreeTokens;
    [Test]
    procedure Test_EmptySegments_Preserved;
    [Test]
    procedure Test_ChineseTokens;
    [Test]
    procedure Test_LargeList_ManagedCopySafe;
  end;

implementation

procedure TTestParseCommaList.Test_EmptyText_ReturnsEmpty;
begin
  Assert.AreEqual(0, Integer(Length(ParseCommaList(''))));
end;

procedure TTestParseCommaList.Test_SingleToken_NoComma;
var
  L: TArray<string>;
begin
  L := ParseCommaList('hello');
  Assert.AreEqual(1, Integer(Length(L)));
  Assert.AreEqual('hello', L[0]);
end;

procedure TTestParseCommaList.Test_ThreeTokens;
var
  L: TArray<string>;
begin
  L := ParseCommaList('a,bb,ccc');
  Assert.AreEqual(3, Integer(Length(L)));
  Assert.AreEqual('a', L[0]);
  Assert.AreEqual('bb', L[1]);
  Assert.AreEqual('ccc', L[2]);
end;

procedure TTestParseCommaList.Test_EmptySegments_Preserved;
var
  L: TArray<string>;
begin
  L := ParseCommaList('a,,b');
  Assert.AreEqual(3, Integer(Length(L)));
  Assert.AreEqual('a', L[0]);
  Assert.AreEqual('', L[1]);
  Assert.AreEqual('b', L[2]);
end;

procedure TTestParseCommaList.Test_ChineseTokens;
var
  L: TArray<string>;
begin
  L := ParseCommaList('你好,世界, DeepBase');
  Assert.AreEqual(3, Integer(Length(L)));
  Assert.AreEqual('你好', L[0]);
  Assert.AreEqual('世界', L[1]);
  // 段保留分隔符后原样（含前导空格），与 tokens.csv 逐段语义一致
  Assert.AreEqual(' DeepBase', L[2]);
end;

procedure TTestParseCommaList.Test_LargeList_ManagedCopySafe;
const
  N = 500;
var
  LParts: TArray<string>;
  LText, LExpect: string;
  L: TArray<string>;
  I: Integer;
begin
  SetLength(LParts, N);
  for I := 0 to N - 1 do
    LParts[I] := 'tok' + I.ToString + '-' + StringOfChar('x', 40);
  LText := string.Join(',', LParts);
  L := ParseCommaList(LText);
  Assert.AreEqual(N, Integer(Length(L)));
  LExpect := 'tok499-' + StringOfChar('x', 40);
  Assert.AreEqual(LExpect, L[N - 1]);
  Assert.AreEqual('tok0-' + StringOfChar('x', 40), L[0]);
  // 回归点：历史上此处为按 SizeOf(string) 的裸内存批量拷贝（审计 T4.2），
  // 托管数组拷贝须走引用计数；函数退出释放 LList/L/LParts 时若曾裸 Move
  // 则 double-free，进程在此崩溃而非断言失败——能跑完即证明拷贝正确。
end;

initialization
  TDUnitX.RegisterTestFixture(TTestParseCommaList);

end.
