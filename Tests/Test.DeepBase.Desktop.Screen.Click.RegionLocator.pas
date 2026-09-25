{ ============================================================================
  Test.DeepBase.Desktop.Screen.Click.RegionLocator
  ---------------------------------------------------------------------------
  Description : TTemplateMatcher 的块匹配判据（占比/容差/提前剪枝/ROI/屏幕坐标/
                命中互不相交）全部用合成像素缓冲离线验证，不依赖真实屏幕；
                TScreenRegionLocator 只补状态面（选项回读）与真实抓屏路径的
                契约形状断言。
  ========================================================================== }

unit Test.DeepBase.Desktop.Screen.Click.RegionLocator;

{$POINTERMATH ON}

interface

uses
  System.Types,
  System.Classes,
  DUnitX.TestFramework,
  Vcl.Graphics,
  DeepBase.Desktop.Perception.ColorMatch,
  DeepBase.Desktop.Screen.Click.RegionLocator;

type
  [TestFixture]
  TTestScreenRegionLocator = class
  private
    FLocator: IScreenRegionLocator;
    // 24x16 @ origin(100,50) 的白底快照，内含两块 4x3 红块：
    //   局部(5,4)-(9,7) -> 屏幕(105,54)；局部(18,10)-(22,13) -> 屏幕(118,60)
    function BuildSnapshot: TPixelBuffer;
    function MakeTemplate(AWidth, AHeight: Integer; AColor: TColor32): TPixelBuffer;
    class procedure Fill(const ABuf: TPixelBuffer; AColor: TColor32); static;
    class procedure Paint(const ABuf: TPixelBuffer; const ALocalRect: TRect;
      AColor: TColor32); static;
    // Length() 在 Win64 是 NativeInt，与 Integer 字面量同喂一个 AreEqual 会撞
    // E2532 类型推断；命中数断言统一走这里，顺便保住 AreEqual 的失败信息。
    class procedure AssertHitCount(AExpected: Integer;
      const AHits: TArray<TMatchResult>; const AMessage: string = ''); static;
  public
    [Setup]
    procedure Setup;
    [Teardown]
    procedure Teardown;

    [Test]
    procedure TestScoreAtExactPatchIsOne;
    [Test]
    procedure TestScoreAtMisalignedPatchIsHitFraction;
    [Test]
    procedure TestScoreAtPrunesBeyondMismatchBudget;
    [Test]
    procedure TestFindMatchesReturnsScreenCoordinates;
    [Test]
    procedure TestFindMatchesAcceptsPartialPatchAtThreshold;
    [Test]
    procedure TestFindMatchesRejectsBelowMinConfidence;
    [Test]
    procedure TestFindMatchesToleranceBoundaryIsInclusive;
    [Test]
    procedure TestFindMatchesHitsDoNotIntersect;
    [Test]
    procedure TestFindMatchesConfinedToROI;
    [Test]
    procedure TestFindMatchesEmptyWhenTemplateCannotFit;
    [Test]
    procedure TestFindMatchesRejectsDegenerateInputs;
    [Test]
    procedure TestNotFoundResultShape;
    [Test]
    procedure TestOptionsRoundTrip;
    [Test]
    procedure TestRealScreenCaptureContract;
  end;

implementation

const
  C_WHITE: TColor32 = $00FFFFFF;
  C_RED: TColor32 = $000000FF;
  C_BLUE: TColor32 = $00FF0000;
  C_NEARY: TColor32 = $00F0F0F0; // 与 C_WHITE 每通道差 15，三通道和 45
  // 快照全屏区域（屏幕坐标）
  C_DESKTOP: TRect = (Left: 100; Top: 50; Right: 124; Bottom: 66);

{ TTestScreenRegionLocator }

class procedure TTestScreenRegionLocator.Fill(const ABuf: TPixelBuffer;
  AColor: TColor32);
var
  X, Y: Integer;
  LRow: PColor32;
begin
  for Y := 0 to ABuf.Height - 1 do
  begin
    LRow := PColor32(ABuf.Bitmap.ScanLine[Y]);
    for X := 0 to ABuf.Width - 1 do
      LRow[X] := AColor;
  end;
end;

class procedure TTestScreenRegionLocator.Paint(const ABuf: TPixelBuffer;
  const ALocalRect: TRect; AColor: TColor32);
var
  X, Y: Integer;
  LRow: PColor32;
begin
  for Y := ALocalRect.Top to ALocalRect.Bottom - 1 do
  begin
    LRow := PColor32(ABuf.Bitmap.ScanLine[Y]);
    for X := ALocalRect.Left to ALocalRect.Right - 1 do
      LRow[X] := AColor;
  end;
