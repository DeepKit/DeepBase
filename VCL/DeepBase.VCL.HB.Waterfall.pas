{ ============================================================================
  DeepBase.VCL.HB.Waterfall - Modern Token-Driven Faceted Waterfall Component

  Version: 1.3 (Delphi 13.1 on Win64)
  Description: THbFacetWaterfall:
               - Left Facet Rail: Categories, Count Badges, Exclude Non-A, Focus
               - Right Waterfall: Dual Modes (wmSectioned, wmTimeline),
                 Summary + Expandable Details, Diff/Quote badges.
               - Nested Hierarchy: ParentId, Depth (28px Indent per level)
               - Fixed 28px Numeric Color Badge for L0-L5 Levels
               - Right-side Detail Expander (▾ / ▸) & IsExpanded state
               - Right-side Property / Inspector Panel (Key-Value metadata & Links)
               - Fullscreen Modal Preview
               - Information Granularity: 6 levels (gCoarsest..gFinest)
               - Strongly-typed THbWaterfallCard for 100% crash-proof lifecycle
  ============================================================================ }

unit DeepBase.VCL.HB.Waterfall;

{$WARN IMPLICIT_STRING_CAST OFF}

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
  System.Generics.Collections,
  System.DateUtils,
  System.JSON,
  Vcl.Controls,
  Vcl.Graphics,
  Vcl.Forms,
  Vcl.ExtCtrls,
  Vcl.StdCtrls,
  DeepBase.HB.Core,
  DeepBase.HB.Touchpoint.Types,
  DeepBase.HB.Waterfall.Types,
  DeepBase.VCL.HB.Theme,
  DeepBase.VCL.HB.Controls,
  DeepBase.VCL.HB.Cards,
  DeepBase.VCL.HB.Dialogs;

type
  /// <summary>
  /// Event fired when user excludes or focuses a facet category.
  /// </summary>
  THbFacetFilterEvent = procedure(Sender: TObject; const ACategoryId: string; AIsExcluded: Boolean) of object;

  /// <summary>
  /// Event fired when a card is selected in the waterfall.
  /// </summary>
  THbCardSelectEvent = procedure(Sender: TObject; const ACardId: string) of object;

  /// <summary>
  /// Event fired when user clicks an external resource link on a card.
  /// </summary>
  THbCardLinkEvent = procedure(Sender: TObject; const ACardId: string;
    AKind: THbWaterfallLinkKind; const ATarget: string) of object;

  /// <summary>
  /// Internal high-performance flicker-free subpanel with clipped children.
  /// </summary>
  THbWaterfallSubPanel = class(THbCustomControl, IHbSurfaceProvider)
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    function GetSurfaceColor: TAlphaColor; override;
  end;

  /// <summary>
  /// Internal high-performance flicker-free scrollbox with clipped children.
  /// </summary>
  THbWaterfallScrollBox = class(TScrollBox, IHbSurfaceProvider)
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
    procedure PaintWindow(DC: HDC); override;
  public
    constructor Create(AOwner: TComponent); override;
    function GetSurfaceColor: TAlphaColor;
  end;

  /// <summary>
  /// Strongly-typed child card widget inside THbFacetWaterfall.
  /// </summary>
  THbWaterfallCard = class(THbCard)
  private
    FPnlBadge: THbWaterfallSubPanel;
    FLblBadge: TLabel;
    FBtnFold: THbButton;
    FBtnDetail: THbButton;
    FLblTitle: TLabel;
    FLblSummary: TLabel;
    FLblDetails: TLabel;
  public
    constructor Create(AOwner: TComponent); override;
    procedure UpdateCard(const AItem: THbWaterfallCardData; AMode: THbWaterfallMode;
      const ATokens: THbTokens; APPI: Integer; AIndex: Integer;
      AOnFold, AOnDetail: TNotifyEvent);
  end;

  /// <summary>
  /// THbFacetWaterfall: Modern Faceted Waterfall Container for VCL.
  /// </summary>
  THbFacetWaterfall = class(THbCustomControl, IHbSnapshotProvider, IHbSurfaceProvider)
  private
    FSurfaceId: string;
    FControlId: string;
    FRestoreNotice: string;
    FFacets: TList<THbFacetCategory>;
    FItems: TList<THbWaterfallCardData>;
    FMode: THbWaterfallMode;
    FFacetWidth: Integer;
    FInspectorWidth: Integer;
    FFocusedCategoryId: string;
    FSelectedCardId: string;
    FGranularity: THbGranularity;
    FOnFilterChanged: THbFacetFilterEvent;
    FOnCardSelected: THbCardSelectEvent;
    FOnLinkClick: THbCardLinkEvent;

    // UI layout sub-panels
    FPnlLeftRail: THbWaterfallSubPanel;
    FPnlCenterArea: THbWaterfallSubPanel;
    FPnlToolbar: THbWaterfallSubPanel;
    FScrollWaterfall: THbWaterfallScrollBox;
    FPnlRightInspector: THbWaterfallSubPanel;
    FBtnModeSec: THbButton;
    FBtnModeTime: THbButton;
    FLblStatus: TLabel;

    // Inspector controls
    FLblInspTitle: TLabel;
    FLblInspDepth: TLabel;
    FLblInspLink: TLabel;
    FBtnOpenLink: THbButton;
    FBtnFullscreen: THbButton;
    FMemoProperties: TMemo;

    procedure SetMode(Value: THbWaterfallMode);
    procedure SetFacetWidth(Value: Integer);
    procedure SetInspectorWidth(Value: Integer);
    procedure SetGranularity(Value: THbGranularity);
    procedure RebuildLeftRail;
    procedure RebuildWaterfall;
    procedure UpdateInspectorPanel;
    procedure OnFacetButtonClick(Sender: TObject);
    procedure OnModeSecClick(Sender: TObject);
    procedure OnModeTimeClick(Sender: TObject);
    procedure OnCardClick(Sender: TObject);
    procedure OnCardDetailToggleClick(Sender: TObject);
    procedure OnCardFoldToggleClick(Sender: TObject);
    procedure OnOpenLinkClick(Sender: TObject);
    procedure OnFullscreenClick(Sender: TObject);
    function MaxDepthForGranularity(AGranularity: THbGranularity): Integer;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
    procedure Paint; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function GetSurfaceColor: TAlphaColor; override;

    procedure AddFacet(const AId, ATitle: string; ACount: Integer = 0);
    procedure AddCard(const AId, ACatId, ACatTitle, ATitle, ASummary: string;
      const ADetails: string = ''; const AQuote: string = '';
      AState: THbWaterfallItemState = wisNormal; ABadgeTone: THbBadgeTone = btBrand;
      const AParentId: string = ''; ADepth: Integer = -1;
      ALinkKind: THbWaterfallLinkKind = wlkNone; const ALinkTarget: string = '';
      const AProperties: TArray<THbCardProperty> = nil);
    procedure Clear;
    procedure ClearCards;

    procedure ExcludeFacet(const ACategoryId: string; AExclude: Boolean = True);
    procedure FocusFacet(const ACategoryId: string);
    procedure ResetFilter;

    procedure ToggleCardCollapse(const ACardId: string);
    procedure SetCardCollapsed(const ACardId: string; ACollapsed: Boolean);
    procedure ToggleCardDetail(const ACardId: string);
    procedure SetCardDetailExpanded(const ACardId: string; AExpanded: Boolean);
    procedure SelectCard(const ACardId: string);
    procedure PreviewFullscreen(const ACardId: string);

    function FindCard(const ACardId: string; out ACard: THbWaterfallCardData): Boolean;
    function IsCardVisible(const ACard: THbWaterfallCardData): Boolean;
    function IsCategoryVisible(const ACategoryId: string): Boolean;
    function GetVisibleCardCount: Integer;

    // IHbSnapshotProvider
    function GetSurfaceId: string;
    function GetControlId: string;
    function CaptureSnapshot: string;
    procedure RestoreSnapshot(const APayload: string);

    property SurfaceId: string read FSurfaceId write FSurfaceId;
    property ControlId: string read FControlId write FControlId;
    property RestoreNotice: string read FRestoreNotice;
    property Facets: TList<THbFacetCategory> read FFacets;
    property Items: TList<THbWaterfallCardData> read FItems;
    property FocusedCategoryId: string read FFocusedCategoryId;
    property SelectedCardId: string read FSelectedCardId;
  published
    property Align;
    property Anchors;
    property FacetWidth: Integer read FFacetWidth write SetFacetWidth default 220;
    property InspectorWidth: Integer read FInspectorWidth write SetInspectorWidth default 260;
    property Mode: THbWaterfallMode read FMode write SetMode default wmSectioned;
    property Granularity: THbGranularity read FGranularity write SetGranularity default gMedium;
    property OnFilterChanged: THbFacetFilterEvent read FOnFilterChanged write FOnFilterChanged;
    property OnCardSelected: THbCardSelectEvent read FOnCardSelected write FOnCardSelected;
    property OnLinkClick: THbCardLinkEvent read FOnLinkClick write FOnLinkClick;
  end;

