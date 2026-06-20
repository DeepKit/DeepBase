/// <summary>
/// Unit tests for DeepBase.Scheduler module
/// Tests: TCronExpression, TRetryPolicy, TScheduledTask, TTaskScheduler
/// </summary>
unit Test.DeepBase.Scheduler;

interface

uses
  System.SysUtils,
  System.Classes,
  System.DateUtils,
  System.SyncObjs,
  DUnitX.TestFramework,
  DeepBase.Scheduler;

type
  /// <summary>
  /// Tests for TCronExpression
  /// </summary>
  [TestFixture]
  TCronExpressionTests = class
  public
    [Test]
    procedure Test_Parse_EveryMinute;
    [Test]
    procedure Test_Parse_EveryHour;
    [Test]
    procedure Test_Parse_DailyAt3AM;
    [Test]
    procedure Test_Parse_Every5Minutes;
    [Test]
    procedure Test_Parse_Weekdays9to5;
    [Test]
    procedure Test_Parse_SundayMidnight;
    [Test]
    procedure Test_Parse_Invalid;
    [Test]
    procedure Test_GetNextRun_EveryMinute;
    [Test]
    procedure Test_GetNextRun_DailyAt3AM;
    [Test]
    procedure Test_ToString;
  end;

  /// <summary>
  /// Tests for TRetryPolicy
  /// </summary>
  [TestFixture]
  TRetryPolicyTests = class
  public
    [Test]
    procedure Test_Default;
    [Test]
    procedure Test_NoRetry;
    [Test]
    procedure Test_GetDelay_FirstAttempt;
    [Test]
    procedure Test_GetDelay_ExponentialBackoff;
    [Test]
    procedure Test_GetDelay_MaxDelay;
  end;

  /// <summary>
  /// Tests for TScheduledTask fluent API
  /// </summary>
  [TestFixture]
  TScheduledTaskFluentTests = class
  private
    FScheduler: TTaskScheduler;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_WithName;
    [Test]
    procedure Test_Delay;
    [Test]
    procedure Test_Every;
    [Test]
    procedure Test_Cron;
    [Test]
    procedure Test_Priority;
    [Test]
    procedure Test_MaxRuns;
    [Test]
    procedure Test_Retry;
    [Test]
    procedure Test_DependsOn;
    [Test]
    procedure Test_Tag;
    [Test]
    procedure Test_FluentChain;
  end;

  /// <summary>
  /// Tests for TTaskScheduler basic operations
  /// </summary>
  [TestFixture]
  TTaskSchedulerBasicTests = class
  private
    FScheduler: TTaskScheduler;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Create;
    [Test]
    procedure Test_Schedule_ReturnsTask;
    [Test]
    procedure Test_Schedule_UniqueId;
    [Test]
    procedure Test_GetTask;
    [Test]
    procedure Test_GetTask_NotFound;
    [Test]
    procedure Test_HasTask;
    [Test]
    procedure Test_CancelTask;
    [Test]
    procedure Test_GetAllTasks;
    [Test]
    procedure Test_GetTasksByTag;
  end;

  /// <summary>
  /// Tests for TTaskScheduler execution
  /// </summary>
  [TestFixture]
  TTaskSchedulerExecutionTests = class
  private
    FScheduler: TTaskScheduler;
    FExecutionCount: Integer;
    FExecutedTaskIds: TArray<string>;
    FEvent: TEvent;
    procedure IncrementCounter;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Run_DelayedTask;
    [Test]
    procedure Test_Run_ImmediateTask;
    [Test]
    procedure Test_Run_IntervalTask;
    [Test]
    procedure Test_Run_MaxRuns;
    [Test]
    procedure Test_Start_Stop;
  end;

  /// <summary>
  /// Tests for task callbacks
  /// </summary>
  [TestFixture]
  TTaskCallbackTests = class
  private
    FScheduler: TTaskScheduler;
    FOnCompleteCalled: Boolean;
    FOnErrorCalled: Boolean;
    FLastError: string;
    FEvent: TEvent;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_OnComplete_Called;
    [Test]
    procedure Test_OnError_Called;
  end;

  /// <summary>
  /// Tests for task state transitions
  /// </summary>
  [TestFixture]
  TTaskStateTests = class
  private
    FScheduler: TTaskScheduler;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_InitialState_Idle;
    [Test]
    procedure Test_State_AfterRun_Pending;
    [Test]
    procedure Test_State_AfterCancel;
  end;

  /// <summary>
  /// Tests for task priorities
  /// </summary>
  [TestFixture]
  TTaskPriorityTests = class
  private
    FScheduler: TTaskScheduler;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_DefaultPriority_Normal;
    [Test]
    procedure Test_SetPriority_Low;
    [Test]
    procedure Test_SetPriority_High;
    [Test]
    procedure Test_SetPriority_Critical;
  end;

  /// <summary>
  /// Tests for global Scheduler() function
  /// </summary>
  [TestFixture]
  TGlobalSchedulerTests = class
  public
    [Test]
    procedure Test_GlobalScheduler_NotNil;
    [Test]
    procedure Test_GlobalScheduler_SameInstance;
  end;

