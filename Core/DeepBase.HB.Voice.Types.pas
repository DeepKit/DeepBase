{ ============================================================================
  DeepBase.HB.Voice.Types - Universal Voice Input & Extraction Contract Types

  Version: 1.0 (Delphi 13.1 on Win64 / Cross-Platform RTL)
  Description: Framework-agnostic contracts for universal voice input, waveform,
               six-state lifecycle, structured field confirmation with Diff view,
               low-confidence warnings, inline modification, and draft storage.
  ============================================================================ }

unit DeepBase.HB.Voice.Types;

interface

uses
  System.SysUtils,
  System.Classes,
  System.UITypes,
  DeepBase.HB.Core;

type
  /// <summary>
  /// Six lifecycle states of voice input flow.
  /// </summary>
  THbVoiceState = (
    vsEntry,        // 1. Entry state (Ghost/mic button)
    vsRecording,    // 2. Recording state (Waveform + timer + 120s limit + privacy badge)
    vsExtracting,   // 3. Extracting state (Skeleton placeholder + pulse text)
    vsConfirming,   // 4. Confirming state (Core decision screen: field cards + diff + inline edit)
    vsPersisted,    // 5. Persisted state (Toast notice + visual highlight flash)
    vsDraft         // 6. Draft state (Offline recovery on unexpected exit)
  );

  /// <summary>
  /// Decision status of a single extracted field item.
  /// </summary>
  THbVoiceFieldStatus = (
    vfsPending,     // Waiting for user confirmation
    vfsAccepted,    // Accepted by user (will be persisted)
    vfsModified,    // Modified in-place by user (will be persisted)
    vfsDiscarded    // Discarded by user (will NOT be persisted)
  );

  /// <summary>
  /// Single structured field item extracted from voice speech.
  /// </summary>
  THbVoiceFieldItem = record
    FieldKey: string;          // Identifier (e.g. 'phone', 'budget', 'memo')
    FieldLabel: string;        // Human label (e.g. '联系电话', '意向金额')
    OldValue: string;          // Existing value in database (for diff comparison)
    ExtractedValue: string;    // LLM extracted value
    CurrentValue: string;      // Final value after in-place modification
    OriginalQuote: string;     // Exact quote snippet from ASR transcript
    Confidence: Single;        // 0.0 ~ 1.0 confidence score
    IsLowConfidence: Boolean;  // True if confidence < threshold (triggers amber badge)
    Status: THbVoiceFieldStatus;
    IsExpanded: Boolean;       // Accordion detail expanded state
  end;

  /// <summary>
  /// Complete voice session payload.
  /// </summary>
  THbVoiceSessionData = record
    SessionId: string;
    AudioDurationSec: Integer;
    RawTranscript: string;
    FieldItems: TArray<THbVoiceFieldItem>;
    CreatedAt: TDateTime;
    IsDraft: Boolean;
  end;

  /// <summary>
  /// Callback signatures for voice engine integration.
  /// </summary>
  THbVoiceStateChangeEvent = procedure(Sender: TObject; AOldState, ANewState: THbVoiceState) of object;
  THbVoiceFieldConfirmEvent = procedure(Sender: TObject; const AItem: THbVoiceFieldItem) of object;
  THbVoicePersistEvent = procedure(Sender: TObject; const AAcceptedItems: TArray<THbVoiceFieldItem>; out ASuccess: Boolean) of object;

implementation

end.
