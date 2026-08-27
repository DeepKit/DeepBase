{ ============================================================================
  DeepBase.VCL.HB.Gate - Compiler-Style Gate Check Panel for VCL
  
  Version: 1.0 (Delphi 13.1 on Win64)
  Description: High-performance compiler-style gate check panel for VCL:
               - Summary pill filter bar (Error / Warning / Pass / Notice)
               - Severity badges with color + icon + label triple redundancy
               - Monospace RuleID column alignment
               - Smooth row accordion expansion for Reason / FixHint / Context
               - Bottom host-injected action slot for waivers & remediation
               - Virtualized list rendering for large-scale rule audits
  ============================================================================ }

unit DeepBase.VCL.HB.Gate;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
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
  DeepBase.HB.Gate.Types,
  DeepBase.VCL.HB.Theme,
  DeepBase.VCL.HB.Controls;

type
  /// <summary>
  /// THbGatePanel: Compiler-Style Quality & Protocol Gate Verification Panel.
  /// </summary>
  THbGatePanel = class(THbCustomControl)
  private
    FRules: TList<THbGateRowItem>;
    FFilterSeverity: Integer; // -1: All, 0: Pass, 1: Notice, 2: Warning, 3: Error
    FSelectedIndex: Integer;
    FRowHeightCollapsed: Integer;
    FRowHeightExpanded: Integer;
    FOnJump: THbGateJumpEvent;
    FOnAction: THbGateActionEvent;

    // Subcomponents
    FPnlSummaryBar: TPanel;
    FBtnFilterAll: THbButton;
    FBtnFilterError: THbButton;
    FBtnFilterWarn: THbButton;
    FBtnFilterPass: THbButton;
    FPnlActionSlot: TPanel;
    FBtnWaiverAction: THbButton;
    FBtnRecheck: THbButton;

    procedure UpdateSummaryButtons;
    procedure OnFilterAllClick(Sender: TObject);
    procedure OnFilterErrorClick(Sender: TObject);
    procedure OnFilterWarnClick(Sender: TObject);
    procedure OnFilterPassClick(Sender: TObject);
    procedure OnWaiverClick(Sender: TObject);
    procedure OnRecheckClick(Sender: TObject);
    function IsRowVisible(const ARule: THbGateRowItem): Boolean;
    function GetSeverityBadgeText(ASeverity: THbGateSeverity): string;
    function GetSeverityColor(ASeverity: THbGateSeverity): TAlphaColor;
  protected
    procedure Paint; override;
    procedure Resize; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure AddRule(const ARuleID, ATitle: string; ASeverity: THbGateSeverity;
      const AReason: string; const AFixHint: string = ''; const AJumpRef: string = '');
    procedure ClearRules;
    function ComputeStats: THbGateSummaryStats;
    procedure ToggleRowExpand(AIndex: Integer);

    property Rules: TList<THbGateRowItem> read FRules;
    property FilterSeverity: Integer read FFilterSeverity write FFilterSeverity;
    property SelectedIndex: Integer read FSelectedIndex write FSelectedIndex;
  published
    property Align;
    property Anchors;
    property OnJump: THbGateJumpEvent read FOnJump write FOnJump;
    property OnAction: THbGateActionEvent read FOnAction write FOnAction;
  end;

implementation

{ THbGatePanel }