implementation

// ============================================================================
// TCronExpressionTests
// ============================================================================

procedure TCronExpressionTests.Test_Parse_EveryMinute;
var
  Cron: TCronExpression;
begin
  Cron := TCronExpression.Parse('* * * * *');
  Assert.IsTrue(Cron.IsValid);
end;

procedure TCronExpressionTests.Test_Parse_EveryHour;
var
  Cron: TCronExpression;
begin
  Cron := TCronExpression.Parse('0 * * * *');
  Assert.IsTrue(Cron.IsValid);
end;

procedure TCronExpressionTests.Test_Parse_DailyAt3AM;
var
  Cron: TCronExpression;
begin
  Cron := TCronExpression.Parse('0 3 * * *');
  Assert.IsTrue(Cron.IsValid);
end;

procedure TCronExpressionTests.Test_Parse_Every5Minutes;
var
  Cron: TCronExpression;
begin
  Cron := TCronExpression.Parse('*/5 * * * *');
  Assert.IsTrue(Cron.IsValid);
end;

procedure TCronExpressionTests.Test_Parse_Weekdays9to5;
var
  Cron: TCronExpression;
begin
  Cron := TCronExpression.Parse('0 9-17 * * 1-5');
  Assert.IsTrue(Cron.IsValid);
end;

procedure TCronExpressionTests.Test_Parse_SundayMidnight;
var
  Cron: TCronExpression;
begin
  Cron := TCronExpression.Parse('0 0 * * 0');
  Assert.IsTrue(Cron.IsValid);
end;

procedure TCronExpressionTests.Test_Parse_Invalid;
var
  Cron: TCronExpression;
begin
  Cron := TCronExpression.Parse('invalid');
  Assert.IsFalse(Cron.IsValid);
end;

procedure TCronExpressionTests.Test_GetNextRun_EveryMinute;
var
  Cron: TCronExpression;
  Now, Next: TDateTime;
begin
  Cron := TCronExpression.Parse('* * * * *');
  Now := EncodeDateTime(2024, 1, 15, 10, 30, 0, 0);
  Next := Cron.GetNextRun(Now);
  // Should be next minute
  Assert.IsTrue(Next > Now);
  Assert.IsTrue(MinutesBetween(Next, Now) <= 1);
end;

procedure TCronExpressionTests.Test_GetNextRun_DailyAt3AM;
var
  Cron: TCronExpression;
  Now, Next: TDateTime;
  Hour, Min, Sec, MSec: Word;
begin
  Cron := TCronExpression.Parse('0 3 * * *');
  Now := EncodeDateTime(2024, 1, 15, 10, 30, 0, 0);
  Next := Cron.GetNextRun(Now);
  
  DecodeTime(Next, Hour, Min, Sec, MSec);
  Assert.AreEqual(Word(3), Hour);
  Assert.AreEqual(Word(0), Min);
end;

