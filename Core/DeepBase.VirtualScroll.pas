unit DeepBase.VirtualScroll;

{*******************************************************************************
  DeepBase.VirtualScroll - 虚拟滚动和 UI 渲染优化

  版本: 1.0
  功能:
  - 虚拟滚动 (Virtual Scrolling) - 支持百万级列表
  - 智能渲染 (Smart Rendering) - 只渲染可见区域
  - 帧率控制 (Frame Rate Control)
  - 渲染队列 (Render Queue)
  - 延迟加载 (Lazy Loading)

  适用于:
  - VCL TListView/TListBox 增强
  - FMX 列表控件
  - 自定义绘制控件
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.SyncObjs, System.DateUtils,
  System.Generics.Collections, System.Diagnostics, System.Math,
  {$IFDEF MSWINDOWS}
  Winapi.Windows, Winapi.Messages,
  {$ENDIF}
  Vcl.Controls, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.Graphics, Vcl.ExtCtrls, Vcl.Forms;

type
  /// <summary>虚拟列表项</summary>
  TVirtualItem = record
    Index: Integer;
    Data: Pointer;
    Height: Integer;
    Top: Integer;
    Visible: Boolean;
    Selected: Boolean;
  end;

  /// <summary>渲染统计</summary>
  TRenderStats = record
    TotalItems: Integer;
    VisibleItems: Integer;
    RenderedItems: Integer;
    FrameTime: Double;
    FPS: Double;
    ScrollOffset: Integer;
    ViewportHeight: Integer;
    procedure Reset;
    function ToString: string;
  end;

  /// <summary>项绘制事件</summary>
  TDrawItemEvent = procedure(Sender: TObject; Canvas: TCanvas;
    const Item: TVirtualItem; const Rect: TRect; var Handled: Boolean) of object;

  /// <summary>项高度事件</summary>
  TItemHeightEvent = procedure(Sender: TObject; Index: Integer;
    var Height: Integer) of object;

  /// <summary>数据请求事件</summary>
  TDataRequestEvent = procedure(Sender: TObject; StartIndex, Count: Integer) of object;

  /// <summary>
  /// 虚拟滚动数据源
  /// </summary>
  TVirtualDataSource = class
  private
    FItemCount: Integer;
    FDefaultItemHeight: Integer;
    FOnGetItemHeight: TItemHeightEvent;
    FOnDataRequest: TDataRequestEvent;
    FItemHeights: TDictionary<Integer, Integer>;
    FLock: TCriticalSection;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>设置项目总数</summary>
    procedure SetItemCount(Count: Integer);

    /// <summary>获取项目高度</summary>
    function GetItemHeight(Index: Integer): Integer;

    /// <summary>设置特定项目高度</summary>
    procedure SetItemHeight(Index: Integer; Height: Integer);

    /// <summary>清除高度缓存</summary>
    procedure ClearHeightCache;

    /// <summary>获取累计高度到指定索引</summary>
    function GetOffsetToIndex(Index: Integer): Integer;

    /// <summary>根据偏移量获取索引</summary>
    function GetIndexAtOffset(Offset: Integer): Integer;

    /// <summary>获取总内容高度</summary>
    function GetTotalHeight: Integer;

    property ItemCount: Integer read FItemCount;
    property DefaultItemHeight: Integer read FDefaultItemHeight write FDefaultItemHeight;
    property OnGetItemHeight: TItemHeightEvent read FOnGetItemHeight write FOnGetItemHeight;
    property OnDataRequest: TDataRequestEvent read FOnDataRequest write FOnDataRequest;
  end;

  /// <summary>
  /// 虚拟滚动控制器
  /// </summary>
  TVirtualScrollController = class
  private
    FDataSource: TVirtualDataSource;
    FViewportHeight: Integer;
    FScrollOffset: Integer;
    FVisibleItems: TList<TVirtualItem>;
    FOverscan: Integer;  // 预渲染的额外行数
    FStats: TRenderStats;
    FLastRenderTime: TDateTime;
    FOnVisibleRangeChanged: TNotifyEvent;

    procedure CalculateVisibleItems;
    function GetFirstVisibleIndex: Integer;
    function GetLastVisibleIndex: Integer;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>设置数据源</summary>
    procedure SetDataSource(Source: TVirtualDataSource);

    /// <summary>设置视口高度</summary>
    procedure SetViewportHeight(Height: Integer);

    /// <summary>设置滚动偏移</summary>
    procedure SetScrollOffset(Offset: Integer);

    /// <summary>滚动指定量</summary>
    procedure ScrollBy(Delta: Integer);

    /// <summary>滚动到指定项</summary>
    procedure ScrollToIndex(Index: Integer; Center: Boolean = False);

    /// <summary>确保项可见</summary>
    procedure EnsureVisible(Index: Integer);

    /// <summary>获取可见项列表</summary>
    function GetVisibleItems: TArray<TVirtualItem>;

    /// <summary>获取渲染统计</summary>
    function GetStats: TRenderStats;

    property DataSource: TVirtualDataSource read FDataSource;
    property ViewportHeight: Integer read FViewportHeight;
    property ScrollOffset: Integer read FScrollOffset;
    property Overscan: Integer read FOverscan write FOverscan;
    property FirstVisibleIndex: Integer read GetFirstVisibleIndex;
    property LastVisibleIndex: Integer read GetLastVisibleIndex;
    property OnVisibleRangeChanged: TNotifyEvent read FOnVisibleRangeChanged
      write FOnVisibleRangeChanged;
  end;

  /// <summary>
  /// 帧率控制器
  /// </summary>
  TFrameRateController = class
  private
    FTargetFPS: Integer;
    FFrameInterval: Integer;  // ms
    FLastFrameTime: TDateTime;
    FFrameCount: Integer;
    FActualFPS: Double;
    FEnabled: Boolean;
    FTimer: TTimer;
    FOnFrame: TNotifyEvent;

    procedure TimerTick(Sender: TObject);
    procedure UpdateFPS;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>开始帧控制</summary>
    procedure Start;

    /// <summary>停止帧控制</summary>
    procedure Stop;

    /// <summary>请求下一帧</summary>
    procedure RequestFrame;

    /// <summary>检查是否应该渲染</summary>
    function ShouldRender: Boolean;

    property TargetFPS: Integer read FTargetFPS write FTargetFPS;
    property ActualFPS: Double read FActualFPS;
    property Enabled: Boolean read FEnabled;
    property OnFrame: TNotifyEvent read FOnFrame write FOnFrame;
  end;

  /// <summary>
  /// 渲染队列项
  /// </summary>
  TRenderQueueItem = record
    Priority: Integer;
    Index: Integer;
    Callback: TProc;
  end;

  /// <summary>
  /// 渲染队列管理器
  /// </summary>
  TRenderQueue = class
  private
    FQueue: TList<TRenderQueueItem>;
    FLock: TCriticalSection;
    FMaxItemsPerFrame: Integer;
    FProcessing: Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>添加渲染任务</summary>
    procedure Enqueue(Index: Integer; Callback: TProc; Priority: Integer = 0);

    /// <summary>处理队列</summary>
    procedure ProcessQueue;

    /// <summary>清空队列</summary>
    procedure Clear;

    /// <summary>获取队列长度</summary>
    function Count: Integer;

    property MaxItemsPerFrame: Integer read FMaxItemsPerFrame write FMaxItemsPerFrame;
  end;

  /// <summary>
  /// 双缓冲绘制器
  /// </summary>
  TDoubleBufferPainter = class
  private
    FBuffer: TBitmap;
    FWidth: Integer;
    FHeight: Integer;
    FDirty: Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>设置缓冲区大小</summary>
    procedure SetSize(AWidth, AHeight: Integer);

    /// <summary>获取缓冲区画布</summary>
    function GetCanvas: TCanvas;

    /// <summary>绘制到目标</summary>
    procedure PaintTo(Target: TCanvas; X, Y: Integer);

    /// <summary>标记为脏需重绘</summary>
    procedure Invalidate;

    /// <summary>清除缓冲区</summary>
    procedure Clear(Color: TColor = clWhite);

    property Width: Integer read FWidth;
    property Height: Integer read FHeight;
    property IsDirty: Boolean read FDirty;
  end;

  /// <summary>
  /// 增强虚拟 ListBox
  /// </summary>
  TUniVirtualListBox = class(TCustomControl)
  private
    FDataSource: TVirtualDataSource;
    FScrollController: TVirtualScrollController;
    FFrameController: TFrameRateController;
    FRenderQueue: TRenderQueue;
    FBufferPainter: TDoubleBufferPainter;

    FScrollBar: TScrollBar;
    FItemHeight: Integer;
    FSelectedIndex: Integer;
    FHoverIndex: Integer;

    FOnDrawItem: TDrawItemEvent;
    FOnSelectChange: TNotifyEvent;
    FOnItemClick: TNotifyEvent;

    procedure ScrollBarChange(Sender: TObject);
    procedure UpdateScrollBar;
    procedure DrawItems;
    procedure DrawItem(Index: Integer; const ItemRect: TRect);
    function GetItemAtY(Y: Integer): Integer;
    procedure DoSelectChange;

  protected
    procedure Paint; override;
    procedure Resize; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
      MousePos: TPoint): Boolean; override;
    procedure CreateWnd; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    /// <summary>设置项目数量</summary>
    procedure SetItemCount(Count: Integer);

    /// <summary>刷新显示</summary>
    procedure RefreshDisplay;

    /// <summary>滚动到指定项</summary>
    procedure ScrollToItem(Index: Integer);

    /// <summary>获取渲染统计</summary>
    function GetRenderStats: TRenderStats;

    property DataSource: TVirtualDataSource read FDataSource;
    property SelectedIndex: Integer read FSelectedIndex write FSelectedIndex;
    property ItemHeight: Integer read FItemHeight write FItemHeight;

    property OnDrawItem: TDrawItemEvent read FOnDrawItem write FOnDrawItem;
    property OnSelectChange: TNotifyEvent read FOnSelectChange write FOnSelectChange;
    property OnItemClick: TNotifyEvent read FOnItemClick write FOnItemClick;
  end;

  /// <summary>
  /// 延迟加载管理器
  /// </summary>
  TLazyLoadManager = class
  private
    FLoadedRanges: TList<TPair<Integer, Integer>>;
    FPageSize: Integer;
    FOnLoadPage: TProc<Integer, Integer>;
    FLock: TCriticalSection;

    function IsLoaded(Index: Integer): Boolean;
    procedure MarkLoaded(StartIndex, EndIndex: Integer);
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>确保数据已加载</summary>
    procedure EnsureLoaded(StartIndex, EndIndex: Integer);

    /// <summary>清除加载状态</summary>
    procedure ClearLoadState;

    /// <summary>预加载</summary>
    procedure Preload(AroundIndex: Integer; Range: Integer = 100);

    property PageSize: Integer read FPageSize write FPageSize;
    property OnLoadPage: TProc<Integer, Integer> read FOnLoadPage write FOnLoadPage;
  end;

