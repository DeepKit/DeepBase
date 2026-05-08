{ ============================================================================
  DeepBase.Exception - Exception logging and platform exception dispatch

  Version: 0.5
  Description: Core exception report logging without a direct VCL/FMX dependency.
               UI packages can register adapters for Application.OnException.
               No direct dependency on DeepBase.Manager ¡ª uses registered callbacks.
  ============================================================================ }

unit DeepBase.Exception;

interface

uses
  System.SysUtils,
  System.Classes,
  DeepBase.Logging,
  DeepBase.Storage.Interfaces;

type
  TExceptionInstallProc = reference to procedure;
  TExceptionShowProc = reference to procedure(Sender: TObject; E: Exception);

  TDeepBaseExceptionHandler = class
  private
    class var FInstance: TDeepBaseExceptionHandler;
    class var FConnectionStorageFactory: TFunc<TObject, IExceptionReportStorage>;
    class var FPlatformInstallProc: TExceptionInstallProc;
    class var FPlatformShowProc: TExceptionShowProc;
    class var FIsInitializedProc: TFunc<Boolean>;
    class var FGetLoggerProc: TFunc<TDeepBaseLogger>;
    class var FGetConfigDBProc: TFunc<TObject>;
    class function CreateStorageFromConnection(
      AConnection: TObject): IExceptionReportStorage; static;
    class function BuildExceptionReportData(
      E: Exception): TExceptionReportData; static;
    class procedure LogExceptionToDB(E: Exception); static;
  public
    class constructor Create;
    class destructor Destroy;

    class procedure Install;
    class procedure HandleException(Sender: TObject; E: Exception); static;
    class procedure SetStorageFactory(
      const AFactory: TFunc<TObject, IExceptionReportStorage>); static;
    class procedure SetPlatformAdapter(const AInstallProc: TExceptionInstallProc;
      const AShowProc: TExceptionShowProc); static;
    class procedure SetManagerCallbacks(
      const AIsInitialized: TFunc<Boolean>;
      const AGetLogger: TFunc<TDeepBaseLogger>;
      const AGetConfigDB: TFunc<TObject>); static;
  end;

implementation

uses
  System.DateUtils;

{ TDeepBaseExceptionHandler }

class constructor TDeepBaseExceptionHandler.Create;
begin
  FInstance := TDeepBaseExceptionHandler.Create;
end;

class destructor TDeepBaseExceptionHandler.Destroy;
begin
  FreeAndNil(FInstance);
end;

class procedure TDeepBaseExceptionHandler.Install;
begin
  if Assigned(FPlatformInstallProc) then
    FPlatformInstallProc;
end;

class procedure TDeepBaseExceptionHandler.SetStorageFactory(
  const AFactory: TFunc<TObject, IExceptionReportStorage>);
begin
  FConnectionStorageFactory := AFactory;
end;

class procedure TDeepBaseExceptionHandler.SetPlatformAdapter(
  const AInstallProc: TExceptionInstallProc; const AShowProc: TExceptionShowProc);
begin
  FPlatformInstallProc := AInstallProc;
  FPlatformShowProc := AShowProc;
end;

class procedure TDeepBaseExceptionHandler.SetManagerCallbacks(
  const AIsInitialized: TFunc<Boolean>;
  const AGetLogger: TFunc<TDeepBaseLogger>;
  const AGetConfigDB: TFunc<TObject>);
begin
  FIsInitializedProc := AIsInitialized;
  FGetLoggerProc := AGetLogger;
  FGetConfigDBProc := AGetConfigDB;
end;

class function TDeepBaseExceptionHandler.CreateStorageFromConnection(
  AConnection: TObject): IExceptionReportStorage;
begin
  Result := nil;
  if Assigned(FConnectionStorageFactory) then
    Result := FConnectionStorageFactory(AConnection);
end;

class function TDeepBaseExceptionHandler.BuildExceptionReportData(
  E: Exception): TExceptionReportData;
begin
  Result.ReportTimeISO := DateToISO8601(Now);
  Result.ExceptionClass := E.ClassName;
  Result.MessageText := E.Message;
  {$IF CompilerVersion >= 33.0}
  Result.StackTrace := E.StackTrace;
  {$ELSE}
  Result.StackTrace := '';
  {$ENDIF}
end;

class procedure TDeepBaseExceptionHandler.HandleException(Sender: TObject;
  E: Exception);
var
  IsInit: Boolean;
  Logger: TDeepBaseLogger;
begin
  IsInit := Assigned(FIsInitializedProc) and FIsInitializedProc;

  if IsInit then
  begin
    Logger := nil;
    if Assigned(FGetLoggerProc) then
      Logger := FGetLoggerProc;
    if Assigned(Logger) then
      Logger.LogException(E);
  end;

  LogExceptionToDB(E);

  if Assigned(FPlatformShowProc) then
    FPlatformShowProc(Sender, E);
end;

class procedure TDeepBaseExceptionHandler.LogExceptionToDB(E: Exception);
var
  Storage: IExceptionReportStorage;
  ReportData: TExceptionReportData;
  ConnectionObject: TObject;
begin
  try
    ReportData := BuildExceptionReportData(E);
    Storage := nil;

    if Assigned(FIsInitializedProc) and FIsInitializedProc then
    begin
      ConnectionObject := nil;
      if Assigned(FGetConfigDBProc) then
        ConnectionObject := FGetConfigDBProc;
    end
    else
      ConnectionObject := nil;

    if Assigned(FConnectionStorageFactory) then
    begin
      try
        Storage := CreateStorageFromConnection(ConnectionObject);
      except
        Storage := nil;
      end;
    end;

    if Assigned(Storage) then
      Storage.WriteReport(ReportData);
  except
    // Avoid recursive exception reporting.
  end;
end;

end.
