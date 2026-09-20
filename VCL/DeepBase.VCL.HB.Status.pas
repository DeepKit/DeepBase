{ ============================================================================
  DeepBase.VCL.HB.Status - Token-Driven Status Dot & Indicator for VCL

  Version: 1.0 (Delphi 13.1 on Win64)
  Description: THbStatusDot:
               - 4+ States: Success, Danger, Warning, Muted, Info
               - Optional breathing / pulse halo glow animation
               - Optional accompanying label text with token typography
               - High-DPI scaling & real-time theme reactivity
  ============================================================================ }

unit DeepBase.VCL.HB.Status;

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
  /// Status indicator states for THbStatusDot.
  /// </summary>
  THbStatusDotState = (
    sdSuccess,  // Token Success (Green)
    sdDanger,   // Token Danger (Red)
    sdWarning,  // Token Warning (Amber)
    sdMuted,    // Token InkMuted / Border (Gray)
    sdInfo      // Token Info / Primary (Blue)
  );

  /// <summary>
  /// THbStatusDot: Modern vector status light with optional breathing pulse glow.
  /// </summary>
  THbStatusDot = class(THbCustomControl)
  private
    FStatus: THbStatusDotState;
    FPulse: Boolean;
    FDotSize: Single;
    FShowLabel: Boolean;
    FCaption: string;
    FAnimTimer: TTimer;
    FAnimPhase: Single;

    procedure SetStatus(Value: THbStatusDotState);
    procedure SetPulse(Value: Boolean);
    procedure SetDotSize(Value: Single);
    procedure SetShowLabel(Value: Boolean);
    procedure SetCaption(const Value: string);
    procedure OnAnimTimer(Sender: TObject);
    procedure UpdateTimerState;
    function GetStatusColor: TAlphaColor;
  protected
    procedure Paint; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    property StatusColor: TAlphaColor read GetStatusColor;
  published
    property Align;
    property Anchors;
    property Status: THbStatusDotState read FStatus write SetStatus default sdSuccess;
    property Pulse: Boolean read FPulse write SetPulse default False;
    property DotSize: Single read FDotSize write SetDotSize;
    property ShowLabel: Boolean read FShowLabel write SetShowLabel default False;
    property Caption: string read FCaption write SetCaption;
    property Enabled;
    property Visible;
    property OnClick;
    property OnDblClick;
    property OnMouseDown;
    property OnMouseUp;
    property OnMouseMove;
  end;

implementation

{ THbStatusDot }

constructor THbStatusDot.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle - [csAcceptsControls] + [csOpaque];
  FStatus := sdSuccess;
  FPulse := False;
  FDotSize := 8.0;
  FShowLabel := False;
  FCaption := '';
  FAnimPhase := 0.0;

  FAnimTimer := TTimer.Create(Self);
  FAnimTimer.Interval := 60;
  FAnimTimer.OnTimer := OnAnimTimer;
  FAnimTimer.Enabled := False;

  Width := ScalePixels(24);
  Height := ScalePixels(24);
  DoubleBuffered := True;
end;

destructor THbStatusDot.Destroy;
begin
  FreeAndNil(FAnimTimer);
  inherited;
end;

procedure THbStatusDot.Resize;
begin
  inherited;
end;

procedure THbStatusDot.SetStatus(Value: THbStatusDotState);
begin
  if FStatus <> Value then
  begin
    FStatus := Value;
    UpdateTimerState;
    Invalidate;
  end;
end;

procedure THbStatusDot.SetPulse(Value: Boolean);
begin
  if FPulse <> Value then
  begin
    FPulse := Value;
    UpdateTimerState;
    Invalidate;
  end;
end;

procedure THbStatusDot.SetDotSize(Value: Single);
begin
  if FDotSize <> Value then
  begin
    FDotSize := Value;
    Invalidate;
  end;
end;

procedure THbStatusDot.SetShowLabel(Value: Boolean);
begin
  if FShowLabel <> Value then
  begin
    FShowLabel := Value;
    Invalidate;
  end;
end;

procedure THbStatusDot.SetCaption(const Value: string);
begin
  if FCaption <> Value then
  begin
    FCaption := Value;
    Invalidate;
  end;
end;

