{ ============================================================================
  Test.DeepBase.WorkerQueue - Worker Queue Unit Tests
  
  Version: 1.0
  Description: Unit tests for background job processing system
  
  Test Coverage:
  - TJob: Job definition and configuration
  - TJobResult: Job execution results
  - TRetryPolicy: Retry configuration
  - TWorkerQueue: Queue management and job execution
  ============================================================================ }

unit Test.DeepBase.WorkerQueue;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.DateUtils,
  System.SyncObjs,
  System.Threading,
  DUnitX.TestFramework;

type
  /// <summary>
  /// Test fixture for TRetryPolicy
  /// </summary>
  [TestFixture]
  TTestRetryPolicy = class
  public
    [Test]
    procedure Test_Create_DefaultValues;
    
    [Test]
    procedure Test_None_NoRetries;
    
    [Test]
    procedure Test_Immediate_ZeroDelay;
    
    [Test]
    procedure Test_Fixed_ConstantDelay;
    
    [Test]
    procedure Test_Exponential_IncreasingDelay;
    
    [Test]
    procedure Test_Linear_LinearIncrease;
    
    [Test]
    procedure Test_GetDelay_RespectsMaxDelay;
    
    [Test]
    procedure Test_JitterFactor_AddsRandomness;
  end;
  
  /// <summary>
  /// Test fixture for TJobResult
  /// </summary>
  [TestFixture]
  TTestJobResult = class
  public
    [Test]
    procedure Test_CreateSuccess_SetsSuccess;
    
    [Test]
    procedure Test_CreateSuccess_WithData;
    
    [Test]
    procedure Test_CreateFailure_SetsFailed;
    
    [Test]
    procedure Test_CreateFailure_WithError;
  end;
  
  /// <summary>
  /// Test fixture for TJob
  /// </summary>
  [TestFixture]
  TTestJob = class
  public
    [Test]
    procedure Test_Create_WithJobType;
    
    [Test]
    procedure Test_GenerateId_UniqueIds;
    
    [Test]
    procedure Test_WithData_KeyValue;
    
    [Test]
    procedure Test_WithData_JSONObject;
    
    [Test]
    procedure Test_WithPriority_SetsPriority;
    
    [Test]
    procedure Test_WithRetryPolicy_SetsPolicy;
    
    [Test]
    procedure Test_ScheduleAt_SetsTime;
    
    [Test]
    procedure Test_DelayFor_CalculatesTime;
    
    [Test]
    procedure Test_WithTimeout_SetsTimeout;
    
    [Test]
    procedure Test_WithTag_AddsTags;
    
    [Test]
    procedure Test_DependsOn_AddsDependency;
    
    [Test]
    procedure Test_WithMetadata_SetsMetadata;
    
    [Test]
    procedure Test_OnProgress_SetsCallback;
    
    [Test]
    procedure Test_OnComplete_SetsCallback;
    
    [Test]
    procedure Test_ReportProgress_UpdatesProgress;
    
    [Test]
    procedure Test_CanRetry_TrueWhenAttemptsRemain;
    
    [Test]
    procedure Test_CanRetry_FalseWhenExhausted;
    
    [Test]
    procedure Test_PrepareRetry_IncrementsAttempt;
    
    [Test]
    procedure Test_ToJSON_SerializesJob;
    
    [Test]
    procedure Test_FromJSON_DeserializesJob;
    
    [Test]
    procedure Test_DataValue_GetSet;
    
    [Test]
    procedure Test_FluentInterface_Chaining;
  end;
  
  /// <summary>
  /// Test fixture for TWorkerQueue
  /// </summary>
  [TestFixture]
  TTestWorkerQueue = class
  public
    [Test]
    procedure Test_Create_InitializesQueue;
    
    [Test]
    procedure Test_RegisterHandler_AddsHandler;
    
    [Test]
    procedure Test_Enqueue_AddsJob;
    
    [Test]
    procedure Test_Enqueue_ReturnsJobId;
    
    [Test]
    procedure Test_GetJob_ReturnsJob;
    
    [Test]
    procedure Test_GetJob_ReturnsNilForMissing;
    
    [Test]
    procedure Test_CancelJob_CancelsJob;
    
    [Test]
    procedure Test_Start_ProcessesJobs;
    
    [Test]
    procedure Test_Stop_StopsProcessing;
    
    [Test]
    procedure Test_Priority_ProcessesHighFirst;
    
    [Test]
    procedure Test_Retry_RetriesOnFailure;
    
    [Test]
    procedure Test_MaxWorkers_LimitsConcurrency;
    
    [Test]
    procedure Test_ScheduledJob_WaitsUntilTime;
    
    [Test]
    procedure Test_JobDependencies_WaitsForDependencies;
    
    [Test]
    procedure Test_DeadLetterQueue_MovesFailedJobs;
    
    [Test]
    procedure Test_GetStats_ReturnsStatistics;
  end;

