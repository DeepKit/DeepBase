unit Test.UniBase.Logging;

{*******************************************************************************
  UniBase Logging 模块单元测试
  
  测试内容:
  - Log / LogDebug / LogInfo / LogWarn / LogError
  - LogFmt 格式化
  - 存储模式
  - 日志清理
  - 线程安全
*******************************************************************************}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils, System.Classes, System.Threading, System.SyncObjs,
  UniBase.Types, UniBase.Manager, UniBase.Logging;

type
  [TestFixture]
  TTestUniBaseLogging = class
  private
    FLog: TUniBaseLogging;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_LogInfo_WritesSuccessfully;
    
    [Test]
    procedure Test_LogDebug_WritesSuccessfully;
    
    [Test]
    procedure Test_LogWarn_WritesSuccessfully;
    
    [Test]
    procedure Test_LogError_WritesSuccessfully;
    
    [Test]
    procedure Test_LogFmt_FormatsCorrectly;
    
    [Test]
    procedure Test_Log_WithSource;
    
    [Test]
    procedure Test_GetLogs_ReturnsEntries;
    
    [Test]
    procedure Test_GetLogs_FilterByLevel;
    
    [Test]
    procedure Test_GetLogs_FilterBySource;
    
    [Test]
    procedure Test_ClearOldLogs;
    
    [Test]
    procedure Test_OnLogAdded_Event;
    
    [Test]
    procedure Test_ThreadSafety_ConcurrentWrites;
    
    [Test]
    procedure Test_Performance_BulkWrite;
  end;

implementation

uses
  System.Diagnostics, System.DateUtils;

{ TTestUniBaseLogging }

procedure TTestUniBaseLogging.Setup;
begin
  if not UniBase.Initialized then
    UniBase.Initialize(':memory:');
  
  FLog := UniBase.Log;
end;

procedure TTestUniBaseLogging.TearDown;
begin
  FLog := nil;
end;

procedure TTestUniBaseLogging.Test_LogInfo_WritesSuccessfully;
var
  Msg: string;
  Logs: TArray<TLogEntry>;
begin
  Msg := 'Test info message ' + TGUID.NewGuid.ToString;
  
  FLog.LogInfo(Msg, 'Test');
  FLog.Flush; // 确保写入完成
  
  Logs := FLog.GetLogs(10);
  
  Assert.IsTrue(Length(Logs) > 0, '应该有日志记录');
end;

procedure TTestUniBaseLogging.Test_LogDebug_WritesSuccessfully;
var
  Msg: string;
begin
  Msg := 'Test debug message';
  
  Assert.WillNotRaise(
    procedure
    begin
      FLog.LogDebug(Msg, 'Test');
    end,
    Exception,
    'LogDebug 不应该抛出异常'
  );
end;

procedure TTestUniBaseLogging.Test_LogWarn_WritesSuccessfully;
var
  Msg: string;
begin
  Msg := 'Test warning message';
  
  Assert.WillNotRaise(
    procedure
    begin
      FLog.LogWarn(Msg, 'Test');
    end,
    Exception,
    'LogWarn 不应该抛出异常'
  );
end;

procedure TTestUniBaseLogging.Test_LogError_WritesSuccessfully;
var
  Msg: string;
begin
  Msg := 'Test error message';
  
  Assert.WillNotRaise(
    procedure
    begin
      FLog.LogError(Msg, 'Test');
    end,
    Exception,
    'LogError 不应该抛出异常'
  );
end;

procedure TTestUniBaseLogging.Test_LogFmt_FormatsCorrectly;
var
  Template: string;
begin
  Template := 'User %s logged in from %s';
  
  Assert.WillNotRaise(
    procedure
    begin
      FLog.LogFmt(Template, ['Alice', '192.168.1.1'], llInfo, 'Auth');
    end,
    Exception,
    'LogFmt 不应该抛出异常'
  );
end;

procedure TTestUniBaseLogging.Test_Log_WithSource;
var
  Msg, Source: string;
begin
  Msg := 'Test message with source';
  Source := 'CustomSource';
  
  Assert.WillNotRaise(
    procedure
    begin
      FLog.Log(Msg, llInfo, Source);
    end,
    Exception,
    'Log with source 不应该抛出异常'
  );
end;

procedure TTestUniBaseLogging.Test_GetLogs_ReturnsEntries;
var
  Logs: TArray<TLogEntry>;
  I: Integer;
