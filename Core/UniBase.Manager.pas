{ ============================================================================
  UniBase.Manager - Core Manager
  
  Version: 0.3
  Description: Core manager of UniBase framework providing unified
               initialization and resource management.
  Thread Safety: Initialize/Finalize methods should only be called from
                 the main thread.
  ============================================================================ }

unit UniBase.Manager;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.SyncObjs,
  System.Math,
  System.Generics.Collections,
  FireDAC.Comp.Client,
  FireDAC.Stan.Def,
  FireDAC.Stan.Async,
  FireDAC.DApt,
  FireDAC.Stan.ExprFuncs,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  UniBase.Types,
  UniBase.Consts,
  UniBase.Config,
  UniBase.i18n,
  UniBase.Theme,
  UniBase.Logging,
  UniBase.Security,
  UniBase.Plugin,
  UniBase.PluginManager;

const
  UNIBASE_VERSION = '0.3';
  DEFAULT_CONFIGDB_NAME = 'config.db';
  ROOT_TXT_NAME = 'root.txt';
  
  /// <summary>
  /// Schema version compatibility error code
  /// </summary>
  ecSchemaVersionMismatch = TInitErrorCode(10);

type
  TUniBaseManager = class;

  /// <summary>
  /// UniBase 配置模块接口（前向声明）
  /// </summary>
  IUniBaseConfig = interface
    ['{A1B2C3D4-E5F6-4A5B-8C9D-0E1F2A3B4C5D}']
    function GetConfig(const Key: string; const Default: string = ''): string;
    procedure SetConfig(const Key, Value: string; const Category: string = 'General');
  end;

  /// <summary>
  /// UniBase 国际化模块接口（前向声明）
  /// </summary>
  IUniBaseI18n = interface
    ['{B2C3D4E5-F6A7-5B6C-9D0E-1F2A3B4C5D6E}']
    function Translate(const Text: string): string;
    function GetCurrentLanguage: string;
    procedure SetCurrentLanguage(const Value: string);
  end;

  /// <summary>
  /// UniBase 核心管理器
  /// </summary>
  TUniBaseManager = class(TComponent)
  private
    // 核心状态
    FRootPath: string;
    FConfigDBPath: string;
    FConfigDB: TFDConnection;
    FIsInitialized: Boolean;
    FLastError: string;
    FInitErrorCode: TInitErrorCode;
    
    // 当前设置
    FCurrentLanguage: string;
    FCurrentTheme: string;
    
    // 线程同步
    FLock: TObject;
    
    // 事件
    FOnLanguageChanged: TNotifyEvent;
    FOnThemeChanged: TNotifyEvent;
    FOnConfigChanged: TConfigChangedEvent;
    
    // 核心模块
    FConfig: TUniBaseConfig;
    FI18n: TUniBaseI18n;
    FTheme: TUniBaseTheme;
    FLogger: TUniBaseLogger;
    FSecurity: TUniBaseSecurity;
    FPluginManager: TUniBasePluginManager;
    
    // 内部方法
    procedure InitializeModules;
    procedure FinalizeModules;
    function ReadRootTxt(const FilePath: string): string;
    function WriteRootTxt(const FilePath, RootPath: string): Boolean;
    function CreateRootTxt(out FilePath: string): Boolean;
    function ConnectToDatabase(const DBPath: string): Boolean;
    function ValidateSchema: Boolean;
    function ValidateSchemaVersion: Boolean;
    function CreateSchema: Boolean;
    function GetSchemaVersionInternal: string;
    function MigrateSchemaInternal(const FromVersion, ToVersion: string): Boolean;
    function RunMigrationScript(const ScriptPath: string): Boolean;
    function GetExeDir: string;
    function GetAppDataDir: string;
    function CheckWritePermission(const Path: string): Boolean;
    function FindRootPath: string;
    function CreatePluginContext: IUniBasePluginContext;
    
    // 事件处理器 (用于子模块回调)
    procedure HandleConfigChanged(Sender: TObject; const Key, OldValue, NewValue: string);
    procedure HandleLanguageChanged(Sender: TObject);
    procedure HandleThemeChanged(Sender: TObject);
    
    // 属性 Setter
    procedure SetCurrentLanguage(const Value: string);
    procedure SetCurrentTheme(const Value: string);
    
  protected
    procedure DoLanguageChanged;
    procedure DoThemeChanged;
    procedure DoConfigChanged(const Key, OldValue, NewValue: string);
    
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    // ========================================
    // 初始化方法
    // ========================================
    
    /// <summary>
    /// 初始化 UniBase（主线程调用）
    /// </summary>
    function Initialize: Boolean;
    
    /// <summary>
    /// 初始化 UniBase，返回详细错误信息
    /// </summary>
    function InitializeEx(out ErrorMsg: string): Boolean;
    
    /// <summary>
    /// 使用指定数据库路径初始化（支持 :memory: 用于测试）
    /// </summary>
    function InitializeWithDB(const DBPath: string): Boolean;
    
    /// <summary>Clean up resources</summary>
    procedure Finalize;
    
    // ========================================
    // Schema Migration
    // ========================================
    
    /// <summary>Get current database schema version</summary>
    function GetCurrentSchemaVersion: string;
    
    /// <summary>
    /// Check and migrate schema to target version.
    /// Looks for scripts: {RootPath}/sql/upgrade_vX_to_vY.sql
    /// </summary>
    function CheckAndMigrateSchema(const TargetVersion: string = ''): Boolean;
    
    // ========================================
    // Health Check
    // ========================================
    
    /// <summary>
    /// 执行健康检查
    /// </summary>
    function HealthCheck: THealthCheckResult;
    
    // ========================================
    // 项目信息
    // ========================================
    
    /// <summary>
    /// 获取项目信息
    /// </summary>
    function GetProjectInfo(const Key: string): string;
    
    /// <summary>
    /// 设置项目信息
    /// </summary>
    procedure SetProjectInfo(const Key, Value: string);
    
    // ========================================
    // 资源路径
    // ========================================
    
    /// <summary>
    /// 获取资源完整路径
    /// </summary>
    function GetAssetPath(const RelativePath: string): string;
    
    // ========================================
    // 属性
    // ========================================
    
    /// <summary>数据库连接（供子模块使用）</summary>
    property ConfigDB: TFDConnection read FConfigDB;
    
    // 子模块访问点
    property Config: TUniBaseConfig read FConfig;
    property I18n: TUniBaseI18n read FI18n;
    property Theme: TUniBaseTheme read FTheme;
    property Logger: TUniBaseLogger read FLogger;
    property Security: TUniBaseSecurity read FSecurity;
    property PluginManager: TUniBasePluginManager read FPluginManager;
    
    /// <summary>项目根目录</summary>
    property RootPath: string read FRootPath;
    
    /// <summary>配置数据库路径</summary>
    property ConfigDBPath: string read FConfigDBPath;
    
    /// <summary>是否已初始化</summary>
    property IsInitialized: Boolean read FIsInitialized;
    
    /// <summary>最后一次错误信息</summary>
    property LastError: string read FLastError;
    
    /// <summary>初始化错误码</summary>
    property InitErrorCode: TInitErrorCode read FInitErrorCode;
    
    /// <summary>当前语言</summary>
    property CurrentLanguage: string read FCurrentLanguage write SetCurrentLanguage;
    
    /// <summary>当前主题</summary>
    property CurrentTheme: string read FCurrentTheme write SetCurrentTheme;
    
    /// <summary>同步锁对象（供子模块使用）</summary>
    property Lock: TObject read FLock;
    
    // ========================================
    // 事件
    // ========================================
    
    property OnLanguageChanged: TNotifyEvent read FOnLanguageChanged write FOnLanguageChanged;
    property OnThemeChanged: TNotifyEvent read FOnThemeChanged write FOnThemeChanged;
    property OnConfigChanged: TConfigChangedEvent read FOnConfigChanged write FOnConfigChanged;
  end;

