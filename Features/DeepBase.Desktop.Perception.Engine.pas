{ ============================================================================
  DeepBase.Desktop.Perception.Engine
  ---------------------------------------------------------------------------
  Version     : 0.1 (Unstable API)
  Description : Desktop perception engine. Captures screenshots via GDI
                (BitBlt on the screen DC) and optionally recognizes elements
                through an IDesktopVisionProvider. This unit is pure
                mechanism: it captures and recognizes, it never decides what
                to click or why. No business semantics.
                When no provider is configured, perception degrades to
                screenshot-only (capture works, recognition returns empty).
                DPI scaling is resolved per-capture so screen coordinates are
                consistent with the actuation layer's mouse API.
  ========================================================================== }

unit DeepBase.Desktop.Perception.Engine;

interface

uses
  System.SysUtils,
  System.Types,
  System.Classes,
  System.SyncObjs,
  Winapi.Windows,
  Vcl.Graphics,
  Vcl.Imaging.pngimage,
  DeepBase.Logging,
  DeepBase.Crypto.Encoding,
  DeepBase.Crypto.Hash,
  DeepBase.Desktop.Perception.Types;

type
  // The desktop perception engine. Owns an optional vision provider.
  // Thread-safe for capture; provider calls are serialized by FLock.
  TDesktopPerceptionEngine = class(TInterfacedObject)
  private
    FProvider: IDesktopVisionProvider;
    FLock: TCriticalSection;
    FCache: TPerceptionCache;
    FEnabled: Boolean;
    // Single-slot frame cache for L0 cost gating: when a subsequent Perceive
    // call produces an identical screenshot (same provider identity + same
    // MD5 of ImageBase64), the cached element list is reused and the vision
    // provider is not invoked. Invalidated on provider swap (see SetProvider).
    FFrameCache: TFrameCacheEntry;
    FFrameCacheKey: string;
    function BuildFrameCacheKey(const AShot: TDesktopScreenshot): string;
    // Core recognize-with-frame-cache path shared by both Perceive overloads.
    function PerceiveWithCache(
      const AShot: TDesktopScreenshot): TPerceptionResult;
    function GetDpiScale: Double;
    function CaptureToBitmap(const ARect: TRect): TBitmap;
    function BitmapToPngBase64(const ABitmap: TBitmap;
      out AWidth, AHeight: Integer): string;
  public
    constructor Create(const AProvider: IDesktopVisionProvider = nil);
    destructor Destroy; override;

    // Capture the full virtual screen into a screenshot record. The returned
    // ImageBase64 is a PNG consumable by LLM().ChatVision.
    function CaptureScreen: TDesktopScreenshot; overload;
    // Capture a specific screen rect (physical coordinates).
    function CaptureScreen(const ARect: TRect): TDesktopScreenshot; overload;
    // Capture a specific window. ALocator must resolve to a window handle.
    function CaptureWindow(const ALocator: TWindowLocator): TDesktopScreenshot;

    // Recognize elements in a screenshot via the configured provider.
    // Returns False when no provider is configured (degraded mode).
    function Recognize(const AShot: TDesktopScreenshot;
      out AElements: TPerceivedElementArray): Boolean;
    // Find a single element by label. Checks cache first.
    function FindByLabel(const AShot: TDesktopScreenshot;
      const ALabel: string; out AElement: TPerceivedElement): Boolean;

    // Full perception pass: capture + recognize.
    function Perceive: TPerceptionResult; overload;
    // Perception pass on an already-captured screenshot: recognize (with L0
    // frame-cache reuse) without re-capturing. The capture-free overload lets
    // callers reuse a screenshot and makes the frame cache unit-testable with
    // a fixed shot.
    function Perceive(const AShot: TDesktopScreenshot): TPerceptionResult; overload;

    function GetEnabled: Boolean;
    procedure SetEnabled(AValue: Boolean);
    function GetProvider: IDesktopVisionProvider;
    procedure SetProvider(AValue: IDesktopVisionProvider);

    property Enabled: Boolean read GetEnabled write SetEnabled;
    property Provider: IDesktopVisionProvider read GetProvider write SetProvider;
  end;

