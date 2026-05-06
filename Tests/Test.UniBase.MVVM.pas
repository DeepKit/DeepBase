{ ============================================================================
  Test.UniBase.MVVM - MVVM Framework Unit Tests
  
  Description: Tests for TViewModelBase, TRelayCommand, TAsyncCommand,
               validation rules and related functionality.
  ============================================================================ }

unit Test.UniBase.MVVM;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.Rtti,
  System.Threading,
  System.Generics.Collections,
  UniBase.DataBinding,
  UniBase.MVVM;

type
  // ============================================================================
  // Test ViewModel for testing
  // ============================================================================
  
  TTestViewModel = class(TViewModelBase)
  private
    FName: string;
    FAge: Integer;
    FEmail: string;
    
    procedure SetName(const Value: string);
    procedure SetAge(const Value: Integer);
    procedure SetEmail(const Value: string);
  protected
    function DoValidate: TValidationErrors; override;
    function DoValidateProperty(const PropertyName: string): TValidationErrors; override;
  public
    property Name: string read FName write SetName;
    property Age: Integer read FAge write SetAge;
    property Email: string read FEmail write SetEmail;
  end;
  
  // ============================================================================
  // Test Fixtures
  // ============================================================================
  
  [TestFixture]
  TTestViewModelBase = class
  private
    FViewModel: TTestViewModel;
    FPropertyChangedCount: Integer;
    FLastChangedProperty: string;
    
    procedure HandlePropertyChanged(const Args: TPropertyChangedEventArgs);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_Create_DefaultValues;
    
    [Test]
    procedure Test_IsBusy_NotifiesPropertyChanged;
    
    [Test]
    procedure Test_BusyMessage_NotifiesPropertyChanged;
    
    [Test]
    procedure Test_ErrorMessage_NotifiesPropertyChanged;
    
    [Test]
    procedure Test_BeginBusy_SetsIsBusyAndMessage;
    
    [Test]
    procedure Test_EndBusy_ClearsIsBusyAndMessage;
    
    [Test]
    procedure Test_Activate_CallsOnActivate;
    
    [Test]
    procedure Test_Deactivate_CallsOnDeactivate;
    
    [Test]
    procedure Test_CustomProperty_NotifiesChange;
  end;
  
  [TestFixture]
  TTestValidation = class
  private
    FViewModel: TTestViewModel;
    FErrorCount: Integer;
    FLastErrorProperty: string;
    
    procedure HandlePropertyError(Sender: TObject; const Args: TPropertyErrorEventArgs);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_Validate_ReturnsErrors;
    
    [Test]
    procedure Test_ValidateProperty_ReturnsPropertyErrors;
    
    [Test]
    procedure Test_HasErrors_TrueWhenErrors;
    
    [Test]
    procedure Test_HasErrors_FalseWhenNoErrors;
    
    [Test]
    procedure Test_GetErrors_ReturnsPropertyErrors;
    
    [Test]
    procedure Test_ClearErrors_RemovesAllErrors;
    
    [Test]
    procedure Test_PropertyErrorHandler_CalledOnError;
  end;
  
  [TestFixture]
  TTestValidationRules = class
  public
    [Test]
    procedure Test_Required_FailsOnEmpty;
    
    [Test]
    procedure Test_Required_PassesOnNonEmpty;
    
    [Test]
    procedure Test_MinLength_FailsOnShort;
    
    [Test]
    procedure Test_MinLength_PassesOnLong;
    
    [Test]
    procedure Test_MaxLength_FailsOnLong;
    
    [Test]
    procedure Test_MaxLength_PassesOnShort;
    
    [Test]
    procedure Test_Email_FailsOnInvalid;
    
    [Test]
    procedure Test_Email_PassesOnValid;
    
    [Test]
    procedure Test_Email_PassesOnEmpty;
    
    [Test]
    procedure Test_Range_FailsOutOfRange;
    
    [Test]
    procedure Test_Range_PassesInRange;
  end;
  
  [TestFixture]
  TTestRelayCommand = class
  private
    FExecuteCount: Integer;
    FLastParameter: TValue;
    FCanExecuteResult: Boolean;
    FCanExecuteChangedCount: Integer;
    
    procedure HandleCanExecuteChanged(Sender: TObject);
  public
    [Setup]
    procedure Setup;
    
    [Test]
    procedure Test_Execute_CallsExecuteProc;
    
    [Test]
    procedure Test_Execute_WithParameter;
    
    [Test]
    procedure Test_CanExecute_ReturnsTrue_WhenNoFunc;
    
    [Test]
    procedure Test_CanExecute_ReturnsFuncResult;
    
    [Test]
    procedure Test_Execute_DoesNothing_WhenCanExecuteFalse;
    
    [Test]
    procedure Test_RaiseCanExecuteChanged_NotifiesHandlers;
  end;
  
  [TestFixture]
  TTestAsyncCommand = class
  private
    FViewModel: TTestViewModel;
    FExecuteCount: Integer;
    FCompletedCalled: Boolean;
    FErrorCalled: Boolean;
    FLastError: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_Execute_RunsInBackground;
    
    [Test]
    procedure Test_Execute_SetsViewModelBusy;
    
    [Test]
    procedure Test_State_TransitionsCorrectly;
    
    [Test]
    procedure Test_CanExecute_FalseWhileRunning;
    
    [Test]
    procedure Test_OnCompleted_CalledOnSuccess;
    
    [Test]
    procedure Test_OnError_CalledOnException;
    
    [Test]
    procedure Test_Cancel_StopsExecution;
  end;
  
  [TestFixture]
  TTestValidationError = class
  public
    [Test]
    procedure Test_Create_SetsFields;
    
    [Test]
    procedure Test_DefaultSeverity_IsError;
  end;

