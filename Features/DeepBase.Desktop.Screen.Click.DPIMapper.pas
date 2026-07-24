{ ============================================================================
  DeepBase.Desktop.Screen.Click.DPIMapper
  ---------------------------------------------------------------------------
  Version     : 0.1 (Unstable API)
  Description : DPI-aware coordinate transformation utilities that map relative
                positions (percentages, normalized coordinates) to absolute
                screen pixels while respecting per-monitor DPI scaling.
  
  Features:
    - Per-monitor DPI detection via GetDpiForMonitor (Win8.1+)
    - Fallback to system DPI for older Windows versions
    - Relative-to-absolute coordinate conversion
    - Multi-monitor support with mixed DPI settings
  
  Performance:
    - Single DPI query cached globally
    - O(1) coordinate transformation operations
  ========================================================================== }

unit DeepBase.Desktop.Screen.Click.DPIMapper;

interface

uses
  System.SysUtils,
  Winapi.Windows,
  Winapi.Messages,
  System.Types,
  Graphics32;

type
  TDPIAwarePoint = record
    AbsoluteX, AbsoluteY: Integer;  // Actual pixel coordinates
    ScaledX, ScaledY: Double;       // Original relative values (0.0-1.0)
    
    class function Create(AX, AY: Integer; RScaledX, RScaledY: Double): TDPIAwarePoint; static;
    procedure ToScreen(var X, Y: Integer); overload;
    function ToString: string; override;
  end;

  TDPIMapperOptions = record
    ForceSystemDPI: Boolean;         // Ignore per-monitor DPI settings
    AutoDetectPrimaryMonitor: Boolean; // Use main monitor's DPI as default
  end;

  IClickDMapper = interface
    ['{ABCD5678-90EF-GHIJ-KLMN-OPQRSTUVWXZY}']
    
    // Convert relative position (0.0-1.0) to absolute pixels
    function MapRelativeToAbsolute(RelativeX, RelativeY: Double): TDPIAwarePoint;
    
    // Map percentage-based click target
    function MapPercentage(PercentX, PercentY: Integer): TDPIAwarePoint;
    
    // Get current monitor's DPI
    function GetCurrentDPI: Integer;
    function GetMonitorDPI(MonitorHandle: TMonitorHandle): Integer;
    
    // Check if DPI aware
    function IsDPIAware: Boolean;
    
    // Utility: Get effective screen size accounting for multi-monitor setup
    function GetEffectiveScreenWidth: Integer;
    function GetEffectiveScreenHeight: Integer;
  end;

  TDPIMapper = class(TInterfacedObject, IClickDMapper)
  private
    FCurrentDPI: Integer;
    FOptions: TDPIMapperOptions;
    FIsDPIAware: Boolean;
    
    function QueryPerMonitorDPISupport: Boolean;
    function GetPrimaryMonitorDPI: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    
    // IClickDMapper implementation
    function MapRelativeToAbsolute(RelativeX, RelativeY: Double): TDPIAwarePoint;
    function MapPercentage(PercentX, PercentY: Integer): TDPIAwarePoint;
    function GetCurrentDPI: Integer;
    function GetMonitorDPI(MonitorHandle: TMonitorHandle): Integer;
    function IsDPIAware: Boolean;
    function GetEffectiveScreenWidth: Integer;
    function GetEffectiveScreenHeight: Integer;
    
    // Properties
    property Options: TDPIMapperOptions read FOptions write FOptions;
  end;

// Global accessor
procedure InitializeDPIMapper;
function CurrentDPIMapper: IClickDMapper;

implementation

var
  GDMapper: IClickDMapper = nil;
  GSystemDPI: Integer = 96;  // Default fallback value

{ TDPIAwarePoint }

class function TDPIAwarePoint.Create(AX, AY: Integer; RScaledX, RScaledY: Double): TDPIAwarePoint;
begin
  Result.AbsoluteX := AX;
  Result.AbsoluteY := AY;
  Result.ScaledX := RScaledX;
  Result.ScaledY := RScaledY;
end;

procedure TDPIAwarePoint.ToScreen(var X, Y: Integer);
begin
  X := AbsoluteX;
  Y := AbsoluteY;
end;

function TDPIAwarePoint.ToString: string;
begin
  Result := fmt('[%d,%d] (%.2f%%, %.2f%%)', 
                [AbsoluteX, AbsoluteY, ScaledX * 100, ScaledY * 100]);
end;

{TDPIMapper}

