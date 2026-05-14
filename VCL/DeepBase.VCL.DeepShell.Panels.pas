{ ============================================================================
  DeepBase.VCL.DeepShell.Panels

  Helpers for the three collapsible main areas (top / middle / bottom)
  and the default IShellStatusManager implementation that the bottom
  diagnostic pane consumes.

  Collapsing rules (see docs/71.vcl.DeepShell-结构规范.md §6):
    - Top collapse keeps a one-line summary.
    - Middle collapse keeps a "restore workspace" entry point.
    - Bottom collapse keeps the status bar visible.
  ============================================================================ }

unit DeepBase.VCL.DeepShell.Panels;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.StdCtrls,
  DeepBase.VCL.DeepShell.Types,
  DeepBase.VCL.DeepShell.Intf;

const
  MIN_TOP_HEIGHT_COLLAPSED    = 24;
  MIN_BOTTOM_HEIGHT_COLLAPSED = 24;
  MIN_MIDDLE_HEIGHT_COLLAPSED = 28;
  DEFAULT_TOP_HEIGHT          = 64;
  DEFAULT_BOTTOM_HEIGHT       = 140;

type
  /// <summary>
  /// Lightweight controller around a TPanel + TSplitter pair that implements
  /// the docs/71 collapse contract. Bottom + Top panels keep a one-line
  /// summary band when collapsed.
  /// </summary>
  TShellAreaController = class
  private
    FPanel: TPanel;
    FSplitter: TSplitter;
    FState: TShellPanelState;
    FCollapsedSummary: TLabel;
    FExpandedHost: TWinControl;
    procedure UpdateVisuals;
  public
    constructor Create(APanel: TPanel; ASplitter: TSplitter;
      AExpandedHost: TWinControl; ACollapsedSummary: TLabel;
      const APanelId: string);
    procedure SetCollapsed(AValue: Boolean);
    procedure ToggleCollapsed;
    procedure SetVisible(AValue: Boolean);
    procedure SetSize(AValue: Integer);
    function State: TShellPanelState;
    procedure ApplyState(const AState: TShellPanelState);
    procedure SetSummary(const AText: string);
    property Panel: TPanel read FPanel;
  end;

  /// <summary>
  /// Default IShellStatusManager. Stores entries in memory and publishes
  /// status events through the EventBus so UI components can refresh.
  /// </summary>
  TShellStatusManager = class(TInterfacedObject, IShellStatusManager)
  private
    FLock: TCriticalSection;
    FBus: IShellEventBus;
    FEntries: TList<TShellStatusEntry>;
    FCapacity: Integer;
    FSanitizer: TShellStatusSanitizer;
    function ApplySanitizer(const ASource, AMessage: string): string;
    procedure AddEntry(AKind: TShellStatusKind;
      const ASource, AMessage, ADetail, ATaskId: string; APercent: Integer);
  public
    constructor Create(const ABus: IShellEventBus; ACapacity: Integer = 1000);
    destructor Destroy; override;
    // IShellStatusManager
    procedure Info(const ASource, AMessage: string);
    procedure Warning(const ASource, AMessage: string);
    procedure LogError(const ASource, AMessage, ADetail: string);
    procedure ShellError(const ASource, AMessage, ADetail: string);
    procedure Progress(const ATaskId, ASource: string; APercent: Integer; const AMessage: string);
    procedure TaskStart(const ATaskId, ASource, AMessage: string);
    procedure TaskFinish(const ATaskId, AMessage: string);
    procedure Diagnostic(const ASource, AMessage: string);
    function GetEntries: TArray<TShellStatusEntry>;
    procedure ClearEntries;
    procedure SetSanitizer(ASanitizer: TShellStatusSanitizer);
  end;

implementation

// ---------------------------------------------------------------------------
// TShellAreaController
// ---------------------------------------------------------------------------

constructor TShellAreaController.Create(APanel: TPanel; ASplitter: TSplitter;
  AExpandedHost: TWinControl; ACollapsedSummary: TLabel; const APanelId: string);
begin
  inherited Create;
  FPanel := APanel;
  FSplitter := ASplitter;
  FExpandedHost := AExpandedHost;
  FCollapsedSummary := ACollapsedSummary;
  FState := TShellPanelState.Make(APanelId);
  FState.Visible := True;
  FState.Collapsed := False;
  FState.Size := if FPanel <> nil then FPanel.Height else 0;
  FState.LastExpandedSize := FState.Size;
end;

