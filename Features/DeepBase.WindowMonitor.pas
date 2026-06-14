{ ============================================================================
  DeepBase.WindowMonitor - Foreground Window & Process Monitor
  Version: 0.7
  ============================================================================ }

unit DeepBase.WindowMonitor;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.SyncObjs,
  Winapi.Windows, Winapi.PSAPI, Winapi.TlHelp32, Winapi.ShlObj,
  DeepBase.Exceptions, DeepBase.Logging;

type
  TProcessState = (psStarted, psStopped);
  TWindowChangeCallback = reference to procedure(
    const OldProc, NewProc: string; const OldTitle, NewTitle: string);
  TProcessStateCallback = reference to procedure(
    const ProcName: string; State: TProcessState);

  IWindowMonitor = interface
    ['{F4A5B6C7-8D9E-4F1A-8B2C-3C4D5E6F7A8B}']
    procedure Start;
    procedure Stop;
    function IsRunning: Boolean;
    function GetForegroundProcessName: string;
    function GetForegroundWindowTitle: string;
    function GetForegroundWindowHandle: HWND;
    function IsProcessRunning(const ProcName: string): Boolean;
    function GetProcessID(const ProcName: string): DWORD;
    procedure AddWatchTarget(const ProcName: string; const ExpectedPath: string = '');
    procedure RemoveWatchTarget(const ProcName: string);
    function RegisterWindowCallback(const Callback: TWindowChangeCallback): Integer;
    function RegisterProcessCallback(const Callback: TProcessStateCallback): Integer;
    procedure UnregisterCallback(const Token: Integer);
  end;

  TWindowMonitor = class(TInterfacedObject, IWindowMonitor)
  private
    FWinEventHook: HWINEVENTHOOK;
    FPollEvent: TEvent;
    FPollThread: TThread;
    FWatchTargets: TThreadList<string>;
    FWatchTargetPaths: TDictionary<string, string>;
    FLastForegroundProc: string;
    FLastForegroundTitle: string;
    FWindowCallbacks: TDictionary<Integer, TWindowChangeCallback>;
    FProcessCallbacks: TDictionary<Integer, TProcessStateCallback>;
    FCallbackLock: TCriticalSection;
    FNextToken: Integer;
    FLastCallbackTime: Int64;
    FHealthCheckWnd: HWND;
    FIsRunning: Boolean;
    class var FActiveInstance: TWindowMonitor;

    class procedure WinEventCallback(hWinEventHook: HWINEVENTHOOK;
      event: DWORD; hwnd: HWND; idObject: LONG; idChild: LONG;
      dwEventThread: DWORD; dwmsEventTime: DWORD); stdcall; static;
    procedure HandleForegroundChange(hwnd: HWND);
    procedure NotifyCallbacks(const OldProc, NewProc: string;
      const OldTitle, NewTitle: string);
    procedure PollThreadProc;
    procedure CheckHookHealth;
    function GetProcessNameFromHWND(hwnd: HWND): string;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
    function IsRunning: Boolean;
    function GetForegroundProcessName: string;
    function GetForegroundWindowTitle: string;
    function GetForegroundWindowHandle: HWND;
    function IsProcessRunning(const ProcName: string): Boolean;
    function GetProcessID(const ProcName: string): DWORD;
    procedure AddWatchTarget(const ProcName: string; const ExpectedPath: string = '');
    procedure RemoveWatchTarget(const ProcName: string);
    function RegisterWindowCallback(const Callback: TWindowChangeCallback): Integer;
    function RegisterProcessCallback(const Callback: TProcessStateCallback): Integer;
    procedure UnregisterCallback(const Token: Integer);
  end;

implementation

constructor TWindowMonitor.Create;
begin
  inherited;
  FWatchTargets := TThreadList<string>.Create;
  FWatchTargetPaths := TDictionary<string, string>.Create;
  FWindowCallbacks := TDictionary<Integer, TWindowChangeCallback>.Create;
  FProcessCallbacks := TDictionary<Integer, TProcessStateCallback>.Create;
  FCallbackLock := TCriticalSection.Create;
  FPollEvent := TEvent.Create(nil, True, False, '');
  FNextToken := 1;
  FHealthCheckWnd := 0;
  FIsRunning := False;
end;

destructor TWindowMonitor.Destroy;
begin
  Stop;
  if FHealthCheckWnd <> 0 then
    DestroyWindow(FHealthCheckWnd);
  FWatchTargetPaths.Free;
  FWatchTargets.Free;
  FWindowCallbacks.Free;
  FProcessCallbacks.Free;
  FCallbackLock.Free;
  FPollEvent.Free;
  inherited;
