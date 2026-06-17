unit Test.DeepBase.CLI.Pipeline;

{*******************************************************************************
  Unit Tests for DeepBase.CLI.Pipeline
  Tests pipeline data, parser, filters and execution
*******************************************************************************}

interface

{$IFDEF TESTDeepInsight}
uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestCLIPipeline = class
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // TPipelineData Tests
    [Test]
    procedure TestPipelineDataCreate;
    [Test]
    procedure TestPipelineDataAddLine;
    [Test]
    procedure TestPipelineDataSetLines;
    [Test]
    procedure TestPipelineDataSetRaw;
    [Test]
    procedure TestPipelineDataClear;
    [Test]
    procedure TestPipelineDataAsString;
    [Test]
    procedure TestPipelineDataLineCount;
    [Test]
    procedure TestPipelineDataGetLine;
    [Test]
    procedure TestPipelineDataGetLineOutOfRange;

    // TPipelineParser Tests
    [Test]
    procedure TestParserIsPipelineSimple;
    [Test]
    procedure TestParserIsPipelineWithQuotes;
    [Test]
    procedure TestParserIsPipelineNoOperator;
    [Test]
    procedure TestParserSplitByPipe;
    [Test]
    procedure TestParserSplitByPipeWithQuotes;
    [Test]
    procedure TestParserParseSimpleCommand;
    [Test]
    procedure TestParserParseFilter;
    [Test]
    procedure TestParserParseRedirect;
    [Test]
    procedure TestParserParseAppendRedirect;
    [Test]
    procedure TestParserParseTee;
    [Test]
    procedure TestParserParseFilterWithOptions;

    // TPipelineFilters.Grep Tests
    [Test]
    procedure TestGrepBasic;
    [Test]
    procedure TestGrepIgnoreCase;
    [Test]
    procedure TestGrepInvert;
    [Test]
    procedure TestGrepNoMatch;
    [Test]
    procedure TestGrepRegex;

    // TPipelineFilters.Sort Tests
    [Test]
    procedure TestSortBasic;
    [Test]
    procedure TestSortReverse;
    [Test]
    procedure TestSortNumeric;
    [Test]
    procedure TestSortUnique;

    // TPipelineFilters.Head Tests
    [Test]
    procedure TestHeadDefault;
    [Test]
    procedure TestHeadWithCount;
    [Test]
    procedure TestHeadLessThanCount;

    // TPipelineFilters.Tail Tests
    [Test]
    procedure TestTailDefault;
    [Test]
    procedure TestTailWithCount;
    [Test]
    procedure TestTailLessThanCount;

    // TPipelineFilters.Uniq Tests
    [Test]
    procedure TestUniqBasic;
    [Test]
    procedure TestUniqWithCount;
    [Test]
    procedure TestUniqIgnoreCase;

    // TPipelineFilters.Wc Tests
    [Test]
    procedure TestWcAll;
    [Test]
    procedure TestWcLinesOnly;
    [Test]
    procedure TestWcWordsOnly;

    // TPipelineFilters.Rev Tests
    [Test]
    procedure TestRevBasic;
    [Test]
    procedure TestRevEmpty;

    // TPipelineFilters.Cut Tests
    [Test]
    procedure TestCutSingleField;
    [Test]
    procedure TestCutMultipleFields;
    [Test]
    procedure TestCutFieldRange;
    [Test]
    procedure TestCutCustomDelimiter;

    // TPipelineFilters.Tr Tests
    [Test]
    procedure TestTrBasic;
    [Test]
    procedure TestTrMultipleChars;

    // TPipeline Tests
    [Test]
    procedure TestPipelineCreate;
    [Test]
    procedure TestPipelineSetStdinString;
    [Test]
    procedure TestPipelineSetStdinLines;
    [Test]
    procedure TestPipelineRegisterFilter;
    [Test]
    procedure TestPipelineExecuteFilter;
    [Test]
    procedure TestPipelineExecuteChain;
  end;
{$ENDIF}

implementation

{$IFDEF TESTDeepInsight}
uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  DeepBase.CLI.Pipeline;

procedure TTestCLIPipeline.Setup;
begin
end;

procedure TTestCLIPipeline.TearDown;
begin
end;

// ============================================================================
// TPipelineData Tests
// ============================================================================

procedure TTestCLIPipeline.TestPipelineDataCreate;
var
  Data: TPipelineData;
begin
  Data := TPipelineData.Create;
  try
    Assert.AreEqual(0, Data.LineCount);
    Assert.AreEqual('', Data.RawData);
    Assert.IsFalse(Data.IsStructured);
  finally
    Data.Free;
  end;
end;

procedure TTestCLIPipeline.TestPipelineDataAddLine;
var
  Data: TPipelineData;