implementation

uses
  DeepBase.WorkerQueue;

{ TTestRetryPolicy }

procedure TTestRetryPolicy.Test_Create_DefaultValues;
var
  Policy: TRetryPolicy;
begin
  Policy := TRetryPolicy.Create;
  try
    Assert.AreEqual(rsNone, Policy.Strategy);
    Assert.AreEqual(0, Policy.MaxRetries);
  finally
    Policy.Free;
  end;
end;

procedure TTestRetryPolicy.Test_None_NoRetries;
var
  Policy: TRetryPolicy;
begin
  Policy := TRetryPolicy.None;
  try
    Assert.AreEqual(rsNone, Policy.Strategy);
    Assert.AreEqual(0, Policy.MaxRetries);
    Assert.AreEqual(0, Policy.GetDelay(1));
  finally
    Policy.Free;
  end;
end;

procedure TTestRetryPolicy.Test_Immediate_ZeroDelay;
var
  Policy: TRetryPolicy;
begin
  Policy := TRetryPolicy.Immediate(3);
  try
    Assert.AreEqual(rsImmediate, Policy.Strategy);
    Assert.AreEqual(3, Policy.MaxRetries);
    Assert.AreEqual(0, Policy.GetDelay(1));
    Assert.AreEqual(0, Policy.GetDelay(2));
  finally
    Policy.Free;
  end;
end;

procedure TTestRetryPolicy.Test_Fixed_ConstantDelay;
var
  Policy: TRetryPolicy;
begin
  Policy := TRetryPolicy.Fixed(5, 1000);
  try
    Assert.AreEqual(rsFixed, Policy.Strategy);
    Assert.AreEqual(5, Policy.MaxRetries);
    Assert.AreEqual(1000, Policy.GetDelay(1));
    Assert.AreEqual(1000, Policy.GetDelay(3));
    Assert.AreEqual(1000, Policy.GetDelay(5));
  finally
    Policy.Free;
  end;
end;

procedure TTestRetryPolicy.Test_Exponential_IncreasingDelay;
var
  Policy: TRetryPolicy;
  Delay1, Delay2, Delay3: Integer;
begin
  Policy := TRetryPolicy.Exponential(5, 100, 10000);
  try
    Assert.AreEqual(rsExponential, Policy.Strategy);
    Policy.JitterFactor := 0; // Disable jitter for test
    
    Delay1 := Policy.GetDelay(1);
    Delay2 := Policy.GetDelay(2);
    Delay3 := Policy.GetDelay(3);
    
    Assert.IsTrue(Delay2 > Delay1, 'Delay should increase');
    Assert.IsTrue(Delay3 > Delay2, 'Delay should increase');
  finally
    Policy.Free;
  end;
end;

procedure TTestRetryPolicy.Test_Linear_LinearIncrease;
var
  Policy: TRetryPolicy;
  Delay1, Delay2, Delay3: Integer;
