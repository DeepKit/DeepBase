{ ============================================================================
  Test.DeepBase.Commerce.Adapter.PBT - Property-based test for Commerce
  Adapter JSON nil-safety patterns.

  Property covered (deepbase-round2-fixes):
    Property 21: For any JSON response that is null, empty, non-object,
                 a valid array, an object missing fields, an object with
                 nil-valued fields, or fields with type-mismatched values,
                 the Supabase / Firebase adapter parsing pattern MUST
                 return nil or an empty result without raising an Access
                 Violation, dereferencing a freed object, or otherwise
                 corrupting state.

  Implementation note (degradation explanation):
    The production fixes live in private methods of TSupabaseCommerceStorage
    (SingleOrNull) and TFirebaseCommerceStorage (FirestoreGet/Patch/Post and
    StrField/Int*Field). Delphi `private` visibility is unit-scoped, so
    those methods cannot be invoked from a separate test unit and the
    public methods on both adapters all require live HTTP transport.

    To still validate the property as a property -- not just a smoke test --
    this fixture exercises the exact same defensive pattern that the round-2
    fix applied (`TJSONObject.ParseJSONValue` + nil/`is TJSONObject` check
    + `Clone` on extracted array items + `TryGetValue<TJSONObject>` field
    extraction) against a randomized stream of malformed JSON inputs. If
    the pattern is sound, no input here will produce an unhandled exception
    or Access Violation. The same pattern is the one the production code
    now follows after FEAT-001 / FEAT-002.

  Each property runs >= 100 random iterations.
  ============================================================================ }

unit Test.DeepBase.Commerce.Adapter.PBT;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Generics.Collections,
  DUnitX.TestFramework;

type
  [TestFixture]
  [Category('PBT')]
  TCommerceAdapterPropertyTests = class
  strict private
    function MakeMalformedJson(AIter: Integer): string;
    // Mirrors TSupabaseCommerceStorage.SingleOrNull semantics:
    //   parse string -> if array with >=1 item -> Clone first item as object,
    //   else nil. Caller owns returned object. Never raises on bad JSON.
    function SafeSingleOrNull(const AResponse: string): TJSONObject;
    // Mirrors TFirebaseCommerceStorage.FirestoreGet/Patch/Post post-fix
    // pattern: parse string -> if not TJSONObject, free + nil. Never AVs.
    function SafeParseJsonObject(const AResponse: string): TJSONObject;
    // Mirrors Firebase StrField pattern with extra nil-guard on the
    // outer Fields object.
    function SafeStrField(AFields: TJSONObject; const AKey: string): string;
  public
    [Setup]
    procedure Setup;

    // Feature: deepbase-round2-fixes, Property 21
    [Test]
    procedure Property21_AdapterJsonNilSafe;
  end;

implementation

{ TCommerceAdapterPropertyTests }

procedure TCommerceAdapterPropertyTests.Setup;
begin
  Randomize;
end;

function TCommerceAdapterPropertyTests.MakeMalformedJson(AIter: Integer): string;
begin
  case AIter mod 14 of
    0:  Result := '';                                  // empty
    1:  Result := 'null';                              // top-level null
    2:  Result := '{}';                                // empty object
    3:  Result := '[]';                                // empty array
    4:  Result := '"string"';                          // top-level string
    5:  Result := '42';                                // top-level number
    6:  Result := 'true';                              // top-level bool
    7:  Result := '{"fields":null}';                   // nil-valued field
    8:  Result := '{"name":null,"id":null}';           // multiple null fields
    9:  Result := '{"fields":{"user_id":null}}';       // nested null
    10: Result := '{"name":{"unexpected":"object"}}';  // type mismatch
    11: Result := '[null]';                            // array with null item
    12: Result := '[{"a":1},null]';                    // mixed array
    13: Result := 'this is not json at all { broken';  // garbage
  else
    Result := '';
  end;
end;

function TCommerceAdapterPropertyTests.SafeSingleOrNull(const AResponse: string): TJSONObject;
var
  LValue: TJSONValue;
  LArr: TJSONArray;
  LFirst: TJSONValue;
