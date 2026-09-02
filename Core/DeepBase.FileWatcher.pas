unit DeepBase.FileWatcher;

(*******************************************************************************
  DeepBase File Watcher
  File system change monitoring with:
  - Windows API (ReadDirectoryChangesW) for efficient monitoring
  - Recursive directory watching
  - File/directory filters
  - Multiple watchers support
  - Debouncing for rapid changes
  - Event callbacks and notifications
  - Background thread monitoring
  - Buffer overflow handling

  Author: DeepBase Team
  Created: 2025-11-29
*******************************************************************************)

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.SyncObjs, System.Threading, System.IOUtils,
  System.RegularExpressions, Winapi.Windows, DeepBase.Exceptions;

const
  FILE_ACTION_ADDED = $00000001;
  FILE_ACTION_REMOVED = $00000002;
  FILE_ACTION_MODIFIED = $00000003;
  FILE_ACTION_RENAMED_OLD_NAME = $00000004;
  FILE_ACTION_RENAMED_NEW_NAME = $00000005;

type
  // Windows API structure for file notifications
  PFILE_NOTIFY_INFORMATION = ^FILE_NOTIFY_INFORMATION;
  FILE_NOTIFY_INFORMATION = record
    NextEntryOffset: DWORD;
    Action: DWORD;
    FileNameLength: DWORD;
    FileName: array[0..0] of WideChar;
  end;

