{ ============================================================================
  DeepBase.Hotkeys - Hotkey Management Module
  
  Version: 1.0
  Description: Manages user-defined hotkeys and conflict detection.
  Thread Safety: All public methods are thread-safe.
  ============================================================================ }

unit DeepBase.Hotkeys;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Winapi.Windows,
  Winapi.Messages,
  DeepBase.Types,
  DeepBase.Storage.Interfaces;

function DeepBaseTextToShortCut(const Text: string): TShortCut;
function DeepBaseShortCutToText(Shortcut: TShortCut): string;

type
  THotkeyScope = (
    hsGlobal,
    hsApplication,
    hsForm,
    hsEditor
  );

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
    Scope: THotkeyScope;
  end;
  THotkeyInfoArray = TArray<THotkeyInfo>;

  /// <summary>
  /// Hotkey changed callback type
  /// </summary>
  THotkeyChangedProc = reference to procedure(const ActionName: string);
  THotkeyActionProc = reference to procedure(const ActionName: string);

  /// <summary>
  /// Platform abstraction for global hotkey APIs.
  /// </summary>
  IDeepBaseGlobalHotkeyPlatform = interface
    ['{9D04A51A-E20E-4F0D-817E-951E54E5A404}']
    function RegisterHotKey(const AHandle: HWND; const AHotkeyId: Integer;
      const AModifiers, AVirtualKey: UINT): Boolean;
    function UnregisterHotKey(const AHandle: HWND;
      const AHotkeyId: Integer): Boolean;
  end;

  /// <summary>
  /// Default Windows platform implementation for global hotkeys.
  /// </summary>
  TDeepBaseWinHotkeyPlatform = class(TInterfacedObject, IDeepBaseGlobalHotkeyPlatform)
  public
    function RegisterHotKey(const AHandle: HWND; const AHotkeyId: Integer;
      const AModifiers, AVirtualKey: UINT): Boolean;
    function UnregisterHotKey(const AHandle: HWND;
      const AHotkeyId: Integer): Boolean;
  end;

  /// <summary>
  /// Global hotkey registrar with duplicate-registration guard and WM_HOTKEY dispatch helper.
  /// </summary>
  TDeepBaseGlobalHotkeys = class
  private
    FHandle: HWND;
    FPlatform: IDeepBaseGlobalHotkeyPlatform;
    FLock: TObject;
    FOwnsLock: Boolean;
    FRegistered: TDictionary<Integer, TShortCut>;
    class function GetModifiers(AShortcut: TShortCut): UINT; static;
    class function GetVirtualKey(AShortcut: TShortCut): UINT; static;
  public
    constructor Create(const AHandle: HWND = 0;
      const APlatform: IDeepBaseGlobalHotkeyPlatform = nil;
      ALock: TObject = nil);
    destructor Destroy; override;
    function Register(const AHotkeyId: Integer; AShortcut: TShortCut): Boolean;
    function Unregister(const AHotkeyId: Integer): Boolean;
    procedure UnregisterAll;
    function IsRegistered(const AHotkeyId: Integer): Boolean;
    function Count: Integer;
    function DispatchMessage(const AMsg: TMsg; out AHotkeyId: Integer): Boolean;
  end;

  /// <summary>
  /// Hotkey manager
  /// </summary>
  TDeepBaseHotkeys = class
  private
    FConnection: TObject;
    FStorage: IHotkeyStorage;
    FLock: TObject;
    FOwnsLock: Boolean;
    FCache: TDictionary<string, TShortCut>; // ActionName -> Shortcut
    FDefaultCache: TDictionary<string, TShortCut>; // ActionName -> DefaultShortcut
    FScopeCache: TDictionary<string, THotkeyScope>; // ActionName -> Scope
    FActionBindings: TDictionary<string, THotkeyActionProc>; // ActionName -> Handler
    FOnHotkeyChanged: THotkeyChangedProc;
    class var FConnectionStorageFactory: TFunc<TObject, IHotkeyStorage>;
    
    procedure LoadCache;
    function GetHotkeyScopeNoLock(const ActionName: string): THotkeyScope;
    function TryResolveActionByShortcutNoLock(Shortcut: TShortCut;
      Scope: THotkeyScope; const ExcludeActionName: string;
      out ActionName: string): Boolean;
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
    /// ��ȡ��ݼ�
    /// </summary>
    function GetHotkey(const ActionName: string): TShortCut;
    
    /// <summary>
    /// ���ÿ�ݼ�
    /// </summary>
    procedure SetHotkey(const ActionName: string; Shortcut: TShortCut);
    
    /// <summary>
    /// ע��Ĭ�Ͽ�ݼ���ֻ�ڲ�����ʱ���룩
    /// </summary>
    procedure RegisterDefaultHotkeys(const Defaults: TArray<THotkeyDefault>);
    
    // ========================================
    // Reset Functions
    // ========================================
    
    /// <summary>
    /// ���õ�����ݼ�ΪĬ��ֵ
    /// </summary>
    procedure ResetHotkey(const ActionName: string);
    
    /// <summary>
    /// �������п�ݼ�ΪĬ��ֵ
    /// </summary>
    procedure ResetAllHotkeys;
    
    // ========================================
    // Conflict Detection
    // ========================================
    
    /// <summary>
    /// ����ݼ���ͻ
    /// </summary>
    /// <returns>��ͻ�� ActionName���޳�ͻ���ؿ��ַ���</returns>
    function CheckHotkeyConflict(Shortcut: TShortCut; const ExcludeActionName: string = ''): string;
    function CheckHotkeyConflictInScope(Shortcut: TShortCut;
      Scope: THotkeyScope; const ExcludeActionName: string = ''): string;

    // ========================================
    // Scope and Action Binding
    // ========================================
    procedure SetHotkeyScope(const ActionName: string; Scope: THotkeyScope);
    function GetHotkeyScope(const ActionName: string): THotkeyScope;
    procedure BindAction(const ActionName: string; const AHandler: THotkeyActionProc);
    procedure UnbindAction(const ActionName: string);
    procedure ClearActionBindings;
    function ExecuteAction(const ActionName: string): Boolean;
    function TriggerShortcut(Shortcut: TShortCut; Scope: THotkeyScope): Boolean;
    
    // ========================================
    // Query Methods
    // ========================================
    
    /// <summary>
    /// ��ȡ���п�ݼ���Ϣ
    /// </summary>
    function GetAllHotkeys: THotkeyInfoArray;
    
    /// <summary>
    /// ��ȡ��ݼ���ϸ��Ϣ (�������ý���)
    /// </summary>
    function GetAllHotkeyDefaults: TArray<THotkeyDefault>;
    
    /// <summary>
    /// ����ݼ��Ƿ��޸Ĺ�
    /// </summary>
    function IsHotkeyCustomized(const ActionName: string): Boolean;
    
    /// <summary>
    /// ��ݼ�����
    /// </summary>
    function Count: Integer;
    
    /// <summary>
    /// ɾ����ݼ�
    /// </summary>
    procedure DeleteHotkey(const ActionName: string);
    
    /// <summary>
    /// ��ݼ�����¼�
    /// </summary>
    property OnHotkeyChanged: THotkeyChangedProc read FOnHotkeyChanged write FOnHotkeyChanged;
  end;

