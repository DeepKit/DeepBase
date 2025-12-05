program UniFlow;

uses
  System.StartUpCopy,
  FMX.Forms,
  UniFlow.Engine in 'Source\Core\UniFlow.Engine.pas',
  UniFlow.Skill.Client in 'Source\AI\UniFlow.Skill.Client.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm, Form); // Note: Actual Form class needs to be defined if UI is added
  Application.Run;
end.
