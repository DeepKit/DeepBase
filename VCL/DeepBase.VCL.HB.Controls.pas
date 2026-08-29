{ ============================================================================
  DeepBase.VCL.HB.Controls - HB Visual Infrastructure Core Atomic Controls

  Version: 1.0 (Delphi 13.1 on Win64)
  Description: Modern vector-rendered VCL controls adhering to HB Design Tokens:
               - THbButton (4 kinds x 3 sizes x 5 states)
               - THbDualButton (Free vs AI Points dual track)
               - THbChip & THbBadge (Pill filters & status tags)
               - THbAvatar (Hash seeded color + online breathing dot)
               - THbProgressRing (Conic/Arc progress + indeterminate)
               - THbToast (Light notification bubble)
               - THbSkeleton (Loading placeholders with sweep animation)
               - THbSectionHeader (Section title with count badge & action)
  Thread Safety: Main UI thread.
  ============================================================================ }

unit DeepBase.VCL.HB.Controls;

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
  Vcl.ExtCtrls,
  Vcl.Forms,
  DeepBase.HB.Core,
  DeepBase.VCL.HB.Theme;

type
  THbControlState = (csNormal, csHover, csPressed, csDisabled);

  THbBtnKind = (bkPrimary, bkGhost, bkSoft, bkDanger);
  THbBtnSize = (bsS, bsM, bsL);

  THbChipTone = (ttNeutral, ttBrand, ttSuccess, ttWarning, ttDanger);
  THbBadgeTone = DeepBase.HB.Core.THbBadgeTone;
  THbBadgeShape = (hpPill, hpSquare);
  THbAvatarSize = (avsS, avsM, avsL, avsXL);
  THbAvatarStatus = (sdNone, sdOnline, sdAway, sdOffline);

  THbToastKind = (tkSuccess, tkWarning, tkDanger, tkInfo);
  THbSkeletonVariant = (skLine, skCard, skCircle);

  { --------------------------------------------------------------------------
    THbCustomControl - Base class for all HB vector-rendered controls
    -------------------------------------------------------------------------- }
  THbCustomControl = class(TCustomControl)
  private
    FIsHovered: Boolean;
    FIsPressed: Boolean;
    FHasFocus: Boolean;
    procedure CMMouseEnter(var Message: TMessage); message CM_MOUSEENTER;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
    procedure WMSetFocus(var Message: TWMSetFocus); message WM_SETFOCUS;
    procedure WMKillFocus(var Message: TWMKillFocus); message WM_KILLFOCUS;
    procedure WMHbThemeChanged(var Message: TMessage); message WM_HB_THEME_CHANGED;
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
    procedure OnThemeChangedNotification(Sender: TObject);
  protected
    function GetCurrentState: THbControlState; virtual;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    function GetTokens: THbTokens; virtual;
    function ScaleDIP(AValue: Single): Single; virtual;
    function ScalePixels(AValue: Single): Integer; virtual;

    // GDI+ Drawing Helpers
    procedure EraseBackground(AGraphics: TGPGraphics); virtual;
    procedure DrawFocusRing(AGraphics: TGPGraphics; const ARect: TGPRectF; ARadius: Single);
    function CreateRoundRectPath(const ARect: TGPRectF; ARadius: Single): TGPGraphicsPath;
    function ColorToARGB(AColor: TAlphaColor; AAlphaOverride: Byte = 0): ARGB;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property CurrentState: THbControlState read GetCurrentState;
  end;

  { --------------------------------------------------------------------------
    THbButton - 4 Kinds x 3 Sizes x 5 States Modern Button
    -------------------------------------------------------------------------- }
  THbButton = class(THbCustomControl)
  private
    FKind: THbBtnKind;
    FSize: THbBtnSize;
    FCaption: string;
    FPill: Boolean;
    procedure SetKind(Value: THbBtnKind);
    procedure SetSize(Value: THbBtnSize);
    procedure SetCaption(const Value: string);
    procedure SetPill(Value: Boolean);
  protected
    procedure Paint; override;
    function GetDefaultSize: TSize;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Kind: THbBtnKind read FKind write SetKind default bkPrimary;
    property Size: THbBtnSize read FSize write SetSize default bsM;
    property Caption: string read FCaption write SetCaption;
    property Pill: Boolean read FPill write SetPill default True;
    property Enabled;
    property TabStop default True;
    property TabOrder;
    property Visible;
    property OnClick;
  end;

  { --------------------------------------------------------------------------
    THbDualButton - Free vs AI Points Dual-Track Button
    -------------------------------------------------------------------------- }
  THbDualButton = class(THbCustomControl)
  private
    FCaptionFree: string;
    FCaptionPoints: string;
    FPointsCost: Integer;
    FShowYuanHint: Boolean;
    FFreeEnabledOnly: Boolean;
    FHoverPart: Integer; // 0=none, 1=free, 2=points
    FPressPart: Integer;
    FOnFreeClick: TNotifyEvent;
    FOnPointsClick: TNotifyEvent;
    procedure SetCaptionFree(const Value: string);
    procedure SetCaptionPoints(const Value: string);
    procedure SetPointsCost(Value: Integer);
    procedure SetShowYuanHint(Value: Boolean);
    procedure SetFreeEnabledOnly(Value: Boolean);
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
  protected
    procedure Paint; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property CaptionFree: string read FCaptionFree write SetCaptionFree;
    property CaptionPoints: string read FCaptionPoints write SetCaptionPoints;
    property PointsCost: Integer read FPointsCost write SetPointsCost default 5;
    property ShowYuanHint: Boolean read FShowYuanHint write SetShowYuanHint default True;
    property FreeEnabledOnly: Boolean read FFreeEnabledOnly write SetFreeEnabledOnly default False;
    property OnFreeClick: TNotifyEvent read FOnFreeClick write FOnFreeClick;
    property OnPointsClick: TNotifyEvent read FOnPointsClick write FOnPointsClick;
    property Enabled;
    property Visible;
  end;

  { --------------------------------------------------------------------------
    THbChip - Pill Filter Tag with Selected & Closable support
    -------------------------------------------------------------------------- }
  THbChip = class(THbCustomControl)
  private
    FTone: THbChipTone;
    FSelected: Boolean;
    FClosable: Boolean;
    FCaption: string;
    FOnClose: TNotifyEvent;
    FClosePressed: Boolean;
    procedure SetTone(Value: THbChipTone);
    procedure SetSelected(Value: Boolean);
    procedure SetClosable(Value: Boolean);
    procedure SetCaption(const Value: string);
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Tone: THbChipTone read FTone write SetTone default ttNeutral;
    property Selected: Boolean read FSelected write SetSelected default False;
    property Closable: Boolean read FClosable write SetClosable default False;
    property Caption: string read FCaption write SetCaption;
    property OnClose: TNotifyEvent read FOnClose write FOnClose;
    property Enabled;
    property Visible;
    property OnClick;
  end;

  { --------------------------------------------------------------------------
    THbBadge - Compact Status Badge
    -------------------------------------------------------------------------- }
  THbBadge = class(THbCustomControl)
  private
    FTone: THbBadgeTone;
    FShape: THbBadgeShape;
    FCaption: string;
    procedure SetTone(Value: THbBadgeTone);
    procedure SetShape(Value: THbBadgeShape);
    procedure SetCaption(const Value: string);
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Tone: THbBadgeTone read FTone write SetTone default btNeutral;
    property Shape: THbBadgeShape read FShape write SetShape default hpSquare;
    property Caption: string read FCaption write SetCaption;
    property Enabled;
    property Visible;
  end;

  { --------------------------------------------------------------------------
    THbAvatar - Hash Seeded Initials Avatar with Online Dot
    -------------------------------------------------------------------------- }
  THbAvatar = class(THbCustomControl)
  private
    FInitials: string;
    FSeed: string;
    FSize: THbAvatarSize;
    FStatusDot: THbAvatarStatus;
    procedure SetInitials(const Value: string);
    procedure SetSeed(const Value: string);
    procedure SetSize(Value: THbAvatarSize);
    procedure SetStatusDot(Value: THbAvatarStatus);
  protected
    procedure Paint; override;
    function GetSeedColor(const ASeed: string): TAlphaColor;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Initials: string read FInitials write SetInitials;
    property Seed: string read FSeed write SetSeed;
    property Size: THbAvatarSize read FSize write SetSize default avsM;
    property StatusDot: THbAvatarStatus read FStatusDot write SetStatusDot default sdNone;
    property Enabled;
    property Visible;
  end;

  { --------------------------------------------------------------------------
    THbProgressRing - Conic/Arc Circular Progress
    -------------------------------------------------------------------------- }
  THbProgressRing = class(THbCustomControl)
  private
    FPercent: Double;
    FThickness: Single;
    FIndeterminate: Boolean;
    FShowCaption: Boolean;
    FAnimTimer: TTimer;
    FAnimAngle: Single;
    procedure SetPercent(Value: Double);
    procedure SetThickness(Value: Single);
    procedure SetIndeterminate(Value: Boolean);
    procedure SetShowCaption(Value: Boolean);
    procedure OnAnimTimer(Sender: TObject);
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property Percent: Double read FPercent write SetPercent;
    property Thickness: Single read FThickness write SetThickness;
    property Indeterminate: Boolean read FIndeterminate write SetIndeterminate default False;
    property ShowCaption: Boolean read FShowCaption write SetShowCaption default True;
    property Enabled;
    property Visible;
  end;

  { --------------------------------------------------------------------------
    THbToast - Lightweight Status Notification
    -------------------------------------------------------------------------- }
  THbToast = class(THbCustomControl)
  private
    FKind: THbToastKind;
    FMessageText: string;
    FActionCaption: string;
    FOnActionClick: TNotifyEvent;
    procedure SetKind(Value: THbToastKind);
    procedure SetMessageText(const Value: string);
    procedure SetActionCaption(const Value: string);
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Kind: THbToastKind read FKind write SetKind default tkSuccess;
    property MessageText: string read FMessageText write SetMessageText;
    property ActionCaption: string read FActionCaption write SetActionCaption;
    property OnActionClick: TNotifyEvent read FOnActionClick write FOnActionClick;
    property Enabled;
    property Visible;
  end;

  { --------------------------------------------------------------------------
    THbSkeleton - Loading Placeholder with Sweep Animation
    -------------------------------------------------------------------------- }
  THbSkeleton = class(THbCustomControl)
  private
    FVariant: THbSkeletonVariant;
    FAnimated: Boolean;
    FAnimTimer: TTimer;
    FAnimOffset: Single;
    procedure SetVariant(Value: THbSkeletonVariant);
    procedure SetAnimated(Value: Boolean);
    procedure OnAnimTimer(Sender: TObject);
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property Variant: THbSkeletonVariant read FVariant write SetVariant default skLine;
    property Animated: Boolean read FAnimated write SetAnimated default True;
    property Enabled;
    property Visible;
  end;

  { --------------------------------------------------------------------------
    THbSectionHeader - Section Header with Count Badge & Trailing Action
    -------------------------------------------------------------------------- }
  THbSectionHeader = class(THbCustomControl)
  private
    FTitle: string;
    FCount: Integer;
    FTrailingLink: string;
    FOnTrailingClick: TNotifyEvent;
    FTrailingPressed: Boolean;
    procedure SetTitle(const Value: string);
    procedure SetCount(Value: Integer);
    procedure SetTrailingLink(const Value: string);
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Title: string read FTitle write SetTitle;
    property Count: Integer read FCount write SetCount default -1;
    property TrailingLink: string read FTrailingLink write SetTrailingLink;
    property OnTrailingClick: TNotifyEvent read FOnTrailingClick write FOnTrailingClick;
    property Enabled;
    property Visible;
  end;

