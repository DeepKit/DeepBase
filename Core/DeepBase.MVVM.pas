{ ============================================================================
  DeepBase.MVVM - Model-View-ViewModel Framework
  
  Version: 0.3
  Description: Provides MVVM infrastructure building on DeepBase.DataBinding.
               Includes ViewModel base class, Command pattern, and validation.
  
  Thread Safety: TAsyncCommand uses ITask for background execution.
                 Other classes should be used from the main thread only.
  
  Usage:
    TLoginViewModel = class(TViewModelBase)
    private
      FUsername: string;
      FLoginCommand: ICommand;
    public
      property Username: string read FUsername write SetUsername;
      property LoginCommand: ICommand read FLoginCommand;
    end;
  ============================================================================ }

unit DeepBase.MVVM;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
  System.Threading,
  System.Generics.Collections,
  DeepBase.DataBinding;

type
  // Forward declarations
  TViewModelBase = class;
  TRelayCommand = class;
  TAsyncCommand = class;
  
  // ============================================================================
  // Validation Types
  // ============================================================================
  
  /// <summary>
  /// Validation error severity
  /// </summary>
  TValidationSeverity = (vsError, vsWarning, vsInfo);
  
  /// <summary>
  /// Validation error record
  /// </summary>
  TValidationError = record
    PropertyName: string;
    ErrorMessage: string;
    Severity: TValidationSeverity;
    
    class function Create(const AProp, AMsg: string; 
      ASeverity: TValidationSeverity = vsError): TValidationError; static;
  end;
  TValidationErrors = TArray<TValidationError>;
  
  /// <summary>
  /// Interface for validatable objects
  /// </summary>
  IValidatable = interface
    ['{B2C3D4E5-F6A7-4B8C-9D0E-1F2A3B4C5D6E}']
    function Validate: TValidationErrors;
    function ValidateProperty(const PropertyName: string): TValidationErrors;
    function HasErrors: Boolean;
    function GetErrors(const PropertyName: string): TValidationErrors;
  end;
  
  // ============================================================================
  // Command Types
  // ============================================================================
  
  /// <summary>
  /// Command execute procedure (no parameter)
  /// </summary>
  TExecuteProc = reference to procedure;
  
  /// <summary>
  /// Command execute procedure with parameter
  /// </summary>
  TExecuteProcParam = reference to procedure(const Parameter: TValue);
  
  /// <summary>
  /// CanExecute function (no parameter)
  /// </summary>
  TCanExecuteFunc = reference to function: Boolean;
  
  /// <summary>
  /// CanExecute function with parameter
  /// </summary>
  TCanExecuteFuncParam = reference to function(const Parameter: TValue): Boolean;
  
  /// <summary>
  /// Async execute procedure with cancellation check function
  /// </summary>
  TAsyncExecuteProc = reference to procedure(IsCancelled: TFunc<Boolean>);
  
  /// <summary>
  /// Async execute procedure with parameter and cancellation check
  /// </summary>
  TAsyncExecuteProcParam = reference to procedure(const Parameter: TValue; 
    IsCancelled: TFunc<Boolean>);
  
  /// <summary>
  /// CanExecuteChanged event handler
  /// </summary>
  TCanExecuteChangedEvent = procedure(Sender: TObject) of object;
  
  /// <summary>
  /// Command interface
  /// </summary>
  ICommand = interface
    ['{C3D4E5F6-A7B8-4C9D-0E1F-2A3B4C5D6E7F}']
    procedure Execute(const Parameter: TValue);
    function CanExecute(const Parameter: TValue): Boolean;
    procedure AddCanExecuteChangedHandler(Handler: TCanExecuteChangedEvent);
    procedure RemoveCanExecuteChangedHandler(Handler: TCanExecuteChangedEvent);
    procedure RaiseCanExecuteChanged;
  end;
  
  /// <summary>
  /// Relay command - synchronous command implementation
  /// </summary>
  TRelayCommand = class(TInterfacedObject, ICommand)
  private
    FExecuteProc: TExecuteProc;
    FExecuteProcParam: TExecuteProcParam;
    FCanExecuteFunc: TCanExecuteFunc;
    FCanExecuteFuncParam: TCanExecuteFuncParam;
    FCanExecuteChangedHandlers: TList<TCanExecuteChangedEvent>;
    FHasParameter: Boolean;
  public
    /// <summary>Create command without parameter</summary>
    constructor Create(AExecute: TExecuteProc; ACanExecute: TCanExecuteFunc = nil); overload;
    /// <summary>Create command with parameter</summary>
    constructor Create(AExecute: TExecuteProcParam; ACanExecute: TCanExecuteFuncParam = nil); overload;
    destructor Destroy; override;
    
    // ICommand
    procedure Execute(const Parameter: TValue);
    function CanExecute(const Parameter: TValue): Boolean;
    procedure AddCanExecuteChangedHandler(Handler: TCanExecuteChangedEvent);
    procedure RemoveCanExecuteChangedHandler(Handler: TCanExecuteChangedEvent);
    procedure RaiseCanExecuteChanged;
  end;
  
  /// <summary>
  /// Async command state
  /// </summary>
  TAsyncCommandState = (acsIdle, acsRunning, acsCancelling, acsCancelled, acsCompleted, acsFailed);
  
  /// <summary>
  /// Async command - runs in background thread
  /// </summary>
  TAsyncCommand = class(TInterfacedObject, ICommand)
  private
    FExecuteProc: TAsyncExecuteProc;
    FExecuteProcParam: TAsyncExecuteProcParam;
    FCanExecuteFunc: TCanExecuteFunc;
    FCanExecuteFuncParam: TCanExecuteFuncParam;
    FCanExecuteChangedHandlers: TList<TCanExecuteChangedEvent>;
    FHasParameter: Boolean;
    FState: TAsyncCommandState;
    FTask: ITask;
    FCancelled: Boolean;
    FViewModel: TViewModelBase;
    FOnCompleted: TProc;
    FOnError: TProc<Exception>;
    FLastError: string;
    
    procedure DoExecute(const Parameter: TValue);
    procedure SetState(Value: TAsyncCommandState);
    function GetIsCancelled: Boolean;
    function GetIsRunning: Boolean;
  public
    /// <summary>Create async command without parameter</summary>
    constructor Create(AViewModel: TViewModelBase; AExecute: TAsyncExecuteProc; 
      ACanExecute: TCanExecuteFunc = nil); overload;
    /// <summary>Create async command with parameter</summary>
    constructor Create(AViewModel: TViewModelBase; AExecute: TAsyncExecuteProcParam; 
      ACanExecute: TCanExecuteFuncParam = nil); overload;
    destructor Destroy; override;
    
    // ICommand
    procedure Execute(const Parameter: TValue);
    function CanExecute(const Parameter: TValue): Boolean;
    procedure AddCanExecuteChangedHandler(Handler: TCanExecuteChangedEvent);
    procedure RemoveCanExecuteChangedHandler(Handler: TCanExecuteChangedEvent);
    procedure RaiseCanExecuteChanged;
    
    /// <summary>Cancel the running command</summary>
    procedure Cancel;
    
    /// <summary>Wait for completion (blocking)</summary>
    procedure Wait(Timeout: Cardinal = INFINITE);
    
    property State: TAsyncCommandState read FState;
    property IsRunning: Boolean read GetIsRunning;
    property IsCancelled: Boolean read GetIsCancelled;
    property LastError: string read FLastError;
    property OnCompleted: TProc read FOnCompleted write FOnCompleted;
    property OnError: TProc<Exception> read FOnError write FOnError;
  end;
  
  // ============================================================================
  // ViewModel Types
  // ============================================================================
  
  /// <summary>
  /// Property error event args
  /// </summary>
  TPropertyErrorEventArgs = record
    PropertyName: string;
    Errors: TValidationErrors;
  end;
  
  /// <summary>
  /// Property error event handler
  /// </summary>
  TPropertyErrorEvent = procedure(Sender: TObject; const Args: TPropertyErrorEventArgs) of object;
  
  /// <summary>
  /// Base class for all ViewModels
  /// </summary>
  TViewModelBase = class(TObservableObject, IValidatable)
  private
    FIsBusy: Boolean;
    FBusyMessage: string;
    FErrorMessage: string;
    FValidationErrors: TDictionary<string, TValidationErrors>;
    FPropertyErrorHandlers: TList<TPropertyErrorEvent>;
    FIsActive: Boolean;
    
    procedure SetIsBusy(const Value: Boolean);
    procedure SetBusyMessage(const Value: string);
    procedure SetErrorMessage(const Value: string);
    function GetHasErrors: Boolean;
  protected
    /// <summary>Called when ViewModel is activated (e.g., form shown)</summary>
    procedure OnActivate; virtual;
    /// <summary>Called when ViewModel is deactivated (e.g., form hidden)</summary>
    procedure OnDeactivate; virtual;
    
    /// <summary>Override to provide validation logic</summary>
    function DoValidate: TValidationErrors; virtual;
    /// <summary>Override to provide property-specific validation</summary>
    function DoValidateProperty(const PropertyName: string): TValidationErrors; virtual;
    
    /// <summary>Add validation error for a property</summary>
    procedure AddError(const PropertyName, ErrorMessage: string; 
      Severity: TValidationSeverity = vsError);
    /// <summary>Clear errors for a property</summary>
    procedure ClearErrors(const PropertyName: string = '');
    /// <summary>Notify property error change</summary>
    procedure NotifyPropertyError(const PropertyName: string);
    
    /// <summary>Set busy state with message</summary>
    procedure BeginBusy(const Message: string = '');
    /// <summary>Clear busy state</summary>
    procedure EndBusy;
  public
    constructor Create; override;
    destructor Destroy; override;
    
    /// <summary>Activate the ViewModel</summary>
    procedure Activate;
    /// <summary>Deactivate the ViewModel</summary>
    procedure Deactivate;
    
    // IValidatable
    function Validate: TValidationErrors;
    function ValidateProperty(const PropertyName: string): TValidationErrors;
    function HasErrors: Boolean;
    function GetErrors(const PropertyName: string): TValidationErrors;
    
    /// <summary>Add property error event handler</summary>
    procedure AddPropertyErrorHandler(Handler: TPropertyErrorEvent);
    /// <summary>Remove property error event handler</summary>
    procedure RemovePropertyErrorHandler(Handler: TPropertyErrorEvent);
    
    /// <summary>Indicates async operation in progress</summary>
    property IsBusy: Boolean read FIsBusy write SetIsBusy;
    /// <summary>Message to display during busy state</summary>
    property BusyMessage: string read FBusyMessage write SetBusyMessage;
    /// <summary>Last error message</summary>
    property ErrorMessage: string read FErrorMessage write SetErrorMessage;
    /// <summary>Whether ViewModel is active</summary>
    property IsActive: Boolean read FIsActive;
  end;
  
  // ============================================================================
  // Validation Rules
  // ============================================================================
  
  /// <summary>
  /// Generic validation rule
  /// </summary>
  TValidationRule<T> = class
  private
    FPropertyName: string;
    FErrorMessage: string;
    FValidateFunc: TFunc<T, Boolean>;
  public
    constructor Create(const APropertyName, AErrorMessage: string; 
      AValidateFunc: TFunc<T, Boolean>);
    function Validate(const Value: T): TValidationError;
    function IsValid(const Value: T): Boolean;
    
    property PropertyName: string read FPropertyName;
    property ErrorMessage: string read FErrorMessage;
  end;
  
  /// <summary>
  /// Common validation rules factory
  /// </summary>
  TValidationRules = class
  public
    /// <summary>Value is required (not empty string)</summary>
    class function Required(const PropertyName: string; 
      const ErrorMessage: string = ''): TValidationRule<string>;
    /// <summary>String minimum length</summary>
    class function MinLength(const PropertyName: string; MinLen: Integer; 
      const ErrorMessage: string = ''): TValidationRule<string>;
    /// <summary>String maximum length</summary>
    class function MaxLength(const PropertyName: string; MaxLen: Integer; 
      const ErrorMessage: string = ''): TValidationRule<string>;
    /// <summary>String matches regex pattern</summary>
    class function Pattern(const PropertyName, APattern: string; 
      const ErrorMessage: string = ''): TValidationRule<string>;
    /// <summary>Email format validation</summary>
    class function Email(const PropertyName: string; 
      const ErrorMessage: string = ''): TValidationRule<string>;
    /// <summary>Integer range validation</summary>
    class function Range(const PropertyName: string; MinVal, MaxVal: Integer; 
      const ErrorMessage: string = ''): TValidationRule<Integer>;
  end;

