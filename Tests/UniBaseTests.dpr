program UniBaseTests;

{$IFNDEF TESTINSIGHT}
{$APPTYPE CONSOLE}
{$ENDIF}

{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  {$IFDEF TESTINSIGHT}
  TestInsight.DUnitX,
  {$ELSE}
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  {$ENDIF}
  DUnitX.TestFramework,
  // Test units - Phase 0
  Test.UniBase.Manager in 'Test.UniBase.Manager.pas',
  // Test units - Phase 0 (more)
  Test.UniBase.Config in 'Test.UniBase.Config.pas',
  Test.UniBase.i18n in 'Test.UniBase.i18n.pas',
  Test.UniBase.FormState in 'Test.UniBase.FormState.pas',
  Test.UniBase.Logging in 'Test.UniBase.Logging.pas',
  Test.UniBase.MRU in 'Test.UniBase.MRU.pas',
  Test.UniBase.Hotkeys in 'Test.UniBase.Hotkeys.pas',
  Test.UniBase.Theme in 'Test.UniBase.Theme.pas',
  Test.UniBase.License in 'Test.UniBase.License.pas',
  Test.UniBase.Updater in 'Test.UniBase.Updater.pas',
  Test.UniBase.Unlock in 'Test.UniBase.Unlock.pas',
  // MAINT: Core infra tests
  Test.UniBase.Consts in 'Test.UniBase.Consts.pas',
  Test.UniBase.DBException in 'Test.UniBase.DBException.pas',
  Test.UniBase.SQLLogger in 'Test.UniBase.SQLLogger.pas',
  Test.UniBase.Protection in 'Test.UniBase.Protection.pas',
  // LLM & Crypto tests
  Test.UniBase.Crypto in 'Test.UniBase.Crypto.pas',
  Test.UniBase.LLM in 'Test.UniBase.LLM.pas',
  Test.UniBase.Crypto.OpenSSL in 'Test.UniBase.Crypto.OpenSSL.pas',
  // Payment & Social tests
  Test.UniBase.Payment in 'Test.UniBase.Payment.pas',
  Test.UniBase.Social in 'Test.UniBase.Social.pas',
  // Types tests
  Test.UniBase.Types in 'Test.UniBase.Types.pas',
  // GUI Test helper
  Test.UniBase.TestHelper in 'Test.UniBase.TestHelper.pas',
  // Core units
  UniBase.Types in '..\Core\UniBase.Types.pas',
  UniBase.Manager in '..\Core\UniBase.Manager.pas',
  UniBase.Unlock in '..\Core\UniBase.Unlock.pas',
  UniBase.Config in '..\Core\UniBase.Config.pas',
  UniBase.i18n in '..\Core\UniBase.i18n.pas',
  UniBase.FormState in '..\Core\UniBase.FormState.pas',
  UniBase.Logging in '..\Core\UniBase.Logging.pas',
  UniBase.MRU in '..\Core\UniBase.MRU.pas',
  UniBase.Hotkeys in '..\Core\UniBase.Hotkeys.pas',
  UniBase.Theme in '..\Core\UniBase.Theme.pas',
  UniBase.License in '..\Core\UniBase.License.pas',
  // DoQry 集成模块（在单独的测试工程中覆盖，这里不包含以避免 DBClient 依赖问题）
  UniBase.DB.DoQry in '..\Core\UniBase.DB.DoQry.pas',
  // LLM unit for LLM tests
  UniBase.LLM in '..\Core\UniBase.LLM.pas',
  // Payment & Social integration units
  UniBase.Payment in '..\ThirdParty\Payment\UniBase.Payment.pas',
  UniBase.Social in '..\ThirdParty\Social\UniBase.Social.pas';

{$IFNDEF TESTINSIGHT}
var
  Runner: ITestRunner;
  Results: IRunResults;
  Logger: ITestLogger;
  NUnitLogger: ITestLogger;
{$ENDIF}

begin
  ReportMemoryLeaksOnShutdown := True;

  {$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
  {$ELSE}
  try
    // 检查是否有命令行参数
    TDUnitX.CheckCommandLine;

    // 创建测试运行器
    Runner := TDUnitX.CreateRunner;
    Runner.UseRTTI := True;
    Runner.FailsOnNoAsserts := False;

    // 添加控制台日志记录器
    Logger := TDUnitXConsoleLogger.Create(True);
    Runner.AddLogger(Logger);

    // 添加 NUnit XML 日志记录器（用于 CI）
    if TDUnitX.Options.XMLOutputFile <> '' then
    begin
      NUnitLogger := TDUnitXXMLNUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile);
      Runner.AddLogger(NUnitLogger);
    end;

    // 运行测试
    Results := Runner.Execute;

    // 如果不是从 IDE 运行，等待用户输入
    {$IFNDEF CI}
    if TDUnitX.Options.ExitBehavior <> TDUnitXExitBehavior.Continue then
    begin
      System.Write('按回车键退出...');
      System.Readln;
    end;
    {$ENDIF}

    // 根据测试结果设置退出码
    if not Results.AllPassed then
      System.ExitCode := 1;

  except
    on E: Exception do
    begin
      System.Writeln(E.ClassName, ': ', E.Message);
      System.ExitCode := 2;
    end;
  end;
  {$ENDIF}
end.
