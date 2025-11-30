program DebugTest4;
{$APPTYPE CONSOLE}
uses
  System.SysUtils,
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  DUnitX.TestFramework,
  Test.UniBase.Manager in 'Test.UniBase.Manager.pas',
  UniBase.Types in '..\Core\UniBase.Types.pas',
  UniBase.Manager in '..\Core\UniBase.Manager.pas',
  UniBase.Config in '..\Core\UniBase.Config.pas',
  UniBase.i18n in '..\Core\UniBase.i18n.pas',
  UniBase.FormState in '..\Core\UniBase.FormState.pas',
  UniBase.Logging in '..\Core\UniBase.Logging.pas',
  UniBase.MRU in '..\Core\UniBase.MRU.pas',
  UniBase.Hotkeys in '..\Core\UniBase.Hotkeys.pas',
  UniBase.Theme in '..\Core\UniBase.Theme.pas';
begin
  WriteLn('Debug Test 4');
end.
