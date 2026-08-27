{ ============================================================================
  DeepBase.HB.ShareCard.Types - Core Contracts for Offscreen Share Card Renderer
  
  Version: 1.0 (Delphi 13.1 on Win64 / Cross-Platform RTL)
  Description: Framework-agnostic contracts for offscreen card rendering,
               privacy masking, multi-aspect ratio export (16:9, 1:1, 4:5),
               and immutable watermark locking.
  ============================================================================ }

unit DeepBase.HB.ShareCard.Types;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  DeepBase.HB.Core;

type
  /// <summary>
  /// Output format specifications for share cards.
  /// </summary>
  THbShareCardFormat = (
    scfLandscape16x9, // 1920 x 1080 Desktop / presentation standard
    scfSquare1x1,     // 1080 x 1080 Social feed standard
    scfPortrait4x5    // 1080 x 1350 Mobile long-form / audit receipt standard
  );

  /// <summary>
  /// Data model for rendering an offscreen share / proof card.
  /// </summary>
  THbShareCardData = record
    Title: string;                    // Main title (e.g. 'DeepRW 认知论证体检合格证')
    Subtitle: string;                 // Subtitle or project name
    HeaderCategory: string;           // Category pill text (e.g. '7 字段法源审计')
    MetricRows: TArray<string>;       // Multi-line metrics (e.g. '门禁通过率: 100%', '主张数: 42 项')
    FooterNote: string;               // Mandatory disclaimer (e.g. '通过本地检查 ≠ 事实绝对正确')
    BadgeText: string;                // Corner badge / watermark text
    WatermarkLocked: Boolean;         // If True, caller cannot disable rendering of watermark
    LogoRef: string;                  // Optional branding logo text or glyph
    QRSlot: string;                   // Optional verification URL / hash string for QR slot
    EnableAutoMasking: Boolean;       // Automatically mask sensitive phone/ID numbers
    TimestampStr: string;             // Snapshot timestamp string
    PrimaryColorTone: THbBadgeTone;   // Color mood tone
  end;

implementation

end.
