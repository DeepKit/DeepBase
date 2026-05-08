{ ============================================================================
  DeepBase.Plugin - Plugin Interfaces and Types
  
  Version: 0.3
  Description: Defines the plugin interface contract and supporting types
               for the DeepBase plugin system.
  
  Plugin developers should implement IDeepBasePlugin interface and export
  a RegisterPlugin function that returns the plugin instance.
  ============================================================================ }

unit DeepBase.Plugin;

interface

uses
  System.SysUtils,
  System.Classes;

type
  /// <summary>
  /// Plugin state enumeration
  /// </summary>
  TPluginState = (
    psUnloaded,    // Not loaded
    psLoading,     // Currently loading
    psLoaded,      // Loaded but not yet initialized
    psActive,      // Initialized and active
    psError,       // Failed to load or initialize
    psUnloading    // Currently unloading
  );
  
  /// <summary>
  /// Plugin capability flags
  /// </summary>
  TPluginCapability = (
    pcMenuItems,      // Plugin provides menu items
    pcToolbarItems,   // Plugin provides toolbar items
    pcSettingsPage,   // Plugin provides settings UI
    pcBackgroundTask, // Plugin runs background tasks
    pcEventHandler    // Plugin handles framework events
  );
  TPluginCapabilities = set of TPluginCapability;
  
  /// <summary>
  /// Plugin information record
  /// </summary>
  TPluginInfo = record
    /// <summary>Unique plugin identifier</summary>
    ID: TGUID;
    /// <summary>Display name</summary>
    Name: string;
    /// <summary>Version string (e.g., "1.0.0")</summary>
    Version: string;
    /// <summary>Author name</summary>
    Author: string;
    /// <summary>Description</summary>
    Description: string;
    /// <summary>Website or support URL</summary>
    URL: string;
    /// <summary>Plugin capabilities</summary>
    Capabilities: TPluginCapabilities;
    /// <summary>Minimum required DeepBase version</summary>
    MinDeepBaseVersion: string;
    /// <summary>GUIDs of required plugins</summary>
    Dependencies: TArray<TGUID>;
  end;
  
  /// <summary>
  /// Menu item provided by plugin
  /// </summary>
  TPluginMenuItem = record
    /// <summary>Unique identifier for this menu item</summary>
    ID: string;
    /// <summary>Display caption (can include & for accelerator)</summary>
    Caption: string;
    /// <summary>Parent menu path (e.g., "Tools" or "Tools/Options")</summary>
    ParentPath: string;
    /// <summary>Position hint (lower = higher in menu)</summary>
    Position: Integer;
    /// <summary>Keyboard shortcut (e.g., "Ctrl+Shift+P")</summary>
    Shortcut: string;
    /// <summary>Icon resource name (optional)</summary>
    IconName: string;
    /// <summary>Whether item is enabled</summary>
    Enabled: Boolean;
    /// <summary>Whether item is visible</summary>
    Visible: Boolean;
  end;
  
  /// <summary>
  /// Toolbar item provided by plugin
  /// </summary>
  TPluginToolbarItem = record
    /// <summary>Unique identifier</summary>
    ID: string;
    /// <summary>Tooltip text</summary>
    Hint: string;
    /// <summary>Target toolbar name (e.g., "Main", "Edit")</summary>
    ToolbarName: string;
    /// <summary>Position in toolbar</summary>
    Position: Integer;
    /// <summary>Icon resource name</summary>
    IconName: string;
    /// <summary>Whether item is enabled</summary>
    Enabled: Boolean;
  end;
  
  /// <summary>
  /// Plugin error event arguments
  /// </summary>
  TPluginErrorEventArgs = record
    PluginID: TGUID;
    PluginName: string;
    ErrorMessage: string;
    IsFatal: Boolean;
  end;
  
  /// <summary>
  /// Plugin event handler types
  /// </summary>
  TPluginLoadedEvent = procedure(Sender: TObject; const Info: TPluginInfo) of object;
  TPluginUnloadedEvent = procedure(Sender: TObject; const PluginID: TGUID) of object;
  TPluginErrorEvent = procedure(Sender: TObject; const Args: TPluginErrorEventArgs) of object;
  TPluginMenuClickEvent = procedure(Sender: TObject; const MenuItemID: string) of object;
  TPluginToolbarClickEvent = procedure(Sender: TObject; const ToolbarItemID: string) of object;
  
  /// <summary>
  /// Base plugin interface - all plugins must implement this
  /// </summary>
  IDeepBasePlugin = interface
    ['{D1E2F3A4-B5C6-4D7E-8F9A-0B1C2D3E4F5A}']
    
    /// <summary>Get plugin metadata</summary>
    function GetPluginInfo: TPluginInfo;
    
    /// <summary>
    /// Initialize the plugin. Called after loading.
    /// Return True if successful, False otherwise.
    /// </summary>
    function Initialize: Boolean;
    
    /// <summary>
    /// Finalize the plugin. Called before unloading.
    /// Return True if safe to unload, False to cancel unload.
    /// </summary>
    function Finalize: Boolean;
    
    /// <summary>Get current plugin state</summary>
    function GetState: TPluginState;
    
    /// <summary>Get last error message (if State = psError)</summary>
    function GetLastError: string;
  end;
  
  /// <summary>
  /// Optional interface for plugins that provide UI elements
  /// </summary>
  IDeepBasePluginUI = interface
    ['{E2F3A4B5-C6D7-4E8F-9A0B-1C2D3E4F5A6B}']
    
    /// <summary>Get menu items to add to host application</summary>
    function GetMenuItems: TArray<TPluginMenuItem>;
    
    /// <summary>Get toolbar items to add to host application</summary>
    function GetToolbarItems: TArray<TPluginToolbarItem>;
    
    /// <summary>Get settings page component (nil if not supported)</summary>
    function GetSettingsPage(AOwner: TComponent): TComponent;
    
    /// <summary>Called when a menu item is clicked</summary>
    procedure OnMenuClick(const MenuItemID: string);
    
    /// <summary>Called when a toolbar item is clicked</summary>
    procedure OnToolbarClick(const ToolbarItemID: string);
  end;
  
  /// <summary>
  /// Optional interface for plugins that handle framework events
  /// </summary>
  IDeepBasePluginEvents = interface
    ['{F3A4B5C6-D7E8-4F9A-0B1C-2D3E4F5A6B7C}']
    
    /// <summary>Called when language changes</summary>
    procedure OnLanguageChanged(const NewLanguage: string);
    
    /// <summary>Called when theme changes</summary>
    procedure OnThemeChanged(const NewTheme: string);
    
    /// <summary>Called when a config value changes</summary>
    procedure OnConfigChanged(const Key, OldValue, NewValue: string);
  end;
  
  /// <summary>
  /// Plugin context passed to plugins during initialization
  /// Provides access to framework services
  /// </summary>
  IDeepBasePluginContext = interface
    ['{A4B5C6D7-E8F9-4A0B-1C2D-3E4F5A6B7C8D}']
    
    /// <summary>Get configuration value</summary>
    function GetConfig(const Key: string; const Default: string = ''): string;
    
    /// <summary>Set configuration value (restricted to plugin-specific keys)</summary>
    procedure SetConfig(const Key, Value: string);
    
    /// <summary>Translate text using current language</summary>
    function Translate(const Text: string): string;
    
    /// <summary>Log a message</summary>
    procedure Log(const Message: string; Level: Integer = 1); // 1=Info
    
    /// <summary>Get application root path</summary>
    function GetRootPath: string;
    
    /// <summary>Get plugin data directory (created if not exists)</summary>
    function GetPluginDataPath(const PluginID: TGUID): string;
  end;
  
  /// <summary>
  /// Base class for plugin implementations.
  /// Provides default implementations and helper methods.
  /// </summary>
  TDeepBasePluginBase = class(TInterfacedObject, IDeepBasePlugin)
  private
    FState: TPluginState;
    FLastError: string;
    FContext: IDeepBasePluginContext;
  protected
    /// <summary>Plugin context for accessing framework services</summary>
    property Context: IDeepBasePluginContext read FContext;
    
    /// <summary>Set error state with message</summary>
    procedure SetError(const ErrorMsg: string);
    
    /// <summary>Set state</summary>
    procedure SetState(AState: TPluginState);
    
    /// <summary>Override to provide plugin info</summary>
    function DoGetPluginInfo: TPluginInfo; virtual; abstract;
    
    /// <summary>Override to perform initialization</summary>
    function DoInitialize: Boolean; virtual;
    
    /// <summary>Override to perform cleanup</summary>
    function DoFinalize: Boolean; virtual;
  public
    constructor Create;
    
    /// <summary>Set the plugin context (called by PluginManager)</summary>
    procedure SetContext(AContext: IDeepBasePluginContext);
    
    // IDeepBasePlugin implementation
    function GetPluginInfo: TPluginInfo;
    function Initialize: Boolean;
    function Finalize: Boolean;
    function GetState: TPluginState;
    function GetLastError: string;
    
    property State: TPluginState read FState;
    property LastError: string read FLastError;
  end;