implementation

{ THbWaterfallSubPanel }

constructor THbWaterfallSubPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  // Parent THbFacetWaterfall is already DoubleBuffered; nested DB bitmaps
  // realloc on every resize and dominate Gate #5 Form.Update cost.
  DoubleBuffered := False;
  ControlStyle := [csAcceptsControls, csCaptureMouse, csOpaque];
end;

procedure THbWaterfallSubPanel.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.Style := Params.Style or WS_CLIPCHILDREN or WS_CLIPSIBLINGS;
  Params.WindowClass.Style := Params.WindowClass.Style and not (CS_HREDRAW or CS_VREDRAW);
end;

procedure THbWaterfallSubPanel.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  Message.Result := 1;
end;

procedure THbWaterfallSubPanel.Paint;
var
  DC: HDC;
begin
  DC := Canvas.Handle;
  SelectObject(DC, GetStockObject(DC_BRUSH));
  SetDCBrushColor(DC, ColorToRGB(AlphaColorToColor(THbTheme.Tokens.Surface)));
  Winapi.Windows.FillRect(DC, ClientRect, GetStockObject(DC_BRUSH));
end;

function THbWaterfallSubPanel.GetSurfaceColor: TAlphaColor;
begin
  Result := THbTheme.Tokens.Surface;
end;

{ THbWaterfallScrollBox }

constructor THbWaterfallScrollBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  // Nested double-buffer bitmaps realloc on resize; parent waterfall owns DB.
  DoubleBuffered := False;
  ControlStyle := ControlStyle + [csOpaque] - [csParentBackground];
  BorderStyle := bsNone;
end;

procedure THbWaterfallScrollBox.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.Style := Params.Style or WS_CLIPCHILDREN or WS_CLIPSIBLINGS;
  Params.WindowClass.Style := Params.WindowClass.Style and not (CS_HREDRAW or CS_VREDRAW);
end;

procedure THbWaterfallScrollBox.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  Message.Result := 1;
end;

procedure THbWaterfallScrollBox.PaintWindow(DC: HDC);
var
  R: TRect;
begin
  SelectObject(DC, GetStockObject(DC_BRUSH));
  SetDCBrushColor(DC, ColorToRGB(AlphaColorToColor(THbTheme.Tokens.Surface)));
  R := ClientRect;
  Winapi.Windows.FillRect(DC, R, GetStockObject(DC_BRUSH));
end;

function THbWaterfallScrollBox.GetSurfaceColor: TAlphaColor;
begin
  Result := THbTheme.Tokens.Surface;
end;

{ THbWaterfallCard }

constructor THbWaterfallCard.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  // Card base already DoubleBuffered; keep a single buffer layer under scroll host.
  DoubleBuffered := False;
  Align := alTop;
  AlignWithMargins := True;

  FPnlBadge := THbWaterfallSubPanel.Create(Self);
  FPnlBadge.Parent := Self;

  FLblBadge := TLabel.Create(FPnlBadge);
  FLblBadge.Parent := FPnlBadge;
  FLblBadge.Align := alClient;
  FLblBadge.Alignment := taCenter;
  FLblBadge.Layout := tlCenter;
  FLblBadge.Font.Style := [fsBold];
  FLblBadge.Transparent := True;

  FBtnFold := THbButton.Create(Self);
  FBtnFold.Parent := Self;
  FBtnFold.Kind := bkGhost;

  FBtnDetail := THbButton.Create(Self);
  FBtnDetail.Parent := Self;
  FBtnDetail.Align := alRight;
  FBtnDetail.Kind := bkGhost;
  FBtnDetail.AlignWithMargins := True;

  FLblTitle := TLabel.Create(Self);
  FLblTitle.Parent := Self;
  FLblTitle.Font.Style := [fsBold];

  FLblSummary := TLabel.Create(Self);
  FLblSummary.Parent := Self;

  FLblDetails := TLabel.Create(Self);
  FLblDetails.Parent := Self;
  FLblDetails.Font.Color := clGray;
