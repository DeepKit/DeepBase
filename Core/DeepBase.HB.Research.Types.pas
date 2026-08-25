{ ============================================================================
  DeepBase.HB.Research.Types - Data Types & API Contracts for Research Discovery
                                & Evidence Audit Infrastructure

  Version: 1.0 (Delphi 13.1 on Win64 / Cross-Platform RTL)
  Description: Framework-agnostic type definitions, PFM 7-field structures,
               evidence audit records, and interaction contracts for DeepRW
               and downstream research workbenches.
  ============================================================================ }

unit DeepBase.HB.Research.Types;

interface

uses
  System.SysUtils,
  System.Classes,
  System.UITypes,
  System.Generics.Collections,
  DeepBase.HB.Core;

type
  /// <summary>
  /// Stage rail execution state for multi-step workflows.
  /// </summary>
  THbStageState = (ssCompleted, ssActive, ssPending, ssWarning, ssBlocked);

  /// <summary>
  /// Signal classification types for raw input discovery.
  /// </summary>
  THbSignalType = (stAnomaly, stContradiction, stRepeatedFailure, stKnowledgeGap, stWeakSignal, stDiscomfort);

  /// <summary>
  /// Signal lifecycle status.
  /// </summary>
  THbSignalStatus = (sigRaw, sigLinked, sigExcluded);

  /// <summary>
  /// Structured field certainty state.
  /// </summary>
  THbFieldCertainty = (fcEmpty, fcAiCandidate, fcConfirmed, fcDisputed);

  /// <summary>
  /// Boundary notification and handoff severity level.
  /// </summary>
  THbBoundaryLevel = (blNotice, blCaution, blStop, blHandoff);

  /// <summary>
  /// Evidence quote polarity regarding a claim.
  /// </summary>
  THbEvidencePolarity = (epSupport, epDispute, epBackground, epUnknown);

  /// <summary>
  /// Quality/Protocol Gate verification verdict.
  /// </summary>
  THbGateVerdict = (gvPass, gvWarning, gvError, gvBlocked);

  /// <summary>
  /// Human researcher decision action types.
  /// </summary>
  THbDecisionAction = (daConfirm, daReject, daClarify, daSplit, daMerge, daDefer, daHandoff);

  /// <summary>
  /// Raw Signal Record for research discovery input.
  /// </summary>
  THbSignalItem = record
    Id: string;
    RawQuote: string;
    SourceTitle: string;
    SourceAnchor: string;
    Timestamp: TDateTime;
    SignalType: THbSignalType;
    Confidence: Single; // 0.0 - 1.0
    IsHumanConfirmed: Boolean;
    Status: THbSignalStatus;
    LinkedFieldId: string;
  end;

  /// <summary>
  /// Individual Structured Field representation in PFM or generic schemas.
  /// </summary>
  THbStructuredField = record
    FieldKey: string;
    FieldLabel: string;
    FieldValue: string;
    Certainty: THbFieldCertainty;
    SourcesCount: Integer;
    DisputeReason: string;
    AiRationale: string;
    LastModified: TDateTime;
  end;

  /// <summary>
  /// PFM (Problem Field Manifestation) 7-Field Intake minimum structure.
  /// </summary>
  TPfmStructuredIntake = record
    IssueField: THbStructuredField;     // 问题场
    PressureBearer: THbStructuredField; // 承压者
    Constraint: THbStructuredField;     // 约束
    WeakSignal: THbStructuredField;     // 弱信号
    BoundaryNotice: THbStructuredField; // 边界提示
    HandoffTarget: THbStructuredField;  // 转交目标
    StopCondition: THbStructuredField;  // 停止条件

    procedure InitDefaults;
    function IsCompleteForCandidateGeneration: Boolean;
  end;

  /// <summary>
  /// Research Theme/Question Candidate for side-by-side comparison.
  /// </summary>
  THbResearchCandidate = record
    Id: string;
    Title: string;
    CoreQuestion: string;
    FeasibilityScore: Single;
    EvidenceAvailability: Single;
    ValueImpact: Single;
    EthicalRiskNotes: string;
    KeyBasis: string;
    CounterEvidence: string;
    KnownBoundaries: string;
    NextSteps: string;
    IsPinned: Boolean;
    IsPromoted: Boolean;
  end;

  /// <summary>
  /// Exact Evidence Excerpt with source reference and cryptographic snapshot.
  /// </summary>
  THbEvidenceExcerptItem = record
    Id: string;
    ClaimId: string;
    SourceTitle: string;
    SourceUrl: string;
    ExactAnchor: string; // e.g. "p.42 §2.1"
    ExactQuote: string;
    SnapshotHash: string;
    IsHashVerified: Boolean;
    Polarity: THbEvidencePolarity;
    Confidence: Single;
  end;

  /// <summary>
  /// Gate check rule verification item.
  /// </summary>
  THbGateCheckRule = record
    RuleId: string;
    RuleTitle: string;
    Verdict: THbGateVerdict;
    Explanation: string;
    TargetObjectId: string;
    RepairHint: string;
  end;

  /// <summary>
  /// Lineage Provenance step node.
  /// </summary>
  THbProvenanceNode = record
    NodeId: string;
    NodeTitle: string;
    Category: string;
    Timestamp: TDateTime;
    IsBrokenLink: Boolean;
    IsCurrent: Boolean;
  end;

implementation

{ TPfmStructuredIntake }

procedure TPfmStructuredIntake.InitDefaults;
  procedure SetupField(var F: THbStructuredField; const AKey, ALabel: string);
  begin
    F.FieldKey := AKey;
    F.FieldLabel := ALabel;
    F.FieldValue := '';
    F.Certainty := fcEmpty;
    F.SourcesCount := 0;
    F.DisputeReason := '';
    F.AiRationale := '';
    F.LastModified := Now;
  end;
begin
  SetupField(IssueField, 'issue_field', '问题场');
  SetupField(PressureBearer, 'pressure_bearer', '承压者');
  SetupField(Constraint, 'constraint', '核心约束');
  SetupField(WeakSignal, 'weak_signal', '前线弱信号');
  SetupField(BoundaryNotice, 'boundary_notice', '边界提示');
  SetupField(HandoffTarget, 'handoff_target', '专业转交目标');
  SetupField(StopCondition, 'stop_condition', '停止研究条件');
end;

function TPfmStructuredIntake.IsCompleteForCandidateGeneration: Boolean;
begin
  Result := (IssueField.FieldValue <> '') and
            (PressureBearer.FieldValue <> '') and
            (Constraint.FieldValue <> '') and
            (StopCondition.FieldValue <> '');
end;

end.