implementation

function DeepBaseTextToShortCut(const Text: string): TShortCut;
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

function DeepBaseShortCutToText(Shortcut: TShortCut): string;
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

{ TDeepBaseWinHotkeyPlatform }

function TDeepBaseWinHotkeyPlatform.RegisterHotKey(const AHandle: HWND;
  const AHotkeyId: Integer; const AModifiers, AVirtualKey: UINT): Boolean;
begin
  Result := Winapi.Windows.RegisterHotKey(AHandle, AHotkeyId, AModifiers,
    AVirtualKey);
end;

function TDeepBaseWinHotkeyPlatform.UnregisterHotKey(const AHandle: HWND;
  const AHotkeyId: Integer): Boolean;
begin
  Result := Winapi.Windows.UnregisterHotKey(AHandle, AHotkeyId);
end;

{ TDeepBaseGlobalHotkeys }

constructor TDeepBaseGlobalHotkeys.Create(const AHandle: HWND;
  const APlatform: IDeepBaseGlobalHotkeyPlatform; ALock: TObject);
begin
  inherited Create;
  FHandle := AHandle;
  FPlatform := APlatform;
  if not Assigned(FPlatform) then
    FPlatform := TDeepBaseWinHotkeyPlatform.Create;

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

  FRegistered := TDictionary<Integer, TShortCut>.Create;
