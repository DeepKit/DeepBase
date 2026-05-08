unit Test.DeepBase.MRU;

{*******************************************************************************
  DeepBase MRU 模块单元测试
  
  测试内容:
  - AddMRU / GetMRUList / GetMRUItems
  - ClearMRU / RemoveInvalidMRU
  - 排序验证
  - 重复添加处理
*******************************************************************************}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils, System.Classes, System.IOUtils,
  DeepBase.Types, DeepBase.Manager, DeepBase.MRU;

type
  [TestFixture]
  TTestDeepBaseMRU = class
  private
    FMRU: TDeepBaseMRU;
    FTestCategory: string;
    FManager: TDeepBaseManager;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_AddMRU_SingleItem;
    
    [Test]
    procedure Test_AddMRU_MultipleItems;
    
    [Test]
    procedure Test_AddMRU_DuplicateKey_UpdatesTimestamp;
    
    [Test]
    procedure Test_GetMRUList_ReturnsKeys;
    
    [Test]
    procedure Test_GetMRUItems_ReturnsFullInfo;
    
    [Test]
    procedure Test_GetMRUList_MaxItems;
    
    [Test]
    procedure Test_GetMRUList_SortedByLastAccess;
    
    [Test]
    procedure Test_ClearMRU;
    
    [Test]
    procedure Test_ClearMRU_ByCategory;
    
    [Test]
    procedure Test_RemoveMRU_SingleItem;
    
    [Test]
    procedure Test_RemoveInvalidMRU_RemovesNonexistentFiles;
    
    [Test]
    procedure Test_AccessCount_Increments;
    
    [Test]
    procedure Test_DifferentCategories_Isolated;
  end;

implementation

{ TTestDeepBaseMRU }

procedure TTestDeepBaseMRU.Setup;
begin
  FManager := DeepBase.Manager.DeepBase;
  if not FManager.IsInitialized then
    FManager.InitializeWithDB(':memory:');
  FMRU := FManager.MRU;
  FTestCategory := 'test_' + TGUID.NewGuid.ToString;
end;

procedure TTestDeepBaseMRU.TearDown;
begin
  // 清理测试数据
  if FMRU <> nil then
    FMRU.ClearMRU(FTestCategory);
  FMRU := nil;
end;

procedure TTestDeepBaseMRU.Test_AddMRU_SingleItem;
var
  Items: TArray<string>;
begin
  FMRU.AddMRU(FTestCategory, 'key1', 'Display 1');
  
  Items := FMRU.GetMRUList(FTestCategory);
  
  Assert.AreEqual(Integer(1), Integer(Length(Items)), 'should have 1 item');
  Assert.AreEqual('key1', string(Items[0]), 'Key 应该正确');
end;

procedure TTestDeepBaseMRU.Test_AddMRU_MultipleItems;
var
  Items: TArray<string>;
begin
  FMRU.AddMRU(FTestCategory, 'key1', 'Display 1');
  FMRU.AddMRU(FTestCategory, 'key2', 'Display 2');
  FMRU.AddMRU(FTestCategory, 'key3', 'Display 3');
  
  Items := FMRU.GetMRUList(FTestCategory);
  
  Assert.AreEqual(Integer(3), Integer(Length(Items)), 'should have 3 items');
end;

procedure TTestDeepBaseMRU.Test_AddMRU_DuplicateKey_UpdatesTimestamp;
var
  ItemsBefore, ItemsAfter: TArray<TMRUItem>;
begin
  FMRU.AddMRU(FTestCategory, 'key1', 'Display 1');
  Sleep(100);
  ItemsBefore := FMRU.GetMRUItems(FTestCategory);
  
  Sleep(100);
  FMRU.AddMRU(FTestCategory, 'key1', 'Display 1 Updated');
  ItemsAfter := FMRU.GetMRUItems(FTestCategory);
  
  Assert.AreEqual(Integer(1), Integer(Length(ItemsAfter)), 'duplicate key should not create duplicate item');
  Assert.IsTrue(ItemsAfter[0].LastAccess >= ItemsBefore[0].LastAccess, 
    'timestamp should be updated');
end;

procedure TTestDeepBaseMRU.Test_GetMRUList_ReturnsKeys;
var
  Items: TArray<string>;
begin
  FMRU.AddMRU(FTestCategory, 'file1.txt', 'File 1');
  FMRU.AddMRU(FTestCategory, 'file2.txt', 'File 2');
  
  Items := FMRU.GetMRUList(FTestCategory);
  
  Assert.AreEqual(Integer(2), Integer(Length(Items)), 'should have 2 items');
end;

procedure TTestDeepBaseMRU.Test_GetMRUItems_ReturnsFullInfo;
var
  Items: TArray<TMRUItem>;
begin
  FMRU.AddMRU(FTestCategory, 'mykey', 'My Display Name');
  
  Items := FMRU.GetMRUItems(FTestCategory);
  
  Assert.AreEqual(Integer(1), Integer(Length(Items)), 'should have 1 item');
  Assert.AreEqual('mykey', string(Items[0].ItemKey), 'ItemKey 应该正确');
  Assert.AreEqual('My Display Name', string(Items[0].DisplayName), 'DisplayName 应该正确');
  Assert.IsTrue(Items[0].AccessCount >= 1, 'AccessCount 应该至少�?1');
end;

procedure TTestDeepBaseMRU.Test_GetMRUList_MaxItems;
var
  Items: TArray<string>;
  I: Integer;
begin
  // 添加 10 个项�?
  for I := 1 to 10 do
    FMRU.AddMRU(FTestCategory, 'key' + IntToStr(I), 'Display ' + IntToStr(I));
  
  // 只获�?5 �?
  Items := FMRU.GetMRUList(FTestCategory, 5);
  
  Assert.AreEqual(Integer(5), Integer(Length(Items)), 'should return only 5 items');
