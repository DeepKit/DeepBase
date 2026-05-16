{ ============================================================================
  DeepBase.Browser.PageDriver
  ---------------------------------------------------------------------------
  Version     : 2.0
  Description : DeepBase native natural-language page driver.

                The implementation keeps the useful product shape from modern
                in-page agents: dehydrate the DOM into indexed interactive
                elements, let an LLM choose one constrained action, execute the
                action through a small local JS bridge, then observe again.

                Runtime dependency note:
                This unit does not load third-party browser extensions or CDN
                bundles. The browser only receives the DeepBase JS bridge below;
                planning and auditing stay in Delphi.
  ============================================================================ }

unit DeepBase.Browser.PageDriver;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.JSON,
  System.Generics.Collections,
  DeepBase.Browser.Types,
  DeepBase.BrowserAutomation;

type
  EBrowserPageDriverError = class(EBrowserAutomation);

  TPageDriverStatus = (
    pdsNotLoaded,
    pdsLoading,
    pdsReady,
    pdsExecuting,
    pdsError
  );

  TPageDriverResult = record
    Success: Boolean;
    Action: string;
    Description: string;
    DurationMs: Int64;
    RawResponse: string;
    ErrorMessage: string;
  end;

  TPageDriverConfig = record
    Model: string;
    BaseURL: string;
    ApiKey: string;
    Language: string;
    MaxSteps: Integer;
    TimeoutMs: Integer;
    // Kept for source compatibility with older callers. Native PageDriver
    // intentionally ignores external bundles.
    BundleUrl: string;

    class function Default: TPageDriverConfig; static;
  end;

  IPageDriver = interface
    ['{F1A2B3C4-D5E6-7890-ABCD-EF1234567890}']
    function GetStatus: TPageDriverStatus;
    function GetConfig: TPageDriverConfig;

    function Load(ASession: IBrowserAutomationSession): Boolean;
    function Execute(const AInstruction: string;
      out AResult: TPageDriverResult): Boolean;
    function IsReady: Boolean;
    procedure Unload;

    property Status: TPageDriverStatus read GetStatus;
    property Config: TPageDriverConfig read GetConfig;
  end;

  TPageDriverJS = class
  public
    class function BuildLoaderScript(
      const AConfig: TPageDriverConfig): string; static;
    class function BuildExecuteScript(const AActionJson: string;
      AMaxSteps: Integer = 0): string; static;
    class function BuildStatusScript: string; static;
    class function BuildSnapshotScript: string; static;
    class function BuildUnloadScript: string; static;
    class function ParseResult(const AJson: string;
      out AResult: TPageDriverResult): Boolean; static;
  end;

  TPageDriver = class(TInterfacedObject, IPageDriver)
  private
    FConfig: TPageDriverConfig;
    FStatus: TPageDriverStatus;
    FSession: IBrowserAutomationSession;
    FLock: TCriticalSection;
    FLastError: string;

    function WaitForReady(ASession: IBrowserAutomationSession;
      ATimeoutMs: Integer): Boolean;
    function CollectSnapshot(const ASession: IBrowserAutomationSession;
      out ASnapshot, AError: string): Boolean;
    function CallPlanner(const AInstruction, ASnapshot, AHistory: string;
      AStep: Integer; out APlanJson, ARawResponse, AError: string): Boolean;
    function ExecutePlan(const ASession: IBrowserAutomationSession;
      const APlanJson: string; out AStepResult: TPageDriverResult;
      out AError: string): Boolean;
  public
    constructor Create; overload;
    constructor Create(const AConfig: TPageDriverConfig); overload;
    destructor Destroy; override;

    function GetStatus: TPageDriverStatus;
    function GetConfig: TPageDriverConfig;

    function Load(ASession: IBrowserAutomationSession): Boolean;
    function Execute(const AInstruction: string;
      out AResult: TPageDriverResult): Boolean;
    function IsReady: Boolean;
    procedure Unload;

    property Status: TPageDriverStatus read GetStatus;
    property Config: TPageDriverConfig read GetConfig;
    property LastError: string read FLastError;
  end;

function PageDriverStatusToString(AValue: TPageDriverStatus): string;

implementation

uses
  System.Diagnostics,
  System.Net.HttpClient,
  System.Net.URLClient,
  DeepBase.Logging;

