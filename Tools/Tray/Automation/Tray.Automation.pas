unit Tray.Automation;

{*******************************************************************************
  UniBaseTray - 自动化脚本引擎
  
  功能:
  - 解析和执行 JSON 格式的自动化脚本
  - 支持多种 Action 类型
  - 错误处理和日志记录
  
  脚本格式示例:
  {
    "name": "重启服务",
    "steps": [
      {"action": "findWindow", "title": "服务管理器"},
      {"action": "wait", "seconds": 1},
      {"action": "runCommand", "command": "net stop MyService"},
      {"action": "wait", "seconds": 2},
      {"action": "runCommand", "command": "net start MyService"}
    ]
  }
*******************************************************************************}

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.ShellAPI, Winapi.TlHelp32,
  System.SysUtils, System.Classes, System.JSON, System.Generics.Collections,
  System.DateUtils,
  UniBase.Exceptions;

type
  { Action 执行结果 }
  TActionResult = record
    Success: Boolean;
    ErrorMessage: string;
    OutputData: string;
    class function OK(const AOutput: string = ''): TActionResult; static;
    class function Fail(const AError: string): TActionResult; static;
  end;
  
  { Action 类型 }
  TActionType = (
    atUnknown,
    atWait,           // 等待指定秒数
    atRunCommand,     // 执行命令
    atFindWindow,     // 查找窗口
    atActivateWindow, // 激活窗口
    atKillProcess,    // 终止进程
    atSendKeys,       // 发送按键
    atSendText,       // 发送文本
    atPaste,          // 粘贴
    atMouseClick,     // 鼠标点击
    atWaitWindow,     // 等待窗口出现
    atIf              // 条件判断
  );
  
  { 单个 Action }
  TAutomationAction = class
  private
    FActionType: TActionType;
    FParams: TJSONObject;
    FOwnsParams: Boolean;
  public
    constructor Create(AType: TActionType; AParams: TJSONObject; AOwnsParams: Boolean = False);
    destructor Destroy; override;
    
    function GetParamStr(const AName: string; const ADefault: string = ''): string;
    function GetParamInt(const AName: string; ADefault: Integer = 0): Integer;
    function GetParamBool(const AName: string; ADefault: Boolean = False): Boolean;
    
    property ActionType: TActionType read FActionType;
    property Params: TJSONObject read FParams;
  end;
  
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

{ 辅助函数 }
function ActionTypeFromString(const AStr: string): TActionType;
function ActionTypeToString(AType: TActionType): string;
function FindWindowByTitle(const ATitle: string; APartialMatch: Boolean = True): HWND;
function FindProcessByName(const AName: string): DWORD;
function KillProcessByPID(APID: DWORD): Boolean;
function KillProcessByName(const AName: string): Boolean;

implementation

uses
  Tray.Launcher, Tray.KeyboardMouse;

{ TActionResult }

class function TActionResult.OK(const AOutput: string): TActionResult;
begin
  Result.Success := True;
  Result.ErrorMessage := '';
  Result.OutputData := AOutput;
end;

class function TActionResult.Fail(const AError: string): TActionResult;
begin
  Result.Success := False;
  Result.ErrorMessage := AError;
  Result.OutputData := '';
end;

{ 辅助函数 }

function ActionTypeFromString(const AStr: string): TActionType;
var
  S: string;
begin
  S := LowerCase(AStr);
  if S = 'wait' then Result := atWait
  else if S = 'runcommand' then Result := atRunCommand
  else if S = 'findwindow' then Result := atFindWindow
  else if S = 'activatewindow' then Result := atActivateWindow
  else if S = 'killprocess' then Result := atKillProcess
  else if S = 'sendkeys' then Result := atSendKeys
  else if S = 'sendtext' then Result := atSendText
  else if S = 'paste' then Result := atPaste
  else if S = 'mouseclick' then Result := atMouseClick
  else if S = 'waitwindow' then Result := atWaitWindow
  else if S = 'if' then Result := atIf
  else Result := atUnknown;
end;

