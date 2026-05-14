// AI-GENERATED
// DeepBase.Governance.Explain.pas
// P11：审计与解释层 — ExplainRecord / AuditReport

unit DeepBase.Governance.Explain;

interface

uses
  System.SysUtils,
  System.JSON,
  System.Generics.Collections,
  DeepBase.Governance.Run;

type
  TExplainRecord = class
  private
    FId: string;
    FActionRunId: string;
    FGateKey: string;
    FDecisionPath: TArray<string>;
    FBlockedReason: string;
    FTimestamp: TDateTime;
  public
    constructor Create(const AActionRunId, AGateKey: string);
    procedure AddStep(const AStep: string);
    procedure SetBlocked(const AReason: string);
    function ToJSON: TJSONObject;
    function ToMarkdown: string;
    property Id: string read FId;
    property ActionRunId: string read FActionRunId;
    property GateKey: string read FGateKey;
    property DecisionPath: TArray<string> read FDecisionPath;
    property BlockedReason: string read FBlockedReason;
  end;

  TAuditFinding = record
    Id: string;
    Severity: string;  // Info/Warning/Severe/Critical
    ActionKey: string;
    Description: string;
    Suggestion: string;
  end;

  TAuditReport = class
  private
    FId: string;
    FCreatedAt: TDateTime;
    FScope: string;
    FFindings: TList<TAuditFinding>;
    FExplainRecords: TObjectList<TExplainRecord>;
  public
    constructor Create(const AScope: string);
    destructor Destroy; override;
    procedure AddFinding(const ASeverity, AActionKey, ADescription, ASuggestion: string);
    procedure AddExplain(ARecord: TExplainRecord);
    function GetFindings: TArray<TAuditFinding>;
    function FindingCount: Integer;
    function ToJSON: TJSONObject;
    function ToMarkdown: string;
    function QueryByAction(const AActionKey: string): TArray<TAuditFinding>;
    property Id: string read FId;
    property Scope: string read FScope;
    property CreatedAt: TDateTime read FCreatedAt;
  end;

implementation

{ TExplainRecord }

constructor TExplainRecord.Create(const AActionRunId, AGateKey: string);
begin
  inherited Create;
  FId := TGUID.NewGuid.ToString;
  FActionRunId := AActionRunId;
  FGateKey := AGateKey;
  FDecisionPath := nil;
  FBlockedReason := '';
  FTimestamp := Now;
end;

procedure TExplainRecord.AddStep(const AStep: string);
begin
  SetLength(FDecisionPath, Length(FDecisionPath) + 1);
  FDecisionPath[High(FDecisionPath)] := AStep;
end;

procedure TExplainRecord.SetBlocked(const AReason: string);
begin
  FBlockedReason := AReason;
end;

function TExplainRecord.ToJSON: TJSONObject;
var
  LArr: TJSONArray;
  S: string;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id', FId);
  Result.AddPair('action_run_id', FActionRunId);
  Result.AddPair('gate_key', FGateKey);
  LArr := TJSONArray.Create;
  for S in FDecisionPath do
    LArr.Add(S);
  Result.AddPair('decision_path', LArr);
  if FBlockedReason <> '' then
    Result.AddPair('blocked_reason', FBlockedReason);
end;

function TExplainRecord.ToMarkdown: string;
var
  S: string;
begin
  Result := '## Explain: ' + FGateKey + #13#10;
  Result := Result + 'ActionRun: ' + FActionRunId + #13#10;
  Result := Result + '### Decision Path' + #13#10;
  for S in FDecisionPath do
    Result := Result + '- ' + S + #13#10;
  if FBlockedReason <> '' then
    Result := Result + '### Blocked: ' + FBlockedReason + #13#10;
end;

{ TAuditReport }

constructor TAuditReport.Create(const AScope: string);
begin
  inherited Create;
  FId := TGUID.NewGuid.ToString;
  FScope := AScope;
  FCreatedAt := Now;
  FFindings := TList<TAuditFinding>.Create;
  FExplainRecords := TObjectList<TExplainRecord>.Create(True);
end;

destructor TAuditReport.Destroy;
begin
  FExplainRecords.Free;
  FFindings.Free;
  inherited;
end;

procedure TAuditReport.AddFinding(const ASeverity, AActionKey, ADescription, ASuggestion: string);
var
  F: TAuditFinding;
begin
  F.Id := TGUID.NewGuid.ToString;
  F.Severity := ASeverity;
  F.ActionKey := AActionKey;
  F.Description := ADescription;
  F.Suggestion := ASuggestion;
  FFindings.Add(F);
end;

procedure TAuditReport.AddExplain(ARecord: TExplainRecord);
begin
  FExplainRecords.Add(ARecord);
end;

function TAuditReport.GetFindings: TArray<TAuditFinding>;
begin
  Result := FFindings.ToArray;
end;

function TAuditReport.FindingCount: Integer;
begin
  Result := FFindings.Count;
end;

function TAuditReport.ToJSON: TJSONObject;
var
  LArr: TJSONArray;
  F: TAuditFinding;
  LObj: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id', FId);
  Result.AddPair('scope', FScope);
  LArr := TJSONArray.Create;
  for F in FFindings do
  begin
    LObj := TJSONObject.Create;
    LObj.AddPair('severity', F.Severity);
    LObj.AddPair('action_key', F.ActionKey);
    LObj.AddPair('description', F.Description);
    LObj.AddPair('suggestion', F.Suggestion);
    LArr.AddElement(LObj);
  end;
  Result.AddPair('findings', LArr);
end;

function TAuditReport.ToMarkdown: string;
var
  F: TAuditFinding;
begin
  Result := '# Audit Report: ' + FScope + #13#10;
  Result := Result + 'Findings: ' + IntToStr(FFindings.Count) + #13#10#13#10;
  for F in FFindings do
  begin
    Result := Result + '## [' + F.Severity + '] ' + F.ActionKey + #13#10;
    Result := Result + F.Description + #13#10;
    if F.Suggestion <> '' then
      Result := Result + '> Suggestion: ' + F.Suggestion + #13#10;
    Result := Result + #13#10;
  end;
end;

function TAuditReport.QueryByAction(const AActionKey: string): TArray<TAuditFinding>;
var
  LList: TList<TAuditFinding>;
  F: TAuditFinding;
begin
  LList := TList<TAuditFinding>.Create;
  try
    for F in FFindings do
      if SameText(F.ActionKey, AActionKey) then
        LList.Add(F);
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

end.
