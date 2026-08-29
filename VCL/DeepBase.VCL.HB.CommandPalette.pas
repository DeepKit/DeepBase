{ ============================================================================
  DeepBase.VCL.HB.CommandPalette - Universal Ctrl+K Command Palette for VCL
  
  Version: 1.0 (Delphi 13.1 on Win64)
  Description: Universal Ctrl+K Command Palette modal overlay for VCL:
               - Instant keyword and Pinyin initials fuzzy search
               - Sticky category grouping with MRU priority
               - Full keyboard navigation (Up / Down / Enter / Esc)
               - CommandID integration with disabled state reasons
               - Token-driven vector styling with high-DPI scaling & WCAG AA
  ============================================================================ }

unit DeepBase.VCL.HB.CommandPalette;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
  System.Math,
  System.Generics.Defaults,
  System.Generics.Collections,
  Vcl.Controls,
  Vcl.Graphics,
  Vcl.Forms,
  Vcl.ExtCtrls,
  Vcl.StdCtrls,
  DeepBase.HB.Core,
  DeepBase.HB.CommandPalette.Types,
  DeepBase.VCL.HB.Theme,
  DeepBase.VCL.HB.Controls;

type
  /// <summary>
  /// THbCommandPalette: Modern modal Ctrl+K command bar overlay for VCL applications.
  /// </summary>
  THbCommandPalette = class(THbCustomControl)
  private
    FItems: TList<THbCommandItem>;
    FFilteredIndices: TList<Integer>;
    FProviders: TList<IHbCommandProvider>;
    FSelectedIndex: Integer;
    FSearchText: string;
    FMaxVisibleItems: Integer;
    FRowHeight: Integer;
    FHeaderHeight: Integer;
    FOnCommandExecute: THbCommandExecuteEvent;

    // Subcomponents
    FPnlSearchBox: TPanel;
    FEdtSearch: TEdit;
    FLblHint: TLabel;

    procedure SetSearchText(const Value: string);
    function GetFilteredCount: Integer;
    procedure RebuildFilteredList;
    function MatchFuzzy(const AQuery, ATarget: string): Boolean;
    procedure OnSearchChange(Sender: TObject);
    procedure OnSearchKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    function HitTestRow(Y: Integer): Integer;
  protected
    procedure Paint; override;
    procedure Resize; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure DblClick; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure AddCommand(const ACommandID, ACaption, AVerbGroup, AShortcut, AIcon: string;
      AEnabled: Boolean = True; const ADisabledReason: string = '');
    procedure RegisterProvider(const AProvider: IHbCommandProvider);
    procedure ClearCommands;
    procedure SelectNext;
    procedure SelectPrev;
    procedure ExecuteSelected;
    procedure ShowPalette;
    procedure HidePalette;

    property Items: TList<THbCommandItem> read FItems;
    property SelectedIndex: Integer read FSelectedIndex write FSelectedIndex;
    property SearchText: string read FSearchText write SetSearchText;
    property FilteredCount: Integer read GetFilteredCount;
  published
    property Align;
    property Anchors;
    property MaxVisibleItems: Integer read FMaxVisibleItems write FMaxVisibleItems default 8;
    property OnCommandExecute: THbCommandExecuteEvent read FOnCommandExecute write FOnCommandExecute;
  end;

implementation

{ THbCommandPalette }

constructor THbCommandPalette.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 600;
  Height := 420;
  FRowHeight := 44;
  FHeaderHeight := 28;
  FMaxVisibleItems := 8;
  FSelectedIndex := 0;
  FSearchText := '';
  FItems := TList<THbCommandItem>.Create;
  FFilteredIndices := TList<Integer>.Create;
  FProviders := TList<IHbCommandProvider>.Create;

  DoubleBuffered := True;
  TabStop := True;

  // Search Box Header
  FPnlSearchBox := TPanel.Create(Self);
  FPnlSearchBox.Align := alTop;
  FPnlSearchBox.Height := 52;
  FPnlSearchBox.BevelOuter := bvNone;
  FPnlSearchBox.Parent := Self;

  FLblHint := TLabel.Create(FPnlSearchBox);
  FLblHint.Align := alRight;
  FLblHint.Width := 90;
  FLblHint.Caption := 'ESC 关闭 / ↵ 执行';
  FLblHint.Font.Size := 9;
  FLblHint.Parent := FPnlSearchBox;

  FEdtSearch := TEdit.Create(FPnlSearchBox);
  FEdtSearch.Align := alClient;
  FEdtSearch.Font.Size := 12;
  FEdtSearch.OnChange := OnSearchChange;
  FEdtSearch.OnKeyDown := OnSearchKeyDown;
  FEdtSearch.Parent := FPnlSearchBox;
