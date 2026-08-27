{ ============================================================================
  DeepBase.VCL.HB.Grid - High-Performance Virtual Data Grid for VCL

  Version: 1.0 (Delphi 13.1 on Win64)
  Description: THbDataGrid:
               - Virtual row rendering (constant memory & 60fps scrolling)
               - Column definitions (Heatbars, Badges, Currencies, Sort)
               - Selection range stats (Sum, Avg, Count, Min, Max)
               - Token-driven styling with GDI+ anti-aliasing
  ============================================================================ }

unit DeepBase.VCL.HB.Grid;

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
  System.Generics.Collections,
  Vcl.Controls,
  Vcl.Graphics,
  Vcl.Forms,
  Vcl.StdCtrls,
  System.Math,
  DeepBase.HB.Core,
  DeepBase.HB.Grid.Types,
  DeepBase.VCL.HB.Theme;

type
  THbDataGrid = class;

  /// <summary>
  /// Callback to retrieve cell text for virtual rows.
  /// </summary>
  THbGetCellTextEvent = procedure(Sender: TObject; ARow, ACol: Integer; var AValue: string) of object;

  /// <summary>
  /// Callback to retrieve cell numeric float value for heatbars and stats.
  /// </summary>
  THbGetCellFloatEvent = procedure(Sender: TObject; ARow, ACol: Integer; var AValue: Double) of object;

  /// <summary>
  /// THbDataGrid: Modern Virtual Data Grid Component for VCL.
  /// </summary>
  THbDataGrid = class(TCustomControl)
  private
    FColumns: TList<THbGridColumnDef>;
    FRowCount: Integer;
    FRowHeight: Integer;
    FHeaderHeight: Integer;
    FSelection: THbGridSelection;
    FSelectedRows: TList<Integer>;
    FOnGetCellText: THbGetCellTextEvent;
    FOnGetCellFloat: THbGetCellFloatEvent;
    FScrollTopRow: Integer;
    procedure SetRowCount(Value: Integer);
    procedure SetRowHeight(Value: Integer);
    procedure SetHeaderHeight(Value: Integer);
    procedure UpdateScrollBars;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure Resize; override;
    procedure CreateWnd; override;
    procedure WMVScroll(var Message: TWMVScroll); message WM_VSCROLL;
    procedure CMMouseWheel(var Message: TCMMouseWheel); message CM_MOUSEWHEEL;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure AddColumn(const AField, ATitle: string; AWidth: Integer = 120;
      AType: THbGridColumnType = gctText; AAlign: TAlignment = taLeftJustify);
    procedure ClearColumns;

    function ComputeSelectionStats: THbGridStats;
    procedure SelectRow(ARowIndex: Integer; AAddToSelection: Boolean = False);
    procedure ClearSelection;
    procedure ScrollToRow(ARow: Integer);

    property Columns: TList<THbGridColumnDef> read FColumns;
    property SelectedRows: TList<Integer> read FSelectedRows;
    property Selection: THbGridSelection read FSelection write FSelection;
    property ScrollTopRow: Integer read FScrollTopRow write ScrollToRow;
  published
    property Align;
    property Anchors;
    property RowCount: Integer read FRowCount write SetRowCount default 0;
    property RowHeight: Integer read FRowHeight write SetRowHeight default 34;
    property HeaderHeight: Integer read FHeaderHeight write SetHeaderHeight default 36;
    property OnGetCellText: THbGetCellTextEvent read FOnGetCellText write FOnGetCellText;
    property OnGetCellFloat: THbGetCellFloatEvent read FOnGetCellFloat write FOnGetCellFloat;
  end;

implementation

function ColorToARGB(AColor: TAlphaColor; AAlphaOverride: Byte = 0): ARGB;
var
  A, R, G, B: Byte;
