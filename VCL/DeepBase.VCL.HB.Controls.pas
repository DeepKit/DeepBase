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
  System.DateUtils,
  System.Types,
  System.Generics.Collections,
  Winapi.Windows,
  Winapi.Messages,
  Winapi.GDIPAPI,
  Winapi.GDIPOBJ,
  Vcl.Controls,
  Vcl.Graphics,
  Vcl.ExtCtrls,
  Vcl.Forms,
  DeepBase.HB.Core,
  DeepBase.HB.StateSlot.Types,
  DeepBase.HB.Touchpoint.Types,
  DeepBase.HB.Touchpoint.Engine,
  DeepBase.HB.Runtime,
  DeepBase.HB.Lifecycle,
  DeepBase.VCL.HB.Theme;

function GetCachedFontFamily(const AName: string): TGPFontFamily;
function GetCachedFont(const AName: string; ASize: Single; AStyle: Integer): TGPFont;

type
  THbControlState = (csNormal, csHover, csPressed, csDisabled);
  THbLifecyclePhase = DeepBase.HB.Runtime.THbLifecyclePhase;
  EHbLifecycleViolation = DeepBase.HB.Runtime.EHbLifecycleViolation;
  THbLifecycleErrorEvent = procedure(Sender: TObject; const AStep: string; AException: Exception) of object;

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
  THbCustomControl = class(TCustomControl, IHbSurfaceProvider)
  private
    FLife: THbLifecycleState;
    FTouchpoint: IHbTouchpoint;
    FOnLifecycleError: THbLifecycleErrorEvent;
    FIsHovered: Boolean;
    FIsPressed: Boolean;
    FHasFocus: Boolean;
    procedure CMMouseEnter(var Message: TMessage); message CM_MOUSEENTER;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
    procedure WMSetFocus(var Message: TWMSetFocus); message WM_SETFOCUS;
    procedure WMKillFocus(var Message: TWMKillFocus); message WM_KILLFOCUS;
    procedure WMHbThemeChanged(var Message: TMessage); message WM_HB_THEME_CHANGED;
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
    procedure WMPaint(var Message: TWMPaint); message WM_PAINT;
    procedure OnThemeChangedNotification(Sender: TObject);
    function GetLifecyclePhase: THbLifecyclePhase;
    procedure SetLifecyclePhase(Value: THbLifecyclePhase);
    function GetTouchpointId: string;
    procedure SetTouchpointId(const Value: string);
    function GetSurfaceId: string;
    procedure SetSurfaceId(const Value: string);
    function GetTargetState: string;
    procedure SetTargetState(const Value: string);
    function GetIsDisposed: Boolean;
  protected
    // 7-Step Lifecycle Pipeline
    procedure BindToken; virtual;
    procedure BindState; virtual;
    procedure AttachTouchpoint(const ATouchpoint: IHbTouchpoint); virtual;
    procedure Render; virtual;
    procedure EmitTelemetry; virtual;
    procedure HandleLifecycleError(const AStep: string; AException: Exception); virtual;

    function GetCurrentState: THbControlState; virtual;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure Paint; override;
    function GetTokens: THbTokens; virtual;
    function ScaleDIP(AValue: Single): Single; virtual;
    function ScalePixels(AValue: Single): Integer; virtual;

    // GDI+ Drawing Helpers
    procedure CreateParams(var Params: TCreateParams); override;
    procedure EraseBackground(AGraphics: TGPGraphics); virtual;
    procedure DrawFocusRing(AGraphics: TGPGraphics; const ARect: TGPRectF; ARadius: Single);
    function CreateRoundRectPath(const ARect: TGPRectF; ARadius: Single): TGPGraphicsPath;
    function ColorToARGB(AColor: TAlphaColor; AAlphaOverride: Byte = 0): ARGB;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure DoDispose; virtual;

    // Surface Provider & Background Resolution
    function GetContainerBgColor: TAlphaColor; virtual;
    function GetSurfaceColor: TAlphaColor; virtual;

    property LifecyclePhase: THbLifecyclePhase read GetLifecyclePhase write SetLifecyclePhase;
    property Touchpoint: IHbTouchpoint read FTouchpoint write FTouchpoint;
    property TouchpointId: string read GetTouchpointId write SetTouchpointId;
    property SurfaceId: string read GetSurfaceId write SetSurfaceId;
    property TargetState: string read GetTargetState write SetTargetState;
    property CurrentState: THbControlState read GetCurrentState;
    property IsDisposed: Boolean read GetIsDisposed;
    property OnLifecycleError: THbLifecycleErrorEvent read FOnLifecycleError write FOnLifecycleError;
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
    procedure Click; override;
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
    FCloseHovered: Boolean;
    function GetCloseRect: TGPRectF;
    procedure SetTone(Value: THbChipTone);
    procedure SetSelected(Value: Boolean);
    procedure SetClosable(Value: Boolean);
    procedure SetCaption(const Value: string);
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
  protected
    procedure Paint; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
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
    function GetTrailingRect: TGPRectF;
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

