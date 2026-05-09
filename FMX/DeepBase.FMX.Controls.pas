{ ============================================================================
  DeepBase.FMX.Controls - FMX 控件注册单元
  
  版本: 1.1
  说明: 注册所�?DeepBase FMX 控件
  
  新增:
  - Cross-platform controls (ListView, FormControls)
  - Theme support
  - Platform adapter
  ============================================================================ }

unit DeepBase.FMX.Controls;

interface

uses
  System.Classes;

procedure Register;

implementation

uses
  DeepBase.FMX.ConfigControls,
  DeepBase.FMX.I18nControls,
  DeepBase.FMX.MRUControls,
  DeepBase.FMX.ListView,
  DeepBase.FMX.FormControls,
  DeepBase.FMX.LLMConfigPanel,
  DeepBase.FMX.LogListView,
  DeepBase.FMX.NotificationBar,
  DeepBase.FMX.LicenseStatusPanel;

procedure Register;
begin
  var Palette := 'DeepBase FMX';

  // Config Controls
  RegisterComponents(Palette, [
    TFMXConfigEdit,
    TFMXConfigCheckBox,
    TFMXConfigSpinBox
  ]);
  
  // I18n Controls
  RegisterComponents(Palette, [
    TFMXi18nLabel,
    TFMXi18nButton
  ]);
  
  // MRU Controls
  RegisterComponents(Palette, [
    TFMXMRUComboBox
  ]);

  // Cross-Platform ListView Controls
  RegisterComponents(Palette, [
    TUniListView,
    TUniPullRefresh
  ]);

  // Cross-Platform Form Controls
  RegisterComponents(Palette, [
    TUniMaterialEdit,
    TUniSearchComboBox,
    TUniLabeledSwitch,
    TUniChipInput,
    TUniStarRating
  ]);

  // LLM Controls
  RegisterComponents(Palette, [
    TFMXLLMConfigPanel
  ]);

  // Logging & License Controls
  RegisterComponents(Palette, [
    TFMXLogListView,
    TFMXNotificationBar,
    TFMXLicenseStatusPanel
  ]);
end;

end.
