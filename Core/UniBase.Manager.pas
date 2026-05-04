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
  System.DateUtils,
  System.Math,
  System.Threading,  // BUG-007 FIX: Added for TTask.Run
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
  UniBase.Interfaces,
  UniBase.Config,
  UniBase.i18n,
  UniBase.Theme,
  UniBase.Logging,
  UniBase.Security,
  UniBase.Plugin,
  UniBase.PluginManager,
  UniBase.FormState,
  UniBase.MRU,
  UniBase.Hotkeys;

const
  UNIBASE_VERSION = '0.3';
  CONFIG_DB_SUFFIX = 'Config.db';
  DATA_DB_SUFFIX = 'Data.db';
  ROOT_TXT_NAME = 'root.txt';
  
  // R-004: Schema 验证所需的核心表
  REQUIRED_CORE_TABLES: array[0..5] of string = (
    'SchemaInfo', 'ProjectInfo', 'Settings', 'FormStates', 'Languages', 'I18nTexts'
  );
  
  /// <summary>
  /// Schema version compatibility error code
  /// </summary>
  ecSchemaVersionMismatch = TInitErrorCode(10);

type
  TUniBaseManager = class;

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
    
    // 延迟初始化回调
    FReadyCallbacks: TList<TProc>;
    FReadyFired: Boolean;
    
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
    FFormState: TUniBaseFormState;
    FMRU: TUniBaseMRU;
    FHotkeys: TUniBaseHotkeys;
    
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
    procedure EnsureSchemaColumns;
    procedure RunOperationalRetention;
    function GetRetentionDays(const SettingKey: string;
      DefaultValue: Integer): Integer;
    function TableExists(const TableName: string): Boolean;
    function TableHasColumn(const TableName, ColumnName: string): Boolean;
    function ResolveTimeColumn(const TableName, Preferred,
      Fallback: string): string;
    procedure ArchiveAndTrimTable(const TableName, TimeColumn: string;
      DaysToKeep: Integer);
    function GetExeDir: string;
    function GetAppDataDir: string;
    function CheckWritePermission(const Path: string): Boolean;
    function FindRootPath: string;
    function CreatePluginContext: IUniBasePluginContext;
    
    // InitializeEx 辅助方法（R-001 重构）
    function DoFindRootPath(out ErrorMsg: string): Boolean;
    function DoLocateConfigDB(out ErrorMsg: string): Boolean;
    function DoConnectAndValidate(out ErrorMsg: string): Boolean;
    
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
    
    /// <summary>
    /// 注册初始化完成后的回调。如果已初始化则立即执行。
    /// 用于解决窗体 FormShow 中访问 UniBase 功能时对象未就绪的问题。
    /// </summary>
    /// <example>
    /// procedure TMyForm.FormShow(Sender: TObject);
    /// begin
    ///   UniBase.WhenReady(procedure
    ///   begin
    ///     LoadProviders;  // 安全：此时 UniBase 已完全初始化
    ///   end);
    /// end;
    /// </example>
    procedure WhenReady(ACallback: TProc);
    
    /// <summary>
    /// 触发所有已注册的 Ready 回调（由 Application.Run 前调用）
    /// </summary>
    procedure FireReadyCallbacks;
    
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
    property FormState: TUniBaseFormState read FFormState;
    property MRU: TUniBaseMRU read FMRU;
    property Hotkeys: TUniBaseHotkeys read FHotkeys;
    
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

// ============================================================================
// Direct Module Access Functions (Convenience Shortcuts)
// These provide direct access to sub-modules without calling UniBase() first.
// Usage:
//   uses UniBase.Manager;
//   Value := UBConfig.GetConfig('Key', 'Default');
//   UBI18n.Translate('Hello');
// ============================================================================

/// <summary>Direct access to Config module</summary>
function UBConfig: TUniBaseConfig;
/// <summary>Direct access to I18n module</summary>
function UBI18n: TUniBaseI18n;
/// <summary>Direct access to Theme module</summary>
function UBTheme: TUniBaseTheme;
/// <summary>Direct access to Logger module</summary>
function UBLogger: TUniBaseLogger;
/// <summary>Direct access to Security module</summary>
function UBSecurity: TUniBaseSecurity;
/// <summary>Direct access to PluginManager module</summary>
function UBPlugins: TUniBasePluginManager;
/// <summary>Direct access to FormState module</summary>
function UBFormState: TUniBaseFormState;
/// <summary>Direct access to MRU module</summary>
function UBMRU: TUniBaseMRU;
/// <summary>Direct access to Hotkeys module</summary>
function UBHotkeys: TUniBaseHotkeys;

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

