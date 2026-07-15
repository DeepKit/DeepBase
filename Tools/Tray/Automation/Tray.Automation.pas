unit Tray.Automation;

{*******************************************************************************
  DeepBaseTray - 自动化脚本引擎
  
  功能:
  - 解析和执行 JSON 格式的自动化脚本
  - 支持多种 Action 类型
  - 错误处理和日志记录
  
  脚本格式示例:
  [
    "name": "重启服务",
    "steps": [
      ["action": "findWindow", "title": "服务管理器"],
      ["action": "wait", "seconds": 1],
      ["action": "runCommand", "command": "net stop MyService"],
      ["action": "wait", "seconds": 2],
      ["action": "runCommand", "command": "net start MyService"]
    ]
  ]
*******************************************************************************}

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.ShellAPI, Winapi.TlHelp32,
  System.SysUtils, System.Classes, System.JSON, System.Generics.Collections,
  System.DateUtils,
  DeepBase.Exceptions,
  Tray.Types;

type
  { 脚本 }
  TAutomationScript = class
  private
    FName: string;
    FDescription: string;
    FActions: TObjectList<TAutomationAction>;
  public
    constructor Create;
    destructor Destroy; override;
    
    class function ParseFromJSON(const AJson: string): TAutomationScript;
    
    property Name: string read FName write FName;
    property Description: string read FDescription write FDescription;
    property Actions: TObjectList<TAutomationAction> read FActions;
  end;
  
  { 脚本执行器 }
  TScriptExecutor = class
  private
    FScript: TAutomationScript;
    FRunning: Boolean;
    FCurrentStep: Integer;
    FLastError: string;
    FOnStepStart: TProc<Integer, TAutomationAction>;
    FOnStepComplete: TProc<Integer, TActionResult>;
    FOnScriptComplete: TProc<Boolean>;
    
    { Action 执行方法 }
    function ExecuteWait(AAction: TAutomationAction): TActionResult;
    function ExecuteRunCommand(AAction: TAutomationAction): TActionResult;
    function ExecuteFindWindow(AAction: TAutomationAction): TActionResult;
    function ExecuteActivateWindow(AAction: TAutomationAction): TActionResult;
    function ExecuteKillProcess(AAction: TAutomationAction): TActionResult;
    function ExecuteAction(AAction: TAutomationAction): TActionResult;
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure LoadScript(AScript: TAutomationScript);
    procedure Execute;
    procedure Stop;
    
    property Running: Boolean read FRunning;
    property CurrentStep: Integer read FCurrentStep;
    property LastError: string read FLastError;
    
    property OnStepStart: TProc<Integer, TAutomationAction> read FOnStepStart write FOnStepStart;
    property OnStepComplete: TProc<Integer, TActionResult> read FOnStepComplete write FOnStepComplete;
    property OnScriptComplete: TProc<Boolean> read FOnScriptComplete write FOnScriptComplete;
  end;

type
{ 辅助函数 }
  TKeyboardMouseActions = class
  public
    { 键盘操作 }
    class function ExecuteSendKeys(AAction: TAutomationAction): TActionResult;
    class function ExecuteSendText(AAction: TAutomationAction): TActionResult;
    class function ExecutePaste(AAction: TAutomationAction): TActionResult;
    
    { 鼠标操作 }
    class function ExecuteMouseClick(AAction: TAutomationAction): TActionResult;
    
    { 等待操作 }
    class function ExecuteWaitWindow(AAction: TAutomationAction): TActionResult;
    
    { 辅助方法 }
    class procedure SendKeyPress(VK: Word; Extended: Boolean = False);
    class procedure SendKeyDown(VK: Word; Extended: Boolean = False);
    class procedure SendKeyUp(VK: Word; Extended: Boolean = False);
    class procedure SendChar(C: Char);
    class procedure SendString(const S: string);
    class function ParseKeyString(const AKeys: string): Boolean;
  end;

function FindWindowByTitle(const ATitle: string; APartialMatch: Boolean = True): hWnd;
function FindProcessByName(const AName: string): DWORD;
function KillProcessByPID(APID: DWORD): Boolean;
function KillProcessByName(const AName: string): Boolean;

