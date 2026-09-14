{ ============================================================================
  DeepBase.EHAI.Types - Delphi Semantic Implementation for EHAI Language Common Layer

  Version: 1.0 (Delphi 13.1 on Win64 / Cross-Platform RTL)
  Specification: EHAI Language-Neutral Realization Contract v0 (APPROVED ENGINEERING BASELINE v0)
  Description: Delphi semantic binding for EHAI cross-language contract:
               - CandidateSpace & RecommendedMark (bounded <= 7, non-executing)
               - CandidateSelection (Choose meta-action, CandidateSelection != Inherent Commitment)
               - Regenerate (pure exploratory, non-committing, zero canonical mutation)
               - HumanOverride & FrameRejection tri-state:
                 * eokCandidateReject (reject candidates within frame)
                 * eokAlternativeExpression (custom parameters within frame)
                 * eokFrameRejection (reject problem framing / refute premise)
               - BackNavigation (0 Exit without Commitment != Reject != Consent != Judgment)
               - SourceDistinction (Human-stated vs AI-derived Interpretation)
               - CommitmentBoundary & AuthorityBasis (Standing/Prior/Rule/Explicit)
               - ContextBinding, Anti-Drift verification & RecoverableLineage
               - Strictly free from product domain types (No AsWish/AXIS leakage)
  ============================================================================ }

unit DeepBase.EHAI.Types;

{$WARN IMPLICIT_STRING_CAST OFF}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections;

