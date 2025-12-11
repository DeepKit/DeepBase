unit Test.UniBase.Reflection;

{*******************************************************************************
  Unit Tests for UniBase.Reflection
  Tests RTTI utilities, property/field/method access, object utilities
*******************************************************************************}

interface

{$IFDEF TESTINSIGHT}
uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestReflection = class
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // TTypeInfo Tests
    [Test]
    procedure TestTypeInfoContext;
    [Test]
    procedure TestTypeInfoGetTypeByClass;
    [Test]
    procedure TestTypeInfoGetKind;
    [Test]
    procedure TestTypeInfoIsClass;
    [Test]
    procedure TestTypeInfoIsRecord;
    [Test]
    procedure TestTypeInfoIsString;
    [Test]
    procedure TestTypeInfoIsNumeric;
    [Test]
    procedure TestTypeInfoGetName;
    [Test]
    procedure TestTypeInfoGetSize;
    [Test]
    procedure TestTypeInfoIsAssignableFrom;
    [Test]
    procedure TestTypeInfoGetBaseTypes;

    // TPropertyAccess_ Tests
    [Test]
    procedure TestPropertyAccessGetValue;
    [Test]
    procedure TestPropertyAccessGetValueTyped;
    [Test]
    procedure TestPropertyAccessSetValue;
    [Test]
    procedure TestPropertyAccessTryGetValue;
    [Test]
    procedure TestPropertyAccessTrySetValue;
    [Test]
    procedure TestPropertyAccessHasProperty;
    [Test]
    procedure TestPropertyAccessGetPropertyInfo;
    [Test]
    procedure TestPropertyAccessGetProperties;
    [Test]
    procedure TestPropertyAccessGetPropertyNames;
    [Test]
    procedure TestPropertyAccessCopyProperties;
    [Test]
    procedure TestPropertyAccessCopyPropertiesWithExclude;
    [Test]
    procedure TestPropertyAccessGetValueNotFound;

    // TFieldAccess Tests
    [Test]
    procedure TestFieldAccessGetValue;
    [Test]
    procedure TestFieldAccessSetValue;
    [Test]
    procedure TestFieldAccessTryGetValue;
    [Test]
    procedure TestFieldAccessHasField;
    [Test]
    procedure TestFieldAccessGetFieldInfo;
    [Test]
    procedure TestFieldAccessGetFields;
    [Test]
    procedure TestFieldAccessGetValueNotFound;

    // TMethodInvoke Tests
    [Test]
    procedure TestMethodInvokeBasic;
    [Test]
    procedure TestMethodInvokeWithArgs;
    [Test]
    procedure TestMethodInvokeFunction;
    [Test]
    procedure TestMethodInvokeTryInvoke;
    [Test]
    procedure TestMethodInvokeHasMethod;
    [Test]
    procedure TestMethodInvokeGetMethodInfo;
    [Test]
    procedure TestMethodInvokeGetMethods;

    // TObjectUtils Tests
    [Test]
    procedure TestObjectUtilsClone;
    [Test]
    procedure TestObjectUtilsCloneNil;
    [Test]
    procedure TestObjectUtilsEquals;
    [Test]
    procedure TestObjectUtilsEqualsWithExclude;
    [Test]
    procedure TestObjectUtilsGetDifferences;
    [Test]
    procedure TestObjectUtilsToDictionary;
    [Test]
    procedure TestObjectUtilsFromDictionary;
    [Test]
    procedure TestObjectUtilsCreateInstance;
    [Test]
    procedure TestObjectUtilsSafeCast;

    // TTypeRegistry Tests
    [Test]
    procedure TestTypeRegistryRegister;
    [Test]
    procedure TestTypeRegistryCreateInstance;
    [Test]
    procedure TestTypeRegistryIsRegistered;
    [Test]
    procedure TestTypeRegistryGetClass;
    [Test]
    procedure TestTypeRegistryGetRegisteredNames;
    [Test]
    procedure TestTypeRegistryClear;

    // TEnumUtils Tests
    [Test]
    procedure TestEnumUtilsGetName;
    [Test]
    procedure TestEnumUtilsGetValue;
    [Test]
    procedure TestEnumUtilsTryGetValue;
    [Test]
    procedure TestEnumUtilsGetNames;
    [Test]
    procedure TestEnumUtilsGetValues;
    [Test]
    procedure TestEnumUtilsGetCount;
    [Test]
    procedure TestEnumUtilsGetOrdinal;

    // TReflect Shortcut Tests
    [Test]
    procedure TestReflectGetProp;
    [Test]
    procedure TestReflectSetProp;
    [Test]
    procedure TestReflectHasProp;
    [Test]
    procedure TestReflectCall;
    [Test]
    procedure TestReflectMake;
  end;
{$ENDIF}