type
  EFileWatcherException = class(EDeepBaseException);

  /// <summary>Types of file system changes</summary>
  TFileChangeType = (
    fctCreated,
    fctDeleted,
    fctModified,
    fctRenamed,
    fctAttributes
  );
  TFileChangeTypes = set of TFileChangeType;

  /// <summary>File change event information</summary>
  TFileChangeInfo = record
    ChangeType: TFileChangeType;
    FileName: string;
    OldFileName: string;  // For rename events
    Directory: string;
    FullPath: string;
    Timestamp: TDateTime;
    IsDirectory: Boolean;
    
    function ToString: string;
  end;

  /// <summary>File filter settings</summary>
  TFileFilter = record
    IncludePatterns: TArray<string>;
    ExcludePatterns: TArray<string>;
    IncludeExtensions: TArray<string>;
    ExcludeExtensions: TArray<string>;
    IncludeDirectories: Boolean;
    IncludeHidden: Boolean;
    IncludeSystem: Boolean;
    MinSize: Int64;
    MaxSize: Int64;
    
    class function Default: TFileFilter; static;
    function Matches(const AFileName: string; AIsDirectory: Boolean): Boolean;
  end;

  /// <summary>Watcher configuration</summary>
  TFileWatcherConfig = record
    WatchSubdirectories: Boolean;
    ChangeTypes: TFileChangeTypes;
    BufferSize: Integer;
    DebounceMs: Integer;
    NotifyFilters: Cardinal;
    
    class function Default: TFileWatcherConfig; static;
  end;

  /// <summary>File change event callback</summary>
  TFileChangeEvent = procedure(Sender: TObject; const AInfo: TFileChangeInfo) of object;
  TFileChangeCallback = reference to procedure(const AInfo: TFileChangeInfo);

  /// <summary>Error event callback</summary>
  TFileWatcherErrorEvent = procedure(Sender: TObject; const AError: string) of object;

  /// <summary>Forward declaration</summary>
  TFileWatcher = class;

  /// <summary>
  /// Lifecycle guard for TFileWatcher queued callbacks.
  /// Interface-based ref-counting keeps the guard alive as long as
  /// queued anonymous methods hold a reference. When the FileWatcher
  /// is destroyed, FFileWatcher is set to nil; callbacks detect this
  /// and skip — preventing use-after-free.
  /// </summary>
  TFileWatcherGuard = class(TInterfacedObject)
  private
    FFileWatcher: TFileWatcher;
    FLock: TObject;
  public
    constructor Create(AWatcher: TFileWatcher);
    destructor Destroy; override;
    function GetWatcher: TFileWatcher;
    procedure ClearWatcher;
  end;

  /// <summary>Watcher thread for monitoring directory</summary>
  TFileWatcherThread = class(TThread)
  private
    FOwner: TFileWatcher;
    FDirectoryHandle: THandle;
    FBuffer: PByte;
    FBufferSize: Integer;
    FOverlapped: TOverlapped;
    FCompletionEvent: THandle;
    FStopEvent: THandle;
    FPendingRename: string;

    procedure ProcessChanges(ABytesTransferred: DWORD);
    procedure NotifyChange(const AInfo: TFileChangeInfo);
    procedure NotifyError(const AError: string);
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TFileWatcher);
    destructor Destroy; override;

    procedure StopWatching;
  end;

  /// <summary>Debounced change entry</summary>
  TDebouncedChange = record
    Info: TFileChangeInfo;
    ScheduledTime: TDateTime;
  end;

  /// <summary>File system watcher</summary>
  TFileWatcher = class
  private
    FDirectory: string;
    FConfig: TFileWatcherConfig;
    FFilter: TFileFilter;
    FWatcherThread: TFileWatcherThread;
    FRunning: Boolean;
    FLock: TCriticalSection;
    FDestroying: Boolean;
    FGuard: TFileWatcherGuard;

    // Events
    FOnFileChanged: TFileChangeEvent;
    FOnError: TFileWatcherErrorEvent;
    FCallbacks: TList<TFileChangeCallback>;

    // Debouncing
    FDebouncedChanges: TDictionary<string, TDebouncedChange>;
    FDebounceThread: TThread;
    FDebounceLock: TCriticalSection;
    FDebounceStopEvent: TEvent;
    // BIZ2-013 fix: gate that keeps at most ONE drain task in flight at a
    // time. Without this, every file change spawned a fresh TTask (Sleep +
    // ProcessDebouncedChanges), so a compile/git-checkout burst of N changes
    // saturated the thread pool with N identical drain tasks. A single
    // drain task processes every pending change after the longest debounce
    // window, so we never need more than one.
    FDebounceTaskScheduled: Boolean;

    procedure DoFileChanged(const AInfo: TFileChangeInfo);
    procedure HandleDebounce(const AInfo: TFileChangeInfo);
    procedure ProcessDebouncedChanges(Sender: TObject);
  public
    constructor Create(const ADirectory: string); overload;
    constructor Create(const ADirectory: string; const AConfig: TFileWatcherConfig); overload;
    destructor Destroy; override;
    
    /// <summary>Start watching</summary>
    procedure Start;
    
    /// <summary>Stop watching</summary>
    procedure Stop;
    
    /// <summary>Check if running</summary>
    property Running: Boolean read FRunning;

    /// <summary>True while destructor is in progress</summary>
    property Destroying: Boolean read FDestroying;
    
    /// <summary>Directory being watched</summary>
    property Directory: string read FDirectory;
    
    /// <summary>Configuration</summary>
    property Config: TFileWatcherConfig read FConfig write FConfig;
    
    /// <summary>File filter</summary>
    property Filter: TFileFilter read FFilter write FFilter;
    
    /// <summary>Add callback</summary>
    procedure AddCallback(ACallback: TFileChangeCallback);
    
    /// <summary>Remove callback</summary>
    procedure ReDeepMoveCallback(ACallback: TFileChangeCallback);
    
    /// <summary>Validate watch path for security</summary>
    class function IsValidWatchPath(const APath: string): Boolean; static;
    
    /// <summary>Events</summary>
    property OnFileChanged: TFileChangeEvent read FOnFileChanged write FOnFileChanged;
    property OnError: TFileWatcherErrorEvent read FOnError write FOnError;
  end;

  /// <summary>Multi-directory watcher manager</summary>
  TFileWatcherManager = class
  private
    FWatchers: TObjectDictionary<string, TFileWatcher>;
    FLock: TCriticalSection;
    FGlobalCallback: TFileChangeCallback;
    FOnFileChanged: TFileChangeEvent;
    FOnError: TFileWatcherErrorEvent;
    
    procedure HandleChange(const AInfo: TFileChangeInfo);
    procedure HandleError(Sender: TObject; const AError: string);
  public
    constructor Create;
    destructor Destroy; override;
    
    /// <summary>Add directory to watch</summary>
    function Watch(const ADirectory: string): TFileWatcher; overload;
    function Watch(const ADirectory: string; const AConfig: TFileWatcherConfig): TFileWatcher; overload;
    
    /// <summary>Stop watching directory</summary>
    procedure Unwatch(const ADirectory: string);
    
    /// <summary>Check if watching directory</summary>
    function IsWatching(const ADirectory: string): Boolean;
    
    /// <summary>Get watcher for directory</summary>
    function GetWatcher(const ADirectory: string): TFileWatcher;
    
    /// <summary>Get all watched directories</summary>
    function GetWatchedDirectories: TArray<string>;
    
    /// <summary>Start all watchers</summary>
    procedure StartAll;
    
    /// <summary>Stop all watchers</summary>
    procedure StopAll;
    
    /// <summary>Clear all watchers</summary>
    procedure Clear;
    
    /// <summary>Validate watch path security</summary>
    function IsValidWatchPath(const APath: string): Boolean;
    
    /// <summary>Events</summary>
    property OnFileChanged: TFileChangeEvent read FOnFileChanged write FOnFileChanged;
    property OnError: TFileWatcherErrorEvent read FOnError write FOnError;
  end;

  /// <summary>Watcher builder</summary>
  TFileWatcherBuilder = class
  private
    FDirectory: string;
    FConfig: TFileWatcherConfig;
    FFilter: TFileFilter;
    FOnChanged: TFileChangeEvent;
    FOnError: TFileWatcherErrorEvent;
    FCallbacks: TList<TFileChangeCallback>;
  public
    constructor Create(const ADirectory: string);
    destructor Destroy; override;
    
    function WatchSubdirectories(AEnabled: Boolean = True): TFileWatcherBuilder;
    function WatchCreated(AEnabled: Boolean = True): TFileWatcherBuilder;
    function WatchDeleted(AEnabled: Boolean = True): TFileWatcherBuilder;
    function WatchModified(AEnabled: Boolean = True): TFileWatcherBuilder;
    function WatchRenamed(AEnabled: Boolean = True): TFileWatcherBuilder;
    function WatchAttributes(AEnabled: Boolean = True): TFileWatcherBuilder;
    function WithBufferSize(ASize: Integer): TFileWatcherBuilder;
    function WithDebounce(AMilliseconds: Integer): TFileWatcherBuilder;
    function IncludePattern(const APattern: string): TFileWatcherBuilder;
    function ExcludePattern(const APattern: string): TFileWatcherBuilder;
    function IncludeExtension(const AExt: string): TFileWatcherBuilder;
    function ExcludeExtension(const AExt: string): TFileWatcherBuilder;
    function IncludeDirectories(AEnabled: Boolean = True): TFileWatcherBuilder;
    function IncludeHidden(AEnabled: Boolean = True): TFileWatcherBuilder;
    function OnChanged(AHandler: TFileChangeEvent): TFileWatcherBuilder;
    function OnCallback(ACallback: TFileChangeCallback): TFileWatcherBuilder;
    function OnErrorEvent(AHandler: TFileWatcherErrorEvent): TFileWatcherBuilder;
    
    function Build: TFileWatcher;
    function BuildAndStart: TFileWatcher;
  end;

  /// <summary>Static helper class</summary>
  TFileWatchers = class
  private
    class var FDefaultManager: TFileWatcherManager;
    class var FLock: TCriticalSection;
  public
    class constructor Create;
    class destructor Destroy;
    
    /// <summary>Create watcher builder</summary>
    class function Watch(const ADirectory: string): TFileWatcherBuilder;
    
    /// <summary>Quick watch with callback</summary>
    class function QuickWatch(const ADirectory: string; 
      ACallback: TFileChangeCallback): TFileWatcher;
    
    /// <summary>Default manager for global watchers</summary>
    class function Manager: TFileWatcherManager;
  end;