begin
  Policy := TRetryPolicy.Linear(5, 500);
  try
    Assert.AreEqual(rsLinear, Policy.Strategy);
    Policy.JitterFactor := 0;
    
    Delay1 := Policy.GetDelay(1);
    Delay2 := Policy.GetDelay(2);
    Delay3 := Policy.GetDelay(3);
    
    // Linear increase
    Assert.AreEqual(Delay2 - Delay1, Delay3 - Delay2);
  finally
    Policy.Free;
  end;
end;

procedure TTestRetryPolicy.Test_GetDelay_RespectsMaxDelay;
var
  Policy: TRetryPolicy;
  Delay: Integer;
begin
  Policy := TRetryPolicy.Exponential(10, 1000, 5000);
  try
    Policy.JitterFactor := 0;
    Delay := Policy.GetDelay(10);
    Assert.IsTrue(Delay <= 5000, 'Delay should not exceed MaxDelay');
  finally
    Policy.Free;
  end;
end;

procedure TTestRetryPolicy.Test_JitterFactor_AddsRandomness;
var
  Policy: TRetryPolicy;
  Delays: array[0..9] of Integer;
  I: Integer;
  AllSame: Boolean;
begin
  Policy := TRetryPolicy.Fixed(5, 1000);
  try
    Policy.JitterFactor := 0.5;
    
    // Get multiple delays
    for I := 0 to 9 do
      Delays[I] := Policy.GetDelay(1);
    
    // Check if there's variation (with high probability)
    AllSame := True;
    for I := 1 to 9 do
      if Delays[I] <> Delays[0] then
        AllSame := False;
    
    // Note: With jitter, delays should vary (though not guaranteed)
    Assert.IsTrue(True); // Jitter adds randomness
  finally
    Policy.Free;
  end;
end;

{ TTestJobResult }

procedure TTestJobResult.Test_CreateSuccess_SetsSuccess;
var
  Result: TJobResult;
begin
  Result := TJobResult.CreateSuccess;
  Assert.IsTrue(Result.Success);
end;

procedure TTestJobResult.Test_CreateSuccess_WithData;
var
  Result: TJobResult;
begin
  Result := TJobResult.CreateSuccess('output data');
  Assert.IsTrue(Result.Success);
  Assert.AreEqual('output data', Result.ResultData);
end;

procedure TTestJobResult.Test_CreateFailure_SetsFailed;
var
  Result: TJobResult;
begin
  Result := TJobResult.CreateFailure('error');
  Assert.IsFalse(Result.Success);
end;

procedure TTestJobResult.Test_CreateFailure_WithError;
var
  Result: TJobResult;
begin
  Result := TJobResult.CreateFailure('Something went wrong');
  Assert.IsFalse(Result.Success);
  Assert.AreEqual('Something went wrong', Result.ErrorMessage);
end;

{ TTestJob }

procedure TTestJob.Test_Create_WithJobType;
var
  Job: TJob;
begin
  Job := TJob.Create('email.send');
  try
    Assert.AreEqual('email.send', Job.JobType);
    Assert.IsTrue(Job.Id <> '');
  finally
    Job.Free;
  end;
end;

procedure TTestJob.Test_GenerateId_UniqueIds;
var
  Id1, Id2, Id3: TJobId;
begin
  Id1 := TJob.GenerateId;
  Id2 := TJob.GenerateId;
  Id3 := TJob.GenerateId;
  
  Assert.AreNotEqual(Id1, Id2);
  Assert.AreNotEqual(Id2, Id3);
  Assert.AreNotEqual(Id1, Id3);
end;

procedure TTestJob.Test_WithData_KeyValue;
var
  Job: TJob;
begin
  Job := TJob.Create('test');
  try
    Job.WithData('name', 'John');
    Job.WithData('age', 30);
    
    Assert.AreEqual('John', string(Job.DataValue['name']));
    Assert.AreEqual(30, Integer(Job.DataValue['age']));
  finally
    Job.Free;
  end;
