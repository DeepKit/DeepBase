unit Form.CustomerEdit;

{*******************************************************************************
  CRUD Application Template - Customer Edit Form
  
  This form demonstrates:
  - Entity editing with validation
  - Data binding concepts
  - Form layout patterns
  
  DeepBase features:
  - Entity validation
  - Logging
*******************************************************************************}

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Entity.Customer;

type
  TCustomerEditForm = class(TForm)
    PnlBottom: TPanel;
    BtnOK: TButton;
    BtnCancel: TButton;
    PageControl: TPageControl;
    TabBasic: TTabSheet;
    TabAddress: TTabSheet;
    TabNotes: TTabSheet;
    LblFirstName: TLabel;
    EdtFirstName: TEdit;
    LblLastName: TLabel;
    EdtLastName: TEdit;
    LblEmail: TLabel;
    EdtEmail: TEdit;
    LblPhone: TLabel;
    EdtPhone: TEdit;
    LblStatus: TLabel;
    CmbStatus: TComboBox;
    LblAddress: TLabel;
    EdtAddress: TEdit;
    LblCity: TLabel;
    EdtCity: TEdit;
    LblCountry: TLabel;
    EdtCountry: TEdit;
    LblPostalCode: TLabel;
    EdtPostalCode: TEdit;
    LblNotes: TLabel;
    MemoNotes: TMemo;
    LblCreatedAt: TLabel;
    LblCreatedAtValue: TLabel;
    LblUpdatedAt: TLabel;
    LblUpdatedAtValue: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure BtnOKClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    FCustomer: TCustomer;
    FIsNewCustomer: Boolean;
    
    procedure LoadFromCustomer;
    procedure SaveToCustomer;
    function ValidateInput: Boolean;
  public
    property Customer: TCustomer read FCustomer write FCustomer;
    property IsNewCustomer: Boolean read FIsNewCustomer write FIsNewCustomer;
  end;

var
  CustomerEditForm: TCustomerEditForm;

implementation

{$R *.dfm}

uses
  Data.Module,
  DeepBase.Logging;

{ TCustomerEditForm }

procedure TCustomerEditForm.FormCreate(Sender: TObject);
begin
  FCustomer := nil;
  FIsNewCustomer := True;
  
  // Setup status combo
  CmbStatus.Items.Clear;
  CmbStatus.Items.Add('Active');
  CmbStatus.Items.Add('Inactive');
  CmbStatus.Items.Add('Suspended');
  CmbStatus.ItemIndex := 0;
  
  PageControl.ActivePageIndex := 0;
end;

procedure TCustomerEditForm.FormShow(Sender: TObject);
begin
  if FIsNewCustomer then
    Caption := 'Add Customer'
  else
    Caption := 'Edit Customer';
    
  LoadFromCustomer;
  EdtFirstName.SetFocus;
end;

procedure TCustomerEditForm.LoadFromCustomer;
begin
  if FCustomer = nil then
    Exit;
    
  // Basic info
  EdtFirstName.Text := FCustomer.FirstName;
  EdtLastName.Text := FCustomer.LastName;
  EdtEmail.Text := FCustomer.Email;
  EdtPhone.Text := FCustomer.Phone;
  
  case FCustomer.StatusEnum of
    csActive: CmbStatus.ItemIndex := 0;
    csInactive: CmbStatus.ItemIndex := 1;
    csSuspended: CmbStatus.ItemIndex := 2;
  else
    CmbStatus.ItemIndex := 0;
  end;
  
  // Address
  EdtAddress.Text := FCustomer.Address;
  EdtCity.Text := FCustomer.City;
  EdtCountry.Text := FCustomer.Country;
  EdtPostalCode.Text := FCustomer.PostalCode;
  
  // Notes
  MemoNotes.Text := FCustomer.Notes;
  
  // Audit info
  if FCustomer.CreatedAt > 0 then
    LblCreatedAtValue.Caption := FormatDateTime('yyyy-mm-dd hh:nn:ss', FCustomer.CreatedAt)
  else
    LblCreatedAtValue.Caption := '-';
    
  if FCustomer.UpdatedAt > 0 then
    LblUpdatedAtValue.Caption := FormatDateTime('yyyy-mm-dd hh:nn:ss', FCustomer.UpdatedAt)
  else
    LblUpdatedAtValue.Caption := '-';
end;

procedure TCustomerEditForm.SaveToCustomer;
begin
  if FCustomer = nil then
    Exit;
    
  // Basic info
  FCustomer.FirstName := Trim(EdtFirstName.Text);
  FCustomer.LastName := Trim(EdtLastName.Text);
  FCustomer.Email := Trim(EdtEmail.Text);
  FCustomer.Phone := Trim(EdtPhone.Text);
  
  case CmbStatus.ItemIndex of
    0: FCustomer.StatusEnum := csActive;
    1: FCustomer.StatusEnum := csInactive;
    2: FCustomer.StatusEnum := csSuspended;
  end;
  
  // Address
  FCustomer.Address := Trim(EdtAddress.Text);
  FCustomer.City := Trim(EdtCity.Text);
  FCustomer.Country := Trim(EdtCountry.Text);
  FCustomer.PostalCode := Trim(EdtPostalCode.Text);
  
  // Notes
  FCustomer.Notes := MemoNotes.Text;
end;

function TCustomerEditForm.ValidateInput: Boolean;
var
  ErrorMsg: string;
begin
  Result := False;
  
  // First, save to customer object for validation
  SaveToCustomer;
  
  // Use entity validation
  if not FCustomer.Validate(ErrorMsg) then
  begin
    MessageDlg(ErrorMsg, mtError, [mbOK], 0);
    
    // Focus appropriate field
    if Pos('First name', ErrorMsg) > 0 then
    begin
      PageControl.ActivePage := TabBasic;
      EdtFirstName.SetFocus;
    end
    else if Pos('Last name', ErrorMsg) > 0 then
    begin
      PageControl.ActivePage := TabBasic;
      EdtLastName.SetFocus;
    end
    else if Pos('Email', ErrorMsg) > 0 then
    begin
      PageControl.ActivePage := TabBasic;
      EdtEmail.SetFocus;
    end;
    Exit;
  end;
  
  // Check for duplicate email
  if DataMod.EmailExists(FCustomer.Email, FCustomer.Id) then
  begin
    MessageDlg('A customer with this email already exists.', mtError, [mbOK], 0);
    PageControl.ActivePage := TabBasic;
    EdtEmail.SetFocus;
    Exit;
  end;
  
  Result := True;
end;

procedure TCustomerEditForm.BtnOKClick(Sender: TObject);
begin
  if ValidateInput then
  begin
    Log.Debug('Customer validated: %s', [FCustomer.DisplayName]);
    ModalResult := mrOK;
  end;
end;

end.
