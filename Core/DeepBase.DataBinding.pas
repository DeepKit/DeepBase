{ ============================================================================
  DeepBase.DataBinding - Data Binding Module
  
  Version: 0.3
  Description: Provides data binding infrastructure for Model-View separation.
               Supports one-way, two-way, and one-time bindings.
  
  Thread Safety: TBindingManager is NOT thread-safe. Use from main thread only.
  
  Usage:
    FUser := TUserModel.Create;
    FBindings := TBindingManager.Create;
    FBindings.Bind(FUser, 'Name', EditName, 'Text', bmTwoWay);
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
  protected
    /// <summary>
    /// Call this in property setters after changing the value
    /// </summary>
    procedure NotifyPropertyChanged(const PropertyName: string);
    
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
end;

destructor TObservableObject.Destroy;
begin
  FreeAndNil(FPropertyChangedHandlers);
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
  
  // Initial sync: source -> target
  UpdateTarget(Entry);
end;

procedure TBindingManager.Unbind(Source, Target: TObject);
var
  i: Integer;
  Entry: TBindingEntry;
  Observable: INotifyPropertyChanged;
begin
  for i := FBindings.Count - 1 downto 0 do
  begin
    Entry := FBindings[i];
    if (Entry.Source = Source) and (Entry.Target = Target) then
    begin
      // Unsubscribe from source
      if Supports(Entry.Source, INotifyPropertyChanged, Observable) then
        Observable.RemovePropertyChangedHandler(HandleSourcePropertyChanged);
      
      FBindings.Delete(i);
    end;
  end;
end;

procedure TBindingManager.UnbindObject(Obj: TObject);
var
  i: Integer;
  Entry: TBindingEntry;
  Observable: INotifyPropertyChanged;
begin
  for i := FBindings.Count - 1 downto 0 do
  begin
    Entry := FBindings[i];
    if (Entry.Source = Obj) or (Entry.Target = Obj) then
    begin
      if Supports(Entry.Source, INotifyPropertyChanged, Observable) then
        Observable.RemovePropertyChangedHandler(HandleSourcePropertyChanged);
      
      FBindings.Delete(i);
    end;
  end;
end;

procedure TBindingManager.UnbindAll;
var
  i: Integer;
  Entry: TBindingEntry;
  Observable: INotifyPropertyChanged;
begin
  for i := FBindings.Count - 1 downto 0 do
  begin
    Entry := FBindings[i];
    if Supports(Entry.Source, INotifyPropertyChanged, Observable) then
      Observable.RemovePropertyChangedHandler(HandleSourcePropertyChanged);
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
