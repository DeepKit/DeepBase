unit Test.DeepBase.Export.Gen;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.IOUtils;

type
  [TestFixture]
  TPDFExportTests = class
  public
    [Test]
    procedure Test_CreateEmptyPDF;

    [Test]
    procedure Test_DrawText;

    [Test]
    procedure Test_DrawText_CJK;

    [Test]
    procedure Test_DrawTextAligned_Center;

    [Test]
    procedure Test_DrawTextBlock_Wrapping;

    [Test]
    procedure Test_DrawLine;

    [Test]
    procedure Test_DrawRect;

    [Test]
    procedure Test_DrawTable;

    [Test]
    procedure Test_MultiPage;

    [Test]
    procedure Test_SaveToStream;
  end;

  [TestFixture]
  TDOCXExportTests = class
  public
    [Test]
    procedure Test_CreateEmptyDOCX;

    [Test]
    procedure Test_AddParagraph;

    [Test]
    procedure Test_AddParagraph_Bold;

    [Test]
    procedure Test_AddTable;

    [Test]
    procedure Test_SaveToStream;
  end;

  [TestFixture]
  TShareTests = class
  public
    [Test]
    procedure Test_CopyToClipboard;

    [Test]
    procedure Test_GetPicturesFolder;

    [Test]
    procedure Test_GetTempSharePath;
  end;

implementation

uses
  DeepBase.Export.PDF,
  DeepBase.Export.DOCX,
  DeepBase.Share;

{ TPDFExportTests }

procedure TPDFExportTests.Test_CreateEmptyPDF;
var
  PDF: TPDFDocument;
  MS: TMemoryStream;
  Header: TBytes;
  S: string;
begin
  PDF := TPDFDocument.Create;
  try
    PDF.AddPage;
    MS := TMemoryStream.Create;
    try
      PDF.SaveToStream(MS);
      Assert.IsTrue(MS.Size > 0, 'PDF stream should not be empty');
      MS.Position := 0;
      SetLength(Header, 8);
      MS.ReadBuffer(Header[0], Length(Header));
      S := TEncoding.ASCII.GetString(Header);
      Assert.AreEqual('%PDF-1.', Copy(S, 1, 7), 'Should start with %PDF-1.');
    finally
      MS.Free;
    end;
  finally
    PDF.Free;
  end;
end;

procedure TPDFExportTests.Test_DrawText;
var
  PDF: TPDFDocument;
  MS: TMemoryStream;
begin
  PDF := TPDFDocument.Create;
  try
    PDF.AddPage;
    PDF.DrawText(50, 50, 'Hello World');
    MS := TMemoryStream.Create;
    try
      PDF.SaveToStream(MS);
      Assert.IsTrue(MS.Size > 100, 'PDF with text should have content');
    finally
      MS.Free;
    end;
  finally
    PDF.Free;
  end;
end;

procedure TPDFExportTests.Test_DrawText_CJK;
var
  PDF: TPDFDocument;
  MS: TMemoryStream;