begin
  Data := TPipelineData.Create;
  try
    Data.AddLine('Line 1');
    Data.AddLine('Line 2');
    Data.AddLine('Line 3');
    Assert.AreEqual(3, Data.LineCount);
    Assert.AreEqual('Line 1', Data.GetLine(0));
    Assert.AreEqual('Line 2', Data.GetLine(1));
    Assert.AreEqual('Line 3', Data.GetLine(2));
  finally
    Data.Free;
  end;
end;

procedure TTestCLIPipeline.TestPipelineDataSetLines;
var
  Data: TPipelineData;
  Lines: TArray<string>;
begin
  Data := TPipelineData.Create;
  try
    Lines := ['Alpha', 'Beta', 'Gamma'];
    Data.SetLines(Lines);
    Assert.AreEqual(3, Data.LineCount);
    Assert.AreEqual('Alpha', Data.GetLine(0));
    Assert.AreEqual('Gamma', Data.GetLine(2));
  finally
    Data.Free;
  end;
end;

procedure TTestCLIPipeline.TestPipelineDataSetRaw;
var
  Data: TPipelineData;
begin
  Data := TPipelineData.Create;
  try
    Data.SetRaw('Line1' + sLineBreak + 'Line2' + sLineBreak + 'Line3');
    Assert.AreEqual(3, Data.LineCount);
    Assert.AreEqual('Line1', Data.GetLine(0));
    Assert.AreEqual('Line3', Data.GetLine(2));
  finally
    Data.Free;
  end;
end;

procedure TTestCLIPipeline.TestPipelineDataClear;
var
  Data: TPipelineData;
begin
  Data := TPipelineData.Create;
  try
    Data.AddLine('Line 1');
    Data.AddLine('Line 2');
    Assert.AreEqual(2, Data.LineCount);
    Data.Clear;
    Assert.AreEqual(0, Data.LineCount);
    Assert.AreEqual('', Data.RawData);
  finally
    Data.Free;
  end;
end;

procedure TTestCLIPipeline.TestPipelineDataAsString;
var
  Data: TPipelineData;
  Expected: string;
begin
  Data := TPipelineData.Create;
  try
    Data.AddLine('A');
    Data.AddLine('B');
    Data.AddLine('C');
    Expected := 'A' + sLineBreak + 'B' + sLineBreak + 'C';
    Assert.AreEqual(Expected, Data.AsString);
  finally
    Data.Free;
  end;
end;

procedure TTestCLIPipeline.TestPipelineDataLineCount;
var
  Data: TPipelineData;
begin
  Data := TPipelineData.Create;
  try
    Assert.AreEqual(0, Data.LineCount);
    Data.AddLine('1');
    Assert.AreEqual(1, Data.LineCount);
    Data.AddLine('2');
    Assert.AreEqual(2, Data.LineCount);
  finally
    Data.Free;
  end;
end;

procedure TTestCLIPipeline.TestPipelineDataGetLine;
var
  Data: TPipelineData;
begin
  Data := TPipelineData.Create;
  try
    Data.AddLine('First');
    Data.AddLine('Second');
    Data.AddLine('Third');
    Assert.AreEqual('First', Data.GetLine(0));
    Assert.AreEqual('Second', Data.GetLine(1));
    Assert.AreEqual('Third', Data.GetLine(2));
  finally
    Data.Free;
  end;
end;

procedure TTestCLIPipeline.TestPipelineDataGetLineOutOfRange;
var
  Data: TPipelineData;
begin
  Data := TPipelineData.Create;
  try
    Data.AddLine('Only');
    Assert.AreEqual('', Data.GetLine(-1));
    Assert.AreEqual('', Data.GetLine(1));
    Assert.AreEqual('', Data.GetLine(100));
  finally
    Data.Free;
  end;
end;

// ============================================================================
// TPipelineParser Tests
// ============================================================================

procedure TTestCLIPipeline.TestParserIsPipelineSimple;
begin
  Assert.IsTrue(TPipelineParser.IsPipeline('ls | grep test'));
  Assert.IsTrue(TPipelineParser.IsPipeline('cat file.txt > output.txt'));
  Assert.IsTrue(TPipelineParser.IsPipeline('echo hello >> log.txt'));
end;

procedure TTestCLIPipeline.TestParserIsPipelineWithQuotes;
begin
  Assert.IsFalse(TPipelineParser.IsPipeline('echo "hello | world"'));
  Assert.IsFalse(TPipelineParser.IsPipeline('echo ''test > file'''));
end;

procedure TTestCLIPipeline.TestParserIsPipelineNoOperator;
begin
  Assert.IsFalse(TPipelineParser.IsPipeline('simple command'));
  Assert.IsFalse(TPipelineParser.IsPipeline('ls -la'));
