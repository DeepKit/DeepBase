{ ============================================================================
  Test.Regression.BUG324_WorkerQueueCallbackSafety - REVIEW5-CORE-002

  Verifies that external callbacks (OnJobStarted, OnJobCompleted, OnError,
  OnJobFailed, OnJobRetrying, FOnCompletion) and storage (SaveJob) raising
  exceptions do NOT leave a job stuck in jsRunning.

  Bug: Prior to fix, any callback exception would either:
  (a) Prevent the job from transitioning out of jsRunning (if thrown before
      the handler try/except), or
  (b) Be caught by the handler try/except, causing a successful job to be
      treated as failed and possibly retried.
  ============================================================================ }

unit Test.Regression.BUG324_WorkerQueueCallbackSafety;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.SyncObjs,
  DUnitX.TestFramework,
  Test.Regression.Base,
  DeepBase.WorkerQueue;

type
  /// <summary>Helper class providing method-pointer callbacks that raise.</summary>
  TCallbackRaiser = class
  public
    procedure RaiseOnStarted(Sender: TObject; const AJob: TJob);
    procedure RaiseOnCompleted(Sender: TObject; const AJob: TJob);
    procedure RaiseOnFailed(Sender: TObject; const AJob: TJob);
    procedure RaiseOnRetrying(Sender: TObject; const AJob: TJob);
    procedure RaiseOnError(Sender: TObject; const AJob: TJob; const AError: Exception);
    procedure RaiseOnProgress(const AJobId: TJobId; AProgress: Integer; const AMessage: string);
  end;

  [TestFixture]
  [Category('regression')]
  TBUG324_WorkerQueueCallbackSafetyTest = class(TRegressionTestBase)
  private
    FQueue: TWorkerQueue;
    FRaiser: TCallbackRaiser;
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

    [Test]
    procedure Test_OnJobStarted_Exception_JobStillCompletes;
    [Test]
    procedure Test_OnJobCompleted_Exception_JobStaysCompleted;
    [Test]
    procedure Test_OnCompletion_Exception_JobStaysCompleted;
    [Test]
    procedure Test_SaveJob_PreExec_Exception_JobStillCompletes;
    [Test]
    procedure Test_OnError_Exception_RetryPathStillExecutes;
    [Test]
    procedure Test_OnJobFailed_Exception_JobStillFails;
    [Test]
    procedure Test_OnJobRetrying_Exception_RetryStillHappens;
    [Test]
    procedure Test_ReportProgress_Exception_HandlerNotFailed;
    [Test]
    procedure Test_AllCallbacksThrow_JobStateCorrect;
    /// <summary>BUG-438: handler 抛异常 + Timeout>0 走 handler-thread 分支 +
    /// retry。修复前 FError := E 跨 except 块悬挂, raise LHandlerErr 触发
    /// AV 216 (Runtime error 216 @0x593A)。修复后克隆异常对象, FOnCompletion
    /// 收到的 AResult 应含原异常 Message (验证克隆保留 Message 且不崩)。</summary>
    [Test]
    procedure Test_BUG438_HandlerException_MessagePropagatedToCompletion;
  end;

implementation

uses
  System.Threading;

type
  /// <summary>Storage that raises on SaveJob</summary>
  TRaisingStorage = class(TInterfacedObject, IJobStorage)
  private
    FRaiseOnSave: Boolean;
  public
    constructor Create(ARaiseOnSave: Boolean);
    procedure SaveJob(const AJob: TJob);
    procedure DeleteJob(const AJobId: TJobId);
    function LoadJob(const AJobId: TJobId): TJob;
    function LoadPendingJobs: TObjectList<TJob>;
    function LoadJobsByStatus(AStatus: TJobStatus): TObjectList<TJob>;
    procedure Clear;
  end;

{ TCallbackRaiser }

procedure TCallbackRaiser.RaiseOnStarted(Sender: TObject; const AJob: TJob);
begin
  raise Exception.Create('OnJobStarted simulated failure');
end;

procedure TCallbackRaiser.RaiseOnCompleted(Sender: TObject; const AJob: TJob);
begin
  raise Exception.Create('OnJobCompleted simulated failure');
end;

procedure TCallbackRaiser.RaiseOnFailed(Sender: TObject; const AJob: TJob);
begin
  raise Exception.Create('OnJobFailed simulated failure');
end;

procedure TCallbackRaiser.RaiseOnRetrying(Sender: TObject; const AJob: TJob);
begin
  raise Exception.Create('OnJobRetrying simulated failure');
end;

procedure TCallbackRaiser.RaiseOnError(Sender: TObject; const AJob: TJob; const AError: Exception);
begin
  raise Exception.Create('OnError simulated failure');
