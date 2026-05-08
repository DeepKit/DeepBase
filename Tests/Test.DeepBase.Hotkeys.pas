unit Test.DeepBase.Hotkeys;

{*******************************************************************************
  DeepBase Hotkeys 模块单元测试
  
  测试内容:
  - GetHotkey / SetHotkey
  - RegisterDefaultHotkeys
  - ResetHotkey / ResetAllHotkeys
  - CheckHotkeyConflict
*******************************************************************************}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils, System.Classes,
  System.Generics.Collections,
  Winapi.Windows,
  Winapi.Messages,
  Vcl.ActnList,
  Vcl.Menus,
  Vcl.StdCtrls,
  DeepBase.Types, DeepBase.Manager, DeepBase.Hotkeys, DeepBase.Storage.Interfaces,
  DeepBase.VCL.Hotkeys, DeepBase.Hotkeys.Exchange;

type
  [TestFixture]
  TTestDeepBaseHotkeys = class
  private
    FHotkeys: TDeepBaseHotkeys;
    FManager: TDeepBaseManager;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_SetGetHotkey_Basic;
    
    [Test]
    procedure Test_GetHotkey_NotExists_ReturnsZero;
    
    [Test]
    procedure Test_SetHotkey_OverwritesExisting;
    
    [Test]
    procedure Test_RegisterDefaultHotkeys;
    
    [Test]
    procedure Test_ResetHotkey_ToDefault;
    
    [Test]
    procedure Test_ResetAllHotkeys;
    
    [Test]
    procedure Test_CheckHotkeyConflict_NoConflict;
    
    [Test]
    procedure Test_CheckHotkeyConflict_HasConflict;
    
    [Test]
    procedure Test_GetAllHotkeys;
    
    [Test]
    procedure Test_DeleteHotkey;
    
    [Test]
    procedure Test_HotkeyToText;
    
    [Test]
    procedure Test_TextToHotkey;
    
    [Test]
    procedure Test_OnHotkeyChanged_Event;

    [Test]
    procedure Test_Scope_Default_IsApplication;

    [Test]
    procedure Test_CheckHotkeyConflictInScope_DifferentScopes_NoConflict;

    [Test]
    procedure Test_CheckHotkeyConflictInScope_SameScope_HasConflict;

    [Test]
    procedure Test_TriggerShortcut_ExecutesBoundActionByScope;

    [Test]
    procedure Test_TriggerShortcut_WithoutBinding_ReturnsFalse;

    [Test]
    procedure Test_StorageInjection_BasicLifecycle;
  end;

  [TestFixture]
  TTestDeepBaseGlobalHotkeys = class
  public
    [Test]
    procedure Test_Register_Unregister_Basic;

    [Test]
    procedure Test_Register_DuplicateId_IsRejected;

    [Test]
    procedure Test_Register_InvalidShortcut_IsRejected;

    [Test]
    procedure Test_Register_PlatformFailure_IsHandled;

    [Test]
    procedure Test_DispatchMessage_WMHotKey;

    [Test]
    procedure Test_UnregisterAll_ClearsRegistrations;
  end;

  [TestFixture]
  TTestDeepBaseVCLHotkeyBinder = class
  public
    [Test]
    procedure Test_BindAction_AppliesShortcut_AndTriggersExecute;

    [Test]
    procedure Test_BindMenuItem_AppliesShortcut_AndTriggersClick;

    [Test]
    procedure Test_HandleKeyDown_RespectsScope;

    [Test]
    procedure Test_Unbind_DisablesBoundTrigger;

    [Test]
    procedure Test_HookHotkeyChanges_UpdatesControlShortcut;
  end;

  [TestFixture]
  TTestDeepBaseHotkeyExchange = class
  public
    [Test]
    procedure Test_ExportImportJson_RoundTrip;

    [Test]
    procedure Test_ImportFromJson_ConflictPolicy;
  end;

implementation

type
  TMockGlobalHotkeyPlatform = class(TInterfacedObject, IDeepBaseGlobalHotkeyPlatform)
  private
    FFailOnId: Integer;
    FRegistered: TDictionary<Integer, UINT>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure SetFailOnId(AHotkeyId: Integer);
    function RegisterHotKey(const AHandle: HWND; const AHotkeyId: Integer;
      const AModifiers, AVirtualKey: UINT): Boolean;
    function UnregisterHotKey(const AHandle: HWND;
      const AHotkeyId: Integer): Boolean;
  end;

  TInMemoryHotkeyStorage = class(TInterfacedObject, IHotkeyStorage)
  private
    FData: TDictionary<string, THotkeyStorageData>;
  public
    constructor Create;
    destructor Destroy; override;
    function ReadEnabledHotkeys: THotkeyStorageDataArray;
    procedure RegisterDefaults(const Defaults: THotkeyStorageDataArray);
    procedure UpdateShortcut(const ActionName: string; Shortcut: Word;
      IsCustomized: Boolean);
    procedure ResetShortcut(const ActionName: string);
    procedure ResetAllShortcuts;
    function ReadAllHotkeys: THotkeyStorageDataArray;
    procedure DeleteHotkey(const ActionName: string);
  end;

  TNotifyProbe = class
  public
    Fired: Boolean;
    procedure HandleNotify(Sender: TObject);
  end;

constructor TMockGlobalHotkeyPlatform.Create;
begin
  inherited Create;
  FFailOnId := -1;
  FRegistered := TDictionary<Integer, UINT>.Create;
end;

destructor TMockGlobalHotkeyPlatform.Destroy;
begin
  FRegistered.Free;
  inherited;
end;

