{ ============================================================================
  DeepBase.VCL.MVVMControls - VCL MVVM Controls
  
  Version: 0.3
  Description: VCL controls and base forms for MVVM pattern.
               Provides TMVVMForm, TMVVMFrame and command-bound controls.
  
  Usage:
    TMyForm = class(TMVVMForm<TMyViewModel>)
      procedure FormCreate(Sender: TObject);
    private
      procedure SetupBindings;
    end;
    
    procedure TMyForm.FormCreate(Sender: TObject);
    begin
      SetViewModel(TMyViewModel.Create);
      SetupBindings;
    end;
  ============================================================================ }

unit DeepBase.VCL.MVVMControls;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.Graphics,
  DeepBase.DataBinding,
  DeepBase.MVVM,
  DeepBase.Exceptions;

type
  // Forward declarations
  TMVVMFormBase = class;
  TMVVMFrameBase = class;
  TCommandButton = class;
  
  // ============================================================================
  // Base MVVM Form (non-generic)
  // ============================================================================
  
  /// <summary>
  /// Non-generic base class for MVVM forms
  /// </summary>
  TMVVMFormBase = class(TForm)
  private
    FViewModelObj: TViewModelBase;
    FBindingManager: TBindingManager;
    FOwnsViewModel: Boolean;
    
    procedure HandleViewModelPropertyChanged(const Args: TPropertyChangedEventArgs);
    procedure HandlePropertyError(Sender: TObject; const Args: TPropertyErrorEventArgs);
  protected
    /// <summary>Called when ViewModel is set</summary>
    procedure OnViewModelSet; virtual;
    /// <summary>Called to setup bindings after ViewModel is set</summary>
    procedure SetupBindings; virtual;
    /// <summary>Called when ViewModel's IsBusy changes</summary>
    procedure OnBusyChanged(IsBusy: Boolean); virtual;
    /// <summary>Called when ViewModel's ErrorMessage changes</summary>
    procedure OnErrorChanged(const ErrorMessage: string); virtual;
    /// <summary>Called when property validation error occurs</summary>
    procedure OnPropertyError(const PropertyName: string; const Errors: TValidationErrors); virtual;
    
    procedure DoShow; override;
    procedure DoClose(var Action: TCloseAction); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    /// <summary>Bind a control property to a ViewModel property</summary>
    procedure BindControl(Control: TControl; const ControlProp: string;
      const ViewModelProp: string; Mode: TBindingMode = bmTwoWay);
    
    /// <summary>Bind a command button to a command</summary>
    procedure BindCommand(Button: TButton; Command: ICommand; 
      const Parameter: TValue); overload;
    procedure BindCommand(Button: TButton; Command: ICommand); overload;
    
    /// <summary>The binding manager instance</summary>
    property BindingManager: TBindingManager read FBindingManager;
    /// <summary>The ViewModel instance (base type)</summary>
    property ViewModelObj: TViewModelBase read FViewModelObj;
    /// <summary>Whether form owns the ViewModel (frees on destroy)</summary>
    property OwnsViewModel: Boolean read FOwnsViewModel write FOwnsViewModel;
  end;
  
  // ============================================================================
  // Generic MVVM Form
  // ============================================================================
  
  /// <summary>
  /// Generic MVVM form with typed ViewModel
  /// </summary>
  TMVVMForm<T: TViewModelBase, constructor> = class(TMVVMFormBase)
  private
    function GetViewModel: T;
  protected
    /// <summary>Set or create the ViewModel (pass nil to auto-create)</summary>
    procedure SetViewModel(AViewModel: T);
  public
    /// <summary>The typed ViewModel</summary>
    property ViewModel: T read GetViewModel;
  end;
  
  // ============================================================================
  // Base MVVM Frame (non-generic)
  // ============================================================================
  
  /// <summary>
  /// Non-generic base class for MVVM frames
  /// </summary>
  TMVVMFrameBase = class(TFrame)
  private
    FViewModelObj: TViewModelBase;
    FBindingManager: TBindingManager;
    FOwnsViewModel: Boolean;
    
    procedure HandleViewModelPropertyChanged(const Args: TPropertyChangedEventArgs);
    procedure HandlePropertyError(Sender: TObject; const Args: TPropertyErrorEventArgs);
  protected
    /// <summary>Called when ViewModel is set</summary>
    procedure OnViewModelSet; virtual;
    /// <summary>Called to setup bindings after ViewModel is set</summary>
    procedure SetupBindings; virtual;
    /// <summary>Called when ViewModel's IsBusy changes</summary>
    procedure OnBusyChanged(IsBusy: Boolean); virtual;
    /// <summary>Called when ViewModel's ErrorMessage changes</summary>
    procedure OnErrorChanged(const ErrorMessage: string); virtual;
    /// <summary>Called when property validation error occurs</summary>
    procedure OnPropertyError(const PropertyName: string; const Errors: TValidationErrors); virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    /// <summary>Bind a control property to a ViewModel property</summary>
    procedure BindControl(Control: TControl; const ControlProp: string;
      const ViewModelProp: string; Mode: TBindingMode = bmTwoWay);
    
    /// <summary>Bind a command button to a command</summary>
    procedure BindCommand(Button: TButton; Command: ICommand; 
      const Parameter: TValue); overload;
    procedure BindCommand(Button: TButton; Command: ICommand); overload;
    
    /// <summary>Activate the ViewModel</summary>
    procedure Activate;
    /// <summary>Deactivate the ViewModel</summary>
    procedure Deactivate;
    
    /// <summary>The binding manager instance</summary>
    property BindingManager: TBindingManager read FBindingManager;
    /// <summary>The ViewModel instance (base type)</summary>
    property ViewModelObj: TViewModelBase read FViewModelObj;
    /// <summary>Whether frame owns the ViewModel (frees on destroy)</summary>
    property OwnsViewModel: Boolean read FOwnsViewModel write FOwnsViewModel;
  end;
  
  // ============================================================================
  // Generic MVVM Frame
  // ============================================================================
  
  /// <summary>
  /// Generic MVVM frame with typed ViewModel
  /// </summary>
  TMVVMFrame<T: TViewModelBase, constructor> = class(TMVVMFrameBase)
  private
    function GetViewModel: T;
  protected
    /// <summary>Set or create the ViewModel (pass nil to auto-create)</summary>
    procedure SetViewModel(AViewModel: T);
  public
    /// <summary>The typed ViewModel</summary>
    property ViewModel: T read GetViewModel;
  end;
  
  // ============================================================================
  // Command Button
  // ============================================================================
  
  /// <summary>
  /// Button that binds to an ICommand
  /// </summary>
  TCommandButton = class(TButton)
  private
    FCommand: ICommand;
    FCommandParameter: TValue;
    
    procedure HandleCanExecuteChanged(Sender: TObject);
    procedure UpdateEnabledState;
    procedure SetCommand(const Value: ICommand);
    procedure SetCommandParameter(const Value: TValue);
  protected
    procedure Click; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    /// <summary>The command to execute on click</summary>
    property Command: ICommand read FCommand write SetCommand;
    /// <summary>Parameter to pass to command</summary>
    property CommandParameter: TValue read FCommandParameter write SetCommandParameter;
  end;
  
  // ============================================================================
  // Error Label
  // ============================================================================
  
  /// <summary>
  /// Label that displays validation errors for a property
  /// </summary>
  TValidationErrorLabel = class(TLabel)
  private
    FPropertyName: string;
    FViewModel: TViewModelBase;
    
    procedure HandlePropertyError(Sender: TObject; const Args: TPropertyErrorEventArgs);
    procedure SetViewModel(const Value: TViewModelBase);
    procedure UpdateErrors;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    /// <summary>Bind to a ViewModel for error display</summary>
    procedure BindToViewModel(AViewModel: TViewModelBase; const APropName: string);
    
    /// <summary>The property name to show errors for</summary>
    property PropertyName: string read FPropertyName write FPropertyName;
    /// <summary>The ViewModel to watch for errors</summary>
    property ViewModel: TViewModelBase read FViewModel write SetViewModel;
  end;
  
  // ============================================================================
  // Busy Indicator Panel
  // ============================================================================
  
  /// <summary>
  /// Panel that shows when ViewModel is busy
  /// </summary>
  TBusyIndicatorPanel = class(TPanel)
  private
    FViewModel: TViewModelBase;
    FBusyLabel: TLabel;
    FProgressBar: TProgressBar;
    
    procedure HandleViewModelPropertyChanged(const Args: TPropertyChangedEventArgs);
    procedure SetViewModel(const Value: TViewModelBase);
    procedure UpdateVisibility;
  protected
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    /// <summary>Bind to a ViewModel for busy state display</summary>
    procedure BindToViewModel(AViewModel: TViewModelBase);
    
    /// <summary>The ViewModel to watch for busy state</summary>
    property ViewModel: TViewModelBase read FViewModel write SetViewModel;
  end;

