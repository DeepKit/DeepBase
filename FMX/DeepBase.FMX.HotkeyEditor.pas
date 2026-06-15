{ ============================================================================
  DeepBase.FMX.HotkeyEditor - FMX Hotkey Editor

  Version: 1.0
  Description: Reusable FMX hotkey editor with search, category filtering,
               conflict-aware shortcut editing, reset, and JSON import/export.
  ============================================================================ }

unit DeepBase.FMX.HotkeyEditor;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Math,
  System.UITypes,
  System.Generics.Collections,
  FMX.Types,
  FMX.Controls,
  FMX.Controls.Presentation,
  FMX.StdCtrls,
  FMX.Edit,
  FMX.ListBox,
  FMX.Layouts,
  FMX.Grid,
  FMX.Grid.Style,
  FMX.Dialogs,
  DeepBase.Hotkeys,
  DeepBase.Hotkeys.Exchange;

type
  TFMXHotkeyEditor = class(TLayout)
  private
    FConnection: TComponent;
    FHotkeys: TDeepBaseHotkeys;
    FAllHotkeys: THotkeyInfoArray;
    FFilteredHotkeys: THotkeyInfoArray;
    FCategories: TStringList;
    FEditingRow: Integer;
    FIsEditing: Boolean;
    FOnHotkeysChanged: TNotifyEvent;

    FToolbar: TLayout;
    FSearchLabel: TLabel;
    FSearchEdit: TEdit;
    FBtnExport: TButton;
    FBtnImport: TButton;
    FBtnResetSelected: TButton;
    FBtnResetAll: TButton;

    FLeftPanel: TLayout;
    FCategoryLabel: TLabel;
    FCategoryList: TListBox;

    FGrid: TStringGrid;
    FStatusPanel: TLayout;
    FStatusLabel: TLabel;

    procedure CreateControls;
    procedure LayoutControls;
    procedure SetStatus(const AText: string; AIsWarning: Boolean = False);

    procedure LoadCategories;
    procedure LoadHotkeys;
    procedure FilterHotkeys;
    procedure RefreshGrid;
    procedure RefreshAll;

    procedure StartEditing(ARow: Integer);
    procedure StopEditing;
    procedure ApplyHotkey(ARow: Integer; AShortcut: TShortCut);
    function GetSelectedActionName: string;
    function BuildShortcutFromKey(AKey: Word; AShift: TShiftState): TShortCut;
    procedure NotifyHotkeysChanged;

    procedure SearchChanged(Sender: TObject);
    procedure CategoryChanged(Sender: TObject);
    procedure GridKeyDown(Sender: TObject; var Key: Word; var KeyChar: Char;
      Shift: TShiftState);
    procedure GridDblClick(Sender: TObject);
    procedure ResetAllClick(Sender: TObject);
    procedure ResetSelectedClick(Sender: TObject);
    procedure ExportClick(Sender: TObject);
    procedure ImportClick(Sender: TObject);

    procedure SetConnection(Value: TComponent);
  protected
    procedure Loaded; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure RefreshData;
  published
    property Connection: TComponent read FConnection write SetConnection;
    property OnHotkeysChanged: TNotifyEvent read FOnHotkeysChanged write FOnHotkeysChanged;
  end;

procedure Register;

implementation

const
  COL_ACTION = 0;
  COL_SHORTCUT = 1;
  COL_DEFAULT = 2;
  COL_DESCRIPTION = 3;
  CATEGORY_ALL = '(All)';

procedure Register;
begin
  RegisterComponents('DeepBase FMX', [TFMXHotkeyEditor]);
end;

{ TFMXHotkeyEditor }

constructor TFMXHotkeyEditor.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 760;
  Height := 500;

  FCategories := TStringList.Create;
  FCategories.Sorted := True;
  FCategories.Duplicates := dupIgnore;
  FEditingRow := -1;
  FIsEditing := False;

  CreateControls;
end;

destructor TFMXHotkeyEditor.Destroy;
begin
  FreeAndNil(FHotkeys);
  FreeAndNil(FCategories);
  inherited;
end;

