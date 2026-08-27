{ ============================================================================
  DeepBase.HB.Grid.Types - High-Performance Data Grid Contract Types

  Version: 1.0 (Delphi 13.1 on Win64 / Cross-Platform RTL)
  Description: Shared contracts for Excel-like virtual grid:
               - Column definitions & formatting types
               - Cell selection & multi-cell statistical aggregations
  ============================================================================ }

unit DeepBase.HB.Grid.Types;

interface

uses
  System.SysUtils,
  System.Classes,
  System.UITypes,
  System.Generics.Collections,
  DeepBase.HB.Core;

type
  /// <summary>
  /// Visual cell display type in the data grid.
  /// </summary>
  THbGridColumnType = (
    gctText,        // Standard string
    gctInteger,     // Integer number
    gctFloat,       // Floating number / Currency
    gctHeatBar,     // Horizontal progress / heatmap data bar
    gctBadge,       // Pill badge with tone
    gctButton,      // Clickable action button in cell
    gctCheckbox     // Boolean toggle
  );

  /// <summary>
  /// Column sort order.
  /// </summary>
  THbGridSortOrder = (gsoNone, gsoAscending, gsoDescending);

  /// <summary>
  /// Column definition in the grid.
  /// </summary>
  THbGridColumnDef = record
    Field: string;
    Title: string;
    Width: Integer;
    ColType: THbGridColumnType;
    Alignment: TAlignment;
    IsFrozen: Boolean;
    IsSortable: Boolean;
    IsFilterable: Boolean;
    SortOrder: THbGridSortOrder;
    Visible: Boolean;
  end;

  /// <summary>
  /// Cell selection rectangle (Row/Col indices).
  /// </summary>
  THbGridSelection = record
    StartRow: Integer;
    EndRow: Integer;
    StartCol: Integer;
    EndCol: Integer;
  end;

  /// <summary>
  /// Aggregated statistics computed on the current cell selection.
  /// </summary>
  THbGridStats = record
    SelectedRowCount: Integer;
    SelectedCellCount: Integer;
    NumericCount: Integer;
    SumValue: Double;
    AvgValue: Double;
    MinValue: Double;
    MaxValue: Double;
  end;

implementation

end.
