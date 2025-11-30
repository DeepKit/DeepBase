{ ============================================================================
  Studio.LicenseForm - License Key Management Interface
  
  Version: 1.0
  Features: 
    - License Key generator
    - Issued keys management
    - Key verification/testing
  ============================================================================ }

unit Studio.LicenseForm;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.DateUtils,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.Grids,
  Vcl.Buttons,
  Vcl.Clipbrd,
  UniBase.License;

type
  TLicenseManagerForm = class(TForm)
  private
    FPageControl: TPageControl;
    FTabGenerate: TTabSheet;
    FTabManage: TTabSheet;
    FTabVerify: TTabSheet;
    
    // Generate tab controls
    FPnlGenerate: TPanel;
    FLblIssuedTo: TLabel;
    FEdtIssuedTo: TEdit;
    FLblType: TLabel;
    FCmbType: TComboBox;
    FLblExpiry: TLabel;
    FDtpExpiry: TDateTimePicker;
    FChkNeverExpire: TCheckBox;
    FLblFeatures: TLabel;
    FClbFeatures: TCheckListBox;
    FLblSecretKey: TLabel;
    FEdtSecretKey: TEdit;
    FBtnGenerate: TButton;
    FMmoGeneratedKey: TMemo;
    FBtnCopyKey: TSpeedButton;
    
    // Manage tab controls
    FPnlManage: TPanel;
    FLvKeys: TListView;
    FBtnAddKey: TButton;
    FBtnRevokeKey: TButton;
    FBtnExportKeys: TButton;
    
    // Verify tab controls
    FPnlVerify: TPanel;
    FLblVerifyKey: TLabel;
    FMmoVerifyKey: TMemo;
    FBtnVerify: TButton;
    FMmoVerifyResult: TMemo;
    
    FIssuedKeys: TStringList;
    
    procedure CreateControls;
    procedure CreateGenerateTab;
    procedure CreateManageTab;
    procedure CreateVerifyTab;
    procedure HandleGenerateClick(Sender: TObject);
    procedure HandleCopyKeyClick(Sender: TObject);
    procedure HandleVerifyClick(Sender: TObject);
    procedure HandleNeverExpireChange(Sender: TObject);
    procedure HandleAddKeyClick(Sender: TObject);
    procedure HandleRevokeKeyClick(Sender: TObject);
    procedure HandleExportKeysClick(Sender: TObject);
    procedure LoadIssuedKeys;
    procedure SaveIssuedKeys;
    procedure AddKeyToList(const Key, IssuedTo, LicType: string; ExpiresAt: TDateTime);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  LicenseManagerForm: TLicenseManagerForm;

implementation

uses
  System.IOUtils;

{ TLicenseManagerForm }

constructor TLicenseManagerForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  
  Caption := 'License Manager';
  Width := 700;
  Height := 550;
  Position := poMainFormCenter;
  
  FIssuedKeys := TStringList.Create;
  
  CreateControls;
  LoadIssuedKeys;
end;

destructor TLicenseManagerForm.Destroy;
begin
  FreeAndNil(FIssuedKeys);
  inherited;
end;

procedure TLicenseManagerForm.CreateControls;
begin
  FPageControl := TPageControl.Create(Self);
  FPageControl.Parent := Self;
  FPageControl.Align := alClient;
  
  FTabGenerate := TTabSheet.Create(FPageControl);
  FTabGenerate.PageControl := FPageControl;
  FTabGenerate.Caption := 'Generate Key';
  
  FTabManage := TTabSheet.Create(FPageControl);
  FTabManage.PageControl := FPageControl;
  FTabManage.Caption := 'Manage Keys';
  
  FTabVerify := TTabSheet.Create(FPageControl);
  FTabVerify.PageControl := FPageControl;
  FTabVerify.Caption := 'Verify Key';
  
  CreateGenerateTab;
  CreateManageTab;
  CreateVerifyTab;
end;

procedure TLicenseManagerForm.CreateGenerateTab;
var
  Y: Integer;