implementation

{ TTestViewModel }

procedure TTestViewModel.SetName(const Value: string);
begin
  SetField<string>(FName, Value, 'Name');
end;

procedure TTestViewModel.SetAge(const Value: Integer);
begin
  SetField<Integer>(FAge, Value, 'Age');
end;

procedure TTestViewModel.SetEmail(const Value: string);
begin
  SetField<string>(FEmail, Value, 'Email');
end;

function TTestViewModel.DoValidate: TValidationErrors;
var
  Errors: TList<TValidationError>;
begin
  Errors := TList<TValidationError>.Create;
  try
    // Name required
    if Trim(FName) = '' then
      Errors.Add(TValidationError.Create('Name', 'Name is required'));
    
    // Age range
    if (FAge < 0) or (FAge > 150) then
      Errors.Add(TValidationError.Create('Age', 'Age must be between 0 and 150'));
    
    // Email format (simple check)
    if (FEmail <> '') and (Pos('@', FEmail) = 0) then
      Errors.Add(TValidationError.Create('Email', 'Email format is invalid'));
    
    Result := Errors.ToArray;
  finally
    Errors.Free;
  end;
end;

function TTestViewModel.DoValidateProperty(const PropertyName: string): TValidationErrors;
begin
  SetLength(Result, 0);
  
  if PropertyName = 'Name' then
  begin
    if Trim(FName) = '' then
    begin
      SetLength(Result, 1);
      Result[0] := TValidationError.Create('Name', 'Name is required');
    end;
  end
  else if PropertyName = 'Age' then
  begin
    if (FAge < 0) or (FAge > 150) then
    begin
      SetLength(Result, 1);
      Result[0] := TValidationError.Create('Age', 'Age must be between 0 and 150');
    end;
  end
  else if PropertyName = 'Email' then
  begin
    if (FEmail <> '') and (Pos('@', FEmail) = 0) then
    begin
      SetLength(Result, 1);
      Result[0] := TValidationError.Create('Email', 'Email format is invalid');
    end;
  end;
end;

{ TTestViewModelBase }

procedure TTestViewModelBase.Setup;
begin
  FViewModel := TTestViewModel.Create;
  FPropertyChangedCount := 0;
  FLastChangedProperty := '';
  FViewModel.AddPropertyChangedHandler(HandlePropertyChanged);
