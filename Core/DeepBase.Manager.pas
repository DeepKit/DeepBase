{ ============================================================================
  DeepBase.Manager - Core Manager
  
  Version: 0.3
  Description: Core manager of DeepBase framework providing unified
               initialization and resource management.
  Thread Safety: Initialize/Finalize methods should only be called from
                 the main thread.
  ============================================================================ }

unit DeepBase.Manager;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.SyncObjs,
  System.Threading,  // BUG-007 FIX: Added for TTask.Run
  System.Generics.Collections,
  DeepBase.Types,
  DeepBase.Consts,
  DeepBase.Interfaces,
  DeepBase.Config,
  DeepBase.i18n,
  DeepBase.Theme,
  DeepBase.Logging,
  DeepBase.Security,
  DeepBase.Plugin,
  DeepBase.PluginManager,
  DeepBase.FormState,
  DeepBase.MRU,
  DeepBase.Hotkeys,
  DeepBase.Storage.Interfaces;

const
  // FR-001 fix: alias to the canonical version constant in DeepBase.Consts
  // so framework code does not duplicate or drift from the single source.
  DeepBase_VERSION = DeepBase_VERSION_STRING;
  CONFIG_DB_SUFFIX = 'Config.db';
  DATA_DB_SUFFIX = 'Data.db';
  ROOT_TXT_NAME = 'root.txt';
  
  // R-004: Schema ��֤����ĺ��ı�
  REQUIRED_CORE_TABLES: array[0..5] of string = (
    'SchemaInfo', 'ProjectInfo', 'Settings', 'FormStates', 'Languages', 'I18nTexts'
  );
  
  /// <summary>
  /// Schema version compatibility error code
  /// </summary>
  ecSchemaVersionMismatch = TInitErrorCode(10);

