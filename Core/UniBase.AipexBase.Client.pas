{ ============================================================================
  UniBase.AipexBase.Client - AipexBase API Client
  
  Version: 1.0
  Description: API client for AipexBase backend service.
               Handles user authentication, billing, usage statistics, etc.
  
  Features:
    - User registration/login/password recovery
    - User profile management
    - Balance and recharge
    - Usage statistics
    - Billing and invoices
  ============================================================================ }

unit UniBase.AipexBase.Client;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.DateUtils,
  System.Net.HttpClient, System.Net.HttpClientComponent, System.Net.URLClient,
  System.Generics.Collections, System.NetEncoding, System.Net.Mime;

type
  /// <summary>API Exception base class</summary>
  EAipexBaseError = class(Exception)
  public
    StatusCode: Integer;
    ErrorCode: string;
    constructor Create(const AMessage: string; AStatusCode: Integer = 0;
      const AErrorCode: string = ''); reintroduce;
  end;

  EAipexBaseAuthError = class(EAipexBaseError);      // 401
  EAipexBaseNotFoundError = class(EAipexBaseError);  // 404
  EAipexBaseValidationError = class(EAipexBaseError); // 400

  /// <summary>User info record</summary>
  TAipexUser = record
    UserId: Integer;  // Backend uses integer user_id
    Username: string;
    Email: string;
    Phone: string;
    Avatar: string;
    CreatedAt: TDateTime;
    LastLoginAt: TDateTime;
    Status: string;
    
    procedure Clear;
  end;

  /// <summary>Balance info record</summary>
  TAipexBalance = record
    Balance: Currency;
    Currency: string;
    FrozenAmount: Currency;
    AvailableAmount: Currency;
    
    procedure Clear;
  end;

  /// <summary>Recharge option</summary>
  TAipexRechargeOption = record
    Amount: Currency;
    Bonus: Currency;
    Description: string;
  end;
  TAipexRechargeOptions = TArray<TAipexRechargeOption>;

  /// <summary>Transaction record</summary>
  TAipexTransaction = record
    TransactionId: string;
    TransactionType: string;  // recharge, consume, refund
    Amount: Currency;
    Balance: Currency;
    Description: string;
    CreatedAt: TDateTime;
    Status: string;
  end;
  TAipexTransactions = TArray<TAipexTransaction>;

  /// <summary>Usage statistics summary</summary>
  TAipexUsageSummary = record
    TotalCalls: Int64;
    InputTokens: Int64;
    OutputTokens: Int64;
    TotalCost: Currency;
    PeriodStart: TDateTime;
    PeriodEnd: TDateTime;
  end;

  /// <summary>Daily usage data point</summary>
  TAipexUsageDataPoint = record
    Date: TDate;
    Calls: Int64;
    InputTokens: Int64;
    OutputTokens: Int64;
    Cost: Currency;
  end;
  TAipexUsageDataPoints = TArray<TAipexUsageDataPoint>;

  /// <summary>Model usage breakdown</summary>
  TAipexModelUsage = record
    Model: string;
    Calls: Int64;
    Tokens: Int64;
    Cost: Currency;
    Percentage: Double;
  end;
  TAipexModelUsages = TArray<TAipexModelUsage>;

  /// <summary>API call record</summary>
  TAipexApiCall = record
    CallId: string;
    Model: string;
    InputTokens: Integer;
    OutputTokens: Integer;
    Duration: Integer;  // milliseconds
    Cost: Currency;
    CreatedAt: TDateTime;
    Status: string;
  end;
  TAipexApiCalls = TArray<TAipexApiCall>;

  /// <summary>Invoice/Billing record</summary>
  TAipexInvoice = record
    InvoiceId: string;
    InvoiceNo: string;
    PeriodStart: TDateTime;
    PeriodEnd: TDateTime;
    Amount: Currency;
    Status: string;  // pending, invoiced, cancelled
    InvoiceUrl: string;
    CreatedAt: TDateTime;
  end;
  TAipexInvoices = TArray<TAipexInvoice>;

  /// <summary>Login response</summary>
  TAipexLoginResult = record
    Success: Boolean;
    AccessToken: string;
    RefreshToken: string;
    ExpiresIn: Integer;
    User: TAipexUser;
    ErrorMessage: string;
  end;

  /// <summary>Generic API response</summary>
  TAipexApiResponse = record
    Success: Boolean;
    ErrorCode: string;
    ErrorMessage: string;
    Data: TJSONValue;
  end;

  /// <summary>
  /// AipexBase API Client
  /// </summary>
  TAipexBaseClient = class
  private
    FBaseURL: string;
    FAccessToken: string;
    FRefreshToken: string;
    FHttpClient: THTTPClient;
    FTimeout: Integer;
    FCurrentUser: TAipexUser;
    FOnTokenRefreshed: TProc<string, string>;
    
    procedure SetupHeaders;
    function DoGet(const AEndpoint: string): string;
    function DoPost(const AEndpoint: string; const ABody: string): string;
    function DoPut(const AEndpoint: string; const ABody: string): string;
    function DoDelete(const AEndpoint: string): string;
    procedure HandleHttpError(StatusCode: Integer; const ResponseBody: string);
    function ParseJsonResponse(const AJson: string): TAipexApiResponse;
    
  public
    constructor Create(const ABaseURL: string);
    destructor Destroy; override;
    
    // ===== Authentication =====
    
    /// <summary>User login (supports email/phone/username)</summary>
    function Login(const AUsername, APassword: string; ARememberMe: Boolean = False): TAipexLoginResult;
    
    /// <summary>User registration</summary>
    function Register(const AUsername, AEmail, APassword, AConfirmPassword: string): TAipexLoginResult;
    
    /// <summary>Send password reset email</summary>
    function ForgotPassword(const AEmail: string): Boolean;
    
    /// <summary>Reset password with token</summary>
    function ResetPassword(const AToken, ANewPassword: string): Boolean;
    
    /// <summary>Refresh access token</summary>
    function RefreshAccessToken: Boolean;
    
    /// <summary>Logout</summary>
    procedure Logout;
    
    /// <summary>Check if logged in</summary>
    function IsLoggedIn: Boolean;
    
    // ===== User Profile =====
    
    /// <summary>Get current user info</summary>
    function GetUserInfo: TAipexUser;
    
    /// <summary>Update user profile</summary>
    function UpdateProfile(const AUsername, APhone: string): Boolean;
    
    /// <summary>Change password</summary>
    function ChangePassword(const AOldPassword, ANewPassword: string): Boolean;
    
    /// <summary>Upload avatar</summary>
    function UploadAvatar(AStream: TStream): string;
    
    // ===== Balance & Recharge =====
    
    /// <summary>Get current balance</summary>
    function GetBalance: TAipexBalance;
    
    /// <summary>Get recharge options</summary>
    function GetRechargeOptions: TAipexRechargeOptions;
    
    /// <summary>Create recharge order</summary>
    function CreateRechargeOrder(AAmount: Currency; const APaymentMethod: string): string;
    
    /// <summary>Get transaction history</summary>
    function GetTransactions(APage, APageSize: Integer): TAipexTransactions;
    
    // ===== Usage Statistics =====
    
    /// <summary>Get usage summary</summary>
    function GetUsageSummary(AStartDate, AEndDate: TDateTime): TAipexUsageSummary;
    
    /// <summary>Get usage trend data</summary>
    function GetUsageTrend(AStartDate, AEndDate: TDateTime; const AGroupBy: string = 'day'): TAipexUsageDataPoints;
    
    /// <summary>Get model usage breakdown</summary>
    function GetModelUsage(AStartDate, AEndDate: TDateTime): TAipexModelUsages;
    
    /// <summary>Get recent API calls</summary>
    function GetRecentCalls(ALimit: Integer = 20): TAipexApiCalls;
    
    // ===== Billing & Invoices =====
    
    /// <summary>Get invoice list</summary>
    function GetInvoices(APage, APageSize: Integer; const AStatus: string = ''): TAipexInvoices;
    
    /// <summary>Request invoice</summary>
    function RequestInvoice(const AInvoiceId: string): Boolean;
    
    /// <summary>Download invoice</summary>
    function DownloadInvoice(const AInvoiceId: string; AStream: TStream): Boolean;
    
    // ===== Properties =====
    
    property BaseURL: string read FBaseURL write FBaseURL;
    property AccessToken: string read FAccessToken write FAccessToken;
    property RefreshToken: string read FRefreshToken write FRefreshToken;
    property Timeout: Integer read FTimeout write FTimeout;
    property CurrentUser: TAipexUser read FCurrentUser;
    property OnTokenRefreshed: TProc<string, string> read FOnTokenRefreshed write FOnTokenRefreshed;
  end;