/// <summary>
/// Get global UniBase singleton
/// </summary>
function UniBase: TUniBaseManager;

/// <summary>
/// Set the global UniBase instance (for testing/dependency injection only)
/// Passing nil will reset to default lazy-initialization behavior.
/// IMPORTANT: Must be called before any UniBase() call, or after explicit cleanup.
/// </summary>
procedure SetUniBaseInstance(AInstance: TUniBaseManager);

implementation

uses
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  Winapi.ShlObj,
  {$ENDIF}
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Error,
  FireDAC.UI.Intf,
  FireDAC.Phys.Intf,
  FireDAC.Comp.ScriptCommands,
  FireDAC.Stan.Util,
  FireDAC.Comp.Script,
  UniBase.Schema;

var
  GUniBaseManager: TUniBaseManager = nil;
  GUniBaseLock: TObject = nil;

function UniBase: TUniBaseManager;
begin
  if GUniBaseManager = nil then
  begin
    TMonitor.Enter(GUniBaseLock);
    try
      if GUniBaseManager = nil then
        GUniBaseManager := TUniBaseManager.Create(nil);
    finally
      TMonitor.Exit(GUniBaseLock);
    end;
  end;
  Result := GUniBaseManager;
end;

procedure SetUniBaseInstance(AInstance: TUniBaseManager);
begin
  TMonitor.Enter(GUniBaseLock);
  try
    // Free existing instance if it was auto-created (not externally owned)
    if (GUniBaseManager <> nil) and (GUniBaseManager <> AInstance) then
    begin
      // Only free if no owner (auto-created by UniBase function)
      if GUniBaseManager.Owner = nil then
        FreeAndNil(GUniBaseManager);
    end;
    GUniBaseManager := AInstance;
  finally
    TMonitor.Exit(GUniBaseLock);
  end;
