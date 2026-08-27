{ ============================================================================
  DeepBase.FMX.HB.Terminal - Terminal, Agent & Shell Views for FireMonkey

  Version: 1.0 (Delphi 13.1 on Win64 / Cross-Platform FMX)
  Description: Terminal UI infrastructure for DeepDsh & DeepBase in FireMonkey:
               THbKeyValRow (Key-Value row with mask & copy),
               THbToastHost (Host-level floating toast manager),
               THbStreamBlock (Agent delta streaming & thought folding block).
  ============================================================================ }

unit DeepBase.FMX.HB.Terminal;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
  System.Generics.Collections,
  FMX.Types,
  FMX.Controls,
  FMX.Graphics,
  FMX.Forms,
  FMX.Platform,
  DeepBase.HB.Core,
  DeepBase.HB.Terminal.Types,
  DeepBase.FMX.HB.Theme,
  DeepBase.FMX.HB.Controls;

type
  /// <summary>
  /// THbKeyValRow: Standardized property display row with masking and copy for FMX.
  /// </summary>
  THbKeyValRow = class(THbFmxControl)
  private
    FKeyText: string;
    FValueText: string;
    FLabelWidth: Single;
    FIsMasked: Boolean;
    FIsMonospace: Boolean;
    FCanCopy: Boolean;
    FBadgeText: string;
    FBadgeTone: THbBadgeTone;
    FHoverCopy: Boolean;
    FOnCopied: TNotifyEvent;
    procedure SetKeyText(const Value: string);
    procedure SetValueText(const Value: string);
    procedure SetLabelWidth(const Value: Single);
    procedure SetIsMasked(const Value: Boolean);
    procedure SetIsMonospace(const Value: Boolean);
    procedure SetCanCopy(const Value: Boolean);
    procedure SetBadgeText(const Value: string);
    procedure SetBadgeTone(const Value: THbBadgeTone);
    function GetDisplayValue: string;
  protected
    procedure MouseMove(Shift: TShiftState; X, Y: Single); override;
    procedure DoMouseLeave; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens); override;
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
    property LabelWidth: Single read FLabelWidth write SetLabelWidth;
    property ValueText: string read FValueText write SetValueText;
    property Visible;
    property OnCopied: TNotifyEvent read FOnCopied write FOnCopied;
  end;

  /// <summary>
  /// THbStreamBlock: Agent delta streaming block with thought folding for FMX.
  /// </summary>
  THbStreamBlock = class(THbFmxControl)
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
  protected
    procedure MouseMove(Shift: TShiftState; X, Y: Single); override;
    procedure DoMouseLeave; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens); override;
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
  /// THbToastHost: Host-level floating Toast notification manager for FMX.
  /// </summary>
  THbToastHost = class(TComponent)
  private
    FHostControl: TFmxObject;
    FPosition: THbToastPosition;
    FActiveToasts: TList<THbToast>;
    procedure RepositionToasts;
  public
    constructor Create(AOwner: TComponent; AHostControl: TFmxObject); reintroduce;
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
    Repaint;
  end;
end;

procedure THbKeyValRow.SetValueText(const Value: string);
begin
  if FValueText <> Value then
  begin
    FValueText := Value;
    Repaint;
  end;
end;

procedure THbKeyValRow.SetLabelWidth(const Value: Single);
begin
  if FLabelWidth <> Value then
  begin
    FLabelWidth := Value;
    Repaint;
  end;
end;

procedure THbKeyValRow.SetIsMasked(const Value: Boolean);
begin
  if FIsMasked <> Value then
  begin
    FIsMasked := Value;
    Repaint;
  end;
end;

procedure THbKeyValRow.SetIsMonospace(const Value: Boolean);
begin
  if FIsMonospace <> Value then
  begin
    FIsMonospace := Value;
    Repaint;
  end;
end;

procedure THbKeyValRow.SetCanCopy(const Value: Boolean);
begin
  if FCanCopy <> Value then
  begin
    FCanCopy := Value;
    Repaint;
  end;
end;

procedure THbKeyValRow.SetBadgeText(const Value: string);
begin
  if FBadgeText <> Value then
  begin
    FBadgeText := Value;
    Repaint;
  end;
end;

procedure THbKeyValRow.SetBadgeTone(const Value: THbBadgeTone);
begin
  if FBadgeTone <> Value then
  begin
    FBadgeTone := Value;
    Repaint;
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

procedure THbKeyValRow.MouseMove(Shift: TShiftState; X, Y: Single);
var
  OldHover: Boolean;
begin
  inherited MouseMove(Shift, X, Y);
  OldHover := FHoverCopy;
  FHoverCopy := FCanCopy and (X >= Width - 28) and (X <= Width - 4) and (Y >= 4) and (Y <= Height - 4);
  if OldHover <> FHoverCopy then
    Repaint;
