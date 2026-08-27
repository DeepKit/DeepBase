{ ============================================================================
  DeepBase.HB.Dock.Types - Docking, Floating & Window Proportions Contract Types

  Version: 1.0 (Delphi 13.1 on Win64 / Cross-Platform RTL)
  Description: Contracts for Tear-Off Docking, Magnetic Float Island, and
               Multi-Monitor Proportional Anchoring.
  ============================================================================ }

unit DeepBase.HB.Dock.Types;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types;

type
  /// <summary>
  /// Docking position inside a host site.
  /// </summary>
  THbDockPosition = (
    dpLeft,
    dpRight,
    dpTop,
    dpBottom,
    dpCenterTab,
    dpFloatWindow
  );

  /// <summary>
  /// Visual compass zones for magnetic drag-docking.
  /// </summary>
  THbDockGuideZone = (
    dgzNone,
    dgzLeft,
    dgzRight,
    dgzTop,
    dgzBottom,
    dgzCenterTab
  );

  /// <summary>
  /// Window proportional anchoring descriptor for multi-monitor consistency.
  /// </summary>
  THbWindowProportion = record
    WidthRatio: Single;       // e.g. 0.65 (65% of workarea width)
    HeightRatio: Single;      // e.g. 0.75 (75% of workarea height)
    LockAspectRatio: Boolean; // True: locks AspectRatio
    AspectRatio: Single;      // e.g. 16.0 / 10.0
    MinWidthPx: Integer;      // Minimum width safeguard (e.g. 960)
    MinHeightPx: Integer;     // Minimum height safeguard (e.g. 600)
  end;

implementation

end.