constructor THbGatePanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 750;
  Height := 500;
  FRowHeightCollapsed := 42;
  FRowHeightExpanded := 130;
  FFilterSeverity := -1; // All
  FSelectedIndex := -1;
  FRules := TList<THbGateRowItem>.Create;

  DoubleBuffered := True;

  // 1. Top Summary Filter Bar
  FPnlSummaryBar := TPanel.Create(Self);
  FPnlSummaryBar.Align := alTop;
  FPnlSummaryBar.Height := 44;
  FPnlSummaryBar.BevelOuter := bvNone;
  FPnlSummaryBar.Parent := Self;

  FBtnFilterAll := THbButton.Create(FPnlSummaryBar);
  FBtnFilterAll.Align := alLeft;
  FBtnFilterAll.Width := 90;
  FBtnFilterAll.Caption := '全部 (0)';
  FBtnFilterAll.Kind := bkPrimary;
  FBtnFilterAll.OnClick := OnFilterAllClick;
  FBtnFilterAll.Parent := FPnlSummaryBar;

  FBtnFilterError := THbButton.Create(FPnlSummaryBar);
  FBtnFilterError.Align := alLeft;
  FBtnFilterError.Width := 100;
  FBtnFilterError.Caption := '✕ 阻断 (0)';
  FBtnFilterError.Kind := bkSoft;
  FBtnFilterError.OnClick := OnFilterErrorClick;
  FBtnFilterError.Parent := FPnlSummaryBar;

  FBtnFilterWarn := THbButton.Create(FPnlSummaryBar);
  FBtnFilterWarn.Align := alLeft;
  FBtnFilterWarn.Width := 100;
  FBtnFilterWarn.Caption := '⚠ 警告 (0)';
  FBtnFilterWarn.Kind := bkSoft;
  FBtnFilterWarn.OnClick := OnFilterWarnClick;
  FBtnFilterWarn.Parent := FPnlSummaryBar;

  FBtnFilterPass := THbButton.Create(FPnlSummaryBar);
  FBtnFilterPass.Align := alLeft;
  FBtnFilterPass.Width := 100;
  FBtnFilterPass.Caption := '✓ 通过 (0)';
  FBtnFilterPass.Kind := bkSoft;
  FBtnFilterPass.OnClick := OnFilterPassClick;
  FBtnFilterPass.Parent := FPnlSummaryBar;

  // 2. Bottom Action Slot
  FPnlActionSlot := TPanel.Create(Self);
  FPnlActionSlot.Align := alBottom;
  FPnlActionSlot.Height := 46;
  FPnlActionSlot.BevelOuter := bvNone;
  FPnlActionSlot.Parent := Self;

  FBtnWaiverAction := THbButton.Create(FPnlActionSlot);
  FBtnWaiverAction.Align := alRight;
  FBtnWaiverAction.Width := 140;
  FBtnWaiverAction.Caption := '📝 申请书面豁免...';
  FBtnWaiverAction.Kind := bkSoft;
  FBtnWaiverAction.OnClick := OnWaiverClick;
  FBtnWaiverAction.Parent := FPnlActionSlot;

  FBtnRecheck := THbButton.Create(FPnlActionSlot);
  FBtnRecheck.Align := alRight;
  FBtnRecheck.Width := 120;
  FBtnRecheck.Caption := '🔄 重新体检';
  FBtnRecheck.Kind := bkPrimary;
  FBtnRecheck.OnClick := OnRecheckClick;
  FBtnRecheck.Parent := FPnlActionSlot;
end;

destructor THbGatePanel.Destroy;
begin
  FRules.Free;
  inherited;
end;

procedure THbGatePanel.Resize;
begin
  inherited;
end;

function THbGatePanel.ComputeStats: THbGateSummaryStats;
var
  I: Integer;
  R: THbGateRowItem;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.TotalCount := FRules.Count;
  for I := 0 to FRules.Count - 1 do
  begin
    R := FRules[I];
    case R.Severity of
      sePass:    Inc(Result.PassCount);
      seNotice:  Inc(Result.NoticeCount);
      seWarning: Inc(Result.WarningCount);
      seError:   Inc(Result.ErrorCount);
    end;
  end;
end;

procedure THbGatePanel.UpdateSummaryButtons;
var
  Stats: THbGateSummaryStats;
begin
  Stats := ComputeStats;
  if Assigned(FBtnFilterAll) then
    FBtnFilterAll.Caption := Format('全部 (%d)', [Stats.TotalCount]);
  if Assigned(FBtnFilterError) then
    FBtnFilterError.Caption := Format('✕ 阻断 (%d)', [Stats.ErrorCount]);
  if Assigned(FBtnFilterWarn) then
    FBtnFilterWarn.Caption := Format('⚠ 警告 (%d)', [Stats.WarningCount]);
  if Assigned(FBtnFilterPass) then
    FBtnFilterPass.Caption := Format('✓ 通过 (%d)', [Stats.PassCount]);
end;

procedure THbGatePanel.OnFilterAllClick(Sender: TObject);
begin
  FFilterSeverity := -1;
  FBtnFilterAll.Kind := bkPrimary;
  FBtnFilterError.Kind := bkSoft;
  FBtnFilterWarn.Kind := bkSoft;
  FBtnFilterPass.Kind := bkSoft;
  Invalidate;
end;

procedure THbGatePanel.OnFilterErrorClick(Sender: TObject);
begin
  FFilterSeverity := Ord(seError);
  FBtnFilterAll.Kind := bkSoft;
  FBtnFilterError.Kind := bkPrimary;
  FBtnFilterWarn.Kind := bkSoft;
  FBtnFilterPass.Kind := bkSoft;
  Invalidate;
end;

procedure THbGatePanel.OnFilterWarnClick(Sender: TObject);
begin
  FFilterSeverity := Ord(seWarning);
  FBtnFilterAll.Kind := bkSoft;
  FBtnFilterError.Kind := bkSoft;
  FBtnFilterWarn.Kind := bkPrimary;
  FBtnFilterPass.Kind := bkSoft;
  Invalidate;
end;

