{ ============================================================================
  DeepBase.Browser.ScriptStore
  ---------------------------------------------------------------------------
  Version     : 1.0
  Description : JS script template rendering and runtime script store.
                The default store is intentionally lightweight and in-memory;
                persistent SQLite backing can be layered behind IJSScriptStore.
  ============================================================================ }

unit DeepBase.Browser.ScriptStore;

interface

uses
  System.SysUtils,
  System.JSON;

const
  JSCRIPT_EXISTS = 'browser.exists';
  JSCRIPT_CLICK = 'browser.click';
  JSCRIPT_INPUT_TEXT = 'browser.input_text';
  JSCRIPT_GET_TEXT = 'browser.get_text';
  JSCRIPT_RESPONSE_WAITER = 'browser.response_waiter';
  JSCRIPT_WAITER_CANCEL = 'browser.response_waiter_cancel';
  JSCRIPT_SELECTOR_HEAL = 'browser.selector_heal_discover';

type
  EBrowserScriptStore = class(Exception);

  TJSScriptDefinition = record
    Name: string;
    Body: string;
    Description: string;
    IsActive: Boolean;
    Placeholders: TArray<string>;
  end;

  TJSScriptArray = TArray<TJSScriptDefinition>;

  TJSTemplate = record
  public
    class function Render(const ATemplate: string;
      const AValues: array of const): string; static;
    class function Extract(const ATemplate: string): TArray<string>; static;
  end;

  TJSScriptStoreSqlite = class sealed
  public
    class function GetBuiltinDefaults: TJSScriptArray; static;
  end;

  IJSScriptStore = interface
    ['{A6F63C92-4C25-4E31-A4CF-8E7B5A899985}']
    function HasScript(const AName: string): Boolean;
    function GetScript(const AName: string): string;
    function Render(const AName: string;
      const AValues: array of const): string;
    procedure Replace(const AName, ABody: string;
      const ADescription: string = '');
    procedure Activate(const AName: string);
    procedure Deactivate(const AName: string);
    procedure Reload;
  end;

function ScriptStore: IJSScriptStore;

implementation

uses
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections,
  DeepBase.Browser.Types;

type
  TJSScriptEntry = record
    Name: string;
    Body: string;
    Description: string;
    Active: Boolean;
  end;

  TMemoryJSScriptStore = class(TInterfacedObject, IJSScriptStore)
  private
    FLock: TCriticalSection;
    FScripts: TDictionary<string, TJSScriptEntry>;
  public
    constructor Create;
    destructor Destroy; override;

    function HasScript(const AName: string): Boolean;
    function GetScript(const AName: string): string;
    function Render(const AName: string;
      const AValues: array of const): string;
    procedure Replace(const AName, ABody: string;
      const ADescription: string = '');
    procedure Activate(const AName: string);
    procedure Deactivate(const AName: string);
    procedure Reload;
  end;

var
  GScriptStore: IJSScriptStore = nil;
  GScriptStoreLock: TCriticalSection = nil;

function VarRecToString(const AValue: TVarRec): string;
begin
  case AValue.VType of
    vtString:
      Result := string(AValue.VString^);
    vtAnsiString:
      Result := string(AnsiString(AValue.VAnsiString));
    vtWideString:
      Result := WideString(AValue.VWideString);
    vtUnicodeString:
      Result := string(AValue.VUnicodeString);
    vtChar:
      Result := string(AValue.VChar);
    vtWideChar:
      Result := string(AValue.VWideChar);
    vtInteger:
      Result := IntToStr(AValue.VInteger);
    vtInt64:
      Result := IntToStr(AValue.VInt64^);
    vtBoolean:
      if AValue.VBoolean then
        Result := 'true'
      else
        Result := 'false';
  else
    Result := '';
  end;
end;

function VarRecToJsonLiteral(const AValue: TVarRec): string;
var
  LFormat: TFormatSettings;
begin
  case AValue.VType of
    vtInteger:
      Result := IntToStr(AValue.VInteger);
    vtInt64:
      Result := IntToStr(AValue.VInt64^);
    vtBoolean:
      if AValue.VBoolean then
        Result := 'true'
      else
        Result := 'false';
    vtExtended:
      begin
        LFormat := TFormatSettings.Invariant;
        Result := FloatToStr(AValue.VExtended^, LFormat);
      end;
  else
    Result := JsStringLiteral(VarRecToString(AValue));
  end;
