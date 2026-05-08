{==============================================================================
  CommerceE2EDemo.pas - Minimal end-to-end sample for the DeepBase Commerce
  framework.

  Demonstrates the complete commerce flow in a single console application:
    1. Create TDeepBaseCommerceService with TInMemoryCommerceStorage
    2. Register a product
    3. Ensure a user via WeChat identity
    4. Create an order
    5. Register a fake payment gateway and notification verifier
    6. Begin payment
    7. Verify and confirm payment
    8. Check entitlement
    9. Consume entitlement

  This demo uses in-memory storage and fake gateway/verifier implementations
  so it runs without any external dependencies.
==============================================================================}

program CommerceE2EDemo;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Generics.Collections,
  DeepBase.Commerce.Types in '..\..\Features\DeepBase.Commerce.Types.pas',
  DeepBase.Commerce.Storage in '..\..\Features\DeepBase.Commerce.Storage.pas',
  DeepBase.Commerce.Service in '..\..\Features\DeepBase.Commerce.Service.pas',
  DeepBase.Commerce.PaymentBridge in '..\..\Features\DeepBase.Commerce.PaymentBridge.pas';

type
  { Fake payment gateway that always returns a successful payment intent. }
  TFakePaymentGateway = class(TInterfacedObject, ICommercePaymentGateway)
  public
    function CreatePaymentIntent(const AOrder: TCommerceOrderData;
      const APayment: TCommercePaymentData;
      const APayerOpenId: string): TCommercePaymentIntent;
  end;

{ TFakePaymentGateway }

function TFakePaymentGateway.CreatePaymentIntent(const AOrder: TCommerceOrderData;
  const APayment: TCommercePaymentData;
  const APayerOpenId: string): TCommercePaymentIntent;
begin
  Result.Success := True;
  Result.PaymentId := APayment.PaymentId;
  Result.OutTradeNo := AOrder.OutTradeNo;
  Result.PrepayId := 'fake_prepay_' + Copy(APayment.PaymentId, 1, 16);
  Result.PayUrl := '';
  Result.QRCodeData := '';
  Result.ClientParamsJson := '{"fakePrepayId":"' + Result.PrepayId + '"}';
  Result.RawResponse := '{"status":"ok"}';
  Result.ErrorCode := '';
  Result.ErrorMessage := '';
end;

var
  Storage: ICommerceStorage;
  Service: TDeepBaseCommerceService;
  Product: TCommerceProductData;
  User: TCommerceUserData;
  Order: TCommerceOrderData;
  Intent: TCommercePaymentIntent;
  ConfirmedOrder: TCommerceOrderData;
  Gateway: ICommercePaymentGateway;
  Verifier: ICommerceNotificationVerifier;
  Callback: TFunc<string, TArray<TPair<string, string>>, TCommercePaymentNotification>;
  FakeRawBody: string;
