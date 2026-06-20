unit DeepBase.Reflection;

{*******************************************************************************
  DeepBase Reflection/RTTI Utilities
  A comprehensive reflection module with:
  - Extended RTTI property and field access
  - Dynamic method invocation
  - Type information utilities
  - Object cloning and comparison
  - Attribute handling
  - Type registry for factory patterns
  
  Author: DeepBase Team
  Created: 2025-11-29
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.TypInfo, System.Rtti,
  System.Generics.Collections, System.SyncObjs;

type
  EReflectionException = class(Exception);

  /// <summary>Property access mode</summary>
  TPropertyAccess = (paRead, paWrite, paReadWrite);

  /// <summary>Member visibility</summary>
  TMemberVisibility = (mvPrivate, mvProtected, mvPublic, mvPublished);
  TMemberVisibilities = set of TMemberVisibility;

  /// <summary>Property info record</summary>
  TPropertyInfoEx = record
    Name: string;
    TypeName: string;
    TypeKind: TTypeKind;
    Access: TPropertyAccess;
    Visibility: TMemberVisibility;
    HasDefault: Boolean;
    DefaultValue: TValue;
    
    function IsReadable: Boolean;
    function IsWritable: Boolean;
  end;

  /// <summary>Field info record</summary>
  TFieldInfoEx = record
    Name: string;
    TypeName: string;
    TypeKind: TTypeKind;
    Offset: Integer;
    Visibility: TMemberVisibility;
  end;

  /// <summary>Method info record</summary>
  TMethodInfoEx = record
    Name: string;
    ReturnType: string;
    IsFunction: Boolean;
    IsClassMethod: Boolean;
    IsStatic: Boolean;
    Visibility: TMemberVisibility;
    ParameterCount: Integer;
    Parameters: TArray<string>;
  end;

  /// <summary>Type info utilities</summary>
  TTypeInfo = class
  private
    class var FContext: TRttiContext;
    class var FLock: TCriticalSection;
    class constructor Create;
    class destructor Destroy;
  public
    /// <summary>Get RTTI context (shared)</summary>
    class function Context: TRttiContext; static;
    
    /// <summary>Get type by name</summary>
    class function GetType(const ATypeName: string): TRttiType; overload; static;
    class function GetType<T>: TRttiType; overload; static;
    class function GetTypeByClass(AClass: TClass): TRttiType; static;
    
    /// <summary>Get type kind</summary>
    class function GetKind<T>: TTypeKind; static;
    class function GetKindName(AKind: TTypeKind): string; static;
    
    /// <summary>Type checks</summary>
    class function IsClass<T>: Boolean; static;
    class function IsRecord<T>: Boolean; static;
    class function IsInterface<T>: Boolean; static;
    class function IsOrdinal<T>: Boolean; static;
    class function IsNumeric<T>: Boolean; static;
    class function IsString<T>: Boolean; static;
    
    /// <summary>Get type name</summary>
    class function GetName<T>: string; static;
    class function GetFullName<T>: string; static;
    
    /// <summary>Get type size</summary>
    class function GetSize<T>: Integer; static;
    
    /// <summary>Check assignability</summary>
    class function IsAssignableFrom(ATarget, ASource: TRttiType): Boolean; overload; static;
    class function IsAssignableFrom<TTarget, TSource>: Boolean; overload; static;
    
    /// <summary>Get base types</summary>
    class function GetBaseTypes(AType: TRttiType): TArray<TRttiType>; static;
    class function GetInterfaces(AType: TRttiType): TArray<TRttiInterfaceType>; static;
  end;

  /// <summary>Property access utilities</summary>
  TPropertyAccess_ = class
  public
    /// <summary>Get property value</summary>
    class function GetValue(AInstance: TObject; const APropertyName: string): TValue; overload; static;
    class function GetValue<T>(AInstance: TObject; const APropertyName: string): T; overload; static;
    class function TryGetValue(AInstance: TObject; const APropertyName: string; out AValue: TValue): Boolean; static;
    
    /// <summary>Set property value</summary>
    class procedure SetValue(AInstance: TObject; const APropertyName: string; const AValue: TValue); overload; static;
    class procedure SetValue<T>(AInstance: TObject; const APropertyName: string; const AValue: T); overload; static;
    class function TrySetValue(AInstance: TObject; const APropertyName: string; const AValue: TValue): Boolean; static;
    
    /// <summary>Check property existence</summary>
    class function HasProperty(AInstance: TObject; const APropertyName: string): Boolean; overload; static;
    class function HasProperty(AClass: TClass; const APropertyName: string): Boolean; overload; static;
    
    /// <summary>Get property info</summary>
    class function GetPropertyInfo(AInstance: TObject; const APropertyName: string): TPropertyInfoEx; static;
    class function GetProperties(AInstance: TObject; AVisibilities: TMemberVisibilities = [mvPublic, mvPublished]): TArray<TPropertyInfoEx>; overload; static;
    class function GetProperties(AClass: TClass; AVisibilities: TMemberVisibilities = [mvPublic, mvPublished]): TArray<TPropertyInfoEx>; overload; static;
    
    /// <summary>Get property names</summary>
    class function GetPropertyNames(AInstance: TObject): TArray<string>; overload; static;
    class function GetPropertyNames(AClass: TClass): TArray<string>; overload; static;
    
    /// <summary>Copy properties</summary>
    class procedure CopyProperties(ASource, ATarget: TObject; const AExclude: TArray<string> = nil); static;
  end;

  /// <summary>Field access utilities</summary>
  TFieldAccess = class
  public
    /// <summary>Get field value</summary>
    class function GetValue(AInstance: TObject; const AFieldName: string): TValue; overload; static;
    class function GetValue<T>(AInstance: TObject; const AFieldName: string): T; overload; static;
    class function TryGetValue(AInstance: TObject; const AFieldName: string; out AValue: TValue): Boolean; static;
    
    /// <summary>Set field value</summary>
    class procedure SetValue(AInstance: TObject; const AFieldName: string; const AValue: TValue); overload; static;
    class procedure SetValue<T>(AInstance: TObject; const AFieldName: string; const AValue: T); overload; static;
    class function TrySetValue(AInstance: TObject; const AFieldName: string; const AValue: TValue): Boolean; static;
    
    /// <summary>Check field existence</summary>
    class function HasField(AInstance: TObject; const AFieldName: string): Boolean; overload; static;
    class function HasField(AClass: TClass; const AFieldName: string): Boolean; overload; static;
    
    /// <summary>Get field info</summary>
    class function GetFieldInfo(AInstance: TObject; const AFieldName: string): TFieldInfoEx; static;
    class function GetFields(AInstance: TObject; AVisibilities: TMemberVisibilities = [mvPublic, mvPublished]): TArray<TFieldInfoEx>; overload; static;
    class function GetFields(AClass: TClass; AVisibilities: TMemberVisibilities = [mvPublic, mvPublished]): TArray<TFieldInfoEx>; overload; static;
  end;

  /// <summary>Method invocation utilities</summary>
  TMethodInvoke = class
  public
    /// <summary>Invoke method</summary>
    class function Invoke(AInstance: TObject; const AMethodName: string; 
      const AArgs: array of TValue): TValue; static;
    class function TryInvoke(AInstance: TObject; const AMethodName: string;
      const AArgs: array of TValue; out AResult: TValue): Boolean; static;
    
    /// <summary>Invoke class method</summary>
    class function InvokeClass(AClass: TClass; const AMethodName: string;
      const AArgs: array of TValue): TValue; static;
    
    /// <summary>Check method existence</summary>
    class function HasMethod(AInstance: TObject; const AMethodName: string): Boolean; overload; static;
    class function HasMethod(AClass: TClass; const AMethodName: string): Boolean; overload; static;
    
    /// <summary>Get method info</summary>
    class function GetMethodInfo(AInstance: TObject; const AMethodName: string): TMethodInfoEx; static;
    class function GetMethods(AInstance: TObject; AVisibilities: TMemberVisibilities = [mvPublic, mvPublished]): TArray<TMethodInfoEx>; overload; static;
    class function GetMethods(AClass: TClass; AVisibilities: TMemberVisibilities = [mvPublic, mvPublished]): TArray<TMethodInfoEx>; overload; static;
  end;

  /// <summary>Attribute utilities</summary>
  TAttributeUtils = class
  public
    /// <summary>Get attribute from type</summary>
    class function GetAttribute<T: TCustomAttribute>(AType: TRttiType): T; overload; static;
    class function GetAttribute<T: TCustomAttribute>(AClass: TClass): T; overload; static;
    class function GetAttributes<T: TCustomAttribute>(AType: TRttiType): TArray<T>; overload; static;
    class function GetAttributes<T: TCustomAttribute>(AClass: TClass): TArray<T>; overload; static;
    
    /// <summary>Get attribute from property</summary>
    class function GetPropertyAttribute<T: TCustomAttribute>(AClass: TClass; const APropertyName: string): T; static;
    class function GetPropertyAttributes<T: TCustomAttribute>(AClass: TClass; const APropertyName: string): TArray<T>; static;
    
    /// <summary>Get attribute from method</summary>
    class function GetMethodAttribute<T: TCustomAttribute>(AClass: TClass; const AMethodName: string): T; static;
    
    /// <summary>Check attribute existence</summary>
    class function HasAttribute<T: TCustomAttribute>(AType: TRttiType): Boolean; overload; static;
    class function HasAttribute<T: TCustomAttribute>(AClass: TClass): Boolean; overload; static;
    class function HasPropertyAttribute<T: TCustomAttribute>(AClass: TClass; const APropertyName: string): Boolean; static;
    
    /// <summary>Get all attributes</summary>
    class function GetAllAttributes(AType: TRttiType): TArray<TCustomAttribute>; static;
  end;

  /// <summary>Object utilities</summary>
  TObjectUtils = class
  public
    /// <summary>Clone object (shallow)</summary>
    class function Clone<T: class>(ASource: T): T; static;
    
    /// <summary>Deep clone object</summary>
    class function DeepClone<T: class>(ASource: T): T; static;
    
    /// <summary>Compare objects by properties</summary>
    class function Equals(AObj1, AObj2: TObject; const AExclude: TArray<string> = nil): Boolean; static;
    
    /// <summary>Get differences between objects</summary>
    class function GetDifferences(AObj1, AObj2: TObject): TArray<string>; static;
    
    /// <summary>Convert to dictionary</summary>
    class function ToDictionary(AInstance: TObject): TDictionary<string, TValue>; static;
    
    /// <summary>Populate from dictionary</summary>
    class procedure FromDictionary(AInstance: TObject; const AValues: TDictionary<string, TValue>); static;
    
    /// <summary>Create instance</summary>
    class function CreateInstance(AClass: TClass): TObject; overload; static;
    class function CreateInstance(AClass: TClass; const AArgs: array of TValue): TObject; overload; static;
    class function CreateInstance<T: class>: T; overload; static;
    class function CreateInstance<T: class>(const AArgs: array of TValue): T; overload; static;
    
    /// <summary>Safe cast</summary>
    class function SafeCast<T: class>(AInstance: TObject): T; static;
    class function TryCast<T: class>(AInstance: TObject; out AResult: T): Boolean; static;
  end;

  /// <summary>Type registry for factory pattern</summary>
  TTypeRegistry = class
  private
    class var FRegistry: TDictionary<string, TClass>;
    class var FLock: TCriticalSection;
    class constructor Create;
    class destructor Destroy;
  public
    /// <summary>Register type</summary>
    class procedure RegisterType(const AName: string; AClass: TClass); overload; static;
    class procedure RegisterType<T: class>; overload; static;
    class procedure RegisterType<T: class>(const AName: string); overload; static;
    
    /// <summary>Unregister type</summary>
    class procedure UnregisterType(const AName: string); static;
    
    /// <summary>Create instance by name</summary>
    class function CreateInstance(const AName: string): TObject; overload; static;
    class function CreateInstance(const AName: string; const AArgs: array of TValue): TObject; overload; static;
    class function CreateInstance<T: class>(const AName: string): T; overload; static;
    
    /// <summary>Get registered class</summary>
    class function GetClass(const AName: string): TClass; static;
    class function TryGetClass(const AName: string; out AClass: TClass): Boolean; static;
    
    /// <summary>Check registration</summary>
    class function IsRegistered(const AName: string): Boolean; static;
    
    /// <summary>Get all registered names</summary>
    class function GetRegisteredNames: TArray<string>; static;
    
    /// <summary>Clear registry</summary>
    class procedure Clear; static;
  end;

  /// <summary>Value conversion utilities</summary>
  TValueConverter = class
  public
    /// <summary>Convert TValue to type</summary>
    class function Convert<T>(const AValue: TValue): T; static;
    class function TryConvert<T>(const AValue: TValue; out AResult: T): Boolean; static;
    
    /// <summary>Convert between types</summary>
    class function ConvertTo(const AValue: TValue; ATargetType: TRttiType): TValue; static;
    
    /// <summary>From/To string</summary>
    class function ToString(const AValue: TValue): string; static;
    class function FromString(const AValue: string; ATargetType: TRttiType): TValue; overload; static;
    class function FromString<T>(const AValue: string): T; overload; static;
    
    /// <summary>Check convertibility</summary>
    class function CanConvert(const AValue: TValue; ATargetType: TRttiType): Boolean; overload; static;
    class function CanConvert<TSource, TTarget>: Boolean; overload; static;
  end;

  /// <summary>Enum utilities</summary>
  TEnumUtils = class
  public
    /// <summary>Get enum name</summary>
    class function GetName<T>(AValue: T): string; static;
    
    /// <summary>Get enum value from name</summary>
    class function GetValue<T>(const AName: string): T; static;
    class function TryGetValue<T>(const AName: string; out AValue: T): Boolean; static;
    
    /// <summary>Get all enum names</summary>
    class function GetNames<T>: TArray<string>; static;
    
    /// <summary>Get all enum values</summary>
    class function GetValues<T>: TArray<T>; static;
    
    /// <summary>Get enum count</summary>
    class function GetCount<T>: Integer; static;
    
    /// <summary>Get ordinal value</summary>
    class function GetOrdinal<T>(AValue: T): Integer; static;
    
    /// <summary>Get value from ordinal</summary>
    class function FromOrdinal<T>(AOrdinal: Integer): T; static;
  end;

  /// <summary>Generic list utilities</summary>
  TListUtils = class
  public
    /// <summary>Get list item type</summary>
    class function GetItemType(AList: TObject): TRttiType; static;
    
    /// <summary>Get list count</summary>
    class function GetCount(AList: TObject): Integer; static;
    
    /// <summary>Get item at index</summary>
    class function GetItem(AList: TObject; AIndex: Integer): TValue; static;
    
    /// <summary>Add item</summary>
    class procedure AddItem(AList: TObject; const AValue: TValue); static;
    
    /// <summary>Clear list</summary>
    class procedure Clear(AList: TObject); static;
    
    /// <summary>Check if is generic list</summary>
    class function IsList(AType: TRttiType): Boolean; overload; static;
    class function IsList(AInstance: TObject): Boolean; overload; static;
  end;

  /// <summary>Static helper shortcut</summary>
  TReflect = class
  public
    // Type info
    class function GetType<T>: TRttiType; static;
    class function GetTypeName<T>: string; static;
    
    // Property access
    class function GetProp(AObj: TObject; const AProp: string): TValue; overload; static;
    class function GetProp<T>(AObj: TObject; const AProp: string): T; overload; static;
    class procedure SetProp(AObj: TObject; const AProp: string; const AValue: TValue); overload; static;
    class procedure SetProp<T>(AObj: TObject; const AProp: string; const AValue: T); overload; static;
    class function HasProp(AObj: TObject; const AProp: string): Boolean; static;
    
    // Field access
    class function GetField(AObj: TObject; const AField: string): TValue; overload; static;
    class function GetField<T>(AObj: TObject; const AField: string): T; overload; static;
    class procedure SetField(AObj: TObject; const AField: string; const AValue: TValue); overload; static;
    class procedure SetField<T>(AObj: TObject; const AField: string; const AValue: T); overload; static;
    
    // Method invoke
    class function Call(AObj: TObject; const AMethod: string; const AArgs: array of TValue): TValue; static;
    class function HasMethod(AObj: TObject; const AMethod: string): Boolean; static;
    
    // Object utils
    class function Clone<T: class>(AObj: T): T; static;
    class function Make<T: class>: T; overload; static;
    class function Make<T: class>(const AArgs: array of TValue): T; overload; static;
  end;

implementation

{ TPropertyInfoEx }

function TPropertyInfoEx.IsReadable: Boolean;
begin
  Result := Access in [paRead, paReadWrite];
end;

function TPropertyInfoEx.IsWritable: Boolean;
begin
  Result := Access in [paWrite, paReadWrite];
end;

{ TTypeInfo }

class constructor TTypeInfo.Create;
begin
  FLock := TCriticalSection.Create;
  FContext := TRttiContext.Create;
end;

class destructor TTypeInfo.Destroy;
begin
  FContext.Free;
  FreeAndNil(FLock);
end;

class function TTypeInfo.Context: TRttiContext;
begin
  Result := FContext;
end;

class function TTypeInfo.GetType(const ATypeName: string): TRttiType;
begin
  FLock.Enter;
  try
    Result := FContext.FindType(ATypeName);
  finally
    FLock.Leave;
  end;
end;

class function TTypeInfo.GetType<T>: TRttiType;
begin
  FLock.Enter;
  try
    Result := FContext.GetType(TypeInfo(T));
  finally
    FLock.Leave;
  end;
end;

class function TTypeInfo.GetTypeByClass(AClass: TClass): TRttiType;
begin
  FLock.Enter;
  try
    Result := FContext.GetType(AClass);
  finally
    FLock.Leave;
  end;
end;

class function TTypeInfo.GetKind<T>: TTypeKind;
var
  LInfo: PTypeInfo;
begin
  LInfo := TypeInfo(T);
  if Assigned(LInfo) then
    Result := LInfo.Kind
  else
    Result := tkUnknown;
end;

class function TTypeInfo.GetKindName(AKind: TTypeKind): string;
begin
  Result := System.TypInfo.GetEnumName(TypeInfo(TTypeKind), Ord(AKind));
end;

class function TTypeInfo.IsClass<T>: Boolean;
begin
  Result := GetKind<T> = tkClass;
end;

class function TTypeInfo.IsRecord<T>: Boolean;
begin
  Result := GetKind<T> = tkRecord;
end;

class function TTypeInfo.IsInterface<T>: Boolean;
begin
  Result := GetKind<T> = tkInterface;
end;

class function TTypeInfo.IsOrdinal<T>: Boolean;
begin
  Result := GetKind<T> in [tkInteger, tkChar, tkEnumeration, tkWChar, tkInt64];
end;

class function TTypeInfo.IsNumeric<T>: Boolean;
begin
  Result := GetKind<T> in [tkInteger, tkFloat, tkInt64];
end;

class function TTypeInfo.IsString<T>: Boolean;
begin
  Result := GetKind<T> in [tkString, tkLString, tkWString, tkUString];
end;

class function TTypeInfo.GetName<T>: string;
var
  LInfo: PTypeInfo;
begin
  LInfo := TypeInfo(T);
  if Assigned(LInfo) then
    Result := string(LInfo.Name)
  else
    Result := '';
end;

class function TTypeInfo.GetFullName<T>: string;
var
  LType: TRttiType;
begin
  LType := GetType<T>;
  if Assigned(LType) then
    Result := LType.QualifiedName
  else
    Result := GetName<T>;
end;

class function TTypeInfo.GetSize<T>: Integer;
begin
  Result := SizeOf(T);
end;

class function TTypeInfo.IsAssignableFrom(ATarget, ASource: TRttiType): Boolean;
begin
  if (ATarget = nil) or (ASource = nil) then
    Exit(False);
    
  if ATarget = ASource then
    Exit(True);
    
  if (ATarget is TRttiInstanceType) and (ASource is TRttiInstanceType) then
    Result := TRttiInstanceType(ASource).MetaclassType.InheritsFrom(
      TRttiInstanceType(ATarget).MetaclassType)
  else
    Result := False;
end;

class function TTypeInfo.IsAssignableFrom<TTarget, TSource>: Boolean;
begin
  Result := IsAssignableFrom(GetType<TTarget>, GetType<TSource>);
end;

class function TTypeInfo.GetBaseTypes(AType: TRttiType): TArray<TRttiType>;
var
  LList: TList<TRttiType>;
  LCurrent: TRttiType;
begin
  LList := TList<TRttiType>.Create;
  try
    LCurrent := AType;
    while LCurrent <> nil do
    begin
      LList.Add(LCurrent);
      if LCurrent is TRttiInstanceType then
        LCurrent := TRttiInstanceType(LCurrent).BaseType
      else
        LCurrent := nil;
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

class function TTypeInfo.GetInterfaces(AType: TRttiType): TArray<TRttiInterfaceType>;
var
  LList: TList<TRttiInterfaceType>;
  LIntf: TRttiInterfaceType;
begin
  LList := TList<TRttiInterfaceType>.Create;
  try
    if AType is TRttiInstanceType then
    begin
      for LIntf in TRttiInstanceType(AType).GetImplementedInterfaces do
        LList.Add(LIntf);
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

{ TPropertyAccess_ }

class function TPropertyAccess_.GetValue(AInstance: TObject; const APropertyName: string): TValue;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
begin
  LContext := TTypeInfo.Context;
  LType := LContext.GetType(AInstance.ClassType);
  if LType = nil then
    raise EReflectionException.CreateFmt('Type not found for %s', [AInstance.ClassName]);
    
  LProp := LType.GetProperty(APropertyName);
  if LProp = nil then
    raise EReflectionException.CreateFmt('Property %s not found in %s', [APropertyName, AInstance.ClassName]);
    
  if not LProp.IsReadable then
    raise EReflectionException.CreateFmt('Property %s is not readable', [APropertyName]);
    
  Result := LProp.GetValue(AInstance);
end;

class function TPropertyAccess_.GetValue<T>(AInstance: TObject; const APropertyName: string): T;
begin
  Result := GetValue(AInstance, APropertyName).AsType<T>;
end;

class function TPropertyAccess_.TryGetValue(AInstance: TObject; const APropertyName: string; out AValue: TValue): Boolean;
begin
  try
    AValue := GetValue(AInstance, APropertyName);
    Result := True;
  except
    Result := False;
  end;
end;

class procedure TPropertyAccess_.SetValue(AInstance: TObject; const APropertyName: string; const AValue: TValue);
var
  LContext: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
begin
  LContext := TTypeInfo.Context;
  LType := LContext.GetType(AInstance.ClassType);
  if LType = nil then
    raise EReflectionException.CreateFmt('Type not found for %s', [AInstance.ClassName]);
    
  LProp := LType.GetProperty(APropertyName);
  if LProp = nil then
    raise EReflectionException.CreateFmt('Property %s not found in %s', [APropertyName, AInstance.ClassName]);
    
  if not LProp.IsWritable then
    raise EReflectionException.CreateFmt('Property %s is not writable', [APropertyName]);
    
  LProp.SetValue(AInstance, AValue);
end;

class procedure TPropertyAccess_.SetValue<T>(AInstance: TObject; const APropertyName: string; const AValue: T);
begin
  SetValue(AInstance, APropertyName, TValue.From<T>(AValue));
end;

class function TPropertyAccess_.TrySetValue(AInstance: TObject; const APropertyName: string; const AValue: TValue): Boolean;
begin
  try
    SetValue(AInstance, APropertyName, AValue);
    Result := True;
  except
    Result := False;
  end;
end;

class function TPropertyAccess_.HasProperty(AInstance: TObject; const APropertyName: string): Boolean;
begin
  Result := HasProperty(AInstance.ClassType, APropertyName);
end;

class function TPropertyAccess_.HasProperty(AClass: TClass; const APropertyName: string): Boolean;
var
  LContext: TRttiContext;
  LType: TRttiType;
begin
  LContext := TTypeInfo.Context;
  LType := LContext.GetType(AClass);
  Result := (LType <> nil) and (LType.GetProperty(APropertyName) <> nil);
end;

class function TPropertyAccess_.GetPropertyInfo(AInstance: TObject; const APropertyName: string): TPropertyInfoEx;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
begin
  LContext := TTypeInfo.Context;
  LType := LContext.GetType(AInstance.ClassType);
  if LType = nil then
    raise EReflectionException.CreateFmt('Type not found for %s', [AInstance.ClassName]);
    
  LProp := LType.GetProperty(APropertyName);
  if LProp = nil then
    raise EReflectionException.CreateFmt('Property %s not found', [APropertyName]);
    
  Result.Name := LProp.Name;
  Result.TypeName := LProp.PropertyType.Name;
  Result.TypeKind := LProp.PropertyType.TypeKind;
  
  if LProp.IsReadable and LProp.IsWritable then
    Result.Access := paReadWrite
  else if LProp.IsReadable then
    Result.Access := paRead
  else
    Result.Access := paWrite;
    
  Result.Visibility := TMemberVisibility(LProp.Visibility);
  Result.HasDefault := False;
end;

class function TPropertyAccess_.GetProperties(AInstance: TObject; AVisibilities: TMemberVisibilities): TArray<TPropertyInfoEx>;
begin
  Result := GetProperties(AInstance.ClassType, AVisibilities);
end;

class function TPropertyAccess_.GetProperties(AClass: TClass; AVisibilities: TMemberVisibilities): TArray<TPropertyInfoEx>;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
  LList: TList<TPropertyInfoEx>;
  LInfo: TPropertyInfoEx;
begin
  LList := TList<TPropertyInfoEx>.Create;
  try
    LContext := TTypeInfo.Context;
    LType := LContext.GetType(AClass);
    if LType <> nil then
    begin
      for LProp in LType.GetProperties do
      begin
        if TMemberVisibility(LProp.Visibility) in AVisibilities then
        begin
          LInfo.Name := LProp.Name;
          LInfo.TypeName := LProp.PropertyType.Name;
          LInfo.TypeKind := LProp.PropertyType.TypeKind;
          
          if LProp.IsReadable and LProp.IsWritable then
            LInfo.Access := paReadWrite
          else if LProp.IsReadable then
            LInfo.Access := paRead
          else
            LInfo.Access := paWrite;
            
          LInfo.Visibility := TMemberVisibility(LProp.Visibility);
          LInfo.HasDefault := False;
          LList.Add(LInfo);
        end;
      end;
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

class function TPropertyAccess_.GetPropertyNames(AInstance: TObject): TArray<string>;
begin
  Result := GetPropertyNames(AInstance.ClassType);
end;

class function TPropertyAccess_.GetPropertyNames(AClass: TClass): TArray<string>;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
  LList: TList<string>;
begin
  LList := TList<string>.Create;
  try
    LContext := TTypeInfo.Context;
    LType := LContext.GetType(AClass);
    if LType <> nil then
    begin
      for LProp in LType.GetProperties do
        LList.Add(LProp.Name);
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

class procedure TPropertyAccess_.CopyProperties(ASource, ATarget: TObject; const AExclude: TArray<string>);
var
  LContext: TRttiContext;
  LSourceType, LTargetType: TRttiType;
  LSourceProp, LTargetProp: TRttiProperty;
  LExcludeSet: TDictionary<string, Boolean>;
  LName: string;
begin
  LExcludeSet := TDictionary<string, Boolean>.Create;
  try
    for LName in AExclude do
      LExcludeSet.AddOrSetValue(LName.ToLower, True);
      
    LContext := TTypeInfo.Context;
    LSourceType := LContext.GetType(ASource.ClassType);
    LTargetType := LContext.GetType(ATarget.ClassType);
    
    if (LSourceType = nil) or (LTargetType = nil) then
      Exit;
      
    for LSourceProp in LSourceType.GetProperties do
    begin
      if LExcludeSet.ContainsKey(LSourceProp.Name.ToLower) then
        Continue;
        
      if not LSourceProp.IsReadable then
        Continue;
        
      LTargetProp := LTargetType.GetProperty(LSourceProp.Name);
      if (LTargetProp <> nil) and LTargetProp.IsWritable then
        LTargetProp.SetValue(ATarget, LSourceProp.GetValue(ASource));
    end;
  finally
    LExcludeSet.Free;
  end;
end;

{ TFieldAccess }

class function TFieldAccess.GetValue(AInstance: TObject; const AFieldName: string): TValue;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LField: TRttiField;
begin
  LContext := TTypeInfo.Context;
  LType := LContext.GetType(AInstance.ClassType);
  if LType = nil then
    raise EReflectionException.CreateFmt('Type not found for %s', [AInstance.ClassName]);
    
  LField := LType.GetField(AFieldName);
  if LField = nil then
    raise EReflectionException.CreateFmt('Field %s not found in %s', [AFieldName, AInstance.ClassName]);
    
  Result := LField.GetValue(AInstance);
end;

class function TFieldAccess.GetValue<T>(AInstance: TObject; const AFieldName: string): T;
begin
  Result := GetValue(AInstance, AFieldName).AsType<T>;
end;

class function TFieldAccess.TryGetValue(AInstance: TObject; const AFieldName: string; out AValue: TValue): Boolean;
begin
  try
    AValue := GetValue(AInstance, AFieldName);
    Result := True;
  except
    Result := False;
  end;
end;

class procedure TFieldAccess.SetValue(AInstance: TObject; const AFieldName: string; const AValue: TValue);
var
  LContext: TRttiContext;
  LType: TRttiType;
  LField: TRttiField;
begin
  LContext := TTypeInfo.Context;
  LType := LContext.GetType(AInstance.ClassType);
  if LType = nil then
    raise EReflectionException.CreateFmt('Type not found for %s', [AInstance.ClassName]);
    
  LField := LType.GetField(AFieldName);
  if LField = nil then
    raise EReflectionException.CreateFmt('Field %s not found in %s', [AFieldName, AInstance.ClassName]);
    
  LField.SetValue(AInstance, AValue);
end;

class procedure TFieldAccess.SetValue<T>(AInstance: TObject; const AFieldName: string; const AValue: T);
begin
  SetValue(AInstance, AFieldName, TValue.From<T>(AValue));
end;

class function TFieldAccess.TrySetValue(AInstance: TObject; const AFieldName: string; const AValue: TValue): Boolean;
begin
  try
    SetValue(AInstance, AFieldName, AValue);
    Result := True;
  except
    Result := False;
  end;
end;

class function TFieldAccess.HasField(AInstance: TObject; const AFieldName: string): Boolean;
begin
  Result := HasField(AInstance.ClassType, AFieldName);
end;

class function TFieldAccess.HasField(AClass: TClass; const AFieldName: string): Boolean;
var
  LContext: TRttiContext;
  LType: TRttiType;
begin
  LContext := TTypeInfo.Context;
  LType := LContext.GetType(AClass);
  Result := (LType <> nil) and (LType.GetField(AFieldName) <> nil);
end;

class function TFieldAccess.GetFieldInfo(AInstance: TObject; const AFieldName: string): TFieldInfoEx;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LField: TRttiField;
begin
  LContext := TTypeInfo.Context;
  LType := LContext.GetType(AInstance.ClassType);
  if LType = nil then
    raise EReflectionException.CreateFmt('Type not found for %s', [AInstance.ClassName]);
    
  LField := LType.GetField(AFieldName);
  if LField = nil then
    raise EReflectionException.CreateFmt('Field %s not found', [AFieldName]);
    
  Result.Name := LField.Name;
  Result.TypeName := LField.FieldType.Name;
  Result.TypeKind := LField.FieldType.TypeKind;
  Result.Offset := LField.Offset;
  Result.Visibility := TMemberVisibility(LField.Visibility);
end;

class function TFieldAccess.GetFields(AInstance: TObject; AVisibilities: TMemberVisibilities): TArray<TFieldInfoEx>;
begin
  Result := GetFields(AInstance.ClassType, AVisibilities);
end;

class function TFieldAccess.GetFields(AClass: TClass; AVisibilities: TMemberVisibilities): TArray<TFieldInfoEx>;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LField: TRttiField;
  LList: TList<TFieldInfoEx>;
  LInfo: TFieldInfoEx;
begin
  LList := TList<TFieldInfoEx>.Create;
  try
    LContext := TTypeInfo.Context;
    LType := LContext.GetType(AClass);
    if LType <> nil then
    begin
      for LField in LType.GetFields do
      begin
        if TMemberVisibility(LField.Visibility) in AVisibilities then
        begin
          LInfo.Name := LField.Name;
          LInfo.TypeName := LField.FieldType.Name;
          LInfo.TypeKind := LField.FieldType.TypeKind;
          LInfo.Offset := LField.Offset;
          LInfo.Visibility := TMemberVisibility(LField.Visibility);
          LList.Add(LInfo);
        end;
      end;
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

{ TMethodInvoke }

class function TMethodInvoke.Invoke(AInstance: TObject; const AMethodName: string;
  const AArgs: array of TValue): TValue;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LMethod: TRttiMethod;
begin
  LContext := TTypeInfo.Context;
  LType := LContext.GetType(AInstance.ClassType);
  if LType = nil then
    raise EReflectionException.CreateFmt('Type not found for %s', [AInstance.ClassName]);
    
  LMethod := LType.GetMethod(AMethodName);
  if LMethod = nil then
    raise EReflectionException.CreateFmt('Method %s not found in %s', [AMethodName, AInstance.ClassName]);
    
  Result := LMethod.Invoke(AInstance, AArgs);
end;

class function TMethodInvoke.TryInvoke(AInstance: TObject; const AMethodName: string;
  const AArgs: array of TValue; out AResult: TValue): Boolean;
begin
  try
    AResult := Invoke(AInstance, AMethodName, AArgs);
    Result := True;
  except
    Result := False;
  end;
end;

class function TMethodInvoke.InvokeClass(AClass: TClass; const AMethodName: string;
  const AArgs: array of TValue): TValue;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LMethod: TRttiMethod;
begin
  LContext := TTypeInfo.Context;
  LType := LContext.GetType(AClass);
  if LType = nil then
    raise EReflectionException.CreateFmt('Type not found for %s', [AClass.ClassName]);
    
  LMethod := LType.GetMethod(AMethodName);
  if LMethod = nil then
    raise EReflectionException.CreateFmt('Method %s not found', [AMethodName]);
    
  Result := LMethod.Invoke(AClass, AArgs);
end;

class function TMethodInvoke.HasMethod(AInstance: TObject; const AMethodName: string): Boolean;
begin
  Result := HasMethod(AInstance.ClassType, AMethodName);
end;

class function TMethodInvoke.HasMethod(AClass: TClass; const AMethodName: string): Boolean;
var
  LContext: TRttiContext;
  LType: TRttiType;
begin
  LContext := TTypeInfo.Context;
  LType := LContext.GetType(AClass);
  Result := (LType <> nil) and (LType.GetMethod(AMethodName) <> nil);
end;

class function TMethodInvoke.GetMethodInfo(AInstance: TObject; const AMethodName: string): TMethodInfoEx;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LMethod: TRttiMethod;
  LParams: TArray<TRttiParameter>;
  I: Integer;
begin
  LContext := TTypeInfo.Context;
  LType := LContext.GetType(AInstance.ClassType);
  if LType = nil then
    raise EReflectionException.CreateFmt('Type not found for %s', [AInstance.ClassName]);
    
  LMethod := LType.GetMethod(AMethodName);
  if LMethod = nil then
    raise EReflectionException.CreateFmt('Method %s not found', [AMethodName]);
    
  Result.Name := LMethod.Name;
  Result.IsFunction := LMethod.ReturnType <> nil;
  if Result.IsFunction then
    Result.ReturnType := LMethod.ReturnType.Name
  else
    Result.ReturnType := '';
  Result.IsClassMethod := LMethod.IsClassMethod;
  Result.IsStatic := LMethod.IsStatic;
  Result.Visibility := TMemberVisibility(LMethod.Visibility);
  
  LParams := LMethod.GetParameters;
  Result.ParameterCount := Length(LParams);
  SetLength(Result.Parameters, Result.ParameterCount);
  for I := 0 to High(LParams) do
    Result.Parameters[I] := LParams[I].Name + ': ' + LParams[I].ParamType.Name;
end;

class function TMethodInvoke.GetMethods(AInstance: TObject; AVisibilities: TMemberVisibilities): TArray<TMethodInfoEx>;
begin
  Result := GetMethods(AInstance.ClassType, AVisibilities);
end;

class function TMethodInvoke.GetMethods(AClass: TClass; AVisibilities: TMemberVisibilities): TArray<TMethodInfoEx>;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LMethod: TRttiMethod;
  LList: TList<TMethodInfoEx>;
  LInfo: TMethodInfoEx;
  LParams: TArray<TRttiParameter>;
  I: Integer;
begin
  LList := TList<TMethodInfoEx>.Create;
  try
    LContext := TTypeInfo.Context;
    LType := LContext.GetType(AClass);
    if LType <> nil then
    begin
      for LMethod in LType.GetMethods do
      begin
        if TMemberVisibility(LMethod.Visibility) in AVisibilities then
        begin
          LInfo.Name := LMethod.Name;
          LInfo.IsFunction := LMethod.ReturnType <> nil;
          if LInfo.IsFunction then
            LInfo.ReturnType := LMethod.ReturnType.Name
          else
            LInfo.ReturnType := '';
          LInfo.IsClassMethod := LMethod.IsClassMethod;
          LInfo.IsStatic := LMethod.IsStatic;
          LInfo.Visibility := TMemberVisibility(LMethod.Visibility);
          
          LParams := LMethod.GetParameters;
          LInfo.ParameterCount := Length(LParams);
          SetLength(LInfo.Parameters, LInfo.ParameterCount);
          for I := 0 to High(LParams) do
            if LParams[I].ParamType <> nil then
              LInfo.Parameters[I] := LParams[I].Name + ': ' + LParams[I].ParamType.Name
            else
              LInfo.Parameters[I] := LParams[I].Name + ': ?';
            
          LList.Add(LInfo);
        end;
      end;
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

{ TAttributeUtils }

class function TAttributeUtils.GetAttribute<T>(AType: TRttiType): T;
var
  LAttr: TCustomAttribute;
begin
  Result := nil;
  if AType = nil then
    Exit;
    
  for LAttr in AType.GetAttributes do
  begin
    if LAttr is T then
      Exit(T(LAttr));
  end;
end;

class function TAttributeUtils.GetAttribute<T>(AClass: TClass): T;
begin
  Result := GetAttribute<T>(TTypeInfo.Context.GetType(AClass));
end;

class function TAttributeUtils.GetAttributes<T>(AType: TRttiType): TArray<T>;
var
  LList: TList<T>;
  LAttr: TCustomAttribute;
begin
  LList := TList<T>.Create;
  try
    if AType <> nil then
    begin
      for LAttr in AType.GetAttributes do
      begin
        if LAttr is T then
          LList.Add(T(LAttr));
      end;
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

class function TAttributeUtils.GetAttributes<T>(AClass: TClass): TArray<T>;
begin
  Result := GetAttributes<T>(TTypeInfo.Context.GetType(AClass));
end;

class function TAttributeUtils.GetPropertyAttribute<T>(AClass: TClass; const APropertyName: string): T;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
  LAttr: TCustomAttribute;
begin
  Result := nil;
  LContext := TTypeInfo.Context;
  LType := LContext.GetType(AClass);
  if LType = nil then
    Exit;
    
  LProp := LType.GetProperty(APropertyName);
  if LProp = nil then
    Exit;
    
  for LAttr in LProp.GetAttributes do
  begin
    if LAttr is T then
      Exit(T(LAttr));
  end;
end;

class function TAttributeUtils.GetPropertyAttributes<T>(AClass: TClass; const APropertyName: string): TArray<T>;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
  LList: TList<T>;
  LAttr: TCustomAttribute;
begin
  LList := TList<T>.Create;
  try
    LContext := TTypeInfo.Context;
    LType := LContext.GetType(AClass);
    if LType <> nil then
    begin
      LProp := LType.GetProperty(APropertyName);
      if LProp <> nil then
      begin
        for LAttr in LProp.GetAttributes do
        begin
          if LAttr is T then
            LList.Add(T(LAttr));
        end;
      end;
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

class function TAttributeUtils.GetMethodAttribute<T>(AClass: TClass; const AMethodName: string): T;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LMethod: TRttiMethod;
  LAttr: TCustomAttribute;
begin
  Result := nil;
  LContext := TTypeInfo.Context;
  LType := LContext.GetType(AClass);
  if LType = nil then
    Exit;
    
  LMethod := LType.GetMethod(AMethodName);
  if LMethod = nil then
    Exit;
    
  for LAttr in LMethod.GetAttributes do
  begin
    if LAttr is T then
      Exit(T(LAttr));
  end;
end;

class function TAttributeUtils.HasAttribute<T>(AType: TRttiType): Boolean;
begin
  Result := GetAttribute<T>(AType) <> nil;
end;

class function TAttributeUtils.HasAttribute<T>(AClass: TClass): Boolean;
begin
  Result := GetAttribute<T>(AClass) <> nil;
end;

class function TAttributeUtils.HasPropertyAttribute<T>(AClass: TClass; const APropertyName: string): Boolean;
begin
  Result := GetPropertyAttribute<T>(AClass, APropertyName) <> nil;
end;

class function TAttributeUtils.GetAllAttributes(AType: TRttiType): TArray<TCustomAttribute>;
begin
  if AType <> nil then
    Result := AType.GetAttributes
  else
    Result := nil;
end;

{ TObjectUtils }

class function TObjectUtils.Clone<T>(ASource: T): T;
begin
  if ASource = nil then
    Exit(nil);
    
  Result := CreateInstance<T>;
  TPropertyAccess_.CopyProperties(ASource, Result);
end;

class function TObjectUtils.DeepClone<T>(ASource: T): T;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
  LValue: TValue;
  LObj, LClonedObj: TObject;
begin
  if ASource = nil then
    Exit(nil);
    
  Result := CreateInstance<T>;
  LContext := TTypeInfo.Context;
  LType := LContext.GetType(ASource.ClassType);
  
  if LType <> nil then
  begin
    for LProp in LType.GetProperties do
    begin
      if not LProp.IsReadable or not LProp.IsWritable then
        Continue;
        
      LValue := LProp.GetValue(TObject(ASource));
      
      // Deep clone nested objects
      if (LValue.TypeInfo <> nil) and (LValue.TypeInfo.Kind = tkClass) then
      begin
        LObj := LValue.AsObject;
        if LObj <> nil then
        begin
          // Recursively deep clone nested object
          LClonedObj := CreateInstance(LObj.ClassType);
          TPropertyAccess_.CopyProperties(LObj, LClonedObj);
          LValue := TValue.From<TObject>(LClonedObj);
        end;
      end;
      
      LProp.SetValue(TObject(Result), LValue);
    end;
  end;
end;

class function TObjectUtils.Equals(AObj1, AObj2: TObject; const AExclude: TArray<string>): Boolean;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
  LValue1, LValue2: TValue;
  LExcludeSet: TDictionary<string, Boolean>;
  LName: string;
begin
  if (AObj1 = nil) and (AObj2 = nil) then
    Exit(True);
  if (AObj1 = nil) or (AObj2 = nil) then
    Exit(False);
  if AObj1.ClassType <> AObj2.ClassType then
    Exit(False);
    
  LExcludeSet := TDictionary<string, Boolean>.Create;
  try
    for LName in AExclude do
      LExcludeSet.AddOrSetValue(LName.ToLower, True);
      
    LContext := TTypeInfo.Context;
    LType := LContext.GetType(AObj1.ClassType);
    
    if LType <> nil then
    begin
      for LProp in LType.GetProperties do
      begin
        if LExcludeSet.ContainsKey(LProp.Name.ToLower) then
          Continue;
          
        if not LProp.IsReadable then
          Continue;
          
        LValue1 := LProp.GetValue(AObj1);
        LValue2 := LProp.GetValue(AObj2);
        
        if LValue1.ToString <> LValue2.ToString then
          Exit(False);
      end;
    end;
    
    Result := True;
  finally
    LExcludeSet.Free;
  end;
end;

class function TObjectUtils.GetDifferences(AObj1, AObj2: TObject): TArray<string>;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
  LValue1, LValue2: TValue;
  LList: TList<string>;
begin
  LList := TList<string>.Create;
  try
    if (AObj1 = nil) or (AObj2 = nil) then
    begin
      LList.Add('One or both objects are nil');
      Exit(LList.ToArray);
    end;
    
    LContext := TTypeInfo.Context;
    LType := LContext.GetType(AObj1.ClassType);
    
    if LType <> nil then
    begin
      for LProp in LType.GetProperties do
      begin
        if not LProp.IsReadable then
          Continue;
          
        LValue1 := LProp.GetValue(AObj1);
        LValue2 := LProp.GetValue(AObj2);
        
        if LValue1.ToString <> LValue2.ToString then
          LList.Add(LProp.Name);
      end;
    end;
    
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

class function TObjectUtils.ToDictionary(AInstance: TObject): TDictionary<string, TValue>;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
begin
  Result := TDictionary<string, TValue>.Create;
  
  if AInstance = nil then
    Exit;
    
  LContext := TTypeInfo.Context;
  LType := LContext.GetType(AInstance.ClassType);
  
  if LType <> nil then
  begin
    for LProp in LType.GetProperties do
    begin
      if LProp.IsReadable then
        Result.Add(LProp.Name, LProp.GetValue(AInstance));
    end;
  end;
end;

class procedure TObjectUtils.FromDictionary(AInstance: TObject; const AValues: TDictionary<string, TValue>);
var
  LContext: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
  LPair: TPair<string, TValue>;
begin
  if AInstance = nil then
    Exit;
    
  LContext := TTypeInfo.Context;
  LType := LContext.GetType(AInstance.ClassType);
  
  if LType <> nil then
  begin
    for LPair in AValues do
    begin
      LProp := LType.GetProperty(LPair.Key);
      if (LProp <> nil) and LProp.IsWritable then
        LProp.SetValue(AInstance, LPair.Value);
    end;
  end;
end;

class function TObjectUtils.CreateInstance(AClass: TClass): TObject;
begin
  Result := CreateInstance(AClass, []);
end;

class function TObjectUtils.CreateInstance(AClass: TClass; const AArgs: array of TValue): TObject;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LMethod: TRttiMethod;
  LParams: TArray<TRttiParameter>;
  LValue: TValue;
begin
  LContext := TTypeInfo.Context;
  LType := LContext.GetType(AClass);
  
  if LType = nil then
    raise EReflectionException.CreateFmt('Type not found for %s', [AClass.ClassName]);
    
  // Find matching constructor
  for LMethod in LType.GetMethods do
  begin
    if LMethod.IsConstructor then
    begin
      LParams := LMethod.GetParameters;
      if Length(LParams) = Length(AArgs) then
      begin
        LValue := LMethod.Invoke(AClass, AArgs);
        Exit(LValue.AsObject);
      end;
    end;
  end;
  
  // Try default constructor
  for LMethod in LType.GetMethods do
  begin
    if LMethod.IsConstructor and (Length(LMethod.GetParameters) = 0) then
    begin
      LValue := LMethod.Invoke(AClass, []);
      Exit(LValue.AsObject);
    end;
  end;
  
  raise EReflectionException.CreateFmt('No suitable constructor found for %s', [AClass.ClassName]);
end;

class function TObjectUtils.CreateInstance<T>: T;
begin
  Result := T(CreateInstance(T, []));
end;

class function TObjectUtils.CreateInstance<T>(const AArgs: array of TValue): T;
begin
  Result := T(CreateInstance(T, AArgs));
end;

class function TObjectUtils.SafeCast<T>(AInstance: TObject): T;
begin
  if AInstance is T then
    Result := T(AInstance)
  else
    Result := nil;
end;

class function TObjectUtils.TryCast<T>(AInstance: TObject; out AResult: T): Boolean;
begin
  if AInstance is T then
  begin
    AResult := T(AInstance);
    Result := True;
  end
  else
  begin
    AResult := nil;
    Result := False;
  end;
end;

{ TTypeRegistry }

class constructor TTypeRegistry.Create;
begin
  FLock := TCriticalSection.Create;
  FRegistry := TDictionary<string, TClass>.Create;
end;

class destructor TTypeRegistry.Destroy;
begin
  FreeAndNil(FRegistry);
  FreeAndNil(FLock);
end;

class procedure TTypeRegistry.RegisterType(const AName: string; AClass: TClass);
begin
  FLock.Enter;
  try
    FRegistry.AddOrSetValue(AName, AClass);
  finally
    FLock.Leave;
  end;
end;

class procedure TTypeRegistry.RegisterType<T>;
begin
  RegisterType(T.ClassName, T);
end;

class procedure TTypeRegistry.RegisterType<T>(const AName: string);
begin
  RegisterType(AName, T);
end;

class procedure TTypeRegistry.UnregisterType(const AName: string);
begin
  FLock.Enter;
  try
    FRegistry.Remove(AName);
  finally
    FLock.Leave;
  end;
end;

class function TTypeRegistry.CreateInstance(const AName: string): TObject;
begin
  Result := CreateInstance(AName, []);
end;

class function TTypeRegistry.CreateInstance(const AName: string; const AArgs: array of TValue): TObject;
var
  LClass: TClass;
begin
  if not TryGetClass(AName, LClass) then
    raise EReflectionException.CreateFmt('Type %s not registered', [AName]);
    
  Result := TObjectUtils.CreateInstance(LClass, AArgs);
end;

class function TTypeRegistry.CreateInstance<T>(const AName: string): T;
begin
  Result := T(CreateInstance(AName, []));
end;

class function TTypeRegistry.GetClass(const AName: string): TClass;
begin
  if not TryGetClass(AName, Result) then
    raise EReflectionException.CreateFmt('Type %s not registered', [AName]);
end;

class function TTypeRegistry.TryGetClass(const AName: string; out AClass: TClass): Boolean;
begin
  FLock.Enter;
  try
    Result := FRegistry.TryGetValue(AName, AClass);
  finally
    FLock.Leave;
  end;
end;

class function TTypeRegistry.IsRegistered(const AName: string): Boolean;
begin
  FLock.Enter;
  try
    Result := FRegistry.ContainsKey(AName);
  finally
    FLock.Leave;
  end;
end;

class function TTypeRegistry.GetRegisteredNames: TArray<string>;
begin
  FLock.Enter;
  try
    Result := FRegistry.Keys.ToArray;
  finally
    FLock.Leave;
  end;
end;

class procedure TTypeRegistry.Clear;
begin
  FLock.Enter;
  try
    FRegistry.Clear;
  finally
    FLock.Leave;
  end;
end;

{ TValueConverter }

class function TValueConverter.Convert<T>(const AValue: TValue): T;
begin
  Result := AValue.AsType<T>;
end;

class function TValueConverter.TryConvert<T>(const AValue: TValue; out AResult: T): Boolean;
begin
  try
    AResult := AValue.AsType<T>;
    Result := True;
  except
    Result := False;
  end;
end;

class function TValueConverter.ConvertTo(const AValue: TValue; ATargetType: TRttiType): TValue;
begin
  if ATargetType = nil then
    raise EReflectionException.Create('Target type is nil');
    
  Result := AValue.Cast(ATargetType.Handle);
end;

class function TValueConverter.ToString(const AValue: TValue): string;
begin
  case AValue.Kind of
    tkUnknown: Result := '';
    tkInteger: Result := IntToStr(AValue.AsInteger);
    tkChar: Result := string(AValue.AsType<AnsiChar>);
    tkEnumeration: 
      if AValue.TypeInfo = TypeInfo(Boolean) then
        Result := BoolToStr(AValue.AsBoolean, True)
      else
        Result := System.TypInfo.GetEnumName(AValue.TypeInfo, AValue.AsOrdinal);
    tkFloat: Result := FloatToStr(AValue.AsExtended);
    tkString, tkLString, tkWString, tkUString: Result := AValue.AsString;
    tkClass: 
      if AValue.AsObject <> nil then
        Result := AValue.AsObject.ClassName
      else
        Result := 'nil';
    tkInt64: Result := IntToStr(AValue.AsInt64);
  else
    Result := AValue.ToString;
  end;
end;

class function TValueConverter.FromString(const AValue: string; ATargetType: TRttiType): TValue;
begin
  if ATargetType = nil then
    raise EReflectionException.Create('Target type is nil');
    
  case ATargetType.TypeKind of
    tkInteger: Result := StrToIntDef(AValue, 0);
    tkFloat: Result := StrToFloatDef(AValue, 0);
    tkString, tkLString, tkWString, tkUString: Result := AValue;
    tkEnumeration:
      if ATargetType.Handle = TypeInfo(Boolean) then
        Result := StrToBoolDef(AValue, False)
      else
        Result := TValue.FromOrdinal(ATargetType.Handle, 
          System.TypInfo.GetEnumValue(ATargetType.Handle, AValue));
    tkInt64: Result := StrToInt64Def(AValue, 0);
  else
    Result := TValue.Empty;
  end;
end;

class function TValueConverter.FromString<T>(const AValue: string): T;
var
  LType: TRttiType;
  LValue: TValue;
begin
  LType := TTypeInfo.GetType<T>;
  LValue := FromString(AValue, LType);
  Result := LValue.AsType<T>;
end;

class function TValueConverter.CanConvert(const AValue: TValue; ATargetType: TRttiType): Boolean;
begin
  try
    AValue.Cast(ATargetType.Handle);
    Result := True;
  except
    Result := False;
  end;
end;

class function TValueConverter.CanConvert<TSource, TTarget>: Boolean;
var
  LValue: TValue;
begin
  LValue := TValue.Empty;
  LValue := TValue.From<TSource>(Default(TSource));
  Result := CanConvert(LValue, TTypeInfo.GetType<TTarget>);
end;

{ TEnumUtils }

class function TEnumUtils.GetName<T>(AValue: T): string;
var
  LInfo: PTypeInfo;
  LOrdinal: Integer;
  LSize: Integer;
begin
  LInfo := TypeInfo(T);
  if (LInfo = nil) or (LInfo.Kind <> tkEnumeration) then
    raise EReflectionException.Create('Type is not an enumeration');
  
  LSize := SizeOf(T);
  case LSize of
    1: LOrdinal := PByte(@AValue)^;
    2: LOrdinal := PWord(@AValue)^;
    4: LOrdinal := PInteger(@AValue)^;
  else
    LOrdinal := PByte(@AValue)^;
  end;
  Result := System.TypInfo.GetEnumName(LInfo, LOrdinal);
end;

class function TEnumUtils.GetValue<T>(const AName: string): T;
var
  LValue: T;
begin
  if not TryGetValue<T>(AName, LValue) then
    raise EReflectionException.CreateFmt('Invalid enum name: %s', [AName]);
  Result := LValue;
end;

class function TEnumUtils.TryGetValue<T>(const AName: string; out AValue: T): Boolean;
var
  LInfo: PTypeInfo;
  LOrdinal: Integer;
  LSize: Integer;
begin
  LInfo := TypeInfo(T);
  if (LInfo = nil) or (LInfo.Kind <> tkEnumeration) then
  begin
    Result := False;
    Exit;
  end;
  
  LOrdinal := System.TypInfo.GetEnumValue(LInfo, AName);
  if LOrdinal < 0 then
  begin
    Result := False;
    Exit;
  end;
  
  LSize := SizeOf(T);
  case LSize of
    1: PByte(@AValue)^ := LOrdinal;
    2: PWord(@AValue)^ := LOrdinal;
    4: PInteger(@AValue)^ := LOrdinal;
  else
    PByte(@AValue)^ := LOrdinal;
  end;
  Result := True;
end;

class function TEnumUtils.GetNames<T>: TArray<string>;
var
  LInfo: PTypeInfo;
  LTypeData: PTypeData;
  LList: TList<string>;
  I: Integer;
begin
  LInfo := TypeInfo(T);
  if (LInfo = nil) or (LInfo.Kind <> tkEnumeration) then
    raise EReflectionException.Create('Type is not an enumeration');
    
  LTypeData := GetTypeData(LInfo);
  LList := TList<string>.Create;
  try
    for I := LTypeData.MinValue to LTypeData.MaxValue do
      LList.Add(System.TypInfo.GetEnumName(LInfo, I));
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

class function TEnumUtils.GetValues<T>: TArray<T>;
var
  LInfo: PTypeInfo;
  LTypeData: PTypeData;
  LList: TList<T>;
  I: Integer;
  LValue: T;
  LSize: Integer;
begin
  LInfo := TypeInfo(T);
  if (LInfo = nil) or (LInfo.Kind <> tkEnumeration) then
    raise EReflectionException.Create('Type is not an enumeration');
    
  LTypeData := GetTypeData(LInfo);
  LSize := SizeOf(T);
  LList := TList<T>.Create;
  try
    for I := LTypeData.MinValue to LTypeData.MaxValue do
    begin
      case LSize of
        1: PByte(@LValue)^ := I;
        2: PWord(@LValue)^ := I;
        4: PInteger(@LValue)^ := I;
      else
        PByte(@LValue)^ := I;
      end;
      LList.Add(LValue);
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

class function TEnumUtils.GetCount<T>: Integer;
var
  LInfo: PTypeInfo;
  LTypeData: PTypeData;
begin
  LInfo := TypeInfo(T);
  if (LInfo = nil) or (LInfo.Kind <> tkEnumeration) then
    raise EReflectionException.Create('Type is not an enumeration');
    
  LTypeData := GetTypeData(LInfo);
  Result := LTypeData.MaxValue - LTypeData.MinValue + 1;
end;

class function TEnumUtils.GetOrdinal<T>(AValue: T): Integer;
var
  LSize: Integer;
begin
  LSize := SizeOf(T);
  case LSize of
    1: Result := PByte(@AValue)^;
    2: Result := PWord(@AValue)^;
    4: Result := PInteger(@AValue)^;
  else
    Result := PByte(@AValue)^;
  end;
end;

class function TEnumUtils.FromOrdinal<T>(AOrdinal: Integer): T;
var
  LSize: Integer;
begin
  LSize := SizeOf(T);
  case LSize of
    1: PByte(@Result)^ := AOrdinal;
    2: PWord(@Result)^ := AOrdinal;
    4: PInteger(@Result)^ := AOrdinal;
  else
    PByte(@Result)^ := AOrdinal;
  end;
end;

{ TListUtils }

class function TListUtils.GetItemType(AList: TObject): TRttiType;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LMethod: TRttiMethod;
begin
  Result := nil;
  LContext := TTypeInfo.Context;
  LType := LContext.GetType(AList.ClassType);
  
  if LType = nil then
    Exit;
    
  // Look for GetItem method to determine item type
  LMethod := LType.GetMethod('GetItem');
  if (LMethod <> nil) and (LMethod.ReturnType <> nil) then
    Result := LMethod.ReturnType;
end;

class function TListUtils.GetCount(AList: TObject): Integer;
var
  LValue: TValue;
begin
  if TPropertyAccess_.TryGetValue(AList, 'Count', LValue) then
    Result := LValue.AsInteger
  else
    Result := 0;
end;

class function TListUtils.GetItem(AList: TObject; AIndex: Integer): TValue;
begin
  Result := TMethodInvoke.Invoke(AList, 'GetItem', [AIndex]);
end;

class procedure TListUtils.AddItem(AList: TObject; const AValue: TValue);
begin
  TMethodInvoke.Invoke(AList, 'Add', [AValue]);
end;

class procedure TListUtils.Clear(AList: TObject);
begin
  TMethodInvoke.Invoke(AList, 'Clear', []);
end;

class function TListUtils.IsList(AType: TRttiType): Boolean;
begin
  Result := (AType <> nil) and 
            (AType.QualifiedName.StartsWith('System.Generics.Collections.TList<') or
             AType.QualifiedName.StartsWith('System.Generics.Collections.TObjectList<'));
end;

class function TListUtils.IsList(AInstance: TObject): Boolean;
begin
  Result := (AInstance <> nil) and IsList(TTypeInfo.Context.GetType(AInstance.ClassType));
end;

{ TReflect }

class function TReflect.GetType<T>: TRttiType;
begin
  Result := TTypeInfo.GetType<T>;
end;

class function TReflect.GetTypeName<T>: string;
begin
  Result := TTypeInfo.GetName<T>;
end;

class function TReflect.GetProp(AObj: TObject; const AProp: string): TValue;
begin
  Result := TPropertyAccess_.GetValue(AObj, AProp);
end;

class function TReflect.GetProp<T>(AObj: TObject; const AProp: string): T;
begin
  Result := TPropertyAccess_.GetValue<T>(AObj, AProp);
end;

class procedure TReflect.SetProp(AObj: TObject; const AProp: string; const AValue: TValue);
begin
  TPropertyAccess_.SetValue(AObj, AProp, AValue);
end;

class procedure TReflect.SetProp<T>(AObj: TObject; const AProp: string; const AValue: T);
begin
  TPropertyAccess_.SetValue<T>(AObj, AProp, AValue);
end;

class function TReflect.HasProp(AObj: TObject; const AProp: string): Boolean;
begin
  Result := TPropertyAccess_.HasProperty(AObj, AProp);
end;

class function TReflect.GetField(AObj: TObject; const AField: string): TValue;
begin
  Result := TFieldAccess.GetValue(AObj, AField);
end;

class function TReflect.GetField<T>(AObj: TObject; const AField: string): T;
begin
  Result := TFieldAccess.GetValue<T>(AObj, AField);
end;

class procedure TReflect.SetField(AObj: TObject; const AField: string; const AValue: TValue);
begin
  TFieldAccess.SetValue(AObj, AField, AValue);
end;

class procedure TReflect.SetField<T>(AObj: TObject; const AField: string; const AValue: T);
begin
  TFieldAccess.SetValue<T>(AObj, AField, AValue);
end;

class function TReflect.Call(AObj: TObject; const AMethod: string; const AArgs: array of TValue): TValue;
begin
  Result := TMethodInvoke.Invoke(AObj, AMethod, AArgs);
end;

class function TReflect.HasMethod(AObj: TObject; const AMethod: string): Boolean;
begin
  Result := TMethodInvoke.HasMethod(AObj, AMethod);
end;

class function TReflect.Clone<T>(AObj: T): T;
begin
  Result := TObjectUtils.Clone<T>(AObj);
end;

class function TReflect.Make<T>: T;
begin
  Result := TObjectUtils.CreateInstance<T>;
end;

class function TReflect.Make<T>(const AArgs: array of TValue): T;
begin
  Result := TObjectUtils.CreateInstance<T>(AArgs);
end;

end.
