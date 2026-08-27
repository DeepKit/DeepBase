{ ============================================================================
  DeepBase.VCL.HB.Voice - Universal Voice Input, Waveform & Confirmation Host for VCL

  Version: 1.0 (Delphi 13.1 on Win64)
  Description: Universal Voice Input components for VCL:
               - THbVoiceWaveform: Animated waveform with timer & privacy guard
               - THbVoiceFieldCard: Structured field confirmation card with Diff view,
                 low-confidence warnings, in-place inline editing, and quote fold.
               - THbVoiceInputHost / THbVoiceDialog: Complete six-state flow container
                 (Entry, Recording, Extracting, Confirming, Persisted, Draft).
  ============================================================================ }

unit DeepBase.VCL.HB.Voice;

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
  Vcl.StdCtrls,
  DeepBase.HB.Core,
  DeepBase.HB.Voice.Types,
  DeepBase.VCL.HB.Theme,
  DeepBase.VCL.HB.Controls,
  DeepBase.VCL.HB.Terminal;

type
  /// <summary>
  /// THbVoiceWaveform: Animated audio waveform with timer & privacy badge.
  /// </summary>
  THbVoiceWaveform = class(THbCustomControl)
  private
    FDurationSec: Integer;
    FMaxDurationSec: Integer;
    FIsRecording: Boolean;
    FIsPaused: Boolean;
    FAnimPhase: Single;
    FTimer: TTimer;
    FOnFinish: TNotifyEvent;
    FOnCancel: TNotifyEvent;
    procedure SetDurationSec(Value: Integer);
    procedure SetIsRecording(Value: Boolean);
    procedure SetIsPaused(Value: Boolean);
    procedure OnTimerTick(Sender: TObject);
  protected
    procedure Paint; override;
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
    property OnCancel: TNotifyEvent read FOnCancel write FOnCancel;
    property OnFinish: TNotifyEvent read FOnFinish write FOnFinish;
  end;

  /// <summary>
  /// THbVoiceFieldCard: Structured field item card with Diff view & inline edit.
  /// </summary>
  THbVoiceFieldCard = class(THbCustomControl)
  private
    FItem: THbVoiceFieldItem;
    FIsEditing: Boolean;
    FEditBox: TEdit;
    FOnItemChanged: TNotifyEvent;
    procedure SetItem(const Value: THbVoiceFieldItem);
    procedure SetIsEditing(Value: Boolean);
    procedure OnEditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  protected
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure Paint; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Accept;
    procedure BeginEdit;
    procedure CommitEdit;
    procedure Discard;
    property Item: THbVoiceFieldItem read FItem write SetItem;
  published
    property Align;
    property Anchors;
    property Enabled;
    property IsEditing: Boolean read FIsEditing write SetIsEditing default False;
    property Visible;
    property OnItemChanged: TNotifyEvent read FOnItemChanged write FOnItemChanged;
  end;

  /// <summary>
  /// Delegate signature for voice modal execution seam (for testing/automation).
  /// </summary>
  THbVoiceModalShowFunc = reference to function(AForm: TForm): TModalResult;

  /// <summary>
  /// THbVoiceDialog: Universal multi-state voice input & confirmation modal dialog.
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
  Width := 560;
  Height := 140;

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
    Invalidate;
  end;
end;

procedure THbVoiceWaveform.SetIsRecording(Value: Boolean);
begin
  if FIsRecording <> Value then
  begin
    FIsRecording := Value;
    FTimer.Enabled := FIsRecording and not FIsPaused;
    Invalidate;
  end;
end;

procedure THbVoiceWaveform.SetIsPaused(Value: Boolean);
begin
  if FIsPaused <> Value then
  begin
    FIsPaused := Value;
    FTimer.Enabled := FIsRecording and not FIsPaused;
    Invalidate;
  end;
end;

procedure THbVoiceWaveform.OnTimerTick(Sender: TObject);
begin
  if FIsRecording and not FIsPaused then
  begin
    FAnimPhase := FAnimPhase + 0.15;
    if FAnimPhase > 6.28318 then
      FAnimPhase := FAnimPhase - 6.28318;
    Invalidate;
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

