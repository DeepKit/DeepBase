{ ============================================================================
  DeepBase.EventBus - Publish-Subscribe Event Bus
  
  A flexible event bus implementation for decoupled component communication.
  
  Features:
  - Type-safe event publishing and subscribing
  - Synchronous and asynchronous event dispatch
  - Event filtering and prioritization
  - Weak reference support (auto-unsubscribe on object destruction)
  - Thread-safe operations
  - Event hiDeepStory and replay
  - Dead letter handling for unhandled events
  
  Usage:
    // Define event
    type
      TUserLoginEvent = record
        UserId: Integer;
        Username: string;
        Timestamp: TDateTime;
      end;
    
    // Subscribe
    EventBus.Subscribe<TUserLoginEvent>(
      procedure(const Event: TUserLoginEvent)
      begin
        ShowMessage('User logged in: ' + Event.Username);
      end);
    
    // Publish
    var LoginEvent: TUserLoginEvent;
    LoginEvent.UserId := 123;
    LoginEvent.Username := 'john';
    LoginEvent.Timestamp := Now;
    EventBus.Publish<TUserLoginEvent>(LoginEvent);
  ============================================================================ }

unit DeepBase.EventBus;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Rtti,
  System.TypInfo,
  System.Math,
  System.SyncObjs,
  System.Threading;

