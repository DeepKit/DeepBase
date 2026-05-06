unit Test.UniBase.CloudSync;

{*******************************************************************************
  UniBase CloudSync Module Unit Tests
  
  Test Coverage:
  - JSON Deep Merge (JSONDeepMerge, JSONMergeArrays, JSONClone, JSONValuesEqual)
  - Array merge strategies (Replace, Append, MergeByIndex, Union)
  - TLocalConfigStore CRUD operations
  - TConfigItem serialization
  - TConfigVersion handling
  - Conflict detection basics
*******************************************************************************}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.IOUtils,
  System.DateUtils,
  System.Generics.Collections,
  UniBase.CloudSync;

type
  [TestFixture]
  TTestJSONDeepMerge = class
  public
    // JSONClone tests
    [Test]
    procedure Test_JSONClone_Null_ReturnsNil;
    
    [Test]
    procedure Test_JSONClone_SimpleValue_ReturnsClone;
    
    [Test]
    procedure Test_JSONClone_Object_ReturnsDeepClone;
    
    [Test]
    procedure Test_JSONClone_Array_ReturnsDeepClone;
    
    // JSONValuesEqual tests
    [Test]
    procedure Test_JSONValuesEqual_BothNull_ReturnsTrue;
    
    [Test]
    procedure Test_JSONValuesEqual_OneNull_ReturnsFalse;
    
    [Test]
    procedure Test_JSONValuesEqual_SameSimpleValue_ReturnsTrue;
    
    [Test]
    procedure Test_JSONValuesEqual_DifferentValues_ReturnsFalse;
    
    [Test]
    procedure Test_JSONValuesEqual_SameObject_ReturnsTrue;
    
    [Test]
    procedure Test_JSONValuesEqual_DifferentObjects_ReturnsFalse;
    
    // JSONMergeArrays - Replace strategy
    [Test]
    procedure Test_JSONMergeArrays_Replace_ReplacesTarget;
    
    // JSONMergeArrays - Append strategy
    [Test]
    procedure Test_JSONMergeArrays_Append_AppendsElements;
    
    // JSONMergeArrays - MergeByIndex strategy
    [Test]
    procedure Test_JSONMergeArrays_MergeByIndex_MergesObjects;
    
    [Test]
    procedure Test_JSONMergeArrays_MergeByIndex_AppendsExtraElements;
    
    // JSONMergeArrays - Union strategy
    [Test]
    procedure Test_JSONMergeArrays_Union_DeduplicatesElements;
    
    [Test]
    procedure Test_JSONMergeArrays_Union_AddsNewElements;
    
    // JSONDeepMerge tests
    [Test]
    procedure Test_JSONDeepMerge_EmptySource_TargetUnchanged;
    
    [Test]
    procedure Test_JSONDeepMerge_NewKey_AddsToTarget;
    
    [Test]
    procedure Test_JSONDeepMerge_ExistingSimpleKey_OverwritesValue;
    
    [Test]
    procedure Test_JSONDeepMerge_NestedObjects_RecursiveMerge;
    
    [Test]
    procedure Test_JSONDeepMerge_ArrayFields_UsesStrategy;
    
    [Test]
    procedure Test_JSONDeepMerge_TypeMismatch_SourceOverwrites;
    
    [Test]
    procedure Test_JSONDeepMerge_ComplexNested_MergesCorrectly;
  end;

  [TestFixture]
  TTestLocalConfigStore = class
  private
    FStore: TLocalConfigStore;
    FTempPath: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    // Basic CRUD
    [Test]
    procedure Test_Put_And_Get;
    
    [Test]
    procedure Test_Get_NonExistent_ReturnsNil;
    
    [Test]
    procedure Test_GetOrCreate_ExistingKey_ReturnsExisting;
    
    [Test]
    procedure Test_GetOrCreate_NewKey_CreatesItem;
    
    [Test]
    procedure Test_Exists_ExistingKey_ReturnsTrue;
    
    [Test]
    procedure Test_Exists_NonExistent_ReturnsFalse;
    
    [Test]
    procedure Test_Delete_MarksAsDeleted;
    
    [Test]
    procedure Test_Exists_DeletedKey_ReturnsFalse;
    
    [Test]
    procedure Test_GetAll_ReturnsNonDeletedItems;
    
    [Test]
    procedure Test_GetDirtyItems_ReturnsDirtyOnly;
    
    [Test]
    procedure Test_MarkAllClean_ClearsDirtyFlags;
    
    [Test]
    procedure Test_Clear_RemovesAllItems;
    
    // Persistence
    [Test]
    procedure Test_SaveAndLoad_PersistsData;
    
    [Test]
    procedure Test_CurrentVersion_Persisted;
  end;

  [TestFixture]
  TTestConfigItem = class
  public
    [Test]
    procedure Test_Create_SetsKeyAndType;
    
    [Test]
    procedure Test_SetStringValue_SetsValue;
    
    [Test]
    procedure Test_SetIntegerValue_ConvertsToString;
    
    [Test]
    procedure Test_SetFloatValue_ConvertsToString;
    
    [Test]
    procedure Test_SetBooleanValue_ConvertsToString;
    
    [Test]
    procedure Test_SetDateTimeValue_ConvertsToISO8601;
    
    [Test]
    procedure Test_SetJSONValue_Serializes;
    
    [Test]
    procedure Test_GetIntegerValue_ParsesString;
    
    [Test]
    procedure Test_GetFloatValue_ParsesString;
    
    [Test]
    procedure Test_GetBooleanValue_ParsesString;
    
    [Test]
    procedure Test_ToJSON_SerializesAllFields;
    
    [Test]
    procedure Test_FromJSON_DeserializesAllFields;
  end;

  [TestFixture]
  TTestConfigVersion = class
  public
    [Test]
    procedure Test_Create_InitializesFields;
    
    [Test]
    procedure Test_ToJSON_SerializesCorrectly;
    
    [Test]
    procedure Test_FromJSON_DeserializesCorrectly;
  end;

  [TestFixture]
  TTestCloudServiceConfig = class
  public
    [Test]
    procedure Test_Default_SetsReasonableDefaults;
  end;

  [TestFixture]
  TTestSyncProgress = class
  public
    [Test]
    procedure Test_ProgressPercent_ZeroTotal_ReturnsZero;
    
    [Test]
    procedure Test_ProgressPercent_Calculation;
  end;

  [TestFixture]
  TTestSyncStatistics = class
  public
    [Test]
    procedure Test_Reset_ClearsAllValues;
  end;

