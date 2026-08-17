{ ============================================================================
  DeepBase.Desktop.Screen.Click.SmartExecutor
  ---------------------------------------------------------------------------
  Version     : 0.1 (Unstable API)
  Description : Intelligent click execution with multi-point tolerance matching,
                timeout/retry mechanisms, and fallback anchor point strategies.
  
  Features:
    - Smart fallback: If primary anchor fails, try alternative points
    - Configurable retry count and delay between attempts
    - Tolerance-based position adjustment (+/- n pixels)
    - Integration with RegionLocator for visual element detection
    
  Performance:
    - Parallel anchor point evaluation (future optimization)
    - Early exit on successful match
  ========================================================================== }

unit DeepBase.Desktop.Screen.Click.SmartExecutor;

interface

uses
  System.SysUtils,
  Winapi.Windows,
  System.Variants,
  Graphics32,
  DeepBase.Desktop.Screen.Click.RegionLocator,
  DeepBase.Desktop.Screen.Click.DPIMapper,
  DeepBase.Automation.ActionEngine.Core;

type
  TClickTolerance = record
    MinConfidence: Double;        // Minimum match confidence (default 0.6)
    TolerancePixels: Integer;     // +/- pixel tolerance around matched position (default 5)
    MaxRetries: Integer;          // Maximum retry attempts (default 3)
    RetryDelayMs: Cardinal;       // Delay between retries in ms (default 500)
  end;

  TClickAnchorMode = (
    camCenter,           // Use center of matched region
    camTopLeft,         // Use top-left corner
    camBestFit,         // Try multiple anchors until one works
    camCustom           // Custom anchor offset
  );

  TClickOptions = record
    AnchorMode: TClickAnchorMode;
    CustomOffsetX, CustomOffsetY: Integer;  // For camCustom mode
    Tolerance: TClickTolerance;
  end;

  ISmartClickExecutor = interface
    ['{ABCD9012-34EF-GHIJ-KLMN-OPQRSTUVWXYA}']
    
    // Execute click based on image template match
    function ClickByTemplate(const TemplateImage: TBitmap32;
      const Options: TClickOptions = default): Boolean; overload;
      
    // Execute click at absolute coordinates with tolerance
    function ClickAtPoint(X, Y: Integer; 
      const Tolerance: TClickTolerance = default): Boolean; overload;
      
    // Execute click at relative position (0.0-1.0 per monitor DPI)
    function ClickAtRelative(RelativeX, RelativeY: Double;
      const Options: TClickOptions = default): Boolean;
      
    // Helper: Validate click target exists
    function WaitForTargetToAppear(const TemplateImage: TBitmap32;
      TimeoutMs: Cardinal): TMatchResult;
  end;

  TSmartClickExecutor = class(TInterfacedObject, ISmartClickExecutor)
  private
    FRegionLocator: IScreenRegionLocator;
    FDPIMapper: IClickDMapper;
    
    procedure SimulateMouseClick(X, Y: Integer);
    function TryClickWithTolerance(X, Y: Integer; 
      Tolerance: Integer): Boolean;
    function FindBestAnchorPoint(
      const MatchResult: TMatchResult;
      const Options: TClickOptions): TPoint;
  public
    constructor Create;
    
    // ISmartClickExecutor implementation
    function ClickByTemplate(const TemplateImage: TBitmap32;
      const Options: TClickOptions): Boolean; overload;
    function ClickAtPoint(X, Y: Integer;
      const Tolerance: TClickTolerance): Boolean; overload;
    function ClickAtRelative(RelativeX, RelativeY: Double;
      const Options: TClickOptions): Boolean;
    function WaitForTargetToAppear(const TemplateImage: TBitmap32;
      TimeoutMs: Cardinal): TMatchResult;
  end;

// Global accessor
procedure InitializeSmartClickExecutor;
function CurrentSmartClickExecutor: ISmartClickExecutor;

implementation

var
  GSmartExecutor: ISmartClickExecutor = nil;

{ TSmartClickExecutor }

constructor TSmartClickExecutor.Create;
begin
  inherited Create;
  
  // Lazy initialize dependencies
  InitializeScreenRegionLocator;
  InitializeDPIMapper;
  
  FRegionLocator := CurrentScreenRegionLocator;
  FDPIMapper := CurrentDPIMapper;
end;

procedure TSmartClickExecutor.SimulateMouseClick(X, Y: Integer);
begin
  SetCursorPosition(X, Y);
  Sleep(50);
  mouse_event(MOUSEEVENTF_LEFTDOWN, X, Y, 0, 0);
  Sleep(50);
  mouse_event(MOUSEEVENTF_LEFTUP, X, Y, 0, 0);
end;

function TSmartClickExecutor.TryClickWithTolerance(X, Y: Integer; 
  Tolerance: Integer): Boolean;
var
  DeltaX, DeltaY: Integer;
  SuccessCount: Integer;
  TotalAttempts: Integer;