type
  TDeepBaseManager = class;
  TManagerConnectionFactory = function(const DBPath: string): TObject;
  TManagerConnectionIsConnected = function(AConnection: TObject): Boolean;
  TManagerConnectionCloser = procedure(AConnection: TObject);

  /// <summary>
  /// DeepBase ���Ĺ�����
  /// </summary>
  TDeepBaseManager = class(TComponent)
  private
    // ����״̬
    FRootPath: string;
    FConfigDBPath: string;
    FConfigDB: TObject;
    FStorage: IManagerStorage;
    FIsInitialized: Boolean;
    FLastError: string;
    FInitErrorCode: TInitErrorCode;
    
    // ��ǰ����
    FCurrentLanguage: string;
    FCurrentTheme: string;
    
    // �߳�ͬ��
    FLock: TObject;
    
    // �ӳٳ�ʼ���ص�
    FReadyCallbacks: TList<TProc>;
    FReadyFired: Boolean;
    
    // �¼�
    FOnLanguageChanged: TNotifyEvent;
    FOnThemeChanged: TNotifyEvent;
    FOnConfigChanged: TConfigChangedEvent;
    
    // ����ģ��
    FConfig: TDeepBaseConfig;
    FI18n: TDeepBaseI18n;
    FTheme: TDeepBaseTheme;
    FLogger: TDeepBaseLogger;
    FSecurity: TDeepBaseSecurity;
    FPluginManager: TDeepBasePluginManager;
    FFormState: TDeepBaseFormState;
    FMRU: TDeepBaseMRU;
    FHotkeys: TDeepBaseHotkeys;
    class var FStorageFactory: TFunc<TObject, IManagerStorage>;
    class var FConnectionFactory: TManagerConnectionFactory;
    class var FConnectionIsConnected: TManagerConnectionIsConnected;
    class var FConnectionCloser: TManagerConnectionCloser;
    
    // �ڲ�����
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
    function CreatePluginContext: IDeepBasePluginContext;
    class function CreateStorageFromConnection(
      AConnection: TObject): IManagerStorage; static;
    class function IsConnectionAlive(AConnection: TObject): Boolean; static;
    class procedure CloseConnection(var AConnection: TObject); static;
    
    // InitializeEx ����������R-001 �ع���
    function DoFindRootPath(out ErrorMsg: string): Boolean;
    function DoLocateConfigDB(out ErrorMsg: string): Boolean;
    function DoConnectAndValidate(out ErrorMsg: string): Boolean;
    function FormatInitializationError(const Operation,
      ErrorMsg: string): string;
    procedure RaiseInitializationError(const Operation,
      ErrorMsg: string);
    
    // �¼������� (������ģ��ص�)
    procedure HandleConfigChanged(Sender: TObject; const Key, OldValue, NewValue: string);
    procedure HandleLanguageChanged(Sender: TObject);
    procedure HandleThemeChanged(Sender: TObject);
    
    // ���� Setter
    procedure SetCurrentLanguage(const Value: string);
    procedure SetCurrentTheme(const Value: string);
    
  protected
    procedure DoLanguageChanged;
    procedure DoThemeChanged;
    procedure DoConfigChanged(const Key, OldValue, NewValue: string);
    
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    class procedure SetStorageFactory(
      const AFactory: TFunc<TObject, IManagerStorage>); static;
    class procedure SetConnectionAdapter(
      const AFactory: TManagerConnectionFactory;
      const AIsConnected: TManagerConnectionIsConnected;
      const ACloser: TManagerConnectionCloser); static;
    
    // ========================================
    // ��ʼ������
    // ========================================
    
    /// <summary>
    /// ��ʼ�� DeepBase�����̵߳��ã�
    /// Boolean ��ڣ�ʧ��ʱ���� False����ͨ�� LastError / InitErrorCode ��¶ԭ��
    /// </summary>
    function Initialize: Boolean;
    
    /// <summary>
    /// ��ʼ�� DeepBase��������ϸ������Ϣ
    /// Boolean ��ڣ�ʧ��ʱ���׳���ʼ���쳣�����÷�Ӧ��鷵��ֵ��
    /// </summary>
    function InitializeEx(out ErrorMsg: string): Boolean;
    
    /// <summary>
    /// ʹ��ָ�����ݿ�·����ʼ����֧�� :memory: ���ڲ��ԣ�
    /// Boolean ��ڣ�ʧ��ʱ���� False����ͨ�� LastError / InitErrorCode ��¶ԭ��
    /// </summary>
    function InitializeWithDB(const DBPath: string): Boolean;

    /// <summary>
    /// �쳣��ڣ���ʼ��ʧ��ʱ�׳� EInitializationException��
    /// </summary>
    procedure InitializeOrRaise;

    /// <summary>
    /// �쳣��ڣ�ʹ��ָ�����ݿ�·����ʼ����ʧ��ʱ�׳� EInitializationException��
    /// </summary>
    procedure InitializeWithDBOrRaise(const DBPath: string);
    
    /// <summary>
    /// ע���ʼ����ɺ�Ļص�������ѳ�ʼ��������ִ�С�
    /// ���ڽ������ FormShow �з��� DeepBase ����ʱ����δ���������⡣
    /// </summary>
    /// <example>
    /// procedure TMyForm.FormShow(Sender: TObject);
    /// begin
    ///   DeepBase.WhenReady(procedure
    ///   begin
    ///     LoadProviders;  // ��ȫ����ʱ DeepBase ����ȫ��ʼ��
    ///   end);
    /// end;
    /// </example>
    procedure WhenReady(ACallback: TProc);
    
    /// <summary>
    /// ����������ע��� Ready �ص����� Application.Run ǰ���ã�
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
    /// ִ�н������
    /// </summary>
    function HealthCheck: THealthCheckResult;
    
    // ========================================
    // ��Ŀ��Ϣ
    // ========================================
    
    /// <summary>
    /// ��ȡ��Ŀ��Ϣ
    /// </summary>
    function GetProjectInfo(const Key: string): string;
    
    /// <summary>
    /// ������Ŀ��Ϣ
    /// </summary>
    procedure SetProjectInfo(const Key, Value: string);
    
    // ========================================
    // ��Դ·��
    // ========================================
    
    /// <summary>
    /// ��ȡ��Դ����·��
    /// </summary>
    function GetAssetPath(const RelativePath: string): string;
    
    // ========================================
    // ����
    // ========================================
    
    /// <summary>���ݿ����ӣ�����ģ��ʹ�ã�</summary>
    property ConfigDB: TObject read FConfigDB;
    
    // ��ģ����ʵ�
    property Config: TDeepBaseConfig read FConfig;
    property I18n: TDeepBaseI18n read FI18n;
    property Theme: TDeepBaseTheme read FTheme;
    property Logger: TDeepBaseLogger read FLogger;
    property Security: TDeepBaseSecurity read FSecurity;
    property PluginManager: TDeepBasePluginManager read FPluginManager;
    property FormState: TDeepBaseFormState read FFormState;
    property MRU: TDeepBaseMRU read FMRU;
    property Hotkeys: TDeepBaseHotkeys read FHotkeys;
    
    /// <summary>��Ŀ��Ŀ¼</summary>
    property RootPath: string read FRootPath;
    
    /// <summary>�������ݿ�·��</summary>
    property ConfigDBPath: string read FConfigDBPath;
    
    /// <summary>�Ƿ��ѳ�ʼ��</summary>
    property IsInitialized: Boolean read FIsInitialized;
    
    /// <summary>���һ�δ�����Ϣ</summary>
    property LastError: string read FLastError;
    
    /// <summary>��ʼ��������</summary>
    property InitErrorCode: TInitErrorCode read FInitErrorCode;
    
    /// <summary>��ǰ����</summary>
    property CurrentLanguage: string read FCurrentLanguage write SetCurrentLanguage;
    
    /// <summary>��ǰ����</summary>
    property CurrentTheme: string read FCurrentTheme write SetCurrentTheme;
    
    /// <summary>ͬ�������󣨹���ģ��ʹ�ã�</summary>
    property Lock: TObject read FLock;
    
    // ========================================
    // �¼�
    // ========================================
    
    property OnLanguageChanged: TNotifyEvent read FOnLanguageChanged write FOnLanguageChanged;
    property OnThemeChanged: TNotifyEvent read FOnThemeChanged write FOnThemeChanged;
    property OnConfigChanged: TConfigChangedEvent read FOnConfigChanged write FOnConfigChanged;
  end;

/// <summary>
/// Get global DeepBase singleton
/// </summary>
function DeepBase: TDeepBaseManager;

/// <summary>
/// Set the global DeepBase instance (for testing/dependency injection only)
/// Passing nil will reset to default lazy-initialization behavior.
/// IMPORTANT: Must be called before any DeepBase() call, or after explicit cleanup.
/// </summary>
procedure SetDeepBaseInstance(AInstance: TDeepBaseManager);

