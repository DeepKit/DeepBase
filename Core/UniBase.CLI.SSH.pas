{ ============================================================================
  UniBase.CLI.SSH - SSH Remote Execution Support
  
  Version: 0.2
  Description: Provides SSH connection management and remote command execution
               capabilities for the CLI framework.
  
  Features:
    - SSH connection management (connect, disconnect, reconnect)
    - Remote command execution with output capture
    - SFTP file transfer support
    - Connection pooling for multiple hosts
    - Session persistence and reuse
    - Proxy/Jump host support
    - Background thread for idle connection cleanup
  
  Note: This module provides the framework interface. Actual SSH implementation
        requires external library such as libssh2 or similar. The module uses
        a pluggable backend architecture to support different SSH libraries.
  
  Usage:
    var SSH := TSSHManager.Create;
    try
      SSH.Connect('user@host:22', 'password');
      var Result := SSH.Execute('ls -la');
      WriteLn(Result.Output);
    finally
      SSH.Free;
    end;
  ============================================================================ }

unit UniBase.CLI.SSH;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.IOUtils,
  System.SyncObjs,
  System.DateUtils,
  System.JSON;

type
  // Forward declarations
  TSSHSession = class;
  TSSHManager = class;
  
  // ============================================================================
  // SSH Authentication Types
  // ============================================================================
  
  TSSHAuthMethod = (
    amPassword,       // Password authentication
    amPublicKey,      // Public key authentication
    amKeyboardInt,    // Keyboard-interactive
    amAgent           // SSH agent
  );
  
  /// <summary>
  /// SSH authentication credentials
  /// </summary>
  TSSHCredentials = record
    Username: string;
    Password: string;
    PrivateKeyFile: string;
    PrivateKeyPassphrase: string;
    AuthMethod: TSSHAuthMethod;
    
    class function CreatePassword(const AUser, APass: string): TSSHCredentials; static;
    class function CreatePublicKey(const AUser, AKeyFile: string;
      const APassphrase: string = ''): TSSHCredentials; static;
  end;
  
  // ============================================================================
  // SSH Connection Options
  // ============================================================================
  
  /// <summary>
  /// SSH connection options
  /// </summary>
  TSSHOptions = record
    Host: string;
    Port: Integer;
    ConnectTimeout: Integer;     // milliseconds
    CommandTimeout: Integer;     // milliseconds
    KeepAliveInterval: Integer;  // seconds
    StrictHostKeyCheck: Boolean;
    KnownHostsFile: string;
    ProxyHost: string;           // Jump host
    ProxyPort: Integer;
    Compression: Boolean;
    
    class function Default: TSSHOptions; static;
    procedure ParseHostString(const HostString: string);
  end;
  
  // ============================================================================
  // SSH Execution Result
  // ============================================================================
  
  /// <summary>
  /// Result of SSH command execution
  /// </summary>
  TSSHResult = record
    Success: Boolean;
    ExitCode: Integer;
    Output: string;
    ErrorOutput: string;
    ExecutionTime: Int64;  // milliseconds
    
    class function OK(const AOutput: string; ACode: Integer = 0): TSSHResult; static;
    class function Error(const AError: string; ACode: Integer = -1): TSSHResult; static;
  end;
  
  // ============================================================================
  // SSH Session Events
  // ============================================================================
  
  TSSHOutputEvent = procedure(const Data: string) of object;
  TSSHProgressEvent = procedure(Current, Total: Int64; var Cancel: Boolean) of object;
  TSSHHostKeyEvent = procedure(const Host, Fingerprint: string; 
    var Accept: Boolean) of object;
  
  // ============================================================================
  // SSH Backend Interface
  // ============================================================================
  
  /// <summary>
  /// Interface for SSH backend implementations
  /// </summary>
  ISSHBackend = interface
    ['{B2C3D4E5-F6A7-4B8C-9D0E-1F2A3B4C5D6E}']
    function Connect(const Options: TSSHOptions; 
      const Credentials: TSSHCredentials): Boolean;
    procedure Disconnect;
    function IsConnected: Boolean;
    function Execute(const Command: string; Timeout: Integer): TSSHResult;
    function Upload(const LocalFile, RemotePath: string): Boolean;
    function Download(const RemotePath, LocalFile: string): Boolean;
    function GetLastError: string;
    
    procedure SetOnOutput(Handler: TSSHOutputEvent);
    procedure SetOnProgress(Handler: TSSHProgressEvent);
    procedure SetOnHostKey(Handler: TSSHHostKeyEvent);
  end;
  
  // ============================================================================
  // SSH Session
  // ============================================================================
  
  TSSHSessionState = (ssDisconnected, ssConnecting, ssConnected, ssExecuting);
  
  /// <summary>
  /// Represents a single SSH session
  /// </summary>
  TSSHSession = class
  private
    FId: string;
    FOptions: TSSHOptions;
    FCredentials: TSSHCredentials;
    FBackend: ISSHBackend;
    FState: TSSHSessionState;
    FLastActivity: TDateTime;
    FLastError: string;
    FOnOutput: TSSHOutputEvent;
    FOnProgress: TSSHProgressEvent;
    FOnHostKey: TSSHHostKeyEvent;
    FLock: TCriticalSection;
    
    procedure SetState(AState: TSSHSessionState);
  public
    constructor Create(const AId: string);
    destructor Destroy; override;
    
    /// <summary>Connect to SSH server</summary>
    function Connect(const Options: TSSHOptions;
      const Credentials: TSSHCredentials): Boolean;
    
    /// <summary>Disconnect from server</summary>
    procedure Disconnect;
    
    /// <summary>Execute remote command</summary>
    function Execute(const Command: string): TSSHResult;
    
    /// <summary>Upload file via SFTP</summary>
    function Upload(const LocalFile, RemotePath: string): Boolean;
    
    /// <summary>Download file via SFTP</summary>
    function Download(const RemotePath, LocalFile: string): Boolean;
    
    /// <summary>Check if session is valid and connected</summary>
    function IsConnected: Boolean;
    
    property Id: string read FId;
    property Options: TSSHOptions read FOptions;
    property State: TSSHSessionState read FState;
    property LastActivity: TDateTime read FLastActivity;
    property LastError: string read FLastError;
    property OnOutput: TSSHOutputEvent read FOnOutput write FOnOutput;
    property OnProgress: TSSHProgressEvent read FOnProgress write FOnProgress;
    property OnHostKey: TSSHHostKeyEvent read FOnHostKey write FOnHostKey;
  end;
  
  // ============================================================================
  // SSH Connection Pool Cleanup Thread
  // ============================================================================
  
  TSSHConnectionPool = class;
  
  /// <summary>
  /// Background thread for cleaning up idle SSH connections
  /// </summary>
  TSSHCleanupThread = class(TThread)
  private
    FPool: TSSHConnectionPool;
    FInterval: Integer;  // milliseconds
    FStopEvent: TEvent;
  protected
    procedure Execute; override;
  public
    constructor Create(APool: TSSHConnectionPool; AIntervalSeconds: Integer);
    destructor Destroy; override;
    procedure Stop;
  end;
  
  // ============================================================================
  // SSH Connection Pool
  // ============================================================================
  
  /// <summary>
  /// Manages a pool of SSH connections
  /// </summary>
  TSSHConnectionPool = class
  private
    FSessions: TObjectDictionary<string, TSSHSession>;
    FMaxConnections: Integer;
    FIdleTimeout: Integer;  // seconds
    FCleanupInterval: Integer; // seconds
    FLock: TCriticalSection;
    FCleanupThread: TSSHCleanupThread;
    
    function GetSessionKey(const Host: string; Port: Integer; 
      const User: string): string;
    procedure DoCleanupIdleSessions;
  public
    constructor Create(MaxConnections: Integer = 10; IdleTimeout: Integer = 300;
      CleanupInterval: Integer = 60);
    destructor Destroy; override;
    
    /// <summary>Get or create a session</summary>
    function GetSession(const Options: TSSHOptions;
      const Credentials: TSSHCredentials): TSSHSession;
    
    /// <summary>Release a session back to pool</summary>
    procedure ReleaseSession(Session: TSSHSession);
    
    /// <summary>Remove a session from pool</summary>
    procedure RemoveSession(const SessionId: string);
    
    /// <summary>Close all sessions</summary>
    procedure CloseAll;
    
    /// <summary>Get active session count</summary>
    function ActiveCount: Integer;
    
    /// <summary>Manually trigger cleanup of idle sessions</summary>
    procedure CleanupIdleSessions;
    
    property MaxConnections: Integer read FMaxConnections write FMaxConnections;
    property IdleTimeout: Integer read FIdleTimeout write FIdleTimeout;
    property CleanupInterval: Integer read FCleanupInterval;
  end;
  
  // ============================================================================
  // SSH Manager
  // ============================================================================
  
  /// <summary>
  /// High-level SSH management interface
  /// </summary>
  TSSHManager = class
  private
    FPool: TSSHConnectionPool;
    FCurrentSession: TSSHSession;
    FDefaultOptions: TSSHOptions;
    FDefaultCredentials: TSSHCredentials;
    FHostAliases: TDictionary<string, TSSHOptions>;
    FOnOutput: TSSHOutputEvent;
    FOnHostKey: TSSHHostKeyEvent;
    
    function ParseHostString(const HostString: string; 
      out Options: TSSHOptions; out Credentials: TSSHCredentials): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    
    /// <summary>Connect to a host</summary>
    function Connect(const HostString: string; 
      const Password: string = ''): Boolean; overload;
    function Connect(const Options: TSSHOptions;
      const Credentials: TSSHCredentials): Boolean; overload;
    
    /// <summary>Disconnect current session</summary>
    procedure Disconnect;
    
    /// <summary>Execute command on current session</summary>
    function Execute(const Command: string): TSSHResult;
    
    /// <summary>Execute command on specific host</summary>
    function ExecuteOn(const HostString, Command: string;
      const Password: string = ''): TSSHResult;
    
    /// <summary>Upload file</summary>
    function Upload(const LocalFile, RemotePath: string): Boolean;
    
    /// <summary>Download file</summary>
    function Download(const RemotePath, LocalFile: string): Boolean;
    
    /// <summary>Check if connected</summary>
    function IsConnected: Boolean;
    
    /// <summary>Add host alias</summary>
    procedure AddHostAlias(const Alias: string; const Options: TSSHOptions);
    
    /// <summary>Get host alias</summary>
    function GetHostAlias(const Alias: string): TSSHOptions;
    
    /// <summary>Load host aliases from file</summary>
    procedure LoadAliases(const FileName: string);
    
    /// <summary>Save host aliases to file</summary>
    procedure SaveAliases(const FileName: string);
    
    property Pool: TSSHConnectionPool read FPool;
    property CurrentSession: TSSHSession read FCurrentSession;
    property DefaultOptions: TSSHOptions read FDefaultOptions write FDefaultOptions;
    property DefaultCredentials: TSSHCredentials read FDefaultCredentials write FDefaultCredentials;
    property OnOutput: TSSHOutputEvent read FOnOutput write FOnOutput;
    property OnHostKey: TSSHHostKeyEvent read FOnHostKey write FOnHostKey;
  end;
  
  // ============================================================================
  // Mock SSH Backend (for testing)
  // ============================================================================
  
  /// <summary>
  /// Mock SSH backend for testing without actual SSH connections
  /// </summary>
  TMockSSHBackend = class(TInterfacedObject, ISSHBackend)
  private
    FConnected: Boolean;
    FHost: string;
    FUser: string;
    FLastError: string;
    FOnOutput: TSSHOutputEvent;
    FOnProgress: TSSHProgressEvent;
    FOnHostKey: TSSHHostKeyEvent;
    FMockResponses: TDictionary<string, TSSHResult>;
  public
    constructor Create;
    destructor Destroy; override;
    
    // ISSHBackend implementation
    function Connect(const Options: TSSHOptions;
      const Credentials: TSSHCredentials): Boolean;
    procedure Disconnect;
    function IsConnected: Boolean;
    function Execute(const Command: string; Timeout: Integer): TSSHResult;
    function Upload(const LocalFile, RemotePath: string): Boolean;
    function Download(const RemotePath, LocalFile: string): Boolean;
    function GetLastError: string;
    
    procedure SetOnOutput(Handler: TSSHOutputEvent);
    procedure SetOnProgress(Handler: TSSHProgressEvent);
    procedure SetOnHostKey(Handler: TSSHHostKeyEvent);
    
    /// <summary>Add mock response for testing</summary>
    procedure AddMockResponse(const Command: string; const Response: TSSHResult);
    procedure ClearMockResponses;
  end;
  
  // ============================================================================
  // Factory Functions
  // ============================================================================
  
  /// <summary>Create SSH backend (returns mock by default)</summary>
  function CreateSSHBackend: ISSHBackend;
  
  /// <summary>Set custom SSH backend factory</summary>
  procedure SetSSHBackendFactory(Factory: TFunc<ISSHBackend>);

