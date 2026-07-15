unit DeepFlow.Skill.Client;

interface

uses
  System.SysUtils, System.Classes, System.Net.HttpClient, System.Net.URLClient, System.JSON;

type
  /// <summary>
  /// Skill 客户端异常，携带调用上下文（技能名称、调用类型、原始错误信息）。
  /// </summary>
  ESkillClientException = class(Exception)
  private
    FSkillName: string;
    FCallType: string;
    FOriginalMessage: string;
  public
    constructor Create(const ASkillName, ACallType, AOriginalMessage: string);

    /// <summary>被调用的技能名称</summary>
    property SkillName: string read FSkillName;
    /// <summary>调用类型（如 'ExecuteSkill'）</summary>
    property CallType: string read FCallType;
    /// <summary>原始异常消息</summary>
    property OriginalMessage: string read FOriginalMessage;
  end;

  TSkillClient = class
  private
    FHttpClient: THTTPClient;
    FBaseUrl: string;
    FTimeoutMS: Integer;
    FMaxRetries: Integer;
    FRetryDelays: TArray<Integer>;

    function ExecuteWithRetry(const ASkillName: string; AInput: TJSONObject): TJSONObject;
  public
    /// <summary>
    /// 创建 Skill 客户端。
    /// </summary>
    /// <param name="ABaseUrl">服务基础 URL</param>
    /// <param name="ATimeoutMS">单次请求超时（毫秒），默认 30000</param>
    /// <param name="AMaxRetries">最大重试次数，默认 3</param>
    constructor Create(const ABaseUrl: string = 'http://127.0.0.1:8000';
      ATimeoutMS: Integer = 30000; AMaxRetries: Integer = 3);
    destructor Destroy; override;

    /// <summary>
    /// 执行技能调用。包含指数退避重试（1s/2s/4s）和异常包装。
    /// </summary>
    function ExecuteSkill(const ASkillName: string; AInput: TJSONObject): TJSONObject;

    /// <summary>单次请求超时（毫秒）</summary>
    property TimeoutMS: Integer read FTimeoutMS write FTimeoutMS;
    /// <summary>最大重试次数</summary>
    property MaxRetries: Integer read FMaxRetries write FMaxRetries;
  end;

implementation

{ ESkillClientException }

constructor ESkillClientException.Create(const ASkillName, ACallType,
  AOriginalMessage: string);
begin
  FSkillName := ASkillName;
  FCallType := ACallType;
  FOriginalMessage := AOriginalMessage;
  inherited CreateFmt('Skill call failed [%s.%s]: %s',
    [ACallType, ASkillName, AOriginalMessage]);
end;

{ TSkillClient }

constructor TSkillClient.Create(const ABaseUrl: string; ATimeoutMS, AMaxRetries: Integer);
begin
  inherited Create;
  FHttpClient := THTTPClient.Create;
  FBaseUrl := ABaseUrl;
  FTimeoutMS := ATimeoutMS;
  FMaxRetries := AMaxRetries;
  // DATA2-040: 指数退避延迟序列（毫秒），按重试次数索引
  SetLength(FRetryDelays, 3);
  FRetryDelays[0] := 1000;  // 第 1 次重试前等待 1s
  FRetryDelays[1] := 2000;  // 第 2 次重试前等待 2s
  FRetryDelays[2] := 4000;  // 第 3 次重试前等待 4s
end;

destructor TSkillClient.Destroy;
begin
  FHttpClient.Free;
  inherited;
end;

function TSkillClient.ExecuteSkill(const ASkillName: string;
  AInput: TJSONObject): TJSONObject;
begin
  try
    Result := ExecuteWithRetry(ASkillName, AInput);
  except
    on E: ESkillClientException do
      raise; // 已是包装后的异常，直接抛出
    on E: Exception do
      raise ESkillClientException.Create(ASkillName, 'ExecuteSkill', E.Message);
  end;
end;

function TSkillClient.ExecuteWithRetry(const ASkillName: string;
  AInput: TJSONObject): TJSONObject;
