{ ============================================================================
  DeepBase.Desktop.Screen.Click.DPIMapper
  ---------------------------------------------------------------------------
  Description : DPI-aware mapping of relative positions (0.0-1.0 / percentage)
                to absolute screen pixels.

  DPI 真相源：逐监视器 DPI 一律取 VCL 的 TMonitor.PixelsPerInch，与
  VCL/DeepBase.VCL.HB.Tray.pas、VCL/DeepBase.VCL.HB.Grid.pas 同一口径。
  不用 GetDpiForMonitor：本机 Delphi 37.0 未随附 Winapi.Shcore（实测见
  CodeReview/20260925-AUDIT-乙-B2-证据/B2-段0-DPI接口可用性探针.txt），
  且 VCL 已消化 per-monitor awareness，再包一层就是第二套 DPI 真相源。
  ========================================================================== }

unit DeepBase.Desktop.Screen.Click.DPIMapper;

interface

uses
  System.SysUtils,
  System.Types,
  System.Math,
  Winapi.Windows,
  System.Win.HighDpi,
  Vcl.Forms;

type
  TDPIAwarePoint = record
    AbsoluteX, AbsoluteY: Integer;  // 实际像素坐标
    ScaledX, ScaledY: Double;       // 换算前的相对值 (0.0-1.0)

    class function Create(AX, AY: Integer; RScaledX, RScaledY: Double): TDPIAwarePoint; static;
    procedure ToScreen(var X, Y: Integer);
    function ToString: string;
  end;

  IClickDMapper = interface
    ['{8E726F2B-1AB9-4F2D-8EB6-A9E16DF383BE}']

    // 相对坐标越界时夹到 [0,1]，返回夹后的相对值，便于调用方核对输入是否被改写
    function MapRelativeToAbsolute(RelativeX, RelativeY: Double): TDPIAwarePoint;
    function MapPercentage(PercentX, PercentY: Integer): TDPIAwarePoint;

    /// 当前（左上角所在）监视器 DPI；该点不在任何监视器内时退回 Screen.PixelsPerInch
    function GetCurrentDPI: Integer;
    /// 指定监视器的 DPI；句柄不在当前监视器列表内时退回 GetCurrentDPI，不返回 0
    function GetMonitorDPI(AMonitor: HMONITOR): Integer;

    /// 进程是否处于 per-monitor DPI aware 状态（直接问 RTL，不做 GetModuleHandle 猜测）
    function IsDPIAware: Boolean;

    function GetEffectiveScreenWidth: Integer;
    function GetEffectiveScreenHeight: Integer;
  end;

  TDPIMapper = class(TInterfacedObject, IClickDMapper)
  public
    function MapRelativeToAbsolute(RelativeX, RelativeY: Double): TDPIAwarePoint;
    function MapPercentage(PercentX, PercentY: Integer): TDPIAwarePoint;
    function GetCurrentDPI: Integer;
    function GetMonitorDPI(AMonitor: HMONITOR): Integer;
    function IsDPIAware: Boolean;
    function GetEffectiveScreenWidth: Integer;
    function GetEffectiveScreenHeight: Integer;
  end;

procedure InitializeDPIMapper;
function CurrentDPIMapper: IClickDMapper;

implementation

var
  GDMapper: IClickDMapper = nil;

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
  Result := Format('[%d,%d] (%.2f%%, %.2f%%)',
    [AbsoluteX, AbsoluteY, ScaledX * 100, ScaledY * 100]);
end;

{ TDPIMapper }

function TDPIMapper.GetCurrentDPI: Integer;
var
  Mon: TMonitor;
begin
  // 取左上角所在监视器：与 VCL 自身（HB.Tray 菜单定位）同一定位口径
  Mon := Screen.MonitorFromPoint(Point(50, 50));
  if Mon <> nil then
    Result := Mon.PixelsPerInch
  else
    Result := Screen.PixelsPerInch;
end;

function TDPIMapper.GetMonitorDPI(AMonitor: HMONITOR): Integer;
var
  I: Integer;
begin
  for I := 0 to Screen.MonitorCount - 1 do
    if Screen.Monitors[I].Handle = AMonitor then
      Exit(Screen.Monitors[I].PixelsPerInch);
  Result := GetCurrentDPI;
end;

function TDPIMapper.IsDPIAware: Boolean;
begin
  // 必须写单元限定名：方法名与 RTL 函数同名（Delphi 标识符不区分大小写），
  // 裸调用会解析成本方法自身形成无限递归。
  Result := System.Win.HighDpi.IsDpiAware;
end;

function TDPIMapper.MapRelativeToAbsolute(RelativeX, RelativeY: Double): TDPIAwarePoint;
var
  RelX, RelY: Double;
begin
  // 本机 System.Math 无 Clamp（实测 E2003），夹取用其 Max/Min Double 重载
  RelX := Max(0.0, Min(1.0, RelativeX));
  RelY := Max(0.0, Min(1.0, RelativeY));
  Result := TDPIAwarePoint.Create(
    Trunc(RelX * GetEffectiveScreenWidth),
    Trunc(RelY * GetEffectiveScreenHeight),
    RelX, RelY);
end;

function TDPIMapper.MapPercentage(PercentX, PercentY: Integer): TDPIAwarePoint;
begin
  Result := MapRelativeToAbsolute(PercentX / 100.0, PercentY / 100.0);
end;

function TDPIMapper.GetEffectiveScreenWidth: Integer;
begin
  Result := Screen.Width;
end;

function TDPIMapper.GetEffectiveScreenHeight: Integer;
begin
  Result := Screen.Height;
end;

procedure InitializeDPIMapper;
begin
  if GDMapper = nil then
    GDMapper := TDPIMapper.Create;
end;

function CurrentDPIMapper: IClickDMapper;
begin
  InitializeDPIMapper;
  Result := GDMapper;
end;

initialization
finalization
  GDMapper := nil;

end.
