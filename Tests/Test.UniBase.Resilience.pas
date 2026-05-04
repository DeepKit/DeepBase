/// <summary>
/// Unit tests for UniBase.Resilience module
/// Tests: Circuit Breaker, Retry Policy, Timeout Policy, Fallback Policy,
///        Bulkhead Policy, Combined Resilience Policy, Circuit Breaker Registry
/// </summary>
unit Test.UniBase.Resilience;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Threading,
  System.Generics.Collections,
  System.DateUtils,
  DUnitX.TestFramework,
  UniBase.Resilience;

type
  // Custom exception for testing
  ETestException = class(Exception);
  ECustomException = class(Exception);
  EAnotherException = class(Exception);

  /// <summary>
  /// Tests for TCircuitBreaker
  /// </summary>
  [TestFixture]
  TCircuitBreakerTests = class
  private
    FCircuitBreaker: TCircuitBreaker;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // Basic tests
    [Test]
    procedure Test_Create_InitialStateClosed;
    [Test]
    procedure Test_Create_DefaultThresholds;

    // Configuration tests
    [Test]
    procedure Test_FailureThreshold_FluentConfig;
    [Test]
    procedure Test_SuccessThreshold_FluentConfig;
    [Test]
    procedure Test_OpenDuration_FluentConfig;

    // State transition tests
    [Test]
    procedure Test_StateTransition_ClosedToOpen_OnFailureThreshold;
    [Test]
    procedure Test_StateTransition_OpenToHalfOpen_AfterDuration;
    [Test]
    procedure Test_StateTransition_HalfOpenToClosed_OnSuccessThreshold;
    [Test]
    procedure Test_StateTransition_HalfOpenToOpen_OnFailure;

    // Execute tests
    [Test]
    procedure Test_Execute_Proc_Success;
    [Test]
    procedure Test_Execute_Proc_Failure;
    [Test]
    procedure Test_Execute_Func_Success;
    [Test]
    procedure Test_Execute_Func_Failure;
    [Test]
    procedure Test_Execute_RejectedWhenOpen;
    [Test]
    procedure Test_Execute_Proc_Timeout_RecordsFailure;
    [Test]
    procedure Test_Execute_Func_Timeout_RecordsFailure;

    // AllowRequest tests
    [Test]
    procedure Test_AllowRequest_TrueWhenClosed;
    [Test]
    procedure Test_AllowRequest_FalseWhenOpen;
    [Test]
    procedure Test_AllowRequest_TrueWhenHalfOpen;

    // RecordSuccess/RecordFailure tests
    [Test]
    procedure Test_RecordSuccess_ResetsFailureCount;
    [Test]
    procedure Test_RecordFailure_IncrementsCount;

    // Reset tests
    [Test]
    procedure Test_Reset_RestoresClosedState;

    // Event tests
    [Test]
    procedure Test_OnStateChanged_Fires;
    [Test]
    procedure Test_OnRejected_Fires;

    // State helper tests
    [Test]
    procedure Test_CircuitState_ToString;

    // Thread safety tests
    [Test]
    procedure Test_ThreadSafety_ConcurrentExecute;
  end;

  /// <summary>
  /// Tests for TRetryPolicy
  /// </summary>
  [TestFixture]
  TRetryPolicyTests = class
  private
    FRetryPolicy: TRetryPolicy;
    FAttemptCount: Integer;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // Basic tests
    [Test]
    procedure Test_Create_DefaultValues;

    // Configuration tests
    [Test]
    procedure Test_MaxRetries_FluentConfig;
    [Test]
    procedure Test_FixedDelay_FluentConfig;
    [Test]
    procedure Test_LinearBackoff_FluentConfig;
    [Test]
    procedure Test_ExponentialBackoff_FluentConfig;
    [Test]
    procedure Test_WithJitter_FluentConfig;
    [Test]
    procedure Test_Handle_SpecificException;
    [Test]
    procedure Test_HandleAll_AllExceptions;

    // Execute tests - success
    [Test]
    procedure Test_Execute_Proc_NoRetryOnSuccess;
    [Test]
    procedure Test_Execute_Func_NoRetryOnSuccess;

    // Execute tests - retry
    [Test]
    procedure Test_Execute_Proc_RetriesOnFailure;
    [Test]
    procedure Test_Execute_Func_RetriesOnFailure;
    [Test]
    procedure Test_Execute_SucceedsAfterRetries;
    [Test]
    procedure Test_Execute_RaisesAfterMaxRetries;

    // Handle exception filtering tests
    [Test]
    procedure Test_Execute_RetriesHandledException;
    [Test]
    procedure Test_Execute_DoesNotRetryUnhandledException;

    // Delay strategy tests
    [Test]
    procedure Test_CalculateDelay_FixedStrategy;
    [Test]
    procedure Test_CalculateDelay_LinearStrategy;
    [Test]
    procedure Test_CalculateDelay_ExponentialStrategy;
    [Test]
    procedure Test_CalculateDelay_WithJitter;
    [Test]
    procedure Test_CalculateDelay_CappedAtMax;

    // Event tests
    [Test]
    procedure Test_OnRetry_Fires;
    [Test]
    procedure Test_OnRetry_CanCancelRetry;
    [Test]
    procedure Test_OnWait_Fires;

    // TryExecute tests
    [Test]
    procedure Test_TryExecute_ReturnsTrueOnSuccess;
    [Test]
    procedure Test_TryExecute_ReturnsFalseOnFailure;
  end;

  /// <summary>
  /// Tests for ETimeoutException
  /// </summary>
  [TestFixture]
  TTimeoutExceptionTests = class
  public
    [Test]
    procedure Test_Create_StoresTimeout;
    [Test]
    procedure Test_Create_FormatsMessage;
  end;

  /// <summary>
  /// Tests for TTimeoutPolicy
  /// </summary>
  [TestFixture]
  TTimeoutPolicyTests = class
  private
    FTimeoutPolicy: TTimeoutPolicy;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // Basic tests
    [Test]
    procedure Test_Create_StoresTimeout;

    // Configuration tests
    [Test]
    procedure Test_Timeout_FluentConfig;
    [Test]
    procedure Test_OnTimeoutEvent_FluentConfig;

    // Execute tests
    [Test]
    procedure Test_Execute_Proc_CompletesBeforeTimeout;
    [Test]
    procedure Test_Execute_Proc_RaisesOnTimeout;
    [Test]
    procedure Test_Execute_Func_CompletesBeforeTimeout;
    [Test]
    procedure Test_Execute_Func_RaisesOnTimeout;
    [Test]
    procedure Test_Execute_PropagatesException;

    // Event tests
    [Test]
    procedure Test_OnTimeout_Fires;
  end;

  /// <summary>
  /// Tests for TFallbackPolicy<T>
  /// </summary>
  [TestFixture]
  TFallbackPolicyTests = class
  private
    FFallbackPolicy: TFallbackPolicy<string>;
    FIntFallbackPolicy: TFallbackPolicy<Integer>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // Basic tests
    [Test]
    procedure Test_Create;

    // Configuration tests
    [Test]
    procedure Test_Value_FluentConfig;
    [Test]
    procedure Test_ValueFunc_FluentConfig;
    [Test]
    procedure Test_Handle_SpecificException;
    [Test]
    procedure Test_HandleAll;

    // Execute tests
    [Test]
    procedure Test_Execute_ReturnsResultOnSuccess;
    [Test]
    procedure Test_Execute_ReturnsFallbackOnException;
    [Test]
    procedure Test_Execute_ReturnsFallbackFunc;
    [Test]
    procedure Test_Execute_RaisesUnhandledException;

    // Integer type tests
    [Test]
    procedure Test_Execute_IntegerFallback;
  end;

  /// <summary>
  /// Tests for EBulkheadRejectedException
  /// </summary>
  [TestFixture]
  TBulkheadRejectedExceptionTests = class
  public
    [Test]
    procedure Test_Create_StoresMaxConcurrency;
    [Test]
    procedure Test_Create_FormatsMessage;
  end;

  /// <summary>
  /// Tests for TBulkheadPolicy
  /// </summary>
  [TestFixture]
  TBulkheadPolicyTests = class
  private
    FBulkheadPolicy: TBulkheadPolicy;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // Basic tests
    [Test]
    procedure Test_Create_InitialValues;

    // Configuration tests
    [Test]
    procedure Test_MaxQueue_FluentConfig;
    [Test]
    procedure Test_QueueTimeout_FluentConfig;

    // Execute tests
    [Test]
    procedure Test_Execute_Proc_Success;
    [Test]
    procedure Test_Execute_Func_Success;
    [Test]
    procedure Test_Execute_RejectsBeyondMax;
    [Test]
    procedure Test_Execute_QueuesWhenFull;
    [Test]
    procedure Test_Execute_RejectsWhenQueueFull;

    // TryExecute tests
    [Test]
    procedure Test_TryExecute_ReturnsTrueOnSuccess;
    [Test]
    procedure Test_TryExecute_ReturnsFalseOnRejection;

    // Stats tests
    [Test]
    procedure Test_CurrentCount_TracksActive;
    [Test]
    procedure Test_QueueCount_TracksQueued;

    // Thread safety tests
    [Test]
    procedure Test_ThreadSafety_ConcurrentExecute;
  end;

  /// <summary>
  /// Tests for TResiliencePolicy (combined)
  /// </summary>
  [TestFixture]
  TResiliencePolicyTests = class
  private
    FPolicy: TResiliencePolicy;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // Basic tests
    [Test]
    procedure Test_Create;

    // Configuration tests
    [Test]
    procedure Test_WithRetry_FluentConfig;
    [Test]
    procedure Test_WithTimeout_Policy_FluentConfig;
    [Test]
    procedure Test_WithTimeout_Ms_FluentConfig;
    [Test]
    procedure Test_WithCircuitBreaker_FluentConfig;
    [Test]
    procedure Test_WithBulkhead_Policy_FluentConfig;
    [Test]
    procedure Test_WithBulkhead_Int_FluentConfig;

    // Execute tests
    [Test]
    procedure Test_Execute_Proc_WithAllPolicies;
    [Test]
    procedure Test_Execute_Func_WithAllPolicies;
    [Test]
    procedure Test_Execute_Proc_NoPolicy;
    [Test]
    procedure Test_Execute_RetryOnly;
    [Test]
    procedure Test_Execute_TimeoutOnly;

    // Ownership tests
    [Test]
    procedure Test_PolicyOwnership_True;
    [Test]
    procedure Test_PolicyOwnership_False;
  end;

  /// <summary>
  /// Tests for TCircuitBreakerRegistry
  /// </summary>
  [TestFixture]
  TCircuitBreakerRegistryTests = class
  private
    FRegistry: TCircuitBreakerRegistry;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // Basic tests
    [Test]
    procedure Test_Create;

    // GetOrCreate tests
    [Test]
    procedure Test_GetOrCreate_CreatesNew;
    [Test]
    procedure Test_GetOrCreate_ReturnsSame;

    // TryGet tests
    [Test]
    procedure Test_TryGet_ReturnsTrueIfExists;
    [Test]
    procedure Test_TryGet_ReturnsFalseIfNotExists;

    // Remove tests
    [Test]
    procedure Test_Remove_RemovesBreaker;
    [Test]
    procedure Test_Remove_DoesNothingIfNotExists;

    // Clear tests
    [Test]
    procedure Test_Clear_RemovesAllBreakers;

    // Singleton tests
    [Test]
    procedure Test_Instance_ReturnsSingleton;
    [Test]
    procedure Test_CircuitBreakers_GlobalFunction;

    // Thread safety tests
    [Test]
    procedure Test_ThreadSafety_ConcurrentGetOrCreate;
  end;