implementation

{ TRenderStats }

procedure TRenderStats.Reset;
begin
  FillChar(Self, SizeOf(Self), 0);
end;

function TRenderStats.ToString: string;
begin
  Result := Format(
    '渲染统计:' + sLineBreak +
    '  总项数: %d' + sLineBreak +
    '  可见项: %d' + sLineBreak +
    '  已渲染: %d' + sLineBreak +
    '  帧时间: %.2f ms' + sLineBreak +
    '  FPS: %.1f' + sLineBreak +
    '  滚动偏移: %d' + sLineBreak +
    '  视口高度: %d',
    [TotalItems, VisibleItems, RenderedItems, FrameTime,
     FPS, ScrollOffset, ViewportHeight]);
end;

{ TVirtualDataSource }

constructor TVirtualDataSource.Create;
begin
  inherited Create;
  FItemCount := 0;
  FDefaultItemHeight := 24;
  FItemHeights := TDictionary<Integer, Integer>.Create;
  FLock := TCriticalSection.Create;
end;

destructor TVirtualDataSource.Destroy;
begin
  FreeAndNil(FItemHeights);
  FreeAndNil(FLock);
  inherited;
end;

procedure TVirtualDataSource.SetItemCount(Count: Integer);
begin
  FLock.Enter;
  try
    FItemCount := Count;
  finally
    FLock.Leave;
  end;
