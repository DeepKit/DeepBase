{ ============================================================================
  DeepBase.VCL.HB.Choice - Modern Token-Driven 0-9 Choice Deck Component

  Version: 1.0 (Delphi 13.1 on Win64)
  Description: THbChoiceDeck:
               - 1-7 Contextual options (Key 1 can be Recommended)
               - 8 Fixed control: Regenerate
               - 9 Fixed control: Custom Input ("Myself", not "Other")
               - 0 Fixed control: Navigate Back (Navigation, not Rejection)
               - 4 Semantic Color Tokens: Choice.Option / Regenerate / Input / Back
               - Mouse click and Keyboard numbers (1..7, 8, 9, 0) equivalent
               - High-DPI scaling, WCAG AA contrast, Five-state machine
  ============================================================================ }

unit DeepBase.VCL.HB.Choice;

{$WARN IMPLICIT_STRING_CAST OFF}

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
  System.Math,
  System.Generics.Collections,
  Vcl.Controls,
  Vcl.Graphics,
  Vcl.Forms,
  Winapi.GDIPAPI,
  Winapi.GDIPOBJ,
  DeepBase.HB.Core,
  DeepBase.HB.Choice.Types,
  DeepBase.VCL.HB.Theme,
  DeepBase.VCL.HB.Controls;

type
  /// <summary>
  /// THbChoiceDeck: Standard 0-9 Interactive Choice Deck Control for VCL.
  /// </summary>
  THbChoiceDeck = class(THbCustomControl)
  private
    FItems: TList<THbChoiceItem>;
    FSelectedIndex: Integer;
    FHoverIndex: Integer;
    FPressedIndex: Integer;
    FItemHeight: Integer;
    FItemSpacing: Integer;
    FOnChoice: THbChoiceEvent;
    FOnCustomInput: THbChoiceInputEvent;
    procedure SetSelectedIndex(Value: Integer);
    function ItemIndexAt(X, Y: Integer): Integer;
    function GetItemCount: Integer;
    function GetItem(Index: Integer): THbChoiceItem;
    procedure SetItem(Index: Integer; const Value: THbChoiceItem);
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
    procedure WMKeyDown(var Message: TWMKeyDown); message WM_KEYDOWN;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure Clear;
    procedure AddOption(AKey: Integer; const AText: string;
      const ADesc: string = ''; AIsRecommended: Boolean = False);
    procedure AddStandardControls(AHasRegenerate: Boolean = True;
      AHasInput: Boolean = True; AHasBack: Boolean = True);
    procedure SetOptions(const AOptions: array of string; ARecommendedKey: Integer = 1);

    procedure SelectKey(AKey: Integer);
    procedure SetItemEnabled(AKey: Integer; AEnabled: Boolean);
    function FindItemByKey(AKey: Integer; out AItem: THbChoiceItem): Boolean;
    function IndexOfKey(AKey: Integer): Integer;
    function ItemRect(AIndex: Integer): TRect;

    property Items[Index: Integer]: THbChoiceItem read GetItem write SetItem;
    property ItemCount: Integer read GetItemCount;
    property SelectedIndex: Integer read FSelectedIndex write SetSelectedIndex;
  published
    property Align;
    property Anchors;
    property Enabled;
    property TabStop default True;
    property Visible;
    property ItemHeight: Integer read FItemHeight write FItemHeight default 46;
    property ItemSpacing: Integer read FItemSpacing write FItemSpacing default 8;
    property OnChoice: THbChoiceEvent read FOnChoice write FOnChoice;
    property OnCustomInput: THbChoiceInputEvent read FOnCustomInput write FOnCustomInput;
    property OnClick;
    property OnEnter;
    property OnExit;
  end;

implementation

{ THbChoiceDeck }

constructor THbChoiceDeck.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FItems := TList<THbChoiceItem>.Create;
  FSelectedIndex := -1;
  FHoverIndex := -1;
  FPressedIndex := -1;
  FItemHeight := ScalePixels(46);
  FItemSpacing := ScalePixels(8);
  Width := ScalePixels(420);
  Height := ScalePixels(360);
  TabStop := True;
  DoubleBuffered := True;
end;

destructor THbChoiceDeck.Destroy;
begin
  FItems.Free;
  inherited;
end;

procedure THbChoiceDeck.Resize;
begin
  inherited;
  Invalidate;
end;

procedure THbChoiceDeck.Clear;
begin
  FItems.Clear;
  FSelectedIndex := -1;
  FHoverIndex := -1;
  FPressedIndex := -1;
  Invalidate;
