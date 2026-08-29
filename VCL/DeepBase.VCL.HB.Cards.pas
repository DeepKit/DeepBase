{ ============================================================================
  DeepBase.VCL.HB.Cards - HB Visual Infrastructure Business Cards & Containers

  Version: 1.0 (Delphi 13.1 on Win64)
  Description: Modern vector-rendered VCL container & business card components:
               - THbCard (ckSurface / ckSunken / ckHero / ckOutline container)
               - THbStatBig (Hero KPI metric number with trend)
               - THbListRow (High-density customer/task contact row)
               - THbEmptyState (Guidance empty state with illustration/action)
  Thread Safety: Main UI thread.
  ============================================================================ }

unit DeepBase.VCL.HB.Cards;

{$WARN IMPLICIT_STRING_CAST OFF}

interface

uses
  System.SysUtils,
  System.Classes,
  System.UITypes,
  System.UIConsts,
  System.Math,
  System.Types,
  Winapi.Windows,
  Winapi.Messages,
  Winapi.GDIPAPI,
  Winapi.GDIPOBJ,
  Vcl.Controls,
  Vcl.Graphics,
  Vcl.Forms,
  DeepBase.HB.Core,
  DeepBase.VCL.HB.Theme,
  DeepBase.VCL.HB.Controls;

type
  THbCardKind = (ckSurface, ckSunken, ckHero, ckOutline);
  THbCardRadius = (rsS, rsM, rsL);

  THbStatEmphasis = (peNormal, peHero);
  THbStatTrend = (trNone, trUp, trDown);

  { --------------------------------------------------------------------------
    THbCard - Modern container card with gradient/elevation/sunken support
    -------------------------------------------------------------------------- }
  THbCard = class(TCustomControl)
  private
    FKind: THbCardKind;
    FRadius: THbCardRadius;
    FElevation: Integer;
    procedure SetKind(Value: THbCardKind);
    procedure SetRadius(Value: THbCardRadius);
    procedure SetElevation(Value: Integer);
    procedure WMHbThemeChanged(var Message: TMessage); message WM_HB_THEME_CHANGED;
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
    procedure OnThemeChangedNotification(Sender: TObject);
  protected
    procedure Paint; override;
    function CreateRoundRectPath(const ARect: TGPRectF; ARadius: Single): TGPGraphicsPath;
    function ColorToARGB(AColor: TAlphaColor; AAlphaOverride: Byte = 0): ARGB;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property Kind: THbCardKind read FKind write SetKind default ckSurface;
    property Radius: THbCardRadius read FRadius write SetRadius default rsM;
    property Elevation: Integer read FElevation write SetElevation default 0;
    property Align;
    property Anchors;
    property Enabled;
    property Padding;
    property Visible;
  end;

  { --------------------------------------------------------------------------
    THbStatBig - KPI Metric Hero Stat Component
    -------------------------------------------------------------------------- }
  THbStatBig = class(THbCustomControl)
  private
    FValue: string;
    FCaption: string;
    FEmphasis: THbStatEmphasis;
    FTrend: THbStatTrend;
    FTrendText: string;
    procedure SetValue(const Value: string);
    procedure SetCaption(const Value: string);
    procedure SetEmphasis(Value: THbStatEmphasis);
    procedure SetTrend(Value: THbStatTrend);
    procedure SetTrendText(const Value: string);
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Value: string read FValue write SetValue;
    property Caption: string read FCaption write SetCaption;
    property Emphasis: THbStatEmphasis read FEmphasis write SetEmphasis default peHero;
    property Trend: THbStatTrend read FTrend write SetTrend default trNone;
    property TrendText: string read FTrendText write SetTrendText;
    property Enabled;
    property Visible;
  end;

  { --------------------------------------------------------------------------
    THbListRow - High-density Customer / Task List Row Component
    -------------------------------------------------------------------------- }
  THbListRow = class(THbCustomControl)
  private
    FAvatarSeed: string;
    FTitle: string;
    FBadge1Text: string;
    FBadge1Tone: THbBadgeTone;
    FBadge2Text: string;
    FBadge2Tone: THbBadgeTone;
    FContextText: string;
    FFreeButtonText: string;
    FPointsButtonText: string;
    FPointsCost: Integer;
    FDimmed: Boolean;
    FActionHoverPart: Integer; // 1=free, 2=points
    FActionPressPart: Integer;
    FOnFreeClick: TNotifyEvent;
    FOnPointsClick: TNotifyEvent;

    procedure SetAvatarSeed(const Value: string);
    procedure SetTitle(const Value: string);
    procedure SetBadge1Text(const Value: string);
    procedure SetBadge1Tone(Value: THbBadgeTone);
    procedure SetBadge2Text(const Value: string);
    procedure SetBadge2Tone(Value: THbBadgeTone);
    procedure SetContextText(const Value: string);
    procedure SetFreeButtonText(const Value: string);
    procedure SetPointsButtonText(const Value: string);
    procedure SetPointsCost(Value: Integer);
    procedure SetDimmed(Value: Boolean);
  protected
    procedure Paint; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
    function GetSeedColor(const ASeed: string): TAlphaColor;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property AvatarSeed: string read FAvatarSeed write SetAvatarSeed;
    property Title: string read FTitle write SetTitle;
    property Badge1Text: string read FBadge1Text write SetBadge1Text;
    property Badge1Tone: THbBadgeTone read FBadge1Tone write SetBadge1Tone default btDanger;
    property Badge2Text: string read FBadge2Text write SetBadge2Text;
    property Badge2Tone: THbBadgeTone read FBadge2Tone write SetBadge2Tone default btBrand;
    property ContextText: string read FContextText write SetContextText;
    property FreeButtonText: string read FFreeButtonText write SetFreeButtonText;
    property PointsButtonText: string read FPointsButtonText write SetPointsButtonText;
    property PointsCost: Integer read FPointsCost write SetPointsCost default 5;
    property Dimmed: Boolean read FDimmed write SetDimmed default False;
    property OnFreeClick: TNotifyEvent read FOnFreeClick write FOnFreeClick;
    property OnPointsClick: TNotifyEvent read FOnPointsClick write FOnPointsClick;
    property Enabled;
    property Visible;
  end;

  { --------------------------------------------------------------------------
    THbEmptyState - Guidance Empty State Component
    -------------------------------------------------------------------------- }
  THbEmptyState = class(THbCustomControl)
  private
    FGlyph: string;
    FTitle: string;
    FHint: string;
    FActionCaption: string;
    FOnActionClick: TNotifyEvent;
    FActionHovered: Boolean;
    FActionPressed: Boolean;
    procedure SetGlyph(const Value: string);
    procedure SetTitle(const Value: string);
    procedure SetHint(const Value: string);
    procedure SetActionCaption(const Value: string);
  protected
    procedure Paint; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
    function GetActionBtnRect: TGPRectF;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Glyph: string read FGlyph write SetGlyph;
    property Title: string read FTitle write SetTitle;
    property Hint: string read FHint write SetHint;
    property ActionCaption: string read FActionCaption write SetActionCaption;
    property OnActionClick: TNotifyEvent read FOnActionClick write FOnActionClick;
    property Enabled;
    property Visible;
  end;