procedure TMockGlobalHotkeyPlatform.SetFailOnId(AHotkeyId: Integer);
begin
  FFailOnId := AHotkeyId;
end;

function TMockGlobalHotkeyPlatform.RegisterHotKey(const AHandle: HWND;
  const AHotkeyId: Integer; const AModifiers, AVirtualKey: UINT): Boolean;
begin
  if AHotkeyId = FFailOnId then
    Exit(False);

  if FRegistered.ContainsKey(AHotkeyId) then
    Exit(False);

  FRegistered.Add(AHotkeyId, AModifiers or (AVirtualKey shl 16));
  Result := True;
end;

function TMockGlobalHotkeyPlatform.UnregisterHotKey(const AHandle: HWND;
  const AHotkeyId: Integer): Boolean;
begin
  Result := FRegistered.ContainsKey(AHotkeyId);
  if Result then
    FRegistered.Remove(AHotkeyId);
end;

constructor TInMemoryHotkeyStorage.Create;
begin
  inherited Create;
  FData := TDictionary<string, THotkeyStorageData>.Create;
end;

destructor TInMemoryHotkeyStorage.Destroy;
begin
  FData.Free;
  inherited;
end;

function TInMemoryHotkeyStorage.ReadEnabledHotkeys: THotkeyStorageDataArray;
var
  Pair: TPair<string, THotkeyStorageData>;
begin
  SetLength(Result, 0);
  for Pair in FData do
    if Pair.Value.IsEnabled then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := Pair.Value;
    end;
end;

procedure TInMemoryHotkeyStorage.RegisterDefaults(
  const Defaults: THotkeyStorageDataArray);
var
  Item: THotkeyStorageData;
begin
  for Item in Defaults do
    if not FData.ContainsKey(Item.ActionName) then
      FData.Add(Item.ActionName, Item);
end;

procedure TInMemoryHotkeyStorage.UpdateShortcut(const ActionName: string;
  Shortcut: Word; IsCustomized: Boolean);
var
  Data: THotkeyStorageData;
begin
  if FData.TryGetValue(ActionName, Data) then
  begin
    Data.Shortcut := Shortcut;
    Data.IsCustomized := IsCustomized;
    FData.AddOrSetValue(ActionName, Data);
  end;
end;

procedure TInMemoryHotkeyStorage.ResetShortcut(const ActionName: string);
var
  Data: THotkeyStorageData;
begin
  if FData.TryGetValue(ActionName, Data) then
  begin
    Data.Shortcut := Data.DefaultShortcut;
    Data.IsCustomized := False;
    FData.AddOrSetValue(ActionName, Data);
  end;
end;

procedure TInMemoryHotkeyStorage.ResetAllShortcuts;
var
  Pair: TPair<string, THotkeyStorageData>;
  Data: THotkeyStorageData;
begin
  for Pair in FData do
  begin
    Data := Pair.Value;
    Data.Shortcut := Data.DefaultShortcut;
    Data.IsCustomized := False;
    FData.AddOrSetValue(Pair.Key, Data);
  end;
end;

function TInMemoryHotkeyStorage.ReadAllHotkeys: THotkeyStorageDataArray;
var
  Pair: TPair<string, THotkeyStorageData>;
begin
  SetLength(Result, 0);
  for Pair in FData do
  begin
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := Pair.Value;
  end;
end;

procedure TInMemoryHotkeyStorage.DeleteHotkey(const ActionName: string);
begin
  FData.Remove(ActionName);
end;

procedure TNotifyProbe.HandleNotify(Sender: TObject);
begin
  Fired := True;
end;

{ TTestDeepBaseHotkeys }

procedure TTestDeepBaseHotkeys.Setup;
begin
  FManager := DeepBase.Manager.DeepBase;
  if not FManager.IsInitialized then
    FManager.InitializeWithDB(':memory:');
  FHotkeys := FManager.Hotkeys;
end;

procedure TTestDeepBaseHotkeys.TearDown;
begin
  FHotkeys := nil;
end;

procedure TTestDeepBaseHotkeys.Test_SetGetHotkey_Basic;
var
  Action: string;
  Shortcut: TShortCut;
  Retrieved: TShortCut;
begin
  Action := 'test.action.save';
  Shortcut := TextToShortCut('Ctrl+S');
  
  FHotkeys.SetHotkey(Action, Shortcut);
  Retrieved := FHotkeys.GetHotkey(Action);
  
  Assert.AreEqual(Shortcut, Retrieved, '快捷键应该正确保存和读取');
end;

procedure TTestDeepBaseHotkeys.Test_GetHotkey_NotExists_ReturnsZero;
var
  Retrieved: TShortCut;
begin
  Retrieved := FHotkeys.GetHotkey('nonexistent.action.' + TGUID.NewGuid.ToString);
  
  Assert.AreEqual(TShortCut(0), Retrieved, '不存在的 Action 应该返回 0');
end;

procedure TTestDeepBaseHotkeys.Test_SetHotkey_OverwritesExisting;
var
  Action: string;
  Shortcut1, Shortcut2, Retrieved: TShortCut;
begin
  Action := 'test.action.overwrite';
  Shortcut1 := TextToShortCut('Ctrl+A');
  Shortcut2 := TextToShortCut('Ctrl+B');
  
  FHotkeys.SetHotkey(Action, Shortcut1);
  FHotkeys.SetHotkey(Action, Shortcut2);
  Retrieved := FHotkeys.GetHotkey(Action);
  
  Assert.AreEqual(Shortcut2, Retrieved, 'later shortcut should override earlier shortcut');
end;

