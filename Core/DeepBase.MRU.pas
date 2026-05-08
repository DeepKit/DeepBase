{ ============================================================================
  DeepBase.MRU - Most Recently Used Module

  Version: 1.0
  Description: Manages various types of MRU (Most Recently Used) lists.
  Thread Safety: All public methods are thread-safe.
  ============================================================================ }

unit DeepBase.MRU;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  DeepBase.Types,
  DeepBase.Storage.Interfaces;

type
  /// <summary>
  /// MRU manager
  /// </summary>
  TDeepBaseMRU = class
  private
    FConnection: TObject;
    FStorage: IMRUStorage;
    FLock: TObject;
    FOwnsLock: Boolean;
    class var FConnectionStorageFactory: TFunc<TObject, IMRUStorage>;

    procedure WriteMRU(const Category, ItemKey, DisplayName: string;
      IconIndex: Integer);
    procedure InternalRemoveMRU(const Category, ItemKey: string);
    class function CreateStorageFromConnection(
      AConnection: TObject): IMRUStorage; static;

  public
    constructor Create(AConnection: TObject; ALock: TObject = nil); overload;
    constructor Create(const AStorage: IMRUStorage; ALock: TObject = nil); overload;
    destructor Destroy; override;

    class procedure SetConnectionStorageFactory(
      const AFactory: TFunc<TObject, IMRUStorage>); static;

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
    procedure AddMRU(const Category, ItemKey: string;
      const DisplayName: string = ''; IconIndex: Integer = 0);

    /// <summary>
    /// 获取 MRU 列表 (仅返回 ItemKey)
    /// </summary>
    function GetMRUList(const Category: string;
      MaxItems: Integer = 10): TArray<string>;

    /// <summary>
    /// 获取 MRU 完整项列表
    /// </summary>
    function GetMRUItems(const Category: string;
      MaxItems: Integer = 10): TMRUItemArray;

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
    procedure DeleteMRU(const Category, ItemKey: string);
      deprecated 'Use RemoveMRU instead';
    procedure RemoveInvalidFileMRU(const Category: string);
      deprecated 'Use RemoveInvalidMRU instead';
  end;

implementation

uses
  System.IOUtils;

{ TDeepBaseMRU }

constructor TDeepBaseMRU.Create(AConnection: TObject; ALock: TObject);
begin
  Create(CreateStorageFromConnection(AConnection), ALock);
  FConnection := AConnection;
end;

constructor TDeepBaseMRU.Create(const AStorage: IMRUStorage; ALock: TObject);
begin
  inherited Create;
  FStorage := AStorage;
  if Assigned(ALock) then
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

destructor TDeepBaseMRU.Destroy;
begin
  if FOwnsLock then
    FreeAndNil(FLock);
  inherited;
end;

class procedure TDeepBaseMRU.SetConnectionStorageFactory(
  const AFactory: TFunc<TObject, IMRUStorage>);
begin
  FConnectionStorageFactory := AFactory;
end;

class function TDeepBaseMRU.CreateStorageFromConnection(
  AConnection: TObject): IMRUStorage;
begin
  Result := nil;
  if Assigned(AConnection) and Assigned(FConnectionStorageFactory) then
    Result := FConnectionStorageFactory(AConnection);
  if (Result = nil) and Assigned(AConnection) then
    raise EInvalidOp.Create(
      'No MRU storage factory registered for connection-backed constructor. ' +
      'Include DeepBase.Persistence.MRU.FireDAC or DeepBase.Persistence.Manager.FireDAC.');
end;

procedure TDeepBaseMRU.WriteMRU(const Category, ItemKey, DisplayName: string;
  IconIndex: Integer);
begin
  if Assigned(FStorage) then
    FStorage.Upsert(Category, ItemKey, DisplayName, IconIndex);
end;

procedure TDeepBaseMRU.InternalRemoveMRU(const Category, ItemKey: string);
begin
  if Assigned(FStorage) then
    FStorage.Delete(Category, ItemKey);
end;

procedure TDeepBaseMRU.AddMRU(const Category, ItemKey: string;
  const DisplayName: string; IconIndex: Integer);