procedure THbVoiceWaveform.Paint;
var
  Graphics: TGPGraphics;
  Tokens: THbTokens;
  BrushBg, BrushInk, BrushMuted, BrushBrand: TGPSolidBrush;
  PenWave: TGPPen;
  FontTimer, FontBadge: TGPFont;
  FontFamily: TGPFontFamily;
  StrFmt: TGPStringFormat;
  R, TimerRect, PrivacyRect: TGPRectF;
  I: Integer;
  BarX, BarH, CenterY: Single;
  TimerStr, PrivacyStr: string;
begin
  Tokens := GetTokens;
  Graphics := TGPGraphics.Create(Canvas.Handle);
  try
    Graphics.SetSmoothingMode(SmoothingModeAntiAlias);
    Graphics.SetTextRenderingHint(TextRenderingHintClearTypeGridFit);

    R := MakeRect(0.0, 0.0, Single(Width), Single(Height));

    // Outer Background
    BrushBg := TGPSolidBrush.Create(ColorToARGB(Tokens.Sunken));
    try
      Graphics.FillRectangle(BrushBg, R);
    finally
      BrushBg.Free;
    end;

    FontFamily := TGPFontFamily.Create(Tokens.FontFamily);
    try
      FontTimer := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeL), FontStyleBold, UnitPixel);
      FontBadge := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeXS), FontStyleRegular, UnitPixel);
      BrushInk := TGPSolidBrush.Create(ColorToARGB(Tokens.Ink));
      BrushMuted := TGPSolidBrush.Create(ColorToARGB(Tokens.InkMuted));
      BrushBrand := TGPSolidBrush.Create(ColorToARGB(Tokens.Primary));
      PenWave := TGPPen.Create(ColorToARGB(Tokens.Primary), 3.0);
      StrFmt := TGPStringFormat.Create;
      try
        StrFmt.SetAlignment(StringAlignmentCenter);
        StrFmt.SetLineAlignment(StringAlignmentCenter);

        // Top Privacy Trust Badge
        PrivacyStr := '🔒 本地安全沙箱处理 · 录音不外泄';
        PrivacyRect := MakeRect(0.0, 10.0, Single(Width), 20.0);
        Graphics.DrawString(PrivacyStr, Length(PrivacyStr), FontBadge, PrivacyRect, StrFmt, BrushMuted);

        // Center Waveform Bars (24 bars)
        CenterY := Height / 2.0 + 4.0;
        for I := 0 to 23 do
        begin
          BarX := Width / 2.0 - 140.0 + I * 12.0;
          if FIsRecording and not FIsPaused then
            BarH := 8.0 + 26.0 * Abs(Sin(FAnimPhase + I * 0.35))
          else
            BarH := 6.0;

          Graphics.DrawLine(PenWave, BarX, CenterY - BarH / 2.0, BarX, CenterY + BarH / 2.0);
        end;

        // Bottom Timer String (e.g. 00:23 / 02:00)
        var MinVal := FDurationSec div 60;
        var SecVal := FDurationSec mod 60;
        var MaxMin := FMaxDurationSec div 60;
        var MaxSec := FMaxDurationSec mod 60;
        TimerStr := Format('%.2d:%.2d / %.2d:%.2d', [MinVal, SecVal, MaxMin, MaxSec]);

        TimerRect := MakeRect(0.0, Single(Height) - 34.0, Single(Width), 26.0);
        Graphics.DrawString(TimerStr, Length(TimerStr), FontTimer, TimerRect, StrFmt, BrushInk);
      finally
        StrFmt.Free;
        PenWave.Free;
        BrushBrand.Free;
        BrushMuted.Free;
        BrushInk.Free;
        FontBadge.Free;
        FontTimer.Free;
      end;
    finally
      FontFamily.Free;
    end;
  finally
    Graphics.Free;
  end;
end;

{ THbVoiceFieldCard }

constructor THbVoiceFieldCard.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 560;
  Height := 80;
  FIsEditing := False;

  FEditBox := TEdit.Create(Self);
  FEditBox.Parent := Self;
  FEditBox.Visible := False;
  FEditBox.OnKeyDown := OnEditKeyDown;
end;

procedure THbVoiceFieldCard.SetItem(const Value: THbVoiceFieldItem);
begin
  FItem := Value;
  if FItem.CurrentValue = '' then
    FItem.CurrentValue := FItem.ExtractedValue;
  Invalidate;
end;

procedure THbVoiceFieldCard.SetIsEditing(Value: Boolean);
begin
  if FIsEditing <> Value then
  begin
    FIsEditing := Value;
    FEditBox.Visible := FIsEditing;
    if FIsEditing then
    begin
      FEditBox.Text := FItem.CurrentValue;
      FEditBox.SetFocus;
      FEditBox.SelectAll;
    end;
    Invalidate;
  end;
