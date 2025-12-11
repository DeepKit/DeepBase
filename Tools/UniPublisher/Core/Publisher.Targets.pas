{ ============================================================================
  Publisher.Targets - Publish Target Management
  
  Version: 1.0
  Description:
    Manages publish targets (HTTP, GitHub, Gitee) with configuration validation,
    execution, and result tracking.
    
    Features:
    - Configuration validation before publishing
    - Unified publish result structure
    - GitHub publishing via gh CLI
    - Gitee publishing via HTTP API
    - HTTP upload support
  ============================================================================ }

unit Publisher.Targets;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.JSON,
  System.Net.HttpClient,
  System.Diagnostics,
  Winapi.Windows,
  Winapi.ShellAPI,
  Publisher.Config;

type
  /// <summary>Status of a publish operation.</summary>
  TPublishStatus = (psNotStarted, psInProgress, psSuccess, psFailed, psSkipped);

  /// <summary>Result of a single publish operation.</summary>
  TPublishResult = record
    TargetName: string;       // 'HTTP', 'GitHub', 'Gitee'
    Status: TPublishStatus;
    ErrorMessage: string;
    OutputUrl: string;        // URL to the published release
    Duration: TTimeSpan;
    StartTime: TDateTime;
    EndTime: TDateTime;
    
    procedure Clear;
    function StatusText: string;
    function ToLogLine: string;
  end;

  /// <summary>Aggregated results from all publish targets.</summary>
  TPublishResults = record
    Http: TPublishResult;
    GitHub: TPublishResult;
    Gitee: TPublishResult;
    
    procedure Clear;
    function TotalCount: Integer;
    function SuccessCount: Integer;
    function FailedCount: Integer;
    function GetSummary: string;
  end;

  /// <summary>Validation result for a publish target.</summary>
  TValidationResult = record
    IsValid: Boolean;
    Errors: TArray<string>;
    Warnings: TArray<string>;
    
    procedure Clear;
    procedure AddError(const Msg: string);
    procedure AddWarning(const Msg: string);
    function GetSummary: string;
  end;

  /// <summary>Callback for publish progress updates.</summary>
  TPublishProgressCallback = reference to procedure(
    const TargetName: string; 
    Progress: Integer; 
    const StatusText: string
  );

  /// <summary>Validates publish configurations before execution.</summary>
  TTargetValidator = class
  public
    class function ValidateHttp(const Config: TPublishConfig): TValidationResult; static;
    class function ValidateGitHub(const Config: TPublishConfig): TValidationResult; static;
    class function ValidateGitee(const Config: TPublishConfig): TValidationResult; static;
    class function ValidateAll(const Config: TPublishConfig): TValidationResult; static;
    
    /// <summary>Check if gh CLI is available.</summary>
    class function IsGhCliAvailable: Boolean; static;
    
    /// <summary>Check if a file exists and is accessible.</summary>
    class function ValidatePackageFile(const FilePath: string): TValidationResult; static;
  end;

  /// <summary>HTTP upload publisher.</summary>
  THttpPublisher = class
  private
    FConfig: TPublishConfig;
    FOnProgress: TPublishProgressCallback;
  public
    constructor Create(AConfig: TPublishConfig);
    
    function Publish(const PackagePath, VersionJsonPath: string): TPublishResult;
    
    property OnProgress: TPublishProgressCallback read FOnProgress write FOnProgress;
  end;

  /// <summary>GitHub Release publisher using gh CLI.</summary>
  TGitHubPublisher = class
  private
    FConfig: TPublishConfig;
    FOnProgress: TPublishProgressCallback;
    
    function RunGhCommand(const Args: string; out Output: string): Boolean;
  public
    constructor Create(AConfig: TPublishConfig);
    
    function Publish(const PackagePath, Tag, ReleaseNotes: string): TPublishResult;
    function GetReleaseUrl(const Tag: string): string;
    
    property OnProgress: TPublishProgressCallback read FOnProgress write FOnProgress;
  end;

  /// <summary>Gitee Release publisher using HTTP API.</summary>
  TGiteePublisher = class
  private
    FConfig: TPublishConfig;
    FOnProgress: TPublishProgressCallback;
  public
    constructor Create(AConfig: TPublishConfig);
    
    function Publish(const PackagePath, Tag, ReleaseNotes: string): TPublishResult;
    function GetReleaseUrl(const Tag: string): string;
    
    property OnProgress: TPublishProgressCallback read FOnProgress write FOnProgress;
  end;

  /// <summary>Unified publisher that handles all targets.</summary>
  TUnifiedPublisher = class
  private
    FConfig: TPublishConfig;
    FOnProgress: TPublishProgressCallback;
    FOnLog: TProc<string>;
    FResults: TPublishResults;
    
    procedure Log(const Msg: string);
  public
    constructor Create(AConfig: TPublishConfig);
    
    /// <summary>Validate all enabled targets.</summary>
    function ValidateAll: TValidationResult;
    
    /// <summary>Publish to all enabled targets.</summary>
    function PublishAll(const PackagePath, VersionJsonPath, Tag, ReleaseNotes: string): TPublishResults;
    
    /// <summary>Publish to a specific target.</summary>
    function PublishToHttp(const PackagePath, VersionJsonPath: string): TPublishResult;
    function PublishToGitHub(const PackagePath, Tag, ReleaseNotes: string): TPublishResult;
    function PublishToGitee(const PackagePath, Tag, ReleaseNotes: string): TPublishResult;
    
    property Results: TPublishResults read FResults;
    property OnProgress: TPublishProgressCallback read FOnProgress write FOnProgress;
    property OnLog: TProc<string> read FOnLog write FOnLog;
  end;