procedure TTestDeepBaseHotkeys.Test_RegisterDefaultHotkeys;
var
  Defaults: TArray<THotkeyDefault>;
  Retrieved: TShortCut;
begin
  SetLength(Defaults, 2);
  Defaults[0].ActionName := 'default.action1';
  Defaults[0].Shortcut := 'Ctrl+1';
  Defaults[0].Description := 'Action 1';
  Defaults[1].ActionName := 'default.action2';
  Defaults[1].Shortcut := 'Ctrl+2';
  Defaults[1].Description := 'Action 2';
  
  FHotkeys.RegisterDefaultHotkeys(Defaults);
  
  Retrieved := FHotkeys.GetHotkey('default.action1');
  Assert.AreEqual<TShortCut>(TextToShortCut(Defaults[0].Shortcut), Retrieved, '默认快捷键应该被注册');
end;

procedure TTestDeepBaseHotkeys.Test_ResetHotkey_ToDefault;
var
  Defaults: TArray<THotkeyDefault>;
  Action: string;
  NewShortcut, Retrieved: TShortCut;
begin
  Action := 'reset.test.action';
  
  SetLength(Defaults, 1);
  Defaults[0].ActionName := Action;
  Defaults[0].Shortcut := 'Ctrl+R';
  Defaults[0].Description := 'Reset Test';
  
  FHotkeys.RegisterDefaultHotkeys(Defaults);
  
  // 修改快捷�?
  NewShortcut := TextToShortCut('Ctrl+X');
  FHotkeys.SetHotkey(Action, NewShortcut);
  
  // 重置
  FHotkeys.ResetHotkey(Action);
  Retrieved := FHotkeys.GetHotkey(Action);
  
  Assert.AreEqual<TShortCut>(TextToShortCut(Defaults[0].Shortcut), Retrieved, 'reset should restore default shortcut');
end;

procedure TTestDeepBaseHotkeys.Test_ResetAllHotkeys;
var
  Defaults: TArray<THotkeyDefault>;
begin
  SetLength(Defaults, 2);
  Defaults[0].ActionName := 'resetall.action1';
  Defaults[0].Shortcut := 'Ctrl+1';
  Defaults[0].Description := 'Action 1';
  Defaults[1].ActionName := 'resetall.action2';
  Defaults[1].Shortcut := 'Ctrl+2';
  Defaults[1].Description := 'Action 2';
  
  FHotkeys.RegisterDefaultHotkeys(Defaults);
  
  // 修改
  FHotkeys.SetHotkey('resetall.action1', TextToShortCut('Ctrl+A'));
  FHotkeys.SetHotkey('resetall.action2', TextToShortCut('Ctrl+B'));
  
  // 全部重置
  FHotkeys.ResetAllHotkeys;
  
  Assert.AreEqual<TShortCut>(TextToShortCut(Defaults[0].Shortcut), FHotkeys.GetHotkey('resetall.action1'), 
    'Action1 应该恢复默认');
  Assert.AreEqual<TShortCut>(TextToShortCut(Defaults[1].Shortcut), FHotkeys.GetHotkey('resetall.action2'), 
    'Action2 应该恢复默认');
end;

procedure TTestDeepBaseHotkeys.Test_CheckHotkeyConflict_NoConflict;
const
  Candidates: array[0..11] of string = (
    'Ctrl+Shift+Alt+F1', 'Ctrl+Shift+Alt+F2', 'Ctrl+Shift+Alt+F3', 'Ctrl+Shift+Alt+F4',
    'Ctrl+Shift+Alt+F5', 'Ctrl+Shift+Alt+F6', 'Ctrl+Shift+Alt+F7', 'Ctrl+Shift+Alt+F8',
    'Ctrl+Shift+Alt+F9', 'Ctrl+Shift+Alt+F10', 'Ctrl+Shift+Alt+F11', 'Ctrl+Shift+Alt+F12'
  );
var
  Conflict: string;
  I: Integer;
  Unused: TShortCut;
begin
  // Hotkeys 模块在初始化时可能已预置了一批默认快捷键�?
  // 因此这里不要假设 'Ctrl+F' 一定不会被占用�?

  FHotkeys.SetHotkey('existing.action', TextToShortCut('Ctrl+E'));

  Unused := 0;
  for I := Low(Candidates) to High(Candidates) do
  begin
    if FHotkeys.CheckHotkeyConflict(TextToShortCut(Candidates[I])) = '' then
    begin
      Unused := TextToShortCut(Candidates[I]);
      Break;
    end;
  end;

  Assert.AreNotEqual(TShortCut(0), Unused, 'should find an unused shortcut for testing');

  Conflict := FHotkeys.CheckHotkeyConflict(Unused);
  Assert.IsEmpty(Conflict, '不同的快捷键不应该有冲突');
end;

procedure TTestDeepBaseHotkeys.Test_CheckHotkeyConflict_HasConflict;
var
  Action: string;
  Shortcut: TShortCut;
  Conflict: string;
begin
  Action := 'conflict.test.action';
  Shortcut := TextToShortCut('Ctrl+C');
  
  FHotkeys.SetHotkey(Action, Shortcut);
  
  Conflict := FHotkeys.CheckHotkeyConflict(Shortcut);
  
  Assert.AreEqual(Action, Conflict, '应该返回冲突�?Action 名称');
end;

procedure TTestDeepBaseHotkeys.Test_GetAllHotkeys;
var
  AllHotkeys: TArray<THotkeyInfo>;
  I: Integer;
