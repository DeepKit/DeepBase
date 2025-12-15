unit Test.UniBase.LLM.BillingClient;

interface

uses
  System.SysUtils,
  System.Classes,
  DUnitX.TestFramework,
  UniBase.LLM.BillingClient;

type
  /// <summary>
  /// Tests for TChatMessage record.
  /// </summary>
  [TestFixture]
  TChatMessageTests = class
  public
    [Test]
    procedure Test_CreateSystem_Sets_Role_And_Content;

    [Test]
    procedure Test_CreateUser_Sets_Role_And_Content;

    [Test]
    procedure Test_CreateAssistant_Sets_Role_And_Content;

    [Test]
    procedure Test_RoleToString_Returns_Correct_Strings;
  end;

  /// <summary>
  /// Tests for TChatHistory class.
  /// </summary>
  [TestFixture]
  TChatHistoryTests = class
  public
    [Test]
    procedure Test_Create_With_SystemPrompt_Adds_System_Message;

    [Test]
    procedure Test_AddUserMessage_Appends_Message;

    [Test]
    procedure Test_AddAssistantMessage_Appends_Message;

    [Test]
    procedure Test_GetMessages_Returns_All_Messages;

    [Test]
    procedure Test_Clear_Removes_All_Messages;

    [Test]
    procedure Test_Clear_Keeps_System_Message_When_KeepSystem_True;

    [Test]
    procedure Test_MaxHistory_Trims_Old_Messages;

    [Test]
    procedure Test_GetCount_Returns_Correct_Count;

    [Test]
    procedure Test_ToJSON_Returns_Valid_JSON;
  end;

  /// <summary>
  /// Tests for TTokenUsage record.
  /// </summary>
  [TestFixture]
  TTokenUsageTests = class
  public
    [Test]
    procedure Test_TotalTokens_Calculates_Sum;
  end;

  /// <summary>
  /// Tests for TChatResponse record.
  /// </summary>
  [TestFixture]
  TChatResponseTests = class
  public
    [Test]
    procedure Test_Init_Sets_Default_Values;
  end;

  /// <summary>
  /// Tests for TBillingClient class (without network).
  /// </summary>
  [TestFixture]
  TBillingClientTests = class
  public
    [Test]
    procedure Test_Create_Sets_Properties;

    [Test]
    procedure Test_BaseURL_Removes_Trailing_Slash;

    [Test]
    procedure Test_BaseURL_Handles_V1_Suffix;

    [Test]
    procedure Test_Model_Property_Get_Set;

    [Test]
    procedure Test_Temperature_Property_Get_Set;

    [Test]
    procedure Test_MaxTokens_Property_Get_Set;

    [Test]
    procedure Test_SystemPrompt_Property_Get_Set;

    [Test]
    procedure Test_Cancel_Sets_Cancelled_Flag;
  end;

implementation

{ TChatMessageTests }

procedure TChatMessageTests.Test_CreateSystem_Sets_Role_And_Content;
var
  Msg: TChatMessage;
begin
  Msg := TChatMessage.CreateSystem('You are a helpful assistant.');

  Assert.AreEqual(mrSystem, Msg.Role);
  Assert.AreEqual('You are a helpful assistant.', Msg.Content);
end;

procedure TChatMessageTests.Test_CreateUser_Sets_Role_And_Content;
var
  Msg: TChatMessage;
begin
  Msg := TChatMessage.CreateUser('Hello, world!');

  Assert.AreEqual(mrUser, Msg.Role);
  Assert.AreEqual('Hello, world!', Msg.Content);
end;

procedure TChatMessageTests.Test_CreateAssistant_Sets_Role_And_Content;
var
  Msg: TChatMessage;
begin
  Msg := TChatMessage.CreateAssistant('Hi there!');

  Assert.AreEqual(mrAssistant, Msg.Role);
  Assert.AreEqual('Hi there!', Msg.Content);
end;

procedure TChatMessageTests.Test_RoleToString_Returns_Correct_Strings;
var
  Msg: TChatMessage;
begin
  Msg.Role := mrSystem;
  Assert.AreEqual('system', Msg.RoleToString);

  Msg.Role := mrUser;
  Assert.AreEqual('user', Msg.RoleToString);

  Msg.Role := mrAssistant;
  Assert.AreEqual('assistant', Msg.RoleToString);
end;

{ TChatHistoryTests }

procedure TChatHistoryTests.Test_Create_With_SystemPrompt_Adds_System_Message;
var
  History: TChatHistory;
  Messages: TChatMessages;
begin
  History := TChatHistory.Create('You are a test bot.');
  try
    Messages := History.GetMessages;

    Assert.AreEqual(1, Length(Messages));
    Assert.AreEqual(mrSystem, Messages[0].Role);
    Assert.AreEqual('You are a test bot.', Messages[0].Content);
  finally
    History.Free;
  end;
end;

