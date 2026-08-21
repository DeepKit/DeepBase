unit DeepBase.BrowserAutomation;

interface

uses
  System.SysUtils,
  System.Classes,
  DeepBase.Browser.Types;  // BUG-BA-024 fix: IBrowserAutomationSession lives here now

const
  // BUG-BA-008 fix: explicit "no timeout" sentinel
  BROWSER_INFINITE_TIMEOUT = -1;

type
  EBrowserAutomation = class(Exception);

  TBrowserAutomationStrategy = (
    dbasAuto,
    dbasDom,
    dbasCdp,
    dbasPageDriver
  );

  TBrowserAutomationActionType = (
    baatNavigate,
    baatWaitForSelector,
    baatClick,
    baatInputText,
    baatUploadFile,
    baatGetText,
    baatExecuteScript,
    baatEvaluateScript,
    baatCallDevToolsProtocol,
    baatDelay,
    baatCaptureScreenshot,
    baatDriveInstruction
  );

  TBrowserAutomationSelectors = record
    Input: string;
    Send: string;
    Assistant: string;
    Loading: string;
    LoginCheck: string;
    NewChat: string;

    procedure Init;
    procedure LoadFromJson(const AJson: string);
    function ToJson: string;
  end;

  TBrowserAutomationWaitConfig = record
    TimeoutMs: Integer;          // Total timeout for wait operations
    StableMs: Integer;            // Stability window (for MutationObserver-based waits)
    CheckIntervalMs: Integer;     // Sleep interval between polls
    PerCallTimeoutMs: Integer;    // Per-EvaluateScript-call timeout (separate from poll interval)

    class function Default: TBrowserAutomationWaitConfig; static;
  end;

  TBrowserAutomationPolicy = record
    Strategy: TBrowserAutomationStrategy;
    StopOnError: Boolean;
    Wait: TBrowserAutomationWaitConfig;

    class function Default: TBrowserAutomationPolicy; static;
  end;

  TBrowserAutomationAction = record
    ActionType: TBrowserAutomationActionType;
    Name: string;
    Url: string;
    Selector: string;
    Text: string;
    Script: string;
    CDPMethod: string;
    CDPParams: string;
    TimeoutMs: Integer;
    DelayMs: Integer;

    procedure Init(AType: TBrowserAutomationActionType);

    class function Navigate(const AUrl: string;
      const AName: string = ''): TBrowserAutomationAction; static;
    class function WaitForSelector(const ASelector: string;
      ATimeoutMs: Integer = 0; const AName: string = ''):
      TBrowserAutomationAction; static;
    class function Click(const ASelector: string; const AName: string = ''):
      TBrowserAutomationAction; static;
    class function InputText(const ASelector, AText: string;
      const AName: string = ''): TBrowserAutomationAction; static;
    // 2026-08-06: 文件上传(CDP DOM.setFileInputFiles)——B站等视频平台投稿必需
    class function UploadFile(const ASelector, AFilePath: string;
      const AName: string = ''): TBrowserAutomationAction; static;
    class function GetText(const ASelector: string; const AName: string = ''):
      TBrowserAutomationAction; static;
    class function ExecuteScript(const AScript: string;
      const AName: string = ''): TBrowserAutomationAction; static;
    class function EvaluateScript(const AScript: string; ATimeoutMs: Integer = 0;
      const AName: string = ''): TBrowserAutomationAction; static;
    class function CallDevToolsProtocol(const AMethod, AParams: string;
      ATimeoutMs: Integer = 0; const AName: string = ''):
      TBrowserAutomationAction; static;
    class function Delay(ADelayMs: Integer; const AName: string = ''):
      TBrowserAutomationAction; static;
    class function CaptureScreenshot(const AName: string = ''):
      TBrowserAutomationAction; static;
    class function DriveInstruction(const AInstruction: string;
      const AName: string = ''): TBrowserAutomationAction; static;
  end;

  TBrowserAutomationResult = record
    Success: Boolean;
    ActionIndex: Integer;
    ActionName: string;
    ActionType: TBrowserAutomationActionType;
    Value: string;
    RawResult: string;
    BinaryData: TBytes;
    ErrorCode: string;
    ErrorMessage: string;
    DurationMs: Int64;

    class function Ok(AIndex: Integer;
      const AAction: TBrowserAutomationAction; const AValue: string = '';
      const ARawResult: string = ''; ADurationMs: Int64 = 0):
      TBrowserAutomationResult; static;
    class function Fail(AIndex: Integer;
      const AAction: TBrowserAutomationAction; const AErrorCode,
      AErrorMessage: string; const ARawResult: string = '';
      ADurationMs: Int64 = 0): TBrowserAutomationResult; static;
  end;

  IBrowserAutomationSession = DeepBase.Browser.Types.IBrowserAutomationSession;

  TDriveCallback = reference to function(const AInstruction: string;
    out AValue: string; out AError: string): Boolean;

  TBrowserAutomationScripts = class
  public
    class function JavaScriptString(const AValue: string): string; static;
    class function BuildExistsScript(const ASelector: string): string; static;
    class function BuildClickScript(const ASelector: string): string; static;
    class function BuildInputTextScript(const ASelector, AText: string):
      string; static;
    class function BuildGetTextScript(const ASelector: string): string; static;
  end;

  TBrowserAutomationRunner = class
  private
    FSession: IBrowserAutomationSession;
    FPolicy: TBrowserAutomationPolicy;
    FDriveCallback: TDriveCallback;

    function EffectiveTimeout(const AAction: TBrowserAutomationAction): Integer;
    function RunAction(const AAction: TBrowserAutomationAction;
      AIndex: Integer): TBrowserAutomationResult;
    function WaitForSelector(const AAction: TBrowserAutomationAction;
      AIndex: Integer): TBrowserAutomationResult;
  public
    constructor Create(const ASession: IBrowserAutomationSession); overload;
    constructor Create(const ASession: IBrowserAutomationSession;
      const APolicy: TBrowserAutomationPolicy); overload;

    function Run(const AActions: TArray<TBrowserAutomationAction>):
      TArray<TBrowserAutomationResult>;

    property Session: IBrowserAutomationSession read FSession write FSession;
    property Policy: TBrowserAutomationPolicy read FPolicy write FPolicy;
    property DriveCallback: TDriveCallback
      read FDriveCallback write FDriveCallback;
  end;

