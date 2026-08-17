{ ============================================================================
  DeepBase.Desktop.Perception.LLMProvider
  ---------------------------------------------------------------------------
  Version     : 0.1 (Unstable API)
  Description : IDesktopVisionProvider backed by DeepBase LLM().ChatVision.
                Sends a screenshot to the configured vision-tier model with a
                neutral system prompt that asks for UI elements and their
                screen coordinates as JSON. The prompt is deliberately
                business-agnostic: it asks for generic desktop UI elements,
                never names any application or domain.
                When LLM is not configured (IsConfigured=False), IsAvailable
                returns False and the engine degrades to screenshot-only.
  ========================================================================== }

unit DeepBase.Desktop.Perception.LLMProvider;

interface

uses
  System.SysUtils,
  System.Types,
  System.JSON,
  System.SyncObjs,
  DeepBase.Logging,
  DeepBase.LLM.Client,
  DeepBase.LLM.Types,
  DeepBase.LLM.Service,
  DeepBase.Desktop.Perception.Types;

type
  TLLMVisionProvider = class(TInterfacedObject, IDesktopVisionProvider)
  private
    FTier: TModelTier;
    FLock: TCriticalSection;
    FSystemPrompt: string;
    FClient: ILLMClient;
    function BuildSystemPrompt: string;
    function ParseElements(const AJson: string;
      out AElements: TPerceivedElementArray): Boolean;
    function ParseElement(const AObj: TJSONObject;
      out AElement: TPerceivedElement): Boolean;
    function GetClient: ILLMClient;
  public
    constructor Create(const ATier: TModelTier;
      const AClient: ILLMClient = nil);
    function Recognize(const AShot: TDesktopScreenshot;
      out AElements: TPerceivedElementArray): Boolean;
    function FindByLabel(const AShot: TDesktopScreenshot;
      const ALabel: string; out AElement: TPerceivedElement): Boolean;
    function IsAvailable: Boolean;
    function GetName: string;
  end;

const
  // Neutral recognition system prompt. No business semantics: it describes
  // generic desktop UI elements (buttons, inputs, labels) and a JSON output
  // contract. It must not name any application or domain.
  C_NEUTRAL_VISION_SYSTEM_PROMPT: string =
    'You are a desktop UI perception assistant. Given a screenshot, identify ' +
    'the visible interactive and informational elements (buttons, input ' +
    'fields, text labels, links, checkboxes, etc.). For each element return ' +
    'its visible text label (or a short neutral description if unlabeled), ' +
    'its bounding box in screen pixel coordinates (left, top, right, bottom), ' +
    'and a confidence score between 0 and 1. Respond ONLY with a JSON array, ' +
    'no prose. Schema per element: {"label": string, "left": int, "top": int, ' +
    '"right": int, "bottom": int, "confidence": number}. Coordinates must be ' +
    'absolute screen pixel positions within the image bounds.';

implementation

{ TLLMVisionProvider }

constructor TLLMVisionProvider.Create(const ATier: TModelTier;
  const AClient: ILLMClient);
begin
  inherited Create;
  FTier := ATier;
  FClient := AClient;
  FLock := TCriticalSection.Create;
  FSystemPrompt := BuildSystemPrompt;
  Logger.Info('LLM vision provider created, tier=' + string(ATier),
    'Perception.LLM');
end;

function TLLMVisionProvider.BuildSystemPrompt: string;
begin
  Result := C_NEUTRAL_VISION_SYSTEM_PROMPT;
end;

function TLLMVisionProvider.GetClient: ILLMClient;
begin
  if FClient <> nil then
    Result := FClient
  else
    Result := LLM;
end;

function TLLMVisionProvider.IsAvailable: Boolean;
var
  LClient: ILLMClient;
  LModel: string;
begin
  Result := False;
  LClient := GetClient;
  if LClient = nil then
    Exit;
  try
    // ILLMClient exposes no IsConfigured probe; use GetModelForTier: a
    // non-empty resolved model for the vision tier means the layer is wired
    // and the tier has a backing provider.
    LModel := LClient.GetModelForTier(FTier);
    Result := LModel <> '';
  except
    on E: Exception do
    begin
      Logger.Warn('LLM vision provider unavailable: ' + E.Message,
        'Perception.LLM');
      Result := False;
    end;
  end;