end;

procedure TTestCLIPipeline.TestParserSplitByPipe;
var
  Parts: TArray<string>;
begin
  Parts := TPipelineParser.SplitByPipe('cmd1 | cmd2 | cmd3');
  Assert.AreEqual(3, Integer(Length(Parts)));
  Assert.AreEqual('cmd1 ', Parts[0]);
  Assert.AreEqual(' cmd2 ', Parts[1]);
  Assert.AreEqual(' cmd3', Parts[2]);
end;

procedure TTestCLIPipeline.TestParserSplitByPipeWithQuotes;
var
  Parts: TArray<string>;
begin
  Parts := TPipelineParser.SplitByPipe('echo "a|b" | grep test');
  Assert.AreEqual(2, Integer(Length(Parts)));
  Assert.IsTrue(Parts[0].Contains('"a|b"'));
end;

procedure TTestCLIPipeline.TestParserParseSimpleCommand;
var
  Stages: TObjectList<TPipelineStage>;
begin
  Stages := TPipelineParser.Parse('ls -la');
  try
    Assert.AreEqual(1, Integer(Stages.Count));
    Assert.AreEqual(pstCommand, Stages[0].StageType);
    Assert.AreEqual('ls -la', Stages[0].Command);
  finally
    Stages.Free;
  end;
end;

procedure TTestCLIPipeline.TestParserParseFilter;
var
  Stages: TObjectList<TPipelineStage>;
begin
  Stages := TPipelineParser.Parse('grep test');
  try
    Assert.AreEqual(1, Integer(Stages.Count));
    Assert.AreEqual(pstFilter, Stages[0].StageType);
    Assert.AreEqual('grep', Stages[0].Command);
    Assert.AreEqual(1, Integer(Length(Stages[0].Args)));
    Assert.AreEqual('test', Stages[0].Args[0]);
  finally
    Stages.Free;
  end;
end;

procedure TTestCLIPipeline.TestParserParseRedirect;
var
  Stages: TObjectList<TPipelineStage>;
begin
  Stages := TPipelineParser.Parse('echo hello > output.txt');
  try
    Assert.AreEqual(2, Integer(Stages.Count));
    Assert.AreEqual(pstCommand, Stages[0].StageType);
    Assert.AreEqual(pstRedirect, Stages[1].StageType);
    Assert.AreEqual('output.txt', Stages[1].TargetFile);
    Assert.IsFalse(Stages[1].AppendMode);
  finally
    Stages.Free;
  end;
end;

procedure TTestCLIPipeline.TestParserParseAppendRedirect;
var
  Stages: TObjectList<TPipelineStage>;
begin
  Stages := TPipelineParser.Parse('echo hello >> log.txt');
  try
    Assert.AreEqual(2, Integer(Stages.Count));
    Assert.AreEqual(pstRedirect, Stages[1].StageType);
    Assert.AreEqual('log.txt', Stages[1].TargetFile);
    Assert.IsTrue(Stages[1].AppendMode);
  finally
    Stages.Free;
  end;
end;

procedure TTestCLIPipeline.TestParserParseTee;
var
  Stages: TObjectList<TPipelineStage>;
begin
  Stages := TPipelineParser.Parse('tee output.log');
  try
    Assert.AreEqual(1, Integer(Stages.Count));
    Assert.AreEqual(pstTee, Stages[0].StageType);
    Assert.AreEqual('output.log', Stages[0].TargetFile);
  finally
    Stages.Free;
  end;
end;

procedure TTestCLIPipeline.TestParserParseFilterWithOptions;
var
  Stages: TObjectList<TPipelineStage>;
begin
  Stages := TPipelineParser.Parse('grep -i -v pattern');
  try
    Assert.AreEqual(1, Integer(Stages.Count));
    Assert.AreEqual(pstFilter, Stages[0].StageType);
    Assert.IsTrue(Stages[0].Options.ContainsKey('i'));
    Assert.IsTrue(Stages[0].Options.ContainsKey('v'));
    Assert.AreEqual(1, Integer(Length(Stages[0].Args)));
    Assert.AreEqual('pattern', Stages[0].Args[0]);
  finally
    Stages.Free;
  end;
end;

// ============================================================================
// TPipelineFilters.Grep Tests
// ============================================================================

procedure TTestCLIPipeline.TestGrepBasic;
var
  Input, Output: TPipelineData;
  Options: TDictionary<string, string>;