end;

function TVirtualDataSource.GetItemHeight(Index: Integer): Integer;
begin
  FLock.Enter;
  try
    if not FItemHeights.TryGetValue(Index, Result) then
    begin
      Result := FDefaultItemHeight;
      if Assigned(FOnGetItemHeight) then
        FOnGetItemHeight(Self, Index, Result);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TVirtualDataSource.SetItemHeight(Index: Integer; Height: Integer);
begin
  FLock.Enter;
  try
    FItemHeights.AddOrSetValue(Index, Height);
  finally
    FLock.Leave;
  end;
end;

procedure TVirtualDataSource.ClearHeightCache;
begin
  FLock.Enter;
  try
    FItemHeights.Clear;
  finally
    FLock.Leave;
  end;
end;

function TVirtualDataSource.GetOffsetToIndex(Index: Integer): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to Min(Index, FItemCount) - 1 do
    Inc(Result, GetItemHeight(I));
end;

function TVirtualDataSource.GetIndexAtOffset(Offset: Integer): Integer;
var
  CurrentOffset: Integer;
begin
  Result := 0;
  CurrentOffset := 0;

  while (Result < FItemCount) and (CurrentOffset < Offset) do
  begin
    Inc(CurrentOffset, GetItemHeight(Result));
    if CurrentOffset <= Offset then
      Inc(Result);
  end;