end;

procedure TTestDeepBaseMRU.Test_GetMRUList_SortedByLastAccess;
var
  Items: TArray<TMRUItem>;
begin
  FMRU.AddMRU(FTestCategory, 'old', 'Old Item');
  Sleep(100);
  FMRU.AddMRU(FTestCategory, 'new', 'New Item');
  
  Items := FMRU.GetMRUItems(FTestCategory);
  
  // 最新的应该排在前面
  Assert.AreEqual('new', string(Items[0].ItemKey), 'newest item should be first');
end;

procedure TTestDeepBaseMRU.Test_ClearMRU;
var
  Items: TArray<string>;
begin
  FMRU.AddMRU(FTestCategory, 'key1', 'Display 1');
  FMRU.AddMRU(FTestCategory, 'key2', 'Display 2');
  
  FMRU.ClearMRU(FTestCategory);
  
  Items := FMRU.GetMRUList(FTestCategory);
  
  Assert.AreEqual(Integer(0), Integer(Length(Items)), 'items should be empty after clear');
end;

procedure TTestDeepBaseMRU.Test_ClearMRU_ByCategory;
var
  OtherCategory: string;
  Items1, Items2: TArray<string>;
begin
  OtherCategory := 'other_' + TGUID.NewGuid.ToString;
  
  FMRU.AddMRU(FTestCategory, 'key1', 'Display 1');
  FMRU.AddMRU(OtherCategory, 'key2', 'Display 2');
  
  FMRU.ClearMRU(FTestCategory);
  
  Items1 := FMRU.GetMRUList(FTestCategory);
  Items2 := FMRU.GetMRUList(OtherCategory);
  
  Assert.AreEqual(Integer(0), Integer(Length(Items1)), 'cleared category should be empty');
  Assert.AreEqual(Integer(1), Integer(Length(Items2)), '其他分类不应该受影响');
  
  // 清理
  FMRU.ClearMRU(OtherCategory);
end;

procedure TTestDeepBaseMRU.Test_RemoveMRU_SingleItem;
var
  Items: TArray<string>;
begin
  FMRU.AddMRU(FTestCategory, 'key1', 'Display 1');
  FMRU.AddMRU(FTestCategory, 'key2', 'Display 2');
  
  FMRU.RemoveMRU(FTestCategory, 'key1');
  
  Items := FMRU.GetMRUList(FTestCategory);
  
  Assert.AreEqual(Integer(1), Integer(Length(Items)), 'should have 1 item after removal');
  Assert.AreEqual('key2', string(Items[0]), '剩余的应该是 key2');
end;

procedure TTestDeepBaseMRU.Test_RemoveInvalidMRU_RemovesNonexistentFiles;
var
  TempFile: string;
  Items: TArray<string>;
begin
  // 创建一个临时文�?
  TempFile := TPath.Combine(TPath.GetTempPath, 'mru_test_' + TGUID.NewGuid.ToString + '.tmp');
  TFile.WriteAllText(TempFile, 'test');
  
  try
    // 添加存在的文件和不存在的文件
    FMRU.AddMRU(FTestCategory, TempFile, 'Existing File');
    FMRU.AddMRU(FTestCategory, 'C:\nonexistent\file.txt', 'Nonexistent File');
    
    // 移除无效�?
    FMRU.RemoveInvalidMRU(FTestCategory);
    
    Items := FMRU.GetMRUList(FTestCategory);
    
    Assert.AreEqual(Integer(1), Integer(Length(Items)), 'only existing file should remain');
    Assert.AreEqual(TempFile, string(Items[0]), 'remaining item should be the existing file');
  finally
    if TFile.Exists(TempFile) then
      TFile.Delete(TempFile);
  end;
end;

procedure TTestDeepBaseMRU.Test_AccessCount_Increments;
var
  Items: TArray<TMRUItem>;
  InitialCount: Integer;
begin
  FMRU.AddMRU(FTestCategory, 'key1', 'Display 1');
  Items := FMRU.GetMRUItems(FTestCategory);
  InitialCount := Items[0].AccessCount;
  
  // 再次添加同一�?key
  FMRU.AddMRU(FTestCategory, 'key1', 'Display 1');
  Items := FMRU.GetMRUItems(FTestCategory);
  
  Assert.IsTrue(Items[0].AccessCount > InitialCount, 'AccessCount 应该增加');
end;

procedure TTestDeepBaseMRU.Test_DifferentCategories_Isolated;
var
  Cat1, Cat2: string;
  Items1, Items2: TArray<string>;
begin
  Cat1 := 'cat1_' + TGUID.NewGuid.ToString;
  Cat2 := 'cat2_' + TGUID.NewGuid.ToString;
  
  FMRU.AddMRU(Cat1, 'key1', 'Display 1');
  FMRU.AddMRU(Cat2, 'key2', 'Display 2');
  
  Items1 := FMRU.GetMRUList(Cat1);
  Items2 := FMRU.GetMRUList(Cat2);
  
  Assert.AreEqual(Integer(1), Integer(Length(Items1)), 'Cat1 should have 1 item');
  Assert.AreEqual(Integer(1), Integer(Length(Items2)), 'Cat2 should have 1 item');
  Assert.AreEqual('key1', string(Items1[0]), 'Cat1 �?key 应该正确');
  Assert.AreEqual('key2', string(Items2[0]), 'Cat2 �?key 应该正确');
  
  // 清理
  FMRU.ClearMRU(Cat1);
  FMRU.ClearMRU(Cat2);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDeepBaseMRU);

end.
