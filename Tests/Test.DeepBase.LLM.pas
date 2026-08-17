unit Test.DeepBase.LLM;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  FireDAC.Comp.Client,
  FireDAC.Stan.Def,
  FireDAC.Phys.SQLite,
  DUnitX.TestFramework,
  DeepBase.LLM;

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

  [TestFixture]
  TLLMConfigStoreTests = class
  public
    [Test]
    procedure Test_BuiltInTiers_ExposeFiveDesktopSlots;

    [Test]
    procedure Test_TierModels_NormalizeLegacyVisionToImageGen;

    [Test]
    procedure Test_Load_MigratesLegacyVisionTier;

    [Test]
    procedure Test_IsConfigured_TextOnly_And_IsFullyConfigured_AllFiveSlots;

    [Test]
    procedure Test_IsConfigured_AllowsLocalProviderWithoutApiKey;
  end;

  /// <summary>
  /// Tests for TLLMMessage helpers.
  /// </summary>
  [TestFixture]
  TLLMMessageTests = class
  public
    [Test]
    procedure Test_System_User_Assistant_Constructors_Set_Role_And_Content;

    [Test]
    procedure Test_TierImageGen_DisplayName;
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

  [TestFixture]
  TLLMStorageFactoryTests = class
  public
    [Test]
    procedure Test_CreateWithConnection_WithoutStorageFactory_ShouldFailClearly;
    [Test]
    procedure Test_CreateWithStorageObject_WithoutStorageFactory_ShouldSucceed;
    [Test]
    procedure Test_CreateWithStorageInterface_ShouldSucceed;
  end;

  [TestFixture]
  TLLMHttpClientTransportTests = class
  public
    [Test]
    procedure Test_Send_Uses_Injected_Transport;

    [Test]
    procedure Test_Send_WithoutApiKey_OmitsAuthorizationHeader;

    [Test]
    procedure Test_GenerateImage_Uses_Injected_Transport;
  end;

  /// <summary>
  /// REVIEW5-FEAT-006: Tests for HTTP 200 error envelope parsing.
  /// Verifies that Send correctly handles HTTP 200 responses with error envelopes.
  /// </summary>
  [TestFixture]
  TLLMHttpErrorEnvelopeTests = class
  public
    [Test]
    procedure Test_Send_OpenAI_ErrorEnvelope_ExtractsError;

    [Test]
    procedure Test_Send_Anthropic_ErrorEnvelope_ExtractsError;

    [Test]
    procedure Test_Send_OpenAI_SuccessResponse_ParsesContent;

    [Test]
    procedure Test_Send_Anthropic_SuccessResponse_ParsesContent;
  end;

  {$IFDEF MSWINDOWS}
  /// <summary>
  /// Tests for LLM API key persistence through Windows Credential Manager.
  /// </summary>
  [TestFixture]
  TLLMCredentialStorageTests = class
  private const
    TEST_CONFIG = 'UnitTestCredArch016';
    TEST_TARGET = 'DeepBase_LLM_UnitTestCredArch016_ApiKey';
    TEST_API_KEY_TARGET = 'DeepBase_LLMApiKeys_Arch016';
  private
    FConnection: TFDConnection;
    FLLM: TDeepBaseLLM;

    procedure CreateTables;
    function ReadConfigApiKeyRef(const ConfigName: string): string;
    procedure InsertLLMConfig(const ConfigName, ApiKeyRef: string);
  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_SaveConfig_Stores_Credential_Reference_Not_Plain_Key;

    [Test]
    procedure Test_GetConfig_Resolves_Legacy_Raw_ApiKeyRef;

    [Test]
    procedure Test_GetConfig_Resolves_LLMApiKeys_Credential_Reference;
  end;
  {$ENDIF}

implementation

uses
  System.StrUtils,
  Data.DB,
  FireDAC.Stan.Param,
  DeepBase.Schema,
  DeepBase.Persistence.LLM.FireDAC
  , DeepBase.LLM.HTTP
  , DeepBase.LLM.Types
  , DeepBase.LLM.Config
  , DeepBase.Net.Transport
  , DeepBase.Config
  {$IFDEF MSWINDOWS}
  , DeepBase.Security.DPAPI
  {$ENDIF};

