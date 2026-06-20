unit DeepBase.IntentClarification.Router;

interface

uses
  System.SysUtils,
  System.Math,
  DeepBase.IntentClarification.Types,
  DeepBase.IntentClarification.Interfaces;

type
  /// <summary>路由结果，包含计算出的姿态、深度和级别</summary>
  TRouteResult = record
    Posture: TPosture;
    Depth: Double;
    Level: TClarificationLevel;
  end;

  /// <summary>
  /// 姿态深度路由器 - 根据上下文计算 Posture 和 Depth，映射到 Level
  /// Requirements: 2.1-2.8
  /// </summary>
  TPostureDepthRouter = class
  public
    /// <summary>
    /// 将连续深度值映射为离散级别
    /// Property 7: d < 0.2 → L0, d < 0.4 → L1, d < 0.6 → L2, d < 0.8 → L3, d >= 0.8 → L4
    /// </summary>
    class function DepthToLevel(ADepth: Double): TClarificationLevel; static;

    /// <summary>返回指定级别对应的深度上限值</summary>
    class function LevelToMaxDepth(ALevel: TClarificationLevel): Double; static;

    /// <summary>
    /// 将深度值钳制到 MaxLevel 对应的上限范围内
    /// Property 8: 如果计算出的级别 > MaxLevel，则钳制深度到 MaxLevel 的上限
    /// </summary>
    class function ClampDepth(ADepth: Double; AMaxLevel: TClarificationLevel): Double; static;

    /// <summary>
    /// 执行完整路由：计算 Posture、Depth 和 Level
    /// Requirements: 2.1 - 计算 Posture + Depth 组合
    /// Requirements: 2.7 - 允许姿态动态切换
    /// Requirements: 2.8 - MaxLevel 钳制
    /// </summary>
    function Route(const AInput: string; const AState: TSessionState;
      const ASignals: TArray<TDetectedSignal>;
      AMaxLevel: TClarificationLevel): TRouteResult;

  private
    /// <summary>基于上下文计算姿态</summary>
    function ComputePosture(const AInput: string; const AState: TSessionState;
      const ASignals: TArray<TDetectedSignal>): TPosture;

    /// <summary>基于上下文计算深度</summary>
    function ComputeDepth(const AInput: string; const AState: TSessionState;
      const ASignals: TArray<TDetectedSignal>): Double;

    /// <summary>检查信号数组中是否存在指定类型的信号</summary>
    function HasSignal(const ASignals: TArray<TDetectedSignal>;
      AKind: TSignalKind): Boolean;

    /// <summary>获取指定类型信号的最高置信度</summary>
    function GetMaxConfidence(const ASignals: TArray<TDetectedSignal>;
      AKind: TSignalKind): Double;
  end;

implementation

{ TPostureDepthRouter }

class function TPostureDepthRouter.DepthToLevel(ADepth: Double): TClarificationLevel;
begin
  // Property 7: 深度-级别映射正确性
  // d < 0.2 → L0, d < 0.4 → L1, d < 0.6 → L2, d < 0.8 → L3, d >= 0.8 → L4
  if ADepth < 0.2 then
    Result := clL0
  else if ADepth < 0.4 then
    Result := clL1
  else if ADepth < 0.6 then
    Result := clL2
  else if ADepth < 0.8 then
    Result := clL3
  else
    Result := clL4;
end;

class function TPostureDepthRouter.LevelToMaxDepth(ALevel: TClarificationLevel): Double;
begin
  // 返回每个级别对应的深度上限
  case ALevel of
    clL0: Result := 0.2;
    clL1: Result := 0.4;
    clL2: Result := 0.6;
    clL3: Result := 0.8;
    clL4: Result := 1.0;
  else
    Result := 1.0;
  end;
end;

class function TPostureDepthRouter.ClampDepth(ADepth: Double;
  AMaxLevel: TClarificationLevel): Double;
var
  LMaxDepth: Double;
begin
  // Property 8: MaxLevel 钳制
  // 如果计算出的级别超过 MaxLevel，将深度钳制到 MaxLevel 的上限
  LMaxDepth := LevelToMaxDepth(AMaxLevel);

  if ADepth > LMaxDepth then
    Result := LMaxDepth - 0.01  // 钳制到 MaxLevel 范围内（略低于上限以确保映射正确）
  else
    Result := ADepth;

  // 确保结果在 [0.0, 1.0] 范围内
  Result := EnsureRange(Result, 0.0, 1.0);
end;

function TPostureDepthRouter.Route(const AInput: string;
  const AState: TSessionState;
  const ASignals: TArray<TDetectedSignal>;
  AMaxLevel: TClarificationLevel): TRouteResult;
var
  LRawDepth: Double;
