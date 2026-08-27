{ ============================================================================
  DeepBase.FMX.HB.Waterfall - Faceted Waterfall Component for FMX

  Version: 1.0 (Delphi 13.1 on Win64 / Cross-Platform)
  Description: THbFmxFacetWaterfall for FMX.
  ============================================================================ }

unit DeepBase.FMX.HB.Waterfall;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  DeepBase.HB.Core,
  DeepBase.HB.Waterfall.Types,
  DeepBase.FMX.HB.Theme;

type
  /// <summary>
  /// THbFmxFacetWaterfall: Modern Faceted Waterfall Container for FMX.
  /// </summary>
  THbFmxFacetWaterfall = class(TControl)
  private
    FFacets: TList<THbFacetCategory>;
    FItems: TList<THbWaterfallCardData>;
    FMode: THbWaterfallMode;
    FFocusedCategoryId: string;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure AddFacet(const AId, ATitle: string; ACount: Integer = 0);
    procedure AddCard(const AId, ACatId, ACatTitle, ATitle, ASummary: string);
    procedure ExcludeFacet(const ACategoryId: string; AExclude: Boolean = True);
    procedure FocusFacet(const ACategoryId: string);
    procedure ResetFilter;

    function IsCategoryVisible(const ACategoryId: string): Boolean;
    function GetVisibleCardCount: Integer;

    property Facets: TList<THbFacetCategory> read FFacets;
    property Items: TList<THbWaterfallCardData> read FItems;
  published
    property Align;
    property Mode: THbWaterfallMode read FMode write FMode default wmSectioned;
  end;

implementation

{ THbFmxFacetWaterfall }

constructor THbFmxFacetWaterfall.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 700;
  Height := 400;
  FMode := wmSectioned;
  FFacets := TList<THbFacetCategory>.Create;
  FItems := TList<THbWaterfallCardData>.Create;
end;

destructor THbFmxFacetWaterfall.Destroy;
begin
  FFacets.Free;
  FItems.Free;
  inherited;
end;

procedure THbFmxFacetWaterfall.AddFacet(const AId, ATitle: string; ACount: Integer);
var
  F: THbFacetCategory;
begin
  F.Id := AId;
  F.Title := ATitle;
  F.Count := ACount;
  F.IsExcluded := False;
  F.IsFocused := False;
  FFacets.Add(F);
end;

procedure THbFmxFacetWaterfall.AddCard(const AId, ACatId, ACatTitle, ATitle, ASummary: string);
var
  C: THbWaterfallCardData;
begin
  C.Id := AId;
  C.CategoryId := ACatId;
  C.CategoryTitle := ACatTitle;
  C.Title := ATitle;
  C.SummaryText := ASummary;
  C.DetailText := '';
  C.QuoteSource := '';
  C.TimestampStr := FormatDateTime('hh:nn:ss', Now);
  C.State := wisNormal;
  C.BadgeTone := btBrand;
  C.IsExpanded := False;
  C.Tag := 0;
  FItems.Add(C);
end;

procedure THbFmxFacetWaterfall.ExcludeFacet(const ACategoryId: string; AExclude: Boolean);
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
end;

procedure THbFmxFacetWaterfall.FocusFacet(const ACategoryId: string);
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
end;

procedure THbFmxFacetWaterfall.ResetFilter;
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
end;

function THbFmxFacetWaterfall.IsCategoryVisible(const ACategoryId: string): Boolean;
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

function THbFmxFacetWaterfall.GetVisibleCardCount: Integer;
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

end.
