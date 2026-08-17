unit DeepBase.Speech.TTS.StepFun;

{ ============================================================================
  DeepBase.Speech.TTS.StepFun — StepFun (阶跃星辰) TTS Backend via REST API.
  Uses stepaudio-2.5-tts model with instruction/emotion support.
  Supports voice cloning (upload, create, delete, preview).
  Adapted from DeepInput/uTTS.StepFun.pas, implements ITTSBackend interface.
  Self-registers to TSpeechRegistry on initialization.
  ============================================================================ }

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.Net.HTTPClient, System.Net.URLClient, System.Net.Mime, System.JSON,
  DeepBase.Speech.Types, DeepBase.Speech.Registry;

type
  TStepFunTTSBackend = class(TInterfacedObject, ITTSBackend)
  private
    FApiKey: string;
    FLastError: string;
    FVoices: TArray<TTTSVoice>;
    FVoicesLoaded: Boolean;
    FClient: THTTPClient;
    FOnDone: TProc;

    function AuthHeaders: TNetHeaders;
    function JSONHeaders: TNetHeaders;
    function MapSpeed(ASpeed: Integer): Double;
    function MapVolume(AVolume: Integer): Double;
    function FetchSystemVoices: TArray<TTTSVoice>;
    function FetchClonedVoices: TArray<TTTSVoice>;
    function PostJSON(const APath: string; const AJSON: string): IHTTPResponse;
    function GetJSON(const APath: string): IHTTPResponse;
  public
    constructor Create(const AApiKey: string);
    destructor Destroy; override;

    function IsAvailable: Boolean;
    function SupportedVoices(const ALanguage: string): TArray<TTTSVoice>;
    procedure Speak(const AText: string; const AOptions: TTTSOptions);
    procedure SpeakAsync(const AText: string; const AOptions: TTTSOptions;
      AOnDone: TProc);
    procedure Stop;

    // Voice cloning
    function UploadFile(const AFilePath: string): string;
    function CreateVoice(const AFileID, AName: string;
      const ADescription: string = ''): string;
    function DeleteVoice(const AVoiceID: string): Boolean;
    function PreviewVoice(const AVoiceID, AText: string): TBytes;
    property ApiKey: string read FApiKey write FApiKey;
  end;

implementation

uses
  System.NetEncoding;

const
  STEPFUN_BASE_URL = 'https://api.stepfun.com/v1';
  DEFAULT_TTS_MODEL = 'stepaudio-2.5-tts';

{ TStepFunTTSBackend }

constructor TStepFunTTSBackend.Create(const AApiKey: string);
begin
  inherited Create;
  FApiKey := AApiKey;
  FLastError := '';
  FVoicesLoaded := False;
  FClient := THTTPClient.Create;
  FClient.ConnectionTimeout := 30000;
  FClient.ResponseTimeout := 60000;
end;

destructor TStepFunTTSBackend.Destroy;
begin
  FreeAndNil(FClient);
  inherited;
end;

function TStepFunTTSBackend.AuthHeaders: TNetHeaders;
begin
  SetLength(Result, 1);
  Result[0].Name := 'Authorization';
  Result[0].Value := 'Bearer ' + FApiKey;
end;

function TStepFunTTSBackend.JSONHeaders: TNetHeaders;
begin
  SetLength(Result, 2);
  Result[0].Name := 'Authorization';
  Result[0].Value := 'Bearer ' + FApiKey;
  Result[1].Name := 'Content-Type';
  Result[1].Value := 'application/json';
end;

function TStepFunTTSBackend.MapSpeed(ASpeed: Integer): Double;
begin
  if ASpeed < -100 then ASpeed := -100;
  if ASpeed > 100 then ASpeed := 100;
  if ASpeed >= 0 then
    Result := 1.0 + (ASpeed / 100.0)
  else
    Result := 1.0 + (ASpeed / 100.0) * 0.5;
end;

function TStepFunTTSBackend.MapVolume(AVolume: Integer): Double;
begin
  if AVolume < -100 then AVolume := -100;
  if AVolume > 100 then AVolume := 100;
  if AVolume >= 0 then
    Result := 1.0 + (AVolume / 100.0)
  else
    Result := 1.0 + (AVolume / 100.0) * 0.9;
end;

function TStepFunTTSBackend.IsAvailable: Boolean;
begin
  Result := FApiKey <> '';