implementation

{ TTestJSONDeepMerge }

procedure TTestJSONDeepMerge.Test_JSONClone_Null_ReturnsNil;
begin
  Assert.IsNull(JSONClone(nil));
end;

procedure TTestJSONDeepMerge.Test_JSONClone_SimpleValue_ReturnsClone;
var
  Original, Cloned: TJSONValue;
begin
  Original := TJSONString.Create('test');
  try
    Cloned := JSONClone(Original);
    try
      Assert.IsNotNull(Cloned);
      Assert.AreEqual('test', Cloned.Value);
      Assert.AreNotSame(Original, Cloned);
    finally
      Cloned.Free;
    end;
  finally
    Original.Free;
  end;
end;

procedure TTestJSONDeepMerge.Test_JSONClone_Object_ReturnsDeepClone;
var
  Original, Cloned: TJSONObject;
begin
  Original := TJSONObject.Create;
  Original.AddPair('key', 'value');
  Original.AddPair('nested', TJSONObject.Create.AddPair('inner', 'data'));
  try
    Cloned := JSONClone(Original) as TJSONObject;
    try
      Assert.IsNotNull(Cloned);
      Assert.AreEqual('value', Cloned.GetValue<string>('key'));
      Assert.AreEqual('data', Cloned.GetValue<TJSONObject>('nested').GetValue<string>('inner'));
      Assert.AreNotSame(Original, Cloned);
    finally
      Cloned.Free;
    end;
  finally
    Original.Free;
  end;
end;

procedure TTestJSONDeepMerge.Test_JSONClone_Array_ReturnsDeepClone;
var
  Original, Cloned: TJSONArray;
begin
  Original := TJSONArray.Create;
  Original.Add(1);
  Original.Add('two');
  Original.Add(TJSONObject.Create.AddPair('three', 3));
  try
    Cloned := JSONClone(Original) as TJSONArray;
    try
      Assert.IsNotNull(Cloned);
      Assert.AreEqual(3, Integer(Cloned.Count));
      Assert.AreEqual(1, Cloned.Items[0].GetValue<Integer>);
      Assert.AreEqual('two', Cloned.Items[1].Value);
      Assert.AreNotSame(Original, Cloned);
    finally
      Cloned.Free;
    end;
  finally
    Original.Free;
  end;
end;

procedure TTestJSONDeepMerge.Test_JSONValuesEqual_BothNull_ReturnsTrue;
begin
  Assert.IsTrue(JSONValuesEqual(nil, nil));
end;

procedure TTestJSONDeepMerge.Test_JSONValuesEqual_OneNull_ReturnsFalse;
var
  Value: TJSONValue;
begin
  Value := TJSONString.Create('test');
  try
    Assert.IsFalse(JSONValuesEqual(nil, Value));
    Assert.IsFalse(JSONValuesEqual(Value, nil));
  finally
    Value.Free;
  end;
end;

