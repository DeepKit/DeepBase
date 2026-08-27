{ ============================================================================
  DeepBase.FMX.HB.CommandPalette - Universal Command Palette for FMX
  
  Version: 1.0 (Delphi 13.1 on Win64 / Cross-Platform FMX)
  Description: Cross-platform FMX twin implementation of THbCommandPalette:
               - THbFmxControl vector rendering pipeline
               - Fuzzy search & filter matching
               - Full keyboard navigation & execute event
  ============================================================================ }

unit DeepBase.FMX.HB.CommandPalette;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
  System.Math,
  System.Generics.Collections,
  FMX.Types,
  FMX.Controls,
  FMX.Graphics,
  FMX.Layouts,
  FMX.Objects,
  DeepBase.HB.Core,
  DeepBase.HB.CommandPalette.Types,
  DeepBase.FMX.HB.Theme,
  DeepBase.FMX.HB.Controls;

type
  /// <summary>
  /// THbCommandPalette (FMX): Universal Ctrl+K command palette for FMX.
  /// </summary>
  THbCommandPalette = class(THbFmxControl)
  private
    FItems: TList<THbCommandItem>;
    FFilteredIndices: TList<Integer>;
    FSelectedIndex: Integer;
    FSearchText: string;
    FOnCommandExecute: THbCommandExecuteEvent;

    function GetFilteredCount: Integer;
    procedure SetSearchText(const Value: string);
    procedure RebuildFilteredList;
    function MatchFuzzy(const AQuery, ATarget: string): Boolean;
  protected
    procedure DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure AddCommand(const ACommandID, ACaption, AVerbGroup, AShortcut, AIcon: string;
      AEnabled: Boolean = True; const ADisabledReason: string = '');
    procedure ClearCommands;
    procedure SelectNext;
    procedure SelectPrev;
    procedure ExecuteSelected;

    property Items: TList<THbCommandItem> read FItems;
    property SelectedIndex: Integer read FSelectedIndex write FSelectedIndex;
    property SearchText: string read FSearchText write SetSearchText;
    property FilteredCount: Integer read GetFilteredCount;
  published
    property Align;
    property OnCommandExecute: THbCommandExecuteEvent read FOnCommandExecute write FOnCommandExecute;
  end;

implementation

{ THbCommandPalette }

constructor THbCommandPalette.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 600;
  Height := 420;
  FItems := TList<THbCommandItem>.Create;
  FFilteredIndices := TList<Integer>.Create;
  FSelectedIndex := 0;
  FSearchText := '';
end;

destructor THbCommandPalette.Destroy;
begin
  FItems.Free;
  FFilteredIndices.Free;
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

  if FSelectedIndex >= FFilteredIndices.Count then
    FSelectedIndex := Max(0, FFilteredIndices.Count - 1);
end;

procedure THbCommandPalette.SetSearchText(const Value: string);
begin
  if FSearchText <> Value then
  begin
    FSearchText := Value;
    RebuildFilteredList;
    Repaint;
  end;
end;

procedure THbCommandPalette.SelectNext;
begin
  if FFilteredIndices.Count > 0 then
  begin
    FSelectedIndex := (FSelectedIndex + 1) mod FFilteredIndices.Count;
    Repaint;
  end;
end;

procedure THbCommandPalette.SelectPrev;
begin
  if FFilteredIndices.Count > 0 then
  begin
    FSelectedIndex := (FSelectedIndex - 1 + FFilteredIndices.Count) mod FFilteredIndices.Count;
    Repaint;
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
  Item.LastUsedAt := Now;
  Item.Payload := '';
  FItems.Add(Item);
  RebuildFilteredList;
  Repaint;
end;

procedure THbCommandPalette.ClearCommands;
begin
  FItems.Clear;
  FFilteredIndices.Clear;
  FSelectedIndex := 0;
  Repaint;
end;

procedure THbCommandPalette.ExecuteSelected;
var
  ItemIndex: Integer;
