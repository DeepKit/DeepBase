{ ============================================================================
  DeepBase.VCL.DeepShell.MainForm

  TDeepMainForm - reusable VCL desktop main form. Downstream apps inherit
  this class and override RegisterServices / RegisterCommands /
  RegisterProviders. The shell core does not depend on Db1, doQry,
  WebView2, governance or LLM units.

  See docs/70.vcl.DeepShell-总览与AI入口.md
      docs/73.vcl.DeepShell-生命周期与启动顺序.md
  ============================================================================ }

unit DeepBase.VCL.DeepShell.MainForm;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.ComCtrls,
  Vcl.ExtCtrls,
  Vcl.StdCtrls,
  Vcl.Grids,
  Vcl.Menus,
  Vcl.ActnList,
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
  DeepBase.VCL.DeepShell.Governance;

type
  // Internal mediator that lets the EventBus dispatch into the form without
  // queued closures keeping a raw class reference. The form holds the
  // bridge through this interface; on Destroy the form calls Detach which
  // nils the bridge's owner pointer. Queued closures see IsAlive = False
  // and silently no-op.
  IShellMainFormBridge = interface
    ['{2B1E2C04-9C1F-4F0F-9F5C-1C77F9D1A013}']
    procedure DispatchEvent(const AEvent: TDeepShellEvent);
    procedure Detach;
    function IsAlive: Boolean;
  end;

  TDeepMainForm = class(TForm)
  private
    FInstanceId: string;
    FShellInitialised: Boolean;
    FShownOnce: Boolean;

    // Core services (own concrete classes, expose interfaces).
    FBus: IShellEventBus;
    FRegistry: IShellServiceRegistry;
    FCommands: IShellCommandManager;
    FContext: IShellContextManager;
    FRecent: IShellRecentService;
    FLayout: IShellLayoutService;
    FSettings: IShellSettingsStore;
    FTheme: IShellThemeService;
    FLocalization: IShellLocalizationService;
    FStatus: IShellStatusManager;
    FGovernance: IGovernanceService;

    // Settings page providers
    FSettingsPages: TList<ISettingsPageProvider>;

    // Main view providers and dispatch
    FStructureProviders: TList<IShellStructureProvider>;
    FMainViewProviders: TList<IShellMainViewProvider>;
    FInspectorProviders: TList<IShellInspectorProvider>;
    FCurrentMainView: TControl;

    // UI structure
    FCommandBar: TPanel;
    FMainMenu: TMainMenu;
    FCommandMenuItems: TDictionary<string, TMenuItem>;
    FTopPanel: TPanel;
    FTopHost: TPanel;
    FTopSummary: TLabel;
    FTopSplitter: TSplitter;
    FBottomPanel: TPanel;
    FBottomHost: TPanel;
    FBottomSummary: TLabel;
    FBottomSplitter: TSplitter;
    FMiddlePanel: TPanel;
    FMiddleHost: TPanel;
    FMiddleSummary: TLabel;
    FStatusBar: TStatusBar;
    FBottomLog: TMemo;

    // Panel controllers
    FTopController: TShellAreaController;
    FMiddleController: TShellAreaController;
    FBottomController: TShellAreaController;

    // Tool windows
    FStructureWindow: TDeepShellToolWindow;
    FStructureTree: TTreeView;
    FInspectorWindow: TDeepShellToolWindow;
    FInspectorGrid: TStringGrid;

    // Misc
    FStatusToken: string;
    FLastLogEntryCount: Integer;
    FActiveProjectIdForLayout: string;
    FBridge: IShellMainFormBridge;
    procedure HookEventBus;
    procedure UnhookEventBus;
    procedure InstallBuiltInCommands;
    procedure CaptureLayoutState(out AState: TShellLayoutState);
    procedure ApplyLayoutState(const AState: TShellLayoutState);
    procedure AppendLogEntry(const AEntry: TShellStatusEntry);
    procedure ResolveServicesFromRegistry;
    procedure RebuildMainMenu;
    procedure RefreshInspector(const ARef: TShellObjectRef);
    procedure DoCommandMenuClick(Sender: TObject);
    procedure DoStructureChange(Sender: TObject; Node: TTreeNode);
    procedure DoStructureExpanding(Sender: TObject; Node: TTreeNode; var AllowExpansion: Boolean);
    procedure DoStructureDeletion(Sender: TObject; Node: TTreeNode);
    procedure ExpandStructureNode(ANode: TTreeNode);
    function StructureNodeRef(ANode: TTreeNode): TShellObjectRef;
    function StructureNodeProvider(ANode: TTreeNode): IShellStructureProvider;
  protected
    // Lifecycle - override in descendants.
    procedure InitializeShell; virtual;
    procedure RegisterServices; virtual;
    procedure RegisterCommands; virtual;
    procedure RegisterProviders; virtual;
    procedure BuildShellUI; virtual;
    procedure LoadShellState; virtual;
    procedure AfterShellShown; virtual;
    procedure BeforeShellClose; virtual;
    procedure SaveShellState; virtual;
    procedure ShutdownShell; virtual;

    // VCL hooks
    procedure DoShow; override;
    procedure DoClose(var Action: TCloseAction); override;

    // Internal: methods are called from TShellMainFormBridge in the same
    // unit so they live under protected, not private.
    procedure UpdateStatusBarFromContext(const AContext: TShellContext);
    procedure RefreshBottomLog;
    procedure HandleCommandRejected(const AEvent: TDeepShellEvent); virtual;
    procedure HandleCommandStateChanged(const AEvent: TDeepShellEvent); virtual;

    // Helpers exposed to descendants
    procedure RegisterStructureProvider(const AProvider: IShellStructureProvider);
    procedure RegisterMainViewProvider(const AProvider: IShellMainViewProvider);
    procedure RegisterInspectorProvider(const AProvider: IShellInspectorProvider);
    procedure RegisterSettingsPageProvider(const AProvider: ISettingsPageProvider);
    procedure SetGovernance(const AGovernance: IGovernanceService);

    /// <summary>
    /// Open a project: save the previously active project layout (if any),
    /// switch context, and apply the new project's saved layout (if any).
    /// Use this instead of calling Context.SetProject directly when you want
    /// per-project layout isolation.
    /// </summary>
    procedure OpenProject(const AProjectId, APath: string); virtual;
    /// <summary>
    /// Close the current project: save its layout and clear context.
    /// </summary>
    procedure CloseProject; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    /// <summary>
    /// Shell setup runs in AfterConstruction (not Create), so descendants
    /// see fully-initialised fields by the time RegisterServices etc. fire.
    /// Descendants may still override these virtuals; just do not rely on
    /// derived fields existing inside the inherited constructor body.
    /// </summary>
    procedure AfterConstruction; override;

    // Service accessors
    property Services: IShellServiceRegistry read FRegistry;
    property Commands: IShellCommandManager read FCommands;
    property EventBus: IShellEventBus read FBus;
    property Context: IShellContextManager read FContext;
    property Recent: IShellRecentService read FRecent;
    property Layout: IShellLayoutService read FLayout;
    property SettingsStore: IShellSettingsStore read FSettings;
    property Theme: IShellThemeService read FTheme;
    property Localization: IShellLocalizationService read FLocalization;
    property Status: IShellStatusManager read FStatus;

    /// <summary>
    /// Resolve a shell-internal text key through the localization service if
    /// available; falls back to ADefault. Built-in command captions and the
    /// settings dialog use this so downstream can override via
    /// <c>FLocalization.RegisterText('shell.cmd.fileExit', '退出')</c>.
    /// Captions are resolved at registration time; locale changes require an
    /// app restart for built-in captions to refresh (downstream-registered
    /// commands can re-register themselves on locale change).
    /// </summary>
    function ShellText(const AKey, ADefault: string): string;

    // Hosts for downstream views
    property TopAreaHost: TPanel read FTopHost;
    property MiddleHost: TPanel read FMiddleHost;
    property BottomAreaHost: TPanel read FBottomHost;
    property StructureWindow: TDeepShellToolWindow read FStructureWindow;
    property InspectorWindow: TDeepShellToolWindow read FInspectorWindow;

    procedure RebuildStructureTree;

    // Main view dispatch
    procedure OpenView(const ARef: TShellObjectRef);
    procedure ClearMainView;

    // Settings dialog
    procedure OpenSettingsDialog;

    property InstanceId: string read FInstanceId;
  end;

