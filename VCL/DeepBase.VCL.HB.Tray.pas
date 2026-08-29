{ ============================================================================
  DeepBase.VCL.HB.Tray - Modern Token-Driven Tray Icon & Popup Menu for VCL

  Version: 1.0 (Delphi 13.1 on Win64)
  Description: Modern HB-themed Tray Icon & Popup Menu for VCL:
               - THbTrayIcon: Tray icon with dynamic badge count & breathing dot
               - THbTrayMenu: Multi-zone token-driven popup menu with smart
                 multi-monitor positioning, no-focus-stealing, and dark mode support.
  ============================================================================ }

unit DeepBase.VCL.HB.Tray;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  Winapi.ShellAPI,
  Winapi.GDIPOBJ,
  Winapi.GDIPAPI,
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
  System.Generics.Collections,
  Vcl.Controls,
  Vcl.Graphics,
  Vcl.Forms,
  Vcl.ExtCtrls,
  Vcl.Menus,
  DeepBase.HB.Core,
  DeepBase.HB.Tray.Types,
  DeepBase.VCL.HB.Theme;

type
  THbTrayMenu = class;

  /// <summary>
  /// Single item in the HB Tray Menu.
  /// </summary>
  THbTrayMenuItem = class
  private
    FId: string;
    FCaption: string;
    FShortcutText: string;
    FKind: THbTrayItemKind;
    FIsDefault: Boolean;
    FIsChecked: Boolean;
    FIsDestructive: Boolean;
    FIsEnabled: Boolean;
    FBadgeText: string;
    FBadgeTone: THbBadgeTone;
    FTag: NativeInt;
    FOnClick: TNotifyEvent;
  public
    constructor Create;
    property Id: string read FId write FId;
    property Caption: string read FCaption write FCaption;
    property ShortcutText: string read FShortcutText write FShortcutText;
    property Kind: THbTrayItemKind read FKind write FKind;
    property IsDefault: Boolean read FIsDefault write FIsDefault;
    property IsChecked: Boolean read FIsChecked write FIsChecked;
    property IsDestructive: Boolean read FIsDestructive write FIsDestructive;
    property IsEnabled: Boolean read FIsEnabled write FIsEnabled;
    property BadgeText: string read FBadgeText write FBadgeText;
    property BadgeTone: THbBadgeTone read FBadgeTone write FBadgeTone;
    property Tag: NativeInt read FTag write FTag;
    property OnClick: TNotifyEvent read FOnClick write FOnClick;
  end;

  /// <summary>
  /// Popup floating menu form for modern HB tray menu.
  /// </summary>
  THbTrayMenuForm = class(TCustomForm)
  private
    FMenu: THbTrayMenu;
    FHoverIndex: Integer;
    FItemRects: TList<TRect>;
    procedure WMNCHitTest(var Msg: TWMNCHitTest); message WM_NCHITTEST;
    procedure WMActivateApp(var Msg: TWMActivateApp); message WM_ACTIVATEAPP;
    procedure WMKillFocus(var Msg: TWMKillFocus); message WM_KILLFOCUS;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure Paint; override;
  public
    constructor CreateNew(AOwner: TComponent; Dummy: Integer = 0); override;
    destructor Destroy; override;
    procedure PopupAt(X, Y: Integer);
    property Menu: THbTrayMenu read FMenu write FMenu;
  end;

  /// <summary>
  /// THbTrayMenu: Multi-zone token-driven popup menu container.
  /// </summary>
  THbTrayMenu = class(TComponent)
  private
    FHeader: THbTrayHeaderData;
    FItems: TObjectList<THbTrayMenuItem>;
    FForm: THbTrayMenuForm;
    procedure EnsureForm;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetHeader(const ATitle: string; const ASubtitle: string = ''; const AVersion: string = ''; ATone: THbBadgeTone = btSuccess; AHasDot: Boolean = True);
    function AddItem(const ACaption: string; AOnClick: TNotifyEvent = nil; const AShortcut: string = ''; AIsDefault: Boolean = False): THbTrayMenuItem;
    function AddCheckItem(const ACaption: string; AOnClick: TNotifyEvent; AIsChecked: Boolean = False): THbTrayMenuItem;
    function AddSeparator: THbTrayMenuItem;
    function AddDestructiveItem(const ACaption: string; AOnClick: TNotifyEvent): THbTrayMenuItem;
    procedure Clear;
    procedure Popup(X, Y: Integer);
    procedure PopupAtTray;
    property Header: THbTrayHeaderData read FHeader write FHeader;
    property Items: TObjectList<THbTrayMenuItem> read FItems;
  end;

  /// <summary>
  /// THbTrayIcon: Modern tray icon with dynamic badges & token menu integration.
  /// </summary>
  THbTrayIcon = class(TComponent)
  private
    FTrayIcon: TTrayIcon;
    FMenu: THbTrayMenu;
    FBadgeCount: Integer;
    FBreathingDot: Boolean;
    FBaseToolTip: string;
    FOnDblClick: TNotifyEvent;
    procedure SetBadgeCount(Value: Integer);
    procedure SetBreathingDot(Value: Boolean);
    function GetActive: Boolean;
    procedure SetActive(Value: Boolean);
    function GetIcon: TIcon;
    procedure SetIcon(Value: TIcon);
    function GetToolTip: string;
    procedure SetToolTip(const Value: string);
    procedure OnTrayMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure OnTrayDblClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ShowBalloonHint(const ATitle, AMessage: string; AIcon: TBalloonFlags = bfInfo; ATimeoutMs: Integer = 3000);
  published
    property Active: Boolean read GetActive write SetActive default False;
    property BadgeCount: Integer read FBadgeCount write SetBadgeCount default 0;
    property BreathingDot: Boolean read FBreathingDot write SetBreathingDot default False;
    property Icon: TIcon read GetIcon write SetIcon;
    property Menu: THbTrayMenu read FMenu;
    property ToolTip: string read GetToolTip write SetToolTip;
    property OnDblClick: TNotifyEvent read FOnDblClick write FOnDblClick;
  end;