// ============================================================================
// Helper Functions
// ============================================================================

/// <summary>Convert async command state to string</summary>
function AsyncCommandStateToStr(State: TAsyncCommandState): string;

/// <summary>Convert validation severity to string</summary>
function ValidationSeverityToStr(Severity: TValidationSeverity): string;

implementation

uses
  System.RegularExpressions;

{ Helper Functions }

function AsyncCommandStateToStr(State: TAsyncCommandState): string;
begin
  case State of
    acsIdle:       Result := 'Idle';
    acsRunning:    Result := 'Running';
    acsCancelling: Result := 'Cancelling';
    acsCancelled:  Result := 'Cancelled';
    acsCompleted:  Result := 'Completed';
    acsFailed:     Result := 'Failed';
  else
    Result := 'Unknown';
  end;
end;

function ValidationSeverityToStr(Severity: TValidationSeverity): string;
begin
  case Severity of
    vsError:   Result := 'Error';
    vsWarning: Result := 'Warning';
    vsInfo:    Result := 'Info';
  else
    Result := 'Unknown';
  end;
end;

{ TValidationError }

class function TValidationError.Create(const AProp, AMsg: string;
  ASeverity: TValidationSeverity): TValidationError;
begin
  Result.PropertyName := AProp;
  Result.ErrorMessage := AMsg;
  Result.Severity := ASeverity;
