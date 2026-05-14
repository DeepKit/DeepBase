unit DeepBase.IntentClarification.Provider.L0;

interface

uses
  System.SysUtils,
  DeepBase.IntentClarification.Types,
  DeepBase.IntentClarification.Interfaces;

type
  /// <summary>
  /// L0 背景识别处理器 - 纯规则引擎，零 LLM 依赖。
  /// 基于上下文状态和配置规则直接路由到目标意图。
  /// Requirements: 4.1, 4.3
  /// </summary>
  TL0BackgroundProvider = class(TInterfacedObject, ILevelProvider)
  private
    const
      CDepthThreshold = 0.2;
  public
    { ILevelProvider }
    function GetLevel: TClarificationLevel;
    function CanHandle(const AContext: TProcessingContext): Boolean;
    function Process(const AContext: TProcessingContext): TProviderResult;
    function RequiresLLM: Boolean;
  end;

implementation

{ TL0BackgroundProvider }

function TL0BackgroundProvider.GetLevel: TClarificationLevel;
begin
  Result := clL0;
end;

function TL0BackgroundProvider.RequiresLLM: Boolean;
begin
  Result := False;
end;

function TL0BackgroundProvider.CanHandle(const AContext: TProcessingContext): Boolean;
begin
  // L0 handles when context depth is shallow (< 0.2) or when there is
  // enough domain context information to route directly without clarification.
  if AContext.Depth < CDepthThreshold then
    Exit(True);

  // Also handle if domain context provides a clear active intent
  Result := (Trim(AContext.DomainContext.ActiveIntent) <> '') and
            (Trim(AContext.UserInput) <> '');
end;

function TL0BackgroundProvider.Process(const AContext: TProcessingContext): TProviderResult;
var
  LOption: TOptionItem;
begin
  Result := Default(TProviderResult);
  Result.Source := 'rule';

  // If domain context already has a clear active intent, route directly
  if Trim(AContext.DomainContext.ActiveIntent) <> '' then
  begin
    Result.Success := True;
    Result.Question := '';
    Result.RecommendedOption := 1;

    LOption.Number := 1;
    LOption.Text := AContext.DomainContext.ActiveIntent;
    LOption.Value := AContext.DomainContext.ActiveIntent;
    LOption.IsRecommended := True;
    Result.Options := [LOption];
    Exit;
  end;

  // Otherwise generate a simple routing question with domain-based options
  Result.Success := True;
  Result.Question := '请问您想做什么？';
  Result.RecommendedOption := 1;

  // Provide a generic option based on available domain info
  LOption.Number := 1;
  if Trim(AContext.DomainContext.DomainName) <> '' then
    LOption.Text := '继续使用 ' + AContext.DomainContext.DomainName
  else
    LOption.Text := '开始新任务';
  LOption.Value := LOption.Text;
  LOption.IsRecommended := True;
  Result.Options := [LOption];
end;

end.
