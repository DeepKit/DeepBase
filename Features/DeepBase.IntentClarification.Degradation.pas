unit DeepBase.IntentClarification.Degradation;

interface

uses
  System.SysUtils,
  DeepBase.IntentClarification.Types,
  DeepBase.IntentClarification.Interfaces;

type
  /// <summary>降级结果记录</summary>
  TDegradationResult = record
    Level: TClarificationLevel;
    Info: string;
  end;

  /// <summary>
  /// 降级处理器 - 实现 L4→L3→L2→L1→L0 逐级降级逻辑。
  /// 当高级别处理器不可用时，自动降级到下一可用级别。
  /// Property 14: 始终返回有效的较低级别，DegradationInfo 非空。
  /// Requirements: 14.1-14.5
  /// </summary>
  TDegradationHandler = class
  public
    /// <summary>
    /// Degrades from the current level to the next lower level.
    /// Returns the degraded level and a non-empty info string describing the reason.
    /// </summary>
    function Degrade(ACurrentLevel: TClarificationLevel;
      const AError: string): TDegradationResult;
  end;

implementation

{ TDegradationHandler }

function TDegradationHandler.Degrade(ACurrentLevel: TClarificationLevel;
  const AError: string): TDegradationResult;
var
  LLevelName: string;
begin
  Result := Default(TDegradationResult);

  // Degrade one level down: L4→L3→L2→L1→L0
  case ACurrentLevel of
    clL4:
    begin
      Result.Level := clL3;
      LLevelName := 'L4→L3';
    end;
    clL3:
    begin
      Result.Level := clL2;
      LLevelName := 'L3→L2';
    end;
    clL2:
    begin
      Result.Level := clL1;
      LLevelName := 'L2→L1';
    end;
    clL1:
    begin
      Result.Level := clL0;
      LLevelName := 'L1→L0';
    end;
    clL0:
    begin
      // Already at lowest level, stay at L0
      Result.Level := clL0;
      LLevelName := 'L0(已是最低级别)';
    end;
  else
    Result.Level := clL0;
    LLevelName := '未知→L0';
  end;

  // Property 14: DegradationInfo always non-empty
  if AError <> '' then
    Result.Info := Format('降级 %s: %s', [LLevelName, AError])
  else
    Result.Info := Format('降级 %s: 上级处理器不可用', [LLevelName]);
end;

end.
