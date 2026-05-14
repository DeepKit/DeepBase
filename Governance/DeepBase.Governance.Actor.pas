// AI-GENERATED
// DeepBase.Governance.Actor.pas
// P03：主体责任对象 — 谁发起、谁代理、谁负责

unit DeepBase.Governance.Actor;

interface

uses
  System.SysUtils,
  System.JSON,
  System.Generics.Collections;

type
  /// 主体类型
  TActorType = (
    atHuman,     // 人类用户
    atAI,        // AI Agent
    atSystem,    // 系统自动
    atTimer,     // 定时器
    atExternal   // 外部系统
  );

  /// 主体对象
  TActor = class
  private
    FKey: string;
    FActorType: TActorType;
    FDisplayName: string;
    FRoles: TArray<string>;
    FScope: string;
  public
    constructor Create(const AKey: string; AActorType: TActorType;
      const ADisplayName: string; const ARoles: TArray<string>;
      const AScope: string = '');
    property Key: string read FKey;
    property ActorType: TActorType read FActorType;
    property DisplayName: string read FDisplayName;
    property Roles: TArray<string> read FRoles;
    property Scope: string read FScope;
    function HasRole(const ARole: string): Boolean;
  end;

  /// 责任记录
  TAccountabilityRecord = class
  private
    FId: string;
    FActionRunId: string;
    FActorKey: string;
    FAgentKey: string;
    FResponsibilityType: string;
    FCreatedAt: TDateTime;
  public
    constructor Create(const AActorKey: string;
      const AActionRunId: string = '';
      const AAgentKey: string = '';
      const AResponsibilityType: string = 'executor');
    property Id: string read FId;
    property ActionRunId: string read FActionRunId write FActionRunId;
    property ActorKey: string read FActorKey;
    property AgentKey: string read FAgentKey;
    property ResponsibilityType: string read FResponsibilityType;
    property CreatedAt: TDateTime read FCreatedAt;
  end;

  /// 运行时上下文（统一包装 Actor + Payload）
  TRuntimeContext = class
  private
    FActor: TActor;
    FPayload: TJSONObject;
    FCorrelationId: string;
    FOwnsPayload: Boolean;
  public
    constructor Create(AActor: TActor; APayload: TJSONObject;
      AOwnsPayload: Boolean = False);
    destructor Destroy; override;

    /// 转为 TJSONObject（供 Runtime.EnterGate 使用）
    function ToJSON: TJSONObject;

    property Actor: TActor read FActor;
    property Payload: TJSONObject read FPayload;
    property CorrelationId: string read FCorrelationId write FCorrelationId;
  end;

  /// Actor 解析器
  IActorResolver = interface
    ['{B1C2D3E4-F5A6-7890-BCDE-F12345678902}']
    function GetCurrentActor: TActor;
    function ResolveActor(const AKey: string): TActor;
  end;

  /// 简单 Actor 注册表
  TActorRegistry = class
  private
    FActors: TObjectDictionary<string, TActor>;
    FCurrentActorKey: string;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Register(AActor: TActor);
    function Find(const AKey: string): TActor;
    function GetCurrent: TActor;
    procedure SetCurrent(const AKey: string);
    function Count: Integer;
  end;

implementation

{ TActor }

constructor TActor.Create(const AKey: string; AActorType: TActorType;
  const ADisplayName: string; const ARoles: TArray<string>;
  const AScope: string);
begin
  inherited Create;
  FKey := AKey;
  FActorType := AActorType;
  FDisplayName := ADisplayName;
  FRoles := ARoles;
  FScope := AScope;
end;

function TActor.HasRole(const ARole: string): Boolean;
var
  R: string;
begin
  for R in FRoles do
    if SameText(R, ARole) then
      Exit(True);
  Result := False;
end;

{ TAccountabilityRecord }

constructor TAccountabilityRecord.Create(const AActorKey, AActionRunId,
  AAgentKey, AResponsibilityType: string);
begin
  inherited Create;
  FId := TGUID.NewGuid.ToString;
  FActorKey := AActorKey;
  FActionRunId := AActionRunId;
  FAgentKey := AAgentKey;
  FResponsibilityType := AResponsibilityType;
  FCreatedAt := Now;
end;

{ TRuntimeContext }

constructor TRuntimeContext.Create(AActor: TActor; APayload: TJSONObject;
  AOwnsPayload: Boolean);
begin
  inherited Create;
  FActor := AActor;
  FPayload := APayload;
  FOwnsPayload := AOwnsPayload;
  FCorrelationId := TGUID.NewGuid.ToString;
end;

destructor TRuntimeContext.Destroy;
begin
  if FOwnsPayload and (FPayload <> nil) then
    FPayload.Free;
  inherited;
end;

function TRuntimeContext.ToJSON: TJSONObject;
var
  LUser: TJSONObject;
begin
  Result := TJSONObject.Create;
  if FActor <> nil then
  begin
    Result.AddPair('user_id', FActor.Key);
    LUser := TJSONObject.Create;
    if Length(FActor.Roles) > 0 then
      LUser.AddPair('role', FActor.Roles[0]);
    Result.AddPair('user', LUser);
  end;
  Result.AddPair('correlation_id', FCorrelationId);

  // 合并 Payload 字段
  if FPayload <> nil then
  begin
    var LPair: TJSONPair;
    for LPair in FPayload do
    begin
      if Result.GetValue(LPair.JsonString.Value) = nil then
        Result.AddPair(LPair.JsonString.Value, LPair.JsonValue.Clone as TJSONValue);
    end;
  end;
end;

{ TActorRegistry }

constructor TActorRegistry.Create;
begin
  inherited Create;
  FActors := TObjectDictionary<string, TActor>.Create([doOwnsValues]);
  FCurrentActorKey := '';
end;

destructor TActorRegistry.Destroy;
begin
  FActors.Free;
  inherited;
end;

procedure TActorRegistry.Register(AActor: TActor);
begin
  FActors.AddOrSetValue(AActor.Key, AActor);
end;

function TActorRegistry.Find(const AKey: string): TActor;
begin
  if not FActors.TryGetValue(AKey, Result) then
    Result := nil;
end;

function TActorRegistry.GetCurrent: TActor;
begin
  Result := Find(FCurrentActorKey);
end;

procedure TActorRegistry.SetCurrent(const AKey: string);
begin
  FCurrentActorKey := AKey;
end;

function TActorRegistry.Count: Integer;
begin
  Result := FActors.Count;
end;

end.
