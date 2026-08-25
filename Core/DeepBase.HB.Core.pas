{ ============================================================================
  DeepBase.HB.Core - Framework-Agnostic HB Design Tokens & Theme Engine Core

  Version: 1.0 (Delphi 13.1 on Win64 / Cross-Platform RTL)
  Description: Framework-agnostic Design Token theme system for HB Visual
               Infrastructure. Shared across VCL and FMX without any UI
               framework dependencies.
               Supports 3-axis matrix (Hue x Lightness x Density), WCAG 2.1 AA
               contrast validator, JSON diff inheritance (inherits), and
               dual-track event broadcasting (callbacks + TMessageManager).
  ============================================================================ }

unit DeepBase.HB.Core;

interface

uses
  System.SysUtils,
  System.Classes,
  System.UITypes,
  System.Math,
  System.JSON,
  System.Generics.Collections,
  System.SyncObjs,
  System.Messaging;

type
  THbDensity = (hdComfortable, hdCompact);
  THbEaseMode = (emLinear, emEaseIn, emEaseOut, emEaseInOut);

  /// <summary>
  /// Semantic badge tones.
  /// </summary>
  THbBadgeTone = (btNeutral, btBrand, btSuccess, btWarning, btDanger);

  /// <summary>
  /// Comprehensive Design Tokens structure for HB Visual Infrastructure.
  /// All dimensions in DIP (96 DPI base), all colors in TAlphaColor (ARGB).
  /// </summary>
  THbTokens = record
    // Surface Group
    Surface: TAlphaColor;
    SurfaceAlt: TAlphaColor;
    Border: TAlphaColor;
    Soft: TAlphaColor;
    Sunken: TAlphaColor;
    Elevation1: TAlphaColor;
    Elevation2: TAlphaColor;
    Elevation3: TAlphaColor;

    // Ink (Typography color) Group
    Ink: TAlphaColor;
    InkMuted: TAlphaColor;
    FontScale: Single;

    // Brand Group
    Primary: TAlphaColor;
    PrimaryHover: TAlphaColor;
    PrimaryPressed: TAlphaColor;
    OnPrimary: TAlphaColor;
    HeroGradFrom: TAlphaColor;
    HeroGradTo: TAlphaColor;
    FocusRing: TAlphaColor;

    // Status Group
    Success: TAlphaColor;
    SuccessSoft: TAlphaColor;
    Warning: TAlphaColor;
    WarningSoft: TAlphaColor;
    Danger: TAlphaColor;
    DangerSoft: TAlphaColor;
    Info: TAlphaColor;
    InfoSoft: TAlphaColor;

    // Shape Group
    RadiusS: Single;
    RadiusM: Single;
    RadiusL: Single;
    PillRatio: Single;
    BorderWidth: Single;

    // Typography Group
    FontFamily: string;
    SizeXS: Single;
    SizeS: Single;
    SizeM: Single;
    SizeL: Single;
    SizeXL: Single;
    SizeXXL: Single;
    WeightBold: Integer;

    // Space Group
    SpaceXS: Single;
    SpaceS: Single;
    SpaceM: Single;
    SpaceL: Single;
    SpaceXL: Single;

    // Motion Group
    DurFast: Integer; // ms
    DurNorm: Integer; // ms
    DurSlow: Integer; // ms
    EaseMode: THbEaseMode;

    // Density Group
    RowHeightScale: Single;

    class function DefaultWarmGold: THbTokens; static;
    function ScaleForDPI(APPI: Integer): THbTokens;
    function CalculateContrastRatio(AColor1, AColor2: TAlphaColor): Double;
    function ValidateWcagAA(out AReason: string): Boolean;
  end;

  THbThemeMetadata = record
    Id: string;
    Name: string;
    NameEn: string;
    Description: string;
    InheritsId: string;
    IsDark: Boolean;
  end;

  THbThemeDefinition = record
    Meta: THbThemeMetadata;
    RawJson: string;
    Tokens: THbTokens;
  end;

  THbThemeChangeEvent = procedure(Sender: TObject; const AThemeId: string; ADensity: THbDensity) of object;

  /// <summary>
  /// Cross-framework RTL Message broadcast on theme or density changes.
  /// </summary>
  THbThemeChangedMessage = class(TMessage<string>)
  private
    FThemeId: string;
    FDensity: THbDensity;
  public
    constructor Create(const AThemeId: string; ADensity: THbDensity);
    property ThemeId: string read FThemeId;
    property Density: THbDensity read FDensity;
  end;

  /// <summary>
  /// Singleton Theme Engine for HB Visual Infrastructure (Shared Core).
  /// </summary>
  THbTheme = class
  private
    class var FLock: TCriticalSection;
    class var FRegistry: TDictionary<string, THbThemeDefinition>;
    class var FCurrentThemeId: string;
    class var FCurrentDensity: THbDensity;
    class var FListeners: TList<TNotifyEvent>;
    class var FSettingsBridge: TObject;

    class procedure EnsureInitialized;
    class procedure ParseTokensFromJson(AObj: TJSONObject; var ATokens: THbTokens); static;
    class function ParseColor(const AHex: string; ADefault: TAlphaColor = TAlphaColors.Null): TAlphaColor; static;
  public
    class constructor Create;
    class destructor Destroy;

    class procedure Initialize;
    class procedure RegisterTheme(const ADef: THbThemeDefinition); static;
    class function RegisterThemeFromJson(const AJson: string): string; static;
    class function GetTheme(const AThemeId: string; out ADef: THbThemeDefinition): Boolean; static;
    class function GetAvailableThemes: TArray<THbThemeMetadata>; static;

    class procedure ApplyTheme(const AThemeId: string; ADensity: THbDensity = hdComfortable); static;
    class procedure SetDensity(ADensity: THbDensity); static;
    class function CurrentId: string; static;
    class function CurrentDensity: THbDensity; static;
    class function Current: THbThemeDefinition; static;
    class function Tokens: THbTokens; static;
    class function IsDark: Boolean; static;

    class function GetScaledDIP(AValue: Single; APPI: Integer = 96): Single; static;
    class function GetScaledPixels(AValue: Single; APPI: Integer = 96): Integer; static;

    class procedure AddListener(AListener: TNotifyEvent); static;
    class procedure RemoveListener(AListener: TNotifyEvent); static;
    class procedure BroadcastChange; static;

    class procedure AttachSettings(ASettings: TObject); static;
  end;

