unit Test.DeepBase.RateLimiter;

{*******************************************************************************
  DeepBase RateLimiter Module Unit Tests
  
  Test Coverage:
  - Token Bucket algorithm
  - Fixed Window algorithm
  - Sliding Window algorithm
  - Sliding Window Counter algorithm
  - Rate Limit Configuration fluent API
  - Rate Limit Manager
  - Rate Limit Decorator
  - Key-based rate limiting
  - Thread safety
  - Result handling (Allow/Deny)
*******************************************************************************}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Threading,
  System.DateUtils,
  DeepBase.RateLimiter;

type
  [TestFixture]
  TTestTokenBucketLimiter = class
  public
    [Test]
    procedure Test_InitialCapacity_AllowsRequests;
    
    [Test]
    procedure Test_ExceedCapacity_DeniesRequests;
    
    [Test]
    procedure Test_RefillRate_AddsTokensOverTime;
    
    [Test]
    procedure Test_TryAcquireN_ConsumesMultipleTokens;
    
    [Test]
    procedure Test_Reset_RestoresCapacity;
    
    [Test]
    procedure Test_GetStats_ReturnsRemainingTokens;
    
    [Test]
    procedure Test_KeyBased_IndependentBuckets;
    
    [Test]
    procedure Test_Acquire_ReturnsResult;
  end;

  [TestFixture]
  TTestFixedWindowLimiter = class
  public
    [Test]
    procedure Test_WithinLimit_AllowsRequests;
    
    [Test]
    procedure Test_ExceedLimit_DeniesRequests;
    
    [Test]
    procedure Test_WindowReset_AllowsNewRequests;
    
    [Test]
    procedure Test_Reset_ClearsCounter;
    
    [Test]
    procedure Test_GetStats_ReturnsRemaining;
    
    [Test]
    procedure Test_KeyBased_IndependentWindows;
    
    [Test]
    procedure Test_Acquire_ReturnsResetTime;
  end;

  [TestFixture]
  TTestSlidingWindowLimiter = class
  public
    [Test]
    procedure Test_WithinLimit_AllowsRequests;
    
    [Test]
    procedure Test_ExceedLimit_DeniesRequests;
    
    [Test]
    procedure Test_OldRequestsExpire_AllowsNewRequests;
    
    [Test]
    procedure Test_Reset_ClearsLog;
    
    [Test]
    procedure Test_GetStats_ReturnsAccurateRemaining;
    
    [Test]
    procedure Test_KeyBased_IndependentLogs;
  end;

  [TestFixture]
  TTestSlidingWindowCounterLimiter = class
  public
    [Test]
    procedure Test_WithinLimit_AllowsRequests;
    
    [Test]
    procedure Test_ExceedLimit_DeniesRequests;
    
    [Test]
    procedure Test_WindowTransition_WeightedCount;
    
    [Test]
    procedure Test_Reset_ClearsCounters;
    
    [Test]
    procedure Test_KeyBased_IndependentCounters;
  end;

  [TestFixture]
  TTestRateLimitConfig = class
  public
    [Test]
    procedure Test_RequestsPerSecond;
    
    [Test]
    procedure Test_RequestsPerMinute;
    
    [Test]
    procedure Test_RequestsPerHour;
    
    [Test]
    procedure Test_RequestsPerDay;
    
    [Test]
    procedure Test_CustomWindow;
    
    [Test]
    procedure Test_Algorithm_TokenBucket;
    
    [Test]
    procedure Test_Algorithm_FixedWindow;
    
    [Test]
    procedure Test_Algorithm_SlidingWindow;
    
    [Test]
    procedure Test_BurstSize;
    
    [Test]
    procedure Test_Build_CreatesLimiter;
  end;

  [TestFixture]
  TTestRateLimitManager = class
  private
    FManager: TRateLimitManager;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_AddLimit_WithConfig;
    
    [Test]
    procedure Test_AddLimit_WithLimiter;
    
    [Test]
    procedure Test_RemoveLimit;
    
    [Test]
    procedure Test_Check_ExistingLimit;
    
    [Test]
    procedure Test_Check_NonExistentLimit;
    
    [Test]
    procedure Test_CheckAll_AllPass;
    
    [Test]
    procedure Test_CheckAll_OneFails;
    
    [Test]
    procedure Test_Acquire_ReturnsResult;
    
    [Test]
    procedure Test_ResetLimit;
    
    [Test]
    procedure Test_ResetAll;
    
    [Test]
    procedure Test_HasLimit;
    
    [Test]
    procedure Test_GetLimiter;
  end;

  [TestFixture]
  TTestRateLimitDecorator = class
  public
    [Test]
    procedure Test_Execute_WithinLimit_Executes;
    
    [Test]
    procedure Test_Execute_ExceedLimit_NotExecuted;
    
    [Test]
    procedure Test_ExecuteFunc_ReturnsValue;
    
    [Test]
    procedure Test_OnExceeded_CalledWhenDenied;
    
    [Test]
    procedure Test_ExecuteOrWait_WaitsForToken;
  end;

  [TestFixture]
  TTestRateLimitResult = class
  public
    [Test]
    procedure Test_Allow_SetsAllowedTrue;
    
    [Test]
    procedure Test_Deny_SetsAllowedFalse;
    
    [Test]
    procedure Test_Allow_SetsRemaining;
    
    [Test]
    procedure Test_Deny_SetsRetryAfter;
  end;

  [TestFixture]
  TTestRateLimiterThreadSafety = class
  public
    [Test]
    procedure Test_TokenBucket_ConcurrentAccess;
    
    [Test]
    procedure Test_FixedWindow_ConcurrentAccess;
    
    [Test]
    procedure Test_SlidingWindow_ConcurrentAccess;
    
    [Test]
    procedure Test_Manager_ConcurrentAccess;
  end;

