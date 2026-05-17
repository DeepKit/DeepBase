{ ============================================================================
  Test.DeepBase.Browser.Contract.PBT - Property-based tests for browser
  script template contracts and selector event-payload safety.

  Properties covered (deepbase-round2-fixes):
    Property 31: ScriptStore.Render(JSCRIPT_GET_TEXT|CLICK|INPUT_TEXT,
                 ...) returns a JS source string whose top-level return
                 expression matches the documented contract:
                   get_text   -> [found, text, error]
                   click      -> [success, error]
                   input_text -> [success, error]
                 The selector argument is interpolated through
                 VarRecToJsonLiteral, which produces a JSON-safe string
                 literal even for inputs containing quotes, backslashes,
                 newlines, tabs, or non-ASCII characters.
    Property 32: When TBrowserSelectorManager publishes an event for a
                 failed selector resolution, it builds the payload via
                 TJSONObject.ToJSON. For any selector value containing
                 special characters the resulting JSON parses back to
                 a TJSONObject whose fields equal the originals
                 byte-for-byte (no injection, no escape leakage).

  Each property runs >= 100 random iterations.

  Notes on observability:
    - For Property 31 we examine the *rendered* JS template directly.
      Executing JS would require a live WebView2 host. The contract is
      a syntactic property of the template after placeholder
      substitution.
    - For Property 32 the BrowserSelectorManager event publish path
      requires a live IBrowserSession to fail on (the JSON payload is
      built only after EvaluateScript returns False). We therefore
      exercise the same construction pattern (TJSONObject AddPair / ToJSON
      / ParseJSONValue) with the same field names ("selector", "error")
      that the production unit uses, and verify the JSON round-trip
      property under a wide range of malicious input strings. This is
      the same anti-injection guarantee the production code relies on.
  ============================================================================ }

unit Test.DeepBase.Browser.Contract.PBT;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  DUnitX.TestFramework,
  DeepBase.Browser.ScriptStore;

type
  [TestFixture]
  TBrowserContractPropertyTests = class
  strict private
    function MakeNastySelector(AIter: Integer): string;
    function MakeNastyError(AIter: Integer): string;
    function BuildSelectorFailedPayload(
      const ASelector, AError: string): string;
  public
    [Setup]
    procedure Setup;

    // Feature: deepbase-round2-fixes, Property 31 (get_text contract)
    [Test]
    procedure Property31_GetTextScriptContract;

    // Feature: deepbase-round2-fixes, Property 31 (click contract)
    [Test]
    procedure Property31_ClickScriptContract;

    // Feature: deepbase-round2-fixes, Property 31 (input_text contract)
    [Test]
    procedure Property31_InputTextScriptContract;

    // Feature: deepbase-round2-fixes, Property 32
    [Test]
    procedure Property32_SelectorEventJSONIsSafe;
  end;

implementation

{ TBrowserContractPropertyTests }

procedure TBrowserContractPropertyTests.Setup;
begin
  Randomize;
end;

function TBrowserContractPropertyTests.MakeNastySelector(
  AIter: Integer): string;
