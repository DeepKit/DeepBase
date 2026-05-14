unit DeepBase.Speech.Audio.WinMM;

interface

uses
  System.Classes,
  System.SyncObjs,
  System.SysUtils,
  Winapi.MMSystem,
  Winapi.Windows,
  DeepBase.Speech.Types;

type
  TDeepBaseWinMMAudioCapture = class(TInterfacedObject, ISpeechAudioCapture)
  private
    FWaveIn: HWAVEIN;
    FIsRecording: Boolean;
    FLastError: string;
    FSampleRate: Integer;
    FBufferSize: Integer;
    FBufferCount: Integer;
    FStream: TMemoryStream;
    FLock: TCriticalSection;
    FWaveHeaders: array of TWaveHdr;
    FBuffers: array of PByte;

    procedure PrepareBuffers;
    procedure FreeBuffers;
    procedure AddBufferToStream(AHeader: PWaveHdr);
  public
    /// <summary>
    /// Create audio capture.
    /// For batch recognition use defaults (1000ms buffers).
    /// For low-latency streaming use ABufferMs=50, ABufferCount=8.
    /// </summary>
    constructor Create(ASampleRate: Integer = 16000;
      ABufferCount: Integer = 4; ABufferMs: Integer = 1000);
    destructor Destroy; override;

    /// <summary>Create a low-latency instance optimized for streaming ASR (50ms buffers × 8).</summary>
    class function CreateLowLatency(ASampleRate: Integer = 16000): TDeepBaseWinMMAudioCapture; static;

    function StartRecording: Boolean;
    procedure StopRecording;
    function GetAudioData: TSpeechAudioData;
    function GetPCMData: TBytes;
    function GetFloatSamples: TArray<Single>;
    function IsRecording: Boolean;
    function LastError: string;
    function SampleRate: Integer;
    function BufferMs: Integer;
  end;

implementation

{$POINTERMATH ON}

procedure WaveInProc(AWaveIn: HWAVEIN; AMsg: UINT; AInstance: DWORD_PTR;
  AParam1, AParam2: DWORD_PTR); stdcall;
var
  Capture: TDeepBaseWinMMAudioCapture;
  Header: PWaveHdr;
begin
  if AMsg <> WIM_DATA then
    Exit;

  Capture := TDeepBaseWinMMAudioCapture(AInstance);
  Header := PWaveHdr(AParam1);
  if Assigned(Capture) and Assigned(Header) and Capture.IsRecording then
  begin
    Capture.AddBufferToStream(Header);
    if Capture.IsRecording then
      waveInAddBuffer(AWaveIn, Header, SizeOf(TWaveHdr));
  end;
end;

constructor TDeepBaseWinMMAudioCapture.Create(ASampleRate, ABufferCount,
  ABufferMs: Integer);
begin
  inherited Create;
  FWaveIn := 0;
  FIsRecording := False;
  FLastError := '';
  FSampleRate := ASampleRate;
  FBufferCount := ABufferCount;
  FBufferSize := FSampleRate * SizeOf(SmallInt) * ABufferMs div 1000;
  FStream := TMemoryStream.Create;
  FLock := TCriticalSection.Create;
end;

class function TDeepBaseWinMMAudioCapture.CreateLowLatency(
  ASampleRate: Integer): TDeepBaseWinMMAudioCapture;
begin
  // 50ms buffers × 8 = 400ms total buffered, good balance of latency vs CPU.
  // M0 Spike confirmed 50ms is optimal for streaming ASR on modern hardware.
  Result := TDeepBaseWinMMAudioCapture.Create(ASampleRate, 8, 50);
end;

destructor TDeepBaseWinMMAudioCapture.Destroy;
begin
  if FIsRecording then
    StopRecording;
  FLock.Free;
  FStream.Free;
  inherited;
end;

procedure TDeepBaseWinMMAudioCapture.PrepareBuffers;
var
  I: Integer;
  Res: MMRESULT;
begin
  SetLength(FWaveHeaders, FBufferCount);
  SetLength(FBuffers, FBufferCount);

  for I := 0 to FBufferCount - 1 do
  begin
    GetMem(FBuffers[I], FBufferSize);
    FillChar(FBuffers[I]^, FBufferSize, 0);
    FillChar(FWaveHeaders[I], SizeOf(TWaveHdr), 0);
    FWaveHeaders[I].lpData := PAnsiChar(FBuffers[I]);
    FWaveHeaders[I].dwBufferLength := FBufferSize;
    FWaveHeaders[I].dwUser := NativeUInt(Self);

    Res := waveInPrepareHeader(FWaveIn, @FWaveHeaders[I], SizeOf(TWaveHdr));
    if Res <> MMSYSERR_NOERROR then
      raise EDeepBaseSpeechAudioError.CreateFmt(
        'waveInPrepareHeader failed: %d', [Res]);

    Res := waveInAddBuffer(FWaveIn, @FWaveHeaders[I], SizeOf(TWaveHdr));
    if Res <> MMSYSERR_NOERROR then
      raise EDeepBaseSpeechAudioError.CreateFmt(
        'waveInAddBuffer failed: %d', [Res]);
  end;