implementation

{ TPublishResult }

procedure TPublishResult.Clear;
begin
  TargetName := '';
  Status := psNotStarted;
  ErrorMessage := '';
  OutputUrl := '';
  Duration := TTimeSpan.Zero;
  StartTime := 0;
  EndTime := 0;
end;

function TPublishResult.StatusText: string;
begin
  case Status of
    psNotStarted: Result := '未开始';
    psInProgress: Result := '进行中';
    psSuccess:    Result := '成功';
    psFailed:     Result := '失败';
    psSkipped:    Result := '跳过';
  else
    Result := '未知';
  end;
end;

function TPublishResult.ToLogLine: string;
begin
  if Status = psSuccess then
    Result := Format('[%s] %s - %s (%.2fs)', 
      [TargetName, StatusText, OutputUrl, Duration.TotalSeconds])
  else if Status = psFailed then
    Result := Format('[%s] %s - %s', [TargetName, StatusText, ErrorMessage])
  else
    Result := Format('[%s] %s', [TargetName, StatusText]);
end;

{ TPublishResults }

procedure TPublishResults.Clear;
begin
  Http.Clear;
  GitHub.Clear;
  Gitee.Clear;
end;

function TPublishResults.TotalCount: Integer;
var
  Count: Integer;
begin
  Count := 0;
  if Http.Status <> psSkipped then Inc(Count);
  if GitHub.Status <> psSkipped then Inc(Count);
  if Gitee.Status <> psSkipped then Inc(Count);
  Result := Count;
end;

function TPublishResults.SuccessCount: Integer;
var
  Count: Integer;
begin
  Count := 0;
  if Http.Status = psSuccess then Inc(Count);
  if GitHub.Status = psSuccess then Inc(Count);
  if Gitee.Status = psSuccess then Inc(Count);
  Result := Count;
end;

function TPublishResults.FailedCount: Integer;
var
  Count: Integer;
begin
  Count := 0;
  if Http.Status = psFailed then Inc(Count);
  if GitHub.Status = psFailed then Inc(Count);
  if Gitee.Status = psFailed then Inc(Count);
  Result := Count;
end;

function TPublishResults.GetSummary: string;
begin
  Result := Format('发布结果: %d/%d 成功', [SuccessCount, TotalCount]);
  if FailedCount > 0 then
    Result := Result + Format(', %d 失败', [FailedCount]);
