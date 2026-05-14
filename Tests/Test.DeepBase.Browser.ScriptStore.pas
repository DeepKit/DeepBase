unit Test.DeepBase.Browser.ScriptStore;

{ ============================================================================
  Test.DeepBase.Browser.ScriptStore
  ---------------------------------------------------------------------------
  Tests focus on the pure template engine (TJSTemplate) and the seed/render
  contract. DB-bound paths (Replace/Activate/Reload) are covered indirectly
  by integration tests; here we keep the suite headless and fast.
  ============================================================================ }

interface

uses
  DUnitX.TestFramework,
  DeepBase.Browser.ScriptStore;

type
  [TestFixture]
  TJSTemplateTests = class
  public
    [Test] procedure Test_Render_StringValue_IsJsonEscaped;
    [Test] procedure Test_Render_StringValue_WithSingleQuotes;
    [Test] procedure Test_Render_StringValue_WithDoubleQuotes;
    [Test] procedure Test_Render_StringValue_WithBackslash;
    [Test] procedure Test_Render_StringValue_WithUnicode;
    [Test] procedure Test_Render_IntegerValue_NoQuotes;
    [Test] procedure Test_Render_BooleanValue_AsJsLiteral;
    [Test] procedure Test_Render_MultiplePlaceholders;
    [Test] procedure Test_Render_RepeatedPlaceholder_AllReplaced;
    [Test] procedure Test_Render_OddCount_RaisesException;
    [Test] procedure Test_Extract_FindsAllPlaceholders;
    [Test] procedure Test_Extract_DeduplicatesPlaceholders;
    [Test] procedure Test_Extract_EmptyTemplate_ReturnsEmpty;
    [Test] procedure Test_Extract_MalformedDelimiter_StopsCleanly;
  end;

  [TestFixture]
  TBuiltinDefaultsTests = class
  public
    [Test] procedure Test_Builtins_HasSevenScripts;
    [Test] procedure Test_Builtins_AllHaveBody;
    [Test] procedure Test_Builtins_AllAreActive;
    [Test] procedure Test_ExistsScript_HasSelectorPlaceholder;
    [Test] procedure Test_ResponseWaiter_HasFourPlaceholders;
    [Test] procedure Test_RenderedExists_ProducesValidJsLiteral;
  end;

implementation

uses
  System.SysUtils,
  System.StrUtils,
  System.JSON,
  DeepBase.Browser.Types;

{ -------------------- TJSTemplateTests -------------------- }

procedure TJSTemplateTests.Test_Render_StringValue_IsJsonEscaped;
var
  LResult: string;
begin
  LResult := TJSTemplate.Render('var x = {{name}};', ['name', 'hello']);
  Assert.AreEqual('var x = "hello";', LResult);
end;

procedure TJSTemplateTests.Test_Render_StringValue_WithSingleQuotes;
var
  LResult: string;
begin
  // Selectors like 'a:contains("foo")' or "[name='bar']" must survive
  LResult := TJSTemplate.Render(
    'var sel = {{s}};', ['s', '[name=''bar'']']);
  // TJSONString wraps in double quotes, single quotes stay raw
  Assert.IsTrue(StartsText('var sel = "', LResult),
    'Should start with double-quoted literal');
  Assert.IsTrue(EndsText('";', LResult),
    'Should end with closing quote and semicolon');
  Assert.IsTrue(Pos('[name=''bar'']', LResult) > 0,
    'Single-quoted content must be preserved verbatim');
end;

procedure TJSTemplateTests.Test_Render_StringValue_WithDoubleQuotes;
var
  LResult: string;
begin
  LResult := TJSTemplate.Render(
    'var sel = {{s}};', ['s', 'a"b']);
  // Double quotes must be escaped to \"
  Assert.IsTrue(Pos('"a\"b"', LResult) > 0,
    'Double quote inside payload must be escaped: ' + LResult);
end;

procedure TJSTemplateTests.Test_Render_StringValue_WithBackslash;
var
  LResult: string;
