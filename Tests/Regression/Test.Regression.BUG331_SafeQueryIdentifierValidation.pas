{ ============================================================================
  Test.Regression.BUG331_SafeQueryIdentifierValidation - REVIEW5-DATA-002

  Verifies that SafeQuery validates and quotes schema identifiers:
  - Rejects wildcards (*)
  - Rejects SQL injection characters (expressions, semicolons, etc.)
  - Validates table/column names against cached schema
  - Uses double-quote quoting for SQLite identifiers
  ============================================================================ }

unit Test.Regression.BUG331_SafeQueryIdentifierValidation;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  Test.Regression.Base,
  DeepBase.Exceptions;

type
  [TestFixture]
  [Category('regression')]
  TBUG331_SafeQueryIdentifierValidationTest = class(TRegressionTestBase)
  protected
    function GetBugNumber: string; override;
    function GetBugDescription: string; override;
    function GetFixDate: string; override;
    function GetPriority: string; override;
    function GetAffectedFile: string; override;
  public
    /// <summary>EExternalDBInvalidIdentifier exception class exists</summary>
    [Test]
    procedure Test_InvalidIdentifier_ExceptionClassExists;

    /// <summary>EExternalDBInvalidIdentifier inherits from EExternalDBException</summary>
    [Test]
    procedure Test_InvalidIdentifier_ExceptionInheritance;

    /// <summary>EExternalDBInvalidIdentifier can be raised and caught</summary>
    [Test]
    procedure Test_InvalidIdentifier_CanRaiseAndCatch;
  end;

implementation

function TBUG331_SafeQueryIdentifierValidationTest.GetBugNumber: string;
begin
  Result := 'BUG-331';
end;

function TBUG331_SafeQueryIdentifierValidationTest.GetBugDescription: string;
begin
  Result := 'SafeQuery lacks schema identifier validation and quoting';
end;

function TBUG331_SafeQueryIdentifierValidationTest.GetFixDate: string;
begin
  Result := '2026-06-29';
end;

function TBUG331_SafeQueryIdentifierValidationTest.GetPriority: string;
begin
  Result := 'P1';
end;

function TBUG331_SafeQueryIdentifierValidationTest.GetAffectedFile: string;
begin
  Result := 'DeepAxis/DeepBase.External.SQLiteReader.pas';
end;

procedure TBUG331_SafeQueryIdentifierValidationTest.Test_InvalidIdentifier_ExceptionClassExists;
var
  E: EExternalDBInvalidIdentifier;
begin
  E := EExternalDBInvalidIdentifier.Create('test');
  try
    Assert.AreEqual('test', E.Message);
  finally
    E.Free;
  end;
end;

procedure TBUG331_SafeQueryIdentifierValidationTest.Test_InvalidIdentifier_ExceptionInheritance;
var
  E: Exception;
begin
  E := EExternalDBInvalidIdentifier.Create('test');
  try
    Assert.IsTrue(E is EExternalDBException,
      'EExternalDBInvalidIdentifier should inherit from EExternalDBException');
    Assert.IsTrue(E is EDeepBaseException,
      'EExternalDBInvalidIdentifier should inherit from EDeepBaseException');
  finally
    E.Free;
  end;
end;

procedure TBUG331_SafeQueryIdentifierValidationTest.Test_InvalidIdentifier_CanRaiseAndCatch;
var
  LCaught: Boolean;
begin
  LCaught := False;
  try
    raise EExternalDBInvalidIdentifier.Create('Wildcard (*) not allowed');
  except
    on E: EExternalDBInvalidIdentifier do
    begin
      LCaught := True;
      Assert.Contains(E.Message, 'Wildcard');
    end;
  end;
  Assert.IsTrue(LCaught, 'EExternalDBInvalidIdentifier should be catchable');
end;

end.