/// <summary>
/// Plugin registration function type.
/// Each plugin BPL must export a function of this type named "RegisterPlugin".
/// </summary>
type
  TRegisterPluginFunc = function: IDeepBasePlugin;

/// <summary>
/// Helper: Create a TPluginInfo record
/// </summary>
function MakePluginInfo(
  const AID: TGUID;
  const AName, AVersion, AAuthor, ADescription: string;
  ACapabilities: TPluginCapabilities = [];
  const AMinDeepBaseVersion: string = '0.3';
  const ADependencies: TArray<TGUID> = nil): TPluginInfo;

/// <summary>
/// Helper: Convert plugin state to string
/// </summary>
function PluginStateToStr(State: TPluginState): string;

/// <summary>
/// Helper: Compare version strings (returns -1, 0, or 1)
/// </summary>
function CompareVersions(const V1, V2: string): Integer;

/// <summary>
/// Helper: GUID to string without braces
/// </summary>
function GUIDToShortString(const G: TGUID): string;

implementation

{ Helper Functions }

function MakePluginInfo(
  const AID: TGUID;
  const AName, AVersion, AAuthor, ADescription: string;
  ACapabilities: TPluginCapabilities;
  const AMinDeepBaseVersion: string;
  const ADependencies: TArray<TGUID>): TPluginInfo;
