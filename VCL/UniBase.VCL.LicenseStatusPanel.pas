{ ============================================================================
  UniBase.VCL.LicenseStatusPanel - 许可证状态面板组件
  
  版本: 1.0
  功能: 显示当前许可证状态、类型、过期时间等信息
  ============================================================================ }

unit UniBase.VCL.LicenseStatusPanel;

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.StdCtrls,
  Vcl.Graphics,
  Vcl.Buttons,
  UniBase.License;

type
  TLicenseStatusPanel = class(TCustomPanel)
  private
    FLblTitle: TLabel;
    FLblStatus: TLabel;
    FLblType: TLabel;
    FLblExpiry: TLabel;
    FLblIssuedTo: TLabel;
    FBtnActivate: TSpeedButton;
    FBtnDeactivate: TSpeedButton;
    FShapeStatus: TShape;
    FLicense: TUniBaseLicense;
    FOwnsLicense: Boolean;
    FOnActivateClick: TNotifyEvent;
    FOnDeactivateClick: TNotifyEvent;
    FCompact: Boolean;
    
    procedure CreateControls;
    procedure UpdateControls;
    procedure HandleActivateClick(Sender: TObject);
    procedure HandleDeactivateClick(Sender: TObject);
    procedure SetLicense(Value: TUniBaseLicense);
    procedure SetCompact(Value: Boolean);
    function GetStatusColor(Status: TLicenseStatus): TColor;
  protected
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    /// <summary>刷新显示</summary>
    procedure RefreshStatus;
    
    /// <summary>关联的许可证管理器</summary>
    property License: TUniBaseLicense read FLicense write SetLicense;
  published
    property Align;
    property Anchors;
    property BevelOuter default bvNone;
    property Color;
    property Enabled;
    property Font;
    property ParentColor;
    property ParentFont;
    property Visible;
    
    /// <summary>紧凑模式</summary>
    property Compact: Boolean read FCompact write SetCompact default False;
    
    /// <summary>激活按钮点击事件</summary>
    property OnActivateClick: TNotifyEvent read FOnActivateClick write FOnActivateClick;
    
    /// <summary>停用按钮点击事件</summary>
    property OnDeactivateClick: TNotifyEvent read FOnDeactivateClick write FOnDeactivateClick;
  end;

procedure Register;

implementation

uses
  System.DateUtils;

procedure Register;
begin
  RegisterComponents('UniBase', [TLicenseStatusPanel]);
end;

{ TLicenseStatusPanel }

constructor TLicenseStatusPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  
  BevelOuter := bvNone;
  Width := 300;
  Height := 120;
  FCompact := False;
  FOwnsLicense := True;
  FLicense := TUniBaseLicense.Create;
  
  CreateControls;
  UpdateControls;
end;

destructor TLicenseStatusPanel.Destroy;
begin
  if FOwnsLicense then
    FreeAndNil(FLicense);
  inherited;
end;

procedure TLicenseStatusPanel.CreateControls;
begin
  // 状态指示灯
  FShapeStatus := TShape.Create(Self);
  FShapeStatus.Parent := Self;
  FShapeStatus.Shape := stCircle;
  FShapeStatus.Width := 12;
  FShapeStatus.Height := 12;
  FShapeStatus.Brush.Color := clGray;
  FShapeStatus.Pen.Style := psClear;
  
  // 标题
  FLblTitle := TLabel.Create(Self);
  FLblTitle.Parent := Self;
  FLblTitle.Caption := 'License Status';
  FLblTitle.Font.Style := [fsBold];
  
  // 状态
  FLblStatus := TLabel.Create(Self);
  FLblStatus.Parent := Self;
  FLblStatus.Caption := 'Not Licensed';
  
  // 类型
  FLblType := TLabel.Create(Self);
  FLblType.Parent := Self;
  FLblType.Caption := 'Type: -';
  
  // 过期时间
  FLblExpiry := TLabel.Create(Self);
  FLblExpiry.Parent := Self;
  FLblExpiry.Caption := 'Expires: -';
  
  // 授权给
  FLblIssuedTo := TLabel.Create(Self);
  FLblIssuedTo.Parent := Self;
  FLblIssuedTo.Caption := 'Issued to: -';
  
  // 激活按钮
  FBtnActivate := TSpeedButton.Create(Self);
  FBtnActivate.Parent := Self;
  FBtnActivate.Caption := 'Activate';
  FBtnActivate.Width := 70;
  FBtnActivate.Height := 25;
  FBtnActivate.OnClick := HandleActivateClick;
  
  // 停用按钮
  FBtnDeactivate := TSpeedButton.Create(Self);
  FBtnDeactivate.Parent := Self;
  FBtnDeactivate.Caption := 'Deactivate';
  FBtnDeactivate.Width := 70;
  FBtnDeactivate.Height := 25;
  FBtnDeactivate.OnClick := HandleDeactivateClick;
end;

procedure TLicenseStatusPanel.Resize;
var
  Y: Integer;
