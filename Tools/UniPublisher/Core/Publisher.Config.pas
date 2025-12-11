{ ============================================================================
  Publisher.Config - UniPublisher Configuration Model
  
  Version: 1.0
  Description:
    Defines the configuration model for UniPublisher, supporting the standard
    `.publish.json` format as specified in docs/tools/UniPublisher-Spec.md.
    
    Each application maintains a `{AppName}.publish.json` file containing:
    - Application identity (appId, appName, displayName)
    - Build paths (dproj, outputDir)
    - Package layout rules (include/exclude patterns)
    - Publish targets (HTTP, GitHub, Gitee)
    - Metadata (website, support email, etc.)
  ============================================================================ }

unit Publisher.Config;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.JSON,
  System.Generics.Collections;

type
  /// <summary>Package layout configuration for file inclusion/exclusion.</summary>
  TPackageLayout = record
    IncludePatterns: TArray<string>;  // e.g. ['*.exe', '*.dll', 'assets/**']
    ExcludePatterns: TArray<string>;  // e.g. ['*.dcu', '*.map', '*.log']
    
    procedure Clear;
    function ToJSON: TJSONObject;
    procedure FromJSON(AObj: TJSONObject);
  end;

  /// <summary>HTTP upload target configuration.</summary>
  THttpTarget = record
    Enabled: Boolean;
    UploadUrl: string;        // URL for uploading files
    VersionJsonPath: string;  // URL where version.json will be accessible
    
    procedure Clear;
    function ToJSON: TJSONObject;
    procedure FromJSON(AObj: TJSONObject);
  end;

  /// <summary>GitHub Release target configuration.</summary>
  TGitHubTarget = record
    Enabled: Boolean;
    Owner: string;            // Repository owner
    Repo: string;             // Repository name
    UseGhCli: Boolean;        // Use gh CLI for publishing
    
    procedure Clear;
    function ToJSON: TJSONObject;
    procedure FromJSON(AObj: TJSONObject);
    function GetRepoSlug: string;  // Returns 'owner/repo'
  end;

  /// <summary>Gitee Release target configuration.</summary>
  TGiteeTarget = record
    Enabled: Boolean;
    Owner: string;
    Repo: string;
    ApiToken: string;         // Personal access token
    
    procedure Clear;
    function ToJSON: TJSONObject;
    procedure FromJSON(AObj: TJSONObject);
    function GetRepoSlug: string;
  end;

  /// <summary>All publish targets combined.</summary>
  TPublishTargets = record
    Http: THttpTarget;
    GitHub: TGitHubTarget;
    Gitee: TGiteeTarget;
    
    procedure Clear;
    function ToJSON: TJSONObject;
    procedure FromJSON(AObj: TJSONObject);
  end;

  /// <summary>Application metadata.</summary>
  TPublishMetadata = record
    Website: string;
    SupportEmail: string;
    Category: string;
    Author: string;
    
    procedure Clear;
    function ToJSON: TJSONObject;
    procedure FromJSON(AObj: TJSONObject);
  end;

  /// <summary>
  /// Main configuration model for UniPublisher.
  /// Maps to the .publish.json file format.
  /// </summary>
  TPublishConfig = class
  private
    FAppId: string;
    FAppName: string;
    FDisplayName: string;
    FDproj: string;
    FOutputDir: string;
    FPackageLayout: TPackageLayout;
    FPublishTargets: TPublishTargets;
    FMetadata: TPublishMetadata;
    FConfigPath: string;  // Path where config was loaded from
    
    procedure SetDefaults;
  public
    constructor Create;
    destructor Destroy; override;
    
    /// <summary>Load configuration from a JSON file.</summary>
    function LoadFromFile(const APath: string): Boolean;
    
    /// <summary>Save configuration to a JSON file.</summary>
    function SaveToFile(const APath: string): Boolean;
    
    /// <summary>Save to the same file it was loaded from.</summary>
    function Save: Boolean;
    
    /// <summary>Convert to JSON string (formatted).</summary>
    function ToJSONString(AIndent: Integer = 2): string;
    
    /// <summary>Load from JSON string.</summary>
    function FromJSONString(const AJson: string): Boolean;
    
    /// <summary>Clear all fields to defaults.</summary>
    procedure Clear;
    
    /// <summary>Validate configuration for required fields.</summary>
    function Validate(out ErrorMsg: string): Boolean;
    
    /// <summary>Generate default package name based on appName and version.</summary>
    function GetDefaultPackageName(const AVersion: string): string;
    
    // Properties
    property AppId: string read FAppId write FAppId;
    property AppName: string read FAppName write FAppName;
    property DisplayName: string read FDisplayName write FDisplayName;
    property Dproj: string read FDproj write FDproj;
    property OutputDir: string read FOutputDir write FOutputDir;
    property PackageLayout: TPackageLayout read FPackageLayout write FPackageLayout;
    property PublishTargets: TPublishTargets read FPublishTargets write FPublishTargets;
    property Metadata: TPublishMetadata read FMetadata write FMetadata;
    property ConfigPath: string read FConfigPath;
  end;

  /// <summary>
  /// Simple MRU (Most Recently Used) manager for publish configs.
  /// Stores recent .publish.json paths in a local JSON file.
  /// </summary>
  TPublishConfigMRU = class
  private
    FItems: TList<string>;
    FMaxItems: Integer;
    FStoragePath: string;
    
    procedure LoadFromStorage;
    procedure SaveToStorage;
  public
    constructor Create(const AStoragePath: string; AMaxItems: Integer = 10);
    destructor Destroy; override;
    
    /// <summary>Add a config path to MRU (moves to top if exists).</summary>
    procedure Add(const APath: string);
    
    /// <summary>Remove a config path from MRU.</summary>
    procedure Remove(const APath: string);
    
    /// <summary>Get all MRU items.</summary>
    function GetItems: TArray<string>;
    
    /// <summary>Get the most recent item, or empty if none.</summary>
    function GetMostRecent: string;
    
    /// <summary>Clear all items.</summary>
    procedure Clear;
    
    property MaxItems: Integer read FMaxItems write FMaxItems;
  end;