function BrowserAutomationActionTypeToString(
  AValue: TBrowserAutomationActionType): string;

// BUG-BA-011: exposed so other Browser units (e.g., SelectorManager) can
// safely interpret CDP-shaped boolean results without re-inventing the parser.
function TryJsonBool(const AText: string; out AValue: Boolean): Boolean;

implementation

uses
  System.JSON,
  System.Math,
  System.Diagnostics,
  DeepBase.Browser.ScriptStore;

// BUG-BA-006 fix: unified bool literal recognition.
// Both JsonValueAsBool and TryJsonBool accept the same set of literals:
//   true:  'true', '1', 'yes', 'y', 'on'
//   false: anything else (with explicit handling for 'false', '0', 'no', 'n', 'off')
function IsBoolTrueLiteral(const AText: string): Boolean;
begin
  Result := SameText(AText, 'true') or (AText = '1') or
    SameText(AText, 'yes') or SameText(AText, 'y') or
    SameText(AText, 'on');
end;

function IsBoolFalseLiteral(const AText: string): Boolean;
begin
  Result := SameText(AText, 'false') or (AText = '0') or
    SameText(AText, 'no') or SameText(AText, 'n') or
    SameText(AText, 'off');
end;

function JsonValueAsBool(AValue: TJSONValue; ADefault: Boolean): Boolean;
begin
  Result := ADefault;
  if AValue = nil then
    Exit;

  if AValue is TJSONTrue then
    Exit(True);
  if AValue is TJSONFalse then
    Exit(False);

  Result := IsBoolTrueLiteral(AValue.Value);
end;

function TryJsonBool(const AText: string; out AValue: Boolean): Boolean;
var
  LJson: TJSONValue;
  LObj: TJSONObject;
  LValue: TJSONValue;
  LText: string;
begin
  Result := True;
  LText := Trim(AText);

  if IsBoolTrueLiteral(LText) then
  begin
    AValue := True;
    Exit;
  end;

  if IsBoolFalseLiteral(LText) then
  begin
    AValue := False;
    Exit;
  end;

  Result := False;
  LJson := TJSONObject.ParseJSONValue(LText);
  if LJson = nil then
    Exit;
  try
    if (LJson is TJSONTrue) or (LJson is TJSONFalse) then
    begin
      AValue := JsonValueAsBool(LJson, False);
      Exit(True);
    end;

    if LJson is TJSONObject then
    begin
      LObj := LJson as TJSONObject;
      LValue := LObj.GetValue('success');
      if LValue = nil then
        LValue := LObj.GetValue('exists');
      if LValue = nil then
        LValue := LObj.GetValue('value');
      if LValue <> nil then
      begin
        AValue := JsonValueAsBool(LValue, False);
        Exit(True);
      end;
    end;
  finally
    LJson.Free;
  end;
end;

function TryJsonString(const AText: string; out AValue: string): Boolean;
var
  LJson: TJSONValue;
  LObj: TJSONObject;
  LValue: TJSONValue;
begin
  Result := False;
  AValue := '';
  LJson := TJSONObject.ParseJSONValue(Trim(AText));
  if LJson = nil then
  begin
    AValue := AText;
    Exit(False);
  end;
  try
    // BUG-BA-007 fix: explicit JSON null handling - return empty + Result=False
    if LJson is TJSONNull then
    begin
      AValue := '';
      Exit(False);
    end;

    if LJson is TJSONString then
    begin
      AValue := LJson.Value;
      Exit(True);
    end;

    if LJson is TJSONObject then
    begin
      LObj := LJson as TJSONObject;
      LValue := LObj.GetValue('value');
      if LValue = nil then
        LValue := LObj.GetValue('text');
      if LValue <> nil then
      begin
        // Also handle null inside object
        if LValue is TJSONNull then
        begin
          AValue := '';
          Exit(False);
        end;
        AValue := LValue.Value;
        Exit(True);
      end;
    end;

    AValue := LJson.Value;
    Result := True;
  finally
    LJson.Free;
  end;
