{ ============================================================================
  DeepBase.Speech.Config
  ---------------------------------------------------------------------------
  Version     : 1.0
  Description : Speech configuration keys, defaults, and BCP-47 normalization.
                All config stored in ConfigDB settings table (no JSON files).
  ============================================================================ }

unit DeepBase.Speech.Config;

interface

uses
  System.SysUtils;

const
  // ASR
  SPEECH_CFG_ASR_BACKEND       = 'speech.asr.backend';        // sensevoice|auto|sapi|winrt|baidu
  SPEECH_CFG_ASR_LANGUAGE      = 'speech.asr.language';       // BCP-47: zh-CN, en-US
  SPEECH_CFG_ASR_MAX_SECONDS   = 'speech.asr.max_seconds';    // 30
  SPEECH_CFG_ASR_SILENCE_MS    = 'speech.asr.silence_timeout_ms'; // 3000

  // SenseVoice
  SPEECH_CFG_SV_MODEL_DIR      = 'speech.sensevoice.model_dir';
  SPEECH_CFG_SV_LANGUAGE       = 'speech.sensevoice.language'; // auto|zh|en|yue|ko
  SPEECH_CFG_SV_USE_ITN        = 'speech.sensevoice.use_itn';  // 0|1
  SPEECH_CFG_SV_PARTIAL_MS     = 'speech.sensevoice.partial_interval_ms';

  // TTS
  SPEECH_CFG_TTS_BACKEND       = 'speech.tts.backend';        // sapi|azure
  SPEECH_CFG_TTS_LANGUAGE      = 'speech.tts.language';       // zh-CN
  SPEECH_CFG_TTS_VOICE         = 'speech.tts.voice';          // auto or specific token
  SPEECH_CFG_TTS_RATE          = 'speech.tts.rate';           // -10..10
  SPEECH_CFG_TTS_VOLUME        = 'speech.tts.volume';         // 0..100

  // WakeWord
  SPEECH_CFG_WAKE_ENABLED      = 'speech.wake_word.enabled';  // 0|1
  SPEECH_CFG_WAKE_WORDS        = 'speech.wake_word.words';    // comma-separated
  SPEECH_CFG_WAKE_THRESHOLD    = 'speech.wake_word.threshold';// 0.7
  SPEECH_CFG_WAKE_BUFFER_MS    = 'speech.wake_word.buffer_ms';// 500

  // Voiceprint
  SPEECH_CFG_VP_ENABLED        = 'speech.voiceprint.enabled'; // 0|1

  // Intent
  SPEECH_CFG_INTENT_LLM_ENABLED = 'speech.intent.llm_enabled'; // 0|1
  SPEECH_CFG_INTENT_LLM_TIMEOUT = 'speech.intent.llm_timeout_ms'; // 5000

  // Trace
  SPEECH_CFG_TRACE_AUDIO       = 'speech.trace.audio_payload_enabled'; // 0

  // Defaults
  SPEECH_DEFAULT_ASR_BACKEND   = 'sensevoice';
  SPEECH_DEFAULT_SV_MODEL_DIR  = '';
  SPEECH_DEFAULT_SV_LANGUAGE   = 'auto';
  SPEECH_DEFAULT_SV_USE_ITN    = '1';
  SPEECH_DEFAULT_SV_PARTIAL_MS = 500;
  SPEECH_DEFAULT_ASR_LANGUAGE  = 'zh-CN';
  SPEECH_DEFAULT_ASR_MAX_SEC   = 30;
  SPEECH_DEFAULT_ASR_SILENCE   = 3000;
  SPEECH_DEFAULT_TTS_BACKEND   = 'sapi';
  SPEECH_DEFAULT_TTS_LANGUAGE  = 'zh-CN';
  SPEECH_DEFAULT_TTS_RATE      = 0;
  SPEECH_DEFAULT_TTS_VOLUME    = 100;
  SPEECH_DEFAULT_WAKE_THRESHOLD = 0.7;
  SPEECH_DEFAULT_WAKE_BUFFER   = 500;
  SPEECH_DEFAULT_INTENT_TIMEOUT = 5000;

type
  /// <summary>
  /// BCP-47 language tag normalization.
  /// Accepts: zh-CN, zh-Hans-CN, zh_CN, en-US, en_US
  /// Rejects: bare 'zh' or 'en' (ambiguous)
  /// </summary>
  TSpeechLangHelper = class
  public
    /// Normalize a language tag to BCP-47 format (e.g. 'zh-CN').
    /// Raises EArgumentException if tag is ambiguous or invalid.
    class function Normalize(const ATag: string): string;

    /// Check if a tag is valid without raising.
    class function IsValid(const ATag: string): Boolean;

    /// Extract primary language (e.g. 'zh' from 'zh-CN').
    class function PrimaryLanguage(const ATag: string): string;

    /// Extract region (e.g. 'CN' from 'zh-CN'). Empty if no region.
    class function Region(const ATag: string): string;
  end;

implementation

class function TSpeechLangHelper.Normalize(const ATag: string): string;
var
  LTag, LPrimary, LRegion: string;
  LParts: TArray<string>;
begin
  LTag := Trim(ATag);
  if LTag = '' then
    raise EArgumentException.Create('Speech language tag cannot be empty');

  // Replace underscore with hyphen
  LTag := LTag.Replace('_', '-');

  // Split by hyphen
  LParts := LTag.Split(['-']);

  if Length(LParts) = 1 then
    raise EArgumentException.CreateFmt(
      'Ambiguous language tag "%s": must include region (e.g. zh-CN, en-US)', [ATag]);

  LPrimary := LowerCase(LParts[0]);

  // Handle zh-Hans-CN → zh-CN (skip script subtag)
  if Length(LParts) = 3 then
    LRegion := UpperCase(LParts[2])
  else if Length(LParts) = 2 then
  begin
    // Could be 'zh-CN' or 'zh-Hans'
    if Length(LParts[1]) = 2 then
      LRegion := UpperCase(LParts[1])
    else if Length(LParts[1]) = 4 then
      // Script subtag without region — ambiguous
      raise EArgumentException.CreateFmt(
        'Language tag "%s" has script but no region (e.g. use zh-Hans-CN)', [ATag])
    else
      LRegion := UpperCase(LParts[1]);
  end
  else
    raise EArgumentException.CreateFmt('Invalid language tag format: "%s"', [ATag]);

  if (Length(LPrimary) < 2) or (Length(LPrimary) > 3) then
    raise EArgumentException.CreateFmt('Invalid primary language: "%s"', [LPrimary]);

  if (LRegion <> '') and (Length(LRegion) <> 2) then
    raise EArgumentException.CreateFmt('Invalid region subtag: "%s"', [LRegion]);

  Result := LPrimary + '-' + LRegion;
end;

class function TSpeechLangHelper.IsValid(const ATag: string): Boolean;
begin
  try
    Normalize(ATag);
    Result := True;
  except
    Result := False;
  end;
end;

class function TSpeechLangHelper.PrimaryLanguage(const ATag: string): string;
var
  LNorm: string;
begin
  LNorm := Normalize(ATag);
  Result := Copy(LNorm, 1, Pos('-', LNorm) - 1);
end;

class function TSpeechLangHelper.Region(const ATag: string): string;
var
  LNorm: string;
  LPos: Integer;
begin
  LNorm := Normalize(ATag);
  LPos := Pos('-', LNorm);
  if LPos > 0 then
    Result := Copy(LNorm, LPos + 1, MaxInt)
  else
    Result := '';
end;

end.