begin
  FPnlGenerate := TPanel.Create(Self);
  FPnlGenerate.Parent := FTabGenerate;
  FPnlGenerate.Align := alClient;
  FPnlGenerate.BevelOuter := bvNone;
  
  Y := 16;
  
  // Issued To
  FLblIssuedTo := TLabel.Create(Self);
  FLblIssuedTo.Parent := FPnlGenerate;
  FLblIssuedTo.Caption := 'Issued To (Name/Company):';
  FLblIssuedTo.SetBounds(16, Y, 200, 16);
  Inc(Y, 18);
  
  FEdtIssuedTo := TEdit.Create(Self);
  FEdtIssuedTo.Parent := FPnlGenerate;
  FEdtIssuedTo.SetBounds(16, Y, 300, 24);
  Inc(Y, 32);
  
  // License Type
  FLblType := TLabel.Create(Self);
  FLblType.Parent := FPnlGenerate;
  FLblType.Caption := 'License Type:';
  FLblType.SetBounds(16, Y, 100, 16);
  Inc(Y, 18);
  
  FCmbType := TComboBox.Create(Self);
  FCmbType.Parent := FPnlGenerate;
  FCmbType.Style := csDropDownList;
  FCmbType.Items.Add('Trial');
  FCmbType.Items.Add('Standard');
  FCmbType.Items.Add('Professional');
  FCmbType.Items.Add('Enterprise');
  FCmbType.ItemIndex := 1;
  FCmbType.SetBounds(16, Y, 200, 24);
  Inc(Y, 32);
  
  // Expiry
  FLblExpiry := TLabel.Create(Self);
  FLblExpiry.Parent := FPnlGenerate;
  FLblExpiry.Caption := 'Expires:';
  FLblExpiry.SetBounds(16, Y, 100, 16);
  Inc(Y, 18);
  
  FDtpExpiry := TDateTimePicker.Create(Self);
  FDtpExpiry.Parent := FPnlGenerate;
  FDtpExpiry.Date := IncYear(Now, 1);
  FDtpExpiry.SetBounds(16, Y, 150, 24);
  
  FChkNeverExpire := TCheckBox.Create(Self);
  FChkNeverExpire.Parent := FPnlGenerate;
  FChkNeverExpire.Caption := 'Never Expire (Perpetual)';
  FChkNeverExpire.SetBounds(180, Y + 2, 180, 20);
  FChkNeverExpire.OnClick := HandleNeverExpireChange;
  Inc(Y, 32);
  
  // Features
  FLblFeatures := TLabel.Create(Self);
  FLblFeatures.Parent := FPnlGenerate;
  FLblFeatures.Caption := 'Features:';
  FLblFeatures.SetBounds(16, Y, 100, 16);
  Inc(Y, 18);
  
  FClbFeatures := TCheckListBox.Create(Self);
  FClbFeatures.Parent := FPnlGenerate;
  FClbFeatures.Items.Add('*  (All Features)');
  FClbFeatures.Items.Add('llm');
  FClbFeatures.Items.Add('auto_update');
  FClbFeatures.Items.Add('remote_config');
  FClbFeatures.Items.Add('analytics');
  FClbFeatures.Items.Add('priority_support');
  FClbFeatures.Checked[0] := True;
  FClbFeatures.SetBounds(16, Y, 200, 100);
  Inc(Y, 108);
  
  // Secret Key
  FLblSecretKey := TLabel.Create(Self);
  FLblSecretKey.Parent := FPnlGenerate;
  FLblSecretKey.Caption := 'Secret Key (for signing):';
  FLblSecretKey.SetBounds(16, Y, 200, 16);
  Inc(Y, 18);
  
  FEdtSecretKey := TEdit.Create(Self);
  FEdtSecretKey.Parent := FPnlGenerate;
  FEdtSecretKey.Text := 'UniBase2024SecretKey';
  FEdtSecretKey.SetBounds(16, Y, 300, 24);
  Inc(Y, 32);
  
  // Generate Button
  FBtnGenerate := TButton.Create(Self);
  FBtnGenerate.Parent := FPnlGenerate;
  FBtnGenerate.Caption := 'Generate License Key';
  FBtnGenerate.SetBounds(16, Y, 150, 28);
  FBtnGenerate.OnClick := HandleGenerateClick;
  Inc(Y, 40);
  
  // Generated Key
  FMmoGeneratedKey := TMemo.Create(Self);
  FMmoGeneratedKey.Parent := FPnlGenerate;
  FMmoGeneratedKey.ReadOnly := True;
  FMmoGeneratedKey.ScrollBars := ssVertical;
  FMmoGeneratedKey.SetBounds(16, Y, 400, 60);
  
  FBtnCopyKey := TSpeedButton.Create(Self);
  FBtnCopyKey.Parent := FPnlGenerate;
  FBtnCopyKey.Caption := 'Copy';
  FBtnCopyKey.SetBounds(420, Y, 60, 25);
  FBtnCopyKey.OnClick := HandleCopyKeyClick;
end;