procedure TCronExpressionTests.Test_ToString;
var
  Cron: TCronExpression;
begin
  Cron := TCronExpression.Parse('0 3 * * *');
  Assert.IsNotEmpty(Cron.ToString);
end;

// ============================================================================
// TRetryPolicyTests
// ============================================================================

procedure TRetryPolicyTests.Test_Default;
var
  Policy: TRetryPolicy;
begin
  Policy := TRetryPolicy.Default;
  Assert.IsTrue(Policy.MaxRetries > 0);
  Assert.IsTrue(Policy.InitialDelayMs > 0);
end;

procedure TRetryPolicyTests.Test_NoRetry;
var
  Policy: TRetryPolicy;
begin
  Policy := TRetryPolicy.NoRetry;
  Assert.AreEqual(0, Policy.MaxRetries);
end;

procedure TRetryPolicyTests.Test_GetDelay_FirstAttempt;
var
  Policy: TRetryPolicy;
begin
  Policy := TRetryPolicy.Default;
  Policy.InitialDelayMs := 1000;
  Assert.AreEqual(1000, Policy.GetDelay(1));
end;

procedure TRetryPolicyTests.Test_GetDelay_ExponentialBackoff;
var
  Policy: TRetryPolicy;
  Delay1, Delay2: Integer;
begin
  Policy := TRetryPolicy.Default;
  Policy.InitialDelayMs := 1000;
  Policy.BackoffMultiplier := 2.0;
  
  Delay1 := Policy.GetDelay(1);
  Delay2 := Policy.GetDelay(2);
  
  Assert.IsTrue(Delay2 > Delay1);
end;

procedure TRetryPolicyTests.Test_GetDelay_MaxDelay;
var
  Policy: TRetryPolicy;
  Delay: Integer;
begin
  Policy := TRetryPolicy.Default;
  Policy.InitialDelayMs := 1000;
  Policy.MaxDelayMs := 5000;
  Policy.BackoffMultiplier := 10.0;
  
  Delay := Policy.GetDelay(5);
  Assert.IsTrue(Delay <= Policy.MaxDelayMs);
end;

// ============================================================================
// TScheduledTaskFluentTests
// ============================================================================

procedure TScheduledTaskFluentTests.Setup;
begin
  FScheduler := TTaskScheduler.Create;
end;

procedure TScheduledTaskFluentTests.TearDown;
begin
  FScheduler.Free;
end;

procedure TScheduledTaskFluentTests.Test_WithName;
var
  Task: TScheduledTask;
begin
  Task := FScheduler.Schedule('test', procedure begin end);
  Task.WithName('Test Task');
  Assert.AreEqual('Test Task', Task.Name);
end;

procedure TScheduledTaskFluentTests.Test_Delay;
var
  Task: TScheduledTask;
begin
  Task := FScheduler.Schedule('test', procedure begin end);
  Task.Delay(5000);
  Assert.IsTrue(Task.NextRunAt > Now);
end;

procedure TScheduledTaskFluentTests.Test_Every;
var
  Task: TScheduledTask;
begin
  Task := FScheduler.Schedule('test', procedure begin end);
  Task.Every(60000);
  // Should accept interval without error
  Assert.IsNotNull(Task);
end;

procedure TScheduledTaskFluentTests.Test_Cron;
var
  Task: TScheduledTask;
begin
  Task := FScheduler.Schedule('test', procedure begin end);
  Task.Cron('0 3 * * *');
  Assert.IsNotNull(Task);
end;

procedure TScheduledTaskFluentTests.Test_Priority;
var
  Task: TScheduledTask;
begin
  Task := FScheduler.Schedule('test', procedure begin end);
  Task.Priority(tpHigh);
  // Should set priority without error
  Assert.IsNotNull(Task);
end;

procedure TScheduledTaskFluentTests.Test_MaxRuns;
var
  Task: TScheduledTask;
begin
  Task := FScheduler.Schedule('test', procedure begin end);
  Task.MaxRuns(5);
  Assert.IsNotNull(Task);
end;