end;

procedure TDeepBaseWinMMAudioCapture.FreeBuffers;
var
  I: Integer;
begin
  for I := 0 to FBufferCount - 1 do
  begin
    if (I <= High(FWaveHeaders)) and
       ((FWaveHeaders[I].dwFlags and WHDR_PREPARED) <> 0) then
      waveInUnprepareHeader(FWaveIn, @FWaveHeaders[I], SizeOf(TWaveHdr));
    if (I <= High(FBuffers)) and Assigned(FBuffers[I]) then
      FreeMem(FBuffers[I]);
  end;
  SetLength(FWaveHeaders, 0);
  SetLength(FBuffers, 0);
end;

procedure TDeepBaseWinMMAudioCapture.AddBufferToStream(AHeader: PWaveHdr);
begin
  FLock.Enter;
  try
    if Assigned(AHeader) and (AHeader^.dwBytesRecorded > 0) then
      FStream.Write(AHeader^.lpData^, AHeader^.dwBytesRecorded);
  finally
    FLock.Leave;
  end;
end;

function TDeepBaseWinMMAudioCapture.StartRecording: Boolean;
var
  Format: TWaveFormatEx;
  Res: MMRESULT;
  ErrorText: array[0..255] of Char;
begin
  Result := False;
  FLastError := '';

  FLock.Enter;
  try
    FStream.Clear;
  finally
    FLock.Leave;
  end;

  FillChar(Format, SizeOf(Format), 0);
  Format.wFormatTag := WAVE_FORMAT_PCM;
  Format.nChannels := 1;
  Format.nSamplesPerSec := FSampleRate;
  Format.wBitsPerSample := 16;
  Format.nBlockAlign := Format.nChannels * Format.wBitsPerSample div 8;
  Format.nAvgBytesPerSec := Format.nSamplesPerSec * Format.nBlockAlign;

  Res := waveInOpen(@FWaveIn, WAVE_MAPPER, @Format,
    NativeUInt(@WaveInProc), NativeUInt(Self), CALLBACK_FUNCTION);
  if Res <> MMSYSERR_NOERROR then
  begin
    waveInGetErrorText(Res, @ErrorText[0], Length(ErrorText));
    FLastError := Trim(string(ErrorText));
    Exit;
  end;

  try
    PrepareBuffers;
  except
    on E: Exception do
    begin
      FLastError := E.Message;
      FreeBuffers;
      waveInClose(FWaveIn);
      FWaveIn := 0;
      Exit;
    end;
  end;

  FIsRecording := True;
  Res := waveInStart(FWaveIn);
  if Res <> MMSYSERR_NOERROR then
  begin
    FIsRecording := False;
    waveInGetErrorText(Res, @ErrorText[0], Length(ErrorText));
    FLastError := Trim(string(ErrorText));
    FreeBuffers;
    waveInClose(FWaveIn);
    FWaveIn := 0;
    Exit;
  end;

  Result := True;
end;

procedure TDeepBaseWinMMAudioCapture.StopRecording;
begin
  if not FIsRecording then
    Exit;

  FIsRecording := False;
  waveInStop(FWaveIn);
  waveInReset(FWaveIn);
  FreeBuffers;
  waveInClose(FWaveIn);
  FWaveIn := 0;
end;

function TDeepBaseWinMMAudioCapture.GetAudioData: TSpeechAudioData;
begin
  Result := TSpeechAudioData.FromPCM16(GetPCMData, FSampleRate);
end;

function TDeepBaseWinMMAudioCapture.GetPCMData: TBytes;
begin
  FLock.Enter;
  try
    SetLength(Result, FStream.Size);
    if FStream.Size > 0 then
    begin
      FStream.Position := 0;
      FStream.ReadBuffer(Result[0], FStream.Size);
    end;
  finally
    FLock.Leave;
  end;
end;

function TDeepBaseWinMMAudioCapture.GetFloatSamples: TArray<Single>;
begin
  Result := TSpeechAudioUtils.PCM16ToFloat(GetPCMData);
end;

function TDeepBaseWinMMAudioCapture.IsRecording: Boolean;
begin
  Result := FIsRecording;
end;

function TDeepBaseWinMMAudioCapture.LastError: string;
begin
  Result := FLastError;
end;

function TDeepBaseWinMMAudioCapture.SampleRate: Integer;
begin
  Result := FSampleRate;
end;

function TDeepBaseWinMMAudioCapture.BufferMs: Integer;
begin
  if FSampleRate > 0 then
    Result := FBufferSize * 1000 div (FSampleRate * SizeOf(SmallInt))
  else
    Result := 0;
end;

end.
