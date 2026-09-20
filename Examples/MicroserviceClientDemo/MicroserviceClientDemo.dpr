program MicroserviceClientDemo;

uses
  Vcl.Forms,
  Main.Form in 'Main.Form.pas' {MainForm},
  DeepBase.Microservice.Client in 'DeepBase.Microservice.Client.pas';

begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'DeepBase Microservice Client Demo';
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
