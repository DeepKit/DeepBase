/// <summary>
/// Unit tests for UniBase.StateMachine module
/// Tests: TStateMachine, TStateConfiguration, TStateMachineBuilder,
///        Transitions, Guards, Entry/Exit Actions, Events, History
/// </summary>
unit Test.UniBase.StateMachine;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  DUnitX.TestFramework,
  UniBase.StateMachine;

type
  // Test states
  TTestState = (tsIdle, tsRunning, tsPaused, tsStopped, tsCompleted);
  // Test triggers
  TTestTrigger = (ttStart, ttPause, ttResume, ttStop, ttComplete, ttReset);

  /// <summary>
  /// Tests for TTransitionResult
  /// </summary>
  [TestFixture]
  TTransitionResultTests = class
  public
    [Test]
    procedure Test_CreateSuccess;
    [Test]
    procedure Test_CreateFailure;
    [Test]
    procedure Test_CreateIgnored;
  end;

  /// <summary>
  /// Tests for TStateConfiguration
  /// </summary>
  [TestFixture]
  TStateConfigurationTests = class
  private
    FStateMachine: TStateMachine<TTestState, TTestTrigger>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // Permit tests
    [Test]
    procedure Test_Permit_FluentAPI;
    [Test]
    procedure Test_Permit_MultipleTransitions;
    [Test]
    procedure Test_PermitIf_WithGuard;
    [Test]
    procedure Test_PermitIf_GuardDescription;

    // Reentry tests
    [Test]
    procedure Test_PermitReentry;
    [Test]
    procedure Test_PermitReentryIf;

    // Internal transition tests
    [Test]
    procedure Test_InternalTransition;
    [Test]
    procedure Test_InternalTransitionIf;

    // Ignore tests
    [Test]
    procedure Test_Ignore;
    [Test]
    procedure Test_IgnoreIf;

    // Entry/Exit action tests
    [Test]
    procedure Test_OnEntry;
    [Test]
    procedure Test_OnExit;
    [Test]
    procedure Test_MultipleEntryActions;
    [Test]
    procedure Test_MultipleExitActions;

    // Hierarchical state tests
    [Test]
    procedure Test_SubstateOf;
    [Test]
    procedure Test_InitialTransition;
  end;

  /// <summary>
  /// Tests for TStateMachine basic functionality
  /// </summary>
  [TestFixture]
  TStateMachineBasicTests = class
  private
    FStateMachine: TStateMachine<TTestState, TTestTrigger>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Create_InitialState;
    [Test]
    procedure Test_CurrentState;
    [Test]
    procedure Test_Configure_ReturnsConfiguration;
    [Test]
    procedure Test_Configure_SameStateReturnsSameConfig;
    [Test]
    procedure Test_Start_ExecutesEntryActions;
    [Test]
    procedure Test_IsStarted_BeforeStart;
    [Test]
    procedure Test_IsStarted_AfterStart;
  end;

  /// <summary>
  /// Tests for TStateMachine transitions
  /// </summary>
  [TestFixture]
  TStateMachineTransitionTests = class
  private
    FStateMachine: TStateMachine<TTestState, TTestTrigger>;
    FEntryCount: Integer;
    FExitCount: Integer;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Fire_SimpleTransition;
    [Test]
    procedure Test_Fire_MultipleTransitions;
    [Test]
    procedure Test_Fire_ReturnsTrueOnSuccess;
    [Test]
    procedure Test_Fire_ExecutesExitActions;
    [Test]
    procedure Test_Fire_ExecutesEntryActions;
    [Test]
    procedure Test_Fire_UnhandledTrigger_Throws;
    [Test]
    procedure Test_Fire_UnhandledTrigger_NoThrow;
    [Test]
    procedure Test_Fire_IgnoredTrigger;
    [Test]
    procedure Test_FireIfInState_CorrectState;
    [Test]
    procedure Test_FireIfInState_WrongState;
    [Test]
    procedure Test_CanFire_True;
    [Test]
    procedure Test_CanFire_False;
    [Test]
    procedure Test_GetPermittedTriggers;
  end;

  /// <summary>
  /// Tests for TStateMachine guards
  /// </summary>
  [TestFixture]
  TStateMachineGuardTests = class
  private
    FStateMachine: TStateMachine<TTestState, TTestTrigger>;
    FGuardValue: Boolean;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Guard_AllowsTransition;
    [Test]
    procedure Test_Guard_BlocksTransition;
    [Test]
    procedure Test_Guard_MultipleGuards;
  end;

  /// <summary>
  /// Tests for TStateMachine actions
  /// </summary>
  [TestFixture]
  TStateMachineActionTests = class
  private
    FStateMachine: TStateMachine<TTestState, TTestTrigger>;
    FActionLog: TList<string>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_TransitionAction_Executes;
    [Test]
    procedure Test_TransitionAction_ReceivesParameters;
    [Test]
    procedure Test_EntryAction_Order;
    [Test]
    procedure Test_ExitAction_Order;
    [Test]
    procedure Test_InternalTransition_NoEntryExit;
    [Test]
    procedure Test_Reentry_ExecutesEntryExit;
  end;

  /// <summary>
  /// Tests for TStateMachine events
  /// </summary>
  [TestFixture]
  TStateMachineEventTests = class
  private
    FStateMachine: TStateMachine<TTestState, TTestTrigger>;
    FStateChangedCalled: Boolean;
    FOldState: TTestState;
    FNewState: TTestState;
    FLastTrigger: TTestTrigger;
    FTransitionFailedCalled: Boolean;
    FFailedState: TTestState;
    FFailedTrigger: TTestTrigger;
    procedure HandleStateChanged(Sender: TObject; const AOldState, ANewState: TTestState; const ATrigger: TTestTrigger);
    procedure HandleTransitionFailed(Sender: TObject; const AState: TTestState; const ATrigger: TTestTrigger; const AReason: string);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_OnStateChanged_Fires;
    [Test]
    procedure Test_OnStateChanged_CorrectParameters;
    [Test]
    procedure Test_OnTransitionFailed_Fires;
  end;

  /// <summary>
  /// Tests for TStateMachine history
  /// </summary>
  [TestFixture]
  TStateMachineHistoryTests = class
  private
    FStateMachine: TStateMachine<TTestState, TTestTrigger>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_GetHistory_Empty;
    [Test]
    procedure Test_GetHistory_AfterTransitions;
    [Test]
    procedure Test_ClearHistory;
    [Test]
    procedure Test_MaxHistorySize;
  end;

  /// <summary>
  /// Tests for TStateMachine reset
  /// </summary>
  [TestFixture]
  TStateMachineResetTests = class
  private
    FStateMachine: TStateMachine<TTestState, TTestTrigger>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Reset_ReturnToInitialState;
    [Test]
    procedure Test_Reset_AfterMultipleTransitions;
  end;

  /// <summary>
  /// Tests for TStateMachine IsIn
  /// </summary>
  [TestFixture]
  TStateMachineIsInTests = class
  private
    FStateMachine: TStateMachine<TTestState, TTestTrigger>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_IsIn_CurrentState;
    [Test]
    procedure Test_IsIn_NotCurrentState;
  end;

  /// <summary>
  /// Tests for TStateMachine context
  /// </summary>
  [TestFixture]
  TStateMachineContextTests = class
  private
    FStateMachine: TStateMachine<TTestState, TTestTrigger>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Context_SetGet;
    [Test]
    procedure Test_Context_OwnsContext;
    [Test]
    procedure Test_Context_InGuard;
    [Test]
    procedure Test_Context_InAction;
  end;

  /// <summary>
  /// Tests for TStateMachineBuilder
  /// </summary>
  [TestFixture]
  TStateMachineBuilderTests = class
  public
    [Test]
    procedure Test_Builder_Create;
    [Test]
    procedure Test_Builder_State;
    [Test]
    procedure Test_Builder_Permit;
    [Test]
    procedure Test_Builder_PermitIf;
    [Test]
    procedure Test_Builder_OnEntry;
    [Test]
    procedure Test_Builder_OnExit;
    [Test]
    procedure Test_Builder_Ignore;
    [Test]
    procedure Test_Builder_SubstateOf;
    [Test]
    procedure Test_Builder_WithContext;
    [Test]
    procedure Test_Builder_Build;
    [Test]
    procedure Test_Builder_FluentChain;
  end;

  /// <summary>
  /// Tests for string-based state machine
  /// </summary>
  [TestFixture]
  TStringStateMachineTests = class
  private
    FStateMachine: TStringStateMachine;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_StringStates;
    [Test]
    procedure Test_StringTriggers;
    [Test]
    procedure Test_StringTransitions;
  end;

  /// <summary>
  /// Tests for exception handling
  /// </summary>
  [TestFixture]
  TStateMachineExceptionTests = class
  private
    FStateMachine: TStateMachine<TTestState, TTestTrigger>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_InvalidTransition_Exception;
    [Test]
    procedure Test_InvalidTransition_ExceptionType;
  end;

  // Test context class
  TTestContext = class
  private
    FValue: Integer;
  public
    property Value: Integer read FValue write FValue;
  end;