implementation

uses
  Vcl.Dialogs;

// ============================================================================
// Internal Command Button Binding Helper
// ============================================================================

type
  TCommandButtonBinding = class
  private
    FButton: TButton;
    FCommand: ICommand;
    FParameter: TValue;
    FOriginalOnClick: TNotifyEvent;
    
    procedure HandleClick(Sender: TObject);
    procedure HandleCanExecuteChanged(Sender: TObject);
  public
    constructor Create(AButton: TButton; ACommand: ICommand; const AParameter: TValue);
    destructor Destroy; override;
  end;

constructor TCommandButtonBinding.Create(AButton: TButton; ACommand: ICommand;
  const AParameter: TValue);
begin
  inherited Create;
  FButton := AButton;
  FCommand := ACommand;
  FParameter := AParameter;
  
  // Store original click handler
  FOriginalOnClick := FButton.OnClick;
  FButton.OnClick := HandleClick;
  
  // Subscribe to CanExecuteChanged
  FCommand.AddCanExecuteChangedHandler(HandleCanExecuteChanged);
  
  // Initial state
  FButton.Enabled := FCommand.CanExecute(FParameter);
end;

destructor TCommandButtonBinding.Destroy;
begin
  if FCommand <> nil then
    FCommand.RemoveCanExecuteChangedHandler(HandleCanExecuteChanged);
  
  // Restore original click handler
  if FButton <> nil then
    FButton.OnClick := FOriginalOnClick;
    
  inherited;
