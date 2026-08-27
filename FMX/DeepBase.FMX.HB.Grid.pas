{ ============================================================================
  DeepBase.FMX.HB.Grid - High-Performance Virtual Data Grid for FMX

  Version: 1.0 (Delphi 13.1 on Win64 / Cross-Platform)
  Description: THbFmxDataGrid for FMX.
  ============================================================================ }

unit DeepBase.FMX.HB.Grid;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  DeepBase.HB.Core,
  DeepBase.HB.Grid.Types,
  DeepBase.FMX.HB.Theme;

type
  /// <summary>
  /// THbFmxDataGrid: Virtual Data Grid for FMX.
  /// </summary>
  THbFmxDataGrid = class(TControl)
  private
    FColumns: TList<THbGridColumnDef>;
    FRowCount: Integer;
    FSelectedRows: TList<Integer>;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure AddColumn(const AField, ATitle: string; AWidth: Integer = 120;
      AType: THbGridColumnType = gctText);
    procedure ClearColumns;

    function ComputeSelectionStats: THbGridStats;
    procedure SelectRow(ARowIndex: Integer; AAddToSelection: Boolean = False);
    procedure ClearSelection;

    property Columns: TList<THbGridColumnDef> read FColumns;
    property SelectedRows: TList<Integer> read FSelectedRows;
  published
    property Align;
    property RowCount: Integer read FRowCount write FRowCount default 0;
  end;

implementation

{ THbFmxDataGrid }

constructor THbFmxDataGrid.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 600;
  Height := 350;
  FRowCount := 0;
  FColumns := TList<THbGridColumnDef>.Create;
  FSelectedRows := TList<Integer>.Create;
end;

destructor THbFmxDataGrid.Destroy;
begin
  FSelectedRows.Free;
  FColumns.Free;
  inherited;
end;

procedure THbFmxDataGrid.AddColumn(const AField, ATitle: string; AWidth: Integer; AType: THbGridColumnType);
var
  Col: THbGridColumnDef;
begin
  Col.Field := AField;
  Col.Title := ATitle;
  Col.Width := AWidth;
  Col.ColType := AType;
  Col.Alignment := taLeftJustify;
  Col.IsFrozen := False;
  Col.IsSortable := True;
  Col.IsFilterable := True;
  Col.SortOrder := gsoNone;
  Col.Visible := True;
  FColumns.Add(Col);
end;

procedure THbFmxDataGrid.ClearColumns;
begin
  FColumns.Clear;
end;

procedure THbFmxDataGrid.SelectRow(ARowIndex: Integer; AAddToSelection: Boolean);
begin
  if not AAddToSelection then
    FSelectedRows.Clear;

  if (ARowIndex >= 0) and (ARowIndex < FRowCount) then
  begin
    if not FSelectedRows.Contains(ARowIndex) then
      FSelectedRows.Add(ARowIndex);
  end;
end;

procedure THbFmxDataGrid.ClearSelection;
begin
  FSelectedRows.Clear;
end;

function THbFmxDataGrid.ComputeSelectionStats: THbGridStats;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.SelectedRowCount := FSelectedRows.Count;
end;

end.