type
  /// <summary>
  /// Human Involvement Profiles (L4 §3 / L3 §3.2).
  /// Five equal semantic roles, orthogonally combinable.
  /// </summary>
  TEhaiInvolvementProfile = (
    eipInform,     // 1. Inform: Unidirectional notice, disclosure, status presentation
    eipProvide,    // 2. Provide: Supplement facts, preferences, constraints, parameters
    eipJudge,      // 3. Judge: Sovereign valuation, ranking, trade-off, selection
    eipAuthorize,  // 4. Authorize: Explicit permission crossing boundary of control & liability
    eipAct         // 5. Act: Physical / real-world human action execution
  );

  /// <summary>
  /// Semantic source / Epistemic qualification origin (L4 §6, L6 §2.2, Contract §4).
  /// Decouples cognitive source from physical hardware input device.
  /// </summary>
  TEhaiSource = (
    esHuman,       // Human-stated direct input or sovereign commitment
    esAI,          // AI / Model-derived interpretation or recommendation
    esInferred,    // Machine heuristic or probabilistic inference
    esRule,        // Deterministic rule-derived logic
    esTool,        // Environment / tool probe observation
    esSystem       // System infrastructure / orchestration event
  );

  /// <summary>
  /// Standard Choice Grammar Meta Actions (L4 §5, Contract §2).
  /// </summary>
  TEhaiMetaAction = (
    emaChoose,      // 1..7 Pointer citation grammar; formal semantics determined by Profile+Context
    emaRegenerate,  // 8 Non-committing candidate regeneration within current frame (8 != Judgment)
    emaReframe,     // 9 Frame escape / custom expression / human override (9 != Reject)
    emaExit         // 0 Non-committing exit / navigation back (0 != Reject, 0 != Consent)
  );

  /// <summary>
  /// Frame Rejection & Override Tri-State Classification (Contract §1 SRC-05/SRC-06, §2.4/§2.5).
  /// Explicitly distinguishes the semantic nature of human override.
  /// </summary>
  TEhaiOverrideKind = (
    eokNone,                    // No override (normal candidate selection or control action)
    eokCandidateReject,         // Sub-kind 1: Candidate Rejection (reject current candidate set, request new options within same frame)
    eokAlternativeExpression,   // Sub-kind 2: Alternative Expression (provide custom value/parameter/text within same frame)
    eokFrameRejection           // Sub-kind 3: Frame Rejection (reject problem framing, refute premise, reframe goal)
  );

  /// <summary>
  /// Inform Profile Semantic States (L4 §3.1).
  /// Four independent semantic states: Available != Presented != Acknowledged != Agreed.
  /// </summary>
  TEhaiInformState = (
    eisAvailable,     // Information available in notification/inbox
    eisPresented,     // Information presented in active user viewport
    eisAcknowledged,  // Explicit human acknowledgement receipt (Acknowledged != Agreed)
    eisAgreed         // Explicit human agreement/endorsement (beyond pure inform)
  );

  /// <summary>
  /// Semantic Effect Classification (L6 §2.2, Contract §3).
  /// </summary>
  TEhaiSemanticEffectKind = (
    eseInformOnly,      // Presentation / receipt only
    eseDataProvided,    // Data / parameter bound
    eseJudgmentMade,    // Value judgment / choice recorded
    eseAuthorized,      // Scope / action permission granted
    eseActionReported   // Human action attestation recorded
  );

  /// <summary>
  /// Authority Basis Kind (Contract §3.2, L3 §10.4).
  /// Compatible with: Need Authorization != Need Repeated Manual Authorization.
  /// </summary>
  TEhaiAuthorityBasisKind = (
    eabExplicitConfirmation,  // Explicit human review click / confirmation
    eabPriorAuthorization,    // Pre-approved batch or scoped permission
    eabStandingAuthorization, // Ongoing standing policy authorization
    eabRuleDerivedAuthority   // Deterministic regulatory / organizational rule authority
  );

  /// <summary>
  /// Decision Cardinality Parameter (L4 §5.5, Contract §2.2).
  /// </summary>
  TEhaiCardinality = (
    ecSingle,    // Single-choice selection
    ecMultiple   // Multi-choice selection
  );

  /// <summary>
  /// Authority Basis Envelope.
  /// </summary>
  TEhaiAuthorityBasis = record
    Kind: TEhaiAuthorityBasisKind;
    AuthorityHolder: string;
    ScopeBoundary: string;
    CeilingAmount: Double;
    ConditionExpr: string;
    EstablishedAt: TDateTime;
    ExpiresAt: TDateTime;
    class function CreateExplicit(const AHolder, AScope: string): TEhaiAuthorityBasis; static;
    class function CreateStanding(const AHolder, AScope, ACondition: string;
      ACeiling: Double = 0.0; AExpiresAt: TDateTime = 0.0): TEhaiAuthorityBasis; static;
    class function CreateRuleDerived(const ARuleId, AScope: string): TEhaiAuthorityBasis; static;
    function IsValidAt(ATimestamp: TDateTime): Boolean;
    function Covers(const AScope: string; AAmount: Double = 0.0): Boolean;
  end;

  /// <summary>
  /// Decision Context Binding Envelope (L4 §6, Contract §1 SRC-10, §4.3).
  /// Recoverable + Traceable + Context-Bound.
  /// </summary>
  TEhaiContextBinding = record
    ContextId: string;
    ContextTitle: string;
    StepInfo: string;
    ObservableObjectRef: string;
    ScopeBoundary: string;
    AuthorityHolder: string;
    CreatedAt: TDateTime;
    class function Create(const AContextId, ATitle, AStepInfo, AObjectRef,
      AScope, AAuthority: string): TEhaiContextBinding; static;
    function IsValid: Boolean;
    function IsEqual(const Other: TEhaiContextBinding): Boolean;
  end;

  /// <summary>
  /// Single Candidate Item within CandidateSpace (Contract §2.1, SRC-01, SRC-02).
  /// </summary>
  TEhaiCandidate = record
    Key: Integer;                // 1..7 (or 8, 9, 0 for controls)
    Text: string;               // Candidate title / summary
    Description: string;        // Secondary details
    IsRecommended: Boolean;     // Priority recommendation marker (1 only; Recommended != Best)
    Enabled: Boolean;
    Payload: NativeInt;         // Application domain context handle
    class function Create(AKey: Integer; const AText: string;
      const ADesc: string = ''; AIsRecommended: Boolean = False;
      AEnabled: Boolean = True; APayload: NativeInt = 0): TEhaiCandidate; static;
  end;

  /// <summary>
  /// Headless Bounded Candidate Space (Contract §2.1, SRC-01).
  /// Bounded <= 7 candidate options.
  /// </summary>
  TEhaiCandidateSpace = record
  private
    FItems: TArray<TEhaiCandidate>;
    FRecommendedKey: Integer;
    FHasNoReliableCandidates: Boolean;
    FNoReliableMessage: string;
    FCardinality: TEhaiCardinality;
  public
    class function CreateEmpty(ACardinality: TEhaiCardinality = ecSingle): TEhaiCandidateSpace; static;
    class function CreateBounded(const AOptions: array of string;
      ARecommendedKey: Integer = 1; ACardinality: TEhaiCardinality = ecSingle): TEhaiCandidateSpace; static;
    procedure AddOption(AKey: Integer; const AText: string;
      const ADesc: string = ''; AIsRecommended: Boolean = False; APayload: NativeInt = 0);
    procedure SetNoReliableCandidates(const AMessage: string);
    procedure Clear;
    function Count: Integer;
    function GetItem(Index: Integer): TEhaiCandidate;
    function FindByKey(AKey: Integer; out ACandidate: TEhaiCandidate): Boolean;
    property Items[Index: Integer]: TEhaiCandidate read GetItem; default;
    property RecommendedKey: Integer read FRecommendedKey;
    property HasNoReliableCandidates: Boolean read FHasNoReliableCandidates;
    property NoReliableMessage: string read FNoReliableMessage;
    property Cardinality: TEhaiCardinality read FCardinality write FCardinality;
  end;

  /// <summary>
  /// Unified EHAI Interaction Action Payload (Contract §2, §3, §4).
  /// Carries explicit semantic intent, profile, source, override kind, and context binding.
  /// </summary>
  TEhaiInteractionAction = record
    MetaAction: TEhaiMetaAction;
    Key: Integer;                // 0..9 (or -1 for non-keyed actions)
    SelectedKeys: TArray<Integer>; // For multi-choice selections
    Text: string;               // Option title or custom entered free text
    Profile: TEhaiInvolvementProfile;
    Source: TEhaiSource;
    OverrideKind: TEhaiOverrideKind;
    Context: TEhaiContextBinding;
    AuthorityBasis: TEhaiAuthorityBasis;
    Payload: NativeInt;         // Application domain context handle
    Timestamp: TDateTime;

    class function CreateCandidate(AKey: Integer; const AText: string;
      AProfile: TEhaiInvolvementProfile; const AContext: TEhaiContextBinding;
      APayload: NativeInt = 0; ASource: TEhaiSource = esHuman): TEhaiInteractionAction; static;

    class function CreateMultiCandidate(const ASelectedKeys: array of Integer;
      AProfile: TEhaiInvolvementProfile; const AContext: TEhaiContextBinding;
      APayload: NativeInt = 0; ASource: TEhaiSource = esHuman): TEhaiInteractionAction; static;

    class function CreateRegenerate(const AProfile: TEhaiInvolvementProfile;
      const AContext: TEhaiContextBinding; APayload: NativeInt = 0;
      ASource: TEhaiSource = esHuman): TEhaiInteractionAction; overload; static;

    class function CreateRegenerate(const AContext: TEhaiContextBinding;
      APayload: NativeInt = 0; ASource: TEhaiSource = esHuman): TEhaiInteractionAction; overload; static; deprecated 'Use overload with explicit AProfile parameter';

    class function CreateOverride(AOverrideKind: TEhaiOverrideKind;
      const AText: string; const AProfile: TEhaiInvolvementProfile;
      const AContext: TEhaiContextBinding; APayload: NativeInt = 0;
      ASource: TEhaiSource = esHuman): TEhaiInteractionAction; overload; static;

    class function CreateOverride(AOverrideKind: TEhaiOverrideKind;
      const AText: string; const AContext: TEhaiContextBinding;
      APayload: NativeInt = 0; ASource: TEhaiSource = esHuman): TEhaiInteractionAction; overload; static; deprecated 'Use overload with explicit AProfile parameter';

    class function CreateExit(const AProfile: TEhaiInvolvementProfile;
      const AContext: TEhaiContextBinding; APayload: NativeInt = 0;
      ASource: TEhaiSource = esHuman): TEhaiInteractionAction; overload; static;

    class function CreateExit(const AContext: TEhaiContextBinding;
      APayload: NativeInt = 0; ASource: TEhaiSource = esHuman): TEhaiInteractionAction; overload; static; deprecated 'Use overload with explicit AProfile parameter';
  end;

  /// <summary>
  /// Provenance and Lineage Trace Record (Contract §1 SRC-10, §4.3, L6 §2.1).
  /// </summary>
  TEhaiTraceRecord = record
    TraceId: string;
    Source: TEhaiSource;
    ActorIdentity: string;
    Action: TEhaiInteractionAction;
    SemanticEffect: TEhaiSemanticEffectKind;
    IsCommitted: Boolean;
    RecordedAt: TDateTime;
    class function Create(const ATraceId, AActor: string;
      const AAction: TEhaiInteractionAction; AEffect: TEhaiSemanticEffectKind;
      AIsCommitted: Boolean): TEhaiTraceRecord; static;
  end;

  /// <summary>
  /// Context-bound entity contract interface.
  /// </summary>
  IEhaiContextBound = interface
    ['{8A3F1B2C-9E4D-4F5A-8B6C-7D8E9F0A1B2C}']
    function GetContextBinding: TEhaiContextBinding;
  end;

  /// <summary>
  /// Source and provenance traceable entity contract interface.
  /// </summary>
  IEhaiSourceTraceable = interface
    ['{9B4E2C3D-0F5E-4A6B-9C7D-8E9F0A1B2C3D}']
    function GetSource: TEhaiSource;
    function GetActorIdentity: string;
  end;

  /// <summary>
  /// Universal EHAI Interaction Contract Interface.
  /// </summary>
  IEhaiInteractionContract = interface
    ['{AC5F3D4E-1A6F-4B7C-AD8E-9F0A1B2C3D4E}']
    function ProcessAction(const AAction: TEhaiInteractionAction;
      out ATrace: TEhaiTraceRecord): Boolean;
    function ValidateCommitment(const AAction: TEhaiInteractionAction;
      const AAuthority: TEhaiAuthorityBasis): Boolean;
  end;

