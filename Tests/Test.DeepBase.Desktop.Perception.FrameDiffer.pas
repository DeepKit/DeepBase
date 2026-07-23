unit Test.DeepBase.Desktop.Perception.FrameDiffer;

{ ============================================================================
  Tests for the L0 pixel-diff gate (PERCEPT-P2-001b): TFrameDiffer decides
  whether a captured bitmap changed against the previous frame. An identical
  frame is judged static (IsChanged=False) so CaptureScreen can reuse the prior
  encoding; a visibly different frame is judged changed (IsChanged=True); the
  first frame is always changed (seed); a dimension change is always changed
  (uncomparable). Threshold is configurable. Tests build synthetic TBitmaps so
  no real screen capture is needed.
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

type
  [TestFixture]
  TFrameDifferTests = class
  private
    function MakeSolidBitmap(const AColor: TColor;
      AW, AH: Integer): TBitmap;
  public
    [Test]
    procedure Test_FirstFrame_AlwaysChanged;

    [Test]
    procedure Test_IdenticalFrame_NotChanged;

    [Test]
    procedure Test_DifferentColor_Changed;

    [Test]
    procedure Test_DimensionChange_AlwaysChanged;

    [Test]
    procedure Test_ThresholdLax_ToleratesSmallChange;

    [Test]
    procedure Test_Reset_FollowedByFirstFrameChanged;
  end;

implementation

{$POINTERMATH ON}

{ TFrameDifferTests }

// Build a small solid-color bitmap in pf32bit so ScanLine layout is fixed and
// the differ's internal pf32bit copy is a no-op-equivalent. Caller owns and
// must free the result.
function TFrameDifferTests.MakeSolidBitmap(const AColor: TColor;
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

procedure TFrameDifferTests.Test_FirstFrame_AlwaysChanged;
var
  LDiffer: TFrameDiffer;
  LBmp: TBitmap;
begin
  // No prior signature: the first IsChanged must seed and return True so a
  // capture happens at least once.
  LDiffer := TFrameDiffer.Create(0.004);
  try
    LBmp := MakeSolidBitmap(clWhite, 64, 64);
    try
      Assert.IsTrue(LDiffer.IsChanged(LBmp),
        'first frame must be reported as changed (seed)');
    finally
      LBmp.Free;
    end;
  finally
    LDiffer.Free;
  end;
end;

procedure TFrameDifferTests.Test_IdenticalFrame_NotChanged;
var
  LDiffer: TFrameDiffer;
  LBmp1, LBmp2: TBitmap;
begin
  // Same bitmap twice: after seeding with the first, the second identical
  // frame must be judged static (IsChanged=False) so CaptureScreen reuses the
  // prior encoding and skips both PNG encode and the vision provider.
  LDiffer := TFrameDiffer.Create(0.004);
  try
    LBmp1 := MakeSolidBitmap(clNavy, 80, 80);
    try
      Assert.IsTrue(LDiffer.IsChanged(LBmp1), 'seed frame');
      LBmp2 := MakeSolidBitmap(clNavy, 80, 80);
      try
        Assert.IsFalse(LDiffer.IsChanged(LBmp2),
          'identical frame must be judged static');
      finally
        LBmp2.Free;
      end;
    finally
      LBmp1.Free;
    end;
  finally
    LDiffer.Free;
  end;
end;

procedure TFrameDifferTests.Test_DifferentColor_Changed;
var
  LDiffer: TFrameDiffer;
  LBmp1, LBmp2: TBitmap;
begin
  // Two clearly different colors: every cell differs across all channels, so
  // the change ratio far exceeds the 0.4% threshold -> IsChanged=True.
  LDiffer := TFrameDiffer.Create(0.004);
  try
    LBmp1 := MakeSolidBitmap(clBlack, 64, 64);
    try
      Assert.IsTrue(LDiffer.IsChanged(LBmp1), 'seed frame');
      LBmp2 := MakeSolidBitmap(clWhite, 64, 64);
      try
        Assert.IsTrue(LDiffer.IsChanged(LBmp2),
          'black->white must be detected as changed');
      finally
        LBmp2.Free;
      end;
    finally
      LBmp1.Free;
    end;
  finally
    LDiffer.Free;
  end;
end;

procedure TFrameDifferTests.Test_DimensionChange_AlwaysChanged;
var
  LDiffer: TFrameDiffer;
  LBmp1, LBmp2: TBitmap;
begin
  // Same color but different dimensions: signatures are uncomparable
  // (different cell grid), so IsChanged must return True (treat as changed)
  // and refresh the signature to the new size.
  LDiffer := TFrameDiffer.Create(0.004);
  try
    LBmp1 := MakeSolidBitmap(clGreen, 64, 64);
    try
      Assert.IsTrue(LDiffer.IsChanged(LBmp1), 'seed frame');
      LBmp2 := MakeSolidBitmap(clGreen, 96, 96);
      try
        Assert.IsTrue(LDiffer.IsChanged(LBmp2),
          'dimension change must be detected as changed (uncomparable)');
      finally
        LBmp2.Free;
      end;
    finally
      LBmp1.Free;
    end;
  finally
    LDiffer.Free;
  end;
end;

procedure TFrameDifferTests.Test_ThresholdLax_ToleratesSmallChange;
var
  LDiffer: TFrameDiffer;
  LBmp1, LBmp2: TBitmap;
  X, Y: Integer;
  LRow: PRGBQuad;
begin
  // A tiny per-pixel nudge (every channel +1) is far below even a strict
  // threshold; with a lax threshold (1.0 = tolerate everything) an altered
  // frame is judged static. This proves the threshold knob actually gates the
  // decision rather than the differ always reporting changed.
  LDiffer := TFrameDiffer.Create(1.0);
  try
    LBmp1 := MakeSolidBitmap(clGray, 64, 64);
    try
      Assert.IsTrue(LDiffer.IsChanged(LBmp1), 'seed frame');
      LBmp2 := MakeSolidBitmap(clGray, 64, 64);
      try
        // Nudge every pixel by +1 on red only.
        for Y := 0 to 63 do
        begin
          LRow := LBmp2.ScanLine[Y];
          for X := 0 to 63 do
            LRow[X].rgbRed := LRow[X].rgbRed + 1;
        end;
        Assert.IsFalse(LDiffer.IsChanged(LBmp2),
          'with threshold 1.0 a +1 nudge must be tolerated as static');
      finally
        LBmp2.Free;
      end;
    finally
      LBmp1.Free;
    end;
  finally
    LDiffer.Free;
  end;
end;

procedure TFrameDifferTests.Test_Reset_FollowedByFirstFrameChanged;
var
  LDiffer: TFrameDiffer;
  LBmp1, LBmp2: TBitmap;
begin
  // After Reset the prior signature is forgotten, so the next frame behaves
  // like a first frame (always changed) even if it is identical to the one
  // before reset.
  LDiffer := TFrameDiffer.Create(0.004);
  try
    LBmp1 := MakeSolidBitmap(clMaroon, 64, 64);
    try
      Assert.IsTrue(LDiffer.IsChanged(LBmp1), 'seed frame');
      Assert.IsFalse(LDiffer.IsChanged(LBmp1),
        'identical second frame static before reset');
      LDiffer.Reset;
      LBmp2 := MakeSolidBitmap(clMaroon, 64, 64);
      try
        Assert.IsTrue(LDiffer.IsChanged(LBmp2),
          'after reset the identical frame is treated as first (changed)');
      finally
        LBmp2.Free;
      end;
    finally
      LBmp1.Free;
    end;
  finally
    LDiffer.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TFrameDifferTests);

end.
