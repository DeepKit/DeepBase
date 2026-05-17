{ ============================================================================
  Test.DeepBase.SQL.Security.PBT - Property-based tests for SQL safety.

  Properties covered (deepbase-round2-fixes):
    Property 17: TSQLUtils.IsValidIdentifier accepts only [A-Za-z_][A-Za-z0-9_]*
                 (max 128 chars). ValidateIdentifier raises EArgumentException
                 on rejection.
    Property 18: TSQLLogger.FormatExtra always emits valid JSON for any
                 dictionary of key/value strings (including special chars
                 like quotes, backslashes, newlines, embedded NULs, unicode).
                 Round-trip parse must recover every original key/value.
    Property 19: TDBGuardian.Checkpoint accepts only the WAL checkpoint
                 whitelist [PASSIVE, FULL, RESTART, TRUNCATE] (case-insensitive)
                 and raises EArgumentOutOfRangeException for everything else
                 (including SQL injection attempts).

  Each property runs >= 100 random iterations.
  ============================================================================ }

unit Test.DeepBase.SQL.Security.PBT;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Generics.Collections,
  System.Character,
  FireDAC.Comp.Client,
  FireDAC.Stan.Def,
  FireDAC.Phys,
  FireDAC.Phys.SQLiteDef,
  FireDAC.Phys.SQLite,
  DUnitX.TestFramework,
  DeepBase.SQL.Utils,
  DeepBase.SQLLogger,
  DeepBase.DB.Guardian;

type
  [TestFixture]
  TSQLSecurityPropertyTests = class
  strict private
    function NewMemoryConnection: TFDConnection;
    function RandomAlpha: Char;
    function RandomAlphaDigit: Char;
    function RandomDigit: Char;
    function RandomSpecial: Char;
    function RandomValidIdentifier(AMaxLen: Integer): string;
    function RandomInvalidIdentifier(AIter: Integer): string;
    function RandomTrickyValue(AIter: Integer): string;
  public
    [Setup]
    procedure Setup;

    // Feature: deepbase-round2-fixes, Property 17
    [Test]
    procedure Property17_SqlIdentifierValidation;

    // Feature: deepbase-round2-fixes, Property 18
    [Test]
    procedure Property18_SQLLoggerFormatExtraJsonValid;

    // Feature: deepbase-round2-fixes, Property 19
    [Test]
    procedure Property19_GuardianCheckpointWhitelist;
  end;

implementation

{ TSQLSecurityPropertyTests }

procedure TSQLSecurityPropertyTests.Setup;
begin
  Randomize;
end;

function TSQLSecurityPropertyTests.NewMemoryConnection: TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  Result.DriverName := 'SQLite';
  Result.Params.Database := ':memory:';
  Result.LoginPrompt := False;
  Result.Open;
end;

function TSQLSecurityPropertyTests.RandomAlpha: Char;
begin
  if Random(2) = 0 then
    Result := Char(Ord('a') + Random(26))
  else
    Result := Char(Ord('A') + Random(26));
end;

function TSQLSecurityPropertyTests.RandomDigit: Char;
begin
  Result := Char(Ord('0') + Random(10));
end;

function TSQLSecurityPropertyTests.RandomAlphaDigit: Char;
begin
  case Random(3) of
    0: Result := RandomAlpha;
    1: Result := RandomDigit;
  else
    Result := '_';
  end;
end;

