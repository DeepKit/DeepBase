{ ============================================================================
  DeepBase.RateLimiter - Rate Limiting Module
  
  A comprehensive rate limiting implementation for API throttling.
  
  Features:
  - Multiple algorithms: Token Bucket, Sliding Window, Fixed Window
  - Thread-safe operations
  - Key-based rate limiting (per-user, per-IP, etc.)
  - Configurable limits and time windows
  - Burst allowance support
  - Rate limit statistics and monitoring
  - Async support with callbacks
  
  Usage:
    // Token Bucket (smooth rate limiting)
    var Limiter := TTokenBucketLimiter.Create(100, 10); // 100 tokens, 10/sec refill
    if Limiter.TryAcquire then
      ProcessRequest;
    
    // Sliding Window (more accurate)
    var Limiter := TSlidingWindowLimiter.Create(100, 60000); // 100 req/minute
    if Limiter.TryAcquire('user123') then
      ProcessRequest;
    
    // Rate Limit Manager (multiple limits)
    RateLimitManager
      .AddLimit('api', TRateLimitConfig.Create.RequestsPerMinute(100))
      .AddLimit('login', TRateLimitConfig.Create.RequestsPerMinute(5));
    
    if RateLimitManager.Check('api', UserIP) then
      ProcessRequest;
  ============================================================================ }

unit DeepBase.RateLimiter;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.SyncObjs,
  System.DateUtils,
  System.Math,
  System.StrUtils;