begin
  Input := TPipelineData.Create;
  Options := TDictionary<string, string>.Create;
  try
    Input.SetLines(['apple', 'banana', 'apricot', 'cherry']);
    Output := TPipelineFilters.Grep(Input, ['ap'], Options);
    try
      Assert.AreEqual(2, Output.LineCount);
      Assert.AreEqual('apple', Output.GetLine(0));
      Assert.AreEqual('apricot', Output.GetLine(1));
    finally
      Output.Free;
    end;
  finally
    Input.Free;
    Options.Free;
  end;
end;

procedure TTestCLIPipeline.TestGrepIgnoreCase;
var
  Input, Output: TPipelineData;
  Options: TDictionary<string, string>;
begin
  Input := TPipelineData.Create;
  Options := TDictionary<string, string>.Create;
  try
    Input.SetLines(['Apple', 'BANANA', 'apricot']);
    Options.Add('i', '');
    Output := TPipelineFilters.Grep(Input, ['apple'], Options);
    try
      Assert.AreEqual(1, Output.LineCount);
      Assert.AreEqual('Apple', Output.GetLine(0));
    finally
      Output.Free;
    end;
  finally
    Input.Free;
    Options.Free;
  end;
end;

procedure TTestCLIPipeline.TestGrepInvert;
var
  Input, Output: TPipelineData;
  Options: TDictionary<string, string>;
begin
  Input := TPipelineData.Create;
  Options := TDictionary<string, string>.Create;
  try
    Input.SetLines(['apple', 'banana', 'cherry']);
    Options.Add('v', '');
    Output := TPipelineFilters.Grep(Input, ['a'], Options);
    try
      Assert.AreEqual(1, Output.LineCount);
      Assert.AreEqual('cherry', Output.GetLine(0));
    finally
      Output.Free;
    end;
  finally
    Input.Free;
    Options.Free;
  end;
end;

procedure TTestCLIPipeline.TestGrepNoMatch;
var
  Input, Output: TPipelineData;
  Options: TDictionary<string, string>;
begin
  Input := TPipelineData.Create;
  Options := TDictionary<string, string>.Create;
  try
    Input.SetLines(['apple', 'banana', 'cherry']);
    Output := TPipelineFilters.Grep(Input, ['xyz'], Options);
    try
      Assert.AreEqual(0, Output.LineCount);
    finally
      Output.Free;
    end;
  finally
    Input.Free;
    Options.Free;
  end;
end;

procedure TTestCLIPipeline.TestGrepRegex;
var
  Input, Output: TPipelineData;
  Options: TDictionary<string, string>;
begin
  Input := TPipelineData.Create;
  Options := TDictionary<string, string>.Create;
  try
    Input.SetLines(['test123', 'abc456', 'test789', 'xyz']);
    Output := TPipelineFilters.Grep(Input, ['^test'], Options);
    try
      Assert.AreEqual(2, Output.LineCount);
      Assert.AreEqual('test123', Output.GetLine(0));
      Assert.AreEqual('test789', Output.GetLine(1));
    finally
      Output.Free;
    end;
  finally
    Input.Free;
    Options.Free;
  end;
end;

// ============================================================================
// TPipelineFilters.Sort Tests
// ============================================================================

procedure TTestCLIPipeline.TestSortBasic;
var
  Input, Output: TPipelineData;
  Options: TDictionary<string, string>;
begin
  Input := TPipelineData.Create;
  Options := TDictionary<string, string>.Create;
  try
    Input.SetLines(['cherry', 'apple', 'banana']);
    Output := TPipelineFilters.Sort(Input, [], Options);
    try
      Assert.AreEqual(3, Output.LineCount);
      Assert.AreEqual('apple', Output.GetLine(0));
      Assert.AreEqual('banana', Output.GetLine(1));
      Assert.AreEqual('cherry', Output.GetLine(2));
    finally
      Output.Free;
    end;
  finally
    Input.Free;
    Options.Free;
  end;
end;

procedure TTestCLIPipeline.TestSortReverse;
var
  Input, Output: TPipelineData;
  Options: TDictionary<string, string>;
begin
  Input := TPipelineData.Create;
  Options := TDictionary<string, string>.Create;
  try
    Input.SetLines(['apple', 'banana', 'cherry']);
    Options.Add('r', '');
    Output := TPipelineFilters.Sort(Input, [], Options);
    try
      Assert.AreEqual(3, Output.LineCount);
      Assert.AreEqual('cherry', Output.GetLine(0));
      Assert.AreEqual('banana', Output.GetLine(1));
      Assert.AreEqual('apple', Output.GetLine(2));
    finally
      Output.Free;
    end;
  finally
    Input.Free;
    Options.Free;
  end;
end;

procedure TTestCLIPipeline.TestSortNumeric;
var
  Input, Output: TPipelineData;
  Options: TDictionary<string, string>;