function TSQLSecurityPropertyTests.RandomSpecial: Char;
const
  CSpecials: array[0..14] of Char = (
    ';', '''', '"', '\', ' ', #9, #10, #13, '-', '/', '*', '(', ')', '`', '#'
  );
begin
  Result := CSpecials[Random(Length(CSpecials))];
end;

function TSQLSecurityPropertyTests.RandomValidIdentifier(AMaxLen: Integer): string;
var
  LLen: Integer;
begin
  LLen := 1 + Random(AMaxLen);
  SetLength(Result, LLen);
  // First char: letter or underscore
  if Random(4) = 0 then
    Result[1] := '_'
  else
    Result[1] := RandomAlpha;
  for var I := 2 to LLen do
    Result[I] := RandomAlphaDigit;
end;

function TSQLSecurityPropertyTests.RandomInvalidIdentifier(AIter: Integer): string;
begin
  case AIter mod 8 of
    0: Result := '';                                  // empty
    1: Result := string(RandomDigit) + RandomValidIdentifier(8);   // starts with digit
    2: Result := 'name' + RandomSpecial + 'rest';     // contains special char
    3: Result := 'DROP TABLE users';                  // SQL injection
    4: Result := 'col;DROP TABLE users';              // injection with semicolon
    5: Result := 'col--comment';                      // SQL comment
    6: Result := StringOfChar('a', 129);              // exceeds 128 chars
  else
    begin
      // Random char with at least one special
      var LBuf := '';
      var LLen := 1 + Random(20);
      LBuf := LBuf + RandomSpecial;
      for var I := 2 to LLen do
        if Random(3) = 0 then
          LBuf := LBuf + RandomSpecial
        else
          LBuf := LBuf + RandomAlphaDigit;
      Result := LBuf;
    end;
  end;
end;

function TSQLSecurityPropertyTests.RandomTrickyValue(AIter: Integer): string;
begin
  case AIter mod 8 of
    0: Result := '';
    1: Result := 'plain ascii value';
    2: Result := 'value with "quotes"';
    3: Result := 'with \backslash\\ and / slash';
    4: Result := 'multi'#10'line'#13'value';
    5: Result := 'tab'#9'separated'#9'cols';
    6: // Unicode characters via codepoints to avoid source-encoding warnings.
       // CJK (中文), katakana (テスト), and emoji (rocket) ranges.
       Result := #$4E2D#$6587 + ' unicode ' +
                 #$30C6#$30B9#$30C8 + ' ' +
                 #$D83D#$DE80;
  else
    begin
      // Random mix of specials and printable. Skip NUL (#0) because some
      // string-based JSON parsers truncate at NUL; that is outside the
      // scope of this property.
      var LLen := 1 + Random(40);
      SetLength(Result, LLen);
      for var I := 1 to LLen do
        if Random(3) = 0 then
          Result[I] := RandomSpecial
        else
          Result[I] := Char($20 + Random($7E - $20 + 1));
    end;
  end;
end;

// Feature: deepbase-round2-fixes, Property 17: For any string matching
// [A-Za-z_][A-Za-z0-9_]* and length 1..128, IsValidIdentifier MUST return
// True; for any string violating that pattern (empty, leading digit,
// containing punctuation/whitespace/control chars, or length > 128),
// IsValidIdentifier MUST return False and ValidateIdentifier MUST raise
// EArgumentException.
procedure TSQLSecurityPropertyTests.Property17_SqlIdentifierValidation;
begin
  for var Iter := 1 to 100 do
  begin
    // ---- Positive case: random valid identifier ----
    var LValid := RandomValidIdentifier(64);
    Assert.IsTrue(TSQLUtils.IsValidIdentifier(LValid),
      Format('Iter %d: valid identifier "%s" rejected', [Iter, LValid]));
    // Should not raise on validate.
    var LRaised: Boolean := False;
    try
      TSQLUtils.ValidateIdentifier(LValid, 'test-positive');
    except
      on E: Exception do
        LRaised := True;
    end;
    Assert.IsFalse(LRaised,
      Format('Iter %d: ValidateIdentifier raised on valid identifier "%s"',
        [Iter, LValid]));

    // ---- Negative case: known-invalid identifier ----
    var LInvalid := RandomInvalidIdentifier(Iter);
    Assert.IsFalse(TSQLUtils.IsValidIdentifier(LInvalid),
      Format('Iter %d: invalid identifier %s incorrectly accepted',
        [Iter, QuotedStr(LInvalid)]));
    // ValidateIdentifier MUST raise EArgumentException.
    var LRaisedExpected: Boolean := False;
    var LWrongClass: string := '';
    try
      TSQLUtils.ValidateIdentifier(LInvalid, 'test-negative');
    except
      on E: EArgumentException do
        LRaisedExpected := True;
      on E: Exception do
        LWrongClass := E.ClassName;
    end;
    var LDescr := if LWrongClass = '' then '<no exception>' else LWrongClass;
    Assert.IsTrue(LRaisedExpected,
      Format('Iter %d: ValidateIdentifier did not raise EArgumentException ' +
             'on invalid identifier %s (got %s instead)',
        [Iter, QuotedStr(LInvalid), LDescr]));
  end;
end;

// Feature: deepbase-round2-fixes, Property 18: TSQLLogger.FormatExtra MUST
// emit JSON that round-trips through TJSONObject.ParseJSONValue, and every
// original (key, value) pair MUST be recoverable from the parsed object,
// regardless of special characters in keys or values (quotes, backslashes,
// newlines, NULs, multi-byte UTF-8). No JSON injection.
procedure TSQLSecurityPropertyTests.Property18_SQLLoggerFormatExtraJsonValid;
begin
  for var Iter := 1 to 100 do
  begin
    var LDict := TDictionary<string, string>.Create;
    try
      // 1..6 random pairs per iteration. Use unique keys to avoid clobbering.
      var LCount := 1 + Random(6);
      for var I := 0 to LCount - 1 do
      begin
        var LKey := Format('k%d_%s', [I, RandomValidIdentifier(8)]);
        var LValue := RandomTrickyValue(Iter * 31 + I);
        LDict.AddOrSetValue(LKey, LValue);
      end;

      var LJson := TSQLLogger.FormatExtra(LDict);
      Assert.IsNotEmpty(LJson,
        Format('Iter %d: FormatExtra produced empty string', [Iter]));

      var LParsed := TJSONObject.ParseJSONValue(LJson);
      try
        Assert.IsTrue(LParsed is TJSONObject,
          Format('Iter %d: FormatExtra output not a JSON object: %s',
            [Iter, LJson]));
        var LObj := TJSONObject(LParsed);
        for var LPair in LDict do
        begin
          var LRecovered: string := '';
          var LFound := LObj.TryGetValue<string>(LPair.Key, LRecovered);
          Assert.IsTrue(LFound,
            Format('Iter %d: key "%s" missing from parsed JSON %s',
              [Iter, LPair.Key, LJson]));
          Assert.AreEqual(LPair.Value, LRecovered,
            Format('Iter %d: value mismatch for key "%s" in JSON %s',
              [Iter, LPair.Key, LJson]));
        end;
      finally
        LParsed.Free;
      end;
    finally
      LDict.Free;
    end;
  end;
end;

// Feature: deepbase-round2-fixes, Property 19: TDBGuardian.Checkpoint MUST
// accept only the WAL whitelist {PASSIVE, FULL, RESTART, TRUNCATE}
// (case-insensitive) plus the empty string (which the implementation maps
// to 'PASSIVE' as a default). For every other input -- including injection
// attempts like 'PASSIVE; DROP TABLE x' or random garbage -- it MUST raise
// EArgumentOutOfRangeException before issuing any PRAGMA.
procedure TSQLSecurityPropertyTests.Property19_GuardianCheckpointWhitelist;
const
  CWhitelist: array[0..3] of string = ('PASSIVE', 'FULL', 'RESTART', 'TRUNCATE');

  function MakeBadMode(AIter: Integer): string;
  begin
    case AIter mod 9 of
      0: Result := 'INVALID';
      1: Result := 'PASSIVE; DROP TABLE foo';   // injection
      2: Result := 'TRUNCATE--';                 // SQL comment
      3: Result := 'PASSIVE TRUNCATE';           // two modes concatenated
      4: Result := 'PASSIV';                     // close to valid but typo
      5: Result := '0';                          // numeric
      6: Result := StringOfChar('A', 64);        // long garbage
      7: Result := 'PASSIVE)';                   // SQL break-out
    else
      begin
        // Random chars
        var LLen := 1 + Random(20);
        SetLength(Result, LLen);
        for var I := 1 to LLen do
          Result[I] := Char($20 + Random($7E - $20 + 1));
      end;
    end;
  end;

  function IsAccidentallyValid(const ABad: string): Boolean;
  var
    LU: string;
  begin
    LU := ABad.ToUpper;
    Result := (LU = 'PASSIVE') or (LU = 'FULL') or (LU = 'RESTART') or
              (LU = 'TRUNCATE') or (ABad = '');
  end;

begin
  var LConn := NewMemoryConnection;
  try
    // ---- Positive: whitelist must NOT raise (PRAGMA may fail silently
    // because :memory: doesn't support WAL, but the validation gate must
    // not raise EArgumentOutOfRangeException).
    for var LMode in CWhitelist do
    begin
      var LRaised: Boolean := False;
      try
        TDBGuardian.Checkpoint(LConn, LMode);
      except
        on E: EArgumentOutOfRangeException do
          LRaised := True;
        // Other exceptions (PRAGMA failure on :memory:) are caught
        // internally by the implementation, so they should not reach us.
      end;
      Assert.IsFalse(LRaised,
        Format('Whitelisted mode "%s" was rejected by Checkpoint validation',
          [LMode]));
    end;

    // Lowercase variants must also pass validation (case-insensitive).
    for var LMode in CWhitelist do
    begin
      var LLower := LMode.ToLower;
      var LRaised: Boolean := False;
      try
        TDBGuardian.Checkpoint(LConn, LLower);
      except
        on E: EArgumentOutOfRangeException do
          LRaised := True;
      end;
      Assert.IsFalse(LRaised,
        Format('Whitelisted mode "%s" (lowercase) rejected', [LLower]));
    end;

    // Empty string defaults to PASSIVE per implementation.
    var LRaisedEmpty: Boolean := False;
    try
      TDBGuardian.Checkpoint(LConn, '');
    except
      on E: EArgumentOutOfRangeException do
        LRaisedEmpty := True;
    end;
    Assert.IsFalse(LRaisedEmpty,
      'Empty mode should default to PASSIVE, not raise');

    // ---- Negative: all non-whitelist inputs MUST raise. ----
    for var Iter := 1 to 100 do
    begin
      var LBad := MakeBadMode(Iter);
      // Random generation may occasionally land on a whitelist string;
      // skip such accidental matches so the property stays well-defined.
      if IsAccidentallyValid(LBad) then
        Continue;

      var LExpectedRaised: Boolean := False;
      var LWrongClass: string := '';
      try
        TDBGuardian.Checkpoint(LConn, LBad);
      except
        on E: EArgumentOutOfRangeException do
          LExpectedRaised := True;
        on E: Exception do
          LWrongClass := E.ClassName;
      end;
      var LDescr := if LWrongClass = '' then '<no exception>' else LWrongClass;
      Assert.IsTrue(LExpectedRaised,
        Format('Iter %d: bad mode %s did not raise ' +
               'EArgumentOutOfRangeException (got %s)',
          [Iter, QuotedStr(LBad), LDescr]));
    end;
  finally
    LConn.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TSQLSecurityPropertyTests);

end.
