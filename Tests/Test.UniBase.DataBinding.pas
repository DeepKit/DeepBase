{ ============================================================================
  Test.UniBase.DataBinding - DataBinding Module Unit Tests
  
  Tests for UniBase.DataBinding module including:
  - TObservableObject property change notifications
  - TObservableList<T> collection change notifications
  - TBindingManager binding operations
  - One-way and two-way binding modes
  - Value converters
  ============================================================================ }

unit Test.UniBase.DataBinding;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.Rtti,
  System.Generics.Collections,
  UniBase.DataBinding;

type
  // Test model class
  TTestPerson = class(TObservableObject)
  private
    FName: string;
    FAge: Integer;
    FActive: Boolean;
    procedure SetName(const Value: string);
    procedure SetAge(const Value: Integer);
    procedure SetActive(const Value: Boolean);
  public
    property Name: string read FName write SetName;
    property Age: Integer read FAge write SetAge;
    property Active: Boolean read FActive write SetActive;
  end;
  
  // Test target class (simulates UI control)
  TTestTarget = class
  private
    FText: string;
    FValue: Integer;
    FChecked: Boolean;
  public
    property Text: string read FText write FText;
    property Value: Integer read FValue write FValue;
    property Checked: Boolean read FChecked write FChecked;
  end;
  
  // Simple value converter for testing
  TStringToUpperConverter = class(TInterfacedObject, IValueConverter)
  public
    function Convert(const Value: TValue): TValue;
    function ConvertBack(const Value: TValue): TValue;
  end;
  
  TIntToStringConverter = class(TInterfacedObject, IValueConverter)
  public
    function Convert(const Value: TValue): TValue;
    function ConvertBack(const Value: TValue): TValue;
  end;

  [TestFixture]
  TTestObservableObject = class
  private
    FPerson: TTestPerson;
    FChangedProps: TList<string>;
    FChangeCount: Integer;
    
    procedure OnPropertyChanged(const Args: TPropertyChangedEventArgs);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_NotifyPropertyChanged_FiresEvent;
    
    [Test]
    procedure Test_MultipleHandlers_AllReceiveNotification;
    
    [Test]
    procedure Test_RemoveHandler_StopsNotification;
    
    [Test]
    procedure Test_SetField_NotifiesOnChange;
    
    [Test]
    procedure Test_SetField_NoNotifyWhenSameValue;
  end;
  
  [TestFixture]
  TTestObservableList = class
  private
    FList: TObservableList<TTestPerson>;
    FLastAction: TCollectionChangedAction;
    FChangeCount: Integer;
    
    procedure OnCollectionChanged(Sender: TObject; const Args: TCollectionChangedEventArgs);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_Add_NotifiesChange;
    
    [Test]
    procedure Test_Insert_NotifiesChange;
    
    [Test]
    procedure Test_Delete_NotifiesChange;
    
    [Test]
    procedure Test_Clear_NotifiesChange;
    
    [Test]
    procedure Test_SetItem_NotifiesReplace;
    
    [Test]
    procedure Test_Remove_ReturnsCorrectIndex;
  end;
  
  [TestFixture]
  TTestBindingManager = class
  private
    FManager: TBindingManager;
    FSource: TTestPerson;
    FTarget: TTestTarget;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_Bind_InitialSync;
    
    [Test]
    procedure Test_OneWayBinding_SourceToTarget;
    
    [Test]
    procedure Test_TwoWayBinding_TargetToSource;
    
    [Test]
    procedure Test_OneTimeBinding_NoUpdatesAfterInit;
    
    [Test]
    procedure Test_Unbind_StopsUpdates;
    
    [Test]
    procedure Test_UnbindAll_ClearsBindings;
    
    [Test]
    procedure Test_BindingCount_ReturnsCorrectCount;
    
    [Test]
    procedure Test_ValueConverter_ConvertOnSync;
    
    [Test]
    procedure Test_ValueConverter_ConvertBackOnTwoWay;
    
    [Test]
    procedure Test_MultipleBindings_AllUpdate;
    
    [Test]
    procedure Test_UpdateAllTargets_ForcesSync;
  end;

implementation

{ TTestPerson }

procedure TTestPerson.SetName(const Value: string);
begin
  SetField<string>(FName, Value, 'Name');
