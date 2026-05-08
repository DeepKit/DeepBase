program MicroserviceClientDemo;

uses
  Vcl.Forms,
  MainForm in 'MainForm.pas' {MainForm},
  DeepBase.Microservice.Client in 'DeepBase.Microservice.Client.pas';

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'DeepBase Microservice Client Demo';
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