begin
  TMonitor.Enter(FLock);
  try
    WriteMRU(Category, ItemKey, DisplayName, IconIndex);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TDeepBaseMRU.RemoveMRU(const Category, ItemKey: string);
begin
  TMonitor.Enter(FLock);
  try
    InternalRemoveMRU(Category, ItemKey);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TDeepBaseMRU.DeleteMRU(const Category, ItemKey: string);
begin
  RemoveMRU(Category, ItemKey);
end;

procedure TDeepBaseMRU.ClearMRU(const Category: string);
begin
  TMonitor.Enter(FLock);
  try
    if Assigned(FStorage) then
      FStorage.Clear(Category);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TDeepBaseMRU.GetMRUList(const Category: string;
  MaxItems: Integer): TArray<string>;
var
  Items: TMRUItemArray;
  I: Integer;
begin
  Items := GetMRUItems(Category, MaxItems);
  SetLength(Result, Length(Items));
  for I := 0 to High(Items) do
    Result[I] := Items[I].ItemKey;
end;

function TDeepBaseMRU.GetMRUItems(const Category: string;
  MaxItems: Integer): TMRUItemArray;
begin
  SetLength(Result, 0);
  if not Assigned(FStorage) then
    Exit;

  TMonitor.Enter(FLock);
  try
    Result := FStorage.ReadItems(Category, MaxItems);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TDeepBaseMRU.RemoveInvalidMRU(const Category: string): Integer;
const
  FILE_CATEGORIES: array[0..3] of string = (
    'File', 'Project', 'RecentFiles', 'RecentProjects'
  );
var
  Categories: TArray<string>;
  Cat: string;
  Items: TMRUItemArray;
  Item: TMRUItem;
begin
  Result := 0;
  if not Assigned(FStorage) then
    Exit;

  if Category <> '' then
    Categories := TArray<string>.Create(Category)
  else
    Categories := TArray<string>.Create(
      FILE_CATEGORIES[0], FILE_CATEGORIES[1],
      FILE_CATEGORIES[2], FILE_CATEGORIES[3]);

  TMonitor.Enter(FLock);
  try
    for Cat in Categories do
    begin
      Items := FStorage.ReadItems(Cat, MaxInt);
      for Item in Items do
      begin
        if Item.ItemKey = '' then
          Continue;

        // BUG-042 FIX: Also handle UNC paths (\\server\share)
        if (Item.ItemKey[1] = '/') or (Item.ItemKey[1] = '\') or
           ((Length(Item.ItemKey) > 1) and (Item.ItemKey[2] = ':')) then
        begin
          if not FileExists(Item.ItemKey) and not DirectoryExists(Item.ItemKey) then
          begin
            FStorage.Delete(Cat, Item.ItemKey);
            Inc(Result);
          end;
        end;
      end;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TDeepBaseMRU.RemoveInvalidFileMRU(const Category: string);
begin
  RemoveInvalidMRU(Category);
end;

procedure TDeepBaseMRU.SetPinned(const Category, ItemKey: string;
  IsPinned: Boolean);
begin
  TMonitor.Enter(FLock);
  try
    if Assigned(FStorage) then
      FStorage.SetPinned(Category, ItemKey, IsPinned);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TDeepBaseMRU.IsPinned(const Category, ItemKey: string): Boolean;
begin
  Result := False;
  TMonitor.Enter(FLock);
  try
    if Assigned(FStorage) then
      Result := FStorage.IsPinned(Category, ItemKey);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TDeepBaseMRU.GetMRUCount(const Category: string): Integer;
begin
  Result := 0;
  TMonitor.Enter(FLock);
  try
    if Assigned(FStorage) then
      Result := FStorage.Count(Category);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TDeepBaseMRU.GetAccessCount(const Category, ItemKey: string): Integer;
begin
  Result := 0;
  TMonitor.Enter(FLock);
  try
    if Assigned(FStorage) then
      Result := FStorage.AccessCount(Category, ItemKey);
  finally
    TMonitor.Exit(FLock);
  end;
end;

end.
