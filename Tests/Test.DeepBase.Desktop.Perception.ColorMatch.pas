unit Test.DeepBase.Desktop.Perception.ColorMatch;

{$POINTERMATH ON}

interface

uses
  System.SysUtils,
  System.Types,
  DUnitX.TestFramework,
  Vcl.Graphics,
  DeepBase.Desktop.Perception.ColorMatch;

type
  [TestFixture]
  TColorMatchTests = class
  private
    // Build a deterministic pixel buffer with a known pattern so tests do
    // not depend on the live screen. Layout (8x4, origin 100,50):
    //   row0: red  red  red  red  red  red  red  red
    //   row1: red  red  red  red  red  red  red  red
    //   row2: red  red  GRN  GRN  red  red  red  red   (green island at 2..3)
    //   row3: red  red  red  red  red  red  red  red
    // RED = $000000FF, GRN = $0000FF00. Used by search/multi tests.
    function BuildPatternBuffer: TPixelBuffer;
  public
    [Test]
    procedure Test_ParseHexColor_Formats;

    [Test]
    procedure Test_ParseHexColor_InvalidReturnsFalse;

    [Test]
    procedure Test_ParsePointSpec_DefaultTol;

    [Test]
    procedure Test_ParsePointSpec_NegativeOffsets;

    [Test]
    procedure Test_ParsePointSpec_InvalidReturnsFalse;

    [Test]
    procedure Test_ParseMultiSpec_ThreePoints;

    [Test]
    procedure Test_ParseMultiSpec_InvalidReturnsFalse;

    [Test]
    procedure Test_FindColor_ExactMatch;

    [Test]
    procedure Test_FindColor_ToleranceMatch;

    [Test]
    procedure Test_FindColor_NotFound;

    [Test]
    procedure Test_FindColor_EmptyBufferNoCrash;

    [Test]
    procedure Test_CheckColorAt_BoundsAndTolerance;

    [Test]
    procedure Test_FindMultiColor_AnchorWithRelativePoints;

    [Test]
    procedure Test_FindMultiColor_RelativePointFails;

    [Test]
    procedure Test_FindMultiColor_EmptySpecsNoCrash;

    [Test]
    procedure Test_PixelBuffer_PixelAtOutOfBoundsReturnsBlack;

    [Test]
    procedure Test_CaptureRegion_FullScreenNonEmpty;
  end;

implementation

const
  C_RED: TColor32 = $000000FF;
  C_GRN: TColor32 = $0000FF00;

{ TColorMatchTests }

function TColorMatchTests.BuildPatternBuffer: TPixelBuffer;
var
  X, Y: Integer;
  LRow: PColor32;
begin
  Result.Bitmap := TBitmap.Create;
  Result.Bitmap.PixelFormat := pf32bit;
  Result.Bitmap.Width := 8;
  Result.Bitmap.Height := 4;
  Result.OriginX := 100;
  Result.OriginY := 50;
  for Y := 0 to 3 do
  begin
    LRow := PColor32(Result.Bitmap.ScanLine[Y]);
    for X := 0 to 7 do
      LRow[X] := C_RED;
  end;
  // Green island at row 2, cols 2..3.
  LRow := PColor32(Result.Bitmap.ScanLine[2]);
  LRow[2] := C_GRN;
  LRow[3] := C_GRN;
end;

procedure TColorMatchTests.Test_ParseHexColor_Formats;
var
  LColor: TColor32;
begin
  Assert.IsTrue(TColorMatcher.ParseHexColor('#FF8800', LColor));
  Assert.AreEqual(TColor32($00FF8800), LColor);

  Assert.IsTrue(TColorMatcher.ParseHexColor('0xFF8800', LColor));
  Assert.AreEqual(TColor32($00FF8800), LColor);

  Assert.IsTrue(TColorMatcher.ParseHexColor('FF8800', LColor));
  Assert.AreEqual(TColor32($00FF8800), LColor);

  Assert.IsTrue(TColorMatcher.ParseHexColor('  #00ff00  ', LColor));
  Assert.AreEqual(TColor32($0000FF00), LColor);
end;

procedure TColorMatchTests.Test_ParseHexColor_InvalidReturnsFalse;
var
  LColor: TColor32;
begin
  Assert.IsFalse(TColorMatcher.ParseHexColor('', LColor));
  Assert.IsFalse(TColorMatcher.ParseHexColor('FF88', LColor));      // too short
  Assert.IsFalse(TColorMatcher.ParseHexColor('FF88000', LColor));   // too long
  Assert.IsFalse(TColorMatcher.ParseHexColor('GG8800', LColor));    // non-hex
end;

procedure TColorMatchTests.Test_ParsePointSpec_DefaultTol;
var
  DX, DY, LTol: Integer;
  LColor: TColor32;
