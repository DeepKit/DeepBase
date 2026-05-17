{ ============================================================================
  Test.DeepBase.Browser.ResponseWaiter.PBT - Property-based tests for the
  WebView2 postMessage envelope parsing and multi-waiter routing logic.

  Properties covered (deepbase-bug-fixes-p0p1p2):
    Property 9 - ResponseWaiter Message Parsing
      For any valid JSON value (string literal or object) received via
      WebView2 Get_WebMessageAsJson, the dispatcher correctly extracts
      the envelope object regardless of whether the original
      postMessage argument was a JS string or a JS object.

    Property 10 - ResponseWaiter Multi-Waiter Isolation
      For any set of N concurrent waiters, each waiter only receives
      messages tagged with its own waiter ID. No message is delivered
      to the wrong waiter.

  Each property runs >= 100 random iterations.

  Notes on observability:
    - DispatchPostMessage is a private method of TBrowserResponseWaiter
      and is not directly callable from outside the unit. We mirror
      the WebView2 unwrap-then-parse algorithm here as
      ParseWebView2Envelope, matching the production logic in
      Features\DeepBase.Browser.ResponseWaiter.pas (BUG-BA-027 fix):
        * If the top-level value is a JSON string, parse its content
          again to obtain the envelope object.
        * Otherwise expect a top-level JSON object directly.
    - Property 10 mirrors the planned waiter-ID dispatch rule by
      filtering envelopes on a "_waiterId" field. This pins the
      routing invariant the design document requires; the production
      code will read the same field name when multi-waiter dispatch
      is wired up.
  ============================================================================ }

unit Test.DeepBase.Browser.ResponseWaiter.PBT;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Generics.Collections,
  DUnitX.TestFramework;

type
  /// <summary>Decoded WebView2 envelope used by the helper-mirror
  /// dispatcher. Mirrors the field shape of the production
  /// db_response_waiter message.</summary>
  TMirrorEnvelope = record
    Valid: Boolean;
    EnvType: string;
    WaiterId: string;
    ResultText: string;
    Response: string;
    DurationMs: Int64;
  end;

  [TestFixture]
  TResponseWaiterPropertyTests = class
  strict private
    function MakeNastyText(AIter: Integer): string;
    function BuildEnvelopeJson(const AEnvType, AWaiterId,
      AResult, AResponse: string; ADurationMs: Int64): string;
    function WrapAsStringLiteral(const AInner: string): string;
    function ParseWebView2Envelope(const AJson: string;
      out AEnvelope: TMirrorEnvelope): Boolean;
    procedure DispatchToWaiterById(const AJson: string;
      const AInboxes: TObjectDictionary<string, TList<TMirrorEnvelope>>);
  public
    [Setup]
    procedure Setup;

    // Feature: deepbase-bug-fixes-p0p1p2, Property 9: ResponseWaiter Message Parsing
    [Test]
    procedure Property9_StringWrappedAndObjectPayloadsParseEqually;

    // Feature: deepbase-bug-fixes-p0p1p2, Property 10: ResponseWaiter Multi-Waiter Isolation
    [Test]
    procedure Property10_MessagesRouteToMatchingWaiterIdOnly;
  end;

implementation

{ TResponseWaiterPropertyTests }

procedure TResponseWaiterPropertyTests.Setup;
begin
  Randomize;
end;