type
  // ============================================================================
  // Event Handler Types
  // ============================================================================
  
  TEventPriority = (epLow, epNormal, epHigh, epCritical);
  TEventDispatchMode = (edmSync, edmAsync, edmMainThread);
  
  /// <summary>Generic event handler</summary>
  TEventHandler<T> = reference to procedure(const Event: T);
  
  /// <summary>Untyped event handler (for internal use)</summary>
  TUntypedEventHandler = reference to procedure(const Event: TValue);

  /// <summary>Untyped event filter (for internal use)</summary>
  TUntypedEventFilter = reference to function(const Event: TValue): Boolean;
  
  /// <summary>Event filter predicate</summary>
  TEventFilter<T> = reference to function(const Event: T): Boolean;
  
  // ============================================================================
  // Subscription Token
  // ============================================================================
  
  /// <summary>
  /// Subscription handle for unsubscribing
  /// </summary>
  ISubscription = interface
    ['{A7D3B2C1-5E4F-4A3B-8C7D-9E0F1A2B3C4D}']
    procedure Unsubscribe;
    function IsActive: Boolean;
    function GetEventType: string;
  end;
  
  TSubscription = class(TInterfacedObject, ISubscription)
  private
    FEventBus: TObject;
    FEventType: string;
    FSubscriptionId: TGUID;
    FActive: Boolean;
  public
    constructor Create(AEventBus: TObject; const AEventType: string;
      const ASubscriptionId: TGUID);
    destructor Destroy; override;
    procedure Unsubscribe;
    function IsActive: Boolean;
    function GetEventType: string;
    /// <summary>Internal: called by EventBus on destruction to invalidate
    /// the subscription token so later Unsubscribe calls become no-ops.</summary>
    procedure InvalidateBus;
    property SubscriptionId: TGUID read FSubscriptionId;
  end;

  TEventBus = class;

  /// <summary>
  /// Owner-bound helper component for weak subscriptions.
  /// When owner is destroyed, this link auto-unsubscribes the subscription.
  /// </summary>
  TWeakSubscriptionLink = class(TComponent)
  private
    FEventBus: TEventBus;
    FSubscriptionId: TGUID;
  public
    constructor Create(AOwner: TComponent; AEventBus: TEventBus;
      const ASubscriptionId: TGUID); reintroduce;
    destructor Destroy; override;
    procedure DetachEventBus;
    property SubscriptionId: TGUID read FSubscriptionId;
  end;
  
  // ============================================================================
  // Subscription Info
  // ============================================================================
  
  TSubscriptionInfo = record
    Id: TGUID;
    Handler: TUntypedEventHandler;
    Priority: TEventPriority;
    DispatchMode: TEventDispatchMode;
    Filter: TUntypedEventFilter;
    Tag: string;
    CreatedAt: TDateTime;
    InvokeCount: Int64;
  end;
  
  // ============================================================================
  // Event Bus Statistics
  // ============================================================================
  
  TEventBusStats = record
    TotalPublished: Int64;
    TotalDelivered: Int64;
    TotalFiltered: Int64;
    TotalErrors: Int64;
    ActiveSubscriptions: Integer;
    
    procedure Reset;
    function ToString: string;
  end;
  
  // ============================================================================
  // Event Bus
  // ============================================================================
  
  TDeadLetterHandler = reference to procedure(const EventType: string;
    const Event: TValue; const Reason: string);
  TErrorHandler = reference to procedure(const EventType: string;
    const Event: TValue; const Error: Exception);
  
  /// <summary>
  /// Main event bus class
  /// </summary>
  TEventBus = class
  private
    FSubscriptions: TDictionary<string, TList<TSubscriptionInfo>>;
    FOwnerLinks: TList<TWeakSubscriptionLink>;
    FLock: TCriticalSection;
    FStats: TEventBusStats;
    FOnDeadLetter: TDeadLetterHandler;
    FOnError: TErrorHandler;
    FEnabled: Boolean;
    FEventHistory: TList<TPair<string, TValue>>;
    FMaxHistorySize: Integer;
    FKeepHistory: Boolean;
    FAsyncCount: Integer;
    FAsyncDrained: TEvent;
    // BASIC-023: track live TSubscription instances to invalidate them
    // when EventBus is destroyed, preventing dangling-pointer Unsubscribe.
    FLiveSubscriptions: TList<TObject>;

    procedure RegisterLiveSubscription(ASub: TObject);
    procedure UnregisterLiveSubscription(ASub: TObject);
    procedure InvalidateAllLiveSubscriptions;

    function GetEventTypeName<T>: string;
    function GetSubscriptionList(const EventType: string): TList<TSubscriptionInfo>;
    function SubscribeInternal<T>(Handler: TEventHandler<T>;
      Priority: TEventPriority;
      DispatchMode: TEventDispatchMode;
      Filter: TEventFilter<T>;
      const Tag: string;
      out SubscriptionId: TGUID): ISubscription;
    procedure RegisterWeakSubscriptionLink(AOwner: TComponent;
      const SubscriptionId: TGUID);
    procedure RemoveWeakSubscriptionLink(const SubscriptionId: TGUID);
    procedure OwnerLinkDestroyed(ALink: TWeakSubscriptionLink;
      const SubscriptionId: TGUID);
    procedure DetachWeakSubscriptionLinks;
    procedure TrackAsyncBegin;
    procedure TrackAsyncEnd;
    procedure InvokeHandler(const Info: TSubscriptionInfo; const Event: TValue);
    procedure AddToHistory(const EventType: string; const Event: TValue);
  public
    constructor Create;
    destructor Destroy; override;
    
    // ========================================================================
    // Subscribe
    // ========================================================================
    
    /// <summary>
    /// Subscribe to events of type T.
    /// Note: this is a strong subscription; caller must Unsubscribe explicitly.
    /// </summary>
    function Subscribe<T>(Handler: TEventHandler<T>): ISubscription; overload;
    
    /// <summary>Subscribe with options</summary>
    function Subscribe<T>(Handler: TEventHandler<T>;
      Priority: TEventPriority;
      DispatchMode: TEventDispatchMode = edmSync): ISubscription; overload;
    
    /// <summary>Subscribe with filter</summary>
    function Subscribe<T>(Handler: TEventHandler<T>;
      Filter: TEventFilter<T>): ISubscription; overload;
    
    /// <summary>Subscribe with all options</summary>
    function Subscribe<T>(Handler: TEventHandler<T>;
      Priority: TEventPriority;
      DispatchMode: TEventDispatchMode;
      Filter: TEventFilter<T>;
      const Tag: string = ''): ISubscription; overload;

    /// <summary>
    /// Weak subscription bound to component lifecycle.
    /// Owner destruction triggers automatic Unsubscribe.
    /// </summary>
    function SubscribeWeak<T>(AOwner: TComponent;
      Handler: TEventHandler<T>): ISubscription; overload;
    function SubscribeWeak<T>(AOwner: TComponent;
      Handler: TEventHandler<T>;
      Priority: TEventPriority;
      DispatchMode: TEventDispatchMode = edmSync): ISubscription; overload;
    function SubscribeWeak<T>(AOwner: TComponent;
      Handler: TEventHandler<T>;
      Priority: TEventPriority;
      DispatchMode: TEventDispatchMode;
      Filter: TEventFilter<T>;
      const Tag: string = ''): ISubscription; overload;
    
    /// <summary>Subscribe using RTTI (for dynamic event types)</summary>
    function SubscribeByType(const EventType: string;
      Handler: TUntypedEventHandler;
      Priority: TEventPriority = epNormal;
      DispatchMode: TEventDispatchMode = edmSync): ISubscription;
      
    /// <summary>Validate event type for security</summary>
    class function IsValidEventType(const EventType: string): Boolean; static;
    
    // ========================================================================
    // Unsubscribe
    // ========================================================================
    
    /// <summary>Unsubscribe by subscription ID</summary>
    procedure Unsubscribe(const SubscriptionId: TGUID);
    
    /// <summary>Unsubscribe all handlers for event type</summary>
    procedure UnsubscribeAll<T>; overload;
    procedure UnsubscribeAll(const EventType: string); overload;
    
    /// <summary>Unsubscribe by tag</summary>
    procedure UnsubscribeByTag(const Tag: string);
    
    // ========================================================================
    // Publish
    // ========================================================================
    
    /// <summary>Publish event synchronously</summary>
    procedure Publish<T>(const Event: T); overload;
    
    /// <summary>Publish event with specified dispatch mode</summary>
    procedure Publish<T>(const Event: T; DispatchMode: TEventDispatchMode); overload;
    
    /// <summary>Publish event asynchronously</summary>
    function PublishAsync<T>(const Event: T): ITask;
    
    /// <summary>Publish using RTTI</summary>
    procedure PublishByType(const EventType: string; const Event: TValue);
    
    // ========================================================================
    // Query
    // ========================================================================
    
    /// <summary>Check if there are subscribers for event type</summary>
    function HasSubscribers<T>: Boolean; overload;
    function HasSubscribers(const EventType: string): Boolean; overload;
    
    /// <summary>Get subscriber count for event type</summary>
    function GetSubscriberCount<T>: Integer; overload;
    function GetSubscriberCount(const EventType: string): Integer; overload;
    
    /// <summary>Get all registered event types</summary>
    function GetEventTypes: TArray<string>;
    
    // ========================================================================
    // History
    // ========================================================================
    
    /// <summary>Replay last N events of type T to new subscriber</summary>
    procedure ReplayHistory<T>(Handler: TEventHandler<T>; Count: Integer = -1);
    
    /// <summary>Clear event hiDeepStory</summary>
    procedure ClearHistory;
    
    // ========================================================================
    // Utility
    // ========================================================================
    
    /// <summary>Clear all subscriptions</summary>
    procedure Clear;
    
    /// <summary>Reset statistics</summary>
    procedure ResetStats;

    /// <summary>Wait for currently queued asynchronous handlers to complete</summary>
    function WaitForAsyncHandlers(TimeoutMs: Cardinal = 5000): Boolean;
    
    // ========================================================================
    // Properties
    // ========================================================================
    
    property Enabled: Boolean read FEnabled write FEnabled;
    property Stats: TEventBusStats read FStats;
    property KeepHistory: Boolean read FKeepHistory write FKeepHistory;
    property MaxHistorySize: Integer read FMaxHistorySize write FMaxHistorySize;
    property OnDeadLetter: TDeadLetterHandler read FOnDeadLetter write FOnDeadLetter;
    property OnError: TErrorHandler read FOnError write FOnError;
  end;
  
  // ============================================================================
  // Global Event Bus
  // ============================================================================

