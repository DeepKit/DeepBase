{ ============================================================================
  DeepBase.VCL.HB.Terminal - Terminal, Agent & Shell Views for VCL

  Version: 1.0 (Delphi 13.1 on Win64)
  Description: Terminal UI infrastructure for DeepDsh and downstream tools:
               THbKeyValRow (Key-Value row with mask & copy),
               THbToastHost (Host-level floating toast manager),
               THbStreamBlock (Agent delta streaming & thought folding block).
  ============================================================================ }

unit DeepBase.VCL.HB.Terminal;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  Winapi.GDIPOBJ,
  Winapi.GDIPAPI,
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
  System.Math,
  System.Generics.Collections,
  Vcl.Controls,
  Vcl.Graphics,
  Vcl.Forms,
  Vcl.ExtCtrls,
  Vcl.Clipbrd,
  DeepBase.HB.Core,
  DeepBase.HB.Terminal.Types,
  DeepBase.VCL.HB.Theme,
  DeepBase.VCL.HB.Controls;

type
  /// <summary>
  /// THbKeyValRow: Standardized property display row with masking and copy.
  /// </summary>
  THbKeyValRow = class(THbCustomControl)
  private
    FKeyText: string;
    FValueText: string;
    FLabelWidth: Integer;
    FIsMasked: Boolean;
    FIsMonospace: Boolean;
    FCanCopy: Boolean;
    FBadgeText: string;
    FBadgeTone: THbBadgeTone;
    FHoverCopy: Boolean;
    FOnCopied: TNotifyEvent;
    procedure SetKeyText(const Value: string);
    procedure SetValueText(const Value: string);
    procedure SetLabelWidth(const Value: Integer);
    procedure SetIsMasked(const Value: Boolean);
    procedure SetIsMonospace(const Value: Boolean);
    procedure SetCanCopy(const Value: Boolean);
    procedure SetBadgeText(const Value: string);
    procedure SetBadgeTone(const Value: THbBadgeTone);
    function GetDisplayValue: string;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
  protected
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure CopyToClipboard;
  published
    property Align;
    property Anchors;
    property BadgeText: string read FBadgeText write SetBadgeText;
    property BadgeTone: THbBadgeTone read FBadgeTone write SetBadgeTone default btNeutral;
    property CanCopy: Boolean read FCanCopy write SetCanCopy default True;
    property Enabled;
    property IsMasked: Boolean read FIsMasked write SetIsMasked default False;
    property IsMonospace: Boolean read FIsMonospace write SetIsMonospace default False;
    property KeyText: string read FKeyText write SetKeyText;
    property LabelWidth: Integer read FLabelWidth write SetLabelWidth default 140;
    property ValueText: string read FValueText write SetValueText;
    property Visible;
    property OnCopied: TNotifyEvent read FOnCopied write FOnCopied;
  end;

  /// <summary>
  /// THbStreamBlock: Agent delta streaming block with thought folding.
  /// </summary>
  THbStreamBlock = class(THbCustomControl)
  private
    FStage: THbStreamStage;
    FThoughtText: string;
    FContentText: string;
    FThoughtDurationSec: Single;
    FIsThoughtCollapsed: Boolean;
    FHoverThoughtHeader: Boolean;
    FAnimTimer: TTimer;
    FAnimPhase: Single;
    procedure SetStage(const Value: THbStreamStage);
    procedure SetThoughtText(const Value: string);
    procedure SetContentText(const Value: string);
    procedure SetThoughtDurationSec(const Value: Single);
    procedure SetIsThoughtCollapsed(const Value: Boolean);
    procedure OnAnimTimerTick(Sender: TObject);
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
  protected
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure AppendDelta(const AText: string; AIsThought: Boolean);
    procedure Clear;
  published
    property Align;
    property Anchors;
    property ContentText: string read FContentText write SetContentText;
    property Enabled;
    property IsThoughtCollapsed: Boolean read FIsThoughtCollapsed write SetIsThoughtCollapsed default False;
    property Stage: THbStreamStage read FStage write SetStage default ssThinking;
    property ThoughtDurationSec: Single read FThoughtDurationSec write SetThoughtDurationSec;
    property ThoughtText: string read FThoughtText write SetThoughtText;
    property Visible;
  end;

  /// <summary>
  /// THbToastHost: Host-level floating Toast notification manager.
  /// </summary>
  THbToastHost = class(TComponent)
  private
    FHostControl: TWinControl;
    FPosition: THbToastPosition;
    FActiveToasts: TList<THbToast>;
    procedure RepositionToasts;
  public
    constructor Create(AOwner: TComponent; AHostControl: TWinControl); reintroduce;
    destructor Destroy; override;
    procedure ShowToast(const AMessage: string; AKind: THbToastKind = tkSuccess; ADurationMs: Integer = 3000);
    property Position: THbToastPosition read FPosition write FPosition default tpTopRight;
  end;