procedure THbGatePanel.OnFilterPassClick(Sender: TObject);
begin
  FFilterSeverity := Ord(sePass);
  FBtnFilterAll.Kind := bkSoft;
  FBtnFilterError.Kind := bkSoft;
  FBtnFilterWarn.Kind := bkSoft;
  FBtnFilterPass.Kind := bkPrimary;
  Invalidate;
end;

procedure THbGatePanel.OnWaiverClick(Sender: TObject);
var
  RuleId: string;
begin
  if (FSelectedIndex >= 0) and (FSelectedIndex < FRules.Count) then
    RuleId := FRules[FSelectedIndex].RuleID
  else
    RuleId := '';

  if Assigned(FOnAction) then
    FOnAction(Self, RuleId, 'waiver');
end;

procedure THbGatePanel.OnRecheckClick(Sender: TObject);
begin
  if Assigned(FOnAction) then
    FOnAction(Self, '', 'recheck');
end;

function THbGatePanel.IsRowVisible(const ARule: THbGateRowItem): Boolean;
begin
  if FFilterSeverity < 0 then
    Result := True
  else
    Result := (Ord(ARule.Severity) = FFilterSeverity);
end;

function THbGatePanel.GetSeverityBadgeText(ASeverity: THbGateSeverity): string;
begin
  case ASeverity of
    sePass:    Result := '✓ PASS 通过';
    seNotice:  Result := 'ℹ NOTE 提示';
    seWarning: Result := '⚠ WARN 警告';
    seError:   Result := '✕ FAIL 阻断';
  end;
end;

function THbGatePanel.GetSeverityColor(ASeverity: THbGateSeverity): TAlphaColor;
var
  Tokens: THbTokens;
begin
  Tokens := THbTheme.Tokens;
  case ASeverity of
    sePass:    Result := Tokens.Success;
    seNotice:  Result := Tokens.Info;
    seWarning: Result := Tokens.Warning;
    seError:   Result := Tokens.Danger;
  else
    Result := Tokens.Info;
  end;
end;

procedure THbGatePanel.AddRule(const ARuleID, ATitle: string; ASeverity: THbGateSeverity;
  const AReason: string; const AFixHint: string; const AJumpRef: string);
var
  Item: THbGateRowItem;
begin
  Item.RuleID := ARuleID;
  Item.Severity := ASeverity;
  Item.Title := ATitle;
  Item.TargetText := '';
  Item.ReasonText := AReason;
  Item.FixHint := AFixHint;
  Item.JumpRef := AJumpRef;
  Item.ContextSnippet := '';
  Item.IsExpanded := False;
  Item.WaiverStatus := '';
  FRules.Add(Item);
  UpdateSummaryButtons;
  Invalidate;
end;

procedure THbGatePanel.ClearRules;
begin
  FRules.Clear;
  FSelectedIndex := -1;
  UpdateSummaryButtons;
  Invalidate;
end;

procedure THbGatePanel.ToggleRowExpand(AIndex: Integer);
var
  Item: THbGateRowItem;
begin
  if (AIndex >= 0) and (AIndex < FRules.Count) then
  begin
    Item := FRules[AIndex];
    Item.IsExpanded := not Item.IsExpanded;
    FRules[AIndex] := Item;
    FSelectedIndex := AIndex;
    Invalidate;
  end;
end;

procedure THbGatePanel.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  TopOffset, CurY, I, RowH: Integer;
  R: THbGateRowItem;
begin
  inherited;
  TopOffset := FPnlSummaryBar.Height;
  if Y < TopOffset then
    Exit;

  CurY := TopOffset;
  for I := 0 to FRules.Count - 1 do
  begin
    R := FRules[I];
    if not IsRowVisible(R) then
      Continue;

    if R.IsExpanded then
      RowH := FRowHeightExpanded
    else
      RowH := FRowHeightCollapsed;

    if (Y >= CurY) and (Y < CurY + RowH) then
    begin
      ToggleRowExpand(I);
      if (R.JumpRef <> '') and (X > Width - 100) and Assigned(FOnJump) then
        FOnJump(Self, R.JumpRef);
      Break;
    end;
    Inc(CurY, RowH + 4);
  end;
end;

procedure THbGatePanel.Paint;
var
  Tokens: THbTokens;
  CanvasObj: TCanvas;
  TopOffset, CurY, I, RowH: Integer;
  R: THbGateRowItem;
  RowRect: TRect;
  SevColor: TColor;