end;

function TVirtualDataSource.GetTotalHeight: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FItemCount - 1 do
    Inc(Result, GetItemHeight(I));
end;

{ TVirtualScrollController }

constructor TVirtualScrollController.Create;
begin
  inherited Create;
  FVisibleItems := TList<TVirtualItem>.Create;
  FOverscan := 3;
  FStats.Reset;
end;

destructor TVirtualScrollController.Destroy;
begin
  FreeAndNil(FVisibleItems);
  inherited;
end;

procedure TVirtualScrollController.SetDataSource(Source: TVirtualDataSource);
begin
  FDataSource := Source;
  CalculateVisibleItems;
end;

procedure TVirtualScrollController.SetViewportHeight(Height: Integer);
begin
  if FViewportHeight <> Height then
  begin
    FViewportHeight := Height;
    CalculateVisibleItems;
  end;
end;

procedure TVirtualScrollController.SetScrollOffset(Offset: Integer);
var
  MaxOffset: Integer;
begin
  if FDataSource = nil then
    Exit;

  MaxOffset := Max(0, FDataSource.GetTotalHeight - FViewportHeight);
  Offset := EnsureRange(Offset, 0, MaxOffset);

  if FScrollOffset <> Offset then
  begin
    FScrollOffset := Offset;
    CalculateVisibleItems;

    if Assigned(FOnVisibleRangeChanged) then
      FOnVisibleRangeChanged(Self);
  end;
end;

procedure TVirtualScrollController.ScrollBy(Delta: Integer);
begin
  SetScrollOffset(FScrollOffset + Delta);
end;

procedure TVirtualScrollController.ScrollToIndex(Index: Integer; Center: Boolean);
var
  ItemOffset: Integer;
begin
  if FDataSource = nil then
    Exit;

  // 加强边界检查
  if (Index < 0) or (FDataSource.ItemCount = 0) then
    Exit;
  Index := EnsureRange(Index, 0, FDataSource.ItemCount - 1);
  ItemOffset := FDataSource.GetOffsetToIndex(Index);

  if Center then
    ItemOffset := ItemOffset - (FViewportHeight - FDataSource.GetItemHeight(Index)) div 2;

  SetScrollOffset(ItemOffset);
end;

procedure TVirtualScrollController.EnsureVisible(Index: Integer);
var
  ItemTop, ItemBottom: Integer;
begin
  if FDataSource = nil then
    Exit;

  Index := EnsureRange(Index, 0, FDataSource.ItemCount - 1);
  ItemTop := FDataSource.GetOffsetToIndex(Index);
  ItemBottom := ItemTop + FDataSource.GetItemHeight(Index);

  if ItemTop < FScrollOffset then
    SetScrollOffset(ItemTop)
  else if ItemBottom > FScrollOffset + FViewportHeight then
    SetScrollOffset(ItemBottom - FViewportHeight);
end;

procedure TVirtualScrollController.CalculateVisibleItems;
var
  StartWatch: TStopwatch;
  FirstIndex, LastIndex, I: Integer;
  CurrentTop: Integer;
  Item: TVirtualItem;
begin
  if FDataSource = nil then
    Exit;

  StartWatch := TStopwatch.StartNew;
  FVisibleItems.Clear;

  // 计算第一个可见项，加强边界检查
  FirstIndex := FDataSource.GetIndexAtOffset(FScrollOffset);
  FirstIndex := Max(0, FirstIndex - FOverscan);
  FirstIndex := Min(FirstIndex, FDataSource.ItemCount - 1);

  // 计算最后一个可见项，加强边界检查
  LastIndex := FDataSource.GetIndexAtOffset(FScrollOffset + FViewportHeight);
  LastIndex := Min(FDataSource.ItemCount - 1, LastIndex + FOverscan);
  LastIndex := Max(FirstIndex, LastIndex); // 确保LastIndex >= FirstIndex

  // 请求数据加载
  if Assigned(FDataSource.OnDataRequest) then
    FDataSource.OnDataRequest(Self, FirstIndex, LastIndex - FirstIndex + 1);

  // 构建可见项列表
  CurrentTop := FDataSource.GetOffsetToIndex(FirstIndex) - FScrollOffset;

  for I := FirstIndex to LastIndex do
  begin
    // 防止无限循环 - 检查索引有效性
    if (I < 0) or (I >= FDataSource.ItemCount) then
      Break;
      
    Item.Index := I;
    Item.Data := nil;
    Item.Height := FDataSource.GetItemHeight(I);
    
    // 防止负高度或过大高度
    if Item.Height <= 0 then
      Item.Height := FDataSource.DefaultItemHeight;
    if Item.Height > 10000 then // 限制最大高度
      Item.Height := 10000;
      
    Item.Top := CurrentTop;
    Item.Visible := (CurrentTop + Item.Height > 0) and (CurrentTop < FViewportHeight);
    Item.Selected := False;
    FVisibleItems.Add(Item);
    Inc(CurrentTop, Item.Height);
    
    // 防止整数溢出
    if CurrentTop > MaxInt - Item.Height then
      Break;
  end;

  // 更新统计
  FStats.TotalItems := FDataSource.ItemCount;
  FStats.VisibleItems := FVisibleItems.Count;
  FStats.ScrollOffset := FScrollOffset;
  FStats.ViewportHeight := FViewportHeight;
  FStats.FrameTime := StartWatch.Elapsed.TotalMilliseconds;
  FLastRenderTime := Now;
