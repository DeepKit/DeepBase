{ ============================================================================
  DeepBase.Speech.MFCC
  ---------------------------------------------------------------------------
  Version     : 1.0
  Description : Pure Delphi MFCC (Mel-Frequency Cepstral Coefficients)
                feature extraction. No external DLL dependencies.
                Input: 16 kHz PCM16 mono audio.
                Output: 13 MFCC coefficients per frame (+ delta + delta-delta = 39 dim).
  Parameters  : Frame 25ms / Hop 10ms / Hamming window / 40 Mel filters / 13 coeffs
  ============================================================================ }

unit DeepBase.Speech.MFCC;

interface

uses
  System.SysUtils, System.Math;

type
  TMFCCFrame = array[0..12] of Single;  // 13 coefficients
  TMFCCFeatures = TArray<TMFCCFrame>;

  TMFCCExtractor = class
  private
    FSampleRate: Integer;
    FFrameSize: Integer;   // samples per frame (25ms @ 16kHz = 400)
    FHopSize: Integer;     // samples per hop (10ms @ 16kHz = 160)
    FFFTSize: Integer;     // next power of 2 >= FFrameSize (e.g. 512)
    FNumFilters: Integer;  // 40 Mel filters
    FNumCoeffs: Integer;   // 13 MFCC coefficients
    FHammingWindow: TArray<Single>;
    FMelFilterBank: TArray<TArray<Single>>;
    procedure InitHammingWindow;
    procedure InitMelFilterBank;
    function HzToMel(AHz: Single): Single;
    function MelToHz(AMel: Single): Single;
    procedure ApplyHamming(var AFrame: TArray<Single>);
    function ComputeFFT(const AFrame: TArray<Single>): TArray<Single>;
    function ApplyMelFilters(const APowerSpectrum: TArray<Single>): TArray<Single>;
    function ApplyDCT(const ALogMelEnergies: TArray<Single>): TMFCCFrame;
  public
    /// <summary>
    /// In-place iterative radix-2 Cooley-Tukey FFT. Both arrays must have
    /// the same power-of-2 length. Exposed as public for testing and for
    /// callers that need a frequency transform without the full MFCC
    /// pipeline.
    /// </summary>
    class procedure RadixFFT(var ARealPart, AImagPart: TArray<Single>); static;

    /// <summary>Smallest power of 2 >= AValue (returns 1 for AValue <= 1).</summary>
    class function NextPow2(AValue: Integer): Integer; static;
    constructor Create(ASampleRate: Integer = 16000);

    /// <summary>
    /// Extract MFCC features from PCM16 audio data.
    /// Input: raw PCM16 bytes (16-bit signed, mono, 16kHz).
    /// Output: array of 13-dim MFCC frames.
    /// </summary>
    function Extract(const APCM16: TBytes): TMFCCFeatures;

    /// <summary>
    /// Compute mean vector across all frames (for enrollment).
    /// </summary>
    class function MeanVector(const AFeatures: TMFCCFeatures): TMFCCFrame;

    property SampleRate: Integer read FSampleRate;
    property FrameSize: Integer read FFrameSize;
    property HopSize: Integer read FHopSize;
    property FFTSize: Integer read FFFTSize;
  end;

implementation

constructor TMFCCExtractor.Create(ASampleRate: Integer);
begin
  inherited Create;
  FSampleRate := ASampleRate;
  FFrameSize := Round(0.025 * ASampleRate);  // 25ms
  FHopSize := Round(0.010 * ASampleRate);    // 10ms
  FFFTSize := NextPow2(FFrameSize);          // pad up to next power of 2
  FNumFilters := 40;
  FNumCoeffs := 13;
  InitHammingWindow;
  InitMelFilterBank;
end;

function TMFCCExtractor.HzToMel(AHz: Single): Single;
begin
  Result := 2595.0 * Log10(1.0 + AHz / 700.0);
end;

function TMFCCExtractor.MelToHz(AMel: Single): Single;
begin
  Result := 700.0 * (Power(10.0, AMel / 2595.0) - 1.0);
end;

procedure TMFCCExtractor.InitHammingWindow;
var
  I: Integer;
begin
  SetLength(FHammingWindow, FFrameSize);
  for I := 0 to FFrameSize - 1 do
    FHammingWindow[I] := 0.54 - 0.46 * Cos(2.0 * Pi * I / (FFrameSize - 1));
end;

