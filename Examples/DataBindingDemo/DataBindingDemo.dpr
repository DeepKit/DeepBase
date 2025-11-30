{ ============================================================================
  DataBindingDemo - UniBase DataBinding Demonstration
  
  This demo project shows how to use the UniBase.DataBinding module for
  creating observable objects and binding them to UI controls.
  ============================================================================ }

program DataBindingDemo;

uses
  Vcl.Forms,
  MainForm in 'MainForm.pas' {frmMain},
  UniBase.DataBinding in '..\..\Core\UniBase.DataBinding.pas',
  UniBase.VCL.BindableControls in '..\..\VCL\UniBase.VCL.BindableControls.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'DataBinding Demo';
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
