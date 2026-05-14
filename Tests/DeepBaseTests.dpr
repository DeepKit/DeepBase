program DeepBaseTests;

{$IFNDEF TESTDeepInsight}
{$APPTYPE CONSOLE}
{$ENDIF}

{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  {$IFDEF TESTDeepInsight}
  TestDeepInsight.DUnitX,
  {$ELSE}
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  {$ENDIF}
  DUnitX.TestFramework,
  // Test units - Phase 0
  Test.DeepBase.Manager in 'Test.DeepBase.Manager.pas',
  // Test units - Phase 0 (more)
  Test.DeepBase.Config in 'Test.DeepBase.Config.pas',
  Test.DeepBase.i18n in 'Test.DeepBase.i18n.pas',
  Test.DeepBase.FormState in 'Test.DeepBase.FormState.pas',
  Test.DeepBase.Logging in 'Test.DeepBase.Logging.pas',
  Test.DeepBase.MRU in 'Test.DeepBase.MRU.pas',
  Test.DeepBase.Hotkeys in 'Test.DeepBase.Hotkeys.pas',
  Test.DeepBase.Theme in 'Test.DeepBase.Theme.pas',
  Test.DeepBase.License in 'Test.DeepBase.License.pas',
  Test.DeepBase.Updater in 'Test.DeepBase.Updater.pas',
  Test.DeepBase.Unlock in 'Test.DeepBase.Unlock.pas',
  // MAINT: Core infra tests
  Test.DeepBase.Consts in 'Test.DeepBase.Consts.pas',
  Test.DeepBase.DBException in 'Test.DeepBase.DBException.pas',
  Test.DeepBase.SQLLogger in 'Test.DeepBase.SQLLogger.pas',
  Test.DeepBase.Protection in 'Test.DeepBase.Protection.pas',
  // Persistence tests
  Test.DeepBase.DB.Factory in 'Test.DeepBase.DB.Factory.pas',
  Test.DeepBase.DB.Pool in 'Test.DeepBase.DB.Pool.pas',
  Test.DeepBase.DB.Migrations in 'Test.DeepBase.DB.Migrations.pas',
  // LLM & Crypto tests
  Test.DeepBase.Crypto in 'Test.DeepBase.Crypto.pas',
  Test.DeepBase.LLM in 'Test.DeepBase.LLM.pas',
  Test.DeepBase.LLM.Manager in 'Test.DeepBase.LLM.Manager.pas',
  Test.DeepBase.IntentClarification in 'Test.DeepBase.IntentClarification.pas',
  Test.DeepBase.IntentClarification.Integration in 'Test.DeepBase.IntentClarification.Integration.pas',
  Test.DeepBase.BrowserAutomation in 'Test.DeepBase.BrowserAutomation.pas',
  Test.DeepBase.Browser.Types in 'Test.DeepBase.Browser.Types.pas',
  Test.DeepBase.Browser.Registry in 'Test.DeepBase.Browser.Registry.pas',
  Test.DeepBase.Browser.Recovery in 'Test.DeepBase.Browser.Recovery.pas',
  Test.DeepBase.Browser.Recovery.Integration in 'Test.DeepBase.Browser.Recovery.Integration.pas',
  Test.DeepBase.Browser.ResponseWaiter in 'Test.DeepBase.Browser.ResponseWaiter.pas',
  Test.DeepBase.Browser.Session in 'Test.DeepBase.Browser.Session.pas',
  Test.DeepBase.Browser.Events in 'Test.DeepBase.Browser.Events.pas',
  Test.DeepBase.Browser.Selectors in 'Test.DeepBase.Browser.Selectors.pas',
  Test.DeepBase.Browser.Selectors.Integration in 'Test.DeepBase.Browser.Selectors.Integration.pas',
  Test.DeepBase.Browser.Async in 'Test.DeepBase.Browser.Async.pas',
  Test.DeepBase.Browser.WindowPool in 'Test.DeepBase.Browser.WindowPool.pas',
  Test.DeepBase.Browser.Vision in 'Test.DeepBase.Browser.Vision.pas',
  Test.DeepBase.Browser.ScriptStore in 'Test.DeepBase.Browser.ScriptStore.pas',
  Test.DeepBase.Browser.CDP in 'Test.DeepBase.Browser.CDP.pas',
  Test.DeepBase.Browser.Service in 'Test.DeepBase.Browser.Service.pas',
  Test.DeepBase.Inference.Types in 'Test.DeepBase.Inference.Types.pas',
  Test.DeepBase.Inference.Runtime in 'Test.DeepBase.Inference.Runtime.pas',
  Test.DeepBase.Inference.Session in 'Test.DeepBase.Inference.Session.pas',
  Test.DeepBase.Inference.Service in 'Test.DeepBase.Inference.Service.pas',
  Test.DeepBase.Inference.IoC in 'Test.DeepBase.Inference.IoC.pas',
  Test.DeepBase.Crypto.OpenSSL in 'Test.DeepBase.Crypto.OpenSSL.pas',
  // Payment & Social tests
  Test.DeepBase.Payment in 'Test.DeepBase.Payment.pas',
  Test.DeepBase.Commerce in 'Test.DeepBase.Commerce.pas',
  Test.DeepBase.Speech in 'Test.DeepBase.Speech.pas',
  Test.DeepBase.Social in 'Test.DeepBase.Social.pas',
  // Types tests
  Test.DeepBase.Types in 'Test.DeepBase.Types.pas',
  Test.DeepBase.Serialization in 'Test.DeepBase.Serialization.pas',
  // Resilience tests (core module fixed)
  Test.DeepBase.Resilience in 'Test.DeepBase.Resilience.pas',
  // Additional tests that should compile
  Test.DeepBase.DateTime in 'Test.DeepBase.DateTime.pas',
  Test.DeepBase.Math in 'Test.DeepBase.Math.pas',
  Test.DeepBase.Memory in 'Test.DeepBase.Memory.pas',
  Test.DeepBase.ObjectPool in 'Test.DeepBase.ObjectPool.pas',
  Test.DeepBase.RateLimiter in 'Test.DeepBase.RateLimiter.pas',
  Test.DeepBase.FeatureFlags in 'Test.DeepBase.FeatureFlags.pas',
  Test.DeepBase.Metrics in 'Test.DeepBase.Metrics.pas',
  Test.DeepBase.i18n.Plural in 'Test.DeepBase.i18n.Plural.pas',
  Test.DeepBase.i18n.Gender in 'Test.DeepBase.i18n.Gender.pas',
  Test.DeepBase.Compression in 'Test.DeepBase.Compression.pas',
  Test.DeepBase.Benchmark in 'Test.DeepBase.Benchmark.pas',
  Test.DeepBase.LockContention in 'Test.DeepBase.LockContention.pas',
  Test.DeepBase.PerformanceSuite in 'Test.DeepBase.PerformanceSuite.pas',
  Test.DeepBase.Diagnose in 'Test.DeepBase.Diagnose.pas',
  Test.DeepBase.Exception in 'Test.DeepBase.Exception.pas',
  Test.DeepBase.Security in 'Test.DeepBase.Security.pas',
  Test.DeepBase.Authorization in 'Test.DeepBase.Authorization.pas',
  Test.DeepBase.Interfaces in 'Test.DeepBase.Interfaces.pas',
  Test.DeepBase.ORM in 'Test.DeepBase.ORM.pas',
  Test.DeepBase.ORM.Mapping in 'Test.DeepBase.ORM.Mapping.pas',
  // GUI Test helper
  Test.DeepBase.TestHelper in 'Test.DeepBase.TestHelper.pas',
  // Services module tests (OPT-007)
  Test.DeepBase.Services.HealthCheck in 'Test.DeepBase.Services.HealthCheck.pas',
  // PKG-001: Previously unregistered test units
  Test.DeepBase.AntiTamper in 'Test.DeepBase.AntiTamper.pas',
  Test.DeepBase.AppLifecycle in 'Test.DeepBase.AppLifecycle.pas',
  Test.DeepBase.AutoUpdate in 'Test.DeepBase.AutoUpdate.pas',
  Test.DeepBase.Cache in 'Test.DeepBase.Cache.pas',
  Test.DeepBase.CloudBackup in 'Test.DeepBase.CloudBackup.pas',
  Test.DeepBase.CloudSync in 'Test.DeepBase.CloudSync.pas',
  Test.DeepBase.Collections in 'Test.DeepBase.Collections.pas',
  Test.DeepBase.Configuration in 'Test.DeepBase.Configuration.pas',
  Test.DeepBase.DataBinding in 'Test.DeepBase.DataBinding.pas',
  Test.DeepBase.DB.AutoRefreshConfig in 'Test.DeepBase.DB.AutoRefreshConfig.pas',
  Test.DeepBase.DB.ConnectionPool in 'Test.DeepBase.DB.ConnectionPool.pas',
  Test.DeepBase.DB.DoQry in 'Test.DeepBase.DB.DoQry.pas',
  Test.DeepBase.DB.JobQueue in 'Test.DeepBase.DB.JobQueue.pas',
  Test.DeepBase.DB.StatusMachine in 'Test.DeepBase.DB.StatusMachine.pas',
  Test.DeepBase.Diff in 'Test.DeepBase.Diff.pas',
  Test.DeepBase.EventBus in 'Test.DeepBase.EventBus.pas',
  Test.DeepBase.Export in 'Test.DeepBase.Export.pas',
  Test.DeepBase.Export.Gen in 'Test.DeepBase.Export.Gen.pas',
  Test.DeepBase.Expression in 'Test.DeepBase.Expression.pas',
  Test.DeepBase.Feedback in 'Test.DeepBase.Feedback.pas',
  Test.DeepBase.FileWatcher in 'Test.DeepBase.FileWatcher.pas',
  Test.DeepBase.Graph in 'Test.DeepBase.Graph.pas',
  Test.DeepBase.HttpServer in 'Test.DeepBase.HttpServer.pas',
  Test.DeepBase.IoC in 'Test.DeepBase.IoC.pas',
  Test.DeepBase.KeyManager in 'Test.DeepBase.KeyManager.pas',
  Test.DeepBase.LLM.BillingClient in 'Test.DeepBase.LLM.BillingClient.pas',
  Test.DeepBase.LLM.ImportExport in 'Test.DeepBase.LLM.ImportExport.pas',
  Test.DeepBase.LLM.PromptTemplate in 'Test.DeepBase.LLM.PromptTemplate.pas',
  Test.DeepBase.LogAggregator in 'Test.DeepBase.LogAggregator.pas',
  Test.DeepBase.MVVM in 'Test.DeepBase.MVVM.pas',
  Test.DeepBase.Net in 'Test.DeepBase.Net.pas',
  Test.DeepBase.Performance in 'Test.DeepBase.Performance.pas',
  Test.DeepBase.Persistence.RuntimeRegistration in 'Test.DeepBase.Persistence.RuntimeRegistration.pas',
  Test.DeepBase.Plugin in 'Test.DeepBase.Plugin.pas',
  Test.DeepBase.PluginManager in 'Test.DeepBase.PluginManager.pas',
  { Test.DeepBase.PublishConfig excluded: depends on Tools/UniPublisher unit Publisher.Config }
  Test.DeepBase.Reflection in 'Test.DeepBase.Reflection.pas',
  Test.DeepBase.RuntimeContext in 'Test.DeepBase.RuntimeContext.pas',
  Test.DeepBase.Scheduler in 'Test.DeepBase.Scheduler.pas',
  Test.DeepBase.Schema in 'Test.DeepBase.Schema.pas',
  Test.DeepBase.Security.DPAPI in 'Test.DeepBase.Security.DPAPI.pas',
  Test.DeepBase.Services.Protection in 'Test.DeepBase.Services.Protection.pas',
  Test.DeepBase.Services.Registration in 'Test.DeepBase.Services.Registration.pas',
  Test.DeepBase.SingleInstance in 'Test.DeepBase.SingleInstance.pas',
  Test.DeepBase.SplashScreen in 'Test.DeepBase.SplashScreen.pas',
  Test.DeepBase.StateMachine in 'Test.DeepBase.StateMachine.pas',
  Test.DeepBase.Template in 'Test.DeepBase.Template.pas',
  Test.DeepBase.Validation in 'Test.DeepBase.Validation.pas',
  Test.DeepBase.VirtualScroll in 'Test.DeepBase.VirtualScroll.pas',
  Test.DeepBase.WorkerQueue in 'Test.DeepBase.WorkerQueue.pas',
  Test.DeepBase.TrayIcon in 'Test.DeepBase.TrayIcon.pas',
  Test.DeepBase.VCL.DeepShell in 'Test.DeepBase.VCL.DeepShell.pas',
  Test.WebService in 'Test.WebService.pas',
  // Core units
  DeepBase.Types in '..\Core\DeepBase.Types.pas',
  DeepBase.Manager in '..\Core\DeepBase.Manager.pas',
  DeepBase.Unlock in '..\Features\DeepBase.Unlock.pas',
  DeepBase.Config in '..\Core\DeepBase.Config.pas',
  DeepBase.IoC in '..\Core\DeepBase.IoC.pas',
  DeepBase.i18n in '..\Core\DeepBase.i18n.pas',
  DeepBase.FormState in '..\Core\DeepBase.FormState.pas',
  DeepBase.Logging in '..\Core\DeepBase.Logging.pas',
  DeepBase.MRU in '..\Core\DeepBase.MRU.pas',
  DeepBase.Hotkeys in '..\Core\DeepBase.Hotkeys.pas',
  DeepBase.Theme in '..\Core\DeepBase.Theme.pas',
  DeepBase.License in '..\Core\DeepBase.License.pas',
  DeepBase.RateLimiter in '..\Core\DeepBase.RateLimiter.pas',
  DeepBase.FeatureFlags in '..\Core\DeepBase.FeatureFlags.pas',
  // DoQry 集成模块（Persistence 包的唯一实现）
  DeepBase.DB.DoQry in '..\Persistence\DeepBase.DB.DoQry.pas',
  DeepBase.Persistence.Manager.FireDAC in '..\Persistence\DeepBase.Persistence.Manager.FireDAC.pas',
  DeepBase.Persistence.License.FireDAC in '..\Persistence\DeepBase.Persistence.License.FireDAC.pas',
  DeepBase.Persistence.Exception.FireDAC in '..\Persistence\DeepBase.Persistence.Exception.FireDAC.pas',
  DeepBase.Persistence.Diagnose.FireDAC in '..\Persistence\DeepBase.Persistence.Diagnose.FireDAC.pas',
  DeepBase.Persistence.ORM.FireDAC in '..\Persistence\DeepBase.Persistence.ORM.FireDAC.pas',
  DeepBase.Persistence.LLM.FireDAC in '..\Persistence\DeepBase.Persistence.LLM.FireDAC.pas',
  DeepBase.Persistence.TestHelper.FireDAC in '..\Persistence\DeepBase.Persistence.TestHelper.FireDAC.pas',
  // LLM unit for LLM tests
  DeepBase.LLM in '..\Core\DeepBase.LLM.pas',
  DeepBase.LLM.Manager in '..\Core\DeepBase.LLM.Manager.pas',
  DeepBase.IntentClarification in '..\Features\DeepBase.IntentClarification.pas',
  DeepBase.IntentClarification.Logging in '..\Features\DeepBase.IntentClarification.Logging.pas',
  DeepBase.IntentClarification.Types in '..\Features\DeepBase.IntentClarification.Types.pas',
  DeepBase.IntentClarification.Interfaces in '..\Features\DeepBase.IntentClarification.Interfaces.pas',
  DeepBase.IntentClarification.Engine in '..\Features\DeepBase.IntentClarification.Engine.pas',
  DeepBase.IntentClarification.IoC in '..\Features\DeepBase.IntentClarification.IoC.pas',
  DeepBase.IntentClarification.Provider.L0 in '..\Features\DeepBase.IntentClarification.Provider.L0.pas',
  DeepBase.IntentClarification.Provider.L1 in '..\Features\DeepBase.IntentClarification.Provider.L1.pas',
  DeepBase.IntentClarification.Provider.L2 in '..\Features\DeepBase.IntentClarification.Provider.L2.pas',
  DeepBase.IntentClarification.Provider.L3 in '..\Features\DeepBase.IntentClarification.Provider.L3.pas',
  DeepBase.IntentClarification.Provider.L4 in '..\Features\DeepBase.IntentClarification.Provider.L4.pas',
  DeepBase.IntentClarification.Session in '..\Features\DeepBase.IntentClarification.Session.pas',
  DeepBase.IntentClarification.SessionFSM in '..\Features\DeepBase.IntentClarification.SessionFSM.pas',
  DeepBase.IntentClarification.Router in '..\Features\DeepBase.IntentClarification.Router.pas',
  DeepBase.IntentClarification.SignalDetector in '..\Features\DeepBase.IntentClarification.SignalDetector.pas',
  DeepBase.IntentClarification.Budget in '..\Features\DeepBase.IntentClarification.Budget.pas',
  DeepBase.IntentClarification.Exit in '..\Features\DeepBase.IntentClarification.Exit.pas',
  DeepBase.IntentClarification.OptionFrame in '..\Features\DeepBase.IntentClarification.OptionFrame.pas',
  DeepBase.IntentClarification.Storage in '..\Features\DeepBase.IntentClarification.Storage.pas',
  DeepBase.IntentClarification.Metrics in '..\Features\DeepBase.IntentClarification.Metrics.pas',
  DeepBase.IntentClarification.FeatureConfig in '..\Features\DeepBase.IntentClarification.FeatureConfig.pas',
  DeepBase.IntentClarification.Templates in '..\Features\DeepBase.IntentClarification.Templates.pas',
  DeepBase.IntentClarification.Validation in '..\Features\DeepBase.IntentClarification.Validation.pas',
  DeepBase.IntentClarification.LLMResilience in '..\Features\DeepBase.IntentClarification.LLMResilience.pas',
  DeepBase.IntentClarification.Anticipation in '..\Features\DeepBase.IntentClarification.Anticipation.pas',
  DeepBase.IntentClarification.Degradation in '..\Features\DeepBase.IntentClarification.Degradation.pas',
  DeepBase.IntentClarification.Moments in '..\Features\DeepBase.IntentClarification.Moments.pas',
  DeepBase.IntentClarification.Rapport in '..\Features\DeepBase.IntentClarification.Rapport.pas',
  DeepBase.IntentClarification.Registration in '..\Features\DeepBase.IntentClarification.Registration.pas',
  DeepBase.BrowserAutomation in '..\Features\DeepBase.BrowserAutomation.pas',
  DeepBase.Browser.Types in '..\Features\DeepBase.Browser.Types.pas',
  DeepBase.Browser.Registry in '..\Features\DeepBase.Browser.Registry.pas',
  DeepBase.Browser.Recovery in '..\Features\DeepBase.Browser.Recovery.pas',
  DeepBase.Browser.ResponseWaiter in '..\Features\DeepBase.Browser.ResponseWaiter.pas',
  DeepBase.Browser.Session in '..\Features\DeepBase.Browser.Session.pas',
  DeepBase.Browser.CDP in '..\Features\DeepBase.Browser.CDP.pas',
  DeepBase.Browser.Service in '..\Features\DeepBase.Browser.Service.pas',
  DeepBase.Browser.Events in '..\Features\DeepBase.Browser.Events.pas',
  DeepBase.Browser.Selectors in '..\Features\DeepBase.Browser.Selectors.pas',
  DeepBase.Browser.WindowPool in '..\Features\DeepBase.Browser.WindowPool.pas',
  DeepBase.Browser.Vision in '..\Features\DeepBase.Browser.Vision.pas',
  DeepBase.Browser.ScriptStore in '..\Features\DeepBase.Browser.ScriptStore.pas',
  DeepBase.Browser.AutomationAdapter in '..\Features\DeepBase.Browser.AutomationAdapter.pas',
  DeepBase.Browser.IoC in '..\Features\DeepBase.Browser.IoC.pas',
  DeepBase.Inference.Types in '..\Features\DeepBase.Inference.Types.pas',
  DeepBase.Inference.Runtime in '..\Features\DeepBase.Inference.Runtime.pas',
  DeepBase.Inference.Session in '..\Features\DeepBase.Inference.Session.pas',
  DeepBase.Inference.Service in '..\Features\DeepBase.Inference.Service.pas',
  DeepBase.Inference.IoC in '..\Features\DeepBase.Inference.IoC.pas',
  // Payment & Social integration units
  DeepBase.Authorization in '..\Core\DeepBase.Authorization.pas',
  DeepBase.Interfaces in '..\Core\DeepBase.Interfaces.pas',
  DeepBase.Payment in '..\ThirdParty\Payment\DeepBase.Payment.pas',
  DeepBase.Commerce.Types in '..\Features\DeepBase.Commerce.Types.pas',
  DeepBase.Commerce.Storage in '..\Features\DeepBase.Commerce.Storage.pas',
  DeepBase.Commerce.Service in '..\Features\DeepBase.Commerce.Service.pas',
  DeepBase.Commerce.Backend.Contract in '..\Features\DeepBase.Commerce.Backend.Contract.pas',
  DeepBase.Commerce.Backend.Http in '..\Features\DeepBase.Commerce.Backend.Http.pas',
  DeepBase.Speech.Types in '..\Features\DeepBase.Speech.Types.pas',
  DeepBase.Speech.VAD in '..\Features\DeepBase.Speech.VAD.pas',
  DeepBase.Speech.Audio.WinMM in '..\Features\DeepBase.Speech.Audio.WinMM.pas',
  DeepBase.Speech.ASR.Baidu in '..\Features\DeepBase.Speech.ASR.Baidu.pas',
  DeepBase.Speech.Service in '..\Features\DeepBase.Speech.Service.pas',
  DeepBase.Social in '..\ThirdParty\Social\DeepBase.Social.pas',
  DeepBase.Social.OAuth in '..\ThirdParty\Social\DeepBase.Social.OAuth.pas',
  DeepBase.Social.WeChat in '..\ThirdParty\Social\DeepBase.Social.WeChat.pas',
  DeepBase.Social.Weibo in '..\ThirdParty\Social\DeepBase.Social.Weibo.pas',
  DeepBase.Social.QQ in '..\ThirdParty\Social\DeepBase.Social.QQ.pas',
  DeepBase.Metrics in '..\Core\DeepBase.Metrics.pas',
  DeepBase.Compression in '..\Core\DeepBase.Compression.pas',
  DeepBase.Diagnose in '..\Core\DeepBase.Diagnose.pas',
  DeepBase.Schema in '..\Core\DeepBase.Schema.pas',
  DeepBase.Benchmark in '..\Core\DeepBase.Benchmark.pas',
  // Cache unit for PerformanceSuite tests
  DeepBase.Cache in '..\Core\DeepBase.Cache.pas',
  // Security unit for Security tests
  DeepBase.Security in '..\Core\DeepBase.Security.pas',
  // Services units for HealthCheck tests
  DeepBase.Services.HealthCheck in '..\Core\DeepBase.Services.HealthCheck.pas',
  // Exception handler unit for Exception tests
  DeepBase.Exception in '..\Core\DeepBase.Exception.pas',
  DeepBase.VCL.ExceptionAdapter in '..\VCL\DeepBase.VCL.ExceptionAdapter.pas',
  // Memory unit for Memory tests
  DeepBase.ObjectPool in '..\Core\DeepBase.ObjectPool.pas',
  DeepBase.Memory in '..\Core\DeepBase.Memory.pas',
  // TrayIcon unit for TrayIcon tests
  DeepBase.TrayIcon in '..\Core\DeepBase.TrayIcon.pas',
  // WebService units
  DeepBase.WebAPI.Core in '..\Tools\WebService\DeepBase.WebAPI.Core.pas',
  DeepBase.WebAPI.Auth in '..\Tools\WebService\DeepBase.WebAPI.Auth.pas',
  DeepBase.WebAPI.WebSocket in '..\Tools\WebService\DeepBase.WebAPI.WebSocket.pas',
  DeepBase.WebAPI.OpenAPI in '..\Tools\WebService\DeepBase.WebAPI.OpenAPI.pas';

{$IFNDEF TESTDeepInsight}
var
  Runner: ITestRunner;
  Results: IRunResults;
  Logger: ITestLogger;
  NUnitLogger: ITestLogger;
{$ENDIF}

begin
  ReportMemoryLeaksOnShutdown := True;

  {$IFDEF TESTDeepInsight}
  TestDeepInsight.DUnitX.RunRegisteredTests;
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
      System.Write('按回车键退出..');
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