end;

procedure TTestPerson.SetAge(const Value: Integer);
begin
  SetField<Integer>(FAge, Value, 'Age');
end;

procedure TTestPerson.SetActive(const Value: Boolean);
begin
  SetField<Boolean>(FActive, Value, 'Active');
end;

{ TStringToUpperConverter }

function TStringToUpperConverter.Convert(const Value: TValue): TValue;
begin
  if Value.IsType<string> then
    Result := TValue.From<string>(UpperCase(Value.AsString))
  else
    Result := Value;
end;

function TStringToUpperConverter.ConvertBack(const Value: TValue): TValue;
begin
  if Value.IsType<string> then
    Result := TValue.From<string>(LowerCase(Value.AsString))
  else
    Result := Value;
end;

{ TIntToStringConverter }

function TIntToStringConverter.Convert(const Value: TValue): TValue;
begin
  if Value.IsType<Integer> then
    Result := TValue.From<string>(IntToStr(Value.AsInteger))
  else
    Result := Value;
end;

function TIntToStringConverter.ConvertBack(const Value: TValue): TValue;
var
  S: string;
  I: Integer;
begin
  if Value.IsType<string> then
  begin
    S := Value.AsString;
    if TryStrToInt(S, I) then
      Result := TValue.From<Integer>(I)
    else
      Result := TValue.From<Integer>(0);
  end
  else
    Result := Value;
end;

{ TTestObservableObject }

procedure TTestObservableObject.Setup;
begin
  FPerson := TTestPerson.Create;
  FChangedProps := TList<string>.Create;
  FChangeCount := 0;
end;

procedure TTestObservableObject.TearDown;
begin
  FPerson.Free;
  FChangedProps.Free;
end;

procedure TTestObservableObject.OnPropertyChanged(const Args: TPropertyChangedEventArgs);
begin
  Inc(FChangeCount);
  FChangedProps.Add(Args.PropertyName);
end;

procedure TTestObservableObject.Test_NotifyPropertyChanged_FiresEvent;
begin
  FPerson.AddPropertyChangedHandler(OnPropertyChanged);
  FPerson.Name := 'Test';
  
  Assert.AreEqual(1, FChangeCount);
  Assert.AreEqual('Name', FChangedProps[0]);
end;

procedure TTestObservableObject.Test_MultipleHandlers_AllReceiveNotification;
var
  Count2: Integer;
  Handler2: TPropertyChangedEvent;
begin
  Count2 := 0;
  Handler2 := procedure(const Args: TPropertyChangedEventArgs)
              begin
                Inc(Count2);
              end;
  
  FPerson.AddPropertyChangedHandler(OnPropertyChanged);
  FPerson.AddPropertyChangedHandler(Handler2);
  
  FPerson.Name := 'Test';
  
  Assert.AreEqual(1, FChangeCount);
  Assert.AreEqual(1, Count2);
end;

procedure TTestObservableObject.Test_RemoveHandler_StopsNotification;
begin
  FPerson.AddPropertyChangedHandler(OnPropertyChanged);
  FPerson.Name := 'Test1';
  Assert.AreEqual(1, FChangeCount);
  
  FPerson.RemovePropertyChangedHandler(OnPropertyChanged);
  FPerson.Name := 'Test2';
  Assert.AreEqual(1, FChangeCount); // Should still be 1
end;

procedure TTestObservableObject.Test_SetField_NotifiesOnChange;
begin
  FPerson.AddPropertyChangedHandler(OnPropertyChanged);
  
  FPerson.Name := 'Initial';
  FPerson.Age := 25;
  FPerson.Active := True;
  
  Assert.AreEqual(3, FChangeCount);
  Assert.IsTrue(FChangedProps.Contains('Name'));
  Assert.IsTrue(FChangedProps.Contains('Age'));
  Assert.IsTrue(FChangedProps.Contains('Active'));
end;

procedure TTestObservableObject.Test_SetField_NoNotifyWhenSameValue;
begin
  FPerson.Name := 'Same';
  FPerson.AddPropertyChangedHandler(OnPropertyChanged);
  
  FPerson.Name := 'Same'; // Same value
  
  Assert.AreEqual(0, FChangeCount);
end;

{ TTestObservableList }

