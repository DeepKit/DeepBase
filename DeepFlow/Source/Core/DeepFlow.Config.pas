unit DeepFlow.Config;

{*******************************************************************************
  DeepFlow.Config - 配置管理
  
  描述：
    读取和管理 DeepFlow 运行时配置。
    支持 JSON 配置文件和环境变量覆盖。
    
  作者：鲁班（开发者）
  日期：2025-12-04
  版本：1.0
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.IOUtils,
  System.Generics.Collections;

type
  /// <summary>日志级别</summary>
  TLogLevel = (llDebug, llInfo, llWarn, llError, llFatal);

  /// <summary>DeepFlow 配置</summary>
  TDeepFlowConfig = class
  private
    FConfigPath: string;
    FRawJSON: TJSONObject;
    
    // 基础配置
    FUseMockAI: Boolean;
    FSkillServiceUrl: string;
    FSkillServicePort: Integer;
    FMockLLMUrl: string;
    FLogLevel: TLogLevel;
    FLogPath: string;
    
    // 数据库配置
    FDatabasePath: string;
    
    // 性能配置
    FMessageQueueSize: Integer;
    FMessageTimeout: Integer;
    FMaxRetries: Integer;
    FRetryDelay: Integer;
    
    // 安全配置
    FEnableGuard: Boolean;
    FMaxInputLength: Integer;
    FBlockedPatterns: TList<string>;
    
    procedure LoadFromFile(const APath: string);
    procedure ApplyDefaults;
    function ParseLogLevel(const ALevel: string): TLogLevel;
  public
    constructor Create; overload;
    constructor Create(const AConfigPath: string); overload;
    destructor Destroy; override;
    
    /// <summary>重新加载配置</summary>
    procedure Reload;
    
    /// <summary>获取配置值（带默认值）</summary>
    function GetString(const APath: string; const ADefault: string = ''): string;
    function GetInteger(const APath: string; const ADefault: Integer = 0): Integer;
    function GetBoolean(const APath: string; const ADefault: Boolean = False): Boolean;
    function GetFloat(const APath: string; const ADefault: Double = 0): Double;
    
    // 基础配置
    property UseMockAI: Boolean read FUseMockAI write FUseMockAI;
    property SkillServiceUrl: string read FSkillServiceUrl write FSkillServiceUrl;
    property SkillServicePort: Integer read FSkillServicePort write FSkillServicePort;
    property MockLLMUrl: string read FMockLLMUrl write FMockLLMUrl;
    property LogLevel: TLogLevel read FLogLevel write FLogLevel;
    property LogPath: string read FLogPath write FLogPath;
    
    // 数据库配置
    property DatabasePath: string read FDatabasePath write FDatabasePath;
    
    // 性能配置
    property MessageQueueSize: Integer read FMessageQueueSize write FMessageQueueSize;
    property MessageTimeout: Integer read FMessageTimeout write FMessageTimeout;
    property MaxRetries: Integer read FMaxRetries write FMaxRetries;
    property RetryDelay: Integer read FRetryDelay write FRetryDelay;
    
    // 安全配置
    property EnableGuard: Boolean read FEnableGuard write FEnableGuard;
    property MaxInputLength: Integer read FMaxInputLength write FMaxInputLength;
    property BlockedPatterns: TList<string> read FBlockedPatterns;
    
    // 原始 JSON
    property RawJSON: TJSONObject read FRawJSON;
  end;

/// <summary>全局配置实例</summary>
function GlobalConfig: TDeepFlowConfig;

implementation

var
  _GlobalConfig: TDeepFlowConfig = nil;

function GlobalConfig: TDeepFlowConfig;
begin
  if _GlobalConfig = nil then
    _GlobalConfig := TDeepFlowConfig.Create;
  Result := _GlobalConfig;
end;

{ TDeepFlowConfig }

constructor TDeepFlowConfig.Create;
begin
  Create('Config\DeepFlow.config.json');
end;

constructor TDeepFlowConfig.Create(const AConfigPath: string);
begin
  inherited Create;
  FBlockedPatterns := TList<string>.Create;
  FConfigPath := AConfigPath;
  ApplyDefaults;
  
  if TFile.Exists(AConfigPath) then
    LoadFromFile(AConfigPath);
end;

destructor TDeepFlowConfig.Destroy;
begin
  FBlockedPatterns.Free;
  FRawJSON.Free;
  inherited;
end;

procedure TDeepFlowConfig.ApplyDefaults;
begin
  // 基础配置
  FUseMockAI := True;
  FSkillServiceUrl := 'http://127.0.0.1';
  FSkillServicePort := 8000;
  FMockLLMUrl := 'http://127.0.0.1:8766';
  FLogLevel := llDebug;
  FLogPath := 'Logs';
  
  // 数据库配置
  FDatabasePath := 'Data\DeepFlow.db';
  
  // 性能配置
  FMessageQueueSize := 1000;
  FMessageTimeout := 30000;  // 30秒
  FMaxRetries := 3;
  FRetryDelay := 1000;  // 1秒
  
  // 安全配置
  FEnableGuard := True;
  FMaxInputLength := 10000;
  
  // 默认阻止模式
  FBlockedPatterns.Clear;
  FBlockedPatterns.Add('ignore.*previous.*instructions');
  FBlockedPatterns.Add('system.*prompt');
  FBlockedPatterns.Add('jailbreak');
end;

procedure TDeepFlowConfig.LoadFromFile(const APath: string);
var
  JSONContent: string;
  JSONValue: TJSONValue;
  BlockedArray: TJSONArray;
  I: Integer;
begin
  JSONContent := TFile.ReadAllText(APath, TEncoding.UTF8);
  JSONValue := TJSONObject.ParseJSONValue(JSONContent);
  
  if not (JSONValue is TJSONObject) then
  begin
    JSONValue.Free;
    Exit;
  end;
  
  FRawJSON.Free;
  FRawJSON := JSONValue as TJSONObject;
  
  // 解析配置
  if FRawJSON.TryGetValue<Boolean>('UseMockAI', FUseMockAI) then;
  if FRawJSON.TryGetValue<string>('SkillServiceUrl', FSkillServiceUrl) then;
  if FRawJSON.TryGetValue<Integer>('SkillServicePort', FSkillServicePort) then;
  if FRawJSON.TryGetValue<string>('MockLLMUrl', FMockLLMUrl) then;
  if FRawJSON.TryGetValue<string>('LogPath', FLogPath) then;
  if FRawJSON.TryGetValue<string>('DatabasePath', FDatabasePath) then;
  
  // 解析日志级别
  var LogLevelStr: string;
  if FRawJSON.TryGetValue<string>('LogLevel', LogLevelStr) then
    FLogLevel := ParseLogLevel(LogLevelStr);
  
  // 解析性能配置
  if FRawJSON.TryGetValue<Integer>('MessageQueueSize', FMessageQueueSize) then;
  if FRawJSON.TryGetValue<Integer>('MessageTimeout', FMessageTimeout) then;
  if FRawJSON.TryGetValue<Integer>('MaxRetries', FMaxRetries) then;
  if FRawJSON.TryGetValue<Integer>('RetryDelay', FRetryDelay) then;
  
  // 解析安全配置
  if FRawJSON.TryGetValue<Boolean>('EnableGuard', FEnableGuard) then;
  if FRawJSON.TryGetValue<Integer>('MaxInputLength', FMaxInputLength) then;
  
  // 解析阻止模式
  if FRawJSON.TryGetValue<TJSONArray>('BlockedPatterns', BlockedArray) then
  begin
    FBlockedPatterns.Clear;
    for I := 0 to BlockedArray.Count - 1 do
      FBlockedPatterns.Add(BlockedArray.Items[I].Value);
  end;
end;

procedure TDeepFlowConfig.Reload;
begin
  ApplyDefaults;
  if TFile.Exists(FConfigPath) then
    LoadFromFile(FConfigPath);
end;

function TDeepFlowConfig.ParseLogLevel(const ALevel: string): TLogLevel;
begin
  if SameText(ALevel, 'DEBUG') then
    Result := llDebug
  else if SameText(ALevel, 'INFO') then
    Result := llInfo
  else if SameText(ALevel, 'WARN') or SameText(ALevel, 'WARNING') then
    Result := llWarn
  else if SameText(ALevel, 'ERROR') then
    Result := llError
  else if SameText(ALevel, 'FATAL') then
    Result := llFatal
  else
    Result := llInfo;
end;

function TDeepFlowConfig.GetString(const APath: string; const ADefault: string): string;
begin
  if (FRawJSON <> nil) and FRawJSON.TryGetValue<string>(APath, Result) then
    Exit;
  Result := ADefault;
end;

function TDeepFlowConfig.GetInteger(const APath: string; const ADefault: Integer): Integer;
begin
  if (FRawJSON <> nil) and FRawJSON.TryGetValue<Integer>(APath, Result) then
    Exit;
  Result := ADefault;
end;

function TDeepFlowConfig.GetBoolean(const APath: string; const ADefault: Boolean): Boolean;
begin
  if (FRawJSON <> nil) and FRawJSON.TryGetValue<Boolean>(APath, Result) then
    Exit;
  Result := ADefault;
end;

function TDeepFlowConfig.GetFloat(const APath: string; const ADefault: Double): Double;
begin
  if (FRawJSON <> nil) and FRawJSON.TryGetValue<Double>(APath, Result) then
    Exit;
  Result := ADefault;
end;

initialization

finalization
  FreeAndNil(_GlobalConfig);

end.