type
  TFakeLLMTransport = class(TInterfacedObject, IDeepBaseHttpTransport)
  public
    LastRequest: TDeepBaseHttpTransportRequest;
    Response: TDeepBaseHttpTransportResponse;
    CallCount: Integer;
    function Send(const ARequest: TDeepBaseHttpTransportRequest):
      TDeepBaseHttpTransportResponse;
  end;

  TMockDisconnectedLLMStorage = class(TInterfacedObject, ILLMStorage)
  public
    function IsConnected: Boolean;
    function TableExists(const TableName: string): Boolean;
    function TableHasColumn(const TableName, ColumnName: string): Boolean;
    function OpenDataSet(const SQL: string;
      const Params: array of TLLMStorageParam): TDataSet;
    function Execute(const SQL: string;
      const Params: array of TLLMStorageParam): Integer;
    function ExecuteScalar(const SQL: string;
      const Params: array of TLLMStorageParam): Variant;
    function IsPostgreSQL: Boolean;
  end;

function TFakeLLMTransport.Send(const ARequest: TDeepBaseHttpTransportRequest):
  TDeepBaseHttpTransportResponse;
begin
  Inc(CallCount);
  LastRequest := ARequest;
  Result := Response;
end;

function TMockDisconnectedLLMStorage.IsConnected: Boolean;
begin
  Result := False;
end;

function TMockDisconnectedLLMStorage.TableExists(const TableName: string): Boolean;
begin
  Result := False;
end;

function TMockDisconnectedLLMStorage.TableHasColumn(const TableName,
  ColumnName: string): Boolean;
begin
  Result := False;
end;

function TMockDisconnectedLLMStorage.OpenDataSet(const SQL: string;
  const Params: array of TLLMStorageParam): TDataSet;
begin
  raise EInvalidOp.Create('OpenDataSet should not be called for disconnected storage');
end;

function TMockDisconnectedLLMStorage.Execute(const SQL: string;
  const Params: array of TLLMStorageParam): Integer;
begin
  Result := 0;
end;

function TMockDisconnectedLLMStorage.ExecuteScalar(const SQL: string;
  const Params: array of TLLMStorageParam): Variant;
begin
  Result := 0;
end;

function TMockDisconnectedLLMStorage.IsPostgreSQL: Boolean;
begin
  Result := False;
end;

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

procedure TLLMMessageTests.Test_TierImageGen_DisplayName;
begin
  Assert.AreEqual('Image Generation', TierImageGen.DisplayName);
  Assert.AreEqual('Image Fallback', TierImageFallback.DisplayName);
end;

{ TLLMConfigStoreTests }

procedure TLLMConfigStoreTests.Test_BuiltInTiers_ExposeFiveDesktopSlots;
var
  Tiers: TArray<TModelTier>;
begin
  Tiers := TLLMConfigStore.BuiltInTiers;

  Assert.AreEqual<Integer>(5, Length(Tiers));
  Assert.AreEqual(string(TierSmart), string(Tiers[0]));
  Assert.AreEqual(string(TierBalanced), string(Tiers[1]));
  Assert.AreEqual(string(TierFast), string(Tiers[2]));
  Assert.AreEqual(string(TierImageGen), string(Tiers[3]));
  Assert.AreEqual(string(TierImageFallback), string(Tiers[4]));
end;

procedure TLLMConfigStoreTests.Test_TierModels_NormalizeLegacyVisionToImageGen;
var
  Store: TLLMConfigStore;
  Models: TArray<string>;
begin
  Store := TLLMConfigStore.Create;
  try
    Store.SetTierModels(string(TierVision), ['legacy-vision-model']);

    Models := Store.GetTierModels(string(TierImageGen));
    Assert.AreEqual<Integer>(1, Length(Models));
    Assert.AreEqual('legacy-vision-model', Models[0]);
  finally
    Store.Free;
  end;
