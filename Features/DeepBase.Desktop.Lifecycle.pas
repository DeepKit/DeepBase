unit DeepBase.Desktop.Lifecycle;

interface

uses
  System.SysUtils,
  DeepBase.Commerce.Permissions,
  DeepBase.Commerce.SafeClient,
  DeepBase.Commerce.Types,
  DeepBase.Commerce.UpgradeFlow,
  DeepBase.Updater;

type
  TDeepBaseDesktopLifecycleConfig = record
    AppId: string;
    DeviceId: string;
    UserId: string;
    CurrentVersion: string;
    UpdateUrl: string;
    Channel: string;
    class function Create(const AAppId, ADeviceId: string;
      const ACurrentVersion: string = ''; const AUpdateUrl: string = '';
      const AChannel: string = 'stable'): TDeepBaseDesktopLifecycleConfig; static;
  end;

  TDeepBaseDesktopLifecycle = class
  private
    FConfig: TDeepBaseDesktopLifecycleConfig;
    FClient: TDeepKitSafeClient;
    FOwnsClient: Boolean;
    FUpdater: TUpdateManager;
    FOwnsUpdater: Boolean;
    FPermissions: TDeepKitPermissionClient;
    FUpgradeFlow: TDeepKitUpgradeFlowClient;
    FLastSession: TDeepKitAuthSession;
    FLastSnapshot: TDeepKitLicenseSnapshot;

    procedure EnsureClient;
    procedure EnsurePermissions;
    procedure EnsureUpgradeFlow;
    procedure ApplyAuthContext;
    function ChannelToUpdateChannel(const AChannel: string): TUpdateChannel;
  public
    constructor Create(const AConfig: TDeepBaseDesktopLifecycleConfig;
      AClient: TDeepKitSafeClient; AOwnsClient: Boolean = False);
    destructor Destroy; override;

    procedure AttachUpdater(AUpdater: TUpdateManager; AOwnsUpdater: Boolean = False);
    procedure ConfigureUpdater(const AUpdateUrl, ACurrentVersion: string;
      const AChannel: string = 'stable');

    function LoginDeviceAnonymous(const ADeviceFingerprint: string = ''):
      TDeepKitAuthSession;
    function RefreshAuth(const ARefreshToken: string): TDeepKitAuthSession;
    procedure Logout(const ARefreshToken: string = '');

    function HasFeature(const AFeatureCode: string): TDeepKitPermissionResult;
    procedure RequireFeature(const AFeatureCode: string);
    function ConsumeQuota(const AFeatureCode: string; AQuantity: Integer = 1;
      const ARequestId: string = ''): TDeepKitConsumeEntitlementResult;
    function RefreshLicenseSnapshot: TDeepKitLicenseSnapshot;
    function GetPermissionClient: TDeepKitPermissionClient;
    function GetUpgradeFlowClient: TDeepKitUpgradeFlowClient;

    function ListProducts: TArray<TCommerceProductData>;
    function StartPaidUpgrade(const AProductId: string;
      AProvider: TCommercePaymentProvider = cppWeChatPay;
      AChannel: TCommercePaymentChannel = cpcH5;
      const APayerOpenId: string = '';
      const AIdempotencyKey: string = ''): TDeepKitUpgradeStartResult;
    function CheckEntitlement(const AEntitlementCode: string;
      out AEntitlement: TCommerceEntitlementData): Boolean;

    function CheckForUpdates(out AInfo: TUpdateInfo): Boolean;
    function GetDeepKitUpdateManifest(const ACurrentVersion: string = '';
      const AChannel: string = ''): TDeepKitUpdateManifest;

    property Config: TDeepBaseDesktopLifecycleConfig read FConfig write FConfig;
    property Client: TDeepKitSafeClient read FClient;
    property Updater: TUpdateManager read FUpdater;
    property Permissions: TDeepKitPermissionClient read FPermissions;
    property LastSession: TDeepKitAuthSession read FLastSession;
    property LastSnapshot: TDeepKitLicenseSnapshot read FLastSnapshot;
  end;

implementation

class function TDeepBaseDesktopLifecycleConfig.Create(const AAppId,
  ADeviceId, ACurrentVersion, AUpdateUrl, AChannel: string):
  TDeepBaseDesktopLifecycleConfig;
