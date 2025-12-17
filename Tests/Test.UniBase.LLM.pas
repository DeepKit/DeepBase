unit Test.UniBase.LLM;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  DUnitX.TestFramework,
  UniBase.LLM;

type
  /// <summary>
  /// Tests for TLLMConfig and provider string mapping.
  /// </summary>
  [TestFixture]
  TLLMConfigTests = class
  public
    [Test]
    procedure Test_Init_Sets_Defaults;

    [Test]
    procedure Test_Provider_String_RoundTrip_All_Values;
  end;

  /// <summary>
  /// Tests for TLLMMessage helpers.
  /// </summary>
  [TestFixture]
  TLLMMessageTests = class
  public
    [Test]
    procedure Test_System_User_Assistant_Constructors_Set_Role_And_Content;
  end;

  /// <summary>
  /// Tests for TLLMChatResponse.Init.
  /// </summary>
  [TestFixture]
  TLLMChatResponseTests = class
  public
    [Test]
    procedure Test_Init_Sets_Default_Values;
  end;

  /// <summary>
  /// Tests for TLLMRequestOptions defaulting and config mapping.
  /// </summary>
  [TestFixture]
  TLLMRequestOptionsTests = class
  public
    [Test]
    procedure Test_Default_Values;

    [Test]
    procedure Test_FromConfig_Uses_Config_Values;
  end;

  /// <summary>
  /// Tests for TLLMPromptTemplate.Init/RenderUserPrompt/Clone.
  /// </summary>
  [TestFixture]
  TLLMPromptTemplateTests = class
  public
    [Test]
    procedure Test_Init_Sets_Sensible_Defaults;

    [Test]
    procedure Test_RenderUserPrompt_Uses_Values_And_Defaults;

    [Test]
    procedure Test_Clone_Copies_Fields_And_Allocates_New_Dictionaries;
  end;

implementation

{ TLLMConfigTests }

procedure TLLMConfigTests.Test_Init_Sets_Defaults;
var
  C: TLLMConfig;
begin
  C.Init;
  Assert.AreEqual('Default', C.Name);
  Assert.AreEqual(LLMProviderToStr(lpOpenAI), C.ProviderToStr);
  Assert.AreEqual('gpt-4o-mini', C.Model);
  Assert.AreEqual(4096, C.MaxTokens);
  Assert.AreEqual(0.7, C.Temperature, 0.0001);
  Assert.IsTrue(C.IsEnabled);
  Assert.IsFalse(C.IsDefault);
  Assert.IsTrue(C.InputTokenPrice > 0);
  Assert.IsTrue(C.OutputTokenPrice > 0);
end;

procedure TLLMConfigTests.Test_Provider_String_RoundTrip_All_Values;
var
  P, P2: TLLMProvider;
  S: string;
begin
  for P in [lpOpenAI, lpAnthropic, lpAzure, lpLiteLLM, lpOllama, lpCustom] do
  begin
    S := LLMProviderToStr(P);
    P2 := StrToLLMProvider(S);
    Assert.AreEqual(P, P2, 'Round-trip failed for provider ' + S);
  end;
end;

{ TLLMMessageTests }

procedure TLLMMessageTests.Test_System_User_Assistant_Constructors_Set_Role_And_Content;
var
  M: TLLMMessage;
begin
  M := TLLMMessage.System('sys');
  Assert.AreEqual('system', M.Role);
  Assert.AreEqual('sys', M.Content);

  M := TLLMMessage.User('user msg');
  Assert.AreEqual('user', M.Role);
  Assert.AreEqual('user msg', M.Content);

  M := TLLMMessage.Assistant('reply');
  Assert.AreEqual('assistant', M.Role);
  Assert.AreEqual('reply', M.Content);
end;

{ TLLMChatResponseTests }

procedure TLLMChatResponseTests.Test_Init_Sets_Default_Values;
var
  R: TLLMChatResponse;
