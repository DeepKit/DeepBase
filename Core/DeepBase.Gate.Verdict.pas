{ ============================================================================
  DeepBase.Gate.Verdict - 安全门禁裁决统一强类型（T1 fail-closed 立法）

  法源：WO-20260919-AUDIT-甲 A6 / 总报告 T1 家族（裸 Boolean 门禁语义漂移：
        缺字段 / 未知算法 / 异常路径被默认值 or 早退当作"通过"）。

  语义纪律：
  - gdRejected 枚举序 = 0，default(TGateVerdict) / ZeroMemory 记录天然是
    "拒绝"：零值即 fail-closed，不需要任何额外检查代码；
  - 门禁函数只返回本类型，调用侧以 IsApproved 为唯一放行判据；
  - 缺字段 / 未知算法 / 校验异常 → gdRejected；
  - 校验能力不可用（如签名/摘要基线缺失）→ gdIndeterminate。
    注意：Indeterminate 不是豁免 —— 它不等于 True，任何调用侧都不得据此
    放行执行路径（IsApproved 恒 False），仅供审计归因与治理告警。
  - 调用侧书写纪律：非 ASCII 字面量不得直接坐 `Exit()` 未类型化实参位
    （如 `Exit(TGateVerdict.Rejected('中文'))` 会把字面量推导为 AnsiString，
    W1057 转码）；经具类型形参传递（Reject 等）不受影响。

  边界（工单 §3.5）：本单元只做类型化，不做框架 —— 无接口继承体系、
  无插件式 checker、无策略注册表。
  ============================================================================ }

unit DeepBase.Gate.Verdict;

interface

type
  { 门禁裁决。gdRejected 必须保持枚举序 0（缺省即拒绝）。 }
  TGateDecision = (gdRejected, gdApproved, gdIndeterminate);

  TGateVerdict = record
  strict private
    FDecision: TGateDecision;
    FReason: string;
    function GetIsApproved: Boolean;
  public
    class function Approved(const AReason: string = ''): TGateVerdict; static;
    class function Rejected(const AReason: string): TGateVerdict; static;
    { 不可判定 = 不放行 + 告警归因；仅当存在可上报的治理主体时使用，
      其余失败一律 Rejected。 }
    class function Indeterminate(const AReason: string): TGateVerdict; static;
    property Decision: TGateDecision read FDecision;
    property Reason: string read FReason;
    property IsApproved: Boolean read GetIsApproved;
    class operator Implicit(const AVerdict: TGateVerdict): Boolean;
    class operator Equal(const A, B: TGateVerdict): Boolean;
    class operator NotEqual(const A, B: TGateVerdict): Boolean;
  end;

implementation

{ TGateVerdict }

class function TGateVerdict.Approved(const AReason: string): TGateVerdict;
begin
  Result.FDecision := gdApproved;
  Result.FReason := AReason;
end;

class function TGateVerdict.Rejected(const AReason: string): TGateVerdict;
begin
  Result.FDecision := gdRejected;
  Result.FReason := AReason;
end;

class function TGateVerdict.Indeterminate(const AReason: string): TGateVerdict;
begin
  Result.FDecision := gdIndeterminate;
  Result.FReason := AReason;
end;

function TGateVerdict.GetIsApproved: Boolean;
begin
  Result := FDecision = gdApproved;
end;

class operator TGateVerdict.Implicit(const AVerdict: TGateVerdict): Boolean;
begin
  Result := AVerdict.FDecision = gdApproved;
end;

class operator TGateVerdict.Equal(const A, B: TGateVerdict): Boolean;
begin
  Result := A.FDecision = B.FDecision;
end;

class operator TGateVerdict.NotEqual(const A, B: TGateVerdict): Boolean;
begin
  Result := not (A = B);
end;

end.
