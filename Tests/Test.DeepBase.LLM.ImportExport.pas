{ ============================================================================
  Test.DeepBase.LLM.ImportExport - Unit Tests for Import/Export Types
  
  Test Coverage (pure types only):
    - TImportResult.Init
    - TImportResult.Summary
    - TLLMImportExport.YamlToJson (BIZ-R3-019: YAML import refused)
  ============================================================================ }

unit Test.DeepBase.LLM.ImportExport;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.JSON,
  DeepBase.LLM.ImportExport;

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

  [TestFixture]
  TTestYamlToJson = class
  private
    FImp: TLLMImportExport;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure Test_YamlContent_ReturnsNil;
    [Test]
    procedure Test_JsonObject_Accepted;
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

{ TTestYamlToJson — BIZ-R3-019: YAML import is refused (export-only format) }

procedure TTestYamlToJson.Setup;
begin
  // YamlToJson does not touch FLLMManager, so nil is safe here.
  FImp := TLLMImportExport.Create(nil);
end;

procedure TTestYamlToJson.TearDown;
begin
  FImp.Free;
end;

procedure TTestYamlToJson.Test_YamlContent_ReturnsNil;
const
  // Minimal YAML produced by JsonToYaml (indentation-based, not JSON).
  YAML = 'version: 1' + sLineBreak + 'categories:' + sLineBreak + '  - ' + sLineBreak;
var
  Obj: TJSONObject;
begin
  Obj := FImp.YamlToJson(YAML);
  try
    // YAML import is unsupported — must refuse, not return a stub object.
    Assert.IsNull(Obj, 'YamlToJson must return nil for YAML content (import unsupported)');
  finally
    // YamlToJson returns nil for YAML, but guard against a future change that
    // returns an object: free it defensively without raising on nil.
    Obj.Free;
  end;
end;

procedure TTestYamlToJson.Test_JsonObject_Accepted;
const
  JSON = '{"version":1,"categories":[],"meta_prompts":[],"prompts":[]}';
var
  Obj: TJSONObject;
begin
  // JSON content (leading '{') is still accepted via the JSON fast path.
  Obj := FImp.YamlToJson(JSON);
  try
    Assert.IsNotNull(Obj, 'JSON content must parse to a non-nil object');
    Assert.IsNotNull(Obj.Values['version'], 'Parsed object must contain the version key');
  finally
    Obj.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestImportResult);
  TDUnitX.RegisterTestFixture(TTestYamlToJson);

end.
