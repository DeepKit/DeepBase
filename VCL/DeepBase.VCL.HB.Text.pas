{ ============================================================================
  DeepBase.VCL.HB.Text - Token-Driven Modern Text & Label Control for VCL

  Version: 1.0 (Delphi 13.1 on Win64)
  Description: THbText / THbLabel:
               - Token-driven color tones (Default, Primary, Success, Warning, Danger, Muted, Info)
               - Semantic text roles (Body, Heading, Subheading, Caption, Muted)
               - AutoSize, WordWrap, Multi-line, Alignment & Layout
               - High-DPI scaling & smooth ClearType / Anti-Aliased GDI+ rendering
               - Zero flicker & WM_HB_THEME_CHANGED real-time broadcast update
  ============================================================================ }

unit DeepBase.VCL.HB.Text;

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
  Vcl.Forms,
  DeepBase.HB.Core,
  DeepBase.VCL.HB.Theme,
  DeepBase.VCL.HB.Controls;

type
  /// <summary>
  /// Semantic typography roles for THbText.
  /// </summary>
  THbTextRole = (
    trBody,         // Tokens.SizeM, Tokens.Ink
    trMuted,        // Tokens.SizeS, Tokens.InkMuted
    trPrimary,      // Tokens.SizeM, Tokens.Primary
    trSecondary,    // Tokens.SizeS, Tokens.InkMuted
    trSuccess,      // Tokens.SizeM, Tokens.Success
    trWarning,      // Tokens.SizeM, Tokens.Warning
    trDanger,       // Tokens.SizeM, Tokens.Danger
    trInfo,         // Tokens.SizeM, Tokens.Info
    trHeading,      // Tokens.SizeL, Bold, Tokens.Ink
    trSubheading,   // Tokens.SizeM, Bold, Tokens.Ink
    trCaption       // Tokens.SizeXS, Tokens.InkMuted
  );

  /// <summary>
  /// Explicit color tone override for THbText.
  /// </summary>
  THbTextTone = (
    ttDefault,
    ttPrimary,
    ttSecondary,
    ttSuccess,
    ttWarning,
    ttDanger,
    ttMuted,
    ttInfo
  );

  /// <summary>
  /// Vertical text layout alignment.
  /// </summary>
  THbTextLayout = (
    tlTop,
    tlCenter,
    tlBottom
  );

  /// <summary>
  /// THbText: Modern token-driven typography label component for VCL.
  /// </summary>
  THbText = class(THbCustomControl)
  private
    FCaption: string;
    FWordWrap: Boolean;
    FAlignment: TAlignment;
    FLayout: THbTextLayout;
    FRole: THbTextRole;
    FTone: THbTextTone;
    FBold: Boolean;
    FFontSize: Single;
    FAutoSize: Boolean;
    FEllipsis: Boolean;

    procedure SetCaption(const Value: string);
    procedure SetWordWrap(Value: Boolean);
    procedure SetAlignment(Value: TAlignment);
    procedure SetLayout(Value: THbTextLayout);
    procedure SetRole(Value: THbTextRole);
    procedure SetTone(Value: THbTextTone);
    procedure SetBold(Value: Boolean);
    procedure SetFontSize(Value: Single);
    procedure SetAutoSizeProp(Value: Boolean);
    procedure SetEllipsis(Value: Boolean);

    procedure AdjustBoundsForText;
    function GetEffectiveColor: TAlphaColor;
    function GetEffectiveFontSize: Single;
    function GetEffectiveFontStyle: Integer;
  protected
    procedure Paint; override;
    procedure Resize; override;
    procedure Loaded; override;
    procedure CMTextChanged(var Message: TMessage); message CM_TEXTCHANGED;
  public
    constructor Create(AOwner: TComponent); override;

    property EffectiveColor: TAlphaColor read GetEffectiveColor;
    property EffectiveFontSize: Single read GetEffectiveFontSize;
  published
    property Align;
    property Anchors;
    property AutoSize: Boolean read FAutoSize write SetAutoSizeProp default True;
    property Caption: string read FCaption write SetCaption;
    property Text: string read FCaption write SetCaption;
    property WordWrap: Boolean read FWordWrap write SetWordWrap default False;
    property Alignment: TAlignment read FAlignment write SetAlignment default taLeftJustify;
    property Layout: THbTextLayout read FLayout write SetLayout default tlCenter;
    property Role: THbTextRole read FRole write SetRole default trBody;
    property Tone: THbTextTone read FTone write SetTone default ttDefault;
    property Bold: Boolean read FBold write SetBold default False;
    property FontSize: Single read FFontSize write SetFontSize;
    property Ellipsis: Boolean read FEllipsis write SetEllipsis default False;
    property Enabled;
    property Visible;
    property OnClick;
    property OnDblClick;
    property OnMouseDown;
    property OnMouseUp;
    property OnMouseMove;
  end;

  /// <summary>
  /// Alias for THbText to provide 1:1 drop-in naming for TLabel migrations.
  /// </summary>
  THbLabel = THbText;