begin
  Input := TPipelineData.Create;
  Options := TDictionary<string, string>.Create;
  try
    Input.SetLines(['10', '2', '1', '20']);
    Options.Add('n', '');
    Output := TPipelineFilters.Sort(Input, [], Options);
    try
      Assert.AreEqual(4, Output.LineCount);
      Assert.AreEqual('1', Output.GetLine(0));
      Assert.AreEqual('2', Output.GetLine(1));
      Assert.AreEqual('10', Output.GetLine(2));
      Assert.AreEqual('20', Output.GetLine(3));
    finally
      Output.Free;
    end;
  finally
    Input.Free;
    Options.Free;
  end;
end;

procedure TTestCLIPipeline.TestSortUnique;
var
  Input, Output: TPipelineData;
  Options: TDictionary<string, string>;
begin
  Input := TPipelineData.Create;
  Options := TDictionary<string, string>.Create;
  try
    Input.SetLines(['apple', 'banana', 'apple', 'cherry', 'banana']);
    Options.Add('u', '');
    Output := TPipelineFilters.Sort(Input, [], Options);
    try
      Assert.AreEqual(3, Output.LineCount);
    finally
      Output.Free;
    end;
  finally
    Input.Free;
    Options.Free;
  end;
end;

// ============================================================================
// TPipelineFilters.Head Tests
// ============================================================================

procedure TTestCLIPipeline.TestHeadDefault;
var
  Input, Output: TPipelineData;
  Options: TDictionary<string, string>;
  I: Integer;
begin
  Input := TPipelineData.Create;
  Options := TDictionary<string, string>.Create;
  try
    for I := 1 to 20 do
      Input.AddLine('Line ' + IntToStr(I));
    Output := TPipelineFilters.Head(Input, [], Options);
    try
      Assert.AreEqual(10, Output.LineCount);
      Assert.AreEqual('Line 1', Output.GetLine(0));
      Assert.AreEqual('Line 10', Output.GetLine(9));
    finally
      Output.Free;
    end;
  finally
    Input.Free;
    Options.Free;
  end;
end;

procedure TTestCLIPipeline.TestHeadWithCount;
var
  Input, Output: TPipelineData;
  Options: TDictionary<string, string>;
begin
  Input := TPipelineData.Create;
  Options := TDictionary<string, string>.Create;
  try
    Input.SetLines(['A', 'B', 'C', 'D', 'E']);
    Output := TPipelineFilters.Head(Input, ['3'], Options);
    try
      Assert.AreEqual(3, Output.LineCount);
      Assert.AreEqual('A', Output.GetLine(0));
      Assert.AreEqual('C', Output.GetLine(2));
    finally
      Output.Free;
    end;
  finally
    Input.Free;
    Options.Free;
  end;
end;

procedure TTestCLIPipeline.TestHeadLessThanCount;
var
  Input, Output: TPipelineData;
  Options: TDictionary<string, string>;
begin
  Input := TPipelineData.Create;
  Options := TDictionary<string, string>.Create;
  try
    Input.SetLines(['A', 'B']);
    Output := TPipelineFilters.Head(Input, ['10'], Options);
    try
      Assert.AreEqual(2, Output.LineCount);
    finally
      Output.Free;
    end;
  finally
    Input.Free;
    Options.Free;
  end;
end;

// ============================================================================
// TPipelineFilters.Tail Tests
// ============================================================================

procedure TTestCLIPipeline.TestTailDefault;
var
  Input, Output: TPipelineData;
  Options: TDictionary<string, string>;
  I: Integer;
begin
  Input := TPipelineData.Create;
  Options := TDictionary<string, string>.Create;
  try
    for I := 1 to 20 do
      Input.AddLine('Line ' + IntToStr(I));
    Output := TPipelineFilters.Tail(Input, [], Options);
    try
      Assert.AreEqual(10, Output.LineCount);
      Assert.AreEqual('Line 11', Output.GetLine(0));
      Assert.AreEqual('Line 20', Output.GetLine(9));
    finally
      Output.Free;
    end;
  finally
    Input.Free;
    Options.Free;
  end;
end;

procedure TTestCLIPipeline.TestTailWithCount;
var
  Input, Output: TPipelineData;
  Options: TDictionary<string, string>;
begin
  Input := TPipelineData.Create;
  Options := TDictionary<string, string>.Create;
  try
    Input.SetLines(['A', 'B', 'C', 'D', 'E']);
    Output := TPipelineFilters.Tail(Input, ['2'], Options);
    try
      Assert.AreEqual(2, Output.LineCount);
      Assert.AreEqual('D', Output.GetLine(0));
      Assert.AreEqual('E', Output.GetLine(1));
    finally
      Output.Free;
    end;
  finally
    Input.Free;
    Options.Free;
  end;
end;