// Utility functions
function EhaiKeyToMetaAction(AKey: Integer): TEhaiMetaAction;
function EhaiMetaActionToKey(AAction: TEhaiMetaAction): Integer;
function EhaiOverrideKindToStr(AKind: TEhaiOverrideKind): string;
function EhaiProfileToStr(AProfile: TEhaiInvolvementProfile): string;
function EhaiSourceToStr(ASource: TEhaiSource): string;
function EhaiCheckContextDrift(const AInitialBinding, ACurrentBinding: TEhaiContextBinding): Boolean;

implementation

{ TEhaiAuthorityBasis }

class function TEhaiAuthorityBasis.CreateExplicit(const AHolder, AScope: string): TEhaiAuthorityBasis;
begin
  Result.Kind := eabExplicitConfirmation;
  Result.AuthorityHolder := AHolder;
  Result.ScopeBoundary := AScope;
  Result.CeilingAmount := 0.0;
  Result.ConditionExpr := '';
  Result.EstablishedAt := Now;
  Result.ExpiresAt := 0.0;
end;

class function TEhaiAuthorityBasis.CreateStanding(const AHolder, AScope,
  ACondition: string; ACeiling: Double; AExpiresAt: TDateTime): TEhaiAuthorityBasis;
begin
  Result.Kind := eabStandingAuthorization;
  Result.AuthorityHolder := AHolder;
  Result.ScopeBoundary := AScope;
  Result.CeilingAmount := ACeiling;
  Result.ConditionExpr := ACondition;
  Result.EstablishedAt := Now;
  Result.ExpiresAt := AExpiresAt;
