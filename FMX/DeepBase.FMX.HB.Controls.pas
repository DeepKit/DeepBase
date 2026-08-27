{ ============================================================================
  DeepBase.FMX.HB.Controls - Core Vector-Rendered HB Controls for FireMonkey

  Version: 1.0 (Delphi 13.1 on Win64 / Cross-Platform FMX)
  Description: Complete set of 8 vector-rendered, design-token-driven atomic
               controls for FireMonkey with 5-state lifecycle
               (Normal/Hover/Pressed/Disabled/Focused), DPI/Density responsiveness,
               and WCAG AA compliant contrast.
  ============================================================================ }

unit DeepBase.FMX.HB.Controls;

interface

uses
  System.SysUtils,
  System.Classes,
  System.UITypes,
  System.Types,
  System.Math,
  System.Messaging,
  FMX.Types,
  FMX.Controls,
  FMX.Graphics,
  FMX.Objects,
  DeepBase.HB.Core;

type
  THbControlState = (stNormal, stHover, stPressed, stDisabled, stFocused);
  THbButtonKind = (bkPrimary, bkGhost, bkSoft, bkDanger);
  THbButtonSize = (bsSmall, bsMedium, bsLarge);
  THbDualTrack = (htNone, htFree, htPoints);
  THbChipTone = (ttNeutral, ttBrand, ttSuccess, ttWarning, ttDanger);
  THbBadgeTone = DeepBase.HB.Core.THbBadgeTone;
  THbBadgeShape = (hpPill, hpSquare);
  THbAvatarSize = (avsS, avsM, avsL, avsXL);
  THbAvatarStatus = (sdNone, sdOnline, sdAway, sdOffline);
  THbToastKind = (tkSuccess, tkWarning, tkDanger, tkInfo);
  THbSkeletonShape = (skLine, skCircle, skCard);

  /// <summary>
  /// Abstract base class for all HB FMX vector-rendered controls.
  /// </summary>
  THbFmxControl = class(TControl)
  private
    FState: THbControlState;
    FThemeSubId: Integer;
    procedure OnThemeChangedMessage(const Sender: TObject; const M: TMessage);
  protected
    procedure DoMouseEnter; override;
    procedure DoMouseLeave; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure Paint; override;
    procedure DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens); virtual; abstract;
    function GetEffectiveState: THbControlState; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property State: THbControlState read FState;
  end;

  /// <summary>
  /// THbButton: Primary, Ghost, Soft, Danger button with Pill and 3-size support.
  /// </summary>
  THbButton = class(THbFmxControl)
  private
    FKind: THbButtonKind;
    FSize: THbButtonSize;
    FPill: Boolean;
    FCaption: string;
    procedure SetKind(const Value: THbButtonKind);
    procedure SetSize(const Value: THbButtonSize);
    procedure SetPill(const Value: Boolean);
    procedure SetCaption(const Value: string);
  protected
    procedure DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Align;
    property Anchors;
    property Caption: string read FCaption write SetCaption;
    property Enabled;
    property Kind: THbButtonKind read FKind write SetKind default bkPrimary;
    property Size: THbButtonSize read FSize write SetSize default bsMedium;
    property Pill: Boolean read FPill write SetPill default False;
    property TabOrder;
    property TabStop default True;
    property Visible;
    property OnClick;
  end;

  /// <summary>
  /// THbDualButton: Dual-track action button with Free track and AI points track.
  /// </summary>
  THbDualButton = class(THbFmxControl)
  private
    FCaptionFree: string;
    FCaptionPoints: string;
    FPointsCost: Integer;
    FPointsUnit: string;
    FHoverTrack: THbDualTrack;
    FOnFreeClick: TNotifyEvent;
    FOnPointsClick: TNotifyEvent;
    procedure SetCaptionFree(const Value: string);
    procedure SetCaptionPoints(const Value: string);
    procedure SetPointsCost(const Value: Integer);
    procedure SetPointsUnit(const Value: string);
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
    property CaptionFree: string read FCaptionFree write SetCaptionFree;
    property CaptionPoints: string read FCaptionPoints write SetCaptionPoints;
    property PointsCost: Integer read FPointsCost write SetPointsCost default 5;
    property PointsUnit: string read FPointsUnit write SetPointsUnit;
    property Enabled;
    property TabOrder;
    property TabStop default True;
    property Visible;
    property OnFreeClick: TNotifyEvent read FOnFreeClick write FOnFreeClick;
    property OnPointsClick: TNotifyEvent read FOnPointsClick write FOnPointsClick;
  end;

  /// <summary>
  /// THbChip: Semantic filter tag capsule with optional close button.
  /// </summary>
  THbChip = class(THbFmxControl)
  private
    FTone: THbChipTone;
    FSelected: Boolean;
    FClosable: Boolean;
    FCaption: string;
    FOnClose: TNotifyEvent;
    procedure SetTone(const Value: THbChipTone);
    procedure SetSelected(const Value: Boolean);
    procedure SetClosable(const Value: Boolean);
    procedure SetCaption(const Value: string);
  protected
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Align;
    property Anchors;
    property Caption: string read FCaption write SetCaption;
    property Closable: Boolean read FClosable write SetClosable default False;
    property Enabled;
    property Selected: Boolean read FSelected write SetSelected default False;
    property Tone: THbChipTone read FTone write SetTone default ttNeutral;
    property Visible;
    property OnClick;
    property OnClose: TNotifyEvent read FOnClose write FOnClose;
  end;

  /// <summary>
  /// THbBadge: Compact status tag pill or square badge.
  /// </summary>
  THbBadge = class(THbFmxControl)
  private
    FTone: THbBadgeTone;
    FShape: THbBadgeShape;
    FCaption: string;
    procedure SetTone(const Value: THbBadgeTone);
    procedure SetShape(const Value: THbBadgeShape);
    procedure SetCaption(const Value: string);
  protected
    procedure DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Align;
    property Anchors;
    property Caption: string read FCaption write SetCaption;
    property Shape: THbBadgeShape read FShape write SetShape default hpPill;
    property Tone: THbBadgeTone read FTone write SetTone default btNeutral;
    property Visible;
  end;

  /// <summary>
  /// THbAvatar: Name seed hashed background with status ring dot.
  /// </summary>
  THbAvatar = class(THbFmxControl)
  private
    FInitials: string;
    FSeed: string;
    FSize: THbAvatarSize;
    FStatusDot: THbAvatarStatus;
    procedure SetInitials(const Value: string);
    procedure SetSeed(const Value: string);
    procedure SetSize(const Value: THbAvatarSize);
    procedure SetStatusDot(const Value: THbAvatarStatus);
    function HashSeedToColor(const ASeed: string): TAlphaColor;
  protected
    procedure DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Align;
    property Anchors;
    property Initials: string read FInitials write SetInitials;
    property Seed: string read FSeed write SetSeed;
    property Size: THbAvatarSize read FSize write SetSize default avsM;
    property StatusDot: THbAvatarStatus read FStatusDot write SetStatusDot default sdNone;
    property Visible;
  end;

  /// <summary>
  /// THbProgressRing: Circular progress and indeterminate spinner indicator.
  /// </summary>
  THbProgressRing = class(THbFmxControl)
  private
    FPercent: Single;
    FIndeterminate: Boolean;
    FStrokeWidth: Single;
    FAnimAngle: Single;
    FTimer: TTimer;
    procedure SetPercent(const Value: Single);
    procedure SetIndeterminate(const Value: Boolean);
    procedure SetStrokeWidth(const Value: Single);
    procedure OnTimerTick(Sender: TObject);
  protected
    procedure DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property Align;
    property Anchors;
    property Indeterminate: Boolean read FIndeterminate write SetIndeterminate default False;
    property Percent: Single read FPercent write SetPercent;
    property StrokeWidth: Single read FStrokeWidth write SetStrokeWidth;
    property Visible;
  end;

  /// <summary>
  /// THbToast: Notification message pill with 4 semantic kinds.
  /// </summary>
  THbToast = class(THbFmxControl)
  private
    FKind: THbToastKind;
    FMessageText: string;
    FDurationMs: Integer;
    FAutoDismiss: Boolean;
    FTimer: TTimer;
    procedure SetKind(const Value: THbToastKind);
    procedure SetMessageText(const Value: string);
    procedure OnTimerTick(Sender: TObject);
  protected
    procedure DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ShowToast(const AMessage: string; AKind: THbToastKind = tkSuccess);
  published
    property Align;
    property Anchors;
    property AutoDismiss: Boolean read FAutoDismiss write FAutoDismiss default True;
    property DurationMs: Integer read FDurationMs write FDurationMs default 3000;
    property Kind: THbToastKind read FKind write SetKind default tkSuccess;
    property MessageText: string read FMessageText write SetMessageText;
    property Visible;
  end;

  /// <summary>
  /// THbSkeleton: Loading placeholder shimmer block.
  /// </summary>
  THbSkeleton = class(THbFmxControl)
  private
    FShape: THbSkeletonShape;
    FAnimPhase: Single;
    FTimer: TTimer;
    procedure SetShape(const Value: THbSkeletonShape);
    procedure OnTimerTick(Sender: TObject);
  protected
    procedure DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property Align;
    property Anchors;
    property Shape: THbSkeletonShape read FShape write SetShape default skLine;
    property Visible;
  end;

  /// <summary>
  /// THbSectionHeader: Section title, badge count, and trailing action link.
  /// </summary>
  THbSectionHeader = class(THbFmxControl)
  private
    FTitle: string;
    FCount: Integer;
    FTrailingLink: string;
    FOnLinkClick: TNotifyEvent;
    procedure SetTitle(const Value: string);
    procedure SetCount(const Value: Integer);
    procedure SetTrailingLink(const Value: string);
  protected
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Align;
    property Anchors;
    property Count: Integer read FCount write SetCount default 0;
    property Title: string read FTitle write SetTitle;
    property TrailingLink: string read FTrailingLink write SetTrailingLink;
    property Visible;
    property OnLinkClick: TNotifyEvent read FOnLinkClick write FOnLinkClick;
  end;

