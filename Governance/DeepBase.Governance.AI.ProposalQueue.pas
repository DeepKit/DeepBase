// AI-GENERATED
// DeepBase.Governance.AI.ProposalQueue.pas
// P15：AI-Proposal 队列 — AI 建议进入队列，人审批准转 ChangeSet

unit DeepBase.Governance.AI.ProposalQueue;

interface

uses
  System.SysUtils,
  System.SyncObjs,
  System.Generics.Collections,
  DeepBase.Governance.ModelVersion;

type
  EProposalQueueError = class(Exception);

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
    FLock: TCriticalSection;
    FMaxPending: Integer;
    function PendingCountInternal: Integer;
    function FindByIdInternal(const AId: string): TProposal;
  public
    constructor Create(AModelVersion: TModelVersion; AMaxPending: Integer = 0);
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

constructor TProposalQueue.Create(AModelVersion: TModelVersion; AMaxPending: Integer = 0);
begin
  inherited Create;
  FProposals := TObjectList<TProposal>.Create(True);
  FModelVersion := AModelVersion;
  FLock := TCriticalSection.Create;
  // AMaxPending <= 0 表示采用默认上限 (1000), 防止 AI 循环提交无限堆积 TProposal
  // 致 OOM (REVIEW5-R3-D-008 / BUG-430). 调用方可显式传更大值放宽, 但不应传 0 关闭.
  if AMaxPending <= 0 then
    FMaxPending := 1000
  else
    FMaxPending := AMaxPending;
end;

destructor TProposalQueue.Destroy;
begin
  FLock.Free;
  FProposals.Free;
  inherited;
end;

// 在已持 FLock 的情况下统计待审 (psSubmitted) 数量, 供 Submit 容量检查复用.
function TProposalQueue.PendingCountInternal: Integer;
var
  LP: TProposal;
begin
  Result := 0;
  for LP in FProposals do
    if LP.Status = psSubmitted then
      Inc(Result);
end;

function TProposalQueue.Submit(const AProposerKey, ATargetObjectType,
  ATargetObjectKey, AProposedChange, AReason: string): TProposal;
begin
  // 容量检查 + 入队必须在同一锁内完成, 否则 TOCTOU (检查后另一线程抢先入队突破上限).
  FLock.Enter;
  try
    if (FMaxPending > 0) and (PendingCountInternal >= FMaxPending) then
      raise EProposalQueueError.CreateFmt(
        '提案队列已满: 待审提案数 %d 已达上限 %d, 请先审核或拒绝部分提案后再提交',
        [PendingCountInternal, FMaxPending]);
    Result := TProposal.Create(AProposerKey, ATargetObjectType,
      ATargetObjectKey, AProposedChange, AReason);
    FProposals.Add(Result);
  finally
    FLock.Leave;
  end;
end;

procedure TProposalQueue.Approve(const AProposalId, AReviewerKey, AComment: string);
var
  LP: TProposal;
begin
  // FindByIdInternal 在已持锁内遍历, 避免 TCriticalSection 不可重入导致的自死锁.
  FLock.Enter;
  try
    LP := FindByIdInternal(AProposalId);
    if LP <> nil then
      LP.Approve(AReviewerKey, AComment);
  finally
    FLock.Leave;
  end;
end;

procedure TProposalQueue.Reject(const AProposalId, AReviewerKey, AComment: string);
var
  LP: TProposal;
begin
  FLock.Enter;
  try
    LP := FindByIdInternal(AProposalId);
    if LP <> nil then
      LP.Reject(AReviewerKey, AComment);
  finally
    FLock.Leave;
  end;
end;

function TProposalQueue.Apply(const AProposalId: string): Boolean;
var
  LP: TProposal;
  LCS: TChangeSet;
begin
  FLock.Enter;
  try
    LP := FindByIdInternal(AProposalId);
    if (LP = nil) or (LP.Status <> psApproved) then
      Exit(False);

    LCS := FModelVersion.CreateChangeSet(
      'AI Proposal: ' + LP.Reason, LP.ProposerKey);
    LCS.AddEntry(ckModify, LP.TargetObjectType, LP.TargetObjectKey,
      '', LP.ProposedChange);
    LP.MarkApplied(LCS.Version);
    Result := True;
  finally
    FLock.Leave;
  end;
end;

// 在已持 FLock 的情况下线性查找. 调用方负责加锁.
function TProposalQueue.FindByIdInternal(const AId: string): TProposal;
var
  LP: TProposal;
begin
  for LP in FProposals do
    if LP.Id = AId then
      Exit(LP);
  Result := nil;
end;

function TProposalQueue.FindById(const AId: string): TProposal;
begin
  FLock.Enter;
  try
    Result := FindByIdInternal(AId);
  finally
    FLock.Leave;
  end;
end;

function TProposalQueue.GetPending: TArray<TProposal>;
var
  LList: TList<TProposal>;
  LP: TProposal;
begin
  LList := TList<TProposal>.Create;
  try
    FLock.Enter;
    try
      for LP in FProposals do
        if LP.Status = psSubmitted then
          LList.Add(LP);
      Result := LList.ToArray;
    finally
      FLock.Leave;
    end;
  finally
    LList.Free;
  end;
end;

function TProposalQueue.GetAll: TArray<TProposal>;
begin
  FLock.Enter;
  try
    Result := FProposals.ToArray;
  finally
    FLock.Leave;
  end;
end;

function TProposalQueue.Count: Integer;
begin
  FLock.Enter;
  try
    Result := FProposals.Count;
  finally
    FLock.Leave;
  end;
end;

end.
