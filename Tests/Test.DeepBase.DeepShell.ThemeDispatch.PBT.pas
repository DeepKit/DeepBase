{ ============================================================================
  Test.DeepBase.DeepShell.ThemeDispatch.PBT - Property test for
  Theme/Localization main-thread dispatch (DSHELL-009).

  Property covered:
    P14 : Theme/Locale Thread-Correct Dispatch (Req 10.1, 10.2)
          For any call to ApplyTheme or SetLocale from a non-main thread,
          all UI subscriber callbacks SHALL execute on the main thread
          (ThreadID = MainThreadID).

  Strategy:
    - 100 iterations against TShellDefaultThemeService and 100 iterations
      against TShellDefaultLocalizationService.
    - Each iteration spawns a TThread.CreateAnonymousThread that calls
      ApplyTheme / SetLocale with a unique id so the early-exit
      "no change" branch never short-circuits the dispatch path.
    - The subscriber records the ThreadID it observes.
    - The test thread (which is the DUnitX main thread) drains the
      TThread.Queue work via System.Classes.CheckSynchronize until the
      subscriber has run, with a generous timeout.
    - Assertion: the recorded ThreadID equals MainThreadID. Because
      ApplyTheme/SetLocale check TThread.CurrentThread.ThreadID against
      MainThreadID and switch to TThread.Queue when the call originates
      off the main thread, observing MainThreadID inside the handler is
      the property under test.

  Helper-mirror coverage:
    - A second test exercises the bare main-thread detection +
      TThread.Queue dispatch logic in isolation. Useful both as a
      regression guard and as a lightweight fallback if the heavy real
      service fixture ever needs to be marked [Ignore] under specific
      runners.

  Heavy-fixture handling:
    - The real-service tests are kept active. They are bounded by a
      5 s drain timeout per iteration so a wedged main thread fails
      fast rather than hanging the suite.
  ============================================================================ }

unit Test.DeepBase.DeepShell.ThemeDispatch.PBT;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.DateUtils,
  DUnitX.TestFramework,
  DeepBase.VCL.DeepShell.Intf,
  DeepBase.VCL.DeepShell.Theme,
  DeepBase.VCL.DeepShell.Localization;

type
  [TestFixture]
  [Category('PBT')]
  TThemeLocaleDispatchPropertyTests = class
  strict private
    procedure DrainUntil(APredicate: TFunc<Boolean>; ATimeoutMs: Integer);
  public
    [Setup]
    procedure Setup;

    // Feature: deepbase-bug-fixes-p0p1p2, Property 14 - Theme service
    [Test]
    procedure Property14_ApplyTheme_DispatchesOnMainThread;

    // Feature: deepbase-bug-fixes-p0p1p2, Property 14 - Localization service
    [Test]
    procedure Property14_SetLocale_DispatchesOnMainThread;

    // Feature: deepbase-bug-fixes-p0p1p2, Property 14 - helper-mirror
    [Test]
    procedure Property14_HelperMirror_QueueRunsOnMainThread;
  end;

implementation

{ TThemeLocaleDispatchPropertyTests }

procedure TThemeLocaleDispatchPropertyTests.Setup;
begin
  Randomize;
end;

procedure TThemeLocaleDispatchPropertyTests.DrainUntil(
  APredicate: TFunc<Boolean>; ATimeoutMs: Integer);
var
  LDeadline: TDateTime;
begin
  LDeadline := IncMilliSecond(Now, ATimeoutMs);
  while not APredicate() and (Now < LDeadline) do
    CheckSynchronize(10);
  CheckSynchronize(10); // final flush
end;

// Feature: deepbase-bug-fixes-p0p1p2, Property 14 (Theme): ApplyTheme called
// off the main thread must marshal subscriber callbacks back to the main
// thread. Verified across 100 iterations with unique theme ids per call
// so the same-theme early-exit never masks the dispatch path.
procedure TThemeLocaleDispatchPropertyTests
  .Property14_ApplyTheme_DispatchesOnMainThread;
const
  CIterations = 100;
var
  Iter: Integer;
  LService: TShellDefaultThemeService;
  LObserved: TThreadID;
  LThemeId: string;
  LWorker: TThread;
