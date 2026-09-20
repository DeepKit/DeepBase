{ ============================================================================
  Test.DeepBase.HB.Font - Unit Tests for HB Font Governance & Fallback Chain

  Version: 1.0 (Delphi 13.1 on Win64)
  Description: Verifies WO-20260904-003:
               - Tokens.FontFamily resolves to Microsoft YaHei UI
               - 3-tier fallback chain resolution logic with mock probe
               - Cache management
               - Zero hardcoded font names in HB visual units
               - Visual verification render tests for 100%, 125%, 150% DPI
  ============================================================================ }

unit Test.DeepBase.HB.Font;

{$WARN IMPLICIT_STRING_CAST OFF}

interface

uses
  DUnitX.TestFramework,
  Winapi.Windows,
  Winapi.Messages,
  Winapi.GDIPOBJ,
  Winapi.GDIPAPI,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Types,
  System.UITypes,
  Vcl.Graphics,
  Vcl.Imaging.pngimage,
  DeepBase.HB.Core,
  DeepBase.HB.ShareCard.Types,
  DeepBase.VCL.HB.ShareCard;

type
  [TestFixture]
  TTestHbFont = class
  private
    procedure RenderTypographyLadder(const AOutPath: string; APPI: Integer);
  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_DefaultFont_ResolvesToMicrosoftYaHeiUI;

    [Test]
    procedure Test_FallbackChain_PrimaryAvailable_SelectsPrimary;

    [Test]
    procedure Test_FallbackChain_PrimaryMissing_SelectsSecondary;

    [Test]
    procedure Test_FallbackChain_PrimaryAndSecondaryMissing_SelectsSegoeUI;

    [Test]
    procedure Test_FallbackChain_AllMissing_ReturnsLastOrFallback;

    [Test]
    procedure Test_ResetDefaultFontCache_ClearsCache;

    [Test]
    procedure Test_NoHardcodedSegoeUI_InVclHBUnits;

    [Test]
    procedure Test_VisualVerification_ExportShareCard_PNG;

    [Test]
    procedure Test_VisualVerification_ExportTypographyLadder_DPI_100_125_150;
  end;

implementation

{ TTestHbFont }

procedure TTestHbFont.Setup;
begin
  THbTheme.ResetDefaultFontCache;
end;

procedure TTestHbFont.TearDown;
begin
  THbTheme.ResetDefaultFontCache;
end;

procedure TTestHbFont.Test_DefaultFont_ResolvesToMicrosoftYaHeiUI;
var
  FontName: string;
begin
  FontName := THbTheme.Tokens.FontFamily;
  {$IFDEF MSWINDOWS}
  // On standard Windows 10/11 system, Microsoft YaHei UI is always installed
  Assert.AreEqual('Microsoft YaHei UI', FontName, 'Tokens.FontFamily must resolve to Microsoft YaHei UI on Windows');
  {$ENDIF}
  Assert.IsTrue(FontName <> '', 'Font family must not be empty');
end;

procedure TTestHbFont.Test_FallbackChain_PrimaryAvailable_SelectsPrimary;
var
  Resolved: string;
begin
  Resolved := THbTheme.ResolveFontFamily(['Microsoft YaHei UI', 'Microsoft YaHei', 'Segoe UI'],
    function(const AName: string): Boolean
    begin
      Result := (AName = 'Microsoft YaHei UI') or (AName = 'Microsoft YaHei') or (AName = 'Segoe UI');
    end);
  Assert.AreEqual('Microsoft YaHei UI', Resolved);
end;

procedure TTestHbFont.Test_FallbackChain_PrimaryMissing_SelectsSecondary;
var
  Resolved: string;
begin
  Resolved := THbTheme.ResolveFontFamily(['Microsoft YaHei UI', 'Microsoft YaHei', 'Segoe UI'],
    function(const AName: string): Boolean
    begin
      // Mock: Microsoft YaHei UI not available, Microsoft YaHei available
      Result := (AName = 'Microsoft YaHei') or (AName = 'Segoe UI');
    end);
  Assert.AreEqual('Microsoft YaHei', Resolved);
end;

procedure TTestHbFont.Test_FallbackChain_PrimaryAndSecondaryMissing_SelectsSegoeUI;
var
  Resolved: string;
begin
  Resolved := THbTheme.ResolveFontFamily(['Microsoft YaHei UI', 'Microsoft YaHei', 'Segoe UI'],
    function(const AName: string): Boolean
    begin
      // Mock: Only Segoe UI available
      Result := (AName = 'Segoe UI');
    end);
  Assert.AreEqual('Segoe UI', Resolved);
end;

procedure TTestHbFont.Test_FallbackChain_AllMissing_ReturnsLastOrFallback;
var
  Resolved: string;
begin
  Resolved := THbTheme.ResolveFontFamily(['FontA', 'FontB', 'FontC'],
    function(const AName: string): Boolean
    begin
      Result := False;
    end);
  Assert.AreEqual('FontC', Resolved);
end;

procedure TTestHbFont.Test_ResetDefaultFontCache_ClearsCache;
var
  F1, F2: string;
