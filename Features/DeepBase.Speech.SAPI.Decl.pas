{ ============================================================================
  DeepBase.Speech.SAPI.Decl
  ---------------------------------------------------------------------------
  Version     : 2.0
  Description : Minimal SAPI 5.4 COM interface declarations for Delphi 37.0.

  v2.0 (2026-08-09): Layout rewritten from REVERSE-ENGINEERED evidence, not
  from memory of sapi.idl. The Windows 24H2 sapi.dll vtable order DIFFERS
  from the widely-copied sapi.idl listing; every slot below was verified by:

    1) Reflection of System.Speech.dll interop interfaces (authoritative for
       the shipping sapi.dll it talks to): slot = interface method index + 3.
    2) Live ctypes probes against real SpInprocRecognizer objects:
       SetInput@9 S_OK, CreateRecoContext@12 S_OK, SetInterest@10 S_OK,
       CreateGrammar@14 S_OK, LoadDictation@20 S_OK, SetDictationState@22
       S_OK, SetRecoState@17 S_OK, BindToFile@17 S_OK, GetEvents@11 returns
       SPEI_RECOGNITION(0x20026), GetText@5 S_OK ("Â§" for a 440 Hz tone).

  Event IDs are SAPI 5.3+ numbering (SPEI_RECOGNITION = 38, NOT 19). The
  SetInterest validator (disassembled at sapi+0x8127C) REQUIRES bits 30+33
  (SPEI_RESERVED1|SPEI_RESERVED2) and REJECTS bits 0-29, 31, 32, 56-63 â€?
  SPFEI_ALL_SR_EVENTS with old numbering fails E_INVALIDARG.

  SPEVENT (Win64, 40 bytes): eEventId@0 elParamType@4 ulStreamNum@8 pad@12
  ullAudioStreamOffset@16 wParam@24 lParam@32. For SPEI_RECOGNITION the
  wParam is the ISpRecoResult pointer. eEventId may carry high flag bits
  (observed 0x20026 = RECOGNITION) â€?mask with $FF before comparing.

  Thread Safety: COM interfaces are apartment-threaded (STA).
  ============================================================================ }

unit DeepBase.Speech.SAPI.Decl;

interface

{$Z4}  // C-style enums are 4-byte ints; Delphi minimized enums would pass
       // garbage in the upper bytes of the register and sapi.dll rejects
       // them with SPERR_INVALID_FLAGS (0x80045001).

uses
  Winapi.Windows, Winapi.ActiveX, System.SysUtils;

// ============================================================================
// GUIDs
// ============================================================================

const
  // CLSIDs (verified against HKCR registry, 2026-08-09)
  CLSID_SpVoice: TGUID            = '{96749377-3391-11D2-9EE3-00C04F797396}';
  CLSID_SpInprocRecognizer: TGUID = '{41B89B6B-9399-11D2-9623-00C04F8EE628}';
  CLSID_SpSharedRecognizer: TGUID = '{3BEE4890-4FE9-4A37-8C1E-5E7E12791C1F}';
  CLSID_SpStream: TGUID          = '{715D9C59-4442-11D2-9605-00C04F8EE628}';

  // Category tokens
  SPCAT_RECOGNIZERS: PWideChar = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Speech\Recognizers';
  SPCAT_VOICES: PWideChar      = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Speech\Voices';

// ============================================================================
// SAPI 5.3+ event IDs (reverse-engineered from sapi.dll + System.Speech)
// ============================================================================