implementation

uses
  Tray.Launcher,
  Vcl.Clipbrd;

{ 辅助函数 - TEnumWindowData 用于窗口查找 }

type
  TEnumWindowData = record
    Title: string;
    PartialMatch: Boolean;
    FoundHandle: hWnd;
  end;
  PEnumWindowData = ^TEnumWindowData;

function EnumWindowsCallback(hwnd: hWnd; lParam: LPARAM): BOOL; stdcall;
var
  Data: PEnumWindowData;
  WindowTitle: array[0..255] of Char;
  Title: string;
begin
  Result := True;  // 继续枚举
  Data := PEnumWindowData(lParam);
  
  if GetWindowText(hWnd, WindowTitle, Length(WindowTitle)) > 0 then
  begin
    Title := string(WindowTitle);
    if Data.PartialMatch then
    begin
      if Pos(UpperCase(Data.Title), UpperCase(Title)) > 0 then
      begin
        Data.FoundHandle := hWnd;
        Result := False;  // 停止枚举
      end;
    end
    else
    begin
      if SameText(Title, Data.Title) then
      begin
        Data.FoundHandle := hWnd;
        Result := False;
      end;
    end;
  end;
end;

function FindWindowByTitle(const ATitle: string; APartialMatch: Boolean): hWnd;
var
  Data: TEnumWindowData;
begin
  Data.Title := ATitle;
  Data.PartialMatch := APartialMatch;
  Data.FoundHandle := 0;
  
  EnumWindows(@EnumWindowsCallback, LPARAM(@Data));
  Result := Data.FoundHandle;
end;

function FindProcessByName(const AName: string): DWORD;
var
  Snapshot: THandle;
  PE: TProcessEntry32;
  SearchName: string;
begin
  Result := 0;
  SearchName := UpperCase(AName);
  
  Snapshot := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if Snapshot = INVALID_HANDLE_VALUE then
    Exit;
    
  try
    PE.dwSize := SizeOf(TProcessEntry32);
    if Process32First(Snapshot, PE) then
    begin
      repeat
        if UpperCase(PE.szExeFile) = SearchName then
        begin
          Result := PE.th32ProcessID;
          Break;
        end;
      until not Process32Next(Snapshot, PE);
    end;
  finally
    CloseHandle(Snapshot);
  end;
end;

function KillProcessByPID(APID: DWORD): Boolean;
var
  hProcess: THandle;
begin
  Result := False;
  hProcess := OpenProcess(PROCESS_TERMINATE, False, APID);
  if hProcess <> 0 then
  begin
    try
      Result := TerminateProcess(hProcess, 0);
    finally
      CloseHandle(hProcess);
    end;
  end;
end;

function KillProcessByName(const AName: string): Boolean;
var
  PID: DWORD;
begin
  PID := FindProcessByName(AName);
  if PID > 0 then
    Result := KillProcessByPID(PID)
  else
    Result := False;
end;

{ TAutomationScript }

constructor TAutomationScript.Create;
begin
  inherited Create;
  FActions := TObjectList<TAutomationAction>.Create(True);
end;

destructor TAutomationScript.Destroy;
begin
  FActions.Free;
  inherited;
end;

class function TAutomationScript.ParseFromJSON(const AJson: string): TAutomationScript;
var
  JRoot: TJSONObject;
  JSteps: TJSONArray;
  JStep: TJSONValue;
  JStepObj: TJSONObject;
  ActionStr: string;
  ActionType: TActionType;
  Action: TAutomationAction;
  ParamsCopy: TJSONObject;