implementation

{ --------------------------------------------------------------------------
  THbCard Implementation
  -------------------------------------------------------------------------- }

constructor THbCard.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  DoubleBuffered := True;
  ControlStyle := ControlStyle + [csAcceptsControls] - [csOpaque];
  FKind := ckSurface;
  FRadius := rsM;
  FElevation := 0;
  SetBounds(0, 0, 240, 160);
  THbTheme.AddListener(OnThemeChangedNotification);
end;

destructor THbCard.Destroy;
begin
  THbTheme.RemoveListener(OnThemeChangedNotification);
  inherited;
end;

procedure THbCard.OnThemeChangedNotification(Sender: TObject);
begin
  Invalidate;
end;

procedure THbCard.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  Message.Result := 1;
end;

procedure THbCard.WMHbThemeChanged(var Message: TMessage);
begin
  Invalidate;
end;

procedure THbCard.SetKind(Value: THbCardKind);
begin
  if FKind <> Value then
  begin
    FKind := Value;
    Invalidate;
  end;
end;

procedure THbCard.SetRadius(Value: THbCardRadius);
begin
  if FRadius <> Value then
  begin
    FRadius := Value;
    Invalidate;
  end;
end;

procedure THbCard.SetElevation(Value: Integer);
begin
  if FElevation <> Value then
  begin
    FElevation := EnsureRange(Value, 0, 3);
    Invalidate;
  end;
end;

function THbCard.ColorToARGB(AColor: TAlphaColor; AAlphaOverride: Byte): ARGB;
var
  A: Byte;
