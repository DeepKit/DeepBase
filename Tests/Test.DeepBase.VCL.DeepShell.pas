{ ============================================================================
  Test.DeepBase.VCL.DeepShell

  Contract tests for the DeepShell desktop shell. The bulk of the cases here
  are regression tests for fixes that the 2026-05-14 audit caught:

    BUG-166: ResolveServicesFromRegistry must rebind FRecent / FLayout /
             FSettings to whatever the descendant registered.
    BUG-167: EventBus + form bridge must not UAF after the form is destroyed
             when a queued main-thread dispatch is still pending.
    BUG-168: TShellCommandManager.Execute must reject when the gate result
             reports denied (out param) even if the function returns True.
    BUG-169: TDeepMainForm constructor must not call virtual methods; the
             Register* / BuildShellUI chain runs in AfterConstruction.

  Plus generic contract tests for the in-memory services so regressions in
  ordering / capacity / JSON round-trip are caught before they reach apps.
  ============================================================================ }

unit Test.DeepBase.VCL.DeepShell;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Threading,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  DeepBase.VCL.DeepShell.Types,
  DeepBase.VCL.DeepShell.Intf,
  DeepBase.VCL.DeepShell.Events,
  DeepBase.VCL.DeepShell.Services,
  DeepBase.VCL.DeepShell.Context,
  DeepBase.VCL.DeepShell.Commands,
  DeepBase.VCL.DeepShell.Recent,
  DeepBase.VCL.DeepShell.Layout,
  DeepBase.VCL.DeepShell.Settings,
  DeepBase.VCL.DeepShell.Panels,
  DeepBase.VCL.DeepShell.MainForm;

type
  // -------- Test doubles ---------------------------------------------------

  /// <summary>
  /// Governance double that returns a configured (Boolean, GateResult) pair
  /// for every EnterGate call. Lets us drive BUG-168 fail-closed test
  /// without a real OCGS adapter.
  /// </summary>
  TFakeGovernance = class(TInterfacedObject, IGovernanceService)
  private
    FEnabled: Boolean;
    FFunctionResult: Boolean;
    FGateOutcome: TShellGateOutcome;
    FCalled: Boolean;
  public
    constructor Create(AEnabled: Boolean; AFunctionResult: Boolean;
      AGateOutcome: TShellGateOutcome);
    function IsEnabled: Boolean;
    function EnterGate(const AGateKey, AContextJson: string;
      out AResult: TShellGateResult): Boolean;
    property Called: Boolean read FCalled;
  end;

  /// <summary>
  /// Recent double used to verify ResolveServicesFromRegistry binds the
  /// shell to the registry-registered service rather than the default.
  /// </summary>
  TFakeRecent = class(TInterfacedObject, IShellRecentService)
  private
    FAddCount: Integer;
  public
    procedure AddRecent(const AItem: TShellRecentItem);
    procedure AddRecentProject(const AProjectId, APath, ADisplayName, ALayoutKey: string);
    function GetRecent(AKind: TShellRecentKind): TArray<TShellRecentItem>;
    function GetRecentProjects: TArray<TShellRecentItem>;
    procedure MarkInvalid(AKind: TShellRecentKind; const AItemKey: string);
    procedure Remove(AKind: TShellRecentKind; const AItemKey: string);
    procedure Clear;
    property AddCount: Integer read FAddCount;
  end;

  /// <summary>
  /// TDeepMainForm subclass that swaps the default Recent service with a
  /// fake during RegisterServices, so the ResolveServicesFromRegistry
  /// rebinding path can be verified.
  /// </summary>
  TFakeMainForm = class(TDeepMainForm)
  private
    FFakeRecent: TFakeRecent;
    FRegisterServicesCalled: Boolean;
    FRegisterCommandsCalled: Boolean;
    FRegisterProvidersCalled: Boolean;
    FBuildShellUICalled: Boolean;
  protected
    procedure RegisterServices; override;
    procedure RegisterCommands; override;
    procedure RegisterProviders; override;
    procedure BuildShellUI; override;
  public
    property FakeRecent: TFakeRecent read FFakeRecent;
    property RegisterServicesCalled: Boolean read FRegisterServicesCalled;
    property RegisterCommandsCalled: Boolean read FRegisterCommandsCalled;
    property RegisterProvidersCalled: Boolean read FRegisterProvidersCalled;
    property BuildShellUICalled: Boolean read FBuildShellUICalled;
  end;

  // -------- Fixtures --------------------------------------------------------

  [TestFixture]
  TTestShellEventBus = class
  public
    [Test] procedure SubscribeAndPublish_DispatchesOnSameThread;
    [Test] procedure UnsubscribeStopsFutureDispatch;
    [Test] procedure SubscribeAll_GetsEveryKind;
    [Test] procedure BackgroundPublish_DoesNotUAF_AfterBusReleased;
    [Test] procedure UnsubscribeBeforeQueueDrain_QueuedHandlerDoesNotRun;
  end;

  [TestFixture]
  TTestShellCommandManager = class
  public
    [Test] procedure Execute_AllowedGate_RunsHandler;
    [Test] procedure Execute_DeniedByGateResult_DoesNotRunHandler;
    [Test] procedure Execute_FunctionFalse_DoesNotRunHandler;
    [Test] procedure Execute_NoGateKey_SkipsGovernance;
    [Test] procedure Execute_DisabledCommand_NoOp;
    [Test] procedure Register_PreservesInsertionOrderInCommandIds;
    [Test] procedure Execute_FromBackgroundThread_RunsOnMainThread;
    [Test] procedure ExecuteSync_FromBackgroundThread_BlocksUntilHandlerCompletes;
  end;

  [TestFixture]
  TTestShellRecentService = class
  public
    [Test] procedure AddRecentProject_DeduplicatesByKey;
    [Test] procedure AddRecentProject_RespectsCapacity;
    [Test] procedure GetRecentProjects_OrderedByLastOpenedAt;
  end;

  [TestFixture]
  TTestShellLayoutService = class
  public
    [Test] procedure SettingsBacked_RoundTripPreservesPanelState;
    [Test] procedure InMemory_TryLoadGlobal_FalseWhenUnset;
    [Test] procedure SettingsBacked_RemoteNewerSkipsLocalWrite;
    [Test] procedure SettingsBacked_SameInstanceAlwaysWins;
  end;

  [TestFixture]
  TTestShellAreaController = class
  public
    [Test] procedure SetCollapsed_RemembersLastExpandedSize;
    [Test] procedure ApplyState_RestoresExpandedSize;
  end;

  [TestFixture]
  TTestDeepMainFormLifecycle = class
  public
    [Test] procedure AfterConstruction_RunsLifecycleVirtualsInOrder;
    [Test] procedure ResolveServicesFromRegistry_PicksUpDescendantOverride;
  end;