implementation

function ColorToARGB(AColor: TAlphaColor; AAlphaOverride: Byte = 0): ARGB;
var
  A, R, G, B: Byte;
begin
  A := TAlphaColorRec(AColor).A;
  R := TAlphaColorRec(AColor).R;
  G := TAlphaColorRec(AColor).G;
  B := TAlphaColorRec(AColor).B;
  if AAlphaOverride > 0 then
    A := AAlphaOverride;
  Result := (ARGB(A) shl 24) or (ARGB(R) shl 16) or (ARGB(G) shl 8) or ARGB(B);
end;

function ScaleDIP(APixels: Single; APPI: Integer = 0): Single;
begin
  if APPI <= 0 then
    APPI := Screen.PixelsPerInch;
  Result := APixels * (APPI / 96.0);
end;

function ScalePixels(APixels: Single; APPI: Integer = 0): Integer;
begin
  Result := Round(ScaleDIP(APixels, APPI));
end;

{ THbTrayMenuItem }

constructor THbTrayMenuItem.Create;
begin
  inherited Create;
  FKind := tikItem;
  FIsDefault := False;
  FIsChecked := False;
  FIsDestructive := False;
  FIsEnabled := True;
  FBadgeTone := btBrand;
  FTag := 0;
end;

{ THbTrayMenuForm }

constructor THbTrayMenuForm.CreateNew(AOwner: TComponent; Dummy: Integer);
begin
  inherited CreateNew(AOwner, Dummy);
  BorderStyle := bsNone;
  Position := poDesigned;
  Color := clBlack;
  FHoverIndex := -1;
  FItemRects := TList<TRect>.Create;
  DoubleBuffered := True;
end;

destructor THbTrayMenuForm.Destroy;
begin
  FItemRects.Free;
  inherited;
end;

procedure THbTrayMenuForm.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.Style := WS_POPUP;
  Params.ExStyle := Params.ExStyle or WS_EX_TOOLWINDOW or WS_EX_TOPMOST;
end;

procedure THbTrayMenuForm.WMNCHitTest(var Msg: TWMNCHitTest);
begin
  Msg.Result := HTCLIENT;
end;

procedure THbTrayMenuForm.WMActivateApp(var Msg: TWMActivateApp);
begin
  inherited;
  if not Msg.Active then
    Hide;
end;

procedure THbTrayMenuForm.WMKillFocus(var Msg: TWMKillFocus);
begin
  inherited;
  Hide;
end;

procedure THbTrayMenuForm.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
  NewHover: Integer;
begin
  inherited;
  NewHover := -1;
  for I := 0 to FItemRects.Count - 1 do
  begin
    if PtInRect(FItemRects[I], Point(X, Y)) then
    begin
      NewHover := I;
      Break;
    end;
  end;

  if FHoverIndex <> NewHover then
  begin
    FHoverIndex := NewHover;
    Invalidate;
  end;