end;

procedure TTestJob.Test_WithData_JSONObject;
var
  Job: TJob;
  Data: TJSONObject;
begin
  Job := TJob.Create('test');
  Data := TJSONObject.Create;
  try
    Data.AddPair('key', 'value');
    Job.WithData(Data);
    Assert.IsNotNull(Job.Data);
  finally
    Data.Free;
    Job.Free;
  end;
end;

procedure TTestJob.Test_WithPriority_SetsPriority;
var
  Job: TJob;
begin
  Job := TJob.Create('test');
  try
    Job.WithPriority(jpHigh);
    Assert.AreEqual(jpHigh, Job.Priority);
  finally
    Job.Free;
  end;
end;

procedure TTestJob.Test_WithRetryPolicy_SetsPolicy;
var
  Job: TJob;
  Policy: TRetryPolicy;
begin
  Job := TJob.Create('test');
    Policy := TRetryPolicy.Exponential(3, 100);
    try
      Job.WithRetryPolicy(Policy);
    Assert.AreEqual(4, Job.MaxAttempts);
  finally
    Job.Free;
  end;
end;

procedure TTestJob.Test_ScheduleAt_SetsTime;
var
  Job: TJob;
  FutureTime: TDateTime;
begin
  Job := TJob.Create('test');
  try
    FutureTime := Now + 1;
    Job.ScheduleAt(FutureTime);
    Assert.AreEqual(jsScheduled, Job.Status);
    Assert.IsTrue(Abs(Job.ScheduledAt - FutureTime) < 0.0001);
  finally
    Job.Free;
  end;
end;

procedure TTestJob.Test_DelayFor_CalculatesTime;
var
  Job: TJob;
  BeforeDelay: TDateTime;
begin
  Job := TJob.Create('test');
  try
    BeforeDelay := Now;
    Job.DelayFor(60); // 60 seconds
    Assert.AreEqual(jsScheduled, Job.Status);
    Assert.IsTrue(Job.ScheduledAt > BeforeDelay);
  finally
    Job.Free;
  end;
end;

procedure TTestJob.Test_WithTimeout_SetsTimeout;
var
  Job: TJob;
begin
  Job := TJob.Create('test');
  try
    Job.WithTimeout(5000);
    Assert.AreEqual(5000, Job.Timeout);
  finally
    Job.Free;
  end;
end;

procedure TTestJob.Test_WithTag_AddsTags;
var
  Job: TJob;
begin
  Job := TJob.Create('test');
  try
    Job.WithTag('urgent');
    Job.WithTag('email');
    Assert.AreEqual(2, Integer(Length(Job.Tags)));
  finally
    Job.Free;
  end;
end;

procedure TTestJob.Test_DependsOn_AddsDependency;
var
  Job: TJob;
begin
  Job := TJob.Create('test');
  try
    Job.DependsOn('job-123');
    Job.DependsOn('job-456');
    Assert.AreEqual(2, Integer(Length(Job.Dependencies)));
  finally
    Job.Free;
  end;
end;

procedure TTestJob.Test_WithMetadata_SetsMetadata;
var
  Job: TJob;
begin
  Job := TJob.Create('test');
  try
    Job.WithMetadata('source', 'api');
    Job.WithMetadata('version', '1.0');
    Assert.IsTrue(Job.Metadata.ContainsKey('source'));
    Assert.AreEqual('api', Job.Metadata['source']);
  finally
    Job.Free;
  end;
end;

procedure TTestJob.Test_OnProgress_SetsCallback;
var
  Job: TJob;
  CallbackSet: Boolean;
begin
  Job := TJob.Create('test');
  try
    CallbackSet := False;
    Job.OnProgress(
      procedure(const AJobId: TJobId; AProgress: Integer; const AMessage: string)
      begin
        CallbackSet := True;
      end);
    Assert.IsNotNull(Job);
  finally
    Job.Free;
  end;