end;

procedure THbWaterfallCard.UpdateCard(const AItem: THbWaterfallCardData;
  AMode: THbWaterfallMode; const ATokens: THbTokens; APPI: Integer; AIndex: Integer;
  AOnFold, AOnDetail: TNotifyEvent);
var
  DpiScale: Double;
  IndentPx, CardHeightPx: Integer;
  TitleStr, DetailTextStr: string;
begin
  DpiScale := APPI / 96.0;
  Tag := AIndex;

  // 1. Exact 28px Indentation per depth level
  IndentPx := AItem.Depth * Round(28 * DpiScale);

  // 2. Dynamic card height when DetailText is expanded
  if AItem.IsExpanded then
    CardHeightPx := Round(116 * DpiScale)
  else
    CardHeightPx := Round(68 * DpiScale);

  Height := CardHeightPx;
  Margins.SetBounds(Round(8 * DpiScale) + IndentPx,
                    Round(4 * DpiScale),
                    Round(8 * DpiScale),
                    Round(4 * DpiScale));

  // 3. Setup 28px numeric level badge
  FPnlBadge.Left := Round(6 * DpiScale);
  FPnlBadge.Top := Round(10 * DpiScale);
  FPnlBadge.Width := Round(28 * DpiScale);
  FPnlBadge.Height := Round(28 * DpiScale);
  FPnlBadge.Color := AlphaColorToColor(ATokens.GetLevelColor(AItem.Depth));
  FLblBadge.Caption := IntToStr(AItem.Depth);
  FLblBadge.Font.Color := clWhite;

  // 4. Setup fold button
  FBtnFold.Left := Round(38 * DpiScale);
  FBtnFold.Top := Round(12 * DpiScale);
  FBtnFold.Width := Round(24 * DpiScale);
  FBtnFold.Height := Round(24 * DpiScale);
  FBtnFold.Tag := AIndex;
  FBtnFold.OnClick := AOnFold;
  if AItem.HasChildren then
  begin
    FBtnFold.Visible := True;
    if AItem.Collapsed then
      FBtnFold.Caption := '▶'
    else
      FBtnFold.Caption := '▼';
  end
  else
    FBtnFold.Visible := False;

  // 5. Setup detail button
  FBtnDetail.Width := Round(36 * DpiScale);
  FBtnDetail.Margins.SetBounds(0, Round(6 * DpiScale), Round(6 * DpiScale), Round(6 * DpiScale));
  FBtnDetail.Tag := AIndex;
  FBtnDetail.OnClick := AOnDetail;
  if AItem.IsExpanded then
    FBtnDetail.Caption := '▴'
  else
    FBtnDetail.Caption := '▾';

  // 6. Title and Summary Text
  if AMode = wmTimeline then
  begin
    Kind := ckOutline;
    Radius := rsS;
    if AItem.TimestampStr <> '' then
      TitleStr := '⏱ [' + AItem.TimestampStr + '] ' + AItem.Title
    else
      TitleStr := '⏱ ' + AItem.Title;
  end
  else
  begin
    Kind := ckSurface;
    Radius := rsM;
    TitleStr := '[' + AItem.CategoryTitle + '] ' + AItem.Title;
  end;

  FLblTitle.Left := Round(68 * DpiScale);
  FLblTitle.Top := Round(10 * DpiScale);
  FLblTitle.Caption := TitleStr;

  FLblSummary.Left := Round(68 * DpiScale);
  FLblSummary.Top := Round(34 * DpiScale);
  FLblSummary.Caption := AItem.SummaryText;

  // 7. Expanded Details Area
  if AItem.IsExpanded then
  begin
    FLblDetails.Visible := True;
    FLblDetails.Left := Round(68 * DpiScale);
    FLblDetails.Top := Round(60 * DpiScale);
    FLblDetails.Width := Round(400 * DpiScale);
    DetailTextStr := '详情: ' + AItem.DetailText;
    if AItem.QuoteSource <> '' then
      DetailTextStr := DetailTextStr + ' (来源: ' + AItem.QuoteSource + ')';
    FLblDetails.Caption := DetailTextStr;
  end
  else
    FLblDetails.Visible := False;
end;

{ THbFacetWaterfall }

