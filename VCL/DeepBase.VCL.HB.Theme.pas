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
  THbGranularity = DeepBase.HB.Core.THbGranularity;
  THbEaseMode = DeepBase.HB.Core.THbEaseMode;
  THbTokens = DeepBase.HB.Core.THbTokens;
  THbThemeMetadata = DeepBase.HB.Core.THbThemeMetadata;
  THbThemeDefinition = DeepBase.HB.Core.THbThemeDefinition;
  THbThemeChangeEvent = DeepBase.HB.Core.THbThemeChangeEvent;
  THbThemeChangedMessage = DeepBase.HB.Core.THbThemeChangedMessage;
  THbGranularityChangedMessage = DeepBase.HB.Core.THbGranularityChangedMessage;
  THbOverrideHook = DeepBase.HB.Core.THbOverrideHook;
  THbTheme = DeepBase.HB.Core.THbTheme;

function CalculateContrastRatio(AColor1, AColor2: TAlphaColor): Double; inline;
function RelativeLuminance(AColor: TAlphaColor): Double; inline;
function AlphaColorToColor(AColor: TAlphaColor): TColor; inline;
function GetHbSeedColor(const ASeed: string; const ATokens: THbTokens): TAlphaColor; inline;
function BlendAlphaColor(AColor1, AColor2: TAlphaColor; ARatio: Single): TAlphaColor; inline;
procedure RegisterThemeOverride(const AThemeId: string; const AOverrideTokens: THbTokens); inline;
procedure RegisterThemeOverrideHook(AHook: THbOverrideHook); inline;
procedure ClearThemeOverrides; inline;

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

function GetHbSeedColor(const ASeed: string; const ATokens: THbTokens): TAlphaColor;
begin
  Result := DeepBase.HB.Core.GetHbSeedColor(ASeed, ATokens);
end;

function BlendAlphaColor(AColor1, AColor2: TAlphaColor; ARatio: Single): TAlphaColor;
begin
  Result := DeepBase.HB.Core.BlendAlphaColor(AColor1, AColor2, ARatio);
end;

procedure RegisterThemeOverride(const AThemeId: string; const AOverrideTokens: THbTokens);
begin
  THbTheme.RegisterOverride(AThemeId, AOverrideTokens);
end;

procedure RegisterThemeOverrideHook(AHook: THbOverrideHook);
begin
  THbTheme.RegisterOverrideHook(AHook);
end;

procedure ClearThemeOverrides;
begin
  THbTheme.ClearOverrides;
end;

end.
