unit Test.UniBase.EventBus;

{*******************************************************************************
  UniBase EventBus Module Unit Tests
  
  Test Coverage:
  - Subscribe/Unsubscribe operations
  - Publish synchronous events
  - Publish asynchronous events
  - Event priorities
  - Event filtering
  - Dispatch modes (Sync/Async/MainThread)
  - Event history and replay
  - Statistics tracking
  - Tag-based management
  - Thread safety
  - Dead letter handling
  - Error handling
*******************************************************************************}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Threading,
  System.Rtti,
  UniBase.EventBus;

type
  // Test event types
  TTestEvent = record
    Id: Integer;
    Message: string;
    Timestamp: TDateTime;
  end;
  
  TUserLoginEvent = record
    UserId: Integer;
    Username: string;
  end;
  
  TOrderEvent = record
    OrderId: Integer;
    Amount: Double;
    Status: string;
  end;

  [TestFixture]
  TTestUniBaseEventBus = class
  private
    FEventBus: TEventBus;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    // Basic Subscribe/Publish
    [Test]
    procedure Test_Subscribe_And_Publish_BasicEvent;
    
    [Test]
    procedure Test_Subscribe_MultipleHandlers;
    
    [Test]
    procedure Test_Unsubscribe_RemovesHandler;
    
    [Test]
    procedure Test_UnsubscribeAll_RemovesAllHandlersForType;
    
    [Test]
    procedure Test_UnsubscribeByTag_RemovesTaggedHandlers;
    
    // Event Priorities
    [Test]
    procedure Test_Priority_HighBeforeNormal;
    
    [Test]
    procedure Test_Priority_CriticalFirst;
    
    [Test]
    procedure Test_Priority_OrderPreservedWithinSamePriority;
    
    // Event Filtering
    [Test]
    procedure Test_Filter_OnlyMatchingEventsDelivered;
    
    [Test]
    procedure Test_Filter_NoFilterReceivesAll;
    
    // Dispatch Modes
    [Test]
    procedure Test_DispatchMode_Sync_ExecutesImmediately;
    
    [Test]
    procedure Test_DispatchMode_Async_ExecutesInBackground;
    
    // Statistics
    [Test]
    procedure Test_Stats_TotalPublished;
    
    [Test]
    procedure Test_Stats_TotalDelivered;
    
    [Test]
    procedure Test_Stats_TotalFiltered;
    
    [Test]
    procedure Test_Stats_ActiveSubscriptions;
    
    [Test]
    procedure Test_Stats_Reset;
    
    // Query Methods
    [Test]
    procedure Test_HasSubscribers_True;
    
    [Test]
    procedure Test_HasSubscribers_False;
    
    [Test]
    procedure Test_GetSubscriberCount;
    
    [Test]
    procedure Test_GetEventTypes;
    
    // History
    [Test]
    procedure Test_KeepHistory_StoresEvents;
    
    [Test]
    procedure Test_ReplayHistory_DeliversPastEvents;
    
    [Test]
    procedure Test_ClearHistory;
    
    [Test]
    procedure Test_MaxHistorySize_LimitsStorage;
    
    // Enabled Flag
    [Test]
    procedure Test_Disabled_NoEventsDelivered;
    
    [Test]
    procedure Test_ReEnabled_EventsDelivered;
    
    // Error Handling
    [Test]
    procedure Test_OnError_CalledOnException;
    
    [Test]
    procedure Test_DeadLetter_CalledWhenNoSubscribers;
    
    // Clear
    [Test]
    procedure Test_Clear_RemovesAllSubscriptions;
    
    // Thread Safety
    [Test]
    procedure Test_ThreadSafety_ConcurrentPublish;
    
    [Test]
    procedure Test_ThreadSafety_ConcurrentSubscribeUnsubscribe;
    
    // ISubscription interface
    [Test]
    procedure Test_Subscription_IsActive;
    
    [Test]
    procedure Test_Subscription_GetEventType;
  end;

  [TestFixture]
  TTestEventBusStats = class
  public
    [Test]
    procedure Test_Reset_ClearsAllCounters;
    
    [Test]
    procedure Test_ToString_FormatsCorrectly;
  end;
  
  [TestFixture]
  TTestGlobalEventBus = class
  public
    [Test]
    procedure Test_EventBus_ReturnsSingleton;
    
    [Test]
    procedure Test_SetEventBus_ReplacesInstance;
  end;