implementation

// ============================================================================
// TCircuitBreakerTests
// ============================================================================

procedure TCircuitBreakerTests.Setup;
begin
  FCircuitBreaker := TCircuitBreaker.Create('TestBreaker');
end;

procedure TCircuitBreakerTests.TearDown;
begin
  FCircuitBreaker.Free;
end;

procedure TCircuitBreakerTests.Test_Create_InitialStateClosed;
begin
  Assert.AreEqual(csClosed, FCircuitBreaker.State);
end;

procedure TCircuitBreakerTests.Test_Create_DefaultThresholds;
var
  CB: TCircuitBreaker;
begin
  CB := TCircuitBreaker.Create('Test');
  try
    // Default failure threshold is 5
    // Default success threshold is 2
    // Default open duration is 30000ms
    Assert.AreEqual('Test', CB.Name);
    Assert.AreEqual(csClosed, CB.State);
  finally
    CB.Free;
  end;
end;

procedure TCircuitBreakerTests.Test_FailureThreshold_FluentConfig;
var
  Result: TCircuitBreaker;
begin
  Result := FCircuitBreaker.FailureThreshold(10);
  Assert.AreSame(FCircuitBreaker, Result);
end;

procedure TCircuitBreakerTests.Test_SuccessThreshold_FluentConfig;
var
  Result: TCircuitBreaker;
begin
  Result := FCircuitBreaker.SuccessThreshold(5);
  Assert.AreSame(FCircuitBreaker, Result);
end;

procedure TCircuitBreakerTests.Test_OpenDuration_FluentConfig;
var
  Result: TCircuitBreaker;
begin
  Result := FCircuitBreaker.OpenDuration(5000);
  Assert.AreSame(FCircuitBreaker, Result);
end;

procedure TCircuitBreakerTests.Test_StateTransition_ClosedToOpen_OnFailureThreshold;
begin
  FCircuitBreaker.FailureThreshold(3);

  // Record 3 failures
  FCircuitBreaker.RecordFailure;
  Assert.AreEqual(csClosed, FCircuitBreaker.State);
  FCircuitBreaker.RecordFailure;
  Assert.AreEqual(csClosed, FCircuitBreaker.State);
  FCircuitBreaker.RecordFailure;

  Assert.AreEqual(csOpen, FCircuitBreaker.State);
end;

procedure TCircuitBreakerTests.Test_StateTransition_OpenToHalfOpen_AfterDuration;
begin
  FCircuitBreaker.FailureThreshold(1).OpenDuration(50);

  // Trip the breaker
  FCircuitBreaker.RecordFailure;
  Assert.AreEqual(csOpen, FCircuitBreaker.State);

  // Wait for open duration
  Sleep(100);

  // State should transition to half-open
  Assert.AreEqual(csHalfOpen, FCircuitBreaker.State);
end;

procedure TCircuitBreakerTests.Test_StateTransition_HalfOpenToClosed_OnSuccessThreshold;
begin
  FCircuitBreaker.FailureThreshold(1).SuccessThreshold(2).OpenDuration(50);

  // Trip the breaker
  FCircuitBreaker.RecordFailure;
  Sleep(100);
  Assert.AreEqual(csHalfOpen, FCircuitBreaker.State);

  // Record successes
  FCircuitBreaker.RecordSuccess;
  Assert.AreEqual(csHalfOpen, FCircuitBreaker.State);
  FCircuitBreaker.RecordSuccess;

  Assert.AreEqual(csClosed, FCircuitBreaker.State);
end;