end;

procedure TLLMConfigStoreTests.Test_Load_MigratesLegacyVisionTier;
var
  Store: TLLMConfigStore;
  Models: TArray<string>;
begin
  DeleteConfig('LLM.Providers');
  DeleteConfig('LLM.Tiers');
  DeleteConfig('LLM.Keys');
  try
    Store := TLLMConfigStore.Create;
    try
      Store.LoadTierModelsJson('{"vision":["old-image-model"],"vision_fallback":["fallback-model"]}');

      Models := Store.GetTierModels(string(TierImageGen));
      Assert.AreEqual<Integer>(1, Length(Models));
      Assert.AreEqual('old-image-model', Models[0]);
      Models := Store.GetTierModels(string(TierImageFallback));
      Assert.AreEqual<Integer>(1, Length(Models));
      Assert.AreEqual('fallback-model', Models[0]);
    finally
      Store.Free;
    end;
  finally
    DeleteConfig('LLM.Providers');
    DeleteConfig('LLM.Tiers');
    DeleteConfig('LLM.Keys');
  end;
end;

procedure TLLMConfigStoreTests.Test_IsConfigured_TextOnly_And_IsFullyConfigured_AllFiveSlots;
var
  Store: TLLMConfigStore;
  Provider: TProviderConfig;
begin
  Store := TLLMConfigStore.Create;
  try
    Provider.Name := 'OpenAI';
    Provider.Endpoint := 'https://api.example.com/v1';
    Provider.ApiFormat := 'openai';
    Provider.Priority := 0;
    Store.AddProvider(Provider, 'sk-test');

    Store.SetTierModels(string(TierSmart), ['smart-model']);
    Store.SetTierModels(string(TierBalanced), ['balanced-model']);
    Store.SetTierModels(string(TierFast), ['fast-model']);

    Assert.IsTrue(Store.IsConfigured);
    Assert.IsFalse(Store.IsFullyConfigured);

    Store.SetTierModels(string(TierImageGen), ['image-model']);
    Store.SetTierModels(string(TierImageFallback), ['fallback-model']);

    Assert.IsTrue(Store.IsFullyConfigured);
  finally
    Store.Free;
  end;
end;

procedure TLLMConfigStoreTests.Test_IsConfigured_AllowsLocalProviderWithoutApiKey;
var
  Store: TLLMConfigStore;
  Provider: TProviderConfig;
begin
  Store := TLLMConfigStore.Create;
  try
    Provider.Name := 'Ollama';
    Provider.Endpoint := 'http://localhost:11434/v1';
    Provider.ApiFormat := 'openai';
    Provider.Priority := 0;
    Store.AddProvider(Provider, '');

    Store.SetTierModels(string(TierSmart), ['llama3.1']);
    Store.SetTierModels(string(TierBalanced), ['llama3.1']);
    Store.SetTierModels(string(TierFast), ['llama3.1']);

    Assert.IsTrue(Store.IsConfigured);
  finally
    Store.Free;
  end;
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

{ TLLMStorageFactoryTests }

procedure TLLMStorageFactoryTests.Test_CreateWithConnection_WithoutStorageFactory_ShouldFailClearly;
var
  Conn: TFDConnection;
  LLM: TDeepBaseLLM;
  RaisedMsg: string;
begin
  TDeepBaseLLM.SetStorageFactory(nil);
  try
    Conn := TFDConnection.Create(nil);
    try
      Conn.DriverName := 'SQLite';
      Conn.Params.Database := ':memory:';
      Conn.Connected := True;

      LLM := nil;
      RaisedMsg := '';
      try
        LLM := TDeepBaseLLM.Create(Conn);
        Assert.Fail('Expected EInvalidOp when LLM storage factory is missing');
      except
        on E: EInvalidOp do
          RaisedMsg := E.Message;
      end;
      LLM.Free;

      Assert.IsTrue(RaisedMsg.Contains('DeepBase.Persistence.LLM.FireDAC'),
        'Error should point to LLM FireDAC adapter registration');
    finally
      Conn.Free;
    end;
  finally
    RegisterLLMStorageFactory;
  end;
