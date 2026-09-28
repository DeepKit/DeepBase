unit Test.DeepBase.ExportPDFObjGraph;

{ A5-R07 回归：PDF 字体对象号预留。
  TPDFDocument 给 Type0 字体写伴生 CIDFont 时用的是 ObjNum+1，而这个号从未在
  NextObj 分配链上登记过，于是必然与后续 Page/Content/Catalog 撞号：同一文件里
  出现两个同号码对象体、其中一个被 xref 覆盖成孤儿、/DescendantFonts 指向的实体
  不是 CIDFont。本单元只断言对象号图形的不变量，不重复校验字体嵌入内容。 }

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections;

type
  [TestFixture]
  TPDFObjectGraphTests = class
  private
    function ExportedPdf(const AFontNames: array of string;
      APages: Integer): string;
    function ObjectHeaderNumbers(const APdf: string): TList<Integer>;
    function UniqueObjectBody(const APdf: string; ANumber: Integer): string;
    function TrailerSize(const APdf: string): Integer;
    function DescendantNumbers(const APdf: string): TArray<Integer>;
    function FirstObjectWithType0(const APdf: string): Integer;
  public
    [Test]
    procedure SingleFont_Type0AndCompanion_HaveDistinctObjectNumbers;

    [Test]
    procedure SingleFont_DescendantFontResolvesToCidFontType2;

    [Test]
    procedure SingleFont_ObjectNumberSpaceIsContiguousAndComplete;

    [Test]
    procedure TwoFontsTwoPages_NoDuplicateObjectNumbers;

    [Test]
    procedure TwoFontsTwoPages_EachType0PointsAtItsOwnCidFont;

    [Test]
    procedure TwoFontsTwoPages_ObjectNumberSpaceIsContiguousAndComplete;
  end;

implementation

uses
  DeepBase.Export.PDF;

const
  PAGE_W = 595.0;
  PAGE_H = 842.0;

{ 对象体一律以「N 0 obj」独立成行写出（SaveToStream 的格式串决定）。测试样本不含
  图像 XObject，文本走十六进制编码操作符，故流内容里不会出现同形态的行，无需像甲
  A4 校验器那样遮蔽 stream 区段。 }
function PdfLines(const APdf: string): TArray<string>;
var
  Lines: TArray<string>;
  I: Integer;