implementation

{ THbKeyValRow }

constructor THbKeyValRow.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FKeyText := 'Property';
  FValueText := 'Value';
  FLabelWidth := 140;
  FIsMasked := False;
  FIsMonospace := False;
  FCanCopy := True;
  FBadgeText := '';
  FBadgeTone := btNeutral;
  FHoverCopy := False;
  Width := 360;
  Height := 28;
end;

procedure THbKeyValRow.SetKeyText(const Value: string);
begin
  if FKeyText <> Value then
  begin
    FKeyText := Value;
    Invalidate;
  end;
end;

procedure THbKeyValRow.SetValueText(const Value: string);
begin
  if FValueText <> Value then
  begin
    FValueText := Value;
    Invalidate;
  end;
end;

procedure THbKeyValRow.SetLabelWidth(const Value: Integer);
begin
  if FLabelWidth <> Value then
  begin
    FLabelWidth := Value;
    Invalidate;
  end;
end;

procedure THbKeyValRow.SetIsMasked(const Value: Boolean);
begin
  if FIsMasked <> Value then
  begin
    FIsMasked := Value;
    Invalidate;
  end;
end;

procedure THbKeyValRow.SetIsMonospace(const Value: Boolean);
begin
  if FIsMonospace <> Value then
  begin
    FIsMonospace := Value;
    Invalidate;
  end;
end;

procedure THbKeyValRow.SetCanCopy(const Value: Boolean);
begin
  if FCanCopy <> Value then
  begin
    FCanCopy := Value;
    Invalidate;
  end;
end;

procedure THbKeyValRow.SetBadgeText(const Value: string);
begin
  if FBadgeText <> Value then
  begin
    FBadgeText := Value;
    Invalidate;
  end;
end;

procedure THbKeyValRow.SetBadgeTone(const Value: THbBadgeTone);
begin
  if FBadgeTone <> Value then
  begin
    FBadgeTone := Value;
    Invalidate;
  end;
end;