implementation

{ THbFmxControl }

constructor THbFmxControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FState := stNormal;
  HitTest := True;
  TabStop := True;
  FThemeSubId := Integer(TMessageManager.DefaultManager.SubscribeToMessage(
    THbThemeChangedMessage, OnThemeChangedMessage));
end;

destructor THbFmxControl.Destroy;
begin
  TMessageManager.DefaultManager.Unsubscribe(THbThemeChangedMessage, FThemeSubId);
  inherited Destroy;
end;

procedure THbFmxControl.OnThemeChangedMessage(const Sender: TObject; const M: TMessage);
begin
  Repaint;
end;

procedure THbFmxControl.DoMouseEnter;
begin
  inherited DoMouseEnter;
  if Enabled and (FState <> stPressed) then
  begin
    FState := stHover;
    Repaint;
  end;
end;

procedure THbFmxControl.DoMouseLeave;
begin
  inherited DoMouseLeave;
  if Enabled and (FState <> stPressed) then
  begin
    FState := stNormal;
    Repaint;
  end;
end;

procedure THbFmxControl.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Enabled and (Button = TMouseButton.mbLeft) then
  begin
    FState := stPressed;
    Repaint;
  end;
end;

procedure THbFmxControl.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if Enabled then
  begin
    if PointInObject(X, Y) then
      FState := stHover
    else
      FState := stNormal;
    Repaint;
  end;