const
  SPEI_RESERVED1           = 30;  // SetInterest REQUIRED bit
  SPEI_RESERVED2           = 33;  // SetInterest REQUIRED bit
  SPEI_END_SR_STREAM       = 34;
  SPEI_SOUND_START         = 35;
  SPEI_SOUND_END           = 36;
  SPEI_PHRASE_START        = 37;
  SPEI_RECOGNITION         = 38;  // wParam = ISpRecoResult*
  SPEI_HYPOTHESIS          = 39;
  SPEI_SR_BOOKMARK         = 40;
  SPEI_PROPERTY_NUM_CHANGE = 41;
  SPEI_PROPERTY_STRING_CHANGE = 42;
  SPEI_FALSE_RECOGNITION   = 43;
  SPEI_INTERFERENCE        = 44;
  SPEI_REQUEST_UI          = 45;
  SPEI_RECO_STATE_CHANGE   = 46;
  SPEI_ADAPTATION          = 47;
  SPEI_START_SR_STREAM     = 48;
  SPEI_RECO_OTHER_CONTEXT  = 49;
  SPEI_SR_AUDIO_LEVEL      = 50;
  SPEI_SR_RETAINEDAUDIO    = 51;
  SPEI_SR_PRIVATE          = 52;
  SPEI_ACTIVE_CATEGORY_CHANGED = 53;
  SPEI_TEXTFEEDBACK        = 54;
  SPEI_RECOGNITION_ALL     = 55;
  SPEI_BARGE_IN            = 56;

// Event interest flags (UInt64(1) shl SPEI_xxx)
const
  SPFEI_RECOGNITION   = UInt64(1) shl SPEI_RECOGNITION;   // 1 shl 38
  SPFEI_HYPOTHESIS    = UInt64(1) shl SPEI_HYPOTHESIS;    // 1 shl 39
  SPFEI_FALSE_RECOG   = UInt64(1) shl SPEI_FALSE_RECOGNITION; // 1 shl 43
  SPFEI_END_SR_STREAM = UInt64(1) shl SPEI_END_SR_STREAM; // 1 shl 34
  SPFEI_SOUND_START   = UInt64(1) shl SPEI_SOUND_START;   // 1 shl 35
  SPFEI_SOUND_END     = UInt64(1) shl SPEI_SOUND_END;     // 1 shl 36
  SPFEI_START_SR_STREAM = UInt64(1) shl SPEI_START_SR_STREAM; // 1 shl 48
  // SetInterest validator REQUIRES bits 30+33 (disasm sapi+0x8127C)
  SPFEI_REQUIRED      = (UInt64(1) shl SPEI_RESERVED1) or
                        (UInt64(1) shl SPEI_RESERVED2);
  // Valid interest for recognition: required bits + the events DeepBase uses
  SPFEI_SR_INTEREST   = SPFEI_REQUIRED or SPFEI_END_SR_STREAM or
                        SPFEI_SOUND_START or SPFEI_SOUND_END or
                        SPFEI_RECOGNITION or SPFEI_HYPOTHESIS or
                        SPFEI_FALSE_RECOG or SPFEI_START_SR_STREAM;

// ============================================================================
// Enumerations
// ============================================================================

type
  SPSTREAMFORMAT = (
    SPSF_Default = -1,
    SPSF_NoAssignedFormat = 0,
    SPSF_Text = 1,
    SPSF_NonStandardFormat = 6,
    SPSF_ExtendedAudioFormat = 7,
    SPSF_8kHz8BitMono = 8,
    SPSF_8kHz16BitMono = 10,
    SPSF_16kHz16BitMono = 22,
    SPSF_44kHz16BitMono = 34
  );

  SPRECOSTATE = (
    SPRS_INACTIVE = 0,
    SPRS_ACTIVE = 1,
    SPRS_ACTIVE_ALWAYS = 2
  );

  SPRUNSTATE = (
    SPRS_DONE = 1,
    SPRS_IS_SPEAKING = 2
  );

  SPVPRIORITY = (
    SPVPRI_NORMAL = 0,
    SPVPRI_ALERT = 1,
    SPVPRI_OVER = 2
  );

  SPCFGRULEATTRIBUTES = (
    SPRAF_TopLevel = 1,
    SPRAF_Active = 2,
    SPRAF_Export = 4
  );

  // ISpStream.BindToFile mode (SPFILEMODE)
  SPFILEMODE = (
    SPFM_OPEN_READONLY = 0,
    SPFM_OPEN_READWRITE = 1,
    SPFM_CREATE = 2,
    SPFM_CREATE_ALWAYS = 3,
    SPFM_NUM_MODES = 4
  );

  // Grammar load options
  SPLOADOPTIONS = (
    SPLO_DYNAMIC = 0,
    SPLO_STATIC = 1
  );

  SPCONTEXTSTATE = (
    SPCS_DISABLED = 0,
    SPCS_ENABLED = 1
  );

