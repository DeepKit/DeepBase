unit DeepBase.Serialization;

(*******************************************************************************
  DeepBase Serialization Framework
  A unified serialization system with:
  - Multiple format support (JSON, XML, Binary)
  - Attribute-based mapping
  - Custom serializers
  - Polymorphic type handling
  - Circular reference detection
  - Streaming support
  - Pretty printing options
  - Schema validation
  
  Author: DeepBase Team
  Created: 2025-11-29
*******************************************************************************)

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.TypInfo, System.Rtti, System.JSON, System.SyncObjs;

type
  ESerializationException = class(Exception);

  /// <summary>Serialization format</summary>
  TSerializationFormat = (sfJSON, sfXML, sfBinary);

  /// <summary>Serialization options</summary>
  TSerializationOptions = record
    PrettyPrint: Boolean;
    IndentSize: Integer;
    IncludeNulls: Boolean;
    IncludeDefaults: Boolean;
    UseCamelCase: Boolean;
    DateFormat: string;
    EnumAsString: Boolean;
    IgnoreUnknownFields: Boolean;
    MaxDepth: Integer;
    
    class function Default: TSerializationOptions; static;
  end;

  // Forward declarations
  ISerializer = interface;
  TSerializationContext = class;

  /// <summary>Attribute: Mark field/property for serialization</summary>
  SerializeAttribute = class(TCustomAttribute)
  private
    FName: string;
  public
    constructor Create(const AName: string = '');
    property Name: string read FName;
  end;

  /// <summary>Attribute: Ignore field/property during serialization</summary>
  SerializeIgnoreAttribute = class(TCustomAttribute);

  /// <summary>Attribute: Mark as required field</summary>
  SerializeRequiredAttribute = class(TCustomAttribute);

  /// <summary>Attribute: Specify default value</summary>
  SerializeDefaultAttribute = class(TCustomAttribute)
  private
    FValue: Variant;
  public
    constructor Create(const AValue: Variant);
    property Value: Variant read FValue;
  end;

  /// <summary>Attribute: Custom date format</summary>
  SerializeDateFormatAttribute = class(TCustomAttribute)
  private
    FFormat: string;
  public
    constructor Create(const AFormat: string);
    property Format: string read FFormat;
  end;

  /// <summary>Attribute: Specify order</summary>
  SerializeOrderAttribute = class(TCustomAttribute)
  private
    FOrder: Integer;
  public
    constructor Create(AOrder: Integer);
    property Order: Integer read FOrder;
  end;

  /// <summary>Attribute: Type discriminator for polymorphism</summary>
  SerializeTypeAttribute = class(TCustomAttribute)
  private
    FTypeName: string;
  public
    constructor Create(const ATypeName: string);
    property TypeName: string read FTypeName;
  end;

  /// <summary>Attribute: Mark class as safe for deserialization</summary>
  SerializeSafeAttribute = class(TCustomAttribute);

  /// <summary>Attribute: Mark class for serialization</summary>
  SerializableAttribute = class(TCustomAttribute);

  /// <summary>Custom value converter interface</summary>
  IValueConverter = interface
    ['{A1B2C3D4-5678-9ABC-DEF0-123456789ABC}']
    function CanConvert(ATypeInfo: PTypeInfo): Boolean;
    function Serialize(const AValue: TValue; AContext: TSerializationContext): TValue;
    function Deserialize(const AValue: TValue; ATargetType: PTypeInfo; AContext: TSerializationContext): TValue;
  end;

  /// <summary>Type registry for polymorphic serialization</summary>
  TTypeRegistry = class
  private
    FTypes: TDictionary<string, TClass>;
    FNames: TDictionary<TClass, string>;
    FLock: TCriticalSection;
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure Register(AClass: TClass; const ATypeName: string);
    function GetTypeName(AClass: TClass): string;
    function GetClass(const ATypeName: string): TClass;
    function TryGetClass(const ATypeName: string; out AClass: TClass): Boolean;
  end;

  /// <summary>Serialization context for tracking state</summary>
  TSerializationContext = class
  private
    FFormat: TSerializationFormat;
    FOptions: TSerializationOptions;
    FConverters: TList<IValueConverter>;
    FTypeRegistry: TTypeRegistry;
    FVisited: TList<Pointer>;
    FDepth: Integer;
    FPath: TStack<string>;
  public
    constructor Create(AFormat: TSerializationFormat; const AOptions: TSerializationOptions);
    destructor Destroy; override;
    
    procedure PushPath(const AName: string);
    procedure PopPath;
    function GetPath: string;
    
    procedure CheckDepth;
    procedure EnterObject(AObj: TObject);
    procedure LeaveObject(AObj: TObject);
    function IsVisited(AObj: TObject): Boolean;
    function IsAllowedType(AClass: TClass): Boolean;
    function IsClassAllowed(const AClassName: string; const AAllowedClasses: TArray<string>): Boolean;
    function GetAllowedClasses: TArray<string>;
    
    function FindConverter(ATypeInfo: PTypeInfo): IValueConverter;
    procedure AddConverter(AConverter: IValueConverter);
    
    property Format: TSerializationFormat read FFormat;
    property Options: TSerializationOptions read FOptions;
    property TypeRegistry: TTypeRegistry read FTypeRegistry;
    property Depth: Integer read FDepth;
  end;

  /// <summary>Serializer interface (non-generic methods only)</summary>
  ISerializer = interface
    ['{B1C2D3E4-5678-9ABC-DEF0-123456789ABC}']
    function Serialize(AObject: TObject): string;
    function SerializeToStream(AObject: TObject; AStream: TStream): Boolean;
    
    function Deserialize(const AData: string; AClass: TClass): TObject;
    function DeserializeFromStream(AStream: TStream; AClass: TClass): TObject;
    
    function GetOptions: TSerializationOptions;
    procedure SetOptions(const AOptions: TSerializationOptions);
    property Options: TSerializationOptions read GetOptions write SetOptions;
  end;

  /// <summary>Base serializer implementation</summary>
  TBaseSerializer = class(TInterfacedObject, ISerializer)
  protected
    FFormat: TSerializationFormat;
    FOptions: TSerializationOptions;
    FTypeRegistry: TTypeRegistry;
    FConverters: TList<IValueConverter>;
    FRttiContext: TRttiContext;
    
    function CreateContext: TSerializationContext;
    
    // Override in subclasses
    function DoSerialize(AObject: TObject; AContext: TSerializationContext): string; virtual; abstract;
    function DoDeserialize(const AData: string; AClass: TClass; AContext: TSerializationContext): TObject; virtual; abstract;
  public
    constructor Create(AFormat: TSerializationFormat);
    destructor Destroy; override;
    
    function Serialize<T>(const AValue: T): string; overload;
    function Serialize(AObject: TObject): string; overload;
    function SerializeToStream<T>(const AValue: T; AStream: TStream): Boolean; overload;
    function SerializeToStream(AObject: TObject; AStream: TStream): Boolean; overload;
    
    function Deserialize<T>(const AData: string): T; overload;
    function Deserialize(const AData: string; AClass: TClass): TObject; overload;
    function DeserializeFromStream<T>(AStream: TStream): T; overload;
    function DeserializeFromStream(AStream: TStream; AClass: TClass): TObject; overload;
    
    procedure RegisterType(AClass: TClass; const ATypeName: string = '');
    procedure AddConverter(AConverter: IValueConverter);
    
    function GetOptions: TSerializationOptions;
    procedure SetOptions(const AOptions: TSerializationOptions);
    property Options: TSerializationOptions read GetOptions write SetOptions;
    property TypeRegistry: TTypeRegistry read FTypeRegistry;
  end;

  /// <summary>JSON serializer</summary>
  TJsonSerializer = class(TBaseSerializer)
  private
    function ValueToJson(const AValue: TValue; AContext: TSerializationContext): TJSONValue;
    function ObjectToJson(AObject: TObject; AContext: TSerializationContext): TJSONObject;
    function ArrayToJson(const AValue: TValue; AContext: TSerializationContext): TJSONArray;
    
    function JsonToValue(AJson: TJSONValue; ATypeInfo: PTypeInfo; AContext: TSerializationContext): TValue;
    function JsonToObject(AJson: TJSONObject; AClass: TClass; AContext: TSerializationContext): TObject;
    function JsonArrayToValue(AJson: TJSONArray; ATypeInfo: PTypeInfo; AContext: TSerializationContext): TValue;
    
    function GetPropertyName(AProp: TRttiProperty): string;
    function ShouldSerialize(AProp: TRttiProperty): Boolean;
    function GetSerializeAttribute(AProp: TRttiProperty): SerializeAttribute;
  protected
    function DoSerialize(AObject: TObject; AContext: TSerializationContext): string; override;
    function DoDeserialize(const AData: string; AClass: TClass; AContext: TSerializationContext): TObject; override;
  public
    constructor Create;
  end;

  /// <summary>XML serializer</summary>
  TXmlSerializer = class(TBaseSerializer)
  private
    function EscapeXml(const AValue: string): string;
    function UnescapeXml(const AValue: string): string;
    function ValueToXml(const AValue: TValue; const AName: string; AIndent: Integer; AContext: TSerializationContext): string;
    function ObjectToXml(AObject: TObject; const AName: string; AIndent: Integer; AContext: TSerializationContext): string;
    
    function GetPropertyName(AProp: TRttiProperty): string;
    function ShouldSerialize(AProp: TRttiProperty): Boolean;
  protected
    function DoSerialize(AObject: TObject; AContext: TSerializationContext): string; override;
    function DoDeserialize(const AData: string; AClass: TClass; AContext: TSerializationContext): TObject; override;
  public
    constructor Create;
  end;

  /// <summary>Binary serializer</summary>
  TBinarySerializer = class(TBaseSerializer)
  private
    procedure WriteValue(AStream: TStream; const AValue: TValue; AContext: TSerializationContext);
    procedure WriteObject(AStream: TStream; AObject: TObject; AContext: TSerializationContext);
    procedure WriteString(AStream: TStream; const AValue: string);
    procedure WriteInteger(AStream: TStream; AValue: Int64);
    procedure WriteFloat(AStream: TStream; AValue: Double);
    
    function ReadValue(AStream: TStream; ATypeInfo: PTypeInfo; AContext: TSerializationContext): TValue;
    function ReadObject(AStream: TStream; AClass: TClass; AContext: TSerializationContext): TObject;
    function ReadString(AStream: TStream): string;
    function ReadInteger(AStream: TStream): Int64;
    function ReadFloat(AStream: TStream): Double;
    
    function ShouldSerialize(AProp: TRttiProperty): Boolean;
  protected
    function DoSerialize(AObject: TObject; AContext: TSerializationContext): string; override;
    function DoDeserialize(const AData: string; AClass: TClass; AContext: TSerializationContext): TObject; override;
  public
    constructor Create;
    
    function SerializeToBytes(AObject: TObject): TBytes;
    function DeserializeFromBytes(const AData: TBytes; AClass: TClass): TObject;
  end;

  /// <summary>Date/Time converter</summary>
  TDateTimeConverter = class(TInterfacedObject, IValueConverter)
  private
    FFormat: string;
  public
    constructor Create(const AFormat: string = '');
    function CanConvert(ATypeInfo: PTypeInfo): Boolean;
    function Serialize(const AValue: TValue; AContext: TSerializationContext): TValue;
    function Deserialize(const AValue: TValue; ATargetType: PTypeInfo; AContext: TSerializationContext): TValue;
  end;

  /// <summary>Enum converter</summary>
  TEnumConverter = class(TInterfacedObject, IValueConverter)
  public
    function CanConvert(ATypeInfo: PTypeInfo): Boolean;
    function Serialize(const AValue: TValue; AContext: TSerializationContext): TValue;
    function Deserialize(const AValue: TValue; ATargetType: PTypeInfo; AContext: TSerializationContext): TValue;
  end;

  /// <summary>Serialization helper</summary>
  TSerializer = class
  private
    class var FJsonSerializer: ISerializer;
    class var FXmlSerializer: ISerializer;
    class var FBinarySerializer: TBinarySerializer;
    class var FLock: TCriticalSection;
    
    class function GetJson: ISerializer; static;
    class function GetXml: ISerializer; static;
    class function GetBinary: TBinarySerializer; static;
  public
    class constructor Create;
    class destructor Destroy;
    
    /// <summary>Serialize to JSON</summary>
    class function ToJson<T>(const AValue: T): string; overload;
    class function ToJson(AObject: TObject): string; overload;
    class function ToJson<T>(const AValue: T; const AOptions: TSerializationOptions): string; overload;
    
    /// <summary>Deserialize from JSON</summary>
    class function FromJson<T>(const AJson: string): T; overload;
    class function FromJson(const AJson: string; AClass: TClass): TObject; overload;
    
    /// <summary>Serialize to XML</summary>
    class function ToXml<T>(const AValue: T): string; overload;
    class function ToXml(AObject: TObject): string; overload;
    
    /// <summary>Deserialize from XML</summary>
    class function FromXml<T>(const AXml: string): T; overload;
    class function FromXml(const AXml: string; AClass: TClass): TObject; overload;
    
    /// <summary>Serialize to binary</summary>
    class function ToBytes(AObject: TObject): TBytes;
    
    /// <summary>Deserialize from binary</summary>
    class function FromBytes(const AData: TBytes; AClass: TClass): TObject;
    
    /// <summary>Clone object via serialization</summary>
    class function Clone<T: class>(AObject: T): T;
    
    /// <summary>Access serializers</summary>
    class property Json: ISerializer read GetJson;
    class property Xml: ISerializer read GetXml;
    class property Binary: TBinarySerializer read GetBinary;
  end;

  /// <summary>Serializer builder</summary>
  TSerializerBuilder = class
  private
    FFormat: TSerializationFormat;
    FOptions: TSerializationOptions;
    FConverters: TList<IValueConverter>;
    FTypes: TList<TPair<TClass, string>>;
  public
    constructor Create(AFormat: TSerializationFormat);
    destructor Destroy; override;
    
    function WithPrettyPrint(AEnabled: Boolean = True): TSerializerBuilder;
    function WithIndentSize(ASize: Integer): TSerializerBuilder;
    function WithCamelCase(AEnabled: Boolean = True): TSerializerBuilder;
    function WithNulls(AInclude: Boolean = True): TSerializerBuilder;
    function WithDefaults(AInclude: Boolean = True): TSerializerBuilder;
    function WithDateFormat(const AFormat: string): TSerializerBuilder;
    function WithEnumAsString(AEnabled: Boolean = True): TSerializerBuilder;
    function WithMaxDepth(ADepth: Integer): TSerializerBuilder;
    function WithConverter(AConverter: IValueConverter): TSerializerBuilder;
    function WithType(AClass: TClass; const ATypeName: string = ''): TSerializerBuilder;
    
    function Build: ISerializer;
  end;

