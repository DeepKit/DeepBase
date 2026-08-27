{ ============================================================================
  DeepBase.FMX.HB.Voice - Universal Voice Input & Confirmation Host for FMX

  Version: 1.0 (Delphi 13.1 on Win64 / Cross-Platform)
  Description: Universal Voice Input components for FMX:
               - THbVoiceWaveform: Animated waveform with timer & privacy guard
               - THbVoiceFieldCard: Structured field confirmation card with Diff view,
                 low-confidence warnings, and quote fold.
               - THbVoiceDialog: Multi-state voice input & confirmation helper.
  ============================================================================ }

unit DeepBase.FMX.HB.Voice;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
  System.Math,
  System.Generics.Collections,
  FMX.Types,
  FMX.Controls,
  FMX.Graphics,
  FMX.Objects,
  FMX.Forms,
  FMX.StdCtrls,
  FMX.Edit,
  FMX.Layouts,
  DeepBase.HB.Core,
  DeepBase.HB.Voice.Types,
  DeepBase.FMX.HB.Theme,
  DeepBase.FMX.HB.Controls;

type
  /// <summary>
  /// THbVoiceWaveform: Animated audio waveform with timer & privacy badge for FMX.
  /// </summary>
  THbVoiceWaveform = class(THbFmxControl)
  private
    FDurationSec: Integer;
    FMaxDurationSec: Integer;
    FIsRecording: Boolean;
    FIsPaused: Boolean;
    FAnimPhase: Single;
    FTimer: TTimer;
    procedure SetDurationSec(Value: Integer);
    procedure SetIsRecording(Value: Boolean);
    procedure SetIsPaused(Value: Boolean);
    procedure OnTimerTick(Sender: TObject);
  protected
    procedure DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure StartRecording;
    procedure PauseRecording;
    procedure ResumeRecording;
    procedure StopRecording;
  published
    property Align;
    property Anchors;
    property DurationSec: Integer read FDurationSec write SetDurationSec default 0;
    property Enabled;
    property IsPaused: Boolean read FIsPaused write SetIsPaused default False;
    property IsRecording: Boolean read FIsRecording write SetIsRecording default False;
    property MaxDurationSec: Integer read FMaxDurationSec write FMaxDurationSec default 120;
    property Visible;
  end;

  /// <summary>
  /// THbVoiceFieldCard: Structured field item card with Diff view for FMX.
  /// </summary>
  THbVoiceFieldCard = class(THbFmxControl)
  private
    FItem: THbVoiceFieldItem;
    FOnItemChanged: TNotifyEvent;
    procedure SetItem(const Value: THbVoiceFieldItem);
  protected
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens); override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Accept;
    procedure Discard;
    property Item: THbVoiceFieldItem read FItem write SetItem;
  published
    property Align;
    property Anchors;
    property Enabled;
    property Visible;
    property OnItemChanged: TNotifyEvent read FOnItemChanged write FOnItemChanged;
  end;

  /// <summary>
  /// Delegate signature for voice modal execution seam (for testing/automation).
  /// </summary>
  THbVoiceModalShowFunc = reference to function(AForm: TForm): TModalResult;

  /// <summary>
  /// THbVoiceDialog: Universal voice input modal dialog helper for FMX.
  /// </summary>
  THbVoiceDialog = class
  private
    class var FModalRunner: THbVoiceModalShowFunc;
  public
    class property ModalRunner: THbVoiceModalShowFunc read FModalRunner write FModalRunner;
    class function Execute(const ATitle: string; 
      var AItems: TArray<THbVoiceFieldItem>; 
      out AConfirmedCount: Integer): Boolean;
  end;

implementation

{ THbVoiceWaveform }

constructor THbVoiceWaveform.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FDurationSec := 0;
  FMaxDurationSec := 120;
  FIsRecording := False;
  FIsPaused := False;
  FAnimPhase := 0.0;
  Width := 560.0;
  Height := 140.0;

  FTimer := TTimer.Create(Self);
  FTimer.Interval := 60;
  FTimer.Enabled := False;
  FTimer.OnTimer := OnTimerTick;
end;

destructor THbVoiceWaveform.Destroy;
begin
  FTimer.Free;
  inherited;
end;

