unit Tray.KeyboardMouse;

{*******************************************************************************
  UniBaseTray - 键盘鼠标自动化模块
  
  功能:
  - sendKeys: 发送按键组合
  - sendText: 发送文本
  - paste: 粘贴剪贴板内容
  - mouseClick: 鼠标点击
  - waitWindow: 等待窗口出现
*******************************************************************************}

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Classes,
  Vcl.Clipbrd,
  Tray.Automation;

type
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

implementation

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
  hwnd: HWND;
begin
  Title := AAction.GetParamStr('title', '');
  if Title = '' then
    Exit(TActionResult.Fail('Missing "title" parameter'));
    
  Timeout := AAction.GetParamInt('timeout', 30) * 1000;  // 默认30秒
  CheckInterval := AAction.GetParamInt('interval', 500);  // 默认500ms
  
  StartTime := GetTickCount;
  
  repeat
    hwnd := FindWindowByTitle(Title, True);
    if hwnd <> 0 then
      Exit(TActionResult.OK(IntToStr(hwnd)));
      
    Sleep(CheckInterval);
  until GetTickCount - StartTime > Cardinal(Timeout);
  
  Result := TActionResult.Fail('Timeout waiting for window: ' + Title);
end;

end.