var
  GFontFamilyCache: TDictionary<string, TGPFontFamily>;
  GFontCache: TDictionary<string, TGPFont>;
  GFontCacheLock: TRTLCriticalSection;
  GStringFormatCenter: TGPStringFormat;

function GetCachedFontFamily(const AName: string): TGPFontFamily;
var
  FontName: string;
begin
  if AName <> '' then
    FontName := AName
  else
    FontName := THbTheme.Tokens.FontFamily;

  EnterCriticalSection(GFontCacheLock);
  try
    if not GFontFamilyCache.TryGetValue(FontName, Result) then
    begin
      Result := TGPFontFamily.Create(FontName);
      GFontFamilyCache.Add(FontName, Result);
    end;
  finally
    LeaveCriticalSection(GFontCacheLock);
  end;
end;

function GetCachedFont(const AName: string; ASize: Single; AStyle: Integer): TGPFont;
var
  Key: string;
  Family: TGPFontFamily;
  IntSize: Integer;
begin
  IntSize := Round(ASize * 10);
  Key := Format('%s_%d_%d', [AName, IntSize, AStyle]);
  EnterCriticalSection(GFontCacheLock);
  try
    if not GFontCache.TryGetValue(Key, Result) then
    begin
      Family := GetCachedFontFamily(AName);
      Result := TGPFont.Create(Family, ASize, AStyle, UnitPixel);
      GFontCache.Add(Key, Result);
    end;
  finally
    LeaveCriticalSection(GFontCacheLock);
  end;
end;

{ THbCustomControl }

constructor THbCustomControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FLife.ResetCreated;
  DoubleBuffered := True;
  ControlStyle := ControlStyle + [csCaptureMouse, csOpaque] - [csParentBackground];
  FIsHovered := False;
  FIsPressed := False;
  FHasFocus := False;
  FTouchpoint := nil;

  try
    BindToken;
    BindState;
  except
    on E: Exception do
    begin
      HandleLifecycleError('Create/Binding', E);
      raise;
    end;
  end;

  THbTheme.AddListener(OnThemeChangedNotification);
end;

function THbCustomControl.GetLifecyclePhase: THbLifecyclePhase;
begin
  Result := FLife.Phase;
end;

procedure THbCustomControl.SetLifecyclePhase(Value: THbLifecyclePhase);
begin
  FLife.Phase := Value;
end;

function THbCustomControl.GetTouchpointId: string;
begin
  Result := FLife.TouchpointId;
end;

procedure THbCustomControl.SetTouchpointId(const Value: string);
begin
  FLife.TouchpointId := Value;
end;

function THbCustomControl.GetSurfaceId: string;
begin
  Result := FLife.SurfaceId;
end;

procedure THbCustomControl.SetSurfaceId(const Value: string);
begin
  FLife.SurfaceId := Value;
end;

function THbCustomControl.GetTargetState: string;
begin
  Result := FLife.TargetState;
end;

procedure THbCustomControl.SetTargetState(const Value: string);
begin
  FLife.TargetState := Value;
end;

function THbCustomControl.GetIsDisposed: Boolean;
begin
  Result := FLife.IsDisposed;
end;

procedure THbCustomControl.BindToken;
begin
  FLife.BindToken;
end;

procedure THbCustomControl.BindState;
begin
  FLife.BindState;
end;

procedure THbCustomControl.AttachTouchpoint(const ATouchpoint: IHbTouchpoint);
begin
  FTouchpoint := ATouchpoint;
  FLife.AttachTouchpoint(ATouchpoint, FLife.SurfaceId);
