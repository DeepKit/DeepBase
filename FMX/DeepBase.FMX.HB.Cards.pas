{ ============================================================================
  DeepBase.FMX.HB.Cards - Composite Cards & Containers for FireMonkey

  Version: 1.0 (Delphi 13.1 on Win64 / Cross-Platform FMX)
  Description: Composite business cards and container components for HB Visual
               Infrastructure in FireMonkey (THbCard, THbStatBig, THbListRow,
               THbEmptyState) with full Design Token integration.
  ============================================================================ }

unit DeepBase.FMX.HB.Cards;

interface

uses
  System.SysUtils,
  System.Classes,
  System.UITypes,
  System.Types,
  System.Math,
  FMX.Types,
  FMX.Controls,
  FMX.Graphics,
  FMX.Objects,
  DeepBase.HB.Core,
  DeepBase.FMX.HB.Controls;

type
  THbCardKind = (ckSurface, ckSunken, ckHero, ckOutline);
  THbCardRadius = (rdS, rdM, rdL);
  THbCardElevation = (elNone, elLow, elMedium, elHigh);
  THbStatEmphasis = (peNormal, peHero);
  THbListRowHoverBtn = (hbNone, hbFree, hbPoints);

  /// <summary>
  /// THbCard: Container supporting Surface, Sunken, Hero gradient, and Outline modes.
  /// </summary>
  THbCard = class(THbFmxControl)
  private
    FKind: THbCardKind;
    FRadiusKind: THbCardRadius;
    FElevation: THbCardElevation;
    procedure SetKind(const Value: THbCardKind);
    procedure SetRadiusKind(const Value: THbCardRadius);
    procedure SetElevation(const Value: THbCardElevation);
  protected
    procedure DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Align;
    property Anchors;
    property Elevation: THbCardElevation read FElevation write SetElevation default elNone;
    property Enabled;
    property Kind: THbCardKind read FKind write SetKind default ckSurface;
    property RadiusKind: THbCardRadius read FRadiusKind write SetRadiusKind default rdM;
    property Visible;
  end;

  /// <summary>
  /// THbStatBig: Prominent KPI metric display with trend indicator.
  /// </summary>
  THbStatBig = class(THbFmxControl)
  private
    FValue: string;
    FCaption: string;
    FEmphasis: THbStatEmphasis;
    FTrendText: string;
    FTrendUp: Boolean;
    procedure SetValue(const Value: string);
    procedure SetCaption(const Value: string);
    procedure SetEmphasis(const Value: THbStatEmphasis);
    procedure SetTrendText(const Value: string);
    procedure SetTrendUp(const Value: Boolean);
  protected
    procedure DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Align;
    property Anchors;
    property Caption: string read FCaption write SetCaption;
    property Emphasis: THbStatEmphasis read FEmphasis write SetEmphasis default peNormal;
    property TrendText: string read FTrendText write SetTrendText;
    property TrendUp: Boolean read FTrendUp write SetTrendUp default True;
    property Value: string read FValue write SetValue;
    property Visible;
  end;

  /// <summary>
  /// THbListRow: High-density contact/task list row with avatar, tags, and action buttons.
  /// </summary>
  THbListRow = class(THbFmxControl)
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
    FHoverBtn: THbListRowHoverBtn;
    FOnFreeClick: TNotifyEvent;
    FOnPointsClick: TNotifyEvent;
    procedure SetAvatarSeed(const Value: string);
    procedure SetTitle(const Value: string);
    procedure SetBadge1Text(const Value: string);
    procedure SetBadge1Tone(const Value: THbBadgeTone);
    procedure SetBadge2Text(const Value: string);
    procedure SetBadge2Tone(const Value: THbBadgeTone);
    procedure SetContextText(const Value: string);
    procedure SetFreeButtonText(const Value: string);
    procedure SetPointsButtonText(const Value: string);
    procedure SetPointsCost(const Value: Integer);
    procedure SetDimmed(const Value: Boolean);
    function HashSeedToColor(const ASeed: string): TAlphaColor;
  protected
    procedure MouseMove(Shift: TShiftState; X, Y: Single); override;
    procedure DoMouseLeave; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Align;
    property Anchors;
    property AvatarSeed: string read FAvatarSeed write SetAvatarSeed;
    property Badge1Text: string read FBadge1Text write SetBadge1Text;
    property Badge1Tone: THbBadgeTone read FBadge1Tone write SetBadge1Tone default btDanger;
    property Badge2Text: string read FBadge2Text write SetBadge2Text;
    property Badge2Tone: THbBadgeTone read FBadge2Tone write SetBadge2Tone default btBrand;
    property ContextText: string read FContextText write SetContextText;
    property Dimmed: Boolean read FDimmed write SetDimmed default False;
    property Enabled;
    property FreeButtonText: string read FFreeButtonText write SetFreeButtonText;
    property PointsButtonText: string read FPointsButtonText write SetPointsButtonText;
    property PointsCost: Integer read FPointsCost write SetPointsCost default 5;
    property Title: string read FTitle write SetTitle;
    property Visible;
    property OnFreeClick: TNotifyEvent read FOnFreeClick write FOnFreeClick;
    property OnPointsClick: TNotifyEvent read FOnPointsClick write FOnPointsClick;
  end;

  /// <summary>
  /// THbEmptyState: Empty placeholder card with glyph, title, hint, and CTA action.
  /// </summary>
  THbEmptyState = class(THbFmxControl)
  private
    FGlyph: string;
    FTitle: string;
    FHintText: string;
    FActionCaption: string;
    FHoverAction: Boolean;
    FOnActionClick: TNotifyEvent;
    procedure SetGlyph(const Value: string);
    procedure SetTitle(const Value: string);
    procedure SetHintText(const Value: string);
    procedure SetActionCaption(const Value: string);
  protected
    procedure MouseMove(Shift: TShiftState; X, Y: Single); override;
    procedure DoMouseLeave; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property ActionCaption: string read FActionCaption write SetActionCaption;
    property Align;
    property Anchors;
    property Enabled;
    property Glyph: string read FGlyph write SetGlyph;
    property HintText: string read FHintText write SetHintText;
    property Title: string read FTitle write SetTitle;
    property Visible;
    property OnActionClick: TNotifyEvent read FOnActionClick write FOnActionClick;
  end;