implementation

// ============================================================================
// TTransitionResultTests
// ============================================================================

procedure TTransitionResultTests.Test_CreateSuccess;
var
  Result: TTransitionResult<TTestState, TTestTrigger>;
begin
  Result := TTransitionResult<TTestState, TTestTrigger>.CreateSuccess(tsIdle, tsRunning, ttStart);
  Assert.IsTrue(Result.Success);
  Assert.AreEqual(tsIdle, Result.FromState);
  Assert.AreEqual(tsRunning, Result.ToState);
  Assert.AreEqual(ttStart, Result.Trigger);
  Assert.AreEqual('', Result.ErrorMessage);
  Assert.IsFalse(Result.WasIgnored);
end;

procedure TTransitionResultTests.Test_CreateFailure;
var
  Result: TTransitionResult<TTestState, TTestTrigger>;
begin
  Result := TTransitionResult<TTestState, TTestTrigger>.CreateFailure(tsIdle, ttPause, 'Guard failed');
  Assert.IsFalse(Result.Success);
  Assert.AreEqual(tsIdle, Result.FromState);
  Assert.AreEqual(tsIdle, Result.ToState);
  Assert.AreEqual(ttPause, Result.Trigger);
  Assert.AreEqual('Guard failed', Result.ErrorMessage);
  Assert.IsFalse(Result.WasIgnored);
end;

procedure TTransitionResultTests.Test_CreateIgnored;
var
  Result: TTransitionResult<TTestState, TTestTrigger>;
begin
  Result := TTransitionResult<TTestState, TTestTrigger>.CreateIgnored(tsRunning, ttStart);
  Assert.IsTrue(Result.Success);
  Assert.AreEqual(tsRunning, Result.FromState);
  Assert.AreEqual(tsRunning, Result.ToState);
  Assert.IsTrue(Result.WasIgnored);
end;

// ============================================================================
// TStateConfigurationTests
// ============================================================================

procedure TStateConfigurationTests.Setup;
begin
  FStateMachine := TStateMachine<TTestState, TTestTrigger>.Create(tsIdle);
end;

procedure TStateConfigurationTests.TearDown;
begin
  FStateMachine.Free;
end;

procedure TStateConfigurationTests.Test_Permit_FluentAPI;
var
  Config: TStateConfiguration<TTestState, TTestTrigger>;
  Result: TStateConfiguration<TTestState, TTestTrigger>;
begin
  Config := FStateMachine.Configure(tsIdle);
  Result := Config.Permit(ttStart, tsRunning);
  Assert.AreSame(Config, Result);
end;

procedure TStateConfigurationTests.Test_Permit_MultipleTransitions;
var
  Config: TStateConfiguration<TTestState, TTestTrigger>;
begin
  Config := FStateMachine.Configure(tsIdle);
  Config.Permit(ttStart, tsRunning);
  Config.Permit(ttComplete, tsCompleted);
  Assert.AreEqual(2, Config.Transitions.Count);
end;

procedure TStateConfigurationTests.Test_PermitIf_WithGuard;
var
  Config: TStateConfiguration<TTestState, TTestTrigger>;
begin
  Config := FStateMachine.Configure(tsIdle);
  Config.PermitIf(ttStart, tsRunning,
    function(const Ctx: TObject): Boolean
    begin
      Result := True;
    end);
  Assert.AreEqual(1, Config.Transitions.Count);
  Assert.IsNotNull(@Config.Transitions[0].Guard);