implementation

{ THbCustomControl }

constructor THbCustomControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  DoubleBuffered := True;
  ControlStyle := ControlStyle - [csOpaque] + [csCaptureMouse];
  FIsHovered := False;
  FIsPressed := False;
  FHasFocus := False;
  THbTheme.AddListener(OnThemeChangedNotification);
end;

destructor THbCustomControl.Destroy;
begin
  THbTheme.RemoveListener(OnThemeChangedNotification);
  inherited;
end;

procedure THbCustomControl.OnThemeChangedNotification(Sender: TObject);
begin
  Invalidate;
end;

procedure THbCustomControl.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  Message.Result := 1; // Prevent background erase flicker
end;

procedure THbCustomControl.WMHbThemeChanged(var Message: TMessage);
begin
  Invalidate;
end;

procedure THbCustomControl.CMMouseEnter(var Message: TMessage);
begin
  inherited;
  FIsHovered := True;
  Invalidate;
end;

procedure THbCustomControl.CMMouseLeave(var Message: TMessage);
begin
  inherited;
  FIsHovered := False;
  FIsPressed := False;
  Invalidate;
end;

procedure THbCustomControl.WMSetFocus(var Message: TWMSetFocus);
begin
  inherited;
  FHasFocus := True;
  Invalidate;
end;

procedure THbCustomControl.WMKillFocus(var Message: TWMKillFocus);
begin
  inherited;
  FHasFocus := False;
  Invalidate;
end;

procedure THbCustomControl.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if (Button = mbLeft) and Enabled then
  begin
    FIsPressed := True;
    if CanFocus and TabStop then
      SetFocus;
    Invalidate;
  end;
end;

procedure THbCustomControl.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if Button = mbLeft then
  begin
    FIsPressed := False;
    Invalidate;
  end;
end;