implementation

{$IFDEF TESTINSIGHT}
uses
  System.SysUtils, System.Classes, System.Rtti, System.TypInfo,
  System.Generics.Collections,
  UniBase.Reflection;

type
  // Test enum
  TTestColor = (tcRed, tcGreen, tcBlue, tcYellow);

  // Test record
  TTestRecord = record
    X: Integer;
    Y: Integer;
  end;

  // Test class for reflection tests
  TTestPerson = class
  private
    FName: string;
    FAge: Integer;
    FActive: Boolean;
  public
    constructor Create; overload;
    constructor Create(const AName: string; AAge: Integer); overload;
    
    procedure SetName(const Value: string);
    function GetDescription: string;
    function Add(A, B: Integer): Integer;
    
    property Name: string read FName write FName;
    property Age: Integer read FAge write FAge;
    property Active: Boolean read FActive write FActive;
  end;

  // Derived class for inheritance tests
  TTestEmployee = class(TTestPerson)
  private
    FEmployeeId: string;
    FDepartment: string;
  public
    property EmployeeId: string read FEmployeeId write FEmployeeId;
    property Department: string read FDepartment write FDepartment;
  end;

{ TTestPerson }

constructor TTestPerson.Create;
begin
  inherited Create;
  FName := '';
  FAge := 0;
  FActive := True;
end;

constructor TTestPerson.Create(const AName: string; AAge: Integer);
begin
  inherited Create;
  FName := AName;
  FAge := AAge;
  FActive := True;
end;

procedure TTestPerson.SetName(const Value: string);
begin
  FName := Value;
end;

function TTestPerson.GetDescription: string;
begin
  Result := Format('%s (%d years old)', [FName, FAge]);
end;

function TTestPerson.Add(A, B: Integer): Integer;
begin
  Result := A + B;
end;

{ TTestReflection }

procedure TTestReflection.Setup;
begin
end;

procedure TTestReflection.TearDown;
begin
end;

// ============================================================================
// TTypeInfo Tests
// ============================================================================

procedure TTestReflection.TestTypeInfoContext;
var
  Ctx: TRttiContext;
begin
  Ctx := TTypeInfo.Context;
  Assert.IsNotNull(Ctx.GetType(TObject));
end;

procedure TTestReflection.TestTypeInfoGetTypeByClass;
var
  T: TRttiType;
begin
  T := TTypeInfo.GetTypeByClass(TTestPerson);
  Assert.IsNotNull(T);
  Assert.AreEqual('TTestPerson', T.Name);
end;

procedure TTestReflection.TestTypeInfoGetKind;
begin
  Assert.AreEqual(tkClass, TTypeInfo.GetKind<TTestPerson>);
  Assert.AreEqual(tkInteger, TTypeInfo.GetKind<Integer>);
  Assert.AreEqual(tkUString, TTypeInfo.GetKind<string>);
  Assert.AreEqual(tkFloat, TTypeInfo.GetKind<Double>);
  Assert.AreEqual(tkRecord, TTypeInfo.GetKind<TTestRecord>);
  Assert.AreEqual(tkEnumeration, TTypeInfo.GetKind<TTestColor>);
end;

procedure TTestReflection.TestTypeInfoIsClass;
begin
  Assert.IsTrue(TTypeInfo.IsClass<TTestPerson>);
  Assert.IsTrue(TTypeInfo.IsClass<TObject>);
  Assert.IsFalse(TTypeInfo.IsClass<Integer>);
  Assert.IsFalse(TTypeInfo.IsClass<string>);
end;

procedure TTestReflection.TestTypeInfoIsRecord;
begin
  Assert.IsTrue(TTypeInfo.IsRecord<TTestRecord>);
  Assert.IsFalse(TTypeInfo.IsRecord<TTestPerson>);
  Assert.IsFalse(TTypeInfo.IsRecord<Integer>);
end;

procedure TTestReflection.TestTypeInfoIsString;
begin
  Assert.IsTrue(TTypeInfo.IsString<string>);
  Assert.IsFalse(TTypeInfo.IsString<Integer>);
  Assert.IsFalse(TTypeInfo.IsString<TTestPerson>);
end;

procedure TTestReflection.TestTypeInfoIsNumeric;
begin
  Assert.IsTrue(TTypeInfo.IsNumeric<Integer>);
  Assert.IsTrue(TTypeInfo.IsNumeric<Double>);
  Assert.IsTrue(TTypeInfo.IsNumeric<Int64>);
  Assert.IsFalse(TTypeInfo.IsNumeric<string>);
  Assert.IsFalse(TTypeInfo.IsNumeric<Boolean>);