end;

procedure TStateConfigurationTests.Test_PermitIf_GuardDescription;
var
  Config: TStateConfiguration<TTestState, TTestTrigger>;
begin
  Config := FStateMachine.Configure(tsIdle);
  Config.PermitIf(ttStart, tsRunning,
    function(const Ctx: TObject): Boolean
    begin
      Result := True;
    end, 'Must be ready');
  Assert.AreEqual('Must be ready', Config.Transitions[0].GuardDescription);
end;

procedure TStateConfigurationTests.Test_PermitReentry;
var
  Config: TStateConfiguration<TTestState, TTestTrigger>;
begin
  Config := FStateMachine.Configure(tsRunning);
  Config.PermitReentry(ttReset);
  Assert.IsTrue(Config.Transitions[0].IsReentry);
  Assert.AreEqual(tsRunning, Config.Transitions[0].TargetState);
end;

procedure TStateConfigurationTests.Test_PermitReentryIf;
var
  Config: TStateConfiguration<TTestState, TTestTrigger>;
begin
  Config := FStateMachine.Configure(tsRunning);
  Config.PermitReentryIf(ttReset,
    function(const Ctx: TObject): Boolean
    begin
      Result := True;
    end);
  Assert.IsTrue(Config.Transitions[0].IsReentry);
end;

procedure TStateConfigurationTests.Test_InternalTransition;
var
  Config: TStateConfiguration<TTestState, TTestTrigger>;
begin
  Config := FStateMachine.Configure(tsRunning);
  Config.InternalTransition(ttPause,
    procedure(const From, To: TTestState; const Trigger: TTestTrigger; const Ctx: TObject)
    begin
    end);
  Assert.IsTrue(Config.Transitions[0].IsInternal);
end;

procedure TStateConfigurationTests.Test_InternalTransitionIf;
var
  Config: TStateConfiguration<TTestState, TTestTrigger>;
begin
  Config := FStateMachine.Configure(tsRunning);
  Config.InternalTransitionIf(ttPause,
    function(const Ctx: TObject): Boolean
    begin
      Result := True;
    end,
    procedure(const From, To: TTestState; const Trigger: TTestTrigger; const Ctx: TObject)
    begin
    end);
  Assert.IsTrue(Config.Transitions[0].IsInternal);
  Assert.IsNotNull(@Config.Transitions[0].Guard);
end;

procedure TStateConfigurationTests.Test_Ignore;
var
  Config: TStateConfiguration<TTestState, TTestTrigger>;
begin
  Config := FStateMachine.Configure(tsIdle);
  Config.Ignore(ttPause);
  Assert.AreEqual(1, Config.IgnoredTriggers.Count);
end;

procedure TStateConfigurationTests.Test_IgnoreIf;
var
  Config: TStateConfiguration<TTestState, TTestTrigger>;
begin
  Config := FStateMachine.Configure(tsIdle);
  Config.IgnoreIf(ttPause,
    function(const Ctx: TObject): Boolean
    begin
      Result := True;
    end);
  Assert.IsTrue(Config.IgnoredTriggers.Count > 0);
end;

procedure TStateConfigurationTests.Test_OnEntry;
var
  Config: TStateConfiguration<TTestState, TTestTrigger>;
begin
  Config := FStateMachine.Configure(tsRunning);
  Config.OnEntry(
    procedure(const Ctx: TObject)
    begin
    end);
  Assert.AreEqual(1, Config.EntryActions.Count);
end;

procedure TStateConfigurationTests.Test_OnExit;
var
  Config: TStateConfiguration<TTestState, TTestTrigger>;
begin
  Config := FStateMachine.Configure(tsRunning);
  Config.OnExit(
    procedure(const Ctx: TObject)
    begin
    end);
  Assert.AreEqual(1, Config.ExitActions.Count);
end;

procedure TStateConfigurationTests.Test_MultipleEntryActions;
var
  Config: TStateConfiguration<TTestState, TTestTrigger>;
begin
  Config := FStateMachine.Configure(tsRunning);
  Config
    .OnEntry(procedure(const Ctx: TObject) begin end)
    .OnEntry(procedure(const Ctx: TObject) begin end)
    .OnEntry(procedure(const Ctx: TObject) begin end);
  Assert.AreEqual(3, Config.EntryActions.Count);
end;

procedure TStateConfigurationTests.Test_MultipleExitActions;
var
  Config: TStateConfiguration<TTestState, TTestTrigger>;
begin
  Config := FStateMachine.Configure(tsRunning);
  Config
    .OnExit(procedure(const Ctx: TObject) begin end)
    .OnExit(procedure(const Ctx: TObject) begin end);
  Assert.AreEqual(2, Config.ExitActions.Count);
end;

procedure TStateConfigurationTests.Test_SubstateOf;
var
  Config: TStateConfiguration<TTestState, TTestTrigger>;
begin
  Config := FStateMachine.Configure(tsPaused);
  Config.SubstateOf(tsRunning);
  Assert.IsTrue(Config.HasParent);
  Assert.AreEqual(tsRunning, Config.ParentState);
end;

procedure TStateConfigurationTests.Test_InitialTransition;
var
  Config: TStateConfiguration<TTestState, TTestTrigger>;
begin
  Config := FStateMachine.Configure(tsRunning);
  Config.InitialTransition(tsPaused);
  Assert.IsTrue(Config.HasInitialSubstate);
  Assert.AreEqual(tsPaused, Config.InitialSubstate);
end;

// ============================================================================
// TStateMachineBasicTests
// ============================================================================

procedure TStateMachineBasicTests.Setup;
begin
  FStateMachine := TStateMachine<TTestState, TTestTrigger>.Create(tsIdle);
end;

procedure TStateMachineBasicTests.TearDown;
begin
  FStateMachine.Free;
end;

procedure TStateMachineBasicTests.Test_Create_InitialState;
begin
  Assert.AreEqual(tsIdle, FStateMachine.InitialState);
  Assert.AreEqual(tsIdle, FStateMachine.CurrentState);
end;

procedure TStateMachineBasicTests.Test_CurrentState;
begin
  Assert.AreEqual(tsIdle, FStateMachine.CurrentState);