procedure THbVoiceWaveform.SetDurationSec(Value: Integer);
begin
  if FDurationSec <> Value then
  begin
    FDurationSec := Value;
    Repaint;
  end;
end;

procedure THbVoiceWaveform.SetIsRecording(Value: Boolean);
begin
  if FIsRecording <> Value then
  begin
    FIsRecording := Value;
    FTimer.Enabled := FIsRecording and not FIsPaused;
    Repaint;
  end;
end;

procedure THbVoiceWaveform.SetIsPaused(Value: Boolean);
begin
  if FIsPaused <> Value then
  begin
    FIsPaused := Value;
    FTimer.Enabled := FIsRecording and not FIsPaused;
    Repaint;
  end;
end;

procedure THbVoiceWaveform.OnTimerTick(Sender: TObject);
begin
  if FIsRecording and not FIsPaused then
  begin
    FAnimPhase := FAnimPhase + 0.15;
    if FAnimPhase > 6.28318 then
      FAnimPhase := FAnimPhase - 6.28318;
    Repaint;
  end;
end;

procedure THbVoiceWaveform.StartRecording;
begin
  FDurationSec := 0;
  FIsPaused := False;
  IsRecording := True;
end;

procedure THbVoiceWaveform.PauseRecording;
begin
  IsPaused := True;
end;

procedure THbVoiceWaveform.ResumeRecording;
begin
  IsPaused := False;
end;

procedure THbVoiceWaveform.StopRecording;
begin
  IsRecording := False;
  IsPaused := False;
end;

procedure THbVoiceWaveform.DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens);
var
  R, TimerRect, PrivacyRect: TRectF;
  I: Integer;
  BarX, BarH, CenterY: Single;
  TimerStr, PrivacyStr: string;
begin
  R := ARect;

  // Background
  Canvas.Fill.Color := Tokens.Sunken;
  Canvas.FillRect(R, Tokens.RadiusS, Tokens.RadiusS, AllCorners, 1.0);

  // Top Privacy Trust Badge
  PrivacyStr := '🔒 本地安全沙箱处理 · 录音不外泄';
  PrivacyRect := TRectF.Create(0.0, 10.0, Width, 30.0);
  Canvas.Font.Family := Tokens.FontFamily;
  Canvas.Font.Size := Tokens.SizeXS;
  Canvas.Font.Style := [];
  Canvas.Fill.Color := Tokens.InkMuted;
  Canvas.FillText(PrivacyRect, PrivacyStr, False, 1.0, [], TTextAlign.Center, TTextAlign.Center);

  // Center Waveform Bars
  CenterY := Height * 0.55;
  for I := 0 to 19 do
  begin
    BarX := 24.0 + I * ((Width - 48.0) / 20.0);
    if FIsRecording and not FIsPaused then
      BarH := 12.0 + 28.0 * Abs(Sin(FAnimPhase + I * 0.4))
    else
      BarH := 6.0;

    Canvas.Stroke.Color := Tokens.Primary;
    Canvas.Stroke.Thickness := 3.0;
    Canvas.DrawLine(PointF(BarX, CenterY - BarH / 2.0), PointF(BarX, CenterY + BarH / 2.0), 1.0);
  end;

  // Bottom Timer
  TimerStr := Format('⏱ %0.2d:%0.2d / %0.2d:%0.2d', [FDurationSec div 60, FDurationSec mod 60,
    FMaxDurationSec div 60, FMaxDurationSec mod 60]);
  TimerRect := TRectF.Create(0.0, Height - 30.0, Width, Height - 10.0);
  Canvas.Font.Size := Tokens.SizeS;
  Canvas.Fill.Color := Tokens.Ink;
  Canvas.FillText(TimerRect, TimerStr, False, 1.0, [], TTextAlign.Center, TTextAlign.Center);
end;

{ THbVoiceFieldCard }

constructor THbVoiceFieldCard.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 560.0;
  Height := 80.0;
end;

procedure THbVoiceFieldCard.SetItem(const Value: THbVoiceFieldItem);
begin
  FItem := Value;
  Repaint;
end;

procedure THbVoiceFieldCard.Accept;
begin
  FItem.Status := vfsAccepted;
  FItem.CurrentValue := FItem.ExtractedValue;
  Repaint;
  if Assigned(FOnItemChanged) then
    FOnItemChanged(Self);
end;