end;

{ TRelayCommand }

constructor TRelayCommand.Create(AExecute: TExecuteProc; ACanExecute: TCanExecuteFunc);
begin
  inherited Create;
  FExecuteProc := AExecute;
  FCanExecuteFunc := ACanExecute;
  FHasParameter := False;
  FCanExecuteChangedHandlers := TList<TCanExecuteChangedEvent>.Create;
end;

constructor TRelayCommand.Create(AExecute: TExecuteProcParam; 
  ACanExecute: TCanExecuteFuncParam);
begin
  inherited Create;
  FExecuteProcParam := AExecute;
  FCanExecuteFuncParam := ACanExecute;
  FHasParameter := True;
  FCanExecuteChangedHandlers := TList<TCanExecuteChangedEvent>.Create;
end;

destructor TRelayCommand.Destroy;
begin
  FreeAndNil(FCanExecuteChangedHandlers);
  inherited;
end;

procedure TRelayCommand.Execute(const Parameter: TValue);
begin
  if not CanExecute(Parameter) then
    Exit;
    
  if FHasParameter then
  begin
    if Assigned(FExecuteProcParam) then
      FExecuteProcParam(Parameter);
  end
  else
  begin
    if Assigned(FExecuteProc) then
      FExecuteProc;
  end;
end;