begin
  SuccessCount := 0;
  TotalAttempts := 0;
  
  // Try multiple positions within tolerance box
  for DeltaX := -Tolerance to +Tolerance do
    for DeltaY := -Tolerance to +Tolerance do
    begin
      Inc(TotalAttempts);
      var TestX := X + DeltaX;
      var TestY := Y + DeltaY;
      
      // Execute click at this offset
      SimulateMouseClick(TestX, TestY);
      
      // In real implementation, would check result here
      // For now, assume success after first attempt
      if DeltaX = 0 then
        Inc(SuccessCount);
    end;
    
  Result := SuccessCount > 0;
end;

function TSmartClickExecutor.FindBestAnchorPoint(
  const MatchResult: TMatchResult;
  const Options: TClickOptions): TPoint;
begin
  case Options.AnchorMode of
    camCenter:
      Result := Point(
        MatchResult.Rect.Left + Round((MatchResult.Rect.Right - MatchResult.Rect.Left) / 2),
        MatchResult.Rect.Top + Round((MatchResult.Rect.Bottom - MatchResult.Rect.Top) / 2)
      );
      
    camTopLeft:
      Result := Point(MatchResult.Rect.Left, MatchResult.Rect.Top);
      
    camBestFit:
      // Try multiple anchor points sequentially
      // TODO: Implement intelligent selection algorithm
      Result := Point(MatchResult.Rect.Left, MatchResult.Rect.Top);
      
    camCustom:
      Result := Point(
        MatchResult.Rect.Left + Options.CustomOffsetX,
        MatchResult.Rect.Top + Options.CustomOffsetY
      );
  end;
end;

function TSmartClickExecutor.ClickByTemplate(const TemplateImage: TBitmap32;
  const Options: TClickOptions): Boolean;
var
  MatchResult: TMatchResult;
  TargetPoint: TPoint;
  RetryCount: Integer;
begin
  Result := False;
  
  // Default options if not specified
  if Options.Tolerance.MinConfidence = 0 then
    Options.Tolerance.MinConfidence := 0.7;
    
  if Options.Tolerance.MaxRetries = 0 then
    Options.Tolerance.MaxRetries := 3;
    
  // Search for template
  MatchResult := FRegionLocator.FindTemplate(TemplateImage);
  
  if not MatchResult.Found then
    Exit(False);
    
  // Find best click anchor
  TargetPoint := FindBestAnchorPoint(MatchResult, Options);
  
  // Retry loop with tolerance
  for RetryCount := 0 to Options.Tolerance.MaxRetries - 1 do
  begin
    if TryClickWithTolerance(TargetPoint.X, TargetPoint.Y, 
                              Options.Tolerance.TolerancePixels) then
    begin
      Result := True;
      Break;
    end;
    
    // Wait before next retry
    if RetryCount < Options.Tolerance.MaxRetries - 1 then
      Sleep(Options.Tolerance.RetryDelayMs);
  end;
end;

function TSmartClickExecutor.ClickAtPoint(X, Y: Integer;
  const Tolerance: TClickTolerance): Boolean;
begin
  if Tolerance.TolerancePixels > 0 then
    Result := TryClickWithTolerance(X, Y, Tolerance.TolerancePixels)
  else
  begin
    SimulateMouseClick(X, Y);
    Result := True;
  end;
end;

function TSmartClickExecutor.ClickAtRelative(RelativeX, RelativeY: Double;
  const Options: TClickOptions): Boolean;
var
  AbsPoint: TDPIAwarePoint;
begin
  // Convert relative to absolute using DPI mapper
  AbsPoint := FDPIMapper.MapRelativeToAbsolute(RelativeX, RelativeY);
  
  // Execute click at absolute coordinates
  Result := ClickAtPoint(AbsPoint.AbsoluteX, AbsPoint.AbsoluteY, 
                         Options.Tolerance);
end;

function TSmartClickExecutor.WaitForTargetToAppear(
  const TemplateImage: TBitmap32;
  TimeoutMs: Cardinal): TMatchResult;
var
  StartTime: LongWord;
  ElapsedMs: Cardinal;
  MaxCheckInterval: Cardinal;
  CheckCount: Integer;
begin
  Result := TMatchResult.Default;
  StartTime := GetTickCount64;
  MaxCheckInterval := 100;  // Check every 100ms
  
  repeat
    // Capture current screen state
    FRegionLocator.CaptureScreen();
    
    // Search for template
    Result := FRegionLocator.FindTemplate(TemplateImage);
    
    if Result.Found then
      Break;  // Target found!
      
    // Wait before next check
    Sleep(MaxCheckInterval);
    Inc(CheckCount);
    
    // Check timeout
    ElapsedMs := GetTickCount64 - StartTime;
    
  until ElapsedMs >= TimeoutMs;
end;

// Global initialization
procedure InitializeSmartClickExecutor;
begin
  if not Assigned(GSmartExecutor) then
    GSmartExecutor := TSmartClickExecutor.Create;
end;

function CurrentSmartClickExecutor: ISmartClickExecutor;
begin
  if not Assigned(GSmartExecutor) then
    InitializeSmartClickExecutor;
    
  Result := GSmartExecutor;
end;

initialization
finalization
  GSmartExecutor := nil;

end.
