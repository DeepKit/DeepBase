{ ============================================================================
  UniBase.MRU - Most Recently Used Module
  
  Version: 1.0
  Description: Manages various types of MRU (Most Recently Used) lists.
  Thread Safety: All public methods are thread-safe.
  ============================================================================ }

unit UniBase.MRU;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  FireDAC.Comp.Client,
  UniBase.Types;

type
  /// <summary>
  /// MRU manager
  /// </summary>
  TUniBaseMRU = class
  private
    FConnection: TFDConnection;
    FLock: TObject;
    FOwnsLock: Boolean;
    
    procedure WriteMRU(const Category, ItemKey, DisplayName: string; IconIndex: Integer);
    procedure InternalRemoveMRU(const Category, ItemKey: string);
    
  public
    constructor Create(AConnection: TFDConnection; ALock: TObject = nil);
    destructor Destroy; override;
    
    // ========================================
    // Core Methods
    // ========================================
    
    /// <summary>
    /// 添加或更新 MRU 项
    /// </summary>
    /// <param name="Category">类别：File, Project, Command, Search 等</param>
    /// <param name="ItemKey">唯一键（如文件路径）</param>
    /// <param name="DisplayName">显示名称（可选，不提供则使用 ItemKey）</param>
    /// <param name="IconIndex">图标索引（可选）</param>
    procedure AddMRU(const Category, ItemKey: string; const DisplayName: string = ''; IconIndex: Integer = 0);
    
    /// <summary>
    /// 获取 MRU 列表 (仅返回 ItemKey)
    /// </summary>
    function GetMRUList(const Category: string; MaxItems: Integer = 10): TArray<string>;
    
    /// <summary>
    /// 获取 MRU 完整项列表
    /// </summary>
    function GetMRUItems(const Category: string; MaxItems: Integer = 10): TMRUItemArray;
    
    /// <summary>
    /// 清空指定类别的 MRU
    /// </summary>
    procedure ClearMRU(const Category: string);
    
    /// <summary>
    /// 移除单个 MRU 项
    /// </summary>
    procedure RemoveMRU(const Category, ItemKey: string);
    
    /// <summary>
    /// 移除不存在的文件路径 MRU 项
    /// </summary>
    /// <param name="Category">类别（留空则检查所有文件相关类别）</param>
    /// <returns>移除的项数</returns>
    function RemoveInvalidMRU(const Category: string = ''): Integer;
    
    // ========================================
    // Pinning
    // ========================================
    
    /// <summary>
    /// 置顶/取消置顶 MRU 项
    /// </summary>
    procedure SetPinned(const Category, ItemKey: string; IsPinned: Boolean);
    
    /// <summary>
    /// 检查是否置顶
    /// </summary>
    function IsPinned(const Category, ItemKey: string): Boolean;
    
    // ========================================
    // Statistics
    // ========================================
    
    /// <summary>
    /// 获取 MRU 项数量
    /// </summary>
    function GetMRUCount(const Category: string): Integer;
    
    /// <summary>
    /// 获取访问次数
    /// </summary>
    function GetAccessCount(const Category, ItemKey: string): Integer;
    
    // Backward compatibility
    procedure DeleteMRU(const Category, ItemKey: string); deprecated 'Use RemoveMRU instead';
    procedure RemoveInvalidFileMRU(const Category: string); deprecated 'Use RemoveInvalidMRU instead';
  end;

implementation

uses
  System.IOUtils,
  System.DateUtils,
  FireDAC.Stan.Param;

{ TUniBaseMRU }

constructor TUniBaseMRU.Create(AConnection: TFDConnection; ALock: TObject);
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
end;

destructor TUniBaseMRU.Destroy;
begin
  if FOwnsLock then
    FLock.Free;
  inherited;
end;

