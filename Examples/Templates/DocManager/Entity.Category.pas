unit Entity.Category;

{*******************************************************************************
  Category Entity - 分类实体

  DeepBase 框架文档管理模板 - 树状分类结构
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  DeepBase.ORM.Attributes, DeepBase.ORM.Entity;

type
  TCategory = class;

  /// <summary>
  /// 分类实体 - 支持无限层级树状结构
  /// </summary>
  [Table('Categories')]
  TCategory = class(TEntityBase)
  private
    [PrimaryKey]
    [Column('Id')]
    FId: string;

    [Column('Name')]
    FName: string;

    [Column('ParentId')]
    FParentId: string;

    [Column('SortOrder')]
    FSortOrder: Integer;

    [Column('Description')]
    FDescription: string;

    [Column('IconIndex')]
    FIconIndex: Integer;

    [Column('CreatedAt')]
    FCreatedAt: TDateTime;

    // 非持久化字段
    FParent: TCategory;
    FChildren: TObjectList<TCategory>;
    FLevel: Integer;
    FDocumentCount: Integer;

    function GetIsRoot: Boolean;
    function GetFullPath: string;
    function GetHasChildren: Boolean;
  public
    constructor Create; override;
    destructor Destroy; override;

    class function NewId: string;

    /// <summary>验证分类</summary>
    function Validate: Boolean; override;

    /// <summary>获取验证错误</summary>
    function GetValidationErrors: TArray<string>;

    /// <summary>添加子分�?/summary>
    procedure AddChild(Child: TCategory);

    /// <summary>移除子分�?/summary>
    procedure ReDeepMoveChild(const ChildId: string);

    /// <summary>查找子分�?/summary>
    function FindChild(const ChildId: string): TCategory;

    /// <summary>获取所有后代分�?ID</summary>
    function GetAllDescendantIds: TArray<string>;

    /// <summary>检查是否是某个分类的后�?/summary>
    function IsDescendantOf(const CategoryId: string): Boolean;

    // 属�?
    property Id: string read FId write FId;
    property Name: string read FName write FName;
    property ParentId: string read FParentId write FParentId;
    property SortOrder: Integer read FSortOrder write FSortOrder;
    property Description: string read FDescription write FDescription;
    property IconIndex: Integer read FIconIndex write FIconIndex;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;

    // 关系属�?
    property Parent: TCategory read FParent write FParent;
    property Children: TObjectList<TCategory> read FChildren;

    // 计算属�?
    property IsRoot: Boolean read GetIsRoot;
    property FullPath: string read GetFullPath;
    property HasChildren: Boolean read GetHasChildren;
    property Level: Integer read FLevel write FLevel;
    property DocumentCount: Integer read FDocumentCount write FDocumentCount;
  end;

  /// <summary>
  /// 分类树管理器
  /// </summary>
  TCategoryTree = class
  private
    FRootCategories: TObjectList<TCategory>;
    FAllCategories: TDictionary<string, TCategory>;

    procedure BuildTree(Categories: TObjectList<TCategory>);
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>从分类列表构建树</summary>
    procedure LoadFromList(Categories: TObjectList<TCategory>);

    /// <summary>清空�?/summary>
    procedure Clear;

    /// <summary>根据 ID 查找分类</summary>
    function FindById(const Id: string): TCategory;

    /// <summary>获取分类的完整路�?/summary>
    function GetCategoryPath(const Id: string): string;

    /// <summary>获取指定分类下的所有后�?ID</summary>
    function GetDescendantIds(const ParentId: string): TArray<string>;

    /// <summary>将树扁平化为列表（按深度优先顺序�?/summary>
    function Flatten: TArray<TCategory>;

    property RootCategories: TObjectList<TCategory> read FRootCategories;
    property AllCategories: TDictionary<string, TCategory> read FAllCategories;
  end;

implementation

{ TCategory }

constructor TCategory.Create;
begin
  inherited;
  FId := NewId;
  FSortOrder := 0;
  FIconIndex := 0;
  FCreatedAt := Now;
  FChildren := TObjectList<TCategory>.Create(False);  // 不拥有子对象
  FLevel := 0;
  FDocumentCount := 0;
end;

destructor TCategory.Destroy;
begin
  FChildren.Free;
  inherited;
end;

class function TCategory.NewId: string;
begin
  Result := TGUID.NewGuid.ToString.Replace('{', '').Replace('}', '').Replace('-', '');
end;

function TCategory.GetIsRoot: Boolean;
begin
  Result := FParentId.IsEmpty;
end;

function TCategory.GetFullPath: string;
begin
  if FParent <> nil then
    Result := FParent.GetFullPath + '/' + FName
  else
    Result := FName;
end;

function TCategory.GetHasChildren: Boolean;
begin
  Result := FChildren.Count > 0;
end;

function TCategory.Validate: Boolean;
var
  Errors: TArray<string>;
begin
  Errors := GetValidationErrors;
  Result := Length(Errors) = 0;
end;

function TCategory.GetValidationErrors: TArray<string>;
var
  Errors: TList<string>;
begin
  Errors := TList<string>.Create;
  try
    if FName.Trim.IsEmpty then
      Errors.Add('分类名称不能为空');

    if Length(FName) > 100 then
      Errors.Add('分类名称不能超过 100 字符');

    // 检查循环引�?
    if not FParentId.IsEmpty and (FParentId = FId) then
      Errors.Add('分类不能作为自己的父分类');

    Result := Errors.ToArray;
  finally
    Errors.Free;
  end;
end;

procedure TCategory.AddChild(Child: TCategory);
begin
  if (Child <> nil) and not FChildren.Contains(Child) then
  begin
    Child.FParent := Self;
    Child.FParentId := FId;
    Child.FLevel := FLevel + 1;
    FChildren.Add(Child);
  end;
end;

procedure TCategory.ReDeepMoveChild(const ChildId: string);
var
  I: Integer;
begin
  for I := FChildren.Count - 1 downto 0 do
  begin
    if FChildren[I].Id = ChildId then
    begin
      FChildren[I].FParent := nil;
      FChildren[I].FParentId := '';
      FChildren.Delete(I);
      Break;
    end;
  end;
end;

function TCategory.FindChild(const ChildId: string): TCategory;
var
  Child: TCategory;
  Found: TCategory;
begin
  Result := nil;

  for Child in FChildren do
  begin
    if Child.Id = ChildId then
      Exit(Child);

    // 递归查找
    Found := Child.FindChild(ChildId);
    if Found <> nil then
      Exit(Found);
  end;
end;

function TCategory.GetAllDescendantIds: TArray<string>;
var
  Ids: TList<string>;

  procedure CollectIds(Cat: TCategory);
  var
    Child: TCategory;
  begin
    for Child in Cat.Children do
    begin
      Ids.Add(Child.Id);
      CollectIds(Child);
    end;
  end;

begin
  Ids := TList<string>.Create;
  try
    CollectIds(Self);
    Result := Ids.ToArray;
  finally
    Ids.Free;
  end;
end;

function TCategory.IsDescendantOf(const CategoryId: string): Boolean;
var
  Current: TCategory;
begin
  Current := FParent;
  while Current <> nil do
  begin
    if Current.Id = CategoryId then
      Exit(True);
    Current := Current.Parent;
  end;
  Result := False;
end;

{ TCategoryTree }

constructor TCategoryTree.Create;
begin
  inherited;
  FRootCategories := TObjectList<TCategory>.Create(False);
  FAllCategories := TDictionary<string, TCategory>.Create;
end;

destructor TCategoryTree.Destroy;
begin
  FRootCategories.Free;
  FAllCategories.Free;
  inherited;
end;

procedure TCategoryTree.LoadFromList(Categories: TObjectList<TCategory>);
var
  Cat: TCategory;
begin
  Clear;

  // 首先添加所有分类到字典
  for Cat in Categories do
    FAllCategories.Add(Cat.Id, Cat);

  // 构建树结�?
  BuildTree(Categories);
end;

procedure TCategoryTree.BuildTree(Categories: TObjectList<TCategory>);
var
  Cat, Parent: TCategory;
begin
  for Cat in Categories do
  begin
    if Cat.ParentId.IsEmpty then
    begin
      // 根分�?
      Cat.Level := 0;
      FRootCategories.Add(Cat);
    end
    else if FAllCategories.TryGetValue(Cat.ParentId, Parent) then
    begin
      // 找到父分�?
      Parent.AddChild(Cat);
    end
    else
    begin
      // 父分类不存在，作为根分类处理
      Cat.Level := 0;
      FRootCategories.Add(Cat);
    end;
  end;

  // �?SortOrder 排序
  FRootCategories.Sort(TComparer<TCategory>.Construct(
    function(const A, B: TCategory): Integer
    begin
      Result := A.SortOrder - B.SortOrder;
    end
  ));
end;

procedure TCategoryTree.Clear;
begin
  FRootCategories.Clear;
  FAllCategories.Clear;
end;

function TCategoryTree.FindById(const Id: string): TCategory;
begin
  if not FAllCategories.TryGetValue(Id, Result) then
    Result := nil;
end;

function TCategoryTree.GetCategoryPath(const Id: string): string;
var
  Cat: TCategory;
begin
  Cat := FindById(Id);
  if Cat <> nil then
    Result := Cat.FullPath
  else
    Result := '';
end;

function TCategoryTree.GetDescendantIds(const ParentId: string): TArray<string>;
var
  Parent: TCategory;
begin
  Parent := FindById(ParentId);
  if Parent <> nil then
    Result := Parent.GetAllDescendantIds
  else
    SetLength(Result, 0);
end;

function TCategoryTree.Flatten: TArray<TCategory>;
var
  List: TList<TCategory>;

  procedure Visit(Cat: TCategory);
  var
    Child: TCategory;
  begin
    List.Add(Cat);
    for Child in Cat.Children do
      Visit(Child);
  end;

var
  Root: TCategory;
begin
  List := TList<TCategory>.Create;
  try
    for Root in FRootCategories do
      Visit(Root);
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

end.
