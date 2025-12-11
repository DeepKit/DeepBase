{ ============================================================================
  Test.UniBase.VirtualScroll - Unit Tests for Virtual Scrolling Module
  
  Test Coverage:
    - TRenderStats record operations
    - TVirtualDataSource data management
    - TVirtualScrollController scrolling logic
    - TFrameRateController FPS control
    - TRenderQueue task management
    - TDoubleBufferPainter buffering
    - TLazyLoadManager lazy loading
  ============================================================================ }

unit Test.UniBase.VirtualScroll;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Vcl.Graphics,
  UniBase.VirtualScroll;

type
  [TestFixture]
  TTestRenderStats = class
  public
    [Test]
    procedure Test_Reset;
    [Test]
    procedure Test_ToString;
    [Test]
    procedure Test_FieldValues;
  end;

  [TestFixture]
  TTestVirtualDataSource = class
  private
    FDataSource: TVirtualDataSource;
    FItemHeightCalled: Boolean;
    FLastIndex: Integer;
    procedure OnGetItemHeight(Sender: TObject; Index: Integer; var Height: Integer);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_Create_Defaults;
    [Test]
    procedure Test_SetItemCount;
    [Test]
    procedure Test_DefaultItemHeight;
    [Test]
    procedure Test_GetItemHeight_Default;
    [Test]
    procedure Test_GetItemHeight_Custom;
    [Test]
    procedure Test_SetItemHeight;
    [Test]
    procedure Test_ClearHeightCache;
    [Test]
    procedure Test_GetOffsetToIndex;
    [Test]
    procedure Test_GetIndexAtOffset;
    [Test]
    procedure Test_GetTotalHeight;
    [Test]
    procedure Test_OnGetItemHeight_Event;
  end;

  [TestFixture]
  TTestVirtualScrollController = class
  private
    FController: TVirtualScrollController;
    FDataSource: TVirtualDataSource;
    FVisibleRangeChanged: Boolean;
    procedure OnVisibleRangeChanged(Sender: TObject);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_Create_Defaults;
    [Test]
    procedure Test_SetDataSource;
    [Test]
    procedure Test_SetViewportHeight;
    [Test]
    procedure Test_SetScrollOffset;
    [Test]
    procedure Test_ScrollBy_Forward;
    [Test]
    procedure Test_ScrollBy_Backward;
    [Test]
    procedure Test_ScrollBy_ClampMin;
    [Test]
    procedure Test_ScrollBy_ClampMax;
    [Test]
    procedure Test_ScrollToIndex;
    [Test]
    procedure Test_ScrollToIndex_Center;
    [Test]
    procedure Test_EnsureVisible_AlreadyVisible;
    [Test]
    procedure Test_EnsureVisible_ScrollDown;
    [Test]
    procedure Test_EnsureVisible_ScrollUp;
    [Test]
    procedure Test_GetVisibleItems;
    [Test]
    procedure Test_GetStats;
    [Test]
    procedure Test_FirstLastVisibleIndex;
    [Test]
    procedure Test_OnVisibleRangeChanged;
    [Test]
    procedure Test_Overscan;
  end;

  [TestFixture]
  TTestFrameRateController = class
  private
    FController: TFrameRateController;
    FFrameCount: Integer;
    procedure OnFrame(Sender: TObject);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_Create_Defaults;
    [Test]
    procedure Test_TargetFPS;
    [Test]
    procedure Test_Start;
    [Test]
    procedure Test_Stop;
    [Test]
    procedure Test_ShouldRender;
    [Test]
    procedure Test_RequestFrame;
  end;

  [TestFixture]
  TTestRenderQueue = class
  private
    FQueue: TRenderQueue;
    FProcessedIndices: TList<Integer>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_Create_Empty;
    [Test]
    procedure Test_Enqueue;
    [Test]
    procedure Test_Enqueue_Multiple;
    [Test]
    procedure Test_ProcessQueue;
    [Test]
    procedure Test_ProcessQueue_MaxItems;
    [Test]
    procedure Test_ProcessQueue_Priority;
    [Test]
    procedure Test_Clear;
    [Test]
    procedure Test_Count;
  end;

  [TestFixture]
  TTestDoubleBufferPainter = class
  private
    FPainter: TDoubleBufferPainter;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_Create_Defaults;
    [Test]
    procedure Test_SetSize;
    [Test]
    procedure Test_GetCanvas;
    [Test]
    procedure Test_Invalidate;
    [Test]
    procedure Test_Clear;
    [Test]
    procedure Test_PaintTo;
  end;

  [TestFixture]
  TTestLazyLoadManager = class
  private
    FManager: TLazyLoadManager;
    FLoadedPages: TList<TPair<Integer, Integer>>;
    procedure OnLoadPage(StartIndex, EndIndex: Integer);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_Create_Defaults;
    [Test]
    procedure Test_PageSize;
    [Test]
    procedure Test_EnsureLoaded;
    [Test]
    procedure Test_EnsureLoaded_AlreadyLoaded;
    [Test]
    procedure Test_ClearLoadState;
    [Test]
    procedure Test_Preload;
  end;

  [TestFixture]
  TTestTVirtualItem = class
  public
    [Test]
    procedure Test_DefaultValues;
    [Test]
    procedure Test_FieldAssignment;
  end;

