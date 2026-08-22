unit DeepBase.Net.Transport;

interface

uses
  System.Classes,
  System.SysUtils,
  System.SyncObjs,
  System.Net.HttpClient,
  System.Net.URLClient;

type
  EDeepBaseNetTransportError = class(Exception);

  TDeepBaseHttpMethod = (dbhmGet, dbhmPost, dbhmPut, dbhmPatch, dbhmDelete,
    dbhmHead, dbhmOptions);

  TDeepBaseHttpTransportRequest = record
    Method: TDeepBaseHttpMethod;
    Url: string;
    Body: string;
    BodyBytes: TBytes;
    Headers: TNetHeaders;
    ContentType: string;
    TimeoutMs: Integer;
    FollowRedirects: Boolean;
    MaxRedirects: Integer;
    ProxyUrl: string;
    class function Create(AMethod: TDeepBaseHttpMethod;
      const AUrl: string): TDeepBaseHttpTransportRequest; static;
  end;

  TDeepBaseHttpTransportResponse = record
    StatusCode: Integer;
    StatusText: string;
    Body: string;
    BodyBytes: TBytes;
    Headers: TNetHeaders;
    ContentType: string;
    ContentLength: Int64;
    class function Create(AStatusCode: Integer; const ABody: string;
      const AStatusText: string = ''): TDeepBaseHttpTransportResponse; static;
    function IsSuccess: Boolean;
  end;

  IDeepBaseHttpTransport = interface
    ['{89149015-96CE-43F1-986E-804A07F55BE3}']
    function Send(const ARequest: TDeepBaseHttpTransportRequest):
      TDeepBaseHttpTransportResponse;
  end;

  /// <summary>
  /// Cancellation token for aborting in-progress streaming requests.
  /// Thread-safe: Cancel can be called from any thread.
  /// </summary>
  ICancellationToken = interface
    ['{D4E5F6A7-B8C9-4D0E-A1F2-3B4C5D6E7F80}']
    function IsCancelled: Boolean;
    procedure Cancel;
  end;

  /// <summary>
  /// Callback invoked for each chunk received during streaming.
  /// Set ACancel to True to abort the stream.
  /// </summary>
  TStreamChunkEvent = reference to procedure(const AChunk: string; var ACancel: Boolean);

  /// <summary>
  /// Extended transport interface supporting true streaming responses.
  /// Chunks are delivered via callback before the full response completes.
  /// </summary>
  IDeepBaseStreamingTransport = interface(IDeepBaseHttpTransport)
    ['{A2B3C4D5-E6F7-4890-AB12-CD34EF56A789}']
    function SendStreaming(const ARequest: TDeepBaseHttpTransportRequest;
      AOnChunk: TStreamChunkEvent;
      const ACancelToken: ICancellationToken): TDeepBaseHttpTransportResponse;
  end;

  /// <summary>
  /// Default implementation of ICancellationToken using atomic integer.
  /// </summary>
  TCancellationToken = class(TInterfacedObject, ICancellationToken)
  private
    FCancelled: Integer; // 0 = not cancelled, 1 = cancelled
  public
    function IsCancelled: Boolean;
    procedure Cancel;
  end;

  TDeepBaseSystemNetTransport = class(TInterfacedObject, IDeepBaseHttpTransport,
    IDeepBaseStreamingTransport)
  public
    function Send(const ARequest: TDeepBaseHttpTransportRequest):
      TDeepBaseHttpTransportResponse;
    function SendStreaming(const ARequest: TDeepBaseHttpTransportRequest;
      AOnChunk: TStreamChunkEvent;
      const ACancelToken: ICancellationToken): TDeepBaseHttpTransportResponse;
  end;

function DeepBaseHttpMethodToString(AMethod: TDeepBaseHttpMethod): string;
function DeepBaseHttpMethodFromString(const AMethod: string): TDeepBaseHttpMethod;

implementation

