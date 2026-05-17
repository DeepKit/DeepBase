{ ============================================================================
  AutoFixDemo

  Minimal VCL demo that wires the AutoFix facade and the VCL exception
  hook into a regular Application.Initialize / Application.Run flow.

  Without --autofix-mode the demo behaves like any other VCL app: every
  AutoFix.* call is a cheap no-op and zero files are written under
  autofix-output/.

  With --autofix-mode the registered scenarios run after the main form is
  shown; HealthSignal, runtime errors, scenario results and exit reason
  are written to autofix-output/.

  See: design v2.0 §3.5 / §3.7, requirements 14.1, 14.2, 14.3, 14.4
  ============================================================================ }

program AutoFixDemo;

uses
{$IFDEF MSWINDOWS}
  Winapi.Windows,
{$ENDIF}
  Vcl.Forms,
  DeepBase.AutoFix,
{$IFDEF MSWINDOWS}
  DeepBase.AutoFix.VclHook,
{$ENDIF}
  Demo.MainForm in 'Demo.MainForm.pas';

var
  GMainForm: TDemoMainForm;

begin
  // L2 ExceptProc + scenario runner initialization. Idempotent and silent
  // when --autofix-mode is absent.
  AutoFix.Install;
{$IFDEF MSWINDOWS}
  // L1 Application.OnException hook. Self-skips when AutoFix is inactive.
  TAutoFixVclHook.Install;
{$ENDIF}

  // Register a couple of cheap scenarios so external runners have
  // something to drive when --autofix-scenario=smoke,probe is passed.
  AutoFix.RegisterScenario('smoke',
    procedure
    begin
      // Smoke scenario: do nothing and let the runner observe a clean pass.
    end);

  AutoFix.RegisterScenario('probe',
    procedure
    begin
      // Probe scenario: verify the facade is reachable.
      var LStatus := if AutoFix.Active then 'on' else 'off';
{$IFDEF MSWINDOWS}
      OutputDebugString(PChar('AutoFix probe: ' + LStatus));
{$ENDIF}
    end);

  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'AutoFix Demo';
  Application.CreateForm(TDemoMainForm, GMainForm);
  Application.Run;
end.