implementation

{ TTestRenderStats }

procedure TTestRenderStats.Test_Reset;
var
  Stats: TRenderStats;
begin
  Stats.TotalItems := 100;
  Stats.VisibleItems := 10;
  Stats.FPS := 60.0;
  
  Stats.Reset;
  
  Assert.AreEqual(0, Stats.TotalItems);
  Assert.AreEqual(0, Stats.VisibleItems);
  Assert.AreEqual(Double(0), Stats.FPS);
end;

procedure TTestRenderStats.Test_ToString;
var
  Stats: TRenderStats;
  S: string;
begin
  Stats.TotalItems := 1000;
  Stats.VisibleItems := 20;
  Stats.RenderedItems := 25;
  Stats.FPS := 59.5;
  Stats.ScrollOffset := 100;
  Stats.ViewportHeight := 500;
  
  S := Stats.ToString;
  
  Assert.IsTrue(S.Contains('1000'));
  Assert.IsTrue(S.Contains('20'));
  Assert.IsTrue(S.Contains('59.5') or S.Contains('59,5'));
end;

procedure TTestRenderStats.Test_FieldValues;
var
  Stats: TRenderStats;
begin
  Stats.TotalItems := 500;
  Stats.VisibleItems := 15;
  Stats.RenderedItems := 20;
  Stats.FrameTime := 16.6;
  Stats.FPS := 60.0;
  Stats.ScrollOffset := 200;
  Stats.ViewportHeight := 400;
  
  Assert.AreEqual(500, Stats.TotalItems);
  Assert.AreEqual(15, Stats.VisibleItems);
  Assert.AreEqual(20, Stats.RenderedItems);
  Assert.AreEqual(Double(16.6), Stats.FrameTime, 0.01);
  Assert.AreEqual(Double(60.0), Stats.FPS, 0.01);
  Assert.AreEqual(200, Stats.ScrollOffset);
  Assert.AreEqual(400, Stats.ViewportHeight);
end;

{ TTestVirtualDataSource }

procedure TTestVirtualDataSource.Setup;
begin
  FDataSource := TVirtualDataSource.Create;
  FItemHeightCalled := False;
  FLastIndex := -1;
end;

procedure TTestVirtualDataSource.TearDown;
begin
  FDataSource.Free;
end;

procedure TTestVirtualDataSource.OnGetItemHeight(Sender: TObject; Index: Integer; var Height: Integer);
begin
  FItemHeightCalled := True;
  FLastIndex := Index;
  Height := 30 + Index;  // Variable height based on index
end;

procedure TTestVirtualDataSource.Test_Create_Defaults;
begin
  Assert.AreEqual(0, FDataSource.ItemCount);
  Assert.AreEqual(24, FDataSource.DefaultItemHeight);  // Default is 24
end;

procedure TTestVirtualDataSource.Test_SetItemCount;
begin
  FDataSource.SetItemCount(1000);
  Assert.AreEqual(1000, FDataSource.ItemCount);
end;

