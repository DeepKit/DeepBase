unit LogAnalyzer.Data;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.DateUtils,
  FireDAC.Comp.Client;

type
  TLogLevel = (llTrace, llDebug, llInfo, llWarn, llError, llFatal);
  TLogLevels = set of TLogLevel;

  TLogEntry = record
    Id: Int64;
    Timestamp: TDateTime;
    Level: TLogLevel;
    Source: string;
    Message: string;
    Details: string;
  end;

  TLogQuery = record
    FromTime: TDateTime;
    ToTime: TDateTime;
    Levels: TLogLevels;
    SourceKeyword: string;
    MessageKeyword: string;
    class function DefaultLast24Hours: TLogQuery; static;
  end;

  ILogSource = interface
    ['{C1E88F0E-3BB8-4B5D-9C2A-2E0A6D9C27AA}']
    function LoadLogs(const AQuery: TLogQuery): TArray<TLogEntry>;
  end;

  /// <summary>
  /// Log source implementation based on a FireDAC connection to the UniBase Logs table.
  /// </summary>
  TDbLogSource = class(TInterfacedObject, ILogSource)
  private
    FConnection: TFDConnection;
    function MapLevel(const ALevel: Integer): TLogLevel;
  public
    constructor Create(AConnection: TFDConnection);
    function LoadLogs(const AQuery: TLogQuery): TArray<TLogEntry>;
    property Connection: TFDConnection read FConnection;
  end;

implementation

{ TLogQuery }

class function TLogQuery.DefaultLast24Hours: TLogQuery;
var
  NowTime: TDateTime;
begin
  NowTime := Now;
  Result.ToTime := NowTime;
  Result.FromTime := IncHour(NowTime, -24);
  Result.Levels := [llInfo, llWarn, llError, llFatal];
  Result.SourceKeyword := '';
  Result.MessageKeyword := '';
end;

{ TDbLogSource }

constructor TDbLogSource.Create(AConnection: TFDConnection);
begin
  inherited Create;
  FConnection := AConnection;
end;

function TDbLogSource.MapLevel(const ALevel: Integer): TLogLevel;
begin
  // Map integer levels from Logs.Level to TLogLevel.
  case ALevel of
    0: Result := llTrace;
    1: Result := llDebug;
    2: Result := llInfo;
    3: Result := llWarn;
    4: Result := llError;
    5: Result := llFatal;
  else
    Result := llInfo;
  end;
end;

function TDbLogSource.LoadLogs(const AQuery: TLogQuery): TArray<TLogEntry>;
var
  Q: TFDQuery;
  List: TList<TLogEntry>;
  E: TLogEntry;
begin
  if FConnection = nil then
    raise Exception.Create('TDbLogSource requires a valid FireDAC connection');

  List := TList<TLogEntry>.Create;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'SELECT Id, CreatedAt, Level, Source, Message, Details ' +
      'FROM Logs ' +
      'WHERE CreatedAt BETWEEN :FromTime AND :ToTime ' +
      '  AND (:Source = '''' OR Source LIKE :SourceLike) ' +
      '  AND (:Msg = '''' OR Message LIKE :MsgLike) ' +
      'ORDER BY CreatedAt DESC ' +
      'LIMIT 1000';

    Q.ParamByName('FromTime').AsDateTime := AQuery.FromTime;
    Q.ParamByName('ToTime').AsDateTime := AQuery.ToTime;
    Q.ParamByName('Source').AsString := AQuery.SourceKeyword;
    Q.ParamByName('SourceLike').AsString := '%' + AQuery.SourceKeyword + '%';
    Q.ParamByName('Msg').AsString := AQuery.MessageKeyword;
    Q.ParamByName('MsgLike').AsString := '%' + AQuery.MessageKeyword + '%';

    Q.Open;
    while not Q.Eof do
    begin
      E.Id        := Q.FieldByName('Id').AsLargeInt;
      E.Timestamp := Q.FieldByName('CreatedAt').AsDateTime;
      E.Level     := MapLevel(Q.FieldByName('Level').AsInteger);
      E.Source    := Q.FieldByName('Source').AsString;
      E.Message   := Q.FieldByName('Message').AsString;
      if Q.FindField('Details') <> nil then
        E.Details := Q.FieldByName('Details').AsString
      else
        E.Details := '';

      if (E.Level in AQuery.Levels) then
        List.Add(E);

      Q.Next;
    end;

    Result := List.ToArray;
  finally
    Q.Free;
    List.Free;
  end;
end;

end.