end;

class procedure TTestScreenRegionLocator.AssertHitCount(AExpected: Integer;
  const AHits: TArray<TMatchResult>; const AMessage: string);
var
  LCount: Integer;
begin
  LCount := Length(AHits);
  Assert.AreEqual(AExpected, LCount, AMessage);
end;

function TTestScreenRegionLocator.MakeTemplate(AWidth, AHeight: Integer;
  AColor: TColor32): TPixelBuffer;
begin
  Result.Bitmap := TBitmap.Create;
  Result.Bitmap.PixelFormat := pf32bit;
  Result.Bitmap.Width := AWidth;
  Result.Bitmap.Height := AHeight;
  // 模板自身坐标一律从 (0,0) 起算：匹配层只看像素内容，不关心它来自屏幕何处
  Result.OriginX := 0;
  Result.OriginY := 0;
  Fill(Result, AColor);
end;

function TTestScreenRegionLocator.BuildSnapshot: TPixelBuffer;
begin
  Result.Bitmap := TBitmap.Create;
  Result.Bitmap.PixelFormat := pf32bit;
  Result.Bitmap.Width := 24;
  Result.Bitmap.Height := 16;
  Result.OriginX := 100;
  Result.OriginY := 50;
  Fill(Result, C_WHITE);
  Paint(Result, Rect(5, 4, 9, 7), C_RED);
  Paint(Result, Rect(18, 10, 22, 13), C_RED);
end;

procedure TTestScreenRegionLocator.Setup;
begin
  FLocator := TScreenRegionLocator.Create;
end;

procedure TTestScreenRegionLocator.Teardown;
begin
  FLocator := nil;
end;

procedure TTestScreenRegionLocator.TestScoreAtExactPatchIsOne;
var
  LSnap, LTmpl: TPixelBuffer;
begin
  LSnap := BuildSnapshot;
  LTmpl := MakeTemplate(4, 3, C_RED);
  try
    Assert.AreEqual(1.0,
      TTemplateMatcher.ScoreAt(LSnap, LTmpl, 105, 54, 30, 12), 1e-9);
  finally
    LTmpl.Release;
    LSnap.Release;
  end;
end;

procedure TTestScreenRegionLocator.TestScoreAtMisalignedPatchIsHitFraction;
var
  LSnap, LTmpl: TPixelBuffer;
begin
  LSnap := BuildSnapshot;
  LTmpl := MakeTemplate(4, 3, C_RED);
  try
    // 上移一行：模板 12 像素里只有 2 行 8 个落在红块上
    Assert.AreEqual(8.0 / 12.0,
      TTemplateMatcher.ScoreAt(LSnap, LTmpl, 105, 53, 30, 12), 1e-9);
    // 完全落在白底上
    Assert.AreEqual(0.0,
      TTemplateMatcher.ScoreAt(LSnap, LTmpl, 100, 50, 30, 12), 1e-9);
  finally
    LTmpl.Release;
    LSnap.Release;
  end;
end;

procedure TTestScreenRegionLocator.TestScoreAtPrunesBeyondMismatchBudget;
var
  LSnap, LTmpl: TPixelBuffer;
begin
  LSnap := BuildSnapshot;
  LTmpl := MakeTemplate(4, 3, C_RED);
  try
    // 同一位置真实失配 4；预算 3 => 提前剪枝返回 -1（= 必然低于阈值）
    Assert.AreEqual(-1.0,
      TTemplateMatcher.ScoreAt(LSnap, LTmpl, 105, 53, 30, 3), 1e-9);
  finally
    LTmpl.Release;
    LSnap.Release;
  end;
end;

procedure TTestScreenRegionLocator.TestFindMatchesReturnsScreenCoordinates;
var
  LSnap, LTmpl: TPixelBuffer;
  LHits: TArray<TMatchResult>;
begin
  LSnap := BuildSnapshot;
  LTmpl := MakeTemplate(4, 3, C_RED);
  try
    // 阈值 1.0 = 只接受整块精确命中，位置必须逐像素对齐
    LHits := TTemplateMatcher.FindMatches(LSnap, LTmpl, C_DESKTOP, 30, 1.0, 10);
    AssertHitCount(2, LHits);
    if Length(LHits) = 2 then
    begin
      // 扫描序：先左上块
      Assert.IsTrue(LHits[0].Found);
      Assert.AreEqual(105, LHits[0].Position.X);
      Assert.AreEqual(54, LHits[0].Position.Y);
      Assert.AreEqual(1.0, LHits[0].Confidence, 1e-9);
      Assert.AreEqual(Rect(105, 54, 109, 57), LHits[0].Rect);
      Assert.AreEqual(118, LHits[1].Position.X);
      Assert.AreEqual(60, LHits[1].Position.Y);
    end;
  finally
    LTmpl.Release;
    LSnap.Release;
  end;
