program CRUDApp;

{$APPTYPE GUI}

{$R *.res}

uses
  Vcl.Forms,
  Main.Form in 'Main.Form.pas' {MainForm},
  Data.Module in 'Data.Module.pas' {DataMod: TDataModule},
  Entity.Customer in 'Entity.Customer.pas',
  Form.CustomerEdit in 'Form.CustomerEdit.pas' {CustomerEditForm},
  Form.CustomerList in 'Form.CustomerList.pas' {CustomerListFrame: TFrame};

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'CRUD Application Template';
  Application.CreateForm(TDataMod, DataMod);
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
