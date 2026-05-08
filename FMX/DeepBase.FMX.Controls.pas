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
  // Config Controls
  RegisterComponents('DeepBase FMX', [
    TFMXConfigEdit,
    TFMXConfigCheckBox,
    TFMXConfigSpinBox
  ]);
  
  // I18n Controls
  RegisterComponents('DeepBase FMX', [
    TFMXi18nLabel,
    TFMXi18nButton
  ]);
  
  // MRU Controls
  RegisterComponents('DeepBase FMX', [
    TFMXMRUComboBox
  ]);

  // Cross-Platform ListView Controls
  RegisterComponents('DeepBase FMX', [
    TUniListView,
    TUniPullRefresh
  ]);

  // Cross-Platform Form Controls
  RegisterComponents('DeepBase FMX', [
    TUniMaterialEdit,
    TUniSearchComboBox,
    TUniLabeledSwitch,
    TUniChipInput,
    TUniStarRating
  ]);

  // LLM Controls
  RegisterComponents('DeepBase FMX', [
    TFMXLLMConfigPanel
  ]);

  // Logging & License Controls
  RegisterComponents('DeepBase FMX', [
    TFMXLogListView,
    TFMXNotificationBar,
    TFMXLicenseStatusPanel
  ]);
end;

end.