type
  // ============================================================================
  // Rate Limit Result
  // ============================================================================
  
  TRateLimitResult = record
    Allowed: Boolean;
    Remaining: Integer;
    ResetTime: TDateTime;
    RetryAfterMs: Int64;
    
    class function Allow(ARemaining: Integer; AResetTime: TDateTime): TRateLimitResult; static;
    class function Deny(ARetryAfterMs: Int64; AResetTime: TDateTime): TRateLimitResult; static;
  end;
  
  // ============================================================================
  // Rate Limiter Interface
  // ============================================================================
  
  IRateLimiter = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    function TryAcquire(const Key: string = ''): Boolean;
    function Acquire(const Key: string = ''): TRateLimitResult;
    procedure Reset(const Key: string = '');
    function GetStats(const Key: string = ''): TRateLimitResult;
  end;
  
  // ============================================================================
  // Token Bucket Limiter
  // ============================================================================
  
  /// <summary>
  /// Token Bucket algorithm - smooth rate limiting with burst support
  /// Tokens are added at a constant rate, requests consume tokens
  /// </summary>
  TTokenBucketLimiter = class(TInterfacedObject, IRateLimiter)
  private
    type
      TBucket = record
        Tokens: Double;
        LastRefillTicks: UInt64; // CR-290: 单调时钟, 免疫NTP/DST跳变
      end;
  private
    FCapacity: Integer;           // Maximum tokens
    FRefillRate: Double;          // Tokens per second
    FBuckets: TDictionary<string, TBucket>;
    FLock: TCriticalSection;
    FDefaultKey: string;
    FCleanupCounter: Integer;
    const CLEANUP_THRESHOLD = 100;
    procedure CleanupExpired;
    procedure RefillBucket(var Bucket: TBucket);
    function GetOrCreateBucket(const Key: string): TBucket;
    procedure SaveBucket(const Key: string; const Bucket: TBucket);
  public
    constructor Create(ACapacity: Integer; ARefillRate: Double);
    destructor Destroy; override;
    
    function TryAcquire(const Key: string = ''): Boolean;
    function TryAcquireN(const Key: string; Count: Integer): Boolean;
    function Acquire(const Key: string = ''): TRateLimitResult;
    procedure Reset(const Key: string = '');
    function GetStats(const Key: string = ''): TRateLimitResult;
    
    property Capacity: Integer read FCapacity;
    property RefillRate: Double read FRefillRate;
  end;
  
  // ============================================================================
  // Fixed Window Limiter
  // ============================================================================
  
  /// <summary>
  /// Fixed Window algorithm - simple time-based windows
  /// Counts requests within fixed time intervals
  /// </summary>
  TFixedWindowLimiter = class(TInterfacedObject, IRateLimiter)
  private
    type
      TWindow = record
        Count: Integer;
        StartTicks: UInt64; // CR-290
      end;
  private
    FMaxRequests: Integer;
    FWindowSizeMs: Int64;
    FWindows: TDictionary<string, TWindow>;
    FLock: TCriticalSection;
    FDefaultKey: string;
    procedure CleanupExpired;
    function GetOrCreateWindow(const Key: string): TWindow;
    procedure SaveWindow(const Key: string; const Window: TWindow);
    function IsWindowExpired(const Window: TWindow): Boolean;
  public
    constructor Create(AMaxRequests: Integer; AWindowSizeMs: Int64);
    destructor Destroy; override;
    
    function TryAcquire(const Key: string = ''): Boolean;
    function Acquire(const Key: string = ''): TRateLimitResult;
    procedure Reset(const Key: string = '');
    function GetStats(const Key: string = ''): TRateLimitResult;
    
    property MaxRequests: Integer read FMaxRequests;
    property WindowSizeMs: Int64 read FWindowSizeMs;
  end;
  
  // ============================================================================
  // Sliding Window Limiter
  // ============================================================================
  
  /// <summary>
  /// Sliding Window Log algorithm - most accurate rate limiting
  /// Tracks individual request timestamps
  /// </summary>
  TSlidingWindowLimiter = class(TInterfacedObject, IRateLimiter)
  private
    FMaxRequests: Integer;
    FWindowSizeMs: Int64;
    FRequestLogs: TDictionary<string, TList<UInt64>>;
    FLock: TCriticalSection;
    FDefaultKey: string;
    FCleanupCounter: Integer;
    const CLEANUP_THRESHOLD = 100;
    procedure CleanupExpired;
    function GetOrCreateLog(const Key: string): TList<UInt64>;
    procedure CleanupOldRequests(Log: TList<UInt64>);
  public
    constructor Create(AMaxRequests: Integer; AWindowSizeMs: Int64);
    destructor Destroy; override;
    
    function TryAcquire(const Key: string = ''): Boolean;
    function Acquire(const Key: string = ''): TRateLimitResult;
    procedure Reset(const Key: string = '');
    function GetStats(const Key: string = ''): TRateLimitResult;
    
    property MaxRequests: Integer read FMaxRequests;
    property WindowSizeMs: Int64 read FWindowSizeMs;
  end;
  
  // ============================================================================
  // Sliding Window Counter Limiter
  // ============================================================================
  
  /// <summary>
  /// Sliding Window Counter algorithm - memory efficient approximation
  /// Combines current and previous window counts with weighted average
  /// </summary>
  TSlidingWindowCounterLimiter = class(TInterfacedObject, IRateLimiter)
  private
    type
      TWindowCounter = record
        CurrentCount: Integer;
        PreviousCount: Integer;
        StartTicks: UInt64; // CR-290
      end;
  private
    FMaxRequests: Integer;
    FWindowSizeMs: Int64;
    FCounters: TDictionary<string, TWindowCounter>;
    FLock: TCriticalSection;
    FDefaultKey: string;
    FCleanupCounter: Integer;
    const CLEANUP_THRESHOLD = 100;
    procedure CleanupExpired;
    function GetOrCreateCounter(const Key: string): TWindowCounter;
    procedure SaveCounter(const Key: string; const Counter: TWindowCounter);
    function GetWeightedCount(const Counter: TWindowCounter): Double;
  public
    constructor Create(AMaxRequests: Integer; AWindowSizeMs: Int64);
    destructor Destroy; override;
    
    function TryAcquire(const Key: string = ''): Boolean;
    function Acquire(const Key: string = ''): TRateLimitResult;
    procedure Reset(const Key: string = '');
    function GetStats(const Key: string = ''): TRateLimitResult;
    
    property MaxRequests: Integer read FMaxRequests;
    property WindowSizeMs: Int64 read FWindowSizeMs;
  end;
  
  // ============================================================================
  // Rate Limit Configuration
  // ============================================================================
  
  TRateLimitAlgorithm = (rlaTokenBucket, rlaFixedWindow, rlaSlidingWindow, rlaSlidingWindowCounter);
  
  TRateLimitConfig = class
  private
    FAlgorithm: TRateLimitAlgorithm;
    FMaxRequests: Integer;
    FWindowSizeMs: Int64;
    FBurstSize: Integer;
    FRefillRate: Double;
  public
    constructor Create;
    
    function Algorithm(Value: TRateLimitAlgorithm): TRateLimitConfig;
    function RequestsPerSecond(Value: Integer): TRateLimitConfig;
    function RequestsPerMinute(Value: Integer): TRateLimitConfig;
    function RequestsPerHour(Value: Integer): TRateLimitConfig;
    function RequestsPerDay(Value: Integer): TRateLimitConfig;
    function CustomWindow(MaxReq: Integer; WindowMs: Int64): TRateLimitConfig;
    function BurstSize(Value: Integer): TRateLimitConfig;
    function RefillRate(Value: Double): TRateLimitConfig;
    
    function Build: IRateLimiter;
    
    property AlgorithmType: TRateLimitAlgorithm read FAlgorithm;
    property MaxRequestsValue: Integer read FMaxRequests;
    property WindowSizeMsValue: Int64 read FWindowSizeMs;
    property BurstSizeValue: Integer read FBurstSize;
    property RefillRateValue: Double read FRefillRate;
  end;
  
  // ============================================================================
  // Rate Limit Manager
  // ============================================================================
  
  /// <summary>
  /// Manages multiple rate limiters with different configurations
  /// </summary>
  TRateLimitManager = class
  private
    FLimiters: TDictionary<string, IRateLimiter>;
    FLock: TCriticalSection;
    FFailOpenOnUnknownLimit: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    
    function AddLimit(const Name: string; Config: TRateLimitConfig): TRateLimitManager; overload;
    function AddLimit(const Name: string; Limiter: IRateLimiter): TRateLimitManager; overload;
    function RemoveLimit(const Name: string): TRateLimitManager;
    
    function Check(const LimitName: string; const Key: string = ''): Boolean;
    function CheckAll(const Key: string; const LimitNames: array of string): Boolean;
    function Acquire(const LimitName: string; const Key: string = ''): TRateLimitResult;
    procedure ResetLimit(const LimitName: string; const Key: string = '');
    procedure ResetAll(const Key: string = '');
    
    function GetLimiter(const Name: string): IRateLimiter;
    function HasLimit(const Name: string): Boolean;

    /// <summary>CR-294(Owner 决策B): 限额名不存在时的策略。
    /// False(默认)=fail-closed 拒绝；True=fail-open 放行(仅限非关键路径显式开启)。</summary>
    property FailOpenOnUnknownLimit: Boolean
      read FFailOpenOnUnknownLimit write FFailOpenOnUnknownLimit;
    
    class function Instance: TRateLimitManager;
    class procedure ReleaseInstance;
  end;
  
  // ============================================================================
  // Rate Limit Decorator
  // ============================================================================
  
  TRateLimitedProc = reference to procedure;
  TRateLimitedFunc<T> = reference to function: T;
  TOnRateLimitExceeded = reference to procedure(const Result: TRateLimitResult);
  
  TRateLimitDecorator = class
  private
    FLimiter: IRateLimiter;
    FKey: string;
    FOnExceeded: TOnRateLimitExceeded;
  public
    constructor Create(ALimiter: IRateLimiter; const AKey: string = '');
    
    function OnExceeded(Handler: TOnRateLimitExceeded): TRateLimitDecorator;
    
    function Execute(Proc: TRateLimitedProc): Boolean; overload;
    function Execute<T>(Func: TRateLimitedFunc<T>; out Value: T): Boolean; overload;
    function ExecuteOrWait(Proc: TRateLimitedProc; MaxWaitMs: Integer = 5000): Boolean;
  end;

// Global rate limit manager
function RateLimitManager: TRateLimitManager;

implementation

var
  _RateLimitManager: TRateLimitManager;
  _RateLimitManagerLock: TCriticalSection;

