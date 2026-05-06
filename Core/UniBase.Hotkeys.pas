{ ============================================================================
  UniBase.Hotkeys - Hotkey Management Module
  
  Version: 1.0
  Description: Manages user-defined hotkeys and conflict detection.
  Thread Safety: All public methods are thread-safe.
  ============================================================================ }

unit UniBase.Hotkeys;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  UniBase.Types,
  UniBase.Storage.Interfaces;

type
  /// <summary>
  /// Hotkey detailed info
  /// </summary>
  THotkeyInfo = record
    ActionName: string;
    Shortcut: TShortCut;
    DefaultShortcut: TShortCut;
    Category: string;
    Description: string;
    IsEnabled: Boolean;
    IsCustomized: Boolean;
  end;
  THotkeyInfoArray = TArray<THotkeyInfo>;

  /// <summary>
  /// Hotkey changed callback type
  /// </summary>
  THotkeyChangedProc = reference to procedure(const ActionName: string);

  /// <summary>
  /// Hotkey manager
  /// </summary>
  TUniBaseHotkeys = class
  private
    FConnection: TObject;
    FStorage: IHotkeyStorage;
    FLock: TObject;
    FOwnsLock: Boolean;
    FCache: TDictionary<string, TShortCut>; // ActionName -> Shortcut
    FDefaultCache: TDictionary<string, TShortCut>; // ActionName -> DefaultShortcut
    FOnHotkeyChanged: THotkeyChangedProc;
    class var FConnectionStorageFactory: TFunc<TObject, IHotkeyStorage>;
    
    procedure LoadCache;
    procedure InternalWriteHotkey(const ActionName: string; Shortcut, DefaultShortcut: TShortCut; 
      const Description, Category: string; IsCustomized: Boolean);
    procedure DoHotkeyChanged(const ActionName: string);
    class function CreateStorageFromConnection(
      AConnection: TObject): IHotkeyStorage; static;
    
  public
    constructor Create(AConnection: TObject; ALock: TObject = nil); overload;
    constructor Create(const AStorage: IHotkeyStorage;
      ALock: TObject = nil); overload;
    destructor Destroy; override;
    class procedure SetConnectionStorageFactory(
      const AFactory: TFunc<TObject, IHotkeyStorage>); static;
    
    // ========================================
    // Core Methods
    // ========================================
    
    /// <summary>
    /// 获取快捷键
    /// </summary>
    function GetHotkey(const ActionName: string): TShortCut;
    
    /// <summary>
    /// 设置快捷键
    /// </summary>
    procedure SetHotkey(const ActionName: string; Shortcut: TShortCut);
    
    /// <summary>
    /// 注册默认快捷键（只在不存在时插入）
    /// </summary>
    procedure RegisterDefaultHotkeys(const Defaults: TArray<THotkeyDefault>);
    
    // ========================================
    // Reset Functions
    // ========================================
    
    /// <summary>
    /// 重置单个快捷键为默认值
    /// </summary>
    procedure ResetHotkey(const ActionName: string);
    
    /// <summary>
    /// 重置所有快捷键为默认值
    /// </summary>
    procedure ResetAllHotkeys;
    
    // ========================================
    // Conflict Detection
    // ========================================
    
    /// <summary>
    /// 检查快捷键冲突
    /// </summary>
    /// <returns>冲突的 ActionName，无冲突返回空字符串</returns>
    function CheckHotkeyConflict(Shortcut: TShortCut; const ExcludeActionName: string = ''): string;
    
    // ========================================
    // Query Methods
    // ========================================
    
    /// <summary>
    /// 获取所有快捷键信息
    /// </summary>
    function GetAllHotkeys: THotkeyInfoArray;
    
    /// <summary>
    /// 获取快捷键详细信息 (用于设置界面)
    /// </summary>
    function GetAllHotkeyDefaults: TArray<THotkeyDefault>;
    
    /// <summary>
    /// 检查快捷键是否被修改过
    /// </summary>
    function IsHotkeyCustomized(const ActionName: string): Boolean;
    
    /// <summary>
    /// 快捷键数量
    /// </summary>
    function Count: Integer;
    
    /// <summary>
    /// 删除快捷键
    /// </summary>
    procedure DeleteHotkey(const ActionName: string);
    
    /// <summary>
    /// 快捷键变更事件
    /// </summary>
    property OnHotkeyChanged: THotkeyChangedProc read FOnHotkeyChanged write FOnHotkeyChanged;
  end;