function ParseJsonOrStringifiedJson(const AJson: string): TJSONValue;
var
  LOuter: TJSONValue;
  LInner: TJSONValue;
begin
  Result := nil;
  LOuter := TJSONObject.ParseJSONValue(Trim(AJson));
  if LOuter = nil then
    Exit;

  if LOuter is TJSONString then
  begin
    LInner := TJSONObject.ParseJSONValue(Trim(TJSONString(LOuter).Value));
    LOuter.Free;
    Result := LInner;
    Exit;
  end;

  Result := LOuter;
end;

function JsonStringValue(AObj: TJSONObject; const AName: string;
  const ADefault: string = ''): string;
var
  LValue: TJSONValue;
begin
  Result := ADefault;
  if AObj = nil then
    Exit;
  LValue := AObj.GetValue(AName);
  if LValue <> nil then
    Result := LValue.Value;
end;

function JsonBoolValue(AObj: TJSONObject; const AName: string;
  ADefault: Boolean): Boolean;
var
  LValue: TJSONValue;
begin
  Result := ADefault;
  if AObj = nil then
    Exit;
  LValue := AObj.GetValue(AName);
  if LValue = nil then
    Exit;
  if LValue is TJSONBool then
    Exit(TJSONBool(LValue).AsBoolean);
  Result := SameText(LValue.Value, 'true') or (LValue.Value = '1');
end;

function NormalizeActionName(const AValue: string): string;
begin
  Result := LowerCase(Trim(AValue));
  Result := StringReplace(Result, '-', '_', [rfReplaceAll]);
  if (Result = 'type') or (Result = 'fill') or (Result = 'set_text') then
    Result := 'input_text'
  else if (Result = 'click_element') or (Result = 'click_element_by_index') then
    Result := 'click'
  else if Result = 'finish' then
    Result := 'done';
end;

function ExtractJsonObject(const AText: string): string;
var
  I: Integer;
  LStart: Integer;
  LDepth: Integer;
  LInString: Boolean;
  LEscaped: Boolean;
  C: Char;
begin
  Result := '';
  LStart := 0;
  LDepth := 0;
  LInString := False;
  LEscaped := False;

  for I := 1 to Length(AText) do
  begin
    C := AText[I];
    if LStart = 0 then
    begin
      if C = '{' then
      begin
        LStart := I;
        LDepth := 1;
      end;
      Continue;
    end;

    if LInString then
    begin
      if LEscaped then
        LEscaped := False
      else if C = '\' then
        LEscaped := True
      else if C = '"' then
        LInString := False;
      Continue;
    end;

    if C = '"' then
      LInString := True
    else if C = '{' then
      Inc(LDepth)
    else if C = '}' then
    begin
      Dec(LDepth);
      if LDepth = 0 then
        Exit(Copy(AText, LStart, I - LStart + 1));
    end;
  end;
end;

function BuildChatMessage(const ARole, AContent: string): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('role', ARole);
  Result.AddPair('content', AContent);
end;

function PageDriverStatusToString(AValue: TPageDriverStatus): string;
begin
  case AValue of
    pdsNotLoaded: Result := 'not_loaded';
    pdsLoading: Result := 'loading';
    pdsReady: Result := 'ready';
    pdsExecuting: Result := 'executing';
    pdsError: Result := 'error';
  else
    Result := 'unknown';
  end;
end;

{ TPageDriverConfig }

class function TPageDriverConfig.Default: TPageDriverConfig;
begin
  Result := System.Default(TPageDriverConfig);
  Result.Model := 'qwen3.5-plus';
  Result.BaseURL := '';
  Result.ApiKey := '';
  Result.Language := 'en-US';
  Result.MaxSteps := 10;
  Result.TimeoutMs := 120000;
  Result.BundleUrl := '';
end;

{ TPageDriverJS }

class function TPageDriverJS.BuildLoaderScript(
  const AConfig: TPageDriverConfig): string;