implementation

uses
  Winapi.Windows,
  System.Types,
  System.TypInfo,
  System.JSON,
  Vcl.Dialogs,
  Vcl.Graphics;

type
  PShellObjectRef = ^TShellObjectRef;

  TShellMainFormBridge = class(TInterfacedObject, IShellMainFormBridge)
  private
    FOwner: TDeepMainForm;
  public
    constructor Create(AOwner: TDeepMainForm);
    procedure DispatchEvent(const AEvent: TDeepShellEvent);
    procedure Detach;
    function IsAlive: Boolean;
  end;

constructor TShellMainFormBridge.Create(AOwner: TDeepMainForm);
begin
  inherited Create;
  FOwner := AOwner;
end;

procedure TShellMainFormBridge.Detach;
begin
  FOwner := nil;
end;

function TShellMainFormBridge.IsAlive: Boolean;
begin
  Result := FOwner <> nil;
end;

procedure TShellMainFormBridge.DispatchEvent(const AEvent: TDeepShellEvent);
begin
  if FOwner = nil then
    Exit;
  case AEvent.Kind of
    sekContextChanged, sekProjectOpened, sekProjectClosed:
      FOwner.UpdateStatusBarFromContext(AEvent.Context);
    sekLogAdded, sekTaskStarted, sekTaskProgress, sekTaskFinished:
      FOwner.RefreshBottomLog;
    sekObjectSelected:
      FOwner.RefreshInspector(AEvent.ObjectRef);
    sekCommandRejected:
      FOwner.HandleCommandRejected(AEvent);
    sekCommandStateChanged:
      FOwner.HandleCommandStateChanged(AEvent);
  end;
end;

// ---------------------------------------------------------------------------
// Construction / lifecycle
// ---------------------------------------------------------------------------

constructor TDeepMainForm.Create(AOwner: TComponent);
var
  LGuid: TGUID;
begin
  // DFM streaming: if a descendant ships a .dfm resource matching its
  // class name, route through TForm.Create which calls
  // InitInheritedComponent and streams components. If there is no DFM
  // resource for the actual class (our base, or a code-only descendant),
  // fall back to CreateNew to avoid "Resource <ClassName> not found".
  if FindResource(HInstance, PChar(ClassName), RT_RCDATA) <> 0 then
    inherited Create(AOwner)
  else
    inherited CreateNew(AOwner);

  CreateGUID(LGuid);
  FInstanceId := GUIDToString(LGuid);

  FSettingsPages := TList<ISettingsPageProvider>.Create;
  FStructureProviders := TList<IShellStructureProvider>.Create;
  FMainViewProviders := TList<IShellMainViewProvider>.Create;
  FInspectorProviders := TList<IShellInspectorProvider>.Create;
  FCommandMenuItems := TDictionary<string, TMenuItem>.Create;

  Caption := 'DeepShell';
  Width := 1280;
  Height := 800;
  Position := poScreenCenter;

  // Default core services (downstream may replace via RegisterServices).
  FBus := TShellEventBus.Create;
  FRegistry := TShellServiceRegistry.Create;
  FRecent := TShellInMemoryRecentService.Create;
  FSettings := TShellInMemorySettingsStore.Create;
  FLayout := TShellInMemoryLayoutService.Create;
  FTheme := TShellDefaultThemeService.Create;
  FLocalization := TShellDefaultLocalizationService.Create;
  FStatus := TShellStatusManager.Create(FBus);
  FContext := TShellContextManager.Create(FBus);
  FCommands := TShellCommandManager.Create(FBus,
    function: TShellContext
    begin
      if FContext <> nil then
        Result := FContext.Current
      else
        Result := TShellContext.Empty;
    end);

  // Default governance: audit-only. Allows everything but records L2/L3
  // commands through the status manager so audit trail is non-empty until
  // a real OCGS adapter is wired up. Downstream can SetGovernance(nil) or
  // replace with a stricter service.
  SetGovernance(TShellAuditOnlyGovernanceService.Create(FStatus));

  // Mediator that dispatches EventBus callbacks back into the form
  // without the queued closure ever holding a raw class reference.
  FBridge := TShellMainFormBridge.Create(Self);

  // NOTE: virtual methods (RegisterServices / RegisterCommands /
  // RegisterProviders / BuildShellUI / InitializeShell) deliberately do
  // NOT run here - they fire in AfterConstruction when descendant fields
  // are fully initialised.
end;

procedure TDeepMainForm.AfterConstruction;
begin
  inherited AfterConstruction;
  if FShellInitialised then
    Exit;

  InitializeShell;
  RegisterServices;
  ResolveServicesFromRegistry; // pick up any descendant-replaced services
  RegisterCommands;
  RegisterProviders;
  BuildShellUI;
  HookEventBus;
  RebuildMainMenu;
  RebuildStructureTree;

  FShellInitialised := True;
end;

procedure TDeepMainForm.ResolveServicesFromRegistry;
var
  LSvc: IInterface;
  LRecent: IShellRecentService;
  LLayout: IShellLayoutService;
  LSettings: IShellSettingsStore;
  LTheme: IShellThemeService;
  LLocale: IShellLocalizationService;
begin
  if FRegistry = nil then
    Exit;
  if FRegistry.TryGetService(CAP_SHELL_RECENT, LSvc)
     and Supports(LSvc, IShellRecentService, LRecent) then
    FRecent := LRecent;
  if FRegistry.TryGetService(CAP_SHELL_LAYOUT, LSvc)
     and Supports(LSvc, IShellLayoutService, LLayout) then
    FLayout := LLayout;
  if FRegistry.TryGetService(CAP_SHELL_SETTINGS, LSvc)
     and Supports(LSvc, IShellSettingsStore, LSettings) then
    FSettings := LSettings;
  if FRegistry.TryGetService(CAP_SHELL_THEME, LSvc)
     and Supports(LSvc, IShellThemeService, LTheme) then
    FTheme := LTheme;
  if FRegistry.TryGetService(CAP_SHELL_I18N, LSvc)
     and Supports(LSvc, IShellLocalizationService, LLocale) then
    FLocalization := LLocale;
  // Bus / Context / Commands / Status are constructor-owned and do not
  // get rebound from the registry: they are part of the shell's identity.
end;

