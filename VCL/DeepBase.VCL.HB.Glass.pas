{ ============================================================================
  DeepBase.VCL.HB.Glass - Windows 11 Fluent Acrylic / Frosted Glass Panel for VCL

  Version: 1.0 (Delphi 13.1 on Win64)
  Description: THbGlassPanel:
               - Fluent translucent acrylic / frosted glass background
               - Soft multi-pass DropShadow elevation
               - Top-lit subtle specular rim highlight
               - Micro-transition animations (FadeIn / FadeOut)
               - Container support (csAcceptsControls) for overlay & popup cards
  ============================================================================ }

unit DeepBase.VCL.HB.Glass;

{$WARN IMPLICIT_STRING_CAST OFF}

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  Winapi.GDIPAPI,
  Winapi.GDIPOBJ,
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
  System.Math,
  Vcl.Controls,
  Vcl.Graphics,
  Vcl.ExtCtrls,
  Vcl.Forms,
  DeepBase.HB.Core,
  DeepBase.VCL.HB.Theme,
  DeepBase.VCL.HB.Controls;

type
  /// <summary>
  /// THbGlassPanel: Translucent frosted glass panel with soft shadow & micro transitions.
  /// </summary>
  THbGlassPanel = class(THbCustomControl)
  private
    FAcrylic: Boolean;
    FDropShadow: Boolean;
    FRadius: Single;
    FOpacity: Single;
    FAnimTimer: TTimer;
    FTargetOpacity: Single;
    FAnimStep: Single;

    procedure SetAcrylic(Value: Boolean);
    procedure SetDropShadow(Value: Boolean);
    procedure SetRadius(Value: Single);
    procedure SetOpacity(Value: Single);
    procedure OnAnimTimer(Sender: TObject);
    function GetShadowOffset: Single;
  protected
    procedure Paint; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure FadeIn(ADurationMs: Integer = 150);
    procedure FadeOut(ADurationMs: Integer = 150);
  published
    property Align;
    property Anchors;
    property Acrylic: Boolean read FAcrylic write SetAcrylic default True;
    property DropShadow: Boolean read FDropShadow write SetDropShadow default True;
    property Radius: Single read FRadius write SetRadius;
    property Opacity: Single read FOpacity write SetOpacity;
    property Enabled;
    property Visible;
    property OnClick;
    property OnDblClick;
    property OnMouseDown;
    property OnMouseUp;
    property OnMouseMove;
  end;

implementation

{ THbGlassPanel }

constructor THbGlassPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csAcceptsControls, csOpaque];
  FAcrylic := True;
  FDropShadow := True;
  FRadius := 10.0;
  FOpacity := 1.0;
  FTargetOpacity := 1.0;
  FAnimStep := 0.0;

  FAnimTimer := TTimer.Create(Self);
  FAnimTimer.Interval := 30;
  FAnimTimer.OnTimer := OnAnimTimer;
  FAnimTimer.Enabled := False;

  Width := ScalePixels(240);
  Height := ScalePixels(160);
  DoubleBuffered := True;
end;

destructor THbGlassPanel.Destroy;
begin
  FreeAndNil(FAnimTimer);
  inherited;
end;

procedure THbGlassPanel.Resize;
begin
  inherited;
  Invalidate;
end;

procedure THbGlassPanel.SetAcrylic(Value: Boolean);
begin
  if FAcrylic <> Value then
  begin
    FAcrylic := Value;
    Invalidate;
  end;
end;

procedure THbGlassPanel.SetDropShadow(Value: Boolean);
begin
  if FDropShadow <> Value then
  begin
    FDropShadow := Value;
    Invalidate;
  end;
end;

procedure THbGlassPanel.SetRadius(Value: Single);
begin
  if FRadius <> Value then
  begin
    FRadius := Value;
    Invalidate;
  end;
end;

procedure THbGlassPanel.SetOpacity(Value: Single);
begin
  FOpacity := EnsureRange(Value, 0.0, 1.0);
  Invalidate;
end;

function THbGlassPanel.GetShadowOffset: Single;
begin
  if FDropShadow then
    Result := ScaleDIP(6.0)
  else
    Result := 0.0;
end;

procedure THbGlassPanel.FadeIn(ADurationMs: Integer);
var
  Steps: Integer;
