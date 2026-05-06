{==============================================================================
  UniBase.Export.DOCX - OOXML Document Generator

  Generates valid DOCX (Office Open XML) files using System.Zip and
  hand-crafted XML.  No Microsoft Office dependency required.

  Supports paragraphs, tables, bold/italic, font/size control, and
  JPEG image embedding.

  Usage:
    var Doc := TDOCXDocument.Create;
    Doc.AddParagraph('Hello World', 16, True);
    Doc.AddTable(['Name', 'Age'], [['Alice', '30'], ['Bob', '25']]);
    Doc.SaveToFile('output.docx');
    Doc.Free;
==============================================================================}

unit UniBase.Export.DOCX;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Zip,
  System.Generics.Collections;

type
  TDOCXAlign = (daLeft, daCenter, daRight);

  TDOCXDocument = class
  private
    type
      TParagraphRun = record
        Text: string;
        Bold: Boolean;
        Italic: Boolean;
        FontName: string;
        FontSize: Double;
        FontColor: string;   // hex RRGGBB
      end;

      TParagraph = record
        Runs: TArray<TParagraphRun>;
        Align: TDOCXAlign;
        SpacingBefore: Double;
        SpacingAfter: Double;
      end;

      TTableCol = record
        Header: string;
        Width: Double;     // cm
      end;

      TTable = record
        Columns: TArray<TTableCol>;
        Rows: TArray<TArray<string>>;
        HeaderColor: string; // hex RRGGBB
      end;

      TImageRef = record
        RelId: string;    // rIdN
        FileName: string; // image1.jpeg
        WidthCm: Double;
        HeightCm: Double;
        Data: TBytes;
      end;

    var
      FParagraphs: TList<TParagraph>;
      FTables: TList<TTable>;
      FImages: TList<TImageRef>;
      FDefaultFont: string;
      FDefaultSize: Double;
      FImageCounter: Integer;
      FRelCounter: Integer;

    function NextRelId: string;
    function EscapeXML(const AText: string): string;
    function BuildContentTypes: string;
    function BuildRels: string;
    function BuildDocument: string;
    function BuildDocRels: string;
    function BuildStyles: string;
    procedure AddImageToZip(AZip: TZipFile; const AImg: TImageRef);
  public
    constructor Create;
    destructor Destroy; override;

    procedure SetDefaultFont(const AName: string; ASize: Double);

    procedure AddParagraph(const AText: string; AFontSize: Double = 0;
      ABold: Boolean = False; AItalic: Boolean = False;
      AAlign: TDOCXAlign = daLeft);
    procedure AddParagraphRuns(const ARuns: TArray<string>;
      const ABoldFlags: TArray<Boolean>; AFontSize: Double = 0;
      AAlign: TDOCXAlign = daLeft);
    procedure AddTable(const AHeaders: TArray<string>;
      const ARows: TArray<TArray<string>>;
      const AColWidths: TArray<Double> = nil;
      const AHeaderColor: string = '4472C4');
    procedure AddImage(const AFileName: string; AWidthCm, AHeightCm: Double); overload;
    procedure AddImage(AStream: TStream; AWidthCm, AHeightCm: Double;
      const AMimeHint: string = 'image/jpeg'); overload;

    procedure AddSpacing(ABeforePt, AAfterPt: Double);

    procedure SaveToStream(AStream: TStream);
    procedure SaveToFile(const AFileName: string);
  end;

implementation

uses
  System.IOUtils;

{ TDOCXDocument }

constructor TDOCXDocument.Create;
begin
  inherited Create;
  FParagraphs := TList<TParagraph>.Create;
  FTables := TList<TTable>.Create;
  FImages := TList<TImageRef>.Create;
  FDefaultFont := '';
  FDefaultSize := 11;
  FImageCounter := 0;
  FRelCounter := 0;
end;

destructor TDOCXDocument.Destroy;
begin
  FreeAndNil(FParagraphs);
  FreeAndNil(FTables);
  FreeAndNil(FImages);
  inherited;
