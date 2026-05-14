// AI-GENERATED
// DeepBase.Governance.Model.pas
// 第三层：数据模型（依赖 Types）
// Action / Ability / AccessGate / ContextField / RouteRule 数据类

unit DeepBase.Governance.Model;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  DeepBase.Governance.Types;

type
  /// 门禁条件 (GateCondition)
  TGateCondition = class
  private
    FKind: TGateConditionKind;
    FExpression: string;       // JsonLogic 表达式
    FDescription: string;
    FBlockedMessage: string;
  public
    constructor Create(AKind: TGateConditionKind; const AExpression: string;
      const ADescription: string = ''; const ABlockedMessage: string = '');
    property Kind: TGateConditionKind read FKind;
    property Expression: string read FExpression;
    property Description: string read FDescription;
    property BlockedMessage: string read FBlockedMessage;
  end;

  /// 门禁 (AccessGate) — 门 + 禁
  TAccessGate = class
  private
    FKey: string;
    FDisplayName: string;
    FGateType: TGateType;
    FParentKey: string;
    FConditions: TObjectList<TGateCondition>;
    FActionKeys: TList<string>;
    FFieldKey: string;
  public
    constructor Create(const AKey, ADisplayName: string; AGateType: TGateType;
      const AParentKey: string = ''; const AFieldKey: string = '');
    destructor Destroy; override;
    procedure AddCondition(ACondition: TGateCondition);
    procedure AddActionKey(const AActionKey: string);
    property Key: string read FKey;
    property DisplayName: string read FDisplayName;
    property GateType: TGateType read FGateType;
    property ParentKey: string read FParentKey;
    property Conditions: TObjectList<TGateCondition> read FConditions;
    property ActionKeys: TList<string> read FActionKeys;
    property FieldKey: string read FFieldKey;
  end;

  /// 行为 (Action)
  TAction = class
  private
    FKey: string;
    FDisplayName: string;
    FRiskLevel: TRiskLevel;
    FEnabled: Boolean;
    FGateKey: string;
    FBridgeKeys: TList<string>;
    FDueRef: string;           // 合当引用（L2+ 必须有）
    FPurposeKey: string;       // 理论层目的关联
    FDisabledReason: string;
  public
    constructor Create(const AKey, ADisplayName: string; ARiskLevel: TRiskLevel;
      const AGateKey: string = ''; const ADueRef: string = '';
      const APurposeKey: string = '');
    destructor Destroy; override;
    procedure AddBridgeKey(const ABridgeKey: string);
    property Key: string read FKey;
    property DisplayName: string read FDisplayName;
    property RiskLevel: TRiskLevel read FRiskLevel;
    property Enabled: Boolean read FEnabled write FEnabled;
    property GateKey: string read FGateKey;
    property BridgeKeys: TList<string> read FBridgeKeys;
    property DueRef: string read FDueRef write FDueRef;
    property PurposeKey: string read FPurposeKey;
    property DisabledReason: string read FDisabledReason write FDisabledReason;
  end;

  /// 能力 (Ability)
  TAbility = class
  private
    FKey: string;
    FDisplayName: string;
    FDescription: string;
  public
    constructor Create(const AKey, ADisplayName: string;
      const ADescription: string = '');
    property Key: string read FKey;
    property DisplayName: string read FDisplayName;
    property Description: string read FDescription;
  end;

  /// 上下文场域 (ContextField)
  TContextField = class
  private
    FKey: string;
    FDisplayName: string;
    FDescription: string;
    FGateKeys: TList<string>;
    FActionKeys: TList<string>;
  public
    constructor Create(const AKey, ADisplayName: string;
      const ADescription: string = '');
    destructor Destroy; override;
    procedure AddGateKey(const AGateKey: string);
    procedure AddActionKey(const AActionKey: string);
    property Key: string read FKey;
    property DisplayName: string read FDisplayName;
    property Description: string read FDescription;
    property GateKeys: TList<string> read FGateKeys;
    property ActionKeys: TList<string> read FActionKeys;
  end;

  /// 路由规则 (RouteRule)
  TRouteRule = class
  private
    FId: string;
    FSourceGateKey: string;
    FConditionExpr: string;    // JsonLogic 表达式
    FTargetType: TRouteTargetType;
    FTargetKey: string;
    FPriority: Integer;
    FFallbackTarget: string;
    FVersion: Integer;
    FEffectiveFrom: TDateTime;
    FExpiredAt: TDateTime;
    FRiskLevel: TRiskLevel;
    FEnabled: Boolean;
    FCreatedBy: string;
    FApprovedBy: string;
    FTags: string;
    FDescription: string;
  public
    constructor Create(const AId, ASourceGateKey, AConditionExpr: string;
      ATargetType: TRouteTargetType; const ATargetKey: string;
      APriority: Integer = 0);
    property Id: string read FId;
    property SourceGateKey: string read FSourceGateKey;
    property ConditionExpr: string read FConditionExpr;
    property TargetType: TRouteTargetType read FTargetType;
    property TargetKey: string read FTargetKey;
    property Priority: Integer read FPriority write FPriority;
    property FallbackTarget: string read FFallbackTarget write FFallbackTarget;
    property Version: Integer read FVersion write FVersion;
    property EffectiveFrom: TDateTime read FEffectiveFrom write FEffectiveFrom;
    property ExpiredAt: TDateTime read FExpiredAt write FExpiredAt;
    property RiskLevel: TRiskLevel read FRiskLevel write FRiskLevel;
    property Enabled: Boolean read FEnabled write FEnabled;
    property CreatedBy: string read FCreatedBy write FCreatedBy;
    property ApprovedBy: string read FApprovedBy write FApprovedBy;
    property Tags: string read FTags write FTags;
    property Description: string read FDescription write FDescription;
  end;