implementation

var
  GSSHBackendFactory: TFunc<ISSHBackend> = nil;

// ============================================================================
// Factory Functions
// ============================================================================

function CreateSSHBackend: ISSHBackend;
begin
  if Assigned(GSSHBackendFactory) then
    Result := GSSHBackendFactory()
  else
    Result := TMockSSHBackend.Create;
end;

procedure SetSSHBackendFactory(Factory: TFunc<ISSHBackend>);
begin
  GSSHBackendFactory := Factory;
end;

// ============================================================================
// TSSHCredentials
// ============================================================================

class function TSSHCredentials.CreatePassword(const AUser, APass: string): TSSHCredentials;
begin
  Result.Username := AUser;
  Result.Password := APass;
  Result.PrivateKeyFile := '';
  Result.PrivateKeyPassphrase := '';
  Result.AuthMethod := amPassword;
end;

class function TSSHCredentials.CreatePublicKey(const AUser, AKeyFile: string;
  const APassphrase: string): TSSHCredentials;
begin
  Result.Username := AUser;
  Result.Password := '';
  Result.PrivateKeyFile := AKeyFile;
  Result.PrivateKeyPassphrase := APassphrase;
  Result.AuthMethod := amPublicKey;
end;

// ============================================================================
// TSSHOptions
// ============================================================================