procedure TFMXHotkeyEditor.CreateControls;
begin
  FToolbar := TLayout.Create(Self);
  FToolbar.Parent := Self;
  FToolbar.Align := TAlignLayout.Top;
  FToolbar.Height := 44;

  FSearchLabel := TLabel.Create(Self);
  FSearchLabel.Parent := FToolbar;
  FSearchLabel.Text := 'Search:';
  FSearchLabel.Height := 24;

  FSearchEdit := TEdit.Create(Self);
  FSearchEdit.Parent := FToolbar;
  FSearchEdit.Height := 28;
  FSearchEdit.OnChange := SearchChanged;

  FBtnResetAll := TButton.Create(Self);
  FBtnResetAll.Parent := FToolbar;
  FBtnResetAll.Text := 'Reset All';
  FBtnResetAll.Height := 28;
  FBtnResetAll.OnClick := ResetAllClick;

  FBtnResetSelected := TButton.Create(Self);
  FBtnResetSelected.Parent := FToolbar;
  FBtnResetSelected.Text := 'Reset Selected';
  FBtnResetSelected.Height := 28;
  FBtnResetSelected.OnClick := ResetSelectedClick;

  FBtnImport := TButton.Create(Self);
  FBtnImport.Parent := FToolbar;
  FBtnImport.Text := 'Import...';
  FBtnImport.Height := 28;
  FBtnImport.OnClick := ImportClick;

  FBtnExport := TButton.Create(Self);
  FBtnExport.Parent := FToolbar;
  FBtnExport.Text := 'Export...';
  FBtnExport.Height := 28;
  FBtnExport.OnClick := ExportClick;

  FLeftPanel := TLayout.Create(Self);
  FLeftPanel.Parent := Self;
  FLeftPanel.Align := TAlignLayout.Left;
  FLeftPanel.Width := 170;
  FLeftPanel.Padding.Top := 4;

  FCategoryLabel := TLabel.Create(Self);
  FCategoryLabel.Parent := FLeftPanel;
  FCategoryLabel.Align := TAlignLayout.Top;
  FCategoryLabel.Height := 20;
  FCategoryLabel.Text := 'Categories:';

  FCategoryList := TListBox.Create(Self);
  FCategoryList.Parent := FLeftPanel;
  FCategoryList.Align := TAlignLayout.Client;
  FCategoryList.OnChange := CategoryChanged;

  FGrid := TStringGrid.Create(Self);
  FGrid.Parent := Self;
  FGrid.Align := TAlignLayout.Client;
  FGrid.ReadOnly := True;
  FGrid.RowCount := 1;
  FGrid.Options := FGrid.Options + [TGridOption.RowSelect];
  FGrid.OnKeyDown := GridKeyDown;
  FGrid.OnDblClick := GridDblClick;

  with TStringColumn.Create(FGrid) do
  begin
    Parent := FGrid;
    Header := 'Action';
    Width := 180;
  end;

  with TStringColumn.Create(FGrid) do
  begin
    Parent := FGrid;
    Header := 'Shortcut';
    Width := 140;
  end;

  with TStringColumn.Create(FGrid) do
  begin
    Parent := FGrid;
    Header := 'Default';
    Width := 140;
  end;

  with TStringColumn.Create(FGrid) do
  begin
    Parent := FGrid;
    Header := 'Description';
    Width := 320;
  end;

  FStatusPanel := TLayout.Create(Self);
  FStatusPanel.Parent := Self;
  FStatusPanel.Align := TAlignLayout.Bottom;
  FStatusPanel.Height := 28;
  FStatusPanel.Padding.Left := 8;

  FStatusLabel := TLabel.Create(Self);
  FStatusLabel.Parent := FStatusPanel;
  FStatusLabel.Align := TAlignLayout.Client;
  FStatusLabel.Text := '';

  LayoutControls;
end;

procedure TFMXHotkeyEditor.Loaded;
begin
  inherited;
  LayoutControls;
end;

procedure TFMXHotkeyEditor.Resize;
begin
  inherited;
  LayoutControls;
end;

procedure TFMXHotkeyEditor.LayoutControls;
const
  BTN_WIDTH = 110;
  BTN_GAP = 8;
  LEFT_PAD = 10;
  TOP_PAD = 8;
var
  RightX: Single;