end;

procedure TLLMStorageFactoryTests.Test_CreateWithStorageObject_WithoutStorageFactory_ShouldSucceed;
var
  StorageObj: TObject;
  LLM: TDeepBaseLLM;
begin
  TDeepBaseLLM.SetStorageFactory(nil);
  try
    StorageObj := TMockDisconnectedLLMStorage.Create;
    LLM := nil;
    try
      LLM := TDeepBaseLLM.Create(StorageObj);
      Assert.IsNotNull(LLM, 'LLM should be created when connection object implements ILLMStorage');
    finally
      LLM.Free;
    end;
  finally
    RegisterLLMStorageFactory;
  end;
end;

procedure TLLMStorageFactoryTests.Test_CreateWithStorageInterface_ShouldSucceed;
var
  Storage: ILLMStorage;
  LLM: TDeepBaseLLM;
begin
  TDeepBaseLLM.SetStorageFactory(nil);
  try
    Storage := TMockDisconnectedLLMStorage.Create;
    LLM := nil;
    try
      LLM := TDeepBaseLLM.Create(Storage);
      Assert.IsNotNull(LLM, 'LLM should be created when storage interface is injected directly');
    finally
      LLM.Free;
    end;
  finally
    RegisterLLMStorageFactory;
  end;
end;

{ TLLMHttpClientTransportTests }

procedure TLLMHttpClientTransportTests.Test_Send_Uses_Injected_Transport;
var
  Client: TLLMHttpClient;
  Fake: TFakeLLMTransport;
  Transport: IDeepBaseHttpTransport;
  Messages: TArray<DeepBase.LLM.Types.TChatMessage>;
  ChatResult: TChatResult;
  I: Integer;
  FoundAuth: Boolean;
begin
  Fake := TFakeLLMTransport.Create;
  Transport := Fake as IDeepBaseHttpTransport;
  Fake.Response := TDeepBaseHttpTransportResponse.Create(200,
    '{"choices":[{"message":{"content":"ok"}}],"usage":{"prompt_tokens":2,"completion_tokens":1,"total_tokens":3}}');

  Client := TLLMHttpClient.Create(5);
  try
    Client.HttpTransport := Transport;
    SetLength(Messages, 1);
    Messages[0] := DeepBase.LLM.Types.TChatMessage.User('hello');

    Assert.IsTrue(Client.Send('https://llm.example.com/v1', 'sk_test',
      'openai', 'gpt-test', Messages, 32, 0.2, ChatResult));
    Assert.AreEqual(1, Fake.CallCount);
    Assert.AreEqual(dbhmPost, Fake.LastRequest.Method);
    Assert.AreEqual('https://llm.example.com/v1/chat/completions',
      Fake.LastRequest.Url);
    Assert.IsTrue(Pos('"model":"gpt-test"', Fake.LastRequest.Body) > 0);
    Assert.AreEqual('ok', ChatResult.Content);

    FoundAuth := False;
    for I := 0 to High(Fake.LastRequest.Headers) do
      if SameText(Fake.LastRequest.Headers[I].Name, 'Authorization') and
         (Fake.LastRequest.Headers[I].Value = 'Bearer sk_test') then
        FoundAuth := True;
    Assert.IsTrue(FoundAuth);
  finally
    Client.Free;
  end;
end;

procedure TLLMHttpClientTransportTests.Test_Send_WithoutApiKey_OmitsAuthorizationHeader;
var
  Client: TLLMHttpClient;
  Fake: TFakeLLMTransport;
  Transport: IDeepBaseHttpTransport;
  Messages: TArray<DeepBase.LLM.Types.TChatMessage>;
  ChatResult: TChatResult;
  I: Integer;
  FoundAuth: Boolean;