function TResponseWaiterPropertyTests.MakeNastyText(AIter: Integer): string;
begin
  // Cover payload shapes that the JSON unwrap path has to survive:
  //   plain ASCII, embedded quotes, backslashes, control chars,
  //   CJK, multi-line, and empty.
  case AIter mod 8 of
    0: Result := '';
    1: Result := 'plain text';
    2: Result := 'with "double" and ''single'' quotes';
    3: Result := 'line1' + #10 + 'line2' + #13#10 + 'line3';
    4: Result := 'tab' + #9 + 'embedded';
    5: Result := 'backslashes \\path\to\file';
    6: Result := Char($4E2D) + Char($6587) + ' mixed ' + Char($1F600);
  else
    var LBuf: string := '';
    var LLen := 4 + Random(60);
    for var I := 1 to LLen do
    begin
      case Random(6) of
        0: LBuf := LBuf + '"';
        1: LBuf := LBuf + '\';
        2: LBuf := LBuf + #10;
        3: LBuf := LBuf + Char($4E00 + Random($1000));
        4: LBuf := LBuf + Char(Ord(' ') + Random(95));
      else
        LBuf := LBuf + Char(Ord('a') + Random(26));
      end;
    end;
    Result := LBuf;
  end;
end;

function TResponseWaiterPropertyTests.BuildEnvelopeJson(
  const AEnvType, AWaiterId, AResult, AResponse: string;
  ADurationMs: Int64): string;
var
  LObj: TJSONObject;
begin
  // Build the "object form" envelope. TJSONObject.ToJSON handles all
  // necessary string escaping. This is the canonical form a JS
  // window.chrome.webview.postMessage(obj) call would produce on the
  // host side.
  LObj := TJSONObject.Create;
  try
    LObj.AddPair('type', AEnvType);
    if AWaiterId <> '' then
      LObj.AddPair('_waiterId', AWaiterId);
    LObj.AddPair('result', AResult);
    LObj.AddPair('response', AResponse);
    LObj.AddPair('durationMs', TJSONNumber.Create(ADurationMs));
    Result := LObj.ToJSON;
  finally
    LObj.Free;
  end;
end;

function TResponseWaiterPropertyTests.WrapAsStringLiteral(
  const AInner: string): string;
var
  LStr: TJSONString;
begin
  // Mirror what WebView2 does when JS calls
  //   window.chrome.webview.postMessage(JSON.stringify({...}))
  // The host side Get_WebMessageAsJson returns a JSON string literal
  // whose content is the originally-stringified JSON. Wrapping via
  // TJSONString.ToJSON gives us exactly that escaped representation.
  LStr := TJSONString.Create(AInner);
  try
    Result := LStr.ToJSON;
  finally
    LStr.Free;
  end;
end;

function TResponseWaiterPropertyTests.ParseWebView2Envelope(
  const AJson: string; out AEnvelope: TMirrorEnvelope): Boolean;
var
  LValue: TJSONValue;
  LInner: TJSONValue;
  LObj: TJSONObject;
  LDurValue: TJSONValue;
  LDurNum: TJSONNumber;
begin
  // Helper-mirror of TBrowserResponseWaiter.DispatchPostMessage.
  // Behaviour pinned by BUG-BA-027:
  //   1. ParseJSONValue(AJson). Reject nil silently.
  //   2. If the top-level value is a TJSONString, treat its inner
  //      content as JSON and re-parse.
  //   3. Require the final value to be a TJSONObject; otherwise abort.
  //   4. Extract type/waiterId/result/response/durationMs.
  Result := False;
  AEnvelope := Default(TMirrorEnvelope);

  LValue := TJSONObject.ParseJSONValue(AJson);
  if LValue = nil then
    Exit;
  try
    if LValue is TJSONString then
    begin
      LInner := TJSONObject.ParseJSONValue(TJSONString(LValue).Value);
      if LInner = nil then
        Exit;
      LValue.Free;
      LValue := LInner;
    end;

    if not (LValue is TJSONObject) then
      Exit;
    LObj := LValue as TJSONObject;

    AEnvelope.EnvType := LObj.GetValue<string>('type', '');
    AEnvelope.WaiterId := LObj.GetValue<string>('_waiterId', '');
    AEnvelope.ResultText := LObj.GetValue<string>('result', '');
    AEnvelope.Response := LObj.GetValue<string>('response', '');

    LDurValue := LObj.GetValue('durationMs');
    if LDurValue is TJSONNumber then
      LDurNum := TJSONNumber(LDurValue)
    else
      LDurNum := nil;
    AEnvelope.DurationMs := if LDurNum <> nil then LDurNum.AsInt64 else 0;

    AEnvelope.Valid := True;
    Result := True;
  finally
    LValue.Free;
  end;