function THbKeyValRow.GetDisplayValue: string;
begin
  if FIsMasked then
  begin
    if Length(FValueText) > 8 then
      Result := Copy(FValueText, 1, 3) + string.Create(#$2022, 8) + Copy(FValueText, Length(FValueText) - 2, 3)
    else
      Result := string.Create(#$2022, 8);
  end
  else
    Result := FValueText;
end;

procedure THbKeyValRow.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  OldHover: Boolean;
begin
  inherited MouseMove(Shift, X, Y);
  OldHover := FHoverCopy;
  FHoverCopy := FCanCopy and (X >= Width - 28) and (X <= Width - 4) and (Y >= 4) and (Y <= Height - 4);
  if OldHover <> FHoverCopy then
    Invalidate;
end;

procedure THbKeyValRow.CMMouseLeave(var Message: TMessage);
begin
  inherited;
  FHoverCopy := False;
  Invalidate;
end;

procedure THbKeyValRow.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button = mbLeft) and FCanCopy and FHoverCopy then
    CopyToClipboard;
end;

procedure THbKeyValRow.CopyToClipboard;
begin
  Clipboard.AsText := FValueText;
  if Assigned(FOnCopied) then
    FOnCopied(Self);
end;

procedure THbKeyValRow.Paint;
var
  Graphics: TGPGraphics;
  Tokens: THbTokens;
  BrushMuted, BrushVal: TGPSolidBrush;
  FontKey, FontVal: TGPFont;
  FontFamily: TGPFontFamily;
  StrFmt: TGPStringFormat;
  KeyRect, ValRect, CopyRect: TGPRectF;
  DisplayVal, ValFontName: string;
  ScaledLabelWidth: Single;
begin
  Tokens := GetTokens;
  Graphics := TGPGraphics.Create(Canvas.Handle);
  try
    Graphics.SetSmoothingMode(SmoothingModeAntiAlias);
    Graphics.SetTextRenderingHint(TextRenderingHintClearTypeGridFit);

    ScaledLabelWidth := ScalePixels(FLabelWidth);
    KeyRect := MakeRect(0.0, 0.0, ScaledLabelWidth, Single(Height));
    ValRect := MakeRect(ScaledLabelWidth + 8.0, 0.0, Width - ScaledLabelWidth - 36.0, Single(Height));
    CopyRect := MakeRect(Width - 24.0, (Height - 16.0) / 2.0, 18.0, 16.0);

    BrushMuted := TGPSolidBrush.Create(ColorToARGB(Tokens.InkMuted));
    BrushVal := TGPSolidBrush.Create(ColorToARGB(Tokens.Ink));
    StrFmt := TGPStringFormat.Create;
    try
      StrFmt.SetAlignment(StringAlignmentNear);
      StrFmt.SetLineAlignment(StringAlignmentCenter);

      // Key
      FontFamily := TGPFontFamily.Create(Tokens.FontFamily);
      try
        FontKey := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeS), FontStyleBold, UnitPixel);
        try
          Graphics.DrawString(FKeyText, Length(FKeyText), FontKey, KeyRect, StrFmt, BrushMuted);
        finally
          FontKey.Free;
        end;

        // Value
        if FIsMonospace then
          ValFontName := 'Consolas'
        else
          ValFontName := Tokens.FontFamily;

        var ValFamily := TGPFontFamily.Create(ValFontName);
        try
          FontVal := TGPFont.Create(ValFamily, ScaleDIP(Tokens.SizeS), FontStyleRegular, UnitPixel);
          try
            DisplayVal := GetDisplayValue;
            Graphics.DrawString(DisplayVal, Length(DisplayVal), FontVal, ValRect, StrFmt, BrushVal);
          finally
            FontVal.Free;
          end;
        finally
          ValFamily.Free;
        end;

        // Copy Icon Button
        if FCanCopy then
        begin
          if FHoverCopy then
          begin
            var HoverBg := TGPSolidBrush.Create(ColorToARGB(Tokens.Soft));
            try
              Graphics.FillRectangle(HoverBg, CopyRect);
            finally
              HoverBg.Free;
            end;
          end;
          var FontCopy := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeXS), FontStyleRegular, UnitPixel);
          try
            StrFmt.SetAlignment(StringAlignmentCenter);
            Graphics.DrawString(#$D83D#$DCCB, 2, FontCopy, CopyRect, StrFmt, BrushMuted);
          finally
            FontCopy.Free;
          end;
        end;
      finally
        FontFamily.Free;
      end;
    finally
      BrushMuted.Free;
      BrushVal.Free;
      StrFmt.Free;
    end;
  finally
    Graphics.Free;
  end;
end;

{ THbStreamBlock }

constructor THbStreamBlock.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FStage := ssThinking;
  FThoughtText := '';
  FContentText := '';
  FThoughtDurationSec := 0.0;
  FIsThoughtCollapsed := False;
  FHoverThoughtHeader := False;
  FAnimPhase := 0.0;
  Width := 460;
  Height := 160;

  FAnimTimer := TTimer.Create(Self);
  FAnimTimer.Interval := 60;
  FAnimTimer.OnTimer := OnAnimTimerTick;
  FAnimTimer.Enabled := True;
end;

destructor THbStreamBlock.Destroy;
begin
  FAnimTimer.Free;
  inherited Destroy;
end;

procedure THbStreamBlock.OnAnimTimerTick(Sender: TObject);
begin
  if FStage = ssThinking then
  begin
    FAnimPhase := FAnimPhase + 0.15;
    if FAnimPhase > 6.28 then
      FAnimPhase := 0.0;
    FThoughtDurationSec := FThoughtDurationSec + 0.06;
    Invalidate;
  end;
end;

procedure THbStreamBlock.SetStage(const Value: THbStreamStage);
begin
  if FStage <> Value then
  begin
    FStage := Value;
    if FStage in [ssCommitted, ssCompleted] then
      FIsThoughtCollapsed := True;
    Invalidate;
  end;
end;

procedure THbStreamBlock.SetThoughtText(const Value: string);
begin
  if FThoughtText <> Value then
  begin
    FThoughtText := Value;
    Invalidate;
  end;
end;

procedure THbStreamBlock.SetContentText(const Value: string);
begin
  if FContentText <> Value then
  begin
    FContentText := Value;
    Invalidate;
  end;
end;

procedure THbStreamBlock.SetThoughtDurationSec(const Value: Single);
begin
  if FThoughtDurationSec <> Value then
  begin
    FThoughtDurationSec := Value;
    Invalidate;
  end;
end;

procedure THbStreamBlock.SetIsThoughtCollapsed(const Value: Boolean);
begin
  if FIsThoughtCollapsed <> Value then
  begin
    FIsThoughtCollapsed := Value;
    Invalidate;
  end;
end;

procedure THbStreamBlock.AppendDelta(const AText: string; AIsThought: Boolean);
begin
  if AIsThought then
  begin
    FThoughtText := FThoughtText + AText;
    FStage := ssThinking;
  end
  else
  begin
    FContentText := FContentText + AText;
    if FStage = ssThinking then
    begin
      FStage := ssCommitted;
      FIsThoughtCollapsed := True;
    end;
  end;
  Invalidate;
end;

procedure THbStreamBlock.Clear;
begin
  FThoughtText := '';
  FContentText := '';
  FThoughtDurationSec := 0.0;
  FStage := ssThinking;
  FIsThoughtCollapsed := False;
  Invalidate;
end;

procedure THbStreamBlock.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  OldHover: Boolean;
begin
  inherited MouseMove(Shift, X, Y);
  OldHover := FHoverThoughtHeader;
  FHoverThoughtHeader := (Y >= 4) and (Y <= 30);
  if OldHover <> FHoverThoughtHeader then
    Invalidate;
end;

procedure THbStreamBlock.CMMouseLeave(var Message: TMessage);
begin
  inherited;
  FHoverThoughtHeader := False;
  Invalidate;
end;

procedure THbStreamBlock.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button = mbLeft) and FHoverThoughtHeader and (FThoughtText <> '') then
    IsThoughtCollapsed := not IsThoughtCollapsed;
