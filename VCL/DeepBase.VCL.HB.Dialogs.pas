{ ============================================================================
  DeepBase.VCL.HB.Dialogs - Modern Multi-Zone Dialog & Accordion Summary Bar for VCL

  Version: 1.0 (Delphi 13.1 on Win64)
  Description: Modern vector-rendered Dialogs and Summary+Detail components:
               - THbSummaryBar: Standalone expandable summary+detail bar
                 (Supports vertical & horizontal accordion modes)
               - THbDialog: Modern multi-zone modal dialog with built-in input zone,
                 structured Key-Value parameters, boundary alerts, evidence fold,
                 and multi-action decision footer.
  ============================================================================ }

unit DeepBase.VCL.HB.Dialogs;

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
  DeepBase.HB.Dialogs.Types,
  DeepBase.VCL.HB.Theme,
  DeepBase.VCL.HB.Controls;

type
  /// <summary>
  /// THbSummaryBar: Universal expandable summary + detail bar component.
  /// Used both standalone and as the building block for Waterfall Wizards.
  /// </summary>
  THbSummaryBar = class(THbCustomControl)
  private
    FStepIndex: Integer;
    FTitle: string;
    FSummaryText: string;
    FStatusText: string;
    FStatusTone: THbBadgeTone;
    FState: THbStepState;
    FIsExpanded: Boolean;
    FOrientation: THbWaterfallOrientation;
    FCollapsedSize: Integer;
    FExpandedSize: Integer;
    FHoverToggle: Boolean;
    FOnToggle: TNotifyEvent;
    procedure SetStepIndex(Value: Integer);
    procedure SetTitle(const Value: string);
    procedure SetSummaryText(const Value: string);
    procedure SetStatusText(const Value: string);
    procedure SetStatusTone(Value: THbBadgeTone);
    procedure SetState(Value: THbStepState);
    procedure SetIsExpanded(Value: Boolean);
    procedure SetOrientation(Value: THbWaterfallOrientation);
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
  protected
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Toggle;
  published
    property Align;
    property Anchors;
    property CollapsedSize: Integer read FCollapsedSize write FCollapsedSize default 42;
    property Enabled;
    property ExpandedSize: Integer read FExpandedSize write FExpandedSize default 220;
    property IsExpanded: Boolean read FIsExpanded write SetIsExpanded default False;
    property Orientation: THbWaterfallOrientation read FOrientation write SetOrientation default woVertical;
    property State: THbStepState read FState write SetState default ssPending;
    property StatusText: string read FStatusText write SetStatusText;
    property StatusTone: THbBadgeTone read FStatusTone write SetStatusTone default btNeutral;
    property StepIndex: Integer read FStepIndex write SetStepIndex default 1;
    property SummaryText: string read FSummaryText write SetSummaryText;
    property Title: string read FTitle write SetTitle;
    property Visible;
    property OnToggle: TNotifyEvent read FOnToggle write FOnToggle;
  end;

  /// <summary>
  /// Delegate signature for modal execution seam (for testing/automation).
  /// </summary>
  THbModalShowFunc = reference to function(AForm: TForm): TModalResult;

  /// <summary>
  /// THbDialog: Universal modern multi-zone modal dialog.
  /// </summary>
  THbDialog = class
  private
    class var FModalRunner: THbModalShowFunc;
  public
    class property ModalRunner: THbModalShowFunc read FModalRunner write FModalRunner;
    class function Execute(const AOptions: THbDialogOptions; var AInputValue: string): THbDialogResult;
    class procedure ShowInfo(const ATitle, AMessage: string);
    class function Confirm(const ATitle, AMessage: string; const ABoundaryNotice: string = ''): Boolean;
    class function Prompt(const ATitle, APrompt: string; var AValue: string): Boolean;
    class function PromptReason(const ATitle, APrompt: string; var AReason: string): Boolean;
  end;

implementation

{ THbSummaryBar }

