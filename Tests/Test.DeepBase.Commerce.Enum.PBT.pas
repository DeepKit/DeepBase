{ ============================================================================
  Test.DeepBase.Commerce.Enum.PBT - Property-based tests for Commerce
  enum string serialization round-trip.

  Properties covered (deepbase-round2-fixes):
    Property 22: For every value of TCommerceOrderStatus,
                 TCommercePaymentStatus, and TCommercePaymentProvider,
                 calling the public CommerceXxxToStr converter must
                 produce a non-empty stable string, and a faithful
                 mirror parser must round-trip the value back to the
                 original enum (ToStr is therefore injective and the
                 implicit FromStr is its inverse). The Round-2 fix
                 changed the Supabase adapter to write enum values as
                 these stable strings rather than ordinal integers.

  Each property runs 100 iterations:
    - For each enum we sweep every constant once per pass and shuffle
      the order across passes so that the test does not lock in a
      particular declaration order.

  Notes on observability:
    - The forward converters (ToStr) are exported from
      DeepBase.Commerce.Types.
    - The reverse converters (OrderStatusFromString /
      PaymentStatusFromString) live in the implementation section of
      DeepBase.Commerce.Backend.Http and DeepBase.Commerce.SafeClient
      so they are not callable from this test unit. We mirror the
      mapping locally; the test enforces that ToStr produces exactly
      the strings the inverse parser accepts (case-insensitive in
      production code, exact-match here for stability).
  ============================================================================ }

unit Test.DeepBase.Commerce.Enum.PBT;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  DUnitX.TestFramework,
  DeepBase.Commerce.Types;

type
  [TestFixture]
  [Category('PBT')]
  TCommerceEnumPropertyTests = class
  strict private
    function OrderStatusFromString(
      const AValue: string): TCommerceOrderStatus;
    function PaymentStatusFromString(
      const AValue: string): TCommercePaymentStatus;
    function PaymentProviderFromString(
      const AValue: string): TCommercePaymentProvider;
  public
    [Setup]
    procedure Setup;

    // Feature: deepbase-round2-fixes, Property 22 (order status)
    [Test]
    procedure Property22_OrderStatusRoundTrip;

    // Feature: deepbase-round2-fixes, Property 22 (payment status)
    [Test]
    procedure Property22_PaymentStatusRoundTrip;

    // Feature: deepbase-round2-fixes, Property 22 (payment provider)
    [Test]
    procedure Property22_PaymentProviderRoundTrip;
  end;

implementation

{ TCommerceEnumPropertyTests }

procedure TCommerceEnumPropertyTests.Setup;
begin
  Randomize;
end;

function TCommerceEnumPropertyTests.OrderStatusFromString(
  const AValue: string): TCommerceOrderStatus;
begin
  // Mirror of DeepBase.Commerce.Backend.Http.OrderStatusFromString.
  // Default branch (refunded) follows the production convention.
  if SameText(AValue, 'created') then
    Result := cosCreated
  else if SameText(AValue, 'paying') then
    Result := cosPaying
  else if SameText(AValue, 'paid') then
    Result := cosPaid
  else if SameText(AValue, 'closed') then
    Result := cosClosed
  else if SameText(AValue, 'failed') then
    Result := cosFailed
  else if SameText(AValue, 'refunded') then
    Result := cosRefunded
  else
    raise EArgumentException.CreateFmt(
      'Unknown order status "%s"', [AValue]);
end;

function TCommerceEnumPropertyTests.PaymentStatusFromString(
  const AValue: string): TCommercePaymentStatus;
begin
  if SameText(AValue, 'created') then
    Result := cpsCreated
  else if SameText(AValue, 'pending') then
    Result := cpsPending
  else if SameText(AValue, 'paid') then
    Result := cpsPaid
  else if SameText(AValue, 'failed') then
    Result := cpsFailed
  else if SameText(AValue, 'refunded') then
    Result := cpsRefunded
  else
    raise EArgumentException.CreateFmt(
      'Unknown payment status "%s"', [AValue]);
