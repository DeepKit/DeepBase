{==============================================================================
  UniBase.Export.PDF - Pure Object Pascal PDF Stream Writer

  Generates valid PDF 1.4 documents without third-party dependencies.
  Supports text (ASCII + CJK), tables, lines, rectangles, and JPEG images.

  Uses composite Type0 font with Identity-H encoding so a single font
  handles both Western and CJK characters.  Reference font defaults to
  SimSun (always available on Chinese Windows).  Override via SetFont.

  Coordinate system: top-left origin (Y increases downward), converted
  internally to PDF's bottom-left origin.

  Usage:
    var PDF := TPDFDocument.Create;
    PDF.AddPage;
    PDF.SetFont('SimSun', 16);
    PDF.DrawText(50, 50, 'Hello / 你好');
    PDF.SaveToFile('output.pdf');
    PDF.Free;
==============================================================================}

unit UniBase.Export.PDF;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Math,
  System.Generics.Collections;

type
  TPDFTextAlign = (paLeft, paCenter, paRight);

  TPDFColor = record
    R, G, B: Double;
    class function RGB(R, G, B: Byte): TPDFColor; static;
    class function Black: TPDFColor; static;
    class function White: TPDFColor; static;
    class function Gray(V: Byte): TPDFColor; static;
    class function DarkGray: TPDFColor; static;
    class function LightGray: TPDFColor; static;
    class function Blue: TPDFColor; static;
    class function Red: TPDFColor; static;
  end;

  TPDFColumnDef = record
    Title: string;
    Width: Double;
    Align: TPDFTextAlign;
    constructor Create(const ATitle: string; AWidth: Double;
      AAlign: TPDFTextAlign = paLeft);
  end;

  TPDFDocument = class
  private
    type
      TFontEntry = record
        Name: string;
        Size: Double;
        Key: string;
        ObjNum: Integer;
      end;

      TImageEntry = record
        ObjNum: Integer;
        Width: Integer;
        Height: Integer;
        Data: TBytes;
      end;

      TPageRec = record
        PageObjNum: Integer;
        ContentObjNum: Integer;
        Content: TStringBuilder;
        FontKeys: TList<string>;
        ImageRefs: TList<string>;
      end;

    var
      FPageWidth: Double;
      FPageHeight: Double;
      FMrgLeft, FMrgRight, FMrgTop, FMrgBottom: Double;
      FFontName: string;
      FFontSize: Double;
      FFill: TPDFColor;
      FStroke: TPDFColor;
      FLineW: Double;
      FPages: TList<TPageRec>;
      FFonts: TList<TFontEntry>;
      FImages: TList<TImageEntry>;
      FObjNum: Integer;

    function NextObj: Integer;
    function FindOrAddFont(const AName: string; ASize: Double): string;
    function AddImageObj(AW, AH: Integer; const AData: TBytes): string;
    function PDFY(Y: Double): Double;
    function HexEncode(const AText: string): string;
    function CharW(C: Char): Double;
    function MeasureText(const AText: string): Double;
    class procedure ParseJPGDim(const AData: TBytes; out AW, AH: Integer); static;
    procedure WriteObj(ALines: TStrings; ANum: Integer; const ABody: string); overload;
    procedure WriteStreamObj(ALines: TStrings; ANum: Integer;
      const AStreamData: string); overload;
  public
    constructor Create;
    destructor Destroy; override;

    procedure SetPageSize(AW, AH: Double);
    procedure SetMargins(AL, AT, AR, AB: Double);
    procedure SetFont(const AName: string; ASize: Double);
    procedure SetFillColor(const AColor: TPDFColor);
    procedure SetStrokeColor(const AColor: TPDFColor);
    procedure SetLineWidth(AW: Double);

    function AddPage: Integer;

    procedure DrawText(X, Y: Double; const AText: string);
    procedure DrawTextAligned(X, Y, AW: Double; const AText: string;
      AAlign: TPDFTextAlign);
    function DrawTextBlock(X, Y, MaxW: Double; const AText: string;
      ALineH: Double = 0): Double;
    procedure DrawLine(X1, Y1, X2, Y2: Double);
    procedure DrawRect(X, Y, AW, AH: Double; AFill: Boolean = False;
      AStroke: Boolean = True);
    procedure DrawImageJPEG(X, Y, AW, AH: Double; const AFileName: string); overload;
    procedure DrawImageJPEG(X, Y, AW, AH: Double; AStream: TStream); overload;
    procedure DrawTable(X, Y: Double; const ACols: TArray<TPDFColumnDef>;
      const ARows: TArray<TArray<string>>; AHeaderColor: TPDFColor);

    procedure SaveToStream(AStream: TStream);
    procedure SaveToFile(const AFileName: string);

    property PageW: Double read FPageWidth;
    property PageH: Double read FPageHeight;
    property MrgLeft: Double read FMrgLeft;
    property MrgRight: Double read FMrgRight;
    property MrgTop: Double read FMrgTop;
    property MrgBottom: Double read FMrgBottom;
  end;

