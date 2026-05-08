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
begin
  ErrorClass := nil;
  ErrorMsg := '';
  TaskProc := Proc;
  Task := TTask.Run(
    procedure
    begin
      try
        TaskProc();
      except
        on E: Exception do
        begin
          ErrorClass := ExceptClass(E.ClassType);
          ErrorMsg := E.Message;
        end;
      end;
    end);
  Completed := Task.Wait(FTimeoutMs);

  if not Completed then
  begin
    if Assigned(FOnTimeout) then
      FOnTimeout(FTimeoutMs);
    raise ETimeoutException.Create(FTimeoutMs);
  end;

  if Assigned(ErrorClass) then
    raise ErrorClass.Create(ErrorMsg);
end;

function TTimeoutPolicy.Execute<T>(Func: TFunc<T>): T;
var
  TaskFunc: TFunc<T>;
  Task: ITask;
  TaskResult: T;
  Completed: Boolean;
  ErrorClass: ExceptClass;
  ErrorMsg: string;
begin
  ErrorClass := nil;
  ErrorMsg := '';
  TaskFunc := Func;
  Task := TTask.Run(
    procedure
    begin
      try
        TaskResult := TaskFunc();
      except
        on E: Exception do
        begin
          ErrorClass := ExceptClass(E.ClassType);
          ErrorMsg := E.Message;
        end;
      end;
    end);
  Completed := Task.Wait(FTimeoutMs);

  if not Completed then
  begin
    if Assigned(FOnTimeout) then
      FOnTimeout(FTimeoutMs);
    raise ETimeoutException.Create(FTimeoutMs);
  end;

  if Assigned(ErrorClass) then
    raise ErrorClass.Create(ErrorMsg);

  Result := TaskResult;
end;

end.
