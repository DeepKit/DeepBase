{ ============================================================================
  UniBase.Config - Configuration Management Module
  
  Version: 0.3
  Description: Provides type-safe config read/write with memory cache and
               thread-safe protection.
  Thread Safety: All public methods are thread-safe.
  ============================================================================ }

unit UniBase.Config;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.NetEncoding,
  FireDAC.Comp.Client,
  UniBase.Types,
  UniBase.Consts,
  UniBase.Interfaces;

type
  /// <summary>
  /// Configuration manager.
  /// Implements IUniBaseConfig for dependency injection and testing.
  /// </summary>
  TUniBaseConfig = class(TInterfacedObject, IUniBaseConfig)
  private
    FConnection: TFDConnection;
    FLock: TObject;
    FCache: TDictionary<string, string>;
    FCacheEnabled: Boolean;
    FOnConfigChanged: TConfigChangedEvent;
    
    function ReadFromDB(const Key: string; const Default: string = ''): string;
    procedure WriteToDB(const Key, Value: string; const Category: string; 
      const ValueType: string; const Description: string);
    
    // R-002: 公共设置逻辑（消除 SetConfig* 重复代码）
    procedure SetConfigInternal(const Key, NewValue, Category, ValueType: string);
    
  public
    constructor Create(AConnection: TFDConnection; ALock: TObject);
    destructor Destroy; override;
    
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
    // For secure storage of passwords/API keys, use UniBase.Security module instead:
    //   UniBase.Security.SaveSecret('key', 'value');
    //   Value := UniBase.Security.LoadSecret('key');
    // ========================================
    
    /// <summary>
    /// Get encrypted config value (auto-decrypts).
    /// DEPRECATED: Use UniBase.Security.LoadSecret() instead for secure storage.
    /// </summary>
    function GetConfigEncrypted(const Key: string; const Default: string = ''): string;
      deprecated 'Use UniBase.Security.LoadSecret() for secure DPAPI encryption';
    
    /// <summary>
    /// Set config with XOR obfuscation.
    /// DEPRECATED: Use UniBase.Security.SaveSecret() instead for secure storage.
    /// </summary>
    procedure SetConfigEncrypted(const Key, Value: string; const Category: string = SConfigCategoryGeneral);
      deprecated 'Use UniBase.Security.SaveSecret() for secure DPAPI encryption';
    
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
  UniBase.Security;

{ TUniBaseConfig }

constructor TUniBaseConfig.Create(AConnection: TFDConnection; ALock: TObject);
begin
  inherited Create;
  FConnection := AConnection;
  FLock := ALock;
  FCache := TDictionary<string, string>.Create;
  FCacheEnabled := True;
end;

destructor TUniBaseConfig.Destroy;
begin
  FCache.Free;
  inherited;
end;

procedure TUniBaseConfig.ClearCache;
begin
  TMonitor.Enter(FLock);
  try
    FCache.Clear;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TUniBaseConfig.PreloadCache;
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    FCache.Clear;
    
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'SELECT Key, Value FROM Settings';
      Query.Open;
      
      while not Query.Eof do
      begin
        FCache.AddOrSetValue(
          Query.FieldByName('Key').AsString,
          Query.FieldByName('Value').AsString
        );
        Query.Next;
      end;
    finally
      Query.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TUniBaseConfig.ReadFromDB(const Key: string; const Default: string): string;
var
  Query: TFDQuery;
begin
  Result := Default;
  
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT Value FROM Settings WHERE Key = :Key';
    Query.ParamByName('Key').AsString := Key;
    Query.Open;
    
    if not Query.Eof then
      Result := Query.FieldByName('Value').AsString;
  finally
    Query.Free;
  end;
end;

procedure TUniBaseConfig.WriteToDB(const Key, Value, Category, ValueType, Description: string);
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 
      'INSERT OR REPLACE INTO Settings (Key, Value, Category, ValueType, Description) ' +
      'VALUES (:Key, :Value, :Category, :ValueType, :Description)';
    Query.ParamByName('Key').AsString := Key;
    Query.ParamByName('Value').AsString := Value;
    Query.ParamByName('Category').AsString := Category;
    Query.ParamByName('ValueType').AsString := ValueType;
    Query.ParamByName('Description').AsString := Description;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;


function TUniBaseConfig.GetConfigEncrypted(const Key: string; const Default: string): string;
var
  Secret: string;
begin
  // 从安全存储加载密文（DPAPI/Secrets 表），不再使用 XOR/Settings 表
  Secret := LoadSecret(Key);
  if Secret = '' then
    Result := Default
  else
    Result := Secret;
end;

procedure TUniBaseConfig.SetConfigEncrypted(const Key, Value: string; const Category: string);
begin
  // 将敏感配置委托给 UniBase.Security 模块存储（DPAPI/Secrets 表）
  SaveSecret(Key, Value, 'Config:' + Category);

  // 移除普通配置缓存，避免明文/旧值残留
  TMonitor.Enter(FLock);
  try
    FCache.Remove(Key);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TUniBaseConfig.GetConfig(const Key: string; const Default: string): string;
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

procedure TUniBaseConfig.SetConfigInternal(const Key, NewValue, Category, ValueType: string);
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

procedure TUniBaseConfig.SetConfig(const Key, Value: string; const Category: string);
begin
  TMonitor.Enter(FLock);
  try
    SetConfigInternal(Key, Value, Category, 'String');
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TUniBaseConfig.GetConfigInt(const Key: string; Default: Integer): Integer;
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

procedure TUniBaseConfig.SetConfigInt(const Key: string; Value: Integer; const Category: string);
begin
  TMonitor.Enter(FLock);
  try
    SetConfigInternal(Key, IntToStr(Value), Category, 'Integer');
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TUniBaseConfig.GetConfigBool(const Key: string; Default: Boolean): Boolean;
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

procedure TUniBaseConfig.SetConfigBool(const Key: string; Value: Boolean; const Category: string);
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

function TUniBaseConfig.GetConfigFloat(const Key: string; Default: Double): Double;
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

procedure TUniBaseConfig.SetConfigFloat(const Key: string; Value: Double; const Category: string);
begin
  TMonitor.Enter(FLock);
  try
    SetConfigInternal(Key, FloatToStr(Value), Category, 'Float');
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TUniBaseConfig.GetConfigsByCategory(const Category: string): TDictionary<string, string>;
var
  Query: TFDQuery;
begin
  Result := TDictionary<string, string>.Create;
  
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'SELECT Key, Value FROM Settings WHERE Category = :Category';
      Query.ParamByName('Category').AsString := Category;
      Query.Open;
      
      while not Query.Eof do
      begin
        Result.Add(
          Query.FieldByName('Key').AsString,
          Query.FieldByName('Value').AsString
        );
        Query.Next;
      end;
    finally
      Query.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TUniBaseConfig.DeleteConfig(const Key: string);
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    // Delete from cache
    FCache.Remove(Key);
    
    // Delete from database
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'DELETE FROM Settings WHERE Key = :Key';
      Query.ParamByName('Key').AsString := Key;
      Query.ExecSQL;
    finally
      Query.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TUniBaseConfig.ConfigExists(const Key: string): Boolean;
var
  Query: TFDQuery;
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
    
    // Query database
    if not Assigned(FConnection) or not FConnection.Connected then
      Exit;
      
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'SELECT 1 FROM Settings WHERE Key = :Key';
      Query.ParamByName('Key').AsString := Key;
      Query.Open;
      Result := not Query.Eof;
    finally
      Query.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

end.
