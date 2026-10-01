{ ============================================================================
  DeepBase.DataBinding - Data Binding Module
  
  Version: 0.3
  Description: Provides data binding infrastructure for Model-View separation.
               Supports one-way, two-way, and one-time bindings.
               Binding entries track the lifetime of the observable source: when
               a source is destroyed its entries are removed automatically, so a
               manager never dereferences a freed source.
  
  Thread Safety: TBindingManager is NOT thread-safe. Use from main thread only.
  
  Usage:
    FUser := TUserModel.Create;      // TUserModel = class(TObservableObject)
    FBindings := TBindingManager.Create;
    FBindings.Bind(FUser, 'Name', EditName, 'Text', bmTwoWay);  // EditName: TControl
  ============================================================================ }

unit DeepBase.DataBinding;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
  System.TypInfo,
  System.Generics.Collections,
  System.Generics.Defaults;

type
  // Forward declarations
  TObservableObject = class;
  TBindingManager = class;
  
  /// <summary>
  /// Property changed event arguments
  /// </summary>
  TPropertyChangedEventArgs = record
    PropertyName: string;
    Sender: TObject;
  end;
  
  /// <summary>
  /// Property changed event handler
  /// </summary>
  TPropertyChangedEvent = procedure(const Args: TPropertyChangedEventArgs) of object;
  
  /// <summary>
  /// "对象正在析构" event handler. Sender is the instance being destroyed.
  /// 订阅方只能据此摘除自己持有的对该实例的引用；此刻起读写它的属性都已越界。
  /// </summary>
  TObjectDestroyingEvent = procedure(Sender: TObject) of object;
  
  /// <summary>
  /// Collection changed action
  /// </summary>
  TCollectionChangedAction = (caAdd, caRemove, caReplace, caClear, caReset);
  
  /// <summary>
  /// Collection changed event arguments
  /// </summary>
  TCollectionChangedEventArgs = record
    Action: TCollectionChangedAction;
    OldIndex: Integer;
    NewIndex: Integer;
    OldItem: TObject;
    NewItem: TObject;
  end;
  
  /// <summary>
  /// Collection changed event handler
  /// </summary>
  TCollectionChangedEvent = procedure(Sender: TObject; 
    const Args: TCollectionChangedEventArgs) of object;
  
  /// <summary>
  /// Interface for objects that notify property changes
  /// </summary>
  INotifyPropertyChanged = interface
    ['{E8B7C3A1-4D2F-4E5A-9B6C-7D8E9F0A1B2C}']
    procedure AddPropertyChangedHandler(Handler: TPropertyChangedEvent);
    procedure RemovePropertyChangedHandler(Handler: TPropertyChangedEvent);
  end;
  
  /// <summary>
  /// Interface for objects that notify collection changes
  /// </summary>
  INotifyCollectionChanged = interface
    ['{F9C8D4B2-5E3A-4F6B-AC7D-8E9F0A1B2C3D}']
    procedure AddCollectionChangedHandler(Handler: TCollectionChangedEvent);
    procedure ReDeepMoveCollectionChangedHandler(Handler: TCollectionChangedEvent);
  end;
  
  /// <summary>
  /// Binding mode
  /// </summary>
  TBindingMode = (
    bmOneWay,     // Source -> Target only
    bmTwoWay,     // Source <-> Target
    bmOneTime     // Source -> Target once on bind
  );
  
  /// <summary>
  /// Value converter interface for binding
  /// </summary>
  IValueConverter = interface
    ['{A1B2C3D4-E5F6-4A5B-8C9D-0E1F2A3B4C5D}']
    function Convert(const Value: TValue): TValue;
    function ConvertBack(const Value: TValue): TValue;
  end;
  
  /// <summary>
  /// Base class for observable objects with property change notification
  /// </summary>
  TObservableObject = class(TInterfacedPersistent, INotifyPropertyChanged)
  private
    FPropertyChangedHandlers: TList<TPropertyChangedEvent>;
    FDestroyingHandlers: TList<TObjectDestroyingEvent>;
  protected
    /// <summary>
    /// Call this in property setters after changing the value
    /// </summary>
    procedure NotifyPropertyChanged(const PropertyName: string);
    
    /// <summary>
    /// 由 Destroy 在释放 handler 列表之前调用；派生类不应改写其时序。
    /// </summary>
    procedure NotifyDestroying;
    
    /// <summary>
    /// Helper to set field and notify if changed
    /// </summary>
    procedure SetField<T>(var Field: T; const Value: T; const PropertyName: string);
  public
    constructor Create; virtual;
    destructor Destroy; override;
    
    // INotifyPropertyChanged
    procedure AddPropertyChangedHandler(Handler: TPropertyChangedEvent);
    procedure RemovePropertyChangedHandler(Handler: TPropertyChangedEvent);
    
    /// <summary>
    /// 登记「正在析构」回调，供持有本实例裸指针的一方（TBindingManager）及时摘除引用。
    /// 与 AddPropertyChangedHandler 同样对同一 handler 去重：一个订阅方在一个源上只占一份登记，
    /// 因此退订也必须按订阅方计数（见 TBindingManager.HasRemainingBindingForSource）。
    /// </summary>
    procedure AddDestroyingHandler(Handler: TObjectDestroyingEvent);
    procedure RemoveDestroyingHandler(Handler: TObjectDestroyingEvent);
  end;
  
  /// <summary>
  /// Observable list with collection change notifications
  /// </summary>
  TObservableList<T: class> = class(TInterfacedObject, INotifyCollectionChanged)
  private
    FItems: TObjectList<T>;
    FCollectionChangedHandlers: TList<TCollectionChangedEvent>;
    FOwnsObjects: Boolean;
    
    function GetCount: Integer;
    function GetItem(Index: Integer): T;
    procedure SetItem(Index: Integer; const Value: T);
    procedure SetOwnsObjects(Value: Boolean);
  protected
    procedure NotifyCollectionChanged(Action: TCollectionChangedAction;
      OldIndex, NewIndex: Integer; OldItem, NewItem: TObject);
  public
    constructor Create(AOwnsObjects: Boolean = True);
    destructor Destroy; override;
    
    // INotifyCollectionChanged
    procedure AddCollectionChangedHandler(Handler: TCollectionChangedEvent);
    procedure ReDeepMoveCollectionChangedHandler(Handler: TCollectionChangedEvent);
    
    // List operations
    function Add(Item: T): Integer;
    procedure Insert(Index: Integer; Item: T);
    procedure Delete(Index: Integer);
    function Remove(Item: T): Integer;
    procedure Clear;
    function IndexOf(Item: T): Integer;
    
    property Count: Integer read GetCount;
    property Items[Index: Integer]: T read GetItem write SetItem; default;
    property OwnsObjects: Boolean read FOwnsObjects write SetOwnsObjects;
  end;
  
  /// <summary>
  /// Binding entry record
  /// </summary>
  TBindingEntry = record
    Source: TObject;
    SourceProperty: string;
    Target: TObject;
    TargetProperty: string;
    Mode: TBindingMode;
    Converter: IValueConverter;
    Active: Boolean;
  end;
  
  /// <summary>
  /// Binding manager - manages all bindings between objects
  /// </summary>
  TBindingManager = class
  private
    FBindings: TList<TBindingEntry>;
    FRttiContext: TRttiContext;
    FUpdating: Boolean;
    
    procedure HandleSourcePropertyChanged(const Args: TPropertyChangedEventArgs);
    procedure UpdateTarget(const Entry: TBindingEntry);
    procedure UpdateSource(const Entry: TBindingEntry);
    
    function GetPropertyValue(Obj: TObject; const PropName: string): TValue;
    procedure SetPropertyValue(Obj: TObject; const PropName: string; const Value: TValue);

    { A5-R02 落笔①（source 面）：源正在析构 ⇒ 以它为 source 的条目全部作废。
      摘条只能在析构通知里做（此后指针即悬空），且必须绕开退订：此刻对象的 handler 列表
      正要随它一起消失，回调里再去 Remove handler 是在已析构实例上做无用功。 }
    procedure HandleSourceDestroying(Sender: TObject);
    procedure DropBindingsForDestroyingSource(ASource: TObject);

    { 退订成对收口：属性变更与「正在析构」两份登记必须同时摘除。漏摘后者会让本 manager
      释放后仍被源析构回调（悬空方法指针）。登记侧不分绑定模式（bmOneTime 的条目仍被
      UpdateAllTargets 重读），退订侧同理。 }
    procedure UnsubscribeSource(ASource: TObject);

    { A5-R01 退订按源引用计数：AddPropertyChangedHandler 对同一 handler 去重
      （TObservableObject.AddPropertyChangedHandler 有 Contains 判重），一个 Source
      在同一个 manager 内只登记一份订阅。因此删除绑定条目时必须先确认该 Source 没有
      其它条目，否则解绑同源兄弟绑定中的一条会退订共享订阅，让存活的绑定静默失效。
      ASkipIndex 指向即将删除的那一条，不计入「剩余」。 }
    function HasRemainingBindingForSource(ASource: TObject;
      ASkipIndex: Integer): Boolean;

  public
    constructor Create;
    destructor Destroy; override;
    
    /// <summary>
    /// Create a binding between source and target properties
    /// </summary>
    procedure Bind(Source: TObject; const SourceProp: string;
                   Target: TObject; const TargetProp: string;
                   Mode: TBindingMode = bmTwoWay;
                   Converter: IValueConverter = nil);
    
    /// <summary>
    /// Remove all bindings for a source/target pair
    /// </summary>
    procedure Unbind(Source, Target: TObject);
    
    /// <summary>
    /// Remove all bindings for a specific object (as source or target)
    /// </summary>
    procedure UnbindObject(Obj: TObject);
    
    /// <summary>
    /// Remove all bindings
    /// </summary>
    procedure UnbindAll;
    
    /// <summary>
    /// Force update all targets from sources
    /// </summary>
    procedure UpdateAllTargets;
    
    /// <summary>
    /// Notify that a target property has changed (for two-way binding)
    /// </summary>
    procedure NotifyTargetChanged(Target: TObject; const PropName: string);
    
    /// <summary>
    /// Number of active bindings
    /// </summary>
    function BindingCount: Integer;
  end;