begin
  Result :=
    '(function(){' +
    '  window.__dbPageDriverStatus = "loading";' +
    '  window.__dbPageDriverError = "";' +
    '  function cleanText(v){ return String(v || "").replace(/\s+/g," ").trim(); }' +
    '  function visible(el){' +
    '    if(!el) return false;' +
    '    var s = window.getComputedStyle(el);' +
    '    if(s.display === "none" || s.visibility === "hidden" || Number(s.opacity) === 0) return false;' +
    '    var r = el.getBoundingClientRect();' +
    '    return r.width > 0 && r.height > 0;' +
    '  }' +
    '  function describe(el){' +
    '    var tag = (el.tagName || "").toLowerCase();' +
    '    var value = "";' +
    '    if(tag === "input" || tag === "textarea" || tag === "select") value = el.value || "";' +
    '    var label = "";' +
    '    if(el.id){ var l = document.querySelector("label[for=\""+CSS.escape(el.id)+"\"]"); if(l) label = l.innerText || ""; }' +
    '    var text = cleanText(el.getAttribute("aria-label") || el.getAttribute("title") || label || el.innerText || el.textContent || el.getAttribute("placeholder") || value || el.name || el.id);' +
    '    return {' +
    '      tag: tag,' +
    '      text: text.substring(0, 180),' +
    '      id: el.id || "",' +
    '      name: el.getAttribute("name") || "",' +
    '      role: el.getAttribute("role") || "",' +
    '      type: el.getAttribute("type") || "",' +
    '      value: value.substring(0, 120),' +
    '      placeholder: el.getAttribute("placeholder") || "",' +
    '      ariaLabel: el.getAttribute("aria-label") || ""' +
    '    };' +
    '  }' +
    '  function elements(){' +
    '    var nodes = Array.prototype.slice.call(document.querySelectorAll("button,input,textarea,select,a[href],[role=button],[role=menuitem],[onclick],[contenteditable=true],[tabindex]"));' +
    '    var out = [];' +
    '    for(var i=0;i<nodes.length;i++){' +
    '      var el = nodes[i];' +
    '      if(!visible(el) || el.disabled || el.getAttribute("aria-hidden") === "true") continue;' +
    '      var d = describe(el);' +
    '      d.index = out.length;' +
    '      out.push(d);' +
    '      if(out.length >= 120) break;' +
    '    }' +
    '    return {nodes:nodes.filter(function(el){ return visible(el) && !el.disabled && el.getAttribute("aria-hidden") !== "true"; }), data:out};' +
    '  }' +
    '  function line(e){' +
    '    var attrs = "";' +
    '    if(e.id) attrs += " id=\""+e.id+"\"";' +
    '    if(e.name) attrs += " name=\""+e.name+"\"";' +
    '    if(e.type) attrs += " type=\""+e.type+"\"";' +
    '    if(e.role) attrs += " role=\""+e.role+"\"";' +
    '    if(e.placeholder) attrs += " placeholder=\""+e.placeholder+"\"";' +
    '    if(e.ariaLabel) attrs += " aria-label=\""+e.ariaLabel+"\"";' +
    '    if(e.value) attrs += " value=\""+e.value+"\"";' +
    '    return "["+e.index+"]<"+e.tag+attrs+">"+e.text+"</"+e.tag+">";' +
    '  }' +
    '  function inputText(el, text){' +
    '    el.scrollIntoView({block:"center", inline:"nearest"});' +
    '    el.focus();' +
    '    if(el.isContentEditable){ el.innerText = text; }' +
    '    else { el.value = text; }' +
    '    el.dispatchEvent(new InputEvent("input",{bubbles:true,inputType:"insertText",data:text}));' +
    '    el.dispatchEvent(new Event("change",{bubbles:true}));' +
    '  }' +
    '  window.__dbPageDriverNative = {' +
    '    version: "deepbase-native-1",' +
    '    snapshot: function(){' +
    '      var r = elements();' +
    '      return JSON.stringify({' +
    '        success:true,' +
    '        url: location.href,' +
    '        title: document.title,' +
    '        scrollY: window.scrollY,' +
    '        viewport: {width: window.innerWidth, height: window.innerHeight},' +
    '        elements: r.data,' +
    '        content: r.data.map(line).join("\n"),' +
    '        pageText: cleanText(document.body ? document.body.innerText : "").substring(0, 4000)' +
    '      });' +
    '    },' +
    '    execute: function(planJson){' +
    '      try {' +
    '        var plan = typeof planJson === "string" ? JSON.parse(planJson) : planJson;' +
    '        var action = String(plan.action || plan.name || "").toLowerCase().replace(/-/g,"_");' +
    '        if(action === "type" || action === "fill" || action === "set_text") action = "input_text";' +
    '        if(action === "click_element" || action === "click_element_by_index") action = "click";' +
    '        if(action === "finish") action = "done";' +
    '        if(action === "done") return JSON.stringify({success: plan.success !== false, action:"done", description: String(plan.text || plan.message || ""), rawResponse: JSON.stringify(plan)});' +
    '        if(action === "wait") return JSON.stringify({success:true, action:"wait", description:"wait requested", rawResponse: JSON.stringify(plan)});' +
    '        if(action === "scroll") { window.scrollBy(0, Number(plan.pixels || 0) || ((plan.down === false ? -1 : 1) * window.innerHeight * Number(plan.num_pages || 0.5))); return JSON.stringify({success:true, action:"scroll", description:"scrolled", rawResponse: JSON.stringify(plan)}); }' +
    '        var r = elements();' +
    '        var idx = Number(plan.index);' +
    '        var el = r.nodes[idx];' +
    '        if(!el) return JSON.stringify({success:false, action:action, error:"No element at index "+idx, rawResponse: JSON.stringify(plan)});' +
    '        if(action === "input_text") {' +
    '          inputText(el, String(plan.text || plan.value || ""));' +
    '          return JSON.stringify({success:true, action:action, description:"input_text index "+idx, rawResponse: JSON.stringify(plan)});' +
    '        }' +
    '        if(action === "click") {' +
    '          el.scrollIntoView({block:"center", inline:"nearest"});' +
    '          el.focus({preventScroll:true});' +
    '          el.click();' +
    '          return JSON.stringify({success:true, action:action, description:"click index "+idx, rawResponse: JSON.stringify(plan)});' +
    '        }' +
    '        return JSON.stringify({success:false, action:action, error:"Unknown action "+action, rawResponse: JSON.stringify(plan)});' +
    '      } catch(e) {' +
    '        return JSON.stringify({success:false, action:"execute", error:String(e)});' +
    '      }' +
    '    }' +
    '  };' +
    '  window.__dbPageDriverStatus = "ready";' +
    '})();';