end;

{ TUniBaseManager }

constructor TUniBaseManager.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FLock := TObject.Create;
  FIsInitialized := False;
  FInitErrorCode := ecUnknown;
  FLastError := '';
  FCurrentLanguage := 'en-US';
  FCurrentTheme := 'Windows11';
end;

destructor TUniBaseManager.Destroy;
begin
  Finalize;
  FLock.Free;
  inherited;
end;

function TUniBaseManager.Initialize: Boolean;
var
  Dummy: string;
begin
  Result := InitializeEx(Dummy);
end;

function TUniBaseManager.InitializeEx(out ErrorMsg: string): Boolean;
var
  RootTxtPath: string;
begin
  Result := False;
  ErrorMsg := '';
  
  if FIsInitialized then
  begin
    Result := True;
    Exit;
  end;
  
  try
    // 1. 查找 root.txt
    FRootPath := FindRootPath;
    
    if FRootPath = '' then
    begin
      // 尝试创建 root.txt
      if not CreateRootTxt(RootTxtPath) then
      begin
        FInitErrorCode := ecPermissionDenied;
        FLastError := 'Cannot create root.txt';
        ErrorMsg := Format('[%d] %s: %s', [Ord(FInitErrorCode), 
          InitErrorCodeToStr(FInitErrorCode), FLastError]);
        Exit;
      end;
      FRootPath := ExtractFilePath(RootTxtPath);
    end;
    
    // 2. 验证根目录
    if not TDirectory.Exists(FRootPath) then
    begin
      FInitErrorCode := ecInvalidPath;
      FLastError := 'Root path does not exist: ' + FRootPath;
      ErrorMsg := Format('[%d] %s: %s', [Ord(FInitErrorCode),
        InitErrorCodeToStr(FInitErrorCode), FLastError]);
      Exit;
    end;
    
    // 3. 确定 config.db 路径
    FConfigDBPath := TPath.Combine(FRootPath, DEFAULT_CONFIGDB_NAME);
    
    // 4. 连接数据库
    if not ConnectToDatabase(FConfigDBPath) then
    begin
      ErrorMsg := Format('[%d] %s: %s', [Ord(FInitErrorCode),
        InitErrorCodeToStr(FInitErrorCode), FLastError]);
      Exit;
    end;
    
    // 5. 验证/创建 Schema
    // 始终调用 CreateSchema 以确保所有表存在（使用 IF NOT EXISTS）
    if not CreateSchema then
    begin
      ErrorMsg := Format('[%d] %s: %s', [Ord(FInitErrorCode),
        InitErrorCodeToStr(FInitErrorCode), FLastError]);
      Exit;
    end;
    
    // Ensure Tier 1 Tables exist (Temporary fix until migration system)
    // In future versions, we will check SchemaVersion and run upgrade scripts
    // For now, we just try to create them if missing
    // Note: We need a better way to handle this, but for now let's assume 
    // ValidateSchema only checks core tables.
    // We can run additional SQL scripts here if needed.
    
    // 6. 初始化子模块
    InitializeModules;
    
    FIsInitialized := True;
    FInitErrorCode := ecSuccess;
    Result := True;
    
  except
    on E: Exception do
    begin
      FInitErrorCode := ecUnknown;
      FLastError := E.Message;
      ErrorMsg := Format('[%d] %s: %s', [Ord(FInitErrorCode),
        InitErrorCodeToStr(FInitErrorCode), FLastError]);
    end;
  end;
end;

function TUniBaseManager.InitializeWithDB(const DBPath: string): Boolean;
begin
  Result := False;
  
  if FIsInitialized then
  begin
    Result := True;
    Exit;
  end;
  
  try
    // 内存数据库或指定路径
    if DBPath = ':memory:' then
    begin
      FRootPath := GetExeDir;
      FConfigDBPath := DBPath;
    end
    else
    begin
      FRootPath := ExtractFilePath(DBPath);
      FConfigDBPath := DBPath;
    end;
    
    if not ConnectToDatabase(DBPath) then
      Exit;
      
    // 对于内存数据库，始终创建 Schema
    if DBPath = ':memory:' then
    begin
      if not CreateSchema then
        Exit;
    end
    else
    begin
      if not ValidateSchema then
      begin
        if not CreateSchema then
          Exit;
      end;
    end;
    
    InitializeModules;
    
    FIsInitialized := True;
    FInitErrorCode := ecSuccess;
    Result := True;
    
  except
    on E: Exception do
    begin
      FInitErrorCode := ecUnknown;
      FLastError := E.Message;
    end;
  end;