procedure TTestCLIPipeline.TestTailLessThanCount;
var
  Input, Output: TPipelineData;
  Options: TDictionary<string, string>;
begin
  Input := TPipelineData.Create;
  Options := TDictionary<string, string>.Create;
  try
    Input.SetLines(['A', 'B']);
    Output := TPipelineFilters.Tail(Input, ['10'], Options);
    try
      Assert.AreEqual(2, Output.LineCount);
    finally
      Output.Free;
    end;
  finally
    Input.Free;
    Options.Free;
  end;
end;

// ============================================================================
// TPipelineFilters.Uniq Tests
// ============================================================================

procedure TTestCLIPipeline.TestUniqBasic;
var
  Input, Output: TPipelineData;
  Options: TDictionary<string, string>;
begin
  Input := TPipelineData.Create;
  Options := TDictionary<string, string>.Create;
  try
    Input.SetLines(['apple', 'apple', 'banana', 'banana', 'banana', 'cherry']);
    Output := TPipelineFilters.Uniq(Input, [], Options);
    try
      Assert.AreEqual(3, Output.LineCount);
      Assert.AreEqual('apple', Output.GetLine(0));
      Assert.AreEqual('banana', Output.GetLine(1));
      Assert.AreEqual('cherry', Output.GetLine(2));
    finally
      Output.Free;
    end;
  finally
    Input.Free;
    Options.Free;
  end;
end;

procedure TTestCLIPipeline.TestUniqWithCount;
var
  Input, Output: TPipelineData;
  Options: TDictionary<string, string>;
begin
  Input := TPipelineData.Create;
  Options := TDictionary<string, string>.Create;
  try
    Input.SetLines(['a', 'a', 'b']);
    Options.Add('c', '');
    Output := TPipelineFilters.Uniq(Input, [], Options);
    try
      Assert.AreEqual(2, Output.LineCount);
      Assert.IsTrue(Output.GetLine(0).Contains('2'));
      Assert.IsTrue(Output.GetLine(0).Contains('a'));
    finally
      Output.Free;
    end;
  finally
    Input.Free;
    Options.Free;
  end;
end;

procedure TTestCLIPipeline.TestUniqIgnoreCase;
var
  Input, Output: TPipelineData;
  Options: TDictionary<string, string>;
begin
  Input := TPipelineData.Create;
  Options := TDictionary<string, string>.Create;
  try
    Input.SetLines(['Apple', 'APPLE', 'apple', 'Banana']);
    Options.Add('i', '');
    Output := TPipelineFilters.Uniq(Input, [], Options);
    try
      Assert.AreEqual(2, Output.LineCount);
    finally
      Output.Free;
    end;
  finally
    Input.Free;
    Options.Free;
  end;
end;

// ============================================================================
// TPipelineFilters.Wc Tests
// ============================================================================

procedure TTestCLIPipeline.TestWcAll;
var
  Input, Output: TPipelineData;
  Options: TDictionary<string, string>;
begin
  Input := TPipelineData.Create;
  Options := TDictionary<string, string>.Create;
  try
    Input.SetLines(['hello world', 'foo bar baz']);
    Output := TPipelineFilters.Wc(Input, [], Options);
    try
      Assert.AreEqual(1, Output.LineCount);
      Assert.IsTrue(Output.GetLine(0).Contains('2'));  // 2 lines
      Assert.IsTrue(Output.GetLine(0).Contains('5'));  // 5 words
    finally
      Output.Free;
    end;
  finally
    Input.Free;
    Options.Free;
  end;
end;

procedure TTestCLIPipeline.TestWcLinesOnly;
var
  Input, Output: TPipelineData;
  Options: TDictionary<string, string>;
begin
  Input := TPipelineData.Create;
  Options := TDictionary<string, string>.Create;
  try
    Input.SetLines(['a', 'b', 'c', 'd', 'e']);
    Options.Add('l', '');
    Output := TPipelineFilters.Wc(Input, [], Options);
    try
      Assert.AreEqual(1, Output.LineCount);
      Assert.AreEqual('5', Trim(Output.GetLine(0)));
    finally
      Output.Free;
    end;
  finally
    Input.Free;
    Options.Free;
  end;
end;

procedure TTestCLIPipeline.TestWcWordsOnly;
var
  Input, Output: TPipelineData;
  Options: TDictionary<string, string>;
begin
  Input := TPipelineData.Create;
  Options := TDictionary<string, string>.Create;
  try
    Input.SetLines(['one two three']);
    Options.Add('w', '');
    Output := TPipelineFilters.Wc(Input, [], Options);
    try
      Assert.AreEqual(1, Output.LineCount);
      Assert.AreEqual('3', Trim(Output.GetLine(0)));
    finally
      Output.Free;
    end;
  finally
    Input.Free;
    Options.Free;
  end;