end;

procedure THbKeyValRow.DoMouseLeave;
begin
  inherited DoMouseLeave;
  FHoverCopy := False;
  Repaint;
end;

procedure THbKeyValRow.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Enabled and (Button = TMouseButton.mbLeft) and FCanCopy and FHoverCopy then
    CopyToClipboard;
end;

procedure THbKeyValRow.CopyToClipboard;
var
  ClipService: IFMXClipboardService;
begin
  if TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, ClipService) then
    ClipService.SetClipboard(FValueText);

  if Assigned(FOnCopied) then
    FOnCopied(Self);
end;

procedure THbKeyValRow.DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens);
var
  R, KeyRect, ValRect, CopyRect: TRectF;
  DisplayVal, ValFontName: string;
begin
  R := ARect;
  KeyRect := TRectF.Create(R.Left, R.Top, R.Left + FLabelWidth, R.Bottom);
  ValRect := TRectF.Create(R.Left + FLabelWidth + 8, R.Top, R.Right - 32, R.Bottom);
  CopyRect := TRectF.Create(R.Right - 26, R.Top + (R.Height - 18) / 2, R.Right - 6, R.Top + (R.Height + 18) / 2);

  // Key
  Canvas.Fill.Color := Tokens.InkMuted;
  Canvas.Font.Family := Tokens.FontFamily;
  Canvas.Font.Size := Tokens.SizeS;
  Canvas.Font.Style := [TFontStyle.fsBold];
  Canvas.FillText(KeyRect, FKeyText, False, 1.0, [], TTextAlign.Leading, TTextAlign.Center);

  // Value
  if FIsMonospace then
    ValFontName := 'Consolas'
  else
    ValFontName := Tokens.FontFamily;

  Canvas.Fill.Color := Tokens.Ink;
  Canvas.Font.Family := ValFontName;
  Canvas.Font.Size := Tokens.SizeS;
  Canvas.Font.Style := [];
  DisplayVal := GetDisplayValue;
  Canvas.FillText(ValRect, DisplayVal, False, 1.0, [], TTextAlign.Leading, TTextAlign.Center);

  // Copy Icon Button
  if FCanCopy then
  begin
    if FHoverCopy then
    begin
      Canvas.Fill.Color := Tokens.Soft;
      Canvas.FillRect(CopyRect, Tokens.RadiusS, Tokens.RadiusS, AllCorners, 1.0);
    end;
    Canvas.Fill.Color := Tokens.InkMuted;
    Canvas.Font.Family := Tokens.FontFamily;
    Canvas.Font.Size := Tokens.SizeXS;
    Canvas.Font.Style := [];
    Canvas.FillText(CopyRect, #$D83D#$DCCB, False, 1.0, [], TTextAlign.Center, TTextAlign.Center);
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
    Repaint;
  end;
end;

procedure THbStreamBlock.SetStage(const Value: THbStreamStage);
begin
  if FStage <> Value then
  begin
    FStage := Value;
    if FStage in [ssCommitted, ssCompleted] then
      FIsThoughtCollapsed := True;
    Repaint;
  end;
end;

procedure THbStreamBlock.SetThoughtText(const Value: string);
begin
  if FThoughtText <> Value then
  begin
    FThoughtText := Value;
    Repaint;
  end;
end;

procedure THbStreamBlock.SetContentText(const Value: string);
begin
  if FContentText <> Value then
  begin
    FContentText := Value;
    Repaint;
  end;
end;

procedure THbStreamBlock.SetThoughtDurationSec(const Value: Single);
begin
  if FThoughtDurationSec <> Value then
  begin
    FThoughtDurationSec := Value;
    Repaint;
  end;
end;

procedure THbStreamBlock.SetIsThoughtCollapsed(const Value: Boolean);
begin
  if FIsThoughtCollapsed <> Value then
  begin
    FIsThoughtCollapsed := Value;
    Repaint;
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
  Repaint;
end;

procedure THbStreamBlock.Clear;
begin
  FThoughtText := '';
  FContentText := '';
  FThoughtDurationSec := 0.0;
  FStage := ssThinking;
  FIsThoughtCollapsed := False;
  Repaint;
end;

procedure THbStreamBlock.MouseMove(Shift: TShiftState; X, Y: Single);
var
  OldHover: Boolean;
begin
  inherited MouseMove(Shift, X, Y);
  OldHover := FHoverThoughtHeader;
  FHoverThoughtHeader := (Y >= 4) and (Y <= 30);
  if OldHover <> FHoverThoughtHeader then
    Repaint;
end;

procedure THbStreamBlock.DoMouseLeave;
begin
  inherited DoMouseLeave;
  FHoverThoughtHeader := False;
  Repaint;
end;

procedure THbStreamBlock.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Enabled and (Button = TMouseButton.mbLeft) and FHoverThoughtHeader and (FThoughtText <> '') then
    IsThoughtCollapsed := not IsThoughtCollapsed;
end;

procedure THbStreamBlock.DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens);
var
  R, HeaderRect, ContentRect: TRectF;
  PulseAlpha: Single;
  HeaderTitle: string;
