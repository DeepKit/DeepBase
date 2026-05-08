unit Entity.Tag;

{*******************************************************************************
  Tag Entity - 标签实体

  DeepBase 框架文档管理模板 - 标签系统
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.UITypes,
  DeepBase.ORM.Attributes, DeepBase.ORM.Entity;

type
  /// <summary>
  /// 标签实体
  /// </summary>
  [Table('Tags')]
  TTag = class(TEntityBase)
  private
    [PrimaryKey]
    [Column('Id')]
    FId: string;

    [Column('Name')]
    FName: string;

    [Column('Color')]
    FColor: string;

    [Column('UsageCount')]
    FUsageCount: Integer;

    [Column('CreatedAt')]
    FCreatedAt: TDateTime;

    function GetColorValue: TColor;
    procedure SetColorValue(const Value: TColor);
  public
    constructor Create; override;

    class function NewId: string;

    /// <summary>验证标签</summary>
    function Validate: Boolean; override;

    /// <summary>获取验证错误</summary>
    function GetValidationErrors: TArray<string>;

    /// <summary>预定义颜色列�?/summary>
    class function GetPresetColors: TArray<string>;

    // 属�?
    property Id: string read FId write FId;
    property Name: string read FName write FName;
    property Color: string read FColor write FColor;
    property ColorValue: TColor read GetColorValue write SetColorValue;
    property UsageCount: Integer read FUsageCount write FUsageCount;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
  end;

  /// <summary>
  /// 文档-标签关联
  /// </summary>
  [Table('DocumentTags')]
  TDocumentTag = class(TEntityBase)
  private
    [Column('DocumentId')]
    [PrimaryKey]
    FDocumentId: string;

    [Column('TagId')]
    [PrimaryKey]
    FTagId: string;

    [Column('CreatedAt')]
    FCreatedAt: TDateTime;
  public
    constructor Create; override;

    property DocumentId: string read FDocumentId write FDocumentId;
    property TagId: string read FTagId write FTagId;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
  end;

  /// <summary>
  /// 标签服务
  /// </summary>
  TTagService = class
  private
    FTags: TObjectDictionary<string, TTag>;
    FTagsByName: TDictionary<string, TTag>;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>加载标签</summary>
    procedure LoadTags(Tags: TObjectList<TTag>);

    /// <summary>根据 ID 获取标签</summary>
    function GetTagById(const Id: string): TTag;

    /// <summary>根据名称获取标签</summary>
    function GetTagByName(const Name: string): TTag;

    /// <summary>获取或创建标�?/summary>
    function GetOrCreateTag(const Name: string): TTag;

    /// <summary>获取所有标�?/summary>
    function GetAllTags: TArray<TTag>;

    /// <summary>获取热门标签</summary>
    function GetPopularTags(Count: Integer = 10): TArray<TTag>;

    /// <summary>搜索标签</summary>
    function SearchTags(const Query: string): TArray<TTag>;

    /// <summary>清空</summary>
    procedure Clear;

    property Tags: TObjectDictionary<string, TTag> read FTags;
  end;

implementation

uses
  System.StrUtils;

{ TTag }

constructor TTag.Create;
begin
  inherited;
  FId := NewId;
  FColor := '#3498db';  // 默认蓝色
  FUsageCount := 0;
  FCreatedAt := Now;
end;

class function TTag.NewId: string;
begin
  Result := TGUID.NewGuid.ToString.Replace('{', '').Replace('}', '').Replace('-', '');
end;

function TTag.GetColorValue: TColor;
var
  R, G, B: Byte;
  ColorStr: string;
begin
  ColorStr := FColor;
  if ColorStr.StartsWith('#') then
    ColorStr := Copy(ColorStr, 2, Length(ColorStr));

  if Length(ColorStr) = 6 then
  begin
    R := StrToIntDef('$' + Copy(ColorStr, 1, 2), 0);
    G := StrToIntDef('$' + Copy(ColorStr, 3, 2), 0);
    B := StrToIntDef('$' + Copy(ColorStr, 5, 2), 0);
    Result := RGB(R, G, B);
  end
  else
    Result := clBlue;
end;

procedure TTag.SetColorValue(const Value: TColor);
begin
  FColor := Format('#%.2x%.2x%.2x', [
    GetRValue(Value),
    GetGValue(Value),
    GetBValue(Value)
  ]);
end;

function TTag.Validate: Boolean;
var
  Errors: TArray<string>;
begin
  Errors := GetValidationErrors;
  Result := Length(Errors) = 0;
end;

function TTag.GetValidationErrors: TArray<string>;
var
  Errors: TList<string>;
begin
  Errors := TList<string>.Create;
  try
    if FName.Trim.IsEmpty then
      Errors.Add('标签名称不能为空');

    if Length(FName) > 50 then
      Errors.Add('标签名称不能超过 50 字符');

    // 标签名不能包含特殊字�?
    if ContainsText(FName, ',') or ContainsText(FName, ';') then
      Errors.Add('标签名称不能包含逗号或分�?);

    Result := Errors.ToArray;
  finally
    Errors.Free;
  end;
end;

class function TTag.GetPresetColors: TArray<string>;
begin
  Result := [
    '#e74c3c',  // 红色
    '#e67e22',  // 橙色
    '#f1c40f',  // 黄色
    '#2ecc71',  // 绿色
    '#1abc9c',  // 青绿�?
    '#3498db',  // 蓝色
    '#9b59b6',  // 紫色
    '#34495e',  // 深灰�?
    '#95a5a6',  // 灰色
    '#e91e63'   // 粉红�?
  ];
end;

{ TDocumentTag }

constructor TDocumentTag.Create;
begin
  inherited;
  FCreatedAt := Now;
end;

{ TTagService }

constructor TTagService.Create;
begin
  inherited;
  FTags := TObjectDictionary<string, TTag>.Create([doOwnsValues]);
  FTagsByName := TDictionary<string, TTag>.Create;
end;

destructor TTagService.Destroy;
begin
  FTagsByName.Free;
  FTags.Free;
  inherited;
end;

procedure TTagService.LoadTags(Tags: TObjectList<TTag>);
var
  Tag: TTag;
begin
  Clear;

  for Tag in Tags do
  begin
    FTags.Add(Tag.Id, Tag);
    FTagsByName.Add(Tag.Name.ToLower, Tag);
  end;

  // 不释放传入的列表，因为对象已经移动到字典
  Tags.OwnsObjects := False;
end;

function TTagService.GetTagById(const Id: string): TTag;
begin
  if not FTags.TryGetValue(Id, Result) then
    Result := nil;
end;

function TTagService.GetTagByName(const Name: string): TTag;
begin
  if not FTagsByName.TryGetValue(Name.ToLower, Result) then
    Result := nil;
end;

function TTagService.GetOrCreateTag(const Name: string): TTag;
var
  NormalizedName: string;
begin
  NormalizedName := Name.Trim;
  Result := GetTagByName(NormalizedName);

  if Result = nil then
  begin
    Result := TTag.Create;
    Result.Name := NormalizedName;
    FTags.Add(Result.Id, Result);
    FTagsByName.Add(NormalizedName.ToLower, Result);
  end;
end;

function TTagService.GetAllTags: TArray<TTag>;
var
  List: TList<TTag>;
  Pair: TPair<string, TTag>;
begin
  List := TList<TTag>.Create;
  try
    for Pair in FTags do
      List.Add(Pair.Value);

    // 按名称排�?
    List.Sort(TComparer<TTag>.Construct(
      function(const A, B: TTag): Integer
      begin
        Result := CompareText(A.Name, B.Name);
      end
    ));

    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

function TTagService.GetPopularTags(Count: Integer): TArray<TTag>;
var
  List: TList<TTag>;
  Pair: TPair<string, TTag>;
begin
  List := TList<TTag>.Create;
  try
    for Pair in FTags do
      List.Add(Pair.Value);

    // 按使用次数降序排�?
    List.Sort(TComparer<TTag>.Construct(
      function(const A, B: TTag): Integer
      begin
        Result := B.UsageCount - A.UsageCount;
      end
    ));

    // 取前 N �?
    if List.Count > Count then
      List.DeleteRange(Count, List.Count - Count);

    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

function TTagService.SearchTags(const Query: string): TArray<TTag>;
var
  List: TList<TTag>;
  Pair: TPair<string, TTag>;
  LowerQuery: string;
begin
  List := TList<TTag>.Create;
  try
    LowerQuery := Query.ToLower;

    for Pair in FTags do
    begin
      if Pair.Value.Name.ToLower.Contains(LowerQuery) then
        List.Add(Pair.Value);
    end;

    // 按相关性排序（名称开头匹配优先）
    List.Sort(TComparer<TTag>.Construct(
      function(const A, B: TTag): Integer
      var
        AStarts, BStarts: Boolean;
      begin
        AStarts := A.Name.ToLower.StartsWith(LowerQuery);
        BStarts := B.Name.ToLower.StartsWith(LowerQuery);

        if AStarts and not BStarts then
          Result := -1
        else if BStarts and not AStarts then
          Result := 1
        else
          Result := CompareText(A.Name, B.Name);
      end
    ));

    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

procedure TTagService.Clear;
begin
  FTagsByName.Clear;
  FTags.Clear;
end;

end.
