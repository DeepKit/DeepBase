{ ============================================================================
  DeepBase.Browser.Vision
  ---------------------------------------------------------------------------
  Version     : 1.0
  Description : Screenshot-based element detection fallback for browser
                automation. When DOM selectors fail, this module can use
                a vision provider (LLM-based or other) to identify UI
                elements from screenshots and compute click/input coordinates.
  ============================================================================ }

unit DeepBase.Browser.Vision;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Types,
  System.Generics.Collections,
  DeepBase.Browser.Types;

type
  TDetectedElement = record
    Description: string;
    Bounds: TRect;
    Confidence: Double;
    Selector: string;
  end;

  TDetectedElementArray = TArray<TDetectedElement>;

  IVisionProvider = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    function DetectElements(
      const AScreenshot: TBytes): TDetectedElementArray;
    function FindElement(const ADescription: string;
      const AScreenshot: TBytes;
      out AElement: TDetectedElement): Boolean;
    function IsAvailable: Boolean;
    function GetName: string;
  end;

  TBrowserVisionFallback = class
  private
    FSession: IBrowserSession;
    FProvider: IVisionProvider;
    FEnabled: Boolean;

    function TakeScreenshot: TBytes;
  public
    constructor Create(ASession: IBrowserSession;
      AProvider: IVisionProvider = nil);

    function TryVisionClick(
      const ADescription: string): Boolean;
    function TryVisionInput(const ADescription,
      AText: string): Boolean;
    function TryVisionFind(const ADescription: string;
      out ABounds: TRect): Boolean;
    function DetectAllElements: TDetectedElementArray;

    property Provider: IVisionProvider
      read FProvider write FProvider;
    property Enabled: Boolean
      read FEnabled write FEnabled;
  end;

  TVisionCache = class
  private
    FCache: TDictionary<string, TDetectedElement>;
    // M5 fix: track insertion timestamp per entry to enforce FMaxAgeMs
    FTimestamps: TDictionary<string, TDateTime>;
    FLock: TCriticalSection;
    FMaxAgeMs: Integer;
  public
    constructor Create(AMaxAgeMs: Integer = 3600000);
    destructor Destroy; override;
    function Get(const ADescription: string;
      out AElement: TDetectedElement): Boolean;
    procedure Put(const ADescription: string;
      const AElement: TDetectedElement);
    procedure Clear;
  end;

implementation

uses
  System.JSON,
  System.DateUtils,
  DeepBase.Browser.CDP,
  DeepBase.Browser.Events,
  DeepBase.Logging;

{ TBrowserVisionFallback }

constructor TBrowserVisionFallback.Create(
  ASession: IBrowserSession; AProvider: IVisionProvider);
begin
  inherited Create;
  FSession := ASession;
  FProvider := AProvider;
  FEnabled := AProvider <> nil;
end;

function TBrowserVisionFallback.TakeScreenshot: TBytes;
var
  LError: string;
begin
  Result := nil;
  if FSession = nil then
    Exit;
  if not FSession.CaptureScreenshot(Result, LError) then
    Logger.WarnFmt('Vision screenshot failed: %s',
      [LError], 'TBrowserVisionFallback');
end;

function TBrowserVisionFallback.TryVisionClick(
  const ADescription: string): Boolean;
var
  LElement: TDetectedElement;
  LImage: TBytes;
  LCenterX, LCenterY: Double;
  LResult, LError: string;
begin
  Result := False;
  if not FEnabled or (FProvider = nil) then
    Exit;

  LImage := TakeScreenshot;
  if Length(LImage) = 0 then
    Exit;

  if not FProvider.FindElement(ADescription, LImage,
    LElement) then
  begin
    Logger.InfoFmt('Vision element not found: %s',
      [ADescription], 'TBrowserVisionFallback');
    Exit;
  end;

  LCenterX := (LElement.Bounds.Left + LElement.Bounds.Right) / 2;
  LCenterY := (LElement.Bounds.Top + LElement.Bounds.Bottom) / 2;

  // BUG-BA-019 fix: distinct out variables for AJsonResult vs AError.
  // H7 fix: use JsFloat for locale-independent numeric formatting.
  Result := FSession.CallDevToolsProtocol(
    'Input.dispatchMouseEvent',
    '{"type":"mousePressed","x":' + JsFloat(LCenterX) +
    ',"y":' + JsFloat(LCenterY) +
    ',"button":"left","clickCount":1}',
    5000, LResult, LError);

  if Result then
    Result := FSession.CallDevToolsProtocol(
      'Input.dispatchMouseEvent',
      '{"type":"mouseReleased","x":' + JsFloat(LCenterX) +
      ',"y":' + JsFloat(LCenterY) +
      ',"button":"left","clickCount":1}',
      5000, LResult, LError);

  if Result then
    Logger.InfoFmt('Vision click succeeded: %s at (%.0f,%.0f)',
      [ADescription, LCenterX, LCenterY],
      'TBrowserVisionFallback')
  else if LError <> '' then
    Logger.WarnFmt('Vision click CDP error: %s', [LError],
      'TBrowserVisionFallback');