end;

procedure TWindowMonitor.Start;
begin
  if FIsRunning then Exit;

  TInterlocked.Exchange(Pointer(FActiveInstance), Pointer(Self));
  MemoryBarrier;

  FHealthCheckWnd := AllocateHWnd(nil);

  FWinEventHook := SetWinEventHook(
    EVENT_SYSTEM_FOREGROUND, EVENT_SYSTEM_FOREGROUND,
    0, @TWindowMonitor.WinEventCallback, 0, 0, WINEVENT_OUTOFCONTEXT);

  if FWinEventHook = 0 then
  begin
    FActiveInstance := nil;
    raise EWindowMonitorError.Create('SetWinEventHook failed');
  end;

  FIsRunning := True;
  FPollEvent.ResetEvent;

  FPollThread := TThread.CreateAnonymousThread(PollThreadProc);
  FPollThread.FreeOnTerminate := False;
  FPollThread.Start;
end;

procedure TWindowMonitor.Stop;
begin
  if not FIsRunning then Exit;
  FIsRunning := False;

  FPollEvent.SetEvent;

  if FWinEventHook <> 0 then
  begin
    UnhookWinEvent(FWinEventHook);
    FWinEventHook := 0;
  end;

  if Assigned(FPollThread) then
  begin
    if FPollThread.WaitFor(5000) = wrTimeout then
    begin
      Logger.Warn('WindowMonitor: poll thread did not exit in 5s', 'WindowMonitor');
      FPollThread.Terminate;
    end;
    FreeAndNil(FPollThread);
  end;

  FActiveInstance := nil;
end;

function TWindowMonitor.IsRunning: Boolean;
begin
  Result := FIsRunning;
end;

class procedure TWindowMonitor.WinEventCallback(hWinEventHook: HWINEVENTHOOK;
  event: DWORD; hwnd: HWND; idObject: LONG; idChild: LONG;
  dwEventThread: DWORD; dwmsEventTime: DWORD); stdcall;
begin
  var Instance := FActiveInstance;
  if Instance = nil then Exit;

  try
    Instance.HandleForegroundChange(hwnd);
  except
    on E: Exception do
      Logger.ErrorFmt('WinEventCallback exception: %s', [E.Message], 'WindowMonitor');
  end;
end;

procedure TWindowMonitor.HandleForegroundChange(hwnd: HWND);
begin
  var NowTick := GetTickCount64;
  if (NowTick - FLastCallbackTime < 200) then
  begin
    var QuickProc := GetProcessNameFromHWND(hwnd);
    if SameText(QuickProc, FLastForegroundProc) then
      Exit;
  end;
  FLastCallbackTime := NowTick;

  var NewProc := GetProcessNameFromHWND(hwnd);
  if NewProc = '' then Exit;

  var NewTitle := '';
  var Targets := FWatchTargets.LockList;
  try
    if Targets.Contains(NewProc) then
    begin
      SetLength(NewTitle, 256);
      SetLength(NewTitle, InternalGetWindowText(hwnd, PChar(NewTitle), 256));
    end;
  finally
    FWatchTargets.UnlockList;
  end;

  var OldProc, OldTitle: string;
  FCallbackLock.Enter;
  try
    OldProc := FLastForegroundProc;
    OldTitle := FLastForegroundTitle;
    if (NewProc <> OldProc) or (NewTitle <> OldTitle) then
    begin
      FLastForegroundProc := NewProc;
      FLastForegroundTitle := NewTitle;
    end
    else
      Exit;
  finally
    FCallbackLock.Leave;
  end;

  TThread.Queue(nil, procedure
  begin
    try
      NotifyCallbacks(OldProc, NewProc, OldTitle, NewTitle);
    except
      on E: Exception do
        Logger.ErrorFmt('NotifyCallbacks exception: %s', [E.Message], 'WindowMonitor');
    end;
  end);
end;

procedure TWindowMonitor.NotifyCallbacks(const OldProc, NewProc: string;
  const OldTitle, NewTitle: string);
var
  Snapshot: TArray<TWindowChangeCallback>;
begin
  FCallbackLock.Enter;
  try
    Snapshot := FWindowCallbacks.Values.ToArray;
  finally
    FCallbackLock.Leave;
  end;

  for var CB in Snapshot do
  begin
    try
      CB(OldProc, NewProc, OldTitle, NewTitle);
    except
      on E: Exception do
        Logger.ErrorFmt('Window callback exception: %s', [E.Message], 'WindowMonitor');
    end;
  end;
