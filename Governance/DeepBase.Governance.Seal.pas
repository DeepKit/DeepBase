// AI-GENERATED
// DeepBase.Governance.Seal.pas
// P10：封存补救层 — SealRecord / RemediationRecord / Waiver

unit DeepBase.Governance.Seal;

interface

uses
  System.SysUtils,
  System.Hash,
  System.Generics.Collections;

type
  TSealStatus = (ssOpen, ssSealed, ssArchived, ssExpired);
  TRemediationType = (rtRollback, rtCompensate, rtRecall, rtFreeze, rtUnseal);

  /// 封存记录
  TSealRecord = class
  private
    FId: string;
    FSubjectType: string;
    FSubjectId: string;
    FSealedAt: TDateTime;
    FSealedBy: string;
    FIntegrityHash: string;
    FStatus: TSealStatus;
  public
    constructor Create(const ASubjectType, ASubjectId, ASealedBy: string;
      const APayload: string);
    function Verify(const APayload: string): Boolean;
    property Id: string read FId;
    property SubjectType: string read FSubjectType;
    property SubjectId: string read FSubjectId;
    property SealedAt: TDateTime read FSealedAt;
    property SealedBy: string read FSealedBy;
    property IntegrityHash: string read FIntegrityHash;
    property Status: TSealStatus read FStatus;
  end;

  /// 补救记录
  TRemediationRecord = class
  private
    FId: string;
    FIncidentRef: string;
    FRemediationType: TRemediationType;
    FTargetRef: string;
    FExecutedAt: TDateTime;
    FExecutedBy: string;
    FEvidenceRef: string;
  public
    constructor Create(const AIncidentRef: string; AType: TRemediationType;
      const ATargetRef, AExecutedBy: string);
    property Id: string read FId;
    property IncidentRef: string read FIncidentRef;
    property RemediationType: TRemediationType read FRemediationType;
    property TargetRef: string read FTargetRef;
    property ExecutedAt: TDateTime read FExecutedAt;
    property ExecutedBy: string read FExecutedBy;
    property EvidenceRef: string read FEvidenceRef write FEvidenceRef;
  end;

  /// 豁免记录
  TWaiver = class
  private
    FId: string;
    FRuleRef: string;
    FScope: string;
    FReason: string;
    FApprovedBy: string;
    FExpiresAt: TDateTime;
    FCreatedAt: TDateTime;
  public
    constructor Create(const ARuleRef, AScope, AReason, AApprovedBy: string;
      AExpiresAt: TDateTime);
    function IsExpired: Boolean;
    property Id: string read FId;
    property RuleRef: string read FRuleRef;
    property Scope: string read FScope;
    property Reason: string read FReason;
    property ApprovedBy: string read FApprovedBy;
    property ExpiresAt: TDateTime read FExpiresAt;
  end;

  /// 封存注册表
  TSealRegistry = class
  private
    FSeals: TObjectList<TSealRecord>;
    FRemediations: TObjectList<TRemediationRecord>;
    FWaivers: TObjectList<TWaiver>;
  public
    constructor Create;
    destructor Destroy; override;
    function Seal(const ASubjectType, ASubjectId, ASealedBy, APayload: string): TSealRecord;
    function FindSeal(const ASubjectId: string): TSealRecord;
    function IsSealed(const ASubjectId: string): Boolean;
    function AddRemediation(const AIncidentRef: string; AType: TRemediationType;
      const ATargetRef, AExecutedBy: string): TRemediationRecord;
    function AddWaiver(const ARuleRef, AScope, AReason, AApprovedBy: string;
      AExpiresAt: TDateTime): TWaiver;
    function HasActiveWaiver(const ARuleRef: string): Boolean;
  end;

implementation

{ TSealRecord }

constructor TSealRecord.Create(const ASubjectType, ASubjectId, ASealedBy,
  APayload: string);
begin
  inherited Create;
  FId := TGUID.NewGuid.ToString;
  FSubjectType := ASubjectType;
  FSubjectId := ASubjectId;
  FSealedBy := ASealedBy;
  FSealedAt := Now;
  FIntegrityHash := THashSHA2.GetHashString(APayload);
  FStatus := ssSealed;
end;

function TSealRecord.Verify(const APayload: string): Boolean;
begin
  Result := THashSHA2.GetHashString(APayload) = FIntegrityHash;
end;

{ TRemediationRecord }

constructor TRemediationRecord.Create(const AIncidentRef: string;
  AType: TRemediationType; const ATargetRef, AExecutedBy: string);
begin
  inherited Create;
  FId := TGUID.NewGuid.ToString;
  FIncidentRef := AIncidentRef;
  FRemediationType := AType;
  FTargetRef := ATargetRef;
  FExecutedBy := AExecutedBy;
  FExecutedAt := Now;
  FEvidenceRef := '';
end;

{ TWaiver }

constructor TWaiver.Create(const ARuleRef, AScope, AReason, AApprovedBy: string;
  AExpiresAt: TDateTime);
begin
  inherited Create;
  FId := TGUID.NewGuid.ToString;
  FRuleRef := ARuleRef;
  FScope := AScope;
  FReason := AReason;
  FApprovedBy := AApprovedBy;
  FExpiresAt := AExpiresAt;
  FCreatedAt := Now;
end;

function TWaiver.IsExpired: Boolean;
begin
  Result := (FExpiresAt > 0) and (Now > FExpiresAt);
end;

{ TSealRegistry }

constructor TSealRegistry.Create;
begin
  inherited Create;
  FSeals := TObjectList<TSealRecord>.Create(True);
  FRemediations := TObjectList<TRemediationRecord>.Create(True);
  FWaivers := TObjectList<TWaiver>.Create(True);
end;

destructor TSealRegistry.Destroy;
begin
  FWaivers.Free;
  FRemediations.Free;
  FSeals.Free;
  inherited;
end;

function TSealRegistry.Seal(const ASubjectType, ASubjectId, ASealedBy,
  APayload: string): TSealRecord;
begin
  Result := TSealRecord.Create(ASubjectType, ASubjectId, ASealedBy, APayload);
  FSeals.Add(Result);
end;

function TSealRegistry.FindSeal(const ASubjectId: string): TSealRecord;
var
  S: TSealRecord;
begin
  for S in FSeals do
    if S.SubjectId = ASubjectId then
      Exit(S);
  Result := nil;
end;

function TSealRegistry.IsSealed(const ASubjectId: string): Boolean;
var
  S: TSealRecord;
begin
  S := FindSeal(ASubjectId);
  Result := (S <> nil) and (S.Status = ssSealed);
end;

function TSealRegistry.AddRemediation(const AIncidentRef: string;
  AType: TRemediationType; const ATargetRef, AExecutedBy: string): TRemediationRecord;
begin
  Result := TRemediationRecord.Create(AIncidentRef, AType, ATargetRef, AExecutedBy);
  FRemediations.Add(Result);
end;

function TSealRegistry.AddWaiver(const ARuleRef, AScope, AReason,
  AApprovedBy: string; AExpiresAt: TDateTime): TWaiver;
begin
  Result := TWaiver.Create(ARuleRef, AScope, AReason, AApprovedBy, AExpiresAt);
  FWaivers.Add(Result);
end;

function TSealRegistry.HasActiveWaiver(const ARuleRef: string): Boolean;
var
  W: TWaiver;
begin
  for W in FWaivers do
    if (W.RuleRef = ARuleRef) and not W.IsExpired then
      Exit(True);
  Result := False;
end;

end.
