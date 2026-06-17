unit DeepBase.Speech.TTS.Edge;

{ ============================================================================
  DeepBase.Speech.TTS.Edge — Free TTS via Microsoft Edge WebSocket service.
  Adapted from DeepInput/uTTS.Edge.pas, implements ITTSBackend interface.
  Uses WinHTTP Win32 API for WebSocket (no Delphi WebSocket unit needed).
  Self-registers to TSpeechRegistry on initialization.
  ============================================================================ }

interface

uses
  System.SysUtils, System.Classes,
  System.Net.HTTPClient, System.JSON, System.Generics.Collections,
  Winapi.Windows, Winapi.WinHTTP,
  DeepBase.Speech.Types, DeepBase.Speech.Registry;

{$IF not declared(WinHttpWebSocketSend)}
const
  WINHTTP_OPTION_UPGRADE_TO_WEB_SOCKET = 114;
  WINHTTP_WEB_SOCKET_UTF8_MESSAGE_TYPE = 2;
  WINHTTP_WEB_SOCKET_UTF8_FRAGMENT_BUFFER_TYPE = 5;
  WINHTTP_WEB_SOCKET_BINARY_MESSAGE_BUFFER_TYPE = 3;
  WINHTTP_WEB_SOCKET_BINARY_FRAGMENT_BUFFER_TYPE = 4;
  WINHTTP_WEB_SOCKET_CLOSE_BUFFER_TYPE = 6;
  WINHTTP_WEB_SOCKET_SUCCESS_CLOSE_STATUS = Word(1000);

function WinHttpWebSocketCompleteUpgrade(hRequest: HINTERNET;
  pContext: Pointer): HINTERNET; stdcall; external 'winhttp.dll' name 'WinHttpWebSocketCompleteUpgrade';
function WinHttpWebSocketSend(hWebSocket: HINTERNET;
  eBufferType: Cardinal; pvBuffer: Pointer; dwBufferLength: Cardinal): Cardinal; stdcall; external 'winhttp.dll' name 'WinHttpWebSocketSend';
function WinHttpWebSocketReceive(hWebSocket: HINTERNET;
  pvBuffer: Pointer; dwBufferLength: Cardinal;
  pdwBytesRead: PCardinal; peBufferType: PCardinal): Cardinal; stdcall; external 'winhttp.dll' name 'WinHttpWebSocketReceive';
function WinHttpWebSocketClose(hWebSocket: HINTERNET;
  wStatus: Word; pvBuffer: Pointer; dwBufferLength: Cardinal): Cardinal; stdcall; external 'winhttp.dll' name 'WinHttpWebSocketClose';
{$IFEND}

type
  TEdgeTTSBackend = class(TInterfacedObject, ITTSBackend)
  private
    FLastError: string;
    FVoices: TArray<TTTSVoice>;
    FVoicesLoaded: Boolean;
    FClient: THTTPClient;
    FOnDone: TProc;

    function BuildSSML(const AText: string; const AOptions: TTTSOptions): string;
    function FetchVoices: TArray<TTTSVoice>;
    function Synthesize(const ASSML: string): TBytes;
    class function ParseGender(const AGender: string): string; static;
    class function GenerateRequestID: string; static;
  public
    constructor Create;
    destructor Destroy; override;

    function IsAvailable: Boolean;
    function SupportedVoices(const ALanguage: string): TArray<TTTSVoice>;
    procedure Speak(const AText: string; const AOptions: TTTSOptions);
    procedure SpeakAsync(const AText: string; const AOptions: TTTSOptions;
      AOnDone: TProc);
    procedure Stop;
  end;

implementation

uses
  System.NetEncoding, System.DateUtils;

const
  EDGE_TTS_VOICES_URL = 'https://speech.platform.bing.com/consumer/speech/synthesize/readaloud/voices/list?trustedclienttoken=6A5AA1D4EAFF4E9FB37E23D68491D6F4';
  EDGE_TTS_WSS_HOST = 'speech.platform.bing.com';
  EDGE_TTS_WSS_PATH = '/consumer/speech/synthesize/readaloud/edge/v1?TrustedClientToken=6A5AA1D4EAFF4E9FB37E23D68491D6F4&ConnectionId=';
  EDGE_TTS_ORIGIN = 'https://speech.platform.bing.com';
  EDGE_TTS_UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';
  TURN_END = 'Path:turn end';

{ TEdgeTTSBackend }

constructor TEdgeTTSBackend.Create;
begin
  inherited Create;
  FLastError := '';
  FVoicesLoaded := False;
  FClient := THTTPClient.Create;
end;

destructor TEdgeTTSBackend.Destroy;
begin
  FreeAndNil(FClient);
  inherited;
end;

class function TEdgeTTSBackend.GenerateRequestID: string;
var
  GUID: TGUID;
