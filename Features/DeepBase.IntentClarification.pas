unit DeepBase.IntentClarification;

interface

uses
  System.SysUtils,
  DeepBase.LLM.Client,
  DeepBase.LLM.Types;

type
  EIntentClarification = class(Exception);

  TClarificationSelectionMode = (
    csmFreeText,
    csmSingleChoice,
    csmMultiChoice
  );

  TIntentClarificationStatus = (
    icsReady,
    icsNeedsClarification,
    icsFailed
  );

  TIntentClarificationOption = record
    Code: string;
    Text: string;
    Value: string;

    class function Create(const ACode, AText: string;
      const AValue: string = ''): TIntentClarificationOption; static;
  end;

  TIntentClarificationSlot = record
    Name: string;
    DisplayName: string;
    Value: string;
    Required: Boolean;
    Confidence: Double;
    Question: string;
    Options: TArray<TIntentClarificationOption>;

    procedure Init;
    function EffectiveName: string;
    function IsSatisfied(AMinConfidence: Double): Boolean;
  end;

  TIntentClarificationRequest = record
    SessionId: string;
    IntentName: string;
    UserText: string;
    Locale: string;
    Domain: string;
    ContextSummary: string;
    AnchorQuestion: string;
    Slots: TArray<TIntentClarificationSlot>;
    RecentTurns: TArray<string>;

    procedure Init;
  end;

  TIntentClarificationResult = record
    Status: TIntentClarificationStatus;
    IntentName: string;
    Confidence: Double;
    Question: string;
    SelectionMode: TClarificationSelectionMode;
    Options: TArray<TIntentClarificationOption>;
    MissingSlots: TArray<string>;
    Slots: TArray<TIntentClarificationSlot>;
    Source: string;
    ErrorCode: string;
    ErrorMessage: string;
    RawResponse: string;

    function NeedsClarification: Boolean;
    function IsReady: Boolean;
  end;

  TIntentClarificationPolicy = record
    MinSlotConfidence: Double;
    MinIntentConfidence: Double;
    MaxOptions: Integer;
    MaxPromptChars: Integer;
    UseLLM: Boolean;
    ModelTier: TModelTier;

    class function Default: TIntentClarificationPolicy; static;
  end;

  // NOTE: IClarificationEngine is defined in DeepBase.IntentClarification.Interfaces.
  // The base unit cannot import Interfaces due to circular dependency.
  // Recommended creation path: TICIoCRegistration.CreateEngineFromContainer (see IoC.pas).
  // CreateEngine/CreateEngineWithPreset below return IInterface; cast to
  // IClarificationEngine via Supports() or use the IoC path directly.

  TIntentClarifier = class
  private
    FLLM: ILLMClient;
    FPolicy: TIntentClarificationPolicy;

    function BuildRuleResult(
      const ARequest: TIntentClarificationRequest): TIntentClarificationResult;
    function BuildLLMSystemPrompt: string;
    function BuildLLMUserPrompt(
      const ARequest: TIntentClarificationRequest): string;
    function TryClarifyWithLLM(const ARequest: TIntentClarificationRequest;
      out AResult: TIntentClarificationResult): Boolean;
    function TryParseLLMJson(const AJson: string;
      const ARequest: TIntentClarificationRequest;
      out AResult: TIntentClarificationResult): Boolean;
    function CalculateConfidence(
      const ASlots: TArray<TIntentClarificationSlot>): Double;
  public
    constructor Create; overload;
    constructor Create(const ALLM: ILLMClient); overload;

    function Clarify(
      const ARequest: TIntentClarificationRequest): TIntentClarificationResult;

    class function ApplyOptionAnswer(
      const ARequest: TIntentClarificationRequest;
      const ASlotName, AAnswer: string;
      out AUpdatedRequest: TIntentClarificationRequest): Boolean; static;

    class function SelectionModeToString(
      AMode: TClarificationSelectionMode): string; static;
    class function StringToSelectionMode(
      const AValue: string): TClarificationSelectionMode; static;

    /// <summary>
    /// Creates a TClarificationEngine with default configuration.
    /// Returns IInterface; use Supports(Result, IClarificationEngine) to cast.
    /// Recommended: use TICIoCRegistration.CreateEngineFromContainer instead.
    /// </summary>
    class function CreateEngine: IInterface; static;

    /// <summary>
    /// Creates a TClarificationEngine configured with the named preset template.
    /// Returns IInterface; use Supports(Result, IClarificationEngine) to cast.
    /// Recommended: use TICIoCRegistration.CreateEngineFromContainer instead.
    /// </summary>
    class function CreateEngineWithPreset(
      const APresetName: string): IInterface; static;

    property LLM: ILLMClient read FLLM write FLLM;
    property Policy: TIntentClarificationPolicy read FPolicy write FPolicy;
  end;

