{ ============================================================================
  DeepBase.Speech.SAPI.Decl
  ---------------------------------------------------------------------------
  Version     : 1.0
  Description : Minimal SAPI 5.4 COM interface declarations for Delphi 37.0.
                Delphi does not ship Winapi.SpeechLib; these are hand-written
                from the SAPI 5.4 IDL (sapi.idl / sapiddk.idl).
                Only the interfaces needed by DeepBase.Speech are declared.
  Thread Safety: COM interfaces are apartment-threaded (STA).
  ============================================================================ }

unit DeepBase.Speech.SAPI.Decl;

interface

uses
  Winapi.Windows, Winapi.ActiveX, System.SysUtils;

// ============================================================================
// GUIDs
// ============================================================================

const
  // CLSIDs
  CLSID_SpVoice: TGUID            = '{96749377-3391-11D2-9EE3-00C04F797396}';
  CLSID_SpInprocRecognizer: TGUID = '{41B89B6B-9399-11D2-9623-00C04F8EE628}';
  CLSID_SpSharedRecognizer: TGUID = '{3BEE4890-4FE9-4A37-8C1E-5E7E12791C1F}';

  // Category tokens
  SPCAT_RECOGNIZERS: PWideChar = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Speech\Recognizers';
  SPCAT_VOICES: PWideChar      = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Speech\Voices';

  // Event interest flags
  SPFEI_ALL_SR_EVENTS = $000000000003FFFE;
  SPFEI_RECOGNITION   = $00000080;
  SPFEI_HYPOTHESIS    = $00000040;
  SPFEI_SOUND_START   = $00000002;
  SPFEI_SOUND_END     = $00000004;

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
    SPRST_INACTIVE = 0,
    SPRST_ACTIVE = 1,
    SPRST_ACTIVE_ALWAYS = 2
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

// ============================================================================
// Forward declarations
// ============================================================================

type
  ISpObjectToken = interface;
  ISpObjectTokenCategory = interface;
  ISpRecognizer = interface;
  ISpRecoContext = interface;
  ISpRecoGrammar = interface;
  ISpRecoResult = interface;
  ISpVoice = interface;