begin
  if AAlphaOverride > 0 then
    A := AAlphaOverride
  else
    A := TAlphaColorRec(AColor).A;

  Result := (A shl 24) or
            (TAlphaColorRec(AColor).R shl 16) or
            (TAlphaColorRec(AColor).G shl 8) or
            TAlphaColorRec(AColor).B;
end;

function THbCard.CreateRoundRectPath(const ARect: TGPRectF; ARadius: Single): TGPGraphicsPath;
var
  R2: Single;
begin
  Result := TGPGraphicsPath.Create;
  R2 := ARadius * 2;
  if R2 > ARect.Width then R2 := ARect.Width;
  if R2 > ARect.Height then R2 := ARect.Height;

  if R2 <= 0.1 then
  begin
    Result.AddRectangle(ARect);
    Exit;
  end;

  Result.AddArc(ARect.X, ARect.Y, R2, R2, 180, 90);
  Result.AddArc(ARect.X + ARect.Width - R2, ARect.Y, R2, R2, 270, 90);
  Result.AddArc(ARect.X + ARect.Width - R2, ARect.Y + ARect.Height - R2, R2, R2, 0, 90);
  Result.AddArc(ARect.X, ARect.Y + ARect.Height - R2, R2, R2, 90, 90);
  Result.CloseFigure;
end;

procedure THbCard.Paint;
var
  Graphics: TGPGraphics;
  Tokens: THbTokens;
  RectF: TGPRectF;
  RadiusVal: Single;
  Path: TGPGraphicsPath;
  Brush: TGPSolidBrush;
  GradBrush: TGPLinearGradientBrush;
  Pen: TGPPen;
  BgColor, BorderColor: TAlphaColor;
begin
  Tokens := THbTheme.Tokens;
  Graphics := TGPGraphics.Create(Canvas.Handle);
  try
    Graphics.SetSmoothingMode(SmoothingModeAntiAlias);

    Brush := TGPSolidBrush.Create(ColorToARGB(Tokens.Surface));
    try
      Graphics.FillRectangle(Brush, MakeRect(0.0, 0.0, Width, Height));
    finally
      Brush.Free;
    end;

    RectF := MakeRect(1.0, 1.0, Width - 2.0, Height - 2.0);

    case FRadius of
      rsS: RadiusVal := THbTheme.GetScaledDIP(Tokens.RadiusS, CurrentPPI);
      rsL: RadiusVal := THbTheme.GetScaledDIP(Tokens.RadiusL, CurrentPPI);
      else RadiusVal := THbTheme.GetScaledDIP(Tokens.RadiusM, CurrentPPI);
    end;

    Path := CreateRoundRectPath(RectF, RadiusVal);
    try
      case FKind of
        ckHero:
        begin
          // Linear gradient from HeroGradFrom to HeroGradTo
          GradBrush := TGPLinearGradientBrush.Create(
            MakeRect(0.0, 0.0, Width, Height),
            ColorToARGB(Tokens.HeroGradFrom),
            ColorToARGB(Tokens.HeroGradTo),
            LinearGradientModeForwardDiagonal
          );
          try
            Graphics.FillPath(GradBrush, Path);
          finally
            GradBrush.Free;
          end;
        end;
        ckSunken:
        begin
          BgColor := Tokens.Sunken;
          BorderColor := Tokens.Border;
          Brush := TGPSolidBrush.Create(ColorToARGB(BgColor));
          try Graphics.FillPath(Brush, Path); finally Brush.Free; end;

          Pen := TGPPen.Create(ColorToARGB(BorderColor), 1.0);
          try Graphics.DrawPath(Pen, Path); finally Pen.Free; end;
        end;
        ckOutline:
        begin
          BorderColor := Tokens.Border;
          Pen := TGPPen.Create(ColorToARGB(BorderColor), 1.0);
          try Graphics.DrawPath(Pen, Path); finally Pen.Free; end;
        end;
        else // ckSurface
        begin
          BgColor := Tokens.SurfaceAlt;
          BorderColor := Tokens.Border;
          Brush := TGPSolidBrush.Create(ColorToARGB(BgColor));
          try Graphics.FillPath(Brush, Path); finally Brush.Free; end;

          Pen := TGPPen.Create(ColorToARGB(BorderColor), 1.0);
          try Graphics.DrawPath(Pen, Path); finally Pen.Free; end;
        end;
      end;
    finally
      Path.Free;
    end;
  finally
    Graphics.Free;
  end;
end;