class function TSSHOptions.Default: TSSHOptions;
begin
  Result.Host := '';
  Result.Port := 22;
  Result.ConnectTimeout := 30000;
  Result.CommandTimeout := 60000;
  Result.KeepAliveInterval := 30;
  Result.StrictHostKeyCheck := True;
  Result.KnownHostsFile := '';
  Result.ProxyHost := '';
  Result.ProxyPort := 22;
  Result.Compression := False;
end;

procedure TSSHOptions.ParseHostString(const HostString: string);
var
  Parts: TArray<string>;
  HostPart: string;
begin
  // Format: [user@]host[:port]
  if HostString.Contains('@') then
  begin
    Parts := HostString.Split(['@']);
    // User is handled separately
    HostPart := Parts[1];
  end
  else
    HostPart := HostString;
  
  if HostPart.Contains(':') then
  begin
    Parts := HostPart.Split([':']);
    Host := Parts[0];
    TryStrToInt(Parts[1], Port);
  end
  else
  begin
    Host := HostPart;
    Port := 22;
  end;
end;

// ============================================================================
// TSSHResult
// ============================================================================

class function TSSHResult.OK(const AOutput: string; ACode: Integer): TSSHResult;
begin
  Result.Success := True;
  Result.ExitCode := ACode;
  Result.Output := AOutput;
  Result.ErrorOutput := '';
  Result.ExecutionTime := 0;
