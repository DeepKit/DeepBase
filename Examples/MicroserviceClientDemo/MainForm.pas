{ ============================================================================
  MicroserviceClientDemo - Main Form
  
  Demonstrates the usage of TMicroserviceClient with:
  - REST API calls (GET/POST/PUT/DELETE)
  - Retry with exponential backoff
  - Circuit breaker pattern
  - Service discovery
  - Request/Response logging
  ============================================================================ }

unit MainForm;

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls,
  UniBase.Microservice.Client;

type
  // Sample DTOs for demonstration
  TUserDto = record
    Id: Integer;
    Name: string;
    Email: string;
    IsActive: Boolean;
  end;

  TCreateUserRequest = record
    Name: string;
    Email: string;
    Password: string;
  end;

  TPostDto = record
    Id: Integer;
    UserId: Integer;
    Title: string;
    Body: string;
  end;

  TMainForm = class(TForm)
    pnlTop: TPanel;
    lblBaseUrl: TLabel;
    edtBaseUrl: TEdit;
    btnConnect: TButton;
    lblToken: TLabel;
    edtToken: TEdit;
    PageControl1: TPageControl;
    tsBasicOps: TTabSheet;
    tsCircuitBreaker: TTabSheet;
    tsServiceDiscovery: TTabSheet;
    pnlBasicOps: TPanel;
    btnGetUser: TButton;
    btnGetUsers: TButton;
    btnCreateUser: TButton;
    btnUpdateUser: TButton;
    btnDeleteUser: TButton;
    edtUserId: TEdit;
    lblUserId: TLabel;
    pnlCircuitBreaker: TPanel;
    lblCBStatus: TLabel;
    btnCBTest: TButton;
    btnCBReset: TButton;
    lblCBState: TLabel;
    pnlServiceDiscovery: TPanel;
    btnRegisterService: TButton;
    btnGetEndpoint: TButton;
    edtServiceName: TEdit;
    edtServiceUrl: TEdit;
    lblServiceName: TLabel;
    lblServiceUrl: TLabel;
    memoLog: TMemo;
    StatusBar1: TStatusBar;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnConnectClick(Sender: TObject);
    procedure btnGetUserClick(Sender: TObject);
    procedure btnGetUsersClick(Sender: TObject);
    procedure btnCreateUserClick(Sender: TObject);
    procedure btnUpdateUserClick(Sender: TObject);
    procedure btnDeleteUserClick(Sender: TObject);
    procedure btnCBTestClick(Sender: TObject);
    procedure btnCBResetClick(Sender: TObject);
    procedure btnRegisterServiceClick(Sender: TObject);
    procedure btnGetEndpointClick(Sender: TObject);
  private
    FClient: TMicroserviceClient;
    FServiceDiscovery: TServiceDiscovery;
    
    procedure Log(const Msg: string);
    procedure LogFormat(const Fmt: string; const Args: array of const);
    procedure UpdateCircuitBreakerStatus;
    procedure OnRequestLog(Sender: TObject; const Method, Url: string;
      const Headers: TStrings; const Body: string);
    procedure OnResponseLog(Sender: TObject; StatusCode: Integer;
      const Body: string; ResponseTimeMs: Integer);
  public
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

procedure TMainForm.FormCreate(Sender: TObject);
begin
  FClient := nil;
  FServiceDiscovery := TServiceDiscovery.Create;
  
  // Default values for JSONPlaceholder (free fake API)
  edtBaseUrl.Text := 'https://jsonplaceholder.typicode.com';
  edtUserId.Text := '1';
  edtServiceName.Text := 'user-service';
  edtServiceUrl.Text := 'http://localhost:8080';
  
  Log('MicroserviceClient Demo initialized');
  Log('Using JSONPlaceholder API for testing');
  Log('');
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FClient.Free;
  FServiceDiscovery.Free;
end;

procedure TMainForm.Log(const Msg: string);
begin
  memoLog.Lines.Add(FormatDateTime('hh:nn:ss.zzz', Now) + ' | ' + Msg);
end;

procedure TMainForm.LogFormat(const Fmt: string; const Args: array of const);
begin
  Log(Format(Fmt, Args));
end;

