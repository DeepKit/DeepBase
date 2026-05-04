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
  UniBase.Storage.Interfaces;

type
  TUniBaseExceptionHandler = class
  private
    class var FInstance: TUniBaseExceptionHandler;
    class var FConnectionStorageFactory: TFunc<TObject, IExceptionReportStorage>;
    class function CreateStorageFromConnection(
      AConnection: TObject): IExceptionReportStorage; static;
    class function BuildExceptionReportData(
      E: Exception): TExceptionReportData; static;
    procedure OnException(Sender: TObject; E: Exception);
    procedure LogExceptionToDB(E: Exception);
  public
    class constructor Create;
    class destructor Destroy;
    
    class procedure Install;
    class procedure SetStorageFactory(
      const AFactory: TFunc<TObject, IExceptionReportStorage>); static;
  end;

implementation

uses
  System.DateUtils;

type
  TFireDACExceptionReportStorage = class(TInterfacedObject,
    IExceptionReportStorage)
  private
    FConnection: TFDConnection;
  public
    constructor Create(AConnection: TFDConnection);
    procedure WriteReport(const Data: TExceptionReportData);
  end;

{ TFireDACExceptionReportStorage }

constructor TFireDACExceptionReportStorage.Create(AConnection: TFDConnection);
begin
  inherited Create;
  FConnection := AConnection;
end;

procedure TFireDACExceptionReportStorage.WriteReport(
  const Data: TExceptionReportData);
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text :=
      'INSERT INTO ExceptionReports (ReportTime, ExceptionClass, Message, StackTrace) ' +
      'VALUES (:Time, :Class, :Msg, :Stack)';
    Query.ParamByName('Time').AsString := Data.ReportTimeISO;
    Query.ParamByName('Class').AsString := Data.ExceptionClass;
    Query.ParamByName('Msg').AsString := Data.MessageText;
    Query.ParamByName('Stack').AsString := Data.StackTrace;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

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

class procedure TUniBaseExceptionHandler.SetStorageFactory(
  const AFactory: TFunc<TObject, IExceptionReportStorage>);
begin
  FConnectionStorageFactory := AFactory;
end;

class function TUniBaseExceptionHandler.CreateStorageFromConnection(
  AConnection: TObject): IExceptionReportStorage;
begin
  if Assigned(AConnection) and Assigned(FConnectionStorageFactory) then
    Result := FConnectionStorageFactory(AConnection)
  else if AConnection is TFDConnection then
    Result := TFireDACExceptionReportStorage.Create(TFDConnection(AConnection))
  else
    Result := nil;
end;

class function TUniBaseExceptionHandler.BuildExceptionReportData(
  E: Exception): TExceptionReportData;
begin
  Result.ReportTimeISO := DateToISO8601(Now);
  Result.ExceptionClass := E.ClassName;
  Result.MessageText := E.Message;
  {$IF CompilerVersion >= 33.0} // Rio+
  Result.StackTrace := E.StackTrace;
  {$ELSE}
  Result.StackTrace := '';
  {$ENDIF}
end;

procedure TUniBaseExceptionHandler.OnException(Sender: TObject; E: Exception);
begin
  // 1. Log to System Logger
  if UniBase.Manager.UniBase.IsInitialized then
  begin
    if UniBase.Manager.UniBase.Logger <> nil then
      UniBase.Manager.UniBase.Logger.LogException(E);
  end;
  LogExceptionToDB(E);
  
  // 2. Show User Dialog
  // In production, maybe show a custom error dialog (P3 task)
  // For now, standard VCL dialog
  if not (E is EAbort) then
    Application.ShowException(E);
end;

procedure TUniBaseExceptionHandler.LogExceptionToDB(E: Exception);
var
  Storage: IExceptionReportStorage;
  ReportData: TExceptionReportData;
  ConnectionObject: TObject;
begin
  // Save detailed report to ExceptionReports table via injected storage.
  try
    Storage := nil;
    ReportData := BuildExceptionReportData(E);

    // 1) Prefer explicit storage injection (can ignore connection parameter).
    try
      Storage := CreateStorageFromConnection(nil);
    except
      Storage := nil;
    end;

    // 2) Fallback to manager connection when available.
    if not Assigned(Storage) then
    begin
      ConnectionObject := nil;
      if UniBase.Manager.UniBase.IsInitialized then
        ConnectionObject := UniBase.Manager.UniBase.ConfigDB;
      if Assigned(ConnectionObject) then
      begin
        try
          Storage := CreateStorageFromConnection(ConnectionObject);
        except
          Storage := nil;
        end;
      end;
    end;

    if Assigned(Storage) then
      Storage.WriteReport(ReportData);
  except
    // Avoid recursive crash
  end;
end;

end.
