{ ============================================================================
  UniBase.VCL.Controls - VCL 控件注册单元
  
  版本: 1.0
  说明: 注册所有 UniBase VCL 组件到组件面板
  ============================================================================ }

unit UniBase.VCL.Controls;

interface

uses
  System.Classes,
  UniBase.VCL.ConfigControls,
  UniBase.VCL.I18nControls,
  UniBase.VCL.ComboBoxes,
  UniBase.VCL.FormStateHelper,
  UniBase.VCL.LogListView,
  UniBase.VCL.LLMConfigPanel,
  UniBase.VCL.WaitForm,
  UniBase.VCL.NotificationBar,
  UniBase.VCL.AutoUpdater;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('UniBase Controls', [
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
