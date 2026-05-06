{ ============================================================================
  LoginViewModel - MVVM Demo Login ViewModel
  
  Description: Demonstrates TViewModelBase, TRelayCommand, TAsyncCommand,
               and validation in a login form scenario.
  ============================================================================ }

unit LoginViewModel;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Threading,
  System.Rtti,
  System.Generics.Collections,
  UniBase.DataBinding,
  UniBase.MVVM,
  UniBase.Exceptions;

type
  /// <summary>
  /// Login form ViewModel with validation and async login command
  /// </summary>
  TLoginViewModel = class(TViewModelBase)
  private
    FUsername: string;
    FPassword: string;
    FRememberMe: Boolean;
    FIsLoggedIn: Boolean;
    FLoginMessage: string;
    
    FLoginCommand: ICommand;
    FCancelCommand: ICommand;
    
    procedure SetUsername(const Value: string);
    procedure SetPassword(const Value: string);
    procedure SetRememberMe(const Value: Boolean);
    procedure SetIsLoggedIn(const Value: Boolean);
    procedure SetLoginMessage(const Value: string);
    
    function CanLogin: Boolean;
    procedure DoLogin(IsCancelled: TFunc<Boolean>);
    procedure DoCancel;
  protected
    function DoValidate: TValidationErrors; override;
    function DoValidateProperty(const PropertyName: string): TValidationErrors; override;
    procedure OnActivate; override;
  public
    constructor Create; override;
    
    property Username: string read FUsername write SetUsername;
    property Password: string read FPassword write SetPassword;
    property RememberMe: Boolean read FRememberMe write SetRememberMe;
    property IsLoggedIn: Boolean read FIsLoggedIn write SetIsLoggedIn;
    property LoginMessage: string read FLoginMessage write SetLoginMessage;
    
    property LoginCommand: ICommand read FLoginCommand;
    property CancelCommand: ICommand read FCancelCommand;
  end;

implementation

uses
  System.Generics.Collections;

{ TLoginViewModel }

constructor TLoginViewModel.Create;
var
  AsyncCmd: TAsyncCommand;
begin
  inherited Create;
  
  FUsername := '';
  FPassword := '';
  FRememberMe := False;
  FIsLoggedIn := False;
  FLoginMessage := '';
  
  // Create async login command
  AsyncCmd := TAsyncCommand.Create(Self, DoLogin, CanLogin);
  AsyncCmd.OnCompleted := 
    procedure
    begin
      IsLoggedIn := True;
      LoginMessage := 'Login successful! Welcome, ' + FUsername + '!';
    end;
  AsyncCmd.OnError := 
    procedure(E: Exception)
    begin
      LoginMessage := 'Login failed: ' + E.Message;
    end;
  FLoginCommand := AsyncCmd;
  
  // Create cancel command
  FCancelCommand := TRelayCommand.Create(DoCancel);
end;

procedure TLoginViewModel.OnActivate;
begin
  inherited;
  // Reset state when form is shown
  IsLoggedIn := False;
  LoginMessage := 'Please enter your credentials';
end;

procedure TLoginViewModel.SetUsername(const Value: string);
begin
  if SetField<string>(FUsername, Value, 'Username') then
  begin
    ValidateProperty('Username');
    FLoginCommand.RaiseCanExecuteChanged;
  end;
end;

procedure TLoginViewModel.SetPassword(const Value: string);
begin
  if SetField<string>(FPassword, Value, 'Password') then
  begin
    ValidateProperty('Password');
    FLoginCommand.RaiseCanExecuteChanged;
  end;
end;

procedure TLoginViewModel.SetRememberMe(const Value: Boolean);
begin
  SetField<Boolean>(FRememberMe, Value, 'RememberMe');
end;

procedure TLoginViewModel.SetIsLoggedIn(const Value: Boolean);
begin
  SetField<Boolean>(FIsLoggedIn, Value, 'IsLoggedIn');
end;

procedure TLoginViewModel.SetLoginMessage(const Value: string);
begin
  SetField<string>(FLoginMessage, Value, 'LoginMessage');
end;

function TLoginViewModel.CanLogin: Boolean;
begin
  // Can only login if not busy and has valid input
  Result := not IsBusy and 
            (Trim(FUsername) <> '') and 
            (Length(FPassword) >= 6);
end;

procedure TLoginViewModel.DoLogin(IsCancelled: TFunc<Boolean>);
var
  i: Integer;
begin
  // Simulate async login (e.g., API call)
  TThread.Synchronize(nil,
    procedure
    begin
      LoginMessage := 'Connecting to server...';
    end);
  
  for i := 1 to 10 do
  begin
    if IsCancelled() then
    begin
      TThread.Synchronize(nil,
        procedure
        begin
          LoginMessage := 'Login cancelled';
        end);
      Exit;
    end;
    Sleep(200);
    
    // Update progress
    TThread.Synchronize(nil,
      procedure
      begin
        LoginMessage := Format('Authenticating... %d%%', [i * 10]);
      end);
  end;
  
  // Simulate validation
  if FUsername = 'admin' then
  begin
    if FPassword <> 'admin123' then
      raise EOperationException.Create('Invalid password for admin account');
  end
  else if FUsername = 'error' then
  begin
    raise EOperationException.Create('Simulated server error');
  end;
  
  // Success - OnCompleted will be called
end;

procedure TLoginViewModel.DoCancel;
begin
  if IsBusy then
  begin
    // Cancel the async command
    (FLoginCommand as TAsyncCommand).Cancel;
    LoginMessage := 'Login cancelled by user';
  end;
end;

function TLoginViewModel.DoValidate: TValidationErrors;
var
  Errors: TList<TValidationError>;
begin
  Errors := TList<TValidationError>.Create;
  try
    // Username validation
    if Trim(FUsername) = '' then
      Errors.Add(TValidationError.Create('Username', 'Username is required'))
    else if Length(FUsername) < 3 then
      Errors.Add(TValidationError.Create('Username', 'Username must be at least 3 characters'));
    
    // Password validation  
    if FPassword = '' then
      Errors.Add(TValidationError.Create('Password', 'Password is required'))
    else if Length(FPassword) < 6 then
      Errors.Add(TValidationError.Create('Password', 'Password must be at least 6 characters'));
    
    Result := Errors.ToArray;
  finally
    Errors.Free;
  end;
end;

function TLoginViewModel.DoValidateProperty(const PropertyName: string): TValidationErrors;
begin
  SetLength(Result, 0);
  
  if PropertyName = 'Username' then
  begin
    if Trim(FUsername) = '' then
    begin
      SetLength(Result, 1);
      Result[0] := TValidationError.Create('Username', 'Username is required');
    end
    else if Length(FUsername) < 3 then
    begin
      SetLength(Result, 1);
      Result[0] := TValidationError.Create('Username', 'Username must be at least 3 characters');
    end;
  end
  else if PropertyName = 'Password' then
  begin
    if FPassword = '' then
    begin
      SetLength(Result, 1);
      Result[0] := TValidationError.Create('Password', 'Password is required');
    end
    else if Length(FPassword) < 6 then
    begin
      SetLength(Result, 1);
      Result[0] := TValidationError.Create('Password', 'Password must be at least 6 characters');
    end;
  end;
end;

end.