end;

class function TEhaiAuthorityBasis.CreateRuleDerived(const ARuleId,
  AScope: string): TEhaiAuthorityBasis;
begin
  Result.Kind := eabRuleDerivedAuthority;
  Result.AuthorityHolder := ARuleId;
  Result.ScopeBoundary := AScope;
  Result.CeilingAmount := 0.0;
  Result.ConditionExpr := '';
  Result.EstablishedAt := Now;
  Result.ExpiresAt := 0.0;
end;

function TEhaiAuthorityBasis.IsValidAt(ATimestamp: TDateTime): Boolean;
begin
  if (ExpiresAt > 0.0) and (ATimestamp > ExpiresAt) then
    Exit(False);
  Result := (AuthorityHolder <> '');
end;

function TEhaiAuthorityBasis.Covers(const AScope: string; AAmount: Double): Boolean;
begin
  if not IsValidAt(Now) then
    Exit(False);

  // Fail-closed: Empty Scope = no authorization (must not be treated as wildcard)
  if ScopeBoundary = '' then
    Exit(False);

  if (ScopeBoundary <> '*') and
     (SameText(ScopeBoundary, AScope) = False) then
    Exit(False);

  // CeilingAmount = 0.0 means no ceiling amount constraint
  if (CeilingAmount > 0.0) and (AAmount > CeilingAmount) then
    Exit(False);

  Result := True;