function TRelayCommand.CanExecute(const Parameter: TValue): Boolean;
begin
  if FHasParameter then
  begin
    if Assigned(FCanExecuteFuncParam) then
      Result := FCanExecuteFuncParam(Parameter)
    else
      Result := True;
  end
  else
  begin
    if Assigned(FCanExecuteFunc) then
      Result := FCanExecuteFunc
    else
      Result := True;
  end;
end;

procedure TRelayCommand.AddCanExecuteChangedHandler(Handler: TCanExecuteChangedEvent);
begin
  if not FCanExecuteChangedHandlers.Contains(Handler) then
    FCanExecuteChangedHandlers.Add(Handler);
end;

procedure TRelayCommand.RemoveCanExecuteChangedHandler(Handler: TCanExecuteChangedEvent);
begin
  FCanExecuteChangedHandlers.Remove(Handler);
end;

procedure TRelayCommand.RaiseCanExecuteChanged;
var
  Handler: TCanExecuteChangedEvent;
begin
  for Handler in FCanExecuteChangedHandlers do
    Handler(Self);
end;

{ TAsyncCommand }

constructor TAsyncCommand.Create(AViewModel: TViewModelBase; 
  AExecute: TAsyncExecuteProc; ACanExecute: TCanExecuteFunc);
begin
  inherited Create;
  FViewModel := AViewModel;
  FExecuteProc := AExecute;
  FCanExecuteFunc := ACanExecute;
  FHasParameter := False;
  FState := acsIdle;
  FCancelled := False;
  FCanExecuteChangedHandlers := TList<TCanExecuteChangedEvent>.Create;