end;

procedure THbFmxControl.DoEnter;
begin
  inherited DoEnter;
  Repaint;
end;

procedure THbFmxControl.DoExit;
begin
  inherited DoExit;
  Repaint;
end;

function THbFmxControl.GetEffectiveState: THbControlState;
begin
  if not Enabled then
    Result := stDisabled
  else if IsFocused then
    Result := stFocused
  else
    Result := FState;
end;

procedure THbFmxControl.Paint;
var
  Tokens: THbTokens;
  R: TRectF;
begin
  inherited Paint;
  Tokens := THbTheme.Tokens;
  R := LocalRect;

  DrawHbControl(Canvas, R, Tokens);

  // Paint focus ring if focused
  if IsFocused and TabStop and Enabled then
  begin
    Canvas.Stroke.Color := Tokens.FocusRing;
    Canvas.Stroke.Thickness := 2.0;
    Canvas.Stroke.Kind := TBrushKind.Solid;
    R.Inflate(-1, -1);
    Canvas.DrawRect(R, Tokens.RadiusS, Tokens.RadiusS, AllCorners, 0.75);
  end;
end;

{ THbButton }

constructor THbButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FKind := bkPrimary;
  FSize := bsMedium;
  FPill := False;
  FCaption := 'Action';
  Width := 96;
  Height := 36;
end;

procedure THbButton.SetKind(const Value: THbButtonKind);
begin
  if FKind <> Value then
  begin
    FKind := Value;
    Repaint;
  end;
end;

procedure THbButton.SetSize(const Value: THbButtonSize);
begin
  if FSize <> Value then
  begin
    FSize := Value;
    case FSize of
      bsSmall: Height := 28;
      bsMedium: Height := 36;
      bsLarge: Height := 44;
    end;
    Repaint;
  end;
end;

procedure THbButton.SetPill(const Value: Boolean);
begin
  if FPill <> Value then
  begin
    FPill := Value;
    Repaint;
  end;
end;

procedure THbButton.SetCaption(const Value: string);
begin
  if FCaption <> Value then
  begin
    FCaption := Value;
    Repaint;
  end;
end;

procedure THbButton.DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens);
var
  EffState: THbControlState;
  BgColor, BorderColor, TextColor: TAlphaColor;
  Radius: Single;
  R: TRectF;
begin
  EffState := GetEffectiveState;
  R := ARect;
  R.Inflate(-1, -1);

  if FPill then
    Radius := R.Height / 2.0
  else
    Radius := Tokens.RadiusM;

  // Determine colors based on Kind and State
  case FKind of
    bkPrimary:
      begin
        case EffState of
          stHover:   BgColor := Tokens.PrimaryHover;
          stPressed: BgColor := Tokens.PrimaryPressed;
          stDisabled: BgColor := $33808080;
          else       BgColor := Tokens.Primary;
        end;
        BorderColor := TAlphaColors.Null;
        TextColor := Tokens.OnPrimary;
      end;
    bkGhost:
      begin
        case EffState of
          stHover:   BgColor := Tokens.Soft;
          stPressed: BgColor := Tokens.Sunken;
          stDisabled: BgColor := TAlphaColors.Null;
          else       BgColor := TAlphaColors.Null;
        end;
        BorderColor := Tokens.Border;
        TextColor := Tokens.Ink;
      end;
    bkSoft:
      begin
        case EffState of
          stHover:   BgColor := Tokens.SurfaceAlt;
          stPressed: BgColor := Tokens.Sunken;
          stDisabled: BgColor := $1A808080;
          else       BgColor := Tokens.Soft;
        end;
        BorderColor := TAlphaColors.Null;
        TextColor := Tokens.Primary;
      end;
    bkDanger:
      begin
        case EffState of
          stHover:   BgColor := $FFE11D48;
          stPressed: BgColor := $FF9F1239;
          stDisabled: BgColor := $33808080;
          else       BgColor := Tokens.Danger;
        end;
        BorderColor := TAlphaColors.Null;
        TextColor := $FFFFFFFF;
      end;
    else
      BgColor := Tokens.Primary;
      BorderColor := TAlphaColors.Null;
      TextColor := Tokens.OnPrimary;
  end;

  if not Enabled then
    TextColor := Tokens.InkMuted;

  // Fill Background
  if BgColor <> TAlphaColors.Null then
  begin
    Canvas.Fill.Color := BgColor;
    Canvas.Fill.Kind := TBrushKind.Solid;
    Canvas.FillRect(R, Radius, Radius, AllCorners, 1.0);
  end;

  // Stroke Border
  if BorderColor <> TAlphaColors.Null then
  begin
    Canvas.Stroke.Color := BorderColor;
    Canvas.Stroke.Thickness := Tokens.BorderWidth;
    Canvas.Stroke.Kind := TBrushKind.Solid;
    Canvas.DrawRect(R, Radius, Radius, AllCorners, 1.0);
  end;

  // Text
  if FCaption <> '' then
  begin
    Canvas.Fill.Color := TextColor;
    Canvas.Font.Family := Tokens.FontFamily;
    Canvas.Font.Size := Tokens.SizeM;
    Canvas.Font.Style := [TFontStyle.fsBold];
    Canvas.FillText(R, FCaption, False, 1.0, [], TTextAlign.Center, TTextAlign.Center);
  end;
