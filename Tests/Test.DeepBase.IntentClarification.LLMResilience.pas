{ ============================================================================
  Test.DeepBase.IntentClarification.LLMResilience

  WO-20260919-AUDIT-乙-R2 E8：Top20 T3.8 改写回归。
  验证 ExecuteWithResilience 超时路径改走 TManagedWorker + 引用计数信箱后：
    1) 超时结果契约不变（Success=False / resilience_failure / 携带 timeout 文案）；
    2) 成功、异常路径行为不变；
    3) 「退出期晚到调用」安全：超时后宿主栈已退出、后台体仍写引用计数信箱不 UAF；
    4) 无泄漏：被 Evacuate 的 worker 由看护线程清扫归零。
  风格对齐 B4/E6（Test.DeepBase.Resilience 的 QuarantinedWorkerCount 清零压测）。
  ============================================================================ }

unit Test.DeepBase.IntentClarification.LLMResilience;

interface

uses
  System.SysUtils,
  System.Diagnostics,
  DUnitX.TestFramework,
  DeepBase.LLM.Client,
  DeepBase.LLM.Types,
  DeepBase.IntentClarification.LLMResilience,
  DeepBase.ManagedWorker;

type
  /// <summary>可注入延迟/异常/结果的慢速假 LLM 客户端，覆盖 ILLMClient 全签名。</summary>
  TSlowFakeLLM = class(TInterfacedObject, ILLMClient)
  public
    DelayMs: Integer;
    FailWith: string;        // 非空则 Chat 抛异常
    ResponseText: string;
    function Chat(const ATier: TModelTier;
      const AUserPrompt: string): TChatResult; overload;
    function Chat(const ATier: TModelTier;
      const ASystemPrompt, AUserPrompt: string): TChatResult; overload;
    function ChatWithHistory(const ATier: TModelTier;
      const AMessages: TArray<TChatMessage>;
      AMaxTokens: Integer = 0; ATemperature: Double = -1): TChatResult;
    function ChatWithHistoryByProvider(const AProviderName, AModelId: string;
      const AMessages: TArray<TChatMessage>;
      AMaxTokens: Integer = 0; ATemperature: Double = -1): TChatResult;
    procedure ChatStream(const ATier: TModelTier;
      const AMessages: TArray<TChatMessage>; AOnChunk: TProc<string>;
      AOnError: TProc<string>; AMaxTokens: Integer = 0);
    function ChatVision(const ATier: TModelTier;
      const AImageBase64: string; const AImageMimeType: string;
      const AUserPrompt: string; const ASystemPrompt: string = ''): TChatResult;
    function GenerateImage(const APrompt: string;
      const ASize: string = '1024x1024'): TImageGenerationResult;
    procedure GenerateImageStream(const APrompt: string;
      const AOnProgress: TImageProgressCallback;
      const AOnResult: TProc<TImageGenerationResult>;
      const AOnError: TProc<string>;
      const ASize: string = '1024x1024');
    procedure ChatVisionStream(const ATier: TModelTier;
      const AImageBase64: string; const AImageMimeType: string;
      const AUserPrompt: string; const ASystemPrompt: string;
      AOnChunk: TProc<string>; AOnError: TProc<string>;
      AMaxTokens: Integer = 0);
    function GetModelForTier(const ATier: TModelTier): string;
    function CallCount: Integer;
    function LastDurationMs: Integer;
  end;

  [TestFixture]
  TTestLLMResilienceHarness = class
  private
    function FastConfig: TLLMResilienceConfig;
  public
    [Test]
    procedure Test_Success_ReturnsInnerContent;

    [Test]
    procedure Test_Timeout_KeepsContract_NoLeak;

    [Test]
    procedure Test_Exception_FallsBackToResilienceFailure;

    [Test]
    procedure Test_LateWriteAfterTimeout_SafeAndQuarantineDrains;
  end;

implementation

{ TSlowFakeLLM }

function TSlowFakeLLM.Chat(const ATier: TModelTier;
  const AUserPrompt: string): TChatResult;
begin
  Result := Chat(ATier, '', AUserPrompt);
end;

function TSlowFakeLLM.Chat(const ATier: TModelTier;
  const ASystemPrompt, AUserPrompt: string): TChatResult;
begin
  if DelayMs > 0 then
    Sleep(DelayMs);
  if FailWith <> '' then
    raise Exception.Create(FailWith);
  Result := Default(TChatResult);
  Result.Success := True;
  Result.Content := ResponseText;
  Result.FinishReason := 'stop';
end;

function TSlowFakeLLM.ChatWithHistory(const ATier: TModelTier;
  const AMessages: TArray<TChatMessage>; AMaxTokens: Integer;
  ATemperature: Double): TChatResult;
begin
  Result := Chat(ATier, '', '');
end;

function TSlowFakeLLM.ChatWithHistoryByProvider(const AProviderName,
  AModelId: string; const AMessages: TArray<TChatMessage>;
  AMaxTokens: Integer; ATemperature: Double): TChatResult;
begin
  Result := Chat(TierFast, '', '');
end;

procedure TSlowFakeLLM.ChatStream(const ATier: TModelTier;
  const AMessages: TArray<TChatMessage>; AOnChunk, AOnError: TProc<string>;
  AMaxTokens: Integer);
begin
end;

function TSlowFakeLLM.ChatVision(const ATier: TModelTier;
  const AImageBase64, AImageMimeType, AUserPrompt,
  ASystemPrompt: string): TChatResult;
begin
  Result := Chat(ATier, AUserPrompt);
end;

function TSlowFakeLLM.GenerateImage(const APrompt,
  ASize: string): TImageGenerationResult;