function CalculateContrastRatio(AColor1, AColor2: TAlphaColor): Double;
function RelativeLuminance(AColor: TAlphaColor): Double;

implementation

{ THbThemeChangedMessage }

constructor THbThemeChangedMessage.Create(const AThemeId: string; ADensity: THbDensity);
begin
  inherited Create(AThemeId);
  FThemeId := AThemeId;
  FDensity := ADensity;
end;

{ Color & Luminance Helpers }

function RelativeLuminance(AColor: TAlphaColor): Double;
  function ComponentToLinear(C: Byte): Double;
  var
    V: Double;
  begin
    V := C / 255.0;
    if V <= 0.03928 then
      Result := V / 12.92
    else
      Result := Power(Double((V + 0.055) / 1.055), Double(2.4));
  end;
var
  R, G, B: Double;
begin
  R := ComponentToLinear(Byte((AColor shr 16) and $FF));
  G := ComponentToLinear(Byte((AColor shr 8) and $FF));
  B := ComponentToLinear(Byte(AColor and $FF));
  Result := 0.2126 * R + 0.7152 * G + 0.0722 * B;
end;

function CalculateContrastRatio(AColor1, AColor2: TAlphaColor): Double;
var
  L1, L2, Tmp: Double;
begin
  L1 := RelativeLuminance(AColor1);
  L2 := RelativeLuminance(AColor2);
  if L1 < L2 then
  begin
    Tmp := L1;
    L1 := L2;
    L2 := Tmp;
  end;
  Result := (L1 + 0.05) / (L2 + 0.05);
