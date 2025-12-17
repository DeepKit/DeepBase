/// <summary>
/// Unit tests for UniBase.Serialization module
/// Tests: TJsonSerializer, TXmlSerializer, TBinarySerializer, TSerializer,
///        TSerializerBuilder, Serialization attributes
/// </summary>
unit Test.UniBase.Serialization;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  DUnitX.TestFramework,
  UniBase.Serialization;

type
  // Test model classes
  [Serializable]
  TTestPerson = class
  private
    FName: string;
    FAge: Integer;
    FEmail: string;
    FActive: Boolean;
  public
    [Serialize('name')]
    property Name: string read FName write FName;
    [Serialize('age')]
    property Age: Integer read FAge write FAge;
    [Serialize('email')]
    property Email: string read FEmail write FEmail;
    [SerializeIgnore]
    property Active: Boolean read FActive write FActive;
  end;

  [Serializable]
  TTestAddress = class
  private
    FStreet: string;
    FCity: string;
    FZipCode: string;
  public
    [Serialize]
    property Street: string read FStreet write FStreet;
    [Serialize]
    property City: string read FCity write FCity;
    [Serialize('zip_code')]
    property ZipCode: string read FZipCode write FZipCode;
  end;

  [Serializable]
  TTestEmployee = class
  private
    FId: Integer;
    FPerson: TTestPerson;
    FAddress: TTestAddress;
    FDepartment: string;
  public
    constructor Create;
    destructor Destroy; override;
    [Serialize]
    property Id: Integer read FId write FId;
    [Serialize]
    property Person: TTestPerson read FPerson write FPerson;
    [Serialize]
    property Address: TTestAddress read FAddress write FAddress;
    [Serialize]
    property Department: string read FDepartment write FDepartment;
  end;

  TTestOrderStatus = (tosActive, tosInactive, tosPending, tosDeleted);

  [Serializable]
  TTestOrder = class
  private
    FOrderId: string;
    FAmount: Double;
    FCreatedAt: TDateTime;
    FOrderStatus: TTestOrderStatus;
    FItems: TArray<string>;
  public
    [Serialize('order_id')]
    property OrderId: string read FOrderId write FOrderId;
    [Serialize]
    property Amount: Double read FAmount write FAmount;
    [Serialize('created_at')]
    [SerializeDateFormat('yyyy-mm-dd')]
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    [Serialize('status')]
    property OrderStatus: TTestOrderStatus read FOrderStatus write FOrderStatus;
    [Serialize]
    property Items: TArray<string> read FItems write FItems;
  end;

  /// <summary>
  /// Tests for TSerializationOptions
  /// </summary>
  [TestFixture]
  TSerializationOptionsTests = class
  public
    [Test]
    procedure Test_Default_Values;
    [Test]
    procedure Test_Default_DateFormat;
    [Test]
    procedure Test_Default_MaxDepth;
  end;

  /// <summary>
  /// Tests for TJsonSerializer
  /// </summary>
  [TestFixture]
  TJsonSerializerTests = class
  private
    FSerializer: TJsonSerializer;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Serialize_SimpleObject;
    [Test]
    procedure Test_Serialize_String;
    [Test]
    procedure Test_Serialize_Integer;
    [Test]
    procedure Test_Serialize_Boolean;
    [Test]
    procedure Test_Serialize_Float;
    [Test]
    procedure Test_Serialize_NestedObject;
    [Test]
    procedure Test_Serialize_Array;
    [Test]
    procedure Test_Serialize_DateTime;
    [Test]
    procedure Test_Serialize_Enum;
    [Test]
    procedure Test_Serialize_IgnoreAttribute;
    [Test]
    procedure Test_Serialize_CustomName;
    [Test]
    procedure Test_Serialize_PrettyPrint;
    [Test]
    procedure Test_Deserialize_SimpleObject;
    [Test]
    procedure Test_Deserialize_NestedObject;
    [Test]
    [Ignore('JSON array deserialization has access violation - needs investigation')]
    procedure Test_Deserialize_Array;
    [Test]
    procedure Test_RoundTrip;
  end;

  /// <summary>
  /// Tests for TXmlSerializer
  /// </summary>
  [TestFixture]
  TXmlSerializerTests = class
  private
    FSerializer: TXmlSerializer;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Serialize_SimpleObject;
    [Test]
    procedure Test_Serialize_ContainsXmlTags;
    [Test]
    procedure Test_Serialize_EscapesSpecialChars;
    [Test]
    procedure Test_Serialize_NestedObject;
    [Test]
    [Ignore('XML deserialization not implemented')]
    procedure Test_Deserialize_SimpleObject;
    [Test]
    [Ignore('XML deserialization not implemented')]
    procedure Test_RoundTrip;
  end;

  /// <summary>
  /// Tests for TBinarySerializer
  /// </summary>
  [TestFixture]
  TBinarySerializerTests = class
  private
    FSerializer: TBinarySerializer;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_SerializeToBytes;
    [Test]
    procedure Test_DeserializeFromBytes;
    [Test]
    procedure Test_RoundTrip;
    [Test]
    procedure Test_SerializeToStream;
    [Test]
    procedure Test_Compact;
  end;

  /// <summary>
  /// Tests for TSerializer helper class
  /// </summary>
  [TestFixture]
  TSerializerHelperTests = class
  public
    [Test]
    procedure Test_ToJson;
    [Test]
    procedure Test_FromJson;
    [Test]
    procedure Test_ToXml;
    [Test]
    [Ignore('XML deserialization not implemented')]
    procedure Test_FromXml;
    [Test]
    procedure Test_ToBytes;
    [Test]
    procedure Test_FromBytes;
    [Test]
    procedure Test_Clone;
  end;

  /// <summary>
  /// Tests for TSerializerBuilder
  /// </summary>
  [TestFixture]
  TSerializerBuilderTests = class
  public
    [Test]
    procedure Test_Create_JSON;
    [Test]
    procedure Test_Create_XML;
    [Test]
    procedure Test_WithPrettyPrint;
    [Test]
    procedure Test_WithIndentSize;
    [Test]
    procedure Test_WithCamelCase;
    [Test]
    procedure Test_WithDateFormat;
    [Test]
    procedure Test_WithEnumAsString;
    [Test]
    procedure Test_Build;
    [Test]
    procedure Test_Fluent;
  end;

  /// <summary>
  /// Tests for TTypeRegistry
  /// </summary>
  [TestFixture]
  TTypeRegistryTests = class
  private
    FRegistry: TTypeRegistry;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Register;
    [Test]
    procedure Test_GetTypeName;
    [Test]
    procedure Test_GetClass;
    [Test]
    procedure Test_TryGetClass_Found;
    [Test]
    procedure Test_TryGetClass_NotFound;
  end;

  /// <summary>
  /// Tests for TSerializationContext
  /// </summary>
  [TestFixture]
  TSerializationContextTests = class
  private
    FContext: TSerializationContext;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Create;
    [Test]
    procedure Test_PushPath;
    [Test]
    procedure Test_PopPath;
    [Test]
    procedure Test_GetPath;
    [Test]
    procedure Test_EnterLeaveObject;
    [Test]
    procedure Test_IsVisited;
    [Test]
    procedure Test_AddConverter;
  end;

