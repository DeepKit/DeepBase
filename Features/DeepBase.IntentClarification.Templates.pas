{ ============================================================================
  DeepBase.IntentClarification.Templates - Preset Template Manager

  Manages loading, validation, and override of preset templates
  (ToolCommand, CreativeAssistant, DecisionAdvisor).

  Design Properties:
    - Property 38: Override preserves non-overridden values
    - Property 39: Validation reports missing required fields

  Requirements: 13.1-13.5
  ============================================================================ }

unit DeepBase.IntentClarification.Templates;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  DeepBase.IntentClarification.Types;

type
  /// <summary>
  /// Manages preset template loading, validation, and configuration overrides.
  /// </summary>
  TPresetTemplateManager = class
  private
    const
      CRequiredFields: array[0..4] of string = (
        'Name', 'MaxLevel', 'Style', 'BudgetConfig.MaxTurns',
        'BudgetConfig.MaxTimeSeconds'
      );
  public
    /// <summary>
    /// Loads a preset template by name.
    /// Supported names: 'tool-command', 'creative-assistant', 'decision-advisor'.
    /// Raises EArgumentException for unknown names.
    /// </summary>
    function LoadTemplate(const AName: string): TPresetTemplate;

    /// <summary>
    /// Validates a template and returns a list of missing required field names.
    /// Returns empty array if template is valid.
    /// Property 39: validation reports missing required fields.
    /// </summary>
    function ValidateTemplate(const ATemplate: TPresetTemplate): TArray<string>;

    /// <summary>
    /// Applies a single field override to a template and returns the modified copy.
    /// Property 38: non-overridden fields retain their original values.
    /// Supported fields: 'Name', 'MaxLevel', 'Style', 'EnableAnticipation',
    ///   'EnablePersonas', 'PersonaPack', 'DefaultPosture',
    ///   'BudgetConfig.MaxTurns', 'BudgetConfig.MaxTimeSeconds',
    ///   'BudgetConfig.MaxCognitiveLoad', 'BudgetConfig.UserPatienceThreshold'.
    /// </summary>
    function ApplyOverride(const ATemplate: TPresetTemplate;
      const AField, AValue: string): TPresetTemplate;
  end;

implementation

uses
  System.StrUtils;

{ TPresetTemplateManager }

function TPresetTemplateManager.LoadTemplate(const AName: string): TPresetTemplate;
begin
  if SameText(AName, 'tool-command') then
    Result := TPresetTemplate.ToolCommand
  else if SameText(AName, 'creative-assistant') then
    Result := TPresetTemplate.CreativeAssistant
  else if SameText(AName, 'decision-advisor') then
    Result := TPresetTemplate.DecisionAdvisor
  else
    raise EArgumentException.CreateFmt('Unknown template name: "%s"', [AName]);
end;

function TPresetTemplateManager.ValidateTemplate(
  const ATemplate: TPresetTemplate): TArray<string>;
var
  LMissing: TList<string>;
begin
  LMissing := TList<string>.Create;
  try
    if Trim(ATemplate.Name) = '' then
      LMissing.Add('Name');

    if Trim(ATemplate.Style) = '' then
      LMissing.Add('Style');

    if ATemplate.BudgetConfig.MaxTurns <= 0 then
      LMissing.Add('BudgetConfig.MaxTurns');

    if ATemplate.BudgetConfig.MaxTimeSeconds <= 0 then
      LMissing.Add('BudgetConfig.MaxTimeSeconds');

    Result := LMissing.ToArray;
  finally
    LMissing.Free;
  end;
end;

function TPresetTemplateManager.ApplyOverride(const ATemplate: TPresetTemplate;
  const AField, AValue: string): TPresetTemplate;
begin
  // Start with a copy - all non-overridden fields are preserved (Property 38)
  Result := ATemplate;

  if SameText(AField, 'Name') then
    Result.Name := AValue
  else if SameText(AField, 'Style') then
    Result.Style := AValue
  else if SameText(AField, 'PersonaPack') then
    Result.PersonaPack := AValue
  else if SameText(AField, 'MaxLevel') then
    Result.MaxLevel := TClarificationLevel(StrToIntDef(AValue, Ord(ATemplate.MaxLevel)))
  else if SameText(AField, 'DefaultPosture') then
    Result.DefaultPosture := TPosture(StrToIntDef(AValue, Ord(ATemplate.DefaultPosture)))
  else if SameText(AField, 'EnableAnticipation') then
    Result.EnableAnticipation := SameText(AValue, 'true') or (AValue = '1')
  else if SameText(AField, 'EnablePersonas') then
    Result.EnablePersonas := SameText(AValue, 'true') or (AValue = '1')
  else if SameText(AField, 'BudgetConfig.MaxTurns') then
    Result.BudgetConfig.MaxTurns := StrToIntDef(AValue, ATemplate.BudgetConfig.MaxTurns)
  else if SameText(AField, 'BudgetConfig.MaxTimeSeconds') then
    Result.BudgetConfig.MaxTimeSeconds := StrToIntDef(AValue, ATemplate.BudgetConfig.MaxTimeSeconds)
  else if SameText(AField, 'BudgetConfig.MaxCognitiveLoad') then
    Result.BudgetConfig.MaxCognitiveLoad := StrToIntDef(AValue, ATemplate.BudgetConfig.MaxCognitiveLoad)
  else if SameText(AField, 'BudgetConfig.UserPatienceThreshold') then
    Result.BudgetConfig.UserPatienceThreshold := StrToFloatDef(AValue, ATemplate.BudgetConfig.UserPatienceThreshold);
end;

end.