/// <summary>Get global event bus instance</summary>
function EventBus: TEventBus;

/// <summary>
/// Set custom global event bus (for testing/dependency injection).
/// 
/// R-007: ����Ȩ����˵����
///   - ���ô˷�����AEventBus ������Ȩת�Ƹ�ȫ�ֵ���������
///   - ֮ǰ��ȫ��ʵ���������� auto-created ����֮ǰ����ģ����ᱻ�ͷ�
///   - ���� nil ������ΪĬ�ϵ���������Ϊ
///   - �����߲�Ӧ�ڵ��ú�������л��ͷ� AEventBus
/// </summary>
procedure SetEventBus(AEventBus: TEventBus);

implementation

var
  GEventBus: TEventBus = nil;
  GEventBusLock: TCriticalSection = nil;
  // BUG EXP-P1-010 FIX: set in finalization to prevent `EventBus()` from
  // lazily recreating GEventBus after the unit has torn down. Without this
  // guard, any post-finalization call to `EventBus` would instantiate a
  // fresh TEventBus that then leaks (no subsequent finalization will free it).
  GEventBusFinalized: Boolean = False;

function EventBus: TEventBus;
begin
  // BUG EXP-P1-010 FIX: once the unit has finalized, refuse to recreate the
  // singleton — a lazy create here would leak because no finalization will
  // free it again.
  if GEventBusFinalized then
    Exit(nil);
  if GEventBus = nil then
  begin
    var LNew := TEventBus.Create;
    if TInterlocked.CompareExchange(Pointer(GEventBus), Pointer(LNew), nil) <> nil then
      LNew.Free;  // Another thread created it first
  end;
  Result := GEventBus;
end;

procedure SetEventBus(AEventBus: TEventBus);
begin
  GEventBusLock.Enter;
  try
    // R-007: ����Ȩת���߼�
    // - ��������ʵ���뵱ǰʵ����ͬ���ͷž�ʵ��
    // - ���� nil ���ͷŵ�ǰʵ�����������������
    // - ����ͬһʵ�����޲��������� double-free��
    if GEventBus <> AEventBus then
    begin
      FreeAndNil(GEventBus);  // ��ȫ�ͷž�ʵ�������� nil �����
      GEventBus := AEventBus; // ����Ȩת�ƣ������߲�Ӧ���ͷ�
    end;
  finally
    GEventBusLock.Leave;
  end;
end;

// ============================================================================
// TEventBusStats
// ============================================================================

procedure TEventBusStats.Reset;
begin
  TotalPublished := 0;
  TotalDelivered := 0;
  TotalFiltered := 0;
  TotalErrors := 0;
end;

function TEventBusStats.ToString: string;
begin
  Result := Format('Published: %d, Delivered: %d, Filtered: %d, Errors: %d, Subscriptions: %d',
    [TotalPublished, TotalDelivered, TotalFiltered, TotalErrors, ActiveSubscriptions]);