end;

procedure TWindowMonitor.PollThreadProc;
begin
  NameThreadForDebugging('WindowMonitor');
  while FPollEvent.WaitFor(30000) = wrTimeout do
  begin
    try
      var Targets := FWatchTargets.LockList;
      try
        for var Target in Targets do
        begin
          var Running := IsProcessRunning(Target);
        end;
      finally
        FWatchTargets.UnlockList;
      end;
    except
      on E: Exception do
        Logger.ErrorFmt('PollThreadProc exception: %s', [E.Message], 'WindowMonitor');
    end;
  end;
end;

procedure TWindowMonitor.CheckHookHealth;
begin
  if FHealthCheckWnd <> 0 then
    PostMessage(FHealthCheckWnd, WM_NULL, 0, 0);
end;

function TWindowMonitor.GetForegroundProcessName: string;
begin
  var hwnd := GetForegroundWindow;
  Result := GetProcessNameFromHWND(hwnd);
end;

function TWindowMonitor.GetForegroundWindowTitle: string;
begin
  SetLength(Result, 256);
  var hwnd := GetForegroundWindow;
  SetLength(Result, InternalGetWindowText(hwnd, PChar(Result), 256));
end;

function TWindowMonitor.GetForegroundWindowHandle: HWND;
begin
  Result := GetForegroundWindow;
end;

function TWindowMonitor.IsProcessRunning(const ProcName: string): Boolean;
begin
  Result := False;
  var Snap := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if Snap = INVALID_HANDLE_VALUE then Exit;
  try
    var PE: TProcessEntry32;
    PE.dwSize := SizeOf(PE);
    if Process32First(Snap, PE) then
      repeat
        if SameText(PE.szExeFile, ProcName) then Exit(True);
      until not Process32Next(Snap, PE);
  finally
    CloseHandle(Snap);
  end;
end;

function TWindowMonitor.GetProcessID(const ProcName: string): DWORD;
begin
  Result := 0;
  var Snap := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if Snap = INVALID_HANDLE_VALUE then Exit;
  try
    var PE: TProcessEntry32;
    PE.dwSize := SizeOf(PE);
    if Process32First(Snap, PE) then
      repeat
        if SameText(PE.szExeFile, ProcName) then Exit(PE.th32ProcessID);
      until not Process32Next(Snap, PE);
  finally
    CloseHandle(Snap);
  end;
end;

procedure TWindowMonitor.AddWatchTarget(const ProcName: string; const ExpectedPath: string);
begin
  FWatchTargets.Add(ProcName);
  if ExpectedPath <> '' then
    FWatchTargetPaths.AddOrSetValue(ProcName, ExpectedPath);
end;

procedure TWindowMonitor.RemoveWatchTarget(const ProcName: string);
begin
  FWatchTargets.Remove(ProcName);
  FWatchTargetPaths.Remove(ProcName);
end;

function TWindowMonitor.RegisterWindowCallback(const Callback: TWindowChangeCallback): Integer;
begin
  FCallbackLock.Enter;
  try
    Inc(FNextToken);
    FWindowCallbacks.Add(FNextToken, Callback);
    Result := FNextToken;
  finally
    FCallbackLock.Leave;
  end;
end;

function TWindowMonitor.RegisterProcessCallback(const Callback: TProcessStateCallback): Integer;
begin
  FCallbackLock.Enter;
  try
    Inc(FNextToken);
    FProcessCallbacks.Add(FNextToken, Callback);
    Result := FNextToken;
  finally
    FCallbackLock.Leave;
  end;
end;

procedure TWindowMonitor.UnregisterCallback(const Token: Integer);
begin
  FCallbackLock.Enter;
  try
    FWindowCallbacks.Remove(Token);
    FProcessCallbacks.Remove(Token);
  finally
    FCallbackLock.Leave;
  end;
end;

function TWindowMonitor.GetProcessNameFromHWND(hwnd: HWND): string;
begin
  var PID: DWORD;
  GetWindowThreadProcessId(hwnd, PID);
  if PID = 0 then Exit('');

  var hProcess := OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, PID);
  if hProcess = 0 then Exit('');

  try
    SetLength(Result, MAX_PATH);
    var Len: DWORD := MAX_PATH;
    if QueryFullProcessImageName(hProcess, 0, PChar(Result), Len) then
    begin
      SetLength(Result, Len);
      Result := ExtractFileName(Result);
    end
    else
      Result := '';
  finally
    CloseHandle(hProcess);
  end;
end;

end.
