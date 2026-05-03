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
  // Persistence tests
  Test.UniBase.DB.Factory in 'Test.UniBase.DB.Factory.pas',
  Test.UniBase.DB.Pool in 'Test.UniBase.DB.Pool.pas',
  Test.UniBase.DB.Migrations in 'Test.UniBase.DB.Migrations.pas',
  // LLM & Crypto tests
  Test.UniBase.Crypto in 'Test.UniBase.Crypto.pas',
  Test.UniBase.LLM in 'Test.UniBase.LLM.pas',
  Test.UniBase.Crypto.OpenSSL in 'Test.UniBase.Crypto.OpenSSL.pas',
  // Payment & Social tests
  Test.UniBase.Payment in 'Test.UniBase.Payment.pas',
  Test.UniBase.Social in 'Test.UniBase.Social.pas',
  // Types tests
  Test.UniBase.Types in 'Test.UniBase.Types.pas',
  Test.UniBase.Serialization in 'Test.UniBase.Serialization.pas',
  // Resilience tests (core module fixed)
  Test.UniBase.Resilience in 'Test.UniBase.Resilience.pas',
  // Additional tests that should compile
  Test.UniBase.DateTime in 'Test.UniBase.DateTime.pas',
  Test.UniBase.Math in 'Test.UniBase.Math.pas',
  Test.UniBase.Memory in 'Test.UniBase.Memory.pas',
  Test.UniBase.ObjectPool in 'Test.UniBase.ObjectPool.pas',
  Test.UniBase.RateLimiter in 'Test.UniBase.RateLimiter.pas',
  Test.UniBase.FeatureFlags in 'Test.UniBase.FeatureFlags.pas',
  Test.UniBase.Metrics in 'Test.UniBase.Metrics.pas',
  Test.UniBase.i18n.Plural in 'Test.UniBase.i18n.Plural.pas',
  Test.UniBase.i18n.Gender in 'Test.UniBase.i18n.Gender.pas',
  Test.UniBase.Compression in 'Test.UniBase.Compression.pas',
  Test.UniBase.Benchmark in 'Test.UniBase.Benchmark.pas',
  Test.UniBase.LockContention in 'Test.UniBase.LockContention.pas',
  Test.UniBase.PerformanceSuite in 'Test.UniBase.PerformanceSuite.pas',
  Test.UniBase.Diagnose in 'Test.UniBase.Diagnose.pas',
  Test.UniBase.Exception in 'Test.UniBase.Exception.pas',
  Test.UniBase.Security in 'Test.UniBase.Security.pas',
  Test.UniBase.Authorization in 'Test.UniBase.Authorization.pas',
  Test.UniBase.Interfaces in 'Test.UniBase.Interfaces.pas',
  // GUI Test helper
  Test.UniBase.TestHelper in 'Test.UniBase.TestHelper.pas',
  // Services module tests (OPT-007)
  Test.UniBase.Services.HealthCheck in 'Test.UniBase.Services.HealthCheck.pas',
  // Core units
  UniBase.Types in '..\Core\UniBase.Types.pas',
  UniBase.Manager in '..\Core\UniBase.Manager.pas',
  UniBase.Unlock in '..\Features\UniBase.Unlock.pas',
  UniBase.Config in '..\Core\UniBase.Config.pas',
  UniBase.i18n in '..\Core\UniBase.i18n.pas',
  UniBase.FormState in '..\Core\UniBase.FormState.pas',
  UniBase.Logging in '..\Core\UniBase.Logging.pas',
  UniBase.MRU in '..\Core\UniBase.MRU.pas',
  UniBase.Hotkeys in '..\Core\UniBase.Hotkeys.pas',
  UniBase.Theme in '..\Core\UniBase.Theme.pas',
  UniBase.License in '..\Core\UniBase.License.pas',
  UniBase.RateLimiter in '..\Core\UniBase.RateLimiter.pas',
  UniBase.FeatureFlags in '..\Core\UniBase.FeatureFlags.pas',
  // DoQry 集成模块（Persistence 包的唯一实现）
  UniBase.DB.DoQry in '..\Persistence\UniBase.DB.DoQry.pas',
  // LLM unit for LLM tests
  UniBase.LLM in '..\Core\UniBase.LLM.pas',
  // Payment & Social integration units
  UniBase.Authorization in '..\Core\UniBase.Authorization.pas',
  UniBase.Interfaces in '..\Core\UniBase.Interfaces.pas',
  UniBase.Payment in '..\ThirdParty\Payment\UniBase.Payment.pas',
  UniBase.Social in '..\ThirdParty\Social\UniBase.Social.pas',
  UniBase.Social.OAuth in '..\ThirdParty\Social\UniBase.Social.OAuth.pas',
  UniBase.Social.WeChat in '..\ThirdParty\Social\UniBase.Social.WeChat.pas',
  UniBase.Social.Weibo in '..\ThirdParty\Social\UniBase.Social.Weibo.pas',
  UniBase.Social.QQ in '..\ThirdParty\Social\UniBase.Social.QQ.pas',
  UniBase.Metrics in '..\Core\UniBase.Metrics.pas',
  UniBase.Compression in '..\Core\UniBase.Compression.pas',
  UniBase.Diagnose in '..\Core\UniBase.Diagnose.pas',
  UniBase.Schema in '..\Core\UniBase.Schema.pas',
  UniBase.Benchmark in '..\Core\UniBase.Benchmark.pas',
  // Cache unit for PerformanceSuite tests
  UniBase.Cache in '..\Core\UniBase.Cache.pas',
  // Security unit for Security tests
  UniBase.Security in '..\Core\UniBase.Security.pas',
  // Services units for HealthCheck tests
  UniBase.Services.HealthCheck in '..\Core\UniBase.Services.HealthCheck.pas',
  // Exception handler unit for Exception tests
  UniBase.Exception in '..\Core\UniBase.Exception.pas',
  // Memory unit for Memory tests
  UniBase.ObjectPool in '..\Core\UniBase.ObjectPool.pas',
  UniBase.Memory in '..\Core\UniBase.Memory.pas';

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