begin
  Fake := TFakeLLMTransport.Create;
  Transport := Fake as IDeepBaseHttpTransport;
  Fake.Response := TDeepBaseHttpTransportResponse.Create(200,
    '{"choices":[{"message":{"content":"ok"}}],"usage":{"prompt_tokens":2,"completion_tokens":1,"total_tokens":3}}');

  Client := TLLMHttpClient.Create(5);
  try
    Client.HttpTransport := Transport;
    SetLength(Messages, 1);
    Messages[0] := DeepBase.LLM.Types.TChatMessage.User('hello');

    Assert.IsTrue(Client.Send('http://localhost:11434/v1', '',
      'openai', 'llama3.1', Messages, 32, 0.2, ChatResult));

    FoundAuth := False;
    for I := 0 to High(Fake.LastRequest.Headers) do
      if SameText(Fake.LastRequest.Headers[I].Name, 'Authorization') then
        FoundAuth := True;
    Assert.IsFalse(FoundAuth, 'Empty API key should not send Authorization');
    Assert.AreEqual('ok', ChatResult.Content);
  finally
    Client.Free;
  end;
end;

procedure TLLMHttpClientTransportTests.Test_GenerateImage_Uses_Injected_Transport;
var
  Client: TLLMHttpClient;
  Fake: TFakeLLMTransport;
  Transport: IDeepBaseHttpTransport;
  ImageResult: TImageGenerationResult;
begin
  Fake := TFakeLLMTransport.Create;
  Transport := Fake as IDeepBaseHttpTransport;
  Fake.Response := TDeepBaseHttpTransportResponse.Create(200,
    '{"data":[{"b64_json":"iVBORw0KGgo="}]}');

  Client := TLLMHttpClient.Create(5);
  try
    Client.HttpTransport := Transport;
    Assert.IsTrue(Client.GenerateImage('https://llm.example.com/v1',
      'sk_test', 'openai', 'gpt-image-test', 'draw a cat', '1024x1024',
      ImageResult));
    Assert.AreEqual(1, Fake.CallCount);
    Assert.AreEqual(dbhmPost, Fake.LastRequest.Method);
    Assert.AreEqual('https://llm.example.com/v1/images/generations',
      Fake.LastRequest.Url);
    Assert.IsTrue(Pos('"model":"gpt-image-test"', Fake.LastRequest.Body) > 0);
    Assert.IsTrue(Pos('"prompt":"draw a cat"', Fake.LastRequest.Body) > 0);
    Assert.AreEqual('iVBORw0KGgo=', ImageResult.ImageBase64);
    Assert.AreEqual('gpt-image-test', ImageResult.ModelUsed);
  finally
    Client.Free;
  end;
end;

{ TLLMHttpErrorEnvelopeTests }

procedure TLLMHttpErrorEnvelopeTests.Test_Send_OpenAI_ErrorEnvelope_ExtractsError;
var
  Client: TLLMHttpClient;
  Fake: TFakeLLMTransport;
  Transport: IDeepBaseHttpTransport;
  Result: TChatResult;
  Messages: TArray<TChatMessage>;
begin
  // REVIEW5-FEAT-006: HTTP 200 response with error envelope should extract error info
  Fake := TFakeLLMTransport.Create;
  Transport := Fake as IDeepBaseHttpTransport;

  // OpenAI error envelope format
  Fake.Response := TDeepBaseHttpTransportResponse.Create(200,
    '{"error":{"message":"Rate limit exceeded","type":"rate_limit_error","code":"rate_limit_exceeded"}}');

  Client := TLLMHttpClient.Create(5);
  try
    Client.HttpTransport := Transport;
    SetLength(Messages, 1);
    Messages[0].Role := 'user';
    Messages[0].Content := 'Hello';

    Assert.IsFalse(Client.Send('https://api.openai.com/v1', 'sk_test', 'openai',
      'gpt-4', Messages, 100, 0.7, Result),
      'Send should return False for error envelope');
    Assert.IsFalse(Result.Success,
      'Result.Success should be False for error envelope');
    Assert.AreEqual('Rate limit exceeded', Result.ErrorMessage,
      'ErrorMessage should be extracted from error.message');
    Assert.AreEqual('rate_limit_exceeded', Result.ErrorCode,
      'ErrorCode should be extracted from error.code');
  finally
    Client.Free;
  end;
