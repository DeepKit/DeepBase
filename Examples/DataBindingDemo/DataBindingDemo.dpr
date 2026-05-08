{ ============================================================================
  DataBindingDemo - DeepBase DataBinding Demonstration
  
  This demo project shows how to use the DeepBase.DataBinding module for
  creating observable objects and binding them to UI controls.
  ============================================================================ }

program DataBindingDemo;

uses
  Vcl.Forms,
  MainForm in 'MainForm.pas' {frmMain},
  DeepBase.DataBinding in '..\..\Core\DeepBase.DataBinding.pas',
  DeepBase.VCL.BindableControls in '..\..\VCL\DeepBase.VCL.BindableControls.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'DataBinding Demo';
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