end;

procedure THbTrayMenuForm.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
  Item: THbTrayMenuItem;
begin
  inherited;
  if Button = mbLeft then
  begin
    for I := 0 to FItemRects.Count - 1 do
    begin
      if PtInRect(FItemRects[I], Point(X, Y)) then
      begin
        if Assigned(FMenu) and (I < FMenu.Items.Count) then
        begin
          Item := FMenu.Items[I];
          if Item.IsEnabled and (Item.Kind <> tikSeparator) then
          begin
            if Item.Kind = tikCheck then
              Item.IsChecked := not Item.IsChecked;

            Hide;
            if Assigned(Item.OnClick) then
              Item.OnClick(Item);
          end;
        end;
        Break;
      end;
    end;
  end;
end;

procedure THbTrayMenuForm.PopupAt(X, Y: Integer);
var
  Mon: TMonitor;
  MonRect: TRect;
  CalcH, CalcW, I: Integer;
  Item: THbTrayMenuItem;
  LPPI: Integer;
begin
  if not Assigned(FMenu) then
    Exit;

  // Multi-monitor coordinate detection & clamping
  Mon := Screen.MonitorFromPoint(Point(X, Y));
  if Assigned(Mon) then
  begin
    MonRect := Mon.WorkareaRect;
    LPPI := Mon.PixelsPerInch;
  end
  else
  begin
    MonRect := Screen.WorkAreaRect;
    LPPI := Screen.PixelsPerInch;
  end;

  CalcW := ScalePixels(280, LPPI);
  CalcH := ScalePixels(16, LPPI); // Top/Bottom padding

  if FMenu.Header.Visible then
    Inc(CalcH, ScalePixels(60, LPPI));

  for I := 0 to FMenu.Items.Count - 1 do
  begin
    Item := FMenu.Items[I];
    if Item.Kind = tikSeparator then
      Inc(CalcH, ScalePixels(9, LPPI))
    else
      Inc(CalcH, ScalePixels(32, LPPI));
  end;

  Width := CalcW;
  Height := CalcH;

  // Clamping X
  if X + Width > MonRect.Right - ScalePixels(8, LPPI) then
    X := MonRect.Right - Width - ScalePixels(8, LPPI);
  if X < MonRect.Left + ScalePixels(8, LPPI) then
    X := MonRect.Left + ScalePixels(8, LPPI);

  // Clamping Y (upwards from bottom taskbar)
  if Y + Height > MonRect.Bottom - ScalePixels(8, LPPI) then
    Y := Y - Height - ScalePixels(8, LPPI);
  if Y < MonRect.Top + ScalePixels(8, LPPI) then
    Y := MonRect.Top + ScalePixels(8, LPPI);

  Left := X;
  Top := Y;
  FHoverIndex := -1;
  Show;
  SetWindowPos(Handle, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_SHOWWINDOW);
end;

procedure THbTrayMenuForm.Paint;
var
  Graphics: TGPGraphics;
  Tokens: THbTokens;
  BrushBg, BrushInk, BrushMuted, BrushHover, BrushDestructive: TGPSolidBrush;
  PenBorder: TGPPen;
  FontFamily: TGPFontFamily;
  FontNormal, FontBold, FontSmall: TGPFont;
  StrFmtNear, StrFmtFar, StrFmtCenter: TGPStringFormat;
  CurY: Single;
  I: Integer;
  Item: THbTrayMenuItem;
  R, HeaderRect, ItemRect: TGPRectF;
  NativeRect: TRect;
  LPPI: Integer;