function UBConfig: TUniBaseConfig;
begin
  Result := UniBase.Config;
end;

function UBI18n: TUniBaseI18n;
begin
  Result := UniBase.I18n;
end;

function UBTheme: TUniBaseTheme;
begin
  Result := UniBase.Theme;
end;

function UBLogger: TUniBaseLogger;
begin
  Result := UniBase.Logger;
end;

function UBSecurity: TUniBaseSecurity;
begin
  Result := UniBase.Security;
end;

function UBPlugins: TUniBasePluginManager;
begin
  Result := UniBase.PluginManager;
end;

function UBFormState: TUniBaseFormState;
begin
  Result := UniBase.FormState;
end;

function UBMRU: TUniBaseMRU;
begin
  Result := UniBase.MRU;
end;

function UBHotkeys: TUniBaseHotkeys;
begin
  Result := UniBase.Hotkeys;
end;

{ TUniBaseManager }

constructor TUniBaseManager.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FLock := TObject.Create;
  FReadyCallbacks := TList<TProc>.Create;
  FReadyFired := False;
  FIsInitialized := False;
  FInitErrorCode := ecUnknown;
  FLastError := '';
  FCurrentLanguage := 'en-US';
  FCurrentTheme := 'Windows11';
end;

destructor TUniBaseManager.Destroy;
begin
  Finalize;
  FReadyCallbacks.Free;
  FLock.Free;
  inherited;
end;

function TUniBaseManager.Initialize: Boolean;
var
  Dummy: string;
begin
  Result := InitializeEx(Dummy);
end;

function TUniBaseManager.DoFindRootPath(out ErrorMsg: string): Boolean;
var
  RootTxtPath: string;
begin
  Result := False;
  ErrorMsg := '';
  
  // 查找 root.txt
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
  
  // 验证根目录
  if not TDirectory.Exists(FRootPath) then
  begin
    FInitErrorCode := ecInvalidPath;
    FLastError := 'Root path does not exist: ' + FRootPath;
    ErrorMsg := Format('[%d] %s: %s', [Ord(FInitErrorCode),
      InitErrorCodeToStr(FInitErrorCode), FLastError]);
    Exit;
  end;
  
  Result := True;
end;

function TUniBaseManager.DoLocateConfigDB(out ErrorMsg: string): Boolean;
var
  AppName: string;
  ConfigFileName: string;
  AppDataDir: string;
  FallbackPath: string;
begin
  Result := False;
  ErrorMsg := '';
  
  // 计算 ConfigDB 文件名：{AppName}Config.db
  AppName := ChangeFileExt(ExtractFileName(ParamStr(0)), '');
  if AppName = '' then
    AppName := 'UniBase'; // 兜底，避免空应用名

  ConfigFileName := AppName + CONFIG_DB_SUFFIX;

  // 优先在 RootPath 下查找 {AppName}Config.db
  FConfigDBPath := TPath.Combine(FRootPath, ConfigFileName);

  if not TFile.Exists(FConfigDBPath) then
  begin
    // 备用位置：%APPDATA%/{AppName}/{AppName}Config.db
    AppDataDir := GetAppDataDir;
    if AppDataDir <> '' then
    begin
      FallbackPath := TPath.Combine(AppDataDir, ConfigFileName);
      if TFile.Exists(FallbackPath) then
      begin
        FConfigDBPath := FallbackPath;
      end;
      // 如果两个位置都不存在，保持 FConfigDBPath 指向 RootPath 下的路径
      // ConnectToDatabase 会使用 OpenMode=CreateUTF8 自动创建数据库文件
    end;
    // 不再报错，让 ConnectToDatabase 自动创建数据库
  end;
  
  Result := True;
end;