implementation

uses
  System.JSON,
  System.DateUtils,
  DeepBase.VCL.DeepShell.Localization,
  DeepBase.VCL.DeepShell.Theme;

// ---------------------------------------------------------------------------
// TFakeGovernance
// ---------------------------------------------------------------------------

constructor TFakeGovernance.Create(AEnabled: Boolean; AFunctionResult: Boolean;
  AGateOutcome: TShellGateOutcome);
begin
  inherited Create;
  FEnabled := AEnabled;
  FFunctionResult := AFunctionResult;
  FGateOutcome := AGateOutcome;
end;

function TFakeGovernance.IsEnabled: Boolean;
begin
  Result := FEnabled;
end;

function TFakeGovernance.EnterGate(const AGateKey, AContextJson: string;
  out AResult: TShellGateResult): Boolean;
begin
  FCalled := True;
  AResult := Default(TShellGateResult);
  AResult.Outcome := FGateOutcome;
  if FGateOutcome <> sgoAllowed then
  begin
    AResult.ReasonCode := 'fake.deny';
    AResult.MessageText := 'denied by fake governance';
  end;
  Result := FFunctionResult;
end;

// ---------------------------------------------------------------------------
// TFakeRecent
// ---------------------------------------------------------------------------

procedure TFakeRecent.AddRecent(const AItem: TShellRecentItem);
begin
  Inc(FAddCount);
end;

procedure TFakeRecent.AddRecentProject(const AProjectId, APath,
  ADisplayName, ALayoutKey: string);
begin
  Inc(FAddCount);
end;

function TFakeRecent.GetRecent(AKind: TShellRecentKind): TArray<TShellRecentItem>;
begin
  SetLength(Result, 0);
end;