implementation

uses
  System.DateUtils, System.StrUtils, System.Math, System.NetEncoding;

{ TSerializationOptions }

class function TSerializationOptions.Default: TSerializationOptions;
begin
  Result.PrettyPrint := False;
  Result.IndentSize := 2;
  Result.IncludeNulls := False;
  Result.IncludeDefaults := True;
  Result.UseCamelCase := False;
  Result.DateFormat := 'yyyy-mm-dd"T"hh:nn:ss';
  Result.EnumAsString := True;
  Result.IgnoreUnknownFields := True;
  Result.MaxDepth := 32;
end;

{ SerializeAttribute }

constructor SerializeAttribute.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
end;

{ SerializeDefaultAttribute }

constructor SerializeDefaultAttribute.Create(const AValue: Variant);
begin
  inherited Create;
  FValue := AValue;
end;

{ SerializeDateFormatAttribute }

constructor SerializeDateFormatAttribute.Create(const AFormat: string);
begin
  inherited Create;
  FFormat := AFormat;
end;

{ SerializeOrderAttribute }

constructor SerializeOrderAttribute.Create(AOrder: Integer);
begin
  inherited Create;
  FOrder := AOrder;
end;

{ SerializeTypeAttribute }

constructor SerializeTypeAttribute.Create(const ATypeName: string);
begin
  inherited Create;
  FTypeName := ATypeName;
end;

{ TTypeRegistry }

constructor TTypeRegistry.Create;
begin
  inherited;
  FTypes := TDictionary<string, TClass>.Create;
  FNames := TDictionary<TClass, string>.Create;
  FLock := TCriticalSection.Create;
end;

destructor TTypeRegistry.Destroy;
begin
  FreeAndNil(FLock);
  FreeAndNil(FNames);
  FreeAndNil(FTypes);
  inherited;
end;

procedure TTypeRegistry.Register(AClass: TClass; const ATypeName: string);
var
  LName: string;
