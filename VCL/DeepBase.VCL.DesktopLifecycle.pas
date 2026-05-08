{ ============================================================================
  DeepBase.VCL.DesktopLifecycle

  Thin VCL helpers for wiring the non-visual desktop lifecycle facade to common
  desktop-tool UI actions: license labels, feature gating, paid upgrade, update
  checks, and deterministic GUI-test window placement.
  ============================================================================ }

unit DeepBase.VCL.DesktopLifecycle;

interface

uses
  System.SysUtils,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  DeepBase.Commerce.Types,
  DeepBase.Commerce.UpgradeFlow,
  DeepBase.Desktop.Lifecycle,
  DeepBase.Updater;

type
  TDeepBaseVCLDesktopLifecycleHelper = class
  public
    class procedure PositionWindowForGuiTest(AForm: TForm;
      ALeft: Integer = 100; ATop: Integer = 300); static;

    class function RefreshLicenseStatus(ALifecycle: TDeepBaseDesktopLifecycle;
      AStatusLabel: TCustomLabel; const AFeatureCode: string = 'pro_full'):
      Boolean; static;

    class function ApplyFeatureGate(ALifecycle: TDeepBaseDesktopLifecycle;
      AControl: TControl; const AFeatureCode: string;
      AUpgradeControl: TControl = nil): Boolean; static;

    class function StartPaidUpgrade(ALifecycle: TDeepBaseDesktopLifecycle;
      const AProductId: string; AOpenBrowser: Boolean = True): string; static;

    class function CheckForUpdates(ALifecycle: TDeepBaseDesktopLifecycle;
      AShowMessage: Boolean = True): Boolean; static;

    class function OpenUrl(const AUrl: string): Boolean; static;
  end;

implementation

uses
  Winapi.Windows,
  Winapi.ShellAPI,
  Vcl.Dialogs,
  DeepBase.Commerce.Permissions;

class procedure TDeepBaseVCLDesktopLifecycleHelper.PositionWindowForGuiTest(
  AForm: TForm; ALeft, ATop: Integer);
begin
  if AForm = nil then
    Exit;

  AForm.Position := poDesigned;
  AForm.Left := ALeft;
  AForm.Top := ATop;
end;

class function TDeepBaseVCLDesktopLifecycleHelper.RefreshLicenseStatus(
  ALifecycle: TDeepBaseDesktopLifecycle; AStatusLabel: TCustomLabel;
  const AFeatureCode: string): Boolean;
var
  Check: TDeepKitPermissionResult;
begin
  Result := False;
  if (ALifecycle = nil) or (AStatusLabel = nil) then
    Exit;

  try
    Check := ALifecycle.HasFeature(AFeatureCode);
    Result := Check.Allowed;
    if Result then
      AStatusLabel.Caption := Format('Licensed: %s', [Check.EntitlementCode])
    else
      AStatusLabel.Caption := Format('Free: %s', [Check.Reason]);
  except
    on E: Exception do
      AStatusLabel.Caption := 'License check failed: ' + E.Message;
  end;
end;

class function TDeepBaseVCLDesktopLifecycleHelper.ApplyFeatureGate(
  ALifecycle: TDeepBaseDesktopLifecycle; AControl: TControl;
  const AFeatureCode: string; AUpgradeControl: TControl): Boolean;
begin
  Result := False;
  if (ALifecycle = nil) or (AControl = nil) then
    Exit;

  try
    Result := ALifecycle.HasFeature(AFeatureCode).Allowed;
  except
    Result := False;
  end;

  AControl.Enabled := Result;
  if Assigned(AUpgradeControl) then
    AUpgradeControl.Visible := not Result;
end;

class function TDeepBaseVCLDesktopLifecycleHelper.StartPaidUpgrade(
  ALifecycle: TDeepBaseDesktopLifecycle; const AProductId: string;
  AOpenBrowser: Boolean): string;
var
  Upgrade: TDeepKitUpgradeStartResult;
begin
  if ALifecycle = nil then
    raise EArgumentNilException.Create('ALifecycle');

  Upgrade := ALifecycle.StartPaidUpgrade(AProductId);
  Result := Upgrade.PaymentIntent.PayUrl;
  if Result = '' then
    Result := Upgrade.PaymentIntent.QRCodeData;
  if Result = '' then
    Result := Upgrade.PaymentIntent.ClientParamsJson;

  if AOpenBrowser and (Result <> '') and
     (SameText(Copy(Result, 1, 7), 'http://') or
      SameText(Copy(Result, 1, 8), 'https://')) then
    OpenUrl(Result);
end;

class function TDeepBaseVCLDesktopLifecycleHelper.CheckForUpdates(
  ALifecycle: TDeepBaseDesktopLifecycle; AShowMessage: Boolean): Boolean;
var
  Info: TUpdateInfo;
  Msg: string;
begin
  if ALifecycle = nil then
    raise EArgumentNilException.Create('ALifecycle');

  Result := ALifecycle.CheckForUpdates(Info);
  if not AShowMessage then
    Exit;

  if Result then
  begin
    Msg := Format('New version available: %s', [Info.Version.ToString]);
    if Info.ReleaseNotes <> '' then
      Msg := Msg + sLineBreak + sLineBreak + Info.ReleaseNotes;
    MessageDlg(Msg, mtInformation, [mbOK], 0);
  end
  else
    MessageDlg('Already up to date.', mtInformation, [mbOK], 0);
end;

class function TDeepBaseVCLDesktopLifecycleHelper.OpenUrl(
  const AUrl: string): Boolean;
begin
  Result := AUrl.Trim <> '';
  if Result then
    Result := ShellExecute(0, 'open', PChar(AUrl), nil, nil, SW_SHOWNORMAL) > 32;
end;

end.
