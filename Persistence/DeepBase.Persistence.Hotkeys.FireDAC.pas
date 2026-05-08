{ ============================================================================
  DeepBase.Persistence.Hotkeys.FireDAC - FireDAC adapter for hotkeys storage
  ============================================================================
  Registers FireDAC implementation for IHotkeyStorage.
  ============================================================================ }

unit DeepBase.Persistence.Hotkeys.FireDAC;

interface

uses
  DeepBase.Storage.Interfaces,
  FireDAC.Comp.Client;

function CreateHotkeyStorage(AConnection: TFDConnection): IHotkeyStorage;
procedure RegisterHotkeysFireDACStorageFactory;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.Variants,
  System.Generics.Collections,
  Winapi.Windows,
  FireDAC.Stan.Param,
  DeepBase.Hotkeys,
  DeepBase.Types;

function TextToShortCut(const Text: string): TShortCut;
var
  Parts: TArray<string>;
  RawPart, Part: string;
  Key: Word;
  Modifiers: Word;
  N: Integer;
begin
  Key := 0;
  Modifiers := 0;

  Parts := Text.Replace('-', '+').Split(['+']);
  for RawPart in Parts do
  begin
    Part := Trim(RawPart);
    if Part = '' then
      Continue;

    if SameText(Part, 'Ctrl') or SameText(Part, 'Control') then
      Modifiers := Modifiers or scCtrl
    else if SameText(Part, 'Shift') then
      Modifiers := Modifiers or scShift
    else if SameText(Part, 'Alt') then
      Modifiers := Modifiers or scAlt
    else if (Length(Part) = 1) and CharInSet(UpCase(Part[1]), ['A'..'Z', '0'..'9']) then
      Key := Ord(UpCase(Part[1]))
    else if (Length(Part) > 1) and (UpCase(Part[1]) = 'F') and
      TryStrToInt(Copy(Part, 2, MaxInt), N) and (N >= 1) and (N <= 24) then
      Key := VK_F1 + N - 1
    else if SameText(Part, 'Esc') or SameText(Part, 'Escape') then
      Key := VK_ESCAPE
    else if SameText(Part, 'Enter') or SameText(Part, 'Return') then
      Key := VK_RETURN
    else if SameText(Part, 'Tab') then
      Key := VK_TAB
    else if SameText(Part, 'Space') then
      Key := VK_SPACE
    else if SameText(Part, 'Ins') or SameText(Part, 'Insert') then
      Key := VK_INSERT
    else if SameText(Part, 'Del') or SameText(Part, 'Delete') then
      Key := VK_DELETE
    else if SameText(Part, 'Home') then
      Key := VK_HOME
    else if SameText(Part, 'End') then
      Key := VK_END
    else if SameText(Part, 'PgUp') or SameText(Part, 'PageUp') then
      Key := VK_PRIOR
    else if SameText(Part, 'PgDn') or SameText(Part, 'PageDown') then
      Key := VK_NEXT
    else if SameText(Part, 'Left') then
      Key := VK_LEFT
    else if SameText(Part, 'Right') then
      Key := VK_RIGHT
    else if SameText(Part, 'Up') then
      Key := VK_UP
    else if SameText(Part, 'Down') then
      Key := VK_DOWN
    else if SameText(Part, 'Backspace') or SameText(Part, 'BkSp') then
      Key := VK_BACK
    else if TryStrToInt(Part, N) and (N >= Low(Word)) and (N <= High(Word)) then
      Key := N;
  end;

  if Key = 0 then
    Result := 0
  else
    Result := Key or Modifiers;
end;

type
  TFireDACHotkeyStorage = class(TInterfacedObject, IHotkeyStorage)
  private
    FConnection: TFDConnection;
    function QueryFieldToShortCut(Query: TFDQuery;
      const FieldName: string): Word;
    function QueryToHotkeyData(Query: TFDQuery): THotkeyStorageData;
  public
    constructor Create(AConnection: TFDConnection);
    function ReadEnabledHotkeys: THotkeyStorageDataArray;
    procedure RegisterDefaults(const Defaults: THotkeyStorageDataArray);
    procedure UpdateShortcut(const ActionName: string; Shortcut: Word;
      IsCustomized: Boolean);
    procedure ResetShortcut(const ActionName: string);
    procedure ResetAllShortcuts;
    function ReadAllHotkeys: THotkeyStorageDataArray;
    procedure DeleteHotkey(const ActionName: string);
  end;

constructor TFireDACHotkeyStorage.Create(AConnection: TFDConnection);
begin
  inherited Create;
  FConnection := AConnection;
end;

function TFireDACHotkeyStorage.QueryFieldToShortCut(Query: TFDQuery;
  const FieldName: string): Word;
begin
  Result := 0;
  try
    if Query.FieldByName(FieldName).IsNull then
      Exit;

    if VarIsNumeric(Query.FieldByName(FieldName).Value) then
      Result := Query.FieldByName(FieldName).AsInteger
    else
      Result := TextToShortCut(Query.FieldByName(FieldName).AsString);
  except
    Result := 0;
  end;
end;

function TFireDACHotkeyStorage.QueryToHotkeyData(
  Query: TFDQuery): THotkeyStorageData;