implementation

uses
  System.Variants;

{ TObservableObject }

constructor TObservableObject.Create;
begin
  inherited Create;
  FPropertyChangedHandlers := TList<TPropertyChangedEvent>.Create;
  FDestroyingHandlers := TList<TObjectDestroyingEvent>.Create;
end;

destructor TObservableObject.Destroy;
begin
  { 时序即修法本身：通知必须在两份 handler 列表释放之前发出，否则订阅方（TBindingManager）
    无从得知自己持有的裸指针即将失效 —— 摘掉本行即 A4-01 探针 S4 read-after-free 复现。 }
  NotifyDestroying;
  FreeAndNil(FPropertyChangedHandlers);
  FreeAndNil(FDestroyingHandlers);
  inherited;
end;

procedure TObservableObject.AddPropertyChangedHandler(Handler: TPropertyChangedEvent);
begin
  if not FPropertyChangedHandlers.Contains(Handler) then
    FPropertyChangedHandlers.Add(Handler);
end;

procedure TObservableObject.RemovePropertyChangedHandler(Handler: TPropertyChangedEvent);
begin
  FPropertyChangedHandlers.Remove(Handler);
end;

procedure TObservableObject.AddDestroyingHandler(Handler: TObjectDestroyingEvent);
begin
  if not FDestroyingHandlers.Contains(Handler) then
    FDestroyingHandlers.Add(Handler);
