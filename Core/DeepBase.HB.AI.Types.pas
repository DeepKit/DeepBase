{ ============================================================================
  DeepBase.HB.AI.Types - Dual-Pane AI Console Contract Types

  Version: 1.0 (Delphi 13.1 on Win64 / Cross-Platform RTL)
  Description: Shared contracts for THbAIConsole:
               - Model tiers & pricing/latency metadata
               - Thinking chain (Thought Fold) data
               - Diff review propose item structures
  ============================================================================ }

unit DeepBase.HB.AI.Types;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  DeepBase.HB.Core;

type
  /// <summary>
  /// Model tier identifier.
  /// </summary>
  THbAIModelKind = (
    aimLocal8B,     // Local offline model (0 latency, free, sovereign)
    aimCloudPro,    // Cloud deep reasoning (DeepSeek-R1 / Claude 3.7)
    aimCloudFlash   // Cloud fast lightweight (Claude 3.5 Flash)
  );

  /// <summary>
  /// Metadata for an AI model backend.
  /// </summary>
  THbAIModelInfo = record
    Kind: THbAIModelKind;
    Name: string;
    Provider: string;
    PricePerKTokens: Double;
    IsOffline: Boolean;
    EstimatedLatencyStr: string;
  end;

  /// <summary>
  /// Status of an AI proposed Diff change.
  /// </summary>
  THbProposeStatus = (
    psPending,      // Waiting for human confirmation
    psAccepted,     // Accepted by human (Ctrl+Enter)
    psRejected,     // Rejected by human
    psModified      // Modified in-place before acceptance
  );

  /// <summary>
  /// Single proposal item for Diff review.
  /// </summary>
  THbProposeDiffItem = record
    Id: string;
    TargetKey: string;
    TargetLabel: string;
    OldValue: string;
    NewValue: string;
    Reason: string;
    Status: THbProposeStatus;
    TimestampStr: string;
  end;

  /// <summary>
  /// Step entry in the Chain-of-Thought (Thought Fold).
  /// </summary>
  THbThoughtStep = record
    StepIndex: Integer;
    TimestampStr: string;
    Summary: string;
    EvidenceCount: Integer;
    DurationMs: Integer;
    DetailLog: string;
  end;

implementation

end.
