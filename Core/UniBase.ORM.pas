{ ============================================================================
  UniBase.ORM - Object-Relational Mapping Core
  
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

unit UniBase.ORM;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
  System.TypInfo,
  System.Generics.Collections,
  System.Variants,
  Data.DB,
  FireDAC.Comp.Client,
  UniBase.ORM.Mapping;

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
    function MapRowToEntity(Query: TFDQuery): T;
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
    FConnection: TFDConnection;
    FOwnsConnection: Boolean;
    FInTransaction: Boolean;
    FTransaction: TFDTransaction;
    
    function GetPrimaryKeyValue(Entity: TObject; Metadata: TEntityMetadata): Variant;
    procedure SetPrimaryKeyValue(Entity: TObject; Metadata: TEntityMetadata; Value: Variant);
    function BuildInsertSQL(Metadata: TEntityMetadata; IncludePK: Boolean): string;
    function BuildUpdateSQL(Metadata: TEntityMetadata): string;
    function BuildDeleteSQL(Metadata: TEntityMetadata): string;
    procedure SetQueryParams(Query: TFDQuery; Entity: TObject; Metadata: TEntityMetadata; IncludePK: Boolean);
  public
    constructor Create(AConnection: TFDConnection; AOwnsConnection: Boolean = False);
    destructor Destroy; override;
    
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
    
    property Connection: TFDConnection read FConnection;
    property InTransaction: Boolean read FInTransaction;
  end;
  
  // ============================================================================
  // Exceptions
  // ============================================================================
  
  EORMException = class(Exception);
  EEntityNotFoundException = class(EORMException);
  EInvalidEntityException = class(EORMException);
  EConcurrencyException = class(EORMException);

implementation

uses
  System.StrUtils;

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
  FColumns.Free;
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
  FCache.Free;
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
  if not FCache.TryGetValue(TypeInfo, Result) then
  begin
    Result := ExtractMetadata(EntityType);
    FCache.Add(TypeInfo, Result);
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
  FCache.Clear;
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

function TQueryBuilder<T>.MapRowToEntity(Query: TFDQuery): T;
var
  Col: TColumnMetadata;
  Field: TField;
  Value: TValue;
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
        ctBoolean: Value := TValue.From<Boolean>(Field.AsBoolean);
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
  if FOrderByClause <> '' then
    FOrderByClause := FOrderByClause + ', ' + Column
  else
    FOrderByClause := Column;
  Result := Self;
end;

function TQueryBuilder<T>.OrderByDesc(const Column: string): IQueryBuilder<T>;
begin
  Result := OrderBy(Column + ' DESC');
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
  Query: TFDQuery;
  I: Integer;
begin
  Result := TObjectList<T>.Create(True);
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FContext.Connection;
    Query.SQL.Text := BuildSelectSQL;
    
    for I := 0 to High(FWhereParams) do
      Query.Params[I].Value := FWhereParams[I];
    
    Query.Open;
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
  Query: TFDQuery;
  I: Integer;
begin
  OldSelect := FSelectColumns;
  FSelectColumns := 'COUNT(*)';
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FContext.Connection;
    Query.SQL.Text := BuildSelectSQL;
    
    for I := 0 to High(FWhereParams) do
      Query.Params[I].Value := FWhereParams[I];
    
    Query.Open;
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

constructor TDbContext.Create(AConnection: TFDConnection; AOwnsConnection: Boolean);
begin
  inherited Create;
  FConnection := AConnection;
  FOwnsConnection := AOwnsConnection;
  FInTransaction := False;
  FTransaction := nil;
end;

destructor TDbContext.Destroy;
begin
  if FInTransaction then
    Rollback;
  if FOwnsConnection then
    FConnection.Free;
  inherited;
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

procedure TDbContext.SetQueryParams(Query: TFDQuery; Entity: TObject; 
  Metadata: TEntityMetadata; IncludePK: Boolean);
var
  Col: TColumnMetadata;
  Value: TValue;
begin
  for Col in Metadata.Columns do
  begin
    if Col.IsPrimaryKey and Col.IsAutoIncrement and (not IncludePK) then
      Continue;
    
    Value := Col.RttiField.GetValue(Entity);
    Query.ParamByName(Col.ColumnName).Value := Value.AsVariant;
  end;
end;

procedure TDbContext.Insert<T>(Entity: T);
var
  Metadata: TEntityMetadata;
  Query: TFDQuery;
  NewId: Variant;
begin
  Metadata := TMetadataCache.GetMetadata<T>;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := BuildInsertSQL(Metadata, False);
    SetQueryParams(Query, Entity, Metadata, False);
    Query.ExecSQL;
    
    // Get auto-generated ID
    if (Metadata.PrimaryKey <> nil) and Metadata.PrimaryKey.IsAutoIncrement then
    begin
      NewId := FConnection.GetLastAutoGenValue('');
      SetPrimaryKeyValue(Entity, Metadata, NewId);
    end;
  finally
    Query.Free;
  end;
end;

procedure TDbContext.Update<T>(Entity: T);
var
  Metadata: TEntityMetadata;
  Query: TFDQuery;
begin
  Metadata := TMetadataCache.GetMetadata<T>;
  
  if Metadata.PrimaryKey = nil then
    raise EInvalidEntityException.Create('Cannot update entity without primary key');
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := BuildUpdateSQL(Metadata);
    SetQueryParams(Query, Entity, Metadata, False);
    Query.ParamByName('pk_value').Value := GetPrimaryKeyValue(Entity, Metadata);
    
    if Query.ExecSQL = 0 then
      raise EConcurrencyException.Create('Entity was not found or has been modified');
  finally
    Query.Free;
  end;
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
  Query: TFDQuery;
begin
  Metadata := TMetadataCache.GetMetadata<T>;
  
  if Metadata.PrimaryKey = nil then
    raise EInvalidEntityException.Create('Cannot delete entity without primary key');
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := BuildDeleteSQL(Metadata);
    Query.ParamByName('pk_value').Value := Id;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
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
  
  if FTransaction = nil then
  begin
    FTransaction := TFDTransaction.Create(nil);
    FTransaction.Connection := FConnection;
  end;
  
  FTransaction.StartTransaction;
  FInTransaction := True;
end;

procedure TDbContext.Commit;
begin
  if not FInTransaction then
    raise EORMException.Create('No active transaction');
  
  FTransaction.Commit;
  FInTransaction := False;
end;

procedure TDbContext.Rollback;
begin
  if not FInTransaction then
    Exit;
  
  FTransaction.Rollback;
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
  Result := FConnection.ExecSQL(SQL);
end;

function TDbContext.ExecuteSQL(const SQL: string; const Params: array of Variant): Integer;
var
  Query: TFDQuery;
  I: Integer;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := SQL;
    for I := 0 to High(Params) do
      Query.Params[I].Value := Params[I];
    Result := Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

function TDbContext.ExecuteScalar(const SQL: string): Variant;
begin
  Result := ExecuteScalar(SQL, []);
end;

function TDbContext.ExecuteScalar(const SQL: string; const Params: array of Variant): Variant;
var
  Query: TFDQuery;
  I: Integer;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := SQL;
    for I := 0 to High(Params) do
      Query.Params[I].Value := Params[I];
    Query.Open;
    if not Query.IsEmpty then
      Result := Query.Fields[0].Value
    else
      Result := Null;
  finally
    Query.Free;
  end;
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
              // 如果调用方已显式传入带引号的 SQL 片段，则直接使用
              if (Length(Col.DefaultValue) >= 2) and
                 (Col.DefaultValue[1] = '''') and
                 (Col.DefaultValue[Length(Col.DefaultValue)] = '''') then
                SQL.Append(' DEFAULT ').Append(Col.DefaultValue)
              else
                SQL.Append(' DEFAULT ').Append(QuotedStr(Col.DefaultValue));
            end;
          ctBoolean:
            begin
              if SameText(Col.DefaultValue, 'true') or (Col.DefaultValue = '1') then
                SQL.Append(' DEFAULT 1')
              else if SameText(Col.DefaultValue, 'false') or (Col.DefaultValue = '0') then
                SQL.Append(' DEFAULT 0');
            end;
        else
          // 数值/日期等类型默认按原样拼接，由调用方保证合法性
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