end;

procedure THbCustomControl.Render;
begin
  // Base vector render pipeline hook
end;

procedure THbCustomControl.EmitTelemetry;
begin
  FLife.EmitTelemetry(FTouchpoint, 'Render');
end;

procedure THbCustomControl.HandleLifecycleError(const AStep: string; AException: Exception);
begin
  try
    if Assigned(FOnLifecycleError) then
      FOnLifecycleError(Self, AStep, AException);
  finally
    DoDispose;
  end;
end;

procedure THbCustomControl.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.Style := Params.Style or WS_CLIPCHILDREN or WS_CLIPSIBLINGS;
  Params.WindowClass.Style := Params.WindowClass.Style and not (CS_HREDRAW or CS_VREDRAW);
end;

procedure THbCustomControl.Paint;
begin
  FLife.AssertPaintAllowed(ClassName);
  Render;
end;

procedure THbCustomControl.WMPaint(var Message: TWMPaint);
begin
  FLife.AssertPaintAllowed(ClassName);

  try
    inherited;
    EmitTelemetry;
    FLife.MarkRendered;
  except
    on E: Exception do
      HandleLifecycleError('Paint/Render', E);
  end;
end;

procedure THbCustomControl.DoDispose;
begin
  if FLife.IsDisposed then
    Exit;
  FLife.Dispose;
  THbTheme.RemoveListener(OnThemeChangedNotification);
  FTouchpoint := nil;
end;

destructor THbCustomControl.Destroy;
begin
  DoDispose;
  inherited Destroy;
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
      if CanFocus then SetFocus;
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

type
  TControlCracker = class(TControl);

function THbCustomControl.GetContainerBgColor: TAlphaColor;
var
  P: TControl;
  Provider: IHbSurfaceProvider;
  RGBVal: Longint;
begin
  P := Parent;
  while P <> nil do
  begin
    if P is THbCustomControl then
      Exit(THbCustomControl(P).GetSurfaceColor);

    if Supports(P, IHbSurfaceProvider, Provider) then
      Exit(Provider.GetSurfaceColor);

    if (P is TWinControl) and (TControlCracker(P).Color <> clBtnFace) and (TControlCracker(P).Color <> clDefault) then
    begin
      RGBVal := ColorToRGB(TControlCracker(P).Color);
      Exit((ARGB(255) shl 24) or
           (ARGB(GetRValue(RGBVal)) shl 16) or
           (ARGB(GetGValue(RGBVal)) shl 8) or
           ARGB(GetBValue(RGBVal)));
    end;

    P := P.Parent;
  end;

  Result := GetTokens.Surface;
end;

function THbCustomControl.GetSurfaceColor: TAlphaColor;
begin
  Result := GetContainerBgColor;
end;

procedure THbCustomControl.EraseBackground(AGraphics: TGPGraphics);
begin
  // 动态解析父级容器（如 THbCard / 祖先表面）的实际 Token 底色，
  // 确保 Pill 按钮与圆角控件外侧完美无缝融入父容器，杜绝矩形底色露边
  Canvas.Brush.Color := AlphaColorToColor(GetContainerBgColor);
  Canvas.FillRect(ClientRect);
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
  RingPen := TGPPen.Create(ColorToARGB(Tokens.FocusRing), 1.5);
  try
    RingRect := ARect;
    // 严格限制在控件自身可见矩形内（缩进 1px），防止超出边界被 Windows 窗口矩形硬切成尖锐矩形边框
    if (RingRect.Width > 4.0) and (RingRect.Height > 4.0) then
    begin
      RingRect.X := RingRect.X + 1.0;
      RingRect.Y := RingRect.Y + 1.0;
      RingRect.Width := RingRect.Width - 2.0;
      RingRect.Height := RingRect.Height - 2.0;
    end;
    Path := CreateRoundRectPath(RingRect, Max(1.0, ARadius - 1.0));
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

procedure THbButton.Click;
var
  Ev: TTouchEvidence;