end;

procedure TCommandButtonBinding.HandleClick(Sender: TObject);
begin
  if (FCommand <> nil) and FCommand.CanExecute(FParameter) then
    FCommand.Execute(FParameter);
    
  // Call original handler if any
  if Assigned(FOriginalOnClick) then
    FOriginalOnClick(Sender);
end;

procedure TCommandButtonBinding.HandleCanExecuteChanged(Sender: TObject);
begin
  if FButton <> nil then
    FButton.Enabled := FCommand.CanExecute(FParameter);
end;

// Global list to track command bindings (prevent premature destruction)
var
  GCommandBindings: TList;

procedure RegisterCommandBinding(Binding: TCommandButtonBinding);
begin
  if GCommandBindings = nil then
    GCommandBindings := TList.Create;
  GCommandBindings.Add(Binding);
end;

procedure UnregisterCommandBinding(Binding: TCommandButtonBinding);
begin
  if GCommandBindings <> nil then
    GCommandBindings.Remove(Binding);
end;

// ============================================================================
// TMVVMFormBase
// ============================================================================

constructor TMVVMFormBase.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FBindingManager := TBindingManager.Create;
  FOwnsViewModel := True;
end;

destructor TMVVMFormBase.Destroy;
begin
  if FViewModelObj <> nil then
  begin
    FViewModelObj.RemovePropertyChangedHandler(HandleViewModelPropertyChanged);
    FViewModelObj.RemovePropertyErrorHandler(HandlePropertyError);
  end;
  
  FreeAndNil(FBindingManager);
  
  if FOwnsViewModel and (FViewModelObj <> nil) then
    FreeAndNil(FViewModelObj);
    
  inherited;
end;

procedure TMVVMFormBase.HandleViewModelPropertyChanged(const Args: TPropertyChangedEventArgs);
begin
  if Args.PropertyName = 'IsBusy' then
    OnBusyChanged(FViewModelObj.IsBusy)
  else if Args.PropertyName = 'ErrorMessage' then
    OnErrorChanged(FViewModelObj.ErrorMessage);
end;

procedure TMVVMFormBase.HandlePropertyError(Sender: TObject; 
  const Args: TPropertyErrorEventArgs);
begin
  OnPropertyError(Args.PropertyName, Args.Errors);
end;

procedure TMVVMFormBase.OnViewModelSet;
begin
  // Override in derived classes
end;

procedure TMVVMFormBase.SetupBindings;
begin
  // Override in derived classes
end;

procedure TMVVMFormBase.OnBusyChanged(IsBusy: Boolean);
begin
  // Default: enable/disable form controls
  // Override for custom behavior
