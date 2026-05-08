{ ============================================================================
  DeepBase.ORM.Mapping - ORM Attribute Definitions
  
  Version: 0.3
  Description: Defines attributes for mapping Delphi classes to database tables.
               Uses custom attributes for declarative mapping.
  
  Usage:
    [Table('customers')]
    TCustomer = class
    private
      [PrimaryKey]
      [Column('id')]
      FId: Integer;
      
      [Column('name', 100)]
      FName: string;
      
      [Column('email', 255, True)]  // nullable
      FEmail: string;
      
      [ForeignKey('orders', 'customer_id')]
      FOrders: TObjectList<TOrder>;
    public
      property Id: Integer read FId write FId;
      property Name: string read FName write FName;
      property Email: string read FEmail write FEmail;
    end;
  ============================================================================ }

unit DeepBase.ORM.Mapping;

interface

uses
  System.SysUtils,
  System.Rtti,
  System.TypInfo,
  System.Generics.Collections;

type
  // ============================================================================
  // Table Attribute
  // ============================================================================
  
  /// <summary>
  /// Maps a class to a database table
  /// </summary>
  TableAttribute = class(TCustomAttribute)
  private
    FTableName: string;
    FSchema: string;
  public
    constructor Create(const ATableName: string); overload;
    constructor Create(const ASchema, ATableName: string); overload;
    
    property TableName: string read FTableName;
    property Schema: string read FSchema;
  end;
  
  // ============================================================================
  // Column Attributes
  // ============================================================================
  
  /// <summary>
  /// Column data type hint
  /// </summary>
  TColumnType = (
    ctAuto,       // Auto-detect from Delphi type
    ctInteger,
    ctBigInt,
    ctFloat,
    ctDecimal,
    ctString,
    ctText,
    ctBlob,
    ctBoolean,
    ctDateTime,
    ctDate,
    ctTime,
    ctGuid
  );
  
  /// <summary>
  /// Maps a field/property to a database column
  /// </summary>
  ColumnAttribute = class(TCustomAttribute)
  private
    FColumnName: string;
    FMaxLength: Integer;
    FNullable: Boolean;
    FColumnType: TColumnType;
    FDefaultValue: string;
    FPrecision: Integer;
    FScale: Integer;
  public
    constructor Create(const AColumnName: string); overload;
    constructor Create(const AColumnName: string; AMaxLength: Integer); overload;
    constructor Create(const AColumnName: string; AMaxLength: Integer; ANullable: Boolean); overload;
    constructor Create(const AColumnName: string; AColumnType: TColumnType); overload;
    constructor Create(const AColumnName: string; AColumnType: TColumnType; 
      ANullable: Boolean); overload;
    
    property ColumnName: string read FColumnName;
    property MaxLength: Integer read FMaxLength write FMaxLength;
    property Nullable: Boolean read FNullable write FNullable;
    property ColumnType: TColumnType read FColumnType write FColumnType;
    property DefaultValue: string read FDefaultValue write FDefaultValue;
    property Precision: Integer read FPrecision write FPrecision;
    property Scale: Integer read FScale write FScale;
  end;
  
  /// <summary>
  /// Marks a field as primary key
  /// </summary>
  PrimaryKeyAttribute = class(TCustomAttribute)
  private
    FAutoIncrement: Boolean;
  public
    constructor Create; overload;
    constructor Create(AAutoIncrement: Boolean); overload;
    
    property AutoIncrement: Boolean read FAutoIncrement;
  end;
  
  /// <summary>
  /// Marks a field as auto-increment (alias for PrimaryKey with auto)
  /// </summary>
  AutoIncrementAttribute = class(TCustomAttribute)
  end;
  
  /// <summary>
  /// Marks a field as unique
  /// </summary>
  UniqueAttribute = class(TCustomAttribute)
  private
    FConstraintName: string;
  public
    constructor Create; overload;
    constructor Create(const AConstraintName: string); overload;
    
    property ConstraintName: string read FConstraintName;
  end;
  
  /// <summary>
  /// Marks a field as required (NOT NULL)
  /// </summary>
  RequiredAttribute = class(TCustomAttribute)
  end;
  
  /// <summary>
  /// Specifies maximum length for string columns
  /// </summary>
  MaxLengthAttribute = class(TCustomAttribute)
  private
    FMaxLength: Integer;
  public
    constructor Create(AMaxLength: Integer);
    
    property MaxLength: Integer read FMaxLength;
  end;
  
  /// <summary>
  /// Specifies default value for a column
  /// </summary>
  DefaultValueAttribute = class(TCustomAttribute)
  private
    FValue: string;
  public
    constructor Create(const AValue: string); overload;
    constructor Create(AValue: Integer); overload;
    constructor Create(AValue: Double); overload;
    constructor Create(AValue: Boolean); overload;
    
    property Value: string read FValue;
  end;
  
  // ============================================================================
  // Relationship Attributes
  // ============================================================================
  
  /// <summary>
  /// Relationship type
  /// </summary>
  TRelationType = (
    rtOneToOne,
    rtOneToMany,
    rtManyToOne,
    rtManyToMany
  );
  
  /// <summary>
  /// Cascade action for relationships
  /// </summary>
  TCascadeAction = (
    caNone,
    caCascade,
    caSetNull,
    caSetDefault,
    caRestrict
  );
  
  /// <summary>
  /// Defines a foreign key relationship
  /// </summary>
  ForeignKeyAttribute = class(TCustomAttribute)
  private
    FReferencedTable: string;
    FReferencedColumn: string;
    FOnDelete: TCascadeAction;
    FOnUpdate: TCascadeAction;
  public
    constructor Create(const AReferencedTable, AReferencedColumn: string); overload;
    constructor Create(const AReferencedTable, AReferencedColumn: string;
      AOnDelete: TCascadeAction); overload;
    constructor Create(const AReferencedTable, AReferencedColumn: string;
      AOnDelete, AOnUpdate: TCascadeAction); overload;
    
    property ReferencedTable: string read FReferencedTable;
    property ReferencedColumn: string read FReferencedColumn;
    property OnDelete: TCascadeAction read FOnDelete;
    property OnUpdate: TCascadeAction read FOnUpdate;
  end;
  
  /// <summary>
  /// One-to-one relationship
  /// </summary>
  OneToOneAttribute = class(TCustomAttribute)
  private
    FMappedBy: string;
  public
    constructor Create; overload;
    constructor Create(const AMappedBy: string); overload;
    
    property MappedBy: string read FMappedBy;
  end;
  
  /// <summary>
  /// One-to-many relationship
  /// </summary>
  OneToManyAttribute = class(TCustomAttribute)
  private
    FMappedBy: string;
    FLazyLoad: Boolean;
  public
    constructor Create(const AMappedBy: string); overload;
    constructor Create(const AMappedBy: string; ALazyLoad: Boolean); overload;
    
    property MappedBy: string read FMappedBy;
    property LazyLoad: Boolean read FLazyLoad;
  end;
  
  /// <summary>
  /// Many-to-one relationship
  /// </summary>
  ManyToOneAttribute = class(TCustomAttribute)
  private
    FForeignKeyColumn: string;
  public
    constructor Create; overload;
    constructor Create(const AForeignKeyColumn: string); overload;
    
    property ForeignKeyColumn: string read FForeignKeyColumn;
  end;
  
  /// <summary>
  /// Many-to-many relationship
  /// </summary>
  ManyToManyAttribute = class(TCustomAttribute)
  private
    FJoinTable: string;
    FJoinColumn: string;
    FInverseJoinColumn: string;
  public
    constructor Create(const AJoinTable, AJoinColumn, AInverseJoinColumn: string);
    
    property JoinTable: string read FJoinTable;
    property JoinColumn: string read FJoinColumn;
    property InverseJoinColumn: string read FInverseJoinColumn;
  end;
  
  // ============================================================================
  // Index Attributes
  // ============================================================================
  
  /// <summary>
  /// Creates an index on the column
  /// </summary>
  IndexAttribute = class(TCustomAttribute)
  private
    FIndexName: string;
    FUnique: Boolean;
    FOrder: Integer;
  public
    constructor Create; overload;
    constructor Create(const AIndexName: string); overload;
    constructor Create(const AIndexName: string; AUnique: Boolean); overload;
    constructor Create(const AIndexName: string; AUnique: Boolean; AOrder: Integer); overload;
    
    property IndexName: string read FIndexName;
    property Unique: Boolean read FUnique;
    property Order: Integer read FOrder;
  end;
  
  /// <summary>
  /// Composite index on multiple columns (class-level attribute)
  /// </summary>
  CompositeIndexAttribute = class(TCustomAttribute)
  private
    FIndexName: string;
    FColumns: TArray<string>;
    FUnique: Boolean;
  public
    constructor Create(const AIndexName: string; const AColumns: array of string); overload;
    constructor Create(const AIndexName: string; const AColumns: array of string; 
      AUnique: Boolean); overload;
    
    property IndexName: string read FIndexName;
    property Columns: TArray<string> read FColumns;
    property Unique: Boolean read FUnique;
  end;
  
  // ============================================================================
  // Behavior Attributes
  // ============================================================================
  
  /// <summary>
  /// Excludes a field from ORM mapping
  /// </summary>
  NotMappedAttribute = class(TCustomAttribute)
  end;
  
  /// <summary>
  /// Marks a field as read-only (not updated)
  /// </summary>
  ReadOnlyAttribute = class(TCustomAttribute)
  end;
  
  /// <summary>
  /// Marks a field for timestamp tracking (auto-update on save)
  /// </summary>
  TimestampAttribute = class(TCustomAttribute)
  private
    FOnInsert: Boolean;
    FOnUpdate: Boolean;
  public
    constructor Create; overload;
    constructor Create(AOnInsert, AOnUpdate: Boolean); overload;
    
    property OnInsert: Boolean read FOnInsert;
    property OnUpdate: Boolean read FOnUpdate;
  end;
  
  /// <summary>
  /// Marks a field for soft delete tracking
  /// </summary>
  SoftDeleteAttribute = class(TCustomAttribute)
  end;
  
  /// <summary>
  /// Marks a field for optimistic locking (version column)
  /// </summary>
  VersionAttribute = class(TCustomAttribute)
  end;
  
  // ============================================================================
  // Validation Attributes
  // ============================================================================
  
  /// <summary>
  /// String length validation
  /// </summary>
  StringLengthAttribute = class(TCustomAttribute)
  private
    FMinLength: Integer;
    FMaxLength: Integer;
  public
    constructor Create(AMaxLength: Integer); overload;
    constructor Create(AMinLength, AMaxLength: Integer); overload;
    
    property MinLength: Integer read FMinLength;
    property MaxLength: Integer read FMaxLength;
  end;
  
  /// <summary>
  /// Range validation for numeric types
  /// </summary>
  RangeAttribute = class(TCustomAttribute)
  private
    FMinValue: Double;
    FMaxValue: Double;
  public
    constructor Create(AMinValue, AMaxValue: Integer); overload;
    constructor Create(AMinValue, AMaxValue: Double); overload;
    
    property MinValue: Double read FMinValue;
    property MaxValue: Double read FMaxValue;
  end;
  
  /// <summary>
  /// Regular expression validation
  /// </summary>
  RegExAttribute = class(TCustomAttribute)
  private
    FPattern: string;
    FErrorMessage: string;
  public
    constructor Create(const APattern: string); overload;
    constructor Create(const APattern, AErrorMessage: string); overload;
    
    property Pattern: string read FPattern;
    property ErrorMessage: string read FErrorMessage;
  end;
  
  /// <summary>
  /// Email format validation
  /// </summary>
  EmailAttribute = class(TCustomAttribute)
  end;
  
  /// <summary>
  /// URL format validation
  /// </summary>
  UrlAttribute = class(TCustomAttribute)
  end;

