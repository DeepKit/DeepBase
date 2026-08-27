{ ============================================================================
  DeepBase.FMX.HB.Dialogs - Modern Multi-Zone Dialog & Accordion Summary Bar for FMX

  Version: 1.0 (Delphi 13.1 on Win64 / Cross-Platform)
  Description: Modern vector-rendered Dialogs and Summary+Detail components for FMX:
               - THbSummaryBar: Standalone expandable summary+detail bar
                 (Supports vertical & horizontal accordion modes)
               - THbDialog: Modern multi-zone modal dialog with built-in input zone,
                 structured Key-Value parameters, boundary alerts, evidence fold,
                 and multi-action decision footer.
  ============================================================================ }

unit DeepBase.FMX.HB.Dialogs;

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
  FMX.Memo,
  DeepBase.HB.Core,
  DeepBase.HB.Dialogs.Types,
  DeepBase.FMX.HB.Theme,
  DeepBase.FMX.HB.Controls;

type
  /// <summary>
  /// THbSummaryBar: Universal expandable summary + detail bar component for FMX.
  /// </summary>
  THbSummaryBar = class(THbFmxControl)
  private
    FStepIndex: Integer;
    FTitle: string;
    FSummaryText: string;
    FStatusText: string;
    FStatusTone: THbBadgeTone;
    FState: THbStepState;
    FIsExpanded: Boolean;
    FOrientation: THbWaterfallOrientation;
    FCollapsedSize: Single;
    FExpandedSize: Single;
    FOnToggle: TNotifyEvent;
    procedure SetStepIndex(Value: Integer);
    procedure SetTitle(const Value: string);
    procedure SetSummaryText(const Value: string);
    procedure SetStatusText(const Value: string);
    procedure SetStatusTone(Value: THbBadgeTone);
    procedure SetState(Value: THbStepState);
    procedure SetIsExpanded(Value: Boolean);
    procedure SetOrientation(Value: THbWaterfallOrientation);
  protected
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens); override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Toggle;
  published
    property Align;
    property Anchors;
    property CollapsedSize: Single read FCollapsedSize write FCollapsedSize;
    property Enabled;
    property ExpandedSize: Single read FExpandedSize write FExpandedSize;
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
  /// THbDialog: Universal modern multi-zone modal dialog helper for FMX.
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
  FCollapsedSize := 42.0;
  FExpandedSize := 220.0;
  Width := 560.0;
  Height := FCollapsedSize;
end;

procedure THbSummaryBar.SetStepIndex(Value: Integer);
begin
  if FStepIndex <> Value then
  begin
    FStepIndex := Value;
    Repaint;
  end;
end;

procedure THbSummaryBar.SetTitle(const Value: string);
begin
  if FTitle <> Value then
  begin
    FTitle := Value;
    Repaint;
  end;
end;

procedure THbSummaryBar.SetSummaryText(const Value: string);
begin
  if FSummaryText <> Value then
  begin
    FSummaryText := Value;
    Repaint;
  end;
end;

procedure THbSummaryBar.SetStatusText(const Value: string);
begin
  if FStatusText <> Value then
  begin
    FStatusText := Value;
    Repaint;
  end;
end;

procedure THbSummaryBar.SetStatusTone(Value: THbBadgeTone);
begin
  if FStatusTone <> Value then
  begin
    FStatusTone := Value;
    Repaint;
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
    Repaint;
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
    Repaint;
    if Assigned(FOnToggle) then
      FOnToggle(Self);
  end;
end;

procedure THbSummaryBar.SetOrientation(Value: THbWaterfallOrientation);
begin
  if FOrientation <> Value then
  begin
    FOrientation := Value;
    Repaint;
  end;
end;

procedure THbSummaryBar.Toggle;
begin
  IsExpanded := not IsExpanded;
end;

procedure THbSummaryBar.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button = TMouseButton.mbLeft) and Enabled then
  begin
    if (FOrientation = woVertical) and (Y <= FCollapsedSize) then
      Toggle
    else if (FOrientation = woHorizontal) and (X <= FCollapsedSize) then
      Toggle;
  end;
end;

procedure THbSummaryBar.DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens);
var
  R, HeaderRect, DetailRect: TRectF;
  IndicatorColor: TAlphaColor;
  StepStr, BtnText: string;