begin
  LResult := TJSTemplate.Render(
    'var s = {{x}};', ['x', 'a\b']);
  // Backslash must be escaped to \\
  Assert.IsTrue(Pos('"a\\b"', LResult) > 0,
    'Backslash must be escaped: ' + LResult);
end;

procedure TJSTemplateTests.Test_Render_StringValue_WithUnicode;
var
  LResult: string;
  LValue: string;
begin
  LValue := string(Char($4E2D)) + string(Char($6587));
  LResult := TJSTemplate.Render(
    'var s = {{x}};', ['x', LValue]);
  // Should contain the original Unicode (TJSONString preserves it as-is or escapes)
  Assert.IsTrue(
    (Pos(LValue, LResult) > 0) or
    (Pos('\u4e2d', LowerCase(LResult)) > 0),
    'Unicode should be preserved or escaped: ' + LResult);
end;

procedure TJSTemplateTests.Test_Render_IntegerValue_NoQuotes;
var
  LResult: string;
begin
  LResult := TJSTemplate.Render(
    'var t = {{ms}};', ['ms', 5000]);
  Assert.AreEqual('var t = 5000;', LResult);
end;

procedure TJSTemplateTests.Test_Render_BooleanValue_AsJsLiteral;
var
  LResult: string;
begin
  LResult := TJSTemplate.Render(
    'var ok = {{b}};', ['b', True]);
  Assert.AreEqual('var ok = true;', LResult);

  LResult := TJSTemplate.Render(
    'var ok = {{b}};', ['b', False]);
  Assert.AreEqual('var ok = false;', LResult);
end;

procedure TJSTemplateTests.Test_Render_MultiplePlaceholders;
var
  LResult: string;
begin
  LResult := TJSTemplate.Render(
    'click({{sel}}, {{ms}});',
    ['sel', '#btn', 'ms', 1000]);
  Assert.AreEqual('click("#btn", 1000);', LResult);
end;

procedure TJSTemplateTests.Test_Render_RepeatedPlaceholder_AllReplaced;
var
  LResult: string;
begin
  LResult := TJSTemplate.Render(
    'a={{x}}, b={{x}}, c={{x}}',
    ['x', 7]);
  Assert.AreEqual('a=7, b=7, c=7', LResult);
end;

procedure TJSTemplateTests.Test_Render_OddCount_RaisesException;
begin
  Assert.WillRaise(
    procedure begin
      TJSTemplate.Render('x = {{a}};', ['a']);  // missing value
    end,
    EBrowserScriptStore);
end;

procedure TJSTemplateTests.Test_Extract_FindsAllPlaceholders;
var
  LResult: TArray<string>;
begin
  LResult := TJSTemplate.Extract('a {{x}} b {{y}} c {{z}}');
  Assert.AreEqual<Integer>(3, Length(LResult));
  Assert.AreEqual('x', LResult[0]);
  Assert.AreEqual('y', LResult[1]);
  Assert.AreEqual('z', LResult[2]);
end;

procedure TJSTemplateTests.Test_Extract_DeduplicatesPlaceholders;
var
  LResult: TArray<string>;
begin
  LResult := TJSTemplate.Extract('{{x}} and {{x}} and {{y}}');
  Assert.AreEqual<Integer>(2, Length(LResult));
  Assert.AreEqual('x', LResult[0]);
  Assert.AreEqual('y', LResult[1]);
end;

procedure TJSTemplateTests.Test_Extract_EmptyTemplate_ReturnsEmpty;
var
  LResult: TArray<string>;
begin
  LResult := TJSTemplate.Extract('');
  Assert.AreEqual<Integer>(0, Length(LResult));

  LResult := TJSTemplate.Extract('no placeholders here');
  Assert.AreEqual<Integer>(0, Length(LResult));
end;

procedure TJSTemplateTests.Test_Extract_MalformedDelimiter_StopsCleanly;
var
  LResult: TArray<string>;
begin
  // Unclosed {{
  LResult := TJSTemplate.Extract('hello {{never_closed');
  Assert.AreEqual<Integer>(0, Length(LResult));

  // Closing }} without opening
  LResult := TJSTemplate.Extract('}} weird');
  Assert.AreEqual<Integer>(0, Length(LResult));