begin
  Result := TAutomationScript.Create;
  
  JRoot := TJSONObject.ParseJSONValue(AJson) as TJSONObject;
  if JRoot = nil then
  begin
    Result.Free;
    raise EInvalidOperationException.Create('Invalid JSON format');
  end;
  
  try
    // 解析名称和描述
    if JRoot.GetValue('name') <> nil then
      Result.Name := JRoot.GetValue('name').Value;
    if JRoot.GetValue('description') <> nil then
      Result.Description := JRoot.GetValue('description').Value;
    
    // 解析步骤
    JSteps := JRoot.GetValue('steps') as TJSONArray;
    if JSteps = nil then
      raise EInvalidOperationException.Create('Missing "steps" array');
      
    for JStep in JSteps do
    begin
      if not (JStep is TJSONObject) then
        Continue;
        
      JStepObj := TJSONObject(JStep);
      
      // 获取 action 类型
      if JStepObj.GetValue('action') = nil then
        raise EInvalidOperationException.Create('Missing "action" field in step');
        
      ActionStr := JStepObj.GetValue('action').Value;
      ActionType := ActionTypeFromString(ActionStr);
      
      if ActionType = atUnknown then
        raise EInvalidOperationException.CreateFmt('Unknown action type: %s', [ActionStr]);
      
      // 克隆参数对象
      ParamsCopy := TJSONObject(JStepObj.Clone);
      
      Action := TAutomationAction.Create(ActionType, ParamsCopy, True);
      Result.Actions.Add(Action);
    end;
  finally
    JRoot.Free;
  end;
end;

{ TScriptExecutor }

constructor TScriptExecutor.Create;
begin
  inherited Create;
  FScript := nil;
  FRunning := False;
  FCurrentStep := -1;
end;

destructor TScriptExecutor.Destroy;
begin
  // 不释放 FScript，由调用者管理
  inherited;
end;

procedure TScriptExecutor.LoadScript(AScript: TAutomationScript);
begin
  FScript := AScript;
  FCurrentStep := -1;
  FLastError := '';
end;

procedure TScriptExecutor.Execute;
var
  I: Integer;
  Action: TAutomationAction;
  Result: TActionResult;
  AllSuccess: Boolean;
begin
  if FScript = nil then
    Exit;
  if FRunning then
    Exit;
    
  FRunning := True;
  AllSuccess := True;
  
  try
    for I := 0 to FScript.Actions.Count - 1 do
    begin
      if not FRunning then
        Break;
        
      FCurrentStep := I;
      Action := FScript.Actions[I];
      
      // 通知步骤开始
      if Assigned(FOnStepStart) then
        FOnStepStart(I, Action);
      
      // 执行 Action
      Result := ExecuteAction(Action);
      
      // 通知步骤完成
      if Assigned(FOnStepComplete) then
        FOnStepComplete(I, Result);
      
      if not Result.Success then
      begin
        FLastError := Result.ErrorMessage;
        AllSuccess := False;
        Break;
      end;
    end;
  finally
    FRunning := False;
    FCurrentStep := -1;
    
    // 通知脚本完成
    if Assigned(FOnScriptComplete) then
      FOnScriptComplete(AllSuccess);
  end;
end;

procedure TScriptExecutor.Stop;
begin
  FRunning := False;
end;

function TScriptExecutor.ExecuteAction(AAction: TAutomationAction): TActionResult;
begin
  case AAction.ActionType of
    atWait:
      Result := ExecuteWait(AAction);
    atRunCommand:
      Result := ExecuteRunCommand(AAction);
    atFindWindow:
      Result := ExecuteFindWindow(AAction);
    atActivateWindow:
      Result := ExecuteActivateWindow(AAction);
    atKillProcess:
      Result := ExecuteKillProcess(AAction);
    atSendKeys:
      Result := TKeyboardMouseActions.ExecuteSendKeys(AAction);
    atSendText:
      Result := TKeyboardMouseActions.ExecuteSendText(AAction);
    atPaste:
      Result := TKeyboardMouseActions.ExecutePaste(AAction);
    atMouseClick:
      Result := TKeyboardMouseActions.ExecuteMouseClick(AAction);
    atWaitWindow:
      Result := TKeyboardMouseActions.ExecuteWaitWindow(AAction);
  else
    Result := TActionResult.Fail('Action not implemented: ' + ActionTypeToString(AAction.ActionType));
  end;
end;

function TScriptExecutor.ExecuteWait(AAction: TAutomationAction): TActionResult;
var
  Seconds: Integer;
  Milliseconds: Integer;
