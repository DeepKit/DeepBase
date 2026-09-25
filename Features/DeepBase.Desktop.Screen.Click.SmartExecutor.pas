{ ============================================================================
  DeepBase.Desktop.Screen.Click.SmartExecutor
  ---------------------------------------------------------------------------
  版本     : 0.1 (API 不稳定)
  职责     : 把「视觉定位判定」与「真实输入派发」分成两段——先用虚拟探针确认命中，
             确认之后才派发恰好一次真实点击；返回值反映真实判定结果。

  口径归一：像素类型复用 DeepBase.Desktop.Perception.ColorMatch 的 TPixelBuffer，
            匹配走 DeepBase.Desktop.Screen.Click.RegionLocator，DPI 换算走
            IClickDMapper；本单元不引入第二套图像类型或第二个 DPI 真源。
  可测性  ：真实输入只经 IMouseDevice 一个出口，测试注入计数替身，于是
            「判定不通过 ⇒ 返回 false 且零派发」「判定通过 ⇒ 恰好一次派发」可固化。
 ========================================================================== }

unit DeepBase.Desktop.Screen.Click.SmartExecutor;

interface

uses
  System.Types,
  Winapi.Windows,
  DeepBase.Desktop.Perception.ColorMatch,
  DeepBase.Desktop.Screen.Click.RegionLocator,
  DeepBase.Desktop.Screen.Click.DPIMapper;

type
  // OS 输入派发的唯一出口。抽象出来只为把判定与派发解耦：判定阶段一个真实输入
  // 都不许发出去（旧实现一边判定一边按容差网格逐点真点击，一轮 121 次）。
  IMouseDevice = interface
    ['{0BE5D6A3-1735-4661-A99A-3302DF2D6CED}']
    // 返回 SetCursorPos 的真实结果；返回 False 时调用方不得继续派发点击。
    function MoveCursor(X, Y: Integer): Boolean;
    // 在当前光标位置按下并释放左键（调用前必须已 MoveCursor 成功）。
    procedure Click;
  end;

  TWinMouseDevice = class(TInterfacedObject, IMouseDevice)
  public
    function MoveCursor(X, Y: Integer): Boolean;
    procedure Click;
  end;

  TClickAnchorMode = (
    camCenter,    // 命中区中心
    camTopLeft,   // 命中区左上角
    camCustom     // 命中区左上角 + 自定义偏移
  );

  TClickTolerance = record
    TolerancePixels: Integer; // 邻域探测半径；0 = 只探主锚点
    MaxRetries: Integer;      // 判定不通过时重新取帧判定的轮数
    RetryDelayMs: Cardinal;   // 轮间隔
    class function DefaultValue: TClickTolerance; static;
  end;

  TClickOptions = record
    AnchorMode: TClickAnchorMode;
    CustomOffsetX: Integer;
    CustomOffsetY: Integer;
    Tolerance: TClickTolerance;
    class function DefaultValue: TClickOptions; static;
  end;

  ISmartClickExecutor = interface
    ['{6798745E-2753-4D5A-9C8B-8C3CCA7984EE}']

    // 取帧定位 → 虚拟探针确认锚点仍在命中区内 → 一次真实点击。
    // 判定不通过一律 False 且零派发。
    function ClickByTemplate(const ATemplate: TPixelBuffer;
      const AOptions: TClickOptions): Boolean; overload;
    function ClickByTemplate(const ATemplate: TPixelBuffer): Boolean; overload;

    // 绝对坐标点击没有可比对的期望目标，因此不存在「容差邻域」可言：
    // 只移动光标并派发一次，返回值是光标移动的真实结果。
    function ClickAtPoint(X, Y: Integer): Boolean;

    // 相对坐标 (0.0-1.0) 经 DPI 换算成绝对坐标后点击
    function ClickAtRelative(RelativeX, RelativeY: Double): Boolean;

    // 在超时窗口内轮询等待目标出现；返回最后一次定位结果（超时即未命中形状）。
    function WaitForTargetToAppear(const ATemplate: TPixelBuffer;
      ATimeoutMs: Cardinal): TMatchResult;
  end;

  TSmartClickExecutor = class(TInterfacedObject, ISmartClickExecutor)
  private
    FLocator: IScreenRegionLocator;
    FMouse: IMouseDevice;
    FDPI: IClickDMapper;
    function AnchorPoint(const AMatch: TMatchResult;
      const AOptions: TClickOptions): TPoint;
    function DispatchClick(X, Y: Integer): Boolean;
  public
    constructor Create(const ALocator: IScreenRegionLocator;
      const AMouse: IMouseDevice; const ADPI: IClickDMapper); overload;
    // 生产装配：主屏定位器 + 真实鼠标 + 单例 DPI 换算器
    constructor Create; overload;

    function ClickByTemplate(const ATemplate: TPixelBuffer;
      const AOptions: TClickOptions): Boolean; overload;
    function ClickByTemplate(const ATemplate: TPixelBuffer): Boolean; overload;
    function ClickAtPoint(X, Y: Integer): Boolean;
    function ClickAtRelative(RelativeX, RelativeY: Double): Boolean;
    function WaitForTargetToAppear(const ATemplate: TPixelBuffer;
      ATimeoutMs: Cardinal): TMatchResult;
  end;

procedure InitializeSmartClickExecutor;
function CurrentSmartClickExecutor: ISmartClickExecutor;

implementation

var
  GSmartExecutor: ISmartClickExecutor = nil;

const
  // 等待目标出现时的轮询间隔
  CK_WAIT_POLL_MS = 100;

