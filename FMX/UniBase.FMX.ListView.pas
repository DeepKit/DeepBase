unit UniBase.FMX.ListView;

{*******************************************************************************
  UniBase FMX ListView - Enhanced Cross-Platform List Controls

  Provides enhanced ListView components with:
  - Pull-to-refresh support
  - Infinite scrolling/pagination
  - Swipe actions
  - Search/filter integration
  - Empty state views
  - Loading indicators
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.UITypes, System.Types,
  System.Generics.Collections, System.Rtti,
  FMX.Types, FMX.Controls, FMX.ListView, FMX.ListView.Types,
  FMX.ListView.Appearances, FMX.ListView.Adapters.Base, FMX.StdCtrls,
  FMX.Objects, FMX.Layouts, FMX.Effects, FMX.Ani, FMX.Graphics;

type
  /// <summary>Swipe direction</summary>
  TSwipeDirection = (sdLeft, sdRight);

  /// <summary>Swipe action</summary>
  TSwipeAction = record
    Caption: string;
    Color: TAlphaColor;
    IconPath: string;
    Tag: Integer;
    constructor Create(const ACaption: string; AColor: TAlphaColor;
      const AIconPath: string = ''; ATag: Integer = 0);
  end;

  /// <summary>Swipe action event</summary>
  TSwipeActionEvent = procedure(Sender: TObject; ItemIndex: Integer;
    Direction: TSwipeDirection; Action: TSwipeAction) of object;

  /// <summary>Load more event for infinite scrolling</summary>
  TLoadMoreEvent = procedure(Sender: TObject; var HasMore: Boolean) of object;

  /// <summary>Refresh event for pull-to-refresh</summary>
  TRefreshEvent = procedure(Sender: TObject) of object;

  /// <summary>Item filter predicate</summary>
  TItemFilterFunc = reference to function(Item: TListViewItem): Boolean;

  /// <summary>
  /// Enhanced ListView with pull-to-refresh and infinite scrolling
  /// </summary>
  TUniListView = class(TListView)
  private
    // Pull-to-refresh
    FPullToRefresh: Boolean;
    FRefreshIndicator: TAniIndicator;
    FRefreshThreshold: Single;
    FIsRefreshing: Boolean;
    FOnRefresh: TRefreshEvent;
    FPullDistance: Single;

    // Infinite scrolling
    FInfiniteScroll: Boolean;
    FLoadingMore: Boolean;
    FHasMoreData: Boolean;
    FLoadMoreThreshold: Integer;
    FOnLoadMore: TLoadMoreEvent;
    FLoadingIndicator: TAniIndicator;

    // Swipe actions
    FLeftSwipeActions: TList<TSwipeAction>;
    FRightSwipeActions: TList<TSwipeAction>;
    FOnSwipeAction: TSwipeActionEvent;
    FSwipeEnabled: Boolean;

    // Empty state
    FEmptyView: TLayout;
    FEmptyText: TLabel;
    FEmptyImage: TImage;

    // Search/Filter
    FSearchText: string;
    FFilterFunc: TItemFilterFunc;
    FOriginalItems: TList<TListViewItem>;

    procedure SetPullToRefresh(const Value: Boolean);
    procedure SetInfiniteScroll(const Value: Boolean);
    procedure SetSearchText(const Value: string);
    procedure SetEmptyText(const Value: string);
    function GetEmptyText: string;
    procedure UpdateEmptyView;
    procedure CreateRefreshIndicator;
    procedure CreateLoadingIndicator;
    procedure CreateEmptyView;
    procedure DoScrollChanged(Sender: TObject);
  protected
    procedure DoUpdateScrollViewPos(const Value: Single); override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    // Pull-to-refresh
    procedure BeginRefresh;
    procedure EndRefresh;
    property IsRefreshing: Boolean read FIsRefreshing;

    // Infinite scrolling
    procedure BeginLoadMore;
    procedure EndLoadMore(HasMore: Boolean);
    property IsLoadingMore: Boolean read FLoadingMore;
    property HasMoreData: Boolean read FHasMoreData write FHasMoreData;

    // Swipe actions
    procedure AddLeftSwipeAction(const Action: TSwipeAction);
    procedure AddRightSwipeAction(const Action: TSwipeAction);
    procedure ClearSwipeActions;

    // Search/Filter
    procedure ApplyFilter(FilterFunc: TItemFilterFunc);
    procedure ClearFilter;
    procedure Search(const Text: string);

    // Empty state
    procedure SetEmptyImage(const ResourceName: string);
    property EmptyImageControl: TImage read FEmptyImage;
  published
    // Pull-to-refresh properties
    property PullToRefresh: Boolean read FPullToRefresh write SetPullToRefresh default False;
    property RefreshThreshold: Single read FRefreshThreshold write FRefreshThreshold;
    property OnRefresh: TRefreshEvent read FOnRefresh write FOnRefresh;

    // Infinite scroll properties
    property InfiniteScroll: Boolean read FInfiniteScroll write SetInfiniteScroll default False;
    property LoadMoreThreshold: Integer read FLoadMoreThreshold write FLoadMoreThreshold default 5;
    property OnLoadMore: TLoadMoreEvent read FOnLoadMore write FOnLoadMore;

    // Swipe properties
    property SwipeEnabled: Boolean read FSwipeEnabled write FSwipeEnabled default False;
    property OnSwipeAction: TSwipeActionEvent read FOnSwipeAction write FOnSwipeAction;

    // Search/Filter
    property SearchText: string read FSearchText write SetSearchText;

    // Empty state
    property EmptyText: string read GetEmptyText write SetEmptyText;
  end;

  /// <summary>
  /// Pull-to-refresh indicator control
  /// </summary>
  TUniPullRefresh = class(TLayout)
  private
    FIndicator: TAniIndicator;
    FLabel: TLabel;
    FState: (prsIdle, prsPulling, prsRefreshing);
    FPullText: string;
    FReleaseText: string;
    FRefreshingText: string;
    procedure UpdateState;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetPulling(Distance: Single; Threshold: Single);
    procedure BeginRefresh;
    procedure EndRefresh;
    property PullText: string read FPullText write FPullText;
    property ReleaseText: string read FReleaseText write FReleaseText;
    property RefreshingText: string read FRefreshingText write FRefreshingText;
  end;

  /// <summary>
  /// Virtual list adapter for large datasets
  /// </summary>
  TUniVirtualListAdapter = class
  private
    FListView: TListView;
    FTotalCount: Integer;
    FPageSize: Integer;
    FLoadedPages: TDictionary<Integer, Boolean>;
    FOnLoadPage: TProc<Integer>;
  public
    constructor Create(ListView: TListView);
    destructor Destroy; override;
    procedure SetTotalCount(Count: Integer);
    procedure LoadPage(PageIndex: Integer);
    procedure Reset;
    property TotalCount: Integer read FTotalCount;
    property PageSize: Integer read FPageSize write FPageSize;
    property OnLoadPage: TProc<Integer> read FOnLoadPage write FOnLoadPage;
  end;

implementation

uses
  System.Math, FMX.Platform;

{ TSwipeAction }

constructor TSwipeAction.Create(const ACaption: string; AColor: TAlphaColor;
  const AIconPath: string; ATag: Integer);
begin
  Caption := ACaption;
  Color := AColor;
  IconPath := AIconPath;
  Tag := ATag;
end;

{ TUniListView }

constructor TUniListView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FPullToRefresh := False;
  FRefreshThreshold := 80;
  FIsRefreshing := False;
  FPullDistance := 0;

  FInfiniteScroll := False;
  FLoadingMore := False;
  FHasMoreData := True;
  FLoadMoreThreshold := 5;

  FSwipeEnabled := False;
  FLeftSwipeActions := TList<TSwipeAction>.Create;
  FRightSwipeActions := TList<TSwipeAction>.Create;

  CreateEmptyView;
end;

destructor TUniListView.Destroy;
begin
  FLeftSwipeActions.Free;
  FRightSwipeActions.Free;
  FOriginalItems.Free;
  inherited;
end;

procedure TUniListView.CreateRefreshIndicator;
begin
  if FRefreshIndicator = nil then
  begin
    FRefreshIndicator := TAniIndicator.Create(Self);
    FRefreshIndicator.Parent := Self;
    FRefreshIndicator.Align := TAlignLayout.Top;
    FRefreshIndicator.Height := 40;
    FRefreshIndicator.Visible := False;
  end;
end;

procedure TUniListView.CreateLoadingIndicator;
begin
  if FLoadingIndicator = nil then
  begin
    FLoadingIndicator := TAniIndicator.Create(Self);
    FLoadingIndicator.Parent := Self;
    FLoadingIndicator.Align := TAlignLayout.Bottom;
    FLoadingIndicator.Height := 40;
    FLoadingIndicator.Visible := False;
  end;
end;

procedure TUniListView.CreateEmptyView;
begin
  FEmptyView := TLayout.Create(Self);
  FEmptyView.Parent := Self;
  FEmptyView.Align := TAlignLayout.Client;
  FEmptyView.Visible := False;
  FEmptyView.HitTest := False;

  FEmptyImage := TImage.Create(FEmptyView);
  FEmptyImage.Parent := FEmptyView;
  FEmptyImage.Align := TAlignLayout.Top;
  FEmptyImage.Height := 120;
  FEmptyImage.Margins.Top := 40;
  FEmptyImage.WrapMode := TImageWrapMode.Center;

  FEmptyText := TLabel.Create(FEmptyView);
  FEmptyText.Parent := FEmptyView;
  FEmptyText.Align := TAlignLayout.Top;
  FEmptyText.Height := 40;
  FEmptyText.TextSettings.HorzAlign := TTextAlign.Center;
  FEmptyText.Text := 'No items to display';
  FEmptyText.StyledSettings := FEmptyText.StyledSettings - [TStyledSetting.Size];
  FEmptyText.TextSettings.Font.Size := 16;
  FEmptyText.Opacity := 0.6;
end;

procedure TUniListView.SetPullToRefresh(const Value: Boolean);
begin
  if FPullToRefresh <> Value then
  begin
    FPullToRefresh := Value;
    if Value then
      CreateRefreshIndicator
    else if FRefreshIndicator <> nil then
      FRefreshIndicator.Visible := False;
  end;
end;

procedure TUniListView.SetInfiniteScroll(const Value: Boolean);
begin
  if FInfiniteScroll <> Value then
  begin
    FInfiniteScroll := Value;
    if Value then
      CreateLoadingIndicator
    else if FLoadingIndicator <> nil then
      FLoadingIndicator.Visible := False;
  end;
end;

procedure TUniListView.SetSearchText(const Value: string);
begin
  if FSearchText <> Value then
  begin
    FSearchText := Value;
    Search(Value);
  end;
end;

procedure TUniListView.SetEmptyText(const Value: string);
begin
  if FEmptyText <> nil then
    FEmptyText.Text := Value;
end;

function TUniListView.GetEmptyText: string;
begin
  if FEmptyText <> nil then
    Result := FEmptyText.Text
  else
    Result := '';
end;

procedure TUniListView.UpdateEmptyView;
begin
  if FEmptyView <> nil then
    FEmptyView.Visible := (Items.Count = 0) and not FIsRefreshing;
end;

procedure TUniListView.DoUpdateScrollViewPos(const Value: Single);
begin
  inherited;

  // Pull-to-refresh detection
  if FPullToRefresh and not FIsRefreshing then
  begin
    if Value < 0 then
    begin
      FPullDistance := Abs(Value);
      if FRefreshIndicator <> nil then
      begin
        FRefreshIndicator.Visible := True;
        FRefreshIndicator.Height := Min(FPullDistance, FRefreshThreshold);
      end;
    end
    else
    begin
      // Released - check if threshold reached
      if FPullDistance >= FRefreshThreshold then
        BeginRefresh;
      FPullDistance := 0;
    end;
  end;

  // Infinite scroll detection
  if FInfiniteScroll and FHasMoreData and not FLoadingMore then
  begin
    // Check if near bottom
    var ContentHeight := GetItemsHeight;
    var ViewportHeight := Height;
    var ScrollPos := Value;

    if (ContentHeight - ScrollPos - ViewportHeight) < (FLoadMoreThreshold * ItemAppearance.ItemHeight) then
      BeginLoadMore;
  end;
end;

function GetItemsHeight(ListView: TListView): Single;
begin
  Result := ListView.Items.Count * ListView.ItemAppearance.ItemHeight;
end;

procedure TUniListView.Resize;
begin
  inherited;
  UpdateEmptyView;
end;

procedure TUniListView.DoScrollChanged(Sender: TObject);
begin
  // Additional scroll handling if needed
end;

procedure TUniListView.BeginRefresh;
begin
  if FIsRefreshing then Exit;

  FIsRefreshing := True;
  if FRefreshIndicator <> nil then
  begin
    FRefreshIndicator.Visible := True;
    FRefreshIndicator.Enabled := True;
  end;

  if Assigned(FOnRefresh) then
    FOnRefresh(Self);
end;

procedure TUniListView.EndRefresh;
begin
  FIsRefreshing := False;
  FPullDistance := 0;

  if FRefreshIndicator <> nil then
  begin
    FRefreshIndicator.Enabled := False;
    FRefreshIndicator.Visible := False;
  end;

  UpdateEmptyView;
end;

procedure TUniListView.BeginLoadMore;
var
  HasMore: Boolean;
begin
  if FLoadingMore then Exit;

  FLoadingMore := True;
  if FLoadingIndicator <> nil then
  begin
    FLoadingIndicator.Visible := True;
    FLoadingIndicator.Enabled := True;
  end;

  HasMore := True;
  if Assigned(FOnLoadMore) then
    FOnLoadMore(Self, HasMore);

  // If synchronous, end immediately
  if not HasMore then
    EndLoadMore(HasMore);
end;

procedure TUniListView.EndLoadMore(HasMore: Boolean);
begin
  FLoadingMore := False;
  FHasMoreData := HasMore;

  if FLoadingIndicator <> nil then
  begin
    FLoadingIndicator.Enabled := False;
    FLoadingIndicator.Visible := False;
  end;

  UpdateEmptyView;
end;

procedure TUniListView.AddLeftSwipeAction(const Action: TSwipeAction);
begin
  FLeftSwipeActions.Add(Action);
end;

procedure TUniListView.AddRightSwipeAction(const Action: TSwipeAction);
begin
  FRightSwipeActions.Add(Action);
end;

procedure TUniListView.ClearSwipeActions;
begin
  FLeftSwipeActions.Clear;
  FRightSwipeActions.Clear;
end;

procedure TUniListView.ApplyFilter(FilterFunc: TItemFilterFunc);
var
  I: Integer;
begin
  FFilterFunc := FilterFunc;

  // Store original items if not already stored
  if FOriginalItems = nil then
  begin
    FOriginalItems := TList<TListViewItem>.Create;
    for I := 0 to Items.Count - 1 do
      FOriginalItems.Add(Items[I]);
  end;

  // Apply filter
  Items.BeginUpdate;
  try
    for I := Items.Count - 1 downto 0 do
    begin
      if Assigned(FilterFunc) then
        Items[I].Visible := FilterFunc(Items[I])
      else
        Items[I].Visible := True;
    end;
  finally
    Items.EndUpdate;
  end;

  UpdateEmptyView;
end;

procedure TUniListView.ClearFilter;
begin
  FFilterFunc := nil;
  FSearchText := '';

  Items.BeginUpdate;
  try
    for var I := 0 to Items.Count - 1 do
      Items[I].Visible := True;
  finally
    Items.EndUpdate;
  end;

  UpdateEmptyView;
end;

procedure TUniListView.Search(const Text: string);
var
  SearchLower: string;
begin
  SearchLower := LowerCase(Text);

  if SearchLower = '' then
  begin
    ClearFilter;
    Exit;
  end;

  ApplyFilter(
    function(Item: TListViewItem): Boolean
    begin
      Result := Pos(SearchLower, LowerCase(Item.Text)) > 0;
      if not Result and (Item.Detail <> '') then
        Result := Pos(SearchLower, LowerCase(Item.Detail)) > 0;
    end
  );
end;

procedure TUniListView.SetEmptyImage(const ResourceName: string);
begin
  if FEmptyImage <> nil then
  begin
    // Load from resource
    // FEmptyImage.Bitmap.LoadFromResource(ResourceName);
  end;
end;

{ TUniPullRefresh }

constructor TUniPullRefresh.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Height := 60;
  FPullText := 'Pull to refresh';
  FReleaseText := 'Release to refresh';
  FRefreshingText := 'Refreshing...';
  FState := prsIdle;

  FIndicator := TAniIndicator.Create(Self);
  FIndicator.Parent := Self;
  FIndicator.Align := TAlignLayout.Left;
  FIndicator.Width := 40;
  FIndicator.Enabled := False;

  FLabel := TLabel.Create(Self);
  FLabel.Parent := Self;
  FLabel.Align := TAlignLayout.Client;
  FLabel.TextSettings.HorzAlign := TTextAlign.Center;
  FLabel.Text := FPullText;
end;

destructor TUniPullRefresh.Destroy;
begin
  inherited;
end;

procedure TUniPullRefresh.UpdateState;
begin
  case FState of
    prsIdle:
      begin
        FLabel.Text := FPullText;
        FIndicator.Enabled := False;
      end;
    prsPulling:
      begin
        FLabel.Text := FReleaseText;
        FIndicator.Enabled := False;
      end;
    prsRefreshing:
      begin
        FLabel.Text := FRefreshingText;
        FIndicator.Enabled := True;
      end;
  end;
end;

procedure TUniPullRefresh.SetPulling(Distance, Threshold: Single);
begin
  if Distance >= Threshold then
  begin
    if FState <> prsPulling then
    begin
      FState := prsPulling;
      UpdateState;
    end;
  end
  else
  begin
    if FState <> prsIdle then
    begin
      FState := prsIdle;
      UpdateState;
    end;
  end;
end;

procedure TUniPullRefresh.BeginRefresh;
begin
  FState := prsRefreshing;
  UpdateState;
end;

procedure TUniPullRefresh.EndRefresh;
begin
  FState := prsIdle;
  UpdateState;
end;

{ TUniVirtualListAdapter }

constructor TUniVirtualListAdapter.Create(ListView: TListView);
begin
  inherited Create;
  FListView := ListView;
  FPageSize := 20;
  FTotalCount := 0;
  FLoadedPages := TDictionary<Integer, Boolean>.Create;
end;

destructor TUniVirtualListAdapter.Destroy;
begin
  FLoadedPages.Free;
  inherited;
end;

procedure TUniVirtualListAdapter.SetTotalCount(Count: Integer);
var
  I: Integer;
begin
  FTotalCount := Count;
  FListView.Items.BeginUpdate;
  try
    FListView.Items.Clear;
    for I := 0 to Count - 1 do
      FListView.Items.Add.Text := ''; // Placeholder
  finally
    FListView.Items.EndUpdate;
  end;
end;

procedure TUniVirtualListAdapter.LoadPage(PageIndex: Integer);
begin
  if FLoadedPages.ContainsKey(PageIndex) then
    Exit;

  FLoadedPages.Add(PageIndex, True);

  if Assigned(FOnLoadPage) then
    FOnLoadPage(PageIndex);
end;

procedure TUniVirtualListAdapter.Reset;
begin
  FLoadedPages.Clear;
  FListView.Items.Clear;
  FTotalCount := 0;
end;

end.