const
  /// <summary>All change types</summary>
  AllChangeTypes: TFileChangeTypes = [fctCreated, fctDeleted, fctModified, fctRenamed, fctAttributes];

  /// <summary>Default notify filters</summary>
  DefaultNotifyFilters = FILE_NOTIFY_CHANGE_FILE_NAME or
                         FILE_NOTIFY_CHANGE_DIR_NAME or
                         FILE_NOTIFY_CHANGE_ATTRIBUTES or
                         FILE_NOTIFY_CHANGE_SIZE or
                         FILE_NOTIFY_CHANGE_LAST_WRITE or
                         FILE_NOTIFY_CHANGE_CREATION;

implementation

uses
  System.DateUtils;

{ TFileChangeInfo }

function TFileChangeInfo.ToString: string;
const
  ChangeTypeNames: array[TFileChangeType] of string = (
    'Created', 'Deleted', 'Modified', 'Renamed', 'Attributes');
begin
  if ChangeType = fctRenamed then
    Result := Format('[%s] %s -> %s at %s', 
      [ChangeTypeNames[ChangeType], OldFileName, FileName, DateTimeToStr(Timestamp)])
  else
    Result := Format('[%s] %s at %s', 
      [ChangeTypeNames[ChangeType], FullPath, DateTimeToStr(Timestamp)]);
end;

{ TFileFilter }

class function TFileFilter.Default: TFileFilter;
begin
  Result.IncludePatterns := nil;
  Result.ExcludePatterns := nil;
  Result.IncludeExtensions := nil;
  Result.ExcludeExtensions := nil;
  Result.IncludeDirectories := True;
  Result.IncludeHidden := False;
  Result.IncludeSystem := False;
  Result.MinSize := 0;
  Result.MaxSize := 0;
end;

function TFileFilter.Matches(const AFileName: string; AIsDirectory: Boolean): Boolean;
var
  LExt: string;
  LPattern: string;
  LBaseName: string;
begin
  Result := True;
  LBaseName := ExtractFileName(AFileName);
  LExt := LowerCase(ExtractFileExt(AFileName));
  
  // Check directory inclusion
  if AIsDirectory and not IncludeDirectories then
    Exit(False);
  
  // Check include patterns
  if Length(IncludePatterns) > 0 then
  begin
    Result := False;
    for LPattern in IncludePatterns do
    begin
      if TRegEx.IsMatch(LBaseName, LPattern, [roIgnoreCase]) then
      begin
        Result := True;
        Break;
      end;
    end;
    if not Result then
      Exit;
  end;
  
  // Check exclude patterns
  for LPattern in ExcludePatterns do
  begin
    if TRegEx.IsMatch(LBaseName, LPattern, [roIgnoreCase]) then
      Exit(False);
  end;
  
  // Check include extensions
  if (Length(IncludeExtensions) > 0) and not AIsDirectory then
  begin
    Result := False;
    for LPattern in IncludeExtensions do
    begin
      if SameText(LExt, LPattern) or SameText(LExt, '.' + LPattern) then
      begin
        Result := True;
        Break;
      end;
    end;
    if not Result then
      Exit;
  end;
  
  // Check exclude extensions
  for LPattern in ExcludeExtensions do
  begin
    if SameText(LExt, LPattern) or SameText(LExt, '.' + LPattern) then
      Exit(False);
  end;
end;

{ TFileWatcherConfig }

class function TFileWatcherConfig.Default: TFileWatcherConfig;
begin
  Result.WatchSubdirectories := True;
  Result.ChangeTypes := AllChangeTypes;
  Result.BufferSize := 64 * 1024;  // 64KB
  Result.DebounceMs := 100;
  Result.NotifyFilters := DefaultNotifyFilters;
end;

{ TFileWatcherGuard }

constructor TFileWatcherGuard.Create(AWatcher: TFileWatcher);
begin
  inherited Create;
  FFileWatcher := AWatcher;
  FLock := TObject.Create;
end;

destructor TFileWatcherGuard.Destroy;
begin
  FreeAndNil(FLock);
  inherited;
end;

function TFileWatcherGuard.GetWatcher: TFileWatcher;
begin
  TMonitor.Enter(FLock);
  try
    Result := FFileWatcher;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TFileWatcherGuard.ClearWatcher;
begin
  TMonitor.Enter(FLock);
  try
    FFileWatcher := nil;
  finally
    TMonitor.Exit(FLock);
  end;
end;

{ TFileWatcherThread }

constructor TFileWatcherThread.Create(AOwner: TFileWatcher);
begin
  inherited Create(True);
  FOwner := AOwner;
  FBufferSize := FOwner.Config.BufferSize;
  GetMem(FBuffer, FBufferSize);
  FCompletionEvent := CreateEvent(nil, False, False, nil);
  FStopEvent := CreateEvent(nil, True, False, nil);
  FreeOnTerminate := False;