implementation

{ TTestUniBaseEventBus }

procedure TTestUniBaseEventBus.Setup;
begin
  FEventBus := TEventBus.Create;
end;

procedure TTestUniBaseEventBus.TearDown;
begin
  FEventBus.Free;
  FEventBus := nil;
end;

procedure TTestUniBaseEventBus.Test_Subscribe_And_Publish_BasicEvent;
var
  ReceivedEvent: TTestEvent;
  EventReceived: Boolean;
begin
  EventReceived := False;
  
  FEventBus.Subscribe<TTestEvent>(
    procedure(const Event: TTestEvent)
    begin
      ReceivedEvent := Event;
      EventReceived := True;
    end);
  
  var TestEvent: TTestEvent;
  TestEvent.Id := 123;
  TestEvent.Message := 'Hello World';
  TestEvent.Timestamp := Now;
  
  FEventBus.Publish<TTestEvent>(TestEvent);
  
  Assert.IsTrue(EventReceived, 'Event should be received');
  Assert.AreEqual(123, ReceivedEvent.Id);
  Assert.AreEqual('Hello World', ReceivedEvent.Message);
end;

procedure TTestUniBaseEventBus.Test_Subscribe_MultipleHandlers;
var
  Count: Integer;
begin
  Count := 0;
  
  FEventBus.Subscribe<TTestEvent>(
    procedure(const Event: TTestEvent)
    begin
      TInterlocked.Increment(Count);
    end);
  
  FEventBus.Subscribe<TTestEvent>(
    procedure(const Event: TTestEvent)
    begin
      TInterlocked.Increment(Count);
    end);
  
  FEventBus.Subscribe<TTestEvent>(
    procedure(const Event: TTestEvent)
    begin
      TInterlocked.Increment(Count);
    end);
  
  var TestEvent: TTestEvent;
  TestEvent.Id := 1;
  FEventBus.Publish<TTestEvent>(TestEvent);
  
  Assert.AreEqual(3, Count, 'All 3 handlers should be invoked');
end;

procedure TTestUniBaseEventBus.Test_Unsubscribe_RemovesHandler;
var
  Count: Integer;
  Subscription: ISubscription;
begin
  Count := 0;
  
  Subscription := FEventBus.Subscribe<TTestEvent>(
    procedure(const Event: TTestEvent)
    begin
      TInterlocked.Increment(Count);
    end);
  
  // First publish
  var TestEvent: TTestEvent;
  TestEvent.Id := 1;
  FEventBus.Publish<TTestEvent>(TestEvent);
  Assert.AreEqual(1, Count);
  
  // Unsubscribe
  Subscription.Unsubscribe;
  
  // Second publish - should not increment
  FEventBus.Publish<TTestEvent>(TestEvent);
  Assert.AreEqual(1, Count, 'Handler should not be called after unsubscribe');
end;

procedure TTestUniBaseEventBus.Test_UnsubscribeAll_RemovesAllHandlersForType;
var
  TestCount, LoginCount: Integer;
begin
  TestCount := 0;
  LoginCount := 0;
  
  FEventBus.Subscribe<TTestEvent>(
    procedure(const Event: TTestEvent)
    begin
      TInterlocked.Increment(TestCount);
    end);
  
  FEventBus.Subscribe<TTestEvent>(
    procedure(const Event: TTestEvent)
    begin
      TInterlocked.Increment(TestCount);
    end);
  
  FEventBus.Subscribe<TUserLoginEvent>(
    procedure(const Event: TUserLoginEvent)
    begin
      TInterlocked.Increment(LoginCount);
    end);
  
  // Unsubscribe all TTestEvent handlers
  FEventBus.UnsubscribeAll<TTestEvent>;
  
  var TestEvent: TTestEvent;
  TestEvent.Id := 1;
  FEventBus.Publish<TTestEvent>(TestEvent);
  
  var LoginEvent: TUserLoginEvent;
  LoginEvent.UserId := 1;
  FEventBus.Publish<TUserLoginEvent>(LoginEvent);
  
  Assert.AreEqual(0, TestCount, 'TTestEvent handlers should be removed');
  Assert.AreEqual(1, LoginCount, 'TUserLoginEvent handler should still work');