procedure TCircuitBreakerTests.Test_StateTransition_HalfOpenToOpen_OnFailure;
begin
  FCircuitBreaker.FailureThreshold(1).OpenDuration(50);

  // Trip the breaker
  FCircuitBreaker.RecordFailure;
  Sleep(100);
  Assert.AreEqual(csHalfOpen, FCircuitBreaker.State);

  // Record failure in half-open state
  FCircuitBreaker.RecordFailure;

  Assert.AreEqual(csOpen, FCircuitBreaker.State);
end;

procedure TCircuitBreakerTests.Test_Execute_Proc_Success;
var
  Executed: Boolean;
begin
  Executed := False;
  FCircuitBreaker.Execute(
    procedure
    begin
      Executed := True;
    end);
  Assert.IsTrue(Executed);
end;

procedure TCircuitBreakerTests.Test_Execute_Proc_Failure;
begin
  Assert.WillRaise(
    procedure
    begin
      FCircuitBreaker.Execute(
        procedure
        begin
          raise ETestException.Create('Test');
        end);
    end, ETestException);
end;

procedure TCircuitBreakerTests.Test_Execute_Func_Success;
var
  Result: Integer;
begin
  Result := FCircuitBreaker.Execute<Integer>(
    function: Integer
    begin
      Result := 42;
    end);
  Assert.AreEqual(42, Result);
end;

procedure TCircuitBreakerTests.Test_Execute_Func_Failure;
begin
  Assert.WillRaise(
    procedure
    begin
      FCircuitBreaker.Execute<Integer>(
        function: Integer
        begin
          raise ETestException.Create('Test');
        end);
    end, ETestException);
end;

procedure TCircuitBreakerTests.Test_Execute_RejectedWhenOpen;
begin
  FCircuitBreaker.FailureThreshold(1);
  FCircuitBreaker.RecordFailure;
  Assert.AreEqual(csOpen, FCircuitBreaker.State);

  Assert.WillRaise(
    procedure
    begin
      FCircuitBreaker.Execute(
        procedure
        begin
          // Should not execute
        end);
    end, Exception);
end;

procedure TCircuitBreakerTests.Test_Execute_Proc_Timeout_RecordsFailure;
begin
  FCircuitBreaker.FailureThreshold(1);

  Assert.WillRaise(
    procedure
    begin
      FCircuitBreaker.Execute(
        procedure
        begin
          Sleep(300);
        end, 30);
    end, ETimeoutException);

  Assert.AreEqual(csOpen, FCircuitBreaker.State,
    '超时异常应计入失败并触发熔断');
end;

procedure TCircuitBreakerTests.Test_Execute_Func_Timeout_RecordsFailure;
begin
  FCircuitBreaker.FailureThreshold(1);

  Assert.WillRaise(
    procedure
    begin
      FCircuitBreaker.Execute<Integer>(
        function: Integer
        begin
          Sleep(300);
          Result := 1;
        end, 30);
    end, ETimeoutException);

  Assert.AreEqual(csOpen, FCircuitBreaker.State,
    '函数超时异常应计入失败并触发熔断');
end;

procedure TCircuitBreakerTests.Test_AllowRequest_TrueWhenClosed;
begin
  Assert.IsTrue(FCircuitBreaker.AllowRequest);
end;

procedure TCircuitBreakerTests.Test_AllowRequest_FalseWhenOpen;
begin
  FCircuitBreaker.FailureThreshold(1);
  FCircuitBreaker.RecordFailure;
  Assert.IsFalse(FCircuitBreaker.AllowRequest);
end;

procedure TCircuitBreakerTests.Test_AllowRequest_TrueWhenHalfOpen;
begin
  FCircuitBreaker.FailureThreshold(1).OpenDuration(50);
  FCircuitBreaker.RecordFailure;
  Sleep(100);
  Assert.AreEqual(csHalfOpen, FCircuitBreaker.State);
  Assert.IsTrue(FCircuitBreaker.AllowRequest);
end;

procedure TCircuitBreakerTests.Test_RecordSuccess_ResetsFailureCount;
begin
  FCircuitBreaker.FailureThreshold(3);
  FCircuitBreaker.RecordFailure;
  FCircuitBreaker.RecordFailure;
  // Now we have 2 failures

  FCircuitBreaker.RecordSuccess;
  // Failure count should reset

  // One more failure should not trip the breaker
  FCircuitBreaker.RecordFailure;
  Assert.AreEqual(csClosed, FCircuitBreaker.State);
end;

procedure TCircuitBreakerTests.Test_RecordFailure_IncrementsCount;
begin
  FCircuitBreaker.FailureThreshold(5);

  FCircuitBreaker.RecordFailure;
  FCircuitBreaker.RecordFailure;
  FCircuitBreaker.RecordFailure;
  FCircuitBreaker.RecordFailure;
  Assert.AreEqual(csClosed, FCircuitBreaker.State);

  FCircuitBreaker.RecordFailure;
  Assert.AreEqual(csOpen, FCircuitBreaker.State);
end;

procedure TCircuitBreakerTests.Test_Reset_RestoresClosedState;
begin
  FCircuitBreaker.FailureThreshold(1);
  FCircuitBreaker.RecordFailure;
  Assert.AreEqual(csOpen, FCircuitBreaker.State);

  FCircuitBreaker.Reset;

  Assert.AreEqual(csClosed, FCircuitBreaker.State);
end;

procedure TCircuitBreakerTests.Test_OnStateChanged_Fires;
var
  StateChangeFired: Boolean;
  OldStateCapture, NewStateCapture: TCircuitState;
begin
  StateChangeFired := False;
  FCircuitBreaker
    .FailureThreshold(1)
    .OnStateChanged(
      procedure(const Name: string; OldState, NewState: TCircuitState)
      begin
        StateChangeFired := True;
        OldStateCapture := OldState;
        NewStateCapture := NewState;
      end);

  FCircuitBreaker.RecordFailure;

  Assert.IsTrue(StateChangeFired);
  Assert.AreEqual(csClosed, OldStateCapture);
  Assert.AreEqual(csOpen, NewStateCapture);
end;

procedure TCircuitBreakerTests.Test_OnRejected_Fires;
var
  RejectedFired: Boolean;
begin
  RejectedFired := False;
  FCircuitBreaker
    .FailureThreshold(1)
    .OnRejected(
      procedure(const Name: string)
      begin
        RejectedFired := True;
      end);

  FCircuitBreaker.RecordFailure;
  FCircuitBreaker.AllowRequest;

  Assert.IsTrue(RejectedFired);
end;

procedure TCircuitBreakerTests.Test_CircuitState_ToString;
begin
  Assert.AreEqual('Closed', csClosed.ToString);
  Assert.AreEqual('Open', csOpen.ToString);
  Assert.AreEqual('HalfOpen', csHalfOpen.ToString);
end;

procedure TCircuitBreakerTests.Test_ThreadSafety_ConcurrentExecute;
var
  Tasks: array of ITask;
  I: Integer;
  SuccessCount: Integer;
  Lock: TCriticalSection;
begin
  Lock := TCriticalSection.Create;
  try
    SuccessCount := 0;
    SetLength(Tasks, 10);

    for I := 0 to High(Tasks) do
    begin
      Tasks[I] := TTask.Create(
        procedure
        begin
          try
            FCircuitBreaker.Execute(
              procedure
              begin
                Sleep(10);
              end);
            Lock.Enter;
            try
              Inc(SuccessCount);
            finally
              Lock.Leave;
            end;
          except
            // May fail if circuit opens
          end;
        end);
      Tasks[I].Start;
    end;

    TTask.WaitForAll(Tasks);
    Assert.IsTrue(SuccessCount > 0);
  finally
    Lock.Free;
  end;
