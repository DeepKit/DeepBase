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
    ['{A1B2C3D4-E5F6-4A5B-8C9D-0E1F2A3B4C5D}']
    function GetSlotId: string;                     // 槽位标识符（如 'business' / 'trust' / 'audit'）
    function GetStateLabel: string;                 // 用于无障碍与遥测的状态文本
    function GetStateRank: Integer;                 // 状态权重/安全等级（用于决定视觉层级或告警优先级）
  end;

implementation

end.