// ============================================================================
// Direct Module Access Functions (Convenience Shortcuts)
// These provide direct access to sub-modules without calling DeepBase() first.
// Usage:
//   uses DeepBase.Manager;
//   Value := UBConfig.GetConfig('Key', 'Default');
//   UBI18n.Translate('Hello');
// ============================================================================

/// <summary>Direct access to Config module</summary>
function UBConfig: TDeepBaseConfig;
/// <summary>Direct access to I18n module</summary>
function UBI18n: TDeepBaseI18n;
/// <summary>Direct access to Theme module</summary>
function UBTheme: TDeepBaseTheme;
/// <summary>Direct access to Logger module</summary>
function UBLogger: TDeepBaseLogger;
/// <summary>Direct access to Security module</summary>
function UBSecurity: TDeepBaseSecurity;
/// <summary>Direct access to PluginManager module</summary>
function UBPlugins: TDeepBasePluginManager;
/// <summary>Direct access to FormState module</summary>
function UBFormState: TDeepBaseFormState;
/// <summary>Direct access to MRU module</summary>
function UBMRU: TDeepBaseMRU;
/// <summary>Direct access to Hotkeys module</summary>
function UBHotkeys: TDeepBaseHotkeys;

implementation

uses
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  Winapi.ShlObj,
  {$ENDIF}
  DeepBase.Manager.Schema,
  DeepBase.Manager.Operational,
  DeepBase.Exception,
  DeepBase.Exceptions;

var
  GDeepBaseManager: TDeepBaseManager = nil;
  GDeepBaseLock: TObject = nil;

function DeepBase: TDeepBaseManager;
begin
  if GDeepBaseManager = nil then
  begin
    TMonitor.Enter(GDeepBaseLock);
    try
      if GDeepBaseManager = nil then
        GDeepBaseManager := TDeepBaseManager.Create(nil);
    finally
      TMonitor.Exit(GDeepBaseLock);
    end;
  end;
  Result := GDeepBaseManager;
end;

procedure SetDeepBaseInstance(AInstance: TDeepBaseManager);
begin
  TMonitor.Enter(GDeepBaseLock);
  try
    // Free existing instance if it was auto-created (not externally owned)
    if (GDeepBaseManager <> nil) and (GDeepBaseManager <> AInstance) then
    begin
      // Only free if no owner (auto-created by DeepBase function)
      if GDeepBaseManager.Owner = nil then
        FreeAndNil(GDeepBaseManager);
    end;
    GDeepBaseManager := AInstance;
  finally
    TMonitor.Exit(GDeepBaseLock);
  end;
end;

function UBConfig: TDeepBaseConfig;
begin
  Result := DeepBase.Config;
end;

function UBI18n: TDeepBaseI18n;
begin
  Result := DeepBase.I18n;
end;

function UBTheme: TDeepBaseTheme;
begin
  Result := DeepBase.Theme;
end;

function UBLogger: TDeepBaseLogger;
begin
  Result := DeepBase.Logger;
end;

function UBSecurity: TDeepBaseSecurity;
begin
  Result := DeepBase.Security;
end;

function UBPlugins: TDeepBasePluginManager;
begin
  Result := DeepBase.PluginManager;
end;

function UBFormState: TDeepBaseFormState;
begin
  Result := DeepBase.FormState;
end;

function UBMRU: TDeepBaseMRU;
begin
  Result := DeepBase.MRU;
end;

function UBHotkeys: TDeepBaseHotkeys;
begin
  Result := DeepBase.Hotkeys;
end;

{ TDeepBaseManager }

class procedure TDeepBaseManager.SetStorageFactory(
  const AFactory: TFunc<TObject, IManagerStorage>);
begin
  FStorageFactory := AFactory;
end;

class procedure TDeepBaseManager.SetConnectionAdapter(
  const AFactory: TManagerConnectionFactory;
  const AIsConnected: TManagerConnectionIsConnected;
  const ACloser: TManagerConnectionCloser);
begin
  FConnectionFactory := AFactory;
  FConnectionIsConnected := AIsConnected;
  FConnectionCloser := ACloser;
end;

class function TDeepBaseManager.CreateStorageFromConnection(
  AConnection: TObject): IManagerStorage;
begin
  Result := nil;
  if Assigned(AConnection) and Assigned(FStorageFactory) then
    Result := FStorageFactory(AConnection);
end;

class function TDeepBaseManager.IsConnectionAlive(AConnection: TObject): Boolean;
begin
  if not Assigned(AConnection) then
    Exit(False);

  if Assigned(FConnectionIsConnected) then
    Exit(FConnectionIsConnected(AConnection));

  Result := True;
end;

class procedure TDeepBaseManager.CloseConnection(var AConnection: TObject);
var
  Connection: TObject;
begin
  Connection := AConnection;
  AConnection := nil;
  if not Assigned(Connection) then
    Exit;

  if Assigned(FConnectionCloser) then
    FConnectionCloser(Connection)
  else
    Connection.Free;
end;

constructor TDeepBaseManager.Create(AOwner: TComponent);
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
  FStorage := nil;
end;

destructor TDeepBaseManager.Destroy;
begin
  Finalize;
  FreeAndNil(FReadyCallbacks);
  FreeAndNil(FLock);
  inherited;
end;

function TDeepBaseManager.Initialize: Boolean;
var
  Dummy: string;
begin
  Result := InitializeEx(Dummy);
end;

function TDeepBaseManager.DoFindRootPath(out ErrorMsg: string): Boolean;
var
  RootTxtPath: string;