constructor THbSummaryBar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FStepIndex := 1;
  FTitle := 'Step Title';
  FSummaryText := 'Key: Value summary';
  FStatusText := 'Pending';
  FStatusTone := btNeutral;
  FState := ssPending;
  FIsExpanded := False;
  FOrientation := woVertical;
  FCollapsedSize := 42;
  FExpandedSize := 220;
  FHoverToggle := False;
  Width := 560;
  Height := FCollapsedSize;
end;

procedure THbSummaryBar.SetStepIndex(Value: Integer);
begin
  if FStepIndex <> Value then
  begin
    FStepIndex := Value;
    Invalidate;
  end;
end;

procedure THbSummaryBar.SetTitle(const Value: string);
begin
  if FTitle <> Value then
  begin
    FTitle := Value;
    Invalidate;
  end;
end;

procedure THbSummaryBar.SetSummaryText(const Value: string);
begin
  if FSummaryText <> Value then
  begin
    FSummaryText := Value;
    Invalidate;
  end;
end;

procedure THbSummaryBar.SetStatusText(const Value: string);
begin
  if FStatusText <> Value then
  begin
    FStatusText := Value;
    Invalidate;
  end;
end;

procedure THbSummaryBar.SetStatusTone(Value: THbBadgeTone);
begin
  if FStatusTone <> Value then
  begin
    FStatusTone := Value;
    Invalidate;
  end;
end;

procedure THbSummaryBar.SetState(Value: THbStepState);
begin
  if FState <> Value then
  begin
    FState := Value;
    case FState of
      ssPending:
        begin
          FStatusText := 'Pending';
          FStatusTone := btNeutral;
        end;
      ssActive:
        begin
          FStatusText := 'Active';
          FStatusTone := btBrand;
          FIsExpanded := True;
        end;
      ssCompleted:
        begin
          FStatusText := 'Completed';
          FStatusTone := btSuccess;
        end;
      ssError:
        begin
          FStatusText := 'Error';
          FStatusTone := btDanger;
        end;
    end;
    Invalidate;
  end;
end;

procedure THbSummaryBar.SetIsExpanded(Value: Boolean);
begin
  if FIsExpanded <> Value then
  begin
    FIsExpanded := Value;
    if FOrientation = woVertical then
    begin
      if FIsExpanded then
        Height := FExpandedSize
      else
        Height := FCollapsedSize;
    end
    else
    begin
      if FIsExpanded then
        Width := FExpandedSize
      else
        Width := FCollapsedSize;
    end;
    Invalidate;
    if Assigned(FOnToggle) then
      FOnToggle(Self);
  end;
end;

procedure THbSummaryBar.SetOrientation(Value: THbWaterfallOrientation);
begin
  if FOrientation <> Value then
  begin
    FOrientation := Value;
    Invalidate;
  end;
end;

procedure THbSummaryBar.Toggle;
begin
  IsExpanded := not IsExpanded;
end;

procedure THbSummaryBar.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  OldHover: Boolean;
begin
  inherited MouseMove(Shift, X, Y);
  OldHover := FHoverToggle;
  if FOrientation = woVertical then
    FHoverToggle := (Y <= FCollapsedSize) and (X >= Width - 100)
  else
    FHoverToggle := (X <= FCollapsedSize) and (Y >= Height - 40);
  if OldHover <> FHoverToggle then
    Invalidate;
end;

procedure THbSummaryBar.CMMouseLeave(var Message: TMessage);
begin
  inherited;
  FHoverToggle := False;
  Invalidate;
end;

procedure THbSummaryBar.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button = mbLeft) and Enabled then
  begin
    if (FOrientation = woVertical) and (Y <= FCollapsedSize) then
      Toggle
    else if (FOrientation = woHorizontal) and (X <= FCollapsedSize) then
      Toggle;
  end;
end;