end;

{ TValidationResult }

procedure TValidationResult.Clear;
begin
  IsValid := True;
  SetLength(Errors, 0);
  SetLength(Warnings, 0);
end;

procedure TValidationResult.AddError(const Msg: string);
begin
  IsValid := False;
  SetLength(Errors, Length(Errors) + 1);
  Errors[High(Errors)] := Msg;
end;

procedure TValidationResult.AddWarning(const Msg: string);
begin
  SetLength(Warnings, Length(Warnings) + 1);
  Warnings[High(Warnings)] := Msg;
end;

function TValidationResult.GetSummary: string;
var
  S: string;
begin
  if IsValid then
    Result := '配置验证通过'
  else
    Result := '配置验证失败';
    
  if Length(Errors) > 0 then
  begin
    Result := Result + #13#10 + '错误:';
    for S in Errors do
      Result := Result + #13#10 + '  - ' + S;
  end;
  
  if Length(Warnings) > 0 then
  begin
    Result := Result + #13#10 + '警告:';
    for S in Warnings do
      Result := Result + #13#10 + '  - ' + S;
  end;
end;

{ TTargetValidator }

class function TTargetValidator.ValidateHttp(const Config: TPublishConfig): TValidationResult;
begin
  Result.Clear;
  
  if not Config.PublishTargets.Http.Enabled then
  begin
    Result.AddWarning('HTTP 发布目标未启用');
    Exit;
  end;
  
  if Config.PublishTargets.Http.UploadUrl = '' then
    Result.AddError('HTTP 上传 URL 未配置');
    
  if Config.PublishTargets.Http.VersionJsonPath = '' then
    Result.AddWarning('HTTP version.json 路径未配置');
end;

class function TTargetValidator.ValidateGitHub(const Config: TPublishConfig): TValidationResult;
begin
  Result.Clear;
  
  if not Config.PublishTargets.GitHub.Enabled then
  begin
    Result.AddWarning('GitHub 发布目标未启用');
    Exit;
  end;
  
  if Config.PublishTargets.GitHub.Owner = '' then
    Result.AddError('GitHub Owner 未配置');
    
  if Config.PublishTargets.GitHub.Repo = '' then
    Result.AddError('GitHub Repo 未配置');
    
  if Config.PublishTargets.GitHub.UseGhCli and not IsGhCliAvailable then
    Result.AddError('gh CLI 未安装或不可用 (运行 winget install GitHub.cli 安装)');
end;

class function TTargetValidator.ValidateGitee(const Config: TPublishConfig): TValidationResult;
begin
  Result.Clear;
  
  if not Config.PublishTargets.Gitee.Enabled then
  begin
    Result.AddWarning('Gitee 发布目标未启用');
    Exit;
  end;
  
  if Config.PublishTargets.Gitee.Owner = '' then
    Result.AddError('Gitee Owner 未配置');
    
  if Config.PublishTargets.Gitee.Repo = '' then
    Result.AddError('Gitee Repo 未配置');
    
  if Config.PublishTargets.Gitee.ApiToken = '' then
    Result.AddError('Gitee Access Token 未配置');
end;

class function TTargetValidator.ValidateAll(const Config: TPublishConfig): TValidationResult;
var
  HttpResult, GitHubResult, GiteeResult: TValidationResult;
  S: string;
begin
  Result.Clear;
  
  // Basic config validation
  if Config.AppId = '' then
    Result.AddError('appId 未配置');
  if Config.AppName = '' then
    Result.AddError('appName 未配置');
  if Config.OutputDir = '' then
    Result.AddError('outputDir 未配置');
    
  // Target-specific validation
  HttpResult := ValidateHttp(Config);
  GitHubResult := ValidateGitHub(Config);
  GiteeResult := ValidateGitee(Config);
  
  // Merge errors
  for S in HttpResult.Errors do
    Result.AddError('[HTTP] ' + S);
  for S in GitHubResult.Errors do
    Result.AddError('[GitHub] ' + S);
  for S in GiteeResult.Errors do
    Result.AddError('[Gitee] ' + S);
    
  // Merge warnings
  for S in HttpResult.Warnings do
    Result.AddWarning('[HTTP] ' + S);
  for S in GitHubResult.Warnings do
    Result.AddWarning('[GitHub] ' + S);
  for S in GiteeResult.Warnings do
    Result.AddWarning('[Gitee] ' + S);
    
  // Check if at least one target is enabled
  if not (Config.PublishTargets.Http.Enabled or 
          Config.PublishTargets.GitHub.Enabled or 
          Config.PublishTargets.Gitee.Enabled) then
    Result.AddError('至少需要启用一个发布目标');