begin
  CreateGUID(GUID);
  Result := GUIDToString(GUID);
  Result := StringReplace(Result, '{', '', [rfReplaceAll]);
  Result := StringReplace(Result, '}', '', [rfReplaceAll]);
  Result := StringReplace(Result, '-', '', [rfReplaceAll]);
  Result := LowerCase(Result);
end;

class function TEdgeTTSBackend.ParseGender(const AGender: string): string;
var
  G: string;
begin
  G := LowerCase(AGender);
  if (G = 'male') or (G = 'boy') then
    Result := 'male'
  else if (G = 'female') or (G = 'girl') then
    Result := 'female'
  else
    Result := 'neutral';
end;

function TEdgeTTSBackend.IsAvailable: Boolean;
begin
  Result := True;
end;

procedure TEdgeTTSBackend.Stop;
begin
  // Edge TTS is synchronous — no background operation to stop
end;

function TEdgeTTSBackend.FetchVoices: TArray<TTTSVoice>;
var
  Response: IHTTPResponse;
  JSONArr: TJSONArray;
  JObj: TJSONObject;
  I: Integer;
  List: TList<TTTSVoice>;
  Info: TTTSVoice;
begin
  Result := nil;
  try
    Response := FClient.Get(EDGE_TTS_VOICES_URL);
    if Response.StatusCode <> 200 then
    begin
      FLastError := 'Edge-TTS voices HTTP ' + IntToStr(Response.StatusCode);
      Exit;
    end;

    JSONArr := TJSONObject.ParseJSONValue(Response.ContentAsString) as TJSONArray;
    if JSONArr = nil then
    begin
      FLastError := 'Edge-TTS voices: invalid JSON';
      Exit;
    end;

    try
      List := TList<TTTSVoice>.Create;
      try
        for I := 0 to JSONArr.Count - 1 do
        begin
          JObj := JSONArr.Items[I] as TJSONObject;
          Info.Id := JObj.GetValue<string>('ShortName', '');
          Info.Name := JObj.GetValue<string>('Name', '');
          Info.Language := JObj.GetValue<string>('Locale', '');
          Info.Gender := ParseGender(JObj.GetValue<string>('Gender', ''));
          List.Add(Info);
        end;
        Result := List.ToArray;
      finally
        List.Free;
      end;
    finally
      JSONArr.Free;
    end;
  except
    on E: Exception do
      FLastError := 'Edge-TTS fetch voices: ' + E.Message;
  end;
end;

function TEdgeTTSBackend.SupportedVoices(const ALanguage: string): TArray<TTTSVoice>;
var
  All: TArray<TTTSVoice>;
  Filtered: TList<TTTSVoice>;
  I: Integer;
begin
  if not FVoicesLoaded then
  begin
    FVoices := FetchVoices;
    FVoicesLoaded := True;
  end;

  if ALanguage = '' then
    Exit(FVoices);

  Filtered := TList<TTTSVoice>.Create;
  try
    for I := 0 to High(FVoices) do
      if (ALanguage = '') or SameText(Copy(FVoices[I].Language, 1, Length(ALanguage)), ALanguage) then
        Filtered.Add(FVoices[I]);
    Result := Filtered.ToArray;
  finally
    Filtered.Free;
  end;
end;

function TEdgeTTSBackend.BuildSSML(const AText: string;
  const AOptions: TTTSOptions): string;

  function RateStr(AVal: Integer): string;
  begin
    if AVal = 0 then Result := 'default'
    else if AVal > 0 then Result := '+' + IntToStr(AVal) + '%'
    else Result := IntToStr(AVal) + '%';
  end;

  function VolumeStr(AVal: Integer): string;
  begin
    if AVal = 0 then Result := 'default'
    else if AVal > 0 then Result := '+' + IntToStr(AVal) + '%'
    else Result := IntToStr(AVal) + '%';
  end;

var
  VoiceName: string;
begin
  if AOptions.VoiceId = '' then
    VoiceName := 'zh-CN-XiaoxiaoNeural'
  else
    VoiceName := AOptions.VoiceId;

  Result :=
    '<speak version=' + QuotedStr('1.0') +
    ' xmlns=' + QuotedStr('http://www.w3.org/2001/10/synthesis') +
    ' xml:lang=' + QuotedStr('en-US') + '>' +
    '<voice name=' + QuotedStr(VoiceName) + '>' +
    '<prosody rate=' + QuotedStr(RateStr(AOptions.Rate)) +
    ' volume=' + QuotedStr(VolumeStr(AOptions.Volume)) + '>' +
    TNetEncoding.HTML.Encode(AText) +
    '</prosody></voice></speak>';
end;