implementation

{ TTestTokenBucketLimiter }

procedure TTestTokenBucketLimiter.Test_InitialCapacity_AllowsRequests;
var
  Limiter: TTokenBucketLimiter;
  I: Integer;
begin
  Limiter := TTokenBucketLimiter.Create(10, 1.0);
  try
    // Should allow 10 requests (initial capacity)
    for I := 1 to 10 do
      Assert.IsTrue(Limiter.TryAcquire, Format('Request %d should be allowed', [I]));
  finally
    Limiter.Free;
  end;
end;

procedure TTestTokenBucketLimiter.Test_ExceedCapacity_DeniesRequests;
var
  Limiter: TTokenBucketLimiter;
  I: Integer;
begin
  Limiter := TTokenBucketLimiter.Create(5, 0.1);
  try
    // Consume all tokens
    for I := 1 to 5 do
      Limiter.TryAcquire;
    
    // Next request should be denied
    Assert.IsFalse(Limiter.TryAcquire, 'Request should be denied after capacity exhausted');
  finally
    Limiter.Free;
  end;
end;

procedure TTestTokenBucketLimiter.Test_RefillRate_AddsTokensOverTime;
var
  Limiter: TTokenBucketLimiter;
begin
  Limiter := TTokenBucketLimiter.Create(5, 10.0); // 10 tokens per second
  try
    // Consume all tokens
    while Limiter.TryAcquire do ;
    
    // Wait for refill (100ms should add ~1 token at 10/sec)
    Sleep(150);
    
    // Should allow at least one request
    Assert.IsTrue(Limiter.TryAcquire, 'Should allow request after refill');
  finally
    Limiter.Free;
  end;
end;

procedure TTestTokenBucketLimiter.Test_TryAcquireN_ConsumesMultipleTokens;
var
  Limiter: TTokenBucketLimiter;
begin
  Limiter := TTokenBucketLimiter.Create(10, 1.0);
  try
    // Consume 5 tokens
    Assert.IsTrue(Limiter.TryAcquireN('', 5), 'Should acquire 5 tokens');
    
    // Try to consume 6 more (should fail - only 5 left)
    Assert.IsFalse(Limiter.TryAcquireN('', 6), 'Should not acquire 6 tokens');
    
    // Consume remaining 5
    Assert.IsTrue(Limiter.TryAcquireN('', 5), 'Should acquire remaining 5 tokens');
  finally
    Limiter.Free;
  end;
end;

procedure TTestTokenBucketLimiter.Test_Reset_RestoresCapacity;
var
  Limiter: TTokenBucketLimiter;
begin
  Limiter := TTokenBucketLimiter.Create(5, 0.1);
  try
    // Consume all tokens
    while Limiter.TryAcquire do ;
    
    Assert.IsFalse(Limiter.TryAcquire, 'Should be empty');
    
    // Reset
    Limiter.Reset;
    
    // Should allow requests again
    Assert.IsTrue(Limiter.TryAcquire, 'Should allow after reset');
  finally
    Limiter.Free;
  end;
end;

procedure TTestTokenBucketLimiter.Test_GetStats_ReturnsRemainingTokens;
var
  Limiter: TTokenBucketLimiter;
  Stats: TRateLimitResult;
begin
  Limiter := TTokenBucketLimiter.Create(10, 1.0);
  try
    // Consume 3 tokens
    Limiter.TryAcquire;
    Limiter.TryAcquire;
    Limiter.TryAcquire;
    
    Stats := Limiter.GetStats;
    
    Assert.AreEqual(7, Stats.Remaining, 'Should have 7 tokens remaining');
  finally
    Limiter.Free;
  end;
end;

procedure TTestTokenBucketLimiter.Test_KeyBased_IndependentBuckets;
var
  Limiter: TTokenBucketLimiter;