end;

// ============================================================================
// TSubscription
// ============================================================================

constructor TSubscription.Create(AEventBus: TObject; const AEventType: string;
  const ASubscriptionId: TGUID);
begin
  inherited Create;
  FEventBus := AEventBus;
  FEventType := AEventType;
  FSubscriptionId := ASubscriptionId;
  FActive := True;
  if FEventBus <> nil then
    TEventBus(FEventBus).RegisterLiveSubscription(Self);
end;

destructor TSubscription.Destroy;
begin
  if FEventBus <> nil then
    TEventBus(FEventBus).UnregisterLiveSubscription(Self);
  inherited;
end;

procedure TSubscription.InvalidateBus;
begin
  // Called by EventBus.Destroy under FLock; safe to mutate without lock here.
  FEventBus := nil;
  FActive := False;
end;

procedure TSubscription.Unsubscribe;
begin
  if FActive and (FEventBus <> nil) then
  begin
    TEventBus(FEventBus).Unsubscribe(FSubscriptionId);
    FActive := False;
  end;
end;

function TSubscription.IsActive: Boolean;
begin
  Result := FActive;
end;

function TSubscription.GetEventType: string;
begin
  Result := FEventType;
end;

// ============================================================================
// TWeakSubscriptionLink
// ============================================================================

constructor TWeakSubscriptionLink.Create(AOwner: TComponent; AEventBus: TEventBus;
  const ASubscriptionId: TGUID);
begin
  inherited Create(AOwner);
  FEventBus := AEventBus;
  FSubscriptionId := ASubscriptionId;
end;

destructor TWeakSubscriptionLink.Destroy;
var
  LEventBus: TEventBus;
begin
  LEventBus := FEventBus;
  FEventBus := nil;
  if LEventBus <> nil then
    LEventBus.OwnerLinkDestroyed(Self, FSubscriptionId);
  inherited;
end;

procedure TWeakSubscriptionLink.DetachEventBus;
begin
  FEventBus := nil;
end;

// ============================================================================
// TEventBus
// ============================================================================

constructor TEventBus.Create;
begin
  inherited Create;
  FSubscriptions := TDictionary<string, TList<TSubscriptionInfo>>.Create;
  FOwnerLinks := TList<TWeakSubscriptionLink>.Create;
  FLiveSubscriptions := TList<TObject>.Create;
  FLock := TCriticalSection.Create;
  FEventHistory := TList<TPair<string, TValue>>.Create;
  FAsyncDrained := TEvent.Create(nil, True, True, '');
  FAsyncCount := 0;
  FEnabled := True;
  FKeepHistory := False;
  FMaxHistorySize := 100;
  FStats.Reset;
end;

destructor TEventBus.Destroy;
var
  List: TList<TSubscriptionInfo>;
begin
  WaitForAsyncHandlers(30000);

  FLock.Enter;
  try
    // BASIC-023: invalidate all live TSubscription tokens so external
    // ISubscription holders cannot dereference us after Destroy.
    InvalidateAllLiveSubscriptions;
    FreeAndNil(FLiveSubscriptions);

    DetachWeakSubscriptionLinks;
    FreeAndNil(FOwnerLinks);
    for List in FSubscriptions.Values do
      List.Free;
    FreeAndNil(FSubscriptions);
    FreeAndNil(FEventHistory);
    FreeAndNil(FAsyncDrained);
  finally
    FLock.Leave;
  end;
  FreeAndNil(FLock);
  inherited;
end;

function TEventBus.GetEventTypeName<T>: string;
begin
  Result := string(PTypeInfo(TypeInfo(T))^.Name);
end;

function TEventBus.GetSubscriptionList(const EventType: string): TList<TSubscriptionInfo>;
begin
  if not FSubscriptions.TryGetValue(EventType, Result) then
  begin
    Result := TList<TSubscriptionInfo>.Create;
    FSubscriptions.Add(EventType, Result);
  end;
end;

function TEventBus.SubscribeInternal<T>(Handler: TEventHandler<T>;
  Priority: TEventPriority;
  DispatchMode: TEventDispatchMode;
  Filter: TEventFilter<T>;
  const Tag: string;
  out SubscriptionId: TGUID): ISubscription;
var
  EventType: string;
  Info: TSubscriptionInfo;
  List: TList<TSubscriptionInfo>;
  I: Integer;
  TypedHandler: TEventHandler<T>;
  TypedFilter: TEventFilter<T>;
  WrappedFilter: TUntypedEventFilter;