end;

procedure TTestScreenRegionLocator.TestFindMatchesAcceptsPartialPatchAtThreshold;
var
  LSnap, LTmpl: TPixelBuffer;
  LHits: TArray<TMatchResult>;
begin
  LSnap := BuildSnapshot;
  LTmpl := MakeTemplate(4, 3, C_RED);
  try
    // 阈值 0.7：左移一列仍有 9/12=0.75 命中，扫描序上的第一个可接受位置即 (104,54)
    LHits := TTemplateMatcher.FindMatches(LSnap, LTmpl, C_DESKTOP, 30, 0.7, 1);
    AssertHitCount(1, LHits);
    if Length(LHits) = 1 then
    begin
      Assert.AreEqual(104, LHits[0].Position.X);
      Assert.AreEqual(54, LHits[0].Position.Y);
      Assert.AreEqual(0.75, LHits[0].Confidence, 1e-9);
    end;
  finally
    LTmpl.Release;
    LSnap.Release;
  end;
end;

procedure TTestScreenRegionLocator.TestFindMatchesRejectsBelowMinConfidence;
var
  LSnap, LTmpl: TPixelBuffer;
begin
  LSnap := BuildSnapshot;
  LTmpl := MakeTemplate(4, 3, C_BLUE);
  try
    AssertHitCount(0,
      TTemplateMatcher.FindMatches(LSnap, LTmpl, C_DESKTOP, 30, 0.7, 10));
  finally
    LTmpl.Release;
    LSnap.Release;
  end;
end;

procedure TTestScreenRegionLocator.TestFindMatchesToleranceBoundaryIsInclusive;
var
  LSnap, LTmpl: TPixelBuffer;
begin
  // 快照整片 $F0F0F0，模板纯白：每像素三通道差之和恰为 45
  LSnap := BuildSnapshot;
  Fill(LSnap, C_NEARY);
  LTmpl := MakeTemplate(2, 2, C_WHITE);
  try
    AssertHitCount(1,
      TTemplateMatcher.FindMatches(LSnap, LTmpl, C_DESKTOP, 45, 1.0, 1),
      '容差 45 恰好命中（判定含等号）');
    AssertHitCount(0,
      TTemplateMatcher.FindMatches(LSnap, LTmpl, C_DESKTOP, 44, 1.0, 1),
      '容差 44 应失配');
  finally
    LTmpl.Release;
    LSnap.Release;
  end;
end;

procedure TTestScreenRegionLocator.TestFindMatchesHitsDoNotIntersect;
var
  LSnap, LTmpl: TPixelBuffer;
  LHits: TArray<TMatchResult>;
  I, J: Integer;
begin
  LSnap := BuildSnapshot;
  Fill(LSnap, C_WHITE);
  // 局部 0..9 连续红带（三块 4x3 首尾相接）：精确位置为 x=0..6，逐个都会被扫到
  Paint(LSnap, Rect(0, 0, 4, 3), C_RED);
  Paint(LSnap, Rect(3, 0, 7, 3), C_RED);
  Paint(LSnap, Rect(6, 0, 10, 3), C_RED);
  LTmpl := MakeTemplate(4, 3, C_RED);
  try
    LHits := TTemplateMatcher.FindMatches(LSnap, LTmpl, C_DESKTOP, 30, 1.0, 10);
    AssertHitCount(2, LHits, '重叠候选应被邻域抑制');
    for I := 0 to High(LHits) do
      for J := I + 1 to High(LHits) do
        Assert.IsTrue(TRect.Intersect(LHits[I].Rect, LHits[J].Rect).IsEmpty,
      '命中矩形不得相交');
  finally
    LTmpl.Release;
    LSnap.Release;
  end;
end;

procedure TTestScreenRegionLocator.TestFindMatchesConfinedToROI;
var
  LSnap, LTmpl: TPixelBuffer;
begin
  LSnap := BuildSnapshot;
  LTmpl := MakeTemplate(4, 3, C_RED);
  try
    // ROI 覆盖左上块完整 4x3 范围，但不含右下块
    AssertHitCount(1,
      TTemplateMatcher.FindMatches(LSnap, LTmpl, Rect(100, 50, 112, 60), 30, 1.0, 10));
    // ROI 右边界切到 108 => 模板无处可放 => 无命中
    AssertHitCount(0,
      TTemplateMatcher.FindMatches(LSnap, LTmpl, Rect(100, 50, 108, 66), 30, 1.0, 10));
  finally
    LTmpl.Release;
    LSnap.Release;
  end;
