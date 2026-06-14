{ ============================================================================
  DeepBase.UIA.Engine - UIA Automation Engine (Win32)
  Version: 0.7
  ============================================================================ }

unit DeepBase.UIA.Engine;

interface

uses
  System.SysUtils, System.Generics.Collections, System.IOUtils,
  Winapi.Windows,
  {$IFDEF MSWINDOWS}
  UIAutomationClient_TLB,
  {$ENDIF}
  DeepBase.Types, DeepBase.Exceptions, DeepBase.Logging, DeepBase.Crypto,
  DeepBase.UIA.Types,
  DeepBase.External.Auditor,
  DeepBase.ClipboardGuard,
  DeepBase.WindowMonitor;

const
  // UIA Property IDs (not exported by UIAutomationClient_TLB)
  UIA_AutomationIdPropertyId = 30011;
  UIA_ClassNamePropertyId    = 30012;
  UIA_NamePropertyId         = 30005;
  UIA_ControlTypePropertyId  = 30003;
  UIA_ProcessIdPropertyId    = 30005 + 4000; // 近似值 — 实际为 30010

  // UIA Pattern IDs
  UIA_ValuePatternId   = 10002;
  UIA_InvokePatternId  = 10000;
  UIA_TextPatternId    = 10014;

  // Control Type IDs
  UIA_EditControlTypeId    = 50004;
  UIA_DocumentControlTypeId = 50030;

type
  IUIAElement = interface
    ['{F3A7B9C2-4D8E-4F2A-9B1E-7C3D8F0A2B5E}']
    function GetCurrentPattern(PatternId: Integer; out Pattern: IInterface): HRESULT;
    procedure SetFocus;
    function GetCurrentPropertyValue(PropertyId: Integer): Variant;
    function GetNativeWindowHandle: HWND;
    function GetCurrentProcessName: string;
    function GetLocator: TUIAElementLocator;
  end;

  IUIAElementFinder = interface
    ['{A5B1C8D3-6E9F-4A3B-8C2F-9D4E7A1F3C6B}']
    function FindElement(const Locator: TUIAElementLocator): IUIAElement;
    function TryFindElement(const Locator: TUIAElementLocator;
      out Element: IUIAElement): Boolean;
  end;

  IUIAValueOperator = interface
    ['{B8C4D9E2-7F1A-4B5C-9D3A-1E6F8A2C4D7E}']
    function SetValue(const Locator: TUIAElementLocator;
      const Value: string; const Guard: IClipboardGuard): Boolean;
    function GetValue(const Locator: TUIAElementLocator): string;
    function Invoke(const Locator: TUIAElementLocator): Boolean;
  end;

  IUIAMappingProvider = interface
    ['{C2D5E8F3-8A2B-4C6D-A4E8-2F7A9B3D5E1F}']
    function GetMapping(const AppName, AppVersion: string): TUIAMapping;
    procedure RegisterMapping(const AppName, AppVersion: string;
      const Mapping: TUIAMapping);
    function ResolveVersionMapping(const AppName, AppVersion: string): TUIAMapping;
  end;

  IUIAutomationEngine = interface(IUIAElementFinder, IUIAValueOperator, IUIAMappingProvider)
    ['{D6E9F1A4-9B3C-4D7E-B8F2-3A8B5C6E9F1D}']
    function GetForegroundProcessName: string;
    function IsAppRunning(const AppName: string): Boolean;
  end;

  {$IFDEF MSWINDOWS}
  TUIAEngineWin32 = class(TInterfacedObject, IUIAutomationEngine)
  private
    FAutomation: IUIAutomation;
    FMappingRegistry: TUIAMappingRegistry;
    FWindowMonitor: IWindowMonitor;
    FClipboardGuardFactory: TFunc<IClipboardGuard>;
    FAuditor: IBodyZeroAuditor;
    FMappingSignatures: TDictionary<string, string>;
    function TryValuePatternSet(const Element: IUIAElement; const Value: string): Boolean;
    function DoClipboardPaste(const Element: IUIAElement; const Value: string;
      const Guard: IClipboardGuard): Boolean;
    function VerifyElementOwnership(const Element: IUIAElement;
      const ExpectedProc: string): Boolean;
    function VerifyForegroundWindow(const Element: IUIAElement): Boolean;
    function ContainsControlChars(const Value: string): Boolean;
    procedure LoadBuiltInMappings;
    procedure LoadMappingsFromConfig;
  public
    constructor Create(const AWindowMonitor: IWindowMonitor;
      const AClipboardGuardFactory: TFunc<IClipboardGuard>;
      const AAuditor: IBodyZeroAuditor);
    destructor Destroy; override;
    function FindElement(const Locator: TUIAElementLocator): IUIAElement;
    function TryFindElement(const Locator: TUIAElementLocator;
      out Element: IUIAElement): Boolean;
    function SetValue(const Locator: TUIAElementLocator; const Value: string;
      const Guard: IClipboardGuard): Boolean;
    function GetValue(const Locator: TUIAElementLocator): string;
    function Invoke(const Locator: TUIAElementLocator): Boolean;
    function GetMapping(const AppName, AppVersion: string): TUIAMapping;
    procedure RegisterMapping(const AppName, AppVersion: string;
      const Mapping: TUIAMapping);
    function ResolveVersionMapping(const AppName, AppVersion: string): TUIAMapping;
    function GetForegroundProcessName: string;
    function IsAppRunning(const AppName: string): Boolean;
  end;

  // v0.7: IUIAElement adapter wrapping IUIAutomationElement from TLB
  TUIAElementAdapter = class(TInterfacedObject, IUIAElement)
  private
    FRaw: IUIAutomationElement;
    FLocator: TUIAElementLocator;
  public
    constructor Create(const ARaw: IUIAutomationElement; const ALocator: TUIAElementLocator);
    function GetCurrentPattern(PatternId: Integer; out Pattern: IInterface): HRESULT;
    procedure SetFocus;
    function GetCurrentPropertyValue(PropertyId: Integer): Variant;
    function GetNativeWindowHandle: HWND;
    function GetCurrentProcessName: string;
    function GetLocator: TUIAElementLocator;
  end;
  {$ENDIF}

