{ ============================================================================
  Test.Regression.BUG326_SchedulerCallbackSafety - REVIEW5-CORE-004

  Verifies that Scheduler isolates callback exceptions:
  - OnComplete exception does not overwrite task success state or FLastError
  - OnError exception does not affect task state transitions
  - FRunningCount / FStats.RunningTasks correctly decremented after callback exceptions
  ============================================================================ }

unit Test.Regression.BUG326_SchedulerCallbackSafety;

interface

uses
  System.SysUtils,
  System.Classes,
  DUnitX.TestFramework,
  Test.Regression.Base,
  DeepBase.Scheduler;

type
  [TestFixture]
  [Category('regression')]
  TBUG326_SchedulerCallbackSafetyTest = class(TRegressionTestBase)
  private
    FScheduler: TTaskScheduler;
  protected
    function GetBugNumber: string; override;
    function GetBugDescription: string; override;
    function GetFixDate: string; override;
    function GetPriority: string; override;
    function GetAffectedFile: string; override;
  public
    [SetUp]
    procedure SetUp; override;
    [TearDown]
    procedure TearDown; override;

    /// <summary>OnComplete raises => task still marked completed, LastError not overwritten</summary>
    [Test]
    procedure Test_OnCompleteRaises_TaskStillCompleted;

    /// <summary>OnError raises => task still marked failed, state not corrupted</summary>
    [Test]
    procedure Test_OnErrorRaises_TaskStillFailed;

    /// <summary>OnComplete raises => Stats.RunningTasks correctly decremented to 0</summary>
    [Test]
    procedure Test_OnCompleteRaises_RunningTasksCorrect;
  end;

implementation

{ TBUG326_SchedulerCallbackSafetyTest }

function TBUG326_SchedulerCallbackSafetyTest.GetBugNumber: string;
begin
  Result := 'BUG-326';
end;

function TBUG326_SchedulerCallbackSafetyTest.GetBugDescription: string;
begin
  Result := 'Scheduler OnComplete callback exception corrupts task state';
end;

function TBUG326_SchedulerCallbackSafetyTest.GetFixDate: string;
begin
  Result := '2026-06-29';
end;

function TBUG326_SchedulerCallbackSafetyTest.GetPriority: string;
begin
  Result := 'P1';
end;

function TBUG326_SchedulerCallbackSafetyTest.GetAffectedFile: string;
begin
  Result := 'Core/DeepBase.Scheduler.pas';
end;

procedure TBUG326_SchedulerCallbackSafetyTest.SetUp;
begin
  inherited;
  FScheduler := TTaskScheduler.Create;
  FScheduler.CheckIntervalMs := 20; // Fast check interval for tests
  FScheduler.Start;
end;

procedure TBUG326_SchedulerCallbackSafetyTest.TearDown;
begin
  FScheduler.Stop;
  FreeAndNil(FScheduler);
  inherited;
end;

procedure RaisingCompletedHandler(const ATask: TScheduledTask);
begin
  raise Exception.Create('OnComplete callback error');
end;

procedure RaisingFailedHandler(const ATask: TScheduledTask; const AError: Exception);
begin
  raise Exception.Create('OnError callback error');
end;

procedure TBUG326_SchedulerCallbackSafetyTest.Test_OnCompleteRaises_TaskStillCompleted;
var
  LTask: TScheduledTask;
begin
  LTask := FScheduler.Schedule('test_oncomplete_raise',
    procedure
    begin
      // Successful task
      Sleep(50);
    end);
  LTask.OnComplete(RaisingCompletedHandler);
  LTask.MaxRuns(1);
  // BUG-326: Schedule 创建的任务停在 tsIdle(CanRunTask 只执行 tsPending),
  // 必须显式 .Run 置 tsPending + CalculateNextRun, 调度 tick 才会执行到回调。
  LTask.Run;

  // Wait for task to execute
  Sleep(500);

  // Task should be completed despite OnComplete raising
  Assert.AreEqual(tsCompleted, LTask.State,
    'Task should be tsCompleted even when OnComplete raises');
  Assert.AreEqual('', LTask.LastError,
    'Task LastError should be empty (not overwritten by callback exception)');
end;

procedure TBUG326_SchedulerCallbackSafetyTest.Test_OnErrorRaises_TaskStillFailed;
var
  LTask: TScheduledTask;
begin
  LTask := FScheduler.Schedule('test_onerror_raise',
    procedure
    begin
      raise Exception.Create('Handler error');
    end);
  // Default retry policy is NoRetry, so task fails immediately
  LTask.OnError(RaisingFailedHandler);
  LTask.MaxRuns(1);
  // BUG-326: 同上, 任务需 .Run 才进入 tsPending 被调度执行。
  LTask.Run;

  // Wait for task to execute and fail
  Sleep(500);

  // Task should be failed despite OnError raising
  Assert.AreEqual(tsFailed, LTask.State,
    'Task should be tsFailed even when OnError raises');
end;

procedure TBUG326_SchedulerCallbackSafetyTest.Test_OnCompleteRaises_RunningTasksCorrect;
var
  LTask: TScheduledTask;
begin
  LTask := FScheduler.Schedule('test_runningtasks',
    procedure
    begin
      Sleep(50);
    end);
  LTask.OnComplete(RaisingCompletedHandler);
  LTask.MaxRuns(1);
  // BUG-326: 同上, 需 .Run 触发执行, 否则任务不执行 RunningTasks 恒为 0(trivially 通过无意义)。
  LTask.Run;

  // Wait for task to execute
  Sleep(500);

  // Stats.RunningTasks should be 0 after task completes
  Assert.AreEqual(0, FScheduler.Stats.RunningTasks,
    'RunningTasks should be 0 after task completes');
end;

end.