end;

class function TSSHResult.Error(const AError: string; ACode: Integer): TSSHResult;
begin
  Result.Success := False;
  Result.ExitCode := ACode;
  Result.Output := '';
  Result.ErrorOutput := AError;
  Result.ExecutionTime := 0;
end;

// ============================================================================
// TSSHSession
// ============================================================================

constructor TSSHSession.Create(const AId: string);
begin
  inherited Create;
  FId := AId;
  FState := ssDisconnected;
  FLastActivity := Now;
  FLastError := '';
  FLock := TCriticalSection.Create;
  FBackend := nil;
end;

destructor TSSHSession.Destroy;
begin
  Disconnect;
  FLock.Free;
  inherited;
end;

procedure TSSHSession.SetState(AState: TSSHSessionState);
begin
  FLock.Enter;
  try
    FState := AState;
    FLastActivity := Now;
  finally
    FLock.Leave;
  end;
end;

function TSSHSession.Connect(const Options: TSSHOptions;
  const Credentials: TSSHCredentials): Boolean;
begin
  Result := False;
  FLastError := '';
  
  if FState <> ssDisconnected then
    Disconnect;
  
  SetState(ssConnecting);
  FOptions := Options;
  FCredentials := Credentials;
  
  try
    FBackend := CreateSSHBackend;
    
    if Assigned(FOnOutput) then
      FBackend.SetOnOutput(FOnOutput);
    if Assigned(FOnProgress) then
      FBackend.SetOnProgress(FOnProgress);
    if Assigned(FOnHostKey) then
      FBackend.SetOnHostKey(FOnHostKey);
    
    Result := FBackend.Connect(Options, Credentials);
    
    if Result then
      SetState(ssConnected)
    else
    begin
      FLastError := FBackend.GetLastError;
      SetState(ssDisconnected);
    end;
  except
    on E: Exception do
    begin
      FLastError := E.Message;
      SetState(ssDisconnected);
    end;
  end;
end;

procedure TSSHSession.Disconnect;
begin
  FLock.Enter;
  try
    if Assigned(FBackend) then
    begin
      FBackend.Disconnect;
      FBackend := nil;
    end;
    FState := ssDisconnected;
  finally
    FLock.Leave;
  end;
