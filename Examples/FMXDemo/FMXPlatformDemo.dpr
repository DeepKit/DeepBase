program FMXPlatformDemo;

uses
  System.StartUpCopy,
  FMX.Forms,
  Main.Form in 'Main.Form.pas' {MainForm},
  DeepBase.FMX.Platform in '..\..\FMX\DeepBase.FMX.Platform.pas',
  DeepBase.FMX.Theme in '..\..\FMX\DeepBase.FMX.Theme.pas',
  DeepBase.FMX.ListView in '..\..\FMX\DeepBase.FMX.ListView.pas',
  DeepBase.FMX.FormControls in '..\..\FMX\DeepBase.FMX.FormControls.pas';

begin
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