end;

function TCommerceEnumPropertyTests.PaymentProviderFromString(
  const AValue: string): TCommercePaymentProvider;
begin
  if SameText(AValue, 'wechat_pay') then
    Result := cppWeChatPay
  else if SameText(AValue, 'alipay') then
    Result := cppAlipay
  else if SameText(AValue, 'stripe') then
    Result := cppStripe
  else if SameText(AValue, 'paypal') then
    Result := cppPayPal
  else if SameText(AValue, 'manual') then
    Result := cppManual
  else if SameText(AValue, 'external') then
    Result := cppExternal
  else
    raise EArgumentException.CreateFmt(
      'Unknown payment provider "%s"', [AValue]);
end;

procedure TCommerceEnumPropertyTests.Property22_OrderStatusRoundTrip;
const
  CAllStatuses: array[0..5] of TCommerceOrderStatus = (
    cosCreated, cosPaying, cosPaid, cosClosed, cosFailed, cosRefunded);
var
  LSeen: TDictionary<string, TCommerceOrderStatus>;
  LIdx, LSwap: Integer;
  LTmp: TCommerceOrderStatus;
  LOrdered: array of TCommerceOrderStatus;
  LStr: string;
  LRoundTrip: TCommerceOrderStatus;
begin
  for var Iter := 1 to 100 do
  begin
    LSeen := TDictionary<string, TCommerceOrderStatus>.Create;
    try
      // Shuffle the iteration order so we do not bake declaration
      // ordering into the property check.
      SetLength(LOrdered, Length(CAllStatuses));
      for LIdx := 0 to High(CAllStatuses) do
        LOrdered[LIdx] := CAllStatuses[LIdx];
      for LIdx := High(LOrdered) downto 1 do
      begin
        LSwap := Random(LIdx + 1);
        LTmp := LOrdered[LIdx];
        LOrdered[LIdx] := LOrdered[LSwap];
        LOrdered[LSwap] := LTmp;
      end;

      for var LStatus in LOrdered do
      begin
        LStr := CommerceOrderStatusToStr(LStatus);

        Assert.IsTrue(LStr <> '',
          Format('Iter %d: ToStr(%d) returned empty string',
            [Iter, Ord(LStatus)]));

        // Each enum value must serialize to a UNIQUE string. If two
        // different enums collided on the same string the inverse
        // mapping would be ambiguous.
        if LSeen.ContainsKey(LStr) then
          Assert.AreEqual(Ord(LStatus), Ord(LSeen[LStr]),
            Format('Iter %d: string "%s" maps to %d AND %d',
              [Iter, LStr, Ord(LSeen[LStr]), Ord(LStatus)]))
        else
          LSeen.Add(LStr, LStatus);

        LRoundTrip := OrderStatusFromString(LStr);
        Assert.AreEqual(Ord(LStatus), Ord(LRoundTrip),
          Format('Iter %d: round-trip OrderStatus(%d) -> "%s" -> %d',
            [Iter, Ord(LStatus), LStr, Ord(LRoundTrip)]));
      end;

      Assert.AreEqual<Integer>(Length(CAllStatuses), LSeen.Count,
        Format('Iter %d: every enum must produce a distinct string',
          [Iter]));
    finally
      LSeen.Free;
    end;
  end;
end;

procedure TCommerceEnumPropertyTests.Property22_PaymentStatusRoundTrip;
const
  CAllStatuses: array[0..4] of TCommercePaymentStatus = (
    cpsCreated, cpsPending, cpsPaid, cpsFailed, cpsRefunded);
var
  LSeen: TDictionary<string, TCommercePaymentStatus>;
  LIdx, LSwap: Integer;
  LTmp: TCommercePaymentStatus;
  LOrdered: array of TCommercePaymentStatus;
  LStr: string;
  LRoundTrip: TCommercePaymentStatus;