end;

function TVirtualScrollController.GetFirstVisibleIndex: Integer;
var
  I: Integer;
begin
  for I := 0 to FVisibleItems.Count - 1 do
  begin
    if FVisibleItems[I].Visible then
      Exit(FVisibleItems[I].Index);
  end;

  Result := 0;
end;

function TVirtualScrollController.GetLastVisibleIndex: Integer;
var
  I: Integer;
begin
  for I := FVisibleItems.Count - 1 downto 0 do
  begin
    if FVisibleItems[I].Visible then
      Exit(FVisibleItems[I].Index);
  end;

  Result := 0;
end;

function TVirtualScrollController.GetVisibleItems: TArray<TVirtualItem>;
begin
  Result := FVisibleItems.ToArray;
end;

function TVirtualScrollController.GetStats: TRenderStats;
begin
  Result := FStats;
end;

{ TFrameRateController }

constructor TFrameRateController.Create;
begin
  inherited Create;
  FTargetFPS := 60;
  FFrameInterval := 1000 div FTargetFPS;
  FEnabled := False;
  FFrameCount := 0;

  FTimer := TTimer.Create(nil);
  FTimer.Enabled := False;
  FTimer.Interval := FFrameInterval;
  FTimer.OnTimer := TimerTick;
end;

destructor TFrameRateController.Destroy;
begin
  FreeAndNil(FTimer);
  inherited;
end;

procedure TFrameRateController.TimerTick(Sender: TObject);
begin
  Inc(FFrameCount);
  UpdateFPS;

  if Assigned(FOnFrame) then
    FOnFrame(Self);
end;

procedure TFrameRateController.UpdateFPS;
var
  Elapsed: Double;
begin
  Elapsed := MilliSecondsBetween(Now, FLastFrameTime);
  if Elapsed > 0 then
    FActualFPS := 1000 / Elapsed;
  FLastFrameTime := Now;
end;

procedure TFrameRateController.Start;
begin
  FEnabled := True;
  FLastFrameTime := Now;
  FTimer.Interval := 1000 div FTargetFPS;
  FTimer.Enabled := True;
end;

procedure TFrameRateController.Stop;
begin
  FEnabled := False;
  FTimer.Enabled := False;
end;

procedure TFrameRateController.RequestFrame;
begin
  if FEnabled and Assigned(FOnFrame) then
    FOnFrame(Self);
end;

function TFrameRateController.ShouldRender: Boolean;
begin
  Result := MilliSecondsBetween(Now, FLastFrameTime) >= FFrameInterval;
end;

{ TRenderQueue }

constructor TRenderQueue.Create;
begin
  inherited Create;
  FQueue := TList<TRenderQueueItem>.Create;
  FLock := TCriticalSection.Create;
  FMaxItemsPerFrame := 10;
  FProcessing := False;
end;

destructor TRenderQueue.Destroy;
begin
  FreeAndNil(FQueue);
  FreeAndNil(FLock);
  inherited;
end;

procedure TRenderQueue.Enqueue(Index: Integer; Callback: TProc; Priority: Integer);
var
  Item: TRenderQueueItem;
  I: Integer;
begin
  Item.Priority := Priority;
  Item.Index := Index;
  Item.Callback := Callback;

  FLock.Enter;
  try
    // 按优先级插入
    for I := 0 to FQueue.Count - 1 do
    begin
      if FQueue[I].Priority < Priority then
      begin
        FQueue.Insert(I, Item);
        Exit;
      end;
    end;
    FQueue.Add(Item);
  finally
    FLock.Leave;
  end;