end;

procedure THbStreamBlock.Paint;
var
  Graphics: TGPGraphics;
  Tokens: THbTokens;
  BrushSunken, BrushInk, BrushMuted, BrushPulse: TGPSolidBrush;
  FontHeader, FontContent: TGPFont;
  FontFamily: TGPFontFamily;
  StrFmt: TGPStringFormat;
  R, HeaderRect, ContentRect: TGPRectF;
  PulseAlpha: Byte;
  HeaderTitle: string;
begin
  Tokens := GetTokens;
  Graphics := TGPGraphics.Create(Canvas.Handle);
  try
    Graphics.SetSmoothingMode(SmoothingModeAntiAlias);
    Graphics.SetTextRenderingHint(TextRenderingHintClearTypeGridFit);

    R := MakeRect(0.0, 0.0, Single(Width), Single(Height));

    // 1. Outer Box
    BrushSunken := TGPSolidBrush.Create(ColorToARGB(Tokens.Sunken));
    try
      Graphics.FillRectangle(BrushSunken, R);
    finally
      BrushSunken.Free;
    end;

    // 2. Thought Section Header
    HeaderRect := MakeRect(8.0, 4.0, Width - 16.0, 24.0);
    if FStage = ssThinking then
    begin
      PulseAlpha := Byte(Round(120 + 80 * Sin(FAnimPhase)));
      BrushPulse := TGPSolidBrush.Create(ColorToARGB(Tokens.Primary, PulseAlpha));
      try
        Graphics.FillRectangle(BrushPulse, HeaderRect);
      finally
        BrushPulse.Free;
      end;
      HeaderTitle := Format(#$26A1 + ' 思考中 (%.1fs)... 点击折叠', [FThoughtDurationSec]);
    end
    else
    begin
      if FIsThoughtCollapsed then
        HeaderTitle := Format(#$25B6 + ' 展开思考过程 (%.1fs)', [FThoughtDurationSec])
      else
        HeaderTitle := Format(#$25BC + ' 收起思考过程 (%.1fs)', [FThoughtDurationSec]);
    end;

    BrushInk := TGPSolidBrush.Create(ColorToARGB(Tokens.Ink));
    BrushMuted := TGPSolidBrush.Create(ColorToARGB(Tokens.InkMuted));
    StrFmt := TGPStringFormat.Create;
    try
      FontFamily := TGPFontFamily.Create(Tokens.FontFamily);
      try
        FontHeader := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeXS), FontStyleBold, UnitPixel);
        try
          StrFmt.SetAlignment(StringAlignmentNear);
          StrFmt.SetLineAlignment(StringAlignmentCenter);
          Graphics.DrawString(HeaderTitle, Length(HeaderTitle), FontHeader, HeaderRect, StrFmt, BrushInk);
        finally
          FontHeader.Free;
        end;

        // 3. Thought Body or Committed Content
        ContentRect := MakeRect(8.0, 32.0, Width - 16.0, Height - 36.0);
        FontContent := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeS), FontStyleRegular, UnitPixel);
        try
          if (not FIsThoughtCollapsed) and (FThoughtText <> '') then
            Graphics.DrawString(FThoughtText, Length(FThoughtText), FontContent, ContentRect, StrFmt, BrushMuted)
          else if FContentText <> '' then
            Graphics.DrawString(FContentText, Length(FContentText), FontContent, ContentRect, StrFmt, BrushInk);
        finally
          FontContent.Free;
        end;
      finally
        FontFamily.Free;
      end;
    finally
      BrushInk.Free;
      BrushMuted.Free;
      StrFmt.Free;
    end;
  finally
    Graphics.Free;
  end;