begin
  FOpacity := 0.0;
  FTargetOpacity := 1.0;
  Steps := Max(1, ADurationMs div 30);
  FAnimStep := 1.0 / Steps;
  FAnimTimer.Enabled := True;
  Invalidate;
end;

procedure THbGlassPanel.FadeOut(ADurationMs: Integer);
var
  Steps: Integer;
begin
  FTargetOpacity := 0.0;
  Steps := Max(1, ADurationMs div 30);
  FAnimStep := -1.0 / Steps;
  FAnimTimer.Enabled := True;
  Invalidate;
end;

procedure THbGlassPanel.OnAnimTimer(Sender: TObject);
begin
  FOpacity := FOpacity + FAnimStep;
  if (FAnimStep > 0) and (FOpacity >= FTargetOpacity) then
  begin
    FOpacity := FTargetOpacity;
    FAnimTimer.Enabled := False;
  end
  else if (FAnimStep < 0) and (FOpacity <= FTargetOpacity) then
  begin
    FOpacity := FTargetOpacity;
    FAnimTimer.Enabled := False;
  end;
  Invalidate;
end;

procedure THbGlassPanel.Paint;
var
  Graphics: TGPGraphics;
  Tokens: THbTokens;
  ShOffset, Rad: Single;
  BodyRect, ShadowRect: TGPRectF;
  Path, ShadowPath: TGPGraphicsPath;
  Brush: TGPSolidBrush;
  Pen: TGPPen;
  I: Integer;
  ShadowAlpha, SurfaceAlpha: Byte;
  IsDarkTheme: Boolean;
begin
  Tokens := GetTokens;
  IsDarkTheme := RelativeLuminance(Tokens.Surface) < 0.5;
  Graphics := TGPGraphics.Create(Canvas.Handle);
  try
    Graphics.SetSmoothingMode(SmoothingModeAntiAlias);
    Graphics.SetTextRenderingHint(TextRenderingHintClearTypeGridFit);

    EraseBackground(Graphics);

    ShOffset := GetShadowOffset;
    Rad := ScaleDIP(FRadius);

    BodyRect := MakeRect(ShOffset * 0.5, ShOffset * 0.25,
                         Width - ShOffset, Height - ShOffset);

    // 1. Soft Multi-Pass Drop Shadow
    if FDropShadow then
    begin
      for I := 1 to 3 do
      begin
        ShadowRect := MakeRect(BodyRect.X - I * 1.5, BodyRect.Y + I * 2.0,
                               BodyRect.Width + I * 3.0, BodyRect.Height + I * 1.5);
        ShadowPath := CreateRoundRectPath(ShadowRect, Rad + I * 1.5);
        try
          ShadowAlpha := Byte(Round(12 * FOpacity / I));
          Brush := TGPSolidBrush.Create(ColorToARGB($FF000000, ShadowAlpha));
          try
            Graphics.FillPath(Brush, ShadowPath);
          finally
            Brush.Free;
          end;
        finally
          ShadowPath.Free;
        end;
      end;
    end;

    // 2. Translucent Frosted Glass / Acrylic Body
    Path := CreateRoundRectPath(BodyRect, Rad);
    try
      if FAcrylic then
      begin
        if IsDarkTheme then
          SurfaceAlpha := Byte(Round(215 * FOpacity))
        else
          SurfaceAlpha := Byte(Round(230 * FOpacity));

        Brush := TGPSolidBrush.Create(ColorToARGB(Tokens.Surface, SurfaceAlpha));
      end
      else
      begin
        SurfaceAlpha := Byte(Round(255 * FOpacity));
        Brush := TGPSolidBrush.Create(ColorToARGB(Tokens.Surface, SurfaceAlpha));
      end;

      try
        Graphics.FillPath(Brush, Path);
      finally
        Brush.Free;
      end;

      // 3. Top-Lit Specular Inner Rim Highlight
      if IsDarkTheme then
        Pen := TGPPen.Create(ColorToARGB($FFFFFFFF, Byte(Round(40 * FOpacity))), 1.0)
      else
        Pen := TGPPen.Create(ColorToARGB(Tokens.Border, Byte(Round(180 * FOpacity))), 1.0);
      try
        Graphics.DrawPath(Pen, Path);
      finally
        Pen.Free;
      end;
    finally
      Path.Free;
    end;
  finally
    Graphics.Free;
  end;
end;

end.
