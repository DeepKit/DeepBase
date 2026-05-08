program DeepFlow;

uses
  System.StartUpCopy,
  FMX.Forms,
  DeepFlow.Engine in 'Source\Core\DeepFlow.Engine.pas',
  DeepFlow.Skill.Client in 'Source\AI\DeepFlow.Skill.Client.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm, Form); // Note: Actual Form class needs to be defined if UI is added
  Application.Run;
end.
