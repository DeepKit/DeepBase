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

{$WARN IMPLICIT_STRING_CAST OFF}
{$WARN IMPLICIT_STRING_CAST_LOSS OFF}

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
  System.DateUtils,
  System.Generics.Collections,
  Vcl.Controls,
  Vcl.Graphics,
  Vcl.Forms,
  Vcl.ExtCtrls,
  Vcl.StdCtrls,
  DeepBase.HB.Core,
  DeepBase.HB.Touchpoint.Types,
  DeepBase.HB.Touchpoint.Engine,
  DeepBase.HB.Dialogs.Types,
  DeepBase.VCL.HB.Theme,
  DeepBase.VCL.HB.Controls,
  System.JSON;

type
  /// <summary>
  /// Manages multi-step wizard state, fields, and session snapshot for dialogs.
  /// </summary>
  THbDialogWizardSession = DeepBase.HB.Dialogs.Types.THbDialogWizardSession;

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
    FHoverToggle := (Y <= FCollapsedSize) and (X >= Width - ScaleDIP(100.0))
  else
    FHoverToggle := (X <= FCollapsedSize) and (Y >= Height - ScaleDIP(40.0));
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

// WO-20260926-0294 T3：THbButton 为纯自绘控件（无 ModalResult/Default 属性），
// 按钮与键盘行为经由此桥接对象转发给模态窗体。Owner 挂在 DlgForm 下，随窗体释放。
type
  TDialogModalBridge = class(TComponent)
  private
    FForm: TCustomForm;
    FResult: TModalResult;
    FEdit: TCustomEdit;
    procedure HandleClick(Sender: TObject);
    procedure HandleKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  end;

procedure TDialogModalBridge.HandleClick(Sender: TObject);
begin
  // VCL 模态语义：置 ModalResult 后由 ShowModal 循环收敛关闭；
  // 切勿调 Close（TCustomForm.Close 会无条件覆写为 mrCancel）。
  if FForm <> nil then
    FForm.ModalResult := FResult;
end;

procedure TDialogModalBridge.HandleKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if FForm = nil then
    Exit;
  if Key = VK_ESCAPE then
  begin
    FForm.ModalResult := mrCancel;
    Key := 0;
  end
  else if Key = VK_RETURN then
  begin
    // 输入框内回车保留给换行/输入，其余一律等价确认（替代 TButton.Default）。
    if FForm.ActiveControl <> FEdit then
    begin
      FForm.ModalResult := mrOk;
      Key := 0;
    end;
  end;
end;

class function THbDialog.Execute(const AOptions: THbDialogOptions; var AInputValue: string): THbDialogResult;
var
  DlgForm: TForm;
  LblTitle, LblPrompt: TLabel;
  MemSummary: TMemo;
  EdtInput: TCustomEdit;
  BtnOk, BtnCancel: THbButton;
  PnlHeader, PnlBody, PnlFooter: TPanel;
  Tokens: THbTokens;
  PPI: Integer;
  LNeedH, LBodyH: Integer;
  LBridgeOk, LBridgeCancel, LBridgeKeys: TDialogModalBridge;
  function ScalePx(AVal: Integer): Integer;
  begin
    Result := Round(AVal * (PPI / 96.0));
  end;
  // WO-20260926-0294 T2：按正文字体度量自动换行高度（位图画布离屏度量，
  // 不依赖窗体 Handle 与面板 Realign 时序，从根本上避开 153px 烘焙折行）。
  function MeasureSummaryHeight(const AText: string; AWidth: Integer): Integer;
  var
    LBmp: TBitmap;
    LRect: TRect;
  begin
    LBmp := TBitmap.Create;
    try
      LBmp.Canvas.Font.Name := Tokens.FontFamily;
      LBmp.Canvas.Font.Size := Round(Tokens.SizeS);
      LRect := Rect(0, 0, AWidth, 32767);
      if AText = '' then
        Result := 0
      else
      begin
        DrawText(LBmp.Canvas.Handle, PChar(AText), Length(AText), LRect,
          DT_CALCRECT or DT_WORDBREAK or DT_NOPREFIX or DT_EDITCONTROL);
        Result := LRect.Bottom;
      end;
    finally
      LBmp.Free;
    end;
  end;
