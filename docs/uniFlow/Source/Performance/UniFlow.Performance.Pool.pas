unit UniFlow.Performance.Pool;
(*
  UniFlow Performance - Object Pool
  ==================================
  高性能对象池实现，减少频繁创建/销毁对象的开销。
  
  特性：
  - 泛型对象池，支持任意类型
  - 线程安全
  - 预分配 + 动态扩容
  - 对象重置机制
  - 统计信息
  
  Author: UniFlow Team
  Date: 2025-12-05
*)

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.SyncObjs, System.JSON;

type
  // ============================================================================
  // 池化对象接口
  // ============================================================================
  
  /// <summary>可池化对象接口</summary>
  IPoolable = interface
    ['{8A1B2C3D-4E5F-6A7B-8C9D-0E1F2A3B4C5D}']
    /// <summary>重置对象状态，准备重用</summary>
    procedure Reset;
    /// <summary>对象是否可重用</summary>
    function IsReusable: Boolean;
  end;
  
  // ============================================================================
  // 对象池统计
  // ============================================================================
  
  TPoolStats = record
    TotalCreated: Int64;      // 总创建数
    TotalAcquired: Int64;     // 总获取数
    TotalReleased: Int64;     // 总释放数
    TotalReset: Int64;        // 总重置数
    CurrentPoolSize: Integer; // 当前池大小
    CurrentInUse: Integer;    // 当前使用中
    PeakInUse: Integer;       // 峰值使用
    HitRate: Double;          // 命中率
    
    procedure Reset;
    function ToJSON: TJSONObject;
  end;
  
  // ============================================================================
  // 对象池配置
  // ============================================================================
  
  TPoolConfig = record
    InitialSize: Integer;     // 初始池大小
    MaxSize: Integer;         // 最大池大小 (0 = 无限制)
    GrowthFactor: Double;     // 扩容因子
    ShrinkThreshold: Double;  // 收缩阈值
    MaxIdleTimeMs: Int64;     // 最大空闲时间 (ms)
    
    class function Default: TPoolConfig; static;
    class function Small: TPoolConfig; static;
    class function Large: TPoolConfig; static;
  end;
  
  // ============================================================================
  // 池化对象包装
  // ============================================================================
  
  TPooledItem<T: class> = class
  private
    FInstance: T;
    FLastUsed: TDateTime;
    FUseCount: Integer;
  public
    constructor Create(AInstance: T);
    destructor Destroy; override;
    
    procedure MarkUsed;
    function IsExpired(MaxIdleMs: Int64): Boolean;
    
    property Instance: T read FInstance;
    property LastUsed: TDateTime read FLastUsed;
    property UseCount: Integer read FUseCount;
  end;
  
  // ============================================================================
  // 泛型对象池
  // ============================================================================
  
  /// <summary>对象工厂函数类型</summary>
  TObjectFactory<T: class> = reference to function: T;
  
  /// <summary>对象重置函数类型</summary>
  TObjectResetter<T: class> = reference to procedure(AInstance: T);
  
  /// <summary>对象验证函数类型</summary>
  TObjectValidator<T: class> = reference to function(AInstance: T): Boolean;
  
  TObjectPool<T: class> = class
  private
    FPool: TObjectList<TPooledItem<T>>;
    FConfig: TPoolConfig;
    FFactory: TObjectFactory<T>;
    FResetter: TObjectResetter<T>;
    FValidator: TObjectValidator<T>;
    FLock: TCriticalSection;
    FStats: TPoolStats;
    FEnabled: Boolean;
    
    function CreateInstance: T;
    procedure ResetInstance(AInstance: T);
    function ValidateInstance(AInstance: T): Boolean;
    procedure GrowPool;
    procedure ShrinkPool;
    procedure CleanExpired;
  public
    constructor Create(AFactory: TObjectFactory<T>; AConfig: TPoolConfig); overload;
    constructor Create(AFactory: TObjectFactory<T>); overload;
    destructor Destroy; override;
    
    /// <summary>设置对象重置器</summary>
    procedure SetResetter(AResetter: TObjectResetter<T>);
    
    /// <summary>设置对象验证器</summary>
    procedure SetValidator(AValidator: TObjectValidator<T>);
    
    /// <summary>获取对象</summary>
    function Acquire: T;
    
    /// <summary>释放对象回池</summary>
    procedure Release(AInstance: T);
    
    /// <summary>预热池（预创建对象）</summary>
    procedure Warmup(ACount: Integer = 0);
    
    /// <summary>清空池</summary>
    procedure Clear;
    
    /// <summary>收缩池到指定大小</summary>
    procedure Shrink(ATargetSize: Integer);
    
    /// <summary>获取统计信息</summary>
    function GetStats: TPoolStats;
    
    /// <summary>启用/禁用池化（禁用时直接创建新对象）</summary>
    property Enabled: Boolean read FEnabled write FEnabled;
    property Config: TPoolConfig read FConfig;
  end;
  
  // ============================================================================
  // 专用对象池：TJSONObject 池
  // ============================================================================
  
  TJSONObjectPool = class
  private
    FPool: TObjectPool<TJSONObject>;
    class var FInstance: TJSONObjectPool;
    class var FLock: TCriticalSection;
  public
    constructor Create;
    destructor Destroy; override;
    
    function Acquire: TJSONObject;
    procedure Release(AJson: TJSONObject);
    
    class function GetInstance: TJSONObjectPool;
    class procedure ReleaseInstance;
  end;
  
  // ============================================================================
  // 专用对象池：TStringBuilder 池
  // ============================================================================
  
  TStringBuilderPool = class
  private
    FPool: TObjectPool<TStringBuilder>;
    class var FInstance: TStringBuilderPool;
    class var FLock: TCriticalSection;
  public
    constructor Create;
    destructor Destroy; override;
    
    function Acquire: TStringBuilder;
    procedure Release(ASB: TStringBuilder);
    
    class function GetInstance: TStringBuilderPool;
    class procedure ReleaseInstance;
  end;
  
  // ============================================================================
  // 专用对象池：TStringList 池
  // ============================================================================
  
  TStringListPool = class
  private
    FPool: TObjectPool<TStringList>;
    class var FInstance: TStringListPool;
    class var FLock: TCriticalSection;
  public
    constructor Create;
    destructor Destroy; override;
    
    function Acquire: TStringList;
    procedure Release(ASL: TStringList);
    
    class function GetInstance: TStringListPool;
    class procedure ReleaseInstance;
  end;
  
  // ============================================================================
  // 对象池管理器
  // ============================================================================
  
  TPoolManager = class
  private
    FPools: TDictionary<string, TObject>;
    FLock: TCriticalSection;
    class var FInstance: TPoolManager;
  public
    constructor Create;
    destructor Destroy; override;
    
    /// <summary>注册池</summary>
    procedure RegisterPool(const AName: string; APool: TObject);
    
    /// <summary>获取池</summary>
    function GetPool<T: class>(const AName: string): TObjectPool<T>;
    
    /// <summary>获取所有池统计</summary>
    function GetAllStats: TJSONObject;
    
    /// <summary>清理所有池</summary>
    procedure ClearAll;
    
    class function GetInstance: TPoolManager;
    class procedure ReleaseInstance;
  end;
  
  // ============================================================================
  // 池化作用域辅助类
  // ============================================================================
  
  /// <summary>RAII 风格的池化对象作用域</summary>
  TPooledScope<T: class> = record
  private
    FPool: TObjectPool<T>;
    FInstance: T;
  public
    class function Create(APool: TObjectPool<T>): TPooledScope<T>; static;
    procedure Release;
    property Instance: T read FInstance;
  end;