begin
  for Iter := 1 to CIterations do
  begin
    LService := TShellDefaultThemeService.Create;
    try
      LObserved := 0;
      LThemeId := 'PBT-Theme-' + IntToStr(Iter) + '-' + IntToStr(Random(MaxInt));

      LService.OnThemeChanged(
        procedure(const AId: string)
        begin
          // Record the ThreadID the handler runs on. The handler is
          // expected to execute on the main thread (this test thread),
          // so a plain assignment is safe: there is no other writer
          // unless the dispatch property is violated, which is what
          // we are testing for.
          LObserved := TThread.CurrentThread.ThreadID;
        end);

      LWorker := TThread.CreateAnonymousThread(
        procedure
        begin
          LService.ApplyTheme(LThemeId);
        end);
      LWorker.FreeOnTerminate := False;
      try
        LWorker.Start;
        LWorker.WaitFor;
      finally
        LWorker.Free;
      end;

      DrainUntil(
        function: Boolean
        begin
          Result := LObserved <> 0;
        end,
        5000);

      Assert.AreNotEqual<TThreadID>(0, LObserved,
        Format('Iter %d: theme subscriber must have run; queue drain '
          + 'observed no callback within timeout', [Iter]));
      Assert.AreEqual<TThreadID>(MainThreadID, LObserved,
        Format('Iter %d: theme subscriber ran on thread %d but must run '
          + 'on the main thread (%d)',
          [Iter, NativeInt(LObserved), NativeInt(MainThreadID)]));
    finally
      LService.Free;
    end;
  end;
end;

// Feature: deepbase-bug-fixes-p0p1p2, Property 14 (Localization): SetLocale
// called off the main thread must marshal subscriber callbacks back to the
// main thread. Same shape as the Theme test, with unique locale ids per
// iteration so the SameText early-exit never short-circuits dispatch.
procedure TThemeLocaleDispatchPropertyTests
  .Property14_SetLocale_DispatchesOnMainThread;
const
  CIterations = 100;
var
  Iter: Integer;
  LService: TShellDefaultLocalizationService;
  LObserved: TThreadID;
  LLocale: string;
  LWorker: TThread;
begin
  for Iter := 1 to CIterations do
  begin
    LService := TShellDefaultLocalizationService.Create('en-US');
    try
      LObserved := 0;
      LLocale := 'pbt-' + IntToStr(Iter) + '-' + IntToStr(Random(MaxInt));

      LService.OnLocaleChanged(
        procedure(const ALocale: string)
        begin
          LObserved := TThread.CurrentThread.ThreadID;
        end);

      LWorker := TThread.CreateAnonymousThread(
        procedure
        begin
          LService.SetLocale(LLocale);
        end);
      LWorker.FreeOnTerminate := False;
      try
        LWorker.Start;
        LWorker.WaitFor;
      finally
        LWorker.Free;
      end;

      DrainUntil(
        function: Boolean
        begin
          Result := LObserved <> 0;
        end,
        5000);

      Assert.AreNotEqual<TThreadID>(0, LObserved,
        Format('Iter %d: locale subscriber must have run; queue drain '
          + 'observed no callback within timeout', [Iter]));
      Assert.AreEqual<TThreadID>(MainThreadID, LObserved,
        Format('Iter %d: locale subscriber ran on thread %d but must run '
          + 'on the main thread (%d)',
          [Iter, NativeInt(LObserved), NativeInt(MainThreadID)]));
    finally
      LService.Free;
    end;
  end;
end;

// Feature: deepbase-bug-fixes-p0p1p2, Property 14 (helper-mirror): the bare
// "main-thread detection + TThread.Queue marshalling" pattern that
// ApplyTheme / SetLocale rely on. Cheaper than the real services, and
// independent of Theme / Localization implementation churn.
procedure TThemeLocaleDispatchPropertyTests
  .Property14_HelperMirror_QueueRunsOnMainThread;
const
  CIterations = 100;
var
  Iter: Integer;
  LObserved: TThreadID;
  LCalls: Integer;
  LWorker: TThread;
begin
  for Iter := 1 to CIterations do
  begin
    LObserved := 0;
    LCalls := 0;

    LWorker := TThread.CreateAnonymousThread(
      procedure
      var
        LIsMain: Boolean;
      begin
        LIsMain := TThread.CurrentThread.ThreadID = MainThreadID;
        if LIsMain then
        begin
          // Should never happen for this fixture, but the branch is the
          // production pattern and we keep it for parity.
          Inc(LCalls);
          LObserved := TThread.CurrentThread.ThreadID;
        end
        else
          TThread.Queue(nil,
            procedure
            begin
              Inc(LCalls);
              LObserved := TThread.CurrentThread.ThreadID;
            end);
      end);
    LWorker.FreeOnTerminate := False;
    try
      LWorker.Start;
      LWorker.WaitFor;
    finally
      LWorker.Free;
    end;

    DrainUntil(
      function: Boolean
      begin
        Result := LCalls > 0;
      end,
      5000);

    Assert.AreEqual<Integer>(1, LCalls,
      Format('Iter %d: queued callback must run exactly once', [Iter]));
    Assert.AreEqual<TThreadID>(MainThreadID, LObserved,
      Format('Iter %d: queued callback ran on thread %d but must run on '
        + 'the main thread (%d)',
        [Iter, NativeInt(LObserved), NativeInt(MainThreadID)]));
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TThemeLocaleDispatchPropertyTests);

end.