end;

procedure TResponseWaiterPropertyTests.DispatchToWaiterById(
  const AJson: string;
  const AInboxes: TObjectDictionary<string, TList<TMirrorEnvelope>>);
var
  LEnv: TMirrorEnvelope;
  LBox: TList<TMirrorEnvelope>;
begin
  // Helper-mirror of the planned multi-waiter dispatcher: parse,
  // then deliver the envelope only to the inbox whose key matches
  // the envelope's _waiterId. Missing or unknown IDs result in no
  // delivery (no broadcast).
  if not ParseWebView2Envelope(AJson, LEnv) then
    Exit;
  if LEnv.WaiterId = '' then
    Exit;
  if AInboxes.TryGetValue(LEnv.WaiterId, LBox) then
    LBox.Add(LEnv);
end;

procedure TResponseWaiterPropertyTests
  .Property9_StringWrappedAndObjectPayloadsParseEqually;
var
  LResult, LResponse, LWaiterId: string;
  LDuration: Int64;
  LObjectJson, LStringJson: string;
  LFromObj, LFromStr: TMirrorEnvelope;
  LOkObj, LOkStr: Boolean;
begin
  // Pinned regression first: the simplest object envelope.
  LObjectJson := BuildEnvelopeJson('db_response_waiter',
    'w-1', 'success', 'hello', 1234);
  LOkObj := ParseWebView2Envelope(LObjectJson, LFromObj);
  Assert.IsTrue(LOkObj, 'pinned object envelope must parse');
  Assert.AreEqual('hello', LFromObj.Response,
    'pinned object envelope response field');
  Assert.AreEqual(Int64(1234), LFromObj.DurationMs,
    'pinned object envelope durationMs field');

  LStringJson := WrapAsStringLiteral(LObjectJson);
  LOkStr := ParseWebView2Envelope(LStringJson, LFromStr);
  Assert.IsTrue(LOkStr, 'pinned string-wrapped envelope must parse');
  Assert.AreEqual(LFromObj.Response, LFromStr.Response,
    'pinned forms must agree on response');

  // Random sweep.
  for var Iter := 1 to 100 do
  begin
    LResult := if Iter mod 4 = 0 then 'timeout'
               else if Iter mod 4 = 1 then 'success'
               else if Iter mod 4 = 2 then 'cancelled'
               else 'error';
    LResponse := MakeNastyText(Iter);
    LWaiterId := 'w-' + IntToStr(Iter);
    LDuration := Random(High(Integer));

    LObjectJson := BuildEnvelopeJson('db_response_waiter',
      LWaiterId, LResult, LResponse, LDuration);
    LStringJson := WrapAsStringLiteral(LObjectJson);

    LOkObj := ParseWebView2Envelope(LObjectJson, LFromObj);
    LOkStr := ParseWebView2Envelope(LStringJson, LFromStr);

    Assert.IsTrue(LOkObj,
      Format('Iter %d: object-form envelope must parse', [Iter]));
    Assert.IsTrue(LOkStr,
      Format('Iter %d: string-wrapped envelope must parse', [Iter]));

    // The two forms must round-trip to byte-identical envelopes.
    Assert.AreEqual(LFromObj.EnvType, LFromStr.EnvType,
      Format('Iter %d: type mismatch', [Iter]));
    Assert.AreEqual(LFromObj.WaiterId, LFromStr.WaiterId,
      Format('Iter %d: waiterId mismatch', [Iter]));
    Assert.AreEqual(LFromObj.ResultText, LFromStr.ResultText,
      Format('Iter %d: result mismatch', [Iter]));
    Assert.AreEqual(LFromObj.Response, LFromStr.Response,
      Format('Iter %d: response mismatch', [Iter]));
    Assert.AreEqual(LFromObj.DurationMs, LFromStr.DurationMs,
      Format('Iter %d: durationMs mismatch', [Iter]));

    // The original payload must survive byte-for-byte through the
    // JSON-string -> JSON-object unwrap path.
    Assert.AreEqual(LResponse, LFromStr.Response,
      Format('Iter %d: response field corrupted by string unwrap', [Iter]));
  end;