begin
  R := ARect;
  R.Inflate(-1, -1);

  // 1. Outer Sunken Container
  Canvas.Fill.Color := Tokens.Sunken;
  Canvas.Fill.Kind := TBrushKind.Solid;
  Canvas.FillRect(R, Tokens.RadiusM, Tokens.RadiusM, AllCorners, 1.0);

  Canvas.Stroke.Color := Tokens.Border;
  Canvas.Stroke.Thickness := Tokens.BorderWidth;
  Canvas.Stroke.Kind := TBrushKind.Solid;
  Canvas.DrawRect(R, Tokens.RadiusM, Tokens.RadiusM, AllCorners, 1.0);

  // 2. Thought Section Header
  HeaderRect := TRectF.Create(R.Left + 8, R.Top + 6, R.Right - 8, R.Top + 30);
  if FStage = ssThinking then
  begin
    PulseAlpha := (0.5 + 0.3 * Sin(FAnimPhase));
    Canvas.Fill.Color := Tokens.Primary;
    Canvas.FillRect(HeaderRect, Tokens.RadiusS, Tokens.RadiusS, AllCorners, PulseAlpha);
    HeaderTitle := Format(#$26A1 + ' 思考中 (%.1fs)... 点击折叠', [FThoughtDurationSec]);
  end
  else
  begin
    if FIsThoughtCollapsed then
      HeaderTitle := Format(#$25B6 + ' 展开思考过程 (%.1fs)', [FThoughtDurationSec])
    else
      HeaderTitle := Format(#$25BC + ' 收起思考过程 (%.1fs)', [FThoughtDurationSec]);
  end;

  Canvas.Fill.Color := Tokens.Ink;
  Canvas.Font.Family := Tokens.FontFamily;
  Canvas.Font.Size := Tokens.SizeXS;
  Canvas.Font.Style := [TFontStyle.fsBold];
  Canvas.FillText(HeaderRect, HeaderTitle, False, 1.0, [], TTextAlign.Leading, TTextAlign.Center);

  // 3. Thought Body or Committed Content
  ContentRect := TRectF.Create(R.Left + 8, R.Top + 34, R.Right - 8, R.Bottom - 6);
  Canvas.Font.Size := Tokens.SizeS;
  Canvas.Font.Style := [];

  if (not FIsThoughtCollapsed) and (FThoughtText <> '') then
  begin
    Canvas.Fill.Color := Tokens.InkMuted;
    Canvas.FillText(ContentRect, FThoughtText, True, 1.0, [], TTextAlign.Leading, TTextAlign.Leading);
  end
  else if FContentText <> '' then
  begin
    Canvas.Fill.Color := Tokens.Ink;
    Canvas.FillText(ContentRect, FContentText, True, 1.0, [], TTextAlign.Leading, TTextAlign.Leading);
  end;
end;

{ THbToastHost }

constructor THbToastHost.Create(AOwner: TComponent; AHostControl: TFmxObject);
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
  HostCtrl: TControl;
begin
  if FHostControl = nil then
    Exit;

  T := THbToast.Create(Self);
  T.Parent := FHostControl;
  T.DurationMs := ADurationMs;
  T.ShowToast(AMessage, AKind);

  if FHostControl is TControl then
  begin
    HostCtrl := TControl(FHostControl);
    T.Position.Point := TPointF.Create(HostCtrl.Width - T.Width - 16, 16);
  end;

  FActiveToasts.Add(T);
  RepositionToasts;
end;

procedure THbToastHost.RepositionToasts;
var
  I: Integer;
  T: THbToast;
  TopPos: Single;
  HostCtrl: TControl;
begin
  if (FHostControl = nil) or not (FHostControl is TControl) then
    Exit;

  HostCtrl := TControl(FHostControl);
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
        T.Position.Point := TPointF.Create(HostCtrl.Width - T.Width - 16, TopPos);
      tpBottomRight:
        T.Position.Point := TPointF.Create(HostCtrl.Width - T.Width - 16, HostCtrl.Height - T.Height - TopPos);
      else
        T.Position.Point := TPointF.Create((HostCtrl.Width - T.Width) / 2.0, TopPos);
    end;
    TopPos := TopPos + T.Height + 8;
  end;
end;

end.
