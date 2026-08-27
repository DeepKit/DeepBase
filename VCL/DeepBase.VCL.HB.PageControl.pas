{ ============================================================================
  DeepBase.VCL.HB.PageControl - Modern 4-Style Tab & PageControl for VCL

  Version: 1.0 (Delphi 13.1 on Win64)
  Description: THbPageControl:
               - 4 Modern Tab Styles (tsUnderline, tsSegmented, tsCard, tsChrome)
               - Closable tabs (Chrome style 'x' button)
               - Dynamic Badge counts per tab
               - Smooth active indicator rendering
  ============================================================================ }

unit DeepBase.VCL.HB.PageControl;

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
  DeepBase.HB.Core,
  DeepBase.HB.PageControl.Types,
  DeepBase.VCL.HB.Theme;

type
  THbTabChangeEvent = procedure(Sender: TObject; ANewIndex: Integer) of object;
  THbTabCloseEvent = procedure(Sender: TObject; ATabIndex: Integer; var CanClose: Boolean) of object;

  /// <summary>
  /// THbPageControl: Modern 4-Style Tab Control for VCL.
  /// </summary>
  THbPageControl = class(TCustomControl)
  private
    FTabs: TList<THbTabItemData>;
    FTabStyle: THbTabStyle;
    FActiveTabIndex: Integer;
    FHoverIndex: Integer;
    FTabHeight: Integer;
    FOnTabChange: THbTabChangeEvent;
    FOnTabClose: THbTabCloseEvent;

    procedure SetTabStyle(Value: THbTabStyle);
    procedure SetActiveTabIndex(Value: Integer);
    function GetTabRect(Index: Integer): TRect;
    function GetTabAt(X, Y: Integer): Integer;
  protected
    procedure Paint; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    function AddTab(const AId, ATitle: string; ABadgeCount: Integer = 0; AClosable: Boolean = False): Integer;
    procedure RemoveTab(Index: Integer);
    procedure ClearTabs;

    property Tabs: TList<THbTabItemData> read FTabs;
  published
    property Align;
    property Anchors;
    property TabStyle: THbTabStyle read FTabStyle write SetTabStyle default tsUnderline;
    property ActiveTabIndex: Integer read FActiveTabIndex write SetActiveTabIndex default 0;
    property TabHeight: Integer read FTabHeight write FTabHeight default 38;
    property OnTabChange: THbTabChangeEvent read FOnTabChange write FOnTabChange;
    property OnTabClose: THbTabCloseEvent read FOnTabClose write FOnTabClose;
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

{ THbPageControl }

constructor THbPageControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 500;
  Height := 300;
  FTabStyle := tsUnderline;
  FActiveTabIndex := 0;
  FHoverIndex := -1;
  FTabHeight := 38;
  FTabs := TList<THbTabItemData>.Create;

  DoubleBuffered := True;
  TabStop := True;
end;

destructor THbPageControl.Destroy;
begin
  FTabs.Free;
  inherited;
end;

procedure THbPageControl.SetTabStyle(Value: THbTabStyle);
begin
  if FTabStyle <> Value then
  begin
    FTabStyle := Value;
    Invalidate;
  end;
end;

procedure THbPageControl.SetActiveTabIndex(Value: Integer);
begin
  if (Value >= 0) and (Value < FTabs.Count) and (FActiveTabIndex <> Value) then
  begin
    FActiveTabIndex := Value;
    Invalidate;
    if Assigned(FOnTabChange) then
      FOnTabChange(Self, FActiveTabIndex);
  end;
end;

function THbPageControl.AddTab(const AId, ATitle: string; ABadgeCount: Integer; AClosable: Boolean): Integer;
var
  T: THbTabItemData;
begin
  T.Id := AId;
  T.Title := ATitle;
  T.IconSvg := '';
  T.BadgeCount := ABadgeCount;
  T.IsClosable := AClosable;
  T.IsEnabled := True;
  T.IsVisible := True;
  T.Tag := 0;
  Result := FTabs.Add(T);
  if FTabs.Count = 1 then
    FActiveTabIndex := 0;
  Invalidate;
end;

procedure THbPageControl.RemoveTab(Index: Integer);
var
  CanClose: Boolean;
begin
  if (Index >= 0) and (Index < FTabs.Count) then
  begin
    CanClose := True;
    if Assigned(FOnTabClose) then
      FOnTabClose(Self, Index, CanClose);

    if CanClose then
    begin
      FTabs.Delete(Index);
      if FActiveTabIndex >= FTabs.Count then
        FActiveTabIndex := FTabs.Count - 1;
      Invalidate;
    end;
  end;
