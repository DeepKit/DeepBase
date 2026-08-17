unit Test.DeepBase.Desktop.Perception.BitmapSource;

{ ============================================================================
  Tests for the CaptureToBitmap injection point (PERCEPT-P2-001 Step B1):
  the FBitmapSource TFunc<TRect,TBitmap> lets a caller replace BitBlt with an
  injected bitmap so disk-recorded frames replay through the FULL FrameDiffer
  path (which otherwise only runs inside the real CaptureScreen BitBlt path).

  Four assertions (the calibration harness depends on all four holding):
  (1) static pair   : same injected bitmap twice -> Unchanged=True (the
                      differ judges the replayed frame static and reuses the
                      prior encoding, i.e. the L0a gate fires on replay).
  (2) changed pair  : two different injected bitmaps -> Unchanged=False on the
                      second (the gate correctly does NOT short-circuit real
                      content changes).
  (3) injection-live: an injected bitmap flows through CaptureScreen's
                      FrameDiffer gate and sets Unchanged appropriately,
                      proving the injection reaches the same gate code as a
                      live BitBlt (not a parallel dead path).
  (4) signature-eq  : the SampleSignature of an injected pf24bit bitmap and a
                      live-BitBlt-style pf32bit bitmap of the same content are
                      byte-identical after the internal pf32bit normalization.
                      This converts the "replay is not a format phantom" claim
                      from assumption to evidence (docs/94 §6 calibration
                      validity depends on it).

  No real screen capture is needed: BitmapSource supplies deterministic
  bitmaps. BitmapSource=nil (production default) is covered by the existing
  FrameDiffer/FrameCache suites that never set it.
  ========================================================================== }

interface

uses
  System.SysUtils,
  System.Types,
  Winapi.Windows,
  Vcl.Graphics,
  DUnitX.TestFramework,
  DeepBase.Desktop.Perception.Types,
  DeepBase.Desktop.Perception.Engine;

{$POINTERMATH ON}

type
  [TestFixture]
  TBitmapSourceTests = class
  private
    function MakeSolidBitmap(const AColor: TColor; AW, AH: Integer): TBitmap;
    function MakeSolidBitmapPf24(const AColor: TColor; AW, AH: Integer): TBitmap;
    function CapturesEqual(const A, B: TFrameSignature): Boolean;
  public
    [Test]
    procedure StaticPair_InjectedReplay_Unchanged;

    [Test]
    procedure ChangedPair_InjectedReplay_NotUnchanged;

    [Test]
    procedure InjectedBitmap_FlowsThroughFrameDifferGate;

    [Test]
    procedure Signature_Equal_AcrossPixelFormatSources;
  end;

implementation

{ ---- helpers ------------------------------------------------------------ }

function TBitmapSourceTests.MakeSolidBitmap(const AColor: TColor;
  AW, AH: Integer): TBitmap;
var
  X, Y: Integer;
  LRow: PRGBQuad;
begin
  Result := TBitmap.Create;
  Result.PixelFormat := pf32bit;
  Result.SetSize(AW, AH);
  for Y := 0 to AH - 1 do
  begin
    LRow := Result.ScanLine[Y];
    for X := 0 to AW - 1 do
    begin
      LRow[X].rgbRed := GetRValue(AColor);
      LRow[X].rgbGreen := GetGValue(AColor);
      LRow[X].rgbBlue := GetBValue(AColor);
      LRow[X].rgbReserved := 0;
    end;
  end;
end;

function TBitmapSourceTests.MakeSolidBitmapPf24(const AColor: TColor;
  AW, AH: Integer): TBitmap;
{ A pf24bit-DIB bitmap, mirroring the format a disk PNG decodes to. Used to
  prove the signature is format-source-independent vs the pf32bit live path. }
var
  X, Y: Integer;
  LRow: PByte;
begin
  Result := TBitmap.Create;
  Result.PixelFormat := pf24bit;
  Result.SetSize(AW, AH);
  for Y := 0 to AH - 1 do
  begin
    LRow := Result.ScanLine[Y];
    for X := 0 to AW - 1 do
    begin
      // pf24bit is BGR order.
      LRow[X * 3] := GetBValue(AColor);
      LRow[X * 3 + 1] := GetGValue(AColor);
      LRow[X * 3 + 2] := GetRValue(AColor);
    end;
  end;
end;

function TBitmapSourceTests.CapturesEqual(const A, B: TFrameSignature): Boolean;
begin
  Result := (A.WidthCells = B.WidthCells) and (A.HeightCells = B.HeightCells)
    and (A.Stride = B.Stride) and (Length(A.Cells) = Length(B.Cells));
  if Result and (Length(A.Cells) > 0) then
    Result := CompareMem(A.Cells, B.Cells, Length(A.Cells));
end;

{ ---- tests -------------------------------------------------------------- }

procedure TBitmapSourceTests.StaticPair_InjectedReplay_Unchanged;
var
  LEngine: TDesktopPerceptionEngine;
  LShot1, LShot2: TDesktopScreenshot;
  LEmitter: Integer;
