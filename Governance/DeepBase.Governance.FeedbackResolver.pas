// AI-GENERATED
// DeepBase.Governance.FeedbackResolver.pas
// 第四层：阻挡反馈解析
// 依赖 Interfaces + Types

unit DeepBase.Governance.FeedbackResolver;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  DeepBase.Governance.Types,
  DeepBase.Governance.Interfaces;

type
  /// 反馈模板
  TFeedbackTemplate = record
    GateKey: string;
    State: TGateState;
    Title: string;
    MessageTemplate: string;
    NextStepHint: string;
  end;

  /// 反馈解析器实现
  TFeedbackResolver = class(TInterfacedObject, IFeedbackResolver)
  private
    FTemplates: TList<TFeedbackTemplate>;
    FDefaultFeedbacks: TDictionary<TGateState, TFeedbackTemplate>;
    procedure InitDefaults;
    function FindTemplate(const AGateKey: string;
      AState: TGateState): TFeedbackTemplate;
  public
    constructor Create;
    destructor Destroy; override;

    // 模板管理
    procedure RegisterFeedback(const AGateKey: string; AState: TGateState;
      const ATitle, AMessage, ANextStep: string);

    // IFeedbackResolver
    function GetFeedback(const AGateKey: string;
      AState: TGateState): TFeedbackInfo;
  end;

implementation

{ TFeedbackResolver }

constructor TFeedbackResolver.Create;
begin
  inherited Create;
  FTemplates := TList<TFeedbackTemplate>.Create;
  FDefaultFeedbacks := TDictionary<TGateState, TFeedbackTemplate>.Create;
  InitDefaults;
end;

destructor TFeedbackResolver.Destroy;
begin
  FDefaultFeedbacks.Free;
  FTemplates.Free;
  inherited;
end;

procedure TFeedbackResolver.InitDefaults;
var
  LTemplate: TFeedbackTemplate;
begin
  // Disabled 默认反馈
  LTemplate.GateKey := '';
  LTemplate.State := gsDisabled;
  LTemplate.Title := 'Permission Denied';
  LTemplate.MessageTemplate := 'You do not have permission to perform this action.';
  LTemplate.NextStepHint := 'Contact your administrator for access.';
  FDefaultFeedbacks.Add(gsDisabled, LTemplate);

  // Blocked 默认反馈
  LTemplate.State := gsBlocked;
  LTemplate.Title := 'Action Blocked';
  LTemplate.MessageTemplate := 'This action is currently blocked.';
  LTemplate.NextStepHint := 'Please check the prerequisites.';
  FDefaultFeedbacks.Add(gsBlocked, LTemplate);

  // Locked 默认反馈
  LTemplate.State := gsLocked;
  LTemplate.Title := 'Sealed';
  LTemplate.MessageTemplate := 'This item has been sealed and cannot be modified.';
  LTemplate.NextStepHint := 'Contact an authorized reviewer to unseal.';
  FDefaultFeedbacks.Add(gsLocked, LTemplate);

  // Frozen 默认反馈
  LTemplate.State := gsFrozen;
  LTemplate.Title := 'Frozen';
  LTemplate.MessageTemplate := 'This action is frozen pending review.';
  LTemplate.NextStepHint := 'Wait for the review process to complete.';
  FDefaultFeedbacks.Add(gsFrozen, LTemplate);

  // Conflict 默认反馈
  LTemplate.State := gsConflict;
  LTemplate.Title := 'Conflict Detected';
  LTemplate.MessageTemplate := 'Multiple conditions are in conflict.';
  LTemplate.NextStepHint := 'Resolve the conflicting conditions first.';
  FDefaultFeedbacks.Add(gsConflict, LTemplate);

  // Closed 默认反馈
  LTemplate.State := gsClosed;
  LTemplate.Title := 'Not Available';
  LTemplate.MessageTemplate := 'This action is not available in the current state.';
  LTemplate.NextStepHint := 'Check the required conditions.';
  FDefaultFeedbacks.Add(gsClosed, LTemplate);
end;

procedure TFeedbackResolver.RegisterFeedback(const AGateKey: string;
  AState: TGateState; const ATitle, AMessage, ANextStep: string);
var
  LTemplate: TFeedbackTemplate;
begin
  LTemplate.GateKey := AGateKey;
  LTemplate.State := AState;
  LTemplate.Title := ATitle;
  LTemplate.MessageTemplate := AMessage;
  LTemplate.NextStepHint := ANextStep;
  FTemplates.Add(LTemplate);
end;

function TFeedbackResolver.FindTemplate(const AGateKey: string;
  AState: TGateState): TFeedbackTemplate;
var
  LTemplate: TFeedbackTemplate;
begin
  // 先查找特定 Gate 的模板
  for LTemplate in FTemplates do
  begin
    if (LTemplate.GateKey = AGateKey) and (LTemplate.State = AState) then
      Exit(LTemplate);
  end;

  // 回退到默认模板
  if FDefaultFeedbacks.TryGetValue(AState, Result) then
    Exit;

  // 最终兜底
  Result.GateKey := AGateKey;
  Result.State := AState;
  Result.Title := 'Unavailable';
  Result.MessageTemplate := 'This action is not available.';
  Result.NextStepHint := '';
end;

function TFeedbackResolver.GetFeedback(const AGateKey: string;
  AState: TGateState): TFeedbackInfo;
var
  LTemplate: TFeedbackTemplate;
begin
  LTemplate := FindTemplate(AGateKey, AState);

  Result.GateKey := AGateKey;
  Result.State := AState;
  Result.Title := LTemplate.Title;
  Result.Message := LTemplate.MessageTemplate;
  Result.NextStepHint := LTemplate.NextStepHint;
end;

end.