implementation

{ THbCard }

constructor THbCard.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FKind := ckSurface;
  FRadiusKind := rdM;
  FElevation := elNone;
  Width := 200;
  Height := 120;
end;

procedure THbCard.SetKind(const Value: THbCardKind);
begin
  if FKind <> Value then
  begin
    FKind := Value;
    Repaint;
  end;
end;

procedure THbCard.SetRadiusKind(const Value: THbCardRadius);
begin
  if FRadiusKind <> Value then
  begin
    FRadiusKind := Value;
    Repaint;
  end;
end;

procedure THbCard.SetElevation(const Value: THbCardElevation);
begin
  if FElevation <> Value then
  begin
    FElevation := Value;
    Repaint;
  end;
end;

procedure THbCard.DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens);
var
  R, ShadowR: TRectF;
  Radius: Single;
  BgColor, BorderColor, ShadowColor: TAlphaColor;
  Grad: TGradient;
begin
  R := ARect;
  R.Inflate(-1, -1);

  case FRadiusKind of
    rdS: Radius := Tokens.RadiusS;
    rdL: Radius := Tokens.RadiusL;
    else Radius := Tokens.RadiusM;
  end;

  // Drop Shadow
  if FElevation <> elNone then
  begin
    case FElevation of
      elHigh:   ShadowColor := Tokens.Elevation3;
      elMedium: ShadowColor := Tokens.Elevation2;
      else      ShadowColor := Tokens.Elevation1;
    end;
    ShadowR := R;
    ShadowR.Offset(0, 2);
    Canvas.Fill.Color := ShadowColor;
    Canvas.Fill.Kind := TBrushKind.Solid;
    Canvas.FillRect(ShadowR, Radius, Radius, AllCorners, 1.0);
  end;

  // Background and Border
  case FKind of
    ckHero:
      begin
        Grad := TGradient.Create;
        try
          Grad.Color := Tokens.HeroGradFrom;
          Grad.Color1 := Tokens.HeroGradTo;
          Grad.StartPosition.Point := TPointF.Create(0, 0);
          Grad.StopPosition.Point := TPointF.Create(1, 1);
          Canvas.Fill.Kind := TBrushKind.Gradient;
          Canvas.Fill.Gradient.Assign(Grad);
          Canvas.FillRect(R, Radius, Radius, AllCorners, 1.0);
        finally
          Grad.Free;
        end;
        BorderColor := TAlphaColors.Null;
      end;
    ckSunken:
      begin
        BgColor := Tokens.Sunken;
        BorderColor := Tokens.Border;
        Canvas.Fill.Color := BgColor;
        Canvas.Fill.Kind := TBrushKind.Solid;
        Canvas.FillRect(R, Radius, Radius, AllCorners, 1.0);
      end;
    ckOutline:
      begin
        BorderColor := Tokens.Border;
      end;
    else // ckSurface
      begin
        BgColor := Tokens.Surface;
        BorderColor := Tokens.Border;
        Canvas.Fill.Color := BgColor;
        Canvas.Fill.Kind := TBrushKind.Solid;
        Canvas.FillRect(R, Radius, Radius, AllCorners, 1.0);
      end;
  end;

  if BorderColor <> TAlphaColors.Null then
  begin
    Canvas.Stroke.Color := BorderColor;
    Canvas.Stroke.Thickness := Tokens.BorderWidth;
    Canvas.Stroke.Kind := TBrushKind.Solid;
    Canvas.DrawRect(R, Radius, Radius, AllCorners, 1.0);
  end;
