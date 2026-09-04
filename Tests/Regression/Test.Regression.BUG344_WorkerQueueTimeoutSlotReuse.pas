unit Test.Regression.BUG344_WorkerQueueTimeoutSlotReuse;

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
  TBUG344_WorkerQueueTimeoutSlotReuseTest = class(TRegressionTestBase)
  private
    FQueue: TWorkerQueue;
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
    procedure Test_TimeoutFreesWorkerSlotForNextJob;
  end;

implementation

procedure TBUG344_WorkerQueueTimeoutSlotReuseTest.SetUp;
begin
  inherited;
  FQueue := TWorkerQueue.Create('bug344', 1);
  FQueue.MaxWorkers := 1;
end;

procedure TBUG344_WorkerQueueTimeoutSlotReuseTest.TearDown;
begin
  FreeAndNil(FQueue);
  inherited;
end;

function TBUG344_WorkerQueueTimeoutSlotReuseTest.GetBugNumber: string;
begin
  Result := 'BUG-344';
end;

function TBUG344_WorkerQueueTimeoutSlotReuseTest.GetBugDescription: string;
begin
  Result := 'WorkerQueue must reuse worker slot after job timeout (C-CON-08)';
end;

function TBUG344_WorkerQueueTimeoutSlotReuseTest.GetFixDate: string;
begin
  Result := '2026-09-03';
end;

function TBUG344_WorkerQueueTimeoutSlotReuseTest.GetPriority: string;
begin
  Result := 'P1';
end;

function TBUG344_WorkerQueueTimeoutSlotReuseTest.GetAffectedFile: string;
begin
  Result := 'Core/DeepBase.WorkerQueue.pas';
end;

procedure TBUG344_WorkerQueueTimeoutSlotReuseTest.Test_TimeoutFreesWorkerSlotForNextJob;
var
  LLongStarted, LShortDone: TEvent;
  LLongJobId, LShortJobId: TJobId;
  LLongJob, LShortJob: TJob;
  LTick: UInt64;
begin
  LLongStarted := TEvent.Create(nil, True, False, '');
  LShortDone := TEvent.Create(nil, True, False, '');
  try
    FQueue.RegisterHandler('bug344_long',
      procedure(const AJob: TJob)
      begin
        LLongStarted.SetEvent;
        Sleep(800);
      end);
    FQueue.RegisterHandler('bug344_short',
      procedure(const AJob: TJob)
      begin
        LShortDone.SetEvent;
      end);

    LLongJob := FQueue.CreateJob('bug344_long');
    LLongJob.WithTimeout(100);
    LLongJobId := FQueue.Enqueue(LLongJob);
    FQueue.Start;

    Assert.IsTrue(LLongStarted.WaitFor(5000) = wrSignaled,
      'Long job should start on the single worker');

    var LWaitStart := TThread.GetTickCount64;
    while TThread.GetTickCount64 - LWaitStart < 5000 do
    begin
      LLongJob := FQueue.GetJob(LLongJobId);
      if Assigned(LLongJob) and (LLongJob.Status = jsDeadLetter) then
        Break;
      Sleep(20);
    end;
    Assert.AreEqual(jsDeadLetter, FQueue.GetJob(LLongJobId).Status,
      'Long job must time out before slot reuse is tested');

    LShortJob := FQueue.CreateJob('bug344_short');
    LShortJob.WithTimeout(5000);
    LShortJobId := FQueue.Enqueue(LShortJob);

    LTick := TThread.GetTickCount64;
    Assert.IsTrue(LShortDone.WaitFor(5000) = wrSignaled,
      'Short job must run after timed-out long job releases worker slot');
    LTick := TThread.GetTickCount64 - LTick;
    Assert.IsTrue(LTick < 5000,
      Format('Second job should start promptly, took %d ms', [LTick]));

    var LDoneWait := TThread.GetTickCount64;
    while TThread.GetTickCount64 - LDoneWait < 5000 do
    begin
      LShortJob := FQueue.GetJob(LShortJobId);
      if Assigned(LShortJob) and (LShortJob.Status = jsCompleted) then
        Break;
      Sleep(20);
    end;

    LShortJob := FQueue.GetJob(LShortJobId);
    Assert.IsNotNull(LShortJob);
    Assert.AreEqual(jsCompleted, LShortJob.Status,
      'Follow-up job must complete after slot reuse');

    LLongJob := FQueue.GetJob(LLongJobId);
    Assert.IsNotNull(LLongJob);
    Assert.AreEqual(jsDeadLetter, LLongJob.Status,
      'Timed-out long job must leave dead letter, not block the worker');
  finally
    FQueue.Stop(True);
    LShortDone.Free;
    LLongStarted.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBUG344_WorkerQueueTimeoutSlotReuseTest);

end.