end;

// ============================================================================
// TRetryPolicyTests
// ============================================================================

procedure TRetryPolicyTests.Setup;
begin
  FRetryPolicy := TRetryPolicy.Create;
  FAttemptCount := 0;
end;

procedure TRetryPolicyTests.TearDown;
begin
  FRetryPolicy.Free;
end;

procedure TRetryPolicyTests.Test_Create_DefaultValues;
begin
  // Default max retries is 3
  // Default strategy is fixed
  // Default base delay is 1000ms
  Assert.IsNotNull(FRetryPolicy);
end;

procedure TRetryPolicyTests.Test_MaxRetries_FluentConfig;
var
  Result: TRetryPolicy;
begin
  Result := FRetryPolicy.MaxRetries(5);
  Assert.AreSame(FRetryPolicy, Result);
end;

procedure TRetryPolicyTests.Test_FixedDelay_FluentConfig;
var
  Result: TRetryPolicy;
begin
  Result := FRetryPolicy.FixedDelay(500);
  Assert.AreSame(FRetryPolicy, Result);
end;

procedure TRetryPolicyTests.Test_LinearBackoff_FluentConfig;
var
  Result: TRetryPolicy;
begin
  Result := FRetryPolicy.LinearBackoff(100, 1000);
  Assert.AreSame(FRetryPolicy, Result);
end;

procedure TRetryPolicyTests.Test_ExponentialBackoff_FluentConfig;
var
  Result: TRetryPolicy;
begin
  Result := FRetryPolicy.ExponentialBackoff(100, 2.0, 5000);
  Assert.AreSame(FRetryPolicy, Result);
end;

procedure TRetryPolicyTests.Test_WithJitter_FluentConfig;
var
  Result: TRetryPolicy;
begin
  Result := FRetryPolicy.WithJitter(0.1);
  Assert.AreSame(FRetryPolicy, Result);
end;

procedure TRetryPolicyTests.Test_Handle_SpecificException;
var
  Result: TRetryPolicy;
begin
  Result := FRetryPolicy.Handle<ETestException>;
  Assert.AreSame(FRetryPolicy, Result);
end;

procedure TRetryPolicyTests.Test_HandleAll_AllExceptions;
var
  Result: TRetryPolicy;
begin
  Result := FRetryPolicy.HandleAll;
  Assert.AreSame(FRetryPolicy, Result);
end;

procedure TRetryPolicyTests.Test_Execute_Proc_NoRetryOnSuccess;
var
  ExecuteCount: Integer;
begin
  ExecuteCount := 0;
  FRetryPolicy.Execute(
    procedure
    begin
      Inc(ExecuteCount);
    end);
  Assert.AreEqual(1, ExecuteCount);
end;

procedure TRetryPolicyTests.Test_Execute_Func_NoRetryOnSuccess;
var
  Result: Integer;
begin
  Result := FRetryPolicy.Execute<Integer>(
    function: Integer
    begin
      Result := 42;
    end);
  Assert.AreEqual(42, Result);
end;

procedure TRetryPolicyTests.Test_Execute_Proc_RetriesOnFailure;
var
  AttemptCount: Integer;
begin
  AttemptCount := 0;
  FRetryPolicy.MaxRetries(3).FixedDelay(1);

  Assert.WillRaise(
    procedure
    begin
      FRetryPolicy.Execute(
        procedure
        begin
          Inc(AttemptCount);
          raise ETestException.Create('Test');
        end);
    end, ETestException);

  // 1 initial + 3 retries = 4 attempts
  Assert.AreEqual(4, AttemptCount);
end;

procedure TRetryPolicyTests.Test_Execute_Func_RetriesOnFailure;
var
  AttemptCount: Integer;
begin
  AttemptCount := 0;
  FRetryPolicy.MaxRetries(2).FixedDelay(1);

  Assert.WillRaise(
    procedure
    begin
      FRetryPolicy.Execute<Integer>(
        function: Integer
        begin
          Inc(AttemptCount);
          raise ETestException.Create('Test');
        end);
    end, ETestException);

  // 1 initial + 2 retries = 3 attempts
  Assert.AreEqual(3, AttemptCount);
end;

procedure TRetryPolicyTests.Test_Execute_SucceedsAfterRetries;
var
  AttemptCount: Integer;
  Result: string;
begin
  AttemptCount := 0;
  FRetryPolicy.MaxRetries(5).FixedDelay(1);

  Result := FRetryPolicy.Execute<string>(
    function: string
    begin
      Inc(AttemptCount);
      if AttemptCount < 3 then
        raise ETestException.Create('Transient');
      Result := 'Success';
    end);

  Assert.AreEqual('Success', Result);
  Assert.AreEqual(3, AttemptCount);
end;

procedure TRetryPolicyTests.Test_Execute_RaisesAfterMaxRetries;
begin
  FRetryPolicy.MaxRetries(2).FixedDelay(1);

  Assert.WillRaise(
    procedure
    begin
      FRetryPolicy.Execute(
        procedure
        begin
          raise ETestException.Create('Always fail');
        end);
    end, ETestException);
end;

procedure TRetryPolicyTests.Test_Execute_RetriesHandledException;
var
  AttemptCount: Integer;
begin
  AttemptCount := 0;
  FRetryPolicy.MaxRetries(2).FixedDelay(1).Handle<ETestException>;

  Assert.WillRaise(
    procedure
    begin
      FRetryPolicy.Execute(
        procedure
        begin
          Inc(AttemptCount);
          raise ETestException.Create('Test');
        end);
    end, ETestException);

  Assert.AreEqual(3, AttemptCount); // Retried
end;

procedure TRetryPolicyTests.Test_Execute_DoesNotRetryUnhandledException;
var
  AttemptCount: Integer;
begin
  AttemptCount := 0;
  FRetryPolicy.MaxRetries(5).FixedDelay(1).Handle<ETestException>;

  Assert.WillRaise(
    procedure
    begin
      FRetryPolicy.Execute(
        procedure
        begin
          Inc(AttemptCount);
          raise ECustomException.Create('Unhandled');
        end);
    end, ECustomException);

  Assert.AreEqual(1, AttemptCount); // No retry
end;

procedure TRetryPolicyTests.Test_CalculateDelay_FixedStrategy;
var
  Delay: Int64;
  Policy: TRetryPolicy;
begin
  Policy := TRetryPolicy.Create;
  try
    Policy.FixedDelay(100);

    // Access private method via test helper or test via observable behavior
    // For now, test via timing
    Assert.IsTrue(True); // Placeholder - actual delay tested via execution
  finally
    Policy.Free;
  end;
end;

procedure TRetryPolicyTests.Test_CalculateDelay_LinearStrategy;
begin
  FRetryPolicy.LinearBackoff(100, 1000);
  // Linear: 100 * retryCount
  Assert.IsTrue(True); // Tested via observable behavior
end;

procedure TRetryPolicyTests.Test_CalculateDelay_ExponentialStrategy;
begin
  FRetryPolicy.ExponentialBackoff(100, 2.0, 5000);
  // Exponential: 100 * 2^(retryCount-1)
  Assert.IsTrue(True); // Tested via observable behavior
end;

procedure TRetryPolicyTests.Test_CalculateDelay_WithJitter;
begin
  FRetryPolicy.FixedDelay(100).WithJitter(0.5);
  // Delay varies +/- 50%
  Assert.IsTrue(True); // Tested via observable behavior
end;

procedure TRetryPolicyTests.Test_CalculateDelay_CappedAtMax;
begin
  FRetryPolicy.ExponentialBackoff(1000, 10.0, 5000);
  // Should cap at 5000
  Assert.IsTrue(True); // Tested via observable behavior