end;

procedure TLLMHttpErrorEnvelopeTests.Test_Send_Anthropic_ErrorEnvelope_ExtractsError;
var
  Client: TLLMHttpClient;
  Fake: TFakeLLMTransport;
  Transport: IDeepBaseHttpTransport;
  Result: TChatResult;
  Messages: TArray<TChatMessage>;
begin
  // REVIEW5-FEAT-006: HTTP 200 response with error envelope should extract error info
  Fake := TFakeLLMTransport.Create;
  Transport := Fake as IDeepBaseHttpTransport;

  // Anthropic error envelope format
  Fake.Response := TDeepBaseHttpTransportResponse.Create(200,
    '{"type":"error","error":{"type":"invalid_request_error","message":"Invalid API key"}}');

  Client := TLLMHttpClient.Create(5);
  try
    Client.HttpTransport := Transport;
    SetLength(Messages, 1);
    Messages[0].Role := 'user';
    Messages[0].Content := 'Hello';

    Assert.IsFalse(Client.Send('https://api.anthropic.com/v1', 'sk_test', 'anthropic',
      'claude-3', Messages, 100, 0.7, Result),
      'Send should return False for error envelope');
    Assert.IsFalse(Result.Success,
      'Result.Success should be False for error envelope');
    Assert.AreEqual('Invalid API key', Result.ErrorMessage,
      'ErrorMessage should be extracted from error.message');
    Assert.AreEqual('invalid_request_error', Result.ErrorCode,
      'ErrorCode should be extracted from error.type');
  finally
    Client.Free;
  end;
end;

procedure TLLMHttpErrorEnvelopeTests.Test_Send_OpenAI_SuccessResponse_ParsesContent;
var
  Client: TLLMHttpClient;
  Fake: TFakeLLMTransport;
  Transport: IDeepBaseHttpTransport;
  Result: TChatResult;
  Messages: TArray<TChatMessage>;
begin
  // REVIEW5-FEAT-006: Normal success response should parse correctly
  Fake := TFakeLLMTransport.Create;
  Transport := Fake as IDeepBaseHttpTransport;

  Fake.Response := TDeepBaseHttpTransportResponse.Create(200,
    '{"choices":[{"message":{"content":"Hello, world!"}}],"usage":{"prompt_tokens":10,"completion_tokens":5,"total_tokens":15}}');

  Client := TLLMHttpClient.Create(5);
  try
    Client.HttpTransport := Transport;
    SetLength(Messages, 1);
    Messages[0].Role := 'user';
    Messages[0].Content := 'Hello';

    Assert.IsTrue(Client.Send('https://api.openai.com/v1', 'sk_test', 'openai',
      'gpt-4', Messages, 100, 0.7, Result),
      'Send should return True for success response');
    Assert.IsTrue(Result.Success,
      'Result.Success should be True for success response');
    Assert.AreEqual('Hello, world!', Result.Content,
      'Content should be extracted from choices[0].message.content');
    Assert.AreEqual(10, Result.PromptTokens,
      'PromptTokens should be extracted from usage.prompt_tokens');
    Assert.AreEqual(5, Result.CompletionTokens,
      'CompletionTokens should be extracted from usage.completion_tokens');
    Assert.AreEqual(15, Result.TotalTokens,
      'TotalTokens should be extracted from usage.total_tokens');
  finally
    Client.Free;
  end;
end;

procedure TLLMHttpErrorEnvelopeTests.Test_Send_Anthropic_SuccessResponse_ParsesContent;
var
  Client: TLLMHttpClient;
  Fake: TFakeLLMTransport;
  Transport: IDeepBaseHttpTransport;
  Result: TChatResult;
  Messages: TArray<TChatMessage>;