end;

procedure TUniBaseManager.Finalize;
begin
  if not FIsInitialized then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    FinalizeModules;
    
    if Assigned(FConfigDB) then
    begin
      if FConfigDB.Connected then
        FConfigDB.Close;
      FreeAndNil(FConfigDB);
    end;
    
    FIsInitialized := False;
    FRootPath := '';
    FConfigDBPath := '';
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TUniBaseManager.InitializeModules;
var
  I18nRef: TUniBaseI18n;
  TranslateCallback: TTranslateCallback;
begin
  // 1. Logger - create and register as global logger
  FLogger := TUniBaseLogger.Create(FConfigDBPath);
  SetGlobalLogger(FLogger);  // Register with global Logger() function
  
  // 2. Config
  FConfig := TUniBaseConfig.Create(FConfigDB, FLock);
  FConfig.OnConfigChanged := HandleConfigChanged;
  
  // 3. i18n
  FI18n := TUniBaseI18n.Create(FConfigDB, FLock);
  FI18n.OnLanguageChanged := HandleLanguageChanged;
  // Set global T() callback to decouple i18n from Manager
  I18nRef := FI18n;
  TranslateCallback := function(const Text: string): string
    begin
      Result := I18nRef.Translate(Text);
    end;
  SetGlobalTranslateCallback(TranslateCallback);
  
  // 4. Theme
  FTheme := TUniBaseTheme.Create(FConfigDB, FLock);
  FTheme.OnThemeChanged := HandleThemeChanged;
  
  // 5. Security (DPAPI encryption for secrets)
  FSecurity := TUniBaseSecurity.Create(FConfigDB, FLock);
  
  // Load Initial Settings
  FCurrentLanguage := FConfig.GetConfig(SConfigKeyLanguage, SDefaultLanguage);
  FI18n.CurrentLanguage := FCurrentLanguage;
  
  FCurrentTheme := FConfig.GetConfig(SConfigKeyTheme, SDefaultTheme);
  // Note: Theme application usually happens in VCL/FMX layer, Manager just holds data
  // But TUniBaseTheme might apply it if linked to VCL
  if Assigned(FTheme) then
    FTheme.ApplyTheme(FCurrentTheme);
  
  // 6. Load log level from settings (runtime configurable)
  if Assigned(FLogger) then
  begin
    var LogLevelStr := FConfig.GetConfig(SConfigKeyLogLevel, 'INFO');
    FLogger.MinLevel := StrToLogLevel(LogLevelStr);
  end;
  
  // 7. PluginManager - create and load plugins
  FPluginManager := TUniBasePluginManager.Create(
    TPath.Combine(FRootPath, DEFAULT_PLUGINS_DIR),
    CreatePluginContext);
  // Load plugins after core modules are ready
  FPluginManager.LoadAllPlugins;
end;

function TUniBaseManager.CreatePluginContext: IUniBasePluginContext;
var
  ConfigRef: TUniBaseConfig;
  I18nRef: TUniBaseI18n;
  LoggerRef: TUniBaseLogger;
  RootPathStr: string;
begin
  ConfigRef := FConfig;
  I18nRef := FI18n;
  LoggerRef := FLogger;
  RootPathStr := FRootPath;
  
  Result := TPluginContext.Create(
    // GetConfig
    function(const Key, Default: string): string
    begin
      if Assigned(ConfigRef) then
        Result := ConfigRef.GetConfig(Key, Default)
      else
        Result := Default;
    end,
    // SetConfig
    procedure(const Key, Value: string)
    begin
      if Assigned(ConfigRef) then
        ConfigRef.SetConfig(Key, Value);
    end,
    // Translate
    function(const Text: string): string
    begin
      if Assigned(I18nRef) then
        Result := I18nRef.Translate(Text)
      else
        Result := Text;
    end,
    // Log
    procedure(const Msg: string; Level: Integer)
    begin
      if Assigned(LoggerRef) then
        LoggerRef.Log(Msg, TLogLevel(Level), 'Plugin');
    end,
    RootPathStr
  );
end;

procedure TUniBaseManager.FinalizeModules;
begin
  // Unload plugins first (reverse order of initialization)
  if Assigned(FPluginManager) then FreeAndNil(FPluginManager);
  if Assigned(FSecurity) then FreeAndNil(FSecurity);
  if Assigned(FTheme) then FreeAndNil(FTheme);
  if Assigned(FI18n) then FreeAndNil(FI18n);
  if Assigned(FConfig) then FreeAndNil(FConfig);
  if Assigned(FLogger) then FreeAndNil(FLogger);
end;

function TUniBaseManager.FindRootPath: string;
var
  ExeDir, AppDataDir: string;
  RootTxtPath, ReadPath: string;