implementation

uses
  System.JSON,
  System.Math,
  System.StrUtils,
  System.Generics.Collections,
  DeepBase.IntentClarification.Engine;

function NormalizeJsonObjectText(const AText: string): string;
var
  LText: string;
  LStart: Integer;
  LStop: Integer;
begin
  LText := Trim(AText);

  if StartsText('```json', LText) then
    LText := Trim(Copy(LText, 8, MaxInt))
  else if StartsText('```', LText) then
    LText := Trim(Copy(LText, 4, MaxInt));

  if EndsText('```', LText) then
    LText := Trim(Copy(LText, 1, Length(LText) - 3));

  LStart := Pos('{', LText);
  LStop := LastDelimiter('}', LText);
  if (LStart > 0) and (LStop >= LStart) then
    Result := Copy(LText, LStart, LStop - LStart + 1)
  else
    Result := LText;
end;

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

function JsonBool(AObj: TJSONObject; const AName: string;
  ADefault: Boolean): Boolean;
var
  LValue: TJSONValue;
begin
  Result := ADefault;
  if AObj = nil then
    Exit;

  LValue := AObj.GetValue(AName);
  if LValue = nil then
    Exit;

  if LValue is TJSONTrue then
    Exit(True);
  if LValue is TJSONFalse then
    Exit(False);

  Result := SameText(LValue.Value, 'true') or (LValue.Value = '1') or
    SameText(LValue.Value, 'yes');
end;

function JsonFloat(AObj: TJSONObject; const AName: string;
  ADefault: Double): Double;
var
  LValue: TJSONValue;
begin
  Result := ADefault;
  if AObj = nil then
    Exit;

  LValue := AObj.GetValue(AName);
  if LValue <> nil then
    Result := StrToFloatDef(StringReplace(LValue.Value, ',', '.',
      [rfReplaceAll]), ADefault);
end;

procedure CopySlots(const ASource: TArray<TIntentClarificationSlot>;
  out ADest: TArray<TIntentClarificationSlot>);
var
  I: Integer;
begin
  SetLength(ADest, Length(ASource));
  for I := 0 to High(ASource) do
    ADest[I] := ASource[I];
end;