procedure TTestJSONDeepMerge.Test_JSONValuesEqual_SameSimpleValue_ReturnsTrue;
var
  A, B: TJSONValue;
begin
  A := TJSONString.Create('test');
  B := TJSONString.Create('test');
  try
    Assert.IsTrue(JSONValuesEqual(A, B));
  finally
    A.Free;
    B.Free;
  end;
end;

procedure TTestJSONDeepMerge.Test_JSONValuesEqual_DifferentValues_ReturnsFalse;
var
  A, B: TJSONValue;
begin
  A := TJSONString.Create('test1');
  B := TJSONString.Create('test2');
  try
    Assert.IsFalse(JSONValuesEqual(A, B));
  finally
    A.Free;
    B.Free;
  end;
end;

procedure TTestJSONDeepMerge.Test_JSONValuesEqual_SameObject_ReturnsTrue;
var
  A, B: TJSONObject;
begin
  A := TJSONObject.Create;
  A.AddPair('key', 'value');
  B := TJSONObject.Create;
  B.AddPair('key', 'value');
  try
    Assert.IsTrue(JSONValuesEqual(A, B));
  finally
    A.Free;
    B.Free;
  end;
end;

procedure TTestJSONDeepMerge.Test_JSONValuesEqual_DifferentObjects_ReturnsFalse;
var
  A, B: TJSONObject;
begin
  A := TJSONObject.Create;
  A.AddPair('key', 'value1');
  B := TJSONObject.Create;
  B.AddPair('key', 'value2');
  try
    Assert.IsFalse(JSONValuesEqual(A, B));
  finally
    A.Free;
    B.Free;
  end;
end;

procedure TTestJSONDeepMerge.Test_JSONMergeArrays_Replace_ReplacesTarget;
var
  Target, Source: TJSONArray;
begin
  Target := TJSONArray.Create;
  Target.Add(1);
  Target.Add(2);
  
  Source := TJSONArray.Create;
  Source.Add(3);
  Source.Add(4);
  Source.Add(5);
  try
    JSONMergeArrays(Target, Source, amsReplace);
    
    Assert.AreEqual(3, Integer(Target.Count));
    Assert.AreEqual(3, Target.Items[0].GetValue<Integer>);
    Assert.AreEqual(4, Target.Items[1].GetValue<Integer>);
    Assert.AreEqual(5, Target.Items[2].GetValue<Integer>);
  finally
    Target.Free;
    Source.Free;
  end;
end;

procedure TTestJSONDeepMerge.Test_JSONMergeArrays_Append_AppendsElements;
var
  Target, Source: TJSONArray;
begin
  Target := TJSONArray.Create;
  Target.Add(1);
  Target.Add(2);
  
  Source := TJSONArray.Create;
  Source.Add(3);
  Source.Add(4);
  try
    JSONMergeArrays(Target, Source, amsAppend);
    
    Assert.AreEqual(4, Integer(Target.Count));
    Assert.AreEqual(1, Target.Items[0].GetValue<Integer>);
    Assert.AreEqual(2, Target.Items[1].GetValue<Integer>);
    Assert.AreEqual(3, Target.Items[2].GetValue<Integer>);
    Assert.AreEqual(4, Target.Items[3].GetValue<Integer>);
  finally
    Target.Free;
    Source.Free;
  end;
end;

procedure TTestJSONDeepMerge.Test_JSONMergeArrays_MergeByIndex_MergesObjects;
var
  Target, Source: TJSONArray;
begin
  Target := TJSONArray.Create;
  Target.Add(TJSONObject.Create.AddPair('a', 1));
  Target.Add(TJSONObject.Create.AddPair('b', 2));
  
  Source := TJSONArray.Create;
  Source.Add(TJSONObject.Create.AddPair('c', 3));
  try
    JSONMergeArrays(Target, Source, amsMergeByIndex);
    
    // First element should be merged
    var FirstObj := Target.Items[0] as TJSONObject;
    Assert.AreEqual(1, FirstObj.GetValue<Integer>('a'));
    Assert.AreEqual(3, FirstObj.GetValue<Integer>('c'));
  finally
    Target.Free;
    Source.Free;
  end;
end;

procedure TTestJSONDeepMerge.Test_JSONMergeArrays_MergeByIndex_AppendsExtraElements;
var
  Target, Source: TJSONArray;
begin
  Target := TJSONArray.Create;
  Target.Add(1);
  
  Source := TJSONArray.Create;
  Source.Add(10);
  Source.Add(20);
  Source.Add(30);
  try
    JSONMergeArrays(Target, Source, amsMergeByIndex);
    
    // Source has more elements, extras should be appended
    Assert.IsTrue(Target.Count >= 2, 'Should have at least 2 elements');
  finally
    Target.Free;
    Source.Free;
  end;
