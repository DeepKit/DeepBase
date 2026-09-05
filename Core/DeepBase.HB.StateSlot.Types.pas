{ ============================================================================
  DeepBase.HB.StateSlot.Types - Pluggable State Slot Interface

  Version: 2.0 (Delphi 13.1 on Win64 / Cross-Platform RTL)
  Description: Pluggable State Slot Provider interface for HB Runtime.
               Complies with docs/29.ui-runtime.md v2.0 Section 3.1.
               STRICT ISOLATION: Zero business enums in Core layer.
  ============================================================================ }

unit DeepBase.HB.StateSlot.Types;

{ IMPLICIT_STRING_CAST OFF}

interface

uses
  System.SysUtils;

type
  /// <summary>
  /// 状态槽提供者接口：将外部状态源投影为 HB 控件可消费的标准化属性
  /// </summary>
  IHbStateSlotProvider = interface
    ['{E3A1C590-7D82-4F6B-B415-9C0E2A4F8D17}']
    function GetSlotId: string;                     // 槽位标识符（如 'business' / 'trust' / 'audit'）
    function GetStateLabel: string;                 // 用于无障碍与遥测的状态文本
    function GetStateRank: Integer;                 // 状态权重/安全等级（用于决定视觉层级或告警优先级）
  end;

implementation

end.