destructor TDeepMainForm.Destroy;
begin
  if FShellInitialised then
  begin
    try
      BeforeShellClose;
      SaveShellState;
      ShutdownShell;
    except
      // Closing must not be blocked by save/shutdown errors.
    end;
    FShellInitialised := False;
  end;
  // EventBus must always be unhooked, regardless of close path.
  UnhookEventBus;
  // Tell the bridge it must not call back into us anymore. Any TThread.Queue
  // closures still in flight will see IsAlive = False and no-op.
  if FBridge <> nil then
  begin
    FBridge.Detach;
    FBridge := nil;
  end;

  // Free PShellObjectRef payloads on every structure tree node before VCL
  // tears down the tree. OnDeletion would normally do this but the order
  // of TForm.Destroy vs nested control destruction is not guaranteed.
  if FStructureTree <> nil then
  begin
    var I: Integer;
    var LNode: TTreeNode;
    for I := 0 to FStructureTree.Items.Count - 1 do
    begin
      LNode := FStructureTree.Items[I];
      if (LNode <> nil) and (LNode.Data <> nil) then
      begin
        Dispose(PShellObjectRef(LNode.Data));
        LNode.Data := nil;
      end;
    end;
  end;

  FreeAndNil(FTopController);
  FreeAndNil(FMiddleController);
  FreeAndNil(FBottomController);
  FreeAndNil(FInspectorProviders);
  FreeAndNil(FMainViewProviders);
  FreeAndNil(FStructureProviders);
  FreeAndNil(FSettingsPages);
  FreeAndNil(FCommandMenuItems);

  FCommands := nil;
  FContext := nil;
  FStatus := nil;
  FLocalization := nil;
  FTheme := nil;
  FLayout := nil;
  FSettings := nil;
  FRecent := nil;
  FRegistry := nil;
  FBus := nil;
  FGovernance := nil;

  inherited;
end;

procedure TDeepMainForm.DoShow;
begin
  inherited DoShow;
  if FShownOnce then
    Exit;
  FShownOnce := True;
  LoadShellState;
  AfterShellShown;
end;

procedure TDeepMainForm.DoClose(var Action: TCloseAction);
begin
  // Save state before destroy is called by VCL.
  if FShellInitialised then
  begin
    try
      BeforeShellClose;
      SaveShellState;
      ShutdownShell;
    except
      // Closing must not be blocked by save errors; let the form destroy.
    end;
    FShellInitialised := False;
  end;
  Action := caFree;
  inherited DoClose(Action);
end;

// ---------------------------------------------------------------------------
// Default lifecycle implementations
// ---------------------------------------------------------------------------

procedure TDeepMainForm.InitializeShell;
begin
  // Default no-op. Descendants may pre-load configuration.
end;

procedure TDeepMainForm.RegisterServices;
begin
  // Register the built-in services in the registry so descendants can resolve
  // them via Services.TryGetService(CAP_SHELL_*).
  FRegistry.RegisterService(CAP_SHELL_RECENT, FRecent);
  FRegistry.RegisterService(CAP_SHELL_LAYOUT, FLayout);
  FRegistry.RegisterService(CAP_SHELL_THEME, FTheme);
  FRegistry.RegisterService(CAP_SHELL_I18N, FLocalization);
  FRegistry.RegisterService(CAP_SHELL_SETTINGS, FSettings);
  FRegistry.RegisterService(CAP_SHELL_COMMAND, FCommands);
  FRegistry.RegisterService(CAP_SHELL_EVENTBUS, FBus);
  FRegistry.RegisterService(CAP_SHELL_CONTEXT, FContext);
  FRegistry.RegisterService(CAP_SHELL_STATUS, FStatus);
end;

procedure TDeepMainForm.RegisterCommands;
begin
  InstallBuiltInCommands;
end;

procedure TDeepMainForm.RegisterProviders;
begin
  // Default no-op. Descendants register structure / main view / inspector.
end;

procedure TDeepMainForm.BuildShellUI;
begin
  // Main menu - dynamically populated from registered commands.
  FMainMenu := TMainMenu.Create(Self);
  Self.Menu := FMainMenu;

  // Command bar - reserved for downstream toolbar / quick actions. The
  // shell does NOT auto-build a toolbar (commands are surfaced through the
  // main menu instead); descendants can drop a TToolBar onto FCommandBar.
  FCommandBar := TPanel.Create(Self);
  FCommandBar.Parent := Self;
  FCommandBar.Align := alTop;
  FCommandBar.Height := 0;  // hidden until a descendant gives it content
  FCommandBar.BevelOuter := bvNone;

  // Status bar
  FStatusBar := TStatusBar.Create(Self);
  FStatusBar.Parent := Self;
  FStatusBar.SimplePanel := True;
  FStatusBar.SimpleText := 'Ready';

  // Top area
  FTopPanel := TPanel.Create(Self);
  FTopPanel.Parent := Self;
  FTopPanel.Align := alTop;
  FTopPanel.Height := DEFAULT_TOP_HEIGHT;
  FTopPanel.BevelOuter := bvLowered;

  FTopSummary := TLabel.Create(Self);
  FTopSummary.Parent := FTopPanel;
  FTopSummary.Caption := 'Ready';
  FTopSummary.Layout := tlCenter;
  FTopSummary.Visible := False;

  FTopHost := TPanel.Create(Self);
  FTopHost.Parent := FTopPanel;
  FTopHost.Align := alClient;
  FTopHost.BevelOuter := bvNone;

  FTopSplitter := TSplitter.Create(Self);
  FTopSplitter.Parent := Self;
  FTopSplitter.Align := alTop;
  FTopSplitter.Height := 4;
  FTopSplitter.MinSize := MIN_TOP_HEIGHT_COLLAPSED;

  // Bottom area
  FBottomPanel := TPanel.Create(Self);
  FBottomPanel.Parent := Self;
  FBottomPanel.Align := alBottom;
  FBottomPanel.Height := DEFAULT_BOTTOM_HEIGHT;
  FBottomPanel.BevelOuter := bvLowered;

  FBottomSummary := TLabel.Create(Self);
  FBottomSummary.Parent := FBottomPanel;
  FBottomSummary.Caption := 'Logs collapsed';
  FBottomSummary.Layout := tlCenter;
  FBottomSummary.Visible := False;

  FBottomHost := TPanel.Create(Self);
  FBottomHost.Parent := FBottomPanel;
  FBottomHost.Align := alClient;
  FBottomHost.BevelOuter := bvNone;

  FBottomLog := TMemo.Create(Self);
  FBottomLog.Parent := FBottomHost;
  FBottomLog.Align := alClient;
  FBottomLog.ReadOnly := True;
  FBottomLog.ScrollBars := ssVertical;
  FBottomLog.WordWrap := True;
  FBottomLog.Font.Name := 'Consolas';
  FBottomLog.Font.Size := 9;

  FBottomSplitter := TSplitter.Create(Self);
  FBottomSplitter.Parent := Self;
  FBottomSplitter.Align := alBottom;
  FBottomSplitter.Height := 4;
  FBottomSplitter.MinSize := MIN_BOTTOM_HEIGHT_COLLAPSED;

  // Middle area (client)
  FMiddlePanel := TPanel.Create(Self);
  FMiddlePanel.Parent := Self;
  FMiddlePanel.Align := alClient;
  FMiddlePanel.BevelOuter := bvNone;

  FMiddleHost := TPanel.Create(Self);
  FMiddleHost.Parent := FMiddlePanel;
  FMiddleHost.Align := alClient;
  FMiddleHost.BevelOuter := bvNone;

  FMiddleSummary := TLabel.Create(Self);
  FMiddleSummary.Parent := FMiddlePanel;
  FMiddleSummary.Caption := 'Workspace collapsed - use View / Restore Workspace.';
  FMiddleSummary.Layout := tlCenter;
  FMiddleSummary.Visible := False;

  // Controllers
  FTopController := TShellAreaController.Create(FTopPanel, FTopSplitter,
    FTopHost, FTopSummary, PANEL_TOP);
  FMiddleController := TShellAreaController.Create(FMiddlePanel, nil,
    FMiddleHost, FMiddleSummary, PANEL_MIDDLE);
  FBottomController := TShellAreaController.Create(FBottomPanel, FBottomSplitter,
    FBottomHost, FBottomSummary, PANEL_BOTTOM);
  // Default: bottom collapsed at start.
  FBottomController.SetCollapsed(True);

  // Tool windows
  FStructureWindow := TDeepShellToolWindow.CreateForShell(Self,
    TOOLWIN_STRUCTURE, ShellText('shell.toolwin.structure', 'Structure'));
  FStructureWindow.Hide;

  FStructureTree := TTreeView.Create(FStructureWindow);
  FStructureTree.Parent := FStructureWindow.Upper;
  FStructureTree.Align := alClient;
  FStructureTree.ReadOnly := True;
  FStructureTree.HideSelection := False;
  FStructureTree.OnChange := DoStructureChange;
  FStructureTree.OnExpanding := DoStructureExpanding;
  // Free PShellObjectRef payloads when nodes go away (during clear/rebuild
  // and when the form is destroyed).
  FStructureTree.OnDeletion := DoStructureDeletion;

  FInspectorWindow := TDeepShellToolWindow.CreateForShell(Self,
    TOOLWIN_INSPECTOR, ShellText('shell.toolwin.inspector', 'Inspector'));
  FInspectorWindow.Hide;

  FInspectorGrid := TStringGrid.Create(FInspectorWindow);
  FInspectorGrid.Parent := FInspectorWindow.Upper;
  FInspectorGrid.Align := alClient;
  FInspectorGrid.ColCount := 2;
  // VCL grid invariant: FixedRows must be strictly less than RowCount.
  // Set RowCount before FixedRows so the assignment is valid.
  FInspectorGrid.RowCount := 2;
  FInspectorGrid.FixedRows := 1;
  FInspectorGrid.Cells[0, 0] := ShellText('shell.inspector.col.name', 'Name');
  FInspectorGrid.Cells[1, 0] := ShellText('shell.inspector.col.value', 'Value');
  FInspectorGrid.Options := FInspectorGrid.Options + [goRowSelect, goColSizing];
  FInspectorGrid.DefaultDrawing := True;