constructor THbFacetWaterfall.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 1024;
  Height := 580;
  FFacetWidth := 220;
  FInspectorWidth := 260;
  FMode := wmSectioned;
  FGranularity := gMedium;
  FFocusedCategoryId := '';
  FSelectedCardId := '';
  FSurfaceId := 'HbFacetWaterfall';
  FControlId := 'waterfall_main';
  FRestoreNotice := '';
  FFacets := TList<THbFacetCategory>.Create;
  FItems := TList<THbWaterfallCardData>.Create;

  DoubleBuffered := True;
  ControlStyle := ControlStyle + [csAcceptsControls, csOpaque] - [csParentBackground];

  // 1. Left Rail Panel
  FPnlLeftRail := THbWaterfallSubPanel.Create(Self);
  FPnlLeftRail.Parent := Self;
  FPnlLeftRail.Align := alLeft;
  FPnlLeftRail.Width := FFacetWidth;

  // 2. Center Viewport Area
  FPnlCenterArea := THbWaterfallSubPanel.Create(Self);
  FPnlCenterArea.Parent := Self;
  FPnlCenterArea.Align := alClient;

  // 3. Center Toolbar
  FPnlToolbar := THbWaterfallSubPanel.Create(FPnlCenterArea);
  FPnlToolbar.Parent := FPnlCenterArea;
  FPnlToolbar.Align := alTop;
  FPnlToolbar.Height := Round(42 * (CurrentPPI / 96.0));

  FLblStatus := TLabel.Create(FPnlToolbar);
  FLblStatus.Parent := FPnlToolbar;
  FLblStatus.AutoSize := False;
  FLblStatus.Left := Round(12 * (CurrentPPI / 96.0));
  FLblStatus.Top := Round(12 * (CurrentPPI / 96.0));
  FLblStatus.Width := Round(70 * (CurrentPPI / 96.0));
  FLblStatus.Height := Round(20 * (CurrentPPI / 96.0));
  FLblStatus.Caption := '瀑布信息流';
  FLblStatus.Transparent := True;

  FBtnModeTime := THbButton.Create(FPnlToolbar);
  FBtnModeTime.Parent := FPnlToolbar;
  FBtnModeTime.Align := alRight;
  FBtnModeTime.Width := Round(90 * (CurrentPPI / 96.0));
  FBtnModeTime.Caption := '时间轴流';
  FBtnModeTime.Kind := bkGhost;
  FBtnModeTime.OnClick := OnModeTimeClick;
  FBtnModeTime.Margins.SetBounds(Round(4 * (CurrentPPI / 96.0)), Round(4 * (CurrentPPI / 96.0)), Round(8 * (CurrentPPI / 96.0)), Round(4 * (CurrentPPI / 96.0)));
  FBtnModeTime.AlignWithMargins := True;

  FBtnModeSec := THbButton.Create(FPnlToolbar);
  FBtnModeSec.Parent := FPnlToolbar;
  FBtnModeSec.Align := alRight;
  FBtnModeSec.Width := Round(90 * (CurrentPPI / 96.0));
  FBtnModeSec.Caption := '分类分段';
  FBtnModeSec.Kind := bkPrimary;
  FBtnModeSec.OnClick := OnModeSecClick;
  FBtnModeSec.Margins.SetBounds(Round(4 * (CurrentPPI / 96.0)), Round(4 * (CurrentPPI / 96.0)), Round(4 * (CurrentPPI / 96.0)), Round(4 * (CurrentPPI / 96.0)));
  FBtnModeSec.AlignWithMargins := True;

  // 4. Scrollable Content Area
  FScrollWaterfall := THbWaterfallScrollBox.Create(FPnlCenterArea);
  FScrollWaterfall.Parent := FPnlCenterArea;
  FScrollWaterfall.Align := alClient;

  // 5. Right Inspector Panel
  FPnlRightInspector := THbWaterfallSubPanel.Create(Self);
  FPnlRightInspector.Parent := Self;
  FPnlRightInspector.Align := alRight;
  FPnlRightInspector.Width := 0; // Hidden initially
  FPnlRightInspector.Visible := False;

  FLblInspTitle := TLabel.Create(FPnlRightInspector);
  FLblInspTitle.Parent := FPnlRightInspector;
  FLblInspTitle.Left := Round(12 * (CurrentPPI / 96.0));
  FLblInspTitle.Top := Round(12 * (CurrentPPI / 96.0));
  FLblInspTitle.Font.Style := [fsBold];
  FLblInspTitle.Caption := '卡片属性检查器';
  FLblInspTitle.Transparent := True;

  FLblInspDepth := TLabel.Create(FPnlRightInspector);
  FLblInspDepth.Parent := FPnlRightInspector;
  FLblInspDepth.Left := Round(12 * (CurrentPPI / 96.0));
  FLblInspDepth.Top := Round(36 * (CurrentPPI / 96.0));
  FLblInspDepth.Caption := '层级: -';
  FLblInspDepth.Transparent := True;

  FLblInspLink := TLabel.Create(FPnlRightInspector);
  FLblInspLink.Parent := FPnlRightInspector;
  FLblInspLink.Left := Round(12 * (CurrentPPI / 96.0));
  FLblInspLink.Top := Round(56 * (CurrentPPI / 96.0));
  FLblInspLink.Caption := '资源链接: 无';
  FLblInspLink.Transparent := True;

  FBtnOpenLink := THbButton.Create(FPnlRightInspector);
  FBtnOpenLink.Parent := FPnlRightInspector;
  FBtnOpenLink.Left := Round(12 * (CurrentPPI / 96.0));
  FBtnOpenLink.Top := Round(80 * (CurrentPPI / 96.0));
  FBtnOpenLink.Width := Round(110 * (CurrentPPI / 96.0));
  FBtnOpenLink.Caption := '🔗 打开链接';
  FBtnOpenLink.Kind := bkGhost;
  FBtnOpenLink.OnClick := OnOpenLinkClick;
  FBtnOpenLink.Visible := False;

  FBtnFullscreen := THbButton.Create(FPnlRightInspector);
  FBtnFullscreen.Parent := FPnlRightInspector;
  FBtnFullscreen.Left := Round(130 * (CurrentPPI / 96.0));
  FBtnFullscreen.Top := Round(80 * (CurrentPPI / 96.0));
  FBtnFullscreen.Width := Round(110 * (CurrentPPI / 96.0));
  FBtnFullscreen.Caption := '⛶ 全屏预览';
  FBtnFullscreen.Kind := bkGhost;
  FBtnFullscreen.OnClick := OnFullscreenClick;

  FMemoProperties := TMemo.Create(FPnlRightInspector);
  FMemoProperties.Parent := FPnlRightInspector;
  FMemoProperties.Left := Round(12 * (CurrentPPI / 96.0));
  FMemoProperties.Top := Round(120 * (CurrentPPI / 96.0));
  FMemoProperties.Width := Round(236 * (CurrentPPI / 96.0));
  FMemoProperties.Height := Round(200 * (CurrentPPI / 96.0));
  FMemoProperties.ReadOnly := True;
  FMemoProperties.ScrollBars := ssVertical;

  // Initialize view
  RebuildLeftRail;
  RebuildWaterfall;
end;

destructor THbFacetWaterfall.Destroy;
begin
  FItems.Free;
  FFacets.Free;
  inherited;
end;

procedure THbFacetWaterfall.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.Style := Params.Style or WS_CLIPCHILDREN or WS_CLIPSIBLINGS;
  Params.WindowClass.Style := Params.WindowClass.Style and not (CS_HREDRAW or CS_VREDRAW);
end;

procedure THbFacetWaterfall.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  Message.Result := 1;
end;

procedure THbFacetWaterfall.Paint;
begin
  if (FPnlLeftRail = nil) or (FPnlCenterArea = nil) then
  begin
    Canvas.Brush.Color := AlphaColorToColor(THbTheme.Tokens.Surface);
    Canvas.FillRect(ClientRect);
  end;
end;

