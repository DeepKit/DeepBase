{ ============================================================================
  MultiLanguageDemo
  
  A demonstration project for DeepBase internationalization (i18n) features.
  
  Features demonstrated:
  - T() function for simple translations
  - TFmt() function for formatted translations with arguments
  - TN() function for plural forms
  - Language switching at runtime
  - TI18nLabel and TI18nButton auto-translating controls
  
  Supported languages: English, Chinese (Simplified), Japanese
  ============================================================================ }

program MultiLanguageDemo;

uses
  Vcl.Forms,
  MainForm in 'MainForm.pas' {frmMain},
  DeepBase.Manager in '..\..\Core\DeepBase.Manager.pas',
  DeepBase.Types in '..\..\Core\DeepBase.Types.pas',
  DeepBase.Config in '..\..\Core\DeepBase.Config.pas',
  DeepBase.Logging in '..\..\Core\DeepBase.Logging.pas',
  DeepBase.i18n in '..\..\Core\DeepBase.i18n.pas',
  DeepBase.Consts in '..\..\Core\DeepBase.Consts.pas',
  DeepBase.VCL.I18nControls in '..\..\VCL\DeepBase.VCL.I18nControls.pas';

begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