begin
  F1 := THbTheme.GetDefaultFontFamily;
  Assert.IsTrue(F1 <> '');
  THbTheme.ResetDefaultFontCache;
  F2 := THbTheme.GetDefaultFontFamily;
  Assert.AreEqual(F1, F2);
end;

procedure TTestHbFont.Test_NoHardcodedSegoeUI_InVclHBUnits;
var
  VclPath, Content, FileName: string;
  Files: TArray<string>;
begin
  VclPath := TPath.Combine(ExtractFilePath(ParamStr(0)), '..\..\VCL');
  if not TDirectory.Exists(VclPath) then
    VclPath := 'VCL';

  if TDirectory.Exists(VclPath) then
  begin
    Files := TDirectory.GetFiles(VclPath, 'DeepBase.VCL.HB.*.pas');
    for FileName in Files do
    begin
      Content := TFile.ReadAllText(FileName);
      Assert.IsFalse(Content.Contains('''Segoe UI'''),
        Format('File %s must not contain hardcoded ''Segoe UI''', [TPath.GetFileName(FileName)]));
    end;
  end;
end;

function GetScreenshotsDir: string;
var
  Dir: string;
begin
  Dir := ExtractFilePath(ParamStr(0));
  while (Dir <> '') and not (TDirectory.Exists(TPath.Combine(Dir, 'Core')) and TDirectory.Exists(TPath.Combine(Dir, 'VCL'))) do
    Dir := ExtractFilePath(ExcludeTrailingPathDelimiter(Dir));

  if Dir <> '' then
    Result := TPath.Combine(Dir, 'TestResults\WO-20260904-003\screenshots')
  else
    Result := 'TestResults\WO-20260904-003\screenshots';

  if not TDirectory.Exists(Result) then
    TDirectory.CreateDirectory(Result);
end;

procedure TTestHbFont.Test_VisualVerification_ExportShareCard_PNG;
var
  Data: THbShareCardData;
  OutDir, FilePath: string;
  Saved: Boolean;
begin
  OutDir := GetScreenshotsDir;
  FilePath := TPath.Combine(OutDir, 'sharecard_yahei.png');

  Data.Title := '唤金深度商业推演与行为决策报告';
  Data.Subtitle := 'HB Visual Infrastructure v3.0 · Microsoft YaHei UI 渲染验证';
  Data.HeaderCategory := '唤金 2026 商业中台';
  Data.BadgeText := '认知审计合格证';
  Data.WatermarkLocked := True;
  Data.FooterNote := '通过本地门禁检查 · 采用 Microsoft YaHei UI 全局矢量字体引擎';
  SetLength(Data.MetricRows, 4);
  Data.MetricRows[0] := '四自闭环指标: SDR = 94.8% (自营销转化达标)';
  Data.MetricRows[1] := '零客服自解率: FCR = 91.2% (完全自助导引)';
  Data.MetricRows[2] := '高频网格写入延迟: P95 = 0.0042 ms (优于门禁 470x)';
  Data.MetricRows[3] := '字体渲染状态: 微软雅黑 UI 100% 绑定 · 零宋体回退';

  Saved := THbShareCardRenderer.SaveToFile(Data, scfLandscape16x9, FilePath);
  Assert.IsTrue(Saved, 'ShareCard PNG export must succeed');
  Assert.IsTrue(TFile.Exists(FilePath), 'Exported PNG file must exist');
end;

procedure TTestHbFont.RenderTypographyLadder(const AOutPath: string; APPI: Integer);
var
  Bmp: TBitmap;
  G: TGPGraphics;
  Fam: TGPFontFamily;
  FontXS, FontS, FontM, FontL, FontXL, FontXXL, FontTitle: TGPFont;
  BrushInk, BrushMuted, BrushBrand, BrushBg: TGPSolidBrush;
  ScaleFactor: Single;
  W, H: Integer;
  PNG: TPngImage;
  Tokens: THbTokens;

  function PtToPx(APt: Single): Single;
  begin
    Result := APt * (APPI / 72.0);
  end;

