{ ============================================================================
  DeepBase.Config - Configuration Management Module
  
  Version: 0.3
  Description: Provides type-safe config read/write with memory cache and
               thread-safe protection.
  Thread Safety: All public methods are thread-safe.
  ============================================================================ }

unit DeepBase.Config;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.NetEncoding,
  DeepBase.Types,
  DeepBase.Consts,
  DeepBase.Interfaces,
  DeepBase.Storage.Interfaces;

// ============================================================================
// Unit-level convenience functions
// These provide direct access without needing to call DeepBase().Config
// Usage: 
//   uses DeepBase.Config;
//   DBPath := GetConfig('DB.Path', 'default.db');
// ============================================================================

/// <summary>Get string config value</summary>
function GetConfig(const Key: string; const Default: string = ''): string;
/// <summary>Set string config value</summary>
procedure SetConfig(const Key, Value: string; const Category: string = '');
/// <summary>Get integer config value</summary>
function GetConfigInt(const Key: string; Default: Integer = 0): Integer;
/// <summary>Set integer config value</summary>
procedure SetConfigInt(const Key: string; Value: Integer; const Category: string = '');
/// <summary>Get boolean config value</summary>
function GetConfigBool(const Key: string; Default: Boolean = False): Boolean;
/// <summary>Set boolean config value</summary>
procedure SetConfigBool(const Key: string; Value: Boolean; const Category: string = '');
/// <summary>Get float config value</summary>
function GetConfigFloat(const Key: string; Default: Double = 0): Double;
/// <summary>Set float config value</summary>
procedure SetConfigFloat(const Key: string; Value: Double; const Category: string = '');
/// <summary>Check if config key exists</summary>
function ConfigExists(const Key: string): Boolean;
/// <summary>Delete config key</summary>
procedure DeleteConfig(const Key: string);

type
  /// <summary>
  /// Configuration manager.
  /// Implements IDeepBaseConfig for dependency injection and testing.
  /// </summary>
  TDeepBaseConfig = class(TInterfacedObject, IDeepBaseConfig)
  private
    FConnection: TObject;
    FStorage: IConfigStorage;
    FLock: TObject;
    FOwnsLock: Boolean;
    FCache: TDictionary<string, string>;
    FCacheEnabled: Boolean;
    FOnConfigChanged: TConfigChangedEvent;
    class var FConnectionStorageFactory: TFunc<TObject, IConfigStorage>;
    
    function ReadFromDB(const Key: string; const Default: string = ''): string;
    procedure WriteToDB(const Key, Value: string; const Category: string; 
      const ValueType: string; const Description: string);
    class function CreateStorageFromConnection(AConnection: TObject): IConfigStorage; static;
    
    // R-002: 公共设置逻辑（消除 SetConfig* 重复代码）
    procedure SetConfigInternal(const Key, NewValue, Category, ValueType: string);
    
  public
    constructor Create(AConnection: TObject; ALock: TObject); overload;
    constructor Create(const AStorage: IConfigStorage; ALock: TObject = nil); overload;
    destructor Destroy; override;
    
    class procedure SetConnectionStorageFactory(
      const AFactory: TFunc<TObject, IConfigStorage>); static;
    
    /// <summary>Clear cache</summary>
    procedure ClearCache;
    
    /// <summary>Preload all config into cache</summary>
    procedure PreloadCache;
    
    // ========================================
    // String Config
    // ========================================
    
    function GetConfig(const Key: string; const Default: string = ''): string;
    procedure SetConfig(const Key, Value: string; const Category: string = SConfigCategoryGeneral);
    
    // ========================================
    // Integer Config
    // ========================================
    
    function GetConfigInt(const Key: string; Default: Integer = 0): Integer;
    procedure SetConfigInt(const Key: string; Value: Integer; const Category: string = SConfigCategoryGeneral);
    
    // ========================================
    // Boolean Config
    // ========================================
    
    function GetConfigBool(const Key: string; Default: Boolean = False): Boolean;
    procedure SetConfigBool(const Key: string; Value: Boolean; const Category: string = SConfigCategoryGeneral);
    
    // ========================================
    // Float Config
    // ========================================
    
    function GetConfigFloat(const Key: string; Default: Double = 0): Double;
    procedure SetConfigFloat(const Key: string; Value: Double; const Category: string = SConfigCategoryGeneral);
    
    // ========================================
    // Batch Operations
    // ========================================
    
    /// <summary>Get all configs for a category</summary>
    function GetConfigsByCategory(const Category: string): TDictionary<string, string>;
    
    /// <summary>Delete config</summary>
    procedure DeleteConfig(const Key: string);
    
    /// <summary>Check if config exists</summary>
    function ConfigExists(const Key: string): Boolean;
    
    // ========================================
    // Encrypted Config (DEPRECATED)
    // WARNING: Uses XOR obfuscation, NOT secure encryption!
    // For secure storage of passwords/API keys, use DeepBase.Security module instead:
    //   DeepBase.Security.SaveSecret('key', 'value');
    //   Value := DeepBase.Security.LoadSecret('key');
    // ========================================
    
    /// <summary>
    /// Get encrypted config value (auto-decrypts).
    /// DEPRECATED: Use DeepBase.Security.LoadSecret() instead for secure storage.
    /// </summary>
    function GetConfigEncrypted(const Key: string; const Default: string = ''): string;
      deprecated 'Use DeepBase.Security.LoadSecret() for secure DPAPI encryption';
    
    /// <summary>
    /// Set config with XOR obfuscation.
    /// DEPRECATED: Use DeepBase.Security.SaveSecret() instead for secure storage.
    /// </summary>
    procedure SetConfigEncrypted(const Key, Value: string; const Category: string = SConfigCategoryGeneral);
      deprecated 'Use DeepBase.Security.SaveSecret() for secure DPAPI encryption';
    
    // ========================================
    // Properties
    // ========================================
    
    /// <summary>Enable cache</summary>
    property CacheEnabled: Boolean read FCacheEnabled write FCacheEnabled;
    
    /// <summary>Config changed event</summary>
    property OnConfigChanged: TConfigChangedEvent read FOnConfigChanged write FOnConfigChanged;
  end;