// ============================================================================
// SPEVENT record (ISpRecoContext.GetEvents) â€?Win64 layout VERIFIED by probe
// ============================================================================

type
  //   eEventId@0 (4) elParamType@4 (4) ulStreamNum@8 (4) pad@12 (4)
  //   ullAudioStreamOffset@16 (8) wParam@24 (8) lParam@32 (8) â€?total 40
  // For SPEI_RECOGNITION the wParam holds the ISpRecoResult*.
  // eEventId may include high flag bits (observed 0x20026) â€?compare & $FF.
  SPEVENT = record
    eEventId: Integer;          // SPEVENTENUM â€?C enum, 4 bytes
    elParamType: Integer;       // SPEVENTLPARAMTYPE â€?C enum, 4 bytes
    ulStreamNum: ULONG;         // audio stream number
    ulPadding: ULONG;           // alignment padding
    ullAudioStreamOffset: UInt64;
    wParam: NativeUInt;         // ISpRecoResult* for SPEI_RECOGNITION
    lParam: NativeInt;
  end;

  SPEVENTSOURCEINFO = record
    ullEventInterest: UInt64;
    ullQueuedInterest: UInt64;
    ulCount: ULONG;
    ulSize: ULONG;
  end;

// ============================================================================
// Forward declarations
// ============================================================================

type
  ISpObjectToken = interface;
  ISpObjectTokenCategory = interface;
  ISpNotifySource = interface;
  ISpEventSource = interface;
  ISpProperties = interface;
  ISpRecognizer = interface;
  ISpRecoContext = interface;
  ISpRecoGrammar = interface;
  ISpRecoResult = interface;
  ISpVoice = interface;
  ISpStreamFormat = interface;
  ISpStream = interface;