begin
  LName := ATypeName;
  if LName = '' then
    LName := AClass.ClassName;
    
  FLock.Enter;
  try
    FTypes.AddOrSetValue(LName, AClass);
    FNames.AddOrSetValue(AClass, LName);
  finally
    FLock.Leave;
  end;
end;

function TTypeRegistry.GetTypeName(AClass: TClass): string;
begin
  FLock.Enter;
  try
    if not FNames.TryGetValue(AClass, Result) then
      Result := AClass.ClassName;
  finally
    FLock.Leave;
  end;
end;

function TTypeRegistry.GetClass(const ATypeName: string): TClass;
begin
  if not TryGetClass(ATypeName, Result) then
    raise ESerializationException.CreateFmt('Type not registered: %s', [ATypeName]);
end;

function TTypeRegistry.TryGetClass(const ATypeName: string; out AClass: TClass): Boolean;
begin
  FLock.Enter;
  try
    Result := FTypes.TryGetValue(ATypeName, AClass);
  finally
    FLock.Leave;
  end;
end;

{ TSerializationContext }

constructor TSerializationContext.Create(AFormat: TSerializationFormat; const AOptions: TSerializationOptions);
begin
  inherited Create;
  FFormat := AFormat;
  FOptions := AOptions;
  FConverters := TList<IValueConverter>.Create;
  FTypeRegistry := TTypeRegistry.Create;
  FVisited := TList<Pointer>.Create;
  FDepth := 0;
  FPath := TStack<string>.Create;
end;

destructor TSerializationContext.Destroy;
begin
  FreeAndNil(FPath);
  FreeAndNil(FVisited);
  FreeAndNil(FTypeRegistry);
  FreeAndNil(FConverters);
  inherited;
end;

procedure TSerializationContext.PushPath(const AName: string);
begin
  FPath.Push(AName);
end;

procedure TSerializationContext.PopPath;
begin
  if FPath.Count > 0 then
    FPath.Pop;
end;

function TSerializationContext.GetPath: string;
var
  LItems: TArray<string>;
  I: Integer;
begin
  LItems := FPath.ToArray;
  Result := '';
  for I := High(LItems) downto 0 do
  begin
    if Result <> '' then
      Result := Result + '.';
    Result := Result + LItems[I];
  end;
end;

procedure TSerializationContext.CheckDepth;
begin
  // 降低最大深度限制，防止深度嵌套攻击
  if FDepth >= Min(FOptions.MaxDepth, 8) then
    raise ESerializationException.CreateFmt('Maximum serialization depth exceeded at: %s', [GetPath]);
end;

procedure TSerializationContext.EnterObject(AObj: TObject);
begin
  Inc(FDepth);
  CheckDepth;
  
  if Assigned(AObj) and FVisited.Contains(Pointer(AObj)) then
    raise ESerializationException.CreateFmt('Circular reference detected at: %s', [GetPath]);
    
  if Assigned(AObj) then
    FVisited.Add(Pointer(AObj));
end;

procedure TSerializationContext.LeaveObject(AObj: TObject);
begin
  Dec(FDepth);
  if Assigned(AObj) then
    FVisited.Remove(Pointer(AObj));
end;

function TSerializationContext.IsVisited(AObj: TObject): Boolean;
begin
  Result := FVisited.Contains(Pointer(AObj));
end;

function TSerializationContext.FindConverter(ATypeInfo: PTypeInfo): IValueConverter;
begin
  Result := nil;
  for var LConv in FConverters do
  begin
    if LConv.CanConvert(ATypeInfo) then
      Exit(LConv);
  end;
end;

procedure TSerializationContext.AddConverter(AConverter: IValueConverter);
begin
  FConverters.Add(AConverter);
end;

function TSerializationContext.IsAllowedType(AClass: TClass): Boolean;
const
  // 类型白名单 - 只允许安全的基础类型
  ALLOWED_TYPES: array[0..9] of string = (
    'TObject', 'TStringList', 'TList', 'TDictionary', 'TArray',
    'TDateTime', 'TDate', 'TTime', 'TGUID', 'TBytes'
  );
var
  I: Integer;
  ClassName: string;
begin
  Result := False;
  ClassName := AClass.ClassName;
  
  // 检查是否在白名单中
  for I := Low(ALLOWED_TYPES) to High(ALLOWED_TYPES) do
  begin
    if SameText(ClassName, ALLOWED_TYPES[I]) or 
       ClassName.StartsWith(ALLOWED_TYPES[I]) then
    begin
      Result := True;
      Exit;
    end;
  end;
  
  // 允许标记了SerializableAttribute的类
  var LRttiCtx := TRttiContext.Create;
  try
    var LRttiType := LRttiCtx.GetType(AClass);
    if Assigned(LRttiType) then
    begin
      for var LAttr in LRttiType.GetAttributes do
        if LAttr is SerializableAttribute then
        begin
          Result := True;
          Exit;
        end;
    end;
  finally
    LRttiCtx.Free;
  end;
end;

{ TBaseSerializer }

constructor TBaseSerializer.Create(AFormat: TSerializationFormat);
begin
  inherited Create;
  FFormat := AFormat;
  FOptions := TSerializationOptions.Default;
  FTypeRegistry := TTypeRegistry.Create;
  FConverters := TList<IValueConverter>.Create;
  FRttiContext := TRttiContext.Create;
  
  // Add default converters
  FConverters.Add(TDateTimeConverter.Create);
  FConverters.Add(TEnumConverter.Create);
end;

destructor TBaseSerializer.Destroy;
begin
  FRttiContext.Free;
  FreeAndNil(FConverters);
  FreeAndNil(FTypeRegistry);
  inherited;
end;

function TBaseSerializer.CreateContext: TSerializationContext;
begin
  Result := TSerializationContext.Create(FFormat, FOptions);
  
  // Copy converters
  for var LConv in FConverters do
    Result.AddConverter(LConv);
    
  // Copy type registry - simplified
  // In production, you'd copy the registry entries
end;

function TBaseSerializer.Serialize<T>(const AValue: T): string;
var
  LValue: TValue;
begin
  TValue.Make(@AValue, TypeInfo(T), LValue);
  
  if LValue.IsObject then
    Result := Serialize(LValue.AsObject)
  else
    raise ESerializationException.Create('Only objects can be serialized');
end;

function TBaseSerializer.Serialize(AObject: TObject): string;
var
  LContext: TSerializationContext;
begin
  LContext := CreateContext;
  try
    Result := DoSerialize(AObject, LContext);
  finally
    LContext.Free;
  end;
end;

function TBaseSerializer.SerializeToStream<T>(const AValue: T; AStream: TStream): Boolean;
var
  LData: string;
  LBytes: TBytes;
begin
  LData := Serialize<T>(AValue);
  LBytes := TEncoding.UTF8.GetBytes(LData);
  AStream.WriteBuffer(LBytes[0], Length(LBytes));
  Result := True;
end;

function TBaseSerializer.SerializeToStream(AObject: TObject; AStream: TStream): Boolean;
var
  LData: string;
  LBytes: TBytes;
begin
  LData := Serialize(AObject);
  LBytes := TEncoding.UTF8.GetBytes(LData);
  AStream.WriteBuffer(LBytes[0], Length(LBytes));
  Result := True;
end;

function TBaseSerializer.Deserialize<T>(const AData: string): T;
var
  LType: TRttiType;
  LObj: TObject;
  LValue: TValue;
begin
  LType := FRttiContext.GetType(TypeInfo(T));
  if LType.IsInstance then
  begin
    LObj := Deserialize(AData, LType.AsInstance.MetaclassType);
    TValue.Make(@LObj, TypeInfo(T), LValue);
    Result := LValue.AsType<T>;
  end
  else
    raise ESerializationException.Create('Only objects can be deserialized');
end;

function TBaseSerializer.Deserialize(const AData: string; AClass: TClass): TObject;
var
  LContext: TSerializationContext;
begin
  LContext := CreateContext;
  try
    Result := DoDeserialize(AData, AClass, LContext);
  finally
    LContext.Free;
  end;
end;

function TBaseSerializer.DeserializeFromStream<T>(AStream: TStream): T;
var
  LBytes: TBytes;
  LData: string;
begin
  SetLength(LBytes, AStream.Size - AStream.Position);
  AStream.ReadBuffer(LBytes[0], Length(LBytes));
  LData := TEncoding.UTF8.GetString(LBytes);
  Result := Deserialize<T>(LData);
end;

function TBaseSerializer.DeserializeFromStream(AStream: TStream; AClass: TClass): TObject;
var
  LBytes: TBytes;
  LData: string;
