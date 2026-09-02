unit Test.Regression.BUG335_GuardianTransientOpen;

interface

uses
  System.SysUtils,
  System.IOUtils,
  DUnitX.TestFramework,
  Test.Regression.Base,
  FireDAC.Comp.Client,
  DeepBase.DB.Guardian;

type
  [TestFixture]
  [Category('regression')]
  TBUG335_GuardianTransientOpenTest = class(TRegressionTestBase)
  protected
    function GetBugNumber: string; override;
    function GetBugDescription: string; override;
    function GetFixDate: string; override;
    function GetPriority: string; override;
    function GetAffectedFile: string; override;
  public
    [Test]
    procedure Test_TransientOpenFailure_NoQuarantine;

    [Test]
    procedure Test_StructuralOpenFailure_Quarantines;
  end;

implementation

function TBUG335_GuardianTransientOpenTest.GetBugNumber: string;
begin
  Result := 'BUG-335';
end;

function TBUG335_GuardianTransientOpenTest.GetBugDescription: string;
begin
  Result := 'Guardian must not quarantine transient Open failures';
end;

function TBUG335_GuardianTransientOpenTest.GetFixDate: string;
begin
  Result := '2026-09-02';
end;

function TBUG335_GuardianTransientOpenTest.GetPriority: string;
begin
  Result := 'P0';
end;

function TBUG335_GuardianTransientOpenTest.GetAffectedFile: string;
begin
  Result := 'Persistence/DeepBase.DB.Guardian.pas';
end;

procedure TBUG335_GuardianTransientOpenTest.Test_TransientOpenFailure_NoQuarantine;
var
  Conn: TFDConnection;
  GResult: TGuardianResult;
  BadPath: string;
begin
  BadPath := 'X:\DeepBase_Guardian_NoSuchDrive\missing.db';
  Conn := TFDConnection.Create(nil);
  try
    Conn.DriverName := 'SQLite';
    Conn.Params.Database := BadPath;

    Assert.IsFalse(TDBGuardian.ProtectConnection(Conn, GResult));
    Assert.AreEqual(isUnknown, GResult.Status);
    Assert.IsFalse(GResult.RestoredFromBackup);
    Assert.AreEqual('', GResult.QuarantinePath);
  finally
    Conn.Free;
  end;
end;

procedure TBUG335_GuardianTransientOpenTest.Test_StructuralOpenFailure_Quarantines;
var
  Conn: TFDConnection;
  GResult: TGuardianResult;
  DbPath: string;
begin
  DbPath := TPath.Combine(TPath.GetTempPath,
    Format('bug335_corrupt_%d.db', [Random(MaxInt)]));
  TFile.WriteAllBytes(DbPath, TBytes.Create($DE, $AD, $BE, $EF));

  Conn := TFDConnection.Create(nil);
  try
    Conn.DriverName := 'SQLite';
    Conn.Params.Database := DbPath;

    TDBGuardian.ProtectConnection(Conn, GResult);
    Assert.IsTrue(GResult.QuarantinePath <> '',
      'Structural open failure should quarantine corrupt file');
  finally
    Conn.Free;
    if TFile.Exists(DbPath) then
      TFile.Delete(DbPath);
    if (GResult.QuarantinePath <> '') and TFile.Exists(GResult.QuarantinePath) then
      TFile.Delete(GResult.QuarantinePath);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBUG335_GuardianTransientOpenTest);

end.