end;

procedure TObservableObject.RemoveDestroyingHandler(Handler: TObjectDestroyingEvent);
begin
  FDestroyingHandlers.Remove(Handler);
end;

procedure TObservableObject.NotifyDestroying;
var
  Handler: TObjectDestroyingEvent;
begin
  for Handler in FDestroyingHandlers do
    Handler(Self);
end;

procedure TObservableObject.NotifyPropertyChanged(const PropertyName: string);
var
  Handler: TPropertyChangedEvent;
  Args: TPropertyChangedEventArgs;
begin
  Args.PropertyName := PropertyName;
  Args.Sender := Self;
  
  for Handler in FPropertyChangedHandlers do
    Handler(Args);
end;

procedure TObservableObject.SetField<T>(var Field: T; const Value: T; 
  const PropertyName: string);
var
  Comparer: IEqualityComparer<T>;
begin
  Comparer := TEqualityComparer<T>.Default;
  if not Comparer.Equals(Field, Value) then
  begin
    Field := Value;
    NotifyPropertyChanged(PropertyName);
  end;
end;

{ TObservableList<T> }

constructor TObservableList<T>.Create(AOwnsObjects: Boolean);
begin
  inherited Create;
  FOwnsObjects := AOwnsObjects;
  FItems := TObjectList<T>.Create(AOwnsObjects);
  FCollectionChangedHandlers := TList<TCollectionChangedEvent>.Create;
