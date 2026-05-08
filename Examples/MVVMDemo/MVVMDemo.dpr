{ ============================================================================
  MVVMDemo - MVVM Framework Demo Application
  
  Description: Demonstrates the DeepBase MVVM framework with a login form
               featuring data binding, commands, validation, and async operations.
  
  Features Demonstrated:
    - TViewModelBase with INotifyPropertyChanged
    - TRelayCommand for synchronous commands
    - TAsyncCommand for background operations with cancellation
    - Validation with TValidationError and property-level errors
    - Two-way data binding between ViewModel and View
  
  Test Credentials:
    - Any username (min 3 chars) + any password (min 6 chars) = Success
    - admin + admin123 = Success
    - admin + wrong = Failure (invalid password)
    - error + any = Failure (simulated server error)
  ============================================================================ }

program MVVMDemo;

uses
  Vcl.Forms,
  MainForm in 'MainForm.pas' {frmMain},
  LoginViewModel in 'LoginViewModel.pas',
  DeepBase.DataBinding in '..\..\Core\DeepBase.DataBinding.pas',
  DeepBase.MVVM in '..\..\Core\DeepBase.MVVM.pas',
  DeepBase.VCL.MVVMControls in '..\..\VCL\DeepBase.VCL.MVVMControls.pas';

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
