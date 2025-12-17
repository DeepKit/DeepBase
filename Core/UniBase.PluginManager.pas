{ ============================================================================
  UniBase.PluginManager - Plugin Manager
  
  Version: 0.3
  Description: Manages plugin lifecycle including loading, initialization,
               dependency resolution, and unloading.
  
  Thread Safety: LoadPlugin/UnloadPlugin should be called from main thread.
  ============================================================================ }

unit UniBase.PluginManager;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  System.SyncObjs,
  UniBase.Plugin;

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
    Plugin: IUniBasePlugin;
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
  TPluginContext = class(TInterfacedObject, IUniBasePluginContext)
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
    
    // IUniBasePluginContext implementation
    function GetConfig(const Key: string; const Default: string = ''): string;
    procedure SetConfig(const Key, Value: string);
    function Translate(const Text: string): string;
    procedure Log(const Message: string; Level: Integer = 1);
    function GetRootPath: string;
    function GetPluginDataPath(const PluginID: TGUID): string;
  end;
  
  /// <summary>
  /// Plugin manager - handles plugin lifecycle
  /// </summary>
  TUniBasePluginManager = class
  private
    FPlugins: TDictionary<TGUID, TLoadedPlugin>;
    FLoadOrder: TList<TGUID>;
    FPluginsDir: string;
    FContext: IUniBasePluginContext;
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
    
  public
    constructor Create(const APluginsDir: string; AContext: IUniBasePluginContext);
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
    function GetPlugin(const PluginID: TGUID): IUniBasePlugin;
    
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

implementation

uses
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  UniBase.Consts;

const
  UNIBASE_VERSION = '0.3';
  PLUGIN_CATEGORY = 'Plugins';

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
begin
  if Assigned(FGetConfigFunc) then
    Result := FGetConfigFunc(Key, Default)
  else
    Result := Default;
end;

procedure TPluginContext.SetConfig(const Key, Value: string);
const
  PLUGIN_CONFIG_PREFIX = 'Plugin.';
  SECURITY_KEYS: array[0..6] of string = (
    'password', 'secret', 'key', 'token', 'auth', 'credential', 'private'
  );
var
  I: Integer;
  LowerKey: string;
begin
  // 实现基于角色的配置访问控制
  if not Key.StartsWith(PLUGIN_CONFIG_PREFIX) then
    raise EArgumentException.CreateFmt(
      'Plugin configuration keys must start with "%s". Invalid key: %s',
      [PLUGIN_CONFIG_PREFIX, Key]
    );
  
  // 检查是否尝试设置安全相关配置
  LowerKey := Key.ToLower;
  for I := Low(SECURITY_KEYS) to High(SECURITY_KEYS) do
  begin
    if LowerKey.Contains(SECURITY_KEYS[I]) then
      raise EInvalidOpException.CreateFmt(
        'Plugin cannot modify security-related configuration: %s', [Key]
      );
  end;
  
  if Assigned(FSetConfigProc) then
    FSetConfigProc(Key, Value);
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

{ TUniBasePluginManager }

constructor TUniBasePluginManager.Create(const APluginsDir: string; 
  AContext: IUniBasePluginContext);
begin
  inherited Create;
  FPlugins := TDictionary<TGUID, TLoadedPlugin>.Create;
  FLoadOrder := TList<TGUID>.Create;
  FPluginsDir := APluginsDir;
  FContext := AContext;
  FLock := TObject.Create;
  FNextLoadOrder := 0;
end;

destructor TUniBasePluginManager.Destroy;
begin
  UnloadAllPlugins;
  FLoadOrder.Free;
  FPlugins.Free;
  FLock.Free;
  inherited;
end;

function TUniBasePluginManager.LoadBPL(const Path: string): HMODULE;
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

procedure TUniBasePluginManager.UnloadBPL(Handle: HMODULE);
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
        OutputDebugString(PChar('UniBase.PluginManager: UnloadPackage failed: ' + E.Message));
        {$ENDIF}
    end;
  end;
end;

function TUniBasePluginManager.GetRegisterFunc(Handle: HMODULE): TRegisterPluginFunc;
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

