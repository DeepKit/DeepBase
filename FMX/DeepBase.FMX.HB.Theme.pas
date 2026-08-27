{ ============================================================================
  DeepBase.FMX.HB.Theme - FMX Adapter for HB Visual Infrastructure Theme Engine

  Version: 1.0 (Delphi 13.1 on Win64 / Cross-Platform FMX)
  Description: Re-exports shared framework-agnostic DeepBase.HB.Core tokens and
               singleton engine for FireMonkey (FMX) applications.
  ============================================================================ }

unit DeepBase.FMX.HB.Theme;

interface

uses
  System.SysUtils,
  System.Classes,
  System.UITypes,
  System.Messaging,
  FMX.Types,
  FMX.Controls,
  FMX.Graphics,
  DeepBase.HB.Core;

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

implementation

function CalculateContrastRatio(AColor1, AColor2: TAlphaColor): Double;
begin
  Result := DeepBase.HB.Core.CalculateContrastRatio(AColor1, AColor2);
end;

function RelativeLuminance(AColor: TAlphaColor): Double;
begin
  Result := DeepBase.HB.Core.RelativeLuminance(AColor);
end;

end.