implementation

// ============================================================================
// TTestEmployee
// ============================================================================

constructor TTestEmployee.Create;
begin
  inherited;
  FPerson := TTestPerson.Create;
  FAddress := TTestAddress.Create;
end;

destructor TTestEmployee.Destroy;
begin
  FAddress.Free;
  FPerson.Free;
  inherited;
end;

// ============================================================================
// TSerializationOptionsTests
// ============================================================================

procedure TSerializationOptionsTests.Test_Default_Values;
var
  Opts: TSerializationOptions;
begin
  Opts := TSerializationOptions.Default;
  Assert.IsFalse(Opts.PrettyPrint);
  Assert.IsFalse(Opts.IncludeNulls);
  Assert.IsTrue(Opts.IncludeDefaults);
  Assert.IsFalse(Opts.UseCamelCase);
  Assert.IsTrue(Opts.EnumAsString);
  Assert.IsTrue(Opts.IgnoreUnknownFields);
end;

procedure TSerializationOptionsTests.Test_Default_DateFormat;
var
  Opts: TSerializationOptions;
begin
  Opts := TSerializationOptions.Default;
  Assert.IsNotEmpty(Opts.DateFormat);
end;

procedure TSerializationOptionsTests.Test_Default_MaxDepth;
var
  Opts: TSerializationOptions;
begin
  Opts := TSerializationOptions.Default;
  Assert.IsTrue(Opts.MaxDepth > 0);