begin
  SetLength(LBytes, AStream.Size - AStream.Position);
  AStream.ReadBuffer(LBytes[0], Length(LBytes));
  LData := TEncoding.UTF8.GetString(LBytes);
  Result := Deserialize(LData, AClass);
end;

procedure TBaseSerializer.RegisterType(AClass: TClass; const ATypeName: string);
begin
  FTypeRegistry.Register(AClass, ATypeName);
end;

procedure TBaseSerializer.AddConverter(AConverter: IValueConverter);
begin
  FConverters.Insert(0, AConverter);  // Custom converters have priority
end;

function TBaseSerializer.GetOptions: TSerializationOptions;
begin
  Result := FOptions;
end;

procedure TBaseSerializer.SetOptions(const AOptions: TSerializationOptions);
begin
  FOptions := AOptions;
end;

{ TJsonSerializer }

constructor TJsonSerializer.Create;
begin
  inherited Create(sfJSON);
end;

function TJsonSerializer.GetPropertyName(AProp: TRttiProperty): string;
var
  LAttr: SerializeAttribute;
begin
  LAttr := GetSerializeAttribute(AProp);
  if Assigned(LAttr) and (LAttr.Name <> '') then
    Result := LAttr.Name
  else
  begin
    Result := AProp.Name;
    if FOptions.UseCamelCase then
    begin
      if Length(Result) > 0 then
        Result[1] := LowerCase(Result[1])[1];
    end;
  end;
end;

function TJsonSerializer.ShouldSerialize(AProp: TRttiProperty): Boolean;
var
  LAttr: TCustomAttribute;
begin
  Result := AProp.Visibility = mvPublished;
  
  // Check for Serialize attribute
  for LAttr in AProp.GetAttributes do
  begin
    if LAttr is SerializeIgnoreAttribute then
      Exit(False);
    if LAttr is SerializeAttribute then
      Exit(True);
  end;
end;

function TJsonSerializer.GetSerializeAttribute(AProp: TRttiProperty): SerializeAttribute;
var
  LAttr: TCustomAttribute;
begin
  Result := nil;
  for LAttr in AProp.GetAttributes do
  begin
    if LAttr is SerializeAttribute then
      Exit(SerializeAttribute(LAttr));
  end;
end;

function TJsonSerializer.ValueToJson(const AValue: TValue; AContext: TSerializationContext): TJSONValue;
var
  LConverter: IValueConverter;
  LConverted: TValue;
begin
  if AValue.IsEmpty then
    Exit(TJSONNull.Create);
    
  // Check for custom converter
  LConverter := AContext.FindConverter(AValue.TypeInfo);
  if Assigned(LConverter) then
  begin
    LConverted := LConverter.Serialize(AValue, AContext);
    if LConverted.TypeInfo = TypeInfo(string) then
      Exit(TJSONString.Create(LConverted.AsString))
    else if LConverted.TypeInfo = TypeInfo(Int64) then
      Exit(TJSONNumber.Create(LConverted.AsInt64))
    else if LConverted.TypeInfo = TypeInfo(Double) then
      Exit(TJSONNumber.Create(LConverted.AsExtended));
  end;
    
  case AValue.Kind of
    tkInteger, tkInt64:
      Result := TJSONNumber.Create(AValue.AsInt64);
      
    tkFloat:
      begin
        if AValue.TypeInfo = TypeInfo(TDateTime) then
          Result := TJSONString.Create(FormatDateTime(FOptions.DateFormat, AValue.AsExtended))
        else
          Result := TJSONNumber.Create(AValue.AsExtended);
      end;
      
    tkString, tkLString, tkWString, tkUString:
      Result := TJSONString.Create(AValue.AsString);
      
    tkEnumeration:
      begin
        if AValue.TypeInfo = TypeInfo(Boolean) then
          Result := TJSONBool.Create(AValue.AsBoolean)
        else if FOptions.EnumAsString then
          Result := TJSONString.Create(GetEnumName(AValue.TypeInfo, AValue.AsOrdinal))
        else
          Result := TJSONNumber.Create(AValue.AsOrdinal);
      end;
      
    tkClass:
      Result := ObjectToJson(AValue.AsObject, AContext);
      
    tkDynArray, tkArray:
      Result := ArrayToJson(AValue, AContext);
      
    tkRecord, tkMRecord:
      // Simplified - treat records as objects
      Result := TJSONObject.Create;
      
    else
      Result := TJSONNull.Create;
  end;
end;

function TJsonSerializer.ObjectToJson(AObject: TObject; AContext: TSerializationContext): TJSONObject;
var
  LType: TRttiType;
  LProp: TRttiProperty;
  LValue: TValue;
  LJsonValue: TJSONValue;
  LName: string;
  LKind: TTypeKind;
  LObj: TObject;
begin
  if not Assigned(AObject) then
    Exit(nil);
    
  AContext.EnterObject(AObject);
  try
    Result := TJSONObject.Create;
    
    LType := FRttiContext.GetType(AObject.ClassType);
    for LProp in LType.GetProperties do
    begin
      if not ShouldSerialize(LProp) then
        Continue;
        
      LName := GetPropertyName(LProp);
      AContext.PushPath(LName);
      try
        LValue := LProp.GetValue(AObject);
        LKind := LValue.Kind;
        
        // Skip nil if not including nulls
        if LValue.IsEmpty then
        begin
          if not FOptions.IncludeNulls then
            Continue;
        end;
        if LKind = tkClass then
        begin
          LObj := LValue.AsObject;
          if not Assigned(LObj) then
            if not FOptions.IncludeNulls then
              Continue;
        end;
        
        LJsonValue := ValueToJson(LValue, AContext);
        Result.AddPair(LName, LJsonValue);
      finally
        AContext.PopPath;
      end;
    end;
  finally
    AContext.LeaveObject(AObject);
  end;
end;

function TJsonSerializer.ArrayToJson(const AValue: TValue; AContext: TSerializationContext): TJSONArray;
var
  I: Integer;
  LCount: Integer;
begin
  Result := TJSONArray.Create;
  LCount := AValue.GetArrayLength;
  
  for I := 0 to LCount - 1 do
    Result.AddElement(ValueToJson(AValue.GetArrayElement(I), AContext));
end;

function TJsonSerializer.DoSerialize(AObject: TObject; AContext: TSerializationContext): string;
var
  LJson: TJSONObject;
begin
  LJson := ObjectToJson(AObject, AContext);
  try
    if Assigned(LJson) then
    begin
      if FOptions.PrettyPrint then
        Result := LJson.Format(FOptions.IndentSize)
      else
        Result := LJson.ToJSON;
    end
    else
      Result := 'null';
  finally
    LJson.Free;
  end;
end;

function TJsonSerializer.JsonToValue(AJson: TJSONValue; ATypeInfo: PTypeInfo; AContext: TSerializationContext): TValue;
var
  LConverter: IValueConverter;
begin
  if (AJson = nil) or (AJson is TJSONNull) then
    Exit(TValue.Empty);
    
  // Check for custom converter
  LConverter := AContext.FindConverter(ATypeInfo);
  if Assigned(LConverter) then
  begin
    if AJson is TJSONString then
      Exit(LConverter.Deserialize(TValue.From<string>(TJSONString(AJson).Value), ATypeInfo, AContext))
    else if AJson is TJSONNumber then
      Exit(LConverter.Deserialize(TValue.From<Double>(TJSONNumber(AJson).AsDouble), ATypeInfo, AContext));
  end;
    
  case ATypeInfo.Kind of
    tkInteger:
      Result := TValue.From<Integer>(TJSONNumber(AJson).AsInt);
      
    tkInt64:
      Result := TValue.From<Int64>(TJSONNumber(AJson).AsInt64);
      
    tkFloat:
      begin
        if ATypeInfo = TypeInfo(TDateTime) then
        begin
          if AJson is TJSONString then
            Result := TValue.From<TDateTime>(StrToDateTime(TJSONString(AJson).Value))
          else
            Result := TValue.From<TDateTime>(TJSONNumber(AJson).AsDouble);
        end
        else
          Result := TValue.From<Double>(TJSONNumber(AJson).AsDouble);
      end;
      
    tkString, tkLString, tkWString, tkUString:
      Result := TValue.From<string>(TJSONString(AJson).Value);
      
    tkEnumeration:
      begin
        if ATypeInfo = TypeInfo(Boolean) then
          Result := TValue.From<Boolean>((AJson as TJSONBool).AsBoolean)
        else if AJson is TJSONString then
          Result := TValue.FromOrdinal(ATypeInfo, GetEnumValue(ATypeInfo, TJSONString(AJson).Value))
        else
          Result := TValue.FromOrdinal(ATypeInfo, TJSONNumber(AJson).AsInt);
      end;
      
    else
      Result := TValue.Empty;
  end;
