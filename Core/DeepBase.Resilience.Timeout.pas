{ ============================================================================
  DeepBase.Resilience.Timeout - Timeout resilience policy
  Split from DeepBase.Resilience; use DeepBase.Resilience for compatibility.
  ============================================================================ }

unit DeepBase.Resilience.Timeout;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Threading;

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

  // ============================================================================
  // Ref-counted Lock to eliminate UAF on timeout path (Top20 #19 / E6)
  // ============================================================================
  ITimeoutLock = interface
    ['{D7A8B9C0-E1F2-4A3B-8C9D-0E1F2A3B4C5D}']
    procedure Enter;
    procedure Leave;
  end;

  TTimeoutLock = class(TInterfacedObject, ITimeoutLock)
  private
    FLock: TCriticalSection;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Enter;
    procedure Leave;
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


constructor TTimeoutLock.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
end;

destructor TTimeoutLock.Destroy;
begin
  FreeAndNil(FLock);
  inherited;
end;

procedure TTimeoutLock.Enter;
begin
  FLock.Enter;
end;

procedure TTimeoutLock.Leave;
begin
  FLock.Leave;
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
  TaskProc: TProc;
  Task: ITask;
  Completed: Boolean;
  ErrorClass: ExceptClass;
  ErrorMsg: string;
  Lock: ITimeoutLock;
begin
  ErrorClass := nil;
  ErrorMsg := '';
  // Top20 #19 / E6: 使用引用计数托管锁，即使超时退出宿主栈帧，后台任务仍持有锁引用，彻底杜绝 UAF
  Lock := TTimeoutLock.Create;
  TaskProc := Proc;
  Task := TTask.Run(
    procedure
    begin
      try
        TaskProc();
      except
        on E: Exception do
        begin
          Lock.Enter;
          try
            ErrorClass := ExceptClass(E.ClassType);
            ErrorMsg := E.Message;
          finally
            Lock.Leave;
          end;
        end;
      end;
    end);

  Completed := Task.Wait(FTimeoutMs);

  if not Completed then
  begin
    Task.Cancel;  // Cancel background task to prevent resource leaks
    if Assigned(FOnTimeout) then
      FOnTimeout(FTimeoutMs);
    raise ETimeoutException.Create(FTimeoutMs);
  end;

  Lock.Enter;
  try
    if Assigned(ErrorClass) then
      raise ErrorClass.Create(ErrorMsg);
  finally
    Lock.Leave;
  end;
end;

function TTimeoutPolicy.Execute<T>(Func: TFunc<T>): T;
var
  TaskFunc: TFunc<T>;
  Task: ITask;
  TaskResult: T;
  Completed: Boolean;
  ErrorClass: ExceptClass;
  ErrorMsg: string;
  Lock: ITimeoutLock;
begin
  ErrorClass := nil;
  ErrorMsg := '';
  // Top20 #19 / E6: 引用计数锁跨线程生命周期托管
  Lock := TTimeoutLock.Create;
  TaskFunc := Func;
  Task := TTask.Run(
    procedure
    begin
      try
        var LResult := TaskFunc();
        Lock.Enter;
        try
          TaskResult := LResult;
        finally
          Lock.Leave;
        end;
      except
        on E: Exception do
        begin
          Lock.Enter;
          try
            ErrorClass := ExceptClass(E.ClassType);
            ErrorMsg := E.Message;
          finally
            Lock.Leave;
          end;
        end;
      end;
    end);

  Completed := Task.Wait(FTimeoutMs);

  if not Completed then
  begin
    Task.Cancel;
    if Assigned(FOnTimeout) then
      FOnTimeout(FTimeoutMs);
    raise ETimeoutException.Create(FTimeoutMs);
  end;

  Lock.Enter;
  try
    if Assigned(ErrorClass) then
      raise ErrorClass.Create(ErrorMsg);
    Result := TaskResult;
  finally
    Lock.Leave;
  end;
end;

end.
