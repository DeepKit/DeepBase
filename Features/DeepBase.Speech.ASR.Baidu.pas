unit DeepBase.Speech.ASR.Baidu;

interface

uses
  System.Net.URLClient,
  System.SysUtils,
  DeepBase.Net.Transport,
  DeepBase.Speech.Types;

type
  TSpeechBaiduConfig = record
    ApiKey: string;
    SecretKey: string;
    Cuid: string;
    Pid: Integer;
    TimeoutMs: Integer;
    class function Create(const AApiKey, ASecretKey: string;
      const ACuid: string = 'DeepBase'; APid: Integer = 1537;
      ATimeoutMs: Integer = 30000): TSpeechBaiduConfig; static;
  end;

  TSpeechHttpResponse = record
    StatusCode: Integer;
    Body: string;
    StatusText: string;
    class function Create(AStatusCode: Integer; const ABody: string;
      const AStatusText: string = ''): TSpeechHttpResponse; static;
  end;

  ISpeechHttpTransport = interface
    ['{94D63528-83E5-4359-B52B-9E267DFE2BE1}']
    function Send(const AMethod, AUrl, ABody: string;
      const AHeaders: TNetHeaders): TSpeechHttpResponse;
  end;

  TSpeechHttpClientTransport = class(TInterfacedObject, ISpeechHttpTransport)
  private
    FHttpClient: TObject;
  public
    constructor Create(ATimeoutMs: Integer = 30000);
    destructor Destroy; override;
    function Send(const AMethod, AUrl, ABody: string;
      const AHeaders: TNetHeaders): TSpeechHttpResponse;
  end;

  TSpeechUnifiedHttpTransport = class(TInterfacedObject, ISpeechHttpTransport)
  private
    FTransport: IDeepBaseHttpTransport;
    FTimeoutMs: Integer;
  public
    constructor Create(const ATransport: IDeepBaseHttpTransport;
      ATimeoutMs: Integer = 30000);
    function Send(const AMethod, AUrl, ABody: string;
      const AHeaders: TNetHeaders): TSpeechHttpResponse;
  end;

  TDeepBaseBaiduSpeechRecognizer = class(TInterfacedObject, ISpeechRecognizer)
  private
    FConfig: TSpeechBaiduConfig;
    FTransport: ISpeechHttpTransport;
    FAccessToken: string;
    FTokenExpireTime: TDateTime;
    FLastError: string;
    function ObtainToken: string;
  public
    constructor Create(const AConfig: TSpeechBaiduConfig;
      const ATransport: ISpeechHttpTransport = nil);
    function CheckStatus(out AError: string): Boolean;
    function Recognize(const AAudio: TSpeechAudioData;
      const AOptions: TSpeechRecognitionOptions): TSpeechRecognitionResult;
    property LastError: string read FLastError;
  end;

implementation

uses
  System.Classes,
  System.JSON,
  System.Net.HttpClient,
  System.NetEncoding;

const
  BaiduTokenUrl = 'https://aip.baidubce.com/oauth/2.0/token';
  BaiduRecognizeUrl = 'https://vop.baidu.com/server_api';

function IsSuccessStatus(AStatusCode: Integer): Boolean;
begin
  Result := (AStatusCode >= 200) and (AStatusCode < 300);
end;

function JsonString(AJson: TJSONObject; const AName, ADefault: string): string;
var
  Value: TJSONValue;
begin
  Result := ADefault;
  if not Assigned(AJson) then
    Exit;
  Value := AJson.FindValue(AName);
  if Assigned(Value) and not (Value is TJSONNull) then
    Result := Value.Value;
end;

function JsonInt(AJson: TJSONObject; const AName: string;
  ADefault: Integer): Integer;
var
  Value: TJSONValue;
begin
  Result := ADefault;
  if not Assigned(AJson) then
    Exit;
  Value := AJson.FindValue(AName);
  if Value is TJSONNumber then
    Result := TJSONNumber(Value).AsInt
  else if Assigned(Value) and not (Value is TJSONNull) then
    Result := StrToIntDef(Value.Value, ADefault);
end;

function ParseJsonObject(const ABody: string; out AJson: TJSONObject): Boolean;
var
  Value: TJSONValue;
begin
  AJson := nil;
  Value := TJSONObject.ParseJSONValue(ABody);
  if Value is TJSONObject then
  begin
    AJson := TJSONObject(Value);
    Exit(True);
  end;
  Value.Free;
  Result := False;
end;

function HeaderContentTypeJson: TNetHeaders;
begin
  SetLength(Result, 1);
  Result[0] := TNameValuePair.Create('Content-Type', 'application/json');
end;

class function TSpeechBaiduConfig.Create(const AApiKey, ASecretKey,
  ACuid: string; APid, ATimeoutMs: Integer): TSpeechBaiduConfig;
begin
  Result.ApiKey := AApiKey;
  Result.SecretKey := ASecretKey;
  Result.Cuid := ACuid;
  Result.Pid := APid;
  Result.TimeoutMs := ATimeoutMs;