begin
  Result := Default(TImageGenerationResult);
end;

procedure TSlowFakeLLM.GenerateImageStream(const APrompt: string;
  const AOnProgress: TImageProgressCallback;
  const AOnResult: TProc<TImageGenerationResult>;
  const AOnError: TProc<string>;
  const ASize: string);
begin
end;

procedure TSlowFakeLLM.ChatVisionStream(const ATier: TModelTier;
  const AImageBase64, AImageMimeType, AUserPrompt, ASystemPrompt: string;
  AOnChunk, AOnError: TProc<string>; AMaxTokens: Integer);
begin
end;

function TSlowFakeLLM.GetModelForTier(const ATier: TModelTier): string;
begin
  Result := ATier;
end;

function TSlowFakeLLM.CallCount: Integer;
begin
  Result := 0;
end;

function TSlowFakeLLM.LastDurationMs: Integer;
begin
  Result := 0;
end;

{ TTestLLMResilienceHarness }

function TTestLLMResilienceHarness.FastConfig: TLLMResilienceConfig;
begin
  Result := TLLMResilienceConfig.Default;
  Result.TimeoutMs := 30;      // 远小于慢体延迟，必触发超时
  Result.MaxRetries := 0;      // 单次尝试，测试确定性与用时
  Result.CircuitBreakerThreshold := 100; // 避免熔断干扰单次路径断言
end;

procedure TTestLLMResilienceHarness.Test_Success_ReturnsInnerContent;
var
  LClient: TSlowFakeLLM;
  LWrapper: ILLMClient;
  LRes: TChatResult;
begin
  LClient := TSlowFakeLLM.Create;
  LClient.DelayMs := 0;
  LClient.ResponseText := 'hello-e8';
  LWrapper := TResilientLLMWrapper.Create(LClient, FastConfig);
  LRes := LWrapper.Chat(TierFast, 'q');
  Assert.IsTrue(LRes.Success, '成功路径应 Success=True');
  Assert.AreEqual('hello-e8', LRes.Content, '成功路径应透传内层内容');
end;

procedure TTestLLMResilienceHarness.Test_Timeout_KeepsContract_NoLeak;
var
  LClient: TSlowFakeLLM;
  LWrapper: ILLMClient;
  LRes: TChatResult;
  LSW: TStopwatch;
begin
  LClient := TSlowFakeLLM.Create;
  LClient.DelayMs := 400; // 远超 TimeoutMs=30
  LWrapper := TResilientLLMWrapper.Create(LClient, FastConfig);

  LSW := TStopwatch.StartNew;
  LRes := LWrapper.Chat(TierFast, 'q');
  LSW.Stop;

  Assert.IsFalse(LRes.Success, '超时不得返回成功');
  // 契约：超时后所有尝试耗尽 → resilience_failure，错误文案保留 timeout 语义
  Assert.AreEqual('resilience_failure', LRes.ErrorCode, '超时耗尽后错误码');
  Assert.IsTrue(LRes.ErrorMessage.ToLower.Contains('timed out'),
    '错误文案须含 timeout 语义，实际=' + LRes.ErrorMessage);
  // 宿主侧必须在超时点返回（远早于 400ms 工作体），证明确实走了超时+Evacuate 出口
  Assert.IsTrue(LSW.ElapsedMilliseconds < 350,
    '宿主须在 TimeoutMs 附近返回，不得等满后台体');
end;

procedure TTestLLMResilienceHarness.Test_Exception_FallsBackToResilienceFailure;
var
  LClient: TSlowFakeLLM;
  LWrapper: ILLMClient;
  LRes: TChatResult;
begin
  LClient := TSlowFakeLLM.Create;
  LClient.DelayMs := 0;
  LClient.FailWith := 'boom-e8';
  LWrapper := TResilientLLMWrapper.Create(LClient, FastConfig);
  LRes := LWrapper.Chat(TierFast, 'q');
  Assert.IsFalse(LRes.Success, '异常路径不得成功');
  Assert.AreEqual('resilience_failure', LRes.ErrorCode, '异常耗尽后归一为 resilience_failure');
end;

procedure TTestLLMResilienceHarness.Test_LateWriteAfterTimeout_SafeAndQuarantineDrains;
const
  Rounds = 8;
var
  I: Integer;
  LClient: TSlowFakeLLM;
  LWrapper: ILLMClient;
  LSW: TStopwatch;
begin
  // 每轮：慢体超时→Evacuate→宿主栈退出；后台体稍后写引用计数信箱（晚到调用）。
  // 旧方案此处为 intentional leak；新方案须：不崩、且被抛弃 worker 由看护线程清零。
  LClient := TSlowFakeLLM.Create;
  LClient.DelayMs := 200;
  LWrapper := TResilientLLMWrapper.Create(LClient, FastConfig);
  for I := 0 to Rounds - 1 do
    LWrapper.Chat(TierFast, 'q');

  LSW := TStopwatch.StartNew;
  while TManagedWorker.QuarantinedWorkerCount > 0 do
  begin
    if LSW.ElapsedMilliseconds > 15000 then
      Assert.Fail('E8/T3.8: 隔离区泄漏，晚到调用压测后 15s 仍有 ' +
        TManagedWorker.QuarantinedWorkerCount.ToString + ' 个被抛弃 worker 未回收');
    Sleep(100);
  end;
  // 走到此处未崩即证明晚到写入命中存活信箱（无 UAF），且全部回收。
  Assert.AreEqual(0, TManagedWorker.QuarantinedWorkerCount, '隔离区必须清零');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestLLMResilienceHarness);

end.
