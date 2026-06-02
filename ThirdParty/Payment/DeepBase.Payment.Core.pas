unit DeepBase.Payment.Core;

{*******************************************************************************
  DeepBase Payment Core
  
  Unified payment client interface and base implementation.
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Net.HttpClient,
  System.Net.URLClient, System.NetEncoding, System.Generics.Collections,
  DeepBase.Payment.Types;

type
  /// <summary>Payment client interface - all providers implement this</summary>
  IPaymentClient = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    
    // Core operations
    function CreatePayment(const ARequest: TPaymentRequest): TPaymentResult;
    function GetPaymentStatus(const ATransactionId: string): TPaymentResult;
    function CapturePayment(const ATransactionId: string; AAmount: TMoney): TPaymentResult;
    function CancelPayment(const ATransactionId: string): TPaymentResult;
    
    // Refunds
    function CreateRefund(const ARequest: TRefundRequest): TRefundResult;
    function GetRefundStatus(const ARefundId: string): TRefundResult;
    
    // Webhooks
    function VerifyWebhookSignature(const APayload, ASignature: string): Boolean;
    function ParseWebhookEvent(const APayload: string): TWebhookEvent;
    
    // Provider info
    function GetProvider: TPaymentProvider;
    function GetEnvironment: TPaymentEnvironment;
  end;

  /// <summary>Base payment client with common functionality</summary>
  TPaymentClientBase = class(TInterfacedObject, IPaymentClient)
  protected
    FCredentials: TPaymentCredentials;
    FHttpClient: THTTPClient;
    FTimeout: Integer;
    
    // HTTP helpers
    function DoGet(const AUrl: string; const AHeaders: TNetHeaders = nil): string;
    function DoPost(const AUrl: string; const ABody: string;
      const AHeaders: TNetHeaders = nil): string;
    function DoPostForm(const AUrl: string; const AParams: TStrings;
      const AHeaders: TNetHeaders = nil): string;
    function DoDelete(const AUrl: string; const AHeaders: TNetHeaders = nil): string;
    
    // JSON helpers
    function ParseJSON(const AJson: string): TJSONObject;
    function GetJSONString(AObj: TJSONObject; const APath: string; const ADefault: string = ''): string;
    function GetJSONInt(AObj: TJSONObject; const APath: string; ADefault: Integer = 0): Integer;
    function GetJSONInt64(AObj: TJSONObject; const APath: string; ADefault: Int64 = 0): Int64;
    function GetJSONBool(AObj: TJSONObject; const APath: string; ADefault: Boolean = False): Boolean;
    
    // Abstract methods - must be implemented by providers
    function GetBaseUrl: string; virtual; abstract;
    function GetAuthHeaders: TNetHeaders; virtual; abstract;
  public
    constructor Create(const ACredentials: TPaymentCredentials);
    destructor Destroy; override;
    
    // IPaymentClient
    function CreatePayment(const ARequest: TPaymentRequest): TPaymentResult; virtual; abstract;
    function GetPaymentStatus(const ATransactionId: string): TPaymentResult; virtual; abstract;
    function CapturePayment(const ATransactionId: string; AAmount: TMoney): TPaymentResult; virtual; abstract;
    function CancelPayment(const ATransactionId: string): TPaymentResult; virtual; abstract;
    
    function CreateRefund(const ARequest: TRefundRequest): TRefundResult; virtual; abstract;
    function GetRefundStatus(const ARefundId: string): TRefundResult; virtual; abstract;
    
    function VerifyWebhookSignature(const APayload, ASignature: string): Boolean; virtual; abstract;
    function ParseWebhookEvent(const APayload: string): TWebhookEvent; virtual; abstract;
    
    function GetProvider: TPaymentProvider;
    function GetEnvironment: TPaymentEnvironment;
    
    property Credentials: TPaymentCredentials read FCredentials;
    property Timeout: Integer read FTimeout write FTimeout;
  end;

/// <summary>Factory function to create payment client</summary>
function CreatePaymentClient(const ACredentials: TPaymentCredentials): IPaymentClient;

implementation

{ Factory }

function CreatePaymentClient(const ACredentials: TPaymentCredentials): IPaymentClient;
begin
  raise ENotSupportedException.CreateFmt(
    'DeepBase.Payment.Core does not provide provider adapters for %d; use DeepBase.Payment provider clients',
    [Ord(ACredentials.Provider)]);
end;

{ TPaymentClientBase }

constructor TPaymentClientBase.Create(const ACredentials: TPaymentCredentials);
begin
  inherited Create;
  FCredentials := ACredentials;
  FHttpClient := THTTPClient.Create;
  FHttpClient.ContentType := 'application/json';
  FTimeout := 30000; // 30 seconds
end;

destructor TPaymentClientBase.Destroy;
begin
  FHttpClient.Free;
  inherited;
end;

function TPaymentClientBase.GetProvider: TPaymentProvider;
begin
  Result := FCredentials.Provider;
end;

function TPaymentClientBase.GetEnvironment: TPaymentEnvironment;
begin
  Result := FCredentials.Environment;
end;

function TPaymentClientBase.DoGet(const AUrl: string; const AHeaders: TNetHeaders): string;
var
  Response: IHTTPResponse;
  AllHeaders: TNetHeaders;
begin
  AllHeaders := GetAuthHeaders;
  if Length(AHeaders) > 0 then
    AllHeaders := AllHeaders + AHeaders;
    
  Response := FHttpClient.Get(AUrl, nil, AllHeaders);
  Result := Response.ContentAsString;
  
  if (Response.StatusCode < 200) or (Response.StatusCode >= 300) then
    raise EPaymentError.Create(Result,
      IntToStr(Response.StatusCode), FCredentials.Provider);
end;

function TPaymentClientBase.DoPost(const AUrl: string; const ABody: string;
  const AHeaders: TNetHeaders): string;
var
  Response: IHTTPResponse;
  AllHeaders: TNetHeaders;
  BodyStream: TStringStream;
begin
  AllHeaders := GetAuthHeaders;
  if Length(AHeaders) > 0 then
    AllHeaders := AllHeaders + AHeaders;
    
  BodyStream := TStringStream.Create(ABody, TEncoding.UTF8);
  try
    Response := FHttpClient.Post(AUrl, BodyStream, nil, AllHeaders);
    Result := Response.ContentAsString;
    
    if (Response.StatusCode < 200) or (Response.StatusCode >= 300) then
      raise EPaymentError.Create(Result,
        IntToStr(Response.StatusCode), FCredentials.Provider);
  finally
    BodyStream.Free;
  end;
end;

function TPaymentClientBase.DoPostForm(const AUrl: string; const AParams: TStrings;
  const AHeaders: TNetHeaders): string;
var
  Response: IHTTPResponse;
  AllHeaders: TNetHeaders;
  Body: TStringBuilder;
  BodyStream: TStringStream;
  I: Integer;
begin
  AllHeaders := GetAuthHeaders;
  // Override content type for form data
  SetLength(AllHeaders, Length(AllHeaders) + 1);
  AllHeaders[High(AllHeaders)] := TNameValuePair.Create('Content-Type', 
    'application/x-www-form-urlencoded');
  if Length(AHeaders) > 0 then
    AllHeaders := AllHeaders + AHeaders;

  Body := TStringBuilder.Create;
  try
    for I := 0 to AParams.Count - 1 do
    begin
      if I > 0 then
        Body.Append('&');
      Body.Append(TNetEncoding.URL.Encode(AParams.Names[I]));
      Body.Append('=');
      Body.Append(TNetEncoding.URL.Encode(AParams.ValueFromIndex[I]));
    end;

    BodyStream := TStringStream.Create(Body.ToString, TEncoding.UTF8);
    try
      Response := FHttpClient.Post(AUrl, BodyStream, nil, AllHeaders);
      Result := Response.ContentAsString;

      if (Response.StatusCode < 200) or (Response.StatusCode >= 300) then
        raise EPaymentError.Create(Result,
          IntToStr(Response.StatusCode), FCredentials.Provider);
    finally
      BodyStream.Free;
    end;
  finally
    Body.Free;
  end;
end;

function TPaymentClientBase.DoDelete(const AUrl: string; const AHeaders: TNetHeaders): string;
var
  Response: IHTTPResponse;
  AllHeaders: TNetHeaders;
begin
  AllHeaders := GetAuthHeaders;
  if Length(AHeaders) > 0 then
    AllHeaders := AllHeaders + AHeaders;
    
  Response := FHttpClient.Delete(AUrl, nil, AllHeaders);
  Result := Response.ContentAsString;
  
  if (Response.StatusCode < 200) or (Response.StatusCode >= 300) then
    raise EPaymentError.Create(Result,
      IntToStr(Response.StatusCode), FCredentials.Provider);
end;

function TPaymentClientBase.ParseJSON(const AJson: string): TJSONObject;
begin
  Result := TJSONObject.ParseJSONValue(AJson) as TJSONObject;
  if Result = nil then
    raise EPaymentError.Create('Failed to parse JSON response',
      'INVALID_JSON', FCredentials.Provider);
end;

function TPaymentClientBase.GetJSONString(AObj: TJSONObject; const APath: string;
  const ADefault: string): string;
var
  Value: TJSONValue;
begin
  Value := AObj.FindValue(APath);
  if Assigned(Value) and not (Value is TJSONNull) then
    Result := Value.Value
  else
    Result := ADefault;
end;

function TPaymentClientBase.GetJSONInt(AObj: TJSONObject; const APath: string;
  ADefault: Integer): Integer;
var
  Value: TJSONValue;
begin
  Value := AObj.FindValue(APath);
  if Assigned(Value) and (Value is TJSONNumber) then
    Result := TJSONNumber(Value).AsInt
  else
    Result := ADefault;
end;

function TPaymentClientBase.GetJSONInt64(AObj: TJSONObject; const APath: string;
  ADefault: Int64): Int64;
var
  Value: TJSONValue;
begin
  Value := AObj.FindValue(APath);
  if Assigned(Value) and (Value is TJSONNumber) then
    Result := TJSONNumber(Value).AsInt64
  else
    Result := ADefault;
end;

function TPaymentClientBase.GetJSONBool(AObj: TJSONObject; const APath: string;
  ADefault: Boolean): Boolean;
var
  Value: TJSONValue;
begin
  Value := AObj.FindValue(APath);
  if Assigned(Value) and (Value is TJSONBool) then
    Result := TJSONBool(Value).AsBoolean
  else
    Result := ADefault;
end;

end.