end;

constructor TAsyncCommand.Create(AViewModel: TViewModelBase;
  AExecute: TAsyncExecuteProcParam; ACanExecute: TCanExecuteFuncParam);
begin
  inherited Create;
  FViewModel := AViewModel;
  FExecuteProcParam := AExecute;
  FCanExecuteFuncParam := ACanExecute;
  FHasParameter := True;
  FState := acsIdle;
  FCancelled := False;
  FCanExecuteChangedHandlers := TList<TCanExecuteChangedEvent>.Create;
end;

destructor TAsyncCommand.Destroy;
begin
  Cancel;
  if FTask <> nil then
    Wait;
  FreeAndNil(FCanExecuteChangedHandlers);
  inherited;
end;

procedure TAsyncCommand.SetState(Value: TAsyncCommandState);
begin
  if FState <> Value then
  begin
    FState := Value;
    RaiseCanExecuteChanged;
  end;
end;

function TAsyncCommand.GetIsCancelled: Boolean;
begin
  Result := FCancelled;
end;

function TAsyncCommand.GetIsRunning: Boolean;
begin
  Result := FState = acsRunning;
end;

procedure TAsyncCommand.Execute(const Parameter: TValue);
begin
  if not CanExecute(Parameter) then
    Exit;
    
  DoExecute(Parameter);
end;

procedure TAsyncCommand.DoExecute(const Parameter: TValue);
var
  SelfRef: TAsyncCommand;
  IsCancelledFunc: TFunc<Boolean>;
begin
  SetState(acsRunning);
  FLastError := '';
  FCancelled := False;
  
  // Set ViewModel busy
  if FViewModel <> nil then
    FViewModel.BeginBusy;
  
  // Create cancellation check function
  SelfRef := Self;
  IsCancelledFunc := function: Boolean
    begin
      Result := SelfRef.FCancelled;
    end;
  
  // Create and start task
  FTask := TTask.Create(
    procedure
    begin
      try
        try
          if FHasParameter then
          begin
            if Assigned(FExecuteProcParam) then
              FExecuteProcParam(Parameter, IsCancelledFunc);
          end
          else
          begin
            if Assigned(FExecuteProc) then
              FExecuteProc(IsCancelledFunc);
          end;

          // Check if cancelled
          if FCancelled then
          begin
            TThread.Synchronize(nil,
              procedure
              begin
                SelfRef.SetState(acsCancelled);
                if SelfRef.FViewModel <> nil then
                  SelfRef.FViewModel.EndBusy;
              end);
          end
          else
          begin
            TThread.Synchronize(nil,
              procedure
              begin
                SelfRef.SetState(acsCompleted);
                if SelfRef.FViewModel <> nil then
                  SelfRef.FViewModel.EndBusy;
                if Assigned(SelfRef.FOnCompleted) then
                  SelfRef.FOnCompleted();
              end);
          end;
        except
          on E: Exception do
          begin
            var ErrorMessage := E.Message;
            SelfRef.FLastError := ErrorMessage;
            TThread.Synchronize(nil,
              procedure
              var
                CallbackError: Exception;
              begin
                SelfRef.SetState(acsFailed);
                if SelfRef.FViewModel <> nil then
                begin
                  SelfRef.FViewModel.EndBusy;
                  SelfRef.FViewModel.ErrorMessage := SelfRef.FLastError;
                end;
                if Assigned(SelfRef.FOnError) then
                begin
                  CallbackError := Exception.Create(ErrorMessage);
                  try
                    SelfRef.FOnError(CallbackError);
                  finally
                    CallbackError.Free;
                  end;
                end;
              end);
          end;
        end;
      finally
        // Break the anonymous-method self-cycle in DoExecute's captured state.
        IsCancelledFunc := nil;
      end;
    end);
  
  FTask.Start;