implementation

{ EAipexBaseError }

constructor EAipexBaseError.Create(const AMessage: string; AStatusCode: Integer;
  const AErrorCode: string);
begin
  inherited Create(AMessage);
  StatusCode := AStatusCode;
  ErrorCode := AErrorCode;
end;

{ TAipexUser }

procedure TAipexUser.Clear;
begin
  UserId := 0;
  Username := '';
  Email := '';
  Phone := '';
  Avatar := '';
  CreatedAt := 0;
  LastLoginAt := 0;
  Status := '';
end;

{ TAipexBalance }

procedure TAipexBalance.Clear;
begin
  Balance := 0;
  Currency := 'CNY';
  FrozenAmount := 0;
  AvailableAmount := 0;
end;

{ TAipexBaseClient }

constructor TAipexBaseClient.Create(const ABaseURL: string);
begin
  inherited Create;
  FBaseURL := ABaseURL.TrimRight(['/']);
  FTimeout := 30000;
  FHttpClient := THTTPClient.Create;
  FHttpClient.ConnectionTimeout := FTimeout;
  FHttpClient.ResponseTimeout := FTimeout;
  FCurrentUser.Clear;
end;

destructor TAipexBaseClient.Destroy;
begin
  FHttpClient.Free;
  inherited;
end;