implementation

function UniBaseTextToShortCut(const Text: string): TShortCut;
const
  VK_BACK = $08;
  VK_TAB = $09;
  VK_RETURN = $0D;
  VK_ESCAPE = $1B;
  VK_SPACE = $20;
  VK_INSERT = $2D;
  VK_DELETE = $2E;
  VK_F1 = $70;
var
  Parts: TArray<string>;
  RawPart: string;
  Part: string;
  KeyPart: string;
  KeyCode: Word;
  FKeyNumber: Integer;
begin
  Result := 0;
  KeyPart := '';

  Parts := Text.Split(['+']);
  for RawPart in Parts do
  begin
    Part := Trim(RawPart).ToUpperInvariant;
    if Part = '' then
      Continue;

    if Part = 'CTRL' then
      Result := Result or scCtrl
    else if Part = 'SHIFT' then
      Result := Result or scShift
    else if Part = 'ALT' then
      Result := Result or scAlt
    else
      KeyPart := Part;
  end;

  if KeyPart = '' then
    Exit(0);

  KeyCode := 0;
  if (Length(KeyPart) = 1) and CharInSet(KeyPart[1], ['A'..'Z', '0'..'9']) then
    KeyCode := Ord(KeyPart[1])
  else if (Length(KeyPart) >= 2) and (KeyPart[1] = 'F') and
    TryStrToInt(Copy(KeyPart, 2, MaxInt), FKeyNumber) and
    (FKeyNumber >= 1) and (FKeyNumber <= 24) then
    KeyCode := VK_F1 + FKeyNumber - 1
  else if (KeyPart = 'ESC') or (KeyPart = 'ESCAPE') then
    KeyCode := VK_ESCAPE
  else if (KeyPart = 'ENTER') or (KeyPart = 'RETURN') then
    KeyCode := VK_RETURN
  else if KeyPart = 'TAB' then
    KeyCode := VK_TAB
  else if KeyPart = 'SPACE' then
    KeyCode := VK_SPACE
  else if (KeyPart = 'INS') or (KeyPart = 'INSERT') then
    KeyCode := VK_INSERT
  else if (KeyPart = 'DEL') or (KeyPart = 'DELETE') then
    KeyCode := VK_DELETE
  else if (KeyPart = 'BACKSPACE') or (KeyPart = 'BKSP') then
    KeyCode := VK_BACK;

  if KeyCode = 0 then
    Result := 0
  else
    Result := Result or KeyCode;
end;

function UniBaseShortCutToText(Shortcut: TShortCut): string;
var
  KeyCode: Word;
  KeyText: string;
begin
  Result := '';
  if Shortcut = 0 then
    Exit;

  if (Shortcut and scCtrl) <> 0 then
    Result := Result + 'Ctrl+';
  if (Shortcut and scShift) <> 0 then
    Result := Result + 'Shift+';
  if (Shortcut and scAlt) <> 0 then
    Result := Result + 'Alt+';

  KeyCode := Shortcut and not (scCtrl or scShift or scAlt);
  if (KeyCode >= Ord('A')) and (KeyCode <= Ord('Z')) then
    KeyText := Chr(KeyCode)
  else if (KeyCode >= Ord('0')) and (KeyCode <= Ord('9')) then
    KeyText := Chr(KeyCode)
  else if (KeyCode >= $70) and (KeyCode <= $87) then
    KeyText := 'F' + IntToStr(KeyCode - $70 + 1)
  else
    case KeyCode of
      $08: KeyText := 'Backspace';
      $09: KeyText := 'Tab';
      $0D: KeyText := 'Enter';
      $1B: KeyText := 'Esc';
      $20: KeyText := 'Space';
      $2D: KeyText := 'Ins';
      $2E: KeyText := 'Del';
    else
      KeyText := '';
    end;

  if KeyText = '' then
    Result := ''
  else
    Result := Result + KeyText;
end;

{ TUniBaseHotkeys }

constructor TUniBaseHotkeys.Create(AConnection: TObject; ALock: TObject);
begin
  Create(CreateStorageFromConnection(AConnection), ALock);
  FConnection := AConnection;
end;

constructor TUniBaseHotkeys.Create(const AStorage: IHotkeyStorage;
  ALock: TObject);
