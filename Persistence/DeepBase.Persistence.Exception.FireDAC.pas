{ ============================================================================
  DeepBase.Persistence.Exception.FireDAC - FireDAC adapter for exception reports
  ============================================================================
  Moves ExceptionReports SQL/FireDAC persistence out of Core\DeepBase.Exception.
  ============================================================================ }

unit DeepBase.Persistence.Exception.FireDAC;

interface

uses
  DeepBase.Exception,
  DeepBase.Storage.Interfaces,
  FireDAC.Comp.Client;

function CreateExceptionReportStorage(
  AConnection: TFDConnection): IExceptionReportStorage;
procedure RegisterExceptionReportStorageFactory;

implementation

uses
  System.SysUtils,
  FireDAC.Stan.Param;

type
  TFireDACExceptionReportStorage = class(TInterfacedObject,
    IExceptionReportStorage)
  private
    FConnection: TFDConnection;
  public
    constructor Create(AConnection: TFDConnection);
    procedure WriteReport(const Data: TExceptionReportData);
  end;

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

function CreateExceptionReportStorage(
  AConnection: TFDConnection): IExceptionReportStorage;
begin
  Result := TFireDACExceptionReportStorage.Create(AConnection);
end;

procedure RegisterExceptionReportStorageFactory;
begin
  TDeepBaseExceptionHandler.SetStorageFactory(
    function(AConnection: TObject): IExceptionReportStorage
    var
      FDConnection: TFDConnection;
    begin
      if not (AConnection is TFDConnection) then
        raise EInvalidCast.Create(
          'Expected TFDConnection for ExceptionReport FireDAC storage.');
      FDConnection := TFDConnection(AConnection);
      Result := CreateExceptionReportStorage(FDConnection);
    end);
end;

initialization
  RegisterExceptionReportStorageFactory;

end.