end;

{ THbDualButton }

constructor THbDualButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCaptionFree := '开场白 · 免费';
  FCaptionPoints := 'AI 方案';
  FPointsCost := 5;
  FPointsUnit := #$70B9;
  FHoverTrack := htNone;
  Width := 240;
  Height := 36;
end;

procedure THbDualButton.SetCaptionFree(const Value: string);
begin
  if FCaptionFree <> Value then
  begin
    FCaptionFree := Value;
    Repaint;
  end;
end;

procedure THbDualButton.SetCaptionPoints(const Value: string);
begin
  if FCaptionPoints <> Value then
  begin
    FCaptionPoints := Value;
    Repaint;
  end;
end;

procedure THbDualButton.SetPointsCost(const Value: Integer);
begin
  if FPointsCost <> Value then
  begin
    FPointsCost := Value;
    Repaint;
  end;
end;

procedure THbDualButton.SetPointsUnit(const Value: string);
begin
  if FPointsUnit <> Value then
  begin
    FPointsUnit := Value;
    Repaint;
  end;
end;

procedure THbDualButton.MouseMove(Shift: TShiftState; X, Y: Single);
var
  MidX: Single;
  OldTrack: THbDualTrack;
begin
  inherited MouseMove(Shift, X, Y);
  MidX := Width * 0.52;
  OldTrack := FHoverTrack;
  if X < MidX then
    FHoverTrack := htFree
  else
    FHoverTrack := htPoints;

  if OldTrack <> FHoverTrack then
    Repaint;
end;

procedure THbDualButton.DoMouseLeave;
begin
  inherited DoMouseLeave;
  FHoverTrack := htNone;
  Repaint;
end;

procedure THbDualButton.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  MidX: Single;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Enabled and (Button = TMouseButton.mbLeft) then
  begin
    MidX := Width * 0.52;
    if X < MidX then
    begin
      if Assigned(FOnFreeClick) then
        FOnFreeClick(Self);
    end
    else
    begin
      if Assigned(FOnPointsClick) then
        FOnPointsClick(Self);
    end;
  end;
end;

procedure THbDualButton.DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens);
var
  R, RFree, RPoints: TRectF;
  MidX, Radius: Single;
  PointsLabel: string;
begin
  R := ARect;
  R.Inflate(-1, -1);
  Radius := Tokens.RadiusM;
  MidX := R.Left + R.Width * 0.52;

  RFree := TRectF.Create(R.Left, R.Top, MidX, R.Bottom);
  RPoints := TRectF.Create(MidX, R.Top, R.Right, R.Bottom);

  // 1. Draw Container Border & Background
  Canvas.Fill.Color := Tokens.Soft;
  Canvas.Fill.Kind := TBrushKind.Solid;
  Canvas.FillRect(R, Radius, Radius, AllCorners, 1.0);

  // Left Free Track Hover
  if (FHoverTrack = htFree) and Enabled then
  begin
    Canvas.Fill.Color := Tokens.SurfaceAlt;
    Canvas.FillRect(RFree, Radius, Radius, [TCorner.TopLeft, TCorner.BottomLeft], 1.0);
  end;

  // Right Points Track (Primary Brand filled)
  if (FHoverTrack = htPoints) and Enabled then
    Canvas.Fill.Color := Tokens.PrimaryHover
  else
    Canvas.Fill.Color := Tokens.Primary;

  Canvas.FillRect(RPoints, Radius, Radius, [TCorner.TopRight, TCorner.BottomRight], 1.0);

  // Container Stroke
  Canvas.Stroke.Color := Tokens.Border;
  Canvas.Stroke.Thickness := Tokens.BorderWidth;
  Canvas.Stroke.Kind := TBrushKind.Solid;
  Canvas.DrawRect(R, Radius, Radius, AllCorners, 1.0);

  // Divider Line
  Canvas.Stroke.Color := Tokens.Border;
  Canvas.DrawLine(TPointF.Create(MidX, R.Top), TPointF.Create(MidX, R.Bottom), 1.0);

  // Left Text
  Canvas.Fill.Color := Tokens.Ink;
  Canvas.Font.Family := Tokens.FontFamily;
  Canvas.Font.Size := Tokens.SizeS;
  Canvas.Font.Style := [TFontStyle.fsBold];
  Canvas.FillText(RFree, FCaptionFree, False, 1.0, [], TTextAlign.Center, TTextAlign.Center);

  // Right Text
  PointsLabel := Format('%s (%d%s)', [FCaptionPoints, FPointsCost, FPointsUnit]);
  Canvas.Fill.Color := Tokens.OnPrimary;
  Canvas.Font.Size := Tokens.SizeS;
  Canvas.Font.Style := [TFontStyle.fsBold];
  Canvas.FillText(RPoints, PointsLabel, False, 1.0, [], TTextAlign.Center, TTextAlign.Center);