begin
  if not Assigned(FToolbar) then
    Exit;

  RightX := FToolbar.Width - LEFT_PAD;

  FBtnResetAll.Width := BTN_WIDTH;
  FBtnResetAll.Position.X := RightX - BTN_WIDTH;
  FBtnResetAll.Position.Y := TOP_PAD;
  RightX := FBtnResetAll.Position.X - BTN_GAP;

  FBtnResetSelected.Width := BTN_WIDTH;
  FBtnResetSelected.Position.X := RightX - BTN_WIDTH;
  FBtnResetSelected.Position.Y := TOP_PAD;
  RightX := FBtnResetSelected.Position.X - BTN_GAP;

  FBtnImport.Width := BTN_WIDTH;
  FBtnImport.Position.X := RightX - BTN_WIDTH;
  FBtnImport.Position.Y := TOP_PAD;
  RightX := FBtnImport.Position.X - BTN_GAP;

  FBtnExport.Width := BTN_WIDTH;
  FBtnExport.Position.X := RightX - BTN_WIDTH;
  FBtnExport.Position.Y := TOP_PAD;

  FSearchLabel.Position.X := LEFT_PAD;
  FSearchLabel.Position.Y := TOP_PAD + 3;
  FSearchEdit.Position.X := 60;
  FSearchEdit.Position.Y := TOP_PAD;
  FSearchEdit.Width := Max(120, FBtnExport.Position.X - FSearchEdit.Position.X - BTN_GAP);
end;

procedure TFMXHotkeyEditor.SetConnection(Value: TComponent);
begin
  if FConnection = Value then
    Exit;

  FConnection := Value;
  FreeAndNil(FHotkeys);
  if Assigned(FConnection) then
    FHotkeys := TDeepBaseHotkeys.Create(FConnection);

  RefreshData;
end;

procedure TFMXHotkeyEditor.SetStatus(const AText: string; AIsWarning: Boolean);
begin
  FStatusLabel.Text := AText;
  if AIsWarning then
    FStatusLabel.TextSettings.FontColor := TAlphaColorRec.Red
  else
    FStatusLabel.TextSettings.FontColor := TAlphaColorRec.Black;
end;

procedure TFMXHotkeyEditor.RefreshData;
begin
  if not Assigned(FHotkeys) then
  begin
    FAllHotkeys := nil;
    FFilteredHotkeys := nil;
    FCategories.Clear;
    FCategoryList.Items.Clear;
    RefreshGrid;
    SetStatus('No database connection', True);
    Exit;
  end;

  LoadCategories;
  LoadHotkeys;
  FilterHotkeys;
  RefreshGrid;
  SetStatus('');
end;

procedure TFMXHotkeyEditor.RefreshAll;
begin
  LoadHotkeys;
  FilterHotkeys;
  RefreshGrid;
end;

procedure TFMXHotkeyEditor.LoadCategories;
var
  I: Integer;
begin
  FCategories.Clear;
  FCategories.Add(CATEGORY_ALL);

  FAllHotkeys := FHotkeys.GetAllHotkeys;
  for I := 0 to High(FAllHotkeys) do
    if FAllHotkeys[I].Category <> '' then
      FCategories.Add(FAllHotkeys[I].Category);

  FCategoryList.Items.Clear;
  for I := 0 to FCategories.Count - 1 do
    FCategoryList.Items.Add(FCategories[I]);

  if FCategoryList.Items.Count > 0 then
    FCategoryList.ItemIndex := 0
  else
    FCategoryList.ItemIndex := -1;
end;

procedure TFMXHotkeyEditor.LoadHotkeys;
begin
  if not Assigned(FHotkeys) then
    Exit;
  FAllHotkeys := FHotkeys.GetAllHotkeys;
end;

procedure TFMXHotkeyEditor.FilterHotkeys;
var
  I: Integer;
  SelectedCategory: string;
  SearchText: string;
  Items: TList<THotkeyInfo>;
  Hotkey: THotkeyInfo;
begin
  if (FCategoryList.ItemIndex >= 0) and
     (FCategoryList.ItemIndex < FCategoryList.Items.Count) then
    SelectedCategory := FCategoryList.Items[FCategoryList.ItemIndex]
  else
    SelectedCategory := CATEGORY_ALL;

  SearchText := Trim(LowerCase(FSearchEdit.Text));

  Items := TList<THotkeyInfo>.Create;
  try
    for I := 0 to High(FAllHotkeys) do
    begin
      Hotkey := FAllHotkeys[I];

      if (SelectedCategory <> CATEGORY_ALL) and
         (Hotkey.Category <> SelectedCategory) then
        Continue;

      if SearchText <> '' then
      begin
        if (Pos(SearchText, LowerCase(Hotkey.ActionName)) = 0) and
           (Pos(SearchText, LowerCase(Hotkey.Description)) = 0) and
           (Pos(SearchText, LowerCase(DeepBaseShortCutToText(Hotkey.Shortcut))) = 0) then
          Continue;
      end;

      Items.Add(Hotkey);
    end;

    FFilteredHotkeys := Items.ToArray;
  finally
    Items.Free;
  end;