begin
  Tokens := THbTheme.Tokens;
  Graphics := TGPGraphics.Create(Canvas.Handle);
  FItemRects.Clear;
  LPPI := CurrentPPI;
  if LPPI <= 0 then
    LPPI := Screen.PixelsPerInch;

  try
    Graphics.SetSmoothingMode(SmoothingModeAntiAlias);
    Graphics.SetTextRenderingHint(TextRenderingHintClearTypeGridFit);

    R := MakeRect(0.0, 0.0, Single(Width), Single(Height));

    // Outer surface
    BrushBg := TGPSolidBrush.Create(ColorToARGB(Tokens.Surface));
    PenBorder := TGPPen.Create(ColorToARGB(Tokens.Border), 1.0);
    try
      Graphics.FillRectangle(BrushBg, R);
      Graphics.DrawRectangle(PenBorder, 0.5, 0.5, Single(Width) - 1.0, Single(Height) - 1.0);
    finally
      PenBorder.Free;
      BrushBg.Free;
    end;

    FontFamily := TGPFontFamily.Create(Tokens.FontFamily);
    try
      FontNormal := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeS, LPPI), FontStyleRegular, UnitPixel);
      FontBold := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeS, LPPI), FontStyleBold, UnitPixel);
      FontSmall := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeXS, LPPI), FontStyleRegular, UnitPixel);
      BrushInk := TGPSolidBrush.Create(ColorToARGB(Tokens.Ink));
      BrushMuted := TGPSolidBrush.Create(ColorToARGB(Tokens.InkMuted));
      BrushHover := TGPSolidBrush.Create(ColorToARGB(Tokens.SurfaceAlt));
      BrushDestructive := TGPSolidBrush.Create(ColorToARGB(Tokens.Danger, 30));
      StrFmtNear := TGPStringFormat.Create;
      StrFmtFar := TGPStringFormat.Create;
      StrFmtCenter := TGPStringFormat.Create;
      try
        StrFmtNear.SetAlignment(StringAlignmentNear);
        StrFmtNear.SetLineAlignment(StringAlignmentCenter);
        StrFmtFar.SetAlignment(StringAlignmentFar);
        StrFmtFar.SetLineAlignment(StringAlignmentCenter);
        StrFmtCenter.SetAlignment(StringAlignmentCenter);
        StrFmtCenter.SetLineAlignment(StringAlignmentCenter);

        CurY := ScaleDIP(8.0, LPPI);

        // 1. Header Zone
        if Assigned(FMenu) and FMenu.Header.Visible then
        begin
          HeaderRect := MakeRect(ScaleDIP(12.0, LPPI), CurY, Single(Width) - ScaleDIP(24.0, LPPI), ScaleDIP(48.0, LPPI));
          var BrushHdrBg := TGPSolidBrush.Create(ColorToARGB(Tokens.Sunken));
          try Graphics.FillRectangle(BrushHdrBg, HeaderRect); finally BrushHdrBg.Free; end;

          // Header Title
          var HdrTitleRect := MakeRect(ScaleDIP(24.0, LPPI), CurY + ScaleDIP(6.0, LPPI), Single(Width) - ScaleDIP(48.0, LPPI), ScaleDIP(18.0, LPPI));
          Graphics.DrawString(FMenu.Header.Title, Length(FMenu.Header.Title), FontBold, HdrTitleRect, StrFmtNear, BrushInk);

          // Subtitle / Status
          var HdrSubRect := MakeRect(ScaleDIP(24.0, LPPI), CurY + ScaleDIP(26.0, LPPI), Single(Width) - ScaleDIP(48.0, LPPI), ScaleDIP(16.0, LPPI));
          Graphics.DrawString(FMenu.Header.Subtitle, Length(FMenu.Header.Subtitle), FontSmall, HdrSubRect, StrFmtNear, BrushMuted);

          // Breathing dot
          if FMenu.Header.HasBreathingDot then
          begin
            var DotBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.Success));
            try Graphics.FillEllipse(DotBrush, ScaleDIP(14.0, LPPI), CurY + ScaleDIP(11.0, LPPI), ScaleDIP(6.0, LPPI), ScaleDIP(6.0, LPPI)); finally DotBrush.Free; end;
          end;

          CurY := CurY + ScaleDIP(54.0, LPPI);
        end;

        // 2. Menu Items
        if Assigned(FMenu) then
        begin
          for I := 0 to FMenu.Items.Count - 1 do
          begin
            Item := FMenu.Items[I];
            if Item.Kind = tikSeparator then
            begin
              var PenDiv := TGPPen.Create(ColorToARGB(Tokens.Border), 1.0);
              try
                Graphics.DrawLine(PenDiv, ScaleDIP(12.0, LPPI), CurY + ScaleDIP(4.0, LPPI), Single(Width) - ScaleDIP(12.0, LPPI), CurY + ScaleDIP(4.0, LPPI));
              finally
                PenDiv.Free;
              end;
              NativeRect := Rect(ScalePixels(12, LPPI), Trunc(CurY), Width - ScalePixels(12, LPPI), Trunc(CurY + ScaleDIP(9.0, LPPI)));
              FItemRects.Add(NativeRect);
              CurY := CurY + ScaleDIP(9.0, LPPI);
            end
            else
            begin
              ItemRect := MakeRect(ScaleDIP(8.0, LPPI), CurY, Single(Width) - ScaleDIP(16.0, LPPI), ScaleDIP(32.0, LPPI));
              NativeRect := Rect(ScalePixels(8, LPPI), Trunc(CurY), Width - ScalePixels(8, LPPI), Trunc(CurY + ScaleDIP(32.0, LPPI)));
              FItemRects.Add(NativeRect);

              // Hover effect
              if I = FHoverIndex then
              begin
                if Item.IsDestructive then
                  Graphics.FillRectangle(BrushDestructive, ItemRect)
                else
                  Graphics.FillRectangle(BrushHover, ItemRect);
              end;

              // Checkbox indicator
              if Item.Kind = tikCheck then
              begin
                if Item.IsChecked then
                begin
                  var CheckStr: string := #$2713;
                  var CheckRect := MakeRect(ScaleDIP(12.0, LPPI), CurY, ScaleDIP(20.0, LPPI), ScaleDIP(32.0, LPPI));
                  var CheckBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.Primary));
                  try Graphics.DrawString(CheckStr, Length(CheckStr), FontBold, CheckRect, StrFmtCenter, CheckBrush); finally CheckBrush.Free; end;
                end;
              end;

              // Caption
              var CapRect := MakeRect(ScaleDIP(32.0, LPPI), CurY, Single(Width) - ScaleDIP(120.0, LPPI), ScaleDIP(32.0, LPPI));
              var FontToUse := FontNormal;
              if Item.IsDefault then
                FontToUse := FontBold;

              if Item.IsDestructive and (I = FHoverIndex) then
              begin
                var DangerBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.Danger));
                try Graphics.DrawString(Item.Caption, Length(Item.Caption), FontToUse, CapRect, StrFmtNear, DangerBrush); finally DangerBrush.Free; end;
              end
              else
              begin
                Graphics.DrawString(Item.Caption, Length(Item.Caption), FontToUse, CapRect, StrFmtNear, BrushInk);
              end;

              // Shortcut Text
              if Item.ShortcutText <> '' then
              begin
                var ShortRect := MakeRect(Single(Width) - ScaleDIP(100.0, LPPI), CurY, ScaleDIP(86.0, LPPI), ScaleDIP(32.0, LPPI));
                Graphics.DrawString(Item.ShortcutText, Length(Item.ShortcutText), FontSmall, ShortRect, StrFmtFar, BrushMuted);
              end;

              CurY := CurY + ScaleDIP(32.0, LPPI);
            end;
          end;
        end;

      finally
        StrFmtCenter.Free;
        StrFmtFar.Free;
        StrFmtNear.Free;
        BrushDestructive.Free;
        BrushHover.Free;
        BrushMuted.Free;
        BrushInk.Free;
        FontSmall.Free;
        FontBold.Free;
        FontNormal.Free;
      end;
    finally
      FontFamily.Free;
    end;
  finally
    Graphics.Free;
  end;
