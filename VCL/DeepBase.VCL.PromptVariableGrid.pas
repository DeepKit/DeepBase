{ ============================================================================
  DeepBase.VCL.PromptVariableGrid - Custom Variable Grid Control
  
  Version: 1.0
  Description: Self-drawn grid for editing prompt variables
  Features:
    - 7 variable types support (string/number/boolean/date/datetime/list/json)
    - Type-specific inline editors
    - Color-coded type indicators
    - Add/Delete row support
    - Validation feedback
  ============================================================================ }

unit DeepBase.VCL.PromptVariableGrid;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
  System.Variants,
  System.Generics.Collections,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Grids,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  DeepBase.LLM.Manager;

type
  // Type alias for compatibility
  TPromptVarType = TPromptVariableType;
  
  TPromptVariableGrid = class;
  
  /// <summary>
  /// Variable change event
  /// </summary>
  TVariableChangeEvent = procedure(Sender: TObject; RowIndex: Integer; 
    const Variable: TPromptVariable) of object;
    
  /// <summary>
  /// Variable delete event
  /// </summary>
  TVariableDeleteEvent = procedure(Sender: TObject; RowIndex: Integer; 
    const VariableName: string) of object;
    
  /// <summary>
  /// Inline editor type
  /// </summary>
  TInlineEditorType = (ietNone, ietEdit, ietCombo, ietCheckbox, ietDateTime, ietMemo);
  
  /// <summary>
  /// Column definition
  /// </summary>
  TGridColumn = record
    Title: string;
    Width: Integer;
    Alignment: TAlignment;
    ReadOnly: Boolean;
  end;

  /// <summary>
  /// Custom grid for editing prompt variables
  /// </summary>
  TPromptVariableGrid = class(TDrawGrid)
  private
    FVariables: TList<TPromptVariable>;
    FInlineEdit: TEdit;
    FInlineCombo: TComboBox;
    FInlineCheck: TCheckBox;
    FInlineMemo: TMemo;
    FActiveEditor: TInlineEditorType;
    FEditRow: Integer;
    FEditCol: Integer;
    FColumns: array[0..5] of TGridColumn;
    FTypeColors: array[TPromptVarType] of TColor;
    FReadOnly: Boolean;
    FShowRowIndicator: Boolean;
    FOnVariableChange: TVariableChangeEvent;
    FOnVariableDelete: TVariableDeleteEvent;
    
    // Drawing helpers
    procedure DrawCell(Sender: TObject; ACol, ARow: Integer; 
      Rect: TRect; State: TGridDrawState);
    procedure DrawHeaderCell(ACol: Integer; Rect: TRect);
    procedure DrawDataCell(ACol, ARow: Integer; Rect: TRect; State: TGridDrawState);
    procedure DrawTypeIndicator(VarType: TPromptVarType; Rect: TRect);
    procedure DrawCheckbox(Checked: Boolean; Rect: TRect; Selected: Boolean);
    procedure DrawDeleteButton(Rect: TRect; Selected: Boolean);
    
    // Editor management
    procedure ShowInlineEditor(ACol, ARow: Integer);
    procedure HideInlineEditor(Apply: Boolean);
    procedure EditorExit(Sender: TObject);
    procedure EditorKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ComboChange(Sender: TObject);
    procedure CheckBoxClick(Sender: TObject);
    
    // Grid events
    procedure GridSelectCell(Sender: TObject; ACol, ARow: Integer;
      var CanSelect: Boolean);
    procedure GridDblClick(Sender: TObject);
    procedure GridKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure GridMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
      
    // Internal
    function GetVarTypeFromIndex(Index: Integer): TPromptVarType;
    function GetIndexFromVarType(VarType: TPromptVarType): Integer;
    function GetVariableCount: Integer;
    function GetVariable(Index: Integer): TPromptVariable;
    procedure UpdateGridSize;
    procedure NotifyChange(RowIndex: Integer);
    function GetEditorRect(ACol, ARow: Integer): TRect;
    
  protected
    procedure Resize; override;
    
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    /// <summary>Load variables from array</summary>
    procedure LoadVariables(const Variables: TArray<TPromptVariable>);
    
    /// <summary>Get all variables as array</summary>
    function GetVariables: TArray<TPromptVariable>;
    
    /// <summary>Add new variable</summary>
    procedure AddVariable(const Variable: TPromptVariable); overload;
    procedure AddVariable; overload;
    
    /// <summary>Delete variable at index</summary>
    procedure DeleteVariable(Index: Integer);
    
    /// <summary>Clear all variables</summary>
    procedure Clear;
    
    /// <summary>Update variable at index</summary>
    procedure UpdateVariable(Index: Integer; const Variable: TPromptVariable);
    
    /// <summary>Find variable by name</summary>
    function FindVariable(const Name: string): Integer;
    
    /// <summary>Validate all variables</summary>
    function Validate(out ErrorMsg: string): Boolean;
    
    property VariableCount: Integer read GetVariableCount;
    property Variables[Index: Integer]: TPromptVariable read GetVariable;
    property ReadOnly: Boolean read FReadOnly write FReadOnly;
    property ShowRowIndicator: Boolean read FShowRowIndicator write FShowRowIndicator;
    
    property OnVariableChange: TVariableChangeEvent read FOnVariableChange write FOnVariableChange;
    property OnVariableDelete: TVariableDeleteEvent read FOnVariableDelete write FOnVariableDelete;
  end;