end;

procedure TMVVMFormBase.OnErrorChanged(const ErrorMessage: string);
begin
  // Default: show message box if error
  if ErrorMessage <> '' then
    ShowMessage(ErrorMessage);
end;

procedure TMVVMFormBase.OnPropertyError(const PropertyName: string;
  const Errors: TValidationErrors);
begin
  // Override in derived classes for custom error display
end;

procedure TMVVMFormBase.DoShow;
begin
  inherited;
  if FViewModelObj <> nil then
    FViewModelObj.Activate;
end;

procedure TMVVMFormBase.DoClose(var Action: TCloseAction);
begin
  if FViewModelObj <> nil then
    FViewModelObj.Deactivate;
  inherited;
end;

procedure TMVVMFormBase.BindControl(Control: TControl; const ControlProp,
  ViewModelProp: string; Mode: TBindingMode);
begin
  if FViewModelObj = nil then
    raise EInvalidOperationException.Create('ViewModel not set. Call SetViewModel first.');
    
  FBindingManager.Bind(FViewModelObj, ViewModelProp, Control, ControlProp, Mode);
end;

procedure TMVVMFormBase.BindCommand(Button: TButton; Command: ICommand;
  const Parameter: TValue);
var
  Binding: TCommandButtonBinding;
begin
  Binding := TCommandButtonBinding.Create(Button, Command, Parameter);
  RegisterCommandBinding(Binding);
end;

procedure TMVVMFormBase.BindCommand(Button: TButton; Command: ICommand);
begin
  BindCommand(Button, Command, TValue.Empty);
end;

// ============================================================================
// TMVVMForm<T>
// ============================================================================

function TMVVMForm<T>.GetViewModel: T;
begin
  Result := T(FViewModelObj);
end;

procedure TMVVMForm<T>.SetViewModel(AViewModel: T);
begin
  // Unsubscribe from old ViewModel
  if FViewModelObj <> nil then
  begin
    FViewModelObj.RemovePropertyChangedHandler(HandleViewModelPropertyChanged);
    FViewModelObj.RemovePropertyErrorHandler(HandlePropertyError);
    
    if FOwnsViewModel then
      FViewModelObj.Free;
  end;
  
  // Create new if not provided
  if AViewModel = nil then
    FViewModelObj := T.Create
  else
    FViewModelObj := AViewModel;
  
  // Subscribe to property changes
  FViewModelObj.AddPropertyChangedHandler(HandleViewModelPropertyChanged);
  FViewModelObj.AddPropertyErrorHandler(HandlePropertyError);
  
  OnViewModelSet;
  SetupBindings;
end;

// ============================================================================
// TMVVMFrameBase
// ============================================================================

constructor TMVVMFrameBase.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FBindingManager := TBindingManager.Create;
  FOwnsViewModel := True;
end;

destructor TMVVMFrameBase.Destroy;
begin
  if FViewModelObj <> nil then
  begin
    FViewModelObj.RemovePropertyChangedHandler(HandleViewModelPropertyChanged);
    FViewModelObj.RemovePropertyErrorHandler(HandlePropertyError);
  end;
  
  FreeAndNil(FBindingManager);
  
  if FOwnsViewModel and (FViewModelObj <> nil) then
    FreeAndNil(FViewModelObj);
    
  inherited;
end;

procedure TMVVMFrameBase.HandleViewModelPropertyChanged(const Args: TPropertyChangedEventArgs);
begin
  if Args.PropertyName = 'IsBusy' then
    OnBusyChanged(FViewModelObj.IsBusy)
  else if Args.PropertyName = 'ErrorMessage' then
    OnErrorChanged(FViewModelObj.ErrorMessage);
end;

procedure TMVVMFrameBase.HandlePropertyError(Sender: TObject;
  const Args: TPropertyErrorEventArgs);
begin
  OnPropertyError(Args.PropertyName, Args.Errors);
end;

procedure TMVVMFrameBase.OnViewModelSet;
begin
  // Override in derived classes
end;

procedure TMVVMFrameBase.SetupBindings;
begin
  // Override in derived classes
end;

procedure TMVVMFrameBase.OnBusyChanged(IsBusy: Boolean);
begin
  // Override in derived classes
end;

procedure TMVVMFrameBase.OnErrorChanged(const ErrorMessage: string);
begin
  if ErrorMessage <> '' then
    ShowMessage(ErrorMessage);
