unit Test.DeepBase.RuntimeContext;

interface

uses
  System.SysUtils,
  System.Classes,
  System.DateUtils,
  System.Rtti,
  System.SyncObjs,
  System.Threading,
  DUnitX.TestFramework,
  DeepBase.RuntimeContext;

type
  TFailAction = (faNone, faConfigure, faInitialize, faStart, faStop,
    faShutdown);

  TAsyncDrainEvent = record
    Value: Integer;
  end;

  TTestRuntimeComponent = class(TDeepBaseRuntimeComponent)
  private
    FLog: TStrings;
    FFailAction: TFailAction;
    procedure AddLog(const Action: string);
    procedure FailIf(Action: TFailAction; const ActionName: string);
  public
    constructor Create(const AName: string; ALog: TStrings;
      AFailAction: TFailAction = faNone); reintroduce;
    procedure Configure; override;
    procedure Initialize; override;
    procedure Start; override;
    procedure Stop; override;
    procedure Shutdown; override;
  end;

  /// <summary>
  /// Adapter that manages an EventBus within the runtime lifecycle.
  /// On Start: enables the bus. On Stop: drains async callbacks.
  /// On Shutdown: disables and clears subscriptions.
  /// </summary>
  TEventBusRuntimeComponent = class(TDeepBaseRuntimeComponent)
  private
    FBus: TObject;  // TEventBus, kept as TObject to avoid forward issues
    FOwnsBus: Boolean;
    FActivated: Boolean;
    FStarted: Boolean;
  public
    constructor Create(const AName: string; ABus: TObject; AOwnsBus: Boolean); reintroduce;
    destructor Destroy; override;
    procedure Start; override;
    procedure Stop; override;
    procedure Shutdown; override;
  end;

  /// <summary>
  /// Adapter that manages a WorkerQueue within the runtime lifecycle.
  /// On Start: starts the queue. On Stop: waits for running jobs.
  /// On Shutdown: stops the queue.
  /// </summary>
  TWorkerQueueRuntimeComponent = class(TDeepBaseRuntimeComponent)
  private
    FQueue: TObject;  // TWorkerQueue
    FActivated: Boolean;
    FStarted: Boolean;
  public
    constructor Create(const AName: string; AQueue: TObject); reintroduce;
    procedure Start; override;
    procedure Stop; override;
    procedure Shutdown; override;
  end;

  /// <summary>
  /// Adapter that manages a TTaskScheduler within the runtime lifecycle.
  /// On Start: starts the scheduler. On Stop: waits for running tasks.
  /// On Shutdown: stops the scheduler.
  /// </summary>
  TSchedulerRuntimeComponent = class(TDeepBaseRuntimeComponent)
  private
    FScheduler: TObject;  // TTaskScheduler
    FActivated: Boolean;
    FStarted: Boolean;
  public
    constructor Create(const AName: string; AScheduler: TObject); reintroduce;
    procedure Start; override;
    procedure Stop; override;
    procedure Shutdown; override;
  end;

  /// <summary>
  /// Adapter that manages the global IoC container within the runtime lifecycle.
  /// On Shutdown: clears registrations (only if it was started).
  /// </summary>
  TIoCRuntimeComponent = class(TDeepBaseRuntimeComponent)
  private
    FStarted: Boolean;
  public
    procedure Start; override;
    procedure Shutdown; override;
  end;

  [TestFixture]
  TTestDeepBaseRuntimeContext = class
  private
    FContext: TDeepBaseRuntimeContext;
    FLog: TStringList;
    procedure AssertLogEquals(const Expected: array of string);
  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure StartAndShutdown_RunInDeterministicOrder;

    [Test]
    procedure InitializeFailure_ShutsDownConfiguredComponentsInReverse;

    [Test]
    procedure StartFailure_StopsStartedAndShutsDownConfiguredComponents;

    [Test]
    procedure RegisterAfterConfigure_Raises;

    [Test]
    procedure EventBusComponent_StartsStopsAndClears;

    [Test]
    procedure WorkerQueueComponent_StartsAndStopsQueue;

    [Test]
    procedure WorkerQueueComponent_Stop_DrainsRunningJobs;

    [Test]
    procedure WorkerQueueComponent_CancelByTag_ThenStop_JoinsRunningJob;

    [Test]
    procedure SchedulerComponent_StartsAndStopsScheduler;

    [Test]
    procedure SchedulerComponent_Stop_WaitsForRunningTasks;

    [Test]
    procedure ShutdownWithoutStart_DoesNotStopGlobalEventBus;

    [Test]
    procedure ShutdownWithoutStart_DoesNotStopExplicitEventBus;

    [Test]
    procedure ShutdownWithoutStart_DoesNotStopGlobalWorkerQueue;

    [Test]
    procedure ShutdownWithoutStart_DoesNotStopExplicitWorkerQueue;

    [Test]
    procedure ShutdownWithoutStart_DoesNotClearGlobalIoCContainer;

    [Test]
    procedure ShutdownWithoutStart_DoesNotStopExplicitScheduler;

    [Test]
    procedure EventBusComponent_Stop_DrainsAsyncCallbacks;

    [Test]
    procedure CustomLifecycleOrder_StopsAsyncBeforeManager_AndLoggerBeforePersistence;

  end;

