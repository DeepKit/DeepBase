unit DeepBase.IntentClarification.Types;

interface

uses
  System.SysUtils,
  System.JSON,
  System.DateUtils;

type
  TClarificationLevel = (
    clL0,
    clL1,
    clL2,
    clL3,
    clL4
  );

  TPosture = (
    posExecutive,
    posClarifying,
    posExploring,
    posAdvisory,
    posReflective
  );

  TSessionStatus = (
    ssActive,
    ssSuspended,
    ssCompleted,
    ssArchived
  );

  TSignalKind = (
    skHesitation,
    skContradiction,
    skFrustration,
    skAvoidance,
    skBreakthrough
  );

  TOptionItem = record
    Number: Integer;
    Code: string;
    Text: string;
    Value: string;
    IsRecommended: Boolean;
  end;

  TProgressHint = record
    CurrentTurn: Integer;
    EstimatedRemaining: Integer;
    Message: string;
  end;

  TDetectedSignal = record
    Kind: TSignalKind;
    Confidence: Double;
    Evidence: string;
    Source: string;
    DetectedAt: TDateTime;
  end;

  THypothesis = record
    Text: string;
    IntentName: string;
    Confidence: Double;
    Evidence: string;
    SlotsJson: string;
    Denied: Boolean;
  end;

  TTurnRecord = record
    TurnNumber: Integer;
    UserInput: string;
    Question: string;
    Answer: string;
    AssistantOutput: string;
    Level: TClarificationLevel;
    Posture: TPosture;
    Timestamp: TDateTime;
  end;

  TRapportProfile = record
    UserId: string;
    TrustLevel: Double;
    Familiarity: Double;
    PreferredDepth: Double;
    CommunicationStyle: string;
    Boundaries: TArray<string>;
    LastUpdated: TDateTime;
  end;

  TBudgetConfig = record
    MaxTurns: Integer;
    MaxTimeSeconds: Integer;
    MaxTokens: Integer;
    MaxCognitiveLoad: Integer;
    UserPatienceThreshold: Double;

    class function Default: TBudgetConfig; static;
  end;

  TBudgetStatus = record
    TurnsUsed: Integer;
    TurnsRemaining: Integer;
    TokensUsed: Integer;
    TokensRemaining: Integer;
    TimeElapsedMs: Int64;
    IsExhausted: Boolean;
    ShouldExit: Boolean;
  end;

  TPresetTemplate = record
    Name: string;
    MaxLevel: TClarificationLevel;
    Style: string;
    EnableAnticipation: Boolean;
    EnablePersonas: Boolean;
    PersonaPack: string;
    DefaultPosture: TPosture;
    BudgetConfig: TBudgetConfig;

    class function ToolCommand: TPresetTemplate; static;
    class function CreativeAssistant: TPresetTemplate; static;
    class function DecisionAdvisor: TPresetTemplate; static;
  end;

  TAnticipationSource = record
    SourceType: string;
    Signal: string;
    Confidence: Double;
    Evidence: string;
  end;

  TAnticipationResult = record
    PredictionId: string;
    IntentName: string;
    Confidence: Double;
    Sources: TArray<TAnticipationSource>;
    Evidence: string;
  end;

  TSessionState = record
    SessionId: string;
    UserId: string;
    DomainName: string;
    IntentName: string;
    Status: TSessionStatus;
    CurrentLevel: TClarificationLevel;
    CurrentPosture: TPosture;
    CurrentDepth: Double;
    TurnCount: Integer;
    CreatedAt: TDateTime;
    LastActiveAt: TDateTime;
    Hypotheses: TArray<THypothesis>;
    Signals: TArray<TDetectedSignal>;
    History: TArray<TTurnRecord>;
    CheckpointJson: string;
  end;

  TSessionCheckpoint = record
    Version: Integer;
    SessionState: TSessionState;
    RapportSnapshot: TRapportProfile;
    TurnHistory: TArray<TTurnRecord>;
    OpenQuestions: TArray<string>;
    ResumeHint: string;
    SerializedAt: TDateTime;

    function ToJson: string;
    class function FromJson(const AJson: string): TSessionCheckpoint; static;
  end;

  TTurnResult = record
    SessionId: string;
    TurnNumber: Integer;
    Status: TSessionStatus;
    Level: TClarificationLevel;
    Posture: TPosture;
    Question: string;
    Options: TArray<TOptionItem>;
    RecommendedOption: Integer;
    Scaffolds: TArray<string>;
    ProgressHint: TProgressHint;
    EchoConfirmation: string;
    DegradationInfo: string;
    Signals: TArray<TDetectedSignal>;
    AcceptsFreeText: Boolean;
    Source: string;
    ErrorCode: string;
    ErrorMessage: string;
  end;

