{ ============================================================================
  Test.Regression.BUG007_WhenReadyDeadlock - WhenReady死锁风险回归测试

  BUG-007: 死锁风险 - WhenReady方法
  
  原问�? WhenReady方法中存在潜在死锁，回调函数中再次调用DeepBase功能�?
          可能因为嵌套锁定导致死锁�?
  
  修复方案: 使用TTask.Run异步执行回调，避免嵌套锁定导致死锁�?
  
  修复日期: 2025-12-16
  文件: Core/DeepBase.Manager.pas
  优先�? P0 (Critical)
  分类: Concurrency
  ============================================================================ }

unit Test.Regression.BUG007_WhenReadyDeadlock;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Threading,
  DUnitX.TestFramework,
  Test.Regression.Base;

type
  [TestFixture]
  [Category('Regression')]
  [Category('P0')]
  [Category('Concurrency')]
  TBug007_WhenReadyDeadlockTest = class(TConcurrencyRegressionTestBase)
  protected
    function GetBugNumber: string; override;
    function GetBugDescription: string; override;
    function GetFixDate: string; override;
    function GetPriority: string; override;
    function GetAffectedFile: string; override;
  public
    [Test]
    [Description('验证 WhenReady 回调中调�?DeepBase 功能不会死锁')]
    procedure Test_WhenReady_NestedCall_NoDeadlock;
    
    [Test]
    [Description('验证 WhenReady 在已初始化后立即执行回调')]
    procedure Test_WhenReady_AfterInit_ExecutesImmediately;
    
    [Test]
    [Description('验证多个 WhenReady 回调可以并发执行')]
    procedure Test_WhenReady_MultipleConcurrentCallbacks;
    
    [Test]
    [Description('验证 WhenReady 回调异常不影响其他回�?)]
    procedure Test_WhenReady_ExceptionInCallback_DoesNotBlockOthers;
  end;

implementation

uses
  DeepBase.Manager;

{ TBug007_WhenReadyDeadlockTest }

function TBug007_WhenReadyDeadlockTest.GetBugNumber: string;
begin
  Result := 'BUG-007';
end;

function TBug007_WhenReadyDeadlockTest.GetBugDescription: string;
begin
  Result := '死锁风险 - WhenReady方法';
end;

function TBug007_WhenReadyDeadlockTest.GetFixDate: string;
begin
  Result := '2025-12-16';
end;

function TBug007_WhenReadyDeadlockTest.GetPriority: string;
begin
  Result := 'P0';
end;

function TBug007_WhenReadyDeadlockTest.GetAffectedFile: string;
begin
  Result := 'Core/DeepBase.Manager.pas';
end;

procedure TBug007_WhenReadyDeadlockTest.Test_WhenReady_NestedCall_NoDeadlock;
var
  Manager: TDeepBaseManager;
  CallbackExecuted: Boolean;
  NestedCallSucceeded: Boolean;
  CompletionEvent: TEvent;
begin
  LogTestStart('Test_WhenReady_NestedCall_NoDeadlock');
  
  // 检�?DeepBase 是否已初始化
  if not DeepBase.Manager.DeepBase.IsInitialized then
  begin
    Assert.Pass('DeepBase not initialized, skipping test');
    Exit;
  end;
  
  CallbackExecuted := False;
  NestedCallSucceeded := False;
  CompletionEvent := TEvent.Create(nil, True, False, '');
  
  try
    // 注册一个回调，在回调中再次调用 DeepBase 功能
    DeepBase.Manager.DeepBase.WhenReady(procedure
    begin
      CallbackExecuted := True;
      try
        // 在回调中尝试访问 DeepBase 功能（这在修复前会导致死锁）
        if DeepBase.Manager.DeepBase.IsInitialized then
        begin
          // 尝试读取配置（这会获取锁�?
          var Lang := DeepBase.Manager.DeepBase.CurrentLanguage;
          if Lang <> '' then
            NestedCallSucceeded := True;
        end;
      finally
        CompletionEvent.SetEvent;
      end;
    end);
    
    // 等待回调完成（设置超时以检测死锁）
    case CompletionEvent.WaitFor(5000) of
      wrSignaled:
        begin
          Assert.IsTrue(CallbackExecuted, '回调应该被执�?);
          Assert.IsTrue(NestedCallSucceeded, '嵌套调用应该成功');
        end;
      wrTimeout:
        Assert.Fail('检测到死锁：WhenReady 回调�?5 秒内未完�?);
    else
      Assert.Fail('等待回调时发生错�?);
    end;
  finally
    CompletionEvent.Free;
  end;
  
  LogTestEnd('Test_WhenReady_NestedCall_NoDeadlock', True);
end;

procedure TBug007_WhenReadyDeadlockTest.Test_WhenReady_AfterInit_ExecutesImmediately;
var
  CallbackExecuted: Boolean;
  CompletionEvent: TEvent;
begin
  LogTestStart('Test_WhenReady_AfterInit_ExecutesImmediately');
  
  if not DeepBase.Manager.DeepBase.IsInitialized then
  begin
    Assert.Pass('DeepBase not initialized, skipping test');
    Exit;
  end;
  
  CallbackExecuted := False;
  CompletionEvent := TEvent.Create(nil, True, False, '');
  
  try
    // 在已初始化后注册回调
    DeepBase.Manager.DeepBase.WhenReady(procedure
    begin
      CallbackExecuted := True;
      CompletionEvent.SetEvent;
    end);
    
    // 回调应该很快执行（异步但快速）
    case CompletionEvent.WaitFor(2000) of
      wrSignaled:
        Assert.IsTrue(CallbackExecuted, '回调应该被执�?);
      wrTimeout:
        Assert.Fail('回调应该在初始化后快速执�?);
    end;
  finally
    CompletionEvent.Free;
  end;
  
  LogTestEnd('Test_WhenReady_AfterInit_ExecutesImmediately', True);
end;

procedure TBug007_WhenReadyDeadlockTest.Test_WhenReady_MultipleConcurrentCallbacks;
var
  ExecutedCount: Integer;
  Lock: TObject;
  CompletionEvent: TEvent;
  I: Integer;
const
  CALLBACK_COUNT = 10;
begin
  LogTestStart('Test_WhenReady_MultipleConcurrentCallbacks');
  
  if not DeepBase.Manager.DeepBase.IsInitialized then
  begin
    Assert.Pass('DeepBase not initialized, skipping test');
    Exit;
  end;
  
  ExecutedCount := 0;
  Lock := TObject.Create;
  CompletionEvent := TEvent.Create(nil, True, False, '');
  
  try
    // 注册多个回调
    for I := 1 to CALLBACK_COUNT do
    begin
      DeepBase.Manager.DeepBase.WhenReady(procedure
      begin
        TMonitor.Enter(Lock);
        try
          Inc(ExecutedCount);
          if ExecutedCount = CALLBACK_COUNT then
            CompletionEvent.SetEvent;
        finally
          TMonitor.Exit(Lock);
        end;
      end);
    end;
    
    // 等待所有回调完�?
    case CompletionEvent.WaitFor(10000) of
      wrSignaled:
        Assert.AreEqual(CALLBACK_COUNT, ExecutedCount, 
          '所有回调都应该被执�?);
      wrTimeout:
        Assert.Fail(Format('只有 %d/%d 个回调被执行', [ExecutedCount, CALLBACK_COUNT]));
    end;
  finally
    CompletionEvent.Free;
    Lock.Free;
  end;
  
  LogTestEnd('Test_WhenReady_MultipleConcurrentCallbacks', True);
end;

procedure TBug007_WhenReadyDeadlockTest.Test_WhenReady_ExceptionInCallback_DoesNotBlockOthers;
var
  FirstCallbackExecuted: Boolean;
  SecondCallbackExecuted: Boolean;
  CompletionEvent: TEvent;
begin
  LogTestStart('Test_WhenReady_ExceptionInCallback_DoesNotBlockOthers');
  
  if not DeepBase.Manager.DeepBase.IsInitialized then
  begin
    Assert.Pass('DeepBase not initialized, skipping test');
    Exit;
  end;
  
  FirstCallbackExecuted := False;
  SecondCallbackExecuted := False;
  CompletionEvent := TEvent.Create(nil, True, False, '');
  
  try
    // 注册一个会抛出异常的回�?
    DeepBase.Manager.DeepBase.WhenReady(procedure
    begin
      FirstCallbackExecuted := True;
      raise Exception.Create('Test exception');
    end);
    
    // 注册另一个正常的回调
    DeepBase.Manager.DeepBase.WhenReady(procedure
    begin
      SecondCallbackExecuted := True;
      CompletionEvent.SetEvent;
    end);
    
    // 等待第二个回调完�?
    case CompletionEvent.WaitFor(5000) of
      wrSignaled:
        begin
          Assert.IsTrue(FirstCallbackExecuted, '第一个回调应该被执行');
          Assert.IsTrue(SecondCallbackExecuted, '第二个回调应该被执行（不受第一个异常影响）');
        end;
      wrTimeout:
        Assert.Fail('第一个回调的异常不应该阻止其他回调执�?);
    end;
  finally
    CompletionEvent.Free;
  end;
  
  LogTestEnd('Test_WhenReady_ExceptionInCallback_DoesNotBlockOthers', True);
end;

initialization
  TDUnitX.RegisterTestFixture(TBug007_WhenReadyDeadlockTest);

end.