end;

procedure TDeepMainForm.LoadShellState;
var
  LGlobal: TShellLayoutState;
begin
  if FLayout.TryLoadGlobalLayout(LGlobal) then
    ApplyLayoutState(LGlobal);
end;

procedure TDeepMainForm.AfterShellShown;
begin
  // Default: position tool windows docked to main form edges if they have
  // no saved layout (Left=0, Top=0 means never positioned).
  if (FStructureWindow <> nil) and (FStructureWindow.Left = 0) and (FStructureWindow.Top = 0) then
  begin
    FStructureWindow.Left := Self.Left - FStructureWindow.Width - 4;
    FStructureWindow.Top := Self.Top;
    FStructureWindow.Height := Self.Height;
  end;
  if (FInspectorWindow <> nil) and (FInspectorWindow.Left = 0) and (FInspectorWindow.Top = 0) then
  begin
    FInspectorWindow.Left := Self.Left + Self.Width + 4;
    FInspectorWindow.Top := Self.Top;
    FInspectorWindow.Height := Self.Height;
  end;
end;

procedure TDeepMainForm.BeforeShellClose;
begin
  // Default no-op.
end;

procedure TDeepMainForm.CaptureLayoutState(out AState: TShellLayoutState);
var
  LPlacement: TWindowPlacement;
  LRect: TRect;
  LUsePlacement: Boolean;
begin
  AState := TShellLayoutState.Empty;
  AState.WriterInstanceId := FInstanceId;

  // wsMinimized: Left/Top are off-screen sentinel values.
  // wsMaximized: Left/Top/Width/Height match the maximized rect, not what
  // the user wants restored on next launch.
  // In both cases use GetWindowPlacement.rcNormalPosition so the next
  // launch can restore a sane bounding box independent of WindowState.
  LUsePlacement := WindowState in [wsMinimized, wsMaximized];
  AState.Maximized := WindowState = wsMaximized;

  if LUsePlacement and HandleAllocated then
  begin
    FillChar(LPlacement, SizeOf(LPlacement), 0);
    LPlacement.length := SizeOf(LPlacement);
    if GetWindowPlacement(Handle, LPlacement) then
    begin
      LRect := LPlacement.rcNormalPosition;
      AState.MainLeft := LRect.Left;
      AState.MainTop := LRect.Top;
      AState.MainWidth := LRect.Right - LRect.Left;
      AState.MainHeight := LRect.Bottom - LRect.Top;
    end
    else
    begin
      AState.MainLeft := Left;
      AState.MainTop := Top;
      AState.MainWidth := Width;
      AState.MainHeight := Height;
    end;
  end
  else
  begin
    AState.MainLeft := Left;
    AState.MainTop := Top;
    AState.MainWidth := Width;
    AState.MainHeight := Height;
  end;

  if FTopController <> nil then AState.TopPanel := FTopController.State;
  if FMiddleController <> nil then AState.MiddlePanel := FMiddleController.State;
  if FBottomController <> nil then AState.BottomPanel := FBottomController.State;
  if FStructureWindow <> nil then AState.LeftToolWindow := FStructureWindow.State;
  if FInspectorWindow <> nil then AState.RightToolWindow := FInspectorWindow.State;
end;

procedure TDeepMainForm.ApplyLayoutState(const AState: TShellLayoutState);
var
  LMonitor: TMonitor;
  LWork: TRect;
  LLeft, LTop, LWidth, LHeight: Integer;
begin
  if (AState.MainWidth > 0) and (AState.MainHeight > 0) then
  begin
    LLeft := AState.MainLeft;
    LTop := AState.MainTop;
    LWidth := AState.MainWidth;
    LHeight := AState.MainHeight;

    // Constrain to a real, currently-attached monitor's work area so the
    // window cannot land off-screen if the saved layout came from a
    // monitor that is no longer connected.
    LMonitor := Screen.MonitorFromPoint(Point(LLeft + LWidth div 2,
                                              LTop + LHeight div 2));
    if LMonitor = nil then
      LMonitor := Screen.PrimaryMonitor;
    if LMonitor <> nil then
    begin
      LWork := LMonitor.WorkareaRect;
      if LWidth > LWork.Right - LWork.Left then LWidth := LWork.Right - LWork.Left;
      if LHeight > LWork.Bottom - LWork.Top then LHeight := LWork.Bottom - LWork.Top;
      if LLeft + LWidth > LWork.Right then LLeft := LWork.Right - LWidth;
      if LTop + LHeight > LWork.Bottom then LTop := LWork.Bottom - LHeight;
      if LLeft < LWork.Left then LLeft := LWork.Left;
      if LTop < LWork.Top then LTop := LWork.Top;
    end;

    Left := LLeft;
    Top := LTop;
    Width := LWidth;
    Height := LHeight;
  end;
  if AState.Maximized then
    WindowState := wsMaximized;

  if FTopController <> nil then FTopController.ApplyState(AState.TopPanel);
  if FMiddleController <> nil then FMiddleController.ApplyState(AState.MiddlePanel);
  if FBottomController <> nil then FBottomController.ApplyState(AState.BottomPanel);

  if FStructureWindow <> nil then
  begin
    FStructureWindow.SetState(AState.LeftToolWindow);
    FStructureWindow.ConstrainToWorkAreaOf(Self);
  end;
  if FInspectorWindow <> nil then
  begin
    FInspectorWindow.SetState(AState.RightToolWindow);
    FInspectorWindow.ConstrainToWorkAreaOf(Self);
  end;