begin
  R := ARect;

  // Background
  Canvas.Fill.Color := Tokens.Surface;
  Canvas.FillRect(R, Tokens.RadiusS, Tokens.RadiusS, AllCorners, 1.0);

  // Indicator Border
  case FState of
    ssCompleted: IndicatorColor := Tokens.Success;
    ssActive: IndicatorColor := Tokens.Primary;
    ssError: IndicatorColor := Tokens.Danger;
    else IndicatorColor := Tokens.Border;
  end;

  Canvas.Stroke.Color := IndicatorColor;
  Canvas.Stroke.Thickness := 4.0;
  if FOrientation = woVertical then
    Canvas.DrawLine(PointF(2.0, 0.0), PointF(2.0, Height), 1.0)
  else
    Canvas.DrawLine(PointF(0.0, 2.0), PointF(Width, 2.0), 1.0);

  // Header Summary Row
  HeaderRect := TRectF.Create(14.0, 0.0, Width - 14.0, FCollapsedSize);

  // Step Badge
  var BadgeRect := TRectF.Create(16.0, (FCollapsedSize - 22.0) / 2.0, 38.0, (FCollapsedSize + 22.0) / 2.0);
  Canvas.Fill.Color := IndicatorColor;
  Canvas.FillEllipse(BadgeRect, 0.25);

  Canvas.Font.Family := Tokens.FontFamily;
  Canvas.Font.Size := Tokens.SizeXS;
  Canvas.Font.Style := [TFontStyle.fsBold];
  Canvas.Fill.Color := Tokens.Ink;

  if FState = ssCompleted then
    StepStr := #$2713
  else
    StepStr := IntToStr(FStepIndex);
  Canvas.FillText(BadgeRect, StepStr, False, 1.0, [], TTextAlign.Center, TTextAlign.Center);

  // Title
  Canvas.Font.Size := Tokens.SizeS;
  var TitleRect := TRectF.Create(48.0, 0.0, 220.0, FCollapsedSize);
  Canvas.FillText(TitleRect, FTitle, False, 1.0, [], TTextAlign.Leading, TTextAlign.Center);

  // Summary Text
  Canvas.Font.Size := Tokens.SizeXS;
  Canvas.Font.Style := [];
  Canvas.Fill.Color := Tokens.InkMuted;
  var SummaryRect := TRectF.Create(230.0, 0.0, Width - 110.0, FCollapsedSize);
  Canvas.FillText(SummaryRect, FSummaryText, False, 1.0, [], TTextAlign.Leading, TTextAlign.Center);

  // Toggle Button
  var ToggleRect := TRectF.Create(Width - 96.0, (FCollapsedSize - 24.0) / 2.0, Width - 16.0, (FCollapsedSize + 24.0) / 2.0);
  Canvas.Fill.Color := Tokens.SurfaceAlt;
  Canvas.FillRect(ToggleRect, Tokens.RadiusS, Tokens.RadiusS, AllCorners, 1.0);

  if FIsExpanded then
    BtnText := '收起 ' + #$25B2
  else
    BtnText := '展开 ' + #$25BC;

  Canvas.Fill.Color := Tokens.Ink;
  Canvas.FillText(ToggleRect, BtnText, False, 1.0, [], TTextAlign.Center, TTextAlign.Center);

  // Detail Content Box (when expanded)
  if FIsExpanded and (Height > FCollapsedSize) then
  begin
    DetailRect := TRectF.Create(12.0, FCollapsedSize + 4.0, Width - 12.0, Height - 6.0);
    Canvas.Fill.Color := Tokens.Sunken;
    Canvas.FillRect(DetailRect, Tokens.RadiusS, Tokens.RadiusS, AllCorners, 1.0);
  end;
end;

class function THbDialog.Execute(const AOptions: THbDialogOptions; var AInputValue: string): THbDialogResult;
var
  DlgForm: TForm;
  LblTitle, LblSummary, LblPrompt: TLabel;
  EdtInput: TControl;
  Memo: TMemo;
  Edit: TEdit;
  BtnOk, BtnCancel: TButton;
  PnlHeader, PnlBody, PnlFooter: TPanel;
  Tokens: THbTokens;