implementation

// ============================================================================
// TableAttribute
// ============================================================================

constructor TableAttribute.Create(const ATableName: string);
begin
  inherited Create;
  FTableName := ATableName;
  FSchema := '';
end;

constructor TableAttribute.Create(const ASchema, ATableName: string);
begin
  inherited Create;
  FSchema := ASchema;
  FTableName := ATableName;
end;

// ============================================================================
// ColumnAttribute
// ============================================================================

constructor ColumnAttribute.Create(const AColumnName: string);
begin
  inherited Create;
  FColumnName := AColumnName;
  FMaxLength := 0;
  FNullable := True;
  FColumnType := ctAuto;
  FDefaultValue := '';
  FPrecision := 0;
  FScale := 0;
end;

constructor ColumnAttribute.Create(const AColumnName: string; AMaxLength: Integer);
begin
  Create(AColumnName);
  FMaxLength := AMaxLength;
end;

constructor ColumnAttribute.Create(const AColumnName: string; AMaxLength: Integer;
  ANullable: Boolean);
begin
  Create(AColumnName, AMaxLength);
  FNullable := ANullable;
end;

constructor ColumnAttribute.Create(const AColumnName: string; AColumnType: TColumnType);
begin
  Create(AColumnName);
  FColumnType := AColumnType;
