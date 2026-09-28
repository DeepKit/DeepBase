unit Test.DeepBase.LogQuerySourceLifetime;
{
  WO-20260925-AUDIT-甲-A5 / A5-R06 回归单元。

  被测缺陷：TLogAnalyzer.TopExceptions 原先把「过滤后的子集列表」用
  SetDataSource 换入容器状态、跑完再「自赋值恢复」——换入触发 SetDataSource 的
  自有源释放逻辑（owned 源在查询中途被销毁），恢复时传的是换入后的当前值
  （原始引用永久丢失），finally 释放临时列表后 FDataSource 悬垂（借用源场景直接
  AV）。修复改为把子集作为参数下传聚合过程，全程不改容器状态。

  判据来源：甲 A4 的 A4-05 探针（owned / borrowed 两条场景共 4 条断言）。
}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  DUnitX.TestFramework,
  DeepBase.Types,
  DeepBase.LogAggregator,
  DeepBase.LogQuery;

type

  { 计数析构次数，用于断言「分析器在查询中途销毁了自己的数据源」 }
  TTrackedLogList = class(TList<TAggregatedLog>)
  public
    DestroyCount: Integer;
    constructor Create;
    destructor Destroy; override;
  end;

  [TestFixture]
  TLogQuerySourceLifetime = class
  private
    function MkLog(const AMsg: string; ALevel: TLogLevel;
      const AStack: string): TAggregatedLog;
    procedure FillMixedSource(ASource: TList<TAggregatedLog>);
  public
    [Test]
    procedure OwnedSource_IsNotFreedDuringTopExceptions;

    [Test]
    procedure OwnedSource_StaysQueryableAfterTopExceptions;

    [Test]
    procedure OwnedSource_IsFreedExactlyOnceByAnalyzerDestroy;

    [Test]
    procedure BorrowedSource_KeepsOriginalOwnershipAfterTopExceptions;

    [Test]
    procedure BorrowedSource_StaysLinkedAfterTopExceptions;

    [Test]
    procedure TopExceptions_AggregatesOnlyStackBearingErrors;

    [Test]
    procedure TopErrors_IsNotAffectedByTopExceptionsCall;

    [Test]
    procedure RepeatedTopExceptions_KeepsStateIntact;

    [Test]
    procedure EmptyAnalyzer_ReturnsEmptyWithoutRaising;
  end;

implementation

uses
  System.DateUtils;

{ TTrackedLogList }

constructor TTrackedLogList.Create;
begin
  inherited Create;
  DestroyCount := 0;
end;

destructor TTrackedLogList.Destroy;
begin
  Inc(DestroyCount);
  inherited;
end;

{ TLogQuerySourceLifetime }

function TLogQuerySourceLifetime.MkLog(const AMsg: string; ALevel: TLogLevel;
  const AStack: string): TAggregatedLog;
begin
  Result := Default(TAggregatedLog);
  Result.Timestamp := Now;
  Result.Level := ALevel;
  Result.Message := AMsg;
  Result.Source := 'test';
  Result.StackTrace := AStack;
end;

{ 4 条 = 2 条带堆栈的错误 + 1 条不带堆栈的错误 + 1 条不带堆栈的信息，
  与 A4-05 探针的样本形状一致：TopExceptions 只应聚合前两类中的堆栈行。 }
procedure TLogQuerySourceLifetime.FillMixedSource(ASource: TList<TAggregatedLog>);
begin
  ASource.Add(MkLog('plain-1', llInfo, ''));
  ASource.Add(MkLog('plain-2', llInfo, ''));
  ASource.Add(MkLog('ERR-alpha', llError, 'stack-alpha'));
  ASource.Add(MkLog('ERR-beta', llError, 'stack-beta'));
end;

procedure TLogQuerySourceLifetime.OwnedSource_IsNotFreedDuringTopExceptions;
var
  Src: TTrackedLogList;
  Analyzer: TLogAnalyzer;
begin
  Src := TTrackedLogList.Create;
  FillMixedSource(Src);
  Analyzer := TLogAnalyzer.Create;
  try
    Analyzer.SetDataSource(Src, True);
    Analyzer.TopExceptions(5);
    Assert.AreEqual(0, Src.DestroyCount,
      'TopExceptions must not free the data source it does not need to own');
  finally
    // 所有权随 SetDataSource(..., True) 移交，Src 只能由分析器释放，测试不得再 Free
    Analyzer.Free;
  end;
end;

procedure TLogQuerySourceLifetime.OwnedSource_StaysQueryableAfterTopExceptions;
var
  Src: TTrackedLogList;
  Analyzer: TLogAnalyzer;
  Stats: TLogStats;
begin
  Src := TTrackedLogList.Create;
  FillMixedSource(Src);
  Analyzer := TLogAnalyzer.Create;
  try
    Analyzer.SetDataSource(Src, True);
    Analyzer.TopExceptions(5);
    Stats := Analyzer.GetStats;
    Assert.AreEqual<Int64>(4, Stats.TotalCount,
      'the analyzer must still point at the original source after TopExceptions');
  finally
    // 所有权已移交：Src 由分析器释放，测试再 Free 就是双释
    Analyzer.Free;
  end;
end;

procedure TLogQuerySourceLifetime.OwnedSource_IsFreedExactlyOnceByAnalyzerDestroy;
var
  Src: TTrackedLogList;
  Analyzer: TLogAnalyzer;
begin
  Src := TTrackedLogList.Create;
  FillMixedSource(Src);
  Analyzer := TLogAnalyzer.Create;
  Analyzer.SetDataSource(Src, True);
  Analyzer.TopExceptions(5);
  Assert.AreEqual(0, Src.DestroyCount,
    'TopExceptions must not destroy the owned source mid-query');
  Analyzer.Free;
  Assert.AreEqual(1, Src.DestroyCount,
    'an owning analyzer must destroy the source exactly once, at its own teardown');
  // 所有权在 SetDataSource(..., True) 时已经移交，Src 由分析器释放，此处不得再 Free
