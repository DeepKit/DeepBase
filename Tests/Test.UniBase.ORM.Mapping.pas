{ ============================================================================
  Test.UniBase.ORM.Mapping - Unit Tests for ORM Mapping Attributes
  
  Test Coverage:
    - TableAttribute constructors
    - ColumnAttribute constructors and properties
    - PrimaryKeyAttribute / AutoIncrementAttribute
    - UniqueAttribute / MaxLengthAttribute / DefaultValueAttribute
    - ForeignKeyAttribute
    - OneToOneAttribute / OneToManyAttribute / ManyToOneAttribute / ManyToManyAttribute
    - IndexAttribute / CompositeIndexAttribute
    - TimestampAttribute / StringLengthAttribute / RangeAttribute / RegExAttribute
  ============================================================================ }

unit Test.UniBase.ORM.Mapping;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  UniBase.ORM.Mapping;

type
  [TestFixture]
  TTestTableAttribute = class
  public
    [Test]
    procedure Test_Create_WithTableName;
    [Test]
    procedure Test_Create_WithSchemaAndName;
  end;

  [TestFixture]
  TTestColumnAttribute = class
  public
    [Test]
    procedure Test_Create_NameOnly;
    [Test]
    procedure Test_Create_NameAndMaxLength;
    [Test]
    procedure Test_Create_NameMaxNullable;
    [Test]
    procedure Test_Create_WithColumnType;
    [Test]
    procedure Test_Create_WithColumnTypeNullable;
  end;

  [TestFixture]
  TTestPrimaryKeyAndUnique = class
  public
    [Test]
    procedure Test_PrimaryKey_DefaultAutoIncrement;
    [Test]
    procedure Test_PrimaryKey_Explicit;
    [Test]
    procedure Test_Unique_Default;
    [Test]
    procedure Test_Unique_WithName;
  end;

  [TestFixture]
  TTestDefaultAndLength = class
  public
    [Test]
    procedure Test_MaxLengthAttribute;
    [Test]
    procedure Test_DefaultValue_String;
    [Test]
    procedure Test_DefaultValue_Int;
    [Test]
    procedure Test_DefaultValue_Float;
    [Test]
    procedure Test_DefaultValue_Bool;
  end;

  [TestFixture]
  TTestRelations = class
  public
    [Test]
    procedure Test_ForeignKey_Constructors;
    [Test]
    procedure Test_OneToOne_Constructors;
    [Test]
    procedure Test_OneToMany_Constructors;
    [Test]
    procedure Test_ManyToOne_Constructors;
    [Test]
    procedure Test_ManyToMany_Constructor;
  end;

  [TestFixture]
  TTestIndexes = class
  public
    [Test]
    procedure Test_Index_Constructors;
    [Test]
    procedure Test_CompositeIndex_Constructors;
  end;

  [TestFixture]
  TTestBehaviorAndValidation = class
  public
    [Test]
    procedure Test_Timestamp_DefaultAndCustom;
    [Test]
    procedure Test_StringLength_Constructors;
    [Test]
    procedure Test_Range_Constructors;
    [Test]
    procedure Test_RegEx_Constructors;
  end;

implementation

{ TTestTableAttribute }

procedure TTestTableAttribute.Test_Create_WithTableName;
var
  A: TableAttribute;
begin
  A := TableAttribute.Create('customers');
  try
    Assert.AreEqual('customers', A.TableName);
    Assert.AreEqual('', A.Schema);
  finally
    A.Free;
  end;
end;

procedure TTestTableAttribute.Test_Create_WithSchemaAndName;
var
  A: TableAttribute;
begin
  A := TableAttribute.Create('public', 'orders');
  try
    Assert.AreEqual('orders', A.TableName);
    Assert.AreEqual('public', A.Schema);
  finally
    A.Free;
  end;
end;

{ TTestColumnAttribute }

procedure TTestColumnAttribute.Test_Create_NameOnly;
var
  A: ColumnAttribute;
