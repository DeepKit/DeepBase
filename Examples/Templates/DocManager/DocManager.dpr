program DocManager;

uses
  Vcl.Forms,
  Main.Form in 'Main.Form.pas' {MainForm},
  Data.Module in 'Data.Module.pas' {DataModule1: TDataModule},
  Entity.Document in 'Entity.Document.pas',
  Entity.Category in 'Entity.Category.pas',
  Entity.Tag in 'Entity.Tag.pas',
  Service.Document in 'Service.Document.pas',
  Service.Search in 'Service.Search.pas',
  Form.DocumentEdit in 'Form.DocumentEdit.pas' {DocumentEditForm},
  Form.CategoryTree in 'Form.CategoryTree.pas' {CategoryTreeForm};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'Document Manager';
  Application.CreateForm(TDataModule1, DataModule1);
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