end;

function TAsyncCommand.CanExecute(const Parameter: TValue): Boolean;
begin
  // Cannot execute while running
  if FState = acsRunning then
  begin
    Result := False;
    Exit;
  end;
  
  if FHasParameter then
  begin
    if Assigned(FCanExecuteFuncParam) then
      Result := FCanExecuteFuncParam(Parameter)
    else
      Result := True;
  end
  else
  begin
    if Assigned(FCanExecuteFunc) then
      Result := FCanExecuteFunc
    else
      Result := True;
  end;
end;

procedure TAsyncCommand.AddCanExecuteChangedHandler(Handler: TCanExecuteChangedEvent);
begin
  if not FCanExecuteChangedHandlers.Contains(Handler) then
    FCanExecuteChangedHandlers.Add(Handler);
end;

procedure TAsyncCommand.RemoveCanExecuteChangedHandler(Handler: TCanExecuteChangedEvent);
begin
  FCanExecuteChangedHandlers.Remove(Handler);
end;

procedure TAsyncCommand.RaiseCanExecuteChanged;
var
  Handler: TCanExecuteChangedEvent;
begin
  for Handler in FCanExecuteChangedHandlers do
    Handler(Self);
end;

procedure TAsyncCommand.Cancel;
begin
  if FState = acsRunning then
  begin
    SetState(acsCancelling);
    FCancelled := True;
  end;
end;

procedure TAsyncCommand.Wait(Timeout: Cardinal);
var
  StartTick: Cardinal;
  TimedOut: Boolean;
  Completed: Boolean;
begin
  if FTask = nil then
    Exit;

  if TThread.CurrentThread.ThreadID <> MainThreadID then
  begin
    if FTask.Wait(Timeout) then
      FTask := nil;
    Exit;
  end;

  StartTick := TThread.GetTickCount;
  Completed := False;
  repeat
    if FTask.Wait(10) then
    begin
      CheckSynchronize(0);
      Completed := True;
      Break;
    end;

    CheckSynchronize(10);
    TimedOut := (Timeout <> INFINITE) and
      ((TThread.GetTickCount - StartTick) >= Timeout);
  until TimedOut;

  if Completed then
    FTask := nil;
end;

{ TViewModelBase }

constructor TViewModelBase.Create;
begin
  inherited Create;
  FIsBusy := False;
  FBusyMessage := '';
  FErrorMessage := '';
  FIsActive := False;
  FValidationErrors := TDictionary<string, TValidationErrors>.Create;
  FPropertyErrorHandlers := TList<TPropertyErrorEvent>.Create;
end;

destructor TViewModelBase.Destroy;
begin
  FreeAndNil(FPropertyErrorHandlers);
  FreeAndNil(FValidationErrors);
  inherited;
end;

procedure TViewModelBase.SetIsBusy(const Value: Boolean);
begin
  SetField<Boolean>(FIsBusy, Value, 'IsBusy');
end;

procedure TViewModelBase.SetBusyMessage(const Value: string);
begin
  SetField<string>(FBusyMessage, Value, 'BusyMessage');
end;

procedure TViewModelBase.SetErrorMessage(const Value: string);
begin
  SetField<string>(FErrorMessage, Value, 'ErrorMessage');
end;

function TViewModelBase.GetHasErrors: Boolean;
var
  Pair: TPair<string, TValidationErrors>;
begin
  Result := False;
  for Pair in FValidationErrors do
  begin
    if Length(Pair.Value) > 0 then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

procedure TViewModelBase.OnActivate;
begin
  // Override in derived classes
end;

procedure TViewModelBase.OnDeactivate;
begin
  // Override in derived classes
end;