function RateLimitManager: TRateLimitManager;
begin
  if not Assigned(_RateLimitManager) then
  begin
    _RateLimitManagerLock.Enter;
    try
      if not Assigned(_RateLimitManager) then
        _RateLimitManager := TRateLimitManager.Create;
    finally
      _RateLimitManagerLock.Leave;
    end;
  end;
  Result := _RateLimitManager;
end;

// ============================================================================
// TRateLimitResult
// ============================================================================

class function TRateLimitResult.Allow(ARemaining: Integer; AResetTime: TDateTime): TRateLimitResult;
begin
  Result.Allowed := True;
  Result.Remaining := ARemaining;
  Result.ResetTime := AResetTime;
  Result.RetryAfterMs := 0;
end;

class function TRateLimitResult.Deny(ARetryAfterMs: Int64; AResetTime: TDateTime): TRateLimitResult;
begin
  Result.Allowed := False;
  Result.Remaining := 0;
  Result.ResetTime := AResetTime;
  Result.RetryAfterMs := ARetryAfterMs;
end;

// ============================================================================
// TTokenBucketLimiter
// ============================================================================

constructor TTokenBucketLimiter.Create(ACapacity: Integer; ARefillRate: Double);
begin
  inherited Create;
  // BUG-045 FIX: Validate parameters to prevent division by zero
  if ACapacity <= 0 then
    raise EArgumentException.Create('TokenBucket capacity must be positive');
  if ARefillRate <= 0 then
    raise EArgumentException.Create('TokenBucket refill rate must be positive');
  FCapacity := ACapacity;
  FRefillRate := ARefillRate;
  FBuckets := TDictionary<string, TBucket>.Create;
  FLock := TCriticalSection.Create;
  FDefaultKey := '__default__';
end;

destructor TTokenBucketLimiter.Destroy;
begin
  FreeAndNil(FBuckets);
  FreeAndNil(FLock);
  inherited;
end;

procedure TTokenBucketLimiter.RefillBucket(var Bucket: TBucket);
var
  NowTicks: UInt64;
  ElapsedSec: Double;
  TokensToAdd: Double;
begin
  // CR-290: 单调时钟取时间差，NTP 回拨/DST 不再影响补充计算
  NowTicks := TThread.GetTickCount64;
  ElapsedSec := (NowTicks - Bucket.LastRefillTicks) / 1000.0;
  TokensToAdd := ElapsedSec * FRefillRate;

  Bucket.Tokens := Min(FCapacity, Bucket.Tokens + TokensToAdd);
  Bucket.LastRefillTicks := NowTicks;
end;

procedure TTokenBucketLimiter.CleanupExpired;
var
  KeysToRemove: TList<string>;
  Pair: TPair<string, TBucket>;
  NowTicks: UInt64;
  ElapsedSec: Double;
begin
  Inc(FCleanupCounter);
  if (FCleanupCounter < CLEANUP_THRESHOLD) and (FBuckets.Count <= CLEANUP_THRESHOLD) then
    Exit;
  FCleanupCounter := 0;

  KeysToRemove := TList<string>.Create;
  try
    NowTicks := TThread.GetTickCount64;
    for Pair in FBuckets do
    begin
      ElapsedSec := (NowTicks - Pair.Value.LastRefillTicks) / 1000.0;
      if (ElapsedSec * FRefillRate >= FCapacity) then
        KeysToRemove.Add(Pair.Key);
    end;
    for var K in KeysToRemove do
      FBuckets.Remove(K);
  finally
    KeysToRemove.Free;
  end;
end;

function TTokenBucketLimiter.GetOrCreateBucket(const Key: string): TBucket;
var
  ActualKey: string;
begin
  ActualKey := IfThen(Key = '', FDefaultKey, Key);

  if not FBuckets.TryGetValue(ActualKey, Result) then
  begin
    Result.Tokens := FCapacity;
    Result.LastRefillTicks := TThread.GetTickCount64;
  end;
end;

procedure TTokenBucketLimiter.SaveBucket(const Key: string; const Bucket: TBucket);
var
  ActualKey: string;
begin
  ActualKey := IfThen(Key = '', FDefaultKey, Key);
  FBuckets.AddOrSetValue(ActualKey, Bucket);
end;

function TTokenBucketLimiter.TryAcquire(const Key: string): Boolean;
begin
  Result := TryAcquireN(Key, 1);
end;

function TTokenBucketLimiter.TryAcquireN(const Key: string; Count: Integer): Boolean;
var
  Bucket: TBucket;
begin
  FLock.Enter;
  try
    CleanupExpired;
    Bucket := GetOrCreateBucket(Key);
    RefillBucket(Bucket);
    
    if Bucket.Tokens >= Count then
    begin
      Bucket.Tokens := Bucket.Tokens - Count;
      SaveBucket(Key, Bucket);
      Result := True;
    end
    else
      Result := False;
  finally
    FLock.Leave;
  end;
end;

function TTokenBucketLimiter.Acquire(const Key: string): TRateLimitResult;
var
  Bucket: TBucket;
  TokensNeeded: Double;
  WaitTimeMs: Int64;
  ResetTime: TDateTime;
begin
  FLock.Enter;
  try
    CleanupExpired;
    Bucket := GetOrCreateBucket(Key);
    RefillBucket(Bucket);
    
    ResetTime := IncSecond(Now, Ceil((FCapacity - Bucket.Tokens) / FRefillRate));
    
    if Bucket.Tokens >= 1 then
    begin
      Bucket.Tokens := Bucket.Tokens - 1;
      SaveBucket(Key, Bucket);
      Result := TRateLimitResult.Allow(Trunc(Bucket.Tokens), ResetTime);
    end
    else
    begin
      TokensNeeded := 1 - Bucket.Tokens;
      WaitTimeMs := Ceil(TokensNeeded / FRefillRate * 1000);
      Result := TRateLimitResult.Deny(WaitTimeMs, ResetTime);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TTokenBucketLimiter.Reset(const Key: string);
var
  ActualKey: string;
  Bucket: TBucket;
begin
  FLock.Enter;
  try
    ActualKey := IfThen(Key = '', FDefaultKey, Key);
    Bucket.Tokens := FCapacity;
    Bucket.LastRefillTicks := TThread.GetTickCount64;
    FBuckets.AddOrSetValue(ActualKey, Bucket);
  finally
    FLock.Leave;
  end;