begin
  Result := '';
  
  // 优先级 1: EXE 所在目录
  ExeDir := GetExeDir;
  RootTxtPath := TPath.Combine(ExeDir, ROOT_TXT_NAME);
  
  if TFile.Exists(RootTxtPath) then
  begin
    ReadPath := ReadRootTxt(RootTxtPath);
    if ReadPath <> '' then
    begin
      Result := ReadPath;
      Exit;
    end;
  end;
  
  // 优先级 2: APPDATA 目录
  AppDataDir := GetAppDataDir;
  if AppDataDir <> '' then
  begin
    RootTxtPath := TPath.Combine(AppDataDir, ROOT_TXT_NAME);
    if TFile.Exists(RootTxtPath) then
    begin
      ReadPath := ReadRootTxt(RootTxtPath);
      if ReadPath <> '' then
        Result := ReadPath;
    end;
  end;
end;

function TUniBaseManager.ReadRootTxt(const FilePath: string): string;
var
  Lines: TArray<string>;
  Line: string;
begin
  Result := '';
  
  try
    Lines := TFile.ReadAllLines(FilePath, TEncoding.UTF8);
    if Length(Lines) > 0 then
    begin
      Line := Trim(Lines[0]);
      
      // 检查是否是 INI 格式扩展
      if (Length(Line) > 0) and (Line[1] = '[') then
      begin
        // TODO: 解析 INI 格式的 [Paths] 部分
        // 暂时不支持，返回空
        Exit;
      end;
      
      // 简单格式：第一行是路径
      if TDirectory.Exists(Line) then
        Result := Line;
    end;
  except
    on E: Exception do
    begin
      // 读取失败，记录日志后返回空
      if Assigned(FLogger) then
        FLogger.Log('ReadRootTxt failed: ' + FilePath + ' - ' + E.Message, llWarn, 'Manager');
    end;
  end;
end;

function TUniBaseManager.WriteRootTxt(const FilePath, RootPath: string): Boolean;
begin
  Result := False;
  try
    TFile.WriteAllText(FilePath, RootPath, TEncoding.UTF8);
    Result := True;
  except
    on E: Exception do
    begin
      // 写入失败，记录日志
      if Assigned(FLogger) then
        FLogger.Log('WriteRootTxt failed: ' + FilePath + ' - ' + E.Message, llWarn, 'Manager');
    end;
  end;
end;

function TUniBaseManager.CreateRootTxt(out FilePath: string): Boolean;
var
  ExeDir, AppDataDir: string;
begin
  Result := False;
  FilePath := '';
  
  // 优先尝试 EXE 目录
  ExeDir := GetExeDir;
  if CheckWritePermission(ExeDir) then
  begin
    FilePath := TPath.Combine(ExeDir, ROOT_TXT_NAME);
    Result := WriteRootTxt(FilePath, ExeDir);
    if Result then
      Exit;
  end;
  
  // 回退到 APPDATA
  AppDataDir := GetAppDataDir;
  if (AppDataDir <> '') and TDirectory.Exists(AppDataDir) then
  begin
    FilePath := TPath.Combine(AppDataDir, ROOT_TXT_NAME);
    Result := WriteRootTxt(FilePath, AppDataDir);
  end;
end;

function TUniBaseManager.ConnectToDatabase(const DBPath: string): Boolean;
begin
  Result := False;
  
  try
    FreeAndNil(FConfigDB);
    FConfigDB := TFDConnection.Create(nil);
    
    FConfigDB.DriverName := 'SQLite';
    FConfigDB.Params.Database := DBPath;
    
    // SQLite 特定设置
    FConfigDB.Params.Values['LockingMode'] := 'Normal';
    FConfigDB.Params.Values['Synchronous'] := 'Normal';
    FConfigDB.Params.Values['JournalMode'] := 'WAL';
    FConfigDB.Params.Values['OpenMode'] := 'CreateUTF8';
    
    FConfigDB.Open;
    Result := FConfigDB.Connected;
    
    if not Result then
    begin
      FInitErrorCode := ecConfigDBNotFound;
      FLastError := 'Failed to connect to database';
    end;
    
  except
    on E: Exception do
    begin
      FInitErrorCode := ecConfigDBNotFound;
      FLastError := 'Database connection error: ' + E.Message;
    end;
  end;
end;

function TUniBaseManager.ValidateSchema: Boolean;
var
  Query: TFDQuery;
  TableCount: Integer;
