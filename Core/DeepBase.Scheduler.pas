{ ============================================================================
  DeepBase.Scheduler - Task Scheduler
  
  A flexible task scheduling system for background job execution.
  
  Features:
  - Cron expression support (minute, hour, day, month, weekday)
  - One-time delayed tasks
  - Recurring interval tasks
  - Task retry with exponential backoff
  - Task priority and dependencies
  - Thread pool execution
  - Task persistence (optional)
  - Graceful shutdown
  
  Usage:
    // Simple delayed task
    Scheduler.Schedule('send-email',
      procedure
      begin
        SendEmail('user@example.com', 'Hello');
      end)
      .Delay(5000)     // 5 seconds
      .Run;
    
    // Cron task (every day at 3:00 AM)
    Scheduler.Schedule('daily-backup',
      procedure
      begin
        PerformBackup;
      end)
      .Cron('0 3 * * *')
      .Run;
    
    // Interval task with retry
    Scheduler.Schedule('sync-data',
      procedure
      begin
        SyncWithServer;
      end)
      .Every(60000)    // Every minute
      .Retry(3, 1000)  // 3 retries, 1 second initial delay
      .Run;
  ============================================================================ }

unit DeepBase.Scheduler;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Generics.Defaults,
  System.SyncObjs,
  System.Threading,
  System.DateUtils,
  System.Math,
  System.RegularExpressions,
  DeepBase.Exceptions;

