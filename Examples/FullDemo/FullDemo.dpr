{ ============================================================================
  UniBase FullDemo - 综合功能演示
  
  版本: 1.0
  说明: 演示 UniBase 框架所有功能模块
  ============================================================================ }

program FullDemo;

uses
  Vcl.Forms,
  FullDemo.MainForm in 'FullDemo.MainForm.pas' {MainForm},
  UniBase.Manager,
  UniBase.Config,
  UniBase.i18n,
  UniBase.Logging,
  UniBase.FormState,
  UniBase.MRU,
  UniBase.Hotkeys,
  UniBase.Theme,
  UniBase.LLM,
  UniBase.AutoUpdate in '..\..\Features\UniBase.AutoUpdate.pas',
  UniBase.RemoteConfig,
  UniBase.License;

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'UniBase Full Demo';
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