end;

{ THbStatBig }

constructor THbStatBig.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FValue := '0';
  FCaption := 'Metric';
  FEmphasis := peNormal;
  FTrendText := '';
  FTrendUp := True;
  Width := 160;
  Height := 64;
end;

procedure THbStatBig.SetValue(const Value: string);
begin
  if FValue <> Value then
  begin
    FValue := Value;
    Repaint;
  end;
end;

procedure THbStatBig.SetCaption(const Value: string);
begin
  if FCaption <> Value then
  begin
    FCaption := Value;
    Repaint;
  end;
end;

procedure THbStatBig.SetEmphasis(const Value: THbStatEmphasis);
begin
  if FEmphasis <> Value then
  begin
    FEmphasis := Value;
    Repaint;
  end;
end;

procedure THbStatBig.SetTrendText(const Value: string);
begin
  if FTrendText <> Value then
  begin
    FTrendText := Value;
    Repaint;
  end;
end;

procedure THbStatBig.SetTrendUp(const Value: Boolean);
begin
  if FTrendUp <> Value then
  begin
    FTrendUp := Value;
    Repaint;
  end;
end;

procedure THbStatBig.DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens);
var
  R, ValR, CapR, TrendR: TRectF;
  ValColor, CapColor, TrendColor: TAlphaColor;
  TrendSymbol: string;