end;

function THbChoiceDeck.GetItemCount: Integer;
begin
  Result := FItems.Count;
end;

function THbChoiceDeck.GetItem(Index: Integer): THbChoiceItem;
begin
  Result := FItems[Index];
end;

procedure THbChoiceDeck.SetItem(Index: Integer; const Value: THbChoiceItem);
begin
  FItems[Index] := Value;
  Invalidate;
end;

procedure THbChoiceDeck.AddOption(AKey: Integer; const AText, ADesc: string;
  AIsRecommended: Boolean);
var
  Item: THbChoiceItem;
begin
  Item := THbChoiceItem.Create(AKey, AText, ADesc, AIsRecommended, True);
  FItems.Add(Item);
  if (FSelectedIndex = -1) and (FItems.Count = 1) then
    FSelectedIndex := 0;
  Invalidate;
end;

procedure THbChoiceDeck.AddStandardControls(AHasRegenerate, AHasInput, AHasBack: Boolean);
begin
  if AHasRegenerate then
    AddOption(8, GetDefaultKeyLabel(8), '重新提问或生成');
  if AHasInput then
    AddOption(9, GetDefaultKeyLabel(9), '手动输入说明或修改');
  if AHasBack then
    AddOption(0, GetDefaultKeyLabel(0), '返回上一步');
end;

procedure THbChoiceDeck.SetOptions(const AOptions: array of string; ARecommendedKey: Integer);
var
  I, Key: Integer;
begin
  Clear;
  for I := 0 to High(AOptions) do
  begin
    Key := I + 1;
    if Key <= 7 then
      AddOption(Key, AOptions[I], '', Key = ARecommendedKey);
  end;
  AddStandardControls(True, True, True);
end;