implementation

{ TGateCondition }

constructor TGateCondition.Create(AKind: TGateConditionKind;
  const AExpression, ADescription, ABlockedMessage: string);
begin
  inherited Create;
  FKind := AKind;
  FExpression := AExpression;
  FDescription := ADescription;
  FBlockedMessage := ABlockedMessage;
end;

{ TAccessGate }

constructor TAccessGate.Create(const AKey, ADisplayName: string;
  AGateType: TGateType; const AParentKey, AFieldKey: string);
begin
  inherited Create;
  FKey := AKey;
  FDisplayName := ADisplayName;
  FGateType := AGateType;
  FParentKey := AParentKey;
  FFieldKey := AFieldKey;
  FConditions := TObjectList<TGateCondition>.Create(True);
  FActionKeys := TList<string>.Create;
end;

destructor TAccessGate.Destroy;
begin
  FConditions.Free;
  FActionKeys.Free;
  inherited;
end;

procedure TAccessGate.AddCondition(ACondition: TGateCondition);
begin
  FConditions.Add(ACondition);
end;

procedure TAccessGate.AddActionKey(const AActionKey: string);
begin
  FActionKeys.Add(AActionKey);
end;

{ TAction }

constructor TAction.Create(const AKey, ADisplayName: string;
  ARiskLevel: TRiskLevel; const AGateKey, ADueRef, APurposeKey: string);
begin
  inherited Create;
  FKey := AKey;
  FDisplayName := ADisplayName;
  FRiskLevel := ARiskLevel;
  FEnabled := True;
  FGateKey := AGateKey;
  FDueRef := ADueRef;
  FPurposeKey := APurposeKey;
  FBridgeKeys := TList<string>.Create;
  FDisabledReason := '';
end;

destructor TAction.Destroy;
begin
  FBridgeKeys.Free;
  inherited;
end;

procedure TAction.AddBridgeKey(const ABridgeKey: string);
begin
  FBridgeKeys.Add(ABridgeKey);
end;

{ TAbility }

constructor TAbility.Create(const AKey, ADisplayName, ADescription: string);
begin
  inherited Create;
  FKey := AKey;
  FDisplayName := ADisplayName;
  FDescription := ADescription;
end;

{ TContextField }

constructor TContextField.Create(const AKey, ADisplayName, ADescription: string);
begin
  inherited Create;
  FKey := AKey;
  FDisplayName := ADisplayName;
  FDescription := ADescription;
  FGateKeys := TList<string>.Create;
  FActionKeys := TList<string>.Create;
end;

destructor TContextField.Destroy;
begin
  FGateKeys.Free;
  FActionKeys.Free;
  inherited;
end;

procedure TContextField.AddGateKey(const AGateKey: string);
begin
  FGateKeys.Add(AGateKey);
end;

procedure TContextField.AddActionKey(const AActionKey: string);
begin
  FActionKeys.Add(AActionKey);
end;

{ TRouteRule }

constructor TRouteRule.Create(const AId, ASourceGateKey, AConditionExpr: string;
  ATargetType: TRouteTargetType; const ATargetKey: string; APriority: Integer);
begin
  inherited Create;
  FId := AId;
  FSourceGateKey := ASourceGateKey;
  FConditionExpr := AConditionExpr;
  FTargetType := ATargetType;
  FTargetKey := ATargetKey;
  FPriority := APriority;
  FFallbackTarget := '';
  FVersion := 1;
  FEffectiveFrom := Now;
  FExpiredAt := 0;
  FRiskLevel := rlL0;
  FEnabled := True;
  FCreatedBy := '';
  FApprovedBy := '';
  FTags := '';
  FDescription := '';
end;

end.