end;

function TTokenBucketLimiter.GetStats(const Key: string): TRateLimitResult;
var
  Bucket: TBucket;
begin
  FLock.Enter;
  try
    CleanupExpired;
    Bucket := GetOrCreateBucket(Key);
    RefillBucket(Bucket);
    Result := TRateLimitResult.Allow(Trunc(Bucket.Tokens),
      IncSecond(Now, Ceil((FCapacity - Bucket.Tokens) / FRefillRate)));
  finally
    FLock.Leave;
  end;
end;

// ============================================================================
// TFixedWindowLimiter
// ============================================================================

constructor TFixedWindowLimiter.Create(AMaxRequests: Integer; AWindowSizeMs: Int64);
begin
  inherited Create;
  // CR-294: 参数校验对齐 TokenBucket(BUG-045)——窗口 0 会使限流完全失效,
  // MaxRequests<=0 则全拒绝
  if AMaxRequests <= 0 then
    raise EArgumentException.Create('RateLimiter: AMaxRequests must be > 0');
  if AWindowSizeMs <= 0 then
    raise EArgumentException.Create('RateLimiter: AWindowSizeMs must be > 0');
  FMaxRequests := AMaxRequests;
  FWindowSizeMs := AWindowSizeMs;
  FWindows := TDictionary<string, TWindow>.Create;
  FLock := TCriticalSection.Create;
  FDefaultKey := '__default__';
end;

destructor TFixedWindowLimiter.Destroy;
begin
  FreeAndNil(FWindows);
  FreeAndNil(FLock);
  inherited;
end;

procedure TFixedWindowLimiter.CleanupExpired;
var
  KeysToRemove: TList<string>;
  Pair: TPair<string, TWindow>;
begin
  KeysToRemove := TList<string>.Create;
  try
    for Pair in FWindows do
    begin
      if IsWindowExpired(Pair.Value) and (Pair.Value.Count = 0) then
        KeysToRemove.Add(Pair.Key);
    end;
    for var K in KeysToRemove do
      FWindows.Remove(K);
  finally
    KeysToRemove.Free;
  end;
end;

function TFixedWindowLimiter.GetOrCreateWindow(const Key: string): TWindow;
var
  ActualKey: string;
begin
  ActualKey := IfThen(Key = '', FDefaultKey, Key);
  
  if not FWindows.TryGetValue(ActualKey, Result) then
  begin
    Result.Count := 0;
    Result.StartTicks := TThread.GetTickCount64;
  end;
end;

procedure TFixedWindowLimiter.SaveWindow(const Key: string; const Window: TWindow);
var
  ActualKey: string;
begin
  ActualKey := IfThen(Key = '', FDefaultKey, Key);
  FWindows.AddOrSetValue(ActualKey, Window);
end;

function TFixedWindowLimiter.IsWindowExpired(const Window: TWindow): Boolean;
var
  ElapsedMs: Int64;
begin
  // CR-290: 单调时钟差值
  ElapsedMs := Int64(TThread.GetTickCount64 - Window.StartTicks);
  Result := ElapsedMs >= FWindowSizeMs;
end;

function TFixedWindowLimiter.TryAcquire(const Key: string): Boolean;
var
  Window: TWindow;
begin
  FLock.Enter;
  try
    CleanupExpired;
    Window := GetOrCreateWindow(Key);
    
    if IsWindowExpired(Window) and (Window.Count = 0) then
    begin
      FWindows.Remove(IfThen(Key = '', FDefaultKey, Key));
      Window := GetOrCreateWindow(Key);
    end
    else if IsWindowExpired(Window) then
    begin
      Window.Count := 0;
      Window.StartTicks := TThread.GetTickCount64;
    end;
    
    if Window.Count < FMaxRequests then
    begin
      Inc(Window.Count);
      SaveWindow(Key, Window);
      Result := True;
    end
    else
      Result := False;
  finally
    FLock.Leave;
  end;
end;

function TFixedWindowLimiter.Acquire(const Key: string): TRateLimitResult;
var
  Window: TWindow;
  ResetTime: TDateTime;
  RetryAfterMs: Int64;
begin
  FLock.Enter;
  try
    CleanupExpired;
    Window := GetOrCreateWindow(Key);
    
    if IsWindowExpired(Window) and (Window.Count = 0) then
    begin
      FWindows.Remove(IfThen(Key = '', FDefaultKey, Key));
      Window := GetOrCreateWindow(Key);
    end
    else if IsWindowExpired(Window) then
    begin
      Window.Count := 0;
      Window.StartTicks := TThread.GetTickCount64;
    end;
    
    // CR-290: 窗口起始为单调刻度, 展示墙钟按剩余时间近似还原
    ResetTime := IncMilliSecond(Now, FWindowSizeMs - Int64(TThread.GetTickCount64 - Window.StartTicks));
    
    if Window.Count < FMaxRequests then
    begin
      Inc(Window.Count);
      SaveWindow(Key, Window);
      Result := TRateLimitResult.Allow(FMaxRequests - Window.Count, ResetTime);
    end
    else
    begin
      // CR-290: 窗口起始刻度 + 窗口长 即为解禁时刻
      RetryAfterMs := Int64(Window.StartTicks + UInt64(FWindowSizeMs)) - Int64(TThread.GetTickCount64);
      if RetryAfterMs < 0 then RetryAfterMs := 0;
      Result := TRateLimitResult.Deny(RetryAfterMs, ResetTime);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TFixedWindowLimiter.Reset(const Key: string);
var
  ActualKey: string;
  Window: TWindow;
begin
  FLock.Enter;
  try
    ActualKey := IfThen(Key = '', FDefaultKey, Key);
    Window.Count := 0;
    Window.StartTicks := TThread.GetTickCount64;
    FWindows.AddOrSetValue(ActualKey, Window);
  finally
    FLock.Leave;
  end;
end;

function TFixedWindowLimiter.GetStats(const Key: string): TRateLimitResult;
var
  Window: TWindow;