end;

procedure TCallbackRaiser.RaiseOnProgress(const AJobId: TJobId; AProgress: Integer; const AMessage: string);
begin
  raise Exception.Create('Progress callback simulated failure');
end;

{ TRaisingStorage }

constructor TRaisingStorage.Create(ARaiseOnSave: Boolean);
begin
  inherited Create;
  FRaiseOnSave := ARaiseOnSave;
end;

procedure TRaisingStorage.SaveJob(const AJob: TJob);
begin
  if FRaiseOnSave then
    raise Exception.Create('Storage.SaveJob simulated failure');
end;

procedure TRaisingStorage.DeleteJob(const AJobId: TJobId);
begin
end;

function TRaisingStorage.LoadJob(const AJobId: TJobId): TJob;
begin
  Result := nil;
end;

function TRaisingStorage.LoadPendingJobs: TObjectList<TJob>;
begin
  Result := TObjectList<TJob>.Create(False);
end;

function TRaisingStorage.LoadJobsByStatus(AStatus: TJobStatus): TObjectList<TJob>;
begin
  Result := TObjectList<TJob>.Create(False);
end;

procedure TRaisingStorage.Clear;
begin
end;

{ TBUG324_WorkerQueueCallbackSafetyTest }

function TBUG324_WorkerQueueCallbackSafetyTest.GetBugNumber: string;
begin
  Result := 'BUG-324';
end;

function TBUG324_WorkerQueueCallbackSafetyTest.GetBugDescription: string;
begin
  Result := 'WorkerQueue callback exception leaves job stuck in jsRunning';
end;

function TBUG324_WorkerQueueCallbackSafetyTest.GetFixDate: string;
begin
  Result := '2026-06-29';
end;

function TBUG324_WorkerQueueCallbackSafetyTest.GetPriority: string;
begin
  Result := 'P1';
end;

function TBUG324_WorkerQueueCallbackSafetyTest.GetAffectedFile: string;
begin
  Result := 'Core/DeepBase.WorkerQueue.pas';
end;

procedure TBUG324_WorkerQueueCallbackSafetyTest.SetUp;
begin
  inherited;
  FQueue := TWorkerQueue.Create('bug324_test', 2);
  FRaiser := TCallbackRaiser.Create;
end;

procedure TBUG324_WorkerQueueCallbackSafetyTest.TearDown;
begin
  FreeAndNil(FQueue);
  FreeAndNil(FRaiser);
  inherited;
end;

procedure TBUG324_WorkerQueueCallbackSafetyTest.Test_OnJobStarted_Exception_JobStillCompletes;
var
  LJobId: TJobId;
  LJob: TJob;
  LCompleted: Boolean;
begin
  LCompleted := False;
  FQueue.RegisterHandler('test_started', procedure(const AJob: TJob) begin LCompleted := True; end);
  FQueue.OnJobStarted := FRaiser.RaiseOnStarted;

  LJob := FQueue.CreateJob('test_started');
  LJobId := FQueue.Enqueue(LJob);
  FQueue.Start;

  Sleep(500);

  LJob := FQueue.GetJob(LJobId);
  Assert.IsTrue(Assigned(LJob), 'Job should exist');
  Assert.AreEqual(jsCompleted, LJob.Status, 'Job should be completed despite OnJobStarted exception');
  Assert.IsTrue(LCompleted, 'Handler should have been called');
end;

procedure TBUG324_WorkerQueueCallbackSafetyTest.Test_OnJobCompleted_Exception_JobStaysCompleted;
var
  LJobId: TJobId;
  LJob: TJob;
begin
  FQueue.RegisterHandler('test_completed', procedure(const AJob: TJob) begin end);
  FQueue.OnJobCompleted := FRaiser.RaiseOnCompleted;

  LJob := FQueue.CreateJob('test_completed');
  LJobId := FQueue.Enqueue(LJob);
  FQueue.Start;

  Sleep(500);

  LJob := FQueue.GetJob(LJobId);
  Assert.IsTrue(Assigned(LJob), 'Job should exist');
  Assert.AreEqual(jsCompleted, LJob.Status, 'Job should stay completed despite OnJobCompleted exception');
end;

procedure TBUG324_WorkerQueueCallbackSafetyTest.Test_OnCompletion_Exception_JobStaysCompleted;
var
  LJobId: TJobId;
  LJob: TJob;
