// AI-GENERATED
// DeepBase.Governance.Interfaces.pas
// 第二层：接口定义（依赖 Types）
// 10 个核心接口

unit DeepBase.Governance.Interfaces;

interface

uses
  System.JSON,
  DeepBase.Governance.Types,
  DeepBase.Governance.Model,
  DeepBase.Governance.ReviewQueue;

type
  /// Runtime 入口接口
  IOCGSRuntime = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    function EnterGate(const AGateKey: string; AContext: TJSONObject;
      AMode: TRunMode; const AConfirmation: string = ''): TActionResult;
    function PreviewGate(const AGateKey: string;
      AContext: TJSONObject): TGateResolution;
    function GetAvailableActions(AContext: TJSONObject): TArray<TActionInfo>;
  end;

  /// 行为网格接口
  IActionGrid = interface
    ['{B2C3D4E5-F6A7-8901-BCDE-F12345678901}']
    procedure RegisterAction(const AActionKey: string; const ADisplayName: string;
      ARiskLevel: TRiskLevel);
    function Run(const AActionKey: string; AContext: TJSONObject;
      AMode: TRunMode): TActionResult;
    function CanRun(const AActionKey: string; AContext: TJSONObject): Boolean;
    function GetDisabledReason(const AActionKey: string;
      AContext: TJSONObject): string;
    procedure SetEnabled(const AActionKey: string; AEnabled: Boolean);
    function GetActionInfo(const AActionKey: string): TActionInfo;
    function GetAllActions: TArray<TActionInfo>;
  end;

  /// 门禁解析接口
  IGateResolver = interface
    ['{C3D4E5F6-A7B8-9012-CDEF-123456789012}']
    function Resolve(const AGateKey: string;
      AContext: TJSONObject): TGateResolution;
    function GetState(const AGateKey: string;
      AContext: TJSONObject): TGateState;
  end;

  /// 路由解析接口
  IRouteResolver = interface
    ['{D4E5F6A7-B8C9-0123-DEFA-234567890123}']
    function Resolve(const ASourceGateKey: string;
      APayload: TJSONObject): string;
    function GetFallback(const ASourceGateKey: string): string;
    procedure ReloadRules;
  end;

  /// 行为执行器接口
  IActionExecutor = interface
    ['{E5F6A7B8-C9D0-1234-EFAB-345678901234}']
    // ASY-GOV-006 阶段3：AConfirmation = 人工裁决凭证（review_id）。
    // 空串表示该 action 无需裁决（向后兼容）；非空时由 verifier 校验批准。
    function Execute(const AActionKey: string; AContext: TJSONObject;
      AMode: TRunMode; const AConfirmation: string = ''): TActionResult;
    procedure SetVerifier(const AVerifier: IReviewDecisionVerifier);
  end;

  /// 合当判定接口
  IDueChecker = interface
    ['{F6A7B8C9-D0E1-2345-FABC-456789012345}']
    function Check(const AActionKey: string;
      AContext: TJSONObject): TDueResult;
    function GetReason(const AActionKey: string): string;
  end;

  /// 投射解析接口
  IProjectionResolver = interface
    ['{A7B8C9D0-E1F2-3456-ABCD-567890123456}']
    function GetEnabled(const AKey: string; AContext: TJSONObject): Boolean;
    function GetHint(const AKey: string; AContext: TJSONObject): string;
    procedure RefreshAll;
  end;

  /// 反馈解析接口
  IFeedbackResolver = interface
    ['{B8C9D0E1-F2A3-4567-BCDE-678901234567}']
    function GetFeedback(const AGateKey: string;
      AState: TGateState): TFeedbackInfo;
  end;

  /// 证据记录接口
  IEvidenceRecorder = interface
    ['{C9D0E1F2-A3B4-5678-CDEF-789012345678}']
    procedure LogAction(const AActionKey: string; AContext: TJSONObject;
      AResult: TActionResult);
    procedure LogBlocked(const AGateKey: string; const AReason: string;
      AContext: TJSONObject);
  end;

  /// Key 解析接口
  IKeyResolver = interface
    ['{D0E1F2A3-B4C5-6789-DEFA-890123456789}']
    function ResolveGateKey(const AKey: string): TAccessGate;
    function ResolveActionKey(const AKey: string): TAction;
    function Exists(const AKey: string): Boolean;
  end;

  /// Bridge 执行接口（Action → NativeRoutine 的适配层）
  IBridge = interface
    ['{E1F2A3B4-C5D6-7890-EFAB-901234567890}']
    function GetKey: string;
    function Execute(AContext: TJSONObject; AMode: TRunMode): TActionResult;
    function CanExecute(AContext: TJSONObject): Boolean;
  end;

implementation

end.
