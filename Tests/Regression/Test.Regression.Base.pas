{ ============================================================================
  Test.Regression.Base - 回归测试基类

  提供所有回归测试的通用基础设施�?
  - 标准化的 Bug 信息获取接口
  - 通用�?SetUp/TearDown 逻辑
  - 测试辅助方法

  使用方法�?
  1. 继承 TRegressionTestBase
  2. 实现 GetBugNumber, GetBugDescription, GetFixDate
  3. 添加具体的测试方�?
  ============================================================================ }

unit Test.Regression.Base;

interface

uses
  System.SysUtils,
  System.Classes,
  DUnitX.TestFramework;

type
  /// <summary>
  /// 回归测试基类
  /// 所有回归测试应继承此类以获得统一的测试基础设施
  /// </summary>
  TRegressionTestBase = class
  private
    FTestStartTime: TDateTime;
  protected
    /// <summary>获取 Bug 编号，如 'BUG-058'</summary>
    function GetBugNumber: string; virtual; abstract;

    /// <summary>获取 Bug 简短描�?/summary>
    function GetBugDescription: string; virtual; abstract;

    /// <summary>获取修复日期，格�?'YYYY-MM-DD'</summary>
    function GetFixDate: string; virtual; abstract;

    /// <summary>获取 Bug 优先级，�?'P0', 'P1'</summary>
    function GetPriority: string; virtual;

    /// <summary>获取受影响的源文件路�?/summary>
    function GetAffectedFile: string; virtual;

    /// <summary>记录测试开始信�?/summary>
    procedure LogTestStart(const TestName: string);

    /// <summary>记录测试结束信息</summary>
    procedure LogTestEnd(const TestName: string; Success: Boolean);

    /// <summary>创建临时测试目录</summary>
    function CreateTempTestDir: string;

    /// <summary>清理临时测试目录</summary>
    procedure CleanupTempTestDir(const DirPath: string);
  public
    [SetUp]
    procedure SetUp; virtual;

    [TearDown]
    procedure TearDown; virtual;

    /// <summary>获取完整�?Bug 信息字符�?/summary>
    function GetBugInfo: string;
  end;

  /// <summary>
  /// 并发回归测试基类
  /// 用于测试并发相关�?Bug 修复
  /// </summary>
  TConcurrencyRegressionTestBase = class(TRegressionTestBase)
  private
    FThreadCount: Integer;
    FIterationCount: Integer;
  protected
    /// <summary>默认线程�?/summary>
    property ThreadCount: Integer read FThreadCount write FThreadCount;

    /// <summary>每个线程的迭代次�?/summary>
    property IterationCount: Integer read FIterationCount write FIterationCount;

    /// <summary>运行并发测试</summary>
    procedure RunConcurrentTest(const TestProc: TProc);

    /// <summary>等待所有线程完�?/summary>
    procedure WaitForThreads(const Threads: array of TThread; TimeoutMs: Integer = 30000);
  public
    [SetUp]
    procedure SetUp; override;
  end;

  /// <summary>
  /// 内存回归测试基类
  /// 用于测试内存泄漏相关�?Bug 修复
  /// </summary>
  TMemoryRegressionTestBase = class(TRegressionTestBase)
  private
    FInitialMemory: Int64;
  protected
    /// <summary>获取当前内存使用�?/summary>
    function GetCurrentMemoryUsage: Int64;

    /// <summary>检查内存泄�?/summary>
    procedure CheckNoMemoryLeak(const OperationName: string; ToleranceBytes: Int64 = 1024);
  public
    [SetUp]
    procedure SetUp; override;

    [TearDown]
    procedure TearDown; override;
  end;

implementation

uses
  System.IOUtils,
  System.DateUtils,
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  Winapi.PsAPI,
  {$ENDIF}
  System.Diagnostics;

{ TRegressionTestBase }

procedure TRegressionTestBase.SetUp;
begin
  FTestStartTime := Now;
end;

procedure TRegressionTestBase.TearDown;
begin
  // 基类清理逻辑
end;

function TRegressionTestBase.GetPriority: string;
begin
  Result := 'P1'; // 默认优先�?
end;

function TRegressionTestBase.GetAffectedFile: string;
begin
  Result := ''; // 子类可覆�?
end;

function TRegressionTestBase.GetBugInfo: string;
begin
  Result := Format('%s: %s (Fixed: %s, Priority: %s)',
    [GetBugNumber, GetBugDescription, GetFixDate, GetPriority]);
end;

procedure TRegressionTestBase.LogTestStart(const TestName: string);
begin
  {$IFDEF DEBUG}
  OutputDebugString(PChar(Format('[Regression] Starting: %s - %s', [GetBugNumber, TestName])));
  {$ENDIF}
end;

