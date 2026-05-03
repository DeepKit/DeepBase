{ ============================================================================
  UniBase.EventBus - Publish-Subscribe Event Bus
  
  A flexible event bus implementation for decoupled component communication.
  
  Features:
  - Type-safe event publishing and subscribing
  - Synchronous and asynchronous event dispatch
  - Event filtering and prioritization
  - Weak reference support (auto-unsubscribe on object destruction)
  - Thread-safe operations
  - Event history and replay
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

unit UniBase.EventBus;

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
    procedure Unsubscribe;
    function IsActive: Boolean;
    function GetEventType: string;
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
    Filter: TFunc<TValue, Boolean>;
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
    
    /// <summary>Clear event history</summary>
    procedure ClearHistory;
    
    // ========================================================================
    // Utility
    // ========================================================================
    
    /// <summary>Clear all subscriptions</summary>
    procedure Clear;
    
    /// <summary>Reset statistics</summary>
    procedure ResetStats;
    
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
/// R-007: 所有权语义说明：
///   - 调用此方法后，AEventBus 的所有权转移给全局单例管理器
///   - 之前的全局实例（无论是 auto-created 还是之前传入的）都会被释放
///   - 传入 nil 可重置为默认的懒加载行为
///   - 调用者不应在调用后继续持有或释放 AEventBus
/// </summary>
procedure SetEventBus(AEventBus: TEventBus);

implementation

var
  GEventBus: TEventBus = nil;
  GEventBusLock: TCriticalSection = nil;

function EventBus: TEventBus;
begin
  if GEventBus = nil then
  begin
    GEventBusLock.Enter;
    try
      if GEventBus = nil then
        GEventBus := TEventBus.Create;
    finally
      GEventBusLock.Leave;
    end;
  end;
  Result := GEventBus;
end;

procedure SetEventBus(AEventBus: TEventBus);
begin
  GEventBusLock.Enter;
  try
    // R-007: 所有权转移逻辑
    // - 如果传入的实例与当前实例不同，释放旧实例
    // - 传入 nil 会释放当前实例并允许后续懒加载
    // - 传入同一实例则无操作（避免 double-free）
    if GEventBus <> AEventBus then
    begin
      FreeAndNil(GEventBus);  // 安全释放旧实例（包括 nil 情况）
      GEventBus := AEventBus; // 所有权转移，调用者不应再释放
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
  FLock := TCriticalSection.Create;
  FEventHistory := TList<TPair<string, TValue>>.Create;
  FEnabled := True;
  FKeepHistory := False;
  FMaxHistorySize := 100;
  FStats.Reset;
end;

destructor TEventBus.Destroy;
var
  List: TList<TSubscriptionInfo>;
begin
  FLock.Enter;
  try
    DetachWeakSubscriptionLinks;
    FOwnerLinks.Free;
    for List in FSubscriptions.Values do
      List.Free;
    FSubscriptions.Free;
    FEventHistory.Free;
  finally
    FLock.Leave;
  end;
  FLock.Free;
  inherited;
end;

function TEventBus.GetEventTypeName<T>: string;
begin
  Result := PTypeInfo(TypeInfo(T))^.Name;
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
    Info.Filter := TFunc<TValue, Boolean>(
      function(const Event: TValue): Boolean
      begin
        Result := TypedFilter(Event.AsType<T>);
      end);
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
const
  // 事件类型白名单
  ALLOWED_EVENT_TYPES: array[0..4] of string = (
    'TUserEvent', 'TSystemEvent', 'TDataEvent', 'TUIEvent', 'TLogEvent'
  );
var
  Info: TSubscriptionInfo;
  List: TList<TSubscriptionInfo>;
  I: Integer;
  IsAllowed: Boolean;
begin
  // 实现事件类型白名单验证机制
  IsAllowed := False;
  for I := Low(ALLOWED_EVENT_TYPES) to High(ALLOWED_EVENT_TYPES) do
  begin
    if EventType.StartsWith(ALLOWED_EVENT_TYPES[I]) then
    begin
      IsAllowed := True;
      Break;
    end;
  end;
  
  if not IsAllowed then
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
begin
  LHandler := Info.Handler;
  LEvent := Event;
  
  case Info.DispatchMode of
    edmSync:
      LHandler(LEvent);
      
    edmAsync:
      TThread.CreateAnonymousThread(
        procedure
        begin
          LHandler(LEvent);
        end).Start;
      
    edmMainThread:
      // Queue to main thread - using Queue for compatibility
      if TThread.CurrentThread.ThreadID = MainThreadID then
        LHandler(LEvent)
      else
        TThread.Queue(nil,
          procedure
          begin
            LHandler(LEvent);
          end);
  end;
end;

procedure TEventBus.AddToHistory(const EventType: string; const Event: TValue);
begin
  if not FKeepHistory then
    Exit;
  
  FEventHistory.Add(TPair<string, TValue>.Create(EventType, Event));
  
  // Trim history if too large
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
  LProc: TProc;
begin
  EventCopy := Event;
  LSelf := Self;
  LProc := procedure
    begin
      LSelf.Publish<T>(EventCopy);
    end;
  Result := TTask.Run(LProc);
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
  
  Inc(FStats.TotalPublished);
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
          Inc(FStats.TotalFiltered);
          Continue;
        end;
      end;
      
      InvokeHandler(Info, Event);
      Inc(FStats.TotalDelivered);
      Delivered := True;
      
    except
      on E: Exception do
      begin
        Inc(FStats.TotalErrors);
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

class function TEventBus.IsValidEventType(const EventType: string): Boolean;
var
  AllowedTypes: TArray<string>;
  I: Integer;
begin
  Result := False;
  
  // 检查基本要求
  if EventType.IsEmpty or (Length(EventType) > 255) then
    Exit;
    
  // 检查字符有效性 - 只允许字母、数字、点和下划线
  for var C in EventType do
  begin
    if not CharInSet(C, ['a'..'z', 'A'..'Z', '0'..'9', '.', '_']) then
      Exit;
  end;
  
  // 不能以点开头或结尾
  if EventType.StartsWith('.') or EventType.EndsWith('.') then
    Exit;
    
  // 不允许连续的点
  if EventType.Contains('..') then
    Exit;
    
  // 定义允许的事件类型前缀
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
  
  // 检查是否以允许的前缀开头
  for I := Low(AllowedTypes) to High(AllowedTypes) do
  begin
    if EventType.StartsWith(AllowedTypes[I]) then
    begin
      Result := True;
      Break;
    end;
  end;
  
  // 禁止危险的事件类型
  var LowerType := EventType.ToLower;
  if LowerType.Contains('system') and (LowerType.Contains('exec') or LowerType.Contains('cmd')) then
    Result := False;
end;

// ============================================================================
// Initialization
// ============================================================================

initialization
  GEventBusLock := TCriticalSection.Create;

finalization
  GEventBus.Free;
  GEventBusLock.Free;

end.