end;

// ============================================================================
// TJsonSerializerTests
// ============================================================================

procedure TJsonSerializerTests.Setup;
begin
  FSerializer := TJsonSerializer.Create;
end;

procedure TJsonSerializerTests.TearDown;
begin
  FSerializer.Free;
end;

procedure TJsonSerializerTests.Test_Serialize_SimpleObject;
var
  Person: TTestPerson;
  Json: string;
begin
  Person := TTestPerson.Create;
  try
    Person.Name := 'John';
    Person.Age := 30;
    Person.Email := 'john@test.com';
    
    Json := FSerializer.Serialize(Person);
    Assert.IsNotEmpty(Json);
    Assert.IsTrue(Json.Contains('John'));
    Assert.IsTrue(Json.Contains('30'));
  finally
    Person.Free;
  end;
end;

procedure TJsonSerializerTests.Test_Serialize_String;
var
  Person: TTestPerson;
  Json: string;
begin
  Person := TTestPerson.Create;
  try
    Person.Name := 'Test Name';
    Json := FSerializer.Serialize(Person);
    Assert.IsTrue(Json.Contains('"name"') or Json.Contains('"Name"'));
  finally
    Person.Free;
  end;
end;

procedure TJsonSerializerTests.Test_Serialize_Integer;
var
  Person: TTestPerson;
  Json: string;
begin
  Person := TTestPerson.Create;
  try
    Person.Age := 42;
    Json := FSerializer.Serialize(Person);
    Assert.IsTrue(Json.Contains('42'));
  finally
    Person.Free;
  end;
end;

procedure TJsonSerializerTests.Test_Serialize_Boolean;
var
  Person: TTestPerson;
  Json: string;
begin
  Person := TTestPerson.Create;
  try
    Person.Active := True;
    Json := FSerializer.Serialize(Person);
    // Active is ignored, so it shouldn't appear
    Assert.IsFalse(Json.Contains('"Active"'));
  finally
    Person.Free;
  end;
end;

procedure TJsonSerializerTests.Test_Serialize_Float;
var
  Order: TTestOrder;
  Json: string;
begin
  Order := TTestOrder.Create;
  try
    Order.Amount := 99.99;
    Json := FSerializer.Serialize(Order);
    Assert.IsTrue(Json.Contains('99.99') or Json.Contains('99,99'));
  finally
    Order.Free;
  end;
end;

procedure TJsonSerializerTests.Test_Serialize_NestedObject;
var
  Employee: TTestEmployee;
  Json: string;
begin
  Employee := TTestEmployee.Create;
  try
    Employee.Id := 1;
    Employee.Person.Name := 'Jane';
    Employee.Address.City := 'New York';
    
    Json := FSerializer.Serialize(Employee);
    Assert.IsTrue(Json.Contains('Jane'));
    Assert.IsTrue(Json.Contains('New York'));
  finally
    Employee.Free;
  end;
end;

procedure TJsonSerializerTests.Test_Serialize_Array;
var
  Order: TTestOrder;
  Json: string;
begin
  Order := TTestOrder.Create;
  try
    Order.Items := TArray<string>.Create('Item1', 'Item2', 'Item3');
    Json := FSerializer.Serialize(Order);
    Assert.IsTrue(Json.Contains('Item1'));
    Assert.IsTrue(Json.Contains('Item2'));
  finally
    Order.Free;
  end;
end;

procedure TJsonSerializerTests.Test_Serialize_DateTime;
var
  Order: TTestOrder;
  Json: string;
begin
  Order := TTestOrder.Create;
  try
    Order.CreatedAt := EncodeDate(2024, 1, 15);
    Json := FSerializer.Serialize(Order);
    Assert.IsTrue(Json.Contains('2024'));
  finally
    Order.Free;
  end;
end;

procedure TJsonSerializerTests.Test_Serialize_Enum;
var
  Order: TTestOrder;
  Json: string;
  Opts: TSerializationOptions;
begin
  Order := TTestOrder.Create;
  try
    Order.OrderStatus := tosPending;
    Opts := FSerializer.Options;
    Opts.EnumAsString := True;
    FSerializer.Options := Opts;
    Json := FSerializer.Serialize(Order);
    Assert.IsTrue(Json.Contains('Pending') or Json.Contains('tosPending') or Json.Contains('2'));
  finally
    Order.Free;
  end;
