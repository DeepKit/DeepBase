// AI-GENERATED
unit Test.DeepFlow.Engine;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.DateUtils,
  DeepFlow.Engine,
  DeepFlow.Message,
  DeepFlow.Role,
  DeepFlow.Config;

type
  [TestFixture]
  TDeepFlowEngineTests = class
  private
    FEngine: TDeepFlowEngine;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Stop_FromWorkerThread_DoesNotDeadlock;
    [Test]
    procedure Stop_WhilePaused_ExitsCleanly;
    [Test]
    procedure Stop_WithTimeout_DoesNotHangIndefinitely;
    [Test]
    procedure Pause_ThenStop_DoesNotDeadlock;
  end;

implementation

{ TDeepFlowEngineTests }

procedure TDeepFlowEngineTests.Setup;
begin
  FEngine := TDeepFlowEngine.Create;
end;

procedure TDeepFlowEngineTests.TearDown;
begin
  FEngine.Free;
end;

procedure TDeepFlowEngineTests.Stop_FromWorkerThread_DoesNotDeadlock;
var
  LShutdownMsg: TDeepFlowMessage;
  LCompleted: Boolean;
  LWaitThread: TThread;
begin
  // Initialize and start the engine
  FEngine.Initialize;
  FEngine.Start;

  // Send a system.shutdown message which will trigger Stop() from worker thread
  LShutdownMsg := TDeepFlowMessage.Create;
  LShutdownMsg.MsgType := 'system.shutdown';
  LShutdownMsg.Target := 'Engine';

  // This should NOT deadlock - the engine should detect it's being called
  // from the worker thread and skip WaitFor
  FEngine.SubmitMessage(LShutdownMsg);

  // Wait a bit for the message to be processed
  Sleep(500);

  // If we got here without hanging, the test passed
  Assert.AreEqual(esStopped, FEngine.State, 'Engine should be stopped');
end;

procedure TDeepFlowEngineTests.Stop_WhilePaused_ExitsCleanly;
var
  LWaitResult: Boolean;
begin
  FEngine.Initialize;
  FEngine.Start;

  // Pause the engine
  FEngine.Pause;
  Assert.IsTrue(FEngine.State = esRunning, 'Engine should still be in Running state when paused');

  // Stop should wake the paused worker thread and exit cleanly
  FEngine.Stop;

  Assert.AreEqual(esStopped, FEngine.State, 'Engine should be stopped after Pause->Stop');
end;

procedure TDeepFlowEngineTests.Stop_WithTimeout_DoesNotHangIndefinitely;
var
  LStartTime: TDateTime;
  LElapsed: Integer;
begin
  FEngine.Initialize;
  FEngine.Start;

  LStartTime := Now;

  // Stop should complete within the timeout (5 seconds + 2 seconds fallback)
  FEngine.Stop;

  LElapsed := MilliSecondsBetween(Now, LStartTime);

  // Should complete in well under 7 seconds (5s main timeout + 2s fallback)
  Assert.IsTrue(LElapsed < 7000, 'Stop should complete within timeout, took ' + IntToStr(LElapsed) + 'ms');
  Assert.AreEqual(esStopped, FEngine.State);
end;

procedure TDeepFlowEngineTests.Pause_ThenStop_DoesNotDeadlock;
var
  LThread: TThread;
  LDone: TEvent;
begin
  FEngine.Initialize;
  FEngine.Start;

  LDone := TEvent.Create(nil, False, False, '');
  try
    // Start a thread that will pause the engine
    LThread := TThread.CreateAnonymousThread(
      procedure
      begin
        Sleep(100); // Let engine start
        FEngine.Pause;
        Sleep(100); // Let pause take effect
        FEngine.Stop;
        LDone.SetEvent;
      end
    );
    LThread.Start;

    // Wait for the thread to complete (with timeout)
    if LDone.WaitFor(5000) <> wrSignaled then
      Assert.Fail('Pause->Stop sequence deadlocked');

    Assert.AreEqual(esStopped, FEngine.State);
  finally
    LDone.Free;
  end;
end;

end.