type
  // ============================================================================
  // Task Types
  // ============================================================================
  
  TTaskState = (tsIdle, tsPending, tsRunning, tsCompleted, tsFailed, tsCancelled);
  TTaskPriority = (tpLow, tpNormal, tpHigh, tpCritical);

  /// <summary>
  /// Persisted task metadata (no proc reference ¡ª callers re-register on restart).
  /// </summary>
  TTaskMeta = record
    Id: string;
    Name: string;
    State: TTaskState;
    Priority: TTaskPriority;
    DelayMs: Integer;
    IntervalMs: Integer;
    CronExpr: string;
    UseCron: Boolean;
    RunCount: Integer;
    MaxRuns: Integer;
    CreatedAt: TDateTime;
    NextRunAt: TDateTime;
    LastRunAt: TDateTime;
    Tags: string;
    DependsOn: string;
  end;

  IJobStore = interface
    ['{A7B3C9D2-E4F5-4A6B-8C9D-0E1F2A3B4C5D}']
    procedure SaveTask(const AMeta: TTaskMeta);
    procedure RemoveTask(const ATaskId: string);
    function LoadAll: TArray<TTaskMeta>;
    procedure Clear;
  end;
  
  TTaskProc = reference to procedure;
  TTaskProcWithContext = reference to procedure(const TaskId: string);
  
  // ============================================================================
  // Cron Expression Parser
  // ============================================================================
  
  /// <summary>
  /// Cron expression: minute hour day month weekday
  /// Examples:
  ///   "* * * * *"     - every minute
  ///   "0 * * * *"     - every hour
  ///   "0 3 * * *"     - every day at 3:00 AM
  ///   "0 0 * * 0"     - every Sunday at midnight
  ///   "*/5 * * * *"   - every 5 minutes
  ///   "0 9-17 * * 1-5" - 9 AM to 5 PM on weekdays
  /// </summary>
  TCronExpression = record
  private
    FMinutes: TArray<Integer>;    // 0-59
    FHours: TArray<Integer>;      // 0-23
    FDays: TArray<Integer>;       // 1-31
    FMonths: TArray<Integer>;     // 1-12
    FWeekdays: TArray<Integer>;   // 0-6 (Sunday = 0)
    FIsValid: Boolean;
    
    class function ParseField(const Field: string; Min, Max: Integer): TArray<Integer>; static;
    function Matches(const DT: TDateTime): Boolean;
  public
    class function Parse(const Expression: string): TCronExpression; static;
    function GetNextRun(const From: TDateTime): TDateTime;
    function ToString: string;
    property IsValid: Boolean read FIsValid;
  end;
  
  // ============================================================================
  // Retry Policy
  // ============================================================================
  
  TRetryPolicy = record
    MaxRetries: Integer;
    InitialDelayMs: Integer;
    MaxDelayMs: Integer;
    BackoffMultiplier: Double;
    
    class function Default: TRetryPolicy; static;
    class function NoRetry: TRetryPolicy; static;
    function GetDelay(Attempt: Integer): Integer;
  end;
  
  // ============================================================================
  // Scheduled Task
  // ============================================================================
  
  TScheduledTask = class;
  TTaskScheduler = class;
  
  TTaskCompletedEvent = reference to procedure(const Task: TScheduledTask);
  TTaskFailedEvent = reference to procedure(const Task: TScheduledTask;
    const Error: Exception);
  
  /// <summary>
  /// Represents a scheduled task
  /// </summary>
  TScheduledTask = class
  private
    FId: string;
    FName: string;
    FProc: TTaskProc;
    FScheduler: TTaskScheduler;
    FState: TTaskState;
    FPriority: TTaskPriority;
    
    // Scheduling options
    FDelayMs: Integer;
    FIntervalMs: Integer;
    FCronExpr: TCronExpression;
    FUseCron: Boolean;
    FRunCount: Integer;
    FMaxRuns: Integer;         // 0 = unlimited
    
    // Timing
    FCreatedAt: TDateTime;
    FNextRunAt: TDateTime;
    FLastRunAt: TDateTime;
    FLastDuration: Integer;    // milliseconds
    
    // Retry
    FRetryPolicy: TRetryPolicy;
    FCurrentRetry: Integer;
    FLastError: string;
    
    // Events
    FOnCompleted: TTaskCompletedEvent;
    FOnFailed: TTaskFailedEvent;
    
    // Dependencies
    FDependsOn: TArray<string>;
    FTags: TArray<string>;
    
    procedure CalculateNextRun;
  public
    constructor Create(AScheduler: TTaskScheduler; const AId: string);
    
    // Fluent configuration
    function WithName(const AName: string): TScheduledTask;
    function Delay(Ms: Integer): TScheduledTask;
    function Every(Ms: Integer): TScheduledTask;
    function Cron(const Expression: string): TScheduledTask;
    function Priority(APriority: TTaskPriority): TScheduledTask;
    function MaxRuns(Count: Integer): TScheduledTask;
    function Retry(MaxRetries: Integer; InitialDelayMs: Integer = 1000): TScheduledTask;
    function DependsOn(const TaskIds: array of string): TScheduledTask;
    function Tag(const ATag: string): TScheduledTask;
    function OnComplete(Handler: TTaskCompletedEvent): TScheduledTask;
    function OnError(Handler: TTaskFailedEvent): TScheduledTask;
    
    /// <summary>Submit task to scheduler</summary>
    procedure Run;
    
    /// <summary>Cancel task</summary>
    procedure Cancel;
    
    property Id: string read FId;
    property Name: string read FName;
    property State: TTaskState read FState;
    property NextRunAt: TDateTime read FNextRunAt;
    property LastRunAt: TDateTime read FLastRunAt;
    property RunCount: Integer read FRunCount;
    property LastError: string read FLastError;
    property Tags: TArray<string> read FTags;
  end;
  
  // ============================================================================
  // Scheduler Statistics
  // ============================================================================
  
  TSchedulerStats = record
    TotalTasks: Integer;
    PendingTasks: Integer;
    RunningTasks: Integer;
    CompletedTasks: Integer;
    FailedTasks: Integer;
    TotalExecutions: Int64;
    
    procedure Reset;
    function ToString: string;
  end;
  
  // ============================================================================
  // Task Scheduler
  // ============================================================================
  
  /// <summary>
  /// Main task scheduler class
  /// </summary>
  TTaskScheduler = class
  private
    FTasks: TObjectDictionary<string, TScheduledTask>;
    FLock: TCriticalSection;
    FTimerThread: TThread;
    FRunning: Boolean;
    FStats: TSchedulerStats;
    FCheckIntervalMs: Integer;
    FMaxConcurrentTasks: Integer;
    FRunningCount: Integer;
    FJobStore: IJobStore;
    FShutdownEvent: TEvent;

    procedure TimerProc;
    procedure ExecuteTask(Task: TScheduledTask);
    procedure ProcessPendingTasks;
    function CanRunTask(Task: TScheduledTask): Boolean;
    procedure SaveTaskMeta(Task: TScheduledTask);
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>Start scheduler</summary>
    procedure Start;

    /// <summary>Stop scheduler (waits for running tasks)</summary>
    procedure Stop;

    /// <summary>Set job store for persistence</summary>
    procedure SetJobStore(const AStore: IJobStore);

    /// <summary>Get persisted task IDs (for re-registration on restart)</summary>
    function GetPersistedTaskIds: TArray<string>;
    
    /// <summary>Create new task</summary>
    function Schedule(const TaskId: string; Proc: TTaskProc): TScheduledTask;
    
    /// <summary>Get task by ID</summary>
    function GetTask(const TaskId: string): TScheduledTask;
    
    /// <summary>Check if task exists</summary>
    function HasTask(const TaskId: string): Boolean;
    
    /// <summary>Cancel task</summary>
    function CancelTask(const TaskId: string): Boolean;
    
    /// <summary>Cancel all tasks with tag</summary>
    procedure CancelByTag(const Tag: string);
    
    /// <summary>Remove completed/failed tasks</summary>
    procedure Cleanup;
    
    /// <summary>Get all task IDs</summary>
    function GetTaskIds: TArray<string>;
    
    /// <summary>Get tasks by state</summary>
    function GetTasksByState(State: TTaskState): TArray<TScheduledTask>;
    
    /// <summary>Get tasks by tag</summary>
    function GetTasksByTag(const Tag: string): TArray<TScheduledTask>;
    
    property Running: Boolean read FRunning;
    property Stats: TSchedulerStats read FStats;
    property CheckIntervalMs: Integer read FCheckIntervalMs write FCheckIntervalMs;
    property MaxConcurrentTasks: Integer read FMaxConcurrentTasks write FMaxConcurrentTasks;
  end;
  
  // ============================================================================
  // Global Scheduler
  // ============================================================================