end;

procedure TStepFunTTSBackend.Stop;
begin
  // Synchronous API — no background operation to stop
end;

function TStepFunTTSBackend.PostJSON(const APath: string;
  const AJSON: string): IHTTPResponse;
var
  Bytes: TBytes;
  Stream: TBytesStream;
begin
  Bytes := TEncoding.UTF8.GetBytes(AJSON);
  Stream := TBytesStream.Create(Bytes);
  try
    Result := FClient.Post(STEPFUN_BASE_URL + APath, Stream, nil, JSONHeaders);
  finally
    Stream.Free;
  end;
end;

function TStepFunTTSBackend.GetJSON(const APath: string): IHTTPResponse;
begin
  Result := FClient.Get(STEPFUN_BASE_URL + APath, nil, JSONHeaders);
end;

function TStepFunTTSBackend.FetchSystemVoices: TArray<TTTSVoice>;
var
  Response: IHTTPResponse;
  JSONVal: TJSONValue;
  JSONArr: TJSONArray;
  I: Integer;
  List: TList<TTTSVoice>;
  Info: TTTSVoice;
begin
  Result := nil;
  try
    Response := GetJSON('/audio/system_voices?model=' + DEFAULT_TTS_MODEL);
    if Response.StatusCode <> 200 then
    begin
      FLastError := 'StepFun voices HTTP ' + IntToStr(Response.StatusCode);
      Exit;
    end;

    JSONVal := TJSONObject.ParseJSONValue(Response.ContentAsString);
    if JSONVal = nil then Exit;

    try
      // BUG-427 FIX (E-008): 'voices' key may be absent or non-array. The old
      // `GetValue('voices') as TJSONArray` raised EInvalidCast when GetValue returned
      // nil (key missing), so the following nil-check was dead code and FLastError got
      // a confusing "Invalid cast" message instead of a clear error. Use `is` + hard
      // cast so a missing/non-array key returns cleanly with a descriptive message.
      var VoicesVal := (JSONVal as TJSONObject).GetValue('voices');
      if not (VoicesVal is TJSONArray) then
      begin
        FLastError := 'StepFun fetch system voices: response missing "voices" array';
        Exit;
      end;
      JSONArr := TJSONArray(VoicesVal);

      List := TList<TTTSVoice>.Create;
      try
        for I := 0 to JSONArr.Count - 1 do
        begin
          Info := Default(TTTSVoice);
          var JObj := JSONArr.Items[I] as TJSONObject;
          Info.Id := JObj.GetValue<string>('voice_id', '');
          Info.Name := JObj.GetValue<string>('name', Info.Id);
          Info.Language := JObj.GetValue<string>('language', '');
          Info.Gender := 'neutral';

          var Tags := JObj.GetValue('tags');
          if Tags is TJSONArray then
          begin
            var TagArr := TJSONArray(Tags);
            for var J := 0 to TagArr.Count - 1 do
            begin
              var Tag := LowerCase(TagArr.Items[J].Value);
              if Tag = 'male' then Info.Gender := 'male'
              else if Tag = 'female' then Info.Gender := 'female';
            end;
          end;
          List.Add(Info);
        end;
        Result := List.ToArray;
      finally
        List.Free;
      end;
    finally
      JSONVal.Free;
    end;
  except
    on E: Exception do
      FLastError := 'StepFun fetch voices: ' + E.Message;
  end;
end;

function TStepFunTTSBackend.FetchClonedVoices: TArray<TTTSVoice>;
var
  Response: IHTTPResponse;
  JSONVal: TJSONValue;
  JSONArr: TJSONArray;
  I: Integer;
  List: TList<TTTSVoice>;
  Info: TTTSVoice;
