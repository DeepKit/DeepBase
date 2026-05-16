{ ============================================================================
  DeepBase.Speech.FBank
  ---------------------------------------------------------------------------
  Version     : 1.0
  Description : 80-dim FBank (log-Mel energy) feature extraction.
                No external DLL dependencies. Uses Radix-2 FFT (padded).
                Input: 16 kHz PCM16 mono audio.
                Output: TArray<TArray<Single>> — [frames][80] log-Mel energies.
  Parameters  : Frame 25ms / Hop 10ms / Hamming window / 80 Mel filters
  Note        : Reuses the Hamming + Mel filter pattern from MFCC.pas but
                skips DCT and outputs raw 80-dim log-Mel energies.
  ============================================================================ }

unit DeepBase.Speech.FBank;

interface

uses
  System.SysUtils, System.Math;

type
  TFBankExtractor = class
  private
    FSampleRate: Integer;
    FFrameSize: Integer;
    FHopSize: Integer;
    FNumFilters: Integer;
    FFFTSize: Integer;
    FWindow: TArray<Single>;
    FMelFilters: TArray<TArray<Single>>;
    procedure InitWindow;
    procedure InitMelFilters;
    function HzToMel(AHz: Single): Single;
    function MelToHz(AMel: Single): Single;
    procedure Radix2FFT(var AReal, AImag: TArray<Single>; AN: Integer);
  public
    constructor Create(ASampleRate: Integer = 16000; ANumFilters: Integer = 80);

    function Extract(const APCM16: TBytes): TArray<TArray<Single>>;

    property SampleRate: Integer read FSampleRate;
    property FrameSize: Integer read FFrameSize;
    property HopSize: Integer read FHopSize;
    property NumFilters: Integer read FNumFilters;
    property FFTSize: Integer read FFFTSize;
  end;

implementation

{ --- TFBankExtractor ----------------------------------------------------- }

constructor TFBankExtractor.Create(ASampleRate: Integer; ANumFilters: Integer);
begin
  inherited Create;
  FSampleRate := ASampleRate;
  FFrameSize := Round(0.025 * ASampleRate);
  FHopSize := Round(0.010 * ASampleRate);
  FNumFilters := ANumFilters;
  // Pad to next power of 2 for radix-2 FFT
  FFFTSize := 1;
  while FFFTSize < FFrameSize do
    FFFTSize := FFFTSize shl 1;
  InitWindow;
  InitMelFilters;
end;

function TFBankExtractor.HzToMel(AHz: Single): Single;
begin
  Result := 2595.0 * Log10(1.0 + AHz / 700.0);
end;

function TFBankExtractor.MelToHz(AMel: Single): Single;
begin
  Result := 700.0 * (Power(10.0, AMel / 2595.0) - 1.0);
end;

procedure TFBankExtractor.InitWindow;
var
  I: Integer;
begin
  SetLength(FWindow, FFrameSize);
  for I := 0 to FFrameSize - 1 do
    FWindow[I] := 0.54 - 0.46 * Cos(2.0 * Pi * I / (FFrameSize - 1));
end;

procedure TFBankExtractor.InitMelFilters;
var
  LMelLow, LMelHigh: Single;
  LMelPoints: TArray<Single>;
  LBinPoints: TArray<Integer>;
  I, J, K: Integer;
  LFreqRes: Single;
begin
  LMelLow := HzToMel(0);
  LMelHigh := HzToMel(FSampleRate / 2.0);

  SetLength(LMelPoints, FNumFilters + 2);
  for I := 0 to FNumFilters + 1 do
    LMelPoints[I] := LMelLow + I * (LMelHigh - LMelLow) / (FNumFilters + 1);

  SetLength(LBinPoints, FNumFilters + 2);
  LFreqRes := FSampleRate / FFFTSize;
  for I := 0 to FNumFilters + 1 do
    LBinPoints[I] := Round(MelToHz(LMelPoints[I]) / LFreqRes);

  SetLength(FMelFilters, FNumFilters);
  for I := 0 to FNumFilters - 1 do
  begin
    SetLength(FMelFilters[I], FFFTSize div 2 + 1);
    for J := 0 to Length(FMelFilters[I]) - 1 do
    begin
      if (J >= LBinPoints[I]) and (J <= LBinPoints[I + 1]) then
      begin
        K := LBinPoints[I + 1] - LBinPoints[I];
        if K > 0 then
          FMelFilters[I][J] := (J - LBinPoints[I]) / K
        else
          FMelFilters[I][J] := 0;
      end
      else if (J >= LBinPoints[I + 1]) and (J <= LBinPoints[I + 2]) then
      begin
        K := LBinPoints[I + 2] - LBinPoints[I + 1];
        if K > 0 then
          FMelFilters[I][J] := (LBinPoints[I + 2] - J) / K
        else
          FMelFilters[I][J] := 0;
      end
      else
        FMelFilters[I][J] := 0;
    end;
  end;
