unit Test.DeepBase.Desktop.Perception.FrameCache;

{ ============================================================================
  Tests for the L0 frame cache (PERCEPT-P2-001): an identical screenshot
  (same provider identity + same MD5 of ImageBase64) reuses the last
  recognition result and skips the vision provider call; a different
  screenshot re-invokes; SetProvider invalidates. Driven through the
  capture-free Perceive(AShot) overload so a fixed shot is reproducible.
  ========================================================================== }

interface

uses
  System.SysUtils,
  System.Types,
  DUnitX.TestFramework,
  DeepBase.Desktop.Perception.Types,
  DeepBase.Desktop.Perception.Engine;

type
  // Stub vision provider. Counts how many times Recognize was actually
  // invoked so a frame-cache hit is observable as no increment.
  TCountingStubProvider = class(TInterfacedObject, IDesktopVisionProvider)
  private
    FRecognizeCount: Integer;
    FName: string;
    FElements: TPerceivedElementArray;
  public
    constructor Create(const AName: string);
    function Recognize(const AShot: TDesktopScreenshot;
      out AElements: TPerceivedElementArray): Boolean;
    function FindByLabel(const AShot: TDesktopScreenshot;
      const ALabel: string; out AElement: TPerceivedElement): Boolean;
    function IsAvailable: Boolean;
    function GetName: string;
    property RecognizeCount: Integer read FRecognizeCount;
  end;

  [TestFixture]
  TFrameCacheTests = class
  private
    function MakeShot(const ABase64: string): TDesktopScreenshot;
  public
    [Test]
    procedure Test_SameFrame_SecondPerceiveSkipsProvider;

    [Test]
    procedure Test_DifferentFrame_ReinvokesProvider;

    [Test]
    procedure Test_SetProvider_InvalidatesFrameCache;

    [Test]
    procedure Test_FindByLabel_ReusesFrameCacheSameFrame;
  end;

implementation

{ TCountingStubProvider }

constructor TCountingStubProvider.Create(const AName: string);
var
  LEl: TPerceivedElement;
begin
  inherited Create;
  FName := AName;
  FRecognizeCount := 0;
  // Return one fixed element so the cache has something to reuse.
  LEl := Default(TPerceivedElement);
  LEl.Label_ := 'Send';
  LEl.BoundingBox := Rect(10, 10, 80, 40);
  LEl.Confidence := 0.9;
  SetLength(FElements, 1);
  FElements[0] := LEl;
end;

function TCountingStubProvider.Recognize(const AShot: TDesktopScreenshot;
  out AElements: TPerceivedElementArray): Boolean;
begin
  Inc(FRecognizeCount);
  AElements := Copy(FElements);
  Result := True;
end;

function TCountingStubProvider.FindByLabel(const AShot: TDesktopScreenshot;
  const ALabel: string; out AElement: TPerceivedElement): Boolean;
begin
  Result := False;
end;

function TCountingStubProvider.IsAvailable: Boolean;
begin
  Result := True;
end;

function TCountingStubProvider.GetName: string;
begin
  Result := FName;
end;

{ TFrameCacheTests }

function TFrameCacheTests.MakeShot(const ABase64: string): TDesktopScreenshot;
begin
  Result := Default(TDesktopScreenshot);
  Result.ImageBase64 := ABase64;
  Result.MimeType := 'image/png';
  Result.WidthPx := 800;
  Result.HeightPx := 600;
end;

procedure TFrameCacheTests.Test_SameFrame_SecondPerceiveSkipsProvider;
var
  LEngine: TDesktopPerceptionEngine;
  LProvider: TCountingStubProvider;
  LShot: TDesktopScreenshot;
  LR1, LR2: TPerceptionResult;
begin
  // Same screenshot passed twice: first Perceive misses -> provider invoked
  // (count=1); second Perceive on the identical shot hits the frame cache
  // -> provider NOT invoked (count stays 1), result reused.
  LProvider := TCountingStubProvider.Create('stub-a');
  LEngine := TDesktopPerceptionEngine.Create(LProvider);
  try
    LShot := MakeShot('AAAA-same-frame');
    LR1 := LEngine.Perceive(LShot);
    Assert.AreEqual(1, LProvider.RecognizeCount, 'first perceive invoked');
    Assert.AreEqual(1, LR1.ElementCount, 'first perceive returned 1 element');
    Assert.AreEqual('stub-a', LR1.ProviderUsed, 'provider used recorded');

    LR2 := LEngine.Perceive(LShot);
    Assert.AreEqual(1, LProvider.RecognizeCount,
      'second perceive reused cache, provider not invoked');
    Assert.AreEqual(1, LR2.ElementCount, 'reused result has 1 element');
    Assert.AreEqual('stub-a', LR2.ProviderUsed, 'reused provider recorded');
    Assert.AreEqual(LR1.Elements[0].Label_, LR2.Elements[0].Label_,
      'reused element label matches');
  finally
    LEngine.Free;
  end;
