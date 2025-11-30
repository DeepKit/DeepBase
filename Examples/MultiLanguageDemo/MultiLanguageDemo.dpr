{ ============================================================================
  MultiLanguageDemo
  
  A demonstration project for UniBase internationalization (i18n) features.
  
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
  UniBase.Manager in '..\..\Core\UniBase.Manager.pas',
  UniBase.Types in '..\..\Core\UniBase.Types.pas',
  UniBase.Config in '..\..\Core\UniBase.Config.pas',
  UniBase.Logging in '..\..\Core\UniBase.Logging.pas',
  UniBase.i18n in '..\..\Core\UniBase.i18n.pas',
  UniBase.Consts in '..\..\Core\UniBase.Consts.pas',
  UniBase.VCL.I18nControls in '..\..\VCL\UniBase.VCL.I18nControls.pas';

begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
