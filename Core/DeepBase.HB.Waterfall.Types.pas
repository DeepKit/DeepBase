{ ============================================================================
  DeepBase.HB.Waterfall.Types - Faceted Waterfall Core Contract Types

  Version: 1.0 (Delphi 13.1 on Win64 / Cross-Platform RTL)
  Description: Contract types for THbFacetWaterfall:
               - Facet categories (Focus, Exclude non-A, count badge)
               - Dual modes (wmSectioned, wmTimeline)
               - Waterfall items with summary, details, and Diff/Quote tags
  ============================================================================ }

unit DeepBase.HB.Waterfall.Types;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  DeepBase.HB.Core;

type
  /// <summary>
  /// Waterfall presentation mode.
  /// </summary>
  THbWaterfallMode = (
    wmSectioned,  // Grouped by categories with section headers
    wmTimeline    // Blended chronological feed with category chips
  );

  /// <summary>
  /// Single facet category item in the left rail.
  /// </summary>
  THbFacetCategory = record
    Id: string;
    Title: string;
    Count: Integer;
    IconSvg: string;
    IsExcluded: Boolean;
    IsFocused: Boolean;
  end;

  /// <summary>
  /// State of an individual waterfall item.
  /// </summary>
  THbWaterfallItemState = (
    wisNormal,
    wisActive,
    wisCompleted,
    wisWarning,
    wisBlocked,
    wisDiscarded
  );

  /// <summary>
  /// Kind of external interface/resource link on a card.
  /// </summary>
  THbWaterfallLinkKind = (
    wlkNone,
    wlkDoc,      // Document / Specification
    wlkUrl,      // Web URL
    wlkSymbol,   // Source code symbol / unit
    wlkTask      // Workorder / Task ID
  );

  /// <summary>
  /// Key-value property metadata for right inspector panel.
  /// </summary>
  THbCardProperty = record
    Key: string;
    Value: string;
    class function Create(const AKey, AValue: string): THbCardProperty; static;
  end;

  /// <summary>
  /// Data record for a single waterfall card.
  /// </summary>
  THbWaterfallCardData = record
    Id: string;
    CategoryId: string;
    CategoryTitle: string;
    Title: string;
    SummaryText: string;
    DetailText: string;
    QuoteSource: string;
    TimestampStr: string;
    State: THbWaterfallItemState;
    BadgeTone: THbBadgeTone;
    IsExpanded: Boolean; // True = Right-side detail expanded downwards
    ParentId: string;    // Empty = Root card (backward-compatible)
    Depth: Integer;      // Hierarchy depth: 0 = L0, 1 = L1, ..., 5 = L5
    Collapsed: Boolean;  // True if child cards are folded
    HasChildren: Boolean;// True if card has nested sub-cards
    LinkKind: THbWaterfallLinkKind; // Interface link kind
    LinkTarget: string;             // Target document/URL/symbol
    Properties: TArray<THbCardProperty>; // Metadata for inspector panel
    Tag: NativeInt;
  end;

implementation

{ THbCardProperty }

class function THbCardProperty.Create(const AKey, AValue: string): THbCardProperty;
begin
  Result.Key := AKey;
  Result.Value := AValue;
end;

end.
