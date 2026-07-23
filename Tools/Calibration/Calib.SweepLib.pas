{ ============================================================================
  Calib.Sweep - TFrameDiffer threshold sweep harness
  ---------------------------------------------------------------------------
  Purpose     : Implements docs/94 §6.3 threshold-sweep protocol for the
                DeepAxis perception layer's L0 pixel-diff gate (TFrameDiffer).
                Given a directory of recorded frame sequences (produced by
                Calib.Record.dpr), sweeps the candidate thresholds
                0.1%, 0.2%, 0.4%, 0.6%, 0.8%, 1.0% and yields the primary
                metric (LLM-call reduction proxy = static-frame skip rate) and
                the secondary metric (false-silence rate on changed samples),
                plus a markdown table fragment ready to paste into docs/94 §6.

  Mechanism   : Pure TFrameDiffer replay — loads disk PNGs into TBitmap and
                calls IsChanged directly. Does NOT go through
                TDesktopPerceptionEngine.BitmapSource injection: the sweep only
                needs "given consecutive frames -> changed? -> count", which is
                fully contained in TFrameDiffer. The BitmapSource path is for
                end-to-end CaptureScreen replay (covered by B2 tests), and
                bypassing it here avoids its FLastShot ownership constraints.

                Per sequence, the first frame seeds the differ (IsChanged is
                Always-True on a first frame, so it is excluded from counting);
                each subsequent frame's IsChanged verdict is the data point.

  Metrics (per docs/94 §6.1) -----------------------------------------------
    Primary (static samples)  : skip rate = judged-quiet frames / non-first
                                frames. Each judged-quiet frame is one saved
                                vision-provider call, so skip rate is a faithful
                                pre-provider proxy for the LLM-call reduction
                                target (≥90%).
    Secondary (changed samples): false-silence rate = judged-quiet frames /
                                non-first frames. In a changed sequence every
                                non-first frame carries real content change, so
                                any "quiet" verdict is a miss (silence). Target
                                ≤1%.
    Boundary samples          : report per-threshold change-judgment ratio only;
                                not part of the selection rule, surfaced for the
                                sensitivity curve note.

  Sample tree (produced by Calib.Record.dpr) ------------------------------
    <root>/
      static/   <seq>/  manifest.jsonl  0001.png 0002.png ...
      changed/  <seq>/  manifest.jsonl  0001.png 0002.png ...
      boundary/ <seq>/  manifest.jsonl  0001.png 0002.png ...
    A non-empty dir is treated as a sequence; frame files are the *.png children
    in lexical order. manifest.jsonl is informational and not required by the
    sweep (ordering is file-name based).
  ========================================================================== }

unit Calib.SweepLib;

{$POINTERMATH ON}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Math,
  System.StrUtils,
  System.IOUtils,
  System.Generics.Collections,
  System.Generics.Defaults,
  Vcl.Graphics,
  Vcl.Imaging.pngimage,
  DeepBase.Desktop.Perception.Engine;

type
  TSweepKind = (skStatic, skChanged, skBoundary);

  /// One metric row for one threshold, aggregated across all sequences of
  /// the matching kind. Boundary rows carry the change-ratio only.
  TSweepRow = record
    Threshold: Double;
    SkipRateStatic: Double;       // primary, skStatic only (NaN if none)
    FalseSilenceChanged: Double;   // secondary, skChanged only (NaN if none)
    ChangeRatioBoundary: Double;  // skBoundary only (NaN if none)
    SeqCountStatic: Integer;
    SeqCountChanged: Integer;
    SeqCountBoundary: Integer;
    Selected: Boolean;
  end;

  /// Aggregated sweep report across the candidate thresholds.
  TSweepReport = record
    Rows: TArray<TSweepRow>;
    /// The threshold chosen by the §6.3 selection rule (false-silence ≤1% AND
    /// highest skip rate, ties resolve to the smaller / more conservative).
    /// NaN when no candidate satisfies the false-silence gate.
    SelectedThreshold: Double;
    /// Markdown table fragment pastable into docs/94 §6's results table.
    MarkdownTable: string;
    /// Human-readable summary quoted in the console.
    Summary: string;
  end;

  /// Runs the sweep against ASampleRoot. Raises on unreadable paths.
  function SweepThresholds(const ASampleRoot: string): TSweepReport;

  /// Candidate thresholds from docs/94 §6.3, as fractions (0.001 = 0.1%).
  function CandidateThresholds: TArray<Double>;

  /// Looks up whether a directory under <root>/<kindName>/ holds a "static",
  /// "changed", or "boundary" sample set by directory name convention.
  function KindFromDirName(const ADirName: string): TSweepKind;