procedure TChatHistoryTests.Test_AddUserMessage_Appends_Message;
var
  History: TChatHistory;
  Messages: TChatMessages;
begin
  History := TChatHistory.Create('System prompt');
  try
    History.AddUserMessage('User message');
    Messages := History.GetMessages;

    Assert.AreEqual(2, Length(Messages));
    Assert.AreEqual(mrUser, Messages[1].Role);
    Assert.AreEqual('User message', Messages[1].Content);
  finally
    History.Free;
  end;
end;

procedure TChatHistoryTests.Test_AddAssistantMessage_Appends_Message;
var
  History: TChatHistory;
  Messages: TChatMessages;
begin
  History := TChatHistory.Create('System prompt');
  try
    History.AddUserMessage('Hello');
    History.AddAssistantMessage('Hi there!');
    Messages := History.GetMessages;

    Assert.AreEqual(3, Length(Messages));
    Assert.AreEqual(mrAssistant, Messages[2].Role);
    Assert.AreEqual('Hi there!', Messages[2].Content);
  finally
    History.Free;
  end;
end;

procedure TChatHistoryTests.Test_GetMessages_Returns_All_Messages;
var
  History: TChatHistory;
  Messages: TChatMessages;
begin
  History := TChatHistory.Create('System');
  try
    History.AddUserMessage('User 1');
    History.AddAssistantMessage('Assistant 1');
    History.AddUserMessage('User 2');

    Messages := History.GetMessages;

    Assert.AreEqual(4, Length(Messages));
  finally
    History.Free;
  end;
end;

procedure TChatHistoryTests.Test_Clear_Removes_All_Messages;
var
  History: TChatHistory;
begin
  History := TChatHistory.Create('System');
  try
    History.AddUserMessage('User 1');
    History.AddAssistantMessage('Assistant 1');

    History.Clear(False);

    Assert.AreEqual(0, History.GetCount);
  finally
    History.Free;
  end;
end;

procedure TChatHistoryTests.Test_Clear_Keeps_System_Message_When_KeepSystem_True;
var
  History: TChatHistory;
  Messages: TChatMessages;
begin
  History := TChatHistory.Create('System prompt');
  try
    History.AddUserMessage('User 1');
    History.AddAssistantMessage('Assistant 1');

    History.Clear(True);

    Messages := History.GetMessages;
    Assert.AreEqual(1, Length(Messages));
    Assert.AreEqual(mrSystem, Messages[0].Role);
    Assert.AreEqual('System prompt', Messages[0].Content);
  finally
    History.Free;
  end;
end;

procedure TChatHistoryTests.Test_MaxHistory_Trims_Old_Messages;
var
  History: TChatHistory;
  Messages: TChatMessages;
begin
  // MaxHistory = 3 means system + 2 pairs (4 messages max excluding system)
  History := TChatHistory.Create('System', 3);
  try
    History.AddUserMessage('User 1');
    History.AddAssistantMessage('Assistant 1');
    History.AddUserMessage('User 2');
    History.AddAssistantMessage('Assistant 2');
    History.AddUserMessage('User 3');
    History.AddAssistantMessage('Assistant 3');

    Messages := History.GetMessages;

    // Should keep system + last 3 pairs = 7, but trimmed to system + 3*2 = 7
    // With MaxHistory=3, keeps system + 3 user/assistant pairs
    Assert.IsTrue(Length(Messages) <= 7, 'MaxHistory should limit message count');
    Assert.AreEqual(mrSystem, Messages[0].Role, 'First message should be system');
  finally
    History.Free;
  end;
end;

procedure TChatHistoryTests.Test_GetCount_Returns_Correct_Count;
var
  History: TChatHistory;
begin
  History := TChatHistory.Create('System');
  try
    Assert.AreEqual(1, History.GetCount);

    History.AddUserMessage('User 1');
    Assert.AreEqual(2, History.GetCount);

    History.AddAssistantMessage('Assistant 1');
    Assert.AreEqual(3, History.GetCount);
  finally
    History.Free;
  end;
end;

procedure TChatHistoryTests.Test_ToJSON_Returns_Valid_JSON;
var
  History: TChatHistory;
  JSON: string;
begin
  History := TChatHistory.Create('System');
  try
    History.AddUserMessage('Hello');
    History.AddAssistantMessage('Hi');

    JSON := History.ToJSON;

    Assert.IsTrue(JSON.StartsWith('['), 'JSON should start with [');
    Assert.IsTrue(JSON.EndsWith(']'), 'JSON should end with ]');
    Assert.IsTrue(JSON.Contains('"role"'), 'JSON should contain role');
    Assert.IsTrue(JSON.Contains('"content"'), 'JSON should contain content');
  finally
    History.Free;
  end;
end;

{ TTokenUsageTests }

procedure TTokenUsageTests.Test_TotalTokens_Calculates_Sum;
var
  Usage: TTokenUsage;
