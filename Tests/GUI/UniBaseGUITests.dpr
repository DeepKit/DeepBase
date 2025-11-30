{ ============================================================================
  UniBaseGUITests - UniBase GUI 自动化测试项目
  
  版本: 1.0
  说明: GUI 自动化测试主程序
  
  运行方式:
    UniBaseGUITests.exe           - 运行所有 GUI 测试
    UniBaseGUITests.exe -v        - 详细输出
    UniBaseGUITests.exe -r:HTML   - 生成 HTML 报告
  ============================================================================ }

program UniBaseGUITests;

{$APPTYPE CONSOLE}

// {$R *.res}  // Resource file not required for this project

// Define USE_DUNITX to enable DUnitX support
// {$DEFINE USE_DUNITX}

uses
  System.SysUtils,
  System.IOUtils,
  Vcl.Forms,
{$IFDEF USE_DUNITX}
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  DUnitX.Loggers.XML.NUnit,
  DUnitX.Windows.Console,
{$ENDIF}
  // Core
  UniBase.Manager in '..\..\Core\UniBase.Manager.pas',
  UniBase.Types in '..\..\Core\UniBase.Types.pas',
  UniBase.Config in '..\..\Core\UniBase.Config.pas',
  UniBase.i18n in '..\..\Core\UniBase.i18n.pas',
  UniBase.Logging in '..\..\Core\UniBase.Logging.pas',
  UniBase.FormState in '..\..\Core\UniBase.FormState.pas',
  UniBase.Theme in '..\..\Core\UniBase.Theme.pas',
  UniBase.TestHelper in '..\..\Core\UniBase.TestHelper.pas',
  // VCL Controls
  UniBase.VCL.ConfigControls in '..\..\VCL\UniBase.VCL.ConfigControls.pas',
  UniBase.VCL.I18nControls in '..\..\VCL\UniBase.VCL.I18nControls.pas',
  // GUI Test Framework
  UniBase.GUITest in 'UniBase.GUITest.pas',
  GUITest.FormFactory in 'GUITest.FormFactory.pas',
  // Test Units
  Test.GUI.Core in 'Test.GUI.Core.pas',
  Test.GUI.VCL in 'Test.GUI.VCL.pas';

{$IFDEF USE_DUNITX}
var
  Runner: ITestRunner;
  Results: IRunResults;
  Logger: ITestLogger;
  NUnitLogger: ITestLogger;
  OutputPath: string;
{$ELSE}
var
  OutputPath: string;
{$ENDIF}

begin
  try
    // 初始化 VCL 应用
    Application.Initialize;
    
    // 设置输出路径
    OutputPath := TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), 'TestResults');
    ForceDirectories(OutputPath);
    
{$IFDEF USE_DUNITX}
    // DUnitX mode
    if TDUnitX.RegisteredFixtures.Count = 0 then
    begin
      Writeln('No test fixtures registered!');
      Writeln('');
      Writeln('Available test classes:');
      Writeln('  - TTestGUICore (basic control tests)');
      Writeln('  - TTestGUIDataEntry (data entry workflow tests)');
      Writeln('  - TTestGUIKeyboard (keyboard interaction tests)');
      Writeln('  - TTestGUIConfigControls (config control tests)');
      Writeln('  - TTestGUII18nControls (i18n control tests)');
      Writeln('  - TTestGUITheme (theme tests)');
    end
    else
    begin
      // 创建测试运行器
      Runner := TDUnitX.CreateRunner;
      Runner.UseRTTI := True;
      
      // 控制台日志
      Logger := TDUnitXConsoleLogger.Create(True);
      Runner.AddLogger(Logger);
      
      // NUnit XML 报告
      NUnitLogger := TDUnitXXMLNUnitFileLogger.Create(
        TPath.Combine(OutputPath, 'gui_test_results.xml'));
      Runner.AddLogger(NUnitLogger);
      
      // 显示标题
      Writeln('');
      Writeln('========================================');
      Writeln('  UniBase GUI Automated Tests');
      Writeln('========================================');
      Writeln('');
      Writeln('Test fixtures: ' + IntToStr(TDUnitX.RegisteredFixtures.Count));
      Writeln('Output path: ' + OutputPath);
      Writeln('');
      Writeln('Starting tests...');
      Writeln('');
      
      // 运行测试
      Results := Runner.Execute;
      
      // 显示摘要
      Writeln('');
      Writeln('========================================');
      Writeln('  Test Summary');
      Writeln('========================================');
      Writeln('');
      Writeln(Format('  Total:    %d', [Results.TestCount]));
      Writeln(Format('  Passed:   %d', [Results.PassCount]));
      Writeln(Format('  Failed:   %d', [Results.FailureCount]));
      Writeln(Format('  Errors:   %d', [Results.ErrorCount]));
      Writeln(Format('  Skipped:  %d', [Results.SkippedCount]));
      Writeln('');
      
      // 设置退出码
      if Results.AllPassed then
      begin
        Writeln('All tests passed!');
        ExitCode := 0;
      end
      else
      begin
        Writeln('Some tests failed!');
        ExitCode := 1;
      end;
    end;
{$ELSE}
    // Standalone mode - just show info
    Writeln('');
    Writeln('========================================');
    Writeln('  UniBase GUI Test Framework');
    Writeln('========================================');
    Writeln('');
    Writeln('This project can be used with DUnitX for automated testing.');
    Writeln('To enable DUnitX support, define USE_DUNITX in project settings.');
    Writeln('');
    Writeln('Available test classes:');
    Writeln('  - TTestGUICore (basic control tests)');
    Writeln('  - TTestGUIDataEntry (data entry workflow tests)');
    Writeln('  - TTestGUIKeyboard (keyboard interaction tests)');
    Writeln('  - TTestGUIConfigControls (config control tests)');
    Writeln('  - TTestGUII18nControls (i18n control tests)');
    Writeln('  - TTestGUITheme (theme tests)');
    Writeln('');
    Writeln('Output path: ' + OutputPath);
    Writeln('');
    ExitCode := 0;
{$ENDIF}
    
    {$IFDEF DEBUG}
    Writeln('');
    Write('Press Enter to exit...');
    Readln;
    {$ENDIF}
    
  except
    on E: Exception do
    begin
      Writeln('ERROR: ' + E.Message);
      ExitCode := 2;
    end;
  end;
end.