begin
  Result := False;
  
  if not Assigned(FConfigDB) or not FConfigDB.Connected then
    Exit;
    
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConfigDB;
    
    // 检查必需的表是否存在
    Query.SQL.Text := 
      'SELECT COUNT(*) FROM sqlite_master WHERE type=''table'' AND name IN ' +
      '(''SchemaInfo'', ''ProjectInfo'', ''Settings'', ''FormStates'', ''Languages'', ''I18nTexts'')';
    Query.Open;
    
    TableCount := Query.Fields[0].AsInteger;
    Result := (TableCount = 6);
    
    if not Result then
    begin
      FInitErrorCode := ecConfigDBCorrupted;
      FLastError := Format('Schema validation failed: expected 6 tables, found %d', [TableCount]);
      Exit;
    end;
    
    // 验证 Schema 版本兼容性
    Result := ValidateSchemaVersion;
  finally
    Query.Free;
  end;
end;

function TUniBaseManager.ValidateSchemaVersion: Boolean;
var
  DBVersion: string;
  
  function CompareVersions(const V1, V2: string): Integer;
  var
    Parts1, Parts2: TArray<string>;
    I, N1, N2: Integer;
  begin
    Parts1 := V1.Split(['.']);
    Parts2 := V2.Split(['.']);
    Result := 0;
    
    for I := 0 to Max(Length(Parts1), Length(Parts2)) - 1 do
    begin
      if I < Length(Parts1) then N1 := StrToIntDef(Parts1[I], 0) else N1 := 0;
      if I < Length(Parts2) then N2 := StrToIntDef(Parts2[I], 0) else N2 := 0;
      
      if N1 < N2 then Exit(-1);
      if N1 > N2 then Exit(1);
    end;
  end;
  
begin
  Result := True;
  
  DBVersion := GetSchemaVersionInternal;
  if DBVersion = '' then
  begin
    // 没有版本信息，可能是旧数据库，允许继续
    Exit;
  end;
  
  // 检查版本范围
  if CompareVersions(DBVersion, MIN_COMPATIBLE_SCHEMA_VERSION) < 0 then
  begin
    FInitErrorCode := ecSchemaVersionMismatch;
    FLastError := Format(
      'Database schema version %s is too old. Minimum required: %s. ' +
      'Please upgrade your database or use CheckAndMigrateSchema.',
      [DBVersion, MIN_COMPATIBLE_SCHEMA_VERSION]);
    Result := False;
    Exit;
  end;
  
  if CompareVersions(DBVersion, MAX_COMPATIBLE_SCHEMA_VERSION) > 0 then
  begin
    FInitErrorCode := ecSchemaVersionMismatch;
    FLastError := Format(
      'Database schema version %s is newer than framework supports (max: %s). ' +
      'Please upgrade UniBase framework.',
      [DBVersion, MAX_COMPATIBLE_SCHEMA_VERSION]);
    Result := False;
    Exit;
  end;
end;

function TUniBaseManager.CreateSchema: Boolean;
var
  Script: TFDScript;
begin
  Result := False;
  
  if not Assigned(FConfigDB) or not FConfigDB.Connected then
    Exit;

  Script := TFDScript.Create(nil);
  try
    Script.Connection := FConfigDB;
    Script.SQLScripts.Add;
    // Use centralized schema definitions from UniBase.Schema unit
    Script.SQLScripts[0].SQL.Text := GetFullSchemaSQL;
    
    try
      Script.ExecuteAll;
      Result := True;
      FInitErrorCode := ecSuccess;
    except
      on E: Exception do
      begin
        FInitErrorCode := ecConfigDBCorrupted;
        FLastError := 'Failed to create schema: ' + E.Message;
      end;
    end;
    
  finally
    Script.Free;
  end;
end;

function TUniBaseManager.GetSchemaVersionInternal: string;
var
  Query: TFDQuery;
begin
  Result := '';
  
  if not Assigned(FConfigDB) or not FConfigDB.Connected then
    Exit;
    
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConfigDB;
    Query.SQL.Text := 'SELECT Value FROM SchemaInfo WHERE Key = ''SchemaVersion''';
    Query.Open;
    
    if not Query.Eof then
      Result := Query.FieldByName('Value').AsString;
  finally
    Query.Free;
  end;
end;

function TUniBaseManager.GetCurrentSchemaVersion: string;
begin
  TMonitor.Enter(FLock);
  try
    Result := GetSchemaVersionInternal;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TUniBaseManager.RunMigrationScript(const ScriptPath: string): Boolean;
var
  Script: TFDScript;
  ScriptSQL: string;
begin
  Result := False;
  
  if not TFile.Exists(ScriptPath) then
  begin
    FLastError := 'Migration script not found: ' + ScriptPath;
    Exit;
  end;
  
  try
    ScriptSQL := TFile.ReadAllText(ScriptPath, TEncoding.UTF8);
    
    Script := TFDScript.Create(nil);
    try
      Script.Connection := FConfigDB;
      Script.SQLScripts.Add;
      Script.SQLScripts[0].SQL.Text := ScriptSQL;
      Script.ExecuteAll;
      Result := True;
    finally
      Script.Free;
    end;
  except
    on E: Exception do
    begin
      FLastError := 'Migration script error: ' + E.Message;
    end;
  end;