begin
  R := ARect;
  ValR := TRectF.Create(R.Left, R.Top, R.Right, R.Top + R.Height * 0.58);
  CapR := TRectF.Create(R.Left, R.Top + R.Height * 0.58, R.Right, R.Bottom);

  if FEmphasis = peHero then
  begin
    ValColor := Tokens.OnPrimary;
    CapColor := $CCFFFFFF;
  end
  else
  begin
    ValColor := Tokens.Primary;
    CapColor := Tokens.InkMuted;
  end;

  // Value
  Canvas.Fill.Color := ValColor;
  Canvas.Font.Family := Tokens.FontFamily;
  Canvas.Font.Size := Tokens.SizeXXL;
  Canvas.Font.Style := [TFontStyle.fsBold];
  Canvas.FillText(ValR, FValue, False, 1.0, [], TTextAlign.Leading, TTextAlign.Center);

  // Caption
  Canvas.Fill.Color := CapColor;
  Canvas.Font.Size := Tokens.SizeS;
  Canvas.Font.Style := [];
  Canvas.FillText(CapR, FCaption, False, 1.0, [], TTextAlign.Leading, TTextAlign.Center);

  // Trend
  if FTrendText <> '' then
  begin
    if FTrendUp then
    begin
      TrendColor := Tokens.Success;
      TrendSymbol := #$2191 + ' ';
    end
    else
    begin
      TrendColor := Tokens.Danger;
      TrendSymbol := #$2193 + ' ';
    end;

    TrendR := TRectF.Create(R.Right - 60, R.Top + 4, R.Right, R.Top + 24);
    Canvas.Fill.Color := TrendColor;
    Canvas.Font.Size := Tokens.SizeXS;
    Canvas.Font.Style := [TFontStyle.fsBold];
    Canvas.FillText(TrendR, TrendSymbol + FTrendText, False, 1.0, [], TTextAlign.Trailing, TTextAlign.Center);
  end;
end;

{ THbListRow }

constructor THbListRow.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FAvatarSeed := 'A';
  FTitle := 'Contact';
  FBadge1Text := '';
  FBadge1Tone := btDanger;
  FBadge2Text := '';
  FBadge2Tone := btBrand;
  FContextText := '';
  FFreeButtonText := '开场白 · 免费';
  FPointsButtonText := 'AI 方案';
  FPointsCost := 5;
  FDimmed := False;
  FHoverBtn := hbNone;
  Width := 460;
  Height := 56;
end;

procedure THbListRow.SetAvatarSeed(const Value: string);
begin
  if FAvatarSeed <> Value then
  begin
    FAvatarSeed := Value;
    Repaint;
  end;
end;

procedure THbListRow.SetTitle(const Value: string);
begin
  if FTitle <> Value then
  begin
    FTitle := Value;
    Repaint;
  end;
end;

procedure THbListRow.SetBadge1Text(const Value: string);
begin
  if FBadge1Text <> Value then
  begin
    FBadge1Text := Value;
    Repaint;
  end;
end;

procedure THbListRow.SetBadge1Tone(const Value: THbBadgeTone);
begin
  if FBadge1Tone <> Value then
  begin
    FBadge1Tone := Value;
    Repaint;
  end;
end;

procedure THbListRow.SetBadge2Text(const Value: string);
begin
  if FBadge2Text <> Value then
  begin
    FBadge2Text := Value;
    Repaint;
  end;
end;

procedure THbListRow.SetBadge2Tone(const Value: THbBadgeTone);
begin
  if FBadge2Tone <> Value then
  begin
    FBadge2Tone := Value;
    Repaint;
  end;
end;

procedure THbListRow.SetContextText(const Value: string);
begin
  if FContextText <> Value then
  begin
    FContextText := Value;
    Repaint;
  end;
end;

procedure THbListRow.SetFreeButtonText(const Value: string);
begin
  if FFreeButtonText <> Value then
  begin
    FFreeButtonText := Value;
    Repaint;
  end;
end;

procedure THbListRow.SetPointsButtonText(const Value: string);
begin
  if FPointsButtonText <> Value then
  begin
    FPointsButtonText := Value;
    Repaint;
  end;
end;

procedure THbListRow.SetPointsCost(const Value: Integer);
begin
  if FPointsCost <> Value then
  begin
    FPointsCost := Value;
    Repaint;
  end;
