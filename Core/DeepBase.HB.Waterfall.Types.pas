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
    IsExpanded: Boolean;
    Tag: NativeInt;
  end;

implementation

end.