function TFakeRecent.GetRecentProjects: TArray<TShellRecentItem>;
begin
  SetLength(Result, 0);
end;

procedure TFakeRecent.MarkInvalid(AKind: TShellRecentKind; const AItemKey: string);
begin
end;

procedure TFakeRecent.Remove(AKind: TShellRecentKind; const AItemKey: string);
begin
end;

procedure TFakeRecent.Clear;
begin
end;

// ---------------------------------------------------------------------------
// TFakeMainForm
// ---------------------------------------------------------------------------

procedure TFakeMainForm.RegisterServices;
begin
  inherited;
  FRegisterServicesCalled := True;
  // BUG-166 setup: replace the default in-memory recent service with a
  // fake. After ResolveServicesFromRegistry the form's Recent property
  // must point to this fake, not to the in-memory default.
  FFakeRecent := TFakeRecent.Create;
  Services.RegisterService(CAP_SHELL_RECENT, FFakeRecent);
end;

procedure TFakeMainForm.RegisterCommands;
begin
  inherited;
  FRegisterCommandsCalled := True;
end;

procedure TFakeMainForm.RegisterProviders;
begin
  inherited;
  FRegisterProvidersCalled := True;
end;

procedure TFakeMainForm.BuildShellUI;
begin
  inherited;
  FBuildShellUICalled := True;
end;

// ---------------------------------------------------------------------------
// TTestShellEventBus
// ---------------------------------------------------------------------------

procedure TTestShellEventBus.SubscribeAndPublish_DispatchesOnSameThread;
var
  LBus: IShellEventBus;
  LCalled: Integer;
  LEvent: TDeepShellEvent;
begin
  LBus := TShellEventBus.Create;
  LCalled := 0;
  LBus.Subscribe(sekLogAdded,
    procedure(const E: TDeepShellEvent)
    begin
      Inc(LCalled);
    end);
  LEvent := Default(TDeepShellEvent);
  LEvent.Kind := sekLogAdded;
  LBus.Publish(LEvent);
  Assert.AreEqual(1, LCalled);
end;

procedure TTestShellEventBus.UnsubscribeStopsFutureDispatch;
var
  LBus: IShellEventBus;
  LToken: string;
  LCalled: Integer;
  LEvent: TDeepShellEvent;
begin
  LBus := TShellEventBus.Create;
  LCalled := 0;
  LToken := LBus.Subscribe(sekLogAdded,
    procedure(const E: TDeepShellEvent)
    begin
      Inc(LCalled);
    end);
  LEvent := Default(TDeepShellEvent);
  LEvent.Kind := sekLogAdded;
  LBus.Publish(LEvent);
  LBus.Unsubscribe(LToken);
  LBus.Publish(LEvent);
  Assert.AreEqual(1, LCalled,
    'Handler should not run for events published after Unsubscribe');
end;

procedure TTestShellEventBus.SubscribeAll_GetsEveryKind;
var
  LBus: IShellEventBus;
  LCalled: Integer;
  LEvent: TDeepShellEvent;
begin
  LBus := TShellEventBus.Create;
  LCalled := 0;
  LBus.SubscribeAll(
    procedure(const E: TDeepShellEvent)
    begin
      Inc(LCalled);
    end);
  LEvent := Default(TDeepShellEvent);
  LEvent.Kind := sekLogAdded;
  LBus.Publish(LEvent);
  LEvent.Kind := sekProjectOpened;
  LBus.Publish(LEvent);
  Assert.AreEqual(2, LCalled);
end;

procedure TTestShellEventBus.BackgroundPublish_DoesNotUAF_AfterBusReleased;
var
  LBus: IShellEventBus;
  LDispatched: Integer;
  LSync: TEvent;
  LEvent: TDeepShellEvent;
  LTask: ITask;