begin
  Result := False;
  ErrorMsg := '';
  
  // ���� root.txt
  FRootPath := FindRootPath;
  
  if FRootPath = '' then
  begin
    // ���Դ��� root.txt
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
  
  // ��֤��Ŀ¼
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

function TDeepBaseManager.DoLocateConfigDB(out ErrorMsg: string): Boolean;
var
  AppName: string;
  ConfigFileName: string;
  AppDataDir: string;
  FallbackPath: string;
begin
  Result := False;
  ErrorMsg := '';
  
  // ���� ConfigDB �ļ�����{AppName}Config.db
  AppName := ChangeFileExt(ExtractFileName(ParamStr(0)), '');
  if AppName = '' then
    AppName := 'DeepBase'; // ���ף������Ӧ����

  // Avoid doubled "Config" (e.g. DeepShineConfig.exe → DeepShineConfigConfig.db)
  if AppName.EndsWith('Config', True) then
    ConfigFileName := AppName + '.db'
  else
    ConfigFileName := AppName + CONFIG_DB_SUFFIX;

  // ������ RootPath �²��� {AppName}Config.db
  FConfigDBPath := TPath.Combine(FRootPath, ConfigFileName);

  if not TFile.Exists(FConfigDBPath) then
  begin
    // ����λ�ã�%APPDATA%/{AppName}/{AppName}Config.db
    AppDataDir := GetAppDataDir;
    if AppDataDir <> '' then
    begin
      FallbackPath := TPath.Combine(AppDataDir, ConfigFileName);
      if TFile.Exists(FallbackPath) then
      begin
        FConfigDBPath := FallbackPath;
      end;
      // �������λ�ö������ڣ����� FConfigDBPath ָ�� RootPath �µ�·��
      // ConnectToDatabase ��ʹ�� OpenMode=CreateUTF8 �Զ��������ݿ��ļ�
    end;
    // ���ٱ������� ConnectToDatabase �Զ��������ݿ�
  end;
  
  Result := True;
end;

function TDeepBaseManager.DoConnectAndValidate(out ErrorMsg: string): Boolean;
begin
  Result := False;
  ErrorMsg := '';
  
  // �������ݿ�
  if not ConnectToDatabase(FConfigDBPath) then
  begin
    ErrorMsg := Format('[%d] %s: %s', [Ord(FInitErrorCode),
      InitErrorCodeToStr(FInitErrorCode), FLastError]);
    Exit;
  end;
  
  // ��֤/���� Schema��ʹ�� IF NOT EXISTS ȷ�����б����ڣ�
  if not CreateSchema then
  begin
    ErrorMsg := Format('[%d] %s: %s', [Ord(FInitErrorCode),
      InitErrorCodeToStr(FInitErrorCode), FLastError]);
    Exit;
  end;
  
  Result := True;
end;

function TDeepBaseManager.FormatInitializationError(const Operation,
  ErrorMsg: string): string;
var
  Detail: string;
begin
  Detail := ErrorMsg;
  if Detail = '' then
    Detail := FLastError;
  if Detail = '' then
    Detail := InitErrorCodeToStr(FInitErrorCode);

  Result := Format('%s failed [%d] %s: %s', [
    Operation,
    Ord(FInitErrorCode),
    InitErrorCodeToStr(FInitErrorCode),
    Detail
  ]);
end;

procedure TDeepBaseManager.RaiseInitializationError(const Operation,
  ErrorMsg: string);
begin
  raise EInitializationException.Create(
    FormatInitializationError(Operation, ErrorMsg),
    Ord(FInitErrorCode),
    'DeepBase.Manager.' + Operation);
end;

function TDeepBaseManager.InitializeEx(out ErrorMsg: string): Boolean;
begin
  Result := False;
  ErrorMsg := '';
  
  // BASIC-018 fix: protect against concurrent initialization. Finalize
  // already uses FLock; initialization must use the same lock so a
  // racing second thread sees FIsInitialized = True after the first
  // thread completes, rather than duplicating module creation.
  TMonitor.Enter(FLock);
  try
    if FIsInitialized then
    begin
      Result := True;
      Exit;
    end;
    
    try
      // 1. Find and verify root directory
      if not DoFindRootPath(ErrorMsg) then
        Exit;
      
      // 2. Locate config database
      if not DoLocateConfigDB(ErrorMsg) then
        Exit;
      
      // 3. Connect and validate schema
      if not DoConnectAndValidate(ErrorMsg) then
        Exit;
      
      // 4. Initialize modules
      InitializeModules;

      // 5. Register exception handler callbacks
      TDeepBaseExceptionHandler.SetManagerCallbacks(
        function: Boolean begin Result := FIsInitialized end,
        function: TDeepBaseLogger begin Result := FLogger end,
        function: TObject begin Result := FConfigDB end);

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
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TDeepBaseManager.InitializeOrRaise;
var
  ErrorMsg: string;
begin
  if not InitializeEx(ErrorMsg) then
    RaiseInitializationError('Initialize', ErrorMsg);
end;

function TDeepBaseManager.InitializeWithDB(const DBPath: string): Boolean;
begin
  Result := False;
  
  // BASIC-018 fix: same lock as InitializeEx/Finalize.
  TMonitor.Enter(FLock);
  try
    if FIsInitialized then
    begin
      Result := True;
      Exit;
    end;
    
    try
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

      TDeepBaseExceptionHandler.SetManagerCallbacks(
        function: Boolean begin Result := FIsInitialized end,
        function: TDeepBaseLogger begin Result := FLogger end,
        function: TObject begin Result := FConfigDB end);

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
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TDeepBaseManager.InitializeWithDBOrRaise(const DBPath: string);
begin
  if not InitializeWithDB(DBPath) then
    RaiseInitializationError('InitializeWithDB', '');
