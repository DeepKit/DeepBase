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
  System.Variants,
  System.Generics.Collections,
  Vcl.Menus, // For TShortCut, ShortCutToText, TextToShortCut
  FireDAC.Comp.Client,
  UniBase.Types;

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
  /// Hotkey manager
  /// </summary>
  TUniBaseHotkeys = class
  private
    FConnection: TFDConnection;
    FLock: TObject;
    FOwnsLock: Boolean;
    FCache: TDictionary<string, TShortCut>; // ActionName -> Shortcut
    FDefaultCache: TDictionary<string, TShortCut>; // ActionName -> DefaultShortcut
    
    procedure LoadCache;
    procedure InternalWriteHotkey(const ActionName: string; Shortcut, DefaultShortcut: TShortCut; 
      const Description, Category: string; IsCustomized: Boolean);
    
  public
    constructor Create(AConnection: TFDConnection; ALock: TObject = nil);
    destructor Destroy; override;
    
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
  end;

implementation

uses
  FireDAC.Stan.Param;

{ TUniBaseHotkeys }

constructor TUniBaseHotkeys.Create(AConnection: TFDConnection; ALock: TObject);
begin
  inherited Create;
  FConnection := AConnection;
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
  FCache.Free;
  FDefaultCache.Free;
  if FOwnsLock then
    FLock.Free;
  inherited;
end;

procedure TUniBaseHotkeys.LoadCache;
var
  Query: TFDQuery;
  ActionName: string;
  Shortcut, DefaultShortcut: TShortCut;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    FCache.Clear;
    FDefaultCache.Clear;
    
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'SELECT ActionName, Shortcut, DefaultShortcut FROM Hotkeys WHERE IsEnabled = 1';
      Query.Open;
      
      while not Query.Eof do
      begin
        ActionName := Query.FieldByName('ActionName').AsString;
        // Shortcut 字段可能是整数或文本格式，尝试两种方式读取
        try
          if Query.FieldByName('Shortcut').IsNull then
            Shortcut := 0
          else if VarIsNumeric(Query.FieldByName('Shortcut').Value) then
            Shortcut := Query.FieldByName('Shortcut').AsInteger
          else
            Shortcut := TextToShortCut(Query.FieldByName('Shortcut').AsString);
        except
          Shortcut := 0;
        end;
        
        try
          if Query.FieldByName('DefaultShortcut').IsNull then
            DefaultShortcut := 0
          else if VarIsNumeric(Query.FieldByName('DefaultShortcut').Value) then
            DefaultShortcut := Query.FieldByName('DefaultShortcut').AsInteger
          else
            DefaultShortcut := TextToShortCut(Query.FieldByName('DefaultShortcut').AsString);
        except
          DefaultShortcut := 0;
        end;
        
        FCache.AddOrSetValue(ActionName, Shortcut);
        if DefaultShortcut <> 0 then
          FDefaultCache.AddOrSetValue(ActionName, DefaultShortcut);
          
        Query.Next;
      end;
    finally
      Query.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TUniBaseHotkeys.RegisterDefaultHotkeys(const Defaults: TArray<THotkeyDefault>);
var
  Def: THotkeyDefault;
  Query: TFDQuery;
  ShortcutVal: TShortCut;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      // Use INSERT OR IGNORE to insert only if not exists
      Query.SQL.Text := 
        'INSERT OR IGNORE INTO Hotkeys (ActionName, Shortcut, DefaultShortcut, Category, Description, IsEnabled, IsCustomized) ' +
        'VALUES (:Action, :Shortcut, :Default, :Cat, :Desc, 1, 0)';
        
      for Def in Defaults do
      begin
        ShortcutVal := TextToShortCut(Def.Shortcut);
        
        Query.ParamByName('Action').AsString := Def.ActionName;
        Query.ParamByName('Shortcut').AsInteger := ShortcutVal;
        Query.ParamByName('Default').AsInteger := ShortcutVal;
        Query.ParamByName('Cat').AsString := Def.Category;
        Query.ParamByName('Desc').AsString := Def.Description;
        Query.ExecSQL;
        
        // Add to cache if not exists
        if not FCache.ContainsKey(Def.ActionName) then
        begin
          FCache.Add(Def.ActionName, ShortcutVal);
          FDefaultCache.Add(Def.ActionName, ShortcutVal);
        end;
      end;
    finally
      Query.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TUniBaseHotkeys.InternalWriteHotkey(const ActionName: string; Shortcut, DefaultShortcut: TShortCut; 
  const Description, Category: string; IsCustomized: Boolean);
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
  Query: TFDQuery;
  DefaultShortcut: TShortCut;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      // Restore to default
      Query.SQL.Text := 
        'UPDATE Hotkeys SET Shortcut = DefaultShortcut, IsCustomized = 0 ' +
        'WHERE ActionName = :Action';
      Query.ParamByName('Action').AsString := ActionName;
      Query.ExecSQL;
      
      // Update cache
      if FDefaultCache.TryGetValue(ActionName, DefaultShortcut) then
        FCache.AddOrSetValue(ActionName, DefaultShortcut);
    finally
      Query.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TUniBaseHotkeys.ResetAllHotkeys;
