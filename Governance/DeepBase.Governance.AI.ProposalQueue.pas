// AI-GENERATED
// DeepBase.Governance.AI.ProposalQueue.pas
// P15：AI-Proposal 队列 — AI 建议进入队列，人审批准转 ChangeSet

unit DeepBase.Governance.AI.ProposalQueue;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  DeepBase.Governance.ModelVersion;

type
  TProposalStatus = (psSubmitted, psUnderReview, psApproved, psRejected, psApplied);

  TProposal = class
  private
    FId: string;
    FProposerKey: string;
    FTargetObjectType: string;
    FTargetObjectKey: string;
    FProposedChange: string;
    FReason: string;
    FStatus: TProposalStatus;
    FReviewerKey: string;
    FReviewComment: string;
    FCreatedAt: TDateTime;
    FResolvedAt: TDateTime;
    FChangeSetVersion: Integer;
  public
    constructor Create(const AProposerKey, ATargetObjectType, ATargetObjectKey,
      AProposedChange, AReason: string);
    procedure Approve(const AReviewerKey, AComment: string);
    procedure Reject(const AReviewerKey, AComment: string);
    procedure MarkApplied(AChangeSetVersion: Integer);
    property Id: string read FId;
    property ProposerKey: string read FProposerKey;
    property TargetObjectType: string read FTargetObjectType;
    property TargetObjectKey: string read FTargetObjectKey;
    property ProposedChange: string read FProposedChange;
    property Reason: string read FReason;
    property Status: TProposalStatus read FStatus;
    property ReviewerKey: string read FReviewerKey;
    property ReviewComment: string read FReviewComment;
    property CreatedAt: TDateTime read FCreatedAt;
    property ResolvedAt: TDateTime read FResolvedAt;
    property ChangeSetVersion: Integer read FChangeSetVersion;
  end;

  TProposalQueue = class
  private
    FProposals: TObjectList<TProposal>;
    FModelVersion: TModelVersion;
  public
    constructor Create(AModelVersion: TModelVersion);
    destructor Destroy; override;

    /// AI 提交建议
    function Submit(const AProposerKey, ATargetObjectType, ATargetObjectKey,
      AProposedChange, AReason: string): TProposal;

    /// 人审批准
    procedure Approve(const AProposalId, AReviewerKey, AComment: string);

    /// 人审拒绝
    procedure Reject(const AProposalId, AReviewerKey, AComment: string);

    /// 应用已批准的建议到 ModelVersion
    function Apply(const AProposalId: string): Boolean;

    /// 查询
    function FindById(const AId: string): TProposal;
    function GetPending: TArray<TProposal>;
    function GetAll: TArray<TProposal>;
    function Count: Integer;
  end;

implementation

{ TProposal }

constructor TProposal.Create(const AProposerKey, ATargetObjectType,
  ATargetObjectKey, AProposedChange, AReason: string);
begin
  inherited Create;
  FId := TGUID.NewGuid.ToString;
  FProposerKey := AProposerKey;
  FTargetObjectType := ATargetObjectType;
  FTargetObjectKey := ATargetObjectKey;
  FProposedChange := AProposedChange;
  FReason := AReason;
  FStatus := psSubmitted;
  FCreatedAt := Now;
  FResolvedAt := 0;
  FChangeSetVersion := 0;
end;

procedure TProposal.Approve(const AReviewerKey, AComment: string);
begin
  FReviewerKey := AReviewerKey;
  FReviewComment := AComment;
  FStatus := psApproved;
  FResolvedAt := Now;
end;

procedure TProposal.Reject(const AReviewerKey, AComment: string);
begin
  FReviewerKey := AReviewerKey;
  FReviewComment := AComment;
  FStatus := psRejected;
  FResolvedAt := Now;
end;

procedure TProposal.MarkApplied(AChangeSetVersion: Integer);
begin
  FStatus := psApplied;
  FChangeSetVersion := AChangeSetVersion;
end;

{ TProposalQueue }

constructor TProposalQueue.Create(AModelVersion: TModelVersion);
begin
  inherited Create;
  FProposals := TObjectList<TProposal>.Create(True);
  FModelVersion := AModelVersion;
end;

destructor TProposalQueue.Destroy;
begin
  FProposals.Free;
  inherited;
end;

function TProposalQueue.Submit(const AProposerKey, ATargetObjectType,
  ATargetObjectKey, AProposedChange, AReason: string): TProposal;
begin
  Result := TProposal.Create(AProposerKey, ATargetObjectType,
    ATargetObjectKey, AProposedChange, AReason);
  FProposals.Add(Result);
end;

procedure TProposalQueue.Approve(const AProposalId, AReviewerKey, AComment: string);
var
  LP: TProposal;
begin
  LP := FindById(AProposalId);
  if LP <> nil then
    LP.Approve(AReviewerKey, AComment);
end;

procedure TProposalQueue.Reject(const AProposalId, AReviewerKey, AComment: string);
var
  LP: TProposal;
begin
  LP := FindById(AProposalId);
  if LP <> nil then
    LP.Reject(AReviewerKey, AComment);
end;

function TProposalQueue.Apply(const AProposalId: string): Boolean;
var
  LP: TProposal;
  LCS: TChangeSet;
begin
  LP := FindById(AProposalId);
  if (LP = nil) or (LP.Status <> psApproved) then
    Exit(False);

  LCS := FModelVersion.CreateChangeSet(
    'AI Proposal: ' + LP.Reason, LP.ProposerKey);
  LCS.AddEntry(ckModify, LP.TargetObjectType, LP.TargetObjectKey,
    '', LP.ProposedChange);
  LP.MarkApplied(LCS.Version);
  Result := True;
end;

function TProposalQueue.FindById(const AId: string): TProposal;
var
  LP: TProposal;
begin
  for LP in FProposals do
    if LP.Id = AId then
      Exit(LP);
  Result := nil;
end;

function TProposalQueue.GetPending: TArray<TProposal>;
var
  LList: TList<TProposal>;
  LP: TProposal;
begin
  LList := TList<TProposal>.Create;
  try
    for LP in FProposals do
      if LP.Status = psSubmitted then
        LList.Add(LP);
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TProposalQueue.GetAll: TArray<TProposal>;
begin
  Result := FProposals.ToArray;
end;

function TProposalQueue.Count: Integer;
begin
  Result := FProposals.Count;
end;

end.
