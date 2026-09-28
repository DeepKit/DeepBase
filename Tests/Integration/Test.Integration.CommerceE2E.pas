unit Test.Integration.CommerceE2E;

interface

uses
  System.SysUtils,
  System.DateUtils,
  System.Generics.Collections,
  System.Net.URLClient,
  DUnitX.TestFramework,
  DeepBase.Commerce.Backend.Http,
  DeepBase.Commerce.SafeClient,
  DeepBase.Commerce.Types,
  DeepBase.Commerce.UpgradeFlow,
  DeepBase.Desktop.Lifecycle;

type
  [TestFixture]
  TCommerceDesktopE2ETests = class
  public
    [Test]
    procedure Test_FreeUser_UpgradeToPro_UnlocksFeatureAndPaidUpdateChannel;

    [Test]
    procedure Test_LicenseSnapshot_WithFixedPastExpiry_IsRejected;
  end;

implementation

{ 快照寿命一律以运行时刻推算（相对基准），不再写死日期：
  写死 expires_at 会让本用例在某个真实日期之后无条件转红（日期炸弹），
  而「未到期」正是被测主路径的前提，红在夹具而非产品行为上等于没有覆盖。 }
function SnapshotInstantIso(const AUtcBare: TDateTime): string;
begin
  Result := FormatDateTime('yyyy"-"mm"-"dd"T"hh":"nn":"ss"Z"', AUtcBare);
end;

function SnapshotJson(const AIssuedIso, AExpiresIso, ASnapshotId: string): string;
begin
  Result := '{"snapshot_id":"' + ASnapshotId +
    '","issued_at":"' + AIssuedIso + '","expires_at":"' + AExpiresIso +
    '","payload":{"app_id":"deepbase_desktop","device_id":"dev_e2e","tier":"pro",' +
    '"features":["pro_full"]},"signature":"sig_e2e","key_id":"v1",' +
    '"schema_version":1,"revocation_version":0}';
end;

type
  TE2EHttpRequest = record
    Method: string;
    Url: string;
    Body: string;
    Headers: TNetHeaders;
  end;

  TE2EFakeTransport = class(TInterfacedObject, ICommerceBackendHttpTransport)
  private
    FRequests: TList<TE2EHttpRequest>;
    FResponses: TQueue<TCommerceBackendHttpResponse>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure QueueResponse(AStatusCode: Integer; const ABody: string);
    function RequestCount: Integer;
    function RequestAt(AIndex: Integer): TE2EHttpRequest;
    function Send(const AMethod, AUrl, ABody: string;
      const AHeaders: TNetHeaders): TCommerceBackendHttpResponse;
  end;

constructor TE2EFakeTransport.Create;
begin
  inherited Create;
  FRequests := TList<TE2EHttpRequest>.Create;
  FResponses := TQueue<TCommerceBackendHttpResponse>.Create;
end;

destructor TE2EFakeTransport.Destroy;
begin
  FResponses.Free;
  FRequests.Free;
  inherited;
end;

procedure TE2EFakeTransport.QueueResponse(AStatusCode: Integer;
  const ABody: string);
begin
  FResponses.Enqueue(TCommerceBackendHttpResponse.Create(AStatusCode, ABody));
end;

function TE2EFakeTransport.RequestCount: Integer;
begin
  Result := FRequests.Count;
end;

function TE2EFakeTransport.RequestAt(AIndex: Integer): TE2EHttpRequest;
begin
  Result := FRequests[AIndex];
end;

function TE2EFakeTransport.Send(const AMethod, AUrl, ABody: string;
  const AHeaders: TNetHeaders): TCommerceBackendHttpResponse;
var
  Req: TE2EHttpRequest;
begin
  Req.Method := AMethod;
  Req.Url := AUrl;
  Req.Body := ABody;
  Req.Headers := AHeaders;
  FRequests.Add(Req);

  if FResponses.Count = 0 then
    raise Exception.CreateFmt('Unexpected E2E request: %s %s', [AMethod, AUrl]);

  Result := FResponses.Dequeue;