function THbFacetWaterfall.GetSurfaceColor: TAlphaColor;
begin
  Result := THbTheme.Tokens.Surface;
end;

procedure THbFacetWaterfall.Resize;
begin
  inherited;
  if Assigned(FPnlLeftRail) and (FPnlLeftRail.Width <> FFacetWidth) then
    FPnlLeftRail.Width := FFacetWidth;
end;

procedure THbFacetWaterfall.SetMode(Value: THbWaterfallMode);
begin
  if FMode <> Value then
  begin
    FMode := Value;
    if FMode = wmSectioned then
    begin
      FBtnModeSec.Kind := bkPrimary;
      FBtnModeTime.Kind := bkGhost;
    end
    else
    begin
      FBtnModeSec.Kind := bkGhost;
      FBtnModeTime.Kind := bkPrimary;
    end;
    RebuildWaterfall;
  end;
end;

procedure THbFacetWaterfall.SetFacetWidth(Value: Integer);
begin
  if FFacetWidth <> Value then
  begin
    FFacetWidth := Value;
    if Assigned(FPnlLeftRail) then
      FPnlLeftRail.Width := FFacetWidth;
  end;
end;

procedure THbFacetWaterfall.SetInspectorWidth(Value: Integer);
begin
  if FInspectorWidth <> Value then
  begin
    FInspectorWidth := Value;
    UpdateInspectorPanel;
  end;
end;

function THbFacetWaterfall.MaxDepthForGranularity(AGranularity: THbGranularity): Integer;
begin
  case AGranularity of
    gCoarsest: Result := 0;
    gCoarse:   Result := 1;
    gMedium:   Result := 2;
    gFine:     Result := 3;
    gFiner:    Result := 4;
    gFinest:   Result := 999;
  else
    Result := 2;
  end;
end;

procedure THbFacetWaterfall.SetGranularity(Value: THbGranularity);
begin
  if FGranularity <> Value then
  begin
    FGranularity := Value;
    RebuildWaterfall;
  end;
end;

procedure THbFacetWaterfall.AddFacet(const AId, ATitle: string; ACount: Integer);
var
  Facet: THbFacetCategory;
begin
  Facet.Id := AId;
  Facet.Title := ATitle;
  Facet.Count := ACount;
  Facet.IconSvg := '';
  Facet.IsExcluded := False;
  Facet.IsFocused := False;
  FFacets.Add(Facet);
  RebuildLeftRail;
end;

procedure THbFacetWaterfall.AddCard(const AId, ACatId, ACatTitle, ATitle, ASummary,
  ADetails, AQuote: string; AState: THbWaterfallItemState; ABadgeTone: THbBadgeTone;
  const AParentId: string; ADepth: Integer; ALinkKind: THbWaterfallLinkKind;
  const ALinkTarget: string; const AProperties: TArray<THbCardProperty>);
var
  Card: THbWaterfallCardData;
  ParentCard: THbWaterfallCardData;
  I: Integer;
  CalculatedDepth: Integer;
begin
  Card.Id := AId;
  Card.CategoryId := ACatId;
  Card.CategoryTitle := ACatTitle;
  Card.Title := ATitle;
  Card.SummaryText := ASummary;
  Card.DetailText := ADetails;
  Card.QuoteSource := AQuote;
  Card.TimestampStr := '';
  Card.State := AState;
  Card.BadgeTone := ABadgeTone;
  Card.IsExpanded := False;
  Card.ParentId := AParentId;
  Card.Collapsed := False;
  Card.HasChildren := False;
  Card.LinkKind := ALinkKind;
  Card.LinkTarget := ALinkTarget;
  SetLength(Card.Properties, Length(AProperties));
  for I := 0 to High(AProperties) do
    Card.Properties[I] := AProperties[I];
  Card.Tag := 0;

  // Resolve Depth
  if ADepth >= 0 then
    Card.Depth := ADepth
  else if AParentId <> '' then
  begin
    CalculatedDepth := 1;
    if FindCard(AParentId, ParentCard) then
      CalculatedDepth := ParentCard.Depth + 1;
    Card.Depth := CalculatedDepth;
  end
  else
    Card.Depth := 0;

  // Mark parent has children
  if AParentId <> '' then
  begin
    for I := 0 to FItems.Count - 1 do
    begin
      if FItems[I].Id = AParentId then
      begin
        ParentCard := FItems[I];
        ParentCard.HasChildren := True;
        FItems[I] := ParentCard;
        Break;
      end;
    end;
  end;

  FItems.Add(Card);
  RebuildWaterfall;
end;

function THbFacetWaterfall.FindCard(const ACardId: string; out ACard: THbWaterfallCardData): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to FItems.Count - 1 do
  begin
    if FItems[I].Id = ACardId then
    begin
      ACard := FItems[I];
      Exit(True);
    end;
  end;
end;

procedure THbFacetWaterfall.ToggleCardCollapse(const ACardId: string);
var
  I: Integer;
  Card: THbWaterfallCardData;
begin
  for I := 0 to FItems.Count - 1 do
  begin
    if FItems[I].Id = ACardId then
    begin
      Card := FItems[I];
      Card.Collapsed := not Card.Collapsed;
      FItems[I] := Card;
      RebuildWaterfall;
      Break;
    end;
  end;
end;

procedure THbFacetWaterfall.SetCardCollapsed(const ACardId: string; ACollapsed: Boolean);
var
  I: Integer;
  Card: THbWaterfallCardData;
begin
  for I := 0 to FItems.Count - 1 do
  begin
    if FItems[I].Id = ACardId then
    begin
      Card := FItems[I];
      if Card.Collapsed <> ACollapsed then
      begin
        Card.Collapsed := ACollapsed;
        FItems[I] := Card;
        RebuildWaterfall;
      end;
      Break;
    end;
  end;
end;

procedure THbFacetWaterfall.ToggleCardDetail(const ACardId: string);
var
  I: Integer;
  Card: THbWaterfallCardData;
begin
  for I := 0 to FItems.Count - 1 do
  begin
    if FItems[I].Id = ACardId then
    begin
      Card := FItems[I];
      Card.IsExpanded := not Card.IsExpanded;
      FItems[I] := Card;
      RebuildWaterfall;
      Break;
    end;
  end;
end;

procedure THbFacetWaterfall.SetCardDetailExpanded(const ACardId: string; AExpanded: Boolean);
var
  I: Integer;
  Card: THbWaterfallCardData;