implementation

{ TPackageLayout }

procedure TPackageLayout.Clear;
begin
  SetLength(IncludePatterns, 0);
  SetLength(ExcludePatterns, 0);
end;

function TPackageLayout.ToJSON: TJSONObject;
var
  IncArr, ExcArr: TJSONArray;
  S: string;
begin
  Result := TJSONObject.Create;
  
  IncArr := TJSONArray.Create;
  for S in IncludePatterns do
    IncArr.Add(S);
  Result.AddPair('includePatterns', IncArr);
  
  ExcArr := TJSONArray.Create;
  for S in ExcludePatterns do
    ExcArr.Add(S);
  Result.AddPair('excludePatterns', ExcArr);
end;

procedure TPackageLayout.FromJSON(AObj: TJSONObject);
var
  Arr: TJSONArray;
  I: Integer;
begin
  Clear;
  if AObj = nil then Exit;
  
  Arr := AObj.GetValue<TJSONArray>('includePatterns', nil);
  if Arr <> nil then
  begin
    SetLength(IncludePatterns, Arr.Count);
    for I := 0 to Arr.Count - 1 do
      IncludePatterns[I] := Arr.Items[I].Value;
  end;
  
  Arr := AObj.GetValue<TJSONArray>('excludePatterns', nil);
  if Arr <> nil then
  begin
    SetLength(ExcludePatterns, Arr.Count);
    for I := 0 to Arr.Count - 1 do
      ExcludePatterns[I] := Arr.Items[I].Value;
  end;
end;

{ THttpTarget }

procedure THttpTarget.Clear;
begin
  Enabled := False;
  UploadUrl := '';
  VersionJsonPath := '';
end;