// ============================================================================
// Interfaces â€?vtable slots are VERIFIED (System.Speech reflection + probes)
// ============================================================================

  // ISpNotifySource : IUnknown â€?7 methods (vtable 3..9) [verified via
  // ISpEventSource reflection: SetNotifySink@3 SetNotifyWindowMessage@4
  // SetNotifyCallbackFunction@5 SetNotifyCallbackInterface@6
  // SetNotifyWin32Event@7 WaitForNotifyEvent@8 GetNotifyEventHandle@9]
  ISpNotifySource = interface(IUnknown)
    ['{5EFF4AEF-8487-11D2-961C-00C04F8EE628}']
    function SetNotifySink(pNotifySink: IUnknown): HRESULT; stdcall;
    function SetNotifyWindowMessage(hWnd: HWND; Msg: UINT; wParam: WPARAM;
      lParam: LPARAM): HRESULT; stdcall;
    function SetNotifyCallbackFunction(pfnCallback: Pointer; wParam: WPARAM;
      lParam: LPARAM): HRESULT; stdcall;
    function SetNotifyCallbackInterface(pSpCallback: IUnknown; wParam: WPARAM;
      lParam: LPARAM): HRESULT; stdcall;
    function SetNotifyWin32Event: HRESULT; stdcall;
    function WaitForNotifyEvent(msTimeout: DWORD): HRESULT; stdcall;
    function GetNotifyEventHandle(out pEventHandle: THandle): HRESULT; stdcall;
  end;

  // ISpEventSource : ISpNotifySource â€?3 methods (vtable 10..12)
  ISpEventSource = interface(ISpNotifySource)
    ['{BE7A9CCE-5F9E-11D2-960F-00C04F8EE628}']
    function SetInterest(ullEventInterest, ullQueuedInterest: UInt64): HRESULT; stdcall; // 10 VERIFIED
    function GetEvents(ulCount: ULONG; pEvents: Pointer;
      pulFetched: PULONG): HRESULT; stdcall;                                             // 11 VERIFIED
    function GetInfo(pInfo: Pointer): HRESULT; stdcall;                                  // 12
  end;

  // ISpProperties : IUnknown â€?4 methods (vtable 3..6) [verified: ISpRecognizer
  // reflection slots 3-6 are Set/GetPropertyNum/String â€?the REAL base of
  // ISpRecognizer, NOT ISpEventSource!]
  ISpProperties = interface(IUnknown)
    ['{5B4A9714-94FC-4243-8B0B-051E46C84165}']
    function SetPropertyNum(pszName: PWideChar; lValue: Integer): HRESULT; stdcall;
    function GetPropertyNum(pszName: PWideChar; out plValue: Integer): HRESULT; stdcall;
    function SetPropertyString(pszName, pszValue: PWideChar): HRESULT; stdcall;
    function GetPropertyString(pszName: PWideChar;
      out ppCoMemValue: PWideChar): HRESULT; stdcall;
  end;

  // ISpStreamFormat : IStream â€?1 method (vtable 13)
  ISpStreamFormat = interface(IStream)
    ['{BED530BE-2606-4F4D-A1C0-54CD5A2796C2}']
    function GetFormat(out pguidFormatId: TGUID;
      out ppCoMemWaveFormatEx: Pointer): HRESULT; stdcall; // 13
  end;

  // ISpStream : ISpStreamFormat â€?vtable 14..18. BindToFile sits at 17
  // (VERIFIED by probe; one extra slot vs the classic listing at 16).
  ISpStream = interface(ISpStreamFormat)
    ['{12E3CCA9-7518-44C5-A5E7-BA5A79CB929E}']
    function SetBaseStream(pStream: IStream; const rguidFormat: TGUID;
      const pWaveFormatEx: Pointer): HRESULT; stdcall; // 14
    function GetBaseStream(out ppStream: IStream): HRESULT; stdcall; // 15
    function BindToFile(pszFileName: PWideChar; eMode: SPFILEMODE;
      const pFormatId: Pointer; const pWaveFormatEx: Pointer;
      ullEventInterest: UInt64): HRESULT; stdcall;    // 17 VERIFIED
    function Close: HRESULT; stdcall;                 // 18
  end;

  // ISpObjectTokenCategory : IUnknown â€?5 methods (vtable 3..7)
  ISpObjectTokenCategory = interface(IUnknown)
    ['{2D3D3845-39AF-4850-BBF9-40B49780011D}']
    function SetId(pszCategoryId: PWideChar; fCreateIfNotExist: BOOL): HRESULT; stdcall;
    function GetId(out ppszCoMemCategoryId: PWideChar): HRESULT; stdcall;
    function GetDataKey(Access: DWORD;
      out ppSubKey: IUnknown): HRESULT; stdcall;
    function SetDataKey(const pSubKey: IUnknown; fCreateIfNotExist: BOOL): HRESULT; stdcall;
    function EnumTokens(pszRequiredAttributes: PWideChar;
      pszOptionalAttributes: PWideChar;
      out ppEnum: IUnknown): HRESULT; stdcall;
  end;

  // ISpObjectToken : ISpObjectTokenCategory â€?7 methods (vtable 8..14)
  ISpObjectToken = interface(ISpObjectTokenCategory)
    ['{14056589-E16C-11D2-BB90-00C04F8EE6C0}']
    function CreateInstance(const pUnkOuter: IUnknown; dwClsContext: DWORD;
      const riid: TGUID; out ppvObject: Pointer): HRESULT; stdcall;
    function Remove(const pUnkRemove: IUnknown): HRESULT; stdcall;
    function GetCategory(out ppCategory: ISpObjectTokenCategory): HRESULT; stdcall;
    function GetDescription(Language: LCID;
      out ppszCoMemDescription: PWideChar): HRESULT; stdcall;
    function SetDescription(Language: LCID;
      pszDescription: PWideChar): HRESULT; stdcall;
    function SetStringValue(pszValueName, pszValue: PWideChar): HRESULT; stdcall;
    function GetStringValue(pszValueName: PWideChar;
      out ppszCoMemValue: PWideChar): HRESULT; stdcall;
  end;

  // ISpRecognizer : ISpProperties â€?vtable 7..22 (VERIFIED slots 9/12/17)
  ISpRecognizer = interface(ISpProperties)
    ['{C2B5F241-DAA0-4507-9E16-5A1EAA2B7A5C}']
    function SetRecognizer(pToken: ISpObjectToken): HRESULT; stdcall;  // 7
    function GetRecognizer(out ppToken: ISpObjectToken): HRESULT; stdcall; // 8
    function SetInput(pUnkInput: IUnknown; fAllowFormatChanges: BOOL): HRESULT; stdcall; // 9 VERIFIED
    function GetInputObjectToken(out ppToken: ISpObjectToken): HRESULT; stdcall; // 10
    function GetInputStream(out ppStream: IUnknown): HRESULT; stdcall; // 11
    function CreateRecoContext(out ppNewCtxt: ISpRecoContext): HRESULT; stdcall; // 12 VERIFIED
    function GetRecoContext(out ppRecoContext: ISpRecoContext): HRESULT; stdcall; // 13
    function Slot14: HRESULT; stdcall;                // 14 (unused)
    function Slot15: HRESULT; stdcall;                // 15 (unused)
    function GetRecoState(out pState: SPRECOSTATE): HRESULT; stdcall; // 16
    function SetRecoState(NewState: SPRECOSTATE): HRESULT; stdcall;  // 17 VERIFIED â€?recognition START switch!
    function GetStatus(pStatus: Pointer): HRESULT; stdcall;          // 18
    function GetFormat(WaveFormatType: DWORD; out pFormatId: TGUID;
      out ppCoMemWaveFormatEx: Pointer): HRESULT; stdcall;           // 19
    function IsUISupported(pszTypeOfUI: PWideChar; pvExtraData: Pointer;
      cbExtraData: ULONG; out pfSupported: BOOL): HRESULT; stdcall;  // 20
    function DisplayUI(hWndParent: HWND; pszTitle: PWideChar;
      pszTypeOfUI: PWideChar; pvExtraData: Pointer;
      cbExtraData: ULONG): HRESULT; stdcall;                         // 21
    function EmulateRecognition(pPhrase: IUnknown): HRESULT; stdcall; // 22
  end;

  // ISpRecoContext : ISpEventSource â€?vtable 13..30. NOTE: CreateGrammar is
  // at 14 on this sapi.dll (VERIFIED), NOT at 26 as the classic sapi.idl
  // listing claims. Slots marked (unused) are placeholders only.
  ISpRecoContext = interface(ISpEventSource)
    ['{F740A62F-7C15-489E-8234-940A33D9272D}']
    function GetRecognizer(out ppRecognizer: ISpRecognizer): HRESULT; stdcall; // 13
    function CreateGrammar(ullGrammarId: UInt64;
      out ppGrammar: ISpRecoGrammar): HRESULT; stdcall;  // 14 VERIFIED
    function GetStatus(pStatus: Pointer): HRESULT; stdcall; // 15
    function GetMaxAlternates(out pcAlternates: ULONG): HRESULT; stdcall; // 16
    function SetMaxAlternates(cAlternates: ULONG): HRESULT; stdcall; // 17
    function SetAudioOptions(Options: DWORD; const pAudioFormatId: TGUID;
      const pWaveFormatEx: Pointer): HRESULT; stdcall; // 18
    function Slot19: HRESULT; stdcall;                // 19 (unused)
    function Slot20: HRESULT; stdcall;                // 20 (unused)
    function Bookmark(Options: DWORD; ullStreamPosition: UInt64;
      lparam: LPARAM): HRESULT; stdcall;              // 21
    function Slot22: HRESULT; stdcall;                // 22 (unused)
    function Pause(dwReserved: DWORD): HRESULT; stdcall;  // 23
    function Resume(dwReserved: DWORD): HRESULT; stdcall; // 24
    function Slot25: HRESULT; stdcall;                // 25 (unused)
    function Slot26: HRESULT; stdcall;                // 26 (unused)
    function Slot27: HRESULT; stdcall;                // 27 (unused)
    function Slot28: HRESULT; stdcall;                // 28 (unused)
    function SetContextState(eState: SPCONTEXTSTATE): HRESULT; stdcall; // 29
    function Slot30: HRESULT; stdcall;                // 30 (unused)
  end;

  // ISpRecoGrammar : IUnknown + 10 placeholder slots (3..12 = ISpGrammarBuilder
  // area), then vtable 13..22. LoadDictation@20 / SetDictationState@22 VERIFIED.
  ISpRecoGrammar = interface(IUnknown)
    ['{2177DB29-7F45-47D0-8554-067E91C80502}']
    function Slot3: HRESULT; stdcall;                 // ISpGrammarBuilder area
    function Slot4: HRESULT; stdcall;
    function Slot5: HRESULT; stdcall;
    function Slot6: HRESULT; stdcall;
    function Slot7: HRESULT; stdcall;
    function Slot8: HRESULT; stdcall;
    function Slot9: HRESULT; stdcall;
    function Slot10: HRESULT; stdcall;
    function Slot11: HRESULT; stdcall;
    function Slot12: HRESULT; stdcall;
    function LoadCmdFromFile(pszFileName: PWideChar;
      Options: SPLOADOPTIONS): HRESULT; stdcall;      // 13
    function Slot14: HRESULT; stdcall;
    function Slot15: HRESULT; stdcall;
    function LoadCmdFromMemory(const pGrammar: Pointer;
      Options: SPLOADOPTIONS): HRESULT; stdcall;      // 16
    function Slot17: HRESULT; stdcall;
    function SetRuleState(pszName: PWideChar; pReserved: Pointer;
      NewState: DWORD): HRESULT; stdcall;             // 18
    function Slot19: HRESULT; stdcall;
    function LoadDictation(pszTopicName: PWideChar;
      Options: SPLOADOPTIONS): HRESULT; stdcall;      // 20 VERIFIED
    function Slot21: HRESULT; stdcall;                // UnloadDictation
    function SetDictationState(NewState: SPRECOSTATE): HRESULT; stdcall; // 22 VERIFIED
    function Slot23: HRESULT; stdcall;
    function Slot24: HRESULT; stdcall;
    function Slot25: HRESULT; stdcall;
    function SetGrammarState(eState: DWORD): HRESULT; stdcall; // 26
  end;

  // ISpRecoResult : IUnknown â€?we only use GetText@5 (VERIFIED). The classic
  // ISpPhrase base (GetPhrase@3 GetSerializedPhrase@4 Discard@6) applies.
  ISpRecoResult = interface(IUnknown)
    ['{20B053BE-E235-43CD-9A2A-8D17A48B7842}']
    function GetPhrase(out ppCoMemPhrase: Pointer): HRESULT; stdcall;  // 3
    function GetSerializedPhrase(out ppCoMemPhrase: Pointer): HRESULT; stdcall; // 4
    function GetText(ulStart, ulCount: ULONG; fUseTextReplacements: BOOL;
      out ppszCoMemText: PWideChar; pulStartIndex, pulLength: PULONG): HRESULT; stdcall; // 5 VERIFIED
    function Discard(ulValueTypes: ULONG): HRESULT; stdcall; // 6
  end;

  // ISpVoice : ISpEventSource â€?25 methods (vtable 13..37), classic order
  // (TTS path; not re-verified on 24H2 but SAPI TTS was working before).
  ISpVoice = interface(ISpEventSource)
    ['{6C44DF74-72B9-4992-A1EC-EF996E0422D4}']
    function SetOutput(pUnkOutput: IUnknown; fAllowFormatChanges: BOOL): HRESULT; stdcall;
    function GetOutputObjectToken(out ppToken: ISpObjectToken): HRESULT; stdcall;
    function GetOutputStream(out ppStream: ISpStreamFormat): HRESULT; stdcall;
    function Pause: HRESULT; stdcall;
    function Resume: HRESULT; stdcall;
    function SetVoice(pToken: ISpObjectToken): HRESULT; stdcall;
    function GetVoice(out ppToken: ISpObjectToken): HRESULT; stdcall;
    function Speak(pwcs: PWideChar; dwFlags: DWORD;
      out pulStreamNumber: ULONG): HRESULT; stdcall;
    function SpeakStream(pStream: IStream; dwFlags: DWORD;
      out pulStreamNumber: ULONG): HRESULT; stdcall;
    function GetStatus(pStatus: Pointer): HRESULT; stdcall;
    function Skip(pItemType: PWideChar; lNumItems: Integer;
      out pulNumSkipped: ULONG): HRESULT; stdcall;
    function SetPriority(ePriority: SPVPRIORITY): HRESULT; stdcall;
    function GetPriority(out pePriority: SPVPRIORITY): HRESULT; stdcall;
    function SetAlertBoundary(eBoundary: DWORD): HRESULT; stdcall;
    function GetAlertBoundary(out peBoundary: DWORD): HRESULT; stdcall;
    function SetRate(RateAdjust: Integer): HRESULT; stdcall;
    function GetRate(out pRateAdjust: Integer): HRESULT; stdcall;
    function SetVolume(usVolume: Word): HRESULT; stdcall;
    function GetVolume(out pusVolume: Word): HRESULT; stdcall;
    function WaitUntilDone(msTimeout: ULONG): HRESULT; stdcall;
    function SetSyncSpeakTimeout(msTimeout: ULONG): HRESULT; stdcall;
    function GetSyncSpeakTimeout(out pmsTimeout: ULONG): HRESULT; stdcall;
    function SpeakCompleteEvent(out pHandle: THandle): HRESULT; stdcall;
    function IsUISupported(pszTypeOfUI: PWideChar; pvExtraData: Pointer;
      cbExtraData: ULONG; out pfSupported: BOOL): HRESULT; stdcall;
    function DisplayUI(hWndParent: HWND; pszTitle: PWideChar;
      pszTypeOfUI: PWideChar; pvExtraData: Pointer;
      cbExtraData: ULONG): HRESULT; stdcall;
  end;

