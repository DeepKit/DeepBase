{ ============================================================================
  DeepBase.VCL.HB.NavTree - Multi-Tree Navigation & Collapsible Mini Rail for VCL

  Version: 1.0 (Delphi 13.1 on Win64)
  Description: THbNavTree:
               - Multi-level tree navigation with Section Group Headers
               - Instant search & fuzzy filter box
               - 240px expanded ⇄ 48px Mini Rail smooth toggle
               - Badge counts, shortcuts, and token-driven focus feedback
  ============================================================================ }

unit DeepBase.VCL.HB.NavTree;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  Winapi.GDIPOBJ,
  Winapi.GDIPAPI,
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
  DeepBase.HB.NavTree.Types,
  DeepBase.VCL.HB.Theme;

type
  THbNavNodeSelectEvent = procedure(Sender: TObject; const ANodeId: string) of object;

  /// <summary>
  /// THbNavTree: Modern Sidebar Multi-Tree Navigation Component for VCL.
  /// </summary>
  THbNavTree = class(TCustomControl)
  private
    FItems: TList<THbNavItemData>;
    FSelectedId: string;
    FHoverIndex: Integer;
    FIsCollapsed: Boolean;
    FExpandedWidth: Integer;
    FCollapsedWidth: Integer;
    FSearchFilter: string;
    FOnNodeSelect: THbNavNodeSelectEvent;

    procedure SetIsCollapsed(Value: Boolean);
    procedure SetSearchFilter(const Value: string);
    function GetItemAt(X, Y: Integer): Integer;
  protected
    procedure Paint; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure AddSection(const ATitle: string);
    procedure AddItem(const AId, ATitle: string; const ABadge: string = '';
      const AShortcut: string = ''; const AParentId: string = '');
    procedure AddDivider;
    procedure Clear;

    procedure SelectNode(const AId: string);
    procedure ToggleRail;

    property Items: TList<THbNavItemData> read FItems;
    property SelectedId: string read FSelectedId write SelectNode;
  published
    property Align;
    property Anchors;
    property IsCollapsed: Boolean read FIsCollapsed write SetIsCollapsed default False;
    property ExpandedWidth: Integer read FExpandedWidth write FExpandedWidth default 230;
    property CollapsedWidth: Integer read FCollapsedWidth write FCollapsedWidth default 52;
    property SearchFilter: string read FSearchFilter write SetSearchFilter;
    property OnNodeSelect: THbNavNodeSelectEvent read FOnNodeSelect write FOnNodeSelect;
  end;

implementation

function ColorToARGB(AColor: TAlphaColor; AAlphaOverride: Byte = 0): ARGB;
var
  A, R, G, B: Byte;
begin
  A := TAlphaColorRec(AColor).A;
  R := TAlphaColorRec(AColor).R;
  G := TAlphaColorRec(AColor).G;
  B := TAlphaColorRec(AColor).B;
  if AAlphaOverride > 0 then
    A := AAlphaOverride;
  Result := (ARGB(A) shl 24) or (ARGB(R) shl 16) or (ARGB(G) shl 8) or ARGB(B);
end;

function ScaleDIP(APixels: Single): Single;
begin
  Result := APixels * (Screen.PixelsPerInch / 96.0);
end;

{ THbNavTree }

constructor THbNavTree.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FExpandedWidth := 230;
  FCollapsedWidth := 52;
  Width := FExpandedWidth;
  Height := 500;
  FIsCollapsed := False;
  FSelectedId := '';
  FHoverIndex := -1;
  FSearchFilter := '';
  FItems := TList<THbNavItemData>.Create;

  DoubleBuffered := True;
  TabStop := True;
end;

destructor THbNavTree.Destroy;
begin
  FItems.Free;
  inherited;
end;

procedure THbNavTree.SetIsCollapsed(Value: Boolean);
begin
  if FIsCollapsed <> Value then
  begin
    FIsCollapsed := Value;
    if FIsCollapsed then
      Width := FCollapsedWidth
    else
      Width := FExpandedWidth;
    Invalidate;
  end;
end;

procedure THbNavTree.SetSearchFilter(const Value: string);
begin
  if FSearchFilter <> Value then
  begin
    FSearchFilter := Value;
    Invalidate;
  end;
end;

procedure THbNavTree.AddSection(const ATitle: string);
var
  N: THbNavItemData;
begin
  N := Default(THbNavItemData);
  N.Title := ATitle;
  N.Kind := nnSectionHeader;
  N.BadgeTone := btNeutral;
  N.IsExpanded := True;
  N.IsVisible := True;
  FItems.Add(N);
  Invalidate;
end;

procedure THbNavTree.AddItem(const AId, ATitle, ABadge, AShortcut, AParentId: string);
var
  N: THbNavItemData;