end;

constructor ColumnAttribute.Create(const AColumnName: string; AColumnType: TColumnType;
  ANullable: Boolean);
begin
  Create(AColumnName, AColumnType);
  FNullable := ANullable;
end;

// ============================================================================
// PrimaryKeyAttribute
// ============================================================================

constructor PrimaryKeyAttribute.Create;
begin
  inherited Create;
  FAutoIncrement := True;
end;

constructor PrimaryKeyAttribute.Create(AAutoIncrement: Boolean);
begin
  inherited Create;
  FAutoIncrement := AAutoIncrement;
end;

// ============================================================================
// UniqueAttribute
// ============================================================================

constructor UniqueAttribute.Create;
begin
  inherited Create;
  FConstraintName := '';
end;

constructor UniqueAttribute.Create(const AConstraintName: string);
begin
  inherited Create;
  FConstraintName := AConstraintName;
end;

// ============================================================================
// MaxLengthAttribute
// ============================================================================

constructor MaxLengthAttribute.Create(AMaxLength: Integer);
begin
  inherited Create;
  FMaxLength := AMaxLength;
end;

// ============================================================================
// DefaultValueAttribute
// ============================================================================

constructor DefaultValueAttribute.Create(const AValue: string);
begin
  inherited Create;
  FValue := QuotedStr(AValue);