/// <summary>Get global scheduler instance</summary>
function Scheduler: TTaskScheduler;

/// <summary>Set custom scheduler (for testing)</summary>
procedure SetScheduler(AScheduler: TTaskScheduler);

implementation

var
  GScheduler: TTaskScheduler = nil;
  GSchedulerLock: TCriticalSection = nil;

function Scheduler: TTaskScheduler;
begin
  if GScheduler = nil then
  begin
    GSchedulerLock.Enter;
    try
      if GScheduler = nil then
      begin
        GScheduler := TTaskScheduler.Create;
        GScheduler.Start;
      end;
    finally
      GSchedulerLock.Leave;
    end;
  end;
  Result := GScheduler;
end;

procedure SetScheduler(AScheduler: TTaskScheduler);
begin
  GSchedulerLock.Enter;
  try
    if GScheduler <> AScheduler then
    begin
      if GScheduler <> nil then
      begin
        GScheduler.Stop;
        GScheduler.Free;
      end;
      GScheduler := AScheduler;
    end;
  finally
    GSchedulerLock.Leave;
  end;
end;

// ============================================================================
// TCronExpression
// ============================================================================

class function TCronExpression.ParseField(const Field: string;
  Min, Max: Integer): TArray<Integer>;
var
  Parts: TArray<string>;
  Part: string;
  Values: TList<Integer>;
  I, J, Start, Stop, Step, Val: Integer;
  RangeParts, StepParts: TArray<string>;
begin
  Values := TList<Integer>.Create;
  try
    // Handle wildcard
    if Field = '*' then
    begin
      SetLength(Result, Max - Min + 1);
      for I := Min to Max do
        Result[I - Min] := I;
      Exit;
    end;
    
    // Split by comma
    Parts := Field.Split([',']);
    
    for I := Low(Parts) to High(Parts) do
    begin
      Part := Parts[I];
      // Check for step
      StepParts := Part.Split(['/']);
      Step := 1;
      if Length(StepParts) = 2 then
        Step := StrToIntDef(StepParts[1], 1);
      
      // Check for range
      if StepParts[0] = '*' then
      begin
        Start := Min;
        Stop := Max;
      end
      else if Pos('-', StepParts[0]) > 0 then
      begin
        RangeParts := StepParts[0].Split(['-']);
        Start := StrToIntDef(RangeParts[0], Min);
        Stop := StrToIntDef(RangeParts[1], Max);
      end
      else
      begin
        Val := StrToIntDef(StepParts[0], -1);
        if (Val >= Min) and (Val <= Max) then
          Values.Add(Val);
        Continue;
      end;
      
      // Add values with step
      J := Start;
      while J <= Stop do
      begin
        if (J >= Min) and (J <= Max) and not Values.Contains(J) then
          Values.Add(J);
        Inc(J, Step);
      end;
    end;
    
    Values.Sort;
    Result := Values.ToArray;
  finally
    Values.Free;
  end;