end;

{ THbToastHost }

constructor THbToastHost.Create(AOwner: TComponent; AHostControl: TWinControl);
begin
  inherited Create(AOwner);
  FHostControl := AHostControl;
  FPosition := tpTopRight;
  FActiveToasts := TList<THbToast>.Create;
end;

destructor THbToastHost.Destroy;
var
  T: THbToast;
begin
  for T in FActiveToasts do
    T.Free;
  FActiveToasts.Free;
  inherited Destroy;
end;

procedure THbToastHost.ShowToast(const AMessage: string; AKind: THbToastKind; ADurationMs: Integer);
var
  T: THbToast;
begin
  if FHostControl = nil then
    Exit;

  T := THbToast.Create(FHostControl);
  T.Parent := FHostControl;
  T.MessageText := AMessage;
  T.Kind := AKind;
  T.Visible := True;
  FActiveToasts.Add(T);
  RepositionToasts;
end;

procedure THbToastHost.RepositionToasts;
var
  I: Integer;
  T: THbToast;
  TopPos: Integer;
begin
  if FHostControl = nil then
    Exit;

  TopPos := 16;
  for I := FActiveToasts.Count - 1 downto 0 do
  begin
    T := FActiveToasts[I];
    if not T.Visible then
    begin
      FActiveToasts.Delete(I);
      T.Free;
      Continue;
    end;

    case FPosition of
      tpTopRight:
        begin
          T.Left := FHostControl.ClientWidth - T.Width - 16;
          T.Top := TopPos;
        end;
      tpBottomRight:
        begin
          T.Left := FHostControl.ClientWidth - T.Width - 16;
          T.Top := FHostControl.ClientHeight - T.Height - TopPos;
        end;
      else
        begin
          T.Left := (FHostControl.ClientWidth - T.Width) div 2;
          T.Top := TopPos;
        end;
    end;
    TopPos := TopPos + T.Height + 8;
  end;
end;

end.
