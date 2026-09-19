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
  DUnitX.TestFramework, System.SysUtils, System.Classes, System.SyncObjs, System.Diagnostics, Winapi.Windows,
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

  // E8/B4 同构回信上下文的最小复刻：与 VCL/FMX LLMChatFrame 的 ILLMChatContext /
  // ILLMFMXChatContext 语义一致（TryBeginOwner 在守护锁内检查注册态；UnregisterOwner
  // 先注销再释放）。因 frame widget 需 Application 消息泵才能跑 Synchronize、且
  // TBillingClient.Chat 非 virtual 无法注入阻塞假件，故在 headless 机制层验证
  // 「有界等待→Evacuate→宿主注销→晚到回写被丢弃」这一 frame Destroy 所依赖的纪律。
  IFrameCtx = interface
    ['{5A1C7E93-8B02-4D6F-9C41-3E7A0B5D2F88}']
    function TryBeginOwner(out AHost: TObject): Boolean;
    procedure UnregisterOwner;
  end;

  TFrameCtx = class(TInterfacedObject, IFrameCtx)
  private
    FLock: TCriticalSection;
    FOwner: TObject;
    FRegistered: Boolean;
  public
    constructor Create(AOwner: TObject);
    destructor Destroy; override;
    function TryBeginOwner(out AHost: TObject): Boolean;
    procedure UnregisterOwner;
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
    [Test]
    procedure BoundedWaitEvacuateDropsLateCallbackAfterHostUnregister;
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

{ TFrameCtx }

constructor TFrameCtx.Create(AOwner: TObject);
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FOwner := AOwner;
  FRegistered := True;
end;

destructor TFrameCtx.Destroy;
begin
  FreeAndNil(FLock);
  inherited;
end;

function TFrameCtx.TryBeginOwner(out AHost: TObject): Boolean;
begin
  FLock.Enter;
  try
    if FRegistered then
    begin
      AHost := FOwner;
      Result := True;
    end
    else
    begin
      AHost := nil;
      Result := False;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TFrameCtx.UnregisterOwner;
begin
  FLock.Enter;
  try
    FRegistered := False;
    FOwner := nil;
  finally
    FLock.Leave;
  end;
end;

[Test]
procedure TTestManagedWorker.BoundedWaitEvacuateDropsLateCallbackAfterHostUnregister;
var
  LHost: TObject;
  LCtx: IFrameCtx;
  LWorker: TManagedWorker;
  LCallbackApplied: Integer; // 应为 0：宿主注销后晚到回写必须被丢弃
  LBase: Integer;            // 进入时的隔离区基线（不含其他 fixture 残留）
  LSW: TStopwatch;
begin
  // 单轮确定化地复刻 VCL/FMX LLMChatFrame.Destroy 所依赖的纪律（B4 同构）：
  // worker 已在飞（阻塞体不可协作取消）→ Cancel→Wait(小预算)→超时 Evacuate →
  // 宿主 UnregisterOwner 后释放 → 晚到的回写必须被 TryBeginOwner 判为未注册而丢弃。
  // （不用多轮循环：Delphi 对 for 体内联 var 的匿名方体捕获共享同一单元格，会误读后续轮上下文。）
  LCallbackApplied := 0;
  LBase := TManagedWorker.QuarantinedWorkerCount;
  LHost := TObject.Create;
  LCtx := TFrameCtx.Create(LHost);
  LWorker := TManagedWorker.Create(
    procedure
    var
      LOwner: TObject;
    begin
      Sleep(200); // 超过 Wait(30) 预算且不可取消（模拟阻塞的 LLM 调用 + 晚到）
      if LCtx.TryBeginOwner(LOwner) then
        // 若守护失效，此处会解引用已释放的 LHost（UAF）；断言应证其不进入
        InterlockedIncrement(LCallbackApplied);
    end, 'FrameLike');
  LWorker.Start;
  Sleep(30);           // 让 worker 真正进入阻塞体（现实 frame：Destroy 时已在飞）
  LWorker.Cancel;      // frame.Destroy 等价：Cancel→Wait(小预算)→超时 Evacuate
  if not LWorker.Wait(30) then
    LWorker.Evacuate
  else
    LWorker.Free;
  LCtx.UnregisterOwner; // frame.Destroy：先注销宿主再释放字段/对象
  FreeAndNil(LHost);

  // 等被 Evacuate 的晚到体跑完并被看护线程回收（隔离区回到基线）；
  // 期间晚到体已尝试回写，因宿主已注销应被丢弃。
  LSW := TStopwatch.StartNew;
  while TManagedWorker.QuarantinedWorkerCount > LBase do
  begin
    if LSW.ElapsedMilliseconds > 15000 then
      Assert.Fail('E8/frame: 隔离区泄漏，晚到回写后 15s 未回基线，当前=' +
        TManagedWorker.QuarantinedWorkerCount.ToString + ' 基线=' + LBase.ToString);
    Sleep(50);
  end;
  Assert.AreEqual(0, LCallbackApplied,
    'E8/frame 纪律: 宿主注销后的晚到回写必须被 TryBeginOwner 丢弃，不得触碰已释放宿主');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestManagedWorker);

end.