procedure TLicenseManagerForm.CreateManageTab;
begin
  FPnlManage := TPanel.Create(Self);
  FPnlManage.Parent := FTabManage;
  FPnlManage.Align := alClient;
  FPnlManage.BevelOuter := bvNone;
  
  FLvKeys := TListView.Create(Self);
  FLvKeys.Parent := FPnlManage;
  FLvKeys.Align := alClient;
  FLvKeys.ViewStyle := vsReport;
  FLvKeys.RowSelect := True;
  FLvKeys.GridLines := True;
  
  with FLvKeys.Columns.Add do
  begin
    Caption := 'Issued To';
    Width := 150;
  end;
  with FLvKeys.Columns.Add do
  begin
    Caption := 'Type';
    Width := 100;
  end;
  with FLvKeys.Columns.Add do
  begin
    Caption := 'Expires';
    Width := 100;
  end;
  with FLvKeys.Columns.Add do
  begin
    Caption := 'Key (truncated)';
    Width := 250;
  end;
  
  // Buttons panel
  var PnlButtons := TPanel.Create(Self);
  PnlButtons.Parent := FPnlManage;
  PnlButtons.Align := alBottom;
  PnlButtons.Height := 40;
  PnlButtons.BevelOuter := bvNone;
  
  FBtnAddKey := TButton.Create(Self);
  FBtnAddKey.Parent := PnlButtons;
  FBtnAddKey.Caption := 'Add from Generate';
  FBtnAddKey.SetBounds(8, 8, 120, 25);
  FBtnAddKey.OnClick := HandleAddKeyClick;
  
  FBtnRevokeKey := TButton.Create(Self);
  FBtnRevokeKey.Parent := PnlButtons;
  FBtnRevokeKey.Caption := 'Revoke Selected';
  FBtnRevokeKey.SetBounds(136, 8, 120, 25);
  FBtnRevokeKey.OnClick := HandleRevokeKeyClick;
  
  FBtnExportKeys := TButton.Create(Self);
  FBtnExportKeys.Parent := PnlButtons;
  FBtnExportKeys.Caption := 'Export to CSV';
  FBtnExportKeys.SetBounds(264, 8, 100, 25);
  FBtnExportKeys.OnClick := HandleExportKeysClick;
end;

procedure TLicenseManagerForm.CreateVerifyTab;
var
  Y: Integer;
begin
  FPnlVerify := TPanel.Create(Self);
  FPnlVerify.Parent := FTabVerify;
  FPnlVerify.Align := alClient;
  FPnlVerify.BevelOuter := bvNone;
  
  Y := 16;
  
  FLblVerifyKey := TLabel.Create(Self);
  FLblVerifyKey.Parent := FPnlVerify;
  FLblVerifyKey.Caption := 'Paste License Key to Verify:';
  FLblVerifyKey.SetBounds(16, Y, 200, 16);
  Inc(Y, 20);
  
  FMmoVerifyKey := TMemo.Create(Self);
  FMmoVerifyKey.Parent := FPnlVerify;
  FMmoVerifyKey.ScrollBars := ssVertical;
  FMmoVerifyKey.SetBounds(16, Y, 500, 80);
  Inc(Y, 88);
  
  FBtnVerify := TButton.Create(Self);
  FBtnVerify.Parent := FPnlVerify;
  FBtnVerify.Caption := 'Verify Key';
  FBtnVerify.SetBounds(16, Y, 100, 28);
  FBtnVerify.OnClick := HandleVerifyClick;
  Inc(Y, 40);
  
  var LblResult := TLabel.Create(Self);
  LblResult.Parent := FPnlVerify;
  LblResult.Caption := 'Verification Result:';
  LblResult.SetBounds(16, Y, 150, 16);
  Inc(Y, 20);
  
  FMmoVerifyResult := TMemo.Create(Self);
  FMmoVerifyResult.Parent := FPnlVerify;
  FMmoVerifyResult.ReadOnly := True;
  FMmoVerifyResult.ScrollBars := ssVertical;
  FMmoVerifyResult.SetBounds(16, Y, 500, 200);
end;

procedure TLicenseManagerForm.HandleGenerateClick(Sender: TObject);
var
  IssuedTo, SecretKey: string;
  LicType: TLicenseType;
  ExpiresAt: TDateTime;
  Features: TArray<string>;
  I, Count: Integer;
  Key: string;
