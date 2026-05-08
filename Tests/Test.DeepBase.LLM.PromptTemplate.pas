{ ============================================================================
  Test.DeepBase.LLM.PromptTemplate - Prompt Template Unit Tests
  
  说明: 测试 LLM Prompt 模板管理功能
  ============================================================================ }

unit Test.DeepBase.LLM.PromptTemplate;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils, System.IOUtils, System.Generics.Collections,
  FireDAC.Comp.Client, FireDAC.Stan.Def, FireDAC.Phys.SQLite,
  DeepBase.LLM;

type
  [TestFixture]
  TTestLLMPromptTemplate = class
  private
    FConnection: TFDConnection;
    FLLM: TDeepBaseLLM;
    
    procedure CreateTestTables;
    procedure DropTestTables;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_TemplateInit_SetsDefaults;
    
    [Test]
    procedure Test_SaveTemplate_InsertsNew;
    
    [Test]
    procedure Test_SaveTemplate_UpdatesExisting;
    
    [Test]
    procedure Test_GetTemplate_ReturnsCorrectData;
    
    [Test]
    procedure Test_DeleteTemplate_RemovesNonBuiltIn;
    
    [Test]
    procedure Test_DeleteTemplate_SkipsBuiltIn;
    
    [Test]
    procedure Test_CopyTemplate_CreatesNewTemplate;
    
    [Test]
    procedure Test_GetTemplatesByCategory_FiltersCorrectly;
    
    [Test]
    procedure Test_RenderUserPrompt_ReplacesVariables;
    
    [Test]
    procedure Test_RenderUserPrompt_UsesDefaults;
    
    [Test]
    procedure Test_ValidateTemplate_DetectsEmptyName;
    
    [Test]
    procedure Test_ValidateTemplate_DetectsMissingVariables;
    
    [Test]
    procedure Test_RenderWithInheritance_MergesDefaults;
    
    [Test]
    procedure Test_ExportImport_RoundTrip;
  end;

implementation

uses
  DeepBase.Schema;

{ TTestLLMPromptTemplate }

procedure TTestLLMPromptTemplate.Setup;
begin
  // 使用内存数据�?
  FConnection := TFDConnection.Create(nil);
  FConnection.DriverName := 'SQLite';
  FConnection.Params.Database := ':memory:';
  FConnection.Open;
  
  CreateTestTables;
  
  FLLM := TDeepBaseLLM.Create(FConnection);
end;

procedure TTestLLMPromptTemplate.TearDown;
begin
  FLLM.Free;
  DropTestTables;
  FConnection.Free;
end;

procedure TTestLLMPromptTemplate.CreateTestTables;
var
  Q: TFDQuery;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    // 创建 LLMPromptTemplates �?
    Q.SQL.Text := SQL_TIER2_LLM_PROMPT_TEMPLATES;
    Q.ExecSQL;
    // 创建 LLMConfiguration 表（FLLM 构造函数需要）
    Q.SQL.Text := SQL_TIER2_LLM_CONFIG;
    Q.ExecSQL;
  finally
    Q.Free;
  end;
end;

procedure TTestLLMPromptTemplate.DropTestTables;
var
  Q: TFDQuery;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text := 'DROP TABLE IF EXISTS LLMPromptTemplates';
    Q.ExecSQL;
    Q.SQL.Text := 'DROP TABLE IF EXISTS LLMConfiguration';
    Q.ExecSQL;
  finally
    Q.Free;
  end;
end;

procedure TTestLLMPromptTemplate.Test_TemplateInit_SetsDefaults;
var
  T: TLLMPromptTemplate;
begin
  T.Init;
  
  Assert.AreEqual(0, T.Id, 'Id should be 0');
  Assert.AreEqual('', T.Name, 'Name should be empty');
  Assert.AreEqual('General', T.Category, 'Category should be General');
  Assert.AreEqual('text', T.OutputFormat, 'OutputFormat should be text');
  Assert.AreEqual(0.7, T.Temperature, 0.001, 'Temperature should be 0.7');
  Assert.IsTrue(T.IsEnabled, 'IsEnabled should be True');
  Assert.IsFalse(T.IsBuiltIn, 'IsBuiltIn should be False');