begin
  FQueue.RegisterHandler('test_oncompletion', procedure(const AJob: TJob) begin end);

  LJob := FQueue.CreateJob('test_oncompletion');
  LJob.OnComplete(
    procedure(const AJobId: TJobId; ASuccess: Boolean; const AResult: string)
    begin
      raise Exception.Create('OnCompletion simulated failure');
    end
  );
  LJobId := FQueue.Enqueue(LJob);
  FQueue.Start;

  Sleep(500);

  LJob := FQueue.GetJob(LJobId);
  Assert.IsTrue(Assigned(LJob), 'Job should exist');
  Assert.AreEqual(jsCompleted, LJob.Status, 'Job should stay completed despite FOnCompletion exception');
end;

procedure TBUG324_WorkerQueueCallbackSafetyTest.Test_SaveJob_PreExec_Exception_JobStillCompletes;
var
  LJobId: TJobId;
  LJob: TJob;
  LHandlerCalled: Boolean;
begin
  LHandlerCalled := False;
  FQueue.RegisterHandler('test_savepre',
    procedure(const AJob: TJob) begin LHandlerCalled := True; end);

  LJob := FQueue.CreateJob('test_savepre');
  LJobId := FQueue.Enqueue(LJob);
  // Set raising storage AFTER enqueue so Enqueue's SaveJob succeeds
  // but ProcessJob's SaveJob calls (pre and post) will raise.
  FQueue.Storage := TRaisingStorage.Create(True);
  FQueue.Start;

  Sleep(500);

  LJob := FQueue.GetJob(LJobId);
  Assert.IsTrue(Assigned(LJob), 'Job should exist');
  Assert.AreEqual(jsCompleted, LJob.Status, 'Job should complete despite SaveJob throwing');
  Assert.IsTrue(LHandlerCalled, 'Handler should have been called despite SaveJob failure');
end;

procedure TBUG324_WorkerQueueCallbackSafetyTest.Test_OnError_Exception_RetryPathStillExecutes;
var
  LJobId: TJobId;
  LJob: TJob;
  LRetryPolicy: TRetryPolicy;
begin
  FQueue.RegisterHandler('test_onerror_retry',
    procedure(const AJob: TJob)
    begin
      raise Exception.Create('Handler failure');
    end);
  FQueue.OnError := FRaiser.RaiseOnError;

  LJob := FQueue.CreateJob('test_onerror_retry');
  LRetryPolicy := TRetryPolicy.Immediate(2);
  LJob.WithRetryPolicy(LRetryPolicy);
  LJobId := FQueue.Enqueue(LJob);
  FQueue.Start;

  Sleep(1000);
  FQueue.Stop(True);

  LJob := FQueue.GetJob(LJobId);
  Assert.IsTrue(Assigned(LJob), 'Job should exist');
  Assert.AreNotEqual(jsRunning, LJob.Status, 'Job must not be stuck in jsRunning');
end;

procedure TBUG324_WorkerQueueCallbackSafetyTest.Test_OnJobFailed_Exception_JobStillFails;
var
  LJobId: TJobId;
  LJob: TJob;
begin
  FQueue.RegisterHandler('test_failed',
    procedure(const AJob: TJob)
    begin
      raise Exception.Create('Handler failure');
    end);
  FQueue.OnJobFailed := FRaiser.RaiseOnFailed;

  LJob := FQueue.CreateJob('test_failed');
  LJobId := FQueue.Enqueue(LJob);
  FQueue.Start;

  Sleep(500);

  LJob := FQueue.GetJob(LJobId);
  Assert.IsTrue(Assigned(LJob), 'Job should exist');
  Assert.AreNotEqual(jsRunning, LJob.Status, 'Job must not be stuck in jsRunning');
end;

procedure TBUG324_WorkerQueueCallbackSafetyTest.Test_OnJobRetrying_Exception_RetryStillHappens;
var
  LJobId: TJobId;
  LJob: TJob;
  LRetryPolicy: TRetryPolicy;
  LCallCount: Integer;
begin
  LCallCount := 0;
  FQueue.RegisterHandler('test_retrying',
    procedure(const AJob: TJob)
    begin
      TInterlocked.Increment(LCallCount);
      raise Exception.Create('Handler failure');
    end);
  FQueue.OnJobRetrying := FRaiser.RaiseOnRetrying;

  LJob := FQueue.CreateJob('test_retrying');
  LRetryPolicy := TRetryPolicy.Immediate(1);
  LJob.WithRetryPolicy(LRetryPolicy);
  LJobId := FQueue.Enqueue(LJob);
  FQueue.Start;

  Sleep(1000);
  FQueue.Stop(True);

  Assert.IsTrue(LCallCount >= 2,
    Format('Handler should be called at least twice (got %d) despite OnJobRetrying exception', [LCallCount]));