end;

class function TTargetValidator.IsGhCliAvailable: Boolean;
var
  StartInfo: TStartupInfo;
  ProcInfo: TProcessInformation;
  CmdLine: string;
begin
  Result := False;
  
  CmdLine := 'cmd /c gh --version';
  
  FillChar(StartInfo, SizeOf(StartInfo), 0);
  StartInfo.cb := SizeOf(StartInfo);
  StartInfo.dwFlags := STARTF_USESHOWWINDOW;
  StartInfo.wShowWindow := SW_HIDE;
  
  FillChar(ProcInfo, SizeOf(ProcInfo), 0);
  
  if CreateProcess(nil, PChar(CmdLine), nil, nil, False, 
    CREATE_NO_WINDOW, nil, nil, StartInfo, ProcInfo) then
  begin
    WaitForSingleObject(ProcInfo.hProcess, 5000);
    Result := True;
    CloseHandle(ProcInfo.hProcess);
    CloseHandle(ProcInfo.hThread);
  end;
end;

class function TTargetValidator.ValidatePackageFile(const FilePath: string): TValidationResult;
begin
  Result.Clear;
  
  if FilePath = '' then
  begin
    Result.AddError('包文件路径为空');
    Exit;
  end;
  
  if not TFile.Exists(FilePath) then
  begin
    Result.AddError('包文件不存在: ' + FilePath);
    Exit;
  end;
  
  if TFile.GetSize(FilePath) = 0 then
    Result.AddError('包文件大小为 0');
end;

{ THttpPublisher }

constructor THttpPublisher.Create(AConfig: TPublishConfig);
begin
  inherited Create;
  FConfig := AConfig;
end;

function THttpPublisher.Publish(const PackagePath, VersionJsonPath: string): TPublishResult;
var
  SW: TStopwatch;
  Client: THTTPClient;
  Response: IHTTPResponse;
  FormData: TMultipartFormData;
begin
  Result.Clear;
  Result.TargetName := 'HTTP';
  Result.Status := psInProgress;
  Result.StartTime := Now;
  SW := TStopwatch.StartNew;
  
  if Assigned(FOnProgress) then
    FOnProgress('HTTP', 0, '准备上传...');
  
  try
    if not FConfig.PublishTargets.Http.Enabled then
    begin
      Result.Status := psSkipped;
      Exit;
    end;
    
    if not TFile.Exists(PackagePath) then
    begin
      Result.Status := psFailed;
      Result.ErrorMessage := '包文件不存在: ' + PackagePath;
      Exit;
    end;
    
    Client := THTTPClient.Create;
    try
      if Assigned(FOnProgress) then
        FOnProgress('HTTP', 30, '上传文件...');
      
      // Create multipart form data
      FormData := TMultipartFormData.Create;
      try
        FormData.AddFile('file', PackagePath);
        
        Response := Client.Post(FConfig.PublishTargets.Http.UploadUrl, FormData);
        
        if (Response.StatusCode >= 200) and (Response.StatusCode < 300) then
        begin
          Result.Status := psSuccess;
          Result.OutputUrl := FConfig.PublishTargets.Http.VersionJsonPath;
          
          if Assigned(FOnProgress) then
            FOnProgress('HTTP', 100, '上传完成');
        end
        else
        begin
          Result.Status := psFailed;
          Result.ErrorMessage := Format('HTTP 上传失败: %d %s', 
            [Response.StatusCode, Response.StatusText]);
        end;
      finally
        FormData.Free;
      end;
    finally
      Client.Free;
    end;
  except
    on E: Exception do
    begin
      Result.Status := psFailed;
      Result.ErrorMessage := 'HTTP 上传异常: ' + E.Message;
    end;
  end;
  
  SW.Stop;
  Result.Duration := SW.Elapsed;
  Result.EndTime := Now;