end;

procedure TTestViewModelBase.TearDown;
begin
  FViewModel.Free;
end;

procedure TTestViewModelBase.HandlePropertyChanged(const Args: TPropertyChangedEventArgs);
begin
  Inc(FPropertyChangedCount);
  FLastChangedProperty := Args.PropertyName;
end;

procedure TTestViewModelBase.Test_Create_DefaultValues;
begin
  Assert.IsFalse(FViewModel.IsBusy, 'IsBusy should be False by default');
  Assert.AreEqual('', FViewModel.BusyMessage, 'BusyMessage should be empty');
  Assert.AreEqual('', FViewModel.ErrorMessage, 'ErrorMessage should be empty');
  Assert.IsFalse(FViewModel.IsActive, 'IsActive should be False by default');
end;

procedure TTestViewModelBase.Test_IsBusy_NotifiesPropertyChanged;
begin
  FViewModel.IsBusy := True;
  
  Assert.AreEqual('IsBusy', FLastChangedProperty);
  Assert.IsTrue(FViewModel.IsBusy);
end;

procedure TTestViewModelBase.Test_BusyMessage_NotifiesPropertyChanged;
begin
  FViewModel.BusyMessage := 'Loading...';
  
  Assert.AreEqual('BusyMessage', FLastChangedProperty);
  Assert.AreEqual('Loading...', FViewModel.BusyMessage);
end;

procedure TTestViewModelBase.Test_ErrorMessage_NotifiesPropertyChanged;
begin
  FViewModel.ErrorMessage := 'An error occurred';
  
  Assert.AreEqual('ErrorMessage', FLastChangedProperty);
  Assert.AreEqual('An error occurred', FViewModel.ErrorMessage);
end;

procedure TTestViewModelBase.Test_BeginBusy_SetsIsBusyAndMessage;
begin
  FViewModel.BeginBusy('Processing...');
  
  Assert.IsTrue(FViewModel.IsBusy);
  Assert.AreEqual('Processing...', FViewModel.BusyMessage);
end;

procedure TTestViewModelBase.Test_EndBusy_ClearsIsBusyAndMessage;
begin
  FViewModel.BeginBusy('Loading');
  FViewModel.EndBusy;
  
  Assert.IsFalse(FViewModel.IsBusy);
  Assert.AreEqual('', FViewModel.BusyMessage);
end;

procedure TTestViewModelBase.Test_Activate_CallsOnActivate;
begin
  FViewModel.Activate;
  
  Assert.IsTrue(FViewModel.IsActive);
  Assert.AreEqual('IsActive', FLastChangedProperty);
end;

procedure TTestViewModelBase.Test_Deactivate_CallsOnDeactivate;
begin
  FViewModel.Activate;
  FViewModel.Deactivate;
  
  Assert.IsFalse(FViewModel.IsActive);
end;

procedure TTestViewModelBase.Test_CustomProperty_NotifiesChange;
begin
  FViewModel.Name := 'Test';
  
  Assert.AreEqual('Name', FLastChangedProperty);
  Assert.AreEqual('Test', FViewModel.Name);
end;

{ TTestValidation }

procedure TTestValidation.Setup;
begin
  FViewModel := TTestViewModel.Create;
  FErrorCount := 0;
  FLastErrorProperty := '';
  FViewModel.AddPropertyErrorHandler(HandlePropertyError);
end;

procedure TTestValidation.TearDown;
begin
  FViewModel.Free;
end;

procedure TTestValidation.HandlePropertyError(Sender: TObject;
  const Args: TPropertyErrorEventArgs);
begin
  Inc(FErrorCount);
  FLastErrorProperty := Args.PropertyName;
end;

procedure TTestValidation.Test_Validate_ReturnsErrors;
var
  Errors: TValidationErrors;
begin
  FViewModel.Name := '';
  FViewModel.Age := 200;
  FViewModel.Email := 'invalid';
  
  Errors := FViewModel.Validate;
  
  Assert.AreEqual(3, Integer(Length(Errors)), 'Should have 3 errors');