begin
  // Set non-defaults first to ensure Init really resets
  R.Success := True;
  R.Content := 'x';
  R.FinishReason := 'stop';
  R.InputTokens := 10;
  R.OutputTokens := 20;
  R.TotalTokens := 30;
  R.DurationMs := 123;
  R.ErrorCode := 'ERR';
  R.ErrorMessage := 'msg';

  R.Init;

  Assert.IsFalse(R.Success);
  Assert.AreEqual('', R.Content);
  Assert.AreEqual('', R.FinishReason);
  Assert.AreEqual(0, R.InputTokens);
  Assert.AreEqual(0, R.OutputTokens);
  Assert.AreEqual(0, R.TotalTokens);
  Assert.AreEqual<Int64>(0, R.DurationMs);
  Assert.AreEqual('', R.ErrorCode);
  Assert.AreEqual('', R.ErrorMessage);
end;

{ TLLMRequestOptionsTests }

procedure TLLMRequestOptionsTests.Test_Default_Values;
var
  O: TLLMRequestOptions;
begin
  O := TLLMRequestOptions.Default;
  Assert.AreEqual('', O.Model);
  Assert.AreEqual(4096, O.MaxTokens);
  Assert.AreEqual(0.7, O.Temperature, 0.0001);
  Assert.AreEqual(1.0, O.TopP, 0.0001);
  Assert.AreEqual(Integer(0), Integer(Length(O.Stop)));
  Assert.IsFalse(O.Stream);
end;

procedure TLLMRequestOptionsTests.Test_FromConfig_Uses_Config_Values;
var
  C: TLLMConfig;
  O: TLLMRequestOptions;
begin
  C.Init;
  C.Model := 'test-model';
  C.MaxTokens := 1234;
  C.Temperature := 1.1;

  O := TLLMRequestOptions.FromConfig(C);
  Assert.AreEqual('test-model', O.Model);
  Assert.AreEqual(1234, O.MaxTokens);
  Assert.AreEqual(1.1, O.Temperature, 0.0001);
  Assert.AreEqual(1.0, O.TopP, 0.0001);
  Assert.AreEqual(Integer(0), Integer(Length(O.Stop)));
  Assert.IsFalse(O.Stream);
end;

{ TLLMPromptTemplateTests }

procedure TLLMPromptTemplateTests.Test_Init_Sets_Sensible_Defaults;
var
  T: TLLMPromptTemplate;
begin
  T.Init;
  Assert.AreEqual(0, T.Id);
  Assert.AreEqual('', T.Name);
  Assert.AreEqual('General', T.Category);
  Assert.AreEqual('text', T.OutputFormat);
  Assert.AreEqual('', T.ValidationRegex);
  Assert.IsTrue(T.IsEnabled);
  Assert.IsFalse(T.IsBuiltIn);
  Assert.AreEqual(0, T.SortOrder);
  Assert.AreEqual(Integer(0), Integer(Length(T.Variables)));
  Assert.AreEqual(Integer(0), Integer(Length(T.IncludeTemplates)));
  Assert.IsNull(T.DefaultValues);
end;

procedure TLLMPromptTemplateTests.Test_RenderUserPrompt_Uses_Values_And_Defaults;
var
  T: TLLMPromptTemplate;
  Values: TDictionary<string, string>;
  Output: string;
begin
  T.Init;
  T.UserPromptTemplate := 'Hello {{name}}, today is {{day}}.';
  SetLength(T.Variables, 2);
  T.Variables[0] := 'name';
  T.Variables[1] := 'day';

  T.DefaultValues := TDictionary<string, string>.Create;
  try
    T.DefaultValues.Add('day', 'Monday');

    Values := TDictionary<string, string>.Create;
    try
      Values.Add('name', 'Alice');

      Output := T.RenderUserPrompt(Values);
      Assert.AreEqual('Hello Alice, today is Monday.', Output);
    finally
      Values.Free;
    end;
  finally
    T.DefaultValues.Free;
    T.DefaultValues := nil;
  end;
end;