end;

function CreateScriptDefinition(const AName, ABody,
  ADescription: string): TJSScriptDefinition;
begin
  Result.Name := AName;
  Result.Body := ABody;
  Result.Description := ADescription;
  Result.IsActive := True;
  Result.Placeholders := TJSTemplate.Extract(ABody);
end;

{ TJSScriptStoreSqlite }

class function TJSScriptStoreSqlite.GetBuiltinDefaults: TJSScriptArray;
begin
  SetLength(Result, 7);
  Result[0] := CreateScriptDefinition(JSCRIPT_EXISTS,
    '(function(){try{return document.querySelector({{selector}})!==null;}catch(e){return false;}})();',
    'Checks whether a selector exists.');
  Result[1] := CreateScriptDefinition(JSCRIPT_CLICK,
    '(function(){try{' +
    'var el=document.querySelector({{selector}});' +
    'if(!el)return {success:false,error:"not_found"};' +
    'if(el.scrollIntoView)el.scrollIntoView({block:"center",inline:"center"});' +
    'el.click();' +
    'return {success:true,error:""};' +
    '}catch(e){return {success:false,error:String(e)}}})();',
    'Clicks the first matching element. Returns {success,error}.');
  Result[2] := CreateScriptDefinition(JSCRIPT_INPUT_TEXT,
    '(function(){try{' +
    'var el=document.querySelector({{selector}});' +
    'if(!el)return {success:false,error:"not_found"};' +
    'if(el.scrollIntoView)el.scrollIntoView({block:"center",inline:"center"});' +
    'if(el.focus)el.focus();' +
    'if("value" in el){el.value={{text}};}else{el.textContent={{text}};}' +
    'el.dispatchEvent(new Event("input",{bubbles:true}));' +
    'el.dispatchEvent(new Event("change",{bubbles:true}));' +
    'return {success:true,error:""};' +
    '}catch(e){return {success:false,error:String(e)}}})();',
    'Sets text on the first matching input. Returns {success,error}.');
  Result[3] := CreateScriptDefinition(JSCRIPT_GET_TEXT,
    '(function(){try{' +
    'var list=document.querySelectorAll({{selector}});' +
    'if(!list||list.length===0)return {found:false,text:"",error:"not_found"};' +
    'var el=list[list.length-1];' +
    'return {found:true,text:(el.innerText||el.textContent||""),error:""};' +
    '}catch(e){return {found:false,text:"",error:String(e)}}})();',
    'Returns visible text for the last matching element. Returns {found,text,error}.');
  // H1 fix: real MutationObserver-based waiter; placeholders match
  // ResponseWaiter callsite (response_selector / loading_selector /
  // timeout_ms / stable_ms). Previously this was a stub calling a
  // non-existent window.__deepBaseWaitForResponse function.
  Result[4] := CreateScriptDefinition(JSCRIPT_RESPONSE_WAITER,
    '(function(){' +
    '  if (window.__dbWaiter) window.__dbWaiter.cancel();' +
    '  var responseSel = {{response_selector}};' +
    '  var loadingSel = {{loading_selector}};' +
    '  var timeoutMs = {{timeout_ms}};' +
    '  var stableMs = {{stable_ms}};' +
    '  window.__dbWaiter = {' +
    '    observer:null, timeoutTimer:null, stableTimer:null,' +
    '    startTime:Date.now(), lastContent:"", cancelled:false,' +
    '    start: function() {' +
    '      var self = this;' +
    '      this.timeoutTimer = setTimeout(function() {' +
    '        self.finish("timeout", self.getLatestResponse());' +
    '      }, timeoutMs);' +
    '      this.observer = new MutationObserver(function() {' +
    '        if (self.cancelled) return;' +
    '        if (loadingSel) {' +
    '          var loading = document.querySelector(loadingSel);' +
    '          if (loading) { clearTimeout(self.stableTimer); return; }' +
    '        }' +
    '        var content = self.getLatestResponse();' +
    '        if (content !== self.lastContent) {' +
    '          self.lastContent = content;' +
    '          clearTimeout(self.stableTimer);' +
    '          self.stableTimer = setTimeout(function() {' +
    '            self.finish("success", content);' +
    '          }, stableMs);' +
    '        }' +
    '      });' +
    '      this.observer.observe(document.body, ' +
    '        {childList:true, subtree:true, characterData:true, attributes:true});' +
    '      var initial = this.getLatestResponse();' +
    '      if (initial) {' +
    '        this.lastContent = initial;' +
    '        this.stableTimer = setTimeout(function() {' +
    '          self.finish("success", initial);' +
    '        }, stableMs);' +
    '      }' +
    '    },' +
    '    getLatestResponse: function() {' +
    '      if (!responseSel) return "";' +
    '      var els = document.querySelectorAll(responseSel);' +
    '      if (els.length === 0) return "";' +
    '      var last = els[els.length - 1];' +
    '      return last.innerText || last.textContent || "";' +
    '    },' +
    '    finish: function(result, response) {' +
    '      if (this.cancelled) return;' +
    '      this.cancel();' +
    '      var msg = JSON.stringify({' +
    '        type:"db_response_waiter", result:result,' +
    '        response:response, durationMs:(Date.now() - this.startTime)' +
    '      });' +
    '      if (window.chrome && window.chrome.webview)' +
    '        window.chrome.webview.postMessage(msg);' +
    '    },' +
    '    cancel: function() {' +
    '      this.cancelled = true;' +
    '      if (this.observer) { this.observer.disconnect(); this.observer = null; }' +
    '      clearTimeout(this.timeoutTimer);' +
    '      clearTimeout(this.stableTimer);' +
    '    }' +
    '  };' +
    '  window.__dbWaiter.start();' +
    '})();',
    'MutationObserver-based response stability detector.');
  // H1 fix: real cancel logic; previously called non-existent
  // window.__deepBaseCancelResponseWaiter.
  Result[5] := CreateScriptDefinition(JSCRIPT_WAITER_CANCEL,
    'if (window.__dbWaiter) {' +
    '  window.__dbWaiter.cancel();' +
    '  delete window.__dbWaiter;' +
    '}',
    'Cancels an active response waiter.');
  // H2 fix: zero-placeholder template (callers pass []).
  // Returns JSON array of stable selectors discovered via attributes.
  Result[6] := CreateScriptDefinition(JSCRIPT_SELECTOR_HEAL,
    '(function(){' +
    '  try {' +
    '    var candidates = document.querySelectorAll(' +
    '      "[data-testid], [aria-label], [name], [placeholder]");' +
    '    var result = [];' +
    '    var esc = (window.CSS && window.CSS.escape) ? window.CSS.escape :' +
    '              function(s){ return String(s).replace(/(["\\])/g, ''\\$1''); };' +
    '    for (var i = 0; i < candidates.length; i++) {' +
    '      var el = candidates[i];' +
    '      var sel = "";' +
    '      var tid = el.getAttribute("data-testid");' +
    '      var lbl = el.getAttribute("aria-label");' +
    '      var nm  = el.getAttribute("name");' +
    '      var ph  = el.getAttribute("placeholder");' +
    '      if (tid) sel = "[data-testid=\"" + esc(tid) + "\"]";' +
    '      else if (lbl) sel = "[aria-label=\"" + esc(lbl) + "\"]";' +
    '      else if (nm)  sel = "[name=\"" + esc(nm) + "\"]";' +
    '      else if (ph)  sel = "[placeholder=\"" + esc(ph) + "\"]";' +
    '      if (sel) result.push(sel);' +
    '    }' +
    '    return JSON.stringify(result);' +
    '  } catch(e) { return "[]"; }' +
    '})();',
    'Discovers alternate selectors via data-testid / aria-label / name / placeholder.');