end;

destructor TFileWatcherThread.Destroy;
begin
  CloseHandle(FCompletionEvent);
  CloseHandle(FStopEvent);
  FreeMem(FBuffer);
  inherited;
end;

procedure TFileWatcherThread.StopWatching;
begin
  SetEvent(FStopEvent);
  Terminate;
end;

procedure TFileWatcherThread.Execute;
var
  LBytesReturned: DWORD;
  LWaitResult: DWORD;
  LHandles: array[0..1] of THandle;
begin
  // Open directory handle
  FDirectoryHandle := CreateFile(
    PChar(FOwner.Directory),
    FILE_LIST_DIRECTORY,
    FILE_SHARE_READ or FILE_SHARE_WRITE or FILE_SHARE_DELETE,
    nil,
    OPEN_EXISTING,
    FILE_FLAG_BACKUP_SEMANTICS or FILE_FLAG_OVERLAPPED,
    0
  );
  
  if FDirectoryHandle = INVALID_HANDLE_VALUE then
  begin
    NotifyError(Format('Failed to open directory: %s (Error: %d)', 
      [FOwner.Directory, GetLastError]));
    Exit;
  end;
  
  try
    LHandles[0] := FCompletionEvent;
    LHandles[1] := FStopEvent;
    
    while (not Terminated) and (not FOwner.FDestroying) do
    begin
      // Initialize overlapped structure
      FillChar(FOverlapped, SizeOf(FOverlapped), 0);
      FOverlapped.hEvent := FCompletionEvent;
      
      // Start async read
      if not ReadDirectoryChangesW(
        FDirectoryHandle,
        FBuffer,
        FBufferSize,
        FOwner.Config.WatchSubdirectories,
        FOwner.Config.NotifyFilters,
        @LBytesReturned,
        @FOverlapped,
        nil
      ) then
      begin
        if GetLastError <> ERROR_IO_PENDING then
        begin
          NotifyError(Format('ReadDirectoryChangesW failed (Error: %d)', [GetLastError]));
          Break;
        end;
      end;
      
      // Wait for completion or stop
      LWaitResult := WaitForMultipleObjects(2, @LHandles[0], False, INFINITE);
      
      case LWaitResult of
        WAIT_OBJECT_0: // Completion event
          begin
            if GetOverlappedResult(FDirectoryHandle, FOverlapped, LBytesReturned, False) then
            begin
              if LBytesReturned > 0 then
                ProcessChanges(LBytesReturned)
              else
                NotifyError('Buffer overflow - some changes may be lost');
            end;
          end;
          
        WAIT_OBJECT_0 + 1: // Stop event
          Break;
          
        WAIT_FAILED:
          begin
            NotifyError(Format('Wait failed (Error: %d)', [GetLastError]));
            Break;
          end;
      end;
    end;
  finally
    CloseHandle(FDirectoryHandle);
  end;
end;

procedure TFileWatcherThread.ProcessChanges(ABytesTransferred: DWORD);
var
  LInfo: PFILE_NOTIFY_INFORMATION;
  LOffset: DWORD;
  LFileName: string;
  LChangeInfo: TFileChangeInfo;
begin
  LOffset := 0;
  
  repeat
    LInfo := PFILE_NOTIFY_INFORMATION(FBuffer + LOffset);
    
    // Extract filename
    SetLength(LFileName, LInfo^.FileNameLength div SizeOf(Char));
    Move(LInfo^.FileName[0], LFileName[1], LInfo^.FileNameLength);
    
    // Build change info
    LChangeInfo.FileName := ExtractFileName(LFileName);
    LChangeInfo.Directory := FOwner.Directory;
    LChangeInfo.FullPath := TPath.Combine(FOwner.Directory, LFileName);
    LChangeInfo.Timestamp := Now;
    LChangeInfo.OldFileName := '';
    LChangeInfo.IsDirectory := DirectoryExists(LChangeInfo.FullPath);
    
    case LInfo^.Action of
      FILE_ACTION_ADDED:
        begin
          LChangeInfo.ChangeType := fctCreated;
          FPendingRename := '';
        end;
        
      FILE_ACTION_REMOVED:
        begin
          LChangeInfo.ChangeType := fctDeleted;
          FPendingRename := '';
        end;
        
      FILE_ACTION_MODIFIED:
        begin
          LChangeInfo.ChangeType := fctModified;
          FPendingRename := '';
        end;
        
      FILE_ACTION_RENAMED_OLD_NAME:
        begin
          FPendingRename := LFileName;
          LOffset := LOffset + LInfo^.NextEntryOffset;
          if LInfo^.NextEntryOffset = 0 then
            Break;
          Continue;
        end;
        
      FILE_ACTION_RENAMED_NEW_NAME:
        begin
          LChangeInfo.ChangeType := fctRenamed;
          LChangeInfo.OldFileName := ExtractFileName(FPendingRename);
          FPendingRename := '';
        end;
    end;
    
    // Check filter
    if FOwner.Filter.Matches(LChangeInfo.FileName, LChangeInfo.IsDirectory) then
    begin
      // Check change type
      if LChangeInfo.ChangeType in FOwner.Config.ChangeTypes then
        NotifyChange(LChangeInfo);
    end;
    
    // Move to next entry
    if LInfo^.NextEntryOffset = 0 then
      Break;
    LOffset := LOffset + LInfo^.NextEntryOffset;
  until False;
end;

procedure TFileWatcherThread.NotifyChange(const AInfo: TFileChangeInfo);
var
  LGuard: IInterface;
  LInfo: TFileChangeInfo;