// ============================================================================
// Speak flags
// ============================================================================

const
  SPF_DEFAULT          = 0;
  SPF_ASYNC            = 1;
  SPF_PURGEBEFORESPEAK = 2;
  SPF_IS_FILENAME      = 4;
  SPF_IS_XML           = 8;
  SPF_IS_NOT_XML       = 16;

// ============================================================================
// Helper: CoCreate SAPI objects
// ============================================================================

function CoCreateSpVoice(out ASpVoice: ISpVoice): HRESULT;
function CoCreateSpInprocRecognizer(out ARecognizer: ISpRecognizer): HRESULT;
function CoCreateSpSharedRecognizer(out ARecognizer: ISpRecognizer): HRESULT;
function CoCreateSpStream(out AStream: ISpStream): HRESULT;

implementation

function CoCreateSpVoice(out ASpVoice: ISpVoice): HRESULT;
begin
  Result := CoCreateInstance(CLSID_SpVoice, nil, CLSCTX_ALL,
    ISpVoice, ASpVoice);
end;

function CoCreateSpInprocRecognizer(out ARecognizer: ISpRecognizer): HRESULT;
begin
  Result := CoCreateInstance(CLSID_SpInprocRecognizer, nil, CLSCTX_ALL,
    ISpRecognizer, ARecognizer);
end;

function CoCreateSpSharedRecognizer(out ARecognizer: ISpRecognizer): HRESULT;
begin
  Result := CoCreateInstance(CLSID_SpSharedRecognizer, nil, CLSCTX_ALL,
    ISpRecognizer, ARecognizer);
end;

function CoCreateSpStream(out AStream: ISpStream): HRESULT;
begin
  Result := CoCreateInstance(CLSID_SpStream, nil, CLSCTX_ALL,
    ISpStream, AStream);
end;

end.