begin
  FLock.Enter;
  try
    CleanupExpired;
    Window := GetOrCreateWindow(Key);
    
    if IsWindowExpired(Window) then
      Result := TRateLimitResult.Allow(FMaxRequests, IncMilliSecond(Now, FWindowSizeMs))
    else
      Result := TRateLimitResult.Allow(FMaxRequests - Window.Count,
        IncMilliSecond(Now, FWindowSizeMs - Int64(TThread.GetTickCount64 - Window.StartTicks)));
  finally
    FLock.Leave;
  end;
end;

// ============================================================================
// TSlidingWindowLimiter
// ============================================================================

constructor TSlidingWindowLimiter.Create(AMaxRequests: Integer; AWindowSizeMs: Int64);
begin
  inherited Create;
  // CR-294: 参数校验对齐 TokenBucket(BUG-045)——窗口 0 会使限流完全失效,
  // MaxRequests<=0 则全拒绝
  if AMaxRequests <= 0 then
    raise EArgumentException.Create('RateLimiter: AMaxRequests must be > 0');
  if AWindowSizeMs <= 0 then
    raise EArgumentException.Create('RateLimiter: AWindowSizeMs must be > 0');
  FMaxRequests := AMaxRequests;
  FWindowSizeMs := AWindowSizeMs;
  FRequestLogs := TDictionary<string, TList<UInt64>>.Create;
  FLock := TCriticalSection.Create;
  FDefaultKey := '__default__';
end;

destructor TSlidingWindowLimiter.Destroy;
var
  Pair: TPair<string, TList<UInt64>>;
begin
  for Pair in FRequestLogs do
    Pair.Value.Free;
  FreeAndNil(FRequestLogs);
  FreeAndNil(FLock);
  inherited;
end;

procedure TSlidingWindowLimiter.CleanupExpired;
var
  KeysToRemove: TList<string>;
  Pair: TPair<string, TList<UInt64>>;
begin
  Inc(FCleanupCounter);
  if (FCleanupCounter < CLEANUP_THRESHOLD) and (FRequestLogs.Count <= CLEANUP_THRESHOLD) then
    Exit;
  FCleanupCounter := 0;

  KeysToRemove := TList<string>.Create;
  try
    for Pair in FRequestLogs do
    begin
      CleanupOldRequests(Pair.Value);
      if Pair.Value.Count = 0 then
        KeysToRemove.Add(Pair.Key);
    end;
    for var K in KeysToRemove do
    begin
      FRequestLogs[K].Free;
      FRequestLogs.Remove(K);
    end;
  finally
    KeysToRemove.Free;
  end;
end;

function TSlidingWindowLimiter.GetOrCreateLog(const Key: string): TList<UInt64>;
var
  ActualKey: string;
begin
  ActualKey := IfThen(Key = '', FDefaultKey, Key);
  
  if not FRequestLogs.TryGetValue(ActualKey, Result) then
  begin
    Result := TList<UInt64>.Create;
    FRequestLogs.Add(ActualKey, Result);
  end;
end;

procedure TSlidingWindowLimiter.CleanupOldRequests(Log: TList<UInt64>);
var
  Cutoff: UInt64;
  I: Integer;
begin
  // CR-290: 单调刻度截止线
  Cutoff := TThread.GetTickCount64 - UInt64(FWindowSizeMs);
  
  // Remove old requests from beginning of list
  I := 0;
  while (I < Log.Count) and (Log[I] < Cutoff) do
    Inc(I);
  
  if I > 0 then
    Log.DeleteRange(0, I);
end;

function TSlidingWindowLimiter.TryAcquire(const Key: string): Boolean;
var
  Log: TList<UInt64>;
begin
  FLock.Enter;
  try
    CleanupExpired;
    Log := GetOrCreateLog(Key);
    CleanupOldRequests(Log);
    
    if Log.Count < FMaxRequests then
    begin
      Log.Add(TThread.GetTickCount64);
      Result := True;
    end
    else
      Result := False;
  finally
    FLock.Leave;
  end;
end;

function TSlidingWindowLimiter.Acquire(const Key: string): TRateLimitResult;
var
  Log: TList<UInt64>;
  ResetTime: TDateTime;
  RetryAfterMs: Int64;
begin
  FLock.Enter;
  try
    CleanupExpired;
    Log := GetOrCreateLog(Key);
    CleanupOldRequests(Log);
    
    // CR-290: Log[0] 为单调刻度, 展示墙钟按剩余时间近似还原
    if Log.Count > 0 then
      ResetTime := IncMilliSecond(Now, Int64(UInt64(FWindowSizeMs) + Log[0] - TThread.GetTickCount64))
    else
      ResetTime := IncMilliSecond(Now, FWindowSizeMs);
    
    if Log.Count < FMaxRequests then
    begin
      Log.Add(TThread.GetTickCount64);
      Result := TRateLimitResult.Allow(FMaxRequests - Log.Count, ResetTime);
    end
    else
    begin
      // CR-290: 队首请求刻度 + 窗口长 即为解禁时刻（SlidingWindow 用 Log[0]）
      RetryAfterMs := Int64(UInt64(FWindowSizeMs) + Log[0] - TThread.GetTickCount64);
      if RetryAfterMs < 0 then RetryAfterMs := 0;
      Result := TRateLimitResult.Deny(RetryAfterMs, ResetTime);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TSlidingWindowLimiter.Reset(const Key: string);
var
  Log: TList<UInt64>;
begin
  FLock.Enter;
  try
    CleanupExpired;
    Log := GetOrCreateLog(Key);
    Log.Clear;
  finally
    FLock.Leave;
  end;
end;

function TSlidingWindowLimiter.GetStats(const Key: string): TRateLimitResult;
var
  Log: TList<UInt64>;
  ResetTime: TDateTime;
begin
  FLock.Enter;
  try
    CleanupExpired;
    Log := GetOrCreateLog(Key);
    CleanupOldRequests(Log);
    
    // CR-290: Log[0] 为单调刻度, 展示墙钟按剩余时间近似还原
    if Log.Count > 0 then
      ResetTime := IncMilliSecond(Now, Int64(UInt64(FWindowSizeMs) + Log[0] - TThread.GetTickCount64))
    else
      ResetTime := IncMilliSecond(Now, FWindowSizeMs);
    
    Result := TRateLimitResult.Allow(FMaxRequests - Log.Count, ResetTime);
  finally
    FLock.Leave;
  end;