end;

procedure TTestJSONDeepMerge.Test_JSONMergeArrays_Union_DeduplicatesElements;
var
  Target, Source: TJSONArray;
begin
  Target := TJSONArray.Create;
  Target.Add(1);
  Target.Add(2);
  Target.Add(3);
  
  Source := TJSONArray.Create;
  Source.Add(2);  // Duplicate
  Source.Add(3);  // Duplicate
  Source.Add(4);  // New
  try
    JSONMergeArrays(Target, Source, amsUnion);
    
    Assert.AreEqual(4, Integer(Target.Count));  // 1, 2, 3, 4
  finally
    Target.Free;
    Source.Free;
  end;
end;

procedure TTestJSONDeepMerge.Test_JSONMergeArrays_Union_AddsNewElements;
var
  Target, Source: TJSONArray;
begin
  Target := TJSONArray.Create;
  Target.Add('apple');
  
  Source := TJSONArray.Create;
  Source.Add('banana');
  Source.Add('cherry');
  try
    JSONMergeArrays(Target, Source, amsUnion);
    
    Assert.AreEqual(3, Integer(Target.Count));
  finally
    Target.Free;
    Source.Free;
  end;
end;

procedure TTestJSONDeepMerge.Test_JSONDeepMerge_EmptySource_TargetUnchanged;
var
  Target, Source: TJSONObject;
begin
  Target := TJSONObject.Create;
  Target.AddPair('key', 'value');
  
  Source := TJSONObject.Create;
  try
    JSONDeepMerge(Target, Source);
    
    Assert.AreEqual('value', Target.GetValue<string>('key'));
    Assert.AreEqual(1, Integer(Target.Count));
  finally
    Target.Free;
    Source.Free;
  end;
end;

procedure TTestJSONDeepMerge.Test_JSONDeepMerge_NewKey_AddsToTarget;
var
  Target, Source: TJSONObject;
begin
  Target := TJSONObject.Create;
  Target.AddPair('existing', 'value1');
  
  Source := TJSONObject.Create;
  Source.AddPair('newkey', 'value2');
  try
    JSONDeepMerge(Target, Source);
    
    Assert.AreEqual('value1', Target.GetValue<string>('existing'));
    Assert.AreEqual('value2', Target.GetValue<string>('newkey'));
  finally
    Target.Free;
    Source.Free;
  end;
end;

procedure TTestJSONDeepMerge.Test_JSONDeepMerge_ExistingSimpleKey_OverwritesValue;
var
  Target, Source: TJSONObject;
begin
  Target := TJSONObject.Create;
  Target.AddPair('key', 'old');
  
  Source := TJSONObject.Create;
  Source.AddPair('key', 'new');
  try
    JSONDeepMerge(Target, Source);
    
    Assert.AreEqual('new', Target.GetValue<string>('key'));
  finally
    Target.Free;
    Source.Free;
  end;
end;

procedure TTestJSONDeepMerge.Test_JSONDeepMerge_NestedObjects_RecursiveMerge;
var
  Target, Source: TJSONObject;
  Nested: TJSONObject;
begin
  Target := TJSONObject.Create;
  Target.AddPair('nested', TJSONObject.Create
    .AddPair('a', 1)
    .AddPair('b', 2));
  
  Source := TJSONObject.Create;
  Source.AddPair('nested', TJSONObject.Create
    .AddPair('b', 20)
    .AddPair('c', 3));
  try
    JSONDeepMerge(Target, Source);
    
    Nested := Target.GetValue<TJSONObject>('nested');
    Assert.AreEqual(1, Nested.GetValue<Integer>('a'));   // Unchanged
    Assert.AreEqual(20, Nested.GetValue<Integer>('b'));  // Overwritten
    Assert.AreEqual(3, Nested.GetValue<Integer>('c'));   // Added
  finally
    Target.Free;
    Source.Free;
  end;
end;

procedure TTestJSONDeepMerge.Test_JSONDeepMerge_ArrayFields_UsesStrategy;
var
  Target, Source: TJSONObject;
  Arr: TJSONArray;
begin
  Target := TJSONObject.Create;
  Target.AddPair('items', TJSONArray.Create.Add(1).Add(2));
  
  Source := TJSONObject.Create;
  Source.AddPair('items', TJSONArray.Create.Add(3).Add(4));
  try
    // Default strategy is amsReplace
    JSONDeepMerge(Target, Source, amsReplace);
    
    Arr := Target.GetValue<TJSONArray>('items');
    Assert.AreEqual(2, Integer(Arr.Count));
    Assert.AreEqual(3, Arr.Items[0].GetValue<Integer>);
    Assert.AreEqual(4, Arr.Items[1].GetValue<Integer>);
  finally
    Target.Free;
    Source.Free;
  end;
