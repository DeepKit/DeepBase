{ ============================================================================
  DeepBase.VCL.DeepShell

  Facade unit. Re-exports DeepShell types, interfaces, services, the fluent
  ShellCommand builder and TDeepMainForm so a downstream unit only needs to
  use one identifier:

    uses
      DeepBase.VCL.DeepShell;

  Internally this unit only forwards. It does not introduce new logic.
  ============================================================================ }

unit DeepBase.VCL.DeepShell;

interface

uses
  DeepBase.VCL.DeepShell.Types,
  DeepBase.VCL.DeepShell.Intf,
  DeepBase.VCL.DeepShell.Events,
  DeepBase.VCL.DeepShell.Services,
  DeepBase.VCL.DeepShell.Context,
  DeepBase.VCL.DeepShell.Commands,
  DeepBase.VCL.DeepShell.Recent,
  DeepBase.VCL.DeepShell.Layout,
  DeepBase.VCL.DeepShell.Theme,
  DeepBase.VCL.DeepShell.Localization,
  DeepBase.VCL.DeepShell.Settings,
  DeepBase.VCL.DeepShell.Panels,
  DeepBase.VCL.DeepShell.ToolWindow,
  DeepBase.VCL.DeepShell.Governance,
  DeepBase.VCL.DeepShell.MainForm;

type
  // Types
  TShellObjectRef         = DeepBase.VCL.DeepShell.Types.TShellObjectRef;
  TShellContext           = DeepBase.VCL.DeepShell.Types.TShellContext;
  TShellCommand           = DeepBase.VCL.DeepShell.Types.TShellCommand;
  TShellPanelState        = DeepBase.VCL.DeepShell.Types.TShellPanelState;
  TShellToolWindowState   = DeepBase.VCL.DeepShell.Types.TShellToolWindowState;
  TShellLayoutState       = DeepBase.VCL.DeepShell.Types.TShellLayoutState;
  TShellRecentItem        = DeepBase.VCL.DeepShell.Types.TShellRecentItem;
  TShellRecentKind        = DeepBase.VCL.DeepShell.Types.TShellRecentKind;
  TShellViewInfo          = DeepBase.VCL.DeepShell.Types.TShellViewInfo;
  TShellViewKind          = DeepBase.VCL.DeepShell.Types.TShellViewKind;
  TShellProperty          = DeepBase.VCL.DeepShell.Types.TShellProperty;
  TShellRelation          = DeepBase.VCL.DeepShell.Types.TShellRelation;
  TShellIssue             = DeepBase.VCL.DeepShell.Types.TShellIssue;
  TShellIssueSeverity     = DeepBase.VCL.DeepShell.Types.TShellIssueSeverity;
  TShellRiskLevel         = DeepBase.VCL.DeepShell.Types.TShellRiskLevel;
  TShellGateOutcome       = DeepBase.VCL.DeepShell.Types.TShellGateOutcome;
  TShellGateResult        = DeepBase.VCL.DeepShell.Types.TShellGateResult;

  // Interfaces
  IShellServiceRegistry   = DeepBase.VCL.DeepShell.Intf.IShellServiceRegistry;
  IShellEventBus          = DeepBase.VCL.DeepShell.Intf.IShellEventBus;
  IShellContextManager    = DeepBase.VCL.DeepShell.Intf.IShellContextManager;
  IShellCommandManager    = DeepBase.VCL.DeepShell.Intf.IShellCommandManager;
  IShellStatusManager     = DeepBase.VCL.DeepShell.Intf.IShellStatusManager;
  IShellRecentService     = DeepBase.VCL.DeepShell.Intf.IShellRecentService;
  IShellLayoutService     = DeepBase.VCL.DeepShell.Intf.IShellLayoutService;
  IShellSettingsStore     = DeepBase.VCL.DeepShell.Intf.IShellSettingsStore;
  IShellThemeService      = DeepBase.VCL.DeepShell.Intf.IShellThemeService;
  IShellLocalizationService = DeepBase.VCL.DeepShell.Intf.IShellLocalizationService;
  ISettingsPageProvider   = DeepBase.VCL.DeepShell.Intf.ISettingsPageProvider;
  IShellStructureProvider = DeepBase.VCL.DeepShell.Intf.IShellStructureProvider;
  IShellMainViewProvider  = DeepBase.VCL.DeepShell.Intf.IShellMainViewProvider;
  IShellInspectorProvider = DeepBase.VCL.DeepShell.Intf.IShellInspectorProvider;
  IDatabaseService        = DeepBase.VCL.DeepShell.Intf.IDatabaseService;
  IQueryExecutor          = DeepBase.VCL.DeepShell.Intf.IQueryExecutor;
  IConnectionPoolService  = DeepBase.VCL.DeepShell.Intf.IConnectionPoolService;
  IGovernanceService      = DeepBase.VCL.DeepShell.Intf.IGovernanceService;

  // Implementations / forms
  TShellCommandBuilder    = DeepBase.VCL.DeepShell.Commands.TShellCommandBuilder;
  TDeepMainForm           = DeepBase.VCL.DeepShell.MainForm.TDeepMainForm;
  TDeepShellToolWindow    = DeepBase.VCL.DeepShell.ToolWindow.TDeepShellToolWindow;
  TDeepShellSettingsForm  = DeepBase.VCL.DeepShell.Settings.TDeepShellSettingsForm;
  TShellAuditOnlyGovernanceService =
    DeepBase.VCL.DeepShell.Governance.TShellAuditOnlyGovernanceService;
  TShellAllowAllGovernanceService =
    DeepBase.VCL.DeepShell.Governance.TShellAllowAllGovernanceService;