procedure THbStatusDot.UpdateTimerState;
begin
  if Assigned(FAnimTimer) then
    FAnimTimer.Enabled := FPulse and (FStatus in [sdDanger, sdWarning, sdSuccess, sdInfo]);
end;

procedure THbStatusDot.OnAnimTimer(Sender: TObject);
begin
  FAnimPhase := FAnimPhase + 0.08;
  if FAnimPhase > 2.0 * Pi then
    FAnimPhase := FAnimPhase - 2.0 * Pi;
  Invalidate;
end;

function THbStatusDot.GetStatusColor: TAlphaColor;
var
  Tokens: THbTokens;
begin
  Tokens := GetTokens;
  case FStatus of
    sdSuccess: Result := Tokens.Success;
    sdDanger:  Result := Tokens.Danger;
    sdWarning: Result := Tokens.Warning;
    sdInfo:    Result := Tokens.Info;
    else       Result := Tokens.InkMuted;
  end;
end;

procedure THbStatusDot.Paint;
var
  Graphics: TGPGraphics;
  Tokens: THbTokens;
  BaseColor: TAlphaColor;
  DotDiameter, HaloDiameter: Single;
  DotCenterX, DotCenterY: Single;
  HaloAlpha: Byte;
  DotBrush, HaloBrush, TextBrush: TGPSolidBrush;
  FontFamily: TGPFontFamily;
  Font: TGPFont;
  StrFmt: TGPStringFormat;
  LabelRect: TGPRectF;
begin
  Tokens := GetTokens;
  BaseColor := GetStatusColor;
  Graphics := TGPGraphics.Create(Canvas.Handle);
  try
    Graphics.SetSmoothingMode(SmoothingModeAntiAlias);
    Graphics.SetTextRenderingHint(TextRenderingHintClearTypeGridFit);

    EraseBackground(Graphics);

    DotDiameter := ScaleDIP(FDotSize);
    DotCenterX := DotDiameter * 1.0;
    DotCenterY := Height * 0.5;

    // 1. Optional Pulsing Breathing Halo Ring
    if FPulse and (FStatus in [sdDanger, sdWarning, sdSuccess, sdInfo]) then
    begin
      HaloAlpha := Byte(Round(25 + 45 * (0.5 + 0.5 * Sin(FAnimPhase))));
      HaloDiameter := DotDiameter * (1.8 + 0.4 * (0.5 + 0.5 * Sin(FAnimPhase)));

      HaloBrush := TGPSolidBrush.Create(ColorToARGB(BaseColor, HaloAlpha));
      try
        Graphics.FillEllipse(HaloBrush, DotCenterX - HaloDiameter * 0.5, DotCenterY - HaloDiameter * 0.5, HaloDiameter, HaloDiameter);
      finally
        HaloBrush.Free;
      end;
    end;

    // 2. Solid Inner Dot
    DotBrush := TGPSolidBrush.Create(ColorToARGB(BaseColor));
    try
      Graphics.FillEllipse(DotBrush, DotCenterX - DotDiameter * 0.5, DotCenterY - DotDiameter * 0.5, DotDiameter, DotDiameter);
    finally
      DotBrush.Free;
    end;

    // 3. Optional Label Text
    if FShowLabel and (FCaption <> '') then
    begin
      FontFamily := TGPFontFamily.Create(Tokens.FontFamily);
      try
        Font := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeS), FontStyleRegular, UnitPixel);
        try
          TextBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.Ink));
          try
            StrFmt := TGPStringFormat.Create;
            try
              StrFmt.SetAlignment(StringAlignmentNear);
              StrFmt.SetLineAlignment(StringAlignmentCenter);
              StrFmt.SetFormatFlags(StrFmt.GetFormatFlags or StringFormatFlagsNoWrap);

              LabelRect := MakeRect(DotCenterX + DotDiameter * 0.8 + ScaleDIP(Tokens.SpaceXS), 0.0,
                                    Width - (DotCenterX + DotDiameter * 0.8), Height);
              Graphics.DrawString(FCaption, Length(FCaption), Font, LabelRect, StrFmt, TextBrush);
            finally
              StrFmt.Free;
            end;
          finally
            TextBrush.Free;
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

end.