function DeepBaseHttpMethodToString(AMethod: TDeepBaseHttpMethod): string;
begin
  case AMethod of
    dbhmPost: Result := 'POST';
    dbhmPut: Result := 'PUT';
    dbhmPatch: Result := 'PATCH';
    dbhmDelete: Result := 'DELETE';
    dbhmHead: Result := 'HEAD';
    dbhmOptions: Result := 'OPTIONS';
  else
    Result := 'GET';
  end;
end;

function DeepBaseHttpMethodFromString(const AMethod: string): TDeepBaseHttpMethod;
begin
  if SameText(AMethod, 'POST') then
    Result := dbhmPost
  else if SameText(AMethod, 'PUT') then
    Result := dbhmPut
  else if SameText(AMethod, 'PATCH') then
    Result := dbhmPatch
  else if SameText(AMethod, 'DELETE') then
    Result := dbhmDelete
  else if SameText(AMethod, 'HEAD') then
    Result := dbhmHead
  else if SameText(AMethod, 'OPTIONS') then
    Result := dbhmOptions
  else
    Result := dbhmGet;
end;

{ TDeepBaseHttpTransportRequest }

class function TDeepBaseHttpTransportRequest.Create(
  AMethod: TDeepBaseHttpMethod;
  const AUrl: string): TDeepBaseHttpTransportRequest;
begin
  Result.Method := AMethod;
  Result.Url := AUrl;
  Result.Body := '';
  SetLength(Result.BodyBytes, 0);
  SetLength(Result.Headers, 0);
  Result.ContentType := '';
  Result.TimeoutMs := 30000;
  Result.FollowRedirects := True;
  Result.MaxRedirects := 5;
  Result.ProxyUrl := '';
end;

{ TDeepBaseHttpTransportResponse }

class function TDeepBaseHttpTransportResponse.Create(AStatusCode: Integer;
  const ABody, AStatusText: string): TDeepBaseHttpTransportResponse;
begin
  Result.StatusCode := AStatusCode;
  Result.StatusText := AStatusText;
  Result.Body := ABody;
  Result.BodyBytes := TEncoding.UTF8.GetBytes(ABody);
  SetLength(Result.Headers, 0);
  Result.ContentType := '';
  Result.ContentLength := Length(Result.BodyBytes);
end;

function TDeepBaseHttpTransportResponse.IsSuccess: Boolean;
begin
  Result := (StatusCode >= 200) and (StatusCode < 300);
end;

{ TDeepBaseSystemNetTransport }

function TDeepBaseSystemNetTransport.Send(
  const ARequest: TDeepBaseHttpTransportRequest): TDeepBaseHttpTransportResponse;
var
  Client: THTTPClient;
  Response: IHTTPResponse;
  BodyStream: TStream;
  ResponseStream: TStream;
  Memory: TMemoryStream;