implementation

uses
  System.IOUtils;

{ TPDFColor }

class function TPDFColor.RGB(R, G, B: Byte): TPDFColor;
begin
  Result.R := R / 255;
  Result.G := G / 255;
  Result.B := B / 255;
end;

class function TPDFColor.Black: TPDFColor;
begin
  Result := RGB(0, 0, 0);
end;

class function TPDFColor.White: TPDFColor;
begin
  Result := RGB(255, 255, 255);
end;

class function TPDFColor.Gray(V: Byte): TPDFColor;
begin
  Result := RGB(V, V, V);
end;

class function TPDFColor.DarkGray: TPDFColor;
begin
  Result := RGB(64, 64, 64);
end;

class function TPDFColor.LightGray: TPDFColor;
begin
  Result := RGB(230, 230, 230);
end;

class function TPDFColor.Blue: TPDFColor;
begin
  Result := RGB(41, 98, 255);
end;

class function TPDFColor.Red: TPDFColor;
begin
  Result := RGB(220, 53, 69);
end;

{ TPDFColumnDef }

constructor TPDFColumnDef.Create(const ATitle: string; AWidth: Double;
  AAlign: TPDFTextAlign);
begin
  Title := ATitle;
  Width := AWidth;
  Align := AAlign;
end;

{ TPDFDocument }

constructor TPDFDocument.Create;
begin
  inherited Create;
  FPageWidth := 595.28;
  FPageHeight := 841.89;
  FMrgLeft := 50;
  FMrgRight := 50;
  FMrgTop := 50;
  FMrgBottom := 50;
  FFontName := 'SimSun';
  FFontSize := 12;
  FFill := TPDFColor.Black;
  FStroke := TPDFColor.Black;
  FLineW := 0.5;
  FPages := TList<TPageRec>.Create;
  FFonts := TList<TFontEntry>.Create;
  FImages := TList<TImageEntry>.Create;
  FObjNum := 0;
end;

destructor TPDFDocument.Destroy;
var
  I: Integer;
begin
  for I := 0 to FPages.Count - 1 do
  begin
    FPages[I].Content.Free;
    FPages[I].FontKeys.Free;
    FPages[I].ImageRefs.Free;
  end;
  FreeAndNil(FPages);
  FreeAndNil(FFonts);
  FreeAndNil(FImages);
  inherited;
end;

function TPDFDocument.NextObj: Integer;
begin
  Inc(FObjNum);
  Result := FObjNum;
end;

procedure TPDFDocument.SetPageSize(AW, AH: Double);
begin
  FPageWidth := AW;
  FPageHeight := AH;
end;

procedure TPDFDocument.SetMargins(AL, AT, AR, AB: Double);
begin
  FMrgLeft := AL;
  FMrgTop := AT;
  FMrgRight := AR;
  FMrgBottom := AB;
end;

procedure TPDFDocument.SetFont(const AName: string; ASize: Double);
begin
  FFontName := AName;
  FFontSize := ASize;
end;

procedure TPDFDocument.SetFillColor(const AColor: TPDFColor);
begin
  FFill := AColor;
end;

procedure TPDFDocument.SetStrokeColor(const AColor: TPDFColor);
begin
  FStroke := AColor;
end;

procedure TPDFDocument.SetLineWidth(AW: Double);
begin
  FLineW := AW;
end;

function TPDFDocument.PDFY(Y: Double): Double;
begin
  Result := FPageHeight - Y;
end;

function TPDFDocument.HexEncode(const AText: string): string;
var
  SB: TStringBuilder;
  I: Integer;
  C: Char;