end;

procedure TTestUniBaseEventBus.Test_UnsubscribeByTag_RemovesTaggedHandlers;
var
  TaggedCount, UntaggedCount: Integer;
begin
  TaggedCount := 0;
  UntaggedCount := 0;
  
  FEventBus.Subscribe<TTestEvent>(
    procedure(const Event: TTestEvent)
    begin
      TInterlocked.Increment(TaggedCount);
    end, epNormal, edmSync, nil, 'MyTag');
  
  FEventBus.Subscribe<TTestEvent>(
    procedure(const Event: TTestEvent)
    begin
      TInterlocked.Increment(UntaggedCount);
    end);
  
  FEventBus.UnsubscribeByTag('MyTag');
  
  var TestEvent: TTestEvent;
  TestEvent.Id := 1;
  FEventBus.Publish<TTestEvent>(TestEvent);
  
  Assert.AreEqual(0, TaggedCount, 'Tagged handler should be removed');
  Assert.AreEqual(1, UntaggedCount, 'Untagged handler should remain');
end;

procedure TTestUniBaseEventBus.Test_Priority_HighBeforeNormal;
var
  Order: string;
begin
  Order := '';
  
  FEventBus.Subscribe<TTestEvent>(
    procedure(const Event: TTestEvent)
    begin
      Order := Order + 'N';
    end, epNormal);
  
  FEventBus.Subscribe<TTestEvent>(
    procedure(const Event: TTestEvent)
    begin
      Order := Order + 'H';
    end, epHigh);
  
  var TestEvent: TTestEvent;
  FEventBus.Publish<TTestEvent>(TestEvent);
  
  Assert.AreEqual('HN', Order, 'High priority should execute before Normal');
end;

procedure TTestUniBaseEventBus.Test_Priority_CriticalFirst;
var
  Order: string;
begin
  Order := '';
  
  FEventBus.Subscribe<TTestEvent>(
    procedure(const Event: TTestEvent)
    begin
      Order := Order + 'L';
    end, epLow);
  
  FEventBus.Subscribe<TTestEvent>(
    procedure(const Event: TTestEvent)
    begin
      Order := Order + 'C';
    end, epCritical);
  
  FEventBus.Subscribe<TTestEvent>(
    procedure(const Event: TTestEvent)
    begin
      Order := Order + 'N';
    end, epNormal);
  
  FEventBus.Subscribe<TTestEvent>(
    procedure(const Event: TTestEvent)
    begin
      Order := Order + 'H';
    end, epHigh);
  
  var TestEvent: TTestEvent;
  FEventBus.Publish<TTestEvent>(TestEvent);
  
  Assert.AreEqual('CHNL', Order, 'Priority order: Critical > High > Normal > Low');
end;

procedure TTestUniBaseEventBus.Test_Priority_OrderPreservedWithinSamePriority;
var
  Order: string;
begin
  Order := '';
  
  FEventBus.Subscribe<TTestEvent>(
    procedure(const Event: TTestEvent)
    begin
      Order := Order + '1';
    end, epNormal);
  
  FEventBus.Subscribe<TTestEvent>(
    procedure(const Event: TTestEvent)
    begin
      Order := Order + '2';
    end, epNormal);
  
  FEventBus.Subscribe<TTestEvent>(
    procedure(const Event: TTestEvent)
    begin
      Order := Order + '3';
    end, epNormal);
  
  var TestEvent: TTestEvent;
  FEventBus.Publish<TTestEvent>(TestEvent);
  
  Assert.AreEqual('123', Order, 'Subscription order should be preserved within same priority');
end;