begin
  inherited Click;
  if FTouchpoint <> nil then
  begin
    Ev := FTouchpoint.EmitEvidence;
    if Ev.TouchpointId = '' then
      Ev.TouchpointId := FTouchpoint.GetID;
    if (Ev.SurfaceId = '') and (SurfaceId <> '') then
      Ev.SurfaceId := SurfaceId;
    if Ev.ActionType = '' then
      Ev.ActionType := 'Click';
    if Ev.TimestampUtc <= 0 then
      Ev.TimestampUtc := DateTimeToUnix(TTimeZone.Local.ToUniversalTime(Now), False) * 1000;
    Ev.Success := True;
    Ev.SupportDeflected := True;
    THbTouchpointEngine.Instance.EmitEvidence(Ev);
  end
  else if TouchpointId <> '' then
  begin
    FillChar(Ev, SizeOf(Ev), 0);
    Ev.TouchpointId := TouchpointId;
    Ev.SurfaceId := SurfaceId;
    Ev.ActionType := 'Click';
    Ev.TimestampUtc := DateTimeToUnix(TTimeZone.Local.ToUniversalTime(Now), False) * 1000;
    Ev.Success := True;
    THbTouchpointEngine.Instance.EmitEvidence(Ev);
  end;
end;

procedure THbButton.Paint;
var
  Tokens: THbTokens;
  RadiusVal: Integer;
  BgColor, TextColor, BorderColor: TAlphaColor;
  FontSize: Single;
  R: TRect;
  RadiusPx: Single;
  DC: HDC;
  ParentBg: TAlphaColor;
begin
  inherited Paint;
  Tokens := GetTokens;

  if FPill then
    RadiusPx := Height * 0.5
  else
    RadiusPx := ScaleDIP(Tokens.RadiusM);
  RadiusVal := Round(RadiusPx);

  // Determine colors by Kind & State
  BgColor := Tokens.Primary;
  TextColor := Tokens.OnPrimary;
  BorderColor := TAlphaColors.Null;
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
      case CurrentState of
        csNormal:   BgColor := Tokens.Danger;
        csHover:    BgColor := BlendAlphaColor(Tokens.Danger, $FF000000, 0.15);
        csPressed:  BgColor := BlendAlphaColor(Tokens.Danger, $FF000000, 0.30);
        csDisabled: BgColor := Tokens.Danger;
      end;
      TextColor := Tokens.OnPrimary;
    end;
  end;

  DC := Canvas.Handle;
  ParentBg := GetContainerBgColor;

  // 1. Fill background with parent container color using fast DC_BRUSH
  SelectObject(DC, GetStockObject(DC_BRUSH));
  SetDCBrushColor(DC, ColorToRGB(AlphaColorToColor(ParentBg)));
  R := ClientRect;
  Winapi.Windows.FillRect(DC, R, GetStockObject(DC_BRUSH));

  // 2. Draw Button Pill / Rounded Rect
  if BgColor <> TAlphaColors.Null then
  begin
    SelectObject(DC, GetStockObject(DC_BRUSH));
    SetDCBrushColor(DC, ColorToRGB(AlphaColorToColor(BgColor)));
  end
  else
    SelectObject(DC, GetStockObject(NULL_BRUSH));

  if BorderColor <> TAlphaColors.Null then
  begin
    SelectObject(DC, GetStockObject(DC_PEN));
    SetDCPenColor(DC, ColorToRGB(AlphaColorToColor(BorderColor)));
  end
  else
    SelectObject(DC, GetStockObject(NULL_PEN));

  if (BgColor <> TAlphaColors.Null) or (BorderColor <> TAlphaColors.Null) then
  begin
    Winapi.Windows.RoundRect(DC, 0, 0, Width, Height, RadiusVal * 2, RadiusVal * 2);
  end;

  // 3. Draw Focus Ring if needed
  if FHasFocus and (CurrentState <> csDisabled) then
  begin
    SelectObject(DC, GetStockObject(NULL_BRUSH));
    SelectObject(DC, GetStockObject(DC_PEN));
    SetDCPenColor(DC, ColorToRGB(AlphaColorToColor(Tokens.FocusRing)));
    Winapi.Windows.RoundRect(DC, 1, 1, Width - 1, Height - 1, RadiusVal * 2, RadiusVal * 2);
  end;

  // 4. Draw Text
  case FSize of
    bsS: FontSize := Tokens.SizeS;
    bsM: FontSize := Tokens.SizeM;
    bsL: FontSize := Tokens.SizeL;
  else
    FontSize := Tokens.SizeM;
  end;

  Canvas.Font.Name := Tokens.FontFamily;
  Canvas.Font.Height := -Round(ScaleDIP(FontSize));
  Canvas.Font.Style := [fsBold];
  Canvas.Font.Color := AlphaColorToColor(TextColor);
  SetBkMode(DC, TRANSPARENT);
  DrawTextW(DC, PWideChar(FCaption), -1, R, DT_CENTER or DT_VCENTER or DT_SINGLELINE);
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
      if (FHoverPart = 1) or (FPressPart = 1) then
      begin
        var LeftAlpha: Byte := 160;
        if (FHoverPart = 1) and (FPressPart = 1) then
          LeftAlpha := 255;
        LeftBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.SuccessSoft, LeftAlpha));
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

