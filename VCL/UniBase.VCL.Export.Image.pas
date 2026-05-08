{==============================================================================
  DeepBase.VCL.Export.Image - Canvas-Based Image Export (VCL)

  Renders text, tables, shapes, and images onto a TBitmap canvas and
  exports the result as PNG or JPEG.  No third-party dependencies.

  Usage:
    var Img := TImageExport.Create;
    Img.Width := 800;
    Img.Height := 600;
    Img.SetFont('Microsoft YaHei', 14);
    Img.DrawText(20, 20, 'Hello / 你好');
    Img.DrawTable(20, 60, ['Name', 'Score'], [['Alice', '95']]);
    Img.SaveToFile('output.png');
    Img.Free;
==============================================================================}

unit DeepBase.VCL.Export.Image;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Math,
  System.Generics.Collections,
  Vcl.Graphics,
  Vcl.Imaging.PNGImage,
  Vcl.Imaging.jpeg;

type
  TImageTextAlign = (iaLeft, iaCenter, iaRight);

  TImageColumnDef = record
    Title: string;
    Width: Integer;
    Align: TImageTextAlign;
    constructor Create(const ATitle: string; AWidth: Integer;
      AAlign: TImageTextAlign = iaLeft);
  end;

  TImageExport = class
  private
    FBitmap: TBitmap;
    FFontName: string;
    FFontSize: Integer;
    FFontColor: TColor;
    FFillColor: TColor;
    FStrokeColor: TColor;
    FLineWidth: Integer;
    FBgColor: TColor;

    function TextW(const AText: string): Integer;
    function TextH: Integer;
    procedure ApplyFont(ACanvas: TCanvas);
  public
    constructor Create;
    destructor Destroy; override;

    procedure SetSize(AWidth, AHeight: Integer);
    procedure SetBackground(AColor: TColor);
    procedure SetFont(const AName: string; ASize: Integer);
    procedure SetFontColor(AColor: TColor);
    procedure SetFillColor(AColor: TColor);
    procedure SetStrokeColor(AColor: TColor);
    procedure SetLineWidth(AW: Integer);

    procedure Clear;
    procedure DrawText(X, Y: Integer; const AText: string);
    procedure DrawTextAligned(X, Y, AW: Integer; const AText: string;
      AAlign: TImageTextAlign);
    function DrawTextBlock(X, Y, MaxW: Integer; const AText: string;
      ALineH: Integer = 0): Integer;
    procedure DrawLine(X1, Y1, X2, Y2: Integer);
    procedure DrawRect(X, Y, AW, AH: Integer; AFill: Boolean = False;
      AStroke: Boolean = True);
    procedure DrawRoundRect(X, Y, AW, AH, ARadius: Integer;
      AFill: Boolean = False; AStroke: Boolean = True);
    procedure DrawImage(X, Y, AW, AH: Integer; const AFileName: string); overload;
    procedure DrawImage(X, Y, AW, AH: Integer; AGraphic: TGraphic); overload;
    procedure DrawTable(X, Y: Integer; const ACols: TArray<TImageColumnDef>;
      const ARows: TArray<TArray<string>>; AHeaderColor: TColor = clNavy);

    procedure SaveToStream(AStream: TStream; const AFormat: string = 'png');
    procedure SaveToFile(const AFileName: string);
    procedure SaveToPNG(AStream: TStream);
    procedure SaveToJPEG(AStream: TStream; AQuality: Integer = 90);

    property Bitmap: TBitmap read FBitmap;
    property Width: Integer read FBitmap.Width;
    property Height: Integer read FBitmap.Height;
  end;

implementation

{ TImageColumnDef }

constructor TImageColumnDef.Create(const ATitle: string; AWidth: Integer;
  AAlign: TImageTextAlign);
begin
  Title := ATitle;
  Width := AWidth;
  Align := AAlign;
end;

{ TImageExport }

constructor TImageExport.Create;
begin
  inherited Create;
  FBitmap := TBitmap.Create;
  FBitmap.SetSize(800, 600);
  FBitmap.PixelFormat := pf32bit;
  FBgColor := clWhite;
  FFontName := 'Microsoft YaHei';
  FFontSize := 12;
  FFontColor := clBlack;
  FFillColor := clWhite;
  FStrokeColor := clBlack;
  FLineWidth := 1;
  Clear;
end;

destructor TImageExport.Destroy;
begin
  FreeAndNil(FBitmap);
  inherited;
end;

procedure TImageExport.SetSize(AWidth, AHeight: Integer);
begin
  FBitmap.SetSize(AWidth, AHeight);
  Clear;
end;

procedure TImageExport.SetBackground(AColor: TColor);
begin
  FBgColor := AColor;
end;

procedure TImageExport.SetFont(const AName: string; ASize: Integer);
begin
  FFontName := AName;
  FFontSize := ASize;
end;

procedure TImageExport.SetFontColor(AColor: TColor);
begin
  FFontColor := AColor;
end;