implementation

uses
  System.StrUtils,
  DeepBase.Security,
  DeepBase.Manager;

{ TDeepBaseConfig }

constructor TDeepBaseConfig.Create(AConnection: TObject; ALock: TObject);
begin
  Create(CreateStorageFromConnection(AConnection), ALock);
  FConnection := AConnection;
end;

constructor TDeepBaseConfig.Create(const AStorage: IConfigStorage; ALock: TObject);
begin
  inherited Create;
  FStorage := AStorage;
  if Assigned(ALock) then
  begin
    FLock := ALock;
    FOwnsLock := False;
  end
  else
  begin
    FLock := TObject.Create;
    FOwnsLock := True;
  end;
  FCache := TDictionary<string, string>.Create;
  FCacheEnabled := True;
end;

destructor TDeepBaseConfig.Destroy;
begin
  if FOwnsLock then
    FreeAndNil(FLock);
  FreeAndNil(FCache);
  inherited;
end;

class procedure TDeepBaseConfig.SetConnectionStorageFactory(
  const AFactory: TFunc<TObject, IConfigStorage>);
begin
  FConnectionStorageFactory := AFactory;
end;

class function TDeepBaseConfig.CreateStorageFromConnection(
  AConnection: TObject): IConfigStorage;
begin
  Result := nil;
  if Assigned(AConnection) and Assigned(FConnectionStorageFactory) then
    Result := FConnectionStorageFactory(AConnection);
  if (Result = nil) and Assigned(AConnection) then
    raise EInvalidOp.Create(
      'No config storage factory registered for connection-backed constructor. ' +
      'Include DeepBase.Persistence.Config.FireDAC or DeepBase.Persistence.Manager.FireDAC.');
end;

procedure TDeepBaseConfig.ClearCache;
begin
  TMonitor.Enter(FLock);
  try
    FCache.Clear;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TDeepBaseConfig.PreloadCache;
begin
  if not Assigned(FStorage) then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    FStorage.LoadAll(FCache);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TDeepBaseConfig.ReadFromDB(const Key: string; const Default: string): string;
begin
  if Assigned(FStorage) then
    Result := FStorage.ReadValue(Key, Default)
  else
    Result := Default;
end;

procedure TDeepBaseConfig.WriteToDB(const Key, Value, Category, ValueType, Description: string);
begin
  if Assigned(FStorage) then
    FStorage.WriteValue(Key, Value, Category, ValueType, Description);
end;


