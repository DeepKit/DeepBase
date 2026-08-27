{ ============================================================================
  DeepBase.FMX.HB.Gate - Compiler-Style Gate Check Panel for FMX
  
  Version: 1.0 (Delphi 13.1 on Win64 / Cross-Platform FMX)
  Description: Cross-platform FMX twin implementation of THbGatePanel:
               - THbFmxControl vector rendering pipeline
               - Severity summary stats computation & filter
               - Accordion row toggle and jump navigation
  ============================================================================ }

unit DeepBase.FMX.HB.Gate;

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
  FMX.Layouts,
  FMX.Objects,
  DeepBase.HB.Core,
  DeepBase.HB.Gate.Types,
  DeepBase.FMX.HB.Theme,
  DeepBase.FMX.HB.Controls;

type
  /// <summary>
  /// THbGatePanel (FMX): Compiler-style gate check panel for FMX.
  /// </summary>
  THbGatePanel = class(THbFmxControl)
  private
    FRules: TList<THbGateRowItem>;
    FFilterSeverity: Integer;
    FSelectedIndex: Integer;
    FOnJump: THbGateJumpEvent;
    FOnAction: THbGateActionEvent;
    procedure SetFilterSeverity(Value: Integer);
  protected
    procedure DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure AddRule(const ARuleID, ATitle: string; ASeverity: THbGateSeverity;
      const AReason: string; const AFixHint: string = ''; const AJumpRef: string = '');
    procedure ClearRules;
    function ComputeStats: THbGateSummaryStats;
    procedure ToggleRowExpand(AIndex: Integer);

    property Rules: TList<THbGateRowItem> read FRules;
    property FilterSeverity: Integer read FFilterSeverity write SetFilterSeverity;
    property SelectedIndex: Integer read FSelectedIndex write FSelectedIndex;
  published
    property Align;
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
  FRules := TList<THbGateRowItem>.Create;
  FFilterSeverity := -1;
  FSelectedIndex := -1;
end;

destructor THbGatePanel.Destroy;
begin
  FRules.Free;
  inherited;
end;

procedure THbGatePanel.SetFilterSeverity(Value: Integer);
begin
  if FFilterSeverity <> Value then
  begin
    FFilterSeverity := Value;
    Repaint;
  end;
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
  Repaint;
end;

procedure THbGatePanel.ClearRules;
begin
  FRules.Clear;
  FSelectedIndex := -1;
  Repaint;
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
    Repaint;
  end;
end;

procedure THbGatePanel.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  CurY: Single;
  I: Integer;
  RowH: Single;
  R: THbGateRowItem;
begin
  inherited;
  if Button <> TMouseButton.mbLeft then
    Exit;

  CurY := 44.0;
  for I := 0 to FRules.Count - 1 do
  begin
    R := FRules[I];
    if (FFilterSeverity >= 0) and (Ord(R.Severity) <> FFilterSeverity) then
      Continue;

    if R.IsExpanded then
      RowH := 120.0
    else
      RowH := 40.0;

    if (Y >= CurY) and (Y < CurY + RowH) then
    begin
      ToggleRowExpand(I);
      if (R.JumpRef <> '') and (X > Width - 120.0) and Assigned(FOnJump) then
        FOnJump(Self, R.JumpRef);
      Break;
    end;
    CurY := CurY + RowH + 4.0;
  end;
end;

procedure THbGatePanel.DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens);
var
  R: TRectF;
  I: Integer;
  CurY, RowH: Single;
  Rule: THbGateRowItem;
  SevColor: TAlphaColor;
begin
  // Background
  Canvas.Fill.Color := Tokens.Surface;
  Canvas.Fill.Kind := TBrushKind.Solid;
  Canvas.FillRect(ARect, 0, 0, [], 1.0);

  // Top Summary Bar
  R := RectF(ARect.Left, ARect.Top, ARect.Right, ARect.Top + 40.0);
  Canvas.Fill.Color := Tokens.SurfaceAlt;
  Canvas.FillRect(R, 0, 0, [], 1.0);

  Canvas.Fill.Color := Tokens.Ink;
  Canvas.Font.Size := 13;
  Canvas.Font.Family := Tokens.FontFamily;
  Canvas.FillText(RectF(ARect.Left + 16, ARect.Top + 10, ARect.Right - 16, ARect.Top + 34),
    Format('规则门禁审计: 共 %d 项', [FRules.Count]), False, 1.0, [], TTextAlign.Leading);

  CurY := ARect.Top + 44.0;
  for I := 0 to FRules.Count - 1 do
  begin
    Rule := FRules[I];
    if (FFilterSeverity >= 0) and (Ord(Rule.Severity) <> FFilterSeverity) then
      Continue;

    if Rule.IsExpanded then
      RowH := 120.0
    else
      RowH := 40.0;

    if CurY + RowH > ARect.Bottom then
      Break;

    R := RectF(ARect.Left + 8.0, CurY, ARect.Right - 8.0, CurY + RowH);
    Canvas.Fill.Color := Tokens.SurfaceAlt;
    Canvas.FillRect(R, 4.0, 4.0, AllCorners, 1.0);

    case Rule.Severity of
      sePass:    SevColor := Tokens.Success;
      seNotice:  SevColor := Tokens.Info;
      seWarning: SevColor := Tokens.Warning;
      seError:   SevColor := Tokens.Danger;
    else
      SevColor := Tokens.Info;
    end;

    // Severity badge
    Canvas.Fill.Color := SevColor;
    Canvas.FillRect(RectF(R.Left + 8, R.Top + 8, R.Left + 70, R.Top + 32), 4.0, 4.0, AllCorners, 1.0);
    Canvas.Fill.Color := Tokens.OnPrimary;
    Canvas.Font.Size := 11;
    Canvas.FillText(RectF(R.Left + 8, R.Top + 10, R.Left + 70, R.Top + 30), Rule.RuleID, False, 1.0, [], TTextAlign.Center);

    // Title
    Canvas.Fill.Color := Tokens.Ink;
    Canvas.Font.Size := 12;
    Canvas.FillText(RectF(R.Left + 80, R.Top + 10, R.Right - 80, R.Top + 30), Rule.Title, False, 1.0, [], TTextAlign.Leading);

    // Expand details
    if Rule.IsExpanded then
    begin
      Canvas.Fill.Color := Tokens.InkMuted;
      Canvas.Font.Size := 11;
      Canvas.FillText(RectF(R.Left + 80, R.Top + 40, R.Right - 20, R.Top + 110),
        '原因: ' + Rule.ReasonText + #13#10 + '建议: ' + Rule.FixHint, False, 1.0, [], TTextAlign.Leading);
    end;

    CurY := CurY + RowH + 4.0;
  end;
end;

end.