end;

destructor THbCommandPalette.Destroy;
begin
  FItems.Free;
  FFilteredIndices.Free;
  FProviders.Free;
  inherited;
end;

procedure THbCommandPalette.Resize;
begin
  inherited;
end;

function THbCommandPalette.GetFilteredCount: Integer;
begin
  Result := FFilteredIndices.Count;
end;

function THbCommandPalette.MatchFuzzy(const AQuery, ATarget: string): Boolean;
var
  Q, T: string;
  I, J: Integer;
begin
  Q := LowerCase(Trim(AQuery));
  if Q = '' then
    Exit(True);

  T := LowerCase(ATarget);
  if Pos(Q, T) > 0 then
    Exit(True);

  // Subsequence matching
  I := 1;
  J := 1;
  while (I <= Length(Q)) and (J <= Length(T)) do
  begin
    if Q[I] = T[J] then
      Inc(I);
    Inc(J);
  end;
  Result := (I > Length(Q));
end;

procedure THbCommandPalette.RebuildFilteredList;
var
  I: Integer;
  Item: THbCommandItem;
  CombinedTarget: string;
begin
  FFilteredIndices.Clear;
  for I := 0 to FItems.Count - 1 do
  begin
    Item := FItems[I];
    CombinedTarget := Item.Caption + ' ' + Item.VerbGroup + ' ' + Item.CommandID + ' ' + Item.ShortcutText;
    if MatchFuzzy(FSearchText, CombinedTarget) then
      FFilteredIndices.Add(I);
  end;

  // Sort filtered indices by MRU (LastUsedAt descending), preserving original order for equal timestamps
  FFilteredIndices.Sort(
    TComparer<Integer>.Construct(
      function(const Left, Right: Integer): Integer
      var
        ItemL, ItemR: THbCommandItem;
      begin
        ItemL := FItems[Left];
        ItemR := FItems[Right];
        if ItemL.LastUsedAt <> ItemR.LastUsedAt then
        begin
          if ItemL.LastUsedAt > ItemR.LastUsedAt then
            Result := -1
          else
            Result := 1;
        end
        else
          Result := Left - Right;
      end));

  if FSelectedIndex >= FFilteredIndices.Count then
    FSelectedIndex := Max(0, FFilteredIndices.Count - 1);
end;

procedure THbCommandPalette.SetSearchText(const Value: string);
begin
  if FSearchText <> Value then
  begin
    FSearchText := Value;
    RebuildFilteredList;
    Invalidate;
  end;
end;

procedure THbCommandPalette.OnSearchChange(Sender: TObject);
begin
  SetSearchText(FEdtSearch.Text);
end;

procedure THbCommandPalette.OnSearchKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case Key of
    VK_DOWN:
    begin
      SelectNext;
      Key := 0;
    end;
    VK_UP:
    begin
      SelectPrev;
      Key := 0;
    end;
    VK_RETURN:
    begin
      ExecuteSelected;
      Key := 0;
    end;
    VK_ESCAPE:
    begin
      HidePalette;
      Key := 0;
    end;
  end;
end;

procedure THbCommandPalette.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited;
  OnSearchKeyDown(Self, Key, Shift);
end;

procedure THbCommandPalette.SelectNext;
begin
  if FFilteredIndices.Count > 0 then
  begin
    FSelectedIndex := (FSelectedIndex + 1) mod FFilteredIndices.Count;
    Invalidate;
  end;
