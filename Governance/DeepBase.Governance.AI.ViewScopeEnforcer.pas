// AI-GENERATED
// DeepBase.Governance.AI.ViewScopeEnforcer.pas
// P14：AI-ViewScope 强制 — AI 不可见 Locked Gate，不可读高敏感 Evidence

unit DeepBase.Governance.AI.ViewScopeEnforcer;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  DeepBase.Governance.ModelVersion;

type
  TAccessDeniedReason = (adrNone, adrLocked, adrHidden, adrTenantMismatch, adrSensitive);

  TViewScopeCheckResult = record
    Allowed: Boolean;
    DeniedReason: TAccessDeniedReason;
    Message: string;
    class function Allow: TViewScopeCheckResult; static;
    class function Deny(AReason: TAccessDeniedReason; const AMsg: string): TViewScopeCheckResult; static;
  end;

  TViewScopeEnforcer = class
  private
    FViewScope: TViewScope;
    FSensitiveKeys: TList<string>;
    FTenantMap: TDictionary<string, string>;  // objectKey → tenantId
  public
    constructor Create(AViewScope: TViewScope);
    destructor Destroy; override;

    /// 标记对象为高敏感（AI 不可读）
    procedure MarkSensitive(const AObjectKey: string);
    function IsSensitive(const AObjectKey: string): Boolean;

    /// 设置对象的 Tenant 归属
    procedure SetTenant(const AObjectKey, ATenantId: string);

    /// AI 访问检查
    function CheckAIAccess(const AObjectKey, ATenantId: string): TViewScopeCheckResult;

    /// 批量过滤：返回 AI 可见的 Key 列表
    function FilterForAI(const AKeys: TArray<string>; const ATenantId: string): TArray<string>;
  end;

implementation

{ TViewScopeCheckResult }

class function TViewScopeCheckResult.Allow: TViewScopeCheckResult;
begin
  Result.Allowed := True;
  Result.DeniedReason := adrNone;
  Result.Message := '';
end;

class function TViewScopeCheckResult.Deny(AReason: TAccessDeniedReason;
  const AMsg: string): TViewScopeCheckResult;
begin
  Result.Allowed := False;
  Result.DeniedReason := AReason;
  Result.Message := AMsg;
end;

{ TViewScopeEnforcer }

constructor TViewScopeEnforcer.Create(AViewScope: TViewScope);
begin
  inherited Create;
  FViewScope := AViewScope;
  FSensitiveKeys := TList<string>.Create;
  FTenantMap := TDictionary<string, string>.Create;
end;

destructor TViewScopeEnforcer.Destroy;
begin
  FTenantMap.Free;
  FSensitiveKeys.Free;
  inherited;
end;

procedure TViewScopeEnforcer.MarkSensitive(const AObjectKey: string);
begin
  if not FSensitiveKeys.Contains(AObjectKey.ToLower) then
    FSensitiveKeys.Add(AObjectKey.ToLower);
end;

function TViewScopeEnforcer.IsSensitive(const AObjectKey: string): Boolean;
begin
  Result := FSensitiveKeys.Contains(AObjectKey.ToLower);
end;

procedure TViewScopeEnforcer.SetTenant(const AObjectKey, ATenantId: string);
begin
  FTenantMap.AddOrSetValue(AObjectKey.ToLower, ATenantId);
end;

function TViewScopeEnforcer.CheckAIAccess(const AObjectKey, ATenantId: string): TViewScopeCheckResult;
var
  LVisibility: TViewScopeVisibility;
  LObjectTenant: string;
begin
  // 1. ViewScope 检查
  LVisibility := FViewScope.GetVisibility(AObjectKey, 'ai');
  if LVisibility = vsvLocked then
    Exit(TViewScopeCheckResult.Deny(adrLocked, 'Object is locked for AI'));
  if LVisibility = vsvHidden then
    Exit(TViewScopeCheckResult.Deny(adrHidden, 'Object is hidden from AI'));

  // 2. 敏感性检查
  if IsSensitive(AObjectKey) then
    Exit(TViewScopeCheckResult.Deny(adrSensitive, 'Object contains sensitive data'));

  // 3. Tenant 隔离检查
  if FTenantMap.TryGetValue(AObjectKey.ToLower, LObjectTenant) then
  begin
    if (ATenantId <> '') and not SameText(LObjectTenant, ATenantId) then
      Exit(TViewScopeCheckResult.Deny(adrTenantMismatch,
        'Cross-tenant access denied'));
  end;

  Result := TViewScopeCheckResult.Allow;
end;

function TViewScopeEnforcer.FilterForAI(const AKeys: TArray<string>;
  const ATenantId: string): TArray<string>;
var
  LList: TList<string>;
  LKey: string;
  LCheck: TViewScopeCheckResult;
begin
  LList := TList<string>.Create;
  try
    for LKey in AKeys do
    begin
      LCheck := CheckAIAccess(LKey, ATenantId);
      if LCheck.Allowed then
        LList.Add(LKey);
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

end.
