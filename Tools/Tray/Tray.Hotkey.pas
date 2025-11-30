{ ============================================================================
  Tray.Hotkey - Global Hotkey Registration Module
  
  Version: 1.0
  Description: Provides global hotkey registration for quick access to
               common operations from anywhere in Windows.
  ============================================================================ }

unit Tray.Hotkey;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Vcl.Forms;

type
  THotkeyAction = (
    haShowHide,       // Show/Hide tray window
    haQuickNote,      // Quick note input
    haLaunchStudio,   // Launch Studio
    haLaunchCmd,      // Launch CMD
    haLaunchPwsh,     // Launch PowerShell
    haClipboard,      // Clipboard history (future)
    haScreenshot      // Screenshot (future)
  );
  
  THotkeyCallback = procedure(Action: THotkeyAction) of object;
  
  THotkeyInfo = record
    ID: Integer;
    Action: THotkeyAction;
    Modifiers: UINT;
    VKey: UINT;
    Description: string;
    Enabled: Boolean;
  end;
  
  TTrayHotkeyManager = class
  private
    FHotkeys: TList<THotkeyInfo>;
    FHandle: HWND;
    FNextID: Integer;
    FOnHotkey: THotkeyCallback;
    FOldWndProc: Pointer;
    
    class var FInstance: TTrayHotkeyManager;
    
    procedure WndProc(var Msg: TMessage);
    function FindHotkeyByID(ID: Integer): Integer;
    function GenerateID: Integer;
    
  public
    constructor Create(AHandle: HWND);
    destructor Destroy; override;
    
    class function Instance: TTrayHotkeyManager;
    class procedure Initialize(AHandle: HWND);
    class procedure Finalize;
    
    { Registration }
    function RegisterHotkey(Action: THotkeyAction; Modifiers, VKey: UINT;
      const ADescription: string = ''): Boolean;
    function UnregisterHotkey(Action: THotkeyAction): Boolean;
    procedure UnregisterAll;
    
    { Defaults }
    procedure RegisterDefaults;
    
    { Query }
    function GetHotkeyInfo(Action: THotkeyAction): THotkeyInfo;
    function GetAllHotkeys: TArray<THotkeyInfo>;
    function IsRegistered(Action: THotkeyAction): Boolean;
    
    { Helpers }
    class function ModifiersToString(Modifiers: UINT): string;
    class function VKeyToString(VKey: UINT): string;
    class function HotkeyToString(Modifiers, VKey: UINT): string;
    
    property OnHotkey: THotkeyCallback read FOnHotkey write FOnHotkey;
  end;
  
function TrayHotkeys: TTrayHotkeyManager;

implementation

var
  _HotkeyManager: TTrayHotkeyManager = nil;

function TrayHotkeys: TTrayHotkeyManager;
begin
  Result := TTrayHotkeyManager.Instance;
end;

{ TTrayHotkeyManager }

constructor TTrayHotkeyManager.Create(AHandle: HWND);
begin
  inherited Create;
  FHotkeys := TList<THotkeyInfo>.Create;
  FHandle := AHandle;
  FNextID := 1;
  FOnHotkey := nil;
  FOldWndProc := nil;
end;

destructor TTrayHotkeyManager.Destroy;
begin
  UnregisterAll;
  FHotkeys.Free;
  inherited;
end;

class function TTrayHotkeyManager.Instance: TTrayHotkeyManager;
begin
  Result := FInstance;
end;

class procedure TTrayHotkeyManager.Initialize(AHandle: HWND);
begin
  if FInstance = nil then
    FInstance := TTrayHotkeyManager.Create(AHandle);
  _HotkeyManager := FInstance;
end;

class procedure TTrayHotkeyManager.Finalize;
begin
  FreeAndNil(FInstance);
  _HotkeyManager := nil;
end;

procedure TTrayHotkeyManager.WndProc(var Msg: TMessage);
var
  ID: Integer;
  Idx: Integer;
begin
  if Msg.Msg = WM_HOTKEY then
  begin
    ID := Msg.WParam;
    Idx := FindHotkeyByID(ID);
    if (Idx >= 0) and Assigned(FOnHotkey) then
      FOnHotkey(FHotkeys[Idx].Action);
  end;
end;