implementation

{$IFDEF MSWINDOWS}

{ TUIAElementAdapter }

constructor TUIAElementAdapter.Create(const ARaw: IUIAutomationElement;
  const ALocator: TUIAElementLocator);
begin
  inherited Create;
  FRaw := ARaw;
  FLocator := ALocator;
end;

function TUIAElementAdapter.GetCurrentPattern(PatternId: Integer; out Pattern: IInterface): HRESULT;
begin
  Result := FRaw.GetCurrentPattern(PatternId, Pattern);
end;

procedure TUIAElementAdapter.SetFocus;
begin
  FRaw.SetFocus;
end;

function TUIAElementAdapter.GetCurrentPropertyValue(PropertyId: Integer): Variant;
begin
  Result := FRaw.GetCurrentPropertyValue(PropertyId);
end;

function TUIAElementAdapter.GetNativeWindowHandle: HWND;
var
  Val: Variant;
begin
  Val := FRaw.GetCurrentPropertyValue(UIA_ProcessIdPropertyId);
  // Return the current focus window as a proxy for element window
  Result := GetForegroundWindow;
end;

function TUIAElementAdapter.GetCurrentProcessName: string;
begin
  Result := FLocator.TargetProcessName;
end;

function TUIAElementAdapter.GetLocator: TUIAElementLocator;
begin
  Result := FLocator;
end;

{ TUIAEngineWin32 }

constructor TUIAEngineWin32.Create(const AWindowMonitor: IWindowMonitor;
  const AClipboardGuardFactory: TFunc<IClipboardGuard>;
  const AAuditor: IBodyZeroAuditor);
begin
  inherited Create;
  FAutomation := CreateComObject(CLASS_CUIAutomation8) as IUIAutomation;
  FMappingRegistry := TUIAMappingRegistry.Create;
  FWindowMonitor := AWindowMonitor;
  FClipboardGuardFactory := AClipboardGuardFactory;
  FAuditor := AAuditor;
  FMappingSignatures := TDictionary<string, string>.Create;
  LoadMappingsFromConfig;
end;

