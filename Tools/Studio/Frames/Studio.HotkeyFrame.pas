{ ============================================================================
  Studio.HotkeyFrame - Hotkey Editor Frame
  
  Version: 1.0
  Description: Visual editor for customizing application hotkeys.
               Provides category filtering, search, conflict detection,
               and reset functionality.
  ============================================================================ }

unit Studio.HotkeyFrame;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.UITypes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.Grids,
  Vcl.Menus,
  FireDAC.Comp.Client,
  UniBase.Types,
  UniBase.Hotkeys;

type
  TfraHotkey = class(TFrame)
    pnlToolbar: TPanel;
    edtSearch: TEdit;
    btnResetAll: TButton;
    lblSearch: TLabel;
    splSplitter: TSplitter;
    pnlLeft: TPanel;
    lblCategories: TLabel;
    lstCategories: TListBox;
    pnlRight: TPanel;
    grdHotkeys: TStringGrid;
    pnlStatus: TPanel;
    lblStatus: TLabel;
    btnResetSelected: TButton;
    procedure lstCategoriesClick(Sender: TObject);
    procedure edtSearchChange(Sender: TObject);
    procedure grdHotkeysSelectCell(Sender: TObject; ACol, ARow: Integer;
      var CanSelect: Boolean);
    procedure grdHotkeysKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure grdHotkeysDrawCell(Sender: TObject; ACol, ARow: Integer;
      Rect: TRect; State: TGridDrawState);
    procedure btnResetAllClick(Sender: TObject);
    procedure btnResetSelectedClick(Sender: TObject);
    procedure grdHotkeysDblClick(Sender: TObject);
  private
    FConnection: TFDConnection;
    FHotkeys: TUniBaseHotkeys;
    FAllHotkeys: THotkeyInfoArray;
    FFilteredHotkeys: THotkeyInfoArray;
    FCategories: TStringList;
    FEditingRow: Integer;
    FIsEditing: Boolean;
    
    procedure LoadCategories;
    procedure LoadHotkeys;
    procedure FilterHotkeys;
    procedure RefreshGrid;
    procedure SetStatus(const AText: string; AIsWarning: Boolean = False);
    procedure StartEditing(ARow: Integer);
    procedure StopEditing;
    procedure ApplyHotkey(ARow: Integer; AShortcut: TShortCut);
    function GetSelectedActionName: string;
    
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    procedure SetConnection(AConnection: TFDConnection);
    procedure RefreshData;
  end;

implementation

{$R *.dfm}

const
  COL_ACTION = 0;
  COL_SHORTCUT = 1;
  COL_DEFAULT = 2;
  COL_DESCRIPTION = 3;
  
  CATEGORY_ALL = '(All)';

{ TfraHotkey }

constructor TfraHotkey.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCategories := TStringList.Create;
  FCategories.Sorted := True;
  FCategories.Duplicates := dupIgnore;
  FEditingRow := -1;
  FIsEditing := False;
  
  // Initialize grid columns
  grdHotkeys.ColCount := 4;
  grdHotkeys.RowCount := 2;
  grdHotkeys.FixedRows := 1;
  grdHotkeys.Cells[COL_ACTION, 0] := 'Action';
  grdHotkeys.Cells[COL_SHORTCUT, 0] := 'Shortcut';
  grdHotkeys.Cells[COL_DEFAULT, 0] := 'Default';
  grdHotkeys.Cells[COL_DESCRIPTION, 0] := 'Description';
  
  // Set column widths
  grdHotkeys.ColWidths[COL_ACTION] := 150;
  grdHotkeys.ColWidths[COL_SHORTCUT] := 120;
  grdHotkeys.ColWidths[COL_DEFAULT] := 120;
  grdHotkeys.ColWidths[COL_DESCRIPTION] := 250;
  
  grdHotkeys.Options := grdHotkeys.Options + [goRowSelect] - [goEditing];
end;

destructor TfraHotkey.Destroy;
begin
  FCategories.Free;
  FHotkeys.Free;
  inherited;
