unit Entity.Tag;

{*******************************************************************************
  Tag Entity - 鏍囩瀹炰綋

  DeepBase 妗嗘灦鏂囨。绠＄悊妯℃澘 - 鏍囩绯荤粺
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.UITypes,
  DeepBase.ORM.Attributes, DeepBase.ORM.Entity;

type
  /// <summary>
  /// 鏍囩瀹炰綋
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

    /// <summary>楠岃瘉鏍囩</summary>
    function Validate: Boolean; override;

    /// <summary>鑾峰彇楠岃瘉閿欒</summary>
    function GetValidationErrors: TArray<string>;

    /// <summary>棰勫畾涔夐鑹插垪琛?/summary>
    class function GetPresetColors: TArray<string>;

    // 灞炴€?
    property Id: string read FId write FId;
    property Name: string read FName write FName;
    property Color: string read FColor write FColor;
    property ColorValue: TColor read GetColorValue write SetColorValue;
    property UsageCount: Integer read FUsageCount write FUsageCount;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
  end;

  /// <summary>
  /// 鏂囨。-鏍囩鍏宠仈
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
  /// 鏍囩鏈嶅姟
  /// </summary>
  TTagService = class
  private
    FTags: TObjectDictionary<string, TTag>;
    FTagsByName: TDictionary<string, TTag>;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>鍔犺浇鏍囩</summary>
    procedure LoadTags(Tags: TObjectList<TTag>);

    /// <summary>鏍规嵁 ID 鑾峰彇鏍囩</summary>
    function GetTagById(const Id: string): TTag;

    /// <summary>鏍规嵁鍚嶇О鑾峰彇鏍囩</summary>
    function GetTagByName(const Name: string): TTag;

    /// <summary>鑾峰彇鎴栧垱寤烘爣绛?/summary>
    function GetOrCreateTag(const Name: string): TTag;

    /// <summary>鑾峰彇鎵€鏈夋爣绛?/summary>
    function GetAllTags: TArray<TTag>;

    /// <summary>鑾峰彇鐑棬鏍囩</summary>
    function GetPopularTags(Count: Integer = 10): TArray<TTag>;

    /// <summary>鎼滅储鏍囩</summary>
    function SearchTags(const Query: string): TArray<TTag>;

    /// <summary>娓呯┖</summary>
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
  FColor := '#3498db';  // 榛樿钃濊壊
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
      Errors.Add('鏍囩鍚嶇О涓嶈兘涓虹┖');

    if Length(FName) > 50 then
      Errors.Add('鏍囩鍚嶇О涓嶈兘瓒呰繃 50 瀛楃');

    // 鏍囩鍚嶄笉鑳藉寘鍚壒娈婂瓧绗?
    if ContainsText(FName, ',') or ContainsText(FName, ';') then
      Errors.Add('鏍囩鍚嶇О涓嶈兘鍖呭惈閫楀彿鎴栧垎鍙?);

    Result := Errors.ToArray;
  finally
    Errors.Free;
  end;
end;

class function TTag.GetPresetColors: TArray<string>;
begin
  Result := [
    '#e74c3c',  // 绾㈣壊
    '#e67e22',  // 姗欒壊
    '#f1c40f',  // 榛勮壊
    '#2ecc71',  // 缁胯壊
    '#1abc9c',  // 闈掔豢鑹?
    '#3498db',  // 钃濊壊
    '#9b59b6',  // 绱壊
    '#34495e',  // 娣辩伆钃?
    '#95a5a6',  // 鐏拌壊
    '#e91e63'   // 绮夌孩鑹?
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

  // 涓嶉噴鏀句紶鍏ョ殑鍒楄〃锛屽洜涓哄璞″凡缁忕Щ鍔ㄥ埌瀛楀吀
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

    // 鎸夊悕绉版帓搴?
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

    // 鎸変娇鐢ㄦ鏁伴檷搴忔帓搴?
    List.Sort(TComparer<TTag>.Construct(
      function(const A, B: TTag): Integer
      begin
        Result := B.UsageCount - A.UsageCount;
      end
    ));

    // 鍙栧墠 N 涓?
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

    // 鎸夌浉鍏虫€ф帓搴忥紙鍚嶇О寮€澶村尮閰嶄紭鍏堬級
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