end;

procedure TDeepMainForm.SaveShellState;
var
  LState: TShellLayoutState;
begin
  if FLayout = nil then
    Exit;

  CaptureLayoutState(LState);
  LState.LayoutKey := 'main';
  FLayout.SaveGlobalLayout(LState);

  // Per-project layout: write under the project id we are currently bound
  // to so multi-project workflows can each get their own layout.
  if FActiveProjectIdForLayout <> '' then
  begin
    LState.LayoutKey := 'project:' + FActiveProjectIdForLayout;
    FLayout.SaveProjectLayout(FActiveProjectIdForLayout, LState);
  end;
end;

procedure TDeepMainForm.OpenProject(const AProjectId, APath: string);
var
  LState: TShellLayoutState;
begin
  if FContext = nil then
    Exit;

  // Persist the previously active project's layout before switching.
  if (FActiveProjectIdForLayout <> '')
     and (not SameText(FActiveProjectIdForLayout, AProjectId)) then
  begin
    if FLayout <> nil then
    begin
      CaptureLayoutState(LState);
      LState.LayoutKey := 'project:' + FActiveProjectIdForLayout;
      FLayout.SaveProjectLayout(FActiveProjectIdForLayout, LState);
    end;
  end;

  FActiveProjectIdForLayout := AProjectId;
  FContext.SetProject(AProjectId, APath);

  if FRecent <> nil then
    FRecent.AddRecentProject(AProjectId, APath, AProjectId,
      'project:' + AProjectId);

  // Apply the new project's saved layout if present.
  if (FLayout <> nil) and (AProjectId <> '') then
    if FLayout.TryLoadProjectLayout(AProjectId, LState) then
      ApplyLayoutState(LState);

  // Refresh structure tree so the freshly-opened project is visible.
  RebuildStructureTree;
end;

procedure TDeepMainForm.CloseProject;
var
  LState: TShellLayoutState;
begin
  if (FActiveProjectIdForLayout <> '') and (FLayout <> nil) then
  begin
    CaptureLayoutState(LState);
    LState.LayoutKey := 'project:' + FActiveProjectIdForLayout;
    FLayout.SaveProjectLayout(FActiveProjectIdForLayout, LState);
  end;
  FActiveProjectIdForLayout := '';
  if FContext <> nil then
    FContext.ClearProject;
end;

procedure TDeepMainForm.ShutdownShell;
begin
  // Default no-op. Descendants may cancel async tasks here.
end;

// ---------------------------------------------------------------------------
// EventBus wiring
// ---------------------------------------------------------------------------

procedure TDeepMainForm.HookEventBus;
var
  LBridge: IShellMainFormBridge;
begin
  if FBus = nil then
    Exit;
  // Capture the bridge as a local interface var so the closure does NOT
  // capture Self. The bridge keeps itself alive via the closure refcount;
  // when Destroy calls Detach the bridge silently no-ops.
  LBridge := FBridge;
  FStatusToken := FBus.SubscribeAll(
    procedure(const AEvent: TDeepShellEvent)
    begin
      if (LBridge <> nil) and LBridge.IsAlive then
        LBridge.DispatchEvent(AEvent);
    end);
end;

procedure TDeepMainForm.UnhookEventBus;
begin
  if (FBus <> nil) and (FStatusToken <> '') then
  begin
    FBus.Unsubscribe(FStatusToken);
    FStatusToken := '';
  end;
end;

procedure TDeepMainForm.UpdateStatusBarFromContext(const AContext: TShellContext);
var
  LText: string;
begin
  if FStatusBar = nil then
    Exit;
  LText := if AContext.ProjectId <> ''
    then Format('Project: %s | View: %s', [AContext.ProjectId, AContext.ViewId])
    else 'Ready';
  FStatusBar.SimpleText := LText;
  if FTopController <> nil then
    FTopController.SetSummary(LText);
end;

procedure TDeepMainForm.AppendLogEntry(const AEntry: TShellStatusEntry);
begin
  if FBottomLog = nil then
    Exit;
  FBottomLog.Lines.Add(Format('[%s] %s: %s',
    [FormatDateTime('hh:nn:ss', AEntry.Timestamp),
     AEntry.Source, AEntry.MessageText]));
end;

procedure TDeepMainForm.RefreshBottomLog;
var
  LEntries: TArray<TShellStatusEntry>;
  I: Integer;
begin
  if (FBottomLog = nil) or (FStatus = nil) then
    Exit;
  LEntries := FStatus.GetEntries;

  // If StatusManager trimmed older entries (count went down), rebuild.
  if Length(LEntries) < FLastLogEntryCount then
  begin
    FBottomLog.Lines.BeginUpdate;
    try
      FBottomLog.Lines.Clear;
      for I := 0 to High(LEntries) do
        AppendLogEntry(LEntries[I]);
    finally
      FBottomLog.Lines.EndUpdate;
    end;
    FLastLogEntryCount := Length(LEntries);
    Exit;
  end;

  // Normal path: append only newly added entries; preserves user scroll
  // position and selection.
  for I := FLastLogEntryCount to High(LEntries) do
    AppendLogEntry(LEntries[I]);
  FLastLogEntryCount := Length(LEntries);
end;

procedure TDeepMainForm.HandleCommandRejected(const AEvent: TDeepShellEvent);
var
  LCommandId, LMessage: string;
begin
  // Default rejection feedback. Status bar gets a short notice for every
  // rejection; bottom log + the error tab on bottom panel get the detail.
  // Doc 75 §9 asks for stronger feedback at L2/L3 - downstream may override
  // HandleCommandRejected to pop a modal dialog for high-risk commands.
  LCommandId := AEvent.MessageText;
  LMessage := AEvent.Data;
  if FStatus <> nil then
  begin
    if LMessage = '' then
      LMessage := 'Command rejected';
    FStatus.Warning('shell.governance',
      Format('%s: %s', [LCommandId, LMessage]));
  end;
  if FStatusBar <> nil then
    FStatusBar.SimpleText := Format('Command "%s" was not allowed.', [LCommandId]);
end;

procedure TDeepMainForm.HandleCommandStateChanged(const AEvent: TDeepShellEvent);
var
  LMenuItem: TMenuItem;
  LCmd: TShellCommand;
begin
  // Incremental menu refresh: update only the affected menu item
  if FCommandMenuItems = nil then
    Exit;
  if not FCommandMenuItems.TryGetValue(AEvent.Data, LMenuItem) then
    Exit;
  if (FCommands <> nil) and FCommands.TryGetCommand(AEvent.Data, LCmd) then
  begin
    LMenuItem.Enabled := LCmd.Enabled;
    LMenuItem.Visible := LCmd.Visible;
  end;
end;

// ---------------------------------------------------------------------------
// Built-in commands
// ---------------------------------------------------------------------------