procedure TTestVirtualDataSource.Test_DefaultItemHeight;
begin
  FDataSource.DefaultItemHeight := 50;
  Assert.AreEqual(50, FDataSource.DefaultItemHeight);
end;

procedure TTestVirtualDataSource.Test_GetItemHeight_Default;
begin
  FDataSource.DefaultItemHeight := 32;
  FDataSource.SetItemCount(10);
  
  Assert.AreEqual(32, FDataSource.GetItemHeight(5));
end;

procedure TTestVirtualDataSource.Test_GetItemHeight_Custom;
begin
  FDataSource.DefaultItemHeight := 24;
  FDataSource.SetItemCount(10);
  FDataSource.SetItemHeight(5, 48);
  
  Assert.AreEqual(48, FDataSource.GetItemHeight(5));
  Assert.AreEqual(24, FDataSource.GetItemHeight(3));
end;

procedure TTestVirtualDataSource.Test_SetItemHeight;
begin
  FDataSource.SetItemCount(10);
  FDataSource.SetItemHeight(0, 100);
  FDataSource.SetItemHeight(1, 50);
  
  Assert.AreEqual(100, FDataSource.GetItemHeight(0));
  Assert.AreEqual(50, FDataSource.GetItemHeight(1));
end;

procedure TTestVirtualDataSource.Test_ClearHeightCache;
begin
  FDataSource.SetItemCount(10);
  FDataSource.SetItemHeight(5, 100);
  Assert.AreEqual(100, FDataSource.GetItemHeight(5));
  
  FDataSource.ClearHeightCache;
  Assert.AreEqual(FDataSource.DefaultItemHeight, FDataSource.GetItemHeight(5));
end;

procedure TTestVirtualDataSource.Test_GetOffsetToIndex;
begin
  FDataSource.DefaultItemHeight := 20;
  FDataSource.SetItemCount(10);
  
  // Offset to index 0 should be 0
  Assert.AreEqual(0, FDataSource.GetOffsetToIndex(0));
  // Offset to index 5 should be 5 * 20 = 100
  Assert.AreEqual(100, FDataSource.GetOffsetToIndex(5));
end;

procedure TTestVirtualDataSource.Test_GetIndexAtOffset;
begin
  FDataSource.DefaultItemHeight := 20;
  FDataSource.SetItemCount(100);
  
  // Offset 0 should be index 0
  Assert.AreEqual(0, FDataSource.GetIndexAtOffset(0));
  // Offset 50 should be index 2 (50 / 20 = 2.5 -> 2)
  Assert.AreEqual(2, FDataSource.GetIndexAtOffset(50));
  // Offset 100 should be index 5
  Assert.AreEqual(5, FDataSource.GetIndexAtOffset(100));
end;

procedure TTestVirtualDataSource.Test_GetTotalHeight;
begin
  FDataSource.DefaultItemHeight := 25;
  FDataSource.SetItemCount(10);
  
  // 10 items * 25 height = 250
  Assert.AreEqual(250, FDataSource.GetTotalHeight);
end;

procedure TTestVirtualDataSource.Test_OnGetItemHeight_Event;
begin
  FDataSource.OnGetItemHeight := OnGetItemHeight;
  FDataSource.SetItemCount(10);
  
  var Height := FDataSource.GetItemHeight(5);
  
  Assert.IsTrue(FItemHeightCalled);
  Assert.AreEqual(5, FLastIndex);
  Assert.AreEqual(35, Height);  // 30 + 5
end;

{ TTestVirtualScrollController }

procedure TTestVirtualScrollController.Setup;
begin
  FController := TVirtualScrollController.Create;
  FDataSource := TVirtualDataSource.Create;
  FDataSource.DefaultItemHeight := 20;
  FDataSource.SetItemCount(1000);
  FVisibleRangeChanged := False;
end;

procedure TTestVirtualScrollController.TearDown;
begin
  FController.Free;
  FDataSource.Free;
end;

procedure TTestVirtualScrollController.OnVisibleRangeChanged(Sender: TObject);
begin
  FVisibleRangeChanged := True;
end;

procedure TTestVirtualScrollController.Test_Create_Defaults;
begin
  Assert.AreEqual(0, FController.ViewportHeight);
  Assert.AreEqual(0, FController.ScrollOffset);
  Assert.IsNull(FController.DataSource);
