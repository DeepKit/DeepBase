program TestSecurityM2;

{ Minimal DUnitX runner for WO-20260920-AUDIT-甲-R5 M2 (Top20#05 security master
  password). Covers the UBS2 envelope, the machine binding, the keystore gate and
  secure wiping without touching DeepBaseTests.dpr. }

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.IOUtils,
  DUnitX.TestFramework,
  DeepBase.Persistence.Manager.FireDAC,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  Test.DeepBase.Security.UBS2,
  Test.DeepBase.Security.MachineIdentity,
  Test.DeepBase.SecureMemory,
  Test.DeepBase.KeyManager,
  Test.DeepBase.Security;

begin
  try
    TDUnitX.CheckCommandLine;
    var LRunner: ITestRunner := TDUnitX.CreateRunner;
    LRunner.UseRTTI := True;
    LRunner.FailsOnNoAsserts := False;

    var LConsoleLogger: ITestLogger := TDUnitXConsoleLogger.Create(True);
    LRunner.AddLogger(LConsoleLogger);

    var LXPath := TPath.Combine(ExtractFilePath(ParamStr(0)), '..\TestResults');
    TDirectory.CreateDirectory(LXPath);
    var LXmlFile := TPath.Combine(LXPath, '20260920-AUDIT-M2-SecurityMasterKey.xml');
    var LNUnitLogger: ITestLogger := TDUnitXXMLNUnitFileLogger.Create(LXmlFile);
    LRunner.AddLogger(LNUnitLogger);

    var LResults: IRunResults := LRunner.Execute;
    var LPassed := LResults.AllPassed;
    LResults := nil;
    LRunner := nil;
    LNUnitLogger := nil;
    LConsoleLogger := nil;

    if not LPassed then
      System.ExitCode := 1;
  except
    on E: Exception do
    begin
      System.Writeln(E.ClassName, ': ', E.Message);
      System.ExitCode := 2;
    end;
  end;
end.
