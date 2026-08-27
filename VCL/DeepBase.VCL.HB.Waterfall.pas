{ ============================================================================
  DeepBase.VCL.HB.Waterfall - Modern Token-Driven Faceted Waterfall Component

  Version: 1.0 (Delphi 13.1 on Win64)
  Description: THbFacetWaterfall:
               - Left Facet Rail: Categories, Count Badges, Exclude Non-A, Focus
               - Right Waterfall: Dual Modes (wmSectioned, wmTimeline),
                 Summary + Expandable Details, Diff/Quote badges.
  ============================================================================ }

unit DeepBase.VCL.HB.Waterfall;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
  System.Generics.Collections,
  Vcl.Controls,
  Vcl.Graphics,
  Vcl.Forms,
  Vcl.ExtCtrls,
  Vcl.StdCtrls,
  DeepBase.HB.Core,
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
  /// THbFacetWaterfall: Modern Faceted Waterfall Container for VCL.
  /// </summary>
  THbFacetWaterfall = class(TCustomControl)
  private
    FFacets: TList<THbFacetCategory>;
    FItems: TList<THbWaterfallCardData>;
    FMode: THbWaterfallMode;
    FFacetWidth: Integer;
    FFocusedCategoryId: string;
    FOnFilterChanged: THbFacetFilterEvent;
    
    // UI layout sub-panels
    FPnlLeftRail: TPanel;
    FPnlRightContainer: TPanel;
    FPnlToolbar: TPanel;
    FScrollWaterfall: TScrollBox;
    FBtnModeSec: THbButton;
    FBtnModeTime: THbButton;
    FLblStatus: TLabel;

    procedure SetMode(Value: THbWaterfallMode);
    procedure SetFacetWidth(Value: Integer);
    procedure RebuildLeftRail;
    procedure RebuildWaterfall;
    procedure OnFacetButtonClick(Sender: TObject);
    procedure OnModeSecClick(Sender: TObject);
    procedure OnModeTimeClick(Sender: TObject);
  protected
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure AddFacet(const AId, ATitle: string; ACount: Integer = 0);
    procedure AddCard(const AId, ACatId, ACatTitle, ATitle, ASummary: string;
      const ADetails: string = ''; const AQuote: string = '';
      AState: THbWaterfallItemState = wisNormal; ABadgeTone: THbBadgeTone = btBrand);
    procedure Clear;
    procedure ClearCards;
    
    procedure ExcludeFacet(const ACategoryId: string; AExclude: Boolean = True);
    procedure FocusFacet(const ACategoryId: string);
    procedure ResetFilter;

    function IsCategoryVisible(const ACategoryId: string): Boolean;
    function GetVisibleCardCount: Integer;

    property Facets: TList<THbFacetCategory> read FFacets;
    property Items: TList<THbWaterfallCardData> read FItems;
    property FocusedCategoryId: string read FFocusedCategoryId;
  published
    property Align;
    property Anchors;
    property FacetWidth: Integer read FFacetWidth write SetFacetWidth default 220;
    property Mode: THbWaterfallMode read FMode write SetMode default wmSectioned;
    property OnFilterChanged: THbFacetFilterEvent read FOnFilterChanged write FOnFilterChanged;
  end;

implementation

{ THbFacetWaterfall }

constructor THbFacetWaterfall.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 800;
  Height := 500;
  FFacetWidth := 220;
  FMode := wmSectioned;
  FFocusedCategoryId := '';
  FFacets := TList<THbFacetCategory>.Create;
  FItems := TList<THbWaterfallCardData>.Create;

  DoubleBuffered := True;

  // 1. Left Rail Panel
  FPnlLeftRail := TPanel.Create(Self);
  FPnlLeftRail.Parent := Self;
  FPnlLeftRail.Align := alLeft;
  FPnlLeftRail.Width := FFacetWidth;
  FPnlLeftRail.BevelOuter := bvNone;
  FPnlLeftRail.ParentBackground := False;

  // 2. Right Viewport Container
  FPnlRightContainer := TPanel.Create(Self);
  FPnlRightContainer.Parent := Self;
  FPnlRightContainer.Align := alClient;
  FPnlRightContainer.BevelOuter := bvNone;
  FPnlRightContainer.ParentBackground := False;

  // 3. Right Toolbar
  FPnlToolbar := TPanel.Create(FPnlRightContainer);
  FPnlToolbar.Parent := FPnlRightContainer;
  FPnlToolbar.Align := alTop;
  FPnlToolbar.Height := 42;
  FPnlToolbar.BevelOuter := bvNone;

  FLblStatus := TLabel.Create(FPnlToolbar);
  FLblStatus.Parent := FPnlToolbar;
  FLblStatus.Left := 12;
  FLblStatus.Top := 12;
  FLblStatus.Caption := '全部信息流 (0 项)';
  FLblStatus.Font.Style := [fsBold];

  FBtnModeTime := THbButton.Create(FPnlToolbar);
  FBtnModeTime.Parent := FPnlToolbar;
  FBtnModeTime.Align := alRight;
  FBtnModeTime.Width := 110;
  FBtnModeTime.Caption := '时间线模式';
  FBtnModeTime.Kind := bkSoft;
  FBtnModeTime.OnClick := OnModeTimeClick;

  FBtnModeSec := THbButton.Create(FPnlToolbar);
  FBtnModeSec.Parent := FPnlToolbar;
  FBtnModeSec.Align := alRight;
  FBtnModeSec.Width := 120;
  FBtnModeSec.Caption := '分段聚合模式';
  FBtnModeSec.Kind := bkPrimary;
  FBtnModeSec.OnClick := OnModeSecClick;

  // 4. Right Waterfall Scrollbox
  FScrollWaterfall := TScrollBox.Create(FPnlRightContainer);
  FScrollWaterfall.Parent := FPnlRightContainer;
  FScrollWaterfall.Align := alClient;