begin
  for I := 0 to FItems.Count - 1 do
  begin
    if FItems[I].Id = ACardId then
    begin
      Card := FItems[I];
      if Card.IsExpanded <> AExpanded then
      begin
        Card.IsExpanded := AExpanded;
        FItems[I] := Card;
        RebuildWaterfall;
      end;
      Break;
    end;
  end;
end;

procedure THbFacetWaterfall.SelectCard(const ACardId: string);
begin
  FSelectedCardId := ACardId;
  UpdateInspectorPanel;
  if Assigned(FOnCardSelected) then
    FOnCardSelected(Self, ACardId);
end;

procedure THbFacetWaterfall.UpdateInspectorPanel;
var
  Card: THbWaterfallCardData;
  I: Integer;
begin
  if (FSelectedCardId <> '') and FindCard(FSelectedCardId, Card) and
     ((Card.LinkTarget <> '') or (Length(Card.Properties) > 0)) then
  begin
    FPnlRightInspector.Visible := True;
    FPnlRightInspector.Width := Round(FInspectorWidth * (CurrentPPI / 96.0));
    FLblInspTitle.Caption := Card.Title;
    FLblInspDepth.Caption := Format('层级: L%d (深度 %d)', [Card.Depth, Card.Depth]);

    if Card.LinkTarget <> '' then
    begin
      FLblInspLink.Caption := '资源: ' + Card.LinkTarget;
      FBtnOpenLink.Visible := True;
    end
    else
    begin
      FLblInspLink.Caption := '资源链接: 无';
      FBtnOpenLink.Visible := False;
    end;

    FMemoProperties.Lines.Clear;
    for I := 0 to High(Card.Properties) do
      FMemoProperties.Lines.Add(Format('%s: %s', [Card.Properties[I].Key, Card.Properties[I].Value]));
  end
  else
  begin
    FPnlRightInspector.Width := 0; // Collapsed when no link or props
    FPnlRightInspector.Visible := False;
  end;
end;

procedure THbFacetWaterfall.PreviewFullscreen(const ACardId: string);
var
  Card: THbWaterfallCardData;
  PreviewForm: TForm;
  TitleLbl: TLabel;
  DetailMemo: TMemo;
begin
  if not FindCard(ACardId, Card) then
    Exit;

  PreviewForm := TForm.CreateNew(nil);
  try
    PreviewForm.Caption := '全屏预览 - ' + Card.Title;
    PreviewForm.Width := 800;
    PreviewForm.Height := 600;
    PreviewForm.Position := poScreenCenter;

    TitleLbl := TLabel.Create(PreviewForm);
    TitleLbl.Parent := PreviewForm;
    TitleLbl.Left := 20;
    TitleLbl.Top := 20;
    TitleLbl.Font.Size := 14;
    TitleLbl.Font.Style := [fsBold];
    TitleLbl.Caption := Format('[L%d] %s (%s)', [Card.Depth, Card.Title, Card.CategoryTitle]);

    DetailMemo := TMemo.Create(PreviewForm);
    DetailMemo.Parent := PreviewForm;
    DetailMemo.Left := 20;
    DetailMemo.Top := 60;
    DetailMemo.Width := 740;
    DetailMemo.Height := 460;
    DetailMemo.ReadOnly := True;
    DetailMemo.ScrollBars := ssVertical;

    DetailMemo.Lines.Add('=== 摘要 ===');
    DetailMemo.Lines.Add(Card.SummaryText);
    DetailMemo.Lines.Add('');
    DetailMemo.Lines.Add('=== 详情内容 ===');
    if Card.DetailText <> '' then
      DetailMemo.Lines.Add(Card.DetailText)
    else
      DetailMemo.Lines.Add('(无额外详情)');
    DetailMemo.Lines.Add('');

    if Card.LinkTarget <> '' then
    begin
      DetailMemo.Lines.Add('=== 链接资源 ===');
      DetailMemo.Lines.Add(Card.LinkTarget);
      DetailMemo.Lines.Add('');
    end;

    var NativeCloseBtn := TButton.Create(PreviewForm);
    NativeCloseBtn.Parent := PreviewForm;
    NativeCloseBtn.Left := 660;
    NativeCloseBtn.Top := 530;
    NativeCloseBtn.Width := 100;
    NativeCloseBtn.Caption := '关闭';
    NativeCloseBtn.ModalResult := mrOk;

    PreviewForm.ShowModal;
  finally
    PreviewForm.Free;
  end;
end;

function THbFacetWaterfall.IsCardVisible(const ACard: THbWaterfallCardData): Boolean;
var
  CurParentId: string;
  ParentCard: THbWaterfallCardData;
  MaxDepth: Integer;
begin
  // 1. Check category filter
  if not IsCategoryVisible(ACard.CategoryId) then
    Exit(False);

  // 2. Check Granularity Max Visible Depth
  MaxDepth := MaxDepthForGranularity(FGranularity);
  if ACard.Depth > MaxDepth then
    Exit(False);

  // 3. Check Ancestor Collapsed status in parent chain
  CurParentId := ACard.ParentId;
  while CurParentId <> '' do
  begin
    if FindCard(CurParentId, ParentCard) then
    begin
      if ParentCard.Collapsed then
        Exit(False);
      CurParentId := ParentCard.ParentId;
    end
    else
      Break;
  end;

  Result := True;
end;

procedure THbFacetWaterfall.Clear;
begin
  FFacets.Clear;
  FItems.Clear;
  FFocusedCategoryId := '';
  FSelectedCardId := '';
  UpdateInspectorPanel;
  RebuildLeftRail;
  RebuildWaterfall;
end;

procedure THbFacetWaterfall.ClearCards;
begin
  FItems.Clear;
  FSelectedCardId := '';
  UpdateInspectorPanel;
  RebuildWaterfall;
end;

procedure THbFacetWaterfall.ExcludeFacet(const ACategoryId: string; AExclude: Boolean);
var
  I: Integer;
  F: THbFacetCategory;
begin
  for I := 0 to FFacets.Count - 1 do
  begin
    if FFacets[I].Id = ACategoryId then
    begin
      F := FFacets[I];
      F.IsExcluded := AExclude;
      FFacets[I] := F;
      Break;
    end;
  end;
  RebuildLeftRail;
  RebuildWaterfall;
  if Assigned(FOnFilterChanged) then
    FOnFilterChanged(Self, ACategoryId, AExclude);