procedure TDeepMainForm.InstallBuiltInCommands;
begin
  FCommands.RegisterCommand(
    ShellCommand(CMD_FILE_EXIT, ShellText('shell.cmd.fileExit', 'Exit'))
      .Category(ShellText('shell.cat.file', 'File'))
      .Shortcut('Alt+F4')
      .RiskLevel(rlLow)
      .GateKey('shell.file.exit')
      .OnExecute(procedure begin Close; end));

  FCommands.RegisterCommand(
    ShellCommand(CMD_VIEW_TOGGLE_TOP, ShellText('shell.cmd.view.toggleTop', 'Toggle Top Pane'))
      .Category(ShellText('shell.cat.view', 'View'))
      .OnExecute(procedure
        begin
          if FTopController <> nil then FTopController.ToggleCollapsed;
        end));

  FCommands.RegisterCommand(
    ShellCommand(CMD_VIEW_TOGGLE_MID, ShellText('shell.cmd.view.toggleMiddle', 'Toggle Middle Pane'))
      .Category(ShellText('shell.cat.view', 'View'))
      .OnExecute(procedure
        begin
          if FMiddleController <> nil then FMiddleController.ToggleCollapsed;
        end));

  FCommands.RegisterCommand(
    ShellCommand(CMD_VIEW_TOGGLE_BOT, ShellText('shell.cmd.view.toggleBottom', 'Toggle Bottom Pane'))
      .Category(ShellText('shell.cat.view', 'View'))
      .OnExecute(procedure
        begin
          if FBottomController <> nil then FBottomController.ToggleCollapsed;
        end));

  FCommands.RegisterCommand(
    ShellCommand(CMD_VIEW_STRUCTURE, ShellText('shell.cmd.view.structure', 'Structure Window'))
      .Category(ShellText('shell.cat.view', 'View'))
      .OnExecute(procedure
        begin
          if FStructureWindow <> nil then FStructureWindow.ToggleVisible;
        end));

  FCommands.RegisterCommand(
    ShellCommand(CMD_VIEW_INSPECTOR, ShellText('shell.cmd.view.inspector', 'Inspector Window'))
      .Category(ShellText('shell.cat.view', 'View'))
      .OnExecute(procedure
        begin
          if FInspectorWindow <> nil then FInspectorWindow.ToggleVisible;
        end));

  FCommands.RegisterCommand(
    ShellCommand(CMD_VIEW_RESET_LAYOUT, ShellText('shell.cmd.view.resetLayout', 'Reset Layout'))
      .Category(ShellText('shell.cat.view', 'View'))
      .RiskLevel(rlLow)
      .GateKey('shell.view.resetLayout')
      .OnExecute(procedure
        begin
          if FLayout <> nil then FLayout.ResetGlobalLayout;
          if FTopController <> nil then FTopController.SetCollapsed(False);
          if FMiddleController <> nil then FMiddleController.SetCollapsed(False);
          if FBottomController <> nil then FBottomController.SetCollapsed(True);
        end));

  FCommands.RegisterCommand(
    ShellCommand(CMD_RECENT_CLEAR, ShellText('shell.cmd.recent.clear', 'Clear Recent'))
      .Category(ShellText('shell.cat.file', 'File'))
      .RiskLevel(rlLow)
      .GateKey('shell.recent.clear')
      .OnExecute(procedure
        begin
          if FRecent <> nil then FRecent.Clear;
        end));

  FCommands.RegisterCommand(
    ShellCommand(CMD_LOG_CLEAR, ShellText('shell.cmd.log.clear', 'Clear Log'))
      .Category(ShellText('shell.cat.log', 'Log'))
      .RiskLevel(rlLow)
      .GateKey('shell.log.clear')
      .OnExecute(procedure
        begin
          if FStatus <> nil then FStatus.ClearEntries;
          FLastLogEntryCount := 0;
          if FBottomLog <> nil then FBottomLog.Lines.Clear;
        end));

  FCommands.RegisterCommand(
    ShellCommand(CMD_SETTINGS_OPEN, ShellText('shell.cmd.settings.open', 'Settings...'))
      .Category(ShellText('shell.cat.tools', 'Tools'))
      .OnExecute(procedure begin OpenSettingsDialog; end));

  FCommands.RegisterCommand(
    ShellCommand(CMD_SETTINGS_DEFAULTS,
      ShellText('shell.cmd.settings.restoreDefaults', 'Restore Settings to Defaults'))
      .Category(ShellText('shell.cat.tools', 'Tools'))
      .RiskLevel(rlMedium)
      .GateKey('shell.settings.restoreDefaults')
      .OnExecute(procedure
        var
          I: Integer;
        begin
          for I := 0 to FSettingsPages.Count - 1 do
            FSettingsPages[I].RestoreDefaults;
        end));

  FCommands.RegisterCommand(
    ShellCommand(CMD_HELP_ABOUT, ShellText('shell.cmd.help.about', 'About...'))
      .Category(ShellText('shell.cat.help', 'Help'))
      .OnExecute(procedure
        begin
          ShowMessage(ShellText('shell.help.aboutBody',
            'DeepShell - DeepBase desktop application shell.'));
        end));
end;

// ---------------------------------------------------------------------------
// Provider registration helpers
// ---------------------------------------------------------------------------

procedure TDeepMainForm.RegisterStructureProvider(
  const AProvider: IShellStructureProvider);
begin
  if AProvider <> nil then
  begin
    FStructureProviders.Add(AProvider);
    if FShellInitialised then
      RebuildStructureTree;
  end;
end;

procedure TDeepMainForm.RegisterMainViewProvider(
  const AProvider: IShellMainViewProvider);
begin
  if AProvider <> nil then FMainViewProviders.Add(AProvider);
end;

procedure TDeepMainForm.RegisterInspectorProvider(
  const AProvider: IShellInspectorProvider);
begin
  if AProvider <> nil then FInspectorProviders.Add(AProvider);
end;

procedure TDeepMainForm.RegisterSettingsPageProvider(
  const AProvider: ISettingsPageProvider);
begin
  if AProvider <> nil then FSettingsPages.Add(AProvider);
end;

procedure TDeepMainForm.SetGovernance(const AGovernance: IGovernanceService);
begin
  FGovernance := AGovernance;
  if FCommands <> nil then
    FCommands.SetGovernance(AGovernance);
end;

function TDeepMainForm.ShellText(const AKey, ADefault: string): string;
begin
  if FLocalization <> nil then
    Result := FLocalization.Text(AKey, ADefault)
  else
    Result := ADefault;
end;

// ---------------------------------------------------------------------------
// Main view / inspector dispatch
// ---------------------------------------------------------------------------

procedure TDeepMainForm.ClearMainView;
begin
  if FCurrentMainView <> nil then
  begin
    FCurrentMainView.Free;
    FCurrentMainView := nil;
  end;
end;

procedure TDeepMainForm.OpenView(const ARef: TShellObjectRef);
var
  LProvider: IShellMainViewProvider;
  LInfo: TShellViewInfo;
  LCtl: TControl;
  LMemo: TMemo;
  I: Integer;