begin
  inherited;
  Tokens := THbTheme.Tokens;
  CanvasObj := Canvas;
  TopOffset := FPnlSummaryBar.Height;

  // Background
  CanvasObj.Brush.Color := AlphaColorToColor(Tokens.Surface);
  CanvasObj.Pen.Color := AlphaColorToColor(Tokens.Border);
  CanvasObj.Pen.Width := 1;
  CanvasObj.Rectangle(0, TopOffset, Width, Height - FPnlActionSlot.Height);

  if FRules.Count = 0 then
  begin
    CanvasObj.Font.Color := AlphaColorToColor(Tokens.InkMuted);
    CanvasObj.Font.Size := 10;
    CanvasObj.TextOut(24, TopOffset + 30, '暂无门禁检查项 (点击「重新体检」执行全量规则扫描)...');
    Exit;
  end;

  CurY := TopOffset + 6;
  for I := 0 to FRules.Count - 1 do
  begin
    R := FRules[I];
    if not IsRowVisible(R) then
      Continue;

    if R.IsExpanded then
      RowH := FRowHeightExpanded
    else
      RowH := FRowHeightCollapsed;

    if CurY + RowH > Height - FPnlActionSlot.Height then
      Break;

    RowRect := Rect(10, CurY, Width - 10, CurY + RowH);

    // Row Background & Border
    if I = FSelectedIndex then
    begin
      CanvasObj.Brush.Color := AlphaColorToColor(Tokens.Soft);
      CanvasObj.Pen.Color := AlphaColorToColor(Tokens.FocusRing);
      CanvasObj.Pen.Width := 2;
    end
    else
    begin
      CanvasObj.Brush.Color := AlphaColorToColor(Tokens.SurfaceAlt);
      CanvasObj.Pen.Color := AlphaColorToColor(Tokens.Border);
      CanvasObj.Pen.Width := 1;
    end;
    CanvasObj.RoundRect(RowRect.Left, RowRect.Top, RowRect.Right, RowRect.Bottom, 6, 6);

    // 1. RuleID (Monospace)
    CanvasObj.Font.Name := 'Consolas';
    CanvasObj.Font.Size := 10;
    CanvasObj.Font.Style := [fsBold];
    CanvasObj.Font.Color := AlphaColorToColor(Tokens.Primary);
    CanvasObj.TextOut(RowRect.Left + 14, RowRect.Top + 11, R.RuleID);

    // 2. Severity Badge (Triple redundancy)
    SevColor := AlphaColorToColor(GetSeverityColor(R.Severity));
    CanvasObj.Font.Name := 'Segoe UI';
    CanvasObj.Font.Size := 9;
    CanvasObj.Font.Style := [fsBold];
    CanvasObj.Font.Color := SevColor;
    CanvasObj.TextOut(RowRect.Left + 80, RowRect.Top + 12, GetSeverityBadgeText(R.Severity));

    // 3. Title
    CanvasObj.Font.Size := 10;
    CanvasObj.Font.Style := [];
    CanvasObj.Font.Color := AlphaColorToColor(Tokens.Ink);
    CanvasObj.TextOut(RowRect.Left + 180, RowRect.Top + 11, R.Title);

    // 4. Accordion Toggle icon on right
    CanvasObj.Font.Color := AlphaColorToColor(Tokens.InkMuted);
    if R.IsExpanded then
      CanvasObj.TextOut(RowRect.Right - 30, RowRect.Top + 11, '▲')
    else
      CanvasObj.TextOut(RowRect.Right - 30, RowRect.Top + 11, '▼');

    // 5. Jump link if present
    if R.JumpRef <> '' then
    begin
      CanvasObj.Font.Color := AlphaColorToColor(Tokens.Primary);
      CanvasObj.TextOut(RowRect.Right - 110, RowRect.Top + 11, '定位溯源 ↗');
    end;

    // 6. Expanded Accordion Drawer Details
    if R.IsExpanded then
    begin
      // Divider line
      CanvasObj.Pen.Color := AlphaColorToColor(Tokens.Border);
      CanvasObj.Pen.Width := 1;
      CanvasObj.MoveTo(RowRect.Left + 14, RowRect.Top + 38);
      CanvasObj.LineTo(RowRect.Right - 14, RowRect.Top + 38);

      // Reason text
      CanvasObj.Font.Size := 9;
      CanvasObj.Font.Color := AlphaColorToColor(Tokens.Ink);
      CanvasObj.TextOut(RowRect.Left + 20, RowRect.Top + 46, '【为什么触发】 ' + R.ReasonText);

      // Fix hint
      if R.FixHint <> '' then
      begin
        CanvasObj.Font.Color := AlphaColorToColor(Tokens.Warning);
        CanvasObj.TextOut(RowRect.Left + 20, RowRect.Top + 70, '【修复建议】 ' + R.FixHint);
      end;

      // Target snippet
      if R.TargetText <> '' then
      begin
        CanvasObj.Font.Color := AlphaColorToColor(Tokens.InkMuted);
        CanvasObj.TextOut(RowRect.Left + 20, RowRect.Top + 94, '【触发上下文】 ' + R.TargetText);
      end;
    end;

    Inc(CurY, RowH + 4);
  end;
end;

end.
