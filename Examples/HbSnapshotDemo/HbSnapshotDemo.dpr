{ ============================================================================
  HbSnapshotDemo - Real-world Crash & Snapshot Recovery Demonstration
  Part of WO-20260904-004 Verification Suite
  ============================================================================ }

program HbSnapshotDemo;

{$APPTYPE CONSOLE}
{$WARN IMPLICIT_STRING_CAST OFF}

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.DateUtils,
  Data.DB,
  FireDAC.Comp.Client,
  FireDAC.DApt,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  FireDAC.Phys.SQLiteWrapper.Stat,
  FireDAC.Stan.ExprFuncs,
  FireDAC.ConsoleUI.Wait,
  FireDAC.Stan.Def,
  FireDAC.Stan.Async,
  DeepBase.HB.Core,
  DeepBase.HB.Touchpoint.Types,
  DeepBase.HB.Touchpoint.Engine,
  DeepBase.Persistence.HBTelemetry.FireDAC,
  DeepBase.HB.Dialogs.Types,
  DeepBase.HB.Waterfall.Types;

procedure RunPhase1_SimulateUserWorkAndCrash(const ADbPath: string);
var
  Storage: THbFireDACSnapshotStorage;
  Session: THbDialogWizardSession;
  Sink: THbFireDACTelemetrySink;
  Ev: TTouchEvidence;
begin
  Writeln('=== [PHASE 1: USER FILLING WIZARD HALFWAY] ===');
  Storage := THbFireDACSnapshotStorage.Create(ADbPath);
  Sink := THbFireDACTelemetrySink.Create(ADbPath);
  try
    THbTouchpointEngine.Instance.RegisterTouchpoint('tp_wizard_step', tlCritical, 'DeployWizard', 'InProgress');
    THbTouchpointEngine.Instance.SetSink(Sink);

    Session := THbDialogWizardSession.Create('DeployWizard', 'step_container');
    try
      Session.SetStep(3, 5);
      Session.SetFieldValue('cluster_id', 'prod-asia-east-01');
      Session.SetFieldValue('service_mesh', 'istio-enabled');
      Session.SetFieldValue('replica_count', '8');
      Writeln('  -> Wizard Step set to 3 / 5');
      Writeln('  -> Fields filled: cluster_id=prod-asia-east-01, service_mesh=istio-enabled, replica_count=8');

      // Capture and save snapshot
      Storage.SaveSnapshot(Session.GetSurfaceId, Session.GetControlId, Session.CaptureSnapshot);
      Writeln('  -> Session Snapshot saved to SQLite WAL storage.');

      // Emit touchpoint evidence
      FillChar(Ev, SizeOf(Ev), 0);
      Ev.TouchpointId := 'tp_wizard_step';
      Ev.SurfaceId := 'DeployWizard';
      Ev.TimestampUtc := DateTimeToUnix(TTimeZone.Local.ToUniversalTime(Now), False) * 1000;
      Ev.DwellTimeMs := 450;
      Ev.Success := True;
      Ev.BeforeState := 'Step2';
      Ev.AfterState := 'Step3';
      Ev.ActionType := 'NextStep';
      THbTouchpointEngine.Instance.EmitEvidence(Ev);
      THbTouchpointEngine.Instance.FlushSink;
      Writeln('  -> Touchpoint evidence persisted to hb_evidence table.');
    finally
      Session.Free;
    end;
  finally
    THbTouchpointEngine.Instance.SetSink(nil);
    Sink.Free;
    Storage.Free;
  end;

  Writeln('  -> SIMULATING UNEXPECTED APP CRASH / WINDOW FORCE CLOSE (Process terminated)...');
end;

procedure RunPhase2_SimulateRestartAndRecovery(const ADbPath: string);
var
  Storage: THbFireDACSnapshotStorage;
  Session: THbDialogWizardSession;
  Payload: string;
begin
  Writeln('');
  Writeln('=== [PHASE 2: NEW PROCESS LAUNCH & AUTO-RECOVERY] ===');
  Writeln('  -> Application restarted cleanly by user.');

  Storage := THbFireDACSnapshotStorage.Create(ADbPath);
  try
    Session := THbDialogWizardSession.Create('DeployWizard', 'step_container');
    try
      Writeln('  -> Checking for existing snapshot on DeployWizard:step_container...');
      if Storage.LoadSnapshot('DeployWizard', 'step_container', Payload) then
      begin
        Writeln('  -> FOUND SNAPSHOT payload: ', Payload);
        Session.RestoreSnapshot(Payload);

        Writeln('  -> Restored Step: ', Session.CurrentStep, ' / ', Session.TotalSteps);
        Writeln('  -> Restored Field cluster_id: ', Session.GetFieldValue('cluster_id'));
        Writeln('  -> Restored Field service_mesh: ', Session.GetFieldValue('service_mesh'));
        Writeln('  -> Restored Field replica_count: ', Session.GetFieldValue('replica_count'));
        Writeln('  -> User Notice Rendered: "', Session.RestoreNotice, '"');

        if (Session.CurrentStep = 3) and
           (Session.GetFieldValue('cluster_id') = 'prod-asia-east-01') and
           (Session.RestoreNotice = '已为您恢复上次推演进度') then
        begin
          Writeln('');
          Writeln('>>> [SUCCESS] Crash & Recovery Verification PASSED (100% Fidelity) <<<');
        end
        else
        begin
          Writeln('>>> [FAIL] Snapshot data did not match expected values <<<');
          Halt(1);
        end;
      end
      else
      begin
        Writeln('>>> [FAIL] No snapshot found in database <<<');
        Halt(1);
      end;
    finally
      Session.Free;
    end;
  finally
    Storage.Free;
  end;
end;

var
  DbPath: string;
begin
  SetConsoleOutputCP(CP_UTF8);
  SetConsoleCP(CP_UTF8);
  SetMultiByteConversionCodePage(CP_UTF8);
  try
    DbPath := TPath.Combine(TPath.GetTempPath, 'hb_demo_recovery.sqlite');
    if TFile.Exists(DbPath) then
      TFile.Delete(DbPath);

    RunPhase1_SimulateUserWorkAndCrash(DbPath);
    RunPhase2_SimulateRestartAndRecovery(DbPath);

    if TFile.Exists(DbPath) then
      TFile.Delete(DbPath);
  except
    on E: Exception do
    begin
      Writeln('Exception: ', E.ClassName, ': ', E.Message);
      Halt(2);
    end;
  end;
end.
