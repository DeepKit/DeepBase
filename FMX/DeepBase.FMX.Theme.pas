unit DeepBase.FMX.Theme;

{*******************************************************************************
  DeepBase FMX Theme - Cross-Platform Theme Support

  Provides unified theme management for FMX applications across all platforms.
  Supports light/dark themes and platform-native appearance.

  Features:
  - Light/Dark theme switching
  - System theme detection
  - Custom color schemes
  - Font scaling for accessibility
  - Platform-native styling options
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.UITypes, System.Generics.Collections,
  FMX.Types, FMX.Forms, FMX.Styles, FMX.Controls, FMX.Graphics,
  DeepBase.Theme;

type
  /// <summary>Theme mode</summary>
  TUniThemeMode = (
    utmLight,
    utmDark,
    utmSystem  // Follow system theme
  );

  /// <summary>Color scheme for theming</summary>
  TUniColorScheme = record
    Primary: TAlphaColor;
    PrimaryDark: TAlphaColor;
    PrimaryLight: TAlphaColor;
    Accent: TAlphaColor;
    Background: TAlphaColor;
    Surface: TAlphaColor;
    Error: TAlphaColor;
    OnPrimary: TAlphaColor;
    OnBackground: TAlphaColor;
    OnSurface: TAlphaColor;
    OnError: TAlphaColor;
    Divider: TAlphaColor;
    class function Light: TUniColorScheme; static;
    class function Dark: TUniColorScheme; static;
  end;

  /// <summary>Typography settings</summary>
  TUniTypography = record
    FontFamily: string;
    TitleSize: Single;
    SubtitleSize: Single;
    BodySize: Single;
    CaptionSize: Single;
    ButtonSize: Single;
    ScaleFactor: Single;
    function Scaled(Size: Single): Single;
    class function Default: TUniTypography; static;
  end;

  /// <summary>Theme change event</summary>
  TThemeChangeEvent = procedure(Sender: TObject; NewMode: TUniThemeMode) of object;

  /// <summary>
  /// Cross-platform theme manager
  /// </summary>
  TUniFMXTheme = class
  private
    class var FInstance: TUniFMXTheme;
    var
    FMode: TUniThemeMode;
    FLightColors: TUniColorScheme;
    FDarkColors: TUniColorScheme;
    FTypography: TUniTypography;
    FOnThemeChange: TThemeChangeEvent;
    FAutoApply: Boolean;
    FStyleBookLight: string;
    FStyleBookDark: string;

    function GetCurrentColors: TUniColorScheme;
    function GetEffectiveMode: TUniThemeMode;
    procedure SetMode(const Value: TUniThemeMode);
    procedure ApplyThemeToForm(Form: TCommonCustomForm);
    function DetectSystemTheme: TUniThemeMode;
  public
    constructor Create;
    destructor Destroy; override;

    class function Instance: TUniFMXTheme;
    class procedure FreeInstance;

    // Theme mode
    property Mode: TUniThemeMode read FMode write SetMode;
    property EffectiveMode: TUniThemeMode read GetEffectiveMode;
    function IsDarkMode: Boolean;

    // Color schemes
    property CurrentColors: TUniColorScheme read GetCurrentColors;
    property LightColors: TUniColorScheme read FLightColors write FLightColors;
    property DarkColors: TUniColorScheme read FDarkColors write FDarkColors;
    property Typography: TUniTypography read FTypography write FTypography;

    // StyleBook paths
    property StyleBookLight: string read FStyleBookLight write FStyleBookLight;
    property StyleBookDark: string read FStyleBookDark write FStyleBookDark;

    // Auto-apply to new forms
    property AutoApply: Boolean read FAutoApply write FAutoApply;

    // Events
    property OnThemeChange: TThemeChangeEvent read FOnThemeChange write FOnThemeChange;

    // Methods
    procedure ApplyTheme(Form: TCommonCustomForm = nil);
    procedure ApplyToAllForms;
    procedure SetLightMode;
    procedure SetDarkMode;
    procedure ToggleTheme;

    // Color helpers
    function GetColor(const Name: string): TAlphaColor;
    function GetTextColor(Background: TAlphaColor): TAlphaColor;
    function Lighten(Color: TAlphaColor; Amount: Single): TAlphaColor;
    function Darken(Color: TAlphaColor; Amount: Single): TAlphaColor;
    function WithAlpha(Color: TAlphaColor; Alpha: Byte): TAlphaColor;

    // System theme
    procedure FollowSystemTheme;
  end;

/// <summary>Global theme manager accessor</summary>
function Theme: TUniFMXTheme;

implementation

uses
  System.Math,
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  FMX.Platform;

{ TUniColorScheme }

class function TUniColorScheme.Light: TUniColorScheme;
begin
  Result.Primary := $FF1976D2;       // Blue 700
  Result.PrimaryDark := $FF1565C0;   // Blue 800
  Result.PrimaryLight := $FF42A5F5;  // Blue 400
  Result.Accent := $FFFF4081;        // Pink A200
  Result.Background := $FFFAFAFA;    // Grey 50
  Result.Surface := $FFFFFFFF;       // White
  Result.Error := $FFB00020;         // Red
  Result.OnPrimary := $FFFFFFFF;     // White
  Result.OnBackground := $DE000000;  // Black 87%
  Result.OnSurface := $DE000000;     // Black 87%
  Result.OnError := $FFFFFFFF;       // White
  Result.Divider := $1F000000;       // Black 12%
end;

class function TUniColorScheme.Dark: TUniColorScheme;
begin
  Result.Primary := $FF90CAF9;       // Blue 200
  Result.PrimaryDark := $FF42A5F5;   // Blue 400
  Result.PrimaryLight := $FFBBDEFB;  // Blue 100
  Result.Accent := $FFFF80AB;        // Pink A100
  Result.Background := $FF121212;    // Dark grey
  Result.Surface := $FF1E1E1E;       // Slightly lighter
  Result.Error := $FFCF6679;         // Light red
  Result.OnPrimary := $FF000000;     // Black
  Result.OnBackground := $DEFFFFFF;  // White 87%
  Result.OnSurface := $DEFFFFFF;     // White 87%
  Result.OnError := $FF000000;       // Black
  Result.Divider := $1FFFFFFF;       // White 12%
end;

{ TUniTypography }

class function TUniTypography.Default: TUniTypography;
begin
  Result.FontFamily := 'Segoe UI';
  Result.TitleSize := 20;
  Result.SubtitleSize := 16;
  Result.BodySize := 14;
  Result.CaptionSize := 12;
  Result.ButtonSize := 14;
  Result.ScaleFactor := 1.0;
end;

function TUniTypography.Scaled(Size: Single): Single;
begin
  Result := Size * ScaleFactor;
end;

{ TUniFMXTheme }

constructor TUniFMXTheme.Create;
begin
  inherited Create;
  FMode := utmSystem;
  FLightColors := TUniColorScheme.Light;
  FDarkColors := TUniColorScheme.Dark;
  FTypography := TUniTypography.Default;
  FAutoApply := True;
end;

destructor TUniFMXTheme.Destroy;
begin
  inherited;
end;

class function TUniFMXTheme.Instance: TUniFMXTheme;
begin
  if FInstance = nil then
    FInstance := TUniFMXTheme.Create;
  Result := FInstance;
end;

class procedure TUniFMXTheme.FreeInstance;
begin
  FreeAndNil(FInstance);
end;

function TUniFMXTheme.GetCurrentColors: TUniColorScheme;
begin
  if GetEffectiveMode = utmDark then
    Result := FDarkColors
  else
    Result := FLightColors;
end;

function TUniFMXTheme.GetEffectiveMode: TUniThemeMode;
begin
  if FMode = utmSystem then
    Result := DetectSystemTheme
  else
    Result := FMode;
end;

function TUniFMXTheme.DetectSystemTheme: TUniThemeMode;
{$IFDEF MSWINDOWS}
var
  Reg: HKEY;
  Value: DWORD;
  Size: DWORD;
{$ENDIF}
begin
  Result := utmLight; // Default

  {$IFDEF MSWINDOWS}
  // Check Windows 10/11 dark mode setting
  if RegOpenKeyEx(HKEY_CURRENT_USER,
    'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize',
    0, KEY_READ, Reg) = ERROR_SUCCESS then
  try
    Size := SizeOf(Value);
    if RegQueryValueEx(Reg, 'AppsUseLightTheme', nil, nil, @Value, @Size) = ERROR_SUCCESS then
    begin
      if Value = 0 then
        Result := utmDark
      else
        Result := utmLight;
    end;
  finally
    RegCloseKey(Reg);
  end;
  {$ENDIF}

  {$IFDEF ANDROID}
  // TODO(BUG-281): Check Android dark mode
  {$ENDIF}

  {$IFDEF IOS}
  // TODO(BUG-281): Check iOS dark mode via UITraitCollection
  {$ENDIF}
end;

procedure TUniFMXTheme.SetMode(const Value: TUniThemeMode);
var
  OldMode: TUniThemeMode;
begin
  if FMode <> Value then
  begin
    OldMode := GetEffectiveMode;
    FMode := Value;

    if GetEffectiveMode <> OldMode then
    begin
      if FAutoApply then
        ApplyToAllForms;

      if Assigned(FOnThemeChange) then
        FOnThemeChange(Self, GetEffectiveMode);
    end;
  end;
end;

function TUniFMXTheme.IsDarkMode: Boolean;
begin
  Result := GetEffectiveMode = utmDark;
end;

procedure TUniFMXTheme.ApplyTheme(Form: TCommonCustomForm);
begin
  if Form <> nil then
    ApplyThemeToForm(Form)
  else
    ApplyToAllForms;
end;

procedure TUniFMXTheme.ApplyThemeToForm(Form: TCommonCustomForm);
var
  StylePath: string;
begin
  // Apply StyleBook if specified
  if IsDarkMode then
    StylePath := FStyleBookDark
  else
    StylePath := FStyleBookLight;

  if (StylePath <> '') and FileExists(StylePath) then
  begin
    // Load style from file
    // Note: In real implementation, you'd use TStyleManager.LoadFromFile
  end;

  // Apply background color
  if Form is TForm then
    TForm(Form).Fill.Color := CurrentColors.Background;
end;

procedure TUniFMXTheme.ApplyToAllForms;
var
  I: Integer;
begin
  for I := 0 to Screen.FormCount - 1 do
    ApplyThemeToForm(Screen.Forms[I]);
end;

procedure TUniFMXTheme.SetLightMode;
begin
  Mode := utmLight;
end;

procedure TUniFMXTheme.SetDarkMode;
begin
  Mode := utmDark;
end;

procedure TUniFMXTheme.ToggleTheme;
begin
  if GetEffectiveMode = utmLight then
    Mode := utmDark
  else
    Mode := utmLight;
end;

procedure TUniFMXTheme.FollowSystemTheme;
begin
  Mode := utmSystem;
end;

function TUniFMXTheme.GetColor(const Name: string): TAlphaColor;
var
  Colors: TUniColorScheme;
  LowerName: string;
begin
  Colors := CurrentColors;
  LowerName := LowerCase(Name);

  if LowerName = 'primary' then Result := Colors.Primary
  else if LowerName = 'primarydark' then Result := Colors.PrimaryDark
  else if LowerName = 'primarylight' then Result := Colors.PrimaryLight
  else if LowerName = 'accent' then Result := Colors.Accent
  else if LowerName = 'background' then Result := Colors.Background
  else if LowerName = 'surface' then Result := Colors.Surface
  else if LowerName = 'error' then Result := Colors.Error
  else if LowerName = 'onprimary' then Result := Colors.OnPrimary
  else if LowerName = 'onbackground' then Result := Colors.OnBackground
  else if LowerName = 'onsurface' then Result := Colors.OnSurface
  else if LowerName = 'onerror' then Result := Colors.OnError
  else if LowerName = 'divider' then Result := Colors.Divider
  else Result := Colors.Primary;
end;

function TUniFMXTheme.GetTextColor(Background: TAlphaColor): TAlphaColor;
var
  R, G, B: Byte;
  Luminance: Single;
begin
  // Calculate relative luminance
  R := TAlphaColorRec(Background).R;
  G := TAlphaColorRec(Background).G;
  B := TAlphaColorRec(Background).B;

  Luminance := (0.299 * R + 0.587 * G + 0.114 * B) / 255;

  // Return black or white text based on background luminance
  if Luminance > 0.5 then
    Result := $DE000000  // Black 87%
  else
    Result := $DEFFFFFF; // White 87%
end;

function TUniFMXTheme.Lighten(Color: TAlphaColor; Amount: Single): TAlphaColor;
var
  Rec: TAlphaColorRec;
begin
  Amount := EnsureRange(Amount, 0, 1);
  Rec := TAlphaColorRec(Color);
  Rec.R := Min(255, Round(Rec.R + (255 - Rec.R) * Amount));
  Rec.G := Min(255, Round(Rec.G + (255 - Rec.G) * Amount));
  Rec.B := Min(255, Round(Rec.B + (255 - Rec.B) * Amount));
  Result := TAlphaColor(Rec);
end;

function TUniFMXTheme.Darken(Color: TAlphaColor; Amount: Single): TAlphaColor;
var
  Rec: TAlphaColorRec;
begin
  Amount := EnsureRange(Amount, 0, 1);
  Rec := TAlphaColorRec(Color);
  Rec.R := Max(0, Round(Rec.R * (1 - Amount)));
  Rec.G := Max(0, Round(Rec.G * (1 - Amount)));
  Rec.B := Max(0, Round(Rec.B * (1 - Amount)));
  Result := TAlphaColor(Rec);
end;

function TUniFMXTheme.WithAlpha(Color: TAlphaColor; Alpha: Byte): TAlphaColor;
var
  Rec: TAlphaColorRec;
begin
  Rec := TAlphaColorRec(Color);
  Rec.A := Alpha;
  Result := TAlphaColor(Rec);
end;

{ Global function }

function Theme: TUniFMXTheme;
begin
  Result := TUniFMXTheme.Instance;
end;

initialization
  // Register as Core DeepBase.Theme platform adapter
  DeepBase.Theme.TDeepBaseTheme.SetPlatformAdapter(
    function(const ThemeName: string; out ActiveThemeName: string): Boolean
    begin
      try
        if SameText(ThemeName, 'dark') then
          TUniFMXTheme.Instance.SetMode(utmDark)
        else if SameText(ThemeName, 'light') then
          TUniFMXTheme.Instance.SetMode(utmLight)
        else
          TUniFMXTheme.Instance.SetMode(utmSystem);
        case TUniFMXTheme.Instance.Mode of
          utmLight: ActiveThemeName := 'light';
          utmDark: ActiveThemeName := 'dark';
        else
          ActiveThemeName := 'system';
        end;
        Result := True;
      except
        Result := False;
        ActiveThemeName := '';
      end;
    end,
    nil, // ListThemes: FMX themes managed separately
    function(const ThemeName: string): Boolean
    begin
      Result := SameText(ThemeName, 'light') or SameText(ThemeName, 'dark') or SameText(ThemeName, 'system');
    end,
    function: string
    begin
      case TUniFMXTheme.Instance.Mode of
        utmLight: Result := 'light';
        utmDark: Result := 'dark';
      else
        Result := 'system';
      end;
    end
  );

finalization
  TUniFMXTheme.FreeInstance;

end.