procedure TAipexBaseClient.SetupHeaders;
begin
  FHttpClient.CustomHeaders['Content-Type'] := 'application/json';
  FHttpClient.CustomHeaders['Accept'] := 'application/json';
  if FAccessToken <> '' then
    FHttpClient.CustomHeaders['Authorization'] := 'Bearer ' + FAccessToken;
end;

function TAipexBaseClient.DoGet(const AEndpoint: string): string;
var
  Response: IHTTPResponse;
begin
  SetupHeaders;
  Response := FHttpClient.Get(FBaseURL + AEndpoint);
  if Response.StatusCode >= 400 then
    HandleHttpError(Response.StatusCode, Response.ContentAsString);
  Result := Response.ContentAsString;
end;

function TAipexBaseClient.DoPost(const AEndpoint: string; const ABody: string): string;
var
  Response: IHTTPResponse;
  Content: TStringStream;
begin
  SetupHeaders;
  Content := TStringStream.Create(ABody, TEncoding.UTF8);
  try
    Response := FHttpClient.Post(FBaseURL + AEndpoint, Content);
    if Response.StatusCode >= 400 then
      HandleHttpError(Response.StatusCode, Response.ContentAsString);
    Result := Response.ContentAsString;
  finally
    Content.Free;
  end;
end;

function TAipexBaseClient.DoPut(const AEndpoint: string; const ABody: string): string;
var
  Response: IHTTPResponse;
  Content: TStringStream;
begin
  SetupHeaders;
  Content := TStringStream.Create(ABody, TEncoding.UTF8);
  try
    Response := FHttpClient.Put(FBaseURL + AEndpoint, Content);
    if Response.StatusCode >= 400 then
      HandleHttpError(Response.StatusCode, Response.ContentAsString);
    Result := Response.ContentAsString;
  finally
    Content.Free;
  end;
end;

function TAipexBaseClient.DoDelete(const AEndpoint: string): string;
var
  Response: IHTTPResponse;
begin
  SetupHeaders;
  Response := FHttpClient.Delete(FBaseURL + AEndpoint);
  if Response.StatusCode >= 400 then
    HandleHttpError(Response.StatusCode, Response.ContentAsString);
  Result := Response.ContentAsString;
end;

procedure TAipexBaseClient.HandleHttpError(StatusCode: Integer; const ResponseBody: string);
var
  Json: TJSONObject;
  ErrorMsg, ErrorCode: string;
begin
  ErrorMsg := 'HTTP Error ' + IntToStr(StatusCode);
  ErrorCode := '';
  
  try
    Json := TJSONObject.ParseJSONValue(ResponseBody) as TJSONObject;
    if Assigned(Json) then
    try
      if Json.TryGetValue<string>('message', ErrorMsg) then;
      if Json.TryGetValue<string>('error_code', ErrorCode) then;
    finally
      Json.Free;
    end;
  except
    // Ignore JSON parse errors
  end;
  
  case StatusCode of
    400: raise EAipexBaseValidationError.Create(ErrorMsg, StatusCode, ErrorCode);
    401: raise EAipexBaseAuthError.Create(ErrorMsg, StatusCode, ErrorCode);
    404: raise EAipexBaseNotFoundError.Create(ErrorMsg, StatusCode, ErrorCode);
  else
    raise EAipexBaseError.Create(ErrorMsg, StatusCode, ErrorCode);
  end;
