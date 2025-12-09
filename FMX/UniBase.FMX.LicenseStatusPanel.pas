{ ============================================================================
  UniBase.FMX.LicenseStatusPanel - FMX License Status Panel
  
  Version: 1.0
  Description: Cross-platform panel displaying license status, type, expiration
  Features:
    - Shows license status with color indicator
    - Displays license type, expiry date, issued-to info
    - Activate/Deactivate buttons
    - Compact mode for minimal display
  ============================================================================ }

unit UniBase.FMX.LicenseStatusPanel;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
  FMX.Types,
  FMX.Controls,
  FMX.Controls.Presentation,
  FMX.Layouts,
  FMX.StdCtrls,
  FMX.Objects,
  FMX.Graphics,
  UniBase.License;

type
  TFMXLicenseStatusPanel = class(TLayout)
  private
    FBackground: TRectangle;
    FStatusIndicator: TCircle;
    FLblTitle: TLabel;
    FLblStatus: TLabel;
    FLblType: TLabel;
    FLblExpiry: TLabel;
    FLblIssuedTo: TLabel;
    FBtnActivate: TButton;
    FBtnDeactivate: TButton;
    
    FLicense: TUniBaseLicense;
    FOwnsLicense: Boolean;
    FCompact: Boolean;
    
    FOnActivateClick: TNotifyEvent;
    FOnDeactivateClick: TNotifyEvent;
    
    procedure CreateControls;
    procedure UpdateControls;
    procedure HandleActivateClick(Sender: TObject);
    procedure HandleDeactivateClick(Sender: TObject);
    procedure SetLicense(Value: TUniBaseLicense);
    procedure SetCompact(Value: Boolean);
    function GetStatusColor(Status: TLicenseStatus): TAlphaColor;
    procedure UpdateLayout;
    
  protected
    procedure Resize; override;
    
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    procedure RefreshStatus;
    
    property License: TUniBaseLicense read FLicense write SetLicense;
    property Compact: Boolean read FCompact write SetCompact default False;
    property OnActivateClick: TNotifyEvent read FOnActivateClick write FOnActivateClick;
    property OnDeactivateClick: TNotifyEvent read FOnDeactivateClick write FOnDeactivateClick;
  end;

implementation

uses
  System.DateUtils;

{ TFMXLicenseStatusPanel }

constructor TFMXLicenseStatusPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  
  Width := 320;
  Height := 140;
  FCompact := False;
  FOwnsLicense := True;
  FLicense := TUniBaseLicense.Create;
  
  CreateControls;
  UpdateControls;
end;

destructor TFMXLicenseStatusPanel.Destroy;
begin
  if FOwnsLicense then
    FreeAndNil(FLicense);
  inherited;
end;