implementation

const
  DIR_STATIC    = 'static';
  DIR_CHANGED   = 'changed';
  DIR_BOUNDARY  = 'boundary';

{ Collects *.png files in a directory, lexical order. Empty result if none. }
function ListPngs(const ADir: string): TArray<string>;
var
  LFiles: TArray<string>;
  LF: string;
  LIdx: Integer;
begin
  Result := nil;
  if not TDirectory.Exists(ADir) then
    Exit;
  LFiles := TDirectory.GetFiles(ADir, '*.png');
  SetLength(Result, Length(LFiles));
  LIdx := 0;
  for LF in LFiles do
  begin
    Result[LIdx] := LF;
    Inc(LIdx);
  end;
  // TDirectory.GetFiles order is not guaranteed; sort for determinism.
  TArray.Sort<string>(Result, TStringComparer.Ordinal);
end;

function KindFromDirName(const ADirName: string): TSweepKind;
var
  LName: string;
begin
  LName := LowerCase(ADirName);
  if LName = DIR_STATIC then
    Result := skStatic
  else if LName = DIR_CHANGED then
    Result := skChanged
  else if LName = DIR_BOUNDARY then
    Result := skBoundary
  else
    raise EArgumentException.CreateFmt(
      'Unknown sample kind dir "%s" (expected %s/%s/%s)',
      [ADirName, DIR_STATIC, DIR_CHANGED, DIR_BOUNDARY]);
end;

function CandidateThresholds: TArray<Double>;
begin
  Result := TArray<Double>.Create(0.001, 0.002, 0.004, 0.006, 0.008, 0.010);
end;

/// Enumerates sequence directories under <root>/<kindName>/ as absolute paths.
function ListSequenceDirs(const AKindRoot: string): TArray<string>;
var
  LDirs: TArray<string>;
  LD: string;
  LIdx: Integer;
begin
  Result := nil;
  if not TDirectory.Exists(AKindRoot) then
    Exit;
  LDirs := TDirectory.GetDirectories(AKindRoot);
  SetLength(Result, Length(LDirs));
  LIdx := 0;
  for LD in LDirs do
  begin
    Result[LIdx] := LD;
    Inc(LIdx);
  end;
  TArray.Sort<string>(Result, TStringComparer.Ordinal);
end;

/// Streams every PNG in a sequence through a fresh TFrameDiffer at AThreshold,
/// counting non-first frames judged quiet ("skip"/"false-silence").
/// AQuietCount accumulates judged-quiet non-first frames; AFramesInSeq is the
/// number of non-first frames actually evaluated. First frame always seeds
/// (IsChanged returns True on a fresh differ) and is excluded from both tallies.
procedure SweepOneSequence(
  const ASequenceDir: string;
  AThreshold: Double;
  out AQuietCount: Integer;
  out AFrameCount: Integer);
var
  LDiffer: TFrameDiffer;
  LPngs: TArray<string>;
  LP: string;
  LPng: TPngImage;
  LBmp: TBitmap;
  LIsFirst: Boolean;
  LChanged: Boolean;
begin
  AQuietCount := 0;
  AFrameCount := 0;
  LPngs := ListPngs(ASequenceDir);
  if Length(LPngs) = 0 then
    Exit;

  LDiffer := TFrameDiffer.Create(AThreshold);
  try
    LIsFirst := True;
    for LP in LPngs do
    begin
      LPng := TPngImage.Create;
      try
        LPng.LoadFromFile(LP);
        LBmp := TBitmap.Create;
        try
          LBmp.Assign(LPng);
          LChanged := LDiffer.IsChanged(LBmp);
          if not LIsFirst then
          begin
            Inc(AFrameCount);
            if not LChanged then
              Inc(AQuietCount);
          end;
          LIsFirst := False;
        finally
          LBmp.Free;
        end;
      finally
        LPng.Free;
      end;
    end;
  finally
    LDiffer.Free;
  end;
end;