procedure TImageExport.SetFillColor(AColor: TColor);
begin
  FFillColor := AColor;
end;

procedure TImageExport.SetStrokeColor(AColor: TColor);
begin
  FStrokeColor := AColor;
end;

procedure TImageExport.SetLineWidth(AW: Integer);
begin
  FLineWidth := AW;
end;

procedure TImageExport.ApplyFont(ACanvas: TCanvas);
begin
  ACanvas.Font.Name := FFontName;
  ACanvas.Font.Size := FFontSize;
  ACanvas.Font.Color := FFontColor;
end;

function TImageExport.TextW(const AText: string): Integer;
begin
  ApplyFont(FBitmap.Canvas);
  Result := FBitmap.Canvas.TextWidth(AText);
end;

function TImageExport.TextH: Integer;
begin
  ApplyFont(FBitmap.Canvas);
  Result := FBitmap.Canvas.TextHeight('Ay');
end;

procedure TImageExport.Clear;
begin
  FBitmap.Canvas.Brush.Color := FBgColor;
  FBitmap.Canvas.FillRect(Rect(0, 0, FBitmap.Width, FBitmap.Height));
end;

procedure TImageExport.DrawText(X, Y: Integer; const AText: string);
begin
  ApplyFont(FBitmap.Canvas);
  FBitmap.Canvas.TextOut(X, Y, AText);
end;

procedure TImageExport.DrawTextAligned(X, Y, AW: Integer;
  const AText: string; AAlign: TImageTextAlign);
var
  TW, DX: Integer;
begin
  TW := TextW(AText);
  case AAlign of
    iaLeft:   DX := 0;
    iaCenter: DX := (AW - TW) div 2;
    iaRight:  DX := AW - TW;
  else
    DX := 0;
  end;
  DrawText(X + DX, Y, AText);
end;

function TImageExport.DrawTextBlock(X, Y, MaxW: Integer;
  const AText: string; ALineH: Integer): Integer;
var
  Lines: TArray<string>;
  CurLine: string;
  I, J: Integer;
  Ch: Char;
  CW: Integer;

  procedure Flush;
  begin
    if CurLine <> '' then
    begin
      Lines := Lines + [CurLine];
      CurLine := '';
    end;
  end;

begin
  if ALineH <= 0 then
    ALineH := TextH + 4;

  CurLine := '';
  for J := 1 to Length(AText) do
  begin
    Ch := AText[J];
    if Ch = #13 then Continue;
    if Ch = #10 then
    begin
      Flush;
      Continue;
    end;
    CW := TextW(Ch);
    if (TextW(CurLine) + CW > MaxW) and (CurLine <> '') then
    begin
      Lines := Lines + [CurLine];
      CurLine := Ch;
    end
    else
      CurLine := CurLine + Ch;
  end;
  Flush;

  for I := 0 to High(Lines) do
    DrawText(X, Y + I * ALineH, Lines[I]);

  Result := Length(Lines) * ALineH;
end;

procedure TImageExport.DrawLine(X1, Y1, X2, Y2: Integer);
begin
  FBitmap.Canvas.Pen.Color := FStrokeColor;
  FBitmap.Canvas.Pen.Width := FLineWidth;
  FBitmap.Canvas.MoveTo(X1, Y1);
  FBitmap.Canvas.LineTo(X2, Y2);
end;

procedure TImageExport.DrawRect(X, Y, AW, AH: Integer;
  AFill, AStroke: Boolean);
var
  R: TRect;
begin
  R := Rect(X, Y, X + AW, Y + AH);
  if AFill then
  begin
    FBitmap.Canvas.Brush.Color := FFillColor;
    FBitmap.Canvas.FillRect(R);
  end;
  if AStroke then
  begin
    FBitmap.Canvas.Pen.Color := FStrokeColor;
    FBitmap.Canvas.Pen.Width := FLineWidth;
    FBitmap.Canvas.Brush.Style := bsClear;
    FBitmap.Canvas.Rectangle(R);
  end;
end;

procedure TImageExport.DrawRoundRect(X, Y, AW, AH, ARadius: Integer;
  AFill, AStroke: Boolean);
var
  R: TRect;
begin
  R := Rect(X, Y, X + AW, Y + AH);
  if AFill then
  begin
    FBitmap.Canvas.Brush.Color := FFillColor;
    FBitmap.Canvas.FillRect(R);
  end;
  if AStroke then
  begin
    FBitmap.Canvas.Pen.Color := FStrokeColor;
    FBitmap.Canvas.Pen.Width := FLineWidth;
    FBitmap.Canvas.Brush.Style := bsClear;
    FBitmap.Canvas.RoundRect(R, ARadius, ARadius);
  end;
end;

procedure TImageExport.DrawImage(X, Y, AW, AH: Integer;
  const AFileName: string);
var
  Pic: TPicture;
begin
  Pic := TPicture.Create;
  try
    Pic.LoadFromFile(AFileName);
    DrawImage(X, Y, AW, AH, Pic.Graphic);
  finally
    Pic.Free;
  end;
