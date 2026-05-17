{ ============================================================================
  AutoFixHarness

  Console fixture for the AutoFix end-to-end dry-run. Registers three
  scenarios so an external runner can exercise each terminal exit path:

    pass    : success (TotalErrors == 0, exit code 0)
    error   : non-fatal exception recorded via L3 path
              (TotalErrors > 0, exit code 1)
    fatal   : fatal path through SelfTerminator (exit code 2 + exit-reason.json)

  Console subsystem deliberate: TThread.ForceQueue from
  AutoFix.NotifyShellShown does not pump in a no-message-loop process,
  so the harness drives HealthSignal + ScenarioRunner synchronously.

  Without --autofix-mode the harness runs the registered scenarios as
  cheap no-ops and exits 0.

  See: design v2.0 §3.2 / §3.4 / §3.5, requirements 14.1
  ============================================================================ }

program AutoFixHarness;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  DeepBase.AutoFix in '..\..\..\Core\DeepBase.AutoFix.pas',
  DeepBase.AutoFix.ErrorRecorder in '..\..\..\Core\DeepBase.AutoFix.ErrorRecorder.pas',
  DeepBase.AutoFix.HealthSignal in '..\..\..\Core\DeepBase.AutoFix.HealthSignal.pas',
  DeepBase.AutoFix.ScenarioRunner in '..\..\..\Core\DeepBase.AutoFix.ScenarioRunner.pas',
  DeepBase.AutoFix.SelfTerminator in '..\..\..\Core\DeepBase.AutoFix.SelfTerminator.pas',
  DeepBase.AutoFix.StackWalker in '..\..\..\Core\DeepBase.AutoFix.StackWalker.pas';

begin
  // L2 ExceptProc + scenario runner initialization. Idempotent and
  // silent when --autofix-mode is absent from the command line.
  AutoFix.Install;

  AutoFix.RegisterScenario('pass',
    procedure
    begin
      // Success path: do nothing and let the runner observe a clean pass.
    end);

  AutoFix.RegisterScenario('error',
    procedure
    begin
      // ScenarioRunner wraps the callback in try/except so the global
      // L2 ExceptProc never fires for caught exceptions. Record explicitly
      // so the L3 path produces a runtime-errors.jsonl entry and bumps
      // TotalErrors -> exit code 1 once all scenarios complete.
      try
        raise EConvertError.Create('fixture error');
      except
        on E: Exception do
        begin
          TAutoFixErrorRecorder.RecordFromSafeRun(E, '<fixture-error>');
          raise;
        end;
      end;
    end);

  AutoFix.RegisterScenario('fatal',
    procedure
    begin
      // Drive the SelfTerminator path explicitly. HandleFatal writes
      // exit-reason.json (exit_code=2), marks the current scenario fatal
      // in scenario-results.jsonl, and calls Halt(2) -- so the Exception
      // instance leak below is unreachable in the fatal branch.
      var LFault := EAccessViolation.Create('fixture fatal');
      try
        TAutoFixSelfTerminator.HandleFatal(LFault, nil);
      finally
        LFault.Free;
      end;
    end);

  // Console subsystem: drive HealthSignal + ScenarioRunner synchronously
  // because there is no main message pump for TThread.ForceQueue to land
  // on. ScenarioRunner.Run halts with 0 (no errors) or 1 (errors recorded)
  // when --autofix-mode is active; in non-autofix mode it returns and the
  // harness exits 0 normally.
  TAutoFixHealthSignal.Emit;
  TAutoFixScenarioRunner.Run;
end.