// ============================================================================
// 全局便捷函数
// ============================================================================

/// <summary>获取 TJSONObject 池实例</summary>
function JSONPool: TJSONObjectPool;

/// <summary>获取 TStringBuilder 池实例</summary>
function StringBuilderPool: TStringBuilderPool;

/// <summary>获取 TStringList 池实例</summary>
function StringListPool: TStringListPool;

/// <summary>获取池管理器实例</summary>
function PoolManager: TPoolManager;

implementation

uses
  System.DateUtils;

// ============================================================================
// TPoolStats
// ============================================================================

procedure TPoolStats.Reset;
begin
  TotalCreated := 0;
  TotalAcquired := 0;
  TotalReleased := 0;
  TotalReset := 0;
  CurrentPoolSize := 0;
  CurrentInUse := 0;
  PeakInUse := 0;
  HitRate := 0;
end;

function TPoolStats.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('totalCreated', TJSONNumber.Create(TotalCreated));
  Result.AddPair('totalAcquired', TJSONNumber.Create(TotalAcquired));
  Result.AddPair('totalReleased', TJSONNumber.Create(TotalReleased));
  Result.AddPair('totalReset', TJSONNumber.Create(TotalReset));
  Result.AddPair('currentPoolSize', TJSONNumber.Create(CurrentPoolSize));
  Result.AddPair('currentInUse', TJSONNumber.Create(CurrentInUse));
  Result.AddPair('peakInUse', TJSONNumber.Create(PeakInUse));
  Result.AddPair('hitRate', TJSONNumber.Create(HitRate));
