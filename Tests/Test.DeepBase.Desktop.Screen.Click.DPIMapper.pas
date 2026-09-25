{ ============================================================================
  Test.DeepBase.Desktop.Screen.Click.DPIMapper
  ---------------------------------------------------------------------------
  Description : TDD unit tests for DPI-aware coordinate mapping.

  口径：DPI 一律以 VCL 报告的监视器 DPI 为期望值（与 DeepBase.Desktop.Screen.Click.DPIMapper
  同一真相源），不在测试里另算一套缩放公式。IsDPIAware 是 RTL 的同行委托，无可断言行为，
  故不设用例（不设「A or not A」这类恒真断言充数）。
  ========================================================================== }

unit Test.DeepBase.Desktop.Screen.Click.DPIMapper;

interface

uses
  System.SysUtils,
  System.Types,
  Winapi.Windows,
  Vcl.Forms,
  DUnitX.TestFramework,
  DeepBase.Desktop.Screen.Click.DPIMapper;

type
  [TestFixture]
  TTestDPIMapper = class(TObject)
  private
    FMapper: IClickDMapper;
  public
    [Setup]
    procedure Setup;
    [Test]
    procedure TestCurrentDPIIsPositiveAndPlausible;
    [Test]
    procedure TestCurrentDPIFollowsVCLMonitorPPI;
    [Test]
    procedure TestMonitorDPIForKnownHandleMatchesCurrentDPI;
    [Test]
    procedure TestMonitorDPIForUnknownHandleFallsBackNotZero;
    [Test]
    procedure TestMapCenterPointToScreenMiddle;
    [Test]
    procedure TestMapPercentageMatchesRelativeMapping;
    [Test]
    procedure TestNegativeRelativeClampedToOrigin;
    [Test]
    procedure TestOverRangeRelativeClampedToScreenExtent;
    [Test]
    procedure TestPointToStringRendersBothCoordinateSets;
  end;

implementation

{ TTestDPIMapper }

procedure TTestDPIMapper.Setup;
begin
  FMapper := TDPIMapper.Create;
end;

procedure TTestDPIMapper.TestCurrentDPIIsPositiveAndPlausible;
var
  DPI: Integer;
begin
  DPI := FMapper.GetCurrentDPI;
  Assert.IsTrue(DPI > 0, 'DPI 不得为 0（原实现用 GetSystemMetrics(LOGPIXELSX) 恒得 0）');
  Assert.IsTrue(DPI <= 600, 'DPI 应在合理区间');
end;

procedure TTestDPIMapper.TestCurrentDPIFollowsVCLMonitorPPI;
var
  Mon: TMonitor;
begin
  Mon := Screen.MonitorFromPoint(Point(50, 50));
  Assert.IsTrue(Mon <> nil, '测试机应存在覆盖 (50,50) 的监视器');
  if Mon = nil then Exit;
  Assert.AreEqual(Mon.PixelsPerInch, FMapper.GetCurrentDPI,
    'GetCurrentDPI 必须等于 VCL 报告的对应监视器 DPI，不得自造换算');
end;

procedure TTestDPIMapper.TestMonitorDPIForKnownHandleMatchesCurrentDPI;
var
  Mon: TMonitor;
begin
  Mon := Screen.MonitorFromPoint(Point(50, 50));
  if Mon = nil then Exit;
  Assert.AreEqual(FMapper.GetCurrentDPI, FMapper.GetMonitorDPI(Mon.Handle),
    '同一点位取到的监视器句柄应与 GetCurrentDPI 一致');
end;

procedure TTestDPIMapper.TestMonitorDPIForUnknownHandleFallsBackNotZero;
begin
  Assert.AreEqual(FMapper.GetCurrentDPI, FMapper.GetMonitorDPI(0),
    '未知句柄应退回当前 DPI 而不是返回 0');
end;

procedure TTestDPIMapper.TestMapCenterPointToScreenMiddle;
var
  P: TDPIAwarePoint;
begin
  P := FMapper.MapRelativeToAbsolute(0.5, 0.5);
  Assert.AreEqual(FMapper.GetEffectiveScreenWidth div 2, P.AbsoluteX, '中心点 X');
  Assert.AreEqual(FMapper.GetEffectiveScreenHeight div 2, P.AbsoluteY, '中心点 Y');
  Assert.AreEqual(0.5, P.ScaledX, 1e-9, '相对值原样保留 X');
  Assert.AreEqual(0.5, P.ScaledY, 1e-9, '相对值原样保留 Y');
end;

procedure TTestDPIMapper.TestMapPercentageMatchesRelativeMapping;
var
  ByPercent, ByRelative: TDPIAwarePoint;
begin
  ByPercent := FMapper.MapPercentage(25, 75);
  ByRelative := FMapper.MapRelativeToAbsolute(0.25, 0.75);
  Assert.AreEqual(ByRelative.AbsoluteX, ByPercent.AbsoluteX, '百分比与相对值入口等价 X');
  Assert.AreEqual(ByRelative.AbsoluteY, ByPercent.AbsoluteY, '百分比与相对值入口等价 Y');
end;

procedure TTestDPIMapper.TestNegativeRelativeClampedToOrigin;
var
  P: TDPIAwarePoint;
begin
  P := FMapper.MapRelativeToAbsolute(-0.5, -0.5);
  Assert.AreEqual(0, P.AbsoluteX, '负 X 夹到 0');
  Assert.AreEqual(0, P.AbsoluteY, '负 Y 夹到 0');
  Assert.AreEqual(0.0, P.ScaledX, 1e-9, '夹取结果回写在 Scaled 字段');
end;

procedure TTestDPIMapper.TestOverRangeRelativeClampedToScreenExtent;
var
  P: TDPIAwarePoint;
begin
  P := FMapper.MapRelativeToAbsolute(1.5, 2.0);
  Assert.AreEqual(FMapper.GetEffectiveScreenWidth, P.AbsoluteX, 'X 越界夹到屏宽');
  Assert.AreEqual(FMapper.GetEffectiveScreenHeight, P.AbsoluteY, 'Y 越界夹到屏高');
  Assert.AreEqual(1.0, P.ScaledX, 1e-9, '夹取上限为 1.0');
end;

procedure TTestDPIMapper.TestPointToStringRendersBothCoordinateSets;
begin
  // 原实现调用了不存在的 fmt()，这里把输出格式钉成契约，防止格式再次漂走
  Assert.AreEqual('[10,20] (50.00%, 75.00%)',
    TDPIAwarePoint.Create(10, 20, 0.5, 0.75).ToString);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDPIMapper);

end.