procedure THbVoiceFieldCard.Discard;
begin
  FItem.Status := vfsDiscarded;
  Repaint;
  if Assigned(FOnItemChanged) then
    FOnItemChanged(Self);
end;

procedure THbVoiceFieldCard.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button = TMouseButton.mbLeft) and Enabled then
  begin
    if (X >= Width - 60.0) and (X <= Width - 14.0) and (Y >= 14.0) and (Y <= 40.0) then
      Discard
    else if (X >= Width - 160.0) and (X <= Width - 116.0) and (Y >= 14.0) and (Y <= 40.0) then
      Accept;
  end;
end;

procedure THbVoiceFieldCard.DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens);
var
  R, LabelRect, ValRect, DiffRect, QuoteRect: TRectF;
  IndicatorColor: TAlphaColor;
  DiffStr: string;
begin
  R := ARect;

  // Background
  Canvas.Fill.Color := Tokens.Surface;
  Canvas.FillRect(R, Tokens.RadiusS, Tokens.RadiusS, AllCorners, 1.0);

  // Left Status Tone Indicator
  case FItem.Status of
    vfsAccepted: IndicatorColor := Tokens.Success;
    vfsModified: IndicatorColor := Tokens.Warning;
    vfsDiscarded: IndicatorColor := Tokens.InkMuted;
    else
      if FItem.Confidence < 0.70 then
        IndicatorColor := Tokens.Danger
      else
        IndicatorColor := Tokens.Primary;
  end;

  Canvas.Stroke.Color := IndicatorColor;
  Canvas.Stroke.Thickness := 4.0;
  Canvas.DrawLine(PointF(2.0, 0.0), PointF(2.0, Height), 1.0);

  // Field Label
  LabelRect := TRectF.Create(16.0, 14.0, 136.0, 38.0);
  Canvas.Font.Family := Tokens.FontFamily;
  Canvas.Font.Size := Tokens.SizeS;
  Canvas.Font.Style := [TFontStyle.fsBold];
  Canvas.Fill.Color := Tokens.Ink;
  Canvas.FillText(LabelRect, FItem.FieldLabel, False, 1.0, [], TTextAlign.Leading, TTextAlign.Center);

  // Extracted Value
  ValRect := TRectF.Create(140.0, 14.0, Width - 170.0, 38.0);
  Canvas.Font.Style := [];
  var ValText := FItem.CurrentValue;
  if FItem.Status = vfsDiscarded then
    ValText := ValText + ' (已丢弃)';
  Canvas.FillText(ValRect, ValText, False, 1.0, [], TTextAlign.Leading, TTextAlign.Center);

  // Diff / Quote
  Canvas.Font.Size := Tokens.SizeXS;
  if FItem.OldValue <> '' then
  begin
    DiffStr := Format('原值: %s → 提议更新: %s', [FItem.OldValue, FItem.ExtractedValue]);
    DiffRect := TRectF.Create(140.0, 40.0, Width - 170.0, 58.0);
    Canvas.Fill.Color := Tokens.Warning;
    Canvas.FillText(DiffRect, DiffStr, False, 1.0, [], TTextAlign.Leading, TTextAlign.Center);
  end
  else if FItem.OriginalQuote <> '' then
  begin
    DiffStr := '原话摘录: "' + FItem.OriginalQuote + '"';
    QuoteRect := TRectF.Create(140.0, 40.0, Width - 170.0, 58.0);
    Canvas.Fill.Color := Tokens.InkMuted;
    Canvas.FillText(QuoteRect, DiffStr, False, 1.0, [], TTextAlign.Leading, TTextAlign.Center);
  end;

  // Accept & Discard Buttons
  var BtnAcceptRect := TRectF.Create(Width - 160.0, 14.0, Width - 118.0, 38.0);
  Canvas.Fill.Color := Tokens.Success;
  Canvas.FillRect(BtnAcceptRect, Tokens.RadiusS, Tokens.RadiusS, AllCorners, 0.3);
  Canvas.Fill.Color := Tokens.Ink;
  Canvas.Font.Style := [TFontStyle.fsBold];
  Canvas.FillText(BtnAcceptRect, '✓', False, 1.0, [], TTextAlign.Center, TTextAlign.Center);

  var BtnDiscRect := TRectF.Create(Width - 60.0, 14.0, Width - 18.0, 38.0);
  Canvas.Fill.Color := Tokens.Border;
  Canvas.FillRect(BtnDiscRect, Tokens.RadiusS, Tokens.RadiusS, AllCorners, 1.0);
  Canvas.Fill.Color := Tokens.Ink;
  Canvas.FillText(BtnDiscRect, '🗑️', False, 1.0, [], TTextAlign.Center, TTextAlign.Center);
