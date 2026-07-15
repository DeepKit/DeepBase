{ ============================================================================
  DeepBase.PluginManager - Plugin Manager
  
  Version: 0.3
  Description: Manages plugin lifecycle including loading, initialization,
               dependency resolution, and unloading.
  
  Thread Safety: LoadPlugin/UnloadPlugin should be called from main thread.
  ============================================================================ }

unit DeepBase.PluginManager;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  System.SyncObjs,
  DeepBase.Plugin;

const
  /// <summary>Default plugins subdirectory name</summary>
  DEFAULT_PLUGINS_DIR = 'Plugins';
  
  /// <summary>Plugin registration export name</summary>
  REGISTER_PLUGIN_FUNC = 'RegisterPlugin';

type
  /// <summary>
  /// Internal record to track loaded plugin
  /// </summary>
  TLoadedPlugin = record
    Plugin: IDeepBasePlugin;
    Info: TPluginInfo;
    BPLPath: string;
    PackageHandle: HMODULE;
    LoadOrder: Integer;
  end;
  
  // Callback types for plugin context
  TPluginGetConfigFunc = reference to function(const Key, Default: string): string;
  TPluginSetConfigProc = reference to procedure(const Key, Value: string);
  TPluginTranslateFunc = reference to function(const Text: string): string;
  TPluginLogProc = reference to procedure(const Msg: string; Level: Integer);
  
  /// <summary>
  /// Plugin context implementation providing access to framework services
  /// </summary>
  TPluginContext = class(TInterfacedObject, IDeepBasePluginContext)
  private
    FGetConfigFunc: TPluginGetConfigFunc;
    FSetConfigProc: TPluginSetConfigProc;
    FTranslateFunc: TPluginTranslateFunc;
    FLogProc: TPluginLogProc;
    FRootPath: string;
  public
    constructor Create(
      AGetConfigFunc: TPluginGetConfigFunc;
      ASetConfigProc: TPluginSetConfigProc;
      ATranslateFunc: TPluginTranslateFunc;
      ALogProc: TPluginLogProc;
      const ARootPath: string);
    
    // IDeepBasePluginContext implementation
    function GetConfig(const Key: string; const Default: string = ''): string;
    procedure SetConfig(const Key, Value: string);
    function Translate(const Text: string): string;
    procedure Log(const Message: string; Level: Integer = 1);
    function GetRootPath: string;
    function GetPluginDataPath(const PluginID: TGUID): string;
  end;

  /// <summary>
  /// Immutable snapshot of a loaded plugin used by notification and
  /// unload-all paths so that callbacks can be invoked outside FLock
  /// without racing against concurrent mutations (BIZ2-023).
  /// </summary>
  TLoadedPluginData = record
    Info: TPluginInfo;
    Plugin: IDeepBasePlugin;
    PackageHandle: HMODULE;
  end;

  /// <summary>
  /// Plugin manager - handles plugin lifecycle
  /// </summary>
  TDeepBasePluginManager = class
  private
    FPlugins: TDictionary<TGUID, TLoadedPlugin>;
    FLoadOrder: TList<TGUID>;
    FPluginsDir: string;
    FContext: IDeepBasePluginContext;
    FLock: TObject;
    FNextLoadOrder: Integer;
    
    // Events
    FOnPluginLoaded: TPluginLoadedEvent;
    FOnPluginUnloaded: TPluginUnloadedEvent;
    FOnPluginError: TPluginErrorEvent;
    
    // Internal methods
    function LoadBPL(const Path: string): HMODULE;
    procedure UnloadBPL(Handle: HMODULE);
    function GetRegisterFunc(Handle: HMODULE): TRegisterPluginFunc;
    function CheckDependencies(const Info: TPluginInfo): Boolean;
    function CheckVersionCompatibility(const MinVersion: string): Boolean;
    procedure FirePluginLoaded(const Info: TPluginInfo);
    procedure FirePluginUnloaded(const PluginID: TGUID);
    procedure FirePluginError(const PluginID: TGUID; const PluginName, ErrorMsg: string; IsFatal: Boolean);
    function IsValidPluginPath(const Path: string): Boolean;
    function VerifyPluginSignature(const Path: string): Boolean;
    function GetPluginEnabledSetting(const PluginID: TGUID): Boolean;
    procedure SetPluginEnabledSetting(const PluginID: TGUID; Enabled: Boolean);
    /// <summary>
    /// Capture a thread-safe snapshot of currently loaded plugins.
    /// The returned array holds IDeepBasePlugin references which keep
    /// plugin objects alive via refcount even if unloaded concurrently.
    /// BIZ2-023: used to invoke callbacks outside FLock safely.
    /// </summary>
    function SnapshotLoadedPlugins: TArray<TLoadedPluginData>;
    
  public
    constructor Create(const APluginsDir: string; AContext: IDeepBasePluginContext);
    destructor Destroy; override;
    
    /// <summary>
    /// Load a single plugin from BPL file
    /// </summary>
    function LoadPlugin(const BPLPath: string): Boolean;
    
    /// <summary>
    /// Unload a plugin by its ID
    /// </summary>
    function UnloadPlugin(const PluginID: TGUID): Boolean;
    
    /// <summary>
    /// Load all plugins from the plugins directory
    /// </summary>
    procedure LoadAllPlugins;
    
    /// <summary>
    /// Unload all plugins in reverse load order
    /// </summary>
    procedure UnloadAllPlugins;
    
    /// <summary>
    /// Get a loaded plugin by ID
    /// </summary>
    function GetPlugin(const PluginID: TGUID): IDeepBasePlugin;
    
    /// <summary>
    /// Get all loaded plugin infos
    /// </summary>
    function GetLoadedPlugins: TArray<TPluginInfo>;
    
    /// <summary>
    /// Check if a plugin is loaded
    /// </summary>
    function IsPluginLoaded(const PluginID: TGUID): Boolean;
    
    /// <summary>
    /// Get plugin count
    /// </summary>
    function PluginCount: Integer;
    
    /// <summary>
    /// Enable or disable a plugin (affects next load)
    /// </summary>
    procedure SetPluginEnabled(const PluginID: TGUID; Enabled: Boolean);
    
    /// <summary>
    /// Check if a plugin is enabled
    /// </summary>
    function IsPluginEnabled(const PluginID: TGUID): Boolean;
    
    /// <summary>
    /// Notify plugins of language change
    /// </summary>
    procedure NotifyLanguageChanged(const NewLanguage: string);
    
    /// <summary>
    /// Notify plugins of theme change
    /// </summary>
    procedure NotifyThemeChanged(const NewTheme: string);
    
    /// <summary>
    /// Notify plugins of config change
    /// </summary>
    procedure NotifyConfigChanged(const Key, OldValue, NewValue: string);
    
    /// <summary>Plugins directory path</summary>
    property PluginsDir: string read FPluginsDir;
    
    /// <summary>Plugin loaded event</summary>
    property OnPluginLoaded: TPluginLoadedEvent read FOnPluginLoaded write FOnPluginLoaded;
    
    /// <summary>Plugin unloaded event</summary>
    property OnPluginUnloaded: TPluginUnloadedEvent read FOnPluginUnloaded write FOnPluginUnloaded;
    
    /// <summary>Plugin error event</summary>
    property OnPluginError: TPluginErrorEvent read FOnPluginError write FOnPluginError;
  end;

  /// <summary>
  /// Raised when a plugin cannot be unloaded because one or more other
  /// loaded plugins declare a dependency on it (BIZ2-024).
  /// </summary>
  EPluginInUse = class(Exception);