end;

destructor TDeepBaseGlobalHotkeys.Destroy;
begin
  UnregisterAll;
  FRegistered.Free;
  if FOwnsLock then
    FLock.Free;
  inherited;
end;

class function TDeepBaseGlobalHotkeys.GetModifiers(AShortcut: TShortCut): UINT;
begin
  Result := 0;
  if (AShortcut and scAlt) <> 0 then
    Result := Result or MOD_ALT;
  if (AShortcut and scCtrl) <> 0 then
    Result := Result or MOD_CONTROL;
  if (AShortcut and scShift) <> 0 then
    Result := Result or MOD_SHIFT;
end;

class function TDeepBaseGlobalHotkeys.GetVirtualKey(AShortcut: TShortCut): UINT;
begin
  Result := UINT(AShortcut and not (scAlt or scCtrl or scShift));
end;

function TDeepBaseGlobalHotkeys.Register(const AHotkeyId: Integer;
  AShortcut: TShortCut): Boolean;
var
  Modifiers: UINT;
  VirtualKey: UINT;
begin
  Result := False;
  if (AHotkeyId <= 0) or (AShortcut = 0) then
    Exit;

  Modifiers := GetModifiers(AShortcut);
  VirtualKey := GetVirtualKey(AShortcut);
  if VirtualKey = 0 then
    Exit;

  TMonitor.Enter(FLock);
  try
    if FRegistered.ContainsKey(AHotkeyId) then
      Exit;

    Result := FPlatform.RegisterHotKey(FHandle, AHotkeyId, Modifiers,
      VirtualKey);
    if Result then
      FRegistered.Add(AHotkeyId, AShortcut);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TDeepBaseGlobalHotkeys.Unregister(const AHotkeyId: Integer): Boolean;
begin
  Result := False;
  TMonitor.Enter(FLock);
  try
    if not FRegistered.ContainsKey(AHotkeyId) then
      Exit;

    Result := FPlatform.UnregisterHotKey(FHandle, AHotkeyId);
    if Result then
      FRegistered.Remove(AHotkeyId);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TDeepBaseGlobalHotkeys.UnregisterAll;
var
  Ids: TArray<Integer>;
  Id: Integer;
begin
  TMonitor.Enter(FLock);
  try
    Ids := FRegistered.Keys.ToArray;
    for Id in Ids do
      if FPlatform.UnregisterHotKey(FHandle, Id) then
        FRegistered.Remove(Id);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TDeepBaseGlobalHotkeys.IsRegistered(const AHotkeyId: Integer): Boolean;
begin
  TMonitor.Enter(FLock);
  try
    Result := FRegistered.ContainsKey(AHotkeyId);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TDeepBaseGlobalHotkeys.Count: Integer;
begin
  TMonitor.Enter(FLock);
  try
    Result := FRegistered.Count;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TDeepBaseGlobalHotkeys.DispatchMessage(const AMsg: TMsg;
  out AHotkeyId: Integer): Boolean;
begin
  AHotkeyId := 0;
  Result := (AMsg.message = WM_HOTKEY);
  if not Result then
    Exit;

  AHotkeyId := Integer(AMsg.wParam);
  TMonitor.Enter(FLock);
  try
    Result := FRegistered.ContainsKey(AHotkeyId);
  finally
    TMonitor.Exit(FLock);
  end;
end;

{ TDeepBaseHotkeys }

constructor TDeepBaseHotkeys.Create(AConnection: TObject; ALock: TObject);
begin
  Create(CreateStorageFromConnection(AConnection), ALock);
  FConnection := AConnection;
end;