{ --------------------------------------------------------------------------
  THbStatBig Implementation
  -------------------------------------------------------------------------- }

constructor THbStatBig.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FValue := '43';
  FCaption := '沉睡高价值客户';
  FEmphasis := peHero;
  FTrend := trNone;
  FTrendText := '';
  SetBounds(0, 0, ScalePixels(140), ScalePixels(64));
end;

procedure THbStatBig.SetValue(const Value: string);
begin
  if FValue <> Value then
  begin
    FValue := Value;
    Invalidate;
  end;
end;

procedure THbStatBig.SetCaption(const Value: string);
begin
  if FCaption <> Value then
  begin
    FCaption := Value;
    Invalidate;
  end;
end;

procedure THbStatBig.SetEmphasis(Value: THbStatEmphasis);
begin
  if FEmphasis <> Value then
  begin
    FEmphasis := Value;
    Invalidate;
  end;
end;

procedure THbStatBig.SetTrend(Value: THbStatTrend);
begin
  if FTrend <> Value then
  begin
    FTrend := Value;
    Invalidate;
  end;
end;

procedure THbStatBig.SetTrendText(const Value: string);
begin
  if FTrendText <> Value then
  begin
    FTrendText := Value;
    Invalidate;
  end;
end;

procedure THbStatBig.Paint;
var
  Graphics: TGPGraphics;
  Tokens: THbTokens;
  FontFamily: TGPFontFamily;
  ValFont, CapFont: TGPFont;
  StrFmt: TGPStringFormat;
  ValBrush, CapBrush: TGPSolidBrush;
  ValColor: TAlphaColor;
  ValHeight: Single;
begin
  Tokens := GetTokens;
  Graphics := TGPGraphics.Create(Canvas.Handle);
  try
    Graphics.SetSmoothingMode(SmoothingModeAntiAlias);
    Graphics.SetTextRenderingHint(TextRenderingHintClearTypeGridFit);
    EraseBackground(Graphics);

    if FEmphasis = peHero then
      ValColor := Tokens.Primary
    else
      ValColor := Tokens.Ink;

    FontFamily := TGPFontFamily.Create(Tokens.FontFamily);
    try
      ValHeight := ScaleDIP(Tokens.SizeXXL);
      ValFont := TGPFont.Create(FontFamily, ValHeight, FontStyleBold, UnitPixel);
      CapFont := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeXS), FontStyleRegular, UnitPixel);
      try
        StrFmt := TGPStringFormat.Create;
        try
          StrFmt.SetAlignment(StringAlignmentNear);
          StrFmt.SetLineAlignment(StringAlignmentNear);

          // 1. Draw Large Number Value
          ValBrush := TGPSolidBrush.Create(ColorToARGB(ValColor));
          try
            Graphics.DrawString(FValue, -1, ValFont, MakeRect(0.0, 0.0, Width, ValHeight * 1.1), StrFmt, ValBrush);
          finally
            ValBrush.Free;
          end;

          // 2. Draw Caption
          CapBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.InkMuted));
          try
            Graphics.DrawString(FCaption, -1, CapFont, MakeRect(0.0, ValHeight * 1.1 + ScaleDIP(Tokens.SpaceXS * 0.5), Width, Height - ValHeight * 1.1), StrFmt, CapBrush);
          finally
            CapBrush.Free;
          end;
        finally
          StrFmt.Free;
        end;
      finally
        CapFont.Free;
        ValFont.Free;
      end;
    finally
      FontFamily.Free;
    end;
  finally
    Graphics.Free;
  end;
end;

{ --------------------------------------------------------------------------
  THbListRow Implementation
  -------------------------------------------------------------------------- }

constructor THbListRow.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FAvatarSeed := '张';
  FTitle := '张姐';
  FBadge1Text := '失联97天';
  FBadge1Tone := btDanger;
  FBadge2Text := '';
  FBadge2Tone := btBrand;
  FContextText := '上次：问完价格没回她 · 历史成交 2 单';
  FFreeButtonText := '开场白 · 免费';
  FPointsButtonText := 'AI 方案';
  FPointsCost := 5;
  FDimmed := False;
  FActionHoverPart := 0;
  FActionPressPart := 0;
  SetBounds(0, 0, ScalePixels(420), ScalePixels(56));
end;

procedure THbListRow.SetAvatarSeed(const Value: string);
begin
  if FAvatarSeed <> Value then
  begin
    FAvatarSeed := Value;
    Invalidate;
  end;
