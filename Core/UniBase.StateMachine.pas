unit UniBase.StateMachine;

{*******************************************************************************
  UniBase State Machine
  A flexible finite state machine implementation with:
  - Fluent configuration API
  - State entry/exit actions
  - Transition guards (conditions)
  - Transition actions
  - Event-driven transitions
  - Hierarchical states (substates)
  - State history
  - Persistence support
  
  Author: UniBase Team
  Created: 2025-11-28
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.Rtti, System.SyncObjs;

type
  EStateMachineException = class(Exception);
  EInvalidTransitionException = class(EStateMachineException);
  EInvalidStateException = class(EStateMachineException);

  TStateMachine<TState, TTrigger> = class;

  /// <summary>Guard function type - returns True if transition is allowed</summary>
  TGuardFunc<TState, TTrigger> = reference to function(const AContext: TObject): Boolean;
  
  /// <summary>Action procedure type for transitions and state entry/exit</summary>
  TStateAction<TState, TTrigger> = reference to procedure(const AContext: TObject);
  
  /// <summary>Transition action with from/to state info</summary>
  TTransitionAction<TState, TTrigger> = reference to procedure(
    const AFromState, AToState: TState; 
    const ATrigger: TTrigger;
    const AContext: TObject);

  /// <summary>State change event handler</summary>
  TStateChangedEvent<TState, TTrigger> = procedure(Sender: TObject; 
    const AOldState, ANewState: TState; const ATrigger: TTrigger) of object;
  
  /// <summary>Transition failed event handler</summary>
  TTransitionFailedEvent<TState, TTrigger> = procedure(Sender: TObject;
    const AState: TState; const ATrigger: TTrigger; const AReason: string) of object;

  /// <summary>Transition definition</summary>
  TTransition<TState, TTrigger> = class
  private
    FTrigger: TTrigger;
    FTargetState: TState;
    FGuard: TGuardFunc<TState, TTrigger>;
    FGuardDescription: string;
    FAction: TTransitionAction<TState, TTrigger>;
    FIsInternal: Boolean;
    FIsReentry: Boolean;
  public
    property Trigger: TTrigger read FTrigger write FTrigger;
    property TargetState: TState read FTargetState write FTargetState;
    property Guard: TGuardFunc<TState, TTrigger> read FGuard write FGuard;
    property GuardDescription: string read FGuardDescription write FGuardDescription;
    property Action: TTransitionAction<TState, TTrigger> read FAction write FAction;
    property IsInternal: Boolean read FIsInternal write FIsInternal;
    property IsReentry: Boolean read FIsReentry write FIsReentry;
  end;

  /// <summary>State configuration</summary>
  TStateConfiguration<TState, TTrigger> = class
  private
    FStateMachine: TStateMachine<TState, TTrigger>;
    FState: TState;
    FTransitions: TObjectList<TTransition<TState, TTrigger>>;
    FEntryActions: TList<TStateAction<TState, TTrigger>>;
    FExitActions: TList<TStateAction<TState, TTrigger>>;
    FParentState: TState;
    FHasParent: Boolean;
    FInitialSubstate: TState;
    FHasInitialSubstate: Boolean;
    FIgnoredTriggers: TList<TTrigger>;
  public
    constructor Create(AStateMachine: TStateMachine<TState, TTrigger>; const AState: TState);
    destructor Destroy; override;
    
    /// <summary>Configure transition to another state on trigger</summary>
    function Permit(const ATrigger: TTrigger; const ATargetState: TState): TStateConfiguration<TState, TTrigger>;
    
    /// <summary>Configure conditional transition</summary>
    function PermitIf(const ATrigger: TTrigger; const ATargetState: TState;
      AGuard: TGuardFunc<TState, TTrigger>; const AGuardDescription: string = ''): TStateConfiguration<TState, TTrigger>;
    
    /// <summary>Configure reentry transition (exits and re-enters same state)</summary>
    function PermitReentry(const ATrigger: TTrigger): TStateConfiguration<TState, TTrigger>;
    
    /// <summary>Configure conditional reentry</summary>
    function PermitReentryIf(const ATrigger: TTrigger; 
      AGuard: TGuardFunc<TState, TTrigger>; const AGuardDescription: string = ''): TStateConfiguration<TState, TTrigger>;
    
    /// <summary>Configure internal transition (no state change, no entry/exit)</summary>
    function InternalTransition(const ATrigger: TTrigger;
      AAction: TTransitionAction<TState, TTrigger>): TStateConfiguration<TState, TTrigger>;
    
    /// <summary>Configure internal transition with guard</summary>
    function InternalTransitionIf(const ATrigger: TTrigger;
      AGuard: TGuardFunc<TState, TTrigger>;
      AAction: TTransitionAction<TState, TTrigger>): TStateConfiguration<TState, TTrigger>;
    
    /// <summary>Ignore trigger in this state</summary>
    function Ignore(const ATrigger: TTrigger): TStateConfiguration<TState, TTrigger>;
    
    /// <summary>Ignore trigger conditionally</summary>
    function IgnoreIf(const ATrigger: TTrigger;
      AGuard: TGuardFunc<TState, TTrigger>): TStateConfiguration<TState, TTrigger>;
    
    /// <summary>Add action to execute on state entry</summary>
    function OnEntry(AAction: TStateAction<TState, TTrigger>): TStateConfiguration<TState, TTrigger>;
    
    /// <summary>Add action to execute on state exit</summary>
    function OnExit(AAction: TStateAction<TState, TTrigger>): TStateConfiguration<TState, TTrigger>;
    
    /// <summary>Add transition action</summary>
    function OnTransition(const ATrigger: TTrigger; 
      AAction: TTransitionAction<TState, TTrigger>): TStateConfiguration<TState, TTrigger>;
    
    /// <summary>Set parent state (for hierarchical state machines)</summary>
    function SubstateOf(const AParentState: TState): TStateConfiguration<TState, TTrigger>;
    
    /// <summary>Set initial substate</summary>
    function InitialTransition(const ASubstate: TState): TStateConfiguration<TState, TTrigger>;
    
    property State: TState read FState;
    property Transitions: TObjectList<TTransition<TState, TTrigger>> read FTransitions;
    property EntryActions: TList<TStateAction<TState, TTrigger>> read FEntryActions;
    property ExitActions: TList<TStateAction<TState, TTrigger>> read FExitActions;
    property ParentState: TState read FParentState;
    property HasParent: Boolean read FHasParent;
    property InitialSubstate: TState read FInitialSubstate;
    property HasInitialSubstate: Boolean read FHasInitialSubstate;
    property IgnoredTriggers: TList<TTrigger> read FIgnoredTriggers;
  end;

  /// <summary>Transition result</summary>
  TTransitionResult<TState, TTrigger> = record
    Success: Boolean;
    FromState: TState;
    ToState: TState;
    Trigger: TTrigger;
    ErrorMessage: string;
    WasIgnored: Boolean;
    
    class function CreateSuccess(const AFromState, AToState: TState; const ATrigger: TTrigger): TTransitionResult<TState, TTrigger>; static;
    class function CreateFailure(const AFromState: TState; const ATrigger: TTrigger; const AErrorMessage: string): TTransitionResult<TState, TTrigger>; static;
    class function CreateIgnored(const AState: TState; const ATrigger: TTrigger): TTransitionResult<TState, TTrigger>; static;
  end;

  /// <summary>State history entry</summary>
  TStateHistoryEntry<TState, TTrigger> = record
    State: TState;
    Trigger: TTrigger;
    Timestamp: TDateTime;
    Context: TObject;
  end;

  /// <summary>Finite State Machine</summary>
  TStateMachine<TState, TTrigger> = class
  private
    FCurrentState: TState;
    FInitialState: TState;
    FStates: TObjectDictionary<TState, TStateConfiguration<TState, TTrigger>>;
    FContext: TObject;
    FOwnsContext: Boolean;
    FLock: TCriticalSection;
    FHistory: TList<TStateHistoryEntry<TState, TTrigger>>;
    FMaxHistorySize: Integer;
    FOnStateChanged: TStateChangedEvent<TState, TTrigger>;
    FOnTransitionFailed: TTransitionFailedEvent<TState, TTrigger>;
    FOnUnhandledTrigger: TTransitionFailedEvent<TState, TTrigger>;
    FThrowOnUnhandledTrigger: Boolean;
    FIsStarted: Boolean;
    
    function GetState(const AState: TState): TStateConfiguration<TState, TTrigger>;
    function FindTransition(const ATrigger: TTrigger): TTransition<TState, TTrigger>;
    procedure ExecuteEntryActions(const AState: TState);
    procedure ExecuteExitActions(const AState: TState);
    procedure AddToHistory(const AState: TState; const ATrigger: TTrigger);
    function GetSuperstate(const AState: TState): TState;
    function IsInState(const AState: TState; const ATargetState: TState): Boolean;
    function GetCurrentConfig: TStateConfiguration<TState, TTrigger>;
  public
    constructor Create(const AInitialState: TState);
    destructor Destroy; override;
    
    /// <summary>Configure a state</summary>
    function Configure(const AState: TState): TStateConfiguration<TState, TTrigger>;
    
    /// <summary>Start the state machine (executes initial state entry actions)</summary>
    procedure Start;
    
    /// <summary>Fire a trigger to potentially transition states</summary>
    function Fire(const ATrigger: TTrigger): TTransitionResult<TState, TTrigger>;
    
    /// <summary>Fire trigger if in specific state</summary>
    function FireIfInState(const ATrigger: TTrigger; const ARequiredState: TState): TTransitionResult<TState, TTrigger>;
    
    /// <summary>Check if trigger can be fired in current state</summary>
    function CanFire(const ATrigger: TTrigger): Boolean;
    
    /// <summary>Get all permitted triggers for current state</summary>
    function GetPermittedTriggers: TArray<TTrigger>;
    
    /// <summary>Check if currently in a state (including substates)</summary>
    function IsIn(const AState: TState): Boolean;
    
    /// <summary>Reset to initial state</summary>
    procedure Reset;
    
    /// <summary>Get state history</summary>
    function GetHistory: TArray<TStateHistoryEntry<TState, TTrigger>>;
    
    /// <summary>Clear state history</summary>
    procedure ClearHistory;
    
    /// <summary>Export state machine as DOT graph</summary>
    function ToDotGraph: string;
    
    /// <summary>Export current state configuration as JSON</summary>
    function ToJSON: string;
    
    /// <summary>Restore state from JSON</summary>
    procedure FromJSON(const AJSON: string);
    
    property CurrentState: TState read FCurrentState;
    property InitialState: TState read FInitialState;
    property Context: TObject read FContext write FContext;
    property OwnsContext: Boolean read FOwnsContext write FOwnsContext;
    property MaxHistorySize: Integer read FMaxHistorySize write FMaxHistorySize;
    property ThrowOnUnhandledTrigger: Boolean read FThrowOnUnhandledTrigger write FThrowOnUnhandledTrigger;
    property IsStarted: Boolean read FIsStarted;
    
    property OnStateChanged: TStateChangedEvent<TState, TTrigger> read FOnStateChanged write FOnStateChanged;
    property OnTransitionFailed: TTransitionFailedEvent<TState, TTrigger> read FOnTransitionFailed write FOnTransitionFailed;
    property OnUnhandledTrigger: TTransitionFailedEvent<TState, TTrigger> read FOnUnhandledTrigger write FOnUnhandledTrigger;
  end;

  /// <summary>State machine builder for fluent construction</summary>
  TStateMachineBuilder<TState, TTrigger> = class
  private
    FStateMachine: TStateMachine<TState, TTrigger>;
    FCurrentConfig: TStateConfiguration<TState, TTrigger>;
  public
    constructor Create(const AInitialState: TState);
    
    /// <summary>Configure a state</summary>
    function State(const AState: TState): TStateMachineBuilder<TState, TTrigger>;
    
    /// <summary>Add permitted transition</summary>
    function Permit(const ATrigger: TTrigger; const ATargetState: TState): TStateMachineBuilder<TState, TTrigger>;
    
    /// <summary>Add conditional transition</summary>
    function PermitIf(const ATrigger: TTrigger; const ATargetState: TState;
      AGuard: TGuardFunc<TState, TTrigger>): TStateMachineBuilder<TState, TTrigger>;
    
    /// <summary>Add entry action</summary>
    function OnEntry(AAction: TStateAction<TState, TTrigger>): TStateMachineBuilder<TState, TTrigger>;
    
    /// <summary>Add exit action</summary>
    function OnExit(AAction: TStateAction<TState, TTrigger>): TStateMachineBuilder<TState, TTrigger>;
    
    /// <summary>Ignore trigger</summary>
    function Ignore(const ATrigger: TTrigger): TStateMachineBuilder<TState, TTrigger>;
    
    /// <summary>Set as substate</summary>
    function SubstateOf(const AParentState: TState): TStateMachineBuilder<TState, TTrigger>;
    
    /// <summary>Set context object</summary>
    function WithContext(AContext: TObject; AOwnsContext: Boolean = False): TStateMachineBuilder<TState, TTrigger>;
    
    /// <summary>Set state changed handler</summary>
    function OnStateChanged(AHandler: TStateChangedEvent<TState, TTrigger>): TStateMachineBuilder<TState, TTrigger>;
    
    /// <summary>Build and return the state machine</summary>
    function Build: TStateMachine<TState, TTrigger>;
  end;

  /// <summary>Common state type for simple state machines</summary>
  TSimpleState = (ssIdle, ssRunning, ssPaused, ssStopped, ssCompleted, ssError);
  
  /// <summary>Common trigger type for simple state machines</summary>
  TSimpleTrigger = (stStart, stPause, stResume, stStop, stComplete, stReset, stError);

  /// <summary>Type alias for simple string-based state machine</summary>
  TStringStateMachine = TStateMachine<string, string>;

implementation

uses
  System.JSON, System.TypInfo;

{ TTransitionResult<TState, TTrigger> }

class function TTransitionResult<TState, TTrigger>.CreateSuccess(
  const AFromState, AToState: TState; const ATrigger: TTrigger): TTransitionResult<TState, TTrigger>;
begin
  Result.Success := True;
  Result.FromState := AFromState;
  Result.ToState := AToState;
  Result.Trigger := ATrigger;
  Result.ErrorMessage := '';
  Result.WasIgnored := False;
end;

class function TTransitionResult<TState, TTrigger>.CreateFailure(
  const AFromState: TState; const ATrigger: TTrigger; 
  const AErrorMessage: string): TTransitionResult<TState, TTrigger>;
begin
  Result.Success := False;
  Result.FromState := AFromState;
  Result.ToState := AFromState;
  Result.Trigger := ATrigger;
  Result.ErrorMessage := AErrorMessage;
  Result.WasIgnored := False;
end;

class function TTransitionResult<TState, TTrigger>.CreateIgnored(
  const AState: TState; const ATrigger: TTrigger): TTransitionResult<TState, TTrigger>;
begin
  Result.Success := True;
  Result.FromState := AState;
  Result.ToState := AState;
  Result.Trigger := ATrigger;
  Result.ErrorMessage := '';
  Result.WasIgnored := True;
end;

{ TStateConfiguration<TState, TTrigger> }

constructor TStateConfiguration<TState, TTrigger>.Create(
  AStateMachine: TStateMachine<TState, TTrigger>; const AState: TState);
begin
  inherited Create;
  FStateMachine := AStateMachine;
  FState := AState;
  FTransitions := TObjectList<TTransition<TState, TTrigger>>.Create(True);
  FEntryActions := TList<TStateAction<TState, TTrigger>>.Create;
  FExitActions := TList<TStateAction<TState, TTrigger>>.Create;
  FIgnoredTriggers := TList<TTrigger>.Create;
  FHasParent := False;
  FHasInitialSubstate := False;
end;

destructor TStateConfiguration<TState, TTrigger>.Destroy;
begin
  FIgnoredTriggers.Free;
  FExitActions.Free;
  FEntryActions.Free;
  FTransitions.Free;
  inherited;
end;

function TStateConfiguration<TState, TTrigger>.Permit(const ATrigger: TTrigger; 
  const ATargetState: TState): TStateConfiguration<TState, TTrigger>;
var
  LTransition: TTransition<TState, TTrigger>;
begin
  LTransition := TTransition<TState, TTrigger>.Create;
  LTransition.Trigger := ATrigger;
  LTransition.TargetState := ATargetState;
  LTransition.IsInternal := False;
  LTransition.IsReentry := False;
  FTransitions.Add(LTransition);
  Result := Self;
end;

function TStateConfiguration<TState, TTrigger>.PermitIf(const ATrigger: TTrigger;
  const ATargetState: TState; AGuard: TGuardFunc<TState, TTrigger>;
  const AGuardDescription: string): TStateConfiguration<TState, TTrigger>;
var
  LTransition: TTransition<TState, TTrigger>;
begin
  LTransition := TTransition<TState, TTrigger>.Create;
  LTransition.Trigger := ATrigger;
  LTransition.TargetState := ATargetState;
  LTransition.Guard := AGuard;
  LTransition.GuardDescription := AGuardDescription;
  LTransition.IsInternal := False;
  LTransition.IsReentry := False;
  FTransitions.Add(LTransition);
  Result := Self;
end;

function TStateConfiguration<TState, TTrigger>.PermitReentry(
  const ATrigger: TTrigger): TStateConfiguration<TState, TTrigger>;
var
  LTransition: TTransition<TState, TTrigger>;
begin
  LTransition := TTransition<TState, TTrigger>.Create;
  LTransition.Trigger := ATrigger;
  LTransition.TargetState := FState;
  LTransition.IsInternal := False;
  LTransition.IsReentry := True;
  FTransitions.Add(LTransition);
  Result := Self;
end;

function TStateConfiguration<TState, TTrigger>.PermitReentryIf(const ATrigger: TTrigger;
  AGuard: TGuardFunc<TState, TTrigger>;
  const AGuardDescription: string): TStateConfiguration<TState, TTrigger>;
var
  LTransition: TTransition<TState, TTrigger>;
begin
  LTransition := TTransition<TState, TTrigger>.Create;
  LTransition.Trigger := ATrigger;
  LTransition.TargetState := FState;
  LTransition.Guard := AGuard;
  LTransition.GuardDescription := AGuardDescription;
  LTransition.IsInternal := False;
  LTransition.IsReentry := True;
  FTransitions.Add(LTransition);
  Result := Self;
end;

function TStateConfiguration<TState, TTrigger>.InternalTransition(const ATrigger: TTrigger;
  AAction: TTransitionAction<TState, TTrigger>): TStateConfiguration<TState, TTrigger>;
var
  LTransition: TTransition<TState, TTrigger>;
begin
  LTransition := TTransition<TState, TTrigger>.Create;
  LTransition.Trigger := ATrigger;
  LTransition.TargetState := FState;
  LTransition.Action := AAction;
  LTransition.IsInternal := True;
  LTransition.IsReentry := False;
  FTransitions.Add(LTransition);
  Result := Self;
end;

function TStateConfiguration<TState, TTrigger>.InternalTransitionIf(const ATrigger: TTrigger;
  AGuard: TGuardFunc<TState, TTrigger>;
  AAction: TTransitionAction<TState, TTrigger>): TStateConfiguration<TState, TTrigger>;
var
  LTransition: TTransition<TState, TTrigger>;
begin
  LTransition := TTransition<TState, TTrigger>.Create;
  LTransition.Trigger := ATrigger;
  LTransition.TargetState := FState;
  LTransition.Guard := AGuard;
  LTransition.Action := AAction;
  LTransition.IsInternal := True;
  LTransition.IsReentry := False;
  FTransitions.Add(LTransition);
  Result := Self;
end;

function TStateConfiguration<TState, TTrigger>.Ignore(
  const ATrigger: TTrigger): TStateConfiguration<TState, TTrigger>;
begin
  FIgnoredTriggers.Add(ATrigger);
  Result := Self;
end;

function TStateConfiguration<TState, TTrigger>.IgnoreIf(const ATrigger: TTrigger;
  AGuard: TGuardFunc<TState, TTrigger>): TStateConfiguration<TState, TTrigger>;
var
  LTransition: TTransition<TState, TTrigger>;
begin
  // Implement as internal transition that does nothing but has a guard
  LTransition := TTransition<TState, TTrigger>.Create;
  LTransition.Trigger := ATrigger;
  LTransition.TargetState := FState;
  LTransition.Guard := AGuard;
  LTransition.IsInternal := True;
  FTransitions.Add(LTransition);
  
  // Also add to ignored list for triggers without guard
  FIgnoredTriggers.Add(ATrigger);
  Result := Self;
end;

function TStateConfiguration<TState, TTrigger>.OnEntry(
  AAction: TStateAction<TState, TTrigger>): TStateConfiguration<TState, TTrigger>;
begin
  FEntryActions.Add(AAction);
  Result := Self;
end;

function TStateConfiguration<TState, TTrigger>.OnExit(
  AAction: TStateAction<TState, TTrigger>): TStateConfiguration<TState, TTrigger>;
begin
  FExitActions.Add(AAction);
  Result := Self;
end;

function TStateConfiguration<TState, TTrigger>.OnTransition(const ATrigger: TTrigger;
  AAction: TTransitionAction<TState, TTrigger>): TStateConfiguration<TState, TTrigger>;
var
  LTransition: TTransition<TState, TTrigger>;
begin
  // Find existing transition and add action
  for LTransition in FTransitions do
  begin
    if CompareMem(@LTransition.Trigger, @ATrigger, SizeOf(TTrigger)) then
    begin
      LTransition.Action := AAction;
      Break;
    end;
  end;
  Result := Self;
end;

function TStateConfiguration<TState, TTrigger>.SubstateOf(
  const AParentState: TState): TStateConfiguration<TState, TTrigger>;
begin
  FParentState := AParentState;
  FHasParent := True;
  Result := Self;
end;

function TStateConfiguration<TState, TTrigger>.InitialTransition(
  const ASubstate: TState): TStateConfiguration<TState, TTrigger>;
begin
  FInitialSubstate := ASubstate;
  FHasInitialSubstate := True;
  Result := Self;
end;

{ TStateMachine<TState, TTrigger> }

constructor TStateMachine<TState, TTrigger>.Create(const AInitialState: TState);
begin
  inherited Create;
  FInitialState := AInitialState;
  FCurrentState := AInitialState;
  FStates := TObjectDictionary<TState, TStateConfiguration<TState, TTrigger>>.Create([doOwnsValues]);
  FLock := TCriticalSection.Create;
  FHistory := TList<TStateHistoryEntry<TState, TTrigger>>.Create;
  FMaxHistorySize := 100;
  FThrowOnUnhandledTrigger := True;
  FIsStarted := False;
  FOwnsContext := False;
end;

destructor TStateMachine<TState, TTrigger>.Destroy;
begin
  if FOwnsContext and Assigned(FContext) then
    FContext.Free;
  FHistory.Free;
  FLock.Free;
  FStates.Free;
  inherited;
end;

function TStateMachine<TState, TTrigger>.Configure(
  const AState: TState): TStateConfiguration<TState, TTrigger>;
begin
  if not FStates.TryGetValue(AState, Result) then
  begin
    Result := TStateConfiguration<TState, TTrigger>.Create(Self, AState);
    FStates.Add(AState, Result);
  end;
end;

function TStateMachine<TState, TTrigger>.GetState(
  const AState: TState): TStateConfiguration<TState, TTrigger>;
begin
  if not FStates.TryGetValue(AState, Result) then
    Result := nil;
end;

function TStateMachine<TState, TTrigger>.GetCurrentConfig: TStateConfiguration<TState, TTrigger>;
begin
  Result := GetState(FCurrentState);
end;

procedure TStateMachine<TState, TTrigger>.Start;
begin
  FLock.Enter;
  try
    if FIsStarted then
      Exit;
      
    FIsStarted := True;
    ExecuteEntryActions(FCurrentState);
    
    // Check for initial substate
    var LConfig := GetState(FCurrentState);
    if Assigned(LConfig) and LConfig.HasInitialSubstate then
    begin
      FCurrentState := LConfig.InitialSubstate;
      ExecuteEntryActions(FCurrentState);
    end;
  finally
    FLock.Leave;
  end;
end;

function TStateMachine<TState, TTrigger>.FindTransition(
  const ATrigger: TTrigger): TTransition<TState, TTrigger>;
var
  LConfig: TStateConfiguration<TState, TTrigger>;
  LTransition: TTransition<TState, TTrigger>;
  LState: TState;
begin
  Result := nil;
  LState := FCurrentState;
  
  // Search current state and parent states
  while True do
  begin
    LConfig := GetState(LState);
    if Assigned(LConfig) then
    begin
      for LTransition in LConfig.Transitions do
      begin
        if CompareMem(@LTransition.Trigger, @ATrigger, SizeOf(TTrigger)) then
        begin
          // Check guard
          if Assigned(LTransition.Guard) then
          begin
            if LTransition.Guard(FContext) then
            begin
              Result := LTransition;
              Exit;
            end;
          end
          else
          begin
            Result := LTransition;
            Exit;
          end;
        end;
      end;
      
      // Check parent state
      if LConfig.HasParent then
        LState := LConfig.ParentState
      else
        Break;
    end
    else
      Break;
  end;
end;

function TStateMachine<TState, TTrigger>.Fire(
  const ATrigger: TTrigger): TTransitionResult<TState, TTrigger>;
var
  LTransition: TTransition<TState, TTrigger>;
  LOldState: TState;
  LConfig: TStateConfiguration<TState, TTrigger>;
begin
  FLock.Enter;
  try
    // Check if trigger is ignored
    LConfig := GetCurrentConfig;
    if Assigned(LConfig) and LConfig.IgnoredTriggers.Contains(ATrigger) then
    begin
      Result := TTransitionResult<TState, TTrigger>.CreateIgnored(FCurrentState, ATrigger);
      Exit;
    end;
    
    // Find valid transition
    LTransition := FindTransition(ATrigger);
    
    if not Assigned(LTransition) then
    begin
      // Unhandled trigger
      if Assigned(FOnUnhandledTrigger) then
        FOnUnhandledTrigger(Self, FCurrentState, ATrigger, 'No valid transition found');
        
      if FThrowOnUnhandledTrigger then
        raise EInvalidTransitionException.CreateFmt(
          'No valid transition from state for trigger', []);
          
      Result := TTransitionResult<TState, TTrigger>.CreateFailure(
        FCurrentState, ATrigger, 'No valid transition found');
      
      if Assigned(FOnTransitionFailed) then
        FOnTransitionFailed(Self, FCurrentState, ATrigger, Result.ErrorMessage);
      Exit;
    end;
    
    LOldState := FCurrentState;
    
    // Internal transition - no state change
    if LTransition.IsInternal then
    begin
      if Assigned(LTransition.Action) then
        LTransition.Action(LOldState, LOldState, ATrigger, FContext);
        
      Result := TTransitionResult<TState, TTrigger>.CreateSuccess(
        LOldState, LOldState, ATrigger);
      Exit;
    end;
    
    // Execute exit actions
    if not LTransition.IsReentry or (LTransition.IsReentry and not LTransition.IsInternal) then
      ExecuteExitActions(FCurrentState);
    
    // Execute transition action
    if Assigned(LTransition.Action) then
      LTransition.Action(LOldState, LTransition.TargetState, ATrigger, FContext);
    
    // Update state
    FCurrentState := LTransition.TargetState;
    
    // Add to history
    AddToHistory(FCurrentState, ATrigger);
    
    // Execute entry actions
    if not LTransition.IsReentry or (LTransition.IsReentry and not LTransition.IsInternal) then
      ExecuteEntryActions(FCurrentState);
    
    // Check for initial substate
    LConfig := GetState(FCurrentState);
    if Assigned(LConfig) and LConfig.HasInitialSubstate then
    begin
      FCurrentState := LConfig.InitialSubstate;
      ExecuteEntryActions(FCurrentState);
    end;
    
    // Fire event
    if Assigned(FOnStateChanged) then
      FOnStateChanged(Self, LOldState, FCurrentState, ATrigger);
    
    Result := TTransitionResult<TState, TTrigger>.CreateSuccess(
      LOldState, FCurrentState, ATrigger);
  finally
    FLock.Leave;
  end;
end;

function TStateMachine<TState, TTrigger>.FireIfInState(const ATrigger: TTrigger;
  const ARequiredState: TState): TTransitionResult<TState, TTrigger>;
begin
  FLock.Enter;
  try
    if not IsIn(ARequiredState) then
    begin
      Result := TTransitionResult<TState, TTrigger>.CreateFailure(
        FCurrentState, ATrigger, 'Not in required state');
      Exit;
    end;
    Result := Fire(ATrigger);
  finally
    FLock.Leave;
  end;
end;

function TStateMachine<TState, TTrigger>.CanFire(const ATrigger: TTrigger): Boolean;
var
  LTransition: TTransition<TState, TTrigger>;
  LConfig: TStateConfiguration<TState, TTrigger>;
begin
  FLock.Enter;
  try
    // Check if ignored
    LConfig := GetCurrentConfig;
    if Assigned(LConfig) and LConfig.IgnoredTriggers.Contains(ATrigger) then
      Exit(True);
      
    LTransition := FindTransition(ATrigger);
    Result := Assigned(LTransition);
  finally
    FLock.Leave;
  end;
end;

function TStateMachine<TState, TTrigger>.GetPermittedTriggers: TArray<TTrigger>;
var
  LConfig: TStateConfiguration<TState, TTrigger>;
  LTransition: TTransition<TState, TTrigger>;
  LTriggers: TList<TTrigger>;
begin
  LTriggers := TList<TTrigger>.Create;
  try
    FLock.Enter;
    try
      LConfig := GetCurrentConfig;
      if Assigned(LConfig) then
      begin
        for LTransition in LConfig.Transitions do
        begin
          if not Assigned(LTransition.Guard) or LTransition.Guard(FContext) then
          begin
            if not LTriggers.Contains(LTransition.Trigger) then
              LTriggers.Add(LTransition.Trigger);
          end;
        end;
      end;
    finally
      FLock.Leave;
    end;
    Result := LTriggers.ToArray;
  finally
    LTriggers.Free;
  end;
end;

function TStateMachine<TState, TTrigger>.IsIn(const AState: TState): Boolean;
begin
  FLock.Enter;
  try
    Result := IsInState(FCurrentState, AState);
  finally
    FLock.Leave;
  end;
end;

function TStateMachine<TState, TTrigger>.IsInState(const AState: TState;
  const ATargetState: TState): Boolean;
var
  LConfig: TStateConfiguration<TState, TTrigger>;
  LCheckState: TState;
begin
  // Direct match
  if CompareMem(@AState, @ATargetState, SizeOf(TState)) then
    Exit(True);
    
  // Check if AState is a substate of ATargetState
  LCheckState := AState;
  while True do
  begin
    LConfig := GetState(LCheckState);
    if not Assigned(LConfig) or not LConfig.HasParent then
      Exit(False);
      
    LCheckState := LConfig.ParentState;
    if CompareMem(@LCheckState, @ATargetState, SizeOf(TState)) then
      Exit(True);
  end;
end;

function TStateMachine<TState, TTrigger>.GetSuperstate(const AState: TState): TState;
var
  LConfig: TStateConfiguration<TState, TTrigger>;
begin
  LConfig := GetState(AState);
  if Assigned(LConfig) and LConfig.HasParent then
    Result := LConfig.ParentState
  else
    Result := AState;
end;

procedure TStateMachine<TState, TTrigger>.ExecuteEntryActions(const AState: TState);
var
  LConfig: TStateConfiguration<TState, TTrigger>;
  LAction: TStateAction<TState, TTrigger>;
begin
  LConfig := GetState(AState);
  if Assigned(LConfig) then
  begin
    for LAction in LConfig.EntryActions do
      LAction(FContext);
  end;
end;

procedure TStateMachine<TState, TTrigger>.ExecuteExitActions(const AState: TState);
var
  LConfig: TStateConfiguration<TState, TTrigger>;
  LAction: TStateAction<TState, TTrigger>;
begin
  LConfig := GetState(AState);
  if Assigned(LConfig) then
  begin
    for LAction in LConfig.ExitActions do
      LAction(FContext);
  end;
end;

procedure TStateMachine<TState, TTrigger>.AddToHistory(const AState: TState; 
  const ATrigger: TTrigger);
var
  LEntry: TStateHistoryEntry<TState, TTrigger>;
begin
  LEntry.State := AState;
  LEntry.Trigger := ATrigger;
  LEntry.Timestamp := Now;
  LEntry.Context := FContext;
  
  FHistory.Add(LEntry);
  
  // Trim history if needed
  while FHistory.Count > FMaxHistorySize do
    FHistory.Delete(0);
end;

procedure TStateMachine<TState, TTrigger>.Reset;
begin
  FLock.Enter;
  try
    ExecuteExitActions(FCurrentState);
    FCurrentState := FInitialState;
    FIsStarted := False;
    ClearHistory;
  finally
    FLock.Leave;
  end;
end;

function TStateMachine<TState, TTrigger>.GetHistory: TArray<TStateHistoryEntry<TState, TTrigger>>;
begin
  FLock.Enter;
  try
    Result := FHistory.ToArray;
  finally
    FLock.Leave;
  end;
end;

procedure TStateMachine<TState, TTrigger>.ClearHistory;
begin
  FLock.Enter;
  try
    FHistory.Clear;
  finally
    FLock.Leave;
  end;
end;

function TStateMachine<TState, TTrigger>.ToDotGraph: string;
var
  LBuilder: TStringBuilder;
  LStatePair: TPair<TState, TStateConfiguration<TState, TTrigger>>;
  LTransition: TTransition<TState, TTrigger>;
  
  function StateToString(const AState: TState): string;
  var
    LValue: TValue;
  begin
    LValue := TValue.From<TState>(AState);
    if LValue.Kind = tkEnumeration then
      Result := GetEnumName(LValue.TypeInfo, LValue.AsOrdinal)
    else if LValue.Kind in [tkString, tkUString, tkLString, tkWString] then
      Result := LValue.AsString
    else if LValue.Kind in [tkInteger, tkInt64] then
      Result := LValue.AsOrdinal.ToString
    else
      Result := 'State_' + IntToStr(LValue.AsOrdinal);
  end;
  
  function TriggerToString(const ATrigger: TTrigger): string;
  var
    LValue: TValue;
  begin
    LValue := TValue.From<TTrigger>(ATrigger);
    if LValue.Kind = tkEnumeration then
      Result := GetEnumName(LValue.TypeInfo, LValue.AsOrdinal)
    else if LValue.Kind in [tkString, tkUString, tkLString, tkWString] then
      Result := LValue.AsString
    else if LValue.Kind in [tkInteger, tkInt64] then
      Result := LValue.AsOrdinal.ToString
    else
      Result := 'Trigger_' + IntToStr(LValue.AsOrdinal);
  end;
  
begin
  LBuilder := TStringBuilder.Create;
  try
    LBuilder.AppendLine('digraph StateMachine {');
    LBuilder.AppendLine('  rankdir=LR;');
    LBuilder.AppendLine('  node [shape=ellipse];');
    LBuilder.AppendLine;
    
    // Mark initial state
    LBuilder.AppendFormat('  %s [style=filled, fillcolor=lightblue];', [StateToString(FInitialState)]);
    LBuilder.AppendLine;
    
    // Mark current state
    LBuilder.AppendFormat('  %s [style=filled, fillcolor=lightgreen];', [StateToString(FCurrentState)]);
    LBuilder.AppendLine;
    LBuilder.AppendLine;
    
    // Add transitions
    for LStatePair in FStates do
    begin
      for LTransition in LStatePair.Value.Transitions do
      begin
        LBuilder.AppendFormat('  %s -> %s [label="%s"', [
          StateToString(LStatePair.Key),
          StateToString(LTransition.TargetState),
          TriggerToString(LTransition.Trigger)
        ]);
        
        if LTransition.GuardDescription <> '' then
          LBuilder.AppendFormat(' tooltip="%s"', [LTransition.GuardDescription]);
          
        if LTransition.IsInternal then
          LBuilder.Append(' style=dashed');
          
        LBuilder.AppendLine('];');
      end;
      
      // Add parent relationship
      if LStatePair.Value.HasParent then
      begin
        LBuilder.AppendFormat('  %s -> %s [style=dotted, arrowhead=empty];', [
          StateToString(LStatePair.Key),
          StateToString(LStatePair.Value.ParentState)
        ]);
        LBuilder.AppendLine;
      end;
    end;
    
    LBuilder.AppendLine('}');
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

function TStateMachine<TState, TTrigger>.ToJSON: string;
var
  LJSON: TJSONObject;
  LValue: TValue;
begin
  LJSON := TJSONObject.Create;
  try
    LValue := TValue.From<TState>(FCurrentState);
    if LValue.Kind = tkEnumeration then
      LJSON.AddPair('currentState', GetEnumName(LValue.TypeInfo, LValue.AsOrdinal))
    else if LValue.Kind in [tkString, tkUString, tkLString, tkWString] then
      LJSON.AddPair('currentState', LValue.AsString)
    else
      LJSON.AddPair('currentState', TJSONNumber.Create(LValue.AsOrdinal));
      
    LValue := TValue.From<TState>(FInitialState);
    if LValue.Kind = tkEnumeration then
      LJSON.AddPair('initialState', GetEnumName(LValue.TypeInfo, LValue.AsOrdinal))
    else if LValue.Kind in [tkString, tkUString, tkLString, tkWString] then
      LJSON.AddPair('initialState', LValue.AsString)
    else
      LJSON.AddPair('initialState', TJSONNumber.Create(LValue.AsOrdinal));
      
    LJSON.AddPair('isStarted', TJSONBool.Create(FIsStarted));
    
    Result := LJSON.ToString;
  finally
    LJSON.Free;
  end;
end;

procedure TStateMachine<TState, TTrigger>.FromJSON(const AJSON: string);
var
  LJSON: TJSONObject;
  LStateStr: string;
  LStateValue: TValue;
  LTypeInfo: PTypeInfo;
  I: Integer;
begin
  LJSON := TJSONObject.ParseJSONValue(AJSON) as TJSONObject;
  if not Assigned(LJSON) then
    Exit;
    
  try
    FLock.Enter;
    try
      LTypeInfo := TypeInfo(TState);
      
      if LJSON.TryGetValue<string>('currentState', LStateStr) then
      begin
        if LTypeInfo^.Kind = tkEnumeration then
        begin
          I := GetEnumValue(LTypeInfo, LStateStr);
          if I >= 0 then
          begin
            LStateValue := TValue.FromOrdinal(LTypeInfo, I);
            FCurrentState := LStateValue.AsType<TState>;
          end;
        end
        else if LTypeInfo^.Kind in [tkString, tkUString, tkLString, tkWString] then
        begin
          LStateValue := TValue.From<string>(LStateStr);
          FCurrentState := LStateValue.AsType<TState>;
        end;
      end;
      
      LJSON.TryGetValue<Boolean>('isStarted', FIsStarted);
    finally
      FLock.Leave;
    end;
  finally
    LJSON.Free;
  end;
end;

{ TStateMachineBuilder<TState, TTrigger> }

constructor TStateMachineBuilder<TState, TTrigger>.Create(const AInitialState: TState);
begin
  inherited Create;
  FStateMachine := TStateMachine<TState, TTrigger>.Create(AInitialState);
  FCurrentConfig := nil;
end;

function TStateMachineBuilder<TState, TTrigger>.State(
  const AState: TState): TStateMachineBuilder<TState, TTrigger>;
begin
  FCurrentConfig := FStateMachine.Configure(AState);
  Result := Self;
end;

function TStateMachineBuilder<TState, TTrigger>.Permit(const ATrigger: TTrigger;
  const ATargetState: TState): TStateMachineBuilder<TState, TTrigger>;
begin
  if Assigned(FCurrentConfig) then
    FCurrentConfig.Permit(ATrigger, ATargetState);
  Result := Self;
end;

function TStateMachineBuilder<TState, TTrigger>.PermitIf(const ATrigger: TTrigger;
  const ATargetState: TState;
  AGuard: TGuardFunc<TState, TTrigger>): TStateMachineBuilder<TState, TTrigger>;
begin
  if Assigned(FCurrentConfig) then
    FCurrentConfig.PermitIf(ATrigger, ATargetState, AGuard);
  Result := Self;
end;

function TStateMachineBuilder<TState, TTrigger>.OnEntry(
  AAction: TStateAction<TState, TTrigger>): TStateMachineBuilder<TState, TTrigger>;
begin
  if Assigned(FCurrentConfig) then
    FCurrentConfig.OnEntry(AAction);
  Result := Self;
end;

function TStateMachineBuilder<TState, TTrigger>.OnExit(
  AAction: TStateAction<TState, TTrigger>): TStateMachineBuilder<TState, TTrigger>;
begin
  if Assigned(FCurrentConfig) then
    FCurrentConfig.OnExit(AAction);
  Result := Self;
end;

function TStateMachineBuilder<TState, TTrigger>.Ignore(
  const ATrigger: TTrigger): TStateMachineBuilder<TState, TTrigger>;
begin
  if Assigned(FCurrentConfig) then
    FCurrentConfig.Ignore(ATrigger);
  Result := Self;
end;

function TStateMachineBuilder<TState, TTrigger>.SubstateOf(
  const AParentState: TState): TStateMachineBuilder<TState, TTrigger>;
begin
  if Assigned(FCurrentConfig) then
    FCurrentConfig.SubstateOf(AParentState);
  Result := Self;
end;

function TStateMachineBuilder<TState, TTrigger>.WithContext(AContext: TObject;
  AOwnsContext: Boolean): TStateMachineBuilder<TState, TTrigger>;
begin
  FStateMachine.Context := AContext;
  FStateMachine.OwnsContext := AOwnsContext;
  Result := Self;
end;

function TStateMachineBuilder<TState, TTrigger>.OnStateChanged(
  AHandler: TStateChangedEvent<TState, TTrigger>): TStateMachineBuilder<TState, TTrigger>;
begin
  FStateMachine.OnStateChanged := AHandler;
  Result := Self;
end;

function TStateMachineBuilder<TState, TTrigger>.Build: TStateMachine<TState, TTrigger>;
begin
  Result := FStateMachine;
  FStateMachine := nil; // Transfer ownership
end;

end.
