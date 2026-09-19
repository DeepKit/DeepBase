{ ============================================================================
  DeepBase.FMX.MRUControls - FMX MRU 鎺т欢
  
  鐗堟湰: 1.0
  璇存槑: 鑷姩缁戝畾 MRU 鍒楄〃鐨?FMX 鎺т欢
  鎺т欢:
    - TFMXMRUComboBox: MRU 涓嬫媺鍒楄〃
  ============================================================================ }

unit DeepBase.FMX.MRUControls;

interface

uses
  System.SysUtils,
  System.Classes,
  FMX.Types,
  FMX.Controls,
  FMX.ListBox,
  DeepBase.Types,
  DeepBase.MRU;

type
  /// <summary>
  /// MRU 涓嬫媺鍒楄〃鎺т欢
  /// </summary>
  TFMXMRUComboBox = class(TComboBox)
  private
    FCategory: string;
    FMaxItems: Integer;
    FAutoRefresh: Boolean;
    FOnMRUSelected: TNotifyEvent;
    
    procedure SetCategory(const Value: string);
    procedure DoItemChange(Sender: TObject);
    
  protected
    procedure Loaded; override;
    
  public
    constructor Create(AOwner: TComponent); override;
    
    /// <summary>
    /// 鍒锋柊 MRU 鍒楄〃
    /// </summary>
    procedure RefreshMRU;
    
    /// <summary>
    /// 娣诲姞褰撳墠閫変腑椤瑰埌 MRU
    /// </summary>
    procedure AddCurrentToMRU;
    
    /// <summary>
    /// 鑾峰彇褰撳墠閫変腑鐨?MRU 閿?
    /// </summary>
    function GetSelectedKey: string;
    
  published
    /// <summary>
    /// MRU 绫诲埆
    /// </summary>
    property Category: string read FCategory write SetCategory;
    
    /// <summary>
    /// 鏈€澶ф樉绀洪」鏁?
    /// </summary>
    property MaxItems: Integer read FMaxItems write FMaxItems default 10;
    
    /// <summary>
    /// 鑷姩鍒锋柊
    /// </summary>
    property AutoRefresh: Boolean read FAutoRefresh write FAutoRefresh default True;
    
    /// <summary>
    /// MRU 閫変腑浜嬩欢
    /// </summary>
    property OnMRUSelected: TNotifyEvent read FOnMRUSelected write FOnMRUSelected;
  end;

implementation

uses
  DeepBase.Manager;

{ TFMXMRUComboBox }

constructor TFMXMRUComboBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCategory := 'Default';
  FMaxItems := 10;
  FAutoRefresh := True;
end;

procedure TFMXMRUComboBox.Loaded;
begin
  inherited;
  
  if not (csDesigning in ComponentState) then
  begin
    if FAutoRefresh then
      RefreshMRU;
      
    OnChange := DoItemChange;
  end;
end;

procedure TFMXMRUComboBox.SetCategory(const Value: string);
begin
  if FCategory <> Value then
  begin
    FCategory := Value;
    if not (csDesigning in ComponentState) and FAutoRefresh then
      RefreshMRU;
  end;
end;

procedure TFMXMRUComboBox.RefreshMRU;
var
  MRUItems: TMRUItemArray;
  I: Integer;
  OldIndex: Integer;
begin
  if not DeepBase.Manager.DeepBase.IsInitialized then
    Exit;
    
  OldIndex := ItemIndex;
  Items.Clear;
  
  MRUItems := DeepBase.Manager.DeepBase.MRU.GetMRUItems(FCategory, FMaxItems);
  
  for I := 0 to High(MRUItems) do
  begin
    Items.Add(MRUItems[I].DisplayName);
    // Store key in tag
    if Items.Count > 0 then
      ListItems[Items.Count - 1].Tag := NativeInt(PChar(MRUItems[I].ItemKey));
  end;
  
  // Restore selection if possible
  if (OldIndex >= 0) and (OldIndex < Items.Count) then
    ItemIndex := OldIndex
  else if Items.Count > 0 then
    ItemIndex := 0;
end;

procedure TFMXMRUComboBox.AddCurrentToMRU;
begin
  if not DeepBase.Manager.DeepBase.IsInitialized then
    Exit;
    
  if (ItemIndex >= 0) and (Selected <> nil) then
    DeepBase.Manager.DeepBase.MRU.AddMRU(FCategory, Selected.Text, Selected.Text);
end;

function TFMXMRUComboBox.GetSelectedKey: string;
begin
  Result := '';
  if (ItemIndex >= 0) and (Selected <> nil) then
    Result := Selected.Text;
end;

procedure TFMXMRUComboBox.DoItemChange(Sender: TObject);
begin
  // Update MRU access time
  if (ItemIndex >= 0) and DeepBase.Manager.DeepBase.IsInitialized then
  begin
    DeepBase.Manager.DeepBase.MRU.AddMRU(FCategory, GetSelectedKey, GetSelectedKey);
  end;
  
  if Assigned(FOnMRUSelected) then
    FOnMRUSelected(Self);
end;

end.