end;

procedure THbFacetWaterfall.FocusFacet(const ACategoryId: string);
var
  I: Integer;
  F: THbFacetCategory;
begin
  if FFocusedCategoryId = ACategoryId then
    FFocusedCategoryId := ''
  else
    FFocusedCategoryId := ACategoryId;

  for I := 0 to FFacets.Count - 1 do
  begin
    F := FFacets[I];
    F.IsFocused := (F.Id = FFocusedCategoryId);
    FFacets[I] := F;
  end;
  RebuildLeftRail;
  RebuildWaterfall;
  if Assigned(FOnFilterChanged) then
    FOnFilterChanged(Self, ACategoryId, False);
end;

procedure THbFacetWaterfall.ResetFilter;
var
  I: Integer;
  F: THbFacetCategory;
begin
  FFocusedCategoryId := '';
  for I := 0 to FFacets.Count - 1 do
  begin
    F := FFacets[I];
    F.IsExcluded := False;
    F.IsFocused := False;
    FFacets[I] := F;
  end;
  RebuildLeftRail;
  RebuildWaterfall;
  if Assigned(FOnFilterChanged) then
    FOnFilterChanged(Self, '', False);
end;

function THbFacetWaterfall.IsCategoryVisible(const ACategoryId: string): Boolean;
var
  I: Integer;
begin
  Result := True;
  if (FFocusedCategoryId <> '') and (FFocusedCategoryId <> ACategoryId) then
    Exit(False);

  for I := 0 to FFacets.Count - 1 do
  begin
    if FFacets[I].Id = ACategoryId then
    begin
      if FFacets[I].IsExcluded then
        Exit(False);
      Break;
    end;
  end;
end;

function THbFacetWaterfall.GetVisibleCardCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FItems.Count - 1 do
  begin
    if IsCardVisible(FItems[I]) then
      Inc(Result);
  end;
end;

procedure THbFacetWaterfall.RebuildLeftRail;
var
  I: Integer;
  Btn: THbButton;
  Facet: THbFacetCategory;
begin
  if not Assigned(FPnlLeftRail) then
    Exit;

  FPnlLeftRail.LockDrawing;
  try
    while FPnlLeftRail.ControlCount > 0 do
      FPnlLeftRail.Controls[0].Free;

    for I := 0 to FFacets.Count - 1 do
    begin
      Facet := FFacets[I];
      Btn := THbButton.Create(FPnlLeftRail);
      Btn.Parent := FPnlLeftRail;
      Btn.Align := alTop;
      Btn.Height := Round(36 * (CurrentPPI / 96.0));
      Btn.Margins.SetBounds(Round(4 * (CurrentPPI / 96.0)), Round(2 * (CurrentPPI / 96.0)), Round(4 * (CurrentPPI / 96.0)), Round(2 * (CurrentPPI / 96.0)));
      Btn.AlignWithMargins := True;

      if Facet.IsFocused then
        Btn.Kind := bkPrimary
      else if Facet.IsExcluded then
        Btn.Kind := bkDanger
      else
        Btn.Kind := bkSoft;

      Btn.Caption := Format('%s (%d)', [Facet.Title, Facet.Count]);
      Btn.Tag := I;
      Btn.OnClick := OnFacetButtonClick;
    end;
  finally
    FPnlLeftRail.UnlockDrawing;
  end;
end;

procedure THbFacetWaterfall.OnFacetButtonClick(Sender: TObject);
var
  Btn: THbButton;
  Idx: Integer;
begin
  if Sender is THbButton then
  begin
    Btn := THbButton(Sender);
    Idx := Btn.Tag;
    if (Idx >= 0) and (Idx < FFacets.Count) then
      FocusFacet(FFacets[Idx].Id);
  end;
end;

procedure THbFacetWaterfall.OnCardClick(Sender: TObject);
var
  CardIdx: Integer;
begin
  if Sender is THbWaterfallCard then
  begin
    CardIdx := THbWaterfallCard(Sender).Tag;
    if (CardIdx >= 0) and (CardIdx < FItems.Count) then
      SelectCard(FItems[CardIdx].Id);
  end;
end;

procedure THbFacetWaterfall.OnCardFoldToggleClick(Sender: TObject);
var
  CardIdx: Integer;
begin
  if Sender is THbButton then
  begin
    CardIdx := THbButton(Sender).Tag;
    if (CardIdx >= 0) and (CardIdx < FItems.Count) then
      ToggleCardCollapse(FItems[CardIdx].Id);
  end;
end;

procedure THbFacetWaterfall.OnCardDetailToggleClick(Sender: TObject);
var
  CardIdx: Integer;
begin
  if Sender is THbButton then
  begin
    CardIdx := THbButton(Sender).Tag;
    if (CardIdx >= 0) and (CardIdx < FItems.Count) then
      ToggleCardDetail(FItems[CardIdx].Id);
  end;
end;

procedure THbFacetWaterfall.OnOpenLinkClick(Sender: TObject);
var
  Card: THbWaterfallCardData;
begin
  if (FSelectedCardId <> '') and FindCard(FSelectedCardId, Card) and (Card.LinkTarget <> '') then
  begin
    if Assigned(FOnLinkClick) then
      FOnLinkClick(Self, Card.Id, Card.LinkKind, Card.LinkTarget);
  end;
end;

procedure THbFacetWaterfall.OnFullscreenClick(Sender: TObject);
begin
  if FSelectedCardId <> '' then
    PreviewFullscreen(FSelectedCardId);
end;

procedure THbFacetWaterfall.RebuildWaterfall;
var
  I, VisIndex, VisCount: Integer;
  Card: THbWaterfallCard;
  Item: THbWaterfallCardData;
  Tokens: THbTokens;