end;

// BUG-BA-002 fix: extract 'error' field from JS payload like {"success":false,"error":"not_found"}
function ExtractJsonError(const AText: string): string;
var
  LJson: TJSONValue;
  LObj: TJSONObject;
  LValue: TJSONValue;
begin
  Result := '';
  if Trim(AText) = '' then
    Exit;
  LJson := TJSONObject.ParseJSONValue(Trim(AText));
  if LJson = nil then
    Exit;
  try
    if LJson is TJSONObject then
    begin
      LObj := LJson as TJSONObject;
      LValue := LObj.GetValue('error');
      if LValue = nil then
        LValue := LObj.GetValue('message');
      if LValue <> nil then
        Result := LValue.Value;
    end;
  finally
    LJson.Free;
  end;
end;

// BUG-BA-003 fix: parse {found, text, error} structured response from BuildGetTextScript
function TryJsonGetText(const AText: string; out AFound: Boolean;
  out AText2: string; var AError: string): Boolean;
var
  LJson: TJSONValue;
  LObj: TJSONObject;
  LFoundValue: TJSONValue;
  LTextValue: TJSONValue;
  LErrValue: TJSONValue;
begin
  Result := False;
  AFound := False;
  AText2 := '';

  if Trim(AText) = '' then
    Exit;

  LJson := TJSONObject.ParseJSONValue(Trim(AText));
  if LJson = nil then
    Exit;
  try
    if not (LJson is TJSONObject) then
      Exit;

    LObj := LJson as TJSONObject;
    LFoundValue := LObj.GetValue('found');
    if LFoundValue = nil then
      Exit;

    AFound := JsonValueAsBool(LFoundValue, False);
    LTextValue := LObj.GetValue('text');
    if LTextValue <> nil then
      AText2 := LTextValue.Value;

    LErrValue := LObj.GetValue('error');
    if (LErrValue <> nil) and (AError = '') then
      AError := LErrValue.Value;

    Result := True;
  finally
    LJson.Free;
  end;
end;

function BrowserAutomationActionTypeToString(
  AValue: TBrowserAutomationActionType): string;
begin
  case AValue of
    baatNavigate: Result := 'navigate';
    baatWaitForSelector: Result := 'wait_for_selector';
    baatClick: Result := 'click';
    baatInputText: Result := 'input_text';
    baatUploadFile: Result := 'upload_file';
    baatGetText: Result := 'get_text';
    baatExecuteScript: Result := 'execute_script';
    baatEvaluateScript: Result := 'evaluate_script';
    baatCallDevToolsProtocol: Result := 'call_devtools_protocol';
    baatDelay: Result := 'delay';
    baatCaptureScreenshot: Result := 'capture_screenshot';
    baatDriveInstruction: Result := 'drive_instruction';
  else
    Result := 'unknown';
  end;
end;

{ TBrowserAutomationSelectors }

procedure TBrowserAutomationSelectors.Init;
begin
  Input := '';
  Send := '';
  Assistant := '';
  Loading := '';
  LoginCheck := '';
  NewChat := '';
end;

procedure TBrowserAutomationSelectors.LoadFromJson(const AJson: string);
var
  LJson: TJSONValue;
  LObj: TJSONObject;
begin
  // BUG-BA-005 fix: only Init when input is valid JSON object
  // (preserves existing field values when given empty/invalid JSON)
  if Trim(AJson) = '' then
    Exit;

  LJson := TJSONObject.ParseJSONValue(AJson);
  if not (LJson is TJSONObject) then
  begin
    LJson.Free;
    Exit;
  end;

  Init;  // Only reset when we know we have a valid object to load from
  LObj := LJson as TJSONObject;
  try
    Input := LObj.GetValue<string>('input', '');
    Send := LObj.GetValue<string>('send', '');
    Assistant := LObj.GetValue<string>('assistant', '');
    Loading := LObj.GetValue<string>('loading', '');
    LoginCheck := LObj.GetValue<string>('login_check', '');
    NewChat := LObj.GetValue<string>('new_chat', '');
  finally
    LJson.Free;
  end;
end;

function TBrowserAutomationSelectors.ToJson: string;
var
  LObj: TJSONObject;
begin
  LObj := TJSONObject.Create;
  try
    LObj.AddPair('input', Input);
    LObj.AddPair('send', Send);
    LObj.AddPair('assistant', Assistant);
    LObj.AddPair('loading', Loading);
    LObj.AddPair('login_check', LoginCheck);
    LObj.AddPair('new_chat', NewChat);
    Result := LObj.ToJSON;
  finally
    LObj.Free;
  end;
end;

{ TBrowserAutomationWaitConfig }

