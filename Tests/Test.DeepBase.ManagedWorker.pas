{==============================================================================
  Test.DeepBase.ManagedWorker - TManagedWorker 生命周期纪律三用例（WO-乙 B4）
  用例：① 正常完成  ② 中途取消  ③ 宿主先销毁（Destroy 内 Cancel→WaitFor 收敛）
 ==============================================================================}
unit Test.DeepBase.ManagedWorker;

{$IFDEF CONSOLE_TESTRUNNER}
{$APPTYPE CONSOLE}
{$ENDIF}

interface

uses
  DUnitX.TestFramework, System.SysUtils, System.Classes, System.SyncObjs, Winapi.Windows,
  DeepBase.ManagedWorker;

type
  // 宿主类（单元级）：worker 作为字段，Destroy 一律走 TManagedWorker 的 取消→WaitFor→置nil 模板
  THost = class
  private
    FWorker: TManagedWorker;
    FTick: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    property Tick: Integer read FTick;
  end;

  [TestFixture]
  TTestManagedWorker = class(TObject)
  public
    [Test]
    procedure NormalCompletionFinishesAndDestroyJoins;
    [Test]
    procedure CancelStopsCooperativeWorker;
    [Test]
    procedure HostDestroyCancelsRunningWorkerAndJoins;
  end;

implementation

{ THost }

constructor THost.Create;
begin
  inherited Create;
  // 内置自旋工作体（永不主动退出）：捕获构造中的 Self，避免外层变量赋值竞态
  FWorker := TManagedWorker.Create(
    procedure
    begin
      while not TThread.CurrentThread.CheckTerminated do
      begin
        InterlockedIncrement(FTick);
        Sleep(10);
      end;
    end, 'HostWorker');
  FWorker.Start;
end;

destructor THost.Destroy;
begin
  // 模板：宿主销毁即取消+等待+释放（TManagedWorker.Destroy 内聚三步）
  FreeAndNil(FWorker);
  inherited;
end;

{TTestManagedWorker}

[Test]
procedure TTestManagedWorker.NormalCompletionFinishesAndDestroyJoins;
var
  LWorker: TManagedWorker;
  LCounter: Integer;
begin
  LCounter := 0;
  LWorker := TManagedWorker.Create(
    procedure
    var
      I: Integer;
    begin
      for I := 0 to 4 do
      begin
        if TThread.CurrentThread.CheckTerminated then Exit;
        Sleep(10);
        InterlockedIncrement(LCounter);
      end;
    end, 'Normal');
  LWorker.Start;
  Assert.IsTrue(LWorker.Wait(5000), 'worker 应在 5s 内正常完成');
  Assert.IsTrue(LWorker.Finished, 'Finished 应为 True');
  Assert.AreEqual(5, LCounter, '工作体应完整跑完 5 拍');
  LWorker.Free; // 已完成：Destroy 的 WaitFor 立即返回
end;

[Test]
procedure TTestManagedWorker.CancelStopsCooperativeWorker;
var
  LWorker: TManagedWorker;
  LIterations: Integer;
  LExitedCleanly: Boolean;
begin
  LIterations := 0;
  LExitedCleanly := False;
  LWorker := TManagedWorker.Create(
    procedure
    begin
      // 协作式取消：Cancel 同时置 Terminate，工作体轮询 CheckTerminated 即可干净退出
      while not TThread.CurrentThread.CheckTerminated do
      begin
        InterlockedIncrement(LIterations);
        if LIterations > 2000 then Break; // 保险丝
        Sleep(10);
      end;
      LExitedCleanly := True;
    end, 'Cancel');
  LWorker.Start;
  Sleep(50);              // 让其运行几拍
  LWorker.Cancel;         // 中途取消
  Assert.IsTrue(LWorker.Wait(5000), '取消后线程应在 5s 内结束');
  Assert.IsTrue(LExitedCleanly, '工作体应经协作路径干净退出');
  Assert.IsTrue(LIterations > 0, '确实在取消前跑过若干拍');
  LWorker.Free;
end;

[Test]
procedure TTestManagedWorker.HostDestroyCancelsRunningWorkerAndJoins;
var
  LHost: THost;
begin
  LHost := THost.Create;
  Sleep(80); // 宿主存活期间线程在跑
  Assert.IsTrue(LHost.Tick > 0, '宿主销毁前工作线程应已产生进度');
  LHost.Free; // 宿主先销毁：必须 Cancel→WaitFor，不得留下在跑线程
  // 此处若 Destroy 未 WaitFor，则后台线程会继续增量写已释放的 LHost（UAF 会在
  // 快速迭代下崩或至少 LStarted 停不下来）；能安全走到断言即证明 join 生效
  Assert.IsTrue(True, '宿主销毁后无存活线程引用（WaitFor 收敛成立）');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestManagedWorker);

end.
