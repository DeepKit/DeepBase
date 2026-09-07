{ ============================================================================
  DeepBase.HB.Choice.Types - Unified 0-9 Choice Deck Contract Types

  Version: 2.0 (Delphi 13.1 on Win64 / Cross-Platform RTL)
  Description: Core contract types for HB AI Choice Interaction Standard:
               - 1-7 Contextual option candidates (Key 1 can be Recommended)
               - 8 Fixed control: Regenerate
               - 9 Fixed control: Human Override / Free Input (Frame Rejection)
               - 0 Fixed control: Navigate Back (Navigation, not Rejection)
               - Multi-modal action abstraction: THbChoiceAction & THbChoiceInputSource
               - Layout modes: Deck, Row, NumberedList, Inline
               - Truthful State Machine: Ready, Regenerating, FreeInput,
                 Loading, NoReliableCandidates, Disabled, Error
               - Verified 100% backward-compatible with v1.0
  ============================================================================ }

unit DeepBase.HB.Choice.Types;

{$WARN IMPLICIT_STRING_CAST OFF}

interface

uses
  System.SysUtils,
  System.Classes,
  DeepBase.HB.Core;

type
  /// <summary>
  /// Semantic classification for 0-9 choice options (v1 backward-compatible).
  /// </summary>
  THbChoiceKind = (
    ckOption,      // 1..7 Contextual option candidates
    ckRegenerate,  // 8 Global fixed: Regenerate / Redo
    ckInput,       // 9 Global fixed: Custom user input
    ckBack         // 0 Global fixed: Navigate back / Return
  );

  /// <summary>
  /// Unified interaction intent classification.
  /// </summary>
  THbChoiceActionKind = (
    cakCandidate,    // 1..7 Candidate selection
    cakRegenerate,   // 8 Regenerate current context
    cakFreeInput,    // 9 Human Override / Free text / Frame rejection
    cakBack          // 0 Navigate back
  );

  /// <summary>
  /// Input source device type (decouples action intent from hardware input).
  /// </summary>
  THbChoiceInputSource = (
    cisMouse,          // Mouse primary button click
    cisKeyboard,       // Main keyboard digit (0..9)
    cisNumPad,         // Numeric keypad (with NumLock active)
    cisVoice,          // Speech recognition / intent mapping (future slot)
    cisAccessibility,  // Screen reader / accessibility invoker
    cisProgrammatic    // Programmatic code trigger
  );

  /// <summary>
  /// Visual layout mode for Choice surface.
  /// </summary>
  THbChoiceLayoutMode = (
    clmDeck,          // Mode A: Standard stacked deck (3..7 candidates)
    clmRow,           // Mode B: Compact horizontal row (2..4 short choices)
    clmNumberedList,  // Mode C: Numbered list for long text / sidebar
    clmInline         // Mode D: Lightweight inline decision strip
  );

  /// <summary>
  /// Visual state model for Choice surface (truthful AI state representation).
  /// </summary>
  THbChoiceState = (
    csReady,                 // Normal interactive state
    csChoosing,              // Candidate selection transition
    csRegenerating,          // Light regenerating (old options dimmed, not blanked)
    csFreeInput,             // Free text entry active (shortcuts suspended)
    csLoading,               // Initial candidate fetch
    csNoReliableCandidates,  // Honest AI state: unable to form reliable options
    csDisabled,              // Surface disabled
    csError                  // Technical error (network/provider failure, distinct from NoCandidates)
  );

  /// <summary>
  /// Free input mode delegate configuration.
  /// </summary>
  THbChoiceFreeInputMode = (
    fimBuiltIn,   // ChoiceDeck expands built-in single/multi-line editor
    fimExternal   // Application intercepts via OnFreeInputRequested
  );

  /// <summary>
  /// Single choice option item.
  /// </summary>
  THbChoiceItem = record
    Key: Integer;             // 0..9
    Text: string;             // Option title/summary
    Description: string;      // Optional secondary details
    Kind: THbChoiceKind;      // Option kind
    IsRecommended: Boolean;   // True for key 1 (Recommended, not "Best")
    Enabled: Boolean;
    Tag: NativeInt;
    Payload: NativeInt;
    class function Create(AKey: Integer; const AText: string;
      const ADesc: string = ''; AIsRecommended: Boolean = False;
      AEnabled: Boolean = True; APayload: NativeInt = 0): THbChoiceItem; static;
  end;

  /// <summary>
  /// Unified interaction action payload.
  /// </summary>
  THbChoiceAction = record
    Kind: THbChoiceActionKind;
    Key: Integer;                // 0..9
    Text: string;               // Option title or entered text
    Payload: NativeInt;         // Application domain context handle
    InputSource: THbChoiceInputSource;
    class function Create(AKind: THbChoiceActionKind; AKey: Integer;
      const AText: string; APayload: NativeInt;
      ASource: THbChoiceInputSource): THbChoiceAction; static;
  end;

  // Event prototypes
  THbChoiceEvent = procedure(Sender: TObject; AKey: Integer) of object;
  THbChoiceInputEvent = procedure(Sender: TObject; const AInputText: string) of object;
  THbChoiceActionEvent = procedure(Sender: TObject; const AAction: THbChoiceAction) of object;
  THbChoiceFreeInputRequestEvent = procedure(Sender: TObject; var Handled: Boolean) of object;

