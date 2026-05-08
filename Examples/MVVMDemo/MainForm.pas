{ ============================================================================
  MainForm - MVVM Demo Main Form
  
  Description: Demonstrates MVVM pattern with data binding, commands,
               and validation in a login form.
  ============================================================================ }

unit MainForm;

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Variants, System.Classes, System.Rtti,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  Vcl.ExtCtrls, Vcl.ComCtrls,
  DeepBase.DataBinding,
  DeepBase.MVVM,
  DeepBase.VCL.MVVMControls,
  LoginViewModel;

type
  TfrmMain = class(TForm)
    pnlLogin: TPanel;
    lblTitle: TLabel;
    lblUsername: TLabel;
    edtUsername: TEdit;
    lblPassword: TLabel;
    edtPassword: TEdit;
    chkRememberMe: TCheckBox;
    btnLogin: TButton;
    btnCancel: TButton;
    lblMessage: TLabel;
    pnlBusy: TPanel;
    lblBusy: TLabel;
    pbProgress: TProgressBar;
    lblUsernameError: TLabel;
    lblPasswordError: TLabel;
    pnlSuccess: TPanel;
    lblWelcome: TLabel;
    btnLogout: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure edtUsernameChange(Sender: TObject);
    procedure edtPasswordChange(Sender: TObject);
    procedure chkRememberMeClick(Sender: TObject);
    procedure btnLoginClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure btnLogoutClick(Sender: TObject);
  private
    FViewModel: TLoginViewModel;
    FBindingManager: TBindingManager;
    
    procedure HandlePropertyChanged(const Args: TPropertyChangedEventArgs);
    procedure HandlePropertyError(Sender: TObject; const Args: TPropertyErrorEventArgs);
    procedure UpdateUI;
    procedure UpdateBusyState;
    procedure UpdateErrorLabels;
    procedure SetupBindings;
  public
    property ViewModel: TLoginViewModel read FViewModel;
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

{ TfrmMain }

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  // Create ViewModel
  FViewModel := TLoginViewModel.Create;
  FBindingManager := TBindingManager.Create;
  
  // Subscribe to ViewModel events
  FViewModel.AddPropertyChangedHandler(HandlePropertyChanged);
  FViewModel.AddPropertyErrorHandler(HandlePropertyError);
  
  // Setup bindings
  SetupBindings;
  
  // Initial UI state
  pnlBusy.Visible := False;
  pnlSuccess.Visible := False;
  lblUsernameError.Visible := False;
  lblPasswordError.Visible := False;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  FViewModel.RemovePropertyChangedHandler(HandlePropertyChanged);
  FViewModel.RemovePropertyErrorHandler(HandlePropertyError);
  FBindingManager.Free;
  FViewModel.Free;
end;

procedure TfrmMain.FormShow(Sender: TObject);
begin
  FViewModel.Activate;
  UpdateUI;
end;

procedure TfrmMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  FViewModel.Deactivate;
end;

procedure TfrmMain.SetupBindings;
begin
  // Bind ViewModel properties to controls using TBindingManager
  // Note: For simpler two-way binding, we use manual event handlers
  // In a real app, you might use TMVVMForm<T> base class
  
  // Initial sync from ViewModel to controls
  edtUsername.Text := FViewModel.Username;
  edtPassword.Text := FViewModel.Password;
  chkRememberMe.Checked := FViewModel.RememberMe;
end;

procedure TfrmMain.HandlePropertyChanged(const Args: TPropertyChangedEventArgs);
begin
  // Update UI when ViewModel properties change
  if Args.PropertyName = 'IsBusy' then
    UpdateBusyState
  else if Args.PropertyName = 'LoginMessage' then
    lblMessage.Caption := FViewModel.LoginMessage
  else if Args.PropertyName = 'IsLoggedIn' then
    UpdateUI
  else if Args.PropertyName = 'Username' then
    if edtUsername.Text <> FViewModel.Username then
      edtUsername.Text := FViewModel.Username
  else if Args.PropertyName = 'Password' then
    if edtPassword.Text <> FViewModel.Password then
      edtPassword.Text := FViewModel.Password;
end;

procedure TfrmMain.HandlePropertyError(Sender: TObject; 
  const Args: TPropertyErrorEventArgs);
begin
  UpdateErrorLabels;
end;

procedure TfrmMain.UpdateUI;
begin
  // Show/hide panels based on login state
  pnlLogin.Visible := not FViewModel.IsLoggedIn;
  pnlSuccess.Visible := FViewModel.IsLoggedIn;
  
  if FViewModel.IsLoggedIn then
    lblWelcome.Caption := 'Welcome, ' + FViewModel.Username + '!';
  
  // Update message
  lblMessage.Caption := FViewModel.LoginMessage;
  
  // Update button states
  btnLogin.Enabled := FViewModel.LoginCommand.CanExecute(TValue.Empty);
end;

procedure TfrmMain.UpdateBusyState;
begin
  pnlBusy.Visible := FViewModel.IsBusy;
  lblBusy.Caption := FViewModel.BusyMessage;
  
  // Disable controls during busy state
  edtUsername.Enabled := not FViewModel.IsBusy;
  edtPassword.Enabled := not FViewModel.IsBusy;
  chkRememberMe.Enabled := not FViewModel.IsBusy;
  btnLogin.Enabled := not FViewModel.IsBusy;
  btnCancel.Enabled := FViewModel.IsBusy;
end;

procedure TfrmMain.UpdateErrorLabels;
var
  UsernameErrors, PasswordErrors: TValidationErrors;
begin
  // Update username error
  UsernameErrors := FViewModel.GetErrors('Username');
  if Length(UsernameErrors) > 0 then
  begin
    lblUsernameError.Caption := UsernameErrors[0].ErrorMessage;
    lblUsernameError.Visible := True;
  end
  else
    lblUsernameError.Visible := False;
  
  // Update password error
  PasswordErrors := FViewModel.GetErrors('Password');
  if Length(PasswordErrors) > 0 then
  begin
    lblPasswordError.Caption := PasswordErrors[0].ErrorMessage;
    lblPasswordError.Visible := True;
  end
  else
    lblPasswordError.Visible := False;
    
  // Update login button state
  btnLogin.Enabled := FViewModel.LoginCommand.CanExecute(TValue.Empty);
end;

procedure TfrmMain.edtUsernameChange(Sender: TObject);
begin
  FViewModel.Username := edtUsername.Text;
end;

procedure TfrmMain.edtPasswordChange(Sender: TObject);
begin
  FViewModel.Password := edtPassword.Text;
end;

procedure TfrmMain.chkRememberMeClick(Sender: TObject);
begin
  FViewModel.RememberMe := chkRememberMe.Checked;
end;

procedure TfrmMain.btnLoginClick(Sender: TObject);
begin
  // Execute login command
  FViewModel.LoginCommand.Execute(TValue.Empty);
end;

procedure TfrmMain.btnCancelClick(Sender: TObject);
begin
  // Execute cancel command
  FViewModel.CancelCommand.Execute(TValue.Empty);
end;

procedure TfrmMain.btnLogoutClick(Sender: TObject);
begin
  // Reset to login state
  FViewModel.IsLoggedIn := False;
  FViewModel.Username := '';
  FViewModel.Password := '';
  edtUsername.Text := '';
  edtPassword.Text := '';
  FViewModel.LoginMessage := 'Please enter your credentials';
  UpdateUI;
end;

end.