end;

procedure THbListRow.SetTitle(const Value: string);
begin
  if FTitle <> Value then
  begin
    FTitle := Value;
    Invalidate;
  end;
end;

procedure THbListRow.SetBadge1Text(const Value: string);
begin
  if FBadge1Text <> Value then
  begin
    FBadge1Text := Value;
    Invalidate;
  end;
end;

procedure THbListRow.SetBadge1Tone(Value: THbBadgeTone);
begin
  if FBadge1Tone <> Value then
  begin
    FBadge1Tone := Value;
    Invalidate;
  end;
end;

procedure THbListRow.SetBadge2Text(const Value: string);
begin
  if FBadge2Text <> Value then
  begin
    FBadge2Text := Value;
    Invalidate;
  end;
end;

procedure THbListRow.SetBadge2Tone(Value: THbBadgeTone);
begin
  if FBadge2Tone <> Value then
  begin
    FBadge2Tone := Value;
    Invalidate;
  end;
end;

procedure THbListRow.SetContextText(const Value: string);
begin
  if FContextText <> Value then
  begin
    FContextText := Value;
    Invalidate;
  end;
end;

procedure THbListRow.SetFreeButtonText(const Value: string);
begin
  if FFreeButtonText <> Value then
  begin
    FFreeButtonText := Value;
    Invalidate;
  end;
end;

procedure THbListRow.SetPointsButtonText(const Value: string);
begin
  if FPointsButtonText <> Value then
  begin
    FPointsButtonText := Value;
    Invalidate;
  end;
end;

procedure THbListRow.SetPointsCost(Value: Integer);
begin
  if FPointsCost <> Value then
  begin
    FPointsCost := Value;
    Invalidate;
  end;
end;

procedure THbListRow.SetDimmed(Value: Boolean);
begin
  if FDimmed <> Value then
  begin
    FDimmed := Value;
    Invalidate;
  end;
end;

function THbListRow.GetSeedColor(const ASeed: string): TAlphaColor;
var
  Hash: Cardinal;
  C: Char;
  Tokens: THbTokens;
begin
  Tokens := GetTokens;
  Hash := 5381;
  for C in ASeed do
    Hash := ((Hash shl 5) + Hash) + Ord(C);

  case (Hash mod 4) of
    0: Result := Tokens.Soft;
    1: Result := Tokens.SuccessSoft;
    2: Result := Tokens.WarningSoft;
    else Result := Tokens.InfoSoft;
  end;
end;

procedure THbListRow.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  BtnAreaStart: Single;
  NewPart: Integer;
begin
  inherited;
  BtnAreaStart := Width - ScalePixels(190);
  if X >= BtnAreaStart then
  begin
    if X < (BtnAreaStart + ScalePixels(90)) then
      NewPart := 1
    else
      NewPart := 2;
  end
  else
    NewPart := 0;

  if FActionHoverPart <> NewPart then
  begin
    FActionHoverPart := NewPart;
    Invalidate;
  end;
end;

procedure THbListRow.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if (Button = mbLeft) and Enabled then
  begin
    FActionPressPart := FActionHoverPart;
    Invalidate;
  end;
end;

procedure THbListRow.CMMouseLeave(var Message: TMessage);
begin
  inherited;
  FActionHoverPart := 0;
  FActionPressPart := 0;
  Invalidate;
end;

procedure THbListRow.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if Button = mbLeft then
  begin
    if (FActionPressPart = 1) and (FActionHoverPart = 1) and Assigned(FOnFreeClick) then
      FOnFreeClick(Self)
    else if (FActionPressPart = 2) and (FActionHoverPart = 2) and Assigned(FOnPointsClick) then
      FOnPointsClick(Self);
    FActionPressPart := 0;
    Invalidate;
  end;
end;

procedure THbListRow.Paint;
var
  Graphics: TGPGraphics;
  Tokens: THbTokens;
  RowRect: TGPRectF;
  Path: TGPGraphicsPath;
  Brush: TGPSolidBrush;
  Pen: TGPPen;
  FontFamily: TGPFontFamily;
  TitleFont, SubFont, BtnFont: TGPFont;
  StrFmt: TGPStringFormat;
  TextBrush: TGPSolidBrush;
  AlphaMult: Single;