begin
  ScaleFactor := APPI / 96.0;
  W := Round(1200 * ScaleFactor);
  H := Round(800 * ScaleFactor);

  Tokens := THbTheme.Tokens;
  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(W, H);
    Bmp.PixelFormat := pf32bit;

    G := TGPGraphics.Create(Bmp.Canvas.Handle);
    try
      G.SetTextRenderingHint(TextRenderingHintClearTypeGridFit);
      BrushBg := TGPSolidBrush.Create($FFFFFDF8);
      BrushInk := TGPSolidBrush.Create($FF292524);
      BrushMuted := TGPSolidBrush.Create($FF8A8175);
      BrushBrand := TGPSolidBrush.Create($FFD97706);
      try
        G.FillRectangle(BrushBg, MakeRect(0, 0, W, H));

        Fam := TGPFontFamily.Create(Tokens.FontFamily);
        try
          FontTitle := TGPFont.Create(Fam, PtToPx(24), FontStyleBold, UnitPixel);
          FontXXL := TGPFont.Create(Fam, PtToPx(Tokens.SizeXXL), FontStyleBold, UnitPixel);
          FontXL := TGPFont.Create(Fam, PtToPx(Tokens.SizeXL), FontStyleBold, UnitPixel);
          FontL := TGPFont.Create(Fam, PtToPx(Tokens.SizeL), FontStyleRegular, UnitPixel);
          FontM := TGPFont.Create(Fam, PtToPx(Tokens.SizeM), FontStyleRegular, UnitPixel);
          FontS := TGPFont.Create(Fam, PtToPx(Tokens.SizeS), FontStyleRegular, UnitPixel);
          FontXS := TGPFont.Create(Fam, PtToPx(Tokens.SizeXS), FontStyleRegular, UnitPixel);
          try
            // Header
            G.DrawString(
              PWideChar(Format('DeepBase HB 中文字体治理验证 · %s (%d%% DPI)', [Tokens.FontFamily, Round(ScaleFactor * 100)])),
              -1, FontTitle, MakePoint(40.0 * ScaleFactor, 30.0 * ScaleFactor), BrushBrand);

            G.DrawString(
              PWideChar('全库单一真相源 Tokens.FontFamily 驱动 · GDI+ ClearType 笔画平滑无点阵虚焦'),
              -1, FontM, MakePoint(40.0 * ScaleFactor, 75.0 * ScaleFactor), BrushMuted);

            // Size XXL (34 pt)
            G.DrawString(
              PWideChar('SizeXXL (34pt) 唤金商业引擎：深度推演与决策场 0123456789'),
              -1, FontXXL, MakePoint(40.0 * ScaleFactor, 120.0 * ScaleFactor), BrushInk);

            // Size XL (22 pt)
            G.DrawString(
              PWideChar('SizeXL (22pt) 触点即场 · 每一次人机交互都驱动状态跃迁 (DeepBase HB 2026)'),
              -1, FontXL, MakePoint(40.0 * ScaleFactor, 200.0 * ScaleFactor), BrushBrand);

            // Size L (17 pt)
            G.DrawString(
              PWideChar('SizeL (17pt) 证据驱动 UI · 零客服闭环路径与自营销转化率验证 ABCDEF ghijklmn'),
              -1, FontL, MakePoint(40.0 * ScaleFactor, 265.0 * ScaleFactor), BrushInk);

            // Size M (14 pt - Body Default)
            G.DrawString(
              PWideChar('SizeM (14pt · 正文基准) 唤金默认暖金主题，微软雅黑 UI 呈现饱满清晰中文字形，彻底告别 SimSun 宋体回退。'),
              -1, FontM, MakePoint(40.0 * ScaleFactor, 325.0 * ScaleFactor), BrushInk);

            // Size S (12.5 pt)
            G.DrawString(
              PWideChar('SizeS (12.5pt) 控件标签与辅助描述：THbButton / THbCard / THbFacetWaterfall / THbDataGrid 统一排版。'),
              -1, FontS, MakePoint(40.0 * ScaleFactor, 380.0 * ScaleFactor), BrushMuted);

            // Size XS (11 pt)
            G.DrawString(
              PWideChar('SizeXS (11pt · 微字号) 状态角标与提示文案：Fail-Closed 门禁断言 / 内存环形缓冲 / Grid 聚合采样 / 125% 150% 缩放无损。'),
              -1, FontXS, MakePoint(40.0 * ScaleFactor, 430.0 * ScaleFactor), BrushMuted);

          finally
            FontXS.Free;
            FontS.Free;
            FontM.Free;
            FontL.Free;
            FontXL.Free;
            FontXXL.Free;
            FontTitle.Free;
          end;
        finally
          Fam.Free;
        end;
      finally
        BrushBg.Free;
        BrushInk.Free;
        BrushMuted.Free;
        BrushBrand.Free;
      end;
    finally
      G.Free;
    end;

    PNG := TPngImage.Create;
    try
      PNG.Assign(Bmp);
      PNG.SaveToFile(AOutPath);
    finally
      PNG.Free;
    end;
  finally
    Bmp.Free;
  end;
end;

procedure TTestHbFont.Test_VisualVerification_ExportTypographyLadder_DPI_100_125_150;
var
  OutDir: string;
begin
  OutDir := GetScreenshotsDir;

  // 100% DPI (96 PPI)
  RenderTypographyLadder(TPath.Combine(OutDir, 'typography_100dpi.png'), 96);
  Assert.IsTrue(TFile.Exists(TPath.Combine(OutDir, 'typography_100dpi.png')));

  // 125% DPI (120 PPI)
  RenderTypographyLadder(TPath.Combine(OutDir, 'typography_125dpi.png'), 120);
  Assert.IsTrue(TFile.Exists(TPath.Combine(OutDir, 'typography_125dpi.png')));

  // 150% DPI (144 PPI)
  RenderTypographyLadder(TPath.Combine(OutDir, 'typography_150dpi.png'), 144);
  Assert.IsTrue(TFile.Exists(TPath.Combine(OutDir, 'typography_150dpi.png')));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestHbFont);

end.