begin
  // REVIEW5-FEAT-006: Normal success response should parse correctly
  Fake := TFakeLLMTransport.Create;
  Transport := Fake as IDeepBaseHttpTransport;

  Fake.Response := TDeepBaseHttpTransportResponse.Create(200,
    '{"content":[{"type":"text","text":"Hello from Claude!"}],"usage":{"input_tokens":8,"output_tokens":4}}');

  Client := TLLMHttpClient.Create(5);
  try
    Client.HttpTransport := Transport;
    SetLength(Messages, 1);
    Messages[0].Role := 'user';
    Messages[0].Content := 'Hello';

    Assert.IsTrue(Client.Send('https://api.anthropic.com/v1', 'sk_test', 'anthropic',
      'claude-3', Messages, 100, 0.7, Result),
      'Send should return True for success response');
    Assert.IsTrue(Result.Success,
      'Result.Success should be True for success response');
    Assert.AreEqual('Hello from Claude!', Result.Content,
      'Content should be extracted from content[0].text');
    Assert.AreEqual(8, Result.PromptTokens,
      'PromptTokens should be extracted from usage.input_tokens');
    Assert.AreEqual(4, Result.CompletionTokens,
      'CompletionTokens should be extracted from usage.output_tokens');
  finally
    Client.Free;
  end;
end;

{$IFDEF MSWINDOWS}
{ TLLMCredentialStorageTests }

procedure TLLMCredentialStorageTests.Setup;
begin
  TCredentialManager.DeleteCredential(TEST_TARGET);
  TCredentialManager.DeleteCredential(TEST_API_KEY_TARGET);

  FConnection := TFDConnection.Create(nil);
  FConnection.DriverName := 'SQLite';
  FConnection.Params.Database := ':memory:';
  FConnection.Open;

  CreateTables;
  FLLM := TDeepBaseLLM.Create(FConnection);
end;

procedure TLLMCredentialStorageTests.TearDown;
begin
  if Assigned(FLLM) then
  begin
    FLLM.DeleteConfig(TEST_CONFIG);
    FLLM.Free;
  end;

  if Assigned(FConnection) then
    FConnection.Free;

  TCredentialManager.DeleteCredential(TEST_TARGET);
  TCredentialManager.DeleteCredential(TEST_API_KEY_TARGET);
end;

procedure TLLMCredentialStorageTests.CreateTables;
begin
  FConnection.ExecSQL(SQL_TIER2_LLM_CONFIG);
  FConnection.ExecSQL(SQL_TIER2_LLM_API_KEYS);
end;

function TLLMCredentialStorageTests.ReadConfigApiKeyRef(const ConfigName: string): string;
var
  Query: TFDQuery;
begin
  Result := '';
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT ApiKeyRef FROM LLMConfig WHERE Name = :Name';
    Query.ParamByName('Name').AsString := ConfigName;
    Query.Open;
    if not Query.Eof then
      Result := Query.FieldByName('ApiKeyRef').AsString;
  finally
    Query.Free;
  end;
end;

procedure TLLMCredentialStorageTests.InsertLLMConfig(const ConfigName, ApiKeyRef: string);
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text :=
      'INSERT INTO LLMConfig ' +
      '(Name, Description, ProviderCode, ModelId, BaseUrl, ApiKeyRef, IsEnabled) ' +
      'VALUES (:Name, '''', ''openai'', ''gpt-test'', '''', :ApiKeyRef, 1)';
    Query.ParamByName('Name').AsString := ConfigName;
    Query.ParamByName('ApiKeyRef').AsString := ApiKeyRef;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

procedure TLLMCredentialStorageTests.Test_SaveConfig_Stores_Credential_Reference_Not_Plain_Key;
const
  TEST_SECRET = 'sk-arch016-save-secret';
var
  Config, Loaded: TLLMConfig;
  StoredRef: string;