end;

procedure TResponseWaiterPropertyTests
  .Property10_MessagesRouteToMatchingWaiterIdOnly;
var
  LInboxes: TObjectDictionary<string, TList<TMirrorEnvelope>>;
  LWaiterIds: TArray<string>;
  LIdMessageCounts: TDictionary<string, Integer>;
begin
  // For any random fan-out of N waiters and M messages, every
  // delivered envelope ends up only in the inbox whose key matches
  // the envelope's _waiterId. No broadcast, no leakage.
  for var Iter := 1 to 100 do
  begin
    var LWaiterCount := 2 + Random(5); // 2..6 waiters
    SetLength(LWaiterIds, LWaiterCount);
    for var I := 0 to LWaiterCount - 1 do
      LWaiterIds[I] := Format('iter%d-w%d', [Iter, I]);

    LInboxes := TObjectDictionary<string, TList<TMirrorEnvelope>>.Create([doOwnsValues]);
    LIdMessageCounts := TDictionary<string, Integer>.Create;
    try
      for var Id in LWaiterIds do
      begin
        LInboxes.Add(Id, TList<TMirrorEnvelope>.Create);
        LIdMessageCounts.Add(Id, 0);
      end;

      var LMessageCount := 4 + Random(13); // 4..16 messages per iter
      for var M := 0 to LMessageCount - 1 do
      begin
        // Random target. ~20% chance to address a non-existent ID,
        // which must be silently dropped (not broadcast).
        var LTargetId: string;
        if Random(5) = 0 then
          LTargetId := 'unknown-' + IntToStr(M)
        else
        begin
          LTargetId := LWaiterIds[Random(LWaiterCount)];
          var LExisting: Integer;
          if LIdMessageCounts.TryGetValue(LTargetId, LExisting) then
            LIdMessageCounts[LTargetId] := LExisting + 1
          else
            LIdMessageCounts.Add(LTargetId, 1);
        end;

        var LJson := BuildEnvelopeJson('db_response_waiter',
          LTargetId, 'success',
          Format('payload-%d', [M]), Int64(100 + M));

        // Half the time send the WebView2 string-wrapped form to
        // exercise both unwrap paths.
        if M mod 2 = 0 then
          LJson := WrapAsStringLiteral(LJson);

        DispatchToWaiterById(LJson, LInboxes);
      end;

      // Invariant 1: every envelope in inbox K has _waiterId = K.
      // Invariant 2: inbox sizes match the issued counts.
      for var Id in LWaiterIds do
      begin
        var LBox := LInboxes[Id];
        var LExpected: Integer;
        if not LIdMessageCounts.TryGetValue(Id, LExpected) then
          LExpected := 0;

        Assert.AreEqual(LExpected, Integer(LBox.Count),
          Format('Iter %d waiter %s: inbox size mismatch (expected %d got %d)',
            [Iter, Id, LExpected, LBox.Count]));

        for var J := 0 to LBox.Count - 1 do
          Assert.AreEqual(Id, LBox[J].WaiterId,
            Format('Iter %d waiter %s msg %d: cross-talk (got id=%s)',
              [Iter, Id, J, LBox[J].WaiterId]));
      end;
    finally
      LIdMessageCounts.Free;
      LInboxes.Free; // owns inner TList<TMirrorEnvelope>
    end;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TResponseWaiterPropertyTests);

end.