end;

procedure TImageExport.DrawImage(X, Y, AW, AH: Integer;
  AGraphic: TGraphic);
var
  R: TRect;
begin
  R := Rect(X, Y, X + AW, Y + AH);
  FBitmap.Canvas.StretchDraw(R, AGraphic);
end;

procedure TImageExport.DrawTable(X, Y: Integer;
  const ACols: TArray<TImageColumnDef>;
  const ARows: TArray<TArray<string>>; AHeaderColor: TColor);
var
  C: TCanvas;
  RowH, CurY, ColX: Integer;
  I, J: Integer;
  SavedFontColor: TColor;
  TW, DX: Integer;

  procedure HLine(AX, AYY, AW: Integer);
  begin
    C.Pen.Color := FStrokeColor;
    C.Pen.Width := FLineWidth;
    C.MoveTo(AX, AYY);
    C.LineTo(AX + AW, AYY);
  end;

  procedure VLine(AX, AYY1, AYY2: Integer);
  begin
    C.Pen.Color := FStrokeColor;
    C.Pen.Width := FLineWidth;
    C.MoveTo(AX, AYY1);
    C.LineTo(AX, AYY2);
  end;

var
  TotalW: Integer;
begin
  if Length(ACols) = 0 then Exit;
  C := FBitmap.Canvas;

  SavedFontColor := FFontColor;
  ApplyFont(C);
  RowH := TextH + 10;
  TotalW := 0;
  for I := 0 to High(ACols) do
    TotalW := TotalW + ACols[I].Width;

  CurY := Y;

  // Header
  C.Brush.Color := AHeaderColor;
  C.FillRect(Rect(X, CurY, X + TotalW, CurY + RowH));
  ColX := X;
  C.Font.Color := clWhite;
  for J := 0 to High(ACols) do
  begin
    TW := C.TextWidth(ACols[J].Title);
    case ACols[J].Align of
      iaCenter: DX := (ACols[J].Width - TW) div 2;
      iaRight:  DX := ACols[J].Width - TW - 4;
    else
      DX := 4;
    end;
    C.TextOut(ColX + DX, CurY + 5, ACols[J].Title);
    ColX := ColX + ACols[J].Width;
  end;
  CurY := CurY + RowH;
  HLine(X, CurY, TotalW);

  // Data rows
  C.Font.Color := SavedFontColor;
  for I := 0 to High(ARows) do
  begin
    if Odd(I) then
      C.Brush.Color := RGBToColor(245, 245, 245)
    else
      C.Brush.Color := clWhite;
    C.FillRect(Rect(X, CurY, X + TotalW, CurY + RowH));

    ColX := X;
    for J := 0 to Min(High(ARows[I]), High(ACols)) do
    begin
      TW := C.TextWidth(ARows[I][J]);
      case ACols[J].Align of
        iaCenter: DX := (ACols[J].Width - TW) div 2;
        iaRight:  DX := ACols[J].Width - TW - 4;
      else
        DX := 4;
      end;
      C.TextOut(ColX + DX, CurY + 5, ARows[I][J]);
      ColX := ColX + ACols[J].Width;
    end;
    CurY := CurY + RowH;
    HLine(X, CurY, TotalW);
  end;

  // Vertical lines
  ColX := X;
  for J := 0 to High(ACols) do
  begin
    VLine(ColX, Y, CurY);
    ColX := ColX + ACols[J].Width;
  end;
  VLine(ColX, Y, CurY);

  FFontColor := SavedFontColor;
end;

procedure TImageExport.SaveToStream(AStream: TStream; const AFormat: string);
begin
  if SameText(AFormat, 'jpg') or SameText(AFormat, 'jpeg') then
    SaveToJPEG(AStream)
  else
    SaveToPNG(AStream);
end;

procedure TImageExport.SaveToFile(const AFileName: string);
var
  Ext: string;
  S: TFileStream;
begin
  Ext := ExtractFileExt(AFileName).ToLower;
  S := TFileStream.Create(AFileName, fmCreate);
  try
    if (Ext = '.jpg') or (Ext = '.jpeg') then
      SaveToJPEG(S)
    else
      SaveToPNG(S);
  finally
    S.Free;
  end;
end;

procedure TImageExport.SaveToPNG(AStream: TStream);
var
  PNG: TPNGImage;
begin
  PNG := TPNGImage.Create;
  try
    PNG.Assign(FBitmap);
    PNG.SaveToStream(AStream);
  finally
    PNG.Free;
  end;
end;

procedure TImageExport.SaveToJPEG(AStream: TStream; AQuality: Integer);
var
  JPG: TJPEGImage;
begin
  JPG := TJPEGImage.Create;
  try
    JPG.Assign(FBitmap);
    JPG.CompressionQuality := AQuality;
    JPG.SaveToStream(AStream);
  finally
    JPG.Free;
  end;
end;

end.