begin
  A := ColumnAttribute.Create('name');
  try
    Assert.AreEqual('name', A.ColumnName);
    Assert.AreEqual(ctAuto, A.ColumnType);
  finally
    A.Free;
  end;
end;

procedure TTestColumnAttribute.Test_Create_NameAndMaxLength;
var
  A: ColumnAttribute;
begin
  A := ColumnAttribute.Create('name', 100);
  try
    Assert.AreEqual('name', A.ColumnName);
    Assert.AreEqual(100, A.MaxLength);
  finally
    A.Free;
  end;
end;

procedure TTestColumnAttribute.Test_Create_NameMaxNullable;
var
  A: ColumnAttribute;
begin
  A := ColumnAttribute.Create('email', 255, True);
  try
    Assert.AreEqual('email', A.ColumnName);
    Assert.AreEqual(255, A.MaxLength);
    Assert.IsTrue(A.Nullable);
  finally
    A.Free;
  end;
end;

procedure TTestColumnAttribute.Test_Create_WithColumnType;
var
  A: ColumnAttribute;
begin
  A := ColumnAttribute.Create('id', ctInteger);
  try
    Assert.AreEqual('id', A.ColumnName);
    Assert.AreEqual(ctInteger, A.ColumnType);
  finally
    A.Free;
  end;
end;

procedure TTestColumnAttribute.Test_Create_WithColumnTypeNullable;
var
  A: ColumnAttribute;
begin
  A := ColumnAttribute.Create('price', ctDecimal, False);
  try
    Assert.AreEqual('price', A.ColumnName);
    Assert.AreEqual(ctDecimal, A.ColumnType);
    Assert.IsFalse(A.Nullable);
  finally
    A.Free;
  end;
end;

{ TTestPrimaryKeyAndUnique }

procedure TTestPrimaryKeyAndUnique.Test_PrimaryKey_DefaultAutoIncrement;
var
  A: PrimaryKeyAttribute;
begin
  A := PrimaryKeyAttribute.Create;
  try
    Assert.IsTrue(A.AutoIncrement);
  finally
    A.Free;
  end;
end;

procedure TTestPrimaryKeyAndUnique.Test_PrimaryKey_Explicit;
var
  A: PrimaryKeyAttribute;
begin
  A := PrimaryKeyAttribute.Create(False);
  try
    Assert.IsFalse(A.AutoIncrement);
  finally
    A.Free;
  end;
end;

procedure TTestPrimaryKeyAndUnique.Test_Unique_Default;
var
  A: UniqueAttribute;
begin
  A := UniqueAttribute.Create;
  try
    Assert.AreEqual('', A.ConstraintName);
  finally
    A.Free;
  end;
end;

procedure TTestPrimaryKeyAndUnique.Test_Unique_WithName;
var
  A: UniqueAttribute;
begin
  A := UniqueAttribute.Create('UQ_Customers_Email');
  try
    Assert.AreEqual('UQ_Customers_Email', A.ConstraintName);
  finally
    A.Free;
  end;
end;

{ TTestDefaultAndLength }

procedure TTestDefaultAndLength.Test_MaxLengthAttribute;
var
  A: MaxLengthAttribute;
begin
  A := MaxLengthAttribute.Create(50);
  try
    Assert.AreEqual(50, A.MaxLength);
  finally
    A.Free;
  end;
end;

procedure TTestDefaultAndLength.Test_DefaultValue_String;
var
  A: DefaultValueAttribute;
begin
  A := DefaultValueAttribute.Create('admin');
  try
    Assert.IsTrue(A.Value.Contains('admin'));
  finally
    A.Free;
  end;
end;

procedure TTestDefaultAndLength.Test_DefaultValue_Int;
var
  A: DefaultValueAttribute;
begin
  A := DefaultValueAttribute.Create(1);
  try
    Assert.AreEqual('1', A.Value);
  finally
    A.Free;
  end;
end;

procedure TTestDefaultAndLength.Test_DefaultValue_Float;
var
  A: DefaultValueAttribute;