begin
  FHotkeys.SetHotkey('all.test.action1', TextToShortCut('Ctrl+1'));
  FHotkeys.SetHotkey('all.test.action2', TextToShortCut('Ctrl+2'));
  
  AllHotkeys := FHotkeys.GetAllHotkeys;
  
  Assert.IsTrue(Length(AllHotkeys) >= 2, '应该至少�?2 个快捷键');
end;

procedure TTestDeepBaseHotkeys.Test_DeleteHotkey;
var
  Action: string;
begin
  Action := 'delete.test.action';
  
  FHotkeys.SetHotkey(Action, TextToShortCut('Ctrl+D'));
  Assert.AreNotEqual(TShortCut(0), FHotkeys.GetHotkey(Action), 'shortcut should exist after setting');
  
  FHotkeys.DeleteHotkey(Action);
  
  Assert.AreEqual(TShortCut(0), FHotkeys.GetHotkey(Action), '删除后应该不存在');
end;

procedure TTestDeepBaseHotkeys.Test_HotkeyToText;
var
  Shortcut: TShortCut;
  Text: string;
begin
  Shortcut := TextToShortCut('Ctrl+Shift+S');
  
  Text := ShortCutToText(Shortcut);
  
  Assert.IsNotEmpty(Text, '快捷键文本不应该为空');
  Assert.Contains(Text, 'Ctrl', '应该包含 Ctrl');
end;

procedure TTestDeepBaseHotkeys.Test_TextToHotkey;
var
  Text: string;
  Shortcut: TShortCut;
begin
  Text := 'Ctrl+Alt+F1';
  
  Shortcut := TextToShortCut(Text);
  
  Assert.AreNotEqual(TShortCut(0), Shortcut, 'valid text should convert to non-zero shortcut');
end;

procedure TTestDeepBaseHotkeys.Test_OnHotkeyChanged_Event;
var
  EventFired: Boolean;
  ChangedAction: string;
begin
  EventFired := False;
  ChangedAction := '';
  
  FHotkeys.OnHotkeyChanged := 
    procedure(const AAction: string)
    begin
      EventFired := True;
      ChangedAction := AAction;
    end;
  
  try
    FHotkeys.SetHotkey('event.test.action', TextToShortCut('Ctrl+T'));
    
    Assert.IsTrue(EventFired, 'OnHotkeyChanged event should fire');
    Assert.AreEqual('event.test.action', ChangedAction, '事件应该传递正确的 Action');
  finally
    FHotkeys.OnHotkeyChanged := nil;
  end;
end;

procedure TTestDeepBaseHotkeys.Test_Scope_Default_IsApplication;
var
  Action: string;
begin
  Action := 'scope.default.action';
  FHotkeys.SetHotkey(Action, TextToShortCut('Ctrl+Alt+D'));

  Assert.AreEqual(Integer(hsApplication), Integer(FHotkeys.GetHotkeyScope(Action)),
    'newly set action should default to application scope');
end;

procedure TTestDeepBaseHotkeys.Test_CheckHotkeyConflictInScope_DifferentScopes_NoConflict;
var
  Shortcut: TShortCut;
  Conflict: string;
begin
  Shortcut := TextToShortCut('Ctrl+Alt+Y');
  FHotkeys.SetHotkey('scope.action.app', Shortcut);
  FHotkeys.SetHotkeyScope('scope.action.app', hsApplication);

  FHotkeys.SetHotkey('scope.action.editor', Shortcut);
  FHotkeys.SetHotkeyScope('scope.action.editor', hsEditor);

  Conflict := FHotkeys.CheckHotkeyConflictInScope(Shortcut, hsForm);
  Assert.IsEmpty(Conflict, 'same shortcut in other scopes must not conflict with form scope');
end;

procedure TTestDeepBaseHotkeys.Test_CheckHotkeyConflictInScope_SameScope_HasConflict;
var
  Shortcut: TShortCut;
  Conflict: string;
begin
  Shortcut := TextToShortCut('Ctrl+Alt+U');
  FHotkeys.SetHotkey('scope.same.form.action', Shortcut);
  FHotkeys.SetHotkeyScope('scope.same.form.action', hsForm);

  Conflict := FHotkeys.CheckHotkeyConflictInScope(Shortcut, hsForm, 'scope.current.action');
  Assert.AreEqual('scope.same.form.action', Conflict,
    'conflict lookup must return action in the same scope');
end;

procedure TTestDeepBaseHotkeys.Test_TriggerShortcut_ExecutesBoundActionByScope;
var
  Storage: IHotkeyStorage;
  LocalHotkeys: TDeepBaseHotkeys;
  Shortcut: TShortCut;
  LastAction: string;
begin
  Storage := TInMemoryHotkeyStorage.Create;
  LocalHotkeys := TDeepBaseHotkeys.Create(Storage);
  try
    Shortcut := TextToShortCut('Ctrl+Shift+J');

    LocalHotkeys.SetHotkey('bind.action.app', Shortcut);
    LocalHotkeys.SetHotkeyScope('bind.action.app', hsApplication);
    LocalHotkeys.BindAction('bind.action.app',
      procedure(const ActionName: string)
      begin
        LastAction := ActionName;
      end);

    LocalHotkeys.SetHotkey('bind.action.editor', Shortcut);
    LocalHotkeys.SetHotkeyScope('bind.action.editor', hsEditor);
    LocalHotkeys.BindAction('bind.action.editor',
      procedure(const ActionName: string)
      begin
        LastAction := ActionName;
      end);

    LastAction := '';
    Assert.IsTrue(LocalHotkeys.TriggerShortcut(Shortcut, hsApplication),
      'application shortcut should be triggered');
    Assert.AreEqual('bind.action.app', LastAction,
      'application scope should route to application binding');

    LastAction := '';
    Assert.IsTrue(LocalHotkeys.TriggerShortcut(Shortcut, hsEditor),
      'editor shortcut should be triggered');
    Assert.AreEqual('bind.action.editor', LastAction,
      'editor scope should route to editor binding');
  finally
    LocalHotkeys.Free;
  end;