end;

class function TCronExpression.Parse(const Expression: string): TCronExpression;
var
  Parts: TArray<string>;
begin
  Result.FIsValid := False;
  
  // Split expression
  Parts := Expression.Trim.Split([' '], TStringSplitOptions.ExcludeEmpty);
  
  if Length(Parts) <> 5 then
    Exit;
  
  try
    Result.FMinutes := ParseField(Parts[0], 0, 59);
    Result.FHours := ParseField(Parts[1], 0, 23);
    Result.FDays := ParseField(Parts[2], 1, 31);
    Result.FMonths := ParseField(Parts[3], 1, 12);
    Result.FWeekdays := ParseField(Parts[4], 0, 6);
    
    Result.FIsValid := (Length(Result.FMinutes) > 0) and
                       (Length(Result.FHours) > 0) and
                       (Length(Result.FDays) > 0) and
                       (Length(Result.FMonths) > 0) and
                       (Length(Result.FWeekdays) > 0);
  except
    Result.FIsValid := False;
  end;
end;

function TCronExpression.Matches(const DT: TDateTime): Boolean;
var
  Year, Month, Day, Hour, Minute, Second, Ms: Word;
  Weekday, Val: Integer;
  Found: Boolean;
begin
  if not FIsValid then
    Exit(False);
  
  DecodeDateTime(DT, Year, Month, Day, Hour, Minute, Second, Ms);
  Weekday := DayOfTheWeek(DT) mod 7;  // Convert to 0=Sunday
  
  // Check minute
  Found := False;
  for Val in FMinutes do
    if Val = Minute then
    begin
      Found := True;
      Break;
    end;
  if not Found then Exit(False);
  
  // Check hour
  Found := False;
  for Val in FHours do
    if Val = Hour then
    begin
      Found := True;
      Break;
    end;
  if not Found then Exit(False);
  
  // Check day
  Found := False;
  for Val in FDays do
    if Val = Day then
    begin
      Found := True;
      Break;
    end;
  if not Found then Exit(False);
  
  // Check month
  Found := False;
  for Val in FMonths do
    if Val = Month then
    begin
      Found := True;
      Break;
    end;
  if not Found then Exit(False);
  
  // Check weekday
  Found := False;
  for Val in FWeekdays do
    if Val = Weekday then
    begin
      Found := True;
      Break;
    end;
  if not Found then Exit(False);
  
  Result := True;
end;

function TCronExpression.GetNextRun(const From: TDateTime): TDateTime;
var
  DT: TDateTime;
  MaxIterations: Integer;
begin
  if not FIsValid then
    Exit(0);
  
  // Start from next minute
  DT := IncMinute(From);
  DT := RecodeSecond(DT, 0);
  DT := RecodeMilliSecond(DT, 0);
  
  MaxIterations := 366 * 24 * 60;  // Max 1 year
  
  while MaxIterations > 0 do
  begin
    if Matches(DT) then
      Exit(DT);
    DT := IncMinute(DT);
    Dec(MaxIterations);
  end;
  
  Result := 0;  // No valid time found
end;

function TCronExpression.ToString: string;
begin
  if FIsValid then
    Result := Format('Cron: min=%d hrs=%d days=%d mon=%d wday=%d',
      [Length(FMinutes), Length(FHours), Length(FDays),
       Length(FMonths), Length(FWeekdays)])
  else
    Result := 'Invalid cron expression';
end;

// ============================================================================
// TRetryPolicy
// ============================================================================

class function TRetryPolicy.Default: TRetryPolicy;
begin
  Result.MaxRetries := 3;
  Result.InitialDelayMs := 1000;
  Result.MaxDelayMs := 30000;
  Result.BackoffMultiplier := 2.0;
end;

class function TRetryPolicy.NoRetry: TRetryPolicy;
begin
  Result.MaxRetries := 0;
  Result.InitialDelayMs := 0;
  Result.MaxDelayMs := 0;
  Result.BackoffMultiplier := 1.0;
end;

