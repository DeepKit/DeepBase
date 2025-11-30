{ ============================================================================
  UniBase.Exception - 异常处理模块
  
  版本: 0.3
  说明: 全局异常捕获、记录和报告
  ============================================================================ }

unit UniBase.Exception;

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.Forms,
  Vcl.Dialogs,
  Data.DB,
  FireDAC.Comp.Client,
  UniBase.Manager,
  UniBase.Logging,
  UniBase.Types;

type
  TUniBaseExceptionHandler = class
  private
    class var FInstance: TUniBaseExceptionHandler;
    procedure OnException(Sender: TObject; E: Exception);
    procedure LogExceptionToDB(E: Exception);
  public
    class constructor Create;
    class destructor Destroy;
    
    class procedure Install;
  end;

implementation

uses
  System.DateUtils;

{ TUniBaseExceptionHandler }

class constructor TUniBaseExceptionHandler.Create;
begin
  FInstance := TUniBaseExceptionHandler.Create;
end;

class destructor TUniBaseExceptionHandler.Destroy;
begin
  FInstance.Free;
end;

class procedure TUniBaseExceptionHandler.Install;
begin
  Application.OnException := FInstance.OnException;
end;

procedure TUniBaseExceptionHandler.OnException(Sender: TObject; E: Exception);
begin
  // 1. Log to System Logger
  if UniBase.Manager.UniBase.IsInitialized then
  begin
    if UniBase.Manager.UniBase.Logger <> nil then
      UniBase.Manager.UniBase.Logger.LogException(E);
    LogExceptionToDB(E);
  end;
  
  // 2. Show User Dialog
  // In production, maybe show a custom error dialog (P3 task)
  // For now, standard VCL dialog
  if not (E is EAbort) then
    Application.ShowException(E);
end;

procedure TUniBaseExceptionHandler.LogExceptionToDB(E: Exception);
var
  Query: TFDQuery;
begin
  // Save detailed report to ExceptionReports table
  if not UniBase.Manager.UniBase.IsInitialized then Exit;
  
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := UniBase.Manager.UniBase.ConfigDB; // Use main connection for now
      Query.SQL.Text := 
        'INSERT INTO ExceptionReports (ReportTime, ExceptionClass, Message, StackTrace) ' +
        'VALUES (:Time, :Class, :Msg, :Stack)';
        
      Query.ParamByName('Time').AsString := DateToISO8601(Now);
      Query.ParamByName('Class').AsString := E.ClassName;
      Query.ParamByName('Msg').AsString := E.Message;
      
      // StackTrace requires JclDebug or similar. 
      // Standard Delphi Exception has StackTrace property in newer versions if enabled.
      {$IF CompilerVersion >= 33.0} // Rio+
      Query.ParamByName('Stack').AsString := E.StackTrace;
      {$ELSE}
      Query.ParamByName('Stack').AsString := '';
      {$ENDIF}
      
      Query.ExecSQL;
    finally
      Query.Free;
    end;
  except
    // Avoid recursive crash
  end;
end;

end.