begin
  A := TAlphaColorRec(AColor).A;
  R := TAlphaColorRec(AColor).R;
  G := TAlphaColorRec(AColor).G;
  B := TAlphaColorRec(AColor).B;
  if AAlphaOverride > 0 then
    A := AAlphaOverride;
  Result := (ARGB(A) shl 24) or (ARGB(R) shl 16) or (ARGB(G) shl 8) or ARGB(B);
end;

function ScaleDIP(APixels: Single): Single;
begin
  Result := APixels * (Screen.PixelsPerInch / 96.0);
end;

{ THbDataGrid }

constructor THbDataGrid.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 700;
  Height := 400;
  FRowCount := 0;
  FRowHeight := 34;
  FHeaderHeight := 36;
  FScrollTopRow := 0;
  FColumns := TList<THbGridColumnDef>.Create;
  FSelectedRows := TList<Integer>.Create;
  FSelection.StartRow := -1;
  FSelection.EndRow := -1;
  FSelection.StartCol := -1;
  FSelection.EndCol := -1;

  DoubleBuffered := True;
  TabStop := True;
end;

destructor THbDataGrid.Destroy;
begin
  FSelectedRows.Free;
  FColumns.Free;
  inherited;
end;

procedure THbDataGrid.SetRowCount(Value: Integer);
begin
  if FRowCount <> Value then
  begin
    FRowCount := Value;
    UpdateScrollBars;
    Invalidate;
  end;
end;

procedure THbDataGrid.SetRowHeight(Value: Integer);
begin
  if FRowHeight <> Value then
  begin
    FRowHeight := Value;
    UpdateScrollBars;
    Invalidate;
  end;
end;

procedure THbDataGrid.SetHeaderHeight(Value: Integer);
begin
  if FHeaderHeight <> Value then
  begin
    FHeaderHeight := Value;
    UpdateScrollBars;
    Invalidate;
  end;
end;

procedure THbDataGrid.UpdateScrollBars;
var
  SI: TScrollInfo;
  VisRows: Integer;
begin
  if not HandleAllocated then
    Exit;
  VisRows := Max(1, (Height - FHeaderHeight) div Max(1, FRowHeight));
  FillChar(SI, SizeOf(SI), 0);
  SI.cbSize := SizeOf(SI);
  SI.fMask := SIF_RANGE or SIF_PAGE or SIF_POS;
  SI.nMin := 0;
  SI.nMax := Max(0, FRowCount - 1);
  SI.nPage := VisRows;
  SI.nPos := FScrollTopRow;
  SetScrollInfo(Handle, SB_VERT, SI, True);
end;

procedure THbDataGrid.ScrollToRow(ARow: Integer);
var
  MaxTop: Integer;
  VisRows: Integer;
begin
  VisRows := Max(1, (Height - FHeaderHeight) div Max(1, FRowHeight));
  MaxTop := Max(0, FRowCount - VisRows);
  FScrollTopRow := EnsureRange(ARow, 0, MaxTop);
  UpdateScrollBars;
  Invalidate;
end;

procedure THbDataGrid.Resize;
begin
  inherited;
  UpdateScrollBars;
end;

procedure THbDataGrid.CreateWnd;
begin
  inherited;
  UpdateScrollBars;
end;

procedure THbDataGrid.WMVScroll(var Message: TWMVScroll);
var
  VisRows: Integer;
begin
  VisRows := Max(1, (Height - FHeaderHeight) div Max(1, FRowHeight));
  case Message.ScrollCode of
    SB_LINEUP:   ScrollToRow(FScrollTopRow - 1);
    SB_LINEDOWN: ScrollToRow(FScrollTopRow + 1);
    SB_PAGEUP:   ScrollToRow(FScrollTopRow - VisRows);
    SB_PAGEDOWN: ScrollToRow(FScrollTopRow + VisRows);
    SB_THUMBPOSITION, SB_THUMBTRACK: ScrollToRow(Message.Pos);
    SB_TOP:      ScrollToRow(0);
    SB_BOTTOM:   ScrollToRow(FRowCount - 1);
  end;
