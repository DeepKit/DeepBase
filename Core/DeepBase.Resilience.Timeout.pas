{ ============================================================================
  DeepBase.Resilience.Timeout - Timeout resilience policy
  Split from DeepBase.Resilience; use DeepBase.Resilience for compatibility.
  ============================================================================ }

unit DeepBase.Resilience.Timeout;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Threading,
  DeepBase.ManagedWorker;

type
  // ============================================================================
  // Timeout Policy
  // ============================================================================
  
  ETimeoutException = class(Exception)
  private
    FTimeoutMs: Int64;
  public
    constructor Create(ATimeoutMs: Int64);
    property TimeoutMs: Int64 read FTimeoutMs;
  end;
  
  TOnTimeout = reference to procedure(TimeoutMs: Int64);
  
  /// <summary>
  /// Timeout policy - limits execution time
  /// Top20 #19 / E6: 工作体生命周期统一由 TManagedWorker 托管（取消→WaitFor→置 nil，
  /// 超时抛弃走隔离区），宿主只在 Wait 成功后读结果信箱（DoneEvent 即发布/获取屏障），
  /// 不再需要独立的引用计数锁同步线程与宿主栈帧的双生命周期。
  /// </summary>
  TTimeoutPolicy = class
  private
    FTimeoutMs: Int64;
    FOnTimeout: TOnTimeout;
  public
    constructor Create(ATimeoutMs: Int64 = 5000);
    
    // Configuration
    function Timeout(Ms: Int64): TTimeoutPolicy;
    function OnTimeoutEvent(Handler: TOnTimeout): TTimeoutPolicy;
    
    // Execute
    procedure Execute(Proc: TProc); overload;
    function Execute<T>(Func: TFunc<T>): T; overload;
  end;


implementation

// ============================================================================
// ETimeoutException
// ============================================================================

constructor ETimeoutException.Create(ATimeoutMs: Int64);
begin
  inherited CreateFmt('Operation timed out after %d ms', [ATimeoutMs]);
  FTimeoutMs := ATimeoutMs;
end;

// ============================================================================
// TTimeoutPolicy
// ============================================================================

constructor TTimeoutPolicy.Create(ATimeoutMs: Int64);
begin
  inherited Create;
  FTimeoutMs := ATimeoutMs;
end;

function TTimeoutPolicy.Timeout(Ms: Int64): TTimeoutPolicy;
begin
  FTimeoutMs := Ms;
  Result := Self;
end;

function TTimeoutPolicy.OnTimeoutEvent(Handler: TOnTimeout): TTimeoutPolicy;
begin
  FOnTimeout := Handler;
  Result := Self;
end;

procedure TTimeoutPolicy.Execute(Proc: TProc);
var
  Worker: TManagedWorker;
  ExecProc: TProc;
  ErrorClass: ExceptClass;
  ErrorMsg: string;
begin
  ErrorClass := nil;
  ErrorMsg := '';
  ExecProc := Proc;
  Worker := TManagedWorker.Create(
    procedure
    begin
      try
        ExecProc();
      except
        on E: Exception do
        begin
          // 信箱写入先于 DoneEvent 发布；宿主仅在 Wait 成功后读，无并发访问
          ErrorClass := ExceptClass(E.ClassType);
          ErrorMsg := E.Message;
        end;
      end;
    end, 'Resilience.Timeout');
  Worker.Start;
  if not Worker.Wait(FTimeoutMs) then
  begin
    // 超时抛弃唯一合法出口：Evacuate 内部已 Cancel 并把所有权移交隔离区，
    // 看护线程在其结束后 WaitFor+回收；此后不得再引用 Worker。
    // 闭包持有信箱/捕获帧至线程体结束，无 UAF、无孤儿线程泄漏。
    Worker.Evacuate;
    if Assigned(FOnTimeout) then
      FOnTimeout(FTimeoutMs);
    raise ETimeoutException.Create(FTimeoutMs);
  end;
  Worker.Free; // 已结束：Destroy 即时回收（未结束时 Destroy 保证取消→WaitFor→置 nil）
  if Assigned(ErrorClass) then
    raise ErrorClass.Create(ErrorMsg);
end;

function TTimeoutPolicy.Execute<T>(Func: TFunc<T>): T;
var
  Worker: TManagedWorker;
  ExecFunc: TFunc<T>;
  TaskResult: T;
  ErrorClass: ExceptClass;
  ErrorMsg: string;
begin
  TaskResult := Default(T);
  ErrorClass := nil;
  ErrorMsg := '';
  ExecFunc := Func;
  Worker := TManagedWorker.Create(
    procedure
    var
      LValue: T;
    begin
      try
        LValue := ExecFunc();
        TaskResult := LValue; // 同上：宿主只在 Wait 成功后读
      except
        on E: Exception do
        begin
          ErrorClass := ExceptClass(E.ClassType);
          ErrorMsg := E.Message;
        end;
      end;
    end, 'Resilience.Timeout');
  Worker.Start;
  if not Worker.Wait(FTimeoutMs) then
  begin
    Worker.Evacuate;
    if Assigned(FOnTimeout) then
      FOnTimeout(FTimeoutMs);
    raise ETimeoutException.Create(FTimeoutMs);
  end;
  Worker.Free;
  if Assigned(ErrorClass) then
    raise ErrorClass.Create(ErrorMsg);
  Result := TaskResult;
end;

end.