end;

{ THbChip }

constructor THbChip.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FTone := ttNeutral;
  FSelected := False;
  FClosable := False;
  FCaption := 'Chip';
  Width := 80;
  Height := 28;
end;

procedure THbChip.SetTone(const Value: THbChipTone);
begin
  if FTone <> Value then
  begin
    FTone := Value;
    Repaint;
  end;
end;

procedure THbChip.SetSelected(const Value: Boolean);
begin
  if FSelected <> Value then
  begin
    FSelected := Value;
    Repaint;
  end;
end;

procedure THbChip.SetClosable(const Value: Boolean);
begin
  if FClosable <> Value then
  begin
    FClosable := Value;
    Repaint;
  end;
end;

procedure THbChip.SetCaption(const Value: string);
begin
  if FCaption <> Value then
  begin
    FCaption := Value;
    Repaint;
  end;
end;

procedure THbChip.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Enabled and (Button = TMouseButton.mbLeft) then
  begin
    if FClosable and (X > Width - 24) then
    begin
      if Assigned(FOnClose) then
        FOnClose(Self);
    end
    else
    begin
      FSelected := not FSelected;
      Repaint;
    end;
  end;
end;

procedure THbChip.DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens);
var
  R, TextR, CloseR: TRectF;
  Radius: Single;
  BgColor, BorderColor, TextColor: TAlphaColor;
begin
  R := ARect;
  R.Inflate(-1, -1);
  Radius := R.Height / 2.0;

  if FSelected then
  begin
    BgColor := Tokens.Primary;
    BorderColor := Tokens.Primary;
    TextColor := Tokens.OnPrimary;
  end
  else
  begin
    case FTone of
      ttBrand:   begin BgColor := Tokens.Soft; BorderColor := Tokens.Primary; TextColor := Tokens.Primary; end;
      ttSuccess: begin BgColor := Tokens.SuccessSoft; BorderColor := Tokens.Success; TextColor := Tokens.Success; end;
      ttWarning: begin BgColor := Tokens.WarningSoft; BorderColor := Tokens.Warning; TextColor := Tokens.Warning; end;
      ttDanger:  begin BgColor := Tokens.DangerSoft; BorderColor := Tokens.Danger; TextColor := Tokens.Danger; end;
      else       begin BgColor := Tokens.SurfaceAlt; BorderColor := Tokens.Border; TextColor := Tokens.Ink; end;
    end;
  end;

  // Fill Pill
  Canvas.Fill.Color := BgColor;
  Canvas.Fill.Kind := TBrushKind.Solid;
  Canvas.FillRect(R, Radius, Radius, AllCorners, 1.0);

  // Border
  Canvas.Stroke.Color := BorderColor;
  Canvas.Stroke.Thickness := Tokens.BorderWidth;
  Canvas.Stroke.Kind := TBrushKind.Solid;
  Canvas.DrawRect(R, Radius, Radius, AllCorners, 1.0);

  // Text
  TextR := R;
  if FClosable then
    TextR.Right := TextR.Right - 20;

  Canvas.Fill.Color := TextColor;
  Canvas.Font.Family := Tokens.FontFamily;
  Canvas.Font.Size := Tokens.SizeS;
  Canvas.Font.Style := [TFontStyle.fsBold];
  Canvas.FillText(TextR, FCaption, False, 1.0, [], TTextAlign.Center, TTextAlign.Center);

  // Close '✕' Button
  if FClosable then
  begin
    CloseR := TRectF.Create(R.Right - 20, R.Top, R.Right - 4, R.Bottom);
    Canvas.Fill.Color := TextColor;
    Canvas.Font.Size := Tokens.SizeXS;
    Canvas.FillText(CloseR, #$2715, False, 1.0, [], TTextAlign.Center, TTextAlign.Center);
  end;
end;

{ THbBadge }

constructor THbBadge.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FTone := btNeutral;
  FShape := hpPill;
  FCaption := 'Badge';
  Width := 60;
  Height := 22;
end;

procedure THbBadge.SetTone(const Value: THbBadgeTone);
begin
  if FTone <> Value then
  begin
    FTone := Value;
    Repaint;
  end;
end;

procedure THbBadge.SetShape(const Value: THbBadgeShape);
begin
  if FShape <> Value then
  begin
    FShape := Value;
    Repaint;
  end;
end;

procedure THbBadge.SetCaption(const Value: string);
begin
  if FCaption <> Value then
  begin
    FCaption := Value;
    Repaint;
  end;
end;

procedure THbBadge.DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens);
var
  R: TRectF;
  Radius: Single;
  BgColor, BorderColor, TextColor: TAlphaColor;