function TTrayHotkeyManager.FindHotkeyByID(ID: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to FHotkeys.Count - 1 do
  begin
    if FHotkeys[I].ID = ID then
    begin
      Result := I;
      Break;
    end;
  end;
end;

function TTrayHotkeyManager.GenerateID: Integer;
begin
  Result := FNextID;
  Inc(FNextID);
end;

function TTrayHotkeyManager.RegisterHotkey(Action: THotkeyAction;
  Modifiers, VKey: UINT; const ADescription: string): Boolean;
var
  Info: THotkeyInfo;
  I: Integer;
begin
  Result := False;
  
  // Check if already registered
  for I := 0 to FHotkeys.Count - 1 do
  begin
    if FHotkeys[I].Action = Action then
    begin
      // Already registered, unregister first
      UnregisterHotkey(Action);
      Break;
    end;
  end;
  
  Info.ID := GenerateID;
  Info.Action := Action;
  Info.Modifiers := Modifiers;
  Info.VKey := VKey;
  Info.Description := ADescription;
  Info.Enabled := False;
  
  // Register with Windows
  if Winapi.Windows.RegisterHotKey(FHandle, Info.ID, Modifiers, VKey) then
  begin
    Info.Enabled := True;
    FHotkeys.Add(Info);
    Result := True;
  end;
end;

function TTrayHotkeyManager.UnregisterHotkey(Action: THotkeyAction): Boolean;
var
  I: Integer;
  Info: THotkeyInfo;
begin
  Result := False;
  
  for I := FHotkeys.Count - 1 downto 0 do
  begin
    if FHotkeys[I].Action = Action then
    begin
      Info := FHotkeys[I];
      if Info.Enabled then
        Winapi.Windows.UnregisterHotKey(FHandle, Info.ID);
      FHotkeys.Delete(I);
      Result := True;
      Break;
    end;
  end;
end;

procedure TTrayHotkeyManager.UnregisterAll;
var
  I: Integer;
begin
  for I := 0 to FHotkeys.Count - 1 do
  begin
    if FHotkeys[I].Enabled then
      Winapi.Windows.UnregisterHotKey(FHandle, FHotkeys[I].ID);
  end;
  FHotkeys.Clear;
end;

procedure TTrayHotkeyManager.RegisterDefaults;
begin
  // Ctrl+Alt+U: Show/Hide tray window
  RegisterHotkey(haShowHide, MOD_CONTROL or MOD_ALT, Ord('U'),
    'Show/Hide UniBase Tray');
  
  // Ctrl+Alt+N: Quick note
  RegisterHotkey(haQuickNote, MOD_CONTROL or MOD_ALT, Ord('N'),
    'Quick Note');
  
  // Ctrl+Alt+S: Launch Studio
  RegisterHotkey(haLaunchStudio, MOD_CONTROL or MOD_ALT, Ord('S'),
    'Launch UniBase Studio');
  
  // Ctrl+Alt+C: Launch CMD
  RegisterHotkey(haLaunchCmd, MOD_CONTROL or MOD_ALT, Ord('C'),
    'Launch Command Prompt');
  
  // Ctrl+Alt+P: Launch PowerShell
  RegisterHotkey(haLaunchPwsh, MOD_CONTROL or MOD_ALT, Ord('P'),
    'Launch PowerShell');
end;

function TTrayHotkeyManager.GetHotkeyInfo(Action: THotkeyAction): THotkeyInfo;
var
  I: Integer;
begin
  ZeroMemory(@Result, SizeOf(Result));
  Result.Action := Action;
  
  for I := 0 to FHotkeys.Count - 1 do
  begin
    if FHotkeys[I].Action = Action then
    begin
      Result := FHotkeys[I];
      Break;
    end;
  end;
end;

function TTrayHotkeyManager.GetAllHotkeys: TArray<THotkeyInfo>;
begin
  Result := FHotkeys.ToArray;
end;

function TTrayHotkeyManager.IsRegistered(Action: THotkeyAction): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to FHotkeys.Count - 1 do
  begin
    if (FHotkeys[I].Action = Action) and FHotkeys[I].Enabled then
    begin
      Result := True;
      Break;
    end;
  end;
end;

class function TTrayHotkeyManager.ModifiersToString(Modifiers: UINT): string;
begin
  Result := '';
  if (Modifiers and MOD_CONTROL) <> 0 then
    Result := Result + 'Ctrl+';
  if (Modifiers and MOD_ALT) <> 0 then
    Result := Result + 'Alt+';
  if (Modifiers and MOD_SHIFT) <> 0 then
    Result := Result + 'Shift+';
  if (Modifiers and MOD_WIN) <> 0 then
    Result := Result + 'Win+';
end;

class function TTrayHotkeyManager.VKeyToString(VKey: UINT): string;
begin
  case VKey of
    VK_F1..VK_F24:
      Result := 'F' + IntToStr(VKey - VK_F1 + 1);
    VK_NUMPAD0..VK_NUMPAD9:
      Result := 'Num' + IntToStr(VKey - VK_NUMPAD0);
    VK_SPACE: Result := 'Space';
    VK_TAB: Result := 'Tab';
    VK_RETURN: Result := 'Enter';
    VK_ESCAPE: Result := 'Esc';
    VK_BACK: Result := 'Backspace';
    VK_DELETE: Result := 'Delete';
    VK_INSERT: Result := 'Insert';
    VK_HOME: Result := 'Home';
    VK_END: Result := 'End';
    VK_PRIOR: Result := 'PageUp';
    VK_NEXT: Result := 'PageDown';
    VK_LEFT: Result := 'Left';
    VK_RIGHT: Result := 'Right';
    VK_UP: Result := 'Up';
    VK_DOWN: Result := 'Down';
    Ord('0')..Ord('9'):
      Result := Chr(VKey);
    Ord('A')..Ord('Z'):
      Result := Chr(VKey);
  else
    Result := 'Key$' + IntToHex(VKey, 2);
  end;
end;

class function TTrayHotkeyManager.HotkeyToString(Modifiers, VKey: UINT): string;
begin
  Result := ModifiersToString(Modifiers) + VKeyToString(VKey);
end;

end.
