{ ============================================================================
  Test.Regression.BUG325_WorkerQueueTimeout - REVIEW5-CORE-003

  Verifies that WorkerQueue enforces job timeout semantics:
  - A handler that exceeds Timeout ms is marked as jsFailed
  - The job's Result.ErrorMessage indicates timeout
  - Jobs without timeout (Timeout=0) run normally
  - The job is moved to dead letter after timeout (no retry)
  ============================================================================ }

unit Test.Regression.BUG325_WorkerQueueTimeout;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  DUnitX.TestFramework,
  Test.Regression.Base,
  DeepBase.WorkerQueue;

type
  [TestFixture]
  [Category('regression')]
  TBUG325_WorkerQueueTimeoutTest = class(TRegressionTestBase)
  private
    FQueue: TWorkerQueue;
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

    /// <summary>Handler exceeds timeout => job is jsFailed with timeout message</summary>
    [Test]
    procedure Test_HandlerTimeout_JobMarkedFailed;

    /// <summary>Handler within timeout => job completes normally</summary>
    [Test]
    procedure Test_HandlerWithinTimeout_JobCompletes;

    /// <summary>No timeout (0) => handler runs to completion</summary>
    [Test]
    procedure Test_NoTimeout_HandlerCompletes;

    /// <summary>Timed-out job goes to dead letter (no retry on timeout)</summary>
    [Test]
    procedure Test_Timeout_NoRetry_DeadLetter;

    /// <summary>Handler throws exception (not timeout) => normal error path</summary>
    [Test]
    procedure Test_HandlerException_NotTimeout;
  end;

implementation

{ TBUG325_WorkerQueueTimeoutTest }

function TBUG325_WorkerQueueTimeoutTest.GetBugNumber: string;
begin
  Result := 'BUG-325';
end;

function TBUG325_WorkerQueueTimeoutTest.GetBugDescription: string;
begin
  Result := 'WorkerQueue timeout not enforced — long handlers stuck in jsRunning';
end;

function TBUG325_WorkerQueueTimeoutTest.GetFixDate: string;
begin
  Result := '2026-06-29';
end;

function TBUG325_WorkerQueueTimeoutTest.GetPriority: string;
begin
  Result := 'P1';
end;

function TBUG325_WorkerQueueTimeoutTest.GetAffectedFile: string;
begin
  Result := 'Core/DeepBase.WorkerQueue.pas';
end;

procedure TBUG325_WorkerQueueTimeoutTest.SetUp;
begin
  inherited;
  FQueue := TWorkerQueue.Create('bug325_test', 2);
end;

procedure TBUG325_WorkerQueueTimeoutTest.TearDown;
begin
  FreeAndNil(FQueue);
  inherited;
end;

procedure TBUG325_WorkerQueueTimeoutTest.Test_HandlerTimeout_JobMarkedFailed;
var
  LJobId: TJobId;
  LJob: TJob;
begin
  FQueue.RegisterHandler('test_timeout',
    procedure(const AJob: TJob)
    begin
      Sleep(500); // Exceeds the 100ms timeout
    end);

  LJob := FQueue.CreateJob('test_timeout');
  LJob.WithTimeout(100); // 100ms timeout
  LJobId := FQueue.Enqueue(LJob);
  FQueue.Start;

  // Wait long enough for the handler to finish (500ms) plus overhead
  Sleep(1500);
  FQueue.Stop(True);

  LJob := FQueue.GetJob(LJobId);
  Assert.IsTrue(Assigned(LJob), 'Job should exist');
  Assert.AreNotEqual(jsRunning, LJob.Status, 'Job must not be stuck in jsRunning');
  // The job should be failed (timed out)
  Assert.AreEqual(jsDeadLetter, LJob.Status, 'Timed out job should be in dead letter');
  Assert.IsTrue(Pos('timed out', LowerCase(LJob.Result.ErrorMessage)) > 0,
    'Error message should mention timeout, got: ' + LJob.Result.ErrorMessage);