end;

procedure TTestValidation.Test_ValidateProperty_ReturnsPropertyErrors;
var
  Errors: TValidationErrors;
begin
  FViewModel.Name := '';
  
  Errors := FViewModel.ValidateProperty('Name');
  
  Assert.AreEqual(1, Integer(Length(Errors)));
  Assert.AreEqual('Name', Errors[0].PropertyName);
end;

procedure TTestValidation.Test_HasErrors_TrueWhenErrors;
begin
  FViewModel.Name := '';
  FViewModel.Validate;
  
  Assert.IsTrue(FViewModel.HasErrors);
end;

procedure TTestValidation.Test_HasErrors_FalseWhenNoErrors;
begin
  FViewModel.Name := 'John';
  FViewModel.Age := 30;
  FViewModel.Email := 'john@example.com';
  FViewModel.Validate;
  
  Assert.IsFalse(FViewModel.HasErrors);
end;

procedure TTestValidation.Test_GetErrors_ReturnsPropertyErrors;
var
  Errors: TValidationErrors;
begin
  FViewModel.Name := '';
  FViewModel.ValidateProperty('Name');
  
  Errors := FViewModel.GetErrors('Name');
  
  Assert.AreEqual(1, Integer(Length(Errors)));
  Assert.AreEqual('Name is required', Errors[0].ErrorMessage);
end;

procedure TTestValidation.Test_ClearErrors_RemovesAllErrors;
begin
  FViewModel.Name := '';
  FViewModel.Age := 200;
  FViewModel.Validate;
  
  Assert.IsTrue(FViewModel.HasErrors);
  
  FViewModel.ClearErrors;
  
  Assert.IsFalse(FViewModel.HasErrors);
end;

procedure TTestValidation.Test_PropertyErrorHandler_CalledOnError;
begin
  FViewModel.Name := '';
  FViewModel.ValidateProperty('Name');
  
  Assert.IsTrue(FErrorCount > 0);
  Assert.AreEqual('Name', FLastErrorProperty);
end;

{ TTestValidationRules }

procedure TTestValidationRules.Test_Required_FailsOnEmpty;
var
  Rule: TValidationRule<string>;
begin
  Rule := TValidationRules.Required('Name');
  try
    Assert.IsFalse(Rule.IsValid(''));
    Assert.IsFalse(Rule.IsValid('   '));
  finally
    Rule.Free;
  end;
end;

procedure TTestValidationRules.Test_Required_PassesOnNonEmpty;
var
  Rule: TValidationRule<string>;
begin
  Rule := TValidationRules.Required('Name');
  try
    Assert.IsTrue(Rule.IsValid('John'));
    Assert.IsTrue(Rule.IsValid('  Test  '));
  finally
    Rule.Free;
  end;
end;

procedure TTestValidationRules.Test_MinLength_FailsOnShort;
var
  Rule: TValidationRule<string>;
begin
  Rule := TValidationRules.MinLength('Password', 6);
  try
    Assert.IsFalse(Rule.IsValid('abc'));
    Assert.IsFalse(Rule.IsValid('12345'));
  finally
    Rule.Free;
  end;
end;

procedure TTestValidationRules.Test_MinLength_PassesOnLong;
var
  Rule: TValidationRule<string>;
begin
  Rule := TValidationRules.MinLength('Password', 6);
  try
    Assert.IsTrue(Rule.IsValid('123456'));
    Assert.IsTrue(Rule.IsValid('password123'));
  finally
    Rule.Free;
  end;
end;

procedure TTestValidationRules.Test_MaxLength_FailsOnLong;
var
  Rule: TValidationRule<string>;
begin
  Rule := TValidationRules.MaxLength('Username', 10);
  try
    Assert.IsFalse(Rule.IsValid('verylongusername'));
  finally
    Rule.Free;
  end;
end;

procedure TTestValidationRules.Test_MaxLength_PassesOnShort;
var
  Rule: TValidationRule<string>;