end;

// ============================================================================
// TPoolConfig
// ============================================================================

class function TPoolConfig.Default: TPoolConfig;
begin
  Result.InitialSize := 16;
  Result.MaxSize := 256;
  Result.GrowthFactor := 2.0;
  Result.ShrinkThreshold := 0.25;
  Result.MaxIdleTimeMs := 60000; // 1 minute
end;

class function TPoolConfig.Small: TPoolConfig;
begin
  Result.InitialSize := 4;
  Result.MaxSize := 32;
  Result.GrowthFactor := 2.0;
  Result.ShrinkThreshold := 0.25;
  Result.MaxIdleTimeMs := 30000;
end;

class function TPoolConfig.Large: TPoolConfig;
begin
  Result.InitialSize := 64;
  Result.MaxSize := 1024;
  Result.GrowthFactor := 1.5;
  Result.ShrinkThreshold := 0.1;
  Result.MaxIdleTimeMs := 120000; // 2 minutes
end;

// ============================================================================
// TPooledItem<T>
// ============================================================================

constructor TPooledItem<T>.Create(AInstance: T);
begin
  inherited Create;
  FInstance := AInstance;
  FLastUsed := Now;
  FUseCount := 0;
end;

destructor TPooledItem<T>.Destroy;
begin
  if Assigned(FInstance) then
    FInstance.Free;
  inherited;
end;

procedure TPooledItem<T>.MarkUsed;
begin
  FLastUsed := Now;
  Inc(FUseCount);
end;

function TPooledItem<T>.IsExpired(MaxIdleMs: Int64): Boolean;
begin
  if MaxIdleMs <= 0 then
    Result := False
  else
    Result := MilliSecondsBetween(Now, FLastUsed) > MaxIdleMs;
end;

// ============================================================================
// TObjectPool<T>
// ============================================================================

constructor TObjectPool<T>.Create(AFactory: TObjectFactory<T>; AConfig: TPoolConfig);
begin
  inherited Create;
  FFactory := AFactory;
  FConfig := AConfig;
  FPool := TObjectList<TPooledItem<T>>.Create(True);
  FLock := TCriticalSection.Create;
  FStats.Reset;
  FEnabled := True;
  
  // 初始化池
  Warmup(FConfig.InitialSize);
end;

constructor TObjectPool<T>.Create(AFactory: TObjectFactory<T>);
begin
  Create(AFactory, TPoolConfig.Default);
end;

destructor TObjectPool<T>.Destroy;
begin
  Clear;
  FPool.Free;
  FLock.Free;
  inherited;
end;

procedure TObjectPool<T>.SetResetter(AResetter: TObjectResetter<T>);
begin
  FResetter := AResetter;
end;

procedure TObjectPool<T>.SetValidator(AValidator: TObjectValidator<T>);
begin
  FValidator := AValidator;
end;

function TObjectPool<T>.CreateInstance: T;
begin
  Result := FFactory();
  Inc(FStats.TotalCreated);
end;

procedure TObjectPool<T>.ResetInstance(AInstance: T);
begin
  if Assigned(FResetter) then
  begin
    FResetter(AInstance);
    Inc(FStats.TotalReset);
  end
  else if Supports(AInstance, IPoolable) then
  begin
    (AInstance as IPoolable).Reset;
    Inc(FStats.TotalReset);
  end;
end;

function TObjectPool<T>.ValidateInstance(AInstance: T): Boolean;
begin
  if Assigned(FValidator) then
    Result := FValidator(AInstance)
  else if Supports(AInstance, IPoolable) then
    Result := (AInstance as IPoolable).IsReusable
  else
    Result := True;
end;

procedure TObjectPool<T>.GrowPool;
var
  NewSize, i: Integer;
