program DebugTest;
{$APPTYPE CONSOLE}
uses
  System.SysUtils,
  DUnitX.Loggers.Console,
  DUnitX.TestFramework,
  Test.UniBase.Manager in 'Test.UniBase.Manager.pas',
  UniBase.Types in '..\Core\UniBase.Types.pas',
  UniBase.Manager in '..\Core\UniBase.Manager.pas';
begin
  WriteLn('Debug Test');
end.