end;

function TAipexBaseClient.ParseJsonResponse(const AJson: string): TAipexApiResponse;
var
  Json: TJSONObject;
begin
  Result.Success := False;
  Result.ErrorCode := '';
  Result.ErrorMessage := '';
  Result.Data := nil;
  
  Json := TJSONObject.ParseJSONValue(AJson) as TJSONObject;
  if Assigned(Json) then
  try
    Json.TryGetValue<Boolean>('success', Result.Success);
    Json.TryGetValue<string>('error_code', Result.ErrorCode);
    Json.TryGetValue<string>('message', Result.ErrorMessage);
    Result.Data := Json.GetValue('data');
    if Assigned(Result.Data) then
      Result.Data := Result.Data.Clone as TJSONValue;
  finally
    Json.Free;
  end;
end;

// ===== Authentication =====

function TAipexBaseClient.Login(const AUsername, APassword: string; ARememberMe: Boolean): TAipexLoginResult;
var
  ReqBody: TJSONObject;
  Response: TAipexApiResponse;
  UserObj: TJSONObject;
begin
  Result.Success := False;
  Result.ErrorMessage := '';
  
  ReqBody := TJSONObject.Create;
  try
    // Backend accepts email/phone/username as login identifier
    ReqBody.AddPair('username', AUsername);
    ReqBody.AddPair('password', APassword);
    ReqBody.AddPair('remember_me', TJSONBool.Create(ARememberMe));
    
    Response := ParseJsonResponse(DoPost('/api/auth/login', ReqBody.ToString));
    Result.Success := Response.Success;
    Result.ErrorMessage := Response.ErrorMessage;
    
    if Response.Success and Assigned(Response.Data) then
    begin
      if Response.Data is TJSONObject then
      begin
        TJSONObject(Response.Data).TryGetValue<string>('access_token', Result.AccessToken);
        TJSONObject(Response.Data).TryGetValue<string>('refresh_token', Result.RefreshToken);
        TJSONObject(Response.Data).TryGetValue<Integer>('expires_in', Result.ExpiresIn);
        
        FAccessToken := Result.AccessToken;
        FRefreshToken := Result.RefreshToken;
        
        if TJSONObject(Response.Data).TryGetValue<TJSONObject>('user', UserObj) then
        begin
          UserObj.TryGetValue<Integer>('user_id', Result.User.UserId);
          UserObj.TryGetValue<string>('username', Result.User.Username);
          UserObj.TryGetValue<string>('email', Result.User.Email);
          UserObj.TryGetValue<string>('phone', Result.User.Phone);
          UserObj.TryGetValue<string>('avatar', Result.User.Avatar);
          UserObj.TryGetValue<string>('status', Result.User.Status);
          FCurrentUser := Result.User;
        end;
      end;
      Response.Data.Free;
    end;
  finally
    ReqBody.Free;
  end;
end;

function TAipexBaseClient.Register(const AUsername, AEmail, APassword, AConfirmPassword: string): TAipexLoginResult;
var
  ReqBody: TJSONObject;
  Response: TAipexApiResponse;
begin
  Result.Success := False;
  Result.ErrorMessage := '';
  
  ReqBody := TJSONObject.Create;
  try
    ReqBody.AddPair('username', AUsername);
    ReqBody.AddPair('email', AEmail);
    ReqBody.AddPair('password', APassword);
    ReqBody.AddPair('confirm_password', AConfirmPassword);
    
    Response := ParseJsonResponse(DoPost('/api/auth/register', ReqBody.ToString));
    Result.Success := Response.Success;
    Result.ErrorMessage := Response.ErrorMessage;
    
    if Response.Success and Assigned(Response.Data) then
    begin
      if Response.Data is TJSONObject then
      begin
        TJSONObject(Response.Data).TryGetValue<string>('access_token', Result.AccessToken);
        TJSONObject(Response.Data).TryGetValue<string>('refresh_token', Result.RefreshToken);
        FAccessToken := Result.AccessToken;
        FRefreshToken := Result.RefreshToken;
      end;
      Response.Data.Free;
    end;
  finally
    ReqBody.Free;
  end;
end;

function TAipexBaseClient.ForgotPassword(const AEmail: string): Boolean;
var
  ReqBody: TJSONObject;
  Response: TAipexApiResponse;