begin
  Assert.IsTrue(TColorMatcher.ParsePointSpec('0,0,#FF8800', DX, DY, LColor, LTol));
  Assert.AreEqual(0, DX);
  Assert.AreEqual(0, DY);
  Assert.AreEqual(TColor32($00FF8800), LColor);
  Assert.AreEqual(30, LTol); // default tolerance
end;

procedure TColorMatchTests.Test_ParsePointSpec_NegativeOffsets;
var
  DX, DY, LTol: Integer;
  LColor: TColor32;
begin
  Assert.IsTrue(TColorMatcher.ParsePointSpec('-5,-10,#00FF00,15',
    DX, DY, LColor, LTol));
  Assert.AreEqual(-5, DX);
  Assert.AreEqual(-10, DY);
  Assert.AreEqual(TColor32($0000FF00), LColor);
  Assert.AreEqual(15, LTol);
end;

procedure TColorMatchTests.Test_ParsePointSpec_InvalidReturnsFalse;
var
  DX, DY, LTol: Integer;
  LColor: TColor32;
begin
  Assert.IsFalse(TColorMatcher.ParsePointSpec('0,0', DX, DY, LColor, LTol));
  Assert.IsFalse(TColorMatcher.ParsePointSpec('x,0,#FF8800', DX, DY, LColor, LTol));
  Assert.IsFalse(TColorMatcher.ParsePointSpec('0,0,GG8800', DX, DY, LColor, LTol));
end;

procedure TColorMatchTests.Test_ParseMultiSpec_ThreePoints;
var
  LSpecs: TColorPointSpecArray;
begin
  Assert.IsTrue(TColorMatcher.ParseMultiSpec(
    '0,0,#FF8800,30 | 10,0,#00FF00,30 | 5,10,#0000FF', LSpecs));
  Assert.AreEqual<Integer>(3, Length(LSpecs));
  Assert.AreEqual<Integer>(0, LSpecs[0].DX);
  Assert.AreEqual(TColor32($0000FF00), LSpecs[1].Color);
  Assert.AreEqual<Integer>(30, LSpecs[2].Tol); // default when omitted on last point
end;

procedure TColorMatchTests.Test_ParseMultiSpec_InvalidReturnsFalse;
var
  LSpecs: TColorPointSpecArray;
begin
  Assert.IsFalse(TColorMatcher.ParseMultiSpec('0,0,#FF8800 | bad', LSpecs));
  Assert.AreEqual<Integer>(0, Length(LSpecs));
end;

procedure TColorMatchTests.Test_FindColor_ExactMatch;
var
  LBuf: TPixelBuffer;
  LRes: TColorMatchResult;
begin
  LBuf := BuildPatternBuffer;
  try
    // Green at buffer-local (2,2). Origin (100,50) => screen (102,52).
    LRes := TColorMatcher.FindColor(LBuf, C_GRN, 0);
    Assert.IsTrue(LRes.Found, 'green should be found');
    Assert.AreEqual(102, LRes.MatchX);
    Assert.AreEqual(52, LRes.MatchY);
    Assert.AreEqual(Double(1.0), LRes.Similarity, 0.0001);
  finally
    LBuf.Release;
  end;
end;

procedure TColorMatchTests.Test_FindColor_ToleranceMatch;
var
  LBuf: TPixelBuffer;
  LRes: TColorMatchResult;
  LOffGreen: TColor32;
begin
  // A green slightly off (channel sum diff = 3). Tolerance 5 should match.
  LOffGreen := $0000FE00;
  LBuf := BuildPatternBuffer;
  try
    LRes := TColorMatcher.FindColor(LBuf, LOffGreen, 5);
    Assert.IsTrue(LRes.Found, 'near-green within tol 5 should match exact green');
    Assert.AreEqual(102, LRes.MatchX);
  finally
    LBuf.Release;
  end;
end;

procedure TColorMatchTests.Test_FindColor_NotFound;
var
  LBuf: TPixelBuffer;
  LRes: TColorMatchResult;
begin
  LBuf := BuildPatternBuffer;
  try
    // Pure blue, no blue in pattern. Tolerance 0.
    LRes := TColorMatcher.FindColor(LBuf, $000000FF, 0);
    // RED is $000000FF: red channel = 255 for both, so diff=0 -> this WILL
    // match red. Use a color absent from the pattern instead.
    LRes := TColorMatcher.FindColor(LBuf, $00FFFFFF, 0);
    Assert.IsFalse(LRes.Found, 'pure white absent from pattern');
  finally
    LBuf.Release;
  end;
end;

procedure TColorMatchTests.Test_FindColor_EmptyBufferNoCrash;
var
  LBuf: TPixelBuffer;
  LRes: TColorMatchResult;
begin
  LBuf := Default(TPixelBuffer);
  LRes := TColorMatcher.FindColor(LBuf, C_RED, 10);
  Assert.IsFalse(LRes.Found, 'empty buffer finds nothing without crashing');