end;

destructor TObservableList<T>.Destroy;
begin
  FreeAndNil(FCollectionChangedHandlers);
  FreeAndNil(FItems);
  inherited;
end;

procedure TObservableList<T>.AddCollectionChangedHandler(Handler: TCollectionChangedEvent);
begin
  if not FCollectionChangedHandlers.Contains(Handler) then
    FCollectionChangedHandlers.Add(Handler);
end;

procedure TObservableList<T>.ReDeepMoveCollectionChangedHandler(Handler: TCollectionChangedEvent);
begin
  FCollectionChangedHandlers.Remove(Handler);
end;

procedure TObservableList<T>.NotifyCollectionChanged(Action: TCollectionChangedAction;
  OldIndex, NewIndex: Integer; OldItem, NewItem: TObject);
var
  Handler: TCollectionChangedEvent;
  Args: TCollectionChangedEventArgs;
begin
  Args.Action := Action;
  Args.OldIndex := OldIndex;
  Args.NewIndex := NewIndex;
  Args.OldItem := OldItem;
  Args.NewItem := NewItem;
  
  for Handler in FCollectionChangedHandlers do
    Handler(Self, Args);
end;

function TObservableList<T>.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TObservableList<T>.GetItem(Index: Integer): T;
begin
  Result := FItems[Index];
end;

procedure TObservableList<T>.SetOwnsObjects(Value: Boolean);
begin
  FOwnsObjects := Value;
  if Assigned(FItems) then
    FItems.OwnsObjects := Value;
end;

procedure TObservableList<T>.SetItem(Index: Integer; const Value: T);
var
  OldItem: T;
begin
  OldItem := FItems[Index];
  FItems[Index] := Value;
  NotifyCollectionChanged(caReplace, Index, Index, OldItem, Value);
end;

function TObservableList<T>.Add(Item: T): Integer;
begin
  Result := FItems.Add(Item);
  NotifyCollectionChanged(caAdd, -1, Result, nil, Item);
end;

procedure TObservableList<T>.Insert(Index: Integer; Item: T);
begin
  FItems.Insert(Index, Item);
  NotifyCollectionChanged(caAdd, -1, Index, nil, Item);
end;

procedure TObservableList<T>.Delete(Index: Integer);
var
  Item: T;
begin
  Item := FItems[Index];
  FItems.Delete(Index);
  NotifyCollectionChanged(caRemove, Index, -1, Item, nil);
end;

function TObservableList<T>.Remove(Item: T): Integer;
begin
  Result := FItems.IndexOf(Item);
  if Result >= 0 then
    Delete(Result);
end;