end;

procedure TTestReflection.TestTypeInfoGetName;
begin
  Assert.AreEqual('TTestPerson', TTypeInfo.GetName<TTestPerson>);
  Assert.AreEqual('Integer', TTypeInfo.GetName<Integer>);
  Assert.AreEqual('string', TTypeInfo.GetName<string>);
end;

procedure TTestReflection.TestTypeInfoGetSize;
begin
  Assert.AreEqual(SizeOf(Integer), TTypeInfo.GetSize<Integer>);
  Assert.AreEqual(SizeOf(Double), TTypeInfo.GetSize<Double>);
  Assert.AreEqual(SizeOf(TTestRecord), TTypeInfo.GetSize<TTestRecord>);
end;

procedure TTestReflection.TestTypeInfoIsAssignableFrom;
var
  TParent, TChild: TRttiType;
begin
  TParent := TTypeInfo.GetTypeByClass(TTestPerson);
  TChild := TTypeInfo.GetTypeByClass(TTestEmployee);
  
  Assert.IsTrue(TTypeInfo.IsAssignableFrom(TParent, TChild));
  Assert.IsFalse(TTypeInfo.IsAssignableFrom(TChild, TParent));
  Assert.IsTrue(TTypeInfo.IsAssignableFrom(TParent, TParent));
end;

procedure TTestReflection.TestTypeInfoGetBaseTypes;
var
  T: TRttiType;
  BaseTypes: TArray<TRttiType>;
begin
  T := TTypeInfo.GetTypeByClass(TTestEmployee);
  BaseTypes := TTypeInfo.GetBaseTypes(T);
  
  Assert.IsTrue(Length(BaseTypes) >= 2);
  Assert.AreEqual('TTestEmployee', BaseTypes[0].Name);
  Assert.AreEqual('TTestPerson', BaseTypes[1].Name);
end;

// ============================================================================
// TPropertyAccess_ Tests
// ============================================================================

procedure TTestReflection.TestPropertyAccessGetValue;
var
  Person: TTestPerson;
  V: TValue;
begin
  Person := TTestPerson.Create('Alice', 30);
  try
    V := TPropertyAccess_.GetValue(Person, 'Name');
    Assert.AreEqual('Alice', V.AsString);
    
    V := TPropertyAccess_.GetValue(Person, 'Age');
    Assert.AreEqual(30, V.AsInteger);
  finally
    Person.Free;
  end;
end;

procedure TTestReflection.TestPropertyAccessGetValueTyped;
var
  Person: TTestPerson;
begin
  Person := TTestPerson.Create('Bob', 25);
  try
    Assert.AreEqual('Bob', TPropertyAccess_.GetValue<string>(Person, 'Name'));
    Assert.AreEqual(25, TPropertyAccess_.GetValue<Integer>(Person, 'Age'));
    Assert.IsTrue(TPropertyAccess_.GetValue<Boolean>(Person, 'Active'));
  finally
    Person.Free;
  end;
end;

procedure TTestReflection.TestPropertyAccessSetValue;
var
  Person: TTestPerson;
begin
  Person := TTestPerson.Create;
  try
    TPropertyAccess_.SetValue(Person, 'Name', TValue.From<string>('Charlie'));
    TPropertyAccess_.SetValue(Person, 'Age', TValue.From<Integer>(35));
    
    Assert.AreEqual('Charlie', Person.Name);
    Assert.AreEqual(35, Person.Age);
  finally
    Person.Free;
  end;
end;

procedure TTestReflection.TestPropertyAccessTryGetValue;
var
  Person: TTestPerson;
  V: TValue;
begin
  Person := TTestPerson.Create('Dave', 40);
  try
    Assert.IsTrue(TPropertyAccess_.TryGetValue(Person, 'Name', V));
    Assert.AreEqual('Dave', V.AsString);
    
    Assert.IsFalse(TPropertyAccess_.TryGetValue(Person, 'NonExistent', V));
  finally
    Person.Free;
  end;
end;

procedure TTestReflection.TestPropertyAccessTrySetValue;
var
  Person: TTestPerson;
begin
  Person := TTestPerson.Create;
  try
    Assert.IsTrue(TPropertyAccess_.TrySetValue(Person, 'Name', TValue.From('Eve')));
    Assert.AreEqual('Eve', Person.Name);
    
    Assert.IsFalse(TPropertyAccess_.TrySetValue(Person, 'NonExistent', TValue.From('X')));
  finally
    Person.Free;
  end;
end;

procedure TTestReflection.TestPropertyAccessHasProperty;
var
  Person: TTestPerson;