end;

// ============================================================================
// TPipelineFilters.Rev Tests
// ============================================================================

procedure TTestCLIPipeline.TestRevBasic;
var
  Input, Output: TPipelineData;
  Options: TDictionary<string, string>;
begin
  Input := TPipelineData.Create;
  Options := TDictionary<string, string>.Create;
  try
    Input.SetLines(['hello', 'world']);
    Output := TPipelineFilters.Rev(Input, [], Options);
    try
      Assert.AreEqual(2, Output.LineCount);
      Assert.AreEqual('olleh', Output.GetLine(0));
      Assert.AreEqual('dlrow', Output.GetLine(1));
    finally
      Output.Free;
    end;
  finally
    Input.Free;
    Options.Free;
  end;
end;

procedure TTestCLIPipeline.TestRevEmpty;
var
  Input, Output: TPipelineData;
  Options: TDictionary<string, string>;
begin
  Input := TPipelineData.Create;
  Options := TDictionary<string, string>.Create;
  try
    Input.SetLines(['']);
    Output := TPipelineFilters.Rev(Input, [], Options);
    try
      Assert.AreEqual(1, Output.LineCount);
      Assert.AreEqual('', Output.GetLine(0));
    finally
      Output.Free;
    end;
  finally
    Input.Free;
    Options.Free;
  end;
end;

// ============================================================================
// TPipelineFilters.Cut Tests
// ============================================================================

procedure TTestCLIPipeline.TestCutSingleField;
var
  Input, Output: TPipelineData;
  Options: TDictionary<string, string>;
begin
  Input := TPipelineData.Create;
  Options := TDictionary<string, string>.Create;
  try
    Input.SetLines(['a,b,c', 'x,y,z']);
    Options.Add('d', ',');
    Options.Add('f', '2');
    Output := TPipelineFilters.Cut(Input, [], Options);
    try
      Assert.AreEqual(2, Output.LineCount);
      Assert.AreEqual('b', Output.GetLine(0));
      Assert.AreEqual('y', Output.GetLine(1));
    finally
      Output.Free;
    end;
  finally
    Input.Free;
    Options.Free;
  end;
end;

procedure TTestCLIPipeline.TestCutMultipleFields;
var
  Input, Output: TPipelineData;
  Options: TDictionary<string, string>;
begin
  Input := TPipelineData.Create;
  Options := TDictionary<string, string>.Create;
  try
    Input.SetLines(['a,b,c,d']);
    Options.Add('d', ',');
    Options.Add('f', '1,3');
    Output := TPipelineFilters.Cut(Input, [], Options);
    try
      Assert.AreEqual(1, Output.LineCount);
      Assert.AreEqual('a,c', Output.GetLine(0));
    finally
      Output.Free;
    end;
  finally
    Input.Free;
    Options.Free;
  end;
end;

procedure TTestCLIPipeline.TestCutFieldRange;
var
  Input, Output: TPipelineData;
  Options: TDictionary<string, string>;
begin
  Input := TPipelineData.Create;
  Options := TDictionary<string, string>.Create;
  try
    Input.SetLines(['a,b,c,d,e']);
    Options.Add('d', ',');
    Options.Add('f', '2-4');
    Output := TPipelineFilters.Cut(Input, [], Options);
    try
      Assert.AreEqual(1, Output.LineCount);
      Assert.AreEqual('b,c,d', Output.GetLine(0));
    finally
      Output.Free;
    end;
  finally
    Input.Free;
    Options.Free;
  end;
end;

procedure TTestCLIPipeline.TestCutCustomDelimiter;
var
  Input, Output: TPipelineData;
  Options: TDictionary<string, string>;
begin
  Input := TPipelineData.Create;
  Options := TDictionary<string, string>.Create;
  try
    Input.SetLines(['a:b:c']);
    Options.Add('d', ':');
    Options.Add('f', '2');
    Output := TPipelineFilters.Cut(Input, [], Options);
    try
      Assert.AreEqual(1, Output.LineCount);
      Assert.AreEqual('b', Output.GetLine(0));
    finally
      Output.Free;
    end;
  finally
    Input.Free;
    Options.Free;
  end;
end;

// ============================================================================
// TPipelineFilters.Tr Tests
// ============================================================================

procedure TTestCLIPipeline.TestTrBasic;
var
  Input, Output: TPipelineData;
  Options: TDictionary<string, string>;
begin
  Input := TPipelineData.Create;
  Options := TDictionary<string, string>.Create;
  try
    Input.SetLines(['hello']);
    Output := TPipelineFilters.Tr(Input, ['l', 'x'], Options);
    try
      Assert.AreEqual(1, Output.LineCount);
      Assert.AreEqual('hexxo', Output.GetLine(0));
    finally
      Output.Free;
    end;
  finally
    Input.Free;
    Options.Free;
  end;