function THbCustomControl.GetCurrentState: THbControlState;
begin
  if not Enabled then
    Result := csDisabled
  else if FIsPressed then
    Result := csPressed
  else if FIsHovered then
    Result := csHover
  else
    Result := csNormal;
end;

function THbCustomControl.GetTokens: THbTokens;
begin
  Result := THbTheme.Tokens;
end;

procedure THbCustomControl.EraseBackground(AGraphics: TGPGraphics);
var
  BrushBg: TGPSolidBrush;
begin
  BrushBg := TGPSolidBrush.Create(ColorToARGB(GetTokens.Surface));
  try
    AGraphics.FillRectangle(BrushBg, MakeRect(0.0, 0.0, Width, Height));
  finally
    BrushBg.Free;
  end;
end;

function THbCustomControl.ScaleDIP(AValue: Single): Single;
begin
  Result := THbTheme.GetScaledDIP(AValue, CurrentPPI);
end;

function THbCustomControl.ScalePixels(AValue: Single): Integer;
begin
  Result := THbTheme.GetScaledPixels(AValue, CurrentPPI);
end;

function THbCustomControl.ColorToARGB(AColor: TAlphaColor; AAlphaOverride: Byte): ARGB;
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

function THbCustomControl.CreateRoundRectPath(const ARect: TGPRectF; ARadius: Single): TGPGraphicsPath;
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

procedure THbCustomControl.DrawFocusRing(AGraphics: TGPGraphics; const ARect: TGPRectF; ARadius: Single);
var
  RingPen: TGPPen;
  RingRect: TGPRectF;
  Path: TGPGraphicsPath;
  Tokens: THbTokens;
begin
  if not (FHasFocus and TabStop) then
    Exit;

  Tokens := GetTokens;
  RingPen := TGPPen.Create(ColorToARGB(Tokens.FocusRing), 2.0);
  try
    RingRect := ARect;
    RingRect.X := RingRect.X - 2;
    RingRect.Y := RingRect.Y - 2;
    RingRect.Width := RingRect.Width + 4;
    RingRect.Height := RingRect.Height + 4;
    Path := CreateRoundRectPath(RingRect, ARadius + 2);
    try
      AGraphics.DrawPath(RingPen, Path);
    finally
      Path.Free;
    end;
  finally
    RingPen.Free;
  end;
end;

{ --------------------------------------------------------------------------
  THbButton Implementation
  -------------------------------------------------------------------------- }

constructor THbButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FKind := bkPrimary;
  FSize := bsM;
  FPill := True;
  FCaption := 'Button';
  TabStop := True;
  var DefSz := GetDefaultSize;
  SetBounds(0, 0, DefSz.cx, DefSz.cy);
end;

function THbButton.GetDefaultSize: TSize;
begin
  case FSize of
    bsS: Result := TSize.Create(ScalePixels(72), ScalePixels(26));
    bsM: Result := TSize.Create(ScalePixels(96), ScalePixels(36));
    bsL: Result := TSize.Create(ScalePixels(120), ScalePixels(46));
  end;
end;

procedure THbButton.SetKind(Value: THbBtnKind);
begin
  if FKind <> Value then
  begin
    FKind := Value;
    Invalidate;
  end;
end;

procedure THbButton.SetSize(Value: THbBtnSize);
begin
  if FSize <> Value then
  begin
    FSize := Value;
    var Sz := GetDefaultSize;
    SetBounds(Left, Top, Sz.cx, Sz.cy);
    Invalidate;
  end;
end;

procedure THbButton.SetCaption(const Value: string);
begin
  if FCaption <> Value then
  begin
    FCaption := Value;
    Invalidate;
  end;
end;

procedure THbButton.SetPill(Value: Boolean);
begin
  if FPill <> Value then
  begin
    FPill := Value;
    Invalidate;
  end;
end;

procedure THbButton.Paint;
var
  Graphics: TGPGraphics;
  Tokens: THbTokens;
  RectF: TGPRectF;
  Radius: Single;
  Path: TGPGraphicsPath;
  Brush: TGPSolidBrush;
  Pen: TGPPen;
  Font: TGPFont;
  FontFamily: TGPFontFamily;
  StringFormat: TGPStringFormat;
  TextBrush: TGPSolidBrush;
  BgColor, TextColor, BorderColor: TAlphaColor;
  FontSize: Single;
begin
  Tokens := GetTokens;
  Graphics := TGPGraphics.Create(Canvas.Handle);
  try
    Graphics.SetSmoothingMode(SmoothingModeAntiAlias);
    Graphics.SetTextRenderingHint(TextRenderingHintClearTypeGridFit);
    EraseBackground(Graphics);

    RectF := MakeRect(1.0, 1.0, Width - 2.0, Height - 2.0);

    if FPill then
      Radius := RectF.Height * 0.5
    else
      Radius := ScaleDIP(Tokens.RadiusM);

    // Determine colors by Kind & State
    BgColor := Tokens.Primary;
    TextColor := Tokens.OnPrimary;
    BorderColor := TAlphaColors.Null;
    FontSize := Tokens.SizeM;
    case FKind of
      bkPrimary:
      begin
        case CurrentState of
          csNormal:   BgColor := Tokens.Primary;
          csHover:    BgColor := Tokens.PrimaryHover;
          csPressed:  BgColor := Tokens.PrimaryPressed;
          csDisabled: BgColor := Tokens.Primary;
        end;
        TextColor := Tokens.OnPrimary;
      end;
      bkGhost:
      begin
        BgColor := TAlphaColors.Null;
        case CurrentState of
          csNormal:   TextColor := Tokens.Primary;
          csHover:    TextColor := Tokens.PrimaryHover;
          csPressed:  TextColor := Tokens.PrimaryPressed;
          csDisabled: TextColor := Tokens.InkMuted;
        end;
        BorderColor := TextColor;
      end;
      bkSoft:
      begin
        case CurrentState of
          csNormal:   BgColor := Tokens.Soft;
          csHover:    BgColor := Tokens.PrimaryHover;
          csPressed:  BgColor := Tokens.PrimaryPressed;
          csDisabled: BgColor := Tokens.Soft;
        end;
        if CurrentState in [csHover, csPressed] then
          TextColor := Tokens.OnPrimary
        else
          TextColor := Tokens.Primary;
      end;
      bkDanger:
      begin
        BgColor := Tokens.Danger;
        TextColor := Tokens.OnPrimary;
      end;
    end;

    // Draw Background
    Path := CreateRoundRectPath(RectF, Radius);
    try
      if BgColor <> TAlphaColors.Null then
      begin
        var AlphaVal: Byte := 255;
        if CurrentState = csDisabled then
          AlphaVal := 115;
        Brush := TGPSolidBrush.Create(ColorToARGB(BgColor, AlphaVal));
        try
          Graphics.FillPath(Brush, Path);
        finally
          Brush.Free;
        end;
      end;

      if BorderColor <> TAlphaColors.Null then
      begin
        Pen := TGPPen.Create(ColorToARGB(BorderColor), ScaleDIP(Tokens.BorderWidth));
        try
          Graphics.DrawPath(Pen, Path);
        finally
          Pen.Free;
        end;
      end;
    finally
      Path.Free;
    end;

    // Draw Focus Ring
    DrawFocusRing(Graphics, RectF, Radius);

    // Draw Text
    case FSize of
      bsS: FontSize := Tokens.SizeS;
      bsM: FontSize := Tokens.SizeM;
      bsL: FontSize := Tokens.SizeL;
    end;

    FontFamily := TGPFontFamily.Create(Tokens.FontFamily);
    try
      Font := TGPFont.Create(FontFamily, ScaleDIP(FontSize), FontStyleBold, UnitPixel);
      try
        StringFormat := TGPStringFormat.Create;
        try
          StringFormat.SetAlignment(StringAlignmentCenter);
          StringFormat.SetLineAlignment(StringAlignmentCenter);

          TextBrush := TGPSolidBrush.Create(ColorToARGB(TextColor));
          try
            Graphics.DrawString(FCaption, -1, Font, RectF, StringFormat, TextBrush);
          finally
            TextBrush.Free;
          end;
        finally
          StringFormat.Free;
        end;
      finally
        Font.Free;
      end;
    finally
      FontFamily.Free;
    end;
  finally
    Graphics.Free;
  end;