begin
  Person := TTestPerson.Create;
  try
    Assert.IsTrue(TPropertyAccess_.HasProperty(Person, 'Name'));
    Assert.IsTrue(TPropertyAccess_.HasProperty(Person, 'Age'));
    Assert.IsTrue(TPropertyAccess_.HasProperty(Person, 'Active'));
    Assert.IsFalse(TPropertyAccess_.HasProperty(Person, 'NonExistent'));
  finally
    Person.Free;
  end;
end;

procedure TTestReflection.TestPropertyAccessGetPropertyInfo;
var
  Person: TTestPerson;
  Info: TPropertyInfoEx;
begin
  Person := TTestPerson.Create;
  try
    Info := TPropertyAccess_.GetPropertyInfo(Person, 'Name');
    Assert.AreEqual('Name', Info.Name);
    Assert.AreEqual('string', Info.TypeName);
    Assert.AreEqual(tkUString, Info.TypeKind);
    Assert.IsTrue(Info.IsReadable);
    Assert.IsTrue(Info.IsWritable);
  finally
    Person.Free;
  end;
end;

procedure TTestReflection.TestPropertyAccessGetProperties;
var
  Props: TArray<TPropertyInfoEx>;
  Names: TList<string>;
begin
  Props := TPropertyAccess_.GetProperties(TTestPerson);
  Names := TList<string>.Create;
  try
    for var P in Props do
      Names.Add(P.Name);
    
    Assert.IsTrue(Names.Contains('Name'));
    Assert.IsTrue(Names.Contains('Age'));
    Assert.IsTrue(Names.Contains('Active'));
  finally
    Names.Free;
  end;
end;

procedure TTestReflection.TestPropertyAccessGetPropertyNames;
var
  Person: TTestPerson;
  Names: TArray<string>;
  NameList: TList<string>;
begin
  Person := TTestPerson.Create;
  try
    Names := TPropertyAccess_.GetPropertyNames(Person);
    NameList := TList<string>.Create;
    try
      NameList.AddRange(Names);
      Assert.IsTrue(NameList.Contains('Name'));
      Assert.IsTrue(NameList.Contains('Age'));
    finally
      NameList.Free;
    end;
  finally
    Person.Free;
  end;
end;

procedure TTestReflection.TestPropertyAccessCopyProperties;
var
  Source, Target: TTestPerson;
begin
  Source := TTestPerson.Create('Frank', 50);
  Target := TTestPerson.Create;
  try
    TPropertyAccess_.CopyProperties(Source, Target);
    
    Assert.AreEqual('Frank', Target.Name);
    Assert.AreEqual(50, Target.Age);
    Assert.AreEqual(Source.Active, Target.Active);
  finally
    Source.Free;
    Target.Free;
  end;
end;

procedure TTestReflection.TestPropertyAccessCopyPropertiesWithExclude;
var
  Source, Target: TTestPerson;
begin
  Source := TTestPerson.Create('Grace', 45);
  Target := TTestPerson.Create('Original', 0);
  try
    TPropertyAccess_.CopyProperties(Source, Target, ['Name']);
    
    Assert.AreEqual('Original', Target.Name);  // Excluded
    Assert.AreEqual(45, Target.Age);           // Copied
  finally
    Source.Free;
    Target.Free;
  end;
end;

procedure TTestReflection.TestPropertyAccessGetValueNotFound;
var
  Person: TTestPerson;
begin
  Person := TTestPerson.Create;
  try
    Assert.WillRaise(
      procedure
      begin
        TPropertyAccess_.GetValue(Person, 'NonExistent');
      end,
      EReflectionException
    );
  finally
    Person.Free;
  end;
end;

// ============================================================================
// TFieldAccess Tests
// ============================================================================

procedure TTestReflection.TestFieldAccessGetValue;
var
  Person: TTestPerson;
  V: TValue;
begin
  Person := TTestPerson.Create('Henry', 55);
  try
    V := TFieldAccess.GetValue(Person, 'FName');
    Assert.AreEqual('Henry', V.AsString);
    
    V := TFieldAccess.GetValue(Person, 'FAge');
    Assert.AreEqual(55, V.AsInteger);
  finally
    Person.Free;
  end;
end;

procedure TTestReflection.TestFieldAccessSetValue;
var
  Person: TTestPerson;
begin
  Person := TTestPerson.Create;
  try
    TFieldAccess.SetValue(Person, 'FName', TValue.From<string>('Irene'));
    TFieldAccess.SetValue(Person, 'FAge', TValue.From<Integer>(60));
    
    Assert.AreEqual('Irene', Person.Name);
    Assert.AreEqual(60, Person.Age);
  finally
    Person.Free;
  end;