begin
  // BUG-167 regression: a background-thread Publish must keep the bus alive
  // through the queued main-thread dispatch via interface refcount, even
  // after the test releases its bus reference.
  LBus := TShellEventBus.Create;
  LDispatched := 0;
  LSync := TEvent.Create(nil, True, False, '');
  try
    LBus.Subscribe(sekLogAdded,
      procedure(const E: TDeepShellEvent)
      begin
        Inc(LDispatched);
      end);

    LEvent := Default(TDeepShellEvent);
    LEvent.Kind := sekLogAdded;

    LTask := TTask.Run(
      procedure
      begin
        LBus.Publish(LEvent);
        LSync.SetEvent;
      end);
    LSync.WaitFor(2000);
    LTask.Wait;

    // Drop our local reference. The pending Queue closure must hold the
    // bus alive via captured interface ref; if it doesn't, the next
    // CheckSynchronize would access a freed bus.
    LBus := nil;
    CheckSynchronize(500);
    Assert.AreEqual(1, LDispatched,
      'Queued background dispatch must still run after caller releases bus');
  finally
    LSync.Free;
  end;
end;

procedure TTestShellEventBus.UnsubscribeBeforeQueueDrain_QueuedHandlerDoesNotRun;
var
  LBus: IShellEventBus;
  LCalled: Integer;
  LToken: string;
  LSync: TEvent;
  LEvent: TDeepShellEvent;
  LTask: ITask;
begin
  // BUG: general-purpose Unsubscribe semantics. Background-thread Publish
  // queues a main-thread dispatch. If the subscriber Unsubscribes before
  // CheckSynchronize drains the queue, the handler must NOT run. Tests
  // the token-based re-lookup added on top of the bridge fix.
  LBus := TShellEventBus.Create;
  LCalled := 0;
  LSync := TEvent.Create(nil, True, False, '');
  try
    LToken := LBus.Subscribe(sekLogAdded,
      procedure(const E: TDeepShellEvent)
      begin
        Inc(LCalled);
      end);

    LEvent := Default(TDeepShellEvent);
    LEvent.Kind := sekLogAdded;

    LTask := TTask.Run(
      procedure
      begin
        LBus.Publish(LEvent);
        LSync.SetEvent;
      end);
    LSync.WaitFor(2000);
    LTask.Wait;

    // Unsubscribe BEFORE pumping the queued dispatch.
    LBus.Unsubscribe(LToken);
    CheckSynchronize(500);
    Assert.AreEqual(0, LCalled,
      'Handler unsubscribed before queue drain must not run');
  finally
    LSync.Free;
  end;
end;

// ---------------------------------------------------------------------------
// TTestShellCommandManager
// ---------------------------------------------------------------------------

procedure TTestShellCommandManager.Execute_AllowedGate_RunsHandler;
var
  LBus: IShellEventBus;
  LMgr: IShellCommandManager;
  LMgrImpl: TShellCommandManager;
  LRan: Boolean;
  LFakeGov: TFakeGovernance;
begin
  LBus := TShellEventBus.Create;
  LMgrImpl := TShellCommandManager.Create(LBus,
    function: TShellContext begin Result := TShellContext.Empty; end);
  LMgr := LMgrImpl;
  LFakeGov := TFakeGovernance.Create(True, True, sgoAllowed);
  LMgrImpl.SetGovernance(LFakeGov);

  LRan := False;
  LMgr.RegisterCommand(
    ShellCommand('t.allow', 'Allow').GateKey('g.allow').RiskLevel(rlMedium)
      .OnExecute(procedure begin LRan := True; end));
  LMgr.Execute('t.allow');
  Assert.IsTrue(LRan, 'Handler must run when gate allows');
  Assert.IsTrue(LFakeGov.Called, 'Gate must be consulted');
end;

procedure TTestShellCommandManager.Execute_DeniedByGateResult_DoesNotRunHandler;
var
  LBus: IShellEventBus;
  LMgr: IShellCommandManager;
  LMgrImpl: TShellCommandManager;
  LRan: Boolean;
  LFakeGov: TFakeGovernance;
begin
  // BUG-168 regression: function returns True (call succeeded) but
  // out param says denied. Old code ran the handler. New code must reject.
  LBus := TShellEventBus.Create;
  LMgrImpl := TShellCommandManager.Create(LBus,
    function: TShellContext begin Result := TShellContext.Empty; end);
  LMgr := LMgrImpl;
  LFakeGov := TFakeGovernance.Create(True, True, sgoDeniedHard);
  LMgrImpl.SetGovernance(LFakeGov);

  LRan := False;
  LMgr.RegisterCommand(
    ShellCommand('t.deny', 'Deny').GateKey('g.deny').RiskLevel(rlHigh)
      .OnExecute(procedure begin LRan := True; end));
  LMgr.Execute('t.deny');
  Assert.IsFalse(LRan,
    'Handler must NOT run when gate result reports denied (BUG-168)');