end;

function TDOCXDocument.NextRelId: string;
begin
  Inc(FRelCounter);
  Result := 'rId' + IntToStr(FRelCounter);
end;

function TDOCXDocument.EscapeXML(const AText: string): string;
begin
  Result := AText;
  Result := Result.Replace('&', '&amp;');
  Result := Result.Replace('<', '&lt;');
  Result := Result.Replace('>', '&gt;');
  Result := Result.Replace('"', '&quot;');
  Result := Result.Replace('''', '&apos;');
end;

procedure TDOCXDocument.SetDefaultFont(const AName: string; ASize: Double);
begin
  FDefaultFont := AName;
  FDefaultSize := ASize;
end;

procedure TDOCXDocument.AddParagraph(const AText: string;
  AFontSize: Double; ABold, AItalic: Boolean; AAlign: TDOCXAlign);
var
  P: TParagraph;
  R: TParagraphRun;
begin
  R := Default(TParagraphRun);
  R.Text := AText;
  R.Bold := ABold;
  R.Italic := AItalic;
  R.FontName := FDefaultFont;
  R.FontSize := AFontSize;
  R.FontColor := '';

  P := Default(TParagraph);
  P.Runs := [R];
  P.Align := AAlign;
  P.SpacingBefore := 0;
  P.SpacingAfter := 0;
  FParagraphs.Add(P);
end;

procedure TDOCXDocument.AddParagraphRuns(const ARuns: TArray<string>;
  const ABoldFlags: TArray<Boolean>; AFontSize: Double;
  AAlign: TDOCXAlign);
var
  P: TParagraph;
  R: TParagraphRun;
  I: Integer;
begin
  P := Default(TParagraph);
  P.Align := AAlign;
  P.SpacingBefore := 0;
  P.SpacingAfter := 0;
  for I := 0 to High(ARuns) do
  begin
    R := Default(TParagraphRun);
    R.Text := ARuns[I];
    R.Bold := (I <= High(ABoldFlags)) and ABoldFlags[I];
    R.Italic := False;
    R.FontName := FDefaultFont;
    R.FontSize := AFontSize;
    R.FontColor := '';
    P.Runs := P.Runs + [R];
  end;
  FParagraphs.Add(P);
end;

procedure TDOCXDocument.AddTable(const AHeaders: TArray<string>;
  const ARows: TArray<TArray<string>>;
  const AColWidths: TArray<Double>; const AHeaderColor: string);
var
  T: TTable;
  I: Integer;
begin
  T := Default(TTable);
  SetLength(T.Columns, Length(AHeaders));
  for I := 0 to High(AHeaders) do
  begin
    T.Columns[I].Header := AHeaders[I];
    if I <= High(AColWidths) then
      T.Columns[I].Width := AColWidths[I]
    else
      T.Columns[I].Width := 3.0;
  end;
  T.Rows := Copy(ARows);
  T.HeaderColor := AHeaderColor;
  FTables.Add(T);
end;

procedure TDOCXDocument.AddImage(const AFileName: string;
  AWidthCm, AHeightCm: Double);
var
  S: TFileStream;
begin
  S := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    AddImage(S, AWidthCm, AHeightCm);
  finally
    S.Free;
  end;
end;

procedure TDOCXDocument.AddImage(AStream: TStream; AWidthCm, AHeightCm: Double;
  const AMimeHint: string);
var
  Img: TImageRef;
begin
  Inc(FImageCounter);
  Img.RelId := NextRelId;
  Img.FileName := 'image' + IntToStr(FImageCounter) + '.jpeg';
  Img.WidthCm := AWidthCm;
  Img.HeightCm := AHeightCm;
  SetLength(Img.Data, AStream.Size - AStream.Position);
  AStream.ReadBuffer(Img.Data, Length(Img.Data));
  FImages.Add(Img);
end;

procedure TDOCXDocument.AddSpacing(ABeforePt, AAfterPt: Double);
var
  P: TParagraph;
  R: TParagraphRun;
begin
  R := Default(TParagraphRun);
  R.Text := '';
  P := Default(TParagraph);
  P.Runs := [R];
  P.Align := daLeft;
  P.SpacingBefore := ABeforePt;
  P.SpacingAfter := AAfterPt;
  FParagraphs.Add(P);
end;

function TDOCXDocument.BuildContentTypes: string;
begin
  Result :=
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'#10 +
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'#10 +
    '  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'#10 +
    '  <Default Extension="xml" ContentType="application/xml"/>'#10 +
    '  <Default Extension="jpeg" ContentType="image/jpeg"/>'#10 +
    '  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'#10 +
    '  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'#10 +
    '</Types>';
end;

function TDOCXDocument.BuildRels: string;
begin
  Result :=
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'#10 +
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'#10 +
    '  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'#10 +
    '</Relationships>';
end;

function TDOCXDocument.BuildStyles: string;
begin
  Result :=
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'#10 +
    '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'#10 +
    '  <w:docDefaults>'#10 +
    '    <w:rPrDefault><w:rPr><w:sz w:val="22"/></w:rPr></w:rPrDefault>'#10 +
    '  </w:docDefaults>'#10 +
    '</w:styles>';
end;

function TDOCXDocument.BuildDocRels: string;
var
  SB: TStringBuilder;
  I: Integer;
begin
  SB := TStringBuilder.Create;
  try
    SB.Append('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'#10);
    SB.Append('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'#10);
    SB.Append('  <Relationship Id="rIdStyles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'#10);
    for I := 0 to FImages.Count - 1 do
      SB.AppendFormat(
        '  <Relationship Id="%s" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/%s"/>'#10,
        [FImages[I].RelId, FImages[I].FileName]);
    SB.Append('</Relationships>');
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TDOCXDocument.BuildDocument: string;
var
  SB: TStringBuilder;
  I, J: Integer;
  P: TParagraph;
  T: TTable;
  AlignStr, SpacingAttr: string;
  Cols, Rows: Integer;
  PicRelId: string;

  procedure WriteRun(const ARun: TParagraphRun);
  var
    SizeVal: Integer;
  begin
    SB.Append('<w:r>');
    if ARun.Bold or ARun.Italic or (ARun.FontName <> '') or
       (ARun.FontSize > 0) or (ARun.FontColor <> '') then
    begin
      SB.Append('<w:rPr>');
      if ARun.Bold then
        SB.Append('<w:b/>');
      if ARun.Italic then
        SB.Append('<w:i/>');
      if ARun.FontName <> '' then
        SB.AppendFormat('<w:rFonts w:ascii="%s" w:eastAsia="%s" w:hAnsi="%s"/>',
          [ARun.FontName, ARun.FontName, ARun.FontName]);
      if ARun.FontSize > 0 then
      begin
        SizeVal := Round(ARun.FontSize * 2);
        SB.AppendFormat('<w:sz w:val="%d"/><w:szCs w:val="%d"/>', [SizeVal, SizeVal]);
      end;
      if ARun.FontColor <> '' then
        SB.AppendFormat('<w:color w:val="%s"/>', [ARun.FontColor]);
      SB.Append('</w:rPr>');
    end;
    SB.AppendFormat('<w:t xml:space="preserve">%s</w:t>', [EscapeXML(ARun.Text)]);
    SB.Append('</w:r>');
  end;

begin
  SB := TStringBuilder.Create(8192);
  try
    SB.Append('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'#10);
    SB.Append('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '#10);
    SB.Append('  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '#10);
    SB.Append('  xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '#10);
    SB.Append('  xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '#10);
    SB.Append('  xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'#10);
    SB.Append('<w:body>'#10);

    // Paragraphs
    for I := 0 to FParagraphs.Count - 1 do
    begin
      P := FParagraphs[I];
      SB.Append('<w:p>');
      SB.Append('<w:pPr>');
      case P.Align of
        daCenter: AlignStr := '<w:jc w:val="center"/>';
        daRight:  AlignStr := '<w:jc w:val="right"/>';
      else
        AlignStr := '';
      end;
      SB.Append(AlignStr);
      if (P.SpacingBefore > 0) or (P.SpacingAfter > 0) then
        SB.AppendFormat('<w:spacing w:before="%d" w:after="%d"/>',
          [Round(P.SpacingBefore * 20), Round(P.SpacingAfter * 20)]);
      SB.Append('</w:pPr>');
      for J := 0 to High(P.Runs) do
        WriteRun(P.Runs[J]);
      SB.Append('</w:p>'#10);
    end;

    // Tables
    for I := 0 to FTables.Count - 1 do
    begin
      T := FTables[I];
      Cols := Length(T.Columns);
      Rows := Length(T.Rows);

      SB.AppendFormat('<w:tbl>'#10);
      // Table properties
      SB.Append('<w:tblPr><w:tblBorders>');
      SB.Append('<w:top w:val="single" w:sz="4" w:space="0" w:color="auto"/>');
      SB.Append('<w:left w:val="single" w:sz="4" w:space="0" w:color="auto"/>');
      SB.Append('<w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/>');
      SB.Append('<w:right w:val="single" w:sz="4" w:space="0" w:color="auto"/>');
      SB.Append('<w:insideH w:val="single" w:sz="4" w:space="0" w:color="auto"/>');
      SB.Append('<w:insideV w:val="single" w:sz="4" w:space="0" w:color="auto"/>');
      SB.Append('</w:tblBorders></w:tblPr>'#10);

      // Table grid
      SB.Append('<w:tblGrid>');
      for J := 0 to Cols - 1 do
        SB.AppendFormat('<w:gridCol w:w="%d"/>', [Round(T.Columns[J].Width * 567)]);
      SB.Append('</w:tblGrid>'#10);

      // Header row
      SB.Append('<w:tr>');
      for J := 0 to Cols - 1 do
      begin
        SB.Append('<w:tc>');
        SB.AppendFormat('<w:tcPr><w:shd w:val="clear" w:color="auto" w:fill="%s"/></w:tcPr>',
          [T.HeaderColor]);
        SB.Append('<w:p><w:pPr><w:jc w:val="center"/></w:pPr>');
        SB.AppendFormat('<w:r><w:rPr><w:b/><w:color w:val="FFFFFF"/></w:rPr>');
        SB.AppendFormat('<w:t xml:space="preserve">%s</w:t></w:r></w:p>', [EscapeXML(T.Columns[J].Header)]);
        SB.Append('</w:tc>');
      end;
      SB.Append('</w:tr>'#10);

      // Data rows
      for J := 0 to Rows - 1 do
      begin
        SB.Append('<w:tr>');
        for K := 0 to Min(High(T.Rows[J]), Cols - 1) do
        begin
          SB.Append('<w:tc><w:tcPr/>');
          SB.Append('<w:p>');
          SB.AppendFormat('<w:r><w:t xml:space="preserve">%s</w:t></w:r>', [EscapeXML(T.Rows[J][K])]);
          SB.Append('</w:p></w:tc>');
        end;
        SB.Append('</w:tr>'#10);
      end;
      SB.Append('</w:tbl>'#10);
    end;

    // Images (inline in paragraphs)
    for I := 0 to FImages.Count - 1 do
    begin
      PicRelId := FImages[I].RelId;
      SB.Append('<w:p><w:r><w:drawing>');
      SB.Append('<wp:inline distT="0" distB="0" distL="0" distR="0">');
      SB.AppendFormat('<wp:extent cx="%d" cy="%d"/>',
        [Round(FImages[I].WidthCm * 360000),
         Round(FImages[I].HeightCm * 360000)]);
      SB.Append('<wp:docPr id="' + IntToStr(I + 1) + '" name="Picture ' + IntToStr(I + 1) + '"/>');
      SB.Append('<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">');
      SB.Append('<pic:pic><pic:nvPicPr><pic:cNvPr id="' + IntToStr(I + 1) + '" name="pic"/>');
      SB.Append('<pic:cNvPicPr/></pic:nvPicPr>');
      SB.Append('<pic:blipFill><a:blip r:embed="' + PicRelId + '"/>');
      SB.Append('<a:stretch><a:fillRect/></a:stretch></pic:blipFill>');
      SB.AppendFormat('<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="%d" cy="%d"/></a:xfrm>',
        [Round(FImages[I].WidthCm * 360000),
         Round(FImages[I].HeightCm * 360000)]);
      SB.Append('<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>');
      SB.Append('</pic:pic></a:graphicData></a:graphic>');
      SB.Append('</wp:inline></w:drawing></w:r></w:p>'#10);
    end;

    SB.Append('</w:body>'#10);
    SB.Append('</w:document>');
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

procedure TDOCXDocument.AddImageToZip(AZip: TZipFile;
  const AImg: TImageRef);
var
  MS: TMemoryStream;
begin
  MS := TMemoryStream.Create;
  try
    MS.WriteBuffer(AImg.Data, Length(AImg.Data));
    MS.Position := 0;
    AZip.Add(MS, 'word/media/' + AImg.FileName);
  finally
    MS.Free;
  end;
end;

procedure TDOCXDocument.SaveToStream(AStream: TStream);
var
  Zip: TZipFile;
  DocStream: TMemoryStream;
  I: Integer;
begin
  Zip := TZipFile.Create;
  try
    DocStream := TMemoryStream.Create;
    try
      // [Content_Types].xml
      DocStream.Clear;
      DocStream.WriteBuffer(TEncoding.UTF8.GetBytes(BuildContentTypes),
        Length(TEncoding.UTF8.GetBytes(BuildContentTypes)));
      DocStream.Position := 0;
      Zip.Add(DocStream, '[Content_Types].xml');

      // _rels/.rels
      DocStream.Clear;
      DocStream.WriteBuffer(TEncoding.UTF8.GetBytes(BuildRels),
        Length(TEncoding.UTF8.GetBytes(BuildRels)));
      DocStream.Position := 0;
      Zip.Add(DocStream, '_rels/.rels');

      // word/document.xml
      DocStream.Clear;
      DocStream.WriteBuffer(TEncoding.UTF8.GetBytes(BuildDocument),
        Length(TEncoding.UTF8.GetBytes(BuildDocument)));
      DocStream.Position := 0;
      Zip.Add(DocStream, 'word/document.xml');

      // word/_rels/document.xml.rels
      DocStream.Clear;
      DocStream.WriteBuffer(TEncoding.UTF8.GetBytes(BuildDocRels),
        Length(TEncoding.UTF8.GetBytes(BuildDocRels)));
      DocStream.Position := 0;
      Zip.Add(DocStream, 'word/_rels/document.xml.rels');

      // word/styles.xml
      DocStream.Clear;
      DocStream.WriteBuffer(TEncoding.UTF8.GetBytes(BuildStyles),
        Length(TEncoding.UTF8.GetBytes(BuildStyles)));
      DocStream.Position := 0;
      Zip.Add(DocStream, 'word/styles.xml');

      // Images
      for I := 0 to FImages.Count - 1 do
        AddImageToZip(Zip, FImages[I]);

      Zip.SaveToStream(AStream);
    finally
      DocStream.Free;
    end;
  finally
    Zip.Free;
  end;
end;

procedure TDOCXDocument.SaveToFile(const AFileName: string);
var
  S: TFileStream;
begin
  S := TFileStream.Create(AFileName, fmCreate);
  try
    SaveToStream(S);
  finally
    S.Free;
  end;
end;

end.