end;

{ TGitHubPublisher }

constructor TGitHubPublisher.Create(AConfig: TPublishConfig);
begin
  inherited Create;
  FConfig := AConfig;
end;

function TGitHubPublisher.RunGhCommand(const Args: string; out Output: string): Boolean;
var
  StartInfo: TStartupInfo;
  ProcInfo: TProcessInformation;
  CmdLine: string;
  SecurityAttr: TSecurityAttributes;
  ReadPipe, WritePipe: THandle;
  Buffer: array[0..4095] of AnsiChar;
  BytesRead: DWORD;
  ExitCode: DWORD;
begin
  Result := False;
  Output := '';
  
  // Create pipe for reading output
  FillChar(SecurityAttr, SizeOf(SecurityAttr), 0);
  SecurityAttr.nLength := SizeOf(SecurityAttr);
  SecurityAttr.bInheritHandle := True;
  
  if not CreatePipe(ReadPipe, WritePipe, @SecurityAttr, 0) then
    Exit;
  
  try
    CmdLine := 'cmd /c gh ' + Args;
    
    FillChar(StartInfo, SizeOf(StartInfo), 0);
    StartInfo.cb := SizeOf(StartInfo);
    StartInfo.dwFlags := STARTF_USESHOWWINDOW or STARTF_USESTDHANDLES;
    StartInfo.wShowWindow := SW_HIDE;
    StartInfo.hStdOutput := WritePipe;
    StartInfo.hStdError := WritePipe;
    
    FillChar(ProcInfo, SizeOf(ProcInfo), 0);
    
    if CreateProcess(nil, PChar(CmdLine), nil, nil, True, 
      CREATE_NO_WINDOW, nil, nil, StartInfo, ProcInfo) then
    begin
      CloseHandle(WritePipe);
      WritePipe := 0;
      
      // Read output
      while ReadFile(ReadPipe, Buffer, SizeOf(Buffer) - 1, BytesRead, nil) and (BytesRead > 0) do
      begin
        Buffer[BytesRead] := #0;
        Output := Output + string(Buffer);
      end;
      
      WaitForSingleObject(ProcInfo.hProcess, 60000);  // 60s timeout
      GetExitCodeProcess(ProcInfo.hProcess, ExitCode);
      Result := (ExitCode = 0);
      
      CloseHandle(ProcInfo.hProcess);
      CloseHandle(ProcInfo.hThread);
    end;
  finally
    if WritePipe <> 0 then
      CloseHandle(WritePipe);
    CloseHandle(ReadPipe);
  end;
end;

function TGitHubPublisher.Publish(const PackagePath, Tag, ReleaseNotes: string): TPublishResult;
var
  SW: TStopwatch;
  Args, Output, NotesFile: string;
  RepoSlug: string;