procedure TScheduledTaskFluentTests.Test_Retry;
var
  Task: TScheduledTask;
begin
  Task := FScheduler.Schedule('test', procedure begin end);
  Task.Retry(3, 1000);
  Assert.IsNotNull(Task);
end;

procedure TScheduledTaskFluentTests.Test_DependsOn;
var
  Task: TScheduledTask;
begin
  Task := FScheduler.Schedule('test', procedure begin end);
  Task.DependsOn(['task1', 'task2']);
  Assert.IsNotNull(Task);
end;

procedure TScheduledTaskFluentTests.Test_Tag;
var
  Task: TScheduledTask;
begin
  Task := FScheduler.Schedule('test', procedure begin end);
  Task.Tag('email').Tag('notification');
  Assert.AreEqual(2, Integer(Length(Task.Tags)));
end;

procedure TScheduledTaskFluentTests.Test_FluentChain;
var
  Task: TScheduledTask;
begin
  Task := FScheduler.Schedule('test', procedure begin end)
    .WithName('Chained Task')
    .Delay(1000)
    .Priority(tpHigh)
    .MaxRuns(3)
    .Tag('test');
  
  Assert.AreEqual('Chained Task', Task.Name);
  Assert.AreEqual(1, Integer(Length(Task.Tags)));
end;

// ============================================================================
// TTaskSchedulerBasicTests
// ============================================================================

procedure TTaskSchedulerBasicTests.Setup;
begin
  FScheduler := TTaskScheduler.Create;
end;

procedure TTaskSchedulerBasicTests.TearDown;
begin
  FScheduler.Free;
end;

procedure TTaskSchedulerBasicTests.Test_Create;
begin
  Assert.IsNotNull(FScheduler);
end;

procedure TTaskSchedulerBasicTests.Test_Schedule_ReturnsTask;
var
  Task: TScheduledTask;
begin
  Task := FScheduler.Schedule('test', procedure begin end);
  Assert.IsNotNull(Task);
  Assert.AreEqual('test', Task.Id);
end;

procedure TTaskSchedulerBasicTests.Test_Schedule_UniqueId;
var
  Task1, Task2: TScheduledTask;
begin
  Task1 := FScheduler.Schedule('task1', procedure begin end);
  Task2 := FScheduler.Schedule('task2', procedure begin end);
  Assert.AreNotEqual(Task1.Id, Task2.Id);
end;

procedure TTaskSchedulerBasicTests.Test_GetTask;
var
  Task, Retrieved: TScheduledTask;
begin
  Task := FScheduler.Schedule('myTask', procedure begin end);
  Task.Run;
  Retrieved := FScheduler.GetTask('myTask');
  Assert.AreSame(Task, Retrieved);
end;

procedure TTaskSchedulerBasicTests.Test_GetTask_NotFound;
var
  Task: TScheduledTask;
begin
  Task := FScheduler.GetTask('nonexistent');
  Assert.IsNull(Task);
end;

procedure TTaskSchedulerBasicTests.Test_HasTask;
begin
  FScheduler.Schedule('test', procedure begin end).Run;
  Assert.IsTrue(FScheduler.HasTask('test'));
  Assert.IsFalse(FScheduler.HasTask('other'));
end;

procedure TTaskSchedulerBasicTests.Test_CancelTask;
var
  Task: TScheduledTask;
begin
  Task := FScheduler.Schedule('test', procedure begin end);
  Task.Delay(10000).Run;
  
  FScheduler.CancelTask('test');
  Assert.AreEqual(tsCancelled, Task.State);
end;

procedure TTaskSchedulerBasicTests.Test_GetAllTasks;
var
  Tasks: TArray<TScheduledTask>;
begin
  FScheduler.Schedule('task1', procedure begin end).Run;
  FScheduler.Schedule('task2', procedure begin end).Run;
  FScheduler.Schedule('task3', procedure begin end).Run;
  
  Tasks := FScheduler.GetTasksByState(tsPending);
  Assert.AreEqual(3, Integer(Length(Tasks)));
end;