end;

function TSSHSession.Execute(const Command: string): TSSHResult;
begin
  Result := TSSHResult.Error('Not connected');
  
  if not IsConnected then
    Exit;
  
  SetState(ssExecuting);
  try
    Result := FBackend.Execute(Command, FOptions.CommandTimeout);
    FLastActivity := Now;
  finally
    SetState(ssConnected);
  end;
end;

function TSSHSession.Upload(const LocalFile, RemotePath: string): Boolean;
begin
  Result := False;
  
  if not IsConnected then
    Exit;
  
  SetState(ssExecuting);
  try
    Result := FBackend.Upload(LocalFile, RemotePath);
    FLastActivity := Now;
  finally
    SetState(ssConnected);
  end;
end;

function TSSHSession.Download(const RemotePath, LocalFile: string): Boolean;
begin
  Result := False;
  
  if not IsConnected then
    Exit;
  
  SetState(ssExecuting);
  try
    Result := FBackend.Download(RemotePath, LocalFile);
    FLastActivity := Now;
  finally
    SetState(ssConnected);
  end;
end;

function TSSHSession.IsConnected: Boolean;
begin
  FLock.Enter;
  try
    Result := (FState = ssConnected) or (FState = ssExecuting);
    if Result and Assigned(FBackend) then
      Result := FBackend.IsConnected;
  finally
    FLock.Leave;
  end;
end;

// ============================================================================
// TSSHCleanupThread
// ============================================================================

constructor TSSHCleanupThread.Create(APool: TSSHConnectionPool; AIntervalSeconds: Integer);
begin
  inherited Create(True);  // Create suspended
  FPool := APool;
  FInterval := AIntervalSeconds * 1000;  // Convert to milliseconds
  FStopEvent := TEvent.Create(nil, True, False, '');
  FreeOnTerminate := False;
end;

destructor TSSHCleanupThread.Destroy;
begin
  Stop;
  FStopEvent.Free;
  inherited;
end;

procedure TSSHCleanupThread.Execute;
var
  LWaitResult: TWaitResult;
begin
  while not Terminated do
  begin
    // Wait for interval or stop signal
    LWaitResult := FStopEvent.WaitFor(FInterval);
    
    if (LWaitResult = wrTimeout) and not Terminated then
    begin
      // Timeout means we should do cleanup
      try
        FPool.DoCleanupIdleSessions;
      except
        // Ignore cleanup errors
      end;
    end
    else if LWaitResult = wrSignaled then
    begin
      // Stop signal received
      Break;
    end;
  end;
end;

procedure TSSHCleanupThread.Stop;
begin
  Terminate;
  FStopEvent.SetEvent;
  if Started then
    WaitFor;
end;

// ============================================================================
// TSSHConnectionPool
// ============================================================================

constructor TSSHConnectionPool.Create(MaxConnections: Integer; IdleTimeout: Integer;
  CleanupInterval: Integer);
begin
  inherited Create;
  FSessions := TObjectDictionary<string, TSSHSession>.Create([doOwnsValues]);
  FMaxConnections := MaxConnections;
  FIdleTimeout := IdleTimeout;
  FCleanupInterval := CleanupInterval;
  FLock := TCriticalSection.Create;
  
  // Create and start cleanup thread
  FCleanupThread := TSSHCleanupThread.Create(Self, FCleanupInterval);
  FCleanupThread.Start;
end;

destructor TSSHConnectionPool.Destroy;
begin
  // Stop cleanup thread first
  if Assigned(FCleanupThread) then
  begin
    FCleanupThread.Stop;
    FCleanupThread.Free;
  end;
  
  CloseAll;
  FLock.Free;
  FSessions.Free;
  inherited;
end;

function TSSHConnectionPool.GetSessionKey(const Host: string; Port: Integer;
  const User: string): string;
begin
  Result := Format('%s@%s:%d', [User, Host, Port]);
end;

procedure TSSHConnectionPool.CleanupIdleSessions;
begin
  DoCleanupIdleSessions;
end;

procedure TSSHConnectionPool.DoCleanupIdleSessions;
var
  SessionsToRemove: TList<string>;
  Session: TSSHSession;
  Key: string;
