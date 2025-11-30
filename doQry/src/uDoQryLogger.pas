unit uDoQryLogger;

interface

uses
  System.SysUtils, System.Classes, System.SyncObjs, System.IOUtils, System.StrUtils,
  uDoQryTypes;

procedure DoQryLoggerInit(const ProjectRoot: string);
procedure DoQryLogEvent(const Level, CorrId, ProcName: string; DBType: TDBType;
  const Kind, SQL, ParamsJson: string; DurationMs: Int64; Rows: Integer; const ErrorMsg: string);

implementation

var
  GLogLock: TCriticalSection;
  GLogFile: string = '';
  GLogMaxSize: Int64 = 10 * 1024 * 1024; // 10MB
  GLogMaxFiles: Integer = 5;

function JsonEscape(const S: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(S) do
    case S[I] of
      '"': Result := Result + '\"';
      '\\': Result := Result + '\\';
      #8: Result := Result + '\\b';
      #9: Result := Result + '\\t';
      #10: Result := Result + '\\n';
      #12: Result := Result + '\\f';
      #13: Result := Result + '\\r';
    else
      Result := Result + S[I];
    end;
end;

procedure RotateLogs;
var
  I: Integer;
  BasePath, Dir: string;
begin
  Dir := TPath.GetDirectoryName(GLogFile);
  BasePath := TPath.GetFileName(GLogFile);
  for I := GLogMaxFiles - 1 downto 1 do
  begin
    if TFile.Exists(TPath.Combine(Dir, BasePath + '.' + I.ToString)) then
      TFile.Move(TPath.Combine(Dir, BasePath + '.' + I.ToString), TPath.Combine(Dir, BasePath + '.' + (I+1).ToString), True);
  end;
  if TFile.Exists(GLogFile) then
    TFile.Move(GLogFile, TPath.Combine(Dir, BasePath + '.1'), True);
end;

procedure EnsureLog;
begin
  if GLogFile = '' then Exit;
  if not TDirectory.Exists(TPath.GetDirectoryName(GLogFile)) then
    TDirectory.CreateDirectory(TPath.GetDirectoryName(GLogFile));
  if TFile.Exists(GLogFile) then
    if TFile.GetSize(GLogFile) > GLogMaxSize then
      RotateLogs;
end;

procedure DoQryLoggerInit(const ProjectRoot: string);
begin
  if GLogLock = nil then
    GLogLock := TCriticalSection.Create;
  GLogFile := TPath.Combine(ProjectRoot, TPath.Combine('logs', 'query.log'));
  EnsureLog;
end;

procedure DoQryLogEvent(const Level, CorrId, ProcName: string; DBType: TDBType;
  const Kind, SQL, ParamsJson: string; DurationMs: Int64; Rows: Integer; const ErrorMsg: string);
var
  Line, DBName: string;
  L: TStringList;
  PJson, EJson: string;
begin
  if GLogLock = nil then Exit;
  case DBType of
    dbPostgreSQL: DBName := 'PostgreSQL';
    dbSQLite: DBName := 'SQLite';
  end;
  PJson := Trim(ParamsJson);
  if PJson = '' then PJson := 'null';
  EJson := Trim(ErrorMsg);
  if EJson = '' then EJson := 'null' else EJson := '"' + JsonEscape(EJson) + '"';
  Line := '{' +
    '"ts":"' + FormatDateTime('yyyy"-"mm"-"dd"T"hh":"nn":"ss.zzz"Z"', Now) + '",' +
    '"level":"' + JsonEscape(Level) + '",' +
    '"corrId":"' + JsonEscape(CorrId) + '",' +
    '"proc":"' + JsonEscape(ProcName) + '",' +
    '"dbType":"' + DBName + '",' +
    '"kind":"' + JsonEscape(Kind) + '",' +
    '"durationMs":' + IntToStr(DurationMs) + ',' +
    '"rows":' + IntToStr(Rows) + ',' +
    '"sql":"' + JsonEscape(SQL) + '",' +
    '"params":' + PJson + ',' +
    '"error":' + EJson +
  '}';

  GLogLock.Acquire;
  try
    EnsureLog;
    TFile.AppendAllText(GLogFile, Line + sLineBreak, TEncoding.UTF8);
  finally
    GLogLock.Release;
  end;
end;

initialization
  GLogLock := nil;

finalization
  FreeAndNil(GLogLock);

end.