end;

procedure TCommerceDesktopE2ETests.Test_FreeUser_UpgradeToPro_UnlocksFeatureAndPaidUpdateChannel;
var
  Transport: TE2EFakeTransport;
  Client: TDeepKitSafeClient;
  SafeConfig: TDeepKitSafeClientConfig;
  Lifecycle: TDeepBaseDesktopLifecycle;
  Config: TDeepBaseDesktopLifecycleConfig;
  Upgrade: TDeepKitUpgradeStartResult;
  Entitlement: TCommerceEntitlementData;
  Snapshot: TDeepKitLicenseSnapshot;
  Manifest: TDeepKitUpdateManifest;
  NowUtc: TDateTime;
begin
  NowUtc := TTimeZone.Local.ToUniversalTime(Now);
  Transport := TE2EFakeTransport.Create;
  Transport.QueueResponse(200,
    '{"user_id":"usr_e2e","access_token":"atk_e2e","refresh_token":"rtk_e2e","expires_in":7200}');
  Transport.QueueResponse(200, '{"items":[]}');
  Transport.QueueResponse(200,
    '{"products":[{"product_id":"pro_monthly","app_id":"deepbase_desktop","name":"Pro Monthly","amount_minor":3900,"currency":"CNY","entitlement_code":"pro_full","entitlement_duration_days":31,"initial_quota":-1,"is_active":true}]}');
  Transport.QueueResponse(200,
    '{"order_id":"ord_e2e","out_trade_no":"DBE2E20260508001","app_id":"deepbase_desktop","product_id":"pro_monthly","amount_minor":3900,"currency":"CNY","status":"created"}');
  Transport.QueueResponse(200,
    '{"success":true,"payment_id":"pay_e2e","out_trade_no":"DBE2E20260508001","prepay_id":"prepay_e2e","pay_url":"https://pay.example.test/e2e"}');
  Transport.QueueResponse(200,
    '{"items":[{"entitlement_id":"ent_e2e","user_id":"usr_e2e","app_id":"deepbase_desktop","product_id":"pro_monthly","code":"pro_full","status":"active","remaining_quota":-1}]}');
  Transport.QueueResponse(200,
    SnapshotJson(SnapshotInstantIso(IncDay(NowUtc, -1)),
      SnapshotInstantIso(IncDay(NowUtc, 30)), 'snap_e2e'));
  Transport.QueueResponse(200,
    '{"app_id":"deepbase_desktop","current_version":"1.0.0","channel":"stable-pro","latest_version":"1.1.0","min_version":"1.0.0","manifest_url":"https://cdn.example.test/deepbase/pro/stable/version.json","package_url":"https://cdn.example.test/deepbase/pro/stable/deepbase-1.1.0.zip","package_hash":"sha256:e2e","signature":"sig_manifest","force_update":false,"release_notes":"Pro update"}');

  SafeConfig := TDeepKitSafeClientConfig.CreateDeepKit('https://api.example.test');
  SafeConfig.LicenseSnapshotVerifier :=
    function(const APayload, ASignature, AKeyId, AAppId,
      ADeviceId: string): Boolean
    begin
      Result := (APayload <> '') and (ASignature = 'sig_e2e') and
        (AKeyId = 'v1') and (AAppId = 'deepbase_desktop') and
        (ADeviceId = 'dev_e2e');
    end;
  Client := TDeepKitSafeClient.Create(SafeConfig, Transport);
  Config := TDeepBaseDesktopLifecycleConfig.Create('deepbase_desktop',
    'dev_e2e', '1.0.0', 'https://api.example.test/dk', 'stable');
  Lifecycle := TDeepBaseDesktopLifecycle.Create(Config, Client, True);
  try
    Lifecycle.LoginDeviceAnonymous('fp_e2e');

    Assert.IsFalse(Lifecycle.HasFeature('pro_feature').Allowed,
      'Free user must not see paid feature before upgrade.');

    Upgrade := Lifecycle.StartPaidUpgrade('pro_monthly', cppWeChatPay, cpcH5,
      '', 'idem_e2e_upgrade');
    Assert.AreEqual('ord_e2e', Upgrade.Order.OrderId);
    Assert.AreEqual('https://pay.example.test/e2e', Upgrade.PaymentIntent.PayUrl);

    Assert.IsTrue(Lifecycle.CheckEntitlement('pro_full', Entitlement),
      'Paid entitlement should become visible after backend payment callback.');
    Assert.AreEqual('ent_e2e', Entitlement.EntitlementId);

    Snapshot := Lifecycle.RefreshLicenseSnapshot;
    Assert.AreEqual('snap_e2e', Snapshot.SnapshotId);
    Assert.AreEqual('v1', Snapshot.KeyId);

    Manifest := Lifecycle.GetDeepKitUpdateManifest('1.0.0', 'stable-pro');
    Assert.AreEqual('stable-pro', Manifest.Channel);
    Assert.AreEqual('1.1.0', Manifest.LatestVersion);
    Assert.IsTrue(Pos('/pro/stable/', Manifest.PackageUrl) > 0,
      'Pro user must receive paid update channel package URL.');

    Assert.AreEqual<Integer>(8, Transport.RequestCount);
    Assert.AreEqual('https://api.example.test/dk/auth/login',
      Transport.RequestAt(0).Url);
    Assert.AreEqual('https://api.example.test/dk/commerce/payments/intents',
      Transport.RequestAt(4).Url);
    Assert.AreEqual('https://api.example.test/dk/updates/manifest?app_id=deepbase_desktop&current_version=1.0.0&channel=stable-pro',
      Transport.RequestAt(7).Url);
  finally
    Lifecycle.Free;
  end;