begin
  Rule := TValidationRules.MaxLength('Username', 10);
  try
    Assert.IsTrue(Rule.IsValid('john'));
    Assert.IsTrue(Rule.IsValid('0123456789'));
  finally
    Rule.Free;
  end;
end;

procedure TTestValidationRules.Test_Email_FailsOnInvalid;
var
  Rule: TValidationRule<string>;
begin
  Rule := TValidationRules.Email('Email');
  try
    Assert.IsFalse(Rule.IsValid('invalid'));
    Assert.IsFalse(Rule.IsValid('test@'));
    Assert.IsFalse(Rule.IsValid('@domain.com'));
  finally
    Rule.Free;
  end;
end;

procedure TTestValidationRules.Test_Email_PassesOnValid;
var
  Rule: TValidationRule<string>;
begin
  Rule := TValidationRules.Email('Email');
  try
    Assert.IsTrue(Rule.IsValid('test@example.com'));
    Assert.IsTrue(Rule.IsValid('user.name@domain.org'));
  finally
    Rule.Free;
  end;
end;

procedure TTestValidationRules.Test_Email_PassesOnEmpty;
var
  Rule: TValidationRule<string>;
begin
  Rule := TValidationRules.Email('Email');
  try
    Assert.IsTrue(Rule.IsValid(''), 'Empty email should be valid (use Required for mandatory)');
  finally
    Rule.Free;
  end;
end;

procedure TTestValidationRules.Test_Range_FailsOutOfRange;
var
  Rule: TValidationRule<Integer>;
begin
  Rule := TValidationRules.Range('Age', 0, 150);
  try
    Assert.IsFalse(Rule.IsValid(-1));
    Assert.IsFalse(Rule.IsValid(151));
  finally
    Rule.Free;
  end;
end;

procedure TTestValidationRules.Test_Range_PassesInRange;
var
  Rule: TValidationRule<Integer>;
begin
  Rule := TValidationRules.Range('Age', 0, 150);
  try
    Assert.IsTrue(Rule.IsValid(0));
    Assert.IsTrue(Rule.IsValid(75));
    Assert.IsTrue(Rule.IsValid(150));
  finally
    Rule.Free;
  end;
end;

{ TTestRelayCommand }

procedure TTestRelayCommand.Setup;
begin
  FExecuteCount := 0;
  FLastParameter := TValue.Empty;
  FCanExecuteResult := True;
  FCanExecuteChangedCount := 0;
end;

procedure TTestRelayCommand.HandleCanExecuteChanged(Sender: TObject);
begin
  Inc(FCanExecuteChangedCount);
end;

procedure TTestRelayCommand.Test_Execute_CallsExecuteProc;
var
  Command: ICommand;
begin
  Command := TRelayCommand.Create(
    TExecuteProc(procedure
    begin
      Inc(FExecuteCount);
    end));

  Command.Execute(TValue.Empty);

  Assert.AreEqual(1, FExecuteCount);
end;

procedure TTestRelayCommand.Test_Execute_WithParameter;
var
  Command: ICommand;
begin
  Command := TRelayCommand.Create(
    TExecuteProcParam(procedure(const Parameter: TValue)
    begin
      Inc(FExecuteCount);
      FLastParameter := Parameter;
    end));
  
  Command.Execute(TValue.From<Integer>(42));
  
  Assert.AreEqual(1, FExecuteCount);
  Assert.AreEqual(42, FLastParameter.AsInteger);
end;

procedure TTestRelayCommand.Test_CanExecute_ReturnsTrue_WhenNoFunc;
var
  Command: ICommand;
begin
  Command := TRelayCommand.Create(
    TExecuteProc(procedure
    begin
      // do nothing
    end));

  Assert.IsTrue(Command.CanExecute(TValue.Empty));
end;

procedure TTestRelayCommand.Test_CanExecute_ReturnsFuncResult;
var
  Command: ICommand;