procedure TMFCCExtractor.InitMelFilterBank;
var
  LMelLow, LMelHigh: Single;
  LMelPoints: TArray<Single>;
  LBinPoints: TArray<Integer>;
  LFFTSize, I, J, K: Integer;
  LFreqRes: Single;
begin
  // FFT size is power-of-2 padded frame size; bin spacing must match the
  // padded transform so that ComputeFFT output indexes line up with the
  // triangular filter bank.
  LFFTSize := FFFTSize;
  LMelLow := HzToMel(0);
  LMelHigh := HzToMel(FSampleRate / 2.0);

  // Create mel-spaced points
  SetLength(LMelPoints, FNumFilters + 2);
  for I := 0 to FNumFilters + 1 do
    LMelPoints[I] := LMelLow + I * (LMelHigh - LMelLow) / (FNumFilters + 1);

  // Convert to FFT bin indices
  SetLength(LBinPoints, FNumFilters + 2);
  LFreqRes := FSampleRate / LFFTSize;
  for I := 0 to FNumFilters + 1 do
    LBinPoints[I] := Round(MelToHz(LMelPoints[I]) / LFreqRes);

  // Build triangular filter bank
  SetLength(FMelFilterBank, FNumFilters);
  for I := 0 to FNumFilters - 1 do
  begin
    SetLength(FMelFilterBank[I], LFFTSize div 2 + 1);
    for J := 0 to Length(FMelFilterBank[I]) - 1 do
    begin
      if (J >= LBinPoints[I]) and (J <= LBinPoints[I + 1]) then
      begin
        K := LBinPoints[I + 1] - LBinPoints[I];
        if K > 0 then
          FMelFilterBank[I][J] := (J - LBinPoints[I]) / K
        else
          FMelFilterBank[I][J] := 0;
      end
      else if (J >= LBinPoints[I + 1]) and (J <= LBinPoints[I + 2]) then
      begin
        K := LBinPoints[I + 2] - LBinPoints[I + 1];
        if K > 0 then
          FMelFilterBank[I][J] := (LBinPoints[I + 2] - J) / K
        else
          FMelFilterBank[I][J] := 0;
      end
      else
        FMelFilterBank[I][J] := 0;
    end;
  end;
end;

procedure TMFCCExtractor.ApplyHamming(var AFrame: TArray<Single>);
var
  I: Integer;
begin
  for I := 0 to Min(Length(AFrame), FFrameSize) - 1 do
    AFrame[I] := AFrame[I] * FHammingWindow[I];
end;

function TMFCCExtractor.ComputeFFT(const AFrame: TArray<Single>): TArray<Single>;
var
  LReal, LImag: TArray<Single>;
  I, N, Half: Integer;
begin
  // Iterative radix-2 Cooley-Tukey FFT. Input frame is zero-padded up to
  // FFFTSize (next power of 2 >= FFrameSize). Output is the power spectrum
  // normalized by N to match the previous DFT scaling.
  N := FFFTSize;
  Half := N div 2 + 1;

  SetLength(LReal, N);
  SetLength(LImag, N);
  var LCount := Min(Length(AFrame), N);
  for I := 0 to LCount - 1 do
    LReal[I] := AFrame[I];
  // remaining indices already zero-initialized by SetLength

  RadixFFT(LReal, LImag);

  SetLength(Result, Half);
  for I := 0 to Half - 1 do
    Result[I] := (LReal[I] * LReal[I] + LImag[I] * LImag[I]) / N;
end;

class function TMFCCExtractor.NextPow2(AValue: Integer): Integer;
begin
  Result := 1;
  while Result < AValue do
    Result := Result shl 1;
end;

class procedure TMFCCExtractor.RadixFFT(var ARealPart, AImagPart: TArray<Single>);
var
  N, I, J, K, M, MHalf: Integer;
  LTmpReal, LTmpImag: Single;
  LWReal, LWImag, LWmReal, LWmImag: Double;
  LTReal, LTImag, LUReal, LUImag, LNewWReal: Double;