end;

procedure TTestReflection.TestFieldAccessTryGetValue;
var
  Person: TTestPerson;
  V: TValue;
begin
  Person := TTestPerson.Create('Jack', 65);
  try
    Assert.IsTrue(TFieldAccess.TryGetValue(Person, 'FName', V));
    Assert.AreEqual('Jack', V.AsString);
    
    Assert.IsFalse(TFieldAccess.TryGetValue(Person, 'FNonExistent', V));
  finally
    Person.Free;
  end;
end;

procedure TTestReflection.TestFieldAccessHasField;
var
  Person: TTestPerson;
begin
  Person := TTestPerson.Create;
  try
    Assert.IsTrue(TFieldAccess.HasField(Person, 'FName'));
    Assert.IsTrue(TFieldAccess.HasField(Person, 'FAge'));
    Assert.IsFalse(TFieldAccess.HasField(Person, 'FNonExistent'));
  finally
    Person.Free;
  end;
end;

procedure TTestReflection.TestFieldAccessGetFieldInfo;
var
  Person: TTestPerson;
  Info: TFieldInfoEx;
begin
  Person := TTestPerson.Create;
  try
    Info := TFieldAccess.GetFieldInfo(Person, 'FName');
    Assert.AreEqual('FName', Info.Name);
    Assert.AreEqual('string', Info.TypeName);
    Assert.AreEqual(tkUString, Info.TypeKind);
  finally
    Person.Free;
  end;
end;

procedure TTestReflection.TestFieldAccessGetFields;
var
  Fields: TArray<TFieldInfoEx>;
  Names: TList<string>;
begin
  Fields := TFieldAccess.GetFields(TTestPerson, [mvPrivate]);
  Names := TList<string>.Create;
  try
    for var F in Fields do
      Names.Add(F.Name);
    
    Assert.IsTrue(Names.Contains('FName'));
    Assert.IsTrue(Names.Contains('FAge'));
    Assert.IsTrue(Names.Contains('FActive'));
  finally
    Names.Free;
  end;
end;

procedure TTestReflection.TestFieldAccessGetValueNotFound;
var
  Person: TTestPerson;
begin
  Person := TTestPerson.Create;
  try
    Assert.WillRaise(
      procedure
      begin
        TFieldAccess.GetValue(Person, 'FNonExistent');
      end,
      EReflectionException
    );
  finally
    Person.Free;
  end;
end;

// ============================================================================
// TMethodInvoke Tests
// ============================================================================

procedure TTestReflection.TestMethodInvokeBasic;
var
  Person: TTestPerson;
begin
  Person := TTestPerson.Create;
  try
    TMethodInvoke.Invoke(Person, 'SetName', [TValue.From('Kate')]);
    Assert.AreEqual('Kate', Person.Name);
  finally
    Person.Free;
  end;
end;

procedure TTestReflection.TestMethodInvokeWithArgs;
var
  Person: TTestPerson;
  Result: TValue;
begin
  Person := TTestPerson.Create;
  try
    Result := TMethodInvoke.Invoke(Person, 'Add', [TValue.From(10), TValue.From(20)]);
    Assert.AreEqual(30, Result.AsInteger);
  finally
    Person.Free;
  end;
end;

procedure TTestReflection.TestMethodInvokeFunction;
var
  Person: TTestPerson;
  Result: TValue;
begin
  Person := TTestPerson.Create('Leo', 70);
  try
    Result := TMethodInvoke.Invoke(Person, 'GetDescription', []);
    Assert.AreEqual('Leo (70 years old)', Result.AsString);
  finally
    Person.Free;
  end;
end;

procedure TTestReflection.TestMethodInvokeTryInvoke;
var
  Person: TTestPerson;
  Result: TValue;
begin
  Person := TTestPerson.Create('Mary', 75);
  try
    Assert.IsTrue(TMethodInvoke.TryInvoke(Person, 'GetDescription', [], Result));
    Assert.AreEqual('Mary (75 years old)', Result.AsString);
    
    Assert.IsFalse(TMethodInvoke.TryInvoke(Person, 'NonExistent', [], Result));
  finally
    Person.Free;
  end;
end;

procedure TTestReflection.TestMethodInvokeHasMethod;
var
  Person: TTestPerson;
begin
  Person := TTestPerson.Create;
  try
    Assert.IsTrue(TMethodInvoke.HasMethod(Person, 'SetName'));
    Assert.IsTrue(TMethodInvoke.HasMethod(Person, 'GetDescription'));
    Assert.IsTrue(TMethodInvoke.HasMethod(Person, 'Add'));
    Assert.IsFalse(TMethodInvoke.HasMethod(Person, 'NonExistent'));
  finally
    Person.Free;
  end;