implementation

function JsonString(AObj: TJSONObject; const AName, ADefault: string): string;
var
  LValue: TJSONValue;
begin
  Result := ADefault;
  if AObj = nil then
    Exit;

  LValue := AObj.GetValue(AName);
  if LValue <> nil then
    Result := LValue.Value;
end;

function JsonInt(AObj: TJSONObject; const AName: string; ADefault: Integer): Integer;
var
  LValue: TJSONValue;
begin
  Result := ADefault;
  if AObj = nil then
    Exit;

  LValue := AObj.GetValue(AName);
  if LValue <> nil then
    Result := StrToIntDef(LValue.Value, ADefault);
end;

function JsonFloat(AObj: TJSONObject; const AName: string; ADefault: Double): Double;
var
  LValue: TJSONValue;
begin
  Result := ADefault;
  if AObj = nil then
    Exit;

  LValue := AObj.GetValue(AName);
  if LValue <> nil then
    Result := StrToFloatDef(StringReplace(LValue.Value, ',', '.', [rfReplaceAll]), ADefault);
end;

class function TBudgetConfig.Default: TBudgetConfig;
begin
  Result.MaxTurns := 6;
  Result.MaxTimeSeconds := 300;
  Result.MaxTokens := 0;
  Result.MaxCognitiveLoad := 3;
  Result.UserPatienceThreshold := 0.7;
end;

{ TPresetTemplate }

class function TPresetTemplate.ToolCommand: TPresetTemplate;
begin
  Result := Default(TPresetTemplate);
  Result.Name := 'tool-command';
  Result.MaxLevel := clL1;
  Result.Style := 'direct';
  Result.EnableAnticipation := False;
  Result.EnablePersonas := False;
  Result.PersonaPack := '';
  Result.DefaultPosture := posExecutive;
  Result.BudgetConfig := TBudgetConfig.Default;
  Result.BudgetConfig.MaxTurns := 3;
  Result.BudgetConfig.MaxTimeSeconds := 120;
end;

class function TPresetTemplate.CreativeAssistant: TPresetTemplate;
begin
  Result := Default(TPresetTemplate);
  Result.Name := 'creative-assistant';
  Result.MaxLevel := clL2;
  Result.Style := 'exploratory';
  Result.EnableAnticipation := True;
  Result.EnablePersonas := False;
  Result.PersonaPack := 'creative';
  Result.DefaultPosture := posExploring;
  Result.BudgetConfig := TBudgetConfig.Default;
  Result.BudgetConfig.MaxTurns := 6;
  Result.BudgetConfig.MaxTimeSeconds := 300;
end;

class function TPresetTemplate.DecisionAdvisor: TPresetTemplate;
begin
  Result := Default(TPresetTemplate);
  Result.Name := 'decision-advisor';
  Result.MaxLevel := clL4;
  Result.Style := 'empathetic';
  Result.EnableAnticipation := True;
  Result.EnablePersonas := True;
  Result.PersonaPack := 'decision';
  Result.DefaultPosture := posAdvisory;
  Result.BudgetConfig := TBudgetConfig.Default;
  Result.BudgetConfig.MaxTurns := 8;
  Result.BudgetConfig.MaxTimeSeconds := 600;
end;

{ TSessionCheckpoint }