begin
  R := ARect;
  R.Inflate(-1, -1);

  if FShape = hpPill then
    Radius := R.Height / 2.0
  else
    Radius := Tokens.RadiusS;

  case FTone of
    btBrand:   begin BgColor := Tokens.Soft; BorderColor := Tokens.Primary; TextColor := Tokens.Primary; end;
    btSuccess: begin BgColor := Tokens.SuccessSoft; BorderColor := Tokens.Success; TextColor := Tokens.Success; end;
    btWarning: begin BgColor := Tokens.WarningSoft; BorderColor := Tokens.Warning; TextColor := Tokens.Warning; end;
    btDanger:  begin BgColor := Tokens.DangerSoft; BorderColor := Tokens.Danger; TextColor := Tokens.Danger; end;
    else       begin BgColor := Tokens.SurfaceAlt; BorderColor := Tokens.Border; TextColor := Tokens.InkMuted; end;
  end;

  Canvas.Fill.Color := BgColor;
  Canvas.Fill.Kind := TBrushKind.Solid;
  Canvas.FillRect(R, Radius, Radius, AllCorners, 1.0);

  Canvas.Stroke.Color := BorderColor;
  Canvas.Stroke.Thickness := Tokens.BorderWidth;
  Canvas.Stroke.Kind := TBrushKind.Solid;
  Canvas.DrawRect(R, Radius, Radius, AllCorners, 1.0);

  Canvas.Fill.Color := TextColor;
  Canvas.Font.Family := Tokens.FontFamily;
  Canvas.Font.Size := Tokens.SizeXS;
  Canvas.Font.Style := [TFontStyle.fsBold];
  Canvas.FillText(R, FCaption, False, 1.0, [], TTextAlign.Center, TTextAlign.Center);
end;

{ THbAvatar }

constructor THbAvatar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FInitials := 'HB';
  FSeed := 'HB';
  FSize := avsM;
  FStatusDot := sdNone;
  Width := 36;
  Height := 36;
end;

procedure THbAvatar.SetInitials(const Value: string);
begin
  if FInitials <> Value then
  begin
    FInitials := Value;
    Repaint;
  end;
end;

procedure THbAvatar.SetSeed(const Value: string);
begin
  if FSeed <> Value then
  begin
    FSeed := Value;
    Repaint;
  end;
end;

procedure THbAvatar.SetSize(const Value: THbAvatarSize);
begin
  if FSize <> Value then
  begin
    FSize := Value;
    case FSize of
      avsS: begin Width := 24; Height := 24; end;
      avsM: begin Width := 36; Height := 36; end;
      avsL: begin Width := 48; Height := 48; end;
      avsXL: begin Width := 64; Height := 64; end;
    end;
    Repaint;
  end;
end;

procedure THbAvatar.SetStatusDot(const Value: THbAvatarStatus);
begin
  if FStatusDot <> Value then
  begin
    FStatusDot := Value;
    Repaint;
  end;
end;

function THbAvatar.HashSeedToColor(const ASeed: string): TAlphaColor;
var
  H: Cardinal;
  C: Char;
  Colors: array[0..7] of TAlphaColor;
begin
  Colors[0] := $FFD97706; // Amber
  Colors[1] := $FF2563EB; // Blue
  Colors[2] := $FF059669; // Green
  Colors[3] := $FFE11D48; // Rose
  Colors[4] := $FF7C3AED; // Violet
  Colors[5] := $FF0891B2; // Cyan
  Colors[6] := $FFEA580C; // Orange
  Colors[7] := $FF4F46E5; // Indigo

  H := 0;
  for C in ASeed do
    H := (H * 31) + Ord(C);

  Result := Colors[H mod 8];
end;

procedure THbAvatar.DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens);
var
  R, DotR: TRectF;
  AvatarColor, DotColor: TAlphaColor;
  DotSize: Single;
begin
  R := ARect;
  R.Inflate(-1, -1);

  AvatarColor := HashSeedToColor(FSeed);

  // Draw Circle Avatar
  Canvas.Fill.Color := AvatarColor;
  Canvas.Fill.Kind := TBrushKind.Solid;
  Canvas.FillEllipse(R, 1.0);

  // Initials Text
  if FInitials <> '' then
  begin
    Canvas.Fill.Color := $FFFFFFFF;
    Canvas.Font.Family := Tokens.FontFamily;
    Canvas.Font.Size := R.Height * 0.42;
    Canvas.Font.Style := [TFontStyle.fsBold];
    Canvas.FillText(R, FInitials, False, 1.0, [], TTextAlign.Center, TTextAlign.Center);
  end;

  // Status Dot
  if FStatusDot <> sdNone then
  begin
    case FStatusDot of
      sdOnline:  DotColor := Tokens.Success;
      sdAway:    DotColor := Tokens.Warning;
      sdOffline: DotColor := Tokens.InkMuted;
      else       DotColor := Tokens.Success;
    end;

    DotSize := Max(8.0, R.Height * 0.28);
    DotR := TRectF.Create(R.Right - DotSize, R.Bottom - DotSize, R.Right, R.Bottom);

    // Halo ring
    Canvas.Fill.Color := Tokens.Surface;
    Canvas.FillEllipse(DotR, 1.0);

    DotR.Inflate(-1.5, -1.5);
    Canvas.Fill.Color := DotColor;
    Canvas.FillEllipse(DotR, 1.0);
  end;
