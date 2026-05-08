{ ============================================================================
  DeepBase.FMX.Hotkeys - FMX Hotkey Binding Adapter

  Version: 1.0
  Description: Bridges DeepBase.Hotkeys action-based shortcuts to FMX controls
               (TCustomAction, TMenuItem, TButton) without introducing UI
               dependencies into Core.
  ============================================================================ }

unit DeepBase.FMX.Hotkeys;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
  System.UITypes,
  System.Generics.Collections,
  FMX.Types,
  FMX.ActnList,
  FMX.Menus,
  FMX.StdCtrls,
  DeepBase.Hotkeys;

type
  TDeepBaseFMXHotkeyBinding = class
  private
    class function TrySetShortcutProperty(AInstance: TObject;
      Shortcut: TShortCut): Boolean; static;
    class function TryExecuteMenuItem(AMenuItem: TMenuItem): Boolean; static;
    class function TryExecuteButton(AButton: TButton): Boolean; static;
  public
    ActionName: string;
    Scope: THotkeyScope;
    Action: TCustomAction;
    MenuItem: TMenuItem;
    Button: TButton;
    procedure ApplyShortcut(Shortcut: TShortCut);
    function Execute: Boolean;
  end;

  TDeepBaseFMXHotkeyBinder = class
  private
    FHotkeys: TDeepBaseHotkeys;
    FLock: TObject;
    FBindings: TObjectDictionary<string, TDeepBaseFMXHotkeyBinding>;
    FForwardOnHotkeyChanged: THotkeyChangedProc;
    FHooked: Boolean;
    function RequireHotkeys: TDeepBaseHotkeys;
    function EnsureBinding(const ActionName: string): TDeepBaseFMXHotkeyBinding;
    procedure ExecuteBoundAction(const ActionName: string);
    procedure ApplyBindingShortcut(const ActionName: string);
    procedure HandleHotkeyChanged(const ActionName: string);
  public
    constructor Create(const AHotkeys: TDeepBaseHotkeys);
    destructor Destroy; override;
    procedure BindAction(const ActionName: string; AAction: TCustomAction;
      Scope: THotkeyScope = hsApplication);
    procedure BindMenuItem(const ActionName: string; AMenuItem: TMenuItem;
      Scope: THotkeyScope = hsApplication);
    procedure BindButton(const ActionName: string; AButton: TButton;
      Scope: THotkeyScope = hsApplication);
    procedure Unbind(const ActionName: string);
    procedure Clear;
    procedure RefreshBindings;
    procedure HookHotkeyChanges;
    procedure UnhookHotkeyChanges;
    function TriggerShortcut(Shortcut: TShortCut;
      Scope: THotkeyScope = hsApplication): Boolean;
    function HandleKeyDown(var Key: Word; Shift: TShiftState;
      Scope: THotkeyScope = hsApplication): Boolean;
  end;

implementation

{ TDeepBaseFMXHotkeyBinding }

class function TDeepBaseFMXHotkeyBinding.TrySetShortcutProperty(
  AInstance: TObject; Shortcut: TShortCut): Boolean;
var
  Ctx: TRttiContext;
  RType: TRttiType;
  Prop: TRttiProperty;
begin
  Result := False;
  if AInstance = nil then
    Exit;

  Ctx := TRttiContext.Create;
  try
    RType := Ctx.GetType(AInstance.ClassType);
    if RType = nil then
      Exit;

    Prop := RType.GetProperty('ShortCut');
    if (Prop = nil) or (not Prop.IsWritable) then
      Exit;

    case Prop.PropertyType.TypeKind of
      tkInteger:
        Prop.SetValue(AInstance, TValue.From<Integer>(Integer(Shortcut)));
      tkInt64:
        Prop.SetValue(AInstance, TValue.From<Int64>(Int64(Shortcut)));
    else
      Exit;
    end;

    Result := True;
  finally
    Ctx.Free;
  end;
end;

class function TDeepBaseFMXHotkeyBinding.TryExecuteMenuItem(
  AMenuItem: TMenuItem): Boolean;
var
  ClickHandler: TNotifyEvent;
begin
  Result := False;
  if AMenuItem = nil then
    Exit;

  if Assigned(AMenuItem.Action) then
    Exit(AMenuItem.Action.Execute);

  ClickHandler := AMenuItem.OnClick;
  if Assigned(ClickHandler) then
  begin
    ClickHandler(AMenuItem);
    Result := True;
  end;
end;

class function TDeepBaseFMXHotkeyBinding.TryExecuteButton(
  AButton: TButton): Boolean;
var
  ClickHandler: TNotifyEvent;