end;

procedure TDeepBaseManager.Finalize;
begin
  if not FIsInitialized then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    FinalizeModules;

    CloseConnection(FConfigDB);
    FStorage := nil;
    
    FIsInitialized := False;
    FReadyFired := False;
    FRootPath := '';
    FConfigDBPath := '';
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TDeepBaseManager.WhenReady(ACallback: TProc);
begin
  if not Assigned(ACallback) then
    Exit;
    
  // ����Ѿ������� Ready��ʹ���첽ִ�б���Ƕ��������������
  // BUG-007 FIX: Use TTask.Run to prevent deadlock when callback calls DeepBase functions
  if FReadyFired then
  begin
    TTask.Run(procedure
    begin
      try
        ACallback();
      except
        on E: Exception do
          if Assigned(FLogger) then
            FLogger.Error('WhenReady callback failed: ' + E.Message, 'DeepBase');
      end;
    end);
    Exit;
  end;
  
  // ���������еȴ�
  TMonitor.Enter(FLock);
  try
    FReadyCallbacks.Add(ACallback);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TDeepBaseManager.FireReadyCallbacks;
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
            FLogger.Error('Ready callback failed: ' + E.Message, 'DeepBase');
      end;
    end;
    FReadyCallbacks.Clear;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TDeepBaseManager.InitializeModules;
var
  I18nRef: TDeepBaseI18n;
  TranslateCallback: TTranslateCallback;
  ConfigStorage: IConfigStorage;
  I18nStorage: II18nStorage;
  ThemeStorage: IThemeStorage;
  SecurityStorage: ISecuritySecretStorage;
  FormStateStorage: IFormStateStorage;
  MRUStorage: IMRUStorage;
  HotkeyStorage: IHotkeyStorage;
begin
  // 1. Logger - create and register as global logger
  FLogger := TDeepBaseLogger.Create(FConfigDBPath);
  SetGlobalLogger(FLogger);  // Register with global Logger() function
  
  // 2. Config
  ConfigStorage := nil;
  if Assigned(FStorage) then
  begin
    try
      ConfigStorage := FStorage.CreateConfigStorage;
    except
      on E: Exception do
        FLogger.Warn('CreateConfigStorage failed: ' + E.Message, 'DeepBase.Manager');
    end;
  end;
  if Assigned(ConfigStorage) then
    FConfig := TDeepBaseConfig.Create(ConfigStorage, FLock)
  else
    FConfig := TDeepBaseConfig.Create(FConfigDB, FLock);
  FConfig.OnConfigChanged := HandleConfigChanged;
  
  // PERF-001: Ԥ�����û��棬�����״η���ʱ�������С��ѯ
  try
    FConfig.PreloadCache;
  except
    // Ԥ��ʧ�ܲ�Ӱ���������У����־�Ĭ���� DEBUG �����
    {$IFDEF DEBUG}
    OutputDebugString('DeepBase.Manager: PreloadCache failed');
    {$ENDIF}
  end;
  
  // 3. i18n
  I18nStorage := nil;
  if Assigned(FStorage) then
  begin
    try
      I18nStorage := FStorage.CreateI18nStorage;
    except
      on E: Exception do
        FLogger.Warn('CreateI18nStorage failed: ' + E.Message, 'DeepBase.Manager');
    end;
  end;
  if Assigned(I18nStorage) then
    FI18n := TDeepBaseI18n.Create(I18nStorage, FLock)
  else
    FI18n := TDeepBaseI18n.Create(FConfigDB, FLock);
  FI18n.OnLanguageChanged := HandleLanguageChanged;
  // Set global T() callback to decouple i18n from Manager
  I18nRef := FI18n;
  TranslateCallback := function(const Text: string): string
    begin
      Result := I18nRef.Translate(Text);
    end;
  SetGlobalTranslateCallback(TranslateCallback);
  
  // 4. Theme
  ThemeStorage := nil;
  if Assigned(FStorage) then
  begin
    try
      ThemeStorage := FStorage.CreateThemeStorage;
    except
      on E: Exception do
        FLogger.Warn('CreateThemeStorage failed: ' + E.Message, 'DeepBase.Manager');
    end;
  end;
  if Assigned(ThemeStorage) then
    FTheme := TDeepBaseTheme.Create(ThemeStorage, FLock)
  else
    FTheme := TDeepBaseTheme.Create(FConfigDB, FLock);
  FTheme.OnThemeChanged := HandleThemeChanged;
  
  // 5. Security (DPAPI encryption for secrets)
  SecurityStorage := nil;
  if Assigned(FStorage) then
  begin
    try
      SecurityStorage := FStorage.CreateSecuritySecretStorage;
    except
      on E: Exception do
        FLogger.Warn('CreateSecuritySecretStorage failed: ' + E.Message, 'DeepBase.Manager');
    end;
  end;
  if Assigned(SecurityStorage) then
    FSecurity := TDeepBaseSecurity.Create(SecurityStorage, FLock)
  else
    FSecurity := TDeepBaseSecurity.Create(FConfigDB, FLock);
  
  // Load Initial Settings
  FCurrentLanguage := FConfig.GetConfig(SConfigKeyLanguage, SDefaultLanguage);
  FI18n.CurrentLanguage := FCurrentLanguage;
  
  FCurrentTheme := FConfig.GetConfig(SConfigKeyTheme, SDefaultTheme);
  // Note: Theme application usually happens in VCL/FMX layer, Manager just holds data
  // But TDeepBaseTheme might apply it if linked to VCL
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
  FormStateStorage := nil;
  if Assigned(FStorage) then
  begin
    try
      FormStateStorage := FStorage.CreateFormStateStorage;
    except
      on E: Exception do
        FLogger.Warn('CreateFormStateStorage failed: ' + E.Message, 'DeepBase.Manager');
    end;
  end;
  if Assigned(FormStateStorage) then
    FFormState := TDeepBaseFormState.Create(FormStateStorage, FLock)
  else
    FFormState := TDeepBaseFormState.Create(FConfigDB, FLock);
  
  // 8. MRU - Most Recently Used tracking
  MRUStorage := nil;
  if Assigned(FStorage) then
  begin
    try
      MRUStorage := FStorage.CreateMRUStorage;
    except
      on E: Exception do
        FLogger.Warn('CreateMRUStorage failed: ' + E.Message, 'DeepBase.Manager');
    end;
  end;
  if Assigned(MRUStorage) then
    FMRU := TDeepBaseMRU.Create(MRUStorage, FLock)
  else
    FMRU := TDeepBaseMRU.Create(FConfigDB, FLock);
  
  // 9. Hotkeys - keyboard shortcut management
  HotkeyStorage := nil;
  if Assigned(FStorage) then
  begin
    try
      HotkeyStorage := FStorage.CreateHotkeyStorage;
    except
      on E: Exception do
        FLogger.Warn('CreateHotkeyStorage failed: ' + E.Message, 'DeepBase.Manager');
    end;
  end;
  if Assigned(HotkeyStorage) then
    FHotkeys := TDeepBaseHotkeys.Create(HotkeyStorage, FLock)
  else
    FHotkeys := TDeepBaseHotkeys.Create(FConfigDB, FLock);
  
  // 10. PluginManager - create and load plugins
  FPluginManager := TDeepBasePluginManager.Create(
    TPath.Combine(FRootPath, DEFAULT_PLUGINS_DIR),
    CreatePluginContext);
  // Load plugins after core modules are ready
  FPluginManager.LoadAllPlugins;