begin
  Result.ActionName := Query.FieldByName('ActionName').AsString;
  Result.Shortcut := QueryFieldToShortCut(Query, 'Shortcut');
  Result.DefaultShortcut := QueryFieldToShortCut(Query, 'DefaultShortcut');
  Result.Category := Query.FieldByName('Category').AsString;
  Result.Description := Query.FieldByName('Description').AsString;
  Result.IsEnabled := Query.FieldByName('IsEnabled').AsInteger <> 0;
  Result.IsCustomized := Query.FieldByName('IsCustomized').AsInteger <> 0;
end;

function TFireDACHotkeyStorage.ReadEnabledHotkeys: THotkeyStorageDataArray;
var
  Query: TFDQuery;
  List: TList<THotkeyStorageData>;
begin
  SetLength(Result, 0);
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  List := TList<THotkeyStorageData>.Create;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text :=
        'SELECT ActionName, Shortcut, DefaultShortcut, Category, Description, IsEnabled, IsCustomized ' +
        'FROM Hotkeys WHERE IsEnabled = 1';
      Query.Open;

      while not Query.Eof do
      begin
        List.Add(QueryToHotkeyData(Query));
        Query.Next;
      end;

      Result := List.ToArray;
    finally
      Query.Free;
    end;
  finally
    List.Free;
  end;
end;

procedure TFireDACHotkeyStorage.RegisterDefaults(
  const Defaults: THotkeyStorageDataArray);
var
  Def: THotkeyStorageData;
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text :=
      'INSERT OR IGNORE INTO Hotkeys (ActionName, Shortcut, DefaultShortcut, Category, Description, IsEnabled, IsCustomized) ' +
      'VALUES (:Action, :Shortcut, :Default, :Cat, :Desc, :Enabled, :Customized)';

    for Def in Defaults do
    begin
      Query.ParamByName('Action').AsString := Def.ActionName;
      Query.ParamByName('Shortcut').AsInteger := Def.Shortcut;
      Query.ParamByName('Default').AsInteger := Def.DefaultShortcut;
      Query.ParamByName('Cat').AsString := Def.Category;
      Query.ParamByName('Desc').AsString := Def.Description;
      Query.ParamByName('Enabled').AsInteger := Ord(Def.IsEnabled);
      Query.ParamByName('Customized').AsInteger := Ord(Def.IsCustomized);
      Query.ExecSQL;
    end;
  finally
    Query.Free;
  end;
end;

procedure TFireDACHotkeyStorage.UpdateShortcut(const ActionName: string;
  Shortcut: Word; IsCustomized: Boolean);
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text :=
      'UPDATE Hotkeys SET Shortcut = :Shortcut, IsCustomized = :Customized ' +
      'WHERE ActionName = :Action';

    Query.ParamByName('Action').AsString := ActionName;
    Query.ParamByName('Shortcut').AsInteger := Shortcut;
    Query.ParamByName('Customized').AsInteger := Ord(IsCustomized);
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

procedure TFireDACHotkeyStorage.ResetShortcut(const ActionName: string);
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text :=
      'UPDATE Hotkeys SET Shortcut = DefaultShortcut, IsCustomized = 0 ' +
      'WHERE ActionName = :Action';
    Query.ParamByName('Action').AsString := ActionName;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

procedure TFireDACHotkeyStorage.ResetAllShortcuts;
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text :=
      'UPDATE Hotkeys SET Shortcut = DefaultShortcut, IsCustomized = 0';
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

function TFireDACHotkeyStorage.ReadAllHotkeys: THotkeyStorageDataArray;
var
  Query: TFDQuery;
  List: TList<THotkeyStorageData>;
begin
  SetLength(Result, 0);
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  List := TList<THotkeyStorageData>.Create;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text :=
        'SELECT ActionName, Shortcut, DefaultShortcut, Category, Description, IsEnabled, IsCustomized ' +
        'FROM Hotkeys ORDER BY Category, ActionName';
      Query.Open;

      while not Query.Eof do
      begin
        List.Add(QueryToHotkeyData(Query));
        Query.Next;
      end;

      Result := List.ToArray;
    finally
      Query.Free;
    end;
  finally
    List.Free;
  end;
end;

procedure TFireDACHotkeyStorage.DeleteHotkey(const ActionName: string);
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'DELETE FROM Hotkeys WHERE ActionName = :Action';
    Query.ParamByName('Action').AsString := ActionName;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

function CreateHotkeyStorage(AConnection: TFDConnection): IHotkeyStorage;
begin
  Result := TFireDACHotkeyStorage.Create(AConnection);
end;

procedure RegisterHotkeysFireDACStorageFactory;
begin
  TDeepBaseHotkeys.SetConnectionStorageFactory(
    function(AConnection: TObject): IHotkeyStorage
    var
      FDConnection: TFDConnection;
    begin
      if not (AConnection is TFDConnection) then
        raise EInvalidCast.Create(
          'Expected TFDConnection for Hotkeys FireDAC storage.');
      FDConnection := TFDConnection(AConnection);
      Result := CreateHotkeyStorage(FDConnection);
    end);
end;

initialization
  RegisterHotkeysFireDACStorageFactory;

end.