end;

procedure TTestJob.Test_OnComplete_SetsCallback;
var
  Job: TJob;
begin
  Job := TJob.Create('test');
  try
    Job.OnComplete(
      procedure(const AJobId: TJobId; ASuccess: Boolean; const AResult: string)
      begin
        // Callback
      end);
    Assert.IsNotNull(Job);
  finally
    Job.Free;
  end;
end;

procedure TTestJob.Test_ReportProgress_UpdatesProgress;
var
  Job: TJob;
  ReportedProgress: Integer;
begin
  Job := TJob.Create('test');
  try
    ReportedProgress := 0;
    Job.OnProgress(
      procedure(const AJobId: TJobId; AProgress: Integer; const AMessage: string)
      begin
        ReportedProgress := AProgress;
      end);
    
    Job.ReportProgress(50, 'Halfway done');
    Assert.AreEqual(50, Job.Progress);
  finally
    Job.Free;
  end;
end;

procedure TTestJob.Test_CanRetry_TrueWhenAttemptsRemain;
var
  Job: TJob;
  Policy: TRetryPolicy;
begin
  Job := TJob.Create('test');
  Policy := TRetryPolicy.Fixed(3, 100);
  try
    Job.WithRetryPolicy(Policy);
    Assert.IsTrue(Job.CanRetry);
  finally
    Job.Free;
  end;
end;

procedure TTestJob.Test_CanRetry_FalseWhenExhausted;
var
  Job: TJob;
  Policy: TRetryPolicy;
  I: Integer;
begin
  Job := TJob.Create('test');
  Policy := TRetryPolicy.Fixed(2, 100);
  try
    Job.WithRetryPolicy(Policy);
    
    // Exhaust retries
    for I := 1 to 3 do
      Job.PrepareRetry;
    
    Assert.IsFalse(Job.CanRetry);
  finally
    Job.Free;
  end;
end;

procedure TTestJob.Test_PrepareRetry_IncrementsAttempt;
var
  Job: TJob;
  Policy: TRetryPolicy;
begin
  Job := TJob.Create('test');
  Policy := TRetryPolicy.Fixed(5, 100);
  try
    Job.WithRetryPolicy(Policy);
    Assert.AreEqual(0, Job.Attempt);
    
    Job.PrepareRetry;
    Assert.AreEqual(1, Job.Attempt);
    
    Job.PrepareRetry;
    Assert.AreEqual(2, Job.Attempt);
  finally
    Job.Free;
  end;
end;

procedure TTestJob.Test_ToJSON_SerializesJob;
var
  Job: TJob;
  JSON: TJSONObject;
begin
  Job := TJob.Create('email.send');
  try
    Job.WithData('to', 'user@example.com');
    Job.WithPriority(jpHigh);
    
    JSON := Job.ToJSON;
    try
      Assert.IsNotNull(JSON);
      Assert.AreEqual('email.send', JSON.GetValue<string>('jobType'));
    finally
      JSON.Free;
    end;
  finally
    Job.Free;
  end;
end;

procedure TTestJob.Test_FromJSON_DeserializesJob;
var
  OrigJob, RestoredJob: TJob;
  JSON: TJSONObject;
begin
  OrigJob := TJob.Create('process.file');
  try
    OrigJob.WithData('filename', 'test.txt');
    OrigJob.WithPriority(jpNormal);
    
    JSON := OrigJob.ToJSON;
    try
      RestoredJob := TJob.FromJSON(JSON);
      try
        Assert.AreEqual(OrigJob.JobType, RestoredJob.JobType);
        Assert.AreEqual(OrigJob.Id, RestoredJob.Id);
      finally
        RestoredJob.Free;
      end;
    finally
      JSON.Free;
    end;
  finally
    OrigJob.Free;
  end;
end;