end;

procedure TTestDeepBaseHotkeys.Test_TriggerShortcut_WithoutBinding_ReturnsFalse;
var
  Storage: IHotkeyStorage;
  LocalHotkeys: TDeepBaseHotkeys;
  Shortcut: TShortCut;
begin
  Storage := TInMemoryHotkeyStorage.Create;
  LocalHotkeys := TDeepBaseHotkeys.Create(Storage);
  try
    Shortcut := TextToShortCut('Ctrl+Shift+K');
    LocalHotkeys.SetHotkey('bind.none.action', Shortcut);
    LocalHotkeys.SetHotkeyScope('bind.none.action', hsApplication);

    Assert.IsFalse(LocalHotkeys.TriggerShortcut(Shortcut, hsApplication),
      'shortcut without binding should not trigger action');
  finally
    LocalHotkeys.Free;
  end;
end;

procedure TTestDeepBaseHotkeys.Test_StorageInjection_BasicLifecycle;
var
  Storage: IHotkeyStorage;
  LocalHotkeys: TDeepBaseHotkeys;
  Defaults: TArray<THotkeyDefault>;
  NewShortcut: TShortCut;
begin
  Storage := TInMemoryHotkeyStorage.Create;
  LocalHotkeys := TDeepBaseHotkeys.Create(Storage);
  try
    SetLength(Defaults, 1);
    Defaults[0].ActionName := 'inject.action';
    Defaults[0].Shortcut := 'Ctrl+I';
    Defaults[0].Description := 'Injected hotkey';
    Defaults[0].Category := 'Test';

    LocalHotkeys.RegisterDefaultHotkeys(Defaults);
    Assert.AreEqual<TShortCut>(TextToShortCut('Ctrl+I'),
      LocalHotkeys.GetHotkey('inject.action'),
      'Injected storage should provide registered defaults');

    NewShortcut := TextToShortCut('Ctrl+Shift+I');
    LocalHotkeys.SetHotkey('inject.action', NewShortcut);
    Assert.AreEqual<TShortCut>(NewShortcut,
      LocalHotkeys.GetHotkey('inject.action'),
      'Injected storage should persist hotkey updates');
    Assert.IsTrue(LocalHotkeys.IsHotkeyCustomized('inject.action'),
      'Changed hotkey should be marked customized');

    LocalHotkeys.ResetHotkey('inject.action');
    Assert.AreEqual<TShortCut>(TextToShortCut('Ctrl+I'),
      LocalHotkeys.GetHotkey('inject.action'),
      'Reset should restore default shortcut');

    LocalHotkeys.DeleteHotkey('inject.action');
    Assert.AreEqual<TShortCut>(0, LocalHotkeys.GetHotkey('inject.action'),
      'Delete should remove injected hotkey');
  finally
    LocalHotkeys.Free;
  end;
end;

procedure TTestDeepBaseGlobalHotkeys.Test_Register_Unregister_Basic;
var
  Platform: TMockGlobalHotkeyPlatform;
  GlobalHotkeys: TDeepBaseGlobalHotkeys;
  Shortcut: TShortCut;
begin
  Platform := TMockGlobalHotkeyPlatform.Create;
  GlobalHotkeys := TDeepBaseGlobalHotkeys.Create(0, Platform);
  try
    Shortcut := TextToShortCut('Ctrl+Shift+F12');
    Assert.IsTrue(GlobalHotkeys.Register(101, Shortcut), 'register should succeed');
    Assert.IsTrue(GlobalHotkeys.IsRegistered(101), 'hotkey id should be marked registered');
    Assert.AreEqual(1, GlobalHotkeys.Count, 'registered count should be 1');

    Assert.IsTrue(GlobalHotkeys.Unregister(101), 'unregister should succeed');
    Assert.IsFalse(GlobalHotkeys.IsRegistered(101), 'hotkey id should be removed after unregister');
    Assert.AreEqual(0, GlobalHotkeys.Count, 'registered count should be 0');
  finally
    GlobalHotkeys.Free;
  end;
end;

procedure TTestDeepBaseGlobalHotkeys.Test_Register_DuplicateId_IsRejected;
var
  Platform: TMockGlobalHotkeyPlatform;
  GlobalHotkeys: TDeepBaseGlobalHotkeys;
begin
  Platform := TMockGlobalHotkeyPlatform.Create;
  GlobalHotkeys := TDeepBaseGlobalHotkeys.Create(0, Platform);
  try
    Assert.IsTrue(GlobalHotkeys.Register(11, TextToShortCut('Ctrl+1')), 'first registration should succeed');
    Assert.IsFalse(GlobalHotkeys.Register(11, TextToShortCut('Ctrl+2')), 'duplicate hotkey id should be rejected');
    Assert.AreEqual(1, GlobalHotkeys.Count, 'duplicate registration should not increase count');
  finally
    GlobalHotkeys.Free;
  end;
end;

procedure TTestDeepBaseGlobalHotkeys.Test_Register_InvalidShortcut_IsRejected;
var
  Platform: TMockGlobalHotkeyPlatform;
  GlobalHotkeys: TDeepBaseGlobalHotkeys;