begin
  inherited;
  
  if FCompact then
  begin
    // 紧凑布局：单行
    FShapeStatus.SetBounds(8, (Height - FShapeStatus.Height) div 2, 12, 12);
    FLblTitle.SetBounds(28, (Height - FLblTitle.Height) div 2, 100, FLblTitle.Height);
    FLblStatus.SetBounds(130, (Height - FLblStatus.Height) div 2, 80, FLblStatus.Height);
    FLblType.Visible := False;
    FLblExpiry.Visible := False;
    FLblIssuedTo.Visible := False;
    FBtnActivate.SetBounds(Width - 150, (Height - 25) div 2, 70, 25);
    FBtnDeactivate.SetBounds(Width - 75, (Height - 25) div 2, 70, 25);
  end
  else
  begin
    // 完整布局：多行
    Y := 8;
    
    FShapeStatus.SetBounds(8, Y + 2, 12, 12);
    FLblTitle.SetBounds(28, Y, Width - 36, FLblTitle.Height);
    Inc(Y, FLblTitle.Height + 8);
    
    FLblStatus.SetBounds(8, Y, Width - 16, FLblStatus.Height);
    Inc(Y, FLblStatus.Height + 4);
    
    FLblType.Visible := True;
    FLblType.SetBounds(8, Y, Width - 16, FLblType.Height);
    Inc(Y, FLblType.Height + 4);
    
    FLblExpiry.Visible := True;
    FLblExpiry.SetBounds(8, Y, Width - 16, FLblExpiry.Height);
    Inc(Y, FLblExpiry.Height + 4);
    
    FLblIssuedTo.Visible := True;
    FLblIssuedTo.SetBounds(8, Y, Width - 16, FLblIssuedTo.Height);
    Inc(Y, FLblIssuedTo.Height + 8);
    
    FBtnActivate.SetBounds(8, Y, 70, 25);
    FBtnDeactivate.SetBounds(84, Y, 70, 25);
  end;
end;

procedure TLicenseStatusPanel.UpdateControls;
var
  Info: TLicenseInfo;
  DaysLeft: Integer;
begin
  if not Assigned(FLicense) then
  begin
    FShapeStatus.Brush.Color := clGray;
    FLblStatus.Caption := 'No License Manager';
    FLblType.Caption := 'Type: -';
    FLblExpiry.Caption := 'Expires: -';
    FLblIssuedTo.Caption := 'Issued to: -';
    FBtnActivate.Enabled := False;
    FBtnDeactivate.Enabled := False;
    Exit;
  end;
  
  Info := FLicense.LicenseInfo;
  
  // 状态指示灯颜色
  FShapeStatus.Brush.Color := GetStatusColor(Info.Status);
  
  // 状态文字
  if FLicense.IsLicensed then
    FLblStatus.Caption := 'Status: ' + Info.StatusName
  else
    FLblStatus.Caption := 'Status: Not Licensed';
  
  // 类型
  FLblType.Caption := 'Type: ' + Info.TypeName;
  
  // 过期时间
  if Info.ExpiresAt = 0 then
    FLblExpiry.Caption := 'Expires: Never (Perpetual)'
  else if Info.IsExpired then
    FLblExpiry.Caption := 'Expired: ' + DateToStr(Info.ExpiresAt)
  else
  begin
    DaysLeft := Info.DaysRemaining;
    if DaysLeft <= 30 then
      FLblExpiry.Caption := Format('Expires: %s (%d days left)', [DateToStr(Info.ExpiresAt), DaysLeft])
    else
      FLblExpiry.Caption := 'Expires: ' + DateToStr(Info.ExpiresAt);
  end;
  
  // 授权给
  if Info.IssuedTo <> '' then
    FLblIssuedTo.Caption := 'Issued to: ' + Info.IssuedTo
  else
    FLblIssuedTo.Caption := 'Issued to: -';
  
  // 按钮状态
  FBtnActivate.Enabled := not FLicense.IsLicensed;
  FBtnDeactivate.Enabled := FLicense.IsLicensed;
end;

function TLicenseStatusPanel.GetStatusColor(Status: TLicenseStatus): TColor;
begin
  case Status of
    lsValid: Result := clLime;
    lsExpired: Result := clYellow;
    lsInvalid: Result := clRed;
    lsBlacklisted: Result := clMaroon;
    lsDeviceMismatch: Result := clOrange;
  else
    Result := clGray;
  end;
end;

procedure TLicenseStatusPanel.HandleActivateClick(Sender: TObject);
begin
  if Assigned(FOnActivateClick) then
    FOnActivateClick(Self);
end;

procedure TLicenseStatusPanel.HandleDeactivateClick(Sender: TObject);
begin
  if Assigned(FOnDeactivateClick) then
    FOnDeactivateClick(Self);
end;

procedure TLicenseStatusPanel.SetLicense(Value: TUniBaseLicense);
begin
  if FOwnsLicense and Assigned(FLicense) then
    FreeAndNil(FLicense);
  
  FLicense := Value;
  FOwnsLicense := False;
  UpdateControls;
end;

procedure TLicenseStatusPanel.SetCompact(Value: Boolean);
begin
  if FCompact <> Value then
  begin
    FCompact := Value;
    if FCompact then
      Height := 32
    else
      Height := 120;
    Resize;
  end;
end;

procedure TLicenseStatusPanel.RefreshStatus;
begin
  UpdateControls;
end;

end.