procedure TTestUniBaseEventBus.Test_Filter_OnlyMatchingEventsDelivered;
var
  ReceivedCount: Integer;
begin
  ReceivedCount := 0;
  
  FEventBus.Subscribe<TOrderEvent>(
    procedure(const Event: TOrderEvent)
    begin
      TInterlocked.Increment(ReceivedCount);
    end,
    function(const Event: TOrderEvent): Boolean
    begin
      Result := Event.Amount > 100;  // Only high-value orders
    end);
  
  var SmallOrder: TOrderEvent;
  SmallOrder.OrderId := 1;
  SmallOrder.Amount := 50;
  FEventBus.Publish<TOrderEvent>(SmallOrder);
  
  var LargeOrder: TOrderEvent;
  LargeOrder.OrderId := 2;
  LargeOrder.Amount := 200;
  FEventBus.Publish<TOrderEvent>(LargeOrder);
  
  Assert.AreEqual(1, ReceivedCount, 'Only order > 100 should be delivered');
end;

procedure TTestUniBaseEventBus.Test_Filter_NoFilterReceivesAll;
var
  ReceivedCount: Integer;
begin
  ReceivedCount := 0;
  
  FEventBus.Subscribe<TOrderEvent>(
    procedure(const Event: TOrderEvent)
    begin
      TInterlocked.Increment(ReceivedCount);
    end);
  
  var Order1: TOrderEvent;
  Order1.Amount := 50;
  FEventBus.Publish<TOrderEvent>(Order1);
  
  var Order2: TOrderEvent;
  Order2.Amount := 200;
  FEventBus.Publish<TOrderEvent>(Order2);
  
  Assert.AreEqual(2, ReceivedCount, 'Without filter, all events should be delivered');
end;

procedure TTestUniBaseEventBus.Test_DispatchMode_Sync_ExecutesImmediately;
var
  Executed: Boolean;
begin
  Executed := False;
  
  FEventBus.Subscribe<TTestEvent>(
    procedure(const Event: TTestEvent)
    begin
      Executed := True;
    end, epNormal, edmSync);
  
  var TestEvent: TTestEvent;
  FEventBus.Publish<TTestEvent>(TestEvent);
  
  // Should be true immediately after publish
  Assert.IsTrue(Executed, 'Sync handler should execute immediately');
end;

procedure TTestUniBaseEventBus.Test_DispatchMode_Async_ExecutesInBackground;
var
  Executed: Boolean;
  StartTime: TDateTime;
  CompletionEvent: TEvent;  // BUG-027 FIX: 使用事件同步替代固定延时
  WaitResult: TWaitResult;
begin
  Executed := False;
  CompletionEvent := TEvent.Create(nil, True, False, '');  // Manual reset
  try
    FEventBus.Subscribe<TTestEvent>(
      procedure(const Event: TTestEvent)
      begin
        Sleep(50);  // BUG-027 FIX: 减少Sleep时间，主要用于验证异步特性
        Executed := True;
        CompletionEvent.SetEvent;  // BUG-027 FIX: 信号通知完成
      end, epNormal, edmAsync);

    var TestEvent: TTestEvent;
    StartTime := Now;
    FEventBus.Publish<TTestEvent>(TestEvent);

    // Should return quickly (not wait for sleep)
    Assert.IsFalse(Executed, 'Async handler should not have completed immediately');

    // BUG-027 FIX: 使用事件等待替代固定Sleep，超时设为2000ms以适应高负载系统
    WaitResult := CompletionEvent.WaitFor(2000);
    Assert.AreEqual(wrSignaled, WaitResult, 'Async handler should complete within timeout');
    Assert.IsTrue(Executed, 'Async handler should complete eventually');
  finally
    CompletionEvent.Free;
  end;
end;

procedure TTestUniBaseEventBus.Test_Stats_TotalPublished;
var
  InitialCount: Int64;
begin
  InitialCount := FEventBus.Stats.TotalPublished;
  
  var TestEvent: TTestEvent;
  FEventBus.Publish<TTestEvent>(TestEvent);
  FEventBus.Publish<TTestEvent>(TestEvent);
  FEventBus.Publish<TTestEvent>(TestEvent);
  
  Assert.AreEqual(InitialCount + 3, FEventBus.Stats.TotalPublished);