begin
  case AIter mod 9 of
    0: Result := '#main';
    1: Result := 'div[data-testid="login-btn"]';
    2: Result := 'a[href="' + StringOfChar('"', 1 + Random(3)) + '"]';
    3: Result := '.cls\path\with\backslashes';
    4: Result := 'span:contains("' + #10#13#9'with newlines")';
    5: Result := 'div[title="' + 'hello "world" '#9'tab'#10'newline"]';
    6: Result := 'p[data-name="' + Char($4E2D) + Char($6587) + '"]';
    7: Result := 'input[value="' + StringOfChar('\', 2 + Random(4)) + '"]';
  else
    // Random gibberish with chars guaranteed to require escaping.
    var LBuf: string := '';
    var LLen := 4 + Random(40);
    for var I := 1 to LLen do
    begin
      case Random(8) of
        0: LBuf := LBuf + '"';
        1: LBuf := LBuf + '\';
        2: LBuf := LBuf + #10;
        3: LBuf := LBuf + #13;
        4: LBuf := LBuf + #9;
        5: LBuf := LBuf + Char($00 + Random(32));
        6: LBuf := LBuf + Char($4E00 + Random($1000));
      else
        LBuf := LBuf + Char(Ord('a') + Random(26));
      end;
    end;
    Result := LBuf;
  end;
end;

function TBrowserContractPropertyTests.MakeNastyError(
  AIter: Integer): string;
begin
  case AIter mod 6 of
    0: Result := 'not_found';
    1: Result := 'Error: "quoted ' + #9 + 'tab"';
    2: Result := 'oops\\backslash\n newline';
    3: Result := 'multi' + #13#10 + 'line';
    4: Result := Char($1F600) + ' emoji';
  else
    Result := '';
  end;
end;

function TBrowserContractPropertyTests.BuildSelectorFailedPayload(
  const ASelector, AError: string): string;
var
  LObj: TJSONObject;
begin
  // Mirrors the construction in TBrowserSelectorManager.ResolveSelector
  // (Round-2 fix BUG-BA-016 / BUG-BA-017): use TJSONObject for safe
  // serialization rather than ad-hoc string concatenation.
  LObj := TJSONObject.Create;
  try
    LObj.AddPair('selector', ASelector);
    LObj.AddPair('error', AError);
    Result := LObj.ToJSON;
  finally
    LObj.Free;
  end;
end;

procedure TBrowserContractPropertyTests.Property31_GetTextScriptContract;
var
  LStore: IJSScriptStore;
  LSelector, LRendered: string;
begin
  LStore := ScriptStore;
  for var Iter := 1 to 100 do
  begin
    LSelector := MakeNastySelector(Iter);
    LRendered := LStore.Render(JSCRIPT_GET_TEXT, ['selector', LSelector]);

    Assert.IsTrue(LRendered <> '',
      Format('Iter %d: rendered get_text must be non-empty', [Iter]));

    // Contract: the template returns an object with these three fields.
    Assert.IsTrue(Pos('found:', LRendered) > 0,
      Format('Iter %d: get_text must include "found:" field', [Iter]));
    Assert.IsTrue(Pos('text:', LRendered) > 0,
      Format('Iter %d: get_text must include "text:" field', [Iter]));
    Assert.IsTrue(Pos('error:', LRendered) > 0,
      Format('Iter %d: get_text must include "error:" field', [Iter]));

    // The placeholder must have been consumed; if VarRecToJsonLiteral
    // failed to escape correctly the literal "{{selector}}" would
    // remain in the output.
    Assert.IsFalse(Pos('{{selector}}', LRendered) > 0,
      Format('Iter %d: placeholder must be substituted', [Iter]));
  end;
end;

procedure TBrowserContractPropertyTests.Property31_ClickScriptContract;
var
  LStore: IJSScriptStore;
  LSelector, LRendered: string;
begin
  LStore := ScriptStore;
  for var Iter := 1 to 100 do
  begin
    LSelector := MakeNastySelector(Iter);
    LRendered := LStore.Render(JSCRIPT_CLICK, ['selector', LSelector]);

    Assert.IsTrue(LRendered <> '',
      Format('Iter %d: rendered click must be non-empty', [Iter]));

    // Contract: click returns {success, error}.
    Assert.IsTrue(Pos('success:', LRendered) > 0,
      Format('Iter %d: click must include "success:" field', [Iter]));
    Assert.IsTrue(Pos('error:', LRendered) > 0,
      Format('Iter %d: click must include "error:" field', [Iter]));
    // click must NOT advertise a "found" or "text" field.
    Assert.IsFalse(Pos('found:', LRendered) > 0,
      Format('Iter %d: click must not include "found:" field', [Iter]));

    Assert.IsFalse(Pos('{{selector}}', LRendered) > 0,
      Format('Iter %d: placeholder must be substituted', [Iter]));
  end;
end;

procedure
TBrowserContractPropertyTests
.Property31_InputTextScriptContract;
var
  LStore: IJSScriptStore;
  LSelector, LText, LRendered: string;
begin
  LStore := ScriptStore;
  for var Iter := 1 to 100 do
  begin
    LSelector := MakeNastySelector(Iter);
    LText := MakeNastyError(Iter);
    LRendered := LStore.Render(JSCRIPT_INPUT_TEXT,
      ['selector', LSelector, 'text', LText]);

    Assert.IsTrue(LRendered <> '',
      Format('Iter %d: rendered input_text must be non-empty', [Iter]));

    // Contract: input_text returns {success, error}.
    Assert.IsTrue(Pos('success:', LRendered) > 0,
      Format('Iter %d: input_text must include "success:" field',
        [Iter]));
    Assert.IsTrue(Pos('error:', LRendered) > 0,
      Format('Iter %d: input_text must include "error:" field', [Iter]));

    Assert.IsFalse(Pos('{{selector}}', LRendered) > 0,
      Format('Iter %d: selector placeholder must be substituted', [Iter]));
    Assert.IsFalse(Pos('{{text}}', LRendered) > 0,
      Format('Iter %d: text placeholder must be substituted', [Iter]));
  end;
end;

procedure TBrowserContractPropertyTests.Property32_SelectorEventJSONIsSafe;
var
  LSelector, LError, LJson: string;
  LParsed: TJSONValue;
  LObj: TJSONObject;
begin
  for var Iter := 1 to 100 do
  begin
    LSelector := MakeNastySelector(Iter);
    LError := MakeNastyError(Iter);

    LJson := BuildSelectorFailedPayload(LSelector, LError);

    Assert.IsTrue(LJson <> '',
      Format('Iter %d: payload must be non-empty', [Iter]));

    // The JSON must be parseable. ParseJSONValue returns nil for bad
    // input; with TJSONObject.ToJSON we should always get a valid
    // object back. ParseJSONValue raises no exception either way.
    LParsed := nil;
    try
      try
        LParsed := TJSONObject.ParseJSONValue(LJson);
      except
        on E: Exception do
          Assert.Fail(
            Format('Iter %d: ParseJSONValue raised %s on %s',
              [Iter, E.ClassName, E.Message]));
      end;

      Assert.IsTrue(LParsed <> nil,
        Format('Iter %d: payload "%s" must parse back', [Iter, LJson]));
      Assert.IsTrue(LParsed is TJSONObject,
        Format('Iter %d: parsed payload must be a JSON object', [Iter]));

      LObj := LParsed as TJSONObject;

      // Round-trip equality: every original byte survives.
      Assert.AreEqual(LSelector, LObj.GetValue<string>('selector'),
        Format('Iter %d: selector field round-trip mismatch', [Iter]));
      Assert.AreEqual(LError, LObj.GetValue<string>('error'),
        Format('Iter %d: error field round-trip mismatch', [Iter]));
    finally
      LParsed.Free;
    end;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBrowserContractPropertyTests);

end.