implementation

uses
  Winapi.Windows,
  System.Math,
  System.RegularExpressions;

const
  COL_NAME = 0;
  COL_TYPE = 1;
  COL_DEFAULT = 2;
  COL_DESC = 3;
  COL_REQUIRED = 4;
  COL_DELETE = 5;
  
  TYPE_NAMES: array[TPromptVarType] of string = (
    'string', 'number', 'boolean', 'date', 'datetime', 'list', 'json'
  );

{ TPromptVariableGrid }

constructor TPromptVariableGrid.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  
  FVariables := TList<TPromptVariable>.Create;
  
  // Set default options
  DefaultDrawing := False;
  FixedCols := 0;
  FixedRows := 1;
  ColCount := 6;
  RowCount := 2;
  Options := Options + [goRowSelect, goColSizing, goThumbTracking] - [goRangeSelect];
  DefaultRowHeight := 26;
  RowHeights[0] := 28;
  
  // Define columns
  FColumns[COL_NAME].Title := 'Variable Name';
  FColumns[COL_NAME].Width := 140;
  FColumns[COL_NAME].Alignment := taLeftJustify;
  FColumns[COL_NAME].ReadOnly := False;
  
  FColumns[COL_TYPE].Title := 'Type';
  FColumns[COL_TYPE].Width := 90;
  FColumns[COL_TYPE].Alignment := taLeftJustify;
  FColumns[COL_TYPE].ReadOnly := False;
  
  FColumns[COL_DEFAULT].Title := 'Default Value';
  FColumns[COL_DEFAULT].Width := 150;
  FColumns[COL_DEFAULT].Alignment := taLeftJustify;
  FColumns[COL_DEFAULT].ReadOnly := False;
  
  FColumns[COL_DESC].Title := 'Description';
  FColumns[COL_DESC].Width := 180;
  FColumns[COL_DESC].Alignment := taLeftJustify;
  FColumns[COL_DESC].ReadOnly := False;
  
  FColumns[COL_REQUIRED].Title := 'Required';
  FColumns[COL_REQUIRED].Width := 70;
  FColumns[COL_REQUIRED].Alignment := taCenter;
  FColumns[COL_REQUIRED].ReadOnly := False;
  
  FColumns[COL_DELETE].Title := '';
  FColumns[COL_DELETE].Width := 30;
  FColumns[COL_DELETE].Alignment := taCenter;
  FColumns[COL_DELETE].ReadOnly := True;
  
  // Apply column widths
  ColWidths[COL_NAME] := FColumns[COL_NAME].Width;
  ColWidths[COL_TYPE] := FColumns[COL_TYPE].Width;
  ColWidths[COL_DEFAULT] := FColumns[COL_DEFAULT].Width;
  ColWidths[COL_DESC] := FColumns[COL_DESC].Width;
  ColWidths[COL_REQUIRED] := FColumns[COL_REQUIRED].Width;
  ColWidths[COL_DELETE] := FColumns[COL_DELETE].Width;
  
  // Type colors
  FTypeColors[pvtString] := $00E8F5E9;    // Light green
  FTypeColors[pvtNumber] := $00E3F2FD;    // Light blue
  FTypeColors[pvtBoolean] := $00FFF3E0;   // Light orange
  FTypeColors[pvtDate] := $00F3E5F5;      // Light purple
  FTypeColors[pvtDateTime] := $00FCE4EC;  // Light pink
  FTypeColors[pvtList] := $00E0F7FA;      // Light cyan
  FTypeColors[pvtJSON] := $00FFF8E1;      // Light amber
  
  // Create inline editors
  FInlineEdit := TEdit.Create(Self);
  FInlineEdit.Parent := Self;
  FInlineEdit.Visible := False;
  FInlineEdit.OnExit := EditorExit;
  FInlineEdit.OnKeyDown := EditorKeyDown;
  
  FInlineCombo := TComboBox.Create(Self);
  FInlineCombo.Parent := Self;
  FInlineCombo.Visible := False;
  FInlineCombo.Style := csDropDownList;
  FInlineCombo.OnExit := EditorExit;
  FInlineCombo.OnKeyDown := EditorKeyDown;
  FInlineCombo.OnChange := ComboChange;
  // Add type items
  FInlineCombo.Items.AddStrings(['string', 'number', 'boolean', 'date', 'datetime', 'list', 'json']);
  
  FInlineCheck := TCheckBox.Create(Self);
  FInlineCheck.Parent := Self;
  FInlineCheck.Visible := False;
  FInlineCheck.Caption := '';
  FInlineCheck.OnClick := CheckBoxClick;
  
  FInlineMemo := TMemo.Create(Self);
  FInlineMemo.Parent := Self;
  FInlineMemo.Visible := False;
  FInlineMemo.ScrollBars := ssBoth;
  FInlineMemo.OnExit := EditorExit;
  FInlineMemo.OnKeyDown := EditorKeyDown;
  
  FActiveEditor := ietNone;
  FEditRow := -1;
  FEditCol := -1;
  FReadOnly := False;
  FShowRowIndicator := True;
  
  // Event handlers
  OnDrawCell := DrawCell;
  OnSelectCell := GridSelectCell;
  OnDblClick := GridDblClick;
  OnKeyDown := GridKeyDown;
  OnMouseDown := GridMouseDown;
