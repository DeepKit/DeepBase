{ ============================================================================
  Test.DeepBase.Commerce.Service.PBT - Property-based tests for the
  Round-2 commerce-service fixes.

  Properties covered (deepbase-round2-fixes):
    Property 23: For any order whose Status is in the terminal set
                 [cosPaid, cosFailed, cosClosed, cosRefunded],
                 BeginPayment must raise an
                 EDeepBaseCommerceValidationError. Orders in the
                 non-terminal set [cosCreated, cosPaying] must NOT
                 be rejected on terminal-state grounds (they may
                 still raise other validation errors such as missing
                 gateway, but never the terminal-state guard).
    Property 24: For any entitlement with quota Q (1 <= Q <= 20)
                 and N concurrent ConsumeEntitlement(1) calls where
                 N > Q, exactly Q calls succeed and the final
                 RemainingQuota == 0. The fix's atomic
                 "UPDATE WHERE remaining >= count" pattern is
                 modelled by a TLockedCommerceStorage decorator
                 that serialises the consume operation, mirroring
                 SQLite's row-level WHERE atomicity.

  Each property runs >= 100 random iterations.

  Notes on observability and degradation:
    - The production storage backends are HTTP-only
      (TSupabaseCommerceStorage, TFirebaseCommerceStorage,
      TCommerceHttpStorage) and cannot be exercised from a unit
      test fixture. The Round-2 fix's atomicity guarantee lives in
      the storage layer's WHERE clause; we mirror that by wrapping
      TInMemoryCommerceStorage in a TMonitor-protected decorator
      that serialises ConsumeEntitlement under a single critical
      section. This is a faithful in-memory model of "UPDATE
      WHERE remaining_quota >= :count" — the WHERE check and the
      decrement happen as one indivisible step.
    - For Property 23 we do NOT register a payment gateway. The
      BeginPayment terminal-state guard runs BEFORE the gateway
      lookup (see DeepBase.Commerce.Service.pas line 195). Orders
      in non-terminal states therefore reach the gateway lookup
      and raise EDeepBaseCommercePaymentError ("gateway not
      registered"); orders in terminal states raise
      EDeepBaseCommerceValidationError on the guard. We assert on
      the exception class to differentiate.
  ============================================================================ }

unit Test.DeepBase.Commerce.Service.PBT;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Threading,
  System.Generics.Collections,
  DUnitX.TestFramework,
  DeepBase.Commerce.Types,
  DeepBase.Commerce.Storage,
  DeepBase.Commerce.Service;

type
  /// <summary>
  /// Mutex-wrapped commerce storage. Mirrors the atomicity an SQL
  /// "UPDATE ... WHERE remaining_quota >= :count" provides at the
  /// storage layer. Used by Property 24 to model the fix's
  /// no-oversell guarantee.
  /// </summary>
  TLockedCommerceStorage = class(TInterfacedObject, ICommerceStorage)
  strict private
    FInner: ICommerceStorage;
    FLock: TObject;
  public
    constructor Create(const AInner: ICommerceStorage);
    destructor Destroy; override;

    function FindUserById(const AUserId: string;
      out AUser: TCommerceUserData): Boolean;
    function FindUserByIdentity(AProvider: TCommerceAuthProvider;
      const AProviderUserId, AAppId: string;
      out AUser: TCommerceUserData): Boolean;
    procedure UpsertUser(const AUser: TCommerceUserData);
    procedure LinkIdentity(const AIdentity: TCommerceIdentityData);

    function FindProduct(const AAppId, AProductId: string;
      out AProduct: TCommerceProductData): Boolean;
    procedure UpsertProduct(const AProduct: TCommerceProductData);

    procedure CreateOrder(const AOrder: TCommerceOrderData);
    function FindOrderById(const AOrderId: string;
      out AOrder: TCommerceOrderData): Boolean;
    function FindOrderByOutTradeNo(const AOutTradeNo: string;
      out AOrder: TCommerceOrderData): Boolean;
    procedure UpdateOrder(const AOrder: TCommerceOrderData);

    procedure CreatePayment(const APayment: TCommercePaymentData);
    function FindPaymentByOrderId(const AOrderId: string;
      out APayment: TCommercePaymentData): Boolean;
    procedure UpdatePayment(const APayment: TCommercePaymentData);

    procedure UpsertEntitlement(const AEntitlement: TCommerceEntitlementData);
    function ListEntitlements(const AUserId, AAppId: string): TCommerceEntitlementArray;
    function FindEntitlement(const AUserId, AAppId, ACode: string;
      out AEntitlement: TCommerceEntitlementData): Boolean;
    function ConsumeEntitlement(const AEntitlementId: string; ACount: Integer;
      out AEntitlement: TCommerceEntitlementData): Boolean;
  end;

  [TestFixture]
  [Category('PBT')]
  TCommerceServicePropertyTests = class
  public
    [Setup]
    procedure Setup;

    // Feature: deepbase-round2-fixes, Property 23
    [Test]
    procedure Property23_TerminalOrdersRejected;

    // Feature: deepbase-round2-fixes, Property 24
    [Test]
    procedure Property24_AtomicConsumeNoOversell;
  end;

implementation

{ TLockedCommerceStorage }

constructor TLockedCommerceStorage.Create(const AInner: ICommerceStorage);
begin
  inherited Create;
  FInner := AInner;
  FLock := TObject.Create;
end;

destructor TLockedCommerceStorage.Destroy;
begin
  FInner := nil;
  FreeAndNil(FLock);
  inherited;
end;

function TLockedCommerceStorage.FindUserById(const AUserId: string;
  out AUser: TCommerceUserData): Boolean;
begin
  TMonitor.Enter(FLock);
  try
    Result := FInner.FindUserById(AUserId, AUser);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TLockedCommerceStorage.FindUserByIdentity(
  AProvider: TCommerceAuthProvider;
  const AProviderUserId, AAppId: string;
  out AUser: TCommerceUserData): Boolean;
begin
  TMonitor.Enter(FLock);
  try
    Result := FInner.FindUserByIdentity(AProvider, AProviderUserId, AAppId, AUser);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TLockedCommerceStorage.UpsertUser(const AUser: TCommerceUserData);
begin
  TMonitor.Enter(FLock);
  try
    FInner.UpsertUser(AUser);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TLockedCommerceStorage.LinkIdentity(
  const AIdentity: TCommerceIdentityData);
begin
  TMonitor.Enter(FLock);
  try
    FInner.LinkIdentity(AIdentity);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TLockedCommerceStorage.FindProduct(const AAppId, AProductId: string;
  out AProduct: TCommerceProductData): Boolean;
begin
  TMonitor.Enter(FLock);
  try
    Result := FInner.FindProduct(AAppId, AProductId, AProduct);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TLockedCommerceStorage.UpsertProduct(
  const AProduct: TCommerceProductData);
begin
  TMonitor.Enter(FLock);
  try
    FInner.UpsertProduct(AProduct);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TLockedCommerceStorage.CreateOrder(
  const AOrder: TCommerceOrderData);
begin
  TMonitor.Enter(FLock);
  try
    FInner.CreateOrder(AOrder);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TLockedCommerceStorage.FindOrderById(const AOrderId: string;
  out AOrder: TCommerceOrderData): Boolean;
begin
  TMonitor.Enter(FLock);
  try
    Result := FInner.FindOrderById(AOrderId, AOrder);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TLockedCommerceStorage.FindOrderByOutTradeNo(
  const AOutTradeNo: string; out AOrder: TCommerceOrderData): Boolean;
begin
  TMonitor.Enter(FLock);
  try
    Result := FInner.FindOrderByOutTradeNo(AOutTradeNo, AOrder);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TLockedCommerceStorage.UpdateOrder(
  const AOrder: TCommerceOrderData);
begin
  TMonitor.Enter(FLock);
  try
    FInner.UpdateOrder(AOrder);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TLockedCommerceStorage.CreatePayment(
  const APayment: TCommercePaymentData);
begin
  TMonitor.Enter(FLock);
  try
    FInner.CreatePayment(APayment);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TLockedCommerceStorage.FindPaymentByOrderId(const AOrderId: string;
  out APayment: TCommercePaymentData): Boolean;
begin
  TMonitor.Enter(FLock);
  try
    Result := FInner.FindPaymentByOrderId(AOrderId, APayment);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TLockedCommerceStorage.UpdatePayment(
  const APayment: TCommercePaymentData);
begin
  TMonitor.Enter(FLock);
  try
    FInner.UpdatePayment(APayment);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TLockedCommerceStorage.UpsertEntitlement(
  const AEntitlement: TCommerceEntitlementData);
begin
  TMonitor.Enter(FLock);
  try
    FInner.UpsertEntitlement(AEntitlement);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TLockedCommerceStorage.ListEntitlements(const AUserId,
  AAppId: string): TCommerceEntitlementArray;
begin
  TMonitor.Enter(FLock);
  try
    Result := FInner.ListEntitlements(AUserId, AAppId);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TLockedCommerceStorage.FindEntitlement(const AUserId, AAppId,
  ACode: string; out AEntitlement: TCommerceEntitlementData): Boolean;
begin
  TMonitor.Enter(FLock);
  try
    Result := FInner.FindEntitlement(AUserId, AAppId, ACode, AEntitlement);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TLockedCommerceStorage.ConsumeEntitlement(
  const AEntitlementId: string; ACount: Integer;
  out AEntitlement: TCommerceEntitlementData): Boolean;
begin
  // This is the key method for Property 24. The lock here mirrors
  // the atomicity that "UPDATE entitlements SET remaining_quota = ..
  // WHERE remaining_quota >= :count" provides at the SQL layer.
  TMonitor.Enter(FLock);
  try
    Result := FInner.ConsumeEntitlement(AEntitlementId, ACount, AEntitlement);
  finally
    TMonitor.Exit(FLock);
  end;
end;

{ TCommerceServicePropertyTests }

procedure TCommerceServicePropertyTests.Setup;
begin
  Randomize;
end;

procedure TCommerceServicePropertyTests.Property23_TerminalOrdersRejected;
const
  CIters = 100;
const
  CTerminal: array[0..3] of TCommerceOrderStatus =
    (cosPaid, cosFailed, cosClosed, cosRefunded);
  CNonTerminal: array[0..1] of TCommerceOrderStatus =
    (cosCreated, cosPaying);
begin
  for var Iter := 1 to CIters do
  begin
    var LIsTerminal: Boolean := (Iter mod 2) = 0;
    var LStatus: TCommerceOrderStatus;
    if LIsTerminal then
      LStatus := CTerminal[Random(Length(CTerminal))]
    else
      LStatus := CNonTerminal[Random(Length(CNonTerminal))];

    var LStorage: ICommerceStorage := TInMemoryCommerceStorage.Create;
    var LService := TDeepBaseCommerceService.Create(LStorage);
    try
      var LOrder: TCommerceOrderData;
      LOrder.OrderId := 'ord-' + IntToStr(Iter);
      LOrder.UserId := 'user-1';
      LOrder.AppId := 'app';
      LOrder.ProductId := 'prod-1';
      LOrder.OutTradeNo := 'OT-' + IntToStr(Iter);
      LOrder.Title := 'Test Order';
      LOrder.AmountMinor := 9900;
      LOrder.Currency := 'CNY';
      LOrder.Status := LStatus;
      LOrder.CreatedAtISO := CommerceNowISO;
      LOrder.PaidAtISO := '';
      LStorage.CreateOrder(LOrder);

      // P1 fix #3 added a user-existence check in BeginPayment,
      // so we must ensure the referenced user exists and is active.
      var LUser: TCommerceUserData;
      LUser.UserId := 'user-1';
      LUser.DisplayName := 'Test User';
      LUser.Email := '';
      LUser.Phone := '';
      LUser.IsActive := True;
      LUser.CreatedAtISO := CommerceNowISO;
      LUser.UpdatedAtISO := CommerceNowISO;
      LStorage.UpsertUser(LUser);

      var LRaisedClass: TClass := nil;
      try
        LService.BeginPayment(LOrder.OrderId, cppWeChatPay,
          cpcNative, '');
      except
        on E: Exception do
          LRaisedClass := E.ClassType;
      end;

      Assert.IsNotNull(LRaisedClass,
        Format('Iter %d (%s/status=%d): BeginPayment must raise',
          [Iter,
           (if LIsTerminal then 'terminal' else 'non-terminal'),
           Ord(LStatus)]));

      if LIsTerminal then
      begin
        // Property 23: terminal orders must be rejected by the
        // dedicated validation guard (exception class
        // EDeepBaseCommerceValidationError), NOT by some other
        // late-binding error.
        Assert.IsTrue(
          LRaisedClass.InheritsFrom(EDeepBaseCommerceValidationError),
          Format('Iter %d (terminal/status=%d): expected ' +
                 'EDeepBaseCommerceValidationError, got %s',
            [Iter, Ord(LStatus), LRaisedClass.ClassName]));
      end
      else
      begin
        // Non-terminal: the terminal-state guard MUST NOT fire. The
        // call should pass that guard and fail later (here, on the
        // missing gateway -> EDeepBaseCommercePaymentError).
        Assert.IsFalse(
          LRaisedClass.InheritsFrom(EDeepBaseCommerceValidationError) and
          not LRaisedClass.InheritsFrom(EDeepBaseCommercePaymentError),
          Format('Iter %d (non-terminal/status=%d): terminal-state ' +
                 'guard fired on non-terminal order; got %s',
            [Iter, Ord(LStatus), LRaisedClass.ClassName]));
        Assert.IsTrue(
          LRaisedClass.InheritsFrom(EDeepBaseCommercePaymentError),
          Format('Iter %d (non-terminal/status=%d): expected ' +
                 'EDeepBaseCommercePaymentError (gateway missing), got %s',
            [Iter, Ord(LStatus), LRaisedClass.ClassName]));
      end;
    finally
      LService.Free;
      LStorage := nil;
    end;
  end;
end;

procedure TCommerceServicePropertyTests.Property24_AtomicConsumeNoOversell;
const
  CIters = 100;
begin
  for var Iter := 1 to CIters do
  begin
    var LQuota: Integer := 1 + Random(20);            // Q in 1..20
    var LExtraThreads: Integer := 1 + Random(8);       // surplus 1..8
    var LThreadCount: Integer := LQuota + LExtraThreads;

    var LInner: ICommerceStorage := TInMemoryCommerceStorage.Create;
    var LStorage: ICommerceStorage := TLockedCommerceStorage.Create(LInner);
    try
      var LEnt: TCommerceEntitlementData;
      LEnt.EntitlementId := 'ent-' + IntToStr(Iter);
      LEnt.UserId := 'user-1';
      LEnt.AppId := 'app';
      LEnt.ProductId := 'prod-1';
      LEnt.Code := 'feature.x';
      LEnt.Status := cesActive;
      LEnt.ValidFromISO := CommerceNowISO;
      LEnt.ValidUntilISO := '';
      LEnt.RemainingQuota := LQuota;
      LEnt.SourceOrderId := '';
      LStorage.UpsertEntitlement(LEnt);

      var LSuccess := 0;
      var LFailure := 0;

      // TParallel.For races LThreadCount workers, each calling
      // ConsumeEntitlement(1) directly on the synchronised storage.
      // Calling storage.ConsumeEntitlement (rather than service.
      // ConsumeEntitlement) keeps the property focused on the SQL
      // atomicity guarantee being modelled, rather than on the
      // service-layer Find+Decide+Consume orchestration which is a
      // separate concern.
      TParallel.For(0, LThreadCount - 1,
        procedure(AIndex: Integer)
        var
          LOut: TCommerceEntitlementData;
        begin
          if LStorage.ConsumeEntitlement(LEnt.EntitlementId, 1, LOut) then
            TInterlocked.Increment(LSuccess)
          else
            TInterlocked.Increment(LFailure);
        end);

      Assert.AreEqual<Integer>(LQuota,
        TInterlocked.CompareExchange(LSuccess, 0, 0),
        Format('Iter %d: expected exactly %d successes (no oversell), ' +
               'got %d',
          [Iter, LQuota,
           TInterlocked.CompareExchange(LSuccess, 0, 0)]));

      Assert.AreEqual<Integer>(LExtraThreads,
        TInterlocked.CompareExchange(LFailure, 0, 0),
        Format('Iter %d: expected %d failures (surplus consumers), got %d',
          [Iter, LExtraThreads,
           TInterlocked.CompareExchange(LFailure, 0, 0)]));

      // Final remaining quota must be 0 with status flipped to
      // cesConsumed (the in-memory store does that on the last
      // successful decrement).
      var LFinal: TCommerceEntitlementData;
      Assert.IsTrue(
        LStorage.FindEntitlement('user-1', 'app', 'feature.x', LFinal),
        Format('Iter %d: entitlement disappeared', [Iter]));
      Assert.AreEqual<Integer>(0, LFinal.RemainingQuota,
        Format('Iter %d: remaining quota %d, expected 0',
          [Iter, LFinal.RemainingQuota]));
      Assert.AreEqual(Ord(cesConsumed), Ord(LFinal.Status),
        Format('Iter %d: expected cesConsumed (%d) after full drain, ' +
               'got %d',
          [Iter, Ord(cesConsumed), Ord(LFinal.Status)]));
    finally
      LStorage := nil;
      LInner := nil;
    end;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TCommerceServicePropertyTests);

end.
