unit Test.Regression.BUG338_DoQryBindTrim;

interface

uses
  System.SysUtils,
  FireDAC.Comp.Client,
  DUnitX.TestFramework,
  Test.Regression.Base,
  DeepBase.DB.DoQry;

type
  [TestFixture]
  [Category('regression')]
  TBUG338_DoQryBindTrimTest = class(TRegressionTestBase)
  private
    FConnection: TFDConnection;
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
    procedure Test_BindJsonParams_PreservesLeadingTrailingSpaces;
  end;

implementation

procedure TBUG338_DoQryBindTrimTest.SetUp;
var
  Q: TFDQuery;
begin
  inherited;
  UniDbInit(ExtractFilePath(ParamStr(0)));
  UniDbSetDirectSQLAllowed(True);

  FConnection := TFDConnection.Create(nil);
  FConnection.DriverName := 'SQLite';
  FConnection.Params.Database := ':memory:';
  FConnection.FormatOptions.StrsTrim := False;
  FConnection.Open;

  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text := 'CREATE TABLE spaced_vals (id INTEGER PRIMARY KEY, val TEXT)';
    Q.ExecSQL;
  finally
    Q.Free;
  end;
end;

procedure TBUG338_DoQryBindTrimTest.TearDown;
begin
  UniDbSetDirectSQLAllowed(False);
  FConnection.Free;
  inherited;
end;

function TBUG338_DoQryBindTrimTest.GetBugNumber: string;
begin
  Result := 'BUG-338';
end;

function TBUG338_DoQryBindTrimTest.GetBugDescription: string;
begin
  Result := 'DoQry BindJsonParams must not Trim string parameter values';
end;

function TBUG338_DoQryBindTrimTest.GetFixDate: string;
begin
  Result := '2026-09-02';
end;

function TBUG338_DoQryBindTrimTest.GetPriority: string;
begin
  Result := 'P1';
end;

function TBUG338_DoQryBindTrimTest.GetAffectedFile: string;
begin
  Result := 'Persistence/DeepBase.DB.DoQry.pas';
end;

procedure TBUG338_DoQryBindTrimTest.Test_BindJsonParams_PreservesLeadingTrailingSpaces;
var
  Ctx: TUniQueryContext;
  Stored: string;
begin
  Ctx := UniDbMakeContext(FConnection, udbSQLite);
  UniDbExec('INSERT INTO spaced_vals (val) VALUES (:val)',
    '{"val": "  abc  "}', Ctx);
  Stored := UniDbScalar(
    'SELECT val FROM spaced_vals ORDER BY id DESC LIMIT 1', '{}', Ctx);
  Assert.AreEqual('  abc  ', Stored,
    'Bound parameter must preserve leading/trailing spaces');
end;

initialization
  TDUnitX.RegisterTestFixture(TBUG338_DoQryBindTrimTest);

end.
