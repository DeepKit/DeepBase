{ ============================================================================
  DeepBase.HB.Touchpoint.Types - HB Touchpoint Contract & Evidence Types

  Version: 2.0 (Delphi 13.1 on Win64 / Cross-Platform RTL)
  Description: Frozen contract for Human Behavior Touchpoints and Evidence-Driven UI.
               Complies with docs/30.touchpoint.md v2.0 Section 1.3.
  ============================================================================ }

unit DeepBase.HB.Touchpoint.Types;

interface

uses
  System.SysUtils,
  System.Classes;

type
  /// <summary>
  /// 触点重要度分级
  /// </summary>
  THbTouchpointLevel = (
    tlCritical,   // 关键转化触点（确认对话、提交、支付、高危门禁）
    tlStandard    // 常规交互触点（常规按钮、输入框、菜单项）
  );

  /// <summary>
  /// 触点行为证据数据块
  /// </summary>
  TTouchEvidence = record
    TouchpointId: string;
    SurfaceId: string;
    TimestampUtc: Int64;
    DwellTimeMs: Cardinal;
    Success: Boolean;
    BeforeState: string;
    AfterState: string;
    ActionType: string;
    ExitPosition: string;
    ErrorCode: Integer;
    SupportDeflected: Boolean;
  end;

  /// <summary>
  /// 触点指标定义与度量契约
  /// </summary>
  TMetricDefinition = record
    MetricKey: string;
    BaseValue: Double;
    TargetValue: Double;
    AchievedValue: Double;
  end;

  /// <summary>
  /// HB 触点核心接口 - 每一个合格触点必须实现的唯一标准
  /// </summary>
  IHbTouchpoint = interface
    ['{8F9B6E12-4C3D-4E5F-8A9B-1C2D3E4F5A6B}']
    function GetID: string;
    function GetLevel: THbTouchpointLevel;
    function GetBeforeState: string;
    function GetAction: string;
    function GetAfterState: string;
    function GetMeasure: TMetricDefinition;
    function EmitEvidence: TTouchEvidence;
    procedure ExecuteNextAction;
    procedure ExecuteFallbackAction;
  end;

  /// <summary>
  /// HB 遥测持久化驱动接口（注入式持久化槽，纯 RTL，零重依赖）
  /// </summary>
  IHbTelemetrySink = interface
    ['{7E9F4B12-9A8C-4F3D-B2E1-6C5D4A3F2E1B}']
    procedure PersistEvidence(const AEvidence: TArray<TTouchEvidence>);
    procedure Flush;
  end;

  /// <summary>
  /// HB 会话断点快照提供者契约（由可恢复交互容器实现）
  /// </summary>
  IHbSnapshotProvider = interface
    ['{7D4B6E20-8F31-4A5C-9E12-6B8F0A2C4D6E}']
    function GetSurfaceId: string;
    function GetControlId: string;
    function CaptureSnapshot: string;
    procedure RestoreSnapshot(const APayload: string);
  end;

implementation

end.