begin
  IssuedTo := Trim(FEdtIssuedTo.Text);
  if IssuedTo = '' then
  begin
    ShowMessage('Please enter the licensee name.');
    FEdtIssuedTo.SetFocus;
    Exit;
  end;
  
  SecretKey := Trim(FEdtSecretKey.Text);
  if SecretKey = '' then
  begin
    ShowMessage('Please enter a secret key.');
    FEdtSecretKey.SetFocus;
    Exit;
  end;
  
  LicType := TLicenseType(FCmbType.ItemIndex + 1); // Skip ltNone
  
  if FChkNeverExpire.Checked then
    ExpiresAt := 0
  else
    ExpiresAt := FDtpExpiry.Date + 1; // End of day
  
  // Collect features
  Count := 0;
  for I := 0 to FClbFeatures.Items.Count - 1 do
    if FClbFeatures.Checked[I] then
      Inc(Count);
  
  SetLength(Features, Count);
  Count := 0;
  for I := 0 to FClbFeatures.Items.Count - 1 do
  begin
    if FClbFeatures.Checked[I] then
    begin
      Features[Count] := FClbFeatures.Items[I];
      if Pos(' ', Features[Count]) > 0 then
        Features[Count] := Copy(Features[Count], 1, Pos(' ', Features[Count]) - 1);
      Inc(Count);
    end;
  end;
  
  // Generate key
  Key := TUniBaseLicense.GenerateLicenseKey(IssuedTo, LicType, ExpiresAt, Features, SecretKey);
  FMmoGeneratedKey.Text := Key;
end;

procedure TLicenseManagerForm.HandleCopyKeyClick(Sender: TObject);
begin
  if FMmoGeneratedKey.Text <> '' then
  begin
    Clipboard.AsText := FMmoGeneratedKey.Text;
    ShowMessage('License key copied to clipboard.');
  end;
end;

procedure TLicenseManagerForm.HandleVerifyClick(Sender: TObject);
var
  Key, SecretKey: string;
  License: TUniBaseLicense;
  Result: TLicenseValidationResult;
  SL: TStringList;
  I: Integer;
begin
  Key := Trim(FMmoVerifyKey.Text);
  if Key = '' then
  begin
    ShowMessage('Please paste a license key to verify.');
    Exit;
  end;
  
  SecretKey := Trim(FEdtSecretKey.Text);
  
  License := TUniBaseLicense.Create;
  try
    License.SecretKey := SecretKey;
    Result := License.ValidateLicense(Key);
    
    SL := TStringList.Create;
    try
      SL.Add('=== Verification Result ===');
      SL.Add('');
      SL.Add('Valid: ' + BoolToStr(Result.Success, True));
      SL.Add('Status: ' + TUniBaseLicense.LicenseStatusName(Result.Status));
      SL.Add('Message: ' + Result.Message);
      SL.Add('');
      
      if Result.Success then
      begin
        SL.Add('=== License Details ===');
        SL.Add('');
        SL.Add('Issued To: ' + Result.Info.IssuedTo);
        SL.Add('Type: ' + Result.Info.TypeName);
        SL.Add('Issued At: ' + DateTimeToStr(Result.Info.IssuedAt));
        
        if Result.Info.ExpiresAt = 0 then
          SL.Add('Expires: Never (Perpetual)')
        else
          SL.Add('Expires: ' + DateTimeToStr(Result.Info.ExpiresAt));
        
        SL.Add('Device ID: ' + Result.Info.DeviceId);
        SL.Add('Max Devices: ' + IntToStr(Result.Info.MaxDevices));
        SL.Add('');
        SL.Add('Features:');
        for I := 0 to High(Result.Info.Features) do
          SL.Add('  - ' + Result.Info.Features[I]);
      end;
      
      FMmoVerifyResult.Text := SL.Text;
    finally
      SL.Free;
    end;
  finally
    License.Free;
  end;
end;

procedure TLicenseManagerForm.HandleNeverExpireChange(Sender: TObject);
begin
  FDtpExpiry.Enabled := not FChkNeverExpire.Checked;
end;

procedure TLicenseManagerForm.HandleAddKeyClick(Sender: TObject);
var
  Key: string;
  ExpiresAt: TDateTime;
begin
  Key := Trim(FMmoGeneratedKey.Text);
  if Key = '' then
  begin
    ShowMessage('Please generate a key first.');
    FPageControl.ActivePage := FTabGenerate;
    Exit;
  end;
  
  if FChkNeverExpire.Checked then
    ExpiresAt := 0
  else
    ExpiresAt := FDtpExpiry.Date;
  
  AddKeyToList(Key, FEdtIssuedTo.Text, FCmbType.Text, ExpiresAt);
  SaveIssuedKeys;
  
  ShowMessage('Key added to management list.');
end;