end;

procedure TTestUniBaseEventBus.Test_Stats_TotalDelivered;
var
  InitialCount: Int64;
begin
  InitialCount := FEventBus.Stats.TotalDelivered;
  
  FEventBus.Subscribe<TTestEvent>(
    procedure(const Event: TTestEvent)
    begin
      // Do nothing
    end);
  
  FEventBus.Subscribe<TTestEvent>(
    procedure(const Event: TTestEvent)
    begin
      // Do nothing
    end);
  
  var TestEvent: TTestEvent;
  FEventBus.Publish<TTestEvent>(TestEvent);
  
  Assert.AreEqual(InitialCount + 2, FEventBus.Stats.TotalDelivered);
end;

procedure TTestUniBaseEventBus.Test_Stats_TotalFiltered;
var
  InitialCount: Int64;
begin
  InitialCount := FEventBus.Stats.TotalFiltered;
  
  FEventBus.Subscribe<TOrderEvent>(
    procedure(const Event: TOrderEvent)
    begin
    end,
    function(const Event: TOrderEvent): Boolean
    begin
      Result := Event.Amount > 100;
    end);
  
  var SmallOrder: TOrderEvent;
  SmallOrder.Amount := 50;
  FEventBus.Publish<TOrderEvent>(SmallOrder);  // Should be filtered
  
  Assert.AreEqual(InitialCount + 1, FEventBus.Stats.TotalFiltered);
end;

procedure TTestUniBaseEventBus.Test_Stats_ActiveSubscriptions;
var
  Sub1, Sub2: ISubscription;
begin
  Assert.AreEqual(0, FEventBus.Stats.ActiveSubscriptions);
  
  Sub1 := FEventBus.Subscribe<TTestEvent>(
    procedure(const Event: TTestEvent)
    begin
    end);
  
  Assert.AreEqual(1, FEventBus.Stats.ActiveSubscriptions);
  
  Sub2 := FEventBus.Subscribe<TTestEvent>(
    procedure(const Event: TTestEvent)
    begin
    end);
  
  Assert.AreEqual(2, FEventBus.Stats.ActiveSubscriptions);
  
  Sub1.Unsubscribe;
  Assert.AreEqual(1, FEventBus.Stats.ActiveSubscriptions);
end;

procedure TTestUniBaseEventBus.Test_Stats_Reset;
begin
  FEventBus.Subscribe<TTestEvent>(
    procedure(const Event: TTestEvent)
    begin
    end);
  
  var TestEvent: TTestEvent;
  FEventBus.Publish<TTestEvent>(TestEvent);
  
  Assert.IsTrue(FEventBus.Stats.TotalPublished > 0);
  Assert.IsTrue(FEventBus.Stats.TotalDelivered > 0);
  
  FEventBus.ResetStats;
  
  Assert.AreEqual(Int64(0), FEventBus.Stats.TotalPublished);
  Assert.AreEqual(Int64(0), FEventBus.Stats.TotalDelivered);
end;

procedure TTestUniBaseEventBus.Test_HasSubscribers_True;
begin
  FEventBus.Subscribe<TTestEvent>(
    procedure(const Event: TTestEvent)
    begin
    end);
  
  Assert.IsTrue(FEventBus.HasSubscribers<TTestEvent>);
end;

procedure TTestUniBaseEventBus.Test_HasSubscribers_False;
begin
  Assert.IsFalse(FEventBus.HasSubscribers<TTestEvent>);
end;

procedure TTestUniBaseEventBus.Test_GetSubscriberCount;
begin
  Assert.AreEqual(0, FEventBus.GetSubscriberCount<TTestEvent>);
  
  FEventBus.Subscribe<TTestEvent>(
    procedure(const Event: TTestEvent)
    begin
    end);
  
  FEventBus.Subscribe<TTestEvent>(
    procedure(const Event: TTestEvent)
    begin
    end);
  
  Assert.AreEqual(2, FEventBus.GetSubscriberCount<TTestEvent>);
