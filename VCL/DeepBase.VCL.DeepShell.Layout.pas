{ ============================================================================
  DeepBase.VCL.DeepShell.Layout

  In-memory IShellLayoutService and an IShellSettingsStore-backed variant.
  The settings-backed implementation persists layout state as JSON strings
  through the shell settings store, enabling DB1 / ConfigDB persistence
  via SettingsStore adapters without coupling the shell core to DB1.

  See docs/74.vcl.DeepShell-MRU-Layout-Settings设计.md
  ============================================================================ }

unit DeepBase.VCL.DeepShell.Layout;

interface

uses
  System.SysUtils,
  System.SyncObjs,
  System.JSON,
  System.Generics.Collections,
  DeepBase.VCL.DeepShell.Types,
  DeepBase.VCL.DeepShell.Intf;

type
  /// <summary>
  /// Pure in-memory layout service. Used by tests and demos. State is lost
  /// when the process exits.
  /// </summary>
  TShellInMemoryLayoutService = class(TInterfacedObject, IShellLayoutService)
  private
    FLock: TCriticalSection;
    FGlobal: TShellLayoutState;
    FHasGlobal: Boolean;
    FProjectLayouts: TDictionary<string, TShellLayoutState>;
  public
    constructor Create;
    destructor Destroy; override;
    // IShellLayoutService
    procedure SaveGlobalLayout(const AState: TShellLayoutState);
    function TryLoadGlobalLayout(out AState: TShellLayoutState): Boolean;
    procedure SaveProjectLayout(const AProjectId: string; const AState: TShellLayoutState);
    function TryLoadProjectLayout(const AProjectId: string; out AState: TShellLayoutState): Boolean;
    procedure ResetGlobalLayout;
    procedure ResetProjectLayout(const AProjectId: string);
  end;

  /// <summary>
  /// Layout service that persists state via an injected IShellSettingsStore.
  /// Format is a single JSON document per key. Atomic writes are the
  /// responsibility of the underlying store.
  /// </summary>
  TShellSettingsBackedLayoutService = class(TInterfacedObject, IShellLayoutService)
  private
    FStore: IShellSettingsStore;
    FInstanceId: string;
    function GlobalKey: string;
    function ProjectKey(const AProjectId: string): string;
    function StateToJson(const AState: TShellLayoutState): string;
    function TryParseState(const AJson: string; out AState: TShellLayoutState): Boolean;
  public
    constructor Create(const AStore: IShellSettingsStore; const AInstanceId: string);
    destructor Destroy; override;
    procedure SaveGlobalLayout(const AState: TShellLayoutState);
    function TryLoadGlobalLayout(out AState: TShellLayoutState): Boolean;
    procedure SaveProjectLayout(const AProjectId: string; const AState: TShellLayoutState);
    function TryLoadProjectLayout(const AProjectId: string; out AState: TShellLayoutState): Boolean;
    procedure ResetGlobalLayout;
    procedure ResetProjectLayout(const AProjectId: string);
  end;

implementation

uses
  System.DateUtils;

// ---------------------------------------------------------------------------
// TShellInMemoryLayoutService
// ---------------------------------------------------------------------------

constructor TShellInMemoryLayoutService.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FProjectLayouts := TDictionary<string, TShellLayoutState>.Create;
  FGlobal := TShellLayoutState.Empty;
  FHasGlobal := False;
end;

destructor TShellInMemoryLayoutService.Destroy;
begin
  FreeAndNil(FProjectLayouts);
  FreeAndNil(FLock);
  inherited;
end;

procedure TShellInMemoryLayoutService.SaveGlobalLayout(const AState: TShellLayoutState);
begin
  FLock.Enter;
  try
    FGlobal := AState;
    FGlobal.UpdatedAt := Now;
    FHasGlobal := True;
  finally
    FLock.Leave;
  end;
end;

