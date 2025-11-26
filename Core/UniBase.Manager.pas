{ ============================================================================
  UniBase.Manager - 核心管理器
  
  版本: 0.3
  说明: UniBase 框架的核心管理器，提供统一的初始化和资源管理
  线程安全: 初始化/清理方法仅限主线程调用
  ============================================================================ }

unit UniBase.Manager;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.SyncObjs,
  System.Generics.Collections,
  FireDAC.Comp.Client,
  FireDAC.Stan.Def,
  FireDAC.Stan.Async,
  FireDAC.DApt,
  FireDAC.Stan.ExprFuncs,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  UniBase.Types;

const
  UNIBASE_VERSION = '0.3';
  DEFAULT_CONFIGDB_NAME = 'config.db';
  ROOT_TXT_NAME = 'root.txt';

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
    
    // 内部方法
    function FindRootPath: string;
    function ReadRootTxt(const FilePath: string): string;
    function WriteRootTxt(const FilePath, RootPath: string): Boolean;
    function CreateRootTxt(out FilePath: string): Boolean;
    function ConnectToDatabase(const DBPath: string): Boolean;
    function ValidateSchema: Boolean;
    function CreateSchema: Boolean;
    function GetExeDir: string;
    function GetAppDataDir: string;
    function CheckWritePermission(const Path: string): Boolean;
    
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
    /// 清理资源
    /// </summary>
    procedure Finalize;
    
    // ========================================
    // 健康检查
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
/// 获取全局 UniBase 单例
/// </summary>
function UniBase: TUniBaseManager;

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
  FireDAC.Comp.Script;

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
    if not ValidateSchema then
    begin
      if not CreateSchema then
      begin
        ErrorMsg := Format('[%d] %s: %s', [Ord(FInitErrorCode),
          InitErrorCodeToStr(FInitErrorCode), FLastError]);
        Exit;
      end;
    end;
    
    // 6. 加载默认配置
    // 从数据库加载当前语言和主题（后续由 Config 模块实现）
    
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
    // 读取失败，返回空
  end;
end;

function TUniBaseManager.WriteRootTxt(const FilePath, RootPath: string): Boolean;
begin
  Result := False;
  try
    TFile.WriteAllText(FilePath, RootPath, TEncoding.UTF8);
    Result := True;
  except
    // 写入失败
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
    end;
    
  finally
    Query.Free;
  end;
end;

function TUniBaseManager.CreateSchema: Boolean;
var
  Script: TFDScript;
  SchemaSQL: string;
