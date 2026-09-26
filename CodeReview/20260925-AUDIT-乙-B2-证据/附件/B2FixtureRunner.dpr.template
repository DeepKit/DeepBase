{ B2 fixture 子集真跑 runner 模板（被 b2_run_fixture.sh 实体化到 .tmp 后编译运行）。
  __UNIT__ 由脚本替换为本次要跑的测试单元名。
  为什么需要模板：WO §〇-4 禁止本单改 Tests/DeepBaseTests.dpr 注册（收口归主控），
  但「用例绿」必须真跑；本文件只挂被测单元，且三道 fail-closed 让「0 用例」不算绿。 }
program B2FixtureRunner;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  __UNIT__;

var
  LRunner  : ITestRunner;
  LResults : IRunResults;
  LLogger  : ITestLogger;

begin
  ReportMemoryLeaksOnShutdown := False;
  try
    TDUnitX.CheckCommandLine;

    LRunner := TDUnitX.CreateRunner;
    LRunner.UseRTTI := True;
    // 无断言的用例视作失败：防「跑了一个空用例」冒充覆盖
    LRunner.FailsOnNoAsserts := True;

    LLogger := TDUnitXConsoleLogger.Create(True);
    LRunner.AddLogger(LLogger);

    LResults := LRunner.Execute;
    Writeln(Format('RUNNER_STATS fixtureCount=%d testCount=%d pass=%d failure=%d error=%d ignored=%d',
      [LResults.FixtureCount, LResults.TestCount, LResults.PassCount,
       LResults.FailureCount, LResults.ErrorCount, LResults.IgnoredCount]));

    // fail-closed：0 用例不是「全绿」。假 fixture（登记了从未赋值的变量）正是本批测试的原始缺陷形态。
    if LResults.TestCount = 0 then
    begin
      Writeln('RUNNER_VERDICT: NO_TEST_EXECUTED');
      System.ExitCode := 2;
      Exit;
    end;

    if not LResults.AllPassed then
    begin
      Writeln('RUNNER_VERDICT: FAILED');
      System.ExitCode := 1;
      Exit;
    end;
    Writeln('RUNNER_VERDICT: PASSED');
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      System.ExitCode := 2;
    end;
  end;
end.