procedure TRegressionTestBase.LogTestEnd(const TestName: string; Success: Boolean);
var
  Status: string;
  Duration: Double;
begin
  if Success then
    Status := 'PASSED'
  else
    Status := 'FAILED';

  Duration := MilliSecondSpan(Now, FTestStartTime);

  {$IFDEF DEBUG}
  OutputDebugString(PChar(Format('[Regression] %s: %s - %s (%.2f ms)',
    [Status, GetBugNumber, TestName, Duration])));
  {$ENDIF}
end;

function TRegressionTestBase.CreateTempTestDir: string;
begin
  Result := TPath.Combine(TPath.GetTempPath, 'DeepBaseRegression_' + IntToStr(TThread.GetTickCount));
  if not TDirectory.Exists(Result) then
    TDirectory.CreateDirectory(Result);
end;

procedure TRegressionTestBase.CleanupTempTestDir(const DirPath: string);
begin
  if TDirectory.Exists(DirPath) then
  begin
    try
      TDirectory.Delete(DirPath, True);
    except
      // 忽略清理错误
    end;
  end;
end;

{ TConcurrencyRegressionTestBase }

procedure TConcurrencyRegressionTestBase.SetUp;
begin
  inherited;
  FThreadCount := 10;
  FIterationCount := 100;
end;

procedure TConcurrencyRegressionTestBase.RunConcurrentTest(const TestProc: TProc);
var
  Threads: array of TThread;
  I: Integer;
  ErrorCount: Integer;
  Errors: TStringList;
  Lock: TObject;
begin
  SetLength(Threads, FThreadCount);
  ErrorCount := 0;
  Errors := TStringList.Create;
  Lock := TObject.Create;
  try
    // 创建并启动线�?
    for I := 0 to FThreadCount - 1 do
    begin
      Threads[I] := TThread.CreateAnonymousThread(
        procedure
        var
          J: Integer;
        begin
          for J := 1 to FIterationCount do
          begin
            try
              TestProc;
            except
              on E: Exception do
              begin
                TMonitor.Enter(Lock);
                try
                  Inc(ErrorCount);
                  if Errors.Count < 10 then
                    Errors.Add(E.Message);
                finally
                  TMonitor.Exit(Lock);
                end;
              end;
            end;
          end;
        end);
      Threads[I].FreeOnTerminate := False;
    end;

    // 启动所有线�?
    for I := 0 to FThreadCount - 1 do
      Threads[I].Start;

    // 等待所有线程完�?
    WaitForThreads(Threads);

    // 检查错�?
    Assert.AreEqual(0, ErrorCount,
      Format('并发测试失败，错误数: %d. 错误示例: %s', [ErrorCount, Errors.Text]));
  finally
    for I := 0 to FThreadCount - 1 do
      Threads[I].Free;
    Errors.Free;
    Lock.Free;
  end;
end;

procedure TConcurrencyRegressionTestBase.WaitForThreads(const Threads: array of TThread;
  TimeoutMs: Integer);
var
  I: Integer;
  StartTime: TDateTime;
begin
  StartTime := Now;
  for I := Low(Threads) to High(Threads) do
  begin
    while not Threads[I].Finished do
    begin
      if MilliSecondSpan(Now, StartTime) > TimeoutMs then
        Assert.Fail('线程等待超时');
      Sleep(10);
    end;
  end;
end;

{ TMemoryRegressionTestBase }

procedure TMemoryRegressionTestBase.SetUp;
begin
  inherited;
  FInitialMemory := GetCurrentMemoryUsage;
end;

procedure TMemoryRegressionTestBase.TearDown;
begin
  inherited;
end;

function TMemoryRegressionTestBase.GetCurrentMemoryUsage: Int64;
{$IFDEF MSWINDOWS}
var
  MemCounters: TProcessMemoryCounters;
begin
  MemCounters.cb := SizeOf(MemCounters);
  if GetProcessMemoryInfo(GetCurrentProcess, @MemCounters, SizeOf(MemCounters)) then
    Result := MemCounters.WorkingSetSize
  else
    Result := 0;
end;
{$ELSE}
begin
  Result := 0; // �?Windows 平台暂不支持
end;
{$ENDIF}

procedure TMemoryRegressionTestBase.CheckNoMemoryLeak(const OperationName: string;
  ToleranceBytes: Int64);
var
  CurrentMemory: Int64;
  MemoryDiff: Int64;
begin
  CurrentMemory := GetCurrentMemoryUsage;
  MemoryDiff := CurrentMemory - FInitialMemory;

  if MemoryDiff > ToleranceBytes then
    Assert.Fail(Format('检测到内存泄漏: %s - 增长 %d 字节 (容差: %d)',
      [OperationName, MemoryDiff, ToleranceBytes]));
end;

end.