end;

function TJsonSerializer.JsonToObject(AJson: TJSONObject; AClass: TClass; AContext: TSerializationContext): TObject;
var
  LType: TRttiType;
  LProp: TRttiProperty;
  LPair: TJSONPair;
  LValue: TValue;
  LName: string;
begin
  if not Assigned(AJson) then
    Exit(nil);
    
  // 添加类型白名单验证
  if not AContext.IsAllowedType(AClass) then
    raise ESerializationException.CreateFmt('Unauthorized type for deserialization: %s', [AClass.ClassName]);
  
  // Create instance
  LType := FRttiContext.GetType(AClass);
  Result := LType.AsInstance.MetaclassType.Create;
  
  AContext.EnterObject(Result);
  try
    for LProp in LType.GetProperties do
    begin
      if not ShouldSerialize(LProp) then
        Continue;
        
      LName := GetPropertyName(LProp);
      LPair := AJson.Get(LName);
      
      if not Assigned(LPair) then
        Continue;
        
      AContext.PushPath(LName);
      try
        if LProp.PropertyType.TypeKind = tkClass then
        begin
          if LPair.JsonValue is TJSONObject then
            LValue := TValue.From<TObject>(JsonToObject(
              TJSONObject(LPair.JsonValue), 
              LProp.PropertyType.AsInstance.MetaclassType, 
              AContext))
          else
            LValue := TValue.Empty;
        end
        else if LProp.PropertyType.TypeKind in [tkDynArray, tkArray] then
        begin
          if LPair.JsonValue is TJSONArray then
            LValue := JsonArrayToValue(TJSONArray(LPair.JsonValue), LProp.PropertyType.Handle, AContext)
          else
            LValue := TValue.Empty;
        end
        else
          LValue := JsonToValue(LPair.JsonValue, LProp.PropertyType.Handle, AContext);
          
        if not LValue.IsEmpty then
          LProp.SetValue(Result, LValue);
      finally
        AContext.PopPath;
      end;
    end;
  finally
    AContext.LeaveObject(Result);
  end;
end;

function TJsonSerializer.JsonArrayToValue(AJson: TJSONArray; ATypeInfo: PTypeInfo; AContext: TSerializationContext): TValue;
var
  LLen: Integer;
  I: Integer;
  LElementType: PTypeInfo;
  LValues: TArray<TValue>;
begin
  LLen := AJson.Count;
  SetLength(LValues, LLen);
  
  // Get element type from dynamic array RTTI
  if (ATypeInfo <> nil) and (ATypeInfo.Kind = tkDynArray) then
    LElementType := GetTypeData(ATypeInfo)^.ElType2^
  else
    LElementType := nil;
  
  for I := 0 to LLen - 1 do
    LValues[I] := JsonToValue(AJson.Items[I], LElementType, AContext);
    
  Result := TValue.FromArray(ATypeInfo, LValues);
end;

function TJsonSerializer.DoDeserialize(const AData: string; AClass: TClass; AContext: TSerializationContext): TObject;
var
  LJson: TJSONValue;
begin
  LJson := TJSONObject.ParseJSONValue(AData);
  try
    if LJson is TJSONObject then
      Result := JsonToObject(TJSONObject(LJson), AClass, AContext)
    else
      Result := nil;
  finally
    LJson.Free;
  end;
end;

{ TXmlSerializer }

constructor TXmlSerializer.Create;
begin
  inherited Create(sfXML);
end;