function TDeepBaseConfig.GetConfigEncrypted(const Key: string; const Default: string): string;
begin
  // 完全移除XOR实现，强制使用DPAPI安全存储
  raise ENotSupportedException.Create(
    'GetConfigEncrypted is deprecated and removed for security reasons. ' +
    'Use DeepBase.Security.LoadSecret() for secure DPAPI encryption instead.'
  );
end;

procedure TDeepBaseConfig.SetConfigEncrypted(const Key, Value: string; const Category: string);
begin
  // 完全移除XOR实现，强制使用DPAPI安全存储
  raise ENotSupportedException.Create(
    'SetConfigEncrypted is deprecated and removed for security reasons. ' +
    'Use DeepBase.Security.SaveSecret() for secure DPAPI encryption instead.'
  );
end;

function TDeepBaseConfig.GetConfig(const Key: string; const Default: string): string;
begin
  TMonitor.Enter(FLock);
  try
    // Check cache first
    if FCacheEnabled and FCache.TryGetValue(Key, Result) then
      Exit;
      
    // Query database
    Result := ReadFromDB(Key, Default);
    
    // Write to cache
    if FCacheEnabled and (Result <> Default) then
      FCache.AddOrSetValue(Key, Result);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TDeepBaseConfig.SetConfigInternal(const Key, NewValue, Category, ValueType: string);
var
  OldValue: string;
begin
  // 注意：调用者需确保已获取锁
  // 获取旧值
  if FCacheEnabled and FCache.TryGetValue(Key, OldValue) then
    // From cache
  else
    OldValue := ReadFromDB(Key, '');
  
  // 写入数据库
  WriteToDB(Key, NewValue, Category, ValueType, '');
  
  // 更新缓存
  if FCacheEnabled then
    FCache.AddOrSetValue(Key, NewValue);
    
  // 触发事件
  if (OldValue <> NewValue) and Assigned(FOnConfigChanged) then
    FOnConfigChanged(Self, Key, OldValue, NewValue);
end;

procedure TDeepBaseConfig.SetConfig(const Key, Value: string; const Category: string);
begin
  TMonitor.Enter(FLock);
  try
    SetConfigInternal(Key, Value, Category, 'String');
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TDeepBaseConfig.GetConfigInt(const Key: string; Default: Integer): Integer;
var
  StrValue: string;
begin
  StrValue := GetConfig(Key, '');
  if StrValue = '' then
    Result := Default
  else if not TryStrToInt(StrValue, Result) then
  begin
    // Type conversion failed, return default (caller may log a warning if needed)
    Result := Default;
  end;
end;

procedure TDeepBaseConfig.SetConfigInt(const Key: string; Value: Integer; const Category: string);
begin
  TMonitor.Enter(FLock);
  try
    SetConfigInternal(Key, IntToStr(Value), Category, 'Integer');
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TDeepBaseConfig.GetConfigBool(const Key: string; Default: Boolean): Boolean;
var
  StrValue: string;
begin
  StrValue := UpperCase(GetConfig(Key, ''));
  if StrValue = '' then
    Result := Default
  else if (StrValue = 'TRUE') or (StrValue = '1') or (StrValue = 'YES') then
    Result := True
  else if (StrValue = 'FALSE') or (StrValue = '0') or (StrValue = 'NO') then
    Result := False
  else
  begin
    // Type conversion failed, return default
    Result := Default;
  end;
end;

procedure TDeepBaseConfig.SetConfigBool(const Key: string; Value: Boolean; const Category: string);
var
  NewValue: string;
begin
  if Value then
    NewValue := 'True'
  else
    NewValue := 'False';
    
  TMonitor.Enter(FLock);
  try
    SetConfigInternal(Key, NewValue, Category, 'Boolean');
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TDeepBaseConfig.GetConfigFloat(const Key: string; Default: Double): Double;
var
  StrValue: string;
begin
  StrValue := GetConfig(Key, '');
  if StrValue = '' then
    Result := Default
  else if not TryStrToFloat(StrValue, Result) then
  begin
    // Type conversion failed, return default
    Result := Default;
  end;
end;

