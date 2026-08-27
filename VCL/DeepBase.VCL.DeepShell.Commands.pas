{ ============================================================================
  DeepBase.VCL.DeepShell.Commands

  CommandManager + fluent ShellCommand builder.

  All menus, toolbar buttons, shortcuts and context menus must call
  IShellCommandManager.Execute. Execute consults the registered governance
  service before invoking the command handler.

  See docs/72.vcl.DeepShell-核心接口与服务契约.md §4
      docs/75.vcl.DeepShell-Command-Governance集成.md
  ============================================================================ }

unit DeepBase.VCL.DeepShell.Commands;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections,
  DeepBase.VCL.DeepShell.Types,
  DeepBase.VCL.DeepShell.Intf;

type
  /// <summary>
  /// Fluent builder for TShellCommand. Use <c>ShellCommand('id', 'caption')</c>
  /// to obtain a builder, chain configuration calls, then pass the result to
  /// <c>IShellCommandManager.RegisterCommand</c>.
  /// </summary>
  TShellCommandBuilder = record
  private
    FCmd: TShellCommand;
  public
    function Hint(const AHint: string): TShellCommandBuilder;
    function Category(const ACategory: string): TShellCommandBuilder;
    function Shortcut(const AShortcutText: string): TShellCommandBuilder;
    function CapabilityId(const ACapabilityId: string): TShellCommandBuilder;
    function GateKey(const AGateKey: string): TShellCommandBuilder;
    function PurposeKey(const APurposeKey: string): TShellCommandBuilder;
    function RiskLevel(ALevel: TShellRiskLevel): TShellCommandBuilder;
    function RequiresEvidence(AValue: Boolean = True): TShellCommandBuilder;
    function Visible(AValue: Boolean): TShellCommandBuilder;
    function Enabled(AValue: Boolean): TShellCommandBuilder;
    function Checked(AValue: Boolean): TShellCommandBuilder;
    function OnExecute(AHandler: TProc): TShellCommandBuilder;
    function Build: TShellCommand;
    class operator Implicit(const ABuilder: TShellCommandBuilder): TShellCommand;
  end;

/// <summary>
/// Start a fluent command builder. Pass the builder directly to
/// IShellCommandManager.RegisterCommand thanks to the implicit conversion.
/// </summary>
function ShellCommand(const AId, ACaption: string): TShellCommandBuilder;

type
  TShellCommandManager = class(TInterfacedObject, IShellCommandManager)
  private
    FLock: TCriticalSection;
    FCommands: TDictionary<string, TShellCommand>;
    /// <summary>
    /// Insertion-ordered list of command ids; lets downstream menus / palettes
    /// render commands in the order they were registered. TDictionary.Keys
    /// has no defined ordering.
    /// </summary>
    FOrderedIds: TList<string>;
    FBus: IShellEventBus;
    FGovernance: IGovernanceService;
    FContextResolver: TFunc<TShellContext>;
    function BuildContextJson(const ACommand: TShellCommand): string;
    procedure PublishExecuted(const ACommand: TShellCommand);
    procedure PublishRejected(const ACommand: TShellCommand;
      const AResult: TShellGateResult);
  public
    constructor Create(const ABus: IShellEventBus;
      AContextResolver: TFunc<TShellContext>);
    destructor Destroy; override;

    /// <summary>
    /// Wire up an optional governance service. Pass nil to clear.
    /// </summary>
    procedure SetGovernance(const AGovernance: IGovernanceService);

    // IShellCommandManager
    procedure RegisterCommand(const ACommand: TShellCommand);
    procedure UnregisterCommand(const ACommandId: string);
    procedure Execute(const ACommandId: string);
    procedure ExecuteSync(const ACommandId: string);
    procedure UpdateCommandState(const ACommandId: string; AEnabled, AVisible: Boolean);
    procedure UpdateCommandChecked(const ACommandId: string; AChecked: Boolean);
    function TryGetCommand(const ACommandId: string; out ACommand: TShellCommand): Boolean;
    function CommandIds: TArray<string>;
    procedure ExecuteOnMainThread(const ACommandId: string);
  end;

implementation

uses
  System.JSON;

