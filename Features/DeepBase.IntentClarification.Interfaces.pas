unit DeepBase.IntentClarification.Interfaces;

interface

uses
  System.SysUtils,
  DeepBase.IntentClarification.Types,
  DeepBase.IntentClarification,
  DeepBase.LLM.Client;

type
  // === 支撑类型（接口方法所需，Types.pas 中未定义） ===

  /// <summary>会话句柄，用于标识和操作一个活跃会话</summary>
  TSessionHandle = record
    Id: string;
    class function Create(const AId: string): TSessionHandle; static;
  end;

  /// <summary>启动澄清会话的请求参数</summary>
  TClarificationStartRequest = record
    UserId: string;
    DomainName: string;
    IntentName: string;
    InitialInput: string;
    Locale: string;
    Template: string;            // 预设模板名称（可选）
    BudgetOverride: TBudgetConfig; // 预算覆盖（可选）
    HasBudgetOverride: Boolean;
  end;

  /// <summary>挂起会话的结果</summary>
  TSuspendResult = record
    Success: Boolean;
    SessionId: string;
    CheckpointSaved: Boolean;
    ResumeHint: string;
    ErrorMessage: string;
  end;

  /// <summary>恢复会话的结果</summary>
  TResumeResult = record
    Success: Boolean;
    SessionId: string;
    RestoredTurnCount: Integer;
    ErrorMessage: string;
  end;

  /// <summary>取消会话的结果</summary>
  TCancelResult = record
    Success: Boolean;
    SessionId: string;
    Summary: string;
    ErrorMessage: string;
  end;

  /// <summary>领域上下文信息，由 DomainAdapter 提供</summary>
  TDomainContext = record
    DomainName: string;
    SessionId: string;
    ActiveIntent: string;
    ContextSummary: string;
    Metadata: TArray<string>;    // Key=Value 对
  end;

  /// <summary>退出结果，包含退出时的摘要和恢复信息</summary>
  TExitResult = record
    SessionId: string;
    Reason: string;              // 'user_cancel' | 'budget_exhausted' | 'auto_complete' | 'frustration'
    Summary: string;
    ResumeHint: string;
    BestGuessIntent: string;
    CheckpointSaved: Boolean;
  end;

  /// <summary>澄清过程中的错误信息</summary>
  TClarificationError = record
    Code: string;
    Message: string;
    SessionId: string;
    Recoverable: Boolean;
  end;

  /// <summary>级别处理器的处理上下文</summary>
  TProcessingContext = record
    SessionId: string;
    UserInput: string;
    Level: TClarificationLevel;
    Posture: TPosture;
    Depth: Double;
    TurnCount: Integer;
    DomainContext: TDomainContext;
    Signals: TArray<TDetectedSignal>;
    Hypotheses: TArray<THypothesis>;
    History: TArray<TTurnRecord>;
  end;

  /// <summary>级别处理器的处理结果</summary>
  TProviderResult = record
    Success: Boolean;
    Question: string;
    Options: TArray<TOptionItem>;
    Scaffolds: TArray<string>;
    RecommendedOption: Integer;
    Source: string;              // 'rule' | 'llm'
    ErrorMessage: string;
  end;

  /// <summary>专家角色配置</summary>
  TPersonaProfile = record
    Id: string;
    Name: string;
    Role: string;               // 专家领域
    Style: string;              // 沟通风格
    KnowledgeAreas: TArray<string>;
    Description: string;
  end;

  /// <summary>预判引擎的输入上下文</summary>
  TAnticipationContext = record
    UserId: string;
    SessionId: string;
    CurrentInput: string;
    DomainContext: TDomainContext;
    RecentHistory: TArray<TTurnRecord>;
    RapportProfile: TRapportProfile;
  end;

  /// <summary>已解析的意图，用于可行性检查</summary>
  TResolvedIntent = record
    IntentName: string;
    Confidence: Double;
    Slots: TArray<TIntentClarificationSlot>;
    DomainName: string;
    Source: string;
  end;

  /// <summary>可行性检查结果</summary>
  TFeasibilityResult = record
    Feasible: Boolean;
    Reason: string;
    Suggestions: TArray<string>;
    BlockingSlots: TArray<string>;
  end;

  /// <summary>用户行为模式，用于学习适配器</summary>
  TUserPattern = record
    UserId: string;
    PatternType: string;        // 'slot_preference' | 'depth_preference' | 'style_preference'
    Key: string;
    Value: string;
    Confidence: Double;
    ObservedAt: TDateTime;
  end;

  /// <summary>自动填充建议</summary>
  TAutoFillSuggestion = record
    SlotName: string;
    SuggestedValue: string;
    Confidence: Double;
    Evidence: string;
    ShouldApply: Boolean;
  end;

  // === Forward declarations for interfaces ===
  IDomainAdapter = interface;
  IPresenter = interface;
  ILevelProvider = interface;
  IPersonaRegistry = interface;
  IAnticipationEngine = interface;

  // === 核心接口 ===

  /// <summary>
  /// 引擎主接口 - 管理会话生命周期和轮次循环
  /// Requirements: 12.1
  /// </summary>
  IClarificationEngine = interface
    ['{E1A2B3C4-D5E6-7890-ABCD-111111111111}']
    function StartSession(const ARequest: TClarificationStartRequest): TSessionHandle;
    function SubmitInput(const AHandle: TSessionHandle; const AInput: string): TTurnResult;
    function SuspendSession(const AHandle: TSessionHandle): TSuspendResult;
    function ResumeSession(const AHandle: TSessionHandle): TResumeResult;
    function CancelSession(const AHandle: TSessionHandle): TCancelResult;
    function GetSessionState(const AHandle: TSessionHandle): TSessionState;
    // Configuration methods
    procedure SetDomainAdapter(const AAdapter: IDomainAdapter);
    procedure SetPresenter(const APresenter: IPresenter);
    procedure RegisterProvider(const AProvider: ILevelProvider);
    procedure SetLLM(const ALLM: ILLMClient);
    procedure SetPersonaRegistry(const ARegistry: IPersonaRegistry);
    procedure SetAnticipationEngine(const AAnticipation: IAnticipationEngine);
  end;

  /// <summary>
  /// 领域适配器接口 - 为特定产品/领域提供上下文和知识
  /// Requirements: 12.2
  /// </summary>
  IDomainAdapter = interface
    ['{E1A2B3C4-D5E6-7890-ABCD-222222222222}']
    function GetDomainName: string;
    function GetMaxLevel: TClarificationLevel;
    function GetContextForSession(const ASessionId: string): TDomainContext;
    function GetDomainKnowledge(const ATopic: string): string;
    function GetPresetSlots(const AIntentName: string): TArray<TIntentClarificationSlot>;
  end;

  /// <summary>
  /// 呈现器接口 - 将澄清结果委托给调用方进行 UI 渲染
  /// Requirements: 12.3
  /// </summary>
  IPresenter = interface
    ['{E1A2B3C4-D5E6-7890-ABCD-333333333333}']
    procedure PresentTurn(const ATurnResult: TTurnResult);
    procedure PresentExit(const AExitResult: TExitResult);
    procedure PresentError(const AError: TClarificationError);
  end;

  /// <summary>
  /// 级别处理器接口 - 各级别（L0-L4）的统一处理抽象
  /// Requirements: 12.1
  /// </summary>
  ILevelProvider = interface
    ['{E1A2B3C4-D5E6-7890-ABCD-888888888888}']
    function GetLevel: TClarificationLevel;
    function CanHandle(const AContext: TProcessingContext): Boolean;
    function Process(const AContext: TProcessingContext): TProviderResult;
    function RequiresLLM: Boolean;
  end;

  // === 可选接口 ===

  /// <summary>
  /// 专家角色注册表接口 - 为 L3/L4 提供专家角色选择
  /// Requirements: 12.6
  /// </summary>
  IPersonaRegistry = interface
    ['{E1A2B3C4-D5E6-7890-ABCD-444444444444}']
    function GetPersona(const AId: string): TPersonaProfile;
    function FindBestMatch(const AContext: TDomainContext): TPersonaProfile;
    function FindComplementaryPanel(const AContext: TDomainContext;
      ACount: Integer): TArray<TPersonaProfile>;
  end;

  /// <summary>
  /// 预判引擎接口 - 基于多信号源预测用户意图
  /// Requirements: 12.7
  /// </summary>
  IAnticipationEngine = interface
    ['{E1A2B3C4-D5E6-7890-ABCD-555555555555}']
    function Predict(const AContext: TAnticipationContext): TAnticipationResult;
    procedure FeedbackPositive(const APredictionId: string);
    procedure FeedbackNegative(const APredictionId: string);
  end;

  /// <summary>
  /// 可行性检查器接口 - 验证已解析意图的可执行性
  /// Requirements: 12.8
  /// </summary>
  IFeasibilityChecker = interface
    ['{E1A2B3C4-D5E6-7890-ABCD-666666666666}']
    function Check(const AIntent: TResolvedIntent): TFeasibilityResult;
  end;

  /// <summary>
  /// 学习适配器接口 - 记录用户模式并提供自动填充建议
  /// Requirements: 12.6 (扩展)
  /// </summary>
  ILearningAdapter = interface
    ['{E1A2B3C4-D5E6-7890-ABCD-777777777777}']
    procedure RecordPattern(const APattern: TUserPattern);
    function ShouldAutoFill(const ASlotName: string;
      const AContext: TDomainContext): TAutoFillSuggestion;
  end;

implementation

// === TSessionHandle ===

class function TSessionHandle.Create(const AId: string): TSessionHandle;
begin
  Result.Id := AId;
end;

end.
