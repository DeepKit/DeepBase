{ ============================================================================
  DeepBase.AutoFix

  Single public entry point for the AutoFix runtime. Wraps the four core
  units (ErrorRecorder, ScenarioRunner, HealthSignal, SelfTerminator) so
  application code only needs:

    AutoFix.Install;                 // before Application.Initialize
    AutoFix.RegisterScenario(...);   // any time after Install
    AutoFix.NotifyShellShown;        // after AfterShellShown / OnShow
    AutoFix.ConfirmSelfTermination('MyApp:updater'); // only if the host
        // accepts that fatal scenarios Halt this process (termination gate
        // lives in SelfTerminator); without it AutoFix records but never exits.

  When --autofix-mode is absent from the command line, every facade method
  is a cheap no-op and zero files are written.

  See: design v2.0 §3.5
  ============================================================================ }

unit DeepBase.AutoFix;

interface

uses
  System.Classes,
  DeepBase.AutoFix.ScenarioRunner;

type
  TAutoFixScenarioProc = TScenarioProc;

  AutoFix = class sealed
  public
    /// <summary>Parses --autofix-* command line, installs L2 ExceptProc and
    /// initializes the scenario runner. Idempotent.</summary>
    class procedure Install; static;
    /// <summary>Register a named scenario callback.</summary>
    class procedure RegisterScenario(const AName: string;
      AProc: TScenarioProc); static;
    /// <summary>Call after the main shell is fully shown. Writes
    /// health-signal.json and queues scenario execution to the next idle
    /// frame so the UI thread is not blocked.</summary>
    class procedure NotifyShellShown; static;
    /// <summary>True when --autofix-mode is on the command line.</summary>
    class function Active: Boolean; static;
    /// <summary>Host opt-in for SelfTerminator's fatal path (exit-reason.json
    /// + Halt 2). --autofix-mode alone never terminates the process; the
    /// ASource names the confirming component for the audit trail.</summary>
    class procedure ConfirmSelfTermination(const ASource: string); static;
  end;

implementation

uses
  System.SysUtils,
  DeepBase.AutoFix.ErrorRecorder,
  DeepBase.AutoFix.HealthSignal,
  DeepBase.AutoFix.SelfTerminator;

{ AutoFix }

class procedure AutoFix.Install;
begin
  TAutoFixErrorRecorder.Install;
  TAutoFixScenarioRunner.Initialize;
end;

class procedure AutoFix.RegisterScenario(const AName: string;
  AProc: TScenarioProc);
begin
  TAutoFixScenarioRunner.RegisterScenario(AName, AProc);
end;

class procedure AutoFix.NotifyShellShown;
begin
  if not TAutoFixErrorRecorder.Active then Exit;

  TAutoFixHealthSignal.Emit;

  // BIZ-R3-014 FIX: Use TThread.Queue instead of TThread.ForceQueue to ensure
  // the scenario runner executes on the main thread. ForceQueue uses the thread
  // pool, and if TAutoFixScenarioRunner.Run calls Halt (via HandleFatal),
  // non-main-thread Halt can cause incomplete process cleanup.
  TThread.Queue(nil,
    procedure
    begin
      TAutoFixScenarioRunner.Run;
    end);
end;

class function AutoFix.Active: Boolean;
begin
  Result := TAutoFixErrorRecorder.Active;
end;

class procedure AutoFix.ConfirmSelfTermination(const ASource: string);
begin
  TAutoFixSelfTerminator.ConfirmTermination(ASource);
end;

end.