var
  LRequestBody: TJSONObject;
  LResponse: IHTTPResponse;
  LContentStream: TStringStream;
  LAttempt: Integer;
  LLastException: Exception;
  LDelayMS: Integer;
  LSuccess: Boolean;
begin
  Result := nil;
  LLastException := nil;
  LSuccess := False;

  // DATA2-040: 设置超时
  FHttpClient.ConnectionTimeout := FTimeoutMS;
  FHttpClient.ResponseTimeout := FTimeoutMS;

  for LAttempt := 0 to FMaxRetries - 1 do
  begin
    LRequestBody := TJSONObject.Create;
    try
      LRequestBody.AddPair('skill_name', ASkillName);
      LRequestBody.AddPair('input_data', AInput.Clone as TJSONObject);

      LContentStream := TStringStream.Create(LRequestBody.ToJSON, TEncoding.UTF8);
      try
        try
          LResponse := FHttpClient.Post(FBaseUrl + '/execute', LContentStream, nil,
            [TNameValuePair.Create('Content-Type', 'application/json')]);

          if (LResponse.StatusCode div 100) <> 2 then
            raise ESkillClientException.Create(ASkillName, 'ExecuteSkill',
              Format('HTTP %d: %s', [LResponse.StatusCode, LResponse.StatusText]));

          Result := TJSONObject.ParseJSONValue(
            LResponse.ContentAsString(TEncoding.UTF8)) as TJSONObject;

          if Result = nil then
            raise ESkillClientException.Create(ASkillName, 'ExecuteSkill',
              'Response is not valid JSON');

          LSuccess := True;
          Exit; // 成功则退出
        except
          on E: Exception do
          begin
            // BUG-439: 克隆异常对象, 避免跨 except 块持有 RTL 自动释放的 E 导致
            // LLastException 悬挂。except on E: 块结束 RTL 自动 Free E; 若直接
            // LLastException := E, 循环退出后 raise LLastException / LLastException.Message
            // 操作已释放对象 → 确定性 AV (与 BUG-438 同构, 已由 TryExecute 回归测试
            // Test_TryExecute_ErrorOutParam_NotDanglingAfterReturn 在同构场景下确证)。
            // 保留 ESkillClientException 类型, 使尾部 is 判断与未包装 re-raise 语义不变。
            // 释放上一轮残留的克隆对象 (多轮重试全失败时, 上一轮克隆在此被覆盖前需回收)。
            FreeAndNil(LLastException);
            if E is ESkillClientException then
              LLastException := ESkillClientException.Create(
                ESkillClientException(E).SkillName,
                ESkillClientException(E).CallType,
                ESkillClientException(E).OriginalMessage)
            else
              LLastException := Exception.Create(E.Message);
            // 最后一次尝试失败不再等待
            if LAttempt < FMaxRetries - 1 then
            begin
              if LAttempt < Length(FRetryDelays) then
                LDelayMS := FRetryDelays[LAttempt]
              else
                LDelayMS := FRetryDelays[High(FRetryDelays)] * 2; // 超出预定义则翻倍
              Sleep(LDelayMS);
            end;
          end;
        end;
      finally
        LContentStream.Free;
      end;
    finally
      LRequestBody.Free;
    end;
  end;

  // 所有重试都失败，抛出包装后的异常
  if LLastException <> nil then
  begin
    if LLastException is ESkillClientException then
      raise LLastException  // BUG-439: 克隆对象所有权转交 RTL, 由 RTL 在新 except 块结束时 Free
    else
    begin
      // BUG-439: 克隆的 LLastException 不再需要, 包装为新异常前释放避免泄漏。
      try
        raise ESkillClientException.Create(ASkillName, 'ExecuteSkill',
          Format('All %d attempts failed. Last error: %s',
            [FMaxRetries, LLastException.Message]));
      finally
        FreeAndNil(LLastException);
      end;
    end;
  end;
end;

end.
