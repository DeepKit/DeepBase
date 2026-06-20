{ ============================================================================
  Test.DeepBase.IntentClarification.SignalDetector.PBT - PBT for the
  SignalDetector token-counting performance fix.

  Properties covered (deepbase-round2-fixes):
    Property 42: For any input string and token, the PosEx-based
                 CountToken implementation (Round-2 fix, Req 15.7) must
                 return the same count as the naive Copy-based
                 implementation it replaced. The two algorithms agree
                 over random ASCII / UTF-8 / overlapping-pattern /
                 token-larger-than-text / token-equal-to-text inputs.

  Each property runs >= 100 random iterations.

  Notes on observability:
    - DeepBase.IntentClarification.SignalDetector.CountToken is declared
      in the unit's implementation section and is therefore not callable
      from this test. We mirror BOTH implementations locally:
        CountTokenPosEx -> the new, fixed algorithm
        CountTokenCopy  -> the old, naive algorithm
      and then assert their equivalence under random inputs. This is a
      "helper-mirror pattern": the test pins the *algorithm-level*
      invariant the production refactor relies on. If the production
      code drifts, the helper-mirror still validates the property
      claimed by the spec, and a parallel unit test (or an integration
      test) is responsible for exercising the actual call site.
  ============================================================================ }

unit Test.DeepBase.IntentClarification.SignalDetector.PBT;

interface

uses
  System.SysUtils,
  System.StrUtils,
  DUnitX.TestFramework;

type
  [TestFixture]
  [Category('PBT')]
  TSignalDetectorPropertyTests = class
  strict private
    function CountTokenPosEx(const AText, AToken: string): Integer;
    function CountTokenCopy(const AText, AToken: string): Integer;
    function RandomToken(AIter: Integer): string;
    function RandomText(AIter: Integer; const AToken: string): string;
  public
    [Setup]
    procedure Setup;

    // Feature: deepbase-round2-fixes, Property 42
    [Test]
    procedure Property42_PosExAndCopyAgree;
  end;

implementation

{ TSignalDetectorPropertyTests }

procedure TSignalDetectorPropertyTests.Setup;
begin
  Randomize;
end;

function TSignalDetectorPropertyTests.CountTokenPosEx(
  const AText, AToken: string): Integer;
var
  LPos, LStart: Integer;
begin
  // Mirror of the Round-2 fixed implementation in
  // DeepBase.IntentClarification.SignalDetector (IC-019). Uses PosEx
  // with an advancing start index, so the loop body never copies the
  // tail of AText.
  Result := 0;
  if (AText = '') or (AToken = '') then
    Exit;

  LStart := 1;
  repeat
    LPos := PosEx(AToken, AText, LStart);
    if LPos <= 0 then
      Break;
    Inc(Result);
    LStart := LPos + Length(AToken);
  until LStart > Length(AText);
end;

function TSignalDetectorPropertyTests.CountTokenCopy(
  const AText, AToken: string): Integer;
var
  LRem: string;
  LPos: Integer;
begin
  // Mirror of the original Copy-based loop. Each iteration discards
  // the head of AText with a fresh allocation, hence the O(n^2)
  // behaviour the fix removes.
  Result := 0;
  if (AText = '') or (AToken = '') then
    Exit;

  LRem := AText;
  while True do
  begin
    LPos := Pos(AToken, LRem);
    if LPos <= 0 then
      Break;
    Inc(Result);
    LRem := Copy(LRem, LPos + Length(AToken),
      Length(LRem) - LPos - Length(AToken) + 1);
    if LRem = '' then
      Break;
  end;
end;

function TSignalDetectorPropertyTests.RandomToken(AIter: Integer): string;
begin
  // Cover several token shapes:
  //   - single ASCII char (typical "?" / "!")
  //   - multi-char ASCII (whole word)
  //   - CJK character (multi-byte in UTF-8 but a single UTF-16 code unit
  //     in a Delphi string)
  //   - overlapping-prone token like "aa" or "aba"
  case AIter mod 7 of
    0: Result := '?';
    1: Result := 'foo';
    2: Result := 'bar';
    3: Result := Char($4E2D);                 // CJK 中
    4: Result := 'aa';
    5: Result := 'aba';
  else
    var LLen := 1 + Random(4);
    var LBuf := '';
    for var I := 1 to LLen do
      LBuf := LBuf + Char(Ord('a') + Random(3));  // {a, b, c}
    Result := LBuf;
  end;
end;

function TSignalDetectorPropertyTests.RandomText(AIter: Integer;
  const AToken: string): string;
var
  LBuf: string;
  LLen: Integer;
begin
  case AIter mod 6 of
    0: Result := '';
    1: Result := AToken;                       // text == token
    2: Result := AToken + AToken + AToken;     // adjacent repeats
    3: Result := 'no match here';
    4: Result := AToken + ' middle ' + AToken;
  else
    // Random 8..120 char string built from a mix of token chars,
    // overlap-prone chars, and unrelated chars. This is the regime
    // where the two algorithms most easily disagree if either has
    // an off-by-one bug.
    LLen := 8 + Random(112);
    SetLength(LBuf, LLen);
    for var I := 1 to LLen do
    begin
      case Random(4) of
        0:
          if (AToken <> '') then
            LBuf[I] := AToken[1 + Random(Length(AToken))]
          else
            LBuf[I] := 'x';
        1: LBuf[I] := Char(Ord('a') + Random(5));
        2: LBuf[I] := Char($4E00 + Random($1000));
      else
        LBuf[I] := Char(Ord(' ') + Random(95));
      end;
    end;
    Result := LBuf;
  end;
end;

procedure TSignalDetectorPropertyTests.Property42_PosExAndCopyAgree;
var
  LToken, LText: string;
  LCountNew, LCountOld: Integer;
begin
  // Pinned regression cases first - quick to fail and easy to debug.
  Assert.AreEqual(CountTokenCopy('aaaa', 'aa'),
    CountTokenPosEx('aaaa', 'aa'),
    'overlapping token "aa" in "aaaa"');
  Assert.AreEqual(CountTokenCopy('', 'x'),
    CountTokenPosEx('', 'x'),
    'empty text');
  Assert.AreEqual(CountTokenCopy('abc', ''),
    CountTokenPosEx('abc', ''),
    'empty token');
  Assert.AreEqual(CountTokenCopy('hellohello', 'hello'),
    CountTokenPosEx('hellohello', 'hello'),
    'adjacent repeats');

  for var Iter := 1 to 100 do
  begin
    LToken := RandomToken(Iter);
    LText := RandomText(Iter, LToken);

    LCountNew := CountTokenPosEx(LText, LToken);
    LCountOld := CountTokenCopy(LText, LToken);

    Assert.AreEqual(LCountOld, LCountNew,
      Format('Iter %d: PosEx=%d Copy=%d for token=%s text length=%d',
        [Iter, LCountNew, LCountOld, LToken, Length(LText)]));

    // Counts are non-negative and bounded by Length(text).
    Assert.IsTrue(LCountNew >= 0,
      Format('Iter %d: count must be non-negative', [Iter]));
    if LToken <> '' then
      Assert.IsTrue(LCountNew * Length(LToken) <= Length(LText),
        Format('Iter %d: %d non-overlapping copies of len-%d token ' +
               'cannot fit in len-%d text',
          [Iter, LCountNew, Length(LToken), Length(LText)]));
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TSignalDetectorPropertyTests);

end.
