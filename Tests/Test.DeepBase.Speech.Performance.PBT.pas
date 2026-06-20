{ ============================================================================
  Test.DeepBase.Speech.Performance.PBT - PBT for the SpeechService
  incremental-VAD performance refactor.

  Properties covered (deepbase-round2-fixes):
    Property 41: For any audio buffer, polling ShouldAutoStop with
                 incremental cursor advance (Round-2 fix, Req 15.6) is
                 algorithmically equivalent to running the same VAD
                 from offset 0 every poll. The cursor:
                   (a) only ever moves forward,
                   (b) advances in integer multiples of the VAD frame
                       size,
                   (c) the FIRST poll that would have fired a stop
                       under full re-processing also fires under
                       incremental processing,
                   (d) once the incremental cursor passes a frame, that
                       frame is never reconsidered.

  Each property runs >= 100 iterations.

  Notes on observability:
    - TDeepBaseSpeechService.ShouldAutoStop sits on top of a real
      WinMM capture device (FCapture) and a TVAD instance. Standing up
      the full fixture from a CI test is heavy (it requires a working
      audio backend) and would make the property test fragile. The
      task spec explicitly allows degrading to a minimal-logic test
      that pins the cursor-advance invariants. We do that here:
        * `IncrementalProcess` is a faithful, side-effect-free port of
          the production loop body (cursor + frame-aligned VAD feed),
        * `FullProcess` re-runs the same VAD over [0..total) every
          poll (the unfixed behaviour),
        * a TVADStub plays back a predetermined frame-result tape so
          the comparison is deterministic.
      The two implementations must arrive at the same final auto-stop
      decision and the same number of consumed frames.
  ============================================================================ }

unit Test.DeepBase.Speech.Performance.PBT;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Math,
  DUnitX.TestFramework;

type
  /// <summary>
  /// Deterministic VAD stand-in. Each call to ProcessFrame returns the
  /// next entry in FTape; reaching the end returns False forever. Tape
  /// values represent the boolean ProcessFrame would have returned for
  /// a given frame (True = silence threshold reached -> auto-stop).
  /// </summary>
  TVADStub = class
  strict private
    FTape: TArray<Boolean>;
    FFrameSize: Integer;
    FConsumed: Integer;
  public
    constructor Create(const ATape: TArray<Boolean>; AFrameSize: Integer);
    function ProcessFrame(AStart, ACount: Integer): Boolean;
    procedure Reset;
    property FrameSize: Integer read FFrameSize;
    property Consumed: Integer read FConsumed;
  end;

  TAutoStopResult = record
    AutoStop: Boolean;
    FramesConsumed: Integer;
    EndCursor: Integer;
  end;

  [TestFixture]
  [Category('PBT')]
  TSpeechAutoStopPropertyTests = class
  strict private
    function IncrementalPoll(AVAD: TVADStub; var ACursor: Integer;
      ATotalSamples: Integer): TAutoStopResult;
    function FullProcess(AVAD: TVADStub; ATotalSamples: Integer): TAutoStopResult;
    function MakeRandomTape(ALen: Integer; AStopFrame: Integer): TArray<Boolean>;
  public
    [Setup]
    procedure Setup;

    // Feature: deepbase-round2-fixes, Property 41
    [Test]
    procedure Property41_IncrementalEquivalentToFull;
  end;

implementation

{ TVADStub }

constructor TVADStub.Create(const ATape: TArray<Boolean>;
  AFrameSize: Integer);
begin
  inherited Create;
  FTape := ATape;
  FFrameSize := AFrameSize;
  FConsumed := 0;
end;

function TVADStub.ProcessFrame(AStart, ACount: Integer): Boolean;
var
  LFrameIdx: Integer;