begin
  SessionsToRemove := TList<string>.Create;
  try
    FLock.Enter;
    try
      for Key in FSessions.Keys do
      begin
        Session := FSessions[Key];
        if (Session.State = ssConnected) and
           (SecondsBetween(Now, Session.LastActivity) > FIdleTimeout) then
          SessionsToRemove.Add(Key);
      end;
      
      for Key in SessionsToRemove do
      begin
        FSessions[Key].Disconnect;
        FSessions.Remove(Key);
      end;
    finally
      FLock.Leave;
    end;
  finally
    SessionsToRemove.Free;
  end;
end;

function TSSHConnectionPool.GetSession(const Options: TSSHOptions;
  const Credentials: TSSHCredentials): TSSHSession;
var
  Key: string;
begin
  Key := GetSessionKey(Options.Host, Options.Port, Credentials.Username);
  
  FLock.Enter;
  try
    if FSessions.TryGetValue(Key, Result) then
    begin
      if Result.IsConnected then
        Exit;
      // Session exists but not connected, remove it
      FSessions.Remove(Key);
    end;
    
    // Check max connections
    if FSessions.Count >= FMaxConnections then
      DoCleanupIdleSessions;
    
    if FSessions.Count >= FMaxConnections then
    begin
      Result := nil;
      Exit;
    end;
    
    // Create new session
    Result := TSSHSession.Create(Key);
    FSessions.Add(Key, Result);
  finally
    FLock.Leave;
  end;
  
  // Connect outside lock
  if not Result.Connect(Options, Credentials) then
  begin
    FLock.Enter;
    try
      FSessions.Remove(Key);
    finally
      FLock.Leave;
    end;
    Result := nil;
  end;
end;

procedure TSSHConnectionPool.ReleaseSession(Session: TSSHSession);
begin
  // Session stays in pool for reuse
  // Just update last activity
  if Assigned(Session) then
    Session.FLastActivity := Now;
end;

procedure TSSHConnectionPool.RemoveSession(const SessionId: string);
begin
  FLock.Enter;
  try
    if FSessions.ContainsKey(SessionId) then
    begin
      FSessions[SessionId].Disconnect;
      FSessions.Remove(SessionId);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TSSHConnectionPool.CloseAll;
var
  Session: TSSHSession;
begin
  FLock.Enter;
  try
    for Session in FSessions.Values do
      Session.Disconnect;
    FSessions.Clear;
  finally
    FLock.Leave;
  end;
end;

function TSSHConnectionPool.ActiveCount: Integer;
var
  Session: TSSHSession;
begin
  Result := 0;
  FLock.Enter;
  try
    for Session in FSessions.Values do
      if Session.IsConnected then
        Inc(Result);
  finally
    FLock.Leave;
  end;
end;

// ============================================================================
// TSSHManager
// ============================================================================

constructor TSSHManager.Create;
begin
  inherited Create;
  FPool := TSSHConnectionPool.Create;
  FCurrentSession := nil;
  FDefaultOptions := TSSHOptions.Default;
  FHostAliases := TDictionary<string, TSSHOptions>.Create;
end;

destructor TSSHManager.Destroy;
begin
  FHostAliases.Free;
  FPool.Free;
  inherited;
end;

function TSSHManager.ParseHostString(const HostString: string;
  out Options: TSSHOptions; out Credentials: TSSHCredentials): Boolean;
var
  Parts: TArray<string>;
  UserPart, HostPart: string;
begin
  Result := True;
  Options := FDefaultOptions;
  Credentials := FDefaultCredentials;
  
  // Check for alias first
  if FHostAliases.ContainsKey(HostString) then
  begin
    Options := FHostAliases[HostString];
    Exit;
  end;
  
  // Parse [user@]host[:port]
  if HostString.Contains('@') then
  begin
    Parts := HostString.Split(['@']);
    UserPart := Parts[0];
    HostPart := Parts[1];
    Credentials.Username := UserPart;
  end
  else
    HostPart := HostString;
  
  Options.ParseHostString(HostPart);
  
  if Options.Host = '' then
    Result := False;
end;

function TSSHManager.Connect(const HostString: string;
  const Password: string): Boolean;
var
  Options: TSSHOptions;
  Credentials: TSSHCredentials;
begin
  Result := False;
  
  if not ParseHostString(HostString, Options, Credentials) then
    Exit;
  
  if Password <> '' then
    Credentials.Password := Password;
  
  Result := Connect(Options, Credentials);
end;

function TSSHManager.Connect(const Options: TSSHOptions;
  const Credentials: TSSHCredentials): Boolean;