end;

procedure THbListRow.SetDimmed(const Value: Boolean);
begin
  if FDimmed <> Value then
  begin
    FDimmed := Value;
    Repaint;
  end;
end;

function THbListRow.HashSeedToColor(const ASeed: string): TAlphaColor;
var
  H: Cardinal;
  C: Char;
  Colors: array[0..7] of TAlphaColor;
begin
  Colors[0] := $FFD97706;
  Colors[1] := $FF2563EB;
  Colors[2] := $FF059669;
  Colors[3] := $FFE11D48;
  Colors[4] := $FF7C3AED;
  Colors[5] := $FF0891B2;
  Colors[6] := $FFEA580C;
  Colors[7] := $FF4F46E5;

  H := 0;
  for C in ASeed do
    H := (H * 31) + Ord(C);

  Result := Colors[H mod 8];
end;

procedure THbListRow.MouseMove(Shift: TShiftState; X, Y: Single);
var
  OldBtn: THbListRowHoverBtn;
begin
  inherited MouseMove(Shift, X, Y);
  OldBtn := FHoverBtn;

  if (Y >= 12) and (Y <= 44) then
  begin
    if (X >= Width - 190) and (X < Width - 100) then
      FHoverBtn := hbFree
    else if (X >= Width - 95) and (X <= Width - 12) then
      FHoverBtn := hbPoints
    else
      FHoverBtn := hbNone;
  end
  else
    FHoverBtn := hbNone;

  if OldBtn <> FHoverBtn then
    Repaint;
end;

procedure THbListRow.DoMouseLeave;
begin
  inherited DoMouseLeave;
  FHoverBtn := hbNone;
  Repaint;
end;

procedure THbListRow.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Enabled and (Button = TMouseButton.mbLeft) then
  begin
    if FHoverBtn = hbFree then
    begin
      if Assigned(FOnFreeClick) then
        FOnFreeClick(Self);
    end
    else if FHoverBtn = hbPoints then
    begin
      if Assigned(FOnPointsClick) then
        FOnPointsClick(Self);
    end;
  end;
end;

procedure THbListRow.DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens);
var
  R, AvatarR, TitleR, ContextR, BadgeR, BtnFreeR, BtnPointsR: TRectF;
  AvatarColor, TextColor: TAlphaColor;
  Opacity: Single;