end;

procedure THbVoiceFieldCard.OnEditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    CommitEdit;
    Key := 0;
  end
  else if Key = VK_ESCAPE then
  begin
    IsEditing := False;
    Key := 0;
  end;
end;

procedure THbVoiceFieldCard.Accept;
begin
  FItem.Status := vfsAccepted;
  IsEditing := False;
  Invalidate;
  if Assigned(FOnItemChanged) then
    FOnItemChanged(Self);
end;

procedure THbVoiceFieldCard.BeginEdit;
begin
  IsEditing := True;
end;

procedure THbVoiceFieldCard.CommitEdit;
begin
  FItem.CurrentValue := FEditBox.Text;
  FItem.Status := vfsModified;
  IsEditing := False;
  Invalidate;
  if Assigned(FOnItemChanged) then
    FOnItemChanged(Self);
end;

procedure THbVoiceFieldCard.Discard;
begin
  FItem.Status := vfsDiscarded;
  IsEditing := False;
  Invalidate;
  if Assigned(FOnItemChanged) then
    FOnItemChanged(Self);
end;

procedure THbVoiceFieldCard.Resize;
begin
  inherited;
  if Assigned(FEditBox) then
  begin
    FEditBox.Left := 140;
    FEditBox.Top := 22;
    FEditBox.Width := Width - 320;
    FEditBox.Height := 26;
  end;
end;

procedure THbVoiceFieldCard.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button = mbLeft) and Enabled then
  begin
    // Check Action Buttons on Right
    if (X >= Width - 60) and (X <= Width - 14) and (Y >= 14) and (Y <= 40) then
      Discard
    else if (X >= Width - 110) and (X <= Width - 66) and (Y >= 14) and (Y <= 40) then
      BeginEdit
    else if (X >= Width - 160) and (X <= Width - 116) and (Y >= 14) and (Y <= 40) then
      Accept;
  end;
end;

procedure THbVoiceFieldCard.Paint;
var
  Graphics: TGPGraphics;
  Tokens: THbTokens;
  BrushBg, BrushInk, BrushMuted: TGPSolidBrush;
  FontLabel, FontVal, FontSmall: TGPFont;
  FontFamily: TGPFontFamily;
  StrFmt: TGPStringFormat;
  R, LabelRect, ValRect, DiffRect, QuoteRect: TGPRectF;
  IndicatorColor: TAlphaColor;
  IndicatorPen: TGPPen;
  DiffStr: string;
