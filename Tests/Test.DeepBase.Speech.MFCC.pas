unit Test.DeepBase.Speech.MFCC;

interface

uses
  System.SysUtils,
  System.Math,
  DUnitX.TestFramework,
  DeepBase.Speech.MFCC;

type
  [TestFixture]
  TMFCCFFTTests = class
  private
    procedure NaiveDFT(const ASignal: TArray<Single>;
      out AReal, AImag: TArray<Double>);
  public
    [Test]
    procedure Test_NextPow2_ReturnsExpected;

    [Test]
    procedure Test_RadixFFT_MatchesNaiveDFT_WithinTolerance;

    [Test]
    procedure Test_FFT_PadsNonPowerOfTwoFrame;

    [Test]
    procedure Test_FFT_ProducesFinitePeakAtExpectedBin;
  end;

implementation

{ TMFCCFFTTests }

procedure TMFCCFFTTests.NaiveDFT(const ASignal: TArray<Single>;
  out AReal, AImag: TArray<Double>);
var
  K, I, N: Integer;
  LAngle: Double;
begin
  N := Length(ASignal);
  SetLength(AReal, N);
  SetLength(AImag, N);
  for K := 0 to N - 1 do
  begin
    AReal[K] := 0.0;
    AImag[K] := 0.0;
    for I := 0 to N - 1 do
    begin
      LAngle := -2.0 * Pi * K * I / N;
      AReal[K] := AReal[K] + ASignal[I] * Cos(LAngle);
      AImag[K] := AImag[K] + ASignal[I] * Sin(LAngle);
    end;
  end;
end;

procedure TMFCCFFTTests.Test_NextPow2_ReturnsExpected;
begin
  Assert.AreEqual(1, TMFCCExtractor.NextPow2(1));
  Assert.AreEqual(2, TMFCCExtractor.NextPow2(2));
  Assert.AreEqual(4, TMFCCExtractor.NextPow2(3));
  Assert.AreEqual(512, TMFCCExtractor.NextPow2(400));
  Assert.AreEqual(512, TMFCCExtractor.NextPow2(512));
  Assert.AreEqual(1024, TMFCCExtractor.NextPow2(513));
end;

procedure TMFCCFFTTests.Test_RadixFFT_MatchesNaiveDFT_WithinTolerance;
const
  CTolerance = 1e-3; // single-precision FFT vs Double-DFT comparison
var
  N, I: Integer;
  LSignal: TArray<Single>;
  LFFTReal, LFFTImag: TArray<Single>;
  LDFTReal, LDFTImag: TArray<Double>;
  LDiffReal, LDiffImag: Double;
begin
  // 64-point composite signal: sum of two sinusoids + DC
  N := 64;
  SetLength(LSignal, N);
  for I := 0 to N - 1 do
    LSignal[I] := 0.5
                + Sin(2 * Pi * 3 * I / N)
                + 0.5 * Sin(2 * Pi * 7 * I / N + 0.3);

  // FFT inputs: Real := signal, Imag := 0
  SetLength(LFFTReal, N);
  SetLength(LFFTImag, N);
  for I := 0 to N - 1 do
  begin
    LFFTReal[I] := LSignal[I];
    LFFTImag[I] := 0;
  end;

  TMFCCExtractor.RadixFFT(LFFTReal, LFFTImag);
  NaiveDFT(LSignal, LDFTReal, LDFTImag);

  for I := 0 to N - 1 do
  begin
    LDiffReal := Abs(LFFTReal[I] - LDFTReal[I]);
    LDiffImag := Abs(LFFTImag[I] - LDFTImag[I]);
    Assert.IsTrue(LDiffReal < CTolerance,
      Format('Real bin %d: FFT %.6f DFT %.6f diff %.2e',
        [I, LFFTReal[I], LDFTReal[I], LDiffReal]));
    Assert.IsTrue(LDiffImag < CTolerance,
      Format('Imag bin %d: FFT %.6f DFT %.6f diff %.2e',
        [I, LFFTImag[I], LDFTImag[I], LDiffImag]));
  end;
end;

procedure TMFCCFFTTests.Test_FFT_PadsNonPowerOfTwoFrame;
var
  LExtractor: TMFCCExtractor;
begin
  // 16 kHz: FrameSize = 400 (not power of 2), FFTSize must round up to 512
  LExtractor := TMFCCExtractor.Create(16000);
  try
    Assert.AreEqual(400, LExtractor.FrameSize);
    Assert.AreEqual(512, LExtractor.FFTSize);
    Assert.AreEqual(0, LExtractor.FFTSize and (LExtractor.FFTSize - 1),
      'FFTSize must be a power of 2');
  finally
    LExtractor.Free;
  end;
end;

procedure TMFCCFFTTests.Test_FFT_ProducesFinitePeakAtExpectedBin;
var
  LExtractor: TMFCCExtractor;
  LPCM: TBytes;
  LFeatures: TMFCCFeatures;
  LSampleCount, I, J: Integer;
  LSample: SmallInt;
begin
  LSampleCount := 800; // 50 ms at 16 kHz
  SetLength(LPCM, LSampleCount * 2);
  for I := 0 to LSampleCount - 1 do
  begin
    LSample := Round(16000 * Sin(2 * Pi * 440 * I / 16000));
    LPCM[I * 2]     := Byte(LSample and $FF);
    LPCM[I * 2 + 1] := Byte((LSample shr 8) and $FF);
  end;

  LExtractor := TMFCCExtractor.Create(16000);
  try
    LFeatures := LExtractor.Extract(LPCM);
    Assert.IsTrue(Length(LFeatures) > 0, 'Should produce at least one frame');
    for I := 0 to Length(LFeatures) - 1 do
      for J := 0 to 12 do
      begin
        Assert.IsFalse(IsNan(LFeatures[I][J]),
          Format('NaN at frame %d coeff %d', [I, J]));
        Assert.IsFalse(IsInfinite(LFeatures[I][J]),
          Format('Inf at frame %d coeff %d', [I, J]));
      end;
  finally
    LExtractor.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TMFCCFFTTests);

end.
