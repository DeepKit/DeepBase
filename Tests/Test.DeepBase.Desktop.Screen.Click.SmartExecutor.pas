{ ============================================================================
  Test.DeepBase.Desktop.Screen.Click.SmartExecutor
  ---------------------------------------------------------------------------
  Description : 「判定阶段零真实输入 + 确认后恰好一次派发」的判据固化。
                执行器的三个依赖（定位器/鼠标/DPI 换算）全部注入替身，
                因此用例可以在无桌面、无屏幕内容的前提下断言派发次数与坐标；
                唯一触真屏幕的 TWinMouseDevice 不在本单元测试范围内
                （它只有两行 OS 调用，且被 IMouseDevice 挡在执行器之外）。
  ========================================================================== }

unit Test.DeepBase.Desktop.Screen.Click.SmartExecutor;

interface

uses
  System.Types,
  Winapi.Windows,
  Vcl.Graphics,
  DUnitX.TestFramework,
  DeepBase.Desktop.Perception.ColorMatch,
  DeepBase.Desktop.Screen.Click.RegionLocator,
  DeepBase.Desktop.Screen.Click.DPIMapper,
  DeepBase.Desktop.Screen.Click.SmartExecutor;

type
  // 输入派发计数控件：MoveCursor/Click 各计一次，记录最后一次落点
  TFakeMouse = class(TInterfacedObject, IMouseDevice)
  public
    MoveCount: Integer;
    ClickCount: Integer;
    LastX: Integer;
    LastY: Integer;
    MoveResult: Boolean;
    constructor Create;
    function MoveCursor(X, Y: Integer): Boolean;
    procedure Click;
  end;

  // 定位计数控件：前 HitFromCall-1 次 FindTemplate 报未命中，之后报 HitRect
  TFakeLocator = class(TInterfacedObject, IScreenRegionLocator)
  private
    FOptions: TRegionLocatorOptions;
    function Hit: TMatchResult;
  public
    CaptureCount: Integer;
    FindCount: Integer;
    HitFromCall: Integer;
    HitRect: TRect;
    constructor Create;
    function FindTemplate(const ATemplate: TPixelBuffer): TMatchResult;
    function FindTemplateInROI(const ATemplate: TPixelBuffer;
      const AROI: TRect): TMatchResult;
    function FindAllTemplates(const ATemplate: TPixelBuffer;
      AMaxCount: Integer): TArray<TMatchResult>;
    procedure SetOptions(const AOptions: TRegionLocatorOptions);
    function GetOptions: TRegionLocatorOptions;
    procedure CaptureScreen;
  end;

  TFakeDpiMapper = class(TInterfacedObject, IClickDMapper)
  public
    MapCallCount: Integer;
    LastRelativeX: Double;
    LastRelativeY: Double;
    AbsX: Integer;
    AbsY: Integer;
    constructor Create;
    function MapRelativeToAbsolute(RelativeX, RelativeY: Double): TDPIAwarePoint;
    function MapPercentage(PercentX, PercentY: Integer): TDPIAwarePoint;
    function GetCurrentDPI: Integer;
    function GetMonitorDPI(AMonitor: HMONITOR): Integer;
    function IsDPIAware: Boolean;
    function GetEffectiveScreenWidth: Integer;
    function GetEffectiveScreenHeight: Integer;
  end;

  [TestFixture]
  TTestSmartClickExecutor = class
  private
    // 类引用用于读计数器，接口引用负责把对象保活到断言之后
    FMouse: TFakeMouse;
    FMouseRef: IMouseDevice;
    FLocator: TFakeLocator;
    FLocatorRef: IScreenRegionLocator;
    FDpiMapper: TFakeDpiMapper;
    FDpiRef: IClickDMapper;
    FExecutor: ISmartClickExecutor;
    // MaxRetries 逐例不同，重试轮间隔一律置 0 以免用例真等
    function OptionsForMode(AAnchor: TClickAnchorMode; AOffsetX, AOffsetY,
      ATolerancePixels, AMaxRetries: Integer): TClickOptions;
    // 替身定位器不读像素，模板只要类型正确；显式清零避免 W1036 未初始化
    class function NoTemplate: TPixelBuffer; static;
  public
    [Setup]
    procedure Setup;
    [Teardown]
    procedure Teardown;

    [Test]
    procedure TestUnconfirmedTargetNeverClicksAndReturnsFalse;
    [Test]
    procedure TestConfirmedTargetClicksExactlyOnce;
    [Test]
    procedure TestRetryConfirmsOnSecondRound;
    [Test]
    procedure TestNonPositiveRetriesStillProbesOnce;
    [Test]
    procedure TestAnchorTopLeftCoords;
    [Test]
    procedure TestAnchorCustomOffsetInsideHitRect;
    [Test]
    procedure TestAnchorBeyondToleranceRejected;
    [Test]
    procedure TestToleranceGridRecoversNearMissAnchor;
    [Test]
    procedure TestCursorMoveFailureSuppressesClick;
    [Test]
    procedure TestClickAtPointDispatchesExactlyOnce;
    [Test]
    procedure TestClickAtPointMoveFailureReturnsFalse;
    [Test]
    procedure TestClickAtRelativeUsesDpiMapper;
    [Test]
    procedure TestWaitForTargetToAppearSuccess;
    [Test]
    procedure TestWaitForTargetToAppearTimeoutReportsNotFound;
    [Test]
    procedure TestDefaultOptionsShape;
  end;