begin
  N := Length(ARealPart);
  if (N <= 1) or (Length(AImagPart) <> N) then
    Exit;

  // Bit-reversal permutation
  J := 0;
  for I := 1 to N - 1 do
  begin
    K := N shr 1;
    while (K > 0) and (J >= K) do
    begin
      J := J - K;
      K := K shr 1;
    end;
    J := J + K;
    if I < J then
    begin
      LTmpReal := ARealPart[I];
      ARealPart[I] := ARealPart[J];
      ARealPart[J] := LTmpReal;
      LTmpImag := AImagPart[I];
      AImagPart[I] := AImagPart[J];
      AImagPart[J] := LTmpImag;
    end;
  end;

  // Butterflies; outer loop doubles the stage size each iteration
  M := 1;
  while M < N do
  begin
    MHalf := M;
    M := M shl 1;
    LWmReal := Cos(-2.0 * Pi / M);
    LWmImag := Sin(-2.0 * Pi / M);
    K := 0;
    while K < N do
    begin
      LWReal := 1.0;
      LWImag := 0.0;
      for J := 0 to MHalf - 1 do
      begin
        LTReal := LWReal * ARealPart[K + J + MHalf]
                - LWImag * AImagPart[K + J + MHalf];
        LTImag := LWReal * AImagPart[K + J + MHalf]
                + LWImag * ARealPart[K + J + MHalf];
        LUReal := ARealPart[K + J];
        LUImag := AImagPart[K + J];
        ARealPart[K + J] := LUReal + LTReal;
        AImagPart[K + J] := LUImag + LTImag;
        ARealPart[K + J + MHalf] := LUReal - LTReal;
        AImagPart[K + J + MHalf] := LUImag - LTImag;
        // advance twiddle factor: W := W * Wm
        LNewWReal := LWReal * LWmReal - LWImag * LWmImag;
        LWImag    := LWReal * LWmImag + LWImag * LWmReal;
        LWReal    := LNewWReal;
      end;
      Inc(K, M);
    end;
  end;
end;

function TMFCCExtractor.ApplyMelFilters(const APowerSpectrum: TArray<Single>): TArray<Single>;
var
  I, J: Integer;
  LSum: Single;
begin
  SetLength(Result, FNumFilters);
  for I := 0 to FNumFilters - 1 do
  begin
    LSum := 0;
    for J := 0 to Min(Length(APowerSpectrum), Length(FMelFilterBank[I])) - 1 do
      LSum := LSum + APowerSpectrum[J] * FMelFilterBank[I][J];
    // Log energy (floor to avoid log(0))
    if LSum < 1e-10 then LSum := 1e-10;
    Result[I] := Ln(LSum);
  end;
end;

function TMFCCExtractor.ApplyDCT(const ALogMelEnergies: TArray<Single>): TMFCCFrame;
var
  I, J: Integer;
  LSum: Single;
begin
  // Type-II DCT
  for I := 0 to FNumCoeffs - 1 do
  begin
    LSum := 0;
    for J := 0 to FNumFilters - 1 do
      LSum := LSum + ALogMelEnergies[J] * Cos(Pi * I * (J + 0.5) / FNumFilters);
    Result[I] := LSum;
  end;
end;

function TMFCCExtractor.Extract(const APCM16: TBytes): TMFCCFeatures;
var
  LSamples: TArray<Single>;
  LNumSamples, LNumFrames, I, J, LStart: Integer;
  LFrame: TArray<Single>;
  LPower, LMelEnergies: TArray<Single>;
  LFrameList: TArray<TMFCCFrame>;
begin
  // Convert PCM16 to float [-1, 1]
  LNumSamples := Length(APCM16) div 2;
  SetLength(LSamples, LNumSamples);
  for I := 0 to LNumSamples - 1 do
    LSamples[I] := SmallInt(APCM16[I * 2] or (APCM16[I * 2 + 1] shl 8)) / 32768.0;

  // Calculate number of frames
  if LNumSamples < FFrameSize then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  LNumFrames := (LNumSamples - FFrameSize) div FHopSize + 1;
  SetLength(LFrameList, LNumFrames);

  // Process each frame
  for I := 0 to LNumFrames - 1 do
  begin
    LStart := I * FHopSize;
    SetLength(LFrame, FFrameSize);
    for J := 0 to FFrameSize - 1 do
      LFrame[J] := LSamples[LStart + J];

    ApplyHamming(LFrame);
    LPower := ComputeFFT(LFrame);
    LMelEnergies := ApplyMelFilters(LPower);
    LFrameList[I] := ApplyDCT(LMelEnergies);
  end;

  Result := LFrameList;
end;

class function TMFCCExtractor.MeanVector(const AFeatures: TMFCCFeatures): TMFCCFrame;
var
  I, J: Integer;
begin
  for J := 0 to 12 do
    Result[J] := 0;

  if Length(AFeatures) = 0 then Exit;

  for I := 0 to Length(AFeatures) - 1 do
    for J := 0 to 12 do
      Result[J] := Result[J] + AFeatures[I][J];

  for J := 0 to 12 do
    Result[J] := Result[J] / Length(AFeatures);
end;

end.
