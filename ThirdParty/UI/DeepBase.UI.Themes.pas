unit DeepBase.UI.Themes;

{*******************************************************************************
  DeepBase UI Theme Package
  
  Provides modern UI themes for VCL applications:
    - Material Design themes
    - Fluent Design themes
    - macOS-style themes
    - Custom theme creation
    - Theme switching at runtime
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.UITypes,
  Vcl.Graphics, Vcl.Themes, Vcl.Styles, Vcl.Controls, Vcl.Forms,
  DeepBase.Exceptions;

type
  TThemeColorScheme = (tcsLight, tcsDark, tcsAuto);
  
  TThemeAccentColor = (
    tacBlue, tacRed, tacGreen, tacOrange, tacPurple, tacPink, 
    tacTeal, tacCyan, tacAmber, tacIndigo, tacCustom
  );

  TThemeColors = record
    Primary: TColor;
    PrimaryLight: TColor;
    PrimaryDark: TColor;
    Secondary: TColor;
    Background: TColor;
    Surface: TColor;
    Error: TColor;
    OnPrimary: TColor;
    OnSecondary: TColor;
    OnBackground: TColor;
    OnSurface: TColor;
    OnError: TColor;
    Border: TColor;
    Divider: TColor;
    Shadow: TColor;
    Overlay: TColor;
    
    class function Light: TThemeColors; static;
    class function Dark: TThemeColors; static;
    class function FromAccent(AAccent: TThemeAccentColor; AScheme: TThemeColorScheme): TThemeColors; static;
  end;

  TThemeTypography = record
    FontFamily: string;
    FontSizeH1: Integer;
    FontSizeH2: Integer;
    FontSizeH3: Integer;
    FontSizeH4: Integer;
    FontSizeBody: Integer;
    FontSizeCaption: Integer;
    FontSizeButton: Integer;
    LineHeight: Double;
    LetterSpacing: Double;
    
    class function Default: TThemeTypography; static;
    class function Compact: TThemeTypography; static;
    class function Comfortable: TThemeTypography; static;
  end;

  TThemeSpacing = record
    XS: Integer;  // 4
    SM: Integer;  // 8
    MD: Integer;  // 16
    LG: Integer;  // 24
    XL: Integer;  // 32
    XXL: Integer; // 48
    BorderRadius: Integer;
    BorderWidth: Integer;
    
    class function Default: TThemeSpacing; static;
    class function Compact: TThemeSpacing; static;
  end;

  TThemeShadow = record
    Elevation1: string;
    Elevation2: string;
    Elevation3: string;
    Elevation4: string;
    
    class function Default: TThemeShadow; static;
  end;

  TThemeDefinition = record
    Name: string;
    DisplayName: string;
    Version: string;
    Author: string;
    ColorScheme: TThemeColorScheme;
    Colors: TThemeColors;
    Typography: TThemeTypography;
    Spacing: TThemeSpacing;
    Shadows: TThemeShadow;
    VclStyleName: string;
  end;

  TThemeChangeEvent = procedure(Sender: TObject; const AThemeName: string) of object;

  TDeepBaseThemeManager = class
  private
    class var FInstance: TDeepBaseThemeManager;
    class var FThemes: TDictionary<string, TThemeDefinition>;
    class var FCurrentTheme: string;
    class var FOnThemeChange: TThemeChangeEvent;
    
    class constructor Create;
    class destructor Destroy;
    
    class procedure ApplyColorsToForm(AForm: TForm; const AColors: TThemeColors);
    class procedure ApplyTypographyToForm(AForm: TForm; const ATypography: TThemeTypography);
  public
    class procedure RegisterTheme(const ATheme: TThemeDefinition);
    class procedure UnregisterTheme(const AName: string);
    class function GetTheme(const AName: string): TThemeDefinition;
    class function GetThemeNames: TArray<string>;
    class function ThemeExists(const AName: string): Boolean;
    
    class procedure ApplyTheme(const AName: string); overload;
    class procedure ApplyTheme(const AName: string; AForm: TForm); overload;
    class procedure ApplyThemeToControl(AControl: TControl; const AColors: TThemeColors);
    
    class function GetCurrentTheme: string;
    class function GetCurrentColors: TThemeColors;
    class function GetCurrentTypography: TThemeTypography;
    class function GetCurrentSpacing: TThemeSpacing;
    
    class function IsDarkTheme: Boolean;
    class procedure ToggleDarkMode;
    
    class property OnThemeChange: TThemeChangeEvent read FOnThemeChange write FOnThemeChange;
  end;

  TMaterialThemes = class
  public
    class function Light: TThemeDefinition;
    class function Dark: TThemeDefinition;
    class function BlueLight: TThemeDefinition;
    class function BlueDark: TThemeDefinition;
    class function IndigoLight: TThemeDefinition;
    class function IndigoDark: TThemeDefinition;
    class function TealLight: TThemeDefinition;
    class function TealDark: TThemeDefinition;
    class function DeepOrangeLight: TThemeDefinition;
    class function DeepOrangeDark: TThemeDefinition;
  end;

  TFluentThemes = class
  public
    class function Light: TThemeDefinition;
    class function Dark: TThemeDefinition;
    class function AcrylicLight: TThemeDefinition;
    class function AcrylicDark: TThemeDefinition;
  end;

  TMacOSThemes = class
  public
    class function Light: TThemeDefinition;
    class function Dark: TThemeDefinition;
    class function BigSurLight: TThemeDefinition;
    class function BigSurDark: TThemeDefinition;
  end;

procedure RegisterBuiltInThemes;
function ColorToHex(AColor: TColor): string;
function HexToColor(const AHex: string): TColor;
function BlendColors(AColor1, AColor2: TColor; ABlend: Byte): TColor;
function DarkenColor(AColor: TColor; APercent: Integer): TColor;
function LightenColor(AColor: TColor; APercent: Integer): TColor;

implementation

uses
  Winapi.Windows, System.Math;

type
  TControlAccess = class(TWinControl);

const
  // Material Design Colors
  clMaterialBlue = $D32F2F;      // #2196F3
  clMaterialRed = $3F51F4;       // #F44336
  clMaterialGreen = $4CAF50;
  clMaterialOrange = $FF9800;
  clMaterialPurple = $9C27B0;
  clMaterialPink = $E91E63;
  clMaterialTeal = $009688;
  clMaterialCyan = $00BCD4;
  clMaterialAmber = $FFC107;
  clMaterialIndigo = $3F51B5;

{ TThemeColors }

class function TThemeColors.Light: TThemeColors;
begin
  Result.Primary := $D32F2F;      // Blue
  Result.PrimaryLight := $D6E4FF;
  Result.PrimaryDark := $0D47A1;
  Result.Secondary := $E91E63;
  Result.Background := $FAFAFA;
  Result.Surface := $FFFFFF;
  Result.Error := $F44336;
  Result.OnPrimary := $FFFFFF;
  Result.OnSecondary := $FFFFFF;
  Result.OnBackground := $212121;
  Result.OnSurface := $212121;
  Result.OnError := $FFFFFF;
  Result.Border := $E0E0E0;
  Result.Divider := $EEEEEE;
  Result.Shadow := $00000020;
  Result.Overlay := $00000080;
end;

class function TThemeColors.Dark: TThemeColors;
begin
  Result.Primary := $BB86FC;
  Result.PrimaryLight := $E1BEE7;
  Result.PrimaryDark := $7B1FA2;
  Result.Secondary := $03DAC6;
  Result.Background := $121212;
  Result.Surface := $1E1E1E;
  Result.Error := $CF6679;
  Result.OnPrimary := $000000;
  Result.OnSecondary := $000000;
  Result.OnBackground := $E0E0E0;
  Result.OnSurface := $E0E0E0;
  Result.OnError := $000000;
  Result.Border := $424242;
  Result.Divider := $303030;
  Result.Shadow := $00000040;
  Result.Overlay := $FFFFFF10;
end;

class function TThemeColors.FromAccent(AAccent: TThemeAccentColor; 
  AScheme: TThemeColorScheme): TThemeColors;
const
  AccentColors: array[TThemeAccentColor] of TColor = (
    $D32F2F,   // Blue
    $3F51F4,   // Red
    $4CAF50,   // Green
    $FF9800,   // Orange
    $9C27B0,   // Purple
    $E91E63,   // Pink
    $009688,   // Teal
    $00BCD4,   // Cyan
    $FFC107,   // Amber
    $3F51B5,   // Indigo
    $2196F3    // Custom (default to blue)
  );
begin
  if AScheme = tcsDark then
    Result := Dark
  else
    Result := Light;
  
  Result.Primary := AccentColors[AAccent];
  Result.PrimaryLight := LightenColor(Result.Primary, 30);
  Result.PrimaryDark := DarkenColor(Result.Primary, 30);
end;

{ TThemeTypography }

class function TThemeTypography.Default: TThemeTypography;
begin
  Result.FontFamily := 'Segoe UI';
  Result.FontSizeH1 := 32;
  Result.FontSizeH2 := 24;
  Result.FontSizeH3 := 20;
  Result.FontSizeH4 := 16;
  Result.FontSizeBody := 14;
  Result.FontSizeCaption := 12;
  Result.FontSizeButton := 14;
  Result.LineHeight := 1.5;
  Result.LetterSpacing := 0;
end;

class function TThemeTypography.Compact: TThemeTypography;
begin
  Result := Default;
  Result.FontSizeH1 := 28;
  Result.FontSizeH2 := 20;
  Result.FontSizeH3 := 16;
  Result.FontSizeH4 := 14;
  Result.FontSizeBody := 12;
  Result.FontSizeCaption := 10;
  Result.FontSizeButton := 12;
  Result.LineHeight := 1.3;
end;

class function TThemeTypography.Comfortable: TThemeTypography;
begin
  Result := Default;
  Result.FontSizeH1 := 36;
  Result.FontSizeH2 := 28;
  Result.FontSizeH3 := 22;
  Result.FontSizeH4 := 18;
  Result.FontSizeBody := 16;
  Result.FontSizeCaption := 14;
  Result.FontSizeButton := 16;
  Result.LineHeight := 1.6;
end;

{ TThemeSpacing }

class function TThemeSpacing.Default: TThemeSpacing;
begin
  Result.XS := 4;
  Result.SM := 8;
  Result.MD := 16;
  Result.LG := 24;
  Result.XL := 32;
  Result.XXL := 48;
  Result.BorderRadius := 4;
  Result.BorderWidth := 1;
end;

class function TThemeSpacing.Compact: TThemeSpacing;
begin
  Result.XS := 2;
  Result.SM := 4;
  Result.MD := 8;
  Result.LG := 12;
  Result.XL := 16;
  Result.XXL := 24;
  Result.BorderRadius := 2;
  Result.BorderWidth := 1;
end;

{ TThemeShadow }

class function TThemeShadow.Default: TThemeShadow;
begin
  Result.Elevation1 := '0 1px 3px rgba(0,0,0,0.12), 0 1px 2px rgba(0,0,0,0.24)';
  Result.Elevation2 := '0 3px 6px rgba(0,0,0,0.15), 0 2px 4px rgba(0,0,0,0.12)';
  Result.Elevation3 := '0 10px 20px rgba(0,0,0,0.15), 0 3px 6px rgba(0,0,0,0.10)';
  Result.Elevation4 := '0 15px 25px rgba(0,0,0,0.15), 0 5px 10px rgba(0,0,0,0.05)';
end;

{ TDeepBaseThemeManager }

class constructor TDeepBaseThemeManager.Create;
begin
  FThemes := TDictionary<string, TThemeDefinition>.Create;
  FCurrentTheme := '';
end;

class destructor TDeepBaseThemeManager.Destroy;
begin
  FThemes.Free;
end;

class procedure TDeepBaseThemeManager.RegisterTheme(const ATheme: TThemeDefinition);
begin
  FThemes.AddOrSetValue(ATheme.Name, ATheme);
end;

class procedure TDeepBaseThemeManager.UnregisterTheme(const AName: string);
begin
  FThemes.Remove(AName);
end;

class function TDeepBaseThemeManager.GetTheme(const AName: string): TThemeDefinition;
begin
  if not FThemes.TryGetValue(AName, Result) then
    raise EInvalidOperationException.CreateFmt('Theme "%s" not found', [AName]);
end;

class function TDeepBaseThemeManager.GetThemeNames: TArray<string>;
begin
  Result := FThemes.Keys.ToArray;
end;

class function TDeepBaseThemeManager.ThemeExists(const AName: string): Boolean;
begin
  Result := FThemes.ContainsKey(AName);
end;

class procedure TDeepBaseThemeManager.ApplyColorsToForm(AForm: TForm; const AColors: TThemeColors);
begin
  AForm.Color := AColors.Background;
  AForm.Font.Color := AColors.OnBackground;
end;

class procedure TDeepBaseThemeManager.ApplyTypographyToForm(AForm: TForm; 
  const ATypography: TThemeTypography);
begin
  AForm.Font.Name := ATypography.FontFamily;
  AForm.Font.Size := ATypography.FontSizeBody;
end;

class procedure TDeepBaseThemeManager.ApplyTheme(const AName: string);
var
  Theme: TThemeDefinition;
  I: Integer;
begin
  Theme := GetTheme(AName);
  FCurrentTheme := AName;
  
  // Apply VCL style if specified
  if Theme.VclStyleName <> '' then
  begin
    try
      if TStyleManager.IsValidStyle(Theme.VclStyleName) then
        TStyleManager.TrySetStyle(Theme.VclStyleName);
    except
      // VCL style file not available, skip
    end;
  end;
  
  // Apply to all forms
  for I := 0 to Screen.FormCount - 1 do
  begin
    ApplyColorsToForm(Screen.Forms[I], Theme.Colors);
    ApplyTypographyToForm(Screen.Forms[I], Theme.Typography);
  end;
  
  if Assigned(FOnThemeChange) then
    FOnThemeChange(nil, AName);
end;

class procedure TDeepBaseThemeManager.ApplyTheme(const AName: string; AForm: TForm);
var
  Theme: TThemeDefinition;
begin
  Theme := GetTheme(AName);
  ApplyColorsToForm(AForm, Theme.Colors);
  ApplyTypographyToForm(AForm, Theme.Typography);
end;

class procedure TDeepBaseThemeManager.ApplyThemeToControl(AControl: TControl;
  const AColors: TThemeColors);
begin
  if AControl is TWinControl then
  begin
    TControlAccess(AControl).Color := AColors.Surface;
    TControlAccess(AControl).Font.Color := AColors.OnSurface;
  end;
end;

class function TDeepBaseThemeManager.GetCurrentTheme: string;
begin
  Result := FCurrentTheme;
end;

class function TDeepBaseThemeManager.GetCurrentColors: TThemeColors;
begin
  if FCurrentTheme <> '' then
    Result := GetTheme(FCurrentTheme).Colors
  else
    Result := TThemeColors.Light;
end;

class function TDeepBaseThemeManager.GetCurrentTypography: TThemeTypography;
begin
  if FCurrentTheme <> '' then
    Result := GetTheme(FCurrentTheme).Typography
  else
    Result := TThemeTypography.Default;
end;

class function TDeepBaseThemeManager.GetCurrentSpacing: TThemeSpacing;
begin
  if FCurrentTheme <> '' then
    Result := GetTheme(FCurrentTheme).Spacing
  else
    Result := TThemeSpacing.Default;
end;

class function TDeepBaseThemeManager.IsDarkTheme: Boolean;
var
  Theme: TThemeDefinition;
begin
  Result := False;
  if (FCurrentTheme <> '') and FThemes.TryGetValue(FCurrentTheme, Theme) then
    Result := Theme.ColorScheme = tcsDark;
end;

class procedure TDeepBaseThemeManager.ToggleDarkMode;
var
  Theme: TThemeDefinition;
  NewThemeName: string;
begin
  if FCurrentTheme = '' then Exit;
  
  Theme := GetTheme(FCurrentTheme);
  
  // Try to find corresponding dark/light theme
  if Theme.ColorScheme = tcsDark then
    NewThemeName := StringReplace(FCurrentTheme, 'Dark', 'Light', [])
  else
    NewThemeName := StringReplace(FCurrentTheme, 'Light', 'Dark', []);
  
  if ThemeExists(NewThemeName) then
    ApplyTheme(NewThemeName);
end;

{ TMaterialThemes }

class function TMaterialThemes.Light: TThemeDefinition;
begin
  Result.Name := 'MaterialLight';
  Result.DisplayName := 'Material Light';
  Result.Version := '1.0';
  Result.Author := 'DeepBase';
  Result.ColorScheme := tcsLight;
  Result.Colors := TThemeColors.Light;
  Result.Typography := TThemeTypography.Default;
  Result.Spacing := TThemeSpacing.Default;
  Result.Shadows := TThemeShadow.Default;
  Result.VclStyleName := 'Windows';
end;

class function TMaterialThemes.Dark: TThemeDefinition;
begin
  Result.Name := 'MaterialDark';
  Result.DisplayName := 'Material Dark';
  Result.Version := '1.0';
  Result.Author := 'DeepBase';
  Result.ColorScheme := tcsDark;
  Result.Colors := TThemeColors.Dark;
  Result.Typography := TThemeTypography.Default;
  Result.Spacing := TThemeSpacing.Default;
  Result.Shadows := TThemeShadow.Default;
  Result.VclStyleName := 'Windows10 Dark';
end;

class function TMaterialThemes.BlueLight: TThemeDefinition;
begin
  Result := Light;
  Result.Name := 'MaterialBlueLight';
  Result.DisplayName := 'Material Blue Light';
  Result.Colors := TThemeColors.FromAccent(tacBlue, tcsLight);
end;

class function TMaterialThemes.BlueDark: TThemeDefinition;
begin
  Result := Dark;
  Result.Name := 'MaterialBlueDark';
  Result.DisplayName := 'Material Blue Dark';
  Result.Colors := TThemeColors.FromAccent(tacBlue, tcsDark);
end;

class function TMaterialThemes.IndigoLight: TThemeDefinition;
begin
  Result := Light;
  Result.Name := 'MaterialIndigoLight';
  Result.DisplayName := 'Material Indigo Light';
  Result.Colors := TThemeColors.FromAccent(tacIndigo, tcsLight);
end;

class function TMaterialThemes.IndigoDark: TThemeDefinition;
begin
  Result := Dark;
  Result.Name := 'MaterialIndigoDark';
  Result.DisplayName := 'Material Indigo Dark';
  Result.Colors := TThemeColors.FromAccent(tacIndigo, tcsDark);
end;

class function TMaterialThemes.TealLight: TThemeDefinition;
begin
  Result := Light;
  Result.Name := 'MaterialTealLight';
  Result.DisplayName := 'Material Teal Light';
  Result.Colors := TThemeColors.FromAccent(tacTeal, tcsLight);
end;

class function TMaterialThemes.TealDark: TThemeDefinition;
begin
  Result := Dark;
  Result.Name := 'MaterialTealDark';
  Result.DisplayName := 'Material Teal Dark';
  Result.Colors := TThemeColors.FromAccent(tacTeal, tcsDark);
end;

class function TMaterialThemes.DeepOrangeLight: TThemeDefinition;
begin
  Result := Light;
  Result.Name := 'MaterialDeepOrangeLight';
  Result.DisplayName := 'Material Deep Orange Light';
  Result.Colors := TThemeColors.FromAccent(tacOrange, tcsLight);
end;

class function TMaterialThemes.DeepOrangeDark: TThemeDefinition;
begin
  Result := Dark;
  Result.Name := 'MaterialDeepOrangeDark';
  Result.DisplayName := 'Material Deep Orange Dark';
  Result.Colors := TThemeColors.FromAccent(tacOrange, tcsDark);
end;

{ TFluentThemes }

class function TFluentThemes.Light: TThemeDefinition;
begin
  Result.Name := 'FluentLight';
  Result.DisplayName := 'Fluent Light';
  Result.Version := '1.0';
  Result.Author := 'DeepBase';
  Result.ColorScheme := tcsLight;
  Result.Colors := TThemeColors.Light;
  Result.Colors.Primary := $0078D4;  // Windows Blue
  Result.Colors.Background := $F3F3F3;
  Result.Colors.Surface := $FFFFFF;
  Result.Typography := TThemeTypography.Default;
  Result.Typography.FontFamily := 'Segoe UI Variable';
  Result.Spacing := TThemeSpacing.Default;
  Result.Spacing.BorderRadius := 4;
  Result.Shadows := TThemeShadow.Default;
  Result.VclStyleName := 'Windows11 Modern Light';
end;

class function TFluentThemes.Dark: TThemeDefinition;
begin
  Result.Name := 'FluentDark';
  Result.DisplayName := 'Fluent Dark';
  Result.Version := '1.0';
  Result.Author := 'DeepBase';
  Result.ColorScheme := tcsDark;
  Result.Colors := TThemeColors.Dark;
  Result.Colors.Primary := $60CDFF;
  Result.Colors.Background := $202020;
  Result.Colors.Surface := $2D2D2D;
  Result.Typography := TThemeTypography.Default;
  Result.Typography.FontFamily := 'Segoe UI Variable';
  Result.Spacing := TThemeSpacing.Default;
  Result.Spacing.BorderRadius := 4;
  Result.Shadows := TThemeShadow.Default;
  Result.VclStyleName := 'Windows11 Modern Dark';
end;

class function TFluentThemes.AcrylicLight: TThemeDefinition;
begin
  Result := Light;
  Result.Name := 'FluentAcrylicLight';
  Result.DisplayName := 'Fluent Acrylic Light';
  Result.Colors.Background := $F9F9F9;
  Result.Colors.Overlay := $FFFFFFC0;
end;

class function TFluentThemes.AcrylicDark: TThemeDefinition;
begin
  Result := Dark;
  Result.Name := 'FluentAcrylicDark';
  Result.DisplayName := 'Fluent Acrylic Dark';
  Result.Colors.Background := $1C1C1C;
  Result.Colors.Overlay := $000000C0;
end;

{ TMacOSThemes }

class function TMacOSThemes.Light: TThemeDefinition;
begin
  Result.Name := 'MacOSLight';
  Result.DisplayName := 'macOS Light';
  Result.Version := '1.0';
  Result.Author := 'DeepBase';
  Result.ColorScheme := tcsLight;
  Result.Colors := TThemeColors.Light;
  Result.Colors.Primary := $007AFF;
  Result.Colors.Background := $F5F5F5;
  Result.Colors.Surface := $FFFFFF;
  Result.Colors.Border := $C8C8C8;
  Result.Typography := TThemeTypography.Default;
  Result.Typography.FontFamily := 'SF Pro Display';
  Result.Spacing := TThemeSpacing.Default;
  Result.Spacing.BorderRadius := 8;
  Result.Shadows := TThemeShadow.Default;
  Result.VclStyleName := 'Calypso';
end;

class function TMacOSThemes.Dark: TThemeDefinition;
begin
  Result.Name := 'MacOSDark';
  Result.DisplayName := 'macOS Dark';
  Result.Version := '1.0';
  Result.Author := 'DeepBase';
  Result.ColorScheme := tcsDark;
  Result.Colors := TThemeColors.Dark;
  Result.Colors.Primary := $0A84FF;
  Result.Colors.Background := $1E1E1E;
  Result.Colors.Surface := $2D2D2D;
  Result.Colors.Border := $3D3D3D;
  Result.Typography := TThemeTypography.Default;
  Result.Typography.FontFamily := 'SF Pro Display';
  Result.Spacing := TThemeSpacing.Default;
  Result.Spacing.BorderRadius := 8;
  Result.Shadows := TThemeShadow.Default;
  Result.VclStyleName := 'Onyx Blue';
end;

class function TMacOSThemes.BigSurLight: TThemeDefinition;
begin
  Result := Light;
  Result.Name := 'MacOSBigSurLight';
  Result.DisplayName := 'macOS Big Sur Light';
  Result.Spacing.BorderRadius := 12;
end;

class function TMacOSThemes.BigSurDark: TThemeDefinition;
begin
  Result := Dark;
  Result.Name := 'MacOSBigSurDark';
  Result.DisplayName := 'macOS Big Sur Dark';
  Result.Spacing.BorderRadius := 12;
end;

{ Helper functions }

procedure RegisterBuiltInThemes;
begin
  // Material themes
  TDeepBaseThemeManager.RegisterTheme(TMaterialThemes.Light);
  TDeepBaseThemeManager.RegisterTheme(TMaterialThemes.Dark);
  TDeepBaseThemeManager.RegisterTheme(TMaterialThemes.BlueLight);
  TDeepBaseThemeManager.RegisterTheme(TMaterialThemes.BlueDark);
  TDeepBaseThemeManager.RegisterTheme(TMaterialThemes.IndigoLight);
  TDeepBaseThemeManager.RegisterTheme(TMaterialThemes.IndigoDark);
  TDeepBaseThemeManager.RegisterTheme(TMaterialThemes.TealLight);
  TDeepBaseThemeManager.RegisterTheme(TMaterialThemes.TealDark);
  TDeepBaseThemeManager.RegisterTheme(TMaterialThemes.DeepOrangeLight);
  TDeepBaseThemeManager.RegisterTheme(TMaterialThemes.DeepOrangeDark);
  
  // Fluent themes
  TDeepBaseThemeManager.RegisterTheme(TFluentThemes.Light);
  TDeepBaseThemeManager.RegisterTheme(TFluentThemes.Dark);
  TDeepBaseThemeManager.RegisterTheme(TFluentThemes.AcrylicLight);
  TDeepBaseThemeManager.RegisterTheme(TFluentThemes.AcrylicDark);
  
  // macOS themes
  TDeepBaseThemeManager.RegisterTheme(TMacOSThemes.Light);
  TDeepBaseThemeManager.RegisterTheme(TMacOSThemes.Dark);
  TDeepBaseThemeManager.RegisterTheme(TMacOSThemes.BigSurLight);
  TDeepBaseThemeManager.RegisterTheme(TMacOSThemes.BigSurDark);
end;

function ColorToHex(AColor: TColor): string;
begin
  Result := '#' + IntToHex(GetRValue(AColor), 2) + 
            IntToHex(GetGValue(AColor), 2) +
            IntToHex(GetBValue(AColor), 2);
end;

function HexToColor(const AHex: string): TColor;
var
  S: string;
begin
  S := AHex;
  if S.StartsWith('#') then
    Delete(S, 1, 1);
  Result := RGB(
    StrToInt('$' + Copy(S, 1, 2)),
    StrToInt('$' + Copy(S, 3, 2)),
    StrToInt('$' + Copy(S, 5, 2))
  );
end;

function BlendColors(AColor1, AColor2: TColor; ABlend: Byte): TColor;
var
  R1, G1, B1, R2, G2, B2: Byte;
begin
  R1 := GetRValue(AColor1);
  G1 := GetGValue(AColor1);
  B1 := GetBValue(AColor1);
  R2 := GetRValue(AColor2);
  G2 := GetGValue(AColor2);
  B2 := GetBValue(AColor2);
  
  Result := RGB(
    R1 + MulDiv(R2 - R1, ABlend, 255),
    G1 + MulDiv(G2 - G1, ABlend, 255),
    B1 + MulDiv(B2 - B1, ABlend, 255)
  );
end;

function DarkenColor(AColor: TColor; APercent: Integer): TColor;
begin
  Result := BlendColors(AColor, clBlack, MulDiv(255, APercent, 100));
end;

function LightenColor(AColor: TColor; APercent: Integer): TColor;
begin
  Result := BlendColors(AColor, clWhite, MulDiv(255, APercent, 100));
end;

end.