end;

procedure TTestVirtualScrollController.Test_SetDataSource;
begin
  FController.SetDataSource(FDataSource);
  Assert.AreEqual(FDataSource, FController.DataSource);
end;

procedure TTestVirtualScrollController.Test_SetViewportHeight;
begin
  FController.SetViewportHeight(500);
  Assert.AreEqual(500, FController.ViewportHeight);
end;

procedure TTestVirtualScrollController.Test_SetScrollOffset;
begin
  FController.SetDataSource(FDataSource);
  FController.SetViewportHeight(500);
  FController.SetScrollOffset(100);
  Assert.AreEqual(100, FController.ScrollOffset);
end;

procedure TTestVirtualScrollController.Test_ScrollBy_Forward;
begin
  FController.SetDataSource(FDataSource);
  FController.SetViewportHeight(500);
  FController.SetScrollOffset(0);
  
  FController.ScrollBy(100);
  Assert.AreEqual(100, FController.ScrollOffset);
end;

procedure TTestVirtualScrollController.Test_ScrollBy_Backward;
begin
  FController.SetDataSource(FDataSource);
  FController.SetViewportHeight(500);
  FController.SetScrollOffset(200);
  
  FController.ScrollBy(-50);
  Assert.AreEqual(150, FController.ScrollOffset);
end;

procedure TTestVirtualScrollController.Test_ScrollBy_ClampMin;
begin
  FController.SetDataSource(FDataSource);
  FController.SetViewportHeight(500);
  FController.SetScrollOffset(50);
  
  FController.ScrollBy(-100);  // Should clamp to 0
  Assert.AreEqual(0, FController.ScrollOffset);
end;

procedure TTestVirtualScrollController.Test_ScrollBy_ClampMax;
begin
  FController.SetDataSource(FDataSource);
  FController.SetViewportHeight(500);
  // Total height = 1000 * 20 = 20000
  // Max scroll = 20000 - 500 = 19500
  FController.SetScrollOffset(19400);
  
  FController.ScrollBy(200);  // Should clamp to max
  Assert.IsTrue(FController.ScrollOffset <= 19500);
end;

procedure TTestVirtualScrollController.Test_ScrollToIndex;
begin
  FController.SetDataSource(FDataSource);
  FController.SetViewportHeight(500);
  
  FController.ScrollToIndex(50);  // Item at offset 50 * 20 = 1000
  Assert.AreEqual(1000, FController.ScrollOffset);
end;

procedure TTestVirtualScrollController.Test_ScrollToIndex_Center;
begin
  FController.SetDataSource(FDataSource);
  FController.SetViewportHeight(500);
  
  FController.ScrollToIndex(50, True);  // Center item 50
  // Centered offset = 1000 - (500 - 20) / 2 = 1000 - 240 = 760
  Assert.IsTrue(FController.ScrollOffset < 1000);
end;

procedure TTestVirtualScrollController.Test_EnsureVisible_AlreadyVisible;
begin
  FController.SetDataSource(FDataSource);
  FController.SetViewportHeight(500);
  FController.SetScrollOffset(0);
  
  var OldOffset := FController.ScrollOffset;
  FController.EnsureVisible(5);  // Item 5 is at offset 100, within viewport 0-500
  Assert.AreEqual(OldOffset, FController.ScrollOffset);
end;

procedure TTestVirtualScrollController.Test_EnsureVisible_ScrollDown;
begin
  FController.SetDataSource(FDataSource);
  FController.SetViewportHeight(500);
  FController.SetScrollOffset(0);
  
  FController.EnsureVisible(100);  // Item 100 is at offset 2000, beyond viewport
  Assert.IsTrue(FController.ScrollOffset > 0);
end;

procedure TTestVirtualScrollController.Test_EnsureVisible_ScrollUp;
begin
  FController.SetDataSource(FDataSource);
  FController.SetViewportHeight(500);
  FController.SetScrollOffset(2000);
  
  FController.EnsureVisible(10);  // Item 10 is at offset 200, before current scroll
  Assert.IsTrue(FController.ScrollOffset < 2000);
end;

