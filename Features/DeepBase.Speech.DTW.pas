{ ============================================================================
  DeepBase.Speech.DTW
  ---------------------------------------------------------------------------
  Version     : 1.0
  Description : Dynamic Time Warping distance calculation for MFCC feature
                sequences. Used by Voiceprint for speaker similarity check.
                Sakoe-Chiba band constraint for efficiency.
  ============================================================================ }

unit DeepBase.Speech.DTW;

interface

uses
  System.SysUtils, System.Math,
  DeepBase.Speech.MFCC;

type
  TDTWResult = record
    Distance: Double;         // Normalized DTW distance
    RawDistance: Double;      // Unnormalized accumulated distance
    PathLength: Integer;      // Warping path length
  end;

  TDTW = class
  public
    /// <summary>
    /// Compute DTW distance between two MFCC feature sequences.
    /// Uses Sakoe-Chiba band constraint (bandwidth = 10% of sequence length).
    /// Distance metric: Euclidean distance between 13-dim MFCC frames.
    /// </summary>
    class function Compute(const ASeqX, ASeqY: TMFCCFeatures): TDTWResult;

    /// <summary>
    /// Euclidean distance between two MFCC frames (13 dimensions).
    /// </summary>
    class function FrameDistance(const AFrameX, AFrameY: TMFCCFrame): Double;
  end;

implementation

class function TDTW.FrameDistance(const AFrameX, AFrameY: TMFCCFrame): Double;
var
  I: Integer;
  LSum, LDiff: Double;
begin
  LSum := 0;
  for I := 0 to 12 do
  begin
    LDiff := AFrameX[I] - AFrameY[I];
    LSum := LSum + LDiff * LDiff;
  end;
  Result := Sqrt(LSum);
end;

class function TDTW.Compute(const ASeqX, ASeqY: TMFCCFeatures): TDTWResult;
var
  N, M, I, J: Integer;
  LBand: Integer;
  LCost: TArray<TArray<Double>>;
  LInf: Double;
  LDist, LMin: Double;
begin
  Result.Distance := 0;
  Result.RawDistance := 0;
  Result.PathLength := 0;

  N := Length(ASeqX);
  M := Length(ASeqY);

  if (N = 0) or (M = 0) then
  begin
    Result.Distance := 0;
    Exit;
  end;

  // Sakoe-Chiba band: 10% of max sequence length
  LBand := Max(1, Max(N, M) div 10);
  LInf := 1e30;

  // Allocate cost matrix
  SetLength(LCost, N + 1);
  for I := 0 to N do
  begin
    SetLength(LCost[I], M + 1);
    for J := 0 to M do
      LCost[I][J] := LInf;
  end;
  LCost[0][0] := 0;

  // Fill cost matrix with band constraint
  for I := 1 to N do
    for J := Max(1, I - LBand) to Min(M, I + LBand) do
    begin
      LDist := FrameDistance(ASeqX[I - 1], ASeqY[J - 1]);
      LMin := LCost[I - 1][J];       // insertion
      if LCost[I][J - 1] < LMin then
        LMin := LCost[I][J - 1];     // deletion
      if LCost[I - 1][J - 1] < LMin then
        LMin := LCost[I - 1][J - 1]; // match
      LCost[I][J] := LDist + LMin;
    end;

  Result.RawDistance := LCost[N][M];
  Result.PathLength := N + M; // approximate (exact requires backtracking)
  if Result.PathLength > 0 then
    Result.Distance := Result.RawDistance / Result.PathLength
  else
    Result.Distance := 0;
end;

end.