end;

procedure TTestReflection.TestMethodInvokeGetMethodInfo;
var
  Person: TTestPerson;
  Info: TMethodInfoEx;
begin
  Person := TTestPerson.Create;
  try
    Info := TMethodInvoke.GetMethodInfo(Person, 'Add');
    Assert.AreEqual('Add', Info.Name);
    Assert.IsTrue(Info.IsFunction);
    Assert.AreEqual('Integer', Info.ReturnType);
    Assert.AreEqual(2, Info.ParameterCount);
  finally
    Person.Free;
  end;
end;

procedure TTestReflection.TestMethodInvokeGetMethods;
var
  Methods: TArray<TMethodInfoEx>;
  Names: TList<string>;
begin
  Methods := TMethodInvoke.GetMethods(TTestPerson);
  Names := TList<string>.Create;
  try
    for var M in Methods do
      Names.Add(M.Name);
    
    Assert.IsTrue(Names.Contains('SetName'));
    Assert.IsTrue(Names.Contains('GetDescription'));
    Assert.IsTrue(Names.Contains('Add'));
  finally
    Names.Free;
  end;
end;

// ============================================================================
// TObjectUtils Tests
// ============================================================================

procedure TTestReflection.TestObjectUtilsClone;
var
  Source, Clone: TTestPerson;
begin
  Source := TTestPerson.Create('Nancy', 80);
  try
    Clone := TObjectUtils.Clone<TTestPerson>(Source);
    try
      Assert.AreEqual(Source.Name, Clone.Name);
      Assert.AreEqual(Source.Age, Clone.Age);
      Assert.AreEqual(Source.Active, Clone.Active);
      Assert.AreNotEqual(NativeInt(Source), NativeInt(Clone));
    finally
      Clone.Free;
    end;
  finally
    Source.Free;
  end;
end;

procedure TTestReflection.TestObjectUtilsCloneNil;
var
  Clone: TTestPerson;
begin
  Clone := TObjectUtils.Clone<TTestPerson>(nil);
  Assert.IsNull(Clone);
end;

procedure TTestReflection.TestObjectUtilsEquals;
var
  P1, P2, P3: TTestPerson;
begin
  P1 := TTestPerson.Create('Oscar', 85);
  P2 := TTestPerson.Create('Oscar', 85);
  P3 := TTestPerson.Create('Peter', 90);
  try
    Assert.IsTrue(TObjectUtils.Equals(P1, P2));
    Assert.IsFalse(TObjectUtils.Equals(P1, P3));
    Assert.IsTrue(TObjectUtils.Equals(nil, nil));
    Assert.IsFalse(TObjectUtils.Equals(P1, nil));
  finally
    P1.Free;
    P2.Free;
    P3.Free;
  end;
end;

procedure TTestReflection.TestObjectUtilsEqualsWithExclude;
var
  P1, P2: TTestPerson;
begin
  P1 := TTestPerson.Create('Quinn', 91);
  P2 := TTestPerson.Create('Quinn', 99);  // Different age
  try
    Assert.IsFalse(TObjectUtils.Equals(P1, P2));
    Assert.IsTrue(TObjectUtils.Equals(P1, P2, ['Age']));
  finally
    P1.Free;
    P2.Free;
  end;
end;

procedure TTestReflection.TestObjectUtilsGetDifferences;
var
  P1, P2: TTestPerson;
  Diffs: TArray<string>;
  DiffList: TList<string>;
begin
  P1 := TTestPerson.Create('Rose', 92);
  P2 := TTestPerson.Create('Rose', 99);
  try
    Diffs := TObjectUtils.GetDifferences(P1, P2);
    DiffList := TList<string>.Create;
    try
      DiffList.AddRange(Diffs);
      Assert.IsTrue(DiffList.Contains('Age'));
      Assert.IsFalse(DiffList.Contains('Name'));
    finally
      DiffList.Free;
    end;
  finally
    P1.Free;
    P2.Free;
  end;
end;

procedure TTestReflection.TestObjectUtilsToDictionary;
var
  Person: TTestPerson;
  Dict: TDictionary<string, TValue>;
begin
  Person := TTestPerson.Create('Sam', 93);
  try
    Dict := TObjectUtils.ToDictionary(Person);
    try
      Assert.IsTrue(Dict.ContainsKey('Name'));
      Assert.IsTrue(Dict.ContainsKey('Age'));
      Assert.AreEqual('Sam', Dict['Name'].AsString);
      Assert.AreEqual(93, Dict['Age'].AsInteger);
    finally
      Dict.Free;
    end;
  finally
    Person.Free;
  end;
