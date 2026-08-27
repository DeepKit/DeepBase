{ ============================================================================
  Test.DeepBase.VCL.HB.Theme - DUnitX Unit Tests for HB Visual Infrastructure

  Version: 1.0 (Delphi 13.1 on Win64)
  Description: Tests for theme token engine, 10 built-in themes, JSON parsing,
               inherits diff merging, 3-axis scaling, and WCAG AA contrast.
  ============================================================================ }

unit Test.DeepBase.VCL.HB.Theme;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.UITypes,
  DeepBase.HB.Core,
  DeepBase.HB.Palettes,
  DeepBase.VCL.HB.Theme,
  DeepBase.VCL.HB.Palettes;

type
  [TestFixture]
  TTestHbTheme = class
  private
    FCalled: Boolean;
    procedure OnThemeChanged(Sender: TObject);
  public
    [Setup]
    procedure Setup;

    [Test]
    procedure Test_BuiltInThemes_Count_AtLeast10;

    [Test]
    procedure Test_BuiltInThemes_All10_Present;

    [Test]
    procedure Test_Inheritance_HuanjinNight_Inherits_HuanjinGold;

    [Test]
    procedure Test_Density_Scaling_Comfortable_And_Compact;

    [Test]
    procedure Test_DPI_Scaling_Calculations;

    [Test]
    procedure Test_WCAG_AA_Contrast_All_BuiltInThemes;

    [Test]
    procedure Test_Custom_Theme_Registration_And_Inherits;

    [Test]
    procedure Test_Theme_Change_Broadcast_Listener;
  end;

implementation

{ TTestHbTheme }

procedure TTestHbTheme.Setup;
begin
  RegisterBuiltInThemes;
  THbTheme.ApplyTheme('huanjin-gold', hdComfortable);
end;

procedure TTestHbTheme.Test_BuiltInThemes_Count_AtLeast10;
var
  Themes: TArray<THbThemeMetadata>;
begin
  Themes := THbTheme.GetAvailableThemes;
  Assert.IsTrue(Length(Themes) >= 10, 'Expected at least 10 built-in themes registered');
end;

procedure TTestHbTheme.Test_BuiltInThemes_All10_Present;
var
  ExpectedIds: TArray<string>;
  Id: string;
  Def: THbThemeDefinition;
begin
  ExpectedIds := [
    'huanjin-gold',
    'huanjin-night',
    'deeparw-indigo',
    'admin-graphite',
    'jade-emerald',
    'rose-clay',
    'frost-contrast',
    'ocean-deep',
    'violet-dusk',
    'tea-green'
  ];

  for Id in ExpectedIds do
  begin
    Assert.IsTrue(THbTheme.GetTheme(Id, Def), Format('Theme "%s" must be registered', [Id]));
    Assert.AreEqual(Id, Def.Meta.Id);
  end;
end;

procedure TTestHbTheme.Test_Inheritance_HuanjinNight_Inherits_HuanjinGold;
var
  GoldDef, NightDef: THbThemeDefinition;
begin
  Assert.IsTrue(THbTheme.GetTheme('huanjin-gold', GoldDef));
  Assert.IsTrue(THbTheme.GetTheme('huanjin-night', NightDef));

  Assert.IsFalse(GoldDef.Meta.IsDark, 'Gold theme should be light');
  Assert.IsTrue(NightDef.Meta.IsDark, 'Night theme should be dark');
  Assert.AreEqual('huanjin-gold', NightDef.Meta.InheritsId);

  // Night overrides primary and surface
  Assert.AreNotEqual(GoldDef.Tokens.Surface, NightDef.Tokens.Surface);
  Assert.AreNotEqual(GoldDef.Tokens.Primary, NightDef.Tokens.Primary);

  // Night inherits typography and radius from Gold
  Assert.AreEqual(GoldDef.Tokens.FontFamily, NightDef.Tokens.FontFamily);
  Assert.AreEqual(GoldDef.Tokens.RadiusM, NightDef.Tokens.RadiusM);
end;

procedure TTestHbTheme.Test_Density_Scaling_Comfortable_And_Compact;
begin
  THbTheme.ApplyTheme('huanjin-gold', hdComfortable);
  Assert.AreEqual(1.0, THbTheme.Tokens.RowHeightScale, 0.001);
  Assert.AreEqual(100, THbTheme.GetScaledPixels(100, 96));

  THbTheme.SetDensity(hdCompact);
  Assert.AreEqual(0.85, THbTheme.Tokens.RowHeightScale, 0.001);
  Assert.AreEqual(85, THbTheme.GetScaledPixels(100, 96));
end;

procedure TTestHbTheme.Test_DPI_Scaling_Calculations;
var
  Tokens, Scaled: THbTokens;
begin
  Tokens := THbTokens.DefaultWarmGold;
  Scaled := Tokens.ScaleForDPI(192); // 200% scaling

  Assert.AreEqual(24.0, Scaled.RadiusM, 0.001); // 12.0 * 2
  Assert.AreEqual(28.0, Scaled.SizeM, 0.001);   // 14.0 * 2
  Assert.AreEqual(28.0, Scaled.SpaceM, 0.001);  // 14.0 * 2
end;

procedure TTestHbTheme.Test_WCAG_AA_Contrast_All_BuiltInThemes;
var
  Themes: TArray<THbThemeMetadata>;
  Meta: THbThemeMetadata;
  Def: THbThemeDefinition;
  Reason: string;
begin
  Themes := THbTheme.GetAvailableThemes;
  for Meta in Themes do
  begin
    Assert.IsTrue(THbTheme.GetTheme(Meta.Id, Def));
    var Valid := Def.Tokens.ValidateWcagAA(Reason);
    Assert.IsTrue(Valid, Format('Theme "%s" failed WCAG AA: %s', [Meta.Id, Reason]));
  end;
end;

procedure TTestHbTheme.Test_Custom_Theme_Registration_And_Inherits;
const
  CUSTOM_JSON =
    '{' +
    '  "id": "custom-brand",' +
    '  "name": "自定义企业色",' +
    '  "inherits": "huanjin-gold",' +
    '  "brand": {' +
    '    "primary": "#0284C7",' +
    '    "onPrimary": "#FFFFFF"' +
    '  }' +
    '}';
var
  Id: string;
  Def: THbThemeDefinition;
begin
  Id := THbTheme.RegisterThemeFromJson(CUSTOM_JSON);
  Assert.AreEqual('custom-brand', Id);

  Assert.IsTrue(THbTheme.GetTheme('custom-brand', Def));
  Assert.AreEqual(TAlphaColor($FF0284C7), Def.Tokens.Primary);
  Assert.AreEqual(TAlphaColor($FFFFFFFF), Def.Tokens.OnPrimary);
  // Inherited from huanjin-gold
  Assert.AreEqual(TAlphaColor($FFFFFDF8), Def.Tokens.Surface);
end;

procedure TTestHbTheme.OnThemeChanged(Sender: TObject);
begin
  FCalled := True;
end;

procedure TTestHbTheme.Test_Theme_Change_Broadcast_Listener;
begin
  FCalled := False;
  THbTheme.AddListener(OnThemeChanged);
  try
    THbTheme.ApplyTheme('deeparw-indigo');
    Assert.IsTrue(FCalled, 'Listener should have been invoked on theme change');
    Assert.AreEqual('deeparw-indigo', THbTheme.CurrentId);
  finally
    THbTheme.RemoveListener(OnThemeChanged);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestHbTheme);

end.