end;

procedure TTestJSONDeepMerge.Test_JSONDeepMerge_TypeMismatch_SourceOverwrites;
var
  Target, Source: TJSONObject;
begin
  Target := TJSONObject.Create;
  Target.AddPair('field', 'string_value');
  
  Source := TJSONObject.Create;
  Source.AddPair('field', TJSONNumber.Create(42));
  try
    JSONDeepMerge(Target, Source);
    
    Assert.AreEqual(42, Target.GetValue<Integer>('field'));
  finally
    Target.Free;
    Source.Free;
  end;
end;

procedure TTestJSONDeepMerge.Test_JSONDeepMerge_ComplexNested_MergesCorrectly;
var
  Target, Source: TJSONObject;
begin
  Target := TJSONObject.Create;
  Target.AddPair('config', TJSONObject.Create
    .AddPair('server', TJSONObject.Create
      .AddPair('host', 'localhost')
      .AddPair('port', 8080))
    .AddPair('debug', TJSONBool.Create(False)));
  
  Source := TJSONObject.Create;
  Source.AddPair('config', TJSONObject.Create
    .AddPair('server', TJSONObject.Create
      .AddPair('port', 9090)
      .AddPair('ssl', TJSONBool.Create(True)))
    .AddPair('timeout', TJSONNumber.Create(30)));
  try
    JSONDeepMerge(Target, Source);
    
    var Config := Target.GetValue<TJSONObject>('config');
    var Server := Config.GetValue<TJSONObject>('server');
    
    Assert.AreEqual('localhost', Server.GetValue<string>('host'));
    Assert.AreEqual(9090, Server.GetValue<Integer>('port'));
    Assert.IsTrue(Server.GetValue<Boolean>('ssl'));
    Assert.IsFalse(Config.GetValue<Boolean>('debug'));
    Assert.AreEqual(30, Config.GetValue<Integer>('timeout'));
  finally
    Target.Free;
    Source.Free;
  end;
end;

{ TTestLocalConfigStore }

procedure TTestLocalConfigStore.Setup;
begin
  FTempPath := TPath.Combine(TPath.GetTempPath, 'test_config_' + TGUID.NewGuid.ToString + '.json');
  FStore := TLocalConfigStore.Create(FTempPath);
end;

procedure TTestLocalConfigStore.TearDown;
begin
  FStore.Free;
  FStore := nil;
  if TFile.Exists(FTempPath) then
    TFile.Delete(FTempPath);
end;

procedure TTestLocalConfigStore.Test_Put_And_Get;
var
  Item, Retrieved: TConfigItem;
begin
  Item := TConfigItem.Create('test_key', citString);
  Item.SetStringValue('test_value');
  
  FStore.Put(Item);
  Retrieved := FStore.Get('test_key');
  
  Assert.IsNotNull(Retrieved);
  Assert.AreEqual('test_value', Retrieved.GetStringValue);
end;

procedure TTestLocalConfigStore.Test_Get_NonExistent_ReturnsNil;
begin
  Assert.IsNull(FStore.Get('nonexistent'));
end;

procedure TTestLocalConfigStore.Test_GetOrCreate_ExistingKey_ReturnsExisting;
var
  Item, Retrieved: TConfigItem;
begin
  Item := TConfigItem.Create('existing_key', citString);
  Item.SetStringValue('original_value');
  FStore.Put(Item);
  
  Retrieved := FStore.GetOrCreate('existing_key');
  
  Assert.AreEqual('original_value', Retrieved.GetStringValue);
end;

procedure TTestLocalConfigStore.Test_GetOrCreate_NewKey_CreatesItem;
var
  Item: TConfigItem;
begin
  Item := FStore.GetOrCreate('new_key', citInteger);
  
  Assert.IsNotNull(Item);
  Assert.AreEqual('new_key', Item.Key);
end;

procedure TTestLocalConfigStore.Test_Exists_ExistingKey_ReturnsTrue;
var
  Item: TConfigItem;
begin
  Item := TConfigItem.Create('exists_key', citString);
  FStore.Put(Item);
  
  Assert.IsTrue(FStore.Exists('exists_key'));
end;

procedure TTestLocalConfigStore.Test_Exists_NonExistent_ReturnsFalse;
begin
  Assert.IsFalse(FStore.Exists('nonexistent'));
end;

procedure TTestLocalConfigStore.Test_Delete_MarksAsDeleted;
var
  Item: TConfigItem;
begin
  Item := TConfigItem.Create('to_delete', citString);
  FStore.Put(Item);
  
  FStore.Delete('to_delete');
  
  // Item still exists but is marked deleted
  Item := FStore.Get('to_delete');
  Assert.IsNotNull(Item);
  Assert.IsTrue(Item.IsDeleted);
