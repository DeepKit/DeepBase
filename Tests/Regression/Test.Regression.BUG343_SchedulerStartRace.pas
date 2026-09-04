unit Test.Regression.BUG343_SchedulerStartRace;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Threading,
  DUnitX.TestFramework,
  Test.Regression.Base,
  DeepBase.Scheduler;

type
  [TestFixture]
  [Category('regression')]
  TBUG343_SchedulerStartRaceTest = class(TRegressionTestBase)
  private
    FScheduler: TTaskScheduler;
  protected
    function GetBugNumber: string; override;
    function GetBugDescription: string; override;
    function GetFixDate: string; override;
    function GetPriority: string; override;
    function GetAffectedFile: string; override;
  public
    [Setup]
    procedure SetUp; override;
    [TearDown]
    procedure TearDown; override;

    [Test]
    procedure Test_ConcurrentStart_IsIdempotent;
  end;

implementation

procedure TBUG343_SchedulerStartRaceTest.SetUp;
begin
  inherited;
  FScheduler := TTaskScheduler.Create;
end;

procedure TBUG343_SchedulerStartRaceTest.TearDown;
begin
  if Assigned(FScheduler) then
  begin
    FScheduler.Stop;
    FreeAndNil(FScheduler);
  end;
  inherited;
end;

function TBUG343_SchedulerStartRaceTest.GetBugNumber: string;
begin
  Result := 'BUG-343';
end;

function TBUG343_SchedulerStartRaceTest.GetBugDescription: string;
begin
  Result := 'Scheduler concurrent Start must be idempotent (single timer thread)';
end;

function TBUG343_SchedulerStartRaceTest.GetFixDate: string;
begin
  Result := '2026-09-03';
end;

function TBUG343_SchedulerStartRaceTest.GetPriority: string;
begin
  Result := 'P1';
end;

function TBUG343_SchedulerStartRaceTest.GetAffectedFile: string;
begin
  Result := 'Core/DeepBase.Scheduler.pas';
end;

procedure TBUG343_SchedulerStartRaceTest.Test_ConcurrentStart_IsIdempotent;
var
  LStartGate: TCountdownEvent;
  LTasks: array[0..1] of ITask;
  LErrors: Integer;
  I: Integer;
begin
  LErrors := 0;
  LStartGate := TCountdownEvent.Create(2);
  try
    for I := 0 to 1 do
    begin
      LTasks[I] := TTask.Run(
        procedure
        begin
          try
            LStartGate.Signal;
            LStartGate.WaitFor;
            FScheduler.Start;
          except
            TInterlocked.Increment(LErrors);
          end;
        end);
    end;

    TTask.WaitForAll([LTasks[0], LTasks[1]]);

    Assert.AreEqual(0, LErrors, 'Concurrent Start must not raise');
    Assert.IsTrue(FScheduler.Running,
      'FRunning must remain True after concurrent Start calls');
    Assert.IsTrue(FScheduler.Stop,
      'Stop must succeed after idempotent concurrent Start');
    Assert.IsFalse(FScheduler.Running,
      'FRunning must be False after Stop');
  finally
    LStartGate.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBUG343_SchedulerStartRaceTest);

end.