class function TBrowserAutomationWaitConfig.Default:
  TBrowserAutomationWaitConfig;
begin
  Result.TimeoutMs := 60000;
  Result.StableMs := 0;
  Result.CheckIntervalMs := 250;
  Result.PerCallTimeoutMs := 5000;  // BUG-BA-001 fix: independent per-call timeout
end;

{ TBrowserAutomationPolicy }

class function TBrowserAutomationPolicy.Default: TBrowserAutomationPolicy;
begin
  Result.Strategy := dbasAuto;
  Result.StopOnError := True;
  Result.Wait := TBrowserAutomationWaitConfig.Default;
end;

{ TBrowserAutomationAction }

procedure TBrowserAutomationAction.Init(AType: TBrowserAutomationActionType);
begin
  Self := Default(TBrowserAutomationAction);
  ActionType := AType;
end;

class function TBrowserAutomationAction.Navigate(const AUrl,
  AName: string): TBrowserAutomationAction;
begin
  Result.Init(baatNavigate);
  Result.Url := AUrl;
  Result.Name := AName;
end;

class function TBrowserAutomationAction.WaitForSelector(const ASelector: string;
  ATimeoutMs: Integer; const AName: string): TBrowserAutomationAction;
begin
  Result.Init(baatWaitForSelector);
  Result.Selector := ASelector;
  Result.TimeoutMs := ATimeoutMs;
  Result.Name := AName;
end;

class function TBrowserAutomationAction.Click(const ASelector,
  AName: string): TBrowserAutomationAction;
begin
  Result.Init(baatClick);
  Result.Selector := ASelector;
  Result.Name := AName;
end;

class function TBrowserAutomationAction.InputText(const ASelector, AText,
  AName: string): TBrowserAutomationAction;
begin
  Result.Init(baatInputText);
  Result.Selector := ASelector;
  Result.Text := AText;
  Result.Name := AName;
end;

class function TBrowserAutomationAction.UploadFile(const ASelector,
  AFilePath, AName: string): TBrowserAutomationAction;
begin
  Result.Init(baatUploadFile);
  Result.Selector := ASelector;
  Result.Text := AFilePath;
  Result.Name := AName;
end;

class function TBrowserAutomationAction.GetText(const ASelector,
  AName: string): TBrowserAutomationAction;
begin
  Result.Init(baatGetText);
  Result.Selector := ASelector;
  Result.Name := AName;
end;

class function TBrowserAutomationAction.ExecuteScript(const AScript,
  AName: string): TBrowserAutomationAction;
begin
  Result.Init(baatExecuteScript);
  Result.Script := AScript;
  Result.Name := AName;
end;

class function TBrowserAutomationAction.EvaluateScript(const AScript: string;
  ATimeoutMs: Integer; const AName: string): TBrowserAutomationAction;
begin
  Result.Init(baatEvaluateScript);
  Result.Script := AScript;
  Result.TimeoutMs := ATimeoutMs;
  Result.Name := AName;
end;

class function TBrowserAutomationAction.CallDevToolsProtocol(
  const AMethod, AParams: string; ATimeoutMs: Integer;
  const AName: string): TBrowserAutomationAction;
begin
  Result.Init(baatCallDevToolsProtocol);
  Result.CDPMethod := AMethod;
  Result.CDPParams := AParams;
  Result.TimeoutMs := ATimeoutMs;
  Result.Name := AName;
end;

class function TBrowserAutomationAction.Delay(ADelayMs: Integer;
  const AName: string): TBrowserAutomationAction;
begin
  Result.Init(baatDelay);
  Result.DelayMs := ADelayMs;
  Result.Name := AName;
end;

class function TBrowserAutomationAction.CaptureScreenshot(
  const AName: string): TBrowserAutomationAction;
begin
  Result.Init(baatCaptureScreenshot);
  Result.Name := AName;
end;

class function TBrowserAutomationAction.DriveInstruction(
  const AInstruction, AName: string): TBrowserAutomationAction;
begin
  Result.Init(baatDriveInstruction);
  Result.Text := AInstruction;
  Result.Name := AName;
end;

{ TBrowserAutomationResult }

class function TBrowserAutomationResult.Ok(AIndex: Integer;
  const AAction: TBrowserAutomationAction; const AValue, ARawResult: string;
  ADurationMs: Int64): TBrowserAutomationResult;
begin
  Result := Default(TBrowserAutomationResult);
  Result.Success := True;
  Result.ActionIndex := AIndex;
  Result.ActionName := AAction.Name;
  Result.ActionType := AAction.ActionType;
  Result.Value := AValue;
  Result.RawResult := ARawResult;
  Result.DurationMs := ADurationMs;
end;

class function TBrowserAutomationResult.Fail(AIndex: Integer;
  const AAction: TBrowserAutomationAction; const AErrorCode, AErrorMessage,
  ARawResult: string; ADurationMs: Int64): TBrowserAutomationResult;
