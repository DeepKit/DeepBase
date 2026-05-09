{ ============================================================================
  DeepBase.VCL.Controls - VCL 控件注册单元
  
  版本: 1.0
  说明: 注册所有 DeepBase VCL 组件到组件面板
  ============================================================================ }

unit DeepBase.VCL.Controls;

interface

uses
  System.Classes,
  DeepBase.VCL.ConfigControls,
  DeepBase.VCL.I18nControls,
  DeepBase.VCL.ComboBoxes,
  DeepBase.VCL.FormStateHelper,
  DeepBase.VCL.LogListView,
  DeepBase.VCL.LLMConfigPanel,
  DeepBase.VCL.WaitForm,
  DeepBase.VCL.NotificationBar,
  DeepBase.VCL.AutoUpdater;

procedure Register;

implementation

procedure Register;
begin
  var Palette := 'DeepBase Controls';
  RegisterComponents(Palette, [
    TConfigEdit,
    TConfigCheckBox,
    TConfigSpinEdit,
    TI18nLabel,
    TI18nButton,
    TLanguageComboBox,
    TThemeComboBox,
    TFormStateHelper,
    TLogListView,
    TLLMConfigPanel,
    TNotificationBar,
    TAutoUpdater
  ]);
  // WaitForm is not a component on palette, but utility.
  // It's a form class, call TWaitForm.ShowWait() directly in code.
end;

end.