begin
  // 计算新大小
  NewSize := Round(FPool.Count * FConfig.GrowthFactor);
  if NewSize < FPool.Count + 1 then
    NewSize := FPool.Count + 1;
  
  // 限制最大大小
  if (FConfig.MaxSize > 0) and (NewSize > FConfig.MaxSize) then
    NewSize := FConfig.MaxSize;
  
  // 扩容
  for i := FPool.Count to NewSize - 1 do
    FPool.Add(TPooledItem<T>.Create(CreateInstance));
  
  FStats.CurrentPoolSize := FPool.Count;
end;

procedure TObjectPool<T>.ShrinkPool;
var
  TargetSize, i: Integer;
begin
  // 计算目标大小
  TargetSize := FConfig.InitialSize;
  if FStats.PeakInUse > TargetSize then
    TargetSize := FStats.PeakInUse;
  
  // 收缩
  while FPool.Count > TargetSize do
    FPool.Delete(FPool.Count - 1);
  
  FStats.CurrentPoolSize := FPool.Count;
end;

procedure TObjectPool<T>.CleanExpired;
var
  i: Integer;
begin
  if FConfig.MaxIdleTimeMs <= 0 then
    Exit;
    
  for i := FPool.Count - 1 downto 0 do
  begin
    if FPool[i].IsExpired(FConfig.MaxIdleTimeMs) then
      FPool.Delete(i);
  end;
  
  FStats.CurrentPoolSize := FPool.Count;
end;

function TObjectPool<T>.Acquire: T;
var
  Item: TPooledItem<T>;
  i: Integer;
begin
  // 如果禁用池化，直接创建新对象
  if not FEnabled then
  begin
    Result := CreateInstance;
    Exit;
  end;
  
  FLock.Enter;
  try
    Inc(FStats.TotalAcquired);
    
    // 清理过期对象
    CleanExpired;
    
    // 从池中获取
    for i := FPool.Count - 1 downto 0 do
    begin
      Item := FPool[i];
      if ValidateInstance(Item.Instance) then
      begin
        Result := Item.Instance;
        Item.MarkUsed;
        FPool.OwnsObjects := False;
        FPool.Delete(i);
        FPool.OwnsObjects := True;
        Item.Free;
        
        Inc(FStats.CurrentInUse);
        if FStats.CurrentInUse > FStats.PeakInUse then
          FStats.PeakInUse := FStats.CurrentInUse;
        
        FStats.CurrentPoolSize := FPool.Count;
        
        // 计算命中率
        FStats.HitRate := (FStats.TotalAcquired - FStats.TotalCreated) / FStats.TotalAcquired;
        
        Exit;
      end;
    end;
    
    // 池空，创建新对象
    Result := CreateInstance;
    Inc(FStats.CurrentInUse);
    if FStats.CurrentInUse > FStats.PeakInUse then
      FStats.PeakInUse := FStats.CurrentInUse;
    
    // 计算命中率
    if FStats.TotalAcquired > 0 then
      FStats.HitRate := (FStats.TotalAcquired - FStats.TotalCreated) / FStats.TotalAcquired;
  finally
    FLock.Leave;
  end;
end;

procedure TObjectPool<T>.Release(AInstance: T);
var
  Item: TPooledItem<T>;
begin
  if AInstance = nil then
    Exit;
    
  // 如果禁用池化，直接销毁
  if not FEnabled then
  begin
    AInstance.Free;
    Exit;
  end;
  
  FLock.Enter;
  try
    Inc(FStats.TotalReleased);
    Dec(FStats.CurrentInUse);
    
    // 检查是否超过最大大小
    if (FConfig.MaxSize > 0) and (FPool.Count >= FConfig.MaxSize) then
    begin
      AInstance.Free;
      Exit;
    end;
    
    // 重置对象
    ResetInstance(AInstance);
    
    // 验证对象
    if not ValidateInstance(AInstance) then
    begin
      AInstance.Free;
      Exit;
    end;
    
    // 放回池中
    Item := TPooledItem<T>.Create(AInstance);
    FPool.Add(Item);
    FStats.CurrentPoolSize := FPool.Count;
  finally
    FLock.Leave;
  end;
end;

procedure TObjectPool<T>.Warmup(ACount: Integer);
var
  i, TargetCount: Integer;