constructor TDeepBaseHotkeys.Create(const AStorage: IHotkeyStorage;
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
  FScopeCache := TDictionary<string, THotkeyScope>.Create;
  FActionBindings := TDictionary<string, THotkeyActionProc>.Create;
  LoadCache;
end;

destructor TDeepBaseHotkeys.Destroy;
begin
  ClearActionBindings;
  FreeAndNil(FActionBindings);
  FreeAndNil(FScopeCache);
  FreeAndNil(FCache);
  FreeAndNil(FDefaultCache);
  if FOwnsLock then
    FreeAndNil(FLock);
  inherited;
end;

class procedure TDeepBaseHotkeys.SetConnectionStorageFactory(
  const AFactory: TFunc<TObject, IHotkeyStorage>);
begin
  FConnectionStorageFactory := AFactory;
end;

class function TDeepBaseHotkeys.CreateStorageFromConnection(
  AConnection: TObject): IHotkeyStorage;
begin
  Result := nil;
  if Assigned(AConnection) and Assigned(FConnectionStorageFactory) then
    Result := FConnectionStorageFactory(AConnection);
  if (Result = nil) and Assigned(AConnection) then
    raise EInvalidOp.Create(
      'No hotkey storage factory registered for connection-backed constructor. ' +
      'Include DeepBase.Persistence.Hotkeys.FireDAC or DeepBase.Persistence.Manager.FireDAC.');
end;

function TDeepBaseHotkeys.GetHotkeyScopeNoLock(
  const ActionName: string): THotkeyScope;
begin
  if not FScopeCache.TryGetValue(ActionName, Result) then
    Result := hsApplication;
end;

function TDeepBaseHotkeys.TryResolveActionByShortcutNoLock(Shortcut: TShortCut;
  Scope: THotkeyScope; const ExcludeActionName: string;
  out ActionName: string): Boolean;
var
  Pair: TPair<string, TShortCut>;
begin
  Result := False;
  ActionName := '';
  if Shortcut = 0 then
    Exit;

  for Pair in FCache do
  begin
    if (Pair.Value = Shortcut) and (Pair.Key <> ExcludeActionName) and
       (GetHotkeyScopeNoLock(Pair.Key) = Scope) then
    begin
      ActionName := Pair.Key;
      Result := True;
      Exit;
    end;
  end;
end;

procedure TDeepBaseHotkeys.LoadCache;
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
    FScopeCache.Clear;

    Items := FStorage.ReadEnabledHotkeys;
    for Item in Items do
    begin
      FCache.AddOrSetValue(Item.ActionName, TShortCut(Item.Shortcut));
      FScopeCache.AddOrSetValue(Item.ActionName, hsApplication);
      if Item.DefaultShortcut <> 0 then
        FDefaultCache.AddOrSetValue(Item.ActionName,
          TShortCut(Item.DefaultShortcut));
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TDeepBaseHotkeys.RegisterDefaultHotkeys(const Defaults: TArray<THotkeyDefault>);
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
      ShortcutVal := DeepBaseTextToShortCut(Def.Shortcut);
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
    begin
      if not FCache.ContainsKey(StorageDefaults[I].ActionName) then
      begin
        FCache.Add(StorageDefaults[I].ActionName,
          TShortCut(StorageDefaults[I].Shortcut));
        FDefaultCache.Add(StorageDefaults[I].ActionName,
          TShortCut(StorageDefaults[I].DefaultShortcut));
      end;

      if not FScopeCache.ContainsKey(StorageDefaults[I].ActionName) then
        FScopeCache.Add(StorageDefaults[I].ActionName, hsApplication);
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TDeepBaseHotkeys.InternalWriteHotkey(const ActionName: string; Shortcut, DefaultShortcut: TShortCut; 
  const Description, Category: string; IsCustomized: Boolean);
begin
  if Assigned(FStorage) then
    FStorage.UpdateShortcut(ActionName, Word(Shortcut), IsCustomized);
end;

procedure TDeepBaseHotkeys.DoHotkeyChanged(const ActionName: string);
begin
  if Assigned(FOnHotkeyChanged) then
    FOnHotkeyChanged(ActionName);
end;

procedure TDeepBaseHotkeys.SetHotkey(const ActionName: string; Shortcut: TShortCut);
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
    if not FScopeCache.ContainsKey(ActionName) then
      FScopeCache.Add(ActionName, hsApplication);
  finally
    TMonitor.Exit(FLock);
  end;
  DoHotkeyChanged(ActionName);
end;

function TDeepBaseHotkeys.GetHotkey(const ActionName: string): TShortCut;
begin
  TMonitor.Enter(FLock);
  try
    if not FCache.TryGetValue(ActionName, Result) then
      Result := 0;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TDeepBaseHotkeys.CheckHotkeyConflict(Shortcut: TShortCut; const ExcludeActionName: string): string;
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

function TDeepBaseHotkeys.CheckHotkeyConflictInScope(Shortcut: TShortCut;
  Scope: THotkeyScope; const ExcludeActionName: string): string;
begin
  Result := '';
  TMonitor.Enter(FLock);
  try
    TryResolveActionByShortcutNoLock(Shortcut, Scope, ExcludeActionName, Result);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TDeepBaseHotkeys.SetHotkeyScope(const ActionName: string;
  Scope: THotkeyScope);
begin
  if ActionName = '' then
    Exit;

  TMonitor.Enter(FLock);
  try
    FScopeCache.AddOrSetValue(ActionName, Scope);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TDeepBaseHotkeys.GetHotkeyScope(const ActionName: string): THotkeyScope;
begin
  TMonitor.Enter(FLock);
  try
    Result := GetHotkeyScopeNoLock(ActionName);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TDeepBaseHotkeys.BindAction(const ActionName: string;
  const AHandler: THotkeyActionProc);
begin
  if ActionName = '' then
    Exit;

  TMonitor.Enter(FLock);
  try
    if Assigned(AHandler) then
      FActionBindings.AddOrSetValue(ActionName, AHandler)
    else
      FActionBindings.Remove(ActionName);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TDeepBaseHotkeys.UnbindAction(const ActionName: string);
begin
  if ActionName = '' then
    Exit;

  TMonitor.Enter(FLock);
  try
    FActionBindings.Remove(ActionName);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TDeepBaseHotkeys.ClearActionBindings;
begin
  TMonitor.Enter(FLock);
  try
    FActionBindings.Clear;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TDeepBaseHotkeys.ExecuteAction(const ActionName: string): Boolean;
var
  Handler: THotkeyActionProc;
begin
  Result := False;
  Handler := nil;
  if ActionName = '' then
    Exit;

  TMonitor.Enter(FLock);
  try
    FActionBindings.TryGetValue(ActionName, Handler);
  finally
    TMonitor.Exit(FLock);
  end;

  if not Assigned(Handler) then
    Exit(False);

  Handler(ActionName);
  Result := True;
end;

function TDeepBaseHotkeys.TriggerShortcut(Shortcut: TShortCut;
  Scope: THotkeyScope): Boolean;
var
  ActionName: string;
begin
  ActionName := '';
  TMonitor.Enter(FLock);
  try
    if not TryResolveActionByShortcutNoLock(Shortcut, Scope, '', ActionName) then
      Exit(False);
  finally
    TMonitor.Exit(FLock);
  end;

  Result := ExecuteAction(ActionName);
end;

procedure TDeepBaseHotkeys.ResetHotkey(const ActionName: string);
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

procedure TDeepBaseHotkeys.ResetAllHotkeys;
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

function TDeepBaseHotkeys.GetAllHotkeys: THotkeyInfoArray;
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
      Result[I].Scope := GetHotkeyScopeNoLock(DataItems[I].ActionName);
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TDeepBaseHotkeys.GetAllHotkeyDefaults: TArray<THotkeyDefault>;
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
        Result[I].Shortcut := DeepBaseShortCutToText(TShortCut(DataItems[I].Shortcut));
      Result[I].Description := DataItems[I].Description;
      Result[I].Category := DataItems[I].Category;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TDeepBaseHotkeys.IsHotkeyCustomized(const ActionName: string): Boolean;
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

function TDeepBaseHotkeys.Count: Integer;
begin
  TMonitor.Enter(FLock);
  try
    Result := FCache.Count;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TDeepBaseHotkeys.DeleteHotkey(const ActionName: string);
begin
  if not Assigned(FStorage) then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    FStorage.DeleteHotkey(ActionName);

    FCache.Remove(ActionName);
    FDefaultCache.Remove(ActionName);
    FScopeCache.Remove(ActionName);
    FActionBindings.Remove(ActionName);
  finally
    TMonitor.Exit(FLock);
  end;
end;

end.