function TUniBasePluginManager.CheckDependencies(const Info: TPluginInfo): Boolean;
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

function TUniBasePluginManager.CheckVersionCompatibility(const MinVersion: string): Boolean;
begin
  if MinVersion = '' then
    Result := True
  else
    Result := CompareVersions(UNIBASE_VERSION, MinVersion) >= 0;
end;

procedure TUniBasePluginManager.FirePluginLoaded(const Info: TPluginInfo);
begin
  if Assigned(FOnPluginLoaded) then
    FOnPluginLoaded(Self, Info);
end;

procedure TUniBasePluginManager.FirePluginUnloaded(const PluginID: TGUID);
begin
  if Assigned(FOnPluginUnloaded) then
    FOnPluginUnloaded(Self, PluginID);
end;

procedure TUniBasePluginManager.FirePluginError(const PluginID: TGUID; 
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

function TUniBasePluginManager.GetPluginEnabledSetting(const PluginID: TGUID): Boolean;
var
  Key, Value: string;
begin
  Key := GUIDToShortString(PluginID) + '.Enabled';
  if Assigned(FContext) then
    Value := FContext.GetConfig(PLUGIN_CATEGORY + '.' + Key, '1')
  else
    Value := '1';
  Result := (Value = '1') or (Value.ToLower = 'true');
end;

procedure TUniBasePluginManager.SetPluginEnabledSetting(const PluginID: TGUID; Enabled: Boolean);
var
  Key: string;
begin
  Key := PLUGIN_CATEGORY + '.' + GUIDToShortString(PluginID) + '.Enabled';
  if Assigned(FContext) then
  begin
    if Enabled then
      FContext.SetConfig(Key, '1')
    else
      FContext.SetConfig(Key, '0');
  end;
end;

function TUniBasePluginManager.LoadPlugin(const BPLPath: string): Boolean;
var
  Handle: HMODULE;
  RegisterFunc: TRegisterPluginFunc;
  Plugin: IUniBasePlugin;
  PluginBase: TUniBasePluginBase;
  Info: TPluginInfo;
  LoadedRec: TLoadedPlugin;
  ErrorMsg: string;
begin
  Result := False;
  
  TMonitor.Enter(FLock);
  try
    // 1. 验证插件文件路径安全性
    if not IsValidPluginPath(BPLPath) then
    begin
      ErrorMsg := 'Invalid plugin path (potential path traversal): ' + BPLPath;
      FirePluginError(TGUID.Empty, ExtractFileName(BPLPath), ErrorMsg, True);
      Exit;
    end;
    
    // 2. 验证插件数字签名
    if not VerifyPluginSignature(BPLPath) then
    begin
      ErrorMsg := 'Plugin signature verification failed: ' + BPLPath;
      FirePluginError(TGUID.Empty, ExtractFileName(BPLPath), ErrorMsg, True);
      Exit;
    end;
    
    // 3. Load BPL
    Handle := LoadBPL(BPLPath);
    if Handle = 0 then
    begin
      ErrorMsg := 'Failed to load BPL: ' + BPLPath;
      FirePluginError(TGUID.Empty, ExtractFileName(BPLPath), ErrorMsg, False);
      Exit;
    end;
    
    // 2. Get RegisterPlugin function
    RegisterFunc := GetRegisterFunc(Handle);
    if not Assigned(RegisterFunc) then
    begin
      ErrorMsg := 'Plugin does not export RegisterPlugin function';
      UnloadBPL(Handle);
      FirePluginError(TGUID.Empty, ExtractFileName(BPLPath), ErrorMsg, False);
      Exit;
    end;
    
    // 3. Call RegisterPlugin to get plugin instance
    try
      Plugin := RegisterFunc();
    except
      on E: Exception do
      begin
        ErrorMsg := 'RegisterPlugin failed: ' + E.Message;
        UnloadBPL(Handle);
        FirePluginError(TGUID.Empty, ExtractFileName(BPLPath), ErrorMsg, False);
        Exit;
      end;
    end;
    
    if Plugin = nil then
    begin
      ErrorMsg := 'RegisterPlugin returned nil';
      UnloadBPL(Handle);
      FirePluginError(TGUID.Empty, ExtractFileName(BPLPath), ErrorMsg, False);
      Exit;
    end;
    
    // 4. Get plugin info
    Info := Plugin.GetPluginInfo;
    
    // Check if already loaded
    if FPlugins.ContainsKey(Info.ID) then
    begin
      ErrorMsg := 'Plugin already loaded: ' + Info.Name;
      UnloadBPL(Handle);
      FirePluginError(Info.ID, Info.Name, ErrorMsg, False);
      Exit;
    end;
    
    // 5. Check version compatibility
    if not CheckVersionCompatibility(Info.MinUniBaseVersion) then
    begin
      ErrorMsg := Format('Plugin requires UniBase %s, but current version is %s',
        [Info.MinUniBaseVersion, UNIBASE_VERSION]);
      UnloadBPL(Handle);
      FirePluginError(Info.ID, Info.Name, ErrorMsg, False);
      Exit;
    end;
    
    // 6. Check dependencies
    if not CheckDependencies(Info) then
    begin
      ErrorMsg := 'Required dependencies not loaded';
      UnloadBPL(Handle);
      FirePluginError(Info.ID, Info.Name, ErrorMsg, False);
      Exit;
    end;
    
    // 7. Set context (if TUniBasePluginBase)
    if Plugin.QueryInterface(IUniBasePlugin, PluginBase) = S_OK then
    begin
      // Try to get the actual object
    end;
    // Use reflection to call SetContext if available
    if Plugin is TUniBasePluginBase then
      TUniBasePluginBase(Plugin).SetContext(FContext);
    
    // 8. Initialize plugin
    if not Plugin.Initialize then
    begin
      ErrorMsg := 'Plugin initialization failed';
      if Plugin.GetLastError <> '' then
        ErrorMsg := ErrorMsg + ': ' + Plugin.GetLastError;
      UnloadBPL(Handle);
      FirePluginError(Info.ID, Info.Name, ErrorMsg, False);
      Exit;
    end;
    
    // 9. Add to loaded plugins
    LoadedRec.Plugin := Plugin;
    LoadedRec.Info := Info;
    LoadedRec.BPLPath := BPLPath;
    LoadedRec.PackageHandle := Handle;
    LoadedRec.LoadOrder := FNextLoadOrder;
    Inc(FNextLoadOrder);
    
    FPlugins.Add(Info.ID, LoadedRec);
    FLoadOrder.Add(Info.ID);
    
    FirePluginLoaded(Info);
    Result := True;
    
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TUniBasePluginManager.UnloadPlugin(const PluginID: TGUID): Boolean;
var
  LoadedRec: TLoadedPlugin;
begin
  Result := False;
  
  TMonitor.Enter(FLock);
  try
    if not FPlugins.TryGetValue(PluginID, LoadedRec) then
      Exit;
    
    // Check if other plugins depend on this one
    // (In a full implementation, would check reverse dependencies)
    
    // Finalize plugin
    if LoadedRec.Plugin <> nil then
    begin
      try
        LoadedRec.Plugin.Finalize;
      except
        on E: Exception do
          FirePluginError(PluginID, LoadedRec.Info.Name, 'Finalize failed: ' + E.Message, False);
      end;
      LoadedRec.Plugin := nil;
    end;
    
    // Unload BPL
    UnloadBPL(LoadedRec.PackageHandle);
    
    // Remove from collections
    FPlugins.Remove(PluginID);
    FLoadOrder.Remove(PluginID);
    
    FirePluginUnloaded(PluginID);
    Result := True;
    
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TUniBasePluginManager.LoadAllPlugins;
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

procedure TUniBasePluginManager.UnloadAllPlugins;
var
  I: Integer;
  PluginID: TGUID;
begin
  TMonitor.Enter(FLock);
  try
    // Unload in reverse load order
    for I := FLoadOrder.Count - 1 downto 0 do
    begin
      PluginID := FLoadOrder[I];
      UnloadPlugin(PluginID);
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TUniBasePluginManager.GetPlugin(const PluginID: TGUID): IUniBasePlugin;
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

function TUniBasePluginManager.GetLoadedPlugins: TArray<TPluginInfo>;
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

function TUniBasePluginManager.IsPluginLoaded(const PluginID: TGUID): Boolean;
begin
  TMonitor.Enter(FLock);
  try
    Result := FPlugins.ContainsKey(PluginID);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TUniBasePluginManager.PluginCount: Integer;
begin
  TMonitor.Enter(FLock);
  try
    Result := FPlugins.Count;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TUniBasePluginManager.SetPluginEnabled(const PluginID: TGUID; Enabled: Boolean);
begin
  SetPluginEnabledSetting(PluginID, Enabled);
end;

function TUniBasePluginManager.IsPluginEnabled(const PluginID: TGUID): Boolean;
begin
  Result := GetPluginEnabledSetting(PluginID);
end;

procedure TUniBasePluginManager.NotifyLanguageChanged(const NewLanguage: string);
var
  LoadedRec: TLoadedPlugin;
  EventHandler: IUniBasePluginEvents;
begin
  TMonitor.Enter(FLock);
  try
    for LoadedRec in FPlugins.Values do
    begin
      if Supports(LoadedRec.Plugin, IUniBasePluginEvents, EventHandler) then
      begin
        try
          EventHandler.OnLanguageChanged(NewLanguage);
        except
          on E: Exception do
            FirePluginError(LoadedRec.Info.ID, LoadedRec.Info.Name, 
              'OnLanguageChanged error: ' + E.Message, False);
        end;
      end;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TUniBasePluginManager.NotifyThemeChanged(const NewTheme: string);
var
  LoadedRec: TLoadedPlugin;
  EventHandler: IUniBasePluginEvents;
begin
  TMonitor.Enter(FLock);
  try
    for LoadedRec in FPlugins.Values do
    begin
      if Supports(LoadedRec.Plugin, IUniBasePluginEvents, EventHandler) then
      begin
        try
          EventHandler.OnThemeChanged(NewTheme);
        except
          on E: Exception do
            FirePluginError(LoadedRec.Info.ID, LoadedRec.Info.Name, 
              'OnThemeChanged error: ' + E.Message, False);
        end;
      end;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TUniBasePluginManager.NotifyConfigChanged(const Key, OldValue, NewValue: string);
var
  LoadedRec: TLoadedPlugin;
  EventHandler: IUniBasePluginEvents;
begin
  TMonitor.Enter(FLock);
  try
    for LoadedRec in FPlugins.Values do
    begin
      if Supports(LoadedRec.Plugin, IUniBasePluginEvents, EventHandler) then
      begin
        try
          EventHandler.OnConfigChanged(Key, OldValue, NewValue);
        except
          on E: Exception do
            FirePluginError(LoadedRec.Info.ID, LoadedRec.Info.Name, 
              'OnConfigChanged error: ' + E.Message, False);
        end;
      end;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TUniBasePluginManager.IsValidPluginPath(const Path: string): Boolean;
var
  CanonicalPath, PluginsCanonical: string;
begin
  Result := False;
  
  try
    // 获取规范化路径
    CanonicalPath := TPath.GetFullPath(Path);
    PluginsCanonical := TPath.GetFullPath(FPluginsDir);
    
    // 检查路径是否在插件目录内
    Result := CanonicalPath.StartsWith(PluginsCanonical + TPath.DirectorySeparatorChar) or
              (CanonicalPath = PluginsCanonical);
              
    // 检查文件扩展名
    if Result then
      Result := SameText(TPath.GetExtension(Path), '.bpl');
      
  except
    on E: Exception do
      Result := False;
  end;
end;

function TUniBasePluginManager.VerifyPluginSignature(const Path: string): Boolean;
begin
  // TODO: Implement plugin signature verification using WinVerifyTrust API
  // Currently returns True to allow plugin loading during development
  // In production, should verify Authenticode signature before loading
  Result := True;
end;

end.