end;

function TLLMVisionProvider.GetName: string;
begin
  Result := 'llm-vision';
end;

function TLLMVisionProvider.ParseElement(const AObj: TJSONObject;
  out AElement: TPerceivedElement): Boolean;
var
  LLabel: string;
  LLeft, LTop, LRight, LBottom: Integer;
  LConf: Double;
begin
  Result := False;
  AElement := Default(TPerceivedElement);
  if AObj = nil then
    Exit;
  LLabel := AObj.GetValue<string>('label', '');
  LLeft := AObj.GetValue<Integer>('left', 0);
  LTop := AObj.GetValue<Integer>('top', 0);
  LRight := AObj.GetValue<Integer>('right', 0);
  LBottom := AObj.GetValue<Integer>('bottom', 0);
  LConf := AObj.GetValue<Double>('confidence', 0.5);
  if (LRight <= LLeft) or (LBottom <= LTop) then
    Exit;
  AElement.Label_ := LLabel;
  AElement.BoundingBox := Rect(LLeft, LTop, LRight, LBottom);
  AElement.Confidence := LConf;
  if AElement.Confidence < 0 then
    AElement.Confidence := 0;
  if AElement.Confidence > 1 then
    AElement.Confidence := 1;
  AElement.Source := psVision;
  Result := True;
end;

function TLLMVisionProvider.ParseElements(const AJson: string;
  out AElements: TPerceivedElementArray): Boolean;
var
  LJson: TJSONValue;
  LArr: TJSONArray;
  I: Integer;
  LElem: TPerceivedElement;
  LList: TArray<TPerceivedElement>;
begin
  Result := False;
  AElements := nil;
  LList := nil;
  try
    LJson := TJSONObject.ParseJSONValue(AJson);
    if LJson = nil then
      Exit;
    try
      if not (LJson is TJSONArray) then
      begin
        // Some models wrap the array in an object; try to unwrap.
        if LJson is TJSONObject then
          LJson := (LJson as TJSONObject).FindValue('elements');
        if not (LJson is TJSONArray) then
          Exit;
      end;
      LArr := LJson as TJSONArray;
      SetLength(LList, LArr.Count);
      I := 0;
      for var LItem in LArr do
      begin
        if (LItem is TJSONObject) and ParseElement(LItem as TJSONObject, LElem) then
        begin
          LList[I] := LElem;
          Inc(I);
        end;
      end;
      SetLength(LList, I);
      AElements := LList;
      Result := True;
    finally
      LJson.Free;
    end;
  except
    on E: Exception do
    begin
      Logger.Warn('LLM vision parse failed: ' + E.Message, 'Perception.LLM');
      Result := False;
    end;
  end;
end;

function TLLMVisionProvider.Recognize(const AShot: TDesktopScreenshot;
  out AElements: TPerceivedElementArray): Boolean;
var
  LClient: ILLMClient;
  LResult: TChatResult;
  LUserPrompt: string;
begin
  Result := False;
  AElements := nil;
  if not AShot.IsValid then
    Exit;
  LClient := GetClient;
  if LClient = nil then
    Exit;
  FLock.Enter;
  try
    LUserPrompt := 'Identify the visible desktop UI elements in this ' +
      'screenshot. Return the JSON array as specified.';
    LResult := LClient.ChatVision(FTier, AShot.ImageBase64, AShot.MimeType,
      LUserPrompt, FSystemPrompt);
    if not LResult.Success then
    begin
      Logger.Warn('LLM vision ChatVision failed: ' + LResult.ErrorMessage,
        'Perception.LLM');
      Exit;
    end;
    Result := ParseElements(LResult.Content, AElements);
  finally
    FLock.Leave;
  end;
end;

function TLLMVisionProvider.FindByLabel(const AShot: TDesktopScreenshot;
  const ALabel: string; out AElement: TPerceivedElement): Boolean;
var
  LElements: TPerceivedElementArray;
  I: Integer;
begin
  Result := False;
  if ALabel = '' then
    Exit;
  if not Recognize(AShot, LElements) then
    Exit;
  for I := 0 to High(LElements) do
  begin
    if SameText(LElements[I].Label_, ALabel) then
    begin
      AElement := LElements[I];
      Result := True;
      Break;
    end;
  end;
end;

end.