begin
  FLock.Enter;
  try
    if ACount <= 0 then
      TargetCount := FConfig.InitialSize
    else
      TargetCount := ACount;
      
    // 限制最大大小
    if (FConfig.MaxSize > 0) and (TargetCount > FConfig.MaxSize) then
      TargetCount := FConfig.MaxSize;
    
    for i := FPool.Count to TargetCount - 1 do
      FPool.Add(TPooledItem<T>.Create(CreateInstance));
    
    FStats.CurrentPoolSize := FPool.Count;
  finally
    FLock.Leave;
  end;
end;

procedure TObjectPool<T>.Clear;
begin
  FLock.Enter;
  try
    FPool.Clear;
    FStats.CurrentPoolSize := 0;
  finally
    FLock.Leave;
  end;
end;

procedure TObjectPool<T>.Shrink(ATargetSize: Integer);
begin
  FLock.Enter;
  try
    while FPool.Count > ATargetSize do
      FPool.Delete(FPool.Count - 1);
    FStats.CurrentPoolSize := FPool.Count;
  finally
    FLock.Leave;
  end;
end;

function TObjectPool<T>.GetStats: TPoolStats;
begin
  FLock.Enter;
  try
    Result := FStats;
  finally
    FLock.Leave;
  end;
end;

// ============================================================================
// TJSONObjectPool
// ============================================================================

constructor TJSONObjectPool.Create;
begin
  inherited Create;
  FPool := TObjectPool<TJSONObject>.Create(
    function: TJSONObject
    begin
      Result := TJSONObject.Create;
    end,
    TPoolConfig.Default
  );
  
  FPool.SetResetter(
    procedure(AJson: TJSONObject)
    begin
      // 清空 JSON 对象
      while AJson.Count > 0 do
        AJson.RemovePair(AJson.Pairs[0].JsonString.Value).Free;
    end
  );
end;

destructor TJSONObjectPool.Destroy;
begin
  FPool.Free;
  inherited;
end;

function TJSONObjectPool.Acquire: TJSONObject;
begin
  Result := FPool.Acquire;
end;

procedure TJSONObjectPool.Release(AJson: TJSONObject);
begin
  FPool.Release(AJson);
end;

class function TJSONObjectPool.GetInstance: TJSONObjectPool;
begin
  if FInstance = nil then
  begin
    if FLock = nil then
      FLock := TCriticalSection.Create;
    FLock.Enter;
    try
      if FInstance = nil then
        FInstance := TJSONObjectPool.Create;
    finally
      FLock.Leave;
    end;
  end;
  Result := FInstance;
end;

class procedure TJSONObjectPool.ReleaseInstance;
begin
  if FLock <> nil then
  begin
    FLock.Enter;
    try
      FreeAndNil(FInstance);
    finally
      FLock.Leave;
    end;
    FreeAndNil(FLock);
  end;
end;

// ============================================================================
// TStringBuilderPool
// ============================================================================

constructor TStringBuilderPool.Create;
begin
  inherited Create;
  FPool := TObjectPool<TStringBuilder>.Create(
    function: TStringBuilder
    begin
      Result := TStringBuilder.Create(256);
    end,
    TPoolConfig.Default
  );
  
  FPool.SetResetter(
    procedure(ASB: TStringBuilder)
    begin
      ASB.Clear;
    end
  );
end;

destructor TStringBuilderPool.Destroy;
begin
  FPool.Free;
  inherited;
end;

function TStringBuilderPool.Acquire: TStringBuilder;
begin
  Result := FPool.Acquire;
end;

procedure TStringBuilderPool.Release(ASB: TStringBuilder);
begin
  FPool.Release(ASB);
end;

class function TStringBuilderPool.GetInstance: TStringBuilderPool;
begin
  if FInstance = nil then
  begin
    if FLock = nil then
      FLock := TCriticalSection.Create;
    FLock.Enter;
    try
      if FInstance = nil then
        FInstance := TStringBuilderPool.Create;
    finally
      FLock.Leave;
    end;
  end;
  Result := FInstance;
end;

class procedure TStringBuilderPool.ReleaseInstance;
begin
  if FLock <> nil then
  begin
    FLock.Enter;
    try
      FreeAndNil(FInstance);
    finally
      FLock.Leave;
    end;
    FreeAndNil(FLock);
  end;
end;

// ============================================================================
// TStringListPool
// ============================================================================

constructor TStringListPool.Create;
begin
  inherited Create;
  FPool := TObjectPool<TStringList>.Create(
    function: TStringList
    begin
      Result := TStringList.Create;
    end,
    TPoolConfig.Default
  );
  
  FPool.SetResetter(
    procedure(ASL: TStringList)
    begin
      ASL.Clear;
    end
  );
