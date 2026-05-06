{ ============================================================================
  UniBase.FMX.I18nControls - FMX 国际化控件

  版本: 1.1
  说明: 自动翻译的 FMX 控件
  控件:
    - TFMXi18nLabel: 自动翻译的 Label
    - TFMXi18nButton: 自动翻译的 Button
    - TFMXi18nCheckBox: 自动翻译的 CheckBox
    - TFMXi18nGroupBox: 自动翻译的 GroupBox
  ============================================================================ }

unit UniBase.FMX.I18nControls;

interface

uses
  System.SysUtils,
  System.Classes,
  FMX.Types,
  FMX.Controls,
  FMX.StdCtrls,
  UniBase.i18n;

type
  /// <summary>
  /// 自动翻译的 FMX Label 控件
  /// 自动订阅语言变更通知，支持多个实例同时使用
  /// </summary>
  TFMXi18nLabel = class(TLabel)
  private
    FTextKey: string;
    FOriginalText: string;
    FSubscribed: Boolean;
    
    procedure SetTextKey(const Value: string);
    procedure UpdateTranslation;
    procedure HandleLanguageChanged(Sender: TObject);
    procedure SubscribeToLanguageChange;
    procedure UnsubscribeFromLanguageChange;
    
  protected
    procedure Loaded; override;
    
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    /// <summary>
    /// 刷新翻译
    /// </summary>
    procedure RefreshTranslation;
    
  published
    /// <summary>
    /// 翻译键（如果为空，则使用 Text 作为键）
    /// </summary>
    property TextKey: string read FTextKey write SetTextKey;
  end;

  /// <summary>
  /// 自动翻译的 FMX Button 控件
  /// 自动订阅语言变更通知，支持多个实例同时使用
  /// </summary>
  TFMXi18nButton = class(TButton)
  private
    FTextKey: string;
    FOriginalText: string;
    FSubscribed: Boolean;
    
    procedure SetTextKey(const Value: string);
    procedure UpdateTranslation;
    procedure HandleLanguageChanged(Sender: TObject);
    procedure SubscribeToLanguageChange;
    procedure UnsubscribeFromLanguageChange;
    
  protected
    procedure Loaded; override;
    
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    procedure RefreshTranslation;
    
  published
    property TextKey: string read FTextKey write SetTextKey;
  end;

  /// <summary>
  /// 自动翻译的 FMX CheckBox 控件
  /// </summary>
  TFMXi18nCheckBox = class(TCheckBox)
  private
    FTextKey: string;
    FOriginalText: string;
    FSubscribed: Boolean;

    procedure SetTextKey(const Value: string);
    procedure UpdateTranslation;
    procedure HandleLanguageChanged(Sender: TObject);
    procedure SubscribeToLanguageChange;
    procedure UnsubscribeFromLanguageChange;

  protected
    procedure Loaded; override;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure RefreshTranslation;

  published
    property TextKey: string read FTextKey write SetTextKey;
  end;

  /// <summary>
  /// 自动翻译的 FMX GroupBox 控件
  /// </summary>
  TFMXi18nGroupBox = class(TGroupBox)
  private
    FTextKey: string;
    FOriginalText: string;
    FSubscribed: Boolean;

    procedure SetTextKey(const Value: string);
    procedure UpdateTranslation;
    procedure HandleLanguageChanged(Sender: TObject);
    procedure SubscribeToLanguageChange;
    procedure UnsubscribeFromLanguageChange;

  protected
    procedure Loaded; override;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure RefreshTranslation;

  published
    property TextKey: string read FTextKey write SetTextKey;
  end;

implementation

uses
  UniBase.Manager;

{ TFMXi18nLabel }

constructor TFMXi18nLabel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FTextKey := '';
  FOriginalText := '';
  FSubscribed := False;
end;

destructor TFMXi18nLabel.Destroy;
begin
  UnsubscribeFromLanguageChange;
  inherited;
end;

procedure TFMXi18nLabel.SubscribeToLanguageChange;
begin
  if FSubscribed then
    Exit;
  if (csDesigning in ComponentState) then
    Exit;
  if UniBase.Manager.UniBase.IsInitialized and 
     Assigned(UniBase.Manager.UniBase.I18n) then
  begin
    UniBase.Manager.UniBase.I18n.SubscribeLanguageChange(HandleLanguageChanged);
    FSubscribed := True;
  end;