end;

function TDeepBaseManager.CreatePluginContext: IDeepBasePluginContext;
var
  ConfigRef: TDeepBaseConfig;
  I18nRef: TDeepBaseI18n;
  LoggerRef: TDeepBaseLogger;
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

procedure TDeepBaseManager.FinalizeModules;
begin
  // BASIC-020 fix: clear global translate callback BEFORE releasing FI18n,
  // so any late T('...') call after finalize does not access freed memory.
  SetGlobalTranslateCallback(nil);

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
    SetGlobalLogger(nil);
    FreeAndNil(FLogger);
  end;
end;

function TDeepBaseManager.FindRootPath: string;
var
  ExeDir, AppDataDir: string;
  RootTxtPath, ReadPath: string;
begin
  Result := '';
  
  // ���ȼ� 1: EXE ����Ŀ¼
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
  
  // ���ȼ� 2: APPDATA Ŀ¼
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

function TDeepBaseManager.ReadRootTxt(const FilePath: string): string;
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
      
      // ����Ƿ��� INI ��ʽ��չ
      if (Length(Line) > 0) and (Line[1] = '[') then
      begin
        // INI ��ʽ�� [Paths] ��չĿǰ��֧�֣�Ϊ���ּ���ֱ�ӷ��ؿ�·��
        Exit;
      end;
      
      // �򵥸�ʽ����һ����·��
      if TDirectory.Exists(Line) then
        Result := Line;
    end;
  except
    on E: Exception do
    begin
      // ��ȡʧ�ܣ���¼��־�󷵻ؿ�
      if Assigned(FLogger) then
        FLogger.Log('ReadRootTxt failed: ' + FilePath + ' - ' + E.Message, llWarn, 'Manager');
    end;
  end;
end;

function TDeepBaseManager.WriteRootTxt(const FilePath, RootPath: string): Boolean;
begin
  Result := False;
  try
    TFile.WriteAllText(FilePath, RootPath, TEncoding.UTF8);
    Result := True;
  except
    on E: Exception do
    begin
      // д��ʧ�ܣ���¼��־
      if Assigned(FLogger) then
        FLogger.Log('WriteRootTxt failed: ' + FilePath + ' - ' + E.Message, llWarn, 'Manager');
    end;
  end;
end;

function TDeepBaseManager.CreateRootTxt(out FilePath: string): Boolean;
var
  ExeDir, AppDataDir: string;
begin
  Result := False;
  FilePath := '';
  
  // ���ȳ��� EXE Ŀ¼
  ExeDir := GetExeDir;
  if CheckWritePermission(ExeDir) then
  begin
    FilePath := TPath.Combine(ExeDir, ROOT_TXT_NAME);
    Result := WriteRootTxt(FilePath, ExeDir);
    if Result then
      Exit;
  end;
  
  // ���˵� APPDATA
  AppDataDir := GetAppDataDir;
  if (AppDataDir <> '') and TDirectory.Exists(AppDataDir) then
  begin
    FilePath := TPath.Combine(AppDataDir, ROOT_TXT_NAME);
    Result := WriteRootTxt(FilePath, AppDataDir);
  end;