end;

function TBrowserVisionFallback.TryVisionInput(
  const ADescription, AText: string): Boolean;
var
  LElement: TDetectedElement;
  LImage: TBytes;
  LCenterX, LCenterY: Double;
  LError, LResult: string;
begin
  Result := False;
  if not FEnabled or (FProvider = nil) then
    Exit;

  LImage := TakeScreenshot;
  if Length(LImage) = 0 then
    Exit;

  if not FProvider.FindElement(ADescription, LImage,
    LElement) then
    Exit;

  // Click to focus
  LCenterX := (LElement.Bounds.Left + LElement.Bounds.Right) / 2;
  LCenterY := (LElement.Bounds.Top + LElement.Bounds.Bottom) / 2;

  // BUG-BA-019 fix: check return values; abort early on CDP failure.
  // H7 fix: locale-safe float formatting.
  if not FSession.CallDevToolsProtocol(
    'Input.dispatchMouseEvent',
    '{"type":"mousePressed","x":' + JsFloat(LCenterX) +
    ',"y":' + JsFloat(LCenterY) +
    ',"button":"left","clickCount":1}',
    5000, LResult, LError) then
    Exit(False);

  if not FSession.CallDevToolsProtocol(
    'Input.dispatchMouseEvent',
    '{"type":"mouseReleased","x":' + JsFloat(LCenterX) +
    ',"y":' + JsFloat(LCenterY) +
    ',"button":"left","clickCount":1}',
    5000, LResult, LError) then
    Exit(False);

  // C4 fix: leak-free string literal builder.
  Result := FSession.CallDevToolsProtocol(
    'Input.insertText',
    '{"text":' + JsStringLiteral(AText) + '}',
    5000, LResult, LError);
end;

function TBrowserVisionFallback.TryVisionFind(
  const ADescription: string; out ABounds: TRect): Boolean;
var
  LElement: TDetectedElement;
  LImage: TBytes;
begin
  Result := False;
  ABounds := Rect(0, 0, 0, 0);
  if not FEnabled or (FProvider = nil) then
    Exit;

  LImage := TakeScreenshot;
  if Length(LImage) = 0 then
    Exit;

  Result := FProvider.FindElement(ADescription, LImage,
    LElement);
  if Result then
    ABounds := LElement.Bounds;
end;

function TBrowserVisionFallback.DetectAllElements:
  TDetectedElementArray;
var
  LImage: TBytes;
begin
  Result := nil;
  if not FEnabled or (FProvider = nil) then
    Exit;

  LImage := TakeScreenshot;
  if Length(LImage) = 0 then
    Exit;

  Result := FProvider.DetectElements(LImage);
end;

{ TVisionCache }

constructor TVisionCache.Create(AMaxAgeMs: Integer);
begin
  inherited Create;
  FMaxAgeMs := AMaxAgeMs;
  FCache := TDictionary<string, TDetectedElement>.Create;
  FTimestamps := TDictionary<string, TDateTime>.Create;
  FLock := TCriticalSection.Create;
end;

destructor TVisionCache.Destroy;
begin
  FLock.Free;
  FTimestamps.Free;
  FCache.Free;
  inherited;
end;

function TVisionCache.Get(const ADescription: string;
  out AElement: TDetectedElement): Boolean;
var
  LKey: string;
  LStamp: TDateTime;
begin
  LKey := LowerCase(ADescription);
  FLock.Enter;
  try
    Result := FCache.TryGetValue(LKey, AElement);
    if not Result then Exit;

    // M5 fix: enforce FMaxAgeMs - evict stale entries on read
    if FTimestamps.TryGetValue(LKey, LStamp) then
    begin
      if MilliSecondsBetween(Now, LStamp) > FMaxAgeMs then
      begin
        FCache.Remove(LKey);
        FTimestamps.Remove(LKey);
        Result := False;
        AElement := Default(TDetectedElement);
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TVisionCache.Put(const ADescription: string;
  const AElement: TDetectedElement);
var
  LKey: string;
begin
  LKey := LowerCase(ADescription);
  FLock.Enter;
  try
    FCache.AddOrSetValue(LKey, AElement);
    FTimestamps.AddOrSetValue(LKey, Now);
  finally
    FLock.Leave;
  end;
end;

procedure TVisionCache.Clear;
begin
  FLock.Enter;
  try
    FCache.Clear;
    FTimestamps.Clear;
  finally
    FLock.Leave;
  end;
end;

end.