procedure TFMXLicenseStatusPanel.CreateControls;
begin
  FBackground := TRectangle.Create(Self);
  FBackground.Parent := Self;
  FBackground.Align := TAlignLayout.Client;
  FBackground.Fill.Color := TAlphaColorRec.White;
  FBackground.Stroke.Color := TAlphaColorRec.Lightgray;
  FBackground.XRadius := 4;
  FBackground.YRadius := 4;
  FBackground.HitTest := False;
  
  // Status indicator (circle)
  FStatusIndicator := TCircle.Create(Self);
  FStatusIndicator.Parent := Self;
  FStatusIndicator.Width := 14;
  FStatusIndicator.Height := 14;
  FStatusIndicator.Fill.Color := TAlphaColorRec.Gray;
  FStatusIndicator.Stroke.Kind := TBrushKind.None;
  
  // Title
  FLblTitle := TLabel.Create(Self);
  FLblTitle.Parent := Self;
  FLblTitle.Text := 'License Status';
  FLblTitle.StyledSettings := FLblTitle.StyledSettings - [TStyledSetting.Style];
  FLblTitle.Font.Style := [TFontStyle.fsBold];
  FLblTitle.AutoSize := False;
  
  // Status
  FLblStatus := TLabel.Create(Self);
  FLblStatus.Parent := Self;
  FLblStatus.Text := 'Not Licensed';
  FLblStatus.AutoSize := False;
  
  // Type
  FLblType := TLabel.Create(Self);
  FLblType.Parent := Self;
  FLblType.Text := 'Type: -';
  FLblType.AutoSize := False;
  
  // Expiry
  FLblExpiry := TLabel.Create(Self);
  FLblExpiry.Parent := Self;
  FLblExpiry.Text := 'Expires: -';
  FLblExpiry.AutoSize := False;
  
  // Issued to
  FLblIssuedTo := TLabel.Create(Self);
  FLblIssuedTo.Parent := Self;
  FLblIssuedTo.Text := 'Issued to: -';
  FLblIssuedTo.AutoSize := False;
  
  // Activate button
  FBtnActivate := TButton.Create(Self);
  FBtnActivate.Parent := Self;
  FBtnActivate.Text := 'Activate';
  FBtnActivate.Width := 80;
  FBtnActivate.Height := 28;
  FBtnActivate.OnClick := HandleActivateClick;
  
  // Deactivate button
  FBtnDeactivate := TButton.Create(Self);
  FBtnDeactivate.Parent := Self;
  FBtnDeactivate.Text := 'Deactivate';
  FBtnDeactivate.Width := 80;
  FBtnDeactivate.Height := 28;
  FBtnDeactivate.OnClick := HandleDeactivateClick;
  
  UpdateLayout;
end;

procedure TFMXLicenseStatusPanel.Resize;
begin
  inherited;
  UpdateLayout;
end;

procedure TFMXLicenseStatusPanel.UpdateLayout;
var
  Y: Single;
begin
  if FCompact then
  begin
    // Compact layout: single line
    FStatusIndicator.Position.X := 10;
    FStatusIndicator.Position.Y := (Height - FStatusIndicator.Height) / 2;
    
    FLblTitle.Position.X := 30;
    FLblTitle.Position.Y := (Height - 18) / 2;
    FLblTitle.Width := 100;
    FLblTitle.Height := 18;
    
    FLblStatus.Position.X := 135;
    FLblStatus.Position.Y := (Height - 18) / 2;
    FLblStatus.Width := 80;
    FLblStatus.Height := 18;
    
    FLblType.Visible := False;
    FLblExpiry.Visible := False;
    FLblIssuedTo.Visible := False;
    
    FBtnActivate.Position.X := Width - 170;
    FBtnActivate.Position.Y := (Height - 28) / 2;
    
    FBtnDeactivate.Position.X := Width - 85;
    FBtnDeactivate.Position.Y := (Height - 28) / 2;
  end
  else
  begin
    // Full layout: multiple lines
    Y := 10;
    
    FStatusIndicator.Position.X := 10;
    FStatusIndicator.Position.Y := Y + 2;
    
    FLblTitle.Position.X := 30;
    FLblTitle.Position.Y := Y;
    FLblTitle.Width := Width - 40;
    FLblTitle.Height := 18;
    Y := Y + 24;
    
    FLblStatus.Visible := True;
    FLblStatus.Position.X := 10;
    FLblStatus.Position.Y := Y;
    FLblStatus.Width := Width - 20;
    FLblStatus.Height := 18;
    Y := Y + 20;
    
    FLblType.Visible := True;
    FLblType.Position.X := 10;
    FLblType.Position.Y := Y;
    FLblType.Width := Width - 20;
    FLblType.Height := 18;
    Y := Y + 20;
    
    FLblExpiry.Visible := True;
    FLblExpiry.Position.X := 10;
    FLblExpiry.Position.Y := Y;
    FLblExpiry.Width := Width - 20;
    FLblExpiry.Height := 18;
    Y := Y + 20;
    
    FLblIssuedTo.Visible := True;
    FLblIssuedTo.Position.X := 10;
    FLblIssuedTo.Position.Y := Y;
    FLblIssuedTo.Width := Width - 20;
    FLblIssuedTo.Height := 18;
    Y := Y + 26;
    
    FBtnActivate.Position.X := 10;
    FBtnActivate.Position.Y := Y;
    
    FBtnDeactivate.Position.X := 96;
    FBtnDeactivate.Position.Y := Y;
  end;
