unit DeepBase.IntentClarification.Provider.L1;

interface

uses
  System.SysUtils,
  DeepBase.IntentClarification.Types,
  DeepBase.IntentClarification.Interfaces,
  DeepBase.IntentClarification;

type
  /// <summary>
  /// L1 槽位填充处理器 - 委托给现有 TIntentClarifier，零 LLM 依赖。
  /// 将 TProcessingContext 转换为 TIntentClarificationRequest，
  /// 调用 TIntentClarifier.Clarify，再将结果转换回 TProviderResult。
  /// Requirements: 4.1, 4.2
  /// </summary>
  TL1SlotProvider = class(TInterfacedObject, ILevelProvider)
  private
    FClarifier: TIntentClarifier;
    FOwnsInstance: Boolean;

    function BuildRequest(const AContext: TProcessingContext): TIntentClarificationRequest;
    function ConvertResult(const AResult: TIntentClarificationResult): TProviderResult;
  public
    /// <summary>
    /// Creates the L1 provider. If AClarifier is nil, a default instance
    /// (rule-only, no LLM) is created and owned internally.
    /// </summary>
    constructor Create(AClarifier: TIntentClarifier = nil);
    destructor Destroy; override;

    { ILevelProvider }
    function GetLevel: TClarificationLevel;
    function CanHandle(const AContext: TProcessingContext): Boolean;
    function Process(const AContext: TProcessingContext): TProviderResult;
    function RequiresLLM: Boolean;

    property Clarifier: TIntentClarifier read FClarifier;
  end;

implementation

uses
  System.Math;

{ TL1SlotProvider }

constructor TL1SlotProvider.Create(AClarifier: TIntentClarifier);
var
  LPolicy: TIntentClarificationPolicy;
begin
  inherited Create;
  if AClarifier <> nil then
  begin
    FClarifier := AClarifier;
    FOwnsInstance := False;
  end
  else
  begin
    FClarifier := TIntentClarifier.Create;
    // Force rule-only mode to guarantee zero LLM dependency
    LPolicy := TIntentClarificationPolicy.Default;
    LPolicy.UseLLM := False;
    FClarifier.Policy := LPolicy;
    FOwnsInstance := True;
  end;
end;

destructor TL1SlotProvider.Destroy;
begin
  if FOwnsInstance then
    FClarifier.Free;
  inherited;
end;

function TL1SlotProvider.GetLevel: TClarificationLevel;
begin
  Result := clL1;
end;

function TL1SlotProvider.RequiresLLM: Boolean;
begin
  Result := False;
end;

function TL1SlotProvider.CanHandle(const AContext: TProcessingContext): Boolean;
begin
  // L1 handles when context depth is in [0.2, 0.4) range
  Result := (AContext.Depth >= 0.2) and (AContext.Depth < 0.4);
end;

function TL1SlotProvider.BuildRequest(
  const AContext: TProcessingContext): TIntentClarificationRequest;
var
  I: Integer;
  LSlot: TIntentClarificationSlot;
  LSlots: TArray<TIntentClarificationSlot>;
begin
  Result.Init;
  Result.SessionId := AContext.SessionId;
  Result.IntentName := AContext.DomainContext.ActiveIntent;
  Result.UserText := AContext.UserInput;
  Result.Domain := AContext.DomainContext.DomainName;
  Result.ContextSummary := AContext.DomainContext.ContextSummary;

  // Convert history to recent turns
  SetLength(Result.RecentTurns, Length(AContext.History));
  for I := 0 to High(AContext.History) do
    Result.RecentTurns[I] := AContext.History[I].UserInput;

  // Use domain context slots if available via metadata
  // (The actual slots come from the DomainAdapter's GetPresetSlots in the engine)
  // For now, pass empty slots - the engine layer populates them before calling Process
end;

function TL1SlotProvider.ConvertResult(
  const AResult: TIntentClarificationResult): TProviderResult;
var
  I: Integer;
  LOption: TOptionItem;
  LOptions: TArray<TOptionItem>;
begin
  Result := Default(TProviderResult);
  Result.Source := 'rule';

  case AResult.Status of
    icsReady:
    begin
      Result.Success := True;
      Result.Question := '';
      // Intent is fully resolved
    end;
    icsNeedsClarification:
    begin
      Result.Success := True;
      Result.Question := AResult.Question;
    end;
    icsFailed:
    begin
      Result.Success := False;
      Result.ErrorMessage := AResult.ErrorMessage;
      Exit;
    end;
  end;

  // Convert options from TIntentClarificationOption to TOptionItem
  SetLength(LOptions, Min(Length(AResult.Options), 8));
  for I := 0 to High(LOptions) do
  begin
    LOption.Number := I + 1;
    LOption.Text := AResult.Options[I].Text;
    LOption.Value := AResult.Options[I].Value;
    LOption.IsRecommended := (I = 0); // First option is recommended by default
    LOptions[I] := LOption;
  end;
  Result.Options := LOptions;

  if Length(LOptions) > 0 then
    Result.RecommendedOption := 1;
end;

function TL1SlotProvider.Process(const AContext: TProcessingContext): TProviderResult;
var
  LRequest: TIntentClarificationRequest;
  LClarifyResult: TIntentClarificationResult;
begin
  LRequest := BuildRequest(AContext);
  LClarifyResult := FClarifier.Clarify(LRequest);
  Result := ConvertResult(LClarifyResult);
end;

end.