function THbChip.GetCloseRect: TGPRectF;
var
  Sz: Single;
begin
  Sz := ScaleDIP(14.0);
  Result := MakeRect(Width - ScaleDIP(18.0), (Height - Sz) * 0.5, Sz, Sz);
end;

procedure THbChip.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  R: TGPRectF;
  NewHover: Boolean;
begin
  inherited;
  if FClosable then
  begin
    R := GetCloseRect;
    NewHover := (X >= R.X) and (X <= R.X + R.Width) and (Y >= R.Y) and (Y <= R.Y + R.Height);
    if FCloseHovered <> NewHover then
    begin
      FCloseHovered := NewHover;
      Invalidate;
    end;
  end;
end;

procedure THbChip.CMMouseLeave(var Message: TMessage);
begin
  inherited;
  if FCloseHovered then
  begin
    FCloseHovered := False;
    Invalidate;
  end;
end;

procedure THbChip.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  R: TGPRectF;
begin
  inherited;
  if (Button = mbLeft) and FClosable then
  begin
    R := GetCloseRect;
    FClosePressed := (X >= R.X) and (X <= R.X + R.Width) and (Y >= R.Y) and (Y <= R.Y + R.Height);
  end
  else
    FClosePressed := False;
end;

procedure THbChip.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  R: TGPRectF;
  IsHit: Boolean;
begin
  inherited;
  if (Button = mbLeft) and FClosePressed and FClosable then
  begin
    R := GetCloseRect;
    IsHit := (X >= R.X) and (X <= R.X + R.Width) and (Y >= R.Y) and (Y <= R.Y + R.Height);
    if IsHit and Assigned(FOnClose) then
      FOnClose(Self);
  end;
  FClosePressed := False;
end;