end;

procedure TRenderQueue.ProcessQueue;
var
  I, ProcessCount: Integer;
  Item: TRenderQueueItem;
begin
  if FProcessing then
    Exit;

  FProcessing := True;
  try
    FLock.Enter;
    try
      ProcessCount := Min(FMaxItemsPerFrame, FQueue.Count);
      for I := 0 to ProcessCount - 1 do
      begin
        Item := FQueue[0];
        FQueue.Delete(0);

        // 执行回调
        if Assigned(Item.Callback) then
        begin
          try
            Item.Callback();
          except
            on E: Exception do
              // 忽略渲染错误，但记录调试信息
              {$IFDEF DEBUG}
              OutputDebugString(PChar('DeepBase.VirtualScroll: Render callback error: ' + E.Message));
              {$ENDIF}
          end;
        end;
      end;
    finally
      FLock.Leave;
    end;
  finally
    FProcessing := False;
  end;
end;

procedure TRenderQueue.Clear;
begin
  FLock.Enter;
  try
    FQueue.Clear;
  finally
    FLock.Leave;
  end;
end;

function TRenderQueue.Count: Integer;
begin
  FLock.Enter;
  try
    Result := FQueue.Count;
  finally
    FLock.Leave;
  end;
end;

{ TDoubleBufferPainter }

constructor TDoubleBufferPainter.Create;
begin
  inherited Create;
  FBuffer := TBitmap.Create;
  FWidth := 0;
  FHeight := 0;
  FDirty := True;
end;

destructor TDoubleBufferPainter.Destroy;
begin
  FreeAndNil(FBuffer);
  inherited;
end;

procedure TDoubleBufferPainter.SetSize(AWidth, AHeight: Integer);
begin
  if (FWidth <> AWidth) or (FHeight <> AHeight) then
  begin
    FWidth := AWidth;
    FHeight := AHeight;
    FBuffer.SetSize(AWidth, AHeight);
    FDirty := True;
  end;
end;

function TDoubleBufferPainter.GetCanvas: TCanvas;
begin
  Result := FBuffer.Canvas;
end;

procedure TDoubleBufferPainter.PaintTo(Target: TCanvas; X, Y: Integer);
begin
  Target.Draw(X, Y, FBuffer);
  FDirty := False;
end;

procedure TDoubleBufferPainter.Invalidate;
begin
  FDirty := True;
end;

procedure TDoubleBufferPainter.Clear(Color: TColor);
begin
  FBuffer.Canvas.Brush.Color := Color;
  FBuffer.Canvas.FillRect(Rect(0, 0, FWidth, FHeight));
end;

{ TUniVirtualListBox }

constructor TUniVirtualListBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  ControlStyle := ControlStyle + [csOpaque];
  TabStop := True;
  Width := 200;
  Height := 300;

  FItemHeight := 24;
  FSelectedIndex := -1;
  FHoverIndex := -1;

  FDataSource := TVirtualDataSource.Create;
  FDataSource.DefaultItemHeight := FItemHeight;

  FScrollController := TVirtualScrollController.Create;
  FScrollController.SetDataSource(FDataSource);

  FFrameController := TFrameRateController.Create;
  FRenderQueue := TRenderQueue.Create;
  FBufferPainter := TDoubleBufferPainter.Create;

  FScrollBar := TScrollBar.Create(Self);
  FScrollBar.Parent := Self;
  FScrollBar.Kind := sbVertical;
  FScrollBar.Align := alRight;
  FScrollBar.Width := 17;
  FScrollBar.OnChange := ScrollBarChange;
end;

destructor TUniVirtualListBox.Destroy;
begin
  FreeAndNil(FFrameController);
  FreeAndNil(FRenderQueue);
  FreeAndNil(FBufferPainter);
  FreeAndNil(FScrollController);
  FreeAndNil(FDataSource);
  inherited;
end;

procedure TUniVirtualListBox.CreateWnd;
begin
  inherited;
  UpdateScrollBar;
end;

procedure TUniVirtualListBox.SetItemCount(Count: Integer);
begin
  FDataSource.SetItemCount(Count);
  UpdateScrollBar;
  RefreshDisplay;
end;

procedure TUniVirtualListBox.RefreshDisplay;
begin
  FScrollController.SetViewportHeight(ClientHeight);
  FBufferPainter.Invalidate;
  Invalidate;
end;

