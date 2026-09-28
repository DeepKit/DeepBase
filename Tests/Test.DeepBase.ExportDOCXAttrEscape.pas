unit Test.DeepBase.ExportDOCXAttrEscape;

{ A5-R08 回归：DOCX 属性值转义。
  TDOCXDocument 的文本面（<w:t>）一直走 EscapeXML，但三个属性值写出口
  （w:rFonts 的 ascii/eastAsia/hAnsi、w:color w:val、w:shd w:fill）直接把调用方
  传入的字符串塞进双引号里。于是字体名或表头底色里出现一个 " 就会提前闭合属性值，
  document.xml 不再是良构 XML；进一步用 "/><... 形态还能在属性位里注入元素。
  本单元只断言「属性值 round-trip 逐字一致 + 不产出额外元素」这两个不变量，
  不复制 Core 的转义算法，避免形成第二套真相源。

  覆盖边界（登记，非本单可测项）：TParagraphRun.FontColor 在本单元内没有任何公开
  写入口（AddParagraph/AddParagraphRuns 一律置空串），所以 w:color 这一处只能随
  另两处同批修，无法从公开 API 构造样本；w:rFonts 与 w:shd w:fill 分别由
  SetDefaultFont 与 AddTable 的 AHeaderColor 驱动，可端到端验证。 }

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes;

type

  [TestFixture]
  TDOCXAttributeEscapeTests = class
  private
    function BuiltDocumentXml(const AFontName: string;
      const AHeaderColor: string; const AText: string): string;
    function AttrValue(const AXml: string; const AAttr: string;
      out AFound: Boolean): string;
    function CountSubstring(const AHaystack, ANeedle: string): Integer;
  public
    [Test]
    procedure FontName_WithQuote_AttributeValueRoundTrips;

    [Test]
    procedure FontName_WithMarkupInjection_NoExtraElementsProduced;

    [Test]
    procedure HeaderColor_WithQuoteAndAngleBrackets_RoundTrips;

    [Test]
    procedure HeaderColor_WithElementInjection_ShadingCountStaysAtColumnCount;

    [Test]
    procedure AttributeSinks_NoRawQuoteInsideStartTags;

    [Test]
    procedure TextAndCellRoundTrip_WithSpecialCjkAndBracketBracketGreater;
  end;

implementation

uses
  System.Zip,
  System.StrUtils,
  DeepBase.Export.DOCX;

const
  // 与甲 A4 探针 A407_DOCX.dpr.template 同形的三类载荷：裸引号、属性位元素注入，
  // 以及 CDATA 终止序列（属性值里 ]]> 无需转义，但必须逐字回来）。
  QUOTE_PAYLOAD = 'Bad"Font';
  INJECT_PAYLOAD = 'x"/><w:ins w:id="9"/><w:rFonts w:ascii="y';
  BRACKET_PAYLOAD = 'A]]>B"C&D<E>F';
  // 「中文测试」——按 A4 探针的做法写码位，避免源文件字面量参与编码面判定。
  CJK_TEXT = #$4E2D#$6587#$6D4B#$8BD5;
  // 数「属性位注入出的新元素」不能用裸 <w:ins：w:tblBorders 里本来就有
  // <w:insideH>/<w:insideV> 两个元素以这四个字母开头，必须带上属性名定界。
  INJECTED_ELEMENT = '<w:ins w:id';

{ 反向走一遍 XML 属性实体的解码。只解五个标准实体，且 &amp; 放最后，
  以免把 &amp;lt; 这类二次转义解成 <。 }

