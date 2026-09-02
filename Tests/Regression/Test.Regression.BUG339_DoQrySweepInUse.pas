unit Test.Regression.BUG339_DoQrySweepInUse;

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
  TBUG339_DoQrySweepInUseTest = class(TRegressionTestBase)
  private
    FConnection: TFDConnection;
    FDbPath: string;
  protected
    function GetBugNumber: string; override;
    function GetBugDescription: string; override;
    function GetFixDate: string; override;
    function GetPriority: string; override;
    function GetAffectedFile: string; override;
  public
    [Setup]
    procedure SetUp; override;
    [TearDown]
    procedure TearDown; override;

    [Test]
    procedure Test_SweepDuringConcurrentUse_DoesNotBreakWorkers;
  end;

implementation

procedure TBUG339_DoQrySweepInUseTest.SetUp;
begin
  inherited;
  FDbPath := TPath.Combine(TPath.GetTempPath,
    Format('bug339_preppool_%d.db', [Random(MaxInt)]));
  if TFile.Exists(FDbPath) then
    TFile.Delete(FDbPath);

  UniDbInit(ExtractFilePath(ParamStr(0)));
  UniDbClearPreparedStatements;
  UniDbSetPreparedStatementPooling(True);
  UniDbSetDirectSQLAllowed(True);

  FConnection := TFDConnection.Create(nil);
  FConnection.DriverName := 'SQLite';
  FConnection.Params.Database := FDbPath;
  FConnection.Params.Values['OpenMode'] := 'CreateUTF8';
  FConnection.Params.Values['JournalMode'] := 'WAL';
  FConnection.Params.Values['BusyTimeout'] := '10000';
  FConnection.Open;
end;

procedure TBUG339_DoQrySweepInUseTest.TearDown;
begin
  UniDbSetDirectSQLAllowed(False);
  UniDbSetPreparedStatementPooling(False);
  UniDbClearPreparedStatements;
  FConnection.Free;
  if TFile.Exists(FDbPath) then
    TFile.Delete(FDbPath);
  inherited;
end;

function TBUG339_DoQrySweepInUseTest.GetBugNumber: string;
begin
  Result := 'BUG-339';
end;

function TBUG339_DoQrySweepInUseTest.GetBugDescription: string;
begin
  Result := 'DoQry sweep must skip prepared entries with InUseCount > 0';
end;

function TBUG339_DoQrySweepInUseTest.GetFixDate: string;
begin
  Result := '2026-09-02';
end;

function TBUG339_DoQrySweepInUseTest.GetPriority: string;
begin
  Result := 'P0';
end;

function TBUG339_DoQrySweepInUseTest.GetAffectedFile: string;
begin
  Result := 'Persistence/DeepBase.DB.DoQry.pas';
end;

procedure TBUG339_DoQrySweepInUseTest.Test_SweepDuringConcurrentUse_DoesNotBreakWorkers;
const
  CThreadCount = 6;
  CIterations = 20;
  SQL = 'SELECT :val AS v';
var
  Ctx: TUniQueryContext;
  Tasks: TArray<ITask>;
  StartGate: TCountdownEvent;
  ErrorCount: Integer;
  I: Integer;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite);
  StartGate := TCountdownEvent.Create(1);
  try
    ErrorCount := 0;
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
              Payload := Format('{"val":%d}', [WorkerIndex * 1000 + Iter]);
              Data := nil;
              try
                UniDbSelect(SQL, Payload, Data, Ctx);
              finally
                Data.Free;
              end;
            end;
          except
            on E: Exception do
              TInterlocked.Increment(ErrorCount);
          end;
        end);
    end;

    StartGate.Signal;
    Sleep(10);
    UniDbSweepConnectionFromPool(FConnection);

    for I := 0 to High(Tasks) do
      Tasks[I].Wait;

    Assert.AreEqual(0, ErrorCount,
      'Sweep during concurrent prepared-query use must not corrupt in-flight work');
  finally
    StartGate.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBUG339_DoQrySweepInUseTest);

end.