end;

procedure THbDataGrid.CMMouseWheel(var Message: TCMMouseWheel);
begin
  inherited;
  if Message.WheelDelta > 0 then
    ScrollToRow(FScrollTopRow - 3)
  else
    ScrollToRow(FScrollTopRow + 3);
  Message.Result := 1;
end;

procedure THbDataGrid.AddColumn(const AField, ATitle: string; AWidth: Integer;
  AType: THbGridColumnType; AAlign: TAlignment);
var
  Col: THbGridColumnDef;
begin
  Col.Field := AField;
  Col.Title := ATitle;
  Col.Width := AWidth;
  Col.ColType := AType;
  Col.Alignment := AAlign;
  Col.IsFrozen := False;
  Col.IsSortable := True;
  Col.IsFilterable := True;
  Col.SortOrder := gsoNone;
  Col.Visible := True;
  FColumns.Add(Col);
  Invalidate;
end;

procedure THbDataGrid.ClearColumns;
begin
  FColumns.Clear;
  Invalidate;
end;

procedure THbDataGrid.SelectRow(ARowIndex: Integer; AAddToSelection: Boolean);
begin
  if not AAddToSelection then
    FSelectedRows.Clear;

  if (ARowIndex >= 0) and (ARowIndex < FRowCount) then
  begin
    if not FSelectedRows.Contains(ARowIndex) then
      FSelectedRows.Add(ARowIndex);
    FSelection.StartRow := ARowIndex;
    FSelection.EndRow := ARowIndex;
  end;
  Invalidate;
end;

procedure THbDataGrid.ClearSelection;
begin
  FSelectedRows.Clear;
  FSelection.StartRow := -1;
  FSelection.EndRow := -1;
  Invalidate;
end;

function THbDataGrid.ComputeSelectionStats: THbGridStats;
var
  R, C: Integer;
  ValStr: string;
  ValFloat: Double;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.SelectedRowCount := FSelectedRows.Count;

  if FSelectedRows.Count = 0 then
    Exit;

  for R in FSelectedRows do
  begin
    for C := 0 to FColumns.Count - 1 do
    begin
      Inc(Result.SelectedCellCount);
      ValFloat := 0.0;
      if Assigned(FOnGetCellFloat) then
      begin
        FOnGetCellFloat(Self, R, C, ValFloat);
        Inc(Result.NumericCount);
        Result.SumValue := Result.SumValue + ValFloat;
        if (Result.NumericCount = 1) or (ValFloat < Result.MinValue) then
          Result.MinValue := ValFloat;
        if (Result.NumericCount = 1) or (ValFloat > Result.MaxValue) then
          Result.MaxValue := ValFloat;
      end
      else if Assigned(FOnGetCellText) then
      begin
        ValStr := '';
        FOnGetCellText(Self, R, C, ValStr);
        if TryStrToFloat(ValStr, ValFloat) then
        begin
          Inc(Result.NumericCount);
          Result.SumValue := Result.SumValue + ValFloat;
          if (Result.NumericCount = 1) or (ValFloat < Result.MinValue) then
            Result.MinValue := ValFloat;
          if (Result.NumericCount = 1) or (ValFloat > Result.MaxValue) then
            Result.MaxValue := ValFloat;
        end;
      end;
    end;
  end;

  if Result.NumericCount > 0 then
    Result.AvgValue := Result.SumValue / Result.NumericCount;
end;

procedure THbDataGrid.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  ClickedRow: Integer;
begin
  inherited;
  SetFocus;
  if (Y > FHeaderHeight) and (FRowHeight > 0) then
  begin
    ClickedRow := FScrollTopRow + (Y - FHeaderHeight) div FRowHeight;
    if (ClickedRow >= 0) and (ClickedRow < FRowCount) then
    begin
      SelectRow(ClickedRow, ssCtrl in Shift);
    end;
  end;