begin
  LProvider := nil;
  // Pass 1: prefer providers whose ProviderId matches the ref's ProviderId.
  // This avoids "first registered wins" wrong-provider dispatch when two
  // providers can open the same Kind.
  if ARef.ProviderId <> '' then
    for I := 0 to FMainViewProviders.Count - 1 do
      if SameText(FMainViewProviders[I].ProviderId, ARef.ProviderId)
         and FMainViewProviders[I].CanOpen(ARef) then
      begin
        LProvider := FMainViewProviders[I];
        Break;
      end;

  // Pass 2: fall back to any provider that claims it can open the ref.
  if LProvider = nil then
    for I := 0 to FMainViewProviders.Count - 1 do
      if FMainViewProviders[I].CanOpen(ARef) then
      begin
        LProvider := FMainViewProviders[I];
        Break;
      end;

  if LProvider = nil then
  begin
    if FStatus <> nil then
      FStatus.Warning('main.view',
        Format('No provider can open %s/%s', [ARef.ProviderId, ARef.Kind]));
    Exit;
  end;

  LInfo := LProvider.GetViewForObject(ARef);
  ClearMainView;

  case LInfo.ViewKind of
    svkControl, svkFrame, svkHtml, svkMarkdown:
      begin
        // For svkHtml / svkMarkdown the provider is expected to attach a
        // dedicated renderer (WebView2, CEF, custom Markdown control, ...).
        // We do NOT render HTML source as plain text - that violates the
        // doc 72 contract.
        LCtl := LProvider.CreateViewControl(FMiddleHost, ARef, LInfo);
        if LCtl <> nil then
        begin
          LCtl.Parent := FMiddleHost;
          LCtl.Align := alClient;
          FCurrentMainView := LCtl;
        end
        else if FStatus <> nil then
          FStatus.Warning('main.view',
            Format('Provider %s returned no control for view %s of kind %d',
              [LProvider.ProviderId, LInfo.ViewId, Ord(LInfo.ViewKind)]));
      end;
    svkText:
      begin
        LMemo := TMemo.Create(FMiddleHost);
        LMemo.Parent := FMiddleHost;
        LMemo.Align := alClient;
        LMemo.ReadOnly := True;
        LMemo.ScrollBars := ssBoth;
        LMemo.Lines.Text := LInfo.Content;
        FCurrentMainView := LMemo;
      end;
    svkExternal:
      begin
        if FStatus <> nil then
          FStatus.Diagnostic('main.view',
            Format('External view requested for %s', [LInfo.ViewId]));
      end;
  end;

  // Update context: SetObject first so Inspector / governance reflect the
  // newly-opened object before SetView lands. ContextManager's ViewType
  // field is meant to carry the kind of view (svkText / svkHtml / ...),
  // not its title - title is descriptive UI text.
  if FContext <> nil then
  begin
    FContext.SetObject(ARef);
    FContext.SetView(LInfo.ViewId,
      GetEnumName(TypeInfo(TShellViewKind), Ord(LInfo.ViewKind)));
  end;
end;

// ---------------------------------------------------------------------------
// Main menu / Structure tree / Inspector grid
// ---------------------------------------------------------------------------

procedure TDeepMainForm.DoCommandMenuClick(Sender: TObject);
var
  LItem: TMenuItem;
  LCommandId: string;
begin
  if not (Sender is TMenuItem) then
    Exit;
  LItem := TMenuItem(Sender);
  LCommandId := string(LItem.Hint);
  if (LCommandId <> '') and (FCommands <> nil) then
    FCommands.Execute(LCommandId);
end;

procedure TDeepMainForm.RebuildMainMenu;
var
  LIds: TArray<string>;
  LCmd: TShellCommand;
  LCategoryItems: TDictionary<string, TMenuItem>;
  LCatItem, LCmdItem: TMenuItem;
  LCategory, LCmdId: string;
  I: Integer;
begin
  if (FMainMenu = nil) or (FCommands = nil) then
    Exit;

  // Wipe any prior menu state. FMainMenu owns its items; freeing them
  // clears FCommandMenuItems' raw refs which are about to be repopulated.
  FMainMenu.Items.Clear;
  FCommandMenuItems.Clear;

  LCategoryItems := TDictionary<string, TMenuItem>.Create;
  try
    LIds := FCommands.CommandIds;  // insertion-ordered (BUG-159)
    for I := 0 to High(LIds) do
    begin
      LCmdId := LIds[I];
      if not FCommands.TryGetCommand(LCmdId, LCmd) then
        Continue;
      if not LCmd.Visible then
        Continue;

      LCategory := LCmd.Category;
      if LCategory = '' then
        LCategory := ShellText('shell.cat.misc', 'Misc');

      // Top-level category menu, lazily created.
      if not LCategoryItems.TryGetValue(LCategory, LCatItem) then
      begin
        LCatItem := TMenuItem.Create(FMainMenu);
        LCatItem.Caption := LCategory;
        FMainMenu.Items.Add(LCatItem);
        LCategoryItems.Add(LCategory, LCatItem);
      end;

      LCmdItem := TMenuItem.Create(LCatItem);
      LCmdItem.Caption := LCmd.Caption;
      LCmdItem.Hint := LCmdId;  // carries command id for click handler
      LCmdItem.Enabled := LCmd.Enabled;
      if LCmd.ShortcutText <> '' then
        LCmdItem.ShortCut := TextToShortCut(LCmd.ShortcutText);
      LCmdItem.OnClick := DoCommandMenuClick;
      LCatItem.Add(LCmdItem);

      FCommandMenuItems.AddOrSetValue(LCmdId, LCmdItem);
    end;
  finally
    LCategoryItems.Free;
  end;
end;

procedure TDeepMainForm.RebuildStructureTree;
var
  LProvider: IShellStructureProvider;
  LTreeNames: TArray<string>;
  LRoots: TArray<TShellObjectRef>;
  LTreeNode, LRootNode, LStub: TTreeNode;
  LProviderRef: PShellObjectRef;
  LRootRef: PShellObjectRef;
  P, T, R, I: Integer;
  LNode: TTreeNode;
begin
  if (FStructureTree = nil) or (FStructureProviders = nil) then
    Exit;

  FStructureTree.Items.BeginUpdate;
  try
    // Belt-and-braces cleanup: walk every node and free its
    // PShellObjectRef payload before Clear. VCL's TTreeView.Items.Clear
    // generally fires OnDeletion per node, but the spec is fuzzy across
    // versions; explicit walk guarantees no leak.
    for I := 0 to FStructureTree.Items.Count - 1 do
    begin
      LNode := FStructureTree.Items[I];
      if (LNode <> nil) and (LNode.Data <> nil) then
      begin
        Dispose(PShellObjectRef(LNode.Data));
        LNode.Data := nil;
      end;
    end;
    FStructureTree.Items.Clear;

    for P := 0 to FStructureProviders.Count - 1 do
    begin
      LProvider := FStructureProviders[P];
      LTreeNames := LProvider.GetTreeNames;
      for T := 0 to High(LTreeNames) do
      begin
        // Provider/tree-name root: synthetic node without a business ref.
        // We tag it with a TShellObjectRef whose ProviderId matches the
        // provider so child loading later can resolve the right provider
        // by walking up the parent chain.
        New(LProviderRef);
        LProviderRef^ := TShellObjectRef.Make('', '__tree__',
          LProvider.ProviderId, LTreeNames[T]);
        LTreeNode := FStructureTree.Items.AddChild(nil, LTreeNames[T]);
        LTreeNode.Data := LProviderRef;

        LRoots := LProvider.GetRootNodes(LTreeNames[T]);
        for R := 0 to High(LRoots) do
        begin
          New(LRootRef);
          LRootRef^ := LRoots[R];
          LRootNode := FStructureTree.Items.AddChild(LTreeNode,
            LProvider.GetDisplayText(LRoots[R]));
          LRootNode.Data := LRootRef;
          if LProvider.HasChildren(LRoots[R]) then
          begin
            LStub := FStructureTree.Items.AddChild(LRootNode, '...');
            LStub.Data := nil;  // sentinel - DoStructureExpanding deletes it
          end;
        end;
      end;
    end;
  finally
    FStructureTree.Items.EndUpdate;
  end;