function GetDefaultChoiceKind(AKey: Integer): THbChoiceKind;
function ChoiceKindToActionKind(AKind: THbChoiceKind): THbChoiceActionKind;
function ActionKindToChoiceKind(AKind: THbChoiceActionKind): THbChoiceKind;
function GetDefaultKeyLabel(AKey: Integer): string;

implementation

{ THbChoiceItem }

class function THbChoiceItem.Create(AKey: Integer; const AText, ADesc: string;
  AIsRecommended, AEnabled: Boolean; APayload: NativeInt): THbChoiceItem;
begin
  Result.Key := AKey;
  Result.Text := AText;
  Result.Description := ADesc;
  Result.Kind := GetDefaultChoiceKind(AKey);
  Result.IsRecommended := AIsRecommended;
  Result.Enabled := AEnabled;
  Result.Tag := APayload;
  Result.Payload := APayload;
end;

{ THbChoiceAction }

class function THbChoiceAction.Create(AKind: THbChoiceActionKind; AKey: Integer;
  const AText: string; APayload: NativeInt;
  ASource: THbChoiceInputSource): THbChoiceAction;
begin
  Result.Kind := AKind;
  Result.Key := AKey;
  Result.Text := AText;
  Result.Payload := APayload;
  Result.InputSource := ASource;
end;

function GetDefaultChoiceKind(AKey: Integer): THbChoiceKind;
begin
  case AKey of
    8: Result := ckRegenerate;
    9: Result := ckInput;
    0: Result := ckBack;
  else
    Result := ckOption;
  end;
end;

function ChoiceKindToActionKind(AKind: THbChoiceKind): THbChoiceActionKind;
begin
  case AKind of
    ckRegenerate: Result := cakRegenerate;
    ckInput:      Result := cakFreeInput;
    ckBack:       Result := cakBack;
  else
    Result := cakCandidate;
  end;
end;

function ActionKindToChoiceKind(AKind: THbChoiceActionKind): THbChoiceKind;
begin
  case AKind of
    cakRegenerate: Result := ckRegenerate;
    cakFreeInput:  Result := ckInput;
    cakBack:       Result := ckBack;
  else
    Result := ckOption;
  end;
end;

function GetDefaultKeyLabel(AKey: Integer): string;
begin
  case AKey of
    8: Result := '换一批';
    9: Result := '自己输入';
    0: Result := '返回';
  else
    Result := '';
  end;
end;

end.