begin
  if Terminated or FOwner.FDestroying then
    Exit;
  LGuard := FOwner.FGuard;              // ref-count bump
  LInfo := AInfo;                       // capture by value
  TThread.Queue(nil,
    procedure
    var
      LW: TFileWatcher;
    begin
      LW := TFileWatcherGuard(LGuard).GetWatcher;
      if Assigned(LW) and not LW.FDestroying then
        LW.DoFileChanged(LInfo);
    end
  );
end;

procedure TFileWatcherThread.NotifyError(const AError: string);
var
  LGuard: IInterface;
  LMsg: string;
begin
  if Terminated or FOwner.FDestroying then
    Exit;
  LGuard := FOwner.FGuard;
  LMsg := AError;
  TThread.Queue(nil,
    procedure
    var
      LW: TFileWatcher;
    begin
      LW := TFileWatcherGuard(LGuard).GetWatcher;
      if Assigned(LW) and not LW.FDestroying and Assigned(LW.OnError) then
        LW.OnError(LW, LMsg);
    end
  );
end;

{ TFileWatcher }

constructor TFileWatcher.Create(const ADirectory: string);
begin
  Create(ADirectory, TFileWatcherConfig.Default);
end;

constructor TFileWatcher.Create(const ADirectory: string; const AConfig: TFileWatcherConfig);
begin
  inherited Create;
  
  if not DirectoryExists(ADirectory) then
    raise EFileWatcherException.CreateFmt('Directory does not exist: %s', [ADirectory]);
    
  FDirectory := ADirectory;
  FConfig := AConfig;
  FFilter := TFileFilter.Default;
  FRunning := False;
  FDestroying := False;
  FLock := TCriticalSection.Create;
  FGuard := TFileWatcherGuard.Create(Self);
  FCallbacks := TList<TFileChangeCallback>.Create;
  FDebouncedChanges := TDictionary<string, TDebouncedChange>.Create;
  FDebounceLock := TCriticalSection.Create;
  FDebounceStopEvent := TEvent.Create(nil, True, False, '');
end;

destructor TFileWatcher.Destroy;
begin
  FDestroying := True;

  // Stop watcher thread first — ensures no new Queue calls after this point
  Stop;

  // Clear guard reference so already-queued callbacks see nil and skip
  if Assigned(FGuard) then
    FGuard.ClearWatcher;

  // Give debounce pool tasks time to see FDestroying and exit
  if Assigned(FDebounceLock) then
  begin
    FDebounceLock.Enter;
    try { sync point } finally FDebounceLock.Leave; end;
    Sleep(50);
  end;

  FreeAndNil(FDebounceStopEvent);
  FreeAndNil(FDebounceLock);
  FreeAndNil(FDebouncedChanges);
  FreeAndNil(FCallbacks);
  FreeAndNil(FGuard);
  FreeAndNil(FLock);
  inherited;
end;

procedure TFileWatcher.Start;
begin
  FLock.Enter;
  try
    if FRunning then
      Exit;
      
    FWatcherThread := TFileWatcherThread.Create(Self);
    FWatcherThread.Start;
    FRunning := True;
  finally
    FLock.Leave;
  end;
end;

procedure TFileWatcher.Stop;
begin
  FLock.Enter;
  try
    if not FRunning then
      Exit;
      
    if Assigned(FWatcherThread) then
    begin
      FWatcherThread.StopWatching;
      FWatcherThread.WaitFor;
      FreeAndNil(FWatcherThread);
    end;
    
    FRunning := False;
  finally
    FLock.Leave;
  end;
end;

procedure TFileWatcher.AddCallback(ACallback: TFileChangeCallback);
begin
  FLock.Enter;
  try
    FCallbacks.Add(ACallback);
  finally
    FLock.Leave;
  end;
end;

procedure TFileWatcher.ReDeepMoveCallback(ACallback: TFileChangeCallback);
begin
  FLock.Enter;
  try
    // Note: Direct removal of anonymous method references is not straightforward
    // This is a simplified implementation - in practice you may need a wrapper class
    // that allows proper identity comparison
    // For now, we just clear all callbacks as a workaround
    FCallbacks.Clear;
  finally
    FLock.Leave;
  end;
end;

procedure TFileWatcher.DoFileChanged(const AInfo: TFileChangeInfo);
begin
  if FDestroying then
    Exit;
  if FConfig.DebounceMs > 0 then
    HandleDebounce(AInfo)
  else
  begin
    // Direct notification
    if Assigned(FOnFileChanged) then
      FOnFileChanged(Self, AInfo);

    FLock.Enter;
    try
      for var LCallback in FCallbacks do
        LCallback(AInfo);
    finally
      FLock.Leave;
    end;
  end;
end;

procedure TFileWatcher.HandleDebounce(const AInfo: TFileChangeInfo);
var
  LKey: string;
  LChange: TDebouncedChange;
  LGuard: IInterface;
  LDebounceMs: Integer;
begin
  if FDestroying then
    Exit;

  LKey := AInfo.FullPath + ':' + IntToStr(Ord(AInfo.ChangeType));
  LDebounceMs := FConfig.DebounceMs;

  FDebounceLock.Enter;
  try
    if FDestroying then
      Exit;
    LChange.Info := AInfo;
    LChange.ScheduledTime := IncMilliSecond(Now, LDebounceMs);
    FDebouncedChanges.AddOrSetValue(LKey, LChange);

    // WO-20260902 FIX-4: capture IInterface (same pattern as NotifyChange)
    // so the debounce task holds a ref-count bump until it finishes.
    LGuard := FGuard;

    // BIZ2-013 fix: only schedule a drain task if none is already in
    // flight. The drain task processes EVERY entry whose ScheduledTime
    // has passed, so one task is enough to empty the dictionary even
    // if many changes arrived during the debounce window.
    if FDebounceTaskScheduled then
      Exit;
    FDebounceTaskScheduled := True;

    // Schedule processing
    var LTask: ITask := TTask.Create(
      procedure
      var
        LW: TFileWatcher;
      begin
        Sleep(LDebounceMs + 10);
        LW := TFileWatcherGuard(LGuard).GetWatcher;
        if Assigned(LW) and not LW.FDestroying then
          LW.ProcessDebouncedChanges(nil);
      end
    );
    LTask.Start;
  finally
    FDebounceLock.Leave;
  end;