function TRetryPolicy.GetDelay(Attempt: Integer): Integer;
var
  Delay: Double;
begin
  Delay := InitialDelayMs * Power(BackoffMultiplier, Attempt - 1);
  Result := Min(Round(Delay), MaxDelayMs);
end;

// ============================================================================
// TSchedulerStats
// ============================================================================

procedure TSchedulerStats.Reset;
begin
  TotalTasks := 0;
  PendingTasks := 0;
  RunningTasks := 0;
  CompletedTasks := 0;
  FailedTasks := 0;
  TotalExecutions := 0;
end;

function TSchedulerStats.ToString: string;
begin
  Result := Format('Total: %d, Pending: %d, Running: %d, Completed: %d, Failed: %d, Executions: %d',
    [TotalTasks, PendingTasks, RunningTasks, CompletedTasks, FailedTasks, TotalExecutions]);
end;

// ============================================================================
// TScheduledTask
// ============================================================================

constructor TScheduledTask.Create(AScheduler: TTaskScheduler; const AId: string);
begin
  inherited Create;
  FScheduler := AScheduler;
  FId := AId;
  FName := AId;
  FState := tsIdle;
  FPriority := tpNormal;
  FDelayMs := 0;
  FIntervalMs := 0;
  FUseCron := False;
  FRunCount := 0;
  FMaxRuns := 0;
  FCreatedAt := Now;
  FNextRunAt := 0;
  FLastRunAt := 0;
  FLastDuration := 0;
  FRetryPolicy := TRetryPolicy.NoRetry;
  FCurrentRetry := 0;
  FLastError := '';
end;

function TScheduledTask.WithName(const AName: string): TScheduledTask;
begin
  FName := AName;
  Result := Self;
end;

function TScheduledTask.Delay(Ms: Integer): TScheduledTask;
begin
  FDelayMs := Ms;
  FIntervalMs := 0;
  FUseCron := False;
  CalculateNextRun;
  Result := Self;
end;

function TScheduledTask.Every(Ms: Integer): TScheduledTask;
begin
  FDelayMs := 0;
  FIntervalMs := Ms;
  FUseCron := False;
  CalculateNextRun;
  Result := Self;
end;

function TScheduledTask.Cron(const Expression: string): TScheduledTask;
begin
  FDelayMs := 0;
  FIntervalMs := 0;
  FCronExpr := TCronExpression.Parse(Expression);
  FUseCron := FCronExpr.IsValid;
  CalculateNextRun;
  Result := Self;
end;

function TScheduledTask.Priority(APriority: TTaskPriority): TScheduledTask;
begin
  FPriority := APriority;
  Result := Self;
end;

function TScheduledTask.MaxRuns(Count: Integer): TScheduledTask;
begin
  FMaxRuns := Count;
  Result := Self;
end;

function TScheduledTask.Retry(MaxRetries, InitialDelayMs: Integer): TScheduledTask;
begin
  FRetryPolicy.MaxRetries := MaxRetries;
  FRetryPolicy.InitialDelayMs := InitialDelayMs;
  FRetryPolicy.MaxDelayMs := InitialDelayMs * 10;
  FRetryPolicy.BackoffMultiplier := 2.0;
  Result := Self;
end;

function TScheduledTask.DependsOn(const TaskIds: array of string): TScheduledTask;
var
  I: Integer;
begin
  SetLength(FDependsOn, Length(TaskIds));
  for I := 0 to High(TaskIds) do
    FDependsOn[I] := TaskIds[I];
  Result := Self;
end;

function TScheduledTask.Tag(const ATag: string): TScheduledTask;
var
  Len: Integer;
begin
  Len := Length(FTags);
  SetLength(FTags, Len + 1);
  FTags[Len] := ATag;
  Result := Self;
end;

function TScheduledTask.OnComplete(Handler: TTaskCompletedEvent): TScheduledTask;
begin
  FOnCompleted := Handler;
  Result := Self;
end;

function TScheduledTask.OnError(Handler: TTaskFailedEvent): TScheduledTask;
begin
  FOnFailed := Handler;
  Result := Self;
end;

procedure TScheduledTask.CalculateNextRun;
begin
  if FUseCron then
    FNextRunAt := FCronExpr.GetNextRun(Now)
  else if FIntervalMs > 0 then
    FNextRunAt := IncMilliSecond(Now, FIntervalMs)
  else if FDelayMs > 0 then
    FNextRunAt := IncMilliSecond(Now, FDelayMs)
  else
    FNextRunAt := Now;