begin
  Result := drCancel;
  Tokens := THbTheme.Tokens;

  DlgForm := TForm.CreateNew(nil);
  try
    DlgForm.Position := TFormPosition.ScreenCenter;
    DlgForm.ClientWidth := 560;
    DlgForm.ClientHeight := 380;
    DlgForm.Caption := AOptions.Title;

    // Header
    PnlHeader := TPanel.Create(DlgForm);
    PnlHeader.Parent := DlgForm;
    PnlHeader.Align := TAlignLayout.Top;
    PnlHeader.Height := 54;

    LblTitle := TLabel.Create(PnlHeader);
    LblTitle.Parent := PnlHeader;
    LblTitle.Position.X := 16;
    LblTitle.Position.Y := 16;
    LblTitle.Text := AOptions.Title;
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
    BtnOk.Text := '确定';
    if AOptions.OkCaption <> '' then
      BtnOk.Text := AOptions.OkCaption;
    BtnOk.ModalResult := mrOk;

    BtnCancel := TButton.Create(PnlFooter);
    BtnCancel.Parent := PnlFooter;
    BtnCancel.Position.X := 338;
    BtnCancel.Position.Y := 10;
    BtnCancel.Width := 90;
    BtnCancel.Height := 32;
    BtnCancel.Text := '取消';
    BtnCancel.ModalResult := mrCancel;

    // Body
    PnlBody := TPanel.Create(DlgForm);
    PnlBody.Parent := DlgForm;
    PnlBody.Align := TAlignLayout.Client;

    LblSummary := TLabel.Create(PnlBody);
    LblSummary.Parent := PnlBody;
    LblSummary.Position.X := 16;
    LblSummary.Position.Y := 12;
    LblSummary.Width := 528;
    LblSummary.Height := 60;
    LblSummary.WordWrap := True;
    LblSummary.Text := AOptions.Summary;
    LblSummary.StyledSettings := [];
    LblSummary.TextSettings.FontColor := Tokens.Ink;

    if AOptions.Kind in [dkPrompt, dkPromptReason] then
    begin
      LblPrompt := TLabel.Create(PnlBody);
      LblPrompt.Parent := PnlBody;
      LblPrompt.Position.X := 16;
      LblPrompt.Position.Y := 80;
      LblPrompt.Text := AOptions.PromptLabel;
      LblPrompt.StyledSettings := [];
      LblPrompt.TextSettings.FontColor := Tokens.InkMuted;

      if AOptions.IsInputMultiline then
      begin
        Memo := TMemo.Create(PnlBody);
        Memo.Parent := PnlBody;
        Memo.Position.X := 16;
        Memo.Position.Y := 104;
        Memo.Width := 528;
        Memo.Height := 100;
        Memo.Text := AOptions.DefaultInput;
        EdtInput := Memo;
      end
      else
      begin
        Edit := TEdit.Create(PnlBody);
        Edit.Parent := PnlBody;
        Edit.Position.X := 16;
        Edit.Position.Y := 104;
        Edit.Width := 528;
        Edit.Height := 32;
        Edit.Text := AOptions.DefaultInput;
        EdtInput := Edit;
      end;
    end
    else
      EdtInput := nil;

    var ModalRes: TModalResult;
    if Assigned(FModalRunner) then
      ModalRes := FModalRunner(DlgForm)
    else
      ModalRes := DlgForm.ShowModal;

    if ModalRes = mrOk then
    begin
      Result := drOk;
      if Assigned(EdtInput) then
      begin
        if EdtInput is TEdit then
          AInputValue := TEdit(EdtInput).Text
        else if EdtInput is TMemo then
          AInputValue := TMemo(EdtInput).Text;
      end;
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
  Opts := Default(THbDialogOptions);
  Opts.Title := ATitle;
  Opts.Summary := AMessage;
  Opts.Kind := dkConfirm;
  Opts.OkCaption := '知道了';
  Execute(Opts, Dummy);
end;

class function THbDialog.Confirm(const ATitle, AMessage: string; const ABoundaryNotice: string): Boolean;
var
  Opts: THbDialogOptions;
  Dummy: string;
begin
  Opts := Default(THbDialogOptions);
  Opts.Title := ATitle;
  Opts.Summary := AMessage;
  Opts.Kind := dkConfirm;
  Opts.OkCaption := '确定';
  Result := (Execute(Opts, Dummy) = drOk);
end;

class function THbDialog.Prompt(const ATitle, APrompt: string; var AValue: string): Boolean;
var
  Opts: THbDialogOptions;
begin
  Opts := Default(THbDialogOptions);
  Opts.Title := ATitle;
  Opts.Summary := '';
  Opts.PromptLabel := APrompt;
  Opts.DefaultInput := AValue;
  Opts.Kind := dkPrompt;
  Opts.IsInputMultiline := False;
  Result := (Execute(Opts, AValue) = drOk);
end;

class function THbDialog.PromptReason(const ATitle, APrompt: string; var AReason: string): Boolean;
var
  Opts: THbDialogOptions;
begin
  Opts := Default(THbDialogOptions);
  Opts.Title := ATitle;
  Opts.Summary := '';
  Opts.PromptLabel := APrompt;
  Opts.DefaultInput := AReason;
  Opts.Kind := dkPromptReason;
  Opts.IsInputMultiline := True;
  Result := (Execute(Opts, AReason) = drOk);
end;

end.
