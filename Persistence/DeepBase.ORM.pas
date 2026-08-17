{ ============================================================================
  DeepBase.ORM - Object-Relational Mapping Core
  
  Version: 0.3
  Description: Provides ORM infrastructure for mapping objects to database tables.
               Supports CRUD operations, transactions, and query building.
  
  Thread Safety: TDbContext is NOT thread-safe. Create one per thread/request.
  
  Usage:
    // Define entity
    [Table('customers')]
    TCustomer = class
      [PrimaryKey] [Column('id')] FId: Integer;
      [Column('name', 100)] FName: string;
    end;
    
    // Use DbContext
    var Ctx := TDbContext.Create(Connection);
    try
      // Insert
      var Customer := TCustomer.Create;
      Customer.Name := 'John';
      Ctx.Insert<TCustomer>(Customer);
      
      // Query
      var Customers := Ctx.Query<TCustomer>.Where('name LIKE ?', ['J%']).ToList;
      
      // Update
      Customer.Name := 'Jane';
      Ctx.Update<TCustomer>(Customer);
      
      // Delete
      Ctx.Delete<TCustomer>(Customer);
    finally
      Ctx.Free;
    end;
  ============================================================================ }

unit DeepBase.ORM;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
  System.TypInfo,
  System.Generics.Collections,
  System.Variants,
  Data.DB,
  DeepBase.ORM.Mapping,
  DeepBase.StorageFactory;