end;

procedure TTestLocalConfigStore.Test_Exists_DeletedKey_ReturnsFalse;
var
  Item: TConfigItem;
begin
  Item := TConfigItem.Create('deleted_key', citString);
  FStore.Put(Item);
  FStore.Delete('deleted_key');
  
  Assert.IsFalse(FStore.Exists('deleted_key'));
end;

procedure TTestLocalConfigStore.Test_GetAll_ReturnsNonDeletedItems;
var
  Item: TConfigItem;
  AllItems: TObjectList<TConfigItem>;
begin
  FStore.Put(TConfigItem.Create('key1', citString));
  FStore.Put(TConfigItem.Create('key2', citString));
  FStore.Put(TConfigItem.Create('key3', citString));
  FStore.Delete('key2');
  
  AllItems := FStore.GetAll;
  try
    Assert.AreEqual<Integer>(2, AllItems.Count);
  finally
    AllItems.Free;
  end;
end;

procedure TTestLocalConfigStore.Test_GetDirtyItems_ReturnsDirtyOnly;
var
  Item: TConfigItem;
  DirtyItems: TObjectList<TConfigItem>;
begin
  Item := TConfigItem.Create('clean', citString);
  Item.IsDirty := False;
  FStore.Put(Item);
  
  Item := TConfigItem.Create('dirty', citString);
  Item.IsDirty := True;
  FStore.Put(Item);
  
  DirtyItems := FStore.GetDirtyItems;
  try
    Assert.AreEqual<Integer>(1, DirtyItems.Count);
    Assert.AreEqual('dirty', DirtyItems[0].Key);
  finally
    DirtyItems.Free;
  end;
end;

procedure TTestLocalConfigStore.Test_MarkAllClean_ClearsDirtyFlags;
var
  Item: TConfigItem;
  DirtyItems: TObjectList<TConfigItem>;
begin
  Item := TConfigItem.Create('dirty1', citString);
  Item.IsDirty := True;
  FStore.Put(Item);
  
  Item := TConfigItem.Create('dirty2', citString);
  Item.IsDirty := True;
  FStore.Put(Item);
  
  FStore.MarkAllClean;
  
  DirtyItems := FStore.GetDirtyItems;
  try
    Assert.AreEqual<Integer>(0, DirtyItems.Count);
  finally
    DirtyItems.Free;
  end;
end;

procedure TTestLocalConfigStore.Test_Clear_RemovesAllItems;
var
  AllItems: TObjectList<TConfigItem>;
begin
  FStore.Put(TConfigItem.Create('key1', citString));
  FStore.Put(TConfigItem.Create('key2', citString));
  
  FStore.Clear;
  
  AllItems := FStore.GetAll;
  try
    Assert.AreEqual<Integer>(0, AllItems.Count);
  finally
    AllItems.Free;
  end;
end;

procedure TTestLocalConfigStore.Test_SaveAndLoad_PersistsData;
var
  Item: TConfigItem;
  NewStore: TLocalConfigStore;
begin
  Item := TConfigItem.Create('persistent_key', citString);
  Item.SetStringValue('persistent_value');
  FStore.Put(Item);
  FStore.Free;
  
  // Create new store from same file
  NewStore := TLocalConfigStore.Create(FTempPath);
  try
    Item := NewStore.Get('persistent_key');
    Assert.IsNotNull(Item);
    Assert.AreEqual('persistent_value', Item.GetStringValue);
  finally
    NewStore.Free;
  end;
  
  // Recreate FStore for TearDown
  FStore := TLocalConfigStore.Create(FTempPath);
end;

procedure TTestLocalConfigStore.Test_CurrentVersion_Persisted;
var
  NewStore: TLocalConfigStore;
begin
  FStore.CurrentVersion := 42;
  FreeAndNil(FStore);
  
  NewStore := TLocalConfigStore.Create(FTempPath);
  try
    Assert.AreEqual(42, NewStore.CurrentVersion);
  finally
    NewStore.Free;
  end;
  
  FStore := TLocalConfigStore.Create(FTempPath);
end;

{ TTestConfigItem }

procedure TTestConfigItem.Test_Create_SetsKeyAndType;
var
  Item: TConfigItem;
begin
  Item := TConfigItem.Create('my_key', citInteger);
  try
    Assert.AreEqual('my_key', Item.Key);
    Assert.AreEqual(citInteger, Item.ItemType);
  finally
    Item.Free;
  end;
end;

procedure TTestConfigItem.Test_SetStringValue_SetsValue;
var
  Item: TConfigItem;
