{ ============================================================================
  DeepBase.Browser.Selectors
  ---------------------------------------------------------------------------
  Version     : 1.0
  Description : Selector management with caching, validation, and
                self-healing fallback. Validates CSS selectors against
                a live browser session and falls back to alternate
                selectors when the primary ones fail.
  ============================================================================ }

unit DeepBase.Browser.Selectors;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections,
  System.JSON,
  DeepBase.Browser.Types,
  DeepBase.BrowserAutomation;

type
  TBrowserSelectorManager = class
  private
    FSession: IBrowserSession;
    FCache: TDictionary<string, TBrowserSelectorInfo>;
    FLock: TCriticalSection;

    function ValidateAgainstBrowser(
      const ASelector: string): Boolean;
  public
    constructor Create(ASession: IBrowserSession);
    destructor Destroy; override;

    procedure RegisterSelector(const AName, ASelector: string;
      const AFallbackSelector: string = '');
    function ResolveSelector(
      const AName: string): string;
    function ValidateSelector(
      const ASelector: string): Boolean;
    function TryHealSelector(const AName: string;
      out ANewSelector: string): Boolean;
    procedure InvalidateCache;
    procedure InvalidateSelector(const AName: string);

    procedure LoadFromConfig(const AJson: string);
    function ToConfig: string;

    function GetSelectorInfo(
      const AName: string): TBrowserSelectorInfo;
    function GetRegisteredNames: TArray<string>;
    function Count: Integer;
  end;

implementation

uses
  DeepBase.Browser.Events,
  DeepBase.Browser.ScriptStore,
  DeepBase.Logging;

{ TBrowserSelectorManager }

constructor TBrowserSelectorManager.Create(
  ASession: IBrowserSession);
begin
  inherited Create;
  FSession := ASession;
  FCache := TDictionary<string, TBrowserSelectorInfo>.Create;
  FLock := TCriticalSection.Create;
end;

destructor TBrowserSelectorManager.Destroy;
begin
  FCache.Free;
  FLock.Free;
  inherited;
end;

procedure TBrowserSelectorManager.RegisterSelector(
  const AName, ASelector: string; const AFallbackSelector: string);
var
  LInfo: TBrowserSelectorInfo;
begin
  LInfo := Default(TBrowserSelectorInfo);
  LInfo.Name := AName;
  LInfo.Selector := ASelector;
  LInfo.FallbackSelector := AFallbackSelector;
  LInfo.IsValid := True;
  LInfo.LastValidatedAt := Now;

  FLock.Enter;
  try
    FCache.AddOrSetValue(AName, LInfo);
  finally
    FLock.Leave;
  end;
end;

function TBrowserSelectorManager.ResolveSelector(
  const AName: string): string;
var
  LInfo: TBrowserSelectorInfo;
  LCurrent: TBrowserSelectorInfo;
  LNewSelector: string;
begin
  Result := '';

  FLock.Enter;
  try
    if not FCache.TryGetValue(AName, LInfo) then
      Exit('');
  finally
    FLock.Leave;
  end;

  if ValidateAgainstBrowser(LInfo.Selector) then
  begin
    FLock.Enter;
    try
      // Only update if selector hasn't been changed by concurrent registration
      if FCache.TryGetValue(AName, LCurrent) and
        (LCurrent.Selector = LInfo.Selector) then
      begin
        LInfo.IsValid := True;
        LInfo.LastValidatedAt := Now;
        FCache[AName] := LInfo;
      end;
    finally
      FLock.Leave;
    end;
    Exit(LInfo.Selector);
  end;

  // Primary failed, try fallback
  if LInfo.FallbackSelector <> '' then
  begin
    if ValidateAgainstBrowser(LInfo.FallbackSelector) then
    begin
      FLock.Enter;
      try
        if FCache.TryGetValue(AName, LCurrent) and
          (LCurrent.Selector = LInfo.Selector) then
        begin
          LInfo.IsValid := True;
          LInfo.LastValidatedAt := Now;
          FCache[AName] := LInfo;
        end;
      finally
        FLock.Leave;
      end;

      Logger.InfoFmt('Selector healed: %s -> %s',
        [AName, LInfo.FallbackSelector],
        'TBrowserSelectorManager');
      Exit(LInfo.FallbackSelector);
    end;
  end;

  // Both failed
  FLock.Enter;
  try
    LInfo.IsValid := False;
    FCache[AName] := LInfo;
  finally
    FLock.Leave;
  end;

  // Attempt self-healing
  if TryHealSelector(AName, LNewSelector) then
    Exit(LNewSelector);

  // Publish failure event
  if FSession <> nil then
  begin
    var LPayload := TJSONObject.Create;
    try
      LPayload.AddPair('selector', AName);
      LPayload.AddPair('error', 'not_found');
      TBrowserEvents.Publish(betScriptFailed,
        FSession.GetSessionId, LPayload.ToJSON);
    finally
      LPayload.Free;
    end;
  end;

  Logger.WarnFmt('Selector unresolved: %s (%s)',
    [AName, LInfo.Selector],
    'TBrowserSelectorManager');
  Result := LInfo.Selector;