begin
  EventType := GetEventTypeName<T>;
  TypedHandler := Handler;
  TypedFilter := Filter;

  SubscriptionId := TGUID.NewGuid;
  Info.Id := SubscriptionId;
  Info.Priority := Priority;
  Info.DispatchMode := DispatchMode;
  Info.Tag := Tag;
  Info.CreatedAt := Now;
  Info.InvokeCount := 0;

  // Wrap typed handler
  Info.Handler := procedure(const Event: TValue)
    begin
      TypedHandler(Event.AsType<T>);
    end;

  // BUG-043 FIX: Wrap typed filter to untyped filter
  if Assigned(TypedFilter) then
  begin
    WrappedFilter :=
      function(const Event: TValue): Boolean
      begin
        Result := TypedFilter(Event.AsType<T>);
      end;
    Info.Filter := WrappedFilter;
  end
  else
    Info.Filter := nil;

  FLock.Enter;
  try
    List := GetSubscriptionList(EventType);

    // Insert by priority (higher priority first)
    I := 0;
    while (I < List.Count) and (List[I].Priority >= Priority) do
      Inc(I);
    List.Insert(I, Info);

    Inc(FStats.ActiveSubscriptions);
  finally
    FLock.Leave;
  end;

  Result := TSubscription.Create(Self, EventType, SubscriptionId);
end;

function TEventBus.Subscribe<T>(Handler: TEventHandler<T>): ISubscription;
begin
  Result := Subscribe<T>(Handler, epNormal, edmSync, nil, '');
end;

function TEventBus.Subscribe<T>(Handler: TEventHandler<T>;
  Priority: TEventPriority;
  DispatchMode: TEventDispatchMode): ISubscription;
begin
  Result := Subscribe<T>(Handler, Priority, DispatchMode, nil, '');
end;

function TEventBus.Subscribe<T>(Handler: TEventHandler<T>;
  Filter: TEventFilter<T>): ISubscription;
begin
  Result := Subscribe<T>(Handler, epNormal, edmSync, Filter, '');
end;

function TEventBus.Subscribe<T>(Handler: TEventHandler<T>;
  Priority: TEventPriority;
  DispatchMode: TEventDispatchMode;
  Filter: TEventFilter<T>;
  const Tag: string): ISubscription;
var
  SubscriptionId: TGUID;
begin
  Result := SubscribeInternal<T>(Handler, Priority, DispatchMode, Filter, Tag,
    SubscriptionId);
end;

function TEventBus.SubscribeWeak<T>(AOwner: TComponent;
  Handler: TEventHandler<T>): ISubscription;
begin
  Result := SubscribeWeak<T>(AOwner, Handler, epNormal, edmSync, nil, '');
end;

function TEventBus.SubscribeWeak<T>(AOwner: TComponent;
  Handler: TEventHandler<T>;
  Priority: TEventPriority;
  DispatchMode: TEventDispatchMode): ISubscription;
begin
  Result := SubscribeWeak<T>(AOwner, Handler, Priority, DispatchMode, nil, '');
end;

function TEventBus.SubscribeWeak<T>(AOwner: TComponent;
  Handler: TEventHandler<T>;
  Priority: TEventPriority;
  DispatchMode: TEventDispatchMode;
  Filter: TEventFilter<T>;
  const Tag: string): ISubscription;
var
  SubscriptionId: TGUID;
begin
  if AOwner = nil then
    raise EArgumentNilException.Create('AOwner');

  Result := SubscribeInternal<T>(Handler, Priority, DispatchMode, Filter, Tag,
    SubscriptionId);
  RegisterWeakSubscriptionLink(AOwner, SubscriptionId);
end;

function TEventBus.SubscribeByType(const EventType: string;
  Handler: TUntypedEventHandler;
  Priority: TEventPriority;
  DispatchMode: TEventDispatchMode): ISubscription;
var
  Info: TSubscriptionInfo;
  List: TList<TSubscriptionInfo>;
  I: Integer;
begin
  // BUG EXP-P0-005 FIX: Use single shared validator. SubscribeByType delegates
  // to IsValidEventType (whitelist of T-prefixed event types + blacklist of
  // system+exec/cmd injection vectors). Subscribe<T>/Publish<T> rely on
  // compile-time type safety via RTTI/generics and intentionally bypass
  // string-based validation (BUG073 still guarded by IsValidEventType on
  // any string-based entry point).
  if not IsValidEventType(EventType) then
    raise EArgumentException.CreateFmt('Event type not allowed: %s', [EventType]);

  Info.Id := TGUID.NewGuid;
  Info.Handler := Handler;
  Info.Priority := Priority;
  Info.DispatchMode := DispatchMode;
  Info.Filter := nil;
  Info.Tag := '';
  Info.CreatedAt := Now;
  Info.InvokeCount := 0;
  
  FLock.Enter;
  try
    List := GetSubscriptionList(EventType);
    
    I := 0;
    while (I < List.Count) and (List[I].Priority >= Priority) do
      Inc(I);
    List.Insert(I, Info);
    
    Inc(FStats.ActiveSubscriptions);
  finally
    FLock.Leave;
  end;
  
  Result := TSubscription.Create(Self, EventType, Info.Id);
end;

procedure TEventBus.RegisterWeakSubscriptionLink(AOwner: TComponent;
  const SubscriptionId: TGUID);