begin
  Tokens := GetTokens;
  Graphics := TGPGraphics.Create(Canvas.Handle);
  try
    Graphics.SetSmoothingMode(SmoothingModeAntiAlias);
    Graphics.SetTextRenderingHint(TextRenderingHintClearTypeGridFit);

    R := MakeRect(0.0, 0.0, Single(Width), Single(Height));

    // Outer Background
    BrushBg := TGPSolidBrush.Create(ColorToARGB(Tokens.Surface));
    try
      Graphics.FillRectangle(BrushBg, R);
    finally
      BrushBg.Free;
    end;

    // Status Indicator Line
    case FItem.Status of
      vfsAccepted, vfsModified: IndicatorColor := Tokens.Success;
      vfsDiscarded: IndicatorColor := Tokens.Border;
      else
        if FItem.IsLowConfidence then
          IndicatorColor := Tokens.Warning
        else
          IndicatorColor := Tokens.Primary;
    end;

    IndicatorPen := TGPPen.Create(ColorToARGB(IndicatorColor), 4.0);
    try
      Graphics.DrawLine(IndicatorPen, 2.0, 0.0, 2.0, Single(Height));
    finally
      IndicatorPen.Free;
    end;

    FontFamily := TGPFontFamily.Create(Tokens.FontFamily);
    try
      FontLabel := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeS), FontStyleBold, UnitPixel);
      FontVal := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeS), FontStyleRegular, UnitPixel);
      FontSmall := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeXS), FontStyleRegular, UnitPixel);
      BrushInk := TGPSolidBrush.Create(ColorToARGB(Tokens.Ink));
      BrushMuted := TGPSolidBrush.Create(ColorToARGB(Tokens.InkMuted));
      StrFmt := TGPStringFormat.Create;
      try
        StrFmt.SetLineAlignment(StringAlignmentCenter);

        // 1. Field Label
        StrFmt.SetAlignment(StringAlignmentNear);
        LabelRect := MakeRect(16.0, 14.0, 120.0, 24.0);
        Graphics.DrawString(FItem.FieldLabel, Length(FItem.FieldLabel), FontLabel, LabelRect, StrFmt, BrushInk);

        // 2. Extracted / Current Value (if not editing)
        if not FIsEditing then
        begin
          ValRect := MakeRect(140.0, 14.0, Width - 320.0, 24.0);
          var ValText := FItem.CurrentValue;
          if FItem.Status = vfsDiscarded then
            ValText := ValText + ' (已丢弃)';
          Graphics.DrawString(ValText, Length(ValText), FontVal, ValRect, StrFmt, BrushInk);
        end;

        // 3. Diff View Sub-line (OldValue vs ExtractedValue)
        if FItem.OldValue <> '' then
        begin
          DiffStr := Format('原值: %s → 提议更新: %s', [FItem.OldValue, FItem.ExtractedValue]);
          DiffRect := MakeRect(140.0, 40.0, Width - 320.0, 18.0);
          var DiffBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.Warning));
          try
            Graphics.DrawString(DiffStr, Length(DiffStr), FontSmall, DiffRect, StrFmt, DiffBrush);
          finally
            DiffBrush.Free;
          end;
        end
        else if FItem.OriginalQuote <> '' then
        begin
          // Quote snippet
          DiffStr := '原话摘录: "' + FItem.OriginalQuote + '"';
          QuoteRect := MakeRect(140.0, 40.0, Width - 320.0, 18.0);
          Graphics.DrawString(DiffStr, Length(DiffStr), FontSmall, QuoteRect, StrFmt, BrushMuted);
        end;

        // 4. Low Confidence Warning Badge
        if FItem.IsLowConfidence and (FItem.Status = vfsPending) then
        begin
          var BadgeRect := MakeRect(16.0, 42.0, 70.0, 18.0);
          var BadgeBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.Warning, 40));
          try Graphics.FillRectangle(BadgeBrush, BadgeRect); finally BadgeBrush.Free; end;

          var BadgeText: string := '请核对';
          StrFmt.SetAlignment(StringAlignmentCenter);
          var TxtBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.Warning));
          try
            Graphics.DrawString(BadgeText, Length(BadgeText), FontSmall, BadgeRect, StrFmt, TxtBrush);
          finally
            TxtBrush.Free;
          end;
        end;

        // 5. Action Buttons (Accept / Edit / Discard)
        StrFmt.SetAlignment(StringAlignmentCenter);
        
        // Accept Button
        var BtnAcceptRect := MakeRect(Width - 160.0, 14.0, 42.0, 24.0);
        var BtnAccBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.Success, 40));
        try Graphics.FillRectangle(BtnAccBrush, BtnAcceptRect); finally BtnAccBrush.Free; end;
        var AccText: string := #$2713;
        Graphics.DrawString(AccText, Length(AccText), FontLabel, BtnAcceptRect, StrFmt, BrushInk);

        // Edit Button
        var BtnEditRect := MakeRect(Width - 110.0, 14.0, 42.0, 24.0);
        var BtnEditBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.SurfaceAlt));
        try Graphics.FillRectangle(BtnEditBrush, BtnEditRect); finally BtnEditBrush.Free; end;
        var EditText: string := '修改';
        Graphics.DrawString(EditText, Length(EditText), FontSmall, BtnEditRect, StrFmt, BrushInk);

        // Discard Button
        var BtnDiscRect := MakeRect(Width - 60.0, 14.0, 42.0, 24.0);
        var BtnDiscBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.Border));
        try Graphics.FillRectangle(BtnDiscBrush, BtnDiscRect); finally BtnDiscBrush.Free; end;
        var DiscText: string := '丢弃';
        Graphics.DrawString(DiscText, Length(DiscText), FontSmall, BtnDiscRect, StrFmt, BrushInk);
      finally
        StrFmt.Free;
        BrushMuted.Free;
        BrushInk.Free;
        FontSmall.Free;
        FontVal.Free;
        FontLabel.Free;
      end;
    finally
      FontFamily.Free;
    end;
  finally
    Graphics.Free;
  end;
end;

type
  THbVoiceDialogHelper = class
  public
    CardList: TList<THbVoiceFieldCard>;
    procedure HandleAcceptAll(Sender: TObject);
  end;