begin
  Platform := TMockGlobalHotkeyPlatform.Create;
  GlobalHotkeys := TDeepBaseGlobalHotkeys.Create(0, Platform);
  try
    Assert.IsFalse(GlobalHotkeys.Register(12, 0), 'zero shortcut should be rejected');
    Assert.IsFalse(GlobalHotkeys.Register(0, TextToShortCut('Ctrl+3')), 'non-positive hotkey id should be rejected');
    Assert.AreEqual(0, GlobalHotkeys.Count, 'invalid registration should keep zero count');
  finally
    GlobalHotkeys.Free;
  end;
end;

procedure TTestDeepBaseGlobalHotkeys.Test_Register_PlatformFailure_IsHandled;
var
  Platform: TMockGlobalHotkeyPlatform;
  GlobalHotkeys: TDeepBaseGlobalHotkeys;
begin
  Platform := TMockGlobalHotkeyPlatform.Create;
  Platform.SetFailOnId(13);
  GlobalHotkeys := TDeepBaseGlobalHotkeys.Create(0, Platform);
  try
    Assert.IsFalse(GlobalHotkeys.Register(13, TextToShortCut('Ctrl+4')), 'platform failure should return false');
    Assert.AreEqual(0, GlobalHotkeys.Count, 'failed platform registration should not be cached');
  finally
    GlobalHotkeys.Free;
  end;
end;

procedure TTestDeepBaseGlobalHotkeys.Test_DispatchMessage_WMHotKey;
var
  Platform: TMockGlobalHotkeyPlatform;
  GlobalHotkeys: TDeepBaseGlobalHotkeys;
  Msg: TMsg;
  HotkeyId: Integer;
begin
  Platform := TMockGlobalHotkeyPlatform.Create;
  GlobalHotkeys := TDeepBaseGlobalHotkeys.Create(0, Platform);
  try
    Assert.IsTrue(GlobalHotkeys.Register(21, TextToShortCut('Ctrl+5')), 'registration should succeed');

    FillChar(Msg, SizeOf(Msg), 0);
    Msg.message := WM_HOTKEY;
    Msg.wParam := WPARAM(21);
    Assert.IsTrue(GlobalHotkeys.DispatchMessage(Msg, HotkeyId), 'registered WM_HOTKEY should dispatch');
    Assert.AreEqual(21, HotkeyId, 'hotkey id should be returned');

    Msg.wParam := WPARAM(999);
    Assert.IsFalse(GlobalHotkeys.DispatchMessage(Msg, HotkeyId), 'unknown WM_HOTKEY id should be rejected');
  finally
    GlobalHotkeys.Free;
  end;
end;

procedure TTestDeepBaseGlobalHotkeys.Test_UnregisterAll_ClearsRegistrations;
var
  Platform: TMockGlobalHotkeyPlatform;
  GlobalHotkeys: TDeepBaseGlobalHotkeys;
begin
  Platform := TMockGlobalHotkeyPlatform.Create;
  GlobalHotkeys := TDeepBaseGlobalHotkeys.Create(0, Platform);
  try
    Assert.IsTrue(GlobalHotkeys.Register(31, TextToShortCut('Ctrl+6')), 'registration #1 should succeed');
    Assert.IsTrue(GlobalHotkeys.Register(32, TextToShortCut('Ctrl+7')), 'registration #2 should succeed');
    Assert.AreEqual(2, GlobalHotkeys.Count, 'count before clear should be 2');

    GlobalHotkeys.UnregisterAll;
    Assert.AreEqual(0, GlobalHotkeys.Count, 'count after clear should be 0');
    Assert.IsFalse(GlobalHotkeys.IsRegistered(31), 'id 31 should be cleared');
    Assert.IsFalse(GlobalHotkeys.IsRegistered(32), 'id 32 should be cleared');
  finally
    GlobalHotkeys.Free;
  end;
end;

procedure TTestDeepBaseVCLHotkeyBinder.Test_BindAction_AppliesShortcut_AndTriggersExecute;
var
  Storage: IHotkeyStorage;
  LocalHotkeys: TDeepBaseHotkeys;
  Binder: TDeepBaseVCLHotkeyBinder;
  Action: TAction;
  Probe: TNotifyProbe;
  Shortcut: TShortCut;
begin
  Storage := TInMemoryHotkeyStorage.Create;
  LocalHotkeys := TDeepBaseHotkeys.Create(Storage);
  Binder := TDeepBaseVCLHotkeyBinder.Create(LocalHotkeys);
  Action := TAction.Create(nil);
  Probe := TNotifyProbe.Create;
  try
    Probe.Fired := False;
    Action.OnExecute := Probe.HandleNotify;

    Shortcut := TextToShortCut('Ctrl+Shift+Q');
    LocalHotkeys.SetHotkey('vcl.action.execute', Shortcut);
    Binder.BindAction('vcl.action.execute', Action, hsApplication);

    Assert.AreEqual(Integer(Shortcut), Integer(Action.ShortCut),
      'bound action should receive shortcut from hotkey store');
    Assert.IsTrue(LocalHotkeys.TriggerShortcut(Shortcut, hsApplication),
      'application scope trigger should execute bound action');
    Assert.IsTrue(Probe.Fired, 'bound action execute should be called');
  finally
    Probe.Free;
    Action.Free;
    Binder.Free;
    LocalHotkeys.Free;
  end;
end;

procedure TTestDeepBaseVCLHotkeyBinder.Test_BindMenuItem_AppliesShortcut_AndTriggersClick;
var
  Storage: IHotkeyStorage;
  LocalHotkeys: TDeepBaseHotkeys;
  Binder: TDeepBaseVCLHotkeyBinder;
  Item: TMenuItem;
  Probe: TNotifyProbe;
  Shortcut: TShortCut;
