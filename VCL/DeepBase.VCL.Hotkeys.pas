{ ============================================================================
  DeepBase.VCL.Hotkeys - VCL Hotkey Binding Adapter

  Version: 1.0
  Description: Bridges DeepBase.Hotkeys action-based shortcuts to VCL controls
               (TCustomAction, TMenuItem, TButton) without introducing UI
               dependencies into Core.
  ============================================================================ }

unit DeepBase.VCL.Hotkeys;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Vcl.ActnList,
  Vcl.Menus,
  Vcl.StdCtrls,
  DeepBase.Hotkeys;

type
  TDeepBaseVCLHotkeyBinding = class
  public
    ActionName: string;
    Scope: THotkeyScope;
    Action: TCustomAction;
    MenuItem: TMenuItem;
    Button: TButton;
    procedure ApplyShortcut(Shortcut: TShortCut);
    function Execute: Boolean;
  end;

  TDeepBaseVCLHotkeyBinder = class
  private
    FHotkeys: TDeepBaseHotkeys;
    FLock: TObject;
    FBindings: TObjectDictionary<string, TDeepBaseVCLHotkeyBinding>;
    FForwardOnHotkeyChanged: THotkeyChangedProc;
    FHooked: Boolean;
    function RequireHotkeys: TDeepBaseHotkeys;
    function EnsureBinding(const ActionName: string): TDeepBaseVCLHotkeyBinding;
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

{ TDeepBaseVCLHotkeyBinding }

procedure TDeepBaseVCLHotkeyBinding.ApplyShortcut(Shortcut: TShortCut);
begin
  if Assigned(Action) then
    Action.ShortCut := Shortcut;
  if Assigned(MenuItem) then
    MenuItem.ShortCut := Shortcut;
end;

function TDeepBaseVCLHotkeyBinding.Execute: Boolean;
begin
  if Assigned(Action) then
    Exit(Action.Execute);

  if Assigned(MenuItem) then
  begin
    if Assigned(MenuItem.Action) then
      Exit(MenuItem.Action.Execute);
    MenuItem.Click;
    Exit(True);
  end;

  if Assigned(Button) then
  begin
    Button.Click;
    Exit(True);
  end;

  Result := False;
end;

{ TDeepBaseVCLHotkeyBinder }

constructor TDeepBaseVCLHotkeyBinder.Create(const AHotkeys: TDeepBaseHotkeys);
begin
  inherited Create;
  FHotkeys := AHotkeys;
  FLock := TObject.Create;
  FBindings := TObjectDictionary<string, TDeepBaseVCLHotkeyBinding>.Create([doOwnsValues]);
  FHooked := False;
  FForwardOnHotkeyChanged := nil;
end;

destructor TDeepBaseVCLHotkeyBinder.Destroy;
begin
  UnhookHotkeyChanges;
  Clear;
  FBindings.Free;
  FLock.Free;
  inherited;
end;

function TDeepBaseVCLHotkeyBinder.RequireHotkeys: TDeepBaseHotkeys;
begin
  Result := FHotkeys;
  if not Assigned(Result) then
    raise EInvalidOp.Create('Hotkeys manager is required.');
end;

function TDeepBaseVCLHotkeyBinder.EnsureBinding(
  const ActionName: string): TDeepBaseVCLHotkeyBinding;
begin
  if not FBindings.TryGetValue(ActionName, Result) then
  begin
    Result := TDeepBaseVCLHotkeyBinding.Create;
    Result.ActionName := ActionName;
    Result.Scope := hsApplication;
    FBindings.Add(ActionName, Result);
  end;
end;

procedure TDeepBaseVCLHotkeyBinder.BindAction(const ActionName: string;
  AAction: TCustomAction; Scope: THotkeyScope);
var
  Binding: TDeepBaseVCLHotkeyBinding;
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

procedure TDeepBaseVCLHotkeyBinder.BindMenuItem(const ActionName: string;
  AMenuItem: TMenuItem; Scope: THotkeyScope);
var
  Binding: TDeepBaseVCLHotkeyBinding;
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

procedure TDeepBaseVCLHotkeyBinder.BindButton(const ActionName: string;
  AButton: TButton; Scope: THotkeyScope);
var
  Binding: TDeepBaseVCLHotkeyBinding;
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

procedure TDeepBaseVCLHotkeyBinder.Unbind(const ActionName: string);
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

procedure TDeepBaseVCLHotkeyBinder.Clear;
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

procedure TDeepBaseVCLHotkeyBinder.ExecuteBoundAction(const ActionName: string);
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
  begin
    if Assigned(MenuRef.Action) then
      Executed := MenuRef.Action.Execute
    else
    begin
      MenuRef.Click;
      Executed := True;
    end;
  end
  else if Assigned(ButtonRef) then
  begin
    ButtonRef.Click;
    Executed := True;
  end;

  if not Executed then
    Exit;
end;

procedure TDeepBaseVCLHotkeyBinder.ApplyBindingShortcut(const ActionName: string);
var
  Binding: TDeepBaseVCLHotkeyBinding;
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

procedure TDeepBaseVCLHotkeyBinder.RefreshBindings;
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

procedure TDeepBaseVCLHotkeyBinder.HandleHotkeyChanged(const ActionName: string);
begin
  ApplyBindingShortcut(ActionName);

  if Assigned(FForwardOnHotkeyChanged) then
    FForwardOnHotkeyChanged(ActionName);
end;

procedure TDeepBaseVCLHotkeyBinder.HookHotkeyChanges;
begin
  if FHooked or not Assigned(FHotkeys) then
    Exit;

  FForwardOnHotkeyChanged := FHotkeys.OnHotkeyChanged;
  FHotkeys.OnHotkeyChanged := HandleHotkeyChanged;
  FHooked := True;
end;

procedure TDeepBaseVCLHotkeyBinder.UnhookHotkeyChanges;
begin
  if (not FHooked) or (not Assigned(FHotkeys)) then
    Exit;

  FHotkeys.OnHotkeyChanged := FForwardOnHotkeyChanged;
  FForwardOnHotkeyChanged := nil;
  FHooked := False;
end;

function TDeepBaseVCLHotkeyBinder.TriggerShortcut(Shortcut: TShortCut;
  Scope: THotkeyScope): Boolean;
begin
  Result := Assigned(FHotkeys) and FHotkeys.TriggerShortcut(Shortcut, Scope);
end;

function TDeepBaseVCLHotkeyBinder.HandleKeyDown(var Key: Word;
  Shift: TShiftState; Scope: THotkeyScope): Boolean;
var
  LShortcut: TShortCut;
begin
  Result := False;
  if Key = 0 then
    Exit;

  LShortcut := Vcl.Menus.ShortCut(Key, Shift);
  if LShortcut = 0 then
    Exit;

  Result := TriggerShortcut(LShortcut, Scope);
  if Result then
    Key := 0;
end;

end.