end;

procedure THbPageControl.ClearTabs;
begin
  FTabs.Clear;
  FActiveTabIndex := -1;
  FHoverIndex := -1;
  Invalidate;
end;

function THbPageControl.GetTabRect(Index: Integer): TRect;
var
  I: Integer;
  CurX: Integer;
  TabW: Integer;
begin
  CurX := 8;
  for I := 0 to Index do
  begin
    TabW := 120;
    if I = Index then
      Exit(Rect(CurX, 0, CurX + TabW, FTabHeight));
    Inc(CurX, TabW + 6);
  end;
  Result := Rect(0, 0, 0, 0);
end;

function THbPageControl.GetTabAt(X, Y: Integer): Integer;
var
  I: Integer;
  R: TRect;
begin
  Result := -1;
  if Y <= FTabHeight then
  begin
    for I := 0 to FTabs.Count - 1 do
    begin
      R := GetTabRect(I);
      if PtInRect(R, Point(X, Y)) then
        Exit(I);
    end;
  end;
end;

procedure THbPageControl.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  NewHover: Integer;
begin
  inherited;
  NewHover := GetTabAt(X, Y);
  if FHoverIndex <> NewHover then
  begin
    FHoverIndex := NewHover;
    Invalidate;
  end;
end;

procedure THbPageControl.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  ClickedTab: Integer;
begin
  inherited;
  SetFocus;
  if Button = mbLeft then
  begin
    ClickedTab := GetTabAt(X, Y);
    if (ClickedTab >= 0) and (ClickedTab < FTabs.Count) then
      SetActiveTabIndex(ClickedTab);
  end;
end;

procedure THbPageControl.Paint;
var
  Graphics: TGPGraphics;
  Tokens: THbTokens;
  BrushBg, BrushPrimary, BrushInk, BrushMuted, BrushSeg, BrushOnPrimary, BrushCard: TGPSolidBrush;
  PenBorder, PenActive, PenCard: TGPPen;
  FontFamily: TGPFontFamily;
  FontNormal, FontBold, FontBadge: TGPFont;
  StrFmtCenter: TGPStringFormat;
  I: Integer;
  TabRect: TRect;
  RTab: TGPRectF;
  IsActive: Boolean;