begin
  Result.Clear;
  Result.TargetName := 'GitHub';
  Result.Status := psInProgress;
  Result.StartTime := Now;
  SW := TStopwatch.StartNew;
  
  if Assigned(FOnProgress) then
    FOnProgress('GitHub', 0, '准备发布...');
  
  try
    if not FConfig.PublishTargets.GitHub.Enabled then
    begin
      Result.Status := psSkipped;
      Exit;
    end;
    
    if not TFile.Exists(PackagePath) then
    begin
      Result.Status := psFailed;
      Result.ErrorMessage := '包文件不存在: ' + PackagePath;
      Exit;
    end;
    
    RepoSlug := FConfig.PublishTargets.GitHub.GetRepoSlug;
    
    // Write release notes to temp file
    NotesFile := TPath.Combine(TPath.GetTempPath, 
      Format('gh_notes_%s_%s.txt', [FConfig.AppName, Tag]));
    TFile.WriteAllText(NotesFile, ReleaseNotes, TEncoding.UTF8);
    
    try
      if Assigned(FOnProgress) then
        FOnProgress('GitHub', 30, '创建 Release...');
      
      // gh release create <tag> <file> --repo <owner/repo> --notes-file <file>
      Args := Format('release create %s "%s" --repo %s --notes-file "%s" --title "%s"',
        [Tag, PackagePath, RepoSlug, NotesFile, Tag]);
      
      if RunGhCommand(Args, Output) then
      begin
        Result.Status := psSuccess;
        Result.OutputUrl := GetReleaseUrl(Tag);
        
        if Assigned(FOnProgress) then
          FOnProgress('GitHub', 100, 'Release 创建成功');
      end
      else
      begin
        Result.Status := psFailed;
        Result.ErrorMessage := 'gh CLI 执行失败: ' + Trim(Output);
      end;
    finally
      if TFile.Exists(NotesFile) then
        TFile.Delete(NotesFile);
    end;
  except
    on E: Exception do
    begin
      Result.Status := psFailed;
      Result.ErrorMessage := 'GitHub 发布异常: ' + E.Message;
    end;
  end;
  
  SW.Stop;
  Result.Duration := SW.Elapsed;
  Result.EndTime := Now;
end;

function TGitHubPublisher.GetReleaseUrl(const Tag: string): string;
begin
  Result := Format('https://github.com/%s/releases/tag/%s',
    [FConfig.PublishTargets.GitHub.GetRepoSlug, Tag]);
end;

{ TGiteePublisher }

constructor TGiteePublisher.Create(AConfig: TPublishConfig);
begin
  inherited Create;
  FConfig := AConfig;
end;

function TGiteePublisher.Publish(const PackagePath, Tag, ReleaseNotes: string): TPublishResult;
var
  SW: TStopwatch;
  Client: THTTPClient;
  Response: IHTTPResponse;
  Url: string;
  Body: TStringStream;
  Json: TJSONObject;
begin
  Result.Clear;
  Result.TargetName := 'Gitee';
  Result.Status := psInProgress;
  Result.StartTime := Now;
  SW := TStopwatch.StartNew;
  
  if Assigned(FOnProgress) then
    FOnProgress('Gitee', 0, '准备发布...');
  
  try
    if not FConfig.PublishTargets.Gitee.Enabled then
    begin
      Result.Status := psSkipped;
      Exit;
    end;
    
    if FConfig.PublishTargets.Gitee.ApiToken = '' then
    begin
      Result.Status := psFailed;
      Result.ErrorMessage := 'Gitee Access Token 未配置';
      Exit;
    end;
    
    if Assigned(FOnProgress) then
      FOnProgress('Gitee', 30, '创建 Release...');
    
    // Create release via Gitee API
    Json := TJSONObject.Create;
    try
      Json.AddPair('access_token', FConfig.PublishTargets.Gitee.ApiToken);
      Json.AddPair('tag_name', Tag);
      Json.AddPair('name', Tag);
      Json.AddPair('body', ReleaseNotes);
      
      Url := Format('https://gitee.com/api/v5/repos/%s/releases',
        [FConfig.PublishTargets.Gitee.GetRepoSlug]);
      
      Body := TStringStream.Create(Json.ToJSON, TEncoding.UTF8);
      try
        Client := THTTPClient.Create;
        try
          Client.ContentType := 'application/json';
          Response := Client.Post(Url, Body);
          
          if (Response.StatusCode >= 200) and (Response.StatusCode < 300) then
          begin
            Result.Status := psSuccess;
            Result.OutputUrl := GetReleaseUrl(Tag);
            
            if Assigned(FOnProgress) then
              FOnProgress('Gitee', 100, 'Release 创建成功');
          end
          else
          begin
            Result.Status := psFailed;
            Result.ErrorMessage := Format('Gitee API 调用失败: %d %s',
              [Response.StatusCode, Response.StatusText]);
          end;
        finally
          Client.Free;
        end;
      finally
        Body.Free;
      end;
    finally
      Json.Free;
    end;
  except
    on E: Exception do
    begin
      Result.Status := psFailed;
      Result.ErrorMessage := 'Gitee 发布异常: ' + E.Message;
    end;
  end;
  
  SW.Stop;
  Result.Duration := SW.Elapsed;
  Result.EndTime := Now;
