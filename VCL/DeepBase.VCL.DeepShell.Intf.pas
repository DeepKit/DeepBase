{ ============================================================================
  DeepBase.VCL.DeepShell.Intf

  All interfaces consumed and exposed by the DeepShell desktop frame.
  Shell core depends on these contracts only - no concrete WebView2, CEF,
  Db1, doQry, governance or LLM dependency.
  See docs/72.vcl.DeepShell-核心接口与服务契约.md
  ============================================================================ }

unit DeepBase.VCL.DeepShell.Intf;

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.Controls,
  DeepBase.VCL.DeepShell.Types;

type
  // ---------------------------------------------------------------------------
  // Forward declarations (so command manager can reference governance)
  // ---------------------------------------------------------------------------
  IGovernanceService = interface;

  // ---------------------------------------------------------------------------
  // Service registry
  // ---------------------------------------------------------------------------

  IShellServiceRegistry = interface
    ['{2B1E2C04-9C1F-4F0F-9F5C-1C77F9D1A001}']
    procedure RegisterService(const AServiceId: string; const AService: IInterface);
    function TryGetService(const AServiceId: string; out AService: IInterface): Boolean;
    function SupportsCapability(const ACapabilityId: string): Boolean;
    function ServiceIds: TArray<string>;
  end;

  // ---------------------------------------------------------------------------
  // EventBus
  // ---------------------------------------------------------------------------

  TDeepShellEventKind = (
    sekProjectOpened,
    sekProjectClosed,
    sekContextChanged,
    sekObjectSelected,
    sekViewChanged,
    sekLayoutChanged,
    sekLogAdded,
    sekIssueAdded,
    sekTaskStarted,
    sekTaskFinished,
    sekServiceStatusChanged,
    sekCommandExecuted,
    sekCommandRejected
  );

  TDeepShellEvent = record
    Kind: TDeepShellEventKind;
    Context: TShellContext;
    ObjectRef: TShellObjectRef;
    MessageText: string;
    Data: string;
  end;

  TShellEventHandler = reference to procedure(const AEvent: TDeepShellEvent);

  IShellEventBus = interface
    ['{2B1E2C04-9C1F-4F0F-9F5C-1C77F9D1A002}']
    function Subscribe(AKind: TDeepShellEventKind; AHandler: TShellEventHandler): string;
    function SubscribeAll(AHandler: TShellEventHandler): string;
    procedure Unsubscribe(const AToken: string);
    procedure Publish(const AEvent: TDeepShellEvent);
  end;

  // ---------------------------------------------------------------------------
  // Context manager
  // ---------------------------------------------------------------------------

  IShellContextManager = interface
    ['{2B1E2C04-9C1F-4F0F-9F5C-1C77F9D1A003}']
    function Current: TShellContext;
    procedure SetProject(const AProjectId, APath: string);
    procedure SetObject(const ARef: TShellObjectRef);
    procedure SetView(const AViewId, AViewType: string);
    procedure ClearProject;
  end;

  // ---------------------------------------------------------------------------
  // Command manager
  // ---------------------------------------------------------------------------

  IShellCommandManager = interface
    ['{2B1E2C04-9C1F-4F0F-9F5C-1C77F9D1A004}']
    procedure RegisterCommand(const ACommand: TShellCommand);
    procedure UnregisterCommand(const ACommandId: string);
    procedure Execute(const ACommandId: string);
    procedure UpdateCommandState(const ACommandId: string; AEnabled, AVisible: Boolean);
    procedure UpdateCommandChecked(const ACommandId: string; AChecked: Boolean);
    function TryGetCommand(const ACommandId: string; out ACommand: TShellCommand): Boolean;
    function CommandIds: TArray<string>;
    /// <summary>
    /// Wire up an optional governance service. Pass nil to clear.
    /// In MVP the default is a NullGovernanceService that allows everything.
    /// </summary>
    procedure SetGovernance(const AGovernance: IGovernanceService);
  end;

  // ---------------------------------------------------------------------------
  // Status / diagnostics
  // ---------------------------------------------------------------------------

  /// <summary>
  /// Sanitizer hook for status / log entries. Downstream can register a
  /// callback that returns a redacted version of the message before it is
  /// stored or published. Default is no-op.
  /// </summary>
  TShellStatusSanitizer = reference to function(const ASource, AMessage: string): string;

  IShellStatusManager = interface
    ['{2B1E2C04-9C1F-4F0F-9F5C-1C77F9D1A005}']
    procedure Info(const ASource, AMessage: string);
    procedure Warning(const ASource, AMessage: string);
    /// <summary>
    /// Recommended name for error reporting. <c>ShellError</c> is kept as
    /// a backward-compatible alias.
    /// </summary>
    procedure LogError(const ASource, AMessage, ADetail: string);
    procedure ShellError(const ASource, AMessage, ADetail: string);
    procedure Progress(const ATaskId, ASource: string; APercent: Integer; const AMessage: string);
    procedure TaskStart(const ATaskId, ASource, AMessage: string);
    procedure TaskFinish(const ATaskId, AMessage: string);
    procedure Diagnostic(const ASource, AMessage: string);
    function GetEntries: TArray<TShellStatusEntry>;
    procedure ClearEntries;
    /// <summary>
    /// Install a sanitizer that runs before each status entry is stored.
    /// Use to redact secrets (Bearer tokens, API keys, ...) that downstream
    /// code may accidentally pass into Status.Info / Status.Warning.
    /// Pass nil to clear.
    /// </summary>
    procedure SetSanitizer(ASanitizer: TShellStatusSanitizer);
  end;

  // ---------------------------------------------------------------------------
  // State services (Recent / Layout / Settings)
  // ---------------------------------------------------------------------------

  IShellRecentService = interface
    ['{2B1E2C04-9C1F-4F0F-9F5C-1C77F9D1A006}']
    procedure AddRecent(const AItem: TShellRecentItem);
    procedure AddRecentProject(const AProjectId, APath, ADisplayName, ALayoutKey: string);
    function GetRecent(AKind: TShellRecentKind): TArray<TShellRecentItem>;
    function GetRecentProjects: TArray<TShellRecentItem>;
    procedure MarkInvalid(AKind: TShellRecentKind; const AItemKey: string);
    procedure Remove(AKind: TShellRecentKind; const AItemKey: string);
    procedure Clear;
  end;

  IShellLayoutService = interface
    ['{2B1E2C04-9C1F-4F0F-9F5C-1C77F9D1A007}']
    procedure SaveGlobalLayout(const AState: TShellLayoutState);
    function TryLoadGlobalLayout(out AState: TShellLayoutState): Boolean;
    procedure SaveProjectLayout(const AProjectId: string; const AState: TShellLayoutState);
    function TryLoadProjectLayout(const AProjectId: string; out AState: TShellLayoutState): Boolean;
    procedure ResetGlobalLayout;
    procedure ResetProjectLayout(const AProjectId: string);
  end;

  IShellSettingsStore = interface
    ['{2B1E2C04-9C1F-4F0F-9F5C-1C77F9D1A008}']
    function ReadString(const AKey, ADefault: string): string;
    procedure WriteString(const AKey, AValue: string);
    function ReadBool(const AKey: string; ADefault: Boolean): Boolean;
    procedure WriteBool(const AKey: string; AValue: Boolean);
    function ReadInteger(const AKey: string; ADefault: Integer): Integer;
    procedure WriteInteger(const AKey: string; AValue: Integer);
    procedure RemoveKey(const AKey: string);
  end;

  // ---------------------------------------------------------------------------
  // Theme / i18n
  // ---------------------------------------------------------------------------

  TShellThemeChangedHandler = reference to procedure(const AThemeId: string);
  TShellLocaleChangedHandler = reference to procedure(const ALocale: string);

  IShellThemeService = interface
    ['{2B1E2C04-9C1F-4F0F-9F5C-1C77F9D1A009}']
    function CurrentTheme: string;
    procedure ApplyTheme(const AThemeId: string);
    function GetThemes: TArray<string>;
    function OnThemeChanged(AHandler: TShellThemeChangedHandler): string;
    procedure RemoveThemeChanged(const AToken: string);
  end;

  IShellLocalizationService = interface
    ['{2B1E2C04-9C1F-4F0F-9F5C-1C77F9D1A00A}']
    function Text(const AKey, ADefault: string): string;
    function CurrentLocale: string;
    procedure SetLocale(const ALocale: string);
    function GetLocales: TArray<string>;
    function OnLocaleChanged(AHandler: TShellLocaleChangedHandler): string;
    procedure RemoveLocaleChanged(const AToken: string);
  end;

  // ---------------------------------------------------------------------------
  // Settings page provider
  // ---------------------------------------------------------------------------

  ISettingsPageProvider = interface
    ['{2B1E2C04-9C1F-4F0F-9F5C-1C77F9D1A00B}']
    function PageId: string;
    function Caption: string;
    function GroupName: string;
    function CreatePage(AOwner: TComponent): TControl;
    procedure Apply;
    procedure Cancel;
    procedure RestoreDefaults;
  end;

  // ---------------------------------------------------------------------------
  // Providers (structure / main view / inspector)
  // ---------------------------------------------------------------------------

  IShellStructureProvider = interface
    ['{2B1E2C04-9C1F-4F0F-9F5C-1C77F9D1A00C}']
    function ProviderId: string;
    function GetTreeNames: TArray<string>;
    function GetRootNodes(const ATreeName: string): TArray<TShellObjectRef>;
    function HasChildren(const ANode: TShellObjectRef): Boolean;
    function GetChildren(const ANode: TShellObjectRef): TArray<TShellObjectRef>;
    function GetDisplayText(const ANode: TShellObjectRef): string;
  end;

  IShellMainViewProvider = interface
    ['{2B1E2C04-9C1F-4F0F-9F5C-1C77F9D1A00D}']
    function ProviderId: string;
    function CanOpen(const ARef: TShellObjectRef): Boolean;
    function GetViewForObject(const ARef: TShellObjectRef): TShellViewInfo;
    /// <summary>
    /// For svkControl / svkFrame the Shell calls back to materialise a control.
    /// AOwner is the host panel; the returned control is owned by AOwner.
    /// May return nil for non-control view kinds.
    /// </summary>
    function CreateViewControl(AOwner: TComponent;
      const ARef: TShellObjectRef; const AInfo: TShellViewInfo): TControl;
  end;

  IShellInspectorProvider = interface
    ['{2B1E2C04-9C1F-4F0F-9F5C-1C77F9D1A00E}']
    function ProviderId: string;
    function CanInspect(const ARef: TShellObjectRef): Boolean;
    function GetProperties(const ARef: TShellObjectRef): TArray<TShellProperty>;
    function GetRelations(const ARef: TShellObjectRef): TArray<TShellRelation>;
    function GetIssues(const ARef: TShellObjectRef): TArray<TShellIssue>;
  end;

  // ---------------------------------------------------------------------------
  // Optional data services (Db1 / doQry / pool)
  // ---------------------------------------------------------------------------

  IDatabaseService = interface
    ['{2B1E2C04-9C1F-4F0F-9F5C-1C77F9D1A00F}']
    function IsConfigured: Boolean;
    function StatusText: string;
    function TestConnection(out AError: string): Boolean;
  end;

  IQueryExecutor = interface
    ['{2B1E2C04-9C1F-4F0F-9F5C-1C77F9D1A010}']
    function Query(const AName: string; const AParams: string): string;
    function Exec(const AName: string; const AParams: string): Integer;
  end;

  IConnectionPoolService = interface
    ['{2B1E2C04-9C1F-4F0F-9F5C-1C77F9D1A011}']
    function StatusText: string;
    function ActiveCount: Integer;
    function Capacity: Integer;
  end;

  // ---------------------------------------------------------------------------
  // Governance (null implementation in core; real adapter is post-MVP)
  // ---------------------------------------------------------------------------

  IGovernanceService = interface
    ['{2B1E2C04-9C1F-4F0F-9F5C-1C77F9D1A012}']
    function IsEnabled: Boolean;
    function EnterGate(const AGateKey, AContextJson: string;
      out AResult: TShellGateResult): Boolean;
  end;

  // ---------------------------------------------------------------------------
  // Standard service ids and capability ids (string constants)
  // ---------------------------------------------------------------------------