function TEdgeTTSBackend.Synthesize(const ASSML: string): TBytes;
var
  hSession, hConnect, hRequest: HINTERNET;
  ConnID, ReqID, TimeStamp: string;
  ConfigMsg, SSMLMsg: UTF8String;
  MS: TMemoryStream;
  Done: Boolean;
  Buf: TArray<Byte>;
  BytesRead: Cardinal;
  BufSize: Cardinal;
  wsStatus: Cardinal;
  TextPart: string;
  AudioStartIdx, I: Integer;
  ErrMode: UINT;
begin
  Result := nil;
  FLastError := '';
  hSession := nil;
  hConnect := nil;
  hRequest := nil;

  ConnID := GenerateRequestID;
  ReqID := GenerateRequestID;
  TimeStamp := DateToISO8601(Now, False);

  ConfigMsg := UTF8String(
    'X-Timestamp:' + TimeStamp + #13#10 +
    'Content-Type:application/json; charset=utf-8' + #13#10 +
    'Path:speech.config' + #13#10 +
    #13#10 +
    '{"context":{"synthesis":{"audio":{"metadataoptions":{' +
    '"sentenceBoundaryEnabled":"false","wordBoundaryEnabled":"true"},' +
    '"outputFormat":"audio-24khz-48kbitrate-mono-mp3"}}}}');

  SSMLMsg := UTF8String(
    'X-RequestId:' + ReqID + #13#10 +
    'Content-Type:application/ssml+xml' + #13#10 +
    'X-Timestamp:' + TimeStamp + 'Z' + #13#10 +
    'Path:ssml' + #13#10 +
    #13#10 +
    ASSML);

  ErrMode := SetErrorMode(SEM_FAILCRITICALERRORS);
  try
    hSession := WinHttpOpen(PChar(EDGE_TTS_UA), WINHTTP_ACCESS_TYPE_DEFAULT_PROXY,
      WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0);
    if hSession = nil then
    begin
      FLastError := 'WinHttpOpen failed: ' + SysErrorMessage(GetLastError);
      Exit;
    end;

    hConnect := WinHttpConnect(hSession, PChar(EDGE_TTS_WSS_HOST),
      INTERNET_DEFAULT_HTTPS_PORT, 0);
    if hConnect = nil then
    begin
      FLastError := 'WinHttpConnect failed: ' + SysErrorMessage(GetLastError);
      Exit;
    end;

    hRequest := WinHttpOpenRequest(hConnect, PChar('GET'),
      PChar(EDGE_TTS_WSS_PATH + ConnID), nil, WINHTTP_NO_REFERER,
      WINHTTP_DEFAULT_ACCEPT_TYPES, WINHTTP_FLAG_SECURE);
    if hRequest = nil then
    begin
      FLastError := 'WinHttpOpenRequest failed: ' + SysErrorMessage(GetLastError);
      Exit;
    end;

    if not WinHttpSetOption(hRequest, WINHTTP_OPTION_UPGRADE_TO_WEB_SOCKET, nil, 0) then
    begin
      FLastError := 'WinHttpSetOption(UPGRADE) failed: ' + SysErrorMessage(GetLastError);
      Exit;
    end;

    WinHttpAddRequestHeaders(hRequest, PChar('Origin: ' + EDGE_TTS_ORIGIN), $FFFFFFFF, WINHTTP_ADDREQ_FLAG_ADD);
    WinHttpAddRequestHeaders(hRequest, PChar('Pragma: no-cache'), $FFFFFFFF, WINHTTP_ADDREQ_FLAG_ADD);
    WinHttpAddRequestHeaders(hRequest, PChar('Cache-Control: no-cache'), $FFFFFFFF, WINHTTP_ADDREQ_FLAG_ADD);

    if not WinHttpSendRequest(hRequest, WINHTTP_NO_ADDITIONAL_HEADERS, 0,
      WINHTTP_NO_REQUEST_DATA, 0, 0, 0) then
    begin
      FLastError := 'WinHttpSendRequest failed: ' + SysErrorMessage(GetLastError);
      Exit;
    end;

    if not WinHttpReceiveResponse(hRequest, nil) then
    begin
      FLastError := 'WinHttpReceiveResponse failed: ' + SysErrorMessage(GetLastError);
      Exit;
    end;

    var hWebSocket: HINTERNET := WinHttpWebSocketCompleteUpgrade(hRequest, nil);
    if hWebSocket = nil then
    begin
      FLastError := 'WebSocket upgrade failed: ' + SysErrorMessage(GetLastError);
      Exit;
    end;

    WinHttpCloseHandle(hRequest);
    hRequest := nil;

    try
      if WinHttpWebSocketSend(hWebSocket, WINHTTP_WEB_SOCKET_UTF8_MESSAGE_TYPE,
        @ConfigMsg[1], Length(ConfigMsg)) <> NO_ERROR then
      begin
        FLastError := 'WebSocket send config failed: ' + SysErrorMessage(GetLastError);
        Exit;
      end;

      if WinHttpWebSocketSend(hWebSocket, WINHTTP_WEB_SOCKET_UTF8_MESSAGE_TYPE,
        @SSMLMsg[1], Length(SSMLMsg)) <> NO_ERROR then
      begin
        FLastError := 'WebSocket send SSML failed: ' + SysErrorMessage(GetLastError);
        Exit;
      end;

      MS := TMemoryStream.Create;
      try
        Done := False;
        SetLength(Buf, 65536);

        while not Done do
        begin
          BytesRead := 0;
          BufSize := Length(Buf);
          wsStatus := 0;

          if WinHttpWebSocketReceive(hWebSocket, @Buf[0], BufSize, @BytesRead, @wsStatus) <> NO_ERROR then
          begin
            FLastError := 'WebSocket receive failed: ' + SysErrorMessage(GetLastError);
            Break;
          end;

          if BytesRead = 0 then
            Break;

          if (wsStatus = WINHTTP_WEB_SOCKET_BINARY_MESSAGE_BUFFER_TYPE) or
             (wsStatus = WINHTTP_WEB_SOCKET_BINARY_FRAGMENT_BUFFER_TYPE) then
          begin
            AudioStartIdx := -1;
            for I := 0 to Integer(BytesRead) - 5 do
            begin
              if (Buf[I] = Ord(#13)) and (Buf[I+1] = Ord(#10)) and
                 (Buf[I+2] = Ord(#13)) and (Buf[I+3] = Ord(#10)) then
              begin
                AudioStartIdx := I + 4;
                Break;
              end;
            end;

            if AudioStartIdx > 0 then
              MS.Write(Buf[AudioStartIdx], BytesRead - Cardinal(AudioStartIdx));
          end
          else if (wsStatus = WINHTTP_WEB_SOCKET_UTF8_MESSAGE_TYPE) or
                  (wsStatus = WINHTTP_WEB_SOCKET_UTF8_FRAGMENT_BUFFER_TYPE) then
          begin
            SetString(TextPart, PAnsiChar(@Buf[0]), BytesRead);
            if Pos(TURN_END, TextPart) > 0 then
              Done := True;
          end
          else if wsStatus = WINHTTP_WEB_SOCKET_CLOSE_BUFFER_TYPE then
            Break;
        end;

        if MS.Size > 0 then
        begin
          SetLength(Result, MS.Size);
          MS.Position := 0;
          MS.Read(Result[0], MS.Size);
        end;
      finally
        MS.Free;
      end;

      WinHttpWebSocketClose(hWebSocket, WINHTTP_WEB_SOCKET_SUCCESS_CLOSE_STATUS, nil, 0);
    finally
      WinHttpCloseHandle(hWebSocket);
    end;
  except
    on E: Exception do
      FLastError := 'Edge-TTS synthesize: ' + E.Message;
  end;

  SetErrorMode(ErrMode);
  if hRequest <> nil then WinHttpCloseHandle(hRequest);
  if hConnect <> nil then WinHttpCloseHandle(hConnect);
  if hSession <> nil then WinHttpCloseHandle(hSession);
end;

procedure TEdgeTTSBackend.Speak(const AText: string; const AOptions: TTTSOptions);
var
  SSML: string;
  AudioData: TBytes;
begin
  FLastError := '';
  if Trim(AText) = '' then
  begin
    FLastError := 'Empty text';
    Exit;
  end;
  SSML := BuildSSML(AText, AOptions);
  AudioData := Synthesize(SSML);
  // Audio data is returned as TBytes; downstream can save/play as needed
end;

procedure TEdgeTTSBackend.SpeakAsync(const AText: string;
  const AOptions: TTTSOptions; AOnDone: TProc);
begin
  FOnDone := AOnDone;
  TThread.CreateAnonymousThread(
    procedure
    begin
      Speak(AText, AOptions);
      if Assigned(FOnDone) then
        TThread.Queue(nil,
          procedure
          begin
            FOnDone();
          end);
    end).Start;
end;

initialization
  var Info: TSpeechBackendInfo;
  Info.Kind := sbkTTS;
  Info.Name := 'Edge';
  Info.IsCloud := True;
  Info.RequiresMic := False;
  Info.SupportsBatch := False;
  Info.SupportsStreaming := False;
  Info.SupportsGrammar := False;
  Info.IsAvailableFunc := function: Boolean begin Result := True; end;
  Info.Enabled := True;
  Info.Priority := 10;
  TSpeechRegistry.Register(Info);

finalization
  TSpeechRegistry.Disable('Edge', sbkTTS);

end.