end;

{ THbTokens }

class function THbTokens.DefaultWarmGold: THbTokens;
begin
  FillChar(Result, SizeOf(Result), 0);

  // Surface Group (Warm Gold Light)
  Result.Surface    := $FFFFFDF8;
  Result.SurfaceAlt := $FFFFF6E6;
  Result.Border     := $FFEBDFC8;
  Result.Soft       := $FFFDF0DA;
  Result.Sunken     := $FFF5EFE6;
  Result.Elevation1 := $1A000000;
  Result.Elevation2 := $26000000;
  Result.Elevation3 := $33000000;

  // Ink Group
  Result.Ink        := $FF292524;
  Result.InkMuted   := $FF8A8175;
  Result.FontScale  := 1.0;

  // Brand Group
  Result.Primary        := $FFD97706; // Amber 600
  Result.PrimaryHover   := $FFB45309;
  Result.PrimaryPressed := $FF92400E;
  Result.OnPrimary      := $FFFFFFFF;
  Result.HeroGradFrom   := $FF78350F;
  Result.HeroGradTo     := $FFF59E0B;
  Result.FocusRing      := $FFD97706;

  // Status Group
  Result.Success     := $FF059669;
  Result.SuccessSoft := $FFECFDF5;
  Result.Warning     := $FFD97706;
  Result.WarningSoft := $FFFEF9C3;
  Result.Danger      := $FFDC2626;
  Result.DangerSoft  := $FFFEF2F2;
  Result.Info        := $FF0284C7;
  Result.InfoSoft    := $FFF0F9FF;

  // Shape Group
  Result.RadiusS     := 6.0;
  Result.RadiusM     := 12.0;
  Result.RadiusL     := 20.0;
  Result.PillRatio   := 0.5;
  Result.BorderWidth := 1.0;

  // Typography Group
  Result.FontFamily := 'Segoe UI';
  Result.SizeXS     := 11.0;
  Result.SizeS      := 12.5;
  Result.SizeM      := 14.0;
  Result.SizeL      := 17.0;
  Result.SizeXL     := 22.0;
  Result.SizeXXL    := 34.0;
  Result.WeightBold := 700;

  // Space Group
  Result.SpaceXS := 4.0;
  Result.SpaceS  := 8.0;
  Result.SpaceM  := 14.0;
  Result.SpaceL  := 22.0;
  Result.SpaceXL := 32.0;

  // Motion Group
  Result.DurFast  := 120;
  Result.DurNorm  := 200;
  Result.DurSlow  := 350;
  Result.EaseMode := emEaseOut;

  // Density Group
  Result.RowHeightScale := 1.0;
end;

function THbTokens.CalculateContrastRatio(AColor1, AColor2: TAlphaColor): Double;
begin
  Result := DeepBase.HB.Core.CalculateContrastRatio(AColor1, AColor2);
end;

function THbTokens.ValidateWcagAA(out AReason: string): Boolean;
begin
  Result := True;
  AReason := '';

  // 1. Text on Surface (WCAG 2.1 AA Body Text >= 4.5:1)
  var RatioInkSur := CalculateContrastRatio(Ink, Surface);
  if RatioInkSur < 4.5 then
  begin
    AReason := Format('Ink on Surface contrast ratio (%.2f:1) is below WCAG AA 4.5:1', [RatioInkSur]);
    Exit(False);
  end;

  // 2. OnPrimary on Primary (WCAG 2.1 AA UI Component / Bold Button Text >= 3.0:1)
  var RatioOnPri := CalculateContrastRatio(OnPrimary, Primary);
  if RatioOnPri < 3.0 then
  begin
    AReason := Format('OnPrimary on Primary contrast ratio (%.2f:1) is below WCAG AA 3.0:1', [RatioOnPri]);
    Exit(False);
  end;
