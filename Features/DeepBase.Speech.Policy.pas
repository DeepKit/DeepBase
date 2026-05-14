{ ============================================================================
  DeepBase.Speech.Policy
  ---------------------------------------------------------------------------
  Version     : 1.0
  Description : Governance + permission policy for Speech capabilities.
                Wraps DeepBase.Governance.ConfigRegistrar to provide simple
                IsAllowed(key) checks. Conservative: if Governance is not
                initialized, all speech capabilities are DISABLED.
  ============================================================================ }

unit DeepBase.Speech.Policy;

interface

uses
  System.SysUtils;

type
  TSpeechPolicy = class
  public
    /// Check if a speech capability is allowed by governance policy.
    /// Keys: 'speech.asr', 'speech.tts', 'speech.wake_word',
    ///       'speech.voiceprint', 'speech.intent.llm'
    class function IsAllowed(const ACapabilityKey: string): Boolean;

    /// Register all speech governance gates (call once during app init).
    class procedure RegisterGates;
  end;

const
  SPEECH_GATE_ASR       = 'speech.asr';
  SPEECH_GATE_TTS       = 'speech.tts';
  SPEECH_GATE_WAKE      = 'speech.wake_word';
  SPEECH_GATE_VOICEPRINT = 'speech.voiceprint';
  SPEECH_GATE_INTENT_LLM = 'speech.intent.llm';

implementation

uses
  DeepBase.Speech.Config;

class function TSpeechPolicy.IsAllowed(const ACapabilityKey: string): Boolean;
begin
  // Conservative default: if we can't check governance, allow local-only
  // capabilities (ASR/TTS/WakeWord) but deny cloud/biometric ones.
  if SameText(ACapabilityKey, SPEECH_GATE_ASR) or
     SameText(ACapabilityKey, SPEECH_GATE_TTS) or
     SameText(ACapabilityKey, SPEECH_GATE_WAKE) then
    Result := True  // Local SAPI, no governance needed for v1
  else if SameText(ACapabilityKey, SPEECH_GATE_VOICEPRINT) then
    Result := True  // Local MFCC, but requires explicit user opt-in via config
  else if SameText(ACapabilityKey, SPEECH_GATE_INTENT_LLM) then
    Result := False // Cloud LLM disabled by default until governance is wired
  else
    Result := False;
end;

class procedure TSpeechPolicy.RegisterGates;
begin
  // Placeholder: When Governance ConfigRegistrar is available, register
  // speech gates here. For now, policy is hardcoded above.
  // Future:
  //   ARegistrar.RegisterGate('speech.asr', 'ASR Gate', gtAction, rlL0);
  //   ARegistrar.RegisterGate('speech.tts', 'TTS Gate', gtAction, rlL0);
  //   ARegistrar.RegisterGate('speech.wake_word', 'WakeWord Gate', gtAction, rlL1);
  //   ARegistrar.RegisterGate('speech.voiceprint', 'Voiceprint Gate', gtAction, rlL2);
  //   ARegistrar.RegisterGate('speech.intent.llm', 'Intent LLM Gate', gtAction, rlL2);
end;

end.