begin
  // Inject a source that returns a FRESH bitmap of identical content on each
  // call (simulating replaying the same recorded frame twice). CaptureScreen
  // frees the bitmap it receives from CaptureToBitmap, so the source must own
  // creation; we hand over a new copy each call. The differ must judge the
  // second capture static and set Unchanged=True.
  LEngine := TDesktopPerceptionEngine.Create(nil);
  try
    LEmitter := 0;
    LEngine.BitmapSource :=
      function(ARect: TRect): TBitmap
      begin
        Inc(LEmitter);
        Result := MakeSolidBitmap(clNavy, 80, 80);  // fresh, handed to engine
      end;
    LShot1 := LEngine.CaptureScreen;
    LShot2 := LEngine.CaptureScreen;
    Assert.IsTrue(LShot1.IsValid, 'first captured shot valid');
    Assert.IsFalse(LShot1.Unchanged, 'first frame is a seed, never Unchanged');
    Assert.IsTrue(LShot2.Unchanged,
      'second identical injected frame must short-circuit (Unchanged=True)');
    Assert.AreEqual(2, LEmitter, 'injection source invoked once per capture');
  finally
    LEngine.Free;
  end;
end;

procedure TBitmapSourceTests.ChangedPair_InjectedReplay_NotUnchanged;
var
  LEngine: TDesktopPerceptionEngine;
  LShot1, LShot2: TDesktopScreenshot;
  LEmitSecond: Boolean;
begin
  // Two genuinely different injected bitmaps: the second must NOT be judged
  // static (no false short-circuit on a content change).
  LEngine := TDesktopPerceptionEngine.Create(nil);
  try
    LEmitSecond := False;
    LEngine.BitmapSource :=
      function(ARect: TRect): TBitmap
      begin
        if not LEmitSecond then
        begin
          LEmitSecond := True;
          Result := MakeSolidBitmap(clBlack, 64, 64);
        end
        else
          Result := MakeSolidBitmap(clWhite, 64, 64);
      end;
    LShot1 := LEngine.CaptureScreen;
    LShot2 := LEngine.CaptureScreen;
    Assert.IsFalse(LShot1.Unchanged, 'first frame seed');
    Assert.IsFalse(LShot2.Unchanged,
      'different content must NOT short-circuit (Unchanged=False)');
  finally
    LEngine.Free;
  end;
end;

procedure TBitmapSourceTests.InjectedBitmap_FlowsThroughFrameDifferGate;
var
  LEngine: TDesktopPerceptionEngine;
  LShot: TDesktopScreenshot;
begin
  // Single injected bitmap: the gate seeds on it (Unchanged=False on first
  // capture). Combined with the static-pair test this proves the injected
  // bitmap reaches the SAME FrameDiffer gate code a live BitBlt would, not a
  // bypass. Also exercises the FrameDiffThreshold passthrough + Reset.
  LEngine := TDesktopPerceptionEngine.Create(nil);
  try
    LEngine.FrameDiffThreshold := 0.01;  // passthrough must reach the differ
    LEngine.BitmapSource :=
      function(ARect: TRect): TBitmap
      begin
        Result := MakeSolidBitmap(clGreen, 96, 96);
      end;
    LShot := LEngine.CaptureScreen;
    Assert.IsFalse(LShot.Unchanged, 'first injected frame seeds (changed)');
    // Second identical -> static, proving threshold/seed path intact.
    Assert.IsTrue(LEngine.CaptureScreen.Unchanged, 'second static after seed');
    // Reset clears the prior frame; the next capture re-seeds (changed).
    LEngine.ResetFrameDiffer;
    Assert.IsFalse(LEngine.CaptureScreen.Unchanged,
      'after ResetFrameDiffer the identical frame re-seeds (changed)');
  finally
    LEngine.Free;
  end;
end;

procedure TBitmapSourceTests.Signature_Equal_AcrossPixelFormatSources;
var
  LDiffer: TFrameDiffer;
  LBmpPf32, LBmpPf24: TBitmap;
  LSig32, LSig24: TFrameSignature;
begin
  // The format-phantom residual: a disk-PNG-decoded pf24bit bitmap and a
  // live-BitBlt-style pf32bit bitmap of identical content must produce
  // byte-identical signatures, because SampleSignature normalizes through an
  // internal pf32bit LWork canvas. If this ever breaks, replay calibration
  // measures a phantom and docs/94 §6 numbers are invalid.
  LDiffer := TFrameDiffer.Create(0.004);
  try
    LBmpPf32 := MakeSolidBitmap(clTeal, 64, 64);
    try
      LBmpPf24 := MakeSolidBitmapPf24(clTeal, 64, 64);
      try
        LSig32 := LDiffer.SampleSignature(LBmpPf32);
        LSig24 := LDiffer.SampleSignature(LBmpPf24);
        Assert.IsFalse(LSig32.IsEmpty, 'pf32bit signature non-empty');
        Assert.IsTrue(CapturesEqual(LSig32, LSig24),
          'pf24bit (disk-PNG-like) and pf32bit (live-BitBlt-like) signatures ' +
          'must be byte-identical after normalization');
      finally
        LBmpPf24.Free;
      end;
    finally
      LBmpPf32.Free;
    end;
  finally
    LDiffer.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBitmapSourceTests);

end.