begin
  Limiter := TTokenBucketLimiter.Create(3, 0.1);
  try
    // Exhaust user1's bucket
    Limiter.TryAcquire('user1');
    Limiter.TryAcquire('user1');
    Limiter.TryAcquire('user1');
    
    Assert.IsFalse(Limiter.TryAcquire('user1'), 'user1 should be rate limited');
    
    // user2 should still have tokens
    Assert.IsTrue(Limiter.TryAcquire('user2'), 'user2 should not be affected');
  finally
    Limiter.Free;
  end;
end;

procedure TTestTokenBucketLimiter.Test_Acquire_ReturnsResult;
var
  Limiter: TTokenBucketLimiter;
  Result: TRateLimitResult;
begin
  Limiter := TTokenBucketLimiter.Create(5, 1.0);
  try
    Result := Limiter.Acquire;
    
    Assert.IsTrue(Result.Allowed);
    Assert.AreEqual(4, Result.Remaining);
  finally
    Limiter.Free;
  end;
end;

{ TTestFixedWindowLimiter }

procedure TTestFixedWindowLimiter.Test_WithinLimit_AllowsRequests;
var
  Limiter: TFixedWindowLimiter;
  I: Integer;
begin
  Limiter := TFixedWindowLimiter.Create(10, 60000); // 10 per minute
  try
    for I := 1 to 10 do
      Assert.IsTrue(Limiter.TryAcquire, Format('Request %d should be allowed', [I]));
  finally
    Limiter.Free;
  end;
end;

procedure TTestFixedWindowLimiter.Test_ExceedLimit_DeniesRequests;
var
  Limiter: TFixedWindowLimiter;
  I: Integer;
begin
  Limiter := TFixedWindowLimiter.Create(5, 60000);
  try
    for I := 1 to 5 do
      Limiter.TryAcquire;
    
    Assert.IsFalse(Limiter.TryAcquire, 'Should deny after limit exceeded');
  finally
    Limiter.Free;
  end;
end;

procedure TTestFixedWindowLimiter.Test_WindowReset_AllowsNewRequests;
var
  Limiter: TFixedWindowLimiter;
begin
  Limiter := TFixedWindowLimiter.Create(5, 100); // 100ms window
  try
    // Exhaust limit
    while Limiter.TryAcquire do ;
    
    Assert.IsFalse(Limiter.TryAcquire, 'Should be denied');
    
    // Wait for window to reset
    Sleep(150);
    
    Assert.IsTrue(Limiter.TryAcquire, 'Should allow after window reset');
  finally
    Limiter.Free;
  end;
end;

procedure TTestFixedWindowLimiter.Test_Reset_ClearsCounter;
var
  Limiter: TFixedWindowLimiter;
begin
  Limiter := TFixedWindowLimiter.Create(5, 60000);
  try
    while Limiter.TryAcquire do ;
    
    Limiter.Reset;
    
    Assert.IsTrue(Limiter.TryAcquire, 'Should allow after reset');
  finally
    Limiter.Free;
  end;
end;

procedure TTestFixedWindowLimiter.Test_GetStats_ReturnsRemaining;
var
  Limiter: TFixedWindowLimiter;
  Stats: TRateLimitResult;
begin
  Limiter := TFixedWindowLimiter.Create(10, 60000);
  try
    Limiter.TryAcquire;
    Limiter.TryAcquire;
    Limiter.TryAcquire;
    
    Stats := Limiter.GetStats;
    
    Assert.AreEqual(7, Stats.Remaining);
  finally
    Limiter.Free;
  end;
end;

procedure TTestFixedWindowLimiter.Test_KeyBased_IndependentWindows;
var
  Limiter: TFixedWindowLimiter;
begin
  Limiter := TFixedWindowLimiter.Create(3, 60000);
  try
    // Exhaust user1
    Limiter.TryAcquire('user1');
    Limiter.TryAcquire('user1');
    Limiter.TryAcquire('user1');
    
    Assert.IsFalse(Limiter.TryAcquire('user1'));
    Assert.IsTrue(Limiter.TryAcquire('user2'), 'user2 should be independent');
  finally
    Limiter.Free;
  end;
end;

procedure TTestFixedWindowLimiter.Test_Acquire_ReturnsResetTime;
var
  Limiter: TFixedWindowLimiter;
  Result: TRateLimitResult;
begin
  Limiter := TFixedWindowLimiter.Create(10, 60000);
  try
    Result := Limiter.Acquire;
    
    Assert.IsTrue(Result.Allowed);
    Assert.IsTrue(Result.ResetTime > Now, 'Reset time should be in future');
  finally
    Limiter.Free;
  end;
end;

{ TTestSlidingWindowLimiter }

procedure TTestSlidingWindowLimiter.Test_WithinLimit_AllowsRequests;
var
  Limiter: TSlidingWindowLimiter;
  I: Integer;
begin
  Limiter := TSlidingWindowLimiter.Create(10, 60000);
  try
    for I := 1 to 10 do
      Assert.IsTrue(Limiter.TryAcquire);
  finally
    Limiter.Free;
  end;
end;

procedure TTestSlidingWindowLimiter.Test_ExceedLimit_DeniesRequests;
var
  Limiter: TSlidingWindowLimiter;