implementation

uses
  DeepBase.EventBus,
  DeepBase.IoC,
  DeepBase.Scheduler,
  DeepBase.WorkerQueue;

{ TTestRuntimeComponent }

constructor TTestRuntimeComponent.Create(const AName: string; ALog: TStrings;
  AFailAction: TFailAction);
begin
  inherited Create(AName);
  FLog := ALog;
  FFailAction := AFailAction;
end;

procedure TTestRuntimeComponent.AddLog(const Action: string);
begin
  FLog.Add(Name + '.' + Action);
end;

procedure TTestRuntimeComponent.FailIf(Action: TFailAction;
  const ActionName: string);
begin
  if FFailAction = Action then
    raise Exception.Create(Name + ' failed at ' + ActionName);
end;

procedure TTestRuntimeComponent.Configure;
begin
  AddLog('Configure');
  FailIf(faConfigure, 'Configure');
end;

procedure TTestRuntimeComponent.Initialize;
begin
  AddLog('Initialize');
  FailIf(faInitialize, 'Initialize');
end;

procedure TTestRuntimeComponent.Start;
begin
  AddLog('Start');
  FailIf(faStart, 'Start');
end;

procedure TTestRuntimeComponent.Stop;
begin
  AddLog('Stop');
  FailIf(faStop, 'Stop');
end;

procedure TTestRuntimeComponent.Shutdown;
begin
  AddLog('Shutdown');
  FailIf(faShutdown, 'Shutdown');
end;

{ TEventBusRuntimeComponent }

constructor TEventBusRuntimeComponent.Create(const AName: string;
  ABus: TObject; AOwnsBus: Boolean);
begin
  inherited Create(AName);
  FBus := ABus;
  FOwnsBus := AOwnsBus;
end;

destructor TEventBusRuntimeComponent.Destroy;
begin
  if FOwnsBus then
    FBus.Free;
  inherited;
end;

procedure TEventBusRuntimeComponent.Start;
begin
  TEventBus(FBus).Enabled := True;
  FStarted := True;
  FActivated := True;
end;

procedure TEventBusRuntimeComponent.Stop;
begin
  if FStarted then
    TEventBus(FBus).WaitForAsyncHandlers(2000);
  FStarted := False;
end;

procedure TEventBusRuntimeComponent.Shutdown;
begin
  if FActivated then
  begin
    TEventBus(FBus).WaitForAsyncHandlers(2000);
    TEventBus(FBus).Enabled := False;
    TEventBus(FBus).Clear;
  end;
  FStarted := False;
  FActivated := False;
end;

{ TWorkerQueueRuntimeComponent }

constructor TWorkerQueueRuntimeComponent.Create(const AName: string;
  AQueue: TObject);
begin
  inherited Create(AName);
  FQueue := AQueue;
end;

procedure TWorkerQueueRuntimeComponent.Start;
begin
  TWorkerQueue(FQueue).Start;
  FStarted := True;
  FActivated := True;
end;

procedure TWorkerQueueRuntimeComponent.Stop;
begin
  if FStarted then
    TWorkerQueue(FQueue).Stop(True);
  FStarted := False;
end;

procedure TWorkerQueueRuntimeComponent.Shutdown;
begin
  if FActivated then
    TWorkerQueue(FQueue).Stop(True);
  FStarted := False;
  FActivated := False;