/// Aggregates skip rate across all static sequences at one threshold.
function SweepStaticKind(const AStaticRoot: string; AThreshold: Double): Double;
var
  LSeqs: TArray<string>;
  LSeq: string;
  LQuiet, LFrames: Integer;
  LTotalQuiet, LTotalFrames: Integer;
begin
  Result := NaN;
  LTotalQuiet := 0;
  LTotalFrames := 0;
  LSeqs := ListSequenceDirs(AStaticRoot);
  for LSeq in LSeqs do
  begin
    SweepOneSequence(LSeq, AThreshold, LQuiet, LFrames);
    Inc(LTotalQuiet, LQuiet);
    Inc(LTotalFrames, LFrames);
  end;
  if LTotalFrames > 0 then
    Result := LTotalQuiet / LTotalFrames;
end;

/// Aggregates false-silence rate across changed sequences at one threshold.
function SweepChangedKind(const AChangedRoot: string; AThreshold: Double): Double;
var
  LSeqs: TArray<string>;
  LSeq: string;
  LQuiet, LFrames: Integer;
  LTotalQuiet, LTotalFrames: Integer;
begin
  Result := NaN;
  LTotalQuiet := 0;
  LTotalFrames := 0;
  LSeqs := ListSequenceDirs(AChangedRoot);
  for LSeq in LSeqs do
  begin
    SweepOneSequence(LSeq, AThreshold, LQuiet, LFrames);
    Inc(LTotalQuiet, LQuiet);
    Inc(LTotalFrames, LFrames);
  end;
  // In a changed sequence every non-first quiet verdict is a miss (false
  // silence). Rate = quiet / non-first frames.
  if LTotalFrames > 0 then
    Result := LTotalQuiet / LTotalFrames;
end;

/// Boundary: average per-threshold change-ratio (1 - quietRate) across sequences;
/// informational only. Returns fraction of frames judged CHANGED (not quiet).
function SweepBoundaryKind(const ABoundaryRoot: string; AThreshold: Double): Double;
var
  LSeqs: TArray<string>;
  LSeq: string;
  LQuiet, LFrames: Integer;
  LTotalQuiet, LTotalFrames: Integer;
begin
  Result := NaN;
  LTotalQuiet := 0;
  LTotalFrames := 0;
  LSeqs := ListSequenceDirs(ABoundaryRoot);
  for LSeq in LSeqs do
  begin
    SweepOneSequence(LSeq, AThreshold, LQuiet, LFrames);
    Inc(LTotalQuiet, LQuiet);
    Inc(LTotalFrames, LFrames);
  end;
  if LTotalFrames > 0 then
    Result := 1.0 - (LTotalQuiet / LTotalFrames);
end;

function CountSequences(const ARoot: string): Integer;
var
  LDirs: TArray<string>;
begin
  if not TDirectory.Exists(ARoot) then
    Exit(0);
  LDirs := TDirectory.GetDirectories(ARoot);
  Result := Length(LDirs);
end;

function PctStr(const AValue: Double): string;
begin
  if IsNan(AValue) then
    Result := 'n/a'
  else
    Result := Format('%.1f%%', [AValue * 100]);
end;

/// §6.3 selection rule: among thresholds with false-silence ≤1%, pick the
/// highest skip rate; tie-break to the smaller (more conservative) threshold.
/// Returns NaN when no candidate passes the ≤1% gate.
function SelectThreshold(const ARows: TArray<TSweepRow>): Double;
var
  LR: TSweepRow;
  LBestSkip, LBestThresh: Double;
  LHave: Boolean;
begin
  Result := NaN;
  LHave := False;
  LBestSkip := 0;
  LBestThresh := 0;
  for LR in ARows do
  begin
    if IsNan(LR.FalseSilenceChanged) then
      Continue;
    if LR.FalseSilenceChanged > 0.01 then
      Continue;
    // Passes the gate. Prefer higher skip rate; tie-break lower threshold.
    if (not LHave) or (LR.SkipRateStatic > LBestSkip + 1e-9) or
       ((Abs(LR.SkipRateStatic - LBestSkip) <= 1e-9) and (LR.Threshold < LBestThresh)) then
    begin
      LHave := True;
      LBestSkip := LR.SkipRateStatic;
      LBestThresh := LR.Threshold;
    end;
  end;
  if LHave then
    Result := LBestThresh
  else
    Result := NaN;
end;