end;

procedure TFMXLicenseStatusPanel.UpdateControls;
var
  Info: TLicenseInfo;
  DaysLeft: Integer;
begin
  if not Assigned(FLicense) then
  begin
    FStatusIndicator.Fill.Color := TAlphaColorRec.Gray;
    FLblStatus.Text := 'No License Manager';
    FLblType.Text := 'Type: -';
    FLblExpiry.Text := 'Expires: -';
    FLblIssuedTo.Text := 'Issued to: -';
    FBtnActivate.Enabled := False;
    FBtnDeactivate.Enabled := False;
    Exit;
  end;
  
  Info := FLicense.LicenseInfo;
  
  // Status indicator color
  FStatusIndicator.Fill.Color := GetStatusColor(Info.Status);
  
  // Status text
  if FLicense.IsLicensed then
    FLblStatus.Text := 'Status: ' + Info.StatusName
  else
    FLblStatus.Text := 'Status: Not Licensed';
  
  // Type
  FLblType.Text := 'Type: ' + Info.TypeName;
  
  // Expiry
  if Info.ExpiresAt = 0 then
    FLblExpiry.Text := 'Expires: Never (Perpetual)'
  else if Info.IsExpired then
    FLblExpiry.Text := 'Expired: ' + DateToStr(Info.ExpiresAt)
  else
  begin
    DaysLeft := Info.DaysRemaining;
    if DaysLeft <= 30 then
      FLblExpiry.Text := Format('Expires: %s (%d days left)', [DateToStr(Info.ExpiresAt), DaysLeft])
    else
      FLblExpiry.Text := 'Expires: ' + DateToStr(Info.ExpiresAt);
  end;
  
  // Issued to
  if Info.IssuedTo <> '' then
    FLblIssuedTo.Text := 'Issued to: ' + Info.IssuedTo
  else
    FLblIssuedTo.Text := 'Issued to: -';
  
  // Button states
  FBtnActivate.Enabled := not FLicense.IsLicensed;
  FBtnDeactivate.Enabled := FLicense.IsLicensed;
end;

function TFMXLicenseStatusPanel.GetStatusColor(Status: TLicenseStatus): TAlphaColor;
begin
  case Status of
    lsValid:          Result := TAlphaColorRec.Limegreen;
    lsExpired:        Result := TAlphaColorRec.Yellow;
    lsInvalid:        Result := TAlphaColorRec.Red;
    lsBlacklisted:    Result := TAlphaColorRec.Maroon;
    lsDeviceMismatch: Result := TAlphaColorRec.Orange;
  else
    Result := TAlphaColorRec.Gray;
  end;
end;

procedure TFMXLicenseStatusPanel.HandleActivateClick(Sender: TObject);
begin
  if Assigned(FOnActivateClick) then
    FOnActivateClick(Self);
end;

procedure TFMXLicenseStatusPanel.HandleDeactivateClick(Sender: TObject);
begin
  if Assigned(FOnDeactivateClick) then
    FOnDeactivateClick(Self);
end;

procedure TFMXLicenseStatusPanel.SetLicense(Value: TUniBaseLicense);
begin
  if FOwnsLicense and Assigned(FLicense) then
    FreeAndNil(FLicense);
  
  FLicense := Value;
  FOwnsLicense := False;
  UpdateControls;
end;

procedure TFMXLicenseStatusPanel.SetCompact(Value: Boolean);
begin
  if FCompact <> Value then
  begin
    FCompact := Value;
    if FCompact then
      Height := 40
    else
      Height := 140;
    UpdateLayout;
  end;
end;

procedure TFMXLicenseStatusPanel.RefreshStatus;
begin
  UpdateControls;
end;

end.