begin
  Limiter := TSlidingWindowLimiter.Create(5, 60000);
  try
    while Limiter.TryAcquire do ;
    
    Assert.IsFalse(Limiter.TryAcquire);
  finally
    Limiter.Free;
  end;
end;

procedure TTestSlidingWindowLimiter.Test_OldRequestsExpire_AllowsNewRequests;
var
  Limiter: TSlidingWindowLimiter;
begin
  Limiter := TSlidingWindowLimiter.Create(5, 100); // 100ms window
  try
    while Limiter.TryAcquire do ;
    
    Sleep(150);
    
    Assert.IsTrue(Limiter.TryAcquire, 'Old requests should expire');
  finally
    Limiter.Free;
  end;
end;

procedure TTestSlidingWindowLimiter.Test_Reset_ClearsLog;
var
  Limiter: TSlidingWindowLimiter;
begin
  Limiter := TSlidingWindowLimiter.Create(5, 60000);
  try
    while Limiter.TryAcquire do ;
    
    Limiter.Reset;
    
    Assert.IsTrue(Limiter.TryAcquire);
  finally
    Limiter.Free;
  end;
end;

procedure TTestSlidingWindowLimiter.Test_GetStats_ReturnsAccurateRemaining;
var
  Limiter: TSlidingWindowLimiter;
  Stats: TRateLimitResult;
begin
  Limiter := TSlidingWindowLimiter.Create(10, 60000);
  try
    Limiter.TryAcquire;
    Limiter.TryAcquire;
    Limiter.TryAcquire;
    
    Stats := Limiter.GetStats;
    
    Assert.AreEqual(7, Stats.Remaining);
  finally
    Limiter.Free;
  end;
end;

procedure TTestSlidingWindowLimiter.Test_KeyBased_IndependentLogs;
var
  Limiter: TSlidingWindowLimiter;
begin
  Limiter := TSlidingWindowLimiter.Create(3, 60000);
  try
    Limiter.TryAcquire('user1');
    Limiter.TryAcquire('user1');
    Limiter.TryAcquire('user1');
    
    Assert.IsFalse(Limiter.TryAcquire('user1'));
    Assert.IsTrue(Limiter.TryAcquire('user2'));
  finally
    Limiter.Free;
  end;
end;

{ TTestSlidingWindowCounterLimiter }

procedure TTestSlidingWindowCounterLimiter.Test_WithinLimit_AllowsRequests;
var
  Limiter: TSlidingWindowCounterLimiter;
  I: Integer;
begin
  Limiter := TSlidingWindowCounterLimiter.Create(10, 60000);
  try
    for I := 1 to 10 do
      Assert.IsTrue(Limiter.TryAcquire);
  finally
    Limiter.Free;
  end;
end;

procedure TTestSlidingWindowCounterLimiter.Test_ExceedLimit_DeniesRequests;
var
  Limiter: TSlidingWindowCounterLimiter;
begin
  Limiter := TSlidingWindowCounterLimiter.Create(5, 60000);
  try
    while Limiter.TryAcquire do ;
    
    Assert.IsFalse(Limiter.TryAcquire);
  finally
    Limiter.Free;
  end;
end;

procedure TTestSlidingWindowCounterLimiter.Test_WindowTransition_WeightedCount;
var
  Limiter: TSlidingWindowCounterLimiter;
begin
  Limiter := TSlidingWindowCounterLimiter.Create(10, 100); // 100ms window
  try
    // Make 5 requests
    Limiter.TryAcquire;
    Limiter.TryAcquire;
    Limiter.TryAcquire;
    Limiter.TryAcquire;
    Limiter.TryAcquire;
    
    // Wait for partial window transition
    Sleep(60);
    
    // Should still count some of previous window
    // with weighted average, should allow some more requests
    Assert.IsTrue(Limiter.TryAcquire, 'Weighted average should allow requests');
  finally
    Limiter.Free;
  end;
end;

procedure TTestSlidingWindowCounterLimiter.Test_Reset_ClearsCounters;
var
  Limiter: TSlidingWindowCounterLimiter;
begin
  Limiter := TSlidingWindowCounterLimiter.Create(5, 60000);
  try
    while Limiter.TryAcquire do ;
    
    Limiter.Reset;
    
    Assert.IsTrue(Limiter.TryAcquire);
  finally
    Limiter.Free;
  end;
end;

procedure TTestSlidingWindowCounterLimiter.Test_KeyBased_IndependentCounters;
var
  Limiter: TSlidingWindowCounterLimiter;
begin
  Limiter := TSlidingWindowCounterLimiter.Create(3, 60000);
  try
    Limiter.TryAcquire('user1');
    Limiter.TryAcquire('user1');
    Limiter.TryAcquire('user1');
    
    Assert.IsFalse(Limiter.TryAcquire('user1'));
    Assert.IsTrue(Limiter.TryAcquire('user2'));
  finally
    Limiter.Free;
  end;