var
  Link: TWeakSubscriptionLink;
begin
  Link := TWeakSubscriptionLink.Create(AOwner, Self, SubscriptionId);
  FLock.Enter;
  try
    FOwnerLinks.Add(Link);
  finally
    FLock.Leave;
  end;
end;

procedure TEventBus.RemoveWeakSubscriptionLink(const SubscriptionId: TGUID);
var
  I: Integer;
  Link: TWeakSubscriptionLink;
begin
  for I := FOwnerLinks.Count - 1 downto 0 do
  begin
    Link := FOwnerLinks[I];
    if Link.SubscriptionId = SubscriptionId then
    begin
      Link.DetachEventBus;
      FOwnerLinks.Delete(I);
      Break;
    end;
  end;
end;

procedure TEventBus.OwnerLinkDestroyed(ALink: TWeakSubscriptionLink;
  const SubscriptionId: TGUID);
begin
  if ALink = nil then
    Exit;

  FLock.Enter;
  try
    FOwnerLinks.Remove(ALink);
  finally
    FLock.Leave;
  end;

  Unsubscribe(SubscriptionId);
end;

procedure TEventBus.DetachWeakSubscriptionLinks;
var
  Link: TWeakSubscriptionLink;
begin
  for Link in FOwnerLinks do
    if Link <> nil then
      Link.DetachEventBus;
  FOwnerLinks.Clear;
end;

procedure TEventBus.RegisterLiveSubscription(ASub: TObject);
begin
  FLock.Enter;
  try
    if (FLiveSubscriptions <> nil) and (FLiveSubscriptions.IndexOf(ASub) < 0) then
      FLiveSubscriptions.Add(ASub);
  finally
    FLock.Leave;
  end;
end;

procedure TEventBus.UnregisterLiveSubscription(ASub: TObject);
begin
  // Tolerant: lock may be nil if EventBus.Destroy already cleared it
  // before TSubscription.Destroy ran (rare but possible during shutdown).
  if FLock = nil then
    Exit;
  FLock.Enter;
  try
    if FLiveSubscriptions <> nil then
      FLiveSubscriptions.Remove(ASub);
  finally
    FLock.Leave;
  end;
end;

procedure TEventBus.InvalidateAllLiveSubscriptions;
var
  Sub: TObject;
begin
  // Caller already holds FLock. Iterate over a copy because InvalidateBus
  // sets FEventBus := nil so the subscription will not call back.
  if FLiveSubscriptions = nil then
    Exit;
  for Sub in FLiveSubscriptions do
    if Sub <> nil then
      TSubscription(Sub).InvalidateBus;
  FLiveSubscriptions.Clear;
end;

procedure TEventBus.TrackAsyncBegin;
begin
  FLock.Enter;
  try
    Inc(FAsyncCount);
    if FAsyncCount = 1 then
      FAsyncDrained.ResetEvent;
  finally
    FLock.Leave;
  end;
end;

procedure TEventBus.TrackAsyncEnd;
begin
  FLock.Enter;
  try
    if FAsyncCount > 0 then
      Dec(FAsyncCount);
    if FAsyncCount = 0 then
      FAsyncDrained.SetEvent;
  finally
    FLock.Leave;
  end;
end;

procedure TEventBus.Unsubscribe(const SubscriptionId: TGUID);
var
  List: TList<TSubscriptionInfo>;
  I: Integer;
begin
  FLock.Enter;
  try
    for List in FSubscriptions.Values do
    begin
      for I := List.Count - 1 downto 0 do
      begin
        if List[I].Id = SubscriptionId then
        begin
          List.Delete(I);
          RemoveWeakSubscriptionLink(SubscriptionId);
          Dec(FStats.ActiveSubscriptions);
          Exit;
        end;
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TEventBus.UnsubscribeAll<T>;
begin
  UnsubscribeAll(GetEventTypeName<T>);
end;

procedure TEventBus.UnsubscribeAll(const EventType: string);
var
  List: TList<TSubscriptionInfo>;
  I: Integer;
begin
  FLock.Enter;
  try
    if FSubscriptions.TryGetValue(EventType, List) then
    begin
      for I := List.Count - 1 downto 0 do
        RemoveWeakSubscriptionLink(List[I].Id);
      Dec(FStats.ActiveSubscriptions, List.Count);
      List.Clear;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TEventBus.UnsubscribeByTag(const Tag: string);
var
  List: TList<TSubscriptionInfo>;
  I: Integer;
begin
  FLock.Enter;
  try
    for List in FSubscriptions.Values do
    begin
      for I := List.Count - 1 downto 0 do
      begin
        if List[I].Tag = Tag then
        begin
          RemoveWeakSubscriptionLink(List[I].Id);
          List.Delete(I);
          Dec(FStats.ActiveSubscriptions);
        end;
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TEventBus.InvokeHandler(const Info: TSubscriptionInfo; const Event: TValue);
var
  LHandler: TUntypedEventHandler;
  LEvent: TValue;
  QueueProc: TThreadProcedure;
