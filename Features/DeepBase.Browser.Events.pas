{ ============================================================================
  DeepBase.Browser.Events
  ---------------------------------------------------------------------------
  Version     : 1.0
  Description : Thin integration layer between browser events and
                DeepBase.EventBus. Provides typed publish/subscribe helpers
                for TBrowserEvent records.
  ============================================================================ }

unit DeepBase.Browser.Events;

interface

uses
  System.SysUtils,
  DeepBase.EventBus,
  DeepBase.Browser.Types;

type
  TBrowserEvents = class
  public
    class procedure Publish(const AEvent: TBrowserEvent); overload;
    class procedure Publish(AEventType: TBrowserEventType;
      const ASessionId: TBrowserSessionId;
      const AData: string = ''); overload;

    class function Subscribe(
      AHandler: TEventHandler<TBrowserEvent>): ISubscription; overload;
    class function Subscribe(
      AHandler: TEventHandler<TBrowserEvent>;
      APriority: TEventPriority;
      ADispatchMode: TEventDispatchMode = edmSync): ISubscription; overload;
    class function Subscribe(
      AHandler: TEventHandler<TBrowserEvent>;
      AFilter: TEventFilter<TBrowserEvent>): ISubscription; overload;

    class function SubscribeByType(
      AEventType: TBrowserEventType;
      AHandler: TEventHandler<TBrowserEvent>): ISubscription;

    class procedure UnsubscribeAll;
  end;

implementation

{ TBrowserEvents }

class procedure TBrowserEvents.Publish(
  const AEvent: TBrowserEvent);
begin
  EventBus.Publish<TBrowserEvent>(AEvent);
end;

class procedure TBrowserEvents.Publish(AEventType: TBrowserEventType;
  const ASessionId: TBrowserSessionId; const AData: string);
begin
  Publish(TBrowserEvent.Create(AEventType, ASessionId, AData));
end;

class function TBrowserEvents.Subscribe(
  AHandler: TEventHandler<TBrowserEvent>): ISubscription;
begin
  Result := EventBus.Subscribe<TBrowserEvent>(AHandler);
end;

class function TBrowserEvents.Subscribe(
  AHandler: TEventHandler<TBrowserEvent>;
  APriority: TEventPriority;
  ADispatchMode: TEventDispatchMode): ISubscription;
begin
  Result := EventBus.Subscribe<TBrowserEvent>(
    AHandler, APriority, ADispatchMode);
end;

class function TBrowserEvents.Subscribe(
  AHandler: TEventHandler<TBrowserEvent>;
  AFilter: TEventFilter<TBrowserEvent>): ISubscription;
begin
  Result := EventBus.Subscribe<TBrowserEvent>(AHandler, AFilter);
end;

class function TBrowserEvents.SubscribeByType(
  AEventType: TBrowserEventType;
  AHandler: TEventHandler<TBrowserEvent>): ISubscription;
var
  LTypeName: string;
begin
  LTypeName := BrowserEventTypeToString(AEventType);
  Result := EventBus.Subscribe<TBrowserEvent>(
    AHandler,
    function(const AEvent: TBrowserEvent): Boolean
    begin
      Result := AEvent.EventType = AEventType;
    end);
end;

class procedure TBrowserEvents.UnsubscribeAll;
begin
  EventBus.UnsubscribeAll<TBrowserEvent>;
end;

end.