procedure TMainForm.btnConnectClick(Sender: TObject);
begin
  FClient.Free;
  FClient := TMicroserviceClient.Create(edtBaseUrl.Text);
  FClient.OnRequestLog := OnRequestLog;
  FClient.OnResponseLog := OnResponseLog;
  
  if edtToken.Text <> '' then
    FClient.SetBearerToken(edtToken.Text);
  
  LogFormat('Connected to: %s', [edtBaseUrl.Text]);
  StatusBar1.Panels[0].Text := 'Connected: ' + edtBaseUrl.Text;
  
  UpdateCircuitBreakerStatus;
end;

procedure TMainForm.OnRequestLog(Sender: TObject; const Method, Url: string;
  const Headers: TStrings; const Body: string);
begin
  LogFormat('>> %s %s', [Method, Url]);
  if Body <> '' then
    LogFormat('   Body: %s', [Copy(Body, 1, 200)]);
end;

procedure TMainForm.OnResponseLog(Sender: TObject; StatusCode: Integer;
  const Body: string; ResponseTimeMs: Integer);
begin
  LogFormat('<< Status: %d (%dms)', [StatusCode, ResponseTimeMs]);
end;

procedure TMainForm.UpdateCircuitBreakerStatus;
var
  StateStr: string;
begin
  if FClient = nil then
  begin
    lblCBState.Caption := 'Not connected';
    Exit;
  end;
  
  case FClient.CircuitBreaker.State of
    csClose: StateStr := 'CLOSED (Normal)';
    csOpen: StateStr := 'OPEN (Blocking)';
    csHalfOpen: StateStr := 'HALF-OPEN (Testing)';
  end;
  
  lblCBState.Caption := Format('State: %s | Failures: %d',
    [StateStr, FClient.CircuitBreaker.FailureCount]);
end;

// ============================================================================
// Basic Operations
// ============================================================================

procedure TMainForm.btnGetUserClick(Sender: TObject);
var
  Response: TApiResponse<TUserDto>;
  UserId: Integer;
begin
  if FClient = nil then
  begin
    ShowMessage('Please connect first');
    Exit;
  end;
  
  UserId := StrToIntDef(edtUserId.Text, 1);
  Log('');
  LogFormat('Getting user #%d...', [UserId]);
  
  Response := FClient.Get<TUserDto>('/users/' + IntToStr(UserId));
  
  if Response.Success then
  begin
    Log('User retrieved successfully:');
    LogFormat('  ID: %d', [Response.Data.Id]);
    LogFormat('  Name: %s', [Response.Data.Name]);
    LogFormat('  Email: %s', [Response.Data.Email]);
  end
  else
    LogFormat('Error: %s (Status: %d)', [Response.ErrorMessage, Response.StatusCode]);
  
  UpdateCircuitBreakerStatus;
end;

procedure TMainForm.btnGetUsersClick(Sender: TObject);
var
  Response: TApiResponse<string>;
begin
  if FClient = nil then
  begin
    ShowMessage('Please connect first');
    Exit;
  end;
  
  Log('');
  Log('Getting all users (raw)...');
  
  Response := FClient.GetRaw('/users', TRequestOptions.Default);
  
  if Response.Success then
  begin
    Log('Users retrieved:');
    Log(Copy(Response.Data, 1, 500) + '...');
    LogFormat('Response time: %dms', [Response.ResponseTime]);
  end
  else
    LogFormat('Error: %s', [Response.ErrorMessage]);
  
  UpdateCircuitBreakerStatus;
end;

procedure TMainForm.btnCreateUserClick(Sender: TObject);
var
  Request: TCreateUserRequest;
  Response: TApiResponse<TUserDto>;
begin
  if FClient = nil then
  begin
    ShowMessage('Please connect first');
    Exit;
  end;
  
  Log('');
  Log('Creating new user...');
  
  Request.Name := 'John Doe';
  Request.Email := 'john.doe@example.com';
  Request.Password := 'secret123';
  
  Response := FClient.Post<TCreateUserRequest, TUserDto>('/users', Request);
  
  if Response.Success then
  begin
    Log('User created successfully:');
    LogFormat('  Assigned ID: %d', [Response.Data.Id]);
    LogFormat('  Name: %s', [Response.Data.Name]);
  end
  else
    LogFormat('Error: %s (Status: %d)', [Response.ErrorMessage, Response.StatusCode]);
  
  UpdateCircuitBreakerStatus;
end;

procedure TMainForm.btnUpdateUserClick(Sender: TObject);
var
  Request: TUserDto;
  Response: TApiResponse<TUserDto>;
  UserId: Integer;