begin
  PDF := TPDFDocument.Create;
  try
    PDF.AddPage;
    PDF.SetFont('SimSun', 14);
    PDF.DrawText(50, 50, #20320#22909#19990#30028' - Hello');
    MS := TMemoryStream.Create;
    try
      PDF.SaveToStream(MS);
      Assert.IsTrue(MS.Size > 100, 'PDF with CJK text should have content');
    finally
      MS.Free;
    end;
  finally
    PDF.Free;
  end;
end;

procedure TPDFExportTests.Test_DrawTextAligned_Center;
var
  PDF: TPDFDocument;
  MS: TMemoryStream;
begin
  PDF := TPDFDocument.Create;
  try
    PDF.AddPage;
    PDF.DrawTextAligned(50, 50, 200, 'Center', paCenter);
    MS := TMemoryStream.Create;
    try
      PDF.SaveToStream(MS);
      Assert.IsTrue(MS.Size > 100);
    finally
      MS.Free;
    end;
  finally
    PDF.Free;
  end;
end;

procedure TPDFExportTests.Test_DrawTextBlock_Wrapping;
var
  PDF: TPDFDocument;
  MS: TMemoryStream;
  H: Double;
begin
  PDF := TPDFDocument.Create;
  try
    PDF.AddPage;
    H := PDF.DrawTextBlock(50, 50, 200,
      'This is a long text that should wrap across multiple lines when rendered.');
    Assert.IsTrue(H > 0, 'DrawTextBlock should return positive height');
    MS := TMemoryStream.Create;
    try
      PDF.SaveToStream(MS);
      Assert.IsTrue(MS.Size > 100);
    finally
      MS.Free;
    end;
  finally
    PDF.Free;
  end;
end;

procedure TPDFExportTests.Test_DrawLine;
var
  PDF: TPDFDocument;
  MS: TMemoryStream;
begin
  PDF := TPDFDocument.Create;
  try
    PDF.AddPage;
    PDF.DrawLine(50, 50, 200, 50);
    MS := TMemoryStream.Create;
    try
      PDF.SaveToStream(MS);
      Assert.IsTrue(MS.Size > 100);
    finally
      MS.Free;
    end;
  finally
    PDF.Free;
  end;
end;

procedure TPDFExportTests.Test_DrawRect;
var
  PDF: TPDFDocument;
  MS: TMemoryStream;
begin
  PDF := TPDFDocument.Create;
  try
    PDF.AddPage;
    PDF.SetFillColor(TPDFColor.LightGray);
    PDF.DrawRect(50, 50, 200, 100, True, True);
    MS := TMemoryStream.Create;
    try
      PDF.SaveToStream(MS);
      Assert.IsTrue(MS.Size > 100);
    finally
      MS.Free;
    end;
  finally
    PDF.Free;
  end;
end;

procedure TPDFExportTests.Test_DrawTable;
var
  PDF: TPDFDocument;
  MS: TMemoryStream;
  Cols: TArray<TPDFColumnDef>;
begin
  PDF := TPDFDocument.Create;
  try
    PDF.AddPage;
    Cols := [
      TPDFColumnDef.Create('Name', 100),
      TPDFColumnDef.Create('Age', 60, paCenter),
      TPDFColumnDef.Create('Score', 80, paRight)
    ];
    PDF.DrawTable(50, 50, Cols,
      [['Alice', '30', '95.5'], ['Bob', '25', '87.3']],
      TPDFColor.Blue);
    MS := TMemoryStream.Create;
    try
      PDF.SaveToStream(MS);
      Assert.IsTrue(MS.Size > 200);
    finally
      MS.Free;
    end;
  finally
    PDF.Free;
  end;
end;

procedure TPDFExportTests.Test_MultiPage;
var
  PDF: TPDFDocument;
  MS: TMemoryStream;
begin
  PDF := TPDFDocument.Create;
  try
    PDF.AddPage;
    PDF.DrawText(50, 50, 'Page 1');
    PDF.AddPage;
    PDF.DrawText(50, 50, 'Page 2');
    PDF.AddPage;
    PDF.DrawText(50, 50, 'Page 3');
    MS := TMemoryStream.Create;
    try
      PDF.SaveToStream(MS);
      Assert.IsTrue(MS.Size > 200, 'Multi-page PDF should be substantial');
    finally
      MS.Free;
    end;
  finally
    PDF.Free;
  end;
end;

procedure TPDFExportTests.Test_SaveToStream;
var
  PDF: TPDFDocument;
  MS: TMemoryStream;
  Reader: TStreamReader;
  Content: string;
begin
  PDF := TPDFDocument.Create;
  try
    PDF.AddPage;
    PDF.DrawText(50, 50, 'Test');
    MS := TMemoryStream.Create;
    try
      PDF.SaveToStream(MS);
      MS.Position := MS.Size - 8;
      Reader := TStreamReader.Create(MS);
      try
        Content := Reader.ReadToEnd;
        Assert.Contains(Content, '%%EOF');
      finally
        Reader.Free;
      end;
    finally
      MS.Free;
    end;
  finally
    PDF.Free;
  end;
end;

{ TDOCXExportTests }

procedure TDOCXExportTests.Test_CreateEmptyDOCX;
var
  Doc: TDOCXDocument;
  MS: TMemoryStream;
begin
  Doc := TDOCXDocument.Create;
  try
    MS := TMemoryStream.Create;
    try
      Doc.SaveToStream(MS);
      Assert.IsTrue(MS.Size > 0, 'DOCX stream should not be empty');
      MS.Position := 0;
      // DOCX is a ZIP, starts with PK signature
      Assert.AreEqual(Byte($50), PByte(MS.Memory)^, 'Should start with PK');
      Assert.AreEqual(Byte($4B), PByte(NativeUInt(MS.Memory) + 1)^, 'Should be PK');
    finally
      MS.Free;
    end;
  finally
    Doc.Free;
  end;
end;

procedure TDOCXExportTests.Test_AddParagraph;
var
  Doc: TDOCXDocument;
  MS: TMemoryStream;
begin
  Doc := TDOCXDocument.Create;
  try
    Doc.AddParagraph('Hello World');
    MS := TMemoryStream.Create;
    try
      Doc.SaveToStream(MS);
      Assert.IsTrue(MS.Size > 500, 'DOCX with paragraph should be substantial');
    finally
      MS.Free;
    end;
  finally
    Doc.Free;
  end;
end;

procedure TDOCXExportTests.Test_AddParagraph_Bold;
var
  Doc: TDOCXDocument;
  MS: TMemoryStream;
begin
  Doc := TDOCXDocument.Create;
  try
    Doc.AddParagraph('Bold Title', 16, True);
    Doc.AddParagraph('Normal text');
    MS := TMemoryStream.Create;
    try
      Doc.SaveToStream(MS);
      Assert.IsTrue(MS.Size > 500);
    finally
      MS.Free;
    end;
  finally
    Doc.Free;
  end;
end;

procedure TDOCXExportTests.Test_AddTable;
var
  Doc: TDOCXDocument;
  MS: TMemoryStream;
begin
  Doc := TDOCXDocument.Create;
  try
    Doc.AddTable(
      ['Name', 'Age', 'City'],
      [['Alice', '30', 'Beijing'], ['Bob', '25', 'Shanghai']],
      [4.0, 2.0, 4.0]);
    MS := TMemoryStream.Create;
    try
      Doc.SaveToStream(MS);
      Assert.IsTrue(MS.Size > 500, 'DOCX with table should be substantial');
    finally
      MS.Free;
    end;
  finally
    Doc.Free;
  end;
end;

procedure TDOCXExportTests.Test_SaveToStream;
var
  Doc: TDOCXDocument;
  MS: TMemoryStream;
begin
  Doc := TDOCXDocument.Create;
  try
    Doc.AddParagraph('Test paragraph');
    MS := TMemoryStream.Create;
    try
      Doc.SaveToStream(MS);
      Assert.IsTrue(MS.Size > 0);
      MS.Position := 0;
      Assert.AreEqual(Byte($50), PByte(MS.Memory)^);
    finally
      MS.Free;
    end;
  finally
    Doc.Free;
  end;
end;

{ TShareTests }

procedure TShareTests.Test_CopyToClipboard;
begin
  Assert.IsTrue(TUniShare.CopyToClipboard('DeepBase test clipboard content'),
    'CopyToClipboard should succeed on Windows');
end;

procedure TShareTests.Test_GetPicturesFolder;
var
  Dir: string;
begin
  Dir := TUniShare.GetPicturesFolder;
  Assert.IsTrue(Dir.Length > 0, 'Pictures folder should not be empty');
  Assert.Contains(Dir, 'DeepBase');
end;

procedure TShareTests.Test_GetTempSharePath;
var
  P: string;
begin
  P := TUniShare.GetTempSharePath('test.txt');
  Assert.IsTrue(P.Length > 0);
  Assert.Contains(P, 'test.txt');
end;

initialization
  TDUnitX.RegisterTestFixture(TPDFExportTests);
  TDUnitX.RegisterTestFixture(TDOCXExportTests);
  TDUnitX.RegisterTestFixture(TShareTests);

end.