type
  // Forward declarations
  TDbContext = class;
  TQueryBuilder<T: class> = class;
  TEntityMetadata = class;
  TColumnMetadata = class;
  
  // ============================================================================
  // Metadata Types
  // ============================================================================
  
  /// <summary>
  /// Column metadata extracted from attributes
  /// </summary>
  TColumnMetadata = class
  private
    FFieldName: string;
    FColumnName: string;
    FColumnType: TColumnType;
    FMaxLength: Integer;
    FNullable: Boolean;
    FIsPrimaryKey: Boolean;
    FIsAutoIncrement: Boolean;
    FIsUnique: Boolean;
    FDefaultValue: string;
    FRttiField: TRttiField;
  public
    property FieldName: string read FFieldName write FFieldName;
    property ColumnName: string read FColumnName write FColumnName;
    property ColumnType: TColumnType read FColumnType write FColumnType;
    property MaxLength: Integer read FMaxLength write FMaxLength;
    property Nullable: Boolean read FNullable write FNullable;
    property IsPrimaryKey: Boolean read FIsPrimaryKey write FIsPrimaryKey;
    property IsAutoIncrement: Boolean read FIsAutoIncrement write FIsAutoIncrement;
    property IsUnique: Boolean read FIsUnique write FIsUnique;
    property DefaultValue: string read FDefaultValue write FDefaultValue;
    property RttiField: TRttiField read FRttiField write FRttiField;
  end;
  
  /// <summary>
  /// Entity metadata extracted from attributes
  /// </summary>
  TEntityMetadata = class
  private
    FEntityType: TClass;
    FTableName: string;
    FSchema: string;
    FColumns: TObjectList<TColumnMetadata>;
    FPrimaryKey: TColumnMetadata;
  public
    constructor Create;
    destructor Destroy; override;
    
    function GetColumnByField(const FieldName: string): TColumnMetadata;
    function GetColumnByColumn(const ColumnName: string): TColumnMetadata;
    function GetFullTableName: string;
    
    property EntityType: TClass read FEntityType write FEntityType;
    property TableName: string read FTableName write FTableName;
    property Schema: string read FSchema write FSchema;
    property Columns: TObjectList<TColumnMetadata> read FColumns;
    property PrimaryKey: TColumnMetadata read FPrimaryKey write FPrimaryKey;
  end;
  
  /// <summary>
  /// Metadata cache for entity types
  /// </summary>
  TMetadataCache = class
  private
    class var FCache: TObjectDictionary<PTypeInfo, TEntityMetadata>;
    class var FRttiContext: TRttiContext;
    class function ExtractMetadata(EntityType: TClass): TEntityMetadata;
  public
    class constructor Create;
    class destructor Destroy;
    
    class function GetMetadata<T: class>: TEntityMetadata; overload;
    class function GetMetadata(EntityType: TClass): TEntityMetadata; overload;
    class procedure ClearCache;
  end;
  
  // ============================================================================
  // Query Builder Interface
  // ============================================================================
  
  /// <summary>
  /// Interface for fluent query builder - enables automatic memory management
  /// </summary>
  IQueryBuilder<T: class> = interface
    ['{7E3A8F2D-B1C4-4E5F-A6D8-9C0B1E2F3A4D}']
    function Where(const Condition: string): IQueryBuilder<T>; overload;
    function Where(const Condition: string; const Params: array of Variant): IQueryBuilder<T>; overload;
    function AndWhere(const Condition: string): IQueryBuilder<T>; overload;
    function AndWhere(const Condition: string; const Params: array of Variant): IQueryBuilder<T>; overload;
    function OrWhere(const Condition: string): IQueryBuilder<T>; overload;
    function OrWhere(const Condition: string; const Params: array of Variant): IQueryBuilder<T>; overload;
    function OrderBy(const Column: string): IQueryBuilder<T>;
    function OrderByDesc(const Column: string): IQueryBuilder<T>;
    function Limit(Count: Integer): IQueryBuilder<T>;
    function Offset(Count: Integer): IQueryBuilder<T>;
    function Select(const Columns: string): IQueryBuilder<T>;
    function ToList: TObjectList<T>;
    function FirstOrDefault: T;
    function First: T;
    function Count: Integer;
    function Exists: Boolean;
  end;

  /// <summary>
  /// Abstract transaction handle for ORM storage.
  /// </summary>
  IORMTransaction = interface
    ['{A2D8A4D1-9E6B-46F7-9A40-1F12B5E7C3B8}']
    procedure Commit;
    procedure Rollback;
  end;

  /// <summary>
  /// Abstract ORM storage contract (ARCH-039).
  /// FireDAC implementation should live in Persistence/.
  /// </summary>
  IORMStorage = interface
    ['{8C7F451E-12EF-4EA4-956C-5BEF048E3A17}']
    function Execute(const SQL: string; const Params: array of Variant): Integer;
    function OpenDataSet(const SQL: string; const Params: array of Variant): TDataSet;
    function ExecuteScalar(const SQL: string; const Params: array of Variant): Variant;
    function BeginTransaction: IORMTransaction;
    function GetLastAutoGenValue(const AGeneratorName: string): Variant;
  end;
  
  // ============================================================================
  // Query Builder Implementation
  // ============================================================================
  
  /// <summary>
  /// Fluent query builder for type-safe queries.
  /// Implements IQueryBuilder for automatic memory management.
  /// </summary>
  TQueryBuilder<T: class> = class(TInterfacedObject, IQueryBuilder<T>)
  private
    FContext: TDbContext;
    FMetadata: TEntityMetadata;
    FWhereClause: string;
    FWhereParams: TArray<Variant>;
    FOrderByClause: string;
    FLimitCount: Integer;
    FOffsetCount: Integer;
    FSelectColumns: string;
    
    function BuildSelectSQL: string;
    function MapRowToEntity(Query: TDataSet): T;
  public
    constructor Create(AContext: TDbContext);
    
    /// <summary>Add WHERE clause</summary>
    function Where(const Condition: string): IQueryBuilder<T>; overload;
    function Where(const Condition: string; const Params: array of Variant): IQueryBuilder<T>; overload;
    
    /// <summary>Add AND condition</summary>
    function AndWhere(const Condition: string): IQueryBuilder<T>; overload;
    function AndWhere(const Condition: string; const Params: array of Variant): IQueryBuilder<T>; overload;
    
    /// <summary>Add OR condition</summary>
    function OrWhere(const Condition: string): IQueryBuilder<T>; overload;
    function OrWhere(const Condition: string; const Params: array of Variant): IQueryBuilder<T>; overload;
    
    /// <summary>Add ORDER BY clause</summary>
    function OrderBy(const Column: string): IQueryBuilder<T>;
    function OrderByDesc(const Column: string): IQueryBuilder<T>;
    
    /// <summary>Limit results</summary>
    function Limit(Count: Integer): IQueryBuilder<T>;
    function Offset(Count: Integer): IQueryBuilder<T>;
    
    /// <summary>Select specific columns</summary>
    function Select(const Columns: string): IQueryBuilder<T>;
    
    /// <summary>Execute query and return results</summary>
    function ToList: TObjectList<T>;
    function FirstOrDefault: T;
    function First: T;
    function Count: Integer;
    function Exists: Boolean;
  end;
  
  // ============================================================================
  // DbContext
  // ============================================================================
  
  /// <summary>
  /// Database context for ORM operations
  /// </summary>
  TDbContext = class
  private
    FConnection: TObject;
    FStorage: IORMStorage;
    FOwnsConnection: Boolean;
    FInTransaction: Boolean;
    FTransaction: IORMTransaction;

    class function CollectEntityParams(Entity: TObject; Metadata: TEntityMetadata;
      IncludePrimaryKey: Boolean): TArray<Variant>; static;
    function RequireStorage: IORMStorage;
    function GetPrimaryKeyValue(Entity: TObject; Metadata: TEntityMetadata): Variant;
    procedure SetPrimaryKeyValue(Entity: TObject; Metadata: TEntityMetadata; Value: Variant);
    function BuildInsertSQL(Metadata: TEntityMetadata; IncludePK: Boolean): string;
    function BuildUpdateSQL(Metadata: TEntityMetadata): string;
    function BuildDeleteSQL(Metadata: TEntityMetadata): string;
  public
    constructor Create(AConnection: TObject; AOwnsConnection: Boolean = False); overload;
    constructor Create(const AStorage: IORMStorage); overload;
    destructor Destroy; override;

    class procedure SetStorageFactory(
      const AFactory: TFunc<TObject, IORMStorage>); static;
    
    // ========================================================================
    // CRUD Operations
    // ========================================================================
    
    /// <summary>Insert a new entity</summary>
    procedure Insert<T: class>(Entity: T);
    
    /// <summary>Update an existing entity</summary>
    procedure Update<T: class>(Entity: T);
    
    /// <summary>Delete an entity</summary>
    procedure Delete<T: class>(Entity: T);
    
    /// <summary>Delete by primary key</summary>
    procedure DeleteById<T: class>(const Id: Variant);
    
    /// <summary>Find entity by primary key</summary>
    function Find<T: class>(const Id: Variant): T;
    
    /// <summary>Check if entity exists</summary>
    function Exists<T: class>(const Id: Variant): Boolean;
    
    /// <summary>Get all entities</summary>
    function GetAll<T: class>: TObjectList<T>;
    
    /// <summary>
    /// Start a query builder. Returns interface for automatic memory management.
    /// Example: Context.Query<TUser>.Where('Name = ?', ['John']).ToList;
    /// </summary>
    function Query<T: class>: IQueryBuilder<T>;
    
    // ========================================================================
    // Transaction Management
    // ========================================================================
    
    /// <summary>Begin a transaction</summary>
    procedure BeginTransaction;
    
    /// <summary>Commit the current transaction</summary>
    procedure Commit;
    
    /// <summary>Rollback the current transaction</summary>
    procedure Rollback;
    
    /// <summary>Execute action within a transaction</summary>
    procedure Transaction(Action: TProc);
    
    // ========================================================================
    // Raw SQL
    // ========================================================================
    
    /// <summary>Execute raw SQL</summary>
    function ExecuteSQL(const SQL: string): Integer; overload;
    function ExecuteSQL(const SQL: string; const Params: array of Variant): Integer; overload;
    
    /// <summary>Execute scalar query</summary>
    function ExecuteScalar(const SQL: string): Variant; overload;
    function ExecuteScalar(const SQL: string; const Params: array of Variant): Variant; overload;
    
    // ========================================================================
    // Schema Operations
    // ========================================================================
    
    /// <summary>Create table from entity metadata</summary>
    procedure CreateTable<T: class>;
    
    /// <summary>Drop table</summary>
    procedure DropTable<T: class>;
    
    /// <summary>Check if table exists</summary>
    function TableExists<T: class>: Boolean;
    
    /// <summary>Ensure table exists (create if not)</summary>
    procedure EnsureTable<T: class>;
    
    // ========================================================================
    // Properties
    // ========================================================================
    
    property Connection: TObject read FConnection;
    property InTransaction: Boolean read FInTransaction;
  end;
  
  // ============================================================================
  // Exceptions
  // ============================================================================
  
  EORMException = class(Exception);
  EEntityNotFoundException = class(EORMException);
  EInvalidEntityException = class(EORMException);
  EConcurrencyException = class(EORMException);