end;

procedure TScheduledTask.Run;
begin
  FState := tsPending;
  CalculateNextRun;
end;

procedure TScheduledTask.Cancel;
begin
  FState := tsCancelled;
end;

// ============================================================================
// TTaskScheduler
// ============================================================================

constructor TTaskScheduler.Create;
begin
  inherited Create;
  FTasks := TObjectDictionary<string, TScheduledTask>.Create([doOwnsValues]);
  FLock := TCriticalSection.Create;
  FShutdownEvent := TEvent.Create(nil, True, False, '');
  FRunning := False;
  FCheckIntervalMs := 100;
  FMaxConcurrentTasks := 4;
  FRunningCount := 0;
  FJobStore := nil;
  FStats.Reset;
end;

destructor TTaskScheduler.Destroy;
begin
  Stop;
  FreeAndNil(FTasks);
  FreeAndNil(FLock);
  FreeAndNil(FShutdownEvent);
  inherited;
end;

procedure TTaskScheduler.SetJobStore(const AStore: IJobStore);
begin
  FLock.Enter;
  try
    FJobStore := AStore;
  finally
    FLock.Leave;
  end;
end;

function TTaskScheduler.GetPersistedTaskIds: TArray<string>;
var
  Metas: TArray<TTaskMeta>;
  I: Integer;
begin
  if FJobStore = nil then
    Exit(nil);
  Metas := FJobStore.LoadAll;
  SetLength(Result, Length(Metas));
  for I := 0 to High(Metas) do
    Result[I] := Metas[I].Id;
end;

procedure TTaskScheduler.SaveTaskMeta(Task: TScheduledTask);
var
  Meta: TTaskMeta;
  DepsStr, TagsStr: string;
  I: Integer;
begin
  if FJobStore = nil then
    Exit;
  Meta.Id := Task.Id;
  Meta.Name := Task.Name;
  Meta.State := Task.State;
  Meta.Priority := tpNormal;
  Meta.DelayMs := Task.FDelayMs;
  Meta.IntervalMs := Task.FIntervalMs;
  if Task.FUseCron then
    Meta.CronExpr := Task.FCronExpr.ToString
  else
    Meta.CronExpr := '';
  Meta.UseCron := Task.FUseCron;
  Meta.RunCount := Task.FRunCount;
  Meta.MaxRuns := Task.FMaxRuns;
  Meta.CreatedAt := Task.FCreatedAt;
  Meta.NextRunAt := Task.FNextRunAt;
  Meta.LastRunAt := Task.FLastRunAt;
  DepsStr := '';
  for I := 0 to High(Task.FDependsOn) do
  begin
    if I > 0 then DepsStr := DepsStr + ',';
    DepsStr := DepsStr + Task.FDependsOn[I];
  end;
  Meta.DependsOn := DepsStr;
  TagsStr := '';
  for I := 0 to High(Task.FTags) do
  begin
    if I > 0 then TagsStr := TagsStr + ',';
    TagsStr := TagsStr + Task.FTags[I];
  end;
  Meta.Tags := TagsStr;
  FJobStore.SaveTask(Meta);
end;

procedure TTaskScheduler.Start;
begin
  if FRunning then
    Exit;
  
  FRunning := True;
  FTimerThread := TThread.CreateAnonymousThread(TimerProc);
  FTimerThread.FreeOnTerminate := False;
  FTimerThread.Start;
end;

procedure TTaskScheduler.Stop;
var
  WaitCount: Integer;
begin
  if not FRunning then
    Exit;

  FRunning := False;

  // Signal timer thread to stop
  if FShutdownEvent <> nil then
    FShutdownEvent.SetEvent;

  if FTimerThread <> nil then
  begin
    FTimerThread.WaitFor;
    FreeAndNil(FTimerThread);
  end;

  // Wait for running tasks to finish (up to 10 seconds)
  WaitCount := 0;
  while (FRunningCount > 0) and (WaitCount < 100) do
  begin
    Sleep(100);
    Inc(WaitCount);
  end;
end;

procedure TTaskScheduler.TimerProc;
begin
  while FRunning do
  begin
    ProcessPendingTasks;
    Sleep(FCheckIntervalMs);
  end;