end;

procedure TFMXHotkeyEditor.RefreshGrid;
var
  I: Integer;
begin
  StopEditing;

  if Length(FFilteredHotkeys) = 0 then
  begin
    FGrid.RowCount := 1;
    FGrid.Cells[COL_ACTION, 0] := '';
    FGrid.Cells[COL_SHORTCUT, 0] := '';
    FGrid.Cells[COL_DEFAULT, 0] := '';
    FGrid.Cells[COL_DESCRIPTION, 0] := '';
    FGrid.Row := 0;
    Exit;
  end;

  FGrid.RowCount := Length(FFilteredHotkeys);
  for I := 0 to High(FFilteredHotkeys) do
  begin
    FGrid.Cells[COL_ACTION, I] := FFilteredHotkeys[I].ActionName;
    FGrid.Cells[COL_SHORTCUT, I] := DeepBaseShortCutToText(FFilteredHotkeys[I].Shortcut);
    FGrid.Cells[COL_DEFAULT, I] := DeepBaseShortCutToText(FFilteredHotkeys[I].DefaultShortcut);
    FGrid.Cells[COL_DESCRIPTION, I] := FFilteredHotkeys[I].Description;
  end;

  if FGrid.Row >= FGrid.RowCount then
    FGrid.Row := FGrid.RowCount - 1;
end;

procedure TFMXHotkeyEditor.StartEditing(ARow: Integer);
begin
  if (ARow < 0) or (ARow >= Length(FFilteredHotkeys)) then
    Exit;

  FEditingRow := ARow;
  FIsEditing := True;
  SetStatus('Press new shortcut key combination... (Escape to cancel)');
end;

procedure TFMXHotkeyEditor.StopEditing;
begin
  FEditingRow := -1;
  FIsEditing := False;
  SetStatus('');
end;

function TFMXHotkeyEditor.GetSelectedActionName: string;
var
  Row: Integer;
begin
  Result := '';
  Row := FGrid.Row;
  if (Row >= 0) and (Row < Length(FFilteredHotkeys)) then
    Result := FFilteredHotkeys[Row].ActionName;
end;

function TFMXHotkeyEditor.BuildShortcutFromKey(AKey: Word;
  AShift: TShiftState): TShortCut;
begin
  Result := AKey;
  if ssCtrl in AShift then
    Result := Result or scCtrl;
  if ssShift in AShift then
    Result := Result or scShift;
  if ssAlt in AShift then
    Result := Result or scAlt;
end;

procedure TFMXHotkeyEditor.ApplyHotkey(ARow: Integer; AShortcut: TShortCut);
var
  ActionName: string;
  ConflictAction: string;
begin
  if not Assigned(FHotkeys) then
    Exit;
  if (ARow < 0) or (ARow >= Length(FFilteredHotkeys)) then
    Exit;

  ActionName := FFilteredHotkeys[ARow].ActionName;

  if AShortcut <> 0 then
  begin
    ConflictAction := FHotkeys.CheckHotkeyConflict(AShortcut, ActionName);
    if ConflictAction <> '' then
    begin
      if MessageDlg(
        Format('Shortcut "%s" is already assigned to "%s".'#13#10 +
               'Do you want to reassign it?',
               [DeepBaseShortCutToText(AShortcut), ConflictAction]),
        TMsgDlgType.mtWarning,
        [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo],
        0) <> mrYes then
      begin
        SetStatus(Format('Conflict: %s is used by %s',
          [DeepBaseShortCutToText(AShortcut), ConflictAction]), True);
        Exit;
      end;

      FHotkeys.SetHotkey(ConflictAction, 0);
    end;
  end;

  FHotkeys.SetHotkey(ActionName, AShortcut);
  RefreshAll;

  if AShortcut = 0 then
    SetStatus(Format('Cleared hotkey for %s', [ActionName]))
  else
    SetStatus(Format('Set %s to %s',
      [ActionName, DeepBaseShortCutToText(AShortcut)]));

  NotifyHotkeysChanged;
end;

procedure TFMXHotkeyEditor.NotifyHotkeysChanged;
begin
  if Assigned(FOnHotkeysChanged) then
    FOnHotkeysChanged(Self);
end;

procedure TFMXHotkeyEditor.SearchChanged(Sender: TObject);
begin
  FilterHotkeys;
  RefreshGrid;
end;

procedure TFMXHotkeyEditor.CategoryChanged(Sender: TObject);
begin
  FilterHotkeys;
  RefreshGrid;