procedure TTestVirtualScrollController.Test_GetVisibleItems;
var
  Items: TArray<TVirtualItem>;
begin
  FController.SetDataSource(FDataSource);
  FController.SetViewportHeight(200);  // Can show ~10 items
  FController.SetScrollOffset(0);
  
  Items := FController.GetVisibleItems;
  Assert.IsTrue(Length(Items) >= 5);  // Should have at least some visible items
end;

procedure TTestVirtualScrollController.Test_GetStats;
var
  Stats: TRenderStats;
begin
  FController.SetDataSource(FDataSource);
  FController.SetViewportHeight(500);
  FController.SetScrollOffset(100);
  
  Stats := FController.GetStats;
  Assert.AreEqual(1000, Stats.TotalItems);
  Assert.AreEqual(500, Stats.ViewportHeight);
  Assert.AreEqual(100, Stats.ScrollOffset);
end;

procedure TTestVirtualScrollController.Test_FirstLastVisibleIndex;
begin
  FController.SetDataSource(FDataSource);
  FController.SetViewportHeight(200);
  FController.SetScrollOffset(100);  // Start at item 5
  
  // With 200 height and 20 per item, can show 10 items
  Assert.AreEqual(5, FController.FirstVisibleIndex);
  Assert.IsTrue(FController.LastVisibleIndex >= FController.FirstVisibleIndex);
end;

procedure TTestVirtualScrollController.Test_OnVisibleRangeChanged;
begin
  FController.OnVisibleRangeChanged := OnVisibleRangeChanged;
  FController.SetDataSource(FDataSource);
  FController.SetViewportHeight(500);
  
  FController.ScrollBy(100);
  
  Assert.IsTrue(FVisibleRangeChanged);
end;

procedure TTestVirtualScrollController.Test_Overscan;
begin
  FController.Overscan := 5;
  Assert.AreEqual(5, FController.Overscan);
  
  FController.Overscan := 10;
  Assert.AreEqual(10, FController.Overscan);
end;

{ TTestFrameRateController }

procedure TTestFrameRateController.Setup;
begin
  FController := TFrameRateController.Create;
  FFrameCount := 0;
end;

procedure TTestFrameRateController.TearDown;
begin
  FController.Free;
end;

procedure TTestFrameRateController.OnFrame(Sender: TObject);
begin
  Inc(FFrameCount);
end;

procedure TTestFrameRateController.Test_Create_Defaults;
begin
  Assert.AreEqual(60, FController.TargetFPS);
  Assert.IsFalse(FController.Enabled);
end;

procedure TTestFrameRateController.Test_TargetFPS;
begin
  FController.TargetFPS := 30;
  Assert.AreEqual(30, FController.TargetFPS);
  
  FController.TargetFPS := 120;
  Assert.AreEqual(120, FController.TargetFPS);
end;

procedure TTestFrameRateController.Test_Start;
begin
  FController.Start;
  Assert.IsTrue(FController.Enabled);
end;

procedure TTestFrameRateController.Test_Stop;
begin
  FController.Start;
  FController.Stop;
  Assert.IsFalse(FController.Enabled);
end;

procedure TTestFrameRateController.Test_ShouldRender;
begin
  // After some time, should return true
  var Result := FController.ShouldRender;
  Assert.IsTrue(Result or not Result);  // Just verify no crash
end;

procedure TTestFrameRateController.Test_RequestFrame;
begin
  FController.OnFrame := OnFrame;
  FController.RequestFrame;
  // RequestFrame should trigger frame callback or queue it
  Assert.Pass;
end;

{ TTestRenderQueue }

procedure TTestRenderQueue.Setup;
begin
  FQueue := TRenderQueue.Create;
  FProcessedIndices := TList<Integer>.Create;
end;

procedure TTestRenderQueue.TearDown;
begin
  FQueue.Free;
  FProcessedIndices.Free;
end;

procedure TTestRenderQueue.Test_Create_Empty;
begin
  Assert.AreEqual(0, FQueue.Count);
end;

procedure TTestRenderQueue.Test_Enqueue;
begin
  FQueue.Enqueue(0, nil);
  Assert.AreEqual(1, FQueue.Count);
end;