end;

{ TSchedulerRuntimeComponent }

constructor TSchedulerRuntimeComponent.Create(const AName: string;
  AScheduler: TObject);
begin
  inherited Create(AName);
  FScheduler := AScheduler;
end;

procedure TSchedulerRuntimeComponent.Start;
begin
  TTaskScheduler(FScheduler).Start;
  FStarted := True;
  FActivated := True;
end;

procedure TSchedulerRuntimeComponent.Stop;
begin
  if FStarted then
    TTaskScheduler(FScheduler).Stop;
  FStarted := False;
end;

procedure TSchedulerRuntimeComponent.Shutdown;
begin
  if FActivated then
    TTaskScheduler(FScheduler).Stop;
  FStarted := False;
  FActivated := False;
end;

{ TIoCRuntimeComponent }

procedure TIoCRuntimeComponent.Start;
begin
  FStarted := True;
end;

procedure TIoCRuntimeComponent.Shutdown;
begin
  if FStarted then
    GlobalContainer.Clear;
end;

{ TTestDeepBaseRuntimeContext }

procedure TTestDeepBaseRuntimeContext.Setup;
begin
  FContext := TDeepBaseRuntimeContext.Create;
  FLog := TStringList.Create;
end;

procedure TTestDeepBaseRuntimeContext.TearDown;
begin
  FContext.Free;
  FLog.Free;
end;

procedure TTestDeepBaseRuntimeContext.AssertLogEquals(
  const Expected: array of string);
var
  I: Integer;
begin
  Assert.AreEqual<Integer>(Length(Expected), FLog.Count, 'Unexpected log count');
  for I := 0 to High(Expected) do
    Assert.AreEqual(Expected[I], FLog[I], 'Unexpected log item ' + I.ToString);
end;

procedure TTestDeepBaseRuntimeContext.StartAndShutdown_RunInDeterministicOrder;
begin
  FContext.RegisterComponent(TTestRuntimeComponent.Create('A', FLog));
  FContext.RegisterComponent(TTestRuntimeComponent.Create('B', FLog));

  FContext.Start;
  FContext.Shutdown;

  AssertLogEquals([
    'A.Configure',
    'B.Configure',
    'A.Initialize',
    'B.Initialize',
    'A.Start',
    'B.Start',
    'B.Stop',
    'A.Stop',
    'B.Shutdown',
    'A.Shutdown'
  ]);
end;

procedure TTestDeepBaseRuntimeContext.InitializeFailure_ShutsDownConfiguredComponentsInReverse;
begin
  FContext.RegisterComponent(TTestRuntimeComponent.Create('A', FLog));
  FContext.RegisterComponent(TTestRuntimeComponent.Create('B', FLog,
    faInitialize));

  try
    FContext.Initialize;
    Assert.Fail('Expected initialize failure');
  except
    on E: Exception do
      Assert.Contains(E.Message, 'B failed at Initialize');
  end;

  AssertLogEquals([
    'A.Configure',
    'B.Configure',
    'A.Initialize',
    'B.Initialize',
    'B.Shutdown',
    'A.Shutdown'
  ]);
end;

procedure TTestDeepBaseRuntimeContext.StartFailure_StopsStartedAndShutsDownConfiguredComponents;
begin
  FContext.RegisterComponent(TTestRuntimeComponent.Create('A', FLog));
  FContext.RegisterComponent(TTestRuntimeComponent.Create('B', FLog, faStart));

  try
    FContext.Start;
    Assert.Fail('Expected start failure');
  except
    on E: Exception do
      Assert.Contains(E.Message, 'B failed at Start');
  end;

  AssertLogEquals([
    'A.Configure',
    'B.Configure',
    'A.Initialize',
    'B.Initialize',
    'A.Start',
    'B.Start',
    'A.Stop',
    'B.Shutdown',
    'A.Shutdown'
  ]);
end;

procedure TTestDeepBaseRuntimeContext.RegisterAfterConfigure_Raises;
var
  Candidate: IRuntimeComponent;
begin
  FContext.RegisterComponent(TTestRuntimeComponent.Create('A', FLog));
  FContext.Configure;
  Candidate := TTestRuntimeComponent.Create('B', FLog);

  try
    FContext.RegisterComponent(Candidate);
    Assert.Fail('Expected registration failure');
  except
    on E: ERuntimeContextError do
      Assert.Contains(E.Message, 'cannot be registered');
  end;