begin
  Seconds := AAction.GetParamInt('seconds', 0);
  Milliseconds := AAction.GetParamInt('milliseconds', 0);
  
  if Seconds > 0 then
    Milliseconds := Milliseconds + Seconds * 1000;
    
  if Milliseconds > 0 then
    Sleep(Milliseconds);
    
  Result := TActionResult.OK;
end;

function TScriptExecutor.ExecuteRunCommand(AAction: TAutomationAction): TActionResult;
var
  Command: string;
  WorkDir: string;
  WaitForExit: Boolean;
  RunAsAdmin: Boolean;
begin
  Command := AAction.GetParamStr('command', '');
  if Command = '' then
    Exit(TActionResult.Fail('Missing "command" parameter'));
    
  WorkDir := AAction.GetParamStr('workDir', '');
  WaitForExit := AAction.GetParamBool('wait', False);
  RunAsAdmin := AAction.GetParamBool('admin', False);
  
  try
    if WaitForExit then
    begin
      // TODO(OPS-P2-001): 实现等待命令完成 — 改用 TProcess 或 CreateProcess + WaitForSingleObject
      TTrayLauncher.LaunchProgram('cmd.exe', '/C ' + Command, WorkDir, RunAsAdmin);
    end
    else
    begin
      TTrayLauncher.LaunchProgram('cmd.exe', '/C ' + Command, WorkDir, RunAsAdmin);
    end;
    Result := TActionResult.OK;
  except
    on E: Exception do
      Result := TActionResult.Fail(E.Message);
  end;
end;

function TScriptExecutor.ExecuteFindWindow(AAction: TAutomationAction): TActionResult;
var
  Title: string;
  ClassName: string;
  PartialMatch: Boolean;
  hWnd: THandle;
begin
  Title := AAction.GetParamStr('title', '');
  ClassName := AAction.GetParamStr('class', '');
  PartialMatch := AAction.GetParamBool('partial', True);
  
  if (Title = '') and (ClassName = '') then
    Exit(TActionResult.Fail('Missing "title" or "class" parameter'));
  
  if Title <> '' then
    hwnd := FindWindowByTitle(Title, PartialMatch)
  else
    hwnd := FindWindow(PChar(ClassName), nil);
    
  if hWnd <> 0 then
    Result := TActionResult.OK(IntToStr(hWnd))
  else
    Result := TActionResult.Fail('Window not found');
end;

function TScriptExecutor.ExecuteActivateWindow(AAction: TAutomationAction): TActionResult;
var
  Title: string;
  hWnd: THandle;
  HandleStr: string;
begin
  Title := AAction.GetParamStr('title', '');
  HandleStr := AAction.GetParamStr('handle', '');
  
  if HandleStr <> '' then
    hwnd := StrToIntDef(HandleStr, 0)
  else if Title <> '' then
    hwnd := FindWindowByTitle(Title, True)
  else
    Exit(TActionResult.Fail('Missing "title" or "handle" parameter'));
    
  if hWnd = 0 then
    Exit(TActionResult.Fail('Window not found'));
    
  // 恢复窗口（如果最小化）
  if IsIconic(hWnd) then
    ShowWindow(hWnd, SW_RESTORE);
    
  // 激活窗口
  SetForegroundWindow(hWnd);
  
  Result := TActionResult.OK;
end;

function TScriptExecutor.ExecuteKillProcess(AAction: TAutomationAction): TActionResult;
var
  ProcessName: string;
  PID: Integer;
begin
  ProcessName := AAction.GetParamStr('name', '');
  PID := AAction.GetParamInt('pid', 0);
  
  if PID > 0 then
  begin
    if KillProcessByPID(PID) then
      Result := TActionResult.OK
    else
      Result := TActionResult.Fail('Failed to kill process by PID');
  end
  else if ProcessName <> '' then
  begin
    if KillProcessByName(ProcessName) then
      Result := TActionResult.OK
    else
      Result := TActionResult.Fail('Process not found or failed to kill');
  end
  else
    Result := TActionResult.Fail('Missing "name" or "pid" parameter');
end;


{ TKeyboardMouseActions }