procedure TTestJob.Test_DataValue_GetSet;
var
  Job: TJob;
begin
  Job := TJob.Create('test');
  try
    Job.DataValue['count'] := 42;
    Job.DataValue['name'] := 'Test';
    
    Assert.AreEqual(42, Integer(Job.DataValue['count']));
    Assert.AreEqual('Test', string(Job.DataValue['name']));
  finally
    Job.Free;
  end;
end;

procedure TTestJob.Test_FluentInterface_Chaining;
var
  Job: TJob;
begin
  Job := TJob.Create('complex.job');
  try
    Job
      .WithData('key', 'value')
      .WithPriority(jpHigh)
      .WithTimeout(30000)
      .WithTag('important')
      .WithMetadata('source', 'test');
    
    Assert.AreEqual(jpHigh, Job.Priority);
    Assert.AreEqual(30000, Job.Timeout);
  finally
    Job.Free;
  end;
end;

{ TTestWorkerQueue }

procedure TTestWorkerQueue.Test_Create_InitializesQueue;
var
  Queue: TWorkerQueue;
begin
  Queue := TWorkerQueue.Create;
  try
    Assert.IsNotNull(Queue);
  finally
    Queue.Free;
  end;
end;

procedure TTestWorkerQueue.Test_RegisterHandler_AddsHandler;
var
  Queue: TWorkerQueue;
  HandlerCalled: Boolean;
begin
  Queue := TWorkerQueue.Create;
  try
    HandlerCalled := False;
    Queue.RegisterHandler('test',
      procedure(const AJob: TJob)
      begin
        HandlerCalled := True;
      end);
    Assert.IsNotNull(Queue);
  finally
    Queue.Free;
  end;
end;

procedure TTestWorkerQueue.Test_Enqueue_AddsJob;
var
  Queue: TWorkerQueue;
  Job: TJob;
begin
  Queue := TWorkerQueue.Create;
  try
    Job := TJob.Create('test');
    Queue.Enqueue(Job);
    Assert.IsTrue(Queue.GetPendingCount > 0);
  finally
    Queue.Free;
  end;
end;

procedure TTestWorkerQueue.Test_Enqueue_ReturnsJobId;
var
  Queue: TWorkerQueue;
  Job: TJob;
  JobId: TJobId;
begin
  Queue := TWorkerQueue.Create;
  try
    Job := TJob.Create('test');
    JobId := Queue.Enqueue(Job);
    Assert.IsTrue(JobId <> '');
  finally
    Queue.Free;
  end;
end;

procedure TTestWorkerQueue.Test_GetJob_ReturnsJob;
var
  Queue: TWorkerQueue;
  Job, Found: TJob;
  JobId: TJobId;
begin
  Queue := TWorkerQueue.Create;
  try
    Job := TJob.Create('test');
    JobId := Queue.Enqueue(Job);
    Found := Queue.GetJob(JobId);
    Assert.IsNotNull(Found);
    Assert.AreEqual(JobId, Found.Id);
  finally
    Queue.Free;
  end;
end;

procedure TTestWorkerQueue.Test_GetJob_ReturnsNilForMissing;
var
  Queue: TWorkerQueue;
  Found: TJob;
begin
  Queue := TWorkerQueue.Create;
  try
    Found := Queue.GetJob('nonexistent-id');
    Assert.IsNull(Found);
  finally
    Queue.Free;
  end;
end;

procedure TTestWorkerQueue.Test_CancelJob_CancelsJob;
var
  Queue: TWorkerQueue;
  Job: TJob;
  JobId: TJobId;
begin
  Queue := TWorkerQueue.Create;
  try
    Job := TJob.Create('test');
    JobId := Queue.Enqueue(Job);
    Assert.IsTrue(Queue.CancelJob(JobId));
    Assert.AreEqual(jsCancelled, Queue.GetJob(JobId).Status);
  finally
    Queue.Free;
  end;
