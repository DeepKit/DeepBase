unit DeepBase.IntentClarification.Exit;

interface

uses
  System.SysUtils,
  DeepBase.IntentClarification.Types,
  DeepBase.IntentClarification.Interfaces;

type
  /// <summary>
  /// 优雅退出处理器 - 处理五种退出触发器，生成检查点摘要和恢复提示。
  /// Exit triggers: user_cancel, info_sufficient, budget_exhausted, frustration, action_over_perfection
  /// Property 29: ResumeHint 始终非空。
  /// Requirements: 10.1-10.6
  /// </summary>
  TGracefulExitHandler = class
  private
    function BuildSummary(const AState: TSessionState; const AReason: string): string;
    function BuildResumeHint(const AState: TSessionState; const AReason: string): string;
    function BuildBestGuess(const AState: TSessionState): string;
  public
    /// <summary>
    /// Handles a graceful exit for the given session state and reason.
    /// Generates checkpoint summary, resume hint, and best-guess intent.
    /// </summary>
    function HandleExit(const AState: TSessionState;
      const AReason: string): TExitResult;
  end;

implementation

{ TGracefulExitHandler }

function TGracefulExitHandler.HandleExit(const AState: TSessionState;
  const AReason: string): TExitResult;
begin
  Result := Default(TExitResult);
  Result.SessionId := AState.SessionId;
  Result.Reason := AReason;
  Result.Summary := BuildSummary(AState, AReason);
  Result.ResumeHint := BuildResumeHint(AState, AReason);
  Result.BestGuessIntent := BuildBestGuess(AState);
  Result.CheckpointSaved := True;

  // Property 29: ResumeHint always non-empty
  if Result.ResumeHint = '' then
    Result.ResumeHint := '可随时继续上次的对话。';
end;

function TGracefulExitHandler.BuildSummary(const AState: TSessionState;
  const AReason: string): string;
begin
  case AState.CurrentLevel of
    clL0: Result := '背景识别阶段';
    clL1: Result := '指令型澄清阶段';
    clL2: Result := '问题识别阶段';
    clL3: Result := '专家指导阶段';
    clL4: Result := '多专家讨论阶段';
  else
    Result := '澄清进行中';
  end;

  Result := Format('会话 %s 在%s退出（原因: %s），已完成 %d 轮交互。',
    [AState.SessionId, Result, AReason, AState.TurnCount]);

  if AState.IntentName <> '' then
    Result := Result + Format(' 当前意图: %s。', [AState.IntentName]);
end;

function TGracefulExitHandler.BuildResumeHint(const AState: TSessionState;
  const AReason: string): string;
begin
  if AReason = 'user_cancel' then
    Result := Format('您可以随时输入"继续"来恢复会话 %s，我们将从第 %d 轮继续。',
      [AState.SessionId, AState.TurnCount])
  else if AReason = 'info_sufficient' then
    Result := Format('意图已明确（%s），如需调整可重新发起。',
      [AState.IntentName])
  else if AReason = 'budget_exhausted' then
    Result := Format('已达到最大轮次限制。基于当前理解执行，如需细化可重新发起会话。', [])
  else if AReason = 'frustration' then
    Result := Format('已保存当前进度（第 %d 轮）。您可以稍后以更轻松的方式继续。',
      [AState.TurnCount])
  else if AReason = 'action_over_perfection' then
    Result := '已基于当前最佳理解开始执行。如结果不符预期，可随时调整。'
  else
    Result := Format('会话 %s 已暂停，可随时恢复。', [AState.SessionId]);

  // Property 29: guarantee non-empty
  if Result = '' then
    Result := '可随时继续上次的对话。';
end;

function TGracefulExitHandler.BuildBestGuess(const AState: TSessionState): string;
begin
  if AState.IntentName <> '' then
    Result := AState.IntentName
  else
    Result := '(未确定意图)';
end;

end.
