{ ============================================================================
  DeepBase.FMX.HB.ShareCard - Offscreen Share & Proof Card Renderer for FMX
  
  Version: 1.0 (Delphi 13.1 on Win64 / Cross-Platform FMX)
  Description: Cross-platform FMX twin implementation of THbShareCardRenderer.
  ============================================================================ }

unit DeepBase.FMX.HB.ShareCard;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
  FMX.Types,
  FMX.Graphics,
  DeepBase.HB.Core,
  DeepBase.HB.ShareCard.Types,
  DeepBase.FMX.HB.Theme;

type
  /// <summary>
  /// THbShareCardRenderer (FMX): Offscreen card renderer for FMX applications.
  /// </summary>
  THbShareCardRenderer = class
  public
    class function GetDimensions(AFormat: THbShareCardFormat; out AWidth, AHeight: Integer): Boolean;
    class function MaskSensitiveText(const AText: string): string;
    class function RenderToBitmap(const AData: THbShareCardData; AFormat: THbShareCardFormat): FMX.Graphics.TBitmap;
    class function SaveToFile(const AData: THbShareCardData; AFormat: THbShareCardFormat; const AFilePath: string): Boolean;
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

class function THbShareCardRenderer.RenderToBitmap(const AData: THbShareCardData; AFormat: THbShareCardFormat): FMX.Graphics.TBitmap;
var
  W, H, I: Integer;
  Bmp: FMX.Graphics.TBitmap;
  Tokens: THbTokens;
  TitleText, SubText, FootNote: string;
  CurY: Single;
begin
  GetDimensions(AFormat, W, H);
  Tokens := THbTheme.Tokens;
  Bmp := FMX.Graphics.TBitmap.Create(W, H);
  try
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

    if Bmp.Canvas.BeginScene then
    try
      // Background Outer
      Bmp.Canvas.Fill.Color := Tokens.Surface;
      Bmp.Canvas.Fill.Kind := TBrushKind.Solid;
      Bmp.Canvas.FillRect(RectF(16, 16, W - 16, H - 16), 32, 32, AllCorners, 1.0);
      Bmp.Canvas.Stroke.Color := Tokens.Border;
      Bmp.Canvas.Stroke.Thickness := 4;
      Bmp.Canvas.DrawRect(RectF(16, 16, W - 16, H - 16), 32, 32, AllCorners, 1.0);

      // Inner Card Container
      Bmp.Canvas.Fill.Color := Tokens.SurfaceAlt;
      Bmp.Canvas.FillRect(RectF(48, 48, W - 48, H - 48), 24, 24, AllCorners, 1.0);
      Bmp.Canvas.Stroke.Thickness := 2;
      Bmp.Canvas.DrawRect(RectF(48, 48, W - 48, H - 48), 24, 24, AllCorners, 1.0);

      // Header Category Pill
      if AData.HeaderCategory <> '' then
      begin
        Bmp.Canvas.Font.Size := 16;
        Bmp.Canvas.Font.Style := [TFontStyle.fsBold];
        Bmp.Canvas.Font.Family := Tokens.FontFamily;
        Bmp.Canvas.Fill.Color := Tokens.Primary;
        Bmp.Canvas.FillText(RectF(80, 80, W - 80, 110), '❖ ' + AData.HeaderCategory, False, 1.0, [], TTextAlign.Leading);
      end;

      // Title
      Bmp.Canvas.Font.Size := 28;
      Bmp.Canvas.Font.Style := [TFontStyle.fsBold];
      Bmp.Canvas.Fill.Color := Tokens.Ink;
      Bmp.Canvas.FillText(RectF(80, 125, W - 80, 175), TitleText, False, 1.0, [], TTextAlign.Leading);

      // Subtitle
      if SubText <> '' then
      begin
        Bmp.Canvas.Font.Size := 18;
        Bmp.Canvas.Font.Style := [];
        Bmp.Canvas.Fill.Color := Tokens.InkMuted;
        Bmp.Canvas.FillText(RectF(80, 180, W - 80, 220), SubText, False, 1.0, [], TTextAlign.Leading);
      end;

      // Metrics Rows
      CurY := 260;
      Bmp.Canvas.Font.Size := 16;
      Bmp.Canvas.Font.Style := [];
      Bmp.Canvas.Fill.Color := Tokens.Ink;
      for I := 0 to High(AData.MetricRows) do
      begin
        if CurY > H - 200 then
          Break;
        Bmp.Canvas.Stroke.Color := Tokens.Border;
        Bmp.Canvas.Stroke.Thickness := 1;
        Bmp.Canvas.DrawLine(PointF(80, CurY - 10), PointF(W - 80, CurY - 10), 1.0);
        Bmp.Canvas.FillText(RectF(80, CurY, W - 80, CurY + 36), '• ' + AData.MetricRows[I], False, 1.0, [], TTextAlign.Leading);
        CurY := CurY + 50;
      end;

      // Watermark / Badge
      if (AData.BadgeText <> '') or AData.WatermarkLocked then
      begin
        Bmp.Canvas.Font.Size := 20;
        Bmp.Canvas.Font.Style := [TFontStyle.fsBold];
        Bmp.Canvas.Fill.Color := Tokens.Primary;
        if AData.BadgeText <> '' then
          Bmp.Canvas.FillText(RectF(W - 360, 80, W - 80, 120), '🛡 ' + AData.BadgeText, False, 1.0, [], TTextAlign.Trailing)
        else
          Bmp.Canvas.FillText(RectF(W - 360, 80, W - 80, 120), '🛡 认知审计合格证', False, 1.0, [], TTextAlign.Trailing);
      end;

      // Footer
      Bmp.Canvas.Font.Size := 14;
      Bmp.Canvas.Fill.Color := Tokens.Warning;
      Bmp.Canvas.FillText(RectF(80, H - 120, W - 80, H - 90), '⚠ ' + FootNote, False, 1.0, [], TTextAlign.Leading);

      // Timestamp
      Bmp.Canvas.Font.Size := 12;
      Bmp.Canvas.Fill.Color := Tokens.InkMuted;
      if AData.TimestampStr <> '' then
        Bmp.Canvas.FillText(RectF(80, H - 85, W - 80, H - 60), '生成快照时间: ' + AData.TimestampStr, False, 1.0, [], TTextAlign.Leading)
      else
        Bmp.Canvas.FillText(RectF(80, H - 85, W - 80, H - 60), '生成快照时间: ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now), False, 1.0, [], TTextAlign.Leading);
    finally
      Bmp.Canvas.EndScene;
    end;
    Result := Bmp;
  except
    Bmp.Free;
    raise;
  end;
end;

class function THbShareCardRenderer.SaveToFile(const AData: THbShareCardData; AFormat: THbShareCardFormat;
  const AFilePath: string): Boolean;
var
  Bmp: FMX.Graphics.TBitmap;
begin
  Bmp := RenderToBitmap(AData, AFormat);
  try
    Bmp.SaveToFile(AFilePath);
    Result := True;
  finally
    Bmp.Free;
  end;
end;

end.