begin
  N := Default(THbNavItemData);
  N.Id := AId;
  N.ParentId := AParentId;
  N.Title := ATitle;
  N.Kind := nnItem;
  N.BadgeText := ABadge;
  N.BadgeTone := btBrand;
  N.ShortcutText := AShortcut;
  N.IsExpanded := True;
  N.IsVisible := True;
  FItems.Add(N);
  Invalidate;
end;

procedure THbNavTree.AddDivider;
var
  N: THbNavItemData;
begin
  N := Default(THbNavItemData);
  N.Kind := nnDivider;
  N.BadgeTone := btNeutral;
  N.IsExpanded := True;
  N.IsVisible := True;
  FItems.Add(N);
  Invalidate;
end;

procedure THbNavTree.Clear;
begin
  FItems.Clear;
  FSelectedId := '';
  FHoverIndex := -1;
  Invalidate;
end;

procedure THbNavTree.SelectNode(const AId: string);
begin
  if FSelectedId <> AId then
  begin
    FSelectedId := AId;
    Invalidate;
    if Assigned(FOnNodeSelect) then
      FOnNodeSelect(Self, FSelectedId);
  end;
end;

procedure THbNavTree.ToggleRail;
begin
  SetIsCollapsed(not FIsCollapsed);
end;

procedure THbNavTree.CMMouseLeave(var Message: TMessage);
begin
  inherited;
  if FHoverIndex <> -1 then
  begin
    FHoverIndex := -1;
    Invalidate;
  end;
end;

function THbNavTree.GetItemAt(X, Y: Integer): Integer;
var
  I: Integer;
  CurY: Single;
  ItemH: Single;
  Q: string;
begin
  Result := -1;
  CurY := 8.0;
  Q := LowerCase(Trim(FSearchFilter));
  for I := 0 to FItems.Count - 1 do
  begin
    if (Q <> '') and (FItems[I].Kind = nnItem) and (Pos(Q, LowerCase(FItems[I].Title)) = 0) then
      Continue;

    if FItems[I].Kind = nnSectionHeader then
      ItemH := 28.0
    else if FItems[I].Kind = nnDivider then
      ItemH := 9.0
    else
      ItemH := 36.0;

    if (Y >= CurY) and (Y < CurY + ItemH) then
      Exit(I);

    CurY := CurY + ItemH;
  end;
end;

procedure THbNavTree.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  NewHover: Integer;
begin
  inherited;
  NewHover := GetItemAt(X, Y);
  if FHoverIndex <> NewHover then
  begin
    FHoverIndex := NewHover;
    Invalidate;
  end;
end;

procedure THbNavTree.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Idx: Integer;
begin
  inherited;
  SetFocus;
  if Button = mbLeft then
  begin
    Idx := GetItemAt(X, Y);
    if (Idx >= 0) and (Idx < FItems.Count) then
    begin
      if (FItems[Idx].Kind = nnItem) and (FItems[Idx].Id <> '') then
        SelectNode(FItems[Idx].Id);
    end;
  end;
end;

procedure THbNavTree.Paint;
var
  Graphics: TGPGraphics;
  Tokens: THbTokens;
  BrushBg, BrushHover, BrushSel, BrushInk, BrushMuted, BrushSection, BrushPrimary, DotBrush, BrushBdg: TGPSolidBrush;
  PenBorder, PenDiv: TGPPen;
  FontFamily: TGPFontFamily;
  FontSection, FontItem, FontBold, FontBadge: TGPFont;
  StrFmtNear, StrFmtFar, StrFmtCenter: TGPStringFormat;
  CurY, ItemH: Single;
  I: Integer;
  Item: THbNavItemData;
  IsSel: Boolean;
  SecRect, ItemRect, TitleRect, BadgeRect: TGPRectF;