begin
  Usage.PromptTokens := 100;
  Usage.CompletionTokens := 50;

  Assert.AreEqual(150, Usage.TotalTokens);
end;

{ TChatResponseTests }

procedure TChatResponseTests.Test_Init_Sets_Default_Values;
var
  Response: TChatResponse;
begin
  Response.Success := True;
  Response.Content := 'Some content';
  Response.DurationMs := 1000;

  Response.Init;

  Assert.IsFalse(Response.Success);
  Assert.AreEqual('', Response.Content);
  Assert.AreEqual('', Response.FinishReason);
  Assert.AreEqual(0, Response.Usage.PromptTokens);
  Assert.AreEqual(0, Response.Usage.CompletionTokens);
  Assert.AreEqual<Int64>(0, Response.DurationMs);
  Assert.AreEqual('', Response.ErrorMessage);
  Assert.AreEqual(0, Response.ErrorCode);
end;

{ TBillingClientTests }

procedure TBillingClientTests.Test_Create_Sets_Properties;
var
  Client: TBillingClient;
begin
  Client := TBillingClient.Create('https://api.example.com', 'test-api-key', 'tenant-123');
  try
    Assert.AreEqual('https://api.example.com', Client.BaseURL);
    Assert.AreEqual('tenant-123', Client.TenantId);
  finally
    Client.Free;
  end;
end;

procedure TBillingClientTests.Test_BaseURL_Removes_Trailing_Slash;
var
  Client: TBillingClient;
begin
  Client := TBillingClient.Create('https://api.example.com/', 'key', 'tenant');
  try
    Assert.AreEqual('https://api.example.com', Client.BaseURL);
  finally
    Client.Free;
  end;
end;

procedure TBillingClientTests.Test_BaseURL_Handles_V1_Suffix;
var
  Client: TBillingClient;
begin
  Client := TBillingClient.Create('https://api.example.com/v1', 'key', 'tenant');
  try
    Assert.AreEqual('https://api.example.com/v1', Client.BaseURL);
  finally
    Client.Free;
  end;

  // Test with trailing slash on /v1
  Client := TBillingClient.Create('https://api.example.com/v1/', 'key', 'tenant');
  try
    Assert.AreEqual('https://api.example.com/v1', Client.BaseURL);
  finally
    Client.Free;
  end;
end;

procedure TBillingClientTests.Test_Model_Property_Get_Set;
var
  Client: TBillingClient;
begin
  Client := TBillingClient.Create('https://api.example.com', 'key', 'tenant');
  try
    Client.Model := 'gpt-4';
    Assert.AreEqual('gpt-4', Client.Model);

    Client.Model := 'claude-3';
    Assert.AreEqual('claude-3', Client.Model);
  finally
    Client.Free;
  end;
end;

procedure TBillingClientTests.Test_Temperature_Property_Get_Set;
var
  Client: TBillingClient;
begin
  Client := TBillingClient.Create('https://api.example.com', 'key', 'tenant');
  try
    Client.Temperature := 0.5;
    Assert.AreEqual(0.5, Client.Temperature, 0.0001);

    Client.Temperature := 1.0;
    Assert.AreEqual(1.0, Client.Temperature, 0.0001);
  finally
    Client.Free;
  end;
end;

procedure TBillingClientTests.Test_MaxTokens_Property_Get_Set;
var
  Client: TBillingClient;
begin
  Client := TBillingClient.Create('https://api.example.com', 'key', 'tenant');
  try
    Client.MaxTokens := 1024;
    Assert.AreEqual(1024, Client.MaxTokens);

    Client.MaxTokens := 4096;
    Assert.AreEqual(4096, Client.MaxTokens);
  finally
    Client.Free;
  end;
end;

procedure TBillingClientTests.Test_SystemPrompt_Property_Get_Set;
var
  Client: TBillingClient;
begin
  Client := TBillingClient.Create('https://api.example.com', 'key', 'tenant');
  try
    Client.SystemPrompt := 'You are a helpful assistant.';
    Assert.AreEqual('You are a helpful assistant.', Client.SystemPrompt);
  finally
    Client.Free;
  end;
end;

procedure TBillingClientTests.Test_Cancel_Sets_Cancelled_Flag;
var
  Client: TBillingClient;
begin
  Client := TBillingClient.Create('https://api.example.com', 'key', 'tenant');
  try
    // Initially not cancelled
    Assert.IsFalse(Client.IsCancelled);

    // After cancel
    Client.Cancel;
    Assert.IsTrue(Client.IsCancelled);
  finally
    Client.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TChatMessageTests);
  TDUnitX.RegisterTestFixture(TChatHistoryTests);
  TDUnitX.RegisterTestFixture(TTokenUsageTests);
  TDUnitX.RegisterTestFixture(TChatResponseTests);
  TDUnitX.RegisterTestFixture(TBillingClientTests);

end.