end;

function TTaskScheduler.CanRunTask(Task: TScheduledTask): Boolean;
var
  DepId: string;
  DepTask: TScheduledTask;
begin
  Result := False;
  
  // Check state
  if Task.FState <> tsPending then
    Exit;
  
  // Check time
  if Now < Task.FNextRunAt then
    Exit;
  
  // Check max runs
  if (Task.FMaxRuns > 0) and (Task.FRunCount >= Task.FMaxRuns) then
  begin
    Task.FState := tsCompleted;
    Exit;
  end;
  
  // Check concurrent limit
  if FRunningCount >= FMaxConcurrentTasks then
    Exit;
  
  // Check dependencies
  for DepId in Task.FDependsOn do
  begin
    if FTasks.TryGetValue(DepId, DepTask) then
    begin
      if DepTask.FState in [tsIdle, tsPending, tsRunning] then
        Exit;  // Dependency not completed
    end;
  end;
  
  Result := True;
end;

procedure TTaskScheduler.ProcessPendingTasks;
var
  Task: TScheduledTask;
  TasksToRun: TList<TScheduledTask>;
begin
  TasksToRun := TList<TScheduledTask>.Create;
  try
    FLock.Enter;
    try
      // Collect tasks to run (sorted by priority)
      for Task in FTasks.Values do
      begin
        if CanRunTask(Task) then
          TasksToRun.Add(Task);
      end;
      
      // Sort by priority (higher first)
      TasksToRun.Sort(TComparer<TScheduledTask>.Construct(
        function(const L, R: TScheduledTask): Integer
        begin
          Result := Ord(R.FPriority) - Ord(L.FPriority);
        end));
    finally
      FLock.Leave;
    end;
    
    // Execute tasks
    for Task in TasksToRun do
    begin
      if FRunningCount < FMaxConcurrentTasks then
        ExecuteTask(Task);
    end;
  finally
    TasksToRun.Free;
  end;
end;

procedure TTaskScheduler.ExecuteTask(Task: TScheduledTask);
var
  TaskRef: TScheduledTask;
  RunTask: ITask;
begin
  // BUG-041 FIX: Protect concurrent counter updates with lock
  FLock.Enter;
  try
    Task.FState := tsRunning;
    Inc(FRunningCount);
    Inc(FStats.RunningTasks);
    Dec(FStats.PendingTasks);
  finally
    FLock.Leave;
  end;
  
  TaskRef := Task;
  RunTask := TTask.Create(
    procedure
    var
      StartTime: TDateTime;
    begin
      StartTime := Now;
      try
        Task.FProc();
        
        FLock.Enter;
        try
          Task.FLastRunAt := Now;
          Task.FLastDuration := MilliSecondsBetween(Now, StartTime);
          Inc(Task.FRunCount);
          Task.FCurrentRetry := 0;
          Task.FLastError := '';
          Inc(FStats.TotalExecutions);
          
          // Check if should reschedule
          if Task.FUseCron or (Task.FIntervalMs > 0) then
          begin
            if (Task.FMaxRuns = 0) or (Task.FRunCount < Task.FMaxRuns) then
            begin
              Task.CalculateNextRun;
              Task.FState := tsPending;
              Inc(FStats.PendingTasks);
            end
            else
            begin
              Task.FState := tsCompleted;
              Inc(FStats.CompletedTasks);
            end;
          end
          else
          begin
            Task.FState := tsCompleted;
            Inc(FStats.CompletedTasks);
          end;
          
          Dec(FRunningCount);
          Dec(FStats.RunningTasks);
        finally
          FLock.Leave;
        end;
        
        if Assigned(Task.FOnCompleted) then
          Task.FOnCompleted(Task);
          
      except
        on E: Exception do
        begin
          FLock.Enter;
          try
            Task.FLastError := E.Message;
            Inc(Task.FCurrentRetry);
            
            // Check retry
            if Task.FCurrentRetry <= Task.FRetryPolicy.MaxRetries then
            begin
              Task.FNextRunAt := IncMilliSecond(Now,
                Task.FRetryPolicy.GetDelay(Task.FCurrentRetry));
              Task.FState := tsPending;
              Inc(FStats.PendingTasks);
            end
            else
            begin
              Task.FState := tsFailed;
              Inc(FStats.FailedTasks);
              
              if Assigned(Task.FOnFailed) then
                Task.FOnFailed(Task, E);
            end;
            
            Dec(FRunningCount);
            Dec(FStats.RunningTasks);
          finally
            FLock.Leave;
          end;
        end;
      end;
    end);
  RunTask.Start;