end;

{ TTestRateLimitConfig }

procedure TTestRateLimitConfig.Test_RequestsPerSecond;
var
  Config: TRateLimitConfig;
begin
  Config := TRateLimitConfig.Create;
  try
    Config.RequestsPerSecond(100);
    
    Assert.AreEqual(100, Config.MaxRequestsValue);
    Assert.AreEqual(Int64(1000), Config.WindowSizeMsValue);
  finally
    Config.Free;
  end;
end;

procedure TTestRateLimitConfig.Test_RequestsPerMinute;
var
  Config: TRateLimitConfig;
begin
  Config := TRateLimitConfig.Create;
  try
    Config.RequestsPerMinute(60);
    
    Assert.AreEqual(60, Config.MaxRequestsValue);
    Assert.AreEqual(Int64(60000), Config.WindowSizeMsValue);
  finally
    Config.Free;
  end;
end;

procedure TTestRateLimitConfig.Test_RequestsPerHour;
var
  Config: TRateLimitConfig;
begin
  Config := TRateLimitConfig.Create;
  try
    Config.RequestsPerHour(1000);
    
    Assert.AreEqual(1000, Config.MaxRequestsValue);
    Assert.AreEqual(Int64(3600000), Config.WindowSizeMsValue);
  finally
    Config.Free;
  end;
end;

procedure TTestRateLimitConfig.Test_RequestsPerDay;
var
  Config: TRateLimitConfig;
begin
  Config := TRateLimitConfig.Create;
  try
    Config.RequestsPerDay(10000);
    
    Assert.AreEqual(10000, Config.MaxRequestsValue);
    Assert.AreEqual(Int64(86400000), Config.WindowSizeMsValue);
  finally
    Config.Free;
  end;
end;

procedure TTestRateLimitConfig.Test_CustomWindow;
var
  Config: TRateLimitConfig;
begin
  Config := TRateLimitConfig.Create;
  try
    Config.CustomWindow(50, 30000);
    
    Assert.AreEqual(50, Config.MaxRequestsValue);
    Assert.AreEqual(Int64(30000), Config.WindowSizeMsValue);
  finally
    Config.Free;
  end;
end;

procedure TTestRateLimitConfig.Test_Algorithm_TokenBucket;
var
  Config: TRateLimitConfig;
begin
  Config := TRateLimitConfig.Create;
  try
    Config.Algorithm(rlaTokenBucket);
    
    Assert.AreEqual(rlaTokenBucket, Config.AlgorithmType);
  finally
    Config.Free;
  end;
end;

procedure TTestRateLimitConfig.Test_Algorithm_FixedWindow;
var
  Config: TRateLimitConfig;
begin
  Config := TRateLimitConfig.Create;
  try
    Config.Algorithm(rlaFixedWindow);
    
    Assert.AreEqual(rlaFixedWindow, Config.AlgorithmType);
  finally
    Config.Free;
  end;
end;

procedure TTestRateLimitConfig.Test_Algorithm_SlidingWindow;
var
  Config: TRateLimitConfig;
begin
  Config := TRateLimitConfig.Create;
  try
    Config.Algorithm(rlaSlidingWindow);
    
    Assert.AreEqual(rlaSlidingWindow, Config.AlgorithmType);
  finally
    Config.Free;
  end;
end;

procedure TTestRateLimitConfig.Test_BurstSize;
var
  Config: TRateLimitConfig;
begin
  Config := TRateLimitConfig.Create;
  try
    Config.BurstSize(20);
    
    Assert.AreEqual(20, Config.BurstSizeValue);
  finally
    Config.Free;
  end;
end;

procedure TTestRateLimitConfig.Test_Build_CreatesLimiter;
var
  Config: TRateLimitConfig;
  Limiter: IRateLimiter;
begin
  Config := TRateLimitConfig.Create;
  try
    Config.Algorithm(rlaFixedWindow).RequestsPerMinute(100);
    Limiter := Config.Build;
    
    Assert.IsNotNull(Limiter);
    Assert.IsTrue(Limiter.TryAcquire);
  finally
    Config.Free;
  end;
end;

{ TTestRateLimitManager }

procedure TTestRateLimitManager.Setup;
begin
  FManager := TRateLimitManager.Create;
end;

procedure TTestRateLimitManager.TearDown;
begin
  FManager.Free;
end;

procedure TTestRateLimitManager.Test_AddLimit_WithConfig;
var
  Config: TRateLimitConfig;
begin
  Config := TRateLimitConfig.Create;
  Config.RequestsPerMinute(100);
  FManager.AddLimit('api', Config);

  Assert.IsTrue(FManager.HasLimit('api'));
end;

procedure TTestRateLimitManager.Test_AddLimit_WithLimiter;
var
  Limiter: IRateLimiter;
begin
  Limiter := TTokenBucketLimiter.Create(100, 10);
  FManager.AddLimit('custom', Limiter);
  
  Assert.IsTrue(FManager.HasLimit('custom'));
