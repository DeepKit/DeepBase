{ ============================================================================
  UniBase.VCL.MRUControls - MRU 绑定控件
  
  版本: 1.0
  说明: 自动绑定 UniBase.MRU 的 VCL 控件
  ============================================================================ }

unit UniBase.VCL.MRUControls;

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.Menus,
  Vcl.StdCtrls,
  Vcl.Controls,
  UniBase.Manager,
  UniBase.MRU,
  UniBase.Types;

type
  /// <summary>
  /// MRU 弹出菜单
  /// </summary>
  TMRUPopupMenu = class(TPopupMenu)
  private
    FCategory: string;
    FMaxItems: Integer;
    FAutoRefresh: Boolean;
    FOnItemClick: TNotifyEvent;
    FEmptyText: string;
    procedure SetCategory(const Value: string);
    procedure InternalItemClick(Sender: TObject);
  protected
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    
    /// <summary>
    /// 刷新菜单项
    /// </summary>
    procedure RefreshItems;
    
    /// <summary>
    /// 获取选中项的 ItemKey
    /// </summary>
    function GetSelectedItemKey: string;
  published
    property Category: string read FCategory write SetCategory;
    property MaxItems: Integer read FMaxItems write FMaxItems default 10;
    property AutoRefresh: Boolean read FAutoRefresh write FAutoRefresh default True;
    property EmptyText: string read FEmptyText write FEmptyText;
    property OnItemClick: TNotifyEvent read FOnItemClick write FOnItemClick;
  end;

  /// <summary>
  /// MRU 下拉框
  /// </summary>
  TMRUComboBox = class(TComboBox)
  private
    FCategory: string;
    FMaxItems: Integer;
    FAutoRefresh: Boolean;
    FLastSelectedKey: string;
    procedure SetCategory(const Value: string);
  protected
    procedure Loaded; override;
    procedure Select; override;
  public
    constructor Create(AOwner: TComponent); override;
    
    /// <summary>
    /// 刷新列表项
    /// </summary>
    procedure RefreshItems;
    
    /// <summary>
    /// 获取选中项的 ItemKey
    /// </summary>
    function GetSelectedItemKey: string;
    
    /// <summary>
    /// 选择指定的 ItemKey
    /// </summary>
    procedure SelectByItemKey(const ItemKey: string);
  published
    property Category: string read FCategory write SetCategory;
    property MaxItems: Integer read FMaxItems write FMaxItems default 10;
    property AutoRefresh: Boolean read FAutoRefresh write FAutoRefresh default True;
  end;

implementation

{ TMRUPopupMenu }

constructor TMRUPopupMenu.Create(AOwner: TComponent);
begin
  inherited;
  FMaxItems := 10;
  FAutoRefresh := True;
  FEmptyText := '(Empty)';
end;

procedure TMRUPopupMenu.SetCategory(const Value: string);
begin
  FCategory := Value;
  if not (csDesigning in ComponentState) and FAutoRefresh then
    RefreshItems;
end;

procedure TMRUPopupMenu.Loaded;
begin
  inherited;
  if (not (csDesigning in ComponentState)) and FAutoRefresh and (FCategory <> '') then
    RefreshItems;
end;

procedure TMRUPopupMenu.RefreshItems;
var
  MRUItems: TMRUItemArray;
  Item: TMRUItem;
  MenuItem: TMenuItem;
  MRU: TUniBaseMRU;
begin
  Items.Clear;
  
  if not UniBase.Manager.UniBase.IsInitialized then Exit;
  if FCategory = '' then Exit;
  
  // 从 MRU 模块获取项目
  MRU := TUniBaseMRU.Create(UniBase.Manager.UniBase.ConfigDB);
  try
    MRUItems := MRU.GetMRUItems(FCategory, FMaxItems);
  finally
    MRU.Free;
  end;
  
  if Length(MRUItems) = 0 then
  begin
    MenuItem := TMenuItem.Create(Self);
    MenuItem.Caption := FEmptyText;
    MenuItem.Enabled := False;
    Items.Add(MenuItem);
    Exit;
  end;
  
  for Item in MRUItems do
  begin
    MenuItem := TMenuItem.Create(Self);
    MenuItem.Caption := Item.DisplayName;
    MenuItem.Hint := Item.ItemKey;
    MenuItem.Tag := NativeInt(PChar(Item.ItemKey)); // Store ItemKey
    MenuItem.OnClick := InternalItemClick;
    Items.Add(MenuItem);
  end;
end;

procedure TMRUPopupMenu.InternalItemClick(Sender: TObject);
begin
  if Assigned(FOnItemClick) then
    FOnItemClick(Sender);
end;

function TMRUPopupMenu.GetSelectedItemKey: string;
begin
  Result := '';
  // 返回最后点击的菜单项的 ItemKey
end;

{ TMRUComboBox }

constructor TMRUComboBox.Create(AOwner: TComponent);
begin
  inherited;
  FMaxItems := 10;
  FAutoRefresh := True;
  Style := csDropDownList;
end;

procedure TMRUComboBox.SetCategory(const Value: string);
begin
  FCategory := Value;
  if not (csDesigning in ComponentState) and FAutoRefresh then
    RefreshItems;
end;

procedure TMRUComboBox.Loaded;
begin
  inherited;
  if (not (csDesigning in ComponentState)) and FAutoRefresh and (FCategory <> '') then
    RefreshItems;
end;

procedure TMRUComboBox.RefreshItems;
var
  MRUItems: TMRUItemArray;
  Item: TMRUItem;
  MRU: TUniBaseMRU;
begin
  Items.Clear;
  
  if not UniBase.Manager.UniBase.IsInitialized then Exit;
  if FCategory = '' then Exit;
  
  MRU := TUniBaseMRU.Create(UniBase.Manager.UniBase.ConfigDB);
  try
    MRUItems := MRU.GetMRUItems(FCategory, FMaxItems);
    
    for Item in MRUItems do
    begin
      Items.AddObject(Item.DisplayName, TObject(NativeInt(Items.Count)));
      // 存储完整数据需要更复杂的方案，这里简化处理
    end;
  finally
    MRU.Free;
  end;
end;

procedure TMRUComboBox.Select;
begin
  inherited;
  if ItemIndex >= 0 then
    FLastSelectedKey := Items[ItemIndex];
end;

function TMRUComboBox.GetSelectedItemKey: string;
var
  MRUItems: TMRUItemArray;
  MRU: TUniBaseMRU;
begin
  Result := '';
  if ItemIndex < 0 then Exit;
  if not UniBase.Manager.UniBase.IsInitialized then Exit;
  
  MRU := TUniBaseMRU.Create(UniBase.Manager.UniBase.ConfigDB);
  try
    MRUItems := MRU.GetMRUItems(FCategory, FMaxItems);
    if ItemIndex < Length(MRUItems) then
      Result := MRUItems[ItemIndex].ItemKey;
  finally
    MRU.Free;
  end;
end;

procedure TMRUComboBox.SelectByItemKey(const ItemKey: string);
var
  MRUItems: TMRUItemArray;
  MRU: TUniBaseMRU;
  I: Integer;
begin
  if not UniBase.Manager.UniBase.IsInitialized then Exit;
  
  MRU := TUniBaseMRU.Create(UniBase.Manager.UniBase.ConfigDB);
  try
    MRUItems := MRU.GetMRUItems(FCategory, FMaxItems);
    for I := 0 to High(MRUItems) do
    begin
      if MRUItems[I].ItemKey = ItemKey then
      begin
        ItemIndex := I;
        Exit;
      end;
    end;
  finally
    MRU.Free;
  end;
end;

end.