end;

constructor DefaultValueAttribute.Create(AValue: Integer);
begin
  inherited Create;
  FValue := IntToStr(AValue);
end;

constructor DefaultValueAttribute.Create(AValue: Double);
begin
  inherited Create;
  FValue := FloatToStr(AValue);
end;

constructor DefaultValueAttribute.Create(AValue: Boolean);
begin
  inherited Create;
  if AValue then
    FValue := '1'
  else
    FValue := '0';
end;

// ============================================================================
// ForeignKeyAttribute
// ============================================================================

constructor ForeignKeyAttribute.Create(const AReferencedTable, AReferencedColumn: string);
begin
  inherited Create;
  FReferencedTable := AReferencedTable;
  FReferencedColumn := AReferencedColumn;
  FOnDelete := caNone;
  FOnUpdate := caNone;
end;

constructor ForeignKeyAttribute.Create(const AReferencedTable, AReferencedColumn: string;
  AOnDelete: TCascadeAction);
begin
  Create(AReferencedTable, AReferencedColumn);
  FOnDelete := AOnDelete;
end;

constructor ForeignKeyAttribute.Create(const AReferencedTable, AReferencedColumn: string;
  AOnDelete, AOnUpdate: TCascadeAction);
begin
  Create(AReferencedTable, AReferencedColumn, AOnDelete);
  FOnUpdate := AOnUpdate;
end;

// ============================================================================
// OneToOneAttribute
// ============================================================================

constructor OneToOneAttribute.Create;
begin
  inherited Create;
  FMappedBy := '';
end;

constructor OneToOneAttribute.Create(const AMappedBy: string);
begin
  inherited Create;
  FMappedBy := AMappedBy;
end;

// ============================================================================
// OneToManyAttribute
// ============================================================================