end;

procedure TTestUniBaseEventBus.Test_GetEventTypes;
var
  Types: TArray<string>;
begin
  FEventBus.Subscribe<TTestEvent>(
    procedure(const Event: TTestEvent)
    begin
    end);
  
  FEventBus.Subscribe<TUserLoginEvent>(
    procedure(const Event: TUserLoginEvent)
    begin
    end);
  
  Types := FEventBus.GetEventTypes;
  
  Assert.AreEqual(2, Length(Types));
end;

procedure TTestUniBaseEventBus.Test_KeepHistory_StoresEvents;
begin
  FEventBus.KeepHistory := True;
  FEventBus.MaxHistorySize := 10;
  
  var Event1: TTestEvent;
  Event1.Id := 1;
  FEventBus.Publish<TTestEvent>(Event1);
  
  var Event2: TTestEvent;
  Event2.Id := 2;
  FEventBus.Publish<TTestEvent>(Event2);
  
  // History is internal, we verify through ReplayHistory
  var ReceivedIds: string;
  ReceivedIds := '';
  
  FEventBus.ReplayHistory<TTestEvent>(
    procedure(const Event: TTestEvent)
    begin
      ReceivedIds := ReceivedIds + IntToStr(Event.Id);
    end);
  
  Assert.AreEqual('12', ReceivedIds);
end;

procedure TTestUniBaseEventBus.Test_ReplayHistory_DeliversPastEvents;
var
  Count: Integer;
begin
  Count := 0;
  FEventBus.KeepHistory := True;
  
  var TestEvent: TTestEvent;
  TestEvent.Id := 1;
  FEventBus.Publish<TTestEvent>(TestEvent);
  FEventBus.Publish<TTestEvent>(TestEvent);
  FEventBus.Publish<TTestEvent>(TestEvent);
  
  FEventBus.ReplayHistory<TTestEvent>(
    procedure(const Event: TTestEvent)
    begin
      Inc(Count);
    end);
  
  Assert.AreEqual(3, Count);
end;

procedure TTestUniBaseEventBus.Test_ClearHistory;
var
  Count: Integer;
begin
  Count := 0;
  FEventBus.KeepHistory := True;
  
  var TestEvent: TTestEvent;
  FEventBus.Publish<TTestEvent>(TestEvent);
  FEventBus.Publish<TTestEvent>(TestEvent);
  
  FEventBus.ClearHistory;
  
  FEventBus.ReplayHistory<TTestEvent>(
    procedure(const Event: TTestEvent)
    begin
      Inc(Count);
    end);
  
  Assert.AreEqual(0, Count);
end;

procedure TTestUniBaseEventBus.Test_MaxHistorySize_LimitsStorage;
var
  Count: Integer;
begin
  Count := 0;
  FEventBus.KeepHistory := True;
  FEventBus.MaxHistorySize := 3;
  
  // Publish 5 events
  var TestEvent: TTestEvent;
  for var I := 1 to 5 do
  begin
    TestEvent.Id := I;
    FEventBus.Publish<TTestEvent>(TestEvent);
  end;
  
  FEventBus.ReplayHistory<TTestEvent>(
    procedure(const Event: TTestEvent)
    begin
      Inc(Count);
    end);
  
  Assert.IsTrue(Count <= 3, 'History should be limited to MaxHistorySize');
end;

procedure TTestUniBaseEventBus.Test_Disabled_NoEventsDelivered;
var
  Received: Boolean;
begin
  Received := False;
  
  FEventBus.Subscribe<TTestEvent>(
    procedure(const Event: TTestEvent)
    begin
      Received := True;
    end);
  
  FEventBus.Enabled := False;
  
  var TestEvent: TTestEvent;
  FEventBus.Publish<TTestEvent>(TestEvent);
  
  Assert.IsFalse(Received, 'Events should not be delivered when disabled');
end;

procedure TTestUniBaseEventBus.Test_ReEnabled_EventsDelivered;
var
  Received: Boolean;