begin
  Result := Default(TBrowserAutomationResult);
  Result.Success := False;
  Result.ActionIndex := AIndex;
  Result.ActionName := AAction.Name;
  Result.ActionType := AAction.ActionType;
  Result.ErrorCode := AErrorCode;
  Result.ErrorMessage := AErrorMessage;
  Result.RawResult := ARawResult;
  Result.DurationMs := ADurationMs;
end;

{ TBrowserAutomationScripts }

class function TBrowserAutomationScripts.JavaScriptString(
  const AValue: string): string;
var
  LJson: TJSONString;
begin
  LJson := TJSONString.Create(AValue);
  try
    Result := LJson.ToJSON;
  finally
    LJson.Free;
  end;
end;

class function TBrowserAutomationScripts.BuildExistsScript(
  const ASelector: string): string;
begin
  // M6 fix: prefer ScriptStore template (database-backed, hot-replaceable);
  // fall back to inline JS only if the named template was deactivated.
  Result := ScriptStore.Render(JSCRIPT_EXISTS, ['selector', ASelector]);
  if Result <> '' then
    Exit;
  Result :=
    '(function(){' +
    'try{' +
    'return document.querySelector(' + JavaScriptString(ASelector) +
    ')!==null;' +
    '}catch(e){return false;}' +
    '})();';
end;

class function TBrowserAutomationScripts.BuildClickScript(
  const ASelector: string): string;
begin
  // M6 fix: ScriptStore-first.
  Result := ScriptStore.Render(JSCRIPT_CLICK, ['selector', ASelector]);
  if Result <> '' then
    Exit;
  Result :=
    '(function(){' +
    'try{' +
    'var el=document.querySelector(' + JavaScriptString(ASelector) + ');' +
    'if(!el)return {success:false,error:"not_found"};' +
    'if(el.scrollIntoView)el.scrollIntoView({block:"center",inline:"center"});' +
    'el.click();' +
    'return {success:true};' +
    '}catch(e){return {success:false,error:String(e)}}' +
    '})();';
end;

class function TBrowserAutomationScripts.BuildInputTextScript(
  const ASelector, AText: string): string;
begin
  // M6 fix: ScriptStore-first.
  Result := ScriptStore.Render(JSCRIPT_INPUT_TEXT,
    ['selector', ASelector, 'text', AText]);
  if Result <> '' then
    Exit;
  Result :=
    '(function(){' +
    'try{' +
    'var el=document.querySelector(' + JavaScriptString(ASelector) + ');' +
    'var text=' + JavaScriptString(AText) + ';' +
    'if(!el)return {success:false,error:"not_found"};' +
    'if(el.scrollIntoView)el.scrollIntoView({block:"center",inline:"center"});' +
    'if(el.focus)el.focus();' +
    // CP-LOGIN-R1 fix (2026-08-22): React 受控组件必须走原生 setter 才会更新
    // 组件内部 state，直接 el.value=text 会被 React 的 value tracker 覆盖，
    // 发送按钮保持 disabled → 点击无效 → wait_response 永不命中。
    // 走 HTMLTextAreaElement/HTMLInputElement 原型 setter，对受控/非受控通用。
    'try{' +
    '  var proto=null;' +
    '  if(el instanceof HTMLTextAreaElement){proto=HTMLTextAreaElement.prototype;}' +
    '  else if(el instanceof HTMLInputElement){proto=HTMLInputElement.prototype;}' +
    '  var setter=proto&&Object.getOwnPropertyDescriptor(proto,"value").set;' +
    '  if(setter){setter.call(el,text);}' +
    '  else{if("value" in el){el.value=text;}else{el.textContent=text;}}' +
    '}catch(e){if("value" in el){el.value=text;}else{el.textContent=text;}}' +
    'el.dispatchEvent(new Event("input",{bubbles:true}));' +
    'el.dispatchEvent(new Event("change",{bubbles:true}));' +
    'return {success:true};' +
    '}catch(e){return {success:false,error:String(e)}}' +
    '})();';
end;

class function TBrowserAutomationScripts.BuildGetTextScript(
  const ASelector: string): string;
begin
  // M6 fix: ScriptStore-first.
  // BUG-BA-003 fix: distinguish 3 cases via {found, text, error}
  //   Element not found     -> {"found":false}
  //   Empty text (real)     -> {"found":true,"text":""}
  //   Exception             -> {"found":false,"error":"<msg>"}
  Result := ScriptStore.Render(JSCRIPT_GET_TEXT, ['selector', ASelector]);
  if Result <> '' then
    Exit;
  Result :=
    '(function(){' +
    'try{' +
    'var list=document.querySelectorAll(' + JavaScriptString(ASelector) + ');' +
    'if(!list||list.length===0)return {found:false};' +
    'var el=list[list.length-1];' +
    'return {found:true,text:(el.innerText||el.textContent||"")};' +
    '}catch(e){return {found:false,error:String(e)}}' +
    '})();';
end;

{ TBrowserAutomationRunner }

constructor TBrowserAutomationRunner.Create(
  const ASession: IBrowserAutomationSession);
begin
  Create(ASession, TBrowserAutomationPolicy.Default);
end;