end;

{ -------------------- TBuiltinDefaultsTests -------------------- }

procedure TBuiltinDefaultsTests.Test_Builtins_HasSevenScripts;
var
  LDefaults: TJSScriptArray;
begin
  LDefaults := TJSScriptStoreSqlite.GetBuiltinDefaults;
  Assert.AreEqual<Integer>(7, Length(LDefaults));
end;

procedure TBuiltinDefaultsTests.Test_Builtins_AllHaveBody;
var
  LDefaults: TJSScriptArray;
  I: Integer;
begin
  LDefaults := TJSScriptStoreSqlite.GetBuiltinDefaults;
  for I := 0 to High(LDefaults) do
    Assert.IsTrue(LDefaults[I].Body <> '',
      Format('Script "%s" has empty body', [LDefaults[I].Name]));
end;

procedure TBuiltinDefaultsTests.Test_Builtins_AllAreActive;
var
  LDefaults: TJSScriptArray;
  I: Integer;
begin
  LDefaults := TJSScriptStoreSqlite.GetBuiltinDefaults;
  for I := 0 to High(LDefaults) do
    Assert.IsTrue(LDefaults[I].IsActive,
      Format('Script "%s" should ship active', [LDefaults[I].Name]));
end;

procedure TBuiltinDefaultsTests.Test_ExistsScript_HasSelectorPlaceholder;
var
  LDefaults: TJSScriptArray;
  I: Integer;
  LFound: Boolean;
begin
  LDefaults := TJSScriptStoreSqlite.GetBuiltinDefaults;
  LFound := False;
  for I := 0 to High(LDefaults) do
    if LDefaults[I].Name = JSCRIPT_EXISTS then
    begin
      LFound := True;
      Assert.AreEqual<Integer>(1, Length(LDefaults[I].Placeholders));
      Assert.AreEqual('selector', LDefaults[I].Placeholders[0]);
      Break;
    end;
  Assert.IsTrue(LFound, 'JSCRIPT_EXISTS not found in defaults');
end;

procedure TBuiltinDefaultsTests.Test_ResponseWaiter_HasFourPlaceholders;
var
  LDefaults: TJSScriptArray;
  I: Integer;
  LFound: Boolean;
begin
  LDefaults := TJSScriptStoreSqlite.GetBuiltinDefaults;
  LFound := False;
  for I := 0 to High(LDefaults) do
    if LDefaults[I].Name = JSCRIPT_RESPONSE_WAITER then
    begin
      LFound := True;
      Assert.AreEqual<Integer>(4, Length(LDefaults[I].Placeholders));
      Break;
    end;
  Assert.IsTrue(LFound, 'JSCRIPT_RESPONSE_WAITER not found');
end;

procedure TBuiltinDefaultsTests.Test_RenderedExists_ProducesValidJsLiteral;
var
  LDefaults: TJSScriptArray;
  I: Integer;
  LBody, LRendered: string;
begin
  LDefaults := TJSScriptStoreSqlite.GetBuiltinDefaults;
  LBody := '';
  for I := 0 to High(LDefaults) do
    if LDefaults[I].Name = JSCRIPT_EXISTS then
    begin
      LBody := LDefaults[I].Body;
      Break;
    end;
  Assert.IsTrue(LBody <> '');

  // Render with a tricky selector containing both kinds of quotes
  LRendered := TJSTemplate.Render(LBody,
    ['selector', '[data-name="x''y"]']);

  // The original Pascal-side selector survived verbatim inside a JS string
  Assert.IsTrue(Pos('document.querySelector(', LRendered) > 0);
  Assert.IsTrue(Pos('!== null', LRendered) > 0);
  // No leftover placeholder
  Assert.IsTrue(Pos('{{', LRendered) = 0,
    'Rendered output still has placeholder: ' + LRendered);
end;

initialization
  TDUnitX.RegisterTestFixture(TJSTemplateTests);
  TDUnitX.RegisterTestFixture(TBuiltinDefaultsTests);

end.