end;

procedure TTestCLIPipeline.TestTrMultipleChars;
var
  Input, Output: TPipelineData;
  Options: TDictionary<string, string>;
begin
  Input := TPipelineData.Create;
  Options := TDictionary<string, string>.Create;
  try
    Input.SetLines(['abc']);
    Output := TPipelineFilters.Tr(Input, ['abc', 'xyz'], Options);
    try
      Assert.AreEqual(1, Output.LineCount);
      Assert.AreEqual('xyz', Output.GetLine(0));
    finally
      Output.Free;
    end;
  finally
    Input.Free;
    Options.Free;
  end;
end;

// ============================================================================
// TPipeline Tests
// ============================================================================

procedure TTestCLIPipeline.TestPipelineCreate;
var
  Pipeline: TPipeline;
begin
  Pipeline := TPipeline.Create;
  try
    Assert.AreEqual('', Pipeline.LastError);
  finally
    Pipeline.Free;
  end;
end;

procedure TTestCLIPipeline.TestPipelineSetStdinString;
var
  Pipeline: TPipeline;
  Output: TPipelineData;
begin
  Pipeline := TPipeline.Create;
  try
    Pipeline.SetStdin('Line1' + sLineBreak + 'Line2');
    Output := Pipeline.Execute('head 1');
    try
      Assert.AreEqual(1, Output.LineCount);
      Assert.AreEqual('Line1', Output.GetLine(0));
    finally
      Output.Free;
    end;
  finally
    Pipeline.Free;
  end;
end;

procedure TTestCLIPipeline.TestPipelineSetStdinLines;
var
  Pipeline: TPipeline;
  Output: TPipelineData;
begin
  Pipeline := TPipeline.Create;
  try
    Pipeline.SetStdin(['apple', 'banana', 'cherry']);
    Output := Pipeline.Execute('tail 2');
    try
      Assert.AreEqual(2, Output.LineCount);
      Assert.AreEqual('banana', Output.GetLine(0));
      Assert.AreEqual('cherry', Output.GetLine(1));
    finally
      Output.Free;
    end;
  finally
    Pipeline.Free;
  end;
end;

procedure TTestCLIPipeline.TestPipelineRegisterFilter;
var
  Pipeline: TPipeline;
  Output: TPipelineData;
begin
  Pipeline := TPipeline.Create;
  try
    Pipeline.RegisterFilter('double',
      function(const Input: TPipelineData; const Args: TArray<string>;
        const Options: TDictionary<string, string>): TPipelineData
      begin
        Result := TPipelineData.Create;
        for var Line in Input.Lines do
        begin
          Result.AddLine(Line);
          Result.AddLine(Line);
        end;
      end);
    Pipeline.SetStdin(['test']);
    Output := Pipeline.Execute('double');
    try
      Assert.AreEqual(2, Output.LineCount);
      Assert.AreEqual('test', Output.GetLine(0));
      Assert.AreEqual('test', Output.GetLine(1));
    finally
      Output.Free;
    end;
  finally
    Pipeline.Free;
  end;
end;

procedure TTestCLIPipeline.TestPipelineExecuteFilter;
var
  Pipeline: TPipeline;
  Output: TPipelineData;
begin
  Pipeline := TPipeline.Create;
  try
    Pipeline.SetStdin(['cherry', 'apple', 'banana']);
    Output := Pipeline.Execute('sort');
    try
      Assert.AreEqual(3, Output.LineCount);
      Assert.AreEqual('apple', Output.GetLine(0));
      Assert.AreEqual('banana', Output.GetLine(1));
      Assert.AreEqual('cherry', Output.GetLine(2));
    finally
      Output.Free;
    end;
  finally
    Pipeline.Free;
  end;
end;

procedure TTestCLIPipeline.TestPipelineExecuteChain;
var
  Pipeline: TPipeline;
  Output: TPipelineData;
begin
  Pipeline := TPipeline.Create;
  try
    Pipeline.SetStdin(['apple', 'apricot', 'banana', 'avocado']);
    Output := Pipeline.Execute('grep ^a | sort | head 2');
    try
      Assert.AreEqual(2, Output.LineCount);
      Assert.AreEqual('apple', Output.GetLine(0));
      Assert.AreEqual('apricot', Output.GetLine(1));
    finally
      Output.Free;
    end;
  finally
    Pipeline.Free;
  end;
end;

{$ENDIF}

end.

initialization
  TDUnitX.RegisterTestFixture(TTestCLIPipeline);
end.