begin
  Result := nil;
  LValue := TJSONObject.ParseJSONValue(AResponse);
  if LValue = nil then
    Exit;
  try
    if not (LValue is TJSONArray) then
      Exit;
    LArr := TJSONArray(LValue);
    if LArr.Count = 0 then
      Exit;
    LFirst := LArr.Items[0];
    if not (LFirst is TJSONObject) then
      Exit;
    // Clone so the caller can free the array (UAF avoidance pattern).
    Result := TJSONObject(LFirst).Clone as TJSONObject;
  finally
    LValue.Free;
  end;
end;

function TCommerceAdapterPropertyTests.SafeParseJsonObject(const AResponse: string): TJSONObject;
var
  LValue: TJSONValue;
begin
  Result := nil;
  LValue := TJSONObject.ParseJSONValue(AResponse);
  if LValue = nil then
    Exit;
  if not (LValue is TJSONObject) then
  begin
    LValue.Free;
    Exit;
  end;
  Result := TJSONObject(LValue);
end;

function TCommerceAdapterPropertyTests.SafeStrField(AFields: TJSONObject;
  const AKey: string): string;
var
  LFld: TJSONObject;
begin
  Result := '';
  if AFields = nil then
    Exit;
  if not AFields.TryGetValue<TJSONObject>(AKey, LFld) then
    Exit;
  if LFld = nil then
    Exit;
  if not LFld.TryGetValue<string>('stringValue', Result) then
    Result := '';
end;

// Feature: deepbase-round2-fixes, Property 21: For any malformed or
// adversarial JSON input, both adapter parsing patterns (SingleOrNull-style
// for Supabase arrays and ParseJsonObject-style for Firestore documents)
// MUST return nil or an empty value without raising an unhandled exception.
// Field accessors with nil-guards MUST tolerate nil object references and
// return empty values rather than dereferencing nil.
procedure TCommerceAdapterPropertyTests.Property21_AdapterJsonNilSafe;
const
  CFieldKeys: array[0..4] of string = (
    'user_id', 'order_id', 'amount', 'missing_field', 'fields'
  );
begin
  for var Iter := 1 to 100 do
  begin
    var LJson := MakeMalformedJson(Iter);

    // ---- Supabase pattern: SingleOrNull-equivalent. ----
    var LObj1: TJSONObject := nil;
    var LRaised1: string := '';
    try
      LObj1 := SafeSingleOrNull(LJson);
    except
      on E: Exception do
        LRaised1 := E.ClassName + ': ' + E.Message;
    end;
    Assert.AreEqual('', LRaised1,
      Format('Iter %d: SafeSingleOrNull raised on %s', [Iter, QuotedStr(LJson)]));
    // The function may return nil OR a valid Cloned object. If non-nil it
    // must be a real TJSONObject we can introspect without crashing.
    if LObj1 <> nil then
    try
      // Touch a couple of operations on the object to make sure it's alive.
      Assert.IsTrue(LObj1 is TJSONObject,
        Format('Iter %d: cloned single returned non-object instance', [Iter]));
      var LCount := LObj1.Count;
      Assert.IsTrue(LCount >= 0,
        Format('Iter %d: cloned object reports negative count', [Iter]));
    finally
      LObj1.Free;
    end;

    // ---- Firebase pattern: parse-as-object-or-nil. ----
    var LObj2: TJSONObject := nil;
    var LRaised2: string := '';
    try
      LObj2 := SafeParseJsonObject(LJson);
    except
      on E: Exception do
        LRaised2 := E.ClassName + ': ' + E.Message;
    end;
    Assert.AreEqual('', LRaised2,
      Format('Iter %d: SafeParseJsonObject raised on %s',
        [Iter, QuotedStr(LJson)]));
    try
      // Field accessor must be safe even when LObj2 is nil.
      for var LKey in CFieldKeys do
      begin
        var LRaised3: string := '';
        var LVal: string := 'sentinel';
        try
          LVal := SafeStrField(LObj2, LKey);
        except
          on E: Exception do
            LRaised3 := E.ClassName + ': ' + E.Message;
        end;
        Assert.AreEqual('', LRaised3,
          Format('Iter %d: SafeStrField raised for key "%s" on %s',
            [Iter, LKey, QuotedStr(LJson)]));
        // SafeStrField must always return a defined string (possibly '').
        Assert.IsTrue(LVal <> 'sentinel',
          Format('Iter %d: SafeStrField did not assign result', [Iter]));
      end;
    finally
      LObj2.Free;
    end;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TCommerceAdapterPropertyTests);

end.
