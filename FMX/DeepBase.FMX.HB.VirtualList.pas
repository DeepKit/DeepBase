{ ============================================================================
  DeepBase.FMX.HB.VirtualList - High-Performance Virtual Review List for FMX
  
  Version: 1.0 (Delphi 13.1 on Win64 / Cross-Platform FMX)
  Description: Cross-platform FMX twin implementation of THbVirtualList:
               - THbFmxControl vector rendering pipeline
               - Multi-selection and filter matching
               - Virtual review queue layout
  ============================================================================ }

unit DeepBase.FMX.HB.VirtualList;

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
  DeepBase.HB.VirtualList.Types,
  DeepBase.FMX.HB.Theme,
  DeepBase.FMX.HB.Controls;

type
  /// <summary>
  /// THbVirtualList (FMX): Virtual review list component for FMX.
  /// </summary>
  THbVirtualList = class(THbFmxControl)
  private
    FItems: TList<THbVirtualListItem>;
    FFilteredIndices: TList<Integer>;
    FSelectedIndices: TList<Integer>;
    FSearchFilter: string;
    FOnItemAction: THbVirtualListItemActionEvent;
    FOnSelectionChange: THbVirtualListSelectionEvent;

    function GetFilteredCount: Integer;
    procedure SetSearchFilter(const Value: string);
    procedure RebuildFilteredIndices;
  protected
    procedure DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure AddItem(const AId, AGroupKey, AGroupTitle, ATitle, ASummary1, ASummary2: string;
      ATone: THbBadgeTone = btBrand; const AStatusText: string = '';
      const ATags: TArray<string> = nil);
    procedure ClearItems;
    procedure SelectItem(AIndex: Integer; AAccumulate: Boolean = False);
    procedure DeselectAll;
    function GetSelectedIds: TArray<string>;

    property Items: TList<THbVirtualListItem> read FItems;
    property SearchFilter: string read FSearchFilter write SetSearchFilter;
    property SelectedIndices: TList<Integer> read FSelectedIndices;
    property FilteredCount: Integer read GetFilteredCount;
  published
    property Align;
    property OnItemAction: THbVirtualListItemActionEvent read FOnItemAction write FOnItemAction;
    property OnSelectionChange: THbVirtualListSelectionEvent read FOnSelectionChange write FOnSelectionChange;
  end;

implementation

{ THbVirtualList }

constructor THbVirtualList.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 750;
  Height := 520;
  FItems := TList<THbVirtualListItem>.Create;
  FFilteredIndices := TList<Integer>.Create;
  FSelectedIndices := TList<Integer>.Create;
  FSearchFilter := '';
end;

destructor THbVirtualList.Destroy;
begin
  FItems.Free;
  FFilteredIndices.Free;
  FSelectedIndices.Free;
  inherited;
end;

function THbVirtualList.GetFilteredCount: Integer;
begin
  Result := FFilteredIndices.Count;
end;

procedure THbVirtualList.RebuildFilteredIndices;
var
  I: Integer;
  Item: THbVirtualListItem;
  Q: string;
begin
  FFilteredIndices.Clear;
  Q := LowerCase(Trim(FSearchFilter));
  for I := 0 to FItems.Count - 1 do
  begin
    Item := FItems[I];
    if (Q = '') or (Pos(Q, LowerCase(Item.Title + ' ' + Item.SummaryLine1 + ' ' + Item.GroupTitle)) > 0) then
      FFilteredIndices.Add(I);
  end;
end;

procedure THbVirtualList.SetSearchFilter(const Value: string);
begin
  if FSearchFilter <> Value then
  begin
    FSearchFilter := Value;
    RebuildFilteredIndices;
    Repaint;
  end;
end;

procedure THbVirtualList.AddItem(const AId, AGroupKey, AGroupTitle, ATitle, ASummary1, ASummary2: string;
  ATone: THbBadgeTone; const AStatusText: string; const ATags: TArray<string>);
var
  Item: THbVirtualListItem;