end;

procedure TTestReflection.TestObjectUtilsFromDictionary;
var
  Person: TTestPerson;
  Dict: TDictionary<string, TValue>;
begin
  Person := TTestPerson.Create;
  Dict := TDictionary<string, TValue>.Create;
  try
    Dict.Add('Name', TValue.From('Tina'));
    Dict.Add('Age', TValue.From(94));
    
    TObjectUtils.FromDictionary(Person, Dict);
    
    Assert.AreEqual('Tina', Person.Name);
    Assert.AreEqual(94, Person.Age);
  finally
    Person.Free;
    Dict.Free;
  end;
end;

procedure TTestReflection.TestObjectUtilsCreateInstance;
var
  Person: TTestPerson;
begin
  Person := TObjectUtils.CreateInstance<TTestPerson>;
  try
    Assert.IsNotNull(Person);
    Assert.AreEqual('', Person.Name);
    Assert.AreEqual(0, Person.Age);
  finally
    Person.Free;
  end;
end;

procedure TTestReflection.TestObjectUtilsSafeCast;
var
  Obj: TObject;
  Person: TTestPerson;
begin
  Obj := TTestPerson.Create('Uma', 95);
  try
    Person := TObjectUtils.SafeCast<TTestPerson>(Obj);
    Assert.IsNotNull(Person);
    Assert.AreEqual('Uma', Person.Name);
    
    Assert.IsNull(TObjectUtils.SafeCast<TTestEmployee>(Obj));
  finally
    Obj.Free;
  end;
end;

// ============================================================================
// TTypeRegistry Tests
// ============================================================================

procedure TTestReflection.TestTypeRegistryRegister;
begin
  TTypeRegistry.Clear;
  TTypeRegistry.RegisterType('Person', TTestPerson);
  
  Assert.IsTrue(TTypeRegistry.IsRegistered('Person'));
  Assert.IsFalse(TTypeRegistry.IsRegistered('Unknown'));
end;

procedure TTestReflection.TestTypeRegistryCreateInstance;
var
  Obj: TObject;
begin
  TTypeRegistry.Clear;
  TTypeRegistry.RegisterType('Person', TTestPerson);
  
  Obj := TTypeRegistry.CreateInstance('Person');
  try
    Assert.IsNotNull(Obj);
    Assert.IsTrue(Obj is TTestPerson);
  finally
    Obj.Free;
  end;
end;

procedure TTestReflection.TestTypeRegistryIsRegistered;
begin
  TTypeRegistry.Clear;
  TTypeRegistry.RegisterType('TestClass', TTestPerson);
  
  Assert.IsTrue(TTypeRegistry.IsRegistered('TestClass'));
  Assert.IsFalse(TTypeRegistry.IsRegistered('NonExistent'));
end;

procedure TTestReflection.TestTypeRegistryGetClass;
var
  C: TClass;
begin
  TTypeRegistry.Clear;
  TTypeRegistry.RegisterType('MyPerson', TTestPerson);
  
  C := TTypeRegistry.GetClass('MyPerson');
  Assert.AreEqual(TTestPerson, C);
end;

procedure TTestReflection.TestTypeRegistryGetRegisteredNames;
var
  Names: TArray<string>;
  NameList: TList<string>;
begin
  TTypeRegistry.Clear;
  TTypeRegistry.RegisterType('A', TTestPerson);
  TTypeRegistry.RegisterType('B', TTestEmployee);
  
  Names := TTypeRegistry.GetRegisteredNames;
  NameList := TList<string>.Create;
  try
    NameList.AddRange(Names);
    Assert.IsTrue(NameList.Contains('A'));
    Assert.IsTrue(NameList.Contains('B'));
  finally
    NameList.Free;
  end;
end;

procedure TTestReflection.TestTypeRegistryClear;
begin
  TTypeRegistry.RegisterType('ToDelete', TTestPerson);
  Assert.IsTrue(TTypeRegistry.IsRegistered('ToDelete'));
  
  TTypeRegistry.Clear;
  Assert.IsFalse(TTypeRegistry.IsRegistered('ToDelete'));
end;

// ============================================================================
// TEnumUtils Tests
// ============================================================================

procedure TTestReflection.TestEnumUtilsGetName;
begin
  Assert.AreEqual('tcRed', TEnumUtils.GetName<TTestColor>(tcRed));
  Assert.AreEqual('tcGreen', TEnumUtils.GetName<TTestColor>(tcGreen));
  Assert.AreEqual('tcBlue', TEnumUtils.GetName<TTestColor>(tcBlue));
end;