function THttpTarget.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('enabled', TJSONBool.Create(Enabled));
  Result.AddPair('uploadUrl', UploadUrl);
  Result.AddPair('versionJsonPath', VersionJsonPath);
end;

procedure THttpTarget.FromJSON(AObj: TJSONObject);
begin
  Clear;
  if AObj = nil then Exit;
  
  Enabled := AObj.GetValue<Boolean>('enabled', False);
  UploadUrl := AObj.GetValue<string>('uploadUrl', '');
  VersionJsonPath := AObj.GetValue<string>('versionJsonPath', '');
end;

{ TGitHubTarget }

procedure TGitHubTarget.Clear;
begin
  Enabled := False;
  Owner := '';
  Repo := '';
  UseGhCli := True;
end;

function TGitHubTarget.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('enabled', TJSONBool.Create(Enabled));
  Result.AddPair('owner', Owner);
  Result.AddPair('repo', Repo);
  Result.AddPair('useGhCli', TJSONBool.Create(UseGhCli));
end;

procedure TGitHubTarget.FromJSON(AObj: TJSONObject);
begin
  Clear;
  if AObj = nil then Exit;
  
  Enabled := AObj.GetValue<Boolean>('enabled', False);
  Owner := AObj.GetValue<string>('owner', '');
  Repo := AObj.GetValue<string>('repo', '');
  UseGhCli := AObj.GetValue<Boolean>('useGhCli', True);
end;

function TGitHubTarget.GetRepoSlug: string;
begin
  Result := Owner + '/' + Repo;
end;

{ TGiteeTarget }

procedure TGiteeTarget.Clear;
begin
  Enabled := False;
  Owner := '';
  Repo := '';
  ApiToken := '';
end;

function TGiteeTarget.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('enabled', TJSONBool.Create(Enabled));
  Result.AddPair('owner', Owner);
  Result.AddPair('repo', Repo);
  // Note: ApiToken is intentionally NOT saved to JSON for security
  // It should be stored separately or entered at runtime
  Result.AddPair('apiToken', '');
end;

procedure TGiteeTarget.FromJSON(AObj: TJSONObject);
begin
  Clear;
  if AObj = nil then Exit;
  
  Enabled := AObj.GetValue<Boolean>('enabled', False);
  Owner := AObj.GetValue<string>('owner', '');
  Repo := AObj.GetValue<string>('repo', '');
  ApiToken := AObj.GetValue<string>('apiToken', '');
end;

function TGiteeTarget.GetRepoSlug: string;
begin
  Result := Owner + '/' + Repo;
end;

{ TPublishTargets }

procedure TPublishTargets.Clear;
begin
  Http.Clear;
  GitHub.Clear;
  Gitee.Clear;
end;

function TPublishTargets.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('http', Http.ToJSON);
  Result.AddPair('github', GitHub.ToJSON);
  Result.AddPair('gitee', Gitee.ToJSON);
end;

procedure TPublishTargets.FromJSON(AObj: TJSONObject);
begin
  Clear;
  if AObj = nil then Exit;
  
  Http.FromJSON(AObj.GetValue<TJSONObject>('http', nil));
  GitHub.FromJSON(AObj.GetValue<TJSONObject>('github', nil));
  Gitee.FromJSON(AObj.GetValue<TJSONObject>('gitee', nil));
end;

{ TPublishMetadata }

procedure TPublishMetadata.Clear;
begin
  Website := '';
  SupportEmail := '';
  Category := '';
  Author := '';
end;

function TPublishMetadata.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('website', Website);
  Result.AddPair('supportEmail', SupportEmail);
  Result.AddPair('category', Category);
  Result.AddPair('author', Author);
end;

procedure TPublishMetadata.FromJSON(AObj: TJSONObject);
begin
  Clear;
  if AObj = nil then Exit;
  
  Website := AObj.GetValue<string>('website', '');
  SupportEmail := AObj.GetValue<string>('supportEmail', '');
  Category := AObj.GetValue<string>('category', '');
  Author := AObj.GetValue<string>('author', '');