end;

destructor TStringListPool.Destroy;
begin
  FPool.Free;
  inherited;
end;

function TStringListPool.Acquire: TStringList;
begin
  Result := FPool.Acquire;
end;

procedure TStringListPool.Release(ASL: TStringList);
begin
  FPool.Release(ASL);
end;

class function TStringListPool.GetInstance: TStringListPool;
begin
  if FInstance = nil then
  begin
    if FLock = nil then
      FLock := TCriticalSection.Create;
    FLock.Enter;
    try
      if FInstance = nil then
        FInstance := TStringListPool.Create;
    finally
      FLock.Leave;
    end;
  end;
  Result := FInstance;
end;

class procedure TStringListPool.ReleaseInstance;
begin
  if FLock <> nil then
  begin
    FLock.Enter;
    try
      FreeAndNil(FInstance);
    finally
      FLock.Leave;
    end;
    FreeAndNil(FLock);
  end;
end;

// ============================================================================
// TPoolManager
// ============================================================================

constructor TPoolManager.Create;
begin
  inherited Create;
  FPools := TDictionary<string, TObject>.Create;
  FLock := TCriticalSection.Create;
end;

destructor TPoolManager.Destroy;
var
  Pool: TObject;
begin
  FLock.Enter;
  try
    for Pool in FPools.Values do
      Pool.Free;
    FPools.Free;
  finally
    FLock.Leave;
  end;
  FLock.Free;
  inherited;
end;

procedure TPoolManager.RegisterPool(const AName: string; APool: TObject);
begin
  FLock.Enter;
  try
    if FPools.ContainsKey(AName) then
      FPools[AName].Free;
    FPools.AddOrSetValue(AName, APool);
  finally
    FLock.Leave;
  end;
end;

function TPoolManager.GetPool<T>(const AName: string): TObjectPool<T>;
begin
  FLock.Enter;
  try
    if FPools.ContainsKey(AName) then
      Result := TObjectPool<T>(FPools[AName])
    else
      Result := nil;
  finally
    FLock.Leave;
  end;
end;

function TPoolManager.GetAllStats: TJSONObject;
var
  Pair: TPair<string, TObject>;
  PoolStats: TJSONObject;
begin
  Result := TJSONObject.Create;
  FLock.Enter;
  try
    for Pair in FPools do
    begin
      // 尝试获取统计信息 - 简化处理
      PoolStats := TJSONObject.Create;
      PoolStats.AddPair('registered', TJSONBool.Create(True));
      Result.AddPair(Pair.Key, PoolStats);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TPoolManager.ClearAll;
var
  Pool: TObject;
begin
  FLock.Enter;
  try
    for Pool in FPools.Values do
      Pool.Free;
    FPools.Clear;
  finally
    FLock.Leave;
  end;
end;

class function TPoolManager.GetInstance: TPoolManager;
begin
  if FInstance = nil then
    FInstance := TPoolManager.Create;
  Result := FInstance;
end;

class procedure TPoolManager.ReleaseInstance;
begin
  FreeAndNil(FInstance);
end;

// ============================================================================
// TPooledScope<T>
// ============================================================================

class function TPooledScope<T>.Create(APool: TObjectPool<T>): TPooledScope<T>;
begin
  Result.FPool := APool;
  Result.FInstance := APool.Acquire;
end;

procedure TPooledScope<T>.Release;
begin
  if Assigned(FPool) and Assigned(FInstance) then
  begin
    FPool.Release(FInstance);
    FInstance := nil;
  end;
end;

// ============================================================================
// 全局便捷函数
// ============================================================================

function JSONPool: TJSONObjectPool;
begin
  Result := TJSONObjectPool.GetInstance;
end;

function StringBuilderPool: TStringBuilderPool;
begin
  Result := TStringBuilderPool.GetInstance;
end;

function StringListPool: TStringListPool;
begin
  Result := TStringListPool.GetInstance;
end;

function PoolManager: TPoolManager;
begin
  Result := TPoolManager.GetInstance;
end;

initialization

finalization
  TJSONObjectPool.ReleaseInstance;
  TStringBuilderPool.ReleaseInstance;
  TStringListPool.ReleaseInstance;
  TPoolManager.ReleaseInstance;

end.