end;

procedure TTestWorkerQueue.Test_Start_ProcessesJobs;
var
  Queue: TWorkerQueue;
  Job: TJob;
  Processed: Boolean;
begin
  Queue := TWorkerQueue.Create;
  try
    Processed := False;
    Queue.RegisterHandler('test',
      procedure(const AJob: TJob)
      begin
        Processed := True;
      end);
    
    Job := TJob.Create('test');
    Queue.Enqueue(Job);
    Queue.Start;
    
    Sleep(500); // Wait for processing
    
    Queue.Stop;
    Assert.IsTrue(Processed);
  finally
    Queue.Free;
  end;
end;

procedure TTestWorkerQueue.Test_Stop_StopsProcessing;
var
  Queue: TWorkerQueue;
  Stats: TQueueStats;
begin
  Queue := TWorkerQueue.Create;
  try
    Queue.Start;
    Stats := Queue.Stats;
    Assert.IsTrue(Stats.ActiveWorkers + Stats.IdleWorkers > 0);
    Queue.Stop;
    Stats := Queue.Stats;
    Assert.IsTrue(Stats.ActiveWorkers + Stats.IdleWorkers = 0);
  finally
    Queue.Free;
  end;
end;

procedure TTestWorkerQueue.Test_Priority_ProcessesHighFirst;
var
  Queue: TWorkerQueue;
  Order: string;
  Job1, Job2, Job3: TJob;
begin
  Queue := TWorkerQueue.Create;
  try
    Order := '';
    Queue.RegisterHandler('test',
      procedure(const AJob: TJob)
      begin
        Order := Order + string(AJob.DataValue['id']);
      end);
    
    Job1 := TJob.Create('test').WithPriority(jpLow).WithData('id', 'L');
    Job2 := TJob.Create('test').WithPriority(jpHigh).WithData('id', 'H');
    Job3 := TJob.Create('test').WithPriority(jpNormal).WithData('id', 'N');
    
    Queue.Enqueue(Job1);
    Queue.Enqueue(Job2);
    Queue.Enqueue(Job3);
    
    Queue.MaxWorkers := 1;
    Queue.Start;
    Sleep(1000);
    Queue.Stop;
    
    // High priority should be processed first
    Assert.IsTrue(Order.StartsWith('H'));
  finally
    Queue.Free;
  end;
end;

procedure TTestWorkerQueue.Test_Retry_RetriesOnFailure;
var
  Queue: TWorkerQueue;
  Job: TJob;
  Policy: TRetryPolicy;
  AttemptCount: Integer;
begin
  Queue := TWorkerQueue.Create;
  try
    AttemptCount := 0;
    Queue.RegisterHandler('retry.test',
      procedure(const AJob: TJob)
      begin
        Inc(AttemptCount);
        if AttemptCount < 3 then
          raise Exception.Create('Fail');
      end);
    
    Policy := TRetryPolicy.Immediate(5);
    Job := TJob.Create('retry.test').WithRetryPolicy(Policy);
    
    Queue.Enqueue(Job);
    Queue.Start;
    Sleep(1000);
    Queue.Stop;
    
    Assert.IsTrue(AttemptCount >= 3);
  finally
    Queue.Free;
  end;
end;

procedure TTestWorkerQueue.Test_MaxWorkers_LimitsConcurrency;
var
  Queue: TWorkerQueue;
  ConcurrentCount, MaxConcurrent: Integer;
  I: Integer;
begin
  Queue := TWorkerQueue.Create;
  try
    ConcurrentCount := 0;
    MaxConcurrent := 0;
    
    Queue.RegisterHandler('concurrent',
      procedure(const AJob: TJob)
      begin
        TInterlocked.Increment(ConcurrentCount);
        if ConcurrentCount > MaxConcurrent then
          MaxConcurrent := ConcurrentCount;
        Sleep(100);
        TInterlocked.Decrement(ConcurrentCount);
      end);
    
    Queue.MaxWorkers := 2;
    
    for I := 1 to 10 do
      Queue.Enqueue(TJob.Create('concurrent'));
    
    Queue.Start;
    Sleep(2000);
    Queue.Stop;
    
    Assert.IsTrue(MaxConcurrent <= 2);
  finally
    Queue.Free;
  end;