begin
  if (FSelectedIndex >= 0) and (FSelectedIndex < FFilteredIndices.Count) then
  begin
    ItemIndex := FFilteredIndices[FSelectedIndex];
    if Assigned(FOnCommandExecute) and FItems[ItemIndex].Enabled then
      FOnCommandExecute(Self, FItems[ItemIndex]);
  end;
end;

procedure THbCommandPalette.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  ClickedRow: Integer;
begin
  inherited;
  if Button <> TMouseButton.mbLeft then
    Exit;

  if (Y >= 48.0) and (FFilteredIndices.Count > 0) then
  begin
    ClickedRow := Trunc((Y - 48.0) / 40.0);
    if (ClickedRow >= 0) and (ClickedRow < FFilteredIndices.Count) then
    begin
      FSelectedIndex := ClickedRow;
      Repaint;
      ExecuteSelected;
    end;
  end;
end;

procedure THbCommandPalette.DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens);
var
  R, RowRect: TRectF;
  I, ItemIdx: Integer;
  CurY: Single;
  Item: THbCommandItem;
begin
  // Background Surface
  Canvas.Fill.Color := Tokens.Surface;
  Canvas.Fill.Kind := TBrushKind.Solid;
  Canvas.FillRect(ARect, Tokens.RadiusM, Tokens.RadiusM, AllCorners, 1.0);

  // Search Box Header
  R := RectF(ARect.Left, ARect.Top, ARect.Right, ARect.Top + 44.0);
  Canvas.Fill.Color := Tokens.SurfaceAlt;
  Canvas.FillRect(R, Tokens.RadiusM, Tokens.RadiusM, [TCorner.TopLeft, TCorner.TopRight], 1.0);

  Canvas.Fill.Color := Tokens.Ink;
  Canvas.Font.Size := 13;
  Canvas.Font.Family := Tokens.FontFamily;
  if FSearchText <> '' then
    Canvas.FillText(RectF(R.Left + 16, R.Top + 10, R.Right - 16, R.Top + 34), FSearchText, False, 1.0, [], TTextAlign.Leading)
  else
    Canvas.FillText(RectF(R.Left + 16, R.Top + 10, R.Right - 16, R.Top + 34), '🔍 输入关键词搜索动词指令...', False, 0.6, [], TTextAlign.Leading);

  CurY := ARect.Top + 48.0;
  for I := 0 to FFilteredIndices.Count - 1 do
  begin
    if CurY + 38.0 > ARect.Bottom then
      Break;

    ItemIdx := FFilteredIndices[I];
    Item := FItems[ItemIdx];

    RowRect := RectF(ARect.Left + 6.0, CurY, ARect.Right - 6.0, CurY + 36.0);
    if I = FSelectedIndex then
    begin
      Canvas.Fill.Color := Tokens.Soft;
      Canvas.FillRect(RowRect, Tokens.RadiusS, Tokens.RadiusS, AllCorners, 1.0);
    end;

    // Caption
    if Item.Enabled then
      Canvas.Fill.Color := Tokens.Ink
    else
      Canvas.Fill.Color := Tokens.InkMuted;

    Canvas.Font.Size := 12;
    Canvas.FillText(RectF(RowRect.Left + 12, RowRect.Top + 8, RowRect.Right - 80, RowRect.Top + 28),
      Item.IconName + ' ' + Item.Caption, False, 1.0, [], TTextAlign.Leading);

    // Shortcut
    if Item.ShortcutText <> '' then
    begin
      Canvas.Fill.Color := Tokens.InkMuted;
      Canvas.Font.Size := 10;
      Canvas.FillText(RectF(RowRect.Right - 100, RowRect.Top + 8, RowRect.Right - 12, RowRect.Top + 28),
        Item.ShortcutText, False, 1.0, [], TTextAlign.Trailing);
    end;

    CurY := CurY + 40.0;
  end;
end;

end.