begin
  Storage := TInMemoryHotkeyStorage.Create;
  LocalHotkeys := TDeepBaseHotkeys.Create(Storage);
  Binder := TDeepBaseVCLHotkeyBinder.Create(LocalHotkeys);
  Item := TMenuItem.Create(nil);
  Probe := TNotifyProbe.Create;
  try
    Probe.Fired := False;
    Item.OnClick := Probe.HandleNotify;

    Shortcut := TextToShortCut('Ctrl+Shift+W');
    LocalHotkeys.SetHotkey('vcl.menu.click', Shortcut);
    Binder.BindMenuItem('vcl.menu.click', Item, hsForm);

    Assert.AreEqual(Integer(Shortcut), Integer(Item.ShortCut),
      'bound menu item should receive shortcut from hotkey store');
    Assert.IsTrue(Binder.TriggerShortcut(Shortcut, hsForm),
      'form scope trigger should execute bound menu item');
    Assert.IsTrue(Probe.Fired, 'bound menu item click should be called');
  finally
    Probe.Free;
    Item.Free;
    Binder.Free;
    LocalHotkeys.Free;
  end;
end;

procedure TTestDeepBaseVCLHotkeyBinder.Test_HandleKeyDown_RespectsScope;
var
  Storage: IHotkeyStorage;
  LocalHotkeys: TDeepBaseHotkeys;
  Binder: TDeepBaseVCLHotkeyBinder;
  Button: TButton;
  Probe: TNotifyProbe;
  Key: Word;
  Shortcut: TShortCut;
begin
  Storage := TInMemoryHotkeyStorage.Create;
  LocalHotkeys := TDeepBaseHotkeys.Create(Storage);
  Binder := TDeepBaseVCLHotkeyBinder.Create(LocalHotkeys);
  Button := TButton.Create(nil);
  Probe := TNotifyProbe.Create;
  try
    Probe.Fired := False;
    Button.OnClick := Probe.HandleNotify;

    Shortcut := TextToShortCut('Ctrl+E');
    LocalHotkeys.SetHotkey('vcl.button.editor', Shortcut);
    Binder.BindButton('vcl.button.editor', Button, hsEditor);

    Key := Ord('E');
    Assert.IsTrue(Binder.HandleKeyDown(Key, [ssCtrl], hsEditor),
      'matching scope should trigger bound button');
    Assert.AreEqual(Word(0), Key, 'handled key should be cleared');
    Assert.IsTrue(Probe.Fired, 'button click should be called');

    Probe.Fired := False;
    Key := Ord('E');
    Assert.IsFalse(Binder.HandleKeyDown(Key, [ssCtrl], hsApplication),
      'different scope should not trigger bound button');
    Assert.IsFalse(Probe.Fired, 'button click should not be called across scopes');
  finally
    Probe.Free;
    Button.Free;
    Binder.Free;
    LocalHotkeys.Free;
  end;
end;

procedure TTestDeepBaseVCLHotkeyBinder.Test_Unbind_DisablesBoundTrigger;
var
  Storage: IHotkeyStorage;
  LocalHotkeys: TDeepBaseHotkeys;
  Binder: TDeepBaseVCLHotkeyBinder;
  Action: TAction;
  Shortcut: TShortCut;
begin
  Storage := TInMemoryHotkeyStorage.Create;
  LocalHotkeys := TDeepBaseHotkeys.Create(Storage);
  Binder := TDeepBaseVCLHotkeyBinder.Create(LocalHotkeys);
  Action := TAction.Create(nil);
  try
    Shortcut := TextToShortCut('Ctrl+Shift+U');
    LocalHotkeys.SetHotkey('vcl.unbind.action', Shortcut);
    Binder.BindAction('vcl.unbind.action', Action, hsApplication);
    Assert.IsTrue(LocalHotkeys.TriggerShortcut(Shortcut, hsApplication),
      'trigger should work before unbind');

    Binder.Unbind('vcl.unbind.action');
    Assert.IsFalse(LocalHotkeys.TriggerShortcut(Shortcut, hsApplication),
      'trigger should be disabled after unbind');
  finally
    Action.Free;
    Binder.Free;
    LocalHotkeys.Free;
  end;
end;

procedure TTestDeepBaseVCLHotkeyBinder.Test_HookHotkeyChanges_UpdatesControlShortcut;
var
  Storage: IHotkeyStorage;
  LocalHotkeys: TDeepBaseHotkeys;
  Binder: TDeepBaseVCLHotkeyBinder;
  Action: TAction;
  Shortcut1: TShortCut;
  Shortcut2: TShortCut;
begin
  Storage := TInMemoryHotkeyStorage.Create;
  LocalHotkeys := TDeepBaseHotkeys.Create(Storage);
  Binder := TDeepBaseVCLHotkeyBinder.Create(LocalHotkeys);
  Action := TAction.Create(nil);
  try
    Shortcut1 := TextToShortCut('Ctrl+Shift+A');
    Shortcut2 := TextToShortCut('Ctrl+Shift+B');
    LocalHotkeys.SetHotkey('vcl.hook.action', Shortcut1);
    Binder.BindAction('vcl.hook.action', Action, hsApplication);
    Assert.AreEqual(Integer(Shortcut1), Integer(Action.ShortCut),
      'initial shortcut should be applied on bind');

    LocalHotkeys.SetHotkey('vcl.hook.action', Shortcut2);
    Assert.AreEqual(Integer(Shortcut1), Integer(Action.ShortCut),
      'without hook, action shortcut should stay unchanged');

    Binder.HookHotkeyChanges;
    LocalHotkeys.SetHotkey('vcl.hook.action', Shortcut2);
    Assert.AreEqual(Integer(Shortcut2), Integer(Action.ShortCut),
      'hooked binder should refresh action shortcut on hotkey change');
  finally
    Action.Free;
    Binder.Free;
    LocalHotkeys.Free;
  end;