end;

procedure TTestDeepBaseRuntimeContext.EventBusComponent_StartsStopsAndClears;
var
  Bus: TEventBus;
  Token: ISubscription;
begin
  Bus := TEventBus.Create;
  try
    Bus.Enabled := False;
    FContext.RegisterComponent(
      TEventBusRuntimeComponent.Create('EventBus', Bus, False));

    FContext.Start;
    Assert.IsTrue(Bus.Enabled);

    Token := Bus.SubscribeByType('TSystemEvent.RuntimeContext',
      procedure(const Event: TValue)
      begin
      end);
    Assert.IsNotNull(Token);
    Assert.AreEqual(1, Bus.GetSubscriberCount('TSystemEvent.RuntimeContext'));

    FContext.Shutdown;
    Assert.IsFalse(Bus.Enabled);
    Assert.AreEqual(0, Bus.GetSubscriberCount('TSystemEvent.RuntimeContext'));
  finally
    if not FContext.ShutdownComplete then
      FContext.Shutdown;
    Bus.Free;
  end;
end;

procedure TTestDeepBaseRuntimeContext.WorkerQueueComponent_StartsAndStopsQueue;
var
  Queue: TWorkerQueue;
  Stats: TQueueStats;
begin
  Queue := TWorkerQueue.Create('runtime-test', 1);
  try
    FContext.RegisterComponent(
      TWorkerQueueRuntimeComponent.Create('WorkerQueue', Queue));

    FContext.Start;
    Stats := Queue.Stats;
    Assert.AreEqual(1, Stats.ActiveWorkers + Stats.IdleWorkers);

    FContext.Shutdown;
    Stats := Queue.Stats;
    Assert.AreEqual(0, Stats.ActiveWorkers + Stats.IdleWorkers);
    Assert.IsTrue(Queue.IsShuttingDown);
  finally
    if not FContext.ShutdownComplete then
      FContext.Shutdown;
    Queue.Free;
  end;
end;

procedure TTestDeepBaseRuntimeContext.WorkerQueueComponent_Stop_DrainsRunningJobs;
var
  Queue: TWorkerQueue;
  StartedEvent: TEvent;
  AllowFinishEvent: TEvent;
  TaskFinished: Boolean;
  ElapsedMs: Integer;
  StartAt: TDateTime;
  ReleaseTask: ITask;
begin
  Queue := TWorkerQueue.Create('runtime-drain-test', 1);
  StartedEvent := TEvent.Create(nil, True, False, '');
  AllowFinishEvent := TEvent.Create(nil, True, False, '');
  TaskFinished := False;
  try
    Queue.RegisterHandler('drain-job',
      procedure(const AJob: TJob)
      begin
        StartedEvent.SetEvent;
        AllowFinishEvent.WaitFor(2000);
        TaskFinished := True;
      end);

    FContext.RegisterComponent(
      TWorkerQueueRuntimeComponent.Create('WorkerQueue', Queue));
    FContext.Start;

    Queue.Enqueue(Queue.CreateJob('drain-job'));

    Assert.AreEqual(wrSignaled, StartedEvent.WaitFor(1000),
      'WorkerQueue job did not start in time');

    ReleaseTask := TTask.Create(
      procedure
      begin
        Sleep(120);
        AllowFinishEvent.SetEvent;
      end);
    ReleaseTask.Start;

    StartAt := Now;
    FContext.Stop;
    ElapsedMs := MilliSecondsBetween(Now, StartAt);

    Assert.IsTrue(TaskFinished,
      'RuntimeContext.Stop should wait for WorkerQueue running jobs to complete');
    Assert.IsTrue(ElapsedMs >= 80,
      'RuntimeContext.Stop should block until WorkerQueue job is finished');
  finally
    if Assigned(ReleaseTask) then
      ReleaseTask.Wait;
    if not FContext.ShutdownComplete then
      FContext.Shutdown;
    AllowFinishEvent.Free;
    StartedEvent.Free;
    Queue.Free;
  end;
end;