procedure TTestObservableList.Setup;
begin
  FList := TObservableList<TTestPerson>.Create(True);
  FChangeCount := 0;
end;

procedure TTestObservableList.TearDown;
begin
  FList.Free;
end;

procedure TTestObservableList.OnCollectionChanged(Sender: TObject; 
  const Args: TCollectionChangedEventArgs);
begin
  Inc(FChangeCount);
  FLastAction := Args.Action;
end;

procedure TTestObservableList.Test_Add_NotifiesChange;
begin
  FList.AddCollectionChangedHandler(OnCollectionChanged);
  FList.Add(TTestPerson.Create);
  
  Assert.AreEqual(1, FChangeCount);
  Assert.AreEqual(Ord(caAdd), Ord(FLastAction));
  Assert.AreEqual(1, FList.Count);
end;

procedure TTestObservableList.Test_Insert_NotifiesChange;
begin
  FList.Add(TTestPerson.Create);
  FList.AddCollectionChangedHandler(OnCollectionChanged);
  
  FList.Insert(0, TTestPerson.Create);
  
  Assert.AreEqual(1, FChangeCount);
  Assert.AreEqual(Ord(caAdd), Ord(FLastAction));
  Assert.AreEqual(2, FList.Count);
end;

procedure TTestObservableList.Test_Delete_NotifiesChange;
begin
  FList.Add(TTestPerson.Create);
  FList.AddCollectionChangedHandler(OnCollectionChanged);
  
  FList.Delete(0);
  
  Assert.AreEqual(1, FChangeCount);
  Assert.AreEqual(Ord(caRemove), Ord(FLastAction));
  Assert.AreEqual(0, FList.Count);
end;

procedure TTestObservableList.Test_Clear_NotifiesChange;
begin
  FList.Add(TTestPerson.Create);
  FList.Add(TTestPerson.Create);
  FList.AddCollectionChangedHandler(OnCollectionChanged);
  
  FList.Clear;
  
  Assert.AreEqual(1, FChangeCount);
  Assert.AreEqual(Ord(caClear), Ord(FLastAction));
  Assert.AreEqual(0, FList.Count);
end;

procedure TTestObservableList.Test_SetItem_NotifiesReplace;
var
  NewPerson: TTestPerson;
begin
  FList.Add(TTestPerson.Create);
  FList.OwnsObjects := False; // To prevent double-free
  FList.AddCollectionChangedHandler(OnCollectionChanged);
  
  NewPerson := TTestPerson.Create;
  try
    FList[0].Free;
    FList[0] := NewPerson;
    
    Assert.AreEqual(1, FChangeCount);
    Assert.AreEqual(Ord(caReplace), Ord(FLastAction));
  finally
    NewPerson.Free;
  end;
end;

procedure TTestObservableList.Test_Remove_ReturnsCorrectIndex;
var
  Person: TTestPerson;
  Index: Integer;
begin
  FList.Add(TTestPerson.Create);
  Person := TTestPerson.Create;
  FList.Add(Person);
  FList.Add(TTestPerson.Create);
  
  Index := FList.Remove(Person);
  
  Assert.AreEqual(1, Index);
  Assert.AreEqual(2, FList.Count);
end;

{ TTestBindingManager }

procedure TTestBindingManager.Setup;
begin
  FManager := TBindingManager.Create;
  FSource := TTestPerson.Create;
  FTarget := TTestTarget.Create;
end;

procedure TTestBindingManager.TearDown;
begin
  FManager.Free;
  FSource.Free;
  FTarget.Free;
end;

procedure TTestBindingManager.Test_Bind_InitialSync;
begin
  FSource.Name := 'Initial';
  
  FManager.Bind(FSource, 'Name', FTarget, 'Text', bmOneWay);
  
  Assert.AreEqual('Initial', FTarget.Text);
end;

procedure TTestBindingManager.Test_OneWayBinding_SourceToTarget;
begin
  FManager.Bind(FSource, 'Name', FTarget, 'Text', bmOneWay);
  
  FSource.Name := 'Updated';
  
  Assert.AreEqual('Updated', FTarget.Text);
end;