begin
  Result := False;
  if AButton = nil then
    Exit;

  if Assigned(AButton.Action) then
    Exit(AButton.Action.Execute);

  ClickHandler := AButton.OnClick;
  if Assigned(ClickHandler) then
  begin
    ClickHandler(AButton);
    Result := True;
  end;
end;

procedure TDeepBaseFMXHotkeyBinding.ApplyShortcut(Shortcut: TShortCut);
begin
  TrySetShortcutProperty(Action, Shortcut);
  TrySetShortcutProperty(MenuItem, Shortcut);
end;

function TDeepBaseFMXHotkeyBinding.Execute: Boolean;
begin
  if Assigned(Action) then
    Exit(Action.Execute);

  if Assigned(MenuItem) then
    Exit(TryExecuteMenuItem(MenuItem));

  if Assigned(Button) then
    Exit(TryExecuteButton(Button));

  Result := False;
end;

{ TDeepBaseFMXHotkeyBinder }

constructor TDeepBaseFMXHotkeyBinder.Create(const AHotkeys: TDeepBaseHotkeys);
begin
  inherited Create;
  FHotkeys := AHotkeys;
  FLock := TObject.Create;
  FBindings := TObjectDictionary<string, TDeepBaseFMXHotkeyBinding>.Create([doOwnsValues]);
  FHooked := False;
  FForwardOnHotkeyChanged := nil;
end;

destructor TDeepBaseFMXHotkeyBinder.Destroy;
begin
  UnhookHotkeyChanges;
  Clear;
  FBindings.Free;
  FLock.Free;
  inherited;
end;

function TDeepBaseFMXHotkeyBinder.RequireHotkeys: TDeepBaseHotkeys;
begin
  Result := FHotkeys;
  if not Assigned(Result) then
    raise EInvalidOp.Create('Hotkeys manager is required.');
end;

function TDeepBaseFMXHotkeyBinder.EnsureBinding(
  const ActionName: string): TDeepBaseFMXHotkeyBinding;
begin
  if not FBindings.TryGetValue(ActionName, Result) then
  begin
    Result := TDeepBaseFMXHotkeyBinding.Create;
    Result.ActionName := ActionName;
    Result.Scope := hsApplication;
    FBindings.Add(ActionName, Result);
  end;
end;

procedure TDeepBaseFMXHotkeyBinder.BindAction(const ActionName: string;
  AAction: TCustomAction; Scope: THotkeyScope);
var
  Binding: TDeepBaseFMXHotkeyBinding;
begin
  if (ActionName = '') or (AAction = nil) then
    Exit;

  TMonitor.Enter(FLock);
  try
    Binding := EnsureBinding(ActionName);
    Binding.Action := AAction;
    Binding.Scope := Scope;
  finally
    TMonitor.Exit(FLock);
  end;

  RequireHotkeys.SetHotkeyScope(ActionName, Scope);
  RequireHotkeys.BindAction(ActionName, ExecuteBoundAction);
  ApplyBindingShortcut(ActionName);
end;

procedure TDeepBaseFMXHotkeyBinder.BindMenuItem(const ActionName: string;
  AMenuItem: TMenuItem; Scope: THotkeyScope);
var
  Binding: TDeepBaseFMXHotkeyBinding;
begin
  if (ActionName = '') or (AMenuItem = nil) then
    Exit;

  TMonitor.Enter(FLock);
  try
    Binding := EnsureBinding(ActionName);
    Binding.MenuItem := AMenuItem;
    Binding.Scope := Scope;
  finally
    TMonitor.Exit(FLock);
  end;

  RequireHotkeys.SetHotkeyScope(ActionName, Scope);
  RequireHotkeys.BindAction(ActionName, ExecuteBoundAction);
  ApplyBindingShortcut(ActionName);
end;

procedure TDeepBaseFMXHotkeyBinder.BindButton(const ActionName: string;
  AButton: TButton; Scope: THotkeyScope);
var
  Binding: TDeepBaseFMXHotkeyBinding;
begin
  if (ActionName = '') or (AButton = nil) then
    Exit;

  TMonitor.Enter(FLock);
  try
    Binding := EnsureBinding(ActionName);
    Binding.Button := AButton;
    Binding.Scope := Scope;
  finally
    TMonitor.Exit(FLock);
  end;

  RequireHotkeys.SetHotkeyScope(ActionName, Scope);
  RequireHotkeys.BindAction(ActionName, ExecuteBoundAction);
end;

procedure TDeepBaseFMXHotkeyBinder.Unbind(const ActionName: string);
begin
  if ActionName = '' then
    Exit;

  TMonitor.Enter(FLock);
  try
    FBindings.Remove(ActionName);
  finally
    TMonitor.Exit(FLock);
  end;

  if Assigned(FHotkeys) then
    FHotkeys.UnbindAction(ActionName);