begin
  Received := False;
  
  FEventBus.Subscribe<TTestEvent>(
    procedure(const Event: TTestEvent)
    begin
      Received := True;
    end);
  
  FEventBus.Enabled := False;
  FEventBus.Enabled := True;
  
  var TestEvent: TTestEvent;
  FEventBus.Publish<TTestEvent>(TestEvent);
  
  Assert.IsTrue(Received, 'Events should be delivered when re-enabled');
end;

procedure TTestUniBaseEventBus.Test_OnError_CalledOnException;
var
  ErrorCalled: Boolean;
  ErrorMessage: string;
begin
  ErrorCalled := False;
  
  FEventBus.OnError := procedure(const EventType: string;
    const Event: TValue; const Error: Exception)
  begin
    ErrorCalled := True;
    ErrorMessage := Error.Message;
  end;
  
  FEventBus.Subscribe<TTestEvent>(
    procedure(const Event: TTestEvent)
    begin
      raise Exception.Create('Test exception');
    end);
  
  var TestEvent: TTestEvent;
  FEventBus.Publish<TTestEvent>(TestEvent);
  
  Assert.IsTrue(ErrorCalled, 'OnError should be called');
  Assert.AreEqual('Test exception', ErrorMessage);
end;

procedure TTestUniBaseEventBus.Test_DeadLetter_CalledWhenNoSubscribers;
var
  DeadLetterCalled: Boolean;
  DeadLetterType: string;
begin
  DeadLetterCalled := False;
  
  FEventBus.OnDeadLetter := procedure(const EventType: string;
    const Event: TValue; const Reason: string)
  begin
    DeadLetterCalled := True;
    DeadLetterType := EventType;
  end;
  
  var TestEvent: TTestEvent;
  FEventBus.Publish<TTestEvent>(TestEvent);
  
  Assert.IsTrue(DeadLetterCalled, 'OnDeadLetter should be called when no subscribers');
end;

procedure TTestUniBaseEventBus.Test_Clear_RemovesAllSubscriptions;
begin
  FEventBus.Subscribe<TTestEvent>(
    procedure(const Event: TTestEvent)
    begin
    end);
  
  FEventBus.Subscribe<TUserLoginEvent>(
    procedure(const Event: TUserLoginEvent)
    begin
    end);
  
  Assert.IsTrue(FEventBus.Stats.ActiveSubscriptions > 0);
  
  FEventBus.Clear;
  
  Assert.AreEqual(0, FEventBus.Stats.ActiveSubscriptions);
  Assert.IsFalse(FEventBus.HasSubscribers<TTestEvent>);
  Assert.IsFalse(FEventBus.HasSubscribers<TUserLoginEvent>);
end;

procedure TTestUniBaseEventBus.Test_ThreadSafety_ConcurrentPublish;
var
  Tasks: TArray<ITask>;
  ReceivedCount: Integer;
  Lock: TCriticalSection;
const
  THREAD_COUNT = 10;
  EVENTS_PER_THREAD = 100;
begin
  ReceivedCount := 0;
  Lock := TCriticalSection.Create;
  try
    FEventBus.Subscribe<TTestEvent>(
      procedure(const Event: TTestEvent)
      begin
        Lock.Enter;
        try
          Inc(ReceivedCount);
        finally
          Lock.Leave;
        end;
      end);
    
    SetLength(Tasks, THREAD_COUNT);
    
    for var I := 0 to THREAD_COUNT - 1 do
    begin
      Tasks[I] := TTask.Run(
        procedure
        var
          J: Integer;
          TestEvent: TTestEvent;
        begin
          for J := 1 to EVENTS_PER_THREAD do
          begin
            TestEvent.Id := J;
            FEventBus.Publish<TTestEvent>(TestEvent);
          end;
        end);
    end;
    
    TTask.WaitForAll(Tasks);
    
    Assert.AreEqual(THREAD_COUNT * EVENTS_PER_THREAD, ReceivedCount);
  finally
    Lock.Free;
  end;
end;

procedure TTestUniBaseEventBus.Test_ThreadSafety_ConcurrentSubscribeUnsubscribe;
var
  Tasks: TArray<ITask>;
  ErrorCount: Integer;
  Lock: TCriticalSection;