end;

procedure TTestShellCommandManager.Execute_FunctionFalse_DoesNotRunHandler;
var
  LBus: IShellEventBus;
  LMgr: IShellCommandManager;
  LMgrImpl: TShellCommandManager;
  LRan: Boolean;
  LFakeGov: TFakeGovernance;
begin
  LBus := TShellEventBus.Create;
  LMgrImpl := TShellCommandManager.Create(LBus,
    function: TShellContext begin Result := TShellContext.Empty; end);
  LMgr := LMgrImpl;
  LFakeGov := TFakeGovernance.Create(True, False, sgoAllowed);
  LMgrImpl.SetGovernance(LFakeGov);

  LRan := False;
  LMgr.RegisterCommand(
    ShellCommand('t.callfail', 'Fail').GateKey('g.fail').RiskLevel(rlMedium)
      .OnExecute(procedure begin LRan := True; end));
  LMgr.Execute('t.callfail');
  Assert.IsFalse(LRan,
    'Handler must NOT run when EnterGate returns False');
end;

procedure TTestShellCommandManager.Execute_NoGateKey_SkipsGovernance;
var
  LBus: IShellEventBus;
  LMgr: IShellCommandManager;
  LMgrImpl: TShellCommandManager;
  LRan: Boolean;
  LFakeGov: TFakeGovernance;
begin
  LBus := TShellEventBus.Create;
  LMgrImpl := TShellCommandManager.Create(LBus,
    function: TShellContext begin Result := TShellContext.Empty; end);
  LMgr := LMgrImpl;
  LFakeGov := TFakeGovernance.Create(True, False, sgoDeniedHard);
  LMgrImpl.SetGovernance(LFakeGov);

  LRan := False;
  LMgr.RegisterCommand(
    ShellCommand('t.nogate', 'No Gate')
      .OnExecute(procedure begin LRan := True; end));
  LMgr.Execute('t.nogate');
  Assert.IsTrue(LRan, 'No GateKey: governance must be skipped entirely');
  Assert.IsFalse(LFakeGov.Called,
    'No GateKey: governance must NOT be invoked');
end;

procedure TTestShellCommandManager.Execute_DisabledCommand_NoOp;
var
  LBus: IShellEventBus;
  LMgr: IShellCommandManager;
  LRan: Boolean;
begin
  LBus := TShellEventBus.Create;
  LMgr := TShellCommandManager.Create(LBus,
    function: TShellContext begin Result := TShellContext.Empty; end);

  LRan := False;
  LMgr.RegisterCommand(
    ShellCommand('t.disabled', 'Off').Enabled(False)
      .OnExecute(procedure begin LRan := True; end));
  LMgr.Execute('t.disabled');
  Assert.IsFalse(LRan, 'Disabled commands must not invoke handler');
end;

procedure TTestShellCommandManager.Register_PreservesInsertionOrderInCommandIds;
var
  LBus: IShellEventBus;
  LMgr: IShellCommandManager;
  LIds: TArray<string>;
begin
  LBus := TShellEventBus.Create;
  LMgr := TShellCommandManager.Create(LBus,
    function: TShellContext begin Result := TShellContext.Empty; end);

  LMgr.RegisterCommand(ShellCommand('a', 'A'));
  LMgr.RegisterCommand(ShellCommand('b', 'B'));
  LMgr.RegisterCommand(ShellCommand('c', 'C'));

  LIds := LMgr.CommandIds;
  Assert.AreEqual<Integer>(3, Length(LIds));
  Assert.AreEqual('a', LIds[0]);
  Assert.AreEqual('b', LIds[1]);
  Assert.AreEqual('c', LIds[2]);
end;

procedure TTestShellCommandManager.Execute_FromBackgroundThread_RunsOnMainThread;
var
  LBus: IShellEventBus;
  LMgr: IShellCommandManager;
  LHandlerThreadId: TThreadID;
  LSync: TEvent;
  LTask: ITask;