function TShellInMemoryLayoutService.TryLoadGlobalLayout(
  out AState: TShellLayoutState): Boolean;
begin
  FLock.Enter;
  try
    Result := FHasGlobal;
    if Result then
      AState := FGlobal
    else
      AState := TShellLayoutState.Empty;
  finally
    FLock.Leave;
  end;
end;

procedure TShellInMemoryLayoutService.SaveProjectLayout(const AProjectId: string;
  const AState: TShellLayoutState);
var
  LState: TShellLayoutState;
begin
  if AProjectId = '' then
    Exit;
  LState := AState;
  LState.UpdatedAt := Now;
  FLock.Enter;
  try
    FProjectLayouts.AddOrSetValue(AProjectId, LState);
  finally
    FLock.Leave;
  end;
end;

function TShellInMemoryLayoutService.TryLoadProjectLayout(const AProjectId: string;
  out AState: TShellLayoutState): Boolean;
begin
  AState := TShellLayoutState.Empty;
  if AProjectId = '' then
    Exit(False);
  FLock.Enter;
  try
    Result := FProjectLayouts.TryGetValue(AProjectId, AState);
  finally
    FLock.Leave;
  end;
end;

procedure TShellInMemoryLayoutService.ResetGlobalLayout;
begin
  FLock.Enter;
  try
    FGlobal := TShellLayoutState.Empty;
    FHasGlobal := False;
  finally
    FLock.Leave;
  end;
end;

procedure TShellInMemoryLayoutService.ResetProjectLayout(const AProjectId: string);
begin
  FLock.Enter;
  try
    FProjectLayouts.Remove(AProjectId);
  finally
    FLock.Leave;
  end;
end;

// ---------------------------------------------------------------------------
// TShellSettingsBackedLayoutService
// ---------------------------------------------------------------------------

function PanelStateToJson(const APanel: TShellPanelState): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('panelId', APanel.PanelId);
  Result.AddPair('visible', TJSONBool.Create(APanel.Visible));
  Result.AddPair('collapsed', TJSONBool.Create(APanel.Collapsed));
  Result.AddPair('size', TJSONNumber.Create(APanel.Size));
  Result.AddPair('lastExpandedSize', TJSONNumber.Create(APanel.LastExpandedSize));
  Result.AddPair('activeTabId', APanel.ActiveTabId);
end;

procedure JsonToPanelState(const AObj: TJSONObject; var APanel: TShellPanelState);
begin
  if AObj = nil then
    Exit;
  APanel.PanelId := AObj.GetValue<string>('panelId', APanel.PanelId);
  APanel.Visible := AObj.GetValue<Boolean>('visible', APanel.Visible);
  APanel.Collapsed := AObj.GetValue<Boolean>('collapsed', APanel.Collapsed);
  APanel.Size := AObj.GetValue<Integer>('size', APanel.Size);
  APanel.LastExpandedSize := AObj.GetValue<Integer>('lastExpandedSize', APanel.LastExpandedSize);
  APanel.ActiveTabId := AObj.GetValue<string>('activeTabId', APanel.ActiveTabId);
end;

function ToolWindowStateToJson(const AWin: TShellToolWindowState): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('windowId', AWin.WindowId);
  Result.AddPair('visible', TJSONBool.Create(AWin.Visible));
  Result.AddPair('pinned', TJSONBool.Create(AWin.Pinned));
  Result.AddPair('locked', TJSONBool.Create(AWin.Locked));
  Result.AddPair('left', TJSONNumber.Create(AWin.Left));
  Result.AddPair('top', TJSONNumber.Create(AWin.Top));
  Result.AddPair('width', TJSONNumber.Create(AWin.Width));
  Result.AddPair('height', TJSONNumber.Create(AWin.Height));
  Result.AddPair('activeTabId', AWin.ActiveTabId);
end;

