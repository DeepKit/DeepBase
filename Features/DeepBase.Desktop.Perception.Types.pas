{ ============================================================================
  DeepBase.Desktop.Perception.Types
  ---------------------------------------------------------------------------
  Version     : 0.1 (Unstable API)
  Description : Neutral type definitions for desktop perception (screenshot +
                visual element recognition). This unit is the base of the
                perception layer that DeepBase exposes to any desktop agent.
                It contains NO business semantics (no app names, no domain
                words). It only describes what is captured and recognized.
  ========================================================================== }

unit DeepBase.Desktop.Perception.Types;

interface

uses
  System.SysUtils,
  System.Types,
  System.SyncObjs,
  System.Generics.Collections,
  Winapi.Windows;

type
  // Source of a recognized element. Neutral: describes the recognition
  // channel, never the business domain.
  TPerceptionSource = (psOCR, psVision, psUIAProbe, psUnknown);

  // A single element perceived on the desktop. Bounds are physical screen
  // coordinates so the actuation layer can click/input at them directly.
  // Label is the recognized text (e.g. "Send"); it carries no business
  // meaning at this layer.
  TPerceivedElement = record
    Label_: string;
    BoundingBox: TRect;
    Confidence: Double;
    Source: TPerceptionSource;
    function IsValid: Boolean;
    function Center: TPoint;
  end;

  TPerceivedElementArray = TArray<TPerceivedElement>;

  // A captured screenshot. ImageBase64 + MimeType are directly consumable by
  // LLM().ChatVision. CaptureRect is the physical screen region captured.
  // Unchanged=True marks a frame that the frame-differ gate judged pixel-stable
  // against the previous capture: in that case ImageBase64 is the *reused*
  // previous-frame encoding (still valid, no PNG re-encode happened) so the
  // frame cache and any downstream consumer see a stable, cacheable shot while
  // paying zero capture/encode cost for the static region.
  TDesktopScreenshot = record
    ImageBase64: string;
    MimeType: string;
    CaptureRect: TRect;
    WidthPx: Integer;
    HeightPx: Integer;
    Unchanged: Boolean;
    function IsValid: Boolean;
  end;

  // Neutral vision provider contract. A provider turns a screenshot into a
  // list of perceived elements. Implementations may be LLM-backed
  // (DeepBase.Desktop.Perception.LLMProvider) or local OCR. The interface is
  // deliberately independent of the browser vision provider
  // (DeepBase.Browser.Vision.IVisionProvider) so the two domains do not
  // couple, but follow the same shape.
  IDesktopVisionProvider = interface
    ['{B7C1D8E4-9F2A-4C6D-8E1B-3A7F5D2C9E04}']
    function Recognize(const AShot: TDesktopScreenshot;
      out AElements: TPerceivedElementArray): Boolean;
    function FindByLabel(const AShot: TDesktopScreenshot;
      const ALabel: string; out AElement: TPerceivedElement): Boolean;
    function IsAvailable: Boolean;
    function GetName: string;
  end;

  // Locator for a window to capture. Neutral: identifies a window by handle
  // or by neutral criteria (title pattern, process name). No business words.
  TWindowLocator = record
    WindowHandle: HWND;
    TitleContains: string;
    ProcessName: string;
    function IsEmpty: Boolean;
  end;

  // Perception result returned to the actuation/application layer.
  TPerceptionResult = record
    Screenshot: TDesktopScreenshot;
    Elements: TPerceivedElementArray;
    ProviderUsed: string;
    function ElementCount: Integer;
  end;

  // Single-slot frame cache entry: holds the fully-recognized element list of
  // the last perceived frame so a subsequent identical frame (same provider +
  // same screenshot bytes) can skip the vision provider call entirely. This is
  // the L0 cost gate for heartbeat polling scenarios where the same window is
  // polled repeatedly and most frames are pixel-identical. The cache key is
  // composed of provider identity + screenshot MD5, so it never returns stale
  // results across a provider swap. TPerceivedElementArray is a dynamic array
  // (value type): assigning it copies, so the record owns its snapshot with no
  // extra heap bookkeeping.
  TFrameCacheEntry = record
    Elements: TPerceivedElementArray;
    ProviderUsed: string;
    function IsEmpty: Boolean;
  end;

  // Sampled RGB signature of one frame, used by the frame-differ gate to decide
  // whether the screen changed between captures. Instead of keeping the full
  // bitmap (expensive, and CaptureScreen frees its TBitmap right after encoding),
  // the differ stores only a coarse average-color grid sampled with a stride.
  // For a 1920x1080 frame at stride 4 that is 480x270 cells = ~388 KB of bytes;
  // the per-cell average doubles as anti-aliasing/sub-pixel-jitter smoothing
  // because each cell summarizes a stride x stride block. This is the L0
  // pre-gate: it runs *before* PNG encoding in CaptureScreen, so a static screen
  // short-circuits not just the vision provider but the Base64 encode itself.
  // Kept here (neutral types unit, no VCL dependency) so the engine can store it
  // without dragging TBitmap into the type contract.
  TFrameSignature = record
    WidthCells: Integer;
    HeightCells: Integer;
    Stride: Integer;
    // Flat array of RGB averages, layout R,G,B per cell, row-major:
    // cell (cx,cy) -> index ((cy*WidthCells)+cx)*3.
    Cells: TBytes;
    function IsEmpty: Boolean;
  end;

  // Cache for recognized elements, keyed by neutral description string.
  // Mirrors the browser vision cache shape but lives in the desktop domain.
  TPerceptionCache = class
  private
    FCache: TDictionary<string, TPerceivedElement>;
    FLock: TCriticalSection;
  public
    constructor Create;
    destructor Destroy; override;
    function Get(const ALabel: string;
      out AElement: TPerceivedElement): Boolean;
    procedure Put(const ALabel: string;
      const AElement: TPerceivedElement);
    procedure Clear;
  end;

