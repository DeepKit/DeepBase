unit DeepBase.Net.Transport.ICS;

interface

uses
  System.SysUtils,
  DeepBase.Net.Transport;

type
  TDeepBaseIcsTransportConfig = record
    TimeoutMs: Integer;
    ProxyUrl: string;
    FollowRedirects: Boolean;
    MaxRedirects: Integer;
    class function Create(ATimeoutMs: Integer = 30000;
      const AProxyUrl: string = '';
      AFollowRedirects: Boolean = True;
      AMaxRedirects: Integer = 5): TDeepBaseIcsTransportConfig; static;
  end;

  TDeepBaseIcsHttpTransport = class(TInterfacedObject, IDeepBaseHttpTransport)
  private
    FConfig: TDeepBaseIcsTransportConfig;
  public
    constructor Create(const AConfig: TDeepBaseIcsTransportConfig);
    class function IsAvailable: Boolean; static;
    function Send(const ARequest: TDeepBaseHttpTransportRequest):
      TDeepBaseHttpTransportResponse;
  end;

implementation

{ TDeepBaseIcsTransportConfig }

class function TDeepBaseIcsTransportConfig.Create(ATimeoutMs: Integer;
  const AProxyUrl: string; AFollowRedirects: Boolean;
  AMaxRedirects: Integer): TDeepBaseIcsTransportConfig;
begin
  if ATimeoutMs <= 0 then
    ATimeoutMs := 30000;
  Result.TimeoutMs := ATimeoutMs;
  Result.ProxyUrl := AProxyUrl;
  Result.FollowRedirects := AFollowRedirects;
  Result.MaxRedirects := AMaxRedirects;
end;

{ TDeepBaseIcsHttpTransport }

constructor TDeepBaseIcsHttpTransport.Create(
  const AConfig: TDeepBaseIcsTransportConfig);
begin
  inherited Create;
  FConfig := AConfig;
  if not IsAvailable then
    raise EDeepBaseNetTransportError.Create(
      'ICS transport is not compiled in. Define DEEPBASE_HAS_ICS and add Overbyte ICS units to enable this optional adapter.');
end;

class function TDeepBaseIcsHttpTransport.IsAvailable: Boolean;
begin
  {$IFDEF DEEPBASE_HAS_ICS}
  Result := True;
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

function TDeepBaseIcsHttpTransport.Send(
  const ARequest: TDeepBaseHttpTransportRequest): TDeepBaseHttpTransportResponse;
begin
  raise EDeepBaseNetTransportError.Create(
    'ICS transport implementation is not linked in this build.');
end;

end.
