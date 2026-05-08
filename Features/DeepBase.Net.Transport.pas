unit DeepBase.Net.Transport;

interface

uses
  System.Classes,
  System.SysUtils,
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

  TDeepBaseSystemNetTransport = class(TInterfacedObject, IDeepBaseHttpTransport)
  public
    function Send(const ARequest: TDeepBaseHttpTransportRequest):
      TDeepBaseHttpTransportResponse;
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
        Result.Body := TEncoding.UTF8.GetString(Result.BodyBytes);
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

end.