// ---------------------------------------------------------------------------
// TShellCommandBuilder
// ---------------------------------------------------------------------------

function ShellCommand(const AId, ACaption: string): TShellCommandBuilder;
begin
  Result := Default(TShellCommandBuilder);
  Result.FCmd := TShellCommand.Make(AId, ACaption);
end;

function TShellCommandBuilder.Hint(const AHint: string): TShellCommandBuilder;
begin
  Result := Self;
  Result.FCmd.Hint := AHint;
end;

function TShellCommandBuilder.Category(const ACategory: string): TShellCommandBuilder;
begin
  Result := Self;
  Result.FCmd.Category := ACategory;
end;

function TShellCommandBuilder.Shortcut(const AShortcutText: string): TShellCommandBuilder;
begin
  Result := Self;
  Result.FCmd.ShortcutText := AShortcutText;
end;

function TShellCommandBuilder.CapabilityId(const ACapabilityId: string): TShellCommandBuilder;
begin
  Result := Self;
  Result.FCmd.CapabilityId := ACapabilityId;
end;

function TShellCommandBuilder.GateKey(const AGateKey: string): TShellCommandBuilder;
begin
  Result := Self;
  Result.FCmd.GateKey := AGateKey;
end;

function TShellCommandBuilder.PurposeKey(const APurposeKey: string): TShellCommandBuilder;
begin
  Result := Self;
  Result.FCmd.PurposeKey := APurposeKey;
end;

function TShellCommandBuilder.RiskLevel(ALevel: TShellRiskLevel): TShellCommandBuilder;
begin
  Result := Self;
  Result.FCmd.RiskLevel := ALevel;
end;

function TShellCommandBuilder.RequiresEvidence(AValue: Boolean): TShellCommandBuilder;
begin
  Result := Self;
  Result.FCmd.RequiresEvidence := AValue;
end;

function TShellCommandBuilder.Visible(AValue: Boolean): TShellCommandBuilder;
begin
  Result := Self;
  Result.FCmd.Visible := AValue;
end;

function TShellCommandBuilder.Enabled(AValue: Boolean): TShellCommandBuilder;
begin
  Result := Self;
  Result.FCmd.Enabled := AValue;
end;

function TShellCommandBuilder.Checked(AValue: Boolean): TShellCommandBuilder;
begin
  Result := Self;
  Result.FCmd.Checked := AValue;
end;

function TShellCommandBuilder.OnExecute(AHandler: TProc): TShellCommandBuilder;
begin
  Result := Self;
  Result.FCmd.Handler := AHandler;
end;

function TShellCommandBuilder.Build: TShellCommand;
begin
  Result := FCmd;
end;

class operator TShellCommandBuilder.Implicit(const ABuilder: TShellCommandBuilder): TShellCommand;
begin
  Result := ABuilder.FCmd;
end;

// ---------------------------------------------------------------------------
// TShellCommandManager
// ---------------------------------------------------------------------------

constructor TShellCommandManager.Create(const ABus: IShellEventBus;
  AContextResolver: TFunc<TShellContext>);
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FCommands := TDictionary<string, TShellCommand>.Create;
  FOrderedIds := TList<string>.Create;
  FBus := ABus;
  FContextResolver := AContextResolver;
  FGovernance := nil;
end;

destructor TShellCommandManager.Destroy;
begin
  FGovernance := nil;
  FBus := nil;
  FreeAndNil(FOrderedIds);
  FreeAndNil(FCommands);
  FreeAndNil(FLock);
  inherited;
end;

procedure TShellCommandManager.SetGovernance(const AGovernance: IGovernanceService);
begin
  FLock.Enter;
  try
    FGovernance := AGovernance;
  finally
    FLock.Leave;
  end;
end;

procedure TShellCommandManager.RegisterCommand(const ACommand: TShellCommand);
begin
  if ACommand.Id = '' then
    raise EArgumentException.Create('TShellCommandManager.RegisterCommand: empty command id');
  FLock.Enter;
  try
    if not FCommands.ContainsKey(ACommand.Id) then
      FOrderedIds.Add(ACommand.Id);
    FCommands.AddOrSetValue(ACommand.Id, ACommand);
  finally
    FLock.Leave;
  end;