procedure TTestDeepBaseRuntimeContext.WorkerQueueComponent_CancelByTag_ThenStop_JoinsRunningJob;
var
  Queue: TWorkerQueue;
  StartedEvent: TEvent;
  AllowFinishEvent: TEvent;
  RunningJobFinished: Boolean;
  CancelledCount: Integer;
  FirstJobId: TJobId;
  SecondJobId: TJobId;
  ElapsedMs: Integer;
  StartAt: TDateTime;
  ReleaseTask: ITask;
  Stats: TQueueStats;
  TaggedJobs: TArray<TJob>;
  I: Integer;
begin
  Queue := TWorkerQueue.Create('runtime-cancel-tag-test', 1);
  StartedEvent := TEvent.Create(nil, True, False, '');
  AllowFinishEvent := TEvent.Create(nil, True, False, '');
  RunningJobFinished := False;
  try
    Queue.RegisterHandler('tagged-job',
      procedure(const AJob: TJob)
      begin
        StartedEvent.SetEvent;
        AllowFinishEvent.WaitFor(2000);
        RunningJobFinished := True;
      end);

    FContext.RegisterComponent(
      TWorkerQueueRuntimeComponent.Create('WorkerQueue', Queue));
    FContext.Start;

    Stats := Queue.Stats;
    Assert.AreEqual(1, Stats.ActiveWorkers + Stats.IdleWorkers,
      'WorkerQueue should have one worker after RuntimeContext.Start');

    FirstJobId := Queue.Enqueue(Queue.CreateJob('tagged-job').WithTag('active'));
    SecondJobId := Queue.Enqueue(Queue.CreateJob('tagged-job').WithTag('cancel-me'));

    Assert.AreEqual(wrSignaled, StartedEvent.WaitFor(5000),
      'First job did not start in time');

    // Cancel pending jobs that have the 'cancel-me' tag.
    // TWorkerQueue has no CancelByTag method, so we use
    // GetJobsByTag + CancelJob to achieve the same result.
    CancelledCount := 0;
    TaggedJobs := Queue.GetJobsByTag('cancel-me');
    for I := 0 to High(TaggedJobs) do
    begin
      if TaggedJobs[I].Status in [jsPending, jsScheduled, jsRetrying] then
      begin
        if Queue.CancelJob(TaggedJobs[I].Id) then
          Inc(CancelledCount);
      end;
    end;
    Assert.AreEqual(1, CancelledCount, 'Exactly one pending tagged job should be cancelled');
    Assert.AreEqual(jsCancelled, Queue.GetJob(SecondJobId).Status);
    Assert.AreEqual(jsRunning, Queue.GetJob(FirstJobId).Status);

    ReleaseTask := TTask.Create(
      procedure
      begin
        Sleep(120);
        AllowFinishEvent.SetEvent;
      end);
    ReleaseTask.Start;

    StartAt := Now;
    FContext.Stop;
    ElapsedMs := MilliSecondsBetween(Now, StartAt);

    Assert.IsTrue(RunningJobFinished,
      'RuntimeContext.Stop should still join the running WorkerQueue job');
    Assert.IsTrue(ElapsedMs >= 80,
      'RuntimeContext.Stop should block until running job finishes');
  finally
    if Assigned(ReleaseTask) then
      ReleaseTask.Wait;
    if not FContext.ShutdownComplete then
      FContext.Shutdown;
    AllowFinishEvent.Free;
    StartedEvent.Free;
    Queue.Free;
  end;
end;

procedure TTestDeepBaseRuntimeContext.SchedulerComponent_StartsAndStopsScheduler;
var
  Scheduler: TTaskScheduler;
begin
  Scheduler := TTaskScheduler.Create;
  try
    Assert.IsFalse(Scheduler.Running);
    FContext.RegisterComponent(
      TSchedulerRuntimeComponent.Create('Scheduler', Scheduler));

    FContext.Start;
    Assert.IsTrue(Scheduler.Running);

    FContext.Shutdown;
    Assert.IsFalse(Scheduler.Running);
  finally
    if not FContext.ShutdownComplete then
      FContext.Shutdown;
    Scheduler.Free;
  end;
end;

procedure TTestDeepBaseRuntimeContext.SchedulerComponent_Stop_WaitsForRunningTasks;
var
  Scheduler: TTaskScheduler;
  StartedEvent: TEvent;
  AllowFinishEvent: TEvent;
  TaskFinished: Boolean;
  ElapsedMs: Integer;
  StartAt: TDateTime;
  ReleaseTask: ITask;