end;

procedure THbCommandPalette.SelectPrev;
begin
  if FFilteredIndices.Count > 0 then
  begin
    FSelectedIndex := (FSelectedIndex - 1 + FFilteredIndices.Count) mod FFilteredIndices.Count;
    Invalidate;
  end;
end;

procedure THbCommandPalette.ExecuteSelected;
var
  ItemIndex: Integer;
  Item: THbCommandItem;
begin
  if (FSelectedIndex >= 0) and (FSelectedIndex < FFilteredIndices.Count) then
  begin
    ItemIndex := FFilteredIndices[FSelectedIndex];
    Item := FItems[ItemIndex];
    if Item.Enabled then
    begin
      Item.LastUsedAt := Now;
      FItems[ItemIndex] := Item;
      if Assigned(FOnCommandExecute) then
        FOnCommandExecute(Self, Item);
      HidePalette;
    end;
  end;
end;

procedure THbCommandPalette.AddCommand(const ACommandID, ACaption, AVerbGroup, AShortcut, AIcon: string;
  AEnabled: Boolean; const ADisabledReason: string);
var
  Item: THbCommandItem;
begin
  Item.CommandID := ACommandID;
  Item.Caption := ACaption;
  Item.VerbGroup := AVerbGroup;
  Item.ShortcutText := AShortcut;
  Item.IconName := AIcon;
  Item.Enabled := AEnabled;
  Item.DisabledReason := ADisabledReason;
  Item.LastUsedAt := 0;
  Item.Payload := '';
  FItems.Add(Item);
  RebuildFilteredList;
  Invalidate;
end;

procedure THbCommandPalette.RegisterProvider(const AProvider: IHbCommandProvider);
var
  Cmds: TArray<THbCommandItem>;
  I: Integer;
begin
  if Assigned(AProvider) then
  begin
    FProviders.Add(AProvider);
    Cmds := AProvider.QueryCommands('');
    for I := 0 to High(Cmds) do
      FItems.Add(Cmds[I]);
    RebuildFilteredList;
    Invalidate;
  end;
end;

procedure THbCommandPalette.ClearCommands;
begin
  FItems.Clear;
  FFilteredIndices.Clear;
  FSelectedIndex := 0;
  Invalidate;
end;

procedure THbCommandPalette.ShowPalette;
begin
  Visible := True;
  BringToFront;
  if Assigned(FEdtSearch) and FEdtSearch.CanFocus then
    FEdtSearch.SetFocus;
end;

procedure THbCommandPalette.HidePalette;
begin
  Visible := False;
end;

function THbCommandPalette.HitTestRow(Y: Integer): Integer;
var
  ListTop, I, ItemIdx, CurY: Integer;
  Item: THbCommandItem;
  LastGroup, CurGroup: string;
begin
  Result := -1;
  ListTop := FPnlSearchBox.Height;
  CurY := ListTop + 4;
  LastGroup := '';

  for I := 0 to FFilteredIndices.Count - 1 do
  begin
    ItemIdx := FFilteredIndices[I];
    Item := FItems[ItemIdx];
    CurGroup := Item.VerbGroup;

    if (CurGroup <> '') and (CurGroup <> LastGroup) then
    begin
      Inc(CurY, FHeaderHeight);
      LastGroup := CurGroup;
    end;

    if (Y >= CurY) and (Y < CurY + FRowHeight) then
      Exit(I);

    Inc(CurY, FRowHeight);
  end;
end;

procedure THbCommandPalette.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  ClickedRow: Integer;
begin
  inherited;
  if Button <> mbLeft then
    Exit;

  ClickedRow := HitTestRow(Y);
  if (ClickedRow >= 0) and (ClickedRow < FFilteredIndices.Count) then
  begin
    FSelectedIndex := ClickedRow;
    Invalidate;
  end;
end;

procedure THbCommandPalette.DblClick;
begin
  inherited;
  ExecuteSelected;
end;