begin
  // Simulate the production VAD: it consumes a fixed-size frame and
  // returns True when silence threshold is reached. The mapping from
  // (start, count) -> tape index assumes frame-aligned reads, which is
  // exactly the precondition the production loop enforces.
  if (ACount <> FFrameSize) or (AStart < 0) then
    Exit(False);
  LFrameIdx := AStart div FFrameSize;
  Inc(FConsumed);
  if (LFrameIdx < 0) or (LFrameIdx >= Length(FTape)) then
    Exit(False);
  Result := FTape[LFrameIdx];
end;

procedure TVADStub.Reset;
begin
  FConsumed := 0;
end;

{ TSpeechAutoStopPropertyTests }

procedure TSpeechAutoStopPropertyTests.Setup;
begin
  Randomize;
end;

function TSpeechAutoStopPropertyTests.IncrementalPoll(AVAD: TVADStub;
  var ACursor: Integer; ATotalSamples: Integer): TAutoStopResult;
var
  LOffset, LChunk: Integer;
begin
  // Faithful port of the inner loop in
  // TDeepBaseSpeechService.ShouldAutoStop after the Round-2 fix:
  //   - process only [FAutoStopCursor .. TotalCount)
  //   - skip the partial tail (waits for a full frame)
  //   - on True return, advance cursor past the consumed frame and
  //     return immediately
  //   - on no-trigger, advance cursor to the last frame-aligned offset
  Result.AutoStop := False;
  Result.FramesConsumed := 0;
  Result.EndCursor := ACursor;

  if ATotalSamples <= ACursor then
    Exit;

  LOffset := ACursor;
  while LOffset < ATotalSamples do
  begin
    LChunk := Min(AVAD.FrameSize, ATotalSamples - LOffset);
    if LChunk < AVAD.FrameSize then
      Break;

    Inc(Result.FramesConsumed);
    if AVAD.ProcessFrame(LOffset, LChunk) then
    begin
      ACursor := LOffset + LChunk;
      Result.AutoStop := True;
      Result.EndCursor := ACursor;
      Exit;
    end;
    Inc(LOffset, LChunk);
  end;
  ACursor := LOffset;
  Result.EndCursor := ACursor;
end;

function TSpeechAutoStopPropertyTests.FullProcess(AVAD: TVADStub;
  ATotalSamples: Integer): TAutoStopResult;
var
  LOffset, LChunk: Integer;
begin
  // Pre-fix behaviour: re-run the VAD from offset 0 every poll. This
  // is the "ground truth" the incremental algorithm must match: the
  // first frame index that returns True is the same in both traces.
  Result.AutoStop := False;
  Result.FramesConsumed := 0;
  Result.EndCursor := 0;

  LOffset := 0;
  while LOffset < ATotalSamples do
  begin
    LChunk := Min(AVAD.FrameSize, ATotalSamples - LOffset);
    if LChunk < AVAD.FrameSize then
      Break;

    Inc(Result.FramesConsumed);
    if AVAD.ProcessFrame(LOffset, LChunk) then
    begin
      Result.AutoStop := True;
      Result.EndCursor := LOffset + LChunk;
      Exit;
    end;
    Inc(LOffset, LChunk);
  end;
  Result.EndCursor := LOffset;
end;

function TSpeechAutoStopPropertyTests.MakeRandomTape(ALen: Integer;
  AStopFrame: Integer): TArray<Boolean>;
begin
  SetLength(Result, ALen);
  for var I := 0 to ALen - 1 do
    Result[I] := False;
  if (AStopFrame >= 0) and (AStopFrame < ALen) then
    Result[AStopFrame] := True;
end;

procedure
TSpeechAutoStopPropertyTests
.Property41_IncrementalEquivalentToFull;
const
  CFrameSize = 320;  // matches typical 20 ms @ 16 kHz frame
var
  LTape: TArray<Boolean>;
  LFrameCount, LStopFrame, LTotalSamples: Integer;
  LCursor: Integer;
  LIncremental, LFull: TAutoStopResult;
  LIncrFrameSum: Integer;
  LStubIncr, LStubFull: TVADStub;
  LPollSamples: Integer;
  LLastCursor: Integer;