begin
  LHandler := Info.Handler;
  LEvent := Event;
  
  case Info.DispatchMode of
    edmSync:
      LHandler(LEvent);
      
    edmAsync:
      begin
        TrackAsyncBegin;
        TThread.CreateAnonymousThread(
        procedure
        begin
          try
            LHandler(LEvent);
          finally
            TrackAsyncEnd;
          end;
        end).Start;
      end;
      
    edmMainThread:
      // Queue to main thread - using Queue for compatibility
      if TThread.CurrentThread.ThreadID = MainThreadID then
        LHandler(LEvent)
      else
      begin
        QueueProc := procedure
          begin
            LHandler(LEvent);
          end;
        TThread.Queue(nil, QueueProc);
      end;
  end;
end;

procedure TEventBus.AddToHistory(const EventType: string; const Event: TValue);
begin
  if not FKeepHistory then
    Exit;
  
  FEventHistory.Add(TPair<string, TValue>.Create(EventType, Event));
  
  // Trim hiDeepStory if too large
  while FEventHistory.Count > FMaxHistorySize do
    FEventHistory.Delete(0);
end;

procedure TEventBus.Publish<T>(const Event: T);
begin
  Publish<T>(Event, edmSync);
end;

procedure TEventBus.Publish<T>(const Event: T; DispatchMode: TEventDispatchMode);
var
  EventValue: TValue;
begin
  TValue.Make(@Event, TypeInfo(T), EventValue);
  PublishByType(GetEventTypeName<T>, EventValue);
end;

function TEventBus.PublishAsync<T>(const Event: T): ITask;
var
  EventCopy: T;
  LSelf: TEventBus;
  Thread: TThread;
begin
  // BUG-317 (INFRA-011): 统一线程模型 - PublishAsync 与 edmAsync 现在都使用
  // TThread.CreateAnonymousThread，避免 TTask.Run 线程池饱和时
  // TrackAsyncEnd 可能不执行导致 WaitForAsyncHandlers 永远挂起的问题。
  // 同时保留 FAsyncCount drain tracker 集成 (BASIC-021 修复)。
  EventCopy := Event;
  LSelf := Self;
  TrackAsyncBegin;
  Thread := TThread.CreateAnonymousThread(
    procedure
    begin
      try
        LSelf.Publish<T>(EventCopy);
      finally
        LSelf.TrackAsyncEnd;
      end;
    end);
  Thread.FreeOnTerminate := True;
  Thread.Start;
  // 返回 nil: 调用方通过 WaitForAsyncHandlers 等待异步排空，
  // 不再依赖 ITask.Wait。外部调用方已无依赖 (仅 docs 示例引用)。
  Result := nil;
end;

procedure TEventBus.PublishByType(const EventType: string; const Event: TValue);
var
  List: TList<TSubscriptionInfo>;
  Subscriptions: TArray<TSubscriptionInfo>;
  Info: TSubscriptionInfo;
  Delivered: Boolean;
begin
  if not FEnabled then
    Exit;
  
  // BASIC-022 fix: stats counters are read by Stats property without
  // holding FLock; use atomic increments so multi-threaded Publish does
  // not corrupt the running totals.
  TInterlocked.Increment(FStats.TotalPublished);
  Delivered := False;
  
  FLock.Enter;
  try
    if FSubscriptions.TryGetValue(EventType, List) then
      Subscriptions := List.ToArray
    else
      SetLength(Subscriptions, 0);
    
    AddToHistory(EventType, Event);
  finally
    FLock.Leave;
  end;
  
  // Invoke handlers outside lock
  for Info in Subscriptions do
  begin
    try
      // Check filter
      if Assigned(Info.Filter) then
      begin
        if not Info.Filter(Event) then
        begin
          TInterlocked.Increment(FStats.TotalFiltered);
          Continue;
        end;
      end;
      
      InvokeHandler(Info, Event);
      TInterlocked.Increment(FStats.TotalDelivered);
      Delivered := True;
      
    except
      on E: Exception do
      begin
        TInterlocked.Increment(FStats.TotalErrors);
        if Assigned(FOnError) then
          FOnError(EventType, Event, E);
      end;
    end;
  end;
  
  // Dead letter handling
  if not Delivered and Assigned(FOnDeadLetter) then
    FOnDeadLetter(EventType, Event, 'No subscribers');
end;

function TEventBus.HasSubscribers<T>: Boolean;
begin
  Result := HasSubscribers(GetEventTypeName<T>);
end;

function TEventBus.HasSubscribers(const EventType: string): Boolean;
var
  List: TList<TSubscriptionInfo>;
begin
  FLock.Enter;
  try
    Result := FSubscriptions.TryGetValue(EventType, List) and (List.Count > 0);
  finally
    FLock.Leave;
  end;
end;

function TEventBus.GetSubscriberCount<T>: Integer;
begin
  Result := GetSubscriberCount(GetEventTypeName<T>);
