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
  TDesktopScreenshot = record
    ImageBase64: string;
    MimeType: string;
    CaptureRect: TRect;
    WidthPx: Integer;
    HeightPx: Integer;
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