begin
  Result := drCancel;
  Tokens := THbTheme.Tokens;

  DlgForm := TForm.CreateNew(nil);
  try
    PPI := DlgForm.PixelsPerInch;
    if PPI <= 0 then
      PPI := Screen.PixelsPerInch;
    if PPI <= 0 then
      PPI := 96;

    DlgForm.Position := poScreenCenter;
    DlgForm.BorderStyle := bsDialog;
    DlgForm.ClientWidth := ScalePx(560);
    DlgForm.ClientHeight := ScalePx(380);
    DlgForm.Caption := AOptions.Title;
    DlgForm.Color := TColor(Tokens.Surface and $00FFFFFF);

    // Layout Panels
    PnlHeader := TPanel.Create(DlgForm);
    PnlHeader.Parent := DlgForm;
    PnlHeader.Align := alTop;
    PnlHeader.Height := ScalePx(54);
    PnlHeader.BevelOuter := bvNone;
    PnlHeader.Color := TColor(Tokens.Surface and $00FFFFFF);
    PnlHeader.ParentBackground := False;

    LblTitle := TLabel.Create(PnlHeader);
    LblTitle.Parent := PnlHeader;
    LblTitle.Left := ScalePx(16);
    LblTitle.Top := ScalePx(16);
    LblTitle.Caption := AOptions.Title;
    LblTitle.Font.Name := Tokens.FontFamily;
    LblTitle.Font.Size := Round(Tokens.SizeM);
    LblTitle.Font.Style := [fsBold];
    LblTitle.Font.Color := TColor(Tokens.Ink and $00FFFFFF);

    PnlFooter := TPanel.Create(DlgForm);
    PnlFooter.Parent := DlgForm;
    PnlFooter.Align := alBottom;
    PnlFooter.Height := ScalePx(52);
    PnlFooter.BevelOuter := bvNone;
    PnlFooter.Color := TColor(Tokens.Surface and $00FFFFFF);
    PnlFooter.ParentBackground := False;

    PnlBody := TPanel.Create(DlgForm);
    PnlBody.Parent := DlgForm;
    PnlBody.Align := alClient;
    PnlBody.BevelOuter := bvNone;
    PnlBody.Color := TColor(Tokens.Surface and $00FFFFFF);
    PnlBody.ParentBackground := False;

    // WO-20260926-0294 T1/T2：正文改用全宽只读 TMemo（替代静态窄 TLabel）。
    // 根因：TLabel 在父面板尚未 Realign（宽 185）时即按 ~153px 烘焙折行，
    // 且 akLeft/akTop 锚定使其永不拓宽。TMemo 显式定界 + 四向锚定，
    // 彻底消除左侧挤缩；同时获得滚动与划选复制能力。
    MemSummary := TMemo.Create(PnlBody);
    MemSummary.Parent := PnlBody;
    MemSummary.Left := ScalePx(20);
    MemSummary.Top := ScalePx(8);
    MemSummary.Width := DlgForm.ClientWidth - ScalePx(40);
    MemSummary.BorderStyle := bsNone;
    MemSummary.ReadOnly := True;
    MemSummary.WordWrap := True;
    MemSummary.WantReturns := False;
    MemSummary.HideSelection := False;
    MemSummary.ScrollBars := ssNone;
    MemSummary.Color := TColor(Tokens.Surface and $00FFFFFF);
    MemSummary.Font.Name := Tokens.FontFamily;
    MemSummary.Font.Size := Round(Tokens.SizeS);
    MemSummary.Font.Color := TColor(Tokens.Ink and $00FFFFFF);
    // 固定尺寸对话框（bsDialog 不可拉伸）：保持默认 [akLeft, akTop]，
    // 显式边界永久有效。切勿加 akRight/akBottom——父面板在 ClientHeight
    // 赋值时 274→129 收缩会把锚定控件的高度钳制为 0（实机 dump 取证）。
    MemSummary.Text := AOptions.Summary;

    // 高度自适应：短文本收敛（告别 380 大黑框两行字），超长截断改滚动。
    LNeedH := MeasureSummaryHeight(AOptions.Summary, MemSummary.Width) + ScalePx(8);
    if AOptions.Kind in [dkPrompt, dkPromptReason] then
    begin
      // 输入区固定占位（标签 70 / 输入 94+110）：正文区让行，可滚。
      LBodyH := ScalePx(274);
      MemSummary.Height := ScalePx(52);
    end
    else
    begin
      LBodyH := LNeedH + ScalePx(16);
      if LBodyH < ScalePx(64) then
        LBodyH := ScalePx(64);
      if LBodyH > ScalePx(280) then
        LBodyH := ScalePx(280);
      MemSummary.Height := LBodyH - ScalePx(16);
    end;
    if LNeedH > MemSummary.Height then
      MemSummary.ScrollBars := ssVertical;
    DlgForm.ClientHeight := ScalePx(54) + LBodyH + ScalePx(52);

    // Optional Prompt Input Zone
    if AOptions.Kind in [dkPrompt, dkPromptReason] then
    begin
      LblPrompt := TLabel.Create(PnlBody);
      LblPrompt.Parent := PnlBody;
      LblPrompt.Left := ScalePx(20);
      LblPrompt.Top := ScalePx(70);
      LblPrompt.Caption := AOptions.PromptLabel;
      LblPrompt.Font.Name := Tokens.FontFamily;
      LblPrompt.Font.Size := Round(Tokens.SizeS);
      LblPrompt.Font.Color := TColor(Tokens.InkMuted and $00FFFFFF);

      if AOptions.IsInputMultiline then
      begin
        var Memo := TMemo.Create(PnlBody);
        Memo.Parent := PnlBody;
        Memo.Left := ScalePx(20);
        Memo.Top := ScalePx(94);
        Memo.Width := DlgForm.ClientWidth - ScalePx(40);
        Memo.Height := ScalePx(110);
        Memo.Text := AOptions.DefaultInput;
        EdtInput := Memo;
      end
      else
      begin
        var Edit := TEdit.Create(PnlBody);
        Edit.Parent := PnlBody;
        Edit.Left := ScalePx(20);
        Edit.Top := ScalePx(94);
        Edit.Width := DlgForm.ClientWidth - ScalePx(40);
        Edit.Height := ScalePx(32);
        Edit.Text := AOptions.DefaultInput;
        EdtInput := Edit;
      end;
    end
    else
      EdtInput := nil;

    // WO-20260926-0294 T3：底栏升级为 HB 胶囊矢量按钮（替代 Win95 原生 TButton）。
    // 注：THbBtnKind 无 bkDefault，按语义取最接近的高亮主色 bkPrimary；取消取 bkGhost。
    // 右下锚定（akRight/akBottom），与底栏边距保持 16/10px，杜绝高 DPI 截断脱位。
    LBridgeOk := TDialogModalBridge.Create(DlgForm);
    LBridgeOk.FForm := DlgForm;
    LBridgeOk.FResult := mrOk;
    BtnOk := THbButton.Create(PnlFooter);
    BtnOk.Parent := PnlFooter;
    BtnOk.Kind := bkPrimary;
    BtnOk.Pill := True;
    BtnOk.Width := ScalePx(86);
    BtnOk.Height := ScalePx(32);
    BtnOk.Top := ScalePx(10);
    BtnOk.Left := DlgForm.ClientWidth - ScalePx(16 + 86);
    BtnOk.Anchors := [akRight, akBottom];
    BtnOk.Caption := '确定';
    if AOptions.OkCaption <> '' then
      BtnOk.Caption := AOptions.OkCaption;
    BtnOk.TabStop := True;
    BtnOk.OnClick := LBridgeOk.HandleClick;

    LBridgeCancel := TDialogModalBridge.Create(DlgForm);
    LBridgeCancel.FForm := DlgForm;
    LBridgeCancel.FResult := mrCancel;
    BtnCancel := THbButton.Create(PnlFooter);
    BtnCancel.Parent := PnlFooter;
    BtnCancel.Kind := bkGhost;
    BtnCancel.Pill := True;
    BtnCancel.Width := ScalePx(86);
    BtnCancel.Height := ScalePx(32);
    BtnCancel.Top := ScalePx(10);
    BtnCancel.Left := BtnOk.Left - ScalePx(10 + 86);
    BtnCancel.Anchors := [akRight, akBottom];
    BtnCancel.Caption := '取消';
    if AOptions.CancelCaption <> '' then
      BtnCancel.Caption := AOptions.CancelCaption;
    BtnCancel.TabStop := True;
    BtnCancel.OnClick := LBridgeCancel.HandleClick;

    // 键盘等价：回车确认（输入框内除外）/ Esc 取消（替代 TButton.Default/Cancel）。
    LBridgeKeys := TDialogModalBridge.Create(DlgForm);
    LBridgeKeys.FForm := DlgForm;
    LBridgeKeys.FEdit := EdtInput;
    DlgForm.KeyPreview := True;
    DlgForm.OnKeyDown := LBridgeKeys.HandleKeyDown;
    DlgForm.ActiveControl := BtnOk;

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

      var Ev: TTouchEvidence;
      FillChar(Ev, SizeOf(Ev), 0);
      Ev.TouchpointId := 'tp_dialog_confirm';
      Ev.SurfaceId := 'frm_dialog';
      Ev.TimestampUtc := DateTimeToUnix(TTimeZone.Local.ToUniversalTime(Now), False) * 1000;
      Ev.DwellTimeMs := 0;
      Ev.Success := True;
      Ev.BeforeState := 'Prompting';
      Ev.AfterState := 'Confirmed';
      Ev.ActionType := 'Confirm';
      Ev.ErrorCode := 0;
      Ev.SupportDeflected := True;

      if not THbTouchpointEngine.Instance.IsRegistered('tp_dialog_confirm') then
        THbTouchpointEngine.Instance.RegisterTouchpoint('tp_dialog_confirm', tlCritical, 'frm_dialog', 'Confirmed');
      THbTouchpointEngine.Instance.EmitEvidence(Ev);
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