end;

function TEventBus.GetSubscriberCount(const EventType: string): Integer;
var
  List: TList<TSubscriptionInfo>;
begin
  FLock.Enter;
  try
    if FSubscriptions.TryGetValue(EventType, List) then
      Result := List.Count
    else
      Result := 0;
  finally
    FLock.Leave;
  end;
end;

function TEventBus.GetEventTypes: TArray<string>;
begin
  FLock.Enter;
  try
    Result := FSubscriptions.Keys.ToArray;
  finally
    FLock.Leave;
  end;
end;

procedure TEventBus.ReplayHistory<T>(Handler: TEventHandler<T>; Count: Integer);
var
  EventType: string;
  I, StartIdx: Integer;
  Pair: TPair<string, TValue>;
begin
  EventType := GetEventTypeName<T>;
  
  FLock.Enter;
  try
    if Count < 0 then
      StartIdx := 0
    else
      StartIdx := Max(0, FEventHistory.Count - Count);
    
    for I := StartIdx to FEventHistory.Count - 1 do
    begin
      Pair := FEventHistory[I];
      if Pair.Key = EventType then
        Handler(Pair.Value.AsType<T>);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TEventBus.ClearHistory;
begin
  FLock.Enter;
  try
    FEventHistory.Clear;
  finally
    FLock.Leave;
  end;
end;

procedure TEventBus.Clear;
var
  List: TList<TSubscriptionInfo>;
begin
  FLock.Enter;
  try
    DetachWeakSubscriptionLinks;
    for List in FSubscriptions.Values do
      List.Clear;
    FStats.ActiveSubscriptions := 0;
  finally
    FLock.Leave;
  end;
end;

procedure TEventBus.ResetStats;
begin
  FLock.Enter;
  try
    FStats.Reset;
    FStats.ActiveSubscriptions := 0;
    
    var List: TList<TSubscriptionInfo>;
    for List in FSubscriptions.Values do
      Inc(FStats.ActiveSubscriptions, List.Count);
  finally
    FLock.Leave;
  end;
end;

function TEventBus.WaitForAsyncHandlers(TimeoutMs: Cardinal): Boolean;
begin
  Result := (FAsyncDrained = nil) or
    (FAsyncDrained.WaitFor(TimeoutMs) = wrSignaled);
end;

class function TEventBus.IsValidEventType(const EventType: string): Boolean;
var
  AllowedTypes: TArray<string>;
  I: Integer;
  LowerType: string;
begin
  Result := False;

  // Basic requirements
  if EventType.IsEmpty or (Length(EventType) > 255) then
    Exit;

  // Character validation - only letters, digits, underscores and dots
  for var C in EventType do
  begin
    if not CharInSet(C, ['a'..'z', 'A'..'Z', '0'..'9', '.', '_']) then
      Exit;
  end;

  // Disallow leading/trailing dots
  if EventType.StartsWith('.') or EventType.EndsWith('.') then
    Exit;

  // Disallow consecutive dots
  if EventType.Contains('..') then
    Exit;

  // CORE-R2-010 FIX: check whitelist FIRST and short-circuit to True so that
  // the blacklist below cannot override an explicit whitelist match. A type
  // that starts with a trusted prefix (TUser, TSystem, ...) is safe by
  // construction.
  AllowedTypes := TArray<string>.Create(
    'TUser',
    'TSystem',
    'TApplication',
    'TData',
    'TUI',
    'TConfig',
    'TLog',
    'TMetric',
    'TSession',
    'TFile',
    'TNetwork',
    'TDatabase'
  );

  for I := Low(AllowedTypes) to High(AllowedTypes) do
  begin
    if EventType.StartsWith(AllowedTypes[I]) then
      Exit(True);
  end;

  // Dangerous event type blacklist (only applies to non-whitelisted types)
  LowerType := EventType.ToLower;
  if LowerType.Contains('system') and (LowerType.Contains('exec') or LowerType.Contains('cmd')) then
    Exit;
end;

// ============================================================================
// Initialization
// ============================================================================

initialization
  GEventBusLock := TCriticalSection.Create;

finalization
  // BUG EXP-P1-010 FIX: guard finalization against (a) uninitialized globals
  // (nil instance — `Free` on a nil class reference is safe in Delphi but we
  // prefer an explicit check for clarity) and (b) concurrent access from
  // worker threads still in-flight during unit shutdown. The Assigned guard
  // plus nil-out makes the teardown idempotent, and holding the lock while
  // tearing down serialises against any concurrent `GEventBusLock.Enter` in
  // the hot path — those callers will observe `GEventBus = nil` and skip.
  GEventBusFinalized := True;
  if Assigned(GEventBusLock) then
    GEventBusLock.Enter;
  try
    if Assigned(GEventBus) then
      FreeAndNil(GEventBus);
  finally
    if Assigned(GEventBusLock) then
    begin
      GEventBusLock.Leave;
      FreeAndNil(GEventBusLock);
    end;
  end;

end.