end;

procedure TFMXi18nLabel.UnsubscribeFromLanguageChange;
begin
  if not FSubscribed then
    Exit;
  if UniBase.Manager.UniBase.IsInitialized and 
     Assigned(UniBase.Manager.UniBase.I18n) then
  begin
    UniBase.Manager.UniBase.I18n.UnsubscribeLanguageChange(HandleLanguageChanged);
  end;
  FSubscribed := False;
end;

procedure TFMXi18nLabel.Loaded;
begin
  inherited;
  
  if not (csDesigning in ComponentState) then
  begin
    // 保存原始文本
    if FOriginalText = '' then
      FOriginalText := Text;
      
    // 订阅语言变更事件
    SubscribeToLanguageChange;
    UpdateTranslation;
  end;
end;

procedure TFMXi18nLabel.SetTextKey(const Value: string);
begin
  if FTextKey <> Value then
  begin
    FTextKey := Value;
    if not (csDesigning in ComponentState) then
      UpdateTranslation;
  end;
end;

procedure TFMXi18nLabel.UpdateTranslation;
var
  Key: string;
begin
  if FTextKey <> '' then
    Key := FTextKey
  else if FOriginalText <> '' then
    Key := FOriginalText
  else
    Key := Text;
    
  if UniBase.Manager.UniBase.IsInitialized then
    Text := UniBase.Manager.UniBase.i18n.Translate(Key)
  else
    Text := Key;
end;

procedure TFMXi18nLabel.RefreshTranslation;
begin
  UpdateTranslation;
end;

procedure TFMXi18nLabel.HandleLanguageChanged(Sender: TObject);
begin
  UpdateTranslation;
end;

{ TFMXi18nButton }

constructor TFMXi18nButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FTextKey := '';
  FOriginalText := '';
  FSubscribed := False;
end;

destructor TFMXi18nButton.Destroy;
begin
  UnsubscribeFromLanguageChange;
  inherited;
end;

procedure TFMXi18nButton.SubscribeToLanguageChange;
begin
  if FSubscribed then
    Exit;
  if (csDesigning in ComponentState) then
    Exit;
  if UniBase.Manager.UniBase.IsInitialized and 
     Assigned(UniBase.Manager.UniBase.I18n) then
  begin
    UniBase.Manager.UniBase.I18n.SubscribeLanguageChange(HandleLanguageChanged);
    FSubscribed := True;
  end;
end;

procedure TFMXi18nButton.UnsubscribeFromLanguageChange;
begin
  if not FSubscribed then
    Exit;
  if UniBase.Manager.UniBase.IsInitialized and 
     Assigned(UniBase.Manager.UniBase.I18n) then
  begin
    UniBase.Manager.UniBase.I18n.UnsubscribeLanguageChange(HandleLanguageChanged);
  end;
  FSubscribed := False;
end;

procedure TFMXi18nButton.Loaded;
begin
  inherited;
  
  if not (csDesigning in ComponentState) then
  begin
    if FOriginalText = '' then
      FOriginalText := Text;
      
    SubscribeToLanguageChange;
    UpdateTranslation;
  end;
end;

procedure TFMXi18nButton.SetTextKey(const Value: string);
begin
  if FTextKey <> Value then
  begin
    FTextKey := Value;
    if not (csDesigning in ComponentState) then
      UpdateTranslation;
  end;
end;

procedure TFMXi18nButton.UpdateTranslation;
var
  Key: string;
begin
  if FTextKey <> '' then
    Key := FTextKey
  else if FOriginalText <> '' then
    Key := FOriginalText
  else
    Key := Text;
    
  if UniBase.Manager.UniBase.IsInitialized then
    Text := UniBase.Manager.UniBase.i18n.Translate(Key)
  else
    Text := Key;
end;

procedure TFMXi18nButton.RefreshTranslation;
begin
  UpdateTranslation;
end;

procedure TFMXi18nButton.HandleLanguageChanged(Sender: TObject);
begin
  UpdateTranslation;
end;

{ TFMXi18nCheckBox }

constructor TFMXi18nCheckBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FTextKey := '';
  FOriginalText := '';
  FSubscribed := False;
end;

destructor TFMXi18nCheckBox.Destroy;
begin
  UnsubscribeFromLanguageChange;
  inherited;
end;