end;

class function TPageDriverJS.BuildExecuteScript(
  const AActionJson: string; AMaxSteps: Integer): string;
begin
  Result :=
    '(function(){' +
    '  if (!window.__dbPageDriverNative) {' +
    '    return JSON.stringify({success:false,error:"driver_not_loaded"});' +
    '  }' +
    '  window.__dbPageDriverStatus = "executing";' +
    '  var r = window.__dbPageDriverNative.execute(' +
    TBrowserAutomationScripts.JavaScriptString(AActionJson) + ');' +
    '  window.__dbPageDriverStatus = "ready";' +
    '  return r;' +
    '})();';
end;

class function TPageDriverJS.BuildStatusScript: string;
begin
  Result :=
    '(function(){' +
    '  return JSON.stringify({' +
    '    status: window.__dbPageDriverStatus || "not_loaded",' +
    '    hasDriver: !!window.__dbPageDriverNative,' +
    '    version: window.__dbPageDriverNative ? window.__dbPageDriverNative.version : "",' +
    '    error: window.__dbPageDriverError || ""' +
    '  });' +
    '})();';
end;

class function TPageDriverJS.BuildSnapshotScript: string;
begin
  Result :=
    '(function(){' +
    '  if (!window.__dbPageDriverNative) {' +
    '    return JSON.stringify({success:false,error:"driver_not_loaded"});' +
    '  }' +
    '  return window.__dbPageDriverNative.snapshot();' +
    '})();';
end;

class function TPageDriverJS.BuildUnloadScript: string;
begin
  Result :=
    '(function(){' +
    '  delete window.__dbPageDriverNative;' +
    '  delete window.__dbPageDriverStatus;' +
    '  delete window.__dbPageDriverError;' +
    '})();';
end;

class function TPageDriverJS.ParseResult(const AJson: string;
  out AResult: TPageDriverResult): Boolean;
var
  LJson: TJSONValue;
  LNestedJson: TJSONValue;
  LObj: TJSONObject;
  LNestedObj: TJSONObject;
  LValue: TJSONValue;