procedure TDeepBaseConfig.SetConfigFloat(const Key: string; Value: Double; const Category: string);
begin
  TMonitor.Enter(FLock);
  try
    SetConfigInternal(Key, FloatToStr(Value), Category, 'Float');
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TDeepBaseConfig.GetConfigsByCategory(const Category: string): TDictionary<string, string>;
begin
  Result := TDictionary<string, string>.Create;
  if not Assigned(FStorage) then
    Exit;

  TMonitor.Enter(FLock);
  try
    FStorage.LoadByCategory(Category, Result);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TDeepBaseConfig.DeleteConfig(const Key: string);
begin
  TMonitor.Enter(FLock);
  try
    // Delete from cache
    FCache.Remove(Key);

    // Delete from storage
    if Assigned(FStorage) then
      FStorage.DeleteValue(Key);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TDeepBaseConfig.ConfigExists(const Key: string): Boolean;
begin
  Result := False;
  
  TMonitor.Enter(FLock);
  try
    // Check cache first
    if FCacheEnabled and FCache.ContainsKey(Key) then
    begin
      Result := True;
      Exit;
    end;

    if Assigned(FStorage) then
      Result := FStorage.ValueExists(Key);
  finally
    TMonitor.Exit(FLock);
  end;
end;

// ============================================================================
// Unit-level convenience function implementations
// Note: These use UBConfig from DeepBase.Manager to avoid dotted-name ambiguity
// ============================================================================

function GetConfig(const Key: string; const Default: string): string;
var
  Cfg: TDeepBaseConfig;
begin
  Cfg := UBConfig;
  if Assigned(Cfg) then
    Result := Cfg.GetConfig(Key, Default)
  else
    Result := Default;
end;

procedure SetConfig(const Key, Value: string; const Category: string);
var
  Cat: string;
  Cfg: TDeepBaseConfig;
begin
  if Category = '' then
    Cat := SConfigCategoryGeneral
  else
    Cat := Category;
  Cfg := UBConfig;
  if Assigned(Cfg) then
    Cfg.SetConfig(Key, Value, Cat);
end;

function GetConfigInt(const Key: string; Default: Integer): Integer;
var
  Cfg: TDeepBaseConfig;
begin
  Cfg := UBConfig;
  if Assigned(Cfg) then
    Result := Cfg.GetConfigInt(Key, Default)
  else
    Result := Default;
end;

procedure SetConfigInt(const Key: string; Value: Integer; const Category: string);
var
  Cat: string;
  Cfg: TDeepBaseConfig;
begin
  if Category = '' then
    Cat := SConfigCategoryGeneral
  else
    Cat := Category;
  Cfg := UBConfig;
  if Assigned(Cfg) then
    Cfg.SetConfigInt(Key, Value, Cat);
end;

function GetConfigBool(const Key: string; Default: Boolean): Boolean;
var
  Cfg: TDeepBaseConfig;
begin
  Cfg := UBConfig;
  if Assigned(Cfg) then
    Result := Cfg.GetConfigBool(Key, Default)
  else
    Result := Default;
end;

procedure SetConfigBool(const Key: string; Value: Boolean; const Category: string);
var
  Cat: string;
  Cfg: TDeepBaseConfig;
begin
  if Category = '' then
    Cat := SConfigCategoryGeneral
  else
    Cat := Category;
  Cfg := UBConfig;
  if Assigned(Cfg) then
    Cfg.SetConfigBool(Key, Value, Cat);
end;

function GetConfigFloat(const Key: string; Default: Double): Double;
var
  Cfg: TDeepBaseConfig;
begin
  Cfg := UBConfig;
  if Assigned(Cfg) then
    Result := Cfg.GetConfigFloat(Key, Default)
  else
    Result := Default;
end;

procedure SetConfigFloat(const Key: string; Value: Double; const Category: string);
var
  Cat: string;
  Cfg: TDeepBaseConfig;
begin
  if Category = '' then
    Cat := SConfigCategoryGeneral
  else
    Cat := Category;
  Cfg := UBConfig;
  if Assigned(Cfg) then
    Cfg.SetConfigFloat(Key, Value, Cat);
end;

function ConfigExists(const Key: string): Boolean;
var
  Cfg: TDeepBaseConfig;
begin
  Cfg := UBConfig;
  if Assigned(Cfg) then
    Result := Cfg.ConfigExists(Key)
  else
    Result := False;
end;

procedure DeleteConfig(const Key: string);
var
  Cfg: TDeepBaseConfig;
begin
  Cfg := UBConfig;
  if Assigned(Cfg) then
    Cfg.DeleteConfig(Key);
end;

end.