procedure TUniVirtualListBox.ScrollToItem(Index: Integer);
begin
  FScrollController.ScrollToIndex(Index);
  UpdateScrollBar;
  RefreshDisplay;
end;

function TUniVirtualListBox.GetRenderStats: TRenderStats;
begin
  Result := FScrollController.GetStats;
end;

procedure TUniVirtualListBox.ScrollBarChange(Sender: TObject);
begin
  FScrollController.SetScrollOffset(FScrollBar.Position);
  RefreshDisplay;
end;

procedure TUniVirtualListBox.UpdateScrollBar;
var
  TotalHeight: Integer;
begin
  TotalHeight := FDataSource.GetTotalHeight;
  FScrollBar.Max := Max(0, TotalHeight - ClientHeight);
  FScrollBar.Position := FScrollController.ScrollOffset;
  FScrollBar.PageSize := ClientHeight;
  FScrollBar.Visible := TotalHeight > ClientHeight;
end;

procedure TUniVirtualListBox.Paint;
begin
  FScrollController.SetViewportHeight(ClientHeight);
  FBufferPainter.SetSize(ClientWidth - FScrollBar.Width, ClientHeight);

  if FBufferPainter.IsDirty then
    DrawItems;

  FBufferPainter.PaintTo(Canvas, 0, 0);
end;

procedure TUniVirtualListBox.DrawItems;
var
  Items: TArray<TVirtualItem>;
  I: Integer;
  ItemRect: TRect;
  BufferCanvas: TCanvas;
begin
  BufferCanvas := FBufferPainter.GetCanvas;
  FBufferPainter.Clear(Color);

  Items := FScrollController.GetVisibleItems;

  for I := 0 to High(Items) do
  begin
    ItemRect := Rect(0, Items[I].Top, FBufferPainter.Width, Items[I].Top + Items[I].Height);

    // 只绘制可见区域
    if (ItemRect.Bottom > 0) and (ItemRect.Top < FBufferPainter.Height) then
      DrawItem(Items[I].Index, ItemRect);
  end;
end;

procedure TUniVirtualListBox.DrawItem(Index: Integer; const ItemRect: TRect);
var
  BufferCanvas: TCanvas;
  Item: TVirtualItem;
  Handled: Boolean;
begin
  BufferCanvas := FBufferPainter.GetCanvas;

  Item.Index := Index;
  Item.Height := ItemRect.Height;
  Item.Top := ItemRect.Top;
  Item.Selected := Index = FSelectedIndex;

  // 绘制背景
  if Item.Selected then
    BufferCanvas.Brush.Color := clHighlight
  else if Index = FHoverIndex then
    BufferCanvas.Brush.Color := clBtnFace
  else
    BufferCanvas.Brush.Color := Color;

  BufferCanvas.FillRect(ItemRect);

  // 自定义绘制
  Handled := False;
  if Assigned(FOnDrawItem) then
    FOnDrawItem(Self, BufferCanvas, Item, ItemRect, Handled);

  if not Handled then
  begin
    // 默认绘制
    if Item.Selected then
      BufferCanvas.Font.Color := clHighlightText
    else
      BufferCanvas.Font.Color := Font.Color;

    BufferCanvas.TextOut(ItemRect.Left + 4, ItemRect.Top + 2,
      Format('Item %d', [Index]));
  end;
end;

function TUniVirtualListBox.GetItemAtY(Y: Integer): Integer;
var
  Items: TArray<TVirtualItem>;
  I: Integer;
begin
  Result := -1;
  Items := FScrollController.GetVisibleItems;

  for I := 0 to High(Items) do
  begin
    if (Y >= Items[I].Top) and (Y < Items[I].Top + Items[I].Height) then
    begin
      Result := Items[I].Index;
      Exit;
    end;
  end;
end;

procedure TUniVirtualListBox.DoSelectChange;
begin
  if Assigned(FOnSelectChange) then
    FOnSelectChange(Self);
end;

procedure TUniVirtualListBox.Resize;
begin
  inherited;
  UpdateScrollBar;
  RefreshDisplay;
end;