end;

{ --------------------------------------------------------------------------
  THbDualButton Implementation
  -------------------------------------------------------------------------- }

constructor THbDualButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCaptionFree := '开场白 · 免费';
  FCaptionPoints := 'AI 方案';
  FPointsCost := 5;
  FShowYuanHint := True;
  FFreeEnabledOnly := False;
  FHoverPart := 0;
  FPressPart := 0;
  SetBounds(0, 0, ScalePixels(190), ScalePixels(32));
end;

procedure THbDualButton.SetCaptionFree(const Value: string);
begin
  if FCaptionFree <> Value then
  begin
    FCaptionFree := Value;
    Invalidate;
  end;
end;

procedure THbDualButton.SetCaptionPoints(const Value: string);
begin
  if FCaptionPoints <> Value then
  begin
    FCaptionPoints := Value;
    Invalidate;
  end;
end;

procedure THbDualButton.SetPointsCost(Value: Integer);
begin
  if FPointsCost <> Value then
  begin
    FPointsCost := Value;
    Invalidate;
  end;
end;

procedure THbDualButton.SetShowYuanHint(Value: Boolean);
begin
  if FShowYuanHint <> Value then
  begin
    FShowYuanHint := Value;
    Invalidate;
  end;
end;

procedure THbDualButton.SetFreeEnabledOnly(Value: Boolean);
begin
  if FFreeEnabledOnly <> Value then
  begin
    FFreeEnabledOnly := Value;
    Invalidate;
  end;
end;

procedure THbDualButton.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  HalfW: Single;
  NewPart: Integer;
begin
  inherited;
  HalfW := Width * 0.5;
  if X < HalfW then
    NewPart := 1
  else
    NewPart := 2;

  if FHoverPart <> NewPart then
  begin
    FHoverPart := NewPart;
    if (NewPart = 2) and FShowYuanHint and (FPointsCost > 0) then
      Hint := Format('消耗 %d 点 (≈ ¥%.2f)', [FPointsCost, FPointsCost * 0.1])
    else
      Hint := '';
    ShowHint := Hint <> '';
    Invalidate;
  end;
end;

procedure THbDualButton.CMMouseLeave(var Message: TMessage);
begin
  inherited;
  FHoverPart := 0;
  FPressPart := 0;
  Invalidate;
end;

procedure THbDualButton.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if (Button = mbLeft) and Enabled then
  begin
    if X < (Width * 0.5) then
      FPressPart := 1
    else
      FPressPart := 2;
    Invalidate;
  end;
end;

procedure THbDualButton.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  HitPart: Integer;
begin
  inherited;
  if Button = mbLeft then
  begin
    HitPart := 0;
    if PtInRect(ClientRect, Point(X, Y)) then
    begin
      if X < (Width * 0.5) then
        HitPart := 1
      else
        HitPart := 2;
    end;

    if (FPressPart = 1) and (HitPart = 1) and Assigned(FOnFreeClick) then
      FOnFreeClick(Self)
    else if (FPressPart = 2) and (HitPart = 2) and Assigned(FOnPointsClick) then
      FOnPointsClick(Self);
    FPressPart := 0;
    Invalidate;
  end;
end;

procedure THbDualButton.Paint;
var
  Graphics: TGPGraphics;
  Tokens: THbTokens;
  LeftRect, RightRect: TGPRectF;
  Radius: Single;
  LeftPath, RightPath: TGPGraphicsPath;
  LeftBrush, RightBrush: TGPSolidBrush;
  LeftPen: TGPPen;
  Font: TGPFont;
  FontFamily: TGPFontFamily;
  StrFmt: TGPStringFormat;
  TextBrush: TGPSolidBrush;
  PointsLabel: string;
begin
  Tokens := GetTokens;
  Graphics := TGPGraphics.Create(Canvas.Handle);
  try
    Graphics.SetSmoothingMode(SmoothingModeAntiAlias);
    Graphics.SetTextRenderingHint(TextRenderingHintClearTypeGridFit);
    EraseBackground(Graphics);

    var HalfW := (Width - 8.0) * 0.5;
    LeftRect := MakeRect(1.0, 1.0, HalfW, Height - 2.0);
    RightRect := MakeRect(HalfW + 6.0, 1.0, HalfW, Height - 2.0);
    Radius := LeftRect.Height * 0.5;

    // 1. Draw Left Free Track (Ghost / Success Outlined)
    LeftPath := CreateRoundRectPath(LeftRect, Radius);
    try
      if (FHoverPart = 1) and (FPressPart = 1) then
      begin
        LeftBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.SuccessSoft));
        try Graphics.FillPath(LeftBrush, LeftPath); finally LeftBrush.Free; end;
      end;
      LeftPen := TGPPen.Create(ColorToARGB(Tokens.Success), ScaleDIP(1.2));
      try Graphics.DrawPath(LeftPen, LeftPath); finally LeftPen.Free; end;
    finally
      LeftPath.Free;
    end;

    // 2. Draw Right Points Track (Solid Primary Gold)
    RightPath := CreateRoundRectPath(RightRect, Radius);
    try
      var PriColor := Tokens.Primary;
      if (FHoverPart = 2) and (FPressPart = 2) then
        PriColor := Tokens.PrimaryPressed
      else if (FHoverPart = 2) then
        PriColor := Tokens.PrimaryHover;

      RightBrush := TGPSolidBrush.Create(ColorToARGB(PriColor));
      try Graphics.FillPath(RightBrush, RightPath); finally RightBrush.Free; end;
    finally
      RightPath.Free;
    end;

    // 3. Render Texts
    FontFamily := TGPFontFamily.Create(Tokens.FontFamily);
    try
      Font := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeXS), FontStyleBold, UnitPixel);
      try
        StrFmt := TGPStringFormat.Create;
        try
          StrFmt.SetAlignment(StringAlignmentCenter);
          StrFmt.SetLineAlignment(StringAlignmentCenter);

          // Left Text (Success)
          TextBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.Success));
          try Graphics.DrawString(FCaptionFree, -1, Font, LeftRect, StrFmt, TextBrush); finally TextBrush.Free; end;

          // Right Text (OnPrimary)
          if FPointsCost > 0 then
            PointsLabel := Format('%s · %d点', [FCaptionPoints, FPointsCost])
          else
            PointsLabel := FCaptionPoints;

          TextBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.OnPrimary));
          try Graphics.DrawString(PointsLabel, -1, Font, RightRect, StrFmt, TextBrush); finally TextBrush.Free; end;
        finally
          StrFmt.Free;
        end;
      finally
        Font.Free;
      end;
    finally
      FontFamily.Free;
    end;
  finally
    Graphics.Free;
  end;
