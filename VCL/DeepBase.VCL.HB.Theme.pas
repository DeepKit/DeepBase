{ ============================================================================
  DeepBase.VCL.HB.Theme - VCL Adapter for HB Visual Infrastructure Theme Engine

  Version: 1.0 (Delphi 13.1 on Win64)
  Description: Re-exports shared framework-agnostic DeepBase.HB.Core tokens and
               singleton engine, with Windows-specific WM_HB_THEME_CHANGED
               message constant for VCL backward compatibility.
  ============================================================================ }

unit DeepBase.VCL.HB.Theme;

interface

uses
  System.SysUtils,
  System.Classes,
  System.UITypes,
  Winapi.Windows,
  Winapi.Messages,
  DeepBase.HB.Core;

const
  WM_HB_THEME_CHANGED = WM_USER + $07B1;

type
  THbDensity = DeepBase.HB.Core.THbDensity;
  THbEaseMode = DeepBase.HB.Core.THbEaseMode;
  THbTokens = DeepBase.HB.Core.THbTokens;
  THbThemeMetadata = DeepBase.HB.Core.THbThemeMetadata;
  THbThemeDefinition = DeepBase.HB.Core.THbThemeDefinition;
  THbThemeChangeEvent = DeepBase.HB.Core.THbThemeChangeEvent;
  THbThemeChangedMessage = DeepBase.HB.Core.THbThemeChangedMessage;
  THbTheme = DeepBase.HB.Core.THbTheme;

function CalculateContrastRatio(AColor1, AColor2: TAlphaColor): Double; inline;
function RelativeLuminance(AColor: TAlphaColor): Double; inline;
function AlphaColorToColor(AColor: TAlphaColor): TColor; inline;

implementation

function AlphaColorToColor(AColor: TAlphaColor): TColor;
begin
  Result := RGB(TAlphaColorRec(AColor).R, TAlphaColorRec(AColor).G, TAlphaColorRec(AColor).B);
end;

function CalculateContrastRatio(AColor1, AColor2: TAlphaColor): Double;
begin
  Result := DeepBase.HB.Core.CalculateContrastRatio(AColor1, AColor2);
end;

function RelativeLuminance(AColor: TAlphaColor): Double;
begin
  Result := DeepBase.HB.Core.RelativeLuminance(AColor);
end;

end.