begin
  inherited Create;
  FStorage := AStorage;
  if ALock <> nil then
  begin
    FLock := ALock;
    FOwnsLock := False;
  end
  else
  begin
    FLock := TObject.Create;
    FOwnsLock := True;
  end;
  FCache := TDictionary<string, TShortCut>.Create;
  FDefaultCache := TDictionary<string, TShortCut>.Create;
  LoadCache;
end;

destructor TUniBaseHotkeys.Destroy;
begin
  FreeAndNil(FCache);
  FreeAndNil(FDefaultCache);
  if FOwnsLock then
    FreeAndNil(FLock);
  inherited;
end;

class procedure TUniBaseHotkeys.SetConnectionStorageFactory(
  const AFactory: TFunc<TObject, IHotkeyStorage>);
begin
  FConnectionStorageFactory := AFactory;
end;

class function TUniBaseHotkeys.CreateStorageFromConnection(
  AConnection: TObject): IHotkeyStorage;
begin
  Result := nil;
  if Assigned(AConnection) and Assigned(FConnectionStorageFactory) then
    Result := FConnectionStorageFactory(AConnection);
  if (Result = nil) and Assigned(AConnection) then
    raise EInvalidOp.Create(
      'No hotkey storage factory registered for connection-backed constructor. ' +
      'Include UniBase.Persistence.Hotkeys.FireDAC or UniBase.Persistence.Manager.FireDAC.');
end;

procedure TUniBaseHotkeys.LoadCache;
var
  Items: THotkeyStorageDataArray;
  Item: THotkeyStorageData;
begin
  if not Assigned(FStorage) then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    FCache.Clear;
    FDefaultCache.Clear;

    Items := FStorage.ReadEnabledHotkeys;
    for Item in Items do
    begin
      FCache.AddOrSetValue(Item.ActionName, TShortCut(Item.Shortcut));
      if Item.DefaultShortcut <> 0 then
        FDefaultCache.AddOrSetValue(Item.ActionName,
          TShortCut(Item.DefaultShortcut));
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TUniBaseHotkeys.RegisterDefaultHotkeys(const Defaults: TArray<THotkeyDefault>);
var
  Def: THotkeyDefault;
  StorageDefaults: THotkeyStorageDataArray;
  ShortcutVal: TShortCut;
  I: Integer;
begin
  SetLength(StorageDefaults, Length(Defaults));

  TMonitor.Enter(FLock);
  try
    for I := 0 to High(Defaults) do
    begin
      Def := Defaults[I];
      ShortcutVal := UniBaseTextToShortCut(Def.Shortcut);
      StorageDefaults[I].ActionName := Def.ActionName;
      StorageDefaults[I].Shortcut := Word(ShortcutVal);
      StorageDefaults[I].DefaultShortcut := Word(ShortcutVal);
      StorageDefaults[I].Category := Def.Category;
      StorageDefaults[I].Description := Def.Description;
      StorageDefaults[I].IsEnabled := True;
      StorageDefaults[I].IsCustomized := False;
    end;

    if Assigned(FStorage) then
      FStorage.RegisterDefaults(StorageDefaults);

    for I := 0 to High(StorageDefaults) do
      if not FCache.ContainsKey(StorageDefaults[I].ActionName) then
      begin
        FCache.Add(StorageDefaults[I].ActionName,
          TShortCut(StorageDefaults[I].Shortcut));
        FDefaultCache.Add(StorageDefaults[I].ActionName,
          TShortCut(StorageDefaults[I].DefaultShortcut));
      end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TUniBaseHotkeys.InternalWriteHotkey(const ActionName: string; Shortcut, DefaultShortcut: TShortCut; 
  const Description, Category: string; IsCustomized: Boolean);
begin
  if Assigned(FStorage) then
    FStorage.UpdateShortcut(ActionName, Word(Shortcut), IsCustomized);
end;

procedure TUniBaseHotkeys.DoHotkeyChanged(const ActionName: string);
begin
  if Assigned(FOnHotkeyChanged) then
    FOnHotkeyChanged(ActionName);
end;

procedure TUniBaseHotkeys.SetHotkey(const ActionName: string; Shortcut: TShortCut);
var
  DefaultShortcut: TShortCut;
  IsCustomized: Boolean;