end;

// ============================================================================
// TSlidingWindowCounterLimiter
// ============================================================================

constructor TSlidingWindowCounterLimiter.Create(AMaxRequests: Integer; AWindowSizeMs: Int64);
begin
  inherited Create;
  // CR-294: 参数校验对齐 TokenBucket(BUG-045)——窗口 0 会使限流完全失效,
  // MaxRequests<=0 则全拒绝
  if AMaxRequests <= 0 then
    raise EArgumentException.Create('RateLimiter: AMaxRequests must be > 0');
  if AWindowSizeMs <= 0 then
    raise EArgumentException.Create('RateLimiter: AWindowSizeMs must be > 0');
  FMaxRequests := AMaxRequests;
  FWindowSizeMs := AWindowSizeMs;
  FCounters := TDictionary<string, TWindowCounter>.Create;
  FLock := TCriticalSection.Create;
  FDefaultKey := '__default__';
end;

destructor TSlidingWindowCounterLimiter.Destroy;
begin
  FreeAndNil(FCounters);
  FreeAndNil(FLock);
  inherited;
end;

procedure TSlidingWindowCounterLimiter.CleanupExpired;
var
  KeysToRemove: TList<string>;
  Pair: TPair<string, TWindowCounter>;
  ElapsedMs: Int64;
begin
  Inc(FCleanupCounter);
  if (FCleanupCounter < CLEANUP_THRESHOLD) and (FCounters.Count <= CLEANUP_THRESHOLD) then
    Exit;
  FCleanupCounter := 0;

  KeysToRemove := TList<string>.Create;
  try
    for Pair in FCounters do
    begin
      ElapsedMs := Int64(TThread.GetTickCount64 - Pair.Value.StartTicks);
      if (ElapsedMs >= FWindowSizeMs * 2)
        and (Pair.Value.CurrentCount = 0)
        and (Pair.Value.PreviousCount = 0) then
        KeysToRemove.Add(Pair.Key);
    end;
    for var K in KeysToRemove do
      FCounters.Remove(K);
  finally
    KeysToRemove.Free;
  end;
end;

function TSlidingWindowCounterLimiter.GetOrCreateCounter(const Key: string): TWindowCounter;
var
  ActualKey: string;
begin
  ActualKey := IfThen(Key = '', FDefaultKey, Key);
  
  if not FCounters.TryGetValue(ActualKey, Result) then
  begin
    Result.CurrentCount := 0;
    Result.PreviousCount := 0;
    Result.StartTicks := TThread.GetTickCount64;
  end;
end;

procedure TSlidingWindowCounterLimiter.SaveCounter(const Key: string; const Counter: TWindowCounter);
var
  ActualKey: string;
begin
  ActualKey := IfThen(Key = '', FDefaultKey, Key);
  FCounters.AddOrSetValue(ActualKey, Counter);
end;

function TSlidingWindowCounterLimiter.GetWeightedCount(const Counter: TWindowCounter): Double;
var
  ElapsedMs: Int64;
  ProgressRatio: Double;
begin
  ElapsedMs := Int64(TThread.GetTickCount64 - Counter.StartTicks);
  
  // Handle window transitions
  if ElapsedMs >= FWindowSizeMs * 2 then
  begin
    // More than 2 windows have passed, count is 0
    Result := 0;
  end
  else if ElapsedMs >= FWindowSizeMs then
  begin
    // In the next window, previous = current, current = 0
    ProgressRatio := (ElapsedMs - FWindowSizeMs) / FWindowSizeMs;
    Result := Counter.CurrentCount * (1 - ProgressRatio);
  end
  else
  begin
    // Still in current window
    ProgressRatio := ElapsedMs / FWindowSizeMs;
    Result := Counter.PreviousCount * (1 - ProgressRatio) + Counter.CurrentCount;
  end;
end;

function TSlidingWindowCounterLimiter.TryAcquire(const Key: string): Boolean;
var
  Counter: TWindowCounter;
  ElapsedMs: Int64;
  WeightedCount: Double;
begin
  FLock.Enter;
  try
    CleanupExpired;
    Counter := GetOrCreateCounter(Key);
    ElapsedMs := Int64(TThread.GetTickCount64 - Counter.StartTicks);
    
    // Handle window transitions
    if ElapsedMs >= FWindowSizeMs * 2 then
    begin
      if (Counter.CurrentCount = 0) and (Counter.PreviousCount = 0) then
      begin
        FCounters.Remove(IfThen(Key = '', FDefaultKey, Key));
        Counter := GetOrCreateCounter(Key);
      end
      else
      begin
        Counter.PreviousCount := 0;
        Counter.CurrentCount := 0;
        Counter.StartTicks := TThread.GetTickCount64;
      end;
    end
    else if ElapsedMs >= FWindowSizeMs then
    begin
      Counter.PreviousCount := Counter.CurrentCount;
      Counter.CurrentCount := 0;
      Counter.StartTicks := Counter.StartTicks + UInt64(FWindowSizeMs);
    end;
    
    WeightedCount := GetWeightedCount(Counter);
    
    if WeightedCount < FMaxRequests then
    begin
      Inc(Counter.CurrentCount);
      SaveCounter(Key, Counter);
      Result := True;
    end
    else
      Result := False;
  finally
    FLock.Leave;
  end;
end;

function TSlidingWindowCounterLimiter.Acquire(const Key: string): TRateLimitResult;
var
  Counter: TWindowCounter;
  ElapsedMs: Int64;
  WeightedCount: Double;
  ResetTime: TDateTime;
  RetryAfterMs: Int64;