implementation

{ THbText }

constructor THbText.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle - [csAcceptsControls] + [csOpaque];
  FCaption := 'HbText';
  FWordWrap := False;
  FAlignment := taLeftJustify;
  FLayout := tlCenter;
  FRole := trBody;
  FTone := ttDefault;
  FBold := False;
  FFontSize := 0.0;
  FAutoSize := True;
  FEllipsis := False;

  Width := ScalePixels(80);
  Height := ScalePixels(24);
  DoubleBuffered := True;
end;

procedure THbText.Loaded;
begin
  inherited;
  if FAutoSize then
    AdjustBoundsForText;
end;

procedure THbText.Resize;
begin
  inherited;
  if FAutoSize and FWordWrap then
    AdjustBoundsForText;
end;

procedure THbText.CMTextChanged(var Message: TMessage);
begin
  inherited;
  FCaption := Text;
  if FAutoSize then
    AdjustBoundsForText;
  Invalidate;
end;

procedure THbText.SetCaption(const Value: string);
begin
  if FCaption <> Value then
  begin
    FCaption := Value;
    if FAutoSize then
      AdjustBoundsForText;
    Invalidate;
  end;
end;

procedure THbText.SetWordWrap(Value: Boolean);
begin
  if FWordWrap <> Value then
  begin
    FWordWrap := Value;
    if FAutoSize then
      AdjustBoundsForText;
    Invalidate;
  end;
end;

procedure THbText.SetAlignment(Value: TAlignment);
begin
  if FAlignment <> Value then
  begin
    FAlignment := Value;
    Invalidate;
  end;
end;

procedure THbText.SetLayout(Value: THbTextLayout);
begin
  if FLayout <> Value then
  begin
    FLayout := Value;
    Invalidate;
  end;
end;

procedure THbText.SetRole(Value: THbTextRole);
begin
  if FRole <> Value then
  begin
    FRole := Value;
    if FAutoSize then
      AdjustBoundsForText;
    Invalidate;
  end;
end;

procedure THbText.SetTone(Value: THbTextTone);
begin
  if FTone <> Value then
  begin
    FTone := Value;
    Invalidate;
  end;
end;

procedure THbText.SetBold(Value: Boolean);
begin
  if FBold <> Value then
  begin
    FBold := Value;
    if FAutoSize then
      AdjustBoundsForText;
    Invalidate;
  end;
end;

procedure THbText.SetFontSize(Value: Single);
begin
  if FFontSize <> Value then
  begin
    FFontSize := Value;
    if FAutoSize then
      AdjustBoundsForText;
    Invalidate;
  end;
end;

procedure THbText.SetAutoSizeProp(Value: Boolean);
begin
  if FAutoSize <> Value then
  begin
    FAutoSize := Value;
    if FAutoSize then
      AdjustBoundsForText;
    Invalidate;
  end;
end;

procedure THbText.SetEllipsis(Value: Boolean);
begin
  if FEllipsis <> Value then
  begin
    FEllipsis := Value;
    Invalidate;
  end;
end;

function THbText.GetEffectiveColor: TAlphaColor;
var
  Tokens: THbTokens;
begin
  Tokens := GetTokens;
  if not Enabled then
    Exit(Tokens.InkMuted);

  // If explicit tone is set
  case FTone of
    ttPrimary:   Exit(Tokens.Primary);
    ttSecondary: Exit(Tokens.InkMuted);
    ttSuccess:   Exit(Tokens.Success);
    ttWarning:   Exit(Tokens.Warning);
    ttDanger:    Exit(Tokens.Danger);
    ttMuted:     Exit(Tokens.InkMuted);
    ttInfo:      Exit(Tokens.Info);
    else ;
  end;

  // Otherwise follow role
  case FRole of
    trMuted,
    trSecondary,
    trCaption:    Result := Tokens.InkMuted;
    trPrimary:    Result := Tokens.Primary;
    trSuccess:    Result := Tokens.Success;
    trWarning:    Result := Tokens.Warning;
    trDanger:     Result := Tokens.Danger;
    trInfo:       Result := Tokens.Info;
    else          Result := Tokens.Ink;
  end;
end;

function THbText.GetEffectiveFontSize: Single;
var
  Tokens: THbTokens;
