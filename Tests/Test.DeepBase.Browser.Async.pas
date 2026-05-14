unit Test.DeepBase.Browser.Async;

interface

uses
  DUnitX.TestFramework,
  DeepBase.Browser.Types;

type
  [TestFixture]
  TBrowserAsyncTests = class
  public
    [Test]
    procedure Test_AsyncPattern_TTaskRun_TThreadQueue;

    [Test]
    procedure Test_IBrowserSessionAsync_Interface_HasCorrectGUID;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.Threading,
  System.SyncObjs;

{ TBrowserAsyncTests }

procedure TBrowserAsyncTests.Test_AsyncPattern_TTaskRun_TThreadQueue;
var
  LResult: string;
  LEvent: TEvent;
  LTask: ITask;
  LWaitedMs: Integer;
begin
  LResult := '';
  LEvent := TEvent.Create(nil, True, False, '');
  try
    LTask := TTask.Run(TProc(
      procedure
      begin
        // Simulate async browser work
        TThread.Sleep(50);
        TThread.Queue(nil,
          procedure
          begin
            LResult := 'completed';
            LEvent.SetEvent;
          end);
      end));

    // Wait for callback on main thread while pumping queued calls.
    LWaitedMs := 0;
    while (LEvent.WaitFor(10) <> wrSignaled) and
      (LWaitedMs < 5000) do
    begin
      CheckSynchronize(10);
      Inc(LWaitedMs, 20);
    end;

    Assert.AreEqual(wrSignaled, LEvent.WaitFor(0));
    Assert.AreEqual('completed', LResult);
  finally
    LEvent.Free;
  end;
end;

procedure TBrowserAsyncTests.Test_IBrowserSessionAsync_Interface_HasCorrectGUID;
var
  LGUID: TGUID;
begin
  LGUID := IBrowserSessionAsync;
  Assert.IsFalse(LGUID = TGUID.Empty,
    'IBrowserSessionAsync should have a valid GUID');
end;

initialization
  TDUnitX.RegisterTestFixture(TBrowserAsyncTests);

end.
