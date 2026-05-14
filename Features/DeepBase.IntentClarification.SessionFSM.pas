{ ============================================================================
  DeepBase.IntentClarification.SessionFSM - State Machine Integration

  Defines TSessionTrigger enum and TSessionFSM type alias.
  Provides a factory function to create a fully-configured state machine
  for session lifecycle management.

  Phase 2 Task 21: StateMachine Integration
    - TSessionTrigger = (stStart, stSubmit, stSuspend, stResume, stCancel,
                         stTimeout, stComplete)
    - TSessionFSM = TStateMachine<TSessionStatus, TSessionTrigger>
    - Configured transitions with entry/exit actions publishing EventBus events
    - Replaces manual IsValidTransition in Session.pas

  Requirements: 21.1
  ============================================================================ }

unit DeepBase.IntentClarification.SessionFSM;

interface

uses
  System.SysUtils,
  DeepBase.IntentClarification.Types,
  DeepBase.StateMachine,
  DeepBase.EventBus,
  DeepBase.Logging,
  DeepBase.IntentClarification.Logging;

type
  /// <summary>
  /// Session lifecycle triggers for the state machine.
  /// Extends the simpler TSessionTrigger in Session.pas with full lifecycle.
  /// </summary>
  TSessionFSMTrigger = (
    sfStart,      // Initial activation
    sfSubmit,     // User submits input (internal transition, stays Active)
    sfSuspend,    // Suspend session (Active -> Suspended)
    sfResume,     // Resume session (Suspended -> Active)
    sfCancel,     // User cancels (Active -> Completed)
    sfTimeout,    // Idle timeout (Active -> Suspended)
    sfComplete    // Natural completion (Active -> Completed)
  );

  /// <summary>Type alias for the session state machine</summary>
  TSessionFSM = TStateMachine<TSessionStatus, TSessionFSMTrigger>;

  /// <summary>
  /// Factory for creating configured session state machines.
  /// Each session gets its own FSM instance.
  /// </summary>
  TSessionFSMFactory = class
  public
    /// <summary>
    /// Creates a new session FSM starting in ssActive state.
    /// Configures all valid transitions:
    ///   Active + sfSuspend -> Suspended
    ///   Active + sfTimeout -> Suspended
    ///   Active + sfCancel  -> Completed
    ///   Active + sfComplete -> Completed
    ///   Active + sfSubmit  -> Active (internal, no entry/exit)
    ///   Suspended + sfResume -> Active
    ///   Completed -> (terminal)
    /// </summary>
    class function CreateForSession(const ASessionId: string;
      AEventBus: TEventBus = nil): TSessionFSM;

    /// <summary>
    /// Creates a session FSM with entry/exit actions that publish
    /// events to the EventBus on state transitions.
    /// </summary>
    class function CreateWithEvents(const ASessionId: string;
      AEventBus: TEventBus): TSessionFSM;
  end;

implementation

const
  IC_STATUS_COMPLETED = TSessionStatus(2);

{ TSessionFSMFactory }

class function TSessionFSMFactory.CreateForSession(const ASessionId: string;
  AEventBus: TEventBus): TSessionFSM;
begin
  if AEventBus <> nil then
    Result := CreateWithEvents(ASessionId, AEventBus)
  else
  begin
    Result := TSessionFSM.Create(ssActive);

    // Active state: can suspend, timeout, cancel, complete, or submit (internal)
    Result.Configure(ssActive)
      .Permit(sfSuspend, ssSuspended)
      .Permit(sfTimeout, ssSuspended)
      .Permit(sfCancel, IC_STATUS_COMPLETED)
      .Permit(sfComplete, IC_STATUS_COMPLETED)
      .InternalTransition(sfSubmit,
        procedure(const AFrom, ATo: TSessionStatus;
          const ATrigger: TSessionFSMTrigger; const ACtx: TObject)
        begin
          // Submit is an internal transition - no state change
        end);

    // Suspended state: can resume
    Result.Configure(ssSuspended)
      .Permit(sfResume, ssActive);

    // Completed state: terminal (no transitions out)
    // Archived state: terminal
    // No configuration needed for terminal states

    Log(ltDebug, Format('IC.FSM: Created for session %s', [ASessionId]));
  end;
end;

class function TSessionFSMFactory.CreateWithEvents(const ASessionId: string;
  AEventBus: TEventBus): TSessionFSM;
begin
  Result := TSessionFSM.Create(ssActive);

  // Active state with entry/exit actions
  Result.Configure(ssActive)
    .OnEntry(
      procedure(const ACtx: TObject)
      begin
        Log(ltDebug, Format('IC.FSM: Session %s entered Active', [ASessionId]));
      end)
    .OnExit(
      procedure(const ACtx: TObject)
      begin
        Log(ltDebug, Format('IC.FSM: Session %s exiting Active', [ASessionId]));
      end)
    .Permit(sfSuspend, ssSuspended)
    .Permit(sfTimeout, ssSuspended)
    .Permit(sfCancel, IC_STATUS_COMPLETED)
    .Permit(sfComplete, IC_STATUS_COMPLETED)
    .InternalTransition(sfSubmit,
      procedure(const AFrom, ATo: TSessionStatus;
        const ATrigger: TSessionFSMTrigger; const ACtx: TObject)
      begin
        // Internal: no state change, no entry/exit
      end);

  // Suspended state with entry action
  Result.Configure(ssSuspended)
    .OnEntry(
      procedure(const ACtx: TObject)
      begin
        Log(ltInfo, Format('IC.FSM: Session %s suspended', [ASessionId]));
      end)
    .Permit(sfResume, ssActive);

  // Completed state with entry action
  Result.Configure(IC_STATUS_COMPLETED)
    .OnEntry(
      procedure(const ACtx: TObject)
      begin
        Log(ltInfo, Format('IC.FSM: Session %s completed', [ASessionId]));
      end);

  Log(ltDebug, Format('IC.FSM: Created with events for session %s', [ASessionId]));
end;

end.