begin
  // 写入一些日志
  for I := 1 to 5 do
    FLog.LogInfo('Test log ' + IntToStr(I), 'Test');
  
  FLog.Flush;
  
  Logs := FLog.GetLogs(10);
  
  Assert.IsTrue(Length(Logs) >= 5, '应该至少有 5 条日志');
end;

procedure TTestUniBaseLogging.Test_GetLogs_FilterByLevel;
var
  Logs: TArray<TLogEntry>;
  Entry: TLogEntry;
begin
  // 写入不同级别的日志
  FLog.LogDebug('Debug', 'Test');
  FLog.LogInfo('Info', 'Test');
  FLog.LogWarn('Warning', 'Test');
  FLog.LogError('Error', 'Test');
  FLog.Flush;
  
  // 只获取 Warning 级别
  Logs := FLog.GetLogs(100, llWarning, llWarning);
  
  for Entry in Logs do
    Assert.AreEqual(Ord(llWarning), Ord(Entry.Level), '应该只有 Warning 级别');
end;

procedure TTestUniBaseLogging.Test_GetLogs_FilterBySource;
var
  Logs: TArray<TLogEntry>;
  Entry: TLogEntry;
begin
  // 写入不同 Source 的日志
  FLog.LogInfo('From Source1', 'Source1');
  FLog.LogInfo('From Source2', 'Source2');
  FLog.Flush;
  
  // 只获取 Source1
  Logs := FLog.GetLogs(100, llDebug, llError, 'Source1');
  
  for Entry in Logs do
    Assert.AreEqual('Source1', Entry.Source, '应该只有 Source1 的日志');
end;

procedure TTestUniBaseLogging.Test_ClearOldLogs;
begin
  // 写入一些日志
  FLog.LogInfo('Old log', 'Test');
  FLog.Flush;
  
  // 清理 0 天前的日志（应该清理所有）
  Assert.WillNotRaise(
    procedure
    begin
      FLog.ClearOldLogs(0);
    end,
    Exception,
    'ClearOldLogs 不应该抛出异常'
  );
end;

procedure TTestUniBaseLogging.Test_OnLogAdded_Event;
var
  EventFired: Boolean;
  ReceivedEntry: TLogEntry;
begin
  EventFired := False;
  
  FLog.OnLogAdded := 
    procedure(const Entry: TLogEntry)
    begin
      EventFired := True;
      ReceivedEntry := Entry;
    end;
  
  try
    FLog.LogInfo('Event test', 'Test');
    FLog.Flush;
    Sleep(100); // 等待异步处理
    
    Assert.IsTrue(EventFired, 'OnLogAdded 事件应该被触发');
  finally
    FLog.OnLogAdded := nil;
  end;
end;

procedure TTestUniBaseLogging.Test_ThreadSafety_ConcurrentWrites;
var
  Tasks: array[0..9] of ITask;
  I: Integer;
  Errors: Integer;
begin
  Errors := 0;
  
  // 创建 10 个并发任务
  for I := 0 to 9 do
  begin
    Tasks[I] := TTask.Create(
      procedure
      var
        J: Integer;
      begin
        try
          for J := 1 to 100 do
            FLog.LogInfo(Format('Thread log %d', [J]), 'ThreadTest');
        except
          TInterlocked.Increment(Errors);
        end;
      end
    );
  end;
  
  // 启动所有任务
  for I := 0 to 9 do
    Tasks[I].Start;
    
  // 等待所有任务完成
  TTask.WaitForAll(Tasks);
  
  Assert.AreEqual(0, Errors, '并发写入不应该产生错误');
end;

procedure TTestUniBaseLogging.Test_Performance_BulkWrite;
var
  SW: TStopwatch;
  I: Integer;
  Elapsed: Int64;
begin
  SW := TStopwatch.StartNew;
  
  for I := 1 to 10000 do
    FLog.LogInfo(Format('Bulk log %d', [I]), 'PerfTest');
  
  FLog.Flush;
  SW.Stop;
  
  Elapsed := SW.ElapsedMilliseconds;
  
  // 10000 条日志写入应该在 5 秒内完成
  Assert.IsTrue(Elapsed < 5000, 
    Format('性能不佳: 10000 条日志写入耗时 %d ms', [Elapsed]));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestUniBaseLogging);

end.