begin
  Result.AppId := AAppId;
  Result.DeviceId := ADeviceId;
  Result.UserId := '';
  Result.CurrentVersion := ACurrentVersion;
  Result.UpdateUrl := AUpdateUrl;
  Result.Channel := AChannel;
end;

constructor TDeepBaseDesktopLifecycle.Create(
  const AConfig: TDeepBaseDesktopLifecycleConfig; AClient: TDeepKitSafeClient;
  AOwnsClient: Boolean);
begin
  inherited Create;
  if AConfig.AppId.Trim = '' then
    raise EDeepBaseCommerceValidationError.Create('Desktop lifecycle app_id is required');
  if AConfig.DeviceId.Trim = '' then
    raise EDeepBaseCommerceValidationError.Create('Desktop lifecycle device_id is required');
  if AClient = nil then
    raise EDeepBaseCommerceValidationError.Create('Desktop lifecycle safe client is required');

  FConfig := AConfig;
  FClient := AClient;
  FOwnsClient := AOwnsClient;
end;

destructor TDeepBaseDesktopLifecycle.Destroy;
begin
  FUpgradeFlow.Free;
  FPermissions.Free;
  if FOwnsUpdater then
    FUpdater.Free;
  if FOwnsClient then
    FClient.Free;
  inherited;
end;

procedure TDeepBaseDesktopLifecycle.EnsureClient;
begin
  if FClient = nil then
    raise EDeepBaseCommerceValidationError.Create('Desktop lifecycle safe client is required');
end;

procedure TDeepBaseDesktopLifecycle.EnsurePermissions;
begin
  EnsureClient;
  if FPermissions = nil then
    FPermissions := TDeepKitPermissionClient.Create(FClient, FConfig.AppId,
      FConfig.DeviceId, False);
end;

procedure TDeepBaseDesktopLifecycle.EnsureUpgradeFlow;
begin
  EnsureClient;
  if FUpgradeFlow = nil then
    FUpgradeFlow := TDeepKitUpgradeFlowClient.Create(FClient, FConfig.AppId,
      FConfig.UserId, FConfig.DeviceId, False)
  else
  begin
    FUpgradeFlow.AppId := FConfig.AppId;
    FUpgradeFlow.UserId := FConfig.UserId;
    FUpgradeFlow.DeviceId := FConfig.DeviceId;
  end;
end;

function TDeepBaseDesktopLifecycle.ChannelToUpdateChannel(
  const AChannel: string): TUpdateChannel;
begin
  if SameText(AChannel, 'beta') then
    Result := ucBeta
  else if SameText(AChannel, 'alpha') then
    Result := ucAlpha
  else if SameText(AChannel, 'dev') then
    Result := ucDev
  else
    Result := ucStable;
end;

procedure TDeepBaseDesktopLifecycle.ApplyAuthContext;
begin
  if Assigned(FUpdater) then
  begin
    FUpdater.UpdateAppId := FConfig.AppId;
    FUpdater.UpdateDeviceId := FConfig.DeviceId;
    FUpdater.UpdateAccessToken := FClient.GetAccessToken;
  end;
end;

procedure TDeepBaseDesktopLifecycle.AttachUpdater(AUpdater: TUpdateManager;
  AOwnsUpdater: Boolean);
begin
  if FOwnsUpdater and Assigned(FUpdater) then
    FUpdater.Free;
  FUpdater := AUpdater;
  FOwnsUpdater := AOwnsUpdater;
  ApplyAuthContext;
end;

procedure TDeepBaseDesktopLifecycle.ConfigureUpdater(const AUpdateUrl,
  ACurrentVersion, AChannel: string);
begin
  if FUpdater = nil then
    AttachUpdater(TUpdateManager.Create, True);

  FConfig.UpdateUrl := AUpdateUrl;
  FConfig.CurrentVersion := ACurrentVersion;
  FConfig.Channel := AChannel;

  FUpdater.Initialize(AUpdateUrl, ACurrentVersion);
  FUpdater.Channel := ChannelToUpdateChannel(AChannel);
  FUpdater.UpdateCheckRouteMode := ucrmManifest;
  ApplyAuthContext;
end;

function TDeepBaseDesktopLifecycle.LoginDeviceAnonymous(
  const ADeviceFingerprint: string): TDeepKitAuthSession;