var
  Query: TFDQuery;
  Pair: TPair<string, TShortCut>;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      // Reset all hotkeys to default
      Query.SQL.Text := 'UPDATE Hotkeys SET Shortcut = DefaultShortcut, IsCustomized = 0';
      Query.ExecSQL;
    finally
      Query.Free;
    end;
    
    // Update cache
    for Pair in FDefaultCache do
      FCache.AddOrSetValue(Pair.Key, Pair.Value);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TUniBaseHotkeys.GetAllHotkeys: THotkeyInfoArray;
var
  Query: TFDQuery;
  List: TList<THotkeyInfo>;
  Item: THotkeyInfo;
begin
  SetLength(Result, 0);
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  List := TList<THotkeyInfo>.Create;
  TMonitor.Enter(FLock);
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
        Item.ActionName := Query.FieldByName('ActionName').AsString;
        // Shortcut 字段可能是整数或文本格式
        try
          if Query.FieldByName('Shortcut').IsNull then
            Item.Shortcut := 0
          else if VarIsNumeric(Query.FieldByName('Shortcut').Value) then
            Item.Shortcut := Query.FieldByName('Shortcut').AsInteger
          else
            Item.Shortcut := TextToShortCut(Query.FieldByName('Shortcut').AsString);
        except
          Item.Shortcut := 0;
        end;
        try
          if Query.FieldByName('DefaultShortcut').IsNull then
            Item.DefaultShortcut := 0
          else if VarIsNumeric(Query.FieldByName('DefaultShortcut').Value) then
            Item.DefaultShortcut := Query.FieldByName('DefaultShortcut').AsInteger
          else
            Item.DefaultShortcut := TextToShortCut(Query.FieldByName('DefaultShortcut').AsString);
        except
          Item.DefaultShortcut := 0;
        end;
        Item.Category := Query.FieldByName('Category').AsString;
        Item.Description := Query.FieldByName('Description').AsString;
        Item.IsEnabled := Query.FieldByName('IsEnabled').AsInteger <> 0;
        Item.IsCustomized := Query.FieldByName('IsCustomized').AsInteger <> 0;
        List.Add(Item);
        Query.Next;
      end;
    finally
      Query.Free;
    end;
    Result := List.ToArray;
  finally
    List.Free;
    TMonitor.Exit(FLock);
  end;
end;

function TUniBaseHotkeys.GetAllHotkeyDefaults: TArray<THotkeyDefault>;
var
  Query: TFDQuery;
  List: TList<THotkeyDefault>;
  Item: THotkeyDefault;
begin
  SetLength(Result, 0);
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  List := TList<THotkeyDefault>.Create;
  TMonitor.Enter(FLock);
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'SELECT ActionName, Shortcut, Description, Category FROM Hotkeys ORDER BY Category, ActionName';
      Query.Open;
      
      while not Query.Eof do
      begin
        Item.ActionName := Query.FieldByName('ActionName').AsString;
        // Shortcut 字段可能是整数或文本格式
        try
          if Query.FieldByName('Shortcut').IsNull then
            Item.Shortcut := ''
          else if VarIsNumeric(Query.FieldByName('Shortcut').Value) then
            Item.Shortcut := ShortCutToText(Query.FieldByName('Shortcut').AsInteger)
          else
            Item.Shortcut := Query.FieldByName('Shortcut').AsString;
        except
          Item.Shortcut := '';
        end;
        Item.Description := Query.FieldByName('Description').AsString;
        Item.Category := Query.FieldByName('Category').AsString;
        List.Add(Item);
        Query.Next;
      end;
    finally
      Query.Free;
    end;
    Result := List.ToArray;
  finally
    List.Free;
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

end.