end;

procedure TFrameCacheTests.Test_DifferentFrame_ReinvokesProvider;
var
  LEngine: TDesktopPerceptionEngine;
  LProvider: TCountingStubProvider;
  LShotA, LShotB: TDesktopScreenshot;
begin
  // Different screenshot base64 -> different MD5 key -> cache miss ->
  // provider invoked again on the second frame.
  LProvider := TCountingStubProvider.Create('stub-diff');
  LEngine := TDesktopPerceptionEngine.Create(LProvider);
  try
    LShotA := MakeShot('frame-AAA');
    LShotB := MakeShot('frame-BBB');
    LEngine.Perceive(LShotA);
    Assert.AreEqual(1, LProvider.RecognizeCount, 'frame A invoked');
    LEngine.Perceive(LShotB);
    Assert.AreEqual(2, LProvider.RecognizeCount,
      'frame B reinvoked (cache miss)');
    // Going back to frame A is a miss again (single-slot cache holds only B).
    LEngine.Perceive(LShotA);
    Assert.AreEqual(3, LProvider.RecognizeCount,
      'frame A again reinvoked (single-slot evicted B)');
  finally
    LEngine.Free;
  end;
end;

procedure TFrameCacheTests.Test_SetProvider_InvalidatesFrameCache;
var
  LEngine: TDesktopPerceptionEngine;
  LProviderA, LProviderB: TCountingStubProvider;
  LShot: TDesktopScreenshot;
begin
  // After SetProvider, the frame cache must be invalidated: even the SAME
  // shot re-invokes the new provider (the cache key includes provider
  // identity, so a swap yields a different key and auto-misses).
  LProviderA := TCountingStubProvider.Create('stub-a');
  LProviderB := TCountingStubProvider.Create('stub-b');
  LEngine := TDesktopPerceptionEngine.Create(LProviderA);
  try
    LShot := MakeShot('frame-X');
    LEngine.Perceive(LShot);
    Assert.AreEqual(1, LProviderA.RecognizeCount, 'provider A recognized');
    // Swap provider. Frame cache invalidated; same shot must hit provider B.
    LEngine.Provider := LProviderB;
    LEngine.Perceive(LShot);
    Assert.AreEqual(1, LProviderB.RecognizeCount,
      'provider B recognized after swap');
    Assert.AreEqual(1, LProviderA.RecognizeCount,
      'provider A not invoked after swap');
    // Same shot again now hits the cache under provider B (count stays 1).
    LEngine.Perceive(LShot);
    Assert.AreEqual(1, LProviderB.RecognizeCount,
      'provider B reused cache on identical shot after swap');
  finally
    LEngine.Free;
  end;
end;

procedure TFrameCacheTests.Test_FindByLabel_ReusesFrameCacheSameFrame;
var
  LEngine: TDesktopPerceptionEngine;
  LProvider: TCountingStubProvider;
  LShot: TDesktopScreenshot;
  LOut: TPerceivedElement;
begin
  // After Perceive(AShot) warms the frame cache, a FindByLabel for a label
  // not in the label cache but present in the cached frame elements must be
  // served from the frame cache WITHOUT invoking the provider again.
  LProvider := TCountingStubProvider.Create('stub-frame');
  LEngine := TDesktopPerceptionEngine.Create(LProvider);
  try
    LShot := MakeShot('frame-same');
    // Warm the frame cache: provider invoked once.
    LEngine.Perceive(LShot);
    Assert.AreEqual(1, LProvider.RecognizeCount, 'perceive warmed cache');
    // FindByLabel for 'Send' (which the stub returns) on the SAME shot:
    // label cache misses (FindByLabel never populated it for 'Send'), but
    // the frame cache has 'Send' -> served without invoking provider.
    Assert.IsTrue(LEngine.FindByLabel(LShot, 'Send', LOut),
      'found via frame cache');
    Assert.AreEqual('Send', LOut.Label_, 'correct label returned');
    Assert.AreEqual(1, LProvider.RecognizeCount,
      'provider not invoked (frame cache served)');
    // A label NOT in the cached frame ('Reply') must miss both caches and
    // fall through to the provider (count -> 2).
    Assert.IsFalse(LEngine.FindByLabel(LShot, 'Reply', LOut),
      'unknown label not found');
    Assert.AreEqual(2, LProvider.RecognizeCount,
      'unknown label fell through to provider');
  finally
    LEngine.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TFrameCacheTests);

end.