begin
  try
    WriteLn('=== DeepBase Commerce E2E Demo ===');
    WriteLn;

    // -----------------------------------------------------------------------
    // Step 1: Create service with in-memory storage
    // -----------------------------------------------------------------------
    WriteLn('Step 1: Creating TDeepBaseCommerceService with TInMemoryCommerceStorage');
    Storage := TInMemoryCommerceStorage.Create;
    Service := TDeepBaseCommerceService.Create(Storage);
    try
      WriteLn('  Service created successfully.');
      WriteLn;

      // -------------------------------------------------------------------
      // Step 2: Register a product
      // -------------------------------------------------------------------
      WriteLn('Step 2: Registering product "premium_monthly"');
      Product := TCommerceProductData.Create(
        'demo_app',                       // AppId
        'premium_monthly',                // ProductId
        'Premium Monthly Subscription',   // Name
        2990,                             // AmountMinor (29.90 CNY in fen)
        'CNY',                            // Currency
        'premium_access',                 // EntitlementCode
        -1,                               // InitialQuota (-1 = unlimited)
        30);                              // EntitlementDurationDays
      Service.RegisterProduct(Product);
      WriteLn(Format('  Product registered: %s (%s %s per %d days)',
        [Product.Name, Product.Currency,
         IntToStr(Product.AmountMinor), Product.EntitlementDurationDays]));
      WriteLn;

      // -------------------------------------------------------------------
      // Step 3: Ensure user via WeChat identity
      // -------------------------------------------------------------------
      WriteLn('Step 3: Ensuring user via WeChat Mini Program identity');
      User := Service.EnsureUserForIdentity(
        capWeChatMiniProgram,
        'wx_openid_abc123',
        'demo_app');
      WriteLn(Format('  User ensured: UserId=%s', [User.UserId]));
      WriteLn;

      // -------------------------------------------------------------------
      // Step 4: Create order
      // -------------------------------------------------------------------
      WriteLn('Step 4: Creating order for user');
      Order := Service.CreateOrder(User.UserId, 'demo_app', 'premium_monthly');
      WriteLn(Format('  Order created: OrderId=%s', [Order.OrderId]));
      WriteLn(Format('  OutTradeNo=%s', [Order.OutTradeNo]));
      WriteLn(Format('  Status=%s', [CommerceOrderStatusToStr(Order.Status)]));
      WriteLn;

      // -------------------------------------------------------------------
      // Step 5: Register fake payment gateway and notification verifier
      // -------------------------------------------------------------------
      WriteLn('Step 5: Registering fake ICommercePaymentGateway');
      Gateway := TFakePaymentGateway.Create;
      Service.RegisterPaymentGateway(cppWeChatPay, Gateway);
      WriteLn('  Fake payment gateway registered for WeChat Pay.');

      WriteLn('  Registering TCallbackNotificationVerifier');
      Callback :=
        function(ARawBody: string;
          AHeaders: TArray<TPair<string, string>>): TCommercePaymentNotification
        begin
          Result.Provider := cppWeChatPay;
          Result.OutTradeNo := Order.OutTradeNo;
          Result.ProviderTradeNo := 'fake_wx_txn_' + Copy(Order.OrderId, 5, 12);
          Result.AmountMinor := Order.AmountMinor;
          Result.Currency := Order.Currency;
          Result.Success := True;
          Result.PaidAtISO := CommerceNowISO;
          Result.RawPayload := ARawBody;
        end;
      Verifier := TCallbackNotificationVerifier.Create(Callback);
      Service.RegisterNotificationVerifier(cppWeChatPay, Verifier);
      WriteLn('  Callback notification verifier registered for WeChat Pay.');
      WriteLn;

      // -------------------------------------------------------------------
      // Step 6: Begin payment
      // -------------------------------------------------------------------
      WriteLn('Step 6: Beginning payment');
      Intent := Service.BeginPayment(
        Order.OrderId,
        cppWeChatPay,
        cpcMiniProgram,
        'wx_openid_abc123');
      WriteLn(Format('  Payment intent: Success=%s', [BoolToStr(Intent.Success, True)]));
      WriteLn(Format('  PrepayId=%s', [Intent.PrepayId]));
      WriteLn(Format('  OutTradeNo=%s', [Intent.OutTradeNo]));
      WriteLn;

      // -------------------------------------------------------------------
      // Step 7: Verify and confirm payment
      // -------------------------------------------------------------------
      WriteLn('Step 7: Verifying and confirming payment');
      FakeRawBody := '{"event":"payment_success","out_trade_no":"' +
        Order.OutTradeNo + '"}';
      ConfirmedOrder := Service.VerifyAndConfirmPayment(
        cppWeChatPay, FakeRawBody, nil);
      WriteLn(Format('  Payment confirmed: OrderId=%s', [ConfirmedOrder.OrderId]));
      WriteLn(Format('  Status=%s', [CommerceOrderStatusToStr(ConfirmedOrder.Status)]));
      WriteLn(Format('  PaidAtISO=%s', [ConfirmedOrder.PaidAtISO]));
      WriteLn;

      // -------------------------------------------------------------------
      // Step 8: Check entitlement
      // -------------------------------------------------------------------
      WriteLn('Step 8: Checking entitlement "premium_access"');
      if Service.HasEntitlement(User.UserId, 'demo_app', 'premium_access') then
        WriteLn('  Entitlement "premium_access" is active.')
      else
        WriteLn('  ERROR: Entitlement "premium_access" not found!');
      WriteLn;

      // -------------------------------------------------------------------
      // Step 9: Consume entitlement
      // -------------------------------------------------------------------
      WriteLn('Step 9: Consuming entitlement "premium_access" (1 use)');
      if Service.ConsumeEntitlement(User.UserId, 'demo_app', 'premium_access', 1) then
        WriteLn('  Entitlement consumed successfully.')
      else
        WriteLn('  ERROR: Failed to consume entitlement!');
      WriteLn;

      WriteLn('=== E2E Demo Complete ===');
    finally
      Service.Free;
    end;
  except
    on E: Exception do
    begin
      WriteLn(Format('FATAL ERROR: %s: %s', [E.ClassName, E.Message]));
      ExitCode := 1;
    end;
  end;
end.