function ActionTypeToString(AType: TActionType): string;
begin
  case AType of
    atWait: Result := 'wait';
    atRunCommand: Result := 'runCommand';
    atFindWindow: Result := 'findWindow';
    atActivateWindow: Result := 'activateWindow';
    atKillProcess: Result := 'killProcess';
    atSendKeys: Result := 'sendKeys';
    atSendText: Result := 'sendText';
    atPaste: Result := 'paste';
    atMouseClick: Result := 'mouseClick';
    atWaitWindow: Result := 'waitWindow';
    atIf: Result := 'if';
  else
    Result := 'unknown';
  end;
end;

type
  TEnumWindowData = record
    Title: string;
    PartialMatch: Boolean;
    FoundHandle: HWND;
  end;
  PEnumWindowData = ^TEnumWindowData;

function EnumWindowsCallback(hwnd: HWND; lParam: LPARAM): BOOL; stdcall;
var
  Data: PEnumWindowData;
  WindowTitle: array[0..255] of Char;
  Title: string;
begin
  Result := True;  // 继续枚举
  Data := PEnumWindowData(lParam);
  
  if GetWindowText(hwnd, WindowTitle, Length(WindowTitle)) > 0 then
  begin
    Title := string(WindowTitle);
    if Data.PartialMatch then
    begin
      if Pos(UpperCase(Data.Title), UpperCase(Title)) > 0 then
      begin
        Data.FoundHandle := hwnd;
        Result := False;  // 停止枚举
      end;
    end
    else
    begin
      if SameText(Title, Data.Title) then
      begin
        Data.FoundHandle := hwnd;
        Result := False;
      end;
    end;
  end;
end;

function FindWindowByTitle(const ATitle: string; APartialMatch: Boolean): HWND;
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

{ TAutomationAction }

constructor TAutomationAction.Create(AType: TActionType; AParams: TJSONObject; AOwnsParams: Boolean);
begin
  inherited Create;
  FActionType := AType;
  FParams := AParams;
  FOwnsParams := AOwnsParams;
end;

destructor TAutomationAction.Destroy;
begin
  if FOwnsParams and Assigned(FParams) then
    FParams.Free;
  inherited;
end;

function TAutomationAction.GetParamStr(const AName, ADefault: string): string;
var
  JV: TJSONValue;
begin
  Result := ADefault;
  if FParams = nil then Exit;
  
  JV := FParams.GetValue(AName);
  if Assigned(JV) then
    Result := JV.Value;
end;

function TAutomationAction.GetParamInt(const AName: string; ADefault: Integer): Integer;
var
  JV: TJSONValue;
begin
  Result := ADefault;
  if FParams = nil then Exit;
  
  JV := FParams.GetValue(AName);
  if Assigned(JV) then
    Result := StrToIntDef(JV.Value, ADefault);
end;

function TAutomationAction.GetParamBool(const AName: string; ADefault: Boolean): Boolean;
var
  JV: TJSONValue;
begin
  Result := ADefault;
  if FParams = nil then Exit;
  
  JV := FParams.GetValue(AName);
  if Assigned(JV) then
  begin
    if JV is TJSONBool then
      Result := TJSONBool(JV).AsBoolean
    else
      Result := SameText(JV.Value, 'true') or (JV.Value = '1');
  end;
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
      // TODO: 实现等待命令完成
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
  hwnd: HWND;
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
    
  if hwnd <> 0 then
    Result := TActionResult.OK(IntToStr(hwnd))
  else
    Result := TActionResult.Fail('Window not found');
end;

function TScriptExecutor.ExecuteActivateWindow(AAction: TAutomationAction): TActionResult;
var
  Title: string;
  hwnd: HWND;
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
    
  if hwnd = 0 then
    Exit(TActionResult.Fail('Window not found'));
    
  // 恢复窗口（如果最小化）
  if IsIconic(hwnd) then
    ShowWindow(hwnd, SW_RESTORE);
    
  // 激活窗口
  SetForegroundWindow(hwnd);
  
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

end.