begin
  FCanExecuteResult := False;

  Command := TRelayCommand.Create(
    TExecuteProc(procedure
    begin
      Inc(FExecuteCount);
    end),
    TCanExecuteFunc(function: Boolean
    begin
      Result := FCanExecuteResult;
    end));
  
  Assert.IsFalse(Command.CanExecute(TValue.Empty));
  
  FCanExecuteResult := True;
  Assert.IsTrue(Command.CanExecute(TValue.Empty));
end;

procedure TTestRelayCommand.Test_Execute_DoesNothing_WhenCanExecuteFalse;
var
  Command: ICommand;
begin
  Command := TRelayCommand.Create(
    TExecuteProc(procedure
    begin
      Inc(FExecuteCount);
    end),
    TCanExecuteFunc(function: Boolean
    begin
      Result := False;
    end));
  
  Command.Execute(TValue.Empty);
  
  Assert.AreEqual(0, FExecuteCount, 'Execute should not run when CanExecute is False');
end;

procedure TTestRelayCommand.Test_RaiseCanExecuteChanged_NotifiesHandlers;
var
  Command: ICommand;
begin
  Command := TRelayCommand.Create(
    TExecuteProc(procedure
    begin
      // do nothing
    end));

  Command.AddCanExecuteChangedHandler(HandleCanExecuteChanged);
  Command.RaiseCanExecuteChanged;
  
  Assert.AreEqual(1, FCanExecuteChangedCount);
end;

{ TTestAsyncCommand }

procedure TTestAsyncCommand.Setup;
begin
  FViewModel := TTestViewModel.Create;
  FExecuteCount := 0;
  FCompletedCalled := False;
  FErrorCalled := False;
  FLastError := '';
end;

procedure TTestAsyncCommand.TearDown;
begin
  FViewModel.Free;
end;

procedure TTestAsyncCommand.Test_Execute_RunsInBackground;
var
  Command: TAsyncCommand;
begin
  Command := TAsyncCommand.Create(FViewModel,
    TAsyncExecuteProc(procedure(IsCancelled: TFunc<Boolean>)
    begin
      Inc(FExecuteCount);
      Sleep(50);
    end));
  try
    Command.Execute(TValue.Empty);
    Command.Wait(2000);
    
    Assert.AreEqual(1, FExecuteCount);
  finally
    Command.Free;
  end;
end;

procedure TTestAsyncCommand.Test_Execute_SetsViewModelBusy;
var
  Command: TAsyncCommand;
  WasBusy: Boolean;
begin
  WasBusy := False;
  
  Command := TAsyncCommand.Create(FViewModel,
    TAsyncExecuteProc(procedure(IsCancelled: TFunc<Boolean>)
    begin
      WasBusy := FViewModel.IsBusy;
      Sleep(50);
    end));
  try
    Command.Execute(TValue.Empty);
    Command.Wait(2000);
    
    Assert.IsTrue(WasBusy, 'ViewModel should be busy during execution');
    Assert.IsFalse(FViewModel.IsBusy, 'ViewModel should not be busy after completion');
  finally
    Command.Free;
  end;
end;

procedure TTestAsyncCommand.Test_State_TransitionsCorrectly;
var
  Command: TAsyncCommand;
begin
  Command := TAsyncCommand.Create(FViewModel,
    TAsyncExecuteProc(procedure(IsCancelled: TFunc<Boolean>)
    begin
      Sleep(100);
    end));
  try
    Assert.AreEqual(Ord(acsIdle), Ord(Command.State), 'Initial state should be Idle');
    
    Command.Execute(TValue.Empty);
    
    // State should be Running immediately after execute
    Assert.AreEqual(Ord(acsRunning), Ord(Command.State), 'State should be Running');
    
    Command.Wait(2000);
    
    Assert.AreEqual(Ord(acsCompleted), Ord(Command.State), 'Final state should be Completed');
  finally
    Command.Free;
  end;
end;

procedure TTestAsyncCommand.Test_CanExecute_FalseWhileRunning;
var
  Command: TAsyncCommand;
  CanExecuteDuringRun: Boolean;