end;

procedure TTestLLMPromptTemplate.Test_SaveTemplate_InsertsNew;
var
  T: TLLMPromptTemplate;
  Loaded: TLLMPromptTemplate;
begin
  T.Init;
  T.Name := 'test_insert';
  T.Category := 'Testing';
  T.Description := 'Test template';
  T.UserPromptTemplate := 'Hello {{name}}';
  SetLength(T.Variables, 1);
  T.Variables[0] := 'name';
  
  FLLM.SaveTemplate(T);
  
  Loaded := FLLM.GetTemplate('test_insert');
  Assert.AreEqual('test_insert', Loaded.Name, 'Name should match');
  Assert.AreEqual('Testing', Loaded.Category, 'Category should match');
  Assert.AreEqual('Hello {{name}}', Loaded.UserPromptTemplate, 'UserPromptTemplate should match');
  Assert.AreEqual(1, Length(Loaded.Variables), 'Should have 1 variable');
  Assert.AreEqual('name', Loaded.Variables[0], 'Variable should be name');
end;

procedure TTestLLMPromptTemplate.Test_SaveTemplate_UpdatesExisting;
var
  T: TLLMPromptTemplate;
  Loaded: TLLMPromptTemplate;
begin
  // Insert
  T.Init;
  T.Name := 'test_update';
  T.Description := 'Original';
  T.UserPromptTemplate := 'Original {{text}}';
  SetLength(T.Variables, 1);
  T.Variables[0] := 'text';
  FLLM.SaveTemplate(T);
  
  // Update
  T.Description := 'Updated';
  T.UserPromptTemplate := 'Updated {{text}}';
  FLLM.SaveTemplate(T);
  
  Loaded := FLLM.GetTemplate('test_update');
  Assert.AreEqual('Updated', Loaded.Description, 'Description should be updated');
  Assert.AreEqual('Updated {{text}}', Loaded.UserPromptTemplate, 'Template should be updated');
end;

procedure TTestLLMPromptTemplate.Test_GetTemplate_ReturnsCorrectData;
var
  T: TLLMPromptTemplate;
  Loaded: TLLMPromptTemplate;
begin
  T.Init;
  T.Name := 'test_get';
  T.Category := 'Code';
  T.Description := 'Test getting template';
  T.SystemPrompt := 'You are a test assistant';
  T.UserPromptTemplate := 'Translate {{text}} to {{lang}}';
  SetLength(T.Variables, 2);
  T.Variables[0] := 'text';
  T.Variables[1] := 'lang';
  T.DefaultValues := TDictionary<string, string>.Create;
  T.DefaultValues.Add('lang', 'English');
  T.Temperature := 0.5;
  T.RecommendedConfig := 'Translation';
  
  FLLM.SaveTemplate(T);
  
  Loaded := FLLM.GetTemplate('test_get');
  Assert.AreEqual('Code', Loaded.Category);
  Assert.AreEqual('You are a test assistant', Loaded.SystemPrompt);
  Assert.AreEqual(2, Integer(Length(Loaded.Variables)));
  Assert.IsNotNull(Loaded.DefaultValues);
  Assert.AreEqual('English', Loaded.DefaultValues['lang']);
  Assert.AreEqual(0.5, Loaded.Temperature, 0.001);
end;

procedure TTestLLMPromptTemplate.Test_DeleteTemplate_RemovesNonBuiltIn;
var
  T: TLLMPromptTemplate;
  Loaded: TLLMPromptTemplate;
begin
  T.Init;
  T.Name := 'test_delete';
  T.UserPromptTemplate := 'Test';
  T.IsBuiltIn := False;
  FLLM.SaveTemplate(T);
  
  FLLM.DeleteTemplate('test_delete');
  
  Loaded := FLLM.GetTemplate('test_delete');
  Assert.AreEqual('', Loaded.Name, 'Template should be deleted');
end;

procedure TTestLLMPromptTemplate.Test_DeleteTemplate_SkipsBuiltIn;
var
  Q: TFDQuery;
  Loaded: TLLMPromptTemplate;