end;

destructor THbFacetWaterfall.Destroy;
begin
  FFacets.Free;
  FItems.Free;
  inherited;
end;

procedure THbFacetWaterfall.Resize;
begin
  inherited;
  if Assigned(FPnlLeftRail) then
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
      FBtnModeTime.Kind := bkSoft;
    end
    else
    begin
      FBtnModeSec.Kind := bkSoft;
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

procedure THbFacetWaterfall.AddFacet(const AId, ATitle: string; ACount: Integer);
var
  F: THbFacetCategory;
begin
  F.Id := AId;
  F.Title := ATitle;
  F.Count := ACount;
  F.IsExcluded := False;
  F.IsFocused := False;
  FFacets.Add(F);
  RebuildLeftRail;
end;

procedure THbFacetWaterfall.AddCard(const AId, ACatId, ACatTitle, ATitle, ASummary, ADetails, AQuote: string;
  AState: THbWaterfallItemState; ABadgeTone: THbBadgeTone);
var
  C: THbWaterfallCardData;
begin
  C.Id := AId;
  C.CategoryId := ACatId;
  C.CategoryTitle := ACatTitle;
  C.Title := ATitle;
  C.SummaryText := ASummary;
  C.DetailText := ADetails;
  C.QuoteSource := AQuote;
  C.TimestampStr := FormatDateTime('hh:nn:ss', Now);
  C.State := AState;
  C.BadgeTone := ABadgeTone;
  C.IsExpanded := False;
  C.Tag := 0;
  FItems.Add(C);
  RebuildWaterfall;
end;

procedure THbFacetWaterfall.Clear;
begin
  FFacets.Clear;
  FItems.Clear;
  FFocusedCategoryId := '';
  RebuildLeftRail;
  RebuildWaterfall;
end;

procedure THbFacetWaterfall.ClearCards;
begin
  FItems.Clear;
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
    if IsCategoryVisible(FItems[I].CategoryId) then
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
      Btn.Caption := Format('%s (%d)', [Facet.Title, Facet.Count]);
      Btn.Tag := I;
      Btn.OnClick := OnFacetButtonClick;
      if Facet.Id = FFocusedCategoryId then
        Btn.Kind := bkPrimary
      else if Facet.IsExcluded then
        Btn.Kind := bkGhost
      else
        Btn.Kind := bkSoft;
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
    begin
      if FFocusedCategoryId = FFacets[Idx].Id then
        FFocusedCategoryId := ''
      else
        FFocusedCategoryId := FFacets[Idx].Id;
      RebuildLeftRail;
      RebuildWaterfall;
      if Assigned(FOnFilterChanged) then
        FOnFilterChanged(Self, FFocusedCategoryId, False);
    end;
  end;
end;

procedure THbFacetWaterfall.RebuildWaterfall;
var
  I, VisCount: Integer;
  Card: THbCard;
  LblTitle, LblSummary: TLabel;
  Item: THbWaterfallCardData;
begin
  VisCount := GetVisibleCardCount;
  if FFocusedCategoryId <> '' then
    FLblStatus.Caption := '正向聚焦: ' + FFocusedCategoryId + ' (共 ' + IntToStr(VisCount) + ' 项)'
  else
    FLblStatus.Caption := '瀑布信息流 (共 ' + IntToStr(VisCount) + ' 项有效)';

  if not Assigned(FScrollWaterfall) then
    Exit;

  FScrollWaterfall.LockDrawing;
  try
    while FScrollWaterfall.ControlCount > 0 do
      FScrollWaterfall.Controls[0].Free;

    for I := 0 to FItems.Count - 1 do
    begin
      Item := FItems[I];
      if not IsCategoryVisible(Item.CategoryId) then
        Continue;

      Card := THbCard.Create(FScrollWaterfall);
      Card.Parent := FScrollWaterfall;
      Card.Align := alTop;
      Card.Height := Round(68 * (CurrentPPI / 96.0));
      Card.Margins.SetBounds(Round(8 * (CurrentPPI / 96.0)), Round(4 * (CurrentPPI / 96.0)), Round(8 * (CurrentPPI / 96.0)), Round(4 * (CurrentPPI / 96.0)));
      Card.AlignWithMargins := True;

      if FMode = wmTimeline then
      begin
        Card.Kind := ckOutline;
        Card.Radius := rsS;
      end
      else
      begin
        Card.Kind := ckSurface;
        Card.Radius := rsM;
      end;

      LblTitle := TLabel.Create(Card);
      LblTitle.Parent := Card;
      LblTitle.Left := Round(16 * (CurrentPPI / 96.0));
      LblTitle.Top := Round(10 * (CurrentPPI / 96.0));
      LblTitle.Font.Style := [fsBold];
      if FMode = wmTimeline then
        LblTitle.Caption := '⏱ ' + Item.Title
      else
        LblTitle.Caption := '[' + Item.CategoryTitle + '] ' + Item.Title;

      LblSummary := TLabel.Create(Card);
      LblSummary.Parent := Card;
      LblSummary.Left := Round(16 * (CurrentPPI / 96.0));
      LblSummary.Top := Round(34 * (CurrentPPI / 96.0));
      LblSummary.Caption := Item.SummaryText;
    end;
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

end.