end;

{ TJSTemplate }

class function TJSTemplate.Render(const ATemplate: string;
  const AValues: array of const): string;
var
  I: Integer;
  LName: string;
  LValue: string;
begin
  if Odd(Length(AValues)) then
    raise EBrowserScriptStore.Create(
      'Template render values must be name/value pairs');

  Result := ATemplate;
  I := 0;
  while I < Length(AValues) - 1 do
  begin
    LName := Trim(VarRecToString(AValues[I]));
    if LName <> '' then
    begin
      LValue := VarRecToJsonLiteral(AValues[I + 1]);
      Result := Result.Replace('{{' + LName + '}}', LValue,
        [rfReplaceAll]);
      Result := Result.Replace('{{ ' + LName + ' }}', LValue,
        [rfReplaceAll]);
    end;
    Inc(I, 2);
  end;
end;

class function TJSTemplate.Extract(
  const ATemplate: string): TArray<string>;
var
  LItems: TList<string>;
  LStart: Integer;
  LStop: Integer;
  LName: string;
begin
  LItems := TList<string>.Create;
  try
    LStart := Pos('{{', ATemplate);
    while LStart > 0 do
    begin
      LStop := Pos('}}', ATemplate, LStart + 2);
      if LStop = 0 then
        Break;

      LName := Trim(Copy(ATemplate, LStart + 2,
        LStop - LStart - 2));
      if (LName <> '') and not LItems.Contains(LName) then
        LItems.Add(LName);

      LStart := Pos('{{', ATemplate, LStop + 2);
    end;
    Result := LItems.ToArray;
  finally
    LItems.Free;
  end;