begin
  ReqBody := TJSONObject.Create;
  try
    ReqBody.AddPair('email', AEmail);
    Response := ParseJsonResponse(DoPost('/api/auth/forgot-password', ReqBody.ToString));
    Result := Response.Success;
    if Assigned(Response.Data) then
      Response.Data.Free;
  finally
    ReqBody.Free;
  end;
end;

function TAipexBaseClient.ResetPassword(const AToken, ANewPassword: string): Boolean;
var
  ReqBody: TJSONObject;
  Response: TAipexApiResponse;
begin
  ReqBody := TJSONObject.Create;
  try
    ReqBody.AddPair('token', AToken);
    ReqBody.AddPair('new_password', ANewPassword);
    Response := ParseJsonResponse(DoPost('/api/auth/reset-password', ReqBody.ToString));
    Result := Response.Success;
    if Assigned(Response.Data) then
      Response.Data.Free;
  finally
    ReqBody.Free;
  end;
end;

function TAipexBaseClient.RefreshAccessToken: Boolean;
var
  ReqBody: TJSONObject;
  Response: TAipexApiResponse;
  NewAccessToken, NewRefreshToken: string;
begin
  Result := False;
  if FRefreshToken = '' then Exit;
  
  ReqBody := TJSONObject.Create;
  try
    ReqBody.AddPair('refresh_token', FRefreshToken);
    Response := ParseJsonResponse(DoPost('/api/auth/refresh', ReqBody.ToString));
    
    if Response.Success and Assigned(Response.Data) and (Response.Data is TJSONObject) then
    begin
      TJSONObject(Response.Data).TryGetValue<string>('access_token', NewAccessToken);
      TJSONObject(Response.Data).TryGetValue<string>('refresh_token', NewRefreshToken);
      
      FAccessToken := NewAccessToken;
      if NewRefreshToken <> '' then
        FRefreshToken := NewRefreshToken;
      
      if Assigned(FOnTokenRefreshed) then
        FOnTokenRefreshed(FAccessToken, FRefreshToken);
      
      Result := True;
    end;
    
    if Assigned(Response.Data) then
      Response.Data.Free;
  finally
    ReqBody.Free;
  end;
end;

procedure TAipexBaseClient.Logout;
begin
  try
    DoPost('/api/auth/logout', '{}');
  except
    // Ignore errors on logout
  end;
  FAccessToken := '';
  FRefreshToken := '';
  FCurrentUser.Clear;
end;

function TAipexBaseClient.IsLoggedIn: Boolean;
begin
  Result := FAccessToken <> '';
end;

// ===== User Profile =====

function TAipexBaseClient.GetUserInfo: TAipexUser;
var
  Response: TAipexApiResponse;
  UserObj: TJSONObject;
begin
  Result.Clear;
  Response := ParseJsonResponse(DoGet('/api/user/profile'));
  
  if Response.Success and Assigned(Response.Data) and (Response.Data is TJSONObject) then
  begin
    UserObj := TJSONObject(Response.Data);
    UserObj.TryGetValue<Integer>('user_id', Result.UserId);
    UserObj.TryGetValue<string>('username', Result.Username);
    UserObj.TryGetValue<string>('email', Result.Email);
    UserObj.TryGetValue<string>('phone', Result.Phone);
    UserObj.TryGetValue<string>('avatar', Result.Avatar);
    UserObj.TryGetValue<string>('status', Result.Status);
    FCurrentUser := Result;
  end;
  
  if Assigned(Response.Data) then
    Response.Data.Free;
end;

function TAipexBaseClient.UpdateProfile(const AUsername, APhone: string): Boolean;
var
  ReqBody: TJSONObject;
  Response: TAipexApiResponse;
begin
  ReqBody := TJSONObject.Create;
  try
    ReqBody.AddPair('username', AUsername);
    ReqBody.AddPair('phone', APhone);
    Response := ParseJsonResponse(DoPut('/api/user/profile', ReqBody.ToString));
    Result := Response.Success;
    if Assigned(Response.Data) then
      Response.Data.Free;
  finally
    ReqBody.Free;
  end;
end;

function TAipexBaseClient.ChangePassword(const AOldPassword, ANewPassword: string): Boolean;
var
  ReqBody: TJSONObject;
  Response: TAipexApiResponse;
begin
  ReqBody := TJSONObject.Create;
  try
    ReqBody.AddPair('old_password', AOldPassword);
    ReqBody.AddPair('new_password', ANewPassword);
    Response := ParseJsonResponse(DoPost('/api/user/change-password', ReqBody.ToString));
    Result := Response.Success;
    if Assigned(Response.Data) then
      Response.Data.Free;
  finally
    ReqBody.Free;
  end;