const
  THREAD_COUNT = 10;
  ITERATIONS = 50;
begin
  ErrorCount := 0;
  Lock := TCriticalSection.Create;
  try
    SetLength(Tasks, THREAD_COUNT);
    
    for var I := 0 to THREAD_COUNT - 1 do
    begin
      Tasks[I] := TTask.Run(
        procedure
        var
          J: Integer;
          Sub: ISubscription;
        begin
          for J := 1 to ITERATIONS do
          begin
            try
              Sub := FEventBus.Subscribe<TTestEvent>(
                procedure(const Event: TTestEvent)
                begin
                end);
              
              var TestEvent: TTestEvent;
              TestEvent.Id := J;
              FEventBus.Publish<TTestEvent>(TestEvent);
              
              Sub.Unsubscribe;
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
    
    Assert.AreEqual(0, ErrorCount, 'No errors during concurrent operations');
  finally
    Lock.Free;
  end;
end;

procedure TTestUniBaseEventBus.Test_Subscription_IsActive;
var
  Sub: ISubscription;
begin
  Sub := FEventBus.Subscribe<TTestEvent>(
    procedure(const Event: TTestEvent)
    begin
    end);
  
  Assert.IsTrue(Sub.IsActive);
  
  Sub.Unsubscribe;
  
  Assert.IsFalse(Sub.IsActive);
end;

procedure TTestUniBaseEventBus.Test_Subscription_GetEventType;
var
  Sub: ISubscription;
begin
  Sub := FEventBus.Subscribe<TTestEvent>(
    procedure(const Event: TTestEvent)
    begin
    end);
  
  Assert.AreEqual('TTestEvent', Sub.GetEventType);
end;

{ TTestEventBusStats }

procedure TTestEventBusStats.Test_Reset_ClearsAllCounters;
var
  Stats: TEventBusStats;
begin
  Stats.TotalPublished := 100;
  Stats.TotalDelivered := 80;
  Stats.TotalFiltered := 20;
  Stats.TotalErrors := 5;
  
  Stats.Reset;
  
  Assert.AreEqual(Int64(0), Stats.TotalPublished);
  Assert.AreEqual(Int64(0), Stats.TotalDelivered);
  Assert.AreEqual(Int64(0), Stats.TotalFiltered);
  Assert.AreEqual(Int64(0), Stats.TotalErrors);
end;

procedure TTestEventBusStats.Test_ToString_FormatsCorrectly;
var
  Stats: TEventBusStats;
  S: string;
begin
  Stats.Reset;
  Stats.TotalPublished := 100;
  Stats.TotalDelivered := 80;
  Stats.ActiveSubscriptions := 5;
  
  S := Stats.ToString;
  
  Assert.IsTrue(S.Contains('100'), 'Should contain published count');
  Assert.IsTrue(S.Contains('80'), 'Should contain delivered count');
  Assert.IsTrue(S.Contains('5'), 'Should contain subscription count');
end;

{ TTestGlobalEventBus }

procedure TTestGlobalEventBus.Test_EventBus_ReturnsSingleton;
var
  Bus1, Bus2: TEventBus;
begin
  Bus1 := EventBus;
  Bus2 := EventBus;
  
  Assert.AreSame(Bus1, Bus2, 'Should return same instance');
end;

procedure TTestGlobalEventBus.Test_SetEventBus_ReplacesInstance;
var
  CustomBus: TEventBus;
  Retrieved: TEventBus;
begin
  CustomBus := TEventBus.Create;
  try
    SetEventBus(CustomBus);
    Retrieved := EventBus;
    
    Assert.AreSame(CustomBus, Retrieved, 'Should return custom instance');
  finally
    // SetEventBus takes ownership, so don't free manually
  end;
  
  // Reset to default
  SetEventBus(nil);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestUniBaseEventBus);
  TDUnitX.RegisterTestFixture(TTestEventBusStats);
  TDUnitX.RegisterTestFixture(TTestGlobalEventBus);

end.