function TViewModelBase.DoValidate: TValidationErrors;
begin
  // Override in derived classes
  Result := nil;
end;

function TViewModelBase.DoValidateProperty(const PropertyName: string): TValidationErrors;
begin
  // Override in derived classes
  Result := nil;
end;

procedure TViewModelBase.AddError(const PropertyName, ErrorMessage: string;
  Severity: TValidationSeverity);
var
  Errors: TValidationErrors;
begin
  if FValidationErrors.TryGetValue(PropertyName, Errors) then
  begin
    SetLength(Errors, Length(Errors) + 1);
    Errors[High(Errors)] := TValidationError.Create(PropertyName, ErrorMessage, Severity);
    FValidationErrors[PropertyName] := Errors;
  end
  else
  begin
    SetLength(Errors, 1);
    Errors[0] := TValidationError.Create(PropertyName, ErrorMessage, Severity);
    FValidationErrors.Add(PropertyName, Errors);
  end;
  
  NotifyPropertyError(PropertyName);
  NotifyPropertyChanged('HasErrors');
end;

procedure TViewModelBase.ClearErrors(const PropertyName: string);
begin
  if PropertyName = '' then
  begin
    FValidationErrors.Clear;
    NotifyPropertyChanged('HasErrors');
  end
  else
  begin
    if FValidationErrors.ContainsKey(PropertyName) then
    begin
      FValidationErrors.Remove(PropertyName);
      NotifyPropertyError(PropertyName);
      NotifyPropertyChanged('HasErrors');
    end;
  end;
end;

procedure TViewModelBase.NotifyPropertyError(const PropertyName: string);
var
  Handler: TPropertyErrorEvent;
  Args: TPropertyErrorEventArgs;
begin
  Args.PropertyName := PropertyName;
  Args.Errors := GetErrors(PropertyName);
  
  for Handler in FPropertyErrorHandlers do
    Handler(Self, Args);
end;

procedure TViewModelBase.BeginBusy(const Message: string);
begin
  FBusyMessage := Message;
  IsBusy := True;
end;

procedure TViewModelBase.EndBusy;
begin
  IsBusy := False;
  FBusyMessage := '';
end;

procedure TViewModelBase.Activate;
begin
  if not FIsActive then
  begin
    FIsActive := True;
    OnActivate;
    NotifyPropertyChanged('IsActive');
  end;
end;

procedure TViewModelBase.Deactivate;
begin
  if FIsActive then
  begin
    FIsActive := False;
    OnDeactivate;
    NotifyPropertyChanged('IsActive');
  end;
end;

function TViewModelBase.Validate: TValidationErrors;
begin
  ClearErrors;
  Result := DoValidate;
  
  // Add errors to dictionary
  for var Err in Result do
    AddError(Err.PropertyName, Err.ErrorMessage, Err.Severity);
end;

function TViewModelBase.ValidateProperty(const PropertyName: string): TValidationErrors;
begin
  ClearErrors(PropertyName);
  Result := DoValidateProperty(PropertyName);
  
  // Add errors to dictionary
  for var Err in Result do
    AddError(Err.PropertyName, Err.ErrorMessage, Err.Severity);
end;

function TViewModelBase.HasErrors: Boolean;
begin
  Result := GetHasErrors;
end;

function TViewModelBase.GetErrors(const PropertyName: string): TValidationErrors;
begin
  if not FValidationErrors.TryGetValue(PropertyName, Result) then
    Result := nil;
end;

procedure TViewModelBase.AddPropertyErrorHandler(Handler: TPropertyErrorEvent);
begin
  if not FPropertyErrorHandlers.Contains(Handler) then
    FPropertyErrorHandlers.Add(Handler);
end;

procedure TViewModelBase.RemovePropertyErrorHandler(Handler: TPropertyErrorEvent);
begin
  FPropertyErrorHandlers.Remove(Handler);
end;

{ TValidationRule<T> }

constructor TValidationRule<T>.Create(const APropertyName, AErrorMessage: string;
  AValidateFunc: TFunc<T, Boolean>);
begin
  inherited Create;
  FPropertyName := APropertyName;
  FErrorMessage := AErrorMessage;
  FValidateFunc := AValidateFunc;