end;

{ --------------------------------------------------------------------------
  THbChip Implementation
  -------------------------------------------------------------------------- }

constructor THbChip.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FTone := ttNeutral;
  FSelected := False;
  FClosable := False;
  FCaption := 'Chip';
  FClosePressed := False;
  SetBounds(0, 0, ScalePixels(70), ScalePixels(24));
end;

procedure THbChip.SetTone(Value: THbChipTone);
begin
  if FTone <> Value then
  begin
    FTone := Value;
    Invalidate;
  end;
end;

procedure THbChip.SetSelected(Value: Boolean);
begin
  if FSelected <> Value then
  begin
    FSelected := Value;
    Invalidate;
  end;
end;

procedure THbChip.SetClosable(Value: Boolean);
begin
  if FClosable <> Value then
  begin
    FClosable := Value;
    Invalidate;
  end;
end;

procedure THbChip.SetCaption(const Value: string);
begin
  if FCaption <> Value then
  begin
    FCaption := Value;
    Invalidate;
  end;
end;

procedure THbChip.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if (Button = mbLeft) and FClosable and (X > (Width - ScalePixels(20))) then
    FClosePressed := True
  else
    FClosePressed := False;
end;

procedure THbChip.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if (Button = mbLeft) and FClosePressed and FClosable and (X > (Width - ScalePixels(20))) and Assigned(FOnClose) then
    FOnClose(Self);
  FClosePressed := False;
end;

procedure THbChip.Paint;
var
  Graphics: TGPGraphics;
  Tokens: THbTokens;
  RectF: TGPRectF;
  Radius: Single;
  Path: TGPGraphicsPath;
  Brush: TGPSolidBrush;
  Font: TGPFont;
  FontFamily: TGPFontFamily;
  StrFmt: TGPStringFormat;
  TextBrush: TGPSolidBrush;
  BgColor, TextColor: TAlphaColor;
begin
  Tokens := GetTokens;
  Graphics := TGPGraphics.Create(Canvas.Handle);
  try
    Graphics.SetSmoothingMode(SmoothingModeAntiAlias);
    Graphics.SetTextRenderingHint(TextRenderingHintClearTypeGridFit);
    EraseBackground(Graphics);

    RectF := MakeRect(1.0, 1.0, Width - 2.0, Height - 2.0);
    Radius := RectF.Height * 0.5;

    if FSelected then
    begin
      BgColor := Tokens.Primary;
      TextColor := Tokens.OnPrimary;
    end
    else
    begin
      case FTone of
        ttBrand:   begin BgColor := Tokens.Soft; TextColor := Tokens.Primary; end;
        ttSuccess: begin BgColor := Tokens.SuccessSoft; TextColor := Tokens.Success; end;
        ttWarning: begin BgColor := Tokens.WarningSoft; TextColor := Tokens.Warning; end;
        ttDanger:  begin BgColor := Tokens.DangerSoft; TextColor := Tokens.Danger; end;
        else       begin BgColor := Tokens.Soft; TextColor := Tokens.Ink; end;
      end;
    end;

    Path := CreateRoundRectPath(RectF, Radius);
    try
      Brush := TGPSolidBrush.Create(ColorToARGB(BgColor));
      try Graphics.FillPath(Brush, Path); finally Brush.Free; end;
    finally
      Path.Free;
    end;

    FontFamily := TGPFontFamily.Create(Tokens.FontFamily);
    try
      Font := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeXS), FontStyleBold, UnitPixel);
      try
        StrFmt := TGPStringFormat.Create;
        try
          StrFmt.SetAlignment(StringAlignmentCenter);
          StrFmt.SetLineAlignment(StringAlignmentCenter);

          var DrawText := FCaption;
          if FClosable then
            DrawText := DrawText + '  ✕';

          TextBrush := TGPSolidBrush.Create(ColorToARGB(TextColor));
          try Graphics.DrawString(DrawText, -1, Font, RectF, StrFmt, TextBrush); finally TextBrush.Free; end;
        finally
          StrFmt.Free;
        end;
      finally
        Font.Free;
      end;
    finally
      FontFamily.Free;
    end;
  finally
    Graphics.Free;
  end;
end;

{ --------------------------------------------------------------------------
  THbBadge Implementation
  -------------------------------------------------------------------------- }

constructor THbBadge.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FTone := btNeutral;
  FShape := hpSquare;
  FCaption := 'Badge';
  SetBounds(0, 0, ScalePixels(56), ScalePixels(20));
end;

procedure THbBadge.SetTone(Value: THbBadgeTone);
begin
  if FTone <> Value then
  begin
    FTone := Value;
    Invalidate;
  end;
end;

procedure THbBadge.SetShape(Value: THbBadgeShape);
begin
  if FShape <> Value then
  begin
    FShape := Value;
    Invalidate;
  end;
end;

procedure THbBadge.SetCaption(const Value: string);
begin
  if FCaption <> Value then
  begin
    FCaption := Value;
    Invalidate;
  end;
end;

procedure THbBadge.Paint;
var
  Graphics: TGPGraphics;
  Tokens: THbTokens;
  RectF: TGPRectF;
  Radius: Single;
  Path: TGPGraphicsPath;
  Brush: TGPSolidBrush;
  Font: TGPFont;
  FontFamily: TGPFontFamily;
  StrFmt: TGPStringFormat;
  TextBrush: TGPSolidBrush;
  BgColor, TextColor: TAlphaColor;