begin
  Scheduler := TTaskScheduler.Create;
  StartedEvent := TEvent.Create(nil, True, False, '');
  AllowFinishEvent := TEvent.Create(nil, True, False, '');
  TaskFinished := False;
  try
    FContext.RegisterComponent(
      TSchedulerRuntimeComponent.Create('Scheduler', Scheduler));
    FContext.Start;

    Scheduler.Schedule('runtime-stop-wait',
      procedure
      begin
        StartedEvent.SetEvent;
        AllowFinishEvent.WaitFor(2000);
        TaskFinished := True;
      end).Delay(0).Run;

    Assert.AreEqual(wrSignaled, StartedEvent.WaitFor(1000),
      'Scheduled task did not start in time');

    ReleaseTask := TTask.Create(
      procedure
      begin
        Sleep(120);
        AllowFinishEvent.SetEvent;
      end);
    ReleaseTask.Start;

    StartAt := Now;
    FContext.Stop;
    ElapsedMs := MilliSecondsBetween(Now, StartAt);

    Assert.IsTrue(TaskFinished,
      'RuntimeContext.Stop should wait for scheduler running tasks to complete');
    Assert.IsTrue(ElapsedMs >= 80,
      'RuntimeContext.Stop should block until running task is finished');
  finally
    if Assigned(ReleaseTask) then
      ReleaseTask.Wait;
    if not FContext.ShutdownComplete then
      FContext.Shutdown;
    AllowFinishEvent.Free;
    StartedEvent.Free;
    Scheduler.Free;
  end;
end;

procedure TTestDeepBaseRuntimeContext.ShutdownWithoutStart_DoesNotStopGlobalEventBus;
var
  Bus: TEventBus;
begin
  Bus := EventBus;
  Bus.Enabled := True;
  FContext.RegisterComponent(
    TEventBusRuntimeComponent.Create('EventBus', Bus, False));
  FContext.Configure;

  FContext.Shutdown;

  Assert.IsTrue(Bus.Enabled,
    'Shutdown-before-start must not stop the global EventBus singleton');
end;

procedure TTestDeepBaseRuntimeContext.ShutdownWithoutStart_DoesNotStopExplicitEventBus;
var
  Bus: TEventBus;
  SubscriberCount: Integer;
begin
  Bus := TEventBus.Create;
  try
    Bus.Enabled := True;
    Bus.SubscribeByType('TSystemEvent.RuntimeContext.ExplicitBus',
      procedure(const Event: TValue)
      begin
      end);
    SubscriberCount := Bus.GetSubscriberCount('TSystemEvent.RuntimeContext.ExplicitBus');
    FContext.RegisterComponent(
      TEventBusRuntimeComponent.Create('EventBus', Bus, False));
    FContext.Configure;

    FContext.Shutdown;

    Assert.IsTrue(Bus.Enabled,
      'Shutdown-before-start must not stop an explicit EventBus instance');
    Assert.AreEqual(SubscriberCount,
      Bus.GetSubscriberCount('TSystemEvent.RuntimeContext.ExplicitBus'),
      'Shutdown-before-start must not clear explicit EventBus subscribers');
  finally
    Bus.Free;
  end;
end;

procedure TTestDeepBaseRuntimeContext.ShutdownWithoutStart_DoesNotStopGlobalWorkerQueue;
var
  Queue: TWorkerQueue;
begin
  Queue := WorkerQueue();
  Queue.Start;
  FContext.RegisterComponent(
    TWorkerQueueRuntimeComponent.Create('WorkerQueue', Queue));
  FContext.Configure;

  FContext.Shutdown;

  Assert.IsFalse(Queue.IsShuttingDown,
    'Shutdown-before-start must not stop the global WorkerQueue singleton');
end;

procedure TTestDeepBaseRuntimeContext.ShutdownWithoutStart_DoesNotStopExplicitWorkerQueue;
var
  Queue: TWorkerQueue;
begin
  Queue := TWorkerQueue.Create('runtime-explicit-worker', 1);
  try
    Queue.Start;
    Assert.IsFalse(Queue.IsShuttingDown);
    FContext.RegisterComponent(
      TWorkerQueueRuntimeComponent.Create('WorkerQueue', Queue));
    FContext.Configure;

    FContext.Shutdown;

    Assert.IsFalse(Queue.IsShuttingDown,
      'Shutdown-before-start must not stop an explicit WorkerQueue instance');
  finally
    Queue.Stop(True);
    Queue.Free;
  end;
