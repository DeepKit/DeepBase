{ ============================================================================
  Test.UniBase.LLM.Manager - Unit Tests for LLM Prompt Manager Types
  
  Test Coverage (pure types/helpers only):
    - TPromptVariable (TypeToStr / StrToType, fields)
    - TMetaPrompt (Category/MergeMode helpers)
    - TPromptCategory (FullPath)
    - TPromptVersion (SuccessRate)
    - TPrompt (GetProductionVersion / HasVersion / GetVersion)
    - TLLMResponse.Init
  ============================================================================ }

unit Test.UniBase.LLM.Manager;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  UniBase.LLM.Manager;

type
  [TestFixture]
  TTestPromptVariable = class
  public
    [Test]
    procedure Test_Type_RoundTrip_AllKinds;
    [Test]
    procedure Test_Fields_Assignment;
  end;

  [TestFixture]
  TTestMetaPromptHelpers = class
  public
    [Test]
    procedure Test_Category_RoundTrip_AllKinds;
    [Test]
    procedure Test_MergeMode_RoundTrip_AllKinds;
  end;

  [TestFixture]
  TTestPromptCategory = class
  public
    [Test]
    procedure Test_FullPath_ContainsName;
  end;

  [TestFixture]
  TTestPromptVersion = class
  public
    [Test]
    procedure Test_SuccessRate_NoTests;
    [Test]
    procedure Test_SuccessRate_Partial;
  end;

  [TestFixture]
  TTestPromptHelpers = class
  public
    [Test]
    procedure Test_GetProductionVersion;
    [Test]
    procedure Test_HasVersion_TrueFalse;
    [Test]
    procedure Test_GetVersion_ReturnsCorrect;
  end;

  [TestFixture]
  TTestLLMResponse = class
  public
    [Test]
    procedure Test_Init_SetsDefaults;
  end;

implementation

{ TTestPromptVariable }

procedure TTestPromptVariable.Test_Type_RoundTrip_AllKinds;
var
  V: TPromptVariable;
  AllTypes: array[0..6] of TPromptVariableType;
  T: TPromptVariableType;
  S: string;
begin
  AllTypes[0] := pvtString;
  AllTypes[1] := pvtNumber;
  AllTypes[2] := pvtBoolean;
  AllTypes[3] := pvtDate;
  AllTypes[4] := pvtDateTime;
  AllTypes[5] := pvtList;
  AllTypes[6] := pvtJson;

  for T in AllTypes do
  begin
    V.VarType := T;
    S := V.TypeToStr;
    Assert.AreEqual(T, TPromptVariable.StrToType(S));
  end;
end;

procedure TTestPromptVariable.Test_Fields_Assignment;
var
  V: TPromptVariable;
begin
  V.Name := 'user_name';
  V.VarType := pvtString;
  V.DefaultValue := 'guest';
  V.Description := 'User name';
  V.Required := True;

  Assert.AreEqual('user_name', V.Name);
  Assert.AreEqual(pvtString, V.VarType);
  Assert.AreEqual('guest', VarToStr(V.DefaultValue));
  Assert.AreEqual('User name', V.Description);
  Assert.IsTrue(V.Required);
end;

{ TTestMetaPromptHelpers }

procedure TTestMetaPromptHelpers.Test_Category_RoundTrip_AllKinds;
var
  M: TMetaPrompt;
  C: TMetaCategory;
  AllCats: array[0..4] of TMetaCategory;
  S: string;
begin
  AllCats[0] := mcSecurity;
  AllCats[1] := mcFormat;
  AllCats[2] := mcRole;
  AllCats[3] := mcDomain;
  AllCats[4] := mcQuality;

  for C in AllCats do
  begin
    M.Category := C;
    S := M.CategoryToStr;
    Assert.AreEqual(C, TMetaPrompt.StrToCategory(S));
  end;
end;

procedure TTestMetaPromptHelpers.Test_MergeMode_RoundTrip_AllKinds;
var
  M: TMetaPrompt;
  Mode: TMetaMergeMode;
  AllModes: array[0..2] of TMetaMergeMode;
  S: string;
begin
  AllModes[0] := mmPrefix;
  AllModes[1] := mmSuffix;
  AllModes[2] := mmWrap;

  for Mode in AllModes do
  begin
    M.MergeMode := Mode;
    S := M.MergeModeToStr;
    Assert.AreEqual(Mode, TMetaPrompt.StrToMergeMode(S));
  end;
end;