end;

function TAipexBaseClient.UploadAvatar(AStream: TStream): string;
var
  Response: IHTTPResponse;
  FormData: TMultipartFormData;
begin
  Result := '';
  SetupHeaders;
  
  FormData := TMultipartFormData.Create;
  try
    FormData.AddStream('avatar', AStream, 'avatar.png', 'image/png');
    Response := FHttpClient.Post(FBaseURL + '/api/user/avatar', FormData);
    
    if Response.StatusCode >= 400 then
      HandleHttpError(Response.StatusCode, Response.ContentAsString);
    
    var ApiResponse := ParseJsonResponse(Response.ContentAsString);
    if ApiResponse.Success and Assigned(ApiResponse.Data) and (ApiResponse.Data is TJSONObject) then
      TJSONObject(ApiResponse.Data).TryGetValue<string>('avatar_url', Result);
    if Assigned(ApiResponse.Data) then
      ApiResponse.Data.Free;
  finally
    FormData.Free;
  end;
end;

// ===== Balance & Recharge =====

function TAipexBaseClient.GetBalance: TAipexBalance;
var
  Response: TAipexApiResponse;
  DataObj: TJSONObject;
begin
  Result.Clear;
  Response := ParseJsonResponse(DoGet('/api/billing/balance'));
  
  if Response.Success and Assigned(Response.Data) and (Response.Data is TJSONObject) then
  begin
    DataObj := TJSONObject(Response.Data);
    DataObj.TryGetValue<Currency>('balance', Result.Balance);
    DataObj.TryGetValue<string>('currency', Result.Currency);
    DataObj.TryGetValue<Currency>('frozen_amount', Result.FrozenAmount);
    DataObj.TryGetValue<Currency>('available_amount', Result.AvailableAmount);
  end;
  
  if Assigned(Response.Data) then
    Response.Data.Free;
end;

function TAipexBaseClient.GetRechargeOptions: TAipexRechargeOptions;
var
  Response: TAipexApiResponse;
  Arr: TJSONArray;
  I: Integer;
  Item: TJSONObject;
begin
  SetLength(Result, 0);
  Response := ParseJsonResponse(DoGet('/api/billing/recharge-options'));
  
  if Response.Success and Assigned(Response.Data) and (Response.Data is TJSONArray) then
  begin
    Arr := TJSONArray(Response.Data);
    SetLength(Result, Arr.Count);
    for I := 0 to Arr.Count - 1 do
    begin
      Item := Arr.Items[I] as TJSONObject;
      Item.TryGetValue<Currency>('amount', Result[I].Amount);
      Item.TryGetValue<Currency>('bonus', Result[I].Bonus);
      Item.TryGetValue<string>('description', Result[I].Description);
    end;
  end;
  
  if Assigned(Response.Data) then
    Response.Data.Free;
end;

function TAipexBaseClient.CreateRechargeOrder(AAmount: Currency; const APaymentMethod: string): string;
var
  ReqBody: TJSONObject;
  Response: TAipexApiResponse;
begin
  Result := '';
  ReqBody := TJSONObject.Create;
  try
    ReqBody.AddPair('amount', TJSONNumber.Create(AAmount));
    ReqBody.AddPair('payment_method', APaymentMethod);
    Response := ParseJsonResponse(DoPost('/api/billing/recharge', ReqBody.ToString));
    
    if Response.Success and Assigned(Response.Data) and (Response.Data is TJSONObject) then
      TJSONObject(Response.Data).TryGetValue<string>('payment_url', Result);
    
    if Assigned(Response.Data) then
      Response.Data.Free;
  finally
    ReqBody.Free;
  end;
end;

function TAipexBaseClient.GetTransactions(APage, APageSize: Integer): TAipexTransactions;
var
  Response: TAipexApiResponse;
  Arr: TJSONArray;
  I: Integer;
  Item: TJSONObject;
  DateStr: string;