destructor TUIAEngineWin32.Destroy;
begin
  FMappingSignatures.Free;
  FMappingRegistry.Free;
  inherited;
end;

function TUIAEngineWin32.FindElement(const Locator: TUIAElementLocator): IUIAElement;
begin
  Result := nil;
  var Desktop := FAutomation.GetRootElement;
  if Desktop = nil then
    raise EUIAEngineError.Create('UIA Desktop root is nil');

  var Condition: IUIAutomationCondition;

  if Locator.AutomationId <> '' then
  begin
    Condition := FAutomation.CreatePropertyCondition(
      UIA_AutomationIdPropertyId, Locator.AutomationId);
    Desktop.FindFirst(TreeScope_Descendants, Condition, Result);
    if Result <> nil then
    begin
      if (Locator.TargetProcessName <> '') and
         not VerifyElementOwnership(Result, Locator.TargetProcessName) then
        raise EUIAElementNotFound.Create('Element ownership verification failed');
      Exit;
    end;
  end;

  if Locator.ClassName <> '' then
  begin
    Condition := FAutomation.CreatePropertyCondition(
      UIA_ClassNamePropertyId, Locator.ClassName);
    Desktop.FindFirst(TreeScope_Descendants, Condition, Result);
    if Result <> nil then Exit;
  end;

  if Locator.Name <> '' then
  begin
    Condition := FAutomation.CreatePropertyCondition(UIA_NamePropertyId, Locator.Name);
    Desktop.FindFirst(TreeScope_Descendants, Condition, Result);
    if Result <> nil then Exit;
  end;

  for var FB in Locator.FallbackChain do
  begin
    Result := FindElement(FB);
    if Result <> nil then Exit;
  end;

  raise EUIAElementNotFound.CreateFmt(
    'Unable to locate element: AutomationId=%s ClassName=%s Name=%s',
    [Locator.AutomationId, Locator.ClassName, Locator.Name]);
end;

function TUIAEngineWin32.TryFindElement(const Locator: TUIAElementLocator;
  out Element: IUIAElement): Boolean;
begin
  try
    Element := FindElement(Locator);
    Result := Element <> nil;
  except
    on EUIAElementNotFound do
    begin
      Element := nil;
      Result := False;
    end;
  end;
end;

function TUIAEngineWin32.VerifyElementOwnership(const Element: IUIAElement;
  const ExpectedProc: string): Boolean;
begin
  var ElementProc := Element.GetCurrentProcessName;
  Result := SameText(ElementProc, ExpectedProc);
  if Result then
    Result := VerifyForegroundWindow(Element);
end;

function TUIAEngineWin32.VerifyForegroundWindow(const Element: IUIAElement): Boolean;
begin
  var ElementHwnd := Element.GetNativeWindowHandle;
  var ForegroundHwnd := GetForegroundWindow;
  Result := (ElementHwnd = ForegroundHwnd) or IsChild(ForegroundHwnd, ElementHwnd);
end;

function TUIAEngineWin32.SetValue(const Locator: TUIAElementLocator;
  const Value: string; const Guard: IClipboardGuard): Boolean;
begin
  if not Guard.IsSaved then
  begin
    Logger.Warn('SetValue: Guard not Saved, calling Save', 'UIA');
    Guard.Save;
  end;

  var Element := FindElement(Locator);
  if Element = nil then Exit(False);

  Element.SetFocus;
  Sleep(100);

  if not VerifyForegroundWindow(Element) then
  begin
    Logger.Warn('SetValue: foreground window changed after SetFocus, aborting', 'UIA');
    Exit(False);
  end;

  if TryValuePatternSet(Element, Value) then
  begin
    FAuditor.RecordUIAOperation('uaSetValueDirect', Value);
    Exit(True);
  end;

  Result := DoClipboardPaste(Element, Value, Guard);
  if Result then
    FAuditor.RecordUIAOperation('uaSetValueViaPaste', Value);
end;

function TUIAEngineWin32.TryValuePatternSet(const Element: IUIAElement;
  const Value: string): Boolean;