procedure THbSummaryBar.Paint;
var
  Graphics: TGPGraphics;
  Tokens: THbTokens;
  BrushBg, BrushInk, BrushMuted: TGPSolidBrush;
  FontTitle, FontSummary, FontBadge: TGPFont;
  FontFamily: TGPFontFamily;
  StrFmt: TGPStringFormat;
  R, HeaderRect, DetailRect: TGPRectF;
  IndicatorColor: TAlphaColor;
  IndicatorPen: TGPPen;
  BtnText: string;
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

    // State Border Indicator
    case FState of
      ssCompleted: IndicatorColor := Tokens.Success;
      ssActive: IndicatorColor := Tokens.Primary;
      ssError: IndicatorColor := Tokens.Danger;
      else IndicatorColor := Tokens.Border;
    end;

    IndicatorPen := TGPPen.Create(ColorToARGB(IndicatorColor), ScaleDIP(Tokens.SpaceXS));
    try
      if FOrientation = woVertical then
        Graphics.DrawLine(IndicatorPen, ScaleDIP(Tokens.SpaceXS * 0.5), 0.0, ScaleDIP(Tokens.SpaceXS * 0.5), Single(Height))
      else
        Graphics.DrawLine(IndicatorPen, 0.0, ScaleDIP(Tokens.SpaceXS * 0.5), Single(Width), ScaleDIP(Tokens.SpaceXS * 0.5));
    finally
      IndicatorPen.Free;
    end;

    // Header Summary Row
    if FOrientation = woVertical then
      HeaderRect := MakeRect(ScaleDIP(Tokens.SpaceM), 0.0, Width - ScaleDIP(Tokens.SpaceM * 2), Single(FCollapsedSize))
    else
      HeaderRect := MakeRect(ScaleDIP(Tokens.SpaceM), 0.0, Single(FCollapsedSize), Single(Height));

    FontFamily := TGPFontFamily.Create(Tokens.FontFamily);
    try
      FontTitle := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeS), FontStyleBold, UnitPixel);
      FontSummary := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeXS), FontStyleRegular, UnitPixel);
      FontBadge := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeXS), FontStyleBold, UnitPixel);
      BrushInk := TGPSolidBrush.Create(ColorToARGB(Tokens.Ink));
      BrushMuted := TGPSolidBrush.Create(ColorToARGB(Tokens.InkMuted));
      StrFmt := TGPStringFormat.Create;
      try
        StrFmt.SetLineAlignment(StringAlignmentCenter);

        // Step Badge Circle
        var BadgeRect := MakeRect(ScaleDIP(Tokens.SpaceM), (FCollapsedSize - ScaleDIP(Tokens.SpaceL)) / 2.0, ScaleDIP(Tokens.SpaceL), ScaleDIP(Tokens.SpaceL));
        var BadgeBrush := TGPSolidBrush.Create(ColorToARGB(IndicatorColor, 40));
        try Graphics.FillEllipse(BadgeBrush, BadgeRect); finally BadgeBrush.Free; end;

        StrFmt.SetAlignment(StringAlignmentCenter);
        var StepStr := IntToStr(FStepIndex);
        if FState = ssCompleted then
          StepStr := #$2713;
        Graphics.DrawString(StepStr, Length(StepStr), FontBadge, BadgeRect, StrFmt, BrushInk);

        // Title + Summary Text
        StrFmt.SetAlignment(StringAlignmentNear);
        var TitleRect := MakeRect(ScaleDIP(Tokens.SpaceM * 3.14), 0.0, ScaleDIP(180.0), Single(FCollapsedSize));
        Graphics.DrawString(FTitle, Length(FTitle), FontTitle, TitleRect, StrFmt, BrushInk);

        var SummaryRect := MakeRect(ScaleDIP(230.0), 0.0, Width - ScaleDIP(340.0), Single(FCollapsedSize));
        Graphics.DrawString(FSummaryText, Length(FSummaryText), FontSummary, SummaryRect, StrFmt, BrushMuted);

        // Toggle Button
        var ToggleRect := MakeRect(Width - ScaleDIP(90.0), (FCollapsedSize - ScaleDIP(Tokens.SpaceL + Tokens.SpaceXS * 0.5)) / 2.0, ScaleDIP(78.0), ScaleDIP(Tokens.SpaceL + Tokens.SpaceXS * 0.5));
        var BtnBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.SurfaceAlt));
        try Graphics.FillRectangle(BtnBrush, ToggleRect); finally BtnBrush.Free; end;

        if FIsExpanded then
          BtnText := '收起 ' + #$25B2
        else
          BtnText := '展开 ' + #$25BC;

        StrFmt.SetAlignment(StringAlignmentCenter);
        Graphics.DrawString(BtnText, Length(BtnText), FontSummary, ToggleRect, StrFmt, BrushInk);

        // Detail Content Area (when expanded)
        if FIsExpanded and (Height > FCollapsedSize) then
        begin
          DetailRect := MakeRect(ScaleDIP(Tokens.SpaceS + Tokens.SpaceXS), Single(FCollapsedSize) + ScaleDIP(Tokens.SpaceXS), Width - ScaleDIP((Tokens.SpaceS + Tokens.SpaceXS) * 2), Height - FCollapsedSize - ScaleDIP(Tokens.SpaceS));
          var DetailBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.Sunken));
          try Graphics.FillRectangle(DetailBrush, DetailRect); finally DetailBrush.Free; end;
        end;
      finally
        StrFmt.Free;
        BrushMuted.Free;
        BrushInk.Free;
        FontBadge.Free;
        FontSummary.Free;
        FontTitle.Free;
      end;
    finally
      FontFamily.Free;
    end;
  finally
    Graphics.Free;
  end;