begin
  Tokens := GetTokens;
  Graphics := TGPGraphics.Create(Canvas.Handle);
  try
    Graphics.SetSmoothingMode(SmoothingModeAntiAlias);
    Graphics.SetTextRenderingHint(TextRenderingHintClearTypeGridFit);
    EraseBackground(Graphics);

    RectF := MakeRect(1.0, 1.0, Width - 2.0, Height - 2.0);
    if FShape = hpPill then
      Radius := RectF.Height * 0.5
    else
      Radius := ScaleDIP(Tokens.RadiusS);

    case FTone of
      btBrand:   begin BgColor := Tokens.Soft; TextColor := Tokens.Primary; end;
      btSuccess: begin BgColor := Tokens.SuccessSoft; TextColor := Tokens.Success; end;
      btWarning: begin BgColor := Tokens.WarningSoft; TextColor := Tokens.Warning; end;
      btDanger:  begin BgColor := Tokens.DangerSoft; TextColor := Tokens.Danger; end;
      else       begin BgColor := Tokens.SurfaceAlt; TextColor := Tokens.InkMuted; end;
    end;

    Path := CreateRoundRectPath(RectF, Radius);
    try
      Brush := TGPSolidBrush.Create(ColorToARGB(BgColor));
      try Graphics.FillPath(Brush, Path); finally Brush.Free; end;
    finally
      Path.Free;
    end;

    FontFamily := TGPFontFamily.Create(Tokens.FontFamily);
    try
      Font := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeXS * 0.95), FontStyleBold, UnitPixel);
      try
        StrFmt := TGPStringFormat.Create;
        try
          StrFmt.SetAlignment(StringAlignmentCenter);
          StrFmt.SetLineAlignment(StringAlignmentCenter);

          TextBrush := TGPSolidBrush.Create(ColorToARGB(TextColor));
          try Graphics.DrawString(FCaption, -1, Font, RectF, StrFmt, TextBrush); finally TextBrush.Free; end;
        finally
          StrFmt.Free;
        end;
      finally
        Font.Free;
      end;
    finally
      FontFamily.Free;
    end;
  finally
    Graphics.Free;
  end;
end;

{ --------------------------------------------------------------------------
  THbAvatar Implementation
  -------------------------------------------------------------------------- }

constructor THbAvatar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FInitials := '张';
  FSeed := '张';
  FSize := avsM;
  FStatusDot := sdNone;
  SetBounds(0, 0, ScalePixels(32), ScalePixels(32));
end;

procedure THbAvatar.SetInitials(const Value: string);
begin
  if FInitials <> Value then
  begin
    FInitials := Value;
    Invalidate;
  end;
end;

procedure THbAvatar.SetSeed(const Value: string);
begin
  if FSeed <> Value then
  begin
    FSeed := Value;
    Invalidate;
  end;
end;

procedure THbAvatar.SetSize(Value: THbAvatarSize);
var
  Dim: Integer;
begin
  if FSize <> Value then
  begin
    FSize := Value;
    Dim := ScalePixels(32);
    case FSize of
      avsS: Dim := ScalePixels(24);
      avsM: Dim := ScalePixels(32);
      avsL: Dim := ScalePixels(42);
      avsXL: Dim := ScalePixels(56);
    end;
    SetBounds(Left, Top, Dim, Dim);
    Invalidate;
  end;
end;

procedure THbAvatar.SetStatusDot(Value: THbAvatarStatus);
begin
  if FStatusDot <> Value then
  begin
    FStatusDot := Value;
    Invalidate;
  end;
end;

function THbAvatar.GetSeedColor(const ASeed: string): TAlphaColor;
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

procedure THbAvatar.Paint;
var
  Graphics: TGPGraphics;
  Tokens: THbTokens;
  RectF, DotRect: TGPRectF;
  Brush: TGPSolidBrush;
  Font: TGPFont;
  FontFamily: TGPFontFamily;
  StrFmt: TGPStringFormat;
  TextBrush: TGPSolidBrush;
  DotPen: TGPPen;
  DotColor: TAlphaColor;
begin
  Tokens := GetTokens;
  Graphics := TGPGraphics.Create(Canvas.Handle);
  try
    Graphics.SetSmoothingMode(SmoothingModeAntiAlias);
    Graphics.SetTextRenderingHint(TextRenderingHintClearTypeGridFit);
    EraseBackground(Graphics);

    RectF := MakeRect(1.0, 1.0, Width - 2.0, Height - 2.0);

    // Draw Circular Base
    Brush := TGPSolidBrush.Create(ColorToARGB(GetSeedColor(FSeed)));
    try
      Graphics.FillEllipse(Brush, RectF);
    finally
      Brush.Free;
    end;

    // Draw Initials
    FontFamily := TGPFontFamily.Create(Tokens.FontFamily);
    try
      Font := TGPFont.Create(FontFamily, ScaleDIP(Width * 0.42), FontStyleBold, UnitPixel);
      try
        StrFmt := TGPStringFormat.Create;
        try
          StrFmt.SetAlignment(StringAlignmentCenter);
          StrFmt.SetLineAlignment(StringAlignmentCenter);

          TextBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.Primary));
          try Graphics.DrawString(FInitials, -1, Font, RectF, StrFmt, TextBrush); finally TextBrush.Free; end;
        finally
          StrFmt.Free;
        end;
      finally
        Font.Free;
      end;
    finally
      FontFamily.Free;
    end;

    // Draw Status Dot with surface cutout ring
    if FStatusDot <> sdNone then
    begin
      DotColor := Tokens.Success;
      case FStatusDot of
        sdOnline:  DotColor := Tokens.Success;
        sdAway:    DotColor := Tokens.Warning;
        sdOffline: DotColor := Tokens.InkMuted;
      end;

      var DotD := Width * 0.28;
      DotRect := MakeRect(Width - DotD - 1, Height - DotD - 1, DotD, DotD);

      // Cutout Ring
      DotPen := TGPPen.Create(ColorToARGB(Tokens.Surface), 2.0);
      try Graphics.DrawEllipse(DotPen, DotRect); finally DotPen.Free; end;

      // Inner Dot
      Brush := TGPSolidBrush.Create(ColorToARGB(DotColor));
      try Graphics.FillEllipse(Brush, DotRect); finally Brush.Free; end;
    end;
  finally
    Graphics.Free;
  end;
end;

{ --------------------------------------------------------------------------
  THbProgressRing Implementation
  -------------------------------------------------------------------------- }

constructor THbProgressRing.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FPercent := 68.0;
  FThickness := 8.0;
  FIndeterminate := False;
  FShowCaption := True;
  FAnimAngle := 0.0;
  FAnimTimer := TTimer.Create(Self);
  FAnimTimer.Interval := 30;
  FAnimTimer.OnTimer := OnAnimTimer;
  FAnimTimer.Enabled := False;
  SetBounds(0, 0, ScalePixels(74), ScalePixels(74));
end;