begin
  Result := False;
  AResult := Default(TPageDriverResult);

  LJson := ParseJsonOrStringifiedJson(AJson);
  if LJson = nil then
  begin
    AResult.Success := False;
    AResult.ErrorMessage := 'Invalid JSON response';
    AResult.RawResponse := AJson;
    Exit;
  end;
  try
    if not (LJson is TJSONObject) then
    begin
      AResult.RawResponse := AJson;
      Exit;
    end;

    LObj := LJson as TJSONObject;

    LValue := LObj.GetValue('success');
    if LValue <> nil then
      AResult.Success := SameText(LValue.Value, 'true') or (LValue.Value = '1');

    AResult.Action := JsonStringValue(LObj, 'action');
    AResult.Description := JsonStringValue(LObj, 'description');

    LValue := LObj.GetValue('rawResponse');
    if LValue <> nil then
      AResult.RawResponse := LValue.Value;

    if AResult.Success and (AResult.RawResponse <> '') then
    begin
      LNestedJson := ParseJsonOrStringifiedJson(AResult.RawResponse);
      if LNestedJson <> nil then
      try
        if LNestedJson is TJSONObject then
        begin
          LNestedObj := LNestedJson as TJSONObject;
          LValue := LNestedObj.GetValue('success');
          if (LValue <> nil) and
             (SameText(LValue.Value, 'false') or (LValue.Value = '0')) then
          begin
            AResult.Success := False;
            LValue := LNestedObj.GetValue('error');
            if (LValue = nil) or (LValue.Value = '') then
              LValue := LNestedObj.GetValue('data');
            if (LValue <> nil) and (LValue.Value <> '') then
              AResult.ErrorMessage := LValue.Value
            else
              AResult.ErrorMessage := 'Nested driver result returned success=false';
          end;
        end;
      finally
        LNestedJson.Free;
      end;
    end;

    LValue := LObj.GetValue('error');
    if (LValue <> nil) and (LValue.Value <> '') then
    begin
      AResult.Success := False;
      AResult.ErrorMessage := LValue.Value;
    end;

    Result := True;
  finally
    LJson.Free;
  end;
end;

{ TPageDriver }

constructor TPageDriver.Create;
begin
  Create(TPageDriverConfig.Default);
end;

constructor TPageDriver.Create(const AConfig: TPageDriverConfig);
begin
  inherited Create;
  FConfig := AConfig;
  FStatus := pdsNotLoaded;
  FLock := TCriticalSection.Create;
end;

destructor TPageDriver.Destroy;
begin
  Unload;
  FreeAndNil(FLock);
  inherited;
end;

function TPageDriver.GetStatus: TPageDriverStatus;
begin
  FLock.Enter;
  try
    Result := FStatus;
  finally
    FLock.Leave;
  end;
end;

function TPageDriver.GetConfig: TPageDriverConfig;
begin
  Result := FConfig;
end;

function TPageDriver.Load(
  ASession: IBrowserAutomationSession): Boolean;
var
  LError: string;
  LRaw: string;
  LSession: IBrowserAutomationSession;
  LReady: Boolean;
begin
  FLock.Enter;
  try
    if FStatus = pdsReady then
      Exit(True);

    if ASession = nil then
    begin
      FLastError := 'Session is nil';
      FStatus := pdsError;
      Exit(False);
    end;

    if not ASession.IsReady then
    begin
      FLastError := 'Session is not ready: ' + ASession.GetLastError;
      FStatus := pdsError;
      Exit(False);
    end;

    FSession := ASession;
    FStatus := pdsLoading;
    LSession := ASession;

    if not LSession.ExecuteScript(TPageDriverJS.BuildLoaderScript(FConfig), LError) then
    begin
      FLastError := 'Failed to inject native PageDriver bridge: ' + LError;
      FStatus := pdsError;
      Exit(False);
    end;
  finally
    FLock.Leave;
  end;

  LReady := WaitForReady(LSession, 5000);

  FLock.Enter;
  try
    if not LReady then
    begin
      FStatus := pdsError;
      FLastError := 'Native PageDriver bridge did not become ready';

      if (FSession <> nil) and FSession.EvaluateScript(
        TPageDriverJS.BuildStatusScript, 5000, LRaw, LError) then
        FLastError := FLastError + ' (' + LRaw + ')';

      Exit(False);
    end;

    FStatus := pdsReady;
    FLastError := '';

    Logger.Info('Browser.PageDriver: native bridge loaded and ready',
      'TPageDriver');
    Result := True;
  finally
    FLock.Leave;
  end;
