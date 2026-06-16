unit Tray.Types;

{*******************************************************************************
  DeepBaseTray - 共享类型定义

  存放自动化模块共用的类型，打破 Tray.Automation 与 Tray.KeyboardMouse
  之间的循环依赖。
*******************************************************************************}

interface

uses
  System.SysUtils, System.JSON;

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

function ActionTypeFromString(const AStr: string): TActionType;
function ActionTypeToString(AType: TActionType): string;

implementation

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

end.
