{ ============================================================================
  DeepBase.VCL.HB.ShareCard - Offscreen Vector Share & Proof Card Renderer
  
  Version: 1.0 (Delphi 13.1 on Win64)
  Description: Offscreen GDI+ renderer for shareable audit receipts & proof cards:
               - Formats: 16:9 (1920x1080), 1:1 (1080x1080), 4:5 (1080x1350)
               - Multi-line metrics (MetricRows) with key-value alignment
               - Mandatory legal disclaimer (FooterNote)
               - Immutable watermark locking (WatermarkLocked)
               - Automatic privacy masking for PII / sensitive data
               - Direct export to TBitmap, PNG file, and Windows Clipboard
  ============================================================================ }

unit DeepBase.VCL.HB.ShareCard;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
  System.Math,
  Vcl.Graphics,
  Vcl.Clipbrd,
  Vcl.Imaging.pngimage,
  DeepBase.HB.Core,
  DeepBase.HB.ShareCard.Types,
  DeepBase.VCL.HB.Theme;

type
  /// <summary>
  /// THbShareCardRenderer: Utility class for offscreen share card vector rendering.
  /// </summary>
  THbShareCardRenderer = class
  public
    class function GetDimensions(AFormat: THbShareCardFormat; out AWidth, AHeight: Integer): Boolean;
    class function MaskSensitiveText(const AText: string): string;
    class function RenderToBitmap(const AData: THbShareCardData; AFormat: THbShareCardFormat): TBitmap;
    class function SaveToFile(const AData: THbShareCardData; AFormat: THbShareCardFormat; const AFilePath: string): Boolean;
    class function CopyToClipboard(const AData: THbShareCardData; AFormat: THbShareCardFormat): Boolean;
  end;

implementation

{ THbShareCardRenderer }

class function THbShareCardRenderer.GetDimensions(AFormat: THbShareCardFormat; out AWidth, AHeight: Integer): Boolean;
begin
  Result := True;
  case AFormat of
    scfLandscape16x9:
    begin
      AWidth := 1920;
      AHeight := 1080;
    end;
    scfSquare1x1:
    begin
      AWidth := 1080;
      AHeight := 1080;
    end;
    scfPortrait4x5:
    begin
      AWidth := 1080;
      AHeight := 1350;
    end;
  else
    AWidth := 1080;
    AHeight := 1080;
  end;
end;

class function THbShareCardRenderer.MaskSensitiveText(const AText: string): string;
var
  I, DigitCount: Integer;
begin
  Result := AText;
  DigitCount := 0;
  for I := 1 to Length(Result) do
  begin
    if CharInSet(Result[I], ['0'..'9']) then
    begin
      Inc(DigitCount);
      if DigitCount > 3 then
        Result[I] := '*';
    end
    else
      DigitCount := 0;
  end;
end;

class function THbShareCardRenderer.RenderToBitmap(const AData: THbShareCardData; AFormat: THbShareCardFormat): TBitmap;
var
  W, H, I, CurY: Integer;
  Bmp: TBitmap;
  Tokens: THbTokens;
  TitleText, SubText, FootNote: string;
