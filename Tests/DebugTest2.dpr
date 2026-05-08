program DebugTest2;
{$APPTYPE CONSOLE}
{$STRONGLINKTYPES ON}
uses
  System.SysUtils,
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  DUnitX.TestFramework,
  Test.DeepBase.Manager in 'Test.DeepBase.Manager.pas',
  DeepBase.Types in '..\Core\DeepBase.Types.pas',
  DeepBase.Manager in '..\Core\DeepBase.Manager.pas',
  DeepBase.Config in '..\Core\DeepBase.Config.pas',
  DeepBase.i18n in '..\Core\DeepBase.i18n.pas',
  DeepBase.FormState in '..\Core\DeepBase.FormState.pas',
  DeepBase.Logging in '..\Core\DeepBase.Logging.pas',
  DeepBase.MRU in '..\Core\DeepBase.MRU.pas',
  DeepBase.Hotkeys in '..\Core\DeepBase.Hotkeys.pas',
  DeepBase.Theme in '..\Core\DeepBase.Theme.pas',
  DeepBase.License in '..\Core\DeepBase.License.pas';
begin
  WriteLn('Debug Test 2');
end.
