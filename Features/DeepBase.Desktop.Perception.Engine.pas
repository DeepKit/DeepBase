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
  // Pixel-diff short-circuit gate (L0 pre-gate, runs before PNG encode).
  // Compares the current captured bitmap against the previous frame's
  // TFrameSignature and reports whether the screen changed; below the threshold
  // the frame is treated as static so CaptureScreen can reuse the previous
  // encoding and skip both PNG encode and (downstream) the vision provider.
  // The threshold is configurable and MUST be re-calibrated on real DeepAxis
  // samples per docs/94 §6 (calibration protocol) — the shipped 0.4% default is
  // a PLACEHOLDER pending that measurement, transcribed from external RPA notes
  // only as a starting point; never ship an un-calibrated threshold as final.
  // Thread-safe: signature state is guarded.
  TFrameDiffer = class
  private
    FLast: TFrameSignature;
    FThreshold: Double;
    FLock: TCriticalSection;
    class function ChangeRatio(const A, B: TFrameSignature;
      out ARatio: Double): Boolean; static;
  public
    constructor Create; overload;
    constructor Create(const AThreshold: Double); overload;
    destructor Destroy; override;
    // Compute the frame signature for a bitmap (sampled cell averages).
    // Public so the calibration harness and tests can compare the signature of
    // an injected disk-PNG bitmap against a live BitBlt bitmap byte-for-byte,
    // proving the two sources are signature-equivalent after the internal
    // pf32bit normalization (i.e. replay calibration is not measuring a
    // format phantom). Pure: no FLast mutation.
    function SampleSignature(const ABitmap: TBitmap): TFrameSignature;
    // True when the frame is judged CHANGED (proceed to encode/recognize).
    // False when static: reuse the previous frame's encoding. First frame and
    // dimension-mismatch both return True (uncomparable => treat as changed).
    function IsChanged(const ABitmap: TBitmap): Boolean;
    function GetThreshold: Double;
    procedure SetThreshold(const AValue: Double);
    procedure Reset;
  end;

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
    // L0 pixel-diff gate (runs before PNG encode in CaptureScreen). When nil,
    // frame-diff short-circuit is disabled (every capture encodes + encodes).
    FFrameDiffer: TFrameDiffer;
    // Last fully-captured shot (post-encode). When the differ judges a frame
    // static, CaptureScreen returns a copy of this with Unchanged=True instead
    // of re-encoding. Kept so a static screen pays zero capture/encode cost.
    FLastShot: TDesktopScreenshot;
    // Injected bitmap source for CaptureToBitmap. When nil (the default for
    // all production callers), CaptureToBitmap performs the real BitBlt. When
    // assigned, CaptureToBitmap returns FBitmapSource(ARect) instead. Strictly
    // additive: the injection is a no-op until set. Exists so a calibration
    // harness can replay disk-recorded bitmaps through the full FrameDiffer
    // path (which only runs inside CaptureToBitmap), and so unit tests can
    // inject deterministic bitmaps instead of mocking BitBlt.
    FBitmapSource: TFunc<TRect, TBitmap>;
    function BuildFrameCacheKey(const AShot: TDesktopScreenshot): string;
    // Core recognize-with-frame-cache path shared by both Perceive overloads.
    function PerceiveWithCache(
      const AShot: TDesktopScreenshot): TPerceptionResult;
    function GetDpiScale: Double;
    // Passthroughs to FFrameDiffer (nil-guarded so a differ-less engine is a
    // strict no-op). Exposed for the calibration harness to sweep the
    // threshold and reset between sweep iterations without touching the
    // differ instance directly.
    function GetFrameDiffThreshold: Double;
    procedure SetFrameDiffThreshold(const AValue: Double);
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

    // Injected bitmap source. nil = real BitBlt (production default). When
    // assigned, CaptureToBitmap returns the injected bitmap for the given
    // rect instead of BitBlt-ing. Strictly additive. See FBitmapSource.
    property BitmapSource: TFunc<TRect, TBitmap>
      read FBitmapSource write FBitmapSource;
    // FrameDiffer threshold passthrough (nil-guarded). Lets a calibration
    // harness sweep the threshold and a runtime supervisor tune it without a
    // rebuild. No-op read returns 0.0 when the differ is nil.
    property FrameDiffThreshold: Double
      read GetFrameDiffThreshold write SetFrameDiffThreshold;
    // Clear the differ's previous-frame state so the next CaptureScreen is
    // treated as a first frame (always judged changed). Use between
    // independent capture sequences. Nil-guarded no-op.
    procedure ResetFrameDiffer;
  end;