end;

procedure TStateMachineBasicTests.Test_Configure_ReturnsConfiguration;
var
  Config: TStateConfiguration<TTestState, TTestTrigger>;
begin
  Config := FStateMachine.Configure(tsIdle);
  Assert.IsNotNull(Config);
  Assert.AreEqual(tsIdle, Config.State);
end;

procedure TStateMachineBasicTests.Test_Configure_SameStateReturnsSameConfig;
var
  Config1, Config2: TStateConfiguration<TTestState, TTestTrigger>;
begin
  Config1 := FStateMachine.Configure(tsIdle);
  Config2 := FStateMachine.Configure(tsIdle);
  Assert.AreSame(Config1, Config2);
end;

procedure TStateMachineBasicTests.Test_Start_ExecutesEntryActions;
var
  EntryExecuted: Boolean;
begin
  EntryExecuted := False;
  FStateMachine.Configure(tsIdle)
    .OnEntry(
      procedure(const Ctx: TObject)
      begin
        EntryExecuted := True;
      end);
  FStateMachine.Start;
  Assert.IsTrue(EntryExecuted);
end;

procedure TStateMachineBasicTests.Test_IsStarted_BeforeStart;
begin
  Assert.IsFalse(FStateMachine.IsStarted);
end;

procedure TStateMachineBasicTests.Test_IsStarted_AfterStart;
begin
  FStateMachine.Start;
  Assert.IsTrue(FStateMachine.IsStarted);
end;

// ============================================================================
// TStateMachineTransitionTests
// ============================================================================

procedure TStateMachineTransitionTests.Setup;
begin
  FStateMachine := TStateMachine<TTestState, TTestTrigger>.Create(tsIdle);
  FEntryCount := 0;
  FExitCount := 0;
end;

procedure TStateMachineTransitionTests.TearDown;
begin
  FStateMachine.Free;
end;

procedure TStateMachineTransitionTests.Test_Fire_SimpleTransition;
begin
  FStateMachine.Configure(tsIdle).Permit(ttStart, tsRunning);
  FStateMachine.Fire(ttStart);
  Assert.AreEqual(tsRunning, FStateMachine.CurrentState);
end;

procedure TStateMachineTransitionTests.Test_Fire_MultipleTransitions;
begin
  FStateMachine.Configure(tsIdle).Permit(ttStart, tsRunning);
  FStateMachine.Configure(tsRunning).Permit(ttPause, tsPaused);
  FStateMachine.Configure(tsPaused).Permit(ttResume, tsRunning);

  FStateMachine.Fire(ttStart);
  Assert.AreEqual(tsRunning, FStateMachine.CurrentState);

  FStateMachine.Fire(ttPause);
  Assert.AreEqual(tsPaused, FStateMachine.CurrentState);

  FStateMachine.Fire(ttResume);
  Assert.AreEqual(tsRunning, FStateMachine.CurrentState);
end;

procedure TStateMachineTransitionTests.Test_Fire_ReturnsTrueOnSuccess;
var
  Result: TTransitionResult<TTestState, TTestTrigger>;
begin
  FStateMachine.Configure(tsIdle).Permit(ttStart, tsRunning);
  Result := FStateMachine.Fire(ttStart);
  Assert.IsTrue(Result.Success);
end;

procedure TStateMachineTransitionTests.Test_Fire_ExecutesExitActions;
begin
  FStateMachine.Configure(tsIdle)
    .Permit(ttStart, tsRunning)
    .OnExit(
      procedure(const Ctx: TObject)
      begin
        Inc(FExitCount);
      end);
  FStateMachine.Fire(ttStart);
  Assert.AreEqual(1, FExitCount);
end;

procedure TStateMachineTransitionTests.Test_Fire_ExecutesEntryActions;
begin
  FStateMachine.Configure(tsIdle).Permit(ttStart, tsRunning);
  FStateMachine.Configure(tsRunning)
    .OnEntry(
      procedure(const Ctx: TObject)
      begin
        Inc(FEntryCount);
      end);
  FStateMachine.Fire(ttStart);
  Assert.AreEqual(1, FEntryCount);
end;

procedure TStateMachineTransitionTests.Test_Fire_UnhandledTrigger_Throws;
begin
  FStateMachine.ThrowOnUnhandledTrigger := True;
  Assert.WillRaise(
    procedure
    begin
      FStateMachine.Fire(ttPause);
    end, EInvalidTransitionException);
end;

procedure TStateMachineTransitionTests.Test_Fire_UnhandledTrigger_NoThrow;
var
  Result: TTransitionResult<TTestState, TTestTrigger>;
begin
  FStateMachine.ThrowOnUnhandledTrigger := False;
  Result := FStateMachine.Fire(ttPause);
  Assert.IsFalse(Result.Success);
end;

procedure TStateMachineTransitionTests.Test_Fire_IgnoredTrigger;
var
  Result: TTransitionResult<TTestState, TTestTrigger>;
begin
  FStateMachine.Configure(tsIdle).Ignore(ttPause);
  Result := FStateMachine.Fire(ttPause);
  Assert.IsTrue(Result.Success);
  Assert.IsTrue(Result.WasIgnored);
  Assert.AreEqual(tsIdle, FStateMachine.CurrentState);
end;

procedure TStateMachineTransitionTests.Test_FireIfInState_CorrectState;
var
  Result: TTransitionResult<TTestState, TTestTrigger>;
begin
  FStateMachine.Configure(tsIdle).Permit(ttStart, tsRunning);
  Result := FStateMachine.FireIfInState(ttStart, tsIdle);
  Assert.IsTrue(Result.Success);
  Assert.AreEqual(tsRunning, FStateMachine.CurrentState);
end;

procedure TStateMachineTransitionTests.Test_FireIfInState_WrongState;
var
  Result: TTransitionResult<TTestState, TTestTrigger>;
begin
  FStateMachine.Configure(tsIdle).Permit(ttStart, tsRunning);
  FStateMachine.ThrowOnUnhandledTrigger := False;
  Result := FStateMachine.FireIfInState(ttStart, tsRunning);
  Assert.IsFalse(Result.Success);
  Assert.AreEqual(tsIdle, FStateMachine.CurrentState);
