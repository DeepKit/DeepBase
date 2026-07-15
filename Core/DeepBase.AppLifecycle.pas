unit DeepBase.AppLifecycle;

interface

uses
  System.SysUtils,
  System.SyncObjs,
  Winapi.Windows;

type
  TAppLifecycle = class
  private
    class var FLock: TCriticalSection;
    class var FMutexHandle: THandle;
    class var FMutexName: string;
    class var FProgramID: string;
    class var FStateDir: string;
    class var FShutdownEvent: TEvent;
    class var FShutdownRequested: Boolean;
    class var FShutdownReason: string;
    class var FShutdownHandlerInstalled: Boolean;

    class function ConsoleCtrlHandler(CtrlType: DWORD): BOOL; stdcall; static;
    class function DefaultProgramID: string; static;
    class function DefaultStateDir: string; static;
    class function SanitizeName(const Value: string): string; static;
    class function BuildMutexName(const LockName: string;
      UseGlobalNamespace: Boolean): string; static;
    class function StateFilePath: string; static;
    class procedure EnsureConfigured; static;
    class procedure EnsureShutdownEvent; static;
    class procedure LoadState(out State: string; out Count: Integer); static;
    class procedure SaveState(const State: string; Count: Integer); static;
    class procedure InstallShutdownHandler; static;
  public
    class constructor Create;
    class destructor Destroy;

    class procedure Configure(const ProgramID: string;
      const StateDir: string = ''); static;
    class procedure Reset; static;

    class function AcquireSingleton(const LockName: string): Boolean; static;
    class procedure ReleaseSingleton; static;

    class procedure MarkStarted; static;
    class procedure MarkCleanShutdown; static;
    class function CrashCount: Integer; static;

    class procedure RequestShutdown(const Reason: string = 'requested'); static;
    class procedure WaitForShutdownSignal(const OnShutdown: TProc); static;
    class function ShutdownRequested: Boolean; static;
    class function ShutdownReason: string; static;
  end;

implementation

uses
  System.Classes,
  System.DateUtils,
  System.IOUtils,
  DeepBase.Exceptions;

const
  STATE_RUNNING = 'running';
  STATE_CLEAN = 'clean';
  STATE_SECTION = 'Lifecycle';
  // BIZ2-021 fix: hard cap on the crash counter so it cannot grow without
  // bound (eventually overflowing Integer). 1000 is well above any sane
  // "crash-loop" policy threshold while leaving ample headroom below
  // Integer.MaxValue.
  MAX_CRASH_COUNT = 1000;
  // If this much time has passed since the last recorded state change
  // without a new crash, reset the counter. Prevents a single historical
  // crash loop from poisoning diagnostics forever.
  CRASH_COUNTER_RESET_HOURS = 24;

class constructor TAppLifecycle.Create;
begin
  FLock := TCriticalSection.Create;
  FMutexHandle := 0;
end;

class destructor TAppLifecycle.Destroy;
begin
  Reset;
  FreeAndNil(FLock);
end;

class procedure TAppLifecycle.Configure(const ProgramID, StateDir: string);
begin
  if Trim(ProgramID) = '' then
    raise EArgumentException.Create('ProgramID cannot be empty');

  FLock.Enter;
  try
    FProgramID := ProgramID;
    if Trim(StateDir) = '' then
      FStateDir := DefaultStateDir
    else
      FStateDir := StateDir;
  finally
    FLock.Leave;
  end;
end;

class procedure TAppLifecycle.Reset;
begin
  ReleaseSingleton;

  FLock.Enter;
  try
    FShutdownRequested := False;
    FShutdownReason := '';
    FreeAndNil(FShutdownEvent);
    FProgramID := '';
    FStateDir := '';
  finally
    FLock.Leave;
  end;
end;

class function TAppLifecycle.DefaultProgramID: string;
begin
  Result := ExtractFileName(ChangeFileExt(ParamStr(0), ''));
  if Trim(Result) = '' then
    Result := 'application';
end;

class function TAppLifecycle.DefaultStateDir: string;
begin
  Result := GetEnvironmentVariable('LOCALAPPDATA');
  if Trim(Result) = '' then
    Result := TPath.GetTempPath;

  Result := TPath.Combine(Result, 'DeepBase');
  Result := TPath.Combine(Result, 'Lifecycle');
end;

class function TAppLifecycle.SanitizeName(const Value: string): string;
var
  Ch: Char;
begin
  Result := '';
  for Ch in Value do
  begin
    if CharInSet(Ch, ['A'..'Z', 'a'..'z', '0'..'9', '_', '-', '.']) then
      Result := Result + Ch
    else
      Result := Result + '_';
  end;

  if Result = '' then
    Result := 'application';