end;

{ 过期快照必须被拒绝：签名校验器显式放行，让「拒绝」只能来自过期判定本身。
  日期取固定的过去时刻（不随真实日期漂移），把原来的日期炸弹转成永久有效的负向回归。 }
procedure TCommerceDesktopE2ETests.Test_LicenseSnapshot_WithFixedPastExpiry_IsRejected;
const
  PAST_ISSUED_ISO = '1999-12-31T00:00:00Z';
  PAST_EXPIRES_ISO = '2000-01-01T00:00:00Z';
var
  Transport: TE2EFakeTransport;
  Client: TDeepKitSafeClient;
  SafeConfig: TDeepKitSafeClientConfig;
  Raised: Boolean;
  ErrorText: string;
begin
  Transport := TE2EFakeTransport.Create;
  Transport.QueueResponse(200,
    SnapshotJson(PAST_ISSUED_ISO, PAST_EXPIRES_ISO, 'snap_expired_e2e'));

  SafeConfig := TDeepKitSafeClientConfig.CreateDeepKit('https://api.example.test');
  SafeConfig.LicenseSnapshotVerifier :=
    function(const APayload, ASignature, AKeyId, AAppId, ADeviceId: string): Boolean
    begin
      Result := True;
    end;
  Client := TDeepKitSafeClient.Create(SafeConfig, Transport);
  try
    Raised := False;
    ErrorText := '';
    try
      Client.RefreshLicenseSnapshot('deepbase_desktop', 'dev_e2e');
    except
      on E: EDeepBaseCommerceValidationError do
      begin
        Raised := True;
        ErrorText := E.Message;
      end;
    end;

    Assert.IsTrue(Raised,
      'Expired license snapshot must be rejected even when the signature verifies.');
    Assert.AreEqual('License snapshot has expired', ErrorText);
    Assert.AreEqual<Integer>(1, Transport.RequestCount);
  finally
    Client.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TCommerceDesktopE2ETests);

end.