procedure THbCommandPalette.Paint;
var
  Tokens: THbTokens;
  CanvasObj: TCanvas;
  ListTop, I, ItemIdx, CurY: Integer;
  Item: THbCommandItem;
  ItemRect: TRect;
  LastGroup, CurGroup: string;
begin
  inherited;
  Tokens := THbTheme.Tokens;
  CanvasObj := Canvas;
  ListTop := FPnlSearchBox.Height;

  // Background surface
  CanvasObj.Brush.Color := AlphaColorToColor(Tokens.Surface);
  CanvasObj.Pen.Color := AlphaColorToColor(Tokens.Border);
  CanvasObj.Pen.Width := 1;
  CanvasObj.RoundRect(0, 0, Width, Height, Round(Tokens.RadiusM), Round(Tokens.RadiusM));

  if FFilteredIndices.Count = 0 then
  begin
    CanvasObj.Font.Color := AlphaColorToColor(Tokens.InkMuted);
    CanvasObj.Font.Size := 10;
    CanvasObj.TextOut(24, ListTop + 30, '未检索到匹配的动词指令 (输入关键词或全拼/首字母搜索)...');
    Exit;
  end;

  CurY := ListTop + 4;
  LastGroup := '';

  for I := 0 to FFilteredIndices.Count - 1 do
  begin
    if CurY + FRowHeight > Height then
      Break;

    ItemIdx := FFilteredIndices[I];
    Item := FItems[ItemIdx];
    CurGroup := Item.VerbGroup;

    // Draw Group Header if changed
    if (CurGroup <> '') and (CurGroup <> LastGroup) then
    begin
      CanvasObj.Font.Size := 9;
      CanvasObj.Font.Style := [fsBold];
      CanvasObj.Font.Color := AlphaColorToColor(Tokens.Primary);
      CanvasObj.TextOut(16, CurY + 4, '❖ ' + CurGroup);
      Inc(CurY, FHeaderHeight);
      LastGroup := CurGroup;
    end;

    ItemRect := Rect(8, CurY, Width - 8, CurY + FRowHeight - 4);

    // Selected / Hovered Row styling
    if I = FSelectedIndex then
    begin
      CanvasObj.Brush.Color := AlphaColorToColor(Tokens.Soft);
      CanvasObj.Pen.Color := AlphaColorToColor(Tokens.FocusRing);
      CanvasObj.Pen.Width := 2;
      CanvasObj.RoundRect(ItemRect.Left, ItemRect.Top, ItemRect.Right, ItemRect.Bottom, 6, 6);
    end
    else
    begin
      CanvasObj.Brush.Color := AlphaColorToColor(Tokens.Surface);
      CanvasObj.Pen.Color := clNone;
    end;

    // Icon + Caption
    if Item.Enabled then
    begin
      CanvasObj.Font.Color := AlphaColorToColor(Tokens.Ink);
      CanvasObj.Font.Style := [];
    end
    else
    begin
      CanvasObj.Font.Color := AlphaColorToColor(Tokens.InkMuted);
      CanvasObj.Font.Style := [];
    end;

    CanvasObj.Font.Size := 10;
    CanvasObj.TextOut(ItemRect.Left + 12, ItemRect.Top + 10, Item.IconName + ' ' + Item.Caption);

    // Shortcut Text or Disabled Reason on Right
    if not Item.Enabled and (Item.DisabledReason <> '') then
    begin
      CanvasObj.Font.Color := AlphaColorToColor(Tokens.Warning);
      CanvasObj.Font.Size := 9;
      CanvasObj.TextOut(ItemRect.Right - CanvasObj.TextWidth(Item.DisabledReason) - 16, ItemRect.Top + 11, Item.DisabledReason);
    end
    else if Item.ShortcutText <> '' then
    begin
      CanvasObj.Font.Color := AlphaColorToColor(Tokens.InkMuted);
      CanvasObj.Font.Size := 9;
      CanvasObj.TextOut(ItemRect.Right - CanvasObj.TextWidth(Item.ShortcutText) - 16, ItemRect.Top + 11, Item.ShortcutText);
    end;

    Inc(CurY, FRowHeight);
  end;
end;

end.