end;

function TGiteePublisher.GetReleaseUrl(const Tag: string): string;
begin
  Result := Format('https://gitee.com/%s/releases/tag/%s',
    [FConfig.PublishTargets.Gitee.GetRepoSlug, Tag]);
end;

{ TUnifiedPublisher }

constructor TUnifiedPublisher.Create(AConfig: TPublishConfig);
begin
  inherited Create;
  FConfig := AConfig;
  FResults.Clear;
end;

procedure TUnifiedPublisher.Log(const Msg: string);
begin
  if Assigned(FOnLog) then
    FOnLog(Msg);
end;

function TUnifiedPublisher.ValidateAll: TValidationResult;
begin
  Result := TTargetValidator.ValidateAll(FConfig);
end;

function TUnifiedPublisher.PublishAll(const PackagePath, VersionJsonPath, Tag, 
  ReleaseNotes: string): TPublishResults;
begin
  FResults.Clear;
  
  Log('========== 开始发布 ==========');
  Log('包文件: ' + PackagePath);
  Log('版本: ' + Tag);
  Log('');
  
  // Publish to enabled targets
  if FConfig.PublishTargets.Http.Enabled then
  begin
    Log('[HTTP] 开始上传...');
    FResults.Http := PublishToHttp(PackagePath, VersionJsonPath);
    Log(FResults.Http.ToLogLine);
    Log('');
  end
  else
    FResults.Http.Status := psSkipped;
  
  if FConfig.PublishTargets.GitHub.Enabled then
  begin
    Log('[GitHub] 开始发布...');
    FResults.GitHub := PublishToGitHub(PackagePath, Tag, ReleaseNotes);
    Log(FResults.GitHub.ToLogLine);
    Log('');
  end
  else
    FResults.GitHub.Status := psSkipped;
  
  if FConfig.PublishTargets.Gitee.Enabled then
  begin
    Log('[Gitee] 开始发布...');
    FResults.Gitee := PublishToGitee(PackagePath, Tag, ReleaseNotes);
    Log(FResults.Gitee.ToLogLine);
    Log('');
  end
  else
    FResults.Gitee.Status := psSkipped;
  
  Log('========== 发布完成 ==========');
  Log(FResults.GetSummary);
  
  Result := FResults;
end;

function TUnifiedPublisher.PublishToHttp(const PackagePath, 
  VersionJsonPath: string): TPublishResult;
var
  Publisher: THttpPublisher;
begin
  Publisher := THttpPublisher.Create(FConfig);
  try
    Publisher.OnProgress := FOnProgress;
    Result := Publisher.Publish(PackagePath, VersionJsonPath);
  finally
    Publisher.Free;
  end;
end;

function TUnifiedPublisher.PublishToGitHub(const PackagePath, Tag, 
  ReleaseNotes: string): TPublishResult;
var
  Publisher: TGitHubPublisher;
begin
  Publisher := TGitHubPublisher.Create(FConfig);
  try
    Publisher.OnProgress := FOnProgress;
    Result := Publisher.Publish(PackagePath, Tag, ReleaseNotes);
  finally
    Publisher.Free;
  end;
end;

function TUnifiedPublisher.PublishToGitee(const PackagePath, Tag, 
  ReleaseNotes: string): TPublishResult;
var
  Publisher: TGiteePublisher;
begin
  Publisher := TGiteePublisher.Create(FConfig);
  try
    Publisher.OnProgress := FOnProgress;
    Result := Publisher.Publish(PackagePath, Tag, ReleaseNotes);
  finally
    Publisher.Free;
  end;
end;

end.