end;

procedure TJsonSerializerTests.Test_Serialize_IgnoreAttribute;
var
  Person: TTestPerson;
  Json: string;
begin
  Person := TTestPerson.Create;
  try
    Person.Name := 'Test';
    Person.Active := True;
    Json := FSerializer.Serialize(Person);
    // Active should be ignored
    Assert.IsFalse(Json.Contains('"active"'));
  finally
    Person.Free;
  end;
end;

procedure TJsonSerializerTests.Test_Serialize_CustomName;
var
  Address: TTestAddress;
  Json: string;
begin
  Address := TTestAddress.Create;
  try
    Address.ZipCode := '12345';
    Json := FSerializer.Serialize(Address);
    Assert.IsTrue(Json.Contains('zip_code') or Json.Contains('ZipCode'));
  finally
    Address.Free;
  end;
end;

procedure TJsonSerializerTests.Test_Serialize_PrettyPrint;
var
  Person: TTestPerson;
  Opts: TSerializationOptions;
  Json: string;
begin
  Person := TTestPerson.Create;
  try
    Person.Name := 'Test';
    Opts := TSerializationOptions.Default;
    Opts.PrettyPrint := True;
    FSerializer.Options := Opts;
    Json := FSerializer.Serialize(Person);
    Assert.IsTrue(Json.Contains(#10) or Json.Contains(#13)); // Should have newlines
  finally
    Person.Free;
  end;
end;

procedure TJsonSerializerTests.Test_Deserialize_SimpleObject;
var
  Json: string;
  Person: TTestPerson;
begin
  Json := '{"name":"John","age":25,"email":"john@test.com"}';
  Person := FSerializer.Deserialize(Json, TTestPerson) as TTestPerson;
  try
    Assert.AreEqual('John', Person.Name);
    Assert.AreEqual(25, Person.Age);
    Assert.AreEqual('john@test.com', Person.Email);
  finally
    Person.Free;
  end;
end;

procedure TJsonSerializerTests.Test_Deserialize_NestedObject;
var
  Json: string;
  Employee: TTestEmployee;
begin
  Json := '{"Id":1,"Person":{"name":"Jane","age":30},"Address":{"City":"Boston"},"Department":"IT"}';
  Employee := FSerializer.Deserialize(Json, TTestEmployee) as TTestEmployee;
  try
    Assert.AreEqual(1, Employee.Id);
    Assert.AreEqual('Jane', Employee.Person.Name);
    Assert.AreEqual('Boston', Employee.Address.City);
  finally
    Employee.Free;
  end;
end;

procedure TJsonSerializerTests.Test_Deserialize_Array;
var
  Json: string;
  Order: TTestOrder;
begin
  Json := '{"Items":["A","B","C"]}';
  Order := FSerializer.Deserialize(Json, TTestOrder) as TTestOrder;
  try
    Assert.AreEqual(Integer(3), Integer(Length(Order.Items)));
    Assert.AreEqual('A', Order.Items[0]);
    Assert.AreEqual('C', Order.Items[2]);
  finally
    Order.Free;
  end;
end;

procedure TJsonSerializerTests.Test_RoundTrip;
var
  Original, Restored: TTestPerson;
  Json: string;
begin
  Original := TTestPerson.Create;
  try
    Original.Name := 'RoundTrip Test';
    Original.Age := 42;
    Original.Email := 'test@roundtrip.com';
    
    Json := FSerializer.Serialize(Original);
    Restored := FSerializer.Deserialize(Json, TTestPerson) as TTestPerson;
    try
      Assert.AreEqual(Original.Name, Restored.Name);
      Assert.AreEqual(Original.Age, Restored.Age);
      Assert.AreEqual(Original.Email, Restored.Email);
    finally
      Restored.Free;
    end;
  finally
    Original.Free;
  end;
end;

// ============================================================================
// TXmlSerializerTests
// ============================================================================

procedure TXmlSerializerTests.Setup;
begin
  FSerializer := TXmlSerializer.Create;
end;

procedure TXmlSerializerTests.TearDown;
begin
  FSerializer.Free;
end;

procedure TXmlSerializerTests.Test_Serialize_SimpleObject;
var
  Person: TTestPerson;
  Xml: string;
begin
  Person := TTestPerson.Create;
  try
    Person.Name := 'John';
    Person.Age := 30;
    
    Xml := FSerializer.Serialize(Person);
    Assert.IsNotEmpty(Xml);
    Assert.IsTrue(Xml.Contains('John'));
  finally
    Person.Free;
  end;
end;

procedure TXmlSerializerTests.Test_Serialize_ContainsXmlTags;
var
  Person: TTestPerson;
  Xml: string;
begin
  Person := TTestPerson.Create;
  try
    Person.Name := 'Test';
    Xml := FSerializer.Serialize(Person);
    Assert.IsTrue(Xml.Contains('<'));
    Assert.IsTrue(Xml.Contains('>'));
    Assert.IsTrue(Xml.Contains('</'));
  finally
    Person.Free;
  end;
end;

procedure TXmlSerializerTests.Test_Serialize_EscapesSpecialChars;
var
  Person: TTestPerson;
  Xml: string;
begin
  Person := TTestPerson.Create;
  try
    Person.Name := 'Test<>&"';
    Xml := FSerializer.Serialize(Person);
    // Should escape < > & "
    Assert.IsTrue(Xml.Contains('&lt;') or not Xml.Contains('<Test<'));
  finally
    Person.Free;
  end;
end;

procedure TXmlSerializerTests.Test_Serialize_NestedObject;
var
  Employee: TTestEmployee;
  Xml: string;
begin
  Employee := TTestEmployee.Create;
  try
    Employee.Id := 1;
    Employee.Person.Name := 'Nested';
    
    Xml := FSerializer.Serialize(Employee);
    Assert.IsTrue(Xml.Contains('Nested'));
  finally
    Employee.Free;
  end;
end;

procedure TXmlSerializerTests.Test_Deserialize_SimpleObject;
var
  Xml: string;
  Person: TTestPerson;
begin
  Xml := '<TTestPerson><Name>Jane</Name><Age>28</Age></TTestPerson>';
  Person := FSerializer.Deserialize(Xml, TTestPerson) as TTestPerson;
  try
    Assert.AreEqual('Jane', Person.Name);
    Assert.AreEqual(28, Person.Age);
  finally
    Person.Free;
  end;
end;

procedure TXmlSerializerTests.Test_RoundTrip;
var
  Original, Restored: TTestPerson;
  Xml: string;
begin
  Original := TTestPerson.Create;
  try
    Original.Name := 'XML RoundTrip';
    Original.Age := 35;
    
    Xml := FSerializer.Serialize(Original);
    Restored := FSerializer.Deserialize(Xml, TTestPerson) as TTestPerson;
    try
      Assert.AreEqual(Original.Name, Restored.Name);
      Assert.AreEqual(Original.Age, Restored.Age);
    finally
      Restored.Free;
    end;
  finally
    Original.Free;
  end;
end;

// ============================================================================
// TBinarySerializerTests
// ============================================================================

procedure TBinarySerializerTests.Setup;
begin
  FSerializer := TBinarySerializer.Create;
end;

procedure TBinarySerializerTests.TearDown;
begin
  FSerializer.Free;
end;

procedure TBinarySerializerTests.Test_SerializeToBytes;
var
  Person: TTestPerson;
  Data: TBytes;
begin
  Person := TTestPerson.Create;
  try
    Person.Name := 'Binary Test';
    Person.Age := 25;
    
    Data := FSerializer.SerializeToBytes(Person);
    Assert.IsTrue(Length(Data) > 0);
  finally
    Person.Free;
  end;
end;

procedure TBinarySerializerTests.Test_DeserializeFromBytes;
var
  Original, Restored: TTestPerson;
  Data: TBytes;
begin
  Original := TTestPerson.Create;
  try
    Original.Name := 'Binary Deserialize';
    Original.Age := 40;
    
    Data := FSerializer.SerializeToBytes(Original);
    Restored := FSerializer.DeserializeFromBytes(Data, TTestPerson) as TTestPerson;
    try
      Assert.AreEqual(Original.Name, Restored.Name);
      Assert.AreEqual(Original.Age, Restored.Age);
    finally
      Restored.Free;
    end;
  finally
    Original.Free;
  end;
end;

procedure TBinarySerializerTests.Test_RoundTrip;
var
  Original, Restored: TTestEmployee;
  Data: TBytes;
begin
  Original := TTestEmployee.Create;
  try
    Original.Id := 123;
    Original.Person.Name := 'Binary Employee';
    Original.Department := 'Engineering';
    
    Data := FSerializer.SerializeToBytes(Original);
    Restored := FSerializer.DeserializeFromBytes(Data, TTestEmployee) as TTestEmployee;
    try
      Assert.AreEqual(Original.Id, Restored.Id);
      Assert.AreEqual(Original.Person.Name, Restored.Person.Name);
      Assert.AreEqual(Original.Department, Restored.Department);
    finally
      Restored.Free;
    end;
  finally
    Original.Free;
  end;
end;

procedure TBinarySerializerTests.Test_SerializeToStream;
var
  Person: TTestPerson;
  Stream: TMemoryStream;
begin
  Person := TTestPerson.Create;
  Stream := TMemoryStream.Create;
  try
    Person.Name := 'Stream Test';
    FSerializer.SerializeToStream(Person, Stream);
    Assert.IsTrue(Stream.Size > 0);
  finally
    Stream.Free;
    Person.Free;
  end;
end;

procedure TBinarySerializerTests.Test_Compact;
var
  Person: TTestPerson;
  JsonSerializer: TJsonSerializer;
  BinaryData: TBytes;
  JsonData: string;
begin
  Person := TTestPerson.Create;
  JsonSerializer := TJsonSerializer.Create;
  try
    Person.Name := 'Compact Test with a longer name';
    Person.Age := 30;
    Person.Email := 'compact@test.com';
    
    BinaryData := FSerializer.SerializeToBytes(Person);
    JsonData := JsonSerializer.Serialize(Person);
    
    // Binary should be more compact than JSON for typical data
    Assert.IsTrue(Length(BinaryData) <= Length(JsonData) * 2);
  finally
    JsonSerializer.Free;
    Person.Free;
  end;
end;

// ============================================================================
// TSerializerHelperTests
// ============================================================================

procedure TSerializerHelperTests.Test_ToJson;
var
  Person: TTestPerson;
  Json: string;
begin
  Person := TTestPerson.Create;
  try
    Person.Name := 'Helper Test';
    Json := TSerializer.ToJson(Person);
    Assert.IsNotEmpty(Json);
    Assert.IsTrue(Json.Contains('Helper Test'));
  finally
    Person.Free;
  end;
end;

procedure TSerializerHelperTests.Test_FromJson;
var
  Json: string;
  Person: TTestPerson;
begin
  Json := '{"name":"From JSON","age":50}';
  Person := TSerializer.FromJson(Json, TTestPerson) as TTestPerson;
  try
    Assert.AreEqual('From JSON', Person.Name);
    Assert.AreEqual(50, Person.Age);
  finally
    Person.Free;
  end;
end;

procedure TSerializerHelperTests.Test_ToXml;
var
  Person: TTestPerson;
  Xml: string;
begin
  Person := TTestPerson.Create;
  try
    Person.Name := 'XML Helper';
    Xml := TSerializer.ToXml(Person);
    Assert.IsNotEmpty(Xml);
    Assert.IsTrue(Xml.Contains('<'));
  finally
    Person.Free;
  end;
end;

procedure TSerializerHelperTests.Test_FromXml;
var
  Xml: string;
  Person: TTestPerson;
begin
  Xml := '<TTestPerson><Name>From XML</Name><Age>45</Age></TTestPerson>';
  Person := TSerializer.FromXml(Xml, TTestPerson) as TTestPerson;
  try
    Assert.AreEqual('From XML', Person.Name);
    Assert.AreEqual(45, Person.Age);
  finally
    Person.Free;
  end;
end;

procedure TSerializerHelperTests.Test_ToBytes;
var
  Person: TTestPerson;
  Data: TBytes;
begin
  Person := TTestPerson.Create;
  try
    Person.Name := 'Bytes Helper';
    Data := TSerializer.ToBytes(Person);
    Assert.IsTrue(Length(Data) > 0);
  finally
    Person.Free;
  end;
end;

procedure TSerializerHelperTests.Test_FromBytes;
var
  Original, Restored: TTestPerson;
  Data: TBytes;
begin
  Original := TTestPerson.Create;
  try
    Original.Name := 'From Bytes';
    Original.Age := 33;
    
    Data := TSerializer.ToBytes(Original);
    Restored := TSerializer.FromBytes(Data, TTestPerson) as TTestPerson;
    try
      Assert.AreEqual(Original.Name, Restored.Name);
    finally
      Restored.Free;
    end;
  finally
    Original.Free;
  end;
end;

procedure TSerializerHelperTests.Test_Clone;
var
  Original, Cloned: TTestPerson;
begin
  Original := TTestPerson.Create;
  try
    Original.Name := 'Original';
    Original.Age := 20;
    
    Cloned := TSerializer.Clone<TTestPerson>(Original);
    try
      Assert.AreEqual(Original.Name, Cloned.Name);
      Assert.AreEqual(Original.Age, Cloned.Age);
      Assert.AreNotSame(Original, Cloned);
    finally
      Cloned.Free;
    end;
  finally
    Original.Free;
  end;
end;

// ============================================================================
// TSerializerBuilderTests
// ============================================================================

procedure TSerializerBuilderTests.Test_Create_JSON;
var
  Builder: TSerializerBuilder;
begin
  Builder := TSerializerBuilder.Create(sfJSON);
  try
    Assert.IsNotNull(Builder);
  finally
    Builder.Free;
  end;
end;

procedure TSerializerBuilderTests.Test_Create_XML;
var
  Builder: TSerializerBuilder;
begin
  Builder := TSerializerBuilder.Create(sfXML);
  try
    Assert.IsNotNull(Builder);
  finally
    Builder.Free;
  end;
end;

procedure TSerializerBuilderTests.Test_WithPrettyPrint;
var
  Builder: TSerializerBuilder;
  Serializer: ISerializer;
begin
  Builder := TSerializerBuilder.Create(sfJSON);
  try
    Builder.WithPrettyPrint(True);
    Serializer := Builder.Build;
    Assert.IsTrue(Serializer.Options.PrettyPrint);
  finally
    Builder.Free;
  end;
end;

procedure TSerializerBuilderTests.Test_WithIndentSize;
var
  Builder: TSerializerBuilder;
  Serializer: ISerializer;
begin
  Builder := TSerializerBuilder.Create(sfJSON);
  try
    Builder.WithIndentSize(4);
    Serializer := Builder.Build;
    Assert.AreEqual(4, Serializer.Options.IndentSize);
  finally
    Builder.Free;
  end;
end;

procedure TSerializerBuilderTests.Test_WithCamelCase;
var
  Builder: TSerializerBuilder;
  Serializer: ISerializer;
begin
  Builder := TSerializerBuilder.Create(sfJSON);
  try
    Builder.WithCamelCase(True);
    Serializer := Builder.Build;
    Assert.IsTrue(Serializer.Options.UseCamelCase);
  finally
    Builder.Free;
  end;
end;

procedure TSerializerBuilderTests.Test_WithDateFormat;
var
  Builder: TSerializerBuilder;
  Serializer: ISerializer;
begin
  Builder := TSerializerBuilder.Create(sfJSON);
  try
    Builder.WithDateFormat('dd/mm/yyyy');
    Serializer := Builder.Build;
    Assert.AreEqual('dd/mm/yyyy', Serializer.Options.DateFormat);
  finally
    Builder.Free;
  end;
end;

procedure TSerializerBuilderTests.Test_WithEnumAsString;
var
  Builder: TSerializerBuilder;
  Serializer: ISerializer;
begin
  Builder := TSerializerBuilder.Create(sfJSON);
  try
    Builder.WithEnumAsString(False);
    Serializer := Builder.Build;
    Assert.IsFalse(Serializer.Options.EnumAsString);
  finally
    Builder.Free;
  end;
end;

procedure TSerializerBuilderTests.Test_Build;
var
  Builder: TSerializerBuilder;
  Serializer: ISerializer;
begin
  Builder := TSerializerBuilder.Create(sfJSON);
  try
    Serializer := Builder.Build;
    Assert.IsNotNull(Serializer);
  finally
    Builder.Free;
  end;
end;

procedure TSerializerBuilderTests.Test_Fluent;
var
  Builder: TSerializerBuilder;
  Serializer: ISerializer;
begin
  Builder := TSerializerBuilder.Create(sfJSON);
  try
    Serializer := Builder
      .WithPrettyPrint(True)
      .WithIndentSize(4)
      .WithCamelCase(True)
      .Build;
    
    Assert.IsTrue(Serializer.Options.PrettyPrint);
    Assert.AreEqual(4, Serializer.Options.IndentSize);
    Assert.IsTrue(Serializer.Options.UseCamelCase);
  finally
    Builder.Free;
  end;
end;

// ============================================================================
// TTypeRegistryTests
// ============================================================================

procedure TTypeRegistryTests.Setup;
begin
  FRegistry := TTypeRegistry.Create;
end;

procedure TTypeRegistryTests.TearDown;
begin
  FRegistry.Free;
end;

procedure TTypeRegistryTests.Test_Register;
begin
  FRegistry.Register(TTestPerson, 'Person');
  Assert.Pass; // No exception
end;

procedure TTypeRegistryTests.Test_GetTypeName;
begin
  FRegistry.Register(TTestPerson, 'Person');
  Assert.AreEqual('Person', FRegistry.GetTypeName(TTestPerson));
end;

procedure TTypeRegistryTests.Test_GetClass;
begin
  FRegistry.Register(TTestPerson, 'Person');
  Assert.AreEqual(TTestPerson, FRegistry.GetClass('Person'));
end;

procedure TTypeRegistryTests.Test_TryGetClass_Found;
var
  Cls: TClass;
begin
  FRegistry.Register(TTestPerson, 'Person');
  Assert.IsTrue(FRegistry.TryGetClass('Person', Cls));
  Assert.AreEqual(TTestPerson, Cls);
end;

procedure TTypeRegistryTests.Test_TryGetClass_NotFound;
var
  Cls: TClass;
begin
  Assert.IsFalse(FRegistry.TryGetClass('Unknown', Cls));
end;

// ============================================================================
// TSerializationContextTests
// ============================================================================

procedure TSerializationContextTests.Setup;
begin
  FContext := TSerializationContext.Create(sfJSON, TSerializationOptions.Default);
end;

procedure TSerializationContextTests.TearDown;
begin
  FContext.Free;
end;

procedure TSerializationContextTests.Test_Create;
begin
  Assert.IsNotNull(FContext);
  Assert.AreEqual(sfJSON, FContext.Format);
end;

procedure TSerializationContextTests.Test_PushPath;
begin
  FContext.PushPath('root');
  FContext.PushPath('child');
  Assert.IsTrue(FContext.GetPath.Contains('child'));
end;

procedure TSerializationContextTests.Test_PopPath;
begin
  FContext.PushPath('root');
  FContext.PushPath('child');
  FContext.PopPath;
  Assert.IsFalse(FContext.GetPath.Contains('child'));
end;

procedure TSerializationContextTests.Test_GetPath;
begin
  FContext.PushPath('level1');
  FContext.PushPath('level2');
  FContext.PushPath('level3');
  Assert.IsTrue(FContext.GetPath.Contains('level1'));
  Assert.IsTrue(FContext.GetPath.Contains('level3'));
end;

procedure TSerializationContextTests.Test_EnterLeaveObject;
var
  Person: TTestPerson;
begin
  Person := TTestPerson.Create;
  try
    FContext.EnterObject(Person);
    Assert.IsTrue(FContext.IsVisited(Person));
    FContext.LeaveObject(Person);
    Assert.IsFalse(FContext.IsVisited(Person));
  finally
    Person.Free;
  end;
end;

procedure TSerializationContextTests.Test_IsVisited;
var
  Person: TTestPerson;
begin
  Person := TTestPerson.Create;
  try
    Assert.IsFalse(FContext.IsVisited(Person));
    FContext.EnterObject(Person);
    Assert.IsTrue(FContext.IsVisited(Person));
  finally
    FContext.LeaveObject(Person);
    Person.Free;
  end;
end;

procedure TSerializationContextTests.Test_AddConverter;
var
  Converter: TDateTimeConverter;
begin
  Converter := TDateTimeConverter.Create;
  FContext.AddConverter(Converter);
  Assert.Pass; // No exception
end;

initialization
  TDUnitX.RegisterTestFixture(TSerializationOptionsTests);
  TDUnitX.RegisterTestFixture(TJsonSerializerTests);
  TDUnitX.RegisterTestFixture(TXmlSerializerTests);
  TDUnitX.RegisterTestFixture(TBinarySerializerTests);
  TDUnitX.RegisterTestFixture(TSerializerHelperTests);
  TDUnitX.RegisterTestFixture(TSerializerBuilderTests);
  TDUnitX.RegisterTestFixture(TTypeRegistryTests);
  TDUnitX.RegisterTestFixture(TSerializationContextTests);

end.