// ============================================================================
// SQL injection defense helpers (interface-level so generic methods like
// TQueryBuilder<T>.OrderBy can reference them — Delphi E2506 forbids generic
// methods from calling unit-local symbols in the implementation section.)
// ============================================================================

/// <summary>
///   Validates a SQL identifier (column/table name) to prevent injection via
///   OrderBy/OrderByDesc. Accepts simple identifiers and schema-qualified
///   names like "schema.table" or "dbo.order_status". Rejects anything that
///   is not a valid identifier: quotes, spaces, semicolons, operators, etc.
/// </summary>
function ValidateSQLIdentifier(const AName: string): Boolean;

/// <summary>
///   Returns True when <paramref name="AValue"/> is safe to concatenate
///   verbatim after <c>DEFAULT</c> in a DDL statement. Only values that can
///   never introduce SQL injection are accepted: NULL / CURRENT_TIMESTAMP /
///   CURRENT_DATE / CURRENT_TIME, numeric literals, and single-quoted string
///   literals (already quoted, quotes escaped).
/// </summary>
function IsSafeDDLDefaultValue(const AValue: string): Boolean;

implementation

uses
  System.StrUtils;

// ============================================================================
// SQL injection defense helpers
// ============================================================================

// Validates a SQL identifier (column/table name) to prevent injection via
// OrderBy/OrderByDesc. Accepts simple identifiers and schema-qualified names
// like "schema.table" or "dbo.order_status". Rejects anything that is not a
// valid identifier: quotes, spaces, semicolons, operators, etc.
function ValidateSQLIdentifier(const AName: string): Boolean;
var
  I: Integer;
  C: Char;
  InSegment: Boolean;
begin
  Result := False;
  if AName = '' then Exit;
  InSegment := False;
  for I := 1 to Length(AName) do
  begin
    C := AName[I];
    if (I = 1) or (not InSegment) then
    begin
      // First char of a segment must be letter or underscore
      if not (CharInSet(C, ['a'..'z', 'A'..'Z', '_'])) then Exit;
      InSegment := True;
    end
    else if C = '.' then
    begin
      // Schema separator: start a new segment
      InSegment := False;
    end
    else if not CharInSet(C, ['a'..'z', 'A'..'Z', '0'..'9', '_']) then
      Exit; // illegal character
  end;
  Result := InSegment; // must not end with '.'
end;

/// <summary>
///   Returns True when <paramref name="AValue"/> is safe to concatenate
///   verbatim after <c>DEFAULT</c> in a DDL statement. Only values that can
///   never introduce SQL injection are accepted:
///   <list type="bullet">
///     <item>NULL / CURRENT_TIMESTAMP / CURRENT_DATE / CURRENT_TIME</item>
///     <item>Numeric literals (optional leading sign, digits, at most one
///       decimal point)</item>
///     <item>Single-quoted string literals (already quoted, quotes
///       escaped)</item>
///   </list>
/// </summary>
function IsSafeDDLDefaultValue(const AValue: string): Boolean;
var
  I: Integer;
  Upper: string;
  HasDigit, HasDot: Boolean;
  V: string;