begin
  Tokens := THbTheme.Tokens;
  VisCount := GetVisibleCardCount;
  if FFocusedCategoryId <> '' then
    FLblStatus.Caption := '正向聚焦: ' + FFocusedCategoryId + ' (共 ' + IntToStr(VisCount) + ' 项)'
  else
    FLblStatus.Caption := '瀑布信息流 (共 ' + IntToStr(VisCount) + ' 项有效)';

  if not Assigned(FScrollWaterfall) then
    Exit;

  FScrollWaterfall.LockDrawing;
  try
    VisIndex := 0;
    for I := 0 to FItems.Count - 1 do
    begin
      Item := FItems[I];
      if not IsCardVisible(Item) then
        Continue;

      if VisIndex < FScrollWaterfall.ControlCount then
      begin
        Card := THbWaterfallCard(FScrollWaterfall.Controls[VisIndex]);
        Card.Visible := True;
      end
      else
      begin
        Card := THbWaterfallCard.Create(FScrollWaterfall);
        Card.Parent := FScrollWaterfall;
        Card.OnClick := OnCardClick;
      end;

      Card.UpdateCard(Item, FMode, Tokens, CurrentPPI, I,
        OnCardFoldToggleClick, OnCardDetailToggleClick);

      Inc(VisIndex);
    end;

    // Remove remaining extra controls
    for var J := FScrollWaterfall.ControlCount - 1 downto VisIndex do
      FScrollWaterfall.Controls[J].Free;
  finally
    FScrollWaterfall.UnlockDrawing;
  end;
end;

procedure THbFacetWaterfall.OnModeSecClick(Sender: TObject);
begin
  SetMode(wmSectioned);
end;

procedure THbFacetWaterfall.OnModeTimeClick(Sender: TObject);
begin
  SetMode(wmTimeline);
end;

function THbFacetWaterfall.GetSurfaceId: string;
begin
  if FSurfaceId <> '' then
    Result := FSurfaceId
  else
    Result := 'HbFacetWaterfall';
end;

function THbFacetWaterfall.GetControlId: string;
begin
  if FControlId <> '' then
    Result := FControlId
  else if Name <> '' then
    Result := Name
  else
    Result := 'waterfall_main';
end;

function THbFacetWaterfall.CaptureSnapshot: string;
var
  Obj: TJSONObject;
  ExArr, ColArr, ExpArr: TJSONArray;
  I: Integer;
begin
  Obj := TJSONObject.Create;
  try
    Obj.AddPair('surface_id', GetSurfaceId);
    Obj.AddPair('control_id', GetControlId);
    Obj.AddPair('mode', TJSONNumber.Create(Ord(FMode)));
    Obj.AddPair('granularity', TJSONNumber.Create(Ord(FGranularity)));
    Obj.AddPair('focused_category', FFocusedCategoryId);
    Obj.AddPair('selected_card', FSelectedCardId);
    Obj.AddPair('timestamp_utc', TJSONNumber.Create(DateTimeToUnix(TTimeZone.Local.ToUniversalTime(Now), False) * 1000));

    ExArr := TJSONArray.Create;
    for I := 0 to FFacets.Count - 1 do
      if FFacets[I].IsExcluded then
        ExArr.Add(FFacets[I].Id);
    Obj.AddPair('excluded_facets', ExArr);

    ColArr := TJSONArray.Create;
    ExpArr := TJSONArray.Create;
    for I := 0 to FItems.Count - 1 do
    begin
      if FItems[I].Collapsed then
        ColArr.Add(FItems[I].Id);
      if FItems[I].IsExpanded then
        ExpArr.Add(FItems[I].Id);
    end;
    Obj.AddPair('collapsed_cards', ColArr);
    Obj.AddPair('expanded_cards', ExpArr);

    Result := Obj.ToJSON;
  finally
    Obj.Free;
  end;
end;

procedure THbFacetWaterfall.RestoreSnapshot(const APayload: string);
var
  Val: TJSONValue;
  Obj: TJSONObject;
  ExArr, ColArr, ExpArr: TJSONArray;
  I, J: Integer;
  Cat: THbFacetCategory;
  Item: THbWaterfallCardData;
begin
  FRestoreNotice := '';
  if Trim(APayload) = '' then
    Exit;

  Val := TJSONObject.ParseJSONValue(APayload);
  if Val = nil then
    Exit;

  try
    if Val is TJSONObject then
    begin
      Obj := TJSONObject(Val);
      if Obj.Values['mode'] is TJSONNumber then
        FMode := THbWaterfallMode(TJSONNumber(Obj.Values['mode']).AsInt);
      if Obj.Values['granularity'] is TJSONNumber then
        FGranularity := THbGranularity(TJSONNumber(Obj.Values['granularity']).AsInt);
      if Obj.Values['focused_category'] <> nil then
        FFocusedCategoryId := Obj.Values['focused_category'].Value;
      if Obj.Values['selected_card'] <> nil then
        FSelectedCardId := Obj.Values['selected_card'].Value;

      // Excluded facets
      if Obj.Values['excluded_facets'] is TJSONArray then
      begin
        ExArr := TJSONArray(Obj.Values['excluded_facets']);
        for I := 0 to FFacets.Count - 1 do
        begin
          Cat := FFacets[I];
          Cat.IsExcluded := False;
          for J := 0 to ExArr.Count - 1 do
          begin
            if ExArr.Items[J].Value = Cat.Id then
            begin
              Cat.IsExcluded := True;
              Break;
            end;
          end;
          FFacets[I] := Cat;
        end;
      end;

      // Collapsed and expanded cards
      ColArr := nil;
      ExpArr := nil;
      if Obj.Values['collapsed_cards'] is TJSONArray then
        ColArr := TJSONArray(Obj.Values['collapsed_cards']);
      if Obj.Values['expanded_cards'] is TJSONArray then
        ExpArr := TJSONArray(Obj.Values['expanded_cards']);

      for I := 0 to FItems.Count - 1 do
      begin
        Item := FItems[I];
        if Assigned(ColArr) then
        begin
          Item.Collapsed := False;
          for J := 0 to ColArr.Count - 1 do
            if ColArr.Items[J].Value = Item.Id then
            begin
              Item.Collapsed := True;
              Break;
            end;
        end;
        if Assigned(ExpArr) then
        begin
          Item.IsExpanded := False;
          for J := 0 to ExpArr.Count - 1 do
            if ExpArr.Items[J].Value = Item.Id then
            begin
              Item.IsExpanded := True;
              Break;
            end;
        end;
        FItems[I] := Item;
      end;

      FRestoreNotice := '已为您恢复上次推演进度';
      RebuildLeftRail;
      RebuildWaterfall;
      UpdateInspectorPanel;
    end;
  finally
    Val.Free;
  end;
end;

end.