begin
  // Insert built-in template directly
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text := 'INSERT INTO LLMPromptTemplates (Name, UserPromptTemplate, IsEnabled, IsBuiltIn) VALUES (:Name, :Tpl, 1, 1)';
    Q.ParamByName('Name').AsString := 'test_builtin';
    Q.ParamByName('Tpl').AsString := 'Built-in template';
    Q.ExecSQL;
  finally
    Q.Free;
  end;
  
  FLLM.DeleteTemplate('test_builtin');
  
  Loaded := FLLM.GetTemplate('test_builtin');
  Assert.AreEqual('test_builtin', Loaded.Name, 'Built-in template should NOT be deleted');
end;

procedure TTestLLMPromptTemplate.Test_CopyTemplate_CreatesNewTemplate;
var
  T: TLLMPromptTemplate;
  Copied: TLLMPromptTemplate;
begin
  T.Init;
  T.Name := 'source_template';
  T.Description := 'Original description';
  T.UserPromptTemplate := 'Hello {{name}}';
  SetLength(T.Variables, 1);
  T.Variables[0] := 'name';
  FLLM.SaveTemplate(T);
  
  Assert.IsTrue(FLLM.CopyTemplate('source_template', 'copied_template'), 'Copy should succeed');
  
  Copied := FLLM.GetTemplate('copied_template');
  Assert.AreEqual('copied_template', Copied.Name);
  Assert.AreEqual('Original description', Copied.Description);
  Assert.AreEqual('Hello {{name}}', Copied.UserPromptTemplate);
  Assert.IsFalse(Copied.IsBuiltIn, 'Copied template should not be built-in');
end;

procedure TTestLLMPromptTemplate.Test_GetTemplatesByCategory_FiltersCorrectly;
var
  T: TLLMPromptTemplate;
  Templates: TLLMPromptTemplateArray;
begin
  // Insert templates in different categories
  T.Init;
  T.Name := 'cat_test_1';
  T.Category := 'Translation';
  T.UserPromptTemplate := 'Translate';
  FLLM.SaveTemplate(T);
  
  T.Init;
  T.Name := 'cat_test_2';
  T.Category := 'Translation';
  T.UserPromptTemplate := 'Translate 2';
  FLLM.SaveTemplate(T);
  
  T.Init;
  T.Name := 'cat_test_3';
  T.Category := 'Code';
  T.UserPromptTemplate := 'Code';
  FLLM.SaveTemplate(T);
  
  Templates := FLLM.GetTemplatesByCategory('Translation');
  Assert.AreEqual(2, Length(Templates), 'Should return 2 Translation templates');
  
  Templates := FLLM.GetTemplatesByCategory('Code');
  Assert.AreEqual(1, Length(Templates), 'Should return 1 Code template');
end;

procedure TTestLLMPromptTemplate.Test_RenderUserPrompt_ReplacesVariables;
var
  T: TLLMPromptTemplate;
  Vars: TDictionary<string, string>;
  Result: string;
begin
  T.Init;
  T.UserPromptTemplate := 'Hello {{name}}, welcome to {{place}}!';
  SetLength(T.Variables, 2);
  T.Variables[0] := 'name';
  T.Variables[1] := 'place';
  
  Vars := TDictionary<string, string>.Create;
  try
    Vars.Add('name', 'Alice');
    Vars.Add('place', 'DeepBase');
    
    Result := T.RenderUserPrompt(Vars);
    Assert.AreEqual('Hello Alice, welcome to DeepBase!', Result);
  finally
    Vars.Free;
  end;
end;

procedure TTestLLMPromptTemplate.Test_RenderUserPrompt_UsesDefaults;
var
  T: TLLMPromptTemplate;
  Vars: TDictionary<string, string>;
  Result: string;
begin
  T.Init;
  T.UserPromptTemplate := 'Translate to {{lang}}: {{text}}';
  SetLength(T.Variables, 2);
  T.Variables[0] := 'lang';
  T.Variables[1] := 'text';
  T.DefaultValues := TDictionary<string, string>.Create;
  T.DefaultValues.Add('lang', 'Chinese');
  
  Vars := TDictionary<string, string>.Create;
  try
    Vars.Add('text', 'Hello world');
    // lang not provided, should use default
    
    Result := T.RenderUserPrompt(Vars);
    Assert.AreEqual('Translate to Chinese: Hello world', Result);
  finally
    Vars.Free;
  end;