end;

class function TAppLifecycle.BuildMutexName(const LockName: string;
  UseGlobalNamespace: Boolean): string;
begin
  if Trim(LockName) = '' then
    raise EArgumentException.Create('LockName cannot be empty');

  if UseGlobalNamespace then
    Result := 'Global\DeepBase_' + SanitizeName(LockName)
  else
    Result := 'Local\DeepBase_' + SanitizeName(LockName);
end;

class procedure TAppLifecycle.EnsureConfigured;
begin
  FLock.Enter;
  try
    if FProgramID = '' then
      FProgramID := DefaultProgramID;
    if FStateDir = '' then
      FStateDir := DefaultStateDir;
  finally
    FLock.Leave;
  end;
end;

class function TAppLifecycle.StateFilePath: string;
var
  ProgramID: string;
  StateDir: string;
begin
  EnsureConfigured;

  FLock.Enter;
  try
    ProgramID := FProgramID;
    StateDir := FStateDir;
  finally
    FLock.Leave;
  end;

  TDirectory.CreateDirectory(StateDir);
  Result := TPath.Combine(StateDir, SanitizeName(ProgramID) + '.lifecycle');
end;

class function TAppLifecycle.AcquireSingleton(
  const LockName: string): Boolean;
var
  Handle: THandle;
  MutexName: string;
begin
  Result := False;

  FLock.Enter;
  try
    if FMutexHandle <> 0 then
      Exit(SameText(FMutexName, BuildMutexName(LockName, True)) or
        SameText(FMutexName, BuildMutexName(LockName, False)));
  finally
    FLock.Leave;
  end;

  MutexName := BuildMutexName(LockName, True);
  Handle := CreateMutex(nil, True, PChar(MutexName));
  // BIZ2-022 fix: when the Global\ mutex creation fails with
  // ERROR_ACCESS_DENIED (e.g. session-0 service vs. interactive user), fall
  // back to a Local\ mutex. The ERROR_ALREADY_EXISTS check below applies
  // equally to the fallback: CreateMutex on a pre-existing local mutex
  // returns a valid handle AND sets GetLastError to ERROR_ALREADY_EXISTS,
  // so we correctly detect the collision and refuse to treat a shared
  // local mutex as exclusive ownership. Windows does not reset
  // GetLastError on a successful CreateMutex, so the value at this point
  // always reflects the most recent CreateMutex call.
  if (Handle = 0) and (GetLastError = ERROR_ACCESS_DENIED) then
  begin
    MutexName := BuildMutexName(LockName, False);
    Handle := CreateMutex(nil, True, PChar(MutexName));
  end;

  if Handle = 0 then
    Exit(False);

  if GetLastError = ERROR_ALREADY_EXISTS then
  begin
    CloseHandle(Handle);
    Exit(False);
  end;

  FLock.Enter;
  try
    FMutexHandle := Handle;
    FMutexName := MutexName;
    Result := True;
  finally
    FLock.Leave;
  end;
end;

class procedure TAppLifecycle.ReleaseSingleton;
var
  Handle: THandle;
begin
  Handle := 0;

  FLock.Enter;
  try
    if FMutexHandle <> 0 then
    begin
      Handle := FMutexHandle;
      FMutexHandle := 0;
      FMutexName := '';
    end;
  finally
    FLock.Leave;
  end;

  if Handle <> 0 then
  begin
    ReleaseMutex(Handle);
    CloseHandle(Handle);
  end;
end;

class procedure TAppLifecycle.LoadState(out State: string; out Count: Integer);
var
  Lines: TStringList;
  Path: string;
begin
  State := STATE_CLEAN;
  Count := 0;
  Path := StateFilePath;

  if not TFile.Exists(Path) then
    Exit;

  Lines := TStringList.Create;
  try
    Lines.NameValueSeparator := '=';
    Lines.LoadFromFile(Path, TEncoding.UTF8);
    State := Lines.Values['State'];
    if State = '' then
      State := STATE_CLEAN;
    Count := StrToIntDef(Lines.Values['CrashCount'], 0);
  finally
    Lines.Free;
  end;
end;

class procedure TAppLifecycle.SaveState(const State: string; Count: Integer);
var
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    Lines.NameValueSeparator := '=';
    Lines.Values['Section'] := STATE_SECTION;
    Lines.Values['ProgramID'] := FProgramID;
    Lines.Values['State'] := State;
    Lines.Values['CrashCount'] := IntToStr(Count);
    Lines.Values['UpdatedAt'] := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now);
    Lines.SaveToFile(StateFilePath, TEncoding.UTF8);
  finally
    Lines.Free;
  end;
end;