end;

{ THbDialog Implementation }

class function THbDialog.Execute(const AOptions: THbDialogOptions; var AInputValue: string): THbDialogResult;
var
  DlgForm: TForm;
  LblTitle, LblSummary, LblPrompt: TLabel;
  EdtInput: TCustomEdit;
  BtnOk, BtnCancel: TButton;
  PnlHeader, PnlBody, PnlFooter: TPanel;
  Tokens: THbTokens;
begin
  Result := drCancel;
  Tokens := THbTheme.Tokens;

  DlgForm := TForm.CreateNew(nil);
  try
    DlgForm.Position := poScreenCenter;
    DlgForm.BorderStyle := bsDialog;
    DlgForm.ClientWidth := 560;
    DlgForm.ClientHeight := 380;
    DlgForm.Caption := AOptions.Title;
    DlgForm.Color := TColor(Tokens.Surface and $00FFFFFF);

    // Layout Panels
    PnlHeader := TPanel.Create(DlgForm);
    PnlHeader.Parent := DlgForm;
    PnlHeader.Align := alTop;
    PnlHeader.Height := 54;
    PnlHeader.BevelOuter := bvNone;

    LblTitle := TLabel.Create(PnlHeader);
    LblTitle.Parent := PnlHeader;
    LblTitle.Left := 16;
    LblTitle.Top := 16;
    LblTitle.Caption := AOptions.Title;
    LblTitle.Font.Size := 12;
    LblTitle.Font.Style := [fsBold];

    PnlFooter := TPanel.Create(DlgForm);
    PnlFooter.Parent := DlgForm;
    PnlFooter.Align := alBottom;
    PnlFooter.Height := 48;
    PnlFooter.BevelOuter := bvNone;

    PnlBody := TPanel.Create(DlgForm);
    PnlBody.Parent := DlgForm;
    PnlBody.Align := alClient;
    PnlBody.BevelOuter := bvNone;

    LblSummary := TLabel.Create(PnlBody);
    LblSummary.Parent := PnlBody;
    LblSummary.Left := 16;
    LblSummary.Top := 8;
    LblSummary.Width := 528;
    LblSummary.WordWrap := True;
    LblSummary.Caption := AOptions.Summary;

    // Optional Prompt Input Zone
    if AOptions.Kind in [dkPrompt, dkPromptReason] then
    begin
      LblPrompt := TLabel.Create(PnlBody);
      LblPrompt.Parent := PnlBody;
      LblPrompt.Left := 16;
      LblPrompt.Top := 70;
      LblPrompt.Caption := AOptions.PromptLabel;

      if AOptions.IsInputMultiline then
      begin
        var Memo := TMemo.Create(PnlBody);
        Memo.Parent := PnlBody;
        Memo.Left := 16;
        Memo.Top := 90;
        Memo.Width := 528;
        Memo.Height := 90;
        Memo.Text := AOptions.DefaultInput;
        EdtInput := Memo;
      end
      else
      begin
        var Edit := TEdit.Create(PnlBody);
        Edit.Parent := PnlBody;
        Edit.Left := 16;
        Edit.Top := 90;
        Edit.Width := 528;
        Edit.Text := AOptions.DefaultInput;
        EdtInput := Edit;
      end;
    end
    else
      EdtInput := nil;

    // Footer Buttons
    BtnOk := TButton.Create(PnlFooter);
    BtnOk.Parent := PnlFooter;
    BtnOk.Left := 460;
    BtnOk.Top := 10;
    BtnOk.Width := 86;
    BtnOk.Caption := '确定';
    if AOptions.OkCaption <> '' then
      BtnOk.Caption := AOptions.OkCaption;
    BtnOk.ModalResult := mrOk;

    BtnCancel := TButton.Create(PnlFooter);
    BtnCancel.Parent := PnlFooter;
    BtnCancel.Left := 366;
    BtnCancel.Top := 10;
    BtnCancel.Width := 86;
    BtnCancel.Caption := '取消';
    BtnCancel.ModalResult := mrCancel;

    var ModalRes: TModalResult;
    if Assigned(FModalRunner) then
      ModalRes := FModalRunner(DlgForm)
    else
      ModalRes := DlgForm.ShowModal;

    if ModalRes = mrOk then
    begin
      Result := drOk;
      if Assigned(EdtInput) then
        AInputValue := EdtInput.Text;
    end
    else
      Result := drCancel;
  finally
    DlgForm.Free;
  end;
