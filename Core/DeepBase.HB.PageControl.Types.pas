{ ============================================================================
  DeepBase.HB.PageControl.Types - Modern Tab & PageControl Contract Types

  Version: 1.0 (Delphi 13.1 on Win64 / Cross-Platform RTL)
  Description: Contracts for 4 styles of THbPageControl:
               - tsUnderline (Industrial console minimal)
               - tsSegmented (Capsule pill switcher)
               - tsCard (Embossed card tabs)
               - tsChrome (Closable multi-tab IDE style)
  ============================================================================ }

unit DeepBase.HB.PageControl.Types;

interface

uses
  System.SysUtils,
  System.Classes,
  DeepBase.HB.Core;

type
  /// <summary>
  /// Modern tab visual styles.
  /// </summary>
  THbTabStyle = (
    tsUnderline,  // Text with bottom active indicator bar
    tsSegmented,  // Pill capsule inside sunken track
    tsCard,       // Embossed card style tabs
    tsChrome      // Browser/IDE style with 'x' close button
  );

  /// <summary>
  /// Tab header orientation.
  /// </summary>
  THbTabOrientation = (toTop, toBottom, toLeft, toRight);

  /// <summary>
  /// Single tab item definition.
  /// </summary>
  THbTabItemData = record
    Id: string;
    Title: string;
    IconSvg: string;
    BadgeCount: Integer;
    IsClosable: Boolean;
    IsEnabled: Boolean;
    IsVisible: Boolean;
    Tag: NativeInt;
  end;

implementation

end.
