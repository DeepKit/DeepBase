unit Test.Regression.BUG347_DoQryConnectionSerialize;

interface

uses
  System.SysUtils,
  System.IOUtils,
  System.Classes,
  System.Threading,
  System.SyncObjs,
  FireDAC.Comp.Client,
  DUnitX.TestFramework,
  Test.Regression.Base,
  DeepBase.DB.DoQry;

type
  [TestFixture]
  [Category('regression')]
  TBUG347_DoQryConnectionSerializeTest = class(TRegressionTestBase)
  protected
    function GetBugNumber: string; override;
    function GetBugDescription: string; override;
    function GetFixDate: string; override;
    function GetPriority: string; override;
    function GetAffectedFile: string; override;
  public
    [Test]
    procedure Test_ConcurrentSameSql_ErrorCountZero;
  end;

implementation

function TBUG347_DoQryConnectionSerializeTest.GetBugNumber: string;
begin
  Result := 'BUG-347';
end;

function TBUG347_DoQryConnectionSerializeTest.GetBugDescription: string;
begin
  Result := 'DoQry must serialize concurrent UniDbSelect on shared WAL connection';
end;

function TBUG347_DoQryConnectionSerializeTest.GetFixDate: string;
begin
  Result := '2026-09-03';
end;

function TBUG347_DoQryConnectionSerializeTest.GetPriority: string;
begin
  Result := 'P1';
end;

function TBUG347_DoQryConnectionSerializeTest.GetAffectedFile: string;
begin
  Result := 'Persistence/DeepBase.DB.DoQry.pas';
end;

procedure TBUG347_DoQryConnectionSerializeTest.Test_ConcurrentSameSql_ErrorCountZero;
const
  CThreadCount = 4;
  CIterations = 10;
  SQL = 'SELECT :val AS v';
var
  DbPath: string;
  Conn: TFDConnection;
  Ctx: TUniQueryContext;
  Tasks: TArray<ITask>;
  StartGate: TCountdownEvent;
  ErrorCount: Integer;
  I: Integer;
begin
  DbPath := TPath.Combine(TPath.GetTempPath,
    Format('bug347_preppool_%d.db', [Random(MaxInt)]));
  if TFile.Exists(DbPath) then
    TFile.Delete(DbPath);

  UniDbInit(ExtractFilePath(ParamStr(0)));
  UniDbClearPreparedStatements;
  UniDbSetPreparedStatementPooling(True);
  UniDbSetDirectSQLAllowed(True);

  Conn := TFDConnection.Create(nil);
  try
    Conn.DriverName := 'SQLite';
    Conn.Params.Database := DbPath;
    Conn.Params.Values['OpenMode'] := 'CreateUTF8';
    Conn.Params.Values['JournalMode'] := 'WAL';
    Conn.Params.Values['BusyTimeout'] := '10000';
    Conn.Open;
    Ctx := UniDbMakeContext(Conn, udbSQLite);

    ErrorCount := 0;
    StartGate := TCountdownEvent.Create(1);
    try
      SetLength(Tasks, CThreadCount);
      for I := 0 to CThreadCount - 1 do
      begin
        var WorkerIndex := I;
        Tasks[I] := TTask.Run(
          procedure
          var
            Data: TFDMemTable;
            Iter: Integer;
            Payload: string;
          begin
            try
              StartGate.WaitFor;
              for Iter := 0 to CIterations - 1 do
              begin
                Payload := Format('{"val":%d}', [WorkerIndex * 100 + Iter]);
                Data := nil;
                try
                  UniDbSelect(SQL, Payload, Data, Ctx);
                finally
                  Data.Free;
                end;
              end;
            except
              TInterlocked.Increment(ErrorCount);
            end;
          end);
      end;

      StartGate.Signal;
      TTask.WaitForAll(Tasks);

      Assert.AreEqual(0, ErrorCount,
        'Concurrent same-SQL UniDbSelect on shared WAL connection must not error');
    finally
      StartGate.Free;
    end;
  finally
    Conn.Free;
    UniDbSetDirectSQLAllowed(False);
    UniDbSetPreparedStatementPooling(False);
    UniDbClearPreparedStatements;
    if TFile.Exists(DbPath) then
      TFile.Delete(DbPath);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBUG347_DoQryConnectionSerializeTest);

end.