implementation

{ TDesktopPerceptionEngine }

constructor TDesktopPerceptionEngine.Create(
  const AProvider: IDesktopVisionProvider);
begin
  inherited Create;
  FProvider := AProvider;
  FLock := TCriticalSection.Create;
  FCache := TPerceptionCache.Create;
  FEnabled := True;
  if AProvider = nil then
    Logger.Info('Desktop perception: no vision provider, degraded to '
      + 'screenshot-only', 'Perception')
  else
    Logger.Info('Desktop perception: provider ' + AProvider.GetName
      + ' attached', 'Perception');
end;

destructor TDesktopPerceptionEngine.Destroy;
begin
  FCache.Free;
  FLock.Free;
  inherited;
end;

function TDesktopPerceptionEngine.GetDpiScale: Double;
var
  LDc: HDC;
begin
  LDc := GetDC(0);
  try
    Result := GetDeviceCaps(LDc, LOGPIXELSX) / 96;
  finally
    ReleaseDC(0, LDc);
  end;
  if Result < 0.5 then
    Result := 1.0;
end;

function TDesktopPerceptionEngine.CaptureToBitmap(const ARect: TRect): TBitmap;
var
  LScreenDc, LMemDc: HDC;
  LOldBmp: HBitmap;
  LWidth, LHeight: Integer;
  LRect: TRect;
begin
  Result := nil;
  LRect := ARect;
  if (LRect.Width <= 0) or (LRect.Height <= 0) then
  begin
    // Default to full virtual screen.
    LRect := Rect(0, 0, GetSystemMetrics(SM_CXSCREEN),
      GetSystemMetrics(SM_CYSCREEN));
    if LRect.Width <= 0 then
      Exit;
  end;

  LWidth := LRect.Width;
  LHeight := LRect.Height;

  LScreenDc := GetDC(0);
  if LScreenDc = 0 then
    Exit;
  try
    LMemDc := CreateCompatibleDC(LScreenDc);
    if LMemDc = 0 then
      Exit;
    try
      Result := TBitmap.Create;
      try
        Result.PixelFormat := pf24bit;
        Result.Width := LWidth;
        Result.Height := LHeight;
        LOldBmp := SelectObject(LMemDc, Result.Handle);
        try
          BitBlt(LMemDc, 0, 0, LWidth, LHeight, LScreenDc, LRect.Left,
            LRect.Top, SRCCOPY);
        finally
          SelectObject(LMemDc, LOldBmp);
        end;
      except
        Result.Free;
        Result := nil;
        raise;
      end;
    finally
      DeleteDC(LMemDc);
    end;
  finally
    ReleaseDC(0, LScreenDc);
  end;
end;

function TDesktopPerceptionEngine.BitmapToPngBase64(const ABitmap: TBitmap;
  out AWidth, AHeight: Integer): string;
var
  LPng: TPngImage;
  LStream: TBytesStream;
begin
  Result := '';
  AWidth := 0;
  AHeight := 0;
  if ABitmap = nil then
    Exit;
  AWidth := ABitmap.Width;
  AHeight := ABitmap.Height;
  LPng := TPngImage.Create;
  try
    LPng.Assign(ABitmap);
    LStream := TBytesStream.Create;
    try
      LPng.SaveToStream(LStream);
      Result := TEncodingUtils.Base64Encode(
        Copy(LStream.Bytes, 0, LStream.Size));
    finally
      LStream.Free;
    end;
  finally
    LPng.Free;
  end;
end;

function TDesktopPerceptionEngine.CaptureScreen: TDesktopScreenshot;
var
  LFullRect: TRect;
begin
  LFullRect := Rect(0, 0, GetSystemMetrics(SM_CXSCREEN),
    GetSystemMetrics(SM_CYSCREEN));
  Result := CaptureScreen(LFullRect);
end;

function TDesktopPerceptionEngine.CaptureScreen(
  const ARect: TRect): TDesktopScreenshot;
var
  LBitmap: TBitmap;
  LDpi: Double;
