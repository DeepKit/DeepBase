unit Test.DeepBase.Browser.Events;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DeepBase.Browser.Types,
  DeepBase.Browser.Events,
  DeepBase.EventBus;

type
  [TestFixture]
  TBrowserEventsTests = class
  public
    [Test]
    procedure Test_PublishAndSubscribe;

    [Test]
    procedure Test_PublishByEventType;

    [Test]
    procedure Test_SubscribeWithFilter;

    [Test]
    procedure Test_UnsubscribeAll;

    [Test]
    procedure Test_Publish_ConvenienceOverload;
  end;

implementation

var
  GReceivedEvents: TArray<TBrowserEvent>;
  GEventLock: TObject;

procedure ResetReceivedEvents;
begin
  GReceivedEvents := nil;
end;

procedure RecordEvent(const AEvent: TBrowserEvent);
begin
  TMonitor.Enter(GEventLock);
  try
    SetLength(GReceivedEvents, Length(GReceivedEvents) + 1);
    GReceivedEvents[High(GReceivedEvents)] := AEvent;
  finally
    TMonitor.Exit(GEventLock);
  end;
end;

{ TBrowserEventsTests }

procedure TBrowserEventsTests.Test_PublishAndSubscribe;
var
  LSub: ISubscription;
begin
  ResetReceivedEvents;
  LSub := TBrowserEvents.Subscribe(
    TEventHandler<TBrowserEvent>(
    procedure(const AEvent: TBrowserEvent)
    begin
      RecordEvent(AEvent);
    end));
  try
    TBrowserEvents.Publish(
      TBrowserEvent.Create(betNavigationCompleted,
        'sess-1', '{"url":"https://example.com"}'));

    Assert.AreEqual<Integer>(1, Length(GReceivedEvents));
    Assert.AreEqual(betNavigationCompleted,
      GReceivedEvents[0].EventType);
    Assert.AreEqual('sess-1', GReceivedEvents[0].SessionId);
  finally
    TBrowserEvents.UnsubscribeAll;
  end;
end;

procedure TBrowserEventsTests.Test_PublishByEventType;
var
  LSub: ISubscription;
begin
  ResetReceivedEvents;
  LSub := TBrowserEvents.SubscribeByType(betCrashed,
    TEventHandler<TBrowserEvent>(
    procedure(const AEvent: TBrowserEvent)
    begin
      RecordEvent(AEvent);
    end));
  try
    TBrowserEvents.Publish(betNavigationCompleted,
      'sess-1', '');
    TBrowserEvents.Publish(betCrashed, 'sess-2', 'OOM');

    Assert.AreEqual<Integer>(1, Length(GReceivedEvents));
    Assert.AreEqual(betCrashed, GReceivedEvents[0].EventType);
    Assert.AreEqual('sess-2', GReceivedEvents[0].SessionId);
  finally
    TBrowserEvents.UnsubscribeAll;
  end;
end;

procedure TBrowserEventsTests.Test_SubscribeWithFilter;
var
  LSub: ISubscription;
begin
  ResetReceivedEvents;
  LSub := TBrowserEvents.Subscribe(
    TEventHandler<TBrowserEvent>(
    procedure(const AEvent: TBrowserEvent)
    begin
      RecordEvent(AEvent);
    end),
    TEventFilter<TBrowserEvent>(
    function(const AEvent: TBrowserEvent): Boolean
    begin
      Result := AEvent.SessionId = 'target';
    end));
  try
    TBrowserEvents.Publish(betScriptExecuted, 'other', '');
    TBrowserEvents.Publish(betScriptExecuted, 'target', 'ok');
    TBrowserEvents.Publish(betScriptFailed, 'target', 'err');

    Assert.AreEqual<Integer>(2, Length(GReceivedEvents));
  finally
    TBrowserEvents.UnsubscribeAll;
  end;
end;

procedure TBrowserEventsTests.Test_UnsubscribeAll;
var
  LSub: ISubscription;
begin
  ResetReceivedEvents;
  LSub := TBrowserEvents.Subscribe(
    TEventHandler<TBrowserEvent>(
    procedure(const AEvent: TBrowserEvent)
    begin
      RecordEvent(AEvent);
    end));

  TBrowserEvents.UnsubscribeAll;
  TBrowserEvents.Publish(betCrashed, 'sess-1', '');

  Assert.AreEqual<Integer>(0, Length(GReceivedEvents));
end;

procedure TBrowserEventsTests.Test_Publish_ConvenienceOverload;
var
  LSub: ISubscription;
begin
  ResetReceivedEvents;
  LSub := TBrowserEvents.Subscribe(
    TEventHandler<TBrowserEvent>(
    procedure(const AEvent: TBrowserEvent)
    begin
      RecordEvent(AEvent);
    end));
  try
    TBrowserEvents.Publish(betResponseReceived,
      'sess-x', '{"text":"hello"}');

    Assert.AreEqual<Integer>(1, Length(GReceivedEvents));
    Assert.AreEqual('{"text":"hello"}',
      GReceivedEvents[0].Data);
  finally
    TBrowserEvents.UnsubscribeAll;
  end;
end;

initialization
  GEventLock := TObject.Create;
  TDUnitX.RegisterTestFixture(TBrowserEventsTests);

finalization
  FreeAndNil(GEventLock);

end.