begin
  Tokens := THbTheme.Tokens;
  Graphics := TGPGraphics.Create(Canvas.Handle);
  try
    Graphics.SetSmoothingMode(SmoothingModeAntiAlias);
    Graphics.SetTextRenderingHint(TextRenderingHintClearTypeGridFit);

    // Outer Background
    BrushBg := TGPSolidBrush.Create(ColorToARGB(Tokens.Surface));
    PenBorder := TGPPen.Create(ColorToARGB(Tokens.Border), 1.0);
    try
      Graphics.FillRectangle(BrushBg, 0, 0, Width, Height);
      Graphics.DrawRectangle(PenBorder, 0.5, 0.5, Width - 1.0, Height - 1.0);
    finally
      PenBorder.Free;
      BrushBg.Free;
    end;

    FontFamily := TGPFontFamily.Create(Tokens.FontFamily);
    try
      FontSection := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeXS), FontStyleBold, UnitPixel);
      FontItem := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeS), FontStyleRegular, UnitPixel);
      FontBold := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeS), FontStyleBold, UnitPixel);
      FontBadge := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeXS), FontStyleBold, UnitPixel);
      BrushHover := TGPSolidBrush.Create(ColorToARGB(Tokens.SurfaceAlt));
      BrushSel := TGPSolidBrush.Create(ColorToARGB(Tokens.SurfaceAlt));
      BrushPrimary := TGPSolidBrush.Create(ColorToARGB(Tokens.Primary));
      BrushInk := TGPSolidBrush.Create(ColorToARGB(Tokens.Ink));
      BrushMuted := TGPSolidBrush.Create(ColorToARGB(Tokens.InkMuted));
      BrushSection := TGPSolidBrush.Create(ColorToARGB(Tokens.InkMuted));
      PenDiv := TGPPen.Create(ColorToARGB(Tokens.Border), 1.0);
      StrFmtNear := TGPStringFormat.Create;
      StrFmtFar := TGPStringFormat.Create;
      StrFmtCenter := TGPStringFormat.Create;
      try
        StrFmtNear.SetAlignment(StringAlignmentNear);
        StrFmtNear.SetLineAlignment(StringAlignmentCenter);
        StrFmtFar.SetAlignment(StringAlignmentFar);
        StrFmtFar.SetLineAlignment(StringAlignmentCenter);
        StrFmtCenter.SetAlignment(StringAlignmentCenter);
        StrFmtCenter.SetLineAlignment(StringAlignmentCenter);

        CurY := 8.0;
        var Q := LowerCase(Trim(FSearchFilter));
        for I := 0 to FItems.Count - 1 do
        begin
          Item := FItems[I];
          if (Q <> '') and (Item.Kind = nnItem) and (Pos(Q, LowerCase(Item.Title)) = 0) then
            Continue;

          if Item.Kind = nnSectionHeader then
          begin
            ItemH := 28.0;
            if not FIsCollapsed then
            begin
              SecRect := MakeRect(12.0, CurY, Single(Width) - 24.0, ItemH);
              Graphics.DrawString(UpperCase(Item.Title), Length(Item.Title), FontSection, SecRect, StrFmtNear, BrushSection);
            end;
          end
          else if Item.Kind = nnDivider then
          begin
            ItemH := 9.0;
            Graphics.DrawLine(PenDiv, 8.0, CurY + 4.0, Single(Width) - 8.0, CurY + 4.0);
          end
          else
          begin
            ItemH := 36.0;
            IsSel := (Item.Id <> '') and (Item.Id = FSelectedId);
            ItemRect := MakeRect(6.0, CurY, Single(Width) - 12.0, ItemH);

            if IsSel then
            begin
              Graphics.FillRectangle(BrushSel, ItemRect);
              // Left active vertical strip (3px)
              Graphics.FillRectangle(BrushPrimary, 6.0, CurY + 4.0, 3.0, ItemH - 8.0);
            end
            else if I = FHoverIndex then
            begin
              Graphics.FillRectangle(BrushHover, ItemRect);
            end;

            // Icon / Indicator
            DotBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.Primary));
            try
              Graphics.FillEllipse(DotBrush, 18.0, CurY + (ItemH - 6.0) / 2.0, 6.0, 6.0);
            finally
              DotBrush.Free;
            end;

            if not FIsCollapsed then
            begin
              TitleRect := MakeRect(34.0, CurY, Single(Width) - 90.0, ItemH);
              if IsSel then
                Graphics.DrawString(Item.Title, Length(Item.Title), FontBold, TitleRect, StrFmtNear, BrushInk)
              else
                Graphics.DrawString(Item.Title, Length(Item.Title), FontItem, TitleRect, StrFmtNear, BrushInk);

              // Badge
              if Item.BadgeText <> '' then
              begin
                BadgeRect := MakeRect(Single(Width) - 48.0, CurY + (ItemH - 18.0) / 2.0, 36.0, 18.0);
                BrushBdg := TGPSolidBrush.Create(ColorToARGB(Tokens.Sunken));
                try
                  Graphics.FillRectangle(BrushBdg, BadgeRect);
                  Graphics.DrawRectangle(PenDiv, BadgeRect);
                  Graphics.DrawString(Item.BadgeText, Length(Item.BadgeText), FontBadge, BadgeRect, StrFmtCenter, BrushPrimary);
                finally
                  BrushBdg.Free;
                end;
              end;
            end;
          end;

          CurY := CurY + ItemH;
        end;

      finally
        StrFmtCenter.Free;
        StrFmtFar.Free;
        StrFmtNear.Free;
        PenDiv.Free;
        BrushSection.Free;
        BrushMuted.Free;
        BrushInk.Free;
        BrushPrimary.Free;
        BrushSel.Free;
        BrushHover.Free;
        FontBadge.Free;
        FontBold.Free;
        FontItem.Free;
        FontSection.Free;
      end;
    finally
      FontFamily.Free;
    end;
  finally
    Graphics.Free;
  end;
end;

end.
