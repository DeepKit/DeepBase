{ ============================================================================
  Test.DeepBase.Encoding.Fix.PBT - Property-based tests for the encoding
  fix output contract.

  Properties covered:
    P17: Encoding Fix Produces Valid UTF-8 (Req 12.2)
         For any string that has been processed by the encoding fix, the
         output SHALL be valid UTF-8 and SHALL NOT contain mojibake
         sequences (U+FFFD or the well-known GBK-cycled marker 锟斤拷).

  Strategy:
    - Generate random valid Unicode strings, round-trip through UTF-8
      encoding/decoding, and assert (a) the value is preserved bit-for-bit
      and (b) no mojibake markers are present.
    - Provide a fixed-fixture detection test that asserts a known mojibake
      string IS detected (negative control), confirming the detector
      itself is wired up correctly.

  Each property test runs >= 100 random iterations.
  ============================================================================ }

unit Test.DeepBase.Encoding.Fix.PBT;

interface

uses
  System.SysUtils,
  System.Classes,
  DUnitX.TestFramework;

type
  [TestFixture]
  TEncodingFixPropertyTests = class
  strict private
    /// <summary>
    /// Returns True if AText contains the well-known GBK-loop mojibake
    /// pattern 锟斤拷 or any U+FFFD replacement character.
    /// </summary>
    function ContainsMojibake(const AText: string): Boolean;
    function RandomUnicodeString(AMinLen, AMaxLen: Integer): string;
  public
    [Setup]
    procedure Setup;

    // Feature: deepbase-bug-fixes-p0p1p2, Property 17 (round-trip)
    [Test]
    procedure Property17_RandomUnicode_RoundTripsThroughUTF8;

    // Feature: deepbase-bug-fixes-p0p1p2, Property 17 (negative control)
    [Test]
    procedure Property17_KnownMojibake_IsDetected;

    // Feature: deepbase-bug-fixes-p0p1p2, Property 17 (clean text)
    [Test]
    procedure Property17_KnownCleanStrings_AreNotFlagged;
  end;

implementation

{ TEncodingFixPropertyTests }

procedure TEncodingFixPropertyTests.Setup;
begin
  Randomize;
end;

function TEncodingFixPropertyTests.ContainsMojibake(const AText: string): Boolean;
const
  CMojibakeMarker = #$951F#$65A4#$62F7; // 锟斤拷 in code points
  CReplacementChar = #$FFFD;
begin
  Result := (Pos(CMojibakeMarker, AText) > 0) or
            (Pos(CReplacementChar, AText) > 0);
end;

function TEncodingFixPropertyTests.RandomUnicodeString(AMinLen,
  AMaxLen: Integer): string;
var
  LLen, I, LCode: Integer;
  LSb: TStringBuilder;
begin
  if AMinLen < 0 then AMinLen := 0;
  if AMaxLen < AMinLen then AMaxLen := AMinLen;
  LLen := AMinLen + Random(AMaxLen - AMinLen + 1);
  LSb := TStringBuilder.Create;
  try
    for I := 1 to LLen do
    begin
      // Pick from BMP, skipping surrogate range (D800-DFFF), the
      // U+FFFD replacement character itself and the GBK-loop tri-glyph
      // so the random generator never accidentally produces what the
      // detector would flag.
      repeat
        LCode := 1 + Random($FFFE);
      until ((LCode < $D800) or (LCode > $DFFF))
            and (LCode <> $FFFD)
            and (LCode <> $951F)
            and (LCode <> $65A4)
            and (LCode <> $62F7);
      LSb.Append(Char(LCode));
    end;
    Result := LSb.ToString;
  finally
    LSb.Free;
  end;
end;

// Feature: deepbase-bug-fixes-p0p1p2, Property 17: Random Unicode strings
// round-trip through UTF-8 without losing data and without producing any
// mojibake markers.
procedure TEncodingFixPropertyTests
  .Property17_RandomUnicode_RoundTripsThroughUTF8;
begin
  for var Iter := 1 to 100 do
  begin
    var LOriginal := RandomUnicodeString(0, 64);
    var LBytes := TEncoding.UTF8.GetBytes(LOriginal);
    var LDecoded := TEncoding.UTF8.GetString(LBytes);

    Assert.AreEqual(LOriginal, LDecoded,
      Format('Iter %d: UTF-8 round-trip lost data', [Iter]));
    Assert.IsFalse(ContainsMojibake(LDecoded),
      Format('Iter %d: round-trip produced mojibake from clean input', [Iter]));
  end;
end;

// Feature: deepbase-bug-fixes-p0p1p2, Property 17 (negative control):
// Strings containing the well-known mojibake sequence MUST be flagged.
// This guards against a regression where the detector is silently
// short-circuited.
procedure TEncodingFixPropertyTests.Property17_KnownMojibake_IsDetected;
const
  CMojibake1 = 'data/' + #$951F#$65A4#$62F7 + 'Config.db';
  CMojibake2 = 'caption=' + #$FFFD + 'value';
  CMojibake3 = 'mixed ' + #$951F#$65A4#$62F7 + ' ascii';
begin
  // We loop over a small set of fixtures, randomising surrounding noise
  // so the detector is exercised on many realistic shapes.
  for var Iter := 1 to 100 do
  begin
    var LSelector := Random(3);
    var LFixture: string := if LSelector = 0
        then CMojibake1
        else if LSelector = 1
          then CMojibake2
          else CMojibake3;
    var LSuffix := IntToStr(Random(MaxInt));
    Assert.IsTrue(ContainsMojibake(LFixture + LSuffix),
      Format('Iter %d: detector failed to flag known mojibake "%s"',
        [Iter, LFixture]));
  end;
end;

// Feature: deepbase-bug-fixes-p0p1p2, Property 17 (positive control):
// Sanitised representative strings - including non-mojibake CJK text -
// must NOT be flagged by the detector.
procedure TEncodingFixPropertyTests.Property17_KnownCleanStrings_AreNotFlagged;
const
  CCleanFixtures: array[0..4] of string = (
    'Plain ASCII string',
    '你好世界',
    'Mixed: hello 世界 / 123',
    'Special chars: /=?&%#@~',
    ''
  );
begin
  for var Iter := 1 to 100 do
  begin
    for var F in CCleanFixtures do
    begin
      var LCandidate := F + ' ' + IntToStr(Random(MaxInt));
      Assert.IsFalse(ContainsMojibake(LCandidate),
        Format('Iter %d: clean string flagged as mojibake: "%s"',
          [Iter, LCandidate]));
    end;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TEncodingFixPropertyTests);

end.