end;

function TDeepBaseManager.ConnectToDatabase(const DBPath: string): Boolean;
var
  Connection: TObject;
begin
  Result := False;

  try
    if not Assigned(FConnectionFactory) then
    begin
      FInitErrorCode := ecConfigDBNotFound;
      FLastError :=
        'No DB connection adapter registered. Include DeepBase.Persistence.Manager.FireDAC.';
      Exit;
    end;

    Connection := FConnectionFactory(DBPath);
    if not Assigned(Connection) then
    begin
      FInitErrorCode := ecConfigDBNotFound;
      FLastError := 'Connection adapter returned nil.';
      Exit;
    end;

    if not IsConnectionAlive(Connection) then
    begin
      CloseConnection(Connection);
      FInitErrorCode := ecConfigDBNotFound;
      FLastError := 'Connection adapter returned a disconnected connection.';
      Exit;
    end;

    CloseConnection(FConfigDB);
    FConfigDB := Connection;

    FStorage := nil;
    try
      FStorage := CreateStorageFromConnection(FConfigDB);
    except
      on E: Exception do
      begin
        FStorage := nil;
        if Assigned(FLogger) then
          FLogger.Warn('Manager storage factory failed: ' + E.Message, 'DeepBase.Manager');
      end;
    end;

    if not Assigned(FStorage) then
    begin
      CloseConnection(FConfigDB);
      FInitErrorCode := ecConfigDBCorrupted;
      FLastError :=
        'No manager storage factory registered. Include DeepBase.Persistence.Manager.FireDAC.';
      Exit;
    end;

    FInitErrorCode := ecSuccess;
    Result := True;
  except
    on E: Exception do
    begin
      FInitErrorCode := ecConfigDBNotFound;
      FLastError := 'Database connection error: ' + E.Message;
    end;
  end;
end;

function TDeepBaseManager.ValidateSchema: Boolean;
var
  ErrorCode: TInitErrorCode;
  ErrorMsg: string;
begin
  Result := TDeepBaseManagerSchema.ValidateSchema(FStorage,
    Assigned(FConfigDB) and IsConnectionAlive(FConfigDB), REQUIRED_CORE_TABLES,
    ErrorCode, ErrorMsg);
  if (not Result) and ((ErrorCode <> ecSuccess) or (ErrorMsg <> '')) then
  begin
    FInitErrorCode := ErrorCode;
    FLastError := ErrorMsg;
  end;
end;

function TDeepBaseManager.ValidateSchemaVersion: Boolean;
var
  ErrorCode: TInitErrorCode;
  ErrorMsg: string;
begin
  Result := TDeepBaseManagerSchema.ValidateSchemaVersion(FStorage,
    Assigned(FConfigDB) and IsConnectionAlive(FConfigDB), ErrorCode, ErrorMsg);
  if (not Result) and ((ErrorCode <> ecSuccess) or (ErrorMsg <> '')) then
  begin
    FInitErrorCode := ErrorCode;
    FLastError := ErrorMsg;
  end;
end;

function TDeepBaseManager.CreateSchema: Boolean;
var
  ErrorCode: TInitErrorCode;
  ErrorMsg: string;
begin
  Result := TDeepBaseManagerSchema.CreateSchema(FStorage,
    Assigned(FConfigDB) and IsConnectionAlive(FConfigDB), FLogger, ErrorCode,
    ErrorMsg);
  if Result then
    FInitErrorCode := ErrorCode
  else if (ErrorCode <> ecSuccess) or (ErrorMsg <> '') then
  begin
    FInitErrorCode := ErrorCode;
    FLastError := ErrorMsg;
  end;
end;

procedure TDeepBaseManager.EnsureSchemaColumns;
begin
  TDeepBaseManagerSchema.EnsureSchemaColumns(FStorage,
    Assigned(FConfigDB) and IsConnectionAlive(FConfigDB));
end;

function TDeepBaseManager.GetRetentionDays(const SettingKey: string;
  DefaultValue: Integer): Integer;
begin
  Result := TDeepBaseManagerOperational.GetRetentionDays(FConfig, SettingKey,
    DefaultValue);
end;

function TDeepBaseManager.TableExists(const TableName: string): Boolean;
begin
  Result := TDeepBaseManagerOperational.TableExists(FStorage,
    Assigned(FConfigDB) and IsConnectionAlive(FConfigDB), TableName);
end;

function TDeepBaseManager.TableHasColumn(const TableName, ColumnName: string): Boolean;
begin
  Result := TDeepBaseManagerOperational.TableHasColumn(FStorage,
    Assigned(FConfigDB) and IsConnectionAlive(FConfigDB), TableName,
    ColumnName);
end;

function TDeepBaseManager.ResolveTimeColumn(const TableName, Preferred,
  Fallback: string): string;
begin
  Result := TDeepBaseManagerOperational.ResolveTimeColumn(FStorage,
    Assigned(FConfigDB) and IsConnectionAlive(FConfigDB), TableName,
    Preferred, Fallback);
end;

procedure TDeepBaseManager.ArchiveAndTrimTable(const TableName, TimeColumn: string;
  DaysToKeep: Integer);
begin
  TDeepBaseManagerOperational.ArchiveAndTrimTable(FStorage,
    Assigned(FConfigDB) and IsConnectionAlive(FConfigDB), TableName,
    TimeColumn, DaysToKeep);
end;