begin
  FLock.Enter;
  try
    CleanupExpired;
    Counter := GetOrCreateCounter(Key);
    ElapsedMs := Int64(TThread.GetTickCount64 - Counter.StartTicks);
    
    // Handle window transitions
    if ElapsedMs >= FWindowSizeMs * 2 then
    begin
      if (Counter.CurrentCount = 0) and (Counter.PreviousCount = 0) then
      begin
        FCounters.Remove(IfThen(Key = '', FDefaultKey, Key));
        Counter := GetOrCreateCounter(Key);
      end
      else
      begin
        Counter.PreviousCount := 0;
        Counter.CurrentCount := 0;
        Counter.StartTicks := TThread.GetTickCount64;
      end;
    end
    else if ElapsedMs >= FWindowSizeMs then
    begin
      Counter.PreviousCount := Counter.CurrentCount;
      Counter.CurrentCount := 0;
      Counter.StartTicks := Counter.StartTicks + UInt64(FWindowSizeMs);
    end;
    
    WeightedCount := GetWeightedCount(Counter);
    ResetTime := IncMilliSecond(Now, FWindowSizeMs - Int64(TThread.GetTickCount64 - Counter.StartTicks));
    
    if WeightedCount < FMaxRequests then
    begin
      Inc(Counter.CurrentCount);
      SaveCounter(Key, Counter);
      Result := TRateLimitResult.Allow(Trunc(FMaxRequests - WeightedCount - 1), ResetTime);
    end
    else
    begin
      // CR-290: 当前窗口起始刻度 + 窗口长 即为本窗解禁时刻
      RetryAfterMs := Int64(Counter.StartTicks + UInt64(FWindowSizeMs)) - Int64(TThread.GetTickCount64);
      if RetryAfterMs < 0 then RetryAfterMs := 0;
      Result := TRateLimitResult.Deny(RetryAfterMs, ResetTime);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TSlidingWindowCounterLimiter.Reset(const Key: string);
var
  ActualKey: string;
  Counter: TWindowCounter;
begin
  FLock.Enter;
  try
    ActualKey := IfThen(Key = '', FDefaultKey, Key);
    Counter.CurrentCount := 0;
    Counter.PreviousCount := 0;
    Counter.StartTicks := TThread.GetTickCount64;
    FCounters.AddOrSetValue(ActualKey, Counter);
  finally
    FLock.Leave;
  end;
end;

function TSlidingWindowCounterLimiter.GetStats(const Key: string): TRateLimitResult;
var
  Counter: TWindowCounter;
  WeightedCount: Double;
  ResetTime: TDateTime;
begin
  FLock.Enter;
  try
    CleanupExpired;
    Counter := GetOrCreateCounter(Key);
    WeightedCount := GetWeightedCount(Counter);
    ResetTime := IncMilliSecond(Now, FWindowSizeMs - Int64(TThread.GetTickCount64 - Counter.StartTicks));
    Result := TRateLimitResult.Allow(Trunc(FMaxRequests - WeightedCount), ResetTime);
  finally
    FLock.Leave;
  end;
end;

// ============================================================================
// TRateLimitConfig
// ============================================================================

constructor TRateLimitConfig.Create;
begin
  inherited Create;
  FAlgorithm := rlaSlidingWindowCounter;
  FMaxRequests := 100;
  FWindowSizeMs := 60000; // 1 minute
  FBurstSize := 0;
  FRefillRate := 0;
end;

function TRateLimitConfig.Algorithm(Value: TRateLimitAlgorithm): TRateLimitConfig;
begin
  FAlgorithm := Value;
  Result := Self;
end;

function TRateLimitConfig.RequestsPerSecond(Value: Integer): TRateLimitConfig;
begin
  FMaxRequests := Value;
  FWindowSizeMs := 1000;
  Result := Self;
end;

function TRateLimitConfig.RequestsPerMinute(Value: Integer): TRateLimitConfig;
begin
  FMaxRequests := Value;
  FWindowSizeMs := 60000;
  Result := Self;
end;

function TRateLimitConfig.RequestsPerHour(Value: Integer): TRateLimitConfig;
begin
  FMaxRequests := Value;
  FWindowSizeMs := 3600000;
  Result := Self;
end;

function TRateLimitConfig.RequestsPerDay(Value: Integer): TRateLimitConfig;
begin
  FMaxRequests := Value;
  FWindowSizeMs := 86400000;
  Result := Self;
end;

function TRateLimitConfig.CustomWindow(MaxReq: Integer; WindowMs: Int64): TRateLimitConfig;
begin
  FMaxRequests := MaxReq;
  FWindowSizeMs := WindowMs;
  Result := Self;
end;

function TRateLimitConfig.BurstSize(Value: Integer): TRateLimitConfig;
begin
  FBurstSize := Value;
  Result := Self;
end;

function TRateLimitConfig.RefillRate(Value: Double): TRateLimitConfig;
begin
  FRefillRate := Value;
  Result := Self;
end;

function TRateLimitConfig.Build: IRateLimiter;
var
  EffectiveBurst: Integer;
  EffectiveRefillRate: Double;
begin
  case FAlgorithm of
    rlaTokenBucket:
    begin
      EffectiveBurst := IfThen(FBurstSize > 0, FBurstSize, FMaxRequests);
      EffectiveRefillRate := FRefillRate;
      if EffectiveRefillRate <= 0 then
        EffectiveRefillRate := FMaxRequests / (FWindowSizeMs / 1000);
      Result := TTokenBucketLimiter.Create(EffectiveBurst, EffectiveRefillRate);
    end;
    
    rlaFixedWindow:
      Result := TFixedWindowLimiter.Create(FMaxRequests, FWindowSizeMs);
    
    rlaSlidingWindow:
      Result := TSlidingWindowLimiter.Create(FMaxRequests, FWindowSizeMs);
    
    rlaSlidingWindowCounter:
      Result := TSlidingWindowCounterLimiter.Create(FMaxRequests, FWindowSizeMs);
  else
    Result := TSlidingWindowCounterLimiter.Create(FMaxRequests, FWindowSizeMs);
  end;
end;

// ============================================================================
// TRateLimitManager
// ============================================================================

constructor TRateLimitManager.Create;
begin
  inherited Create;
  FLimiters := TDictionary<string, IRateLimiter>.Create;
  FLock := TCriticalSection.Create;
  // CR-294(Owner 决策B): 默认 fail-closed——限额名不存在(拼写错误/配置
  // 未加载)时拒绝并保持可观测，而非静默放行裸奔。非关键路径可显式打开。
  FFailOpenOnUnknownLimit := False;