end;

function THbTokens.ScaleForDPI(APPI: Integer): THbTokens;
var
  DpiScale: Single;
begin
  Result := Self;
  if APPI <= 0 then
    APPI := 96;
  DpiScale := APPI / 96.0;

  // Scale Dimensions
  Result.RadiusS := RadiusS * DpiScale;
  Result.RadiusM := RadiusM * DpiScale;
  Result.RadiusL := RadiusL * DpiScale;
  Result.BorderWidth := Max(1.0, BorderWidth * DpiScale);

  Result.SizeXS  := SizeXS * DpiScale;
  Result.SizeS   := SizeS * DpiScale;
  Result.SizeM   := SizeM * DpiScale;
  Result.SizeL   := SizeL * DpiScale;
  Result.SizeXL  := SizeXL * DpiScale;
  Result.SizeXXL := SizeXXL * DpiScale;

  Result.SpaceXS := SpaceXS * DpiScale;
  Result.SpaceS  := SpaceS * DpiScale;
  Result.SpaceM  := SpaceM * DpiScale;
  Result.SpaceL  := SpaceL * DpiScale;
  Result.SpaceXL := SpaceXL * DpiScale;
end;

{ THbTheme }

class constructor THbTheme.Create;
begin
  FLock := TCriticalSection.Create;
  FRegistry := TDictionary<string, THbThemeDefinition>.Create;
  FListeners := TList<TNotifyEvent>.Create;
  FCurrentThemeId := 'huanjin-gold';
  FCurrentDensity := hdComfortable;
  FSettingsBridge := nil;
end;

class destructor THbTheme.Destroy;
begin
  FListeners.Free;
  FRegistry.Free;
  FLock.Free;
end;

class procedure THbTheme.EnsureInitialized;
var
  Def: THbThemeDefinition;
begin
  if FRegistry.Count = 0 then
  begin
    Def.Meta.Id := 'huanjin-gold';
    Def.Meta.Name := '暖金';
    Def.Meta.NameEn := 'Warm Gold';
    Def.Meta.Description := '唤金默认 · 温暖生意感';
    Def.Meta.InheritsId := '';
    Def.Meta.IsDark := False;
    Def.RawJson := '';
    Def.Tokens := THbTokens.DefaultWarmGold;
    FRegistry.AddOrSetValue(Def.Meta.Id, Def);
  end;
end;

class procedure THbTheme.Initialize;
begin
  FLock.Enter;
  try
    EnsureInitialized;
  finally
    FLock.Leave;
  end;
end;

class function THbTheme.ParseColor(const AHex: string; ADefault: TAlphaColor): TAlphaColor;
var
  S: string;
  R, G, B, A: Byte;
  Val: UInt32;
begin
  S := Trim(AHex);
  if S.StartsWith('#') then
    S := S.Substring(1);

  if Length(S) = 6 then
  begin
    if TryStrToUInt('$' + S, Val) then
    begin
      R := Byte((Val shr 16) and $FF);
      G := Byte((Val shr 8) and $FF);
      B := Byte(Val and $FF);
      A := $FF;
      Exit((A shl 24) or (R shl 16) or (G shl 8) or B);
    end;
  end
  else if Length(S) = 8 then
  begin
    if TryStrToUInt('$' + S, Val) then
    begin
      A := Byte((Val shr 24) and $FF);
      R := Byte((Val shr 16) and $FF);
      G := Byte((Val shr 8) and $FF);
      B := Byte(Val and $FF);
      Exit((A shl 24) or (R shl 16) or (G shl 8) or B);
    end;
  end;

  Result := ADefault;
end;

class procedure THbTheme.ParseTokensFromJson(AObj: TJSONObject; var ATokens: THbTokens);
var
  Val: TJSONValue;
  SubObj: TJSONObject;