begin
  EnsureClient;
  FLastSession := FClient.AuthLoginDeviceAnonymous(FConfig.AppId,
    FConfig.DeviceId, ADeviceFingerprint);
  FConfig.UserId := FLastSession.UserId;
  ApplyAuthContext;
  Result := FLastSession;
end;

function TDeepBaseDesktopLifecycle.RefreshAuth(
  const ARefreshToken: string): TDeepKitAuthSession;
begin
  EnsureClient;
  FLastSession := FClient.AuthRefresh(ARefreshToken);
  FConfig.UserId := FLastSession.UserId;
  ApplyAuthContext;
  Result := FLastSession;
end;

procedure TDeepBaseDesktopLifecycle.Logout(const ARefreshToken: string);
begin
  EnsureClient;
  FClient.AuthLogout(ARefreshToken);
  FLastSession := Default(TDeepKitAuthSession);
  FConfig.UserId := '';
  ApplyAuthContext;
end;

function TDeepBaseDesktopLifecycle.HasFeature(
  const AFeatureCode: string): TDeepKitPermissionResult;
begin
  EnsurePermissions;
  Result := FPermissions.HasFeature(AFeatureCode);
end;

procedure TDeepBaseDesktopLifecycle.RequireFeature(const AFeatureCode: string);
begin
  EnsurePermissions;
  FPermissions.RequireFeature(AFeatureCode);
end;

function TDeepBaseDesktopLifecycle.ConsumeQuota(const AFeatureCode: string;
  AQuantity: Integer; const ARequestId: string): TDeepKitConsumeEntitlementResult;
begin
  EnsurePermissions;
  Result := FPermissions.ConsumeQuota(AFeatureCode, AQuantity, ARequestId);
end;

function TDeepBaseDesktopLifecycle.RefreshLicenseSnapshot:
  TDeepKitLicenseSnapshot;
begin
  EnsurePermissions;
  FLastSnapshot := FPermissions.RefreshLicenseSnapshot;
  Result := FLastSnapshot;
end;

function TDeepBaseDesktopLifecycle.GetPermissionClient:
  TDeepKitPermissionClient;
begin
  EnsurePermissions;
  Result := FPermissions;
end;

function TDeepBaseDesktopLifecycle.GetUpgradeFlowClient:
  TDeepKitUpgradeFlowClient;
begin
  EnsureUpgradeFlow;
  Result := FUpgradeFlow;
end;

function TDeepBaseDesktopLifecycle.ListProducts: TArray<TCommerceProductData>;
begin
  EnsureUpgradeFlow;
  Result := FUpgradeFlow.ListProducts;
end;

function TDeepBaseDesktopLifecycle.StartPaidUpgrade(const AProductId: string;
  AProvider: TCommercePaymentProvider; AChannel: TCommercePaymentChannel;
  const APayerOpenId, AIdempotencyKey: string): TDeepKitUpgradeStartResult;
begin
  EnsureUpgradeFlow;
  Result := FUpgradeFlow.StartPaidUpgrade(AProductId, AProvider, AChannel,
    APayerOpenId, AIdempotencyKey);
end;

function TDeepBaseDesktopLifecycle.CheckEntitlement(
  const AEntitlementCode: string; out AEntitlement: TCommerceEntitlementData):
  Boolean;
begin
  EnsureUpgradeFlow;
  Result := FUpgradeFlow.CheckEntitlement(AEntitlementCode, AEntitlement);
end;

function TDeepBaseDesktopLifecycle.CheckForUpdates(
  out AInfo: TUpdateInfo): Boolean;
begin
  if FUpdater = nil then
    ConfigureUpdater(FConfig.UpdateUrl, FConfig.CurrentVersion, FConfig.Channel);
  ApplyAuthContext;
  Result := FUpdater.CheckForUpdatesSync(AInfo);
end;

function TDeepBaseDesktopLifecycle.GetDeepKitUpdateManifest(
  const ACurrentVersion, AChannel: string): TDeepKitUpdateManifest;
var
  VersionText: string;
  ChannelText: string;
begin
  EnsureUpgradeFlow;
  VersionText := ACurrentVersion;
  if VersionText = '' then
    VersionText := FConfig.CurrentVersion;
  ChannelText := AChannel;
  if ChannelText = '' then
    ChannelText := FConfig.Channel;
  Result := FUpgradeFlow.GetUpdateManifest(VersionText, ChannelText);
end;

end.