begin
  Tokens := GetTokens;
  Graphics := TGPGraphics.Create(Canvas.Handle);
  try
    Graphics.SetSmoothingMode(SmoothingModeAntiAlias);
    Graphics.SetTextRenderingHint(TextRenderingHintClearTypeGridFit);

    Brush := TGPSolidBrush.Create(ColorToARGB(Tokens.Surface));
    try
      Graphics.FillRectangle(Brush, MakeRect(0.0, 0.0, Width, Height));
    finally
      Brush.Free;
    end;

    RowRect := MakeRect(1.0, 1.0, Width - 2.0, Height - 2.0);
    AlphaMult := 1.0;
    if FDimmed then
      AlphaMult := 0.6;

    // 1. Draw Row Background
    Path := CreateRoundRectPath(RowRect, ScaleDIP(Tokens.RadiusM));
    try
      Brush := TGPSolidBrush.Create(ColorToARGB(Tokens.SurfaceAlt, Round(255 * AlphaMult)));
      try Graphics.FillPath(Brush, Path); finally Brush.Free; end;

      Pen := TGPPen.Create(ColorToARGB(Tokens.Border, Round(255 * AlphaMult)), 1.0);
      try Graphics.DrawPath(Pen, Path); finally Pen.Free; end;
    finally
      Path.Free;
    end;

    // 2. Draw Avatar
    var AvSize := ScaleDIP(Tokens.SpaceXL);
    var AvRect := MakeRect(ScaleDIP(Tokens.SpaceM), (Height - AvSize) * 0.5, AvSize, AvSize);
    Brush := TGPSolidBrush.Create(ColorToARGB(GetSeedColor(FAvatarSeed), Round(255 * AlphaMult)));
    try
      Graphics.FillEllipse(Brush, AvRect);
    finally
      Brush.Free;
    end;

    FontFamily := TGPFontFamily.Create(Tokens.FontFamily);
    try
      TitleFont := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeS), FontStyleBold, UnitPixel);
      SubFont := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeXS * 0.95), FontStyleRegular, UnitPixel);
      BtnFont := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeXS * 0.9), FontStyleBold, UnitPixel);
      try
        StrFmt := TGPStringFormat.Create;
        try
          StrFmt.SetAlignment(StringAlignmentCenter);
          StrFmt.SetLineAlignment(StringAlignmentCenter);

          // Avatar Initial Text
          TextBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.Primary, Round(255 * AlphaMult)));
          try
            var Initial := FTitle;
            if Initial.Length > 0 then Initial := Initial.Substring(0, 1);
            Graphics.DrawString(Initial, -1, TitleFont, AvRect, StrFmt, TextBrush);
          finally
            TextBrush.Free;
          end;

          // 3. Draw Title Text
          StrFmt.SetAlignment(StringAlignmentNear);
          var ContentX := AvRect.X + AvSize + ScaleDIP(Tokens.SpaceM);
          TextBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.Ink, Round(255 * AlphaMult)));
          try
            Graphics.DrawString(FTitle, -1, TitleFont, MakeRect(ContentX, ScaleDIP(Tokens.SpaceS), ScaleDIP(120), ScaleDIP(18)), StrFmt, TextBrush);
          finally
            TextBrush.Free;
          end;

          // 4. Draw Badge 1 (if present)
          if FBadge1Text <> '' then
          begin
            var BadgeRect := MakeRect(ContentX + ScaleDIP(50), ScaleDIP(Tokens.SpaceS), ScaleDIP(60), ScaleDIP(16));
            var BadgePath := CreateRoundRectPath(BadgeRect, ScaleDIP(Tokens.SpaceXS));
            try
              Brush := TGPSolidBrush.Create(ColorToARGB(Tokens.DangerSoft, Round(255 * AlphaMult)));
              try Graphics.FillPath(Brush, BadgePath); finally Brush.Free; end;
            finally
              BadgePath.Free;
            end;

            StrFmt.SetAlignment(StringAlignmentCenter);
            TextBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.Danger, Round(255 * AlphaMult)));
            try
              Graphics.DrawString(FBadge1Text, -1, SubFont, BadgeRect, StrFmt, TextBrush);
            finally
              TextBrush.Free;
            end;
          end;

          // 5. Draw Context Subtitle Text
          StrFmt.SetAlignment(StringAlignmentNear);
          TextBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.InkMuted, Round(255 * AlphaMult)));
          try
            Graphics.DrawString(FContextText, -1, SubFont, MakeRect(ContentX, ScaleDIP(Tokens.SpaceL + Tokens.SpaceS * 0.75), Width - ContentX - ScaleDIP(195), ScaleDIP(20)), StrFmt, TextBrush);
          finally
            TextBrush.Free;
          end;

          // 6. Draw Right Dual Buttons
          var BtnH := ScaleDIP(26);
          var BtnY := (Height - BtnH) * 0.5;
          var FreeBtnRect := MakeRect(Width - ScaleDIP(185), BtnY, ScaleDIP(85), BtnH);
          var PointsBtnRect := MakeRect(Width - ScaleDIP(95), BtnY, ScaleDIP(85), BtnH);

          // Free Button (Ghost Success)
          var FreePath := CreateRoundRectPath(FreeBtnRect, BtnH * 0.5);
          try
            Pen := TGPPen.Create(ColorToARGB(Tokens.Success, Round(255 * AlphaMult)), 1.0);
            try Graphics.DrawPath(Pen, FreePath); finally Pen.Free; end;
          finally
            FreePath.Free;
          end;

          StrFmt.SetAlignment(StringAlignmentCenter);
          TextBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.Success, Round(255 * AlphaMult)));
          try Graphics.DrawString(FFreeButtonText, -1, BtnFont, FreeBtnRect, StrFmt, TextBrush); finally TextBrush.Free; end;

          // Points Button (Solid Gold)
          var PointsPath := CreateRoundRectPath(PointsBtnRect, BtnH * 0.5);
          try
            Brush := TGPSolidBrush.Create(ColorToARGB(Tokens.Primary, Round(255 * AlphaMult)));
            try Graphics.FillPath(Brush, PointsPath); finally Brush.Free; end;
          finally
            PointsPath.Free;
          end;

          TextBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.OnPrimary, Round(255 * AlphaMult)));
          try
            var PtLabel := Format('%s · %d点', [FPointsButtonText, FPointsCost]);
            Graphics.DrawString(PtLabel, -1, BtnFont, PointsBtnRect, StrFmt, TextBrush);
          finally
            TextBrush.Free;
          end;
        finally
          StrFmt.Free;
        end;
      finally
        BtnFont.Free;
        SubFont.Free;
        TitleFont.Free;
      end;
    finally
      FontFamily.Free;
    end;
  finally
    Graphics.Free;
  end;