end;

{ TEhaiContextBinding }

class function TEhaiContextBinding.Create(const AContextId, ATitle, AStepInfo,
  AObjectRef, AScope, AAuthority: string): TEhaiContextBinding;
begin
  Result.ContextId := AContextId;
  Result.ContextTitle := ATitle;
  Result.StepInfo := AStepInfo;
  Result.ObservableObjectRef := AObjectRef;
  Result.ScopeBoundary := AScope;
  Result.AuthorityHolder := AAuthority;
  Result.CreatedAt := Now;
end;

function TEhaiContextBinding.IsValid: Boolean;
begin
  Result := (ContextId <> '') and (ContextTitle <> '');
end;

function TEhaiContextBinding.IsEqual(const Other: TEhaiContextBinding): Boolean;
begin
  Result := (ContextId = Other.ContextId) and
            (ContextTitle = Other.ContextTitle) and
            (ObservableObjectRef = Other.ObservableObjectRef) and
            (ScopeBoundary = Other.ScopeBoundary);
end;

{ TEhaiCandidate }

class function TEhaiCandidate.Create(AKey: Integer; const AText, ADesc: string;
  AIsRecommended, AEnabled: Boolean; APayload: NativeInt): TEhaiCandidate;
begin
  Result.Key := AKey;
  Result.Text := AText;
  Result.Description := ADesc;
  Result.IsRecommended := AIsRecommended;
  Result.Enabled := AEnabled;
  Result.Payload := APayload;
end;

{ TEhaiCandidateSpace }

class function TEhaiCandidateSpace.CreateEmpty(ACardinality: TEhaiCardinality): TEhaiCandidateSpace;
begin
  SetLength(Result.FItems, 0);
  Result.FRecommendedKey := -1;
  Result.FHasNoReliableCandidates := False;
  Result.FNoReliableMessage := '';
  Result.FCardinality := ACardinality;
end;

class function TEhaiCandidateSpace.CreateBounded(const AOptions: array of string;
  ARecommendedKey: Integer; ACardinality: TEhaiCardinality): TEhaiCandidateSpace;
var
  I, Key: Integer;
begin
  Result := CreateEmpty(ACardinality);
  for I := 0 to High(AOptions) do
  begin
    Key := I + 1;
    // Bounded <= 7 valid contextual candidates
    if Key <= 7 then
      Result.AddOption(Key, AOptions[I], '', Key = ARecommendedKey);
  end;
end;

procedure TEhaiCandidateSpace.AddOption(AKey: Integer; const AText, ADesc: string;
  AIsRecommended: Boolean; APayload: NativeInt);
var
  Idx: Integer;
begin
  if AKey > 7 then
    Exit; // Enforce candidate space bound <= 7

  Idx := Length(FItems);
  SetLength(FItems, Idx + 1);
  FItems[Idx] := TEhaiCandidate.Create(AKey, AText, ADesc, AIsRecommended, True, APayload);
  if AIsRecommended then
    FRecommendedKey := AKey;
  FHasNoReliableCandidates := False;
end;

procedure TEhaiCandidateSpace.SetNoReliableCandidates(const AMessage: string);
begin
  FHasNoReliableCandidates := True;
  FNoReliableMessage := AMessage;
end;

procedure TEhaiCandidateSpace.Clear;
begin
  SetLength(FItems, 0);
  FRecommendedKey := -1;
  FHasNoReliableCandidates := False;
  FNoReliableMessage := '';