function TUniBaseManager.DoConnectAndValidate(out ErrorMsg: string): Boolean;
begin
  Result := False;
  ErrorMsg := '';
  
  // 连接数据库
  if not ConnectToDatabase(FConfigDBPath) then
  begin
    ErrorMsg := Format('[%d] %s: %s', [Ord(FInitErrorCode),
      InitErrorCodeToStr(FInitErrorCode), FLastError]);
    Exit;
  end;
  
  // 验证/创建 Schema（使用 IF NOT EXISTS 确保所有表存在）
  if not CreateSchema then
  begin
    ErrorMsg := Format('[%d] %s: %s', [Ord(FInitErrorCode),
      InitErrorCodeToStr(FInitErrorCode), FLastError]);
    Exit;
  end;
  
  Result := True;
end;

function TUniBaseManager.InitializeEx(out ErrorMsg: string): Boolean;
begin
  Result := False;
  ErrorMsg := '';
  
  if FIsInitialized then
  begin
    Result := True;
    Exit;
  end;
  
  try
    // 1. 查找并验证根目录
    if not DoFindRootPath(ErrorMsg) then
      Exit;
    
    // 2. 定位配置数据库
    if not DoLocateConfigDB(ErrorMsg) then
      Exit;
    
    // 3. 连接数据库并验证 Schema
    if not DoConnectAndValidate(ErrorMsg) then
      Exit;
    
    // 4. 初始化子模块
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
    FReadyFired := False;
    FRootPath := '';
    FConfigDBPath := '';
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TUniBaseManager.WhenReady(ACallback: TProc);
begin
  if not Assigned(ACallback) then
    Exit;
    
  // 如果已经触发过 Ready，使用异步执行避免嵌套锁定导致死锁
  // BUG-007 FIX: Use TTask.Run to prevent deadlock when callback calls UniBase functions
  if FReadyFired then
  begin
    TTask.Run(procedure
    begin
      try
        ACallback();
      except
        on E: Exception do
          if Assigned(FLogger) then
            FLogger.Error('WhenReady callback failed: ' + E.Message, 'UniBase');
      end;
    end);
    Exit;
  end;
  
  // 否则加入队列等待
  TMonitor.Enter(FLock);
  try
    FReadyCallbacks.Add(ACallback);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TUniBaseManager.FireReadyCallbacks;
var
  Callback: TProc;
  I: Integer;
begin
  if FReadyFired then
    Exit;
    
  FReadyFired := True;
  
  TMonitor.Enter(FLock);
  try
    for I := 0 to FReadyCallbacks.Count - 1 do
    begin
      Callback := FReadyCallbacks[I];
      try
        Callback();
      except
        on E: Exception do
          if Assigned(FLogger) then
            FLogger.Error('Ready callback failed: ' + E.Message, 'UniBase');
      end;
    end;
    FReadyCallbacks.Clear;
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
  
  // PERF-001: 预热配置缓存，避免首次访问时产生多次小查询
  try
    FConfig.PreloadCache;
  except
    // 预热失败不影响正常运行，保持静默或在 DEBUG 下输出
    {$IFDEF DEBUG}
    OutputDebugString('UniBase.Manager: PreloadCache failed');
    {$ENDIF}
  end;
  
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
  RunOperationalRetention;
  
  // 7. FormState - form position persistence
  FFormState := TUniBaseFormState.Create(FConfigDB, FLock);
  
  // 8. MRU - Most Recently Used tracking
  FMRU := TUniBaseMRU.Create(FConfigDB, FLock);
  
  // 9. Hotkeys - keyboard shortcut management
  FHotkeys := TUniBaseHotkeys.Create(FConfigDB, FLock);
  
  // 10. PluginManager - create and load plugins
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
  if Assigned(FHotkeys) then FreeAndNil(FHotkeys);
  if Assigned(FMRU) then FreeAndNil(FMRU);
  if Assigned(FFormState) then FreeAndNil(FFormState);
  if Assigned(FSecurity) then FreeAndNil(FSecurity);
  if Assigned(FTheme) then FreeAndNil(FTheme);
  if Assigned(FI18n) then FreeAndNil(FI18n);
  if Assigned(FConfig) then FreeAndNil(FConfig);
  if Assigned(FLogger) then
  begin
    // 先解除全局 Logger 绑定，再由 Manager 负责释放实例
    SetGlobalLogger(nil);
    FreeAndNil(FLogger);
  end;
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
        // INI 格式的 [Paths] 扩展目前不支持，为保持兼容直接返回空路径
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
  I: Integer;
  TableList: string;