end;

destructor TPromptVariableGrid.Destroy;
begin
  FreeAndNil(FVariables);
  inherited;
end;

procedure TPromptVariableGrid.LoadVariables(const Variables: TArray<TPromptVariable>);
var
  V: TPromptVariable;
begin
  FVariables.Clear;
  for V in Variables do
    FVariables.Add(V);
  UpdateGridSize;
  Invalidate;
end;

function TPromptVariableGrid.GetVariables: TArray<TPromptVariable>;
begin
  Result := FVariables.ToArray;
end;

procedure TPromptVariableGrid.AddVariable(const Variable: TPromptVariable);
begin
  FVariables.Add(Variable);
  UpdateGridSize;
  Row := RowCount - 1;
  Invalidate;
  NotifyChange(FVariables.Count - 1);
end;

procedure TPromptVariableGrid.AddVariable;
var
  NewVar: TPromptVariable;
begin
  NewVar.Name := 'new_variable';
  NewVar.VarType := pvtString;
  NewVar.DefaultValue := '';
  NewVar.Description := '';
  NewVar.Required := False;
  
  // Auto-number if name exists
  var BaseName := NewVar.Name;
  var Counter := 1;
  while FindVariable(NewVar.Name) >= 0 do
  begin
    Inc(Counter);
    NewVar.Name := BaseName + IntToStr(Counter);
  end;
  
  AddVariable(NewVar);