begin
  Result := nil;
  try
    Response := GetJSON('/audio/voices');
    if Response.StatusCode <> 200 then Exit;

    JSONVal := TJSONObject.ParseJSONValue(Response.ContentAsString);
    if JSONVal = nil then Exit;

    try
      // BUG-427 FIX (E-008): same as FetchSystemVoices - avoid `as TJSONArray`
      // EInvalidCast when 'voices' is missing; use `is` + hard cast + clear error.
      var VoicesVal := (JSONVal as TJSONObject).GetValue('voices');
      if not (VoicesVal is TJSONArray) then
      begin
        FLastError := 'StepFun fetch cloned voices: response missing "voices" array';
        Exit;
      end;
      JSONArr := TJSONArray(VoicesVal);

      List := TList<TTTSVoice>.Create;
      try
        for I := 0 to JSONArr.Count - 1 do
        begin
          Info := Default(TTTSVoice);
          var JObj := JSONArr.Items[I] as TJSONObject;
          Info.Id := JObj.GetValue<string>('voice_id', '');
          Info.Name := JObj.GetValue<string>('name', Info.Id) + ' [cloned]';
          Info.Language := 'cloned';
          Info.Gender := 'neutral';
          List.Add(Info);
        end;
        Result := List.ToArray;
      finally
        List.Free;
      end;
    finally
      JSONVal.Free;
    end;
  except
    on E: Exception do
      FLastError := 'StepFun fetch cloned: ' + E.Message;
  end;
end;

function TStepFunTTSBackend.SupportedVoices(const ALanguage: string): TArray<TTTSVoice>;
begin
  if not FVoicesLoaded then
  begin
    var SysVoices := FetchSystemVoices;
    var CloneVoices := FetchClonedVoices;
    SetLength(FVoices, Length(SysVoices) + Length(CloneVoices));
    for var I := 0 to Length(SysVoices) - 1 do
      FVoices[I] := SysVoices[I];
    for var I := 0 to Length(CloneVoices) - 1 do
      FVoices[Length(SysVoices) + I] := CloneVoices[I];
    FVoicesLoaded := True;
  end;

  if ALanguage = '' then
    Exit(FVoices);

  var Filtered := TList<TTTSVoice>.Create;
  try
    for var I := 0 to High(FVoices) do
      if SameText(Copy(FVoices[I].Language, 1, Length(ALanguage)), ALanguage) then
        Filtered.Add(FVoices[I]);
    Result := Filtered.ToArray;
  finally
    Filtered.Free;
  end;
end;

procedure TStepFunTTSBackend.Speak(const AText: string; const AOptions: TTTSOptions);
var
  ReqBody: TJSONObject;
  Response: IHTTPResponse;
  VoiceName: string;
begin
  FLastError := '';

  if Trim(AText) = '' then
  begin
    FLastError := 'Empty text';
    Exit;
  end;

  VoiceName := AOptions.VoiceId;
  if VoiceName = '' then
    VoiceName := 'cixingnansheng';

  ReqBody := TJSONObject.Create;
  try
    ReqBody.AddPair('model', DEFAULT_TTS_MODEL);
    ReqBody.AddPair('input', AText);
    ReqBody.AddPair('voice', VoiceName);
    ReqBody.AddPair('response_format', 'wav');
    ReqBody.AddPair('speed', MapSpeed(AOptions.Rate));
    ReqBody.AddPair('volume', MapVolume(AOptions.Volume));

    Response := PostJSON('/audio/speech', ReqBody.ToJSON);
  finally
    ReqBody.Free;
  end;

  if Response.StatusCode <> 200 then
  begin
    FLastError := 'StepFun TTS HTTP ' + IntToStr(Response.StatusCode);
    Exit;
  end;

  var RespStream := Response.ContentStream;
  if (RespStream = nil) or (RespStream.Size = 0) then
  begin
    FLastError := 'StepFun TTS: empty response';
    Exit;
  end;
end;

procedure TStepFunTTSBackend.SpeakAsync(const AText: string;
  const AOptions: TTTSOptions; AOnDone: TProc);
begin
  FOnDone := AOnDone;
  TThread.CreateAnonymousThread(
    procedure
    begin
      Speak(AText, AOptions);
      if Assigned(AOnDone) then
        TThread.Queue(nil,
          procedure
          begin
            AOnDone();
          end);
    end).Start;
end;

function TStepFunTTSBackend.UploadFile(const AFilePath: string): string;
var
  MultiPart: TMultipartFormData;
  Response: IHTTPResponse;
  JSONVal: TJSONValue;