begin
  Result := False;
  
  if not Assigned(FConfigDB) or not FConfigDB.Connected then
    Exit;
    
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConfigDB;
    
    // R-004: 使用 REQUIRED_CORE_TABLES 常量构建查询
    TableList := '';
    for I := Low(REQUIRED_CORE_TABLES) to High(REQUIRED_CORE_TABLES) do
    begin
      if I > Low(REQUIRED_CORE_TABLES) then
        TableList := TableList + ', ';
      TableList := TableList + QuotedStr(REQUIRED_CORE_TABLES[I]);
    end;
    
    Query.SQL.Text := Format(
      'SELECT COUNT(*) FROM sqlite_master WHERE type=''table'' AND name IN (%s)',
      [TableList]);
    Query.Open;
    
    TableCount := Query.Fields[0].AsInteger;
    Result := (TableCount = Length(REQUIRED_CORE_TABLES));
    
    if not Result then
    begin
      FInitErrorCode := ecConfigDBCorrupted;
      FLastError := Format('Schema validation failed: expected %d tables, found %d',
        [Length(REQUIRED_CORE_TABLES), TableCount]);
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
begin
  // Uses UniBase.Types.CompareVersions
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
  Query: TFDQuery;
  FullSQL: string;
  Statements: TArray<string>;
  Stmt: string;
  I, MaxRetry: Integer;
  ErrorMsg: string;
  LastStmt: string;
  
  function SplitSQLStatements(const SQL: string): TArray<string>;
  var
    Current: string;
    List: TList<string>;
    InString: Boolean;
    C: Char;
    J: Integer;
  begin
    // Split by semicolon, but respect string literals
    List := TList<string>.Create;
    try
      Current := '';
      InString := False;
      for J := 1 to Length(SQL) do
      begin
        C := SQL[J];
        if C = '''' then
          InString := not InString;
        if (C = ';') and not InString then
        begin
          Current := Trim(Current);
          if Current <> '' then
            List.Add(Current);
          Current := '';
        end
        else
          Current := Current + C;
      end;
      Current := Trim(Current);
      if Current <> '' then
        List.Add(Current);
      Result := List.ToArray;
    finally
      List.Free;
    end;
  end;
  
begin
  Result := False;
  
  if not Assigned(FConfigDB) or not FConfigDB.Connected then
    Exit;
  
  MaxRetry := 2;  // Try twice: first attempt, then after fixing columns
  
  for I := 1 to MaxRetry do
  begin
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConfigDB;
      // Disable parameter parsing to avoid issues with :name patterns in string literals
      Query.ResourceOptions.ParamCreate := False;
      
      FullSQL := GetFullSchemaSQL;
      Statements := SplitSQLStatements(FullSQL);
      
      try
        for Stmt in Statements do
        begin
          if Trim(Stmt) <> '' then
          begin
            LastStmt := Stmt;  // keep for error reporting
            Query.SQL.Text := Stmt;
            Query.ExecSQL;
          end;
        end;
        try
          // Run compatibility column patching even when schema creation succeeds.
          // Some legacy tables (e.g. MRU ItemPath -> ItemKey) won't fail CREATE IF NOT EXISTS.
          EnsureSchemaColumns;
        except
          on E: Exception do
            if Assigned(FLogger) then
              FLogger.Warn('Post-schema compatibility patch failed: ' + E.Message, 'UniBase.Manager');
        end;
        Result := True;
        FInitErrorCode := ecSuccess;
        Exit;  // Success, exit loop
      except
        on E: Exception do
        begin
          ErrorMsg := E.Message;
          // If first attempt fails, try to fix schema columns
          if I < MaxRetry then
          begin
            try
              EnsureSchemaColumns;  // Add missing columns to existing tables
            except
              on E2: Exception do
                if Assigned(FLogger) then
                  FLogger.Warn('Schema column fix attempt failed: ' + E2.Message, 'UniBase.Manager');
            end;
          end
          else
          begin
            FInitErrorCode := ecConfigDBCorrupted;
            // include failing statement for diagnosis (truncate if too long)
            if Length(LastStmt) > 400 then
              LastStmt := Copy(LastStmt, 1, 400) + '...';
            FLastError := 'Failed to create schema: ' + ErrorMsg + sLineBreak +
                          'Statement: ' + LastStmt;
          end;
        end;
      end;
    finally
      Query.Free;
    end;
  end;
end;

procedure TUniBaseManager.EnsureSchemaColumns;
var
  Query: TFDQuery;
  
  function ColumnExists(const TableName, ColumnName: string): Boolean;
  begin
    Query.SQL.Text := Format(
      'SELECT COUNT(*) FROM pragma_table_info(''%s'') WHERE name = ''%s''',
      [TableName, ColumnName]);
    Query.Open;
    Result := Query.Fields[0].AsInteger > 0;
    Query.Close;
  end;
  
  procedure AddColumnIfMissing(const TableName, ColumnName, ColumnDef: string);
  begin
    if not ColumnExists(TableName, ColumnName) then
    begin
      try
        Query.SQL.Text := Format('ALTER TABLE %s ADD COLUMN %s %s',
          [TableName, ColumnName, ColumnDef]);
        Query.ExecSQL;
      except
        on E: Exception do
          {$IFDEF DEBUG}
          OutputDebugString(PChar('UniBase.Manager: ALTER TABLE failed: ' + E.Message));
          {$ENDIF}
      end;
    end;
  end;
  