function TXmlSerializer.EscapeXml(const AValue: string): string;
begin
  Result := AValue;
  Result := StringReplace(Result, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
  Result := StringReplace(Result, '''', '&apos;', [rfReplaceAll]);
end;

function TXmlSerializer.UnescapeXml(const AValue: string): string;
begin
  Result := AValue;
  Result := StringReplace(Result, '&lt;', '<', [rfReplaceAll]);
  Result := StringReplace(Result, '&gt;', '>', [rfReplaceAll]);
  Result := StringReplace(Result, '&quot;', '"', [rfReplaceAll]);
  Result := StringReplace(Result, '&apos;', '''', [rfReplaceAll]);
  Result := StringReplace(Result, '&amp;', '&', [rfReplaceAll]);
end;

function TXmlSerializer.GetPropertyName(AProp: TRttiProperty): string;
var
  LAttr: TCustomAttribute;
begin
  for LAttr in AProp.GetAttributes do
  begin
    if (LAttr is SerializeAttribute) and (SerializeAttribute(LAttr).Name <> '') then
      Exit(SerializeAttribute(LAttr).Name);
  end;
  
  Result := AProp.Name;
  if FOptions.UseCamelCase and (Length(Result) > 0) then
    Result[1] := LowerCase(Result[1])[1];
end;

function TXmlSerializer.ShouldSerialize(AProp: TRttiProperty): Boolean;
var
  LAttr: TCustomAttribute;
begin
  Result := AProp.Visibility = mvPublished;
  
  for LAttr in AProp.GetAttributes do
  begin
    if LAttr is SerializeIgnoreAttribute then
      Exit(False);
    if LAttr is SerializeAttribute then
      Exit(True);
  end;
end;

function TXmlSerializer.ValueToXml(const AValue: TValue; const AName: string; AIndent: Integer; AContext: TSerializationContext): string;
var
  LIndentStr: string;
  LNewLine: string;
begin
  if FOptions.PrettyPrint then
  begin
    LIndentStr := StringOfChar(' ', AIndent * FOptions.IndentSize);
    LNewLine := sLineBreak;
  end
  else
  begin
    LIndentStr := '';
    LNewLine := '';
  end;
  
  if AValue.IsEmpty then
  begin
    Result := LIndentStr + '<' + AName + '/>' + LNewLine;
    Exit;
  end;
  
  case AValue.Kind of
    tkInteger, tkInt64:
      Result := LIndentStr + '<' + AName + '>' + IntToStr(AValue.AsInt64) + '</' + AName + '>' + LNewLine;
      
    tkFloat:
      begin
        if AValue.TypeInfo = TypeInfo(TDateTime) then
          Result := LIndentStr + '<' + AName + '>' + FormatDateTime(FOptions.DateFormat, AValue.AsExtended) + '</' + AName + '>' + LNewLine
        else
          Result := LIndentStr + '<' + AName + '>' + FloatToStr(AValue.AsExtended) + '</' + AName + '>' + LNewLine;
      end;
      
    tkString, tkLString, tkWString, tkUString:
      Result := LIndentStr + '<' + AName + '>' + EscapeXml(AValue.AsString) + '</' + AName + '>' + LNewLine;
      
    tkEnumeration:
      begin
        if AValue.TypeInfo = TypeInfo(Boolean) then
          Result := LIndentStr + '<' + AName + '>' + BoolToStr(AValue.AsBoolean, True) + '</' + AName + '>' + LNewLine
        else if FOptions.EnumAsString then
          Result := LIndentStr + '<' + AName + '>' + GetEnumName(AValue.TypeInfo, AValue.AsOrdinal) + '</' + AName + '>' + LNewLine
        else
          Result := LIndentStr + '<' + AName + '>' + IntToStr(AValue.AsOrdinal) + '</' + AName + '>' + LNewLine;
      end;
      
    tkClass:
      Result := ObjectToXml(AValue.AsObject, AName, AIndent, AContext);
      
    else
      Result := LIndentStr + '<' + AName + '/>' + LNewLine;
  end;
end;

function TXmlSerializer.ObjectToXml(AObject: TObject; const AName: string; AIndent: Integer; AContext: TSerializationContext): string;
var
  LType: TRttiType;
  LProp: TRttiProperty;
  LValue: TValue;
  LPropName: string;
  LIndentStr: string;
  LNewLine: string;
  LKind: TTypeKind;
  LObj: TObject;
begin
  if not Assigned(AObject) then
  begin
    if FOptions.IncludeNulls then
      Result := StringOfChar(' ', AIndent * FOptions.IndentSize) + '<' + AName + '/>'
    else
      Result := '';
    Exit;
  end;
  
  if FOptions.PrettyPrint then
  begin
    LIndentStr := StringOfChar(' ', AIndent * FOptions.IndentSize);
    LNewLine := sLineBreak;
  end
  else
  begin
    LIndentStr := '';
    LNewLine := '';
  end;
  
  AContext.EnterObject(AObject);
  try
    Result := LIndentStr + '<' + AName + '>' + LNewLine;
    
    LType := FRttiContext.GetType(AObject.ClassType);
    for LProp in LType.GetProperties do
    begin
      if not ShouldSerialize(LProp) then
        Continue;
        
      LPropName := GetPropertyName(LProp);
      AContext.PushPath(LPropName);
      try
        LValue := LProp.GetValue(AObject);
        LKind := LValue.Kind;
        
        if LValue.IsEmpty then
        begin
          if not FOptions.IncludeNulls then
            Continue;
        end;
        if LKind = tkClass then
        begin
          LObj := LValue.AsObject;
          if not Assigned(LObj) then
            if not FOptions.IncludeNulls then
              Continue;
        end;
        
        Result := Result + ValueToXml(LValue, LPropName, AIndent + 1, AContext);
      finally
        AContext.PopPath;
      end;
    end;
    
    Result := Result + LIndentStr + '</' + AName + '>' + LNewLine;
  finally
    AContext.LeaveObject(AObject);
  end;
end;

function TXmlSerializer.DoSerialize(AObject: TObject; AContext: TSerializationContext): string;
var
  LClassName: string;
begin
  if Assigned(AObject) then
    LClassName := AObject.ClassName
  else
    LClassName := 'Object';
    
  Result := '<?xml version="1.0" encoding="UTF-8"?>';
  if FOptions.PrettyPrint then
    Result := Result + sLineBreak;
  Result := Result + ObjectToXml(AObject, LClassName, 0, AContext);
end;

function TXmlSerializer.DoDeserialize(const AData: string; AClass: TClass; AContext: TSerializationContext): TObject;

  function ExtractTagContent(const AXml: string; const ATag: string; out AContent: string): Boolean;
  var
    OpenTag, CloseTag: string;
    StartPos, EndPos: Integer;
  begin
    OpenTag := '<' + ATag + '>';
    CloseTag := '</' + ATag + '>';
    StartPos := AXml.IndexOf(OpenTag);
    if StartPos < 0 then
      Exit(False);
    StartPos := StartPos + Length(OpenTag);
    EndPos := AXml.IndexOf(CloseTag, StartPos);
    if EndPos < 0 then
      Exit(False);
    AContent := AXml.Substring(StartPos, EndPos - StartPos).Trim;
    Result := True;
  end;

  procedure ParseElementToValue(const AText: string; ATypeInfo: PTypeInfo; out AValue: TValue);
  var
    LConverter: IValueConverter;
    LStr: string;
  begin
    LStr := UnescapeXml(AText);
    LConverter := AContext.FindConverter(ATypeInfo);
    if Assigned(LConverter) then
    begin
      AValue := LConverter.Deserialize(TValue.From<string>(LStr), ATypeInfo, AContext);
      Exit;
    end;

    case ATypeInfo.Kind of
      tkInteger:
        AValue := TValue.From<Integer>(StrToIntDef(LStr, 0));
      tkInt64:
        AValue := TValue.From<Int64>(StrToInt64Def(LStr, 0));
      tkFloat:
        begin
          if ATypeInfo = TypeInfo(TDateTime) then
            AValue := TValue.From<TDateTime>(StrToDateTimeDef(LStr, 0))
          else
            AValue := TValue.From<Double>(StrToFloatDef(LStr, 0));
        end;
      tkString, tkLString, tkWString, tkUString:
        AValue := TValue.From<string>(LStr);
      tkEnumeration:
        begin
          if ATypeInfo = TypeInfo(Boolean) then
            AValue := TValue.From<Boolean>(SameText(LStr, 'True'))
          else
            AValue := TValue.FromOrdinal(ATypeInfo, GetEnumValue(ATypeInfo, LStr));
        end;
    else
      AValue := TValue.Empty;
    end;
  end;

  function XmlToObject(const AXml: string; ATargetClass: TClass): TObject;
  var
    LType: TRttiType;
    LProp: TRttiProperty;
    LPropName: string;
    LContent: string;
    LValue: TValue;
  begin
    if not AContext.IsAllowedType(ATargetClass) then
      raise ESerializationException.CreateFmt('Unauthorized type for deserialization: %s', [ATargetClass.ClassName]);

    LType := FRttiContext.GetType(ATargetClass);
    Result := LType.AsInstance.MetaclassType.Create;

    AContext.EnterObject(Result);
    try
      for LProp in LType.GetProperties do
      begin
        if not ShouldSerialize(LProp) then
          Continue;

        LPropName := GetPropertyName(LProp);
        AContext.PushPath(LPropName);
        try
          if not ExtractTagContent(AXml, LPropName, LContent) then
            Continue;

          if LProp.PropertyType.TypeKind = tkClass then
          begin
            if LContent <> '' then
              LValue := TValue.From<TObject>(XmlToObject(LContent, LProp.PropertyType.AsInstance.MetaclassType))
            else
              LValue := TValue.Empty;
          end
          else
            ParseElementToValue(LContent, LProp.PropertyType.Handle, LValue);

          if not LValue.IsEmpty then
            LProp.SetValue(Result, LValue);
        finally
          AContext.PopPath;
        end;
      end;
    finally
      AContext.LeaveObject(Result);
    end;
  end;

var
  LXml: string;
  LClassName: string;
  LRootContent: string;
  LDeclEnd: Integer;
begin
  if AData.Trim.IsEmpty then
    raise ESerializationException.Create('Cannot deserialize empty XML');

  LXml := AData.Trim;
  if LXml.StartsWith('<?xml') then
  begin
    LDeclEnd := LXml.IndexOf('?>');
    if LDeclEnd >= 0 then
      LXml := LXml.Substring(LDeclEnd + 2).Trim;
  end;

  LClassName := AClass.ClassName;

  if not AContext.IsAllowedType(AClass) then
    raise ESerializationException.CreateFmt('Unauthorized type for deserialization: %s', [AClass.ClassName]);

  if ExtractTagContent(LXml, LClassName, LRootContent) then
    Result := XmlToObject(LRootContent, AClass)
  else
    Result := XmlToObject(LXml, AClass);
end;

{ TBinarySerializer }

constructor TBinarySerializer.Create;
begin
  inherited Create(sfBinary);
end;

procedure TBinarySerializer.WriteString(AStream: TStream; const AValue: string);
var
  LLen: Integer;
  LBytes: TBytes;
begin
  LBytes := TEncoding.UTF8.GetBytes(AValue);
  LLen := Length(LBytes);
  AStream.WriteBuffer(LLen, SizeOf(LLen));
  if LLen > 0 then
    AStream.WriteBuffer(LBytes[0], LLen);
end;

function TBinarySerializer.ReadString(AStream: TStream): string;
var
  LLen: Integer;
  LBytes: TBytes;
begin
  AStream.ReadBuffer(LLen, SizeOf(LLen));
  if LLen > 0 then
  begin
    SetLength(LBytes, LLen);
    AStream.ReadBuffer(LBytes[0], LLen);
    Result := TEncoding.UTF8.GetString(LBytes);
  end
  else
    Result := '';
end;

procedure TBinarySerializer.WriteInteger(AStream: TStream; AValue: Int64);
begin
  AStream.WriteBuffer(AValue, SizeOf(AValue));
end;

function TBinarySerializer.ReadInteger(AStream: TStream): Int64;
begin
  AStream.ReadBuffer(Result, SizeOf(Result));
end;

procedure TBinarySerializer.WriteFloat(AStream: TStream; AValue: Double);
begin
  AStream.WriteBuffer(AValue, SizeOf(AValue));
end;

function TBinarySerializer.ReadFloat(AStream: TStream): Double;
begin
  AStream.ReadBuffer(Result, SizeOf(Result));
end;

function TBinarySerializer.ShouldSerialize(AProp: TRttiProperty): Boolean;
var
  LAttr: TCustomAttribute;
begin
  Result := AProp.Visibility = mvPublished;
  
  for LAttr in AProp.GetAttributes do
  begin
    if LAttr is SerializeIgnoreAttribute then
      Exit(False);
    if LAttr is SerializeAttribute then
      Exit(True);
  end;
end;

procedure TBinarySerializer.WriteValue(AStream: TStream; const AValue: TValue; AContext: TSerializationContext);
var
  LKind: Byte;
begin
  if AValue.IsEmpty then
  begin
    LKind := 0;
    AStream.WriteBuffer(LKind, 1);
    Exit;
  end;
  
  LKind := Byte(AValue.Kind);
  AStream.WriteBuffer(LKind, 1);
  
  case AValue.Kind of
    tkInteger, tkInt64:
      WriteInteger(AStream, AValue.AsInt64);
      
    tkFloat:
      WriteFloat(AStream, AValue.AsExtended);
      
    tkString, tkLString, tkWString, tkUString:
      WriteString(AStream, AValue.AsString);
      
    tkEnumeration:
      WriteInteger(AStream, AValue.AsOrdinal);
      
    tkClass:
      WriteObject(AStream, AValue.AsObject, AContext);
  end;
end;

procedure TBinarySerializer.WriteObject(AStream: TStream; AObject: TObject; AContext: TSerializationContext);
var
  LType: TRttiType;
  LProp: TRttiProperty;
  LValue: TValue;
  LIsNull: Byte;
  LPropCount: Integer;
  LProps: TList<TRttiProperty>;
begin
  // Write null marker
  if not Assigned(AObject) then
  begin
    LIsNull := 1;
    AStream.WriteBuffer(LIsNull, 1);
    Exit;
  end;
  
  LIsNull := 0;
  AStream.WriteBuffer(LIsNull, 1);
  
  AContext.EnterObject(AObject);
  try
    // Write class name
    WriteString(AStream, AObject.ClassName);
    
    // Collect properties
    LProps := TList<TRttiProperty>.Create;
    try
      LType := FRttiContext.GetType(AObject.ClassType);
      for LProp in LType.GetProperties do
      begin
        if ShouldSerialize(LProp) then
          LProps.Add(LProp);
      end;
      
      // Write property count
      LPropCount := LProps.Count;
      AStream.WriteBuffer(LPropCount, SizeOf(LPropCount));
      
      // Write properties
      for LProp in LProps do
      begin
        WriteString(AStream, LProp.Name);
        LValue := LProp.GetValue(AObject);
        WriteValue(AStream, LValue, AContext);
      end;
    finally
      LProps.Free;
    end;
  finally
    AContext.LeaveObject(AObject);
  end;
end;

function TBinarySerializer.ReadValue(AStream: TStream; ATypeInfo: PTypeInfo; AContext: TSerializationContext): TValue;
var
  LKind: Byte;
begin
  AStream.ReadBuffer(LKind, 1);
  
  if LKind = 0 then
    Exit(TValue.Empty);
    
  case TTypeKind(LKind) of
    tkInteger:
      Result := TValue.From<Integer>(ReadInteger(AStream));
      
    tkInt64:
      Result := TValue.From<Int64>(ReadInteger(AStream));
      
    tkFloat:
      Result := TValue.From<Double>(ReadFloat(AStream));
      
    tkString, tkLString, tkWString, tkUString:
      Result := TValue.From<string>(ReadString(AStream));
      
    tkEnumeration:
      Result := TValue.FromOrdinal(ATypeInfo, ReadInteger(AStream));
      
    tkClass:
      begin
        if Assigned(ATypeInfo) then
          Result := TValue.From<TObject>(ReadObject(AStream, GetTypeData(ATypeInfo).ClassType, AContext))
        else
          Result := TValue.From<TObject>(ReadObject(AStream, nil, AContext));
      end;
      
    else
      Result := TValue.Empty;
  end;
end;

function TBinarySerializer.ReadObject(AStream: TStream; AClass: TClass; AContext: TSerializationContext): TObject;
var
  LIsNull: Byte;
  LClassName: string;
  LPropCount: Integer;
  I: Integer;
  LPropName: string;
  LType: TRttiType;
  LProp: TRttiProperty;
  LValue: TValue;
  LActualClass: TClass;
begin
  AStream.ReadBuffer(LIsNull, 1);
  if LIsNull = 1 then
    Exit(nil);
    
  // Read class name
  LClassName := ReadString(AStream);
  
  // Determine actual class
  if not FTypeRegistry.TryGetClass(LClassName, LActualClass) then
    LActualClass := AClass;
    
  if not Assigned(LActualClass) then
    raise ESerializationException.CreateFmt('Cannot deserialize unknown class: %s', [LClassName]);
    
  // Create instance
  LType := FRttiContext.GetType(LActualClass);
  Result := LType.AsInstance.MetaclassType.Create;
  
  AContext.EnterObject(Result);
  try
    // Read property count
    AStream.ReadBuffer(LPropCount, SizeOf(LPropCount));
    
    // Read properties
    for I := 0 to LPropCount - 1 do
    begin
      LPropName := ReadString(AStream);
      LProp := LType.GetProperty(LPropName);
      
      if Assigned(LProp) then
      begin
        LValue := ReadValue(AStream, LProp.PropertyType.Handle, AContext);
        if not LValue.IsEmpty then
          LProp.SetValue(Result, LValue);
      end
      else
        // Skip unknown property
        ReadValue(AStream, nil, AContext);
    end;
  finally
    AContext.LeaveObject(Result);
  end;
end;

function TBinarySerializer.DoSerialize(AObject: TObject; AContext: TSerializationContext): string;
var
  LStream: TMemoryStream;
begin
  LStream := TMemoryStream.Create;
  try
    WriteObject(LStream, AObject, AContext);
    Result := TNetEncoding.Base64.EncodeBytesToString(
      TBytes(LStream.Memory), LStream.Size);
  finally
    LStream.Free;
  end;
end;

function TBinarySerializer.DoDeserialize(const AData: string; AClass: TClass; AContext: TSerializationContext): TObject;
var
  LStream: TMemoryStream;
  LBytes: TBytes;
begin
  LBytes := TNetEncoding.Base64.DecodeStringToBytes(AData);
  LStream := TMemoryStream.Create;
  try
    LStream.WriteBuffer(LBytes[0], Length(LBytes));
    LStream.Position := 0;
    Result := ReadObject(LStream, AClass, AContext);
  finally
    LStream.Free;
  end;
end;

function TBinarySerializer.SerializeToBytes(AObject: TObject): TBytes;
var
  LStream: TMemoryStream;
  LContext: TSerializationContext;
begin
  LStream := TMemoryStream.Create;
  LContext := CreateContext;
  try
    WriteObject(LStream, AObject, LContext);
    SetLength(Result, LStream.Size);
    LStream.Position := 0;
    LStream.ReadBuffer(Result[0], LStream.Size);
  finally
    LContext.Free;
    LStream.Free;
  end;
end;

function TBinarySerializer.DeserializeFromBytes(const AData: TBytes; AClass: TClass): TObject;
var
  LStream: TMemoryStream;
  LContext: TSerializationContext;
begin
  LStream := TMemoryStream.Create;
  LContext := CreateContext;
  try
    LStream.WriteBuffer(AData[0], Length(AData));
    LStream.Position := 0;
    Result := ReadObject(LStream, AClass, LContext);
  finally
    LContext.Free;
    LStream.Free;
  end;
end;

{ TDateTimeConverter }

constructor TDateTimeConverter.Create(const AFormat: string);
begin
  inherited Create;
  FFormat := AFormat;
end;

function TDateTimeConverter.CanConvert(ATypeInfo: PTypeInfo): Boolean;
begin
  Result := ATypeInfo = TypeInfo(TDateTime);
end;

function TDateTimeConverter.Serialize(const AValue: TValue; AContext: TSerializationContext): TValue;
var
  LFormat: string;
begin
  LFormat := FFormat;
  if LFormat = '' then
    LFormat := AContext.Options.DateFormat;
  Result := TValue.From<string>(FormatDateTime(LFormat, AValue.AsExtended));
end;

function TDateTimeConverter.Deserialize(const AValue: TValue; ATargetType: PTypeInfo; AContext: TSerializationContext): TValue;
begin
  if AValue.TypeInfo.Kind in [tkString, tkLString, tkWString, tkUString] then
    Result := TValue.From<TDateTime>(StrToDateTime(AValue.AsString))
  else
    Result := TValue.From<TDateTime>(AValue.AsExtended);
end;

{ TEnumConverter }

function TEnumConverter.CanConvert(ATypeInfo: PTypeInfo): Boolean;
begin
  Result := (ATypeInfo.Kind = tkEnumeration) and (ATypeInfo <> TypeInfo(Boolean));
end;

function TEnumConverter.Serialize(const AValue: TValue; AContext: TSerializationContext): TValue;
begin
  if AContext.Options.EnumAsString then
    Result := TValue.From<string>(GetEnumName(AValue.TypeInfo, AValue.AsOrdinal))
  else
    Result := TValue.From<Int64>(AValue.AsOrdinal);
end;

function TEnumConverter.Deserialize(const AValue: TValue; ATargetType: PTypeInfo; AContext: TSerializationContext): TValue;
begin
  if AValue.TypeInfo.Kind in [tkString, tkLString, tkWString, tkUString] then
    Result := TValue.FromOrdinal(ATargetType, GetEnumValue(ATargetType, AValue.AsString))
  else
    Result := TValue.FromOrdinal(ATargetType, AValue.AsInt64);
end;

{ TSerializer }

class constructor TSerializer.Create;
begin
  FLock := TCriticalSection.Create;
end;

class destructor TSerializer.Destroy;
begin
  FJsonSerializer := nil;
  FXmlSerializer := nil;
  FreeAndNil(FBinarySerializer);
  FreeAndNil(FLock);
end;

class function TSerializer.GetJson: ISerializer;
begin
  if not Assigned(FJsonSerializer) then
  begin
    FLock.Enter;
    try
      if not Assigned(FJsonSerializer) then
        FJsonSerializer := TJsonSerializer.Create;
    finally
      FLock.Leave;
    end;
  end;
  Result := FJsonSerializer;
end;

class function TSerializer.GetXml: ISerializer;
begin
  if not Assigned(FXmlSerializer) then
  begin
    FLock.Enter;
    try
      if not Assigned(FXmlSerializer) then
        FXmlSerializer := TXmlSerializer.Create;
    finally
      FLock.Leave;
    end;
  end;
  Result := FXmlSerializer;
end;

class function TSerializer.GetBinary: TBinarySerializer;
begin
  if not Assigned(FBinarySerializer) then
  begin
    FLock.Enter;
    try
      if not Assigned(FBinarySerializer) then
        FBinarySerializer := TBinarySerializer.Create;
    finally
      FLock.Leave;
    end;
  end;
  Result := FBinarySerializer;
end;

class function TSerializer.ToJson<T>(const AValue: T): string;
var
  LSer: TJsonSerializer;
begin
  LSer := TJsonSerializer.Create;
  try
    Result := LSer.Serialize<T>(AValue);
  finally
    LSer.Free;
  end;
end;

class function TSerializer.ToJson(AObject: TObject): string;
begin
  Result := Json.Serialize(AObject);
end;

class function TSerializer.ToJson<T>(const AValue: T; const AOptions: TSerializationOptions): string;
var
  LSer: TJsonSerializer;
begin
  LSer := TJsonSerializer.Create;
  try
    LSer.Options := AOptions;
    Result := LSer.Serialize<T>(AValue);
  finally
    LSer.Free;
  end;
end;

class function TSerializer.FromJson<T>(const AJson: string): T;
var
  LSer: TJsonSerializer;
begin
  LSer := TJsonSerializer.Create;
  try
    Result := LSer.Deserialize<T>(AJson);
  finally
    LSer.Free;
  end;
end;

class function TSerializer.FromJson(const AJson: string; AClass: TClass): TObject;
begin
  Result := Json.Deserialize(AJson, AClass);
end;

class function TSerializer.ToXml<T>(const AValue: T): string;
var
  LSer: TXmlSerializer;
begin
  LSer := TXmlSerializer.Create;
  try
    Result := LSer.Serialize<T>(AValue);
  finally
    LSer.Free;
  end;
end;

class function TSerializer.ToXml(AObject: TObject): string;
begin
  Result := Xml.Serialize(AObject);
end;

class function TSerializer.FromXml<T>(const AXml: string): T;
var
  LSer: TXmlSerializer;
begin
  LSer := TXmlSerializer.Create;
  try
    Result := LSer.Deserialize<T>(AXml);
  finally
    LSer.Free;
  end;
end;

class function TSerializer.FromXml(const AXml: string; AClass: TClass): TObject;
begin
  Result := Xml.Deserialize(AXml, AClass);
end;

class function TSerializer.ToBytes(AObject: TObject): TBytes;
begin
  Result := Binary.SerializeToBytes(AObject);
end;

class function TSerializer.FromBytes(const AData: TBytes; AClass: TClass): TObject;
begin
  Result := Binary.DeserializeFromBytes(AData, AClass);
end;

class function TSerializer.Clone<T>(AObject: T): T;
var
  LData: TBytes;
begin
  LData := ToBytes(AObject);
  Result := T(FromBytes(LData, TObject(AObject).ClassType));
end;

{ TSerializerBuilder }

constructor TSerializerBuilder.Create(AFormat: TSerializationFormat);
begin
  inherited Create;
  FFormat := AFormat;
  FOptions := TSerializationOptions.Default;
  FConverters := TList<IValueConverter>.Create;
  FTypes := TList<TPair<TClass, string>>.Create;
end;

destructor TSerializerBuilder.Destroy;
begin
  FreeAndNil(FTypes);
  FreeAndNil(FConverters);
  inherited;
end;

function TSerializerBuilder.WithPrettyPrint(AEnabled: Boolean): TSerializerBuilder;
begin
  FOptions.PrettyPrint := AEnabled;
  Result := Self;
end;

function TSerializerBuilder.WithIndentSize(ASize: Integer): TSerializerBuilder;
begin
  FOptions.IndentSize := ASize;
  Result := Self;
end;

function TSerializerBuilder.WithCamelCase(AEnabled: Boolean): TSerializerBuilder;
begin
  FOptions.UseCamelCase := AEnabled;
  Result := Self;
end;

function TSerializerBuilder.WithNulls(AInclude: Boolean): TSerializerBuilder;
begin
  FOptions.IncludeNulls := AInclude;
  Result := Self;
end;

function TSerializerBuilder.WithDefaults(AInclude: Boolean): TSerializerBuilder;
begin
  FOptions.IncludeDefaults := AInclude;
  Result := Self;
end;

function TSerializerBuilder.WithDateFormat(const AFormat: string): TSerializerBuilder;
begin
  FOptions.DateFormat := AFormat;
  Result := Self;
end;

function TSerializerBuilder.WithEnumAsString(AEnabled: Boolean): TSerializerBuilder;
begin
  FOptions.EnumAsString := AEnabled;
  Result := Self;
end;

function TSerializerBuilder.WithMaxDepth(ADepth: Integer): TSerializerBuilder;
begin
  FOptions.MaxDepth := ADepth;
  Result := Self;
end;

function TSerializerBuilder.WithConverter(AConverter: IValueConverter): TSerializerBuilder;
begin
  FConverters.Add(AConverter);
  Result := Self;
end;

function TSerializerBuilder.WithType(AClass: TClass; const ATypeName: string): TSerializerBuilder;
begin
  FTypes.Add(TPair<TClass, string>.Create(AClass, ATypeName));
  Result := Self;
end;

function TSerializerBuilder.Build: ISerializer;
var
  LSer: TBaseSerializer;
begin
  case FFormat of
    sfJSON: LSer := TJsonSerializer.Create;
    sfXML: LSer := TXmlSerializer.Create;
    sfBinary: LSer := TBinarySerializer.Create;
  else
    raise ESerializationException.Create('Unknown format');
  end;
  
  LSer.Options := FOptions;
  
  for var LConv in FConverters do
    LSer.AddConverter(LConv);
    
  for var LType in FTypes do
    LSer.RegisterType(LType.Key, LType.Value);
    
  Result := LSer;
end;

// 安全相关的辅助函数实现
function TSerializationContext.IsClassAllowed(const AClassName: string; const AAllowedClasses: TArray<string>): Boolean;
var
  AllowedClass: string;
begin
  Result := False;
  for AllowedClass in AAllowedClasses do
  begin
    if SameText(AClassName, AllowedClass) then
    begin
      Result := True;
      Break;
    end;
  end;
end;

function TSerializationContext.GetAllowedClasses: TArray<string>;
begin
  // 定义允许反序列化的安全类列表
  Result := [
    'TObject',
    'TStringList',
    'TList',
    'TDictionary',
    'TArray',
    'TDateTime',
    'TDate',
    'TTime',
    'TGuid',
    'TPoint',
    'TRect',
    'TSize',
    // 添加项目特定的安全类
    'TDeepBaseConfig',
    'TConfigItem',
    'TLogEntry',
    'TMetricData',
    'TUserInfo',
    'TSessionInfo'
  ];
  
  // 还可以从配置文件或注册表中读取额外的允许类列表
  // 但默认应该是最小权限原则
end;

end.
