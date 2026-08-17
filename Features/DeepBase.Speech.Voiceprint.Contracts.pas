{ ============================================================================
  DeepBase.Speech.Voiceprint.Contracts
  ---------------------------------------------------------------------------
  Version     : 1.0
  Description : Contract types for the voice profile storage subsystem.
                Lives in DeepBaseSpeechCore so both the Features-layer
                TDPAPIFileVoiceProfileStorage (TDPAPIFileVoiceProfileStorage)
                and the Persistence-layer TDBVoiceProfileStorage (FireDAC /
                voice_profiles table) can implement the same interface without
                introducing a Features -> Persistence or Persistence -> Features
                dependency.

                The voice profile storage is responsible for integrity,
                encryption at rest (for file-backed implementations) or
                access control (for DB-backed implementations), and thread
                safety. Callers obtain an instance via the public constructor
                of the concrete implementation they want.
  ============================================================================ }

unit DeepBase.Speech.Voiceprint.Contracts;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  DeepBase.Speech.MFCC;

type
  /// <summary>Stable identifier for a voice profile (GUID form preferred).</summary>
  TVoiceProfileId = string;

  /// <summary>Metadata for a single voice profile. Biometric payload
  /// (MFCC mean vector) is loaded/saved separately via LoadFeatures.</summary>
  TVoiceProfileInfo = record
    ProfileId: TVoiceProfileId;
    UserLabel: string;
    Purpose: string;
    SampleCount: Integer;
    Threshold: Double;
    OwnerApp: string;
    Enabled: Boolean;
    CreatedAt: TDateTime;
  end;

  /// <summary>
  /// Pluggable persistence contract for voice profiles.
  /// Implementations are responsible for integrity, encryption at rest (file)
  /// or access control (DB), and thread safety. The Voiceprint class holds a
  /// non-owning reference — the caller owns the storage instance.
  /// </summary>
  IVoiceProfileStorage = interface
    ['{5C7E4A19-8C2E-4D53-B9A1-0D8A9E3B7F24}']
    /// <summary>Load all persisted profiles. Empty array if none.</summary>
    function LoadAll: TArray<TPair<TVoiceProfileId, TVoiceProfileInfo>>;
    /// <summary>Load the MFCC mean vector for a profile. Empty array if missing.</summary>
    function LoadFeatures(const AId: TVoiceProfileId): TMFCCFeatures;
    /// <summary>Persist a profile and its mean MFCC vector.</summary>
    procedure SaveProfile(const AId: TVoiceProfileId; const AInfo: TVoiceProfileInfo;
      const AMean: TMFCCFrame);
    /// <summary>Remove a profile. Returns True if something was deleted.</summary>
    function DeleteProfile(const AId: TVoiceProfileId): Boolean;
  end;

implementation

end.