// ============================================================================
// Minimal interface declarations (only methods we call)
// ============================================================================

  ISpObjectToken = interface(IUnknown)
    ['{14056589-E16C-11D2-BB90-00C04F8EE6C0}']
    // We only need GetId and GetStringValue
    function GetId(out ppszCoMemTokenId: PWideChar): HRESULT; stdcall;
    // ... other methods omitted (placeholder stubs for vtable alignment)
  end;

  ISpObjectTokenCategory = interface(IUnknown)
    ['{2D3D3845-39AF-4850-BBF9-40B49780011D}']
    function SetId(pszCategoryId: PWideChar; fCreateIfNotExist: BOOL): HRESULT; stdcall;
    function GetId(out ppszCoMemCategoryId: PWideChar): HRESULT; stdcall;
    // ... other methods omitted
  end;

  ISpRecoResult = interface(IUnknown)
    ['{20B053BE-E235-43CD-9A2A-8D17A48B7842}']
    // Minimal: GetText
    function Placeholder1: HRESULT; stdcall;
    function Placeholder2: HRESULT; stdcall;
    function Placeholder3: HRESULT; stdcall;
    function Placeholder4: HRESULT; stdcall;
    function Placeholder5: HRESULT; stdcall;
    function GetText(ulStart, ulCount: ULONG; fUseTextReplacements: BOOL;
      out ppszCoMemText: PWideChar; out pbDisplayAttributes: Byte): HRESULT; stdcall;
  end;

  ISpRecoGrammar = interface(IUnknown)
    ['{2177DB29-7F45-47D0-8554-067E91C80502}']
    // Minimal subset for Grammar-based recognition
    function Placeholder1: HRESULT; stdcall;  // GetGrammarId
    function Placeholder2: HRESULT; stdcall;  // GetRecoContext
    function LoadCmdFromFile(pszFileName: PWideChar; Options: DWORD): HRESULT; stdcall;
    function LoadCmdFromObject(const rcid: TGUID; pszGrammarName: PWideChar; Options: DWORD): HRESULT; stdcall;
    function LoadCmdFromResource(hModule: HMODULE; pszResourceName, pszResourceType: PWideChar;
      wLanguage: Word; Options: DWORD): HRESULT; stdcall;
    function LoadCmdFromMemory(const pGrammar: Pointer; Options: DWORD): HRESULT; stdcall;
    function LoadCmdFromProprietaryGrammar(const rguidParam: TGUID; pszStringParam: PWideChar;
      pvDataParam: Pointer; cbDataSize: ULONG; Options: DWORD): HRESULT; stdcall;
    function SetRuleState(pszName: PWideChar; pReserved: Pointer;
      NewState: DWORD): HRESULT; stdcall;
    function SetRuleIdState(ulRuleId: ULONG; NewState: DWORD): HRESULT; stdcall;
    function LoadDictation(pszTopicName: PWideChar; Options: DWORD): HRESULT; stdcall;
    function UnloadDictation: HRESULT; stdcall;
    function SetDictationState(NewState: DWORD): HRESULT; stdcall;
  end;

  ISpRecoContext = interface(IUnknown)
    ['{F740A62F-7C15-489E-8234-940A33D9272D}']
    function GetRecognizer(out ppRecognizer: ISpRecognizer): HRESULT; stdcall;
    function Placeholder2: HRESULT; stdcall;  // GetStatus
    function Placeholder3: HRESULT; stdcall;  // GetMaxAlternates
    function Placeholder4: HRESULT; stdcall;  // SetMaxAlternates
    function SetAudioOptions(Options: DWORD; const pAudioFormatId: TGUID;
      const pWaveFormatEx: Pointer): HRESULT; stdcall;
    function Placeholder6: HRESULT; stdcall;  // GetAudioOptions
    function Placeholder7: HRESULT; stdcall;  // DeserializeResult
    function Placeholder8: HRESULT; stdcall;  // Bookmark
    function SetAdaptationData(pAdaptationData: PWideChar; cch: ULONG): HRESULT; stdcall;
    function Pause(dwReserved: DWORD): HRESULT; stdcall;
    function Resume(dwReserved: DWORD): HRESULT; stdcall;
    function SetVoice(pVoice: ISpVoice; fAllowFormatChanges: BOOL): HRESULT; stdcall;
    function Placeholder13: HRESULT; stdcall; // GetVoice
    function SetVoicePurgeEvent(ullEventInterest: UInt64): HRESULT; stdcall;
    function SetContextState(eState: DWORD): HRESULT; stdcall;
    function Placeholder16: HRESULT; stdcall; // GetContextState
    function Placeholder17: HRESULT; stdcall; // SetNotifySink
    function SetNotifyWindowMessage(hWnd: HWND; Msg: UINT; wParam: WPARAM; lParam: LPARAM): HRESULT; stdcall;
    function Placeholder19: HRESULT; stdcall; // SetNotifyCallbackFunction
    function Placeholder20: HRESULT; stdcall; // SetNotifyCallbackInterface
    function Placeholder21: HRESULT; stdcall; // SetNotifyWin32Event
    function SetInterest(ullEventInterest, ullQueuedInterest: UInt64): HRESULT; stdcall;
    function Placeholder23: HRESULT; stdcall; // GetEvents
    function CreateGrammar(ullGrammarId: UInt64; out ppGrammar: ISpRecoGrammar): HRESULT; stdcall;
  end;

  ISpRecognizer = interface(IUnknown)
    ['{C2B5F241-DAA0-4507-9E16-5A1EAA2B7A5C}']
    function SetRecognizer(pToken: ISpObjectToken): HRESULT; stdcall;
    function GetRecognizer(out ppToken: ISpObjectToken): HRESULT; stdcall;
    function SetInput(pUnkInput: IUnknown; fAllowFormatChanges: BOOL): HRESULT; stdcall;
    function Placeholder4: HRESULT; stdcall;  // GetInputObjectToken
    function Placeholder5: HRESULT; stdcall;  // GetInputStream
    function CreateRecoContext(out ppNewCtxt: ISpRecoContext): HRESULT; stdcall;
    function Placeholder7: HRESULT; stdcall;  // GetRecoProfile
    function Placeholder8: HRESULT; stdcall;  // SetRecoProfile
    function Placeholder9: HRESULT; stdcall;  // IsSharedInstance
    function GetRecoState(out pState: SPRECOSTATE): HRESULT; stdcall;
    function SetRecoState(NewState: SPRECOSTATE): HRESULT; stdcall;
    function Placeholder12: HRESULT; stdcall; // GetStatus
    function Placeholder13: HRESULT; stdcall; // GetFormat
    function Placeholder14: HRESULT; stdcall; // IsUISupported
    function Placeholder15: HRESULT; stdcall; // DisplayUI
    function Placeholder16: HRESULT; stdcall; // EmulateRecognition
  end;

  ISpVoice = interface(IUnknown)
    ['{6C44DF74-72B9-4992-A1EC-EF996E0422D4}']
    function SetOutput(pUnkOutput: IUnknown; fAllowFormatChanges: BOOL): HRESULT; stdcall;
    function Placeholder2: HRESULT; stdcall;  // GetOutputObjectToken
    function Placeholder3: HRESULT; stdcall;  // GetOutputStream
    function Pause: HRESULT; stdcall;
    function Resume: HRESULT; stdcall;
    function SetVoice(pToken: ISpObjectToken): HRESULT; stdcall;
    function GetVoice(out ppToken: ISpObjectToken): HRESULT; stdcall;
    function Speak(pwcs: PWideChar; dwFlags: DWORD; out pulStreamNumber: ULONG): HRESULT; stdcall;
    function SpeakStream(pStream: IStream; dwFlags: DWORD; out pulStreamNumber: ULONG): HRESULT; stdcall;
    function Placeholder10: HRESULT; stdcall; // GetStatus
    function Placeholder11: HRESULT; stdcall; // Skip
    function SetPriority(ePriority: SPVPRIORITY): HRESULT; stdcall;
    function Placeholder13: HRESULT; stdcall; // GetPriority
    function Placeholder14: HRESULT; stdcall; // SetAlertBoundary
    function Placeholder15: HRESULT; stdcall; // GetAlertBoundary
    function SetRate(RateAdjust: Integer): HRESULT; stdcall;
    function GetRate(out pRateAdjust: Integer): HRESULT; stdcall;
    function SetVolume(usVolume: Word): HRESULT; stdcall;
    function GetVolume(out pusVolume: Word): HRESULT; stdcall;
    function WaitUntilDone(msTimeout: ULONG): HRESULT; stdcall;
    function Placeholder21: HRESULT; stdcall; // SetSyncSpeakTimeout
    function Placeholder22: HRESULT; stdcall; // GetSyncSpeakTimeout
    function Placeholder23: HRESULT; stdcall; // SpeakCompleteEvent
    function Placeholder24: HRESULT; stdcall; // IsUISupported
    function Placeholder25: HRESULT; stdcall; // DisplayUI
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
// Grammar rule states
// ============================================================================

const
  SPRS_INACTIVE = 0;
  SPRS_ACTIVE   = 1;

// ============================================================================
// Helper: CoCreate SAPI objects
// ============================================================================

function CoCreateSpVoice(out ASpVoice: ISpVoice): HRESULT;
function CoCreateSpInprocRecognizer(out ARecognizer: ISpRecognizer): HRESULT;
function CoCreateSpSharedRecognizer(out ARecognizer: ISpRecognizer): HRESULT;

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

end.
