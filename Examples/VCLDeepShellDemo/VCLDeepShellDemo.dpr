{ ============================================================================
  VCLDeepShellDemo

  Minimal demo of TDeepMainForm. Uses fake providers and fake services so
  the shell can start without DB1, doQry, LLM, WebView2 or Governance.

  Reference: docs/76.vcl.DeepShell-新VCL程序接入指南.md §10
  ============================================================================ }

program VCLDeepShellDemo;

uses
  Vcl.Forms,
  Vcl.Dialogs,
  FireDAC.VCLUI.Wait,
  FireDAC.Comp.UI,
  DeepBase.Manager,
  DeepBase.Persistence.Manager.FireDAC,
  Demo.MainForm in 'Demo.MainForm.pas',
  Demo.Services in 'Demo.Services.pas',
  Demo.Commands in 'Demo.Commands.pas',
  Demo.Providers in 'Demo.Providers.pas';

{$R *.res}

var
  GErrorMsg: string;

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'DeepShell Demo';

  // DeepBase init is best-effort for the demo. The shell does not require
  // DB1 to be configured; it will use in-memory fallbacks.
  if not DeepBase.Manager.DeepBase.InitializeEx(GErrorMsg) then
    ShowMessage('DeepBase init reported: ' + GErrorMsg + sLineBreak +
      'Demo will continue with in-memory fallbacks.');

  try
    Application.CreateForm(TDemoMainForm, DemoMainForm);
    Application.Run;
  finally
    DeepBase.Manager.DeepBase.Finalize;
  end;
end.