end;

{ THbProgressRing }

constructor THbProgressRing.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FPercent := 0;
  FIndeterminate := False;
  FStrokeWidth := 4.0;
  FAnimAngle := 0;
  Width := 48;
  Height := 48;

  FTimer := TTimer.Create(Self);
  FTimer.Interval := 25;
  FTimer.OnTimer := OnTimerTick;
  FTimer.Enabled := False;
end;

destructor THbProgressRing.Destroy;
begin
  FTimer.Free;
  inherited Destroy;
end;

procedure THbProgressRing.SetPercent(const Value: Single);
begin
  if FPercent <> Value then
  begin
    FPercent := Value;
    Repaint;
  end;
end;

procedure THbProgressRing.SetIndeterminate(const Value: Boolean);
begin
  if FIndeterminate <> Value then
  begin
    FIndeterminate := Value;
    FTimer.Enabled := FIndeterminate;
    Repaint;
  end;
end;

procedure THbProgressRing.SetStrokeWidth(const Value: Single);
begin
  if FStrokeWidth <> Value then
  begin
    FStrokeWidth := Value;
    Repaint;
  end;
end;

procedure THbProgressRing.OnTimerTick(Sender: TObject);
begin
  FAnimAngle := FAnimAngle + 8.0;
  if FAnimAngle >= 360.0 then
    FAnimAngle := FAnimAngle - 360.0;
  Repaint;
end;

procedure THbProgressRing.DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens);
var
  R: TRectF;
  Center: TPointF;
  Radius, StartAng, SweepAng: Single;
  Path: TPathData;
begin
  R := ARect;
  R.Inflate(-FStrokeWidth, -FStrokeWidth);
  Center := TPointF.Create((R.Left + R.Right) / 2.0, (R.Top + R.Bottom) / 2.0);
  Radius := Min(R.Width, R.Height) / 2.0;

  // 1. Background Track
  Canvas.Stroke.Color := Tokens.Border;
  Canvas.Stroke.Thickness := FStrokeWidth;
  Canvas.Stroke.Kind := TBrushKind.Solid;
  Canvas.DrawEllipse(R, 1.0);

  // 2. Active Arc
  if FIndeterminate then
  begin
    StartAng := FAnimAngle;
    SweepAng := 90.0;
  end
  else
  begin
    StartAng := -90.0;
    SweepAng := (FPercent / 100.0) * 360.0;
  end;

  if SweepAng > 0 then
  begin
    Path := TPathData.Create;
    try
      Path.AddArc(Center, TPointF.Create(Radius, Radius), StartAng, SweepAng);
      Canvas.Stroke.Color := Tokens.Primary;
      Canvas.Stroke.Thickness := FStrokeWidth;
      Canvas.DrawPath(Path, 1.0);
    finally
      Path.Free;
    end;
  end;
end;

{ THbToast }

constructor THbToast.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FKind := tkSuccess;
  FMessageText := 'Toast notification';
  FDurationMs := 3000;
  FAutoDismiss := True;
  Width := 280;
  Height := 40;

  FTimer := TTimer.Create(Self);
  FTimer.Interval := Cardinal(FDurationMs);
  FTimer.OnTimer := OnTimerTick;
  FTimer.Enabled := False;
end;

destructor THbToast.Destroy;
begin
  FTimer.Free;
  inherited Destroy;
end;

procedure THbToast.SetKind(const Value: THbToastKind);
begin
  if FKind <> Value then
  begin
    FKind := Value;
    Repaint;
  end;
end;

procedure THbToast.SetMessageText(const Value: string);
begin
  if FMessageText <> Value then
  begin
    FMessageText := Value;
    Repaint;
  end;
end;

procedure THbToast.OnTimerTick(Sender: TObject);
begin
  FTimer.Enabled := False;
  Visible := False;
end;

procedure THbToast.ShowToast(const AMessage: string; AKind: THbToastKind);
begin
  FMessageText := AMessage;
  FKind := AKind;
  Visible := True;
  Repaint;
  if FAutoDismiss then
  begin
    FTimer.Interval := Cardinal(FDurationMs);
    FTimer.Enabled := True;
  end;
end;

procedure THbToast.DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens);
var
  R: TRectF;
  BgColor, TextColor: TAlphaColor;
  Glyph: string;
