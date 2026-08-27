{ ============================================================================
  DeepBase.VCL.HB.Palettes - VCL Adapter for Built-in 10 Theme Palettes

  Version: 1.0 (Delphi 13.1 on Win64)
  Description: Re-exports and registers the shared 10 built-in theme palettes
               from DeepBase.HB.Palettes for VCL backward compatibility.
  ============================================================================ }

unit DeepBase.VCL.HB.Palettes;

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