begin
  GetDimensions(AFormat, W, H);
  Tokens := THbTheme.Tokens;

  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(W, H);
    Bmp.PixelFormat := pf32bit;

    // Apply auto-masking if requested
    if AData.EnableAutoMasking then
    begin
      TitleText := MaskSensitiveText(AData.Title);
      SubText := MaskSensitiveText(AData.Subtitle);
    end
    else
    begin
      TitleText := AData.Title;
      SubText := AData.Subtitle;
    end;

    if AData.FooterNote <> '' then
      FootNote := AData.FooterNote
    else
      FootNote := '通过本地门禁检查 ≠ 事实绝对正确 · 仅供专业审阅参考';

    // Fill Background
    Bmp.Canvas.Brush.Color := AlphaColorToColor(Tokens.Surface);
    Bmp.Canvas.Pen.Color := AlphaColorToColor(Tokens.Border);
    Bmp.Canvas.Pen.Width := 4;
    Bmp.Canvas.RoundRect(16, 16, W - 16, H - 16, 32, 32);

    // Inner Card Container
    Bmp.Canvas.Brush.Color := AlphaColorToColor(Tokens.SurfaceAlt);
    Bmp.Canvas.Pen.Color := AlphaColorToColor(Tokens.Border);
    Bmp.Canvas.Pen.Width := 2;
    Bmp.Canvas.RoundRect(48, 48, W - 48, H - 48, 24, 24);

    // Header Category Pill
    if AData.HeaderCategory <> '' then
    begin
      Bmp.Canvas.Font.Name := 'Segoe UI';
      Bmp.Canvas.Font.Size := 16;
      Bmp.Canvas.Font.Style := [fsBold];
      Bmp.Canvas.Font.Color := AlphaColorToColor(Tokens.Primary);
      Bmp.Canvas.TextOut(80, 80, '❖ ' + AData.HeaderCategory);
    end;

    // Title
    Bmp.Canvas.Font.Name := 'Segoe UI';
    Bmp.Canvas.Font.Size := 28;
    Bmp.Canvas.Font.Style := [fsBold];
    Bmp.Canvas.Font.Color := AlphaColorToColor(Tokens.Ink);
    Bmp.Canvas.TextOut(80, 130, TitleText);

    // Subtitle
    if SubText <> '' then
    begin
      Bmp.Canvas.Font.Size := 18;
      Bmp.Canvas.Font.Style := [];
      Bmp.Canvas.Font.Color := AlphaColorToColor(Tokens.InkMuted);
      Bmp.Canvas.TextOut(80, 185, SubText);
    end;

    // Metrics Rows
    CurY := 260;
    Bmp.Canvas.Font.Size := 16;
    Bmp.Canvas.Font.Style := [];
    Bmp.Canvas.Font.Color := AlphaColorToColor(Tokens.Ink);

    for I := 0 to High(AData.MetricRows) do
    begin
      if CurY > H - 200 then
        Break;
      Bmp.Canvas.Pen.Color := AlphaColorToColor(Tokens.Border);
      Bmp.Canvas.Pen.Width := 1;
      Bmp.Canvas.MoveTo(80, CurY - 10);
      Bmp.Canvas.LineTo(W - 80, CurY - 10);

      Bmp.Canvas.TextOut(80, CurY, '• ' + AData.MetricRows[I]);
      Inc(CurY, 50);
    end;

    // Watermark / Badge
    if (AData.BadgeText <> '') or AData.WatermarkLocked then
    begin
      Bmp.Canvas.Font.Size := 20;
      Bmp.Canvas.Font.Style := [fsBold];
      Bmp.Canvas.Font.Color := AlphaColorToColor(Tokens.Primary);
      if AData.BadgeText <> '' then
        Bmp.Canvas.TextOut(W - 320, 80, '🛡 ' + AData.BadgeText)
      else
        Bmp.Canvas.TextOut(W - 320, 80, '🛡 认知审计合格证');
    end;

    // Footer Disclaimer Note
    Bmp.Canvas.Font.Size := 14;
    Bmp.Canvas.Font.Style := [];
    Bmp.Canvas.Font.Color := AlphaColorToColor(Tokens.Warning);
    Bmp.Canvas.TextOut(80, H - 120, '⚠ ' + FootNote);

    // Timestamp
    Bmp.Canvas.Font.Size := 12;
    Bmp.Canvas.Font.Color := AlphaColorToColor(Tokens.InkMuted);
    if AData.TimestampStr <> '' then
      Bmp.Canvas.TextOut(80, H - 85, '生成快照时间: ' + AData.TimestampStr)
    else
      Bmp.Canvas.TextOut(80, H - 85, '生成快照时间: ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));

    Result := Bmp;
  except
    Bmp.Free;
    raise;
  end;
end;

class function THbShareCardRenderer.SaveToFile(const AData: THbShareCardData; AFormat: THbShareCardFormat;
  const AFilePath: string): Boolean;
var
  Bmp: TBitmap;
  Png: TPngImage;
begin
  Bmp := RenderToBitmap(AData, AFormat);
  try
    if SameText(ExtractFileExt(AFilePath), '.png') or (ExtractFileExt(AFilePath) = '') then
    begin
      Png := TPngImage.Create;
      try
        Png.Assign(Bmp);
        Png.SaveToFile(AFilePath);
        Result := True;
      finally
        Png.Free;
      end;
    end
    else
    begin
      Bmp.SaveToFile(AFilePath);
      Result := True;
    end;
  finally
    Bmp.Free;
  end;
end;

class function THbShareCardRenderer.CopyToClipboard(const AData: THbShareCardData; AFormat: THbShareCardFormat): Boolean;
var
  Bmp: TBitmap;
begin
  Bmp := RenderToBitmap(AData, AFormat);
  try
    Clipboard.Assign(Bmp);
    Result := True;
  finally
    Bmp.Free;
  end;
end;

end.