procedure TShellAreaController.UpdateVisuals;
begin
  if FPanel = nil then
    Exit;

  FPanel.Visible := FState.Visible;
  if FSplitter <> nil then
    FSplitter.Visible := FState.Visible and (not FState.Collapsed);

  if not FState.Visible then
    Exit;

  if FState.Collapsed then
  begin
    if FExpandedHost <> nil then
      FExpandedHost.Visible := False;
    if FCollapsedSummary <> nil then
    begin
      FCollapsedSummary.Visible := True;
      FCollapsedSummary.Align := alClient;
    end;
    // Middle uses alClient and always fills remaining space; only hosts
    // visible state changes (host vs summary). Top / Bottom panels actually
    // shrink to a one-line summary band.
    if SameText(FState.PanelId, PANEL_TOP) then
      FPanel.Height := MIN_TOP_HEIGHT_COLLAPSED
    else if SameText(FState.PanelId, PANEL_BOTTOM) then
      FPanel.Height := MIN_BOTTOM_HEIGHT_COLLAPSED;
  end
  else
  begin
    if FCollapsedSummary <> nil then
      FCollapsedSummary.Visible := False;
    if FExpandedHost <> nil then
    begin
      FExpandedHost.Visible := True;
      FExpandedHost.Align := alClient;
    end;
    // Same reasoning as above: only Top / Bottom restore explicit Height.
    if (FState.LastExpandedSize > 0)
       and (not SameText(FState.PanelId, PANEL_MIDDLE)) then
      FPanel.Height := FState.LastExpandedSize;
  end;
end;

procedure TShellAreaController.SetCollapsed(AValue: Boolean);
begin
  if FState.Collapsed = AValue then
    Exit;

  // Middle panel is alClient and has no meaningful Height, so don't track
  // LastExpandedSize for it.
  if not SameText(FState.PanelId, PANEL_MIDDLE) then
  begin
    if (not AValue) and (FState.LastExpandedSize <= 0) then
      FState.LastExpandedSize := if SameText(FState.PanelId, PANEL_TOP)
        then DEFAULT_TOP_HEIGHT
        else DEFAULT_BOTTOM_HEIGHT;
    if AValue and (FPanel <> nil) then
      FState.LastExpandedSize := FPanel.Height;
  end;

  FState.Collapsed := AValue;
  UpdateVisuals;
end;

procedure TShellAreaController.ToggleCollapsed;
begin
  SetCollapsed(not FState.Collapsed);
end;

procedure TShellAreaController.SetVisible(AValue: Boolean);
begin
  if FState.Visible = AValue then
    Exit;
  FState.Visible := AValue;
  UpdateVisuals;
end;

procedure TShellAreaController.SetSize(AValue: Integer);
begin
  if AValue <= 0 then
    Exit;
  FState.Size := AValue;
  if not FState.Collapsed then
  begin
    FState.LastExpandedSize := AValue;
    if FPanel <> nil then
      FPanel.Height := AValue;
  end;
end;

function TShellAreaController.State: TShellPanelState;
begin
  if (FPanel <> nil) and (not FState.Collapsed) then
    FState.Size := FPanel.Height;
  Result := FState;
end;

procedure TShellAreaController.ApplyState(const AState: TShellPanelState);
begin
  FState := AState;
  if FState.LastExpandedSize <= 0 then
    FState.LastExpandedSize := FState.Size;
  if (FPanel <> nil) and (not FState.Collapsed) and (FState.Size > 0) then
    FPanel.Height := FState.Size;
  UpdateVisuals;
end;

procedure TShellAreaController.SetSummary(const AText: string);
begin
  if FCollapsedSummary <> nil then
    FCollapsedSummary.Caption := AText;
end;

// ---------------------------------------------------------------------------
// TShellStatusManager
// ---------------------------------------------------------------------------

constructor TShellStatusManager.Create(const ABus: IShellEventBus; ACapacity: Integer);
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FBus := ABus;
  FEntries := TList<TShellStatusEntry>.Create;
  FCapacity := if ACapacity > 0 then ACapacity else 1000;
end;

destructor TShellStatusManager.Destroy;
begin
  FBus := nil;
  FreeAndNil(FEntries);
  FreeAndNil(FLock);
  inherited;
end;

procedure TShellStatusManager.AddEntry(AKind: TShellStatusKind;
  const ASource, AMessage, ADetail, ATaskId: string; APercent: Integer);
var
  LEntry: TShellStatusEntry;
  LBusEvent: TDeepShellEvent;
  LEventKind: TDeepShellEventKind;
  LSanitized: string;
  LSanitizedDetail: string;