end;

class function TSpeechHttpResponse.Create(AStatusCode: Integer;
  const ABody, AStatusText: string): TSpeechHttpResponse;
begin
  Result.StatusCode := AStatusCode;
  Result.Body := ABody;
  Result.StatusText := AStatusText;
end;

constructor TSpeechHttpClientTransport.Create(ATimeoutMs: Integer);
var
  Client: THTTPClient;
begin
  inherited Create;
  Client := THTTPClient.Create;
  Client.ConnectionTimeout := ATimeoutMs;
  Client.ResponseTimeout := ATimeoutMs;
  FHttpClient := Client;
end;

destructor TSpeechHttpClientTransport.Destroy;
begin
  FHttpClient.Free;
  inherited;
end;

function TSpeechHttpClientTransport.Send(const AMethod, AUrl, ABody: string;
  const AHeaders: TNetHeaders): TSpeechHttpResponse;
var
  BodyStream: TStringStream;
  Client: THTTPClient;
  Response: IHTTPResponse;
begin
  Client := THTTPClient(FHttpClient);
  BodyStream := nil;
  try
    if SameText(AMethod, 'GET') then
      Response := Client.Get(AUrl, nil, AHeaders)
    else if SameText(AMethod, 'POST') then
    begin
      BodyStream := TStringStream.Create(ABody, TEncoding.UTF8);
      Response := Client.Post(AUrl, BodyStream, nil, AHeaders);
    end
    else
      raise EDeepBaseSpeechProviderError.Create('Unsupported HTTP method: ' + AMethod);

    if Assigned(Response) then
      Result := TSpeechHttpResponse.Create(Response.StatusCode,
        Response.ContentAsString(TEncoding.UTF8),
        UTF8ToString(RawByteString(Response.StatusText)))
    else
      Result := TSpeechHttpResponse.Create(0, '', 'No response');
  finally
    BodyStream.Free;
  end;
end;

{ TSpeechUnifiedHttpTransport }

constructor TSpeechUnifiedHttpTransport.Create(
  const ATransport: IDeepBaseHttpTransport; ATimeoutMs: Integer);
begin
  inherited Create;
  if not Assigned(ATransport) then
    raise EDeepBaseSpeechProviderError.Create(
      'Speech unified transport requires IDeepBaseHttpTransport');
  if ATimeoutMs <= 0 then
    ATimeoutMs := 30000;
  FTransport := ATransport;
  FTimeoutMs := ATimeoutMs;
end;

function TSpeechUnifiedHttpTransport.Send(const AMethod, AUrl, ABody: string;
  const AHeaders: TNetHeaders): TSpeechHttpResponse;
var
  Request: TDeepBaseHttpTransportRequest;
  Response: TDeepBaseHttpTransportResponse;
begin
  Request := TDeepBaseHttpTransportRequest.Create(
    DeepBaseHttpMethodFromString(AMethod), AUrl);
  Request.Body := ABody;
  Request.Headers := AHeaders;
  Request.ContentType := 'application/json';
  Request.TimeoutMs := FTimeoutMs;

  Response := FTransport.Send(Request);
  Result := TSpeechHttpResponse.Create(Response.StatusCode, Response.Body,
    Response.StatusText);
end;

constructor TDeepBaseBaiduSpeechRecognizer.Create(
  const AConfig: TSpeechBaiduConfig; const ATransport: ISpeechHttpTransport);
begin
  inherited Create;
  FConfig := AConfig;
  FAccessToken := '';
  FTokenExpireTime := 0;
  FLastError := '';
  FTransport := ATransport;
  if FTransport = nil then
    FTransport := TSpeechHttpClientTransport.Create(FConfig.TimeoutMs);
end;

function TDeepBaseBaiduSpeechRecognizer.ObtainToken: string;
var
  ErrorText: string;
  ExpiresIn: Integer;
  Json: TJSONObject;
  Response: TSpeechHttpResponse;
  Url: string;
begin
  Result := '';
  FLastError := '';

  if (FConfig.ApiKey = '') or (FConfig.SecretKey = '') then
  begin
    FLastError := 'Baidu ASR api key or secret key is empty';
    Exit;
  end;

  if (FAccessToken <> '') and (Now < FTokenExpireTime) then
    Exit(FAccessToken);

  Url := BaiduTokenUrl + '?grant_type=client_credentials' +
    '&client_id=' + TNetEncoding.URL.Encode(FConfig.ApiKey) +
    '&client_secret=' + TNetEncoding.URL.Encode(FConfig.SecretKey);

  try
    Response := FTransport.Send('GET', Url, '', nil);
  except
    on E: Exception do
    begin
      FLastError := 'Baidu ASR token request failed: ' + E.Message;
      Exit;
    end;
  end;

  if not IsSuccessStatus(Response.StatusCode) then
  begin
    FLastError := Format('Baidu ASR token HTTP %d %s',
      [Response.StatusCode, Response.StatusText]);
    Exit;
  end;

  if not ParseJsonObject(Response.Body, Json) then
  begin
    FLastError := 'Baidu ASR token returned invalid JSON: ' +
      Copy(Response.Body, 1, 200);
    Exit;
  end;

  try
    FAccessToken := JsonString(Json, 'access_token', '');
    if FAccessToken = '' then
    begin
      ErrorText := JsonString(Json, 'error_description', '');
      if ErrorText = '' then
        ErrorText := JsonString(Json, 'error', 'missing access_token');
      FLastError := 'Baidu ASR token error: ' + ErrorText;
      Exit;
    end;

    ExpiresIn := JsonInt(Json, 'expires_in', 2592000);
    FTokenExpireTime := Now + (ExpiresIn - 3600) / 86400;
    Result := FAccessToken;
  finally
    Json.Free;
  end;