end;

procedure TShellCommandManager.UnregisterCommand(const ACommandId: string);
var
  LIdx: Integer;
begin
  FLock.Enter;
  try
    if FCommands.ContainsKey(ACommandId) then
    begin
      FCommands.Remove(ACommandId);
      LIdx := FOrderedIds.IndexOf(ACommandId);
      if LIdx >= 0 then
        FOrderedIds.Delete(LIdx);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TShellCommandManager.UpdateCommandState(const ACommandId: string;
  AEnabled, AVisible: Boolean);
var
  LCmd: TShellCommand;
  LEvent: TDeepShellEvent;
begin
  FLock.Enter;
  try
    if FCommands.TryGetValue(ACommandId, LCmd) then
    begin
      LCmd.Enabled := AEnabled;
      LCmd.Visible := AVisible;
      FCommands[ACommandId] := LCmd;
    end;
  finally
    FLock.Leave;
  end;
  // Publish state-changed event so UI can update incrementally
  if FBus <> nil then
  begin
    LEvent := Default(TDeepShellEvent);
    LEvent.Kind := sekCommandStateChanged;
    LEvent.Data := ACommandId;
    FBus.Publish(LEvent);
  end;
end;

procedure TShellCommandManager.UpdateCommandChecked(const ACommandId: string;
  AChecked: Boolean);
var
  LCmd: TShellCommand;
begin
  FLock.Enter;
  try
    if FCommands.TryGetValue(ACommandId, LCmd) then
    begin
      LCmd.Checked := AChecked;
      FCommands[ACommandId] := LCmd;
    end;
  finally
    FLock.Leave;
  end;
end;

function TShellCommandManager.TryGetCommand(const ACommandId: string;
  out ACommand: TShellCommand): Boolean;
begin
  FLock.Enter;
  try
    Result := FCommands.TryGetValue(ACommandId, ACommand);
  finally
    FLock.Leave;
  end;
end;

function TShellCommandManager.CommandIds: TArray<string>;
begin
  FLock.Enter;
  try
    Result := FOrderedIds.ToArray;
  finally
    FLock.Leave;
  end;
end;

function TShellCommandManager.BuildContextJson(const ACommand: TShellCommand): string;
var
  LCtx: TShellContext;
  LRoot: TJSONObject;
begin
  if Assigned(FContextResolver) then
    LCtx := FContextResolver()
  else
    LCtx := TShellContext.Empty;

  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('project_id', LCtx.ProjectId);
    // PII protection: project_path on the local machine usually contains a
    // user name (e.g. C:\Users\alice\my-project). Default is to NOT include
    // it in governance evidence. Commands that explicitly require evidence
    // can still surface the path through their own purpose-specific fields
    // or a future RequiresEvidence-driven option.
    if ACommand.RequiresEvidence then
      LRoot.AddPair('project_path', LCtx.ProjectPath);
    LRoot.AddPair('object_id', LCtx.ObjectRef.Id);
    LRoot.AddPair('object_kind', LCtx.ObjectRef.Kind);
    LRoot.AddPair('provider_id', LCtx.ObjectRef.ProviderId);
    LRoot.AddPair('view_id', LCtx.ViewId);
    LRoot.AddPair('command_id', ACommand.Id);
    LRoot.AddPair('purpose_key', ACommand.PurposeKey);
    LRoot.AddPair('capability_id', ACommand.CapabilityId);
    LRoot.AddPair('risk_level', TJSONNumber.Create(ACommand.RiskLevel));
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

procedure TShellCommandManager.PublishExecuted(const ACommand: TShellCommand);
var
  LEvent: TDeepShellEvent;
begin
  if FBus = nil then
    Exit;
  LEvent := Default(TDeepShellEvent);
  LEvent.Kind := sekCommandExecuted;
  if Assigned(FContextResolver) then
    LEvent.Context := FContextResolver();
  LEvent.MessageText := ACommand.Id;
  LEvent.Data := ACommand.Caption;
  FBus.Publish(LEvent);
end;

procedure TShellCommandManager.PublishRejected(const ACommand: TShellCommand;
  const AResult: TShellGateResult);