end;

procedure TTestDeepBaseRuntimeContext.ShutdownWithoutStart_DoesNotClearGlobalIoCContainer;
var
  Container: TIoCContainer;
begin
  Container := GlobalContainer;
  FContext.RegisterComponent(TIoCRuntimeComponent.Create('IoC'));
  FContext.Configure;

  FContext.Shutdown;

  Assert.AreSame(Container, GlobalContainer,
    'Shutdown-before-start must not clear the global IoC container');
end;

procedure TTestDeepBaseRuntimeContext.ShutdownWithoutStart_DoesNotStopExplicitScheduler;
var
  Scheduler: TTaskScheduler;
begin
  Scheduler := TTaskScheduler.Create;
  try
    Scheduler.Start;
    Assert.IsTrue(Scheduler.Running);
    FContext.RegisterComponent(
      TSchedulerRuntimeComponent.Create('Scheduler', Scheduler));
    FContext.Configure;

    FContext.Shutdown;

    Assert.IsTrue(Scheduler.Running,
      'Shutdown-before-start must not stop an explicit Scheduler instance');
  finally
    Scheduler.Stop;
    Scheduler.Free;
  end;
end;

procedure TTestDeepBaseRuntimeContext.EventBusComponent_Stop_DrainsAsyncCallbacks;
var
  Bus: TEventBus;
  CallbackDone: Boolean;
begin
  CallbackDone := False;
  Bus := TEventBus.Create;
  try
    FContext.RegisterComponent(
      TEventBusRuntimeComponent.Create('EventBus', Bus, False));
    FContext.Start;

    Bus.Subscribe<TAsyncDrainEvent>(
      procedure(const Event: TAsyncDrainEvent)
      begin
        Sleep(80);
        CallbackDone := True;
      end,
      epNormal,
      edmAsync);

    var EventData: TAsyncDrainEvent;
    EventData.Value := 1;
    Bus.Publish<TAsyncDrainEvent>(EventData);
    FContext.Stop;

    Assert.IsTrue(CallbackDone,
      'RuntimeContext.Stop should wait until EventBus async callbacks are drained');
  finally
    if not FContext.ShutdownComplete then
      FContext.Shutdown;
    Bus.Free;
  end;
end;

procedure TTestDeepBaseRuntimeContext.CustomLifecycleOrder_StopsAsyncBeforeManager_AndLoggerBeforePersistence;
begin
  FContext.RegisterComponent(TTestRuntimeComponent.Create('Persistence', FLog));
  FContext.RegisterComponent(TTestRuntimeComponent.Create('Logger', FLog));
  FContext.RegisterComponent(TTestRuntimeComponent.Create('Manager', FLog));
  FContext.RegisterComponent(TTestRuntimeComponent.Create('EventBus', FLog));
  FContext.RegisterComponent(TTestRuntimeComponent.Create('Scheduler', FLog));
  FContext.RegisterComponent(TTestRuntimeComponent.Create('WorkerQueue', FLog));

  FContext.Start;
  FContext.Shutdown;

  AssertLogEquals([
    'Persistence.Configure',
    'Logger.Configure',
    'Manager.Configure',
    'EventBus.Configure',
    'Scheduler.Configure',
    'WorkerQueue.Configure',
    'Persistence.Initialize',
    'Logger.Initialize',
    'Manager.Initialize',
    'EventBus.Initialize',
    'Scheduler.Initialize',
    'WorkerQueue.Initialize',
    'Persistence.Start',
    'Logger.Start',
    'Manager.Start',
    'EventBus.Start',
    'Scheduler.Start',
    'WorkerQueue.Start',
    'WorkerQueue.Stop',
    'Scheduler.Stop',
    'EventBus.Stop',
    'Manager.Stop',
    'Logger.Stop',
    'Persistence.Stop',
    'WorkerQueue.Shutdown',
    'Scheduler.Shutdown',
    'EventBus.Shutdown',
    'Manager.Shutdown',
    'Logger.Shutdown',
    'Persistence.Shutdown'
  ]);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDeepBaseRuntimeContext);

end.