end;

function TUniBaseManager.MigrateSchemaInternal(const FromVersion, ToVersion: string): Boolean;
var
  ScriptPath: string;
  Query: TFDQuery;
begin
  Result := False;
  
  // Build script path: sql/upgrade_v0.2_to_v0.3.sql (dots replaced with underscores)
  ScriptPath := TPath.Combine(FRootPath, 'sql');
  ScriptPath := TPath.Combine(ScriptPath, 
    Format('upgrade_v%s_to_v%s.sql', [
      StringReplace(FromVersion, '.', '_', [rfReplaceAll]),
      StringReplace(ToVersion, '.', '_', [rfReplaceAll])
    ]));
  
  if not RunMigrationScript(ScriptPath) then
    Exit;
  
  // Update SchemaInfo
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConfigDB;
    Query.SQL.Text := 'UPDATE SchemaInfo SET Value = :Ver WHERE Key = ''SchemaVersion''';
    Query.ParamByName('Ver').AsString := ToVersion;
    Query.ExecSQL;
    
    Query.SQL.Text := 'UPDATE SchemaInfo SET Value = datetime(''now'') WHERE Key = ''LastUpgrade''';
    Query.ExecSQL;
    
    Result := True;
  finally
    Query.Free;
  end;
end;

function TUniBaseManager.CheckAndMigrateSchema(const TargetVersion: string): Boolean;
var
  CurrentVer, Target: string;
  VersionParts: TArray<string>;
  CurrentMajor, CurrentMinor: Integer;
  TargetMajor, TargetMinor: Integer;
begin
  Result := True;
  
  TMonitor.Enter(FLock);
  try
    CurrentVer := GetSchemaVersionInternal;
    
    if CurrentVer = '' then
    begin
      FLastError := 'Cannot determine current schema version';
      Result := False;
      Exit;
    end;
    
    // Use UNIBASE_VERSION if target not specified
    if TargetVersion = '' then
      Target := UNIBASE_VERSION
    else
      Target := TargetVersion;
    
    if CurrentVer = Target then
      Exit; // Already at target version
    
    // Parse versions (supports X.Y format)
    VersionParts := CurrentVer.Split(['.']);
    if Length(VersionParts) >= 2 then
    begin
      TryStrToInt(VersionParts[0], CurrentMajor);
      TryStrToInt(VersionParts[1], CurrentMinor);
    end
    else
    begin
      CurrentMajor := 0;
      CurrentMinor := 0;
    end;
    
    VersionParts := Target.Split(['.']);
    if Length(VersionParts) >= 2 then
    begin
      TryStrToInt(VersionParts[0], TargetMajor);
      TryStrToInt(VersionParts[1], TargetMinor);
    end
    else
    begin
      TargetMajor := 0;
      TargetMinor := 0;
    end;
    
    // Only support forward migration for now
    if (TargetMajor < CurrentMajor) or 
       ((TargetMajor = CurrentMajor) and (TargetMinor < CurrentMinor)) then
    begin
      FLastError := Format('Downgrade not supported: %s -> %s', [CurrentVer, Target]);
      Result := False;
      Exit;
    end;
    
    // Sequential migration: current -> target
    // For simplicity, we try direct migration first
    Result := MigrateSchemaInternal(CurrentVer, Target);
    
    if not Result then
      FLastError := Format('Migration failed: %s -> %s. %s', [CurrentVer, Target, FLastError]);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TUniBaseManager.GetExeDir: string;
begin
  Result := ExtractFilePath(ParamStr(0));
end;

function TUniBaseManager.GetAppDataDir: string;
{$IFDEF MSWINDOWS}
var
  Path: array[0..MAX_PATH] of Char;
{$ENDIF}
begin
  Result := '';
  
  {$IFDEF MSWINDOWS}
  if SHGetFolderPath(0, CSIDL_APPDATA, 0, 0, @Path) = S_OK then
  begin
    Result := TPath.Combine(Path, 'UniBase');
    if not TDirectory.Exists(Result) then
    begin
      try
        TDirectory.CreateDirectory(Result);
      except
        Result := '';
      end;
    end;
  end;
  {$ELSE}
  Result := TPath.Combine(TPath.GetHomePath, '.unibase');
  if not TDirectory.Exists(Result) then
  begin
    try
      TDirectory.CreateDirectory(Result);
    except
      Result := '';
    end;
  end;
  {$ENDIF}
end;

function TUniBaseManager.CheckWritePermission(const Path: string): Boolean;
var
  TestFile: string;