begin
  if FClient = nil then
  begin
    ShowMessage('Please connect first');
    Exit;
  end;
  
  UserId := StrToIntDef(edtUserId.Text, 1);
  Log('');
  LogFormat('Updating user #%d...', [UserId]);
  
  Request.Id := UserId;
  Request.Name := 'Jane Doe (Updated)';
  Request.Email := 'jane.updated@example.com';
  Request.IsActive := True;
  
  Response := FClient.Put<TUserDto, TUserDto>('/users/' + IntToStr(UserId), Request);
  
  if Response.Success then
  begin
    Log('User updated successfully:');
    LogFormat('  Name: %s', [Response.Data.Name]);
    LogFormat('  Email: %s', [Response.Data.Email]);
  end
  else
    LogFormat('Error: %s (Status: %d)', [Response.ErrorMessage, Response.StatusCode]);
  
  UpdateCircuitBreakerStatus;
end;

procedure TMainForm.btnDeleteUserClick(Sender: TObject);
var
  Response: TApiResponse<Boolean>;
  UserId: Integer;
begin
  if FClient = nil then
  begin
    ShowMessage('Please connect first');
    Exit;
  end;
  
  UserId := StrToIntDef(edtUserId.Text, 1);
  Log('');
  LogFormat('Deleting user #%d...', [UserId]);
  
  Response := FClient.Delete('/users/' + IntToStr(UserId));
  
  if Response.Success then
    Log('User deleted successfully')
  else
    LogFormat('Error: %s (Status: %d)', [Response.ErrorMessage, Response.StatusCode]);
  
  UpdateCircuitBreakerStatus;
end;

// ============================================================================
// Circuit Breaker
// ============================================================================

procedure TMainForm.btnCBTestClick(Sender: TObject);
var
  Response: TApiResponse<string>;
  I: Integer;
begin
  if FClient = nil then
  begin
    ShowMessage('Please connect first');
    Exit;
  end;
  
  Log('');
  Log('Testing circuit breaker with invalid endpoint...');
  Log('Making 6 requests to trigger circuit breaker (threshold: 5)');
  
  for I := 1 to 6 do
  begin
    LogFormat('Request #%d...', [I]);
    
    try
      Response := FClient.GetRaw('/invalid-endpoint-404', TRequestOptions.Default);
      LogFormat('  Status: %d', [Response.StatusCode]);
    except
      on E: Exception do
        LogFormat('  Exception: %s', [E.Message]);
    end;
    
    UpdateCircuitBreakerStatus;
    Application.ProcessMessages;
    Sleep(100);
  end;
  
  Log('');
  Log('Circuit breaker test completed');
  Log('Try making another request - it should be blocked if circuit is open');
end;

procedure TMainForm.btnCBResetClick(Sender: TObject);
begin
  if FClient = nil then
  begin
    ShowMessage('Please connect first');
    Exit;
  end;
  
  FClient.CircuitBreaker.Reset;
  Log('');
  Log('Circuit breaker reset');
  UpdateCircuitBreakerStatus;
end;

// ============================================================================
// Service Discovery
// ============================================================================

procedure TMainForm.btnRegisterServiceClick(Sender: TObject);
begin
  FServiceDiscovery.RegisterService(
    edtServiceName.Text,
    edtServiceUrl.Text,
    1  // weight
  );
  
  Log('');
  LogFormat('Registered service: %s -> %s', [edtServiceName.Text, edtServiceUrl.Text]);
  
  // Register a few more for demonstration
  FServiceDiscovery.RegisterService(edtServiceName.Text, 'http://localhost:8081');
  FServiceDiscovery.RegisterService(edtServiceName.Text, 'http://localhost:8082');
  Log('Also registered: localhost:8081, localhost:8082');
end;

procedure TMainForm.btnGetEndpointClick(Sender: TObject);
var
  Endpoint: string;
  I: Integer;
begin
  Log('');
  LogFormat('Getting endpoints for service: %s', [edtServiceName.Text]);
  Log('Round-robin selection (5 calls):');
  
  for I := 1 to 5 do
  begin
    Endpoint := FServiceDiscovery.GetEndpoint(edtServiceName.Text);
    if Endpoint <> '' then
      LogFormat('  #%d: %s', [I, Endpoint])
    else
      Log('  No endpoints registered');
  end;
end;

end.
