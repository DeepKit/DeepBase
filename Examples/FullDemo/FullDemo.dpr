{ ============================================================================
  DeepBase FullDemo - 综合功能演示
  
  版本: 1.0
  说明: 演示 DeepBase 框架所有功能模块
  ============================================================================ }

program FullDemo;

uses
  Vcl.Forms,
  FullDemo.MainForm in 'FullDemo.MainForm.pas' {MainForm},
  DeepBase.Manager,
  DeepBase.Config,
  DeepBase.i18n,
  DeepBase.Logging,
  DeepBase.FormState,
  DeepBase.MRU,
  DeepBase.Hotkeys,
  DeepBase.Theme,
  DeepBase.LLM,
  DeepBase.AutoUpdate in '..\..\Features\DeepBase.AutoUpdate.pas',
  DeepBase.License;

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'DeepBase Full Demo';
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