begin
  if not Assigned(AObj) then Exit;

  // Surface
  Val := AObj.Values['surface'];
  if Val is TJSONObject then
  begin
    SubObj := TJSONObject(Val);
    if SubObj.Values['surface'] <> nil then
      ATokens.Surface := ParseColor(SubObj.Values['surface'].Value, ATokens.Surface);
    if SubObj.Values['surfaceAlt'] <> nil then
      ATokens.SurfaceAlt := ParseColor(SubObj.Values['surfaceAlt'].Value, ATokens.SurfaceAlt);
    if SubObj.Values['border'] <> nil then
      ATokens.Border := ParseColor(SubObj.Values['border'].Value, ATokens.Border);
    if SubObj.Values['soft'] <> nil then
      ATokens.Soft := ParseColor(SubObj.Values['soft'].Value, ATokens.Soft);
    if SubObj.Values['sunken'] <> nil then
      ATokens.Sunken := ParseColor(SubObj.Values['sunken'].Value, ATokens.Sunken);
    if SubObj.Values['elevation1'] <> nil then
      ATokens.Elevation1 := ParseColor(SubObj.Values['elevation1'].Value, ATokens.Elevation1);
    if SubObj.Values['elevation2'] <> nil then
      ATokens.Elevation2 := ParseColor(SubObj.Values['elevation2'].Value, ATokens.Elevation2);
    if SubObj.Values['elevation3'] <> nil then
      ATokens.Elevation3 := ParseColor(SubObj.Values['elevation3'].Value, ATokens.Elevation3);
  end;

  // Ink
  Val := AObj.Values['ink'];
  if Val is TJSONObject then
  begin
    SubObj := TJSONObject(Val);
    if SubObj.Values['ink'] <> nil then
      ATokens.Ink := ParseColor(SubObj.Values['ink'].Value, ATokens.Ink);
    if SubObj.Values['inkMuted'] <> nil then
      ATokens.InkMuted := ParseColor(SubObj.Values['inkMuted'].Value, ATokens.InkMuted);
    if SubObj.Values['fontScale'] is TJSONNumber then
      ATokens.FontScale := TJSONNumber(SubObj.Values['fontScale']).AsDouble;
  end;

  // Brand
  Val := AObj.Values['brand'];
  if Val is TJSONObject then
  begin
    SubObj := TJSONObject(Val);
    if SubObj.Values['primary'] <> nil then
      ATokens.Primary := ParseColor(SubObj.Values['primary'].Value, ATokens.Primary);
    if SubObj.Values['primaryHover'] <> nil then
      ATokens.PrimaryHover := ParseColor(SubObj.Values['primaryHover'].Value, ATokens.PrimaryHover);
    if SubObj.Values['primaryPressed'] <> nil then
      ATokens.PrimaryPressed := ParseColor(SubObj.Values['primaryPressed'].Value, ATokens.PrimaryPressed);
    if SubObj.Values['onPrimary'] <> nil then
      ATokens.OnPrimary := ParseColor(SubObj.Values['onPrimary'].Value, ATokens.OnPrimary);
    if SubObj.Values['heroGradFrom'] <> nil then
      ATokens.HeroGradFrom := ParseColor(SubObj.Values['heroGradFrom'].Value, ATokens.HeroGradFrom);
    if SubObj.Values['heroGradTo'] <> nil then
      ATokens.HeroGradTo := ParseColor(SubObj.Values['heroGradTo'].Value, ATokens.HeroGradTo);
    if SubObj.Values['focusRing'] <> nil then
      ATokens.FocusRing := ParseColor(SubObj.Values['focusRing'].Value, ATokens.FocusRing);
  end;

  // Status
  Val := AObj.Values['status'];
  if Val is TJSONObject then
  begin
    SubObj := TJSONObject(Val);
    if SubObj.Values['success'] <> nil then
      ATokens.Success := ParseColor(SubObj.Values['success'].Value, ATokens.Success);
    if SubObj.Values['successSoft'] <> nil then
      ATokens.SuccessSoft := ParseColor(SubObj.Values['successSoft'].Value, ATokens.SuccessSoft);
    if SubObj.Values['warning'] <> nil then
      ATokens.Warning := ParseColor(SubObj.Values['warning'].Value, ATokens.Warning);
    if SubObj.Values['warningSoft'] <> nil then
      ATokens.WarningSoft := ParseColor(SubObj.Values['warningSoft'].Value, ATokens.WarningSoft);
    if SubObj.Values['danger'] <> nil then
      ATokens.Danger := ParseColor(SubObj.Values['danger'].Value, ATokens.Danger);
    if SubObj.Values['dangerSoft'] <> nil then
      ATokens.DangerSoft := ParseColor(SubObj.Values['dangerSoft'].Value, ATokens.DangerSoft);
    if SubObj.Values['info'] <> nil then
      ATokens.Info := ParseColor(SubObj.Values['info'].Value, ATokens.Info);
    if SubObj.Values['infoSoft'] <> nil then
      ATokens.InfoSoft := ParseColor(SubObj.Values['infoSoft'].Value, ATokens.InfoSoft);
  end;

  // Shape
  Val := AObj.Values['shape'];
  if Val is TJSONObject then
  begin
    SubObj := TJSONObject(Val);
    if SubObj.Values['radiusS'] is TJSONNumber then
      ATokens.RadiusS := TJSONNumber(SubObj.Values['radiusS']).AsDouble;
    if SubObj.Values['radiusM'] is TJSONNumber then
      ATokens.RadiusM := TJSONNumber(SubObj.Values['radiusM']).AsDouble;
    if SubObj.Values['radiusL'] is TJSONNumber then
      ATokens.RadiusL := TJSONNumber(SubObj.Values['radiusL']).AsDouble;
    if SubObj.Values['pill'] is TJSONNumber then
      ATokens.PillRatio := TJSONNumber(SubObj.Values['pill']).AsDouble;
    if SubObj.Values['borderWidth'] is TJSONNumber then
      ATokens.BorderWidth := TJSONNumber(SubObj.Values['borderWidth']).AsDouble;
  end;

  // Typography
  Val := AObj.Values['typography'];
  if Val is TJSONObject then
  begin
    SubObj := TJSONObject(Val);
    if SubObj.Values['fontFamily'] <> nil then
      ATokens.FontFamily := SubObj.Values['fontFamily'].Value;
    if SubObj.Values['sizeXS'] is TJSONNumber then
      ATokens.SizeXS := TJSONNumber(SubObj.Values['sizeXS']).AsDouble;
    if SubObj.Values['sizeS'] is TJSONNumber then
      ATokens.SizeS := TJSONNumber(SubObj.Values['sizeS']).AsDouble;
    if SubObj.Values['sizeM'] is TJSONNumber then
      ATokens.SizeM := TJSONNumber(SubObj.Values['sizeM']).AsDouble;
    if SubObj.Values['sizeL'] is TJSONNumber then
      ATokens.SizeL := TJSONNumber(SubObj.Values['sizeL']).AsDouble;
    if SubObj.Values['sizeXL'] is TJSONNumber then
      ATokens.SizeXL := TJSONNumber(SubObj.Values['sizeXL']).AsDouble;
    if SubObj.Values['sizeXXL'] is TJSONNumber then
      ATokens.SizeXXL := TJSONNumber(SubObj.Values['sizeXXL']).AsDouble;
  end;

  // Space
  Val := AObj.Values['space'];
  if Val is TJSONObject then
  begin
    SubObj := TJSONObject(Val);
    if SubObj.Values['xs'] is TJSONNumber then
      ATokens.SpaceXS := TJSONNumber(SubObj.Values['xs']).AsDouble;
    if SubObj.Values['s'] is TJSONNumber then
      ATokens.SpaceS := TJSONNumber(SubObj.Values['s']).AsDouble;
    if SubObj.Values['m'] is TJSONNumber then
      ATokens.SpaceM := TJSONNumber(SubObj.Values['m']).AsDouble;
    if SubObj.Values['l'] is TJSONNumber then
      ATokens.SpaceL := TJSONNumber(SubObj.Values['l']).AsDouble;
    if SubObj.Values['xl'] is TJSONNumber then
      ATokens.SpaceXL := TJSONNumber(SubObj.Values['xl']).AsDouble;
  end;

  // Motion
  Val := AObj.Values['motion'];
  if Val is TJSONObject then
  begin
    SubObj := TJSONObject(Val);
    if SubObj.Values['fast'] is TJSONNumber then
      ATokens.DurFast := TJSONNumber(SubObj.Values['fast']).AsInt;
    if SubObj.Values['normal'] is TJSONNumber then
      ATokens.DurNorm := TJSONNumber(SubObj.Values['normal']).AsInt;
    if SubObj.Values['slow'] is TJSONNumber then
      ATokens.DurSlow := TJSONNumber(SubObj.Values['slow']).AsInt;
  end;