end;

function TValidationRule<T>.Validate(const Value: T): TValidationError;
begin
  if not IsValid(Value) then
    Result := TValidationError.Create(FPropertyName, FErrorMessage, vsError)
  else
  begin
    Result.PropertyName := FPropertyName;
    Result.ErrorMessage := '';
    Result.Severity := vsError;
  end;
end;

function TValidationRule<T>.IsValid(const Value: T): Boolean;
begin
  if Assigned(FValidateFunc) then
    Result := FValidateFunc(Value)
  else
    Result := True;
end;

{ TValidationRules }

class function TValidationRules.Required(const PropertyName, ErrorMessage: string): TValidationRule<string>;
var
  Msg: string;
begin
  if ErrorMessage = '' then
    Msg := PropertyName + ' is required'
  else
    Msg := ErrorMessage;
    
  Result := TValidationRule<string>.Create(PropertyName, Msg,
    function(Value: string): Boolean
    begin
      Result := Trim(Value) <> '';
    end);
end;

class function TValidationRules.MinLength(const PropertyName: string; MinLen: Integer;
  const ErrorMessage: string): TValidationRule<string>;
var
  Msg: string;
  LocalMinLen: Integer;
begin
  if ErrorMessage = '' then
    Msg := Format('%s must be at least %d characters', [PropertyName, MinLen])
  else
    Msg := ErrorMessage;
  
  LocalMinLen := MinLen;
  Result := TValidationRule<string>.Create(PropertyName, Msg,
    function(Value: string): Boolean
    begin
      Result := Length(Value) >= LocalMinLen;
    end);
end;

class function TValidationRules.MaxLength(const PropertyName: string; MaxLen: Integer;
  const ErrorMessage: string): TValidationRule<string>;
var
  Msg: string;
  LocalMaxLen: Integer;
begin
  if ErrorMessage = '' then
    Msg := Format('%s must be at most %d characters', [PropertyName, MaxLen])
  else
    Msg := ErrorMessage;
  
  LocalMaxLen := MaxLen;
  Result := TValidationRule<string>.Create(PropertyName, Msg,
    function(Value: string): Boolean
    begin
      Result := Length(Value) <= LocalMaxLen;
    end);
end;

class function TValidationRules.Pattern(const PropertyName, APattern, ErrorMessage: string): TValidationRule<string>;
var
  Msg: string;
  LocalPattern: string;
begin
  if ErrorMessage = '' then
    Msg := PropertyName + ' format is invalid'
  else
    Msg := ErrorMessage;
  
  LocalPattern := APattern;
  Result := TValidationRule<string>.Create(PropertyName, Msg,
    function(Value: string): Boolean
    begin
      Result := TRegEx.IsMatch(Value, LocalPattern);
    end);
end;

class function TValidationRules.Email(const PropertyName, ErrorMessage: string): TValidationRule<string>;
var
  Msg: string;
begin
  if ErrorMessage = '' then
    Msg := PropertyName + ' must be a valid email address'
  else
    Msg := ErrorMessage;
    
  Result := TValidationRule<string>.Create(PropertyName, Msg,
    function(Value: string): Boolean
    const
      EmailPattern = '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
    begin
      if Value = '' then
        Result := True  // Empty is valid (use Required for mandatory)
      else
        Result := TRegEx.IsMatch(Value, EmailPattern);
    end);
end;

class function TValidationRules.Range(const PropertyName: string; MinVal, MaxVal: Integer;
  const ErrorMessage: string): TValidationRule<Integer>;
var
  Msg: string;
  LocalMin, LocalMax: Integer;
begin
  if ErrorMessage = '' then
    Msg := Format('%s must be between %d and %d', [PropertyName, MinVal, MaxVal])
  else
    Msg := ErrorMessage;
  
  LocalMin := MinVal;
  LocalMax := MaxVal;
  Result := TValidationRule<Integer>.Create(PropertyName, Msg,
    function(Value: Integer): Boolean
    begin
      Result := (Value >= LocalMin) and (Value <= LocalMax);
    end);
end;

end.