constructor TBrowserAutomationRunner.Create(
  const ASession: IBrowserAutomationSession;
  const APolicy: TBrowserAutomationPolicy);
begin
  inherited Create;
  FSession := ASession;
  FPolicy := APolicy;
end;

function TBrowserAutomationRunner.EffectiveTimeout(
  const AAction: TBrowserAutomationAction): Integer;
begin
  Result := AAction.TimeoutMs;
  // BUG-BA-008 fix: preserve explicit -1 sentinel for "no timeout"
  if Result = BROWSER_INFINITE_TIMEOUT then
    Exit;
  if Result <= 0 then
    Result := FPolicy.Wait.TimeoutMs;
end;

function TBrowserAutomationRunner.WaitForSelector(
  const AAction: TBrowserAutomationAction;
  AIndex: Integer): TBrowserAutomationResult;
var
  LTimer: TStopwatch;
  LRaw: string;
  LError: string;
  LExists: Boolean;
  LTimeout: Integer;
  LInterval: Integer;
  LPerCallTimeout: Integer;
  LSleepMs: Integer;
  LRemainingMs: Int64;
  LEvalStartMs: Int64;
  LEvalDurationMs: Int64;
begin
  if Trim(AAction.Selector) = '' then
    Exit(TBrowserAutomationResult.Fail(AIndex, AAction, 'missing_selector',
      'Selector is required'));

  LTimeout := EffectiveTimeout(AAction);
  LInterval := Max(25, FPolicy.Wait.CheckIntervalMs);
  // BUG-BA-001 fix: per-call timeout independent of polling interval
  LPerCallTimeout := FPolicy.Wait.PerCallTimeoutMs;
  if LPerCallTimeout <= 0 then
    LPerCallTimeout := 5000;
  LTimer := TStopwatch.StartNew;

  repeat
    LRaw := '';
    LError := '';
    // BUG-BA-004 fix: track eval duration to compensate sleep
    LEvalStartMs := LTimer.ElapsedMilliseconds;
    if FSession.EvaluateScript(
      TBrowserAutomationScripts.BuildExistsScript(AAction.Selector),
      LPerCallTimeout, LRaw, LError) and TryJsonBool(LRaw, LExists) and LExists then
      Exit(TBrowserAutomationResult.Ok(AIndex, AAction, AAction.Selector,
        LRaw, LTimer.ElapsedMilliseconds));
    LEvalDurationMs := LTimer.ElapsedMilliseconds - LEvalStartMs;

    // BUG-BA-008 fix: when LTimeout is BROWSER_INFINITE_TIMEOUT, never break on timeout
    if (LTimeout <> BROWSER_INFINITE_TIMEOUT) and
       ((LTimeout <= 0) or (LTimer.ElapsedMilliseconds >= LTimeout)) then
      Break;

    // BUG-BA-004 fix: subtract eval duration from sleep so true poll interval
    // matches CheckIntervalMs (not eval+CheckIntervalMs)
    LSleepMs := LInterval - Integer(LEvalDurationMs);
    if LSleepMs < 0 then
      LSleepMs := 0;
    if LTimeout <> BROWSER_INFINITE_TIMEOUT then
    begin
      LRemainingMs := LTimeout - LTimer.ElapsedMilliseconds;
      if LRemainingMs < LSleepMs then
      begin
        if LRemainingMs > 0 then
          LSleepMs := Integer(LRemainingMs)
        else
          LSleepMs := 0;
      end;
    end;
    if LSleepMs > 0 then
      TThread.Sleep(LSleepMs);
  until False;

  if LError = '' then
    LError := 'Selector was not found before timeout';
  Result := TBrowserAutomationResult.Fail(AIndex, AAction, 'timeout', LError,
    LRaw, LTimer.ElapsedMilliseconds);
end;

function TBrowserAutomationRunner.RunAction(
  const AAction: TBrowserAutomationAction;
  AIndex: Integer): TBrowserAutomationResult;
var
  LTimer: TStopwatch;
  LError: string;
  LRaw: string;
  LText: string;
  LBool: Boolean;
  LFound: Boolean;
  LImage: TBytes;
