unit Test.Regression.BUG342_EventBusMainThreadDrain;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Threading,
  DUnitX.TestFramework,
  Test.Regression.Base,
  DeepBase.EventBus;

type
  TBug342Event = record
    Value: Integer;
  end;

  [TestFixture]
  [Category('regression')]
  TBUG342_EventBusMainThreadDrainTest = class(TRegressionTestBase)
  protected
    function GetBugNumber: string; override;
    function GetBugDescription: string; override;
    function GetFixDate: string; override;
    function GetPriority: string; override;
    function GetAffectedFile: string; override;
  public
    [Test]
    procedure Test_DestroyDrainsMainThreadQueueHandlers;
  end;

implementation

function TBUG342_EventBusMainThreadDrainTest.GetBugNumber: string;
begin
  Result := 'BUG-342';
end;

function TBUG342_EventBusMainThreadDrainTest.GetBugDescription: string;
begin
  Result := 'EventBus Destroy must drain edmMainThread Queue handlers without hang';
end;

function TBUG342_EventBusMainThreadDrainTest.GetFixDate: string;
begin
  Result := '2026-09-03';
end;

function TBUG342_EventBusMainThreadDrainTest.GetPriority: string;
begin
  Result := 'P1';
end;

function TBUG342_EventBusMainThreadDrainTest.GetAffectedFile: string;
begin
  Result := 'Core/DeepBase.EventBus.pas';
end;

procedure TBUG342_EventBusMainThreadDrainTest.Test_DestroyDrainsMainThreadQueueHandlers;
var
  LBus: TEventBus;
  LHandlerRan: TEvent;
  LDestroyDone: TEvent;
  LDestroyThread: TThread;
  LPublishStarted: TEvent;
  LTick: UInt64;
  LEvt: TBug342Event;
begin
  LBus := TEventBus.Create;
  LHandlerRan := TEvent.Create(nil, True, False, '');
  LPublishStarted := TEvent.Create(nil, True, False, '');
  LDestroyDone := TEvent.Create(nil, True, False, '');
  try
    LBus.Subscribe<TBug342Event>(
      procedure(const Event: TBug342Event)
      begin
        Sleep(30);
        LHandlerRan.SetEvent;
      end,
      epNormal,
      edmMainThread);

    TTask.Run(
      procedure
      begin
        LPublishStarted.SetEvent;
        LEvt.Value := 1;
        LBus.Publish<TBug342Event>(LEvt, edmMainThread);
      end);

    Assert.IsTrue(LPublishStarted.WaitFor(5000) = wrSignaled,
      'Publish thread should start');

    LDestroyThread := TThread.CreateAnonymousThread(
      procedure
      begin
        try
          LBus.Free;
          LBus := nil;
        finally
          LDestroyDone.SetEvent;
        end;
      end);
    LDestroyThread.FreeOnTerminate := False;
    LDestroyThread.Start;

    LTick := TThread.GetTickCount64;
    while LDestroyDone.WaitFor(50) <> wrSignaled do
    begin
      CheckSynchronize(10);
      if TThread.GetTickCount64 - LTick >= 5000 then
        Assert.Fail('EventBus.Destroy must return within 5s while main-thread handlers pending');
    end;

    Assert.IsTrue(LHandlerRan.WaitFor(0) = wrSignaled,
      'Queued main-thread handler must run during Destroy drain');
    LDestroyThread.WaitFor;
    LDestroyThread.Free;
  finally
    if Assigned(LBus) then
      LBus.Free;
    LDestroyDone.Free;
    LPublishStarted.Free;
    LHandlerRan.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBUG342_EventBusMainThreadDrainTest);

end.