end;

procedure TLogQuerySourceLifetime.BorrowedSource_KeepsOriginalOwnershipAfterTopExceptions;
var
  Src: TList<TAggregatedLog>;
  Analyzer: TLogAnalyzer;
begin
  Src := TList<TAggregatedLog>.Create;
  FillMixedSource(Src);
  Analyzer := TLogAnalyzer.Create;
  try
    Analyzer.SetDataSource(Src, False);
    Analyzer.TopExceptions(5);
    Assert.AreEqual<Int64>(4, Analyzer.GetStats.TotalCount,
      'a borrowed source must survive the exception analysis untouched');
  finally
    Analyzer.Free;
    // 借用语义：调用方仍然是源的主人，此处释放必须是一次真正的释放而非双释
    Src.Free;
  end;
end;

procedure TLogQuerySourceLifetime.BorrowedSource_StaysLinkedAfterTopExceptions;
var
  Src: TList<TAggregatedLog>;
  Analyzer: TLogAnalyzer;
begin
  Src := TList<TAggregatedLog>.Create;
  FillMixedSource(Src);
  Analyzer := TLogAnalyzer.Create;
  try
    Analyzer.SetDataSource(Src, False);
    Analyzer.TopExceptions(5);
    Src.Add(MkLog('POST-QUERY-ADD', llWarn, ''));
    Assert.AreEqual<Int64>(5, Analyzer.GetStats.TotalCount,
      'the analyzer must stay bound to the live source, not to a freed alias');
  finally
    Analyzer.Free;
    Src.Free;
  end;
end;

procedure TLogQuerySourceLifetime.TopExceptions_AggregatesOnlyStackBearingErrors;
var
  Src: TList<TAggregatedLog>;
  Analyzer: TLogAnalyzer;
  Top: TArray<TTopError>;
  Found: Integer;
  Err: TTopError;
begin
  Src := TList<TAggregatedLog>.Create;
  Src.Add(MkLog('ERR-alpha', llError, 'stack-alpha'));
  Src.Add(MkLog('ERR-alpha', llError, 'stack-alpha'));
  Src.Add(MkLog('ERR-nostack', llError, ''));
  Src.Add(MkLog('PLAIN', llInfo, 'stack-but-not-an-error'));
  Analyzer := TLogAnalyzer.Create;
  try
    Analyzer.SetDataSource(Src, False);
    Top := Analyzer.TopExceptions(10);
    Assert.AreEqual<Integer>(1, Length(Top),
      'only error-level rows carrying a stack trace belong in TopExceptions');
    if Length(Top) > 0 then
    begin
      Err := Top[0];
      Assert.AreEqual('ERR-alpha', Err.Message);
      Assert.AreEqual<Int64>(2, Err.Count);
    end;
    // 同一批数据走 TopErrors 仍是全量错误聚合，两条路径互不污染
    Top := Analyzer.TopErrors(10);
    Found := 0;
    for Err in Top do
      Inc(Found, Err.Count);
    Assert.AreEqual(3, Found,
      'TopErrors must still aggregate every error-level row of the source');
  finally
    Analyzer.Free;
    Src.Free;
  end;
end;

procedure TLogQuerySourceLifetime.TopErrors_IsNotAffectedByTopExceptionsCall;
var
  Src: TList<TAggregatedLog>;
  Analyzer: TLogAnalyzer;
  Before: TArray<TTopError>;
  After: TArray<TTopError>;
begin
  Src := TList<TAggregatedLog>.Create;
  FillMixedSource(Src);
  Analyzer := TLogAnalyzer.Create;
  try
    Analyzer.SetDataSource(Src, False);
    Before := Analyzer.TopErrors(10);
    Analyzer.TopExceptions(10);
    After := Analyzer.TopErrors(10);
    Assert.AreEqual<Integer>(Length(Before), Length(After),
      'TopExceptions must not change what TopErrors sees');
  finally
    Analyzer.Free;
    Src.Free;
  end;
end;

procedure TLogQuerySourceLifetime.RepeatedTopExceptions_KeepsStateIntact;
var
  Src: TTrackedLogList;
  Analyzer: TLogAnalyzer;
  First: TArray<TTopError>;
  Second: TArray<TTopError>;
begin
  Src := TTrackedLogList.Create;
  FillMixedSource(Src);
  Analyzer := TLogAnalyzer.Create;
  try
    Analyzer.SetDataSource(Src, True);
    First := Analyzer.TopExceptions(5);
    Second := Analyzer.TopExceptions(5);
    Assert.AreEqual<Integer>(Length(First), Length(Second),
      'the second call must return the same rows as the first');
    Assert.AreEqual(0, Src.DestroyCount,
      'no call may destroy the source it was given');
    Assert.AreEqual<Int64>(4, Analyzer.GetStats.TotalCount);
  finally
    // 所有权已移交：Src 由分析器释放
    Analyzer.Free;
  end;
end;

procedure TLogQuerySourceLifetime.EmptyAnalyzer_ReturnsEmptyWithoutRaising;
var
  Analyzer: TLogAnalyzer;
begin
  Analyzer := TLogAnalyzer.Create;
  try
    Assert.AreEqual<Integer>(0, Length(Analyzer.TopErrors(5)),
      'an analyzer without a data source returns an empty result');
    Assert.AreEqual<Integer>(0, Length(Analyzer.TopExceptions(5)),
      'an analyzer without a data source returns an empty result');
  finally
    Analyzer.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TLogQuerySourceLifetime);

end.