end;

function TEhaiCandidateSpace.Count: Integer;
begin
  Result := Length(FItems);
end;

function TEhaiCandidateSpace.GetItem(Index: Integer): TEhaiCandidate;
begin
  if (Index >= 0) and (Index < Length(FItems)) then
    Result := FItems[Index]
  else
    FillChar(Result, SizeOf(Result), 0);
end;

function TEhaiCandidateSpace.FindByKey(AKey: Integer; out ACandidate: TEhaiCandidate): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(FItems) do
    if FItems[I].Key = AKey then
    begin
      ACandidate := FItems[I];
      Exit(True);
    end;
end;

{ TEhaiInteractionAction }

class function TEhaiInteractionAction.CreateCandidate(AKey: Integer;
  const AText: string; AProfile: TEhaiInvolvementProfile;
  const AContext: TEhaiContextBinding; APayload: NativeInt;
  ASource: TEhaiSource): TEhaiInteractionAction;
begin
  Result.MetaAction := emaChoose;
  Result.Key := AKey;
  SetLength(Result.SelectedKeys, 1);
  Result.SelectedKeys[0] := AKey;
  Result.Text := AText;
  Result.Profile := AProfile;
  Result.Source := ASource;
  Result.OverrideKind := eokNone;
  Result.Context := AContext;
  FillChar(Result.AuthorityBasis, SizeOf(Result.AuthorityBasis), 0);
  Result.Payload := APayload;
  Result.Timestamp := Now;
end;

class function TEhaiInteractionAction.CreateMultiCandidate(
  const ASelectedKeys: array of Integer; AProfile: TEhaiInvolvementProfile;
  const AContext: TEhaiContextBinding; APayload: NativeInt;
  ASource: TEhaiSource): TEhaiInteractionAction;
var
  I: Integer;
begin
  Result.MetaAction := emaChoose;
  Result.Key := -1;
  SetLength(Result.SelectedKeys, Length(ASelectedKeys));
  for I := 0 to High(ASelectedKeys) do
    Result.SelectedKeys[I] := ASelectedKeys[I];
  Result.Text := '';
  Result.Profile := AProfile;
  Result.Source := ASource;
  Result.OverrideKind := eokNone;
  Result.Context := AContext;
  FillChar(Result.AuthorityBasis, SizeOf(Result.AuthorityBasis), 0);
  Result.Payload := APayload;
  Result.Timestamp := Now;
end;

class function TEhaiInteractionAction.CreateRegenerate(
  const AProfile: TEhaiInvolvementProfile;
  const AContext: TEhaiContextBinding; APayload: NativeInt;
  ASource: TEhaiSource): TEhaiInteractionAction;
begin
  Result.MetaAction := emaRegenerate;
  Result.Key := 8;
  SetLength(Result.SelectedKeys, 0);
  Result.Text := 'Regenerate';
  Result.Profile := AProfile;
  Result.Source := ASource;
  Result.OverrideKind := eokNone;
  Result.Context := AContext;
  FillChar(Result.AuthorityBasis, SizeOf(Result.AuthorityBasis), 0);
  Result.Payload := APayload;
  Result.Timestamp := Now;
end;

class function TEhaiInteractionAction.CreateRegenerate(
  const AContext: TEhaiContextBinding; APayload: NativeInt;
  ASource: TEhaiSource): TEhaiInteractionAction;
begin
  // Placeholder default eipInform - product callers must explicitly provide profile
  Result := CreateRegenerate(eipInform, AContext, APayload, ASource);
end;

class function TEhaiInteractionAction.CreateOverride(
  AOverrideKind: TEhaiOverrideKind; const AText: string;
  const AProfile: TEhaiInvolvementProfile;
  const AContext: TEhaiContextBinding; APayload: NativeInt;
  ASource: TEhaiSource): TEhaiInteractionAction;
begin
  Result.MetaAction := emaReframe;
  Result.Key := 9;
  SetLength(Result.SelectedKeys, 0);
  Result.Text := AText;
  Result.Profile := AProfile;
  Result.Source := ASource;
  Result.OverrideKind := AOverrideKind;
  Result.Context := AContext;
  FillChar(Result.AuthorityBasis, SizeOf(Result.AuthorityBasis), 0);
  Result.Payload := APayload;
  Result.Timestamp := Now;