end;

function TBrowserSelectorManager.ValidateSelector(
  const ASelector: string): Boolean;
begin
  Result := ValidateAgainstBrowser(ASelector);
end;

function TBrowserSelectorManager.TryHealSelector(
  const AName: string; out ANewSelector: string): Boolean;
var
  LInfo: TBrowserSelectorInfo;
  LResult, LError: string;
  LJson: TJSONValue;
  LSelectors: TJSONArray;
  I: Integer;
  LCandidate: string;
  LStore: IJSScriptStore;
  LJS: string;
begin
  Result := False;
  ANewSelector := '';

  FLock.Enter;
  try
    if not FCache.TryGetValue(AName, LInfo) then
      Exit;
  finally
    FLock.Leave;
  end;

  if FSession = nil then
    Exit;

  // BUG-BA-012 fix: route through ScriptStore (built-in template uses
  // CSS.escape, so attribute values containing quotes / Unicode produce
  // valid selectors). Falls back to a minimal inline if ScriptStore is
  // unavailable in test environments.
  LStore := ScriptStore;
  if (LStore <> nil) and LStore.HasScript(JSCRIPT_SELECTOR_HEAL) then
    LJS := LStore.Render(JSCRIPT_SELECTOR_HEAL, [])
  else
    LJS :=
      '(function(){try{' +
      'var c=document.querySelectorAll(' +
      '"[data-testid],[aria-label],[name],[placeholder]");var r=[];' +
      'var esc=function(s){return String(s).replace(/(["\\])/g,"\\$1");};' +
      'for(var i=0;i<c.length;i++){var el=c[i];' +
      'var tid=el.getAttribute("data-testid");' +
      'var lbl=el.getAttribute("aria-label");' +
      'var nm=el.getAttribute("name");' +
      'var ph=el.getAttribute("placeholder");' +
      'if(tid)r.push("[data-testid=\""+esc(tid)+"\"]");' +
      'else if(lbl)r.push("[aria-label=\""+esc(lbl)+"\"]");' +
      'else if(nm)r.push("[name=\""+esc(nm)+"\"]");' +
      'else if(ph)r.push("[placeholder=\""+esc(ph)+"\"]");}' +
      'return JSON.stringify(r);}catch(e){return "[]";}})();';

  LResult := '';
  if not FSession.EvaluateScript(LJS, 5000, LResult, LError) then
    Exit;

  LJson := TJSONObject.ParseJSONValue(LResult);
  if LJson = nil then
    Exit;
  try
    if not (LJson is TJSONArray) then
      Exit;
    LSelectors := LJson as TJSONArray;
    for I := 0 to LSelectors.Count - 1 do
    begin
      LCandidate := LSelectors.Items[I].Value;
      if ValidateAgainstBrowser(LCandidate) then
      begin
        ANewSelector := LCandidate;

        FLock.Enter;
        try
          LInfo.Selector := LCandidate;
          LInfo.IsValid := True;
          LInfo.LastValidatedAt := Now;
          FCache[AName] := LInfo;
        finally
          FLock.Leave;
        end;

        Logger.InfoFmt('Selector self-healed: %s -> %s',
          [AName, LCandidate],
          'TBrowserSelectorManager');
        Result := True;
        Exit;
      end;
    end;
  finally
    LJson.Free;
  end;
end;

procedure TBrowserSelectorManager.InvalidateCache;
begin
  FLock.Enter;
  try
    FCache.Clear;
  finally
    FLock.Leave;
  end;