function THbChoiceDeck.IndexOfKey(AKey: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to FItems.Count - 1 do
    if FItems[I].Key = AKey then
      Exit(I);
end;

function THbChoiceDeck.FindItemByKey(AKey: Integer; out AItem: THbChoiceItem): Boolean;
var
  Idx: Integer;
begin
  Idx := IndexOfKey(AKey);
  if Idx >= 0 then
  begin
    AItem := FItems[Idx];
    Result := True;
  end
  else
    Result := False;
end;

procedure THbChoiceDeck.SelectKey(AKey: Integer);
var
  Idx: Integer;
begin
  Idx := IndexOfKey(AKey);
  if (Idx >= 0) and FItems[Idx].Enabled then
  begin
    FSelectedIndex := Idx;
    Invalidate;
    if Assigned(FOnChoice) then
      FOnChoice(Self, AKey);
    if (AKey = 9) and Assigned(FOnCustomInput) then
      FOnCustomInput(Self, FItems[Idx].Text);
  end;
end;

procedure THbChoiceDeck.SetItemEnabled(AKey: Integer; AEnabled: Boolean);
var
  Idx: Integer;
  Item: THbChoiceItem;
begin
  Idx := IndexOfKey(AKey);
  if Idx >= 0 then
  begin
    Item := FItems[Idx];
    if Item.Enabled <> AEnabled then
    begin
      Item.Enabled := AEnabled;
      FItems[Idx] := Item;
      Invalidate;
    end;
  end;
end;

procedure THbChoiceDeck.SetSelectedIndex(Value: Integer);
begin
  if (Value >= -1) and (Value < FItems.Count) and (FSelectedIndex <> Value) then
  begin
    FSelectedIndex := Value;
    Invalidate;
  end;
end;

function THbChoiceDeck.ItemRect(AIndex: Integer): TRect;
var
  Y: Integer;
begin
  if (AIndex < 0) or (AIndex >= FItems.Count) then
    Exit(Rect(0, 0, 0, 0));

  Y := ScalePixels(6) + AIndex * (FItemHeight + FItemSpacing);
  Result := Rect(ScalePixels(8), Y, Width - ScalePixels(8), Y + FItemHeight);
end;

function THbChoiceDeck.ItemIndexAt(X, Y: Integer): Integer;
var
  I: Integer;
  R: TRect;
begin
  Result := -1;
  for I := 0 to FItems.Count - 1 do
  begin
    R := ItemRect(I);
    if PtInRect(R, Point(X, Y)) then
      Exit(I);
  end;
end;

procedure THbChoiceDeck.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Idx: Integer;
begin
  inherited;
  if CanFocus and Showing then
  try
    SetFocus;
  except
  end;

  if Button = mbLeft then
  begin
    Idx := ItemIndexAt(X, Y);
    if (Idx >= 0) and FItems[Idx].Enabled then
    begin
      FPressedIndex := Idx;
      FSelectedIndex := Idx;
      Invalidate;
    end;
  end;
end;

procedure THbChoiceDeck.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  Idx: Integer;
begin
  inherited;
  Idx := ItemIndexAt(X, Y);
  if FHoverIndex <> Idx then
  begin
    FHoverIndex := Idx;
    Invalidate;
  end;
end;

procedure THbChoiceDeck.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Idx: Integer;
  TriggerKey: Integer;
begin
  inherited;
  if Button = mbLeft then
  begin
    Idx := ItemIndexAt(X, Y);
    if (FPressedIndex >= 0) and (FPressedIndex = Idx) and FItems[Idx].Enabled then
    begin
      TriggerKey := FItems[Idx].Key;
      FPressedIndex := -1;
      Invalidate;

      if Assigned(FOnChoice) then
        FOnChoice(Self, TriggerKey);
      if (TriggerKey = 9) and Assigned(FOnCustomInput) then
        FOnCustomInput(Self, FItems[Idx].Text);
    end
    else
    begin
      FPressedIndex := -1;
      Invalidate;
    end;
  end;
end;

procedure THbChoiceDeck.CMMouseLeave(var Message: TMessage);
begin
  inherited;
  if FHoverIndex <> -1 then
  begin
    FHoverIndex := -1;
    FPressedIndex := -1;
    Invalidate;
  end;
end;

procedure THbChoiceDeck.WMKeyDown(var Message: TWMKeyDown);
var
  DigitKey: Integer;
  Idx: Integer;
begin
  inherited;
  DigitKey := -1;

  // Direct Number Key Mappings (0..9)
  case Message.CharCode of
    Ord('0'), VK_NUMPAD0: DigitKey := 0;
    Ord('1'), VK_NUMPAD1: DigitKey := 1;
    Ord('2'), VK_NUMPAD2: DigitKey := 2;
    Ord('3'), VK_NUMPAD3: DigitKey := 3;
    Ord('4'), VK_NUMPAD4: DigitKey := 4;
    Ord('5'), VK_NUMPAD5: DigitKey := 5;
    Ord('6'), VK_NUMPAD6: DigitKey := 6;
    Ord('7'), VK_NUMPAD7: DigitKey := 7;
    Ord('8'), VK_NUMPAD8: DigitKey := 8;
    Ord('9'), VK_NUMPAD9: DigitKey := 9;

    VK_UP:
    begin
      if FSelectedIndex > 0 then
        SelectedIndex := FSelectedIndex - 1
      else if (FSelectedIndex = -1) and (FItems.Count > 0) then
        SelectedIndex := 0;
      Exit;
    end;

    VK_DOWN:
    begin
      if FSelectedIndex < FItems.Count - 1 then
        SelectedIndex := FSelectedIndex + 1
      else if (FSelectedIndex = -1) and (FItems.Count > 0) then
        SelectedIndex := 0;
      Exit;
    end;

    VK_RETURN, VK_SPACE:
    begin
      if (FSelectedIndex >= 0) and (FSelectedIndex < FItems.Count) and FItems[FSelectedIndex].Enabled then
      begin
        DigitKey := FItems[FSelectedIndex].Key;
      end;
    end;
  end;

  if DigitKey >= 0 then
  begin
    Idx := IndexOfKey(DigitKey);
    if (Idx >= 0) and FItems[Idx].Enabled then
    begin
      FSelectedIndex := Idx;
      Invalidate;
      if Assigned(FOnChoice) then
        FOnChoice(Self, DigitKey);
      if (DigitKey = 9) and Assigned(FOnCustomInput) then
        FOnCustomInput(Self, FItems[Idx].Text);
    end;
  end;
end;

procedure THbChoiceDeck.Paint;
var
  Graphics: TGPGraphics;
  Tokens: THbTokens;
  I: Integer;
  Item: THbChoiceItem;
  R: TRect;
  ItemBox, BadgeBox, RecBadgeBox: TGPRectF;
  ItemPath, BadgePath, RecBadgePath: TGPGraphicsPath;
  BgBrush, BadgeBrush, TextBrush, SubBrush: TGPSolidBrush;
  BorderPen: TGPPen;
  FontFam: TGPFontFamily;
  MainFont, KeyFont, DescFont, BadgeFont: TGPFont;
  FormatLeft, FormatCenter, FormatRight: TGPStringFormat;
  KeyStr, RecStr: string;
  AccentColor, BorderColor, FillColor: TAlphaColor;
  IsItemHover, IsItemPressed, IsItemFocused: Boolean;
  Rad: Single;
begin
  Tokens := GetTokens;
  Graphics := TGPGraphics.Create(Canvas.Handle);
  try
    Graphics.SetSmoothingMode(SmoothingModeAntiAlias);
    Graphics.SetTextRenderingHint(TextRenderingHintClearTypeGridFit);

    EraseBackground(Graphics);

    FontFam := TGPFontFamily.Create(PWideChar(Tokens.FontFamily));
    try
      MainFont := TGPFont.Create(FontFam, Tokens.SizeM, FontStyleRegular, UnitPoint);
      KeyFont := TGPFont.Create(FontFam, Tokens.SizeM, FontStyleBold, UnitPoint);
      DescFont := TGPFont.Create(FontFam, Tokens.SizeS, FontStyleRegular, UnitPoint);
      BadgeFont := TGPFont.Create(FontFam, Tokens.SizeXS, FontStyleBold, UnitPoint);
      FormatLeft := TGPStringFormat.Create;
      FormatLeft.SetAlignment(StringAlignmentNear);
      FormatLeft.SetLineAlignment(StringAlignmentCenter);
      FormatLeft.SetFormatFlags(StringFormatFlagsNoWrap);

      FormatCenter := TGPStringFormat.Create;
      FormatCenter.SetAlignment(StringAlignmentCenter);
      FormatCenter.SetLineAlignment(StringAlignmentCenter);

      FormatRight := TGPStringFormat.Create;
      FormatRight.SetAlignment(StringAlignmentFar);
      FormatRight.SetLineAlignment(StringAlignmentCenter);
      try
        Rad := ScaleDIP(Tokens.RadiusM);

        for I := 0 to FItems.Count - 1 do
        begin
          Item := FItems[I];
          R := ItemRect(I);
          ItemBox := MakeRect(Single(R.Left), Single(R.Top), Single(R.Width), Single(R.Height));

          IsItemHover := (FHoverIndex = I);
          IsItemPressed := (FPressedIndex = I);
          IsItemFocused := (FSelectedIndex = I) and Focused;

          // 1. Resolve Semantic Accent Color based on Kind
          case Item.Kind of
            ckOption:
            begin
              AccentColor := Tokens.ChoiceOption;
              BorderColor := Tokens.Border;
              if Item.IsRecommended then
                BorderColor := Tokens.ChoiceRecommended;
            end;
            ckRegenerate:
            begin
              AccentColor := Tokens.ChoiceRegenerate;
              BorderColor := Tokens.ChoiceRegenerate;
            end;
            ckInput:
            begin
              AccentColor := Tokens.ChoiceInput;
              BorderColor := Tokens.ChoiceInput;
            end;
            ckBack:
            begin
              AccentColor := Tokens.ChoiceBack;
              BorderColor := Tokens.ChoiceBack;
            end;
          else
            AccentColor := Tokens.ChoiceOption;
            BorderColor := Tokens.Border;
          end;

          // 2. Compute Fill and Highlight
          if not Item.Enabled then
          begin
            FillColor := ColorToARGB(Tokens.Sunken, 160);
            BorderColor := ColorToARGB(Tokens.Border, 100);
          end
          else if IsItemPressed then
          begin
            FillColor := ColorToARGB(AccentColor, 60);
          end
          else if IsItemHover then
          begin
            FillColor := ColorToARGB(AccentColor, 35);
          end
          else
          begin
            FillColor := Tokens.Surface;
          end;

          // 3. Draw Item Container
          ItemPath := CreateRoundRectPath(ItemBox, Rad);
          try
            BgBrush := TGPSolidBrush.Create(FillColor);
            try
              Graphics.FillPath(BgBrush, ItemPath);
            finally
              BgBrush.Free;
            end;

            // Border
            if IsItemFocused then
              BorderPen := TGPPen.Create(ColorToARGB(Tokens.FocusRing), 2.0)
            else if IsItemHover or (Item.IsRecommended and (Item.Kind = ckOption)) then
              BorderPen := TGPPen.Create(ColorToARGB(BorderColor), 1.5)
            else
              BorderPen := TGPPen.Create(ColorToARGB(BorderColor, 180), 1.0);

            try
              Graphics.DrawPath(BorderPen, ItemPath);
            finally
              BorderPen.Free;
            end;
          finally
            ItemPath.Free;
          end;

          // 4. Draw Number Key Badge [Key]
          BadgeBox := MakeRect(ItemBox.X + ScaleDIP(8), ItemBox.Y + (ItemBox.Height - ScaleDIP(28)) * 0.5,
                               ScaleDIP(32), ScaleDIP(28));
          BadgePath := CreateRoundRectPath(BadgeBox, ScaleDIP(Tokens.RadiusS));
          try
            if Item.Kind in [ckRegenerate, ckInput, ckBack] then
              BadgeBrush := TGPSolidBrush.Create(ColorToARGB(AccentColor, 35))
            else if Item.IsRecommended then
              BadgeBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.ChoiceRecommended, 40))
            else
              BadgeBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.Border, 60));

            try
              Graphics.FillPath(BadgeBrush, BadgePath);
            finally
              BadgeBrush.Free;
            end;

            KeyStr := IntToStr(Item.Key);
            if Item.Kind in [ckRegenerate, ckInput, ckBack] then
              TextBrush := TGPSolidBrush.Create(ColorToARGB(AccentColor))
            else if Item.IsRecommended then
              TextBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.ChoiceRecommended))
            else
              TextBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.Ink));

            try
              Graphics.DrawString(PWideChar(KeyStr), Length(KeyStr), KeyFont, BadgeBox, FormatCenter, TextBrush);
            finally
              TextBrush.Free;
            end;
          finally
            BadgePath.Free;
          end;

          // 5. Draw Title & Optional Description
          var TextLeft := ItemBox.X + ScaleDIP(48);
          var TextRight := ItemBox.Width - ScaleDIP(56);
          if Item.IsRecommended then
            TextRight := TextRight - ScaleDIP(60);

          var TextRect := MakeRect(TextLeft, ItemBox.Y + ScaleDIP(4), TextRight, ItemBox.Height - ScaleDIP(8));

          TextBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.Ink));
          try
            if Item.Description <> '' then
            begin
              var TitleR := MakeRect(TextLeft, ItemBox.Y + ScaleDIP(5), TextRight, ScaleDIP(18));
              var DescR := MakeRect(TextLeft, ItemBox.Y + ScaleDIP(23), TextRight, ScaleDIP(16));

              Graphics.DrawString(PWideChar(Item.Text), Length(Item.Text), MainFont, TitleR, FormatLeft, TextBrush);

              SubBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.InkMuted));
              try
                Graphics.DrawString(PWideChar(Item.Description), Length(Item.Description), DescFont, DescR, FormatLeft, SubBrush);
              finally
                SubBrush.Free;
              end;
            end
            else
            begin
              Graphics.DrawString(PWideChar(Item.Text), Length(Item.Text), MainFont, TextRect, FormatLeft, TextBrush);
            end;
          finally
            TextBrush.Free;
          end;

          // 6. Draw [推荐] Badge on Item 1 if Recommended
          if Item.IsRecommended then
          begin
            RecBadgeBox := MakeRect(ItemBox.X + ItemBox.Width - ScaleDIP(54),
                                    ItemBox.Y + (ItemBox.Height - ScaleDIP(20)) * 0.5,
                                    ScaleDIP(46), ScaleDIP(20));
            RecBadgePath := CreateRoundRectPath(RecBadgeBox, ScaleDIP(Tokens.RadiusS));
            try
              BadgeBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.ChoiceRecommended, 30));
              try
                Graphics.FillPath(BadgeBrush, RecBadgePath);
              finally
                BadgeBrush.Free;
              end;

              BorderPen := TGPPen.Create(ColorToARGB(Tokens.ChoiceRecommended, 160), 1.0);
              try
                Graphics.DrawPath(BorderPen, RecBadgePath);
              finally
                BorderPen.Free;
              end;

              RecStr := '推荐';
              TextBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.ChoiceRecommended));
              try
                Graphics.DrawString(PWideChar(RecStr), Length(RecStr), BadgeFont, RecBadgeBox, FormatCenter, TextBrush);
              finally
                TextBrush.Free;
              end;
            finally
              RecBadgePath.Free;
            end;
          end;
        end;

      finally
        FormatLeft.Free;
        FormatCenter.Free;
        FormatRight.Free;
        MainFont.Free;
        KeyFont.Free;
        DescFont.Free;
        BadgeFont.Free;
      end;
    finally
      FontFam.Free;
    end;
  finally
    Graphics.Free;
  end;
end;

end.