const
  // Capability ids
  CAP_SHELL_RECENT     = DeepBase.VCL.DeepShell.Intf.CAP_SHELL_RECENT;
  CAP_SHELL_LAYOUT     = DeepBase.VCL.DeepShell.Intf.CAP_SHELL_LAYOUT;
  CAP_SHELL_THEME      = DeepBase.VCL.DeepShell.Intf.CAP_SHELL_THEME;
  CAP_SHELL_I18N       = DeepBase.VCL.DeepShell.Intf.CAP_SHELL_I18N;
  CAP_SHELL_SETTINGS   = DeepBase.VCL.DeepShell.Intf.CAP_SHELL_SETTINGS;
  CAP_SHELL_COMMAND    = DeepBase.VCL.DeepShell.Intf.CAP_SHELL_COMMAND;
  CAP_SHELL_EVENTBUS   = DeepBase.VCL.DeepShell.Intf.CAP_SHELL_EVENTBUS;
  CAP_SHELL_CONTEXT    = DeepBase.VCL.DeepShell.Intf.CAP_SHELL_CONTEXT;
  CAP_SHELL_STATUS     = DeepBase.VCL.DeepShell.Intf.CAP_SHELL_STATUS;
  CAP_DB_CONNECTION    = DeepBase.VCL.DeepShell.Intf.CAP_DB_CONNECTION;
  CAP_DB_QUERY         = DeepBase.VCL.DeepShell.Intf.CAP_DB_QUERY;
  CAP_DB_POOL          = DeepBase.VCL.DeepShell.Intf.CAP_DB_POOL;
  CAP_AI_LLM           = DeepBase.VCL.DeepShell.Intf.CAP_AI_LLM;
  CAP_GOVERNANCE_GATE  = DeepBase.VCL.DeepShell.Intf.CAP_GOVERNANCE_GATE;
  CAP_BROWSER_AUTO     = DeepBase.VCL.DeepShell.Intf.CAP_BROWSER_AUTO;

  // Risk levels
  rlReadOnly = DeepBase.VCL.DeepShell.Types.rlReadOnly;
  rlLow      = DeepBase.VCL.DeepShell.Types.rlLow;
  rlMedium   = DeepBase.VCL.DeepShell.Types.rlMedium;
  rlHigh     = DeepBase.VCL.DeepShell.Types.rlHigh;

function ShellCommand(const AId, ACaption: string): TShellCommandBuilder;

implementation

function ShellCommand(const AId, ACaption: string): TShellCommandBuilder;
begin
  Result := DeepBase.VCL.DeepShell.Commands.ShellCommand(AId, ACaption);
end;

end.
