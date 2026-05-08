program DebugTest;
{$APPTYPE CONSOLE}
uses
  System.SysUtils,
  DUnitX.Loggers.Console,
  DUnitX.TestFramework,
  Test.DeepBase.Manager in 'Test.DeepBase.Manager.pas',
  DeepBase.Types in '..\Core\DeepBase.Types.pas',
  DeepBase.Manager in '..\Core\DeepBase.Manager.pas';
begin
  WriteLn('Debug Test');
end.