end;

{ TPublishConfig }

constructor TPublishConfig.Create;
begin
  inherited Create;
  SetDefaults;
end;

destructor TPublishConfig.Destroy;
begin
  inherited;
end;

procedure TPublishConfig.SetDefaults;
begin
  FAppId := '';
  FAppName := '';
  FDisplayName := '';
  FDproj := '';
  FOutputDir := '';
  FConfigPath := '';
  
  // Default package layout
  SetLength(FPackageLayout.IncludePatterns, 4);
  FPackageLayout.IncludePatterns[0] := '*.exe';
  FPackageLayout.IncludePatterns[1] := '*.dll';
  FPackageLayout.IncludePatterns[2] := 'config.db';
  FPackageLayout.IncludePatterns[3] := 'README.md';
  
  SetLength(FPackageLayout.ExcludePatterns, 3);
  FPackageLayout.ExcludePatterns[0] := '*.dcu';
  FPackageLayout.ExcludePatterns[1] := '*.map';
  FPackageLayout.ExcludePatterns[2] := '*.log';
  
  FPublishTargets.Clear;
  FMetadata.Clear;
end;

procedure TPublishConfig.Clear;
begin
  SetDefaults;
end;

function TPublishConfig.LoadFromFile(const APath: string): Boolean;
var
  Content: string;
begin
  Result := False;
  if not TFile.Exists(APath) then
    Exit;
    
  try
    Content := TFile.ReadAllText(APath, TEncoding.UTF8);
    if FromJSONString(Content) then
    begin
      FConfigPath := APath;
      Result := True;
    end;
  except
    Result := False;
  end;
end;

function TPublishConfig.SaveToFile(const APath: string): Boolean;
var
  Content: string;
begin
  Result := False;
  try
    Content := ToJSONString;
    ForceDirectories(ExtractFilePath(APath));
    TFile.WriteAllText(APath, Content, TEncoding.UTF8);
    FConfigPath := APath;
    Result := True;
  except
    Result := False;
  end;
end;

function TPublishConfig.Save: Boolean;
begin
  if FConfigPath = '' then
    Result := False
  else
    Result := SaveToFile(FConfigPath);
end;

function TPublishConfig.ToJSONString(AIndent: Integer): string;
var
  Root: TJSONObject;
begin
  Root := TJSONObject.Create;
  try
    Root.AddPair('appId', FAppId);
    Root.AddPair('appName', FAppName);
    Root.AddPair('displayName', FDisplayName);
    Root.AddPair('dproj', FDproj);
    Root.AddPair('outputDir', FOutputDir);
    Root.AddPair('packageLayout', FPackageLayout.ToJSON);
    Root.AddPair('publishTargets', FPublishTargets.ToJSON);
    Root.AddPair('metadata', FMetadata.ToJSON);
    
    Result := Root.Format(AIndent);
  finally
    Root.Free;
  end;
end;

function TPublishConfig.FromJSONString(const AJson: string): Boolean;
var
  Root: TJSONObject;
begin
  Result := False;
  Root := TJSONObject.ParseJSONValue(AJson) as TJSONObject;
  if Root = nil then
    Exit;
    
  try
    FAppId := Root.GetValue<string>('appId', '');
    FAppName := Root.GetValue<string>('appName', '');
    FDisplayName := Root.GetValue<string>('displayName', '');
    FDproj := Root.GetValue<string>('dproj', '');
    FOutputDir := Root.GetValue<string>('outputDir', '');
    
    FPackageLayout.FromJSON(Root.GetValue<TJSONObject>('packageLayout', nil));
    FPublishTargets.FromJSON(Root.GetValue<TJSONObject>('publishTargets', nil));
    FMetadata.FromJSON(Root.GetValue<TJSONObject>('metadata', nil));
    
    Result := True;
  finally
    Root.Free;
  end;
end;