end;

function TDeepBaseBaiduSpeechRecognizer.CheckStatus(out AError: string): Boolean;
begin
  Result := ObtainToken <> '';
  AError := FLastError;
end;

function TDeepBaseBaiduSpeechRecognizer.Recognize(const AAudio: TSpeechAudioData;
  const AOptions: TSpeechRecognitionOptions): TSpeechRecognitionResult;
var
  Body: TJSONObject;
  Cuid: string;
  ErrNo: Integer;
  Json: TJSONObject;
  Response: TSpeechHttpResponse;
  ResultArray: TJSONArray;
  SpeechB64: string;
  Token: string;
  Value: TJSONValue;
begin
  FLastError := '';

  if AAudio.IsEmpty or (Length(AAudio.PCMData) < 3200) then
    Exit(TSpeechRecognitionResult.Failed(srsEmptyAudio, 'empty_audio',
      'Audio is empty or too short'));

  if (AAudio.Format.Encoding <> saePCM16) or
     (AAudio.Format.Channels <> 1) or
     (AAudio.Format.BitsPerSample <> 16) then
    Exit(TSpeechRecognitionResult.Failed(srsProviderNotReady,
      'unsupported_audio_format', 'Baidu ASR requires PCM16 mono audio'));

  Token := ObtainToken;
  if Token = '' then
    Exit(TSpeechRecognitionResult.Failed(srsProviderNotReady, 'token_failed',
      FLastError));

  Cuid := AOptions.Cuid;
  if Cuid = '' then
    Cuid := FConfig.Cuid;
  if Cuid = '' then
    Cuid := 'DeepBase';

  Body := TJSONObject.Create;
  try
    SpeechB64 := TNetEncoding.Base64.EncodeBytesToString(
      @AAudio.PCMData[0], Length(AAudio.PCMData));
    SpeechB64 := SpeechB64.Replace(#13#10, '', [rfReplaceAll]);

    Body.AddPair('format', 'pcm');
    Body.AddPair('rate', TJSONNumber.Create(AAudio.Format.SampleRate));
    Body.AddPair('channel', TJSONNumber.Create(1));
    Body.AddPair('cuid', Cuid);
    Body.AddPair('token', Token);
    Body.AddPair('speech', SpeechB64);
    Body.AddPair('len', TJSONNumber.Create(Length(AAudio.PCMData)));
    Body.AddPair('pid', TJSONNumber.Create(FConfig.Pid));

    try
      Response := FTransport.Send('POST', BaiduRecognizeUrl, Body.ToJSON,
        HeaderContentTypeJson);
    except
      on E: Exception do
        Exit(TSpeechRecognitionResult.Failed(srsHttpError, 'request_failed',
          E.Message));
    end;
  finally
    Body.Free;
  end;

  if not IsSuccessStatus(Response.StatusCode) then
    Exit(TSpeechRecognitionResult.Failed(srsHttpError, 'http_error',
      Format('Baidu ASR HTTP %d %s', [Response.StatusCode, Response.StatusText]),
      Response.Body));

  if not ParseJsonObject(Response.Body, Json) then
    Exit(TSpeechRecognitionResult.Failed(srsParseError, 'invalid_json',
      'Baidu ASR returned invalid JSON', Copy(Response.Body, 1, 200)));

  try
    ErrNo := JsonInt(Json, 'err_no', -1);
    if ErrNo <> 0 then
      Exit(TSpeechRecognitionResult.Failed(srsServiceError,
        IntToStr(ErrNo), JsonString(Json, 'err_msg', 'Baidu ASR service error'),
        Response.Body));

    Value := Json.FindValue('result');
    if Value is TJSONArray then
      ResultArray := TJSONArray(Value)
    else
      ResultArray := nil;

    if (ResultArray = nil) or (ResultArray.Count = 0) then
      Exit(TSpeechRecognitionResult.Failed(srsServiceError, 'empty_result',
        'Baidu ASR returned empty result', Response.Body));

    Result := TSpeechRecognitionResult.Succeeded(ResultArray.Items[0].Value,
      Response.Body);
  finally
    Json.Free;
  end;
end;

end.