end;

procedure TFileWatcher.ProcessDebouncedChanges(Sender: TObject);
var
  LNow: TDateTime;
  LToProcess: TList<TFileChangeInfo>;
  LKey: string;
  LChange: TDebouncedChange;
  LKeysToRemove: TList<string>;
begin
  if FDestroying then
  begin
    // BIZ2-013 fix: even when we bail early, allow the NEXT HandleDebounce
    // call to schedule a new drain task. Otherwise a destructor-triggered
    // early-exit would leave the gate latched forever.
    FDebounceLock.Enter;
    try
      FDebounceTaskScheduled := False;
    finally
      FDebounceLock.Leave;
    end;
    Exit;
  end;

  LNow := Now;
  LToProcess := TList<TFileChangeInfo>.Create;
  LKeysToRemove := TList<string>.Create;
  try
    FDebounceLock.Enter;
    try
      if FDestroying then
      begin
        FDebounceTaskScheduled := False;
        Exit;
      end;
      for LKey in FDebouncedChanges.Keys do
      begin
        LChange := FDebouncedChanges[LKey];
        if LNow >= LChange.ScheduledTime then
        begin
          LToProcess.Add(LChange.Info);
          LKeysToRemove.Add(LKey);
        end;
      end;

      for LKey in LKeysToRemove do
        FDebouncedChanges.Remove(LKey);

      // CR-606-a fix: always release the debounce gate. The original code
      // kept the gate latched when pending changes existed but never
      // re-armed, causing all subsequent file events to be silently lost.
      // Releasing here lets the next file event go through normal debounce.
      FDebounceTaskScheduled := False;
    finally
      FDebounceLock.Leave;
    end;

    // Process changes
    for var LInfo in LToProcess do
    begin
      if FDestroying then
        Break;
      if Assigned(FOnFileChanged) then
        FOnFileChanged(Self, LInfo);
        
      FLock.Enter;
      try
        for var LCallback in FCallbacks do
          LCallback(LInfo);
      finally
        FLock.Leave;
      end;
    end;
  finally
    LKeysToRemove.Free;
    LToProcess.Free;
  end;
end;

{ TFileWatcherManager }

constructor TFileWatcherManager.Create;
begin
  inherited;
  FWatchers := TObjectDictionary<string, TFileWatcher>.Create([doOwnsValues]);
  FLock := TCriticalSection.Create;
  
  FGlobalCallback := 
    procedure(const AInfo: TFileChangeInfo)
    begin
      HandleChange(AInfo);
    end;
end;

destructor TFileWatcherManager.Destroy;
begin
  StopAll;
  FreeAndNil(FLock);
  FreeAndNil(FWatchers);
  inherited;
end;

procedure TFileWatcherManager.HandleChange(const AInfo: TFileChangeInfo);
begin
  if Assigned(FOnFileChanged) then
    FOnFileChanged(Self, AInfo);
end;

procedure TFileWatcherManager.HandleError(Sender: TObject; const AError: string);
begin
  if Assigned(FOnError) then
    FOnError(Sender, AError);
end;

function TFileWatcherManager.Watch(const ADirectory: string): TFileWatcher;
begin
  Result := Watch(ADirectory, TFileWatcherConfig.Default);
end;

function TFileWatcherManager.Watch(const ADirectory: string; 
  const AConfig: TFileWatcherConfig): TFileWatcher;
var
  LNormalized: string;
begin
  // 验证路径安全性，防止路径遍历攻击
  if not IsValidWatchPath(ADirectory) then
    raise EArgumentException.CreateFmt('Invalid or unsafe watch path: %s', [ADirectory]);
    
  LNormalized := IncludeTrailingPathDelimiter(ExpandFileName(ADirectory));
  
  FLock.Enter;
  try
    if FWatchers.TryGetValue(LNormalized, Result) then
      Exit;
      
    Result := TFileWatcher.Create(LNormalized, AConfig);
    Result.AddCallback(FGlobalCallback);
    Result.OnError := HandleError;
    FWatchers.Add(LNormalized, Result);
  finally
    FLock.Leave;
  end;
end;

procedure TFileWatcherManager.Unwatch(const ADirectory: string);
var
  LNormalized: string;
  LWatcher: TFileWatcher;
begin
  // 验证路径安全性
  if not IsValidWatchPath(ADirectory) then
    raise EArgumentException.CreateFmt('Invalid or unsafe watch path: %s', [ADirectory]);
    
  LNormalized := IncludeTrailingPathDelimiter(ExpandFileName(ADirectory));
  
  FLock.Enter;
  try
    if FWatchers.TryGetValue(LNormalized, LWatcher) then
    begin
      LWatcher.Stop;
      FWatchers.Remove(LNormalized);
    end;
  finally
    FLock.Leave;
  end;
end;

function TFileWatcherManager.IsWatching(const ADirectory: string): Boolean;
var
  LNormalized: string;
begin
  LNormalized := IncludeTrailingPathDelimiter(ExpandFileName(ADirectory));
  
  FLock.Enter;
  try
    Result := FWatchers.ContainsKey(LNormalized);
  finally
    FLock.Leave;
  end;