{ TTestPromptCategory }

procedure TTestPromptCategory.Test_FullPath_ContainsName;
var
  Cat: TPromptCategory;
  Path: string;
begin
  Cat.Id := 1;
  Cat.ParentId := 0;
  Cat.Level := 1;
  Cat.Code := '01';
  Cat.Name := '系统提示词';
  Cat.Description := 'Root category';
  Cat.SortOrder := 10;
  Cat.IsActive := True;

  Path := Cat.FullPath;
  Assert.IsTrue(Path.Contains(Cat.Name));
end;

{ TTestPromptVersion }

procedure TTestPromptVersion.Test_SuccessRate_NoTests;
var
  Ver: TPromptVersion;
begin
  Ver.TestCount := 0;
  Ver.SuccessCount := 0;
  Assert.AreEqual(0.0, Ver.SuccessRate, 0.0001);
end;

procedure TTestPromptVersion.Test_SuccessRate_Partial;
var
  Ver: TPromptVersion;
begin
  Ver.TestCount := 4;
  Ver.SuccessCount := 3;
  Assert.AreEqual(0.75, Ver.SuccessRate, 0.0001);
end;

{ TTestPromptHelpers }

procedure TTestPromptHelpers.Test_GetProductionVersion;
var
  P: TPrompt;
  V1, V2, V3: TPromptVersion;
  VerNum: Integer;
begin
  SetLength(P.Versions, 3);

  V1.VersionNumber := 1;
  V1.IsProduction := False;
  P.Versions[0] := V1;

  V2.VersionNumber := 2;
  V2.IsProduction := True;
  P.Versions[1] := V2;

  V3.VersionNumber := 3;
  V3.IsProduction := False;
  P.Versions[2] := V3;

  VerNum := P.GetProductionVersion;
  Assert.AreEqual(2, VerNum);
end;

procedure TTestPromptHelpers.Test_HasVersion_TrueFalse;
var
  P: TPrompt;
  V1: TPromptVersion;
begin
  SetLength(P.Versions, 1);
  V1.VersionNumber := 5;
  P.Versions[0] := V1;

  Assert.IsTrue(P.HasVersion(5));
  Assert.IsFalse(P.HasVersion(2));
end;

procedure TTestPromptHelpers.Test_GetVersion_ReturnsCorrect;
var
  P: TPrompt;
  V1, V2: TPromptVersion;
  R: TPromptVersion;
begin
  SetLength(P.Versions, 2);
  V1.VersionNumber := 1;
  V1.Content := 'v1';
  P.Versions[0] := V1;

  V2.VersionNumber := 2;
  V2.Content := 'v2';
  P.Versions[1] := V2;

  R := P.GetVersion(2);
  Assert.AreEqual(2, R.VersionNumber);
  Assert.AreEqual('v2', R.Content);
end;

{ TTestLLMResponse }

procedure TTestLLMResponse.Test_Init_SetsDefaults;
var
  R: TLLMResponse;
begin
  // Set non-defaults first
  R.Success := True;
  R.Content := 'x';
  R.InputTokens := 10;
  R.OutputTokens := 5;
  R.TotalTokens := 15;
  R.DurationMs := 123;
  R.ErrorCode := 'ERR';
  R.ErrorMessage := 'msg';
  R.PromptId := 1;
  R.VersionNumber := 1;
  R.ConfigName := 'cfg';
  R.Cost := 1.23;

  R.Init;

  Assert.IsFalse(R.Success);
  Assert.AreEqual('', R.Content);
  Assert.AreEqual(0, R.InputTokens);
  Assert.AreEqual(0, R.OutputTokens);
  Assert.AreEqual(0, R.TotalTokens);
  Assert.AreEqual(0, R.DurationMs);
  Assert.AreEqual('', R.ErrorCode);
  Assert.AreEqual('', R.ErrorMessage);
  Assert.AreEqual(0, R.PromptId);
  Assert.AreEqual(0, R.VersionNumber);
  Assert.AreEqual('', R.ConfigName);
  Assert.AreEqual(0.0, R.Cost, 0.0001);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestPromptVariable);
  TDUnitX.RegisterTestFixture(TTestMetaPromptHelpers);
  TDUnitX.RegisterTestFixture(TTestPromptCategory);
  TDUnitX.RegisterTestFixture(TTestPromptVersion);
  TDUnitX.RegisterTestFixture(TTestPromptHelpers);
  TDUnitX.RegisterTestFixture(TTestLLMResponse);

end.
