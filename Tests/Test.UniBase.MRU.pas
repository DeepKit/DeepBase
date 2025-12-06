unit Test.UniBase.MRU;

{*******************************************************************************
  UniBase MRU 模块单元测试
  
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
  UniBase.Types, UniBase.Manager, UniBase.MRU;

type
  [TestFixture]
  TTestUniBaseMRU = class
  private
    FMRU: TUniBaseMRU;
    FTestCategory: string;
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

{ TTestUniBaseMRU }

procedure TTestUniBaseMRU.Setup;
begin
  if not UniBase.IsInitialized then
    UniBase.InitializeWithDB(':memory:');
  
  FMRU := UniBase.MRU;
  FTestCategory := 'test_' + TGUID.NewGuid.ToString;
end;

procedure TTestUniBaseMRU.TearDown;
begin
  // 清理测试数据
  if FMRU <> nil then
    FMRU.ClearMRU(FTestCategory);
  FMRU := nil;
end;

procedure TTestUniBaseMRU.Test_AddMRU_SingleItem;
var
  Items: TArray<string>;
begin
  FMRU.AddMRU(FTestCategory, 'key1', 'Display 1');
  
  Items := FMRU.GetMRUList(FTestCategory);
  
  Assert.AreEqual(1, Length(Items), '应该有 1 个项目');
  Assert.AreEqual('key1', Items[0], 'Key 应该正确');
end;

procedure TTestUniBaseMRU.Test_AddMRU_MultipleItems;
var
  Items: TArray<string>;
begin
  FMRU.AddMRU(FTestCategory, 'key1', 'Display 1');
  FMRU.AddMRU(FTestCategory, 'key2', 'Display 2');
  FMRU.AddMRU(FTestCategory, 'key3', 'Display 3');
  
  Items := FMRU.GetMRUList(FTestCategory);
  
  Assert.AreEqual(3, Length(Items), '应该有 3 个项目');
end;

procedure TTestUniBaseMRU.Test_AddMRU_DuplicateKey_UpdatesTimestamp;
var
  ItemsBefore, ItemsAfter: TArray<TMRUItem>;
begin
  FMRU.AddMRU(FTestCategory, 'key1', 'Display 1');
  Sleep(100);
  ItemsBefore := FMRU.GetMRUItems(FTestCategory);
  
  Sleep(100);
  FMRU.AddMRU(FTestCategory, 'key1', 'Display 1 Updated');
  ItemsAfter := FMRU.GetMRUItems(FTestCategory);
  
  Assert.AreEqual(1, Length(ItemsAfter), '不应该有重复项');
  Assert.IsTrue(ItemsAfter[0].LastAccess >= ItemsBefore[0].LastAccess, 
    '时间戳应该更新');
end;

procedure TTestUniBaseMRU.Test_GetMRUList_ReturnsKeys;
var
  Items: TArray<string>;
begin
  FMRU.AddMRU(FTestCategory, 'file1.txt', 'File 1');
  FMRU.AddMRU(FTestCategory, 'file2.txt', 'File 2');
  
  Items := FMRU.GetMRUList(FTestCategory);
  
  Assert.AreEqual(2, Length(Items), '应该有 2 个项目');
end;

procedure TTestUniBaseMRU.Test_GetMRUItems_ReturnsFullInfo;
var
  Items: TArray<TMRUItem>;
begin
  FMRU.AddMRU(FTestCategory, 'mykey', 'My Display Name');
  
  Items := FMRU.GetMRUItems(FTestCategory);
  
  Assert.AreEqual(1, Length(Items), '应该有 1 个项目');
  Assert.AreEqual('mykey', Items[0].ItemKey, 'ItemKey 应该正确');
  Assert.AreEqual('My Display Name', Items[0].DisplayName, 'DisplayName 应该正确');
  Assert.IsTrue(Items[0].AccessCount >= 1, 'AccessCount 应该至少为 1');
end;

procedure TTestUniBaseMRU.Test_GetMRUList_MaxItems;
var
  Items: TArray<string>;
  I: Integer;
begin
  // 添加 10 个项目
  for I := 1 to 10 do
    FMRU.AddMRU(FTestCategory, 'key' + IntToStr(I), 'Display ' + IntToStr(I));
  
  // 只获取 5 个
  Items := FMRU.GetMRUList(FTestCategory, 5);
  
  Assert.AreEqual(5, Length(Items), '应该只返回 5 个项目');
end;

procedure TTestUniBaseMRU.Test_GetMRUList_SortedByLastAccess;
var
  Items: TArray<TMRUItem>;
begin
  FMRU.AddMRU(FTestCategory, 'old', 'Old Item');
  Sleep(100);
  FMRU.AddMRU(FTestCategory, 'new', 'New Item');
  
  Items := FMRU.GetMRUItems(FTestCategory);
  
  // 最新的应该排在前面
  Assert.AreEqual('new', Items[0].ItemKey, '最新项应该排在第一位');
end;

procedure TTestUniBaseMRU.Test_ClearMRU;
var
  Items: TArray<string>;
begin
  FMRU.AddMRU(FTestCategory, 'key1', 'Display 1');
  FMRU.AddMRU(FTestCategory, 'key2', 'Display 2');
  
  FMRU.ClearMRU(FTestCategory);
  
  Items := FMRU.GetMRUList(FTestCategory);
  
  Assert.AreEqual(0, Length(Items), '清除后应该没有项目');
end;

procedure TTestUniBaseMRU.Test_ClearMRU_ByCategory;
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
  
  Assert.AreEqual(0, Length(Items1), '清除的分类应该没有项目');
  Assert.AreEqual(1, Length(Items2), '其他分类不应该受影响');
  
  // 清理
  FMRU.ClearMRU(OtherCategory);
end;

procedure TTestUniBaseMRU.Test_RemoveMRU_SingleItem;
var
  Items: TArray<string>;
begin
  FMRU.AddMRU(FTestCategory, 'key1', 'Display 1');
  FMRU.AddMRU(FTestCategory, 'key2', 'Display 2');
  
  FMRU.RemoveMRU(FTestCategory, 'key1');
  
  Items := FMRU.GetMRUList(FTestCategory);
  
  Assert.AreEqual(1, Length(Items), '删除后应该只有 1 个项目');
  Assert.AreEqual('key2', Items[0], '剩余的应该是 key2');
end;

procedure TTestUniBaseMRU.Test_RemoveInvalidMRU_RemovesNonexistentFiles;
var
  TempFile: string;
  Items: TArray<string>;
begin
  // 创建一个临时文件
  TempFile := TPath.Combine(TPath.GetTempPath, 'mru_test_' + TGUID.NewGuid.ToString + '.tmp');
  TFile.WriteAllText(TempFile, 'test');
  
  try
    // 添加存在的文件和不存在的文件
    FMRU.AddMRU(FTestCategory, TempFile, 'Existing File');
    FMRU.AddMRU(FTestCategory, 'C:\nonexistent\file.txt', 'Nonexistent File');
    
    // 移除无效项
    FMRU.RemoveInvalidMRU(FTestCategory);
    
    Items := FMRU.GetMRUList(FTestCategory);
    
    Assert.AreEqual(1, Length(Items), '只有存在的文件应该保留');
    Assert.AreEqual(TempFile, Items[0], '保留的应该是存在的文件');
  finally
    if TFile.Exists(TempFile) then
      TFile.Delete(TempFile);
  end;
end;

procedure TTestUniBaseMRU.Test_AccessCount_Increments;
var
  Items: TArray<TMRUItem>;
  InitialCount: Integer;
begin
  FMRU.AddMRU(FTestCategory, 'key1', 'Display 1');
  Items := FMRU.GetMRUItems(FTestCategory);
  InitialCount := Items[0].AccessCount;
  
  // 再次添加同一个 key
  FMRU.AddMRU(FTestCategory, 'key1', 'Display 1');
  Items := FMRU.GetMRUItems(FTestCategory);
  
  Assert.IsTrue(Items[0].AccessCount > InitialCount, 'AccessCount 应该增加');
end;

procedure TTestUniBaseMRU.Test_DifferentCategories_Isolated;
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
  
  Assert.AreEqual(1, Length(Items1), 'Cat1 应该有 1 个项目');
  Assert.AreEqual(1, Length(Items2), 'Cat2 应该有 1 个项目');
  Assert.AreEqual('key1', Items1[0], 'Cat1 的 key 应该正确');
  Assert.AreEqual('key2', Items2[0], 'Cat2 的 key 应该正确');
  
  // 清理
  FMRU.ClearMRU(Cat1);
  FMRU.ClearMRU(Cat2);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestUniBaseMRU);

end.