end;

procedure THbDataGrid.KeyDown(var Key: Word; Shift: TShiftState);
var
  FirstRow, LastRow: Integer;
begin
  inherited;
  if (Key = VK_DOWN) and (FSelectedRows.Count > 0) then
  begin
    LastRow := FSelectedRows[FSelectedRows.Count - 1];
    if LastRow < FRowCount - 1 then
      SelectRow(LastRow + 1, ssShift in Shift);
  end
  else if (Key = VK_UP) and (FSelectedRows.Count > 0) then
  begin
    FirstRow := FSelectedRows[0];
    if FirstRow > 0 then
      SelectRow(FirstRow - 1, ssShift in Shift);
  end;
end;

procedure THbDataGrid.Paint;
var
  Graphics: TGPGraphics;
  Tokens: THbTokens;
  BrushBg, BrushHdr, BrushRowAlt, BrushSel, BrushInk, BrushMuted, BrushTrack, BrushFill: TGPSolidBrush;
  PenBorder, PenDiv, PenRowDiv: TGPPen;
  FontFamily: TGPFontFamily;
  FontHdr, FontCell: TGPFont;
  StrFmtNear, StrFmtFar, StrFmtCenter: TGPStringFormat;
  CurX, CurY, FillW: Single;
  C, R, VisibleRows: Integer;
  Col: THbGridColumnDef;
  CellText: string;
  CellFloat: Double;
  HdrRect, ColRect, RowRect, BarTrack, CellRect: TGPRectF;