begin
  Item := TConfigItem.Create('key', citString);
  try
    Item.SetStringValue('hello');
    Assert.AreEqual('hello', Item.GetStringValue);
  finally
    Item.Free;
  end;
end;

procedure TTestConfigItem.Test_SetIntegerValue_ConvertsToString;
var
  Item: TConfigItem;
begin
  Item := TConfigItem.Create('key', citInteger);
  try
    Item.SetIntegerValue(42);
    Assert.AreEqual(42, Item.GetIntegerValue);
  finally
    Item.Free;
  end;
end;

procedure TTestConfigItem.Test_SetFloatValue_ConvertsToString;
var
  Item: TConfigItem;
begin
  Item := TConfigItem.Create('key', citFloat);
  try
    Item.SetFloatValue(3.14);
    Assert.AreEqual(3.14, Item.GetFloatValue, 0.001);
  finally
    Item.Free;
  end;
end;

procedure TTestConfigItem.Test_SetBooleanValue_ConvertsToString;
var
  Item: TConfigItem;
begin
  Item := TConfigItem.Create('key', citBoolean);
  try
    Item.SetBooleanValue(True);
    Assert.IsTrue(Item.GetBooleanValue);
    
    Item.SetBooleanValue(False);
    Assert.IsFalse(Item.GetBooleanValue);
  finally
    Item.Free;
  end;
end;

procedure TTestConfigItem.Test_SetDateTimeValue_ConvertsToISO8601;
var
  Item: TConfigItem;
  DT: TDateTime;
begin
  Item := TConfigItem.Create('key', citDateTime);
  try
    DT := EncodeDate(2025, 1, 15) + EncodeTime(10, 30, 0, 0);
    Item.SetDateTimeValue(DT);
    
    // Should be able to retrieve the same date
    Assert.AreEqual(DT, Item.GetDateTimeValue, 1/86400);  // Within 1 second
  finally
    Item.Free;
  end;
end;

procedure TTestConfigItem.Test_SetJSONValue_Serializes;
var
  Item: TConfigItem;
  JSON, Retrieved: TJSONValue;
begin
  Item := TConfigItem.Create('key', citJSON);
  try
    JSON := TJSONObject.Create.AddPair('test', 'data');
    Item.SetJSONValue(JSON);
    JSON.Free;
    
    Retrieved := Item.GetJSONValue;
    try
      Assert.IsNotNull(Retrieved);
      Assert.AreEqual('data', (Retrieved as TJSONObject).GetValue<string>('test'));
    finally
      Retrieved.Free;
    end;
  finally
    Item.Free;
  end;
end;

procedure TTestConfigItem.Test_GetIntegerValue_ParsesString;
var
  Item: TConfigItem;
begin
  Item := TConfigItem.Create('key', citInteger);
  try
    Item.Value := '123';
    Assert.AreEqual(123, Item.GetIntegerValue);
  finally
    Item.Free;
  end;
end;

procedure TTestConfigItem.Test_GetFloatValue_ParsesString;
var
  Item: TConfigItem;
begin
  Item := TConfigItem.Create('key', citFloat);
  try
    Item.Value := '2.718';
    Assert.AreEqual(2.718, Item.GetFloatValue, 0.001);
  finally
    Item.Free;
  end;
end;

procedure TTestConfigItem.Test_GetBooleanValue_ParsesString;
var
  Item: TConfigItem;
begin
  Item := TConfigItem.Create('key', citBoolean);
  try
    Item.Value := 'True';
    Assert.IsTrue(Item.GetBooleanValue);
    
    Item.Value := '1';
    Assert.IsTrue(Item.GetBooleanValue);
    
    Item.Value := 'False';
    Assert.IsFalse(Item.GetBooleanValue);
  finally
    Item.Free;
  end;
end;

procedure TTestConfigItem.Test_ToJSON_SerializesAllFields;
var
  Item: TConfigItem;
  JSON: TJSONObject;
begin
  Item := TConfigItem.Create('my_key', citString);
  try
    Item.SetStringValue('my_value');
    Item.IsDirty := True;
    Item.IsDeleted := False;
    
    JSON := Item.ToJSON;
    try
      Assert.AreEqual('my_key', JSON.GetValue<string>('key'));
      Assert.AreEqual('my_value', JSON.GetValue<string>('value'));
    finally
      JSON.Free;
    end;
  finally
    Item.Free;
  end;
end;

procedure TTestConfigItem.Test_FromJSON_DeserializesAllFields;
var
  JSON: TJSONObject;
  Item: TConfigItem;
