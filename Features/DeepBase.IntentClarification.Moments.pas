{ ============================================================================
  DeepBase.IntentClarification.Moments - "Being Understood" Micro-Moments

  Generates echo confirmations, memory references, and expectation hints
  to create moments where the user feels understood and respected.

  Design Properties:
    - Property 40: EchoConfirmation always non-empty when user confirms intent

  Requirements: 15.1-15.4
  ============================================================================ }

unit DeepBase.IntentClarification.Moments;

interface

uses
  System.SysUtils,
  DeepBase.IntentClarification.Types;

type
  /// <summary>
  /// Generates "being understood" micro-moment messages:
  /// - Echo confirmation: rephrases user's confirmed intent in system's own words
  /// - Memory reference: references user's past statements from rapport history
  /// - Expectation hint: manages expectations about remaining interaction turns
  /// </summary>
  TMomentsGenerator = class
  public
    /// <summary>
    /// Generates an echo confirmation message when the user confirms an intent.
    /// Property 40: result is always non-empty when AUserInput is non-empty
    /// and AResolvedIntent is non-empty.
    /// Requirements: 15.1
    /// </summary>
    function GenerateEchoConfirmation(const AUserInput: string;
      const AResolvedIntent: string): string;

    /// <summary>
    /// Generates a memory reference message based on rapport history.
    /// Returns empty string if no relevant history is available.
    /// Requirements: 15.2
    /// </summary>
    function GenerateMemoryReference(const ARapport: TRapportProfile;
      const ACurrentTopic: string): string;

    /// <summary>
    /// Generates an expectation management hint based on remaining turns.
    /// Requirements: 15.4
    /// </summary>
    function GenerateExpectationHint(ATurnsRemaining: Integer): string;
  end;

implementation

{ TMomentsGenerator }

function TMomentsGenerator.GenerateEchoConfirmation(const AUserInput: string;
  const AResolvedIntent: string): string;
begin
  // Property 40: always non-empty when user confirms intent
  if (Trim(AUserInput) = '') or (Trim(AResolvedIntent) = '') then
  begin
    Result := '';
    Exit;
  end;

  Result := Format('Understood - you want to %s.', [AResolvedIntent]);
end;

function TMomentsGenerator.GenerateMemoryReference(const ARapport: TRapportProfile;
  const ACurrentTopic: string): string;
begin
  // Only generate memory reference if we have meaningful rapport data
  if (Trim(ARapport.UserId) = '') or (ARapport.Familiarity < 0.3) then
  begin
    Result := '';
    Exit;
  end;

  if Trim(ACurrentTopic) = '' then
  begin
    Result := '';
    Exit;
  end;

  // Generate a reference based on familiarity level
  if ARapport.Familiarity >= 0.7 then
    Result := Format('Based on our previous conversations about %s...', [ACurrentTopic])
  else
    Result := Format('Relating to %s from before...', [ACurrentTopic]);
end;

function TMomentsGenerator.GenerateExpectationHint(ATurnsRemaining: Integer): string;
begin
  if ATurnsRemaining <= 0 then
    Result := 'We have enough information to proceed.'
  else if ATurnsRemaining = 1 then
    Result := 'Just one more question and we can get started.'
  else if ATurnsRemaining <= 3 then
    Result := Format('About %d more questions to go.', [ATurnsRemaining])
  else
    Result := Format('Estimated %d more turns remaining.', [ATurnsRemaining]);
end;

end.