begin
  A := DefaultValueAttribute.Create(3.14);
  try
    Assert.IsTrue(A.Value <> '');
  finally
    A.Free;
  end;
end;

procedure TTestDefaultAndLength.Test_DefaultValue_Bool;
var
  A: DefaultValueAttribute;
begin
  A := DefaultValueAttribute.Create(True);
  try
    Assert.AreEqual('1', A.Value);
  finally
    A.Free;
  end;
end;

{ TTestRelations }

procedure TTestRelations.Test_ForeignKey_Constructors;
var
  A1, A2, A3: ForeignKeyAttribute;
begin
  A1 := ForeignKeyAttribute.Create('orders', 'customer_id');
  try
    Assert.AreEqual('orders', A1.ReferencedTable);
    Assert.AreEqual('customer_id', A1.ReferencedColumn);
    Assert.AreEqual(caNone, A1.OnDelete);
    Assert.AreEqual(caNone, A1.OnUpdate);
  finally
    A1.Free;
  end;

  A2 := ForeignKeyAttribute.Create('orders', 'customer_id', caCascade);
  try
    Assert.AreEqual(caCascade, A2.OnDelete);
  finally
    A2.Free;
  end;

  A3 := ForeignKeyAttribute.Create('orders', 'customer_id', caSetNull, caRestrict);
  try
    Assert.AreEqual(caSetNull, A3.OnDelete);
    Assert.AreEqual(caRestrict, A3.OnUpdate);
  finally
    A3.Free;
  end;
end;

procedure TTestRelations.Test_OneToOne_Constructors;
var
  A1, A2: OneToOneAttribute;
begin
  A1 := OneToOneAttribute.Create;
  try
    Assert.AreEqual('', A1.MappedBy);
  finally
    A1.Free;
  end;

  A2 := OneToOneAttribute.Create('Customer');
  try
    Assert.AreEqual('Customer', A2.MappedBy);
  finally
    A2.Free;
  end;
end;

procedure TTestRelations.Test_OneToMany_Constructors;
var
  A1, A2: OneToManyAttribute;
begin
  A1 := OneToManyAttribute.Create('Customer');
  try
    Assert.AreEqual('Customer', A1.MappedBy);
    Assert.IsTrue(A1.LazyLoad);
  finally
    A1.Free;
  end;

  A2 := OneToManyAttribute.Create('Customer', False);
  try
    Assert.AreEqual('Customer', A2.MappedBy);
    Assert.IsFalse(A2.LazyLoad);
  finally
    A2.Free;
  end;
end;

procedure TTestRelations.Test_ManyToOne_Constructors;
var
  A1, A2: ManyToOneAttribute;
begin
  A1 := ManyToOneAttribute.Create;
  try
    Assert.AreEqual('', A1.ForeignKeyColumn);
  finally
    A1.Free;
  end;

  A2 := ManyToOneAttribute.Create('customer_id');
  try
    Assert.AreEqual('customer_id', A2.ForeignKeyColumn);
  finally
    A2.Free;
  end;
end;

procedure TTestRelations.Test_ManyToMany_Constructor;
var
  A: ManyToManyAttribute;
begin
  A := ManyToManyAttribute.Create('customer_order', 'customer_id', 'order_id');
  try
    Assert.AreEqual('customer_order', A.JoinTable);
    Assert.AreEqual('customer_id', A.JoinColumn);
    Assert.AreEqual('order_id', A.InverseJoinColumn);
  finally
    A.Free;
  end;
end;

{ TTestIndexes }

procedure TTestIndexes.Test_Index_Constructors;
var
  A1, A2, A3: IndexAttribute;
begin
  A1 := IndexAttribute.Create;
  try
    Assert.AreEqual('', A1.IndexName);
    Assert.IsFalse(A1.Unique);
    Assert.AreEqual(0, A1.Order);
  finally
    A1.Free;
  end;

  A2 := IndexAttribute.Create('IX_Name');
  try
    Assert.AreEqual('IX_Name', A2.IndexName);
  finally
    A2.Free;
  end;

  A3 := IndexAttribute.Create('IX_Name', True, 2);
  try
    Assert.AreEqual('IX_Name', A3.IndexName);
    Assert.IsTrue(A3.Unique);
    Assert.AreEqual(2, A3.Order);
  finally
    A3.Free;
  end;