begin
  SB := TStringBuilder.Create(Length(AText) * 4);
  try
    for I := 1 to Length(AText) do
    begin
      C := AText[I];
      if Ord(C) > $FFFF then
        Continue;
      SB.AppendFormat('%4.4X', [Ord(C)]);
    end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TPDFDocument.CharW(C: Char): Double;
begin
  if Ord(C) > $007F then
    Result := FFontSize
  else if CharInSet(C, ['A'..'Z']) then
    Result := FFontSize * 0.65
  else if CharInSet(C, ['a'..'z']) then
    Result := FFontSize * 0.55
  else if CharInSet(C, ['0'..'9']) then
    Result := FFontSize * 0.55
  else
    Result := FFontSize * 0.4;
end;

function TPDFDocument.MeasureText(const AText: string): Double;
var
  I: Integer;
begin
  Result := 0;
  for I := 1 to Length(AText) do
    Result := Result + CharW(AText[I]);
end;

function TPDFDocument.FindOrAddFont(const AName: string;
  ASize: Double): string;
var
  FKey, FId: string;
  E: TFontEntry;
  I: Integer;
begin
  FKey := AName + '|' + FloatToStr(ASize);
  for I := 0 to FFonts.Count - 1 do
    if FFonts[I].Key = FKey then
    begin
      FId := 'F' + IntToStr(FFonts[I].ObjNum);
      if FPages.Count > 0 then
        if not FPages[FPages.Count - 1].FontKeys.Contains(FId) then
          FPages[FPages.Count - 1].FontKeys.Add(FId);
      Exit(FId);
    end;

  E.Name := AName;
  E.Size := ASize;
  E.Key := FKey;
  E.ObjNum := NextObj;
  FFonts.Add(E);
  FId := 'F' + IntToStr(E.ObjNum);
  if FPages.Count > 0 then
    FPages[FPages.Count - 1].FontKeys.Add(FId);
  Result := FId;
end;

function TPDFDocument.AddImageObj(AW, AH: Integer;
  const AData: TBytes): string;
var
  E: TImageEntry;
begin
  E.ObjNum := NextObj;
  E.Width := AW;
  E.Height := AH;
  E.Data := Copy(AData, 0, Length(AData));
  FImages.Add(E);
  Result := 'Img' + IntToStr(E.ObjNum);
end;

function TPDFDocument.AddPage: Integer;
var
  P: TPageRec;
begin
  P.PageObjNum := NextObj;
  P.ContentObjNum := NextObj;
  P.Content := TStringBuilder.Create(4096);
  P.FontKeys := TList<string>.Create;
  P.ImageRefs := TList<string>.Create;
  Result := FPages.Add(P);
end;

procedure TPDFDocument.DrawText(X, Y: Double; const AText: string);
var
  FId: string;
  C: TStringBuilder;