implementation

uses
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  DeepBase.Consts, DeepBase.Logging;

{$IFDEF MSWINDOWS}
const
  WINTRUST_ACTION_GENERIC_VERIFY_V2: TGUID = '{00AAC56B-CD44-11d0-8CC2-00C04FC295EE}';

type
  WINTRUST_FILE_INFO = record
    cbStruct: DWORD;
    pcwszFilePath: PWideChar;
    hFile: THandle;
    pgKnownSubject: Pointer;
  end;
  PWINTRUST_FILE_INFO = ^WINTRUST_FILE_INFO;

  WINTRUST_DATA = record
    cbStruct: DWORD;
    pPolicyCallbackData: Pointer;
    pSIPClientData: Pointer;
    dwUIChoice: DWORD;
    fdwRevocationChecks: DWORD;
    dwUnionChoice: DWORD;
    pFile: PWINTRUST_FILE_INFO;
    pCatalog: Pointer;
    pBlob: Pointer;
    pSgnr: Pointer;
    pCert: Pointer;
    dwStateAction: DWORD;
    hWVTStateData: THandle;
    pwszURLReference: PWideChar;
    dwProvFlags: DWORD;
    dwUIContext: DWORD;
    pSignatureSettings: Pointer;
  end;
  PWINTRUST_DATA = ^WINTRUST_DATA;