end;

procedure TMVVMFrameBase.OnPropertyError(const PropertyName: string;
  const Errors: TValidationErrors);
begin
  // Override in derived classes
end;

procedure TMVVMFrameBase.BindControl(Control: TControl; const ControlProp,
  ViewModelProp: string; Mode: TBindingMode);
begin
  if FViewModelObj = nil then
    raise EInvalidOperationException.Create('ViewModel not set. Call SetViewModel first.');
    
  FBindingManager.Bind(FViewModelObj, ViewModelProp, Control, ControlProp, Mode);
end;

procedure TMVVMFrameBase.BindCommand(Button: TButton; Command: ICommand;
  const Parameter: TValue);
var
  Binding: TCommandButtonBinding;
begin
  Binding := TCommandButtonBinding.Create(Button, Command, Parameter);
  RegisterCommandBinding(Binding);
end;

procedure TMVVMFrameBase.BindCommand(Button: TButton; Command: ICommand);
begin
  BindCommand(Button, Command, TValue.Empty);
end;

procedure TMVVMFrameBase.Activate;
begin
  if FViewModelObj <> nil then
    FViewModelObj.Activate;
end;

procedure TMVVMFrameBase.Deactivate;
begin
  if FViewModelObj <> nil then
    FViewModelObj.Deactivate;
end;

// ============================================================================
// TMVVMFrame<T>
// ============================================================================

function TMVVMFrame<T>.GetViewModel: T;
begin
  Result := T(FViewModelObj);
end;

procedure TMVVMFrame<T>.SetViewModel(AViewModel: T);
begin
  // Unsubscribe from old ViewModel
  if FViewModelObj <> nil then
  begin
    FViewModelObj.RemovePropertyChangedHandler(HandleViewModelPropertyChanged);
    FViewModelObj.RemovePropertyErrorHandler(HandlePropertyError);
    
    if FOwnsViewModel then
      FViewModelObj.Free;
  end;
  
  // Create new if not provided
  if AViewModel = nil then
    FViewModelObj := T.Create
  else
    FViewModelObj := AViewModel;
  
  // Subscribe to property changes
  FViewModelObj.AddPropertyChangedHandler(HandleViewModelPropertyChanged);
  FViewModelObj.AddPropertyErrorHandler(HandlePropertyError);
  
  OnViewModelSet;
  SetupBindings;
end;

// ============================================================================
// TCommandButton
// ============================================================================

constructor TCommandButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCommandParameter := TValue.Empty;
end;

destructor TCommandButton.Destroy;
begin
  if FCommand <> nil then
    FCommand.RemoveCanExecuteChangedHandler(HandleCanExecuteChanged);
  inherited;
end;

procedure TCommandButton.SetCommand(const Value: ICommand);
begin
  if FCommand <> Value then
  begin
    // Unsubscribe from old command
    if FCommand <> nil then
      FCommand.RemoveCanExecuteChangedHandler(HandleCanExecuteChanged);
    
    FCommand := Value;
    
    // Subscribe to new command
    if FCommand <> nil then
    begin
      FCommand.AddCanExecuteChangedHandler(HandleCanExecuteChanged);
      UpdateEnabledState;
    end;
  end;
end;

procedure TCommandButton.SetCommandParameter(const Value: TValue);
begin
  FCommandParameter := Value;
  UpdateEnabledState;
end;

procedure TCommandButton.HandleCanExecuteChanged(Sender: TObject);
begin
  UpdateEnabledState;
end;

procedure TCommandButton.UpdateEnabledState;
begin
  if FCommand <> nil then
    Enabled := FCommand.CanExecute(FCommandParameter)
  else
    Enabled := False;
end;

procedure TCommandButton.Click;
begin
  if (FCommand <> nil) and FCommand.CanExecute(FCommandParameter) then
    FCommand.Execute(FCommandParameter);
  inherited;
end;

// ============================================================================
// TValidationErrorLabel
// ============================================================================

constructor TValidationErrorLabel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Font.Color := clRed;
  Visible := False;
end;

destructor TValidationErrorLabel.Destroy;
begin
  if FViewModel <> nil then
    FViewModel.RemovePropertyErrorHandler(HandlePropertyError);
  inherited;
end;