procedure TObservableList<T>.Clear;
begin
  FItems.Clear;
  NotifyCollectionChanged(caClear, -1, -1, nil, nil);
end;

function TObservableList<T>.IndexOf(Item: T): Integer;
begin
  Result := FItems.IndexOf(Item);
end;

{ TBindingManager }

constructor TBindingManager.Create;
begin
  inherited Create;
  FBindings := TList<TBindingEntry>.Create;
  FRttiContext := TRttiContext.Create;
  FUpdating := False;
end;

destructor TBindingManager.Destroy;
begin
  UnbindAll;
  FreeAndNil(FBindings);
  FRttiContext.Free;
  inherited;
end;

function TBindingManager.GetPropertyValue(Obj: TObject; const PropName: string): TValue;
var
  RttiType: TRttiType;
  RttiProp: TRttiProperty;
begin
  Result := TValue.Empty;
  
  RttiType := FRttiContext.GetType(Obj.ClassType);
  if RttiType = nil then Exit;
  
  RttiProp := RttiType.GetProperty(PropName);
  if RttiProp <> nil then
    Result := RttiProp.GetValue(Obj);
end;

procedure TBindingManager.SetPropertyValue(Obj: TObject; const PropName: string; 
  const Value: TValue);
var
  RttiType: TRttiType;
  RttiProp: TRttiProperty;
begin
  RttiType := FRttiContext.GetType(Obj.ClassType);
  if RttiType = nil then Exit;
  
  RttiProp := RttiType.GetProperty(PropName);
  if (RttiProp <> nil) and RttiProp.IsWritable then
    RttiProp.SetValue(Obj, Value);
end;

function TBindingManager.HasRemainingBindingForSource(ASource: TObject;
  ASkipIndex: Integer): Boolean;
var
  i: Integer;
begin
  for i := 0 to FBindings.Count - 1 do
    if (i <> ASkipIndex) and (FBindings[i].Source = ASource) then
      Exit(True);
  Result := False;
end;

procedure TBindingManager.UnsubscribeSource(ASource: TObject);
var
  Observable: INotifyPropertyChanged;
begin
  if Supports(ASource, INotifyPropertyChanged, Observable) then
    Observable.RemovePropertyChangedHandler(HandleSourcePropertyChanged);
  if ASource is TObservableObject then
    TObservableObject(ASource).RemoveDestroyingHandler(HandleSourceDestroying);
end;

procedure TBindingManager.HandleSourceDestroying(Sender: TObject);
begin
  DropBindingsForDestroyingSource(Sender);
end;

procedure TBindingManager.DropBindingsForDestroyingSource(ASource: TObject);
var
  i: Integer;
begin
  for i := FBindings.Count - 1 downto 0 do
    if FBindings[i].Source = ASource then
      FBindings.Delete(i);
end;

procedure TBindingManager.HandleSourcePropertyChanged(const Args: TPropertyChangedEventArgs);
var
  i: Integer;
  Entry: TBindingEntry;
begin
  if FUpdating then Exit;
  
  for i := 0 to FBindings.Count - 1 do
  begin
    Entry := FBindings[i];
    if Entry.Active and 
       (Entry.Mode <> bmOneTime) and
       (Entry.Source = Args.Sender) and 
       (Entry.SourceProperty = Args.PropertyName) then
    begin
      UpdateTarget(Entry);
    end;
  end;
end;

procedure TBindingManager.UpdateTarget(const Entry: TBindingEntry);
var
  Value: TValue;
begin
  if not Entry.Active then Exit;
  
  FUpdating := True;
  try
    Value := GetPropertyValue(Entry.Source, Entry.SourceProperty);
    
    if Entry.Converter <> nil then
      Value := Entry.Converter.Convert(Value);
    
    SetPropertyValue(Entry.Target, Entry.TargetProperty, Value);
  finally
    FUpdating := False;
  end;
end;

procedure TBindingManager.UpdateSource(const Entry: TBindingEntry);
var
  Value: TValue;