begin
  LSanitized := ApplySanitizer(ASource, AMessage);
  // Detail also goes through sanitizer; secrets are just as likely to appear
  // in stack traces / response bodies as in summary messages.
  if ADetail <> '' then
    LSanitizedDetail := ApplySanitizer(ASource, ADetail)
  else
    LSanitizedDetail := '';

  LEntry := Default(TShellStatusEntry);
  LEntry.Kind := AKind;
  LEntry.Source := ASource;
  LEntry.MessageText := LSanitized;
  LEntry.Detail := LSanitizedDetail;
  LEntry.TaskId := ATaskId;
  LEntry.PercentComplete := APercent;
  LEntry.Timestamp := Now;

  FLock.Enter;
  try
    FEntries.Add(LEntry);
    while FEntries.Count > FCapacity do
      FEntries.Delete(0);
  finally
    FLock.Leave;
  end;

  if FBus = nil then
    Exit;

  case AKind of
    sskProgress: LEventKind := sekTaskStarted;
  else
    LEventKind := sekLogAdded;
  end;

  LBusEvent := Default(TDeepShellEvent);
  LBusEvent.Kind := LEventKind;
  LBusEvent.MessageText := LSanitized;
  LBusEvent.Data := ATaskId;
  FBus.Publish(LBusEvent);
end;

function TShellStatusManager.ApplySanitizer(const ASource, AMessage: string): string;
var
  LSanitizer: TShellStatusSanitizer;
begin
  Result := AMessage;
  FLock.Enter;
  try
    LSanitizer := FSanitizer;
  finally
    FLock.Leave;
  end;
  if Assigned(LSanitizer) then
  try
    Result := LSanitizer(ASource, AMessage);
  except
    // Defensive: if sanitizer throws, fall back to raw message rather
    // than block logging entirely.
    Result := AMessage;
  end;
end;

procedure TShellStatusManager.SetSanitizer(ASanitizer: TShellStatusSanitizer);
begin
  FLock.Enter;
  try
    FSanitizer := ASanitizer;
  finally
    FLock.Leave;
  end;
end;

procedure TShellStatusManager.Info(const ASource, AMessage: string);
begin
  AddEntry(sskInfo, ASource, AMessage, '', '', 0);
end;

procedure TShellStatusManager.Warning(const ASource, AMessage: string);
begin
  AddEntry(sskWarning, ASource, AMessage, '', '', 0);
end;

procedure TShellStatusManager.ShellError(const ASource, AMessage, ADetail: string);
begin
  AddEntry(sskError, ASource, AMessage, ADetail, '', 0);
end;

procedure TShellStatusManager.LogError(const ASource, AMessage, ADetail: string);
begin
  // LogError is the recommended public name; ShellError stays as alias for
  // existing call sites.
  AddEntry(sskError, ASource, AMessage, ADetail, '', 0);
end;

procedure TShellStatusManager.Progress(const ATaskId, ASource: string;
  APercent: Integer; const AMessage: string);
begin
  AddEntry(sskProgress, ASource, AMessage, '', ATaskId, APercent);
end;

procedure TShellStatusManager.TaskStart(const ATaskId, ASource, AMessage: string);
var
  LEvent: TDeepShellEvent;
begin
  AddEntry(sskInfo, ASource, AMessage, '', ATaskId, 0);
  if FBus = nil then
    Exit;
  LEvent := Default(TDeepShellEvent);
  LEvent.Kind := sekTaskStarted;
  LEvent.MessageText := AMessage;
  LEvent.Data := ATaskId;
  FBus.Publish(LEvent);
end;

procedure TShellStatusManager.TaskFinish(const ATaskId, AMessage: string);
var
  LEvent: TDeepShellEvent;
begin
  AddEntry(sskInfo, '', AMessage, '', ATaskId, 100);
  if FBus = nil then
    Exit;
  LEvent := Default(TDeepShellEvent);
  LEvent.Kind := sekTaskFinished;
  LEvent.MessageText := AMessage;
  LEvent.Data := ATaskId;
  FBus.Publish(LEvent);
end;

procedure TShellStatusManager.Diagnostic(const ASource, AMessage: string);
begin
  AddEntry(sskDiagnostic, ASource, AMessage, '', '', 0);
end;

function TShellStatusManager.GetEntries: TArray<TShellStatusEntry>;
begin
  FLock.Enter;
  try
    Result := FEntries.ToArray;
  finally
    FLock.Leave;
  end;
end;

procedure TShellStatusManager.ClearEntries;
begin
  FLock.Enter;
  try
    FEntries.Clear;
  finally
    FLock.Leave;
  end;
end;

end.