begin
  if ARequest.Url.Trim = '' then
    raise EDeepBaseNetTransportError.Create('HTTP transport URL is required');

  BodyStream := nil;
  Client := THTTPClient.Create;
  try
    Client.ConnectionTimeout := ARequest.TimeoutMs;
    Client.ResponseTimeout := ARequest.TimeoutMs;
    Client.HandleRedirects := ARequest.FollowRedirects;
    Client.MaxRedirects := ARequest.MaxRedirects;
    if ARequest.ContentType <> '' then
      Client.ContentType := ARequest.ContentType;
    if ARequest.ProxyUrl <> '' then
      Client.ProxySettings := TProxySettings.Create(ARequest.ProxyUrl);

    case ARequest.Method of
      dbhmGet:
        Response := Client.Get(ARequest.Url, nil, ARequest.Headers);
      dbhmPost:
        begin
          if Length(ARequest.BodyBytes) > 0 then
            BodyStream := TBytesStream.Create(ARequest.BodyBytes)
          else
            BodyStream := TStringStream.Create(ARequest.Body, TEncoding.UTF8);
          Response := Client.Post(ARequest.Url, BodyStream, nil,
            ARequest.Headers);
        end;
      dbhmPut:
        begin
          if Length(ARequest.BodyBytes) > 0 then
            BodyStream := TBytesStream.Create(ARequest.BodyBytes)
          else
            BodyStream := TStringStream.Create(ARequest.Body, TEncoding.UTF8);
          Response := Client.Put(ARequest.Url, BodyStream, nil,
            ARequest.Headers);
        end;
      dbhmPatch:
        begin
          if Length(ARequest.BodyBytes) > 0 then
            BodyStream := TBytesStream.Create(ARequest.BodyBytes)
          else
            BodyStream := TStringStream.Create(ARequest.Body, TEncoding.UTF8);
          Response := Client.Patch(ARequest.Url, BodyStream, nil,
            ARequest.Headers);
        end;
      dbhmDelete:
        Response := Client.Delete(ARequest.Url, nil, ARequest.Headers);
      dbhmHead:
        Response := Client.Head(ARequest.Url);
      dbhmOptions:
        Response := Client.Options(ARequest.Url);
    end;

    Result.StatusCode := Response.StatusCode;
    Result.StatusText := Response.StatusText;
    ResponseStream := Response.ContentStream;
    if ResponseStream <> nil then
    begin
      Memory := TMemoryStream.Create;
      try
        try
          if ResponseStream.Position <> 0 then
            ResponseStream.Position := 0;
        except
          // Some platform streams are forward-only; copy from current position.
        end;
        Memory.CopyFrom(ResponseStream, 0);
        SetLength(Result.BodyBytes, Memory.Size);
        if Memory.Size > 0 then
        begin
          Memory.Position := 0;
          Memory.ReadBuffer(Result.BodyBytes[0], Memory.Size);
        end;
        // P4.5-T3: 二进制载荷(zip)不是合法 UTF8, TEncoding.UTF8.GetString 抛
        // EEncodingError(1113 "No mapping...")。BodyBytes 已完整保留字节,
        // 文本体仅用于 JSON 响应解析, 二进制时置空即可(调用方按 BodyBytes 用)。
        try
          Result.Body := TEncoding.UTF8.GetString(Result.BodyBytes);
        except
          on E: EEncodingError do
            Result.Body := '';
        end;
      finally
        Memory.Free;
      end;
    end
    else
    begin
      Result.Body := Response.ContentAsString(TEncoding.UTF8);
      Result.BodyBytes := TEncoding.UTF8.GetBytes(Result.Body);
    end;
    Result.Headers := Response.Headers;
    Result.ContentType := Response.MimeType;
    if Response.ContentLength >= 0 then
      Result.ContentLength := Response.ContentLength
    else
      Result.ContentLength := Length(Result.BodyBytes);
  finally
    BodyStream.Free;
    Client.Free;
  end;
end;

{ TCancellationToken }

function TCancellationToken.IsCancelled: Boolean;
begin
  Result := TInterlocked.CompareExchange(FCancelled, 0, 0) <> 0;
end;

procedure TCancellationToken.Cancel;
begin
  TInterlocked.Exchange(FCancelled, 1);
end;

{ TDeepBaseSystemNetTransport.SendStreaming }

function TDeepBaseSystemNetTransport.SendStreaming(
  const ARequest: TDeepBaseHttpTransportRequest;
  AOnChunk: TStreamChunkEvent;
  const ACancelToken: ICancellationToken): TDeepBaseHttpTransportResponse;
var
  Client: THTTPClient;
  Resp: IHTTPResponse;
  BodyStream: TStream;
  Reader: TStreamReader;
  LLine, LData, LTrimmed: string;
  LCancel: Boolean;
  LStartTick: UInt64;
  LFirstTokenMs: Integer;
  LFirstChunkReceived: Boolean;
