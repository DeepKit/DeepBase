{ ============================================================================
  DeepBase.UIA.UnifiedActuator
  ---------------------------------------------------------------------------
  Version     : 0.1 (Unstable API)
  Description : Unified actuator that orchestrates the UIA engine (primary,
                high-fidelity channel) with desktop perception (optional
                visual fallback channel). This is the actuation-layer entry
                point promised by docs/34/docs/87: one executor, two
                channels.

                Policy semantics:
                - fpStrict: UIA only. A UIA miss raises EUIAElementNotFound,
                  exactly as the raw engine does. No visual fallback ever.
                - fpBestEffort: UIA first; on miss, if a perception engine is
                  attached, capture + recognize by label, then act at the
                  perceived center coordinate via mouse/keyboard simulation.

                The UIA engine itself is NOT modified. This unit composes it.
                Perception is an optional dependency (can be nil); when nil,
                the actuator behaves as the raw engine regardless of policy.
                No business semantics.
  ========================================================================== }

unit DeepBase.UIA.UnifiedActuator;

interface

uses
  System.SysUtils,
  System.Types,
  System.SyncObjs,
  Winapi.Windows,
  DeepBase.Logging,
  DeepBase.Exceptions,
  DeepBase.UIA.Types,
  DeepBase.UIA.Engine,
  DeepBase.Desktop.Perception.Types,
  DeepBase.Desktop.Perception.Engine,
  DeepBase.ClipboardGuard;

type
  // Result of a unified actuation attempt. Describes which channel resolved
  // the target, for observability. Neutral: no business words.
  TActuationChannel = (acUIA, acVisual, acNone);

  TActuationResult = record
    Success: Boolean;
    Channel: TActuationChannel;
    ErrorMessage: string;
  end;

  // Unified executor. Holds a UIA engine and an optional perception engine.
  TUnifiedActuator = class
  private
    FUIAEngine: TUIAEngineWin32;
    FPerception: TDesktopPerceptionEngine;
    FClipboardGuardFactory: TFunc<IClipboardGuard>;
    FLock: TCriticalSection;
    function ResolveVisualTarget(const ALabel: string;
      out APoint: TPoint): Boolean;
    function ClickAt(const APoint: TPoint): Boolean;
    function TypeAt(const APoint: TPoint; const AText: string): Boolean;
  public
    constructor Create(const AUIAEngine: TUIAEngineWin32;
      const APerception: TDesktopPerceptionEngine = nil;
      const AClipboardGuardFactory: TFunc<IClipboardGuard> = nil);
    destructor Destroy; override;

    // Click an element. UIA Locator is primary; AVisualLabel is the visual
    // fallback label used only under fpBestEffort when UIA misses.
    function Click(const ALocator: TUIAElementLocator;
      const APolicy: TFallbackPolicy;
      const AVisualLabel: string = ''): TActuationResult;
    // Input text into an element. Visual fallback types at the perceived
    // center via clipboard-free keystroke simulation.
    function InputText(const ALocator: TUIAElementLocator;
      const AValue: string; const APolicy: TFallbackPolicy;
      const AVisualLabel: string = ''): TActuationResult;

    property Perception: TDesktopPerceptionEngine read FPerception;
  end;

implementation

{ TUnifiedActuator }

constructor TUnifiedActuator.Create(const AUIAEngine: TUIAEngineWin32;
  const APerception: TDesktopPerceptionEngine;
  const AClipboardGuardFactory: TFunc<IClipboardGuard>);
begin
  inherited Create;
  FUIAEngine := AUIAEngine;
  FPerception := APerception;
  FClipboardGuardFactory := AClipboardGuardFactory;
  FLock := TCriticalSection.Create;
  if AUIAEngine = nil then
    raise EArgumentException.Create('TUnifiedActuator requires a UIA engine');
end;

destructor TUnifiedActuator.Destroy;
begin
  FLock.Free;
  inherited;
end;

function TUnifiedActuator.ResolveVisualTarget(const ALabel: string;
  out APoint: TPoint): Boolean;
var
  LShot: TDesktopScreenshot;
  LElement: TPerceivedElement;
begin
  Result := False;
  APoint := TPoint.Zero;
  if (FPerception = nil) or (ALabel = '') then
    Exit;
  if not FPerception.Enabled then
    Exit;
  LShot := FPerception.CaptureScreen;
  if not LShot.IsValid then
    Exit;
  if FPerception.FindByLabel(LShot, ALabel, LElement) and LElement.IsValid then
  begin
    APoint := LElement.Center;
    Result := True;
  end;
end;

