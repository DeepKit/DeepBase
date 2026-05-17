{ ============================================================================
  AIErrorHandlerDemo

  Minimal VCL demo for the aierrorhandler-rollout spec. Wires the
  one-line Bootstrap facade and shows four buttons that trigger each
  exception classification path:

     EAbort                -> elIgnore     (silently dropped)
     EConvertError         -> elAutoFix    (logged via Logger.Warn)
     Exception (generic)   -> elAIAnalyze  (LLM if available, fallback dialog)
     EAccessViolation      -> elFatal      (Halt(1) under SilentMode,
                                            else MessageDlg + Application.Terminate)

  Run modes
  ---------
  Default (no env)            : Production mode. SilentMode = False.
                                Dialogs visible, Application.Terminate on fatal.
  Set DEEP_AIEH_MODE=test     : Test mode. SilentMode = True.
                                No dialogs, ExitCode := 1; Halt(1) on fatal.
  Compile -DDEEPBASE_AIEH_TEST: Same effect baked into the binary.

  See: .kiro/specs/aierrorhandler-rollout/(requirements|design|tasks).md
  ============================================================================ }

program AIErrorHandlerDemo;

uses
{$IFDEF MSWINDOWS}
  Winapi.Windows,
{$ENDIF}
  Vcl.Forms,
  DeepBase.AIErrorHandler,
  DeepBase.AIErrorHandler.LLMBridge,
  DeepBase.AIErrorHandler.Bootstrap,
  Demo.MainForm in 'Demo.MainForm.pas';

var
  GMainForm: TDemoMainForm;

begin
  // One-line install. bmAuto resolves SilentMode from DEEP_AIEH_MODE / define.
  // Idempotent and never raises - any internal failure is reported via
  // OutputDebugString and we still get a usable shell.
  InstallAIErrorHandler(bmAuto);

  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'AIErrorHandler Demo';
  Application.CreateForm(TDemoMainForm, GMainForm);
  Application.Run;
end.