begin
  if not Assigned(FConfigDB) or not FConfigDB.Connected then
    Exit;
    
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConfigDB;
    Query.ResourceOptions.ParamCreate := False;
    
    // === Settings table columns ===
    AddColumnIfMissing('Settings', 'ValueType', 'TEXT DEFAULT ''String''');
    AddColumnIfMissing('Settings', 'Category', 'TEXT DEFAULT ''General''');
    AddColumnIfMissing('Settings', 'Description', 'TEXT');
    AddColumnIfMissing('Settings', 'DefaultValue', 'TEXT');
    AddColumnIfMissing('Settings', 'MinValue', 'TEXT');
    AddColumnIfMissing('Settings', 'MaxValue', 'TEXT');
    AddColumnIfMissing('Settings', 'Options', 'TEXT');
    AddColumnIfMissing('Settings', 'IsEncrypted', 'INTEGER DEFAULT 0');
    AddColumnIfMissing('Settings', 'IsReadOnly', 'INTEGER DEFAULT 0');
    AddColumnIfMissing('Settings', 'IsHidden', 'INTEGER DEFAULT 0');
    AddColumnIfMissing('Settings', 'SortOrder', 'INTEGER DEFAULT 0');
    AddColumnIfMissing('Settings', 'CreatedAt', 'TEXT');
    AddColumnIfMissing('Settings', 'UpdatedAt', 'TEXT');
    
    // === Languages table columns ===
    AddColumnIfMissing('Languages', 'NativeName', 'TEXT');
    AddColumnIfMissing('Languages', 'FlagIcon', 'TEXT');
    AddColumnIfMissing('Languages', 'DateFormat', 'TEXT');
    AddColumnIfMissing('Languages', 'TimeFormat', 'TEXT');
    AddColumnIfMissing('Languages', 'NumberFormat', 'TEXT');
    AddColumnIfMissing('Languages', 'CurrencySymbol', 'TEXT');
    AddColumnIfMissing('Languages', 'TextDirection', 'TEXT DEFAULT ''LTR''');
    AddColumnIfMissing('Languages', 'FontFamily', 'TEXT');
    AddColumnIfMissing('Languages', 'IsEnabled', 'INTEGER DEFAULT 1');
    AddColumnIfMissing('Languages', 'IsDefault', 'INTEGER DEFAULT 0');
    AddColumnIfMissing('Languages', 'IsComplete', 'INTEGER DEFAULT 0');
    AddColumnIfMissing('Languages', 'SortOrder', 'INTEGER DEFAULT 0');
    
    // === Logs table columns (renamed from old schema) ===
    AddColumnIfMissing('Logs', 'LogTime', 'TEXT');
    AddColumnIfMissing('Logs', 'LogLevel', 'TEXT');
    AddColumnIfMissing('Logs', 'Source', 'TEXT');
    AddColumnIfMissing('Logs', 'ExceptionClass', 'TEXT');
    AddColumnIfMissing('Logs', 'ExceptionMessage', 'TEXT');
    AddColumnIfMissing('Logs', 'ThreadId', 'INTEGER');
    AddColumnIfMissing('Logs', 'UserId', 'TEXT');
    
    // === MRU table columns ===
    AddColumnIfMissing('MRU', 'ItemKey', 'TEXT');
    AddColumnIfMissing('MRU', 'DisplayName', 'TEXT');
    AddColumnIfMissing('MRU', 'IconIndex', 'INTEGER DEFAULT 0');
    AddColumnIfMissing('MRU', 'IsPinned', 'INTEGER DEFAULT 0');
    AddColumnIfMissing('MRU', 'Extra', 'TEXT');
    if ColumnExists('MRU', 'ItemPath') and ColumnExists('MRU', 'ItemKey') then
    begin
      try
        Query.SQL.Text :=
          'UPDATE MRU SET ItemKey = ItemPath ' +
          'WHERE (ItemKey IS NULL OR ItemKey = '''') ' +
          'AND ItemPath IS NOT NULL AND ItemPath <> ''''';
        Query.ExecSQL;
      except
        on E: Exception do
          {$IFDEF DEBUG}
          OutputDebugString(PChar('UniBase.Manager: MRU ItemPath->ItemKey migration failed: ' + E.Message));
          {$ENDIF}
      end;
    end;
    if ColumnExists('MRU', 'ItemKey') then
    begin
      try
        Query.SQL.Text :=
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_mru_category_itemkey ' +
          'ON MRU(Category, ItemKey)';
        Query.ExecSQL;
      except
        on E: Exception do
          {$IFDEF DEBUG}
          OutputDebugString(PChar('UniBase.Manager: MRU unique index patch failed: ' + E.Message));
          {$ENDIF}
      end;
    end;
    
    // === FormStates table columns ===
    AddColumnIfMissing('FormStates', 'MonitorIndex', 'INTEGER DEFAULT 0');
    AddColumnIfMissing('FormStates', 'Splitters', 'TEXT');
    AddColumnIfMissing('FormStates', 'Columns', 'TEXT');
    AddColumnIfMissing('FormStates', 'TabIndex', 'INTEGER DEFAULT 0');
    AddColumnIfMissing('FormStates', 'ScrollPos', 'TEXT');
    AddColumnIfMissing('FormStates', 'LastAccess', 'TEXT');
    AddColumnIfMissing('FormStates', 'Extra', 'TEXT');
    
    // === Hotkeys table columns ===
    AddColumnIfMissing('Hotkeys', 'Description', 'TEXT');
    AddColumnIfMissing('Hotkeys', 'Category', 'TEXT');
    
    // === Themes table columns ===
    AddColumnIfMissing('Themes', 'DisplayName', 'TEXT');
    AddColumnIfMissing('Themes', 'StyleFile', 'TEXT');
    AddColumnIfMissing('Themes', 'AccentColor', 'INTEGER');
    AddColumnIfMissing('Themes', 'CustomCSS', 'TEXT');
    
    // === LLMConfig table columns ===
    AddColumnIfMissing('LLMConfig', 'ContextWindow', 'INTEGER DEFAULT 4096');
    AddColumnIfMissing('LLMConfig', 'PricePer1kPrompt', 'REAL DEFAULT 0');
    AddColumnIfMissing('LLMConfig', 'PricePer1kCompletion', 'REAL DEFAULT 0');
    
    // === LLMCalls table columns ===
    AddColumnIfMissing('LLMCalls', 'CallTime', 'TEXT');  // Alias for RequestTime
    AddColumnIfMissing('LLMCalls', 'Prompt', 'TEXT');     // Alias for InputText
    AddColumnIfMissing('LLMCalls', 'Response', 'TEXT');   // Alias for OutputText
    AddColumnIfMissing('LLMCalls', 'EstimatedCost', 'REAL DEFAULT 0');
    AddColumnIfMissing('LLMCalls', 'DurationMs', 'INTEGER DEFAULT 0');
    AddColumnIfMissing('LLMCalls', 'Success', 'INTEGER DEFAULT 1');
    AddColumnIfMissing('LLMCalls', 'ErrorCode', 'TEXT');
    AddColumnIfMissing('LLMCalls', 'CallerModule', 'TEXT');
    AddColumnIfMissing('LLMCalls', 'CallerFunction', 'TEXT');
    
    // === LLMPromptTemplates table columns ===
    AddColumnIfMissing('LLMPromptTemplates', 'DefaultValues', 'TEXT');
    AddColumnIfMissing('LLMPromptTemplates', 'ParentTemplate', 'TEXT');
    AddColumnIfMissing('LLMPromptTemplates', 'IncludeTemplates', 'TEXT');
    AddColumnIfMissing('LLMPromptTemplates', 'OutputFormat', 'TEXT DEFAULT ''text''');
    AddColumnIfMissing('LLMPromptTemplates', 'ValidationRegex', 'TEXT');
    AddColumnIfMissing('LLMPromptTemplates', 'Examples', 'TEXT');
    AddColumnIfMissing('LLMPromptTemplates', 'RecommendedConfig', 'TEXT');
    AddColumnIfMissing('LLMPromptTemplates', 'RecommendedModel', 'TEXT');
    AddColumnIfMissing('LLMPromptTemplates', 'MaxTokens', 'INTEGER DEFAULT 0');
    
  finally
    Query.Free;
  end;