begin
  // True incremental streaming: THTTPClient.Post returns once HTTP headers arrive;
  // the body is read line-by-line from IHTTPResponse.ContentStream via TStreamReader.
  // Each SSE "data: ..." line is delivered via AOnChunk as soon as it is received.
  //
  // Note: On some Delphi/platform builds ContentStream may buffer the full body
  // internally before Post returns. In that case this degenerates to buffered
  // SSE parsing — still correct, just not reducing TTFT.  A future transport
  // backed by raw sockets or WinHttpSetStatusCallback can achieve true TTFT.

  if ARequest.Url.Trim = '' then
    raise EDeepBaseNetTransportError.Create('HTTP transport URL is required');

  LStartTick := TThread.GetTickCount64;
  LFirstTokenMs := 0;
  LFirstChunkReceived := False;

  BodyStream := nil;
  Client := THTTPClient.Create;
  try
    Client.ConnectionTimeout := ARequest.TimeoutMs;
    Client.ResponseTimeout := ARequest.TimeoutMs;
    if ARequest.ContentType <> '' then
      Client.ContentType := ARequest.ContentType;
    if ARequest.ProxyUrl <> '' then
      Client.ProxySettings := TProxySettings.Create(ARequest.ProxyUrl);

    // Build body stream
    if Length(ARequest.BodyBytes) > 0 then
      BodyStream := TBytesStream.Create(ARequest.BodyBytes)
    else
      BodyStream := TStringStream.Create(ARequest.Body, TEncoding.UTF8);

    try
      Resp := Client.Post(ARequest.Url, BodyStream, nil, ARequest.Headers);
    except
      on E: Exception do
      begin
        Result := TDeepBaseHttpTransportResponse.Create(0, '', E.Message);
        Exit;
      end;
    end;

    Result.StatusCode := Resp.StatusCode;
    Result.StatusText := Resp.StatusText;
    Result.Headers := Resp.Headers;
    Result.ContentType := Resp.MimeType;
    if Resp.ContentLength >= 0 then
      Result.ContentLength := Resp.ContentLength
    else
      Result.ContentLength := -1;

    // If cancelled or non-success, skip body parsing
    if (Assigned(ACancelToken) and ACancelToken.IsCancelled) or
       not Result.IsSuccess then
    begin
      if (Resp.ContentStream <> nil) and not Result.IsSuccess then
      begin
        // Read error body for diagnostics
        var MemStream := TMemoryStream.Create;
        try
          MemStream.CopyFrom(Resp.ContentStream, 0);
          SetLength(Result.BodyBytes, MemStream.Size);
          if MemStream.Size > 0 then
          begin
            MemStream.Position := 0;
            MemStream.ReadBuffer(Result.BodyBytes[0], MemStream.Size);
          end;
          Result.Body := TEncoding.UTF8.GetString(Result.BodyBytes);
        finally
          MemStream.Free;
        end;
      end;
      Exit;
    end;

    // Read response body incrementally via TStreamReader
    if Resp.ContentStream <> nil then
    begin
      Reader := TStreamReader.Create(Resp.ContentStream, TEncoding.UTF8, True);
      try
        while not Reader.EndOfStream do
        begin
          if Assigned(ACancelToken) and ACancelToken.IsCancelled then
            Break;

          LLine := Reader.ReadLine;
          LTrimmed := TrimRight(LLine);

          if not LTrimmed.StartsWith('data: ') then
            Continue;

          LData := LTrimmed.Substring(6);
          if LData = '[DONE]' then
            Break;

          if not LFirstChunkReceived then
          begin
            LFirstChunkReceived := True;
            LFirstTokenMs := Integer(TThread.GetTickCount64 - LStartTick);
          end;

          LCancel := False;
          if Assigned(AOnChunk) then
            AOnChunk(LData, LCancel);
          if LCancel then
            Break;
        end;
      finally
        Reader.Free;
      end;
    end;

    // Append FirstTokenMs metadata to StatusText for diagnostics
    if LFirstChunkReceived then
      Result.StatusText := Result.StatusText + ' [FirstTokenMs=' +
        IntToStr(LFirstTokenMs) + ']';
  finally
    BodyStream.Free;
    Client.Free;
  end;
end;

end.