begin
  SetLength(Result, 0);
  Response := ParseJsonResponse(DoGet(Format('/api/billing/transactions?page=%d&page_size=%d', [APage, APageSize])));
  
  if Response.Success and Assigned(Response.Data) and (Response.Data is TJSONObject) then
  begin
    if TJSONObject(Response.Data).TryGetValue<TJSONArray>('items', Arr) then
    begin
      SetLength(Result, Arr.Count);
      for I := 0 to Arr.Count - 1 do
      begin
        Item := Arr.Items[I] as TJSONObject;
        Item.TryGetValue<string>('transaction_id', Result[I].TransactionId);
        Item.TryGetValue<string>('type', Result[I].TransactionType);
        Item.TryGetValue<Currency>('amount', Result[I].Amount);
        Item.TryGetValue<Currency>('balance', Result[I].Balance);
        Item.TryGetValue<string>('description', Result[I].Description);
        Item.TryGetValue<string>('status', Result[I].Status);
        if Item.TryGetValue<string>('created_at', DateStr) then
          Result[I].CreatedAt := ISO8601ToDate(DateStr);
      end;
    end;
  end;
  
  if Assigned(Response.Data) then
    Response.Data.Free;
end;

// ===== Usage Statistics =====

function TAipexBaseClient.GetUsageSummary(AStartDate, AEndDate: TDateTime): TAipexUsageSummary;
var
  Response: TAipexApiResponse;
  DataObj: TJSONObject;
begin
  FillChar(Result, SizeOf(Result), 0);
  Response := ParseJsonResponse(DoGet(Format('/api/usage/summary?start=%s&end=%s',
    [FormatDateTime('yyyy-mm-dd', AStartDate), FormatDateTime('yyyy-mm-dd', AEndDate)])));
  
  if Response.Success and Assigned(Response.Data) and (Response.Data is TJSONObject) then
  begin
    DataObj := TJSONObject(Response.Data);
    DataObj.TryGetValue<Int64>('total_calls', Result.TotalCalls);
    DataObj.TryGetValue<Int64>('input_tokens', Result.InputTokens);
    DataObj.TryGetValue<Int64>('output_tokens', Result.OutputTokens);
    DataObj.TryGetValue<Currency>('total_cost', Result.TotalCost);
    Result.PeriodStart := AStartDate;
    Result.PeriodEnd := AEndDate;
  end;
  
  if Assigned(Response.Data) then
    Response.Data.Free;
end;

function TAipexBaseClient.GetUsageTrend(AStartDate, AEndDate: TDateTime; const AGroupBy: string): TAipexUsageDataPoints;
var
  Response: TAipexApiResponse;
  Arr: TJSONArray;
  I: Integer;
  Item: TJSONObject;
  DateStr: string;
begin
  SetLength(Result, 0);
  Response := ParseJsonResponse(DoGet(Format('/api/usage/trend?start=%s&end=%s&group_by=%s',
    [FormatDateTime('yyyy-mm-dd', AStartDate), FormatDateTime('yyyy-mm-dd', AEndDate), AGroupBy])));
  
  if Response.Success and Assigned(Response.Data) and (Response.Data is TJSONArray) then
  begin
    Arr := TJSONArray(Response.Data);
    SetLength(Result, Arr.Count);
    for I := 0 to Arr.Count - 1 do
    begin
      Item := Arr.Items[I] as TJSONObject;
      if Item.TryGetValue<string>('date', DateStr) then
        Result[I].Date := StrToDateDef(DateStr, 0);
      Item.TryGetValue<Int64>('calls', Result[I].Calls);
      Item.TryGetValue<Int64>('input_tokens', Result[I].InputTokens);
      Item.TryGetValue<Int64>('output_tokens', Result[I].OutputTokens);
      Item.TryGetValue<Currency>('cost', Result[I].Cost);
    end;
  end;
  
  if Assigned(Response.Data) then
    Response.Data.Free;
end;

function TAipexBaseClient.GetModelUsage(AStartDate, AEndDate: TDateTime): TAipexModelUsages;
var
  Response: TAipexApiResponse;
  Arr: TJSONArray;
  I: Integer;
  Item: TJSONObject;
begin
  SetLength(Result, 0);
  Response := ParseJsonResponse(DoGet(Format('/api/usage/models?start=%s&end=%s',
    [FormatDateTime('yyyy-mm-dd', AStartDate), FormatDateTime('yyyy-mm-dd', AEndDate)])));
  
  if Response.Success and Assigned(Response.Data) and (Response.Data is TJSONArray) then
  begin
    Arr := TJSONArray(Response.Data);
    SetLength(Result, Arr.Count);
    for I := 0 to Arr.Count - 1 do
    begin
      Item := Arr.Items[I] as TJSONObject;
      Item.TryGetValue<string>('model', Result[I].Model);
      Item.TryGetValue<Int64>('calls', Result[I].Calls);
      Item.TryGetValue<Int64>('tokens', Result[I].Tokens);
      Item.TryGetValue<Currency>('cost', Result[I].Cost);
      Item.TryGetValue<Double>('percentage', Result[I].Percentage);
    end;
  end;
  
  if Assigned(Response.Data) then
    Response.Data.Free;