function SlotIndexByName(const ASlots: TArray<TIntentClarificationSlot>;
  const AName: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(ASlots) do
    if SameText(ASlots[I].Name, AName) then
      Exit(I);
  Result := -1;
end;

function FirstText(const AValue, AFallback: string): string;
begin
  if Trim(AValue) <> '' then
    Result := AValue
  else
    Result := AFallback;
end;

function TrimOptions(const AOptions: TArray<TIntentClarificationOption>;
  AMaxOptions: Integer): TArray<TIntentClarificationOption>;
var
  I: Integer;
  LCount: Integer;
begin
  if AMaxOptions <= 0 then
    AMaxOptions := Length(AOptions);

  LCount := Min(Length(AOptions), AMaxOptions);
  SetLength(Result, LCount);
  for I := 0 to LCount - 1 do
    Result[I] := AOptions[I];
end;

function ParseOptions(AArray: TJSONArray;
  AMaxOptions: Integer): TArray<TIntentClarificationOption>;
var
  I: Integer;
  LCount: Integer;
  LObj: TJSONObject;
begin
  SetLength(Result, 0);
  if AArray = nil then
    Exit;

  LCount := AArray.Count;
  if AMaxOptions > 0 then
    LCount := Min(LCount, AMaxOptions);

  SetLength(Result, LCount);
  for I := 0 to LCount - 1 do
  begin
    if AArray.Items[I] is TJSONObject then
    begin
      LObj := AArray.Items[I] as TJSONObject;
      Result[I].Code := FirstText(JsonString(LObj, 'code', ''),
        JsonString(LObj, 'key', ''));
      Result[I].Text := JsonString(LObj, 'text', '');
      Result[I].Value := FirstText(JsonString(LObj, 'value', ''),
        Result[I].Text);
    end
    else
    begin
      Result[I].Code := Chr(Ord('A') + I);
      Result[I].Text := AArray.Items[I].Value;
      Result[I].Value := Result[I].Text;
    end;
  end;
end;

function ParseMissingSlots(AArray: TJSONArray): TArray<string>;
var
  I: Integer;
begin
  SetLength(Result, 0);
  if AArray = nil then
    Exit;

  SetLength(Result, AArray.Count);
  for I := 0 to AArray.Count - 1 do
    Result[I] := AArray.Items[I].Value;
end;

function ParseSlots(AArray: TJSONArray;
  const ARequest: TIntentClarificationRequest): TArray<TIntentClarificationSlot>;
var
  I: Integer;
  LObj: TJSONObject;
  LName: string;
  LExistingIdx: Integer;
begin
  CopySlots(ARequest.Slots, Result);
  if AArray = nil then
    Exit;

  for I := 0 to AArray.Count - 1 do
  begin
    if not (AArray.Items[I] is TJSONObject) then
      Continue;

    LObj := AArray.Items[I] as TJSONObject;
    LName := JsonString(LObj, 'name', '');
    if LName = '' then
      Continue;

    LExistingIdx := SlotIndexByName(Result, LName);
    if LExistingIdx < 0 then
    begin
      SetLength(Result, Length(Result) + 1);
      LExistingIdx := High(Result);
      Result[LExistingIdx].Init;
      Result[LExistingIdx].Name := LName;
    end;

    Result[LExistingIdx].DisplayName := FirstText(
      JsonString(LObj, 'display_name', ''), Result[LExistingIdx].DisplayName);
    Result[LExistingIdx].Value := FirstText(JsonString(LObj, 'value', ''),
      Result[LExistingIdx].Value);
    Result[LExistingIdx].Confidence := JsonFloat(LObj, 'confidence',
      Result[LExistingIdx].Confidence);
    Result[LExistingIdx].Required := JsonBool(LObj, 'required',
      Result[LExistingIdx].Required);
    Result[LExistingIdx].Question := FirstText(JsonString(LObj, 'question', ''),
      Result[LExistingIdx].Question);
  end;
end;

function BuildOptionsJson(
  const AOptions: TArray<TIntentClarificationOption>): TJSONArray;
var
  LOption: TIntentClarificationOption;
  LObj: TJSONObject;
begin
  Result := TJSONArray.Create;
  for LOption in AOptions do
  begin
    LObj := TJSONObject.Create;
    LObj.AddPair('code', LOption.Code);
    LObj.AddPair('text', LOption.Text);
    LObj.AddPair('value', FirstText(LOption.Value, LOption.Text));
    Result.AddElement(LObj);
  end;
end;

{ TIntentClarificationOption }

class function TIntentClarificationOption.Create(const ACode, AText,
  AValue: string): TIntentClarificationOption;
begin
  Result.Code := ACode;
  Result.Text := AText;
  Result.Value := FirstText(AValue, AText);
end;

{ TIntentClarificationSlot }

procedure TIntentClarificationSlot.Init;
begin
  Name := '';
  DisplayName := '';
  Value := '';
  Required := True;
  Confidence := 0;
  Question := '';
  SetLength(Options, 0);
end;

function TIntentClarificationSlot.EffectiveName: string;
begin
  Result := FirstText(DisplayName, Name);
end;

function TIntentClarificationSlot.IsSatisfied(
  AMinConfidence: Double): Boolean;
begin
  if not Required then
    Exit(True);

  Result := (Trim(Value) <> '') and
    ((Confidence <= 0) or (Confidence >= AMinConfidence));
end;

{ TIntentClarificationRequest }

procedure TIntentClarificationRequest.Init;
begin
  SessionId := '';
  IntentName := '';
  UserText := '';
  Locale := 'zh-CN';
  Domain := '';
  ContextSummary := '';
  AnchorQuestion := '';
  SetLength(Slots, 0);
  SetLength(RecentTurns, 0);
end;

{ TIntentClarificationResult }

function TIntentClarificationResult.NeedsClarification: Boolean;
begin
  Result := Status = icsNeedsClarification;
end;

function TIntentClarificationResult.IsReady: Boolean;
begin
  Result := Status = icsReady;
end;

{ TIntentClarificationPolicy }

class function TIntentClarificationPolicy.Default: TIntentClarificationPolicy;
begin
  Result.MinSlotConfidence := 0.6;
  Result.MinIntentConfidence := 0.6;
  Result.MaxOptions := 8;
  Result.MaxPromptChars := 6000;
  Result.UseLLM := True;
  Result.ModelTier := TierFast;
end;

{ TIntentClarifier }

constructor TIntentClarifier.Create;
begin
  inherited Create;
  FPolicy := TIntentClarificationPolicy.Default;
end;

constructor TIntentClarifier.Create(const ALLM: ILLMClient);
begin
  Create;
  FLLM := ALLM;
end;

function TIntentClarifier.CalculateConfidence(
  const ASlots: TArray<TIntentClarificationSlot>): Double;
var
  LSlot: TIntentClarificationSlot;
  LValue: Double;
begin
  Result := 1.0;
  for LSlot in ASlots do
  begin
    if not LSlot.Required then
      Continue;

    if Trim(LSlot.Value) = '' then
      LValue := 0
    else if LSlot.Confidence <= 0 then
      LValue := 1.0
    else
      LValue := LSlot.Confidence;

    Result := Min(Result, LValue);
  end;
end;

function TIntentClarifier.BuildRuleResult(
  const ARequest: TIntentClarificationRequest): TIntentClarificationResult;
var
  LMissing: TList<string>;
  LFirstMissing: TIntentClarificationSlot;
  LFoundMissing: Boolean;
  LSlot: TIntentClarificationSlot;
begin
  Result := Default(TIntentClarificationResult);
  Result.IntentName := ARequest.IntentName;
  Result.Source := 'rule';
  Result.SelectionMode := csmFreeText;
  CopySlots(ARequest.Slots, Result.Slots);
  Result.Confidence := CalculateConfidence(ARequest.Slots);

  LMissing := TList<string>.Create;
  try
    LFoundMissing := False;
    LFirstMissing.Init;

    for LSlot in ARequest.Slots do
    begin
      if not LSlot.IsSatisfied(FPolicy.MinSlotConfidence) then
      begin
        LMissing.Add(LSlot.Name);
        if not LFoundMissing then
        begin
          LFirstMissing := LSlot;
          LFoundMissing := True;
        end;
      end;
    end;

    Result.MissingSlots := LMissing.ToArray;

    if LMissing.Count = 0 then
    begin
      Result.Status := icsReady;
      if Result.Confidence <= 0 then
        Result.Confidence := 1.0;
      Exit;
    end;

    Result.Status := icsNeedsClarification;
    Result.Question := LFirstMissing.Question;
    if Trim(Result.Question) = '' then
      Result.Question := 'Please clarify ' + LFirstMissing.EffectiveName + '.';
    Result.Options := TrimOptions(LFirstMissing.Options, FPolicy.MaxOptions);
    if Length(Result.Options) > 0 then
      Result.SelectionMode := csmSingleChoice
    else
      Result.SelectionMode := csmFreeText;
  finally
    LMissing.Free;
  end;
end;

function TIntentClarifier.BuildLLMSystemPrompt: string;
begin
  Result :=
    'You are an intent clarification engine for a Delphi application framework.' + sLineBreak +
    'Decide whether the user intent has enough required information to run.' + sLineBreak +
    'Return one strict JSON object only, with fields:' + sLineBreak +
    '{' + sLineBreak +
    '  "intent": "intent name",' + sLineBreak +
    '  "confidence": 0.0,' + sLineBreak +
    '  "needs_clarification": true,' + sLineBreak +
    '  "question": "one concise follow-up question, empty when ready",' + sLineBreak +
    '  "selection_mode": "free_text|single_choice|multi_choice",' + sLineBreak +
    '  "missing_slots": ["slot_name"],' + sLineBreak +
    '  "slots": [{"name":"slot","value":"value","confidence":0.0}],' + sLineBreak +
    '  "options": [{"code":"A","text":"label","value":"value"}]' + sLineBreak +
    '}' + sLineBreak +
    'Ask at most one follow-up question. Prefer provided options when useful.';
end;

function TIntentClarifier.BuildLLMUserPrompt(
  const ARequest: TIntentClarificationRequest): string;
var
  LRoot: TJSONObject;
  LSlots: TJSONArray;
  LSlotObj: TJSONObject;
  LTurns: TJSONArray;
  LSlot: TIntentClarificationSlot;
  LTurn: string;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('session_id', ARequest.SessionId);
    LRoot.AddPair('intent', ARequest.IntentName);
    LRoot.AddPair('user_text', ARequest.UserText);
    LRoot.AddPair('locale', ARequest.Locale);
    LRoot.AddPair('domain', ARequest.Domain);
    LRoot.AddPair('context_summary', ARequest.ContextSummary);
    LRoot.AddPair('anchor_question', ARequest.AnchorQuestion);

    LSlots := TJSONArray.Create;
    for LSlot in ARequest.Slots do
    begin
      LSlotObj := TJSONObject.Create;
      LSlotObj.AddPair('name', LSlot.Name);
      LSlotObj.AddPair('display_name', LSlot.DisplayName);
      LSlotObj.AddPair('value', LSlot.Value);
      LSlotObj.AddPair('required', TJSONBool.Create(LSlot.Required));
      LSlotObj.AddPair('confidence', TJSONNumber.Create(LSlot.Confidence));
      LSlotObj.AddPair('question', LSlot.Question);
      LSlotObj.AddPair('options', BuildOptionsJson(LSlot.Options));
      LSlots.AddElement(LSlotObj);
    end;
    LRoot.AddPair('slots', LSlots);

    LTurns := TJSONArray.Create;
    for LTurn in ARequest.RecentTurns do
      LTurns.Add(LTurn);
    LRoot.AddPair('recent_turns', LTurns);

    Result := LRoot.ToJSON;
    if (FPolicy.MaxPromptChars > 0) and
       (Length(Result) > FPolicy.MaxPromptChars) then
      Result := Copy(Result, 1, FPolicy.MaxPromptChars);
  finally
    LRoot.Free;
  end;
end;

function TIntentClarifier.TryParseLLMJson(const AJson: string;
  const ARequest: TIntentClarificationRequest;
  out AResult: TIntentClarificationResult): Boolean;
var
  LRoot: TJSONObject;
  LText: string;
  LNeedsClarification: Boolean;
  LSlotsValue: TJSONValue;
  LMissingValue: TJSONValue;
  LOptionsValue: TJSONValue;
begin
  Result := False;
  AResult := Default(TIntentClarificationResult);
  AResult.RawResponse := AJson;
  AResult.Source := 'llm';
  AResult.IntentName := ARequest.IntentName;
  AResult.SelectionMode := csmFreeText;
  CopySlots(ARequest.Slots, AResult.Slots);

  LText := NormalizeJsonObjectText(AJson);
  LRoot := TJSONObject.ParseJSONValue(LText) as TJSONObject;
  if LRoot = nil then
    Exit;

  try
    AResult.IntentName := FirstText(JsonString(LRoot, 'intent', ''),
      ARequest.IntentName);
    AResult.Confidence := JsonFloat(LRoot, 'confidence', 1.0);
    AResult.Question := JsonString(LRoot, 'question', '');
    AResult.SelectionMode := StringToSelectionMode(
      JsonString(LRoot, 'selection_mode', 'free_text'));

    LMissingValue := LRoot.GetValue('missing_slots');
    if LMissingValue is TJSONArray then
      AResult.MissingSlots := ParseMissingSlots(LMissingValue as TJSONArray);

    LOptionsValue := LRoot.GetValue('options');
    if LOptionsValue is TJSONArray then
      AResult.Options := ParseOptions(LOptionsValue as TJSONArray,
        FPolicy.MaxOptions);

    LSlotsValue := LRoot.GetValue('slots');
    if LSlotsValue = nil then
      LSlotsValue := LRoot.GetValue('filled_slots');
    if LSlotsValue is TJSONArray then
      AResult.Slots := ParseSlots(LSlotsValue as TJSONArray, ARequest);

    LNeedsClarification := JsonBool(LRoot, 'needs_clarification',
      Length(AResult.MissingSlots) > 0);
    if LNeedsClarification then
      AResult.Status := icsNeedsClarification
    else
      AResult.Status := icsReady;

    if (AResult.Status = icsNeedsClarification) and
       (Trim(AResult.Question) = '') then
      Exit(False);

    if (AResult.Status = icsReady) and
       (AResult.Confidence < FPolicy.MinIntentConfidence) then
      Exit(False);

    if (AResult.SelectionMode = csmFreeText) and
       (Length(AResult.Options) > 0) then
      AResult.SelectionMode := csmSingleChoice;

    Result := True;
  finally
    LRoot.Free;
  end;
end;

function TIntentClarifier.TryClarifyWithLLM(
  const ARequest: TIntentClarificationRequest;
  out AResult: TIntentClarificationResult): Boolean;
var
  LChat: TChatResult;
begin
  Result := False;
  AResult := Default(TIntentClarificationResult);

  if FLLM = nil then
    Exit;

  LChat := FLLM.Chat(FPolicy.ModelTier, BuildLLMSystemPrompt,
    BuildLLMUserPrompt(ARequest));
  if not LChat.Success then
  begin
    AResult.Status := icsFailed;
    AResult.Source := 'llm';
    AResult.ErrorCode := LChat.ErrorCode;
    AResult.ErrorMessage := LChat.ErrorMessage;
    Exit(False);
  end;

  Result := TryParseLLMJson(LChat.Content, ARequest, AResult);
  if not Result then
  begin
    AResult.Status := icsFailed;
    AResult.Source := 'llm';
    AResult.ErrorCode := 'bad_llm_json';
    AResult.ErrorMessage := 'LLM response was not a usable clarification JSON object';
    AResult.RawResponse := LChat.Content;
  end;
end;

function TIntentClarifier.Clarify(
  const ARequest: TIntentClarificationRequest): TIntentClarificationResult;
var
  LLLMResult: TIntentClarificationResult;
begin
  if FPolicy.UseLLM and (FLLM <> nil) then
  begin
    if TryClarifyWithLLM(ARequest, LLLMResult) then
      Exit(LLLMResult);

    Result := BuildRuleResult(ARequest);
    Result.Source := 'rule_fallback';
    Result.ErrorCode := LLLMResult.ErrorCode;
    Result.ErrorMessage := LLLMResult.ErrorMessage;
    Result.RawResponse := LLLMResult.RawResponse;
    Exit;
  end;

  Result := BuildRuleResult(ARequest);
end;

class function TIntentClarifier.ApplyOptionAnswer(
  const ARequest: TIntentClarificationRequest; const ASlotName,
  AAnswer: string; out AUpdatedRequest: TIntentClarificationRequest): Boolean;
var
  I: Integer;
  LOption: TIntentClarificationOption;
  LAnswer: string;
begin
  AUpdatedRequest := ARequest;
  CopySlots(ARequest.Slots, AUpdatedRequest.Slots);
  Result := False;
  LAnswer := Trim(AAnswer);

  for I := 0 to High(AUpdatedRequest.Slots) do
  begin
    if not SameText(AUpdatedRequest.Slots[I].Name, ASlotName) then
      Continue;

    Result := True;
    for LOption in AUpdatedRequest.Slots[I].Options do
    begin
      if SameText(LOption.Code, LAnswer) or SameText(LOption.Value, LAnswer) or
         SameText(LOption.Text, LAnswer) then
      begin
        AUpdatedRequest.Slots[I].Value := FirstText(LOption.Value, LOption.Text);
        AUpdatedRequest.Slots[I].Confidence := 1.0;
        Exit;
      end;
    end;

    AUpdatedRequest.Slots[I].Value := LAnswer;
    if LAnswer <> '' then
      AUpdatedRequest.Slots[I].Confidence := 1.0;
    Exit;
  end;
end;

class function TIntentClarifier.SelectionModeToString(
  AMode: TClarificationSelectionMode): string;
begin
  case AMode of
    csmSingleChoice: Result := 'single_choice';
    csmMultiChoice: Result := 'multi_choice';
  else
    Result := 'free_text';
  end;
end;

class function TIntentClarifier.StringToSelectionMode(
  const AValue: string): TClarificationSelectionMode;
begin
  if SameText(AValue, 'single') or SameText(AValue, 'single_choice') then
    Result := csmSingleChoice
  else if SameText(AValue, 'multi') or SameText(AValue, 'multi_choice') then
    Result := csmMultiChoice
  else
    Result := csmFreeText;
end;

class function TIntentClarifier.CreateEngine: IInterface;
begin
  Result := TClarificationEngine.Create;
end;

class function TIntentClarifier.CreateEngineWithPreset(
  const APresetName: string): IInterface;
begin
  Result := TClarificationEngine.Create;
end;

end.