procedure TFMXi18nCheckBox.SubscribeToLanguageChange;
begin
  if FSubscribed then
    Exit;
  if (csDesigning in ComponentState) then
    Exit;
  if UniBase.Manager.UniBase.IsInitialized and
     Assigned(UniBase.Manager.UniBase.I18n) then
  begin
    UniBase.Manager.UniBase.I18n.SubscribeLanguageChange(HandleLanguageChanged);
    FSubscribed := True;
  end;
end;

procedure TFMXi18nCheckBox.UnsubscribeFromLanguageChange;
begin
  if not FSubscribed then
    Exit;
  if UniBase.Manager.UniBase.IsInitialized and
     Assigned(UniBase.Manager.UniBase.I18n) then
  begin
    UniBase.Manager.UniBase.I18n.UnsubscribeLanguageChange(HandleLanguageChanged);
  end;
  FSubscribed := False;
end;

procedure TFMXi18nCheckBox.Loaded;
begin
  inherited;

  if not (csDesigning in ComponentState) then
  begin
    if FOriginalText = '' then
      FOriginalText := Text;

    SubscribeToLanguageChange;
    UpdateTranslation;
  end;
end;

procedure TFMXi18nCheckBox.SetTextKey(const Value: string);
begin
  if FTextKey <> Value then
  begin
    FTextKey := Value;
    if not (csDesigning in ComponentState) then
      UpdateTranslation;
  end;
end;

procedure TFMXi18nCheckBox.UpdateTranslation;
var
  Key: string;
begin
  if FTextKey <> '' then
    Key := FTextKey
  else if FOriginalText <> '' then
    Key := FOriginalText
  else
    Key := Text;

  if UniBase.Manager.UniBase.IsInitialized then
    Text := UniBase.Manager.UniBase.i18n.Translate(Key)
  else
    Text := Key;
end;

procedure TFMXi18nCheckBox.RefreshTranslation;
begin
  UpdateTranslation;
end;

procedure TFMXi18nCheckBox.HandleLanguageChanged(Sender: TObject);
begin
  UpdateTranslation;
end;

{ TFMXi18nGroupBox }

constructor TFMXi18nGroupBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FTextKey := '';
  FOriginalText := '';
  FSubscribed := False;
end;

destructor TFMXi18nGroupBox.Destroy;
begin
  UnsubscribeFromLanguageChange;
  inherited;
end;

procedure TFMXi18nGroupBox.SubscribeToLanguageChange;
begin
  if FSubscribed then
    Exit;
  if (csDesigning in ComponentState) then
    Exit;
  if UniBase.Manager.UniBase.IsInitialized and
     Assigned(UniBase.Manager.UniBase.I18n) then
  begin
    UniBase.Manager.UniBase.I18n.SubscribeLanguageChange(HandleLanguageChanged);
    FSubscribed := True;
  end;
end;

procedure TFMXi18nGroupBox.UnsubscribeFromLanguageChange;
begin
  if not FSubscribed then
    Exit;
  if UniBase.Manager.UniBase.IsInitialized and
     Assigned(UniBase.Manager.UniBase.I18n) then
  begin
    UniBase.Manager.UniBase.I18n.UnsubscribeLanguageChange(HandleLanguageChanged);
  end;
  FSubscribed := False;
end;

procedure TFMXi18nGroupBox.Loaded;
begin
  inherited;

  if not (csDesigning in ComponentState) then
  begin
    if FOriginalText = '' then
      FOriginalText := Text;

    SubscribeToLanguageChange;
    UpdateTranslation;
  end;
end;

procedure TFMXi18nGroupBox.SetTextKey(const Value: string);
begin
  if FTextKey <> Value then
  begin
    FTextKey := Value;
    if not (csDesigning in ComponentState) then
      UpdateTranslation;
  end;
end;

procedure TFMXi18nGroupBox.UpdateTranslation;
var
  Key: string;
begin
  if FTextKey <> '' then
    Key := FTextKey
  else if FOriginalText <> '' then
    Key := FOriginalText
  else
    Key := Text;

  if UniBase.Manager.UniBase.IsInitialized then
    Text := UniBase.Manager.UniBase.i18n.Translate(Key)
  else
    Text := Key;
end;

procedure TFMXi18nGroupBox.RefreshTranslation;
begin
  UpdateTranslation;
end;

procedure TFMXi18nGroupBox.HandleLanguageChanged(Sender: TObject);
begin
  UpdateTranslation;
end;

end.
