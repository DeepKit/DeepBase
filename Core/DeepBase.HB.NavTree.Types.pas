{ ============================================================================
  DeepBase.HB.NavTree.Types - Multi-Tree Navigation Contract Types

  Version: 1.0 (Delphi 13.1 on Win64 / Cross-Platform RTL)
  Description: Contracts for THbNavTree (240px expanded ⇄ 48px Mini Rail)
  ============================================================================ }

unit DeepBase.HB.NavTree.Types;

interface

uses
  System.SysUtils,
  System.Classes,
  DeepBase.HB.Core;

type
  /// <summary>
  /// Classification of navigation tree node.
  /// </summary>
  THbNavNodeKind = (
    nnSectionHeader,  // Uppercase section category header
    nnItem,           // Standard navigable node
    nnDivider         // Visual separator line
  );

  /// <summary>
  /// Navigation item data record.
  /// </summary>
  THbNavItemData = record
    Id: string;
    ParentId: string;
    Title: string;
    Kind: THbNavNodeKind;
    IconSvg: string;
    BadgeText: string;
    BadgeTone: THbBadgeTone;
    ShortcutText: string;
    IsExpanded: Boolean;
    IsSelected: Boolean;
    IsVisible: Boolean;
    Tag: NativeInt;
  end;

implementation

end.