end;

procedure TDeepBaseFMXHotkeyBinder.Clear;
var
  Keys: TArray<string>;
  ActionName: string;
begin
  TMonitor.Enter(FLock);
  try
    Keys := FBindings.Keys.ToArray;
    FBindings.Clear;
  finally
    TMonitor.Exit(FLock);
  end;

  if not Assigned(FHotkeys) then
    Exit;

  for ActionName in Keys do
    FHotkeys.UnbindAction(ActionName);
end;

procedure TDeepBaseFMXHotkeyBinder.ExecuteBoundAction(const ActionName: string);
var
  ActionRef: TCustomAction;
  MenuRef: TMenuItem;
  ButtonRef: TButton;
  Executed: Boolean;
begin
  ActionRef := nil;
  MenuRef := nil;
  ButtonRef := nil;
  Executed := False;

  TMonitor.Enter(FLock);
  try
    if FBindings.ContainsKey(ActionName) then
    begin
      ActionRef := FBindings[ActionName].Action;
      MenuRef := FBindings[ActionName].MenuItem;
      ButtonRef := FBindings[ActionName].Button;
    end;
  finally
    TMonitor.Exit(FLock);
  end;

  if Assigned(ActionRef) then
    Executed := ActionRef.Execute
  else if Assigned(MenuRef) then
    Executed := TDeepBaseFMXHotkeyBinding.TryExecuteMenuItem(MenuRef)
  else if Assigned(ButtonRef) then
    Executed := TDeepBaseFMXHotkeyBinding.TryExecuteButton(ButtonRef);

  if not Executed then
    Exit;
end;

procedure TDeepBaseFMXHotkeyBinder.ApplyBindingShortcut(const ActionName: string);
var
  Binding: TDeepBaseFMXHotkeyBinding;
  Shortcut: TShortCut;
begin
  if not Assigned(FHotkeys) then
    Exit;

  Shortcut := FHotkeys.GetHotkey(ActionName);

  TMonitor.Enter(FLock);
  try
    if FBindings.TryGetValue(ActionName, Binding) then
      Binding.ApplyShortcut(Shortcut);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TDeepBaseFMXHotkeyBinder.RefreshBindings;
var
  ActionNames: TArray<string>;
  ActionName: string;
begin
  TMonitor.Enter(FLock);
  try
    ActionNames := FBindings.Keys.ToArray;
  finally
    TMonitor.Exit(FLock);
  end;

  for ActionName in ActionNames do
    ApplyBindingShortcut(ActionName);
end;

procedure TDeepBaseFMXHotkeyBinder.HandleHotkeyChanged(const ActionName: string);
begin
  ApplyBindingShortcut(ActionName);

  if Assigned(FForwardOnHotkeyChanged) then
    FForwardOnHotkeyChanged(ActionName);
end;

procedure TDeepBaseFMXHotkeyBinder.HookHotkeyChanges;
begin
  if FHooked or not Assigned(FHotkeys) then
    Exit;

  FForwardOnHotkeyChanged := FHotkeys.OnHotkeyChanged;
  FHotkeys.OnHotkeyChanged := HandleHotkeyChanged;
  FHooked := True;
end;

procedure TDeepBaseFMXHotkeyBinder.UnhookHotkeyChanges;
begin
  if (not FHooked) or (not Assigned(FHotkeys)) then
    Exit;

  FHotkeys.OnHotkeyChanged := FForwardOnHotkeyChanged;
  FForwardOnHotkeyChanged := nil;
  FHooked := False;
end;

function TDeepBaseFMXHotkeyBinder.TriggerShortcut(Shortcut: TShortCut;
  Scope: THotkeyScope): Boolean;
begin
  Result := Assigned(FHotkeys) and FHotkeys.TriggerShortcut(Shortcut, Scope);
end;

function TDeepBaseFMXHotkeyBinder.HandleKeyDown(var Key: Word;
  Shift: TShiftState; Scope: THotkeyScope): Boolean;
var
  LShortcut: TShortCut;
begin
  Result := False;
  if Key = 0 then
    Exit;

  if Key in [vkShift, vkControl, vkMenu] then
    Exit;

  LShortcut := Key;
  if ssCtrl in Shift then
    LShortcut := LShortcut or scCtrl;
  if ssShift in Shift then
    LShortcut := LShortcut or scShift;
  if ssAlt in Shift then
    LShortcut := LShortcut or scAlt;

  if LShortcut = 0 then
    Exit;

  Result := TriggerShortcut(LShortcut, Scope);
  if Result then
    Key := 0;
end;

end.