end;

class procedure THbTheme.RegisterTheme(const ADef: THbThemeDefinition);
begin
  FLock.Enter;
  try
    FRegistry.AddOrSetValue(ADef.Meta.Id, ADef);
  finally
    FLock.Leave;
  end;
end;

class function THbTheme.RegisterThemeFromJson(const AJson: string): string;
var
  JsonVal: TJSONValue;
  Obj: TJSONObject;
  Def, ParentDef: THbThemeDefinition;
  InheritsId: string;
begin
  Result := '';
  JsonVal := TJSONObject.ParseJSONValue(AJson);
  if not (JsonVal is TJSONObject) then
  begin
    JsonVal.Free;
    Exit;
  end;

  Obj := TJSONObject(JsonVal);
  try
    Def.Meta.Id := Obj.GetValue<string>('id', '');
    if Def.Meta.Id = '' then
      Exit;

    Def.Meta.Name := Obj.GetValue<string>('name', Def.Meta.Id);
    Def.Meta.NameEn := Obj.GetValue<string>('nameEn', Def.Meta.Name);
    Def.Meta.Description := Obj.GetValue<string>('description', '');
    Def.Meta.InheritsId := Obj.GetValue<string>('inherits', '');
    Def.Meta.IsDark := Obj.GetValue<Boolean>('isDark', False);
    Def.RawJson := AJson;

    // 1. Initialize tokens: from parent if inherits is set, otherwise default
    InheritsId := Def.Meta.InheritsId;
    if (InheritsId <> '') and GetTheme(InheritsId, ParentDef) then
      Def.Tokens := ParentDef.Tokens
    else
      Def.Tokens := THbTokens.DefaultWarmGold;

    // 2. Parse overrides
    ParseTokensFromJson(Obj, Def.Tokens);

    // 3. Register
    RegisterTheme(Def);
    Result := Def.Meta.Id;
  finally
    Obj.Free;
  end;