end;

class function TEhaiInteractionAction.CreateOverride(
  AOverrideKind: TEhaiOverrideKind; const AText: string;
  const AContext: TEhaiContextBinding; APayload: NativeInt;
  ASource: TEhaiSource): TEhaiInteractionAction;
begin
  // Placeholder default eipProvide - product callers must explicitly provide profile
  Result := CreateOverride(AOverrideKind, AText, eipProvide, AContext, APayload, ASource);
end;

class function TEhaiInteractionAction.CreateExit(
  const AProfile: TEhaiInvolvementProfile;
  const AContext: TEhaiContextBinding; APayload: NativeInt;
  ASource: TEhaiSource): TEhaiInteractionAction;
begin
  Result.MetaAction := emaExit;
  Result.Key := 0;
  SetLength(Result.SelectedKeys, 0);
  Result.Text := 'Exit';
  Result.Profile := AProfile;
  Result.Source := ASource;
  Result.OverrideKind := eokNone;
  Result.Context := AContext;
  FillChar(Result.AuthorityBasis, SizeOf(Result.AuthorityBasis), 0);
  Result.Payload := APayload;
  Result.Timestamp := Now;
end;

class function TEhaiInteractionAction.CreateExit(
  const AContext: TEhaiContextBinding; APayload: NativeInt;
  ASource: TEhaiSource): TEhaiInteractionAction;
begin
  // Placeholder default eipInform - product callers must explicitly provide profile
  Result := CreateExit(eipInform, AContext, APayload, ASource);
end;

{ TEhaiTraceRecord }

class function TEhaiTraceRecord.Create(const ATraceId, AActor: string;
  const AAction: TEhaiInteractionAction; AEffect: TEhaiSemanticEffectKind;
  AIsCommitted: Boolean): TEhaiTraceRecord;
begin
  Result.TraceId := ATraceId;
  Result.Source := AAction.Source;
  Result.ActorIdentity := AActor;
  Result.Action := AAction;
  Result.SemanticEffect := AEffect;
  Result.IsCommitted := AIsCommitted;
  Result.RecordedAt := Now;
end;

{ Utility functions }

function EhaiKeyToMetaAction(AKey: Integer): TEhaiMetaAction;
begin
  case AKey of
    8: Result := emaRegenerate;
    9: Result := emaReframe;
    0: Result := emaExit;
  else
    Result := emaChoose;
  end;
end;

function EhaiMetaActionToKey(AAction: TEhaiMetaAction): Integer;
begin
  case AAction of
    emaRegenerate: Result := 8;
    emaReframe:    Result := 9;
    emaExit:       Result := 0;
  else
    Result := 1;
  end;
end;

function EhaiOverrideKindToStr(AKind: TEhaiOverrideKind): string;
begin
  case AKind of
    eokCandidateReject:         Result := 'CandidateReject';
    eokAlternativeExpression:   Result := 'AlternativeExpression';
    eokFrameRejection:           Result := 'FrameRejection';
  else
    Result := 'None';
  end;
end;

function EhaiProfileToStr(AProfile: TEhaiInvolvementProfile): string;
begin
  case AProfile of
    eipInform:    Result := 'Inform';
    eipProvide:   Result := 'Provide';
    eipJudge:     Result := 'Judge';
    eipAuthorize: Result := 'Authorize';
    eipAct:       Result := 'Act';
  end;
end;

function EhaiSourceToStr(ASource: TEhaiSource): string;
begin
  case ASource of
    esHuman:    Result := 'Human';
    esAI:       Result := 'AI';
    esInferred: Result := 'Inferred';
    esRule:     Result := 'Rule';
    esTool:     Result := 'Tool';
    esSystem:   Result := 'System';
  end;
end;

function EhaiCheckContextDrift(const AInitialBinding, ACurrentBinding: TEhaiContextBinding): Boolean;
begin
  // Anti-Drift Principle (PI-3): Returns True if context has materially changed (drift detected)
  Result := not AInitialBinding.IsEqual(ACurrentBinding);
end;

end.