begin
  if FPages.Count = 0 then
    raise EInvalidOperation.Create('Add a page before drawing');
  C := FPages[FPages.Count - 1].Content;

  FId := FindOrAddFont(FFontName, FFontSize);
  C.Append('BT'#10);
  C.AppendFormat('/%s %.1f Tf'#10, [FId, FFontSize]);
  C.AppendFormat('%.4f %.4f %.4f rg'#10, [FFill.R, FFill.G, FFill.B]);
  C.AppendFormat('%.2f %.2f Td'#10, [X, PDFY(Y)]);
  C.Append('<' + HexEncode(AText) + '> Tj'#10);
  C.Append('ET'#10);
end;

procedure TPDFDocument.DrawTextAligned(X, Y, AW: Double;
  const AText: string; AAlign: TPDFTextAlign);
var
  TW, DX: Double;
begin
  TW := MeasureText(AText);
  case AAlign of
    paLeft:   DX := 0;
    paCenter: DX := (AW - TW) / 2;
    paRight:  DX := AW - TW;
  else
    DX := 0;
  end;
  DrawText(X + DX, Y, AText);
end;

function TPDFDocument.DrawTextBlock(X, Y, MaxW: Double;
  const AText: string; ALineH: Double): Double;
var
  Lines: TArray<string>;
  CurLine: string;
  CurW, CW: Double;
  I, J: Integer;
  Ch: Char;

  procedure Flush;
  begin
    if CurLine <> '' then
    begin
      Lines := Lines + [CurLine];
      CurLine := '';
    end;
    CurW := 0;
  end;

begin
  if ALineH <= 0 then
    ALineH := FFontSize * 1.5;

  CurLine := '';
  CurW := 0;
  for J := 1 to Length(AText) do
  begin
    Ch := AText[J];
    if Ch = #13 then
      Continue;
    if Ch = #10 then
    begin
      Flush;
      Continue;
    end;
    CW := CharW(Ch);
    if (CurW + CW > MaxW) and (CurLine <> '') then
    begin
      Lines := Lines + [CurLine];
      CurLine := Ch;
      CurW := CW;
    end
    else
    begin
      CurLine := CurLine + Ch;
      CurW := CurW + CW;
    end;
  end;
  Flush;

  for I := 0 to High(Lines) do
    DrawText(X, Y + I * ALineH, Lines[I]);

  Result := Length(Lines) * ALineH;
end;

procedure TPDFDocument.DrawLine(X1, Y1, X2, Y2: Double);
var
  C: TStringBuilder;
begin
  if FPages.Count = 0 then Exit;
  C := FPages[FPages.Count - 1].Content;

  C.AppendFormat('%.4f %.4f %.4f RG'#10, [FStroke.R, FStroke.G, FStroke.B]);
  C.AppendFormat('%.2f w'#10, [FLineW]);
  C.AppendFormat('%.2f %.2f m'#10, [X1, PDFY(Y1)]);
  C.AppendFormat('%.2f %.2f l'#10, [X2, PDFY(Y2)]);
  C.Append('S'#10);
end;

procedure TPDFDocument.DrawRect(X, Y, AW, AH: Double;
  AFill, AStroke: Boolean);
var
  C: TStringBuilder;
begin
  if FPages.Count = 0 then Exit;
  C := FPages[FPages.Count - 1].Content;

  C.AppendFormat('%.4f %.4f %.4f rg'#10, [FFill.R, FFill.G, FFill.B]);
  C.AppendFormat('%.4f %.4f %.4f RG'#10, [FStroke.R, FStroke.G, FStroke.B]);
  C.AppendFormat('%.2f w'#10, [FLineW]);
  C.AppendFormat('%.2f %.2f %.2f %.2f re'#10,
    [X, PDFY(Y + AH), AW, AH]);

  if AFill and AStroke then
    C.Append('B'#10)
  else if AFill then
    C.Append('f'#10)
  else
    C.Append('S'#10);
end;

class procedure TPDFDocument.ParseJPGDim(const AData: TBytes;
  out AW, AH: Integer);
var
  I: Integer;
  B: Byte;
begin
  AW := 100;
  AH := 100;
  I := 0;
  while I < Length(AData) - 1 do
  begin
    if AData[I] <> $FF then
    begin
      Inc(I);
      Continue;
    end;
    B := AData[I + 1];
    if (B = $C0) or (B = $C1) or (B = $C2) then
    begin
      if I + 8 < Length(AData) then
      begin
        AH := AData[I + 5] shl 8 or AData[I + 6];
        AW := AData[I + 7] shl 8 or AData[I + 8];
      end;
      Exit;
    end;
    if B = $D9 then
      Exit;
    if B = $DA then
      Exit;
    if (B >= $D0) and (B <= $D8) then
      Inc(I, 2)
    else if I + 3 < Length(AData) then
      Inc(I, 2 + AData[I + 2] shl 8 + AData[I + 3])
    else
      Inc(I, 2);
  end;
end;

procedure TPDFDocument.DrawImageJPEG(X, Y, AW, AH: Double;
  const AFileName: string);
var
  S: TFileStream;
begin
  S := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    DrawImageJPEG(X, Y, AW, AH, S);
  finally
    S.Free;
  end;
end;

procedure TPDFDocument.DrawImageJPEG(X, Y, AW, AH: Double;
  AStream: TStream);
var
  C: TStringBuilder;
  ImgKey: string;
  Data: TBytes;
  ImgW, ImgH: Integer;
begin
  if FPages.Count = 0 then Exit;
  C := FPages[FPages.Count - 1].Content;

  SetLength(Data, AStream.Size - AStream.Position);
  AStream.ReadBuffer(Data, Length(Data));

  ParseJPGDim(Data, ImgW, ImgH);
  ImgKey := AddImageObj(ImgW, ImgH, Data);

  C.Append('q'#10);
  C.AppendFormat('%.2f 0 0 %.2f %.2f %.2f cm'#10,
    [AW, AH, X, PDFY(Y + AH)]);
  C.AppendFormat('/%s Do'#10, [ImgKey]);
  C.Append('Q'#10);

  if not FPages[FPages.Count - 1].ImageRefs.Contains(ImgKey) then
    FPages[FPages.Count - 1].ImageRefs.Add(ImgKey);
end;

procedure TPDFDocument.DrawTable(X, Y: Double;
  const ACols: TArray<TPDFColumnDef>;
  const ARows: TArray<TArray<string>>; AHeaderColor: TPDFColor);
var
  C: TStringBuilder;
  RowH, CurY: Double;
  ColX: Double;
  I, J: Integer;
  SavedFont: string;
  SavedSize: Double;
  SavedFill: TPDFColor;

  procedure HLine(AX, AYY, AW: Double);
  begin
    C.AppendFormat('%.4f %.4f %.4f RG'#10, [FStroke.R, FStroke.G, FStroke.B]);
    C.AppendFormat('%.2f w'#10, [FLineW]);
    C.AppendFormat('%.2f %.2f m'#10, [AX, PDFY(AYY)]);
    C.AppendFormat('%.2f %.2f l'#10, [AX + AW, PDFY(AYY)]);
    C.Append('S'#10);
  end;

  procedure Cell(AX, AYY, AW: Double; const AText: string;
    AAlign: TPDFTextAlign; AFillRow: Boolean);
  var
    TW, DX: Double;
  begin
    if AFillRow then
    begin
      C.AppendFormat('%.4f %.4f %.4f rg'#10,
        [AHeaderColor.R, AHeaderColor.G, AHeaderColor.B]);
      C.AppendFormat('%.2f %.2f %.2f %.2f re f'#10,
        [AX, PDFY(AYY + RowH), AW, RowH]);
    end;
    TW := MeasureText(AText);
    case AAlign of
      paLeft:   DX := 4;
      paCenter: DX := (AW - TW) / 2;
      paRight:  DX := AW - TW - 4;
    else
      DX := 4;
    end;
    if AFillRow then
      C.AppendFormat('%.4f %.4f %.4f rg'#10, [1.0, 1.0, 1.0])
    else
      C.AppendFormat('%.4f %.4f %.4f rg'#10, [FFill.R, FFill.G, FFill.B]);
    C.Append('BT'#10);
    C.AppendFormat('/%s %.1f Tf'#10, [FindOrAddFont(FFontName, FFontSize), FFontSize]);
    C.AppendFormat('%.2f %.2f Td'#10, [AX + DX, PDFY(AYY + RowH) + 2]);
    C.Append('<' + HexEncode(AText) + '> Tj'#10);
    C.Append('ET'#10);
  end;

var
  TotalW: Double;
begin
  if FPages.Count = 0 then Exit;
  if Length(ACols) = 0 then Exit;
  C := FPages[FPages.Count - 1].Content;

  SavedFont := FFontName;
  SavedSize := FFontSize;
  SavedFill := FFill;

  RowH := FFontSize * 1.8;
  TotalW := 0;
  for I := 0 to High(ACols) do
    TotalW := TotalW + ACols[I].Width;

  CurY := Y;

  // Top border
  HLine(X, CurY, TotalW);

  // Header row
  ColX := X;
  for J := 0 to High(ACols) do
  begin
    Cell(ColX, CurY, ACols[J].Width, ACols[J].Title, paCenter, True);
    ColX := ColX + ACols[J].Width;
  end;
  CurY := CurY + RowH;
  HLine(X, CurY, TotalW);

  // Data rows
  for I := 0 to High(ARows) do
  begin
    ColX := X;
    for J := 0 to Min(High(ARows[I]), High(ACols)) do
    begin
      Cell(ColX, CurY, ACols[J].Width, ARows[I][J], ACols[J].Align, False);
      ColX := ColX + ACols[J].Width;
    end;
    CurY := CurY + RowH;
    HLine(X, CurY, TotalW);
  end

  // Vertical lines
  C.AppendFormat('%.4f %.4f %.4f RG'#10, [FStroke.R, FStroke.G, FStroke.B]);
  C.AppendFormat('%.2f w'#10, [FLineW]);
  ColX := X;
  for J := 0 to High(ACols) do
  begin
    C.AppendFormat('%.2f %.2f m'#10, [ColX, PDFY(Y)]);
    C.AppendFormat('%.2f %.2f l'#10, [ColX, PDFY(CurY)]);
    C.Append('S'#10);
    ColX := ColX + ACols[J].Width;
  end;
  C.AppendFormat('%.2f %.2f m'#10, [ColX, PDFY(Y)]);
  C.AppendFormat('%.2f %.2f l'#10, [ColX, PDFY(CurY)]);
  C.Append('S'#10);

  FFontName := SavedFont;
  FFontSize := SavedSize;
  FFill := SavedFill;
end;

{ Save }

procedure TPDFDocument.SaveToStream(AStream: TStream);

  procedure WriteBuf(const AText: string);
  var
    Buf: TBytes;
  begin
    Buf := TEncoding.UTF8.GetBytes(AText);
    AStream.WriteBuffer(Buf, Length(Buf));
  end;

var
  Offsets: TArray<Int64>;
  TotalObjs, I, K: Integer;
  CatObj, PagesObj, CIDObj: Integer;
  PageRefs, FontDict, ImgDict, ContentStr: string;
  ObjNum: Integer;
  ContentBytes: TBytes;
begin
  CatObj := NextObj;
  PagesObj := NextObj;

  TotalObjs := FObjNum;
  // Pre-allocate CIDFont objects: one per font entry
  for I := 0 to FFonts.Count - 1 do
  begin
    CIDObj := NextObj;
    TotalObjs := FObjNum;
  end;
  SetLength(Offsets, TotalObjs + 1);

  // Header
  WriteBuf('%PDF-1.4'#10);
  WriteBuf('%'#226#227#207#211#10);

  // Pages object
  PageRefs := '';
  for I := 0 to FPages.Count - 1 do
  begin
    if I > 0 then
      PageRefs := PageRefs + ' ';
    PageRefs := PageRefs + Format('%d 0 R', [FPages[I].PageObjNum]);
  end;
  Offsets[PagesObj] := AStream.Position;
  WriteBuf(Format('%d 0 obj'#10, [PagesObj]));
  WriteBuf(Format('<< /Type /Pages /Kids [%s] /Count %d >>'#10'endobj'#10,
    [PageRefs, FPages.Count]));

  // Font objects (Type0 + CIDFontType2 companion)
  for I := 0 to FFonts.Count - 1 do
  begin
    ObjNum := FFonts[I].ObjNum;
    Offsets[ObjNum] := AStream.Position;
    WriteBuf(Format('%d 0 obj'#10, [ObjNum]));
    WriteBuf('<< /Type /Font /Subtype /Type0'#10);
    WriteBuf(Format('   /BaseFont /%s'#10, [FFonts[I].Name]));
    WriteBuf('   /Encoding /Identity-H'#10);
    WriteBuf(Format('   /DescendantFonts [%d 0 R]'#10, [ObjNum + 1]));
    WriteBuf('>>'#10'endobj'#10);

    // CIDFont companion uses next sequential number
    Offsets[ObjNum + 1] := AStream.Position;
    WriteBuf(Format('%d 0 obj'#10, [ObjNum + 1]));
    WriteBuf('<< /Type /Font /Subtype /CIDFontType2'#10);
    WriteBuf(Format('   /BaseFont /%s'#10, [FFonts[I].Name]));
    WriteBuf('   /CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) /Supplement 0 >>'#10);
    WriteBuf('>>'#10'endobj'#10);
  end;

  // Image XObjects
  for I := 0 to FImages.Count - 1 do
  begin
    ObjNum := FImages[I].ObjNum;
    Offsets[ObjNum] := AStream.Position;
    WriteBuf(Format('%d 0 obj'#10, [ObjNum]));
    WriteBuf(Format('<< /Type /XObject /Subtype /Image /Width %d /Height %d'#10,
      [FImages[I].Width, FImages[I].Height]));
    WriteBuf('   /ColorSpace /DeviceRGB /BitsPerComponent 8'#10);
    WriteBuf(Format('   /Filter /DCTDecode /Length %d >>'#10'stream'#10,
      [Length(FImages[I].Data)]));
    AStream.WriteBuffer(FImages[I].Data, Length(FImages[I].Data));
    WriteBuf(#10'endstream'#10'endobj'#10);
  end;

  // Content stream objects
  for I := 0 to FPages.Count - 1 do
  begin
    ObjNum := FPages[I].ContentObjNum;
    ContentStr := FPages[I].Content.ToString;
    ContentBytes := TEncoding.UTF8.GetBytes(ContentStr);
    Offsets[ObjNum] := AStream.Position;
    WriteBuf(Format('%d 0 obj'#10'<< /Length %d >>'#10'stream'#10,
      [ObjNum, Length(ContentBytes)]));
    AStream.WriteBuffer(ContentBytes, Length(ContentBytes));
    WriteBuf(#10'endstream'#10'endobj'#10);
  end;

  // Page objects
  for I := 0 to FPages.Count - 1 do
  begin
    ObjNum := FPages[I].PageObjNum;

    FontDict := '';
    for K := 0 to FPages[I].FontKeys.Count - 1 do
    begin
      if K > 0 then
        FontDict := FontDict + ' ';
      FontDict := FontDict + Format('/%s %s 0 R',
        [FPages[I].FontKeys[K],
         Copy(FPages[I].FontKeys[K], 2, MaxInt)]);
    end;

    ImgDict := '';
    for K := 0 to FPages[I].ImageRefs.Count - 1 do
    begin
      if K > 0 then
        ImgDict := ImgDict + ' ';
      ImgDict := ImgDict + Format('/%s %s 0 R',
        [FPages[I].ImageRefs[K],
         Copy(FPages[I].ImageRefs[K], 4, MaxInt)]);
    end;

    Offsets[ObjNum] := AStream.Position;
    WriteBuf(Format('%d 0 obj'#10, [ObjNum]));
    WriteBuf('<< /Type /Page'#10);
    WriteBuf(Format('   /Parent %d 0 R'#10, [PagesObj]));
    WriteBuf(Format('   /MediaBox [0 0 %.2f %.2f]'#10, [FPageWidth, FPageHeight]));
    WriteBuf(Format('   /Contents %d 0 R'#10, [FPages[I].ContentObjNum]));
    WriteBuf('   /Resources << /Font <<');
    if FontDict <> '' then
      WriteBuf(' ' + FontDict);
    WriteBuf(' >>');
    if ImgDict <> '' then
    begin
      WriteBuf(' /XObject <<');
      WriteBuf(' ' + ImgDict);
      WriteBuf(' >>');
    end;
    WriteBuf(' >>'#10'>>'#10'endobj'#10);
  end;

  // Catalog
  Offsets[CatObj] := AStream.Position;
  WriteBuf(Format('%d 0 obj'#10'<< /Type /Catalog /Pages %d 0 R >>'#10'endobj'#10,
    [CatObj, PagesObj]));

  // XRef table
  WriteBuf('xref'#10);
  WriteBuf(Format('0 %d'#10, [TotalObjs + 1]));
  WriteBuf('0000000000 65535 f '#10);
  for I := 1 to TotalObjs do
  begin
    if Offsets[I] > 0 then
      WriteBuf(Format('%.10d 00000 n '#10, [Offsets[I]]))
    else
      WriteBuf('0000000000 00000 f '#10);
  end;

  // Trailer
  WriteBuf('trailer'#10);
  WriteBuf(Format('<< /Size %d /Root %d 0 R >>'#10, [TotalObjs + 1, CatObj]));
  WriteBuf('startxref'#10);
  WriteBuf(IntToStr(AStream.Position) + #10);
  WriteBuf('%%EOF'#10);
end;

procedure TPDFDocument.SaveToFile(const AFileName: string);
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

{ Unused helpers - required by interface declaration }

procedure TPDFDocument.WriteObj(ALines: TStrings; ANum: Integer;
  const ABody: string);
begin
  ALines.Add(Format('%d 0 obj', [ANum]));
  ALines.Add(ABody);
  ALines.Add('endobj');
end;

procedure TPDFDocument.WriteStreamObj(ALines: TStrings; ANum: Integer;
  const AStreamData: string);
var
  Raw: TBytes;
begin
  Raw := TEncoding.UTF8.GetBytes(AStreamData);
  ALines.Add(Format('%d 0 obj', [ANum]));
  ALines.Add(Format('<< /Length %d >>', [Length(Raw)]));
  ALines.Add('stream');
  ALines.Add(AStreamData);
  ALines.Add('endstream');
  ALines.Add('endobj');
end;

end.
