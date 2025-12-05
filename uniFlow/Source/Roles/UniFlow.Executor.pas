unit UniFlow.Executor;

{*******************************************************************************
  UniFlow.Executor - 执行者角色 (L2 能力层)
  
  描述：
    负责执行具体的 Skill，调用 Python 服务执行业务逻辑。
    
  职责：
    - 调用 Skill 服务
    - 管理 Skill 执行上下文
    - 处理执行结果
    
  信任级别：不信任 (输出必须经过 Guard 校验)
    
  作者：鲁班（开发者）
  日期：2025-12-04
  版本：1.0
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Net.HttpClient,
  UniFlow.Message, UniFlow.Role, UniFlow.Config;

type
  /// <summary>执行结果</summary>
  TExecutionResult = record
    Success: Boolean;
    Output: TJSONObject;
    ErrorCode: string;
    ErrorMessage: string;
    ExecutionTime: Integer;  // 毫秒
  end;

  /// <summary>Executor 角色</summary>
  TExecutor = class(TUniFlowRoleBase, IExecutor)
  private
    FHttpClient: THTTPClient;
    FConfig: TUniFlowConfig;
    FSkillServiceUrl: string;
    
    function CallSkillService(const ASkillName: string; const AInput: TJSONObject): TExecutionResult;
  protected
    procedure DoInitialize; override;
    procedure DoStart; override;
    procedure DoStop; override;
    function DoHandleMessage(const AMessage: TUniFlowMessage): TUniFlowMessage; override;
  public
    constructor Create; overload;
    constructor Create(const AConfig: TUniFlowConfig); overload;
    destructor Destroy; override;
    
    // IExecutor 实现
    /// <summary>执行 Skill</summary>
    function Execute(const ASkillName: string; const AInput: TJSONObject): TJSONObject;
    
    /// <summary>执行 LLM 调用</summary>
    function ExecuteLLM(const APrompt: string; const AContext: TJSONObject = nil): TJSONObject;
    
    function CanHandle(const AMsgType: string): Boolean; override;
  end;

implementation

uses
  System.DateUtils, System.NetEncoding;

{ TExecutor }

constructor TExecutor.Create;
begin
  Create(GlobalConfig);
end;

constructor TExecutor.Create(const AConfig: TUniFlowConfig);
var
  Meta: TRoleMetaInfo;
begin
  Meta.Name := 'Executor';
  Meta.DisplayName := '执行者';
  Meta.Level := rlCapability;
  Meta.TrustLevel := tlUntrusted;
  Meta.Description := '负责执行 Skill，调用外部服务';
  Meta.Version := '1.0';
  
  inherited Create(Meta);
  
  FConfig := AConfig;
  FHttpClient := THTTPClient.Create;
  FHttpClient.ConnectionTimeout := 10000;
  FHttpClient.ResponseTimeout := FConfig.MessageTimeout;
end;

destructor TExecutor.Destroy;
begin
  FHttpClient.Free;
  inherited;
end;

procedure TExecutor.DoInitialize;
begin
  FSkillServiceUrl := FConfig.SkillServiceUrl + ':' + IntToStr(FConfig.SkillServicePort);
end;

procedure TExecutor.DoStart;
begin
  // 可以在这里检查 Skill 服务是否可用
end;

procedure TExecutor.DoStop;
begin
  // 清理资源
end;

function TExecutor.CallSkillService(const ASkillName: string; const AInput: TJSONObject): TExecutionResult;
var
  RequestBody: TJSONObject;
  ResponseJSON: TJSONObject;
  Response: IHTTPResponse;
  ContentStream: TStringStream;
  StartTime: TDateTime;
  OutputData: TJSONObject;
begin
  Result.Success := False;
  Result.Output := nil;
  Result.ErrorCode := '';
  Result.ErrorMessage := '';
  
  StartTime := Now;
  RequestBody := TJSONObject.Create;
  try
    RequestBody.AddPair('skill_name', ASkillName);
    RequestBody.AddPair('input_data', AInput.Clone as TJSONObject);
    
    ContentStream := TStringStream.Create(RequestBody.ToJSON, TEncoding.UTF8);
    try
      try
        Response := FHttpClient.Post(
          FSkillServiceUrl + '/execute',
          ContentStream,
          nil,
          [TNameValuePair.Create('Content-Type', 'application/json')]
        );
        
        Result.ExecutionTime := MilliSecondsBetween(Now, StartTime);
        
        if Response.StatusCode = 200 then
        begin
          ResponseJSON := TJSONObject.ParseJSONValue(Response.ContentAsString(TEncoding.UTF8)) as TJSONObject;
          try
            if ResponseJSON.TryGetValue<Boolean>('success', Result.Success) then
            begin
              if Result.Success then
              begin
                if ResponseJSON.TryGetValue<TJSONObject>('output_data', OutputData) then
                  Result.Output := OutputData.Clone as TJSONObject
                else
                  Result.Output := TJSONObject.Create;
              end
              else
              begin
                ResponseJSON.TryGetValue<string>('error', Result.ErrorMessage);
                Result.ErrorCode := 'SKILL_ERROR';
              end;
            end;
          finally
            ResponseJSON.Free;
          end;
        end
        else
        begin
          Result.ErrorCode := 'HTTP_' + IntToStr(Response.StatusCode);
          Result.ErrorMessage := Response.StatusText;
        end;
      except
        on E: Exception do
        begin
          Result.ExecutionTime := MilliSecondsBetween(Now, StartTime);
          Result.ErrorCode := 'EXCEPTION';
          Result.ErrorMessage := E.Message;
        end;
      end;
    finally
      ContentStream.Free;
    end;
  finally
    RequestBody.Free;
  end;
end;

function TExecutor.Execute(const ASkillName: string; const AInput: TJSONObject): TJSONObject;
var
  ExecResult: TExecutionResult;
  RetryCount: Integer;
begin
  Result := TJSONObject.Create;
  RetryCount := 0;
  
  // 重试机制
  repeat
    ExecResult := CallSkillService(ASkillName, AInput);
    
    if ExecResult.Success then
      Break;
    
    Inc(RetryCount);
    if RetryCount < FConfig.MaxRetries then
      Sleep(FConfig.RetryDelay);
      
  until RetryCount >= FConfig.MaxRetries;
  
  Result.AddPair('success', TJSONBool.Create(ExecResult.Success));
  Result.AddPair('skill_name', ASkillName);
  Result.AddPair('execution_time_ms', TJSONNumber.Create(ExecResult.ExecutionTime));
  Result.AddPair('retry_count', TJSONNumber.Create(RetryCount));
  
  if ExecResult.Success then
  begin
    if ExecResult.Output <> nil then
      Result.AddPair('output', ExecResult.Output)
    else
      Result.AddPair('output', TJSONObject.Create);
  end
  else
  begin
    Result.AddPair('error_code', ExecResult.ErrorCode);
    Result.AddPair('error_message', ExecResult.ErrorMessage);
  end;
end;

function TExecutor.ExecuteLLM(const APrompt: string; const AContext: TJSONObject): TJSONObject;
var
  LLMUrl: string;
  RequestBody: TJSONObject;
  ResponseJSON: TJSONObject;
  Response: IHTTPResponse;
  ContentStream: TStringStream;
  StartTime: TDateTime;
begin
  Result := TJSONObject.Create;
  StartTime := Now;
  
  // 使用 Mock LLM 或真实 LLM
  if FConfig.UseMockAI then
    LLMUrl := FConfig.MockLLMUrl + '/execute'
  else
    LLMUrl := FSkillServiceUrl + '/llm/execute';  // 真实 LLM 端点
  
  RequestBody := TJSONObject.Create;
  try
    RequestBody.AddPair('prompt', APrompt);
    RequestBody.AddPair('max_tokens', TJSONNumber.Create(1000));
    RequestBody.AddPair('temperature', TJSONNumber.Create(0.7));
    RequestBody.AddPair('model', 'mock-gpt-4');
    RequestBody.AddPair('stream', TJSONBool.Create(False));
    
    if AContext <> nil then
      RequestBody.AddPair('context', AContext.Clone as TJSONObject);
    
    ContentStream := TStringStream.Create(RequestBody.ToJSON, TEncoding.UTF8);
    try
      try
        Response := FHttpClient.Post(
          LLMUrl,
          ContentStream,
          nil,
          [TNameValuePair.Create('Content-Type', 'application/json')]
        );
        
        if Response.StatusCode = 200 then
        begin
          ResponseJSON := TJSONObject.ParseJSONValue(Response.ContentAsString(TEncoding.UTF8)) as TJSONObject;
          try
            Result.AddPair('success', TJSONBool.Create(True));
            
            var Content: string;
            if ResponseJSON.TryGetValue<string>('content', Content) then
              Result.AddPair('content', Content);
            
            var TokensUsed: Integer;
            if ResponseJSON.TryGetValue<Integer>('tokens_used', TokensUsed) then
              Result.AddPair('tokens_used', TJSONNumber.Create(TokensUsed));
              
          finally
            ResponseJSON.Free;
          end;
        end
        else
        begin
          Result.AddPair('success', TJSONBool.Create(False));
          Result.AddPair('error_code', 'HTTP_' + IntToStr(Response.StatusCode));
          Result.AddPair('error_message', Response.StatusText);
        end;
      except
        on E: Exception do
        begin
          Result.AddPair('success', TJSONBool.Create(False));
          Result.AddPair('error_code', 'EXCEPTION');
          Result.AddPair('error_message', E.Message);
        end;
      end;
    finally
      ContentStream.Free;
    end;
  finally
    RequestBody.Free;
  end;
  
  Result.AddPair('execution_time_ms', TJSONNumber.Create(MilliSecondsBetween(Now, StartTime)));
  Result.AddPair('mock', TJSONBool.Create(FConfig.UseMockAI));
end;

function TExecutor.DoHandleMessage(const AMessage: TUniFlowMessage): TUniFlowMessage;
var
  SkillName: string;
  Input: TJSONObject;
  Prompt: string;
  ExecResult: TJSONObject;
begin
  Result := nil;
  
  if AMessage.MsgType = 'executor.execute' then
  begin
    // 执行 Skill
    if AMessage.Payload.TryGetValue<string>('skill_name', SkillName) then
    begin
      if AMessage.Payload.TryGetValue<TJSONObject>('input', Input) then
        ExecResult := Execute(SkillName, Input)
      else
        ExecResult := Execute(SkillName, TJSONObject.Create);
      
      Result := TResponseMessage.Create(AMessage);
      TResponseMessage(Result).Payload.Free;
      TResponseMessage(Result).Payload := ExecResult;
      
      var Success: Boolean;
      if ExecResult.TryGetValue<Boolean>('success', Success) then
        TResponseMessage(Result).Success := Success;
    end;
  end
  else if AMessage.MsgType = 'executor.llm' then
  begin
    // 执行 LLM 调用
    if AMessage.Payload.TryGetValue<string>('prompt', Prompt) then
    begin
      var Context: TJSONObject := nil;
      AMessage.Payload.TryGetValue<TJSONObject>('context', Context);
      
      ExecResult := ExecuteLLM(Prompt, Context);
      
      Result := TResponseMessage.Create(AMessage);
      TResponseMessage(Result).Payload.Free;
      TResponseMessage(Result).Payload := ExecResult;
      
      var Success: Boolean;
      if ExecResult.TryGetValue<Boolean>('success', Success) then
        TResponseMessage(Result).Success := Success;
    end;
  end;
end;

function TExecutor.CanHandle(const AMsgType: string): Boolean;
begin
  Result := AMsgType.StartsWith('executor.');
end;

end.