end;

procedure TTestIndexes.Test_CompositeIndex_Constructors;
var
  A1, A2: CompositeIndexAttribute;
begin
  A1 := CompositeIndexAttribute.Create('IX_Composite', ['A', 'B']);
  try
    Assert.AreEqual('IX_Composite', A1.IndexName);
    Assert.AreEqual(2, Length(A1.Columns));
    Assert.IsFalse(A1.Unique);
  finally
    A1.Free;
  end;

  A2 := CompositeIndexAttribute.Create('IX_Composite', ['A', 'B', 'C'], True);
  try
    Assert.AreEqual('IX_Composite', A2.IndexName);
    Assert.AreEqual(3, Length(A2.Columns));
    Assert.IsTrue(A2.Unique);
  finally
    A2.Free;
  end;
end;

{ TTestBehaviorAndValidation }

procedure TTestBehaviorAndValidation.Test_Timestamp_DefaultAndCustom;
var
  A1, A2: TimestampAttribute;
begin
  A1 := TimestampAttribute.Create;
  try
    Assert.IsTrue(A1.OnInsert);
    Assert.IsTrue(A1.OnUpdate);
  finally
    A1.Free;
  end;

  A2 := TimestampAttribute.Create(True, False);
  try
    Assert.IsTrue(A2.OnInsert);
    Assert.IsFalse(A2.OnUpdate);
  finally
    A2.Free;
  end;
end;

procedure TTestBehaviorAndValidation.Test_StringLength_Constructors;
var
  A1, A2: StringLengthAttribute;
begin
  A1 := StringLengthAttribute.Create(100);
  try
    Assert.AreEqual(0, A1.MinLength);
    Assert.AreEqual(100, A1.MaxLength);
  finally
    A1.Free;
  end;

  A2 := StringLengthAttribute.Create(5, 50);
  try
    Assert.AreEqual(5, A2.MinLength);
    Assert.AreEqual(50, A2.MaxLength);
  finally
    A2.Free;
  end;
end;

procedure TTestBehaviorAndValidation.Test_Range_Constructors;
var
  A1, A2: RangeAttribute;
begin
  A1 := RangeAttribute.Create(1, 10);
  try
    Assert.AreEqual(1.0, A1.MinValue, 0.0001);
    Assert.AreEqual(10.0, A1.MaxValue, 0.0001);
  finally
    A1.Free;
  end;

  A2 := RangeAttribute.Create(0.5, 2.5);
  try
    Assert.AreEqual(0.5, A2.MinValue, 0.0001);
    Assert.AreEqual(2.5, A2.MaxValue, 0.0001);
  finally
    A2.Free;
  end;
end;

procedure TTestBehaviorAndValidation.Test_RegEx_Constructors;
var
  A1, A2: RegExAttribute;
begin
  A1 := RegExAttribute.Create('^\\d+$');
  try
    Assert.AreEqual('^\\d+$', A1.Pattern);
    Assert.AreEqual('', A1.ErrorMessage);
  finally
    A1.Free;
  end;

  A2 := RegExAttribute.Create('^.+@.+$', 'Invalid email');
  try
    Assert.AreEqual('^.+@.+$', A2.Pattern);
    Assert.AreEqual('Invalid email', A2.ErrorMessage);
  finally
    A2.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestTableAttribute);
  TDUnitX.RegisterTestFixture(TTestColumnAttribute);
  TDUnitX.RegisterTestFixture(TTestPrimaryKeyAndUnique);
  TDUnitX.RegisterTestFixture(TTestDefaultAndLength);
  TDUnitX.RegisterTestFixture(TTestRelations);
  TDUnitX.RegisterTestFixture(TTestIndexes);
  TDUnitX.RegisterTestFixture(TTestBehaviorAndValidation);

end.