function TUnifiedActuator.ClickAt(const APoint: TPoint): Boolean;
begin
  Result := False;
  if (APoint.X < 0) or (APoint.Y < 0) then
    Exit;
  try
    SetCursorPos(APoint.X, APoint.Y);
    mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0);
    mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0);
    Result := True;
  except
    on E: Exception do
    begin
      Logger.Warn('Visual click failed: ' + E.Message, 'Actuator');
      Result := False;
    end;
  end;
end;

function TUnifiedActuator.TypeAt(const APoint: TPoint;
  const AText: string): Boolean;
var
  I: Integer;
  LInput: array[0..1] of TInput;
  LKey: Word;
begin
  Result := False;
  if AText = '' then
    Exit(True);
  if not ClickAt(APoint) then
    Exit;
  Sleep(50); // allow focus to settle on the clicked target
  try
    // Simple keystroke simulation via SendInput. Adequate for ASCII; the
    // clipboard-based UIA SetValue path remains preferred for complex text.
    for I := 1 to Length(AText) do
    begin
      LKey := Ord(AText[I]);
      if LKey > 255 then
        Continue; // non-ASCII skipped in this minimal visual path
      FillChar(LInput, SizeOf(LInput), 0);
      LInput[0].Itype := INPUT_KEYBOARD;
      LInput[0].ki.wScan := 0;
      LInput[0].ki.dwFlags := KEYEVENTF_UNICODE;
      LInput[0].ki.wScan := LKey;
      LInput[1].Itype := INPUT_KEYBOARD;
      LInput[1].ki.wScan := LKey;
      LInput[1].ki.dwFlags := KEYEVENTF_UNICODE or KEYEVENTF_KEYUP;
      SendInput(2, LInput[0], SizeOf(TInput));
    end;
    Result := True;
  except
    on E: Exception do
    begin
      Logger.Warn('Visual type failed: ' + E.Message, 'Actuator');
      Result := False;
    end;
  end;
end;

function TUnifiedActuator.Click(const ALocator: TUIAElementLocator;
  const APolicy: TFallbackPolicy; const AVisualLabel: string): TActuationResult;
var
  LPoint: TPoint;
begin
  Result := Default(TActuationResult);
  Result.Channel := acNone;
  FLock.Enter;
  try
    // Primary channel: UIA Invoke.
    try
      if FUIAEngine.Invoke(ALocator) then
      begin
        Result.Success := True;
        Result.Channel := acUIA;
        Exit;
      end;
    except
      on EUIAElementNotFound do
      begin
        if APolicy = fpStrict then
          raise; // strict: preserve original engine behavior
      end;
    end;

    // fpBestEffort + miss: visual fallback.
    if APolicy <> fpBestEffort then
      Exit;
    if ResolveVisualTarget(AVisualLabel, LPoint) and ClickAt(LPoint) then
    begin
      Result.Success := True;
      Result.Channel := acVisual;
      Logger.Info('Click resolved via visual fallback at ('
        + IntToStr(LPoint.X) + ',' + IntToStr(LPoint.Y) + ')', 'Actuator');
    end
    else
      Result.ErrorMessage := 'UIA miss and visual fallback unavailable';
  finally
    FLock.Leave;
  end;
end;

function TUnifiedActuator.InputText(const ALocator: TUIAElementLocator;
  const AValue: string; const APolicy: TFallbackPolicy;
  const AVisualLabel: string): TActuationResult;
var
  LGuard: IClipboardGuard;
  LPoint: TPoint;
begin
  Result := Default(TActuationResult);
  Result.Channel := acNone;
  FLock.Enter;
  try
    // Primary channel: UIA SetValue (clipboard-guarded).
    try
      LGuard := nil;
      if Assigned(FClipboardGuardFactory) then
        LGuard := FClipboardGuardFactory();
      if FUIAEngine.SetValue(ALocator, AValue, LGuard) then
      begin
        Result.Success := True;
        Result.Channel := acUIA;
        Exit;
      end;
    except
      on EUIAElementNotFound do
      begin
        if APolicy = fpStrict then
          raise;
      end;
    end;

    if APolicy <> fpBestEffort then
      Exit;
    if ResolveVisualTarget(AVisualLabel, LPoint) and TypeAt(LPoint, AValue) then
    begin
      Result.Success := True;
      Result.Channel := acVisual;
      Logger.Info('InputText resolved via visual fallback', 'Actuator');
    end
    else
      Result.ErrorMessage := 'UIA miss and visual fallback unavailable';
  finally
    FLock.Leave;
  end;
end;

end.