end;

procedure TBUG325_WorkerQueueTimeoutTest.Test_HandlerWithinTimeout_JobCompletes;
var
  LJobId: TJobId;
  LJob: TJob;
begin
  FQueue.RegisterHandler('test_within',
    procedure(const AJob: TJob)
    begin
      Sleep(50); // Well within the 5000ms timeout
    end);

  LJob := FQueue.CreateJob('test_within');
  LJob.WithTimeout(5000); // 5 second timeout
  LJobId := FQueue.Enqueue(LJob);
  FQueue.Start;

  Sleep(500);

  LJob := FQueue.GetJob(LJobId);
  Assert.IsTrue(Assigned(LJob), 'Job should exist');
  Assert.AreEqual(jsCompleted, LJob.Status, 'Job should complete within timeout');
end;

procedure TBUG325_WorkerQueueTimeoutTest.Test_NoTimeout_HandlerCompletes;
var
  LJobId: TJobId;
  LJob: TJob;
begin
  FQueue.RegisterHandler('test_noto',
    procedure(const AJob: TJob)
    begin
      Sleep(100);
    end);

  LJob := FQueue.CreateJob('test_noto');
  LJob.WithTimeout(0); // No timeout — run to completion
  LJobId := FQueue.Enqueue(LJob);
  FQueue.Start;

  Sleep(500);

  LJob := FQueue.GetJob(LJobId);
  Assert.IsTrue(Assigned(LJob), 'Job should exist');
  Assert.AreEqual(jsCompleted, LJob.Status, 'Job with no timeout should complete normally');
end;

procedure TBUG325_WorkerQueueTimeoutTest.Test_Timeout_NoRetry_DeadLetter;
var
  LJobId: TJobId;
  LJob: TJob;
  LRetryPolicy: TRetryPolicy;
begin
  FQueue.RegisterHandler('test_tonoretry',
    procedure(const AJob: TJob)
    begin
      Sleep(500); // Exceeds timeout
    end);

  LJob := FQueue.CreateJob('test_tonoretry');
  LJob.WithTimeout(100); // Short timeout
  // Even with retry policy, timeout goes to dead letter (no retry)
  LRetryPolicy := TRetryPolicy.Immediate(3);
  LJob.WithRetryPolicy(LRetryPolicy);
  LJobId := FQueue.Enqueue(LJob);
  FQueue.Start;

  Sleep(1500);
  FQueue.Stop(True);

  LJob := FQueue.GetJob(LJobId);
  Assert.IsTrue(Assigned(LJob), 'Job should exist');
  Assert.AreEqual(jsDeadLetter, LJob.Status,
    'Timed out job should go directly to dead letter, not retry');
end;

procedure TBUG325_WorkerQueueTimeoutTest.Test_HandlerException_NotTimeout;
var
  LJobId: TJobId;
  LJob: TJob;
begin
  FQueue.RegisterHandler('test_exc',
    procedure(const AJob: TJob)
    begin
      raise Exception.Create('Handler error (not timeout)');
    end);

  LJob := FQueue.CreateJob('test_exc');
  LJob.WithTimeout(5000); // Long timeout — should NOT trigger
  LJob.WithRetryPolicy(TRetryPolicy.None); // No retries — go straight to dead letter
  LJobId := FQueue.Enqueue(LJob);
  FQueue.Start;

  Sleep(500);

  LJob := FQueue.GetJob(LJobId);
  Assert.IsTrue(Assigned(LJob), 'Job should exist');
  Assert.AreNotEqual(jsRunning, LJob.Status, 'Job should not be in jsRunning');
  // Handler exception should result in dead letter (no retry configured)
  Assert.AreEqual(jsDeadLetter, LJob.Status, 'Handler exception should go to dead letter');
  Assert.AreEqual('Handler error (not timeout)', LJob.Result.ErrorMessage,
    'Error message should be from handler, not timeout');
end;

end.