end;

procedure TFMXHotkeyEditor.GridDblClick(Sender: TObject);
begin
  StartEditing(FGrid.Row);
end;

procedure TFMXHotkeyEditor.GridKeyDown(Sender: TObject; var Key: Word;
  var KeyChar: Char; Shift: TShiftState);
var
  Shortcut: TShortCut;
begin
  if not FIsEditing then
  begin
    if Key in [vkReturn, vkF2] then
    begin
      StartEditing(FGrid.Row);
      Key := 0;
      KeyChar := #0;
      Exit;
    end;

    if Key = vkDelete then
    begin
      ApplyHotkey(FGrid.Row, 0);
      Key := 0;
      KeyChar := #0;
      Exit;
    end;

    Exit;
  end;

  if Key = vkEscape then
  begin
    StopEditing;
    Key := 0;
    KeyChar := #0;
    Exit;
  end;

  if Key in [vkShift, vkControl, vkMenu] then
    Exit;

  Shortcut := BuildShortcutFromKey(Key, Shift);
  if Shortcut <> 0 then
  begin
    ApplyHotkey(FEditingRow, Shortcut);
    StopEditing;
  end;

  Key := 0;
  KeyChar := #0;
end;

procedure TFMXHotkeyEditor.ResetAllClick(Sender: TObject);
begin
  if not Assigned(FHotkeys) then
    Exit;

  if MessageDlg('Reset all hotkeys to their default values?',
      TMsgDlgType.mtConfirmation,
      [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo],
      0) = mrYes then
  begin
    FHotkeys.ResetAllHotkeys;
    RefreshAll;
    SetStatus('All hotkeys reset to defaults');
    NotifyHotkeysChanged;
  end;
end;

procedure TFMXHotkeyEditor.ResetSelectedClick(Sender: TObject);
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
  RefreshAll;
  SetStatus(Format('Reset %s to default', [ActionName]));
  NotifyHotkeysChanged;
end;

procedure TFMXHotkeyEditor.ExportClick(Sender: TObject);
var
  SaveDialog: TSaveDialog;
begin
  if not Assigned(FHotkeys) then
    Exit;

  SaveDialog := TSaveDialog.Create(nil);
  try
    SaveDialog.Filter := 'JSON Files (*.json)|*.json|All Files (*.*)|*.*';
    SaveDialog.DefaultExt := 'json';
    SaveDialog.FileName := 'deepbase-hotkeys.json';
    if not SaveDialog.Execute then
      Exit;

    TDeepBaseHotkeyExchange.ExportToFile(FHotkeys, SaveDialog.FileName);
    SetStatus(Format('Exported hotkeys to %s', [SaveDialog.FileName]));
  except
    on E: Exception do
      SetStatus('Export failed: ' + E.Message, True);
  end;
  SaveDialog.Free;
end;

procedure TFMXHotkeyEditor.ImportClick(Sender: TObject);
var
  OpenDialog: TOpenDialog;
  ConflictChoice: Integer;
  ConflictMode: THotkeyImportConflictMode;
  ImportedCount: Integer;
begin
  if not Assigned(FHotkeys) then
    Exit;

  OpenDialog := TOpenDialog.Create(nil);
  try
    OpenDialog.Filter := 'JSON Files (*.json)|*.json|All Files (*.*)|*.*';
    if not OpenDialog.Execute then
      Exit;

    ConflictChoice := MessageDlg(
      'If imported hotkeys conflict with existing assignments:'#13#10 +
      'Yes = overwrite existing assignment'#13#10 +
      'No = keep existing assignment and skip imported item'#13#10 +
      'Cancel = abort import',
      TMsgDlgType.mtConfirmation,
      [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo, TMsgDlgBtn.mbCancel],
      0);
    if ConflictChoice = mrCancel then
      Exit;

    if ConflictChoice = mrYes then
      ConflictMode := hicmOverwriteConflict
    else
      ConflictMode := hicmKeepConflict;

    ImportedCount := TDeepBaseHotkeyExchange.ImportFromFile(
      FHotkeys, OpenDialog.FileName, ConflictMode);

    RefreshAll;
    SetStatus(Format('Imported %d hotkeys from %s',
      [ImportedCount, OpenDialog.FileName]));
    NotifyHotkeysChanged;
  except
    on E: Exception do
      SetStatus('Import failed: ' + E.Message, True);
  end;
  OpenDialog.Free;
end;

end.
