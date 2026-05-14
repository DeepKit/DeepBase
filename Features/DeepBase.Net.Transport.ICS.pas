unit DeepBase.Net.Transport.ICS;

interface

uses
  System.SysUtils,
  DeepBase.Net.Transport;

type
  TDeepBaseIcsTlsVersion = (itlsDefault, itls10, itls11, itls12, itls13);
  TDeepBaseIcsCertificateErrorPolicy = (icepReject, icepAllow, icepCallback);
  TDeepBaseIcsCertificateErrorEvent = function(const AUrl,
    AErrorText: string): Boolean of object;
  TDeepBaseIcsCancelEvent = function: Boolean of object;

  TDeepBaseIcsTransportConfig = record
    TimeoutMs: Integer;
    ConnectTimeoutMs: Integer;
    ResponseTimeoutMs: Integer;
    ProxyUrl: string;
    FollowRedirects: Boolean;
    MaxRedirects: Integer;
    VerifyPeer: Boolean;
    TlsMinVersion: TDeepBaseIcsTlsVersion;
    CertificateErrorPolicy: TDeepBaseIcsCertificateErrorPolicy;
    OnCertificateError: TDeepBaseIcsCertificateErrorEvent;
    OnCancel: TDeepBaseIcsCancelEvent;
    class function Create(ATimeoutMs: Integer = 30000;
      const AProxyUrl: string = '';
      AFollowRedirects: Boolean = True;
      AMaxRedirects: Integer = 5): TDeepBaseIcsTransportConfig; static;
    class function CreateSecure(ATimeoutMs: Integer = 30000;
      const AProxyUrl: string = '';
      ATlsMinVersion: TDeepBaseIcsTlsVersion = itls12):
      TDeepBaseIcsTransportConfig; static;
  end;

  TDeepBaseIcsHttpTransport = class(TInterfacedObject, IDeepBaseHttpTransport)
  private
    FConfig: TDeepBaseIcsTransportConfig;
  public
    constructor Create(const AConfig: TDeepBaseIcsTransportConfig);
    class function IsAvailable: Boolean; static;
    class function EffectiveRequest(const AConfig: TDeepBaseIcsTransportConfig;
      const ARequest: TDeepBaseHttpTransportRequest):
      TDeepBaseHttpTransportRequest; static;
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
  Result.ConnectTimeoutMs := ATimeoutMs;
  Result.ResponseTimeoutMs := ATimeoutMs;
  Result.ProxyUrl := AProxyUrl;
  Result.FollowRedirects := AFollowRedirects;
  Result.MaxRedirects := AMaxRedirects;
  Result.VerifyPeer := True;
  Result.TlsMinVersion := itls12;
  Result.CertificateErrorPolicy := icepReject;
  Result.OnCertificateError := nil;
  Result.OnCancel := nil;
end;

class function TDeepBaseIcsTransportConfig.CreateSecure(ATimeoutMs: Integer;
  const AProxyUrl: string; ATlsMinVersion: TDeepBaseIcsTlsVersion):
  TDeepBaseIcsTransportConfig;
begin
  Result := Create(ATimeoutMs, AProxyUrl, True, 5);
  Result.VerifyPeer := True;
  Result.TlsMinVersion := ATlsMinVersion;
  Result.CertificateErrorPolicy := icepReject;
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

class function TDeepBaseIcsHttpTransport.EffectiveRequest(
  const AConfig: TDeepBaseIcsTransportConfig;
  const ARequest: TDeepBaseHttpTransportRequest):
  TDeepBaseHttpTransportRequest;
begin
  Result := ARequest;

  if Result.TimeoutMs <= 0 then
    Result.TimeoutMs := AConfig.TimeoutMs;
  if Result.TimeoutMs <= 0 then
    Result.TimeoutMs := 30000;

  if Result.ProxyUrl = '' then
    Result.ProxyUrl := AConfig.ProxyUrl;
  Result.FollowRedirects := AConfig.FollowRedirects;
  Result.MaxRedirects := AConfig.MaxRedirects;
  if Result.MaxRedirects < 0 then
    Result.MaxRedirects := 0;
end;

function TDeepBaseIcsHttpTransport.Send(
  const ARequest: TDeepBaseHttpTransportRequest): TDeepBaseHttpTransportResponse;
var
  Effective: TDeepBaseHttpTransportRequest;
begin
  Effective := EffectiveRequest(FConfig, ARequest);
  if Effective.Url.Trim = '' then
    raise EDeepBaseNetTransportError.Create('ICS transport URL is required');
  if Assigned(FConfig.OnCancel) and FConfig.OnCancel() then
    raise EDeepBaseNetTransportError.Create('ICS transport request cancelled before send');

  if not IsAvailable then
    raise EDeepBaseNetTransportError.Create(
      'ICS transport is not compiled in. Define DEEPBASE_HAS_ICS and add Overbyte ICS units to enable this optional adapter.');

  raise EDeepBaseNetTransportError.Create(
    'ICS transport request execution requires the Overbyte ICS implementation unit to be linked by the downstream project.');
end;

end.