implementation

const
  // 命中区 20x10，屏幕坐标 (100,100)-(120,110)，中心 (110,105)
  HIT_LEFT = 100;
  HIT_TOP = 100;

{ TFakeMouse }

constructor TFakeMouse.Create;
begin
  inherited Create;
  MoveResult := True;
end;

function TFakeMouse.MoveCursor(X, Y: Integer): Boolean;
begin
  Inc(MoveCount);
  LastX := X;
  LastY := Y;
  Result := MoveResult;
end;

procedure TFakeMouse.Click;
begin
  Inc(ClickCount);
end;

{ TFakeLocator }

constructor TFakeLocator.Create;
begin
  inherited Create;
  HitRect := System.Types.Rect(HIT_LEFT, HIT_TOP, HIT_LEFT + 20, HIT_TOP + 10);
  FOptions.MinConfidence := 0.7;
  FOptions.Tolerance := 30;
  FOptions.UseROI := False;
  FOptions.ROIBounds := System.Types.Rect(0, 0, 0, 0);
end;

function TFakeLocator.Hit: TMatchResult;
begin
  Inc(FindCount);
  if (HitFromCall > 0) and (FindCount >= HitFromCall) then
  begin
    Result.Found := True;
    Result.Rect := HitRect;
    Result.Position := HitRect.TopLeft;
    Result.Confidence := 1.0;
  end
  else
    Result := TMatchResult.NotFound;
end;

function TFakeLocator.FindTemplate(const ATemplate: TPixelBuffer): TMatchResult;
begin
  Result := Hit;
end;

function TFakeLocator.FindTemplateInROI(const ATemplate: TPixelBuffer;
  const AROI: TRect): TMatchResult;
var
  LHit: TMatchResult;
begin
  LHit := Hit;
  // ROI 只在替身语义里做几何裁剪，够测试用
  if LHit.Found and not AROI.Contains(LHit.Position) then
    Result := TMatchResult.NotFound
  else
    Result := LHit;
end;

function TFakeLocator.FindAllTemplates(const ATemplate: TPixelBuffer;
  AMaxCount: Integer): TArray<TMatchResult>;
begin
  if AMaxCount < 1 then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  SetLength(Result, 1);
  Result[0] := Hit;
end;

procedure TFakeLocator.SetOptions(const AOptions: TRegionLocatorOptions);
begin
  FOptions := AOptions;
end;

function TFakeLocator.GetOptions: TRegionLocatorOptions;
begin
  Result := FOptions;
end;

procedure TFakeLocator.CaptureScreen;
begin
  Inc(CaptureCount);
end;

{ TFakeDpiMapper }

constructor TFakeDpiMapper.Create;
begin
  inherited Create;
  AbsX := 400;
  AbsY := 540;
end;

function TFakeDpiMapper.MapRelativeToAbsolute(RelativeX,
  RelativeY: Double): TDPIAwarePoint;
begin
  Inc(MapCallCount);
  LastRelativeX := RelativeX;
  LastRelativeY := RelativeY;
  Result := TDPIAwarePoint.Create(AbsX, AbsY, RelativeX, RelativeY);
end;

function TFakeDpiMapper.MapPercentage(PercentX, PercentY: Integer): TDPIAwarePoint;
begin
  Result := TDPIAwarePoint.Create(PercentX * 19, PercentY * 10, 0.0, 0.0);
end;

function TFakeDpiMapper.GetCurrentDPI: Integer;
begin
  Result := 96;
end;

function TFakeDpiMapper.GetMonitorDPI(AMonitor: HMONITOR): Integer;
begin
  Result := 96;
end;

function TFakeDpiMapper.IsDPIAware: Boolean;
begin
  Result := False;
end;

function TFakeDpiMapper.GetEffectiveScreenWidth: Integer;
begin
  Result := 1920;
end;

function TFakeDpiMapper.GetEffectiveScreenHeight: Integer;
begin
  Result := 1080;
end;

{ TTestSmartClickExecutor }