end;

procedure TTestDeepBaseHotkeyExchange.Test_ExportImportJson_RoundTrip;
var
  SourceStorage: IHotkeyStorage;
  TargetStorage: IHotkeyStorage;
  SourceHotkeys: TDeepBaseHotkeys;
  TargetHotkeys: TDeepBaseHotkeys;
  Defaults: TArray<THotkeyDefault>;
  Json: string;
  Imported: Integer;
begin
  SourceStorage := TInMemoryHotkeyStorage.Create;
  TargetStorage := TInMemoryHotkeyStorage.Create;
  SourceHotkeys := TDeepBaseHotkeys.Create(SourceStorage);
  TargetHotkeys := TDeepBaseHotkeys.Create(TargetStorage);
  try
    SetLength(Defaults, 2);
    Defaults[0].ActionName := 'exchange.action.one';
    Defaults[0].Shortcut := 'Ctrl+Shift+1';
    Defaults[0].Description := 'Exchange Action One';
    Defaults[0].Category := 'Exchange';
    Defaults[1].ActionName := 'exchange.action.two';
    Defaults[1].Shortcut := 'Ctrl+Shift+2';
    Defaults[1].Description := 'Exchange Action Two';
    Defaults[1].Category := 'Exchange';
    SourceHotkeys.RegisterDefaultHotkeys(Defaults);

    SourceHotkeys.SetHotkey('exchange.action.one', TextToShortCut('Ctrl+Shift+1'));
    SourceHotkeys.SetHotkeyScope('exchange.action.one', hsForm);
    SourceHotkeys.SetHotkey('exchange.action.two', TextToShortCut('Ctrl+Shift+2'));
    SourceHotkeys.SetHotkeyScope('exchange.action.two', hsEditor);

    Json := TDeepBaseHotkeyExchange.ExportToJson(SourceHotkeys);
    Assert.IsNotEmpty(Json, 'export json should not be empty');

    Imported := TDeepBaseHotkeyExchange.ImportFromJson(
      TargetHotkeys, Json, hicmOverwriteConflict);
    Assert.AreEqual(2, Imported, 'round-trip should import 2 actions');

    Assert.AreEqual<TShortCut>(TextToShortCut('Ctrl+Shift+1'),
      TargetHotkeys.GetHotkey('exchange.action.one'),
      'action one shortcut should be restored');
    Assert.AreEqual(Integer(hsForm),
      Integer(TargetHotkeys.GetHotkeyScope('exchange.action.one')),
      'action one scope should be restored');

    Assert.AreEqual<TShortCut>(TextToShortCut('Ctrl+Shift+2'),
      TargetHotkeys.GetHotkey('exchange.action.two'),
      'action two shortcut should be restored');
    Assert.AreEqual(Integer(hsEditor),
      Integer(TargetHotkeys.GetHotkeyScope('exchange.action.two')),
      'action two scope should be restored');
  finally
    SourceHotkeys.Free;
    TargetHotkeys.Free;
  end;
end;

procedure TTestDeepBaseHotkeyExchange.Test_ImportFromJson_ConflictPolicy;
var
  Storage: IHotkeyStorage;
  Hotkeys: TDeepBaseHotkeys;
  Json: string;
  Imported: Integer;
  Shortcut: TShortCut;
begin
  Storage := TInMemoryHotkeyStorage.Create;
  Hotkeys := TDeepBaseHotkeys.Create(Storage);
  try
    Shortcut := TextToShortCut('Ctrl+Shift+Z');
    Hotkeys.SetHotkey('exchange.existing', Shortcut);
    Hotkeys.SetHotkeyScope('exchange.existing', hsEditor);

    Json := '{"items":[{"action_name":"exchange.new","shortcut_text":"Ctrl+Shift+Z","scope":"editor"}]}';

    Imported := TDeepBaseHotkeyExchange.ImportFromJson(
      Hotkeys, Json, hicmKeepConflict);
    Assert.AreEqual(0, Imported, 'keep-conflict mode should skip conflicting action');
    Assert.AreEqual<TShortCut>(Shortcut, Hotkeys.GetHotkey('exchange.existing'),
      'existing hotkey should remain unchanged');
    Assert.AreEqual<TShortCut>(0, Hotkeys.GetHotkey('exchange.new'),
      'new hotkey should not be imported in keep-conflict mode');

    Imported := TDeepBaseHotkeyExchange.ImportFromJson(
      Hotkeys, Json, hicmOverwriteConflict);
    Assert.AreEqual(1, Imported, 'overwrite-conflict mode should import action');
    Assert.AreEqual<TShortCut>(0, Hotkeys.GetHotkey('exchange.existing'),
      'existing conflict hotkey should be cleared');
    Assert.AreEqual<TShortCut>(Shortcut, Hotkeys.GetHotkey('exchange.new'),
      'new action should get imported shortcut');
    Assert.AreEqual(Integer(hsEditor),
      Integer(Hotkeys.GetHotkeyScope('exchange.new')),
      'scope from import should be applied');
  finally
    Hotkeys.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDeepBaseHotkeys);
  TDUnitX.RegisterTestFixture(TTestDeepBaseGlobalHotkeys);
  TDUnitX.RegisterTestFixture(TTestDeepBaseVCLHotkeyBinder);
  TDUnitX.RegisterTestFixture(TTestDeepBaseHotkeyExchange);

end.