implementation

{$POINTERMATH ON}

const
  // Sampling stride for the frame signature: every S-th row and S-th column is
  // averaged into one cell, so a static screen needs only (W/S)*(H/S) cell
  // reads. S=4 -> 1/16 pixel access, < 1ms for a 1080p frame on the capture
  // path, and the per-cell average smooths sub-pixel/anti-aliasing jitter.
  CFrameDiffStride = 4;

{ TFrameDiffer }

constructor TFrameDiffer.Create;
begin
  Create(0.004);
end;

constructor TFrameDiffer.Create(const AThreshold: Double);
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FThreshold := AThreshold;
  if FThreshold < 0 then
    FThreshold := 0;
  if FThreshold > 1 then
    FThreshold := 1;
end;

destructor TFrameDiffer.Destroy;
begin
  FLock.Free;
  inherited;
end;

procedure TFrameDiffer.Reset;
begin
  FLock.Enter;
  try
    FLast := Default(TFrameSignature);
  finally
    FLock.Leave;
  end;
end;

function TFrameDiffer.GetThreshold: Double;
begin
  FLock.Enter;
  try
    Result := FThreshold;
  finally
    FLock.Leave;
  end;
end;

procedure TFrameDiffer.SetThreshold(const AValue: Double);
var
  LValue: Double;
begin
  LValue := AValue;
  if LValue < 0 then
    LValue := 0;
  if LValue > 1 then
    LValue := 1;
  FLock.Enter;
  try
    FThreshold := LValue;
  finally
    FLock.Leave;
  end;
end;

// Build a stride-sampled average-color signature from a bitmap. Returns an
// empty signature on nil/zero-size input. Uses a pf32bit working copy so scan
// line layout is fixed regardless of the source pixel format (BitBlt commonly
// yields pfDevice, which is not safe to ScanLine directly). Each cell holds the
// mean RGB of the stride x stride block it covers; the per-cell mean doubles as
// anti-aliasing/sub-pixel-jitter smoothing.
function TFrameDiffer.SampleSignature(const ABitmap: TBitmap): TFrameSignature;
var
  LWork: TBitmap;
  LW, LH, LCellsX, LCellsY, LCX, LCY, LPX, LPY, LPXAbs, LPYAbs, LIdx: Integer;
  LRow: PRGBQuad;
  LSumR, LSumG, LSumB, LCount: Int64;