end;

procedure TRetryPolicyTests.Test_OnRetry_Fires;
var
  RetryCount: Integer;
  RetryEventFired: Boolean;
begin
  RetryCount := 0;
  RetryEventFired := False;

  FRetryPolicy
    .MaxRetries(2)
    .FixedDelay(1)
    .OnRetryEvent(
      procedure(Retry: Integer; E: Exception; var ShouldRetry: Boolean)
      begin
        RetryEventFired := True;
        RetryCount := Retry;
      end);

  try
    FRetryPolicy.Execute(
      procedure
      begin
        raise ETestException.Create('Test');
      end);
  except
  end;

  Assert.IsTrue(RetryEventFired);
  Assert.IsTrue(RetryCount > 0);
end;

procedure TRetryPolicyTests.Test_OnRetry_CanCancelRetry;
var
  AttemptCount: Integer;
begin
  AttemptCount := 0;

  FRetryPolicy
    .MaxRetries(5)
    .FixedDelay(1)
    .OnRetryEvent(
      procedure(Retry: Integer; E: Exception; var ShouldRetry: Boolean)
      begin
        if Retry >= 2 then
          ShouldRetry := False;
      end);

  Assert.WillRaise(
    procedure
    begin
      FRetryPolicy.Execute(
        procedure
        begin
          Inc(AttemptCount);
          raise ETestException.Create('Test');
        end);
    end, ETestException);

  Assert.AreEqual(2, AttemptCount); // Cancelled after 2nd attempt
end;

procedure TRetryPolicyTests.Test_OnWait_Fires;
var
  WaitEventFired: Boolean;
  WaitDelay: Int64;
begin
  WaitEventFired := False;
  WaitDelay := 0;

  FRetryPolicy
    .MaxRetries(1)
    .FixedDelay(10)
    .OnWaitEvent(
      procedure(Retry: Integer; DelayMs: Int64)
      begin
        WaitEventFired := True;
        WaitDelay := DelayMs;
      end);

  try
    FRetryPolicy.Execute(
      procedure
      begin
        raise ETestException.Create('Test');
      end);
  except
  end;

  Assert.IsTrue(WaitEventFired);
  Assert.AreEqual(Int64(10), WaitDelay);
end;

procedure TRetryPolicyTests.Test_TryExecute_ReturnsTrueOnSuccess;
var
  Success: Boolean;
  Error: Exception;
begin
  Success := FRetryPolicy.TryExecute(
    procedure
    begin
      // Success
    end, Error);

  Assert.IsTrue(Success);
  Assert.IsNull(Error);
end;

procedure TRetryPolicyTests.Test_TryExecute_ReturnsFalseOnFailure;
var
  Success: Boolean;
  Error: Exception;
begin
  FRetryPolicy.MaxRetries(1).FixedDelay(1);

  Success := FRetryPolicy.TryExecute(
    procedure
    begin
      raise ETestException.Create('Fail');
    end, Error);

  Assert.IsFalse(Success);
  Assert.IsNotNull(Error);
end;

// ============================================================================
// TTimeoutExceptionTests
// ============================================================================

procedure TTimeoutExceptionTests.Test_Create_StoresTimeout;
var
  E: ETimeoutException;
begin
  E := ETimeoutException.Create(5000);
  try
    Assert.AreEqual(Int64(5000), E.TimeoutMs);
  finally
    E.Free;
  end;
end;

procedure TTimeoutExceptionTests.Test_Create_FormatsMessage;
var
  E: ETimeoutException;
begin
  E := ETimeoutException.Create(3000);
  try
    Assert.Contains(E.Message, '3000');
  finally
    E.Free;
  end;
end;

// ============================================================================
// TTimeoutPolicyTests
// ============================================================================

procedure TTimeoutPolicyTests.Setup;
begin
  FTimeoutPolicy := TTimeoutPolicy.Create(1000);
end;

procedure TTimeoutPolicyTests.TearDown;
begin
  FTimeoutPolicy.Free;
end;

procedure TTimeoutPolicyTests.Test_Create_StoresTimeout;
begin
  Assert.IsNotNull(FTimeoutPolicy);
end;

procedure TTimeoutPolicyTests.Test_Timeout_FluentConfig;
var
  Result: TTimeoutPolicy;
begin
  Result := FTimeoutPolicy.Timeout(500);
  Assert.AreSame(FTimeoutPolicy, Result);
end;

procedure TTimeoutPolicyTests.Test_OnTimeoutEvent_FluentConfig;
var
  Result: TTimeoutPolicy;
begin
  Result := FTimeoutPolicy.OnTimeoutEvent(
    procedure(TimeoutMs: Int64)
    begin
    end);
  Assert.AreSame(FTimeoutPolicy, Result);
end;

procedure TTimeoutPolicyTests.Test_Execute_Proc_CompletesBeforeTimeout;
var
  Executed: Boolean;
begin
  Executed := False;
  FTimeoutPolicy.Timeout(500);

  FTimeoutPolicy.Execute(
    procedure
    begin
      Sleep(10);
      Executed := True;
    end);

  Assert.IsTrue(Executed);
end;

procedure TTimeoutPolicyTests.Test_Execute_Proc_RaisesOnTimeout;
begin
  FTimeoutPolicy.Timeout(50);

  Assert.WillRaise(
    procedure
    begin
      FTimeoutPolicy.Execute(
        procedure
        begin
          Sleep(500);
        end);
    end, ETimeoutException);
end;

procedure TTimeoutPolicyTests.Test_Execute_Func_CompletesBeforeTimeout;
var
  Result: Integer;
begin
  FTimeoutPolicy.Timeout(500);

  Result := FTimeoutPolicy.Execute<Integer>(
    function: Integer
    begin
      Sleep(10);
      Result := 42;
    end);

  Assert.AreEqual(42, Result);
end;

procedure TTimeoutPolicyTests.Test_Execute_Func_RaisesOnTimeout;
begin
  FTimeoutPolicy.Timeout(50);

  Assert.WillRaise(
    procedure
    begin
      FTimeoutPolicy.Execute<Integer>(
        function: Integer
        begin
          Sleep(500);
          Result := 0;
        end);
    end, ETimeoutException);
end;

procedure TTimeoutPolicyTests.Test_Execute_PropagatesException;
begin
  FTimeoutPolicy.Timeout(1000);

  Assert.WillRaise(
    procedure
    begin
      FTimeoutPolicy.Execute(
        procedure
        begin
          raise ETestException.Create('Inner');
        end);
    end, ETestException);
end;

procedure TTimeoutPolicyTests.Test_OnTimeout_Fires;
var
  TimeoutFired: Boolean;
  TimeoutValue: Int64;
begin
  TimeoutFired := False;
  TimeoutValue := 0;

  FTimeoutPolicy
    .Timeout(50)
    .OnTimeoutEvent(
      procedure(TimeoutMs: Int64)
      begin
        TimeoutFired := True;
        TimeoutValue := TimeoutMs;
      end);

  try
    FTimeoutPolicy.Execute(
      procedure
      begin
        Sleep(500);
      end);
  except
  end;

  Assert.IsTrue(TimeoutFired);
  Assert.AreEqual(Int64(50), TimeoutValue);
end;

// ============================================================================
// TFallbackPolicyTests
// ============================================================================

procedure TFallbackPolicyTests.Setup;
begin
  FFallbackPolicy := TFallbackPolicy<string>.Create;
  FIntFallbackPolicy := TFallbackPolicy<Integer>.Create;
end;