end;

procedure TfraHotkey.SetConnection(AConnection: TFDConnection);
begin
  FConnection := AConnection;
  
  // Recreate hotkeys manager with new connection
  FreeAndNil(FHotkeys);
  if Assigned(FConnection) and FConnection.Connected then
    FHotkeys := TUniBaseHotkeys.Create(FConnection);
end;

procedure TfraHotkey.RefreshData;
begin
  if not Assigned(FHotkeys) then
  begin
    SetStatus('No database connection', True);
    Exit;
  end;
  
  LoadCategories;
  LoadHotkeys;
  FilterHotkeys;
  RefreshGrid;
  SetStatus('');
end;

procedure TfraHotkey.LoadCategories;
var
  I: Integer;
begin
  FCategories.Clear;
  FCategories.Add(CATEGORY_ALL);
  
  FAllHotkeys := FHotkeys.GetAllHotkeys;
  
  for I := 0 to High(FAllHotkeys) do
  begin
    if FAllHotkeys[I].Category <> '' then
      FCategories.Add(FAllHotkeys[I].Category);
  end;
  
  lstCategories.Items.Assign(FCategories);
  if lstCategories.Items.Count > 0 then
    lstCategories.ItemIndex := 0;
end;

procedure TfraHotkey.LoadHotkeys;
begin
  FAllHotkeys := FHotkeys.GetAllHotkeys;
end;

procedure TfraHotkey.FilterHotkeys;
var
  I: Integer;
  SelectedCategory: string;
  SearchText: string;
  List: TList<THotkeyInfo>;
  Hotkey: THotkeyInfo;
  Matches: Boolean;
begin
  // Get selected category
  if (lstCategories.ItemIndex >= 0) and (lstCategories.ItemIndex < lstCategories.Items.Count) then
    SelectedCategory := lstCategories.Items[lstCategories.ItemIndex]
  else
    SelectedCategory := CATEGORY_ALL;
    
  SearchText := LowerCase(Trim(edtSearch.Text));
  
  List := TList<THotkeyInfo>.Create;
  try
    for I := 0 to High(FAllHotkeys) do
    begin
      Hotkey := FAllHotkeys[I];
      
      // Category filter
      if (SelectedCategory <> CATEGORY_ALL) and 
         (Hotkey.Category <> SelectedCategory) then
        Continue;
      
      // Search filter
      if SearchText <> '' then
      begin
        Matches := 
          (Pos(SearchText, LowerCase(Hotkey.ActionName)) > 0) or
          (Pos(SearchText, LowerCase(Hotkey.Description)) > 0) or
          (Pos(SearchText, LowerCase(ShortCutToText(Hotkey.Shortcut))) > 0);
        if not Matches then
          Continue;
      end;
      
      List.Add(Hotkey);
    end;
    
    FFilteredHotkeys := List.ToArray;
  finally
    List.Free;
  end;
end;

procedure TfraHotkey.RefreshGrid;
var
  I: Integer;
  Hotkey: THotkeyInfo;
begin
  StopEditing;
  
  if Length(FFilteredHotkeys) = 0 then
  begin
    grdHotkeys.RowCount := 2;
    grdHotkeys.Cells[COL_ACTION, 1] := '';
    grdHotkeys.Cells[COL_SHORTCUT, 1] := '';
    grdHotkeys.Cells[COL_DEFAULT, 1] := '';
    grdHotkeys.Cells[COL_DESCRIPTION, 1] := '';
    Exit;
  end;
  
  grdHotkeys.RowCount := Length(FFilteredHotkeys) + 1;
  
  for I := 0 to High(FFilteredHotkeys) do
  begin
    Hotkey := FFilteredHotkeys[I];
    grdHotkeys.Cells[COL_ACTION, I + 1] := Hotkey.ActionName;
    grdHotkeys.Cells[COL_SHORTCUT, I + 1] := ShortCutToText(Hotkey.Shortcut);
    grdHotkeys.Cells[COL_DEFAULT, I + 1] := ShortCutToText(Hotkey.DefaultShortcut);
    grdHotkeys.Cells[COL_DESCRIPTION, I + 1] := Hotkey.Description;
  end;
