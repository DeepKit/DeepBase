// AI-GENERATED
// DeepBase.Governance.Accountability.pas
// P03：责任追踪层 — L2+ 无 Actor 时 Blocked，L3 等待审核时 Frozen

unit DeepBase.Governance.Accountability;

interface

uses
  System.SysUtils,
  System.JSON,
  System.Generics.Collections,
  DeepBase.Governance.Types,
  DeepBase.Governance.Actor;

type
  /// 审核状态
  THumanReviewStatus = (
    hrsNotRequired,   // 不需要审核
    hrsPending,       // 等待审核
    hrsApproved,      // 已批准
    hrsRejected,      // 已拒绝
    hrsExpired        // 已过期
  );

  /// 审核请求
  THumanReviewRequest = class
  private
    FId: string;
    FActionKey: string;
    FGateKey: string;
    FRequestorKey: string;
    FReviewerKey: string;
    FStatus: THumanReviewStatus;
    FReason: string;
    FCreatedAt: TDateTime;
    FResolvedAt: TDateTime;
  public
    constructor Create(const AActionKey, AGateKey, ARequestorKey: string;
      const AReason: string = '');
    procedure Approve(const AReviewerKey: string);
    procedure Reject(const AReviewerKey, AReason: string);

    property Id: string read FId;
    property ActionKey: string read FActionKey;
    property GateKey: string read FGateKey;
    property RequestorKey: string read FRequestorKey;
    property ReviewerKey: string read FReviewerKey;
    property Status: THumanReviewStatus read FStatus;
    property Reason: string read FReason;
    property CreatedAt: TDateTime read FCreatedAt;
    property ResolvedAt: TDateTime read FResolvedAt;
  end;

  /// 责任检查结果
  TAccountabilityCheckResult = record
    Passed: Boolean;
    Reason: string;
    RequiresReview: Boolean;
    ReviewId: string;
    class function Pass: TAccountabilityCheckResult; static;
    class function Blocked(const AReason: string): TAccountabilityCheckResult; static;
    class function Frozen(const AReviewId, AReason: string): TAccountabilityCheckResult; static;
  end;

  /// 责任检查器 — 判定 Action 是否有合格的 Actor
  TAccountabilityChecker = class
  private
    FActorRegistry: TActorRegistry;
    FPendingReviews: TObjectList<THumanReviewRequest>;
  public
    constructor Create(AActorRegistry: TActorRegistry);
    destructor Destroy; override;

    /// 检查责任：L2+ 必须有 Actor，L3 必须有审核
    function Check(const AActionKey, AGateKey: string;
      ARiskLevel: TRiskLevel; AContext: TJSONObject): TAccountabilityCheckResult;

    /// 提交审核请求（L3 场景）
    function RequestReview(const AActionKey, AGateKey, ARequestorKey: string;
      const AReason: string = ''): THumanReviewRequest;

    /// 查找待审核请求
    function FindPendingReview(const AActionKey: string): THumanReviewRequest;

    /// 获取所有待审核请求
    function GetPendingReviews: TArray<THumanReviewRequest>;

    /// 审核通过
    procedure ApproveReview(const AReviewId, AReviewerKey: string);

    /// 审核拒绝
    procedure RejectReview(const AReviewId, AReviewerKey, AReason: string);

    property ActorRegistry: TActorRegistry read FActorRegistry;
  end;

implementation

{ THumanReviewRequest }

constructor THumanReviewRequest.Create(const AActionKey, AGateKey,
  ARequestorKey, AReason: string);
begin
  inherited Create;
  FId := TGUID.NewGuid.ToString;
  FActionKey := AActionKey;
  FGateKey := AGateKey;
  FRequestorKey := ARequestorKey;
  FReason := AReason;
  FStatus := hrsPending;
  FCreatedAt := Now;
  FResolvedAt := 0;
end;

procedure THumanReviewRequest.Approve(const AReviewerKey: string);
begin
  FReviewerKey := AReviewerKey;
  FStatus := hrsApproved;
  FResolvedAt := Now;
end;

procedure THumanReviewRequest.Reject(const AReviewerKey, AReason: string);
begin
  FReviewerKey := AReviewerKey;
  FReason := AReason;
  FStatus := hrsRejected;
  FResolvedAt := Now;
end;

{ TAccountabilityCheckResult }

class function TAccountabilityCheckResult.Pass: TAccountabilityCheckResult;
begin
  Result.Passed := True;
  Result.Reason := '';
  Result.RequiresReview := False;
  Result.ReviewId := '';
end;

class function TAccountabilityCheckResult.Blocked(
  const AReason: string): TAccountabilityCheckResult;