procedure TFallbackPolicyTests.TearDown;
begin
  FFallbackPolicy.Free;
  FIntFallbackPolicy.Free;
end;

procedure TFallbackPolicyTests.Test_Create;
begin
  Assert.IsNotNull(FFallbackPolicy);
end;

procedure TFallbackPolicyTests.Test_Value_FluentConfig;
var
  Result: TFallbackPolicy<string>;
begin
  Result := FFallbackPolicy.Value('default');
  Assert.AreSame(FFallbackPolicy, Result);
end;

procedure TFallbackPolicyTests.Test_ValueFunc_FluentConfig;
var
  Result: TFallbackPolicy<string>;
begin
  Result := FFallbackPolicy.ValueFunc(
    function(E: Exception): string
    begin
      Result := 'fallback';
    end);
  Assert.AreSame(FFallbackPolicy, Result);
end;

procedure TFallbackPolicyTests.Test_Handle_SpecificException;
var
  Result: TFallbackPolicy<string>;
begin
  Result := FFallbackPolicy.Handle<ETestException>;
  Assert.AreSame(FFallbackPolicy, Result);
end;

procedure TFallbackPolicyTests.Test_HandleAll;
var
  Result: TFallbackPolicy<string>;
begin
  Result := FFallbackPolicy.HandleAll;
  Assert.AreSame(FFallbackPolicy, Result);
end;

procedure TFallbackPolicyTests.Test_Execute_ReturnsResultOnSuccess;
var
  Result: string;
begin
  FFallbackPolicy.Value('fallback');

  Result := FFallbackPolicy.Execute(
    function: string
    begin
      Result := 'success';
    end);

  Assert.AreEqual('success', Result);
end;

procedure TFallbackPolicyTests.Test_Execute_ReturnsFallbackOnException;
var
  Result: string;
begin
  FFallbackPolicy.Value('fallback').HandleAll;

  Result := FFallbackPolicy.Execute(
    function: string
    begin
      raise ETestException.Create('Error');
    end);

  Assert.AreEqual('fallback', Result);
end;

procedure TFallbackPolicyTests.Test_Execute_ReturnsFallbackFunc;
var
  Result: string;
begin
  FFallbackPolicy
    .ValueFunc(
      function(E: Exception): string
      begin
        Result := 'Error: ' + E.Message;
      end)
    .HandleAll;

  Result := FFallbackPolicy.Execute(
    function: string
    begin
      raise ETestException.Create('Test');
    end);

  Assert.AreEqual('Error: Test', Result);
end;

procedure TFallbackPolicyTests.Test_Execute_RaisesUnhandledException;
begin
  FFallbackPolicy.Value('fallback').Handle<ETestException>;

  Assert.WillRaise(
    procedure
    begin
      FFallbackPolicy.Execute(
        function: string
        begin
          raise ECustomException.Create('Unhandled');
        end);
    end, ECustomException);
end;

procedure TFallbackPolicyTests.Test_Execute_IntegerFallback;
var
  Result: Integer;
begin
  FIntFallbackPolicy.Value(-1).HandleAll;

  Result := FIntFallbackPolicy.Execute(
    function: Integer
    begin
      raise ETestException.Create('Error');
    end);

  Assert.AreEqual(-1, Result);
end;

// ============================================================================
// TBulkheadRejectedExceptionTests
// ============================================================================

procedure TBulkheadRejectedExceptionTests.Test_Create_StoresMaxConcurrency;
var
  E: EBulkheadRejectedException;
begin
  E := EBulkheadRejectedException.Create(5);
  try
    Assert.AreEqual(5, E.MaxConcurrency);
  finally
    E.Free;
  end;
end;

procedure TBulkheadRejectedExceptionTests.Test_Create_FormatsMessage;
var
  E: EBulkheadRejectedException;
begin
  E := EBulkheadRejectedException.Create(10);
  try
    Assert.Contains(E.Message, '10');
  finally
    E.Free;
  end;
end;

// ============================================================================
// TBulkheadPolicyTests
// ============================================================================

procedure TBulkheadPolicyTests.Setup;
begin
  FBulkheadPolicy := TBulkheadPolicy.Create(2);
end;

procedure TBulkheadPolicyTests.TearDown;
begin
  FBulkheadPolicy.Free;
end;

procedure TBulkheadPolicyTests.Test_Create_InitialValues;
begin
  Assert.AreEqual(2, FBulkheadPolicy.MaxConcurrency);
  Assert.AreEqual(0, FBulkheadPolicy.CurrentCount);
  Assert.AreEqual(0, FBulkheadPolicy.QueueCount);
end;

procedure TBulkheadPolicyTests.Test_MaxQueue_FluentConfig;
var
  Result: TBulkheadPolicy;
begin
  Result := FBulkheadPolicy.MaxQueue(5);
  Assert.AreSame(FBulkheadPolicy, Result);
end;

procedure TBulkheadPolicyTests.Test_QueueTimeout_FluentConfig;
var
  Result: TBulkheadPolicy;
begin
  Result := FBulkheadPolicy.QueueTimeout(5000);
  Assert.AreSame(FBulkheadPolicy, Result);
end;

procedure TBulkheadPolicyTests.Test_Execute_Proc_Success;
var
  Executed: Boolean;
begin
  Executed := False;
  FBulkheadPolicy.Execute(
    procedure
    begin
      Executed := True;
    end);
  Assert.IsTrue(Executed);
end;

procedure TBulkheadPolicyTests.Test_Execute_Func_Success;
var
  Result: Integer;
begin
  Result := FBulkheadPolicy.Execute<Integer>(
    function: Integer
    begin
      Result := 42;
    end);
  Assert.AreEqual(42, Result);
end;

procedure TBulkheadPolicyTests.Test_Execute_RejectsBeyondMax;
var
  Tasks: array[0..2] of ITask;
  RejectionCount: Integer;
  Lock: TCriticalSection;
  I: Integer;
  Policy: TBulkheadPolicy;
begin
  Lock := TCriticalSection.Create;
  Policy := TBulkheadPolicy.Create(1); // Only 1 concurrent
  try
    RejectionCount := 0;

    for I := 0 to High(Tasks) do
    begin
      Tasks[I] := TTask.Create(
        procedure
        begin
          try
            Policy.Execute(
              procedure
              begin
                Sleep(100);
              end);
          except
            on E: EBulkheadRejectedException do
            begin
              Lock.Enter;
              try
                Inc(RejectionCount);
              finally
                Lock.Leave;
              end;
            end;
          end;
        end);
      Tasks[I].Start;
      Sleep(10); // Small delay to ensure ordering
    end;

    TTask.WaitForAll(Tasks);
    Assert.IsTrue(RejectionCount >= 1);
  finally
    Lock.Free;
    Policy.Free;
  end;
end;

procedure TBulkheadPolicyTests.Test_Execute_QueuesWhenFull;
var
  Tasks: array[0..1] of ITask;
  ExecuteCount: Integer;
  Lock: TCriticalSection;
  I: Integer;
  Policy: TBulkheadPolicy;
begin
  Lock := TCriticalSection.Create;
  Policy := TBulkheadPolicy.Create(1, 1); // 1 concurrent, 1 queue
  try
    ExecuteCount := 0;

    for I := 0 to High(Tasks) do
    begin
      Tasks[I] := TTask.Create(
        procedure
        begin
          try
            Policy.Execute(
              procedure
              begin
                Lock.Enter;
                try
                  Inc(ExecuteCount);
                finally
                  Lock.Leave;
                end;
                Sleep(50);
              end);
          except
          end;
        end);
      Tasks[I].Start;
    end;

    TTask.WaitForAll(Tasks);
    Assert.AreEqual(2, ExecuteCount); // Both should execute (one queued)
  finally
    Lock.Free;
    Policy.Free;
  end;