begin
  if FSession = nil then
    Exit(TBrowserAutomationResult.Fail(AIndex, AAction, 'no_session',
      'Browser automation session is not assigned'));

  if not FSession.IsReady then
    Exit(TBrowserAutomationResult.Fail(AIndex, AAction, 'session_not_ready',
      FSession.GetLastError));

  if AAction.ActionType = baatWaitForSelector then
    Exit(WaitForSelector(AAction, AIndex));

  LTimer := TStopwatch.StartNew;
  LError := '';
  LRaw := '';

  case AAction.ActionType of
    baatNavigate:
      begin
        if FSession.Navigate(AAction.Url, EffectiveTimeout(AAction), LError) then
          Result := TBrowserAutomationResult.Ok(AIndex, AAction, AAction.Url,
            '', LTimer.ElapsedMilliseconds)
        else
          Result := TBrowserAutomationResult.Fail(AIndex, AAction,
            'navigate_failed', LError, '', LTimer.ElapsedMilliseconds);
      end;

    baatClick:
      begin
        if FSession.EvaluateScript(
          TBrowserAutomationScripts.BuildClickScript(AAction.Selector),
          EffectiveTimeout(AAction), LRaw, LError) and
          TryJsonBool(LRaw, LBool) and LBool then
          Result := TBrowserAutomationResult.Ok(AIndex, AAction,
            AAction.Selector, LRaw, LTimer.ElapsedMilliseconds)
        else
        begin
          // BUG-BA-002 fix: prefer JS payload error over transport error
          if (LError = '') and (LRaw <> '') then
            LError := ExtractJsonError(LRaw);
          Result := TBrowserAutomationResult.Fail(AIndex, AAction,
            'click_failed', LError, LRaw, LTimer.ElapsedMilliseconds);
        end;
      end;

    baatInputText:
      begin
        if FSession.EvaluateScript(
          TBrowserAutomationScripts.BuildInputTextScript(AAction.Selector,
            AAction.Text), EffectiveTimeout(AAction), LRaw, LError) and
          TryJsonBool(LRaw, LBool) and LBool then
          Result := TBrowserAutomationResult.Ok(AIndex, AAction,
            AAction.Selector, LRaw, LTimer.ElapsedMilliseconds)
        else
        begin
          // BUG-BA-002 fix: prefer JS payload error over transport error
          if (LError = '') and (LRaw <> '') then
            LError := ExtractJsonError(LRaw);
          Result := TBrowserAutomationResult.Fail(AIndex, AAction,
            'input_failed', LError, LRaw, LTimer.ElapsedMilliseconds);
        end;
      end;

    baatUploadFile:
      begin
        // 2026-08-06: CDP DOM.setFileInputFiles 三步(getDocument -> querySelector -> setFileInputFiles)
        // B站/视频平台 file input 上传必需; JS 无法赋值 file input(浏览器安全限制)
        var LDocRaw, LQueryRaw, LSetRaw, LErr: string;
        var LDocObj, LResObj, LQueryObj, LQueryObj2, LSetObj: TJSONObject;
        var LRootId, LTargetId: string;
        LRootId := '';
        LTargetId := '';
        if FSession.CallDevToolsProtocol('DOM.getDocument', '{"depth":1}',
          EffectiveTimeout(AAction), LDocRaw, LErr) then
        begin
          LDocObj := TJSONObject.ParseJSONValue(LDocRaw) as TJSONObject;
          try
            if Assigned(LDocObj) then
            begin
              LResObj := LDocObj.GetValue('result') as TJSONObject;
              if Assigned(LResObj) then
              begin
                var LRoot := LResObj.GetValue('root') as TJSONObject;
                if Assigned(LRoot) then
                  LRootId := LRoot.GetValue<string>('nodeId');
              end;
            end;
          finally
            LDocObj.Free;
          end;
        end;
        if LRootId = '' then
          Result := TBrowserAutomationResult.Fail(AIndex, AAction,
            'upload_failed', 'DOM.getDocument no root nodeId: ' + LErr, LDocRaw,
            LTimer.ElapsedMilliseconds)
        else
        begin
          LQueryObj := TJSONObject.Create;
          LQueryObj.AddPair('nodeId', LRootId);
          LQueryObj.AddPair('selector', AAction.Selector);
          try
            if not FSession.CallDevToolsProtocol('DOM.querySelector',
              LQueryObj.ToJSON, EffectiveTimeout(AAction), LQueryRaw, LErr) then
              Result := TBrowserAutomationResult.Fail(AIndex, AAction,
                'upload_failed', 'querySelector: ' + LErr, LQueryRaw,
                LTimer.ElapsedMilliseconds)
            else
            begin
              LQueryObj2 := TJSONObject.ParseJSONValue(LQueryRaw) as TJSONObject;
              try
                if Assigned(LQueryObj2) then
                begin
                  var LRes := LQueryObj2.GetValue('result') as TJSONObject;
                  if Assigned(LRes) then
                    LTargetId := LRes.GetValue<string>('nodeId');
                end;
              finally
                LQueryObj2.Free;
              end;
              if LTargetId = '' then
                Result := TBrowserAutomationResult.Fail(AIndex, AAction,
                  'upload_failed', 'querySelector no nodeId (element not found?)',
                  LQueryRaw, LTimer.ElapsedMilliseconds)
              else
              begin
                LSetObj := TJSONObject.Create;
                LSetObj.AddPair('nodeId', LTargetId);
                var LFiles := TJSONArray.Create;
                LFiles.Add(AAction.Text);
                LSetObj.AddPair('files', LFiles);
                try
                  if FSession.CallDevToolsProtocol('DOM.setFileInputFiles',
                    LSetObj.ToJSON, EffectiveTimeout(AAction), LSetRaw, LErr) then
                    Result := TBrowserAutomationResult.Ok(AIndex, AAction,
                      AAction.Text, LSetRaw, LTimer.ElapsedMilliseconds)
                  else
                    Result := TBrowserAutomationResult.Fail(AIndex, AAction,
                      'upload_failed', LErr, LSetRaw, LTimer.ElapsedMilliseconds);
                finally
                  LSetObj.Free;
                end;
              end;
            end;
          finally
            LQueryObj.Free;
          end;
        end;
      end;

    baatGetText:
      begin
        if FSession.EvaluateScript(
          TBrowserAutomationScripts.BuildGetTextScript(AAction.Selector),
          EffectiveTimeout(AAction), LRaw, LError) then
        begin
          // BUG-BA-003 fix: parse {found, text, error} structured response
          if not TryJsonGetText(LRaw, LFound, LText, LError) then
          begin
            if LError = '' then
              LError := 'Failed to parse get_text response';
            Result := TBrowserAutomationResult.Fail(AIndex, AAction,
              'get_text_failed', LError, LRaw, LTimer.ElapsedMilliseconds);
          end
          else if not LFound then
          begin
            if LError = '' then
              LError := 'Element not found';
            Result := TBrowserAutomationResult.Fail(AIndex, AAction,
              'not_found', LError, LRaw, LTimer.ElapsedMilliseconds);
          end
          else
            Result := TBrowserAutomationResult.Ok(AIndex, AAction, LText, LRaw,
              LTimer.ElapsedMilliseconds);
        end
        else
          Result := TBrowserAutomationResult.Fail(AIndex, AAction,
            'get_text_failed', LError, LRaw, LTimer.ElapsedMilliseconds);
      end;

    baatExecuteScript:
      begin
        if FSession.ExecuteScript(AAction.Script, LError) then
          Result := TBrowserAutomationResult.Ok(AIndex, AAction, '', '',
            LTimer.ElapsedMilliseconds)
        else
          Result := TBrowserAutomationResult.Fail(AIndex, AAction,
            'script_failed', LError, '', LTimer.ElapsedMilliseconds);
      end;

    baatEvaluateScript:
      begin
        if FSession.EvaluateScript(AAction.Script, EffectiveTimeout(AAction),
          LRaw, LError) then
          Result := TBrowserAutomationResult.Ok(AIndex, AAction, LRaw, LRaw,
            LTimer.ElapsedMilliseconds)
        else
          Result := TBrowserAutomationResult.Fail(AIndex, AAction,
            'evaluate_failed', LError, LRaw, LTimer.ElapsedMilliseconds);
      end;

    baatCallDevToolsProtocol:
      begin
        if FSession.CallDevToolsProtocol(AAction.CDPMethod, AAction.CDPParams,
          EffectiveTimeout(AAction), LRaw, LError) then
          Result := TBrowserAutomationResult.Ok(AIndex, AAction, LRaw, LRaw,
            LTimer.ElapsedMilliseconds)
        else
          Result := TBrowserAutomationResult.Fail(AIndex, AAction,
            'cdp_failed', LError, LRaw, LTimer.ElapsedMilliseconds);
      end;

    baatDelay:
      begin
        if AAction.DelayMs > 0 then
          TThread.Sleep(AAction.DelayMs);
        Result := TBrowserAutomationResult.Ok(AIndex, AAction,
          IntToStr(Max(0, AAction.DelayMs)), '', LTimer.ElapsedMilliseconds);
      end;

    baatCaptureScreenshot:
      begin
        if FSession.CaptureScreenshot(LImage, LError) then
        begin
          Result := TBrowserAutomationResult.Ok(AIndex, AAction,
            IntToStr(Length(LImage)), '', LTimer.ElapsedMilliseconds);
          Result.BinaryData := LImage;
        end
        else
          Result := TBrowserAutomationResult.Fail(AIndex, AAction,
            'screenshot_failed', LError, '', LTimer.ElapsedMilliseconds);
      end;

    baatDriveInstruction:
      begin
        if not Assigned(FDriveCallback) then
          Result := TBrowserAutomationResult.Fail(AIndex, AAction,
            'no_driver', 'DriveCallback not assigned')
        else if FDriveCallback(AAction.Text, LRaw, LError) then
          Result := TBrowserAutomationResult.Ok(AIndex, AAction,
            LRaw, LRaw, LTimer.ElapsedMilliseconds)
        else
          Result := TBrowserAutomationResult.Fail(AIndex, AAction,
            'drive_failed', LError, LRaw, LTimer.ElapsedMilliseconds);
      end;
  else
    Result := TBrowserAutomationResult.Fail(AIndex, AAction,
      'unknown_action', 'Unsupported browser automation action');
  end;
end;

function TBrowserAutomationRunner.Run(
  const AActions: TArray<TBrowserAutomationAction>):
  TArray<TBrowserAutomationResult>;
var
  I: Integer;
begin
  SetLength(Result, Length(AActions));
  for I := 0 to High(AActions) do
  begin
    Result[I] := RunAction(AActions[I], I);
    if FPolicy.StopOnError and not Result[I].Success then
    begin
      SetLength(Result, I + 1);
      Exit;
    end;
  end;
end;

end.