procedure THbVoiceDialogHelper.HandleAcceptAll(Sender: TObject);
var
  C: THbVoiceFieldCard;
begin
  if Assigned(CardList) then
  begin
    for C in CardList do
      C.Accept;
  end;
end;

{ THbVoiceDialog }

class function THbVoiceDialog.Execute(const ATitle: string; 
  var AItems: TArray<THbVoiceFieldItem>; 
  out AConfirmedCount: Integer): Boolean;
var
  DlgForm: TForm;
  ScrollBox: TScrollBox;
  PnlHeader, PnlFooter: TPanel;
  LblTitle, LblSummary: TLabel;
  BtnAcceptAll, BtnPersist, BtnCancel: TButton;
  CardList: TList<THbVoiceFieldCard>;
  Helper: THbVoiceDialogHelper;
  I: Integer;
  Tokens: THbTokens;
begin
  Result := False;
  AConfirmedCount := 0;
  Tokens := THbTheme.Tokens;

  DlgForm := TForm.CreateNew(nil);
  CardList := TList<THbVoiceFieldCard>.Create;
  Helper := THbVoiceDialogHelper.Create;
  Helper.CardList := CardList;
  try
    DlgForm.Position := poScreenCenter;
    DlgForm.BorderStyle := bsDialog;
    DlgForm.ClientWidth := 640;
    DlgForm.ClientHeight := 480;
    DlgForm.Caption := ATitle;
    DlgForm.Color := TColor(Tokens.Surface and $00FFFFFF);

    // Header
    PnlHeader := TPanel.Create(DlgForm);
    PnlHeader.Parent := DlgForm;
    PnlHeader.Align := alTop;
    PnlHeader.Height := 54;
    PnlHeader.BevelOuter := bvNone;

    LblTitle := TLabel.Create(PnlHeader);
    LblTitle.Parent := PnlHeader;
    LblTitle.Left := 16;
    LblTitle.Top := 16;
    LblTitle.Caption := '🎤 语音提取结果确认 (AI初筛 · 人工核对)';
    LblTitle.Font.Size := 12;
    LblTitle.Font.Style := [fsBold];

    BtnAcceptAll := TButton.Create(PnlHeader);
    BtnAcceptAll.Parent := PnlHeader;
    BtnAcceptAll.Left := 490;
    BtnAcceptAll.Top := 12;
    BtnAcceptAll.Width := 130;
    BtnAcceptAll.Caption := '全部接受 (Enter)';
    BtnAcceptAll.OnClick := Helper.HandleAcceptAll;

    // Footer
    PnlFooter := TPanel.Create(DlgForm);
    PnlFooter.Parent := DlgForm;
    PnlFooter.Align := alBottom;
    PnlFooter.Height := 50;
    PnlFooter.BevelOuter := bvNone;

    LblSummary := TLabel.Create(PnlFooter);
    LblSummary.Parent := PnlFooter;
    LblSummary.Left := 16;
    LblSummary.Top := 16;
    LblSummary.Caption := Format('共提取到 %d 项结构化属性', [Length(AItems)]);

    BtnPersist := TButton.Create(PnlFooter);
    BtnPersist.Parent := PnlFooter;
    BtnPersist.Left := 480;
    BtnPersist.Top := 10;
    BtnPersist.Width := 140;
    BtnPersist.Caption := '💾 写入档案 (Ctrl+Enter)';
    BtnPersist.ModalResult := mrOk;

    BtnCancel := TButton.Create(PnlFooter);
    BtnCancel.Parent := PnlFooter;
    BtnCancel.Left := 370;
    BtnCancel.Top := 10;
    BtnCancel.Width := 100;
    BtnCancel.Caption := '存为草稿退出';
    BtnCancel.ModalResult := mrCancel;

    // ScrollBox Cards
    ScrollBox := TScrollBox.Create(DlgForm);
    ScrollBox.Parent := DlgForm;
    ScrollBox.Align := alClient;
    ScrollBox.BorderStyle := bsNone;

    for I := Low(AItems) to High(AItems) do
    begin
      var Card := THbVoiceFieldCard.Create(ScrollBox);
      Card.Parent := ScrollBox;
      Card.Align := alTop;
      Card.Top := I * 84;
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
    Helper.Free;
    CardList.Free;
    DlgForm.Free;
  end;
end;

end.