begin
  if not Entry.Active or (Entry.Mode <> bmTwoWay) then Exit;
  
  FUpdating := True;
  try
    Value := GetPropertyValue(Entry.Target, Entry.TargetProperty);
    
    if Entry.Converter <> nil then
      Value := Entry.Converter.ConvertBack(Value);
    
    SetPropertyValue(Entry.Source, Entry.SourceProperty, Value);
  finally
    FUpdating := False;
  end;
end;

procedure TBindingManager.Bind(Source: TObject; const SourceProp: string;
                                Target: TObject; const TargetProp: string;
                                Mode: TBindingMode; Converter: IValueConverter);
var
  Entry: TBindingEntry;
  Observable: INotifyPropertyChanged;
begin
  // Create binding entry
  Entry.Source := Source;
  Entry.SourceProperty := SourceProp;
  Entry.Target := Target;
  Entry.TargetProperty := TargetProp;
  Entry.Mode := Mode;
  Entry.Converter := Converter;
  Entry.Active := True;
  
  FBindings.Add(Entry);
  
  // Subscribe to source property changes
  if (Mode <> bmOneTime) and Supports(Source, INotifyPropertyChanged, Observable) then
    Observable.AddPropertyChangedHandler(HandleSourcePropertyChanged);
  
  { 生命周期登记不分绑定模式：bmOneTime 的条目仍会被 UpdateAllTargets 重读，
    源析构后它同样是悬空指针。属性变更订阅可以按模式裁剪，存活订阅不行。 }
  if Source is TObservableObject then
    TObservableObject(Source).AddDestroyingHandler(HandleSourceDestroying);
  
  // Initial sync: source -> target
  UpdateTarget(Entry);
end;

procedure TBindingManager.Unbind(Source, Target: TObject);
var
  i: Integer;
  Entry: TBindingEntry;
begin
  for i := FBindings.Count - 1 downto 0 do
  begin
    Entry := FBindings[i];
    if (Entry.Source = Source) and (Entry.Target = Target) then
    begin
      // 仅当该 Source 不再有其它绑定条目时才退订共享 handler（A5-R01）
      if not HasRemainingBindingForSource(Entry.Source, i) then
        UnsubscribeSource(Entry.Source);

      FBindings.Delete(i);
    end;
  end;
end;

procedure TBindingManager.UnbindObject(Obj: TObject);
var
  i: Integer;
  Entry: TBindingEntry;
begin
  for i := FBindings.Count - 1 downto 0 do
  begin
    Entry := FBindings[i];
    if (Entry.Source = Obj) or (Entry.Target = Obj) then
    begin
      // 同 A5-R01：Obj 作为目标被解绑时，它作为源的其它绑定必须保住订阅
      if not HasRemainingBindingForSource(Entry.Source, i) then
        UnsubscribeSource(Entry.Source);

      FBindings.Delete(i);
    end;
  end;
end;

procedure TBindingManager.UnbindAll;
var
  i: Integer;
  Entry: TBindingEntry;
begin
  for i := FBindings.Count - 1 downto 0 do
  begin
    Entry := FBindings[i];
    UnsubscribeSource(Entry.Source);
  end;
  
  FBindings.Clear;
end;

procedure TBindingManager.UpdateAllTargets;
var
  i: Integer;
begin
  for i := 0 to FBindings.Count - 1 do
    UpdateTarget(FBindings[i]);
end;

procedure TBindingManager.NotifyTargetChanged(Target: TObject; const PropName: string);
var
  i: Integer;
  Entry: TBindingEntry;
begin
  if FUpdating then Exit;
  
  for i := 0 to FBindings.Count - 1 do
  begin
    Entry := FBindings[i];
    if Entry.Active and 
       (Entry.Mode = bmTwoWay) and
       (Entry.Target = Target) and 
       (Entry.TargetProperty = PropName) then
    begin
      UpdateSource(Entry);
    end;
  end;
end;

function TBindingManager.BindingCount: Integer;
begin
  Result := FBindings.Count;
end;

end.