end;

function TTaskScheduler.Schedule(const TaskId: string;
  Proc: TTaskProc): TScheduledTask;
begin
  FLock.Enter;
  try
    if FTasks.ContainsKey(TaskId) then
      raise EInvalidOperationException.CreateFmt('Task "%s" already exists', [TaskId]);
    
    Result := TScheduledTask.Create(Self, TaskId);
    Result.FProc := Proc;
    FTasks.Add(TaskId, Result);
    Inc(FStats.TotalTasks);
    Inc(FStats.PendingTasks);
  finally
    FLock.Leave;
  end;
end;

function TTaskScheduler.GetTask(const TaskId: string): TScheduledTask;
begin
  FLock.Enter;
  try
    if not FTasks.TryGetValue(TaskId, Result) then
      Result := nil;
  finally
    FLock.Leave;
  end;
end;

function TTaskScheduler.HasTask(const TaskId: string): Boolean;
begin
  FLock.Enter;
  try
    Result := FTasks.ContainsKey(TaskId);
  finally
    FLock.Leave;
  end;
end;

function TTaskScheduler.CancelTask(const TaskId: string): Boolean;
var
  Task: TScheduledTask;
begin
  FLock.Enter;
  try
    if FTasks.TryGetValue(TaskId, Task) then
    begin
      if Task.FState in [tsIdle, tsPending] then
      begin
        Task.FState := tsCancelled;
        Dec(FStats.PendingTasks);
        Result := True;
      end
      else
        Result := False;
    end
    else
      Result := False;
  finally
    FLock.Leave;
  end;
end;

procedure TTaskScheduler.CancelByTag(const Tag: string);
var
  Task: TScheduledTask;
  T: string;
begin
  FLock.Enter;
  try
    for Task in FTasks.Values do
    begin
      for T in Task.FTags do
      begin
        if T = Tag then
        begin
          if Task.FState in [tsIdle, tsPending] then
          begin
            Task.FState := tsCancelled;
            Dec(FStats.PendingTasks);
          end;
          Break;
        end;
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TTaskScheduler.Cleanup;
var
  ToRemove: TList<string>;
  Task: TScheduledTask;
  Id: string;
begin
  ToRemove := TList<string>.Create;
  try
    FLock.Enter;
    try
      for Task in FTasks.Values do
        if Task.FState in [tsCompleted, tsFailed, tsCancelled] then
          ToRemove.Add(Task.FId);
      
      for Id in ToRemove do
        FTasks.Remove(Id);
    finally
      FLock.Leave;
    end;
  finally
    ToRemove.Free;
  end;
end;

function TTaskScheduler.GetTaskIds: TArray<string>;
begin
  FLock.Enter;
  try
    Result := FTasks.Keys.ToArray;
  finally
    FLock.Leave;
  end;
end;

function TTaskScheduler.GetTasksByState(State: TTaskState): TArray<TScheduledTask>;
var
  List: TList<TScheduledTask>;
  Task: TScheduledTask;
begin
  List := TList<TScheduledTask>.Create;
  try
    FLock.Enter;
    try
      for Task in FTasks.Values do
        if Task.FState = State then
          List.Add(Task);
    finally
      FLock.Leave;
    end;
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

function TTaskScheduler.GetTasksByTag(const Tag: string): TArray<TScheduledTask>;
var
  List: TList<TScheduledTask>;
  Task: TScheduledTask;
  T: string;
begin
  List := TList<TScheduledTask>.Create;
  try
    FLock.Enter;
    try
      for Task in FTasks.Values do
      begin
        for T in Task.FTags do
        begin
          if T = Tag then
          begin
            List.Add(Task);
            Break;
          end;
        end;
      end;
    finally
      FLock.Leave;
    end;
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

// ============================================================================
// Initialization
// ============================================================================

initialization
  GSchedulerLock := TCriticalSection.Create;

finalization
  if GScheduler <> nil then
  begin
    GScheduler.Stop;
    GScheduler.Free;
  end;
  GSchedulerLock.Free;

end.