begin
  Result.Passed := False;
  Result.Reason := AReason;
  Result.RequiresReview := False;
  Result.ReviewId := '';
end;

class function TAccountabilityCheckResult.Frozen(
  const AReviewId, AReason: string): TAccountabilityCheckResult;
begin
  Result.Passed := False;
  Result.Reason := AReason;
  Result.RequiresReview := True;
  Result.ReviewId := AReviewId;
end;

{ TAccountabilityChecker }

constructor TAccountabilityChecker.Create(AActorRegistry: TActorRegistry);
begin
  inherited Create;
  FActorRegistry := AActorRegistry;
  FPendingReviews := TObjectList<THumanReviewRequest>.Create(True);
end;

destructor TAccountabilityChecker.Destroy;
begin
  FPendingReviews.Free;
  inherited;
end;

function TAccountabilityChecker.Check(const AActionKey, AGateKey: string;
  ARiskLevel: TRiskLevel; AContext: TJSONObject): TAccountabilityCheckResult;
var
  LActor: TActor;
  LActorKey: string;
  LReview: THumanReviewRequest;
begin
  // L0/L1：不需要责任检查
  if ARiskLevel in [rlL0, rlL1] then
    Exit(TAccountabilityCheckResult.Pass);

  // L2+：必须有 Actor
  LActorKey := '';
  if AContext <> nil then
    LActorKey := AContext.GetValue<string>('user_id', '');

  if LActorKey = '' then
  begin
    LActor := FActorRegistry.GetCurrent;
    if LActor <> nil then
      LActorKey := LActor.Key;
  end;

  if LActorKey = '' then
    Exit(TAccountabilityCheckResult.Blocked(
      'L2+ action requires an identified actor (user_id missing)'));

  LActor := FActorRegistry.Find(LActorKey);
  if LActor = nil then
    Exit(TAccountabilityCheckResult.Blocked(
      'Actor not registered: ' + LActorKey));

  // L3：需要人工审核
  if ARiskLevel = rlL3 then
  begin
    LReview := FindPendingReview(AActionKey);
    if LReview = nil then
    begin
      // 自动创建审核请求
      LReview := RequestReview(AActionKey, AGateKey, LActorKey,
        'L3 action requires human review');
      Exit(TAccountabilityCheckResult.Frozen(LReview.Id,
        'L3 action frozen: awaiting human review'));
    end;

    case LReview.Status of
      hrsPending:
        Exit(TAccountabilityCheckResult.Frozen(LReview.Id,
          'Awaiting human review approval'));
      hrsApproved:
        Exit(TAccountabilityCheckResult.Pass);
      hrsRejected:
        Exit(TAccountabilityCheckResult.Blocked(
          'Human review rejected: ' + LReview.Reason));
      hrsExpired:
        Exit(TAccountabilityCheckResult.Blocked(
          'Human review expired, please re-submit'));
    end;
  end;

  // L2 有 Actor 即通过
  Result := TAccountabilityCheckResult.Pass;
end;

function TAccountabilityChecker.RequestReview(const AActionKey, AGateKey,
  ARequestorKey, AReason: string): THumanReviewRequest;
begin
  Result := THumanReviewRequest.Create(AActionKey, AGateKey,
    ARequestorKey, AReason);
  FPendingReviews.Add(Result);
end;

function TAccountabilityChecker.FindPendingReview(
  const AActionKey: string): THumanReviewRequest;
var
  LReview: THumanReviewRequest;
begin
  for LReview in FPendingReviews do
    if SameText(LReview.ActionKey, AActionKey) then
      Exit(LReview);
  Result := nil;
end;

function TAccountabilityChecker.GetPendingReviews: TArray<THumanReviewRequest>;
var
  LList: TList<THumanReviewRequest>;
  LReview: THumanReviewRequest;
begin
  LList := TList<THumanReviewRequest>.Create;
  try
    for LReview in FPendingReviews do
      if LReview.Status = hrsPending then
        LList.Add(LReview);
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

procedure TAccountabilityChecker.ApproveReview(const AReviewId,
  AReviewerKey: string);
var
  LReview: THumanReviewRequest;
begin
  for LReview in FPendingReviews do
    if LReview.Id = AReviewId then
    begin
      LReview.Approve(AReviewerKey);
      Exit;
    end;
end;

procedure TAccountabilityChecker.RejectReview(const AReviewId,
  AReviewerKey, AReason: string);
var
  LReview: THumanReviewRequest;
begin
  for LReview in FPendingReviews do
    if LReview.Id = AReviewId then
    begin
      LReview.Reject(AReviewerKey, AReason);
      Exit;
    end;
end;

end.