end;

procedure TColorMatchTests.Test_CheckColorAt_BoundsAndTolerance;
var
  LBuf: TPixelBuffer;
begin
  LBuf := BuildPatternBuffer;
  try
    // (0,0) is red exact.
    Assert.IsTrue(TColorMatcher.CheckColorAt(LBuf, 0, 0, C_RED, 0));
    // (2,2) is green.
    Assert.IsTrue(TColorMatcher.CheckColorAt(LBuf, 2, 2, C_GRN, 0));
    Assert.IsFalse(TColorMatcher.CheckColorAt(LBuf, 2, 2, C_RED, 0));
    // Out of range returns False, no exception.
    Assert.IsFalse(TColorMatcher.CheckColorAt(LBuf, -1, 0, C_RED, 0));
    Assert.IsFalse(TColorMatcher.CheckColorAt(LBuf, 0, 99, C_RED, 0));
    // Tolerance: red vs near-red.
    Assert.IsTrue(TColorMatcher.CheckColorAt(LBuf, 0, 0, $000001FE, 3));
  finally
    LBuf.Release;
  end;
end;

procedure TColorMatchTests.Test_FindMultiColor_AnchorWithRelativePoints;
var
  LBuf: TPixelBuffer;
  LRes: TColorMatchResult;
  LSpecs: TColorPointSpecArray;
begin
  LBuf := BuildPatternBuffer;
  try
    // Anchor green at (2,2). Relative point (1,0) => (3,2) which is also
    // green. Both pass.
    Assert.IsTrue(TColorMatcher.ParseMultiSpec('0,0,#00FF00,0 | 1,0,#00FF00,0',
      LSpecs));
    LRes := TColorMatcher.FindMultiColor(LBuf, LSpecs);
    Assert.IsTrue(LRes.Found, 'anchor + matching relative point');
    Assert.AreEqual(102, LRes.MatchX);
    Assert.AreEqual(52, LRes.MatchY);
  finally
    LBuf.Release;
  end;
end;

procedure TColorMatchTests.Test_FindMultiColor_RelativePointFails;
var
  LBuf: TPixelBuffer;
  LRes: TColorMatchResult;
  LSpecs: TColorPointSpecArray;
begin
  LBuf := BuildPatternBuffer;
  try
    // Anchor green at (2,2). Relative point (1,0) => (3,2) green BUT we ask
    // for red there with tol 0 -> fails. Anchor at (3,2) likewise: relative
    // (1,0) => (4,2) is red, not green -> also fails. Whole match must fail.
    Assert.IsTrue(TColorMatcher.ParseMultiSpec('0,0,#00FF00,0 | 1,0,#FF0000,0',
      LSpecs));
    LRes := TColorMatcher.FindMultiColor(LBuf, LSpecs);
    Assert.IsFalse(LRes.Found, 'relative point mismatch should fail the match');
  finally
    LBuf.Release;
  end;
end;

procedure TColorMatchTests.Test_FindMultiColor_EmptySpecsNoCrash;
var
  LBuf: TPixelBuffer;
  LRes: TColorMatchResult;
begin
  LBuf := BuildPatternBuffer;
  try
    LRes := TColorMatcher.FindMultiColor(LBuf, nil);
    Assert.IsFalse(LRes.Found, 'empty specs finds nothing without crashing');
  finally
    LBuf.Release;
  end;
end;

procedure TColorMatchTests.Test_PixelBuffer_PixelAtOutOfBoundsReturnsBlack;
var
  LBuf: TPixelBuffer;
begin
  LBuf := BuildPatternBuffer;
  try
    // In-range read returns the stored color.
    Assert.AreEqual(C_GRN, LBuf.PixelAt(2, 2));
    // Out-of-range returns 0 (black), never raises.
    Assert.AreEqual(TColor32(0), LBuf.PixelAt(-1, 0));
    Assert.AreEqual(TColor32(0), LBuf.PixelAt(99, 99));
  finally
    LBuf.Release;
  end;
end;

procedure TColorMatchTests.Test_CaptureRegion_FullScreenNonEmpty;
var
  LBuf: TPixelBuffer;
begin
  // Live capture: only asserts the buffer is non-empty (width/height > 0).
  // A headless/CI box with no desktop returns invalid and the test asserts
  // the no-crash contract rather than a specific pixel.
  LBuf := TColorMatcher.CaptureRegion(Rect(0, 0, 0, 0));
  try
    if LBuf.IsValid then
    begin
      Assert.IsTrue(LBuf.Width > 0, 'full screen width > 0');
      Assert.IsTrue(LBuf.Height > 0, 'full screen height > 0');
    end
    else
      Assert.Pass('no desktop available; capture degraded to empty (allowed)');
  finally
    LBuf.Release;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TColorMatchTests);

end.