constructor OneToManyAttribute.Create(const AMappedBy: string);
begin
  inherited Create;
  FMappedBy := AMappedBy;
  FLazyLoad := True;
end;

constructor OneToManyAttribute.Create(const AMappedBy: string; ALazyLoad: Boolean);
begin
  Create(AMappedBy);
  FLazyLoad := ALazyLoad;
end;

// ============================================================================
// ManyToOneAttribute
// ============================================================================

constructor ManyToOneAttribute.Create;
begin
  inherited Create;
  FForeignKeyColumn := '';
end;

constructor ManyToOneAttribute.Create(const AForeignKeyColumn: string);
begin
  inherited Create;
  FForeignKeyColumn := AForeignKeyColumn;
end;

// ============================================================================
// ManyToManyAttribute
// ============================================================================

constructor ManyToManyAttribute.Create(const AJoinTable, AJoinColumn, AInverseJoinColumn: string);
begin
  inherited Create;
  FJoinTable := AJoinTable;
  FJoinColumn := AJoinColumn;
  FInverseJoinColumn := AInverseJoinColumn;
end;

// ============================================================================
// IndexAttribute
// ============================================================================

constructor IndexAttribute.Create;
begin
  inherited Create;
  FIndexName := '';
  FUnique := False;
  FOrder := 0;
end;

constructor IndexAttribute.Create(const AIndexName: string);
begin
  Create;
  FIndexName := AIndexName;
end;

constructor IndexAttribute.Create(const AIndexName: string; AUnique: Boolean);
begin
  Create(AIndexName);
  FUnique := AUnique;
end;

constructor IndexAttribute.Create(const AIndexName: string; AUnique: Boolean; AOrder: Integer);
begin
  Create(AIndexName, AUnique);
  FOrder := AOrder;
end;

// ============================================================================
// CompositeIndexAttribute
// ============================================================================

constructor CompositeIndexAttribute.Create(const AIndexName: string; 
  const AColumns: array of string);
var
  I: Integer;
begin
  inherited Create;
  FIndexName := AIndexName;
  SetLength(FColumns, Length(AColumns));
  for I := 0 to High(AColumns) do
    FColumns[I] := AColumns[I];
  FUnique := False;
end;

constructor CompositeIndexAttribute.Create(const AIndexName: string;
  const AColumns: array of string; AUnique: Boolean);
begin
  Create(AIndexName, AColumns);
  FUnique := AUnique;
end;

// ============================================================================
// TimestampAttribute
// ============================================================================

constructor TimestampAttribute.Create;
begin
  inherited Create;
  FOnInsert := True;
  FOnUpdate := True;
end;

constructor TimestampAttribute.Create(AOnInsert, AOnUpdate: Boolean);
begin
  inherited Create;
  FOnInsert := AOnInsert;
  FOnUpdate := AOnUpdate;
end;

// ============================================================================
// StringLengthAttribute
// ============================================================================

constructor StringLengthAttribute.Create(AMaxLength: Integer);
begin
  inherited Create;
  FMinLength := 0;
  FMaxLength := AMaxLength;
end;

constructor StringLengthAttribute.Create(AMinLength, AMaxLength: Integer);
begin
  inherited Create;
  FMinLength := AMinLength;
  FMaxLength := AMaxLength;
end;

// ============================================================================
// RangeAttribute
// ============================================================================

constructor RangeAttribute.Create(AMinValue, AMaxValue: Integer);
begin
  inherited Create;
  FMinValue := AMinValue;
  FMaxValue := AMaxValue;
end;

constructor RangeAttribute.Create(AMinValue, AMaxValue: Double);
begin
  inherited Create;
  FMinValue := AMinValue;
  FMaxValue := AMaxValue;
end;

// ============================================================================
// RegExAttribute
// ============================================================================

constructor RegExAttribute.Create(const APattern: string);
begin
  inherited Create;
  FPattern := APattern;
  FErrorMessage := '';
end;

constructor RegExAttribute.Create(const APattern, AErrorMessage: string);
begin
  inherited Create;
  FPattern := APattern;
  FErrorMessage := AErrorMessage;
end;

end.