end;

procedure TBrowserSelectorManager.InvalidateSelector(
  const AName: string);
var
  LInfo: TBrowserSelectorInfo;
begin
  FLock.Enter;
  try
    if FCache.TryGetValue(AName, LInfo) then
    begin
      LInfo.IsValid := False;
      FCache[AName] := LInfo;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TBrowserSelectorManager.LoadFromConfig(
  const AJson: string);
var
  LRoot: TJSONValue;
  LArr: TJSONArray;
  I: Integer;
  LItem: TJSONObject;
  LName, LSelector, LFallback: string;
begin
  LRoot := TJSONObject.ParseJSONValue(AJson);
  if LRoot = nil then
    Exit;
  try
    if not (LRoot is TJSONArray) then
      Exit;
    LArr := LRoot as TJSONArray;
    for I := 0 to LArr.Count - 1 do
    begin
      if not (LArr.Items[I] is TJSONObject) then
        Continue;
      LItem := LArr.Items[I] as TJSONObject;
      LName := LItem.GetValue<string>('name', '');
      LSelector := LItem.GetValue<string>('selector', '');
      LFallback := LItem.GetValue<string>('fallback', '');
      if (LName <> '') and (LSelector <> '') then
        RegisterSelector(LName, LSelector, LFallback);
    end;
  finally
    LRoot.Free;
  end;
end;

function TBrowserSelectorManager.ToConfig: string;
var
  LArr: TJSONArray;
  LItem: TJSONObject;
  LSnapshot: TArray<TBrowserSelectorInfo>;
  LInfo: TBrowserSelectorInfo;
  I: Integer;
begin
  // BUG-BA-016 fix: snapshot under lock, serialize outside.
  // Avoids holding FLock across potentially slow JSON serialization.
  FLock.Enter;
  try
    SetLength(LSnapshot, FCache.Count);
    I := 0;
    for LInfo in FCache.Values do
    begin
      LSnapshot[I] := LInfo;
      Inc(I);
    end;
  finally
    FLock.Leave;
  end;

  LArr := TJSONArray.Create;
  try
    for I := 0 to High(LSnapshot) do
    begin
      LItem := TJSONObject.Create;
      LItem.AddPair('name', LSnapshot[I].Name);
      LItem.AddPair('selector', LSnapshot[I].Selector);
      LItem.AddPair('fallback', LSnapshot[I].FallbackSelector);
      LItem.AddPair('valid',
        TJSONBool.Create(LSnapshot[I].IsValid));
      LArr.AddElement(LItem);
    end;
    Result := LArr.ToJSON;
  finally
    LArr.Free;
  end;
end;

function TBrowserSelectorManager.GetSelectorInfo(
  const AName: string): TBrowserSelectorInfo;
begin
  FLock.Enter;
  try
    if not FCache.TryGetValue(AName, Result) then
    begin
      Result := Default(TBrowserSelectorInfo);
      Result.Name := AName;
    end;
  finally
    FLock.Leave;
  end;
end;

function TBrowserSelectorManager.GetRegisteredNames: TArray<string>;
begin
  FLock.Enter;
  try
    Result := FCache.Keys.ToArray;
  finally
    FLock.Leave;
  end;
end;

function TBrowserSelectorManager.Count: Integer;
begin
  FLock.Enter;
  try
    Result := FCache.Count;
  finally
    FLock.Leave;
  end;
end;

function TBrowserSelectorManager.ValidateAgainstBrowser(
  const ASelector: string): Boolean;
var
  LResult, LError: string;
  LBool: Boolean;
begin
  if FSession = nil then
    Exit(True);

  if not FSession.EvaluateScript(
    TBrowserAutomationScripts.BuildExistsScript(ASelector),
    5000, LResult, LError) then
    Exit(False);

  // BUG-BA-011 fix: reuse the canonical TryJsonBool from BrowserAutomation
  // so we recognise CDP-shaped {"result":{"type":"boolean","value":true}}
  // and the various truthy literals (true / 1 / yes / on).
  if TryJsonBool(LResult, LBool) then
    Exit(LBool);

  // Fallback heuristic for non-JSON shapes
  Result := (LResult = 'true') or
    (Pos('"exists":true', LResult) > 0) or
    (Pos('"success":true', LResult) > 0);
end;

end.