begin
  for var Iter := 1 to 100 do
  begin
    LSeen := TDictionary<string, TCommercePaymentStatus>.Create;
    try
      SetLength(LOrdered, Length(CAllStatuses));
      for LIdx := 0 to High(CAllStatuses) do
        LOrdered[LIdx] := CAllStatuses[LIdx];
      for LIdx := High(LOrdered) downto 1 do
      begin
        LSwap := Random(LIdx + 1);
        LTmp := LOrdered[LIdx];
        LOrdered[LIdx] := LOrdered[LSwap];
        LOrdered[LSwap] := LTmp;
      end;

      for var LStatus in LOrdered do
      begin
        LStr := CommercePaymentStatusToStr(LStatus);

        Assert.IsTrue(LStr <> '',
          Format('Iter %d: ToStr(%d) returned empty string',
            [Iter, Ord(LStatus)]));

        if LSeen.ContainsKey(LStr) then
          Assert.AreEqual(Ord(LStatus), Ord(LSeen[LStr]),
            Format('Iter %d: string "%s" maps to %d AND %d',
              [Iter, LStr, Ord(LSeen[LStr]), Ord(LStatus)]))
        else
          LSeen.Add(LStr, LStatus);

        LRoundTrip := PaymentStatusFromString(LStr);
        Assert.AreEqual(Ord(LStatus), Ord(LRoundTrip),
          Format('Iter %d: round-trip PaymentStatus(%d) -> "%s" -> %d',
            [Iter, Ord(LStatus), LStr, Ord(LRoundTrip)]));
      end;

      Assert.AreEqual<Integer>(Length(CAllStatuses), LSeen.Count,
        Format('Iter %d: every enum must produce a distinct string',
          [Iter]));
    finally
      LSeen.Free;
    end;
  end;
end;

procedure TCommerceEnumPropertyTests.Property22_PaymentProviderRoundTrip;
const
  CAllProviders: array[0..5] of TCommercePaymentProvider = (
    cppWeChatPay, cppAlipay, cppStripe, cppPayPal, cppManual,
    cppExternal);
var
  LSeen: TDictionary<string, TCommercePaymentProvider>;
  LIdx, LSwap: Integer;
  LTmp: TCommercePaymentProvider;
  LOrdered: array of TCommercePaymentProvider;
  LStr: string;
  LRoundTrip: TCommercePaymentProvider;
begin
  for var Iter := 1 to 100 do
  begin
    LSeen := TDictionary<string, TCommercePaymentProvider>.Create;
    try
      SetLength(LOrdered, Length(CAllProviders));
      for LIdx := 0 to High(CAllProviders) do
        LOrdered[LIdx] := CAllProviders[LIdx];
      for LIdx := High(LOrdered) downto 1 do
      begin
        LSwap := Random(LIdx + 1);
        LTmp := LOrdered[LIdx];
        LOrdered[LIdx] := LOrdered[LSwap];
        LOrdered[LSwap] := LTmp;
      end;

      for var LProv in LOrdered do
      begin
        LStr := CommercePaymentProviderToStr(LProv);

        Assert.IsTrue(LStr <> '',
          Format('Iter %d: ToStr(%d) returned empty string',
            [Iter, Ord(LProv)]));

        if LSeen.ContainsKey(LStr) then
          Assert.AreEqual(Ord(LProv), Ord(LSeen[LStr]),
            Format('Iter %d: string "%s" maps to %d AND %d',
              [Iter, LStr, Ord(LSeen[LStr]), Ord(LProv)]))
        else
          LSeen.Add(LStr, LProv);

        LRoundTrip := PaymentProviderFromString(LStr);
        Assert.AreEqual(Ord(LProv), Ord(LRoundTrip),
          Format('Iter %d: round-trip PaymentProvider(%d) -> "%s" -> %d',
            [Iter, Ord(LProv), LStr, Ord(LRoundTrip)]));
      end;

      Assert.AreEqual<Integer>(Length(CAllProviders), LSeen.Count,
        Format('Iter %d: every enum must produce a distinct string',
          [Iter]));
    finally
      LSeen.Free;
    end;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TCommerceEnumPropertyTests);

end.