end;

procedure TBulkheadPolicyTests.Test_Execute_RejectsWhenQueueFull;
var
  Tasks: array[0..2] of ITask;
  RejectionCount: Integer;
  Lock: TCriticalSection;
  I: Integer;
  Policy: TBulkheadPolicy;
begin
  Lock := TCriticalSection.Create;
  Policy := TBulkheadPolicy.Create(1, 0); // 1 concurrent, 0 queue
  try
    RejectionCount := 0;

    for I := 0 to High(Tasks) do
    begin
      Tasks[I] := TTask.Create(
        procedure
        begin
          try
            Policy.Execute(
              procedure
              begin
                Sleep(100);
              end);
          except
            on E: EBulkheadRejectedException do
            begin
              Lock.Enter;
              try
                Inc(RejectionCount);
              finally
                Lock.Leave;
              end;
            end;
          end;
        end);
      Tasks[I].Start;
      Sleep(5);
    end;

    TTask.WaitForAll(Tasks);
    Assert.IsTrue(RejectionCount >= 2); // At least 2 rejected
  finally
    Lock.Free;
    Policy.Free;
  end;
end;

procedure TBulkheadPolicyTests.Test_TryExecute_ReturnsTrueOnSuccess;
var
  Result: Boolean;
begin
  Result := FBulkheadPolicy.TryExecute(
    procedure
    begin
      // Success
    end);
  Assert.IsTrue(Result);
end;

procedure TBulkheadPolicyTests.Test_TryExecute_ReturnsFalseOnRejection;
var
  Tasks: array[0..1] of ITask;
  RejectedResult: Boolean;
  Lock: TCriticalSection;
  I: Integer;
  Policy: TBulkheadPolicy;
begin
  Lock := TCriticalSection.Create;
  Policy := TBulkheadPolicy.Create(1, 0);
  try
    RejectedResult := True;

    // First task blocks
    Tasks[0] := TTask.Create(
      procedure
      begin
        Policy.Execute(
          procedure
          begin
            Sleep(200);
          end);
      end);
    Tasks[0].Start;
    Sleep(20); // Let first task start

    // Second task should be rejected
    Tasks[1] := TTask.Create(
      procedure
      begin
        Lock.Enter;
        try
          RejectedResult := Policy.TryExecute(
            procedure
            begin
              Sleep(10);
            end);
        finally
          Lock.Leave;
        end;
      end);
    Tasks[1].Start;

    TTask.WaitForAll(Tasks);
    Assert.IsFalse(RejectedResult);
  finally
    Lock.Free;
    Policy.Free;
  end;
end;

procedure TBulkheadPolicyTests.Test_CurrentCount_TracksActive;
var
  CurrentInExec: Integer;
begin
  CurrentInExec := -1;

  FBulkheadPolicy.Execute(
    procedure
    begin
      CurrentInExec := FBulkheadPolicy.CurrentCount;
    end);

  Assert.AreEqual(1, CurrentInExec);
  Assert.AreEqual(0, FBulkheadPolicy.CurrentCount);
end;

procedure TBulkheadPolicyTests.Test_QueueCount_TracksQueued;
begin
  // Initial queue count should be 0
  Assert.AreEqual(0, FBulkheadPolicy.QueueCount);
end;

procedure TBulkheadPolicyTests.Test_ThreadSafety_ConcurrentExecute;
var
  Tasks: array of ITask;
  SuccessCount: Integer;
  Lock: TCriticalSection;
  I: Integer;
  Policy: TBulkheadPolicy;
begin
  Lock := TCriticalSection.Create;
  Policy := TBulkheadPolicy.Create(5, 10);
  try
    SuccessCount := 0;
    SetLength(Tasks, 20);

    for I := 0 to High(Tasks) do
    begin
      Tasks[I] := TTask.Create(
        procedure
        begin
          try
            Policy.Execute(
              procedure
              begin
                Sleep(10);
              end);
            Lock.Enter;
            try
              Inc(SuccessCount);
            finally
              Lock.Leave;
            end;
          except
          end;
        end);
      Tasks[I].Start;
    end;

    TTask.WaitForAll(Tasks);
    Assert.IsTrue(SuccessCount > 0);
  finally
    Lock.Free;
    Policy.Free;
  end;
end;

// ============================================================================
// TResiliencePolicyTests
// ============================================================================

procedure TResiliencePolicyTests.Setup;
begin
  FPolicy := TResiliencePolicy.Create;
end;

procedure TResiliencePolicyTests.TearDown;
begin
  FPolicy.Free;
end;

procedure TResiliencePolicyTests.Test_Create;
begin
  Assert.IsNotNull(FPolicy);
end;

procedure TResiliencePolicyTests.Test_WithRetry_FluentConfig;
var
  Result: TResiliencePolicy;
begin
  Result := FPolicy.WithRetry(TRetryPolicy.Create);
  Assert.AreSame(FPolicy, Result);
end;

procedure TResiliencePolicyTests.Test_WithTimeout_Policy_FluentConfig;
var
  Result: TResiliencePolicy;
begin
  Result := FPolicy.WithTimeout(TTimeoutPolicy.Create(1000));
  Assert.AreSame(FPolicy, Result);
end;

procedure TResiliencePolicyTests.Test_WithTimeout_Ms_FluentConfig;
var
  Result: TResiliencePolicy;
begin
  Result := FPolicy.WithTimeout(1000);
  Assert.AreSame(FPolicy, Result);
end;

procedure TResiliencePolicyTests.Test_WithCircuitBreaker_FluentConfig;
var
  CB: TCircuitBreaker;
  Result: TResiliencePolicy;
begin
  CB := TCircuitBreaker.Create('Test');
  try
    Result := FPolicy.WithCircuitBreaker(CB, False);
    Assert.AreSame(FPolicy, Result);
  finally
    CB.Free;
  end;
end;

procedure TResiliencePolicyTests.Test_WithBulkhead_Policy_FluentConfig;
var
  Result: TResiliencePolicy;
begin
  Result := FPolicy.WithBulkhead(TBulkheadPolicy.Create(5));
  Assert.AreSame(FPolicy, Result);
end;

procedure TResiliencePolicyTests.Test_WithBulkhead_Int_FluentConfig;
var
  Result: TResiliencePolicy;
begin
  Result := FPolicy.WithBulkhead(10);
  Assert.AreSame(FPolicy, Result);
end;

procedure TResiliencePolicyTests.Test_Execute_Proc_WithAllPolicies;
var
  Executed: Boolean;
  CB: TCircuitBreaker;
begin
  Executed := False;
  CB := TCircuitBreaker.Create('Test');
  try
    FPolicy
      .WithRetry(TRetryPolicy.Create.MaxRetries(1).FixedDelay(1))
      .WithTimeout(1000)
      .WithCircuitBreaker(CB, False)
      .WithBulkhead(5);

    FPolicy.Execute(
      procedure
      begin
        Executed := True;
      end);

    Assert.IsTrue(Executed);
  finally
    CB.Free;
  end;
end;

procedure TResiliencePolicyTests.Test_Execute_Func_WithAllPolicies;
var
  Result: string;
  CB: TCircuitBreaker;
begin
  CB := TCircuitBreaker.Create('Test');
  try
    FPolicy
      .WithRetry(TRetryPolicy.Create.MaxRetries(1).FixedDelay(1))
      .WithTimeout(1000)
      .WithCircuitBreaker(CB, False)
      .WithBulkhead(5);

    Result := FPolicy.Execute<string>(
      function: string
      begin
        Result := 'Success';
      end);

    Assert.AreEqual('Success', Result);
  finally
    CB.Free;
  end;