end;

procedure TTestLLMPromptTemplate.Test_ValidateTemplate_DetectsEmptyName;
var
  T: TLLMPromptTemplate;
  V: TTemplateValidation;
begin
  T.Init;
  T.Name := '';
  T.UserPromptTemplate := 'Test';
  
  V := FLLM.ValidateTemplate(T);
  
  Assert.IsFalse(V.IsValid, 'Should be invalid');
  Assert.IsTrue(Length(V.Errors) > 0, 'Should have errors');
end;

procedure TTestLLMPromptTemplate.Test_ValidateTemplate_DetectsMissingVariables;
var
  T: TLLMPromptTemplate;
  V: TTemplateValidation;
begin
  T.Init;
  T.Name := 'test_missing_vars';
  T.UserPromptTemplate := 'Hello {{name}}, you are {{age}} years old';
  SetLength(T.Variables, 1);
  T.Variables[0] := 'name'; // 'age' is missing
  
  V := FLLM.ValidateTemplate(T);
  
  Assert.IsTrue(V.IsValid, 'Should be valid (missing vars is warning)');
  Assert.AreEqual(1, Length(V.MissingVariables), 'Should detect 1 missing variable');
  Assert.AreEqual('age', V.MissingVariables[0], 'Missing variable should be age');
end;

procedure TTestLLMPromptTemplate.Test_RenderWithInheritance_MergesDefaults;
var
  Parent, Child: TLLMPromptTemplate;
  Vars: TDictionary<string, string>;
  Result: string;
begin
  // Create parent template
  Parent.Init;
  Parent.Name := 'parent_tpl';
  Parent.UserPromptTemplate := 'Parent: {{lang}}';
  SetLength(Parent.Variables, 1);
  Parent.Variables[0] := 'lang';
  Parent.DefaultValues := TDictionary<string, string>.Create;
  Parent.DefaultValues.Add('lang', 'English');
  FLLM.SaveTemplate(Parent);
  
  // Create child template that inherits from parent
  Child.Init;
  Child.Name := 'child_tpl';
  Child.ParentTemplate := 'parent_tpl';
  Child.UserPromptTemplate := 'Translate {{text}} to {{lang}}';
  SetLength(Child.Variables, 2);
  Child.Variables[0] := 'text';
  Child.Variables[1] := 'lang';
  // No default for lang - should inherit from parent
  FLLM.SaveTemplate(Child);
  
  Vars := TDictionary<string, string>.Create;
  try
    Vars.Add('text', 'Hello');
    // lang not provided, should get from parent's default
    
    Result := FLLM.RenderWithInheritance('child_tpl', Vars);
    Assert.AreEqual('Translate Hello to English', Result);
  finally
    Vars.Free;
  end;
end;

procedure TTestLLMPromptTemplate.Test_ExportImport_RoundTrip;
var
  T: TLLMPromptTemplate;
  Json: string;
  Imported: Integer;
  Loaded: TLLMPromptTemplate;
begin
  // Create template
  T.Init;
  T.Name := 'export_test';
  T.Category := 'Testing';
  T.Description := 'Export test template';
  T.UserPromptTemplate := 'Test {{var}}';
  SetLength(T.Variables, 1);
  T.Variables[0] := 'var';
  T.Temperature := 0.8;
  FLLM.SaveTemplate(T);
  
  // Export
  Json := FLLM.ExportTemplates;
  Assert.IsNotEmpty(Json, 'Export should return JSON');
  Assert.IsTrue(Pos('"name"', Json) > 0, 'JSON should contain name field');
  
  // Delete original
  FLLM.DeleteTemplate('export_test');
  
  // Import
  Imported := FLLM.ImportTemplates(Json, False);
  Assert.AreEqual(1, Imported, 'Should import 1 template');
  
  // Verify
  Loaded := FLLM.GetTemplate('export_test');
  Assert.AreEqual('export_test', Loaded.Name);
  Assert.AreEqual('Testing', Loaded.Category);
  Assert.AreEqual(0.8, Loaded.Temperature, 0.001);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestLLMPromptTemplate);

end.
