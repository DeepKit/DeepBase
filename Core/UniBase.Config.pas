{ ============================================================================
  UniBase.Config - 配置管理模块
  
  版本: 0.3
  说明: 提供类型安全的配置读写，带内存缓存和线程安全保护
  线程安全: 所有公共方法均线程安全
  ============================================================================ }

unit UniBase.Config;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  FireDAC.Comp.Client,
  UniBase.Types;

type
  /// <summary>
  /// 配置管理器
  /// </summary>
  TUniBaseConfig = class
  private
    FConnection: TFDConnection;
    FLock: TObject;
    FCache: TDictionary<string, string>;
    FCacheEnabled: Boolean;
    FOnConfigChanged: TConfigChangedEvent;
    
    function ReadFromDB(const Key: string; const Default: string = ''): string;
    procedure WriteToDB(const Key, Value: string; const Category: string; 
      const ValueType: string; const Description: string);
    procedure InvalidateCache(const Key: string);
    
  public
    constructor Create(AConnection: TFDConnection; ALock: TObject);
    destructor Destroy; override;
    
    /// <summary>清空缓存</summary>
    procedure ClearCache;
    
    /// <summary>预加载所有配置到缓存</summary>
    procedure PreloadCache;
    
    // ========================================
    // String 配置
    // ========================================
    
    function GetConfig(const Key: string; const Default: string = ''): string;
    procedure SetConfig(const Key, Value: string; const Category: string = 'General');
    
    // ========================================
    // Integer 配置
    // ========================================
    
    function GetConfigInt(const Key: string; Default: Integer = 0): Integer;
    procedure SetConfigInt(const Key: string; Value: Integer; const Category: string = 'General');
    
    // ========================================
    // Boolean 配置
    // ========================================
    
    function GetConfigBool(const Key: string; Default: Boolean = False): Boolean;
    procedure SetConfigBool(const Key: string; Value: Boolean; const Category: string = 'General');
    
    // ========================================
    // Float 配置
    // ========================================
    
    function GetConfigFloat(const Key: string; Default: Double = 0): Double;
    procedure SetConfigFloat(const Key: string; Value: Double; const Category: string = 'General');
    
    // ========================================
    // 批量操作
    // ========================================
    
    /// <summary>获取指定分类的所有配置</summary>
    function GetConfigsByCategory(const Category: string): TDictionary<string, string>;
    
    /// <summary>删除配置</summary>
    procedure DeleteConfig(const Key: string);
    
    /// <summary>检查配置是否存在</summary>
    function ConfigExists(const Key: string): Boolean;
    
    // ========================================
    // 属性
    // ========================================
    
    /// <summary>是否启用缓存</summary>
    property CacheEnabled: Boolean read FCacheEnabled write FCacheEnabled;
    
    /// <summary>配置变更事件</summary>
    property OnConfigChanged: TConfigChangedEvent read FOnConfigChanged write FOnConfigChanged;
  end;

implementation

uses
  System.StrUtils;

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

procedure TUniBaseConfig.InvalidateCache(const Key: string);
begin
  // 已在锁内调用，不需要再加锁
  FCache.Remove(Key);
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

function TUniBaseConfig.GetConfig(const Key: string; const Default: string): string;
begin
  TMonitor.Enter(FLock);
  try
    // 先查缓存
    if FCacheEnabled and FCache.TryGetValue(Key, Result) then
      Exit;
      
    // 查数据库
    Result := ReadFromDB(Key, Default);
    
    // 写入缓存
    if FCacheEnabled and (Result <> Default) then
      FCache.AddOrSetValue(Key, Result);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TUniBaseConfig.SetConfig(const Key, Value: string; const Category: string);
var
  OldValue: string;
begin
  TMonitor.Enter(FLock);
  try
    // 获取旧值
    if FCacheEnabled and FCache.TryGetValue(Key, OldValue) then
      // 从缓存获取
    else
      OldValue := ReadFromDB(Key, '');
    
    // 写入数据库
    WriteToDB(Key, Value, Category, 'String', '');
    
    // 更新缓存
    if FCacheEnabled then
      FCache.AddOrSetValue(Key, Value);
      
    // 触发事件
    if (OldValue <> Value) and Assigned(FOnConfigChanged) then
      FOnConfigChanged(Self, Key, OldValue, Value);
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
    // 类型转换失败，记录警告并返回默认值
    // TODO: 集成日志模块后记录警告
    Result := Default;
  end;
end;

procedure TUniBaseConfig.SetConfigInt(const Key: string; Value: Integer; const Category: string);
var
  OldValue: string;
begin
  TMonitor.Enter(FLock);
  try
    if FCacheEnabled and FCache.TryGetValue(Key, OldValue) then
      // 从缓存获取
    else
      OldValue := ReadFromDB(Key, '');
    
    WriteToDB(Key, IntToStr(Value), Category, 'Integer', '');
    
    if FCacheEnabled then
      FCache.AddOrSetValue(Key, IntToStr(Value));
      
    if (OldValue <> IntToStr(Value)) and Assigned(FOnConfigChanged) then
      FOnConfigChanged(Self, Key, OldValue, IntToStr(Value));
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
    // 类型转换失败，返回默认值
    Result := Default;
  end;
end;

procedure TUniBaseConfig.SetConfigBool(const Key: string; Value: Boolean; const Category: string);
var
  OldValue, NewValue: string;
begin
  TMonitor.Enter(FLock);
  try
    if FCacheEnabled and FCache.TryGetValue(Key, OldValue) then
      // 从缓存获取
    else
      OldValue := ReadFromDB(Key, '');
    
    if Value then
      NewValue := 'True'
    else
      NewValue := 'False';
      
    WriteToDB(Key, NewValue, Category, 'Boolean', '');
    
    if FCacheEnabled then
      FCache.AddOrSetValue(Key, NewValue);
      
    if (OldValue <> NewValue) and Assigned(FOnConfigChanged) then
      FOnConfigChanged(Self, Key, OldValue, NewValue);
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
    // 类型转换失败，返回默认值
    Result := Default;
  end;
end;

procedure TUniBaseConfig.SetConfigFloat(const Key: string; Value: Double; const Category: string);
var
  OldValue, NewValue: string;
begin
  TMonitor.Enter(FLock);
  try
    if FCacheEnabled and FCache.TryGetValue(Key, OldValue) then
      // 从缓存获取
    else
      OldValue := ReadFromDB(Key, '');
    
    NewValue := FloatToStr(Value);
    WriteToDB(Key, NewValue, Category, 'Float', '');
    
    if FCacheEnabled then
      FCache.AddOrSetValue(Key, NewValue);
      
    if (OldValue <> NewValue) and Assigned(FOnConfigChanged) then
      FOnConfigChanged(Self, Key, OldValue, NewValue);
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
    // 从缓存删除
    FCache.Remove(Key);
    
    // 从数据库删除
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
    // 先查缓存
    if FCacheEnabled and FCache.ContainsKey(Key) then
    begin
      Result := True;
      Exit;
    end;
    
    // 查数据库
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
