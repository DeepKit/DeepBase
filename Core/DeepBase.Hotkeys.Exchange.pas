{ ============================================================================
  DeepBase.Hotkeys.Exchange - Hotkey Import/Export Utilities

  Version: 1.0
  Description: Exports and imports hotkey profiles in JSON format.
  ============================================================================ }

unit DeepBase.Hotkeys.Exchange;

interface

uses
  System.SysUtils,
  DeepBase.Hotkeys;

type
  THotkeyImportConflictMode = (
    hicmStrict,
    hicmOverwriteConflict,
    hicmKeepConflict
  );

  TDeepBaseHotkeyExchange = class
  public
    class function ExportToJson(AHotkeys: TDeepBaseHotkeys): string; static;
    class procedure ExportToFile(AHotkeys: TDeepBaseHotkeys;
      const AFileName: string); static;
    class function ImportFromJson(AHotkeys: TDeepBaseHotkeys; const AJson: string;
      AConflictMode: THotkeyImportConflictMode = hicmOverwriteConflict): Integer; static;
    class function ImportFromFile(AHotkeys: TDeepBaseHotkeys; const AFileName: string;
      AConflictMode: THotkeyImportConflictMode = hicmOverwriteConflict): Integer; static;
  end;

implementation

uses
  System.Classes,
  System.JSON,
  System.IOUtils;

function ScopeToText(Scope: THotkeyScope): string;
begin
  case Scope of
    hsGlobal:
      Result := 'global';
    hsApplication:
      Result := 'application';
    hsForm:
      Result := 'form';
    hsEditor:
      Result := 'editor';
  else
    Result := 'application';
  end;
end;

function TextToScope(const Value: string;
  DefaultScope: THotkeyScope): THotkeyScope;
var
  S: string;
begin
  S := Trim(LowerCase(Value));
  if S = '' then
    Exit(DefaultScope);

  if S = 'global' then
    Exit(hsGlobal);
  if S = 'application' then
    Exit(hsApplication);
  if S = 'form' then
    Exit(hsForm);
  if S = 'editor' then
    Exit(hsEditor);

  Result := DefaultScope;
end;

function ReadShortcut(Obj: TJSONObject): TShortCut;
var
  Value: TJSONValue;
  ShortcutText: string;
  ShortcutCode: Integer;
begin
  Result := 0;
  if Obj = nil then
    Exit;

  Value := Obj.GetValue('shortcut_text');
  if Assigned(Value) then
  begin
    ShortcutText := Trim(Value.Value);
    if ShortcutText <> '' then
    begin
      Result := DeepBaseTextToShortCut(ShortcutText);
      Exit;
    end;
  end;

  Value := Obj.GetValue('shortcut_code');
  if Assigned(Value) and TryStrToInt(Value.Value, ShortcutCode) then
    Result := TShortCut(ShortcutCode);
end;

function ReadScope(Obj: TJSONObject; DefaultScope: THotkeyScope): THotkeyScope;
var
  Value: TJSONValue;
begin
  Result := DefaultScope;
  if Obj = nil then
    Exit;

  Value := Obj.GetValue('scope');
  if Assigned(Value) then
    Result := TextToScope(Value.Value, DefaultScope);
end;

{ TDeepBaseHotkeyExchange }

class function TDeepBaseHotkeyExchange.ExportToJson(
  AHotkeys: TDeepBaseHotkeys): string;
var
  Root: TJSONObject;
  Items: TJSONArray;
  Hotkeys: THotkeyInfoArray;
  Hotkey: THotkeyInfo;
  Item: TJSONObject;
