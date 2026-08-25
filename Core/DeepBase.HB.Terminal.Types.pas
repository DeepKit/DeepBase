{ ============================================================================
  DeepBase.HB.Terminal.Types - Data Types for Terminal, Shell & Agent Views

  Version: 1.0 (Delphi 13.1 on Win64 / Cross-Platform RTL)
  Description: Framework-agnostic type definitions for Key-Value rows,
               Agent delta streaming blocks, MCP capabilities, and Toast
               host notifications in DeepDsh & DeepBase.
  ============================================================================ }

unit DeepBase.HB.Terminal.Types;

interface

uses
  System.SysUtils,
  System.Classes,
  DeepBase.HB.Core;

type
  /// <summary>
  /// Stream block rendering stage for LLM Agent output.
  /// </summary>
  THbStreamStage = (ssThinking, ssCommitted, ssCompleted, ssError);

  /// <summary>
  /// MCP Server / Tool connectivity status.
  /// </summary>
  THbMcpStatus = (msConnected, msConnecting, msUnavailable, msError);

  /// <summary>
  /// Security / Tool Approval decision state.
  /// </summary>
  THbApprovalState = (asPending, asApprovedOnce, asApprovedAlways, asRejected, asBlocked);

  /// <summary>
  /// Toast host vertical alignment position on form.
  /// </summary>
  THbToastPosition = (tpTopRight, tpBottomRight, tpTopCenter, tpBottomCenter);

  /// <summary>
  /// Individual streaming delta chunk for Agent thought & text.
  /// </summary>
  THbStreamDelta = record
    Sequence: Int64;
    IsThought: Boolean;
    DeltaText: string;
    Timestamp: TDateTime;
  end;

  /// <summary>
  /// MCP Server metadata record.
  /// </summary>
  THbMcpServerInfo = record
    Id: string;
    Name: string;
    Endpoint: string;
    Status: THbMcpStatus;
    ToolCount: Integer;
    ResourceCount: Integer;
    PromptCount: Integer;
    LatencyMs: Integer;
    ErrorMessage: string;
  end;

  /// <summary>
  /// Key-Value property display item.
  /// </summary>
  THbPropertyItem = record
    Key: string;
    Value: string;
    Category: string;
    IsMasked: Boolean;
    IsMonospace: Boolean;
    CanCopy: Boolean;
    BadgeText: string;
    BadgeTone: THbBadgeTone;
  end;

implementation

end.