class procedure TKeyboardMouseActions.SendKeyDown(VK: Word; Extended: Boolean);
var
  Input: TInput;
begin
  ZeroMemory(@Input, SizeOf(Input));
  Input.Itype := INPUT_KEYBOARD;
  Input.ki.wVk := VK;
  Input.ki.wScan := MapVirtualKey(VK, 0);
  Input.ki.dwFlags := 0;
  if Extended then
    Input.ki.dwFlags := Input.ki.dwFlags or KEYEVENTF_EXTENDEDKEY;
  SendInput(1, Input, SizeOf(TInput));
end;

class procedure TKeyboardMouseActions.SendKeyUp(VK: Word; Extended: Boolean);
var
  Input: TInput;
begin
  ZeroMemory(@Input, SizeOf(Input));
  Input.Itype := INPUT_KEYBOARD;
  Input.ki.wVk := VK;
  Input.ki.wScan := MapVirtualKey(VK, 0);
  Input.ki.dwFlags := KEYEVENTF_KEYUP;
  if Extended then
    Input.ki.dwFlags := Input.ki.dwFlags or KEYEVENTF_EXTENDEDKEY;
  SendInput(1, Input, SizeOf(TInput));
end;

class procedure TKeyboardMouseActions.SendKeyPress(VK: Word; Extended: Boolean);
begin
  SendKeyDown(VK, Extended);
  Sleep(10);
  SendKeyUp(VK, Extended);
end;

class procedure TKeyboardMouseActions.SendChar(C: Char);
var
  Input: array[0..1] of TInput;
begin
  ZeroMemory(@Input, SizeOf(Input));
  
  // Key down
  Input[0].Itype := INPUT_KEYBOARD;
  Input[0].ki.wVk := 0;
  Input[0].ki.wScan := Ord(C);
  Input[0].ki.dwFlags := KEYEVENTF_UNICODE;
  
  // Key up
  Input[1].Itype := INPUT_KEYBOARD;
  Input[1].ki.wVk := 0;
  Input[1].ki.wScan := Ord(C);
  Input[1].ki.dwFlags := KEYEVENTF_UNICODE or KEYEVENTF_KEYUP;
  
  SendInput(2, Input[0], SizeOf(TInput));
end;

class procedure TKeyboardMouseActions.SendString(const S: string);
var
  I: Integer;
begin
  for I := 1 to Length(S) do
  begin
    SendChar(S[I]);
    Sleep(5);  // 小延迟确保字符被正确接收
  end;
end;

class function TKeyboardMouseActions.ParseKeyString(const AKeys: string): Boolean;
var
  I: Integer;
  InBracket: Boolean;
  Token: string;
  Modifiers: set of (modCtrl, modAlt, modShift, modWin);
  VK: Word;