end;

procedure TfraHotkey.SetStatus(const AText: string; AIsWarning: Boolean);
begin
  lblStatus.Caption := AText;
  if AIsWarning then
    lblStatus.Font.Color := clRed
  else
    lblStatus.Font.Color := clWindowText;
end;

procedure TfraHotkey.StartEditing(ARow: Integer);
begin
  if (ARow < 1) or (ARow > Length(FFilteredHotkeys)) then
    Exit;
    
  FEditingRow := ARow;
  FIsEditing := True;
  SetStatus('Press new shortcut key combination... (Escape to cancel)', False);
  grdHotkeys.Invalidate;
end;

procedure TfraHotkey.StopEditing;
begin
  FEditingRow := -1;
  FIsEditing := False;
  SetStatus('');
  grdHotkeys.Invalidate;
end;

procedure TfraHotkey.ApplyHotkey(ARow: Integer; AShortcut: TShortCut);
var
  ActionName: string;
  ConflictAction: string;
begin
  if (ARow < 1) or (ARow > Length(FFilteredHotkeys)) then
    Exit;
    
  ActionName := FFilteredHotkeys[ARow - 1].ActionName;
  
  // Check for conflict
  if AShortcut <> 0 then
  begin
    ConflictAction := FHotkeys.CheckHotkeyConflict(AShortcut, ActionName);
    if ConflictAction <> '' then
    begin
      if MessageDlg(
        Format('Shortcut "%s" is already assigned to "%s".'#13#10 +
               'Do you want to reassign it?', 
               [ShortCutToText(AShortcut), ConflictAction]),
        mtWarning, [mbYes, mbNo], 0) <> mrYes then
      begin
        SetStatus(Format('Conflict: %s is used by %s', [ShortCutToText(AShortcut), ConflictAction]), True);
        Exit;
      end;
      
      // Clear the conflicting hotkey
      FHotkeys.SetHotkey(ConflictAction, 0);
    end;
  end;
  
  // Apply the new hotkey
  FHotkeys.SetHotkey(ActionName, AShortcut);
  
  // Refresh display
  LoadHotkeys;
  FilterHotkeys;
  RefreshGrid;
  
  if AShortcut = 0 then
    SetStatus(Format('Cleared hotkey for %s', [ActionName]), False)
  else
    SetStatus(Format('Set %s to %s', [ActionName, ShortCutToText(AShortcut)]), False);
end;

function TfraHotkey.GetSelectedActionName: string;
var
  Row: Integer;
begin
  Result := '';
  Row := grdHotkeys.Row;
  if (Row >= 1) and (Row <= Length(FFilteredHotkeys)) then
    Result := FFilteredHotkeys[Row - 1].ActionName;
end;

procedure TfraHotkey.lstCategoriesClick(Sender: TObject);
begin
  FilterHotkeys;
  RefreshGrid;
end;

procedure TfraHotkey.edtSearchChange(Sender: TObject);
begin
  FilterHotkeys;
  RefreshGrid;
end;

procedure TfraHotkey.grdHotkeysSelectCell(Sender: TObject; ACol, ARow: Integer;
  var CanSelect: Boolean);
begin
  CanSelect := True;
  if FIsEditing and (ARow <> FEditingRow) then
    StopEditing;
end;

procedure TfraHotkey.grdHotkeysKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
  NewShortcut: TShortCut;