end;

procedure TTestRateLimitManager.Test_RemoveLimit;
var
  Config: TRateLimitConfig;
begin
  Config := TRateLimitConfig.Create;
  Config.RequestsPerMinute(100);
  FManager.AddLimit('temp', Config);
  FManager.RemoveLimit('temp');

  Assert.IsFalse(FManager.HasLimit('temp'));
end;

procedure TTestRateLimitManager.Test_Check_ExistingLimit;
var
  Config: TRateLimitConfig;
begin
  Config := TRateLimitConfig.Create;
  Config.RequestsPerMinute(100);
  FManager.AddLimit('api', Config);

  Assert.IsTrue(FManager.Check('api'));
end;

procedure TTestRateLimitManager.Test_Check_NonExistentLimit;
begin
  // CR-294(Owner 决策B): 未知限额默认 fail-closed 拒绝，不再静默放行
  Assert.IsFalse(FManager.Check('nonexistent'));
end;

procedure TTestRateLimitManager.Test_CheckAll_AllPass;
var
  Config1, Config2: TRateLimitConfig;
begin
  Config1 := TRateLimitConfig.Create;
  Config2 := TRateLimitConfig.Create;
  Config1.RequestsPerMinute(100);
  Config2.RequestsPerMinute(100);

  FManager.AddLimit('limit1', Config1);
  FManager.AddLimit('limit2', Config2);

  Assert.IsTrue(FManager.CheckAll('user1', ['limit1', 'limit2']));
end;

procedure TTestRateLimitManager.Test_CheckAll_OneFails;
var
  Config1, Config2: TRateLimitConfig;
begin
  Config1 := TRateLimitConfig.Create;
  Config2 := TRateLimitConfig.Create;
  Config1.RequestsPerMinute(1);
  Config2.RequestsPerMinute(100);

  FManager.AddLimit('limit1', Config1);
  FManager.AddLimit('limit2', Config2);

  // Exhaust limit1
  FManager.Check('limit1', 'user1');

  // CheckAll should fail because limit1 is exhausted
  Assert.IsFalse(FManager.CheckAll('user1', ['limit1', 'limit2']));
end;

procedure TTestRateLimitManager.Test_Acquire_ReturnsResult;
var
  Config: TRateLimitConfig;
  Result: TRateLimitResult;
begin
  Config := TRateLimitConfig.Create;
  Config.RequestsPerMinute(100);
  FManager.AddLimit('api', Config);

  Result := FManager.Acquire('api');

  Assert.IsTrue(Result.Allowed);
end;

procedure TTestRateLimitManager.Test_ResetLimit;
var
  Config: TRateLimitConfig;
begin
  Config := TRateLimitConfig.Create;
  Config.RequestsPerMinute(1);
  FManager.AddLimit('api', Config);

  FManager.Check('api', 'user1'); // Exhaust
  Assert.IsFalse(FManager.Check('api', 'user1'));

  FManager.ResetLimit('api', 'user1');
  Assert.IsTrue(FManager.Check('api', 'user1'));
end;

procedure TTestRateLimitManager.Test_ResetAll;
var
  Config1, Config2: TRateLimitConfig;
begin
  Config1 := TRateLimitConfig.Create;
  Config2 := TRateLimitConfig.Create;
  Config1.RequestsPerMinute(1);
  Config2.RequestsPerMinute(1);

  FManager.AddLimit('api', Config1);
  FManager.AddLimit('login', Config2);

  FManager.Check('api', 'user1');
  FManager.Check('login', 'user1');

  FManager.ResetAll('user1');

  Assert.IsTrue(FManager.Check('api', 'user1'));
  Assert.IsTrue(FManager.Check('login', 'user1'));
end;

procedure TTestRateLimitManager.Test_HasLimit;
var
  Config: TRateLimitConfig;
begin
  Assert.IsFalse(FManager.HasLimit('api'));

  Config := TRateLimitConfig.Create;
  Config.RequestsPerMinute(100);
  FManager.AddLimit('api', Config);

  Assert.IsTrue(FManager.HasLimit('api'));
end;

procedure TTestRateLimitManager.Test_GetLimiter;
var
  Config: TRateLimitConfig;
  Limiter: IRateLimiter;
begin
  Config := TRateLimitConfig.Create;
  Config.RequestsPerMinute(100);
  FManager.AddLimit('api', Config);

  Limiter := FManager.GetLimiter('api');

  Assert.IsNotNull(Limiter);
end;

{ TTestRateLimitDecorator }

procedure TTestRateLimitDecorator.Test_Execute_WithinLimit_Executes;
var
  Limiter: IRateLimiter;
  Decorator: TRateLimitDecorator;
  Executed: Boolean;
begin
  Limiter := TTokenBucketLimiter.Create(10, 1.0);
  Decorator := TRateLimitDecorator.Create(Limiter);
  try
    Executed := False;
    
    Decorator.Execute(procedure begin Executed := True; end);
    
    Assert.IsTrue(Executed);
  finally
    Decorator.Free;
  end;