const
  WTD_UI_NONE = 2;
  WTD_REVOKE_NONE = 0;
  WTD_CHOICE_FILE = 1;
  WTD_STATEACTION_VERIFY = 1;
  WTD_STATEACTION_CLOSE = 2;
  // BIZ-R3-018: force WinVerifyTrust to only use cached URLs (no live CRL/OCSP
  // network fetch). With WTD_REVOKE_NONE, revocation checking is already
  // disabled, so a live network round-trip is unnecessary and would freeze the
  // calling (often UI/main) thread on slow networks across many plugins.
  WTD_CACHE_ONLY_URL_RETRIEVAL = $40;

function WinVerifyTrust(hwnd: THandle; pgActionID: PGUID; pWVTData: Pointer): Longint;
  stdcall; external 'wintrust.dll' name 'WinVerifyTrust';
{$ENDIF}

const
  // FR-001 fix: use canonical DeepBase_VERSION_STRING from DeepBase.Consts.
  DeepBase_VERSION = DeepBase_VERSION_STRING;
  PLUGIN_CATEGORY = 'Plugins';
  PLUGIN_CONFIG_PREFIX = 'Plugin.';

function NormalizePluginConfigKey(const Key: string): string;
begin
  if Key.StartsWith(PLUGIN_CONFIG_PREFIX) then
    Exit(Key);

  if (Key <> '') and (not Key.Contains('.')) then
    Exit(PLUGIN_CONFIG_PREFIX + Key);

  raise EArgumentException.CreateFmt(
    'Plugin configuration keys must start with Plugin. Invalid key: %s',
    [Key]
  );
end;

function IsSecurityConfigKey(const Key: string): Boolean;
var
  LowerKey: string;
  Token: string;
  Tokens: TArray<string>;