begin
  Result := False;
  
  if not Assigned(FConfigDB) or not FConfigDB.Connected then
    Exit;
    
  // Tier 0 Schema SQL（内嵌，避免依赖外部文件）
  SchemaSQL :=
    'CREATE TABLE IF NOT EXISTS SchemaInfo (' +
    '  Key TEXT PRIMARY KEY,' +
    '  Value TEXT' +
    ');' +
    'INSERT OR REPLACE INTO SchemaInfo VALUES (''SchemaVersion'', ''0.3'');' +
    'INSERT OR REPLACE INTO SchemaInfo VALUES (''CreatedAt'', datetime(''now''));' +
    'INSERT OR REPLACE INTO SchemaInfo VALUES (''LastUpgrade'', datetime(''now''));' +
    
    'CREATE TABLE IF NOT EXISTS ProjectInfo (' +
    '  Key TEXT PRIMARY KEY,' +
    '  Value TEXT' +
    ');' +
    'INSERT OR REPLACE INTO ProjectInfo VALUES (''ProjectName'', ''MyApp'');' +
    'INSERT OR REPLACE INTO ProjectInfo VALUES (''ProjectVersion'', ''1.0.0'');' +
    'INSERT OR REPLACE INTO ProjectInfo VALUES (''ProjectDescription'', '''');' +
    'INSERT OR REPLACE INTO ProjectInfo VALUES (''ProjectAuthor'', '''');' +
    'INSERT OR REPLACE INTO ProjectInfo VALUES (''ProjectWebsite'', '''');' +
    
    'CREATE TABLE IF NOT EXISTS Settings (' +
    '  Key TEXT PRIMARY KEY,' +
    '  Value TEXT,' +
    '  ValueType TEXT DEFAULT ''String'',' +
    '  Category TEXT DEFAULT ''General'',' +
    '  Description TEXT,' +
    '  IsEncrypted INTEGER DEFAULT 0' +
    ');' +
    'INSERT OR REPLACE INTO Settings (Key, Value, ValueType, Category, Description) ' +
    '  VALUES (''App.Language'', ''en-US'', ''String'', ''General'', ''Current language'');' +
    'INSERT OR REPLACE INTO Settings (Key, Value, ValueType, Category, Description) ' +
    '  VALUES (''App.DebugMode'', ''False'', ''Boolean'', ''General'', ''Debug mode enabled'');' +
    'INSERT OR REPLACE INTO Settings (Key, Value, ValueType, Category, Description) ' +
    '  VALUES (''App.Theme'', ''Windows11'', ''String'', ''UI'', ''Current theme'');' +
    
    'CREATE TABLE IF NOT EXISTS FormStates (' +
    '  FormName TEXT PRIMARY KEY,' +
    '  Left INTEGER,' +
    '  Top INTEGER,' +
    '  Width INTEGER,' +
    '  Height INTEGER,' +
    '  WindowState INTEGER DEFAULT 0,' +
    '  MonitorIndex INTEGER DEFAULT 0,' +
    '  Extra TEXT' +
    ');' +
    
    'CREATE TABLE IF NOT EXISTS Languages (' +
    '  LangCode TEXT PRIMARY KEY,' +
    '  LangName TEXT NOT NULL,' +
    '  NativeName TEXT,' +
    '  FlagIcon TEXT,' +
    '  IsEnabled INTEGER DEFAULT 1,' +
    '  IsDefault INTEGER DEFAULT 0,' +
    '  SortOrder INTEGER DEFAULT 0' +
    ');' +
    'INSERT OR REPLACE INTO Languages VALUES (''en-US'', ''English'', ''English'', ''us.png'', 1, 1, 0);' +
    'INSERT OR REPLACE INTO Languages VALUES (''zh-CN'', ''Chinese (Simplified)'', ''简体中文'', ''cn.png'', 1, 0, 1);' +
    
    'CREATE TABLE IF NOT EXISTS I18nTexts (' +
    '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  SourceText TEXT NOT NULL,' +
    '  LangCode TEXT NOT NULL,' +
    '  TranslatedText TEXT,' +
    '  PluralForm TEXT,' +
    '  Context TEXT,' +
    '  LastUsedTime TEXT,' +
    '  IsAutoTranslated INTEGER DEFAULT 0,' +
    '  IsVerified INTEGER DEFAULT 0,' +
    '  UNIQUE(SourceText, LangCode)' +
    ');' +
    'CREATE INDEX IF NOT EXISTS idx_i18n_lang ON I18nTexts(LangCode);' +
    'CREATE INDEX IF NOT EXISTS idx_i18n_source ON I18nTexts(SourceText);' +
    'INSERT OR REPLACE INTO I18nTexts (SourceText, LangCode, TranslatedText, IsVerified) ' +
    '  VALUES (''Welcome'', ''zh-CN'', ''欢迎'', 1);' +
    'INSERT OR REPLACE INTO I18nTexts (SourceText, LangCode, TranslatedText, IsVerified) ' +
    '  VALUES (''Save'', ''zh-CN'', ''保存'', 1);' +
    'INSERT OR REPLACE INTO I18nTexts (SourceText, LangCode, TranslatedText, IsVerified) ' +
    '  VALUES (''Cancel'', ''zh-CN'', ''取消'', 1);' +
    'INSERT OR REPLACE INTO I18nTexts (SourceText, LangCode, TranslatedText, IsVerified) ' +
    '  VALUES (''OK'', ''zh-CN'', ''确定'', 1);' +
    'INSERT OR REPLACE INTO I18nTexts (SourceText, LangCode, TranslatedText, IsVerified) ' +
    '  VALUES (''Error'', ''zh-CN'', ''错误'', 1);';

  Script := TFDScript.Create(nil);
  try
    Script.Connection := FConfigDB;
    Script.SQLScripts.Add;
    Script.SQLScripts[0].SQL.Text := SchemaSQL;
    
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
  Result.IsHealthy := False;
  Result.ConfigDBOk := False;
  Result.AssetsDirOk := False;
  Result.LLMConnectionOk := False;
  SetLength(Result.Messages, 0);
  
  // 检查初始化状态
  if not FIsInitialized then
  begin
    Result.AddMessage('UniBase not initialized');
    Exit;
  end;
  
  // 检查数据库连接
  if Assigned(FConfigDB) and FConfigDB.Connected then
  begin
    Result.ConfigDBOk := True;
    Result.AddMessage('ConfigDB: OK');
  end
  else
  begin
    Result.AddMessage('ConfigDB: Not connected');
  end;
  
  // 检查 assets 目录
  if TDirectory.Exists(TPath.Combine(FRootPath, 'assets')) then
  begin
    Result.AssetsDirOk := True;
    Result.AddMessage('Assets directory: OK');
  end
  else
  begin
    Result.AddMessage('Assets directory: Not found (optional)');
    Result.AssetsDirOk := True; // assets 是可选的
  end;
  
  // LLM 检查（Phase 2）
  Result.LLMConnectionOk := False;
  Result.AddMessage('LLM: Not configured (Phase 2)');
  
  // 综合判断
  Result.IsHealthy := Result.ConfigDBOk;
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

initialization
  GUniBaseLock := TObject.Create;

finalization
  FreeAndNil(GUniBaseManager);
  FreeAndNil(GUniBaseLock);

end.