end;

procedure TStateMachineTransitionTests.Test_CanFire_True;
begin
  FStateMachine.Configure(tsIdle).Permit(ttStart, tsRunning);
  Assert.IsTrue(FStateMachine.CanFire(ttStart));
end;

procedure TStateMachineTransitionTests.Test_CanFire_False;
begin
  FStateMachine.Configure(tsIdle).Permit(ttStart, tsRunning);
  Assert.IsFalse(FStateMachine.CanFire(ttPause));
end;

procedure TStateMachineTransitionTests.Test_GetPermittedTriggers;
var
  Triggers: TArray<TTestTrigger>;
begin
  FStateMachine.Configure(tsIdle)
    .Permit(ttStart, tsRunning)
    .Permit(ttComplete, tsCompleted);
  Triggers := FStateMachine.GetPermittedTriggers;
  Assert.AreEqual(2, Length(Triggers));
end;

// ============================================================================
// TStateMachineGuardTests
// ============================================================================

procedure TStateMachineGuardTests.Setup;
begin
  FStateMachine := TStateMachine<TTestState, TTestTrigger>.Create(tsIdle);
  FGuardValue := True;
end;

procedure TStateMachineGuardTests.TearDown;
begin
  FStateMachine.Free;
end;

procedure TStateMachineGuardTests.Test_Guard_AllowsTransition;
begin
  FGuardValue := True;
  FStateMachine.Configure(tsIdle)
    .PermitIf(ttStart, tsRunning,
      function(const Ctx: TObject): Boolean
      begin
        Result := True;
      end);
  FStateMachine.Fire(ttStart);
  Assert.AreEqual(tsRunning, FStateMachine.CurrentState);
end;

procedure TStateMachineGuardTests.Test_Guard_BlocksTransition;
begin
  FStateMachine.ThrowOnUnhandledTrigger := False;
  FStateMachine.Configure(tsIdle)
    .PermitIf(ttStart, tsRunning,
      function(const Ctx: TObject): Boolean
      begin
        Result := False;
      end);
  FStateMachine.Fire(ttStart);
  Assert.AreEqual(tsIdle, FStateMachine.CurrentState);
end;

procedure TStateMachineGuardTests.Test_Guard_MultipleGuards;
var
  Guard1Called, Guard2Called: Boolean;
begin
  Guard1Called := False;
  Guard2Called := False;
  FStateMachine.Configure(tsIdle)
    .PermitIf(ttStart, tsRunning,
      function(const Ctx: TObject): Boolean
      begin
        Guard1Called := True;
        Result := False;
      end)
    .PermitIf(ttStart, tsPaused,
      function(const Ctx: TObject): Boolean
      begin
        Guard2Called := True;
        Result := True;
      end);
  FStateMachine.Fire(ttStart);
  Assert.IsTrue(Guard1Called);
  Assert.IsTrue(Guard2Called);
  Assert.AreEqual(tsPaused, FStateMachine.CurrentState);
end;

// ============================================================================
// TStateMachineActionTests
// ============================================================================

procedure TStateMachineActionTests.Setup;
begin
  FStateMachine := TStateMachine<TTestState, TTestTrigger>.Create(tsIdle);
  FActionLog := TList<string>.Create;
end;

procedure TStateMachineActionTests.TearDown;
begin
  FActionLog.Free;
  FStateMachine.Free;
end;

procedure TStateMachineActionTests.Test_TransitionAction_Executes;
var
  ActionExecuted: Boolean;
begin
  ActionExecuted := False;
  FStateMachine.Configure(tsIdle)
    .Permit(ttStart, tsRunning)
    .OnTransition(ttStart,
      procedure(const From, To: TTestState; const Trigger: TTestTrigger; const Ctx: TObject)
      begin
        ActionExecuted := True;
      end);
  FStateMachine.Fire(ttStart);
  Assert.IsTrue(ActionExecuted);
end;

procedure TStateMachineActionTests.Test_TransitionAction_ReceivesParameters;
var
  ReceivedFrom, ReceivedTo: TTestState;
  ReceivedTrigger: TTestTrigger;
begin
  FStateMachine.Configure(tsIdle)
    .Permit(ttStart, tsRunning)
    .OnTransition(ttStart,
      procedure(const From, To: TTestState; const Trigger: TTestTrigger; const Ctx: TObject)
      begin
        ReceivedFrom := From;
        ReceivedTo := To;
        ReceivedTrigger := Trigger;
      end);
  FStateMachine.Fire(ttStart);
  Assert.AreEqual(tsIdle, ReceivedFrom);
  Assert.AreEqual(tsRunning, ReceivedTo);
  Assert.AreEqual(ttStart, ReceivedTrigger);
end;

procedure TStateMachineActionTests.Test_EntryAction_Order;
begin
  FStateMachine.Configure(tsIdle)
    .Permit(ttStart, tsRunning)
    .OnExit(procedure(const Ctx: TObject) begin FActionLog.Add('Exit'); end);
  FStateMachine.Configure(tsRunning)
    .OnEntry(procedure(const Ctx: TObject) begin FActionLog.Add('Entry'); end);
  FStateMachine.Fire(ttStart);
  Assert.AreEqual(2, FActionLog.Count);
  Assert.AreEqual('Exit', FActionLog[0]);
  Assert.AreEqual('Entry', FActionLog[1]);
end;

procedure TStateMachineActionTests.Test_ExitAction_Order;
begin
  FStateMachine.Configure(tsIdle)
    .Permit(ttStart, tsRunning)
    .OnExit(procedure(const Ctx: TObject) begin FActionLog.Add('Exit1'); end)
    .OnExit(procedure(const Ctx: TObject) begin FActionLog.Add('Exit2'); end);
  FStateMachine.Fire(ttStart);
  Assert.AreEqual(2, FActionLog.Count);
  Assert.AreEqual('Exit1', FActionLog[0]);
  Assert.AreEqual('Exit2', FActionLog[1]);
end;