begin
  Result := True;
  Modifiers := [];
  InBracket := False;
  Token := '';
  
  I := 1;
  while I <= Length(AKeys) do
  begin
    case AKeys[I] of
      '{':
        begin
          InBracket := True;
          Token := '';
        end;
      '}':
        begin
          InBracket := False;
          Token := UpperCase(Trim(Token));
          
          // 解析特殊键
          VK := 0;
          if Token = 'ENTER' then VK := VK_RETURN
          else if Token = 'TAB' then VK := VK_TAB
          else if Token = 'ESC' then VK := VK_ESCAPE
          else if Token = 'ESCAPE' then VK := VK_ESCAPE
          else if Token = 'BACKSPACE' then VK := VK_BACK
          else if Token = 'BS' then VK := VK_BACK
          else if Token = 'DELETE' then VK := VK_DELETE
          else if Token = 'DEL' then VK := VK_DELETE
          else if Token = 'INSERT' then VK := VK_INSERT
          else if Token = 'INS' then VK := VK_INSERT
          else if Token = 'HOME' then VK := VK_HOME
          else if Token = 'END' then VK := VK_END
          else if Token = 'PAGEUP' then VK := VK_PRIOR
          else if Token = 'PGUP' then VK := VK_PRIOR
          else if Token = 'PAGEDOWN' then VK := VK_NEXT
          else if Token = 'PGDN' then VK := VK_NEXT
          else if Token = 'UP' then VK := VK_UP
          else if Token = 'DOWN' then VK := VK_DOWN
          else if Token = 'LEFT' then VK := VK_LEFT
          else if Token = 'RIGHT' then VK := VK_RIGHT
          else if Token = 'F1' then VK := VK_F1
          else if Token = 'F2' then VK := VK_F2
          else if Token = 'F3' then VK := VK_F3
          else if Token = 'F4' then VK := VK_F4
          else if Token = 'F5' then VK := VK_F5
          else if Token = 'F6' then VK := VK_F6
          else if Token = 'F7' then VK := VK_F7
          else if Token = 'F8' then VK := VK_F8
          else if Token = 'F9' then VK := VK_F9
          else if Token = 'F10' then VK := VK_F10
          else if Token = 'F11' then VK := VK_F11
          else if Token = 'F12' then VK := VK_F12
          else if Token = 'SPACE' then VK := VK_SPACE
          else if Token = 'CAPSLOCK' then VK := VK_CAPITAL
          else if Token = 'NUMLOCK' then VK := VK_NUMLOCK
          else if Token = 'SCROLLLOCK' then VK := VK_SCROLL
          else if Token = 'PRINTSCREEN' then VK := VK_SNAPSHOT
          else if Token = 'PRTSC' then VK := VK_SNAPSHOT;
          
          if VK > 0 then
          begin
            // 按下修饰键
            if modCtrl in Modifiers then SendKeyDown(VK_CONTROL);
            if modAlt in Modifiers then SendKeyDown(VK_MENU);
            if modShift in Modifiers then SendKeyDown(VK_SHIFT);
            if modWin in Modifiers then SendKeyDown(VK_LWIN);
            
            // 按下目标键
            SendKeyPress(VK, VK in [VK_INSERT, VK_DELETE, VK_HOME, VK_END, 
              VK_PRIOR, VK_NEXT, VK_UP, VK_DOWN, VK_LEFT, VK_RIGHT]);
            
            // 释放修饰键
            if modWin in Modifiers then SendKeyUp(VK_LWIN);
            if modShift in Modifiers then SendKeyUp(VK_SHIFT);
            if modAlt in Modifiers then SendKeyUp(VK_MENU);
            if modCtrl in Modifiers then SendKeyUp(VK_CONTROL);
            
            Modifiers := [];
          end;
          
          Token := '';
        end;
      '^':
        Include(Modifiers, modCtrl);
      '!':
        Include(Modifiers, modAlt);
      '+':
        Include(Modifiers, modShift);
      '#':
        Include(Modifiers, modWin);
    else
      if InBracket then
        Token := Token + AKeys[I]
      else
      begin
        // 普通字符
        if Modifiers <> [] then
        begin
          // 有修饰键时，转换为虚拟键码
          VK := VkKeyScan(AKeys[I]) and $FF;
          
          if modCtrl in Modifiers then SendKeyDown(VK_CONTROL);
          if modAlt in Modifiers then SendKeyDown(VK_MENU);
          if modShift in Modifiers then SendKeyDown(VK_SHIFT);
          if modWin in Modifiers then SendKeyDown(VK_LWIN);
          
          SendKeyPress(VK);
          
          if modWin in Modifiers then SendKeyUp(VK_LWIN);
          if modShift in Modifiers then SendKeyUp(VK_SHIFT);
          if modAlt in Modifiers then SendKeyUp(VK_MENU);
          if modCtrl in Modifiers then SendKeyUp(VK_CONTROL);
          
          Modifiers := [];
        end
        else
        begin
          // 直接发送字符
          SendChar(AKeys[I]);
        end;
      end;
    end;
    Inc(I);
  end;
end;

class function TKeyboardMouseActions.ExecuteSendKeys(AAction: TAutomationAction): TActionResult;
var
  Keys: string;
begin
  Keys := AAction.GetParamStr('keys', '');
  if Keys = '' then
    Exit(TActionResult.Fail('Missing "keys" parameter'));
    
  try
    ParseKeyString(Keys);
    Result := TActionResult.OK;
  except
    on E: Exception do
      Result := TActionResult.Fail(E.Message);
  end;