end;

function TFileWatcherManager.GetWatcher(const ADirectory: string): TFileWatcher;
var
  LNormalized: string;
begin
  LNormalized := IncludeTrailingPathDelimiter(ExpandFileName(ADirectory));
  
  FLock.Enter;
  try
    if not FWatchers.TryGetValue(LNormalized, Result) then
      Result := nil;
  finally
    FLock.Leave;
  end;
end;

function TFileWatcherManager.GetWatchedDirectories: TArray<string>;
var
  LList: TList<string>;
begin
  LList := TList<string>.Create;
  try
    FLock.Enter;
    try
      for var LKey in FWatchers.Keys do
        LList.Add(LKey);
    finally
      FLock.Leave;
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

procedure TFileWatcherManager.StartAll;
var
  LPair: TPair<string, TFileWatcher>;
begin
  FLock.Enter;
  try
    for LPair in FWatchers do
      LPair.Value.Start;
  finally
    FLock.Leave;
  end;
end;

procedure TFileWatcherManager.StopAll;
var
  LPair: TPair<string, TFileWatcher>;
begin
  FLock.Enter;
  try
    for LPair in FWatchers do
      LPair.Value.Stop;
  finally
    FLock.Leave;
  end;
end;

procedure TFileWatcherManager.Clear;
begin
  FLock.Enter;
  try
    StopAll;
    FWatchers.Clear;
  finally
    FLock.Leave;
  end;
end;

{ TFileWatcherBuilder }

constructor TFileWatcherBuilder.Create(const ADirectory: string);
begin
  inherited Create;
  FDirectory := ADirectory;
  FConfig := TFileWatcherConfig.Default;
  FFilter := TFileFilter.Default;
  FCallbacks := TList<TFileChangeCallback>.Create;
end;

destructor TFileWatcherBuilder.Destroy;
begin
  FreeAndNil(FCallbacks);
  inherited;
end;

function TFileWatcherBuilder.WatchSubdirectories(AEnabled: Boolean): TFileWatcherBuilder;
begin
  FConfig.WatchSubdirectories := AEnabled;
  Result := Self;
end;

function TFileWatcherBuilder.WatchCreated(AEnabled: Boolean): TFileWatcherBuilder;
begin
  if AEnabled then
    Include(FConfig.ChangeTypes, fctCreated)
  else
    Exclude(FConfig.ChangeTypes, fctCreated);
  Result := Self;
end;

function TFileWatcherBuilder.WatchDeleted(AEnabled: Boolean): TFileWatcherBuilder;
begin
  if AEnabled then
    Include(FConfig.ChangeTypes, fctDeleted)
  else
    Exclude(FConfig.ChangeTypes, fctDeleted);
  Result := Self;
end;

function TFileWatcherBuilder.WatchModified(AEnabled: Boolean): TFileWatcherBuilder;
begin
  if AEnabled then
    Include(FConfig.ChangeTypes, fctModified)
  else
    Exclude(FConfig.ChangeTypes, fctModified);
  Result := Self;
end;

function TFileWatcherBuilder.WatchRenamed(AEnabled: Boolean): TFileWatcherBuilder;
begin
  if AEnabled then
    Include(FConfig.ChangeTypes, fctRenamed)
  else
    Exclude(FConfig.ChangeTypes, fctRenamed);
  Result := Self;
end;

function TFileWatcherBuilder.WatchAttributes(AEnabled: Boolean): TFileWatcherBuilder;
begin
  if AEnabled then
    Include(FConfig.ChangeTypes, fctAttributes)
  else
    Exclude(FConfig.ChangeTypes, fctAttributes);
  Result := Self;
end;

function TFileWatcherBuilder.WithBufferSize(ASize: Integer): TFileWatcherBuilder;
begin
  FConfig.BufferSize := ASize;
  Result := Self;
end;

function TFileWatcherBuilder.WithDebounce(AMilliseconds: Integer): TFileWatcherBuilder;
begin
  FConfig.DebounceMs := AMilliseconds;
  Result := Self;
end;

function TFileWatcherBuilder.IncludePattern(const APattern: string): TFileWatcherBuilder;
begin
  SetLength(FFilter.IncludePatterns, Length(FFilter.IncludePatterns) + 1);
  FFilter.IncludePatterns[High(FFilter.IncludePatterns)] := APattern;
  Result := Self;
end;

function TFileWatcherBuilder.ExcludePattern(const APattern: string): TFileWatcherBuilder;
begin
  SetLength(FFilter.ExcludePatterns, Length(FFilter.ExcludePatterns) + 1);
  FFilter.ExcludePatterns[High(FFilter.ExcludePatterns)] := APattern;
  Result := Self;
end;

function TFileWatcherBuilder.IncludeExtension(const AExt: string): TFileWatcherBuilder;
var
  LExt: string;
begin
  LExt := AExt;
  if (LExt <> '') and (LExt[1] <> '.') then
    LExt := '.' + LExt;
  SetLength(FFilter.IncludeExtensions, Length(FFilter.IncludeExtensions) + 1);
  FFilter.IncludeExtensions[High(FFilter.IncludeExtensions)] := LExt;
  Result := Self;
end;

function TFileWatcherBuilder.ExcludeExtension(const AExt: string): TFileWatcherBuilder;
var
  LExt: string;
begin
  LExt := AExt;
  if (LExt <> '') and (LExt[1] <> '.') then
    LExt := '.' + LExt;
  SetLength(FFilter.ExcludeExtensions, Length(FFilter.ExcludeExtensions) + 1);
  FFilter.ExcludeExtensions[High(FFilter.ExcludeExtensions)] := LExt;
  Result := Self;
