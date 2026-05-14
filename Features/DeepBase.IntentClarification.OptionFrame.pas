unit DeepBase.IntentClarification.OptionFrame;

interface

uses
  System.SysUtils,
  System.Math,
  DeepBase.IntentClarification.Types;

type
  /// <summary>
  /// Builds and validates the 0-9 option framework for user interaction.
  /// Options 1-8: substantive choices (max 8, exactly one recommended)
  /// Option 9: regenerate with different angle
  /// Option 0: layered exit (sub-topic -> parent -> full exit)
  /// </summary>
  TOptionFrameBuilder = class
  public
    /// <summary>
    /// Build options from raw candidates, truncate to max 8, mark recommended.
    /// If ARecommendedIndex is out of range, defaults to first option.
    /// </summary>
    class function BuildOptions(const ACandidates: TArray<TOptionItem>;
      ARecommendedIndex: Integer): TArray<TOptionItem>; static;

    /// <summary>
    /// Generate progress hint message for the current turn.
    /// Message is always non-empty.
    /// </summary>
    class function BuildProgressHint(ATurnNumber, AEstimatedRemaining: Integer): TProgressHint; static;

    /// <summary>
    /// Check if input is a special command (0 or 9).
    /// </summary>
    class function IsSpecialInput(const AInput: string): Boolean; static;

    /// <summary>
    /// Check if input is the cancel/exit command (0).
    /// </summary>
    class function IsCancelInput(const AInput: string): Boolean; static;

    /// <summary>
    /// Check if input is the regenerate command (9).
    /// </summary>
    class function IsRegenerateInput(const AInput: string): Boolean; static;

    /// <summary>
    /// Parse numeric option selection from input.
    /// Returns the number if input is 1-8, otherwise returns 0.
    /// </summary>
    class function ParseOptionSelection(const AInput: string): Integer; static;

    /// <summary>
    /// Ensure at least one option exists and exactly one is recommended.
    /// If options are empty, creates a default option.
    /// If ARecommendedIndex is out of range, recommends the first option.
    /// </summary>
    class function EnsureValidFrame(const AOptions: TArray<TOptionItem>;
      ARecommendedIndex: Integer): TArray<TOptionItem>; static;
  end;

const
  /// Maximum number of substantive options (1-8)
  MAX_OPTIONS = 8;

  /// Special input: regenerate
  INPUT_REGENERATE = '9';

  /// Special input: cancel/exit
  INPUT_CANCEL = '0';

implementation

{ TOptionFrameBuilder }

class function TOptionFrameBuilder.BuildOptions(
  const ACandidates: TArray<TOptionItem>;
  ARecommendedIndex: Integer): TArray<TOptionItem>;
var
  LCount: Integer;
  I: Integer;
  LRecIdx: Integer;
begin
  if Length(ACandidates) = 0 then
  begin
    // Return a single default option when no candidates provided
    SetLength(Result, 1);
    Result[0].Number := 1;
    Result[0].Text := '继续';
    Result[0].Value := 'continue';
    Result[0].IsRecommended := True;
    Exit;
  end;

  // Truncate to max 8 options (Requirement 3.7)
  LCount := Min(Length(ACandidates), MAX_OPTIONS);
  SetLength(Result, LCount);

  // Clamp recommended index to valid range
  LRecIdx := ARecommendedIndex;
  if (LRecIdx < 0) or (LRecIdx >= LCount) then
    LRecIdx := 0;

  // Copy candidates, assign sequential numbers, set recommended flag
  for I := 0 to LCount - 1 do
  begin
    Result[I] := ACandidates[I];
    Result[I].Number := I + 1;  // Numbers 1-8
    Result[I].IsRecommended := (I = LRecIdx);
  end;
end;

class function TOptionFrameBuilder.BuildProgressHint(
  ATurnNumber, AEstimatedRemaining: Integer): TProgressHint;
begin
  Result.CurrentTurn := ATurnNumber;
  Result.EstimatedRemaining := Max(AEstimatedRemaining, 0);

  // Generate non-empty message (Property 11: ProgressHint.Message is always non-empty)
  if AEstimatedRemaining <= 0 then
    Result.Message := Format('第 %d 轮，即将完成', [ATurnNumber])
  else if AEstimatedRemaining = 1 then
    Result.Message := Format('第 %d 轮/再问一个问题就可以开始了', [ATurnNumber])
  else
    Result.Message := Format('第 %d 轮/预计还需 %d 轮', [ATurnNumber, AEstimatedRemaining]);
end;

class function TOptionFrameBuilder.IsSpecialInput(const AInput: string): Boolean;
var
  LTrimmed: string;
begin
  LTrimmed := Trim(AInput);
  Result := (LTrimmed = INPUT_CANCEL) or (LTrimmed = INPUT_REGENERATE);
end;

class function TOptionFrameBuilder.IsCancelInput(const AInput: string): Boolean;
begin
  Result := Trim(AInput) = INPUT_CANCEL;
end;

class function TOptionFrameBuilder.IsRegenerateInput(const AInput: string): Boolean;
begin
  Result := Trim(AInput) = INPUT_REGENERATE;
end;

class function TOptionFrameBuilder.ParseOptionSelection(const AInput: string): Integer;
var
  LValue: Integer;
begin
  Result := 0;
  if TryStrToInt(Trim(AInput), LValue) then
  begin
    if (LValue >= 1) and (LValue <= MAX_OPTIONS) then
      Result := LValue;
  end;
end;

class function TOptionFrameBuilder.EnsureValidFrame(
  const AOptions: TArray<TOptionItem>;
  ARecommendedIndex: Integer): TArray<TOptionItem>;
var
  I: Integer;
  LRecIdx: Integer;
  LHasRecommended: Boolean;
begin
  if Length(AOptions) = 0 then
  begin
    // Must have at least one option (Property 9: count in [1, 8])
    SetLength(Result, 1);
    Result[0].Number := 1;
    Result[0].Text := '继续';
    Result[0].Value := 'continue';
    Result[0].IsRecommended := True;
    Exit;
  end;

  // Copy options, truncate if needed
  if Length(AOptions) > MAX_OPTIONS then
  begin
    SetLength(Result, MAX_OPTIONS);
    for I := 0 to MAX_OPTIONS - 1 do
      Result[I] := AOptions[I];
  end
  else
  begin
    SetLength(Result, Length(AOptions));
    for I := 0 to Length(AOptions) - 1 do
      Result[I] := AOptions[I];
  end;

  // Ensure sequential numbering
  for I := 0 to Length(Result) - 1 do
    Result[I].Number := I + 1;

  // Ensure exactly one recommended (Property 9)
  LRecIdx := ARecommendedIndex;
  if (LRecIdx < 0) or (LRecIdx >= Length(Result)) then
  begin
    // Check if any option is already marked recommended
    LHasRecommended := False;
    for I := 0 to Length(Result) - 1 do
    begin
      if Result[I].IsRecommended then
      begin
        LHasRecommended := True;
        LRecIdx := I;
        Break;
      end;
    end;
    if not LHasRecommended then
      LRecIdx := 0;
  end;

  // Clear all recommended flags, then set exactly one
  for I := 0 to Length(Result) - 1 do
    Result[I].IsRecommended := (I = LRecIdx);
end;

end.
