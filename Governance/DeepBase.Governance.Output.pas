// AI-GENERATED
// DeepBase.Governance.Output.pas
// P05：产出物层 — OutputDef / OutputInstance / OutputAcceptance

unit DeepBase.Governance.Output;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  DeepBase.Governance.Types;

type
  /// 产出物本质
  TOutputNature = (
    onArtifact,        // 可持久化实体（文件、记录、报告）
    onStateChange,     // 状态变更
    onCommunication,   // 对外通信（邮件、通知）
    onProcess,         // 过程完成
    onDisposition      // 处置（删除、撤销、封存）
  );

  /// 产出物角色
  TOutputRole = (
    orPrimary,         // 主目标
    orFinal,           // 最终验收物
    orIntermediate,    // 中间材料
    orSnapshot,        // 快照
    orEvidence         // 证据
  );

  /// 可逆性
  TReversibility = (
    rvReversible,      // 可逆
    rvCompensable,     // 可补偿
    rvIrreversible     // 不可逆
  );

  /// 产出物定义
  TOutputDef = class
  private
    FKey: string;
    FName: string;
    FNature: TOutputNature;
    FRole: TOutputRole;
    FRiskLevel: TRiskLevel;
    FReversibility: TReversibility;
    FAcceptanceCriteria: string;
    FTargetObject: string;
    FFinalState: string;
  public
    constructor Create(const AKey, AName: string; ANature: TOutputNature;
      ARole: TOutputRole; ARiskLevel: TRiskLevel;
      AReversibility: TReversibility;
      const AAcceptanceCriteria: string = '');
    property Key: string read FKey;
    property Name: string read FName;
    property Nature: TOutputNature read FNature;
    property Role: TOutputRole read FRole;
    property RiskLevel: TRiskLevel read FRiskLevel;
    property Reversibility: TReversibility read FReversibility;
    property AcceptanceCriteria: string read FAcceptanceCriteria;
    property TargetObject: string read FTargetObject write FTargetObject;
    property FinalState: string read FFinalState write FFinalState;
  end;

  /// 产出物实例状态
  TOutputInstanceState = (
    oisPending,      // 待生成
    oisProduced,     // 已生成
    oisAccepted,     // 已验收
    oisRejected,     // 验收失败
    oisSealed        // 已封存
  );

  /// 产出物实例
  TOutputInstance = class
  private
    FId: string;
    FOutputKey: string;
    FActionRunId: string;
    FState: TOutputInstanceState;
    FAcceptedAt: TDateTime;
    FEvidenceBundleId: string;
    FSnapshotData: string;
  public
    constructor Create(const AOutputKey, AActionRunId: string);
    procedure Accept;
    procedure Reject;
    procedure Seal(const AEvidenceBundleId: string);
    property Id: string read FId;
    property OutputKey: string read FOutputKey;
    property ActionRunId: string read FActionRunId;
    property State: TOutputInstanceState read FState;
    property AcceptedAt: TDateTime read FAcceptedAt;
    property EvidenceBundleId: string read FEvidenceBundleId;
    property SnapshotData: string read FSnapshotData write FSnapshotData;
  end;

  /// 产出物注册表
  TOutputRegistry = class
  private
    FDefs: TObjectDictionary<string, TOutputDef>;
    FInstances: TObjectList<TOutputInstance>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure RegisterDef(ADef: TOutputDef);
    function FindDef(const AKey: string): TOutputDef;
    function CreateInstance(const AOutputKey, AActionRunId: string): TOutputInstance;
    function FindInstancesByAction(const AActionRunId: string): TArray<TOutputInstance>;
    function Count: Integer;
  end;

implementation

{ TOutputDef }

constructor TOutputDef.Create(const AKey, AName: string; ANature: TOutputNature;
  ARole: TOutputRole; ARiskLevel: TRiskLevel; AReversibility: TReversibility;
  const AAcceptanceCriteria: string);
begin
  inherited Create;
  FKey := AKey;
  FName := AName;
  FNature := ANature;
  FRole := ARole;
  FRiskLevel := ARiskLevel;
  FReversibility := AReversibility;
  FAcceptanceCriteria := AAcceptanceCriteria;
  FTargetObject := '';
  FFinalState := '';
end;

{ TOutputInstance }

constructor TOutputInstance.Create(const AOutputKey, AActionRunId: string);
begin
  inherited Create;
  FId := TGUID.NewGuid.ToString;
  FOutputKey := AOutputKey;
  FActionRunId := AActionRunId;
  FState := oisPending;
  FAcceptedAt := 0;
  FEvidenceBundleId := '';
  FSnapshotData := '';
end;

procedure TOutputInstance.Accept;
begin
  FState := oisAccepted;
  FAcceptedAt := Now;
end;

procedure TOutputInstance.Reject;
begin
  FState := oisRejected;
end;

procedure TOutputInstance.Seal(const AEvidenceBundleId: string);
begin
  FState := oisSealed;
  FEvidenceBundleId := AEvidenceBundleId;
end;

{ TOutputRegistry }

constructor TOutputRegistry.Create;
begin
  inherited Create;
  FDefs := TObjectDictionary<string, TOutputDef>.Create([doOwnsValues]);
  FInstances := TObjectList<TOutputInstance>.Create(True);
end;

destructor TOutputRegistry.Destroy;
begin
  FInstances.Free;
  FDefs.Free;
  inherited;
end;

procedure TOutputRegistry.RegisterDef(ADef: TOutputDef);
begin
  FDefs.AddOrSetValue(ADef.Key, ADef);
end;

function TOutputRegistry.FindDef(const AKey: string): TOutputDef;
begin
  if not FDefs.TryGetValue(AKey, Result) then
    Result := nil;
end;

function TOutputRegistry.CreateInstance(const AOutputKey,
  AActionRunId: string): TOutputInstance;
begin
  Result := TOutputInstance.Create(AOutputKey, AActionRunId);
  FInstances.Add(Result);
end;

function TOutputRegistry.FindInstancesByAction(
  const AActionRunId: string): TArray<TOutputInstance>;
var
  LList: TList<TOutputInstance>;
  LInst: TOutputInstance;
begin
  LList := TList<TOutputInstance>.Create;
  try
    for LInst in FInstances do
      if LInst.ActionRunId = AActionRunId then
        LList.Add(LInst);
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TOutputRegistry.Count: Integer;
begin
  Result := FDefs.Count;
end;

end.