begin
  // Background-thread Execute must marshal the handler onto the main
  // thread so UI code in command handlers does not crash. Captured
  // FHandlerThreadId records where the handler actually ran.
  LBus := TShellEventBus.Create;
  LMgr := TShellCommandManager.Create(LBus,
    function: TShellContext begin Result := TShellContext.Empty; end);

  LHandlerThreadId := 0;
  LSync := TEvent.Create(nil, True, False, '');
  try
    LMgr.RegisterCommand(
      ShellCommand('t.bgexec', 'BG')
        .OnExecute(procedure
          begin
            LHandlerThreadId := TThread.CurrentThread.ThreadID;
            LSync.SetEvent;
          end));

    LTask := TTask.Run(
      procedure
      begin
        LMgr.Execute('t.bgexec');
      end);
    LTask.Wait;
    // Pump main-thread queue so the marshalled handler runs.
    CheckSynchronize(2000);
    LSync.WaitFor(500);

    Assert.AreEqual<TThreadID>(MainThreadID, LHandlerThreadId,
      'Background-thread Execute must marshal the handler onto the main thread');
  finally
    LTask := nil;
    LMgr := nil;
    LBus := nil;
    LSync.Free;
  end;
end;

procedure TTestShellCommandManager.ExecuteSync_FromBackgroundThread_BlocksUntilHandlerCompletes;
var
  LBus: IShellEventBus;
  LMgr: IShellCommandManager;
  LCounter: Integer;
  LObservedAfterSync: Integer;
  LTask: ITask;
begin
  // ExecuteSync from a background thread must block until the handler
  // has finished running on the main thread. We launch a worker that
  // calls ExecuteSync; while waiting the main thread pumps Synchronize.
  LBus := TShellEventBus.Create;
  LMgr := TShellCommandManager.Create(LBus,
    function: TShellContext begin Result := TShellContext.Empty; end);
  LCounter := 0;
  LObservedAfterSync := -1;
  LMgr.RegisterCommand(
    ShellCommand('t.sync', 'Sync')
      .OnExecute(procedure
        begin
          Inc(LCounter);
        end));

  LTask := TTask.Run(
    procedure
    begin
      LMgr.ExecuteSync('t.sync');
      // After ExecuteSync returns, handler MUST have run.
      LObservedAfterSync := LCounter;
    end);

  // Pump main-thread queue so Synchronize can land.
  while not LTask.Wait(50) do
    CheckSynchronize(50);

  Assert.AreEqual<Integer>(1, LObservedAfterSync,
    'ExecuteSync must block until handler completes on main thread');
  LTask := nil;
  LMgr := nil;
  LBus := nil;
end;

// ---------------------------------------------------------------------------
// TTestShellRecentService
// ---------------------------------------------------------------------------

procedure TTestShellRecentService.AddRecentProject_DeduplicatesByKey;
var
  LSvc: IShellRecentService;
  LItems: TArray<TShellRecentItem>;
begin
  LSvc := TShellInMemoryRecentService.Create;
  LSvc.AddRecentProject('p1', 'C:\p1', 'P1', 'L1');
  LSvc.AddRecentProject('p1', 'C:\p1', 'P1 updated', 'L1');
  LItems := LSvc.GetRecentProjects;
  Assert.AreEqual<Integer>(1, Length(LItems));
  Assert.AreEqual('P1 updated', LItems[0].DisplayName);
end;

procedure TTestShellRecentService.AddRecentProject_RespectsCapacity;
var
  LSvc: IShellRecentService;
  LItems: TArray<TShellRecentItem>;
  I: Integer;
begin
  LSvc := TShellInMemoryRecentService.Create(3);
  for I := 1 to 5 do
    LSvc.AddRecentProject('p' + IntToStr(I), '', '', '');
  LItems := LSvc.GetRecentProjects;
  Assert.AreEqual<Integer>(3, Length(LItems));
end;

procedure TTestShellRecentService.GetRecentProjects_OrderedByLastOpenedAt;
var
  LSvc: IShellRecentService;
  LItems: TArray<TShellRecentItem>;
begin
  LSvc := TShellInMemoryRecentService.Create;
  LSvc.AddRecentProject('p1', '', 'P1', '');
  Sleep(15);
  LSvc.AddRecentProject('p2', '', 'P2', '');
  Sleep(15);
  LSvc.AddRecentProject('p3', '', 'P3', '');
  LItems := LSvc.GetRecentProjects;
  Assert.AreEqual<Integer>(3, Length(LItems));
  Assert.AreEqual('p3', LItems[0].ProjectId, 'most recently added wins');
  Assert.AreEqual('p2', LItems[1].ProjectId);
  Assert.AreEqual('p1', LItems[2].ProjectId);