end;

function TPageDriver.WaitForReady(ASession: IBrowserAutomationSession;
  ATimeoutMs: Integer): Boolean;
var
  LTimer: TStopwatch;
  LRaw, LError: string;
  LJson: TJSONValue;
  LObj: TJSONObject;
  LStatus: string;
begin
  Result := False;
  if ASession = nil then
    Exit;
  LTimer := TStopwatch.StartNew;

  while LTimer.ElapsedMilliseconds < ATimeoutMs do
  begin
    TThread.Sleep(50);

    if ASession.EvaluateScript(TPageDriverJS.BuildStatusScript, 5000, LRaw, LError) then
    begin
      LJson := ParseJsonOrStringifiedJson(LRaw);
      if LJson <> nil then
      try
        if LJson is TJSONObject then
        begin
          LObj := LJson as TJSONObject;
          LStatus := JsonStringValue(LObj, 'status');
          if LStatus = 'ready' then
            Exit(True);
          if LStatus = 'error' then
          begin
            FLastError := JsonStringValue(LObj, 'error');
            Exit(False);
          end;
        end;
      finally
        LJson.Free;
      end;
    end;
  end;
end;

function TPageDriver.CollectSnapshot(
  const ASession: IBrowserAutomationSession;
  out ASnapshot, AError: string): Boolean;
var
  LResult: TPageDriverResult;
begin
  Result := False;
  ASnapshot := '';
  AError := '';

  if not ASession.EvaluateScript(TPageDriverJS.BuildSnapshotScript,
    10000, ASnapshot, AError) then
    Exit;

  if not TPageDriverJS.ParseResult(ASnapshot, LResult) then
  begin
    AError := LResult.ErrorMessage;
    Exit(False);
  end;

  if not LResult.Success then
  begin
    AError := LResult.ErrorMessage;
    Exit(False);
  end;

  Result := True;
end;

function TPageDriver.CallPlanner(const AInstruction, ASnapshot,
  AHistory: string; AStep: Integer; out APlanJson, ARawResponse,
  AError: string): Boolean;
var
  LHttp: THTTPClient;
  LBody: TJSONObject;
  LMessages: TJSONArray;
  LStream: TStringStream;
  LResponse: IHTTPResponse;
  LResponseText: string;
  LJson: TJSONValue;
  LObj, LChoice, LMessage: TJSONObject;
  LChoices: TJSONArray;
  LContent: string;
  LEndpoint: string;
  LSystemPrompt: string;
  LUserPrompt: string;
  LValue: TJSONValue;
