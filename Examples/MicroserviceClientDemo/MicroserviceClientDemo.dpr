program MicroserviceClientDemo;

uses
  Vcl.Forms,
  MainForm in 'MainForm.pas' {MainForm},
  UniBase.Microservice.Client in 'UniBase.Microservice.Client.pas';

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'UniBase Microservice Client Demo';
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