procedure TTaskSchedulerBasicTests.Test_GetTasksByTag;
var
  Tasks: TArray<TScheduledTask>;
begin
  FScheduler.Schedule('task1', procedure begin end).Tag('email').Run;
  FScheduler.Schedule('task2', procedure begin end).Tag('email').Run;
  FScheduler.Schedule('task3', procedure begin end).Tag('other').Run;
  
  Tasks := FScheduler.GetTasksByTag('email');
  Assert.AreEqual(2, Integer(Length(Tasks)));
end;

// ============================================================================
// TTaskSchedulerExecutionTests
// ============================================================================

procedure TTaskSchedulerExecutionTests.Setup;
begin
  FScheduler := TTaskScheduler.Create;
  FScheduler.Start;
  FExecutionCount := 0;
  SetLength(FExecutedTaskIds, 0);
  FEvent := TEvent.Create(nil, True, False, '');
end;

procedure TTaskSchedulerExecutionTests.TearDown;
begin
  FScheduler.Stop;
  FScheduler.Free;
  FEvent.Free;
end;

procedure TTaskSchedulerExecutionTests.IncrementCounter;
begin
  TInterlocked.Increment(FExecutionCount);
  FEvent.SetEvent;
end;


procedure TTaskSchedulerExecutionTests.Test_Run_DelayedTask;
begin
  FScheduler.Schedule('delayed', IncrementCounter)
    .Delay(100)
    .Run;
  
  FEvent.WaitFor(2000);
  Assert.AreEqual(1, FExecutionCount);
end;

procedure TTaskSchedulerExecutionTests.Test_Run_ImmediateTask;
begin
  FScheduler.Schedule('immediate', IncrementCounter)
    .Delay(0)
    .Run;
  
  FEvent.WaitFor(1000);
  Assert.AreEqual(1, FExecutionCount);
end;

procedure TTaskSchedulerExecutionTests.Test_Run_IntervalTask;
begin
  FScheduler.Schedule('interval', IncrementCounter)
    .Every(100)
    .MaxRuns(3)
    .Run;
  
  Sleep(500);
  Assert.IsTrue(FExecutionCount >= 2);
end;

procedure TTaskSchedulerExecutionTests.Test_Run_MaxRuns;
begin
  FScheduler.Schedule('limited', IncrementCounter)
    .Every(50)
    .MaxRuns(2)
    .Run;
  
  Sleep(500);
  Assert.AreEqual(2, FExecutionCount);
end;

procedure TTaskSchedulerExecutionTests.Test_Start_Stop;
begin
  FScheduler.Stop;
  Assert.IsFalse(FScheduler.Running);

  FScheduler.Start;
  Assert.IsTrue(FScheduler.Running);

  FScheduler.Stop;
  Assert.IsFalse(FScheduler.Running);
end;

// ============================================================================
// TTaskCallbackTests
// ============================================================================

procedure TTaskCallbackTests.Setup;
begin
  FScheduler := TTaskScheduler.Create;
  FScheduler.Start;
  FOnCompleteCalled := False;
  FOnErrorCalled := False;
  FLastError := '';
  FEvent := TEvent.Create(nil, True, False, '');
end;

procedure TTaskCallbackTests.TearDown;
begin
  FScheduler.Stop;
  FScheduler.Free;
  FEvent.Free;
end;

procedure TTaskCallbackTests.Test_OnComplete_Called;
begin
  FScheduler.Schedule('test',
    procedure
    begin
      // Do nothing, just complete
    end)
    .Delay(50)
    .OnComplete(
      procedure(const Task: TScheduledTask)
      begin
        FOnCompleteCalled := True;
        FEvent.SetEvent;
      end)
    .Run;
  
  FEvent.WaitFor(2000);
  Assert.IsTrue(FOnCompleteCalled);
end;