function SweepThresholds(const ASampleRoot: string): TSweepReport;
var
  LRoot: string;
  LStaticRoot, LChangedRoot, LBoundaryRoot: string;
  LCands: TArray<Double>;
  Lt: Integer;
  LRow: TSweepRow;
  LRows: TArray<TSweepRow>;
  LSelected: Double;
  LSb: TStringBuilder;
  LSelMetrics: TSweepRow;
  LFoundSel: Boolean;
const
  CPrimaryFmt = '**选定阈值：%.3f**（LLM 削减率代理 %s，误静默率 %s）';
begin
  if not TDirectory.Exists(ASampleRoot) then
    raise EArgumentException.CreateFmt('Sample root not found: %s', [ASampleRoot]);

  LRoot := TPath.GetFullPath(ASampleRoot);
  LStaticRoot   := TPath.Combine(LRoot, DIR_STATIC);
  LChangedRoot  := TPath.Combine(LRoot, DIR_CHANGED);
  LBoundaryRoot := TPath.Combine(LRoot, DIR_BOUNDARY);

  LCands := CandidateThresholds;
  SetLength(LRows, Length(LCands));

  for Lt := 0 to High(LCands) do
  begin
    LRow := Default(TSweepRow);
    LRow.Threshold := LCands[Lt];
    LRow.SkipRateStatic       := SweepStaticKind(LStaticRoot, LCands[Lt]);
    LRow.FalseSilenceChanged  := SweepChangedKind(LChangedRoot, LCands[Lt]);
    LRow.ChangeRatioBoundary := SweepBoundaryKind(LBoundaryRoot, LCands[Lt]);
    LRow.SeqCountStatic   := CountSequences(LStaticRoot);
    LRow.SeqCountChanged  := CountSequences(LChangedRoot);
    LRow.SeqCountBoundary := CountSequences(LBoundaryRoot);
    LRow.Selected := False;
    LRows[Lt] := LRow;
  end;

  LSelected := SelectThreshold(LRows);
  for Lt := 0 to High(LRows) do
    LRows[Lt].Selected := Abs(LRows[Lt].Threshold - LSelected) < 1e-12;

  Result.Rows := LRows;
  Result.SelectedThreshold := LSelected;

  // Markdown table for docs/94 §6.
  LSb := TStringBuilder.Create;
  try
    LSb.AppendLine('| 阈值候选 | LLM 削减率（静态样本） | 误静默率（变化样本） | 选定? |');
    LSb.AppendLine('|---|---|---|---|');
    for Lt := 0 to High(LRows) do
      LSb.AppendLine(Format('| %s | %s | %s | %s |',
        [PctStr(LRows[Lt].Threshold),
         PctStr(LRows[Lt].SkipRateStatic),
         PctStr(LRows[Lt].FalseSilenceChanged),
         IfThen(LRows[Lt].Selected, '✓', '')]));
    if not IsNan(LSelected) then
    begin
      LFoundSel := False;
      for Lt := 0 to High(LRows) do
        if LRows[Lt].Selected then
        begin
          LSb.AppendLine('');
          LSb.AppendLine(Format(CPrimaryFmt,
            [LSelected,
             PctStr(LRows[Lt].SkipRateStatic),
             PctStr(LRows[Lt].FalseSilenceChanged)]));
          LFoundSel := True;
          Break;
        end;
      if not LFoundSel then
      begin
        LSb.AppendLine('');
        LSb.AppendLine('**选定阈值：TBD**（候选匹配异常）');
      end;
    end
    else
    begin
      LSb.AppendLine('');
      LSb.AppendLine('**选定阈值：TBD**（无一候选在误静默率 ≤1%，需补样本或下调宽容度）');
    end;
    Result.MarkdownTable := LSb.ToString;
  finally
    LSb.Free;
  end;

  // Console summary.
  if not IsNan(LSelected) then
  begin
    LSelMetrics := Default(TSweepRow);
    for Lt := 0 to High(LRows) do
      if LRows[Lt].Selected then
      begin
        LSelMetrics := LRows[Lt];
        Break;
      end;
    Result.Summary := Format('Selected threshold %.3f (skip %s, false-silence %s).',
      [LSelected,
       PctStr(LSelMetrics.SkipRateStatic),
       PctStr(LSelMetrics.FalseSilenceChanged)]);
  end
  else
    Result.Summary := 'No threshold passed the false-silence <=1% gate (TBD).';
end;

end.