begin
  for var Iter := 1 to 100 do
  begin
    // Random buffer geometry. Mix in:
    //  - tapes where stop never triggers (LStopFrame = -1)
    //  - tapes where stop triggers in the first frame
    //  - tapes where stop triggers near the end
    LFrameCount := 4 + Random(60);
    case Iter mod 4 of
      0: LStopFrame := -1;
      1: LStopFrame := 0;
      2: LStopFrame := LFrameCount - 1;
    else
      LStopFrame := Random(LFrameCount);
    end;
    LTape := MakeRandomTape(LFrameCount, LStopFrame);
    LTotalSamples := LFrameCount * CFrameSize + Random(CFrameSize);
    // include a partial trailing frame -> incremental must skip it

    // -------- Full-process baseline --------
    LStubFull := TVADStub.Create(LTape, CFrameSize);
    try
      LFull := FullProcess(LStubFull, LTotalSamples);
    finally
      LStubFull.Free;
    end;

    // -------- Incremental polling --------
    LStubIncr := TVADStub.Create(LTape, CFrameSize);
    try
      LCursor := 0;
      LIncrFrameSum := 0;
      LLastCursor := 0;
      LIncremental.AutoStop := False;
      LIncremental.EndCursor := 0;
      LIncremental.FramesConsumed := 0;

      // Drive the incremental algorithm with random poll boundaries.
      // Each poll receives [0..NewlyAvailable) so the cursor sees a
      // monotonically-growing buffer, which mirrors the production
      // call site where new audio samples accumulate over time.
      var LSimulatedTotal := 0;
      while LSimulatedTotal < LTotalSamples do
      begin
        LPollSamples := 1 + Random(2 * CFrameSize);
        LSimulatedTotal := Min(LSimulatedTotal + LPollSamples,
          LTotalSamples);

        LIncremental := IncrementalPoll(LStubIncr, LCursor,
          LSimulatedTotal);
        Inc(LIncrFrameSum, LIncremental.FramesConsumed);

        // Cursor only moves forward, never backwards.
        Assert.IsTrue(LCursor >= LLastCursor,
          Format('Iter %d: cursor went backwards %d -> %d',
            [Iter, LLastCursor, LCursor]));
        // Cursor stays frame-aligned (multiple of CFrameSize) until
        // it reaches a stop point, where it points just past the
        // triggering frame (still frame-aligned).
        Assert.AreEqual(0, LCursor mod CFrameSize,
          Format('Iter %d: cursor %d not frame-aligned', [Iter, LCursor]));
        LLastCursor := LCursor;

        if LIncremental.AutoStop then
          Break;
      end;

      // Final equivalence: incremental must reach the same auto-stop
      // decision as the full re-processor.
      Assert.AreEqual(LFull.AutoStop, LIncremental.AutoStop,
        Format('Iter %d: AutoStop diverged (full=%s, incr=%s, ' +
               'stopFrame=%d, frames=%d)',
          [Iter, BoolToStr(LFull.AutoStop, True),
           BoolToStr(LIncremental.AutoStop, True),
           LStopFrame, LFrameCount]));

      // When auto-stop triggers, cursors must coincide.
      if LFull.AutoStop then
        Assert.AreEqual(LFull.EndCursor, LCursor,
          Format('Iter %d: EndCursor mismatch full=%d incr=%d',
            [Iter, LFull.EndCursor, LCursor]));

      // Total frames consumed across all incremental polls must equal
      // the full-process count up to and including the stop frame.
      // (Without stop, both walk every full frame exactly once.)
      Assert.AreEqual(LFull.FramesConsumed, LIncrFrameSum,
        Format('Iter %d: frame-consumption diverged (full=%d, ' +
               'incr-sum=%d, stopFrame=%d)',
          [Iter, LFull.FramesConsumed, LIncrFrameSum, LStopFrame]));
    finally
      LStubIncr.Free;
    end;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TSpeechAutoStopPropertyTests);

end.