procedure TStateMachineActionTests.Test_InternalTransition_NoEntryExit;
begin
  FStateMachine.Configure(tsIdle)
    .OnEntry(procedure(const Ctx: TObject) begin FActionLog.Add('Entry'); end)
    .OnExit(procedure(const Ctx: TObject) begin FActionLog.Add('Exit'); end)
    .InternalTransition(ttStart,
      procedure(const From, To: TTestState; const Trigger: TTestTrigger; const Ctx: TObject)
      begin
        FActionLog.Add('Internal');
      end);
  FStateMachine.Fire(ttStart);
  Assert.AreEqual(1, FActionLog.Count);
  Assert.AreEqual('Internal', FActionLog[0]);
end;

procedure TStateMachineActionTests.Test_Reentry_ExecutesEntryExit;
begin
  FStateMachine.Configure(tsIdle)
    .PermitReentry(ttReset)
    .OnEntry(procedure(const Ctx: TObject) begin FActionLog.Add('Entry'); end)
    .OnExit(procedure(const Ctx: TObject) begin FActionLog.Add('Exit'); end);
  FStateMachine.Fire(ttReset);
  Assert.AreEqual(2, FActionLog.Count);
end;

// ============================================================================
// TStateMachineEventTests
// ============================================================================

procedure TStateMachineEventTests.Setup;
begin
  FStateMachine := TStateMachine<TTestState, TTestTrigger>.Create(tsIdle);
  FStateChangedCalled := False;
  FTransitionFailedCalled := False;
end;

procedure TStateMachineEventTests.TearDown;
begin
  FStateMachine.Free;
end;

procedure TStateMachineEventTests.HandleStateChanged(Sender: TObject;
  const AOldState, ANewState: TTestState; const ATrigger: TTestTrigger);
begin
  FStateChangedCalled := True;
  FOldState := AOldState;
  FNewState := ANewState;
  FLastTrigger := ATrigger;
end;

procedure TStateMachineEventTests.HandleTransitionFailed(Sender: TObject;
  const AState: TTestState; const ATrigger: TTestTrigger; const AReason: string);
begin
  FTransitionFailedCalled := True;
  FFailedState := AState;
  FFailedTrigger := ATrigger;
end;

procedure TStateMachineEventTests.Test_OnStateChanged_Fires;
begin
  FStateMachine.OnStateChanged := HandleStateChanged;
  FStateMachine.Configure(tsIdle).Permit(ttStart, tsRunning);
  FStateMachine.Fire(ttStart);
  Assert.IsTrue(FStateChangedCalled);
end;

procedure TStateMachineEventTests.Test_OnStateChanged_CorrectParameters;
begin
  FStateMachine.OnStateChanged := HandleStateChanged;
  FStateMachine.Configure(tsIdle).Permit(ttStart, tsRunning);
  FStateMachine.Fire(ttStart);
  Assert.AreEqual(tsIdle, FOldState);
  Assert.AreEqual(tsRunning, FNewState);
  Assert.AreEqual(ttStart, FLastTrigger);
end;

procedure TStateMachineEventTests.Test_OnTransitionFailed_Fires;
begin
  FStateMachine.ThrowOnUnhandledTrigger := False;
  FStateMachine.OnTransitionFailed := HandleTransitionFailed;
  FStateMachine.Configure(tsIdle)
    .PermitIf(ttStart, tsRunning,
      function(const Ctx: TObject): Boolean
      begin
        Result := False;
      end);
  FStateMachine.Fire(ttStart);
  Assert.IsTrue(FTransitionFailedCalled);
end;

// ============================================================================
// TStateMachineHistoryTests
// ============================================================================

procedure TStateMachineHistoryTests.Setup;
begin
  FStateMachine := TStateMachine<TTestState, TTestTrigger>.Create(tsIdle);
end;

procedure TStateMachineHistoryTests.TearDown;
begin
  FStateMachine.Free;
end;

procedure TStateMachineHistoryTests.Test_GetHistory_Empty;
var
  History: TArray<TStateHistoryEntry<TTestState, TTestTrigger>>;
begin
  History := FStateMachine.GetHistory;
  Assert.AreEqual(0, Length(History));
end;

procedure TStateMachineHistoryTests.Test_GetHistory_AfterTransitions;
var
  History: TArray<TStateHistoryEntry<TTestState, TTestTrigger>>;
begin
  FStateMachine.Configure(tsIdle).Permit(ttStart, tsRunning);
  FStateMachine.Configure(tsRunning).Permit(ttPause, tsPaused);
  FStateMachine.Fire(ttStart);
  FStateMachine.Fire(ttPause);
  History := FStateMachine.GetHistory;
  Assert.AreEqual(2, Length(History));
end;

procedure TStateMachineHistoryTests.Test_ClearHistory;
var
  History: TArray<TStateHistoryEntry<TTestState, TTestTrigger>>;
begin
  FStateMachine.Configure(tsIdle).Permit(ttStart, tsRunning);
  FStateMachine.Fire(ttStart);
  FStateMachine.ClearHistory;
  History := FStateMachine.GetHistory;
  Assert.AreEqual(0, Length(History));
end;

procedure TStateMachineHistoryTests.Test_MaxHistorySize;
var
  History: TArray<TStateHistoryEntry<TTestState, TTestTrigger>>;
begin
  FStateMachine.MaxHistorySize := 2;
  FStateMachine.Configure(tsIdle).Permit(ttStart, tsRunning);
  FStateMachine.Configure(tsRunning)
    .Permit(ttPause, tsPaused)
    .Permit(ttStop, tsStopped);
  FStateMachine.Configure(tsPaused).Permit(ttResume, tsRunning);

  FStateMachine.Fire(ttStart);
  FStateMachine.Fire(ttPause);
  FStateMachine.Fire(ttResume);

  History := FStateMachine.GetHistory;
  Assert.IsTrue(Length(History) <= 2);
end;

// ============================================================================
// TStateMachineResetTests
// ============================================================================

procedure TStateMachineResetTests.Setup;
begin
  FStateMachine := TStateMachine<TTestState, TTestTrigger>.Create(tsIdle);
end;

procedure TStateMachineResetTests.TearDown;
begin
  FStateMachine.Free;
end;

procedure TStateMachineResetTests.Test_Reset_ReturnToInitialState;
begin
  FStateMachine.Configure(tsIdle).Permit(ttStart, tsRunning);
  FStateMachine.Fire(ttStart);
  Assert.AreEqual(tsRunning, FStateMachine.CurrentState);
  FStateMachine.Reset;
  Assert.AreEqual(tsIdle, FStateMachine.CurrentState);