end;

procedure TTestRateLimitDecorator.Test_Execute_ExceedLimit_NotExecuted;
var
  Limiter: IRateLimiter;
  Decorator: TRateLimitDecorator;
  Executed: Boolean;
begin
  Limiter := TTokenBucketLimiter.Create(1, 0.001);
  Decorator := TRateLimitDecorator.Create(Limiter);
  try
    // Exhaust limit
    Decorator.Execute(procedure begin end);

    Executed := False;
    Decorator.Execute(procedure begin Executed := True; end);

    Assert.IsFalse(Executed);
  finally
    Decorator.Free;
  end;
end;

procedure TTestRateLimitDecorator.Test_ExecuteFunc_ReturnsValue;
var
  Limiter: IRateLimiter;
  Decorator: TRateLimitDecorator;
  Value: Integer;
  Success: Boolean;
begin
  Limiter := TTokenBucketLimiter.Create(10, 1.0);
  Decorator := TRateLimitDecorator.Create(Limiter);
  try
    Success := Decorator.Execute<Integer>(
      function: Integer begin Result := 42; end, Value);
    
    Assert.IsTrue(Success);
    Assert.AreEqual(42, Value);
  finally
    Decorator.Free;
  end;
end;

procedure TTestRateLimitDecorator.Test_OnExceeded_CalledWhenDenied;
var
  Limiter: IRateLimiter;
  Decorator: TRateLimitDecorator;
  ExceededCalled: Boolean;
begin
  Limiter := TTokenBucketLimiter.Create(1, 0.001);
  Decorator := TRateLimitDecorator.Create(Limiter);
  try
    ExceededCalled := False;

    Decorator.OnExceeded(
      procedure(const Result: TRateLimitResult)
      begin
        ExceededCalled := True;
      end);

    // First call succeeds
    Decorator.Execute(procedure begin end);

    // Second call exceeds limit
    Decorator.Execute(procedure begin end);

    Assert.IsTrue(ExceededCalled);
  finally
    Decorator.Free;
  end;
end;

procedure TTestRateLimitDecorator.Test_ExecuteOrWait_WaitsForToken;
var
  Limiter: IRateLimiter;
  Decorator: TRateLimitDecorator;
  Executed: Boolean;
  StartTime: TDateTime;
begin
  Limiter := TTokenBucketLimiter.Create(1, 10.0); // Refill 10/sec
  Decorator := TRateLimitDecorator.Create(Limiter);
  try
    // Exhaust token
    Decorator.Execute(procedure begin end);

    Executed := False;
    StartTime := Now;

    // Should wait for refill
    Decorator.ExecuteOrWait(procedure begin Executed := True; end, 1000);

    Assert.IsTrue(Executed, 'Should execute after waiting');
    Assert.IsTrue(MilliSecondsBetween(Now, StartTime) >= 50, 'Should have waited');
  finally
    Decorator.Free;
  end;
end;

{ TTestRateLimitResult }

procedure TTestRateLimitResult.Test_Allow_SetsAllowedTrue;
var
  Result: TRateLimitResult;
begin
  Result := TRateLimitResult.Allow(10, Now + 1);
  Assert.IsTrue(Result.Allowed);
end;

procedure TTestRateLimitResult.Test_Deny_SetsAllowedFalse;
var
  Result: TRateLimitResult;
begin
  Result := TRateLimitResult.Deny(1000, Now + 1);
  Assert.IsFalse(Result.Allowed);
end;

procedure TTestRateLimitResult.Test_Allow_SetsRemaining;
var
  Result: TRateLimitResult;
begin
  Result := TRateLimitResult.Allow(5, Now);
  Assert.AreEqual(5, Result.Remaining);
end;

procedure TTestRateLimitResult.Test_Deny_SetsRetryAfter;
var
  Result: TRateLimitResult;
begin
  Result := TRateLimitResult.Deny(500, Now);
  Assert.AreEqual(Int64(500), Result.RetryAfterMs);
end;

{ TTestRateLimiterThreadSafety }

procedure TTestRateLimiterThreadSafety.Test_TokenBucket_ConcurrentAccess;
var
  Limiter: TTokenBucketLimiter;
  Tasks: TArray<ITask>;
  I: Integer;
  ErrorCount: Integer;
  Lock: TCriticalSection;
const
  THREAD_COUNT = 10;
  REQUESTS_PER_THREAD = 100;
begin
  ErrorCount := 0;
  Lock := TCriticalSection.Create;
  Limiter := TTokenBucketLimiter.Create(1000, 100);
  try
    SetLength(Tasks, THREAD_COUNT);
    
    for I := 0 to THREAD_COUNT - 1 do
    begin
      Tasks[I] := TTask.Run(
        procedure
        var
          J: Integer;
        begin
          for J := 1 to REQUESTS_PER_THREAD do
          begin
            try
              Limiter.TryAcquire;
            except
              Lock.Enter;
              try
                Inc(ErrorCount);
              finally
                Lock.Leave;
              end;
            end;
          end;
        end);
    end;
    
    TTask.WaitForAll(Tasks);
    
    Assert.AreEqual(0, ErrorCount);
  finally
    Limiter.Free;
    Lock.Free;
  end;