function UnescapeXmlAttr(const AValue: string): string;
begin
  Result := AValue;
  Result := StringReplace(Result, '&lt;', '<', [rfReplaceAll]);
  Result := StringReplace(Result, '&gt;', '>', [rfReplaceAll]);
  Result := StringReplace(Result, '&quot;', '"', [rfReplaceAll]);
  Result := StringReplace(Result, '&apos;', '''', [rfReplaceAll]);
  Result := StringReplace(Result, '&amp;', '&', [rfReplaceAll]);
end;

{ TDOCXAttributeEscapeTests }

function TDOCXAttributeEscapeTests.BuiltDocumentXml(const AFontName: string;
  const AHeaderColor: string; const AText: string): string;
var
  Doc: TDOCXDocument;
  MS: TMemoryStream;
  Zip: TZipFile;
  Content: TBytes;
begin
  Doc := TDOCXDocument.Create;
  try
    Doc.SetDefaultFont(AFontName, 12);
    Doc.AddParagraph(AText);
    Doc.AddTable(['h1', 'h2'], [['a', 'b'], [AText, 'row2col2']], nil,
      AHeaderColor);
    MS := TMemoryStream.Create;
    try
      Doc.SaveToStream(MS);
      { 刻意经由「真导出 → 解包」而不是单测某个私有函数：判据要和 Word 看到的一致。 }
      MS.Position := 0;
      Zip := TZipFile.Create;
      try
        Zip.Open(MS, zmRead);
        try
          Assert.IsTrue(Zip.IndexOf('word/document.xml') >= 0,
            'DOCX package must contain word/document.xml');
          Zip.Read('word/document.xml', Content);
        finally
          Zip.Close;
        end;
      finally
        Zip.Free;
      end;
      Result := TEncoding.UTF8.GetString(Content);
    finally
      MS.Free;
    end;
  finally
    Doc.Free;
  end;
end;

{ 取出属性值原文（仍处于转义态）。读到第一个裸 " 就结束——这正是良构属性的定义：
  值里不允许出现未转义的定界符。修复前载荷里的 " 会在这里把值截断。 }

function TDOCXAttributeEscapeTests.AttrValue(const AXml: string;
  const AAttr: string; out AFound: Boolean): string;
var
  Start, Quote: Integer;
  Marker: string;
begin
  Marker := AAttr + '="';
  Start := PosEx(Marker, AXml, 1);
  AFound := Start > 0;
  if not AFound then
    Exit('');
  Inc(Start, Length(Marker));
  Quote := PosEx('"', AXml, Start);
  Assert.IsTrue(Quote > 0,
    'attribute ' + AAttr + ' has no closing quote in document.xml');
  Result := Copy(AXml, Start, Quote - Start);
end;

function TDOCXAttributeEscapeTests.CountSubstring(const AHaystack,
  ANeedle: string): Integer;
var
  Hit: Integer;
begin
  Result := 0;
  Hit := PosEx(ANeedle, AHaystack, 1);
  while Hit > 0 do
  begin
    Inc(Result);
    Hit := PosEx(ANeedle, AHaystack, Hit + Length(ANeedle));
  end;
end;

procedure TDOCXAttributeEscapeTests
  .FontName_WithQuote_AttributeValueRoundTrips;
var
  Doc, Raw: string;
  Found: Boolean;
begin
  Doc := BuiltDocumentXml(QUOTE_PAYLOAD, '4472C4', 'plain-text');
  Raw := AttrValue(Doc, 'w:ascii', Found);
  Assert.IsTrue(Found, 'expected a w:rFonts element carrying w:ascii');
  Assert.AreEqual(QUOTE_PAYLOAD, UnescapeXmlAttr(Raw),
    'font name must come back byte-for-byte; raw attribute value was: ' + Raw);
  // 三个属性共用同一个字体名，任何一个漏转义都会破坏良构。
  Assert.AreEqual(QUOTE_PAYLOAD,
    UnescapeXmlAttr(AttrValue(Doc, 'w:eastAsia', Found)));
  Assert.AreEqual(QUOTE_PAYLOAD,
    UnescapeXmlAttr(AttrValue(Doc, 'w:hAnsi', Found)));
end;

procedure TDOCXAttributeEscapeTests
  .FontName_WithMarkupInjection_NoExtraElementsProduced;
var
  Doc, Raw: string;
  Found: Boolean;
begin
  Doc := BuiltDocumentXml(INJECT_PAYLOAD, '4472C4', 'plain-text');
  Raw := AttrValue(Doc, 'w:ascii', Found);
  Assert.IsTrue(Found, 'expected a w:rFonts element carrying w:ascii');
  Assert.AreEqual(INJECT_PAYLOAD, UnescapeXmlAttr(Raw),
    'injected payload must stay inside the attribute value; raw was: ' + Raw);
  Assert.AreEqual<Integer>(0, CountSubstring(Doc, INJECTED_ELEMENT),
    'attribute value must not be able to open a new element');
  Assert.AreEqual<Integer>(1, CountSubstring(Doc, '<w:rFonts'),
    'exactly one rFonts element per run');
end;

procedure TDOCXAttributeEscapeTests
  .HeaderColor_WithQuoteAndAngleBrackets_RoundTrips;
var
  Doc, Raw: string;
  Found: Boolean;
begin
  Doc := BuiltDocumentXml('SimSun', BRACKET_PAYLOAD, 'plain-text');
  Raw := AttrValue(Doc, 'w:fill', Found);
  Assert.IsTrue(Found, 'expected header cells to carry a w:shd w:fill');
  Assert.AreEqual(BRACKET_PAYLOAD, UnescapeXmlAttr(Raw),
    'header colour must round-trip through the attribute; raw was: ' + Raw);
  Assert.AreEqual('SimSun', UnescapeXmlAttr(AttrValue(Doc, 'w:ascii', Found)),
    'sibling attributes must not be disturbed');
end;

procedure TDOCXAttributeEscapeTests
  .HeaderColor_WithElementInjection_ShadingCountStaysAtColumnCount;
var
  Doc, Raw: string;
  Found: Boolean;
begin
  Doc := BuiltDocumentXml('SimSun', INJECT_PAYLOAD, 'plain-text');
  Raw := AttrValue(Doc, 'w:fill', Found);
  Assert.IsTrue(Found, 'expected header cells to carry a w:shd w:fill');
  Assert.AreEqual(INJECT_PAYLOAD, UnescapeXmlAttr(Raw),
    'header colour injection must stay quoted; raw was: ' + Raw);
  Assert.AreEqual<Integer>(0, CountSubstring(Doc, INJECTED_ELEMENT),
    'w:fill value produced a new element');
  Assert.AreEqual<Integer>(2, CountSubstring(Doc, '<w:shd'),
    'two header columns must produce exactly two w:shd elements');
end;

procedure TDOCXAttributeEscapeTests
  .AttributeSinks_NoRawQuoteInsideStartTags;
var
  Doc, Tag, Head: string;
  Kind, I, J, TagStart, TagEnd, Quotes: Integer;
  Required: array of string;
begin
  { 结构不变量：属性值里的裸 " 会让开始标记提前出现 '>'，把标记撕成两段——
    撕开的证据不是「有没有游离引号」这种字符级巧合，而是这个开始标记里
    本该同时存在的几个属性消失了一个。所以三条一起断言：
      1) 属性集完整（rFonts 三个、shd 三个都必须在同一个标记内）
      2) 标记内引号成对
      3) 标记内没有游离 '<'
    不依赖任何转义实现细节。 }
  Doc := BuiltDocumentXml(INJECT_PAYLOAD, INJECT_PAYLOAD, 'plain-text');
  for Kind := 1 to 2 do
  begin
    if Kind = 1 then
    begin
      Tag := '<w:rFonts';
      Required := ['w:ascii', 'w:eastAsia', 'w:hAnsi'];
    end
    else
    begin
      Tag := '<w:shd';
      Required := ['w:val', 'w:color', 'w:fill'];
    end;
    TagStart := PosEx(Tag, Doc, 1);
    Assert.IsTrue(TagStart > 0, Tag + ' element missing');
    TagEnd := PosEx('>', Doc, TagStart);
    Assert.IsTrue(TagEnd > 0, Tag + ' element never closes');
    Head := Copy(Doc, TagStart, TagEnd - TagStart);
    for J := Low(Required) to High(Required) do
      Assert.IsTrue(PosEx(Required[J] + '="', Head, 1) > 0,
        Tag + ' was torn apart before attribute ' + Required[J] +
        ': ' + Head);
    Quotes := CountSubstring(Head, '"');
    Assert.AreEqual<Integer>(0, Quotes mod 2,
      Tag + ' ...> carries an odd number of quotes, so the element is torn ' +
      'apart: ' + Head);
    // Head 的第 1 个字符就是标记自己的 '<'，游离 '<' 只可能出现在它之后。
    for I := 2 to Length(Head) do
      Assert.IsTrue(Head[I] <> '<',
        'raw < inside a start tag means markup leaked out of the attribute: ' + Head);
  end;
end;

procedure TDOCXAttributeEscapeTests
  .TextAndCellRoundTrip_WithSpecialCjkAndBracketBracketGreater;
var
  Source, Doc: string;
  Found: Boolean;
begin
  Source := 'Special: & < > " '' ' + CJK_TEXT;
  Doc := BuiltDocumentXml('SimSun', '4472C4', Source);
  // 文本面（<w:t>）本来就已转义，这里作为不得回归的护栏。
  Assert.IsTrue(PosEx('<w:t xml:space="preserve">' + Source, Doc, 1) = 0,
    'raw source text must never appear inside document.xml');
  Assert.AreEqual('SimSun', AttrValue(Doc, 'w:ascii', Found));
  Assert.AreEqual('4472C4', AttrValue(Doc, 'w:fill', Found));
  Assert.AreEqual<Integer>(0, CountSubstring(Doc, INJECTED_ELEMENT),
    'text path must not produce injected elements either');
  // 表头 2 格 + 表体 2 行 × 2 列 = 6 格。
  Assert.AreEqual<Integer>(6, CountSubstring(Doc, '<w:tc>'),
    'table must keep its 2 header cells and 4 data cells');
  Assert.IsTrue(CountSubstring(Doc, '&lt;') >= 2,
    'angle brackets from the source text must be entity-encoded');
end;

initialization
  TDUnitX.RegisterTestFixture(TDOCXAttributeEscapeTests);

end.