implementation

{ TPerceivedElement }

function TPerceivedElement.IsValid: Boolean;
begin
  Result := (BoundingBox.Width > 0) and (BoundingBox.Height > 0)
    and (Confidence >= 0) and (Confidence <= 1);
end;

function TPerceivedElement.Center: TPoint;
begin
  Result.X := BoundingBox.Left + (BoundingBox.Right - BoundingBox.Left) div 2;
  Result.Y := BoundingBox.Top + (BoundingBox.Bottom - BoundingBox.Top) div 2;
end;

{ TDesktopScreenshot }

function TDesktopScreenshot.IsValid: Boolean;
begin
  Result := (ImageBase64 <> '') and (MimeType <> '')
    and (WidthPx > 0) and (HeightPx > 0);
end;

{ TWindowLocator }

function TWindowLocator.IsEmpty: Boolean;
begin
  Result := (WindowHandle = 0) and (TitleContains = '')
    and (ProcessName = '');
end;

{ TPerceptionResult }

function TPerceptionResult.ElementCount: Integer;
begin
  Result := Length(Elements);
end;

{ TFrameCacheEntry }

function TFrameCacheEntry.IsEmpty: Boolean;
begin
  Result := (Length(Elements) = 0) and (ProviderUsed = '');
end;

{ TFrameSignature }

function TFrameSignature.IsEmpty: Boolean;
begin
  Result := (WidthCells <= 0) or (HeightCells <= 0) or (Length(Cells) = 0);
end;

{ TPerceptionCache }

constructor TPerceptionCache.Create;
begin
  inherited;
  FCache := TDictionary<string, TPerceivedElement>.Create;
  FLock := TCriticalSection.Create;
end;

destructor TPerceptionCache.Destroy;
begin
  FLock.Free;
  FCache.Free;
  inherited;
end;

function TPerceptionCache.Get(const ALabel: string;
  out AElement: TPerceivedElement): Boolean;
begin
  FLock.Enter;
  try
    Result := FCache.TryGetValue(ALabel, AElement);
  finally
    FLock.Leave;
  end;
end;

procedure TPerceptionCache.Put(const ALabel: string;
  const AElement: TPerceivedElement);
begin
  FLock.Enter;
  try
    FCache.AddOrSetValue(ALabel, AElement);
  finally
    FLock.Leave;
  end;
end;

procedure TPerceptionCache.Clear;
begin
  FLock.Enter;
  try
    FCache.Clear;
  finally
    FLock.Leave;
  end;
end;

end.
