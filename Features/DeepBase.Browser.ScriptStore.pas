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
  System.Generics.Collections;

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

function JsonStringLiteral(const AValue: string): string;
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
    Result := JsonStringLiteral(VarRecToString(AValue));
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
    'return document.querySelector({{selector}}) !== null;',
    'Checks whether a selector exists.');
  Result[1] := CreateScriptDefinition(JSCRIPT_CLICK,
    'document.querySelector({{selector}}).click();',
    'Clicks the first matching element.');
  Result[2] := CreateScriptDefinition(JSCRIPT_INPUT_TEXT,
    'var el = document.querySelector({{selector}});' +
    'el.value = {{text}};' +
    'el.dispatchEvent(new Event("input", { bubbles: true }));',
    'Sets text on the first matching input.');
  Result[3] := CreateScriptDefinition(JSCRIPT_GET_TEXT,
    'var el = document.querySelector({{selector}});' +
    'return el ? el.textContent : "";',
    'Returns visible text for the first matching element.');
  Result[4] := CreateScriptDefinition(JSCRIPT_RESPONSE_WAITER,
    'window.__deepBaseWaitForResponse({{urlPattern}}, {{method}}, ' +
    '{{timeoutMs}}, {{bodyContains}});',
    'Waits for a matching network response.');
  Result[5] := CreateScriptDefinition(JSCRIPT_WAITER_CANCEL,
    'window.__deepBaseCancelResponseWaiter({{waiterId}});',
    'Cancels an active response waiter.');
  Result[6] := CreateScriptDefinition(JSCRIPT_SELECTOR_HEAL,
    'window.__deepBaseDiscoverSelector({{selector}}, {{textHint}});',
    'Discovers alternate selectors for a target element.');
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