end;

// ---------------------------------------------------------------------------
// TTestShellLayoutService
// ---------------------------------------------------------------------------

procedure TTestShellLayoutService.SettingsBacked_RoundTripPreservesPanelState;
var
  LStore: IShellSettingsStore;
  LSvc: IShellLayoutService;
  LIn, LOut: TShellLayoutState;
begin
  LStore := TShellInMemorySettingsStore.Create;
  LSvc := TShellSettingsBackedLayoutService.Create(LStore, 'inst-1');

  LIn := TShellLayoutState.Empty;
  LIn.LayoutKey := 'main';
  LIn.MainLeft := 100;
  LIn.MainTop := 200;
  LIn.MainWidth := 800;
  LIn.MainHeight := 600;
  LIn.Maximized := True;
  LIn.TopPanel.Collapsed := True;
  LIn.TopPanel.LastExpandedSize := 80;

  LSvc.SaveGlobalLayout(LIn);
  Assert.IsTrue(LSvc.TryLoadGlobalLayout(LOut), 'TryLoadGlobalLayout must find saved state');
  Assert.AreEqual(100, LOut.MainLeft);
  Assert.AreEqual(800, LOut.MainWidth);
  Assert.IsTrue(LOut.Maximized);
  Assert.IsTrue(LOut.TopPanel.Collapsed);
  Assert.AreEqual(80, LOut.TopPanel.LastExpandedSize);
end;

procedure TTestShellLayoutService.InMemory_TryLoadGlobal_FalseWhenUnset;
var
  LSvc: IShellLayoutService;
  LState: TShellLayoutState;
begin
  LSvc := TShellInMemoryLayoutService.Create;
  Assert.IsFalse(LSvc.TryLoadGlobalLayout(LState),
    'In-memory layout returns False before any save');
end;

procedure TTestShellLayoutService.SettingsBacked_RemoteNewerSkipsLocalWrite;
var
  LStore: IShellSettingsStore;
  LSvc: IShellLayoutService;
  LState, LCheck: TShellLayoutState;
  LFutureJson: string;
begin
  // Multi-instance CAS regression: a remote instance has just written a
  // state with a UpdatedAt in the FUTURE relative to our wall clock.
  // When local then SaveGlobalLayout, the CAS guard must skip the write.
  // We simulate the remote write by injecting JSON directly into the
  // shared settings store with a far-future timestamp.
  LStore := TShellInMemorySettingsStore.Create;
  LSvc := TShellSettingsBackedLayoutService.Create(LStore, 'inst-local');

  LFutureJson := Format(
    '{"layoutKey":"main","updatedAt":"%s","sequence":1,'
    + '"writerInstanceId":"inst-remote","mainLeft":0,"mainTop":0,'
    + '"mainWidth":9999,"mainHeight":0,"maximized":false}',
    [DateToISO8601(IncDay(Now, 7), False)]);
  LStore.WriteString('shell.layout.global', LFutureJson);

  LState := TShellLayoutState.Empty;
  LState.MainWidth := 500;
  LSvc.SaveGlobalLayout(LState);

  Assert.IsTrue(LSvc.TryLoadGlobalLayout(LCheck));
  Assert.AreEqual(9999, LCheck.MainWidth,
    'Local save must NOT overwrite a remote-newer record (CAS skip)');
end;

procedure TTestShellLayoutService.SettingsBacked_SameInstanceAlwaysWins;
var
  LStore: IShellSettingsStore;
  LSvc: IShellLayoutService;
  LStateA, LStateB, LCheck: TShellLayoutState;
begin
  // Same-instance writes are always last-write-wins; the CAS guard should
  // never block them.
  LStore := TShellInMemorySettingsStore.Create;
  LSvc := TShellSettingsBackedLayoutService.Create(LStore, 'inst-1');

  LStateA := TShellLayoutState.Empty;
  LStateA.MainWidth := 100;
  LSvc.SaveGlobalLayout(LStateA);

  LStateB := TShellLayoutState.Empty;
  LStateB.MainWidth := 200;
  LSvc.SaveGlobalLayout(LStateB);

  Assert.IsTrue(LSvc.TryLoadGlobalLayout(LCheck));
  Assert.AreEqual(200, LCheck.MainWidth,
    'Same-instance second save must win regardless of UpdatedAt rounding');