class procedure TAppLifecycle.MarkStarted;
var
  State: string;
  Count: Integer;
  Lines: TStringList;
  UpdatedAt: TDateTime;
begin
  EnsureConfigured;
  FLock.Enter;
  try
    LoadState(State, Count);
    if SameText(State, STATE_RUNNING) then
    begin
      // BIZ2-021 fix: cap the crash counter and reset it after a long
      // stable period. Without the cap, repeated crashes drive Count to
      // arbitrarily large values (eventually overflowing Integer). Without
      // the time-based reset, a single historical crash loop poisons
      // diagnostics forever even after the underlying bug is fixed.
      if Count >= MAX_CRASH_COUNT then
      begin
        // BIZ2-021 fix: refuse to start when the crash loop threshold is
        // exceeded. The counter is preserved on disk so diagnostics / a
        // manual reset can still inspect it; only the launch is blocked.
        SaveState(STATE_RUNNING, Count);
        raise EOperationException.CreateFmt(
          'Refusing to start: crash count (%d) has reached the maximum ' +
          'allowed threshold (%d). Clear the lifecycle state file at ' +
          '"%s" to reset.',
          [Count, MAX_CRASH_COUNT, StateFilePath]);
      end
      else
      begin
        // Only apply the time-based reset when we have a parseable timestamp.
        // If the state file is corrupted, leave Count alone so the next
        // clean shutdown can reset it.
        Lines := TStringList.Create;
        try
          Lines.NameValueSeparator := '=';
          if TFile.Exists(StateFilePath) then
            Lines.LoadFromFile(StateFilePath, TEncoding.UTF8);
          if TryStrToDateTime(Lines.Values['UpdatedAt'], UpdatedAt)
            and (UpdatedAt > 0)
            and (Now - UpdatedAt >= CRASH_COUNTER_RESET_HOURS / HoursPerDay)
          then
            Count := 1  // treat this launch as the first crash after the quiet period
          else
            Inc(Count);
        finally
          Lines.Free;
        end;
      end;
    end;
    SaveState(STATE_RUNNING, Count);
  finally
    FLock.Leave;
  end;
end;

class procedure TAppLifecycle.MarkCleanShutdown;
begin
  EnsureConfigured;
  FLock.Enter;
  try
    SaveState(STATE_CLEAN, 0);
  finally
    FLock.Leave;
  end;
end;

class function TAppLifecycle.CrashCount: Integer;
var
  State: string;
begin
  EnsureConfigured;
  FLock.Enter;
  try
    LoadState(State, Result);
  finally
    FLock.Leave;
  end;
end;

class procedure TAppLifecycle.EnsureShutdownEvent;
begin
  if not Assigned(FShutdownEvent) then
    FShutdownEvent := TEvent.Create(nil, True, False, '');
end;

class function TAppLifecycle.ConsoleCtrlHandler(CtrlType: DWORD): BOOL;
begin
  case CtrlType of
    CTRL_C_EVENT,
    CTRL_BREAK_EVENT,
    CTRL_CLOSE_EVENT,
    CTRL_LOGOFF_EVENT,
    CTRL_SHUTDOWN_EVENT:
      begin
        RequestShutdown('console');
        Result := True;
      end;
  else
    Result := False;
  end;
end;

class procedure TAppLifecycle.InstallShutdownHandler;
begin
  FLock.Enter;
  try
    if not FShutdownHandlerInstalled then
    begin
      if SetConsoleCtrlHandler(@ConsoleCtrlHandler, True) then
        FShutdownHandlerInstalled := True;
    end;
  finally
    FLock.Leave;
  end;
end;

class procedure TAppLifecycle.RequestShutdown(const Reason: string);
begin
  FLock.Enter;
  try
    EnsureShutdownEvent;
    FShutdownRequested := True;
    FShutdownReason := Reason;
    FShutdownEvent.SetEvent;
  finally
    FLock.Leave;
  end;
end;

class procedure TAppLifecycle.WaitForShutdownSignal(const OnShutdown: TProc);
var
  Event: TEvent;
begin
  InstallShutdownHandler;

  FLock.Enter;
  try
    EnsureShutdownEvent;
    Event := FShutdownEvent;
  finally
    FLock.Leave;
  end;

  Event.WaitFor(INFINITE);

  if Assigned(OnShutdown) then
    OnShutdown;
end;

class function TAppLifecycle.ShutdownRequested: Boolean;
begin
  FLock.Enter;
  try
    Result := FShutdownRequested;
  finally
    FLock.Leave;
  end;
end;

class function TAppLifecycle.ShutdownReason: string;
begin
  FLock.Enter;
  try
    Result := FShutdownReason;
  finally
    FLock.Leave;
  end;
end;

end.