procedure TTestSmartClickExecutor.Setup;
begin
  FMouse := TFakeMouse.Create;
  FMouseRef := FMouse;
  FLocator := TFakeLocator.Create;
  FLocatorRef := FLocator;
  FDpiMapper := TFakeDpiMapper.Create;
  FDpiRef := FDpiMapper;
  FExecutor := TSmartClickExecutor.Create(FLocatorRef, FMouseRef, FDpiRef);
end;

procedure TTestSmartClickExecutor.Teardown;
begin
  FExecutor := nil;
  FMouseRef := nil;
  FLocatorRef := nil;
  FDpiRef := nil;
  FMouse := nil;
  FLocator := nil;
  FDpiMapper := nil;
end;

function TTestSmartClickExecutor.OptionsForMode(AAnchor: TClickAnchorMode;
  AOffsetX, AOffsetY, ATolerancePixels, AMaxRetries: Integer): TClickOptions;
begin
  Result := TClickOptions.DefaultValue;
  Result.AnchorMode := AAnchor;
  Result.CustomOffsetX := AOffsetX;
  Result.CustomOffsetY := AOffsetY;
  Result.Tolerance.TolerancePixels := ATolerancePixels;
  Result.Tolerance.MaxRetries := AMaxRetries;
  Result.Tolerance.RetryDelayMs := 0;
end;

class function TTestSmartClickExecutor.NoTemplate: TPixelBuffer;
begin
  Result.Bitmap := nil;
  Result.OriginX := 0;
  Result.OriginY := 0;
end;

procedure TTestSmartClickExecutor.TestUnconfirmedTargetNeverClicksAndReturnsFalse;
begin
  FLocator.HitFromCall := 0; // 全程定位不到
  Assert.IsFalse(FExecutor.ClickByTemplate(NoTemplate,
    OptionsForMode(camCenter, 0, 0, 5, 3)), '判定不通过必须返回 False');
  Assert.AreEqual(0, FMouse.MoveCount, '判定阶段不得移动光标');
  Assert.AreEqual(0, FMouse.ClickCount, '判定阶段不得派发点击');
  Assert.AreEqual(3, FLocator.CaptureCount, '三轮重试各取帧一次');
end;

procedure TTestSmartClickExecutor.TestConfirmedTargetClicksExactlyOnce;
begin
  FLocator.HitFromCall := 1;
  Assert.IsTrue(FExecutor.ClickByTemplate(NoTemplate,
    OptionsForMode(camCenter, 0, 0, 5, 3)));
  Assert.AreEqual(1, FMouse.ClickCount, '确认后恰好一次真实点击');
  Assert.AreEqual(1, FMouse.MoveCount);
  Assert.AreEqual(HIT_LEFT + 10, FMouse.LastX, 'camCenter 落在命中区中心');
  Assert.AreEqual(HIT_TOP + 5, FMouse.LastY);
end;

procedure TTestSmartClickExecutor.TestRetryConfirmsOnSecondRound;
begin
  FLocator.HitFromCall := 2; // 第一轮未命中：那一轮必须零派发
  Assert.IsTrue(FExecutor.ClickByTemplate(NoTemplate,
    OptionsForMode(camCenter, 0, 0, 5, 3)));
  Assert.AreEqual(1, FMouse.ClickCount);
  Assert.AreEqual(2, FLocator.CaptureCount, '第二轮才确认');
end;

procedure TTestSmartClickExecutor.TestNonPositiveRetriesStillProbesOnce;
begin
  FLocator.HitFromCall := 0;
  Assert.IsFalse(FExecutor.ClickByTemplate(NoTemplate,
    OptionsForMode(camCenter, 0, 0, 5, 0)));
  Assert.AreEqual(1, FLocator.CaptureCount, 'MaxRetries<=0 兜底为一轮，不许零轮');
  Assert.AreEqual(0, FMouse.ClickCount);
end;

procedure TTestSmartClickExecutor.TestAnchorTopLeftCoords;
begin
  FLocator.HitFromCall := 1;
  Assert.IsTrue(FExecutor.ClickByTemplate(NoTemplate,
    OptionsForMode(camTopLeft, 0, 0, 0, 1)));
  Assert.AreEqual(HIT_LEFT, FMouse.LastX);
  Assert.AreEqual(HIT_TOP, FMouse.LastY);
end;

procedure TTestSmartClickExecutor.TestAnchorCustomOffsetInsideHitRect;
begin
  FLocator.HitFromCall := 1;
  Assert.IsTrue(FExecutor.ClickByTemplate(NoTemplate,
    OptionsForMode(camCustom, 3, 2, 0, 1)));
  Assert.AreEqual(HIT_LEFT + 3, FMouse.LastX, '自定义偏移在命中区内即被确认');
  Assert.AreEqual(HIT_TOP + 2, FMouse.LastY);