end;

{ --------------------------------------------------------------------------
  THbEmptyState Implementation
  -------------------------------------------------------------------------- }

constructor THbEmptyState.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FGlyph := '🪙';
  FTitle := '还没有沉睡客户';
  FHint := '你的联系人都在活跃期，这是好事';
  FActionCaption := '去邀请朋友扫描';
  FActionHovered := False;
  FActionPressed := False;
  SetBounds(0, 0, ScalePixels(300), ScalePixels(160));
end;

procedure THbEmptyState.SetGlyph(const Value: string);
begin
  if FGlyph <> Value then
  begin
    FGlyph := Value;
    Invalidate;
  end;
end;

procedure THbEmptyState.SetTitle(const Value: string);
begin
  if FTitle <> Value then
  begin
    FTitle := Value;
    Invalidate;
  end;
end;

procedure THbEmptyState.SetHint(const Value: string);
begin
  if FHint <> Value then
  begin
    FHint := Value;
    Invalidate;
  end;
end;

procedure THbEmptyState.SetActionCaption(const Value: string);
begin
  if FActionCaption <> Value then
  begin
    FActionCaption := Value;
    Invalidate;
  end;
end;

function THbEmptyState.GetActionBtnRect: TGPRectF;
var
  BtnW, BtnH: Single;
begin
  BtnW := ScaleDIP(130);
  BtnH := ScaleDIP(32);
  Result := MakeRect((Width - BtnW) * 0.5, Height - BtnH - ScaleDIP(12), BtnW, BtnH);
end;

procedure THbEmptyState.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  BtnRect: TGPRectF;
  Hover: Boolean;
begin
  inherited;
  BtnRect := GetActionBtnRect;
  Hover := (X >= BtnRect.X) and (X <= BtnRect.X + BtnRect.Width) and
           (Y >= BtnRect.Y) and (Y <= BtnRect.Y + BtnRect.Height);

  if FActionHovered <> Hover then
  begin
    FActionHovered := Hover;
    Invalidate;
  end;
end;

procedure THbEmptyState.CMMouseLeave(var Message: TMessage);
begin
  inherited;
  FActionHovered := False;
  FActionPressed := False;
  Invalidate;
end;

