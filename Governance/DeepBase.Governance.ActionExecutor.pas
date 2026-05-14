// AI-GENERATED
// DeepBase.Governance.ActionExecutor.pas
// 第四层：行为执行器（调用 Bridge 链）
// 依赖 Interfaces + ActionGrid + DueChecker

unit DeepBase.Governance.ActionExecutor;

interface

uses
  System.SysUtils,
  System.JSON,
  DeepBase.Governance.Types,
  DeepBase.Governance.Interfaces;

type
  TActionExecutor = class(TInterfacedObject, IActionExecutor)
  private
    FActionGrid: IActionGrid;
    FDueChecker: IDueChecker;
    FEvidenceRecorder: IEvidenceRecorder;
  public
    constructor Create(AActionGrid: IActionGrid; ADueChecker: IDueChecker;
      AEvidenceRecorder: IEvidenceRecorder);

    // IActionExecutor
    function Execute(const AActionKey: string; AContext: TJSONObject;
      AMode: TRunMode): TActionResult;
  end;

implementation

{ TActionExecutor }

constructor TActionExecutor.Create(AActionGrid: IActionGrid;
  ADueChecker: IDueChecker; AEvidenceRecorder: IEvidenceRecorder);
begin
  inherited Create;
  FActionGrid := AActionGrid;
  FDueChecker := ADueChecker;
  FEvidenceRecorder := AEvidenceRecorder;
end;

function TActionExecutor.Execute(const AActionKey: string;
  AContext: TJSONObject; AMode: TRunMode): TActionResult;
var
  LDue: TDueResult;
begin
  // 1. 检查是否可执行
  if not FActionGrid.CanRun(AActionKey, AContext) then
  begin
    Result := TActionResult.Blocked(AActionKey,
      FActionGrid.GetDisabledReason(AActionKey, AContext));
    // 记录阻挡证据
    if FEvidenceRecorder <> nil then
      FEvidenceRecorder.LogBlocked(AActionKey, Result.Message, AContext);
    Exit;
  end;

  // 2. 合当检查（DryRun 和 Commit 都需要）
  if (FDueChecker <> nil) and (AMode <> rmPreview) then
  begin
    LDue := FDueChecker.Check(AActionKey, AContext);
    if LDue.Verdict <> dvPass then
    begin
      Result := TActionResult.Blocked(AActionKey, LDue.Reason);
      if FEvidenceRecorder <> nil then
        FEvidenceRecorder.LogBlocked(AActionKey, LDue.Reason, AContext);
      Exit;
    end;
  end;

  // 3. 执行
  Result := FActionGrid.Run(AActionKey, AContext, AMode);

  // 4. 记录证据（仅 Commit 模式）
  if (FEvidenceRecorder <> nil) and (AMode = rmCommit) then
    FEvidenceRecorder.LogAction(AActionKey, AContext, Result);
end;

end.
