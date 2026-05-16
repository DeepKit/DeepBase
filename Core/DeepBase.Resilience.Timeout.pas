{ ============================================================================
  DeepBase.Resilience.Timeout - Timeout resilience policy
  Split from DeepBase.Resilience; use DeepBase.Resilience for compatibility.
  ============================================================================ }

unit DeepBase.Resilience.Timeout;

interface

uses
  System.SysUtils,
  System.Classes,
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
  TaskProc: TProc;
  Task: ITask;
  Completed: Boolean;
  ErrorClass: ExceptClass;
  ErrorMsg: string;
  ResultLock: TObject;
begin
  ErrorClass := nil;
  ErrorMsg := '';
  ResultLock := TObject.Create;
  try
    TaskProc := Proc;
    Task := TTask.Run(
      procedure
      begin
        try
          TaskProc();
        except
          on E: Exception do
          begin
            TMonitor.Enter(ResultLock);
            try
              ErrorClass := ExceptClass(E.ClassType);
              ErrorMsg := E.Message;
            finally
              TMonitor.Exit(ResultLock);
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

    TMonitor.Enter(ResultLock);
    try
      if Assigned(ErrorClass) then
        raise ErrorClass.Create(ErrorMsg);
    finally
      TMonitor.Exit(ResultLock);
    end;
  finally
    ResultLock.Free;
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
  ResultLock: TObject;
begin
  ErrorClass := nil;
  ErrorMsg := '';
  ResultLock := TObject.Create;
  try
    TaskFunc := Func;
    Task := TTask.Run(
      procedure
      begin
        try
          var LResult := TaskFunc();
          TMonitor.Enter(ResultLock);
          try
            TaskResult := LResult;
          finally
            TMonitor.Exit(ResultLock);
          end;
        except
          on E: Exception do
          begin
            TMonitor.Enter(ResultLock);
            try
              ErrorClass := ExceptClass(E.ClassType);
              ErrorMsg := E.Message;
            finally
              TMonitor.Exit(ResultLock);
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

    TMonitor.Enter(ResultLock);
    try
      if Assigned(ErrorClass) then
        raise ErrorClass.Create(ErrorMsg);
      Result := TaskResult;
    finally
      TMonitor.Exit(ResultLock);
    end;
  finally
    ResultLock.Free;
  end;
end;

end.