end;

function TAipexBaseClient.GetRecentCalls(ALimit: Integer): TAipexApiCalls;
var
  Response: TAipexApiResponse;
  Arr: TJSONArray;
  I: Integer;
  Item: TJSONObject;
  DateStr: string;
begin
  SetLength(Result, 0);
  Response := ParseJsonResponse(DoGet(Format('/api/usage/calls?limit=%d', [ALimit])));
  
  if Response.Success and Assigned(Response.Data) and (Response.Data is TJSONArray) then
  begin
    Arr := TJSONArray(Response.Data);
    SetLength(Result, Arr.Count);
    for I := 0 to Arr.Count - 1 do
    begin
      Item := Arr.Items[I] as TJSONObject;
      Item.TryGetValue<string>('call_id', Result[I].CallId);
      Item.TryGetValue<string>('model', Result[I].Model);
      Item.TryGetValue<Integer>('input_tokens', Result[I].InputTokens);
      Item.TryGetValue<Integer>('output_tokens', Result[I].OutputTokens);
      Item.TryGetValue<Integer>('duration', Result[I].Duration);
      Item.TryGetValue<Currency>('cost', Result[I].Cost);
      Item.TryGetValue<string>('status', Result[I].Status);
      if Item.TryGetValue<string>('created_at', DateStr) then
        Result[I].CreatedAt := ISO8601ToDate(DateStr);
    end;
  end;
  
  if Assigned(Response.Data) then
    Response.Data.Free;
end;

// ===== Billing & Invoices =====

function TAipexBaseClient.GetInvoices(APage, APageSize: Integer; const AStatus: string): TAipexInvoices;
var
  Response: TAipexApiResponse;
  Arr: TJSONArray;
  I: Integer;
  Item: TJSONObject;
  DateStr: string;
  URL: string;
begin
  SetLength(Result, 0);
  URL := Format('/api/billing/invoices?page=%d&page_size=%d', [APage, APageSize]);
  if AStatus <> '' then
    URL := URL + '&status=' + TNetEncoding.URL.Encode(AStatus);
  
  Response := ParseJsonResponse(DoGet(URL));
  
  if Response.Success and Assigned(Response.Data) and (Response.Data is TJSONObject) then
  begin
    if TJSONObject(Response.Data).TryGetValue<TJSONArray>('items', Arr) then
    begin
      SetLength(Result, Arr.Count);
      for I := 0 to Arr.Count - 1 do
      begin
        Item := Arr.Items[I] as TJSONObject;
        Item.TryGetValue<string>('invoice_id', Result[I].InvoiceId);
        Item.TryGetValue<string>('invoice_no', Result[I].InvoiceNo);
        Item.TryGetValue<Currency>('amount', Result[I].Amount);
        Item.TryGetValue<string>('status', Result[I].Status);
        Item.TryGetValue<string>('invoice_url', Result[I].InvoiceUrl);
        if Item.TryGetValue<string>('period_start', DateStr) then
          Result[I].PeriodStart := ISO8601ToDate(DateStr);
        if Item.TryGetValue<string>('period_end', DateStr) then
          Result[I].PeriodEnd := ISO8601ToDate(DateStr);
        if Item.TryGetValue<string>('created_at', DateStr) then
          Result[I].CreatedAt := ISO8601ToDate(DateStr);
      end;
    end;
  end;
  
  if Assigned(Response.Data) then
    Response.Data.Free;
end;

function TAipexBaseClient.RequestInvoice(const AInvoiceId: string): Boolean;
var
  Response: TAipexApiResponse;
begin
  Response := ParseJsonResponse(DoPost('/api/billing/invoices/' + AInvoiceId + '/request', '{}'));
  Result := Response.Success;
  if Assigned(Response.Data) then
    Response.Data.Free;
end;

function TAipexBaseClient.DownloadInvoice(const AInvoiceId: string; AStream: TStream): Boolean;
var
  Response: IHTTPResponse;
begin
  Result := False;
  SetupHeaders;
  
  Response := FHttpClient.Get(FBaseURL + '/api/billing/invoices/' + AInvoiceId + '/download');
  if Response.StatusCode = 200 then
  begin
    AStream.CopyFrom(Response.ContentStream, 0);
    Result := True;
  end;
end;

end.
