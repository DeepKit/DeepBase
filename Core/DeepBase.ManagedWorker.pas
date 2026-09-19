{==============================================================================
  DeepBase.ManagedWorker - TManagedWorker：后台工作线程生命周期统一纪律组件

  问题（全库审计 T3 / WO-20260919-AUDIT-乙 B4）：同一模式反复出现——
  匿名线程/后台 worker 未 WaitFor 即销毁宿主、FreeOnTerminate 运行中翻转、
  超时抛弃线程造成对象所有权二义。

  纪律：把「取消 → WaitFor → 置 nil」三步封装进组件 Destroy，调用方只暴露
  必要生命周期与 API：
    Create(proc) / Start / Cancel / Wait(ms) / Finished / Evacuate
  - FreeOnTerminate 恒为 False（消灭 RTL 自动释放与外部引用的竞态）；
  - 协作式取消：Cancel 置位 CancelEvent 并 Terminate；工作体用
    CancelEvent.WaitFor(ms) 替代 Sleep 即可协作退出（TThread.CheckTerminated 亦可）；
  - Destroy 若线程未结束：Cancel → WaitFor → 释放，宿主销毁后不可能有线程在跑；
  - Evacuate：超时抛弃场景的唯一合法出口。worker 移交类级隔离区，由看护线程
    在其结束后回收；若永久挂起则对象保持有效（终态一致，无 UAF），进程退出由
    OS 回收——把"运行中翻转 FreeOnTerminate"的竞态转为显式隔离。

  法源：WO-20260919-AUDIT-乙 §B4；H9（质量优先：不留 FreeOnTerminate 兼容开关）。
 ==============================================================================}
unit DeepBase.ManagedWorker;

{$R+.}{$WARNINGS ON}

interface

uses
  System.SysUtils, System.Classes, System.SyncObjs, System.Generics.Collections,
  System.Threading;

type
  /// <summary>单后台工作线程的生命周期管理器：取消→WaitFor→释放 内聚于 Destroy。</summary>
  TManagedWorker = class sealed
  strict private
    type
      /// <summary>内部线程壳：仅承载工作体与完成事件，生命周期恒由 TManagedWorker 管。</summary>
      TCoreThread = class(TThread)
      private
        FProc: TThreadProcedure;
        FOwner: TManagedWorker;
        FDoneEvent: TEvent;
      protected
        procedure Execute; override;
      public
        constructor Create(const AProc: TThreadProcedure; AOwner: TManagedWorker;
          ADoneEvent: TEvent);
      end;

      /// <summary>隔离看护线程：周期性回收已结束的被隔离 worker。</summary>
      TJanitor = class(TThread)
      protected
        procedure Execute; override;
      end;

    class var FQuarantineLock: TCriticalSection;
    class var FQuarantine: TList<TManagedWorker>;
    class var FJanitor: TJanitor;
    class var FJanitorStop: TEvent;

    class procedure EnsureJanitor; static;
    class procedure SweepQuarantine; static;
  strict private
    FThread: TCoreThread;
    FName: string;
    FCancelEvent: TEvent;
    FDoneEvent: TEvent;
    FFinished: Boolean;          // 原子语义：仅由线程尾置 True，外部只读
    FEvacuated: Boolean;         // 仅 FQuarantineLock 内读写
    function GetFinished: Boolean;
  public
    /// <summary>仅供本单元 initialization/finalization 使用：类外无法触达 strict private 类变量，经此收口。</summary>
    class procedure InitQuarantine; static;
    class procedure DoneQuarantine; static;
    /// <summary>创建但不启动。AName 仅用于调试诊断。</summary>
    constructor Create(const AProcedure: TThreadProcedure; const AName: string = '');
    /// <summary>线程未结束则先 Cancel 再 WaitFor（本组件不存在"销毁不等结束"路径）。</summary>
    destructor Destroy; override;
    procedure Start;
    /// <summary>协作式取消：置 CancelEvent + Terminate。不阻塞。</summary>
    procedure Cancel;
    /// <summary>等待结束。返回 True=已结束；False=超时（调用方可 Continue 等待或 Evacuate）。</summary>
    function Wait(ATimeoutMs: Cardinal): Boolean; overload;
    function Wait: Boolean; overload;
    /// <summary>超时抛弃唯一合法出口：移交隔离区，本对象此后不得再被调用方引用。</summary>
    procedure Evacuate;
    /// <summary>协作退出信号：工作体内 CancelEvent.WaitFor(INFINITE/超时) 检测。</summary>
    property CancelEvent: TEvent read FCancelEvent;
    property Finished: Boolean read GetFinished;
    property Name: string read FName;
  end;

implementation

{ TManagedWorker }

class procedure TManagedWorker.InitQuarantine;
begin
  FQuarantineLock := TCriticalSection.Create;
  FQuarantine := TList<TManagedWorker>.Create;
end;

class procedure TManagedWorker.DoneQuarantine;
begin
  // 看护线程本身遵守本组件纪律：停 → WaitFor → 释放；隔离区中仍挂起的
  // worker 不等待（维持终态一致的受控保留，由 OS 于进程退出回收）
  FQuarantineLock.Enter;
  try
    if FJanitor <> nil then
    begin
      FJanitorStop.SetEvent;
      FJanitor.WaitFor;
      FreeAndNil(FJanitor);
    end;
  finally
    FQuarantineLock.Leave;
  end;
  FreeAndNil(FQuarantine);
  FreeAndNil(FJanitorStop);
  FreeAndNil(FQuarantineLock);