end;

// ---------------------------------------------------------------------------
// TTestShellAreaController
// ---------------------------------------------------------------------------

procedure TTestShellAreaController.SetCollapsed_RemembersLastExpandedSize;
var
  LPanel: TPanel;
  LCtl: TShellAreaController;
begin
  LPanel := TPanel.Create(nil);
  try
    LPanel.Height := 200;
    LCtl := TShellAreaController.Create(LPanel, nil, LPanel, nil, PANEL_TOP);
    try
      LCtl.SetCollapsed(True);
      Assert.AreEqual(200, LCtl.State.LastExpandedSize,
        'Collapsing must remember pre-collapse height');
      Assert.IsTrue(LCtl.State.Collapsed);

      LCtl.SetCollapsed(False);
      Assert.IsFalse(LCtl.State.Collapsed);
      Assert.AreEqual(200, LPanel.Height,
        'Restoring must put back the remembered height');
    finally
      LCtl.Free;
    end;
  finally
    LPanel.Free;
  end;
end;

procedure TTestShellAreaController.ApplyState_RestoresExpandedSize;
var
  LPanel: TPanel;
  LCtl: TShellAreaController;
  LState: TShellPanelState;
begin
  LPanel := TPanel.Create(nil);
  try
    LCtl := TShellAreaController.Create(LPanel, nil, LPanel, nil, PANEL_BOTTOM);
    try
      LState := TShellPanelState.Make(PANEL_BOTTOM);
      LState.Visible := True;
      LState.Collapsed := False;
      LState.Size := 220;
      LState.LastExpandedSize := 220;
      LCtl.ApplyState(LState);
      Assert.AreEqual(220, LPanel.Height);
    finally
      LCtl.Free;
    end;
  finally
    LPanel.Free;
  end;
end;

// ---------------------------------------------------------------------------
// TTestDeepMainFormLifecycle
// ---------------------------------------------------------------------------

procedure TTestDeepMainFormLifecycle.AfterConstruction_RunsLifecycleVirtualsInOrder;
var
  LForm: TFakeMainForm;
begin
  // BUG-169 regression: Create must NOT call virtual methods directly;
  // they fire from AfterConstruction so descendants are fully constructed.
  // When the constructor returns, all four flags must be True.
  LForm := TFakeMainForm.Create(nil);
  try
    Assert.IsTrue(LForm.RegisterServicesCalled, 'RegisterServices must run');
    Assert.IsTrue(LForm.RegisterCommandsCalled, 'RegisterCommands must run');
    Assert.IsTrue(LForm.RegisterProvidersCalled, 'RegisterProviders must run');
    Assert.IsTrue(LForm.BuildShellUICalled, 'BuildShellUI must run');
  finally
    LForm.Free;
  end;
end;

procedure TTestDeepMainFormLifecycle.ResolveServicesFromRegistry_PicksUpDescendantOverride;
var
  LForm: TFakeMainForm;
  LRecent: IShellRecentService;
begin
  // BUG-166 regression: descendant registers a fake recent service via
  // Services.RegisterService inside RegisterServices. After
  // ResolveServicesFromRegistry the form must use that fake when
  // OpenProject calls AddRecentProject.
  LForm := TFakeMainForm.Create(nil);
  try
    Assert.IsNotNull(LForm.FakeRecent, 'FakeMainForm must have created fake');

    LRecent := LForm.Recent;
    Assert.IsTrue((LRecent as TObject) is TFakeRecent,
      'Form.Recent must be the registry-registered fake (BUG-166)');

    LForm.OpenProject('p1', 'C:\p1');
    Assert.IsTrue(LForm.FakeRecent.AddCount >= 1,
      'OpenProject must dispatch to the registry-registered recent service');
  finally
    LForm.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestShellEventBus);
  TDUnitX.RegisterTestFixture(TTestShellCommandManager);
  TDUnitX.RegisterTestFixture(TTestShellRecentService);
  TDUnitX.RegisterTestFixture(TTestShellLayoutService);
  TDUnitX.RegisterTestFixture(TTestShellAreaController);
  TDUnitX.RegisterTestFixture(TTestDeepMainFormLifecycle);

end.