procedure TUniVirtualListBox.MouseDown(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
var
  Index: Integer;
begin
  inherited;
  SetFocus;

  if Button = mbLeft then
  begin
    Index := GetItemAtY(Y);
    if Index >= 0 then
    begin
      FSelectedIndex := Index;
      DoSelectChange;
      RefreshDisplay;

      if Assigned(FOnItemClick) then
        FOnItemClick(Self);
    end;
  end;
end;

procedure TUniVirtualListBox.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  Index: Integer;
begin
  inherited;
  Index := GetItemAtY(Y);
  if Index <> FHoverIndex then
  begin
    FHoverIndex := Index;
    RefreshDisplay;
  end;
end;

procedure TUniVirtualListBox.MouseUp(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  inherited;
end;

procedure TUniVirtualListBox.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited;

  case Key of
    VK_UP:
      if FSelectedIndex > 0 then
      begin
        Dec(FSelectedIndex);
        FScrollController.EnsureVisible(FSelectedIndex);
        UpdateScrollBar;
        DoSelectChange;
        RefreshDisplay;
      end;

    VK_DOWN:
      if FSelectedIndex < FDataSource.ItemCount - 1 then
      begin
        Inc(FSelectedIndex);
        FScrollController.EnsureVisible(FSelectedIndex);
        UpdateScrollBar;
        DoSelectChange;
        RefreshDisplay;
      end;

    VK_PRIOR: // Page Up
      begin
        FSelectedIndex := Max(0, FSelectedIndex - (ClientHeight div FItemHeight));
        FScrollController.EnsureVisible(FSelectedIndex);
        UpdateScrollBar;
        DoSelectChange;
        RefreshDisplay;
      end;

    VK_NEXT: // Page Down
      begin
        FSelectedIndex := Min(FDataSource.ItemCount - 1,
          FSelectedIndex + (ClientHeight div FItemHeight));
        FScrollController.EnsureVisible(FSelectedIndex);
        UpdateScrollBar;
        DoSelectChange;
        RefreshDisplay;
      end;

    VK_HOME:
      begin
        FSelectedIndex := 0;
        FScrollController.ScrollToIndex(0);
        UpdateScrollBar;
        DoSelectChange;
        RefreshDisplay;
      end;

    VK_END:
      begin
        FSelectedIndex := FDataSource.ItemCount - 1;
        FScrollController.ScrollToIndex(FSelectedIndex);
        UpdateScrollBar;
        DoSelectChange;
        RefreshDisplay;
      end;
  end;
end;

function TUniVirtualListBox.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
  MousePos: TPoint): Boolean;
begin
  Result := True;
  FScrollController.ScrollBy(-WheelDelta div 4);
  UpdateScrollBar;
  RefreshDisplay;
end;

{ TLazyLoadManager }

constructor TLazyLoadManager.Create;
begin
  inherited Create;
  FLoadedRanges := TList<TPair<Integer, Integer>>.Create;
  FPageSize := 100;
  FLock := TCriticalSection.Create;
end;

destructor TLazyLoadManager.Destroy;
begin
  FreeAndNil(FLoadedRanges);
  FreeAndNil(FLock);
  inherited;
end;

function TLazyLoadManager.IsLoaded(Index: Integer): Boolean;
var
  Range: TPair<Integer, Integer>;
begin
  Result := False;
  FLock.Enter;
  try
    for Range in FLoadedRanges do
    begin
      if (Index >= Range.Key) and (Index <= Range.Value) then
      begin
        Result := True;
        Exit;
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TLazyLoadManager.MarkLoaded(StartIndex, EndIndex: Integer);
var
  Range: TPair<Integer, Integer>;
begin
  FLock.Enter;
  try
    // 简单实现：直接添加范围，实际应该合并重叠范围
    Range := TPair<Integer, Integer>.Create(StartIndex, EndIndex);
    FLoadedRanges.Add(Range);
  finally
    FLock.Leave;
  end;
end;

procedure TLazyLoadManager.EnsureLoaded(StartIndex, EndIndex: Integer);
var
  PageStart, PageEnd: Integer;
begin
  // 计算需要加载的页
  PageStart := (StartIndex div FPageSize) * FPageSize;
  PageEnd := ((EndIndex div FPageSize) + 1) * FPageSize - 1;

  // 检查是否已加载
  if not IsLoaded(StartIndex) or not IsLoaded(EndIndex) then
  begin
    if Assigned(FOnLoadPage) then
      FOnLoadPage(PageStart, PageEnd);
    MarkLoaded(PageStart, PageEnd);
  end;
end;

procedure TLazyLoadManager.ClearLoadState;
begin
  FLock.Enter;
  try
    FLoadedRanges.Clear;
  finally
    FLock.Leave;
  end;
end;

procedure TLazyLoadManager.Preload(AroundIndex, Range: Integer);
var
  StartIndex, EndIndex: Integer;
begin
  StartIndex := Max(0, AroundIndex - Range);
  EndIndex := AroundIndex + Range;
  EnsureLoaded(StartIndex, EndIndex);
end;

end.