begin
  Result.ID := AID;
  Result.Name := AName;
  Result.Version := AVersion;
  Result.Author := AAuthor;
  Result.Description := ADescription;
  Result.URL := '';
  Result.Capabilities := ACapabilities;
  Result.MinDeepBaseVersion := AMinDeepBaseVersion;
  Result.Dependencies := ADependencies;
end;

function PluginStateToStr(State: TPluginState): string;
begin
  case State of
    psUnloaded:  Result := 'Unloaded';
    psLoading:   Result := 'Loading';
    psLoaded:    Result := 'Loaded';
    psActive:    Result := 'Active';
    psError:     Result := 'Error';
    psUnloading: Result := 'Unloading';
  else
    Result := 'Unknown';
  end;
end;

function CompareVersions(const V1, V2: string): Integer;
var
  Parts1, Parts2: TArray<string>;
  I, N1, N2, MaxLen: Integer;
begin
  Parts1 := V1.Split(['.']);
  Parts2 := V2.Split(['.']);
  Result := 0;
  
  if Length(Parts1) > Length(Parts2) then
    MaxLen := Length(Parts1)
  else
    MaxLen := Length(Parts2);
  
  for I := 0 to MaxLen - 1 do
  begin
    if I < Length(Parts1) then
      N1 := StrToIntDef(Parts1[I], 0)
    else
      N1 := 0;
      
    if I < Length(Parts2) then
      N2 := StrToIntDef(Parts2[I], 0)
    else
      N2 := 0;
    
    if N1 < N2 then Exit(-1);
    if N1 > N2 then Exit(1);
  end;
end;

function GUIDToShortString(const G: TGUID): string;
begin
  Result := GUIDToString(G);
  // Remove braces
  if (Length(Result) > 2) and (Result[1] = '{') then
    Result := Copy(Result, 2, Length(Result) - 2);
end;

{ TDeepBasePluginBase }

constructor TDeepBasePluginBase.Create;
begin
  inherited Create;
  FState := psUnloaded;
  FLastError := '';
  FContext := nil;
end;

procedure TDeepBasePluginBase.SetContext(AContext: IDeepBasePluginContext);
begin
  FContext := AContext;
end;

procedure TDeepBasePluginBase.SetError(const ErrorMsg: string);
begin
  FLastError := ErrorMsg;
  FState := psError;
end;

procedure TDeepBasePluginBase.SetState(AState: TPluginState);
begin
  FState := AState;
end;

function TDeepBasePluginBase.GetPluginInfo: TPluginInfo;
begin
  Result := DoGetPluginInfo;
end;

function TDeepBasePluginBase.Initialize: Boolean;
begin
  FState := psLoading;
  FLastError := '';
  
  try
    Result := DoInitialize;
    if Result then
      FState := psActive
    else if FState <> psError then
      FState := psLoaded; // DoInitialize returned False but didn't set error
  except
    on E: Exception do
    begin
      SetError('Initialize failed: ' + E.Message);
      Result := False;
    end;
  end;
end;

function TDeepBasePluginBase.Finalize: Boolean;
begin
  FState := psUnloading;
  
  try
    Result := DoFinalize;
    if Result then
      FState := psUnloaded;
  except
    on E: Exception do
    begin
      SetError('Finalize failed: ' + E.Message);
      Result := False;
    end;
  end;
end;

function TDeepBasePluginBase.DoInitialize: Boolean;
begin
  // Default implementation - override in derived classes
  Result := True;
end;

function TDeepBasePluginBase.DoFinalize: Boolean;
begin
  // Default implementation - override in derived classes
  Result := True;
end;

function TDeepBasePluginBase.GetState: TPluginState;
begin
  Result := FState;
end;

function TDeepBasePluginBase.GetLastError: string;
begin
  Result := FLastError;
end;

end.