end;

procedure TStateMachineResetTests.Test_Reset_AfterMultipleTransitions;
begin
  FStateMachine.Configure(tsIdle).Permit(ttStart, tsRunning);
  FStateMachine.Configure(tsRunning).Permit(ttPause, tsPaused);
  FStateMachine.Fire(ttStart);
  FStateMachine.Fire(ttPause);
  Assert.AreEqual(tsPaused, FStateMachine.CurrentState);
  FStateMachine.Reset;
  Assert.AreEqual(tsIdle, FStateMachine.CurrentState);
end;

// ============================================================================
// TStateMachineIsInTests
// ============================================================================

procedure TStateMachineIsInTests.Setup;
begin
  FStateMachine := TStateMachine<TTestState, TTestTrigger>.Create(tsIdle);
end;

procedure TStateMachineIsInTests.TearDown;
begin
  FStateMachine.Free;
end;

procedure TStateMachineIsInTests.Test_IsIn_CurrentState;
begin
  Assert.IsTrue(FStateMachine.IsIn(tsIdle));
end;

procedure TStateMachineIsInTests.Test_IsIn_NotCurrentState;
begin
  Assert.IsFalse(FStateMachine.IsIn(tsRunning));
end;

// ============================================================================
// TStateMachineContextTests
// ============================================================================

procedure TStateMachineContextTests.Setup;
begin
  FStateMachine := TStateMachine<TTestState, TTestTrigger>.Create(tsIdle);
end;

procedure TStateMachineContextTests.TearDown;
begin
  FStateMachine.Free;
end;

procedure TStateMachineContextTests.Test_Context_SetGet;
var
  Ctx: TTestContext;
begin
  Ctx := TTestContext.Create;
  try
    Ctx.Value := 42;
    FStateMachine.Context := Ctx;
    Assert.AreSame(Ctx, FStateMachine.Context);
  finally
    Ctx.Free;
  end;
end;

procedure TStateMachineContextTests.Test_Context_OwnsContext;
var
  Ctx: TTestContext;
begin
  Ctx := TTestContext.Create;
  FStateMachine.Context := Ctx;
  FStateMachine.OwnsContext := True;
  // Context will be freed when state machine is freed
  Assert.IsTrue(FStateMachine.OwnsContext);
end;

procedure TStateMachineContextTests.Test_Context_InGuard;
var
  Ctx: TTestContext;
  GuardCalled: Boolean;
begin
  Ctx := TTestContext.Create;
  try
    Ctx.Value := 100;
    FStateMachine.Context := Ctx;
    GuardCalled := False;

    FStateMachine.Configure(tsIdle)
      .PermitIf(ttStart, tsRunning,
        function(const C: TObject): Boolean
        begin
          GuardCalled := True;
          Result := (C as TTestContext).Value = 100;
        end);

    FStateMachine.Fire(ttStart);
    Assert.IsTrue(GuardCalled);
    Assert.AreEqual(tsRunning, FStateMachine.CurrentState);
  finally
    Ctx.Free;
  end;
end;

procedure TStateMachineContextTests.Test_Context_InAction;
var
  Ctx: TTestContext;
  ActionCalled: Boolean;
begin
  Ctx := TTestContext.Create;
  try
    Ctx.Value := 50;
    FStateMachine.Context := Ctx;
    ActionCalled := False;

    FStateMachine.Configure(tsIdle)
      .Permit(ttStart, tsRunning)
      .OnExit(
        procedure(const C: TObject)
        begin
          ActionCalled := True;
          (C as TTestContext).Value := 999;
        end);

    FStateMachine.Fire(ttStart);
    Assert.IsTrue(ActionCalled);
    Assert.AreEqual(999, Ctx.Value);
  finally
    Ctx.Free;
  end;
end;

// ============================================================================
// TStateMachineBuilderTests
// ============================================================================

procedure TStateMachineBuilderTests.Test_Builder_Create;
var
  Builder: TStateMachineBuilder<TTestState, TTestTrigger>;
begin
  Builder := TStateMachineBuilder<TTestState, TTestTrigger>.Create(tsIdle);
  try
    Assert.IsNotNull(Builder);
  finally
    Builder.Free;
  end;
end;

procedure TStateMachineBuilderTests.Test_Builder_State;
var
  Builder: TStateMachineBuilder<TTestState, TTestTrigger>;
  Result: TStateMachineBuilder<TTestState, TTestTrigger>;
begin
  Builder := TStateMachineBuilder<TTestState, TTestTrigger>.Create(tsIdle);
  try
    Result := Builder.State(tsRunning);
    Assert.AreSame(Builder, Result);
  finally
    Builder.Free;
  end;
end;

procedure TStateMachineBuilderTests.Test_Builder_Permit;
var
  Builder: TStateMachineBuilder<TTestState, TTestTrigger>;
begin
  Builder := TStateMachineBuilder<TTestState, TTestTrigger>.Create(tsIdle);
  try
    Builder.State(tsIdle).Permit(ttStart, tsRunning);
    Assert.IsTrue(True); // No exception
  finally
    Builder.Free;
  end;
end;

procedure TStateMachineBuilderTests.Test_Builder_PermitIf;
var
  Builder: TStateMachineBuilder<TTestState, TTestTrigger>;
begin
  Builder := TStateMachineBuilder<TTestState, TTestTrigger>.Create(tsIdle);
  try
    Builder.State(tsIdle).PermitIf(ttStart, tsRunning,
      function(const Ctx: TObject): Boolean
      begin
        Result := True;
      end);
    Assert.IsTrue(True);
  finally
    Builder.Free;
  end;
end;

procedure TStateMachineBuilderTests.Test_Builder_OnEntry;
var
  Builder: TStateMachineBuilder<TTestState, TTestTrigger>;
begin
  Builder := TStateMachineBuilder<TTestState, TTestTrigger>.Create(tsIdle);
  try
    Builder.State(tsIdle).OnEntry(
      procedure(const Ctx: TObject)
      begin
      end);
    Assert.IsTrue(True);
  finally
    Builder.Free;
  end;
end;

procedure TStateMachineBuilderTests.Test_Builder_OnExit;
var
  Builder: TStateMachineBuilder<TTestState, TTestTrigger>;