end;

procedure TTestRateLimiterThreadSafety.Test_FixedWindow_ConcurrentAccess;
var
  Limiter: TFixedWindowLimiter;
  Tasks: TArray<ITask>;
  I: Integer;
  ErrorCount: Integer;
  Lock: TCriticalSection;
const
  THREAD_COUNT = 10;
  REQUESTS_PER_THREAD = 100;
begin
  ErrorCount := 0;
  Lock := TCriticalSection.Create;
  Limiter := TFixedWindowLimiter.Create(1000, 60000);
  try
    SetLength(Tasks, THREAD_COUNT);
    
    for I := 0 to THREAD_COUNT - 1 do
    begin
      Tasks[I] := TTask.Run(
        procedure
        var
          J: Integer;
        begin
          for J := 1 to REQUESTS_PER_THREAD do
          begin
            try
              Limiter.TryAcquire;
            except
              Lock.Enter;
              try
                Inc(ErrorCount);
              finally
                Lock.Leave;
              end;
            end;
          end;
        end);
    end;
    
    TTask.WaitForAll(Tasks);
    
    Assert.AreEqual(0, ErrorCount);
  finally
    Limiter.Free;
    Lock.Free;
  end;
end;

procedure TTestRateLimiterThreadSafety.Test_SlidingWindow_ConcurrentAccess;
var
  Limiter: TSlidingWindowLimiter;
  Tasks: TArray<ITask>;
  I: Integer;
  ErrorCount: Integer;
  Lock: TCriticalSection;
const
  THREAD_COUNT = 10;
  REQUESTS_PER_THREAD = 50;
begin
  ErrorCount := 0;
  Lock := TCriticalSection.Create;
  Limiter := TSlidingWindowLimiter.Create(1000, 60000);
  try
    SetLength(Tasks, THREAD_COUNT);
    
    for I := 0 to THREAD_COUNT - 1 do
    begin
      Tasks[I] := TTask.Run(
        procedure
        var
          J: Integer;
        begin
          for J := 1 to REQUESTS_PER_THREAD do
          begin
            try
              Limiter.TryAcquire;
            except
              Lock.Enter;
              try
                Inc(ErrorCount);
              finally
                Lock.Leave;
              end;
            end;
          end;
        end);
    end;
    
    TTask.WaitForAll(Tasks);
    
    Assert.AreEqual(0, ErrorCount);
  finally
    Limiter.Free;
    Lock.Free;
  end;
end;

procedure TTestRateLimiterThreadSafety.Test_Manager_ConcurrentAccess;
var
  Manager: TRateLimitManager;
  Config: TRateLimitConfig;
  Tasks: TArray<ITask>;
  I: Integer;
  ErrorCount: Integer;
  Lock: TCriticalSection;
const
  THREAD_COUNT = 10;
  REQUESTS_PER_THREAD = 50;
begin
  ErrorCount := 0;
  Lock := TCriticalSection.Create;
  Manager := TRateLimitManager.Create;
  Config := TRateLimitConfig.Create;
  Config.RequestsPerMinute(10000);
  Manager.AddLimit('api', Config);
  try
    SetLength(Tasks, THREAD_COUNT);

    for I := 0 to THREAD_COUNT - 1 do
    begin
      Tasks[I] := TTask.Run(
        procedure
        var
          J: Integer;
          Key: string;
        begin
          Key := 'user_' + IntToStr(TThread.CurrentThread.ThreadID);
          for J := 1 to REQUESTS_PER_THREAD do
          begin
            try
              Manager.Check('api', Key);
            except
              Lock.Enter;
              try
                Inc(ErrorCount);
              finally
                Lock.Leave;
              end;
            end;
          end;
        end);
    end;

    TTask.WaitForAll(Tasks);

    Assert.AreEqual(0, ErrorCount);
  finally
    Manager.Free;
    Lock.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestTokenBucketLimiter);
  TDUnitX.RegisterTestFixture(TTestFixedWindowLimiter);
  TDUnitX.RegisterTestFixture(TTestSlidingWindowLimiter);
  TDUnitX.RegisterTestFixture(TTestSlidingWindowCounterLimiter);
  TDUnitX.RegisterTestFixture(TTestRateLimitConfig);
  TDUnitX.RegisterTestFixture(TTestRateLimitManager);
  TDUnitX.RegisterTestFixture(TTestRateLimitDecorator);
  TDUnitX.RegisterTestFixture(TTestRateLimitResult);
  TDUnitX.RegisterTestFixture(TTestRateLimiterThreadSafety);

end.