end;

{ TMemoryJSScriptStore }

constructor TMemoryJSScriptStore.Create;
var
  LDefaults: TJSScriptArray;
  LDefault: TJSScriptDefinition;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FScripts := TDictionary<string, TJSScriptEntry>.Create;

  LDefaults := TJSScriptStoreSqlite.GetBuiltinDefaults;
  for LDefault in LDefaults do
    Replace(LDefault.Name, LDefault.Body, LDefault.Description);
end;

destructor TMemoryJSScriptStore.Destroy;
begin
  FScripts.Free;
  FLock.Free;
  inherited;
end;

function TMemoryJSScriptStore.HasScript(const AName: string): Boolean;
var
  LEntry: TJSScriptEntry;
begin
  FLock.Enter;
  try
    Result := FScripts.TryGetValue(AName, LEntry) and LEntry.Active;
  finally
    FLock.Leave;
  end;
end;

function TMemoryJSScriptStore.GetScript(const AName: string): string;
var
  LEntry: TJSScriptEntry;
begin
  FLock.Enter;
  try
    if FScripts.TryGetValue(AName, LEntry) and LEntry.Active then
      Result := LEntry.Body
    else
      Result := '';
  finally
    FLock.Leave;
  end;
end;

function TMemoryJSScriptStore.Render(const AName: string;
  const AValues: array of const): string;
begin
  Result := TJSTemplate.Render(GetScript(AName), AValues);
end;

procedure TMemoryJSScriptStore.Replace(const AName, ABody: string;
  const ADescription: string);
var
  LEntry: TJSScriptEntry;
begin
  LEntry.Name := AName;
  LEntry.Body := ABody;
  LEntry.Description := ADescription;
  LEntry.Active := True;

  FLock.Enter;
  try
    FScripts.AddOrSetValue(AName, LEntry);
  finally
    FLock.Leave;
  end;
end;

procedure TMemoryJSScriptStore.Activate(const AName: string);
var
  LEntry: TJSScriptEntry;
begin
  FLock.Enter;
  try
    if FScripts.TryGetValue(AName, LEntry) then
    begin
      LEntry.Active := True;
      FScripts.AddOrSetValue(AName, LEntry);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TMemoryJSScriptStore.Deactivate(const AName: string);
var
  LEntry: TJSScriptEntry;
begin
  FLock.Enter;
  try
    if FScripts.TryGetValue(AName, LEntry) then
    begin
      LEntry.Active := False;
      FScripts.AddOrSetValue(AName, LEntry);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TMemoryJSScriptStore.Reload;
begin
  { The in-memory backend has no external source to reload. }
end;

function ScriptStore: IJSScriptStore;
begin
  if GScriptStore = nil then
  begin
    GScriptStoreLock.Enter;
    try
      if GScriptStore = nil then
        GScriptStore := TMemoryJSScriptStore.Create;
    finally
      GScriptStoreLock.Leave;
    end;
  end;
  Result := GScriptStore;
end;

initialization
  GScriptStoreLock := TCriticalSection.Create;

finalization
  GScriptStore := nil;
  FreeAndNil(GScriptStoreLock);

end.