end;

function TDeepMainForm.StructureNodeRef(ANode: TTreeNode): TShellObjectRef;
begin
  if (ANode <> nil) and (ANode.Data <> nil) then
    Result := PShellObjectRef(ANode.Data)^
  else
    Result := TShellObjectRef.Empty;
end;

function TDeepMainForm.StructureNodeProvider(ANode: TTreeNode): IShellStructureProvider;
var
  LRef: TShellObjectRef;
  I: Integer;
begin
  Result := nil;
  while ANode <> nil do
  begin
    LRef := StructureNodeRef(ANode);
    if LRef.ProviderId <> '' then
    begin
      for I := 0 to FStructureProviders.Count - 1 do
        if SameText(FStructureProviders[I].ProviderId, LRef.ProviderId) then
        begin
          Result := FStructureProviders[I];
          Exit;
        end;
    end;
    ANode := ANode.Parent;
  end;
end;

procedure TDeepMainForm.ExpandStructureNode(ANode: TTreeNode);
var
  LProvider: IShellStructureProvider;
  LRef: TShellObjectRef;
  LChildren: TArray<TShellObjectRef>;
  LChild: TTreeNode;
  LChildRef: PShellObjectRef;
  LStub: TTreeNode;
  I: Integer;
begin
  if (ANode = nil) or (ANode.HasChildren = False) then
    Exit;

  // If the only child is the placeholder stub (Data = nil), replace it
  // with real provider-loaded children. Already-expanded nodes don't have
  // a stub anymore, so this is idempotent.
  LStub := nil;
  if (ANode.Count = 1) and (ANode.Item[0].Data = nil) then
    LStub := ANode.Item[0];
  if LStub = nil then
    Exit;

  LRef := StructureNodeRef(ANode);
  if LRef.IsEmpty or (LRef.Kind = '__tree__') then
  begin
    LStub.Delete;
    Exit;
  end;

  LProvider := StructureNodeProvider(ANode);
  if LProvider = nil then
  begin
    LStub.Delete;
    Exit;
  end;

  FStructureTree.Items.BeginUpdate;
  try
    LStub.Delete;
    LChildren := LProvider.GetChildren(LRef);
    for I := 0 to High(LChildren) do
    begin
      New(LChildRef);
      LChildRef^ := LChildren[I];
      LChild := FStructureTree.Items.AddChild(ANode,
        LProvider.GetDisplayText(LChildren[I]));
      LChild.Data := LChildRef;
      if LProvider.HasChildren(LChildren[I]) then
        FStructureTree.Items.AddChild(LChild, '...');
    end;
  finally
    FStructureTree.Items.EndUpdate;
  end;
end;

procedure TDeepMainForm.DoStructureChange(Sender: TObject; Node: TTreeNode);
var
  LRef: TShellObjectRef;
begin
  if Node = nil then
    Exit;
  LRef := StructureNodeRef(Node);
  // Skip synthetic provider/tree-name nodes - they have no business ref.
  if LRef.IsEmpty or (LRef.Kind = '__tree__') then
    Exit;
  if FContext <> nil then
    FContext.SetObject(LRef);
end;

procedure TDeepMainForm.DoStructureExpanding(Sender: TObject;
  Node: TTreeNode; var AllowExpansion: Boolean);
begin
  AllowExpansion := True;
  ExpandStructureNode(Node);
end;

procedure TDeepMainForm.DoStructureDeletion(Sender: TObject; Node: TTreeNode);
begin
  if (Node <> nil) and (Node.Data <> nil) then
  begin
    Dispose(PShellObjectRef(Node.Data));
    Node.Data := nil;
  end;
end;

procedure TDeepMainForm.RefreshInspector(const ARef: TShellObjectRef);
var
  LProvider: IShellInspectorProvider;
  LProps: TArray<TShellProperty>;
  I: Integer;
begin
  if FInspectorGrid = nil then
    Exit;

  // Pick the first provider that claims the ref. Two-pass (provider id
  // priority) would be ideal symmetry with OpenView, but inspector data
  // is a side-pane reflection so first-match is acceptable here.
  LProvider := nil;
  if FInspectorProviders <> nil then
    for I := 0 to FInspectorProviders.Count - 1 do
      if FInspectorProviders[I].CanInspect(ARef) then
      begin
        LProvider := FInspectorProviders[I];
        Break;
      end;

  if LProvider = nil then
  begin
    // Keep header row visible; clear data rows. RowCount must stay >
    // FixedRows for VCL invariant.
    FInspectorGrid.RowCount := 2;
    FInspectorGrid.Cells[0, 1] := '';
    FInspectorGrid.Cells[1, 1] := '';
    Exit;
  end;

  LProps := LProvider.GetProperties(ARef);
  if Length(LProps) = 0 then
  begin
    FInspectorGrid.RowCount := 2;
    FInspectorGrid.Cells[0, 1] := '';
    FInspectorGrid.Cells[1, 1] := '';
    Exit;
  end;
  FInspectorGrid.RowCount := Length(LProps) + 1;
  for I := 0 to High(LProps) do
  begin
    FInspectorGrid.Cells[0, I + 1] := LProps[I].Name;
    FInspectorGrid.Cells[1, I + 1] := LProps[I].Value;
  end;
end;

// ---------------------------------------------------------------------------
// Settings dialog
// ---------------------------------------------------------------------------

procedure TDeepMainForm.OpenSettingsDialog;
var
  LForm: TDeepShellSettingsForm;
  LSelfRef: TDeepMainForm;
begin
  LForm := TDeepShellSettingsForm.CreateNew(Self);
  LSelfRef := Self;
  try
    LForm.SetLocalization(FLocalization);
    LForm.SetCommands(FCommands);
    // Per-page reset goes through governance with page-id specific
    // evidence. Reuses the same GateKey as the global "reset all" command
    // (CMD_SETTINGS_DEFAULTS) but at L1 risk because only one page is
    // affected. Returns False if governance denies; the dialog will not
    // call provider.RestoreDefaults in that case.
    LForm.SetResetAction(
      function(AProvider: ISettingsPageProvider): Boolean
      var
        LGov: IGovernanceService;
        LResult: TShellGateResult;
        LCtxJson: string;
        LJsonObj: TJSONObject;
      begin
        Result := False;
        if AProvider = nil then Exit;
        LGov := LSelfRef.FGovernance;
        if (LGov <> nil) and LGov.IsEnabled then
        begin
          LJsonObj := TJSONObject.Create;
          try
            LJsonObj.AddPair('command_id', CMD_SETTINGS_DEFAULTS);
            LJsonObj.AddPair('page_id', AProvider.PageId);
            LJsonObj.AddPair('risk_level', TJSONNumber.Create(1));
            LCtxJson := LJsonObj.ToJSON;
          finally
            LJsonObj.Free;
          end;
          if not LGov.EnterGate('shell.settings.restoreDefaults', LCtxJson, LResult)
             or not LResult.Allowed then
          begin
            if LSelfRef.FStatus <> nil then
              LSelfRef.FStatus.Warning('shell.settings',
                Format('Restore defaults denied for page "%s": %s',
                  [AProvider.PageId, LResult.MessageText]));
            Exit;
          end;
        end;
        AProvider.RestoreDefaults;
        Result := True;
      end);
    LForm.SetProviders(FSettingsPages.ToArray);
    LForm.Run;
  finally
    LForm.Free;
  end;
end;

end.