procedure TUniBaseMRU.WriteMRU(const Category, ItemKey, DisplayName: string; IconIndex: Integer);
var
  Query: TFDQuery;
  ActualDisplayName: string;
  NowStr: string;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
  if (Category = '') or (ItemKey = '') then
    Exit;
    
  ActualDisplayName := DisplayName;
  if ActualDisplayName = '' then
    ActualDisplayName := ItemKey;
  
  // Use ISO8601 format for SQLite datetime compatibility
  NowStr := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now);
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    
    // 使用 SQLite UPSERT 语法
    Query.SQL.Text := 
      'INSERT INTO MRU (Category, ItemKey, DisplayName, IconIndex, LastAccess, AccessCount, IsPinned) ' +
      'VALUES (:Cat, :Key, :Display, :Icon, :NowTime, 1, 0) ' +
      'ON CONFLICT(Category, ItemKey) DO UPDATE SET ' +
      'DisplayName = :Display, IconIndex = :Icon, ' +
      'LastAccess = :NowTime, ' +
      'AccessCount = AccessCount + 1';
      
    Query.ParamByName('Cat').AsString := Category;
    Query.ParamByName('Key').AsString := ItemKey;
    Query.ParamByName('Display').AsString := ActualDisplayName;
    Query.ParamByName('Icon').AsInteger := IconIndex;
    Query.ParamByName('NowTime').AsString := NowStr;
    
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

procedure TUniBaseMRU.InternalRemoveMRU(const Category, ItemKey: string);
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'DELETE FROM MRU WHERE Category = :Cat AND ItemKey = :Key';
    Query.ParamByName('Cat').AsString := Category;
    Query.ParamByName('Key').AsString := ItemKey;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

procedure TUniBaseMRU.AddMRU(const Category, ItemKey: string; const DisplayName: string; IconIndex: Integer);
begin
  TMonitor.Enter(FLock);
  try
    WriteMRU(Category, ItemKey, DisplayName, IconIndex);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TUniBaseMRU.RemoveMRU(const Category, ItemKey: string);
begin
  TMonitor.Enter(FLock);
  try
    InternalRemoveMRU(Category, ItemKey);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TUniBaseMRU.DeleteMRU(const Category, ItemKey: string);
begin
  RemoveMRU(Category, ItemKey);
end;

procedure TUniBaseMRU.ClearMRU(const Category: string);
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'DELETE FROM MRU WHERE Category = :Category';
      Query.ParamByName('Category').AsString := Category;
      Query.ExecSQL;
    finally
      Query.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TUniBaseMRU.GetMRUList(const Category: string; MaxItems: Integer): TArray<string>;
var
  Items: TMRUItemArray;
  I: Integer;
begin
  Items := GetMRUItems(Category, MaxItems);
  SetLength(Result, Length(Items));
  for I := 0 to High(Items) do
    Result[I] := Items[I].ItemKey;
end;

function TUniBaseMRU.GetMRUItems(const Category: string; MaxItems: Integer): TMRUItemArray;
var
  Query: TFDQuery;
  List: TList<TMRUItem>;
  Item: TMRUItem;
begin
  SetLength(Result, 0);
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  List := TList<TMRUItem>.Create;
  TMonitor.Enter(FLock);
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
        // Pinned items first, then by last access time desc
      Query.SQL.Text := 
        'SELECT ItemKey, DisplayName, LastAccess, AccessCount, IconIndex, IsPinned ' +
        'FROM MRU WHERE Category = :Cat ' +
        'ORDER BY IsPinned DESC, LastAccess DESC ' +
        'LIMIT :Max';
      Query.ParamByName('Cat').AsString := Category;
      Query.ParamByName('Max').AsInteger := MaxItems;
      Query.Open;
      
      while not Query.Eof do
      begin
        Item.ItemKey := Query.FieldByName('ItemKey').AsString;
        Item.DisplayName := Query.FieldByName('DisplayName').AsString;
        if Item.DisplayName = '' then
          Item.DisplayName := Item.ItemKey;
          
        Item.LastAccess := Query.FieldByName('LastAccess').AsDateTime;
        Item.AccessCount := Query.FieldByName('AccessCount').AsInteger;
        Item.IconIndex := Query.FieldByName('IconIndex').AsInteger;
        
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

function TUniBaseMRU.RemoveInvalidMRU(const Category: string): Integer;
var
  Query, DeleteQuery: TFDQuery;
  ItemKey, Cat: string;
  ToDelete: TList<TPair<string, string>>;
  Pair: TPair<string, string>;
