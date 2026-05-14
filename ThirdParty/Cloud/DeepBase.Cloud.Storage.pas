unit DeepBase.Cloud.Storage;

{*******************************************************************************
  DeepBase Cloud Storage Integration
  
  Unified interface for cloud storage providers:
    - AWS S3
    - Azure Blob Storage
    - Alibaba Cloud OSS
    - Google Cloud Storage
    - MinIO (S3 compatible)
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.Net.HttpClient, System.Net.URLClient, System.NetEncoding;

type
  TCloudStorageProvider = (cspAWSS3, cspAzureBlob, cspAliOSS, cspGoogleCloud, cspMinIO);
  
  TStorageClass = (scStandard, scInfrequentAccess, scArchive, scColdline, scGlacier);
  
  TObjectACL = (aclPrivate, aclPublicRead, aclPublicReadWrite, aclAuthenticatedRead);

  TCloudCredentials = record
    Provider: TCloudStorageProvider;
    AccessKeyId: string;
    SecretAccessKey: string;
    Region: string;
    Endpoint: string;
    AccountName: string;  // Azure
    SASToken: string;     // Azure
    ProjectId: string;    // Google
    
    class function ForAWS(const AAccessKey, ASecretKey, ARegion: string): TCloudCredentials; static;
    class function ForAzure(const AAccountName, AAccountKey: string): TCloudCredentials; static;
    class function ForAliOSS(const AAccessKey, ASecretKey, ARegion: string): TCloudCredentials; static;
    class function ForGoogle(const AProjectId, AServiceAccountJson: string): TCloudCredentials; static;
    class function ForMinIO(const AEndpoint, AAccessKey, ASecretKey: string): TCloudCredentials; static;
  end;

  TCloudObject = record
    Key: string;
    Size: Int64;
    LastModified: TDateTime;
    ETag: string;
    StorageClass: TStorageClass;
    ContentType: string;
    Metadata: TDictionary<string, string>;
  end;

  TListObjectsResult = record
    Objects: TArray<TCloudObject>;
    CommonPrefixes: TArray<string>;
    IsTruncated: Boolean;
    ContinuationToken: string;
  end;

  TUploadProgress = procedure(Sender: TObject; ABytesSent, ATotalBytes: Int64) of object;
  TDownloadProgress = procedure(Sender: TObject; ABytesReceived, ATotalBytes: Int64) of object;

  ICloudStorageClient = interface
    ['{F1E2D3C4-B5A6-9788-9A0B-C1D2E3F4A5B6}']
    // Bucket operations
    function CreateBucket(const ABucketName: string; const ARegion: string = ''): Boolean;
    function DeleteBucket(const ABucketName: string): Boolean;
    function BucketExists(const ABucketName: string): Boolean;
    function ListBuckets: TArray<string>;
    
    // Object operations
    function PutObject(const ABucketName, AKey: string; AStream: TStream;
      const AContentType: string = 'application/octet-stream'): Boolean;
    function GetObject(const ABucketName, AKey: string; AStream: TStream): Boolean;
    function DeleteObject(const ABucketName, AKey: string): Boolean;
    function CopyObject(const ASrcBucket, ASrcKey, ADestBucket, ADestKey: string): Boolean;
    function ObjectExists(const ABucketName, AKey: string): Boolean;
    function GetObjectInfo(const ABucketName, AKey: string): TCloudObject;
    
    // Listing
    function ListObjects(const ABucketName: string; const APrefix: string = '';
      const ADelimiter: string = '/'; AMaxKeys: Integer = 1000): TListObjectsResult;
    
    // URLs
    function GetPresignedUrl(const ABucketName, AKey: string; 
      AExpiresInSeconds: Integer = 3600): string;
    function GetPublicUrl(const ABucketName, AKey: string): string;
    
    // ACL
    procedure SetObjectACL(const ABucketName, AKey: string; AACL: TObjectACL);
    function GetObjectACL(const ABucketName, AKey: string): TObjectACL;
    
    // Multipart upload
    function InitiateMultipartUpload(const ABucketName, AKey: string): string;
    function UploadPart(const ABucketName, AKey, AUploadId: string; 
      APartNumber: Integer; AStream: TStream): string;
    function CompleteMultipartUpload(const ABucketName, AKey, AUploadId: string;
      const AParts: TArray<TPair<Integer, string>>): Boolean;
    function AbortMultipartUpload(const ABucketName, AKey, AUploadId: string): Boolean;
  end;

  TCloudStorageClient = class(TInterfacedObject, ICloudStorageClient)
  private
    FCredentials: TCloudCredentials;
    FHttpClient: THTTPClient;
    FOnUploadProgress: TUploadProgress;
    FOnDownloadProgress: TDownloadProgress;
    
    function SignRequest(const AMethod, APath: string; 
      AHeaders: TNetHeaders): TNetHeaders; virtual;
    function BuildUrl(const ABucketName, AKey: string): string; virtual;
  public
    constructor Create(const ACredentials: TCloudCredentials);
    destructor Destroy; override;
    
    // ICloudStorageClient implementation
    function CreateBucket(const ABucketName: string; const ARegion: string = ''): Boolean; virtual;
    function DeleteBucket(const ABucketName: string): Boolean; virtual;
    function BucketExists(const ABucketName: string): Boolean; virtual;
    function ListBuckets: TArray<string>; virtual;
    
    function PutObject(const ABucketName, AKey: string; AStream: TStream;
      const AContentType: string = 'application/octet-stream'): Boolean; virtual;
    function GetObject(const ABucketName, AKey: string; AStream: TStream): Boolean; virtual;
    function DeleteObject(const ABucketName, AKey: string): Boolean; virtual;
    function CopyObject(const ASrcBucket, ASrcKey, ADestBucket, ADestKey: string): Boolean; virtual;
    function ObjectExists(const ABucketName, AKey: string): Boolean; virtual;
    function GetObjectInfo(const ABucketName, AKey: string): TCloudObject; virtual;
    
    function ListObjects(const ABucketName: string; const APrefix: string = '';
      const ADelimiter: string = '/'; AMaxKeys: Integer = 1000): TListObjectsResult; virtual;
    
    function GetPresignedUrl(const ABucketName, AKey: string;
      AExpiresInSeconds: Integer = 3600): string; virtual;
    function GetPublicUrl(const ABucketName, AKey: string): string; virtual;
    
    procedure SetObjectACL(const ABucketName, AKey: string; AACL: TObjectACL); virtual;
    function GetObjectACL(const ABucketName, AKey: string): TObjectACL; virtual;
    
    function InitiateMultipartUpload(const ABucketName, AKey: string): string; virtual;
    function UploadPart(const ABucketName, AKey, AUploadId: string;
      APartNumber: Integer; AStream: TStream): string; virtual;
    function CompleteMultipartUpload(const ABucketName, AKey, AUploadId: string;
      const AParts: TArray<TPair<Integer, string>>): Boolean; virtual;
    function AbortMultipartUpload(const ABucketName, AKey, AUploadId: string): Boolean; virtual;
    
    property Credentials: TCloudCredentials read FCredentials;
    property OnUploadProgress: TUploadProgress read FOnUploadProgress write FOnUploadProgress;
    property OnDownloadProgress: TDownloadProgress read FOnDownloadProgress write FOnDownloadProgress;
  end;

  TAWSS3Client = class(TCloudStorageClient)
  private
    function SignAWSRequest(const AMethod, AService, ARegion, APath: string;
      const APayload: string; AHeaders: TNetHeaders): TNetHeaders;
  protected
    function SignRequest(const AMethod, APath: string;
      AHeaders: TNetHeaders): TNetHeaders; override;
    function BuildUrl(const ABucketName, AKey: string): string; override;
  public
    function GetPresignedUrl(const ABucketName, AKey: string;
      AExpiresInSeconds: Integer = 3600): string; override;
  end;

  TAzureBlobClient = class(TCloudStorageClient)
  private
    function SignAzureRequest(const AMethod, AResource: string;
      AHeaders: TNetHeaders): TNetHeaders;
  protected
    function SignRequest(const AMethod, APath: string;
      AHeaders: TNetHeaders): TNetHeaders; override;
    function BuildUrl(const ABucketName, AKey: string): string; override;
  public
    function CreateBucket(const ABucketName: string; const ARegion: string = ''): Boolean; override;
  end;

  TAliOSSClient = class(TCloudStorageClient)
  private
    function SignAliRequest(const AMethod, ABucket, AKey: string;
      AHeaders: TNetHeaders): TNetHeaders;
  protected
    function SignRequest(const AMethod, APath: string;
      AHeaders: TNetHeaders): TNetHeaders; override;
    function BuildUrl(const ABucketName, AKey: string): string; override;
  end;

  TCloudStorageHelper = class
  public
    class function UploadFile(AClient: ICloudStorageClient; const ABucketName, AKey, AFileName: string): Boolean;
    class function DownloadFile(AClient: ICloudStorageClient; const ABucketName, AKey, AFileName: string): Boolean;
    class function UploadDirectory(AClient: ICloudStorageClient; const ABucketName, APrefix, ALocalDir: string): Integer;
    class function DownloadDirectory(AClient: ICloudStorageClient; const ABucketName, APrefix, ALocalDir: string): Integer;
    class function SyncDirectory(AClient: ICloudStorageClient; const ABucketName, APrefix, ALocalDir: string): Integer;
    class function GetContentType(const AFileName: string): string;
  end;

function CreateCloudStorageClient(const ACredentials: TCloudCredentials): ICloudStorageClient;

implementation

uses
  System.IOUtils, System.DateUtils, System.Hash, System.StrUtils;

{ TCloudCredentials }

class function TCloudCredentials.ForAWS(const AAccessKey, ASecretKey, ARegion: string): TCloudCredentials;
begin
  Result.Provider := cspAWSS3;
  Result.AccessKeyId := AAccessKey;
  Result.SecretAccessKey := ASecretKey;
  Result.Region := ARegion;
  Result.Endpoint := Format('s3.%s.amazonaws.com', [ARegion]);
end;

class function TCloudCredentials.ForAzure(const AAccountName, AAccountKey: string): TCloudCredentials;
begin
  Result.Provider := cspAzureBlob;
  Result.AccountName := AAccountName;
  Result.SecretAccessKey := AAccountKey;
  Result.Endpoint := Format('%s.blob.core.windows.net', [AAccountName]);
end;

class function TCloudCredentials.ForAliOSS(const AAccessKey, ASecretKey, ARegion: string): TCloudCredentials;
begin
  Result.Provider := cspAliOSS;
  Result.AccessKeyId := AAccessKey;
  Result.SecretAccessKey := ASecretKey;
  Result.Region := ARegion;
  Result.Endpoint := Format('oss-%s.aliyuncs.com', [ARegion]);
end;

class function TCloudCredentials.ForGoogle(const AProjectId, AServiceAccountJson: string): TCloudCredentials;
begin
  Result.Provider := cspGoogleCloud;
  Result.ProjectId := AProjectId;
  Result.SecretAccessKey := AServiceAccountJson;
  Result.Endpoint := 'storage.googleapis.com';
end;

class function TCloudCredentials.ForMinIO(const AEndpoint, AAccessKey, ASecretKey: string): TCloudCredentials;
begin
  Result.Provider := cspMinIO;
  Result.Endpoint := AEndpoint;
  Result.AccessKeyId := AAccessKey;
  Result.SecretAccessKey := ASecretKey;
end;

{ TCloudStorageClient }

constructor TCloudStorageClient.Create(const ACredentials: TCloudCredentials);
begin
  FCredentials := ACredentials;
  FHttpClient := THTTPClient.Create;
  FHttpClient.UserAgent := 'DeepBase-CloudStorage/1.0';
end;

destructor TCloudStorageClient.Destroy;
begin
  FHttpClient.Free;
  inherited;
end;

function TCloudStorageClient.SignRequest(const AMethod, APath: string;
  AHeaders: TNetHeaders): TNetHeaders;
begin
  Result := AHeaders;
end;

function TCloudStorageClient.BuildUrl(const ABucketName, AKey: string): string;
begin
  Result := Format('https://%s/%s/%s', [FCredentials.Endpoint, ABucketName, AKey]);
end;

function TCloudStorageClient.CreateBucket(const ABucketName: string; const ARegion: string): Boolean;
var
  Response: IHTTPResponse;
  Url: string;
  Headers: TNetHeaders;
begin
  Url := Format('https://%s/%s', [FCredentials.Endpoint, ABucketName]);
  Headers := SignRequest('PUT', '/' + ABucketName, nil);
  Response := FHttpClient.Put(Url, TStream(nil), TStream(nil), Headers);
  Result := Response.StatusCode in [200, 201, 204];
end;

function TCloudStorageClient.DeleteBucket(const ABucketName: string): Boolean;
var
  Response: IHTTPResponse;
  Url: string;
  Headers: TNetHeaders;
begin
  Url := Format('https://%s/%s', [FCredentials.Endpoint, ABucketName]);
  Headers := SignRequest('DELETE', '/' + ABucketName, nil);
  Response := FHttpClient.Delete(Url, nil, Headers);
  Result := Response.StatusCode in [200, 204];
end;

function TCloudStorageClient.BucketExists(const ABucketName: string): Boolean;
var
  Response: IHTTPResponse;
  Url: string;
  Headers: TNetHeaders;
begin
  Url := Format('https://%s/%s', [FCredentials.Endpoint, ABucketName]);
  Headers := SignRequest('HEAD', '/' + ABucketName, nil);
  Response := FHttpClient.Head(Url, Headers);
  Result := Response.StatusCode = 200;
end;

function TCloudStorageClient.ListBuckets: TArray<string>;
begin
  SetLength(Result, 0);
end;

function TCloudStorageClient.PutObject(const ABucketName, AKey: string; AStream: TStream;
  const AContentType: string): Boolean;
var
  Response: IHTTPResponse;
  Url: string;
  Headers: TNetHeaders;
begin
  Url := BuildUrl(ABucketName, AKey);
  SetLength(Headers, 1);
  Headers[0] := TNameValuePair.Create('Content-Type', AContentType);
  Headers := SignRequest('PUT', '/' + ABucketName + '/' + AKey, Headers);
  
  AStream.Position := 0;
  Response := FHttpClient.Put(Url, AStream, nil, Headers);
  Result := Response.StatusCode in [200, 201];
end;

function TCloudStorageClient.GetObject(const ABucketName, AKey: string; AStream: TStream): Boolean;
var
  Response: IHTTPResponse;
  Url: string;
  Headers: TNetHeaders;
begin
  Url := BuildUrl(ABucketName, AKey);
  Headers := SignRequest('GET', '/' + ABucketName + '/' + AKey, nil);
  Response := FHttpClient.Get(Url, AStream, Headers);
  Result := Response.StatusCode = 200;
end;

function TCloudStorageClient.DeleteObject(const ABucketName, AKey: string): Boolean;
var
  Response: IHTTPResponse;
  Url: string;
  Headers: TNetHeaders;
begin
  Url := BuildUrl(ABucketName, AKey);
  Headers := SignRequest('DELETE', '/' + ABucketName + '/' + AKey, nil);
  Response := FHttpClient.Delete(Url, nil, Headers);
  Result := Response.StatusCode in [200, 204];
end;

function TCloudStorageClient.CopyObject(const ASrcBucket, ASrcKey, ADestBucket, ADestKey: string): Boolean;
begin
  Result := False;
end;

function TCloudStorageClient.ObjectExists(const ABucketName, AKey: string): Boolean;
var
  Response: IHTTPResponse;
  Url: string;
  Headers: TNetHeaders;
begin
  Url := BuildUrl(ABucketName, AKey);
  Headers := SignRequest('HEAD', '/' + ABucketName + '/' + AKey, nil);
  Response := FHttpClient.Head(Url, Headers);
  Result := Response.StatusCode = 200;
end;

function TCloudStorageClient.GetObjectInfo(const ABucketName, AKey: string): TCloudObject;
var
  Response: IHTTPResponse;
  Url: string;
  Headers: TNetHeaders;
begin
  Url := BuildUrl(ABucketName, AKey);
  Headers := SignRequest('HEAD', '/' + ABucketName + '/' + AKey, nil);
  Response := FHttpClient.Head(Url, Headers);
  
  Result.Key := AKey;
  if Response.StatusCode = 200 then
  begin
    Result.Size := StrToInt64Def(Response.HeaderValue['Content-Length'], 0);
    Result.ContentType := Response.HeaderValue['Content-Type'];
    Result.ETag := Response.HeaderValue['ETag'];
  end;
end;

function TCloudStorageClient.ListObjects(const ABucketName: string; const APrefix: string;
  const ADelimiter: string; AMaxKeys: Integer): TListObjectsResult;
begin
  SetLength(Result.Objects, 0);
  SetLength(Result.CommonPrefixes, 0);
  Result.IsTruncated := False;
  Result.ContinuationToken := '';
end;

function TCloudStorageClient.GetPresignedUrl(const ABucketName, AKey: string;
  AExpiresInSeconds: Integer): string;
begin
  Result := BuildUrl(ABucketName, AKey);
end;

function TCloudStorageClient.GetPublicUrl(const ABucketName, AKey: string): string;
begin
  Result := BuildUrl(ABucketName, AKey);
end;

procedure TCloudStorageClient.SetObjectACL(const ABucketName, AKey: string; AACL: TObjectACL);
begin
  // Implementation depends on provider
end;

function TCloudStorageClient.GetObjectACL(const ABucketName, AKey: string): TObjectACL;
begin
  Result := aclPrivate;
end;

function TCloudStorageClient.InitiateMultipartUpload(const ABucketName, AKey: string): string;
begin
  Result := '';
end;

function TCloudStorageClient.UploadPart(const ABucketName, AKey, AUploadId: string;
  APartNumber: Integer; AStream: TStream): string;
begin
  Result := '';
end;

function TCloudStorageClient.CompleteMultipartUpload(const ABucketName, AKey, AUploadId: string;
  const AParts: TArray<TPair<Integer, string>>): Boolean;
begin
  Result := False;
end;

function TCloudStorageClient.AbortMultipartUpload(const ABucketName, AKey, AUploadId: string): Boolean;
begin
  Result := False;
end;

{ TAWSS3Client - AWS Signature Version 4 Implementation }

function TAWSS3Client.SignAWSRequest(const AMethod, AService, ARegion, APath: string;
  const APayload: string; AHeaders: TNetHeaders): TNetHeaders;
var
  AmzDate, DateStamp: string;
  Host: string;
  CanonicalUri, CanonicalQueryString: string;
  CanonicalHeaders, SignedHeaders: string;
  PayloadHash: string;
  CanonicalRequest: string;
  Algorithm, CredentialScope: string;
  StringToSign: string;
  SigningKey: TBytes;
  Signature: string;
  AuthorizationHeader: string;
  I: Integer;
  HeaderList: TStringList;
  
  function HMACSHA256(const AData: TBytes; const AKey: TBytes): TBytes;
  begin
    Result := THashSHA2.GetHMACAsBytes(AData, AKey, THashSHA2.TSHA2Version.SHA256);
  end;
  
  function GetSignatureKey(const AKey, ADateStamp, ARegionName, AServiceName: string): TBytes;
  var
    kDate, kRegion, kService: TBytes;
  begin
    kDate := HMACSHA256(TEncoding.UTF8.GetBytes(ADateStamp), 
                        TEncoding.UTF8.GetBytes('AWS4' + AKey));
    kRegion := HMACSHA256(TEncoding.UTF8.GetBytes(ARegionName), kDate);
    kService := HMACSHA256(TEncoding.UTF8.GetBytes(AServiceName), kRegion);
    Result := HMACSHA256(TEncoding.UTF8.GetBytes('aws4_request'), kService);
  end;
  
  function BytesToHex(const ABytes: TBytes): string;
  var
    B: Byte;
  begin
    Result := '';
    for B in ABytes do
      Result := Result + IntToHex(B, 2);
    Result := LowerCase(Result);
  end;
  
begin
  // Get current time in UTC
  AmzDate := FormatDateTime('yyyymmdd"T"hhnnss"Z"', TTimeZone.Local.ToUniversalTime(Now));
  DateStamp := FormatDateTime('yyyymmdd', TTimeZone.Local.ToUniversalTime(Now));
  
  // Host header
  Host := Credentials.Endpoint;
  
  // Canonical URI (URL-encoded path)
  CanonicalUri := APath;
  if CanonicalUri = '' then
    CanonicalUri := '/';
  
  // Canonical query string (empty for most requests)
  CanonicalQueryString := '';
  
  // Payload hash
  if APayload <> '' then
    PayloadHash := LowerCase(THashSHA2.GetHashString(APayload, THashSHA2.TSHA2Version.SHA256))
  else
    PayloadHash := 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'; // Empty string hash
  
  // Build canonical headers
  HeaderList := TStringList.Create;
  try
    HeaderList.CaseSensitive := False;
    HeaderList.Sorted := True;
    
    // Add required headers
    HeaderList.Values['host'] := Host;
    HeaderList.Values['x-amz-content-sha256'] := PayloadHash;
    HeaderList.Values['x-amz-date'] := AmzDate;
    
    // Add existing headers
    for I := 0 to Length(AHeaders) - 1 do
      HeaderList.Values[LowerCase(AHeaders[I].Name)] := AHeaders[I].Value;
    
    // Build canonical headers string
    CanonicalHeaders := '';
    SignedHeaders := '';
    for I := 0 to HeaderList.Count - 1 do
    begin
      if HeaderList.Names[I] <> '' then
      begin
        CanonicalHeaders := CanonicalHeaders + LowerCase(HeaderList.Names[I]) + ':' + 
                           Trim(HeaderList.ValueFromIndex[I]) + #10;
        if SignedHeaders <> '' then
          SignedHeaders := SignedHeaders + ';';
        SignedHeaders := SignedHeaders + LowerCase(HeaderList.Names[I]);
      end;
    end;
  finally
    HeaderList.Free;
  end;
  
  // Create canonical request
  CanonicalRequest := AMethod + #10 +
                      CanonicalUri + #10 +
                      CanonicalQueryString + #10 +
                      CanonicalHeaders + #10 +
                      SignedHeaders + #10 +
                      PayloadHash;
  
  // Create string to sign
  Algorithm := 'AWS4-HMAC-SHA256';
  CredentialScope := DateStamp + '/' + ARegion + '/' + AService + '/aws4_request';
  StringToSign := Algorithm + #10 +
                  AmzDate + #10 +
                  CredentialScope + #10 +
                  LowerCase(THashSHA2.GetHashString(CanonicalRequest, THashSHA2.TSHA2Version.SHA256));
  
  // Calculate signature
  SigningKey := GetSignatureKey(Credentials.SecretAccessKey, DateStamp, ARegion, AService);
  Signature := BytesToHex(HMACSHA256(TEncoding.UTF8.GetBytes(StringToSign), SigningKey));
  
  // Create authorization header
  AuthorizationHeader := Algorithm + ' ' +
                         'Credential=' + Credentials.AccessKeyId + '/' + CredentialScope + ', ' +
                         'SignedHeaders=' + SignedHeaders + ', ' +
                         'Signature=' + Signature;
  
  // Build result headers
  SetLength(Result, Length(AHeaders) + 4);
  for I := 0 to Length(AHeaders) - 1 do
    Result[I] := AHeaders[I];
  
  Result[Length(AHeaders)] := TNameValuePair.Create('Host', Host);
  Result[Length(AHeaders) + 1] := TNameValuePair.Create('x-amz-date', AmzDate);
  Result[Length(AHeaders) + 2] := TNameValuePair.Create('x-amz-content-sha256', PayloadHash);
  Result[Length(AHeaders) + 3] := TNameValuePair.Create('Authorization', AuthorizationHeader);
end;

function TAWSS3Client.SignRequest(const AMethod, APath: string;
  AHeaders: TNetHeaders): TNetHeaders;
begin
  Result := SignAWSRequest(AMethod, 's3', Credentials.Region, APath, '', AHeaders);
end;

function TAWSS3Client.BuildUrl(const ABucketName, AKey: string): string;
begin
  Result := Format('https://%s.s3.%s.amazonaws.com/%s', 
    [ABucketName, Credentials.Region, TNetEncoding.URL.Encode(AKey)]);
end;

function TAWSS3Client.GetPresignedUrl(const ABucketName, AKey: string;
  AExpiresInSeconds: Integer): string;
var
  AmzDate, DateStamp: string;
  Host: string;
  CanonicalUri: string;
  CredentialScope: string;
  SignedHeaders: string;
  CanonicalQueryString: string;
  CanonicalRequest: string;
  StringToSign: string;
  SigningKey: TBytes;
  Signature: string;
  
  function HMACSHA256(const AData: TBytes; const AKey: TBytes): TBytes;
  begin
    Result := THashSHA2.GetHMACAsBytes(AData, AKey, THashSHA2.TSHA2Version.SHA256);
  end;
  
  function GetSignatureKey(const AKey, ADateStamp, ARegionName, AServiceName: string): TBytes;
  var
    kDate, kRegion, kService: TBytes;
  begin
    kDate := HMACSHA256(TEncoding.UTF8.GetBytes(ADateStamp), 
                        TEncoding.UTF8.GetBytes('AWS4' + AKey));
    kRegion := HMACSHA256(TEncoding.UTF8.GetBytes(ARegionName), kDate);
    kService := HMACSHA256(TEncoding.UTF8.GetBytes(AServiceName), kRegion);
    Result := HMACSHA256(TEncoding.UTF8.GetBytes('aws4_request'), kService);
  end;
  
  function BytesToHex(const ABytes: TBytes): string;
  var
    B: Byte;
  begin
    Result := '';
    for B in ABytes do
      Result := Result + IntToHex(B, 2);
    Result := LowerCase(Result);
  end;
  
begin
  AmzDate := FormatDateTime('yyyymmdd"T"hhnnss"Z"', TTimeZone.Local.ToUniversalTime(Now));
  DateStamp := FormatDateTime('yyyymmdd', TTimeZone.Local.ToUniversalTime(Now));
  
  Host := ABucketName + '.s3.' + Credentials.Region + '.amazonaws.com';
  CanonicalUri := '/' + TNetEncoding.URL.Encode(AKey);
  CredentialScope := DateStamp + '/' + Credentials.Region + '/s3/aws4_request';
  SignedHeaders := 'host';
  
  // Build query string for presigned URL
  CanonicalQueryString := 'X-Amz-Algorithm=AWS4-HMAC-SHA256' +
    '&X-Amz-Credential=' + TNetEncoding.URL.Encode(Credentials.AccessKeyId + '/' + CredentialScope) +
    '&X-Amz-Date=' + AmzDate +
    '&X-Amz-Expires=' + IntToStr(AExpiresInSeconds) +
    '&X-Amz-SignedHeaders=' + SignedHeaders;
  
  // Create canonical request
  CanonicalRequest := 'GET' + #10 +
                      CanonicalUri + #10 +
                      CanonicalQueryString + #10 +
                      'host:' + Host + #10 + #10 +
                      SignedHeaders + #10 +
                      'UNSIGNED-PAYLOAD';
  
  // Create string to sign
  StringToSign := 'AWS4-HMAC-SHA256' + #10 +
                  AmzDate + #10 +
                  CredentialScope + #10 +
                  LowerCase(THashSHA2.GetHashString(CanonicalRequest, THashSHA2.TSHA2Version.SHA256));
  
  // Calculate signature
  SigningKey := GetSignatureKey(Credentials.SecretAccessKey, DateStamp, Credentials.Region, 's3');
  Signature := BytesToHex(HMACSHA256(TEncoding.UTF8.GetBytes(StringToSign), SigningKey));
  
  // Build presigned URL
  Result := 'https://' + Host + CanonicalUri + '?' + CanonicalQueryString + 
            '&X-Amz-Signature=' + Signature;
end;

{ TAzureBlobClient - Azure SharedKey Authentication Implementation }

function TAzureBlobClient.SignAzureRequest(const AMethod, AResource: string;
  AHeaders: TNetHeaders): TNetHeaders;
var
  DateStr: string;
  ContentLength, ContentType: string;
  CanonicalizedHeaders: string;
  CanonicalizedResource: string;
  StringToSign: string;
  SignatureBytes: TBytes;
  Signature: string;
  AuthHeader: string;
  I: Integer;
  HeaderList: TStringList;
  
  function GetHeaderValue(const AName: string): string;
  var
    J: Integer;
  begin
    Result := '';
    for J := 0 to Length(AHeaders) - 1 do
      if SameText(AHeaders[J].Name, AName) then
      begin
        Result := AHeaders[J].Value;
        Break;
      end;
  end;
  
begin
  // Get current time in RFC 1123 format
  DateStr := FormatDateTime('ddd, dd mmm yyyy hh:nn:ss "GMT"', 
    TTimeZone.Local.ToUniversalTime(Now), TFormatSettings.Create('en-US'));
  
  // Get content headers
  ContentLength := GetHeaderValue('Content-Length');
  ContentType := GetHeaderValue('Content-Type');
  
  // Build canonicalized headers (x-ms-* headers sorted alphabetically)
  HeaderList := TStringList.Create;
  try
    HeaderList.CaseSensitive := False;
    HeaderList.Sorted := True;
    
    // Add required x-ms headers
    HeaderList.Values['x-ms-date'] := DateStr;
    HeaderList.Values['x-ms-version'] := '2021-06-08';
    
    // Add existing x-ms headers
    for I := 0 to Length(AHeaders) - 1 do
      if StartsText('x-ms-', AHeaders[I].Name) then
        HeaderList.Values[LowerCase(AHeaders[I].Name)] := AHeaders[I].Value;
    
    // Build canonicalized headers string
    CanonicalizedHeaders := '';
    for I := 0 to HeaderList.Count - 1 do
    begin
      if StartsText('x-ms-', HeaderList.Names[I]) then
        CanonicalizedHeaders := CanonicalizedHeaders + 
          LowerCase(HeaderList.Names[I]) + ':' + Trim(HeaderList.ValueFromIndex[I]) + #10;
    end;
  finally
    HeaderList.Free;
  end;
  
  // Build canonicalized resource
  CanonicalizedResource := '/' + Credentials.AccountName + AResource;
  
  // Build string to sign (SharedKey format)
  // VERB\nContent-Encoding\nContent-Language\nContent-Length\nContent-MD5\nContent-Type\n
  // Date\nIf-Modified-Since\nIf-Match\nIf-None-Match\nIf-Unmodified-Since\nRange\n
  // CanonicalizedHeaders\nCanonicalizedResource
  StringToSign := AMethod + #10 +                    // VERB
                  '' + #10 +                          // Content-Encoding
                  '' + #10 +                          // Content-Language
                  ContentLength + #10 +               // Content-Length
                  '' + #10 +                          // Content-MD5
                  ContentType + #10 +                 // Content-Type
                  '' + #10 +                          // Date (empty, using x-ms-date)
                  '' + #10 +                          // If-Modified-Since
                  '' + #10 +                          // If-Match
                  '' + #10 +                          // If-None-Match
                  '' + #10 +                          // If-Unmodified-Since
                  '' + #10 +                          // Range
                  CanonicalizedHeaders +
                  CanonicalizedResource;
  
  // Calculate HMAC-SHA256 signature
  SignatureBytes := THashSHA2.GetHMACAsBytes(
    TEncoding.UTF8.GetBytes(StringToSign),
    TNetEncoding.Base64.DecodeStringToBytes(Credentials.SecretAccessKey),
    THashSHA2.TSHA2Version.SHA256);
  Signature := TNetEncoding.Base64.EncodeBytesToString(SignatureBytes);
  
  // Build authorization header
  AuthHeader := 'SharedKey ' + Credentials.AccountName + ':' + Signature;
  
  // Build result headers
  SetLength(Result, Length(AHeaders) + 3);
  for I := 0 to Length(AHeaders) - 1 do
    Result[I] := AHeaders[I];
  
  Result[Length(AHeaders)] := TNameValuePair.Create('x-ms-date', DateStr);
  Result[Length(AHeaders) + 1] := TNameValuePair.Create('x-ms-version', '2021-06-08');
  Result[Length(AHeaders) + 2] := TNameValuePair.Create('Authorization', AuthHeader);
end;

function TAzureBlobClient.SignRequest(const AMethod, APath: string;
  AHeaders: TNetHeaders): TNetHeaders;
begin
  Result := SignAzureRequest(AMethod, APath, AHeaders);
end;

function TAzureBlobClient.BuildUrl(const ABucketName, AKey: string): string;
begin
  Result := Format('https://%s.blob.core.windows.net/%s/%s',
    [Credentials.AccountName, ABucketName, TNetEncoding.URL.Encode(AKey)]);
end;

function TAzureBlobClient.CreateBucket(const ABucketName: string; const ARegion: string): Boolean;
var
  Response: IHTTPResponse;
  Url: string;
  Headers: TNetHeaders;
begin
  // Azure creates containers, not buckets
  Url := Format('https://%s.blob.core.windows.net/%s?restype=container',
    [Credentials.AccountName, ABucketName]);
  Headers := SignRequest('PUT', '/' + ABucketName + #10 + 'restype:container', nil);
  Response := FHttpClient.Put(Url, TStream(nil), TStream(nil), Headers);
  Result := Response.StatusCode in [200, 201];
end;

{ TAliOSSClient - Alibaba Cloud OSS Signature Implementation }

function TAliOSSClient.SignAliRequest(const AMethod, ABucket, AKey: string;
  AHeaders: TNetHeaders): TNetHeaders;
var
  DateStr: string;
  ContentType, ContentMD5: string;
  CanonicalizedOSSHeaders: string;
  CanonicalizedResource: string;
  StringToSign: string;
  SignatureBytes: TBytes;
  Signature: string;
  AuthHeader: string;
  I: Integer;
  HeaderList: TStringList;
  
  function GetHeaderValue(const AName: string): string;
  var
    J: Integer;
  begin
    Result := '';
    for J := 0 to Length(AHeaders) - 1 do
      if SameText(AHeaders[J].Name, AName) then
      begin
        Result := AHeaders[J].Value;
        Break;
      end;
  end;
  
begin
  // Get current time in RFC 1123 format (GMT)
  DateStr := FormatDateTime('ddd, dd mmm yyyy hh:nn:ss "GMT"', 
    TTimeZone.Local.ToUniversalTime(Now), TFormatSettings.Create('en-US'));
  
  // Get content headers
  ContentType := GetHeaderValue('Content-Type');
  ContentMD5 := GetHeaderValue('Content-MD5');
  
  // Build canonicalized OSS headers (x-oss-* headers sorted alphabetically)
  HeaderList := TStringList.Create;
  try
    HeaderList.CaseSensitive := False;
    HeaderList.Sorted := True;
    
    // Add existing x-oss headers
    for I := 0 to Length(AHeaders) - 1 do
      if StartsText('x-oss-', AHeaders[I].Name) then
        HeaderList.Values[LowerCase(AHeaders[I].Name)] := AHeaders[I].Value;
    
    // Build canonicalized headers string
    CanonicalizedOSSHeaders := '';
    for I := 0 to HeaderList.Count - 1 do
    begin
      if StartsText('x-oss-', HeaderList.Names[I]) then
        CanonicalizedOSSHeaders := CanonicalizedOSSHeaders + 
          LowerCase(HeaderList.Names[I]) + ':' + Trim(HeaderList.ValueFromIndex[I]) + #10;
    end;
  finally
    HeaderList.Free;
  end;
  
  // Build canonicalized resource
  if ABucket <> '' then
  begin
    if AKey <> '' then
      CanonicalizedResource := '/' + ABucket + '/' + AKey
    else
      CanonicalizedResource := '/' + ABucket + '/';
  end
  else
    CanonicalizedResource := '/';
  
  // Build string to sign (OSS format)
  // VERB + "\n" + Content-MD5 + "\n" + Content-Type + "\n" + Date + "\n" + 
  // CanonicalizedOSSHeaders + CanonicalizedResource
  StringToSign := AMethod + #10 +
                  ContentMD5 + #10 +
                  ContentType + #10 +
                  DateStr + #10 +
                  CanonicalizedOSSHeaders +
                  CanonicalizedResource;
  
  // Calculate HMAC-SHA1 signature (OSS uses SHA1)
  SignatureBytes := THashSHA1.GetHMACAsBytes(
    TEncoding.UTF8.GetBytes(StringToSign),
    TEncoding.UTF8.GetBytes(Credentials.SecretAccessKey));
  Signature := TNetEncoding.Base64.EncodeBytesToString(SignatureBytes);
  
  // Build authorization header
  AuthHeader := 'OSS ' + Credentials.AccessKeyId + ':' + Signature;
  
  // Build result headers
  SetLength(Result, Length(AHeaders) + 2);
  for I := 0 to Length(AHeaders) - 1 do
    Result[I] := AHeaders[I];
  
  Result[Length(AHeaders)] := TNameValuePair.Create('Date', DateStr);
  Result[Length(AHeaders) + 1] := TNameValuePair.Create('Authorization', AuthHeader);
end;

function TAliOSSClient.SignRequest(const AMethod, APath: string;
  AHeaders: TNetHeaders): TNetHeaders;
var
  Bucket, Key: string;
  SlashPos: Integer;
begin
  // Parse bucket and key from path
  if (Length(APath) > 1) and (APath[1] = '/') then
  begin
    SlashPos := Pos('/', Copy(APath, 2, MaxInt));
    if SlashPos > 0 then
    begin
      Bucket := Copy(APath, 2, SlashPos - 1);
      Key := Copy(APath, SlashPos + 2, MaxInt);
    end
    else
    begin
      Bucket := Copy(APath, 2, MaxInt);
      Key := '';
    end;
  end
  else
  begin
    Bucket := '';
    Key := '';
  end;
  
  Result := SignAliRequest(AMethod, Bucket, Key, AHeaders);
end;

function TAliOSSClient.BuildUrl(const ABucketName, AKey: string): string;
begin
  Result := Format('https://%s.%s/%s',
    [ABucketName, Credentials.Endpoint, TNetEncoding.URL.Encode(AKey)]);
end;

{ TCloudStorageHelper }

class function TCloudStorageHelper.UploadFile(AClient: ICloudStorageClient;
  const ABucketName, AKey, AFileName: string): Boolean;
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    Result := AClient.PutObject(ABucketName, AKey, Stream, GetContentType(AFileName));
  finally
    Stream.Free;
  end;
end;

class function TCloudStorageHelper.DownloadFile(AClient: ICloudStorageClient;
  const ABucketName, AKey, AFileName: string): Boolean;
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(AFileName, fmCreate);
  try
    Result := AClient.GetObject(ABucketName, AKey, Stream);
  finally
    Stream.Free;
  end;
end;

class function TCloudStorageHelper.UploadDirectory(AClient: ICloudStorageClient;
  const ABucketName, APrefix, ALocalDir: string): Integer;
var
  Files: TArray<string>;
  F, Key: string;
begin
  Result := 0;
  Files := TDirectory.GetFiles(ALocalDir, '*', TSearchOption.soAllDirectories);
  for F in Files do
  begin
    Key := APrefix + StringReplace(F, ALocalDir, '', []).Replace('\', '/');
    if UploadFile(AClient, ABucketName, Key, F) then
      Inc(Result);
  end;
end;

class function TCloudStorageHelper.DownloadDirectory(AClient: ICloudStorageClient;
  const ABucketName, APrefix, ALocalDir: string): Integer;
var
  ListResult: TListObjectsResult;
  Obj: TCloudObject;
  LocalPath: string;
  RelativeKey: string;

  function BuildSafeLocalPath(const AObjectKey: string): string;
  var
    RootDir: string;
    EntryName: string;
  begin
    EntryName := StringReplace(AObjectKey, '/', PathDelim, [rfReplaceAll]);
    EntryName := StringReplace(EntryName, '\', PathDelim, [rfReplaceAll]);

    if (EntryName = '') or (ExtractFileDrive(EntryName) <> '') or
       EntryName.StartsWith(PathDelim) or EntryName.StartsWith('/') or
       EntryName.StartsWith('\') then
      raise Exception.CreateFmt('Unsafe cloud object key path: %s', [AObjectKey]);

    RootDir := IncludeTrailingPathDelimiter(TPath.GetFullPath(ALocalDir));
    Result := TPath.GetFullPath(TPath.Combine(RootDir, EntryName));

    if not SameText(Copy(Result, 1, Length(RootDir)), RootDir) then
      raise Exception.CreateFmt('Cloud object key escapes local directory: %s', [AObjectKey]);
  end;
begin
  Result := 0;
  ListResult := AClient.ListObjects(ABucketName, APrefix, '', 1000);
  
  for Obj in ListResult.Objects do
  begin
    if (APrefix <> '') and Obj.Key.StartsWith(APrefix) then
      RelativeKey := Copy(Obj.Key, Length(APrefix) + 1, MaxInt)
    else
      RelativeKey := Obj.Key;

    if (APrefix <> '') and (RelativeKey <> '') and
       ((RelativeKey[1] = '/') or (RelativeKey[1] = '\')) then
      Delete(RelativeKey, 1, 1);

    LocalPath := BuildSafeLocalPath(RelativeKey);
    TDirectory.CreateDirectory(TPath.GetDirectoryName(LocalPath));
    if DownloadFile(AClient, ABucketName, Obj.Key, LocalPath) then
      Inc(Result);
  end;
end;

class function TCloudStorageHelper.SyncDirectory(AClient: ICloudStorageClient;
  const ABucketName, APrefix, ALocalDir: string): Integer;
begin
  Result := UploadDirectory(AClient, ABucketName, APrefix, ALocalDir);
end;

class function TCloudStorageHelper.GetContentType(const AFileName: string): string;
var
  Ext: string;
begin
  Ext := LowerCase(TPath.GetExtension(AFileName));
  
  if Ext = '.html' then Result := 'text/html'
  else if Ext = '.htm' then Result := 'text/html'
  else if Ext = '.css' then Result := 'text/css'
  else if Ext = '.js' then Result := 'application/javascript'
  else if Ext = '.json' then Result := 'application/json'
  else if Ext = '.xml' then Result := 'application/xml'
  else if Ext = '.txt' then Result := 'text/plain'
  else if Ext = '.pdf' then Result := 'application/pdf'
  else if Ext = '.zip' then Result := 'application/zip'
  else if Ext = '.png' then Result := 'image/png'
  else if Ext = '.jpg' then Result := 'image/jpeg'
  else if Ext = '.jpeg' then Result := 'image/jpeg'
  else if Ext = '.gif' then Result := 'image/gif'
  else if Ext = '.svg' then Result := 'image/svg+xml'
  else if Ext = '.mp3' then Result := 'audio/mpeg'
  else if Ext = '.mp4' then Result := 'video/mp4'
  else Result := 'application/octet-stream';
end;

{ Factory function }

function CreateCloudStorageClient(const ACredentials: TCloudCredentials): ICloudStorageClient;
begin
  case ACredentials.Provider of
    cspAWSS3:
      Result := TAWSS3Client.Create(ACredentials);
    cspAzureBlob:
      Result := TAzureBlobClient.Create(ACredentials);
    cspAliOSS:
      Result := TAliOSSClient.Create(ACredentials);
    cspMinIO:
      Result := TAWSS3Client.Create(ACredentials); // S3 compatible
  else
    Result := TCloudStorageClient.Create(ACredentials);
  end;
end;

end.