begin
  R := ARect;
  R.Inflate(-1, -1);

  case FKind of
    tkSuccess: begin BgColor := Tokens.SuccessSoft; TextColor := Tokens.Success; Glyph := #$2713; end;
    tkWarning: begin BgColor := Tokens.WarningSoft; TextColor := Tokens.Warning; Glyph := #$26A0; end;
    tkDanger:  begin BgColor := Tokens.DangerSoft; TextColor := Tokens.Danger; Glyph := #$2715; end;
    else       begin BgColor := Tokens.InfoSoft; TextColor := Tokens.Info; Glyph := #$2139; end;
  end;

  // Background Box with Elevation Border
  Canvas.Fill.Color := BgColor;
  Canvas.Fill.Kind := TBrushKind.Solid;
  Canvas.FillRect(R, Tokens.RadiusM, Tokens.RadiusM, AllCorners, 1.0);

  Canvas.Stroke.Color := TextColor;
  Canvas.Stroke.Thickness := Tokens.BorderWidth;
  Canvas.Stroke.Kind := TBrushKind.Solid;
  Canvas.DrawRect(R, Tokens.RadiusM, Tokens.RadiusM, AllCorners, 1.0);

  // Glyph + Text
  Canvas.Fill.Color := TextColor;
  Canvas.Font.Family := Tokens.FontFamily;
  Canvas.Font.Size := Tokens.SizeS;
  Canvas.Font.Style := [TFontStyle.fsBold];
  Canvas.FillText(R, Format('%s  %s', [Glyph, FMessageText]), False, 1.0, [], TTextAlign.Center, TTextAlign.Center);
end;

{ THbSkeleton }

constructor THbSkeleton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FShape := skLine;
  FAnimPhase := 0;
  Width := 160;
  Height := 20;

  FTimer := TTimer.Create(Self);
  FTimer.Interval := 30;
  FTimer.OnTimer := OnTimerTick;
  FTimer.Enabled := True;
end;

destructor THbSkeleton.Destroy;
begin
  FTimer.Free;
  inherited Destroy;
end;

procedure THbSkeleton.SetShape(const Value: THbSkeletonShape);
begin
  if FShape <> Value then
  begin
    FShape := Value;
    Repaint;
  end;
end;

procedure THbSkeleton.OnTimerTick(Sender: TObject);
begin
  FAnimPhase := FAnimPhase + 0.05;
  if FAnimPhase >= 1.0 then
    FAnimPhase := 0.0;
  Repaint;
end;

procedure THbSkeleton.DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens);
var
  R: TRectF;
  PulseAlpha: Single;
begin
  R := ARect;
  R.Inflate(-1, -1);

  PulseAlpha := 0.5 + 0.5 * Sin(FAnimPhase * 2 * Pi);

  Canvas.Fill.Color := Tokens.Sunken;
  Canvas.Fill.Kind := TBrushKind.Solid;

  case FShape of
    skCircle: Canvas.FillEllipse(R, 0.6 + 0.4 * PulseAlpha);
    skCard:   Canvas.FillRect(R, Tokens.RadiusL, Tokens.RadiusL, AllCorners, 0.6 + 0.4 * PulseAlpha);
    else      Canvas.FillRect(R, Tokens.RadiusS, Tokens.RadiusS, AllCorners, 0.6 + 0.4 * PulseAlpha);
  end;
end;

{ THbSectionHeader }

constructor THbSectionHeader.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FTitle := 'Section Title';
  FCount := 0;
  FTrailingLink := '';
  Width := 300;
  Height := 28;
end;

procedure THbSectionHeader.SetTitle(const Value: string);
begin
  if FTitle <> Value then
  begin
    FTitle := Value;
    Repaint;
  end;
end;

procedure THbSectionHeader.SetCount(const Value: Integer);
begin
  if FCount <> Value then
  begin
    FCount := Value;
    Repaint;
  end;
end;

procedure THbSectionHeader.SetTrailingLink(const Value: string);
begin
  if FTrailingLink <> Value then
  begin
    FTrailingLink := Value;
    Repaint;
  end;
end;

procedure THbSectionHeader.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Enabled and (Button = TMouseButton.mbLeft) and (FTrailingLink <> '') then
  begin
    if X > Width - 100 then
    begin
      if Assigned(FOnLinkClick) then
        FOnLinkClick(Self);
    end;
  end;
end;

procedure THbSectionHeader.DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens);
var
  R, TitleR, LinkR: TRectF;
  DisplayTitle: string;
begin
  R := ARect;
  TitleR := R;
  LinkR := R;

  if FCount > 0 then
    DisplayTitle := Format('%s (%d)', [FTitle, FCount])
  else
    DisplayTitle := FTitle;

  // Title
  Canvas.Fill.Color := Tokens.Ink;
  Canvas.Font.Family := Tokens.FontFamily;
  Canvas.Font.Size := Tokens.SizeM;
  Canvas.Font.Style := [TFontStyle.fsBold];
  Canvas.FillText(TitleR, DisplayTitle, False, 1.0, [], TTextAlign.Leading, TTextAlign.Center);

  // Trailing Link
  if FTrailingLink <> '' then
  begin
    Canvas.Fill.Color := Tokens.Primary;
    Canvas.Font.Size := Tokens.SizeS;
    Canvas.Font.Style := [TFontStyle.fsBold];
    Canvas.FillText(LinkR, FTrailingLink, False, 1.0, [], TTextAlign.Trailing, TTextAlign.Center);
  end;
end;

end.