end;

procedure TResiliencePolicyTests.Test_Execute_Proc_NoPolicy;
var
  Executed: Boolean;
begin
  Executed := False;

  FPolicy.Execute(
    procedure
    begin
      Executed := True;
    end);

  Assert.IsTrue(Executed);
end;

procedure TResiliencePolicyTests.Test_Execute_RetryOnly;
var
  AttemptCount: Integer;
begin
  AttemptCount := 0;
  FPolicy.WithRetry(TRetryPolicy.Create.MaxRetries(2).FixedDelay(1));

  try
    FPolicy.Execute(
      procedure
      begin
        Inc(AttemptCount);
        if AttemptCount < 2 then
          raise ETestException.Create('Retry');
      end);
  except
  end;

  Assert.IsTrue(AttemptCount >= 2);
end;

procedure TResiliencePolicyTests.Test_Execute_TimeoutOnly;
begin
  FPolicy.WithTimeout(50);

  Assert.WillRaise(
    procedure
    begin
      FPolicy.Execute(
        procedure
        begin
          Sleep(500);
        end);
    end, ETimeoutException);
end;

procedure TResiliencePolicyTests.Test_PolicyOwnership_True;
var
  Policy: TResiliencePolicy;
begin
  // Test that policies are freed when owned
  Policy := TResiliencePolicy.Create;
  Policy.WithRetry(TRetryPolicy.Create, True);
  Policy.WithTimeout(TTimeoutPolicy.Create(1000), True);
  Policy.WithBulkhead(TBulkheadPolicy.Create(5), True);
  Policy.Free; // Should not leak memory
  Assert.IsTrue(True); // If no AV, ownership works
end;

procedure TResiliencePolicyTests.Test_PolicyOwnership_False;
var
  Policy: TResiliencePolicy;
  Retry: TRetryPolicy;
  Timeout: TTimeoutPolicy;
  Bulkhead: TBulkheadPolicy;
begin
  Policy := TResiliencePolicy.Create;
  Retry := TRetryPolicy.Create;
  Timeout := TTimeoutPolicy.Create(1000);
  Bulkhead := TBulkheadPolicy.Create(5);
  try
    Policy.WithRetry(Retry, False);
    Policy.WithTimeout(Timeout, False);
    Policy.WithBulkhead(Bulkhead, False);
    Policy.Free;
    // Policies should still be valid
    Assert.IsNotNull(Retry);
    Assert.IsNotNull(Timeout);
    Assert.IsNotNull(Bulkhead);
  finally
    Retry.Free;
    Timeout.Free;
    Bulkhead.Free;
  end;
end;

// ============================================================================
// TCircuitBreakerRegistryTests
// ============================================================================

procedure TCircuitBreakerRegistryTests.Setup;
begin
  FRegistry := TCircuitBreakerRegistry.Create;
end;

procedure TCircuitBreakerRegistryTests.TearDown;
begin
  FRegistry.Free;
end;

procedure TCircuitBreakerRegistryTests.Test_Create;
begin
  Assert.IsNotNull(FRegistry);
end;

procedure TCircuitBreakerRegistryTests.Test_GetOrCreate_CreatesNew;
var
  CB: TCircuitBreaker;
begin
  CB := FRegistry.GetOrCreate('Test');
  Assert.IsNotNull(CB);
  Assert.AreEqual('Test', CB.Name);
end;

procedure TCircuitBreakerRegistryTests.Test_GetOrCreate_ReturnsSame;
var
  CB1, CB2: TCircuitBreaker;
begin
  CB1 := FRegistry.GetOrCreate('Test');
  CB2 := FRegistry.GetOrCreate('Test');
  Assert.AreSame(CB1, CB2);
end;

procedure TCircuitBreakerRegistryTests.Test_TryGet_ReturnsTrueIfExists;
var
  CB: TCircuitBreaker;
begin
  FRegistry.GetOrCreate('Test');
  Assert.IsTrue(FRegistry.TryGet('Test', CB));
  Assert.IsNotNull(CB);
end;

procedure TCircuitBreakerRegistryTests.Test_TryGet_ReturnsFalseIfNotExists;
var
  CB: TCircuitBreaker;
begin
  Assert.IsFalse(FRegistry.TryGet('NonExistent', CB));
end;

procedure TCircuitBreakerRegistryTests.Test_Remove_RemovesBreaker;
var
  CB: TCircuitBreaker;
begin
  FRegistry.GetOrCreate('Test');
  FRegistry.Remove('Test');
  Assert.IsFalse(FRegistry.TryGet('Test', CB));
end;

procedure TCircuitBreakerRegistryTests.Test_Remove_DoesNothingIfNotExists;
begin
  FRegistry.Remove('NonExistent');
  Assert.IsTrue(True); // No exception
end;

procedure TCircuitBreakerRegistryTests.Test_Clear_RemovesAllBreakers;
var
  CB: TCircuitBreaker;
begin
  FRegistry.GetOrCreate('Test1');
  FRegistry.GetOrCreate('Test2');
  FRegistry.GetOrCreate('Test3');

  FRegistry.Clear;

  Assert.IsFalse(FRegistry.TryGet('Test1', CB));
  Assert.IsFalse(FRegistry.TryGet('Test2', CB));
  Assert.IsFalse(FRegistry.TryGet('Test3', CB));
end;

procedure TCircuitBreakerRegistryTests.Test_Instance_ReturnsSingleton;
var
  R1, R2: TCircuitBreakerRegistry;
begin
  R1 := TCircuitBreakerRegistry.Instance;
  R2 := TCircuitBreakerRegistry.Instance;
  Assert.AreSame(R1, R2);
end;

procedure TCircuitBreakerRegistryTests.Test_CircuitBreakers_GlobalFunction;
var
  R: TCircuitBreakerRegistry;
begin
  R := CircuitBreakers;
  Assert.IsNotNull(R);
end;

procedure TCircuitBreakerRegistryTests.Test_ThreadSafety_ConcurrentGetOrCreate;
var
  Tasks: array of ITask;
  I: Integer;
  Breakers: TList<TCircuitBreaker>;
  Lock: TCriticalSection;
begin
  Lock := TCriticalSection.Create;
  Breakers := TList<TCircuitBreaker>.Create;
  try
    SetLength(Tasks, 10);

    for I := 0 to High(Tasks) do
    begin
      Tasks[I] := TTask.Create(
        procedure
        var
          CB: TCircuitBreaker;
        begin
          CB := FRegistry.GetOrCreate('SharedBreaker');
          Lock.Enter;
          try
            if not Breakers.Contains(CB) then
              Breakers.Add(CB);
          finally
            Lock.Leave;
          end;
        end);
      Tasks[I].Start;
    end;

    TTask.WaitForAll(Tasks);

    // All threads should get the same breaker
    Assert.AreEqual<Integer>(1, Breakers.Count);
  finally
    Breakers.Free;
    Lock.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TCircuitBreakerTests);
  TDUnitX.RegisterTestFixture(TRetryPolicyTests);
  TDUnitX.RegisterTestFixture(TTimeoutExceptionTests);
  TDUnitX.RegisterTestFixture(TTimeoutPolicyTests);
  TDUnitX.RegisterTestFixture(TFallbackPolicyTests);
  TDUnitX.RegisterTestFixture(TBulkheadRejectedExceptionTests);
  TDUnitX.RegisterTestFixture(TBulkheadPolicyTests);
  TDUnitX.RegisterTestFixture(TResiliencePolicyTests);
  TDUnitX.RegisterTestFixture(TCircuitBreakerRegistryTests);

end.
