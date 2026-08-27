{ ============================================================================
  DeepBase.HB.Tray.Types - Universal Tray Icon & Token Menu Contract Types

  Version: 1.0 (Delphi 13.1 on Win64 / Cross-Platform RTL)
  Description: Shared contracts for modern token-driven tray icon and popup menu:
               - Multi-zone items (Header status, Action, Separator, Check, Radio)
               - Dynamic badge dots (breathing green, unread red badge)
               - Smart multi-monitor positioning & no-focus-stealing dismiss
  ============================================================================ }

unit DeepBase.HB.Tray.Types;

interface

uses
  System.SysUtils,
  System.Classes,
  System.UITypes,
  DeepBase.HB.Core;

type
  /// <summary>
  /// Types of items in the modern HB tray menu.
  /// </summary>
  THbTrayItemKind = (
    tikHeader,      // Status header (App name, state badge, subtitle)
    tikItem,        // Standard clickable action
    tikSeparator,   // Divider line
    tikCheck,       // Toggle checkable item
    tikRadio        // Radio selectable item
  );

  /// <summary>
  /// Header status configuration for tray menu.
  /// </summary>
  THbTrayHeaderData = record
    Title: string;
    Subtitle: string;
    VersionText: string;
    Tone: THbBadgeTone;
    HasBreathingDot: Boolean;
    Visible: Boolean;
  end;

  /// <summary>
  /// Single item definition in the tray popup menu.
  /// </summary>
  THbTrayMenuItemData = record
    Id: string;
    Caption: string;
    ShortcutText: string;
    Kind: THbTrayItemKind;
    IsDefault: Boolean;      // Rendered in bold (e.g. Open Main Console)
    IsChecked: Boolean;      // Checked state for tikCheck/tikRadio
    IsDestructive: Boolean;  // Rendered in danger red on hover (e.g. Exit)
    IsEnabled: Boolean;
    BadgeText: string;
    BadgeTone: THbBadgeTone;
    Tag: NativeInt;
  end;

  /// <summary>
  /// Taskbar edge location relative to the current monitor.
  /// </summary>
  THbTaskbarEdge = (tbeBottom, tbeTop, tbeLeft, tbeRight, tbeUnknown);

implementation

end.
