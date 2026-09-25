{ ============================================================================
  Test.DeepBase.VirtualScrollZeroHeight - A2-08 regression

  TVirtualDataSource.GetIndexAtOffset must advance CurrentOffset by at least
  one unit per iteration: 0/negative item heights may no longer stall the
  scan. Zero-height items are treated as 1px during the traversal, so the
  returned index stays bounded and meaningful even for degenerate heights.
  ============================================================================ }

unit Test.DeepBase.VirtualScrollZeroHeight;

interface

uses
  DUnitX.TestFramework,
  DeepBase.VirtualScroll;

type
  [TestFixture]
  TTestVirtualScrollZeroHeightA208 = class
  private
    FSource: TVirtualDataSource;
  public
    [Setup]
    procedure SetUp;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_MixedZeroHeight_ItemTreatedAsOnePixel;

    [Test]
    procedure Test_AllZeroHeights_LargeItemCount_BoundedResult;

    [Test]
    procedure Test_NegativeHeight_StillAdvances;

    [Test]
    procedure Test_UniformPositiveHeights_SemanticsUnchanged;
  end;

implementation

uses
  System.SysUtils;

{ TTestVirtualScrollZeroHeightA208 }

procedure TTestVirtualScrollZeroHeightA208.SetUp;
begin
  FSource := TVirtualDataSource.Create;
end;

procedure TTestVirtualScrollZeroHeightA208.TearDown;
begin
  FSource.Free;
end;

procedure TTestVirtualScrollZeroHeightA208.Test_MixedZeroHeight_ItemTreatedAsOnePixel;
begin
  FSource.DefaultItemHeight := 10;
  FSource.SetItemCount(3);
  FSource.SetItemHeight(0, 2);
  FSource.SetItemHeight(1, 0); // zero-height item in the middle
  FSource.SetItemHeight(2, 2);
  // scan: item0 ends at 2 (<=2 -> index 1); item1 counts as 1px, ends at 3 (>2)
  Assert.AreEqual(1, FSource.GetIndexAtOffset(2));
  Assert.AreEqual(2, FSource.GetIndexAtOffset(3));
end;

procedure TTestVirtualScrollZeroHeightA208.Test_AllZeroHeights_LargeItemCount_BoundedResult;
var
  Idx: Integer;
begin
  // Degenerate list: every height resolves to 0. Pre-fix the offset never
  // advanced and the scan ran to ItemCount; post-fix each step advances 1px
  // so the walk is bounded by the offset, not the item count.
  FSource.DefaultItemHeight := 0;
  FSource.SetItemCount(100000);
  Idx := FSource.GetIndexAtOffset(500);
  Assert.IsTrue(Idx >= 0);
  Assert.IsTrue(Idx < 600,
    'zero-height scan must advance >=1px per step, got index ' + IntToStr(Idx));
  Assert.AreEqual(500, Idx);
end;

procedure TTestVirtualScrollZeroHeightA208.Test_NegativeHeight_StillAdvances;
begin
  FSource.DefaultItemHeight := 10;
  FSource.SetItemCount(5);
  FSource.SetItemHeight(0, -50); // hostile cached height
  // clamp to 1px: item0 ends at 1 (<=5 -> index 1), item1 ends at 11 (>5)
  Assert.AreEqual(1, FSource.GetIndexAtOffset(5));
end;

procedure TTestVirtualScrollZeroHeightA208.Test_UniformPositiveHeights_SemanticsUnchanged;
begin
  FSource.DefaultItemHeight := 20;
  FSource.SetItemCount(10);
  Assert.AreEqual(0, FSource.GetIndexAtOffset(0));
  Assert.AreEqual(0, FSource.GetIndexAtOffset(19));
  Assert.AreEqual(1, FSource.GetIndexAtOffset(20));
  Assert.AreEqual(2, FSource.GetIndexAtOffset(50));
  Assert.AreEqual(10, FSource.GetIndexAtOffset(100000));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestVirtualScrollZeroHeightA208);

end.
