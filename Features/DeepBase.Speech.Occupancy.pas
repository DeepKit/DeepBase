unit DeepBase.Speech.Occupancy;

{ ============================================================================
  DeepBase.Speech.Occupancy — SAPI Voice Occupancy Detection

  Detects whether the SAPI voice engine audio channel is currently occupied
  (speaking or in use by another application). Used for TTS coordination.

  Thread Safety: COM objects are STA-threaded; all calls must be from the
  same thread that calls CoInitialize.
  ============================================================================ }

interface

uses
  System.SysUtils, System.Win.ComObj, Winapi.Windows, Winapi.ActiveX,
  DeepBase.Speech.SAPI.Decl;

type
  TVoiceOccupancyStatus = (
    vosIdle,      // Voice engine is idle, no speech in progress
    vosSpeaking,  // Voice engine is currently speaking
    vosError      // Unable to determine status (SAPI not available)
  );

  /// <summary>
  /// SAPI voice occupancy detector. Checks whether the SAPI voice engine
  /// is currently busy producing audio output.
  /// </summary>
  TSAPIVoiceOccupancy = class
  private
    FVoice: ISpVoice;
    FInitialized: Boolean;
    FLastError: string;
    function EnsureVoice: Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>Check if the voice engine is currently speaking.</summary>
    function IsSpeaking: Boolean;

    /// <summary>Detailed occupancy status.</summary>
    function GetStatus: TVoiceOccupancyStatus;

    /// <summary>Wait until voice engine is idle, with timeout.</summary>
    function WaitUntilIdle(ATimeoutMs: Cardinal = 5000): Boolean;

    /// <summary>Returns True if the SAPI voice COM object was created successfully.</summary>
    function IsAvailable: Boolean;

    /// <summary>Last error message, if any.</summary>
    property LastError: string read FLastError;
  end;

implementation

{ TSAPIVoiceOccupancy }

constructor TSAPIVoiceOccupancy.Create;
begin
  inherited Create;
  FInitialized := False;
  FLastError := '';
end;

destructor TSAPIVoiceOccupancy.Destroy;
begin
  FVoice := nil;
  inherited;
end;

function TSAPIVoiceOccupancy.EnsureVoice: Boolean;
begin
  if not FInitialized then
  begin
    try
      FVoice := CreateComObject(CLSID_SpVoice) as ISpVoice;
      FInitialized := FVoice <> nil;
    except
      on E: Exception do
      begin
        FLastError := 'SAPI voice creation failed: ' + E.Message;
        FInitialized := False;
      end;
    end;
  end;
  Result := FInitialized;
end;

function TSAPIVoiceOccupancy.IsAvailable: Boolean;
begin
  Result := EnsureVoice;
end;

function TSAPIVoiceOccupancy.IsSpeaking: Boolean;
begin
  Result := GetStatus = vosSpeaking;
end;

function TSAPIVoiceOccupancy.GetStatus: TVoiceOccupancyStatus;
var
  Voice: ISpVoice;
  Status: HRESULT;
begin
  if not EnsureVoice then
    Exit(vosError);

  try
    // Try to get a new voice instance to check if the shared voice is busy.
    // If the shared voice is speaking, this will be detectable via the
    // GetStatus/GetRunningState pattern.
    Voice := CreateComObject(CLSID_SpVoice) as ISpVoice;

    // Check if we can speak — if the engine is occupied, this will fail or block.
    // Use WaitUntilDone(0) to check without blocking.
    Status := Voice.WaitUntilDone(0);
    if Status = S_OK then
      Result := vosIdle
    else
      Result := vosSpeaking;
  except
    on E: Exception do
    begin
      FLastError := 'SAPI occupancy check failed: ' + E.Message;
      Result := vosError;
    end;
  end;
end;

function TSAPIVoiceOccupancy.WaitUntilIdle(ATimeoutMs: Cardinal): Boolean;
var
  StartTick: UInt64;
begin
  Result := False;
  if not EnsureVoice then
    Exit;

  StartTick := GetTickCount64;
  while GetTickCount64 - StartTick < ATimeoutMs do
  begin
    if not IsSpeaking then
      Exit(True);
    Sleep(100);
  end;
  FLastError := 'SAPI voice occupancy timeout after ' + IntToStr(ATimeoutMs) + 'ms';
end;

end.