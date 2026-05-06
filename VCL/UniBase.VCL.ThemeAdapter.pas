{ ============================================================================
  UniBase.VCL.ThemeAdapter - VCL adapter for UniBase.Theme
  ============================================================================ }

unit UniBase.VCL.ThemeAdapter;

interface

procedure RegisterUniBaseVCLThemeAdapter;

implementation

uses
  System.SysUtils,
  Vcl.Themes,
  UniBase.Types,
  UniBase.Theme;

function VclStyleExists(const StyleName: string): Boolean;
var
  Names: TArray<string>;
  Name: string;
begin
  if SameText(StyleName, 'Windows') then
    Exit(True);

  Names := TStyleManager.StyleNames;
  for Name in Names do
    if SameText(Name, StyleName) then
      Exit(True);

  Result := False;
end;

function BuildThemeInfo(const StyleName: string): TThemeInfo;
var
  UpperName: string;
begin
  Result.Name := StyleName;
  Result.StyleFile := '';
  Result.IsBuiltIn := True;
  UpperName := StyleName.ToUpperInvariant;
  Result.IsDark :=
    UpperName.Contains('DARK') or
    UpperName.Contains('BLACK') or
    UpperName.Contains('CARBON') or
    UpperName.Contains('SLATE');
end;

function ApplyVclTheme(const ThemeName: string;
  out ActiveThemeName: string): Boolean;
begin
  ActiveThemeName := ThemeName;
  if not VclStyleExists(ActiveThemeName) then
    ActiveThemeName := 'Windows';

  Result := TStyleManager.TrySetStyle(ActiveThemeName);
  if (not Result) and (not SameText(ActiveThemeName, 'Windows')) then
  begin
    ActiveThemeName := 'Windows';
    Result := TStyleManager.TrySetStyle(ActiveThemeName);
  end;
end;

function ListVclThemes: TThemeInfoArray;
var
  Names: TArray<string>;
  I: Integer;
begin
  Names := TStyleManager.StyleNames;
  SetLength(Result, Length(Names));
  for I := 0 to High(Names) do
    Result[I] := BuildThemeInfo(Names[I]);
end;

function CurrentVclTheme: string;
begin
  if Assigned(TStyleManager.ActiveStyle) then
    Result := TStyleManager.ActiveStyle.Name
  else
    Result := 'Windows';
end;

procedure RegisterUniBaseVCLThemeAdapter;
begin
  TUniBaseTheme.SetPlatformAdapter(
    ApplyVclTheme,
    ListVclThemes,
    VclStyleExists,
    CurrentVclTheme);
end;

initialization
  RegisterUniBaseVCLThemeAdapter;

end.