end;

class function THbVoiceDialog.Execute(const ATitle: string; 
  var AItems: TArray<THbVoiceFieldItem>; 
  out AConfirmedCount: Integer): Boolean;
var
  DlgForm: TForm;
  PnlHeader, PnlFooter: TPanel;
  LblTitle: TLabel;
  BtnOk, BtnCancel: TButton;
  ScrollBox: TVertScrollBox;
  CardList: TList<THbVoiceFieldCard>;
  Card: THbVoiceFieldCard;
  I: Integer;
  Tokens: THbTokens;
begin
  Result := False;
  AConfirmedCount := 0;
  Tokens := THbTheme.Tokens;

  DlgForm := TForm.CreateNew(nil);
  CardList := TList<THbVoiceFieldCard>.Create;
  try
    DlgForm.Position := TFormPosition.ScreenCenter;
    DlgForm.ClientWidth := 560;
    DlgForm.ClientHeight := 480;
    DlgForm.Caption := ATitle;

    // Header
    PnlHeader := TPanel.Create(DlgForm);
    PnlHeader.Parent := DlgForm;
    PnlHeader.Align := TAlignLayout.Top;
    PnlHeader.Height := 54;

    LblTitle := TLabel.Create(PnlHeader);
    LblTitle.Parent := PnlHeader;
    LblTitle.Position.X := 16;
    LblTitle.Position.Y := 16;
    LblTitle.Text := ATitle;
    LblTitle.StyledSettings := [];
    LblTitle.TextSettings.Font.Size := 14;
    LblTitle.TextSettings.Font.Style := [TFontStyle.fsBold];
    LblTitle.TextSettings.FontColor := Tokens.Ink;

    // Footer
    PnlFooter := TPanel.Create(DlgForm);
    PnlFooter.Parent := DlgForm;
    PnlFooter.Align := TAlignLayout.Bottom;
    PnlFooter.Height := 48;

    BtnOk := TButton.Create(PnlFooter);
    BtnOk.Parent := PnlFooter;
    BtnOk.Position.X := 440;
    BtnOk.Position.Y := 10;
    BtnOk.Width := 90;
    BtnOk.Height := 32;
    BtnOk.Text := '全部采纳';
    BtnOk.ModalResult := mrOk;

    BtnCancel := TButton.Create(PnlFooter);
    BtnCancel.Parent := PnlFooter;
    BtnCancel.Position.X := 338;
    BtnCancel.Position.Y := 10;
    BtnCancel.Width := 90;
    BtnCancel.Height := 32;
    BtnCancel.Text := '取消';
    BtnCancel.ModalResult := mrCancel;

    // ScrollBox Cards
    ScrollBox := TVertScrollBox.Create(DlgForm);
    ScrollBox.Parent := DlgForm;
    ScrollBox.Align := TAlignLayout.Client;

    for I := Low(AItems) to High(AItems) do
    begin
      Card := THbVoiceFieldCard.Create(ScrollBox);
      Card.Parent := ScrollBox;
      Card.Align := TAlignLayout.Top;
      Card.Position.Y := I * 84;
      Card.Height := 80;
      Card.Item := AItems[I];
      CardList.Add(Card);
    end;

    var ModalRes: TModalResult;
    if Assigned(FModalRunner) then
      ModalRes := FModalRunner(DlgForm)
    else
      ModalRes := DlgForm.ShowModal;

    if ModalRes = mrOk then
    begin
      Result := True;
      AConfirmedCount := 0;
      for I := 0 to CardList.Count - 1 do
      begin
        AItems[I] := CardList[I].Item;
        if AItems[I].Status in [vfsAccepted, vfsModified] then
          Inc(AConfirmedCount);
      end;
    end
    else
    begin
      Result := False;
      AConfirmedCount := 0;
    end;
  finally
    CardList.Free;
    DlgForm.Free;
  end;
end;

end.