end;

{ THbTrayMenu }

constructor THbTrayMenu.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FItems := TObjectList<THbTrayMenuItem>.Create(True);
  FHeader.Visible := False;
end;

destructor THbTrayMenu.Destroy;
begin
  FForm.Free;
  FItems.Free;
  inherited;
end;

procedure THbTrayMenu.EnsureForm;
begin
  if not Assigned(FForm) then
  begin
    FForm := THbTrayMenuForm.CreateNew(nil);
    FForm.Menu := Self;
  end;
end;

procedure THbTrayMenu.SetHeader(const ATitle, ASubtitle, AVersion: string; ATone: THbBadgeTone; AHasDot: Boolean);
begin
  FHeader.Title := ATitle;
  FHeader.Subtitle := ASubtitle;
  FHeader.VersionText := AVersion;
  FHeader.Tone := ATone;
  FHeader.HasBreathingDot := AHasDot;
  FHeader.Visible := True;
end;

function THbTrayMenu.AddItem(const ACaption: string; AOnClick: TNotifyEvent; const AShortcut: string; AIsDefault: Boolean): THbTrayMenuItem;
begin
  Result := THbTrayMenuItem.Create;
  Result.Caption := ACaption;
  Result.OnClick := AOnClick;
  Result.ShortcutText := AShortcut;
  Result.IsDefault := AIsDefault;
  FItems.Add(Result);