procedure THbChip.Paint;
var
  Graphics: TGPGraphics;
  Tokens: THbTokens;
  RectF, TextRect, CloseR: TGPRectF;
  Radius: Single;
  Path: TGPGraphicsPath;
  Brush, CloseBgBrush: TGPSolidBrush;
  ClosePen: TGPPen;
  Font: TGPFont;
  FontFamily: TGPFontFamily;
  StrFmt: TGPStringFormat;
  TextBrush: TGPSolidBrush;
  BgColor, TextColor: TAlphaColor;
  Pad: Single;
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
          StrFmt.SetLineAlignment(StringAlignmentCenter);

          if FClosable then
          begin
            StrFmt.SetAlignment(StringAlignmentNear);
            TextRect := MakeRect(ScaleDIP(Tokens.SpaceS), 0.0, Width - ScaleDIP(24.0), Height);
          end
          else
          begin
            StrFmt.SetAlignment(StringAlignmentCenter);
            TextRect := RectF;
          end;

          TextBrush := TGPSolidBrush.Create(ColorToARGB(TextColor));
          try Graphics.DrawString(FCaption, -1, Font, TextRect, StrFmt, TextBrush); finally TextBrush.Free; end;

          if FClosable then
          begin
            CloseR := GetCloseRect;
            if FCloseHovered or FClosePressed then
            begin
              CloseBgBrush := TGPSolidBrush.Create(ColorToARGB(TextColor, 40));
              try Graphics.FillEllipse(CloseBgBrush, CloseR); finally CloseBgBrush.Free; end;
            end;
            ClosePen := TGPPen.Create(ColorToARGB(TextColor), 1.2);
            try
              Pad := ScaleDIP(3.5);
              Graphics.DrawLine(ClosePen, CloseR.X + Pad, CloseR.Y + Pad, CloseR.X + CloseR.Width - Pad, CloseR.Y + CloseR.Height - Pad);
              Graphics.DrawLine(ClosePen, CloseR.X + CloseR.Width - Pad, CloseR.Y + Pad, CloseR.X + Pad, CloseR.Y + CloseR.Height - Pad);
            finally
              ClosePen.Free;
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
begin
  Result := GetHbSeedColor(ASeed, GetTokens);
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
  FAnimTimer.Interval := 60;
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
  FAnimAngle := FAnimAngle + 16.0;
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
    var MinDim := Min(Width, Height);
    if Thick >= MinDim * 0.5 then
      Thick := MinDim * 0.25;
    if (Width - Thick - 2.0 <= 0) or (Height - Thick - 2.0 <= 0) then
      Exit;
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
  RectF, TextRect, IconRect: TGPRectF;
  Path: TGPGraphicsPath;
  Brush, IconBgBrush: TGPSolidBrush;
  Pen, IconPen: TGPPen;
  Font: TGPFont;
  FontFamily: TGPFontFamily;
  StrFmt: TGPStringFormat;
  TextBrush: TGPSolidBrush;
  BgColor, BorderColor, TextColor: TAlphaColor;
  IconSz, IconX, IconY: Single;
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
      end;
      tkDanger:
      begin
        BgColor := Tokens.Soft;
        BorderColor := Tokens.Danger;
        TextColor := Tokens.Danger;
      end;
      tkWarning:
      begin
        BgColor := Tokens.Soft;
        BorderColor := Tokens.Warning;
        TextColor := Tokens.Warning;
      end;
      else
      begin
        BgColor := Tokens.Soft;
        BorderColor := Tokens.Info;
        TextColor := Tokens.Info;
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

    // Vector Icon Circle + Shape
    IconSz := ScaleDIP(16.0);
    IconX := RectF.X + ScaleDIP(Tokens.SpaceS);
    IconY := (Height - IconSz) * 0.5;
    IconRect := MakeRect(IconX, IconY, IconSz, IconSz);

    IconBgBrush := TGPSolidBrush.Create(ColorToARGB(BorderColor, 35));
    try
      Graphics.FillEllipse(IconBgBrush, IconRect);
    finally
      IconBgBrush.Free;
    end;

    IconPen := TGPPen.Create(ColorToARGB(BorderColor), 1.4);
    try
      case FKind of
        tkSuccess:
        begin
          Graphics.DrawLine(IconPen, IconX + IconSz * 0.25, IconY + IconSz * 0.52, IconX + IconSz * 0.44, IconY + IconSz * 0.72);
          Graphics.DrawLine(IconPen, IconX + IconSz * 0.44, IconY + IconSz * 0.72, IconX + IconSz * 0.76, IconY + IconSz * 0.30);
        end;
        tkDanger:
        begin
          Graphics.DrawLine(IconPen, IconX + IconSz * 0.30, IconY + IconSz * 0.30, IconX + IconSz * 0.70, IconY + IconSz * 0.70);
          Graphics.DrawLine(IconPen, IconX + IconSz * 0.70, IconY + IconSz * 0.30, IconX + IconSz * 0.30, IconY + IconSz * 0.70);
        end;
        tkWarning:
        begin
          Graphics.DrawLine(IconPen, IconX + IconSz * 0.50, IconY + IconSz * 0.25, IconX + IconSz * 0.50, IconY + IconSz * 0.60);
          Graphics.DrawLine(IconPen, IconX + IconSz * 0.50, IconY + IconSz * 0.75, IconX + IconSz * 0.50, IconY + IconSz * 0.78);
        end;
        else
        begin
          Graphics.DrawLine(IconPen, IconX + IconSz * 0.50, IconY + IconSz * 0.25, IconX + IconSz * 0.50, IconY + IconSz * 0.28);
          Graphics.DrawLine(IconPen, IconX + IconSz * 0.50, IconY + IconSz * 0.45, IconX + IconSz * 0.50, IconY + IconSz * 0.75);
        end;
      end;
    finally
      IconPen.Free;
    end;

    FontFamily := TGPFontFamily.Create(Tokens.FontFamily);
    try
      Font := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeS), FontStyleBold, UnitPixel);
      try
        StrFmt := TGPStringFormat.Create;
        try
          StrFmt.SetAlignment(StringAlignmentNear);
          StrFmt.SetLineAlignment(StringAlignmentCenter);

          TextRect := MakeRect(IconX + IconSz + ScaleDIP(Tokens.SpaceS), 0.0, Width - (IconX + IconSz + ScaleDIP(Tokens.SpaceS * 2)), Height);

          TextBrush := TGPSolidBrush.Create(ColorToARGB(TextColor));
          try
            Graphics.DrawString(FMessageText, -1, Font, TextRect, StrFmt, TextBrush);
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
  FAnimTimer.Interval := 60;
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
  FAnimOffset := FAnimOffset + 0.08;
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