begin
  Result := Default(TFrameSignature);
  if ABitmap = nil then
    Exit;
  LW := ABitmap.Width;
  LH := ABitmap.Height;
  if (LW <= 0) or (LH <= 0) then
    Exit;

  LWork := TBitmap.Create;
  try
    LWork.PixelFormat := pf32bit;
    LWork.SetSize(LW, LH);
    // CR-606 fix: Canvas.Draw on an alpha=0 pf32 source goes through
    // AlphaBlend and leaves the target pixels UNINITIALIZED, so two
    // identical frames produce different signatures at random.
    // Replace with deterministic scanline copy + opaque alpha.
    if ABitmap.PixelFormat = pf32bit then
    begin
      for var LY := 0 to LH - 1 do
      begin
        var PSrc: PRGBQuad := ABitmap.ScanLine[LY];
        var PDst: PRGBQuad := LWork.ScanLine[LY];
        for var LX := 0 to LW - 1 do
        begin
          PDst[LX].rgbRed := PSrc[LX].rgbRed;
          PDst[LX].rgbGreen := PSrc[LX].rgbGreen;
          PDst[LX].rgbBlue := PSrc[LX].rgbBlue;
          PDst[LX].rgbReserved := 255;
        end;
      end;
    end
    else
      LWork.Canvas.Draw(0, 0, ABitmap);

    LCellsX := (LW + CFrameDiffStride - 1) div CFrameDiffStride;
    LCellsY := (LH + CFrameDiffStride - 1) div CFrameDiffStride;
    Result.WidthCells := LCellsX;
    Result.HeightCells := LCellsY;
    Result.Stride := CFrameDiffStride;
    SetLength(Result.Cells, LCellsX * LCellsY * 3);

    for LCY := 0 to LCellsY - 1 do
    begin
      for LCX := 0 to LCellsX - 1 do
      begin
        LSumR := 0; LSumG := 0; LSumB := 0; LCount := 0;
        for LPY := 0 to CFrameDiffStride - 1 do
        begin
          LPYAbs := LCY * CFrameDiffStride + LPY;  // row in source
          if LPYAbs >= LH then
            Break;
          LRow := LWork.ScanLine[LPYAbs];
          for LPX := 0 to CFrameDiffStride - 1 do
          begin
            LPXAbs := LCX * CFrameDiffStride + LPX;
            if LPXAbs >= LW then
              Break;
            Inc(LSumR, LRow[LPXAbs].rgbRed);
            Inc(LSumG, LRow[LPXAbs].rgbGreen);
            Inc(LSumB, LRow[LPXAbs].rgbBlue);
            Inc(LCount);
          end;
        end;
        if LCount > 0 then
        begin
          LIdx := (LCY * LCellsX + LCX) * 3;
          Result.Cells[LIdx] := LSumR div LCount;
          Result.Cells[LIdx + 1] := LSumG div LCount;
          Result.Cells[LIdx + 2] := LSumB div LCount;
        end;
      end;
    end;
  finally
    LWork.Free;
  end;
end;

// Compute the normalized mean absolute difference between two signatures.
// Returns False (uncomparable) when the grids differ in size/stride, so the
// caller treats a dimension change as a guaranteed change. ARatio is the sum
// of per-channel absolute differences over (cellCount * 3 * 255), i.e. the
// fraction of the color space the frames differ by on average.
class function TFrameDiffer.ChangeRatio(const A, B: TFrameSignature;
  out ARatio: Double): Boolean;
var
  I, LLen: Integer;
  LSum: Int64;
  LDenom: Int64;
begin
  ARatio := 1.0;
  if A.IsEmpty or B.IsEmpty then
    Exit(False);
  if (A.WidthCells <> B.WidthCells) or (A.HeightCells <> B.HeightCells)
    or (A.Stride <> B.Stride) then
    Exit(False);
  LLen := Length(A.Cells);
  if (LLen = 0) or (LLen <> Length(B.Cells)) then
    Exit(False);
  LSum := 0;
  for I := 0 to LLen - 1 do
    Inc(LSum, Abs(Int64(A.Cells[I]) - Int64(B.Cells[I])));
  LDenom := Int64(LLen) * 255;
  if LDenom <= 0 then
    Exit(False);
  ARatio := LSum / LDenom;
  Result := True;
end;

function TFrameDiffer.IsChanged(const ABitmap: TBitmap): Boolean;
var
  LCur: TFrameSignature;
  LRatio: Double;