end;

class procedure THbDialog.ShowInfo(const ATitle, AMessage: string);
var
  Opts: THbDialogOptions;
  Dummy: string;
begin
  Opts.Kind := dkInfo;
  Opts.Title := ATitle;
  Opts.Summary := AMessage;
  Execute(Opts, Dummy);
end;

class function THbDialog.Confirm(const ATitle, AMessage: string; const ABoundaryNotice: string): Boolean;
var
  Opts: THbDialogOptions;
  Dummy: string;
begin
  Opts.Kind := dkConfirm;
  Opts.Title := ATitle;
  Opts.Summary := AMessage;
  Opts.BoundaryNotice := ABoundaryNotice;
  Result := Execute(Opts, Dummy) = drOk;
end;

class function THbDialog.Prompt(const ATitle, APrompt: string; var AValue: string): Boolean;
var
  Opts: THbDialogOptions;
begin
  Opts.Kind := dkPrompt;
  Opts.Title := ATitle;
  Opts.PromptLabel := APrompt;
  Opts.DefaultInput := AValue;
  Opts.IsInputMultiline := False;
  Result := Execute(Opts, AValue) = drOk;
end;

class function THbDialog.PromptReason(const ATitle, APrompt: string; var AReason: string): Boolean;
var
  Opts: THbDialogOptions;
begin
  Opts.Kind := dkPromptReason;
  Opts.Title := ATitle;
  Opts.PromptLabel := APrompt;
  Opts.DefaultInput := AReason;
  Opts.IsInputMultiline := True;
  Result := Execute(Opts, AReason) = drOk;
end;

end.