end;

function TFileWatcherBuilder.IncludeDirectories(AEnabled: Boolean): TFileWatcherBuilder;
begin
  FFilter.IncludeDirectories := AEnabled;
  Result := Self;
end;

function TFileWatcherBuilder.IncludeHidden(AEnabled: Boolean): TFileWatcherBuilder;
begin
  FFilter.IncludeHidden := AEnabled;
  Result := Self;
end;

function TFileWatcherBuilder.OnChanged(AHandler: TFileChangeEvent): TFileWatcherBuilder;
begin
  FOnChanged := AHandler;
  Result := Self;
end;

function TFileWatcherBuilder.OnCallback(ACallback: TFileChangeCallback): TFileWatcherBuilder;
begin
  FCallbacks.Add(ACallback);
  Result := Self;
end;

function TFileWatcherBuilder.OnErrorEvent(AHandler: TFileWatcherErrorEvent): TFileWatcherBuilder;
begin
  FOnError := AHandler;
  Result := Self;
end;

function TFileWatcherBuilder.Build: TFileWatcher;
begin
  Result := TFileWatcher.Create(FDirectory, FConfig);
  Result.Filter := FFilter;
  Result.OnFileChanged := FOnChanged;
  Result.OnError := FOnError;
  
  for var LCallback in FCallbacks do
    Result.AddCallback(LCallback);
end;

function TFileWatcherBuilder.BuildAndStart: TFileWatcher;
begin
  Result := Build;
  Result.Start;
end;

{ TFileWatchers }

class constructor TFileWatchers.Create;
begin
  FLock := TCriticalSection.Create;
end;

class destructor TFileWatchers.Destroy;
begin
  FreeAndNil(FDefaultManager);
  FreeAndNil(FLock);
end;

class function TFileWatchers.Watch(const ADirectory: string): TFileWatcherBuilder;
begin
  Result := TFileWatcherBuilder.Create(ADirectory);
end;

class function TFileWatchers.QuickWatch(const ADirectory: string;
  ACallback: TFileChangeCallback): TFileWatcher;
begin
  Result := TFileWatcherBuilder.Create(ADirectory)
    .OnCallback(ACallback)
    .BuildAndStart;
end;

function TFileWatcherManager.IsValidWatchPath(const APath: string): Boolean;
var
  CanonicalPath: string;
  AllowedPaths: TArray<string>;
  I: Integer;
begin
  Result := False;
  
  try
    // 获取规范化路径
    CanonicalPath := AnsiUpperCase(TPath.GetFullPath(APath));
    
    // 定义允许监控的路径前缀
    AllowedPaths := TArray<string>.Create(
      AnsiUpperCase(TPath.GetFullPath(TPath.GetDocumentsPath)),
      AnsiUpperCase(TPath.GetFullPath(TPath.GetTempPath)),
      AnsiUpperCase(TPath.GetFullPath(ExtractFilePath(ParamStr(0))))  // 应用程序目录
    );
    
    // 检查路径是否在允许的目录内
    for I := Low(AllowedPaths) to High(AllowedPaths) do
    begin
      if CanonicalPath.StartsWith(AllowedPaths[I]) then
      begin
        Result := True;
        Break;
      end;
    end;
    
    // 禁止监控系统关键目录
    if CanonicalPath.StartsWith('C:\WINDOWS\') or
       CanonicalPath.StartsWith('C:\SYSTEM32\') or
       CanonicalPath.Contains('..') then
      Result := False;
      
  except
    on E: Exception do
      Result := False;
  end;
end;

class function TFileWatcher.IsValidWatchPath(const APath: string): Boolean;
var
  CanonicalPath: string;
  AllowedPaths: TArray<string>;
  I: Integer;
begin
  Result := False;
  
  try
    // 检查基本要求
    if APath.IsEmpty or (Length(APath) > 260) then // Windows路径长度限制
      Exit;
      
    // 获取规范化路径
    CanonicalPath := AnsiUpperCase(TPath.GetFullPath(APath));
    
    // 检查路径遍历攻击
    if CanonicalPath.Contains('..') or CanonicalPath.Contains('~') then
      Exit;
      
    // 定义允许的根目录
    AllowedPaths := TArray<string>.Create(
      AnsiUpperCase(TPath.GetFullPath(TPath.GetDocumentsPath)),
      AnsiUpperCase(TPath.GetFullPath(TPath.GetTempPath)),
      AnsiUpperCase(TPath.GetFullPath(ExtractFilePath(ParamStr(0))))  // 应用程序目录
    );
    
    // 检查路径是否在允许的目录内
    for I := Low(AllowedPaths) to High(AllowedPaths) do
    begin
      if CanonicalPath.StartsWith(AllowedPaths[I]) then
      begin
        Result := True;
        Break;
      end;
    end;
    
    // 禁止监控系统关键目录
    if CanonicalPath.StartsWith('C:\WINDOWS\') or
       CanonicalPath.StartsWith('C:\SYSTEM32\') or
       CanonicalPath.StartsWith('C:\PROGRAM FILES\') or
       CanonicalPath.StartsWith('C:\PROGRAM FILES (X86)\') then
      Result := False;
      
  except
    on E: Exception do
      Result := False;
  end;
end;

class function TFileWatchers.Manager: TFileWatcherManager;
begin
  if not Assigned(FDefaultManager) then
  begin
    FLock.Enter;
    try
      if not Assigned(FDefaultManager) then
        FDefaultManager := TFileWatcherManager.Create;
    finally
      FLock.Leave;
    end;
  end;
  Result := FDefaultManager;
end;

end.
