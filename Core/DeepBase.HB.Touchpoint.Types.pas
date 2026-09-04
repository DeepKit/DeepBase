{ ============================================================================
  DeepBase.HB.Touchpoint.Types - HB Touchpoint Contract & Evidence Types

  Version: 2.0 (Delphi 13.1 on Win64 / Cross-Platform RTL)
  Description: Frozen contract for Human Behavior Touchpoints and Evidence-Driven UI.
               Complies with docs/30.touchpoint.md v2.0 Section 1.3.
  ============================================================================ }

unit DeepBase.HB.Touchpoint.Types;

{ IMPLICIT_STRING_CAST OFF}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections;

type
  /// <summary>
  /// 触点重要度分级（三级分级策略）
  /// </summary>
  THbTouchpointLevel = (
    tlCritical,   // 关键触点：全量度量（DwellTime/State/Action/11 字段完整证据），100% 采样
    tlStandard    // 常规触点：轻量度量（仅 TouchpointId + ActionType + TimestampUtc），降采样或聚合
    // 注：非触点由未实现 IHbTouchpoint 或未在引擎登记的控件自然表达，零采集、零开销
  );

  /// <summary>
  /// 触点发生不可逆状态转换时沉淀的确定性证据结构体
  /// </summary>
  TTouchEvidence = record
    TouchpointId: string;       // 触点唯一标识符（如 'tp_gold_checkout_confirm'）
    SurfaceId: string;          // 宿主界面/窗体标识（如 'frm_checkout'）
    TimestampUtc: Int64;        // 发生时间戳 (Unix Epoch ms, UTC)
    DwellTimeMs: Integer;       // 用户在该触点/容器的注视/停留毫秒数
    Success: Boolean;           // 转换是否达成预期成功状态
    BeforeState: string;        // 交互前用户/业务状态（如 'Browsing'）
    AfterState: string;         // 交互后跃迁目标状态（如 'OrderPlaced'）
    ActionType: string;         // 驱动跃迁的物理动作（如 'Click' / 'VoiceConfirm' / 'KeyEnter'）
    ExitPosition: string;       // 离开/跳出位置（若转换失败/中断）
    ErrorCode: string;          // 错误码（Fail-Closed 时记录，成功为空）
    SupportDeflected: Boolean;  // 本次交互是否成功避免了客服介入（零客服闭环证据）
  end;

  /// <summary>
  /// 四自指标目标与实测对照记录
  /// </summary>
  TMetricDefinition = record
    MetricKey: string;          // 指标标识（如 'SDR' / 'FCR' / 'CSAT' / 'TTF'）
    BaseValue: Double;          // 历史/行业基线值
    TargetValue: Double;        // 本触点设定的目标值
    AchievedValue: Double;      // 运行时采集的实测值
  end;

  /// <summary>
  /// 触点核心代码级契约接口
  /// </summary>
  IHbTouchpoint = interface
    ['{8F9B6E12-4C3D-4E5F-8A9B-1C2D3E4F5A6B}']
    function GetTouchpointId: string;
    function GetSurfaceId: string;
    function GetLevel: THbTouchpointLevel;
    function GetTargetState: string;
    function GetMetricDefinitions: TArray<TMetricDefinition>;
    function TransformState(const ACurrentState: string; const AActionContext: string): string;
    function EmitEvidence(const AEvidence: TTouchEvidence): Boolean;
    function ValidateZeroSupportClosure: Boolean;
    function EvaluateHealth: Double;
  end;

implementation

end.