{ TClickTolerance }

class function TClickTolerance.DefaultValue: TClickTolerance;
begin
  Result.TolerancePixels := 5;
  Result.MaxRetries := 3;
  Result.RetryDelayMs := 500;
end;

{ TClickOptions }

class function TClickOptions.DefaultValue: TClickOptions;
begin
  Result.AnchorMode := camCenter;
  Result.CustomOffsetX := 0;
  Result.CustomOffsetY := 0;
  Result.Tolerance := TClickTolerance.DefaultValue;
end;

{ TWinMouseDevice }

function TWinMouseDevice.MoveCursor(X, Y: Integer): Boolean;
begin
  Result := SetCursorPos(X, Y);
end;

procedure TWinMouseDevice.Click;
begin
  mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0);
  mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0);
end;

{ TSmartClickExecutor }

constructor TSmartClickExecutor.Create(const ALocator: IScreenRegionLocator;
  const AMouse: IMouseDevice; const ADPI: IClickDMapper);
begin
  inherited Create;
  FLocator := ALocator;
  FMouse := AMouse;
  FDPI := ADPI;
end;

constructor TSmartClickExecutor.Create;
begin
  Create(CurrentScreenRegionLocator, TWinMouseDevice.Create, CurrentDPIMapper);
end;

function TSmartClickExecutor.AnchorPoint(const AMatch: TMatchResult;
  const AOptions: TClickOptions): TPoint;
begin
  case AOptions.AnchorMode of
    camTopLeft:
      Result := AMatch.Rect.TopLeft;
    camCustom:
      Result := Point(AMatch.Rect.Left + AOptions.CustomOffsetX,
        AMatch.Rect.Top + AOptions.CustomOffsetY);
  else
    Result := Point(
      AMatch.Rect.Left + (AMatch.Rect.Width div 2),
      AMatch.Rect.Top + (AMatch.Rect.Height div 2));
  end;
end;

function TSmartClickExecutor.DispatchClick(X, Y: Integer): Boolean;
begin
  if not FMouse.MoveCursor(X, Y) then
    Exit(False); // 光标没落到目标上，点击会打在别处，宁可不发
  FMouse.Click;
  Result := True;
end;

function TSmartClickExecutor.ClickByTemplate(const ATemplate: TPixelBuffer;
  const AOptions: TClickOptions): Boolean;
var
  LTolerance: TClickTolerance;
  LAttempt, LDeltaX, LDeltaY: Integer;
  LHittest: TMatchResult;
  LAnchor: TPoint;
begin
  LTolerance := AOptions.Tolerance;
  if LTolerance.MaxRetries < 1 then
    LTolerance.MaxRetries := 1;

  for LAttempt := 1 to LTolerance.MaxRetries do
  begin
    // 判定阶段：重新取帧再定位（虚拟探针），全程不发任何真实输入
    FLocator.CaptureScreen;
    LHittest := FLocator.FindTemplate(ATemplate);
    if LHittest.Found then
    begin
      LAnchor := AnchorPoint(LHittest, AOptions);
      // 主锚点优先，再按行扫描容差邻域；候选点必须仍落在本帧命中区内才算确认。
      if LHittest.Rect.Contains(LAnchor) then
        Exit(DispatchClick(LAnchor.X, LAnchor.Y));
      for LDeltaY := -LTolerance.TolerancePixels to LTolerance.TolerancePixels do
        for LDeltaX := -LTolerance.TolerancePixels to LTolerance.TolerancePixels do
          if ((LDeltaX <> 0) or (LDeltaY <> 0)) and
            LHittest.Rect.Contains(Point(LAnchor.X + LDeltaX, LAnchor.Y + LDeltaY)) then
            Exit(DispatchClick(LAnchor.X + LDeltaX, LAnchor.Y + LDeltaY));
      // 本轮没有一个候选被确认：一次真实输入都没发，进入下一轮重新判定。
    end;
    if LAttempt < LTolerance.MaxRetries then
      Sleep(LTolerance.RetryDelayMs);
  end;
  Result := False;
end;

function TSmartClickExecutor.ClickByTemplate(const ATemplate: TPixelBuffer): Boolean;
begin
  Result := ClickByTemplate(ATemplate, TClickOptions.DefaultValue);
end;

function TSmartClickExecutor.ClickAtPoint(X, Y: Integer): Boolean;
begin
  Result := DispatchClick(X, Y);
end;

function TSmartClickExecutor.ClickAtRelative(RelativeX, RelativeY: Double): Boolean;
var
  LAbs: TDPIAwarePoint;
begin
  LAbs := FDPI.MapRelativeToAbsolute(RelativeX, RelativeY);
  Result := ClickAtPoint(LAbs.AbsoluteX, LAbs.AbsoluteY);
end;

function TSmartClickExecutor.WaitForTargetToAppear(const ATemplate: TPixelBuffer;
  ATimeoutMs: Cardinal): TMatchResult;
var
  // RTL 里 GetTickCount64 返回 UInt64（Winapi.Windows.pas:8986），变量必须同型否则 W1073
  LStart: UInt64;
begin
  LStart := GetTickCount64;
  while True do
  begin
    FLocator.CaptureScreen;
    Result := FLocator.FindTemplate(ATemplate);
    if Result.Found then
      Exit;
    if GetTickCount64 - LStart >= UInt64(ATimeoutMs) then
      Exit; // 超时即「未出现」：返回未命中形状交给调用方判定，不抛也不谎报命中
    Sleep(CK_WAIT_POLL_MS);
  end;
end;

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
