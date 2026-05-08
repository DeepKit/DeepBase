program TestLLMClient;
{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  DeepBase.LLM.BillingClient in '..\Core\DeepBase.LLM.BillingClient.pas',
  DeepBase.Security.DPAPI in '..\Core\DeepBase.Security.DPAPI.pas';

const
  // 硅基流动 API (OpenAI 兼容)
  BASE_URL = 'https://api.siliconflow.cn/v1';
  // 使用环境变量或直接填�?API Key 测试
  API_KEY = ''; // 需要填入实际的 API Key
  TENANT_ID = 'test';

procedure TestDPAPI;
var
  Original, Encrypted, Decrypted: string;
begin
  WriteLn('=== 测试 DPAPI ===');
  Original := 'Hello, this is a secret message!';
  WriteLn('原始文本: ', Original);
  
  try
    Encrypted := TDPAPIHelper.ProtectString(Original);
    WriteLn('加密�?(Base64): ', Copy(Encrypted, 1, 50), '...');
    
    Decrypted := TDPAPIHelper.UnprotectString(Encrypted);
    WriteLn('解密�? ', Decrypted);
    
    if Original = Decrypted then
      WriteLn('�?DPAPI 测试通过!')
    else
      WriteLn('�?DPAPI 测试失败: 解密结果不匹�?);
  except
    on E: Exception do
      WriteLn('�?DPAPI 测试失败: ', E.Message);
  end;
  WriteLn;
end;

procedure TestChatHistory;
var
  History: TChatHistory;
  Messages: TChatMessages;
  I: Integer;
begin
  WriteLn('=== 测试 ChatHistory ===');
  
  History := TChatHistory.Create('You are a helpful assistant.', 10);
  try
    History.AddUserMessage('Hello');
    History.AddAssistantMessage('Hi there!');
    History.AddUserMessage('How are you?');
    
    Messages := History.GetMessages;
    WriteLn('消息数量: ', Length(Messages));
    
    for I := 0 to High(Messages) do
      WriteLn(Format('  [%d] %s: %s', [I, Messages[I].RoleToString, Copy(Messages[I].Content, 1, 30)]));
    
    if (Length(Messages) = 4) and (Messages[0].Role = mrSystem) then
      WriteLn('�?ChatHistory 测试通过!')
    else
      WriteLn('�?ChatHistory 测试失败');
  finally
    History.Free;
  end;
  WriteLn;
end;

procedure TestBillingClient(const AApiKey: string);
var
  Client: TBillingClient;
  Response: TChatResponse;
  FullResponse: string;
begin
  WriteLn('=== 测试 BillingClient (硅基流动) ===');
  
  if AApiKey = '' then
  begin
    WriteLn('�?跳过: 未提�?API Key');
    WriteLn('  请设�?SILICONFLOW_API_KEY 环境变量或直接修改代�?);
    Exit;
  end;
  
  Client := TBillingClient.Create(BASE_URL, AApiKey, TENANT_ID);
  try
    Client.Model := 'deepseek-ai/DeepSeek-V3';
    Client.MaxTokens := 100;
    Client.Timeout := 30000;
    
    WriteLn('发送请�?..');
    WriteLn('Model: ', Client.Model);
    WriteLn('BaseURL: ', Client.BaseURL);
    
    // 测试非流�?
    WriteLn;
    WriteLn('--- 非流式测�?---');
    try
      if Client.Chat('Say "Hello World" in Chinese, just the translation.', Response) then
      begin
        WriteLn('响应: ', Response.Content);
        WriteLn('Token 使用: ', Response.Usage.TotalTokens);
        WriteLn('耗时: ', Response.DurationMs, 'ms');
        WriteLn('�?非流式测试通过!');
      end
      else
      begin
        WriteLn('�?请求失败: ', Response.ErrorMessage);
      end;
    except
      on E: EBillingAuthError do
        WriteLn('�?认证失败: ', E.Message);
      on E: EBillingBalanceError do
        WriteLn('�?余额不足: ', E.Message);
      on E: EBillingError do
        WriteLn('�?API 错误: ', E.Message);
      on E: Exception do
        WriteLn('�?异常: ', E.ClassName, ' - ', E.Message);
    end;
    
    // 测试流式
    WriteLn;
    WriteLn('--- 流式测试 ---');
    FullResponse := '';
    try
      Write('响应: ');
      if Client.ChatStream('Count from 1 to 5.',
        function(const AChunk: string; ADone: Boolean): Boolean
        begin
          if not ADone then
          begin
            Write(AChunk);
            FullResponse := FullResponse + AChunk;
          end
          else
            WriteLn;
          Result := True;
        end) then
      begin
        WriteLn('�?流式测试通过!');
      end
      else
      begin
        WriteLn('�?流式请求失败');
      end;
    except
      on E: Exception do
        WriteLn('�?流式异常: ', E.ClassName, ' - ', E.Message);
    end;
    
  finally
    Client.Free;
  end;
  WriteLn;
end;

var
  ApiKey: string;
begin
  try
    WriteLn('DeepBase LLM Client 测试');
    WriteLn('========================');
    WriteLn;
    
    // 测试 DPAPI
    TestDPAPI;
    
    // 测试 ChatHistory
    TestChatHistory;
    
    // 测试 BillingClient
    ApiKey := GetEnvironmentVariable('SILICONFLOW_API_KEY');
    if ApiKey = '' then
      ApiKey := API_KEY; // 使用代码中的常量
    TestBillingClient(ApiKey);
    
    WriteLn('测试完成!');
    WriteLn('按回车键退�?..');
    ReadLn;
  except
    on E: Exception do
    begin
      WriteLn('严重错误: ', E.ClassName, ' - ', E.Message);
      ReadLn;
    end;
  end;
end.