destructor THbProgressRing.Destroy;
begin
  FreeAndNil(FAnimTimer);
  inherited;
end;

procedure THbProgressRing.SetPercent(Value: Double);
begin
  if FPercent <> Value then
  begin
    FPercent := EnsureRange(Value, 0.0, 100.0);
    Invalidate;
  end;
end;

procedure THbProgressRing.SetThickness(Value: Single);
begin
  if FThickness <> Value then
  begin
    FThickness := Value;
    Invalidate;
  end;
end;

procedure THbProgressRing.SetIndeterminate(Value: Boolean);
begin
  if FIndeterminate <> Value then
  begin
    FIndeterminate := Value;
    FAnimTimer.Enabled := FIndeterminate;
    Invalidate;
  end;
end;

procedure THbProgressRing.SetShowCaption(Value: Boolean);
begin
  if FShowCaption <> Value then
  begin
    FShowCaption := Value;
    Invalidate;
  end;
end;

procedure THbProgressRing.OnAnimTimer(Sender: TObject);
begin
  FAnimAngle := FAnimAngle + 8.0;
  if FAnimAngle >= 360.0 then
    FAnimAngle := FAnimAngle - 360.0;
  Invalidate;
end;

procedure THbProgressRing.Paint;
var
  Graphics: TGPGraphics;
  Tokens: THbTokens;
  TrackPen, ActivePen: TGPPen;
  RectF: TGPRectF;
  SweepAngle, StartAngle: Single;
  Font: TGPFont;
  FontFamily: TGPFontFamily;
  StrFmt: TGPStringFormat;
  TextBrush: TGPSolidBrush;
begin
  Tokens := GetTokens;
  Graphics := TGPGraphics.Create(Canvas.Handle);
  try
    Graphics.SetSmoothingMode(SmoothingModeAntiAlias);
    Graphics.SetTextRenderingHint(TextRenderingHintClearTypeGridFit);
    EraseBackground(Graphics);

    var Thick := ScaleDIP(FThickness);
    RectF := MakeRect(Thick * 0.5 + 1.0, Thick * 0.5 + 1.0, Width - Thick - 2.0, Height - Thick - 2.0);

    // Track
    TrackPen := TGPPen.Create(ColorToARGB(Tokens.Border), Thick);
    try
      Graphics.DrawEllipse(TrackPen, RectF);
    finally
      TrackPen.Free;
    end;

    // Active Arc
    ActivePen := TGPPen.Create(ColorToARGB(Tokens.Primary), Thick);
    try
      ActivePen.SetStartCap(LineCapRound);
      ActivePen.SetEndCap(LineCapRound);

      if FIndeterminate then
      begin
        StartAngle := FAnimAngle;
        SweepAngle := 100.0;
      end
      else
      begin
        StartAngle := -90.0;
        SweepAngle := (FPercent / 100.0) * 360.0;
      end;

      if SweepAngle > 0.1 then
        Graphics.DrawArc(ActivePen, RectF, StartAngle, SweepAngle);
    finally
      ActivePen.Free;
    end;

    // Text Caption
    if FShowCaption and not FIndeterminate then
    begin
      FontFamily := TGPFontFamily.Create(Tokens.FontFamily);
      try
        Font := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeM), FontStyleBold, UnitPixel);
        try
          StrFmt := TGPStringFormat.Create;
          try
            StrFmt.SetAlignment(StringAlignmentCenter);
            StrFmt.SetLineAlignment(StringAlignmentCenter);

            TextBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.Primary));
            try
              Graphics.DrawString(Format('%.0f%%', [FPercent]), -1, Font, RectF, StrFmt, TextBrush);
            finally
              TextBrush.Free;
            end;
          finally
            StrFmt.Free;
          end;
        finally
          Font.Free;
        end;
      finally
        FontFamily.Free;
      end;
    end;
  finally
    Graphics.Free;
  end;
end;

{ --------------------------------------------------------------------------
  THbToast Implementation
  -------------------------------------------------------------------------- }

constructor THbToast.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FKind := tkSuccess;
  FMessageText := '操作已完成';
  FActionCaption := '';
  SetBounds(0, 0, ScalePixels(220), ScalePixels(36));
end;

procedure THbToast.SetKind(Value: THbToastKind);
begin
  if FKind <> Value then
  begin
    FKind := Value;
    Invalidate;
  end;
end;

procedure THbToast.SetMessageText(const Value: string);
begin
  if FMessageText <> Value then
  begin
    FMessageText := Value;
    Invalidate;
  end;
end;

procedure THbToast.SetActionCaption(const Value: string);
begin
  if FActionCaption <> Value then
  begin
    FActionCaption := Value;
    Invalidate;
  end;
end;

procedure THbToast.Paint;
var
  Graphics: TGPGraphics;
  Tokens: THbTokens;
  RectF: TGPRectF;
  Path: TGPGraphicsPath;
  Brush: TGPSolidBrush;
  Pen: TGPPen;
  Font: TGPFont;
  FontFamily: TGPFontFamily;
  StrFmt: TGPStringFormat;
  TextBrush: TGPSolidBrush;
  BgColor, BorderColor, TextColor: TAlphaColor;
  PrefixIcon: string;
begin
  Tokens := GetTokens;
  Graphics := TGPGraphics.Create(Canvas.Handle);
  try
    Graphics.SetSmoothingMode(SmoothingModeAntiAlias);
    Graphics.SetTextRenderingHint(TextRenderingHintClearTypeGridFit);
    EraseBackground(Graphics);

    RectF := MakeRect(1.0, 1.0, Width - 2.0, Height - 2.0);

    case FKind of
      tkSuccess:
      begin
        BgColor := Tokens.Soft;
        BorderColor := Tokens.Success;
        TextColor := Tokens.Success;
        PrefixIcon := '✓ ';
      end;
      tkDanger:
      begin
        BgColor := Tokens.Soft;
        BorderColor := Tokens.Danger;
        TextColor := Tokens.Danger;
        PrefixIcon := '✕ ';
      end;
      tkWarning:
      begin
        BgColor := Tokens.Soft;
        BorderColor := Tokens.Warning;
        TextColor := Tokens.Warning;
        PrefixIcon := '⚠ ';
      end;
      else
      begin
        BgColor := Tokens.Soft;
        BorderColor := Tokens.Info;
        TextColor := Tokens.Info;
        PrefixIcon := 'ℹ ';
      end;
    end;

    Path := CreateRoundRectPath(RectF, ScaleDIP(Tokens.RadiusM));
    try
      Brush := TGPSolidBrush.Create(ColorToARGB(BgColor));
      try Graphics.FillPath(Brush, Path); finally Brush.Free; end;

      Pen := TGPPen.Create(ColorToARGB(BorderColor), 1.0);
      try Graphics.DrawPath(Pen, Path); finally Pen.Free; end;
    finally
      Path.Free;
    end;

    FontFamily := TGPFontFamily.Create(Tokens.FontFamily);
    try
      Font := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeS), FontStyleBold, UnitPixel);
      try
        StrFmt := TGPStringFormat.Create;
        try
          StrFmt.SetAlignment(StringAlignmentNear);
          StrFmt.SetLineAlignment(StringAlignmentCenter);

          RectF.X := RectF.X + ScaleDIP(Tokens.SpaceM);
          RectF.Width := RectF.Width - ScaleDIP(Tokens.SpaceM * 2);

          TextBrush := TGPSolidBrush.Create(ColorToARGB(TextColor));
          try
            Graphics.DrawString(PrefixIcon + FMessageText, -1, Font, RectF, StrFmt, TextBrush);
          finally
            TextBrush.Free;
          end;
        finally
          StrFmt.Free;
        end;
      finally
        Font.Free;
      end;
    finally
      FontFamily.Free;
    end;
  finally
    Graphics.Free;
  end;