begin
  // Requirements 2.1: 计算 Posture + Depth 组合
  Result.Posture := ComputePosture(AInput, AState, ASignals);

  // 计算原始深度
  LRawDepth := ComputeDepth(AInput, AState, ASignals);

  // Requirements 2.8: 应用 MaxLevel 钳制
  Result.Depth := ClampDepth(LRawDepth, AMaxLevel);

  // Requirements 2.2-2.6: 映射到离散级别
  Result.Level := DepthToLevel(Result.Depth);
end;

function TPostureDepthRouter.ComputePosture(const AInput: string;
  const AState: TSessionState;
  const ASignals: TArray<TDetectedSignal>): TPosture;
var
  LInputLen: Integer;
  LHasHesitation: Boolean;
  LHasContradiction: Boolean;
  LHasFrustration: Boolean;
  LHasBreakthrough: Boolean;
  LHighConfidenceSignal: Boolean;
  LSig: TDetectedSignal;
begin
  LInputLen := Length(AInput);
  LHasHesitation := HasSignal(ASignals, skHesitation);
  LHasContradiction := HasSignal(ASignals, skContradiction);
  LHasFrustration := HasSignal(ASignals, skFrustration);
  LHasBreakthrough := HasSignal(ASignals, skBreakthrough);

  // 检查是否有高置信度信号（> 0.7）
  LHighConfidenceSignal := False;
  for LSig in ASignals do
  begin
    if LSig.Confidence > 0.7 then
    begin
      LHighConfidenceSignal := True;
      Break;
    end;
  end;

  // 姿态启发式规则：
  // 1. 挫败信号 → posExecutive（快速收敛）
  if LHasFrustration and (GetMaxConfidence(ASignals, skFrustration) > 0.5) then
  begin
    Result := posExecutive;
    Exit;
  end;

  // 2. 短输入 (< 10 chars) + 无信号 → posExecutive（用户知道自己要什么）
  if (LInputLen < 10) and (Length(ASignals) = 0) then
  begin
    Result := posExecutive;
    Exit;
  end;

  // 3. 突破信号 → posReflective（确认并收敛）
  if LHasBreakthrough then
  begin
    Result := posReflective;
    Exit;
  end;

  // 4. 任何高置信度信号 → posAdvisory
  if LHighConfidenceSignal then
  begin
    Result := posAdvisory;
    Exit;
  end;

  // 5. 长输入 + 矛盾信号 → posExploring
  if (LInputLen > 50) and LHasContradiction then
  begin
    Result := posExploring;
    Exit;
  end;

  // 6. 中等输入 + 犹豫信号 → posClarifying
  if (LInputLen >= 10) and LHasHesitation then
  begin
    Result := posClarifying;
    Exit;
  end;

  // 7. 默认 → posClarifying
  Result := posClarifying;
end;

function TPostureDepthRouter.ComputeDepth(const AInput: string;
  const AState: TSessionState;
  const ASignals: TArray<TDetectedSignal>): Double;
var
  LDepth: Double;
  LInputLen: Integer;
begin
  // 从当前会话深度开始
  LDepth := AState.CurrentDepth;
  LInputLen := Length(AInput);

  // 如果是新会话（深度为 0），设置初始深度
  if (AState.TurnCount = 0) and (LDepth = 0.0) then
    LDepth := 0.1;  // 默认起始深度（L0 范围）

  // 信号检测到时增加深度 (+0.1)
  if Length(ASignals) > 0 then
    LDepth := LDepth + 0.1;

  // 输入很短且直接时减少深度 (-0.1)
  if (LInputLen < 10) and (Length(ASignals) = 0) then
    LDepth := LDepth - 0.1;

  // 长输入暗示更复杂的需求，轻微增加深度
  if LInputLen > 100 then
    LDepth := LDepth + 0.05;

  // 随轮次推进，深度自然增长（每轮 +0.02）
  if AState.TurnCount > 0 then
    LDepth := LDepth + (AState.TurnCount * 0.02);

  // 钳制到 [0.0, 1.0] 范围
  Result := EnsureRange(LDepth, 0.0, 1.0);
end;

function TPostureDepthRouter.HasSignal(const ASignals: TArray<TDetectedSignal>;
  AKind: TSignalKind): Boolean;
var
  LSig: TDetectedSignal;
begin
  Result := False;
  for LSig in ASignals do
  begin
    if LSig.Kind = AKind then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

function TPostureDepthRouter.GetMaxConfidence(
  const ASignals: TArray<TDetectedSignal>;
  AKind: TSignalKind): Double;
var
  LSig: TDetectedSignal;
begin
  Result := 0.0;
  for LSig in ASignals do
  begin
    if (LSig.Kind = AKind) and (LSig.Confidence > Result) then
      Result := LSig.Confidence;
  end;
end;

end.