begin
  CanExecuteDuringRun := True;
  
  Command := TAsyncCommand.Create(FViewModel,
    TAsyncExecuteProc(procedure(IsCancelled: TFunc<Boolean>)
    begin
      Sleep(100);
    end));
  try
    Assert.IsTrue(Command.CanExecute(TValue.Empty), 'Should be able to execute when idle');
    
    Command.Execute(TValue.Empty);
    CanExecuteDuringRun := Command.CanExecute(TValue.Empty);
    Command.Wait(2000);
    
    Assert.IsFalse(CanExecuteDuringRun, 'CanExecute should be False while running');
  finally
    Command.Free;
  end;
end;

procedure TTestAsyncCommand.Test_OnCompleted_CalledOnSuccess;
var
  Command: TAsyncCommand;
begin
  Command := TAsyncCommand.Create(FViewModel,
    TAsyncExecuteProc(procedure(IsCancelled: TFunc<Boolean>)
    begin
      Sleep(50);
    end));
  try
    Command.OnCompleted := 
      procedure
      begin
        FCompletedCalled := True;
      end;
    
    Command.Execute(TValue.Empty);
    Command.Wait(2000);
    
    // Give a moment for synchronized callback
    Sleep(100);
    
    Assert.IsTrue(FCompletedCalled, 'OnCompleted should be called');
  finally
    Command.Free;
  end;
end;

procedure TTestAsyncCommand.Test_OnError_CalledOnException;
var
  Command: TAsyncCommand;
begin
  Command := TAsyncCommand.Create(FViewModel,
    TAsyncExecuteProc(procedure(IsCancelled: TFunc<Boolean>)
    begin
      raise Exception.Create('Test error');
    end));
  try
    Command.OnError := 
      procedure(E: Exception)
      begin
        FErrorCalled := True;
        FLastError := E.Message;
      end;
    
    Command.Execute(TValue.Empty);
    Command.Wait(2000);
    
    // Give a moment for synchronized callback
    Sleep(100);
    
    Assert.IsTrue(FErrorCalled, 'OnError should be called');
    Assert.AreEqual('Test error', FLastError);
    Assert.AreEqual(Ord(acsFailed), Ord(Command.State));
  finally
    Command.Free;
  end;
end;

procedure TTestAsyncCommand.Test_Cancel_StopsExecution;
var
  Command: TAsyncCommand;
  WasCancelled: Boolean;
begin
  WasCancelled := False;
  
  Command := TAsyncCommand.Create(FViewModel,
    TAsyncExecuteProc(procedure(IsCancelled: TFunc<Boolean>)
    begin
      var i: Integer;
      for i := 1 to 100 do
      begin
        if IsCancelled() then
        begin
          WasCancelled := True;
          Exit;
        end;
        Sleep(10);
      end;
    end));
  try
    Command.Execute(TValue.Empty);
    Sleep(50);
    Command.Cancel;
    Command.Wait(2000);
    
    Assert.IsTrue(WasCancelled or (Command.State = acsCancelled), 
      'Command should have been cancelled');
  finally
    Command.Free;
  end;
end;

{ TTestValidationError }

procedure TTestValidationError.Test_Create_SetsFields;
var
  Error: TValidationError;
begin
  Error := TValidationError.Create('Name', 'Name is required', vsWarning);
  
  Assert.AreEqual('Name', Error.PropertyName);
  Assert.AreEqual('Name is required', Error.ErrorMessage);
  Assert.AreEqual(Ord(vsWarning), Ord(Error.Severity));
end;

procedure TTestValidationError.Test_DefaultSeverity_IsError;
var
  Error: TValidationError;
begin
  Error := TValidationError.Create('Test', 'Test error');
  
  Assert.AreEqual(Ord(vsError), Ord(Error.Severity));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestViewModelBase);
  TDUnitX.RegisterTestFixture(TTestValidation);
  TDUnitX.RegisterTestFixture(TTestValidationRules);
  TDUnitX.RegisterTestFixture(TTestRelayCommand);
  TDUnitX.RegisterTestFixture(TTestAsyncCommand);
  TDUnitX.RegisterTestFixture(TTestValidationError);

end.
