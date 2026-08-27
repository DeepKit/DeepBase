{ ============================================================================
  DeepBase.FMX.HB.Palettes - FMX Adapter for Built-in 10 Theme Palettes

  Version: 1.0 (Delphi 13.1 on Win64 / Cross-Platform FMX)
  Description: Re-exports and registers the shared 10 built-in theme palettes
               from DeepBase.HB.Palettes for FireMonkey applications.
  ============================================================================ }

unit DeepBase.FMX.HB.Palettes;

interface

uses
  System.SysUtils,
  System.Classes,
  DeepBase.HB.Palettes;

procedure RegisterBuiltInThemes; inline;

implementation

procedure RegisterBuiltInThemes;
begin
  DeepBase.HB.Palettes.RegisterBuiltInThemes;
end;

initialization
  RegisterBuiltInThemes;

end.
