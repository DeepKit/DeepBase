unit Test.UniBase.Hotkeys;

{*******************************************************************************
  UniBase Hotkeys 模块单元测试
  
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
  Vcl.Menus,
  UniBase.Types, UniBase.Manager, UniBase.Hotkeys;

type
  [TestFixture]
  TTestUniBaseHotkeys = class
  private
    FHotkeys: TUniBaseHotkeys;
    FManager: TUniBaseManager;
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
  end;

implementation

{ TTestUniBaseHotkeys }

procedure TTestUniBaseHotkeys.Setup;
begin
  FManager := UniBase.Manager.UniBase;
  if not FManager.IsInitialized then
    FManager.InitializeWithDB(':memory:');
  FHotkeys := FManager.Hotkeys;
end;

procedure TTestUniBaseHotkeys.TearDown;
begin
  FHotkeys := nil;
end;

procedure TTestUniBaseHotkeys.Test_SetGetHotkey_Basic;
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

procedure TTestUniBaseHotkeys.Test_GetHotkey_NotExists_ReturnsZero;
var
  Retrieved: TShortCut;
begin
  Retrieved := FHotkeys.GetHotkey('nonexistent.action.' + TGUID.NewGuid.ToString);
  
  Assert.AreEqual(TShortCut(0), Retrieved, '不存在的 Action 应该返回 0');
end;

procedure TTestUniBaseHotkeys.Test_SetHotkey_OverwritesExisting;
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
  
  Assert.AreEqual(Shortcut2, Retrieved, '后设置的快捷键应该覆盖前一个');
end;

procedure TTestUniBaseHotkeys.Test_RegisterDefaultHotkeys;
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

procedure TTestUniBaseHotkeys.Test_ResetHotkey_ToDefault;
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
  
  // 修改快捷键
  NewShortcut := TextToShortCut('Ctrl+X');
  FHotkeys.SetHotkey(Action, NewShortcut);
  
  // 重置
  FHotkeys.ResetHotkey(Action);
  Retrieved := FHotkeys.GetHotkey(Action);
  
  Assert.AreEqual<TShortCut>(TextToShortCut(Defaults[0].Shortcut), Retrieved, '重置后应该恢复默认值');
end;

procedure TTestUniBaseHotkeys.Test_ResetAllHotkeys;
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

procedure TTestUniBaseHotkeys.Test_CheckHotkeyConflict_NoConflict;
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
  // Hotkeys 模块在初始化时可能已预置了一批默认快捷键，
  // 因此这里不要假设 'Ctrl+F' 一定不会被占用。

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

  Assert.AreNotEqual(TShortCut(0), Unused, '应能找到一个未被占用的快捷键用于测试');

  Conflict := FHotkeys.CheckHotkeyConflict(Unused);
  Assert.IsEmpty(Conflict, '不同的快捷键不应该有冲突');
end;

procedure TTestUniBaseHotkeys.Test_CheckHotkeyConflict_HasConflict;
var
  Action: string;
  Shortcut: TShortCut;
  Conflict: string;
begin
  Action := 'conflict.test.action';
  Shortcut := TextToShortCut('Ctrl+C');
  
  FHotkeys.SetHotkey(Action, Shortcut);
  
  Conflict := FHotkeys.CheckHotkeyConflict(Shortcut);
  
  Assert.AreEqual(Action, Conflict, '应该返回冲突的 Action 名称');
end;

procedure TTestUniBaseHotkeys.Test_GetAllHotkeys;
var
  AllHotkeys: TArray<THotkeyInfo>;
  I: Integer;
begin
  FHotkeys.SetHotkey('all.test.action1', TextToShortCut('Ctrl+1'));
  FHotkeys.SetHotkey('all.test.action2', TextToShortCut('Ctrl+2'));
  
  AllHotkeys := FHotkeys.GetAllHotkeys;
  
  Assert.IsTrue(Length(AllHotkeys) >= 2, '应该至少有 2 个快捷键');
end;

procedure TTestUniBaseHotkeys.Test_DeleteHotkey;
var
  Action: string;
begin
  Action := 'delete.test.action';
  
  FHotkeys.SetHotkey(Action, TextToShortCut('Ctrl+D'));
  Assert.AreNotEqual(TShortCut(0), FHotkeys.GetHotkey(Action), '设置后应该存在');
  
  FHotkeys.DeleteHotkey(Action);
  
  Assert.AreEqual(TShortCut(0), FHotkeys.GetHotkey(Action), '删除后应该不存在');
end;

procedure TTestUniBaseHotkeys.Test_HotkeyToText;
var
  Shortcut: TShortCut;
  Text: string;
begin
  Shortcut := TextToShortCut('Ctrl+Shift+S');
  
  Text := ShortCutToText(Shortcut);
  
  Assert.IsNotEmpty(Text, '快捷键文本不应该为空');
  Assert.Contains(Text, 'Ctrl', '应该包含 Ctrl');
end;

procedure TTestUniBaseHotkeys.Test_TextToHotkey;
var
  Text: string;
  Shortcut: TShortCut;
begin
  Text := 'Ctrl+Alt+F1';
  
  Shortcut := TextToShortCut(Text);
  
  Assert.AreNotEqual(TShortCut(0), Shortcut, '有效的文本应该转换为非零快捷键');
end;

procedure TTestUniBaseHotkeys.Test_OnHotkeyChanged_Event;
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
    
    Assert.IsTrue(EventFired, 'OnHotkeyChanged 事件应该被触发');
    Assert.AreEqual('event.test.action', ChangedAction, '事件应该传递正确的 Action');
  finally
    FHotkeys.OnHotkeyChanged := nil;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestUniBaseHotkeys);

end.