procedure TDeepBaseManager.RunOperationalRetention;
begin
  TDeepBaseManagerOperational.RunRetention(FStorage,
    Assigned(FConfigDB) and IsConnectionAlive(FConfigDB), FConfig, FLogger);
end;

function TDeepBaseManager.GetSchemaVersionInternal: string;
begin
  Result := TDeepBaseManagerSchema.GetSchemaVersion(FStorage,
    Assigned(FConfigDB) and IsConnectionAlive(FConfigDB));
end;

function TDeepBaseManager.GetCurrentSchemaVersion: string;
begin
  TMonitor.Enter(FLock);
  try
    Result := GetSchemaVersionInternal;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TDeepBaseManager.RunMigrationScript(const ScriptPath: string): Boolean;
var
  ErrorMsg: string;
begin
  Result := TDeepBaseManagerSchema.RunMigrationScript(FStorage, ScriptPath,
    ErrorMsg);
  if not Result then
    FLastError := ErrorMsg;
end;

function TDeepBaseManager.MigrateSchemaInternal(const FromVersion, ToVersion: string): Boolean;
var
  ErrorMsg: string;
begin
  Result := TDeepBaseManagerSchema.MigrateSchema(FStorage, FRootPath,
    FromVersion, ToVersion, ErrorMsg);
  if not Result then
    FLastError := ErrorMsg;
end;

function TDeepBaseManager.CheckAndMigrateSchema(const TargetVersion: string): Boolean;
var
  CurrentVer: string;
  ErrorMsg: string;
begin
  TMonitor.Enter(FLock);
  try
    CurrentVer := GetSchemaVersionInternal;
    Result := TDeepBaseManagerSchema.CheckAndMigrateSchema(FStorage, FRootPath,
      CurrentVer, TargetVersion, DeepBase_VERSION, ErrorMsg);
    if not Result then
      FLastError := ErrorMsg;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TDeepBaseManager.GetExeDir: string;
begin
  Result := ExtractFilePath(ParamStr(0));
end;

function TDeepBaseManager.GetAppDataDir: string;
{$IFDEF MSWINDOWS}
var
  Path: array[0..MAX_PATH] of Char;
{$ENDIF}
var
  AppName: string;
begin
  Result := '';
  
  // Ӧ����Լ����ʹ�� EXE �ļ�����������չ��
  AppName := ChangeFileExt(ExtractFileName(ParamStr(0)), '');
  if AppName = '' then
    AppName := 'DeepBase';
  
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
  // �� Windows ƽ̨��ʹ�� ~/.{AppName}
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

function TDeepBaseManager.CheckWritePermission(const Path: string): Boolean;
var
  TestFile: string;
begin
  Result := False;
  
  if not TDirectory.Exists(Path) then
    Exit;
    
  TestFile := TPath.Combine(Path, '.DeepBase_write_test');
  try
    TFile.WriteAllText(TestFile, 'test');
    TFile.Delete(TestFile);
    Result := True;
  except
    // ��д��Ȩ��
  end;
end;

function TDeepBaseManager.HealthCheck: THealthCheckResult;
begin
  Result := TDeepBaseManagerOperational.HealthCheck(FIsInitialized,
    Assigned(FConfigDB) and IsConnectionAlive(FConfigDB), FRootPath);
end;

function TDeepBaseManager.GetProjectInfo(const Key: string): string;
begin
  Result := '';
  
  if not FIsInitialized then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    if not Assigned(FStorage) then
      Exit('');
    Result := FStorage.ReadProjectInfo(Key);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TDeepBaseManager.SetProjectInfo(const Key, Value: string);
begin
  if not FIsInitialized then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    if Assigned(FStorage) then
      FStorage.UpsertProjectInfo(Key, Value);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TDeepBaseManager.GetAssetPath(const RelativePath: string): string;
begin
  if FRootPath <> '' then
    Result := TPath.Combine(TPath.Combine(FRootPath, 'assets'), RelativePath)
  else
    Result := RelativePath;
end;

procedure TDeepBaseManager.SetCurrentLanguage(const Value: string);
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

procedure TDeepBaseManager.SetCurrentTheme(const Value: string);
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

procedure TDeepBaseManager.DoLanguageChanged;
begin
  if Assigned(FOnLanguageChanged) then
    FOnLanguageChanged(Self);
end;

procedure TDeepBaseManager.DoThemeChanged;
begin
  if Assigned(FOnThemeChanged) then
    FOnThemeChanged(Self);
end;

procedure TDeepBaseManager.DoConfigChanged(const Key, OldValue, NewValue: string);
begin
  if Assigned(FOnConfigChanged) then
    FOnConfigChanged(Self, Key, OldValue, NewValue);
end;

procedure TDeepBaseManager.HandleConfigChanged(Sender: TObject; const Key, OldValue, NewValue: string);
begin
  // Handle log level changes at runtime
  if (Key = SConfigKeyLogLevel) and Assigned(FLogger) then
    FLogger.MinLevel := StrToLogLevel(NewValue);
  
  DoConfigChanged(Key, OldValue, NewValue);
end;

procedure TDeepBaseManager.HandleLanguageChanged(Sender: TObject);
begin
  DoLanguageChanged;
end;

procedure TDeepBaseManager.HandleThemeChanged(Sender: TObject);
begin
  DoThemeChanged;
end;

initialization
  GDeepBaseLock := TObject.Create;

finalization
  FreeAndNil(GDeepBaseManager);
  FreeAndNil(GDeepBaseLock);

end.