begin
  Result := Default(TDesktopScreenshot);
  LDpi := GetDpiScale;
  if not FEnabled then
    Exit;
  LBitmap := CaptureToBitmap(ARect);
  if LBitmap = nil then
  begin
    Logger.Warn('CaptureScreen: BitBlt returned nil bitmap', 'Perception');
    Exit;
  end;
  try
    Result.ImageBase64 := BitmapToPngBase64(LBitmap, Result.WidthPx,
      Result.HeightPx);
    Result.MimeType := 'image/png';
    // Store physical (non-scaled) rect so the actuation layer, which uses
    // physical mouse coordinates, can target the same area.
    Result.CaptureRect := ARect;
    if Result.CaptureRect.Width <= 0 then
      Result.CaptureRect := Rect(0, 0, Result.WidthPx, Result.HeightPx);
    if Abs(LDpi - 1.0) > 0.01 then
      Logger.InfoFmt('CaptureScreen: dpi scale %.2f (coords are physical)',
        [LDpi], 'Perception');
  finally
    LBitmap.Free;
  end;
end;

function TDesktopPerceptionEngine.CaptureWindow(
  const ALocator: TWindowLocator): TDesktopScreenshot;
var
  LWnd: HWND;
  LRect: TRect;
begin
  Result := Default(TDesktopScreenshot);
  if not FEnabled then
    Exit;
  LWnd := ALocator.WindowHandle;
  if (LWnd = 0) and (ALocator.TitleContains <> '') then
    LWnd := FindWindow(nil, PChar(ALocator.TitleContains));
  if LWnd = 0 then
  begin
    Logger.Warn('CaptureWindow: window not found', 'Perception');
    Exit;
  end;
  if not GetWindowRect(LWnd, LRect) then
  begin
    Logger.Warn('CaptureWindow: GetWindowRect failed', 'Perception');
    Exit;
  end;
  Result := CaptureScreen(LRect);
end;

function TDesktopPerceptionEngine.BuildFrameCacheKey(
  const AShot: TDesktopScreenshot): string;
var
  LProviderName: string;
begin
  // Cache key = provider identity + '|' + MD5(screenshot base64).
  // Binding the provider identity prevents a stale hit when the provider is
  // hot-swapped (e.g. model change) yet the screenshot bytes happen to match.
  // MD5 is deterministic on the PNG base64 (pf24bit + standard RFC4648 base64,
  // no salt/timestamp), so identical pixels yield an identical key.
  if FProvider <> nil then
    LProviderName := FProvider.GetName
  else
    LProviderName := 'none';
  Result := LProviderName + '|' + THashUtils.MD5(AShot.ImageBase64);
end;

function TDesktopPerceptionEngine.Recognize(const AShot: TDesktopScreenshot;
  out AElements: TPerceivedElementArray): Boolean;
begin
  AElements := nil;
  if not FEnabled then
    Exit(False);
  FLock.Enter;
  try
    if FProvider = nil then
      Exit(False);
    if not FProvider.IsAvailable then
      Exit(False);
    Result := FProvider.Recognize(AShot, AElements);
  finally
    FLock.Leave;
  end;
end;

function TDesktopPerceptionEngine.FindByLabel(const AShot: TDesktopScreenshot;
  const ALabel: string; out AElement: TPerceivedElement): Boolean;
var
  LElements: TPerceivedElementArray;
  LKey: string;
  I: Integer;
begin
  Result := False;
  if ALabel = '' then
    Exit;
  if FCache.Get(ALabel, AElement) then
    Exit(True);
  // Frame-cache reuse: if this exact frame was already Perceived (same
  // provider + same screenshot bytes), scan the cached element list before
  // invoking the provider, saving an LLM call for a repeated-frame query.
  LKey := BuildFrameCacheKey(AShot);
  FLock.Enter;
  try
    if (LKey = FFrameCacheKey) and not FFrameCache.IsEmpty then
    begin
      for I := 0 to High(FFrameCache.Elements) do
      begin
        if SameText(FFrameCache.Elements[I].Label_, ALabel) then
        begin
          AElement := FFrameCache.Elements[I];
          FCache.Put(ALabel, AElement);
          Exit(True);
        end;
      end;
    end;
    if FProvider = nil then
      Exit;
    if not FProvider.IsAvailable then
      Exit;
    if not FProvider.FindByLabel(AShot, ALabel, AElement) then
    begin
      // Fall back to full recognition + linear scan.
      if FProvider.Recognize(AShot, LElements) and (Length(LElements) > 0) then
      begin
        for I := 0 to High(LElements) do
        begin
          if SameText(LElements[I].Label_, ALabel) then
          begin
            AElement := LElements[I];
            Result := True;
            Break;
          end;
        end;
      end;
    end
    else
      Result := True;
    if Result then
      FCache.Put(ALabel, AElement);
  finally
    FLock.Leave;
  end;