begin
  Result := '';
  FLastError := '';

  if not FileExists(AFilePath) then
  begin
    FLastError := 'File not found: ' + AFilePath;
    Exit;
  end;

  MultiPart := TMultipartFormData.Create;
  try
    MultiPart.AddField('purpose', 'storage');
    MultiPart.AddFile('file', AFilePath);

    Response := FClient.Post(STEPFUN_BASE_URL + '/files', MultiPart, nil, AuthHeaders);

    if Response.StatusCode <> 200 then
    begin
      FLastError := 'StepFun upload HTTP ' + IntToStr(Response.StatusCode);
      Exit;
    end;

    JSONVal := TJSONObject.ParseJSONValue(Response.ContentAsString);
    if JSONVal = nil then
    begin
      FLastError := 'StepFun upload: invalid JSON';
      Exit;
    end;

    try
      Result := (JSONVal as TJSONObject).GetValue<string>('id', '');
    finally
      JSONVal.Free;
    end;
  finally
    MultiPart.Free;
  end;
end;

function TStepFunTTSBackend.CreateVoice(const AFileID, AName,
  ADescription: string): string;
var
  ReqBody: TJSONObject;
  Response: IHTTPResponse;
  JSONVal: TJSONValue;
begin
  Result := '';
  FLastError := '';

  ReqBody := TJSONObject.Create;
  try
    ReqBody.AddPair('model', DEFAULT_TTS_MODEL);
    ReqBody.AddPair('file_id', AFileID);
    ReqBody.AddPair('name', AName);
    if ADescription <> '' then
      ReqBody.AddPair('description', ADescription);

    Response := PostJSON('/audio/voices', ReqBody.ToJSON);
  finally
    ReqBody.Free;
  end;

  if Response.StatusCode <> 200 then
  begin
    FLastError := 'StepFun create voice HTTP ' + IntToStr(Response.StatusCode);
    Exit;
  end;

  JSONVal := TJSONObject.ParseJSONValue(Response.ContentAsString);
  if JSONVal = nil then
  begin
    FLastError := 'StepFun create voice: invalid JSON';
    Exit;
  end;

  try
    Result := (JSONVal as TJSONObject).GetValue<string>('voice_id', '');
  finally
    JSONVal.Free;
  end;

  FVoicesLoaded := False;
end;

function TStepFunTTSBackend.DeleteVoice(const AVoiceID: string): Boolean;
var
  Response: IHTTPResponse;
begin
  Result := False;
  FLastError := '';

  try
    Response := FClient.Delete(STEPFUN_BASE_URL + '/audio/voices/' +
      AVoiceID, nil, JSONHeaders);
    Result := Response.StatusCode = 200;
    if not Result then
      FLastError := 'StepFun delete voice HTTP ' + IntToStr(Response.StatusCode);
    if Result then
      FVoicesLoaded := False;
  except
    on E: Exception do
      FLastError := 'StepFun delete voice: ' + E.Message;
  end;
end;

function TStepFunTTSBackend.PreviewVoice(const AVoiceID, AText: string): TBytes;
var
  ReqBody: TJSONObject;
  Response: IHTTPResponse;
begin
  Result := nil;
  FLastError := '';

  ReqBody := TJSONObject.Create;
  try
    ReqBody.AddPair('voice_id', AVoiceID);
    ReqBody.AddPair('model', DEFAULT_TTS_MODEL);
    ReqBody.AddPair('input', AText);
    ReqBody.AddPair('response_format', 'wav');

    Response := PostJSON('/audio/voices/preview', ReqBody.ToJSON);
  finally
    ReqBody.Free;
  end;

  if Response.StatusCode <> 200 then
  begin
    FLastError := 'StepFun preview HTTP ' + IntToStr(Response.StatusCode);
    Exit;
  end;

  var RespStream := Response.ContentStream;
  if (RespStream = nil) or (RespStream.Size = 0) then
  begin
    FLastError := 'StepFun preview: empty response';
    Exit;
  end;

  RespStream.Position := 0;
  SetLength(Result, RespStream.Size);
  RespStream.Read(Result[0], RespStream.Size);
end;

initialization
  var Info: TSpeechBackendInfo;
  Info.Kind := sbkTTS;
  Info.Name := 'StepFun';
  Info.IsCloud := True;
  Info.RequiresMic := False;
  Info.SupportsBatch := False;
  Info.SupportsStreaming := False;
  Info.SupportsGrammar := False;
  Info.IsAvailableFunc := function: Boolean begin Result := True; end;
  Info.Enabled := True;
  Info.Priority := 30;
  TSpeechRegistry.Register(Info);

finalization
  TSpeechRegistry.Disable('StepFun', sbkTTS);

end.