begin
  if FFontSize > 0.0 then
    Exit(FFontSize);

  Tokens := GetTokens;
  case FRole of
    trHeading:    Result := Tokens.SizeL;
    trSubheading: Result := Tokens.SizeM;
    trMuted,
    trSecondary:  Result := Tokens.SizeS;
    trCaption:    Result := Tokens.SizeXS;
    else          Result := Tokens.SizeM;
  end;
end;

function THbText.GetEffectiveFontStyle: Integer;
begin
  Result := FontStyleRegular;
  if FBold or (FRole in [trHeading, trSubheading]) then
    Result := Result or FontStyleBold;
end;

procedure THbText.AdjustBoundsForText;
var
  Graphics: TGPGraphics;
  FontFamily: TGPFontFamily;
  Font: TGPFont;
  StrFmt: TGPStringFormat;
  Tokens: THbTokens;
  BoundRect: TGPRectF;
  LayoutWidth: Single;
begin
  if (FCaption = '') or not HandleAllocated then
    Exit;

  Tokens := GetTokens;
  Graphics := TGPGraphics.Create(Canvas.Handle);
  try
    Graphics.SetSmoothingMode(SmoothingModeAntiAlias);
    Graphics.SetTextRenderingHint(TextRenderingHintClearTypeGridFit);

    FontFamily := TGPFontFamily.Create(Tokens.FontFamily);
    try
      Font := TGPFont.Create(FontFamily, ScaleDIP(GetEffectiveFontSize), GetEffectiveFontStyle, UnitPixel);
      try
        StrFmt := TGPStringFormat.Create;
        try
          if FWordWrap and (Width > 0) then
            LayoutWidth := Width
          else
            LayoutWidth := 0;

          if not FWordWrap then
            StrFmt.SetFormatFlags(StrFmt.GetFormatFlags or StringFormatFlagsNoWrap);

          Graphics.MeasureString(FCaption, Length(FCaption), Font, MakePoint(0.0, 0.0), StrFmt, BoundRect);

          if FWordWrap and (LayoutWidth > 0) then
            SetBounds(Left, Top, Width, Max(ScalePixels(20), Ceil(BoundRect.Height) + ScalePixels(4)))
          else
            SetBounds(Left, Top, Max(ScalePixels(20), Ceil(BoundRect.Width) + ScalePixels(4)),
                              Max(ScalePixels(18), Ceil(BoundRect.Height) + ScalePixels(4)));
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

procedure THbText.Paint;
var
  Graphics: TGPGraphics;
  FontFamily: TGPFontFamily;
  Font: TGPFont;
  Brush: TGPSolidBrush;
  StrFmt: TGPStringFormat;
  Tokens: THbTokens;
  DrawRect: TGPRectF;
  FmtFlags: Integer;
begin
  Tokens := GetTokens;
  Graphics := TGPGraphics.Create(Canvas.Handle);
  try
    Graphics.SetSmoothingMode(SmoothingModeAntiAlias);
    Graphics.SetTextRenderingHint(TextRenderingHintClearTypeGridFit);

    EraseBackground(Graphics);

    if FCaption = '' then
      Exit;

    FontFamily := TGPFontFamily.Create(Tokens.FontFamily);
    try
      Font := TGPFont.Create(FontFamily, ScaleDIP(GetEffectiveFontSize), GetEffectiveFontStyle, UnitPixel);
      try
        Brush := TGPSolidBrush.Create(ColorToARGB(GetEffectiveColor));
        try
          StrFmt := TGPStringFormat.Create;
          try
            // Horizontal Alignment
            case FAlignment of
              taLeftJustify:  StrFmt.SetAlignment(StringAlignmentNear);
              taCenter:       StrFmt.SetAlignment(StringAlignmentCenter);
              taRightJustify: StrFmt.SetAlignment(StringAlignmentFar);
            end;

            // Vertical Layout
            case FLayout of
              tlTop:    StrFmt.SetLineAlignment(StringAlignmentNear);
              tlCenter: StrFmt.SetLineAlignment(StringAlignmentCenter);
              tlBottom: StrFmt.SetLineAlignment(StringAlignmentFar);
            end;

            FmtFlags := StrFmt.GetFormatFlags;
            if not FWordWrap then
              FmtFlags := FmtFlags or StringFormatFlagsNoWrap;
            StrFmt.SetFormatFlags(FmtFlags);

            if FEllipsis then
              StrFmt.SetTrimming(StringTrimmingEllipsisCharacter)
            else
              StrFmt.SetTrimming(StringTrimmingNone);

            DrawRect := MakeRect(0.0, 0.0, Single(Width), Single(Height));
            Graphics.DrawString(FCaption, Length(FCaption), Font, DrawRect, StrFmt, Brush);
          finally
            StrFmt.Free;
          end;
        finally
          Brush.Free;
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
