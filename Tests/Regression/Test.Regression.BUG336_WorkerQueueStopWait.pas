unit Test.Regression.BUG336_WorkerQueueStopWait;

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
  TBUG336_WorkerQueueStopWaitTest = class(TRegressionTestBase)
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
    procedure Test_StopFalse_WaitsForWorkers;
  end;

implementation

procedure TBUG336_WorkerQueueStopWaitTest.SetUp;
begin
  inherited;
  FQueue := TWorkerQueue.Create;
  FQueue.MaxWorkers := 2;
  FQueue.DefaultTimeout := 0;
  FQueue.Start;
end;

procedure TBUG336_WorkerQueueStopWaitTest.TearDown;
begin
  FreeAndNil(FQueue);
  inherited;
end;

function TBUG336_WorkerQueueStopWaitTest.GetBugNumber: string;
begin
  Result := 'BUG-336';
end;

function TBUG336_WorkerQueueStopWaitTest.GetBugDescription: string;
begin
  Result := 'WorkerQueue Stop(False) must WaitFor worker threads before free';
end;

function TBUG336_WorkerQueueStopWaitTest.GetFixDate: string;
begin
  Result := '2026-09-02';
end;

function TBUG336_WorkerQueueStopWaitTest.GetPriority: string;
begin
  Result := 'P0';
end;

function TBUG336_WorkerQueueStopWaitTest.GetAffectedFile: string;
begin
  Result := 'Core/DeepBase.WorkerQueue.pas';
end;

procedure TBUG336_WorkerQueueStopWaitTest.Test_StopFalse_WaitsForWorkers;
var
  LStarted, LFinished: TEvent;
  LJob: TJob;
  LTick: UInt64;
begin
  LStarted := TEvent.Create(nil, True, False, '');
  LFinished := TEvent.Create(nil, True, False, '');
  try
    FQueue.RegisterHandler('bug336_sleep',
      procedure(const AJob: TJob)
      begin
        LStarted.SetEvent;
        Sleep(80);
        LFinished.SetEvent;
      end);

    LJob := TJob.Create('bug336_sleep');
    LJob.WithTimeout(0);
    FQueue.Enqueue(LJob);

    Assert.IsTrue(LStarted.WaitFor(5000) = wrSignaled,
      'Job should start on a worker thread');

    LTick := TThread.GetTickCount64;
    FQueue.Stop(False);
    LTick := TThread.GetTickCount64 - LTick;

    Assert.IsTrue(LFinished.WaitFor(0) = wrSignaled,
      'Worker must finish in-flight job before Stop returns');
    Assert.IsTrue(LTick < 5000,
      Format('Stop(False) must join promptly, took %d ms', [LTick]));
  finally
    LFinished.Free;
    LStarted.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBUG336_WorkerQueueStopWaitTest);

end.