end;

function THbTrayMenu.AddCheckItem(const ACaption: string; AOnClick: TNotifyEvent; AIsChecked: Boolean): THbTrayMenuItem;
begin
  Result := THbTrayMenuItem.Create;
  Result.Caption := ACaption;
  Result.Kind := tikCheck;
  Result.OnClick := AOnClick;
  Result.IsChecked := AIsChecked;
  FItems.Add(Result);
end;

function THbTrayMenu.AddSeparator: THbTrayMenuItem;
begin
  Result := THbTrayMenuItem.Create;
  Result.Kind := tikSeparator;
  FItems.Add(Result);
end;

function THbTrayMenu.AddDestructiveItem(const ACaption: string; AOnClick: TNotifyEvent): THbTrayMenuItem;
begin
  Result := THbTrayMenuItem.Create;
  Result.Caption := ACaption;
  Result.OnClick := AOnClick;
  Result.IsDestructive := True;
  FItems.Add(Result);
end;

procedure THbTrayMenu.Clear;
begin
  FItems.Clear;
end;

procedure THbTrayMenu.Popup(X, Y: Integer);
begin
  EnsureForm;
  FForm.PopupAt(X, Y);
end;

procedure THbTrayMenu.PopupAtTray;
var
  P: TPoint;
begin
  GetCursorPos(P);
  Popup(P.X, P.Y);
end;

{ THbTrayIcon }

constructor THbTrayIcon.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FTrayIcon := TTrayIcon.Create(Self);
  FTrayIcon.OnMouseUp := OnTrayMouseUp;
  FTrayIcon.OnDblClick := OnTrayDblClick;
  FMenu := THbTrayMenu.Create(Self);
  FBadgeCount := 0;
  FBreathingDot := False;
end;

destructor THbTrayIcon.Destroy;
begin
  FTrayIcon.Free;
  FMenu.Free;
  inherited;
end;

function THbTrayIcon.GetActive: Boolean;
begin
  Result := FTrayIcon.Visible;
end;

procedure THbTrayIcon.SetActive(Value: Boolean);
begin
  FTrayIcon.Visible := Value;
end;

function THbTrayIcon.GetIcon: TIcon;
begin
  Result := FTrayIcon.Icon;
end;

procedure THbTrayIcon.SetIcon(Value: TIcon);
begin
  FTrayIcon.Icon := Value;
end;

function THbTrayIcon.GetToolTip: string;
begin
  Result := FTrayIcon.Hint;
end;

procedure THbTrayIcon.SetToolTip(const Value: string);
begin
  FBaseToolTip := Value;
  if FBadgeCount > 0 then
    FTrayIcon.Hint := Format('%s (%d 条新通知)', [FBaseToolTip, FBadgeCount])
  else
    FTrayIcon.Hint := FBaseToolTip;
end;

procedure THbTrayIcon.SetBadgeCount(Value: Integer);
begin
  if FBadgeCount <> Value then
  begin
    FBadgeCount := Value;
    if FBadgeCount > 0 then
      FTrayIcon.Hint := Format('%s (%d 条新通知)', [FBaseToolTip, FBadgeCount])
    else
      FTrayIcon.Hint := FBaseToolTip;
  end;
end;

procedure THbTrayIcon.SetBreathingDot(Value: Boolean);
begin
  FBreathingDot := Value;
end;

procedure THbTrayIcon.ShowBalloonHint(const ATitle, AMessage: string; AIcon: TBalloonFlags; ATimeoutMs: Integer);
begin
  FTrayIcon.BalloonTitle := ATitle;
  FTrayIcon.BalloonHint := AMessage;
  FTrayIcon.BalloonFlags := AIcon;
  FTrayIcon.BalloonTimeout := ATimeoutMs;
  FTrayIcon.ShowBalloonHint;
end;

procedure THbTrayIcon.OnTrayMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbRight then
  begin
    FMenu.PopupAtTray;
  end;
end;

procedure THbTrayIcon.OnTrayDblClick(Sender: TObject);
begin
  if Assigned(FOnDblClick) then
    FOnDblClick(Self)
  else if Assigned(Application.MainForm) then
  begin
    if Application.MainForm.Visible then
      Application.MainForm.Hide
    else
    begin
      Application.MainForm.Show;
      Application.MainForm.BringToFront;
    end;
  end;
end;

end.