end;

procedure TTestScreenRegionLocator.TestFindMatchesEmptyWhenTemplateCannotFit;
var
  LSnap, LTmpl: TPixelBuffer;
begin
  LSnap := BuildSnapshot;
  LTmpl := MakeTemplate(30, 20, C_RED);
  try
    AssertHitCount(0,
      TTemplateMatcher.FindMatches(LSnap, LTmpl, C_DESKTOP, 30, 0.7, 10));
  finally
    LTmpl.Release;
    LSnap.Release;
  end;
end;

procedure TTestScreenRegionLocator.TestFindMatchesRejectsDegenerateInputs;
var
  LSnap, LTmpl, LEmpty: TPixelBuffer;
begin
  LSnap := BuildSnapshot;
  LTmpl := MakeTemplate(4, 3, C_RED);
  LEmpty.Bitmap := nil;
  LEmpty.OriginX := 0;
  LEmpty.OriginY := 0;
  try
    // 零尺寸模板 / 空快照 / AMaxCount<1 一律返回空，不抛不崩
    AssertHitCount(0,
      TTemplateMatcher.FindMatches(LSnap, LEmpty, C_DESKTOP, 30, 0.7, 10));
    AssertHitCount(0,
      TTemplateMatcher.FindMatches(LEmpty, LTmpl, C_DESKTOP, 30, 0.7, 10));
    AssertHitCount(0,
      TTemplateMatcher.FindMatches(LSnap, LTmpl, C_DESKTOP, 30, 0.7, 0));
    Assert.AreEqual(-1.0, TTemplateMatcher.ScoreAt(LSnap, LEmpty, 105, 54, 30, 0), 1e-9);
  finally
    LTmpl.Release;
    LSnap.Release;
  end;
end;

procedure TTestScreenRegionLocator.TestNotFoundResultShape;
var
  LResult: TMatchResult;
begin
  LResult := TMatchResult.NotFound;
  Assert.IsFalse(LResult.Found);
  Assert.AreEqual(0.0, LResult.Confidence, 1e-9);
  Assert.AreEqual(-1, LResult.Position.X);
  Assert.AreEqual(-1, LResult.Position.Y);
  Assert.AreEqual(0, LResult.Rect.Width);
end;

procedure TTestScreenRegionLocator.TestOptionsRoundTrip;
var
  LOptions: TRegionLocatorOptions;
begin
  LOptions := FLocator.GetOptions;
  Assert.AreEqual(0.7, LOptions.MinConfidence, 1e-9);
  Assert.AreEqual(30, LOptions.Tolerance);
  Assert.IsFalse(LOptions.UseROI);

  LOptions.MinConfidence := 0.95;
  LOptions.Tolerance := 12;
  LOptions.UseROI := True;
  LOptions.ROIBounds := Rect(1, 2, 300, 400);
  FLocator.SetOptions(LOptions);
  LOptions := FLocator.GetOptions;
  Assert.AreEqual(0.95, LOptions.MinConfidence, 1e-9);
  Assert.AreEqual(12, LOptions.Tolerance);
  Assert.IsTrue(LOptions.UseROI);
  Assert.AreEqual(Rect(1, 2, 300, 400), LOptions.ROIBounds);
end;

procedure TTestScreenRegionLocator.TestRealScreenCaptureContract;
var
  LTmpl: TPixelBuffer;
  LResult: TMatchResult;
begin
  // 真实路径只断言契约形状：命中则 Rect 尺寸必等于模板、占比必达阈值；
  // 未命中则 Confidence 恒 0。屏幕内容不受测试控制，不断言具体位置。
  try
    FLocator.CaptureScreen;
  except
    on EInvalidOperation do
      Assert.Pass('无可用桌面会话：抓取失败已按 fail-loud 抛出');
  end;

  LTmpl := MakeTemplate(4, 3, C_RED);
  try
    LResult := FLocator.FindTemplate(LTmpl);
    if LResult.Found then
    begin
      Assert.AreEqual(4, LResult.Rect.Width);
      Assert.AreEqual(3, LResult.Rect.Height);
      Assert.IsTrue(LResult.Confidence >= FLocator.GetOptions.MinConfidence);
    end
    else
      Assert.AreEqual(0.0, LResult.Confidence, 1e-9);
  finally
    LTmpl.Release;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestScreenRegionLocator);

end.
