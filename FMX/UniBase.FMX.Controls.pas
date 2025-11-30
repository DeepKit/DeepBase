{ ============================================================================
  UniBase.FMX.Controls - FMX 控件注册单元
  
  版本: 1.1
  说明: 注册所有 UniBase FMX 控件
  
  新增:
  - Cross-platform controls (ListView, FormControls)
  - Theme support
  - Platform adapter
  ============================================================================ }

unit UniBase.FMX.Controls;

interface

uses
  System.Classes;

procedure Register;

implementation

uses
  UniBase.FMX.ConfigControls,
  UniBase.FMX.I18nControls,
  UniBase.FMX.MRUControls,
  UniBase.FMX.ListView,
  UniBase.FMX.FormControls;

procedure Register;
begin
  // Config Controls
  RegisterComponents('UniBase FMX', [
    TFMXConfigEdit,
    TFMXConfigCheckBox,
    TFMXConfigSpinBox
  ]);
  
  // I18n Controls
  RegisterComponents('UniBase FMX', [
    TFMXi18nLabel,
    TFMXi18nButton
  ]);
  
  // MRU Controls
  RegisterComponents('UniBase FMX', [
    TFMXMRUComboBox
  ]);

  // Cross-Platform ListView Controls
  RegisterComponents('UniBase FMX', [
    TUniListView,
    TUniPullRefresh
  ]);

  // Cross-Platform Form Controls
  RegisterComponents('UniBase FMX', [
    TUniMaterialEdit,
    TUniSearchComboBox,
    TUniLabeledSwitch,
    TUniChipInput,
    TUniStarRating
  ]);
end;

end.