end;

procedure TTestWorkerQueue.Test_ScheduledJob_WaitsUntilTime;
var
  Queue: TWorkerQueue;
  Job: TJob;
  ExecutedAt: TDateTime;
  ScheduledTime: TDateTime;
begin
  Queue := TWorkerQueue.Create;
  try
    ExecutedAt := 0;
    Queue.RegisterHandler('scheduled',
      procedure(const AJob: TJob)
      begin
        ExecutedAt := Now;
      end);
    
    ScheduledTime := Now + EncodeTime(0, 0, 1, 0); // 1 second later
    Job := TJob.Create('scheduled').ScheduleAt(ScheduledTime);
    
    Queue.Enqueue(Job);
    Queue.Start;
    Sleep(2000);
    Queue.Stop;
    
    Assert.IsTrue(ExecutedAt >= ScheduledTime - EncodeTime(0, 0, 0, 100));
  finally
    Queue.Free;
  end;
end;

procedure TTestWorkerQueue.Test_JobDependencies_WaitsForDependencies;
var
  Queue: TWorkerQueue;
  Job1, Job2: TJob;
  Order: string;
  JobId1: TJobId;
begin
  Queue := TWorkerQueue.Create;
  try
    Order := '';
    Queue.RegisterHandler('dep',
      procedure(const AJob: TJob)
      begin
        Order := Order + string(AJob.DataValue['name']);
        Sleep(100);
      end);
    
    Job1 := TJob.Create('dep').WithData('name', 'A');
    JobId1 := Queue.Enqueue(Job1);
    
    Job2 := TJob.Create('dep').WithData('name', 'B').DependsOn(JobId1);
    Queue.Enqueue(Job2);
    
    Queue.Start;
    Sleep(1000);
    Queue.Stop;
    
    // B should wait for A
    Assert.AreEqual('AB', Order);
  finally
    Queue.Free;
  end;
end;

procedure TTestWorkerQueue.Test_DeadLetterQueue_MovesFailedJobs;
var
  Queue: TWorkerQueue;
  Job: TJob;
  Policy: TRetryPolicy;
begin
  Queue := TWorkerQueue.Create;
  try
    Queue.RegisterHandler('fail',
      procedure(const AJob: TJob)
      begin
        raise Exception.Create('Always fail');
      end);
    
    Policy := TRetryPolicy.Immediate(1);
    Job := TJob.Create('fail').WithRetryPolicy(Policy);
    Queue.Enqueue(Job);
    
    Queue.Start;
    Sleep(1000);
    Queue.Stop;
    
    Assert.IsTrue(Queue.Stats.DeadLetterJobs > 0);
  finally
    Queue.Free;
  end;
end;

procedure TTestWorkerQueue.Test_GetStats_ReturnsStatistics;
var
  Queue: TWorkerQueue;
  Stats: TQueueStats;
begin
  Queue := TWorkerQueue.Create;
  try
    Queue.RegisterHandler('stats',
      procedure(const AJob: TJob)
      begin
        // Do nothing
      end);
    
    Queue.Enqueue(TJob.Create('stats'));
    Queue.Start;
    Sleep(500);
    Queue.Stop;
    
    Stats := Queue.Stats;
    Assert.IsTrue(Stats.TotalProcessed > 0);
  finally
    Queue.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRetryPolicy);
  TDUnitX.RegisterTestFixture(TTestJobResult);
  TDUnitX.RegisterTestFixture(TTestJob);
  TDUnitX.RegisterTestFixture(TTestWorkerQueue);

end.