end;

procedure TFBankExtractor.Radix2FFT(var AReal, AImag: TArray<Single>;
  AN: Integer);
var
  I, J, K, M, LHalf: Integer;
  LAngle, Lcos, Lsin, LTr, Lti: Single;
  LTemp: Single;
begin
  // Bit-reversal permutation
  J := 0;
  for I := 0 to AN - 2 do
  begin
    if I < J then
    begin
      LTemp := AReal[I]; AReal[I] := AReal[J]; AReal[J] := LTemp;
      LTemp := AImag[I]; AImag[I] := AImag[J]; AImag[J] := LTemp;
    end;
    K := AN shr 1;
    while K <= J do
    begin
      J := J - K;
      K := K shr 1;
    end;
    J := J + K;
  end;

  // Cooley-Tukey iterative FFT
  M := 2;
  while M <= AN do
  begin
    LHalf := M shr 1;
    LAngle := -2.0 * Pi / M;
    for K := 0 to LHalf - 1 do
    begin
      Lcos := Cos(LAngle * K);
      Lsin := Sin(LAngle * K);
      for I := K to AN - 1 do
      begin
        if I + LHalf >= AN then Break;
        // Process pairs (I, I+LHalf) but avoid duplicates
        if (I mod M) = K then
        begin
          LTr := Lcos * AReal[I + LHalf] - Lsin * AImag[I + LHalf];
          Lti := Lsin * AReal[I + LHalf] + Lcos * AImag[I + LHalf];
          AReal[I + LHalf] := AReal[I] - LTr;
          AImag[I + LHalf] := AImag[I] - Lti;
          AReal[I] := AReal[I] + LTr;
          AImag[I] := AImag[I] + Lti;
        end;
      end;
    end;
    M := M shl 1;
  end;
end;

function TFBankExtractor.Extract(
  const APCM16: TBytes): TArray<TArray<Single>>;
var
  LSamples: TArray<Single>;
  LNumSamples, LNumFrames, I, J, LStart: Integer;
  LReal, LImag: TArray<Single>;
  LPower: TArray<Single>;
  LFrame: TArray<Single>;
  LMelEnergies: TArray<Single>;
  LSum: Single;
begin
  // Convert PCM16 to float [-1, 1]
  LNumSamples := Length(APCM16) div 2;
  SetLength(LSamples, LNumSamples);
  for I := 0 to LNumSamples - 1 do
    LSamples[I] := SmallInt(APCM16[I * 2] or (APCM16[I * 2 + 1] shl 8)) / 32768.0;

  if LNumSamples < FFrameSize then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  LNumFrames := (LNumSamples - FFrameSize) div FHopSize + 1;
  SetLength(Result, LNumFrames);

  for I := 0 to LNumFrames - 1 do
  begin
    LStart := I * FHopSize;

    // Apply window and zero-pad to FFT size
    SetLength(LReal, FFFTSize);
    SetLength(LImag, FFFTSize);
    for J := 0 to FFFTSize - 1 do
    begin
      LImag[J] := 0;
      if J < FFrameSize then
        LReal[J] := LSamples[LStart + J] * FWindow[J]
      else
        LReal[J] := 0;
    end;

    Radix2FFT(LReal, LImag, FFFTSize);

    // Power spectrum (N/2 + 1 bins)
    SetLength(LPower, FFFTSize div 2 + 1);
    for J := 0 to FFFTSize div 2 do
      LPower[J] := (LReal[J] * LReal[J] + LImag[J] * LImag[J]) / FFFTSize;

    // Apply Mel filter bank → log energies
    SetLength(LMelEnergies, FNumFilters);
    for J := 0 to FNumFilters - 1 do
    begin
      LSum := 0;
      for var K := 0 to Min(Length(LPower), Length(FMelFilters[J])) - 1 do
        LSum := LSum + LPower[K] * FMelFilters[J][K];
      if LSum < 1e-10 then LSum := 1e-10;
      LMelEnergies[J] := Ln(LSum);
    end;

    Result[I] := LMelEnergies;
  end;
end;

end.
