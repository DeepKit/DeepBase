program UniPublisher;

{$APPTYPE GUI}

uses
  Vcl.Forms,
  UniPublisher.MainForm in 'Forms\UniPublisher.MainForm.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'UniPublisher';
  Application.CreateForm(TfrmUniPublisherMain, frmUniPublisherMain);
  Application.Run;
end.