end;

destructor TRateLimitManager.Destroy;
begin
  FreeAndNil(FLimiters);
  FreeAndNil(FLock);
  inherited;
end;

function TRateLimitManager.AddLimit(const Name: string; Config: TRateLimitConfig): TRateLimitManager;
begin
  FLock.Enter;
  try
    FLimiters.AddOrSetValue(Name, Config.Build);
  finally
    FLock.Leave;
    Config.Free;
  end;
  Result := Self;
end;

function TRateLimitManager.AddLimit(const Name: string; Limiter: IRateLimiter): TRateLimitManager;
begin
  FLock.Enter;
  try
    FLimiters.AddOrSetValue(Name, Limiter);
  finally
    FLock.Leave;
  end;
  Result := Self;
end;

function TRateLimitManager.RemoveLimit(const Name: string): TRateLimitManager;
begin
  FLock.Enter;
  try
    FLimiters.Remove(Name);
  finally
    FLock.Leave;
  end;
  Result := Self;
end;

function TRateLimitManager.Check(const LimitName: string; const Key: string): Boolean;
var
  Limiter: IRateLimiter;
begin
  FLock.Enter;
  try
    // CR-294(Owner 决策B): 未知限额默认拒绝(fail-closed)，拼写错误/配置
    // 未加载不再静默放行；非关键路径可经 FailOpenOnUnknownLimit 显式放行
    if FLimiters.TryGetValue(LimitName, Limiter) then
      Result := Limiter.TryAcquire(Key)
    else
      Result := FFailOpenOnUnknownLimit;
  finally
    FLock.Leave;
  end;
end;

function TRateLimitManager.CheckAll(const Key: string; const LimitNames: array of string): Boolean;
var
  Name: string;
begin
  Result := True;
  for Name in LimitNames do
  begin
    if not Check(Name, Key) then
    begin
      Result := False;
      Break;
    end;
  end;
end;

function TRateLimitManager.Acquire(const LimitName: string; const Key: string): TRateLimitResult;
var
  Limiter: IRateLimiter;
begin
  FLock.Enter;
  try
    // CR-294(Owner 决策B): 与 Check 同策略；拒绝时给 60s 重试窗口，
    // 避免调用方 ExecuteOrWait 拿到 0 值陷入忙等
    if FLimiters.TryGetValue(LimitName, Limiter) then
      Result := Limiter.Acquire(Key)
    else if FFailOpenOnUnknownLimit then
      Result := TRateLimitResult.Allow(MaxInt, Now)
    else
      Result := TRateLimitResult.Deny(60000, Now);
  finally
    FLock.Leave;
  end;
end;

procedure TRateLimitManager.ResetLimit(const LimitName: string; const Key: string);
var
  Limiter: IRateLimiter;
begin
  FLock.Enter;
  try
    if FLimiters.TryGetValue(LimitName, Limiter) then
      Limiter.Reset(Key);
  finally
    FLock.Leave;
  end;
end;

procedure TRateLimitManager.ResetAll(const Key: string);
var
  Pair: TPair<string, IRateLimiter>;
begin
  FLock.Enter;
  try
    for Pair in FLimiters do
      Pair.Value.Reset(Key);
  finally
    FLock.Leave;
  end;
end;

function TRateLimitManager.GetLimiter(const Name: string): IRateLimiter;
begin
  FLock.Enter;
  try
    if not FLimiters.TryGetValue(Name, Result) then
      Result := nil;
  finally
    FLock.Leave;
  end;
end;

function TRateLimitManager.HasLimit(const Name: string): Boolean;
begin
  FLock.Enter;
  try
    Result := FLimiters.ContainsKey(Name);
  finally
    FLock.Leave;
  end;
end;

class function TRateLimitManager.Instance: TRateLimitManager;
begin
  Result := RateLimitManager;
end;

class procedure TRateLimitManager.ReleaseInstance;
begin
  _RateLimitManagerLock.Enter;
  try
    FreeAndNil(_RateLimitManager);
  finally
    _RateLimitManagerLock.Leave;
  end;
end;

// ============================================================================
// TRateLimitDecorator
// ============================================================================

constructor TRateLimitDecorator.Create(ALimiter: IRateLimiter; const AKey: string);
begin
  inherited Create;
  FLimiter := ALimiter;
  FKey := AKey;
end;

function TRateLimitDecorator.OnExceeded(Handler: TOnRateLimitExceeded): TRateLimitDecorator;
begin
  FOnExceeded := Handler;
  Result := Self;
end;

function TRateLimitDecorator.Execute(Proc: TRateLimitedProc): Boolean;
var
  R: TRateLimitResult;
begin
  R := FLimiter.Acquire(FKey);
  Result := R.Allowed;
  
  if Result then
    Proc
  else if Assigned(FOnExceeded) then
    FOnExceeded(R);
end;

function TRateLimitDecorator.Execute<T>(Func: TRateLimitedFunc<T>; out Value: T): Boolean;
var
  R: TRateLimitResult;
begin
  R := FLimiter.Acquire(FKey);
  Result := R.Allowed;
  
  if Result then
    Value := Func
  else
  begin
    Value := Default(T);
    if Assigned(FOnExceeded) then
      FOnExceeded(R);
  end;
end;

function TRateLimitDecorator.ExecuteOrWait(Proc: TRateLimitedProc; MaxWaitMs: Integer): Boolean;
var
  R: TRateLimitResult;
  WaitedMs: Int64;
begin
  WaitedMs := 0;
  
  repeat
    R := FLimiter.Acquire(FKey);
    if R.Allowed then
    begin
      Proc;
      Exit(True);
    end;
    
    if R.RetryAfterMs + WaitedMs > MaxWaitMs then
      Exit(False);
    
    Sleep(Min(R.RetryAfterMs, MaxWaitMs - WaitedMs));
    Inc(WaitedMs, R.RetryAfterMs);
  until WaitedMs >= MaxWaitMs;
  
  Result := False;
end;

initialization
  _RateLimitManagerLock := TCriticalSection.Create;

finalization
  FreeAndNil(_RateLimitManager);
  FreeAndNil(_RateLimitManagerLock);

end.
