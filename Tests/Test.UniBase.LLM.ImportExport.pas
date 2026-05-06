{ ============================================================================
  Test.UniBase.LLM.ImportExport - Unit Tests for Import/Export Types
  
  Test Coverage (pure types only):
    - TImportResult.Init
    - TImportResult.Summary
  ============================================================================ }

unit Test.UniBase.LLM.ImportExport;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  UniBase.LLM.ImportExport;

type
  [TestFixture]
  TTestImportResult = class
  public
    [Test]
    procedure Test_Init_SetsDefaults;
    [Test]
    procedure Test_Summary_Success;
    [Test]
    procedure Test_Summary_Failed;
  end;

implementation

procedure TTestImportResult.Test_Init_SetsDefaults;
var
  R: TImportResult;
begin
  R.Init;
  Assert.IsFalse(R.Success);
  Assert.AreEqual(0, R.CategoriesImported);
  Assert.AreEqual(0, R.PromptsImported);
  Assert.AreEqual(0, R.VersionsImported);
  Assert.AreEqual(0, R.MetaPromptsImported);
  Assert.AreEqual(0, R.BindingsImported);
  Assert.AreEqual(0, R.Skipped);
  Assert.AreEqual(0, Integer(Length(R.Errors)));
end;

procedure TTestImportResult.Test_Summary_Success;
var
  R: TImportResult;
  S: string;
begin
  R.Init;
  R.Success := True;
  R.CategoriesImported := 2;
  R.PromptsImported := 5;
  R.VersionsImported := 8;
  R.MetaPromptsImported := 3;
  R.BindingsImported := 4;
  R.Skipped := 1;

  S := R.Summary;
  Assert.IsTrue(S.Contains('Import successful'));
  Assert.IsTrue(S.Contains('2 categories'));
end;

procedure TTestImportResult.Test_Summary_Failed;
var
  R: TImportResult;
  S: string;
begin
  R.Init;
  R.Success := False;
  SetLength(R.Errors, 2);
  R.Errors[0] := 'Error 1';
  R.Errors[1] := 'Error 2';

  S := R.Summary;
  Assert.IsTrue(S.Contains('Import failed'));
  Assert.IsTrue(S.Contains('2'));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestImportResult);

end.