begin
  Config.Init;
  Config.Name := TEST_CONFIG;
  Config.Provider := lpOpenAI;
  Config.Model := 'gpt-test';
  Config.ApiKey := TEST_SECRET;

  FLLM.SaveConfig(Config);

  StoredRef := ReadConfigApiKeyRef(TEST_CONFIG);
  Assert.IsTrue(StartsText('credman:', StoredRef), 'Database should store only a credential reference');
  Assert.AreNotEqual(TEST_SECRET, StoredRef, 'Database must not store the plain API key');
  Assert.AreEqual(TEST_SECRET, TCredentialManager.GetCredential(TEST_TARGET, ''));

  Loaded := FLLM.GetConfig(TEST_CONFIG);
  Assert.AreEqual(TEST_SECRET, Loaded.ApiKey);
end;

procedure TLLMCredentialStorageTests.Test_GetConfig_Resolves_Legacy_Raw_ApiKeyRef;
const
  LEGACY_SECRET = 'sk-arch016-legacy-secret';
var
  Config: TLLMConfig;
  StoredRef: string;
begin
  InsertLLMConfig(TEST_CONFIG, LEGACY_SECRET);
  FLLM.RefreshConfigCache;

  Config := FLLM.GetConfig(TEST_CONFIG);
  Assert.AreEqual(LEGACY_SECRET, Config.ApiKey);

  FLLM.SaveConfig(Config);
  StoredRef := ReadConfigApiKeyRef(TEST_CONFIG);
  Assert.IsTrue(StartsText('credman:', StoredRef), 'Saving a legacy config should migrate it to Credential Manager');
  Assert.AreNotEqual(LEGACY_SECRET, StoredRef, 'Migrated config should not keep the plain API key in DB');
  Assert.AreEqual(LEGACY_SECRET, TCredentialManager.GetCredential(TEST_TARGET, ''));
end;

procedure TLLMCredentialStorageTests.Test_GetConfig_Resolves_LLMApiKeys_Credential_Reference;
const
  API_KEY_NAME = 'PrimaryTestKey';
  API_KEY_SECRET = 'sk-arch016-apikeys-secret';
var
  Query: TFDQuery;
  Config: TLLMConfig;
begin
  TCredentialManager.SaveCredential(TEST_API_KEY_TARGET, '', API_KEY_SECRET);

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text :=
      'INSERT INTO LLMApiKeys ' +
      '(Name, ProviderCode, ApiKey, IsEncrypted, EncryptionMethod, IsEnabled) ' +
      'VALUES (:Name, ''openai'', :ApiKey, 1, ''CREDMAN'', 1)';
    Query.ParamByName('Name').AsString := API_KEY_NAME;
    Query.ParamByName('ApiKey').AsString := 'credman:' + TEST_API_KEY_TARGET;
    Query.ExecSQL;
  finally
    Query.Free;
  end;

  InsertLLMConfig(TEST_CONFIG, API_KEY_NAME);
  FLLM.RefreshConfigCache;

  Config := FLLM.GetConfig(TEST_CONFIG);
  Assert.AreEqual(API_KEY_SECRET, Config.ApiKey);

  Config.ApiKey := API_KEY_NAME;
  FLLM.SaveConfig(Config);
  Assert.AreEqual(API_KEY_NAME, ReadConfigApiKeyRef(TEST_CONFIG),
    'Saving an LLMApiKeys.Name reference should preserve the reference');
end;
{$ENDIF}

initialization
  TDUnitX.RegisterTestFixture(TLLMConfigTests);
  TDUnitX.RegisterTestFixture(TLLMConfigStoreTests);
  TDUnitX.RegisterTestFixture(TLLMMessageTests);
  TDUnitX.RegisterTestFixture(TLLMChatResponseTests);
  TDUnitX.RegisterTestFixture(TLLMRequestOptionsTests);
  TDUnitX.RegisterTestFixture(TLLMPromptTemplateTests);
  TDUnitX.RegisterTestFixture(TLLMStorageFactoryTests);
  TDUnitX.RegisterTestFixture(TLLMHttpClientTransportTests);
  TDUnitX.RegisterTestFixture(TLLMHttpErrorEnvelopeTests);
  {$IFDEF MSWINDOWS}
  TDUnitX.RegisterTestFixture(TLLMCredentialStorageTests);
  {$ENDIF}

end.