begin
  Builder := TStateMachineBuilder<TTestState, TTestTrigger>.Create(tsIdle);
  try
    Builder.State(tsIdle).OnExit(
      procedure(const Ctx: TObject)
      begin
      end);
    Assert.IsTrue(True);
  finally
    Builder.Free;
  end;
end;

procedure TStateMachineBuilderTests.Test_Builder_Ignore;
var
  Builder: TStateMachineBuilder<TTestState, TTestTrigger>;
begin
  Builder := TStateMachineBuilder<TTestState, TTestTrigger>.Create(tsIdle);
  try
    Builder.State(tsIdle).Ignore(ttPause);
    Assert.IsTrue(True);
  finally
    Builder.Free;
  end;
end;

procedure TStateMachineBuilderTests.Test_Builder_SubstateOf;
var
  Builder: TStateMachineBuilder<TTestState, TTestTrigger>;
begin
  Builder := TStateMachineBuilder<TTestState, TTestTrigger>.Create(tsIdle);
  try
    Builder.State(tsPaused).SubstateOf(tsRunning);
    Assert.IsTrue(True);
  finally
    Builder.Free;
  end;
end;

procedure TStateMachineBuilderTests.Test_Builder_WithContext;
var
  Builder: TStateMachineBuilder<TTestState, TTestTrigger>;
  Ctx: TTestContext;
begin
  Builder := TStateMachineBuilder<TTestState, TTestTrigger>.Create(tsIdle);
  Ctx := TTestContext.Create;
  try
    Builder.WithContext(Ctx, False);
    Assert.IsTrue(True);
  finally
    Builder.Free;
    Ctx.Free;
  end;
end;

procedure TStateMachineBuilderTests.Test_Builder_Build;
var
  Builder: TStateMachineBuilder<TTestState, TTestTrigger>;
  SM: TStateMachine<TTestState, TTestTrigger>;
begin
  Builder := TStateMachineBuilder<TTestState, TTestTrigger>.Create(tsIdle);
  try
    SM := Builder.Build;
    try
      Assert.IsNotNull(SM);
      Assert.AreEqual(tsIdle, SM.CurrentState);
    finally
      SM.Free;
    end;
  finally
    Builder.Free;
  end;
end;

procedure TStateMachineBuilderTests.Test_Builder_FluentChain;
var
  Builder: TStateMachineBuilder<TTestState, TTestTrigger>;
  SM: TStateMachine<TTestState, TTestTrigger>;
begin
  Builder := TStateMachineBuilder<TTestState, TTestTrigger>.Create(tsIdle);
  try
    SM := Builder
      .State(tsIdle)
        .Permit(ttStart, tsRunning)
        .OnEntry(procedure(const Ctx: TObject) begin end)
      .State(tsRunning)
        .Permit(ttStop, tsStopped)
        .Permit(ttPause, tsPaused)
      .Build;
    try
      Assert.IsNotNull(SM);
      SM.Fire(ttStart);
      Assert.AreEqual(tsRunning, SM.CurrentState);
    finally
      SM.Free;
    end;
  finally
    Builder.Free;
  end;
end;

// ============================================================================
// TStringStateMachineTests
// ============================================================================

procedure TStringStateMachineTests.Setup;
begin
  FStateMachine := TStringStateMachine.Create('Idle');
end;

procedure TStringStateMachineTests.TearDown;
begin
  FStateMachine.Free;
end;

procedure TStringStateMachineTests.Test_StringStates;
begin
  Assert.AreEqual('Idle', FStateMachine.CurrentState);
end;

procedure TStringStateMachineTests.Test_StringTriggers;
begin
  FStateMachine.Configure('Idle').Permit('Start', 'Running');
  Assert.IsTrue(FStateMachine.CanFire('Start'));
end;

procedure TStringStateMachineTests.Test_StringTransitions;
begin
  FStateMachine.Configure('Idle').Permit('Start', 'Running');
  FStateMachine.Configure('Running').Permit('Stop', 'Stopped');

  FStateMachine.Fire('Start');
  Assert.AreEqual('Running', FStateMachine.CurrentState);

  FStateMachine.Fire('Stop');
  Assert.AreEqual('Stopped', FStateMachine.CurrentState);
end;

// ============================================================================
// TStateMachineExceptionTests
// ============================================================================

procedure TStateMachineExceptionTests.Setup;
begin
  FStateMachine := TStateMachine<TTestState, TTestTrigger>.Create(tsIdle);
  FStateMachine.ThrowOnUnhandledTrigger := True;
end;

procedure TStateMachineExceptionTests.TearDown;
begin
  FStateMachine.Free;
end;

procedure TStateMachineExceptionTests.Test_InvalidTransition_Exception;
begin
  Assert.WillRaise(
    procedure
    begin
      FStateMachine.Fire(ttStart); // No transition configured
    end, Exception);
end;

procedure TStateMachineExceptionTests.Test_InvalidTransition_ExceptionType;
begin
  Assert.WillRaise(
    procedure
    begin
      FStateMachine.Fire(ttPause);
    end, EInvalidTransitionException);
end;

initialization
  TDUnitX.RegisterTestFixture(TTransitionResultTests);
  TDUnitX.RegisterTestFixture(TStateConfigurationTests);
  TDUnitX.RegisterTestFixture(TStateMachineBasicTests);
  TDUnitX.RegisterTestFixture(TStateMachineTransitionTests);
  TDUnitX.RegisterTestFixture(TStateMachineGuardTests);
  TDUnitX.RegisterTestFixture(TStateMachineActionTests);
  TDUnitX.RegisterTestFixture(TStateMachineEventTests);
  TDUnitX.RegisterTestFixture(TStateMachineHistoryTests);
  TDUnitX.RegisterTestFixture(TStateMachineResetTests);
  TDUnitX.RegisterTestFixture(TStateMachineIsInTests);
  TDUnitX.RegisterTestFixture(TStateMachineContextTests);
  TDUnitX.RegisterTestFixture(TStateMachineBuilderTests);
  TDUnitX.RegisterTestFixture(TStringStateMachineTests);
  TDUnitX.RegisterTestFixture(TStateMachineExceptionTests);

end.