procedure JsonToToolWindowState(const AObj: TJSONObject; var AWin: TShellToolWindowState);
begin
  if AObj = nil then
    Exit;
  AWin.WindowId := AObj.GetValue<string>('windowId', AWin.WindowId);
  AWin.Visible := AObj.GetValue<Boolean>('visible', AWin.Visible);
  AWin.Pinned := AObj.GetValue<Boolean>('pinned', AWin.Pinned);
  AWin.Locked := AObj.GetValue<Boolean>('locked', AWin.Locked);
  AWin.Left := AObj.GetValue<Integer>('left', AWin.Left);
  AWin.Top := AObj.GetValue<Integer>('top', AWin.Top);
  AWin.Width := AObj.GetValue<Integer>('width', AWin.Width);
  AWin.Height := AObj.GetValue<Integer>('height', AWin.Height);
  AWin.ActiveTabId := AObj.GetValue<string>('activeTabId', AWin.ActiveTabId);
end;

constructor TShellSettingsBackedLayoutService.Create(const AStore: IShellSettingsStore;
  const AInstanceId: string);
begin
  inherited Create;
  if AStore = nil then
    raise EArgumentNilException.Create(
      'TShellSettingsBackedLayoutService.Create: AStore is nil');
  FStore := AStore;
  FInstanceId := AInstanceId;
end;

destructor TShellSettingsBackedLayoutService.Destroy;
begin
  FStore := nil;
  inherited;
end;

function TShellSettingsBackedLayoutService.GlobalKey: string;
begin
  Result := 'shell.layout.global';
end;

function TShellSettingsBackedLayoutService.ProjectKey(const AProjectId: string): string;
begin
  Result := 'shell.layout.project.' + AProjectId;
end;

function TShellSettingsBackedLayoutService.StateToJson(
  const AState: TShellLayoutState): string;
var
  LRoot: TJSONObject;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('layoutKey', AState.LayoutKey);
    LRoot.AddPair('updatedAt', DateToISO8601(AState.UpdatedAt, False));
    LRoot.AddPair('writerInstanceId', AState.WriterInstanceId);
    LRoot.AddPair('mainLeft', TJSONNumber.Create(AState.MainLeft));
    LRoot.AddPair('mainTop', TJSONNumber.Create(AState.MainTop));
    LRoot.AddPair('mainWidth', TJSONNumber.Create(AState.MainWidth));
    LRoot.AddPair('mainHeight', TJSONNumber.Create(AState.MainHeight));
    LRoot.AddPair('maximized', TJSONBool.Create(AState.Maximized));
    LRoot.AddPair('top', PanelStateToJson(AState.TopPanel));
    LRoot.AddPair('middle', PanelStateToJson(AState.MiddlePanel));
    LRoot.AddPair('bottom', PanelStateToJson(AState.BottomPanel));
    LRoot.AddPair('leftToolWindow', ToolWindowStateToJson(AState.LeftToolWindow));
    LRoot.AddPair('rightToolWindow', ToolWindowStateToJson(AState.RightToolWindow));
    LRoot.AddPair('currentViewId', AState.CurrentViewId);
    LRoot.AddPair('currentTabId', AState.CurrentTabId);
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

function TShellSettingsBackedLayoutService.TryParseState(const AJson: string;
  out AState: TShellLayoutState): Boolean;
var
  LValue: TJSONValue;
  LRoot: TJSONObject;
  LObj: TJSONObject;
  LIso: string;