begin
  Result := False;
  APlanJson := '';
  ARawResponse := '';
  AError := '';

  if (Trim(FConfig.BaseURL) = '') or (Trim(FConfig.Model) = '') then
  begin
    AError := 'LLM configuration required: BaseURL and Model';
    Exit(False);
  end;

  LSystemPrompt :=
    'You are DeepBase PageDriver, a browser UI automation planner. ' +
    'Choose exactly one next action from the indexed browser state. ' +
    'Return only one compact JSON object, no markdown. ' +
    'Allowed actions: ' +
    '{"action":"input_text","index":number,"text":string}, ' +
    '{"action":"click","index":number}, ' +
    '{"action":"scroll","down":boolean,"num_pages":number}, ' +
    '{"action":"wait","seconds":number}, ' +
    '{"action":"done","success":boolean,"text":string}. ' +
    'Only use indexes visible in the state. If the requested task is complete, return done.';

  LUserPrompt :=
    '<user_request>' + sLineBreak + AInstruction + sLineBreak +
    '</user_request>' + sLineBreak +
    '<step>' + IntToStr(AStep) + ' of ' + IntToStr(FConfig.MaxSteps) +
    '</step>' + sLineBreak +
    '<history>' + sLineBreak + AHistory + sLineBreak + '</history>' +
    sLineBreak +
    '<browser_state_json>' + sLineBreak + ASnapshot + sLineBreak +
    '</browser_state_json>' + sLineBreak +
    'Return the next action JSON only.';

  LBody := TJSONObject.Create;
  try
    LBody.AddPair('model', FConfig.Model);
    LBody.AddPair('temperature', TJSONNumber.Create(0));
    LBody.AddPair('max_tokens', TJSONNumber.Create(800));

    LMessages := TJSONArray.Create;
    LMessages.AddElement(BuildChatMessage('system', LSystemPrompt));
    LMessages.AddElement(BuildChatMessage('user', LUserPrompt));
    LBody.AddPair('messages', LMessages);

    LEndpoint := FConfig.BaseURL.TrimRight(['/']) + '/chat/completions';
    LStream := TStringStream.Create(LBody.ToJSON, TEncoding.UTF8);
    LHttp := THTTPClient.Create;
    try
      LHttp.ConnectionTimeout := FConfig.TimeoutMs;
      LHttp.ResponseTimeout := FConfig.TimeoutMs;
      LHttp.ContentType := 'application/json';
      if FConfig.ApiKey <> '' then
        LHttp.CustomHeaders['Authorization'] := 'Bearer ' + FConfig.ApiKey;

      LResponse := LHttp.Post(LEndpoint, LStream);
      LResponseText := LResponse.ContentAsString(TEncoding.UTF8);
      ARawResponse := LResponseText;

      if (LResponse.StatusCode < 200) or (LResponse.StatusCode >= 300) then
      begin
        AError := Format('LLM HTTP %d: %s',
          [LResponse.StatusCode, Copy(LResponseText, 1, 300)]);
        Exit(False);
      end;
    finally
      LHttp.Free;
      LStream.Free;
    end;
  finally
    LBody.Free;
  end;

  LJson := TJSONObject.ParseJSONValue(LResponseText);
  if LJson = nil then
  begin
    AError := 'LLM returned invalid JSON envelope';
    Exit(False);
  end;
  try
    if not (LJson is TJSONObject) then
    begin
      AError := 'LLM envelope is not an object';
      Exit(False);
    end;

    LObj := LJson as TJSONObject;
    LValue := LObj.GetValue('choices');
    if not (LValue is TJSONArray) then
    begin
      AError := 'LLM envelope has no choices array';
      Exit(False);
    end;

    LChoices := LValue as TJSONArray;
    if LChoices.Count = 0 then
    begin
      AError := 'LLM returned no choices';
      Exit(False);
    end;

    if not (LChoices.Items[0] is TJSONObject) then
    begin
      AError := 'LLM choice is not an object';
      Exit(False);
    end;

    LChoice := LChoices.Items[0] as TJSONObject;
    LValue := LChoice.GetValue('message');
    if not (LValue is TJSONObject) then
    begin
      AError := 'LLM choice has no message object';
      Exit(False);
    end;

    LMessage := LValue as TJSONObject;
    LContent := JsonStringValue(LMessage, 'content');
    APlanJson := ExtractJsonObject(LContent);

    if APlanJson = '' then
    begin
      AError := 'LLM did not return an action JSON object: ' +
        Copy(LContent, 1, 300);
      Exit(False);
    end;

    if TJSONObject.ParseJSONValue(APlanJson) = nil then
    begin
      AError := 'LLM action JSON is invalid: ' + Copy(APlanJson, 1, 200);
      Exit(False);
    end;

    Result := True;
  finally
    LJson.Free;
  end;
end;

function TPageDriver.ExecutePlan(const ASession: IBrowserAutomationSession;
  const APlanJson: string; out AStepResult: TPageDriverResult;
  out AError: string): Boolean;
var
  LRaw: string;
begin
  Result := False;
  AStepResult := Default(TPageDriverResult);
  AError := '';

  if not ASession.EvaluateScript(TPageDriverJS.BuildExecuteScript(APlanJson),
    10000, LRaw, AError) then
    Exit(False);

  if not TPageDriverJS.ParseResult(LRaw, AStepResult) then
  begin
    AError := AStepResult.ErrorMessage;
    Exit(False);
  end;

  AStepResult.Action := NormalizeActionName(AStepResult.Action);
  Result := True;
end;

function TPageDriver.Execute(const AInstruction: string;
  out AResult: TPageDriverResult): Boolean;
var
  LTimer: TStopwatch;
  LSession: IBrowserAutomationSession;
  LSnapshot, LPlanJson, LRawPlanner, LError: string;
  LStepResult: TPageDriverResult;
  LHistory: TStringBuilder;
  LStep: Integer;