procedure TTestBindingManager.Test_TwoWayBinding_TargetToSource;
begin
  FManager.Bind(FSource, 'Name', FTarget, 'Text', bmTwoWay);
  
  FTarget.Text := 'FromTarget';
  FManager.NotifyTargetChanged(FTarget, 'Text');
  
  Assert.AreEqual('FromTarget', FSource.Name);
end;

procedure TTestBindingManager.Test_OneTimeBinding_NoUpdatesAfterInit;
begin
  FSource.Name := 'Initial';
  FManager.Bind(FSource, 'Name', FTarget, 'Text', bmOneTime);
  
  Assert.AreEqual('Initial', FTarget.Text);
  
  FSource.Name := 'Updated';
  
  Assert.AreEqual('Initial', FTarget.Text); // Should not update
end;

procedure TTestBindingManager.Test_Unbind_StopsUpdates;
begin
  FManager.Bind(FSource, 'Name', FTarget, 'Text', bmOneWay);
  FSource.Name := 'First';
  Assert.AreEqual('First', FTarget.Text);
  
  FManager.Unbind(FSource, FTarget);
  FSource.Name := 'Second';
  
  Assert.AreEqual('First', FTarget.Text); // Should not update
end;

procedure TTestBindingManager.Test_UnbindAll_ClearsBindings;
begin
  FManager.Bind(FSource, 'Name', FTarget, 'Text', bmOneWay);
  FManager.Bind(FSource, 'Active', FTarget, 'Checked', bmOneWay);
  
  Assert.AreEqual(2, FManager.BindingCount);
  
  FManager.UnbindAll;
  
  Assert.AreEqual(0, FManager.BindingCount);
end;

procedure TTestBindingManager.Test_BindingCount_ReturnsCorrectCount;
begin
  Assert.AreEqual(0, FManager.BindingCount);
  
  FManager.Bind(FSource, 'Name', FTarget, 'Text', bmOneWay);
  Assert.AreEqual(1, FManager.BindingCount);
  
  FManager.Bind(FSource, 'Active', FTarget, 'Checked', bmOneWay);
  Assert.AreEqual(2, FManager.BindingCount);
end;

procedure TTestBindingManager.Test_ValueConverter_ConvertOnSync;
var
  Converter: IValueConverter;
begin
  Converter := TStringToUpperConverter.Create;
  
  FSource.Name := 'hello';
  FManager.Bind(FSource, 'Name', FTarget, 'Text', bmOneWay, Converter);
  
  Assert.AreEqual('HELLO', FTarget.Text);
  
  FSource.Name := 'world';
  Assert.AreEqual('WORLD', FTarget.Text);
end;

procedure TTestBindingManager.Test_ValueConverter_ConvertBackOnTwoWay;
var
  Converter: IValueConverter;
begin
  Converter := TStringToUpperConverter.Create;
  
  FManager.Bind(FSource, 'Name', FTarget, 'Text', bmTwoWay, Converter);
  
  FTarget.Text := 'HELLO';
  FManager.NotifyTargetChanged(FTarget, 'Text');
  
  Assert.AreEqual('hello', FSource.Name); // ConvertBack should lowercase
end;

procedure TTestBindingManager.Test_MultipleBindings_AllUpdate;
var
  Target2: TTestTarget;
begin
  Target2 := TTestTarget.Create;
  try
    FManager.Bind(FSource, 'Name', FTarget, 'Text', bmOneWay);
    FManager.Bind(FSource, 'Name', Target2, 'Text', bmOneWay);
    
    FSource.Name := 'Shared';
    
    Assert.AreEqual('Shared', FTarget.Text);
    Assert.AreEqual('Shared', Target2.Text);
  finally
    Target2.Free;
  end;
end;

procedure TTestBindingManager.Test_UpdateAllTargets_ForcesSync;
begin
  FSource.Name := 'Initial';
  FManager.Bind(FSource, 'Name', FTarget, 'Text', bmOneTime);
  
  Assert.AreEqual('Initial', FTarget.Text);
  
  // Directly change source without notification
  FSource.FName := 'Direct';
  
  FManager.UpdateAllTargets;
  
  Assert.AreEqual('Direct', FTarget.Text);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestObservableObject);
  TDUnitX.RegisterTestFixture(TTestObservableList);
  TDUnitX.RegisterTestFixture(TTestBindingManager);
  
end.