begin
  Item.Id := AId;
  Item.GroupKey := AGroupKey;
  Item.GroupTitle := AGroupTitle;
  Item.Title := ATitle;
  Item.SummaryLine1 := ASummary1;
  Item.SummaryLine2 := ASummary2;
  Item.StatusTone := ATone;
  Item.StatusText := AStatusText;
  Item.Tags := Copy(ATags);
  Item.TimestampStr := FormatDateTime('hh:nn:ss', Now);
  Item.IsSelected := False;
  Item.IsPinned := False;
  Item.Payload := '';
  FItems.Add(Item);
  RebuildFilteredIndices;
  Repaint;
end;

procedure THbVirtualList.ClearItems;
begin
  FItems.Clear;
  FFilteredIndices.Clear;
  FSelectedIndices.Clear;
  Repaint;
end;

procedure THbVirtualList.SelectItem(AIndex: Integer; AAccumulate: Boolean);
begin
  if (AIndex >= 0) and (AIndex < FItems.Count) then
  begin
    if not AAccumulate then
      FSelectedIndices.Clear;

    if FSelectedIndices.Contains(AIndex) then
      FSelectedIndices.Remove(AIndex)
    else
      FSelectedIndices.Add(AIndex);

    if Assigned(FOnSelectionChange) then
      FOnSelectionChange(Self, GetSelectedIds);
    Repaint;
  end;
end;

procedure THbVirtualList.DeselectAll;
begin
  FSelectedIndices.Clear;
  if Assigned(FOnSelectionChange) then
    FOnSelectionChange(Self, GetSelectedIds);
  Repaint;
end;

function THbVirtualList.GetSelectedIds: TArray<string>;
var
  I: Integer;
begin
  SetLength(Result, FSelectedIndices.Count);
  for I := 0 to FSelectedIndices.Count - 1 do
    Result[I] := FItems[FSelectedIndices[I]].Id;
end;

procedure THbVirtualList.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  ClickedRow, ActualIdx: Integer;
begin
  inherited;
  if Button <> TMouseButton.mbLeft then
    Exit;

  if (Y >= 10.0) and (FFilteredIndices.Count > 0) then
  begin
    ClickedRow := Trunc((Y - 10.0) / 64.0);
    if (ClickedRow >= 0) and (ClickedRow < FFilteredIndices.Count) then
    begin
      ActualIdx := FFilteredIndices[ClickedRow];
      SelectItem(ActualIdx, (ssShift in Shift) or (ssCtrl in Shift));
    end;
  end;
end;

procedure THbVirtualList.DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens);
var
  I, ItemIdx: Integer;
  CurY: Single;
  Item: THbVirtualListItem;
  RowRect: TRectF;
  IsSel: Boolean;
begin
  // Background
  Canvas.Fill.Color := Tokens.Surface;
  Canvas.Fill.Kind := TBrushKind.Solid;
  Canvas.FillRect(ARect, 0, 0, [], 1.0);

  CurY := ARect.Top + 10.0;
  for I := 0 to FFilteredIndices.Count - 1 do
  begin
    if CurY + 60.0 > ARect.Bottom then
      Break;

    ItemIdx := FFilteredIndices[I];
    Item := FItems[ItemIdx];
    IsSel := FSelectedIndices.Contains(ItemIdx);

    RowRect := RectF(ARect.Left + 8.0, CurY, ARect.Right - 8.0, CurY + 58.0);

    if IsSel then
      Canvas.Fill.Color := Tokens.Soft
    else
      Canvas.Fill.Color := Tokens.SurfaceAlt;

    Canvas.FillRect(RowRect, Tokens.RadiusS, Tokens.RadiusS, AllCorners, 1.0);

    // Title
    Canvas.Fill.Color := Tokens.Ink;
    Canvas.Font.Size := 12;
    Canvas.Font.Family := Tokens.FontFamily;
    Canvas.FillText(RectF(RowRect.Left + 16, RowRect.Top + 8, RowRect.Right - 100, RowRect.Top + 28),
      Item.Title, False, 1.0, [], TTextAlign.Leading);

    // Summary
    Canvas.Fill.Color := Tokens.InkMuted;
    Canvas.Font.Size := 10;
    Canvas.FillText(RectF(RowRect.Left + 16, RowRect.Top + 30, RowRect.Right - 16, RowRect.Top + 48),
      Item.SummaryLine1, False, 1.0, [], TTextAlign.Leading);

    CurY := CurY + 64.0;
  end;
end;

end.