end;

class function THbTheme.GetTheme(const AThemeId: string; out ADef: THbThemeDefinition): Boolean;
begin
  FLock.Enter;
  try
    EnsureInitialized;
    Result := FRegistry.TryGetValue(AThemeId, ADef);
  finally
    FLock.Leave;
  end;
end;

class function THbTheme.GetAvailableThemes: TArray<THbThemeMetadata>;
var
  List: TList<THbThemeMetadata>;
  Pair: TPair<string, THbThemeDefinition>;
begin
  FLock.Enter;
  try
    EnsureInitialized;
    List := TList<THbThemeMetadata>.Create;
    try
      for Pair in FRegistry do
        List.Add(Pair.Value.Meta);
      Result := List.ToArray;
    finally
      List.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

class procedure THbTheme.ApplyTheme(const AThemeId: string; ADensity: THbDensity);
begin
  FLock.Enter;
  try
    EnsureInitialized;
    if FRegistry.ContainsKey(AThemeId) then
      FCurrentThemeId := AThemeId;
    FCurrentDensity := ADensity;
  finally
    FLock.Leave;
  end;

  BroadcastChange;
end;

class procedure THbTheme.SetDensity(ADensity: THbDensity);
begin
  FLock.Enter;
  try
    FCurrentDensity := ADensity;
  finally
    FLock.Leave;
  end;

  BroadcastChange;