begin
  TMonitor.Enter(FLock);
  try
    // Check if different from default
    if FDefaultCache.TryGetValue(ActionName, DefaultShortcut) then
      IsCustomized := (Shortcut <> DefaultShortcut)
    else
      IsCustomized := True;
      
    InternalWriteHotkey(ActionName, Shortcut, 0, '', '', IsCustomized);
    FCache.AddOrSetValue(ActionName, Shortcut);
  finally
    TMonitor.Exit(FLock);
  end;
  DoHotkeyChanged(ActionName);
end;

function TUniBaseHotkeys.GetHotkey(const ActionName: string): TShortCut;
begin
  TMonitor.Enter(FLock);
  try
    if not FCache.TryGetValue(ActionName, Result) then
      Result := 0;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TUniBaseHotkeys.CheckHotkeyConflict(Shortcut: TShortCut; const ExcludeActionName: string): string;
var
  Pair: TPair<string, TShortCut>;
begin
  Result := '';
  if Shortcut = 0 then Exit;
  
  TMonitor.Enter(FLock);
  try
    for Pair in FCache do
    begin
      if (Pair.Value = Shortcut) and (Pair.Key <> ExcludeActionName) then
      begin
        Result := Pair.Key;
        Exit;
      end;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TUniBaseHotkeys.ResetHotkey(const ActionName: string);
var
  DefaultShortcut: TShortCut;
begin
  if not Assigned(FStorage) then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    FStorage.ResetShortcut(ActionName);

    // Update cache
    if FDefaultCache.TryGetValue(ActionName, DefaultShortcut) then
      FCache.AddOrSetValue(ActionName, DefaultShortcut);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TUniBaseHotkeys.ResetAllHotkeys;
var
  Pair: TPair<string, TShortCut>;
begin
  if not Assigned(FStorage) then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    FStorage.ResetAllShortcuts;
    
    // Update cache
    for Pair in FDefaultCache do
      FCache.AddOrSetValue(Pair.Key, Pair.Value);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TUniBaseHotkeys.GetAllHotkeys: THotkeyInfoArray;
var
  DataItems: THotkeyStorageDataArray;
  I: Integer;
begin
  SetLength(Result, 0);
  if not Assigned(FStorage) then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    DataItems := FStorage.ReadAllHotkeys;
    SetLength(Result, Length(DataItems));
    for I := 0 to High(DataItems) do
    begin
      Result[I].ActionName := DataItems[I].ActionName;
      Result[I].Shortcut := TShortCut(DataItems[I].Shortcut);
      Result[I].DefaultShortcut := TShortCut(DataItems[I].DefaultShortcut);
      Result[I].Category := DataItems[I].Category;
      Result[I].Description := DataItems[I].Description;
      Result[I].IsEnabled := DataItems[I].IsEnabled;
      Result[I].IsCustomized := DataItems[I].IsCustomized;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TUniBaseHotkeys.GetAllHotkeyDefaults: TArray<THotkeyDefault>;
var
  DataItems: THotkeyStorageDataArray;
  I: Integer;
begin
  SetLength(Result, 0);
  if not Assigned(FStorage) then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    DataItems := FStorage.ReadAllHotkeys;
    SetLength(Result, Length(DataItems));
    for I := 0 to High(DataItems) do
    begin
      Result[I].ActionName := DataItems[I].ActionName;
      if DataItems[I].Shortcut = 0 then
        Result[I].Shortcut := ''
      else
        Result[I].Shortcut := UniBaseShortCutToText(TShortCut(DataItems[I].Shortcut));
      Result[I].Description := DataItems[I].Description;
      Result[I].Category := DataItems[I].Category;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TUniBaseHotkeys.IsHotkeyCustomized(const ActionName: string): Boolean;
var
  Shortcut, DefaultShortcut: TShortCut;
begin
  Result := False;
  TMonitor.Enter(FLock);
  try
    if FCache.TryGetValue(ActionName, Shortcut) and 
       FDefaultCache.TryGetValue(ActionName, DefaultShortcut) then
      Result := (Shortcut <> DefaultShortcut);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TUniBaseHotkeys.Count: Integer;
begin
  TMonitor.Enter(FLock);
  try
    Result := FCache.Count;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TUniBaseHotkeys.DeleteHotkey(const ActionName: string);
begin
  if not Assigned(FStorage) then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    FStorage.DeleteHotkey(ActionName);

    FCache.Remove(ActionName);
    FDefaultCache.Remove(ActionName);
  finally
    TMonitor.Exit(FLock);
  end;
end;

end.