end;

function TUniBaseManager.GetRetentionDays(const SettingKey: string;
  DefaultValue: Integer): Integer;
var
  RawValue: string;
begin
  Result := DefaultValue;
  if Assigned(FConfig) then
    RawValue := Trim(FConfig.GetConfig(SettingKey, IntToStr(DefaultValue)))
  else
    RawValue := IntToStr(DefaultValue);

  Result := StrToIntDef(RawValue, DefaultValue);
  if Result < 0 then
    Result := DefaultValue;
  if Result > 36500 then
    Result := 36500;
end;

function TUniBaseManager.TableExists(const TableName: string): Boolean;
var
  Query: TFDQuery;
begin
  Result := False;
  if not Assigned(FConfigDB) or not FConfigDB.Connected or (Trim(TableName) = '') then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConfigDB;
    Query.SQL.Text := Format('SELECT * FROM %s WHERE 1 = 0', [TableName]);
    try
      Query.Open;
      Result := True;
    except
      Result := False;
    end;
  finally
    Query.Free;
  end;
end;

function TUniBaseManager.TableHasColumn(const TableName, ColumnName: string): Boolean;
var
  Query: TFDQuery;
begin
  Result := False;
  if not TableExists(TableName) or (Trim(ColumnName) = '') then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConfigDB;
    Query.SQL.Text := Format('SELECT * FROM %s WHERE 1 = 0', [TableName]);
    try
      Query.Open;
      Result := Assigned(Query.FindField(ColumnName));
    except
      Result := False;
    end;
  finally
    Query.Free;
  end;