procedure TLicenseManagerForm.HandleRevokeKeyClick(Sender: TObject);
begin
  if FLvKeys.Selected = nil then
  begin
    ShowMessage('Please select a key to revoke.');
    Exit;
  end;
  
  if MessageDlg('Are you sure you want to revoke this key?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    FIssuedKeys.Delete(FLvKeys.Selected.Index);
    FLvKeys.Selected.Delete;
    SaveIssuedKeys;
  end;
end;

procedure TLicenseManagerForm.HandleExportKeysClick(Sender: TObject);
var
  SaveDlg: TSaveDialog;
  SL: TStringList;
  I: Integer;
begin
  SaveDlg := TSaveDialog.Create(Self);
  try
    SaveDlg.Filter := 'CSV Files (*.csv)|*.csv';
    SaveDlg.DefaultExt := 'csv';
    SaveDlg.FileName := 'license_keys.csv';
    
    if SaveDlg.Execute then
    begin
      SL := TStringList.Create;
      try
        SL.Add('IssuedTo,Type,Expires,Key');
        for I := 0 to FLvKeys.Items.Count - 1 do
        begin
          SL.Add(Format('"%s","%s","%s","%s"', [
            FLvKeys.Items[I].Caption,
            FLvKeys.Items[I].SubItems[0],
            FLvKeys.Items[I].SubItems[1],
            FIssuedKeys[I]
          ]));
        end;
        SL.SaveToFile(SaveDlg.FileName);
        ShowMessage('Keys exported to ' + SaveDlg.FileName);
      finally
        SL.Free;
      end;
    end;
  finally
    SaveDlg.Free;
  end;
end;

procedure TLicenseManagerForm.AddKeyToList(const Key, IssuedTo, LicType: string; ExpiresAt: TDateTime);
var
  Item: TListItem;
begin
  Item := FLvKeys.Items.Add;
  Item.Caption := IssuedTo;
  Item.SubItems.Add(LicType);
  
  if ExpiresAt = 0 then
    Item.SubItems.Add('Never')
  else
    Item.SubItems.Add(DateToStr(ExpiresAt));
  
  Item.SubItems.Add(Copy(Key, 1, 40) + '...');
  
  FIssuedKeys.Add(Key);
end;

procedure TLicenseManagerForm.LoadIssuedKeys;
var
  FilePath: string;
  JsonStr: string;
  JsonArr: TJSONArray;
  JsonObj: TJSONObject;
  I: Integer;
begin
  FilePath := TPath.Combine(TPath.GetHomePath, '.unibase_studio_keys.json');
  
  if not FileExists(FilePath) then
    Exit;
  
  try
    JsonStr := TFile.ReadAllText(FilePath, TEncoding.UTF8);
    JsonArr := TJSONObject.ParseJSONValue(JsonStr) as TJSONArray;
    
    if Assigned(JsonArr) then
    try
      for I := 0 to JsonArr.Count - 1 do
      begin
        JsonObj := JsonArr.Items[I] as TJSONObject;
        AddKeyToList(
          JsonObj.GetValue<string>('key', ''),
          JsonObj.GetValue<string>('issued_to', ''),
          JsonObj.GetValue<string>('type', ''),
          JsonObj.GetValue<Double>('expires', 0)
        );
      end;
    finally
      JsonArr.Free;
    end;
  except
    // Ignore load errors
  end;
end;

procedure TLicenseManagerForm.SaveIssuedKeys;
var
  FilePath: string;
  JsonArr: TJSONArray;
  JsonObj: TJSONObject;
  I: Integer;
begin
  FilePath := TPath.Combine(TPath.GetHomePath, '.unibase_studio_keys.json');
  
  JsonArr := TJSONArray.Create;
  try
    for I := 0 to FLvKeys.Items.Count - 1 do
    begin
      JsonObj := TJSONObject.Create;
      JsonObj.AddPair('key', FIssuedKeys[I]);
      JsonObj.AddPair('issued_to', FLvKeys.Items[I].Caption);
      JsonObj.AddPair('type', FLvKeys.Items[I].SubItems[0]);
      
      if FLvKeys.Items[I].SubItems[1] = 'Never' then
        JsonObj.AddPair('expires', TJSONNumber.Create(0))
      else
        JsonObj.AddPair('expires', TJSONNumber.Create(StrToDate(FLvKeys.Items[I].SubItems[1])));
      
      JsonArr.Add(JsonObj);
    end;
    
    TFile.WriteAllText(FilePath, JsonArr.Format(2), TEncoding.UTF8);
  finally
    JsonArr.Free;
  end;
end;

end.