end;

class function THbTheme.CurrentId: string;
begin
  FLock.Enter;
  try
    EnsureInitialized;
    Result := FCurrentThemeId;
  finally
    FLock.Leave;
  end;
end;

class function THbTheme.CurrentDensity: THbDensity;
begin
  FLock.Enter;
  try
    Result := FCurrentDensity;
  finally
    FLock.Leave;
  end;
end;

class function THbTheme.Current: THbThemeDefinition;
begin
  FLock.Enter;
  try
    EnsureInitialized;
    if not FRegistry.TryGetValue(FCurrentThemeId, Result) then
      Result.Tokens := THbTokens.DefaultWarmGold;
  finally
    FLock.Leave;
  end;
end;

class function THbTheme.Tokens: THbTokens;
var
  Def: THbThemeDefinition;
begin
  Def := Current;
  Result := Def.Tokens;
  if FCurrentDensity = hdCompact then
    Result.RowHeightScale := 0.85
  else
    Result.RowHeightScale := 1.0;
end;

class function THbTheme.IsDark: Boolean;
begin
  Result := Current.Meta.IsDark;
end;

class function THbTheme.GetScaledDIP(AValue: Single; APPI: Integer): Single;
var
  DensityScale: Single;
begin
  if APPI <= 0 then
    APPI := 96;
  if FCurrentDensity = hdCompact then
    DensityScale := 0.85
  else
    DensityScale := 1.0;
  Result := AValue * (APPI / 96.0) * DensityScale;
end;

class function THbTheme.GetScaledPixels(AValue: Single; APPI: Integer): Integer;
begin
  Result := Integer(Round(GetScaledDIP(AValue, APPI)));
end;

class procedure THbTheme.AddListener(AListener: TNotifyEvent);
begin
  FLock.Enter;
  try
    if not FListeners.Contains(AListener) then
      FListeners.Add(AListener);
  finally
    FLock.Leave;
  end;
end;

class procedure THbTheme.RemoveListener(AListener: TNotifyEvent);
begin
  FLock.Enter;
  try
    FListeners.Remove(AListener);
  finally
    FLock.Leave;
  end;
end;

class procedure THbTheme.BroadcastChange;
var
  ListenersCopy: TArray<TNotifyEvent>;
  Listener: TNotifyEvent;
  CurId: string;
  CurDen: THbDensity;
begin
  FLock.Enter;
  try
    ListenersCopy := FListeners.ToArray;
    CurId := FCurrentThemeId;
    CurDen := FCurrentDensity;
  finally
    FLock.Leave;
  end;

  // 1. Direct callback listeners
  for Listener in ListenersCopy do
  begin
    try
      Listener(nil);
    except
      // Keep broadcasting to others
    end;
  end;

  // 2. Cross-framework RTL message dispatch
  try
    TMessageManager.DefaultManager.SendMessage(nil, THbThemeChangedMessage.Create(CurId, CurDen), True);
  except
  end;
end;

class procedure THbTheme.AttachSettings(ASettings: TObject);
begin
  FLock.Enter;
  try
    FSettingsBridge := ASettings;
  finally
    FLock.Leave;
  end;
end;

end.