begin
  R := ARect;
  R.Inflate(-1, -1);

  if FDimmed then
    Opacity := 0.55
  else
    Opacity := 1.0;

  // Background Box
  Canvas.Fill.Color := Tokens.Surface;
  Canvas.Fill.Kind := TBrushKind.Solid;
  Canvas.FillRect(R, Tokens.RadiusM, Tokens.RadiusM, AllCorners, Opacity);

  Canvas.Stroke.Color := Tokens.Border;
  Canvas.Stroke.Thickness := Tokens.BorderWidth;
  Canvas.Stroke.Kind := TBrushKind.Solid;
  Canvas.DrawRect(R, Tokens.RadiusM, Tokens.RadiusM, AllCorners, Opacity);

  // 1. Avatar
  AvatarR := TRectF.Create(R.Left + 12, R.Top + 10, R.Left + 46, R.Top + 44);
  AvatarColor := HashSeedToColor(FAvatarSeed);
  Canvas.Fill.Color := AvatarColor;
  Canvas.FillEllipse(AvatarR, Opacity);

  Canvas.Fill.Color := $FFFFFFFF;
  Canvas.Font.Family := Tokens.FontFamily;
  Canvas.Font.Size := 14.0;
  Canvas.Font.Style := [TFontStyle.fsBold];
  Canvas.FillText(AvatarR, FAvatarSeed, False, Opacity, [], TTextAlign.Center, TTextAlign.Center);

  // 2. Title & Context
  TitleR := TRectF.Create(R.Left + 54, R.Top + 8, R.Left + 180, R.Top + 28);
  TextColor := Tokens.Ink;
  Canvas.Fill.Color := TextColor;
  Canvas.Font.Size := Tokens.SizeM;
  Canvas.Font.Style := [TFontStyle.fsBold];
  Canvas.FillText(TitleR, FTitle, False, Opacity, [], TTextAlign.Leading, TTextAlign.Center);

  ContextR := TRectF.Create(R.Left + 54, R.Top + 28, R.Right - 200, R.Top + 48);
  Canvas.Fill.Color := Tokens.InkMuted;
  Canvas.Font.Size := Tokens.SizeXS;
  Canvas.Font.Style := [];
  Canvas.FillText(ContextR, FContextText, False, Opacity, [], TTextAlign.Leading, TTextAlign.Center);

  // 3. Badges
  if FBadge1Text <> '' then
  begin
    BadgeR := TRectF.Create(R.Left + 140, R.Top + 10, R.Left + 210, R.Top + 26);
    Canvas.Fill.Color := Tokens.DangerSoft;
    Canvas.FillRect(BadgeR, 8, 8, AllCorners, Opacity);
    Canvas.Fill.Color := Tokens.Danger;
    Canvas.Font.Size := Tokens.SizeXS;
    Canvas.Font.Style := [TFontStyle.fsBold];
    Canvas.FillText(BadgeR, FBadge1Text, False, Opacity, [], TTextAlign.Center, TTextAlign.Center);
  end;

  // 4. Action Buttons (Right side)
  BtnFreeR := TRectF.Create(R.Right - 190, R.Top + 12, R.Right - 100, R.Bottom - 12);
  BtnPointsR := TRectF.Create(R.Right - 95, R.Top + 12, R.Right - 12, R.Bottom - 12);

  // Free Button
  if FHoverBtn = hbFree then
    Canvas.Fill.Color := Tokens.Sunken
  else
    Canvas.Fill.Color := Tokens.Soft;
  Canvas.FillRect(BtnFreeR, Tokens.RadiusS, Tokens.RadiusS, AllCorners, Opacity);

  Canvas.Fill.Color := Tokens.Ink;
  Canvas.Font.Size := Tokens.SizeXS;
  Canvas.Font.Style := [TFontStyle.fsBold];
  Canvas.FillText(BtnFreeR, FFreeButtonText, False, Opacity, [], TTextAlign.Center, TTextAlign.Center);

  // Points Button
  if FHoverBtn = hbPoints then
    Canvas.Fill.Color := Tokens.PrimaryHover
  else
    Canvas.Fill.Color := Tokens.Primary;
  Canvas.FillRect(BtnPointsR, Tokens.RadiusS, Tokens.RadiusS, AllCorners, Opacity);

  Canvas.Fill.Color := Tokens.OnPrimary;
  Canvas.FillText(BtnPointsR, Format('%s (%d%s)', [FPointsButtonText, FPointsCost, #$70B9]), False, Opacity, [], TTextAlign.Center, TTextAlign.Center);
end;

{ THbEmptyState }

constructor THbEmptyState.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FGlyph := #$D83E#$DE99;
  FTitle := 'Empty State Title';
  FHintText := 'Guidance information goes here';
  FActionCaption := 'Action CTA';
  FHoverAction := False;
  Width := 380;
  Height := 180;
end;

procedure THbEmptyState.SetGlyph(const Value: string);
begin
  if FGlyph <> Value then
  begin
    FGlyph := Value;
    Repaint;
  end;
end;

procedure THbEmptyState.SetTitle(const Value: string);
begin
  if FTitle <> Value then
  begin
    FTitle := Value;
    Repaint;
  end;
end;

procedure THbEmptyState.SetHintText(const Value: string);
begin
  if FHintText <> Value then
  begin
    FHintText := Value;
    Repaint;
  end;
end;

procedure THbEmptyState.SetActionCaption(const Value: string);
begin
  if FActionCaption <> Value then
  begin
    FActionCaption := Value;
    Repaint;
  end;
end;

procedure THbEmptyState.MouseMove(Shift: TShiftState; X, Y: Single);
var
  BtnR: TRectF;
  OldHover: Boolean;
begin
  inherited MouseMove(Shift, X, Y);
  OldHover := FHoverAction;
  BtnR := TRectF.Create((Width - 140) / 2.0, Height - 44, (Width + 140) / 2.0, Height - 12);
  FHoverAction := BtnR.Contains(TPointF.Create(X, Y));
  if OldHover <> FHoverAction then
    Repaint;
end;

procedure THbEmptyState.DoMouseLeave;
begin
  inherited DoMouseLeave;
  FHoverAction := False;
  Repaint;
end;

procedure THbEmptyState.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Enabled and (Button = TMouseButton.mbLeft) and FHoverAction then
  begin
    if Assigned(FOnActionClick) then
      FOnActionClick(Self);
  end;
end;

procedure THbEmptyState.DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens);
var
  R, GlyphR, TitleR, HintR, BtnR: TRectF;
begin
  R := ARect;
  R.Inflate(-1, -1);

  // Surface Sunken Container
  Canvas.Fill.Color := Tokens.Sunken;
  Canvas.Fill.Kind := TBrushKind.Solid;
  Canvas.FillRect(R, Tokens.RadiusL, Tokens.RadiusL, AllCorners, 1.0);

  Canvas.Stroke.Color := Tokens.Border;
  Canvas.Stroke.Thickness := Tokens.BorderWidth;
  Canvas.Stroke.Kind := TBrushKind.Solid;
  Canvas.DrawRect(R, Tokens.RadiusL, Tokens.RadiusL, AllCorners, 1.0);

  // Glyph
  GlyphR := TRectF.Create(R.Left, R.Top + 16, R.Right, R.Top + 54);
  Canvas.Fill.Color := Tokens.Ink;
  Canvas.Font.Family := Tokens.FontFamily;
  Canvas.Font.Size := 28.0;
  Canvas.Font.Style := [];
  Canvas.FillText(GlyphR, FGlyph, False, 1.0, [], TTextAlign.Center, TTextAlign.Center);

  // Title
  TitleR := TRectF.Create(R.Left + 16, R.Top + 58, R.Right - 16, R.Top + 82);
  Canvas.Font.Size := Tokens.SizeM;
  Canvas.Font.Style := [TFontStyle.fsBold];
  Canvas.FillText(TitleR, FTitle, False, 1.0, [], TTextAlign.Center, TTextAlign.Center);

  // Hint
  HintR := TRectF.Create(R.Left + 16, R.Top + 84, R.Right - 16, R.Top + 116);
  Canvas.Fill.Color := Tokens.InkMuted;
  Canvas.Font.Size := Tokens.SizeS;
  Canvas.Font.Style := [];
  Canvas.FillText(HintR, FHintText, True, 1.0, [], TTextAlign.Center, TTextAlign.Center);

  // CTA Action Button
  if FActionCaption <> '' then
  begin
    BtnR := TRectF.Create((R.Width - 140) / 2.0, R.Bottom - 44, (R.Width + 140) / 2.0, R.Bottom - 12);
    if FHoverAction then
      Canvas.Fill.Color := Tokens.PrimaryHover
    else
      Canvas.Fill.Color := Tokens.Primary;

    Canvas.FillRect(BtnR, Tokens.RadiusM, Tokens.RadiusM, AllCorners, 1.0);

    Canvas.Fill.Color := Tokens.OnPrimary;
    Canvas.Font.Size := Tokens.SizeS;
    Canvas.Font.Style := [TFontStyle.fsBold];
    Canvas.FillText(BtnR, FActionCaption, False, 1.0, [], TTextAlign.Center, TTextAlign.Center);
  end;
end;

end.