begin
  JSON := TJSONObject.Create;
  JSON.AddPair('key', 'restored_key');
  JSON.AddPair('value', 'restored_value');
  JSON.AddPair('type', TJSONNumber.Create(Ord(citString)));
  JSON.AddPair('isDeleted', TJSONBool.Create(False));
  JSON.AddPair('isDirty', TJSONBool.Create(True));
  try
    Item := TConfigItem.FromJSON(JSON);
    try
      Assert.AreEqual('restored_key', Item.Key);
      Assert.AreEqual('restored_value', Item.GetStringValue);
      Assert.AreEqual(citString, Item.ItemType);
      Assert.IsFalse(Item.IsDeleted);
      Assert.IsTrue(Item.IsDirty);
    finally
      Item.Free;
    end;
  finally
    JSON.Free;
  end;
end;

{ TTestConfigVersion }

procedure TTestConfigVersion.Test_Create_InitializesFields;
var
  Version: TConfigVersion;
begin
  Version := TConfigVersion.Create(5, Now, 'device123', 'abc123');
  
  Assert.AreEqual(5, Version.Version);
  Assert.AreEqual('device123', Version.ModifiedBy);
  Assert.AreEqual('abc123', Version.Checksum);
end;

procedure TTestConfigVersion.Test_ToJSON_SerializesCorrectly;
var
  Version: TConfigVersion;
  JSON: TJSONObject;
begin
  Version := TConfigVersion.Create(10, Now, 'device456', 'hash789');
  JSON := Version.ToJSON;
  try
    Assert.AreEqual(10, JSON.GetValue<Integer>('version'));
    Assert.AreEqual('device456', JSON.GetValue<string>('modifiedBy'));
    Assert.AreEqual('hash789', JSON.GetValue<string>('checksum'));
    Assert.IsTrue(JSON.GetValue('modifiedAt') <> nil);
  finally
    JSON.Free;
  end;
end;

procedure TTestConfigVersion.Test_FromJSON_DeserializesCorrectly;
var
  JSON: TJSONObject;
  Version: TConfigVersion;
begin
  JSON := TJSONObject.Create;
  JSON.AddPair('version', TJSONNumber.Create(15));
  JSON.AddPair('modifiedAt', '2025-01-01T12:00:00Z');
  JSON.AddPair('modifiedBy', 'testdevice');
  JSON.AddPair('checksum', 'testhash');
  try
    Version := TConfigVersion.FromJSON(JSON);
    
    Assert.AreEqual(15, Version.Version);
    Assert.AreEqual('testdevice', Version.ModifiedBy);
    Assert.AreEqual('testhash', Version.Checksum);
  finally
    JSON.Free;
  end;
end;

{ TTestCloudServiceConfig }

procedure TTestCloudServiceConfig.Test_Default_SetsReasonableDefaults;
var
  Config: TCloudServiceConfig;
begin
  Config := TCloudServiceConfig.Default;
  
  Assert.IsTrue(Config.TimeoutSeconds > 0, 'Timeout should be positive');
  Assert.IsTrue(Config.RetryCount >= 0, 'RetryCount should be non-negative');
end;

{ TTestSyncProgress }

procedure TTestSyncProgress.Test_ProgressPercent_ZeroTotal_ReturnsZero;
var
  Progress: TSyncProgress;
begin
  Progress.TotalItems := 0;
  Progress.ProcessedItems := 0;
  
  Assert.AreEqual(0, Progress.ProgressPercent);
end;

procedure TTestSyncProgress.Test_ProgressPercent_Calculation;
var
  Progress: TSyncProgress;
begin
  Progress.TotalItems := 100;
  Progress.ProcessedItems := 50;
  
  Assert.AreEqual(50, Progress.ProgressPercent);
end;

{ TTestSyncStatistics }

procedure TTestSyncStatistics.Test_Reset_ClearsAllValues;
var
  Stats: TSyncStatistics;
begin
  Stats.TotalSyncs := 10;
  Stats.SuccessfulSyncs := 8;
  Stats.FailedSyncs := 2;
  Stats.TotalUploaded := 1000;
  Stats.TotalDownloaded := 2000;
  
  Stats.Reset;
  
  Assert.AreEqual(0, Stats.TotalSyncs);
  Assert.AreEqual(0, Stats.SuccessfulSyncs);
  Assert.AreEqual(0, Stats.FailedSyncs);
  Assert.AreEqual(Int64(0), Stats.TotalUploaded);
  Assert.AreEqual(Int64(0), Stats.TotalDownloaded);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestJSONDeepMerge);
  TDUnitX.RegisterTestFixture(TTestLocalConfigStore);
  TDUnitX.RegisterTestFixture(TTestConfigItem);
  TDUnitX.RegisterTestFixture(TTestConfigVersion);
  TDUnitX.RegisterTestFixture(TTestCloudServiceConfig);
  TDUnitX.RegisterTestFixture(TTestSyncProgress);
  TDUnitX.RegisterTestFixture(TTestSyncStatistics);

end.