function THbSectionHeader.GetTrailingRect: TGPRectF;
var
  Tokens: THbTokens;
  Graphics: TGPGraphics;
  FontFamily: TGPFontFamily;
  Font: TGPFont;
  LayoutRect, BoundingBox: TGPRectF;
  StrFmt: TGPStringFormat;
begin
  if FTrailingLink = '' then
    Exit(MakeRect(0.0, 0.0, 0.0, 0.0));
  Tokens := GetTokens;
  Graphics := TGPGraphics.Create(Canvas.Handle);
  try
    FontFamily := TGPFontFamily.Create(Tokens.FontFamily);
    try
      Font := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeM), FontStyleBold, UnitPixel);
      try
        StrFmt := TGPStringFormat.Create;
        try
          LayoutRect := MakeRect(0.0, 0.0, Single(Width), Single(Height));
          Graphics.MeasureString(FTrailingLink, Length(FTrailingLink), Font, LayoutRect, StrFmt, BoundingBox);
          var LinkW := BoundingBox.Width + ScaleDIP(Tokens.SpaceS);
          Result := MakeRect(Width - LinkW - ScaleDIP(Tokens.SpaceXS), 0.0, LinkW, Single(Height));
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

procedure THbSectionHeader.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  R: TGPRectF;
begin
  inherited;
  if (Button = mbLeft) and (FTrailingLink <> '') then
  begin
    R := GetTrailingRect;
    FTrailingPressed := (X >= R.X) and (X <= R.X + R.Width) and (Y >= R.Y) and (Y <= R.Y + R.Height);
  end
  else
    FTrailingPressed := False;
end;

procedure THbSectionHeader.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  R: TGPRectF;
  IsHit: Boolean;
begin
  inherited;
  if (Button = mbLeft) and FTrailingPressed and (FTrailingLink <> '') then
  begin
    R := GetTrailingRect;
    IsHit := (X >= R.X) and (X <= R.X + R.Width) and (Y >= R.Y) and (Y <= R.Y + R.Height);
    if IsHit and Assigned(FOnTrailingClick) then
      FOnTrailingClick(Self);
  end;
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
  TrailingR: TGPRectF;
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
            Graphics.DrawString(TitleText, -1, Font, MakeRect(0.0, 0.0, Width * 0.6, Height), StrFmt, TextBrush);
          finally
            TextBrush.Free;
          end;

          // Trailing Link
          if FTrailingLink <> '' then
          begin
            TrailingR := GetTrailingRect;
            TextBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.Primary));
            try
              StrFmt.SetAlignment(StringAlignmentFar);
              Graphics.DrawString(FTrailingLink, -1, Font, TrailingR, StrFmt, TextBrush);
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

initialization
  InitializeCriticalSection(GFontCacheLock);
  GFontFamilyCache := TDictionary<string, TGPFontFamily>.Create;
  GFontCache := TDictionary<string, TGPFont>.Create;
  GStringFormatCenter := TGPStringFormat.Create;
  GStringFormatCenter.SetAlignment(StringAlignmentCenter);
  GStringFormatCenter.SetLineAlignment(StringAlignmentCenter);

finalization
  GStringFormatCenter.Free;
  for var F in GFontCache.Values do
    F.Free;
  GFontCache.Free;
  for var Family in GFontFamilyCache.Values do
    Family.Free;
  GFontFamilyCache.Free;
  DeleteCriticalSection(GFontCacheLock);

end.