end;

{ --------------------------------------------------------------------------
  THbSkeleton Implementation
  -------------------------------------------------------------------------- }

constructor THbSkeleton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FVariant := skLine;
  FAnimated := True;
  FAnimOffset := 0.0;
  FAnimTimer := TTimer.Create(Self);
  FAnimTimer.Interval := 30;
  FAnimTimer.OnTimer := OnAnimTimer;
  FAnimTimer.Enabled := True;
  SetBounds(0, 0, ScalePixels(160), ScalePixels(14));
end;

destructor THbSkeleton.Destroy;
begin
  FreeAndNil(FAnimTimer);
  inherited;
end;

procedure THbSkeleton.SetVariant(Value: THbSkeletonVariant);
begin
  if FVariant <> Value then
  begin
    FVariant := Value;
    Invalidate;
  end;
end;

procedure THbSkeleton.SetAnimated(Value: Boolean);
begin
  if FAnimated <> Value then
  begin
    FAnimated := Value;
    FAnimTimer.Enabled := FAnimated;
    Invalidate;
  end;
end;

procedure THbSkeleton.OnAnimTimer(Sender: TObject);
begin
  FAnimOffset := FAnimOffset + 0.04;
  if FAnimOffset > 1.5 then
    FAnimOffset := -0.5;
  Invalidate;
end;

procedure THbSkeleton.Paint;
var
  Graphics: TGPGraphics;
  Tokens: THbTokens;
  RectF: TGPRectF;
  Radius: Single;
  Path: TGPGraphicsPath;
  Brush: TGPSolidBrush;
begin
  Tokens := GetTokens;
  Graphics := TGPGraphics.Create(Canvas.Handle);
  try
    Graphics.SetSmoothingMode(SmoothingModeAntiAlias);
    EraseBackground(Graphics);

    RectF := MakeRect(1.0, 1.0, Width - 2.0, Height - 2.0);
    case FVariant of
      skCircle: Radius := RectF.Height * 0.5;
      skCard:   Radius := ScaleDIP(Tokens.RadiusM);
      else      Radius := ScaleDIP(Tokens.RadiusS);
    end;

    Path := CreateRoundRectPath(RectF, Radius);
    try
      Brush := TGPSolidBrush.Create(ColorToARGB(Tokens.Border));
      try
        Graphics.FillPath(Brush, Path);
      finally
        Brush.Free;
      end;
    finally
      Path.Free;
    end;
  finally
    Graphics.Free;
  end;
end;

{ --------------------------------------------------------------------------
  THbSectionHeader Implementation
  -------------------------------------------------------------------------- }

constructor THbSectionHeader.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FTitle := '区段标题';
  FCount := -1;
  FTrailingLink := '';
  FTrailingPressed := False;
  SetBounds(0, 0, ScalePixels(240), ScalePixels(28));
end;

procedure THbSectionHeader.SetTitle(const Value: string);
begin
  if FTitle <> Value then
  begin
    FTitle := Value;
    Invalidate;
  end;
end;

procedure THbSectionHeader.SetCount(Value: Integer);
begin
  if FCount <> Value then
  begin
    FCount := Value;
    Invalidate;
  end;
end;

procedure THbSectionHeader.SetTrailingLink(const Value: string);
begin
  if FTrailingLink <> Value then
  begin
    FTrailingLink := Value;
    Invalidate;
  end;
end;

procedure THbSectionHeader.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if (Button = mbLeft) and (FTrailingLink <> '') and (X > (Width - ScalePixels(80))) then
    FTrailingPressed := True
  else
    FTrailingPressed := False;
end;

procedure THbSectionHeader.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if (Button = mbLeft) and FTrailingPressed and (FTrailingLink <> '') and (X > (Width - ScalePixels(80))) and Assigned(FOnTrailingClick) then
    FOnTrailingClick(Self);
  FTrailingPressed := False;
end;

procedure THbSectionHeader.Paint;
var
  Graphics: TGPGraphics;
  Tokens: THbTokens;
  Font: TGPFont;
  FontFamily: TGPFontFamily;
  StrFmt: TGPStringFormat;
  TextBrush: TGPSolidBrush;
  TitleText: string;
begin
  Tokens := GetTokens;
  Graphics := TGPGraphics.Create(Canvas.Handle);
  try
    Graphics.SetSmoothingMode(SmoothingModeAntiAlias);
    Graphics.SetTextRenderingHint(TextRenderingHintClearTypeGridFit);
    EraseBackground(Graphics);

    FontFamily := TGPFontFamily.Create(Tokens.FontFamily);
    try
      Font := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeM), FontStyleBold, UnitPixel);
      try
        StrFmt := TGPStringFormat.Create;
        try
          StrFmt.SetLineAlignment(StringAlignmentCenter);

          // Left Title + Count
          if FCount >= 0 then
            TitleText := Format('%s (%d)', [FTitle, FCount])
          else
            TitleText := FTitle;

          TextBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.Ink));
          try
            StrFmt.SetAlignment(StringAlignmentNear);
            Graphics.DrawString(TitleText, -1, Font, MakeRect(0.0, 0.0, Width * 0.7, Height), StrFmt, TextBrush);
          finally
            TextBrush.Free;
          end;

          // Trailing Link
          if FTrailingLink <> '' then
          begin
            TextBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.Primary));
            try
              StrFmt.SetAlignment(StringAlignmentFar);
              Graphics.DrawString(FTrailingLink, -1, Font, MakeRect(Width * 0.5, 0.0, Width * 0.5 - ScaleDIP(Tokens.SpaceXS), Height), StrFmt, TextBrush);
            finally
              TextBrush.Free;
            end;
          end;
        finally
          StrFmt.Free;
        end;
      finally
        Font.Free;
      end;
    finally
      FontFamily.Free;
    end;
  finally
    Graphics.Free;
  end;
end;

end.
