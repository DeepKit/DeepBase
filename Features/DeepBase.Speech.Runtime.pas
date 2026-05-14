{ ============================================================================
  DeepBase.Speech.Runtime
  ---------------------------------------------------------------------------
  Version     : 1.0
  Description : AudioSession state machine and resource arbitration.
                Ensures only one speech capability uses the microphone at a
                time. Manages transitions between states:
                  Idle → WakeListening → PushToTalk → DictationStreaming → TTSPlaying
  Thread Safety: All public methods are thread-safe.
  ============================================================================ }

unit DeepBase.Speech.Runtime;

interface

uses
  System.SysUtils, System.SyncObjs, Winapi.Windows;

type
  TAudioSessionState = (
    assIdle,               // Nothing active
    assWakeListening,      // WakeWord detector has mic
    assPushToTalk,         // User holding PTT key, recording
    assDictationStreaming, // Continuous dictation (DeepInput)
    assTTSPlaying          // TTS output playing
  );

  TAudioSessionTransition = record
    FromState: TAudioSessionState;
    ToState: TAudioSessionState;
    Timestamp: TDateTime;
    Reason: string;
  end;

  TSpeechRuntime = class
  private
    FState: TAudioSessionState;
    FLock: TCriticalSection;
    FLastTransition: TAudioSessionTransition;
    FTraceEnabled: Boolean;
    FWakeWordWasActive: Boolean;  // Track if WakeWord should be restored
    FSessionStartTick: Int64;     // QPC tick when session started
    FOnStateChange: TProc<TAudioSessionState, TAudioSessionState>;
    procedure DoTransition(ANewState: TAudioSessionState; const AReason: string);
    function ElapsedMs: Double;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>Request microphone for a specific purpose.</summary>
    /// <returns>True if granted, False if another session has priority.</returns>
    function RequestMic(ARequestedState: TAudioSessionState;
      const AReason: string): Boolean;

    /// <summary>Release microphone back to Idle (or restore WakeListening if it was active).</summary>
    procedure ReleaseMic(const AReason: string);

    /// <summary>Force-stop current session (e.g. user pressed Esc).</summary>
    procedure ForceStop(const AReason: string);

    /// <summary>Current audio session state.</summary>
    property State: TAudioSessionState read FState;

    /// <summary>Last state transition (for trace/debug).</summary>
    property LastTransition: TAudioSessionTransition read FLastTransition;

    /// <summary>Enable/disable trace logging.</summary>
    property TraceEnabled: Boolean read FTraceEnabled write FTraceEnabled;

    /// <summary>Callback fired on every state change.</summary>
    property OnStateChange: TProc<TAudioSessionState, TAudioSessionState>
      read FOnStateChange write FOnStateChange;
  end;

var
  SpeechRuntime: TSpeechRuntime;

implementation

constructor TSpeechRuntime.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FState := assIdle;
  FTraceEnabled := True;
  FWakeWordWasActive := False;
  FSessionStartTick := 0;
  FOnStateChange := nil;
end;

destructor TSpeechRuntime.Destroy;
begin
  FOnStateChange := nil;
  FreeAndNil(FLock);
  inherited;
end;

function TSpeechRuntime.ElapsedMs: Double;
var
  LNow, LFreq: Int64;
begin
  if FSessionStartTick = 0 then
    Exit(0);
  QueryPerformanceCounter(LNow);
  QueryPerformanceFrequency(LFreq);
  if LFreq > 0 then
    Result := (LNow - FSessionStartTick) * 1000.0 / LFreq
  else
    Result := 0;
end;

procedure TSpeechRuntime.DoTransition(ANewState: TAudioSessionState;
  const AReason: string);
var
  LOldState: TAudioSessionState;
begin
  LOldState := FState;
  FLastTransition.FromState := FState;
  FLastTransition.ToState := ANewState;
  FLastTransition.Timestamp := Now;
  FLastTransition.Reason := AReason;
  FState := ANewState;
  QueryPerformanceCounter(FSessionStartTick);

  if Assigned(FOnStateChange) then
    FOnStateChange(LOldState, ANewState);
end;

function TSpeechRuntime.RequestMic(ARequestedState: TAudioSessionState;
  const AReason: string): Boolean;
begin
  FLock.Enter;
  try
    case FState of
      assIdle:
        begin
          // Always grant from Idle
          if ARequestedState = assWakeListening then
            FWakeWordWasActive := True;
          DoTransition(ARequestedState, AReason);
          Result := True;
        end;

      assWakeListening:
        begin
          // PTT and Dictation can preempt WakeWord (hard-cut)
          if ARequestedState in [assPushToTalk, assDictationStreaming] then
          begin
            FWakeWordWasActive := True; // Remember to restore
            DoTransition(ARequestedState, 'Preempt WakeWord: ' + AReason);
            Result := True;
          end
          else if ARequestedState = assTTSPlaying then
          begin
            // TTS can play while wake is listening (different device path)
            FWakeWordWasActive := True;
            DoTransition(assTTSPlaying, AReason);
            Result := True;
          end
          else
            Result := False;
        end;

      assPushToTalk, assDictationStreaming:
        begin
          // Cannot preempt active recording — first-come-first-served
          Result := False;
        end;

      assTTSPlaying:
        begin
          // PTT can interrupt TTS (user wants to speak — F2 pressed during TTS)
          if ARequestedState in [assPushToTalk, assDictationStreaming] then
          begin
            // Stop TTS, switch to PTT
            DoTransition(ARequestedState, 'Interrupt TTS: ' + AReason);
            Result := True;
          end
          else
            Result := False;
        end;
    else
      Result := False;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TSpeechRuntime.ReleaseMic(const AReason: string);
begin
  FLock.Enter;
  try
    if FWakeWordWasActive and (FState in [assPushToTalk, assDictationStreaming, assTTSPlaying]) then
    begin
      // Auto-restore WakeWord listening after PTT/Dictation/TTS ends
      DoTransition(assWakeListening, 'Restore WakeWord: ' + AReason);
    end
    else
    begin
      FWakeWordWasActive := False;
      DoTransition(assIdle, 'Release: ' + AReason);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TSpeechRuntime.ForceStop(const AReason: string);
begin
  FLock.Enter;
  try
    FWakeWordWasActive := False;
    DoTransition(assIdle, 'ForceStop: ' + AReason);
  finally
    FLock.Leave;
  end;
end;

initialization
  SpeechRuntime := TSpeechRuntime.Create;

finalization
  FreeAndNil(SpeechRuntime);

end.