end;

class procedure TManagedWorker.EnsureJanitor;
begin
  FQuarantineLock.Enter;
  try
    if FJanitorStop = nil then
      FJanitorStop := TEvent.Create(nil, True, False, '');
    if (FJanitor <> nil) and FJanitor.Finished then
    begin
      // 上一轮隔离已扫完，看护线程自然退出：回收后按需重建（避免重复登记泄漏）
      FJanitor.WaitFor;
      FreeAndNil(FJanitor);
    end;
    if FJanitor = nil then
    begin
      FJanitorStop.ResetEvent;
      FJanitor := TJanitor.Create(False);
    end;
  finally
    FQuarantineLock.Leave;
  end;
end;

class procedure TManagedWorker.SweepQuarantine;
var
  I: Integer;
  W: TManagedWorker;
begin
  FQuarantineLock.Enter;
  try
    if FQuarantine = nil then
      Exit;
    I := 0;
    while I < FQuarantine.Count do
    begin
      W := FQuarantine[I];
      if W.FFinished then
      begin
        // 已结束：线程对象可安全 WaitFor+Free（线程已退出，WaitFor 立即返回）
        FQuarantine.Delete(I);
        if W.FThread <> nil then
        begin
          W.FThread.WaitFor;
          FreeAndNil(W.FThread);
        end;
        W.Free;
      end
      else
        Inc(I);
    end;
  finally
    FQuarantineLock.Leave;
  end;
end;

constructor TManagedWorker.Create(const AProcedure: TThreadProcedure; const AName: string);
begin
  inherited Create;
  FName := AName;
  FCancelEvent := TEvent.Create(nil, True, False, '');
  FDoneEvent := TEvent.Create(nil, True, False, '');
  FThread := TCoreThread.Create(AProcedure, Self, FDoneEvent);
  // FreeOnTerminate 恒 False：生命周期唯一真相源在本组件
end;

destructor TManagedWorker.Destroy;
begin
  if FThread <> nil then
  begin
    if not FFinished then
      Cancel;
    FThread.WaitFor;
    FreeAndNil(FThread);
  end;
  FreeAndNil(FCancelEvent);
  FreeAndNil(FDoneEvent);
  inherited;
end;

function TManagedWorker.GetFinished: Boolean;
begin
  Result := FFinished;
end;

procedure TManagedWorker.Start;
begin
  FThread.Start;
end;

procedure TManagedWorker.Cancel;
begin
  FCancelEvent.SetEvent;
  FThread.Terminate;
end;

function TManagedWorker.Wait(ATimeoutMs: Cardinal): Boolean;
begin
  Result := (FDoneEvent.WaitFor(ATimeoutMs) = wrSignaled);
end;

function TManagedWorker.Wait: Boolean;
begin
  Result := Wait(INFINITE);
end;

procedure TManagedWorker.Evacuate;
begin
  // 隔离决策与清扫互斥：防止 Sweep 并发判定 FFinished 后双道释放；FEvacuated 保证幂等
  FQuarantineLock.Enter;
  try
    if FFinished or FEvacuated then
      Exit; // 已结束：走正常 Free；已隔离：重复 Evacuate 不得二次登记
    FEvacuated := True;
  finally
    FQuarantineLock.Leave;
  end;
  // 取消信号照常发出，让工作体有机会协作退出；对象所有权移交隔离区
  Cancel;
  EnsureJanitor;
  FQuarantineLock.Enter;
  try
    FQuarantine.Add(Self);
  finally
    FQuarantineLock.Leave;
  end;
end;

{ TManagedWorker.TCoreThread }

constructor TManagedWorker.TCoreThread.Create(const AProc: TThreadProcedure;
  AOwner: TManagedWorker; ADoneEvent: TEvent);
begin
  inherited Create(True); // suspended：Start 前一切引用可确定
  FreeOnTerminate := False;
  FProc := AProc;
  FOwner := AOwner;
  FDoneEvent := ADoneEvent;
end;

procedure TManagedWorker.TCoreThread.Execute;
begin
  try
    if Assigned(FProc) then
      FProc();
  finally
    // 顺序契约：先发布 FFinished、后置完成事件（SetEvent 即发布点/内存屏障）。
    // 反序会让 Wait 返回 True 后读 Finished 瞬时为 False（竞态）；
    // Sweep 以 FFinished 为释放凭据，置位时线程体已出 Execute，WaitFor 立即返回。
    FOwner.FFinished := True;
    FDoneEvent.SetEvent;
  end;
end;

{ TManagedWorker.TJanitor }

procedure TManagedWorker.TJanitor.Execute;
begin
  while not Terminated do
  begin
    if TManagedWorker.FJanitorStop.WaitFor(500) = wrSignaled then
      Break;
    TManagedWorker.SweepQuarantine;
  end;
end;

initialization
  TManagedWorker.InitQuarantine;

finalization
  TManagedWorker.DoneQuarantine;

end.