end;

procedure TPromptVariableGrid.DeleteVariable(Index: Integer);
var
  VarName: string;
begin
  if (Index >= 0) and (Index < FVariables.Count) then
  begin
    VarName := FVariables[Index].Name;
    FVariables.Delete(Index);
    UpdateGridSize;
    Invalidate;
    
    if Assigned(FOnVariableDelete) then
      FOnVariableDelete(Self, Index, VarName);
  end;
end;

procedure TPromptVariableGrid.Clear;
begin
  FVariables.Clear;
  UpdateGridSize;
  Invalidate;
end;

procedure TPromptVariableGrid.UpdateVariable(Index: Integer; const Variable: TPromptVariable);
begin
  if (Index >= 0) and (Index < FVariables.Count) then
  begin
    FVariables[Index] := Variable;
    Invalidate;
    NotifyChange(Index);
  end;
end;

function TPromptVariableGrid.FindVariable(const Name: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to FVariables.Count - 1 do
    if SameText(FVariables[I].Name, Name) then
      Exit(I);
end;

function TPromptVariableGrid.Validate(out ErrorMsg: string): Boolean;
var
  I: Integer;
  V: TPromptVariable;
  Names: TDictionary<string, Boolean>;
begin
  Result := True;
  ErrorMsg := '';
  Names := TDictionary<string, Boolean>.Create;
  try
    for I := 0 to FVariables.Count - 1 do
    begin
      V := FVariables[I];
      
      // Check empty name
      if Trim(V.Name) = '' then
      begin
        ErrorMsg := Format('Row %d: Variable name cannot be empty', [I + 1]);
        Exit(False);
      end;
      
      // Check valid name format
      if not TRegEx.IsMatch(V.Name, '^[a-zA-Z_][a-zA-Z0-9_]*$') then
      begin
        ErrorMsg := Format('Row %d: Invalid variable name "%s"', [I + 1, V.Name]);
        Exit(False);
      end;
      
      // Check duplicate
      if Names.ContainsKey(LowerCase(V.Name)) then
      begin
        ErrorMsg := Format('Row %d: Duplicate variable name "%s"', [I + 1, V.Name]);
        Exit(False);
      end;
      Names.Add(LowerCase(V.Name), True);
    end;
  finally
    Names.Free;
  end;
end;

function TPromptVariableGrid.GetVariableCount: Integer;
begin
  Result := FVariables.Count;
end;

function TPromptVariableGrid.GetVariable(Index: Integer): TPromptVariable;
begin
  if (Index >= 0) and (Index < FVariables.Count) then
    Result := FVariables[Index]
  else
    Result := Default(TPromptVariable);
end;

procedure TPromptVariableGrid.UpdateGridSize;
begin
  if FVariables.Count = 0 then
    RowCount := 2  // Header + 1 empty row
  else
    RowCount := FVariables.Count + 1;  // Header + data rows
end;

procedure TPromptVariableGrid.NotifyChange(RowIndex: Integer);
begin
  if Assigned(FOnVariableChange) and (RowIndex >= 0) and (RowIndex < FVariables.Count) then
    FOnVariableChange(Self, RowIndex, FVariables[RowIndex]);
end;

procedure TPromptVariableGrid.Resize;
var
  TotalWidth, AvailWidth, DescWidth: Integer;
begin
  inherited;
  
  // Auto-adjust description column width
  TotalWidth := ColWidths[COL_NAME] + ColWidths[COL_TYPE] + ColWidths[COL_DEFAULT] +
                ColWidths[COL_REQUIRED] + ColWidths[COL_DELETE] + 20;
  AvailWidth := ClientWidth - TotalWidth;
  
  if AvailWidth > 100 then
    ColWidths[COL_DESC] := AvailWidth
  else
    ColWidths[COL_DESC] := 100;
end;

// === Drawing ===

procedure TPromptVariableGrid.DrawCell(Sender: TObject; ACol, ARow: Integer;
  Rect: TRect; State: TGridDrawState);
begin
  if ARow = 0 then
    DrawHeaderCell(ACol, Rect)
  else
    DrawDataCell(ACol, ARow, Rect, State);
end;

procedure TPromptVariableGrid.DrawHeaderCell(ACol: Integer; Rect: TRect);
begin
  Canvas.Brush.Color := $00F5F5F5;  // Light gray
  Canvas.FillRect(Rect);
  
  // Draw border
  Canvas.Pen.Color := $00E0E0E0;
  Canvas.MoveTo(Rect.Left, Rect.Bottom - 1);
  Canvas.LineTo(Rect.Right, Rect.Bottom - 1);
  
  // Draw text
  Canvas.Font.Style := [fsBold];
  Canvas.Font.Color := $00424242;
  var Text := FColumns[ACol].Title;
  var TextRect := Rect;
  InflateRect(TextRect, -4, 0);
  DrawText(Canvas.Handle, PChar(Text), Length(Text), TextRect,
    DT_SINGLELINE or DT_VCENTER or DT_END_ELLIPSIS or
    IfThen(FColumns[ACol].Alignment = taCenter, DT_CENTER, DT_LEFT));
  Canvas.Font.Style := [];
end;

procedure TPromptVariableGrid.DrawDataCell(ACol, ARow: Integer; Rect: TRect;
  State: TGridDrawState);
var
  DataRow: Integer;
  V: TPromptVariable;
  Text: string;
  TextRect: TRect;
  Selected: Boolean;
begin
  DataRow := ARow - 1;
  Selected := gdSelected in State;
  
  // Background
  if Selected then
    Canvas.Brush.Color := $00E3F2FD  // Light blue selection
  else if (DataRow >= 0) and (DataRow < FVariables.Count) then
    Canvas.Brush.Color := FTypeColors[FVariables[DataRow].VarType]
  else
    Canvas.Brush.Color := clWindow;
    
  Canvas.FillRect(Rect);
  
  // Draw grid lines
  Canvas.Pen.Color := $00E0E0E0;
  Canvas.MoveTo(Rect.Left, Rect.Bottom - 1);
  Canvas.LineTo(Rect.Right, Rect.Bottom - 1);
  Canvas.MoveTo(Rect.Right - 1, Rect.Top);
  Canvas.LineTo(Rect.Right - 1, Rect.Bottom);
  
  // No data row
  if (DataRow < 0) or (DataRow >= FVariables.Count) then
  begin
    if (DataRow = 0) and (FVariables.Count = 0) then
    begin
      // Show hint in empty grid
      if ACol = COL_NAME then
      begin
        Canvas.Font.Color := clGray;
        Canvas.Font.Style := [fsItalic];
        TextRect := Rect;
        InflateRect(TextRect, -4, 0);
        DrawText(Canvas.Handle, 'Double-click to add variable...', -1, TextRect,
          DT_SINGLELINE or DT_VCENTER);
        Canvas.Font.Style := [];
      end;
    end;
    Exit;
  end;
  
  V := FVariables[DataRow];
  Canvas.Font.Color := $00212121;
  
  case ACol of
    COL_NAME:
    begin
      Text := V.Name;
      TextRect := Rect;
      InflateRect(TextRect, -4, 0);
      DrawText(Canvas.Handle, PChar(Text), Length(Text), TextRect,
        DT_SINGLELINE or DT_VCENTER or DT_END_ELLIPSIS);
    end;
    
    COL_TYPE:
    begin
      // Draw type indicator
      DrawTypeIndicator(V.VarType, Rect);
    end;
    
    COL_DEFAULT:
    begin
      Text := VarToStr(V.DefaultValue);
      TextRect := Rect;
      InflateRect(TextRect, -4, 0);
      DrawText(Canvas.Handle, PChar(Text), Length(Text), TextRect,
        DT_SINGLELINE or DT_VCENTER or DT_END_ELLIPSIS);
    end;
    
    COL_DESC:
    begin
      Text := V.Description;
      Canvas.Font.Color := $00757575;  // Gray for description
      TextRect := Rect;
      InflateRect(TextRect, -4, 0);
      DrawText(Canvas.Handle, PChar(Text), Length(Text), TextRect,
        DT_SINGLELINE or DT_VCENTER or DT_END_ELLIPSIS);
    end;
    
    COL_REQUIRED:
    begin
      DrawCheckbox(V.Required, Rect, Selected);
    end;
    
    COL_DELETE:
    begin
      if not FReadOnly then
        DrawDeleteButton(Rect, Selected);
    end;
  end;
end;

procedure TPromptVariableGrid.DrawTypeIndicator(VarType: TPromptVarType; Rect: TRect);
var
  TypeColor: TColor;
  TagRect: TRect;
  Text: string;
begin
  // Type tag colors
  case VarType of
    pvtString:   TypeColor := $0066BB6A;  // Green
    pvtNumber:   TypeColor := $0042A5F5;  // Blue
    pvtBoolean:  TypeColor := $00FFA726;  // Orange
    pvtDate:     TypeColor := $00AB47BC;  // Purple
    pvtDateTime: TypeColor := $00EC407A;  // Pink
    pvtList:     TypeColor := $0026C6DA;  // Cyan
    pvtJSON:     TypeColor := $00FFCA28;  // Amber
  else
    TypeColor := clGray;
  end;
  
  Text := TYPE_NAMES[VarType];
  
  // Draw tag background
  TagRect := Rect;
  InflateRect(TagRect, -4, -4);
  TagRect.Right := TagRect.Left + Canvas.TextWidth(Text) + 12;
  if TagRect.Right > Rect.Right - 4 then
    TagRect.Right := Rect.Right - 4;
  
  Canvas.Brush.Color := TypeColor;
  Canvas.Pen.Color := TypeColor;
  Canvas.RoundRect(TagRect, 4, 4);
  
  // Draw text
  Canvas.Font.Color := clWhite;
  Canvas.Font.Style := [fsBold];
  var TextRect := TagRect;
  DrawText(Canvas.Handle, PChar(Text), Length(Text), TextRect,
    DT_SINGLELINE or DT_VCENTER or DT_CENTER);
  Canvas.Font.Style := [];
end;

procedure TPromptVariableGrid.DrawCheckbox(Checked: Boolean; Rect: TRect; Selected: Boolean);
var
  CheckRect: TRect;
  CenterX, CenterY: Integer;
begin
  CenterX := (Rect.Left + Rect.Right) div 2;
  CenterY := (Rect.Top + Rect.Bottom) div 2;
  
  CheckRect.Left := CenterX - 8;
  CheckRect.Top := CenterY - 8;
  CheckRect.Right := CenterX + 8;
  CheckRect.Bottom := CenterY + 8;
  
  // Draw checkbox border
  Canvas.Brush.Color := clWhite;
  Canvas.Pen.Color := $00BDBDBD;
  Canvas.Rectangle(CheckRect);
  
  // Draw checkmark if checked
  if Checked then
  begin
    Canvas.Pen.Color := $004CAF50;  // Green
    Canvas.Pen.Width := 2;
    Canvas.MoveTo(CheckRect.Left + 3, CenterY);
    Canvas.LineTo(CenterX - 1, CheckRect.Bottom - 4);
    Canvas.LineTo(CheckRect.Right - 3, CheckRect.Top + 4);
    Canvas.Pen.Width := 1;
  end;
end;

procedure TPromptVariableGrid.DrawDeleteButton(Rect: TRect; Selected: Boolean);
var
  CenterX, CenterY: Integer;
begin
  CenterX := (Rect.Left + Rect.Right) div 2;
  CenterY := (Rect.Top + Rect.Bottom) div 2;
  
  // Draw X
  Canvas.Pen.Color := $00F44336;  // Red
  Canvas.Pen.Width := 2;
  Canvas.MoveTo(CenterX - 5, CenterY - 5);
  Canvas.LineTo(CenterX + 6, CenterY + 6);
  Canvas.MoveTo(CenterX + 5, CenterY - 5);
  Canvas.LineTo(CenterX - 6, CenterY + 6);
  Canvas.Pen.Width := 1;
end;

// === Inline Editor ===

function TPromptVariableGrid.GetEditorRect(ACol, ARow: Integer): TRect;
begin
  Result := CellRect(ACol, ARow);
  InflateRect(Result, -1, -1);
end;

procedure TPromptVariableGrid.ShowInlineEditor(ACol, ARow: Integer);
var
  DataRow: Integer;
  V: TPromptVariable;
  EditorRect: TRect;
begin
  if FReadOnly then Exit;
  
  DataRow := ARow - 1;
  if (DataRow < 0) or (DataRow >= FVariables.Count) then Exit;
  if FColumns[ACol].ReadOnly then Exit;
  
  HideInlineEditor(False);
  
  V := FVariables[DataRow];
  EditorRect := GetEditorRect(ACol, ARow);
  FEditRow := ARow;
  FEditCol := ACol;
  
  case ACol of
    COL_NAME, COL_DEFAULT, COL_DESC:
    begin
      FInlineEdit.SetBounds(EditorRect.Left, EditorRect.Top,
        EditorRect.Width, EditorRect.Height);
      
      case ACol of
        COL_NAME: FInlineEdit.Text := V.Name;
        COL_DEFAULT: FInlineEdit.Text := VarToStr(V.DefaultValue);
        COL_DESC: FInlineEdit.Text := V.Description;
      end;
      
      FInlineEdit.Visible := True;
      FInlineEdit.SetFocus;
      FInlineEdit.SelectAll;
      FActiveEditor := ietEdit;
    end;
    
    COL_TYPE:
    begin
      FInlineCombo.SetBounds(EditorRect.Left, EditorRect.Top,
        EditorRect.Width, EditorRect.Height);
      FInlineCombo.ItemIndex := GetIndexFromVarType(V.VarType);
      FInlineCombo.Visible := True;
      FInlineCombo.SetFocus;
      FInlineCombo.DroppedDown := True;
      FActiveEditor := ietCombo;
    end;
    
    COL_REQUIRED:
    begin
      // Toggle directly
      V.Required := not V.Required;
      FVariables[DataRow] := V;
      Invalidate;
      NotifyChange(DataRow);
    end;
  end;
end;

procedure TPromptVariableGrid.HideInlineEditor(Apply: Boolean);
var
  DataRow: Integer;
  V: TPromptVariable;
begin
  if FActiveEditor = ietNone then Exit;
  
  DataRow := FEditRow - 1;
  
  if Apply and (DataRow >= 0) and (DataRow < FVariables.Count) then
  begin
    V := FVariables[DataRow];
    
    case FActiveEditor of
      ietEdit:
        case FEditCol of
          COL_NAME: V.Name := FInlineEdit.Text;
          COL_DEFAULT: V.DefaultValue := FInlineEdit.Text;
          COL_DESC: V.Description := FInlineEdit.Text;
        end;
        
      ietCombo:
        if FEditCol = COL_TYPE then
          V.VarType := GetVarTypeFromIndex(FInlineCombo.ItemIndex);
    end;
    
    FVariables[DataRow] := V;
    NotifyChange(DataRow);
  end;
  
  FInlineEdit.Visible := False;
  FInlineCombo.Visible := False;
  FInlineCheck.Visible := False;
  FInlineMemo.Visible := False;
  
  FActiveEditor := ietNone;
  FEditRow := -1;
  FEditCol := -1;
  
  Invalidate;
end;

procedure TPromptVariableGrid.EditorExit(Sender: TObject);
begin
  HideInlineEditor(True);
end;

procedure TPromptVariableGrid.EditorKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  case Key of
    VK_RETURN:
    begin
      HideInlineEditor(True);
      Key := 0;
    end;
    VK_ESCAPE:
    begin
      HideInlineEditor(False);
      Key := 0;
    end;
    VK_TAB:
    begin
      HideInlineEditor(True);
      // Move to next cell
      if FEditCol < COL_DESC then
        ShowInlineEditor(FEditCol + 1, FEditRow)
      else if FEditRow < RowCount - 1 then
        ShowInlineEditor(COL_NAME, FEditRow + 1);
      Key := 0;
    end;
  end;
end;

procedure TPromptVariableGrid.ComboChange(Sender: TObject);
begin
  // Apply type change immediately
  HideInlineEditor(True);
end;

procedure TPromptVariableGrid.CheckBoxClick(Sender: TObject);
var
  DataRow: Integer;
  V: TPromptVariable;
begin
  DataRow := FEditRow - 1;
  if (DataRow >= 0) and (DataRow < FVariables.Count) then
  begin
    V := FVariables[DataRow];
    V.Required := FInlineCheck.Checked;
    FVariables[DataRow] := V;
    NotifyChange(DataRow);
  end;
end;

// === Grid Events ===

procedure TPromptVariableGrid.GridSelectCell(Sender: TObject; ACol, ARow: Integer;
  var CanSelect: Boolean);
begin
  if FActiveEditor <> ietNone then
    HideInlineEditor(True);
  CanSelect := True;
end;

procedure TPromptVariableGrid.GridDblClick(Sender: TObject);
var
  CellCol, CellRow: Integer;
begin
  MouseToCell(ScreenToClient(Mouse.CursorPos).X, 
              ScreenToClient(Mouse.CursorPos).Y, CellCol, CellRow);
              
  if CellRow = 0 then Exit;  // Header
  
  // Empty grid - add new variable
  if (FVariables.Count = 0) and (CellRow = 1) then
  begin
    AddVariable;
    Exit;
  end;
  
  if CellCol = COL_DELETE then
  begin
    if not FReadOnly then
      DeleteVariable(CellRow - 1);
  end
  else
    ShowInlineEditor(CellCol, CellRow);
end;

procedure TPromptVariableGrid.GridKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  case Key of
    VK_DELETE:
      if not FReadOnly and (Row > 0) and (Row - 1 < FVariables.Count) then
      begin
        DeleteVariable(Row - 1);
        Key := 0;
      end;
      
    VK_INSERT:
      if not FReadOnly then
      begin
        AddVariable;
        Key := 0;
      end;
      
    VK_F2:
      if Row > 0 then
      begin
        ShowInlineEditor(Col, Row);
        Key := 0;
      end;
      
    VK_RETURN:
      if Row > 0 then
      begin
        ShowInlineEditor(Col, Row);
        Key := 0;
      end;
  end;
end;

procedure TPromptVariableGrid.GridMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  CellCol, CellRow: Integer;
begin
  MouseToCell(X, Y, CellCol, CellRow);
  
  // Click on delete button
  if (CellCol = COL_DELETE) and (CellRow > 0) and (CellRow - 1 < FVariables.Count) then
  begin
    if not FReadOnly then
      DeleteVariable(CellRow - 1);
  end
  // Click on checkbox
  else if (CellCol = COL_REQUIRED) and (CellRow > 0) and (CellRow - 1 < FVariables.Count) then
  begin
    if not FReadOnly then
    begin
      var DataRow := CellRow - 1;
      var V := FVariables[DataRow];
      V.Required := not V.Required;
      FVariables[DataRow] := V;
      Invalidate;
      NotifyChange(DataRow);
    end;
  end;
end;

// === Helpers ===

function TPromptVariableGrid.GetVarTypeFromIndex(Index: Integer): TPromptVarType;
begin
  case Index of
    0: Result := pvtString;
    1: Result := pvtNumber;
    2: Result := pvtBoolean;
    3: Result := pvtDate;
    4: Result := pvtDateTime;
    5: Result := pvtList;
    6: Result := pvtJSON;
  else
    Result := pvtString;
  end;
end;

function TPromptVariableGrid.GetIndexFromVarType(VarType: TPromptVarType): Integer;
begin
  Result := Ord(VarType);
end;

end.