begin
  Result := True;
  if ABitmap = nil then
    Exit;
  LCur := SampleSignature(ABitmap);
  if LCur.IsEmpty then
    Exit;
  FLock.Enter;
  try
    if FLast.IsEmpty then
    begin
      // First frame: seed the signature, treat as changed so we capture once.
      FLast := LCur;
      Exit;
    end;
    if not ChangeRatio(FLast, LCur, LRatio) then
    begin
      // Uncomparable (dimension/format change): refresh signature, treat as
      // changed so the new size gets a fresh capture.
      FLast := LCur;
      Exit;
    end;
    if LRatio <= FThreshold then
    begin
      // Static frame: keep FLast as-is (LCur is statistically identical) and
      // signal no change so CaptureScreen reuses the previous encoding.
      Exit(False);
    end;
    FLast := LCur;
  finally
    FLock.Leave;
  end;
end;

constructor TDesktopPerceptionEngine.Create(
  const AProvider: IDesktopVisionProvider);
begin
  inherited Create;
  FProvider := AProvider;
  FLock := TCriticalSection.Create;
  FCache := TPerceptionCache.Create;
  FEnabled := True;
  // L0 pixel-diff gate enabled by default with a placeholder threshold of
  // 0.4% (re-calibrate on real samples per docs/94 §6). Disable by setting
  // FrameDiffEnabled := False if the host wants every capture to encode.
  FFrameDiffer := TFrameDiffer.Create(0.004);
  if AProvider = nil then
    Logger.Info('Desktop perception: no vision provider, degraded to '
      + 'screenshot-only', 'Perception')
  else
    Logger.Info('Desktop perception: provider ' + AProvider.GetName
      + ' attached', 'Perception');
end;

destructor TDesktopPerceptionEngine.Destroy;
begin
  FFrameDiffer.Free;
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

function TDesktopPerceptionEngine.GetFrameDiffThreshold: Double;
begin
  FLock.Enter;
  try
    if FFrameDiffer = nil then
      Exit(0.0);
    Result := FFrameDiffer.GetThreshold;
  finally
    FLock.Leave;
  end;
end;

procedure TDesktopPerceptionEngine.SetFrameDiffThreshold(const AValue: Double);
begin
  FLock.Enter;
  try
    if FFrameDiffer <> nil then
      FFrameDiffer.SetThreshold(AValue);
  finally
    FLock.Leave;
  end;
end;

procedure TDesktopPerceptionEngine.ResetFrameDiffer;
begin
  FLock.Enter;
  try
    if FFrameDiffer <> nil then
      FFrameDiffer.Reset;
    // Reset the last-shot too: a ResetFrameDiffer means the caller wants the
    // next CaptureScreen treated as a first frame, so FLastShot must not be
    // reused as the static fallback.
    FLastShot := Default(TDesktopScreenshot);
  finally
    FLock.Leave;
  end;
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

  // Injected bitmap source: when assigned, return the injected bitmap for
  // this rect instead of BitBlt-ing. Strictly additive: nil (production
  // default) falls through to the real capture path. The injected bitmap
  // must outlive the call (caller owns lifetime); CaptureToBitmap does not
  // take ownership so existing FLastShot/FreeAndNil patterns at call sites are
  // unaffected.
  if Assigned(FBitmapSource) then
  begin
    Result := FBitmapSource(LRect);
    Exit;
  end;

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
  LChanged: Boolean;
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
    // L0 pixel-diff gate: judge change BEFORE the expensive PNG encode. On a
    // static screen this short-circuits both the Base64 encode and (via the
    // frame cache key matching) the vision provider call downstream.
    LChanged := True;
    if (FFrameDiffer <> nil) and FLastShot.IsValid then
    begin
      LChanged := FFrameDiffer.IsChanged(LBitmap);
      if not LChanged then
      begin
        // Static frame: reuse the previous encoding verbatim. WidthPx/HeightPx
        // and CaptureRect come from FLastShot so the actuation layer still
        // targets the same physical region. Mark Unchanged so callers/tests
        // can distinguish a reused shot from a fresh capture.
        Result := FLastShot;
        Result.Unchanged := True;
        Exit;
      end;
    end;

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
    // Remember the freshly captured shot so the next capture can diff against
    // it and, on a static frame, reuse this encoding.
    FLastShot := Result;
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