begin
  Tokens := THbTheme.Tokens;
  Graphics := TGPGraphics.Create(Canvas.Handle);
  try
    Graphics.SetSmoothingMode(SmoothingModeAntiAlias);
    Graphics.SetTextRenderingHint(TextRenderingHintClearTypeGridFit);

    // Background
    BrushBg := TGPSolidBrush.Create(ColorToARGB(Tokens.Sunken));
    PenBorder := TGPPen.Create(ColorToARGB(Tokens.Border), 1.0);
    try
      Graphics.FillRectangle(BrushBg, 0, 0, Width, Height);
      Graphics.DrawRectangle(PenBorder, 0.5, 0.5, Width - 1.0, Height - 1.0);
    finally
      PenBorder.Free;
      BrushBg.Free;
    end;

    FontFamily := TGPFontFamily.Create(Tokens.FontFamily);
    try
      FontHdr := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeS), FontStyleBold, UnitPixel);
      FontCell := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeS), FontStyleRegular, UnitPixel);
      BrushHdr := TGPSolidBrush.Create(ColorToARGB(Tokens.SurfaceAlt));
      BrushRowAlt := TGPSolidBrush.Create(ColorToARGB(Tokens.Surface));
      BrushSel := TGPSolidBrush.Create(ColorToARGB(Tokens.Primary, 40));
      BrushInk := TGPSolidBrush.Create(ColorToARGB(Tokens.Ink));
      BrushMuted := TGPSolidBrush.Create(ColorToARGB(Tokens.InkMuted));
      StrFmtNear := TGPStringFormat.Create;
      StrFmtFar := TGPStringFormat.Create;
      StrFmtCenter := TGPStringFormat.Create;
      try
        StrFmtNear.SetAlignment(StringAlignmentNear);
        StrFmtNear.SetLineAlignment(StringAlignmentCenter);
        StrFmtFar.SetAlignment(StringAlignmentFar);
        StrFmtFar.SetLineAlignment(StringAlignmentCenter);
        StrFmtCenter.SetAlignment(StringAlignmentCenter);
        StrFmtCenter.SetLineAlignment(StringAlignmentCenter);

        // 1. Draw Header
        HdrRect := MakeRect(0.0, 0.0, Single(Width), Single(FHeaderHeight));
        Graphics.FillRectangle(BrushHdr, HdrRect);

        CurX := 0.0;
        for C := 0 to FColumns.Count - 1 do
        begin
          Col := FColumns[C];
          ColRect := MakeRect(CurX + 8.0, 0.0, Single(Col.Width) - 16.0, Single(FHeaderHeight));
          Graphics.DrawString(Col.Title, Length(Col.Title), FontHdr, ColRect, StrFmtNear, BrushInk);

          PenDiv := TGPPen.Create(ColorToARGB(Tokens.Border), 1.0);
          try
            Graphics.DrawLine(PenDiv, CurX + Col.Width, 0.0, CurX + Col.Width, Single(FHeaderHeight));
          finally
            PenDiv.Free;
          end;
          CurX := CurX + Col.Width;
        end;

        // 2. Draw Virtual Rows
        if FRowHeight > 0 then
          VisibleRows := (Height - FHeaderHeight) div FRowHeight + 2
        else
          VisibleRows := 0;

        for R := FScrollTopRow to FScrollTopRow + VisibleRows do
        begin
          if R >= FRowCount then
            Break;

          CurY := FHeaderHeight + (R - FScrollTopRow) * FRowHeight;
          RowRect := MakeRect(0.0, CurY, Single(Width), Single(FRowHeight));

          // Selection / Hover background
          if FSelectedRows.Contains(R) then
            Graphics.FillRectangle(BrushSel, RowRect)
          else if (R mod 2 = 1) then
            Graphics.FillRectangle(BrushRowAlt, RowRect);

          // Cells
          CurX := 0.0;
          for C := 0 to FColumns.Count - 1 do
          begin
            Col := FColumns[C];
            CellText := '';
            CellFloat := 0.0;

            if Assigned(FOnGetCellText) then
              FOnGetCellText(Self, R, C, CellText);

            if Col.ColType = gctHeatBar then
            begin
              if Assigned(FOnGetCellFloat) then
                FOnGetCellFloat(Self, R, C, CellFloat);
              // Draw HeatBar
              BarTrack := MakeRect(CurX + 8.0, CurY + FRowHeight - 8.0, Single(Col.Width) - 16.0, 4.0);
              BrushTrack := TGPSolidBrush.Create(ColorToARGB(Tokens.Sunken));
              BrushFill := TGPSolidBrush.Create(ColorToARGB(Tokens.Primary));
              try
                Graphics.FillRectangle(BrushTrack, BarTrack);
                FillW := (Single(Col.Width) - 16.0) * (EnsureRange(CellFloat, 0.0, 100.0) / 100.0);
                if FillW > 0 then
                  Graphics.FillRectangle(BrushFill, CurX + 8.0, CurY + FRowHeight - 8.0, FillW, 4.0);
              finally
                BrushFill.Free;
                BrushTrack.Free;
              end;
            end;

            CellRect := MakeRect(CurX + 8.0, CurY, Single(Col.Width) - 16.0, Single(FRowHeight));
            Graphics.DrawString(CellText, Length(CellText), FontCell, CellRect, StrFmtNear, BrushInk);

            CurX := CurX + Col.Width;
          end;

          // Bottom border
          PenRowDiv := TGPPen.Create(ColorToARGB(Tokens.Border), 1.0);
          try
            Graphics.DrawLine(PenRowDiv, 0.0, CurY + FRowHeight, Single(Width), CurY + FRowHeight);
          finally
            PenRowDiv.Free;
          end;
        end;

      finally
        StrFmtCenter.Free;
        StrFmtFar.Free;
        StrFmtNear.Free;
        BrushMuted.Free;
        BrushInk.Free;
        BrushSel.Free;
        BrushRowAlt.Free;
        BrushHdr.Free;
        FontCell.Free;
        FontHdr.Free;
      end;
    finally
      FontFamily.Free;
    end;
  finally
    Graphics.Free;
  end;
end;

end.