procedure THbEmptyState.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if (Button = mbLeft) and FActionHovered then
  begin
    FActionPressed := True;
    Invalidate;
  end;
end;

procedure THbEmptyState.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if (Button = mbLeft) and FActionPressed and FActionHovered then
  begin
    FActionPressed := False;
    Invalidate;
    if Assigned(FOnActionClick) then
      FOnActionClick(Self);
  end
  else
  begin
    FActionPressed := False;
    Invalidate;
  end;
end;

procedure THbEmptyState.Paint;
var
  Graphics: TGPGraphics;
  Tokens: THbTokens;
  FontFamily: TGPFontFamily;
  GlyphFont, TitleFont, HintFont, BtnFont: TGPFont;
  StrFmt: TGPStringFormat;
  TextBrush: TGPSolidBrush;
  BtnRect: TGPRectF;
  BtnPath: TGPGraphicsPath;
  BtnBrush: TGPSolidBrush;
  BrushBg: TGPSolidBrush;
begin
  Tokens := GetTokens;
  Graphics := TGPGraphics.Create(Canvas.Handle);
  try
    Graphics.SetSmoothingMode(SmoothingModeAntiAlias);
    Graphics.SetTextRenderingHint(TextRenderingHintClearTypeGridFit);

    BrushBg := TGPSolidBrush.Create(ColorToARGB(Tokens.Surface));
    try
      Graphics.FillRectangle(BrushBg, MakeRect(0.0, 0.0, Width, Height));
    finally
      BrushBg.Free;
    end;

    FontFamily := TGPFontFamily.Create(Tokens.FontFamily);
    try
      GlyphFont := TGPFont.Create(FontFamily, ScaleDIP(28), FontStyleRegular, UnitPixel);
      TitleFont := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeM), FontStyleBold, UnitPixel);
      HintFont := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeXS), FontStyleRegular, UnitPixel);
      BtnFont := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeXS), FontStyleBold, UnitPixel);
      try
        StrFmt := TGPStringFormat.Create;
        try
          StrFmt.SetAlignment(StringAlignmentCenter);
          StrFmt.SetLineAlignment(StringAlignmentCenter);

          // 1. Draw Emoji Glyph
          TextBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.Primary));
          try
            Graphics.DrawString(FGlyph, -1, GlyphFont, MakeRect(0.0, ScaleDIP(8), Width, ScaleDIP(36)), StrFmt, TextBrush);
          finally
            TextBrush.Free;
          end;

          // 2. Draw Title
          TextBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.Ink));
          try
            Graphics.DrawString(FTitle, -1, TitleFont, MakeRect(0.0, ScaleDIP(46), Width, ScaleDIP(22)), StrFmt, TextBrush);
          finally
            TextBrush.Free;
          end;

          // 3. Draw Hint
          TextBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.InkMuted));
          try
            Graphics.DrawString(FHint, -1, HintFont, MakeRect(0.0, ScaleDIP(70), Width, ScaleDIP(20)), StrFmt, TextBrush);
          finally
            TextBrush.Free;
          end;

          // 4. Draw Action Button (Soft Pill)
          if FActionCaption <> '' then
          begin
            BtnRect := GetActionBtnRect;
            BtnPath := CreateRoundRectPath(BtnRect, BtnRect.Height * 0.5);
            try
              var BgCol := Tokens.Soft;
              if FActionPressed then
                BgCol := Tokens.PrimaryPressed
              else if FActionHovered then
                BgCol := Tokens.PrimaryHover;

              BtnBrush := TGPSolidBrush.Create(ColorToARGB(BgCol));
              try
                Graphics.FillPath(BtnBrush, BtnPath);
              finally
                BtnBrush.Free;
              end;
            finally
              BtnPath.Free;
            end;

            var TextCol := Tokens.Primary;
            if FActionPressed or FActionHovered then
              TextCol := Tokens.OnPrimary;

            TextBrush := TGPSolidBrush.Create(ColorToARGB(TextCol));
            try
              Graphics.DrawString(FActionCaption, -1, BtnFont, BtnRect, StrFmt, TextBrush);
            finally
              TextBrush.Free;
            end;
          end;
        finally
          StrFmt.Free;
        end;
      finally
        BtnFont.Free;
        HintFont.Free;
        TitleFont.Free;
        GlyphFont.Free;
      end;
    finally
      FontFamily.Free;
    end;
  finally
    Graphics.Free;
  end;
end;

end.