procedure TValidationErrorLabel.SetViewModel(const Value: TViewModelBase);
begin
  if FViewModel <> Value then
  begin
    if FViewModel <> nil then
      FViewModel.RemovePropertyErrorHandler(HandlePropertyError);
    
    FViewModel := Value;
    
    if FViewModel <> nil then
    begin
      FViewModel.AddPropertyErrorHandler(HandlePropertyError);
      UpdateErrors;
    end;
  end;
end;

procedure TValidationErrorLabel.HandlePropertyError(Sender: TObject;
  const Args: TPropertyErrorEventArgs);
begin
  if Args.PropertyName = FPropertyName then
    UpdateErrors;
end;

procedure TValidationErrorLabel.UpdateErrors;
var
  Errors: TValidationErrors;
  ErrText: string;
  i: Integer;
begin
  if (FViewModel = nil) or (FPropertyName = '') then
  begin
    Visible := False;
    Exit;
  end;
  
  Errors := FViewModel.GetErrors(FPropertyName);
  
  if Length(Errors) = 0 then
  begin
    Caption := '';
    Visible := False;
  end
  else
  begin
    ErrText := '';
    for i := 0 to High(Errors) do
    begin
      if i > 0 then
        ErrText := ErrText + #13#10;
      ErrText := ErrText + Errors[i].ErrorMessage;
    end;
    Caption := ErrText;
    Visible := True;
  end;
end;

procedure TValidationErrorLabel.BindToViewModel(AViewModel: TViewModelBase;
  const APropName: string);
begin
  FPropertyName := APropName;
  SetViewModel(AViewModel);
end;

// ============================================================================
// TBusyIndicatorPanel
// ============================================================================

constructor TBusyIndicatorPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  
  BevelOuter := bvNone;
  Color := clBtnFace;
  Visible := False;
  
  // Create busy label
  FBusyLabel := TLabel.Create(Self);
  FBusyLabel.Parent := Self;
  FBusyLabel.Align := alTop;
  FBusyLabel.Alignment := taCenter;
  FBusyLabel.Caption := 'Please wait...';
  
  // Create progress bar
  FProgressBar := TProgressBar.Create(Self);
  FProgressBar.Parent := Self;
  FProgressBar.Align := alTop;
  FProgressBar.Style := pbstMarquee;
end;

destructor TBusyIndicatorPanel.Destroy;
begin
  if FViewModel <> nil then
    FViewModel.RemovePropertyChangedHandler(HandleViewModelPropertyChanged);
  inherited;
end;

procedure TBusyIndicatorPanel.Loaded;
begin
  inherited;
  // Adjust layout after loading
  FBusyLabel.Top := 0;
  FProgressBar.Top := FBusyLabel.Height + 4;
end;

procedure TBusyIndicatorPanel.SetViewModel(const Value: TViewModelBase);
begin
  if FViewModel <> Value then
  begin
    if FViewModel <> nil then
      FViewModel.RemovePropertyChangedHandler(HandleViewModelPropertyChanged);
    
    FViewModel := Value;
    
    if FViewModel <> nil then
    begin
      FViewModel.AddPropertyChangedHandler(HandleViewModelPropertyChanged);
      UpdateVisibility;
    end;
  end;
end;

procedure TBusyIndicatorPanel.HandleViewModelPropertyChanged(
  const Args: TPropertyChangedEventArgs);
begin
  if (Args.PropertyName = 'IsBusy') or (Args.PropertyName = 'BusyMessage') then
    UpdateVisibility;
end;

procedure TBusyIndicatorPanel.UpdateVisibility;
begin
  if FViewModel = nil then
  begin
    Visible := False;
    Exit;
  end;
  
  Visible := FViewModel.IsBusy;
  
  if FViewModel.BusyMessage <> '' then
    FBusyLabel.Caption := FViewModel.BusyMessage
  else
    FBusyLabel.Caption := 'Please wait...';
end;

procedure TBusyIndicatorPanel.BindToViewModel(AViewModel: TViewModelBase);
begin
  SetViewModel(AViewModel);
end;

// ============================================================================
// Finalization
// ============================================================================

initialization

finalization
  if GCommandBindings <> nil then
  begin
    // Free all command bindings
    while GCommandBindings.Count > 0 do
    begin
      TCommandButtonBinding(GCommandBindings[0]).Free;
      GCommandBindings.Delete(0);
    end;
    GCommandBindings.Free;
  end;

end.