function TPublishConfig.Validate(out ErrorMsg: string): Boolean;
begin
  Result := False;
  
  if FAppId = '' then
  begin
    ErrorMsg := 'appId is required';
    Exit;
  end;
  
  if FAppName = '' then
  begin
    ErrorMsg := 'appName is required';
    Exit;
  end;
  
  if FDproj = '' then
  begin
    ErrorMsg := 'dproj path is required';
    Exit;
  end;
  
  if not TFile.Exists(FDproj) then
  begin
    ErrorMsg := 'dproj file does not exist: ' + FDproj;
    Exit;
  end;
  
  if FOutputDir = '' then
  begin
    ErrorMsg := 'outputDir is required';
    Exit;
  end;
  
  // At least one publish target should be enabled
  if not (FPublishTargets.Http.Enabled or 
          FPublishTargets.GitHub.Enabled or 
          FPublishTargets.Gitee.Enabled) then
  begin
    ErrorMsg := 'At least one publish target must be enabled';
    Exit;
  end;
  
  ErrorMsg := '';
  Result := True;
end;

function TPublishConfig.GetDefaultPackageName(const AVersion: string): string;
begin
  // Format: AppName-Version-Win32.zip
  Result := Format('%s-%s-Win32.zip', [FAppName, AVersion]);
end;

{ TPublishConfigMRU }

constructor TPublishConfigMRU.Create(const AStoragePath: string; AMaxItems: Integer);
begin
  inherited Create;
  FItems := TList<string>.Create;
  FMaxItems := AMaxItems;
  FStoragePath := AStoragePath;
  LoadFromStorage;
end;

destructor TPublishConfigMRU.Destroy;
begin
  FItems.Free;
  inherited;
end;

procedure TPublishConfigMRU.LoadFromStorage;
var
  Content: string;
  Arr: TJSONArray;
  I: Integer;
begin
  FItems.Clear;
  
  if not TFile.Exists(FStoragePath) then
    Exit;
    
  try
    Content := TFile.ReadAllText(FStoragePath, TEncoding.UTF8);
    Arr := TJSONObject.ParseJSONValue(Content) as TJSONArray;
    if Arr = nil then
      Exit;
      
    try
      for I := 0 to Arr.Count - 1 do
      begin
        if FItems.Count >= FMaxItems then
          Break;
        FItems.Add(Arr.Items[I].Value);
      end;
    finally
      Arr.Free;
    end;
  except
    // Ignore load errors
  end;
end;

procedure TPublishConfigMRU.SaveToStorage;
var
  Arr: TJSONArray;
  S: string;
begin
  Arr := TJSONArray.Create;
  try
    for S in FItems do
      Arr.Add(S);
      
    ForceDirectories(ExtractFilePath(FStoragePath));
    TFile.WriteAllText(FStoragePath, Arr.Format(2), TEncoding.UTF8);
  finally
    Arr.Free;
  end;
end;

procedure TPublishConfigMRU.Add(const APath: string);
var
  Idx: Integer;
begin
  // Remove if exists
  Idx := FItems.IndexOf(APath);
  if Idx >= 0 then
    FItems.Delete(Idx);
    
  // Insert at front
  FItems.Insert(0, APath);
  
  // Trim to max
  while FItems.Count > FMaxItems do
    FItems.Delete(FItems.Count - 1);
    
  SaveToStorage;
end;

procedure TPublishConfigMRU.Remove(const APath: string);
var
  Idx: Integer;
begin
  Idx := FItems.IndexOf(APath);
  if Idx >= 0 then
  begin
    FItems.Delete(Idx);
    SaveToStorage;
  end;
end;

function TPublishConfigMRU.GetItems: TArray<string>;
begin
  Result := FItems.ToArray;
end;

function TPublishConfigMRU.GetMostRecent: string;
begin
  if FItems.Count > 0 then
    Result := FItems[0]
  else
    Result := '';
end;

procedure TPublishConfigMRU.Clear;
begin
  FItems.Clear;
  SaveToStorage;
end;

end.