end;

procedure TTestSmartClickExecutor.TestAnchorBeyondToleranceRejected;
begin
  FLocator.HitFromCall := 1;
  // 锚点偏到命中区外 100px，容差 5 的邻域也够不着：探针全不确认
  Assert.IsFalse(FExecutor.ClickByTemplate(NoTemplate,
    OptionsForMode(camCustom, 100, 100, 5, 1)), '探针不确认必须返回 False');
  Assert.AreEqual(0, FMouse.ClickCount, '候选全不确认时一次点击都不许发');
end;

procedure TTestSmartClickExecutor.TestToleranceGridRecoversNearMissAnchor;
begin
  FLocator.HitFromCall := 1;
  // 锚点在右边界外 1px（Right 是开区间），容差 5 的邻域应把它拉回命中区
  Assert.IsTrue(FExecutor.ClickByTemplate(NoTemplate,
    OptionsForMode(camCustom, 20, 0, 5, 1)));
  Assert.AreEqual(1, FMouse.ClickCount);
  Assert.IsTrue(FLocator.HitRect.Contains(Point(FMouse.LastX, FMouse.LastY)),
    '实际派发点必须落在被探针确认的命中区内');
end;

procedure TTestSmartClickExecutor.TestCursorMoveFailureSuppressesClick;
begin
  FLocator.HitFromCall := 1;
  FMouse.MoveResult := False;
  Assert.IsFalse(FExecutor.ClickByTemplate(NoTemplate,
    OptionsForMode(camCenter, 0, 0, 0, 1)), '光标没落位就不能点击，返回 false');
  Assert.AreEqual(0, FMouse.ClickCount);
end;

procedure TTestSmartClickExecutor.TestClickAtPointDispatchesExactlyOnce;
begin
  Assert.IsTrue(FExecutor.ClickAtPoint(7, 9));
  Assert.AreEqual(1, FMouse.MoveCount);
  Assert.AreEqual(1, FMouse.ClickCount);
  Assert.AreEqual(7, FMouse.LastX);
  Assert.AreEqual(9, FMouse.LastY);
end;

procedure TTestSmartClickExecutor.TestClickAtPointMoveFailureReturnsFalse;
begin
  FMouse.MoveResult := False;
  Assert.IsFalse(FExecutor.ClickAtPoint(7, 9));
  Assert.AreEqual(0, FMouse.ClickCount, '移动失败仍派发点击就是打偏');
end;

procedure TTestSmartClickExecutor.TestClickAtRelativeUsesDpiMapper;
begin
  FDpiMapper.AbsX := 320;
  FDpiMapper.AbsY := 240;
  Assert.IsTrue(FExecutor.ClickAtRelative(0.25, 0.5));
  Assert.AreEqual(1, FDpiMapper.MapCallCount);
  Assert.AreEqual(0.25, FDpiMapper.LastRelativeX);
  Assert.AreEqual(0.5, FDpiMapper.LastRelativeY);
  Assert.AreEqual(320, FMouse.LastX, '相对坐标必须经 DPI 换算后再派发');
  Assert.AreEqual(240, FMouse.LastY);
end;

procedure TTestSmartClickExecutor.TestWaitForTargetToAppearSuccess;
var
  LResult: TMatchResult;
begin
  FLocator.HitFromCall := 1;
  LResult := FExecutor.WaitForTargetToAppear(NoTemplate, 1000);
  Assert.IsTrue(LResult.Found);
  Assert.AreEqual(HIT_LEFT, LResult.Rect.Left);
  Assert.AreEqual(0, FMouse.ClickCount, '等待阶段只读屏，不发输入');
end;

procedure TTestSmartClickExecutor.TestWaitForTargetToAppearTimeoutReportsNotFound;
var
  LResult: TMatchResult;
begin
  FLocator.HitFromCall := 0;
  LResult := FExecutor.WaitForTargetToAppear(NoTemplate, 0);
  Assert.IsFalse(LResult.Found, '超时返回未命中形状，不谎报命中');
  Assert.AreEqual(0.0, LResult.Confidence, '未命中时置信度恒为 0');
  Assert.AreEqual(0, FMouse.ClickCount);
end;

procedure TTestSmartClickExecutor.TestDefaultOptionsShape;
var
  LOptions: TClickOptions;
begin
  LOptions := TClickOptions.DefaultValue;
  Assert.AreEqual<TClickAnchorMode>(camCenter, LOptions.AnchorMode);
  Assert.AreEqual(5, LOptions.Tolerance.TolerancePixels);
  Assert.AreEqual(3, LOptions.Tolerance.MaxRetries);
  Assert.AreEqual(500, Integer(LOptions.Tolerance.RetryDelayMs));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestSmartClickExecutor);

end.