begin
  AState := TShellLayoutState.Empty;
  Result := False;
  if AJson = '' then
    Exit;

  LValue := TJSONObject.ParseJSONValue(AJson);
  if LValue = nil then
    Exit;
  if not (LValue is TJSONObject) then
  begin
    LValue.Free;
    Exit;
  end;

  LRoot := TJSONObject(LValue);
  try
    AState.LayoutKey := LRoot.GetValue<string>('layoutKey', '');
    LIso := LRoot.GetValue<string>('updatedAt', '');
    if LIso <> '' then
    try
      AState.UpdatedAt := ISO8601ToDate(LIso, False);
    except
      AState.UpdatedAt := 0;
    end;
    AState.WriterInstanceId := LRoot.GetValue<string>('writerInstanceId', '');
    AState.MainLeft := LRoot.GetValue<Integer>('mainLeft', 0);
    AState.MainTop := LRoot.GetValue<Integer>('mainTop', 0);
    AState.MainWidth := LRoot.GetValue<Integer>('mainWidth', 0);
    AState.MainHeight := LRoot.GetValue<Integer>('mainHeight', 0);
    AState.Maximized := LRoot.GetValue<Boolean>('maximized', False);
    AState.CurrentViewId := LRoot.GetValue<string>('currentViewId', '');
    AState.CurrentTabId := LRoot.GetValue<string>('currentTabId', '');

    LObj := LRoot.GetValue<TJSONObject>('top', nil);
    JsonToPanelState(LObj, AState.TopPanel);
    LObj := LRoot.GetValue<TJSONObject>('middle', nil);
    JsonToPanelState(LObj, AState.MiddlePanel);
    LObj := LRoot.GetValue<TJSONObject>('bottom', nil);
    JsonToPanelState(LObj, AState.BottomPanel);
    LObj := LRoot.GetValue<TJSONObject>('leftToolWindow', nil);
    JsonToToolWindowState(LObj, AState.LeftToolWindow);
    LObj := LRoot.GetValue<TJSONObject>('rightToolWindow', nil);
    JsonToToolWindowState(LObj, AState.RightToolWindow);

    Result := True;
  finally
    LRoot.Free;
  end;
end;

procedure TShellSettingsBackedLayoutService.SaveGlobalLayout(
  const AState: TShellLayoutState);
var
  LState: TShellLayoutState;
begin
  LState := AState;
  LState.UpdatedAt := Now;
  if LState.WriterInstanceId = '' then
    LState.WriterInstanceId := FInstanceId;
  FStore.WriteString(GlobalKey, StateToJson(LState));
end;

function TShellSettingsBackedLayoutService.TryLoadGlobalLayout(
  out AState: TShellLayoutState): Boolean;
var
  LJson: string;
begin
  LJson := FStore.ReadString(GlobalKey, '');
  if LJson = '' then
  begin
    AState := TShellLayoutState.Empty;
    Exit(False);
  end;
  Result := TryParseState(LJson, AState);
  if not Result then
    AState := TShellLayoutState.Empty;
end;

procedure TShellSettingsBackedLayoutService.SaveProjectLayout(
  const AProjectId: string; const AState: TShellLayoutState);
var
  LState: TShellLayoutState;
begin
  if AProjectId = '' then
    Exit;
  LState := AState;
  LState.UpdatedAt := Now;
  if LState.WriterInstanceId = '' then
    LState.WriterInstanceId := FInstanceId;
  FStore.WriteString(ProjectKey(AProjectId), StateToJson(LState));
end;

function TShellSettingsBackedLayoutService.TryLoadProjectLayout(
  const AProjectId: string; out AState: TShellLayoutState): Boolean;
var
  LJson: string;
begin
  AState := TShellLayoutState.Empty;
  if AProjectId = '' then
    Exit(False);
  LJson := FStore.ReadString(ProjectKey(AProjectId), '');
  if LJson = '' then
    Exit(False);
  Result := TryParseState(LJson, AState);
  if not Result then
    AState := TShellLayoutState.Empty;
end;

procedure TShellSettingsBackedLayoutService.ResetGlobalLayout;
begin
  FStore.RemoveKey(GlobalKey);
end;

procedure TShellSettingsBackedLayoutService.ResetProjectLayout(
  const AProjectId: string);
begin
  if AProjectId <> '' then
    FStore.RemoveKey(ProjectKey(AProjectId));
end;

end.