function TSessionCheckpoint.ToJson: string;
var
  LRoot: TJSONObject;
  LState: TJSONObject;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('version', TJSONNumber.Create(Version));
    LRoot.AddPair('resumeHint', ResumeHint);
    LRoot.AddPair('serializedAt', DateToISO8601(SerializedAt, False));

    LState := TJSONObject.Create;
    LState.AddPair('sessionId', SessionState.SessionId);
    LState.AddPair('userId', SessionState.UserId);
    LState.AddPair('domainName', SessionState.DomainName);
    LState.AddPair('intentName', SessionState.IntentName);
    LState.AddPair('status', TJSONNumber.Create(Ord(SessionState.Status)));
    LState.AddPair('currentLevel', TJSONNumber.Create(Ord(SessionState.CurrentLevel)));
    LState.AddPair('currentPosture', TJSONNumber.Create(Ord(SessionState.CurrentPosture)));
    LState.AddPair('currentDepth', TJSONNumber.Create(SessionState.CurrentDepth));
    LState.AddPair('turnCount', TJSONNumber.Create(SessionState.TurnCount));
    LState.AddPair('createdAt', DateToISO8601(SessionState.CreatedAt, False));
    LState.AddPair('lastActiveAt', DateToISO8601(SessionState.LastActiveAt, False));
    LRoot.AddPair('sessionState', LState);

    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

class function TSessionCheckpoint.FromJson(const AJson: string): TSessionCheckpoint;
var
  LValue: TJSONValue;
  LRoot: TJSONObject;
  LState: TJSONObject;
  LStatus: Integer;
  LLevel: Integer;
  LPosture: Integer;
begin
  Result := Default(TSessionCheckpoint);
  if Trim(AJson) = '' then
    Exit;

  LValue := TJSONObject.ParseJSONValue(AJson);
  if LValue = nil then
    raise EArgumentException.Create('Invalid session checkpoint JSON');
  if not (LValue is TJSONObject) then
  begin
    LValue.Free;
    raise EArgumentException.Create('Session checkpoint JSON root is not an object');
  end;

  LRoot := LValue as TJSONObject;
  try
    Result.Version := JsonInt(LRoot, 'version', 1);
    Result.ResumeHint := JsonString(LRoot, 'resumeHint', '');
    Result.SerializedAt := ISO8601ToDate(JsonString(LRoot, 'serializedAt',
      DateToISO8601(Now, False)), False);

    LState := LRoot.GetValue('sessionState') as TJSONObject;
    if LState <> nil then
    begin
      Result.SessionState.SessionId := JsonString(LState, 'sessionId', '');
      Result.SessionState.UserId := JsonString(LState, 'userId', '');
      Result.SessionState.DomainName := JsonString(LState, 'domainName', '');
      Result.SessionState.IntentName := JsonString(LState, 'intentName', '');

      LStatus := JsonInt(LState, 'status', Ord(ssArchived));
      if (LStatus < Ord(Low(TSessionStatus))) or (LStatus > Ord(High(TSessionStatus))) then
        LStatus := Ord(ssArchived);
      Result.SessionState.Status := TSessionStatus(LStatus);

      LLevel := JsonInt(LState, 'currentLevel', Ord(clL1));
      if (LLevel < Ord(Low(TClarificationLevel))) or
         (LLevel > Ord(High(TClarificationLevel))) then
        LLevel := Ord(clL1);
      Result.SessionState.CurrentLevel := TClarificationLevel(LLevel);

      LPosture := JsonInt(LState, 'currentPosture', Ord(posClarifying));
      if (LPosture < Ord(Low(TPosture))) or (LPosture > Ord(High(TPosture))) then
        LPosture := Ord(posClarifying);
      Result.SessionState.CurrentPosture := TPosture(LPosture);

      Result.SessionState.CurrentDepth := JsonFloat(LState, 'currentDepth', 0.3);
      Result.SessionState.TurnCount := JsonInt(LState, 'turnCount', 0);
      Result.SessionState.CreatedAt := ISO8601ToDate(JsonString(LState, 'createdAt',
        DateToISO8601(Now, False)), False);
      Result.SessionState.LastActiveAt := ISO8601ToDate(JsonString(LState, 'lastActiveAt',
        DateToISO8601(Now, False)), False);
    end;
  finally
    LRoot.Free;
  end;
end;

end.