begin
  Result := 0;
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  ToDelete := TList<TPair<string, string>>.Create;
  try
    TMonitor.Enter(FLock);
    try
      Query := TFDQuery.Create(nil);
      try
        Query.Connection := FConnection;
        
        // Only check file-related categories
        if Category <> '' then
        begin
          Query.SQL.Text := 'SELECT Category, ItemKey FROM MRU WHERE Category = :Cat';
          Query.ParamByName('Cat').AsString := Category;
        end
        else
          Query.SQL.Text := 
            'SELECT Category, ItemKey FROM MRU WHERE Category IN (''File'', ''Project'', ''RecentFiles'', ''RecentProjects'')';
            
        Query.Open;
        
        while not Query.Eof do
        begin
          Cat := Query.FieldByName('Category').AsString;
          ItemKey := Query.FieldByName('ItemKey').AsString;
          
          // Check if file path and does not exist
          if (ItemKey <> '') and 
             ((ItemKey[1] = '/') or ((Length(ItemKey) > 1) and (ItemKey[2] = ':'))) then
          begin
            if not FileExists(ItemKey) and not DirectoryExists(ItemKey) then
              ToDelete.Add(TPair<string, string>.Create(Cat, ItemKey));
          end;
          
          Query.Next;
        end;
      finally
        Query.Free;
      end;
      
      // Delete invalid items
      if ToDelete.Count > 0 then
      begin
        DeleteQuery := TFDQuery.Create(nil);
        try
          DeleteQuery.Connection := FConnection;
          DeleteQuery.SQL.Text := 'DELETE FROM MRU WHERE Category = :Cat AND ItemKey = :Key';
          
          for Pair in ToDelete do
          begin
            DeleteQuery.ParamByName('Cat').AsString := Pair.Key;
            DeleteQuery.ParamByName('Key').AsString := Pair.Value;
            DeleteQuery.ExecSQL;
          end;
          
          Result := ToDelete.Count;
        finally
          DeleteQuery.Free;
        end;
      end;
    finally
      TMonitor.Exit(FLock);
    end;
  finally
    ToDelete.Free;
  end;
end;

procedure TUniBaseMRU.RemoveInvalidFileMRU(const Category: string);
begin
  RemoveInvalidMRU(Category);
end;

procedure TUniBaseMRU.SetPinned(const Category, ItemKey: string; IsPinned: Boolean);
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 
        'UPDATE MRU SET IsPinned = :Pinned WHERE Category = :Cat AND ItemKey = :Key';
      Query.ParamByName('Pinned').AsInteger := Ord(IsPinned);
      Query.ParamByName('Cat').AsString := Category;
      Query.ParamByName('Key').AsString := ItemKey;
      Query.ExecSQL;
    finally
      Query.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TUniBaseMRU.IsPinned(const Category, ItemKey: string): Boolean;
var
  Query: TFDQuery;
begin
  Result := False;
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 
        'SELECT IsPinned FROM MRU WHERE Category = :Cat AND ItemKey = :Key';
      Query.ParamByName('Cat').AsString := Category;
      Query.ParamByName('Key').AsString := ItemKey;
      Query.Open;
      
      if not Query.Eof then
        Result := Query.FieldByName('IsPinned').AsInteger <> 0;
    finally
      Query.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TUniBaseMRU.GetMRUCount(const Category: string): Integer;
var
  Query: TFDQuery;
begin
  Result := 0;
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'SELECT COUNT(*) FROM MRU WHERE Category = :Cat';
      Query.ParamByName('Cat').AsString := Category;
      Query.Open;
      
      Result := Query.Fields[0].AsInteger;
    finally
      Query.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TUniBaseMRU.GetAccessCount(const Category, ItemKey: string): Integer;
var
  Query: TFDQuery;
begin
  Result := 0;
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 
        'SELECT AccessCount FROM MRU WHERE Category = :Cat AND ItemKey = :Key';
      Query.ParamByName('Cat').AsString := Category;
      Query.ParamByName('Key').AsString := ItemKey;
      Query.Open;
      
      if not Query.Eof then
        Result := Query.FieldByName('AccessCount').AsInteger;
    finally
      Query.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

end.
