{ ============================================================================
  UniBase.FMX.I18nControls - FMX 国际化控件
  
  版本: 1.0
  说明: 自动翻译的 FMX 控件
  控件:
    - TFMXi18nLabel: 自动翻译的 Label
    - TFMXi18nButton: 自动翻译的 Button
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
  /// </summary>
  TFMXi18nLabel = class(TLabel)
  private
    FTextKey: string;
    FOriginalText: string;
    
    procedure SetTextKey(const Value: string);
    procedure UpdateTranslation;
    procedure OnLanguageChangedHandler(Sender: TObject);
    
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
  /// </summary>
  TFMXi18nButton = class(TButton)
  private
    FTextKey: string;
    FOriginalText: string;
    
    procedure SetTextKey(const Value: string);
    procedure UpdateTranslation;
    procedure OnLanguageChangedHandler(Sender: TObject);
    
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
end;

destructor TFMXi18nLabel.Destroy;
begin
  // 取消注册语言变更事件
  if UniBase.Manager.UniBase.IsInitialized then
    UniBase.Manager.UniBase.i18n.OnLanguageChanged := nil;
  inherited;
end;

procedure TFMXi18nLabel.Loaded;
begin
  inherited;
  
  if not (csDesigning in ComponentState) then
  begin
    // 保存原始文本
    if FOriginalText = '' then
      FOriginalText := Text;
      
    // 注册语言变更事件
    if UniBase.Manager.UniBase.IsInitialized then
      UniBase.Manager.UniBase.i18n.OnLanguageChanged := OnLanguageChangedHandler;
      
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
    Text := UniBase.Manager.UniBase.i18n.T(Key)
  else
    Text := Key;
end;

procedure TFMXi18nLabel.RefreshTranslation;
begin
  UpdateTranslation;
end;

procedure TFMXi18nLabel.OnLanguageChangedHandler(Sender: TObject);
begin
  UpdateTranslation;
end;

{ TFMXi18nButton }

constructor TFMXi18nButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FTextKey := '';
  FOriginalText := '';
end;

destructor TFMXi18nButton.Destroy;
begin
  if UniBase.Manager.UniBase.IsInitialized then
    UniBase.Manager.UniBase.i18n.OnLanguageChanged := nil;
  inherited;
end;

procedure TFMXi18nButton.Loaded;
begin
  inherited;
  
  if not (csDesigning in ComponentState) then
  begin
    if FOriginalText = '' then
      FOriginalText := Text;
      
    if UniBase.Manager.UniBase.IsInitialized then
      UniBase.Manager.UniBase.i18n.OnLanguageChanged := OnLanguageChangedHandler;
      
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
    Text := UniBase.Manager.UniBase.i18n.T(Key)
  else
    Text := Key;
end;

procedure TFMXi18nButton.RefreshTranslation;
begin
  UpdateTranslation;
end;

procedure TFMXi18nButton.OnLanguageChangedHandler(Sender: TObject);
begin
  UpdateTranslation;
end;

end.