var
  LEvent: TDeepShellEvent;
begin
  if FBus = nil then
    Exit;
  LEvent := Default(TDeepShellEvent);
  LEvent.Kind := sekCommandRejected;
  if Assigned(FContextResolver) then
    LEvent.Context := FContextResolver();
  LEvent.MessageText := ACommand.Id;
  LEvent.Data := AResult.MessageText;
  FBus.Publish(LEvent);
end;

procedure TShellCommandManager.Execute(const ACommandId: string);
begin
  // Commands frequently touch UI (menus / status bar / dialogs). Force
  // execution to the main thread so background-thread callers cannot
  // accidentally drive UI from a worker. Using TThread.Queue (async)
  // rather than Synchronize avoids deadlock if the main thread is itself
  // waiting on something. Use ExecuteSync if you need to block until the
  // handler has finished.
  if TThread.CurrentThread.ThreadID = MainThreadID then
    ExecuteOnMainThread(ACommandId)
  else
  begin
    var LCapturedId := ACommandId;
    var LSelfRef: IShellCommandManager := Self;
    TThread.Queue(nil,
      procedure
      begin
        if LSelfRef <> nil then
          (LSelfRef as TShellCommandManager).ExecuteOnMainThread(LCapturedId);
      end);
  end;
end;

procedure TShellCommandManager.ExecuteSync(const ACommandId: string);
begin
  // Synchronous variant: always blocks until the handler finished on the
  // main thread. Caller is responsible for avoiding deadlock (don't call
  // from main thread while holding a lock that the handler also takes).
  if TThread.CurrentThread.ThreadID = MainThreadID then
    ExecuteOnMainThread(ACommandId)
  else
  begin
    var LCapturedId := ACommandId;
    var LSelfRef: IShellCommandManager := Self;
    TThread.Synchronize(nil,
      procedure
      begin
        if LSelfRef <> nil then
          (LSelfRef as TShellCommandManager).ExecuteOnMainThread(LCapturedId);
      end);
  end;
end;

procedure TShellCommandManager.ExecuteOnMainThread(const ACommandId: string);
var
  LCmd: TShellCommand;
  LGov: IGovernanceService;
  LResult: TShellGateResult;
  LContextJson: string;
  LCallOk: Boolean;
begin
  if not TryGetCommand(ACommandId, LCmd) then
    raise EArgumentException.CreateFmt(
      'TShellCommandManager.Execute: command "%s" is not registered', [ACommandId]);

  if not LCmd.Enabled then
    Exit;

  FLock.Enter;
  try
    LGov := FGovernance;
  finally
    FLock.Leave;
  end;

  // Governance evaluation. A command is only allowed if EnterGate returns
  // True AND LResult.Allowed is True. Adapters that confuse "function
  // returned" with "gate allowed" are caught here; we never run the handler
  // unless both signals say allow.
  if (LCmd.GateKey <> '') and (LGov <> nil) and LGov.IsEnabled then
  begin
    LContextJson := BuildContextJson(LCmd);
    LResult := TShellGateResult.AllowedDefault;
    try
      LCallOk := LGov.EnterGate(LCmd.GateKey, LContextJson, LResult);
    except
      // A throwing governance adapter is treated as soft denial.
      on E: Exception do
      begin
        LCallOk := False;
        LResult := TShellGateResult.Deny(sgoDeniedSoft,
          'gate.exception', E.Message);
      end;
    end;
    if (not LCallOk) or (not LResult.Allowed) then
    begin
      if LResult.MessageText = '' then
      begin
        if LCallOk then
          LResult.MessageText := 'Gate denied access'
        else
          LResult.MessageText := 'Gate call failed';
      end;
      PublishRejected(LCmd, LResult);
      Exit;
    end;
  end;

  if Assigned(LCmd.Handler) then
  begin
    try
      LCmd.Handler();
    except
      on E: Exception do
      begin
        PublishRejected(LCmd,
          TShellGateResult.Deny(sgoDeniedSoft, 'handler.exception', E.Message));
        raise;
      end;
    end;
  end;

  PublishExecuted(LCmd);
end;

end.