end;

function TUniBaseManager.ResolveTimeColumn(const TableName, Preferred,
  Fallback: string): string;
begin
  Result := '';
  if (Preferred <> '') and TableHasColumn(TableName, Preferred) then
    Exit(Preferred);
  if (Fallback <> '') and TableHasColumn(TableName, Fallback) then
    Exit(Fallback);
end;

procedure TUniBaseManager.ArchiveAndTrimTable(const TableName, TimeColumn: string;
  DaysToKeep: Integer);
var
  Query: TFDQuery;
  ArchiveTable: string;
  CutoffIso: string;
begin
  if (DaysToKeep = 0) or not TableExists(TableName) or (TimeColumn = '') then
    Exit;

  ArchiveTable := TableName + '_Archive';
  CutoffIso := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', IncDay(Now, -DaysToKeep));

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConfigDB;

    Query.SQL.Text := Format(
      'CREATE TABLE IF NOT EXISTS %s AS SELECT * FROM %s WHERE 1 = 0',
      [ArchiveTable, TableName]);
    Query.ExecSQL;

    Query.SQL.Text := Format(
      'INSERT INTO %s SELECT * FROM %s WHERE %s < :CutoffTime',
      [ArchiveTable, TableName, TimeColumn]);
    Query.ParamByName('CutoffTime').AsString := CutoffIso;
    Query.ExecSQL;

    Query.SQL.Text := Format(
      'DELETE FROM %s WHERE %s < :CutoffTime',
      [TableName, TimeColumn]);
    Query.ParamByName('CutoffTime').AsString := CutoffIso;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