procedure TLLMPromptTemplateTests.Test_Clone_Copies_Fields_And_Allocates_New_Dictionaries;
var
  Src, CopyT: TLLMPromptTemplate;
  I: Integer;
begin
  Src.Init;
  Src.Id := 42;
  Src.Name := 'welcome';
  Src.Category := 'Greeting';
  Src.Description := 'Welcome message';
  Src.SystemPrompt := 'You are a helpful assistant.';
  Src.UserPromptTemplate := 'Hi {{user}}';
  SetLength(Src.Variables, 1);
  Src.Variables[0] := 'user';
  SetLength(Src.IncludeTemplates, 1);
  Src.IncludeTemplates[0] := 'base';
  Src.OutputFormat := 'markdown';
  Src.ValidationRegex := '.*';
  Src.Examples := '[{"input":{},"output":"hi"}]';
  Src.RecommendedConfig := 'Default';
  Src.RecommendedModel := 'gpt-test';
  Src.MaxTokens := 256;
  Src.Temperature := 0.5;
  Src.IsEnabled := True;
  Src.IsBuiltIn := True;
  Src.SortOrder := 10;

  Src.DefaultValues := TDictionary<string, string>.Create;
  try
    Src.DefaultValues.Add('user', 'World');

    CopyT := Src.Clone;
    try
      // Clone should reset Id and change name
      Assert.AreEqual(0, CopyT.Id);
      Assert.AreEqual(Src.Name + '_copy', CopyT.Name);
      Assert.AreEqual(Src.Category, CopyT.Category);
      Assert.AreEqual(Src.Description, CopyT.Description);
      Assert.AreEqual(Src.SystemPrompt, CopyT.SystemPrompt);
      Assert.AreEqual(Src.UserPromptTemplate, CopyT.UserPromptTemplate);
      Assert.AreEqual(Src.OutputFormat, CopyT.OutputFormat);
      Assert.AreEqual(Src.ValidationRegex, CopyT.ValidationRegex);
      Assert.AreEqual(Src.RecommendedConfig, CopyT.RecommendedConfig);
      Assert.AreEqual(Src.RecommendedModel, CopyT.RecommendedModel);
      Assert.AreEqual(Src.MaxTokens, CopyT.MaxTokens);
      Assert.AreEqual(Src.Temperature, CopyT.Temperature, 0.0001);
      Assert.AreEqual(Src.IsEnabled, CopyT.IsEnabled);
      Assert.IsFalse(CopyT.IsBuiltIn, 'Clone should never be built-in');
      Assert.AreEqual(Src.SortOrder, CopyT.SortOrder);

      // Arrays should be copied element-wise
      Assert.AreEqual(Length(Src.Variables), Length(CopyT.Variables));
      for I := 0 to High(Src.Variables) do
        Assert.AreEqual(Src.Variables[I], CopyT.Variables[I]);

      Assert.AreEqual(Length(Src.IncludeTemplates), Length(CopyT.IncludeTemplates));
      for I := 0 to High(Src.IncludeTemplates) do
        Assert.AreEqual(Src.IncludeTemplates[I], CopyT.IncludeTemplates[I]);

      // DefaultValues should be deep-copied
      Assert.IsNotNull(CopyT.DefaultValues);
      Assert.IsFalse(Src.DefaultValues = CopyT.DefaultValues, 'Clone must have its own dictionary instance');
      Assert.IsTrue(CopyT.DefaultValues.ContainsKey('user'));
      Assert.AreEqual('World', CopyT.DefaultValues['user']);
    finally
      if Assigned(CopyT.DefaultValues) then
        CopyT.DefaultValues.Free;
    end;
  finally
    if Assigned(Src.DefaultValues) then
      Src.DefaultValues.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TLLMConfigTests);
  TDUnitX.RegisterTestFixture(TLLMMessageTests);
  TDUnitX.RegisterTestFixture(TLLMChatResponseTests);
  TDUnitX.RegisterTestFixture(TLLMRequestOptionsTests);
  TDUnitX.RegisterTestFixture(TLLMPromptTemplateTests);

end.