begin
  if AHotkeys = nil then
    raise EArgumentNilException.Create('AHotkeys');

  Root := TJSONObject.Create;
  try
    Root.AddPair('schema', 'deepbase.hotkeys/1');
    Root.AddPair('exported_at', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now));
    Items := TJSONArray.Create;
    Root.AddPair('items', Items);

    Hotkeys := AHotkeys.GetAllHotkeys;
    for Hotkey in Hotkeys do
    begin
      Item := TJSONObject.Create;
      Item.AddPair('action_name', Hotkey.ActionName);
      Item.AddPair('shortcut_text', DeepBaseShortCutToText(Hotkey.Shortcut));
      Item.AddPair('shortcut_code', TJSONNumber.Create(Integer(Hotkey.Shortcut)));
      Item.AddPair('scope', ScopeToText(Hotkey.Scope));
      Item.AddPair('is_customized', TJSONBool.Create(Hotkey.IsCustomized));
      Item.AddPair('description', Hotkey.Description);
      Item.AddPair('category', Hotkey.Category);
      Items.AddElement(Item);
    end;

    Result := Root.ToJSON;
  finally
    Root.Free;
  end;
end;

class procedure TDeepBaseHotkeyExchange.ExportToFile(AHotkeys: TDeepBaseHotkeys;
  const AFileName: string);
var
  Json: string;
begin
  if Trim(AFileName) = '' then
    raise EArgumentException.Create('AFileName is required.');

  Json := ExportToJson(AHotkeys);
  TFile.WriteAllText(AFileName, Json, TEncoding.UTF8);
end;

class function TDeepBaseHotkeyExchange.ImportFromJson(AHotkeys: TDeepBaseHotkeys;
  const AJson: string; AConflictMode: THotkeyImportConflictMode): Integer;
var
  RootValue: TJSONValue;
  Root: TJSONObject;
  ItemsValue: TJSONValue;
  Items: TJSONArray;
  Value: TJSONValue;
  Item: TJSONObject;
  ActionValue: TJSONValue;
  ActionName: string;
  Shortcut: TShortCut;
  Scope: THotkeyScope;
  ConflictAction: string;
begin
  Result := 0;
  if AHotkeys = nil then
    raise EArgumentNilException.Create('AHotkeys');
  if Trim(AJson) = '' then
    raise EArgumentException.Create('AJson is empty.');

  RootValue := TJSONObject.ParseJSONValue(AJson);
  if not (RootValue is TJSONObject) then
  begin
    RootValue.Free;
    raise EArgumentException.Create('Invalid hotkey profile JSON.');
  end;

  Root := TJSONObject(RootValue);
  try
    ItemsValue := Root.GetValue('items');
    if not (ItemsValue is TJSONArray) then
      raise EArgumentException.Create('Invalid hotkey profile JSON: items array is required.');

    Items := TJSONArray(ItemsValue);
    for Value in Items do
    begin
      if not (Value is TJSONObject) then
        Continue;

      Item := TJSONObject(Value);
      ActionName := '';
      ActionValue := Item.GetValue('action_name');
      if Assigned(ActionValue) then
        ActionName := Trim(ActionValue.Value);
      if ActionName = '' then
        Continue;

      Shortcut := ReadShortcut(Item);
      Scope := ReadScope(Item, AHotkeys.GetHotkeyScope(ActionName));

      if Shortcut <> 0 then
      begin
        ConflictAction := AHotkeys.CheckHotkeyConflictInScope(
          Shortcut, Scope, ActionName);
        if ConflictAction <> '' then
        begin
          case AConflictMode of
            hicmStrict:
              raise EInvalidOp.CreateFmt(
                'Hotkey conflict: "%s" already uses %s (%s).',
                [ConflictAction, DeepBaseShortCutToText(Shortcut), ScopeToText(Scope)]);
            hicmKeepConflict:
              Continue;
            hicmOverwriteConflict:
              AHotkeys.SetHotkey(ConflictAction, 0);
          end;
        end;
      end;

      AHotkeys.SetHotkey(ActionName, Shortcut);
      AHotkeys.SetHotkeyScope(ActionName, Scope);
      Inc(Result);
    end;
  finally
    Root.Free;
  end;
end;

class function TDeepBaseHotkeyExchange.ImportFromFile(
  AHotkeys: TDeepBaseHotkeys; const AFileName: string;
  AConflictMode: THotkeyImportConflictMode): Integer;
var
  Json: string;
begin
  if Trim(AFileName) = '' then
    raise EArgumentException.Create('AFileName is required.');

  Json := TFile.ReadAllText(AFileName, TEncoding.UTF8);
  Result := ImportFromJson(AHotkeys, Json, AConflictMode);
end;

end.
