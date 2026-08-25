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
  TShellDefaultLocalizationService =
    DeepBase.VCL.DeepShell.Localization.TShellDefaultLocalizationService;
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

procedure RegisterDefaultShellTexts(ALoc: TShellDefaultLocalizationService;
  const ALocale: string);

implementation

uses
  System.SysUtils;

function ShellCommand(const AId, ACaption: string): TShellCommandBuilder;
begin
  Result := DeepBase.VCL.DeepShell.Commands.ShellCommand(AId, ACaption);
end;

procedure RegisterDefaultShellTexts(ALoc: TShellDefaultLocalizationService;
  const ALocale: string);
begin
  if ALoc = nil then Exit;
  if SameText(ALocale, 'zh-CN') or SameText(ALocale, 'zh-TW') then
  begin
    // [i18n 2026-08-25] 补顶层菜单分类键——RebuildMainMenu 的 Category 走
    // ShellText('shell.cat.*')，缺这些键时中文环境分类恒落英文。
    ALoc.RegisterText(ALocale, 'shell.cat.file',
      {$IFDEF ZH_TW}'檔案'{$ELSE}'文件'{$ENDIF});
    ALoc.RegisterText(ALocale, 'shell.cat.view',
      {$IFDEF ZH_TW}'檢視'{$ELSE}'视图'{$ENDIF});
    ALoc.RegisterText(ALocale, 'shell.cat.log',
      {$IFDEF ZH_TW}'日誌'{$ELSE}'日志'{$ENDIF});
    ALoc.RegisterText(ALocale, 'shell.cat.tools',
      {$IFDEF ZH_TW}'工具'{$ELSE}'工具'{$ENDIF});
    ALoc.RegisterText(ALocale, 'shell.cat.help',
      {$IFDEF ZH_TW}'說明'{$ELSE}'帮助'{$ENDIF});
    ALoc.RegisterText(ALocale, 'shell.status.projectView',
      {$IFDEF ZH_TW}'專案: %s | 檢視: %s'{$ELSE}'项目: %s | 视图: %s'{$ENDIF});
    ALoc.RegisterText(ALocale, 'shell.status.ready',
      {$IFDEF ZH_TW}'就緒'{$ELSE}'就绪'{$ENDIF});
    ALoc.RegisterText(ALocale, 'shell.status.logsCollapsed',
      {$IFDEF ZH_TW}'日誌已摺疊'{$ELSE}'日志已折叠'{$ENDIF});
    ALoc.RegisterText(ALocale, 'shell.status.workspaceCollapsed',
      {$IFDEF ZH_TW}'工作區已摺疊 - 使用 檢視 / 還原工作區。'{$ELSE}'工作区已折叠 - 使用 视图 / 恢复工作区。'{$ENDIF});
    ALoc.RegisterText(ALocale, 'shell.cmd.fileExit',
      {$IFDEF ZH_TW}'結束'{$ELSE}'退出'{$ENDIF});
    ALoc.RegisterText(ALocale, 'shell.cmd.view.toggleTop',
      {$IFDEF ZH_TW}'切換上方窗格'{$ELSE}'切换上方窗格'{$ENDIF});
    ALoc.RegisterText(ALocale, 'shell.cmd.view.toggleMiddle',
      {$IFDEF ZH_TW}'切換中間窗格'{$ELSE}'切换中间窗格'{$ENDIF});
    ALoc.RegisterText(ALocale, 'shell.cmd.view.toggleBottom',
      {$IFDEF ZH_TW}'切換下方窗格'{$ELSE}'切换下方窗格'{$ENDIF});
    ALoc.RegisterText(ALocale, 'shell.cmd.view.structure',
      {$IFDEF ZH_TW}'結構視窗'{$ELSE}'结构窗口'{$ENDIF});
    ALoc.RegisterText(ALocale, 'shell.cmd.view.inspector',
      {$IFDEF ZH_TW}'檢查器視窗'{$ELSE}'检查器窗口'{$ENDIF});
    ALoc.RegisterText(ALocale, 'shell.cmd.view.resetLayout',
      {$IFDEF ZH_TW}'重設佈局'{$ELSE}'重置布局'{$ENDIF});
    ALoc.RegisterText(ALocale, 'shell.cmd.recent.clear',
      {$IFDEF ZH_TW}'清除最近使用'{$ELSE}'清除最近使用'{$ENDIF});
    ALoc.RegisterText(ALocale, 'shell.cmd.log.clear',
      {$IFDEF ZH_TW}'清除日誌'{$ELSE}'清除日志'{$ENDIF});
    ALoc.RegisterText(ALocale, 'shell.cmd.settings.open',
      {$IFDEF ZH_TW}'設定...'{$ELSE}'设置...'{$ENDIF});
    ALoc.RegisterText(ALocale, 'shell.cmd.settings.restoreDefaults',
      {$IFDEF ZH_TW}'恢復預設值'{$ELSE}'恢复默认值'{$ENDIF});
    ALoc.RegisterText(ALocale, 'shell.cmd.help.about',
      {$IFDEF ZH_TW}'關於...'{$ELSE}'关于...'{$ENDIF});
    ALoc.RegisterText(ALocale, 'shell.settings.title',
      {$IFDEF ZH_TW}'設定'{$ELSE}'设置'{$ENDIF});
    ALoc.RegisterText(ALocale, 'shell.btn.ok', 'OK');
    ALoc.RegisterText(ALocale, 'shell.btn.apply',
      {$IFDEF ZH_TW}'套用'{$ELSE}'应用'{$ENDIF});
    ALoc.RegisterText(ALocale, 'shell.btn.cancel',
      {$IFDEF ZH_TW}'取消'{$ELSE}'取消'{$ENDIF});
    ALoc.RegisterText(ALocale, 'shell.btn.restoreDefaults',
      {$IFDEF ZH_TW}'恢復預設值'{$ELSE}'恢复默认值'{$ENDIF});
  end;
end;

end.