begin
  Lines := APdf.Split([#10]);
  for I := Low(Lines) to High(Lines) do
    Lines[I] := TrimRight(Lines[I]);
  Result := Lines;
end;

{ 「N 0 obj」形态的行返回 N，否则返回 -1。 }
function ObjectNumberFromLine(const ALine: string): Integer;
var
  Stop: Integer;
begin
  Result := -1;
  Stop := 1;
  while (Stop <= Length(ALine)) and CharInSet(ALine[Stop], ['0' .. '9']) do
    Inc(Stop);
  if (Stop > 1) and (Copy(ALine, Stop, 6) = ' 0 obj') then
    Result := StrToInt(Copy(ALine, 1, Stop - 1));
end;

{ 从 AStart 起读连续十进制数字（调用方保证 AStart 指向首位数字）。 }
function ReadLeadingInt(const AText: string; AStart: Integer): Integer;
var
  Stop: Integer;
begin
  Stop := AStart;
  while (Stop <= Length(AText)) and CharInSet(AText[Stop], ['0' .. '9']) do
    Inc(Stop);
  Result := StrToInt(Copy(AText, AStart, Stop - AStart));
end;

{ TPDFObjectGraphTests }

function TPDFObjectGraphTests.ExportedPdf(
  const AFontNames: array of string; APages: Integer): string;
var
  P: TPDFDocument;
  MS: TMemoryStream;
  Page, I: Integer;
  Bytes: TBytes;
begin
  P := TPDFDocument.Create;
  MS := TMemoryStream.Create;
  try
    P.SetPageSize(PAGE_W, PAGE_H);
    for Page := 1 to APages do
    begin
      P.AddPage;
      for I := Low(AFontNames) to High(AFontNames) do
      begin
        P.SetFont(AFontNames[I], 12 + I);
        P.DrawText(50, 780 - (Page * 20), Format('page %d font %d', [Page, I]));
      end;
    end;
    P.SaveToStream(MS);
    SetLength(Bytes, MS.Size);
    MS.Position := 0;
    MS.ReadBuffer(Bytes[0], MS.Size);
    Result := TEncoding.UTF8.GetString(Bytes);
  finally
    MS.Free;
    P.Free;
  end;
end;

function TPDFObjectGraphTests.ObjectHeaderNumbers(
  const APdf: string): TList<Integer>;
var
  Line: string;
  Number: Integer;
begin
  Result := TList<Integer>.Create;
  for Line in PdfLines(APdf) do
  begin
    Number := ObjectNumberFromLine(Line);
    if Number >= 0 then
      Result.Add(Number);
  end;
end;

{ 取对象体（头行到 endobj）。号码出现 0 次或 2 次以上一律判失败——那正是 R07 的
  两种症状：预留不写（孤儿号段）与撞号（重号体）。 }
function TPDFObjectGraphTests.UniqueObjectBody(
  const APdf: string; ANumber: Integer): string;
var
  Lines: TArray<string>;
  I: Integer;
  InBody: Boolean;
  Matches: Integer;
begin
  Lines := PdfLines(APdf);
  Matches := 0;
  Result := '';
  InBody := False;
  for I := Low(Lines) to High(Lines) do
  begin
    if InBody then
    begin
      Result := Result + Lines[I] + #10;
      if Pos('endobj', Lines[I]) > 0 then
        InBody := False;
      Continue;
    end;
    if ObjectNumberFromLine(Lines[I]) = ANumber then
    begin
      Inc(Matches);
      Result := Lines[I] + #10;
      InBody := True;
    end;
  end;
  Assert.AreEqual<Integer>(1, Matches,
    'object ' + IntToStr(ANumber) + ' must have exactly one body, found ' +
    IntToStr(Matches));
end;

function TPDFObjectGraphTests.TrailerSize(const APdf: string): Integer;
var
  Idx: Integer;
begin
  Idx := Pos('/Size ', APdf);
  Assert.IsTrue(Idx > 0, 'trailer must declare /Size');
  Result := ReadLeadingInt(APdf, Idx + Length('/Size '));
end;

function TPDFObjectGraphTests.FirstObjectWithType0(
  const APdf: string): Integer;
var
  Numbers: TList<Integer>;
  Number: Integer;
begin
  Result := -1;
  Numbers := ObjectHeaderNumbers(APdf);
  try
    for Number in Numbers do
      if Pos('/Subtype /Type0', UniqueObjectBody(APdf, Number)) > 0 then
        Exit(Number);
  finally
    Numbers.Free;
  end;
end;

{ 返回每个 Type0 字体的 /DescendantFonts 目标号，顺序与对象号升序一致。 }
function TPDFObjectGraphTests.DescendantNumbers(
  const APdf: string): TArray<Integer>;
var
  Numbers: TList<Integer>;
  List: TList<Integer>;
  Number: Integer;
  Body: string;
  Idx: Integer;
begin
  List := TList<Integer>.Create;
  Numbers := ObjectHeaderNumbers(APdf);
  try
    Numbers.Sort;
    for Number in Numbers do
    begin
      Body := UniqueObjectBody(APdf, Number);
      if Pos('/Subtype /Type0', Body) = 0 then
        Continue;
      Idx := Pos('/DescendantFonts [', Body);
      Assert.IsTrue(Idx > 0,
        'Type0 font object ' + IntToStr(Number) + ' has no /DescendantFonts array');
      List.Add(ReadLeadingInt(Body, Idx + Length('/DescendantFonts [')));
    end;
    Result := List.ToArray;
  finally
    Numbers.Free;
    List.Free;
  end;
end;

procedure TPDFObjectGraphTests.SingleFont_Type0AndCompanion_HaveDistinctObjectNumbers;
var
  Pdf: string;
  Numbers: TList<Integer>;
  Seen: TList<Integer>;
  Number: Integer;
  Dup: string;
begin
  Pdf := ExportedPdf(['SimSun'], 1);
  Numbers := ObjectHeaderNumbers(Pdf);
  Seen := TList<Integer>.Create;
  try
    Dup := '';
    for Number in Numbers do
      if Seen.Contains(Number) then
        Dup := Dup + IntToStr(Number) + ','
      else
        Seen.Add(Number);
    Assert.AreEqual('', Dup,
      'duplicate object numbers written into one PDF (A5-R07: the CIDFont ' +
      'companion was emitted at ObjNum+1 without reserving that number)');
    Assert.AreEqual<Integer>(6, Numbers.Count,
      '1 page + 1 font = page/content/font/cidfont/pages/catalog bodies');
  finally
    Numbers.Free;
    Seen.Free;
  end;
end;

procedure TPDFObjectGraphTests.SingleFont_DescendantFontResolvesToCidFontType2;
var
  Pdf: string;
  Descendants: TArray<Integer>;
  Type0Body: string;
  DescendantBody: string;
  Type0Number: Integer;
begin
  Pdf := ExportedPdf(['SimSun'], 1);
  Descendants := DescendantNumbers(Pdf);
  Assert.AreEqual<Integer>(1, Length(Descendants));
  Type0Number := FirstObjectWithType0(Pdf);
  Assert.IsTrue(Type0Number > 0, 'no Type0 font object found');
  Type0Body := UniqueObjectBody(Pdf, Type0Number);
  Assert.IsTrue(
    Pos('/DescendantFonts [' + IntToStr(Descendants[0]) + ' 0 R]', Type0Body) > 0,
    'Type0 ' + IntToStr(Type0Number) + ' must reference object ' +
    IntToStr(Descendants[0]) + ' as its descendant');
  DescendantBody := UniqueObjectBody(Pdf, Descendants[0]);
  Assert.IsTrue(Pos('/Subtype /CIDFontType2', DescendantBody) > 0,
    'descendant object ' + IntToStr(Descendants[0]) +
    ' is not a CIDFontType2 body (A5-R07: the number was taken by Pages/Catalog)');
  Assert.IsTrue(Pos('/BaseFont /SimSun', DescendantBody) > 0,
    'descendant must carry the same /BaseFont as its Type0 parent');
end;

procedure TPDFObjectGraphTests.SingleFont_ObjectNumberSpaceIsContiguousAndComplete;
var
  Pdf: string;
  Size: Integer;
  Numbers: TList<Integer>;
  I: Integer;
  Missing: string;
begin
  Pdf := ExportedPdf(['SimSun'], 1);
  Size := TrailerSize(Pdf);
  Numbers := ObjectHeaderNumbers(Pdf);
  try
    // /Size = 最大对象号 + 1；号段内每个号都必须恰有一个对象体，
    // 既不能预留不写（孤儿号段），也不能复用（重号）。
    Assert.AreEqual<Integer>(Numbers.Count + 1, Size,
      'trailer /Size ' + IntToStr(Size) + ' disagrees with ' +
      IntToStr(Numbers.Count) + ' written object bodies');
    Missing := '';
    for I := 1 to Size - 1 do
      if not Numbers.Contains(I) then
        Missing := Missing + IntToStr(I) + ',';
    Assert.AreEqual('', Missing,
      'object numbers declared but never written: ' + Missing);
  finally
    Numbers.Free;
  end;
end;

procedure TPDFObjectGraphTests.TwoFontsTwoPages_NoDuplicateObjectNumbers;
var
  Pdf: string;
  Numbers: TList<Integer>;
  Seen: TList<Integer>;
  Number: Integer;
  Dup: string;
begin
  Pdf := ExportedPdf(['SimSun', 'Helvetica'], 2);
  Numbers := ObjectHeaderNumbers(Pdf);
  Seen := TList<Integer>.Create;
  try
    Dup := '';
    for Number in Numbers do
      if Seen.Contains(Number) then
        Dup := Dup + IntToStr(Number) + ','
      else
        Seen.Add(Number);
    Assert.AreEqual('', Dup, 'duplicate object numbers with 2 fonts on 2 pages');
    Assert.AreEqual<Integer>(10, Numbers.Count,
      '2 pages(2) + 2 contents(2) + 2 fonts(4) + pages + catalog');
  finally
    Numbers.Free;
    Seen.Free;
  end;
end;

procedure TPDFObjectGraphTests.TwoFontsTwoPages_EachType0PointsAtItsOwnCidFont;
var
  Pdf: string;
  Descendants: TArray<Integer>;
  I: Integer;
begin
  Pdf := ExportedPdf(['SimSun', 'Helvetica'], 2);
  Descendants := DescendantNumbers(Pdf);
  Assert.AreEqual<Integer>(2, Length(Descendants),
    'two font entries on the last page must yield two Type0 objects');
  Assert.IsTrue(Descendants[0] <> Descendants[1],
    'both Type0 fonts share descendant ' + IntToStr(Descendants[0]));
  for I := 0 to High(Descendants) do
    Assert.IsTrue(
      Pos('/Subtype /CIDFontType2', UniqueObjectBody(Pdf, Descendants[I])) > 0,
      'descendant ' + IntToStr(Descendants[I]) + ' is not a CIDFontType2 body');
end;

procedure TPDFObjectGraphTests.TwoFontsTwoPages_ObjectNumberSpaceIsContiguousAndComplete;
var
  Pdf: string;
  Size: Integer;
  Numbers: TList<Integer>;
  I: Integer;
  Missing: string;
begin
  Pdf := ExportedPdf(['SimSun', 'Helvetica'], 2);
  Size := TrailerSize(Pdf);
  Numbers := ObjectHeaderNumbers(Pdf);
  try
    Assert.AreEqual<Integer>(Numbers.Count + 1, Size,
      'trailer /Size ' + IntToStr(Size) + ' disagrees with ' +
      IntToStr(Numbers.Count) + ' written object bodies');
    Missing := '';
    for I := 1 to Size - 1 do
      if not Numbers.Contains(I) then
        Missing := Missing + IntToStr(I) + ',';
    Assert.AreEqual('', Missing,
      'object numbers declared but never written: ' + Missing);
  finally
    Numbers.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TPDFObjectGraphTests);

end.