end;

procedure TBUG324_WorkerQueueCallbackSafetyTest.Test_ReportProgress_Exception_HandlerNotFailed;
var
  LJobId: TJobId;
  LJob: TJob;
begin
  FQueue.RegisterHandler('test_progress',
    procedure(const AJob: TJob)
    begin
      AJob.ReportProgress(50, 'halfway');
    end);

  LJob := FQueue.CreateJob('test_progress');
  LJob.OnProgress(FRaiser.RaiseOnProgress);
  LJobId := FQueue.Enqueue(LJob);
  FQueue.Start;

  Sleep(500);

  LJob := FQueue.GetJob(LJobId);
  Assert.IsTrue(Assigned(LJob), 'Job should exist');
  Assert.AreEqual(jsCompleted, LJob.Status,
    'Job should complete even when progress callback throws');
end;

procedure TBUG324_WorkerQueueCallbackSafetyTest.Test_AllCallbacksThrow_JobStateCorrect;
var
  LJobId: TJobId;
  LJob: TJob;
begin
  FQueue.RegisterHandler('test_allthrow',
    procedure(const AJob: TJob) begin end);
  FQueue.OnJobStarted := FRaiser.RaiseOnStarted;
  FQueue.OnJobCompleted := FRaiser.RaiseOnCompleted;

  LJob := FQueue.CreateJob('test_allthrow');
  LJob.OnComplete(
    procedure(const AJobId: TJobId; ASuccess: Boolean; const AResult: string)
    begin raise Exception.Create('oncompletion'); end
  );
  LJobId := FQueue.Enqueue(LJob);
  // Set raising storage AFTER enqueue so Enqueue's SaveJob succeeds.
  FQueue.Storage := TRaisingStorage.Create(True);
  FQueue.Start;

  Sleep(500);

  LJob := FQueue.GetJob(LJobId);
  Assert.IsTrue(Assigned(LJob), 'Job should exist');
  Assert.AreEqual(jsCompleted, LJob.Status,
    'Job should be completed even when ALL callbacks and storage throw');
end;

procedure TBUG324_WorkerQueueCallbackSafetyTest.Test_BUG438_HandlerException_MessagePropagatedToCompletion;
const
  HANDLER_ERR_MSG = 'BUG438 handler failure marker';
var
  LJobId: TJobId;
  LJob: TJob;
  LRetryPolicy: TRetryPolicy;
  LCompletionMsg: string;
  LCompletionSuccess: Boolean;
  LCompletionCalled: Boolean;
begin
  LCompletionMsg := '';
  LCompletionSuccess := True;
  LCompletionCalled := False;

  FQueue.RegisterHandler('test_bug438_msg',
    procedure(const AJob: TJob)
    begin
      raise Exception.Create(HANDLER_ERR_MSG);
    end);

  LJob := FQueue.CreateJob('test_bug438_msg');
  // CreateJob 默认 Timeout>0 -> 走 handler-thread 分支 (L1921), 触发原 FError
  // 悬挂路径。OnComplete 捕获 dead-letter 分支传入的 E.Message (L2081)。
  LJob.OnComplete(
    procedure(const AJobId: TJobId; ASuccess: Boolean; const AResult: string)
    begin
      LCompletionCalled := True;
      LCompletionSuccess := ASuccess;
      LCompletionMsg := AResult;
    end);
  // Immediate(2): 失败后立即重试 2 次, 全部失败 -> dead-letter -> FOnCompletion(False, E.Message)
  LRetryPolicy := TRetryPolicy.Immediate(2);
  LJob.WithRetryPolicy(LRetryPolicy);
  LJobId := FQueue.Enqueue(LJob);
  FQueue.Start;

  Sleep(1000);
  FQueue.Stop(True);

  LJob := FQueue.GetJob(LJobId);
  Assert.IsTrue(Assigned(LJob), 'Job should exist');
  Assert.AreNotEqual(jsRunning, LJob.Status, 'Job must not be stuck in jsRunning');
  // 修复前此点已 AV 216 进程退出, 无法执行到后续断言。到达此处即证明不崩。
  Assert.IsTrue(LCompletionCalled, 'FOnCompletion should be invoked for dead-lettered job');
  Assert.IsFalse(LCompletionSuccess, 'Dead-lettered job should report ASuccess=False');
  // 克隆异常对象须保留原 Message, 验证非悬挂/非垃圾。
  Assert.IsTrue(Pos(HANDLER_ERR_MSG, LCompletionMsg) > 0,
    'FOnCompletion AResult should contain handler exception Message, got: ' + LCompletionMsg);
end;

end.