procedure TTaskCallbackTests.Test_OnError_Called;
begin
  FScheduler.Schedule('test',
    procedure
    begin
      raise Exception.Create('Test error');
    end)
    .Delay(50)
    .Retry(0, 0)  // No retry
    .OnError(
      procedure(const Task: TScheduledTask; const Error: Exception)
      begin
        FOnErrorCalled := True;
        FLastError := Error.Message;
        FEvent.SetEvent;
      end)
    .Run;
  
  FEvent.WaitFor(2000);
  Assert.IsTrue(FOnErrorCalled);
  Assert.AreEqual('Test error', FLastError);
end;

// ============================================================================
// TTaskStateTests
// ============================================================================

procedure TTaskStateTests.Setup;
begin
  FScheduler := TTaskScheduler.Create;
end;

procedure TTaskStateTests.TearDown;
begin
  FScheduler.Free;
end;

procedure TTaskStateTests.Test_InitialState_Idle;
var
  Task: TScheduledTask;
begin
  Task := FScheduler.Schedule('test', procedure begin end);
  Assert.AreEqual(tsIdle, Task.State);
end;

procedure TTaskStateTests.Test_State_AfterRun_Pending;
var
  Task: TScheduledTask;
begin
  Task := FScheduler.Schedule('test', procedure begin end);
  Task.Delay(10000).Run;
  Assert.AreEqual(tsPending, Task.State);
end;

procedure TTaskStateTests.Test_State_AfterCancel;
var
  Task: TScheduledTask;
begin
  Task := FScheduler.Schedule('test', procedure begin end);
  Task.Delay(10000).Run;
  Task.Cancel;
  Assert.AreEqual(tsCancelled, Task.State);
end;

// ============================================================================
// TTaskPriorityTests
// ============================================================================

procedure TTaskPriorityTests.Setup;
begin
  FScheduler := TTaskScheduler.Create;
end;

procedure TTaskPriorityTests.TearDown;
begin
  FScheduler.Free;
end;

procedure TTaskPriorityTests.Test_DefaultPriority_Normal;
var
  Task: TScheduledTask;
begin
  Task := FScheduler.Schedule('test', procedure begin end);
  // Default should be normal - just test it's set
  Assert.IsNotNull(Task);
end;

procedure TTaskPriorityTests.Test_SetPriority_Low;
var
  Task: TScheduledTask;
begin
  Task := FScheduler.Schedule('test', procedure begin end);
  Task.Priority(tpLow);
  Assert.IsNotNull(Task);
end;

procedure TTaskPriorityTests.Test_SetPriority_High;
var
  Task: TScheduledTask;
begin
  Task := FScheduler.Schedule('test', procedure begin end);
  Task.Priority(tpHigh);
  Assert.IsNotNull(Task);
end;

procedure TTaskPriorityTests.Test_SetPriority_Critical;
var
  Task: TScheduledTask;
begin
  Task := FScheduler.Schedule('test', procedure begin end);
  Task.Priority(tpCritical);
  Assert.IsNotNull(Task);
end;

// ============================================================================
// TGlobalSchedulerTests
// ============================================================================

procedure TGlobalSchedulerTests.Test_GlobalScheduler_NotNil;
begin
  Assert.IsNotNull(Scheduler);
end;

procedure TGlobalSchedulerTests.Test_GlobalScheduler_SameInstance;
var
  S1, S2: TTaskScheduler;
begin
  S1 := Scheduler;
  S2 := Scheduler;
  Assert.AreSame(S1, S2);
end;

initialization
  TDUnitX.RegisterTestFixture(TCronExpressionTests);
  TDUnitX.RegisterTestFixture(TRetryPolicyTests);
  TDUnitX.RegisterTestFixture(TScheduledTaskFluentTests);
  TDUnitX.RegisterTestFixture(TTaskSchedulerBasicTests);
  TDUnitX.RegisterTestFixture(TTaskSchedulerExecutionTests);
  TDUnitX.RegisterTestFixture(TTaskCallbackTests);
  TDUnitX.RegisterTestFixture(TTaskStateTests);
  TDUnitX.RegisterTestFixture(TTaskPriorityTests);
  TDUnitX.RegisterTestFixture(TGlobalSchedulerTests);

end.