begin
  Result := False;
  AResult := Default(TPageDriverResult);

  FLock.Enter;
  try
    if FStatus <> pdsReady then
    begin
      AResult.Success := False;
      AResult.ErrorMessage := 'PageDriver is not ready (status: ' +
        PageDriverStatusToString(FStatus) + ')';
      Exit(False);
    end;

    FStatus := pdsExecuting;
    LSession := FSession;
  finally
    FLock.Leave;
  end;

  if LSession = nil then
  begin
    FLock.Enter;
    try
      if FStatus = pdsExecuting then
        FStatus := pdsError;
    finally
      FLock.Leave;
    end;
    AResult.Success := False;
    AResult.ErrorMessage := 'Session was released';
    Exit(False);
  end;

  LTimer := TStopwatch.StartNew;
  LHistory := TStringBuilder.Create;
  try
    for LStep := 1 to FConfig.MaxSteps do
    begin
      if not CollectSnapshot(LSession, LSnapshot, LError) then
      begin
        AResult.Success := False;
        AResult.ErrorMessage := 'Snapshot failed: ' + LError;
        AResult.DurationMs := LTimer.ElapsedMilliseconds;
        Exit(False);
      end;

      if not CallPlanner(AInstruction, LSnapshot, LHistory.ToString,
        LStep, LPlanJson, LRawPlanner, LError) then
      begin
        AResult.Success := False;
        AResult.ErrorMessage := 'Planner failed: ' + LError;
        AResult.RawResponse := LRawPlanner;
        AResult.DurationMs := LTimer.ElapsedMilliseconds;
        Exit(False);
      end;

      if not ExecutePlan(LSession, LPlanJson, LStepResult, LError) then
      begin
        AResult.Success := False;
        AResult.ErrorMessage := 'Action failed: ' + LError;
        AResult.RawResponse := LPlanJson;
        AResult.DurationMs := LTimer.ElapsedMilliseconds;
        Exit(False);
      end;

      LHistory.AppendFormat('step %d action=%s success=%s result=%s',
        [LStep, LStepResult.Action, BoolToStr(LStepResult.Success, True),
         LStepResult.Description]).AppendLine;

      AResult := LStepResult;
      AResult.DurationMs := LTimer.ElapsedMilliseconds;
      AResult.RawResponse := LPlanJson;

      if SameText(LStepResult.Action, 'wait') then
        TThread.Sleep(1000)
      else if SameText(LStepResult.Action, 'done') then
      begin
        Result := True;
        Break;
      end
      else if not LStepResult.Success then
      begin
        Result := True;
        Break;
      end
      else
        TThread.Sleep(250);
    end;

    if (not Result) and (AResult.ErrorMessage = '') then
    begin
      AResult.Success := False;
      AResult.Action := 'done';
      AResult.ErrorMessage := 'Step count exceeded maximum limit';
      AResult.Description := AResult.ErrorMessage;
      AResult.DurationMs := LTimer.ElapsedMilliseconds;
      Result := True;
    end;
  finally
    LHistory.Free;
    FLock.Enter;
    try
      if FStatus = pdsExecuting then
        FStatus := pdsReady;
    finally
      FLock.Leave;
    end;
  end;

  if AResult.Success then
    Logger.InfoFmt('Browser.PageDriver: executed "%s" in %dms',
      [Copy(AInstruction, 1, 80), AResult.DurationMs],
      'TPageDriver')
  else
    Logger.WarnFmt('Browser.PageDriver: failed "%s" - %s',
      [Copy(AInstruction, 1, 80), AResult.ErrorMessage],
      'TPageDriver');
end;

function TPageDriver.IsReady: Boolean;
begin
  FLock.Enter;
  try
    Result := FStatus = pdsReady;
  finally
    FLock.Leave;
  end;
end;

procedure TPageDriver.Unload;
begin
  FLock.Enter;
  try
    if (FStatus <> pdsNotLoaded) and (FSession <> nil) then
    begin
      FSession.ExecuteScript(TPageDriverJS.BuildUnloadScript, FLastError);
      Logger.Info('Browser.PageDriver: unloaded', 'TPageDriver');
    end;
    FSession := nil;
    FStatus := pdsNotLoaded;
  finally
    FLock.Leave;
  end;
end;

end.
