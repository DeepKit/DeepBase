unit Test.UniBase.AppLifecycle;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestAppLifecycle = class
  private
    FTempDir: string;
    FProgramID: string;
  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure AcquireSingleton_IsReentrantAndReleaseAllowsReacquire;

    [Test]
    procedure MarkStarted_DetectsPreviousRunningAsCrash;

    [Test]
    procedure MarkCleanShutdown_ResetsCrashCount;

    [Test]
    procedure RequestShutdown_SetsSignalState;

    [Test]
    procedure WaitForShutdownSignal_BlocksUntilRequestAndCallsCallback;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Classes,
  UniBase.AppLifecycle;

procedure TTestAppLifecycle.Setup;
var
  GuidText: string;
begin
  GuidText := TGUID.NewGuid.ToString;
  GuidText := StringReplace(GuidText, '{', '', [rfReplaceAll]);
  GuidText := StringReplace(GuidText, '}', '', [rfReplaceAll]);
  FTempDir := TPath.Combine(TPath.GetTempPath, 'UniBase_AppLifecycle_' + GuidText);
  TDirectory.CreateDirectory(FTempDir);
  FProgramID := 'Test.AppLifecycle.' + GuidText;

  TAppLifecycle.Reset;
  TAppLifecycle.Configure(FProgramID, FTempDir);
end;

procedure TTestAppLifecycle.TearDown;
begin
  TAppLifecycle.Reset;
  if (FTempDir <> '') and TDirectory.Exists(FTempDir) then
    TDirectory.Delete(FTempDir, True);
end;

procedure TTestAppLifecycle.AcquireSingleton_IsReentrantAndReleaseAllowsReacquire;
var
  LockName: string;
begin
  LockName := 'Lifecycle.Lock.' + FProgramID;

  Assert.IsTrue(TAppLifecycle.AcquireSingleton(LockName));
  Assert.IsTrue(TAppLifecycle.AcquireSingleton(LockName),
    'Same owner should be able to call AcquireSingleton idempotently');

  TAppLifecycle.ReleaseSingleton;
  Assert.IsTrue(TAppLifecycle.AcquireSingleton(LockName));
end;

procedure TTestAppLifecycle.MarkStarted_DetectsPreviousRunningAsCrash;
begin
  TAppLifecycle.MarkStarted;
  Assert.AreEqual(0, TAppLifecycle.CrashCount);

  TAppLifecycle.Reset;
  TAppLifecycle.Configure(FProgramID, FTempDir);
  TAppLifecycle.MarkStarted;

  Assert.AreEqual(1, TAppLifecycle.CrashCount);
end;

procedure TTestAppLifecycle.MarkCleanShutdown_ResetsCrashCount;
begin
  TAppLifecycle.MarkStarted;
  TAppLifecycle.Reset;
  TAppLifecycle.Configure(FProgramID, FTempDir);
  TAppLifecycle.MarkStarted;
  Assert.AreEqual(1, TAppLifecycle.CrashCount);

  TAppLifecycle.MarkCleanShutdown;
  Assert.AreEqual(0, TAppLifecycle.CrashCount);

  TAppLifecycle.MarkStarted;
  Assert.AreEqual(0, TAppLifecycle.CrashCount);
end;

procedure TTestAppLifecycle.RequestShutdown_SetsSignalState;
begin
  Assert.IsFalse(TAppLifecycle.ShutdownRequested);

  TAppLifecycle.RequestShutdown('test');

  Assert.IsTrue(TAppLifecycle.ShutdownRequested);
  Assert.AreEqual('test', TAppLifecycle.ShutdownReason);
end;

procedure TTestAppLifecycle.WaitForShutdownSignal_BlocksUntilRequestAndCallsCallback;
var
  CallbackCalled: Boolean;
  Worker: TThread;
begin
  CallbackCalled := False;
  Worker := TThread.CreateAnonymousThread(
    procedure
    begin
      TThread.Sleep(50);
      TAppLifecycle.RequestShutdown('unit-test');
    end);
  Worker.FreeOnTerminate := False;
  try
    Worker.Start;
    TAppLifecycle.WaitForShutdownSignal(
      procedure
      begin
        CallbackCalled := True;
      end);
    Worker.WaitFor;
  finally
    Worker.Free;
  end;

  Assert.IsTrue(CallbackCalled);
  Assert.IsTrue(TAppLifecycle.ShutdownRequested);
  Assert.AreEqual('unit-test', TAppLifecycle.ShutdownReason);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestAppLifecycle);

end.