begin
  Result := False;
  
  FCurrentSession := FPool.GetSession(Options, Credentials);
  if Assigned(FCurrentSession) then
  begin
    FCurrentSession.OnOutput := FOnOutput;
    FCurrentSession.OnHostKey := FOnHostKey;
    Result := FCurrentSession.IsConnected;
  end;
end;

procedure TSSHManager.Disconnect;
begin
  if Assigned(FCurrentSession) then
  begin
    FPool.ReleaseSession(FCurrentSession);
    FCurrentSession := nil;
  end;
end;

function TSSHManager.Execute(const Command: string): TSSHResult;
begin
  if not Assigned(FCurrentSession) or not FCurrentSession.IsConnected then
    Result := TSSHResult.Error('Not connected')
  else
    Result := FCurrentSession.Execute(Command);
end;

function TSSHManager.ExecuteOn(const HostString, Command: string;
  const Password: string): TSSHResult;
var
  Options: TSSHOptions;
  Credentials: TSSHCredentials;
  Session: TSSHSession;
begin
  Result := TSSHResult.Error('Failed to connect');
  
  if not ParseHostString(HostString, Options, Credentials) then
    Exit;
  
  if Password <> '' then
    Credentials.Password := Password;
  
  Session := FPool.GetSession(Options, Credentials);
  if Assigned(Session) then
  begin
    try
      Result := Session.Execute(Command);
    finally
      FPool.ReleaseSession(Session);
    end;
  end;
end;

function TSSHManager.Upload(const LocalFile, RemotePath: string): Boolean;
begin
  if not Assigned(FCurrentSession) or not FCurrentSession.IsConnected then
    Result := False
  else
    Result := FCurrentSession.Upload(LocalFile, RemotePath);
end;

function TSSHManager.Download(const RemotePath, LocalFile: string): Boolean;
begin
  if not Assigned(FCurrentSession) or not FCurrentSession.IsConnected then
    Result := False
  else
    Result := FCurrentSession.Download(RemotePath, LocalFile);
end;

function TSSHManager.IsConnected: Boolean;
begin
  Result := Assigned(FCurrentSession) and FCurrentSession.IsConnected;
end;

procedure TSSHManager.AddHostAlias(const Alias: string; const Options: TSSHOptions);
begin
  FHostAliases.AddOrSetValue(Alias, Options);
end;

function TSSHManager.GetHostAlias(const Alias: string): TSSHOptions;
begin
  if not FHostAliases.TryGetValue(Alias, Result) then
    Result := TSSHOptions.Default;
end;

procedure TSSHManager.LoadAliases(const FileName: string);
var
  JSON: TJSONObject;
  Pair: TJSONPair;
  Options: TSSHOptions;
  AliasObj: TJSONObject;
begin
  if not TFile.Exists(FileName) then
    Exit;
  
  try
    JSON := TJSONObject.ParseJSONValue(TFile.ReadAllText(FileName)) as TJSONObject;
    if JSON = nil then Exit;
    
    try
      for Pair in JSON do
      begin
        if Pair.JsonValue is TJSONObject then
        begin
          AliasObj := TJSONObject(Pair.JsonValue);
          Options := TSSHOptions.Default;
          
          if AliasObj.GetValue('host') <> nil then
            Options.Host := AliasObj.GetValue('host').Value;
          if AliasObj.GetValue('port') <> nil then
            Options.Port := AliasObj.GetValue('port').GetValue<Integer>;
          if AliasObj.GetValue('proxy') <> nil then
            Options.ProxyHost := AliasObj.GetValue('proxy').Value;
          
          FHostAliases.AddOrSetValue(Pair.JsonString.Value, Options);
        end;
      end;
    finally
      JSON.Free;
    end;
  except
    // Ignore parse errors
  end;
end;

procedure TSSHManager.SaveAliases(const FileName: string);
var
  JSON: TJSONObject;
  AliasObj: TJSONObject;
  Alias: string;
  Options: TSSHOptions;
begin
  JSON := TJSONObject.Create;
  try
    for Alias in FHostAliases.Keys do
    begin
      Options := FHostAliases[Alias];
      AliasObj := TJSONObject.Create;
      AliasObj.AddPair('host', Options.Host);
      AliasObj.AddPair('port', TJSONNumber.Create(Options.Port));
      if Options.ProxyHost <> '' then
        AliasObj.AddPair('proxy', Options.ProxyHost);
      JSON.AddPair(Alias, AliasObj);
    end;
    
    TFile.WriteAllText(FileName, JSON.Format(2));
  finally
    JSON.Free;
  end;
end;

// ============================================================================
// TMockSSHBackend
// ============================================================================