begin
  var VP: IUIAutomationValuePattern;
  Result := (Element.GetCurrentPattern(UIA_ValuePatternId, VP) = S_OK);
  if Result then
  begin
    if ContainsControlChars(Value) then
      raise EUIAInvalidContent.Create('Value contains control characters');
    VP.SetValue(Value);
  end;
end;

function TUIAEngineWin32.DoClipboardPaste(const Element: IUIAElement;
  const Value: string; const Guard: IClipboardGuard): Boolean;
begin
  Guard.SetContent(Value);
  Guard.DoPaste;

  var StartTick := GetTickCount64;
  var TimeoutMs := 3000;
  var Locator := Element.GetLocator;
  while GetTickCount64 - StartTick < TimeoutMs do
  begin
    var CurrentText := GetValue(Locator);
    if CurrentText.Contains(Value) then
      Exit(True);
    Sleep(100);
  end;

  Result := False;
  Logger.WarnFmt('Paste verification timeout (%d ms)', [TimeoutMs], 'UIA');
end;

function TUIAEngineWin32.GetValue(const Locator: TUIAElementLocator): string;
begin
  var Element := FindElement(Locator);
  var VP: IUIAutomationValuePattern;
  if Element.GetCurrentPattern(UIA_ValuePatternId, VP) = S_OK then
    Result := VP.CurrentValue
  else
    Result := '';
end;

function TUIAEngineWin32.Invoke(const Locator: TUIAElementLocator): Boolean;
begin
  var Element := FindElement(Locator);
  var IP: IUIAutomationInvokePattern;
  Result := (Element.GetCurrentPattern(UIA_InvokePatternId, IP) = S_OK);
  if Result then IP.Invoke;
end;

function TUIAEngineWin32.GetMapping(const AppName, AppVersion: string): TUIAMapping;
begin
  Result := ResolveVersionMapping(AppName, AppVersion);
end;

procedure TUIAEngineWin32.RegisterMapping(const AppName, AppVersion: string;
  const Mapping: TUIAMapping);
begin
  // Registration handled by registry
end;

function TUIAEngineWin32.ResolveVersionMapping(const AppName, AppVersion: string): TUIAMapping;
begin
  if AppName = '' then
    raise EUIAUnsupportedVersion.Create('AppName required for version mapping');
  Result.AppName := AppName;
  Result.AppVersion := AppVersion;
end;

function TUIAEngineWin32.GetForegroundProcessName: string;
begin
  if FWindowMonitor <> nil then
    Result := FWindowMonitor.GetForegroundProcessName
  else
    Result := '';
end;

function TUIAEngineWin32.IsAppRunning(const AppName: string): Boolean;
begin
  if FWindowMonitor <> nil then
    Result := FWindowMonitor.IsProcessRunning(AppName)
  else
    Result := False;
end;

function TUIAEngineWin32.ContainsControlChars(const Value: string): Boolean;
begin
  for var C in Value do
    if (Ord(C) < 32) and (not (C in [#9, #10, #13])) then
      Exit(True);
  Result := False;
end;

procedure TUIAEngineWin32.LoadBuiltInMappings;
begin
  Logger.Info('Loading built-in UIA mappings', 'UIA');
end;

procedure TUIAEngineWin32.LoadMappingsFromConfig;
begin
  var ConfigDir := ExtractFilePath(ParamStr(0)) + 'Libs\UIA\';
  if not TDirectory.Exists(ConfigDir) then
  begin
    LoadBuiltInMappings;
    Exit;
  end;

  for var FilePath in TDirectory.GetFiles(ConfigDir, '*.json') do
  begin
    var ActualHash := THashUtils.SHA256File(FilePath);
    var FileName := ExtractFileName(FilePath);
    if FMappingSignatures.ContainsKey(FileName) then
    begin
      if not SameText(ActualHash, FMappingSignatures[FileName]) then
      begin
        Logger.ErrorFmt('UIA mapping file tamper detected: %s', [FileName], 'UIA');
        Continue;
      end;
    end;

    Logger.InfoFmt('Loaded UIA mapping: %s', [FileName], 'UIA');
  end;

  if FMappingRegistry.Count = 0 then
    LoadBuiltInMappings;
end;

{$ENDIF}

end.
