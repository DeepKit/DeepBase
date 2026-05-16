program UniPublisher;

{$APPTYPE GUI}

uses
  Vcl.Forms,
  DeepPublisher.MainForm in 'Forms\DeepPublisher.MainForm.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'UniPublisher';
  Application.CreateForm(TfrmUniPublisherMain, frmUniPublisherMain);
  Application.Run;
end.