constructor TMockSSHBackend.Create;
begin
  inherited Create;
  FConnected := False;
  FHost := '';
  FUser := '';
  FLastError := '';
  FMockResponses := TDictionary<string, TSSHResult>.Create;
  
  // Add some default mock responses
  AddMockResponse('whoami', TSSHResult.OK('mockuser'));
  AddMockResponse('hostname', TSSHResult.OK('mockhost'));
  AddMockResponse('pwd', TSSHResult.OK('/home/mockuser'));
  AddMockResponse('echo hello', TSSHResult.OK('hello'));
  AddMockResponse('ls', TSSHResult.OK('file1.txt'#10'file2.txt'#10'dir1'));
  AddMockResponse('ls -la', TSSHResult.OK(
    'total 0'#10 +
    'drwxr-xr-x  2 user user  40 Nov 29 10:00 .'#10 +
    'drwxr-xr-x 10 user user 200 Nov 29 09:00 ..'#10 +
    '-rw-r--r--  1 user user 100 Nov 29 10:00 file1.txt'#10 +
    '-rw-r--r--  1 user user 200 Nov 29 10:00 file2.txt'));
  AddMockResponse('uname -a', TSSHResult.OK('Linux mockhost 5.15.0 #1 SMP x86_64 GNU/Linux'));
  AddMockResponse('date', TSSHResult.OK('Sat Nov 29 10:00:00 UTC 2025'));
end;

destructor TMockSSHBackend.Destroy;
begin
  FMockResponses.Free;
  inherited;
end;

function TMockSSHBackend.Connect(const Options: TSSHOptions;
  const Credentials: TSSHCredentials): Boolean;
var
  Accept: Boolean;
begin
  FHost := Options.Host;
  FUser := Credentials.Username;
  
  // Simulate host key verification
  if Assigned(FOnHostKey) then
  begin
    Accept := True;
    FOnHostKey(FHost, 'mock:fingerprint:12:34:56:78:90:ab:cd:ef', Accept);
    if not Accept then
    begin
      FLastError := 'Host key rejected';
      Result := False;
      Exit;
    end;
  end;
  
  // Simulate connection
  FConnected := True;
  Result := True;
  
  if Assigned(FOnOutput) then
    FOnOutput('Connected to ' + FUser + '@' + FHost);
end;

procedure TMockSSHBackend.Disconnect;
begin
  FConnected := False;
  if Assigned(FOnOutput) then
    FOnOutput('Disconnected');
end;

function TMockSSHBackend.IsConnected: Boolean;
begin
  Result := FConnected;
end;

function TMockSSHBackend.Execute(const Command: string; Timeout: Integer): TSSHResult;
begin
  if not FConnected then
  begin
    Result := TSSHResult.Error('Not connected');
    Exit;
  end;
  
  // Check for mock response
  if FMockResponses.TryGetValue(Command, Result) then
    Exit;
  
  // Default response for unknown commands
  Result := TSSHResult.OK('Mock output for: ' + Command);
end;

function TMockSSHBackend.Upload(const LocalFile, RemotePath: string): Boolean;
begin
  Result := FConnected and TFile.Exists(LocalFile);
  if Result and Assigned(FOnOutput) then
    FOnOutput('Uploaded: ' + LocalFile + ' -> ' + RemotePath);
end;

function TMockSSHBackend.Download(const RemotePath, LocalFile: string): Boolean;
begin
  Result := FConnected;
  if Result then
  begin
    // Create mock file
    TFile.WriteAllText(LocalFile, 'Mock content from ' + RemotePath);
    if Assigned(FOnOutput) then
      FOnOutput('Downloaded: ' + RemotePath + ' -> ' + LocalFile);
  end;
end;

function TMockSSHBackend.GetLastError: string;
begin
  Result := FLastError;
end;

procedure TMockSSHBackend.SetOnOutput(Handler: TSSHOutputEvent);
begin
  FOnOutput := Handler;
end;

procedure TMockSSHBackend.SetOnProgress(Handler: TSSHProgressEvent);
begin
  FOnProgress := Handler;
end;

procedure TMockSSHBackend.SetOnHostKey(Handler: TSSHHostKeyEvent);
begin
  FOnHostKey := Handler;
end;

procedure TMockSSHBackend.AddMockResponse(const Command: string; const Response: TSSHResult);
begin
  FMockResponses.AddOrSetValue(Command, Response);
end;

procedure TMockSSHBackend.ClearMockResponses;
begin
  FMockResponses.Clear;
end;

end.