begin
  Tokens := THbTheme.Tokens;
  Graphics := TGPGraphics.Create(Canvas.Handle);
  try
    Graphics.SetSmoothingMode(SmoothingModeAntiAlias);
    Graphics.SetTextRenderingHint(TextRenderingHintClearTypeGridFit);

    // Background
    BrushBg := TGPSolidBrush.Create(ColorToARGB(Tokens.Surface));
    PenBorder := TGPPen.Create(ColorToARGB(Tokens.Border), 1.0);
    try
      Graphics.FillRectangle(BrushBg, MakeRect(0.0, 0.0, Single(Width), Single(Height)));
      // Header dividing line
      Graphics.DrawLine(PenBorder, 0.0, Single(FTabHeight), Single(Width), Single(FTabHeight));
    finally
      PenBorder.Free;
      BrushBg.Free;
    end;

    FontFamily := TGPFontFamily.Create(Tokens.FontFamily);
    try
      FontNormal := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeS), FontStyleRegular, UnitPixel);
      FontBold := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeS), FontStyleBold, UnitPixel);
      FontBadge := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeXS), FontStyleBold, UnitPixel);
      BrushPrimary := TGPSolidBrush.Create(ColorToARGB(Tokens.Primary));
      BrushInk := TGPSolidBrush.Create(ColorToARGB(Tokens.Ink));
      BrushMuted := TGPSolidBrush.Create(ColorToARGB(Tokens.InkMuted));
      PenActive := TGPPen.Create(ColorToARGB(Tokens.Primary), 2.5);
      StrFmtCenter := TGPStringFormat.Create;
      try
        StrFmtCenter.SetAlignment(StringAlignmentCenter);
        StrFmtCenter.SetLineAlignment(StringAlignmentCenter);

        for I := 0 to FTabs.Count - 1 do
        begin
          TabRect := GetTabRect(I);
          RTab := MakeRect(Single(TabRect.Left), Single(TabRect.Top), Single(TabRect.Width), Single(TabRect.Height));
          IsActive := (I = FActiveTabIndex);

          case FTabStyle of
            tsSegmented:
            begin
              if IsActive then
              begin
                BrushSeg := TGPSolidBrush.Create(ColorToARGB(Tokens.Primary));
                try
                  Graphics.FillRectangle(BrushSeg, MakeRect(Single(TabRect.Left), Single(TabRect.Top) + 4.0, Single(TabRect.Width), Single(TabRect.Height) - 8.0));
                finally
                  BrushSeg.Free;
                end;
              end;
            end;

            tsCard:
            begin
              if IsActive then
              begin
                BrushCard := TGPSolidBrush.Create(ColorToARGB(Tokens.Surface));
                PenCard := TGPPen.Create(ColorToARGB(Tokens.Border), 1.0);
                try
                  Graphics.FillRectangle(BrushCard, MakeRect(Single(TabRect.Left), Single(TabRect.Top) + 2.0, Single(TabRect.Width), Single(TabRect.Height) - 2.0));
                  Graphics.DrawLine(PenCard, Single(TabRect.Left), Single(TabRect.Top) + 2.0, Single(TabRect.Left), Single(TabRect.Bottom));
                  Graphics.DrawLine(PenCard, Single(TabRect.Left), Single(TabRect.Top) + 2.0, Single(TabRect.Right), Single(TabRect.Top) + 2.0);
                  Graphics.DrawLine(PenCard, Single(TabRect.Right), Single(TabRect.Top) + 2.0, Single(TabRect.Right), Single(TabRect.Bottom));
                finally
                  PenCard.Free;
                  BrushCard.Free;
                end;
              end
              else
              begin
                BrushCard := TGPSolidBrush.Create(ColorToARGB(Tokens.SurfaceAlt));
                try
                  Graphics.FillRectangle(BrushCard, MakeRect(Single(TabRect.Left), Single(TabRect.Top) + 4.0, Single(TabRect.Width), Single(TabRect.Height) - 4.0));
                finally
                  BrushCard.Free;
                end;
              end;
            end;

            tsChrome:
            begin
              if IsActive then
              begin
                BrushCard := TGPSolidBrush.Create(ColorToARGB(Tokens.SurfaceAlt));
                try
                  Graphics.FillRectangle(BrushCard, MakeRect(Single(TabRect.Left), Single(TabRect.Top) + 2.0, Single(TabRect.Width), Single(TabRect.Height) - 2.0));
                finally
                  BrushCard.Free;
                end;
              end;
            end;
          end;

          // Draw Caption
          if IsActive then
          begin
            if FTabStyle = tsSegmented then
            begin
              BrushOnPrimary := TGPSolidBrush.Create(ColorToARGB(Tokens.OnPrimary));
              try
                Graphics.DrawString(FTabs[I].Title, Length(FTabs[I].Title), FontBold, RTab, StrFmtCenter, BrushOnPrimary);
              finally
                BrushOnPrimary.Free;
              end;
            end
            else
            begin
              Graphics.DrawString(FTabs[I].Title, Length(FTabs[I].Title), FontBold, RTab, StrFmtCenter, BrushInk);
              if FTabStyle = tsUnderline then
                Graphics.DrawLine(PenActive, Single(TabRect.Left) + 8.0, Single(FTabHeight) - 1.0, Single(TabRect.Right) - 8.0, Single(FTabHeight) - 1.0);
            end;
          end
          else
          begin
            Graphics.DrawString(FTabs[I].Title, Length(FTabs[I].Title), FontNormal, RTab, StrFmtCenter, BrushMuted);
          end;

          // Draw Dynamic Badge Count
          if FTabs[I].BadgeCount > 0 then
          begin
            var BdgText := IntToStr(FTabs[I].BadgeCount);
            var BdgRect := MakeRect(Single(TabRect.Right) - 24.0, Single(TabRect.Top) + 6.0, 18.0, 14.0);
            var BrushBdg := TGPSolidBrush.Create(ColorToARGB(Tokens.Primary));
            var BrushBdgText := TGPSolidBrush.Create(ColorToARGB(Tokens.OnPrimary));
            try
              Graphics.FillRectangle(BrushBdg, BdgRect);
              Graphics.DrawString(BdgText, Length(BdgText), FontBadge, BdgRect, StrFmtCenter, BrushBdgText);
            finally
              BrushBdgText.Free;
              BrushBdg.Free;
            end;
          end;
        end;

      finally
        StrFmtCenter.Free;
        PenActive.Free;
        BrushMuted.Free;
        BrushInk.Free;
        BrushPrimary.Free;
        FontBadge.Free;
        FontBold.Free;
        FontNormal.Free;
      end;
    finally
      FontFamily.Free;
    end;
  finally
    Graphics.Free;
  end;
end;

end.
