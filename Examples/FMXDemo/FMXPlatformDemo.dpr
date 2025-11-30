program FMXPlatformDemo;

uses
  System.StartUpCopy,
  FMX.Forms,
  Main.Form in 'Main.Form.pas' {MainForm},
  UniBase.FMX.Platform in '..\..\FMX\UniBase.FMX.Platform.pas',
  UniBase.FMX.Theme in '..\..\FMX\UniBase.FMX.Theme.pas',
  UniBase.FMX.ListView in '..\..\FMX\UniBase.FMX.ListView.pas',
  UniBase.FMX.FormControls in '..\..\FMX\UniBase.FMX.FormControls.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