procedure TTestReflection.TestEnumUtilsGetValue;
begin
  Assert.AreEqual(tcRed, TEnumUtils.GetValue<TTestColor>('tcRed'));
  Assert.AreEqual(tcGreen, TEnumUtils.GetValue<TTestColor>('tcGreen'));
  Assert.AreEqual(tcBlue, TEnumUtils.GetValue<TTestColor>('tcBlue'));
end;

procedure TTestReflection.TestEnumUtilsTryGetValue;
var
  Value: TTestColor;
begin
  Assert.IsTrue(TEnumUtils.TryGetValue<TTestColor>('tcRed', Value));
  Assert.AreEqual(tcRed, Value);
  
  Assert.IsFalse(TEnumUtils.TryGetValue<TTestColor>('Invalid', Value));
end;

procedure TTestReflection.TestEnumUtilsGetNames;
var
  Names: TArray<string>;
  NameList: TList<string>;
begin
  Names := TEnumUtils.GetNames<TTestColor>;
  NameList := TList<string>.Create;
  try
    NameList.AddRange(Names);
    Assert.IsTrue(NameList.Contains('tcRed'));
    Assert.IsTrue(NameList.Contains('tcGreen'));
    Assert.IsTrue(NameList.Contains('tcBlue'));
    Assert.IsTrue(NameList.Contains('tcYellow'));
  finally
    NameList.Free;
  end;
end;

procedure TTestReflection.TestEnumUtilsGetValues;
var
  Values: TArray<TTestColor>;
  ValueList: TList<TTestColor>;
begin
  Values := TEnumUtils.GetValues<TTestColor>;
  ValueList := TList<TTestColor>.Create;
  try
    ValueList.AddRange(Values);
    Assert.IsTrue(ValueList.Contains(tcRed));
    Assert.IsTrue(ValueList.Contains(tcGreen));
    Assert.IsTrue(ValueList.Contains(tcBlue));
    Assert.IsTrue(ValueList.Contains(tcYellow));
  finally
    ValueList.Free;
  end;
end;

procedure TTestReflection.TestEnumUtilsGetCount;
begin
  Assert.AreEqual(4, TEnumUtils.GetCount<TTestColor>);
end;

procedure TTestReflection.TestEnumUtilsGetOrdinal;
begin
  Assert.AreEqual(0, TEnumUtils.GetOrdinal<TTestColor>(tcRed));
  Assert.AreEqual(1, TEnumUtils.GetOrdinal<TTestColor>(tcGreen));
  Assert.AreEqual(2, TEnumUtils.GetOrdinal<TTestColor>(tcBlue));
  Assert.AreEqual(3, TEnumUtils.GetOrdinal<TTestColor>(tcYellow));
end;

// ============================================================================
// TReflect Shortcut Tests
// ============================================================================

procedure TTestReflection.TestReflectGetProp;
var
  Person: TTestPerson;
begin
  Person := TTestPerson.Create('Victor', 96);
  try
    Assert.AreEqual('Victor', TReflect.GetProp<string>(Person, 'Name'));
    Assert.AreEqual(96, TReflect.GetProp<Integer>(Person, 'Age'));
  finally
    Person.Free;
  end;
end;

procedure TTestReflection.TestReflectSetProp;
var
  Person: TTestPerson;
begin
  Person := TTestPerson.Create;
  try
    TReflect.SetProp<string>(Person, 'Name', 'Wendy');
    TReflect.SetProp<Integer>(Person, 'Age', 97);
    
    Assert.AreEqual('Wendy', Person.Name);
    Assert.AreEqual(97, Person.Age);
  finally
    Person.Free;
  end;
end;

procedure TTestReflection.TestReflectHasProp;
var
  Person: TTestPerson;
begin
  Person := TTestPerson.Create;
  try
    Assert.IsTrue(TReflect.HasProp(Person, 'Name'));
    Assert.IsTrue(TReflect.HasProp(Person, 'Age'));
    Assert.IsFalse(TReflect.HasProp(Person, 'NonExistent'));
  finally
    Person.Free;
  end;
end;

procedure TTestReflection.TestReflectCall;
var
  Person: TTestPerson;
  Result: TValue;
begin
  Person := TTestPerson.Create('Xavier', 98);
  try
    Result := TReflect.Call(Person, 'Add', [TValue.From(5), TValue.From(7)]);
    Assert.AreEqual(12, Result.AsInteger);
  finally
    Person.Free;
  end;
end;

procedure TTestReflection.TestReflectMake;
var
  Person: TTestPerson;
begin
  Person := TReflect.Make<TTestPerson>;
  try
    Assert.IsNotNull(Person);
    Assert.AreEqual('', Person.Name);
  finally
    Person.Free;
  end;
end;

{$ENDIF}

end.