const
  // capabilities
  CAP_SHELL_RECENT      = 'shell.recent';
  CAP_SHELL_LAYOUT      = 'shell.layout';
  CAP_SHELL_THEME       = 'shell.theme';
  CAP_SHELL_I18N        = 'shell.i18n';
  CAP_SHELL_SETTINGS    = 'shell.settings';
  CAP_SHELL_COMMAND     = 'shell.command';
  CAP_SHELL_EVENTBUS    = 'shell.eventbus';
  CAP_SHELL_CONTEXT     = 'shell.context';
  CAP_SHELL_STATUS      = 'shell.status';
  CAP_DB_CONNECTION     = 'db.connection';
  CAP_DB_QUERY          = 'db.query';
  CAP_DB_POOL           = 'db.pool';
  CAP_AI_LLM            = 'ai.llm';
  CAP_GOVERNANCE_GATE   = 'governance.gate';
  CAP_BROWSER_AUTO      = 'browser.automation';

  // built-in command ids
  CMD_FILE_NEW          = 'shell.file.new';
  CMD_FILE_OPEN         = 'shell.file.open';
  CMD_FILE_SAVE         = 'shell.file.save';
  CMD_FILE_EXIT         = 'shell.file.exit';
  CMD_VIEW_TOGGLE_TOP   = 'shell.view.toggleTop';
  CMD_VIEW_TOGGLE_MID   = 'shell.view.toggleMiddle';
  CMD_VIEW_TOGGLE_BOT   = 'shell.view.toggleBottom';
  CMD_VIEW_STRUCTURE    = 'shell.view.structureWindow';
  CMD_VIEW_INSPECTOR    = 'shell.view.inspectorWindow';
  CMD_VIEW_RESET_LAYOUT = 'shell.view.resetLayout';
  CMD_RECENT_OPEN       = 'shell.recent.open';
  CMD_RECENT_CLEAR      = 'shell.recent.clear';
  CMD_THEME_SWITCH      = 'shell.theme.switch';
  CMD_LANGUAGE_SWITCH   = 'shell.language.switch';
  CMD_SETTINGS_OPEN     = 'shell.settings.open';
  CMD_LOG_CLEAR         = 'shell.log.clear';
  CMD_LOG_COPY          = 'shell.log.copy';
  CMD_HELP_ABOUT        = 'shell.help.about';
  CMD_SETTINGS_DEFAULTS = 'shell.settings.restoreDefaults';

  // panel ids
  PANEL_TOP    = 'top';
  PANEL_MIDDLE = 'middle';
  PANEL_BOTTOM = 'bottom';

  // tool window ids
  TOOLWIN_STRUCTURE = 'structure';
  TOOLWIN_INSPECTOR = 'inspector';

implementation

end.