end;

function TDesktopPerceptionEngine.Perceive: TPerceptionResult;
begin
  Result := PerceiveWithCache(CaptureScreen);
end;

function TDesktopPerceptionEngine.Perceive(
  const AShot: TDesktopScreenshot): TPerceptionResult;
begin
  Result := PerceiveWithCache(AShot);
end;

function TDesktopPerceptionEngine.PerceiveWithCache(
  const AShot: TDesktopScreenshot): TPerceptionResult;
var
  LElements: TPerceivedElementArray;
  LKey: string;
begin
  Result := Default(TPerceptionResult);
  Result.Screenshot := AShot;
  if not Result.Screenshot.IsValid then
    Exit;
  // Degraded mode (no provider): capture-only, do not populate the frame
  // cache so a later provider attachment cannot serve a stale 'none' result.
  if FProvider = nil then
  begin
    Result.ProviderUsed := 'none';
    Exit;
  end;
  LKey := BuildFrameCacheKey(Result.Screenshot);
  FLock.Enter;
  try
    // L0 cost gate: identical frame (same provider + same screenshot MD5)
    // reuses the last recognition result and skips the vision provider call.
    if (LKey = FFrameCacheKey) and not FFrameCache.IsEmpty then
    begin
      Result.Elements := FFrameCache.Elements;
      Result.ProviderUsed := FFrameCache.ProviderUsed;
      Logger.InfoFmt('frame cache hit md5=%s reuse %d elements',
        [LKey, Length(FFrameCache.Elements)], 'Perception');
      Exit;
    end;
  finally
    FLock.Leave;
  end;
  // Cache miss: invoke the provider, then store the fresh result so the next
  // identical frame hits the cache.
  if Recognize(Result.Screenshot, LElements) then
  begin
    Result.Elements := LElements;
    Result.ProviderUsed := FProvider.GetName;
    FLock.Enter;
    try
      FFrameCache.Elements := LElements;
      FFrameCache.ProviderUsed := Result.ProviderUsed;
      FFrameCacheKey := LKey;
    finally
      FLock.Leave;
    end;
    Logger.InfoFmt('frame cache miss md5=%s invoke %s -> %d elements',
      [LKey, Result.ProviderUsed, Length(LElements)], 'Perception');
  end
  else
    Result.ProviderUsed := 'none';
end;

function TDesktopPerceptionEngine.GetEnabled: Boolean;
begin
  FLock.Enter;
  try
    Result := FEnabled;
  finally
    FLock.Leave;
  end;
end;

procedure TDesktopPerceptionEngine.SetEnabled(AValue: Boolean);
begin
  FLock.Enter;
  try
    FEnabled := AValue;
  finally
    FLock.Leave;
  end;
end;

function TDesktopPerceptionEngine.GetProvider: IDesktopVisionProvider;
begin
  FLock.Enter;
  try
    Result := FProvider;
  finally
    FLock.Leave;
  end;
end;

procedure TDesktopPerceptionEngine.SetProvider(AValue: IDesktopVisionProvider);
begin
  FLock.Enter;
  try
    FProvider := AValue;
    // Invalidate both caches on provider swap: a new provider identity makes
    // the frame cache key mismatch (so frame reuse auto-stops), but also clear
    // FFrameCacheKey explicitly, and clear the label cache so FindByLabel
    // cannot return elements recognized under the previous provider.
    FFrameCache := Default(TFrameCacheEntry);
    FFrameCacheKey := '';
    FCache.Clear;
  finally
    FLock.Leave;
  end;
end;

end.