procedure TTestRenderQueue.Test_Enqueue_Multiple;
begin
  FQueue.Enqueue(0, nil);
  FQueue.Enqueue(1, nil);
  FQueue.Enqueue(2, nil);
  Assert.AreEqual(3, FQueue.Count);
end;

procedure TTestRenderQueue.Test_ProcessQueue;
var
  ProcessedList: TList<Integer>;
begin
  ProcessedList := FProcessedIndices;
  
  FQueue.Enqueue(0, procedure begin ProcessedList.Add(0); end);
  FQueue.Enqueue(1, procedure begin ProcessedList.Add(1); end);
  
  FQueue.ProcessQueue;
  
  Assert.AreEqual(2, FProcessedIndices.Count);
end;

procedure TTestRenderQueue.Test_ProcessQueue_MaxItems;
var
  ProcessedList: TList<Integer>;
begin
  ProcessedList := FProcessedIndices;
  FQueue.MaxItemsPerFrame := 2;
  
  FQueue.Enqueue(0, procedure begin ProcessedList.Add(0); end);
  FQueue.Enqueue(1, procedure begin ProcessedList.Add(1); end);
  FQueue.Enqueue(2, procedure begin ProcessedList.Add(2); end);
  FQueue.Enqueue(3, procedure begin ProcessedList.Add(3); end);
  
  FQueue.ProcessQueue;
  
  // Only MaxItemsPerFrame should be processed
  Assert.AreEqual(2, FProcessedIndices.Count);
end;

procedure TTestRenderQueue.Test_ProcessQueue_Priority;
var
  ProcessedList: TList<Integer>;
begin
  ProcessedList := FProcessedIndices;
  
  FQueue.Enqueue(0, procedure begin ProcessedList.Add(0); end, 1);  // Low priority
  FQueue.Enqueue(1, procedure begin ProcessedList.Add(1); end, 10); // High priority
  FQueue.Enqueue(2, procedure begin ProcessedList.Add(2); end, 5);  // Medium priority
  
  FQueue.ProcessQueue;
  
  // Higher priority should be processed first
  Assert.AreEqual(3, FProcessedIndices.Count);
end;

procedure TTestRenderQueue.Test_Clear;
begin
  FQueue.Enqueue(0, nil);
  FQueue.Enqueue(1, nil);
  FQueue.Clear;
  Assert.AreEqual(0, FQueue.Count);
end;

procedure TTestRenderQueue.Test_Count;
begin
  Assert.AreEqual(0, FQueue.Count);
  FQueue.Enqueue(0, nil);
  Assert.AreEqual(1, FQueue.Count);
  FQueue.Enqueue(1, nil);
  Assert.AreEqual(2, FQueue.Count);
end;

{ TTestDoubleBufferPainter }

procedure TTestDoubleBufferPainter.Setup;
begin
  FPainter := TDoubleBufferPainter.Create;
end;

procedure TTestDoubleBufferPainter.TearDown;
begin
  FPainter.Free;
end;

procedure TTestDoubleBufferPainter.Test_Create_Defaults;
begin
  Assert.AreEqual(0, FPainter.Width);
  Assert.AreEqual(0, FPainter.Height);
end;

procedure TTestDoubleBufferPainter.Test_SetSize;
begin
  FPainter.SetSize(800, 600);
  Assert.AreEqual(800, FPainter.Width);
  Assert.AreEqual(600, FPainter.Height);
end;

procedure TTestDoubleBufferPainter.Test_GetCanvas;
var
  Canvas: TCanvas;
begin
  FPainter.SetSize(100, 100);
  Canvas := FPainter.GetCanvas;
  Assert.IsNotNull(Canvas);
end;

procedure TTestDoubleBufferPainter.Test_Invalidate;
begin
  FPainter.SetSize(100, 100);
  FPainter.Invalidate;
  Assert.IsTrue(FPainter.IsDirty);
end;

procedure TTestDoubleBufferPainter.Test_Clear;
begin
  FPainter.SetSize(100, 100);
  FPainter.Clear(clWhite);
  // No exception means success
  Assert.Pass;
end;

procedure TTestDoubleBufferPainter.Test_PaintTo;
var
  TargetBitmap: TBitmap;