begin
  LowerKey := Key.ToLower;

  if LowerKey.Contains('password') or LowerKey.Contains('secret') or
    LowerKey.Contains('token') or LowerKey.Contains('credential') or
    LowerKey.Contains('private') then
    Exit(True);

  Tokens := LowerKey.Split(['.', '_', '-', ' ', '/', #92, ':']);
  for Token in Tokens do
    if (Token = 'key') or (Token = 'auth') then
      Exit(True);

  Result := False;
end;

{ TPluginContext }

constructor TPluginContext.Create(
  AGetConfigFunc: TPluginGetConfigFunc;
  ASetConfigProc: TPluginSetConfigProc;
  ATranslateFunc: TPluginTranslateFunc;
  ALogProc: TPluginLogProc;
  const ARootPath: string);
begin
  inherited Create;
  FGetConfigFunc := AGetConfigFunc;
  FSetConfigProc := ASetConfigProc;
  FTranslateFunc := ATranslateFunc;
  FLogProc := ALogProc;
  FRootPath := ARootPath;
end;

function TPluginContext.GetConfig(const Key: string; const Default: string): string;
var
  NormalizedKey: string;
begin
  if Assigned(FGetConfigFunc) then
  begin
    Result := FGetConfigFunc(Key, Default);
    if (Result = Default) and (Key <> '') and (not Key.Contains('.')) then
    begin
      NormalizedKey := NormalizePluginConfigKey(Key);
      Result := FGetConfigFunc(NormalizedKey, Default);
    end;
  end
  else
    Result := Default;
end;
procedure TPluginContext.SetConfig(const Key, Value: string);
var
  NormalizedKey: string;
begin
  NormalizedKey := NormalizePluginConfigKey(Key);

  if IsSecurityConfigKey(NormalizedKey) then
    raise EInvalidOpException.CreateFmt(
      'Plugin cannot modify security-related configuration: %s', [Key]
    );

  if Assigned(FSetConfigProc) then
    FSetConfigProc(NormalizedKey, Value);
end;
function TPluginContext.Translate(const Text: string): string;
begin
  if Assigned(FTranslateFunc) then
    Result := FTranslateFunc(Text)
  else
    Result := Text;
end;

procedure TPluginContext.Log(const Message: string; Level: Integer);
begin
  if Assigned(FLogProc) then
    FLogProc(Message, Level);
end;

function TPluginContext.GetRootPath: string;
begin
  Result := FRootPath;
end;

function TPluginContext.GetPluginDataPath(const PluginID: TGUID): string;
begin
  Result := TPath.Combine(FRootPath, 'PluginData');
  Result := TPath.Combine(Result, GUIDToShortString(PluginID));
  
  // Create directory if not exists
  if not TDirectory.Exists(Result) then
    TDirectory.CreateDirectory(Result);
end;

{ TDeepBasePluginManager }

constructor TDeepBasePluginManager.Create(const APluginsDir: string; 
  AContext: IDeepBasePluginContext);
begin
  inherited Create;
  FPlugins := TDictionary<TGUID, TLoadedPlugin>.Create;
  FLoadOrder := TList<TGUID>.Create;
  FPluginsDir := APluginsDir;
  FContext := AContext;
  FLock := TObject.Create;
  FNextLoadOrder := 0;
end;

destructor TDeepBasePluginManager.Destroy;
begin
  UnloadAllPlugins;
  FreeAndNil(FLoadOrder);
  FreeAndNil(FPlugins);
  FreeAndNil(FLock);
  inherited;
end;

function TDeepBasePluginManager.LoadBPL(const Path: string): HMODULE;
begin
  Result := 0;
  
  if not TFile.Exists(Path) then
    Exit;
  
  try
    {$IFDEF MSWINDOWS}
    Result := LoadPackage(Path);
    {$ELSE}
    // Non-Windows platforms would need different implementation
    Result := 0;
    {$ENDIF}
  except
    on E: Exception do
    begin
      Result := 0;
      // Error will be reported by caller
    end;
  end;
end;

procedure TDeepBasePluginManager.UnloadBPL(Handle: HMODULE);
begin
  if Handle <> 0 then
  begin
    try
      {$IFDEF MSWINDOWS}
      UnloadPackage(Handle);
      {$ENDIF}
    except
      on E: Exception do
        {$IFDEF DEBUG}
        OutputDebugString(PChar('DeepBase.PluginManager: UnloadPackage failed: ' + E.Message));
        {$ENDIF}
    end;
  end;
end;

function TDeepBasePluginManager.GetRegisterFunc(Handle: HMODULE): TRegisterPluginFunc;
var
  ProcAddr: Pointer;
begin
  Result := nil;
  
  if Handle = 0 then
    Exit;
  
  {$IFDEF MSWINDOWS}
  ProcAddr := GetProcAddress(Handle, REGISTER_PLUGIN_FUNC);
  if ProcAddr <> nil then
    Result := TRegisterPluginFunc(ProcAddr);
  {$ENDIF}
end;

function TDeepBasePluginManager.CheckDependencies(const Info: TPluginInfo): Boolean;
var
  DepID: TGUID;
begin
  Result := True;
  
  for DepID in Info.Dependencies do
  begin
    if not IsPluginLoaded(DepID) then
    begin
      Result := False;
      Exit;
    end;
  end;
end;

function TDeepBasePluginManager.CheckVersionCompatibility(const MinVersion: string): Boolean;
begin
  if MinVersion = '' then
    Result := True
  else
    Result := CompareVersions(DeepBase_VERSION, MinVersion) >= 0;
end;

procedure TDeepBasePluginManager.FirePluginLoaded(const Info: TPluginInfo);
begin
  if Assigned(FOnPluginLoaded) then
    FOnPluginLoaded(Self, Info);
end;

procedure TDeepBasePluginManager.FirePluginUnloaded(const PluginID: TGUID);
begin
  if Assigned(FOnPluginUnloaded) then
    FOnPluginUnloaded(Self, PluginID);
end;

procedure TDeepBasePluginManager.FirePluginError(const PluginID: TGUID; 
  const PluginName, ErrorMsg: string; IsFatal: Boolean);
var
  Args: TPluginErrorEventArgs;
begin
  if Assigned(FOnPluginError) then
  begin
    Args.PluginID := PluginID;
    Args.PluginName := PluginName;
    Args.ErrorMessage := ErrorMsg;
    Args.IsFatal := IsFatal;
    FOnPluginError(Self, Args);
  end;
end;

function TDeepBasePluginManager.SnapshotLoadedPlugins: TArray<TLoadedPluginData>;
var
  I: Integer;
  LoadedRec: TLoadedPlugin;
begin
  TMonitor.Enter(FLock);
  try
    SetLength(Result, FPlugins.Count);
    I := 0;
    for LoadedRec in FPlugins.Values do
    begin
      Result[I].Info := LoadedRec.Info;
      Result[I].Plugin := LoadedRec.Plugin;
      Result[I].PackageHandle := LoadedRec.PackageHandle;
      Inc(I);
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TDeepBasePluginManager.GetPluginEnabledSetting(const PluginID: TGUID): Boolean;
var
  Key, Value: string;
begin
  Key := PLUGIN_CONFIG_PREFIX + GUIDToShortString(PluginID) + '.Enabled';
  if Assigned(FContext) then
    Value := FContext.GetConfig(Key, '1')
  else
    Value := '1';
  Result := (Value = '1') or (Value.ToLower = 'true');
end;

procedure TDeepBasePluginManager.SetPluginEnabledSetting(const PluginID: TGUID; Enabled: Boolean);
var
  Key: string;
begin
  Key := PLUGIN_CONFIG_PREFIX + GUIDToShortString(PluginID) + '.Enabled';
  if Assigned(FContext) then
  begin
    if Enabled then
      FContext.SetConfig(Key, '1')
    else
      FContext.SetConfig(Key, '0');
  end;
end;

function TDeepBasePluginManager.LoadPlugin(const BPLPath: string): Boolean;
var
  Handle: HMODULE;
  RegisterFunc: TRegisterPluginFunc;
  Plugin: IDeepBasePlugin;
  PluginBase: TDeepBasePluginBase;
  Info: TPluginInfo;
  LoadedRec: TLoadedPlugin;
  // BIZ2-023 fix: error details captured under lock, callback fired outside.
  ErrorMsg: string;
  ErrorID: TGUID;
  ErrorName: string;
  ErrorFatal: Boolean;
begin
  Result := False;
  Handle := 0;
  ErrorMsg := '';
  ErrorID := TGUID.Empty;
  ErrorName := '';
  ErrorFatal := False;

  TMonitor.Enter(FLock);
  try
    // 1. ��֤����ļ�·����ȫ��
    if not IsValidPluginPath(BPLPath) then
    begin
      ErrorMsg := 'Invalid plugin path (potential path traversal): ' + BPLPath;
      ErrorID := TGUID.Empty;
      ErrorName := ExtractFileName(BPLPath);
      ErrorFatal := True;
      // No BPL loaded yet, nothing to clean up
      Exit;
    end;

    // 2. Validate plugin signature
    if not VerifyPluginSignature(BPLPath) then
    begin
      ErrorMsg := 'Plugin signature verification failed: ' + BPLPath;
      ErrorID := TGUID.Empty;
      ErrorName := ExtractFileName(BPLPath);
      ErrorFatal := True;
      Exit;
    end;

    // 3. Load BPL
    Handle := LoadBPL(BPLPath);
    if Handle = 0 then
    begin
      ErrorMsg := 'Failed to load BPL: ' + BPLPath;
      ErrorID := TGUID.Empty;
      ErrorName := ExtractFileName(BPLPath);
      ErrorFatal := False;
      Exit;
    end;

    // 4. Get RegisterPlugin function
    RegisterFunc := GetRegisterFunc(Handle);
    if not Assigned(RegisterFunc) then
    begin
      ErrorMsg := 'Plugin does not export RegisterPlugin function';
      ErrorID := TGUID.Empty;
      ErrorName := ExtractFileName(BPLPath);
      ErrorFatal := False;
      Exit;
    end;

    // 5. Call RegisterPlugin to get plugin instance
    try
      Plugin := RegisterFunc();
    except
      on E: Exception do
      begin
        ErrorMsg := 'RegisterPlugin failed: ' + E.Message;
        ErrorID := TGUID.Empty;
        ErrorName := ExtractFileName(BPLPath);
        ErrorFatal := False;
        Exit;
      end;
    end;

    if Plugin = nil then
    begin
      ErrorMsg := 'RegisterPlugin returned nil';
      ErrorID := TGUID.Empty;
      ErrorName := ExtractFileName(BPLPath);
      ErrorFatal := False;
      Exit;
    end;

    // 6. Get plugin info
    Info := Plugin.GetPluginInfo;

    if not GetPluginEnabledSetting(Info.ID) then
    begin
      ErrorMsg := 'Plugin disabled by configuration: ' + Info.Name;
      ErrorID := Info.ID;
      ErrorName := Info.Name;
      ErrorFatal := False;
      Exit;
    end;

    // Check if already loaded
    if FPlugins.ContainsKey(Info.ID) then
    begin
      ErrorMsg := 'Plugin already loaded: ' + Info.Name;
      ErrorID := Info.ID;
      ErrorName := Info.Name;
      ErrorFatal := False;
      Exit;
    end;

    // 7. Check version compatibility
    if not CheckVersionCompatibility(Info.MinDeepBaseVersion) then
    begin
      ErrorMsg := Format('Plugin requires DeepBase %s, but current version is %s',
        [Info.MinDeepBaseVersion, DeepBase_VERSION]);
      ErrorID := Info.ID;
      ErrorName := Info.Name;
      ErrorFatal := False;
      Exit;
    end;

    // 8. Check dependencies
    if not CheckDependencies(Info) then
    begin
      ErrorMsg := 'Required dependencies not loaded';
      ErrorID := Info.ID;
      ErrorName := Info.Name;
      ErrorFatal := False;
      Exit;
    end;

    // 9. Set context (if TDeepBasePluginBase)
    if Plugin.QueryInterface(IDeepBasePlugin, PluginBase) = S_OK then
    begin
      // Try to get the actual object
    end;
    // Use reflection to call SetContext if available
    if Plugin is TDeepBasePluginBase then
      TDeepBasePluginBase(Plugin).SetContext(FContext);

    // 10. Initialize plugin
    if not Plugin.Initialize then
    begin
      ErrorMsg := 'Plugin initialization failed';
      if Plugin.GetLastError <> '' then
        ErrorMsg := ErrorMsg + ': ' + Plugin.GetLastError;
      ErrorID := Info.ID;
      ErrorName := Info.Name;
      ErrorFatal := False;
      Exit;
    end;

    // 11. Add to loaded plugins
    LoadedRec.Plugin := Plugin;
    LoadedRec.Info := Info;
    LoadedRec.BPLPath := BPLPath;
    LoadedRec.PackageHandle := Handle;
    LoadedRec.LoadOrder := FNextLoadOrder;
    Inc(FNextLoadOrder);

    FPlugins.Add(Info.ID, LoadedRec);
    FLoadOrder.Add(Info.ID);
    Result := True;

  finally
    // BIZ2-023 fix: release FLock BEFORE invoking any user callback.
    // If the callback re-enters the manager (e.g. calls GetPluginState)
    // it must not deadlock on FLock. Exit from try..finally runs the
    // finally block first, so all post-lock work goes here.
    TMonitor.Exit(FLock);

    // Post-lock: clean up BPL on failure and fire callbacks lock-free
    if (not Result) and (Handle <> 0) then
      UnloadBPL(Handle);

    if (not Result) and (ErrorMsg <> '') then
      FirePluginError(ErrorID, ErrorName, ErrorMsg, ErrorFatal)
    else if Result then
      FirePluginLoaded(Info);
  end;
end;

function TDeepBasePluginManager.UnloadPlugin(const PluginID: TGUID): Boolean;
var
  LoadedRec: TLoadedPlugin;
  OtherRec: TLoadedPlugin;
  DepID: TGUID;
  DependentNames: string;
  PluginInfo: TPluginInfo;
  PackageHandle: HMODULE;
  PluginIntf: IDeepBasePlugin;
begin
  Result := False;

  TMonitor.Enter(FLock);
  try
    if not FPlugins.TryGetValue(PluginID, LoadedRec) then
      Exit;

    // BIZ2-024 fix: check reverse dependencies before unloading.
    // If any loaded plugin declares a dependency on this one, refuse
    // to unload (raises EPluginInUse so the caller can handle it).
    DependentNames := '';
    for OtherRec in FPlugins.Values do
    begin
      if OtherRec.Info.ID = PluginID then
        Continue;
      for DepID in OtherRec.Info.Dependencies do
      begin
        if DepID = PluginID then
        begin
          if DependentNames <> '' then
            DependentNames := DependentNames + ', ';
          DependentNames := DependentNames + OtherRec.Info.Name;
          Break;
        end;
      end;
    end;
    if DependentNames <> '' then
      raise EPluginInUse.CreateFmt(
        'Cannot unload plugin "%s": the following loaded plugins depend on it: %s',
        [LoadedRec.Info.Name, DependentNames]);

    // Snapshot data needed for post-lock operations
    PluginInfo := LoadedRec.Info;
    PackageHandle := LoadedRec.PackageHandle;
    PluginIntf := LoadedRec.Plugin;

    // Finalize plugin
    if PluginIntf <> nil then
    begin
      try
        PluginIntf.Finalize;
      except
        on E: Exception do
          FirePluginError(PluginID, PluginInfo.Name, 'Finalize failed: ' + E.Message, False);
      end;
    end;

    // Unload BPL
    UnloadBPL(PackageHandle);

    // Remove from collections
    FPlugins.Remove(PluginID);
    FLoadOrder.Remove(PluginID);
    Result := True;
  finally
    // BIZ2-023 fix: release FLock BEFORE invoking the Unloaded callback.
    TMonitor.Exit(FLock);

    // Fire callback lock-free. Only fires with Result=True on success;
    // on the early Exit (plugin not found) Result stays False and the
    // callback is skipped.
    if Result then
      FirePluginUnloaded(PluginID);
  end;
end;

procedure TDeepBasePluginManager.LoadAllPlugins;
var
  Files: TArray<string>;
  BPLPath: string;
begin
  if not TDirectory.Exists(FPluginsDir) then
  begin
    TDirectory.CreateDirectory(FPluginsDir);
    Exit; // No plugins to load
  end;
  
  Files := TDirectory.GetFiles(FPluginsDir, '*.bpl');
  
  for BPLPath in Files do
  begin
    // Check if plugin is enabled
    // For first-time loading, we load all by default
    LoadPlugin(BPLPath);
  end;
end;

procedure TDeepBasePluginManager.UnloadAllPlugins;
var
  Snapshot: TArray<TLoadedPluginData>;
  I: Integer;
  LoadedRec: TLoadedPlugin;
  UnloadedCallback: TPluginUnloadedEvent;
begin
  // BIZ2-023 fix: snapshot plugins and clear collections under lock,
  // then finalize each plugin and fire callbacks outside the lock.
  // This prevents deadlock if a callback re-enters the manager.
  TMonitor.Enter(FLock);
  try
    SetLength(Snapshot, FLoadOrder.Count);
    for I := 0 to FLoadOrder.Count - 1 do
    begin
      if FPlugins.TryGetValue(FLoadOrder[I], LoadedRec) then
      begin
        Snapshot[I].Info := LoadedRec.Info;
        Snapshot[I].Plugin := LoadedRec.Plugin;
        Snapshot[I].PackageHandle := LoadedRec.PackageHandle;
      end;
    end;
    FPlugins.Clear;
    FLoadOrder.Clear;
    UnloadedCallback := FOnPluginUnloaded;
  finally
    TMonitor.Exit(FLock);
  end;

  // Finalize and unload in reverse load order, lock-free
  for I := Length(Snapshot) - 1 downto 0 do
  begin
    if Snapshot[I].Plugin <> nil then
    begin
      try
        Snapshot[I].Plugin.Finalize;
      except
        on E: Exception do
          FirePluginError(Snapshot[I].Info.ID, Snapshot[I].Info.Name,
            'Finalize failed: ' + E.Message, False);
      end;
    end;
    UnloadBPL(Snapshot[I].PackageHandle);
    if Assigned(UnloadedCallback) then
      UnloadedCallback(Self, Snapshot[I].Info.ID);
  end;
end;

function TDeepBasePluginManager.GetPlugin(const PluginID: TGUID): IDeepBasePlugin;
var
  LoadedRec: TLoadedPlugin;
begin
  Result := nil;
  
  TMonitor.Enter(FLock);
  try
    if FPlugins.TryGetValue(PluginID, LoadedRec) then
      Result := LoadedRec.Plugin;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TDeepBasePluginManager.GetLoadedPlugins: TArray<TPluginInfo>;
var
  I: Integer;
  LoadedRec: TLoadedPlugin;
begin
  TMonitor.Enter(FLock);
  try
    SetLength(Result, FPlugins.Count);
    I := 0;
    for LoadedRec in FPlugins.Values do
    begin
      Result[I] := LoadedRec.Info;
      Inc(I);
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TDeepBasePluginManager.IsPluginLoaded(const PluginID: TGUID): Boolean;
begin
  TMonitor.Enter(FLock);
  try
    Result := FPlugins.ContainsKey(PluginID);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TDeepBasePluginManager.PluginCount: Integer;
begin
  TMonitor.Enter(FLock);
  try
    Result := FPlugins.Count;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TDeepBasePluginManager.SetPluginEnabled(const PluginID: TGUID; Enabled: Boolean);
begin
  SetPluginEnabledSetting(PluginID, Enabled);
end;

function TDeepBasePluginManager.IsPluginEnabled(const PluginID: TGUID): Boolean;
begin
  Result := GetPluginEnabledSetting(PluginID);
end;

procedure TDeepBasePluginManager.NotifyLanguageChanged(const NewLanguage: string);
var
  Snapshot: TArray<TLoadedPluginData>;
  Item: TLoadedPluginData;
  EventHandler: IDeepBasePluginEvents;
begin
  // BIZ2-023 fix: snapshot plugins under lock, then invoke callbacks
  // outside the lock to prevent deadlock if a handler re-enters FLock.
  Snapshot := SnapshotLoadedPlugins;
  for Item in Snapshot do
  begin
    if Supports(Item.Plugin, IDeepBasePluginEvents, EventHandler) then
    begin
      try
        EventHandler.OnLanguageChanged(NewLanguage);
      except
        on E: Exception do
          FirePluginError(Item.Info.ID, Item.Info.Name,
            'OnLanguageChanged error: ' + E.Message, False);
      end;
    end;
  end;
end;

procedure TDeepBasePluginManager.NotifyThemeChanged(const NewTheme: string);
var
  Snapshot: TArray<TLoadedPluginData>;
  Item: TLoadedPluginData;
  EventHandler: IDeepBasePluginEvents;
begin
  // BIZ2-023 fix: snapshot plugins under lock, then invoke callbacks
  // outside the lock to prevent deadlock if a handler re-enters FLock.
  Snapshot := SnapshotLoadedPlugins;
  for Item in Snapshot do
  begin
    if Supports(Item.Plugin, IDeepBasePluginEvents, EventHandler) then
    begin
      try
        EventHandler.OnThemeChanged(NewTheme);
      except
        on E: Exception do
          FirePluginError(Item.Info.ID, Item.Info.Name,
            'OnThemeChanged error: ' + E.Message, False);
      end;
    end;
  end;
end;

procedure TDeepBasePluginManager.NotifyConfigChanged(const Key, OldValue, NewValue: string);
var
  Snapshot: TArray<TLoadedPluginData>;
  Item: TLoadedPluginData;
  EventHandler: IDeepBasePluginEvents;
begin
  // BIZ2-023 fix: snapshot plugins under lock, then invoke callbacks
  // outside the lock to prevent deadlock if a handler re-enters FLock.
  Snapshot := SnapshotLoadedPlugins;
  for Item in Snapshot do
  begin
    if Supports(Item.Plugin, IDeepBasePluginEvents, EventHandler) then
    begin
      try
        EventHandler.OnConfigChanged(Key, OldValue, NewValue);
      except
        on E: Exception do
          FirePluginError(Item.Info.ID, Item.Info.Name,
            'OnConfigChanged error: ' + E.Message, False);
      end;
    end;
  end;
end;

function TDeepBasePluginManager.IsValidPluginPath(const Path: string): Boolean;
var
  CanonicalPath, PluginsCanonical: string;
begin
  Result := False;
  
  try
    // ��ȡ�淶��·��
    CanonicalPath := TPath.GetFullPath(Path);
    PluginsCanonical := TPath.GetFullPath(FPluginsDir);
    
    // ���·���Ƿ��ڲ��Ŀ¼��
    Result := CanonicalPath.StartsWith(PluginsCanonical + TPath.DirectorySeparatorChar) or
              (CanonicalPath = PluginsCanonical);
              
    // ����ļ���չ��
    if Result then
      Result := SameText(TPath.GetExtension(Path), '.bpl');
      
  except
    on E: Exception do
      Result := False;
  end;
end;

function TDeepBasePluginManager.VerifyPluginSignature(const Path: string): Boolean;
{$IFDEF MSWINDOWS}
var
  FileInfo: WINTRUST_FILE_INFO;
  TrustData: WINTRUST_DATA;
  ActionId: TGUID;
  Status: Longint;
begin
  if not FileExists(Path) then
    Exit(False);

  FillChar(FileInfo, SizeOf(FileInfo), 0);
  FileInfo.cbStruct := SizeOf(FileInfo);
  FileInfo.pcwszFilePath := PWideChar(WideString(Path));

  FillChar(TrustData, SizeOf(TrustData), 0);
  TrustData.cbStruct := SizeOf(TrustData);
  TrustData.dwUIChoice := WTD_UI_NONE;
  TrustData.fdwRevocationChecks := WTD_REVOKE_NONE;
  TrustData.dwUnionChoice := WTD_CHOICE_FILE;
  TrustData.pFile := @FileInfo;
  TrustData.dwStateAction := WTD_STATEACTION_VERIFY;
  // BIZ-R3-018: avoid blocking CRL/OCSP network fetches on the calling thread.
  TrustData.dwProvFlags := WTD_CACHE_ONLY_URL_RETRIEVAL;

  ActionId := WINTRUST_ACTION_GENERIC_VERIFY_V2;
  Status := WinVerifyTrust(INVALID_HANDLE_VALUE, @ActionId, @TrustData);

  // Close state handle
  TrustData.dwStateAction := WTD_STATEACTION_CLOSE;
  WinVerifyTrust(INVALID_HANDLE_VALUE, @ActionId, @TrustData);

  Result := (Status = 0);
  if not Result then
  begin
    if DeepBase.Logging.Logger <> nil then
      DeepBase.Logging.Logger.Warn(Format('Plugin signature verification failed (0x%.8x): %s', [Cardinal(Status), Path]), 'Plugin');
  end;
end;
{$ELSE}
begin
  if DeepBase.Logging.Logger <> nil then
    DeepBase.Logging.Logger.Warn('Plugin signature verification not available on this platform: ' + Path, 'Plugin');
  Result := True;
end;
{$ENDIF}

end.