procedure TUniBaseManager.RunOperationalRetention;
const
  KEY_LAST_RUN = 'Maintenance.Retention.LastRunDate';
  KEY_LOGS_DAYS = 'Maintenance.Retention.LogsDays';
  KEY_LLMCALLS_DAYS = 'Maintenance.Retention.LLMCallsDays';
  KEY_EXCEPTION_DAYS = 'Maintenance.Retention.ExceptionReportsDays';
  DEFAULT_LOGS_DAYS = 30;
  DEFAULT_LLMCALLS_DAYS = 90;
  DEFAULT_EXCEPTION_DAYS = 180;
var
  TodayTag: string;
begin
  if not Assigned(FConfigDB) or not FConfigDB.Connected then
    Exit;

  TodayTag := FormatDateTime('yyyy-mm-dd', Date);
  if Assigned(FConfig) and SameText(Trim(FConfig.GetConfig(KEY_LAST_RUN, '')), TodayTag) then
    Exit;

  try
    ArchiveAndTrimTable('Logs',
      ResolveTimeColumn('Logs', 'LogTime', 'CreatedAt'),
      GetRetentionDays(KEY_LOGS_DAYS, DEFAULT_LOGS_DAYS));
    ArchiveAndTrimTable('LLMCalls',
      ResolveTimeColumn('LLMCalls', 'CallTime', 'RequestTime'),
      GetRetentionDays(KEY_LLMCALLS_DAYS, DEFAULT_LLMCALLS_DAYS));
    ArchiveAndTrimTable('ExceptionReports',
      ResolveTimeColumn('ExceptionReports', 'OccurredAt', 'ReportTime'),
      GetRetentionDays(KEY_EXCEPTION_DAYS, DEFAULT_EXCEPTION_DAYS));
  except
    on E: Exception do
      if Assigned(FLogger) then
        FLogger.Warn('Operational retention failed: ' + E.Message, 'UniBase.Manager');
  end;

  if Assigned(FConfig) then
    FConfig.SetConfig(KEY_LAST_RUN, TodayTag);
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
  Query: TFDQuery;
  ScriptSQL, Stmt, Current: string;
  Statements: TList<string>;
  InString: Boolean;
  C: Char;
  J: Integer;
begin
  Result := False;
  
  if not TFile.Exists(ScriptPath) then
  begin
    FLastError := 'Migration script not found: ' + ScriptPath;
    Exit;
  end;
  
  try
    ScriptSQL := TFile.ReadAllText(ScriptPath, TEncoding.UTF8);
    
    // Split SQL by semicolons, respecting string literals
    Statements := TList<string>.Create;
    try
      Current := '';
      InString := False;
      for J := 1 to Length(ScriptSQL) do
      begin
        C := ScriptSQL[J];
        if C = '''' then
          InString := not InString;
        if (C = ';') and not InString then
        begin
          Current := Trim(Current);
          if (Current <> '') and not Current.StartsWith('--') then
            Statements.Add(Current);
          Current := '';
        end
        else
          Current := Current + C;
      end;
      Current := Trim(Current);
      if (Current <> '') and not Current.StartsWith('--') then
        Statements.Add(Current);
      
      Query := TFDQuery.Create(nil);
      try
        Query.Connection := FConfigDB;
        // Disable parameter parsing to avoid issues with :name patterns in string literals
        Query.ResourceOptions.ParamCreate := False;
        
        for Stmt in Statements do
        begin
          if Trim(Stmt) <> '' then
          begin
            Query.SQL.Text := Stmt;
            Query.ExecSQL;
          end;
        end;
        Result := True;
      finally
        Query.Free;
      end;
    finally
      Statements.Free;
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
    
    // Use ISO8601 format for SQLite datetime compatibility
    Query.SQL.Text := 'UPDATE SchemaInfo SET Value = :NowTime WHERE Key = ''LastUpgrade''';
    Query.ParamByName('NowTime').AsString := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now);
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
var
  AppName: string;
begin
  Result := '';
  
  // 应用名约定：使用 EXE 文件名（不含扩展）
  AppName := ChangeFileExt(ExtractFileName(ParamStr(0)), '');
  if AppName = '' then
    AppName := 'UniBase';
  
  {$IFDEF MSWINDOWS}
  if SHGetFolderPath(0, CSIDL_APPDATA, 0, 0, @Path) = S_OK then
  begin
    Result := TPath.Combine(Path, AppName);
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
  // 非 Windows 平台：使用 ~/.{AppName}
  Result := TPath.Combine(TPath.GetHomePath, '.' + AppName.ToLower);
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