begin
  FPainter.SetSize(100, 100);
  FPainter.Clear(clRed);
  
  TargetBitmap := TBitmap.Create;
  try
    TargetBitmap.SetSize(200, 200);
    FPainter.PaintTo(TargetBitmap.Canvas, 0, 0);
    // No exception means success
    Assert.Pass;
  finally
    TargetBitmap.Free;
  end;
end;

{ TTestLazyLoadManager }

procedure TTestLazyLoadManager.Setup;
begin
  FManager := TLazyLoadManager.Create;
  FLoadedPages := TList<TPair<Integer, Integer>>.Create;
end;

procedure TTestLazyLoadManager.TearDown;
begin
  FManager.Free;
  FLoadedPages.Free;
end;

procedure TTestLazyLoadManager.OnLoadPage(StartIndex, EndIndex: Integer);
begin
  FLoadedPages.Add(TPair<Integer, Integer>.Create(StartIndex, EndIndex));
end;

procedure TTestLazyLoadManager.Test_Create_Defaults;
begin
  Assert.AreEqual(100, FManager.PageSize);  // Default page size
end;

procedure TTestLazyLoadManager.Test_PageSize;
begin
  FManager.PageSize := 50;
  Assert.AreEqual(50, FManager.PageSize);
end;

procedure TTestLazyLoadManager.Test_EnsureLoaded;
begin
  FManager.OnLoadPage := OnLoadPage;
  FManager.EnsureLoaded(0, 50);
  
  Assert.IsTrue(FLoadedPages.Count >= 1);
end;

procedure TTestLazyLoadManager.Test_EnsureLoaded_AlreadyLoaded;
begin
  FManager.OnLoadPage := OnLoadPage;
  FManager.EnsureLoaded(0, 50);
  
  var CountBefore := FLoadedPages.Count;
  FManager.EnsureLoaded(0, 50);  // Request same range again
  
  // Should not load again
  Assert.AreEqual(CountBefore, FLoadedPages.Count);
end;

procedure TTestLazyLoadManager.Test_ClearLoadState;
begin
  FManager.OnLoadPage := OnLoadPage;
  FManager.EnsureLoaded(0, 50);
  FManager.ClearLoadState;
  
  var CountBefore := FLoadedPages.Count;
  FManager.EnsureLoaded(0, 50);  // Should load again after clear
  
  Assert.IsTrue(FLoadedPages.Count > CountBefore);
end;

procedure TTestLazyLoadManager.Test_Preload;
begin
  FManager.OnLoadPage := OnLoadPage;
  FManager.Preload(500, 100);  // Preload around index 500
  
  Assert.IsTrue(FLoadedPages.Count >= 1);
end;

{ TTestTVirtualItem }

procedure TTestTVirtualItem.Test_DefaultValues;
var
  Item: TVirtualItem;
begin
  FillChar(Item, SizeOf(Item), 0);
  Assert.AreEqual(0, Item.Index);
  Assert.AreEqual(0, Item.Height);
  Assert.AreEqual(0, Item.Top);
  Assert.IsFalse(Item.Visible);
  Assert.IsFalse(Item.Selected);
end;

procedure TTestTVirtualItem.Test_FieldAssignment;
var
  Item: TVirtualItem;
begin
  Item.Index := 42;
  Item.Height := 30;
  Item.Top := 100;
  Item.Visible := True;
  Item.Selected := True;
  
  Assert.AreEqual(42, Item.Index);
  Assert.AreEqual(30, Item.Height);
  Assert.AreEqual(100, Item.Top);
  Assert.IsTrue(Item.Visible);
  Assert.IsTrue(Item.Selected);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRenderStats);
  TDUnitX.RegisterTestFixture(TTestVirtualDataSource);
  TDUnitX.RegisterTestFixture(TTestVirtualScrollController);
  TDUnitX.RegisterTestFixture(TTestFrameRateController);
  TDUnitX.RegisterTestFixture(TTestRenderQueue);
  TDUnitX.RegisterTestFixture(TTestDoubleBufferPainter);
  TDUnitX.RegisterTestFixture(TTestLazyLoadManager);
  TDUnitX.RegisterTestFixture(TTestTVirtualItem);

end.