end;

class function TKeyboardMouseActions.ExecuteSendText(AAction: TAutomationAction): TActionResult;
var
  Text: string;
begin
  Text := AAction.GetParamStr('text', '');
  if Text = '' then
    Exit(TActionResult.Fail('Missing "text" parameter'));
    
  try
    SendString(Text);
    Result := TActionResult.OK;
  except
    on E: Exception do
      Result := TActionResult.Fail(E.Message);
  end;
end;

class function TKeyboardMouseActions.ExecutePaste(AAction: TAutomationAction): TActionResult;
var
  Text: string;
begin
  Text := AAction.GetParamStr('text', '');
  
  try
    // 如果提供了文本，先设置到剪贴板
    if Text <> '' then
      Clipboard.AsText := Text;
      
    // 发送 Ctrl+V
    SendKeyDown(VK_CONTROL);
    Sleep(10);
    SendKeyPress(Ord('V'));
    Sleep(10);
    SendKeyUp(VK_CONTROL);
    
    Result := TActionResult.OK;
  except
    on E: Exception do
      Result := TActionResult.Fail(E.Message);
  end;
end;

class function TKeyboardMouseActions.ExecuteMouseClick(AAction: TAutomationAction): TActionResult;
var
  X, Y: Integer;
  Button: string;
  DoubleClick: Boolean;
  Input: array[0..1] of TInput;
  DownFlag, UpFlag: DWORD;
begin
  X := AAction.GetParamInt('x', -1);
  Y := AAction.GetParamInt('y', -1);
  Button := LowerCase(AAction.GetParamStr('button', 'left'));
  DoubleClick := AAction.GetParamBool('double', False);
  
  // 确定鼠标按钮标志
  if Button = 'right' then
  begin
    DownFlag := MOUSEEVENTF_RIGHTDOWN;
    UpFlag := MOUSEEVENTF_RIGHTUP;
  end
  else if Button = 'middle' then
  begin
    DownFlag := MOUSEEVENTF_MIDDLEDOWN;
    UpFlag := MOUSEEVENTF_MIDDLEUP;
  end
  else
  begin
    DownFlag := MOUSEEVENTF_LEFTDOWN;
    UpFlag := MOUSEEVENTF_LEFTUP;
  end;
  
  try
    // 移动鼠标到指定位置
    if (X >= 0) and (Y >= 0) then
      SetCursorPos(X, Y);
    
    // 点击
    ZeroMemory(@Input, SizeOf(Input));
    Input[0].Itype := INPUT_MOUSE;
    Input[0].mi.dwFlags := DownFlag;
    Input[1].Itype := INPUT_MOUSE;
    Input[1].mi.dwFlags := UpFlag;
    
    SendInput(2, Input[0], SizeOf(TInput));
    
    // 双击
    if DoubleClick then
    begin
      Sleep(50);
      SendInput(2, Input[0], SizeOf(TInput));
    end;
    
    Result := TActionResult.OK;
  except
    on E: Exception do
      Result := TActionResult.Fail(E.Message);
  end;
end;

class function TKeyboardMouseActions.ExecuteWaitWindow(AAction: TAutomationAction): TActionResult;
var
  Title: string;
  Timeout: Integer;
  CheckInterval: Integer;
  StartTime: Cardinal;
  hWnd: THandle;
begin
  Title := AAction.GetParamStr('title', '');
  if Title = '' then
    Exit(TActionResult.Fail('Missing "title" parameter'));
    
  Timeout := AAction.GetParamInt('timeout', 30) * 1000;  // 默认30秒
  CheckInterval := AAction.GetParamInt('interval', 500);  // 默认500ms
  
  StartTime := GetTickCount;
  
  repeat
    hwnd := FindWindowByTitle(Title, True);
    if hWnd <> 0 then
      Exit(TActionResult.OK(IntToStr(hWnd)));
      
    Sleep(CheckInterval);
  until GetTickCount - StartTime > Cardinal(Timeout);
  
  Result := TActionResult.Fail('Timeout waiting for window: ' + Title);
end;


end.