begin
  Result := False;
  
  if not TDirectory.Exists(Path) then
    Exit;
    
  TestFile := TPath.Combine(Path, '.unibase_write_test');
  try
    TFile.WriteAllText(TestFile, 'test');
    TFile.Delete(TestFile);
    Result := True;
  except
    // 无写入权限
  end;
end;

function TUniBaseManager.HealthCheck: THealthCheckResult;
begin
  Result.Init;
  
  // Check initialization status
  if not FIsInitialized then
  begin
    Result.AddMessage('UniBase not initialized');
    Result.TrimMessages;
    Exit;
  end;
  
  // Check database connection
  if Assigned(FConfigDB) and FConfigDB.Connected then
  begin
    Result.ConfigDBOk := True;
    Result.AddMessage('ConfigDB: OK');
  end
  else
  begin
    Result.AddMessage('ConfigDB: Not connected');
  end;
  
  // Check assets directory
  if TDirectory.Exists(TPath.Combine(FRootPath, 'assets')) then
  begin
    Result.AssetsDirOk := True;
    Result.AddMessage('Assets directory: OK');
  end
  else
  begin
    Result.AddMessage('Assets directory: Not found (optional)');
    Result.AssetsDirOk := True; // Assets is optional
  end;
  
  // LLM check (Phase 2)
  Result.LLMConnectionOk := False;
  Result.AddMessage('LLM: Not configured (Phase 2)');
  
  // Overall status
  Result.IsHealthy := Result.ConfigDBOk;
  
  // Trim array to actual size
  Result.TrimMessages;
end;

function TUniBaseManager.GetProjectInfo(const Key: string): string;
var
  Query: TFDQuery;
begin
  Result := '';
  
  if not FIsInitialized then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConfigDB;
      Query.SQL.Text := 'SELECT Value FROM ProjectInfo WHERE Key = :Key';
      Query.ParamByName('Key').AsString := Key;
      Query.Open;
      
      if not Query.Eof then
        Result := Query.FieldByName('Value').AsString;
    finally
      Query.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TUniBaseManager.SetProjectInfo(const Key, Value: string);
var
  Query: TFDQuery;
begin
  if not FIsInitialized then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConfigDB;
      Query.SQL.Text := 'INSERT OR REPLACE INTO ProjectInfo (Key, Value) VALUES (:Key, :Value)';
      Query.ParamByName('Key').AsString := Key;
      Query.ParamByName('Value').AsString := Value;
      Query.ExecSQL;
    finally
      Query.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TUniBaseManager.GetAssetPath(const RelativePath: string): string;
begin
  if FRootPath <> '' then
    Result := TPath.Combine(TPath.Combine(FRootPath, 'assets'), RelativePath)
  else
    Result := RelativePath;
end;

procedure TUniBaseManager.SetCurrentLanguage(const Value: string);
var
  OldValue: string;
begin
  if FCurrentLanguage <> Value then
  begin
    OldValue := FCurrentLanguage;
    FCurrentLanguage := Value;
    DoLanguageChanged;
    DoConfigChanged('App.Language', OldValue, Value);
  end;
end;

procedure TUniBaseManager.SetCurrentTheme(const Value: string);
var
  OldValue: string;
begin
  if FCurrentTheme <> Value then
  begin
    OldValue := FCurrentTheme;
    FCurrentTheme := Value;
    DoThemeChanged;
    DoConfigChanged('App.Theme', OldValue, Value);
  end;
end;

procedure TUniBaseManager.DoLanguageChanged;
begin
  if Assigned(FOnLanguageChanged) then
    FOnLanguageChanged(Self);
end;

procedure TUniBaseManager.DoThemeChanged;
begin
  if Assigned(FOnThemeChanged) then
    FOnThemeChanged(Self);
end;

procedure TUniBaseManager.DoConfigChanged(const Key, OldValue, NewValue: string);
begin
  if Assigned(FOnConfigChanged) then
    FOnConfigChanged(Self, Key, OldValue, NewValue);
end;

procedure TUniBaseManager.HandleConfigChanged(Sender: TObject; const Key, OldValue, NewValue: string);
begin
  // Handle log level changes at runtime
  if (Key = SConfigKeyLogLevel) and Assigned(FLogger) then
    FLogger.MinLevel := StrToLogLevel(NewValue);
  
  DoConfigChanged(Key, OldValue, NewValue);
end;

procedure TUniBaseManager.HandleLanguageChanged(Sender: TObject);
begin
  DoLanguageChanged;
end;

procedure TUniBaseManager.HandleThemeChanged(Sender: TObject);
begin
  DoThemeChanged;
end;

initialization
  GUniBaseLock := TObject.Create;

finalization
  FreeAndNil(GUniBaseManager);
  FreeAndNil(GUniBaseLock);

end.
