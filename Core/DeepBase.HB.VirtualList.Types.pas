{ ============================================================================
  DeepBase.HB.VirtualList.Types - Core Types for Virtual Review & Candidate Queue
  
  Version: 1.0 (Delphi 13.1 on Win64 / Cross-Platform RTL)
  Description: Framework-agnostic type definitions for high-performance virtual
               review list, candidate queue, batch selection, and tag chips.
  ============================================================================ }

unit DeepBase.HB.VirtualList.Types;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  DeepBase.HB.Core;

type
  /// <summary>
  /// Action button descriptor for virtual list item row.
  /// </summary>
  THbVirtualListAction = record
    ActionKey: string;
    Caption: string;
    Tone: THbBadgeTone;
    Shortcut: string;
  end;

  /// <summary>
  /// Single item representing a candidate / review ticket in virtual list.
  /// </summary>
  THbVirtualListItem = record
    Id: string;
    GroupKey: string;
    GroupTitle: string;
    StatusTone: THbBadgeTone;
    StatusText: string;
    Title: string;
    SummaryLine1: string;
    SummaryLine2: string;
    Tags: TArray<string>;
    TimestampStr: string;
    IsSelected: Boolean;
    IsPinned: Boolean;
    Payload: string;
  end;

  /// <summary>
  /// Group bucket in virtual review list.
  /// </summary>
  THbVirtualListGroup = record
    GroupKey: string;
    GroupTitle: string;
    ItemCount: Integer;
    IsCollapsed: Boolean;
  end;

  /// <summary>
  /// Event fired when an item action button is triggered.
  /// </summary>
  THbVirtualListItemActionEvent = procedure(Sender: TObject; const AItemId, AActionKey: string) of object;

  /// <summary>
  /// Event fired when selection changes in virtual list.
  /// </summary>
  THbVirtualListSelectionEvent = procedure(Sender: TObject; const ASelectedIds: TArray<string>) of object;

  /// <summary>
  /// Event fired to retrieve an item on demand for virtual callback data sources.
  /// </summary>
  THbVirtualListGetItemEvent = procedure(Sender: TObject; AIndex: Integer; out AItem: THbVirtualListItem) of object;

implementation

end.