begin
  if not FIsEditing then
  begin
    // Enter or F2 starts editing
    if Key in [VK_RETURN, VK_F2] then
    begin
      StartEditing(grdHotkeys.Row);
      Key := 0;
    end
    // Delete clears hotkey
    else if Key = VK_DELETE then
    begin
      if grdHotkeys.Row >= 1 then
        ApplyHotkey(grdHotkeys.Row, 0);
      Key := 0;
    end;
    Exit;
  end;
  
  // In editing mode
  if Key = VK_ESCAPE then
  begin
    StopEditing;
    Key := 0;
    Exit;
  end;
  
  // Ignore modifier-only keys
  if Key in [VK_SHIFT, VK_CONTROL, VK_MENU, VK_LWIN, VK_RWIN] then
    Exit;
  
  // Build shortcut from key + modifiers
  NewShortcut := ShortCut(Key, Shift);
  
  if NewShortcut <> 0 then
  begin
    ApplyHotkey(FEditingRow, NewShortcut);
    StopEditing;
  end;
  
  Key := 0;
end;

procedure TfraHotkey.grdHotkeysDrawCell(Sender: TObject; ACol, ARow: Integer;
  Rect: TRect; State: TGridDrawState);
var
  Canvas: TCanvas;
  Text: string;
  IsCustomized: Boolean;
  TextRect: TRect;
begin
  Canvas := grdHotkeys.Canvas;
  Text := grdHotkeys.Cells[ACol, ARow];
  
  // Header row
  if ARow = 0 then
  begin
    Canvas.Brush.Color := clBtnFace;
    Canvas.Font.Style := [fsBold];
  end
  // Editing row
  else if FIsEditing and (ARow = FEditingRow) then
  begin
    Canvas.Brush.Color := $00E0FFFF; // Light yellow
    Canvas.Font.Style := [];
  end
  // Check if customized
  else if (ARow >= 1) and (ARow <= Length(FFilteredHotkeys)) then
  begin
    IsCustomized := FFilteredHotkeys[ARow - 1].IsCustomized;
    if IsCustomized then
    begin
      Canvas.Font.Style := [fsBold];
      if ACol = COL_SHORTCUT then
        Canvas.Font.Color := clBlue;
    end
    else
    begin
      Canvas.Font.Style := [];
      Canvas.Font.Color := clWindowText;
    end;
    
    if gdSelected in State then
      Canvas.Brush.Color := clHighlight
    else
      Canvas.Brush.Color := clWindow;
  end
  else
  begin
    Canvas.Brush.Color := clWindow;
    Canvas.Font.Style := [];
  end;
  
  Canvas.FillRect(Rect);
  
  TextRect := Rect;
  InflateRect(TextRect, -2, -2);
  
  if gdSelected in State then
    Canvas.Font.Color := clHighlightText
  else if (ARow >= 1) and (ARow <= Length(FFilteredHotkeys)) and 
          FFilteredHotkeys[ARow - 1].IsCustomized and (ACol = COL_SHORTCUT) then
    Canvas.Font.Color := clBlue;
    
  DrawText(Canvas.Handle, PChar(Text), Length(Text), TextRect, 
    DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_END_ELLIPSIS);
end;

procedure TfraHotkey.grdHotkeysDblClick(Sender: TObject);
begin
  if grdHotkeys.Row >= 1 then
    StartEditing(grdHotkeys.Row);
end;

procedure TfraHotkey.btnResetAllClick(Sender: TObject);
begin
  if not Assigned(FHotkeys) then
    Exit;
    
  if MessageDlg('Reset all hotkeys to their default values?', 
    mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    FHotkeys.ResetAllHotkeys;
    RefreshData;
    SetStatus('All hotkeys reset to defaults', False);
  end;
end;

procedure TfraHotkey.btnResetSelectedClick(Sender: TObject);
var
  ActionName: string;
begin
  if not Assigned(FHotkeys) then
    Exit;
    
  ActionName := GetSelectedActionName;
  if ActionName = '' then
  begin
    SetStatus('No hotkey selected', True);
    Exit;
  end;
  
  FHotkeys.ResetHotkey(ActionName);
  LoadHotkeys;
  FilterHotkeys;
  RefreshGrid;
  SetStatus(Format('Reset %s to default', [ActionName]), False);
end;

end.