begin
  Result := False;
  if AValue = '' then Exit;

  Upper := UpperCase(Trim(AValue));

  // 1. SQL keywords that are always safe
  if (Upper = 'NULL') or (Upper = 'CURRENT_TIMESTAMP') or
     (Upper = 'CURRENT_DATE') or (Upper = 'CURRENT_TIME') then
    Exit(True);

  // 2. Already single-quoted string literal — accept only if every internal
  //    quote is properly escaped (SQL-style '') so an attacker cannot break
  //    out of the literal.
  if (Length(AValue) >= 2) and (AValue[1] = '''') and
     (AValue[Length(AValue)] = '''') then
  begin
    V := Copy(AValue, 2, Length(AValue) - 2);
    I := 1;
    while I <= Length(V) do
    begin
      if V[I] = '''' then
      begin
        // Must be an escaped quote (''), not a stray single quote
        if (I = Length(V)) or (V[I + 1] <> '''') then
          Exit;
        Inc(I, 2);
      end
      else
        Inc(I);
    end;
    Exit(True);
  end;

  // 3. Numeric literal: optional leading sign, at least one digit, at most
  //    one decimal point, nothing else.
  HasDigit := False;
  HasDot := False;
  for I := 1 to Length(AValue) do
  begin
    case AValue[I] of
      '+', '-':
        if (I <> 1) or (Length(AValue) = 1) then Exit;
      '0'..'9':
        HasDigit := True;
      '.':
        begin
          if HasDot then Exit;   // second decimal point
          HasDot := True;
        end;
    else
      Exit; // any other character is unsafe
    end;
  end;
  Result := HasDigit;
end;

// ============================================================================
// TEntityMetadata
// ============================================================================

constructor TEntityMetadata.Create;
begin
  inherited Create;
  FColumns := TObjectList<TColumnMetadata>.Create(True);
end;

destructor TEntityMetadata.Destroy;
begin
  FreeAndNil(FColumns);
  inherited;
end;

function TEntityMetadata.GetColumnByField(const FieldName: string): TColumnMetadata;
var
  Col: TColumnMetadata;
begin
  for Col in FColumns do
    if SameText(Col.FieldName, FieldName) then
      Exit(Col);
  Result := nil;
end;

function TEntityMetadata.GetColumnByColumn(const ColumnName: string): TColumnMetadata;
var
  Col: TColumnMetadata;
begin
  for Col in FColumns do
    if SameText(Col.ColumnName, ColumnName) then
      Exit(Col);
  Result := nil;
end;

function TEntityMetadata.GetFullTableName: string;
begin
  if FSchema <> '' then
    Result := FSchema + '.' + FTableName
  else
    Result := FTableName;
end;

// ============================================================================
// TMetadataCache
// ============================================================================

class constructor TMetadataCache.Create;
begin
  FCache := TObjectDictionary<PTypeInfo, TEntityMetadata>.Create([doOwnsValues]);
  FRttiContext := TRttiContext.Create;
end;

class destructor TMetadataCache.Destroy;
begin
  FreeAndNil(FCache);
  FRttiContext.Free;
end;

class function TMetadataCache.GetMetadata<T>: TEntityMetadata;
begin
  Result := GetMetadata(T);
end;

class function TMetadataCache.GetMetadata(EntityType: TClass): TEntityMetadata;
var
  TypeInfo: PTypeInfo;
begin
  TypeInfo := EntityType.ClassInfo;
  // DATA2-011: Guard concurrent access to FCache. TMonitor.Enter on the
  // dictionary instance avoids adding a separate lock field.
  TMonitor.Enter(FCache);
  try
    if not FCache.TryGetValue(TypeInfo, Result) then
    begin
      Result := ExtractMetadata(EntityType);
      FCache.Add(TypeInfo, Result);
    end;
  finally
    TMonitor.Exit(FCache);
  end;
end;

class function TMetadataCache.ExtractMetadata(EntityType: TClass): TEntityMetadata;
var
  RttiType: TRttiType;
  RttiField: TRttiField;
  Attr: TCustomAttribute;
  ColMeta: TColumnMetadata;
  TableAttr: TableAttribute;
  ColAttr: ColumnAttribute;
begin
  Result := TEntityMetadata.Create;
  Result.EntityType := EntityType;
  
  RttiType := FRttiContext.GetType(EntityType);
  if RttiType = nil then
    raise EInvalidEntityException.CreateFmt('Cannot get RTTI for type: %s', [EntityType.ClassName]);
  
  // Extract table attribute
  Result.TableName := EntityType.ClassName;
  if Result.TableName.StartsWith('T') then
    Result.TableName := Copy(Result.TableName, 2, MaxInt);
  
  for Attr in RttiType.GetAttributes do
  begin
    if Attr is TableAttribute then
    begin
      TableAttr := TableAttribute(Attr);
      Result.TableName := TableAttr.TableName;
      Result.Schema := TableAttr.Schema;
      Break;
    end;
  end;
  
  // Extract column attributes from fields
  for RttiField in RttiType.GetFields do
  begin
    ColMeta := nil;
    
    for Attr in RttiField.GetAttributes do
    begin
      // Skip NotMapped fields
      if Attr is NotMappedAttribute then
      begin
        ColMeta := nil;
        Break;
      end;
      
      // Column attribute
      if Attr is ColumnAttribute then
      begin
        if ColMeta = nil then
          ColMeta := TColumnMetadata.Create;
        ColAttr := ColumnAttribute(Attr);
        ColMeta.ColumnName := ColAttr.ColumnName;
        ColMeta.ColumnType := ColAttr.ColumnType;
        ColMeta.MaxLength := ColAttr.MaxLength;
        ColMeta.Nullable := ColAttr.Nullable;
        ColMeta.DefaultValue := ColAttr.DefaultValue;
      end;
      
      // Primary key
      if Attr is PrimaryKeyAttribute then
      begin
        if ColMeta = nil then
          ColMeta := TColumnMetadata.Create;
        ColMeta.IsPrimaryKey := True;
        ColMeta.IsAutoIncrement := PrimaryKeyAttribute(Attr).AutoIncrement;
      end;
      
      // Auto increment
      if Attr is AutoIncrementAttribute then
      begin
        if ColMeta = nil then
          ColMeta := TColumnMetadata.Create;
        ColMeta.IsAutoIncrement := True;
      end;
      
      // Unique
      if Attr is UniqueAttribute then
      begin
        if ColMeta = nil then
          ColMeta := TColumnMetadata.Create;
        ColMeta.IsUnique := True;
      end;
      
      // Required
      if Attr is RequiredAttribute then
      begin
        if ColMeta = nil then
          ColMeta := TColumnMetadata.Create;
        ColMeta.Nullable := False;
      end;
      
      // MaxLength
      if Attr is MaxLengthAttribute then
      begin
        if ColMeta = nil then
          ColMeta := TColumnMetadata.Create;
        ColMeta.MaxLength := MaxLengthAttribute(Attr).MaxLength;
      end;
      
      // DefaultValue
      if Attr is DefaultValueAttribute then
      begin
        if ColMeta = nil then
          ColMeta := TColumnMetadata.Create;
        ColMeta.DefaultValue := DefaultValueAttribute(Attr).Value;
      end;
    end;
    
    // If we have a column, finalize it
    if ColMeta <> nil then
    begin
      ColMeta.FieldName := RttiField.Name;
      ColMeta.RttiField := RttiField;
      
      // Default column name from field name (remove F prefix)
      if ColMeta.ColumnName = '' then
      begin
        ColMeta.ColumnName := RttiField.Name;
        if ColMeta.ColumnName.StartsWith('F') then
          ColMeta.ColumnName := Copy(ColMeta.ColumnName, 2, MaxInt);
      end;
      
      // Auto-detect column type
      if ColMeta.ColumnType = ctAuto then
      begin
        case RttiField.FieldType.TypeKind of
          tkInteger, tkInt64: ColMeta.ColumnType := ctInteger;
          tkFloat: ColMeta.ColumnType := ctFloat;
          tkString, tkLString, tkWString, tkUString: ColMeta.ColumnType := ctString;
          tkEnumeration:
            if RttiField.FieldType.Handle = TypeInfo(Boolean) then
              ColMeta.ColumnType := ctBoolean
            else
              ColMeta.ColumnType := ctInteger;
        else
          ColMeta.ColumnType := ctString;
        end;
      end;
      
      Result.Columns.Add(ColMeta);
      
      if ColMeta.IsPrimaryKey then
        Result.PrimaryKey := ColMeta;
    end;
  end;
end;

class procedure TMetadataCache.ClearCache;
begin
  // DATA2-011: Match the lock in GetMetadata so ClearCache is safe against
  // concurrent reads.
  TMonitor.Enter(FCache);
  try
    FCache.Clear;
  finally
    TMonitor.Exit(FCache);
  end;
end;

// ============================================================================
// TQueryBuilder<T>
// ============================================================================

constructor TQueryBuilder<T>.Create(AContext: TDbContext);
begin
  inherited Create;
  FContext := AContext;
  FMetadata := TMetadataCache.GetMetadata<T>;
  FWhereClause := '';
  FOrderByClause := '';
  FLimitCount := 0;
  FOffsetCount := 0;
  FSelectColumns := '*';
end;

function TQueryBuilder<T>.BuildSelectSQL: string;
var
  SQL: TStringBuilder;
begin
  SQL := TStringBuilder.Create;
  try
    SQL.Append('SELECT ').Append(FSelectColumns);
    SQL.Append(' FROM ').Append(FMetadata.GetFullTableName);
    
    if FWhereClause <> '' then
      SQL.Append(' WHERE ').Append(FWhereClause);
    
    if FOrderByClause <> '' then
      SQL.Append(' ORDER BY ').Append(FOrderByClause);
    
    if FLimitCount > 0 then
      SQL.Append(' LIMIT ').Append(FLimitCount);
    
    if FOffsetCount > 0 then
      SQL.Append(' OFFSET ').Append(FOffsetCount);
    
    Result := SQL.ToString;
  finally
    SQL.Free;
  end;
end;

function TQueryBuilder<T>.MapRowToEntity(Query: TDataSet): T;
var
  Col: TColumnMetadata;
  Field: TField;
  Value: TValue;
  BoolText: string;
begin
  Result := T(FMetadata.EntityType.Create);
  
  for Col in FMetadata.Columns do
  begin
    Field := Query.FindField(Col.ColumnName);
    if (Field <> nil) and (not Field.IsNull) then
    begin
      case Col.ColumnType of
        ctInteger: Value := TValue.From<Integer>(Field.AsInteger);
        ctBigInt: Value := TValue.From<Int64>(Field.AsLargeInt);
        ctFloat, ctDecimal: Value := TValue.From<Double>(Field.AsFloat);
        ctString, ctText: Value := TValue.From<string>(Field.AsString);
        ctBoolean:
          begin
            case Field.DataType of
              ftBoolean:
                Value := TValue.From<Boolean>(Field.AsBoolean);
              ftSmallint, ftInteger, ftWord, ftLongWord, ftShortint, ftByte,
              ftLargeint, ftAutoInc:
                Value := TValue.From<Boolean>(Field.AsLargeInt <> 0);
            else
              begin
                BoolText := Trim(Field.AsString).ToLower;
                Value := TValue.From<Boolean>(
                  (BoolText = '1') or (BoolText = 'true') or
                  (BoolText = 'yes') or (BoolText = 'y'));
              end;
            end;
          end;
        ctDateTime: Value := TValue.From<TDateTime>(Field.AsDateTime);
        ctDate: Value := TValue.From<TDate>(Field.AsDateTime);
        ctTime: Value := TValue.From<TTime>(Field.AsDateTime);
      else
        Value := TValue.From<string>(Field.AsString);
      end;
      
      Col.RttiField.SetValue(TObject(Result), Value);
    end;
  end;
end;

function TQueryBuilder<T>.Where(const Condition: string): IQueryBuilder<T>;
begin
  FWhereClause := Condition;
  Result := Self;
end;

function TQueryBuilder<T>.Where(const Condition: string; 
  const Params: array of Variant): IQueryBuilder<T>;
var
  I: Integer;
begin
  FWhereClause := Condition;
  SetLength(FWhereParams, Length(Params));
  for I := 0 to High(Params) do
    FWhereParams[I] := Params[I];
  Result := Self;
end;

function TQueryBuilder<T>.AndWhere(const Condition: string): IQueryBuilder<T>;
begin
  if FWhereClause <> '' then
    FWhereClause := FWhereClause + ' AND ' + Condition
  else
    FWhereClause := Condition;
  Result := Self;
end;

function TQueryBuilder<T>.AndWhere(const Condition: string;
  const Params: array of Variant): IQueryBuilder<T>;
var
  I, OldLen: Integer;
begin
  AndWhere(Condition);
  OldLen := Length(FWhereParams);
  SetLength(FWhereParams, OldLen + Length(Params));
  for I := 0 to High(Params) do
    FWhereParams[OldLen + I] := Params[I];
  Result := Self;
end;

function TQueryBuilder<T>.OrWhere(const Condition: string): IQueryBuilder<T>;
begin
  if FWhereClause <> '' then
    FWhereClause := FWhereClause + ' OR ' + Condition
  else
    FWhereClause := Condition;
  Result := Self;
end;

function TQueryBuilder<T>.OrWhere(const Condition: string;
  const Params: array of Variant): IQueryBuilder<T>;
var
  I, OldLen: Integer;
begin
  OrWhere(Condition);
  OldLen := Length(FWhereParams);
  SetLength(FWhereParams, OldLen + Length(Params));
  for I := 0 to High(Params) do
    FWhereParams[OldLen + I] := Params[I];
  Result := Self;
end;

function TQueryBuilder<T>.OrderBy(const Column: string): IQueryBuilder<T>;
begin
  // DATA2-002 fix: validate column name to prevent SQL injection via
  // concatenated OrderBy clauses. Use the parameterized Where overload
  // if you need to sort by a computed expression that comes from user input.
  if not ValidateSQLIdentifier(Column) then
    raise EORMException.CreateFmt('Invalid ORDER BY column identifier: "%s"', [Column]);
  if FOrderByClause <> '' then
    FOrderByClause := FOrderByClause + ', ' + Column
  else
    FOrderByClause := Column;
  Result := Self;
end;

function TQueryBuilder<T>.OrderByDesc(const Column: string): IQueryBuilder<T>;
begin
  // Validate the bare column BEFORE appending ' DESC' (the appended clause
  // intentionally contains a space, which would fail identifier validation).
  if not ValidateSQLIdentifier(Column) then
    raise EORMException.CreateFmt('Invalid ORDER BY column identifier: "%s"', [Column]);
  if FOrderByClause <> '' then
    FOrderByClause := FOrderByClause + ', ' + Column + ' DESC'
  else
    FOrderByClause := Column + ' DESC';
  Result := Self;
end;

function TQueryBuilder<T>.Limit(Count: Integer): IQueryBuilder<T>;
begin
  FLimitCount := Count;
  Result := Self;
end;

function TQueryBuilder<T>.Offset(Count: Integer): IQueryBuilder<T>;
begin
  FOffsetCount := Count;
  Result := Self;
end;

function TQueryBuilder<T>.Select(const Columns: string): IQueryBuilder<T>;
begin
  FSelectColumns := Columns;
  Result := Self;
end;

function TQueryBuilder<T>.ToList: TObjectList<T>;
var
  Query: TDataSet;
begin
  Result := TObjectList<T>.Create(True);
  Query := FContext.RequireStorage.OpenDataSet(BuildSelectSQL, FWhereParams);
  try
    while not Query.Eof do
    begin
      Result.Add(MapRowToEntity(Query));
      Query.Next;
    end;
  finally
    Query.Free;
  end;
end;

function TQueryBuilder<T>.FirstOrDefault: T;
var
  List: TObjectList<T>;
begin
  FLimitCount := 1;
  List := ToList;
  try
    if List.Count > 0 then
    begin
      Result := List.Extract(List[0]);
    end
    else
      Result := nil;
  finally
    List.Free;
  end;
end;

function TQueryBuilder<T>.First: T;
begin
  Result := FirstOrDefault;
  if Result = nil then
    raise EEntityNotFoundException.Create('Entity not found');
end;

function TQueryBuilder<T>.Count: Integer;
var
  OldSelect: string;
  Query: TDataSet;
begin
  OldSelect := FSelectColumns;
  FSelectColumns := 'COUNT(*)';
  Query := FContext.RequireStorage.OpenDataSet(BuildSelectSQL, FWhereParams);
  try
    Result := Query.Fields[0].AsInteger;
  finally
    Query.Free;
    FSelectColumns := OldSelect;
  end;
end;

function TQueryBuilder<T>.Exists: Boolean;
begin
  Result := Count > 0;
end;

// ============================================================================
// TDbContext
// ============================================================================

constructor TDbContext.Create(AConnection: TObject; AOwnsConnection: Boolean);
var
  LStorage: IORMStorage;
begin
  LStorage := nil;
  if Supports(AConnection, IORMStorage, LStorage) then
  else
    LStorage := TConnectionStorageFactory<IORMStorage>.Create(AConnection);
  if (LStorage = nil) and Assigned(AConnection) then
    raise EInvalidOp.Create(
      'No ORM storage factory registered for connection-backed constructor. ' +
      'Include DeepBase.Persistence.ORM.FireDAC.');
  Create(LStorage);
  FConnection := AConnection;
  FOwnsConnection := AOwnsConnection;
end;

constructor TDbContext.Create(const AStorage: IORMStorage);
begin
  inherited Create;
  FStorage := AStorage;
  FConnection := nil;
  FOwnsConnection := False;
  FInTransaction := False;
  FTransaction := nil;
end;

destructor TDbContext.Destroy;
begin
  if FInTransaction then
    Rollback;
  FTransaction := nil;
  if FOwnsConnection then
    FreeAndNil(FConnection);
  inherited;
end;

class procedure TDbContext.SetStorageFactory(
  const AFactory: TFunc<TObject, IORMStorage>);
begin
  TConnectionStorageFactory<IORMStorage>.SetFactory(AFactory);
end;

function TDbContext.RequireStorage: IORMStorage;
begin
  Result := FStorage;
  if not Assigned(Result) then
    raise EORMException.Create(
      'No ORM storage configured for DbContext. ' +
      'Provide IORMStorage or register DeepBase.Persistence.ORM.FireDAC.');
end;

class function TDbContext.CollectEntityParams(Entity: TObject;
  Metadata: TEntityMetadata; IncludePrimaryKey: Boolean): TArray<Variant>;
var
  Col: TColumnMetadata;
  Value: TValue;
  ParamList: TList<Variant>;
begin
  ParamList := TList<Variant>.Create;
  try
    for Col in Metadata.Columns do
    begin
      if Col.IsPrimaryKey and (not IncludePrimaryKey) then
        Continue;
      if Col.IsPrimaryKey and Col.IsAutoIncrement and (not IncludePrimaryKey) then
        Continue;

      Value := Col.RttiField.GetValue(Entity);
      ParamList.Add(Value.AsVariant);
    end;
    Result := ParamList.ToArray;
  finally
    ParamList.Free;
  end;
end;

function TDbContext.GetPrimaryKeyValue(Entity: TObject; Metadata: TEntityMetadata): Variant;
var
  Value: TValue;
begin
  if Metadata.PrimaryKey = nil then
    raise EInvalidEntityException.Create('Entity has no primary key');
  
  Value := Metadata.PrimaryKey.RttiField.GetValue(Entity);
  Result := Value.AsVariant;
end;

procedure TDbContext.SetPrimaryKeyValue(Entity: TObject; Metadata: TEntityMetadata; Value: Variant);
var
  TVal: TValue;
begin
  if Metadata.PrimaryKey = nil then
    Exit;
  
  TVal := TValue.FromVariant(Value);
  Metadata.PrimaryKey.RttiField.SetValue(Entity, TVal);
end;

function TDbContext.BuildInsertSQL(Metadata: TEntityMetadata; IncludePK: Boolean): string;
var
  SQL: TStringBuilder;
  Col: TColumnMetadata;
  First: Boolean;
begin
  SQL := TStringBuilder.Create;
  try
    SQL.Append('INSERT INTO ').Append(Metadata.GetFullTableName).Append(' (');
    
    // Column names
    First := True;
    for Col in Metadata.Columns do
    begin
      if Col.IsPrimaryKey and Col.IsAutoIncrement and (not IncludePK) then
        Continue;
      
      if not First then
        SQL.Append(', ');
      SQL.Append(Col.ColumnName);
      First := False;
    end;
    
    SQL.Append(') VALUES (');
    
    // Parameter placeholders
    First := True;
    for Col in Metadata.Columns do
    begin
      if Col.IsPrimaryKey and Col.IsAutoIncrement and (not IncludePK) then
        Continue;
      
      if not First then
        SQL.Append(', ');
      SQL.Append(':').Append(Col.ColumnName);
      First := False;
    end;
    
    SQL.Append(')');
    Result := SQL.ToString;
  finally
    SQL.Free;
  end;
end;

function TDbContext.BuildUpdateSQL(Metadata: TEntityMetadata): string;
var
  SQL: TStringBuilder;
  Col: TColumnMetadata;
  First: Boolean;
begin
  SQL := TStringBuilder.Create;
  try
    SQL.Append('UPDATE ').Append(Metadata.GetFullTableName).Append(' SET ');
    
    First := True;
    for Col in Metadata.Columns do
    begin
      if Col.IsPrimaryKey then
        Continue;
      
      if not First then
        SQL.Append(', ');
      SQL.Append(Col.ColumnName).Append(' = :').Append(Col.ColumnName);
      First := False;
    end;
    
    SQL.Append(' WHERE ').Append(Metadata.PrimaryKey.ColumnName).Append(' = :pk_value');
    Result := SQL.ToString;
  finally
    SQL.Free;
  end;
end;

function TDbContext.BuildDeleteSQL(Metadata: TEntityMetadata): string;
begin
  Result := Format('DELETE FROM %s WHERE %s = :pk_value', 
    [Metadata.GetFullTableName, Metadata.PrimaryKey.ColumnName]);
end;

procedure TDbContext.Insert<T>(Entity: T);
var
  Metadata: TEntityMetadata;
  Params: TArray<Variant>;
  NewId: Variant;
begin
  Metadata := TMetadataCache.GetMetadata<T>;
  Params := CollectEntityParams(TObject(Entity), Metadata, False);
  RequireStorage.Execute(BuildInsertSQL(Metadata, False), Params);

  // Get auto-generated ID
  if (Metadata.PrimaryKey <> nil) and Metadata.PrimaryKey.IsAutoIncrement then
  begin
    NewId := RequireStorage.GetLastAutoGenValue('');
    SetPrimaryKeyValue(Entity, Metadata, NewId);
  end;
end;

procedure TDbContext.Update<T>(Entity: T);
var
  Metadata: TEntityMetadata;
  Params, BaseParams: TArray<Variant>;
  I: Integer;
  RowsAffected: Integer;
begin
  Metadata := TMetadataCache.GetMetadata<T>;
  
  if Metadata.PrimaryKey = nil then
    raise EInvalidEntityException.Create('Cannot update entity without primary key');

  BaseParams := CollectEntityParams(TObject(Entity), Metadata, False);
  SetLength(Params, Length(BaseParams) + 1);
  for I := 0 to High(BaseParams) do
    Params[I] := BaseParams[I];
  Params[High(Params)] := GetPrimaryKeyValue(Entity, Metadata);

  RowsAffected := RequireStorage.Execute(BuildUpdateSQL(Metadata), Params);
  if RowsAffected = 0 then
    raise EConcurrencyException.Create('Entity was not found or has been modified');
end;

procedure TDbContext.Delete<T>(Entity: T);
var
  Metadata: TEntityMetadata;
begin
  Metadata := TMetadataCache.GetMetadata<T>;
  DeleteById<T>(GetPrimaryKeyValue(Entity, Metadata));
end;

procedure TDbContext.DeleteById<T>(const Id: Variant);
var
  Metadata: TEntityMetadata;
begin
  Metadata := TMetadataCache.GetMetadata<T>;
  
  if Metadata.PrimaryKey = nil then
    raise EInvalidEntityException.Create('Cannot delete entity without primary key');

  RequireStorage.Execute(BuildDeleteSQL(Metadata), [Id]);
end;

function TDbContext.Find<T>(const Id: Variant): T;
var
  Metadata: TEntityMetadata;
begin
  Metadata := TMetadataCache.GetMetadata<T>;
  
  if Metadata.PrimaryKey = nil then
    raise EInvalidEntityException.Create('Cannot find entity without primary key');
  
  Result := Query<T>
    .Where(Metadata.PrimaryKey.ColumnName + ' = ?', [Id])
    .FirstOrDefault;
end;

function TDbContext.Exists<T>(const Id: Variant): Boolean;
var
  Metadata: TEntityMetadata;
begin
  Metadata := TMetadataCache.GetMetadata<T>;
  
  if Metadata.PrimaryKey = nil then
    raise EInvalidEntityException.Create('Cannot check entity without primary key');
  
  Result := Query<T>
    .Where(Metadata.PrimaryKey.ColumnName + ' = ?', [Id])
    .Exists;
end;

function TDbContext.GetAll<T>: TObjectList<T>;
begin
  Result := Query<T>.ToList;
end;

function TDbContext.Query<T>: IQueryBuilder<T>;
begin
  Result := TQueryBuilder<T>.Create(Self);
end;

procedure TDbContext.BeginTransaction;
begin
  if FInTransaction then
    raise EORMException.Create('Transaction already active');

  FTransaction := RequireStorage.BeginTransaction;
  if not Assigned(FTransaction) then
    raise EORMException.Create('Storage did not provide a transaction handle');
  FInTransaction := True;
end;

procedure TDbContext.Commit;
begin
  if not FInTransaction then
    raise EORMException.Create('No active transaction');

  if not Assigned(FTransaction) then
    raise EORMException.Create('No active transaction handle');

  FTransaction.Commit;
  FTransaction := nil;
  FInTransaction := False;
end;

procedure TDbContext.Rollback;
begin
  if not FInTransaction then
    Exit;

  if Assigned(FTransaction) then
    FTransaction.Rollback;
  FTransaction := nil;
  FInTransaction := False;
end;

procedure TDbContext.Transaction(Action: TProc);
begin
  BeginTransaction;
  try
    Action;
    Commit;
  except
    Rollback;
    raise;
  end;
end;

function TDbContext.ExecuteSQL(const SQL: string): Integer;
begin
  Result := ExecuteSQL(SQL, []);
end;

function TDbContext.ExecuteSQL(const SQL: string; const Params: array of Variant): Integer;
begin
  Result := RequireStorage.Execute(SQL, Params);
end;

function TDbContext.ExecuteScalar(const SQL: string): Variant;
begin
  Result := ExecuteScalar(SQL, []);
end;

function TDbContext.ExecuteScalar(const SQL: string; const Params: array of Variant): Variant;
begin
  Result := RequireStorage.ExecuteScalar(SQL, Params);
end;

procedure TDbContext.CreateTable<T>;
var
  Metadata: TEntityMetadata;
  SQL: TStringBuilder;
  Col: TColumnMetadata;
  First: Boolean;
  ColType: string;
begin
  Metadata := TMetadataCache.GetMetadata<T>;
  SQL := TStringBuilder.Create;
  try
    SQL.Append('CREATE TABLE IF NOT EXISTS ').Append(Metadata.GetFullTableName).Append(' (');
    
    First := True;
    for Col in Metadata.Columns do
    begin
      if not First then
        SQL.Append(', ');
      
      SQL.Append(Col.ColumnName).Append(' ');
      
      // Determine column type
      case Col.ColumnType of
        ctInteger:
          if Col.IsAutoIncrement then
            ColType := 'INTEGER PRIMARY KEY AUTOINCREMENT'
          else
            ColType := 'INTEGER';
        ctBigInt: ColType := 'BIGINT';
        ctFloat: ColType := 'REAL';
        ctDecimal: ColType := 'DECIMAL';
        ctString:
          if Col.MaxLength > 0 then
            ColType := Format('VARCHAR(%d)', [Col.MaxLength])
          else
            ColType := 'VARCHAR(255)';
        ctText: ColType := 'TEXT';
        ctBlob: ColType := 'BLOB';
        ctBoolean: ColType := 'INTEGER';
        ctDateTime: ColType := 'DATETIME';
        ctDate: ColType := 'DATE';
        ctTime: ColType := 'TIME';
        ctGuid: ColType := 'VARCHAR(36)';
      else
        ColType := 'TEXT';
      end;
      
      SQL.Append(ColType);
      
      // Add constraints (skip if already included in type)
      if Col.IsPrimaryKey and (not Col.IsAutoIncrement) then
        SQL.Append(' PRIMARY KEY');
      
      if not Col.Nullable then
        SQL.Append(' NOT NULL');
      
      if Col.IsUnique and (not Col.IsPrimaryKey) then
        SQL.Append(' UNIQUE');
      
      if Col.DefaultValue <> '' then
      begin
        case Col.ColumnType of
          ctString, ctText, ctGuid:
            begin
              // 如果调用方已显式传入带引号的 SQL 片段，经安全校验后直接使用
              if (Length(Col.DefaultValue) >= 2) and
                 (Col.DefaultValue[1] = '''') and
                 (Col.DefaultValue[Length(Col.DefaultValue)] = '''') then
              begin
                if not IsSafeDDLDefaultValue(Col.DefaultValue) then
                  raise EORMException.CreateFmt(
                    'Unsafe DefaultValue for column %s: rejected', [Col.ColumnName]);
                SQL.Append(' DEFAULT ').Append(Col.DefaultValue);
              end
              else
                SQL.Append(' DEFAULT ').Append(QuotedStr(Col.DefaultValue));
            end;
          ctBoolean:
            begin
              if SameText(Col.DefaultValue, 'true') or (Col.DefaultValue = '1') then
                SQL.Append(' DEFAULT 1')
              else if SameText(Col.DefaultValue, 'false') or (Col.DefaultValue = '0') then
                SQL.Append(' DEFAULT 0')
              else
                raise EORMException.CreateFmt(
                  'Unsafe DefaultValue for boolean column %s: "%s"',
                  [Col.ColumnName, Col.DefaultValue]);
            end;
        else
          // 数值/日期等类型：必须通过安全白名单检查，否则拒绝拼接
          if not IsSafeDDLDefaultValue(Col.DefaultValue) then
            raise EORMException.CreateFmt(
              'Unsafe DefaultValue for column %s: "%s"',
              [Col.ColumnName, Col.DefaultValue])
          else
            SQL.Append(' DEFAULT ').Append(Col.DefaultValue);
        end;
      end;
      
      First := False;
    end;
    
    SQL.Append(')');
    ExecuteSQL(SQL.ToString);
  finally
    SQL.Free;
  end;
end;

procedure TDbContext.DropTable<T>;
var
  Metadata: TEntityMetadata;
begin
  Metadata := TMetadataCache.GetMetadata<T>;
  ExecuteSQL('DROP TABLE IF EXISTS ' + Metadata.GetFullTableName);
end;

function TDbContext.TableExists<T>: Boolean;
var
  Metadata: TEntityMetadata;
begin
  Metadata := TMetadataCache.GetMetadata<T>;
  Result := not VarIsNull(ExecuteScalar(
    'SELECT name FROM sqlite_master WHERE type=''table'' AND name=?',
    [Metadata.TableName]));
end;

procedure TDbContext.EnsureTable<T>;
begin
  if not TableExists<T> then
    CreateTable<T>;
end;

end.