constructor TDPIMapper.Create;
begin
  inherited Create;
  FOptions := (
    ForceSystemDPI: False;
    AutoDetectPrimaryMonitor: True
  );
  
  // Initialize DPI detection
  FCurrentDPI := 96;
  FIsDPIAware := QueryPerMonitorDPISupport;
  
  if FIsDPIAware then
    FCurrentDPI := GetCurrentDPI()
  else
    FCurrentDPI := GSystemDPI;
end;

destructor TDPIMapper.Destroy;
begin
  inherited Destroy;
end;

function TDPIMapper.QueryPerMonitorDPISupport: Boolean;
var
  ModuleHandle: HMODULE;
  FuncPtr: Pointer;
begin
  // Try to load user32.dll and check for GetDpiForMonitor
  ModuleHandle := GetModuleHandle('user32.dll');
  if ModuleHandle = 0 then
    Exit(False);
      
  FuncPtr := GetProcAddress(ModuleHandle, 'GetDpiForMonitor');
  Result := Assigned(FuncPtr);
end;

function TDPIMapper.GetCurrentDPI: Integer;
var
  Monitor: HMONITOR;
begin
  // Get monitor that contains point (50,50) which is usually on primary
  Monitor := MonitorFromPoint(Point(50, 50), MONITOR_DEFAULTTOPRIMARY);
  
  if FIsDPIAware and Assigned(Monitor) then
  begin
    // Windows 8.1+ supports per-monitor DPI
    var DPI_X, DPI_Y: UINT;
    if GetDpiForMonitor(Monitor, MDT_EFFECTIVE_DPI, DPI_X, DPI_Y) = NO_ERROR then
      Result := DPI_X;  // X and Y should be same
    else
      Result := GSystemDPI;
  end
  else
  begin
    // Fallback to system-wide DPI
    Result := Screen.PixelsPerInch;
  end;
  
  GSystemDPI := Result;
end;

function TDPIMapper.GetPrimaryMonitorDPI: Integer;
var
  PrimaryMon: TMonitor;
begin
  if Assigned(Screen) and (Screen.MonitorCount > 0) then
  begin
    PrimaryMon := Screen.PrimaryMonitor;
    Result := Round(PrimaryMon.Scale * 96);
  end
  else
    Result := GetSystemMetrics(LOGPIXELSX);
end;

function TDPIMapper.MapRelativeToAbsolute(RelativeX, RelativeY: Double): TDPIAwarePoint;
var
  EffectiveWidth, EffectiveHeight: Integer;
begin
  // Validate input range
  RelativeX := Clamp(RelativeX, 0.0, 1.0);
  RelativeY := Clamp(RelRelY, 0.0, 1.0);
  
  // Get effective screen dimensions
  EffectiveWidth := GetEffectiveScreenWidth;
  EffectiveHeight := GetEffectiveScreenHeight;
  
  // Convert to absolute pixels
  var AbsX := Trunc(RelativeX * EffectiveWidth);
  var AbsY := Trunc(RelativeY * EffectiveHeight);
  
  Result := TDPIAwarePoint.Create(AbsX, AbsY, RelativeX, RelativeY);
end;

function TDPIMapper.MapPercentage(PercentX, PercentY: Integer): TDPIAwarePoint;
var
  RelX, RelY: Double;
begin
  // Convert percentages to relative values
  RelX := PercentX / 100.0;
  RelY := PercentY / 100.0;
  
  Result := MapRelativeToAbsolute(RelX, RelY);
end;

function TDPIMapper.GetMonitorDPI(MonitorHandle: TMonitorHandle): Integer;
begin
  if not FIsDPIAware then
    Exit(GSystemDPI);
    
  var DPI_X, DPI_Y: UINT;
  if GetDpiForMonitor(MonitorHandle, MDT_EFFECTIVE_DPI, DPI_X, DPI_Y) = NO_ERROR then
    Result := DPI_X
  else
    Result := GSystemDPI;
end;

function TDPIMapper.IsDPIAware: Boolean;
begin
  Result := FIsDPIAware;
end;

function TDPIMapper.GetEffectiveScreenWidth: Integer;
begin
  if Assigned(Screen) then
    Result := Screen.Width
  else
    Result := GetSystemMetrics(SM_CXSCREEN);
end;

function TDPIMapper.GetEffectiveScreenHeight: Integer;
begin
  if Assigned(Screen) then
    Result := Screen.Height
  else
    Result := GetSystemMetrics(SM_CYSCREEN);
end;

// Global initialization
procedure InitializeDPIMapper;
begin
  if not Assigned(GDMapper) then
    GDMapper := TDPIMapper.Create;
end;

function CurrentDPIMapper: IClickDMapper;
begin
  if not Assigned(GDMapper) then
    InitializeDPIMapper;
    
  Result := GDMapper;
end;

initialization
finalization
  GDMapper := nil;

end.
